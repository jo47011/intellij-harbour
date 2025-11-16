package org.intellij.sdk.language;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.event.DocumentEvent;
import com.intellij.openapi.editor.event.DocumentListener;
import com.intellij.openapi.editor.event.EditorFactoryEvent;
import com.intellij.openapi.editor.event.EditorFactoryListener;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.PsiTreeChangeAdapter;
import com.intellij.psi.PsiTreeChangeEvent;
import com.intellij.psi.tree.IElementType;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

import java.util.Collection;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Listens for Harbour file events to update references and perform analysis.
 */
public class HarbourFileListener implements EditorFactoryListener {
    private static final Logger LOG = Logger.getInstance(HarbourFileListener.class);
    private final Project project;

    public HarbourFileListener(Project project) {
        this.project = project;
    }

    @Override
    public void editorCreated(@NotNull EditorFactoryEvent event) {
        VirtualFile file = FileDocumentManager.getInstance().getFile(event.getEditor().getDocument());
        if (file != null && "prg".equals(file.getExtension())) {
            HarbourLogger.log("FileListener", "=== Harbour file opened: " + file.getName() + " ===");

            // Add document listener to track changes
            event.getEditor().getDocument().addDocumentListener(new HarbourDocumentListener(project));

            // Use NON-BLOCKING read action to prevent EDT freeze
            // This runs in background without blocking the UI
            ReadAction.nonBlocking(() -> {
                try {
                    PsiFile psiFile = PsiManager.getInstance(project).findFile(file);
                    if (psiFile instanceof HarbourFile) {
                        analyzeHarbourFile((HarbourFile)psiFile);

                        // Register with reference service for cross-file resolution
                        HarbourReferenceService referenceService =
                                HarbourReferenceService.getInstance(project);
                        referenceService.registerFunctions((HarbourFile)psiFile);
                        referenceService.registerProcedures((HarbourFile)psiFile);
                        referenceService.registerClasses((HarbourFile)psiFile);
                        HarbourLogger.log("FileListener", "Registered file with reference service: " + file.getName());

                        // Apply token-based reference approach
                        int refsAdded = HarbourTokenTypeExtension.processFile(psiFile);
                        HarbourLogger.log("FileListener", "Added " + refsAdded + " token-based references to " + file.getName());

                        // Run enhanced diagnostics
                        try {
                            HarbourReferenceDiagnostics.diagnoseFile((HarbourFile)psiFile);
                        } catch (Exception e) {
                            LOG.error("Error running diagnostics", e);
                        }
                    } else {
                        LOG.error("File is not a HarbourFile but " +
                                (psiFile != null ? psiFile.getClass().getName() : "null"));
                    }
                } catch (Exception e) {
                    LOG.error("Error analyzing file: " + e.getMessage(), e);
                }
                return null;
            })
            .inSmartMode(project)
            .expireWhen(() -> project.isDisposed())
            .submit(com.intellij.util.concurrency.AppExecutorUtil.getAppExecutorService());
        }
    }

    /**
     * Document listener for tracking changes to Harbour files in real-time
     */
    private static class HarbourDocumentListener implements DocumentListener {
        private final Project project;
        private boolean documentChanged = false;
        // Throttle mechanism to avoid excessive updates
        private static final AtomicLong lastUpdateTimestamp = new AtomicLong(0);
        private static final long THROTTLE_INTERVAL_MS = 1000; // 1 second throttle

        public HarbourDocumentListener(Project project) {
            this.project = project;
        }

        @Override
        public void documentChanged(@NotNull DocumentEvent event) {
            // Mark document as changed to avoid processing twice
            if (documentChanged) {
                return;
            }
            documentChanged = true;

            Document document = event.getDocument();
            VirtualFile file = FileDocumentManager.getInstance().getFile(document);

            if (file != null && (file.getExtension() != null &&
                    (file.getExtension().equals("prg") || file.getExtension().equals("ch")))) {
                // Check if we should process this update or throttle it
                long currentTime = System.currentTimeMillis();
                long lastUpdate = lastUpdateTimestamp.get();

                // Only process if enough time has passed since the last update
                if (currentTime - lastUpdate > THROTTLE_INTERVAL_MS) {
                    // Try to update the timestamp (atomic compare-and-set)
                    if (lastUpdateTimestamp.compareAndSet(lastUpdate, currentTime)) {
                        HarbourLogger.log("FileListener", "Harbour document changed: " + file.getName() + " (processing)");

                        // Use invokeLater for document commit, then run analysis in background
                        com.intellij.openapi.application.ApplicationManager.getApplication().invokeLater(() -> {
                            try {
                                documentChanged = false;

                                // Commit document to ensure PSI is updated (must be on EDT)
                                PsiDocumentManager.getInstance(project).commitDocument(document);

                                // Run analysis in background using NON-BLOCKING read action
                                ReadAction.nonBlocking(() -> {
                                    try {
                                        // Get the PsiFile after the change
                                        PsiFile psiFile = PsiManager.getInstance(project).findFile(file);

                                        if (psiFile instanceof HarbourFile) {
                                            // Get reference service
                                            HarbourReferenceService referenceService =
                                                    HarbourReferenceService.getInstance(project);

                                            // Force a clear and rebuild of caches for this file
                                            referenceService.forceClearCaches();

                                            // Re-register all declarations
                                            referenceService.registerFunctions((HarbourFile) psiFile);
                                            referenceService.registerProcedures((HarbourFile) psiFile);
                                            referenceService.registerClasses((HarbourFile) psiFile);

                                            // Clear function declaration cache
                                            HarbourFunctionDeclarationCache.clearCache(project);

                                            // Make sure token references are updated
                                            HarbourTokenTypeExtension.processFile(psiFile);

                                            HarbourLogger.log("FileListener", "Updated references for changed file: " + file.getName());
                                        }
                                    } catch (Exception e) {
                                        LOG.error("Error in read action", e);
                                    }
                                    return null;
                                })
                                .inSmartMode(project)
                                .expireWhen(() -> project.isDisposed())
                                .submit(com.intellij.util.concurrency.AppExecutorUtil.getAppExecutorService());
                            } catch (Exception e) {
                                LOG.error("Error processing document change", e);
                            }
                        });
                    } else {
                        // Another thread already updated the timestamp, we'll skip this update
                        HarbourLogger.log("FileListener", "Skipping update for " + file.getName() + " (throttled)");
                        documentChanged = false;
                    }
                } else {
                    // Too soon after the last update, skip this one
                    HarbourLogger.log("FileListener", "Skipping update for " + file.getName() + " (throttled, " +
                            (currentTime - lastUpdate) + "ms < " + THROTTLE_INTERVAL_MS + "ms)");
                    documentChanged = false;
                }
            } else {
                documentChanged = false;
            }
        }
    }

    private void analyzeHarbourFile(HarbourFile file) {
        HarbourLogger.log("FileListener", "Analyzing Harbour file: " + file.getName());
        HarbourLogger.log("FileListener", "Looking for function declarations...");

        try {
            // Look for function declarations
            Collection<HarbourFunctionDeclaration> functions =
                    PsiTreeUtil.findChildrenOfType(file, HarbourFunctionDeclaration.class);

            HarbourLogger.log("FileListener", "Found " + functions.size() + " function declarations");

            for (HarbourFunctionDeclaration func : functions) {
                HarbourLogger.log("FileListener", "Function declaration found: " + func.getName());

                if (func.getNameIdentifier() != null) {
                    HarbourLogger.log("FileListener", "  Name identifier: " + func.getNameIdentifier().getText());
                    HarbourLogger.log("FileListener", "  Element type: " + func.getNameIdentifier().getNode().getElementType().toString());
                } else {
                    LOG.error("  Name identifier is null!");
                }
            }

            // Also try direct token approach
            HarbourLogger.log("FileListener", "Performing token-based function search...");
            int tokenFunctions = findFunctionsByTokens(file);
            HarbourLogger.log("FileListener", "Found " + tokenFunctions + " functions/procedures via tokens");

        } catch (Exception e) {
            LOG.error("Error processing function declarations: " + e.getMessage(), e);
        }
    }

    /**
     * Find functions directly using tokens.
     */
    private int findFunctionsByTokens(PsiFile file) {
        int count = 0;

        // Process all elements in the file
        for (PsiElement element : file.getChildren()) {
            count += processElementForFunctions(element);
        }

        return count;
    }

    /**
     * Process an element recursively to find function declarations.
     */
    private int processElementForFunctions(PsiElement element) {
        int count = 0;

        // Check if this is a function or procedure keyword
        if (element.getNode() != null) {
            IElementType type = element.getNode().getElementType();
            if (type == HarbourTypes.FUNCTION || type == HarbourTypes.PROCEDURE) {
                // Find the identifier after the keyword
                PsiElement nextSibling = element.getNextSibling();
                while (nextSibling != null &&
                        (nextSibling.getNode() == null ||
                                nextSibling.getNode().getElementType() != HarbourTypes.IDENT)) {
                    nextSibling = nextSibling.getNextSibling();
                }

                if (nextSibling != null) {
                    HarbourLogger.log("FileListener", "Found " + (type == HarbourTypes.FUNCTION ? "function" : "procedure") +
                            ": " + nextSibling.getText());
                    count++;
                }
            }
        }

        // Process children recursively
        for (PsiElement child : element.getChildren()) {
            count += processElementForFunctions(child);
        }

        return count;
    }

    /**
     * Creates a PsiTreeChangeListener for tracking file modifications.
     * This should be registered in the plugin.xml.
     */
    public static class PsiChangeListener extends PsiTreeChangeAdapter {
        private static final Logger LOG = Logger.getInstance(PsiChangeListener.class);
        private final Project project;
        // Throttle mechanism for PSI events
        private static final AtomicLong lastProcessTime = new AtomicLong(0);
        private static final long PSI_THROTTLE_MS = 500; // 500ms throttle for PSI events

        public PsiChangeListener(Project project) {
            this.project = project;
        }

        @Override
        public void childrenChanged(@NotNull PsiTreeChangeEvent event) {
            processEvent(event);
        }

        @Override
        public void childAdded(@NotNull PsiTreeChangeEvent event) {
            processEvent(event);
        }

        @Override
        public void childRemoved(@NotNull PsiTreeChangeEvent event) {
            processEvent(event);
        }

        @Override
        public void childReplaced(@NotNull PsiTreeChangeEvent event) {
            processEvent(event);
        }

        private void processEvent(@NotNull PsiTreeChangeEvent event) {
            PsiFile file = event.getFile();
            if (file instanceof HarbourFile) {
                // Throttle PSI events
                long currentTime = System.currentTimeMillis();
                long lastTime = lastProcessTime.get();

                if (currentTime - lastTime > PSI_THROTTLE_MS) {
                    // Try to update the timestamp
                    if (lastProcessTime.compareAndSet(lastTime, currentTime)) {
                        // Update the reference service when a file changes
                        LOG.info("Harbour file modified: " + file.getName());
                        HarbourLogger.log("FileListener", "PSI tree changed, updating references for " + file.getName());

                        // Run in a background thread to avoid UI freezes
                        com.intellij.openapi.application.ApplicationManager.getApplication().executeOnPooledThread(() -> {
                            HarbourReferenceService referenceService =
                                    HarbourReferenceService.getInstance(project);

                            // Clear caches and re-register declarations
                            referenceService.forceClearCaches();

                            ReadAction.run(() -> {
                                referenceService.registerFunctions((HarbourFile) file);
                                referenceService.registerProcedures((HarbourFile) file);
                                referenceService.registerClasses((HarbourFile) file);
                                HarbourFunctionDeclarationCache.clearCache(project);

                                // Force token-based reference attachment
                                HarbourTokenTypeExtension.processFile(file);

                                // Also process changed element and its children
                                PsiElement element = event.getChild();
                                if (element != null) {
                                    processElementReferences(element);
                                }
                            });
                        });
                    }
                } else {
                    LOG.debug("Skipping PSI event for " + file.getName() + " (throttled)");
                }
            }
        }

        /**
         * Process references for an element and its children.
         */
        private void processElementReferences(PsiElement element) {
            // Check if this element needs a reference
            if (element.getNode() != null &&
                    element.getNode().getElementType() == HarbourTypes.IDENT) {

                // Try to add a reference if it doesn't have one
                if (element.getReferences().length == 0) {
                    HarbourTokenTypeExtension.createReferenceForIdent(element);
                }
            }

            // Process children
            for (PsiElement child : element.getChildren()) {
                processElementReferences(child);
            }
        }
    }
}
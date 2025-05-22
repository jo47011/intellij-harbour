package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.TokenType;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.reference.HarbourReference;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

/**
 * Utility for processing Harbour tokens
 */
public class HarbourTokenTypeExtension {
    private static final Logger LOG = Logger.getInstance(HarbourTokenTypeExtension.class);
    private static boolean isReformatting = false;

    // Thread-local formatting flag to handle parallel formatting operations
    private static final ThreadLocal<Boolean> FORMATTING_IN_PROGRESS = new ThreadLocal<>();

    /**
     * Process a file to find and resolve references
     * @return Number of references processed
     */
    public static int processFile(PsiFile file) {
        if (!(file instanceof HarbourFile)) {
            return 0;
        }

        // Don't process during formatting operations (check both flags)
        if (isReformatting || isFormattingInProgress()) {
            HarbourLogger.log("TokenTypeExtension", "Skipping reference processing during formatting operation");
            return 0;
        }

        // Skip if file is not valid
        if (!file.isValid()) {
            HarbourLogger.log("TokenTypeExtension", "Skipping invalid file: " + file.getName());
            return 0;
        }

        // Process on a background thread to avoid UI freezes
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                ReadAction.run(() -> {
                    // Recheck validity inside read action
                    if (!file.isValid()) {
                        HarbourLogger.log("TokenTypeExtension", "File became invalid during processing: " + file.getName());
                        return;
                    }

                    // Safety check for being disposed
                    Project project = file.getProject();
                    if (project.isDisposed()) {
                        HarbourLogger.log("TokenTypeExtension", "Project is disposed, skipping processing");
                        return;
                    }

                    // Make sure the document is committed
                    Document document = PsiDocumentManager.getInstance(project).getDocument(file);
                    if (document != null && PsiDocumentManager.getInstance(project).isUncommited(document)) {
                        HarbourLogger.log("TokenTypeExtension", "Document not committed, skipping processing");
                        return;
                    }

                    // Process all elements in the file
                    processElements(file);
                });
            } catch (Exception e) {
                if (e instanceof com.intellij.psi.PsiInvalidElementAccessException) {
                    // This is expected during editing/formatting, just log at debug level
                    HarbourLogger.log("TokenTypeExtension", "Reference processing skipped due to invalid elements - normal during editing");
                } else {
                    // Unexpected error
                    LOG.error("Error processing file references", e);
                }
            }
        });

        // Return a dummy count to satisfy the API
        return 0;
    }

    /**
     * Create a reference for an identifier element
     */
    public static void createReferenceForIdent(PsiElement element) {
        if (element == null || !element.isValid() || isReformatting || isFormattingInProgress()) {
            return;
        }

        try {
            String text = element.getText();
            if (text == null || text.isEmpty()) {
                return;
            }

            // Create a reference but don't do anything with it yet
            // This is just to satisfy the API call from HarbourFileListener
            new HarbourReference(element);
        } catch (Exception e) {
            // Ignore exceptions during reference creation
            if (!(e instanceof com.intellij.psi.PsiInvalidElementAccessException)) {
                HarbourLogger.log("TokenTypeExtension", "Error creating reference: " + e.getMessage());
            }
        }
    }

    /**
     * Process all elements in a file
     */
    private static void processElements(PsiFile file) {
        if (!file.isValid()) return;

        try {
            Collection<PsiElement> elements = PsiTreeUtil.findChildrenOfAnyType(file, PsiElement.class);
            Set<String> processedElements = new HashSet<>();

            for (PsiElement element : elements) {
                // Periodically check for cancellation
                ProgressManager.checkCanceled();

                // Skip if no longer valid
                if (!element.isValid() || !file.isValid()) {
                    continue;
                }

                // Process this element
                try {
                    processElement(element, processedElements);
                } catch (Exception e) {
                    // Don't let one element's error stop processing of others
                    if (e instanceof com.intellij.psi.PsiInvalidElementAccessException) {
                        // Common during editing, just continue
                        continue;
                    } else {
                        HarbourLogger.log("TokenTypeExtension", "Error processing element: " + e.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            // Log any errors during processing
            if (!(e instanceof com.intellij.psi.PsiInvalidElementAccessException)) {
                LOG.error("Error processing elements", e);
            }
        }
    }

    /**
     * Process a single element
     */
    private static void processElement(PsiElement element, Set<String> processedElements) {
        // Skip invalid elements
        if (!element.isValid() || element.getContainingFile() == null || !element.getContainingFile().isValid()) {
            return;
        }

        // Skip whitespace
        if (element.getNode() != null && element.getNode().getElementType() == TokenType.WHITE_SPACE) {
            return;
        }

        String elementText = safeGetElementText(element);
        if (elementText == null || elementText.isEmpty()) {
            return;
        }

        // Skip if we've seen this element text before
        if (processedElements.contains(elementText)) {
            return;
        }
        processedElements.add(elementText);

        // Try to resolve this element if it might be a reference
        try {
            if (element instanceof com.intellij.psi.PsiNamedElement) {
                // Skip common names that aren't likely meaningful references
                if (elementText.equalsIgnoreCase("if") ||
                        elementText.equalsIgnoreCase("else") ||
                        elementText.equalsIgnoreCase("endif") ||
                        elementText.equalsIgnoreCase("do") ||
                        elementText.equalsIgnoreCase("enddo") ||
                        elementText.equalsIgnoreCase("return")) {
                    return;
                }

                HarbourReference reference = findHarbourReference(element);
                if (reference != null) {
                    PsiElement resolved = safeResolveReference(reference);
                    // We've resolved the reference, no need to do anything with it here
                }
            }
        } catch (Exception e) {
            if (e instanceof com.intellij.psi.PsiInvalidElementAccessException) {
                // Element became invalid during processing, common during editing
                return;
            }

            LOG.error("Error resolving reference for " + elementText, e);
        }
    }

    /**
     * Safely get element text, handling potential exceptions
     */
    private static String safeGetElementText(PsiElement element) {
        if (!element.isValid()) return null;

        try {
            return element.getText();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Safely resolve a reference, handling potential exceptions
     */
    private static PsiElement safeResolveReference(HarbourReference reference) {
        try {
            if (reference.getElement() == null || !reference.getElement().isValid()) {
                return null;
            }
            return reference.resolve();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Find a Harbour reference for an element
     */
    private static HarbourReference findHarbourReference(PsiElement element) {
        if (!element.isValid()) return null;

        try {
            // Only get references for valid elements with proper containment
            PsiFile containingFile = element.getContainingFile();
            if (containingFile == null || !containingFile.isValid()) {
                return null;
            }

            // Check if this element has a reference
            return new HarbourReference(element);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Set the formatting flag (to be called from formatter classes)
     */
    public static void setFormattingInProgress(boolean formatting) {
        isReformatting = formatting;

        // Also set the thread-local flag
        if (formatting) {
            FORMATTING_IN_PROGRESS.set(true);
            HarbourLogger.log("TokenTypeExtension", "Formatting flag set ON");
        } else {
            FORMATTING_IN_PROGRESS.remove();
            HarbourLogger.log("TokenTypeExtension", "Formatting flag set OFF");
        }
    }

    /**
     * Check if formatting is currently in progress
     * This is used to prevent recursive formatting or reference resolution during formatting
     */
    public static boolean isFormattingInProgress() {
        Boolean result = FORMATTING_IN_PROGRESS.get();
        return result != null && result;
    }
}
package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.Annotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.editor.colors.EditorColorsManager;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.editor.markup.TextAttributes;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.progress.ProcessCanceledException;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.jetbrains.annotations.NotNull;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Annotator for Harbour function calls.
 * This highlights function calls in different colors based on whether they are internal (defined in project)
 * or external (not defined in project) using dynamic classification.
 */
public class HarbourFunctionCallAnnotator implements Annotator {
    
    // Track file modification times to detect changes
    private static final ConcurrentHashMap<String, Long> fileModificationTimes = new ConcurrentHashMap<>();
    private static final AtomicLong lastIndexingCheck = new AtomicLong(0);
    private static final long INDEXING_THROTTLE_MS = 1000; // Check for changes at most once per second

    @Override
    public void annotate(@NotNull PsiElement element, @NotNull AnnotationHolder holder) {
        try {
            // Dynamic indexing: Check if the current file has changed and needs re-indexing
            checkAndUpdateFileIndex(element);
            
            // Direct token approach - look for any IDENT token
            if (element instanceof LeafPsiElement) {
                LeafPsiElement leaf = (LeafPsiElement) element;

                if (leaf.getElementType() == HarbourCustomTypes.IDENT) {
                    // Check if this looks like a function call
                    if (isFollowedByParenthesis(leaf)) {
                        // Get function name
                        String functionName = leaf.getText();
                        TextRange range = leaf.getTextRange();

                        // Get project
                        Project project = element.getProject();

                        // Record function usage for tracking frequency
                        HarbourFunctionUsageTracker.recordFunctionUsage(project, functionName);

                        // Get color scheme manager
                        EditorColorsManager colorsManager = EditorColorsManager.getInstance();
                        EditorColorsScheme scheme = colorsManager.getGlobalScheme();

                        // Use dynamic classification to determine if function is internal or external
                        HarbourFunctionClassificationService classificationService = 
                            HarbourFunctionClassificationService.getInstance(project);
                        
                        boolean isInternalFunction = classificationService.isInternalFunction(functionName);

                        TextAttributesKey attributesKey;
                        if (isInternalFunction) {
                            // Internal function - use blue color from scheme
                            attributesKey = HarbourSyntaxHighlighter.LOCAL_FUNCTION;
                        } else {
                            // External function - use light blue color from scheme
                            attributesKey = HarbourSyntaxHighlighter.EXTERNAL_FUNCTION;
                        }

                        // Get the attributes from the scheme but don't modify them
                        TextAttributes attributes = scheme.getAttributes(attributesKey);

                        // Apply annotation without forcing an underline
                        holder.newSilentAnnotation(HighlightSeverity.INFORMATION)
                                .range(range)
                                .enforcedTextAttributes(attributes)
                                .create();
                    }
                }
            }
        } catch (ProcessCanceledException e) {
            // Rethrow without logging
            throw e;
        } catch (Exception e) {
            // Log only to standard logger, not HarbourLogger to reduce clutter
            HarbourLogger.error("FunctionCallAnnotator", "Error in annotation: " + e.getMessage());
        }
    }


    /**
     * Check if an element is followed by parenthesis, which would indicate a function call.
     */
    private boolean isFollowedByParenthesis(PsiElement element) {
        PsiElement next = element.getNextSibling();
        int maxDistance = 5; // Maximum tokens to look ahead
        int distance = 0;

        while (next != null && distance < maxDistance) {
            if (next instanceof LeafPsiElement) {
                LeafPsiElement leaf = (LeafPsiElement) next;
                IElementType type = leaf.getElementType();

                if (type == HarbourCustomTypes.LPAREN) {
                    return true;
                } else if (type != com.intellij.psi.TokenType.WHITE_SPACE) {
                    // If we find a non-whitespace token that's not a parenthesis, stop looking
                    break;
                }
            }

            next = next.getNextSibling();
            distance++;
        }

        return false;
    }
    
    /**
     * Check if the current file has changed and update function index if needed.
     * This provides dynamic function indexing without relying on save listeners.
     */
    private void checkAndUpdateFileIndex(@NotNull PsiElement element) {
        long currentTime = System.currentTimeMillis();
        
        // Throttle indexing checks to avoid excessive processing
        if (currentTime - lastIndexingCheck.get() < INDEXING_THROTTLE_MS) {
            return;
        }
        
        lastIndexingCheck.set(currentTime);
        
        try {
            PsiFile psiFile = element.getContainingFile();
            if (psiFile == null) return;
            
            VirtualFile virtualFile = psiFile.getVirtualFile();
            if (virtualFile == null) return;
            
            // Only process Harbour files
            if (!"prg".equalsIgnoreCase(virtualFile.getExtension())) {
                return;
            }
            
            String filePath = virtualFile.getPath();
            long currentModTime = virtualFile.getModificationStamp();
            Long lastKnownModTime = fileModificationTimes.get(filePath);
            
            // Check if file has been modified since last indexing
            if (lastKnownModTime == null || currentModTime > lastKnownModTime) {
                // Check for cancellation before processing
                ProgressManager.checkCanceled();
                
                HarbourLogger.log("FunctionCallAnnotator", "Dynamic indexing: Updating index for " + virtualFile.getName());
                
                // Update modification time first to prevent duplicate processing
                fileModificationTimes.put(filePath, currentModTime);
                
                // Get function classification service and update index for this file
                Project project = element.getProject();
                HarbourFunctionClassificationService classificationService = 
                    HarbourFunctionClassificationService.getInstance(project);
                
                // Check for cancellation before expensive operation
                ProgressManager.checkCanceled();
                classificationService.updateFileInternalFunctions(virtualFile);
                
                // Trigger re-annotation to update function call colors after indexing
                PsiFile currentPsiFile = PsiManager.getInstance(project).findFile(virtualFile);
                if (currentPsiFile != null) {
                    // Schedule re-annotation in a non-blocking way
                    ApplicationManager.getApplication().invokeLater(() -> {
                        DaemonCodeAnalyzer.getInstance(project).restart(currentPsiFile);
                    });
                }
                
                HarbourLogger.log("FunctionCallAnnotator", "Dynamic indexing: Completed for " + virtualFile.getName());
            }
            
        } catch (ProcessCanceledException e) {
            // Control flow exceptions should be rethrown, not logged
            throw e;
        } catch (Exception e) {
            // Log only to standard logger to avoid excessive debug output
            HarbourLogger.error("FunctionCallAnnotator", "Error in dynamic file indexing: " + e.getMessage());
        }
    }
}
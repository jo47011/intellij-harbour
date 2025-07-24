package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.Annotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.colors.EditorColorsManager;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.editor.markup.EffectType;
import com.intellij.openapi.editor.markup.TextAttributes;
import com.intellij.openapi.progress.ProcessCanceledException;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.jetbrains.annotations.NotNull;

import java.awt.*;
import java.util.List;

/**
 * Annotator for Harbour function calls.
 * This highlights function calls in different colors based on whether they are internal (defined in project)
 * or external (not defined in project) using dynamic classification.
 */
public class HarbourFunctionCallAnnotator implements Annotator {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionCallAnnotator.class);

    // No hardcoded functions - use dynamic classification service

    @Override
    public void annotate(@NotNull PsiElement element, @NotNull AnnotationHolder holder) {
        try {
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
                        
                        // Debug logging to understand the issue
                        HarbourLogger.log("FunctionAnnotator", "CLASSIFY: " + functionName + 
                            " -> isInternal=" + isInternalFunction + 
                            ", serviceInitialized=" + classificationService.isInitialized() +
                            ", totalInternal=" + classificationService.getInternalFunctionCount());

                        TextAttributesKey attributesKey;
                        if (isInternalFunction) {
                            // Internal function - use blue color from scheme
                            attributesKey = HarbourSyntaxHighlighter.LOCAL_FUNCTION;
                            HarbourLogger.log("FunctionAnnotator", "DEBUG: Internal function: " + functionName);
                        } else {
                            // External function - use red color from scheme
                            attributesKey = HarbourSyntaxHighlighter.EXTERNAL_FUNCTION;
                            HarbourLogger.log("FunctionAnnotator", "DEBUG: External function: " + functionName);
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
            LOG.error("Error in HarbourFunctionCallAnnotator", e);
            HarbourLogger.log("FunctionAnnotator", "Error: " + e.getMessage());
        }
    }

    // Removed hardcoded standard function check - now using dynamic classification

    // Removed complex function declaration check - now using simple dynamic classification service

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
}
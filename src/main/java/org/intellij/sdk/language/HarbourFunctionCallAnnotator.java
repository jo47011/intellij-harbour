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
 * This highlights function calls in different colors based on whether they are local (defined in project)
 * or external (not defined in project).
 */
public class HarbourFunctionCallAnnotator implements Annotator {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionCallAnnotator.class);

    // List of standard functions that should be considered external
    private static final String[] STANDARD_FUNCTIONS = {
            "chr", "upper", "lower", "trim", "ltrim", "rtrim", "valtype", "transform",
            "empty", "alias", "aadd", "ascan", "asize", "atail", "len", "eval",
            "db_info", "dbf", "recno", "ordname", "str", "substr", "left", "right",
            "val", "int", "dtos", "stod", "day", "month", "year", "date",
            "time", "round", "ceiling", "floor", "max", "min", "abs", "sqrt"
    };

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

                        // Check if the function is defined in the project
                        boolean isLocalFunction = isFunctionDeclaredInProject(functionName, project);

                        TextAttributesKey attributesKey;
                        if (isLocalFunction && !isStandardFunction(functionName)) {
                            // Local function - use blue color from scheme
                            attributesKey = HarbourSyntaxHighlighter.LOCAL_FUNCTION;
                            HarbourLogger.log("FunctionAnnotator", "DEBUG: Local function: " + functionName);
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

    /**
     * Check if a function name is a standard function
     * @param functionName The function name to check
     * @return true if it's a standard function
     */
    private boolean isStandardFunction(String functionName) {
        // Use the fast cache for standard function lookup
        return HarbourStandardFunctionCache.isStandardFunction(functionName);
    }

    /**
     * Check if the function is declared somewhere in the project using ReferenceService
     * @param functionName The function name to check
     * @param project The current project
     * @return true if the function is declared in the project, false otherwise
     */
    private boolean isFunctionDeclaredInProject(String functionName, Project project) {
        // First check if it's a well-known standard function that should be treated as external
        if (isStandardFunction(functionName)) {
            HarbourLogger.log("FunctionAnnotator", "Standard function detected: " + functionName + " - treating as external");
            return false;
        }

        // Check if we already know the status of this function from previous lookups
        if (HarbourFunctionUsageTracker.isFrequentlyUsed(project, functionName)) {
            // For frequently used functions, assume they're local during initial rendering
            // This prevents flickering during initial load
            boolean isLocal = HarbourFunctionUsageTracker.isFunctionLocal(project, functionName);
            HarbourLogger.log("FunctionAnnotator", "Frequently used function: " + functionName +
                    ", known status: " + (isLocal ? "LOCAL" : "status unknown, assuming LOCAL"));
            return true;
        }

        // Use the reference service for actual lookup
        try {
            HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);
            List<PsiElement> declarations = referenceService.findFunctions(functionName);

            boolean found = !declarations.isEmpty();

            // Store the result for future lookups
            HarbourFunctionUsageTracker.updateFunctionStatus(project, functionName, found);

            HarbourLogger.log("FunctionAnnotator", "Found " + declarations.size() + " declarations for: " + functionName);
            return found;
        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("FunctionAnnotator", "Error checking if function exists: " + e.getMessage());
            return false;
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
}
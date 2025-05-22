package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.Annotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.editor.DefaultLanguageHighlighterColors;
import com.intellij.psi.PsiElement;
import org.intellij.sdk.language.psi.FunctionCall;
import org.jetbrains.annotations.NotNull;

/**
 * General annotator for Harbour elements.
 * Provides syntax highlighting and error checking.
 */
public class HarbourAnnotator implements Annotator {
    @Override
    public void annotate(@NotNull PsiElement element, @NotNull AnnotationHolder holder) {
        // Handle function calls
        if (element instanceof FunctionCall) {
            FunctionCall functionCall = (FunctionCall) element;
            PsiElement nameIdentifier = functionCall.getNameIdentifier();

            if (nameIdentifier != null) {
                // Highlight function names
                holder.newSilentAnnotation(HighlightSeverity.INFORMATION)
                        .range(nameIdentifier.getTextRange())
                        .textAttributes(DefaultLanguageHighlighterColors.FUNCTION_CALL)
                        .create();
            }
        }
    }
}
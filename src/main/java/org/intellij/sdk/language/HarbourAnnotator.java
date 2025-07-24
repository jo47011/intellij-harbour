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
        // Function call highlighting is now handled by HarbourFunctionCallAnnotator
        // which provides internal/external function distinction
        
        // Add other annotations here if needed in the future
    }
}
package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.Annotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.psi.PsiElement;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.jetbrains.annotations.NotNull;

/**
 * Annotator to highlight specific identifier text as keywords
 */
public class HarbourKeywordAnnotator implements Annotator {
    
    @Override
    public void annotate(@NotNull PsiElement element, @NotNull AnnotationHolder holder) {
        // Only process identifier tokens
        if (element instanceof LeafPsiElement && 
            ((LeafPsiElement) element).getElementType() == HarbourCustomTypes.IDENT) {
            
            String text = element.getText().toLowerCase();
            
            // Check for keywords that should be highlighted
            if ("each".equals(text) || "in".equals(text)) {
                // Apply keyword highlighting
                holder.newSilentAnnotation(HighlightSeverity.INFORMATION)
                      .range(element)
                      .textAttributes(HarbourSyntaxHighlighter.KEYWORD)
                      .create();
            }
        }
    }
}
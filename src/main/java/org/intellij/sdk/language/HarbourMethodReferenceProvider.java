package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;

/**
 * Provider for Harbour method references
 */
public class HarbourMethodReferenceProvider extends PsiReferenceProvider {
    private static final Logger LOG = Logger.getInstance(HarbourMethodReferenceProvider.class);
    private static final String COMPONENT = "MethodRefProvider";

    @Override
    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element, @NotNull ProcessingContext context) {
        HarbourLogger.log(COMPONENT, "Getting references for: " + element.getText() + ", class: " + element.getClass().getName());

        // Handle different types of elements
        if (element instanceof FunctionCallImpl) {
            FunctionCallImpl functionCall = (FunctionCallImpl) element;
            String text = functionCall.getText();
            int parenIndex = text.indexOf('(');

            if (parenIndex > 0) {
                String methodName = text.substring(0, parenIndex);
                HarbourLogger.log(COMPONENT, "Found function call: " + methodName);

                return new PsiReference[]{
                        new HarbourMethodReference(element, new TextRange(0, parenIndex))
                };
            }
        } else if (element instanceof LeafPsiElement) {
            LeafPsiElement leafElement = (LeafPsiElement) element;
            String elementType = leafElement.getElementType().toString();

            if (elementType.contains("IDENT")) {
                HarbourLogger.log(COMPONENT, "Found identifier: " + element.getText());

                return new PsiReference[]{
                        new HarbourMethodReference(element, new TextRange(0, element.getTextLength()))
                };
            }
        }

        return PsiReference.EMPTY_ARRAY;
    }
}
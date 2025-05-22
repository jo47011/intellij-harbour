package org.intellij.sdk.language;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReference;
import org.intellij.sdk.language.psi.FunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Special PSI element for function call identifiers with built-in reference support.
 */
public class HarbourFunctionCallIdElement extends ASTWrapperPsiElement {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionCallIdElement.class);

    public HarbourFunctionCallIdElement(@NotNull ASTNode node) {
        super(node);
        LOG.info("Created function call ID element: " + node.getText());
        System.out.println("Created function call ID element: " + node.getText());
    }

    @Override
    public PsiReference getReference() {
        LOG.info("getReference called for function call: " + getText());
        System.out.println("getReference called for function call: " + getText());
        return new DirectFunctionReference(this);
    }

    /**
     * Direct function reference implementation
     */
    private static class DirectFunctionReference implements PsiReference {
        private final HarbourFunctionCallIdElement myElement;

        public DirectFunctionReference(HarbourFunctionCallIdElement element) {
            myElement = element;
            LOG.info("Created DirectFunctionReference for: " + element.getText());
            System.out.println("Created DirectFunctionReference for: " + element.getText());
        }

        @Override
        public @NotNull PsiElement getElement() {
            return myElement;
        }

        @Override
        public @NotNull TextRange getRangeInElement() {
            return new TextRange(0, myElement.getTextLength());
        }

        @Override
        public @Nullable PsiElement resolve() {
            LOG.info("Resolving function call: " + myElement.getText());
            System.out.println("Resolving function call: " + myElement.getText());

            HarbourFile file = (HarbourFile) myElement.getContainingFile();
            String funcName = myElement.getText();

            for (FunctionDeclaration func : file.getFunctionDeclarations()) {
                for (PsiElement child : func.getChildren()) {
                    if (child.getNode() != null &&
                        child.getNode().getElementType() == HarbourTypes.IDENT &&
                        child.getText().equalsIgnoreCase(funcName)) {

                        LOG.info("Resolved to: " + func.getText());
                        System.out.println("Resolved to: " + func.getText());
                        return func;
                    }
                }
            }

            LOG.info("Could not resolve: " + funcName);
            System.out.println("Could not resolve: " + funcName);
            return null;
        }

        @Override
        public @NotNull String getCanonicalText() {
            return myElement.getText();
        }

        @Override
        public PsiElement handleElementRename(@NotNull String newElementName) {
            return myElement;
        }

        @Override
        public PsiElement bindToElement(@NotNull PsiElement element) {
            return myElement;
        }

        @Override
        public boolean isReferenceTo(@NotNull PsiElement element) {
            return resolve() == element;
        }

        @Override
        public boolean isSoft() {
            return false;
        }
    }
}
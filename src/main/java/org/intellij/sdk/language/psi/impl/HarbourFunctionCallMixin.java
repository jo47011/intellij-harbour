package org.intellij.sdk.language.psi.impl;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import com.intellij.psi.PsiReference;
import org.intellij.sdk.language.HarbourLogger;
import org.intellij.sdk.language.psi.FunctionCall;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.reference.HarbourFunctionReference;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Mixin for function call PSI elements.
 */
public abstract class HarbourFunctionCallMixin extends ASTWrapperPsiElement implements FunctionCall, PsiNameIdentifierOwner {

    public HarbourFunctionCallMixin(@NotNull ASTNode node) {
        super(node);
        HarbourLogger.log("FunctionCallMixin", "Created function call mixin: " + node.getText());
    }

    @Override
    public PsiReference getReference() {
        HarbourLogger.log("FunctionCallMixin", "getReference called for function: " + getText());
        return new HarbourFunctionReference(this);
    }

    /**
     * Gets the identifier element of this function call
     * @return the identifier element
     */
    @Nullable
    public PsiElement getIdentifier() {
        // Try to find the IDENT child first
        ASTNode identNode = getNode().findChildByType(HarbourTypes.IDENT);
        if (identNode != null) {
            HarbourLogger.log("FunctionCallMixin", "Found IDENT node: " + identNode.getText());
            return identNode.getPsi();
        }

        // Fallback: Extract function name from text
        HarbourLogger.log("FunctionCallMixin", "Checking for identifier in: " + getText());
        String text = getText();
        int parenIndex = text.indexOf('(');
        if (parenIndex > 0) {
            String functionName = text.substring(0, parenIndex);
            HarbourLogger.log("FunctionCallMixin", "Extracted function name: " + functionName);

            // Check if there's a node that matches this name
            for (ASTNode child : getNode().getChildren(null)) {
                HarbourLogger.log("FunctionCallMixin", "  Child node: " + child.getText() + " - Type: " + child.getElementType());
                if (child.getText().equals(functionName)) {
                    HarbourLogger.log("FunctionCallMixin", "  Found matching child node for function name");
                    return child.getPsi();
                }
            }

            // If no matching child node, use the node itself as fallback
            HarbourLogger.log("FunctionCallMixin", "  No matching child node, using node text directly: " + functionName);
            return new HarbourIdentifierElement(getNode(), functionName);
        }

        HarbourLogger.log("FunctionCallMixin", "No function name pattern found in: " + text);
        return null;
    }

    @Override
    @Nullable
    public PsiElement getNameIdentifier() {
        return getIdentifier();
    }

    @Override
    public String getName() {
        PsiElement nameElement = getNameIdentifier();
        if (nameElement != null) {
            HarbourLogger.log("FunctionCallMixin", "Function name is: " + nameElement.getText());
            return nameElement.getText();
        }

        // Fallback: Extract name from text directly
        String text = getText();
        int parenIndex = text.indexOf('(');
        if (parenIndex > 0) {
            String functionName = text.substring(0, parenIndex);
            HarbourLogger.log("FunctionCallMixin", "Extracted function name directly: " + functionName);
            return functionName;
        }

        HarbourLogger.log("FunctionCallMixin", "Function name is null");
        return null;
    }

    @Override
    public PsiElement setName(@NotNull String name) {
        return this;
    }

    /**
     * Simple identifier element implementation to use when no actual child node is available
     */
    private static class HarbourIdentifierElement extends ASTWrapperPsiElement {
        private final String myName;

        public HarbourIdentifierElement(ASTNode node, String name) {
            super(node);
            this.myName = name;
        }

        @Override
        public String getText() {
            return myName;
        }
    }
}
package org.intellij.sdk.language.psi.impl;

import com.intellij.psi.PsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.lang.ASTNode;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

/**
 * Factory for creating custom PSI elements with proper implementation classes.
 */
public class HarbourPsiElementFactoryImpl {
    /**
     * Create the appropriate PSI element for a given node.
     * Handles special cases like ClassDeclaration where we need getCls() instead of getClass().
     *
     * @param node The AST node to create a PSI element for
     * @return The created PSI element
     */
    public static PsiElement createElement(@NotNull ASTNode node) {
        IElementType type = node.getElementType();

        // Handle specific element types
        if (type == HarbourTypes.CLASS_DECLARATION) {
            return new ClassDeclarationImplWrapper(node);
        }

        // Default handling by returning null lets Grammar-Kit use standard implementation
        return null;
    }

    /**
     * Wrapper class that overrides getClass() by implementing getCls()
     */
    private static class ClassDeclarationImplWrapper extends ClassDeclarationImpl {
        public ClassDeclarationImplWrapper(@NotNull ASTNode node) {
            super(node);
        }

        /**
         * Provide an implementation for getCls() to avoid Object.getClass() conflict
         */
        public PsiElement getCls() {
            return findChildByType(HarbourCustomTypes.IDENT);
        }
    }
}
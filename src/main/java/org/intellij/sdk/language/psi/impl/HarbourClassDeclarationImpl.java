package org.intellij.sdk.language.psi.impl;

import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Implementation for Harbour class declarations.
 * Handles name resolution for class declarations.
 */
public abstract class HarbourClassDeclarationImpl extends HarbourNamedElementImpl implements ClassDeclaration {

    public HarbourClassDeclarationImpl(@NotNull ASTNode node) {
        super(node);
    }

    /**
     * Get the name identifier for this class declaration.
     * This is the IDENT token after the CLASS keyword.
     *
     * @return The PSI element representing the name identifier
     */
    @Nullable
    @Override
    public PsiElement getNameIdentifier() {
        // Find the IDENT element corresponding to the class name
        // In the BNF, it's defined as 'className ::= IDENT { name="cls" }'
        PsiElement classNameElement = findChildByType(HarbourTypes.IDENT);
        if (classNameElement != null) {
            return classNameElement;
        }

        // Fallback: look for first IDENT after CLASS keyword
        PsiElement classKeyword = findChildByType(HarbourTypes.CLASS);
        if (classKeyword != null) {
            PsiElement nextSibling = classKeyword.getNextSibling();
            while (nextSibling != null) {
                if (nextSibling.getNode() != null &&
                        nextSibling.getNode().getElementType() == HarbourTypes.IDENT) {
                    return nextSibling;
                }
                nextSibling = nextSibling.getNextSibling();
            }
        }

        return null;
    }

    /**
     * Get the name of this class declaration.
     *
     * @return The name of the class declaration
     */
    @Override
    public String getName() {
        PsiElement nameIdentifier = getNameIdentifier();
        return nameIdentifier != null ? nameIdentifier.getText() : null;
    }

    /**
     * Get the inherit element if it exists.
     *
     * @return The inherit element
     */
    @Nullable
    public PsiElement getInherit() {
        return findChildByType(HarbourTypes.INHERIT);
    }

    /**
     * Get the parent class name if this class inherits from another.
     *
     * @return The parent class name, or null if none
     */
    @Nullable
    public String getParentClassName() {
        PsiElement inheritElement = getInherit();
        if (inheritElement != null) {
            // Find the IDENT after INHERIT
            PsiElement nextSibling = inheritElement.getNextSibling();
            while (nextSibling != null) {
                if (nextSibling.getNode() != null &&
                        nextSibling.getNode().getElementType() == HarbourTypes.IDENT) {
                    return nextSibling.getText();
                }
                nextSibling = nextSibling.getNextSibling();
            }
        }
        return null;
    }
}
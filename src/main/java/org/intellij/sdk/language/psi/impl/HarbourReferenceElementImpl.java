package org.intellij.sdk.language.psi.impl;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReference;
import org.intellij.sdk.language.psi.HarbourReferenceElement;
import org.intellij.sdk.language.reference.HarbourReference;
import org.jetbrains.annotations.NotNull;

/**
 * Base implementation class for Harbour reference elements.
 */
public class HarbourReferenceElementImpl extends ASTWrapperPsiElement implements HarbourReferenceElement {

    public HarbourReferenceElementImpl(@NotNull ASTNode node) {
        super(node);
    }

    @Override
    public PsiReference getReference() {
        PsiElement identElement = getIdentifierElement();
        if (identElement != null) {
            // Use just this as parameter, since we've updated HarbourReference to accept PsiElement
            return new HarbourReference(identElement);
        }
        return null;
    }

    @Override
    public PsiElement getIdentifierElement() {
        // Simple implementation - in most cases, the identifier is the first child
        // This might need to be customized depending on your grammar
        return getFirstChild();
    }
}
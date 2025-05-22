package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;

/**
 * Interface for Harbour elements that can have references.
 */
public interface HarbourReferenceElement extends PsiElement {
    /**
     * Returns the identifier element that serves as the reference source.
     *
     * @return the identifier element
     */
    PsiElement getIdentifierElement();
}
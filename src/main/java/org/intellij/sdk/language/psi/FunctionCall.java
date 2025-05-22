package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import org.jetbrains.annotations.Nullable;

/**
 * Interface for function call PSI elements.
 */
public interface FunctionCall extends HarbourPsiElement {
    /**
     * Gets the identifier element of this function call
     * @return the identifier element
     */
    @Nullable
    PsiElement getIdentifier();

    /**
     * Gets the name identifier element of this function call.
     * This is an alias for getIdentifier() for compatibility.
     * @return the name identifier element
     */
    @Nullable
    default PsiElement getNameIdentifier() {
        return getIdentifier();
    }

    /**
     * Gets the name of this function call.
     * @return the name of the function call
     */
    @Nullable
    default String getName() {
        PsiElement identifier = getNameIdentifier();
        return identifier != null ? identifier.getText() : null;
    }
}
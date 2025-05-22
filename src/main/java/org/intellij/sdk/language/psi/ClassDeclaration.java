package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import org.jetbrains.annotations.Nullable;
import java.util.List;

public interface ClassDeclaration extends HarbourPsiElement, PsiElement {
    // Basic interface for Grammar-Kit to implement
    List<Statement> getStatementList();

    /**
     * Get the name of the class declaration.
     *
     * @return The name of the class or null if not found
     */
    @Nullable
    String getName();

    /**
     * Get the name identifier element for this class declaration.
     *
     * @return The name identifier element or null if not found
     */
    @Nullable
    PsiElement getNameIdentifier();
}
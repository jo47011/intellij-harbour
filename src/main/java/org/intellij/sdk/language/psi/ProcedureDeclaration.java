package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNamedElement;
import org.jetbrains.annotations.Nullable;
import java.util.List;

public interface ProcedureDeclaration extends HarbourPsiElement, PsiElement, PsiNamedElement {
    // Basic interface for Grammar-Kit to implement
    @Nullable ParameterList getParameterList();
    List<Statement> getStatementList();

    /**
     * Gets the name of the procedure.
     *
     * @return The name of the procedure
     */
    @Override
    @Nullable
    String getName();
}
package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import java.util.List;

public interface FunctionDeclaration extends HarbourNamedElement {
    @Nullable ParameterList getParameterList();

    @NotNull List<Statement> getStatementList();

    @Nullable
    PsiElement getNameIdentifier();

    @Nullable
    String getName();
}
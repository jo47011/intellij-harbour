package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public interface HarbourFunctionDeclaration extends PsiNameIdentifierOwner {
    @Nullable
    PsiElement getNameIdentifier();

    @NotNull
    String getName();

    PsiElement setName(@NotNull String name);
}
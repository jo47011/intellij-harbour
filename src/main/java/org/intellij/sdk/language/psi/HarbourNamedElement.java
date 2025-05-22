package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public interface HarbourNamedElement extends HarbourPsiElement, PsiNameIdentifierOwner {
    @Nullable
    String getName();

    @Nullable
    PsiElement getNameIdentifier();

    @NotNull
    PsiElement setName(@NotNull String name);
}
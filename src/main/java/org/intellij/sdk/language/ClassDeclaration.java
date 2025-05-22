package org.intellij.sdk.language;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Interface for Harbour class declarations
 */
public interface ClassDeclaration extends PsiNameIdentifierOwner {
    @Nullable
    PsiElement getNameIdentifier();

    @NotNull
    String getName();

    PsiElement setName(@NotNull String name);
}
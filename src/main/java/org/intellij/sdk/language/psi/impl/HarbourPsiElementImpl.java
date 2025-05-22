package org.intellij.sdk.language.psi.impl;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import org.intellij.sdk.language.psi.HarbourPsiElement;
import org.jetbrains.annotations.NotNull;

/**
 * Base implementation class for all Harbour PSI elements.
 */
public abstract class HarbourPsiElementImpl extends ASTWrapperPsiElement implements HarbourPsiElement {
    public HarbourPsiElementImpl(@NotNull ASTNode node) {
        super(node);
    }
}
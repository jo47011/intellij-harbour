package org.intellij.sdk.language.psi.impl;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.HarbourLogger;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.intellij.sdk.language.psi.HarbourNamedElement;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Base implementation for named elements in Harbour
 */
public abstract class HarbourNamedElementImpl extends ASTWrapperPsiElement implements HarbourNamedElement, PsiNameIdentifierOwner {

    public HarbourNamedElementImpl(@NotNull ASTNode node) {
        super(node);
    }

    @Override
    @Nullable
    public String getName() {
        PsiElement nameElement = getNameIdentifier();
        return nameElement != null ? nameElement.getText() : null;
    }

    @Override
    @NotNull
    public PsiElement setName(@NotNull String name) throws IncorrectOperationException {
        HarbourLogger.log("NamedElementImpl", "Setting name from: " + getName() + " to: " + name);

        PsiElement nameIdentifier = getNameIdentifier();
        if (nameIdentifier != null) {
            // Create a new identifier with the new name
            PsiElement newNameIdentifier = HarbourElementFactory.createIdentifier(getProject(), name);

            // Replace the old identifier with the new one
            if (newNameIdentifier != null) {
                nameIdentifier.replace(newNameIdentifier);
                HarbourLogger.log("NamedElementImpl", "Name updated successfully");
            } else {
                HarbourLogger.log("NamedElementImpl", "Failed to create new identifier");
            }
        } else {
            HarbourLogger.log("NamedElementImpl", "No name identifier found");
        }

        return this;
    }

    @Override
    @Nullable
    public PsiElement getNameIdentifier() {
        // Find the first IDENT child and return it as the name identifier
        for (PsiElement child : getChildren()) {
            if (child.getNode() != null && child.getNode().getElementType() == HarbourCustomTypes.IDENT) {
                return child;
            }
        }
        return null;
    }

    @Override
    public int getTextOffset() {
        PsiElement nameIdentifier = getNameIdentifier();
        return nameIdentifier != null ? nameIdentifier.getTextOffset() : super.getTextOffset();
    }
}
package org.intellij.sdk.language;

import com.intellij.lang.ASTNode;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.*;
import com.intellij.psi.impl.light.LightElement;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Wrapper to make LeafPsiElement renameable by implementing PsiNamedElement.
 * This allows rename dialog to show the current name.
 */
public class HarbourNamedElementWrapper extends LightElement implements PsiNamedElement, PsiNameIdentifierOwner {
    private final PsiElement myElement;
    private final String myName;
    
    public HarbourNamedElementWrapper(@NotNull PsiElement element) {
        super(element.getManager(), HarbourLanguage.INSTANCE);
        this.myElement = element;
        this.myName = element.getText();
        HarbourLogger.log("NamedElementWrapper", "Created wrapper for: " + myName);
    }
    
    @Override
    public String getText() {
        return myName;
    }
    
    @Override
    public void accept(@NotNull PsiElementVisitor visitor) {
        visitor.visitElement(this);
    }
    
    @Override
    public PsiElement copy() {
        return new HarbourNamedElementWrapper(myElement);
    }
    
    @Override
    public String getName() {
        HarbourLogger.log("NamedElementWrapper", "getName() returning: " + myName);
        return myName;
    }
    
    @Override
    public PsiElement setName(@NotNull String name) throws IncorrectOperationException {
        HarbourLogger.log("NamedElementWrapper", "setName() called with: " + name);
        // Try to replace the actual element
        if (myElement.isValid()) {
            try {
                PsiElement newElement = HarbourElementFactory.createIdentifier(myElement.getProject(), name);
                if (newElement != null) {
                    return myElement.replace(newElement);
                }
            } catch (Exception e) {
                HarbourLogger.log("NamedElementWrapper", "Error in setName: " + e.getMessage());
            }
        }
        return myElement;
    }
    
    @Override
    public @Nullable PsiElement getNameIdentifier() {
        return myElement;
    }
    
    @Override
    public boolean isValid() {
        return myElement.isValid();
    }
    
    @Override
    public @NotNull TextRange getTextRange() {
        return myElement.getTextRange();
    }
    
    @Override
    public int getTextOffset() {
        return myElement.getTextOffset();
    }
    
    @Override
    public ASTNode getNode() {
        return myElement.getNode();
    }
    
    @Override
    public PsiFile getContainingFile() {
        return myElement.getContainingFile();
    }
    
    @Override
    public PsiElement getNavigationElement() {
        return myElement;
    }
    
    @Override
    public PsiElement getOriginalElement() {
        return myElement;
    }
    
    public PsiElement getWrappedElement() {
        return myElement;
    }
    
    @Override
    public String toString() {
        return "HarbourNamedElementWrapper(" + myName + ")";
    }
}
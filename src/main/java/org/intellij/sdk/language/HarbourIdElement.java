package org.intellij.sdk.language;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import com.intellij.psi.PsiNamedElement;
import com.intellij.psi.PsiReference;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.psi.search.LocalSearchScope;
import com.intellij.psi.search.SearchScope;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Custom PSI element for Harbour identifiers.
 */
public class HarbourIdElement extends ASTWrapperPsiElement implements PsiNamedElement, PsiNameIdentifierOwner {
    private static final Logger LOG = Logger.getInstance(HarbourIdElement.class);
    private static final String COMPONENT = "IdElement";

    public HarbourIdElement(@NotNull ASTNode node) {
        super(node);
        HarbourLogger.log(COMPONENT, "Created ID element: " + node.getText());
    }

    @Nullable
    @Override
    public String getName() {
        HarbourLogger.log(COMPONENT, "getName called, returning: " + getText());
        return getText();
    }

    @Override
    public PsiElement setName(@NotNull String name) throws IncorrectOperationException {
        HarbourLogger.log(COMPONENT, "setName called: " + getName() + " to " + name);
        try {
            PsiElement newElement = HarbourElementFactory.createIdentifier(getProject(), name);
            if (newElement != null) {
                HarbourLogger.log(COMPONENT, "New element created successfully: " + newElement.getText());
                return this.replace(newElement);
            } else {
                HarbourLogger.log(COMPONENT, "Failed to create new element");
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Exception during setName: " + e.getMessage());
            HarbourLogger.logStackTrace(COMPONENT, e);
        }
        return this;
    }

    @Override
    public @Nullable PsiElement getNameIdentifier() {
        HarbourLogger.log(COMPONENT, "getNameIdentifier called");
        return this;
    }

    @Override
    public int getTextOffset() {
        int offset = getNode().getStartOffset();
        HarbourLogger.log(COMPONENT, "getTextOffset called, returning: " + offset);
        return offset;
    }

    @NotNull
    @Override
    public SearchScope getUseScope() {
        HarbourLogger.log(COMPONENT, "getUseScope called");
        return new LocalSearchScope(getContainingFile());
    }

    @Override
    public PsiReference getReference() {
        HarbourLogger.log(COMPONENT, "getReference called for: " + getText());
        return new PsiReferenceBase<PsiElement>(this) {
            @Override
            public PsiElement resolve() {
                HarbourLogger.log(COMPONENT, "Reference.resolve called, returning element: " + getElement().getText());
                return getElement();
            }

            @Override
            public PsiElement handleElementRename(@NotNull String newElementName) {
                HarbourLogger.log(COMPONENT, "Reference.handleElementRename: " + newElementName);
                return ((HarbourIdElement)getElement()).setName(newElementName);
            }

            @NotNull
            @Override
            public Object[] getVariants() {
                return EMPTY_ARRAY;
            }
        };
    }
}
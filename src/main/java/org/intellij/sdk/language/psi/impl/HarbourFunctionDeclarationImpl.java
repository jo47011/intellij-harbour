package org.intellij.sdk.language.psi.impl;

import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiNameIdentifierOwner;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.FunctionDeclaration;
import org.intellij.sdk.language.psi.ParameterList;
import org.intellij.sdk.language.psi.Statement;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import java.util.List;

/**
 * Implementation of the Harbour function declaration.
 */
public class HarbourFunctionDeclarationImpl extends HarbourNamedElementImpl implements FunctionDeclaration, PsiNameIdentifierOwner {
    public HarbourFunctionDeclarationImpl(@NotNull ASTNode node) {
        super(node);
    }

    @Override
    public String getName() {
        PsiElement nameIdentifier = getNameIdentifier();
        return nameIdentifier != null ? nameIdentifier.getText() : null;
    }

    @Override
    public PsiElement setName(@NotNull String name) throws IncorrectOperationException {
        return this;
    }

    @Nullable
    @Override
    public PsiElement getNameIdentifier() {
        return findChildByType(HarbourCustomTypes.IDENT);
    }

    /**
     * Implements the getIdent() method required by the generated interface.
     */
    @Nullable
    public PsiElement getIdent() {
        return getNameIdentifier();
    }

    /**
     * Implements the getParameterList() method required by the generated interface.
     */
    @Nullable
    public ParameterList getParameterList() {
        return findChildByClass(ParameterList.class);
    }

    /**
     * Implements the getStatementList() method required by the generated interface.
     * Returns all statement elements in the function body.
     */
    @NotNull
    public List<Statement> getStatementList() {
        return PsiTreeUtil.getChildrenOfTypeAsList(this, Statement.class);
    }

}
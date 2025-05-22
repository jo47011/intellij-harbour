package org.intellij.sdk.language.psi.impl;

import com.intellij.lang.ASTNode;
import com.intellij.psi.PsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.Statement;
import org.jetbrains.annotations.NotNull;

import java.util.List;

/**
 * Implementation for ClassDeclaration.
 */
public class ClassDeclarationImpl extends HarbourClassDeclarationImpl implements ClassDeclaration {
    public ClassDeclarationImpl(@NotNull ASTNode node) {
        super(node);
    }

    @NotNull
    @Override
    public List<Statement> getStatementList() {
        return PsiTreeUtil.getChildrenOfTypeAsList(this, Statement.class);
    }
}
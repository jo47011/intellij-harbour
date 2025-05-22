package org.intellij.sdk.language.psi;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiElementVisitor;
import org.jetbrains.annotations.NotNull;

/**
 * A simple visitor so we can recursively find specific Harbour PSI nodes.
 * In a GrammarKit project, you'd normally use the generated HarbourVisitor.
 */
public class HarbourRecursiveElementVisitor extends PsiElementVisitor {

    public void visitFunctionDeclaration(@NotNull HarbourFunctionDeclaration func) {
        // Just call the parent class's visitElement for the same node
        super.visitElement(func);
    }

    public void visitProcedureDeclaration(@NotNull HarbourProcedureDeclaration proc) {
        super.visitElement(proc);
    }

    @Override
    public void visitElement(@NotNull PsiElement element) {
        if (element instanceof HarbourFunctionDeclaration) {
            visitFunctionDeclaration((HarbourFunctionDeclaration) element);
        }
        else if (element instanceof HarbourProcedureDeclaration) {
            visitProcedureDeclaration((HarbourProcedureDeclaration) element);
        }
        else {
            // Default behavior
            super.visitElement(element);
        }
        // Recurse into children
        element.acceptChildren(this);
    }
}

package org.intellij.sdk.language.psi;

import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFileFactory;
import org.intellij.sdk.language.HarbourFileType;
import org.intellij.sdk.language.HarbourLogger;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import com.intellij.lang.ASTNode;

/**
 * Factory for creating Harbour PSI elements.
 */
public class HarbourElementFactory {

    /**
     * Create an identifier element.
     *
     * @param project The current project
     * @param name The name of the identifier
     * @return The identifier PSI element
     */
    public static PsiElement createIdentifier(@NotNull Project project, @NotNull String name) {
        HarbourLogger.log("ElementFactory", "Creating identifier: " + name);

        final HarbourFile file = createFile(project, name);
        PsiElement element = file.getFirstChild();

        if (element == null) {
            HarbourLogger.log("ElementFactory", "Failed to create identifier element");
        }

        return element;
    }

    /**
     * Create a function declaration.
     *
     * @param project The current project
     * @param name The name of the function
     * @return The function declaration element
     */
    @Nullable
    public static FunctionDeclaration createFunction(@NotNull Project project, @NotNull String name) {
        HarbourLogger.log("ElementFactory", "Creating function: " + name);

        final HarbourFile file = createFile(project, "FUNCTION " + name + "()\nRETURN NIL\n");

        // Find the first function declaration in the file
        for (PsiElement child : file.getChildren()) {
            if (child instanceof FunctionDeclaration) {
                HarbourLogger.log("ElementFactory", "Function created successfully");
                return (FunctionDeclaration) child;
            }
        }

        HarbourLogger.log("ElementFactory", "Failed to create function declaration");
        return null;
    }

    /**
     * Create a procedure declaration.
     *
     * @param project The current project
     * @param name The name of the procedure
     * @return The procedure declaration element
     */
    @Nullable
    public static ProcedureDeclaration createProcedure(@NotNull Project project, @NotNull String name) {
        HarbourLogger.log("ElementFactory", "Creating procedure: " + name);

        final HarbourFile file = createFile(project, "PROCEDURE " + name + "()\nRETURN\n");

        // Find the first procedure declaration in the file
        for (PsiElement child : file.getChildren()) {
            if (child instanceof ProcedureDeclaration) {
                HarbourLogger.log("ElementFactory", "Procedure created successfully");
                return (ProcedureDeclaration) child;
            }
        }

        HarbourLogger.log("ElementFactory", "Failed to create procedure declaration");
        return null;
    }

    /**
     * Create a Harbour file with the given text.
     *
     * @param project The current project
     * @param text The text for the file
     * @return The created file
     */
    @NotNull
    public static HarbourFile createFile(@NotNull Project project, @NotNull String text) {
        HarbourLogger.log("ElementFactory", "Creating file with text: " + text);

        String fileName = "dummy.prg";
        try {
            HarbourFile file = (HarbourFile) PsiFileFactory.getInstance(project)
                    .createFileFromText(fileName, HarbourFileType.INSTANCE, text);

            if (file == null) {
                HarbourLogger.log("ElementFactory", "Failed to create file: null result");
            } else {
                HarbourLogger.log("ElementFactory", "File created successfully");
            }

            return file;
        } catch (Exception e) {
            HarbourLogger.log("ElementFactory", "Exception creating file: " + e.getMessage());
            // Create an empty file as fallback
            return (HarbourFile) PsiFileFactory.getInstance(project)
                    .createFileFromText(fileName, HarbourFileType.INSTANCE, "");
        }
    }

    /**
     * Create a generic PSI element from an AST node.
     * This method is used by the parser definition.
     *
     * @param node The AST node
     * @return The created PSI element
     */
    public static PsiElement createElement(ASTNode node) {
        return node.getPsi();
    }
}
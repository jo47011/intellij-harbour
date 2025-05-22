package org.intellij.sdk.language.psi;

import com.intellij.extapi.psi.PsiFileBase;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.fileTypes.FileType;
import com.intellij.psi.FileViewProvider;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiRecursiveElementVisitor;
import org.intellij.sdk.language.HarbourFileType;
import org.intellij.sdk.language.HarbourLanguage;
import org.intellij.sdk.language.HarbourLogger;
import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.List;

/**
 * PSI file implementation for Harbour language
 */
public class HarbourFile extends PsiFileBase {
    private static final Logger LOG = Logger.getInstance(HarbourFile.class);
    private static final String COMPONENT = "File";

    private void debugLog(String message) {
        HarbourLogger.log(COMPONENT, message);
    }

    public HarbourFile(@NotNull FileViewProvider viewProvider) {
        super(viewProvider, HarbourLanguage.INSTANCE);
        debugLog("Created HarbourFile for: " + viewProvider.getVirtualFile().getName());
    }

    @NotNull
    @Override
    public FileType getFileType() {
        return HarbourFileType.INSTANCE;
    }

    @Override
    public String toString() {
        return "Harbour File";
    }

    /**
     * Gets all function declarations in this file
     *
     * @return List of function declarations
     */
    public List<FunctionDeclaration> getFunctionDeclarations() {
        debugLog("Getting function declarations for: " + getName());
        final List<FunctionDeclaration> functionDeclarations = new ArrayList<>();

        try {
            accept(new PsiRecursiveElementVisitor() {
                @Override
                public void visitElement(@NotNull PsiElement element) {
                    if (element instanceof FunctionDeclaration) {
                        FunctionDeclaration function = (FunctionDeclaration) element;
                        String functionName = function.getName();
                        debugLog("Found function: " + (functionName != null ? functionName : "unnamed"));
                        functionDeclarations.add(function);
                    }
                    super.visitElement(element);
                }
            });

            debugLog("Found " + functionDeclarations.size() + " functions in file");

            // Log all found functions and their details
            for (FunctionDeclaration func : functionDeclarations) {
                String name = func.getName();
                PsiElement nameId = func.getNameIdentifier();

                debugLog("Function: " + name +
                        ", NameId: " + (nameId != null ? nameId.getText() : "null") +
                        ", Class: " + func.getClass().getName());

                if (nameId != null) {
                    debugLog("  NameId Class: " + nameId.getClass().getName());
                }
            }
        } catch (Exception e) {
            debugLog("Error getting function declarations: " + e.getMessage());
            e.printStackTrace();
        }

        return functionDeclarations;
    }

    /**
     * Gets all procedures declarations in this file
     *
     * @return List of procedure declarations
     */
    public List<ProcedureDeclaration> getProcedureDeclarations() {
        debugLog("Getting procedure declarations for: " + getName());
        final List<ProcedureDeclaration> procedures = new ArrayList<>();

        try {
            accept(new PsiRecursiveElementVisitor() {
                @Override
                public void visitElement(@NotNull PsiElement element) {
                    if (element instanceof ProcedureDeclaration) {
                        ProcedureDeclaration procedure = (ProcedureDeclaration) element;
                        String name = procedure.getName();
                        debugLog("Found procedure: " + (name != null ? name : "unnamed"));
                        procedures.add(procedure);
                    }
                    super.visitElement(element);
                }
            });

            debugLog("Found " + procedures.size() + " procedures in file");
        } catch (Exception e) {
            debugLog("Error getting procedure declarations: " + e.getMessage());
            e.printStackTrace();
        }

        return procedures;
    }

    /**
     * Finds all declarations (including static ones) by name
     *
     * @param name The name to search for
     * @return List of matching declarations
     */
    public List<PsiElement> findDeclarationsByName(String name) {
        debugLog("Finding declarations with name: " + name);
        HarbourLogger.log(COMPONENT, "Finding declarations with name: " + name);

        final List<PsiElement> results = new ArrayList<>();

        try {
            accept(new PsiRecursiveElementVisitor() {
                @Override
                public void visitElement(@NotNull PsiElement element) {
                    // Check if the element is a named declaration
                    if (element instanceof HarbourNamedElement) {
                        HarbourNamedElement namedElement = (HarbourNamedElement) element;
                        String elementName = namedElement.getName();

                        // We found a potential match
                        if (elementName != null && elementName.equalsIgnoreCase(name)) {
                            String type = element.getClass().getSimpleName();
                            debugLog("Found matching " + type + ": " + elementName);
                            HarbourLogger.log(COMPONENT, "Found matching " + type + ": " + elementName);
                            results.add(element);
                        }
                    }
                    super.visitElement(element);
                }
            });

            debugLog("Found " + results.size() + " declarations matching '" + name + "'");
            HarbourLogger.log(COMPONENT, "Found " + results.size() + " declarations matching '" + name + "'");
        } catch (Exception e) {
            debugLog("Error finding declarations: " + e.getMessage());
            HarbourLogger.log(COMPONENT, "Error finding declarations: " + e.getMessage());
            e.printStackTrace();
        }

        return results;
    }
}
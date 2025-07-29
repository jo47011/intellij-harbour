package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiFileFactory;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * Provider for Harbour functions.
 * Creates virtual declarations for external functions to enable reference resolution.
 * Uses dynamic classification to distinguish between internal and external functions.
 */
public class HarbourStandardFunctionsProvider {
    private static final Logger LOG = Logger.getInstance(HarbourStandardFunctionsProvider.class);
    private static final Map<String, PsiElement> FUNCTION_DECLARATIONS = new HashMap<>();
    private static boolean initialized = false;

    /**
     * Get all external functions as a set.
     * @return Set of all external function names that have been encountered
     */
    public static Set<String> getAllStandardFunctions() {
        // Return the keys of function declarations that have been created
        Set<String> externalFunctions = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        externalFunctions.addAll(FUNCTION_DECLARATIONS.keySet());
        return externalFunctions;
    }

    // No hardcoded functions - use dynamic classification

    /**
     * Initialize the provider.
     * This must be called from a background thread or with proper read action.
     */
    public static void initialize(Project project) {
        if (initialized) {
            return;
        }

        LOG.info("Initializing Harbour functions provider (using dynamic classification)");
        
        // No hardcoded functions to initialize - everything is dynamic now
        initialized = true;
        
        LOG.info("Harbour functions provider initialized with dynamic classification");
    }

    /**
     * Create a virtual declaration for a standard function.
     * This must be called inside a read action.
     */
    private static void createStandardFunctionDeclaration(String functionName, Project project) {
        // Create a temporary file with a function declaration
        String functionText = "FUNCTION " + functionName + "()\nRETURN NIL";

        try {
            // This operation needs to be in a read action
            PsiFile file = PsiFileFactory.getInstance(project)
                    .createFileFromText("stdlib_" + functionName + ".prg",
                            HarbourFileType.INSTANCE, functionText);

            if (file instanceof HarbourFile) {
                // Find the IDENT for the function name
                PsiElement[] children = file.getChildren();
                for (PsiElement child : children) {
                    if (child.getNode() != null &&
                            child.getNode().getElementType() == org.intellij.sdk.language.psi.HarbourTypes.FUNCTION) {
                        PsiElement nextSibling = child.getNextSibling();
                        while (nextSibling != null) {
                            if (nextSibling.getNode() != null &&
                                    nextSibling.getNode().getElementType() == org.intellij.sdk.language.psi.HarbourTypes.IDENT) {
                                FUNCTION_DECLARATIONS.put(functionName.toLowerCase(), nextSibling);
                                break;
                            }
                            nextSibling = nextSibling.getNextSibling();
                        }
                        break;
                    }
                }
            }
        } catch (Exception e) {
            LOG.error("Error creating standard function declaration for " + functionName, e);
        }
    }

    /**
     * Check if a function is an external Harbour function (not declared in the project).
     * This method now uses dynamic classification instead of hardcoded function lists.
     */
    public static boolean isStandardFunction(@NotNull String functionName) {
        // For backward compatibility, we need to determine this dynamically
        // Try to get the project from any open project (this is a limitation of the static method)
        for (Project openProject : com.intellij.openapi.project.ProjectManager.getInstance().getOpenProjects()) {
            HarbourFunctionClassificationService classificationService = 
                HarbourFunctionClassificationService.getInstance(openProject);
            if (classificationService.isInitialized()) {
                return classificationService.isExternalFunction(functionName);
            }
        }
        // If no project available or not initialized, assume external for safety
        return true;
    }

    /**
     * Get the declaration for a standard Harbour function.
     */
    public static PsiElement getStandardFunctionDeclaration(@NotNull String functionName) {
        PsiElement element = FUNCTION_DECLARATIONS.get(functionName.toLowerCase());

        // Ensure we have a valid element that won't cause PsiInvalidElementAccessException
        if (element != null) {
            try {
                if (element.isValid() && element.getContainingFile() != null) {
                    return element;
                }
            } catch (Exception e) {
                LOG.warn("Invalid standard function declaration for: " + functionName);
                // Fall through to create a safer version
            }

            // If the element has issues, recreate it in the project
            String funcName = functionName.toLowerCase();
            for (Project project : com.intellij.openapi.project.ProjectManager.getInstance().getOpenProjects()) {
                try {
                    createStandardFunctionDeclaration(funcName, project);
                    // Try to get the newly created declaration
                    PsiElement newElement = FUNCTION_DECLARATIONS.get(funcName);
                    if (newElement != null && newElement.isValid()) {
                        return newElement;
                    }
                } catch (Exception e) {
                    LOG.warn("Failed to recreate standard function: " + funcName, e);
                }
            }
        }

        return element;
    }

    /**
     * Add a function as an external function by creating a virtual declaration.
     * This is used when we encounter a function call that is not defined internally.
     */
    public static void addStandardFunction(@NotNull String functionName, Project project) {
        final String lowerName = functionName.toLowerCase();

        if (!FUNCTION_DECLARATIONS.containsKey(lowerName)) {
            // Add declaration in a read action
            ApplicationManager.getApplication().invokeLater(() -> {
                ReadAction.run(() -> {
                    createStandardFunctionDeclaration(lowerName, project);
                });
            });
        }
    }
}
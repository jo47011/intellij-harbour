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

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * Provider for standard Harbour functions.
 * Creates virtual declarations for standard functions to enable reference resolution.
 */
public class HarbourStandardFunctionsProvider {
    private static final Logger LOG = Logger.getInstance(HarbourStandardFunctionsProvider.class);
    private static final Set<String> STANDARD_FUNCTIONS = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
    private static final Map<String, PsiElement> FUNCTION_DECLARATIONS = new HashMap<>();
    private static boolean initialized = false;

    /**
     * Get all standard functions as a set.
     * @return Set of all standard function names
     */
    public static Set<String> getAllStandardFunctions() {
        return new TreeSet<>(STANDARD_FUNCTIONS);
    }

    // Initialize with common Harbour/Clipper functions
    static {
        // String functions
        STANDARD_FUNCTIONS.add("upper");
        STANDARD_FUNCTIONS.add("lower");
        STANDARD_FUNCTIONS.add("alltrim");
        STANDARD_FUNCTIONS.add("ltrim");
        STANDARD_FUNCTIONS.add("rtrim");
        STANDARD_FUNCTIONS.add("substr");
        STANDARD_FUNCTIONS.add("left");
        STANDARD_FUNCTIONS.add("right");
        STANDARD_FUNCTIONS.add("str");
        STANDARD_FUNCTIONS.add("chr");
        STANDARD_FUNCTIONS.add("asc");
        STANDARD_FUNCTIONS.add("at");
        STANDARD_FUNCTIONS.add("strtran");

        // Database functions
        STANDARD_FUNCTIONS.add("dbUseArea");
        STANDARD_FUNCTIONS.add("dbSeek");
        STANDARD_FUNCTIONS.add("dbGoTop");
        STANDARD_FUNCTIONS.add("dbGoBottom");
        STANDARD_FUNCTIONS.add("dbSkip");
        STANDARD_FUNCTIONS.add("dbCloseArea");
        STANDARD_FUNCTIONS.add("dbSetIndex");
        STANDARD_FUNCTIONS.add("dbSetOrder");
        STANDARD_FUNCTIONS.add("dbAppend");
        STANDARD_FUNCTIONS.add("dbDelete");
        STANDARD_FUNCTIONS.add("dbRecall");
        STANDARD_FUNCTIONS.add("dbCommit");

        // File functions
        STANDARD_FUNCTIONS.add("fopen");
        STANDARD_FUNCTIONS.add("fclose");
        STANDARD_FUNCTIONS.add("fread");
        STANDARD_FUNCTIONS.add("fwrite");
        STANDARD_FUNCTIONS.add("ferror");
        STANDARD_FUNCTIONS.add("directory");

        // UI/Terminal functions
        STANDARD_FUNCTIONS.add("cls");
        STANDARD_FUNCTIONS.add("setpos");
        STANDARD_FUNCTIONS.add("devout");
        STANDARD_FUNCTIONS.add("qout");
        STANDARD_FUNCTIONS.add("qqout");
        STANDARD_FUNCTIONS.add("setcolor");
        STANDARD_FUNCTIONS.add("inkey");

        // Type functions
        STANDARD_FUNCTIONS.add("valtype");
        STANDARD_FUNCTIONS.add("type");
        STANDARD_FUNCTIONS.add("empty");

        // Math functions
        STANDARD_FUNCTIONS.add("abs");
        STANDARD_FUNCTIONS.add("int");
        STANDARD_FUNCTIONS.add("round");
        STANDARD_FUNCTIONS.add("sqrt");

        // Date functions
        STANDARD_FUNCTIONS.add("date");
        STANDARD_FUNCTIONS.add("time");
        STANDARD_FUNCTIONS.add("ctod");
        STANDARD_FUNCTIONS.add("dtoc");
        STANDARD_FUNCTIONS.add("day");
        STANDARD_FUNCTIONS.add("month");
        STANDARD_FUNCTIONS.add("year");
        STANDARD_FUNCTIONS.add("dow");

        // Array functions
        STANDARD_FUNCTIONS.add("aadd");
        STANDARD_FUNCTIONS.add("adel");
        STANDARD_FUNCTIONS.add("asize");
        STANDARD_FUNCTIONS.add("asort");
        STANDARD_FUNCTIONS.add("ains");
        STANDARD_FUNCTIONS.add("aeval");
        STANDARD_FUNCTIONS.add("len");

        // Common application functions used in the logs
        STANDARD_FUNCTIONS.add("disp");
        STANDARD_FUNCTIONS.add("message");
    }

    /**
     * Initialize the provider by loading the standard function list.
     * This must be called from a background thread or with proper read action.
     */
    public static void initialize(Project project) {
        if (initialized) {
            return;
        }

        LOG.info("Initializing standard Harbour functions provider");

        try {
            // Try loading additional functions from a resource file
            InputStream stream = HarbourStandardFunctionsProvider.class.getResourceAsStream("/harbour_functions.txt");
            if (stream != null) {
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        line = line.trim();
                        if (!line.isEmpty() && !line.startsWith("#")) {
                            STANDARD_FUNCTIONS.add(line);
                        }
                    }
                }
            }
        } catch (IOException e) {
            LOG.warn("Could not load additional Harbour functions", e);
        }

        LOG.info("Loaded " + STANDARD_FUNCTIONS.size() + " standard Harbour functions");

        // Schedule creation of function declarations to happen in a read action
        ApplicationManager.getApplication().invokeLater(() -> {
            ReadAction.run(() -> {
                // Create virtual declarations for standard functions
                for (String funcName : STANDARD_FUNCTIONS) {
                    try {
                        createStandardFunctionDeclaration(funcName, project);
                    } catch (Exception e) {
                        LOG.error("Error creating standard function declaration for " + funcName, e);
                    }
                }
                LOG.info("Created declarations for standard Harbour functions");
            });
        });

        initialized = true;
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
     * Check if a function is a standard Harbour function.
     */
    public static boolean isStandardFunction(@NotNull String functionName) {
        return STANDARD_FUNCTIONS.contains(functionName);
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
     * Add a function to the standard functions list.
     */
    public static void addStandardFunction(@NotNull String functionName, Project project) {
        // Create a final copy for use in the lambda
        final String lowerName = functionName.toLowerCase();

        if (!STANDARD_FUNCTIONS.contains(lowerName)) {
            STANDARD_FUNCTIONS.add(lowerName);

            // Add declaration in a read action
            ApplicationManager.getApplication().invokeLater(() -> {
                ReadAction.run(() -> {
                    createStandardFunctionDeclaration(lowerName, project);
                });
            });
        }
    }
}
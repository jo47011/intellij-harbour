package org.intellij.sdk.language;

import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;

/**
 * Utility class to handle scope-related operations for Harbour elements.
 */
public class HarbourScopeUtils {
    private static final String COMPONENT = "ScopeUtils";

    /**
     * Find the start and end line numbers of the procedure or function containing the given element.
     *
     * @param element The element to find the scope for
     * @return An array with [startLine, endLine] or null if not in a procedure/function
     */
    public static int[] getProcedureFunctionScope(PsiElement element) {
        if (element == null || element.getContainingFile() == null) {
            return null;
        }

        PsiFile file = element.getContainingFile();
        String fileText = file.getText();
        int currentLineNumber = HarbourLogger.calculateLineNumber(element);

        HarbourLogger.log(COMPONENT, "Finding scope for element at line: " + currentLineNumber);

        // Split the file into lines
        String[] lines = fileText.split("\n");

        // Find the start line (procedure/function declaration)
        int startLine = -1;
        for (int i = currentLineNumber; i >= 0; i--) {
            String line = i < lines.length ? lines[i].toUpperCase() : "";
            // Check for procedure or function declaration
            if (line.contains("PROCEDURE ") || line.contains("FUNCTION ") || line.contains("METHOD ")) {
                startLine = i;
                break;
            }
        }

        if (startLine == -1) {
            HarbourLogger.log(COMPONENT, "Could not find procedure/function start");
            return null; // Not in a procedure/function
        }

        // Find the end line (next procedure/function declaration or end of file)
        int endLine = lines.length - 1;
        for (int i = startLine + 1; i < lines.length; i++) {
            String line = lines[i].toUpperCase();
            // Check for next procedure or function declaration or return statement
            if (line.contains("PROCEDURE ") || line.contains("FUNCTION ") ||
                    line.contains("METHOD ") || line.contains("RETURN") || line.contains("/* EOP */")) {
                endLine = i;
                break;
            }
        }

        HarbourLogger.log(COMPONENT, "Found scope from line " + startLine + " to " + endLine);
        return new int[] { startLine, endLine };
    }

    /**
     * Checks if two elements are in the same procedure/function scope.
     *
     * @param element1 The first element
     * @param element2 The second element
     * @return true if both elements are in the same scope, false otherwise
     */
    public static boolean areInSameScope(PsiElement element1, PsiElement element2) {
        if (element1 == null || element2 == null) {
            return false;
        }

        // Check if they're in the same file
        PsiFile file1 = element1.getContainingFile();
        PsiFile file2 = element2.getContainingFile();

        if (file1 == null || file2 == null || !file1.equals(file2)) {
            return false;
        }

        // Get scope for both elements
        int[] scope1 = getProcedureFunctionScope(element1);
        int[] scope2 = getProcedureFunctionScope(element2);

        // If either element is not in a scope, return false
        if (scope1 == null || scope2 == null) {
            return false;
        }

        // Check if the scopes match
        return scope1[0] == scope2[0] && scope1[1] == scope2[1];
    }

    /**
     * Check if an element is within a specified scope
     *
     * @param element The element to check
     * @param scopeStart The scope start line
     * @param scopeEnd The scope end line
     * @return true if the element is within the scope, false otherwise
     */
    public static boolean isElementInScope(PsiElement element, int scopeStart, int scopeEnd) {
        if (element == null || element.getContainingFile() == null) {
            return false;
        }

        int elementLine = HarbourLogger.calculateLineNumber(element);
        return elementLine >= scopeStart && elementLine <= scopeEnd;
    }
}
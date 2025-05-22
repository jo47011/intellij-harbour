package org.intellij.sdk.language;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.tree.IElementType;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.FunctionCall;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourProcedureDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/**
 * Helper class for diagnosing reference resolution issues.
 */
public class HarbourReferenceDiagnostics {
    private static final Logger LOG = Logger.getInstance(HarbourReferenceDiagnostics.class);

    /**
     * Log a diagnostic message to the central logger.
     */
    public static void log(String message) {
        HarbourLogger.log("Diagnostics", message);
    }

    /**
     * Run a complete diagnostic on a file.
     */
    public static void diagnoseFile(HarbourFile file) {
        log("============= DIAGNOSTICS FOR FILE: " + file.getName() + " =============");

        // 1. Check function declarations in this file
        diagnoseFunctionDeclarations(file);

        // 2. Check all identifiers that might be function calls
        diagnoseIdentifiers(file);

        // 3. Check PSI function calls
        diagnoseFunctionCalls(file);

        // 4. Check reference service
        diagnoseReferenceService(file.getProject());

        log("============= END DIAGNOSTICS FOR: " + file.getName() + " =============");
    }

    /**
     * Diagnose function declarations in a file.
     */
    private static void diagnoseFunctionDeclarations(HarbourFile file) {
        Collection<HarbourFunctionDeclaration> functions =
                PsiTreeUtil.findChildrenOfType(file, HarbourFunctionDeclaration.class);
        Collection<HarbourProcedureDeclaration> procedures =
                PsiTreeUtil.findChildrenOfType(file, HarbourProcedureDeclaration.class);

        log("Found " + functions.size() + " function declarations via PSI");
        for (HarbourFunctionDeclaration function : functions) {
            PsiElement nameIdentifier = function.getNameIdentifier();
            log("  - Function: " + (nameIdentifier != null ? nameIdentifier.getText() : "unnamed") +
                    " at offset " + function.getTextOffset());
        }

        log("Found " + procedures.size() + " procedure declarations via PSI");
        for (HarbourProcedureDeclaration procedure : procedures) {
            PsiElement nameIdentifier = procedure.getNameIdentifier();
            log("  - Procedure: " + (nameIdentifier != null ? nameIdentifier.getText() : "unnamed") +
                    " at offset " + procedure.getTextOffset());
        }

        // Also try token-based approach
        List<PsiElement> tokenBasedFunctions = findFunctionsByTokens(file);
        log("Found " + tokenBasedFunctions.size() + " function/procedure declarations via tokens");
        for (PsiElement element : tokenBasedFunctions) {
            log("  - Token-based function/procedure: " + element.getText() +
                    " at offset " + element.getTextOffset());
        }
    }

    /**
     * Find function declarations using tokens directly.
     */
    private static List<PsiElement> findFunctionsByTokens(PsiFile file) {
        List<PsiElement> result = new ArrayList<>();
        processFunctionKeywords(file, result);
        return result;
    }

    /**
     * Process all FUNCTION and PROCEDURE keywords in a file.
     */
    private static void processFunctionKeywords(PsiElement element, List<PsiElement> result) {
        if (element.getNode() != null) {
            IElementType type = element.getNode().getElementType();
            if (type == HarbourTypes.FUNCTION || type == HarbourTypes.PROCEDURE) {
                PsiElement nextSibling = element.getNextSibling();
                while (nextSibling != null &&
                        (nextSibling.getNode() == null ||
                                nextSibling.getNode().getElementType() != HarbourTypes.IDENT)) {
                    nextSibling = nextSibling.getNextSibling();
                }

                if (nextSibling != null &&
                        nextSibling.getNode() != null &&
                        nextSibling.getNode().getElementType() == HarbourTypes.IDENT) {
                    result.add(nextSibling);
                }
            }
        }

        for (PsiElement child : element.getChildren()) {
            processFunctionKeywords(child, result);
        }
    }

    /**
     * Diagnose all identifiers in a file that might be function calls.
     */
    private static void diagnoseIdentifiers(HarbourFile file) {
        log("Scanning all IDENT tokens for potential function calls");
        Collection<PsiElement> identifiers = PsiTreeUtil.findChildrenOfType(file, PsiElement.class);
        int potentialFunctionCalls = 0;

        for (PsiElement element : identifiers) {
            if (element.getNode() != null && element.getNode().getElementType() == HarbourTypes.IDENT) {
                if (isPotentialFunctionCall(element)) {
                    potentialFunctionCalls++;
                    log("  - Potential function call: " + element.getText() +
                            " at offset " + element.getTextOffset() +
                            " (has " + element.getReferences().length + " references)");
                }
            }
        }

        log("Found " + potentialFunctionCalls + " potential function calls among identifiers");
    }

    /**
     * Check if an element looks like a function call (has LPAREN after it).
     */
    private static boolean isPotentialFunctionCall(PsiElement element) {
        PsiElement nextSibling = element.getNextSibling();
        int distance = 0;
        while (nextSibling != null && distance < 5) {
            if (nextSibling.getNode() != null &&
                    nextSibling.getNode().getElementType() == HarbourTypes.LPAREN) {
                return true;
            }
            nextSibling = nextSibling.getNextSibling();
            distance++;
        }
        return false;
    }

    /**
     * Diagnose PSI function calls in a file.
     */
    private static void diagnoseFunctionCalls(HarbourFile file) {
        Collection<FunctionCall> functionCalls =
                PsiTreeUtil.findChildrenOfType(file, FunctionCall.class);

        log("Found " + functionCalls.size() + " FunctionCall instances via PSI");
        for (FunctionCall call : functionCalls) {
            PsiElement identifier = call.getIdentifier();
            log("  - Function call: " + (identifier != null ? identifier.getText() : "unnamed") +
                    " at offset " + call.getTextOffset() +
                    " (has " + (identifier != null ? identifier.getReferences().length : 0) + " references)");
        }
    }

    /**
     * Diagnose the reference service state.
     */
    private static void diagnoseReferenceService(Project project) {
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        log("Diagnosing HarbourReferenceService");

        // Use a simple test case to check if service is resolving references
        String[] testFunctions = {"getUser", "upper", "Message", "Disp", "cls", "dbSeek", "dbUseArea"};
        for (String functionName : testFunctions) {
            List<PsiElement> elements = ReadAction.compute(() -> service.findFunctions(functionName));
            log("  - Service lookup for '" + functionName + "': found " + elements.size() + " elements");
        }
    }
}
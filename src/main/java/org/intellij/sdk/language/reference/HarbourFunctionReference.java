package org.intellij.sdk.language.reference;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.HarbourLogger;
import org.intellij.sdk.language.HarbourNavigationElement;
import org.intellij.sdk.language.HarbourReferenceService;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourNamedElement;
import org.jetbrains.annotations.NotNull;

import java.util.List;

/**
 * Reference implementation for Harbour functions.
 * Consolidated from inner class in DirectHarbourReferenceContributor.
 */
public class HarbourFunctionReference extends PsiReferenceBase<PsiElement> {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionReference.class);
    private static final String COMPONENT = "FunctionRef";
    private final String functionName;

    /**
     * Primary constructor with explicit function name.
     * Used by DirectHarbourReferenceContributor.
     *
     * @param element The element containing the reference
     * @param functionName The name of the function being referenced
     */
    public HarbourFunctionReference(@NotNull PsiElement element, String functionName) {
        super(element);
        this.functionName = functionName;
    }

    /**
     * Compatibility constructor that extracts name from element.
     * Used by HarbourFunctionCallMixin and other places.
     *
     * @param element The element containing the reference
     */
    public HarbourFunctionReference(@NotNull PsiElement element) {
        super(element);
        this.functionName = extractName(element);
    }

    /**
     * Constructor with text range for partial references.
     *
     * @param element The element containing the reference
     * @param rangeInElement The text range of the reference within the element
     */
    public HarbourFunctionReference(@NotNull PsiElement element, TextRange rangeInElement) {
        super(element, rangeInElement);
        this.functionName = element.getText().substring(rangeInElement.getStartOffset(), rangeInElement.getEndOffset());
    }

    /**
     * Extract the name from an element.
     * This handles different types of elements that might be passed.
     *
     * @param element The element to extract the name from
     * @return The extracted name
     */
    private String extractName(PsiElement element) {
        if (element instanceof HarbourNamedElement) {
            return ((HarbourNamedElement) element).getName();
        } else {
            return element.getText();
        }
    }

    @Override
    public TextRange getRangeInElement() {
        return new TextRange(0, getElement().getTextLength());
    }

    @Override
    public PsiElement resolve() {
        try {
            HarbourLogger.log(COMPONENT, "Resolving function reference: " + functionName);
            
            // Get the service and look for declarations
            HarbourReferenceService service =
                    HarbourReferenceService.getInstance(getElement().getProject());

            // Find all declarations of this function
            List<PsiElement> declarations = service.findFunctions(functionName);

            // Check if we found any
            if (declarations.isEmpty()) {
                HarbourLogger.log(COMPONENT, "No declarations found for: " + functionName);
                return null;
            }

            // Try to find a function declaration
            for (PsiElement decl : declarations) {
                if (decl instanceof HarbourFunctionDeclaration) {
                    HarbourLogger.log(COMPONENT, "Found function declaration for: " + functionName);
                    return decl;
                }
            }

            // If no function declaration was found, return the first element
            PsiElement resolvedElement = declarations.get(0);

            // Get the file and line number for this element
            PsiFile file = resolvedElement.getContainingFile();
            if (file != null && file.getVirtualFile() != null) {
                String filePath = file.getVirtualFile().getPath();
                int lineNumber = HarbourLogger.calculateLineNumber(resolvedElement);

                HarbourLogger.log(COMPONENT, "Creating navigation element for: " + functionName + 
                    " at " + filePath + ":" + lineNumber);

                // Create and return a navigation element
                return new HarbourNavigationElement(
                        resolvedElement,
                        functionName,
                        filePath,
                        lineNumber,
                        "Function declaration"
                );
            }

            return resolvedElement;
        } catch (Exception e) {
            LOG.error("Error resolving function reference: " + functionName, e);
            HarbourLogger.log(COMPONENT, "Error resolving function reference: " + e.getMessage());
            return null;
        }
    }

    @Override
    public Object @NotNull [] getVariants() {
        return EMPTY_ARRAY;
    }

    /**
     * Handle renaming the element.
     * Currently not implemented - throws exception.
     *
     * @param newElementName The new name for the element
     * @return The element with the updated name
     * @throws IncorrectOperationException always, as renaming is not implemented
     */
    @Override
    public PsiElement handleElementRename(@NotNull String newElementName) throws IncorrectOperationException {
        // TODO: Implement rename support if needed
        throw new IncorrectOperationException("Rename not implemented for function references");
    }
}
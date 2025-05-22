package org.intellij.sdk.language.reference;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.HarbourElementManipulator;
import org.intellij.sdk.language.HarbourIdElement;
import org.intellij.sdk.language.HarbourLogger;
import org.intellij.sdk.language.HarbourReferenceService;
import org.intellij.sdk.language.HarbourStandardFunctionsProvider;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.intellij.sdk.language.psi.HarbourNamedElement;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * Reference implementation for Harbour symbols.
 */
public class HarbourReference extends PsiReferenceBase<PsiElement> {
    private static final Logger LOG = Logger.getInstance(HarbourReference.class);
    private final String symbolName;

    /**
     * Create a reference from a PsiElement.
     *
     * @param element The element containing the reference
     */
    public HarbourReference(@NotNull PsiElement element) {
        super(element);
        this.symbolName = extractName(element);
        HarbourLogger.log("Reference", "Created reference for: " + symbolName);
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

    /**
     * Create a reference from a PsiElement with a specific text range.
     *
     * @param element The element containing the reference
     * @param rangeInElement The text range of the reference within the element
     */
    public HarbourReference(@NotNull PsiElement element, TextRange rangeInElement) {
        super(element, rangeInElement);
        this.symbolName = element.getText().substring(rangeInElement.getStartOffset(), rangeInElement.getEndOffset());
        HarbourLogger.log("Reference", "Created reference with range for: " + symbolName);
    }

    /**
     * Gets the referenced name
     */
    @Override
    public String getCanonicalText() {
        return symbolName;
    }

    /**
     * Returns true if this reference is equivalent to the given reference
     */
    @Override
    public boolean isReferenceTo(@NotNull PsiElement element) {
        if (element instanceof HarbourNamedElement) {
            String otherName = ((HarbourNamedElement) element).getName();
            if (otherName != null && otherName.equalsIgnoreCase(symbolName)) {
                return true;
            }
        }

        // Let IntelliJ's resolver handle more complex cases
        return super.isReferenceTo(element);
    }

    /**
     * Return true if soft reference (unresolved references don't produce errors)
     */
    @Override
    public boolean isSoft() {
        // Return false to highlight unresolved references
        return false;
    }

    /**
     * Resolve the reference to its declaration.
     *
     * @return The declaration element, or null if not found
     */
    @Nullable
    @Override
    public PsiElement resolve() {
        Project project = myElement.getProject();
        HarbourLogger.log("Reference", "Resolving reference: " + symbolName);

        try {
            // First check if it's a standard function
            if (HarbourStandardFunctionsProvider.isStandardFunction(symbolName)) {
                PsiElement stdFuncDecl = HarbourStandardFunctionsProvider.getStandardFunctionDeclaration(symbolName);
                if (stdFuncDecl != null) {
                    HarbourLogger.log("Reference", "  Resolved to standard function: " + symbolName);
                    return stdFuncDecl;
                }
            }

            // Then try using the reference service
            PsiElement target = ReadAction.compute(() -> {
                HarbourReferenceService service = HarbourReferenceService.getInstance(project);
                List<PsiElement> targets = service.findFunctions(symbolName);

                // If found using the service, return the first target
                if (!targets.isEmpty()) {
                    return targets.get(0);
                }
                return null;
            });

            if (target != null) {
                HarbourLogger.log("Reference", "  Resolved via service to: " + target.getText());
                return target;
            }
        } catch (Exception e) {
            LOG.error("Error resolving reference: " + symbolName, e);
        }

        // No targets found
        HarbourLogger.log("Reference", "  Could not resolve reference: " + symbolName);
        return null;
    }

    /**
     * Get variant names for this reference.
     * Used for auto-completion.
     *
     * @return Array of variant names
     */
    @NotNull
    @Override
    public Object[] getVariants() {
        return EMPTY_ARRAY;
    }

    /**
     * Handle renaming the element.
     *
     * @param newElementName The new name for the element
     * @return The element with the updated name
     * @throws IncorrectOperationException if renaming is not supported
     */
    @Override
    public PsiElement handleElementRename(@NotNull String newElementName) throws IncorrectOperationException {
        HarbourLogger.log("Reference", "Handling rename: " + symbolName + " -> " + newElementName);

        PsiElement element = getElement();

        if (element instanceof HarbourIdElement) {
            // Use the manipulator if available
            HarbourElementManipulator manipulator = new HarbourElementManipulator();
            return manipulator.handleContentChange((HarbourIdElement) element,
                    TextRange.from(0, element.getTextLength()), newElementName);
        } else if (element instanceof HarbourNamedElement) {
            // Use the setName method for named elements
            return ((HarbourNamedElement) element).setName(newElementName);
        } else {
            // For other elements, try to create a new identifier and replace
            PsiElement newElement = HarbourElementFactory.createIdentifier(element.getProject(), newElementName);
            if (newElement != null) {
                return element.replace(newElement);
            }
        }

        throw new IncorrectOperationException("Cannot rename element: " + element.getText());
    }
}
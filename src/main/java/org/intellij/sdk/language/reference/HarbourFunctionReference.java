package org.intellij.sdk.language.reference;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.HarbourReferenceService;
import org.intellij.sdk.language.psi.HarbourNamedElement;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * Reference implementation for Harbour functions.
 */
public class HarbourFunctionReference extends PsiReferenceBase<PsiElement> {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionReference.class);
    private final String functionName;

    /**
     * Create a reference from a PsiElement.
     *
     * @param element The element containing the reference
     */
    public HarbourFunctionReference(@NotNull PsiElement element) {
        super(element);
        this.functionName = extractName(element);
        LOG.debug("Created reference for: " + functionName);
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
    public HarbourFunctionReference(@NotNull PsiElement element, TextRange rangeInElement) {
        super(element, rangeInElement);
        this.functionName = element.getText().substring(rangeInElement.getStartOffset(), rangeInElement.getEndOffset());
        LOG.debug("Created reference with range for: " + functionName);
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
        LOG.debug("Resolving reference: " + functionName);

        try {
            // First try using the reference service
            HarbourReferenceService service = HarbourReferenceService.getInstance(project);
            List<PsiElement> targets = service.findFunctions(functionName);

            // If found using the service, return the first target
            if (!targets.isEmpty()) {
                PsiElement target = targets.get(0);
                LOG.debug("  Resolved via service to: " + target.getText());
                return target;
            }
        } catch (Exception e) {
            LOG.error("Error resolving reference: " + functionName, e);
        }

        // No targets found
        LOG.debug("  Could not resolve reference: " + functionName);
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
        throw new IncorrectOperationException("Rename not implemented");
    }
}
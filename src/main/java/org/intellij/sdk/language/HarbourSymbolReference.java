package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.util.IncorrectOperationException;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * Reference implementation for Harbour symbols.
 * This is a compatibility class for existing references.
 */
public class HarbourSymbolReference extends PsiReferenceBase<PsiElement> {
    private static final Logger LOG = Logger.getInstance(HarbourSymbolReference.class);
    private final String symbolName;

    /**
     * Create a reference for a symbol.
     *
     * @param element The element containing the reference
     */
    public HarbourSymbolReference(@NotNull PsiElement element) {
        super(element);
        symbolName = element.getText();
        LOG.debug("Created symbol reference for: " + symbolName);
    }

    /**
     * Resolve the reference to its declaration.
     *
     * @return The declaration element, or null if not found
     */
    @Override
    public PsiElement resolve() {
        Project project = myElement.getProject();
        HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);
        LOG.debug("Resolving symbol reference: " + symbolName);

        // Find the declaration using the reference service
        List<PsiElement> targets = referenceService.findSymbol(symbolName);
        if (!targets.isEmpty()) {
            LOG.debug("  Resolved to: " + targets.get(0).getText());
            return targets.get(0);
        }

        LOG.debug("  Could not resolve symbol: " + symbolName);
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
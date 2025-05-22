package org.intellij.sdk.language;

import com.intellij.openapi.util.TextRange;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReference;
import com.intellij.psi.PsiReferenceContributor;
import com.intellij.psi.PsiReferenceProvider;
import com.intellij.psi.PsiReferenceRegistrar;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.intellij.sdk.language.reference.HarbourReference;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Unified reference contributor for Harbour language.
 * This handles all references to functions, procedures, methods, etc.
 */
public class UnifiedHarbourReferenceContributor extends PsiReferenceContributor {
    private static final String COMPONENT = "UnifiedReferenceContributor";

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        HarbourLogger.log(COMPONENT, "Registering Harbour reference providers");
        HarbourLogger.log(COMPONENT, "Registering unified reference providers with enhanced rename support");

        // Register for IDENT elements that might be function calls
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(LeafPsiElement.class).withElementType(HarbourTypes.IDENT),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element,
                                                                           @NotNull ProcessingContext context) {
                        // Check if this element could be a function call
                        if (isFunctionCallElement(element)) {
                            String text = element.getText();
                            HarbourLogger.log(COMPONENT, "Found function call identifier: " + text);
                            return new PsiReference[]{new HarbourReference(element)};
                        }
                        return PsiReference.EMPTY_ARRAY;
                    }
                },
                100 // Higher priority
        );

        // Register for explicit FunctionCallImpl elements
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(FunctionCallImpl.class),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element,
                                                                           @NotNull ProcessingContext context) {
                        if (element instanceof FunctionCallImpl) {
                            String text = element.getText();
                            int parenIndex = text.indexOf('(');

                            if (parenIndex > 0) {
                                String methodName = text.substring(0, parenIndex);
                                HarbourLogger.log(COMPONENT, "Found function call implementation: " + methodName);

                                return new PsiReference[]{
                                        new HarbourReference(element, new TextRange(0, parenIndex))
                                };
                            }
                        }
                        return PsiReference.EMPTY_ARRAY;
                    }
                },
                110 // Higher priority than the identifier provider
        );

        // For standalone identifiers that aren't function calls but might be method names
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(LeafPsiElement.class).withElementType(HarbourTypes.IDENT),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element,
                                                                           @NotNull ProcessingContext context) {
                        // Only handle identifiers that aren't function calls
                        if (!isFunctionCallElement(element)) {
                            String text = element.getText();
                            HarbourLogger.log(COMPONENT, "Found standalone identifier: " + text);
                            return new PsiReference[]{new HarbourReference(element)};
                        }
                        return PsiReference.EMPTY_ARRAY;
                    }
                },
                90 // Lower priority than function calls
        );

        HarbourLogger.log(COMPONENT, "Unified reference providers registered");
    }

    /**
     * Check if an element might be a function call.
     * This looks for IDENT elements that are followed by a LPAREN.
     *
     * @param element The element to check
     * @return true if this element might be a function call
     */
    private boolean isFunctionCallElement(PsiElement element) {
        // Check if this is an identifier
        if (element.getNode() == null) {
            return false;
        }

        IElementType elementType = element.getNode().getElementType();
        if (elementType != HarbourTypes.IDENT) {
            return false;
        }

        // Check if the next non-whitespace element is a left parenthesis
        PsiElement nextSibling = getNextNonWhitespaceSibling(element);
        return nextSibling != null &&
                nextSibling.getNode() != null &&
                nextSibling.getNode().getElementType() == HarbourTypes.LPAREN;
    }

    /**
     * Get the next non-whitespace sibling of an element.
     *
     * @param element The element to get the next sibling of
     * @return The next non-whitespace sibling, or null if none
     */
    @Nullable
    private PsiElement getNextNonWhitespaceSibling(PsiElement element) {
        PsiElement nextSibling = element.getNextSibling();
        while (nextSibling != null && nextSibling.getNode() != null &&
                nextSibling.getNode().getElementType() == com.intellij.psi.TokenType.WHITE_SPACE) {
            nextSibling = nextSibling.getNextSibling();
        }
        return nextSibling;
    }
}
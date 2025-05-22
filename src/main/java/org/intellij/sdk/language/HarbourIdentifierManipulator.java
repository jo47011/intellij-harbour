package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.AbstractElementManipulator;
import com.intellij.psi.PsiElement;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Manipulator for Harbour identifier elements.
 */
public class HarbourIdentifierManipulator extends AbstractElementManipulator<LeafPsiElement> {
    private static final Logger LOG = Logger.getInstance(HarbourIdentifierManipulator.class);
    private static final String COMPONENT = "IdentifierManipulator";

    @Override
    public @Nullable LeafPsiElement handleContentChange(@NotNull LeafPsiElement element, @NotNull TextRange range, String newContent) throws IncorrectOperationException {
        HarbourLogger.log(COMPONENT, "handleContentChange for identifier: " + element.getText() + " -> " + newContent);

        IElementType elementType = element.getElementType();
        String elementTypeStr = elementType.toString();

        HarbourLogger.log(COMPONENT, "Element type: " + elementTypeStr);

        // Handle any type of Harbour identifier
        if (isHarbourIdentifier(elementType, elementTypeStr)) {
            try {
                // Create a new element with the updated name
                PsiElement newElement = HarbourElementFactory.createIdentifier(element.getProject(), newContent);
                if (newElement != null) {
                    HarbourLogger.log(COMPONENT, "Created new identifier: " + newContent);

                    // For full element replacement (typical case)
                    if (range.getStartOffset() == 0 && range.getEndOffset() == element.getTextLength()) {
                        return (LeafPsiElement) element.replace(newElement);
                    }

                    // For partial replacement (rare case)
                    String oldText = element.getText();
                    String newText = oldText.substring(0, range.getStartOffset()) +
                            newContent +
                            oldText.substring(range.getEndOffset());

                    PsiElement partialElement = HarbourElementFactory.createIdentifier(element.getProject(), newText);
                    if (partialElement != null) {
                        return (LeafPsiElement) element.replace(partialElement);
                    }
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception in handleContentChange: " + e.getMessage());
                LOG.error("Error handling content change for identifier", e);
            }
        } else {
            HarbourLogger.log(COMPONENT, "Not an identifier element: " + elementTypeStr);
        }

        return element;
    }

    /**
     * Check if an element is a Harbour identifier using multiple detection methods
     */
    private boolean isHarbourIdentifier(IElementType elementType, String elementTypeStr) {
        // Multiple detection methods for different PSI implementations
        return elementType == HarbourTypes.IDENT ||
                elementTypeStr.contains("IDENT") ||
                elementTypeStr.contains("HarbourTokenType");
    }

    @Override
    public @NotNull TextRange getRangeInElement(@NotNull LeafPsiElement element) {
        return TextRange.create(0, element.getTextLength());
    }
}
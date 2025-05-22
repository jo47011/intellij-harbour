package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.AbstractElementManipulator;
import com.intellij.psi.PsiElement;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Element manipulator for HarbourIdElement.
 * Allows handling text ranges and renaming of identifiers.
 */
public class HarbourElementManipulator extends AbstractElementManipulator<HarbourIdElement> {
    private static final Logger LOG = Logger.getInstance(HarbourElementManipulator.class);
    private static final String COMPONENT = "ElementManipulator";

    @Nullable
    @Override
    public HarbourIdElement handleContentChange(@NotNull HarbourIdElement element, @NotNull TextRange range, String newContent) throws IncorrectOperationException {
        HarbourLogger.log(COMPONENT, "handleContentChange: " + element.getText() + " -> " + newContent + ", range: " + range);

        // Create a new element with the updated text
        String oldText = element.getText();
        String newText = oldText.substring(0, range.getStartOffset()) + newContent + oldText.substring(range.getEndOffset());
        HarbourLogger.log(COMPONENT, "New text: " + newText);

        try {
            // Use factory to create new element
            PsiElement newElement = HarbourElementFactory.createIdentifier(element.getProject(), newText);

            if (newElement != null) {
                HarbourLogger.log(COMPONENT, "Created new element: " + newElement.getText());
                // Replace the old element with the new one
                HarbourIdElement result = (HarbourIdElement) element.replace(newElement);
                HarbourLogger.log(COMPONENT, "Replaced element successfully, returning: " + result.getText());
                return result;
            } else {
                HarbourLogger.log(COMPONENT, "Failed to create new element");
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Exception during content change: " + e.getMessage());
            LOG.error("Error handling content change", e);
        }

        return element;
    }

    @NotNull
    @Override
    public TextRange getRangeInElement(@NotNull HarbourIdElement element) {
        TextRange range = TextRange.from(0, element.getTextLength());
        HarbourLogger.log(COMPONENT, "getRangeInElement for: " + element.getText() + ", returning range: " + range);
        return range;
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.AbstractElementManipulator;
import com.intellij.psi.PsiElement;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Manipulator for function call elements.
 * This is needed for reference resolution to properly handle function calls.
 */
public class HarbourFunctionCallManipulator extends AbstractElementManipulator<FunctionCallImpl> {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionCallManipulator.class);

    @Override
    public @Nullable FunctionCallImpl handleContentChange(@NotNull FunctionCallImpl element,
                                                          @NotNull TextRange range,
                                                          String newContent) throws IncorrectOperationException {
        String oldText = element.getText();
        HarbourLogger.log("FunctionCallManipulator", "Handling content change for: " + oldText);

        // If changing the function name part
        int parenIndex = oldText.indexOf('(');
        if (parenIndex > 0 && range.getEndOffset() <= parenIndex) {
            try {
                // Extract the function name and parameters
                String oldName = oldText.substring(0, parenIndex).trim();
                String params = oldText.substring(parenIndex);

                // Create the new text with the updated name
                String newName = oldText.substring(0, range.getStartOffset()) +
                        newContent +
                        oldText.substring(range.getEndOffset(), parenIndex);

                String newText = newName + params;
                HarbourLogger.log("FunctionCallManipulator", "Modified function call text: " + newText);

                // Create a new function call with the updated name
                Project project = element.getProject();
                PsiElement newElement = HarbourElementFactory.createFile(project, newText).getFirstChild();

                if (newElement != null) {
                    HarbourLogger.log("FunctionCallManipulator", "Successfully created new function call element");
                    return (FunctionCallImpl) element.replace(newElement);
                } else {
                    HarbourLogger.log("FunctionCallManipulator", "Failed to create new function call element");
                }
            } catch (Exception e) {
                HarbourLogger.log("FunctionCallManipulator", "Exception during content change: " + e.getMessage());
                LOG.error("Error handling content change", e);
            }
        } else {
            HarbourLogger.log("FunctionCallManipulator", "Cannot handle content change for range: " + range + " in text: " + oldText);
        }

        return element;
    }

    @Override
    public @NotNull TextRange getRangeInElement(@NotNull FunctionCallImpl element) {
        String text = element.getText();
        int parenIndex = text.indexOf('(');

        if (parenIndex > 0) {
            HarbourLogger.log("FunctionCallManipulator", "Range in element for " + text + ": 0," + parenIndex);
            return TextRange.create(0, parenIndex);
        }

        HarbourLogger.log("FunctionCallManipulator", "Default range for " + text + ": full text");
        return TextRange.create(0, text.length());
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.actionSystem.DataContext;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.refactoring.rename.PsiElementRenameHandler;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourNamedElement;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;

/**
 * Custom rename handler for Harbour elements.
 */
public class HarbourRenameHandler extends PsiElementRenameHandler {
    private static final String COMPONENT = "RenameHandler";

    /**
     * Validates if an element is valid for rename operations.
     *
     * @param element The element to validate
     * @return true if the element is valid, false otherwise
     */
    private boolean isValidElement(PsiElement element) {
        if (element == null) return false;

        try {
            // Check basic validity
            if (!element.isValid()) {
                HarbourLogger.log(COMPONENT, "Element is invalid in handler");
                return false;
            }

            // Check for null containing file
            PsiFile containingFile = element.getContainingFile();
            if (containingFile == null) {
                HarbourLogger.log(COMPONENT, "Element has no containing file in handler");
                return false;
            }

            // Check if containing file is valid
            if (!containingFile.isValid()) {
                HarbourLogger.log(COMPONENT, "Element's containing file is invalid in handler");
                return false;
            }

            // Special case for DummyHolderViewProvider
            if (containingFile.getViewProvider() != null &&
                    containingFile.getViewProvider().toString().contains("DummyHolderViewProvider")) {
                HarbourLogger.log(COMPONENT, "Element is in DummyHolderViewProvider - unsafe to rename");
                return false;
            }

            return true;
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error validating element in handler: " + e.getMessage());
            return false;
        }
    }

    @Override
    public boolean isAvailableOnDataContext(DataContext dataContext) {
        PsiElement element = getElementFromContext(dataContext);
        PsiFile file = CommonDataKeys.PSI_FILE.getData(dataContext);

        // Only allow rename in Harbour files
        boolean isHarbourFile = file instanceof HarbourFile;

        // Check if the element is valid
        boolean isValid = isValidElement(element);

        // We'll allow renaming if we're in a Harbour file and the element is valid
        boolean canRename = element != null && isHarbourFile && isValid;

        HarbourLogger.log(COMPONENT, "isAvailableOnDataContext for file: " + (file != null ? file.getName() : "null") +
                ", element: " + (element != null ? element.getText() + " (" + element.getClass().getName() + ")" : "null") +
                ", isHarbourFile: " + isHarbourFile + ", isValid: " + isValid + ", canRename: " + canRename);

        return canRename;
    }

    /**
     * Tries to find a renamable element at or containing the given element
     */
    private PsiElement findRenamableElement(PsiElement element) {
        if (element == null) return null;

        // Check validity first
        if (!isValidElement(element)) {
            HarbourLogger.log(COMPONENT, "Original element is not valid, cannot find renamable element");
            return null;
        }

        // Check if this element is a renamable element
        if (element instanceof HarbourNamedElement ||
                element instanceof HarbourIdElement ||
                element instanceof FunctionCallImpl) {
            return element;
        }

        // Look for parent that might be a named element
        PsiElement parent = element.getParent();
        if (parent != null && isValidElement(parent) &&
                (parent instanceof HarbourNamedElement ||
                        parent instanceof HarbourIdElement ||
                        parent instanceof FunctionCallImpl)) {
            return parent;
        }

        // Look for any named element containing this one
        HarbourNamedElement namedElement = PsiTreeUtil.getParentOfType(element, HarbourNamedElement.class);
        if (namedElement != null && isValidElement(namedElement)) {
            return namedElement;
        }

        // Try to find HarbourIdElement
        HarbourIdElement idElement = PsiTreeUtil.getParentOfType(element, HarbourIdElement.class);
        if (idElement != null && isValidElement(idElement)) {
            return idElement;
        }

        // Try to find function call
        FunctionCallImpl functionCall = PsiTreeUtil.getParentOfType(element, FunctionCallImpl.class);
        if (functionCall != null && isValidElement(functionCall)) {
            return functionCall;
        }

        // If all else fails, return the original element if it's valid
        if (isValidElement(element)) {
            return element;
        }

        return null;
    }

    @Override
    public void invoke(@NotNull Project project, Editor editor, PsiFile file, DataContext dataContext) {
        PsiElement element = getElementFromContext(dataContext);

        // Check if the original element is valid
        if (!isValidElement(element)) {
            HarbourLogger.log(COMPONENT, "Cannot rename - element is not valid");
            return;
        }

        // Find the most specific renamable element
        if (element != null) {
            PsiElement renamableElement = findRenamableElement(element);
            if (renamableElement != null && renamableElement != element) {
                // Verify the renamable element is still valid
                if (isValidElement(renamableElement)) {
                    HarbourLogger.log(COMPONENT, "Using more specific element for rename: " + renamableElement.getText());
                    element = renamableElement;
                } else {
                    HarbourLogger.log(COMPONENT, "Found renamable element is invalid");
                    return;
                }
            }
        }

        HarbourLogger.log(COMPONENT, "invoke called on element: " + (element != null ? element.getText() : "null"));

        if (element != null) {
            HarbourLogger.log(COMPONENT, "Starting rename on: " + element.getText());
            try {
                // Get the current name for suggestion
                String currentName = getCurrentElementName(element);
                HarbourLogger.log(COMPONENT, "Current name for suggestion: " + currentName);
                
                // Make element final for use in lambda
                final PsiElement finalElement = element;
                final String finalCurrentName = currentName;
                
                // Create a custom data context with the suggested name
                DataContext customContext = new DataContext() {
                    @Override
                    public Object getData(@NotNull String dataId) {
                        if ("rename.suggested.name".equals(dataId) && finalCurrentName != null) {
                            return finalCurrentName;
                        }
                        if (PsiElementRenameHandler.DEFAULT_NAME.is(dataId)) {
                            return finalElement;
                        }
                        return dataContext.getData(dataId);
                    }
                };
                
                super.invoke(project, editor, file, customContext);
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during invoke: " + e.getMessage());
                HarbourLogger.logStackTrace(COMPONENT, e);
            }
        } else {
            HarbourLogger.log(COMPONENT, "Cannot rename - no valid element found at caret position");
        }
    }

    /**
     * Creates a new DataContext with the updated element.
     */
    @SuppressWarnings({"removal", "deprecation"})
    private DataContext updateDataContext(final DataContext dataContext, final PsiElement element) {
        return dataId -> {
            if (PsiElementRenameHandler.DEFAULT_NAME.equals(dataId)) {
                return element;
            }
            if ("rename.suggested.name".equals(dataId)) {
                // Provide the current name as suggestion
                String currentName = getCurrentElementName(element);
                HarbourLogger.log(COMPONENT, "Suggesting name for rename: " + currentName);
                return currentName;
            }
            return dataContext.getData(dataId);
        };
    }
    
    /**
     * Gets the current name of an element for use as rename suggestion
     */
    private String getCurrentElementName(PsiElement element) {
        if (element == null) return null;
        
        // Try to get name from named elements
        if (element instanceof HarbourNamedElement) {
            String name = ((HarbourNamedElement) element).getName();
            if (name != null && !name.isEmpty()) {
                return name;
            }
        }
        
        if (element instanceof HarbourIdElement) {
            String name = ((HarbourIdElement) element).getName();
            if (name != null && !name.isEmpty()) {
                return name;
            }
        }
        
        // For function calls, extract the function name
        if (element instanceof FunctionCallImpl) {
            PsiElement[] children = element.getChildren();
            for (PsiElement child : children) {
                if (child instanceof LeafPsiElement && 
                    ((LeafPsiElement) child).getElementType() == HarbourTypes.IDENT) {
                    return child.getText();
                }
            }
        }
        
        // For leaf elements, use the text directly
        if (element instanceof LeafPsiElement) {
            LeafPsiElement leafElement = (LeafPsiElement) element;
            if (leafElement.getElementType() == HarbourTypes.IDENT ||
                leafElement.getElementType().toString().contains("IDENT")) {
                return leafElement.getText();
            }
        }
        
        // Fallback to element text
        return element.getText();
    }

    @Override
    public void invoke(@NotNull Project project, @NotNull PsiElement[] elements, DataContext dataContext) {
        HarbourLogger.log(COMPONENT, "invoke called with elements array of length: " + elements.length);

        if (elements.length > 0) {
            // Check if the first element is valid
            if (!isValidElement(elements[0])) {
                HarbourLogger.log(COMPONENT, "Cannot rename - first element is not valid");
                return;
            }

            // Find renamable element for the first element
            PsiElement element = elements[0];
            PsiElement renamableElement = findRenamableElement(element);

            if (renamableElement != null && renamableElement != element) {
                // Verify the renamable element is still valid
                if (isValidElement(renamableElement)) {
                    elements = new PsiElement[]{renamableElement};
                    HarbourLogger.log(COMPONENT, "Using more specific element for rename: " + renamableElement.getText());
                } else {
                    HarbourLogger.log(COMPONENT, "Found renamable element is invalid");
                    return;
                }
            }

            HarbourLogger.log(COMPONENT, "Starting rename on: " + elements[0].getText());
            try {
                super.invoke(project, elements, dataContext);
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during invoke: " + e.getMessage());
                HarbourLogger.logStackTrace(COMPONENT, e);
            }
        }
    }

    // Helper method to get element from context
    private PsiElement getElementFromContext(DataContext dataContext) {
        PsiElement element = PsiElementRenameHandler.getElement(dataContext);
        if (element == null) {
            // Try to get element at caret
            Editor editor = CommonDataKeys.EDITOR.getData(dataContext);
            PsiFile file = CommonDataKeys.PSI_FILE.getData(dataContext);
            if (editor != null && file != null) {
                int offset = editor.getCaretModel().getOffset();
                element = file.findElementAt(offset);
                HarbourLogger.log(COMPONENT, "Found element at offset " + offset + ": " +
                        (element != null ? element.getText() + " (" + element.getClass().getName() + ")" : "null"));
            }
        }
        return element;
    }
}
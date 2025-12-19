package org.intellij.sdk.language;

import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.actionSystem.DataContext;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.Messages;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.refactoring.RefactoringFactory;
import com.intellij.refactoring.RenameRefactoring;
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

        return canRename;
    }

    /**
     * Tries to find a renamable element at or containing the given element
     */
    private PsiElement findRenamableElement(PsiElement element) {
        if (element == null) return null;

        // Check validity first
        if (!isValidElement(element)) {
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
            return;
        }

        // Find the most specific renamable element
        if (element != null) {
            PsiElement renamableElement = findRenamableElement(element);
            if (renamableElement != null && renamableElement != element) {
                // Verify the renamable element is still valid
                if (isValidElement(renamableElement)) {
                    element = renamableElement;
                } else {
                    return;
                }
            }
        }

        if (element != null) {
            try {
                // Get the current name
                String currentName = getCurrentElementName(element);

                if (currentName == null || currentName.isEmpty()) {
                    return;
                }

                // Show input dialog for new name
                String newName = Messages.showInputDialog(
                    project,
                    "Rename '" + currentName + "' to:",
                    "Rename Variable",
                    Messages.getQuestionIcon(),
                    currentName,
                    null
                );

                if (newName != null && !newName.isEmpty() && !newName.equals(currentName)) {

                    // Find all occurrences in the current file within the same scope
                    PsiFile psiFile = element.getContainingFile();
                    String fileText = psiFile.getText();

                    // Get the procedure/function scope for local variables (returns line numbers)
                    int[] scopeLines = HarbourScopeUtils.getProcedureFunctionScope(element);

                    // Convert line numbers to offsets
                    int scopeStartOffset = 0;
                    int scopeEndOffset = fileText.length();
                    if (scopeLines != null) {
                        String[] lines = fileText.split("\n", -1);
                        // Calculate start offset (beginning of start line)
                        for (int i = 0; i < scopeLines[0] && i < lines.length; i++) {
                            scopeStartOffset += lines[i].length() + 1; // +1 for newline
                        }
                        // Calculate end offset (end of end line)
                        scopeEndOffset = 0;
                        for (int i = 0; i <= scopeLines[1] && i < lines.length; i++) {
                            scopeEndOffset += lines[i].length() + 1;
                        }
                    }


                    // Find all identifier occurrences with word boundaries
                    java.util.List<int[]> occurrences = new java.util.ArrayList<>();
                    java.util.regex.Pattern pattern = java.util.regex.Pattern.compile(
                        "\\b" + java.util.regex.Pattern.quote(currentName) + "\\b",
                        java.util.regex.Pattern.CASE_INSENSITIVE
                    );
                    java.util.regex.Matcher matcher = pattern.matcher(fileText);

                    while (matcher.find()) {
                        int start = matcher.start();
                        int end = matcher.end();
                        // Check if within scope
                        if (start >= scopeStartOffset && end <= scopeEndOffset) {
                            // Verify it's actually an identifier (not in a string or comment)
                            PsiElement elemAtPos = psiFile.findElementAt(start);
                            if (elemAtPos instanceof LeafPsiElement) {
                                LeafPsiElement leaf = (LeafPsiElement) elemAtPos;
                                if (leaf.getElementType() == HarbourTypes.IDENT &&
                                    leaf.getText().equalsIgnoreCase(currentName)) {
                                    occurrences.add(new int[]{start, end});
                                }
                            }
                        }
                    }

                    if (!occurrences.isEmpty()) {
                        // Sort by offset descending (replace from end to preserve earlier offsets)
                        occurrences.sort((a, b) -> b[0] - a[0]);

                        // Perform the rename in a write action
                        com.intellij.openapi.editor.Document document =
                            com.intellij.psi.PsiDocumentManager.getInstance(project).getDocument(psiFile);

                        if (document != null) {
                            com.intellij.openapi.command.WriteCommandAction.runWriteCommandAction(project,
                                "Rename " + currentName + " to " + newName, null, () -> {
                                for (int[] occ : occurrences) {
                                    document.replaceString(occ[0], occ[1], newName);
                                }
                            });

                            // Commit the document changes and refresh references
                            com.intellij.psi.PsiDocumentManager psiDocManager = com.intellij.psi.PsiDocumentManager.getInstance(project);
                            psiDocManager.commitDocument(document);
                            psiDocManager.commitAllDocuments();

                            // Invalidate all caches for this file to refresh references
                            String filePath = psiFile.getVirtualFile() != null ? psiFile.getVirtualFile().getPath() : null;
                            if (filePath != null) {
                                HarbourIndexCache indexCache = HarbourIndexCache.getInstance(project);
                                if (indexCache != null) {
                                    indexCache.removeFileFromCache(filePath);
                                }
                            }

                            // Clear reference service caches (function/variable lookups)
                            HarbourReferenceService refService = HarbourReferenceService.getInstance(project);
                            if (refService != null) {
                                refService.clearCache();
                            }

                            // Trigger file re-parse to update PSI
                            com.intellij.util.FileContentUtil.reparseFiles(project,
                                java.util.Collections.singletonList(psiFile.getVirtualFile()), true);

                            // Also trigger index refresh for this file
                            com.intellij.openapi.fileEditor.FileDocumentManager.getInstance().saveAllDocuments();
                            com.intellij.util.indexing.FileBasedIndex.getInstance().requestReindex(psiFile.getVirtualFile());

                            HarbourLogger.log(COMPONENT, "Rename completed - " + occurrences.size() + " occurrences");
                        }
                    }
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during invoke: " + e.getMessage());
            }
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
                return getCurrentElementName(element);
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
        if (elements.length > 0) {
            // Check if the first element is valid
            if (!isValidElement(elements[0])) {
                return;
            }

            // Find renamable element for the first element
            PsiElement element = elements[0];
            PsiElement renamableElement = findRenamableElement(element);

            if (renamableElement != null && renamableElement != element) {
                // Verify the renamable element is still valid
                if (isValidElement(renamableElement)) {
                    elements = new PsiElement[]{renamableElement};
                } else {
                    return;
                }
            }

            try {
                super.invoke(project, elements, dataContext);
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during invoke: " + e.getMessage());
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
            }
        }
        return element;
    }
}
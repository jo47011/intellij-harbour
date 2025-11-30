package org.intellij.sdk.language;

import com.intellij.ide.structureView.StructureViewModel;
import com.intellij.ide.structureView.StructureViewTreeElement;
import com.intellij.ide.structureView.TextEditorBasedStructureViewModel;
import com.intellij.ide.util.treeView.smartTree.Sorter;
import com.intellij.openapi.Disposable;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Editor;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Structure View Model for Harbour files.
 * Extends TextEditorBasedStructureViewModel to support cursor tracking
 * and highlighting of the current method in the structure view.
 */
public class HarbourStructureViewModel extends TextEditorBasedStructureViewModel implements
        StructureViewModel.ElementInfoProvider, Disposable {

    private static final Logger LOG = Logger.getInstance(HarbourStructureViewModel.class);
    private boolean isDisposed = false;
    private final HarbourFile psiFile;

    private static final String PROCEDURE_TOKEN = "HarbourTokenType.PROCEDURE";
    private static final String FUNCTION_TOKEN = "HarbourTokenType.FUNCTION";
    private static final String METHOD_TOKEN = "HarbourTokenType.METHOD";
    private static final String CLASS_TOKEN = "HarbourTokenType.CLASS";

    public HarbourStructureViewModel(HarbourFile psiFile, Editor editor) {
        super(editor, psiFile);
        this.psiFile = psiFile;
        LOG.info("Created structure view model for file: " + psiFile.getName());
    }

    @NotNull
    @Override
    protected PsiFile getPsiFile() {
        return psiFile;
    }

    @NotNull
    @Override
    public StructureViewTreeElement getRoot() {
        return new HarbourStructureViewElement(psiFile);
    }

    @Override
    public boolean isAlwaysShowsPlus(StructureViewTreeElement element) {
        return element.getValue() instanceof HarbourFile;
    }

    @Override
    public boolean isAlwaysLeaf(StructureViewTreeElement element) {
        return false; // Allow expansion of elements that have children
    }

    @Override
    public @NotNull Sorter[] getSorters() {
        return new Sorter[]{Sorter.ALPHA_SORTER};
    }

    /**
     * Returns the classes that are suitable for the structure view.
     * This tells the framework which PSI elements can be highlighted.
     */
    @NotNull
    @Override
    protected Class<?> @NotNull [] getSuitableClasses() {
        return new Class[]{LeafPsiElement.class, HarbourFile.class};
    }

    /**
     * Returns the element at the current cursor position.
     * This enables automatic highlighting of the current method/function in the structure view.
     */
    @Nullable
    @Override
    public Object getCurrentEditorElement() {
        if (isDisposed || getEditor() == null) {
            HarbourLogger.log("StructureViewModel", "getCurrentEditorElement: disposed or no editor");
            return null;
        }

        try {
            int offset = getEditor().getCaretModel().getOffset();
            if (offset < 0 || offset >= psiFile.getTextLength()) {
                HarbourLogger.log("StructureViewModel", "getCurrentEditorElement: invalid offset " + offset);
                return null;
            }

            PsiElement elementAtCursor = psiFile.findElementAt(offset);
            if (elementAtCursor == null) {
                HarbourLogger.log("StructureViewModel", "getCurrentEditorElement: no element at offset " + offset);
                return null;
            }

            // Find the containing function/procedure/method/class
            PsiElement result = findContainingStructureElement(offset);
            if (result != null) {
                HarbourLogger.log("StructureViewModel", "getCurrentEditorElement: Found at offset " + offset +
                    ": " + result.getText().substring(0, Math.min(20, result.getText().length())));
            } else {
                HarbourLogger.log("StructureViewModel", "getCurrentEditorElement: no structure element at offset " + offset);
            }
            return result;
        } catch (Exception e) {
            HarbourLogger.log("StructureViewModel", "Error in getCurrentEditorElement: " + e.getMessage());
            return null;
        }
    }

    /**
     * Find the containing structure element (function, procedure, method, or class)
     * for the given cursor offset.
     */
    @Nullable
    private PsiElement findContainingStructureElement(int cursorOffset) {
        // Find the last FUNCTION/PROCEDURE/METHOD/CLASS keyword that appears before the cursor
        PsiElement bestMatch = null;
        int bestMatchOffset = -1;

        // Use PsiTreeUtil to iterate through all leaf elements
        PsiElement current = psiFile.getFirstChild();
        while (current != null) {
            if (current instanceof LeafPsiElement leaf) {
                String type = leaf.getElementType().toString();
                int elementOffset = leaf.getTextOffset();

                // Check if this is a structure keyword that appears before or at the cursor
                if (elementOffset <= cursorOffset &&
                    (type.equals(FUNCTION_TOKEN) || type.equals(PROCEDURE_TOKEN) ||
                     type.equals(METHOD_TOKEN) || type.equals(CLASS_TOKEN))) {

                    // Update best match if this is closer to the cursor
                    if (elementOffset > bestMatchOffset) {
                        bestMatch = leaf;
                        bestMatchOffset = elementOffset;
                    }
                }
            }

            // Depth-first traversal
            PsiElement firstChild = current.getFirstChild();
            if (firstChild != null) {
                current = firstChild;
            } else {
                PsiElement next = current.getNextSibling();
                while (next == null && current != null && current.getParent() != null && current.getParent() != psiFile) {
                    current = current.getParent();
                    next = current.getNextSibling();
                }
                if (next == null && current != null && current.getParent() == psiFile) {
                    next = current.getNextSibling();
                }
                current = next;
            }
        }

        return bestMatch;
    }

    @Override
    public synchronized void dispose() {
        if (!isDisposed) {
            isDisposed = true;
            LOG.info("Disposing Harbour structure view model");
            // Clean up any resources here
        }
    }
}

package org.intellij.sdk.language;

import com.intellij.codeInsight.editorActions.BackspaceHandlerDelegate;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.psi.PsiFile;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

/**
 * Handles smart backspace behavior for paired characters in Harbour language.
 * 
 * Features:
 * - When deleting opening quote/bracket, also removes matching closing one if they form an empty pair
 * - Applies to quotes: "", '' 
 * - Applies to brackets: (), [], {}
 */
public class HarbourBackspaceHandler extends BackspaceHandlerDelegate {

    public HarbourBackspaceHandler() {
        HarbourLogger.log("BackspaceHandler", "HarbourBackspaceHandler initialized");
    }

    /**
     * Called before backspace is processed to potentially handle smart deletion.
     * 
     * @param editor the editor
     * @param file the PSI file
     * @return true if backspace was handled, false to continue with default behavior
     */
    @Override
    public boolean charDeleted(char c, @NotNull PsiFile file, @NotNull Editor editor) {
        // Only process Harbour files
        if (!(file instanceof HarbourFile)) {
            return false;
        }

        Document document = editor.getDocument();
        int offset = editor.getCaretModel().getOffset();
        
        // Check if we can perform smart deletion
        if (shouldDeleteMatchingCharacter(c, document, offset)) {
            // Delete the matching closing character
            document.deleteString(offset, offset + 1);
            HarbourLogger.log("BackspaceHandler", "Deleted matching character for: " + c + " at offset: " + offset);
            return true; // We handled the deletion
        }

        return false; // Let default behavior handle it
    }

    /**
     * Determines if we should delete the matching closing character.
     * 
     * @param deletedChar the character that was just deleted by backspace
     * @param document the document
     * @param currentOffset the current cursor position (after the deletion)
     * @return true if we should delete the matching character
     */
    private boolean shouldDeleteMatchingCharacter(char deletedChar, Document document, int currentOffset) {
        try {
            // Check bounds
            if (currentOffset >= document.getTextLength()) {
                return false;
            }

            // Get the next character
            char nextChar = document.getCharsSequence().charAt(currentOffset);

            // Check for paired characters
            boolean shouldDelete = false;
            
            switch (deletedChar) {
                case '"':
                    // Delete matching closing double quote
                    shouldDelete = (nextChar == '"');
                    break;
                case '\'':
                    // Delete matching closing single quote  
                    shouldDelete = (nextChar == '\'');
                    break;
                case '(':
                    // Delete matching closing parenthesis
                    shouldDelete = (nextChar == ')');
                    break;
                case '[':
                    // Delete matching closing bracket
                    shouldDelete = (nextChar == ']');
                    break;
                case '{':
                    // Delete matching closing brace
                    shouldDelete = (nextChar == '}');
                    break;
                default:
                    shouldDelete = false;
                    break;
            }

            // Additional check: make sure there's nothing between the paired characters
            // (i.e., they form an empty pair)
            if (shouldDelete) {
                // For this simple implementation, we assume they form an empty pair
                // since the cursor is right between them after deletion
                HarbourLogger.log("BackspaceHandler", "Should delete matching character: " + nextChar + 
                                 " for deleted char: " + deletedChar);
            }

            return shouldDelete;

        } catch (Exception e) {
            HarbourLogger.log("BackspaceHandler", "Error in shouldDeleteMatchingCharacter: " + e.getMessage());
            return false;
        }
    }

    /**
     * Called before the actual backspace operation.
     * We can perform any pre-processing here if needed.
     * 
     * @param c the character about to be deleted
     * @param file the PSI file
     * @param editor the editor
     */
    @Override
    public void beforeCharDeleted(char c, @NotNull PsiFile file, @NotNull Editor editor) {
        // Pre-processing can be done here if needed
        // For our smart backspace implementation, we don't need any pre-processing
    }
}
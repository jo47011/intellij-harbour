package org.intellij.sdk.language;

import com.intellij.codeInsight.editorActions.enter.EnterHandlerDelegate;
import com.intellij.openapi.actionSystem.DataContext;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.editor.actionSystem.EditorActionHandler;
import com.intellij.openapi.util.Ref;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Handles Enter key in Harbour files for auto-indentation
 */
public class HarbourEnterHandler implements EnterHandlerDelegate {

    @Override
    public Result preprocessEnter(@NotNull PsiFile file, @NotNull Editor editor, @NotNull Ref<Integer> caretOffset,
                                  @NotNull Ref<Integer> caretAdvance, @NotNull DataContext dataContext,
                                  @Nullable EditorActionHandler originalHandler) {
        return Result.Continue;
    }

    @Override
    public Result postProcessEnter(@NotNull PsiFile file, @NotNull Editor editor, @NotNull DataContext dataContext) {
        if (!(file instanceof HarbourFile)) {
            return Result.Continue;
        }

        try {
            // Get document and current position
            Document document = editor.getDocument();
            int offset = editor.getCaretModel().getOffset();
            int lineNumber = document.getLineNumber(offset);

            // Logger
            HarbourLogger.log("EnterHandler", "Processing Enter after line " + (lineNumber - 1));

            // Only proceed if we have a previous line
            if (lineNumber <= 0) {
                return Result.Continue;
            }

            // Get the current line text (where cursor is now)
            int currentLineStart = document.getLineStartOffset(lineNumber);
            int currentLineEnd = document.getLineEndOffset(lineNumber);
            String currentLineText = "";
            if (currentLineEnd > currentLineStart) {
                currentLineText = document.getCharsSequence().subSequence(currentLineStart, currentLineEnd).toString().trim().toLowerCase();
            }
            HarbourLogger.log("EnterHandler", "Current line text: '" + currentLineText + "'");

            // Get the previous line text
            int prevLineStart = document.getLineStartOffset(lineNumber - 1);
            int prevLineEnd = document.getLineEndOffset(lineNumber - 1);
            String prevLineText = document.getCharsSequence().subSequence(prevLineStart, prevLineEnd).toString();

            // Get indentation from previous line
            String indent = getIndentation(prevLineText);

            // Check if current line is an ending statement that should decrease indent
            boolean shouldDecreaseIndent = shouldUnindent(currentLineText);
            HarbourLogger.log("EnterHandler", "Should decrease indent: " + shouldDecreaseIndent);

            // Check if previous line should trigger increased indentation
            String trimmedPrevLine = prevLineText.trim().toLowerCase();
            boolean shouldAddExtraIndent = !shouldDecreaseIndent && shouldIndentAfter(trimmedPrevLine);
            HarbourLogger.log("EnterHandler", "Should increase indent: " + shouldAddExtraIndent);

            // Special handling for else/elseif - they should align with their corresponding if
            if (currentLineText.equals("else") || currentLineText.startsWith("elseif")) {
                // Else should unindent to match the if level, but the NEXT line after else should indent
                shouldDecreaseIndent = true; // This will decrease by one indent level to match if
                shouldAddExtraIndent = false; // Don't add extra indent for this line
                HarbourLogger.log("EnterHandler", "Special handling for else/elseif - unindenting to match if level");
            }

            // Get indentation size from settings
            HarbourSettings settings = HarbourSettings.getInstance(file.getProject());
            int indentSize = settings != null ? settings.getIndentationSize() : 2;

            // Modify indentation as needed
            if (shouldDecreaseIndent && indent.length() >= indentSize) {
                // Decrease indentation by removing indentSize spaces
                indent = indent.substring(0, indent.length() - indentSize);
                HarbourLogger.log("EnterHandler", "Decreased indent to: '" + indent + "'");
            } else if (shouldAddExtraIndent) {
                // Add extra spaces based on settings
                indent += " ".repeat(indentSize);
                HarbourLogger.log("EnterHandler", "Increased indent to: '" + indent + "'");
            }

            // Apply indentation if needed
            HarbourLogger.log("EnterHandler", "Final indent to apply: '" + indent + "'");

            // Clear existing indentation
            int nonWsOffset = findFirstNonWsOffset(document, currentLineStart,
                    Math.min(currentLineEnd, document.getTextLength()));
            if (nonWsOffset > currentLineStart) {
                document.deleteString(currentLineStart, nonWsOffset);
            }

            // Insert new indentation
            document.insertString(currentLineStart, indent);

            // Commit document changes
            PsiDocumentManager.getInstance(file.getProject()).commitDocument(document);

            return Result.Stop;
        } catch (Exception e) {
            HarbourLogger.log("EnterHandler", "Error in postProcessEnter: " + e.getMessage());
            if (e.getStackTrace().length > 0) {
                HarbourLogger.log("EnterHandler", "  at " + e.getStackTrace()[0]);
            }
        }

        return Result.Continue;
    }

    private int findFirstNonWsOffset(Document document, int start, int end) {
        CharSequence text = document.getCharsSequence();
        int offset = start;
        while (offset < end && offset < document.getTextLength() &&
                Character.isWhitespace(text.charAt(offset))) {
            offset++;
        }
        return offset;
    }

    private String getIndentation(String line) {
        int i = 0;
        while (i < line.length() && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        return line.substring(0, i);
    }

    private boolean shouldIndentAfter(String line) {
        // Check for statements that increase indentation
        return line.startsWith("if ") || line.equals("if") ||
                line.startsWith("for ") || line.equals("for") ||
                line.startsWith("do ") || line.equals("do") ||
                line.startsWith("while ") || line.equals("while") ||
                line.startsWith("procedure ") || line.equals("procedure") ||
                line.startsWith("function ") || line.equals("function") ||
                line.equals("else") || line.startsWith("else ") ||
                line.equals("elseif") || line.startsWith("elseif ") ||
                line.startsWith("case ") || line.equals("case") ||
                line.startsWith("switch ") || line.equals("switch") ||
                line.startsWith("class ") || line.equals("class") ||
                // BEGIN SEQUENCE block support
                line.equals("begin sequence") || line.startsWith("begin sequence ") ||
                line.equals("recover using") || line.startsWith("recover using ");
    }

    private boolean shouldUnindent(String line) {
        // Check for statements that should decrease indentation
        return line.equals("endif") ||
                line.equals("enddo") ||
                line.equals("endcase") ||
                line.equals("endswitch") ||
                line.equals("next") ||
                line.equals("end") ||
                line.equals("endclass") ||
                line.equals("else") || line.startsWith("else ") ||
                line.equals("elseif") || line.startsWith("elseif ") ||
                // BEGIN SEQUENCE block support
                line.equals("recover using") || line.startsWith("recover using ") ||
                line.equals("end sequence") || line.startsWith("end sequence ");
    }
}
package org.intellij.sdk.language;

import com.intellij.codeInsight.editorActions.TypedHandlerDelegate;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Handles auto-formatting for block end keywords in Harbour files
 */
public class HarbourBlockEndTypedHandler extends TypedHandlerDelegate {

    // Block end keywords that should trigger unindent
    private static final Set<String> BLOCK_END_KEYWORDS = new HashSet<>(Arrays.asList(
            "endif", "enddo", "endclass", "endcase", "next", "return", "else", "elseif"
    ));

    // Last characters of keywords that trigger checking
    private static final Set<Character> TRIGGER_CHARS = new HashSet<>(Arrays.asList(
            'f', 'o', 'd', 't', 'n', 's', 'e', 'p', 'r', 'l'  // Added 'l' for else/elseif
    ));

    @Override
    public @NotNull Result charTyped(char c, @NotNull Project project, @NotNull Editor editor, @NotNull PsiFile file) {
        if (!(file instanceof HarbourFile)) {
            return Result.CONTINUE;
        }

        // Check if this is a character that could complete a keyword
        if (!TRIGGER_CHARS.contains(c)) {
            return Result.CONTINUE;
        }

        try {
            Document document = editor.getDocument();
            int offset = editor.getCaretModel().getOffset();

            // Get current line
            int lineNumber = document.getLineNumber(offset);
            int lineStart = document.getLineStartOffset(lineNumber);
            int lineEnd = document.getLineEndOffset(lineNumber);
            String currentLineText = document.getText().substring(lineStart, lineEnd);

            // Extract current word (at cursor position)
            String currentWord = getCurrentWord(document, offset);

            HarbourLogger.log("BlockEndTypedHandler", "Checking word: '" + currentWord + "' in line: '" + currentLineText.trim() + "'");

            // Check if the current word is a block end keyword
            if (BLOCK_END_KEYWORDS.contains(currentWord.toLowerCase())) {
                HarbourLogger.log("BlockEndTypedHandler", "Found block end keyword: " + currentWord);

                // Get current indentation and content
                String currentIndent = getIndentation(currentLineText);
                String lineContent = currentLineText.trim();

                // Get indentation size from settings
                HarbourSettings settings = HarbourSettings.getInstance(project);
                int indentSize = settings != null ? settings.getIndentationSize() : 2;

                // Calculate correct indentation (one level less)
                String correctIndent;
                if (currentIndent.length() >= indentSize) {
                    correctIndent = currentIndent.substring(0, currentIndent.length() - indentSize);
                } else {
                    correctIndent = "";
                }

                HarbourLogger.log("BlockEndTypedHandler", "Current indent: '" + currentIndent + "', Correct indent: '" + correctIndent + "'");

                // Only adjust if the indentation is different
                if (!currentIndent.equals(correctIndent)) {
                    // Calculate cursor position relative to the start of the word
                    int cursorPosInWord = offset - (lineStart + currentIndent.length() + lineContent.indexOf(currentWord));

                    // Replace the entire line with properly indented version
                    document.replaceString(lineStart, lineEnd, correctIndent + lineContent);

                    // Adjust cursor position
                    int newWordStart = lineStart + correctIndent.length() + lineContent.indexOf(currentWord);
                    int newOffset = newWordStart + cursorPosInWord;

                    if (newOffset >= 0 && newOffset <= document.getTextLength()) {
                        editor.getCaretModel().moveToOffset(newOffset);
                    }

                    PsiDocumentManager.getInstance(project).commitDocument(document);
                    HarbourLogger.log("BlockEndTypedHandler", "Adjusted indentation for: " + currentWord);
                    return Result.STOP;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("BlockEndTypedHandler", "Error in charTyped: " + e.getMessage());
        }

        return Result.CONTINUE;
    }

    /**
     * Gets the current word at the cursor position
     */
    private String getCurrentWord(Document document, int offset) {
        CharSequence text = document.getCharsSequence();

        // Find word start (scan backward)
        int start = offset - 1;
        while (start >= 0 && isIdentifierPart(text.charAt(start))) {
            start--;
        }
        start++;

        // Find word end (scan forward)
        int end = offset;
        while (end < text.length() && isIdentifierPart(text.charAt(end))) {
            end++;
        }

        // Extract the word
        if (start <= end && start >= 0 && end <= text.length()) {
            return text.subSequence(start, end).toString();
        }

        return "";
    }

    /**
     * Checks if a character is part of an identifier
     */
    private boolean isIdentifierPart(char c) {
        return Character.isLetterOrDigit(c) || c == '_';
    }

    /**
     * Extracts indentation (leading spaces) from a line
     */
    private String getIndentation(String line) {
        int i = 0;
        while (i < line.length() && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        return line.substring(0, i);
    }
}
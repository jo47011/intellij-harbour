package org.intellij.sdk.language;

import com.intellij.formatting.Indent;
import com.intellij.lang.Language;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.psi.codeStyle.lineIndent.LineIndentProvider;
import com.intellij.util.text.CharArrayUtil;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Provides fast line indentation for Harbour language.
 * This is called for auto-indentation as the user types.
 */
public class HarbourLineIndentProvider implements LineIndentProvider {

    @Override
    public boolean isSuitableFor(@Nullable Language language) {
        return language != null && language.isKindOf(HarbourLanguage.INSTANCE);
    }

    @Nullable
    @Override
    public String getLineIndent(@NotNull Project project, @NotNull Editor editor, @Nullable Language language, int offset) {
        // Get the document from the editor
        Document document = editor.getDocument();
        HarbourLogger.log("LineIndentProvider", "Getting line indent for offset: " + offset);
        
        // Get current line number
        int lineNumber = document.getLineNumber(offset);
        
        // If this is the first line, no indentation
        if (lineNumber <= 0) {
            HarbourLogger.log("LineIndentProvider", "First line, no indentation");
            return "";
        }
        
        // Get the previous line
        int prevLineStart = document.getLineStartOffset(lineNumber - 1);
        int prevLineEnd = document.getLineEndOffset(lineNumber - 1);
        String prevLineText = document.getCharsSequence().subSequence(prevLineStart, prevLineEnd).toString();
        
        // Get indentation from previous line
        String prevIndent = getIndentation(prevLineText);
        String trimmedPrevLine = prevLineText.trim().toLowerCase();
        
        HarbourLogger.log("LineIndentProvider", "Previous line: '" + trimmedPrevLine + "', indent: '" + prevIndent + "'");
        
        // Get current line text to check if it's an ending statement
        int currentLineStart = document.getLineStartOffset(lineNumber);
        int currentLineEnd = document.getLineEndOffset(lineNumber);
        String currentLineText = "";
        if (currentLineEnd > currentLineStart) {
            currentLineText = document.getCharsSequence().subSequence(currentLineStart, currentLineEnd).toString().trim().toLowerCase();
        }
        
        HarbourLogger.log("LineIndentProvider", "Current line: '" + currentLineText + "'");
        
        // Check if current line should decrease indentation
        boolean shouldUnindent = shouldUnindent(currentLineText);
        
        // Check if previous line should increase indentation
        boolean shouldIndent = shouldIndentAfter(trimmedPrevLine);
        
        // Get indentation size from settings (default to 2)
        int indentSize = 2;
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings != null) {
            indentSize = settings.getIndentationSize();
        }
        
        // Calculate new indentation
        String newIndent = prevIndent;
        
        if (shouldUnindent && prevIndent.length() >= indentSize) {
            // Decrease indentation
            newIndent = prevIndent.substring(0, prevIndent.length() - indentSize);
            HarbourLogger.log("LineIndentProvider", "Decreasing indent to: '" + newIndent + "'");
        } else if (shouldIndent) {
            // Increase indentation
            newIndent = prevIndent + " ".repeat(indentSize);
            HarbourLogger.log("LineIndentProvider", "Increasing indent to: '" + newIndent + "'");
        }
        
        HarbourLogger.log("LineIndentProvider", "Final indent: '" + newIndent + "'");
        return newIndent;
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
                line.equals("otherwise") || line.startsWith("otherwise ") ||
                // BEGIN SEQUENCE block support
                line.equals("recover using") || line.startsWith("recover using ") ||
                line.equals("end sequence") || line.startsWith("end sequence ");
    }
}
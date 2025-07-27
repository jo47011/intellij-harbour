package org.intellij.sdk.language;

import com.intellij.lexer.Lexer;
import com.intellij.openapi.editor.colors.EditorColorsManager;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.editor.markup.TextAttributes;
import com.intellij.psi.PsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.ui.ColoredListCellRenderer;
import com.intellij.ui.SimpleTextAttributes;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;

/**
 * Custom list cell renderer for Harbour navigation elements with syntax highlighting
 */
public class HarbourNavigationListRenderer extends ColoredListCellRenderer<PsiElement> {
    private static final String COMPONENT = "NavigationRenderer";

    @Override
    protected void customizeCellRenderer(@NotNull JList<? extends PsiElement> list,
                                         PsiElement element, int index,
                                         boolean selected, boolean hasFocus) {
        if (element instanceof HarbourNavigationElement) {
            HarbourNavigationElement navElement = (HarbourNavigationElement) element;

            // Skip separators
            if (navElement.isSeparator()) {
                append(navElement.getElementName(), SimpleTextAttributes.GRAYED_ATTRIBUTES);
                return;
            }

            // Extract filename from path
            String filePath = navElement.getFilePath();
            String fileName = filePath != null ? filePath.substring(filePath.lastIndexOf('/') + 1) : "unknown";

            // Column 1: Filename (fixed width 30 chars)
            String paddedFileName = String.format("%-30s", truncateFileName(fileName, 30));
            append(paddedFileName, SimpleTextAttributes.REGULAR_BOLD_ATTRIBUTES);

            // Column 2: Line number (right-aligned with extra space for better alignment)  
            String lineNumberStr = String.format("%6d", navElement.getLineNumber());
            append(lineNumberStr, SimpleTextAttributes.GRAYED_ATTRIBUTES);

            // Column 3: Single space separator (reduced since line number field is wider)
            append(" ", SimpleTextAttributes.REGULAR_ATTRIBUTES);

            // Column 4: Syntax-highlighted code (truncated to fit popup width)
            String codeText = navElement.readLineFromFile(navElement.getFilePath(), navElement.getLineNumber());
            if (codeText != null && !codeText.isEmpty()) {
                String truncatedCode = truncateCodeText(codeText.trim());
                applySyntaxHighlighting(truncatedCode);
            }

            // Definition indicator removed as requested
        }
    }

    /**
     * Truncate filename to fit in specified width, preserving extension
     */
    private String truncateFileName(String fileName, int maxWidth) {
        if (fileName.length() <= maxWidth) {
            return fileName;
        }

        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex > 0) {
            String extension = fileName.substring(dotIndex);
            String baseName = fileName.substring(0, dotIndex);
            int maxBase = maxWidth - extension.length() - 3; // -3 for "..."
            if (maxBase > 0) {
                return baseName.substring(0, Math.min(baseName.length(), maxBase)) + "..." + extension;
            } else {
                return "..." + extension;
            }
        } else {
            return fileName.substring(0, maxWidth - 3) + "...";
        }
    }

    /**
     * Truncate code text to fit within maximum popup width
     */
    private String truncateCodeText(String codeText) {
        if (codeText == null || codeText.isEmpty()) {
            return "";
        }
        
        // Maximum total width: 80 characters
        // Filename: 30 + Line number: 6 + Separator: 1 = 37
        // Remaining for code: 80 - 37 = 43 characters
        final int MAX_CODE_LENGTH = 43;
        
        if (codeText.length() <= MAX_CODE_LENGTH) {
            return codeText;
        }
        
        // Truncate and add ellipsis
        return codeText.substring(0, MAX_CODE_LENGTH - 3) + "...";
    }

    /**
     * Apply Harbour syntax highlighting to code text using SimpleColoredComponent
     */
    private void applySyntaxHighlighting(String codeText) {
        try {
            // Use the existing Harbour syntax highlighter
            HarbourSyntaxHighlighter highlighter = new HarbourSyntaxHighlighter();
            Lexer lexer = highlighter.getHighlightingLexer();
            lexer.start(codeText);

            // Get current color scheme
            EditorColorsScheme scheme = EditorColorsManager.getInstance().getGlobalScheme();

            while (lexer.getTokenType() != null) {
                String tokenText = lexer.getTokenText();
                IElementType tokenType = lexer.getTokenType();
                TextAttributesKey[] keys = highlighter.getTokenHighlights(tokenType);

                SimpleTextAttributes attributes = SimpleTextAttributes.REGULAR_ATTRIBUTES;

                if (keys.length > 0) {
                    TextAttributes textAttrs = scheme.getAttributes(keys[0]);
                    if (textAttrs != null) {
                        attributes = SimpleTextAttributes.fromTextAttributes(textAttrs);
                    }
                }

                // Append the token with appropriate styling
                append(tokenText, attributes);
                lexer.advance();
            }

        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Failed to apply syntax highlighting: " + e.getMessage());
            // Fallback to plain text
            append(codeText, SimpleTextAttributes.REGULAR_ATTRIBUTES);
        }
    }
}
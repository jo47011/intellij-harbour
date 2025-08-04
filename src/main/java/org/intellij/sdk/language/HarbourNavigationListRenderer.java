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
import java.awt.*;

/**
 * Custom list cell renderer for Harbour navigation elements with syntax highlighting
 */
public class HarbourNavigationListRenderer extends ColoredListCellRenderer<PsiElement> {
    private static final String COMPONENT = "NavigationRenderer";

    @Override
    protected void customizeCellRenderer(@NotNull JList<? extends PsiElement> list,
                                         PsiElement element, int index,
                                         boolean selected, boolean hasFocus) {
        // Force monospace font for consistent character width
        setFont(new Font(Font.MONOSPACED, Font.PLAIN, 12));
        
        // Calculate dynamic filename column width based on all elements in the list
        int maxFileNameWidth = calculateMaxFileNameWidth(list);
        if (element instanceof HarbourNavigationElement) {
            HarbourNavigationElement navElement = (HarbourNavigationElement) element;

            // Handle separators and special elements
            if (navElement.isSeparator()) {
                String elementName = navElement.getElementName();
                // Check if this is a "Load All" element
                if (elementName != null && elementName.contains("more results")) {
                    // Render as clickable text centered in the list
                    append("    ", SimpleTextAttributes.REGULAR_ATTRIBUTES); // Indent
                    append(elementName, SimpleTextAttributes.LINK_ATTRIBUTES);
                } else {
                    // Regular separator line
                    int separatorWidth = maxFileNameWidth + 5 + 1 + 80;
                    String separatorLine = "─".repeat(separatorWidth);
                    append(separatorLine, SimpleTextAttributes.GRAYED_ATTRIBUTES);
                }
                return;
            }

            // Extract filename from path
            String filePath = navElement.getFilePath();
            String fileName = filePath != null ? filePath.substring(filePath.lastIndexOf('/') + 1) : "unknown";

            // Read and prepare code text
            String codeText = navElement.readLineFromFile(navElement.getFilePath(), navElement.getLineNumber());
            String processedCode = "";
            if (codeText != null && !codeText.isEmpty()) {
                processedCode = truncateCodeText(codeText.trim());
            }

            // Build the complete line with proper alignment
            // Format: filename (dynamic) + line number (5 right-aligned) + space (1) + code (fixed width)
            String truncatedFileName = truncateFileName(fileName, maxFileNameWidth);
            String formattedFileName = String.format("%-" + maxFileNameWidth + "s", truncatedFileName);
            String formattedLineNumber = String.format("%5d", navElement.getLineNumber());
            
            // Add the filename and line number first (these are fixed formatting)
            append(formattedFileName, SimpleTextAttributes.REGULAR_BOLD_ATTRIBUTES);
            append(formattedLineNumber, SimpleTextAttributes.GRAYED_ATTRIBUTES);
            append(" ", SimpleTextAttributes.REGULAR_ATTRIBUTES);
            
            // Ensure code is padded to consistent width, with ellipsis for truncated lines
            String paddedCode;
            if (processedCode.length() > 80) {
                paddedCode = processedCode.substring(0, 79) + "…";
            } else {
                paddedCode = String.format("%-80s", processedCode);
            }
            
            // Apply syntax highlighting to padded code portion
            applySyntaxHighlighting(paddedCode);

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
            int maxBase = maxWidth - extension.length() - 1; // -1 for "…"
            if (maxBase > 0) {
                return baseName.substring(0, Math.min(baseName.length(), maxBase)) + "…" + extension;
            } else {
                return "…" + extension;
            }
        } else {
            return fileName.substring(0, maxWidth - 1) + "…";
        }
    }

    /**
     * Format code text for display, allowing reasonable length without artificial truncation
     */
    private String truncateCodeText(String codeText) {
        if (codeText == null || codeText.isEmpty()) {
            return "";
        }
        
        // Allow much longer code lines - let popup size naturally
        // Only truncate extremely long lines (e.g., minified code, data strings)
        final int MAX_CODE_LENGTH = 150; // Increased from 43 to 150
        
        if (codeText.length() <= MAX_CODE_LENGTH) {
            return codeText;
        }
        
        // Truncate only very long lines and add ellipsis
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
                    if (textAttrs != null && textAttrs.getForegroundColor() != null) {
                        // Create SimpleTextAttributes with explicit color information
                        int style = SimpleTextAttributes.STYLE_PLAIN;
                        if (textAttrs.getFontType() == Font.BOLD) {
                            style |= SimpleTextAttributes.STYLE_BOLD;
                        }
                        if (textAttrs.getFontType() == Font.ITALIC) {
                            style |= SimpleTextAttributes.STYLE_ITALIC;
                        }
                        
                        attributes = new SimpleTextAttributes(
                            textAttrs.getBackgroundColor(),
                            textAttrs.getForegroundColor(),
                            textAttrs.getEffectColor(),
                            style
                        );
                        
                        // Removed excessive logging for performance
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

    /**
     * Calculate the maximum filename width needed for all elements in the list
     */
    private int calculateMaxFileNameWidth(JList<? extends PsiElement> list) {
        int maxWidth = 15; // Minimum width for filename column
        
        // Iterate through all elements to find the longest filename
        for (int i = 0; i < list.getModel().getSize(); i++) {
            PsiElement element = list.getModel().getElementAt(i);
            if (element instanceof HarbourNavigationElement) {
                HarbourNavigationElement navElement = (HarbourNavigationElement) element;
                
                // Skip separators
                if (navElement.isSeparator()) {
                    continue;
                }
                
                // Extract filename from path
                String filePath = navElement.getFilePath();
                if (filePath != null) {
                    String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                    maxWidth = Math.max(maxWidth, fileName.length());
                }
            }
        }
        
        // Add some reasonable limit to prevent extremely wide columns
        return Math.min(maxWidth, 30);
    }
}
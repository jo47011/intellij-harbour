package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

/**
 * Custom formatter for Harbour code that only removes double spaces
 * while preserving indentation and all other formatting
 */
public class HarbourCodeFormatter {
    private final Project project;

    public HarbourCodeFormatter(@NotNull Project project) {
        this.project = project;
        HarbourLogger.log("CodeFormatter", "Created HarbourCodeFormatter");
    }

    /**
     * Format the given file by removing double spaces
     * @param psiFile File to format
     * @return true if changes were made
     */
    public boolean format(@NotNull PsiFile psiFile) {
        if (!(psiFile instanceof HarbourFile)) {
            HarbourLogger.log("CodeFormatter", "Not a Harbour file: " + psiFile.getName());
            return false;
        }

        HarbourLogger.log("CodeFormatter", "Processing file: " + psiFile.getName());

        PsiDocumentManager documentManager = PsiDocumentManager.getInstance(project);
        Document document = documentManager.getDocument(psiFile);

        if (document == null) {
            HarbourLogger.log("CodeFormatter", "No document found for file: " + psiFile.getName());
            return false;
        }

        String originalText = document.getText();
        String formattedText = removeDoubleSpaces(originalText);

        // Only update document if changes were made
        if (!originalText.equals(formattedText)) {
            // Wrap in write action to avoid threading issues
            ApplicationManager.getApplication().runWriteAction(() -> {
                document.setText(formattedText);
                documentManager.commitDocument(document);
            });
            HarbourLogger.log("CodeFormatter", "Document updated with formatted text");
            return true;
        }

        HarbourLogger.log("CodeFormatter", "No changes needed for document");
        return false;
    }

    /**
     * Remove double spaces from text while preserving indentation and spaces in strings
     * @param text Text to process
     * @return Text with double spaces removed
     */
    private String removeDoubleSpaces(String text) {
        // Process text line by line to preserve line endings
        String[] lines = text.split("\n", -1);
        StringBuilder result = new StringBuilder(text.length());

        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];

            // Skip empty lines
            if (line.isEmpty()) {
                result.append(line);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            // Find leading whitespace
            int indentLength = 0;
            while (indentLength < line.length() && Character.isWhitespace(line.charAt(indentLength))) {
                indentLength++;
            }

            // Keep indentation exactly as is
            String indentation = line.substring(0, indentLength);
            String content = line.substring(indentLength);

            // Process content to remove double spaces (preserving spaces in strings)
            String processedContent = processContentPart(content);

            // Combine indentation and processed content
            result.append(indentation).append(processedContent);

            // Add newline if not the last line
            if (i < lines.length - 1) {
                result.append("\n");
            }
        }

        return result.toString();
    }

    /**
     * Process the content part of a line (after indentation) to remove double spaces
     * while preserving spaces in strings
     * @param content Content part of the line
     * @return Processed content with double spaces removed
     */
    private String processContentPart(String content) {
        // Skip empty content
        if (content.isEmpty()) {
            return content;
        }

        StringBuilder result = new StringBuilder(content.length());
        boolean inString = false;
        char stringDelimiter = 0;

        for (int i = 0; i < content.length(); i++) {
            char c = content.charAt(i);

            // Handle string delimiters
            if ((c == '"' || c == '\'') && (i == 0 || content.charAt(i - 1) != '\\')) {
                if (!inString) {
                    inString = true;
                    stringDelimiter = c;
                } else if (c == stringDelimiter) {
                    inString = false;
                }
            }

            // Handle spaces - only condense spaces outside of strings
            if (c == ' ' && !inString) {
                // Only add space if the last character wasn't a space
                if (result.length() == 0 || result.charAt(result.length() - 1) != ' ') {
                    result.append(c);
                }
            } else {
                result.append(c);
            }
        }

        return result.toString();
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.psi.impl.source.codeStyle.PostFormatProcessor;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

/**
 * Post-processes Harbour files after formatting to apply custom indentation rules
 * and line breaking according to settings
 */
public class HarbourPostFormatProcessor implements PostFormatProcessor {
    // Use HarbourLogger for centralized logging instead of local Logger instance

    // Improved patterns for function/procedure detection
    private static final Pattern FUNCTION_START_PATTERN =
            Pattern.compile("^\\s*((?:STATIC\\s+)?(?:FUNCTION|PROCEDURE)\\s+\\w+\\s*\\(?.*)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern FUNCTION_END_PATTERN =
            Pattern.compile("^\\s*RETURN(?:\\s+.*)?$", Pattern.CASE_INSENSITIVE);
    private static final Pattern LOCAL_DECLARATION_PATTERN =
            Pattern.compile("^\\s*LOCAL\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern DATA_DECLARATION_PATTERN =
            Pattern.compile("^\\s*DATA\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern MEMVAR_DECLARATION_PATTERN =
            Pattern.compile("^\\s*MEMVAR\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern PRIVATE_DECLARATION_PATTERN =
            Pattern.compile("^\\s*PRIVATE\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern METHOD_DECLARATION_PATTERN =
            Pattern.compile("^\\s*METHOD\\s+\\w+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern METHOD_IMPLEMENTATION_PATTERN =
            Pattern.compile("^\\s*METHOD\\s+\\w+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern CLASS_START_PATTERN =
            Pattern.compile("^\\s*CLASS\\s+\\w+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern CLASS_END_PATTERN =
            Pattern.compile("^\\s*ENDCLASS.*$", Pattern.CASE_INSENSITIVE);

    // Patterns for detecting string continuations
    private static final Pattern STRING_CONTINUATION_PATTERN =
            Pattern.compile(".*[\"']\\s*\\+\\s*;\\s*$");
    private static final Pattern STRING_START_PATTERN =
            Pattern.compile("^\\s*[\"'].*");

    // New patterns for switch/case statements and DO CASE statements
    private static final Pattern SWITCH_PATTERN =
            Pattern.compile("^\\s*SWITCH\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern DO_CASE_PATTERN =
            Pattern.compile("^\\s*DO\\s+CASE.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern CASE_PATTERN =
            Pattern.compile("^\\s*CASE\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern OTHERWISE_PATTERN =
            Pattern.compile("^\\s*OTHERWISE.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENDSWITCH_PATTERN =
            Pattern.compile("^\\s*ENDSWITCH.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENDCASE_PATTERN =
            Pattern.compile("^\\s*ENDCASE.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern LINE_CONTINUATION_PATTERN =
            Pattern.compile(".*;\\s*$");

    // Pattern for detecting comment-only lines
    private static final Pattern COMMENT_LINE_PATTERN =
            Pattern.compile("^\\s*(?://.*|/\\*.*|.*\\*/\\s*|\\*.*?)$");

    // Patterns for fmt:off and fmt:on comments
    private static final Pattern FMT_OFF_PATTERN =
            Pattern.compile("^\\s*//\\s*fmt:off\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern FMT_ON_PATTERN =
            Pattern.compile("^\\s*//\\s*fmt:on\\s*$", Pattern.CASE_INSENSITIVE);
            
    // Pattern for detecting array/block syntax that should not be broken
    private static final Pattern ARRAY_BLOCK_PATTERN =
            Pattern.compile(".*\\s*:=\\s*\\{.*\\}.*");
    private static final Pattern CODEBLOCK_PATTERN =
            Pattern.compile(".*\\{\\s*\\|\\|.*\\}.*");
    
    // Harbour keywords that should never be split across lines
    private static final String[] HARBOUR_KEYWORDS = {
        ".and.", ".or.", ".not.", ".t.", ".f.", ".true.", ".false."
    };
    
    // Harbour regular keywords that should not be split (word boundaries)
    private static final String[] HARBOUR_WORD_KEYWORDS = {
        "when", "valid", "picture", "say", "get", "read"
    };
    
    // Harbour constructs that should be treated carefully for line breaking
    // Only prevent breaking very specific short constructs, allow breaking longer complex ones
    private static final Pattern SIMPLE_GET_WHEN_PATTERN = 
            Pattern.compile("^\\s*@\\s*\\w+\\s*get\\s+\\w+\\s+when\\s+\\w+\\s*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern SIMPLE_SAY_GET_PATTERN = 
            Pattern.compile("^\\s*say\\s+\"[^\"]*\"\\s+get\\s+\\w+\\s*$", Pattern.CASE_INSENSITIVE);
    
    // Patterns for BEGIN SEQUENCE constructs
    private static final Pattern BEGIN_SEQUENCE_PATTERN =
            Pattern.compile("^\\s*BEGIN\\s+SEQUENCE.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern RECOVER_USING_PATTERN =
            Pattern.compile("^\\s*RECOVER\\s+USING.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern END_SEQUENCE_PATTERN =
            Pattern.compile("^\\s*END\\s+SEQUENCE.*$", Pattern.CASE_INSENSITIVE);

    @Override
    public @NotNull PsiElement processElement(@NotNull PsiElement element, @NotNull CodeStyleSettings settings) {
        return element;
    }

    @Override
    public @NotNull TextRange processText(@NotNull PsiFile file, @NotNull TextRange textRange, @NotNull CodeStyleSettings settings) {
        if (!(file instanceof HarbourFile)) {
            log("Not a Harbour file, skipping");
            return textRange;
        }

        Project project = file.getProject();
        
        // Get Harbour custom code style settings
        HarbourCodeStyleSettings harbourCodeStyleSettings = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        
        // Get line break position from common code style settings (RIGHT_MARGIN)
        int lineBreakPosition = settings.getRightMargin(HarbourLanguage.INSTANCE);
        
        log("Processing file: " + file.getName() + " with line break position: " + lineBreakPosition);

        PsiDocumentManager documentManager = PsiDocumentManager.getInstance(project);
        Document document = documentManager.getDocument(file);
        if (document == null) {
            log("No document found for file: " + file.getName());
            return textRange;
        }

        log("Post-processing text in Harbour file: " + file.getName());
        HarbourTokenTypeExtension.setFormattingInProgress(true);

        try {
            // Get only the selected text range
            String selectedText = document.getText(textRange);
            log("Processing text range: " + textRange.getStartOffset() + " to " + textRange.getEndOffset());
            log("Selected text length: " + selectedText.length());

            // Preserve exact original trailing whitespace - store it separately
            String originalTrailingWhitespace = extractTrailingWhitespace(selectedText);
            log("Original trailing whitespace: '" + originalTrailingWhitespace.replace("\n", "\\n") + "'");

            // Process step by step
            String formattedText = formatHarbourCode(selectedText, lineBreakPosition, harbourCodeStyleSettings);

            // Make sure to restore exact original trailing whitespace
            formattedText = ensureTrailingWhitespace(formattedText, originalTrailingWhitespace);
            log("Restored original trailing whitespace");

            if (!selectedText.equals(formattedText)) {
                log("Text changed after formatting, applying changes to selection");
                final String textToApply = formattedText;
                ApplicationManager.getApplication().runWriteAction(() -> {
                    try {
                        document.replaceString(textRange.getStartOffset(), textRange.getEndOffset(), textToApply);
                        documentManager.commitDocument(document);
                        log("Successfully applied text changes to selection");
                    } catch (Exception e) {
                        log("Error applying text changes: " + e.getMessage());
                    }
                });
            } else {
                log("No text changes needed after formatting");
            }
        } catch (Exception e) {
            log("Exception during formatting: " + e.getMessage());
            log("Stack trace: ");
            for (int i = 0; i < Math.min(5, e.getStackTrace().length); i++) {
                log("  at " + e.getStackTrace()[i]);
            }
            e.printStackTrace();
        } finally {
            HarbourTokenTypeExtension.setFormattingInProgress(false);
        }

        return textRange;
    }

    /**
     * Extract the exact trailing whitespace from text
     */
    private String extractTrailingWhitespace(String text) {
        int lastNonWhitespace = text.length() - 1;
        while (lastNonWhitespace >= 0 && Character.isWhitespace(text.charAt(lastNonWhitespace))) {
            lastNonWhitespace--;
        }

        if (lastNonWhitespace >= text.length() - 1) {
            return ""; // No trailing whitespace
        }

        return text.substring(lastNonWhitespace + 1);
    }

    /**
     * Ensure the text has exactly the specified trailing whitespace
     */
    private String ensureTrailingWhitespace(String text, String trailingWhitespace) {
        // First remove all trailing whitespace
        String trimmed = text.replaceAll("\\s+$", "");

        // Then add the original trailing whitespace
        return trimmed + trailingWhitespace;
    }

    /**
     * Main formatting method
     */
    private String formatHarbourCode(String text, int lineBreakPosition, HarbourCodeStyleSettings settings) {
        String[] lines = text.split("\n", -1);
        StringBuilder result = new StringBuilder(text.length());

        int indentLevel = 0;
        boolean inFunctionBody = false;
        boolean inSwitchBlock = false;
        boolean inDoCaseBlock = false;
        boolean inClassDefinition = false;
        boolean inBlockComment = false; // Track if we're inside a block comment
        boolean inFmtOffBlock = false; // Track if we're inside a fmt:off block
        int indentSize = 2; // Default indentation size for Harbour
        
        // Get custom indentation settings
        int localIndent = settings.LOCAL_INDENT;
        int returnIndent = settings.RETURN_INDENT;
        int dataIndent = settings.DATA_INDENT;
        int methodIndent = settings.METHOD_INDENT;
        int memvarIndent = settings.MEMVAR_INDENT;
        int privateIndent = settings.PRIVATE_INDENT;
        boolean sequenceLikeNormalCode = settings.SEQUENCE_LIKE_NORMAL_CODE;

        // Removed verbose logging for performance

        // First pass - join continuation lines that need re-wrapping
        List<String> processedLines = new ArrayList<>();
        List<String> originalIndents = new ArrayList<>();

        int lineIdx = 0;
        while (lineIdx < lines.length) {
            String currentLine = lines[lineIdx];
            String currentTrimmed = currentLine.trim();

            // Check for fmt:off/fmt:on comments
            if (FMT_OFF_PATTERN.matcher(currentTrimmed).matches()) {
                inFmtOffBlock = true;
                processedLines.add(currentLine);
                originalIndents.add("");
                lineIdx++;
                continue;
            } else if (FMT_ON_PATTERN.matcher(currentTrimmed).matches()) {
                inFmtOffBlock = false;
                processedLines.add(currentLine);
                originalIndents.add("");
                lineIdx++;
                continue;
            }

            // If we're in a fmt:off block, preserve the line exactly as-is
            if (inFmtOffBlock) {
                processedLines.add(currentLine);
                originalIndents.add("");
                lineIdx++;
                continue;
            }

            // Check if this line ends with a continuation semicolon
            // In Harbour, semicolons are ONLY used as continuation markers, never as statement terminators
            if (currentTrimmed.endsWith(";") && lineIdx < lines.length - 1) {
                    // First, check if joining is needed - only join if one of the lines is too long
                    boolean needsJoining = false;

                    // Check if current line (without semicolon) is too long
                    if (currentLine.trim().length() - 1 > 99) {
                        needsJoining = true;
                    }

                    // Check continuation lines
                    if (!needsJoining) {
                        int tempIdx = lineIdx + 1;
                        while (tempIdx < lines.length) {
                            String tempLine = lines[tempIdx].trim();
                            if (!tempLine.isEmpty()) {
                                // Check line length (remove semicolon if present)
                                int len = tempLine.endsWith(";") ? tempLine.length() - 1 : tempLine.length();
                                if (len > 99) {
                                    needsJoining = true;
                                    break;
                                }
                                // Check if this line continues
                                if (!tempLine.endsWith(";")) {
                                    break;
                                }
                            }
                            tempIdx++;
                        }
                    }

                    // If no lines are too long, don't join - keep as is
                    if (!needsJoining) {
                        log("Continuation lines are properly formatted, not joining");

                        // Debug logging for problematic case
                        if (currentTrimmed.contains("Liste(")) {
                            log("DEBUG: Processing Liste line with continuation");
                            log("  Current line: '" + currentLine + "'");
                            log("  Current trimmed: '" + currentTrimmed + "'");
                        }

                        // Add current line unchanged but remove spaces around :=
                        String fixedLine = currentLine.replaceAll("\\s*:=\\s*", ":=");
                        processedLines.add(fixedLine);
                        String firstIndent = currentLine.substring(0, Math.max(0, currentLine.length() - currentTrimmed.length()));
                        originalIndents.add(firstIndent);

                        // Add all continuation lines with proper indentation (one extra level)
                        int j = lineIdx + 1;
                        while (j < lines.length) {
                            String nextLine = lines[j];
                            String nextTrimmed = nextLine.trim();

                            if (!nextTrimmed.isEmpty()) {
                                // Get the existing indentation of this line
                                String existingIndent = nextLine.substring(0, Math.max(0, nextLine.length() - nextTrimmed.length()));
                                // Add extra indentation to the existing indentation
                                String continuationIndent = existingIndent + " ".repeat(indentSize);

                                // Fix spaces around := if present and apply proper indentation
                                String fixedContent = nextTrimmed.replaceAll("\\s*:=\\s*", ":=");
                                String fixedNextLine = continuationIndent + fixedContent;
                                processedLines.add(fixedNextLine);
                                originalIndents.add(continuationIndent);

                                // Check if this line continues
                                if (!nextTrimmed.endsWith(";") || j == lines.length - 1) {
                                    break;
                                }
                            }
                            j++;
                        }

                        lineIdx = j + 1;
                        continue;
                    }

                    // Check if this is a string with nested quotes - if so, don't join
                    boolean hasNestedQuotes = false;

                    // Check the current line for string assignment with nested quotes
                    int assignPos = currentTrimmed.indexOf(":=");
                    if (assignPos > 0 && assignPos < currentTrimmed.length() - 2) {
                        // Skip spaces after :=
                        int pos = assignPos + 2;
                        while (pos < currentTrimmed.length() && currentTrimmed.charAt(pos) == ' ') {
                            pos++;
                        }

                        if (pos < currentTrimmed.length()) {
                            char quoteChar = currentTrimmed.charAt(pos);
                            if (quoteChar == '"' || quoteChar == '\'') {
                                // Check for nested quotes in the entire continuation block
                                char innerQuote = (quoteChar == '"') ? '\'' : '"';

                                // Check current line
                                for (int i = pos + 1; i < currentTrimmed.length(); i++) {
                                    if (currentTrimmed.charAt(i) == innerQuote) {
                                        hasNestedQuotes = true;
                                        break;
                                    }
                                }

                                // Check continuation lines for nested quotes
                                if (!hasNestedQuotes) {
                                    int tempIdx = lineIdx + 1;
                                    while (tempIdx < lines.length) {
                                        String tempLine = lines[tempIdx].trim();
                                        if (!tempLine.isEmpty()) {
                                            for (char c : tempLine.toCharArray()) {
                                                if (c == innerQuote) {
                                                    hasNestedQuotes = true;
                                                    break;
                                                }
                                            }
                                            if (hasNestedQuotes) break;

                                            // Check if this line continues
                                            if (!tempLine.endsWith(";")) {
                                                break;
                                            }
                                        }
                                        tempIdx++;
                                    }
                                }
                            }
                        }
                    }

                    // If nested quotes found, don't join - keep lines but fix := spacing
                    if (hasNestedQuotes) {
                        log("Found nested quotes in continuation lines, not joining");
                        // Add first line with fixed := spacing
                        String fixedLine = currentLine.replaceAll("\\s*:=\\s*", ":=");
                        processedLines.add(fixedLine);
                        String firstIndent = currentLine.substring(0, Math.max(0, currentLine.length() - currentTrimmed.length()));
                        originalIndents.add(firstIndent);

                        log("First indent length: " + firstIndent.length() + ", indentSize: " + indentSize);

                        // Add all continuation lines with proper indentation
                        int j = lineIdx + 1;
                        while (j < lines.length) {
                            String nextLine = lines[j];
                            String nextTrimmed = nextLine.trim();

                            if (!nextTrimmed.isEmpty()) {
                                // Get the existing indentation of this line
                                String existingIndent = nextLine.substring(0, Math.max(0, nextLine.length() - nextTrimmed.length()));
                                // Add extra indentation to the existing indentation
                                String continuationIndent = existingIndent + " ".repeat(indentSize);
                                log("Existing indent: " + existingIndent.length() + " spaces, adding " + indentSize + " more");

                                // Apply proper indentation
                                String fixedNextLine = continuationIndent + nextTrimmed;
                                log("Original line: '" + nextLine + "' -> Fixed: '" + fixedNextLine + "'");
                                processedLines.add(fixedNextLine);
                                originalIndents.add(continuationIndent);

                                // Check if this line continues
                                if (!nextTrimmed.endsWith(";") || j == lines.length - 1) {
                                    break;
                                }
                            }
                            j++;
                        }

                        lineIdx = j + 1;
                        continue;
                    }

                    // This is a continuation line - join all continuations
                    StringBuilder joined = new StringBuilder();
                    String firstIndent = currentLine.substring(0, Math.max(0, currentLine.length() - currentTrimmed.length()));

                    // Remove the trailing semicolon and add the content
                    String firstPart = currentTrimmed.substring(0, currentTrimmed.length() - 1);

                    // Track parentheses balance to detect if we're inside a function call
                    int totalOpenParens = 0;
                    for (char c : firstPart.toCharArray()) {
                        if (c == '(') totalOpenParens++;
                        else if (c == ')') totalOpenParens--;
                    }

                    // Check if it ends with string concatenation pattern
                    if (firstPart.endsWith("\"+ ") || firstPart.endsWith("' +") ||
                        firstPart.endsWith("\" +") || firstPart.endsWith("'+ ") ||
                        firstPart.endsWith("\"+") || firstPart.endsWith("'+")) {
                        // Remove the concatenation operator when joining strings
                        firstPart = firstPart.replaceAll("[\"']\\s*\\+\\s*$", "");
                    }
                    joined.append(firstPart);

                    // Join all continuation lines
                    int j = lineIdx + 1;
                    while (j < lines.length) {
                        String nextLine = lines[j];
                        String nextTrimmed = nextLine.trim();

                        if (!nextTrimmed.isEmpty()) {
                            String lineToAdd = nextTrimmed;

                            // Update total parentheses count with this line
                            for (char c : lineToAdd.toCharArray()) {
                                if (c == '(') totalOpenParens++;
                                else if (c == ')') totalOpenParens--;
                            }

                            // Check if this line also continues
                            boolean continues = false;
                            if (nextTrimmed.endsWith(";") && j < lines.length - 1) {
                                // If we're still inside parentheses (totalOpenParens > 0),
                                // the semicolon is definitely a continuation
                                if (totalOpenParens > 0) {
                                    continues = true;
                                    // Remove the trailing semicolon
                                    lineToAdd = nextTrimmed.substring(0, nextTrimmed.length() - 1);
                                    // Update parentheses count after removing semicolon
                                    totalOpenParens = 0;
                                    for (char c : joined.toString().toCharArray()) {
                                        if (c == '(') totalOpenParens++;
                                        else if (c == ')') totalOpenParens--;
                                    }
                                    for (char c : lineToAdd.toCharArray()) {
                                        if (c == '(') totalOpenParens++;
                                        else if (c == ')') totalOpenParens--;
                                    }
                                } else {
                                    // Check the old way for other cases
                                    int nextLastSemi = nextTrimmed.lastIndexOf(';');
                                    int nextLastParen = nextTrimmed.lastIndexOf(')');
                                    if (nextLastParen < nextLastSemi) {
                                        continues = true;
                                        // Remove the trailing semicolon
                                        lineToAdd = nextTrimmed.substring(0, nextTrimmed.length() - 1);
                                    }
                                }
                            }

                            // Handle string concatenation when joining
                            if (lineToAdd.startsWith("\"") || lineToAdd.startsWith("'")) {
                                // This is a string continuation - just append the content
                                char quote = lineToAdd.charAt(0);
                                int endQuote = lineToAdd.lastIndexOf(quote);
                                if (endQuote > 0) {
                                    // Extract just the string content without quotes
                                    String stringContent = lineToAdd.substring(1, endQuote);
                                    joined.append(stringContent);
                                    // Add anything after the closing quote
                                    if (endQuote < lineToAdd.length() - 1) {
                                        String after = lineToAdd.substring(endQuote + 1);
                                        // Remove leading concatenation operators
                                        after = after.replaceAll("^\\s*\\+\\s*", "");
                                        if (!after.isEmpty()) {
                                            joined.append(after);
                                        }
                                    }
                                } else {
                                    // No closing quote found, just add with space
                                    joined.append(" ").append(lineToAdd);
                                }
                            } else {
                                // Not a string, add with space
                                joined.append(" ").append(lineToAdd);
                            }

                            if (!continues) {
                                break;
                            }
                        }
                        j++;
                    }

                    // Add the joined line
                    processedLines.add(firstIndent + joined.toString());
                    originalIndents.add(firstIndent);

                    // Skip the lines we just joined
                    lineIdx = j + 1;
                    continue;
            }

            // Not a continuation or not joinable - add as is but fix := spacing
            String fixedLine = currentLine.replaceAll("\\s*:=\\s*", ":=");
            processedLines.add(fixedLine);
            String indent = currentLine.substring(0, Math.max(0, currentLine.length() - currentTrimmed.length()));
            originalIndents.add(indent);
            lineIdx++;
        }

        // Now use processedLines instead of lines
        lines = processedLines.toArray(new String[0]);

        // Store previous line's *actual* indentation for comment alignment
        String previousLineActualIndent = "";

        // Track format exclusion
        boolean inFormatExclusion = false;
        inFmtOffBlock = false; // Reset for second pass

        // Main processing loop
        for (int i = 0; i < lines.length; i++) {
            String lineWithWhitespace = lines[i];
            String line = lineWithWhitespace.trim();

            // Check for fmt:off/fmt:on comments (no space between fmt: and off/on)
            if (FMT_OFF_PATTERN.matcher(line).matches()) {
                inFmtOffBlock = true;
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            if (FMT_ON_PATTERN.matcher(line).matches()) {
                inFmtOffBlock = false;
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            // If in fmt:off block, preserve as-is
            if (inFmtOffBlock) {
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            // Clean up malformed continuations
            // This fixes code that was previously malformed
            if (line.contains(",;") && !line.endsWith(",;")) {
                // Replace ,; in the middle of line with just ,
                line = line.replaceAll(",;\\s+", ", ");
                lineWithWhitespace = lineWithWhitespace.replaceAll(",;\\s+", ", ");
            }

            // Clean up semicolons before logical operators on the SAME line
            // Don't remove semicolons at end of line (for continuations)
            if (!line.trim().endsWith(";")) {
                // Only clean up if semicolon is not at the end
                line = line.replaceAll(";\\s+\\.and\\.", " .and.");
                line = line.replaceAll(";\\s+\\.or\\.", " .or.");
                line = line.replaceAll(";\\s+\\.not\\.", " .not.");
                lineWithWhitespace = lineWithWhitespace.replaceAll(";\\s+\\.and\\.", " .and.");
                lineWithWhitespace = lineWithWhitespace.replaceAll(";\\s+\\.or\\.", " .or.");
                lineWithWhitespace = lineWithWhitespace.replaceAll(";\\s+\\.not\\.", " .not.");
            }
            
            // Check for block comment start/end
            if (line.contains("/*")) {
                inBlockComment = true;
            }
            
            // If we're in a block comment, preserve the line as-is
            if (inBlockComment) {
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                // Check if this line ends the block comment
                if (line.contains("*/")) {
                    inBlockComment = false;
                }
                continue; // Skip all other processing for block comment lines
            }

            // Handle empty lines
            if (line.isEmpty()) {
                // Always preserve empty lines - the semicolon cleanup will handle unnecessary semicolons
                result.append("\n");
                continue;
            }

            // Skip lone semicolons
            if (line.equals(";")) {
                continue;
            }

            // Process indentation and code structure
            String lowerLine = line.toLowerCase();

            // Check for function/procedure start
            Matcher functionStartMatcher = FUNCTION_START_PATTERN.matcher(line);
            boolean isMethodImplementation = METHOD_IMPLEMENTATION_PATTERN.matcher(line).matches();
            
            if (functionStartMatcher.matches() || isMethodImplementation) {
                // Found function/procedure start or method implementation
                indentLevel = 0;
                inFunctionBody = true;
                inSwitchBlock = false;
                inDoCaseBlock = false;
            }

            // Check for class start/end
            boolean isClassStatement = CLASS_START_PATTERN.matcher(line).matches();
            boolean isEndClassStatement = CLASS_END_PATTERN.matcher(line).matches();
            if (isClassStatement) {
                inClassDefinition = true;
            } else if (isEndClassStatement) {
                inClassDefinition = false;
            }

            // Check for switch statement
            boolean isSwitchStatement = SWITCH_PATTERN.matcher(line).matches();
            if (isSwitchStatement) {
                // Found switch statement
                inSwitchBlock = true;
            }

            // Check for DO CASE statement
            boolean isDoCaseStatement = DO_CASE_PATTERN.matcher(line).matches();
            if (isDoCaseStatement) {
                // Found DO CASE statement
                inDoCaseBlock = true;
            }

            // Check for case statement
            boolean isCaseStatement = CASE_PATTERN.matcher(line).matches();
            
            // Check for otherwise statement
            boolean isOtherwiseStatement = OTHERWISE_PATTERN.matcher(line).matches();

            // Check for endswitch statement
            boolean isEndSwitchStatement = ENDSWITCH_PATTERN.matcher(line).matches();
            if (isEndSwitchStatement) {
                // Found endswitch statement
                inSwitchBlock = false;
            }
            
            // Check for endcase statement
            boolean isEndCaseStatement = ENDCASE_PATTERN.matcher(line).matches();
            if (isEndCaseStatement) {
                inDoCaseBlock = false;
            }

            // Detect RETURN statements - all will use normal indentation now
            boolean isReturnStatement = FUNCTION_END_PATTERN.matcher(line).matches();

            // Check for statement types
            boolean isLocalDeclaration = LOCAL_DECLARATION_PATTERN.matcher(line).matches();
            boolean isDataDeclaration = DATA_DECLARATION_PATTERN.matcher(line).matches();
            boolean isMemvarDeclaration = MEMVAR_DECLARATION_PATTERN.matcher(line).matches();
            boolean isPrivateDeclaration = PRIVATE_DECLARATION_PATTERN.matcher(line).matches();
            boolean isMethodDeclaration = METHOD_DECLARATION_PATTERN.matcher(line).matches();
            boolean isBeginSequence = BEGIN_SEQUENCE_PATTERN.matcher(line).matches();
            boolean isRecoverUsing = RECOVER_USING_PATTERN.matcher(line).matches();
            boolean isEndSequence = END_SEQUENCE_PATTERN.matcher(line).matches();
            
            int effectiveIndentLevel = indentLevel;
            int customIndentSpaces = -1; // -1 means use standard indentation

            // Apply custom indentation for specific statement types
            // NOTE: RETURN statements at function/method end use custom indentation, others use normal
            if (isReturnStatement) {
                // Check if this RETURN is at the end of a function/method (indentLevel == 1)
                // or inside control structures (indentLevel > 1)
                if (inFunctionBody && indentLevel == 1) {
                    // RETURN at the end of function/method - use custom indentation
                    customIndentSpaces = returnIndent;
                } else {
                    // RETURN inside control structures - use normal indentation
                    customIndentSpaces = -1;
                }
            } else if (isLocalDeclaration && inFunctionBody) {
                // Apply custom indentation for LOCAL declarations
                customIndentSpaces = localIndent;
            } else if (isDataDeclaration) {
                // Apply custom indentation for DATA declarations
                customIndentSpaces = dataIndent;
            } else if (isMemvarDeclaration) {
                // Apply custom indentation for MEMVAR declarations
                customIndentSpaces = memvarIndent;
            } else if (isPrivateDeclaration) {
                // Apply custom indentation for PRIVATE declarations
                customIndentSpaces = privateIndent;
            } else if (isMethodDeclaration && inClassDefinition) {
                // Apply custom indentation for METHOD declarations only inside CLASS/ENDCLASS
                customIndentSpaces = methodIndent;
            } else if (isBeginSequence || isRecoverUsing || isEndSequence) {
                // BEGIN SEQUENCE should always be indented like normal code
                // The checkbox only controls whether content inside gets extra indentation
                customIndentSpaces = -1; // Use normal indentation
            }

            // Block ending check
            boolean isBlockEnd = lowerLine.startsWith("endif") ||
                    lowerLine.startsWith("enddo") ||
                    lowerLine.startsWith("endcase") ||
                    lowerLine.startsWith("next");

            // Additional block end check for endswitch, endclass, and end sequence
            if (isEndSwitchStatement || isEndClassStatement || isEndSequence) {
                isBlockEnd = true;
            }
            
            // RECOVER USING should also be treated as a block ending/transition
            if (isRecoverUsing) {
                isBlockEnd = true;
            }

            // Adjust indentation for case and otherwise statements
            if (isCaseStatement || isOtherwiseStatement) {
                if (inSwitchBlock) {
                    // Handling case/otherwise statement in switch block
                    // Case/otherwise statements are at the same level as switch
                    effectiveIndentLevel = indentLevel - 1;
                } else if (inDoCaseBlock) {
                    // For DO CASE blocks, CASE and OTHERWISE statements should NOT be indented further
                    // They should be at the same level as DO CASE
                    if (indentLevel > 0) effectiveIndentLevel = indentLevel - 1;
                }
            } else if (inSwitchBlock && !isEndSwitchStatement) {
                // For content inside case blocks in SWITCH, use switch level + 1
                // This gives one level of indentation instead of two
                effectiveIndentLevel = Math.min(effectiveIndentLevel, (indentLevel - 1) + 1);
            }

            // Check for else/elseif statements that need special handling
            boolean isElseStatement = lowerLine.equals("else") || lowerLine.startsWith("elseif");
            
            // Handle else/elseif indentation - they should be at the same level as their corresponding if
            if (isElseStatement) {
                // Temporarily decrease effectiveIndentLevel for this line only
                if (effectiveIndentLevel > 0) effectiveIndentLevel--;
            }
            
            // Special handling for SEQUENCE block terminators - they should align with BEGIN SEQUENCE
            if (isRecoverUsing || isEndSequence) {
                // These should be at the same level as BEGIN SEQUENCE, so reduce by 1
                if (effectiveIndentLevel > 0) {
                    effectiveIndentLevel = effectiveIndentLevel - 1;
                }
            }
            
            // Reduce indentation for block endings AFTER all other adjustments
            if (isBlockEnd) {
                if (indentLevel > 0) indentLevel--;
            }

            // Check if this line is a continuation of previous line
            // Since we joined continuations, this should always be false now
            boolean isLineContinuation = false;

            // Check if previous line ends with semicolon (manual continuation formatting)
            // After joining, lines shouldn't have continuation semicolons anymore
            boolean prevLineHasContinuation = false;

            // Handle comment-only lines - use previous line's indentation
            boolean isCommentOnlyLine = COMMENT_LINE_PATTERN.matcher(line).matches();
            String newIndent;

            if (isCommentOnlyLine) {
                // Check if next line is a function/procedure declaration
                boolean nextLineIsFunction = false;
                if (i < lines.length - 1) {
                    String nextLine = lines[i + 1].trim();
                    nextLineIsFunction = FUNCTION_START_PATTERN.matcher(nextLine).matches() || 
                                       METHOD_IMPLEMENTATION_PATTERN.matcher(nextLine).matches();
                }
                
                if (nextLineIsFunction) {
                    // Comments above functions should not be indented
                    newIndent = "";
                } else {
                    // Other comments should use previous line's indentation
                    newIndent = previousLineActualIndent;
                }
            } else if (isLineContinuation) {
                // For continuation lines, add extra indent
                newIndent = previousLineActualIndent + " ".repeat(indentSize);
                // Using continuation indentation for line line
            } else if (isClassStatement || isEndClassStatement) {
                // CLASS and ENDCLASS should never be indented
                newIndent = "";
            } else if (customIndentSpaces >= 0) {
                // Use custom indentation for specific statement types
                newIndent = " ".repeat(customIndentSpaces);
            } else {
                // Apply standard indent
                int finalIndentLevel = isBlockEnd ? indentLevel : effectiveIndentLevel;
                newIndent = " ".repeat(finalIndentLevel * indentSize);
            }

            // Indentation decisions handled above

            // Remove double spaces while preserving strings and fix assignment operator spacing
            StringBuilder processedContent = new StringBuilder();
            boolean inString = false;
            char stringDelimiter = 0;

            // Special handling for the last line - preserve trailing spaces
            boolean isLastLine = (i == lines.length - 1);

            for (int j = 0; j < line.length(); j++) {
                char c = line.charAt(j);

                // Handle string delimiters
                if ((c == '"' || c == '\'') && (j == 0 || line.charAt(j - 1) != '\\')) {
                    if (!inString) {
                        inString = true;
                        stringDelimiter = c;
                    } else if (c == stringDelimiter) {
                        inString = false;
                    }
                }

                // Handle spaces - preserve all spaces on last line
                if (c == ' ' && !inString && !isLastLine) {
                    // Check if this is a space before or after :=
                    boolean skipSpace = false;
                    if (j + 1 < line.length() && line.charAt(j + 1) == ':' &&
                        j + 2 < line.length() && line.charAt(j + 2) == '=') {
                        // Space before :=
                        skipSpace = true;
                    } else if (j > 1 && line.charAt(j - 1) == '=' && line.charAt(j - 2) == ':') {
                        // Space after :=
                        skipSpace = true;
                    } else if (processedContent.length() > 0 &&
                              processedContent.charAt(processedContent.length() - 1) == ' ') {
                        // Consecutive space
                        skipSpace = true;
                    }

                    if (!skipSpace) {
                        processedContent.append(c);
                    }
                } else {
                    processedContent.append(c);
                }
            }

            // Processed line with proper indent
            String processedLine = newIndent + processedContent.toString();

            // Debug: Log all long lines
            if (processedLine.length() > 99) {
                log("LONG LINE (>" + 99 + "): " + processedLine.substring(0, Math.min(50, processedLine.length())) + "...");
                log("  - Full length: " + processedLine.length());
                log("  - lineBreakPosition: " + lineBreakPosition);
                log("  - Will break: " + (lineBreakPosition > 0 && processedLine.length() > lineBreakPosition));
            }

            // Add missing semicolon if next line is a continuation
            if (!processedLine.trim().endsWith(";") && i < lines.length - 1) {
                String trimmed = processedLine.trim().toLowerCase();

                // Never add semicolon after control structure keywords
                if (trimmed.startsWith("if ") || trimmed.equals("if") ||
                    trimmed.startsWith("else") || trimmed.equals("else") ||
                    trimmed.startsWith("elseif ") ||
                    trimmed.startsWith("for ") ||
                    trimmed.startsWith("while ") ||
                    trimmed.startsWith("do ") ||
                    trimmed.startsWith("case ") ||
                    trimmed.equals("otherwise") ||
                    trimmed.startsWith("switch ") ||
                    trimmed.startsWith("class ") ||
                    trimmed.startsWith("method ") ||
                    trimmed.startsWith("function ") ||
                    trimmed.startsWith("procedure ") ||
                    trimmed.startsWith("begin ") ||
                    trimmed.startsWith("recover ")) {
                    // These keywords should never have semicolons
                    // Skip semicolon addition
                } else {
                    String nextLine = lines[i + 1];
                    String nextLineTrimmed = nextLine.trim();

                    // Don't add semicolon if next line is a control structure keyword
                    String nextLineLower = nextLineTrimmed.toLowerCase();
                    if (nextLineLower.startsWith("else") ||
                        nextLineLower.startsWith("elseif") ||
                        nextLineLower.startsWith("endif") ||
                        nextLineLower.startsWith("next") ||
                        nextLineLower.startsWith("enddo") ||
                        nextLineLower.startsWith("endcase") ||
                        nextLineLower.startsWith("endswitch") ||
                        nextLineLower.startsWith("end")) {
                        // Don't add semicolon before control structure keywords
                    } else {
                        // Check if next line is indented more than this line (suggesting continuation)
                        int thisIndent = processedLine.length() - processedLine.trim().length();
                        int nextIndent = nextLine.length() - nextLineTrimmed.length();

                        // If next line is indented more and starts with certain patterns, it's a continuation
                        if (nextIndent > thisIndent && !nextLineTrimmed.isEmpty()) {
                            // Check if it starts with continuation patterns
                            if (nextLineTrimmed.startsWith("\"") ||
                                nextLineTrimmed.startsWith("'") ||
                                nextLineTrimmed.startsWith(".and.") ||
                                nextLineTrimmed.startsWith(".or.") ||
                                nextLineTrimmed.startsWith(".not.") ||
                                nextLineTrimmed.startsWith(",") ||
                                nextLineTrimmed.startsWith("+") ||
                                nextLineTrimmed.startsWith("-") ||
                                nextLineTrimmed.startsWith("*") ||
                                nextLineTrimmed.startsWith("/")) {
                                // This is a continuation, add semicolon
                                if (!processedLine.trim().isEmpty() && !processedLine.trim().endsWith(";")) {
                                    processedLine = processedLine + ";";
                                }
                            }
                        }
                    }
                }
            }

            // Remove unnecessary trailing semicolon ONLY if next line is empty
            else if (processedLine.trim().endsWith(";") && i < lines.length - 1) {
                String nextLineTrimmed = lines[i + 1].trim();
                // Only remove semicolon if next line is empty (no continuation needed)
                if (nextLineTrimmed.isEmpty()) {
                    // Next line is empty, semicolon is not needed
                    String trimmed = processedLine.trim();
                    if (trimmed.endsWith(";")) {
                        processedLine = newIndent + trimmed.substring(0, trimmed.length() - 1);
                    }
                }
            }

            // Store this actual indentation for the next line's potential comment
            // This needs to be stored AFTER all special handling is done
            if (!isCommentOnlyLine && !isLineContinuation) {
                previousLineActualIndent = newIndent;
            }

            if (lineBreakPosition > 0 && processedLine.length() > lineBreakPosition && lines.length < 10000 &&
                       !isLineContinuation && !prevLineHasContinuation && !isCommentOnlyLine) {
                // Line needs breaking (skip for very large files to improve performance)
                // Never break continuation lines - they're already part of a multi-line statement
                // Don't break lines if previous line has continuation (part of manual formatting)
                // Never break comment-only lines - they should be preserved as-is

                // Check if this is a manual continuation (ends with continuation semicolon)
                // A continuation semicolon is one at the end with no closing parenthesis after it
                boolean hasManualContinuation = false;
                String trimmed = processedLine.trim();
                if (trimmed.endsWith(";")) {
                    // Check if this might be a statement ending semicolon (inside parentheses)
                    // vs a continuation semicolon
                    int lastSemi = trimmed.lastIndexOf(';');
                    int lastParen = trimmed.lastIndexOf(')');
                    // If there's no closing paren after the semicolon, it's likely a continuation
                    if (lastParen < lastSemi) {
                        // Check if the line looks like it's incomplete
                        // Lines with .and., .or., opening parenthesis without close, etc.
                        int openParens = 0;
                        for (char c : trimmed.toCharArray()) {
                            if (c == '(') openParens++;
                            else if (c == ')') openParens--;
                        }
                        // If parentheses are balanced, it's probably not a continuation
                        hasManualContinuation = (openParens > 0);
                    }
                }

                if (!hasManualContinuation) {
                    // Debug logging for lines being broken
                    if (processedLine.contains("Miki Plastik") || processedLine.contains("open(") || processedLine.contains("region==DATA->Region")) {
                        log("BREAKING LINE: " + processedLine.substring(0, Math.min(50, processedLine.length())) + "...");
                        log("  - Length: " + processedLine.length() + ", Limit: " + lineBreakPosition);
                        log("  - shouldBreakLine: " + shouldBreakLine(processedLine));
                        log("  - Ends with semicolon: " + processedLine.trim().endsWith(";"));
                        log("  - Is continuation: " + isLineContinuation);
                        log("  - Prev has continuation: " + prevLineHasContinuation);
                    }

                    List<String> brokenLines = breakLine(processedLine, lineBreakPosition, indentSize);

                    for (int j = 0; j < brokenLines.size(); j++) {
                        result.append(brokenLines.get(j));
                        if (j < brokenLines.size() - 1) {
                            result.append("\n");
                        } else if (i < lines.length - 1) {
                            // Always add newline if not at end of file
                            result.append("\n");
                        }
                    }
                } else {
                    // Has manual continuation - keep the line as-is
                    if (processedLine.contains("Liste(")) {
                        log("Keeping line with manual continuation: " + processedLine.substring(0, Math.min(80, processedLine.length())));
                    }
                    result.append(processedLine);
                    if (i < lines.length - 1) {
                        result.append("\n");
                    }
                }  // Close the if (!hasManualContinuation) block
            } else {
                // Regular line, no breaking needed

                // Debug logging for problematic line
                if (processedLine.contains("Miki Plastik") || processedLine.contains("region==DATA->Region")) {
                    log("NOT BREAKING LINE: " + processedLine.substring(0, Math.min(50, processedLine.length())) + "...");
                    log("  - Length: " + processedLine.length() + ", Limit: " + lineBreakPosition);
                    if (processedLine.length() > lineBreakPosition) {
                        log("  - Line is longer than limit but not being broken!");
                        log("  - shouldBreakLine: " + shouldBreakLine(processedLine));
                        log("  - Ends with semicolon: " + processedLine.trim().endsWith(";"));
                        log("  - Is continuation: " + isLineContinuation);
                        log("  - Prev has continuation: " + prevLineHasContinuation);
                    }
                }

                result.append(processedLine);

                // Add newline if not at end of file
                if (i < lines.length - 1) {
                    result.append("\n");
                }
            }

            // Update indentation for next lines
            // Don't increase indent if this is a continuation line (part of previous statement)
            if (!isLineContinuation && (
                    lowerLine.startsWith("if ") ||
                    lowerLine.startsWith("while ") ||
                    lowerLine.startsWith("for ") ||
                    (lowerLine.startsWith("do ") && !isDoCaseStatement) || // DO but not DO CASE
                    isDoCaseStatement || // DO CASE starts a block
                    (lowerLine.startsWith("case ") && !inSwitchBlock && !inDoCaseBlock))) { // Don't increase indent for case in switch or DO CASE
                indentLevel++;
            }
            
            // Handle BEGIN SEQUENCE block indentation
            if (isBeginSequence || isRecoverUsing) {
                if (sequenceLikeNormalCode) {
                    // With checkbox: content inside gets extra indentation
                    indentLevel++;
                } else {
                    // Without checkbox: content inside gets NO extra indentation
                    // Don't change indentLevel
                }
            }
            
            // else does NOT increase indent (elseif is handled with if statements above)
            // elseif should also not increase indent separately since it's already handled

            // Increase indent after switch statement
            // Don't increase indent if this is a continuation line
            if (!isLineContinuation && isSwitchStatement) {
                indentLevel++;
            }

            // Function body indentation
            if (functionStartMatcher.matches() || isMethodImplementation) {
                // For function/method declarations, start with indent level 1 for the body
                indentLevel = 1;
                inFunctionBody = true;
                // Setting indent level to 1 for function/method body
            }
        }

        return result.toString();
    }

    /**
     * Break a long line into multiple lines with proper continuation
     */
    private List<String> breakLine(String line, int lineBreakPosition, int indentSize) {
        List<String> result = new ArrayList<>();

        // Find indentation
        int indentLength = 0;
        while (indentLength < line.length() && Character.isWhitespace(line.charAt(indentLength))) {
            indentLength++;
        }

        String indent = line.substring(0, indentLength);
        String content = line.substring(indentLength);

        // Debug empty content
        if (content.isEmpty()) {
            log("WARNING: breakLine called with empty content, line: '" + line + "'");
            result.add(line);
            return result;
        }

        // Check if this line already contains string continuation
        if (STRING_CONTINUATION_PATTERN.matcher(line).matches()) {
            // Not breaking line with existing string continuation
            result.add(line);
            return result;
        }

        // Check if this line already has a line continuation semicolon
        // If it does, don't break it further as it's already been manually formatted
        if (line.trim().endsWith(";")) {
            result.add(line);
            return result;
        }

        // Regular line breaking logic - handles all cases including strings
        return breakRegularLine(line, indent, content, lineBreakPosition, indentSize);
    }

    /**
     * Break a line containing a string assignment or string in general
     */
    private List<String> breakStringAssignment(String line, String indent, String content,
                                                int stringStart, int stringEnd, char stringDelim,
                                                int lineBreakPosition, int indentSize) {
        List<String> result = new ArrayList<>();

        // Extract the parts
        String beforeString = content.substring(0, stringStart);
        // Remove spaces around := in beforeString
        beforeString = beforeString.replaceAll("\\s*:=\\s*", ":=");
        String stringContent = content.substring(stringStart + 1, stringEnd);
        String afterString = content.substring(stringEnd + 1);

        // If the whole line fits, don't break but fix spaces around :=
        if (line.length() <= lineBreakPosition) {
            String fixedLine = line.replaceAll("\\s*:=\\s*", ":=");
            result.add(fixedLine);
            return result;
        }

        // Calculate maximum line length
        int maxLen = Math.min(99, lineBreakPosition);
        String continuationIndent = indent + " ".repeat(indentSize);

        // Break the string content into multiple lines
        List<String> stringParts = new ArrayList<>();
        String remaining = stringContent;
        boolean firstLine = true;

        while (remaining.length() > 0) {
            int availableLen;
            if (firstLine) {
                // First line: indent + beforeString + " + quotes + content + ";
                availableLen = maxLen - indent.length() - beforeString.length() - 3; // -3 for quotes and ";"
            } else {
                // Continuation lines: continuationIndent + " + content + ";
                availableLen = maxLen - continuationIndent.length() - 3; // -3 for quotes and ";"
            }

            if (availableLen <= 0) {
                // Can't fit anything, bail out
                return breakRegularLine(line, indent, content, lineBreakPosition, indentSize);
            }

            // Find break point
            int breakAt = Math.min(availableLen, remaining.length());

            // Try to break at comma for better readability
            if (breakAt < remaining.length()) {
                // Look for comma near the break point
                for (int i = breakAt; i > Math.max(0, breakAt - 30); i--) {
                    if (remaining.charAt(i) == ',') {
                        breakAt = i + 1; // Keep comma with previous part
                        break;
                    }
                }

                // If no comma, try space
                if (breakAt == Math.min(availableLen, remaining.length())) {
                    for (int i = breakAt; i > Math.max(0, breakAt - 20); i--) {
                        if (remaining.charAt(i) == ' ') {
                            breakAt = i + 1; // Keep space at end
                            break;
                        }
                    }
                }
            }

            stringParts.add(remaining.substring(0, breakAt));
            remaining = remaining.substring(breakAt);
            firstLine = false;
        }

        // Build the result lines
        for (int i = 0; i < stringParts.size(); i++) {
            String part = stringParts.get(i);
            if (i == 0) {
                // First line
                if (i == stringParts.size() - 1) {
                    // Only one part, no continuation
                    result.add(indent + beforeString + stringDelim + part + stringDelim + afterString);
                } else {
                    // More parts follow
                    result.add(indent + beforeString + stringDelim + part + stringDelim + "+;");
                }
            } else if (i == stringParts.size() - 1) {
                // Last line
                result.add(continuationIndent + stringDelim + part + stringDelim + afterString);
            } else {
                // Middle lines
                result.add(continuationIndent + stringDelim + part + stringDelim + "+;");
            }
        }

        return result;
    }

    /**
     * Break a line that starts with ? followed by a string
     */
    private List<String> breakStringLine(String line, String indent, String content,
                                         char stringDelim, int lineBreakPosition, int indentSize) {
        List<String> result = new ArrayList<>();

        // Find where the string actually starts and ends
        int stringStart = content.indexOf(stringDelim);
        if (stringStart == -1) {
            result.add(line);
            return result;
        }

        // Find the matching closing delimiter
        int stringEnd = -1;
        for (int i = stringStart + 1; i < content.length(); i++) {
            if (content.charAt(i) == stringDelim && (i == 0 || content.charAt(i-1) != '\\')) {
                stringEnd = i;
                break;
            }
        }

        if (stringEnd == -1) {
            // String doesn't close on this line - shouldn't happen but handle gracefully
            result.add(line);
            return result;
        }

        // Extract the parts
        String beforeString = content.substring(0, stringStart); // This includes the ?
        if (stringEnd <= stringStart) {
            log("ERROR: stringEnd (" + stringEnd + ") <= stringStart (" + stringStart + ") for content: " + content);
            result.add(line);
            return result;
        }
        String stringContent = content.substring(stringStart + 1, stringEnd); // Content without delimiters
        String afterString = content.substring(stringEnd + 1);

        // If the whole line fits, don't break
        if (line.length() <= lineBreakPosition) {
            result.add(line);
            return result;
        }

        // Calculate how much string content fits on first line
        int firstLineSpace = lineBreakPosition - indent.length() - beforeString.length() - 1 - 2; // -1 for opening quote, -2 for ';
        if (firstLineSpace <= 0) {
            // Can't fit anything, don't break
            result.add(line);
            return result;
        }

        // Break the string content
        if (firstLineSpace >= stringContent.length()) {
            // String fits on one line
            result.add(line);
        } else {
            // Need to break the string
            String firstPart = stringContent.substring(0, Math.min(firstLineSpace, stringContent.length()));
            String secondPart = stringContent.substring(firstPart.length());

            // First line: ? 'firstPart';
            result.add(indent + beforeString + stringDelim + firstPart + stringDelim + "+;");

            // Second line: 'secondPart'
            String continuationIndent = indent + " ".repeat(indentSize);
            result.add(continuationIndent + stringDelim + secondPart + stringDelim + afterString);
        }

        return result;
    }

    /**
     * Break a regular line following wrapping rules from CLAUDE.md
     */
    private List<String> breakRegularLine(String line, String indent, String content,
                                          int lineBreakPosition, int indentSize) {
        List<String> result = new ArrayList<>();

        // Debug logging for problematic cases
        if (content.startsWith(".or.") || content.startsWith(".and.")) {
            log("DEBUG: breakRegularLine called with content starting with logical operator");
            log("  content: '" + content + "'");
            log("  content length: " + content.length());
            log("  line: '" + line + "'");
            log("  line length: " + line.length());
        }

        // Special handling for "do while", "elseif", and "loca/locate for" constructs
        String trimmedLower = content.trim().toLowerCase();
        if (trimmedLower.startsWith("do while ")) {
            // For "do while" statements, try to keep as much on the first line as possible
            // Only break when we really need to
            if (line.length() <= lineBreakPosition) {
                // Fits on one line, don't break
                result.add(line);
                return result;
            }

            // Line is too long, but we want to find the best break point
            // Try to keep the first condition with "do while" if possible
            String afterDoWhile = content.substring(9); // Skip "do while "

            // Find the LAST logical operator that would still fit on the line
            int breakAfterLogical = -1;
            String contentLower = content.toLowerCase();
            String[] operators = {".and.", ".or."};

            // Look for all logical operators and find the last one that fits
            for (String op : operators) {
                int searchStart = 0;
                while (searchStart < content.length()) {
                    int pos = contentLower.indexOf(op, searchStart);
                    if (pos < 0) break;

                    int actualPos = pos + op.length(); // Position after operator in content
                    String firstPart = indent + content.substring(0, actualPos);

                    // Check if this break point would fit (with semicolon)
                    if (firstPart.length() + 1 <= lineBreakPosition) { // +1 for semicolon
                        // This fits, update our best break point
                        breakAfterLogical = actualPos;
                    }

                    searchStart = pos + op.length();
                }
            }

            if (breakAfterLogical > 0) {
                // Break after the logical operator
                String firstPart = content.substring(0, breakAfterLogical);
                String remaining = content.substring(breakAfterLogical).trim();

                // Add semicolon after the logical operator
                result.add(indent + firstPart + ";");

                // Add the continuation with proper indentation
                String continuationIndent = indent + " ".repeat(indentSize);

                // Check if remaining needs further breaking
                if (continuationIndent.length() + remaining.length() > lineBreakPosition) {
                    // Recursively break the remaining
                    List<String> subLines = breakRegularLine(
                        continuationIndent + remaining,
                        continuationIndent,
                        remaining,
                        lineBreakPosition,
                        indentSize
                    );
                    result.addAll(subLines);
                } else {
                    result.add(continuationIndent + remaining);
                }
                return result;
            }
            // If no good logical break point found, fall through to regular breaking
        } else if (trimmedLower.startsWith("if ") && !trimmedLower.startsWith("if(")) {
            // Special handling for if statements (but not if() function calls)
            // Prevent excessive breaking, keep logical expressions together
            if (line.length() <= lineBreakPosition) {
                // Fits on one line, don't break
                result.add(line);
                return result;
            }

            // Line is too long, find optimal break point at logical operators
            int breakAfterLogical = -1;
            String contentLower = content.toLowerCase();

            // Look for the first .or. or .and. that gives a reasonable line
            for (String op : new String[]{".or.", ".and."}) {
                int searchStart = 3; // Start after "if "
                while (searchStart < content.length()) {
                    int pos = contentLower.indexOf(op, searchStart);
                    if (pos < 0) break;

                    int actualPos = pos + op.length();
                    String firstPart = indent + content.substring(0, actualPos);

                    // Keep updating to find the last one that fits
                    if (firstPart.length() + 1 <= lineBreakPosition) {
                        breakAfterLogical = actualPos;
                    }

                    searchStart = pos + op.length();
                }
            }

            if (breakAfterLogical > 0) {
                // Break after the logical operator
                String firstPart = content.substring(0, breakAfterLogical);
                String remaining = content.substring(breakAfterLogical).trim();

                // Remove trailing spaces
                while (firstPart.endsWith(" ")) {
                    firstPart = firstPart.substring(0, firstPart.length() - 1);
                }

                // Add semicolon at the break point
                result.add(indent + firstPart + ";");

                // Add continuation with proper indentation
                String continuationIndent = indent + " ".repeat(indentSize);
                result.add(continuationIndent + remaining);
                return result;
            }
            // If no good logical break point found, fall through to regular breaking
        } else if (trimmedLower.startsWith("elseif ")) {
            // Special handling for elseif statements - prevent excessive breaking
            // Try to keep logical expressions together
            if (line.length() <= lineBreakPosition) {
                // Fits on one line, don't break
                result.add(line);
                return result;
            }

            // Line is too long. For elseif, we want to maximize content on first line
            // Find the best break point that keeps logical units together

            // First, try breaking at logical operators (.or., .and.)
            int bestBreak = -1;
            String contentLower = content.toLowerCase();

            // Look for the last .or. or .and. that would fit
            for (String op : new String[]{".or.", ".and."}) {
                int pos = 0;
                while (pos < content.length()) {
                    int found = contentLower.indexOf(op, pos);
                    if (found < 0) break;

                    int breakPos = found + op.length();
                    String testLine = indent + content.substring(0, breakPos);

                    if (testLine.length() + 1 <= lineBreakPosition) {
                        // This fits, update best break
                        bestBreak = breakPos;
                    }

                    pos = found + op.length();
                }
            }

            // If we can't break at a logical operator, or if we can fit more,
            // try breaking at spaces (but avoid breaking $ operator from its operands)
            if (bestBreak < 0 || bestBreak < content.length() - 20) {
                // Look for spaces as break points, working backwards from the limit
                int maxPos = lineBreakPosition - indent.length() - 1; // -1 for semicolon

                for (int i = Math.min(maxPos, content.length() - 1); i > 7; i--) {
                    if (content.charAt(i) == ' ') {
                        // Don't break right after $ operator
                        if (i > 0 && content.charAt(i-1) == '$') {
                            continue;
                        }
                        // Don't break right before $ operator
                        if (i < content.length() - 1 && content.charAt(i+1) == '$') {
                            continue;
                        }

                        // Check if this is after a logical operator
                        String before = content.substring(Math.max(0, i-4), i).toLowerCase();
                        if (before.endsWith(".or") || before.endsWith(".and")) {
                            // This is right after a logical operator, good break point
                            bestBreak = i;
                            break;
                        }

                        // Otherwise, this is a potential break point
                        if (bestBreak < 0) {
                            bestBreak = i;
                        }
                    }
                }
            }

            if (bestBreak > 0) {
                // Break at the found position
                String firstPart = content.substring(0, bestBreak);
                // Remove trailing spaces
                while (firstPart.endsWith(" ")) {
                    firstPart = firstPart.substring(0, firstPart.length() - 1);
                }
                String remaining = content.substring(bestBreak).trim();

                // Add semicolon at the break point
                result.add(indent + firstPart + ";");

                // Add the continuation with proper indentation
                String continuationIndent = indent + " ".repeat(indentSize);

                // For the remaining part, avoid excessive breaking
                // Only break if absolutely necessary
                if (continuationIndent.length() + remaining.length() > lineBreakPosition) {
                    // Try to find a good break point in the remaining part
                    // Look for logical operators
                    int nextBreak = -1;
                    String remainingLower = remaining.toLowerCase();

                    for (String op : new String[]{".or.", ".and."}) {
                        int pos = remainingLower.lastIndexOf(op);
                        if (pos > 0) {
                            String testLine = continuationIndent + remaining.substring(0, pos + op.length());
                            if (testLine.length() + 1 <= lineBreakPosition) {
                                nextBreak = pos + op.length();
                            }
                        }
                    }

                    if (nextBreak > 0) {
                        // Found a good break point
                        result.add(continuationIndent + remaining.substring(0, nextBreak) + ";");
                        result.add(continuationIndent + remaining.substring(nextBreak).trim());
                    } else {
                        // No good break point, keep as-is (might be too long but better than excessive breaks)
                        result.add(continuationIndent + remaining);
                    }
                } else {
                    result.add(continuationIndent + remaining);
                }
                return result;
            }
            // If no good logical break point found, fall through to regular breaking
        } else if (trimmedLower.startsWith("loca for ") || trimmedLower.startsWith("locate for ")) {
            // Special handling for locate/loca statements - keep "for" with the command
            if (line.length() <= lineBreakPosition) {
                // Fits on one line, don't break
                result.add(line);
                return result;
            }

            // Line is too long, but we want to keep "loca for" or "locate for" together
            // Find a good break point after logical operators
            int commandEnd = trimmedLower.startsWith("loca for ") ? 9 : 11; // Length of "loca for " or "locate for "

            // Look for the first .and. as a preferred break point
            int breakAfterLogical = -1;
            String contentLower = content.toLowerCase();
            int firstAndPos = contentLower.indexOf(".and.", commandEnd);

            if (firstAndPos > 0) {
                int breakPos = firstAndPos + 5; // After ".and."
                String testLine = indent + content.substring(0, breakPos);

                // If first .and. gives us a reasonable line length (at least 35 chars), use it
                if (testLine.length() >= 35 && testLine.length() + 1 <= lineBreakPosition) {
                    breakAfterLogical = breakPos;
                }
            }

            // If no good .and. break, look for .or.
            if (breakAfterLogical < 0) {
                int firstOrPos = contentLower.indexOf(".or.", commandEnd);
                if (firstOrPos > 0) {
                    int breakPos = firstOrPos + 4; // After ".or."
                    String testLine = indent + content.substring(0, breakPos);

                    if (testLine.length() >= 35 && testLine.length() + 1 <= lineBreakPosition) {
                        breakAfterLogical = breakPos;
                    }
                }
            }

            if (breakAfterLogical > 0) {
                // Break after the logical operator
                String firstPart = content.substring(0, breakAfterLogical);
                String remaining = content.substring(breakAfterLogical).trim();

                // Remove trailing spaces from first part
                while (firstPart.endsWith(" ")) {
                    firstPart = firstPart.substring(0, firstPart.length() - 1);
                }

                // Add semicolon at the break point
                result.add(indent + firstPart + ";");

                // Add continuation with proper indentation
                String continuationIndent = indent + " ".repeat(indentSize);
                result.add(continuationIndent + remaining);
                return result;
            }
            // If no good break point found, fall through to regular breaking
        } else if (trimmedLower.startsWith("index ") || trimmedLower.startsWith("index on ")) {
            // Special handling for index statements
            // Keep "index on ... tag ... for" structure together
            if (line.length() <= lineBreakPosition) {
                // Fits on one line, don't break
                result.add(line);
                return result;
            }

            // Line is too long. Find the "for" keyword which marks the condition start
            String contentLower = content.toLowerCase();
            int forPos = contentLower.indexOf(" for ");
            if (forPos > 0) {
                // Check if we can fit everything up to and including "for" on one line
                String upToFor = content.substring(0, forPos + 5); // Include " for "
                String afterFor = content.substring(forPos + 5).trim();

                // If the first part with "for ;" fits, break there
                if ((indent + upToFor).length() + 1 <= lineBreakPosition) {
                    // Add the index declaration part with semicolon
                    result.add(indent + upToFor + ";");

                    // Process the condition part
                    String continuationIndent = indent + " ".repeat(indentSize);

                    // Look for logical operators in the condition to break if needed
                    if (continuationIndent.length() + afterFor.length() > lineBreakPosition) {
                        // Need to break the condition too
                        // Find a good break point at .or. or .and.
                        int condBreak = -1;
                        String afterForLower = afterFor.toLowerCase();

                        // Find the last .or. or .and. that fits
                        for (String op : new String[]{".or.", ".and."}) {
                            int pos = 0;
                            while (pos < afterFor.length()) {
                                int found = afterForLower.indexOf(op, pos);
                                if (found < 0) break;

                                int breakPos = found + op.length();
                                String testLine = continuationIndent + afterFor.substring(0, breakPos);

                                if (testLine.length() + 1 <= lineBreakPosition) {
                                    condBreak = breakPos;
                                }

                                pos = found + op.length();
                            }
                        }

                        if (condBreak > 0) {
                            // Break the condition
                            String firstCondPart = afterFor.substring(0, condBreak);
                            String secondCondPart = afterFor.substring(condBreak).trim();

                            result.add(continuationIndent + firstCondPart + ";");
                            result.add(continuationIndent + secondCondPart);
                        } else {
                            // No good break point in condition, keep as-is
                            result.add(continuationIndent + afterFor);
                        }
                    } else {
                        // Condition fits on one line
                        result.add(continuationIndent + afterFor);
                    }

                    return result;
                }
            }
            // If no "for" keyword or can't fit the structure, fall through to regular breaking
        }

        // If the line fits, don't break it
        if (line.length() <= lineBreakPosition) {
            result.add(line);
            return result;
        }

        // Check if this is a string assignment (variable:="string content" or variable := "string")
        int assignPos = content.indexOf(":=");
        if (assignPos > 0) {
            // Find the first non-space character after :=
            int pos = assignPos + 2;
            while (pos < content.length() && content.charAt(pos) == ' ') {
                pos++;
            }

            if (pos < content.length()) {
                char afterAssign = content.charAt(pos);
                log("Checking for string assignment: assignPos=" + assignPos +
                    ", pos=" + pos + ", char='" + afterAssign + "'");
                if (afterAssign == '"' || afterAssign == '\'') {
                    // This is a string assignment, handle it specially
                    int stringStart = pos;  // Use the position after skipping spaces
                    int stringEnd = -1;
                    char outerQuote = afterAssign;
                    char innerQuote = (outerQuote == '"') ? '\'' : '"';
                    boolean hasNestedQuotes = false;

                    log("String assignment detected, stringStart=" + stringStart +
                        ", content from start: " + content.substring(stringStart,
                        Math.min(stringStart + 20, content.length())));

                    // First, scan the string to check for nested quotes
                    for (int i = stringStart + 1; i < content.length(); i++) {
                        char c = content.charAt(i);

                        // Check for nested quote
                        if (c == innerQuote && (i == 0 || content.charAt(i - 1) != '\\')) {
                            hasNestedQuotes = true;
                            log("Found nested quote at position " + i + ", will not wrap this string");
                        }

                        // Check for closing outer quote
                        if (c == outerQuote && (i == 0 || content.charAt(i - 1) != '\\')) {
                            stringEnd = i;
                            break;
                        }
                    }

                    if (stringEnd > stringStart) {
                        // If string has nested quotes, don't wrap it at all
                        if (hasNestedQuotes) {
                            log("String has nested quotes, not wrapping");
                            result.add(line);
                            return result;
                        }

                        log("Found string end at " + stringEnd + ", calling breakStringAssignment");
                        return breakStringAssignment(line, indent, content, stringStart,
                            stringEnd, afterAssign, lineBreakPosition, indentSize);
                    }
                    // If no valid string end found, fall through to regular processing
                    log("No valid string end found, falling through to regular processing");
                }
            }
        }

        // Track string state
        boolean inString = false;
        char stringDelim = 0;
        int stringStart = -1;

        // Calculate maximum position for break (accounting for semicolon)
        int maxLen = Math.min(99, lineBreakPosition);
        int maxPos = maxLen - indent.length() - 1; // -1 for potential semicolon

        // Find best break point
        int bestBreakPos = -1;
        int lastSpace = -1;
        int lastComma = -1;
        int lastOperator = -1;
        int lastLogical = -1;
        boolean preferLogicalBreak = false;

        for (int i = 0; i < content.length() && i <= maxPos; i++) {
            char c = content.charAt(i);

            // Track string state
            if ((c == '"' || c == '\'') && (i == 0 || content.charAt(i - 1) != '\\')) {
                if (!inString) {
                    inString = true;
                    stringDelim = c;
                    stringStart = i;
                } else if (c == stringDelim) {
                    inString = false;
                }
            }

            // Only look for break points outside strings
            if (!inString) {
                // Check for assignment operator - NEVER break between variable and :=
                if (c == ':' && i + 1 < content.length() && content.charAt(i + 1) == '=') {
                    // Skip past the assignment operator
                    continue;
                }

                // Look for logical operators (.and., .or.)
                String portion = content.substring(i).toLowerCase();
                if (portion.startsWith(".and.") || portion.startsWith(".or.")) {
                    // Break AFTER the logical operator
                    int operatorEnd = i + (portion.startsWith(".and.") ? 5 : 4);

                    // Check what comes after the operator
                    // Skip whitespace to see what follows
                    int checkPos = operatorEnd;
                    while (checkPos < content.length() && content.charAt(checkPos) == ' ') {
                        checkPos++;
                    }

                    // If a parenthesis follows, we STRONGLY prefer to break here
                    // This ensures .or.; on one line and (expression) on the next
                    if (checkPos < content.length() && content.charAt(checkPos) == '(') {
                        // Break right after the operator (before any spaces)
                        if (operatorEnd <= maxPos) {
                            lastLogical = operatorEnd;
                            preferLogicalBreak = true; // Mark that we prefer this break
                            log("Found logical operator before parenthesis at " + i + ", strongly prefer break after operator at " + operatorEnd);
                        }
                    } else if (operatorEnd <= maxPos) {
                        // Normal case - break after the operator
                        lastLogical = operatorEnd;
                        log("Found logical operator at " + i + ", can break after at position " + operatorEnd);
                    }
                }

                // Track other break points (but don't immediately use them if we have a preferred logical break)
                if (c == ',' && i < maxPos) {
                    lastComma = i + 1;
                    if (!preferLogicalBreak) {
                        bestBreakPos = lastComma;
                    }
                } else if (c == ' ' && i > 0 && i < maxPos) {
                    // Don't break right after := or ( or :
                    if (i >= 2 && content.substring(i-2, i).equals(":=")) {
                        continue;
                    }
                    if (content.charAt(i-1) == '(' || content.charAt(i-1) == ':') {
                        continue;
                    }

                    // Don't break between "do" and "while" or right after "do while"
                    if (i >= 2) {
                        String beforeSpace = content.substring(Math.max(0, i-2), i).toLowerCase();
                        if (beforeSpace.equals("do") && i + 5 <= content.length()) {
                            String afterSpace = content.substring(i+1, Math.min(i+6, content.length())).toLowerCase();
                            if (afterSpace.equals("while") || afterSpace.startsWith("while")) {
                                continue; // Don't break between do and while
                            }
                        }
                    }

                    // Don't break between "loca" and "for" or "locate" and "for"
                    if (i >= 4) {
                        String beforeSpace = content.substring(Math.max(0, i-4), i).toLowerCase();
                        if (beforeSpace.equals("loca") && i + 3 <= content.length()) {
                            String afterSpace = content.substring(i+1, Math.min(i+4, content.length())).toLowerCase();
                            if (afterSpace.equals("for") || afterSpace.startsWith("for")) {
                                continue; // Don't break between loca and for
                            }
                        }
                    }
                    if (i >= 6) {
                        String beforeSpace = content.substring(Math.max(0, i-6), i).toLowerCase();
                        if (beforeSpace.equals("locate") && i + 3 <= content.length()) {
                            String afterSpace = content.substring(i+1, Math.min(i+4, content.length())).toLowerCase();
                            if (afterSpace.equals("for") || afterSpace.startsWith("for")) {
                                continue; // Don't break between locate and for
                            }
                        }
                    }

                    // Also don't break right after "while" if it's part of "do while"
                    if (i >= 5) {
                        String beforeSpace = content.substring(Math.max(0, i-5), i).toLowerCase();
                        if (beforeSpace.equals("while") || beforeSpace.endsWith(" while")) {
                            // Check if this is a "do while" by looking further back
                            String checkDoWhile = content.substring(0, i).toLowerCase().trim();
                            if (checkDoWhile.equals("do while") || checkDoWhile.endsWith(" do while")) {
                                continue; // Don't break right after "do while"
                            }
                        }
                    }

                    lastSpace = i + 1;
                    if (bestBreakPos < 0 && !preferLogicalBreak) {
                        bestBreakPos = lastSpace;
                    }
                } else if ((c == '+' || c == '-') && !inString && i < maxPos) {
                    // Can break after + or - operators
                    lastOperator = i + 1;
                }
            }
        }

        // If we found a preferred logical break point (before parenthesis), use it
        if (preferLogicalBreak && lastLogical > 0) {
            bestBreakPos = lastLogical;
            log("Using preferred logical operator break at " + lastLogical);
        } else if (lastLogical > 0 && bestBreakPos < 0) {
            // Use logical operator break if we have no other break point
            bestBreakPos = lastLogical;
            log("Using logical operator break as fallback at " + lastLogical);
        }

        // If we're in a string at max position, we need to break the string
        if (inString && stringStart >= 0) {
            String beforeString = content.substring(0, stringStart);

            // First check if the string has nested quotes - if so, don't wrap
            char innerQuote = (stringDelim == '"') ? '\'' : '"';
            boolean hasNestedQuotes = false;

            // Scan for nested quotes
            for (int i = stringStart + 1; i < content.length(); i++) {
                char c = content.charAt(i);
                if (c == innerQuote && (i == 0 || content.charAt(i - 1) != '\\')) {
                    hasNestedQuotes = true;
                    log("Found nested quote in string, will not wrap");
                    break;
                }
                if (c == stringDelim && (i == 0 || content.charAt(i - 1) != '\\')) {
                    break; // Found string end
                }
            }

            if (hasNestedQuotes) {
                // Don't wrap strings with nested quotes
                result.add(line);
                return result;
            }

            // Find the closing quote
            int stringEnd = -1;
            for (int i = stringStart + 1; i < content.length(); i++) {
                if (content.charAt(i) == stringDelim && (i == 0 || content.charAt(i - 1) != '\\')) {
                    stringEnd = i;
                    break;
                }
            }

            if (stringEnd > 0) {
                String stringContent = content.substring(stringStart + 1, stringEnd);
                String afterString = content.substring(stringEnd + 1);

                // Calculate how much fits on first line
                int availableForString = maxPos - stringStart - 2; // -2 for quotes

                if (availableForString > 10 && availableForString < stringContent.length()) {
                    // Break the string at a space if possible
                    int stringBreakPos = availableForString;
                    boolean breakAtSpace = false;
                    for (int i = stringBreakPos; i > stringBreakPos - 20 && i > 0; i--) {
                        if (stringContent.charAt(i) == ' ') {
                            stringBreakPos = i + 1; // Break AFTER the space to keep it
                            breakAtSpace = true;
                            break;
                        }
                    }

                    // First line with partial string
                    String firstPart = stringContent.substring(0, stringBreakPos);
                    result.add(indent + beforeString + stringDelim + firstPart + stringDelim + "+;");

                    // Second line with rest of string
                    String remaining = stringContent.substring(stringBreakPos);
                    String continuationIndent = indent + " ".repeat(indentSize);
                    result.add(continuationIndent + stringDelim + remaining + stringDelim + afterString);

                    return result;
                }
            }
        }

        // Use best break point found
        if (bestBreakPos <= 0) {
            // No good break point found - try operator or last resort
            if (lastOperator > 0 && lastOperator <= maxPos) {
                bestBreakPos = lastOperator;
            } else {
                // Last resort - break at max position
                bestBreakPos = maxPos;
            }
        }

        // Never break in the middle of or right before := operator
        if (bestBreakPos > 0) {
            // Check if we're breaking in the middle of :=
            if (content.charAt(bestBreakPos - 1) == ':' &&
                bestBreakPos < content.length() && content.charAt(bestBreakPos) == '=') {
                // Move break point after the =
                bestBreakPos = Math.min(bestBreakPos + 1, maxPos);
            }
            // Check if we're breaking right before :=
            else if (bestBreakPos < content.length() - 1 &&
                     content.charAt(bestBreakPos) == ':' &&
                     content.charAt(bestBreakPos + 1) == '=') {
                // This would separate variable from :=, don't allow it
                // Find a better break point before the variable name
                int varStart = bestBreakPos;
                while (varStart > 0 && Character.isJavaIdentifierPart(content.charAt(varStart - 1))) {
                    varStart--;
                }
                if (varStart > 0) {
                    bestBreakPos = varStart;
                } else {
                    // Can't break before variable, must break after :=
                    bestBreakPos = Math.min(bestBreakPos + 2, content.length());
                }
            }
        }

        // Create first line
        String firstPart;
        try {
            if (bestBreakPos < 0 || bestBreakPos > content.length()) {
                log("ERROR: Invalid bestBreakPos " + bestBreakPos + " for content length " + content.length());
                log("  Content: '" + content + "'");
                result.add(line);
                return result;
            }
            firstPart = content.substring(0, bestBreakPos);
        } catch (Exception e) {
            log("ERROR in substring(0, " + bestBreakPos + ") for content: '" + content + "'");
            log("  Exception: " + e.getMessage());
            result.add(line);
            return result;
        }

        // Remove trailing spaces from first part
        while (firstPart.endsWith(" ")) {
            firstPart = firstPart.substring(0, firstPart.length() - 1);
        }

        // Check if needs semicolon
        boolean needsSemicolon = bestBreakPos < content.length();

        // Don't add semicolon ONLY if the line is JUST a control keyword by itself
        // (not when it's a control structure with a condition that's being broken)
        String firstLower = firstPart.trim().toLowerCase();
        if (firstLower.equals("if") || firstLower.equals("else") ||
            firstLower.equals("elseif") || firstLower.equals("do") ||
            firstLower.equals("while") || firstLower.equals("for") ||
            firstLower.equals("switch") || firstLower.equals("case") ||
            firstLower.equals("otherwise")) {
            // Only the keyword alone - don't add semicolon
            needsSemicolon = false;
        }

        // Always add semicolon when breaking after logical operators in conditions
        if (bestBreakPos < content.length() && lastLogical > 0 && bestBreakPos == lastLogical) {
            needsSemicolon = true;
            log("Breaking after logical operator - will add semicolon");
        }

        // Add first line
        if (needsSemicolon) {
            result.add(indent + firstPart + ";");
        } else {
            result.add(indent + firstPart);
        }

        // Process remaining content
        if (bestBreakPos < content.length()) {
            String remaining = content.substring(bestBreakPos);

            // Remove leading spaces from continuation
            while (remaining.startsWith(" ")) {
                remaining = remaining.substring(1);
            }

            String continuationIndent = indent + " ".repeat(indentSize);

            // Check if the remaining line is still too long
            if (continuationIndent.length() + remaining.length() > maxLen) {
                // Recursively break the remaining content
                List<String> subLines = breakRegularLine(
                    continuationIndent + remaining,
                    continuationIndent,
                    remaining,
                    lineBreakPosition,
                    indentSize
                );
                result.addAll(subLines);
            } else {
                result.add(continuationIndent + remaining);
            }
        }

        return result;
    }

    /**
     * Determine if a line should be broken
     * Only prevent breaking simple constructs; allow breaking complex long statements
     */
    private boolean shouldBreakLine(String line) {
        String trimmed = line.trim();
        
        // Don't break comment lines (single-line or block comments)
        if (trimmed.startsWith("//") || trimmed.startsWith("/*") || trimmed.startsWith("*") || trimmed.endsWith("*/")) {
            return false; // Don't break comment lines
        }
        
        // Allow breaking text/string output lines if they're too long
        // The line breaking logic will handle string continuations properly
        
        // Don't break lines that are primarily string literals
        // Pattern: lines that start with a string literal or are assignment to string literals
        if (trimmed.matches("^[\"'].*[\"'].*$") || 
            trimmed.matches(".*:=\\s*[\"'].*[\"'].*$")) {
            // Check if it's primarily a string (not code with a string in it)
            // Count quotes - if there are only 2 quotes, it's likely a single string
            int quoteCount = 0;
            for (char c : trimmed.toCharArray()) {
                if (c == '"' || c == '\'') {
                    quoteCount++;
                }
            }
            // If there are 2 quotes or less, it's likely a single string - don't break
            if (quoteCount <= 2) {
                return false;
            }
        }
        
        // Allow breaking lines with comments - the findBreakPoint method will handle breaking before the comment
        
        // Don't break simple GET ... WHEN constructs (only very basic ones)
        if (SIMPLE_GET_WHEN_PATTERN.matcher(trimmed).matches()) {
            return false;
        }
        
        // Don't break simple SAY ... GET constructs 
        if (SIMPLE_SAY_GET_PATTERN.matcher(trimmed).matches()) {
            return false;
        }
        
        // Note: Removed array/block restrictions - user wants long lines to break
        // The issue was incorrect semicolon placement, not that they shouldn't break
        
        // Allow breaking complex long lines (including complex GET statements)
        return true;
    }
    
    /**
     * Determine if a continuation semicolon should be added
     */
    private boolean shouldAddContinuationSemicolon(String segment, String fullContent, int currentPos, int breakPos) {
        String trimmedSegment = segment.trim();
        String trimmedLower = trimmedSegment.toLowerCase();

        // Debug logging
        if (segment.contains("open(") || segment.contains("BesAus")) {
            log("shouldAddContinuationSemicolon for: " + trimmedSegment);
        }

        // Don't add semicolon after control structure keywords
        if (trimmedLower.startsWith("if ") || trimmedLower.equals("if") ||
            trimmedLower.startsWith("else") || trimmedLower.equals("else") ||
            trimmedLower.startsWith("elseif ") ||
            trimmedLower.startsWith("for ") ||
            trimmedLower.startsWith("while ") ||
            trimmedLower.startsWith("do ") ||
            trimmedLower.startsWith("case ") ||
            trimmedLower.equals("otherwise") ||
            trimmedLower.startsWith("switch ") ||
            trimmedLower.startsWith("class ") ||
            trimmedLower.startsWith("method ") ||
            trimmedLower.startsWith("function ") ||
            trimmedLower.startsWith("procedure ") ||
            trimmedLower.startsWith("begin ") ||
            trimmedLower.startsWith("recover ")) {
            return false;
        }

        // Don't add semicolon if segment already ends with one or ends with comment
        if (trimmedSegment.endsWith(";") || trimmedSegment.endsWith("//")) {
            if (segment.contains("open(") || segment.contains("BesAus")) {
                log("  -> NO: already ends with ; or //");
            }
            return false;
        }

        // Check what comes after the break point
        String contextAfter = fullContent.substring(breakPos).trim();

        // Don't add semicolon if the next line is 'else', 'elseif', or 'endif'
        // This prevents breaking if-else-endif structures
        String contextAfterLower = contextAfter.toLowerCase();
        if (contextAfterLower.startsWith("else") ||
            contextAfterLower.startsWith("elseif") ||
            contextAfterLower.startsWith("endif")) {
            return false;
        }

        // Don't add semicolon if next content starts with comment
        if (contextAfter.startsWith("//") || contextAfter.startsWith("/*")) {
            return false;
        }

        // NOTE: When next content starts with logical operators (.and., .or., .not.),
        // we SHOULD add a semicolon - these are common continuation patterns in Harbour

        // Don't add semicolon if we're breaking inside array/block syntax
        String contextBefore = fullContent.substring(0, currentPos);

        // Count braces to see if we're inside an array literal
        int braceCount = 0;
        boolean inString = false;
        char stringDelim = 0;

        for (char c : contextBefore.toCharArray()) {
            if (!inString && (c == '"' || c == '\'')) {
                inString = true;
                stringDelim = c;
            } else if (inString && c == stringDelim) {
                inString = false;
            } else if (!inString) {
                if (c == '{') braceCount++;
                else if (c == '}') braceCount--;
            }
        }

        // If we're inside braces (array literal), don't add semicolon
        if (braceCount > 0) {
            return false;
        }

        // Check if this looks like an array assignment
        if (contextBefore.contains(":=") && (contextBefore.contains("{") || contextAfter.contains("}"))) {
            return false;
        }

        // Default: add semicolon for normal line continuation
        if (segment.contains("open(") || segment.contains("BesAus")) {
            log("  -> YES: adding semicolon for continuation");
        }
        return true;
    }

    /**
     * Find a good break point, avoiding splitting Harbour keywords
     */
    private int findBreakPoint(String content, int startPos, int endPos) {
        if (endPos >= content.length()) return content.length();

        // Check if line contains // comment - if so, don't break after it
        int commentStart = content.indexOf("//", startPos);
        if (commentStart >= 0 && commentStart < endPos) {
            // Line has comment, only break before the comment
            endPos = Math.min(endPos, commentStart);
            if (endPos <= startPos) {
                // Can't break before comment, don't break line at all
                return content.length();
            }
        }

        // First pass: Look for logical operators to break AFTER them
        // This puts the operator at the end of the line with semicolon
        // The continuation starts with the next logical expression
        String lowerContent = content.toLowerCase();

        // Try to find the best break point around logical operators
        // Prefer breaking after operators that have substantial content following
        int bestBreakPoint = -1;

        for (String op : new String[]{".and.", ".or."}) {
            int opPos = lowerContent.indexOf(op, startPos);
            while (opPos >= 0 && opPos < endPos) {
                int opEnd = opPos + op.length();

                // Skip any spaces after the operator
                while (opEnd < content.length() && content.charAt(opEnd) == ' ') {
                    opEnd++;
                }

                // Check what follows after the operator
                String remaining = content.substring(opEnd).trim();

                // If what remains is short (like "! stop"), prefer to keep it together
                // Break BEFORE the operator so everything stays on the next line
                if (remaining.length() <= 10 && opPos > startPos) {
                    // Break before the operator to keep the short expression together
                    if (content.charAt(opPos - 1) == ' ') {
                        bestBreakPoint = opPos;
                    }
                } else if (opEnd <= endPos) {
                    // Otherwise break after the operator
                    bestBreakPoint = opEnd;
                }

                if (bestBreakPoint > 0 && bestBreakPoint <= endPos) {
                    return bestBreakPoint;
                }

                // Look for next occurrence
                opPos = lowerContent.indexOf(op, opPos + op.length());
            }
        }

        // Second pass: Look for good break points, starting from the end and working backwards
        for (int i = endPos; i > startPos; i--) {
            char c = content.charAt(i);

            // Don't break arrow operator
            if (i > 0 && content.charAt(i-1) == '-' && c == '>') continue;
            if (i < content.length()-1 && c == '-' && content.charAt(i+1) == '>') continue;

            // Check if we're inside or at the boundary of any Harbour keyword
            if (isWithinHarbourKeyword(content, i)) {
                continue; // Skip this position if it would break a keyword
            }

            // Good break points (in order of preference)
            if (c == ' ') return i + 1;        // Prefer spaces
            if (c == ',') return i + 1;        // Then commas
            if (c == '+') return i + 1;        // Then plus operators
            if (c == ';') return i + 1;        // Then semicolons
            if (c == ')') return i + 1;        // Then closing parentheses
            if (c == '.' && !isWithinHarbourKeyword(content, i)) return i + 1; // Dots only if not in keywords
        }

        // No good break point found - return endPos to force breaking at the limit
        // This avoids character-by-character breaking for strings with no natural break points
        return endPos;
    }
    
    /**
     * Check if a position is within a Harbour keyword that should not be split
     */
    private boolean isWithinHarbourKeyword(String content, int position) {
        String lowerContent = content.toLowerCase();
        
        // Check dotted keywords (.and., .or., etc.)
        for (String keyword : HARBOUR_KEYWORDS) {
            if (isPositionWithinKeyword(lowerContent, position, keyword)) {
                return true;
            }
        }
        
        // Check word keywords (when, valid, etc.) - must be whole words
        for (String keyword : HARBOUR_WORD_KEYWORDS) {
            if (isPositionWithinWordKeyword(content, position, keyword)) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * Check if position is within a dotted keyword
     */
    private boolean isPositionWithinKeyword(String lowerContent, int position, String keyword) {
        for (int startIdx = Math.max(0, position - keyword.length() + 1); 
             startIdx <= Math.min(position, lowerContent.length() - keyword.length()); 
             startIdx++) {
            
            int endIdx = startIdx + keyword.length();
            if (endIdx <= lowerContent.length()) {
                String substring = lowerContent.substring(startIdx, endIdx);
                if (substring.equals(keyword)) {
                    if (position >= startIdx && position < endIdx) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    /**
     * Check if position is within a word keyword (must be whole word)
     */
    private boolean isPositionWithinWordKeyword(String content, int position, String keyword) {
        String lowerContent = content.toLowerCase();
        
        for (int startIdx = Math.max(0, position - keyword.length() + 1); 
             startIdx <= Math.min(position, content.length() - keyword.length()); 
             startIdx++) {
            
            int endIdx = startIdx + keyword.length();
            if (endIdx <= content.length()) {
                String substring = lowerContent.substring(startIdx, endIdx);
                if (substring.equals(keyword)) {
                    // Check word boundaries
                    boolean validStart = (startIdx == 0 || !Character.isLetterOrDigit(content.charAt(startIdx - 1)));
                    boolean validEnd = (endIdx >= content.length() || !Character.isLetterOrDigit(content.charAt(endIdx)));
                    
                    if (validStart && validEnd && position >= startIdx && position < endIdx) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /**
     * Get the last non-empty line from the formatted text
     */
    private String getLastNonEmptyLine(String text) {
        if (text == null || text.isEmpty()) {
            return null;
        }
        
        String[] lines = text.split("\n", -1);
        for (int i = lines.length - 1; i >= 0; i--) {
            String line = lines[i].trim();
            if (!line.isEmpty()) {
                return lines[i]; // Return with original whitespace
            }
        }
        return null;
    }

    /**
     * Log a message via the common HarbourLogger
     */
    private void log(String message) {
        HarbourLogger.log("PostFormatter", message);
    }
}
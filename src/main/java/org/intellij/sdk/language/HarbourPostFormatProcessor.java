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

    // New patterns for switch/case statements
    private static final Pattern SWITCH_PATTERN =
            Pattern.compile("^\\s*SWITCH\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern CASE_PATTERN =
            Pattern.compile("^\\s*CASE\\s+.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern ENDSWITCH_PATTERN =
            Pattern.compile("^\\s*ENDSWITCH.*$", Pattern.CASE_INSENSITIVE);
    private static final Pattern LINE_CONTINUATION_PATTERN =
            Pattern.compile(".*;\\s*$");

    // Pattern for detecting comment-only lines
    private static final Pattern COMMENT_LINE_PATTERN =
            Pattern.compile("^\\s*(?://.*|/\\*.*|.*\\*/\\s*|\\*.*?)$");
    
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
            String originalText = document.getText();
            log("Original document length: " + originalText.length());

            // Preserve exact original trailing whitespace - store it separately
            String originalTrailingWhitespace = extractTrailingWhitespace(originalText);
            log("Original trailing whitespace: '" + originalTrailingWhitespace.replace("\n", "\\n") + "'");

            // Process step by step
            String formattedText = formatHarbourCode(originalText, lineBreakPosition, harbourCodeStyleSettings);

            // Make sure to restore exact original trailing whitespace
            formattedText = ensureTrailingWhitespace(formattedText, originalTrailingWhitespace);
            log("Restored original trailing whitespace");

            if (!originalText.equals(formattedText)) {
                log("Text changed after formatting, applying changes");
                final String textToApply = formattedText;
                ApplicationManager.getApplication().runWriteAction(() -> {
                    try {
                        document.setText(textToApply);
                        documentManager.commitDocument(document);
                        log("Successfully applied text changes");
                    } catch (Exception e) {
                        log("Error applying text changes: " + e.getMessage());
                    }
                });
            } else {
                log("No text changes needed after formatting");
            }
        } catch (Exception e) {
            log("Exception during formatting: " + e.getMessage());
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
        boolean inClassDefinition = false;
        int indentSize = 2; // Default indentation size for Harbour
        
        // Get custom indentation settings
        int localIndent = settings.LOCAL_INDENT;
        int returnIndent = settings.RETURN_INDENT;
        int dataIndent = settings.DATA_INDENT;
        int methodIndent = settings.METHOD_INDENT;
        boolean sequenceLikeNormalCode = settings.SEQUENCE_LIKE_NORMAL_CODE;

        // Removed verbose logging for performance

        // Lines to skip (continuation lines)
        List<Integer> skipLines = new ArrayList<>();
        // Lines that are continuations of previous lines
        List<Integer> continuationLines = new ArrayList<>();

        // First pass - identify continuation lines
        for (int i = 0; i < lines.length - 1; i++) {
            String line = lines[i].trim();
            String nextLine = lines[i+1].trim();

            // String continuation pattern
            if (STRING_CONTINUATION_PATTERN.matcher(line).matches() &&
                    STRING_START_PATTERN.matcher(nextLine).matches()) {
                skipLines.add(i+1); // Skip the next line
            }

            // Regular line continuation with semicolon
            if (LINE_CONTINUATION_PATTERN.matcher(line).matches() && !nextLine.isEmpty()) {
                continuationLines.add(i+1); // Mark the next line as a continuation
            }
        }

        // Store previous line's *actual* indentation for comment alignment
        String previousLineActualIndent = "";

        // Main processing loop
        for (int i = 0; i < lines.length; i++) {
            // Skip lines that are part of continuation pairs
            if (skipLines.contains(i)) {
                continue;
            }

            String lineWithWhitespace = lines[i];
            String line = lineWithWhitespace.trim();

            // Skip empty lines
            if (line.isEmpty()) {
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

            // Check for case statement
            boolean isCaseStatement = CASE_PATTERN.matcher(line).matches();

            // Check for endswitch statement
            boolean isEndSwitchStatement = ENDSWITCH_PATTERN.matcher(line).matches();
            if (isEndSwitchStatement) {
                // Found endswitch statement
                inSwitchBlock = false;
            }

            // Detect RETURN statements - all will use normal indentation now
            boolean isReturnStatement = FUNCTION_END_PATTERN.matcher(line).matches();

            // Check for statement types
            boolean isLocalDeclaration = LOCAL_DECLARATION_PATTERN.matcher(line).matches();
            boolean isDataDeclaration = DATA_DECLARATION_PATTERN.matcher(line).matches();
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

            // Adjust indentation for case statements in switch blocks and content inside them
            if (isCaseStatement && inSwitchBlock) {
                // Handling case statement in switch block
                // Case statements are at the same level as switch
                effectiveIndentLevel = indentLevel - 1;
            } else if (inSwitchBlock && !isEndSwitchStatement) {
                // For content inside case blocks, use switch level + 1
                // This gives one level of indentation instead of two
                effectiveIndentLevel = Math.min(effectiveIndentLevel, (indentLevel - 1) + 1);
            }

            // Check for else/elseif statements that need special handling
            boolean isElseStatement = lowerLine.equals("else") || lowerLine.startsWith("elseif");
            
            // Reduce indentation for block endings
            if (isBlockEnd) {
                if (indentLevel > 0) indentLevel--;
            }
            
            // Handle else/elseif indentation - they should be at the same level as their corresponding if
            if (isElseStatement) {
                // Temporarily decrease effectiveIndentLevel for this line only
                if (effectiveIndentLevel > 0) effectiveIndentLevel--;
            }

            // Check if this line is a continuation of previous line
            boolean isLineContinuation = continuationLines.contains(i);

            // Handle comment-only lines - use previous line's indentation
            boolean isCommentOnlyLine = COMMENT_LINE_PATTERN.matcher(line).matches();
            String newIndent;

            if (isCommentOnlyLine) {
                // Comments should be indented like normal code (use previous line's actual indentation)
                newIndent = previousLineActualIndent;
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

            // Remove double spaces while preserving strings
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
                    if (processedContent.length() == 0 || processedContent.charAt(processedContent.length() - 1) != ' ') {
                        processedContent.append(c);
                    }
                } else {
                    processedContent.append(c);
                }
            }

            // Processed line with proper indent
            String processedLine = newIndent + processedContent.toString();

            // Store this actual indentation for the next line's potential comment
            // This needs to be stored AFTER all special handling is done
            if (!isCommentOnlyLine && !isLineContinuation) {
                previousLineActualIndent = newIndent;
            }

            // Check for string continuation pattern
            boolean hasStringContinuation = STRING_CONTINUATION_PATTERN.matcher(processedLine).matches();

            if (hasStringContinuation && i < lines.length - 1) {
                // This is a line with string continuation
                // Processing continuation line

                // Add the first line as is
                result.append(processedLine);
                result.append("\n");

                // Process the continuation line if it exists and starts with a string
                String nextLine = lines[i+1];
                String nextLineTrimmed = nextLine.trim();

                if (STRING_START_PATTERN.matcher(nextLineTrimmed).matches()) {
                    // Get proper indentation for continuation
                    String contIndent = newIndent + " ".repeat(indentSize);

                    // FIX: Make sure not to duplicate quote marks
                    // First ensure we have a proper string start (exactly one quote)
                    String stringContent = nextLineTrimmed;
                    // Count leading quotes to handle multiple formats
                    int quoteCount = 0;
                    while (quoteCount < stringContent.length() &&
                            (stringContent.charAt(quoteCount) == '"' || stringContent.charAt(quoteCount) == '\'')) {
                        quoteCount++;
                    }

                    // Use only one quote
                    String fixedContent;
                    if (quoteCount > 0) {
                        char quote = stringContent.charAt(0);
                        fixedContent = quote + stringContent.substring(quoteCount);
                    } else {
                        fixedContent = stringContent;
                    }

                    // Add with proper indent
                    result.append(contIndent).append(fixedContent);

                    // If not at end, add newline
                    if (i < lines.length - 2) {
                        result.append("\n");
                    }
                }
            } else if (lineBreakPosition > 0 && processedLine.length() > lineBreakPosition && lines.length < 10000) {
                // Line needs breaking (skip for very large files to improve performance)
                List<String> brokenLines = breakLine(processedLine, lineBreakPosition, indentSize);

                for (int j = 0; j < brokenLines.size(); j++) {
                    result.append(brokenLines.get(j));
                    if (j < brokenLines.size() - 1) {
                        result.append("\n");
                    } else if (i < lines.length - 1) {
                        // Only add newline after last segment if not at end of file
                        result.append("\n");
                    }
                }
            } else {
                // Regular line, no breaking needed
                result.append(processedLine);

                // Add newline if not at end of file
                if (i < lines.length - 1) {
                    result.append("\n");
                }
            }

            // Update indentation for next lines
            if (lowerLine.startsWith("if ") ||
                    lowerLine.startsWith("while ") ||
                    lowerLine.startsWith("for ") ||
                    lowerLine.startsWith("do ") ||
                    (lowerLine.startsWith("case ") && !inSwitchBlock)) { // Don't increase indent for case in switch
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
            
            // elseif increases indent like if, but else does NOT increase indent
            if (lowerLine.startsWith("elseif")) {
                indentLevel++;
            }

            // Increase indent after switch statement
            if (isSwitchStatement) {
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

        // Check if this line already contains string continuation
        if (STRING_CONTINUATION_PATTERN.matcher(line).matches()) {
            // Not breaking line with existing string continuation
            result.add(line);
            return result;
        }

        // Start with base indent
        String currentLine = indent;
        int pos = 0;

        // Track string context
        boolean inString = false;
        char stringDelimiter = 0;

        while (pos < content.length()) {
            // Calculate available space
            int availableSpace = lineBreakPosition - currentLine.length();

            // Safety check: ensure we have positive available space
            if (availableSpace <= 0) {
                // Line is already too long, force a break
                result.add(currentLine);
                currentLine = indent + " ".repeat(indentSize);
                availableSpace = lineBreakPosition - currentLine.length();
            }

            // Check if remaining content fits
            if (pos + availableSpace >= content.length()) {
                currentLine += content.substring(pos);
                result.add(currentLine);
                currentLine = null; // Prevent duplication
                break;
            }

            // Find break point
            int breakPos = findBreakPoint(content, pos, pos + availableSpace);
            
            // Safety check: ensure we're making progress
            if (breakPos <= pos) {
                // Force progress by breaking at least one character ahead
                breakPos = Math.min(pos + 1, content.length());
            }

            // Update string context
            for (int i = pos; i < breakPos; i++) {
                char c = content.charAt(i);
                if ((c == '"' || c == '\'') && (i == 0 || content.charAt(i - 1) != '\\')) {
                    if (!inString) {
                        inString = true;
                        stringDelimiter = c;
                    } else if (c == stringDelimiter) {
                        inString = false;
                    }
                }
            }

            // Add segment
            String segment = content.substring(pos, breakPos);

            // Handle string breaks
            if (inString) {
                // Removed excessive logging that can cause memory issues

                // Check for space at break point
                boolean breakAtSpace = breakPos < content.length() && content.charAt(breakPos) == ' ';
                if (breakAtSpace) {
                    segment += " ";
                    breakPos++;
                }

                // Close string and add continuation
                currentLine += segment + stringDelimiter + " +;";
                result.add(currentLine);

                // Start new line with string
                String continuationIndent = indent + " ".repeat(indentSize);
                currentLine = continuationIndent + stringDelimiter;
            } else {
                // Normal break
                if (!segment.trim().endsWith(";") && !segment.trim().endsWith("+") && !segment.trim().endsWith("//")) {
                    currentLine += segment + " ;";
                } else {
                    currentLine += segment;
                }

                result.add(currentLine);

                // Start new line
                currentLine = indent + " ".repeat(indentSize);
            }

            pos = breakPos;
        }

        // Add remaining content if any
        if (currentLine != null && currentLine.length() > indent.length()) {
            result.add(currentLine);
        }

        return result;
    }

    /**
     * Find a good break point
     */
    private int findBreakPoint(String content, int startPos, int endPos) {
        if (endPos >= content.length()) return content.length();

        // Look for good break points
        for (int i = endPos; i > startPos; i--) {
            char c = content.charAt(i);

            // Don't break arrow operator
            if (i > 0 && content.charAt(i-1) == '-' && c == '>') continue;
            if (i < content.length()-1 && c == '-' && content.charAt(i+1) == '>') continue;

            // Check for logical operators
            if (c == '.') {
                String nearby = content.substring(
                        Math.max(0, i-4),
                        Math.min(content.length(), i+5)
                );
                if (nearby.contains(".and.") || nearby.contains(".or.")) continue;
            }

            // Good break points
            if (c == ',' || c == ' ' || c == '.' || c == ';' || c == ')') return i + 1;
        }

        return startPos;
    }

    /**
     * Log a message via the common HarbourLogger
     */
    private void log(String message) {
        HarbourLogger.log("PostFormatter", message);
    }
}
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
        boolean inDoCaseBlock = false;
        boolean inClassDefinition = false;
        boolean inBlockComment = false; // Track if we're inside a block comment
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

        // Lines to skip (continuation lines)
        List<Integer> skipLines = new ArrayList<>();
        // Lines that are continuations of previous lines
        List<Integer> continuationLines = new ArrayList<>();

        // First pass - identify continuation lines
        for (int i = 0; i < lines.length - 1; i++) {
            String line = lines[i].trim();
            String nextLine = lines[i+1].trim();

            // String continuation pattern - handle multiple continuations
            if (STRING_CONTINUATION_PATTERN.matcher(line).matches() &&
                    STRING_START_PATTERN.matcher(nextLine).matches()) {
                skipLines.add(i+1); // Skip the next line

                // Check for chain of string continuations
                int j = i + 1;
                while (j < lines.length - 1) {
                    String currentLine = lines[j].trim();
                    String followingLine = lines[j+1].trim();

                    if (STRING_CONTINUATION_PATTERN.matcher(currentLine).matches() &&
                            STRING_START_PATTERN.matcher(followingLine).matches()) {
                        skipLines.add(j+1); // Skip this continuation too
                        j++;
                    } else {
                        break; // End of continuation chain
                    }
                }
            }

            // Regular line continuation with semicolon
            if (LINE_CONTINUATION_PATTERN.matcher(line).matches() && !nextLine.isEmpty()) {
                continuationLines.add(i+1); // Mark the next line as a continuation
            }
        }

        // Store previous line's *actual* indentation for comment alignment
        String previousLineActualIndent = "";

        // Track format exclusion
        boolean inFormatExclusion = false;

        // Main processing loop
        for (int i = 0; i < lines.length; i++) {
            // Skip lines that are part of continuation pairs
            if (skipLines.contains(i)) {
                continue;
            }

            String lineWithWhitespace = lines[i];
            String line = lineWithWhitespace.trim();

            // Check for format exclusion markers
            if (line.contains("// fmt: off") || line.contains("# fmt: off")) {
                inFormatExclusion = true;
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            if (line.contains("// fmt: on") || line.contains("# fmt: on")) {
                inFormatExclusion = false;
                result.append(lineWithWhitespace);
                if (i < lines.length - 1) {
                    result.append("\n");
                }
                continue;
            }

            // If in format exclusion or line has fmt: skip, preserve as-is
            if (inFormatExclusion || line.contains("// fmt: skip") || line.contains("# fmt: skip")) {
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
            boolean isLineContinuation = continuationLines.contains(i);

            // Check if previous line ends with semicolon (manual continuation formatting)
            boolean prevLineHasContinuation = i > 0 && lines[i-1].trim().endsWith(";");

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

            // Debug: Log all long lines
            if (processedLine.length() > 99) {
                log("LONG LINE (>" + 99 + "): " + processedLine.substring(0, Math.min(50, processedLine.length())) + "...");
                log("  - Full length: " + processedLine.length());
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

            // Check for string continuation pattern
            boolean hasStringContinuation = STRING_CONTINUATION_PATTERN.matcher(processedLine).matches();

            if (hasStringContinuation && i < lines.length - 1) {
                // This is a line with string continuation
                // Processing continuation line

                // Add the first line as is
                result.append(processedLine);
                result.append("\n");

                // Process ALL continuation lines in the chain
                int j = i + 1;
                while (j < lines.length) {
                    String nextLine = lines[j];
                    String nextLineTrimmed = nextLine.trim();

                    // Check if this line is marked to skip (part of string continuation)
                    if (!skipLines.contains(j)) {
                        break; // Not a continuation, stop processing
                    }

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

                        // Add newline if not at end
                        if (j < lines.length - 1) {
                            result.append("\n");
                        }
                    }

                    j++;
                }
            } else if (lineBreakPosition > 0 && processedLine.length() > lineBreakPosition && lines.length < 10000 &&
                       !isLineContinuation && !prevLineHasContinuation && !processedLine.trim().endsWith(";")) {
                // Line needs breaking (skip for very large files to improve performance)
                // Never break continuation lines - they're already part of a multi-line statement
                // Don't break lines that already end with semicolon (manually formatted continuations)
                // Don't break lines if previous line has continuation (part of manual formatting)

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

        // Special handling for lines starting with ? followed by a string
        String trimmed = content.trim();
        if (trimmed.startsWith("?") && trimmed.length() > 2) {
            // Check if it's a string after the ?
            int afterQ = trimmed.indexOf("?") + 1;
            while (afterQ < trimmed.length() && Character.isWhitespace(trimmed.charAt(afterQ))) {
                afterQ++;
            }

            if (afterQ < trimmed.length()) {
                char stringDelim = trimmed.charAt(afterQ);
                if (stringDelim == '"' || stringDelim == '\'') {
                    // This is a ? followed by a string - handle specially
                    return breakStringLine(line, indent, content, stringDelim, lineBreakPosition, indentSize);
                }
            }
        }

        // Regular line breaking logic for non-string lines
        return breakRegularLine(line, indent, content, lineBreakPosition, indentSize);
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
        String stringContent = content.substring(stringStart + 1, stringEnd); // Content without delimiters
        String afterString = content.substring(stringEnd + 1);

        // If the whole line fits, don't break
        if (line.length() <= lineBreakPosition) {
            result.add(line);
            return result;
        }

        // Calculate how much string content fits on first line
        int firstLineSpace = lineBreakPosition - indent.length() - beforeString.length() - 1 - 4; // -1 for opening quote, -4 for ' +;
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

            // First line: ? 'firstPart' +;
            result.add(indent + beforeString + stringDelim + firstPart + stringDelim + " +;");

            // Second line: 'secondPart'
            String continuationIndent = indent + " ".repeat(indentSize);
            result.add(continuationIndent + stringDelim + secondPart + stringDelim + afterString);
        }

        return result;
    }

    /**
     * Break a regular (non-string) line
     */
    private List<String> breakRegularLine(String line, String indent, String content,
                                          int lineBreakPosition, int indentSize) {
        List<String> result = new ArrayList<>();
        String currentLine = indent;
        int pos = 0;

        while (pos < content.length()) {
            // Calculate available space
            int maxLineLength = Math.min(99, lineBreakPosition);
            int availableSpace = maxLineLength - currentLine.length() - 1; // -1 for potential semicolon

            // Safety check
            if (availableSpace <= 0) {
                result.add(currentLine);
                currentLine = indent + " ".repeat(indentSize);
                availableSpace = maxLineLength - currentLine.length() - 1;
            }

            // Check if remaining content fits
            if (pos + availableSpace >= content.length()) {
                currentLine += content.substring(pos);
                result.add(currentLine);
                break;
            }

            // Find break point
            int breakPos = findBreakPoint(content, pos, pos + availableSpace);
            if (breakPos <= pos) {
                breakPos = Math.min(pos + availableSpace, content.length());
            }

            String segment = content.substring(pos, breakPos);

            // Check if we need a semicolon
            String trimmedSegment = segment.trim().toLowerCase();
            boolean isControlKeyword = trimmedSegment.startsWith("if ") || trimmedSegment.equals("if") ||
                                      trimmedSegment.startsWith("else") || trimmedSegment.equals("else") ||
                                      trimmedSegment.startsWith("elseif ");

            if (isControlKeyword) {
                currentLine += segment;
            } else if (shouldAddContinuationSemicolon(segment, content, pos, breakPos)) {
                currentLine += segment + ";";
            } else {
                currentLine += segment;
            }

            result.add(currentLine);
            currentLine = indent + " ".repeat(indentSize);
            pos = breakPos;
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

        // Look for good break points, starting from the end and working backwards
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
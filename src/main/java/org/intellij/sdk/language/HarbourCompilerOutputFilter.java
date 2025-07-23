package org.intellij.sdk.language;

import com.intellij.execution.filters.Filter;
import com.intellij.execution.filters.HyperlinkInfo;
import com.intellij.execution.filters.OpenFileHyperlinkInfo;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.execution.ui.ConsoleViewContentType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Filter Harbour compiler output to create file links and highlight errors.
 */
public class HarbourCompilerOutputFilter implements Filter {
    private final Project project;

    // Pattern to match file:line references in compiler output
    private static final Pattern FILE_PATTERN = Pattern.compile("([^:]+)\\((\\d+)\\)");
    
    // Pattern to match stack trace file references: "in filepath(line)"
    private static final Pattern STACK_TRACE_PATTERN = Pattern.compile("in\\s+([^\\s]+)\\((\\d+)\\)");
    
    // Pattern to match function names in stack traces: "FUNCTION_NAME in filepath(line)"
    private static final Pattern FUNCTION_PATTERN = Pattern.compile("(\\d+):\\s+(\\w+)\\s+in\\s+([^\\s]+)\\((\\d+)\\)");

    // Pattern to match error codes in compiler output
    private static final Pattern ERROR_PATTERN = Pattern.compile("Error [A-Z]\\d+");
    
    // Pattern to match ALL Harbour runtime errors - UNIVERSAL approach
    private static final Pattern RUNTIME_ERROR_PATTERN = Pattern.compile(
        "(Error\\s+\\w+/\\d+|" +                   // ANY Error XXX/### pattern (BASE/1341, EVAL/21, etc)
        "Unrecoverable error|" +                   // Unrecoverable errors
        "Error at:|" +                             // Generic error location
        "Called from\\s+\\w+\\(\\d+\\)|" +        // Stack trace with function(line)
        "\\d+:\\s+\\w+\\(\\d+\\)\\s+in\\s+|" +   // Stack trace format: "1: MAIN(11) in"
        "Division by zero|" +                      // Math errors
        "Bound error|" +                           // Array bounds
        "Type mismatch|" +                         // Type errors
        "Variable does not exist|" +               // Variable errors
        "Access denied|" +                         // Access errors
        "Syntax error|" +                          // Syntax errors
        "File not found|" +                        // File errors
        "Memory exhausted|" +                      // Memory errors
        "Stack overflow|" +                        // Stack errors
        "Argument error|" +                        // Argument errors
        "NIL access error|" +                      // NIL pointer errors
        "Open error|" +                            // File open errors
        "Create error|" +                          // File create errors
        "Read error|" +                            // File read errors
        "Write error)",                            // File write errors
        Pattern.CASE_INSENSITIVE
    );

    public HarbourCompilerOutputFilter(Project project) {
        this.project = project;
        HarbourLogger.log("HarbourCompilerOutputFilter", "Filter initialized");
    }

    /**
     * Process a line of compiler or program output and filter/recognize patterns.
     *
     * @param line Output line from compiler or program
     * @return Filtered result with links or highlighting as needed
     */
    @Nullable
    @Override
    public Result applyFilter(@NotNull String line, int entireLength) {
        // Removed flooding log message - was logging every single line of output

        Result result = null;
        Matcher fileMatcher = FILE_PATTERN.matcher(line);
        Matcher stackTraceMatcher = STACK_TRACE_PATTERN.matcher(line);
        Matcher functionMatcher = FUNCTION_PATTERN.matcher(line);
        Matcher errorMatcher = ERROR_PATTERN.matcher(line);
        Matcher runtimeErrorMatcher = RUNTIME_ERROR_PATTERN.matcher(line);

        // Check for runtime errors first (highest priority)
        if (runtimeErrorMatcher.find()) {
            // REMOVED: HarbourLogger.error causes flooding when output filter runs repeatedly
            // The error is already displayed in console, no need to log it again
            
            // Mark as error in console with red text
            result = new Result(entireLength - line.length(), entireLength, null,
                    ConsoleViewContentType.ERROR_OUTPUT.getAttributes());
        }
        // Check for function pattern with file reference "1: FUNCTION in filepath(line)"
        else if (functionMatcher.find()) {
            String functionName = functionMatcher.group(2);
            String filePath = functionMatcher.group(3);
            int lineNumber = Integer.parseInt(functionMatcher.group(4));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found function reference: " + functionName + " in " + filePath + ":" + lineNumber);

            result = createResult(line, entireLength, filePath, lineNumber);
        }
        // Check for stack trace file references "in filepath(line)"
        else if (stackTraceMatcher.find()) {
            String filePath = stackTraceMatcher.group(1);
            int lineNumber = Integer.parseInt(stackTraceMatcher.group(2));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found stack trace file reference: " + filePath + ":" + lineNumber);

            result = createResult(line, entireLength, filePath, lineNumber);
        }
        // Check for compiler error with file and line
        else if (fileMatcher.find()) {
            String filePath = fileMatcher.group(1);
            int lineNumber = Integer.parseInt(fileMatcher.group(2));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found file reference: " + filePath + ":" + lineNumber);

            result = createResult(line, entireLength, filePath, lineNumber);
        }
        // Check for generic error with code
        else if (errorMatcher.find()) {
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found error: " + errorMatcher.group(0));

            // Just mark as error without link
            result = new Result(entireLength - line.length(), entireLength, null,
                    ConsoleViewContentType.ERROR_OUTPUT.getAttributes());
        }
        // For normal output, we'll just leave it as is

        return result;
    }

    /**
     * Create a result with file hyperlink.
     */
    private Result createResult(String line, int entireLength, String filePath, int lineNumber) {
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(filePath);
        HyperlinkInfo hyperlinkInfo = null;

        if (vFile != null) {
            hyperlinkInfo = new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1);
        }

        // Create result with hyperlink
        return new Result(entireLength - line.length(), entireLength, hyperlinkInfo, null);
    }
}
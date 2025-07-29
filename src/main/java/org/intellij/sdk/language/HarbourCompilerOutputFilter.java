package org.intellij.sdk.language;

import com.intellij.execution.filters.Filter;
import com.intellij.execution.filters.HyperlinkInfo;
import com.intellij.execution.filters.OpenFileHyperlinkInfo;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.execution.ui.ConsoleViewContentType;
import com.intellij.find.FindManager;
import com.intellij.find.FindModel;
import com.intellij.find.FindSettings;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.fileEditor.FileEditorManager;
import com.intellij.openapi.util.TextRange;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.io.File;

/**
 * Filter Harbour compiler output to create file links and highlight errors.
 */
public class HarbourCompilerOutputFilter implements Filter {
    private final Project project;
    private final String workingDirectory;

    // Pattern to match file:line references in compiler output
    private static final Pattern FILE_PATTERN = Pattern.compile("([^:]+)\\((\\d+)\\)");
    
    // Pattern to match include file references like 'filename.ch' or "filename.ch"
    private static final Pattern INCLUDE_FILE_PATTERN = Pattern.compile("['\"]([^'\"]+\\.(ch|hbh|h))['\"]|Can't open #include file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|#include file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|'([^']+\\.(ch|hbh|h))'|\"([^\"]+\\.(ch|hbh|h))\"");
    
    // Pattern to match stack trace file references: "in filepath(line)"
    private static final Pattern STACK_TRACE_PATTERN = Pattern.compile("in\\s+([^\\s]+)\\((\\d+)\\)");
    
    // Pattern to match function names in stack traces: "FUNCTION_NAME in filepath(line)"
    private static final Pattern FUNCTION_PATTERN = Pattern.compile("(\\d+):\\s+(\\w+)\\s+in\\s+([^\\s]+)\\((\\d+)\\)");

    // Pattern to match error codes in compiler output
    private static final Pattern ERROR_PATTERN = Pattern.compile("Error [A-Z]\\d+");
    
    // Pattern to match missing function references: "Referenced, missing, but unknown function(s): FOO()"
    private static final Pattern MISSING_FUNCTION_PATTERN = Pattern.compile("Referenced,\\s+missing,\\s+but\\s+unknown\\s+function\\(s\\):\\s+([A-Z_][A-Z0-9_]*)\\(\\)");
    
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
        this(project, null);
    }
    
    public HarbourCompilerOutputFilter(Project project, String workingDirectory) {
        this.project = project;
        this.workingDirectory = workingDirectory;
        HarbourLogger.log("HarbourCompilerOutputFilter", "Filter initialized with working dir: " + workingDirectory);
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
        // Temporary debug logging for stacktrace navigation issue
        if (line.contains("test-gui.prg") || line.contains(".prg(")) {
            HarbourLogger.log("HarbourCompilerOutputFilter", "Processing line: " + line);
        }

        Result result = null;
        Matcher fileMatcher = FILE_PATTERN.matcher(line);
        Matcher stackTraceMatcher = STACK_TRACE_PATTERN.matcher(line);
        Matcher functionMatcher = FUNCTION_PATTERN.matcher(line);
        Matcher errorMatcher = ERROR_PATTERN.matcher(line);
        Matcher runtimeErrorMatcher = RUNTIME_ERROR_PATTERN.matcher(line);
        Matcher includeFileMatcher = INCLUDE_FILE_PATTERN.matcher(line);
        Matcher missingFunctionMatcher = MISSING_FUNCTION_PATTERN.matcher(line);

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

            int start = functionMatcher.start(3);  // Start of filepath
            int end = functionMatcher.end(4) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for stack trace file references "in filepath(line)"
        else if (stackTraceMatcher.find()) {
            String filePath = stackTraceMatcher.group(1);
            int lineNumber = Integer.parseInt(stackTraceMatcher.group(2));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found stack trace file reference: " + filePath + ":" + lineNumber);

            int start = stackTraceMatcher.start(1);  // Start of filepath
            int end = stackTraceMatcher.end(2) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for compiler error with file and line
        else if (fileMatcher.find()) {
            String filePath = fileMatcher.group(1);
            int lineNumber = Integer.parseInt(fileMatcher.group(2));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found file reference: " + filePath + ":" + lineNumber);

            int start = fileMatcher.start();
            int end = fileMatcher.end();
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for include file references (like miki.ch in error messages)
        else if (includeFileMatcher.find()) {
            String includeFile = extractIncludeFileName(includeFileMatcher);
            if (includeFile != null) {
                HarbourLogger.log("HarbourCompilerOutputFilter", "Found include file reference: " + includeFile);
                
                // Create hyperlink for the include file
                int start = findIncludeFileStart(includeFileMatcher, includeFile);
                int end = findIncludeFileEnd(includeFileMatcher, includeFile);
                result = createIncludeFileResult(line, entireLength, includeFile, start, end);
            }
        }
        // Check for missing function references: "Referenced, missing, but unknown function(s): FOO()"
        else if (missingFunctionMatcher.find()) {
            String functionName = missingFunctionMatcher.group(1);
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found missing function reference: " + functionName);
            
            // Create hyperlink for the function name to search for its usage
            int start = missingFunctionMatcher.start(1);  // Start of function name
            int end = missingFunctionMatcher.end(1);      // End of function name
            result = createMissingFunctionResult(line, entireLength, functionName, start, end);
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
    private Result createResult(String line, int entireLength, String filePath, int lineNumber, int matchStart, int matchEnd) {
        VirtualFile vFile = findFile(filePath);
        HyperlinkInfo hyperlinkInfo = null;

        if (vFile != null) {
            hyperlinkInfo = new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1);
        }

        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        // Create result with hyperlink only for the matched part
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Find a file, trying both absolute and relative paths.
     */
    private VirtualFile findFile(String filePath) {
        // First try as absolute path
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(filePath);
        
        // If not found and we have a working directory, try as relative path
        if (vFile == null && workingDirectory != null && !new File(filePath).isAbsolute()) {
            String absolutePath = new File(workingDirectory, filePath).getAbsolutePath();
            vFile = LocalFileSystem.getInstance().findFileByPath(absolutePath);
            
            if (vFile != null) {
                HarbourLogger.log("HarbourCompilerOutputFilter", "Resolved relative path: " + filePath + " -> " + absolutePath);
            }
        }
        
        return vFile;
    }
    
    /**
     * Extract include file name from matcher, checking all groups.
     */
    private String extractIncludeFileName(Matcher matcher) {
        // Check each group to find the non-null match
        for (int i = 1; i <= matcher.groupCount(); i++) {
            String group = matcher.group(i);
            if (group != null && (group.endsWith(".ch") || group.endsWith(".hbh") || group.endsWith(".h"))) {
                return group;
            }
        }
        return null;
    }
    
    /**
     * Find start position of include file in the match.
     */
    private int findIncludeFileStart(Matcher matcher, String includeFile) {
        String matchedText = matcher.group(0);
        int pos = matchedText.indexOf(includeFile);
        return pos >= 0 ? matcher.start() + pos : matcher.start();
    }
    
    /**
     * Find end position of include file in the match.
     */
    private int findIncludeFileEnd(Matcher matcher, String includeFile) {
        String matchedText = matcher.group(0);
        int pos = matchedText.indexOf(includeFile);
        return pos >= 0 ? matcher.start() + pos + includeFile.length() : matcher.end();
    }
    
    /**
     * Create a result with include file hyperlink.
     */
    private Result createIncludeFileResult(String line, int entireLength, String includeFile, int start, int end) {
        VirtualFile vFile = findIncludeFile(includeFile);
        HyperlinkInfo hyperlinkInfo = null;
        
        if (vFile != null) {
            hyperlinkInfo = new OpenFileHyperlinkInfo(project, vFile, 0);
        }
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + start;
        int hyperlinkEnd = lineStartInEntireText + end;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Find an include file by searching in include paths with case-insensitive matching.
     */
    private VirtualFile findIncludeFile(String includeFile) {
        HarbourLogger.log("HarbourCompilerOutputFilter", "Searching for include file: " + includeFile);
        
        // First try in working directory
        VirtualFile vFile = findIncludeFileWithCaseVariations(includeFile, workingDirectory);
        if (vFile != null) return vFile;
        
        // Try in working directory + include subdirectory
        if (workingDirectory != null) {
            String includeDir = new File(workingDirectory, "include").getAbsolutePath();
            vFile = findIncludeFileWithCaseVariations(includeFile, includeDir);
            if (vFile != null) return vFile;
        }
        
        // Try in include paths from settings
        if (project != null) {
            HarbourSettings settings = HarbourSettings.getInstance(project);
            if (settings != null) {
                for (String includePath : settings.getResolvedIncludePaths(project)) {
                    vFile = findIncludeFileWithCaseVariations(includeFile, includePath);
                    if (vFile != null) {
                        HarbourLogger.log("HarbourCompilerOutputFilter", "Found include file in settings path: " + includePath);
                        return vFile;
                    }
                }
            }
        }
        
        // Try in common Harbour installation directories
        String[] commonPaths = {
            "/usr/include/harbour",
            "/usr/local/include/harbour"
        };
        
        for (String basePath : commonPaths) {
            vFile = findIncludeFileWithCaseVariations(includeFile, basePath);
            if (vFile != null) {
                HarbourLogger.log("HarbourCompilerOutputFilter", "Found include file at: " + basePath);
                return vFile;
            }
        }
        
        HarbourLogger.log("HarbourCompilerOutputFilter", "Include file not found: " + includeFile);
        return null;
    }
    
    /**
     * Find include file with case variations (original, lowercase, uppercase, first letter capitalized).
     */
    private VirtualFile findIncludeFileWithCaseVariations(String includeFile, String searchDir) {
        if (searchDir == null) return null;
        
        // Try different case variations
        String[] variations = {
            includeFile,                                    // Original case
            includeFile.toLowerCase(),                      // All lowercase (miki.ch)
            includeFile.toUpperCase(),                      // All uppercase (MIKI.CH)
            capitalizeFirstLetter(includeFile)             // First letter capitalized (Miki.ch)
        };
        
        for (String variation : variations) {
            String fullPath = new File(searchDir, variation).getAbsolutePath();
            VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(fullPath);
            if (vFile != null) {
                HarbourLogger.log("HarbourCompilerOutputFilter", "Found " + includeFile + " as " + variation + " in " + searchDir);
                return vFile;
            }
        }
        
        return null;
    }
    
    /**
     * Capitalize first letter of filename.
     */
    private String capitalizeFirstLetter(String filename) {
        if (filename == null || filename.isEmpty()) return filename;
        return Character.toUpperCase(filename.charAt(0)) + filename.substring(1);
    }
    
    /**
     * Create a result with missing function hyperlink that searches for function usage.
     */
    private Result createMissingFunctionResult(String line, int entireLength, String functionName, int matchStart, int matchEnd) {
        HyperlinkInfo hyperlinkInfo = new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                // Search for function usage in the project
                searchForFunctionUsage(project, functionName);
            }
        };
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Search for function usage in the project using IntelliJ's Find functionality.
     */
    private void searchForFunctionUsage(Project project, String functionName) {
        HarbourLogger.log("HarbourCompilerOutputFilter", "Searching for function usage: " + functionName);
        
        // Create find model for searching
        FindModel findModel = new FindModel();
        findModel.setStringToFind(functionName + "(");  // Search for function calls like "FOO("
        findModel.setCaseSensitive(false);
        findModel.setWholeWordsOnly(false);
        findModel.setRegularExpressions(false);
        findModel.setFromCursor(false);
        findModel.setForward(true);
        findModel.setGlobal(true);
        findModel.setFindAll(true);
        
        // Use IntelliJ's Find in Files functionality
        FindManager findManager = FindManager.getInstance(project);
        findManager.showFindDialog(findModel, () -> {
            // Callback after find dialog is closed
            HarbourLogger.log("HarbourCompilerOutputFilter", "Find dialog closed for function: " + functionName);
        });
    }
}
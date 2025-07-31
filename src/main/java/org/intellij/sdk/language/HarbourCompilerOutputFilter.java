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
    
    // Pattern to match runtime error function references: "at FUNCTION_NAME(line)" or "Stack: FUNCTION_NAME(line) in filename"
    private static final Pattern RUNTIME_FUNCTION_PATTERN = Pattern.compile("at\\s+(\\w+)\\((\\d+)\\)|Stack:\\s+(\\w+)\\((\\d+)\\)\\s+in\\s+([^\\s\\r\\n]+)");

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

        Result result = null;
        Matcher fileMatcher = FILE_PATTERN.matcher(line);
        Matcher stackTraceMatcher = STACK_TRACE_PATTERN.matcher(line);
        Matcher functionMatcher = FUNCTION_PATTERN.matcher(line);
        Matcher runtimeFunctionMatcher = RUNTIME_FUNCTION_PATTERN.matcher(line);
        Matcher errorMatcher = ERROR_PATTERN.matcher(line);
        Matcher runtimeErrorMatcher = RUNTIME_ERROR_PATTERN.matcher(line);
        Matcher includeFileMatcher = INCLUDE_FILE_PATTERN.matcher(line);
        Matcher missingFunctionMatcher = MISSING_FUNCTION_PATTERN.matcher(line);

        // Check for function pattern with file reference "1: FUNCTION in filepath(line)" (HIGHEST PRIORITY)
        if (functionMatcher.find()) {
            String functionName = functionMatcher.group(2);
            String filePath = functionMatcher.group(3);
            int lineNumber = Integer.parseInt(functionMatcher.group(4));

            int start = functionMatcher.start(3);  // Start of filepath
            int end = functionMatcher.end(4) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for runtime error function patterns: "at FUNCTION(line)" or "Stack: FUNCTION(line) in filename" 
        else if (runtimeFunctionMatcher.find()) {
            String functionName = null;
            String filePath = null;
            int lineNumber = 0;
            int start = 0;
            int end = 0;
            
            // "at FUNCTION(line)" pattern - need to find the source file
            if (runtimeFunctionMatcher.group(1) != null) {
                functionName = runtimeFunctionMatcher.group(1);
                lineNumber = Integer.parseInt(runtimeFunctionMatcher.group(2));
                // For "at FUNCTION(line)", we need to find the source file in the current working directory
                filePath = findSourceFileForFunction(functionName);
                start = runtimeFunctionMatcher.start(1);  // Start of function name
                end = runtimeFunctionMatcher.end(2) + 1;  // End of line number including ')'
            }
            // "Stack: FUNCTION(line) in filename" pattern - filename is provided
            else if (runtimeFunctionMatcher.group(3) != null) {
                functionName = runtimeFunctionMatcher.group(3);
                lineNumber = Integer.parseInt(runtimeFunctionMatcher.group(4));
                filePath = runtimeFunctionMatcher.group(5);
                start = runtimeFunctionMatcher.start(3);  // Start of function name  
                end = runtimeFunctionMatcher.end(5);      // End of filename
            }
            
            if (filePath != null) {
                result = createResult(line, entireLength, filePath, lineNumber, start, end);
            }
        }
        // Check for stack trace file references "in filepath(line)"
        else if (stackTraceMatcher.find()) {
            String filePath = stackTraceMatcher.group(1);
            int lineNumber = Integer.parseInt(stackTraceMatcher.group(2));

            int start = stackTraceMatcher.start(1);  // Start of filepath
            int end = stackTraceMatcher.end(2) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for compiler error with file and line (HIGH PRIORITY - must be before runtime error check)
        else if (fileMatcher.find()) {
            String filePath = fileMatcher.group(1);
            int lineNumber = Integer.parseInt(fileMatcher.group(2));

            int start = fileMatcher.start();
            int end = fileMatcher.end();
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for include file references (like miki.ch in error messages)
        else if (includeFileMatcher.find()) {
            String includeFile = extractIncludeFileName(includeFileMatcher);
            if (includeFile != null) {
                
                // Create hyperlink for the include file
                int start = findIncludeFileStart(includeFileMatcher, includeFile);
                int end = findIncludeFileEnd(includeFileMatcher, includeFile);
                result = createIncludeFileResult(line, entireLength, includeFile, start, end);
            }
        }
        // Check for missing function references: "Referenced, missing, but unknown function(s): FOO()"
        else if (missingFunctionMatcher.find()) {
            String functionName = missingFunctionMatcher.group(1);
            
            // Create hyperlink for the function name to search for its usage
            int start = missingFunctionMatcher.start(1);  // Start of function name
            int end = missingFunctionMatcher.end(1);      // End of function name
            result = createMissingFunctionResult(line, entireLength, functionName, start, end);
        }
        // Check for generic error with code
        else if (errorMatcher.find()) {

            // Just mark as error without link
            result = new Result(entireLength - line.length(), entireLength, null,
                    ConsoleViewContentType.ERROR_OUTPUT.getAttributes());
        }
        // Check for runtime errors last (LOWEST PRIORITY - only for highlighting, no hyperlinks)
        else if (runtimeErrorMatcher.find()) {
            // REMOVED: HarbourLogger.error causes flooding when output filter runs repeatedly
            // The error is already displayed in console, no need to log it again
            
            // Mark as error in console with red text
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
            
            // Resolved relative path
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
                return vFile;
            }
        }
        
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
        });
    }
    
    /**
     * Find the source file for a function when only the function name is given.
     * This is used for runtime errors like "at MAIN(11)" where we need to find which file contains MAIN.
     */
    private String findSourceFileForFunction(String functionName) {
        // For runtime errors, we typically know the current working directory contains the main file
        // Try common patterns: if function is MAIN, look for .prg files in working directory
        if (workingDirectory == null) {
            return null;
        }
        
        File workDir = new File(workingDirectory);
        if (!workDir.exists()) {
            return null;
        }
        
        // List all .prg files in working directory, sorted alphabetically for consistent results
        File[] prgFiles = workDir.listFiles((dir, name) -> name.toLowerCase().endsWith(".prg"));
        if (prgFiles != null && prgFiles.length > 0) {
            // Sort files to ensure consistent ordering
            java.util.Arrays.sort(prgFiles, (a, b) -> a.getName().compareToIgnoreCase(b.getName()));
            
            // For MAIN function, prioritize files in this order:
            if ("MAIN".equalsIgnoreCase(functionName)) {
                // 1. Look for files with "main" in the name first
                for (File file : prgFiles) {
                    String fileName = file.getName().toLowerCase();
                    if (fileName.contains("main") && !fileName.contains("test")) {
                        return file.getAbsolutePath();
                    }
                }
                
                // 2. Look for the most recently compiled file (test_simple.prg has priority)
                for (File file : prgFiles) {
                    String fileName = file.getName().toLowerCase();
                    if (fileName.equals("test_simple.prg")) {
                        return file.getAbsolutePath();
                    }
                }
                
                // 3. Look for files with "simple" (like test_simple.prg)
                for (File file : prgFiles) {
                    String fileName = file.getName().toLowerCase();
                    if (fileName.contains("simple")) {
                        return file.getAbsolutePath();
                    }
                }
                
                // 4. Look for test files but exclude generic ones
                for (File file : prgFiles) {
                    String fileName = file.getName().toLowerCase();
                    if (fileName.startsWith("test_") || fileName.equals("test.prg")) {
                        return file.getAbsolutePath();
                    }
                }
                
                // 5. If no specific match, return the first .prg file (sorted order)
                return prgFiles[0].getAbsolutePath();
            }
        }
        
        return null;
    }
}
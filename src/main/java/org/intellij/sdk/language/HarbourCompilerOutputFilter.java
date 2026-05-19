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
import java.io.File;

/**
 * Filter Harbour compiler output to create file links and highlight errors.
 */
public class HarbourCompilerOutputFilter implements Filter {
    private final Project project;
    private final String workingDirectory;

    // Pattern to match file:line references in compiler output (must be more specific to avoid matching function references)
    // Matches: file.prg(123) Error..., ./file.prg(123) Warning..., .\file.prg(123) Error E0020...
    private static final Pattern FILE_PATTERN = Pattern.compile("((?:\\.[\\\\/])?[^\\s:()]+\\.(prg|c|cpp|h|ch))\\((\\d+)\\)(?:\\s+(?:Warning|Error)|\\s|$)");
    
    // Pattern to match include file references like 'filename.ch' or "filename.ch"
    private static final Pattern INCLUDE_FILE_PATTERN = Pattern.compile("['\"]([^'\"]+\\.(ch|hbh|h))['\"]|Can't open #include file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|#include file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|file ['\"]([^'\"]+\\.(ch|hbh|h))['\"]|'([^']+\\.(ch|hbh|h))'|\"([^\"]+\\.(ch|hbh|h))\"");
    
    // Pattern to match stack trace file references: "in filepath(line)" - must be actual file paths, not function names
    private static final Pattern STACK_TRACE_PATTERN = Pattern.compile("in\\s+([^\\s]+\\.prg)\\((\\d+)\\)");
    
    // Pattern to match function names in stack traces: "FUNCTION_NAME in filepath(line)"
    private static final Pattern FUNCTION_PATTERN = Pattern.compile("(\\d+):\\s+(\\w+)\\s+in\\s+([^\\s]+)\\((\\d+)\\)");
    
    // Pattern to match runtime error function references:
    //   "at FUNCTION_NAME(line)"                         — legacy "at"-prefix format
    //   "Stack: FUNCTION_NAME(line) in filename"         — legacy auto-monitor format
    //   "  FUNCTION_NAME(line) in filename"              — current format (whitespace-indented)
    // Allow $ in function names for Windows compatibility (e.g. __TESTSIMPLEINIT$).
    // Optional (...) prefix matches Harbour block-frame indicators like (b)INIT_HB so they are clickable too.
    private static final Pattern RUNTIME_FUNCTION_PATTERN = Pattern.compile(
        "at\\s+(?:\\([^)]*\\))?([\\w$]+)\\((\\d+)\\)" +
        "|(?:Stack:|^)\\s+(?:\\([^)]*\\))?([\\w$]+)\\((\\d+)\\)\\s+in\\s+([^\\s\\r\\n]+)");
    
    // Pattern to match runtime stacktrace file references: "at filename.prg(line)"
    private static final Pattern RUNTIME_FILE_PATTERN = Pattern.compile("at\\s+([^\\s]+\\.prg)\\((\\d+)\\)");
    
    // Pattern to match function references in compiler warnings: "in function 'MAIN(6)'" (must be very specific to avoid conflicts)
    private static final Pattern COMPILER_FUNCTION_PATTERN = Pattern.compile("in\\s+function\\s+['\"]([A-Z_][A-Z0-9_]*)\\((\\d+)\\)['\"]");
    
    // Pattern to match warning lines with file and function references: ".\myinit.prg(23) Warning ... in function 'MAIN(20)'"
    private static final Pattern WARNING_WITH_FUNCTION_PATTERN = Pattern.compile("^((?:\\.[\\\\/])?[^\\s:()]+\\.(prg|c|cpp|h|ch))\\((\\d+)\\)\\s+Warning.*in\\s+function\\s+['\"]([A-Z_][A-Z0-9_]*)\\((\\d+)\\)['\"]");

    // Pattern to match linker errors with function symbols: "multiple definition of `HB_FUN_MAIN'"
    private static final Pattern LINKER_FUNCTION_PATTERN = Pattern.compile("multiple\\s+definition\\s+of\\s+[`']HB_FUN_([A-Z_][A-Z0-9_]*)[`']");

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
        Matcher runtimeFileMatcher = RUNTIME_FILE_PATTERN.matcher(line);
        Matcher compilerFunctionMatcher = COMPILER_FUNCTION_PATTERN.matcher(line);
        Matcher warningWithFunctionMatcher = WARNING_WITH_FUNCTION_PATTERN.matcher(line);
        Matcher linkerFunctionMatcher = LINKER_FUNCTION_PATTERN.matcher(line);
        Matcher errorMatcher = ERROR_PATTERN.matcher(line);
        Matcher runtimeErrorMatcher = RUNTIME_ERROR_PATTERN.matcher(line);
        Matcher includeFileMatcher = INCLUDE_FILE_PATTERN.matcher(line);
        Matcher missingFunctionMatcher = MISSING_FUNCTION_PATTERN.matcher(line);

        // Pre-check if we have both file and function matches in the same line
        boolean hasFileMatch = fileMatcher.find();
        boolean hasFunctionMatch = compilerFunctionMatcher.find();
        
        // Reset matchers for actual processing
        fileMatcher.reset();
        compilerFunctionMatcher.reset();

        // Check for warning lines with function references: ".\myinit.prg(23) Warning ... in function 'MAIN(20)'" (HIGHEST PRIORITY)
        if (warningWithFunctionMatcher.find()) {
            String filePath = warningWithFunctionMatcher.group(1);
            int warningLineNumber = Integer.parseInt(warningWithFunctionMatcher.group(3));
            String functionName = warningWithFunctionMatcher.group(4);
            int functionLineNumber = Integer.parseInt(warningWithFunctionMatcher.group(5));

            HarbourLogger.trace("CompilerOutputFilter", "WARNING_WITH_FUNCTION_PATTERN matched - filePath: " + filePath +
                              ", warningLine: " + warningLineNumber + ", functionName: " + functionName +
                              ", functionLine: " + functionLineNumber);

            // Create two hyperlinks: file reference and function reference
            int lineStartInEntireText = entireLength - line.length();

            // Hyperlink for the file reference: .\email.prg(284)
            int fileStart = lineStartInEntireText + warningWithFunctionMatcher.start(1);
            int fileEnd = lineStartInEntireText + warningWithFunctionMatcher.end(3) + 1;
            HyperlinkInfo fileLink = createHyperlinkInfo(filePath, warningLineNumber);

            // Hyperlink for the function reference: WINEMAIL(175)
            int funcStart = lineStartInEntireText + warningWithFunctionMatcher.start(4);
            int funcEnd = lineStartInEntireText + warningWithFunctionMatcher.end(5) + 1;
            HyperlinkInfo funcLink = createWarningFunctionHyperlink(filePath, functionLineNumber);

            // Return both hyperlinks as a combined result
            java.util.List<ResultItem> items = new java.util.ArrayList<>();
            items.add(new ResultItem(fileStart, fileEnd, fileLink));
            items.add(new ResultItem(funcStart, funcEnd, funcLink));
            result = new Result(items);
        }
        // Check for function pattern with file reference "1: FUNCTION in filepath(line)" (HIGH PRIORITY)
        else if (functionMatcher.find()) {
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
                // For "at FUNCTION(line)", search for the function and check line ranges
                filePath = findSourceFileForFunction(functionName, lineNumber);
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
        // Check for runtime file pattern: "at filename.prg(line)"
        else if (runtimeFileMatcher.find()) {
            String filePath = runtimeFileMatcher.group(1);
            int lineNumber = Integer.parseInt(runtimeFileMatcher.group(2));

            int start = runtimeFileMatcher.start(1);  // Start of filepath
            int end = runtimeFileMatcher.end(2) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for stack trace file references "in filepath(line)"
        else if (stackTraceMatcher.find()) {
            String filePath = stackTraceMatcher.group(1);
            int lineNumber = Integer.parseInt(stackTraceMatcher.group(2));

            int start = stackTraceMatcher.start(1);  // Start of filepath
            int end = stackTraceMatcher.end(2) + 1;  // End of line number including ')'
            result = createResult(line, entireLength, filePath, lineNumber, start, end);
        }
        // Check for linker function errors: "multiple definition of `HB_FUN_MAIN'" (HIGH PRIORITY for linker errors)
        else if (linkerFunctionMatcher.find()) {
            String functionName = linkerFunctionMatcher.group(1);  // Extract MAIN from HB_FUN_MAIN
            
            // Create hyperlink that immediately opens find dialog for the function
            int start = linkerFunctionMatcher.start(1);  // Start of function name
            int end = linkerFunctionMatcher.end(1);      // End of function name
            result = createLinkerFunctionResult(line, entireLength, functionName, start, end);
        }
        // Check for compiler function references: "in function 'MAIN(6)'" (HIGH PRIORITY for compiler warnings)
        else if (compilerFunctionMatcher.find()) {
            String functionName = compilerFunctionMatcher.group(1);
            int lineNumber = Integer.parseInt(compilerFunctionMatcher.group(2));
            
            // Create hyperlink for the function reference using our generic function search
            int start = compilerFunctionMatcher.start(1);  // Start of function name
            int end = compilerFunctionMatcher.end(2) + 1;  // End of line number including ')'
            result = createCompilerFunctionResult(line, entireLength, functionName, lineNumber, start, end);
        }
        // Check for compiler error with file and line (LOWER PRIORITY than function references)
        else if (fileMatcher.find()) {
            String filePath = fileMatcher.group(1);
            int lineNumber = Integer.parseInt(fileMatcher.group(3));
            
            HarbourLogger.trace("CompilerOutputFilter", "FILE_PATTERN matched - filePath: " + filePath + ", lineNumber: " + lineNumber);

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
            // Validate that the resolved file actually matches the expected filename
            String expectedFileName = new File(filePath).getName().toLowerCase();
            String actualFileName = vFile.getName().toLowerCase();

            if (expectedFileName.equals(actualFileName)) {
                hyperlinkInfo = new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1);
            } else {
                hyperlinkInfo = createFileNotInProjectHyperlink(filePath, lineNumber);
            }
        } else {
            hyperlinkInfo = createFileNotInProjectHyperlink(filePath, lineNumber);
        }

        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        // Create result with hyperlink only for the matched part
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Create a HyperlinkInfo for a file reference (reuses createResult logic without
     * wrapping in a Result, for use with multi-item results).
     */
    private HyperlinkInfo createHyperlinkInfo(String filePath, int lineNumber) {
        VirtualFile vFile = findFile(filePath);
        if (vFile != null) {
            String expectedFileName = new File(filePath).getName().toLowerCase();
            String actualFileName = vFile.getName().toLowerCase();
            if (expectedFileName.equals(actualFileName)) {
                return new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1);
            }
        }
        return createFileNotInProjectHyperlink(filePath, lineNumber);
    }

    /**
     * Create a HyperlinkInfo for a warning function reference that opens the file
     * at the function's line number.
     */
    private HyperlinkInfo createWarningFunctionHyperlink(String filePath, int functionLineNumber) {
        return new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                VirtualFile vFile = findFile(filePath);
                if (vFile != null && vFile.exists()) {
                    new OpenFileHyperlinkInfo(project, vFile, functionLineNumber - 1).navigate(project);
                } else {
                    String fileName = new java.io.File(filePath).getName();
                    String[] fallbackPaths = { filePath, fileName, ".hbmk/" + fileName, "hbmk/" + fileName };
                    VirtualFile foundFile = null;
                    for (String path : fallbackPaths) {
                        if (workingDirectory != null) {
                            String absolutePath = new java.io.File(workingDirectory, path)
                                .getAbsolutePath().replace('\\', '/');
                            foundFile = LocalFileSystem.getInstance().findFileByPath(absolutePath);
                            if (foundFile != null && foundFile.exists()) break;
                        }
                    }
                    if (foundFile != null) {
                        new OpenFileHyperlinkInfo(project, foundFile, functionLineNumber - 1).navigate(project);
                    } else {
                        String searchName = fileName.contains(".")
                            ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
                        logFunctionNotFound(searchName);
                    }
                }
            }
        };
    }

    /**
     * Create a hyperlink for files not in project that uses enhanced search logic.
     */
    private HyperlinkInfo createFileNotInProjectHyperlink(String filePath, int lineNumber) {
        return new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                // Extract function name from file path for search
                String fileName = new File(filePath).getName();
                String functionName = fileName.substring(0, fileName.lastIndexOf('.')); // Remove extension

                // If this looks like a main file, search for "main" function specifically
                if (functionName.toLowerCase().contains("main") || functionName.toLowerCase().equals("myinit")) {
                    functionName = "main";
                }

                handleFileNotInProject(functionName, lineNumber);
            }
        };
    }
    
    /**
     * Find a file, trying both absolute and relative paths with enhanced debug support.
     */
    private VirtualFile findFile(String filePath) {
        // Clean up the file path (remove .\ prefix common in Windows)
        String cleanPath = filePath;
        if (cleanPath.startsWith(".\\") || cleanPath.startsWith("./")) {
            cleanPath = cleanPath.substring(2);
        }

        // Normalize path separators for cross-platform compatibility
        cleanPath = cleanPath.replace('\\', '/');

        // First try as absolute path
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(cleanPath);

        // If not found and we have a working directory, try as relative path
        if (vFile == null && workingDirectory != null && !new File(cleanPath).isAbsolute()) {
            String absolutePath = new File(workingDirectory, cleanPath).getAbsolutePath().replace('\\', '/');
            vFile = LocalFileSystem.getInstance().findFileByPath(absolutePath);
        }

        // If still not found, try with original path
        if (vFile == null) {
            String originalNormalized = filePath.replace('\\', '/');
            vFile = LocalFileSystem.getInstance().findFileByPath(originalNormalized);

            if (vFile == null && workingDirectory != null && !new File(filePath).isAbsolute()) {
                String absolutePath = new File(workingDirectory, filePath).getAbsolutePath().replace('\\', '/');
                vFile = LocalFileSystem.getInstance().findFileByPath(absolutePath);
            }
        }

        // If still not found, try looking in .hbmk directory (temp build directory)
        if (vFile == null && workingDirectory != null) {
            String fileName = new File(filePath).getName();

            String hbmkPath = new File(workingDirectory, ".hbmk/" + fileName).getAbsolutePath().replace('\\', '/');
            vFile = LocalFileSystem.getInstance().findFileByPath(hbmkPath);

            if (vFile == null) {
                String hbmkPathNoDot = new File(workingDirectory, "hbmk/" + fileName).getAbsolutePath().replace('\\', '/');
                vFile = LocalFileSystem.getInstance().findFileByPath(hbmkPathNoDot);
            }
        }

        // Don't perform synchronous refresh under read lock - it causes deadlocks
        // The file system will be refreshed asynchronously if needed

        if (vFile == null) {
            HarbourLogger.log("CompilerOutputFilter", "findFile: not found: " + filePath);
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
                // Log function not found - no UI operations allowed
                logFunctionNotFound(functionName);
            }
        };
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Create a result with compiler function hyperlink that navigates to function definition.
     */
    private Result createCompilerFunctionResult(String line, int entireLength, String functionName, int lineNumber, int matchStart, int matchEnd) {
        HyperlinkInfo hyperlinkInfo = new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                // Use our existing function search logic to find the function definition
                String filePath = findSourceFileForFunction(functionName, lineNumber);
                if (filePath != null) {
                    VirtualFile vFile = findFile(filePath);
                    if (vFile != null) {
                        // Check if file is in project or if it exists
                        if (vFile.exists()) {
                            new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1).navigate(project);
                        } else {
                            // File doesn't exist - search for main occurrences and open find dialog
                            logFunctionNotFound(functionName);
                        }
                    } else {
                        // File not found - this triggers the enhanced search behavior
                        // When navigation goes to files not in project, search for main occurrences
                        handleFileNotInProject(functionName, lineNumber);
                    }
                } else {
                    // No function found at all - fallback to search dialog
                    logFunctionNotFound(functionName);
                }
            }
        };
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Create a result with warning function hyperlink that directly opens the specified file at the function line.
     * This implements the user's request: "just open myinit.prg at line 20 when I click on Main(20)"
     */
    private Result createWarningFunctionResult(String line, int entireLength, String filePath, int functionLineNumber, int matchStart, int matchEnd) {
        HyperlinkInfo hyperlinkInfo = new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                // Find the file directly (no complex search needed)
                VirtualFile vFile = findFile(filePath);
                if (vFile != null && vFile.exists()) {
                    new OpenFileHyperlinkInfo(project, vFile, functionLineNumber - 1).navigate(project);
                } else {
                    // Enhanced fallback logic for debug mode files
                    String fileName = new java.io.File(filePath).getName();

                    String[] fallbackPaths = {
                        filePath,
                        fileName,
                        ".hbmk/" + fileName,
                        "hbmk/" + fileName
                    };

                    VirtualFile foundFile = null;
                    for (String path : fallbackPaths) {
                        if (workingDirectory != null) {
                            String absolutePath = new java.io.File(workingDirectory, path).getAbsolutePath().replace('\\', '/');
                            foundFile = LocalFileSystem.getInstance().findFileByPath(absolutePath);
                            if (foundFile != null && foundFile.exists()) {
                                break;
                            }
                        }
                    }

                    if (foundFile != null) {
                        new OpenFileHyperlinkInfo(project, foundFile, functionLineNumber - 1).navigate(project);
                    } else {
                        String searchName = fileName.contains(".") ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
                        logFunctionNotFound(searchName);
                    }
                }
            }
        };
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    /**
     * Create a result with linker function hyperlink that immediately opens find dialog.
     */
    private Result createLinkerFunctionResult(String line, int entireLength, String functionName, int matchStart, int matchEnd) {
        HyperlinkInfo hyperlinkInfo = new HyperlinkInfo() {
            @Override
            public void navigate(Project project) {
                // For linker errors, immediately open find dialog to search for function definition
                logFunctionNotFound(functionName);
            }
        };
        
        // Calculate actual positions in the entire output
        int lineStartInEntireText = entireLength - line.length();
        int hyperlinkStart = lineStartInEntireText + matchStart;
        int hyperlinkEnd = lineStartInEntireText + matchEnd;
        
        return new Result(hyperlinkStart, hyperlinkEnd, hyperlinkInfo, null);
    }
    
    
    /**
     * Simple fallback when function location cannot be determined - no UI operations allowed in console filter
     */
    private void logFunctionNotFound(String functionName) {
        HarbourLogger.log("CompilerOutputFilter", "Function not found in accessible files: " + functionName);
    }
    
    /**
     * Find the source file for a function when only the function name is given.
     * This is used for runtime errors like "at MAIN(11)" where we need to find which file contains MAIN.
     */
    private String findSourceFileForFunction(String functionName) {
        return findSourceFileForFunction(functionName, -1);
    }
    
    /**
     * Find the source file for a function with optional line number for range checking.
     * This implements the user's suggested approach:
     * 1. Search for "function(" in all .prg files
     * 2. If only one occurrence, return that file
     * 3. If multiple, check which function covers the line number
     * 4. If no line number or no match, fallback to search dialog
     */
    private String findSourceFileForFunction(String functionName, int lineNumber) {
        if (workingDirectory == null) {
            return null;
        }
        
        File workDir = new File(workingDirectory);
        if (!workDir.exists()) {
            return null;
        }
        
        // Get all .prg files in working directory
        File[] prgFiles = workDir.listFiles((dir, name) -> name.toLowerCase().endsWith(".prg"));
        if (prgFiles == null || prgFiles.length == 0) {
            return null;
        }
        
        // Search for function definitions like "PROCEDURE main(" or "FUNCTION main("
        String searchPattern = functionName.toLowerCase() + "(";
        java.util.List<FunctionMatch> matches = new java.util.ArrayList<>();
        
        for (File file : prgFiles) {
            try {
                java.util.List<String> lines = java.nio.file.Files.readAllLines(file.toPath());
                for (int i = 0; i < lines.size(); i++) {
                    String line = lines.get(i).trim().toLowerCase();
                    
                    // Look for function/procedure declarations
                    if ((line.startsWith("function ") || line.startsWith("procedure ")) 
                        && line.contains(searchPattern)) {
                        
                        // Found a function definition - calculate its range
                        int startLine = i + 1; // 1-based line numbers
                        int endLine = findFunctionEndLine(lines, i);
                        
                        matches.add(new FunctionMatch(file.getAbsolutePath(), startLine, endLine));
                    }
                }
            } catch (Exception e) {
                // Skip files that can't be read
                continue;
            }
        }
        
        // If no matches found, open search dialog as fallback
        if (matches.isEmpty()) {
            logFunctionNotFound(functionName);
            return null; // No specific file to navigate to
        }
        
        // If only one match, return it
        if (matches.size() == 1) {
            return matches.get(0).filePath;
        }
        
        // Multiple matches - if we have a line number, check which function contains it
        if (lineNumber > 0) {
            for (FunctionMatch match : matches) {
                if (lineNumber >= match.startLine && lineNumber <= match.endLine) {
                    return match.filePath;
                }
            }
        }
        
        // Multiple matches but no line number or line doesn't match any function
        // Return the first match as fallback
        return matches.get(0).filePath;
    }
    
    /**
     * Find the end line of a function by looking for RETURN statement or next function
     */
    private int findFunctionEndLine(java.util.List<String> lines, int functionStartIndex) {
        for (int i = functionStartIndex + 1; i < lines.size(); i++) {
            String line = lines.get(i).trim().toLowerCase();
            
            // End at next function/procedure declaration
            if (line.startsWith("function ") || line.startsWith("procedure ")) {
                return i; // Line before next function
            }
            
            // End at standalone RETURN (not inside control structures)
            if (line.equals("return") || line.startsWith("return ")) {
                // Simple heuristic: if RETURN is not indented much, it's likely the function end
                String originalLine = lines.get(i);
                int indent = originalLine.length() - originalLine.trim().length();
                if (indent <= 4) { // Reasonable assumption for function-ending RETURN
                    return i + 1;
                }
            }
        }
        
        // If no explicit end found, assume it goes to end of file
        return lines.size();
    }
    
    /**
     * Handle case where file is not in project - search for main occurrences and open find dialog if multiple matches.
     * This implements the user's requirement: "search for occurances of main and if the line number is in range we jump there.
     * In this case there is multiple files matching this condition, so in that case pls open the prefilled find dialog"
     */
    private void handleFileNotInProject(String functionName, int lineNumber) {
        if (workingDirectory == null) {
            logFunctionNotFound(functionName);
            return;
        }
        
        File workDir = new File(workingDirectory);
        if (!workDir.exists()) {
            logFunctionNotFound(functionName);
            return;
        }
        
        // Get all .prg files in working directory and subdirectories
        java.util.List<File> prgFiles = findAllPrgFiles(workDir);
        if (prgFiles.isEmpty()) {
            logFunctionNotFound(functionName);
            return;
        }
        
        // Search for function definitions like "PROCEDURE main(" or "FUNCTION main("
        String searchPattern = functionName.toLowerCase() + "(";
        java.util.List<FunctionMatch> matches = new java.util.ArrayList<>();
        
        for (File file : prgFiles) {
            try {
                java.util.List<String> lines = java.nio.file.Files.readAllLines(file.toPath());
                for (int i = 0; i < lines.size(); i++) {
                    String line = lines.get(i).trim().toLowerCase();
                    
                    // Look for function/procedure declarations
                    if ((line.startsWith("function ") || line.startsWith("procedure ")) 
                        && line.contains(searchPattern)) {
                        
                        // Found a function definition - calculate its range
                        int startLine = i + 1; // 1-based line numbers
                        int endLine = findFunctionEndLine(lines, i);
                        
                        matches.add(new FunctionMatch(file.getAbsolutePath(), startLine, endLine));
                    }
                }
            } catch (Exception e) {
                // Skip files that can't be read
                continue;
            }
        }
        
        // Check if line number is in range for any function
        if (lineNumber > 0) {
            for (FunctionMatch match : matches) {
                if (lineNumber >= match.startLine && lineNumber <= match.endLine) {
                    // Found exact match - try to open it
                    VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(match.filePath);
                    if (vFile != null) {
                        new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1).navigate(project);
                        return; // Successfully navigated
                    }
                }
            }
        }
        
        // Multiple files match or line number doesn't match any function range
        // Open prefilled find dialog as requested
        logFunctionNotFound(functionName);
    }
    
    /**
     * Find all .prg files recursively in directory tree.
     */
    private java.util.List<File> findAllPrgFiles(File directory) {
        java.util.List<File> prgFiles = new java.util.ArrayList<>();
        findPrgFilesRecursive(directory, prgFiles);
        return prgFiles;
    }
    
    /**
     * Recursive helper to find .prg files.
     */
    private void findPrgFilesRecursive(File directory, java.util.List<File> prgFiles) {
        File[] files = directory.listFiles();
        if (files == null) return;
        
        for (File file : files) {
            if (file.isDirectory()) {
                // Recurse into subdirectories
                findPrgFilesRecursive(file, prgFiles);
            } else if (file.getName().toLowerCase().endsWith(".prg")) {
                prgFiles.add(file);
            }
        }
    }
    
    /**
     * Helper class to store function match information
     */
    private static class FunctionMatch {
        final String filePath;
        final int startLine;
        final int endLine;
        
        FunctionMatch(String filePath, int startLine, int endLine) {
            this.filePath = filePath;
            this.startLine = startLine;
            this.endLine = endLine;
        }
    }
}
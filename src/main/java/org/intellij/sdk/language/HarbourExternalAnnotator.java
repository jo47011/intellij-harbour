package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.ExternalAnnotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.project.DumbAware;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.util.io.FileUtil;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.lang.ASTNode;
import com.intellij.psi.tree.IElementType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import com.intellij.psi.PsiRecursiveElementVisitor;
import org.intellij.sdk.language.psi.HarbourTypes;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import com.intellij.openapi.vfs.LocalFileSystem;

/**
 * External annotator for Harbour files that runs the Harbour compiler for linting.
 */
public class HarbourExternalAnnotator extends ExternalAnnotator<HarbourLintInfo, List<HarbourLintResult>> implements DumbAware {
    private static final Logger LOG = Logger.getInstance(HarbourExternalAnnotator.class);
    
    // Patterns to match various Harbour compiler error output formats
    private static final Pattern ERROR_PATTERN = Pattern.compile(
        "^(.+?)\\((\\d+)\\)\\s+(Error|Warning)\\s+(E\\d+|W\\d+)?\\s*(.+)$"
    );
    
    // Alternative pattern for different error formats
    private static final Pattern ERROR_PATTERN_ALT = Pattern.compile(
        "^(.+?):\\s*(\\d+):\\s*(Error|Warning):\\s*(.+)$"
    );
    
    // Another pattern for syntax errors without error codes  
    private static final Pattern ERROR_PATTERN_SIMPLE = Pattern.compile(
        "^(.+?)\\((\\d+)\\)\\s*:?\\s*(Error|Warning|error|warning)\\s*:?\\s*(.+)$", 
        Pattern.CASE_INSENSITIVE
    );
    
    // Cache for lint results
    private static class LintCache {
        String filePath;
        long modificationStamp;
        List<HarbourLintResult> results;
        
        LintCache(String filePath, long modificationStamp, List<HarbourLintResult> results) {
            this.filePath = filePath;
            this.modificationStamp = modificationStamp;
            this.results = results;
        }
    }
    
    private static final Map<String, LintCache> cache = new ConcurrentHashMap<>();
    private static final Map<String, Long> lastLintTime = new ConcurrentHashMap<>();
    private static final long DEBOUNCE_DELAY_MS = 1000; // 1 second debounce
    
    /**
     * Called by the save listener to indicate that linting should be triggered for this file
     */
    public static void setSaveTrigger(String filePath) {
        lastLintTime.put(filePath + "_save_triggered", System.currentTimeMillis());
        HarbourLogger.log("HarbourLinter", "Save trigger flag set for: " + filePath);
    }
    
    /**
     * Check if file content contains obvious syntax errors that should be shown immediately
     */
    private static boolean containsObviousSyntaxError(String content) {
        if (content == null) return false;
        
        // Pattern to detect unmatched quotes like qout("bla"xxx
        // Look for function calls with unmatched quotes
        Pattern unmatchedQuotePattern = Pattern.compile(
            "\\b\\w+\\s*\\(\\s*\"[^\"]*\"[^)\"]*(?![\"\\s]*\\))",
            Pattern.MULTILINE | Pattern.CASE_INSENSITIVE
        );
        
        boolean hasError = unmatchedQuotePattern.matcher(content).find();
        
        if (hasError) {
            HarbourLogger.log("HarbourLinter", "Detected unmatched quote pattern in file content");
        }
        
        return hasError;
    }

    @Nullable
    @Override
    public HarbourLintInfo collectInformation(@NotNull PsiFile file, @NotNull Editor editor, boolean hasErrors) {
        VirtualFile virtualFile = file.getVirtualFile();
        if (virtualFile == null || !virtualFile.isValid()) {
            HarbourLogger.log("HarbourLinter", "Skipping - invalid virtual file for: " + file.getName());
            return null;
        }
        
        String filePath = virtualFile.getPath();
        HarbourLogger.log("HarbourLinter", "=== collectInformation called for: " + file.getName() + " (" + filePath + ") ====");
        HarbourLogger.log("HarbourLinter", "  hasErrors: " + hasErrors);
        
        // Skip if file has parser errors
        if (hasErrors) {
            HarbourLogger.log("HarbourLinter", "Skipping - file has parser errors: " + file.getName());
            return null;
        }

        Project project = file.getProject();
        HarbourSettings settings = HarbourSettings.getInstance(project);
        
        HarbourLogger.log("HarbourLinter", "  lintingEnabled: " + settings.isLintingEnabled());
        HarbourLogger.log("HarbourLinter", "  lintOnSave: " + settings.isLintOnSave());
        HarbourLogger.log("HarbourLinter", "  compilerPath: " + settings.getHarbourCompilerPath());
        
        // Check if linting is enabled
        if (!settings.isLintingEnabled()) {
            HarbourLogger.log("HarbourLinter", "Skipping - linting disabled in settings");
            return null;
        }
        
        // TEMPORARY FIX: Disable save-only restriction until save listener issue is resolved
        // The save listener is not being triggered properly in some IntelliJ versions
        boolean DISABLE_SAVE_ONLY_RESTRICTION = true; // Temporary flag
        
        if (settings.isLintOnSave() && !DISABLE_SAVE_ONLY_RESTRICTION) {
            // Original save-only logic (currently bypassed)
            long currentTime = System.currentTimeMillis();
            Long lastSaveTime = lastLintTime.get(filePath + "_save_triggered");
            
            // WORKAROUND: Also check if file has obvious syntax errors that should be shown immediately
            String fileContent = file.getText();
            boolean hasObviousSyntaxError = containsObviousSyntaxError(fileContent);
            
            if (hasObviousSyntaxError) {
                HarbourLogger.log("HarbourLinter", "WORKAROUND: File has obvious syntax errors, proceeding with linting despite save-only mode");
                HarbourLogger.log("HarbourLinter", "Detected syntax error pattern in file content");
            } else if (lastSaveTime == null || (currentTime - lastSaveTime) > 5000) {
                // No recent save trigger and no obvious errors, skip real-time linting
                HarbourLogger.log("HarbourLinter", "Skipping - lintOnSave enabled but no recent save trigger and no obvious errors");
                return null;
            } else {
                HarbourLogger.log("HarbourLinter", "Proceeding - lintOnSave enabled and recently triggered by save");
                // Clear the save trigger flag
                lastLintTime.remove(filePath + "_save_triggered");
            }
        } else if (settings.isLintOnSave() && DISABLE_SAVE_ONLY_RESTRICTION) {
            HarbourLogger.log("HarbourLinter", "TEMPORARY: Save-only restriction disabled, proceeding with real-time linting");
        }
        
        // Debounce - skip if we've linted too recently (only for real-time linting)
        if (!settings.isLintOnSave()) {
            Long lastTime = lastLintTime.get(filePath);
            long currentTime = System.currentTimeMillis();
            if (lastTime != null && (currentTime - lastTime) < DEBOUNCE_DELAY_MS) {
                HarbourLogger.log("HarbourLinter", "Skipping due to debounce for: " + file.getName());
                return null;
            }
        }

        // Get compiler path
        String compilerPath = settings.getHarbourCompilerPath();
        HarbourLogger.log("HarbourLinter", "  compilerPath from settings: '" + compilerPath + "'");
        if (compilerPath == null || compilerPath.trim().isEmpty()) {
            HarbourLogger.log("HarbourLinter", "ERROR: Harbour compiler path not configured in settings");
            return null;
        }
        
        // Verify the compiler exists
        File compilerFile = new File(compilerPath);
        if (!compilerFile.exists()) {
            HarbourLogger.log("HarbourLinter", "Harbour compiler not found at: " + compilerPath);
            return null;
        }
        
        // On Windows, .exe files are always executable, so skip canExecute() check
        if (!System.getProperty("os.name").toLowerCase().contains("windows") && !compilerFile.canExecute()) {
            HarbourLogger.log("HarbourLinter", "Harbour compiler not executable at: " + compilerPath);
            return null;
        }

        // Check cache
        long modificationStamp = virtualFile.getModificationStamp();
        LintCache cached = cache.get(filePath);
        if (cached != null && cached.modificationStamp == modificationStamp) {
            HarbourLogger.log("HarbourLinter", "Using cached results for: " + file.getName());
            // Return a special marker to indicate cached results
            return new HarbourLintInfo(
                filePath,
                "CACHED", // Special marker
                project,
                compilerPath,
                settings.getIncludePaths(),
                settings.getLintExtraOptions(),
                settings.getLintWarningLevel()
            );
        }
        
        HarbourLogger.log("HarbourLinter", "collectInformation called for: " + file.getName());
        lastLintTime.put(filePath, System.currentTimeMillis());

        return new HarbourLintInfo(
            filePath,
            file.getText(),
            project,
            compilerPath,
            settings.getIncludePaths(),  // Use main include paths
            settings.getLintExtraOptions(),
            settings.getLintWarningLevel()
        );
    }

    @Nullable
    @Override
    public List<HarbourLintResult> doAnnotate(HarbourLintInfo info) {
        if (info == null) {
            return null;
        }
        
        // Check if we should use cached results
        if ("CACHED".equals(info.getFileContent())) {
            LintCache cached = cache.get(info.getFilePath());
            return cached != null ? cached.results : null;
        }

        List<HarbourLintResult> results = new ArrayList<>();
        
        try {
            // Build command line
            List<String> command = new ArrayList<>();
            command.add(info.getHarbourCompilerPath());
            command.add(info.getFilePath());
            
            // Add linting flags
            command.add("-s");  // Syntax check only
            command.add("-m");  // Compile module only
            command.add("-n0"); // No implicit starting procedure
            
            // Add warning level if specified
            if (info.getWarningLevel() > 0) {
                command.add("-w" + info.getWarningLevel());
            }
            
            // Add include paths
            for (String includePath : info.getExtraIncludePaths()) {
                if (!includePath.trim().isEmpty()) {
                    command.add("-i" + includePath);
                }
            }
            
            // Add extra options
            String extraOptions = info.getExtraOptions();
            if (extraOptions != null && !extraOptions.trim().isEmpty()) {
                // Split by spaces but respect quotes
                String[] options = extraOptions.split("\\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)");
                for (String option : options) {
                    command.add(option.replace("\"", ""));
                }
            }
            
            HarbourLogger.log("HarbourLinter", "Running: " + String.join(" ", command));
            HarbourLogger.log("HarbourLinter", "Warning level: " + info.getWarningLevel());
            HarbourLogger.log("HarbourLinter", "Include paths: " + info.getExtraIncludePaths());
            
            // Execute the compiler
            HarbourLogger.log("HarbourLinter", "=== EXECUTING HARBOUR COMPILER ===");
            HarbourLogger.log("HarbourLinter", "Working directory: " + System.getProperty("user.dir"));
            HarbourLogger.log("HarbourLinter", "Command: " + String.join(" ", command));
            
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(true);
            
            try {
                Process process = pb.start();
                HarbourLogger.log("HarbourLinter", "Process started successfully");
                
                // Read output with timeout
                List<String> outputLines = new ArrayList<>();
                try (BufferedReader reader = new BufferedReader(
                        new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        outputLines.add(line);
                        HarbourLogger.log("HarbourLinter", "LIVE OUTPUT: " + line);
                    }
                }
                
                // Wait for process to complete with timeout
                boolean finished = process.waitFor(10, java.util.concurrent.TimeUnit.SECONDS);
                if (!finished) {
                    HarbourLogger.log("HarbourLinter", "WARNING: Process timed out after 10 seconds, terminating");
                    process.destroyForcibly();
                    return results.isEmpty() ? null : results;
                }
                
                int exitCode = process.exitValue();
                HarbourLogger.log("HarbourLinter", "Process completed with exit code: " + exitCode);
                
                // Log all output for debugging
                HarbourLogger.log("HarbourLinter", "=== COMPILER OUTPUT SUMMARY ===");
                HarbourLogger.log("HarbourLinter", "Total output lines: " + outputLines.size());
                for (int i = 0; i < outputLines.size(); i++) {
                    String line = outputLines.get(i);
                    HarbourLogger.log("HarbourLinter", "LINE " + (i+1) + ": " + line);
                }
                HarbourLogger.log("HarbourLinter", "=== END COMPILER OUTPUT ===");
                
                // Parse output for errors/warnings
                int parsedCount = 0;
                for (String line : outputLines) {
                    HarbourLintResult result = parseErrorLine(line, info.getFilePath());
                    if (result != null) {
                        results.add(result);
                        parsedCount++;
                        HarbourLogger.log("HarbourLinter", "PARSED ERROR/WARNING #" + parsedCount + ": " + line);
                        HarbourLogger.log("HarbourLinter", "  -> Severity: " + result.getSeverity() + ", Code: " + result.getErrorCode() + ", Message: " + result.getMessage());
                    } else if (line.toLowerCase().contains("warning") || line.toLowerCase().contains("error")) {
                        HarbourLogger.log("HarbourLinter", "UNPARSED line with Warning/Error: " + line);
                    }
                }
                
                HarbourLogger.log("HarbourLinter", "=== LINTING SUMMARY ===");
                HarbourLogger.log("HarbourLinter", "Exit code: " + exitCode);
                HarbourLogger.log("HarbourLinter", "Total issues found: " + results.size());
                HarbourLogger.log("HarbourLinter", "Lines parsed successfully: " + parsedCount);
                
            } catch (java.io.IOException e) {
                HarbourLogger.log("HarbourLinter", "ERROR: Failed to start process: " + e.getMessage());
                HarbourLogger.log("HarbourLinter", "  Compiler path: " + command.get(0));
                HarbourLogger.log("HarbourLinter", "  File exists: " + new java.io.File(command.get(0)).exists());
                HarbourLogger.log("HarbourLinter", "  File executable: " + new java.io.File(command.get(0)).canExecute());
                throw e;
            }
            
            // Cache the results and update last lint time
            VirtualFile file = LocalFileSystem.getInstance().findFileByPath(info.getFilePath());
            if (file != null) {
                cache.put(info.getFilePath(), new LintCache(
                    info.getFilePath(),
                    file.getModificationStamp(),
                    results
                ));
                
                // Update last lint time for debouncing
                lastLintTime.put(info.getFilePath(), System.currentTimeMillis());
                HarbourLogger.log("HarbourLinter", "Updated last lint time for: " + info.getFilePath());
            }
            
        } catch (Exception e) {
            LOG.error("Error running Harbour linter", e);
            HarbourLogger.log("HarbourLinter", "Error: " + e.getMessage());
        }
        
        return results.isEmpty() ? null : results;
    }

    @Override
    public void apply(@NotNull PsiFile file, List<HarbourLintResult> annotationResult, @NotNull AnnotationHolder holder) {
        if (annotationResult == null || annotationResult.isEmpty()) {
            return;
        }

        Document document = PsiDocumentManager.getInstance(file.getProject()).getDocument(file);
        if (document == null) {
            return;
        }

        for (HarbourLintResult result : annotationResult) {
            TextRange range = null;
            
            // Check if this is an unused variable warning
            String message = result.getMessage();
            if (message != null && (message.contains("declared but not used in function") || 
                                   message.contains("is assigned but not used in function"))) {
                // Extract variable name from the message
                Pattern varNamePattern = Pattern.compile("Variable '([^']+)'");
                Matcher varNameMatcher = varNamePattern.matcher(message);
                if (varNameMatcher.find()) {
                    String varName = varNameMatcher.group(1);
                    HarbourLogger.log("HarbourLinter", "Looking for declaration of unused variable: " + varName);
                    
                    // Find the variable declaration in the PSI tree
                    range = findVariableDeclarationRange(file, varName, document);
                    if (range != null) {
                        HarbourLogger.log("HarbourLinter", "Found variable '" + varName + "' declaration at range: " + range);
                    }
                }
            }
            
            // If we couldn't find the variable declaration, or it's not an unused variable warning,
            // use the line number from the compiler
            if (range == null) {
                int line = result.getLine() - 1; // Harbour uses 1-based line numbers
                if (line < 0 || line >= document.getLineCount()) {
                    continue;
                }

                int lineStartOffset = document.getLineStartOffset(line);
                int lineEndOffset = document.getLineEndOffset(line);
                
                // Create text range for the entire line
                range = new TextRange(lineStartOffset, lineEndOffset);
                
                // Trim whitespace from the line to get the actual code range
                String lineText = document.getText(range);
                int firstNonWhitespace = 0;
                int lastNonWhitespace = lineText.length() - 1;
                
                while (firstNonWhitespace < lineText.length() && 
                       Character.isWhitespace(lineText.charAt(firstNonWhitespace))) {
                    firstNonWhitespace++;
                }
                
                while (lastNonWhitespace > firstNonWhitespace && 
                       Character.isWhitespace(lineText.charAt(lastNonWhitespace))) {
                    lastNonWhitespace--;
                }
                
                if (firstNonWhitespace < lineText.length()) {
                    range = new TextRange(
                        lineStartOffset + firstNonWhitespace,
                        lineStartOffset + lastNonWhitespace + 1
                    );
                }
            }

            // Create annotation
            String fullMessage = result.getMessage();
            if (result.getErrorCode() != null) {
                fullMessage = "[" + result.getErrorCode() + "] " + fullMessage;
            }
            
            holder.newAnnotation(result.getSeverity(), fullMessage)
                .range(range)
                .create();
        }
    }

    /**
     * Parse a single error/warning line from the Harbour compiler output.
     */
    @Nullable
    private HarbourLintResult parseErrorLine(String line, String expectedFilePath) {
        if (line == null || line.trim().isEmpty()) {
            return null;
        }

        HarbourLogger.log("HarbourLinter", "Attempting to parse line: '" + line + "'");
        
        // Try primary pattern first
        Matcher matcher = ERROR_PATTERN.matcher(line);
        String filePath = null;
        int lineNumber = 0;
        String severityStr = null;
        String errorCode = null;
        String message = null;
        
        if (matcher.matches()) {
            HarbourLogger.log("HarbourLinter", "Matched primary pattern");
            filePath = matcher.group(1);
            lineNumber = Integer.parseInt(matcher.group(2));
            severityStr = matcher.group(3);
            errorCode = matcher.group(4);
            message = matcher.group(5);
        } else {
            // Try alternative pattern
            matcher = ERROR_PATTERN_ALT.matcher(line);
            if (matcher.matches()) {
                HarbourLogger.log("HarbourLinter", "Matched alternative pattern");
                filePath = matcher.group(1);
                lineNumber = Integer.parseInt(matcher.group(2));
                severityStr = matcher.group(3);
                errorCode = null; // No error code in this format
                message = matcher.group(4);
            } else {
                // Try simple pattern
                matcher = ERROR_PATTERN_SIMPLE.matcher(line);
                if (matcher.matches()) {
                    HarbourLogger.log("HarbourLinter", "Matched simple pattern");
                    filePath = matcher.group(1);
                    lineNumber = Integer.parseInt(matcher.group(2));
                    severityStr = matcher.group(3);
                    errorCode = null; // No error code in this format
                    message = matcher.group(4);
                } else {
                    HarbourLogger.log("HarbourLinter", "No pattern matched for line: " + line);
                    return null;
                }
            }
        }
        
        // Log for debugging
        HarbourLogger.log("HarbourLinter", "Parsed components - file: '" + filePath + "', line: " + lineNumber + 
            ", severity: '" + severityStr + "', code: '" + errorCode + "', message: '" + message + "'");
        HarbourLogger.log("HarbourLinter", "Comparing paths: parsed='" + filePath + "' expected='" + expectedFilePath + "'");
        
        // Normalize paths for comparison (handle Windows vs Unix paths)
        String normalizedFilePath = filePath.replace('\\', '/');
        String normalizedExpectedPath = expectedFilePath.replace('\\', '/');
        
        // Only process errors for the file we're linting
        if (!normalizedFilePath.equals(normalizedExpectedPath)) {
            // Also try case-insensitive comparison for Windows
            if (!normalizedFilePath.equalsIgnoreCase(normalizedExpectedPath)) {
                HarbourLogger.log("HarbourLinter", "Path mismatch, skipping line");
                return null;
            }
        }

        HighlightSeverity severity;
        if ("Error".equalsIgnoreCase(severityStr)) {
            severity = HighlightSeverity.ERROR;
        } else if ("Warning".equalsIgnoreCase(severityStr)) {
            severity = HighlightSeverity.WARNING;
        } else {
            severity = HighlightSeverity.INFORMATION;
        }

        // Don't try to extract line numbers from unused variable messages - the numbers in parentheses
        // are variable positions, not line numbers. We'll find the actual line in the apply() method.
        
        HarbourLogger.log("HarbourLinter", "Parsed result: line=" + lineNumber + 
            ", severity=" + severityStr + ", code=" + errorCode + ", message=" + message);
        
        return new HarbourLintResult(lineNumber, 0, message, severity, errorCode);
    }
    
    /**
     * Find the text range of a variable declaration in the PSI tree.
     */
    @Nullable
    private TextRange findVariableDeclarationRange(PsiFile file, String varName, Document document) {
        // Use a visitor to find LOCAL declarations
        final TextRange[] result = {null};
        final int[] localDeclCount = {0};
        
        HarbourLogger.log("HarbourLinter", "Starting search for variable: " + varName);
        
        file.accept(new PsiRecursiveElementVisitor() {
            @Override
            public void visitElement(@NotNull PsiElement element) {
                if (result[0] != null) {
                    return; // Already found
                }
                
                ASTNode node = element.getNode();
                if (node != null) {
                    IElementType elementType = node.getElementType();
                    if (elementType == HarbourTypes.LOCAL_DECLARATION) {
                        localDeclCount[0]++;
                        HarbourLogger.log("HarbourLinter", "Found LOCAL_DECLARATION #" + localDeclCount[0] + 
                            " at line " + document.getLineNumber(element.getTextOffset()) + 
                            ": " + element.getText().replace("\n", " "));
                        // Found a LOCAL declaration, search for the variable name in its children
                        visitLocalDeclaration(element, varName, result);
                    }
                }
                
                super.visitElement(element);
            }
        });
        
        if (result[0] == null) {
            HarbourLogger.log("HarbourLinter", "PSI search failed for variable: " + varName + 
                " (searched " + localDeclCount[0] + " LOCAL declarations). Trying text search...");
            // Fallback to text search when PSI tree is incomplete (e.g., due to syntax errors)
            result[0] = findVariableByTextSearch(document, varName);
        }
        
        return result[0];
    }
    
    private void visitLocalDeclaration(PsiElement localDecl, String varName, TextRange[] result) {
        final int[] identCount = {0};
        // Look through all IDENT tokens in this LOCAL declaration
        localDecl.accept(new PsiRecursiveElementVisitor() {
            @Override
            public void visitElement(@NotNull PsiElement element) {
                ASTNode node = element.getNode();
                if (node != null && node.getElementType().toString().equals("IDENT")) {
                    identCount[0]++;
                    String identName = element.getText();
                    HarbourLogger.log("HarbourLinter", "  Found IDENT #" + identCount[0] + ": '" + identName + 
                        "' (looking for '" + varName + "')");
                    
                    if (identName != null && identName.equalsIgnoreCase(varName)) {
                        // Check if this IDENT is actually a variable declaration (not an expression)
                        PsiElement parent = element.getParent();
                        if (parent != null && parent.getNode() != null) {
                            IElementType parentType = parent.getNode().getElementType();
                            HarbourLogger.log("HarbourLinter", "    Parent type: " + parentType + 
                                " (expected: " + HarbourTypes.LOCAL_VAR + ")");
                            if (parentType == HarbourTypes.LOCAL_VAR) {
                                // Found the variable declaration
                                result[0] = element.getTextRange();
                                HarbourLogger.log("HarbourLinter", "Found variable '" + varName + "' at offset " + 
                                    result[0].getStartOffset() + "-" + result[0].getEndOffset());
                                return;
                            }
                        }
                    }
                }
                super.visitElement(element);
            }
        });
        
        if (result[0] == null) {
            HarbourLogger.log("HarbourLinter", "  Variable '" + varName + "' not found in this LOCAL declaration" +
                " (checked " + identCount[0] + " identifiers)");
        }
    }
    
    /**
     * Fallback method to find variable declaration by text search when PSI tree is incomplete.
     */
    @Nullable
    private TextRange findVariableByTextSearch(Document document, String varName) {
        String text = document.getText();
        String[] lines = text.split("\n");
        int currentOffset = 0;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmedLine = line.trim().toUpperCase();
            
            // Check if this is a LOCAL declaration line
            if (trimmedLine.startsWith("LOCAL ")) {
                // Search for the variable name in this line
                String lineForSearch = line.substring(line.toUpperCase().indexOf("LOCAL") + 5);
                
                // Split by comma to handle multiple variable declarations
                String[] vars = lineForSearch.split(",");
                for (String var : vars) {
                    // Extract just the variable name (before any assignment or array declaration)
                    String varDecl = var.trim();
                    String varNameOnly = varDecl.split("[\\s\\[\\(:=]")[0];
                    
                    if (varNameOnly.equalsIgnoreCase(varName)) {
                        // Found the variable - calculate its offset in the line
                        int varStartInLine = line.toUpperCase().indexOf(varNameOnly.toUpperCase());
                        if (varStartInLine >= 0) {
                            int startOffset = currentOffset + varStartInLine;
                            int endOffset = startOffset + varNameOnly.length();
                            HarbourLogger.log("HarbourLinter", "Found variable '" + varName + 
                                "' by text search at line " + i + ", offset " + startOffset + "-" + endOffset);
                            return new TextRange(startOffset, endOffset);
                        }
                    }
                }
            }
            
            currentOffset += line.length() + 1; // +1 for newline
        }
        
        HarbourLogger.log("HarbourLinter", "Text search also failed to find variable: " + varName);
        return null;
    }
}
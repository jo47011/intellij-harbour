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
import com.intellij.notification.Notification;
import com.intellij.notification.NotificationAction;
import com.intellij.notification.NotificationGroupManager;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.options.ShowSettingsUtil;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import com.intellij.psi.PsiRecursiveElementVisitor;
import org.intellij.sdk.language.psi.HarbourTypes;
import java.util.Map;
import java.util.HashMap;
import java.util.Set;
import java.util.HashSet;
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
        long timestamp; // When this cache entry was created
        List<HarbourLintResult> results;
        
        LintCache(String filePath, long modificationStamp, List<HarbourLintResult> results) {
            this.filePath = filePath;
            this.modificationStamp = modificationStamp;
            this.timestamp = System.currentTimeMillis();
            this.results = results;
        }
    }
    
    private static final Map<String, LintCache> cache = new ConcurrentHashMap<>();
    private static final Map<String, Long> lastLintTime = new ConcurrentHashMap<>();
    private static final long DEBOUNCE_DELAY_MS = 3000; // 3 second debounce for better performance
    private static final int MAX_FILE_SIZE_FOR_REALTIME = 100000; // 100KB limit for real-time linting
    
    // Track files that have shown missing include notification
    private static final Set<String> notifiedMissingIncludes = new HashSet<>();
    
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
    
    /**
     * Perform quick syntax checks for common errors without running the full compiler
     * This provides immediate feedback while typing
     */
    private static List<HarbourLintResult> quickSyntaxCheck(String content, String filePath) {
        List<HarbourLintResult> results = new ArrayList<>();
        if (content == null) return results;
        
        String[] lines = content.split("\n");
        
        // Patterns for common syntax errors
        Pattern unmatchedQuoteInLine = Pattern.compile("\\b\\w+\\s*\\(\\s*\"[^\"\\n)]*$");
        Pattern unmatchedParenPattern = Pattern.compile("\\b\\w+\\s*\\([^)]*$");
        Pattern localWithSlash = Pattern.compile("\\bLOCAL\\s+\\w+\\s*/");
        Pattern incompleteFunction = Pattern.compile("\\b\\w+\\s*\\([^)]*(?:\\w+)\\s*$");
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmedLine = line.trim();
            
            // Skip comments and empty lines
            if (trimmedLine.isEmpty() || trimmedLine.startsWith("//") || 
                trimmedLine.startsWith("*") || trimmedLine.startsWith("/*")) continue;
            
            // Skip lines that end with semicolon (line continuation in Harbour)
            if (trimmedLine.endsWith(";")) continue;
            
            // Check for LOCAL with trailing slash (like "LOCAL gaga /")
            if (localWithSlash.matcher(line).find()) {
                results.add(new HarbourLintResult(
                    i + 1,
                    0,
                    "Syntax error: Invalid character '/' after LOCAL declaration",
                    HighlightSeverity.ERROR,
                    "E0030"
                ));
            }
            
            // Check if previous line ends with semicolon (line continuation)
            boolean isPreviousLineContinued = i > 0 && lines[i - 1].trim().endsWith(";");
            
            // Check if current line might be continued on next line
            boolean mightContinue = i + 1 < lines.length && 
                                    (line.endsWith(",") || line.endsWith("(") || 
                                     line.endsWith("+") || line.endsWith("-") ||
                                     (i + 1 < lines.length && lines[i + 1].trim().startsWith("+")));
            
            // Check for unmatched quotes (like qout("bla or qout(asdfasd)
            // Skip if this is part of a continued statement
            if (!isPreviousLineContinued && !mightContinue &&
                (unmatchedQuoteInLine.matcher(line).find() || 
                (line.contains("(") && line.matches(".*\\([^\"'\\)]*[a-zA-Z]+[^\"'\\)]*(?:\\s*$|\\s*//)")))) {
                results.add(new HarbourLintResult(
                    i + 1,
                    0,
                    "Syntax error: Unmatched quote or missing quotes in function call",
                    HighlightSeverity.ERROR,
                    "E0020"
                ));
            }
            
            // Check for unmatched parentheses
            // Skip if this is part of a continued statement
            if (!isPreviousLineContinued && !mightContinue &&
                unmatchedParenPattern.matcher(line).find() && !line.contains(")")) {
                results.add(new HarbourLintResult(
                    i + 1,
                    0,
                    "Syntax error: Unmatched parenthesis",
                    HighlightSeverity.ERROR,
                    "E0020"
                ));
            }
            
            // Check for if without parentheses (like "If oo")
            // Skip if this is part of a continued statement
            if (!isPreviousLineContinued && line.matches(".*\\b[Ii][Ff]\\s+\\w+\\s*$")) {
                results.add(new HarbourLintResult(
                    i + 1,
                    0,
                    "Syntax error: 'if' statement missing parentheses",
                    HighlightSeverity.ERROR,
                    "E0030"
                ));
            }
            
            // Check for qout with unquoted string
            // Skip if this is part of a continued statement
            if (!isPreviousLineContinued && !mightContinue &&
                line.matches(".*\\bqout\\s*\\(\\s*[a-zA-Z]+.*") && 
                !line.matches(".*\\bqout\\s*\\(\\s*[\"'].*")) {
                results.add(new HarbourLintResult(
                    i + 1,
                    0,
                    "Syntax error: qout() requires quoted string",
                    HighlightSeverity.ERROR,
                    "E0030"
                ));
            }
        }
        
        // Basic unused variable detection
        // First, collect all LOCAL variable declarations
        Map<String, Integer> localVars = new HashMap<>();
        Pattern localPattern = Pattern.compile("\\bLOCAL\\s+([\\w,\\s]+)");
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();
            if (line.startsWith("//") || line.startsWith("*")) continue;
            
            Matcher localMatcher = localPattern.matcher(line);
            if (localMatcher.find()) {
                String varList = localMatcher.group(1);
                // Split by comma and trim each variable name
                String[] vars = varList.split(",");
                for (String var : vars) {
                    String varName = var.trim();
                    if (!varName.isEmpty()) {
                        localVars.put(varName, i + 1); // Store line number
                    }
                }
            }
        }
        
        // Now check if variables are used
        for (Map.Entry<String, Integer> entry : localVars.entrySet()) {
            String varName = entry.getKey();
            int declarationLine = entry.getValue();
            boolean isUsed = false;
            
            // Check all lines after declaration for usage
            for (int i = 0; i < lines.length; i++) {
                if (i + 1 == declarationLine) continue; // Skip declaration line
                String line = lines[i];
                
                // Skip comments
                if (line.trim().startsWith("//") || line.trim().startsWith("*")) continue;
                
                // Check if variable is used (simple word boundary check)
                if (line.matches(".*\\b" + Pattern.quote(varName) + "\\b.*")) {
                    isUsed = true;
                    break;
                }
            }
            
            if (!isUsed) {
                results.add(new HarbourLintResult(
                    declarationLine,
                    0,
                    "Warning: Unused local variable '" + varName + "'",
                    HighlightSeverity.WARNING,
                    "W0001"
                ));
            }
        }
        
        return results;
    }
    
    /**
     * Show notification about missing include files
     */
    private void showMissingIncludesNotification(Project project, Set<String> missingFiles, String currentFile) {
        ApplicationManager.getApplication().invokeLater(() -> {
            StringBuilder message = new StringBuilder();
            message.append("Missing include files detected in ")
                   .append(new File(currentFile).getName())
                   .append(":\n\n");
            
            for (String file : missingFiles) {
                message.append("• ").append(file).append("\n");
            }
            
            message.append("\nLinting will continue with available syntax checks.");
            
            Notification notification = NotificationGroupManager.getInstance()
                .getNotificationGroup("Harbour Application")
                .createNotification(
                    "Missing Include Files",
                    message.toString(),
                    NotificationType.WARNING
                );
            
            // Add action to open settings
            notification.addAction(new NotificationAction("Configure Include Paths") {
                @Override
                public void actionPerformed(@NotNull AnActionEvent e, @NotNull Notification notification) {
                    ShowSettingsUtil.getInstance().showSettingsDialog(project, "Harbour");
                    notification.expire();
                }
            });
            
            notification.notify(project);
        });
    }
    
    // Method kept but not used anymore - can be removed later
    private List<HarbourLintResult> runWithCommentedIncludes(
            HarbourLintInfo info, Set<String> missingFiles, List<String> originalCommand) 
            throws IOException, InterruptedException {
        
        // Read original file
        String originalContent = new String(Files.readAllBytes(Paths.get(info.getFilePath())), 
            StandardCharsets.UTF_8);
        
        // Create modified content with problematic includes commented
        String modifiedContent = commentOutIncludes(originalContent, missingFiles);
        
        // Create temporary file
        File tempFile = File.createTempFile("harbour_lint_", ".prg");
        tempFile.deleteOnExit();
        
        try {
            // Write modified content
            Files.write(tempFile.toPath(), modifiedContent.getBytes(StandardCharsets.UTF_8));
            
            // Build new command with temp file
            List<String> command = new ArrayList<>(originalCommand);
            command.set(1, tempFile.getAbsolutePath()); // Replace file path
            
            HarbourLogger.log("HarbourLinter", "Running with temp file: " + tempFile.getAbsolutePath());
            
            // Run compiler
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.redirectErrorStream(true);
            Process process = pb.start();
            
            List<String> outputLines = new ArrayList<>();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    outputLines.add(line);
                }
            }
            
            boolean finished = process.waitFor(30, java.util.concurrent.TimeUnit.SECONDS);
            if (!finished) {
                process.destroyForcibly();
                return new ArrayList<>();
            }
            
            // Parse results and adjust line numbers back to original file
            List<HarbourLintResult> results = new ArrayList<>();
            for (String line : outputLines) {
                HarbourLintResult result = parseErrorLine(line, info.getFilePath());
                if (result != null && !result.getMessage().contains("Can't open #include file")) {
                    results.add(result);
                }
            }
            
            return results;
            
        } finally {
            // Clean up temp file
            if (tempFile.exists()) {
                tempFile.delete();
            }
        }
    }
    
    private String commentOutIncludes(String content, Set<String> missingFiles) {
        String[] lines = content.split("\n");
        StringBuilder modified = new StringBuilder();
        
        for (String line : lines) {
            String trimmed = line.trim();
            boolean shouldComment = false;
            
            // Check if this line includes any of the missing files
            if (trimmed.startsWith("#include")) {
                for (String missingFile : missingFiles) {
                    if (line.contains(missingFile)) {
                        shouldComment = true;
                        break;
                    }
                }
            }
            
            if (shouldComment) {
                modified.append("// LINTING: Commented out missing include - ").append(line).append("\n");
            } else {
                modified.append(line).append("\n");
            }
        }
        
        return modified.toString();
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
        
        // Determine if we should lint this file
        long currentTime = System.currentTimeMillis();
        boolean isSaveTriggered = lastLintTime.containsKey(filePath + "_save_triggered");
        String fileContent = file.getText();
        boolean hasObviousSyntaxError = containsObviousSyntaxError(fileContent);
        
        // Log the detection results
        if (hasObviousSyntaxError) {
            HarbourLogger.log("HarbourLinter", "Detected obvious syntax errors in file");
        }
        
        // Check if save-only mode is enabled
        if (settings.isLintOnSave()) {
            // In save-only mode, we lint if:
            // 1. Save was triggered
            // 2. File has obvious syntax errors (override save-only for critical errors)
            if (!isSaveTriggered && !hasObviousSyntaxError) {
                HarbourLogger.log("HarbourLinter", "Skipping - save-only mode, no save trigger, no obvious errors");
                return null;
            }
            
            if (hasObviousSyntaxError) {
                HarbourLogger.log("HarbourLinter", "Proceeding - obvious syntax errors detected, overriding save-only mode");
            } else {
                HarbourLogger.log("HarbourLinter", "Proceeding - save triggered");
            }
        }
        
        // Debounce - but be smarter about it
        Long lastTime = lastLintTime.get(filePath);
        if (lastTime != null && (currentTime - lastTime) < DEBOUNCE_DELAY_MS) {
            // During debounce, check if we should still proceed:
            // 1. Save was triggered - always proceed
            // 2. File has obvious errors - always proceed  
            // 3. File modification stamp changed - proceed
            long modificationStamp = virtualFile.getModificationStamp();
            LintCache cached = cache.get(filePath);
            boolean fileChanged = cached == null || cached.modificationStamp != modificationStamp;
            
            if (!isSaveTriggered && !hasObviousSyntaxError && !fileChanged) {
                HarbourLogger.log("HarbourLinter", "Skipping due to debounce - no changes detected");
                if (cached != null) {
                    HarbourLogger.log("HarbourLinter", "Returning cached results during debounce");
                    return new HarbourLintInfo(filePath, "CACHED", 
                        project,
                        settings.getHarbourCompilerPath(),
                        settings.getIncludePaths(),
                        settings.getLintExtraOptions(),
                        settings.getLintWarningLevel()
                    );
                }
                return null;
            }
            
            HarbourLogger.log("HarbourLinter", "Overriding debounce - important changes detected");
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

        // Check file size for performance
        long fileSize = virtualFile.getLength();
        if (fileSize > MAX_FILE_SIZE_FOR_REALTIME) {
            HarbourLogger.log("HarbourLinter", "File too large for real-time linting: " + fileSize + " bytes (limit: " + MAX_FILE_SIZE_FOR_REALTIME + " bytes)");
            
            // For large files, do full linting if:
            // 1. Save was triggered
            // 2. File has obvious syntax errors
            // Otherwise, only do quick syntax check
            if (!isSaveTriggered && !hasObviousSyntaxError) {
                HarbourLogger.log("HarbourLinter", "Large file: using quick syntax check only");
                return new HarbourLintInfo(
                    filePath,
                    "QUICK_CHECK:" + fileContent,
                    project,
                    compilerPath,
                    settings.getIncludePaths(),
                    settings.getLintExtraOptions(),
                    settings.getLintWarningLevel()
                );
            } else {
                HarbourLogger.log("HarbourLinter", "Large file but important lint needed: doing full lint");
            }
        }

        // Check cache - but be more careful about when to use it
        long modificationStamp = virtualFile.getModificationStamp();
        LintCache cached = cache.get(filePath);
        
        // Only use cache if:
        // 1. Cache exists and modification stamp matches
        // 2. We're not in an explicit save/lint request
        // 3. The cached results are recent (within 30 seconds)
        boolean canUseCache = false;
        if (cached != null && cached.modificationStamp == modificationStamp) {
            long cacheAge = System.currentTimeMillis() - cached.timestamp;
            boolean isExplicitRequest = lastLintTime.containsKey(filePath + "_save_triggered");
            
            if (!isExplicitRequest && cacheAge < 1000) { // 1 second cache expiry (reduced from 5s) - minimal caching
                canUseCache = true;
                HarbourLogger.log("HarbourLinter", "Using cached results for: " + file.getName() + 
                    " (cache age: " + (cacheAge/1000) + "s, modStamp match: true)");
            } else {
                HarbourLogger.log("HarbourLinter", "Cache invalid: explicit=" + isExplicitRequest + 
                    ", age=" + (cacheAge/1000) + "s, clearing cache");
                cache.remove(filePath); // Clear stale cache
            }
        } else if (cached != null) {
            HarbourLogger.log("HarbourLinter", "Cache invalid: modStamp mismatch (cached=" + 
                cached.modificationStamp + ", current=" + modificationStamp + ")");
            cache.remove(filePath); // Clear invalid cache
        }
        
        if (canUseCache) {
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
        
        // For better performance, alternate between quick checks and full compilation
        // Do quick check more frequently, full compilation less frequently
        boolean doQuickCheckOnly = false;
        Long lastFullCheck = lastLintTime.get(filePath + "_full");
        if (lastFullCheck != null && (System.currentTimeMillis() - lastFullCheck) < 10000) {
            // If we did a full check within 10 seconds, just do a quick check
            doQuickCheckOnly = true;
            HarbourLogger.log("HarbourLinter", "Doing quick syntax check only for performance");
        }
        
        lastLintTime.put(filePath, System.currentTimeMillis());
        if (!doQuickCheckOnly) {
            lastLintTime.put(filePath + "_full", System.currentTimeMillis());
        }

        return new HarbourLintInfo(
            filePath,
            doQuickCheckOnly ? "QUICK_CHECK:" + file.getText() : file.getText(),
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
        
        // Progress bar removed per user feedback - linting is now quick enough
        
        // Check if we should use cached results
        if ("CACHED".equals(info.getFileContent())) {
            LintCache cached = cache.get(info.getFilePath());
            // Progress bar removed - no need to clear
            return cached != null ? cached.results : null;
        }
        
        // DISABLED: Quick syntax check removed as it causes false positives
        // The Harbour compiler is fast enough and more accurate
        // User feedback: "do we still need the quick syntax checker?"
        // Answer: No, it causes more problems than benefits
        /*
        if (info.getFileContent() != null && info.getFileContent().startsWith("QUICK_CHECK:")) {
            // Quick syntax check disabled - return empty results
            return new ArrayList<>();
        }
        */

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
            command.add("-q");   // Quiet mode (suppress progress output)
            
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
            
            // Log file details to debug E0030 "syntax error at '}'" issues
            try {
                File sourceFile = new File(info.getFilePath());
                if (sourceFile.exists()) {
                    List<String> lines = Files.readAllLines(sourceFile.toPath(), StandardCharsets.UTF_8);
                    HarbourLogger.log("HarbourLinter", "File has " + lines.size() + " lines, size: " + sourceFile.length() + " bytes");
                    // Log last 3 lines to see if there's something wrong at the end
                    if (lines.size() > 0) {
                        int startLine = Math.max(0, lines.size() - 3);
                        HarbourLogger.log("HarbourLinter", "Last " + (lines.size() - startLine) + " lines:");
                        for (int i = startLine; i < lines.size(); i++) {
                            String line = lines.get(i);
                            HarbourLogger.log("HarbourLinter", "  L" + (i + 1) + ": [" + line + "] (len=" + line.length() + ")");
                            // Check for code blocks on this line
                            if (line.contains("{ ||")) {
                                HarbourLogger.log("HarbourLinter", "    ^ Contains code block");
                            }
                        }
                    }
                }
            } catch (Exception logEx) {
                HarbourLogger.log("HarbourLinter", "Could not log file details: " + logEx.getMessage());
            }
            
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
                    } else if (line.contains(".prg(") || line.contains(".ch(")) {
                        // Log lines that look like they might be errors but didn't parse
                        HarbourLogger.log("HarbourLinter", "POTENTIAL ERROR LINE not parsed: " + line);
                    }
                }
                
                HarbourLogger.log("HarbourLinter", "=== LINTING SUMMARY ===");
                HarbourLogger.log("HarbourLinter", "Exit code: " + exitCode);
                HarbourLogger.log("HarbourLinter", "Total issues found: " + results.size());
                HarbourLogger.log("HarbourLinter", "Lines parsed successfully: " + parsedCount);
                
                // Check if we found any include file errors
                boolean hasIncludeErrors = results.stream()
                    .anyMatch(r -> r.getMessage().contains("Can't open #include file"));
                    
                if (hasIncludeErrors) {
                    HarbourLogger.log("HarbourLinter", "Include file errors found");
                    
                    // Log include errors to console for visibility
                    Set<String> missingFiles = new HashSet<>();
                    List<HarbourLintResult> enhancedResults = new ArrayList<>();
                    
                    for (HarbourLintResult result : results) {
                        if (result.getMessage().contains("Can't open #include file")) {
                            // Extract missing file name
                            String msg = result.getMessage();
                            int start = msg.indexOf("'");
                            int end = msg.lastIndexOf("'");
                            if (start >= 0 && end > start) {
                                String missingFile = msg.substring(start + 1, end);
                                missingFiles.add(missingFile);
                            }
                            
                            // Create new result with enhanced message
                            String enhancedMsg = result.getMessage() + " (This may be included indirectly - check your #include statements)";
                            HarbourLintResult enhanced = new HarbourLintResult(
                                result.getLine(),
                                result.getColumn(),
                                enhancedMsg,
                                result.getSeverity(),
                                result.getErrorCode()
                            );
                            enhanced.setTextRange(result.getTextRange());
                            enhancedResults.add(enhanced);
                        } else {
                            enhancedResults.add(result);
                        }
                    }
                    results = enhancedResults;
                    
                    // Log to console for visibility
                    if (!missingFiles.isEmpty()) {
                        HarbourLogger.warning("HarbourLinter", 
                            "=== MISSING INCLUDE FILES ===");
                        for (String file : missingFiles) {
                            HarbourLogger.warning("HarbourLinter", 
                                "Missing: " + file + " (may be included indirectly)");
                        }
                        
                        // Show notification popup once per file opening (not per lint)
                        String fileKey = info.getFilePath();
                        if (!notifiedMissingIncludes.contains(fileKey)) {
                            notifiedMissingIncludes.add(fileKey);
                            showMissingIncludesNotification(info.getProject(), missingFiles, info.getFilePath());
                        }
                    }
                    
                    // REMOVED: quick syntax check to prevent flicker
                    // The compiler already gave us the include errors
                    // No need to run additional linting that causes flicker
                }
                
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
                
                // Clear save trigger flag if it was a save-triggered lint
                if (lastLintTime.containsKey(info.getFilePath() + "_save_triggered")) {
                    lastLintTime.remove(info.getFilePath() + "_save_triggered");
                    HarbourLogger.log("HarbourLinter", "Cleared save trigger flag for: " + info.getFilePath());
                }
                
                // Clear notification flag if we had a successful lint with no missing includes
                boolean hasMissingIncludes = results.stream()
                    .anyMatch(r -> r.getMessage().contains("Can't open #include file"));
                if (!hasMissingIncludes && notifiedMissingIncludes.contains(info.getFilePath())) {
                    notifiedMissingIncludes.remove(info.getFilePath());
                    HarbourLogger.log("HarbourLinter", "Cleared missing include notification flag for: " + info.getFilePath());
                }
            }
            
        } catch (Exception e) {
            LOG.error("Error running Harbour linter", e);
            HarbourLogger.log("HarbourLinter", "Error: " + e.getMessage());
        } finally {
            // Progress bar removed - nothing to clear
        }
        
        return results.isEmpty() ? null : results;
    }

    @Override
    public void apply(@NotNull PsiFile file, List<HarbourLintResult> annotationResult, @NotNull AnnotationHolder holder) {
        if (annotationResult == null || annotationResult.isEmpty()) {
            HarbourLogger.log("HarbourLinter", "apply() called with no results for: " + file.getName());
            return;
        }
        
        HarbourLogger.log("HarbourLinter", "apply() called with " + annotationResult.size() + " results for: " + file.getName());

        Document document = PsiDocumentManager.getInstance(file.getProject()).getDocument(file);
        if (document == null) {
            return;
        }
        
        // Get the exclusion comment from settings
        HarbourSettings settings = HarbourSettings.getInstance(file.getProject());
        String exclusionComment = settings.getLinterExclusionComment();
        if (exclusionComment == null || exclusionComment.isEmpty()) {
            exclusionComment = "noqa"; // Default
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
                
                // Check for line continuations (semicolon at end of previous lines)
                // The compiler may report errors on the wrong line when using semicolons
                // Look for the actual error location in multi-line statements
                int actualLine = line;
                
                // Try to extract identifier from various error messages
                String identifier = null;
                if (message != null) {
                    // Try different patterns to extract identifier
                    Pattern[] patterns = {
                        Pattern.compile("'([^']+)'"),                    // Most common: 'IDENTIFIER'
                        Pattern.compile("\"([^\"]+)\""),                 // Sometimes: "IDENTIFIER"
                        Pattern.compile("\\b([A-Z_][A-Z0-9_]*)\\b")     // Fallback: uppercase identifier
                    };
                    
                    for (Pattern pattern : patterns) {
                        Matcher matcher = pattern.matcher(message);
                        if (matcher.find()) {
                            identifier = matcher.group(1);
                            break;
                        }
                    }
                }
                
                // If we found an identifier, search for it in previous lines with continuations
                if (identifier != null) {
                    // Check if previous lines end with semicolon (line continuation)
                    int checkLine = line;
                    boolean inContinuation = false;
                    
                    // First check if current line is part of a continuation
                    while (checkLine > 0) {
                        checkLine--;
                        String prevLineText = document.getText(new TextRange(
                            document.getLineStartOffset(checkLine),
                            document.getLineEndOffset(checkLine)
                        )).trim();
                        
                        // Skip empty lines and comments
                        if (prevLineText.isEmpty() || prevLineText.startsWith("//") || prevLineText.startsWith("*")) {
                            continue;
                        }
                        
                        // Check if this line contains the identifier
                        if (prevLineText.toUpperCase().contains(identifier.toUpperCase())) {
                            actualLine = checkLine;
                            HarbourLogger.log("HarbourLinter", 
                                "Found actual error location at line " + (actualLine + 1) + " for: " + identifier);
                            break;
                        }
                        
                        // If this line doesn't end with semicolon, we're not in a continuation anymore
                        if (!prevLineText.endsWith(";")) {
                            break;
                        }
                        
                        inContinuation = true;
                    }
                    
                    // If we didn't find it in previous lines, check following lines if current line ends with ;
                    if (actualLine == line && line < document.getLineCount() - 1) {
                        String currentLineText = document.getText(new TextRange(
                            document.getLineStartOffset(line),
                            document.getLineEndOffset(line)
                        )).trim();
                        
                        if (currentLineText.endsWith(";")) {
                            checkLine = line;
                            while (checkLine < document.getLineCount() - 1) {
                                checkLine++;
                                String nextLineText = document.getText(new TextRange(
                                    document.getLineStartOffset(checkLine),
                                    document.getLineEndOffset(checkLine)
                                )).trim();
                                
                                // Check if this line contains the identifier
                                if (nextLineText.toUpperCase().contains(identifier.toUpperCase())) {
                                    actualLine = checkLine;
                                    HarbourLogger.log("HarbourLinter", 
                                        "Found actual error location at line " + (actualLine + 1) + " for: " + identifier);
                                    break;
                                }
                                
                                // Stop if we reach a line that doesn't look like a continuation
                                if (!nextLineText.isEmpty() && !nextLineText.startsWith("//") && 
                                    !nextLineText.startsWith("*") && !nextLineText.startsWith("+") &&
                                    !nextLineText.startsWith("-") && !nextLineText.startsWith("/") &&
                                    !nextLineText.startsWith(".")) {
                                    // Check if previous line ended with semicolon
                                    if (checkLine > line + 1) {
                                        String prevLine = document.getText(new TextRange(
                                            document.getLineStartOffset(checkLine - 1),
                                            document.getLineEndOffset(checkLine - 1)
                                        )).trim();
                                        if (!prevLine.endsWith(";")) {
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                int lineStartOffset = document.getLineStartOffset(actualLine);
                int lineEndOffset = document.getLineEndOffset(actualLine);
                
                // Create text range for the entire line
                range = new TextRange(lineStartOffset, lineEndOffset);
                
                // Trim whitespace from the line to get the actual code range
                String lineText = document.getText(range);
                
                // Check if this line should be excluded from linting (check the actual line being highlighted)
                boolean shouldExclude = false;
                
                // Check for // style comments
                int singleLineComment = lineText.indexOf("//");
                if (singleLineComment != -1) {
                    String commentText = lineText.substring(singleLineComment + 2).trim();
                    if (commentText.startsWith(exclusionComment)) {
                        shouldExclude = true;
                    }
                }
                
                // Check for /* style comments
                if (!shouldExclude) {
                    int multiLineComment = lineText.indexOf("/*");
                    if (multiLineComment != -1) {
                        String commentText = lineText.substring(multiLineComment + 2).trim();
                        if (commentText.startsWith(exclusionComment)) {
                            shouldExclude = true;
                        }
                    }
                }
                
                if (shouldExclude) {
                    HarbourLogger.log("HarbourLinter", "Skipping line " + (actualLine + 1) + 
                        " due to exclusion comment: " + exclusionComment);
                    continue; // Skip this error/warning
                }
                
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
        
        // Note: We show ALL errors, including those from include files
        // This is important because include file errors prevent compilation
        HarbourLogger.log("HarbourLinter", "Processing error from: " + filePath);

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
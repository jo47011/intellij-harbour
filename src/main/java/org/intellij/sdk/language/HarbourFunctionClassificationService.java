package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import org.jetbrains.annotations.NotNull;

import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Service for classifying Harbour functions as internal (declared in project) or external.
 * This service scans the project once at startup to build a registry of internal functions,
 * procedures, and classes. Any function call that is not in this registry is considered external.
 */
@Service(Service.Level.PROJECT)
public final class HarbourFunctionClassificationService {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionClassificationService.class);

    // Set of internal function names (lowercase) found in the project
    private final Set<String> internalFunctions = ConcurrentHashMap.newKeySet();
    
    // Set of internal procedure names (lowercase) found in the project  
    private final Set<String> internalProcedures = ConcurrentHashMap.newKeySet();
    
    // Set of internal class names (lowercase) found in the project
    private final Set<String> internalClasses = ConcurrentHashMap.newKeySet();
    
    // Set of internal method names (lowercase) found in the project
    private final Set<String> internalMethods = ConcurrentHashMap.newKeySet();

    // Flag to track if initial scan is complete
    private volatile boolean initialized = false;
    
    // Flag to track if scanning is in progress
    private volatile boolean scanning = false;
    
    
    // Progress tracking
    private volatile int totalFiles = 0;
    private volatile int processedFiles = 0;

    // Project instance
    private final Project project;

    // Patterns for detecting function declarations
    private static final Pattern FUNCTION_PATTERN = Pattern.compile(
            "(?i)\\bFUNCTION\\s+(\\w+)(?:\\s*\\()?", Pattern.CASE_INSENSITIVE);
    private static final Pattern PROCEDURE_PATTERN = Pattern.compile(
            "(?i)\\bPROCEDURE\\s+(\\w+)(?:\\s*\\()?", Pattern.CASE_INSENSITIVE);
    private static final Pattern CLASS_PATTERN = Pattern.compile(
            "(?i)\\bCLASS\\s+(\\w+)\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern METHOD_PATTERN = Pattern.compile(
            "(?i)\\bMETHOD\\s+(\\w+)(?:\\s*\\()?", Pattern.CASE_INSENSITIVE);
    
    // Common Harbour standard functions that are always external
    private static final Set<String> KNOWN_EXTERNAL_FUNCTIONS = Set.of(
            "chr", "asc", "len", "substr", "str", "val", "upper", "lower",
            "alltrim", "ltrim", "rtrim", "space", "replicate", "transform",
            "date", "time", "dtoc", "ctod", "dtos", "year", "month", "day",
            "at", "rat", "left", "right", "stuff", "padr", "padl", "padc",
            "iif", "if", "empty", "eof", "bof", "recno", "lastrec", "fcount",
            "fieldname", "fieldget", "fieldput", "dbf", "alias", "select",
            "use", "close", "append", "delete", "recall", "pack", "zap",
            "seek", "found", "skip", "goto", "gotop", "gobottom",
            "index", "reindex", "set", "get", "readmodal", "clear",
            "qout", "qqout", "devpos", "devout", "setpos", "row", "col",
            "inkey", "lastkey", "readkey", "tone", "alert", "msginfo",
            "file", "ferase", "frename", "fcreate", "fopen", "fclose",
            "fread", "fwrite", "fseek", "ferror", "directory", "adir",
            "type", "valtype", "array", "aadd", "adel", "ains", "asort",
            "ascan", "asize", "aclone", "afill", "acopy", "eval", "fieldblock",
            "memvar", "public", "private", "parameters", "pcount", "procname",
            "procline", "errorblock", "break", "errorlevel", "altd",
            "round", "abs", "int", "sqrt", "exp", "log", "sin", "cos", "tan",
            "asin", "acos", "atan", "min", "max", "mod", "pow"
    );

    /**
     * Get the instance of the service for the given project.
     */
    public static HarbourFunctionClassificationService getInstance(Project project) {
        return project.getService(HarbourFunctionClassificationService.class);
    }

    /**
     * Constructor
     */
    public HarbourFunctionClassificationService(Project project) {
        this.project = project;
    }

    /**
     * Check if a function is internal (declared in the project).
     * 
     * @param functionName The function name to check
     * @return true if the function is declared in the project, false otherwise
     */
    public boolean isInternalFunction(@NotNull String functionName) {
        String normalizedName = functionName.toLowerCase();
        
        // Quick check for known external functions
        if (KNOWN_EXTERNAL_FUNCTIONS.contains(normalizedName)) {
            return false;
        }
        
        if (!initialized && !scanning) {
            // If not initialized yet, trigger initialization
            initializeWithProgress();
            // Return true (internal) as default during initialization
            // This prevents the "all functions light blue" issue during startup
            return !KNOWN_EXTERNAL_FUNCTIONS.contains(normalizedName);
        }
        
        if (!initialized) {
            // Still scanning - for known external functions return false, otherwise true
            // This prevents flickering and ensures better UX during startup
            return !KNOWN_EXTERNAL_FUNCTIONS.contains(normalizedName);
        }
        
        return internalFunctions.contains(normalizedName) || 
               internalProcedures.contains(normalizedName) ||
               internalClasses.contains(normalizedName) ||
               internalMethods.contains(normalizedName);
    }

    /**
     * Check if a function is external (not declared in the project).
     * 
     * @param functionName The function name to check
     * @return true if the function is not declared in the project, false otherwise
     */
    public boolean isExternalFunction(@NotNull String functionName) {
        return !isInternalFunction(functionName);
    }

    /**
     * Get all internal function names.
     * 
     * @return Set of all internal function names
     */
    public Set<String> getAllInternalFunctions() {
        Set<String> allInternal = ConcurrentHashMap.newKeySet();
        allInternal.addAll(internalFunctions);
        allInternal.addAll(internalProcedures);
        allInternal.addAll(internalClasses);
        allInternal.addAll(internalMethods);
        return allInternal;
    }

    /**
     * Get count of internal functions found.
     * 
     * @return Total count of internal functions, procedures, and classes
     */
    public int getInternalFunctionCount() {
        return internalFunctions.size() + internalProcedures.size() + internalClasses.size();
    }

    /**
     * Check if the service is initialized.
     * 
     * @return true if the initial scan is complete
     */
    public boolean isInitialized() {
        return initialized;
    }
    
    /**
     * Check if the service is currently scanning.
     * 
     * @return true if scanning is in progress
     */
    public boolean isScanning() {
        return scanning;
    }

    /**
     * Add a function to the internal function registry.
     * 
     * @param functionName The function name to add
     */
    public void addInternalFunction(@NotNull String functionName) {
        String normalizedName = functionName.toLowerCase();
        internalFunctions.add(normalizedName);
        HarbourLogger.log("FunctionClassification", "Added internal function: " + functionName);
    }

    /**
     * Add a procedure to the internal procedure registry.
     * 
     * @param procedureName The procedure name to add
     */
    public void addInternalProcedure(@NotNull String procedureName) {
        String normalizedName = procedureName.toLowerCase();
        internalProcedures.add(normalizedName);
        HarbourLogger.log("FunctionClassification", "Added internal procedure: " + procedureName);
    }

    /**
     * Add a class to the internal class registry.
     * 
     * @param className The class name to add
     */
    public void addInternalClass(@NotNull String className) {
        String normalizedName = className.toLowerCase();
        internalClasses.add(normalizedName);
        HarbourLogger.log("FunctionClassification", "Added internal class: " + className);
    }

    /**
     * Add a method to the internal method registry.
     * 
     * @param methodName The method name to add
     */
    public void addInternalMethod(@NotNull String methodName) {
        String normalizedName = methodName.toLowerCase();
        internalMethods.add(normalizedName);
        HarbourLogger.log("FunctionClassification", "Added internal method: " + methodName);
    }

    /**
     * Remove a function from the internal function registry.
     * 
     * @param functionName The function name to remove
     */
    public void removeInternalFunction(@NotNull String functionName) {
        String normalizedName = functionName.toLowerCase();
        if (internalFunctions.remove(normalizedName)) {
            HarbourLogger.log("FunctionClassification", "Removed internal function: " + functionName);
        }
    }

    /**
     * Remove a procedure from the internal procedure registry.
     * 
     * @param procedureName The procedure name to remove
     */
    public void removeInternalProcedure(@NotNull String procedureName) {
        String normalizedName = procedureName.toLowerCase();
        if (internalProcedures.remove(normalizedName)) {
            HarbourLogger.log("FunctionClassification", "Removed internal procedure: " + procedureName);
        }
    }

    /**
     * Remove a class from the internal class registry.
     * 
     * @param className The class name to remove
     */
    public void removeInternalClass(@NotNull String className) {
        String normalizedName = className.toLowerCase();
        if (internalClasses.remove(normalizedName)) {
            HarbourLogger.log("FunctionClassification", "Removed internal class: " + className);
        }
    }

    /**
     * Remove a method from the internal method registry.
     * 
     * @param methodName The method name to remove
     */
    public void removeInternalMethod(@NotNull String methodName) {
        String normalizedName = methodName.toLowerCase();
        if (internalMethods.remove(normalizedName)) {
            HarbourLogger.log("FunctionClassification", "Removed internal method: " + methodName);
        }
    }

    /**
     * Scan a single file and update the internal function registries based on its current content.
     * This method compares the current file content with what was previously indexed and updates accordingly.
     * 
     * @param file The virtual file to scan
     */
    public void updateFileInternalFunctions(@NotNull VirtualFile file) {
        HarbourLogger.log("FunctionClassification", "Updating internal functions for file: " + file.getName());
        
        PsiFile psiFile = PsiManager.getInstance(project).findFile(file);
        if (psiFile == null) {
            return;
        }
        
        String fileContent = psiFile.getText();
        if (fileContent == null || fileContent.isEmpty()) {
            return;
        }
        
        // Store current functions from this file (we don't have a per-file tracking yet, 
        // so we'll just add new ones - this is simpler and follows KISS principle)
        
        // Extract and add new functions found in the file
        int functionsFound = findAndAddMatches(fileContent, FUNCTION_PATTERN, internalFunctions, "FUNCTION", file.getName());
        int proceduresFound = findAndAddMatches(fileContent, PROCEDURE_PATTERN, internalProcedures, "PROCEDURE", file.getName());
        int classesFound = findAndAddMatches(fileContent, CLASS_PATTERN, internalClasses, "CLASS", file.getName());
        int methodsFound = findAndAddMatches(fileContent, METHOD_PATTERN, internalMethods, "METHOD", file.getName());
        
        if (functionsFound > 0 || proceduresFound > 0 || classesFound > 0 || methodsFound > 0) {
            HarbourLogger.log("FunctionClassification", 
                    String.format("Updated file %s: %d functions, %d procedures, %d classes, %d methods", 
                            file.getName(), functionsFound, proceduresFound, classesFound, methodsFound));
        }
    }

    /**
     * Force re-scan of the project to update internal function registry.
     * This should be called when project files change significantly.
     */
    public void rescanProject() {
        HarbourLogger.log("FunctionClassification", "Re-scanning project for internal functions");
        
        // Clear existing registries
        internalFunctions.clear();
        internalProcedures.clear();
        internalClasses.clear();
        initialized = false;
        scanning = false;
        
        // Trigger new scan with progress
        initializeWithProgress();
    }

    /**
     * Initialize the service with progress indication.
     * This shows a progress bar to the user while scanning.
     */
    private void initializeWithProgress() {
        if (initialized || scanning) {
            return;
        }
        
        scanning = true;
        
        ProgressManager.getInstance().run(new Task.Backgroundable(project, "Scanning Harbour Functions", true) {
            @Override
            public void run(@NotNull ProgressIndicator indicator) {
                ReadAction.run(() -> {
                    scanProjectForInternalFunctionsWithProgress(indicator);
                });
            }
            
            @Override
            public void onFinished() {
                scanning = false;
                // Force re-highlighting after scan complete
                ApplicationManager.getApplication().invokeLater(() -> {
                    // Trigger re-highlighting by clearing the cache
                    HarbourStandardFunctionCache.clearCache();
                });
            }
        });
    }
    
    /**
     * Initialize the service by scanning the project for internal functions.
     * This runs in the background to avoid blocking the UI.
     */
    private void initializeInBackground() {
        if (initialized || scanning) {
            return;
        }
        
        scanning = true;

        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            ReadAction.run(() -> {
                scanProjectForInternalFunctions();
                scanning = false;
            });
        });
    }

    /**
     * Scan all Harbour files in the project to find internal function declarations with progress indication.
     * This method must be called within a read action.
     */
    private void scanProjectForInternalFunctionsWithProgress(@NotNull ProgressIndicator indicator) {
        if (initialized) {
            return;
        }

        Instant start = Instant.now();
        HarbourLogger.log("FunctionClassification", "Starting project scan for internal functions with progress");
        
        indicator.setText("Scanning Harbour files for function declarations...");
        indicator.setIndeterminate(false);

        try {
            // Get all Harbour files in the project
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));
            
            // Filter out excluded files
            List<VirtualFile> filesToProcess = virtualFiles.stream()
                .filter(file -> !HarbourFileUtils.isFileExcluded(project, file))
                .toList();
            
            totalFiles = filesToProcess.size();
            processedFiles = 0;
            
            if (totalFiles == 0) {
                initialized = true;
                return;
            }

            PsiManager psiManager = PsiManager.getInstance(project);
            int functionsFound = 0;
            int proceduresFound = 0;
            int classesFound = 0;
            int methodsFound = 0;
            
            // Process files in batches to avoid long blocking
            final int BATCH_SIZE = 10;
            
            for (int i = 0; i < filesToProcess.size(); i += BATCH_SIZE) {
                if (indicator.isCanceled()) {
                    HarbourLogger.log("FunctionClassification", "Scan cancelled by user");
                    return;
                }
                
                int endIndex = Math.min(i + BATCH_SIZE, filesToProcess.size());
                List<VirtualFile> batch = filesToProcess.subList(i, endIndex);
                
                for (VirtualFile virtualFile : batch) {
                    if (indicator.isCanceled()) {
                        return;
                    }
                    
                    processedFiles++;
                    double progress = (double) processedFiles / totalFiles;
                    indicator.setFraction(progress);
                    indicator.setText2("Processing: " + virtualFile.getName() + " (" + processedFiles + "/" + totalFiles + ")");

                    PsiFile psiFile = psiManager.findFile(virtualFile);
                    if (psiFile == null) continue;

                    // Process file content efficiently
                    String fileContent = psiFile.getText();
                    if (fileContent == null || fileContent.isEmpty()) continue;
                    
                    // Use optimized pattern matching
                    functionsFound += findAndAddMatches(fileContent, FUNCTION_PATTERN, internalFunctions, "FUNCTION", virtualFile.getName());
                    proceduresFound += findAndAddMatches(fileContent, PROCEDURE_PATTERN, internalProcedures, "PROCEDURE", virtualFile.getName());
                    classesFound += findAndAddMatches(fileContent, CLASS_PATTERN, internalClasses, "CLASS", virtualFile.getName());
                    methodsFound += findAndAddMatches(fileContent, METHOD_PATTERN, internalMethods, "METHOD", virtualFile.getName());
                }
                
                // Brief pause to allow UI updates
                try {
                    Thread.sleep(1);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }

            // Mark as initialized
            initialized = true;

            Instant end = Instant.now();
            Duration duration = Duration.between(start, end);
            
            indicator.setText("Scan completed");
            indicator.setFraction(1.0);
            
            HarbourLogger.log("FunctionClassification", 
                    String.format("Project scan completed in %d ms. Scanned %d files, found %d functions, %d procedures, %d classes, %d methods",
                            duration.toMillis(), processedFiles, functionsFound, proceduresFound, classesFound, methodsFound));
            
            LOG.info(String.format("HarbourFunctionClassificationService initialized: %d functions, %d procedures, %d classes, %d methods in %d ms",
                    functionsFound, proceduresFound, classesFound, methodsFound, duration.toMillis()));

        } catch (Exception e) {
            LOG.error("Error during project scan for internal functions", e);
            HarbourLogger.log("FunctionClassification", "Error during project scan: " + e.getMessage());
        }
    }
    
    /**
     * Optimized pattern matching and adding to collections.
     */
    private int findAndAddMatches(String content, Pattern pattern, Set<String> collection, String type, String fileName) {
        int found = 0;
        Matcher matcher = pattern.matcher(content);
        while (matcher.find()) {
            String name = matcher.group(1);
            if (name != null && !name.isEmpty()) {
                String normalizedName = name.toLowerCase();
                if (collection.add(normalizedName)) { // Only log if newly added
                    found++;
                    HarbourLogger.log("FunctionClassification", 
                            "Found internal " + type + ": " + name + " in " + fileName);
                }
            }
        }
        return found;
    }
    
    /**
     * Scan all Harbour files in the project to find internal function declarations.
     * This method must be called within a read action.
     */
    private void scanProjectForInternalFunctions() {
        if (initialized) {
            return;
        }

        Instant start = Instant.now();
        HarbourLogger.log("FunctionClassification", "Starting project scan for internal functions");

        try {
            // Get all Harbour files in the project
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));
            
            // Filter out excluded files
            List<VirtualFile> filesToProcess = virtualFiles.stream()
                .filter(file -> !HarbourFileUtils.isFileExcluded(project, file))
                .toList();
            
            totalFiles = filesToProcess.size();
            processedFiles = 0;
            
            if (totalFiles == 0) {
                initialized = true;
                return;
            }

            PsiManager psiManager = PsiManager.getInstance(project);
            int functionsFound = 0;
            int proceduresFound = 0;
            int classesFound = 0;
            int methodsFound = 0;
            
            for (VirtualFile virtualFile : filesToProcess) {
                processedFiles++;

                PsiFile psiFile = psiManager.findFile(virtualFile);
                if (psiFile == null) continue;

                // Process file content efficiently
                String fileContent = psiFile.getText();
                if (fileContent == null || fileContent.isEmpty()) continue;
                
                // Use optimized pattern matching
                functionsFound += findAndAddMatches(fileContent, FUNCTION_PATTERN, internalFunctions, "FUNCTION", virtualFile.getName());
                proceduresFound += findAndAddMatches(fileContent, PROCEDURE_PATTERN, internalProcedures, "PROCEDURE", virtualFile.getName());
                classesFound += findAndAddMatches(fileContent, CLASS_PATTERN, internalClasses, "CLASS", virtualFile.getName());
            }

            // Mark as initialized
            initialized = true;

            Instant end = Instant.now();
            Duration duration = Duration.between(start, end);
            
            HarbourLogger.log("FunctionClassification", 
                    String.format("Project scan completed in %d ms. Scanned %d files, found %d functions, %d procedures, %d classes, %d methods",
                            duration.toMillis(), processedFiles, functionsFound, proceduresFound, classesFound, methodsFound));
            
            LOG.info(String.format("HarbourFunctionClassificationService initialized: %d functions, %d procedures, %d classes, %d methods in %d ms",
                    functionsFound, proceduresFound, classesFound, methodsFound, duration.toMillis()));

        } catch (Exception e) {
            LOG.error("Error during project scan for internal functions", e);
            HarbourLogger.log("FunctionClassification", "Error during project scan: " + e.getMessage());
        }
    }
    

    /**
     * Initializer for the service that runs on project startup.
     */
    public static class Initializer implements StartupActivity.DumbAware {
        @Override
        public void runActivity(@NotNull Project project) {
            HarbourLogger.log("FunctionClassification", "Initializing function classification service");
            
            // Initialize the save listener service to ensure it's available
            HarbourSaveListenerService.getInstance();
            
            // Get the service instance (this will create it if needed)
            HarbourFunctionClassificationService service = getInstance(project);
            
            // Start background initialization with progress
            service.initializeWithProgress();
        }
    }
}
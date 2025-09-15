package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.progress.util.ProgressIndicatorBase;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.SystemInfo;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.ClassDeclaration;
import com.intellij.psi.tree.IElementType;
import com.intellij.psi.PsiWhiteSpace;
import org.intellij.sdk.language.psi.HarbourTypes;
import com.intellij.psi.util.PsiTreeUtil;
import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Progressive indexer for Harbour files that prioritizes visible files
 * and processes others in the background with lower priority.
 */
public class HarbourProgressiveIndexer {
    private static final Logger LOG = Logger.getInstance(HarbourProgressiveIndexer.class);
    private static final AtomicBoolean INDEXING_IN_PROGRESS = new AtomicBoolean(false);
    private static final int BATCH_SIZE = 20;
    private static final int MAX_INITIAL_FILES = 100;

    /**
     * Start progressive indexing of Harbour files.
     * This will first index a small batch of files quickly and then
     * continue with the rest in the background.
     *
     * @param project The project to index
     */
    public static void startProgressiveIndexing(@NotNull Project project) {
        if (INDEXING_IN_PROGRESS.compareAndSet(false, true)) {
            LOG.info("Starting progressive indexing of Harbour files");

            // Create and run task asynchronously - no EDT blocking
            Task.Backgroundable task = new Task.Backgroundable(project, "Scanning Harbour project files", false) {
                @Override
                public void run(@NotNull ProgressIndicator indicator) {
                    long startTime = System.currentTimeMillis();
                    long timeout = 60000; // 60 second timeout
                    
                    try {
                            indicator.setIndeterminate(false);

                            // First get all Harbour files in the project - MUST BE IN READ ACTION
                            Collection<VirtualFile> harbourFiles = ReadAction.compute(() ->
                                    FileTypeIndex.getFiles(
                                            HarbourFileType.INSTANCE,
                                            GlobalSearchScope.projectScope(project))
                            );

                            LOG.info("Starting indexing of " + harbourFiles.size() + " Harbour files");
                            HarbourLogger.log("Indexer", "Starting indexing of " + harbourFiles.size() + " Harbour files");
                            
                            // Log the list of files to be indexed
                            StringBuilder fileList = new StringBuilder("Files to index:\n");
                            int fileCount = 0;
                            for (VirtualFile file : harbourFiles) {
                                fileCount++;
                                fileList.append("  ").append(fileCount).append(". ").append(file.getName())
                                       .append(" (").append(file.getPath()).append(")\n");
                                if (fileCount >= 20) {
                                    fileList.append("  ... and ").append(harbourFiles.size() - 20).append(" more files\n");
                                    break;
                                }
                            }
                            HarbourLogger.log("Indexer", fileList.toString());
                            
                            // Check cache status
                            HarbourSettings settings = HarbourSettings.getInstance(project);
                            if (settings.isIndexCacheEnabled()) {
                                HarbourIndexCache cache = HarbourIndexCache.getInstance(project);
                                if (cache != null) {
                                    LOG.info("Cache enabled. Has data: " + cache.hasCachedData() + ", Loaded: " + cache.isCacheLoaded());
                                } else {
                                    LOG.error("Cache service is null despite being enabled!");
                                }
                            }

                            // Index ALL files in background - no limits
                            LOG.info("Indexing all " + harbourFiles.size() + " Harbour files in background");

                            // First index open files - highest priority
                            indicator.setText("Indexing open Harbour files");
                            Set<VirtualFile> openFiles = ReadAction.compute(() -> getOpenHarbourFiles(project));
                            if (!openFiles.isEmpty()) {
                                indexFiles(project, openFiles, indicator, 0, openFiles.size());
                            }

                            // Then index ALL remaining files with progress tracking
                            indicator.setText("Scanning all Harbour project files");
                            indicator.setFraction(0.1);

                            Set<VirtualFile> remainingFiles = new HashSet<>(harbourFiles);
                            remainingFiles.removeAll(openFiles);
                            
                            LOG.info("Indexing " + remainingFiles.size() + " remaining files");
                            
                            // Index remaining files WITH progress indicator
                            if (!remainingFiles.isEmpty()) {
                                indexFiles(project, remainingFiles, indicator, openFiles.size(), harbourFiles.size());
                            }
                            
                            // NOW mark progress as complete after actual work is done
                            indicator.setFraction(1.0);
                            indicator.setText("Harbour file scanning completed");
                            indicator.setText2("");
                            
                            // Small delay to ensure UI updates
                            try {
                                Thread.sleep(500);
                            } catch (InterruptedException e) {
                                // Ignore
                            }
                            
                        } finally {
                            INDEXING_IN_PROGRESS.set(false);
                            
                            // Force save the cache after indexing completes
                            HarbourSettings settings = HarbourSettings.getInstance(project);
                            if (settings.isIndexCacheEnabled()) {
                                HarbourIndexCache cache = HarbourIndexCache.getInstance(project);
                                if (cache != null) {
                                    cache.forceSave();
                                    LOG.info("Forced cache save after indexing");
                                } else {
                                    LOG.error("Cannot save - cache service is null!");
                                }
                            }
                            
                            LOG.info("Harbour indexing completed successfully");
                            HarbourLogger.log("Indexer", "Harbour indexing completed successfully");
                        }
                    }
                };
            
            // Run the task asynchronously to avoid EDT blocking
            // Try using runProcessWithProgressAsynchronously with error handling
            try {
                ProgressManager.getInstance().runProcessWithProgressAsynchronously(task, 
                    new com.intellij.openapi.progress.impl.BackgroundableProcessIndicator(task));
            } catch (Exception e) {
                HarbourLogger.error("Indexer", "Failed to start indexing task: " + e.getMessage());
                LOG.error("Failed to start indexing task", e);
            }
        } else {
            LOG.info("Progressive indexing already in progress");
        }
    }

    /**
     * Get all currently open Harbour files.
     *
     * @param project The project
     * @return Set of open files
     */
    private static Set<VirtualFile> getOpenHarbourFiles(@NotNull Project project) {
        // This MUST be called inside a ReadAction
        Set<VirtualFile> openFiles = new HashSet<>();
        VirtualFile[] openFilesArray = com.intellij.openapi.fileEditor.FileEditorManager.getInstance(project).getOpenFiles();

        for (VirtualFile file : openFilesArray) {
            if (file.getFileType() == HarbourFileType.INSTANCE && !file.isDirectory()) {
                openFiles.add(file);
            }
        }

        LOG.info("Found " + openFiles.size() + " open Harbour files");
        return openFiles;
    }

    /**
     * Index all files at once with progress indicator.
     *
     * @param project The project
     * @param files Files to index
     * @param indicator Progress indicator
     */
    private static void indexAllFiles(@NotNull Project project, @NotNull Collection<VirtualFile> files,
                                      @NotNull ProgressIndicator indicator) {
        indexFiles(project, files, indicator, 0, files.size());
    }

    /**
     * Index files with progress indicator.
     *
     * @param project The project
     * @param files Files to index
     * @param indicator Progress indicator
     * @param startProgress Starting progress value (0-1)
     * @param count Number of files to process
     */
    private static void indexFiles(@NotNull Project project, @NotNull Collection<VirtualFile> files,
                                   @NotNull ProgressIndicator indicator, int processedFiles, int totalFiles) {
        PsiManager psiManager = PsiManager.getInstance(project);
        HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);
        AtomicInteger processed = new AtomicInteger(processedFiles);

        long indexingStartTime = System.currentTimeMillis();
        long maxIndexingTime = 30000; // 30 seconds max per batch
        for (VirtualFile file : files) {
            indicator.checkCanceled();

            if (HarbourPerformanceOptimizer.isShuttingDown() || project.isDisposed()) {
                return;
            }
            
            // Check for timeout
            if (System.currentTimeMillis() - indexingStartTime > maxIndexingTime) {
                HarbourLogger.log("Indexer", "Indexing timeout reached after processing " + processed.get() + " files");
                LOG.warn("Indexing timeout reached, stopping batch");
                break;
            }
            
            String fullPath = file.getPath();
            int currentFileNum = processed.get() + 1; // Show 1-based numbering
            
            // Update progress BEFORE processing the file
            double fraction = (double) (processedFiles + processed.get()) / totalFiles;
            
            indicator.setFraction(fraction);
            indicator.setText2("Processing " + file.getName() + " (" + currentFileNum + "/" + files.size() + ")");
            
            // Windows-specific: Force progress bar repaint
            if (SystemInfo.isWindows) {
                // On Windows, we need to ensure progress updates are visible
                // Use invokeLater (non-blocking) instead of invokeAndWait (blocking)
                ApplicationManager.getApplication().invokeLater(() -> {
                    // This allows the EDT to process pending paint events
                    indicator.checkCanceled(); // Also check for cancellation
                });
                
                // Small yield to allow UI thread to process the update
                try {
                    Thread.sleep(5); // Reduced delay, just enough for Windows
                } catch (InterruptedException e) {
                    // Ignore interruption
                }
            }
            
            LOG.info("Processing file " + currentFileNum + "/" + files.size() + ": " + file.getName() + " (" + fullPath + ")");
            HarbourLogger.log("Indexer", "Processing file " + currentFileNum + "/" + files.size() + ": " + file.getName() + " at " + fullPath);

            try {
                // Use non-blocking read action to allow progress updates
                ApplicationManager.getApplication().runReadAction(() -> {
                    try {
                        // Allow progress updates during read action
                        indicator.checkCanceled();
                        
                        // Check file isn't excluded first
                        if (referenceService.isExcluded(file)) {
                            HarbourLogger.log("Indexer", "Skipping excluded file: " + file.getName());
                            return;
                        }
                        
                        // Skip binary files
                        if (file.getFileType().isBinary()) {
                            HarbourLogger.log("Indexer", "Skipping binary file: " + file.getName());
                            return;
                        }

                        // Check if file is already in cache and unchanged
                        HarbourSettings settings = HarbourSettings.getInstance(project);
                        HarbourIndexCache indexCache = HarbourIndexCache.getInstance(project);
                        
                        if (indexCache != null && settings.isIndexCacheEnabled() && indexCache.hasCachedData() && !indexCache.isFileModified(file)) {
                            // File is cached and unchanged - skip indexing
                            LOG.info("Skipping cached file: " + file.getName());
                            return;
                        } else if (indexCache != null) {
                            LOG.info("Indexing file: " + file.getName() + " (cache enabled=" + settings.isIndexCacheEnabled() + 
                                    ", has data=" + indexCache.hasCachedData() + ", modified=" + 
                                    (indexCache.hasCachedData() ? indexCache.isFileModified(file) : "N/A") + ")");
                        } else {
                            LOG.info("Indexing file: " + file.getName() + " (cache service is null)");
                        }

                        // Get PSI and register functions
                        HarbourLogger.log("Indexer", "Getting PSI for: " + file.getName());
                        com.intellij.psi.PsiFile psiFile = psiManager.findFile(file);
                        
                        if (psiFile instanceof HarbourFile harbourFile) {
                            // Add timeout protection for registration
                            long startTime = System.currentTimeMillis();
                            
                            // Check for cancellation before heavy operations
                            indicator.checkCanceled();
                            
                            // Register in runtime cache
                            try {
                                referenceService.registerFunctions(harbourFile);
                                
                                // Check cancellation between operations
                                indicator.checkCanceled();
                                
                                referenceService.registerProcedures(harbourFile);
                            } catch (Exception e) {
                                HarbourLogger.error("Indexer", "Failed to register for " + file.getName() + ": " + e.getMessage());
                            }
                            
                            
                            // Update persistent cache if enabled
                            if (settings.isIndexCacheEnabled() && indexCache != null) {
                                HarbourLogger.log("Indexer", "Updating cache for: " + file.getName());
                                try {
                                    updatePersistentCache(harbourFile, file, indexCache);
                                    HarbourLogger.log("Indexer", "Cache updated for: " + file.getName());
                                } catch (Exception e) {
                                    HarbourLogger.error("Indexer", "Failed to update cache for " + file.getName() + ": " + e.getMessage());
                                }
                            }
                        } else {
                            HarbourLogger.log("Indexer", "File is not a HarbourFile: " + file.getName());
                        }
                    } catch (Exception e) {
                        LOG.warn("Error processing file in read action: " + file.getName(), e);
                    }
                });

                // Increment counter after successful processing
                int count = processed.incrementAndGet();
                
                // Update progress AFTER processing completes too
                double finalFraction = (double) (processedFiles + count) / totalFiles;
                indicator.setFraction(finalFraction);
                indicator.setText2("Completed " + file.getName() + " (" + count + "/" + files.size() + ")");
                
                // Windows-specific: Force progress bar repaint after completion
                if (SystemInfo.isWindows) {
                    ApplicationManager.getApplication().invokeLater(() -> {
                        // Allow UI update on Windows (non-blocking)
                    });
                }
                
                // Log progress every 10 files or at important milestones
                if (count % 10 == 0 || count == 1 || count == files.size()) {
                    HarbourLogger.log("Indexer", "Progress: " + count + "/" + files.size() + " files indexed");
                }
                
                HarbourLogger.log("Indexer", "Completed processing file " + count + "/" + files.size() + ": " + file.getName());

            } catch (Exception e) {
                LOG.warn("Error indexing file: " + file.getName(), e);
            }
        }
    }


    /**
     * Reindex a specific Harbour file after changes.
     * This method should be called when a file is modified to
     * ensure references are updated immediately.
     *
     * @param project The project
     * @param file The file to reindex
     */
    public static void reindexFile(@NotNull Project project, @NotNull VirtualFile file) {
        if (project.isDisposed() || HarbourPerformanceOptimizer.isShuttingDown()) {
            return;
        }

        // Check cache to see if file actually changed
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings.isIndexCacheEnabled()) {
            HarbourIndexCache cache = HarbourIndexCache.getInstance(project);
            if (cache.hasCachedData() && !cache.isFileModified(file)) {
                LOG.info("File not modified, skipping reindex: " + file.getName());
                return;
            }
        }

        LOG.info("Reindexing Harbour file: " + file.getName());

        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                ApplicationManager.getApplication().runReadAction(() -> {
                    // Get the PSI file
                    PsiManager psiManager = PsiManager.getInstance(project);
                    com.intellij.psi.PsiFile psiFile = psiManager.findFile(file);

                    if (psiFile instanceof HarbourFile harbourFile) {
                        // Get the reference service
                        HarbourReferenceService referenceService =
                                HarbourReferenceService.getInstance(project);

                        // Make sure the file isn't excluded
                        if (!referenceService.isExcluded(file)) {
                            // Register declarations in runtime cache
                            referenceService.registerFunctions(harbourFile);
                            referenceService.registerProcedures(harbourFile);
                            referenceService.registerClasses(harbourFile);

                            // Update persistent cache if enabled (settings already defined above)
                            if (settings.isIndexCacheEnabled()) {
                                HarbourIndexCache indexCache = HarbourIndexCache.getInstance(project);
                                if (indexCache != null) {
                                    updatePersistentCache(harbourFile, file, indexCache);
                                }
                            }

                            // Ensure token-based references are processed
                            HarbourTokenTypeExtension.processFile(psiFile);

                            LOG.info("Successfully reindexed file: " + file.getName());
                        }
                    }
                });
            } catch (Exception e) {
                LOG.warn("Error reindexing file: " + file.getName(), e);
            }
        });
    }
    
    /**
     * Update persistent cache with declarations from a file.
     */
    private static void updatePersistentCache(@NotNull HarbourFile harbourFile, @NotNull VirtualFile file, @NotNull HarbourIndexCache cache) {
        try {
            List<HarbourIndexCache.CacheEntry> entries = new ArrayList<>();
            
            // Log what we're looking for
            HarbourLogger.log("Indexer", "Looking for functions in " + file.getName());
            
            // Since PSI classes aren't generated, scan for FUNCTION/PROCEDURE tokens directly
            com.intellij.openapi.editor.Document document = com.intellij.psi.PsiDocumentManager.getInstance(harbourFile.getProject()).getDocument(harbourFile);
            if (document == null) {
                HarbourLogger.log("Indexer", "No document found for " + file.getName());
                return;
            }
            
            // Parse file text to find functions and procedures
            String text = harbourFile.getText();
            String[] lines = text.split("\n");
            
            boolean inBlockComment = false;
            for (int i = 0; i < lines.length; i++) {
                String line = lines[i];
                String trimmedLine = line.trim();
                
                // Skip empty lines
                if (trimmedLine.isEmpty()) {
                    continue;
                }
                
                // Check for block comment start/end
                if (trimmedLine.contains("/*")) {
                    inBlockComment = true;
                }
                if (inBlockComment) {
                    if (trimmedLine.contains("*/")) {
                        inBlockComment = false;
                    }
                    continue;
                }
                
                // Skip line comments (// or * at start of line or &&)
                if (trimmedLine.startsWith("//") || trimmedLine.startsWith("*") || trimmedLine.startsWith("&&")) {
                    continue;
                }
                
                // Skip preprocessor directives
                if (trimmedLine.startsWith("#")) {
                    continue;
                }
                
                // Remove inline comments before processing
                int commentPos = trimmedLine.indexOf("//");
                if (commentPos == -1) {
                    commentPos = trimmedLine.indexOf("&&");
                }
                if (commentPos > 0) {
                    trimmedLine = trimmedLine.substring(0, commentPos).trim();
                }
                
                // Skip if line is within string literals (simple check)
                // Count quotes - if odd number, we're likely in a string
                long quoteCount = trimmedLine.chars().filter(ch -> ch == '"' || ch == '\'').count();
                if (quoteCount % 2 != 0) {
                    continue;
                }
                
                String upperLine = trimmedLine.toUpperCase();
                
                // Check for FUNCTION declaration (must be at start of line)
                if (upperLine.startsWith("FUNCTION ") || upperLine.startsWith("STATIC FUNCTION ")) {
                    String name = extractFunctionName(trimmedLine);
                    if (name != null && isValidIdentifier(name)) {
                        entries.add(new HarbourIndexCache.CacheEntry(
                            name,
                            file.getPath(),
                            i + 1, // Line number (1-based)
                            trimmedLine,
                            HarbourIndexCache.EntryType.FUNCTION
                        ));
                        HarbourLogger.log("Indexer", "Found function: " + name + " at line " + (i + 1));
                    }
                }
                // Check for PROCEDURE declaration (must be at start of line)
                else if (upperLine.startsWith("PROCEDURE ") || upperLine.startsWith("STATIC PROCEDURE ")) {
                    String name = extractProcedureName(trimmedLine);
                    if (name != null && isValidIdentifier(name)) {
                        entries.add(new HarbourIndexCache.CacheEntry(
                            name,
                            file.getPath(),
                            i + 1, // Line number (1-based)
                            trimmedLine,
                            HarbourIndexCache.EntryType.PROCEDURE
                        ));
                        HarbourLogger.log("Indexer", "Found procedure: " + name + " at line " + (i + 1));
                    }
                }
                // Check for CLASS declaration (must be at start of line)
                else if (upperLine.startsWith("CLASS ") || upperLine.startsWith("CREATE CLASS ")) {
                    String name = extractClassName(trimmedLine);
                    if (name != null && isValidIdentifier(name)) {
                        entries.add(new HarbourIndexCache.CacheEntry(
                            name,
                            file.getPath(),
                            i + 1, // Line number (1-based)
                            trimmedLine,
                            HarbourIndexCache.EntryType.CLASS
                        ));
                        HarbourLogger.log("Indexer", "Found class: " + name + " at line " + (i + 1));
                    }
                }
            }
            
            HarbourLogger.log("Indexer", "Total entries found: " + entries.size());
            
            // Update cache
            if (!entries.isEmpty()) {
                cache.updateFileCache(file, entries);
                LOG.info("Updated persistent cache for file: " + file.getName() + " with " + entries.size() + " entries");
                HarbourLogger.log("Indexer", "Added " + entries.size() + " entries to cache for " + file.getName());
            } else {
                HarbourLogger.log("Indexer", "No entries found to cache for " + file.getName());
            }
        } catch (Exception e) {
            LOG.warn("Error updating persistent cache for file: " + file.getName(), e);
        }
    }
    
    /**
     * Extract function name from a line containing FUNCTION declaration.
     */
    private static String extractFunctionName(String line) {
        String[] parts = line.split("\\s+");
        for (int i = 0; i < parts.length; i++) {
            if (parts[i].equalsIgnoreCase("FUNCTION") && i + 1 < parts.length) {
                String name = parts[i + 1];
                // Remove parentheses and parameters if present
                int parenIndex = name.indexOf('(');
                if (parenIndex > 0) {
                    name = name.substring(0, parenIndex);
                }
                return name;
            }
        }
        return null;
    }
    
    /**
     * Extract procedure name from a line containing PROCEDURE declaration.
     */
    private static String extractProcedureName(String line) {
        String[] parts = line.split("\\s+");
        for (int i = 0; i < parts.length; i++) {
            if (parts[i].equalsIgnoreCase("PROCEDURE") && i + 1 < parts.length) {
                String name = parts[i + 1];
                // Remove parentheses and parameters if present
                int parenIndex = name.indexOf('(');
                if (parenIndex > 0) {
                    name = name.substring(0, parenIndex);
                }
                return name;
            }
        }
        return null;
    }
    
    /**
     * Extract class name from a line containing CLASS declaration.
     */
    private static String extractClassName(String line) {
        String[] parts = line.split("\\s+");
        for (int i = 0; i < parts.length; i++) {
            if (parts[i].equalsIgnoreCase("CLASS") && i + 1 < parts.length) {
                String name = parts[i + 1];
                // Remove INHERIT or other keywords if present
                String[] nameTokens = name.split("\\s+");
                if (nameTokens.length > 0) {
                    name = nameTokens[0];
                }
                // Handle cases like "CLASS MyClass INHERIT BaseClass"
                if (name.equalsIgnoreCase("INHERIT") || name.equalsIgnoreCase("FROM")) {
                    return null;
                }
                return name;
            }
        }
        return null;
    }
    
    /**
     * Check if a name is a valid Harbour identifier.
     * Valid identifiers start with letter or underscore, followed by letters, digits, or underscores.
     */
    private static boolean isValidIdentifier(String name) {
        if (name == null || name.isEmpty()) {
            return false;
        }
        
        // Check first character
        char firstChar = name.charAt(0);
        if (!Character.isLetter(firstChar) && firstChar != '_') {
            return false;
        }
        
        // Check remaining characters
        for (int i = 1; i < name.length(); i++) {
            char ch = name.charAt(i);
            if (!Character.isLetterOrDigit(ch) && ch != '_') {
                return false;
            }
        }
        
        // Reject if it's a Harbour keyword
        String upper = name.toUpperCase();
        if (upper.equals("IF") || upper.equals("ELSE") || upper.equals("ENDIF") || 
            upper.equals("DO") || upper.equals("WHILE") || upper.equals("FOR") ||
            upper.equals("NEXT") || upper.equals("RETURN") || upper.equals("LOCAL") ||
            upper.equals("STATIC") || upper.equals("PRIVATE") || upper.equals("PUBLIC") ||
            upper.equals("NIL") || upper.equals("END") || upper.equals("CASE") ||
            upper.equals("OTHERWISE") || upper.equals("SWITCH") || upper.equals("EXIT")) {
            return false;
        }
        
        return true;
    }
}
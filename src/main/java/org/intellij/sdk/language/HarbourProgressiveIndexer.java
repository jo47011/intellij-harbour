package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.ClassDeclaration;
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

            ApplicationManager.getApplication().invokeLater(() -> {
                // Start with a small indexing job in the background
                ProgressManager.getInstance().run(new Task.Backgroundable(project, "Indexing Harbour Files", true) {
                    @Override
                    public void run(@NotNull ProgressIndicator indicator) {
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

                            // Skip indexing if only a few files
                            if (harbourFiles.size() <= MAX_INITIAL_FILES) {
                                LOG.info("Small project detected, indexing all " + harbourFiles.size() + " files");
                                indexAllFiles(project, harbourFiles, indicator);
                                return;
                            }

                            // Process in batches
                            LOG.info("Large project detected, doing progressive indexing of " + harbourFiles.size() + " files");

                            // First index open files - highest priority
                            indicator.setText("Indexing open Harbour files");
                            Set<VirtualFile> openFiles = ReadAction.compute(() -> getOpenHarbourFiles(project));
                            indexFiles(project, openFiles, indicator, 0, openFiles.size());

                            // Then index a limited set to improve initial performance
                            indicator.setText("Initial indexing of Harbour files");
                            Set<VirtualFile> initialFiles = new HashSet<>(openFiles);
                            int initialCount = Math.min(MAX_INITIAL_FILES, harbourFiles.size());
                            int counter = 0;

                            for (VirtualFile file : harbourFiles) {
                                if (!initialFiles.contains(file)) {
                                    initialFiles.add(file);
                                    counter++;
                                    if (counter >= initialCount) break;
                                }
                            }

                            indexFiles(project, initialFiles, indicator, openFiles.size(), initialCount);

                            // Finally process the rest in the background with lower priority
                            indicator.setText("Background indexing of remaining Harbour files");
                            indicator.setFraction(0.5);

                            Set<VirtualFile> remainingFiles = new HashSet<>(harbourFiles);
                            remainingFiles.removeAll(initialFiles);

                            indexFilesInBackground(project, remainingFiles);
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
                        }
                    }
                });
            });
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

        for (VirtualFile file : files) {
            indicator.checkCanceled();

            if (HarbourPerformanceOptimizer.isShuttingDown() || project.isDisposed()) {
                return;
            }
            
            String fullPath = file.getPath();
            LOG.info("Processing file " + processed.get() + "/" + totalFiles + ": " + file.getName() + " (" + fullPath + ")");
            HarbourLogger.log("Indexer", "Processing file " + processed.get() + "/" + totalFiles + ": " + file.getName());

            try {
                // Must use ReadAction for file operations
                ReadAction.run(() -> {
                    try {
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
                        
                        // Skip very large files
                        if (file.getLength() > 2 * 1024 * 1024) { // 2MB
                            HarbourLogger.warning("Indexer", "Skipping very large file (" + file.getLength() + " bytes): " + file.getName());
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
                        com.intellij.psi.PsiFile psiFile = psiManager.findFile(file);
                        if (psiFile instanceof HarbourFile harbourFile) {
                            // Add timeout protection for registration
                            long startTime = System.currentTimeMillis();
                            
                            // Register in runtime cache
                            HarbourLogger.log("Indexer", "Registering functions for: " + file.getName());
                            referenceService.registerFunctions(harbourFile);
                            
                            long elapsed = System.currentTimeMillis() - startTime;
                            if (elapsed > 1000) {
                                HarbourLogger.warning("Indexer", "Slow function registration (" + elapsed + "ms) for: " + file.getName());
                            }
                            
                            HarbourLogger.log("Indexer", "Registering procedures for: " + file.getName());
                            referenceService.registerProcedures(harbourFile);
                            
                            // Update persistent cache if enabled
                            if (settings.isIndexCacheEnabled() && indexCache != null) {
                                updatePersistentCache(harbourFile, file, indexCache);
                            }
                        }
                    } catch (Exception e) {
                        LOG.warn("Error processing file in read action: " + file.getName(), e);
                    }
                });

                // Update progress outside read action
                int count = processed.incrementAndGet();
                indicator.setFraction((double) count / totalFiles);
                indicator.setText2("Processing " + file.getName() + " (" + count + "/" + totalFiles + ")");

            } catch (Exception e) {
                LOG.warn("Error indexing file: " + file.getName(), e);
            }
        }
    }

    /**
     * Index remaining files in background with lower priority.
     * This splits the work into batches to avoid freezing the UI.
     *
     * @param project The project
     * @param files Files to index
     */
    private static void indexFilesInBackground(@NotNull Project project, @NotNull Collection<VirtualFile> files) {
        if (files.isEmpty()) return;

        LOG.info("Starting background indexing of " + files.size() + " remaining files");

        // Convert to array for batch processing
        VirtualFile[] filesArray = files.toArray(new VirtualFile[0]);
        AtomicInteger processedBatches = new AtomicInteger(0);
        int totalBatches = (filesArray.length + BATCH_SIZE - 1) / BATCH_SIZE;

        // Process first batch immediately
        processBatch(project, filesArray, processedBatches, totalBatches);
    }

    /**
     * Process a batch of files, then schedule the next batch.
     */
    private static void processBatch(@NotNull Project project, @NotNull VirtualFile[] files,
                                     @NotNull AtomicInteger processedBatches, int totalBatches) {
        if (HarbourPerformanceOptimizer.isShuttingDown() || project.isDisposed()) {
            return;
        }

        int batchIndex = processedBatches.getAndIncrement();
        if (batchIndex >= totalBatches) {
            LOG.info("Background indexing completed");
            
            // Force save the cache after all background indexing completes
            HarbourSettings settings = HarbourSettings.getInstance(project);
            if (settings.isIndexCacheEnabled()) {
                HarbourIndexCache cache = HarbourIndexCache.getInstance(project);
                cache.forceSave();
                LOG.info("Forced cache save after background indexing completed");
            }
            return;
        }

        int startIndex = batchIndex * BATCH_SIZE;
        int endIndex = Math.min(startIndex + BATCH_SIZE, files.length);

        // Process this batch
        HarbourPerformanceOptimizer.submitBackgroundTask(() -> {
            try {
                PsiManager psiManager = PsiManager.getInstance(project);
                HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);

                for (int i = startIndex; i < endIndex; i++) {
                    if (HarbourPerformanceOptimizer.isShuttingDown() || project.isDisposed()) {
                        return;
                    }

                    VirtualFile file = files[i];

                    // Must use ReadAction for PSI operations
                    ReadAction.run(() -> {
                        try {
                            if (!referenceService.isExcluded(file)) {
                                // Check if file is already in cache and unchanged
                                HarbourSettings settings = HarbourSettings.getInstance(project);
                                HarbourIndexCache indexCache = HarbourIndexCache.getInstance(project);
                                
                                if (settings.isIndexCacheEnabled() && indexCache.hasCachedData() && !indexCache.isFileModified(file)) {
                                    // File is cached and unchanged - skip indexing
                                    return;
                                }
                                
                                com.intellij.psi.PsiFile psiFile = psiManager.findFile(file);
                                if (psiFile instanceof HarbourFile harbourFile) {
                                    // Register in runtime cache
                                    referenceService.registerFunctions(harbourFile);
                                    referenceService.registerProcedures(harbourFile);
                                    
                                    // Update persistent cache if enabled
                                    if (settings.isIndexCacheEnabled()) {
                                        updatePersistentCache(harbourFile, file, indexCache);
                                    }
                                }
                            }
                        } catch (Exception e) {
                            if (!HarbourPerformanceOptimizer.isShuttingDown()) {
                                LOG.warn("Error in background indexing: " + file.getName(), e);
                            }
                        }
                    });
                }

                // Schedule next batch with delay to avoid UI freezes
                ApplicationManager.getApplication().invokeLater(() -> {
                    processBatch(project, files, processedBatches, totalBatches);
                }, o -> HarbourPerformanceOptimizer.isShuttingDown() || project.isDisposed());

            } catch (Exception e) {
                if (!HarbourPerformanceOptimizer.isShuttingDown()) {
                    LOG.error("Error processing batch " + batchIndex, e);
                }
            }
        });
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
                ReadAction.run(() -> {
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

                            // Update persistent cache
                            HarbourIndexCache indexCache = HarbourIndexCache.getInstance(project);
                            updatePersistentCache(harbourFile, file, indexCache);

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
            
            // Extract functions
            Collection<HarbourFunctionDeclaration> functions = PsiTreeUtil.findChildrenOfType(harbourFile, HarbourFunctionDeclaration.class);
            for (HarbourFunctionDeclaration function : functions) {
                String name = function.getName();
                if (name != null && !name.isEmpty()) {
                    com.intellij.openapi.editor.Document document = com.intellij.psi.PsiDocumentManager.getInstance(harbourFile.getProject()).getDocument(harbourFile);
                    if (document != null) {
                        int lineNumber = document.getLineNumber(function.getTextOffset()) + 1;
                        String signature = function.getText().split("\\n")[0]; // First line as signature
                        entries.add(new HarbourIndexCache.CacheEntry(
                            name,
                            file.getPath(),
                            lineNumber,
                            signature,
                            function.getText().toUpperCase().startsWith("PROCEDURE") ? 
                                HarbourIndexCache.EntryType.PROCEDURE : 
                                HarbourIndexCache.EntryType.FUNCTION
                        ));
                    }
                }
            }
            
            // Extract classes
            Collection<ClassDeclaration> classes = PsiTreeUtil.findChildrenOfType(harbourFile, ClassDeclaration.class);
            for (ClassDeclaration classDecl : classes) {
                String name = classDecl.getName();
                if (name != null && !name.isEmpty()) {
                    com.intellij.openapi.editor.Document document = com.intellij.psi.PsiDocumentManager.getInstance(harbourFile.getProject()).getDocument(harbourFile);
                    if (document != null) {
                        int lineNumber = document.getLineNumber(classDecl.getTextOffset()) + 1;
                        String signature = classDecl.getText().split("\\n")[0]; // First line as signature
                        entries.add(new HarbourIndexCache.CacheEntry(
                            name,
                            file.getPath(),
                            lineNumber,
                            signature,
                            HarbourIndexCache.EntryType.CLASS
                        ));
                    }
                }
            }
            
            // Update cache
            if (!entries.isEmpty()) {
                cache.updateFileCache(file, entries);
                LOG.info("Updated persistent cache for file: " + file.getName() + " with " + entries.size() + " entries");
            }
        } catch (Exception e) {
            LOG.warn("Error updating persistent cache for file: " + file.getName(), e);
        }
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.progress.ProcessCanceledException;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.util.concurrency.AppExecutorUtil;
import org.jetbrains.annotations.NotNull;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Future;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Performance optimization helper for Harbour language plugin.
 * Provides utilities to prevent EDT freezes and optimize resource usage.
 */
public class HarbourPerformanceOptimizer implements StartupActivity.DumbAware {
    private static final Logger LOG = Logger.getInstance(HarbourPerformanceOptimizer.class);

    // Cache to prevent redundant operations
    private static final ConcurrentHashMap<String, Object> CACHE = new ConcurrentHashMap<>();

    // Track background tasks to prevent overloading
    private static final AtomicBoolean INDEXING_IN_PROGRESS = new AtomicBoolean(false);
    private static final AtomicBoolean CLEANUP_SCHEDULED = new AtomicBoolean(false);
    private static ScheduledFuture<?> cleanupTask;

    // Track all running tasks for shutdown
    private static final List<Future<?>> activeTasks = new ArrayList<>();

    // Shutdown flag to prevent new operations when shutting down
    private static final AtomicBoolean SHUTDOWN_IN_PROGRESS = new AtomicBoolean(false);

    // Maximum files to process in one batch
    private static final int MAX_FILES_PER_BATCH = 50;

    @Override
    public void runActivity(@NotNull Project project) {
        LOG.info("Initializing Harbour performance optimizer");

        // Schedule periodic cache cleanup
        scheduleCleanup();

        // Configure chunk size for large file processing
        configureChunkSizes();
    }

    /**
     * Clears all caches and cancels all background tasks.
     * Call when the plugin is being unloaded.
     */
    public static void shutdown() {
        if (!SHUTDOWN_IN_PROGRESS.compareAndSet(false, true)) {
            return; // Already shutting down
        }

        LOG.info("Harbour performance optimizer shutdown started");

        // Cancel periodic cleanup
        if (cleanupTask != null) {
            cleanupTask.cancel(true);
            cleanupTask = null;
        }

        // Cancel all active tasks
        synchronized (activeTasks) {
            LOG.info("Cancelling " + activeTasks.size() + " active background tasks");
            for (Future<?> task : activeTasks) {
                if (task != null && !task.isDone() && !task.isCancelled()) {
                    task.cancel(true);
                }
            }
            activeTasks.clear();
        }

        // Clear caches
        CACHE.clear();

        LOG.info("Harbour performance optimizer shutdown completed");
    }

    /**
     * Process a large collection of files in batches to prevent freezes.
     *
     * @param project The project
     * @param title The title for the progress indicator
     * @param files The files to process
     * @param processor The function to apply to each file
     */
    public static void processBatched(
            @NotNull Project project,
            @NotNull String title,
            @NotNull Collection<PsiFile> files,
            @NotNull Consumer<PsiFile> processor) {

        if (files.isEmpty() || SHUTDOWN_IN_PROGRESS.get()) {
            return;
        }

        if (files.size() <= MAX_FILES_PER_BATCH) {
            // Small enough to process in one go
            for (PsiFile file : files) {
                if (SHUTDOWN_IN_PROGRESS.get()) return;
                processor.accept(file);
            }
            return;
        }

        // For large collections, use a background task with batching
        ProgressManager.getInstance().run(new Task.Backgroundable(project, title, true) {
            @Override
            public void run(@NotNull ProgressIndicator indicator) {
                List<PsiFile> filesList = new ArrayList<>(files);
                int totalFiles = filesList.size();
                indicator.setIndeterminate(false);

                for (int i = 0; i < totalFiles; i += MAX_FILES_PER_BATCH) {
                    if (SHUTDOWN_IN_PROGRESS.get() || indicator.isCanceled()) {
                        return;
                    }

                    indicator.setText("Processing files " + (i + 1) + " to " +
                            Math.min(i + MAX_FILES_PER_BATCH, totalFiles) +
                            " of " + totalFiles);
                    indicator.setFraction((double) i / totalFiles);

                    int endIndex = Math.min(i + MAX_FILES_PER_BATCH, totalFiles);
                    List<PsiFile> batch = filesList.subList(i, endIndex);

                    // Process each batch in a read action
                    try {
                        ReadAction.run(() -> {
                            for (PsiFile file : batch) {
                                if (SHUTDOWN_IN_PROGRESS.get()) return;
                                ProgressManager.checkCanceled();
                                processor.accept(file);
                            }
                        });
                    } catch (ProcessCanceledException e) {
                        // Handle cancellation gracefully
                        LOG.info("Batch processing was canceled");
                        break;
                    }
                }
            }
        });
    }

    /**
     * Run a background task with proper progress and cancellation support.
     *
     * @param project The project
     * @param title The task title
     * @param task The task to run
     */
    public static void runInBackground(@NotNull Project project, @NotNull String title, @NotNull Runnable task) {
        if (SHUTDOWN_IN_PROGRESS.get()) {
            LOG.info("Skipping background task during shutdown: " + title);
            return;
        }

        ProgressManager.getInstance().run(new Task.Backgroundable(project, title, true) {
            @Override
            public void run(@NotNull ProgressIndicator indicator) {
                Future<?> taskFuture = null;
                try {
                    taskFuture = AppExecutorUtil.getAppExecutorService().submit(() -> {
                        try {
                            if (!SHUTDOWN_IN_PROGRESS.get()) {
                                task.run();
                            }
                        } catch (ProcessCanceledException e) {
                            // Expected during cancellation
                        } catch (Exception e) {
                            LOG.error("Error in background task: " + title, e);
                        }
                    });

                    // Register for shutdown handling
                    synchronized (activeTasks) {
                        if (!SHUTDOWN_IN_PROGRESS.get()) {
                            activeTasks.add(taskFuture);
                        } else {
                            taskFuture.cancel(true);
                        }
                    }

                    // Wait with periodic cancellation check
                    while (!taskFuture.isDone()) {
                        if (indicator.isCanceled() || SHUTDOWN_IN_PROGRESS.get()) {
                            taskFuture.cancel(true);
                            break;
                        }
                        try {
                            Thread.sleep(100);
                        } catch (InterruptedException e) {
                            taskFuture.cancel(true);
                            Thread.currentThread().interrupt();
                            break;
                        }
                    }
                } finally {
                    // Remove from active tasks when done
                    if (taskFuture != null) {
                        synchronized (activeTasks) {
                            activeTasks.remove(taskFuture);
                        }
                    }
                }
            }
        });
    }

    /**
     * Submit a task to run in a background thread with proper cancellation support.
     * Returns a Future that can be used to check completion or cancel the task.
     *
     * @param task The task to run
     * @return A Future representing the task
     */
    public static Future<?> submitBackgroundTask(Runnable task) {
        if (SHUTDOWN_IN_PROGRESS.get()) {
            return null;
        }

        Future<?> future = AppExecutorUtil.getAppExecutorService().submit(() -> {
            if (!SHUTDOWN_IN_PROGRESS.get()) {
                try {
                    task.run();
                } catch (ProcessCanceledException e) {
                    // Expected during cancellation
                } catch (Exception e) {
                    LOG.error("Error in background task", e);
                }
            }
        });

        // Register for shutdown handling
        synchronized (activeTasks) {
            if (!SHUTDOWN_IN_PROGRESS.get()) {
                activeTasks.add(future);
            } else {
                future.cancel(true);
            }
        }

        return future;
    }

    /**
     * Check if the plugin is currently shutting down.
     *
     * @return true if shutdown is in progress
     */
    public static boolean isShuttingDown() {
        return SHUTDOWN_IN_PROGRESS.get();
    }

    /**
     * Check if an element should be processed for references.
     * Helps prevent expensive operations on irrelevant elements.
     *
     * @param element The PSI element to check
     * @return true if the element should be processed
     */
    public static boolean shouldProcessElement(@NotNull PsiElement element) {
        if (SHUTDOWN_IN_PROGRESS.get()) {
            return false;
        }

        try {
            PsiFile file = element.getContainingFile();
            if (file == null) {
                return false;
            }

            // Skip files that might cause performance issues
            HarbourReferenceService service = HarbourReferenceService.getInstance(element.getProject());
            if (file.getVirtualFile() != null && service.isExcluded(file.getVirtualFile())) {
                return false;
            }

            return true;
        } catch (Exception e) {
            // Handle any exceptions from invalid PSI
            return false;
        }
    }

    /**
     * Configure chunk sizes for optimal performance.
     */
    private static void configureChunkSizes() {
        // Get available processors but cap at a reasonable number to prevent too much parallelism
        int processors = Math.min(Runtime.getRuntime().availableProcessors(), 4);
        System.setProperty("idea.indexing.chunk.size", String.valueOf(100 * processors));
    }

    /**
     * Schedule periodic cache cleanup to prevent memory leaks.
     */
    private static void scheduleCleanup() {
        if (CLEANUP_SCHEDULED.compareAndSet(false, true)) {
            cleanupTask = AppExecutorUtil.getAppScheduledExecutorService().scheduleWithFixedDelay(
                    () -> {
                        if (!SHUTDOWN_IN_PROGRESS.get()) {
                            LOG.debug("Running scheduled cache cleanup");
                            CACHE.clear();
                        }
                    },
                    30, 30, TimeUnit.MINUTES
            );
        }
    }
}
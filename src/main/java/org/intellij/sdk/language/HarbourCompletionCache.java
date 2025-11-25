package org.intellij.sdk.language;

import com.intellij.openapi.components.Service;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.vfs.VirtualFileManager;
import com.intellij.openapi.vfs.newvfs.BulkFileListener;
import com.intellij.openapi.vfs.newvfs.events.VFileEvent;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.util.messages.MessageBusConnection;
import org.jetbrains.annotations.NotNull;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Cache for Harbour completion items to improve performance.
 * Caches user-defined functions from the project and invalidates on file changes.
 */
@Service(Service.Level.PROJECT)
public final class HarbourCompletionCache {

    private final Project project;
    private final Map<String, Set<String>> fileFunctionsCache=new ConcurrentHashMap<>();
    private volatile Set<String> allProjectFunctions=null;
    private volatile long lastCacheTime=0;
    private static final long CACHE_VALIDITY_MS=5000; // Cache valid for 5 seconds
    private final Object cacheLock=new Object();

    public HarbourCompletionCache(Project project) {
        this.project=project;
        setupFileChangeListener();
        HarbourLogger.log("CompletionCache", "Initialized completion cache for project");
    }

    public static HarbourCompletionCache getInstance(@NotNull Project project) {
        return project.getService(HarbourCompletionCache.class);
    }

    /**
     * Get all user-defined functions from the project (cached)
     */
    public Set<String> getAllProjectFunctions() {
        synchronized (cacheLock) {
            long currentTime=System.currentTimeMillis();

            // Return cached result if still valid
            if (allProjectFunctions != null && (currentTime - lastCacheTime) < CACHE_VALIDITY_MS) {
                HarbourLogger.log("CompletionCache", "Returning cached functions: " + allProjectFunctions.size());
                return new HashSet<>(allProjectFunctions);
            }

            // Rebuild cache
            HarbourLogger.log("CompletionCache", "Cache expired or invalid, rebuilding...");
            rebuildCache();

            lastCacheTime=currentTime;
            return new HashSet<>(allProjectFunctions);
        }
    }

    /**
     * Rebuild the entire cache by scanning all project files
     */
    private void rebuildCache() {
        Set<String> functions=new HashSet<>();

        try {
            ReadAction.run(() -> {
                try {
                    // Get all Harbour files in the project
                    Collection<VirtualFile> virtualFiles=FileTypeIndex.getFiles(
                            HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

                    HarbourLogger.log("CompletionCache", "Scanning " + virtualFiles.size() + " files");

                    PsiManager psiManager=PsiManager.getInstance(project);
                    int fileCount=0;

                    for (VirtualFile virtualFile : virtualFiles) {
                        ProgressManager.checkCanceled();

                        // Skip excluded files
                        if (HarbourFileUtils.isFileExcluded(project, virtualFile)) {
                            continue;
                        }

                        // Get file content and scan for function declarations
                        PsiFile psiFile=psiManager.findFile(virtualFile);
                        if (psiFile != null) {
                            fileCount++;
                            String content=psiFile.getText();
                            Set<String> fileFunctions=scanTextForFunctions(content);

                            // Cache per-file results
                            fileFunctionsCache.put(virtualFile.getPath(), fileFunctions);
                            functions.addAll(fileFunctions);

                            if (fileCount % 50 == 0) {
                                HarbourLogger.log("CompletionCache", "Scanned " + fileCount + " files, found " +
                                        functions.size() + " functions");
                            }
                        }
                    }

                    HarbourLogger.log("CompletionCache", "Cache rebuilt: " + fileCount + " files, " +
                            functions.size() + " total functions");

                } catch (Exception e) {
                    HarbourLogger.log("CompletionCache", "Error rebuilding cache: " + e.getMessage());
                }
            });
        } catch (Exception e) {
            HarbourLogger.log("CompletionCache", "Error in ReadAction: " + e.getMessage());
        }

        allProjectFunctions=functions;
    }

    /**
     * Scan text content for function declarations
     */
    private Set<String> scanTextForFunctions(String content) {
        Set<String> functions=new HashSet<>();

        try {
            // Match patterns for FUNCTION and PROCEDURE declarations
            Pattern functionPattern=Pattern.compile("(?i)\\b(FUNCTION|PROCEDURE)\\s+(\\w+)");
            Matcher matcher=functionPattern.matcher(content);

            while (matcher.find()) {
                ProgressManager.checkCanceled();

                String functionName=matcher.group(2);
                if (functionName != null && !functionName.isEmpty()) {
                    functions.add(functionName);
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionCache", "Error scanning text: " + e.getMessage());
        }

        return functions;
    }

    /**
     * Invalidate cache when files change
     */
    private void setupFileChangeListener() {
        MessageBusConnection connection=project.getMessageBus().connect();
        connection.subscribe(VirtualFileManager.VFS_CHANGES, new BulkFileListener() {
            @Override
            public void after(@NotNull List<? extends VFileEvent> events) {
                boolean harbourFileChanged=false;

                for (VFileEvent event : events) {
                    VirtualFile file=event.getFile();
                    if (file != null && isHarbourFile(file)) {
                        harbourFileChanged=true;

                        // Remove this file from cache
                        fileFunctionsCache.remove(file.getPath());
                    }
                }

                if (harbourFileChanged) {
                    synchronized (cacheLock) {
                        // Invalidate the cache
                        allProjectFunctions=null;
                        lastCacheTime=0;
                        HarbourLogger.log("CompletionCache", "Cache invalidated due to file changes");
                    }
                }
            }
        });
    }

    /**
     * Check if a file is a Harbour file
     */
    private boolean isHarbourFile(VirtualFile file) {
        if (file == null) return false;
        String extension=file.getExtension();
        return extension != null && (extension.equalsIgnoreCase("prg") ||
                                      extension.equalsIgnoreCase("ch") ||
                                      extension.equalsIgnoreCase("hb"));
    }

    /**
     * Clear the entire cache
     */
    public void clearCache() {
        synchronized (cacheLock) {
            fileFunctionsCache.clear();
            allProjectFunctions=null;
            lastCacheTime=0;
            HarbourLogger.log("CompletionCache", "Cache cleared");
        }
    }
}

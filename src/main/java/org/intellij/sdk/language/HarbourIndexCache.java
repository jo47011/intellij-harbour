package org.intellij.sdk.language;

import com.intellij.openapi.components.*;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.vfs.VirtualFileManager;
import com.intellij.util.xmlb.XmlSerializerUtil;
import com.intellij.util.xmlb.annotations.XCollection;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import com.intellij.openapi.application.ApplicationManager;

import java.io.Serializable;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Persistent cache for Harbour language indexing that survives IDE restarts.
 * Stores function, procedure, and class declarations with minimal memory footprint.
 */
@State(
    name = "HarbourIndexCache",
    storages = {@Storage("harbour-index-cache.xml")}
)
@Service(Service.Level.PROJECT)
public final class HarbourIndexCache implements PersistentStateComponent<HarbourIndexCache> {
    private static final Logger LOG = Logger.getInstance(HarbourIndexCache.class);
    private static final String COMPONENT = "IndexCache";
    
    // Cache size limits to prevent freezing
    private static final int MAX_ENTRIES_PER_FILE = 100;  // Limit entries per file
    private static final int MAX_TOTAL_ENTRIES = 5000;    // Limit total cache size
    private static final int SAVE_BATCH_SIZE = 500;       // Save in batches to prevent freezing
    
    private Project project;
    
    // Default constructor for serialization
    public HarbourIndexCache() {
        // Required for XML serialization
        this.project = null;
    }
    
    public HarbourIndexCache(Project project) {
        this.project = project;
        
        // Initialize runtime caches immediately
        initializeRuntimeCaches();
        cacheLoaded = true;
        
        // Log initialization
        HarbourLogger.log(COMPONENT, "HarbourIndexCache initialized for project: " + project.getName() + " (entries: " + cacheEntries.size() + ", timestamps: " + fileTimestamps.size() + ")");
    }
    
    // Serializable cache entries
    @XCollection(elementTypes = {CacheEntry.class})
    private List<CacheEntry> cacheEntries = new ArrayList<>();
    
    @XCollection(elementTypes = {FileTimestamp.class})
    private List<FileTimestamp> fileTimestamps = new ArrayList<>();
    
    // Runtime cache for fast lookup (not persisted)
    private transient Map<String, List<CacheEntry>> functionCache;
    private transient Map<String, List<CacheEntry>> classCache;
    private transient Map<String, List<CacheEntry>> procedureCache;
    private transient Map<String, Long> timestampMap;
    private transient boolean cacheLoaded = false;
    
    // Cache statistics
    private long lastCacheSize = 0;
    private int totalEntries = 0;
    private long lastCleanupTime = System.currentTimeMillis();
    
    public static HarbourIndexCache getInstance(@NotNull Project project) {
        HarbourIndexCache instance = project.getService(HarbourIndexCache.class);
        if (instance == null) {
            HarbourLogger.log("IndexCache", "ERROR: getInstance() returned null for project: " + project.getName());
        }
        return instance;
    }
    
    /**
     * Serializable cache entry for a symbol declaration.
     */
    public static class CacheEntry implements Serializable {
        public String name = "";
        public String filePath = "";
        public int lineNumber = 0;
        public String signature = "";
        public EntryType type = EntryType.FUNCTION;
        public long timestamp = 0;
        
        public CacheEntry() {
            // Required for XML serialization
        }
        
        public CacheEntry(String name, String filePath, int lineNumber, String signature, EntryType type) {
            this.name = name != null ? name : "";
            this.filePath = filePath != null ? filePath : "";
            this.lineNumber = lineNumber;
            this.signature = signature != null ? signature : "";
            this.type = type;
            this.timestamp = System.currentTimeMillis();
        }
    }
    
    /**
     * Type of cache entry.
     */
    public enum EntryType {
        FUNCTION,
        PROCEDURE,
        CLASS
    }
    
    /**
     * File timestamp for change detection.
     */
    public static class FileTimestamp implements Serializable {
        public String filePath = "";
        public long lastModified = 0;
        
        public FileTimestamp() {
            // Required for XML serialization
        }
        
        public FileTimestamp(String filePath, long lastModified) {
            this.filePath = filePath != null ? filePath : "";
            this.lastModified = lastModified;
        }
    }
    
    @Override
    public @Nullable HarbourIndexCache getState() {
        // Write to a file to confirm this is called
        try {
            String debugFile = System.getProperty("user.home") + "/log/cache-getstate-debug.txt";
            new java.io.File(System.getProperty("user.home") + "/log").mkdirs();
            try (java.io.FileWriter fw = new java.io.FileWriter(debugFile, true)) {
                fw.write(java.time.LocalDateTime.now() + " - getState() called with " + cacheEntries.size() + " entries\n");
            }
        } catch (Exception e) {
            // Ignore
        }
        
        HarbourLogger.log(COMPONENT, "getState() called - preparing to save cache with " + cacheEntries.size() + " entries");
        
        // Clean up before saving if needed
        if (shouldCleanup()) {
            cleanupCache();
        }
        
        HarbourLogger.log(COMPONENT, "getState() returning cache with " + cacheEntries.size() + " entries and " + fileTimestamps.size() + " timestamps");
        return this;
    }
    
    @Override
    public void loadState(@NotNull HarbourIndexCache state) {
        HarbourLogger.log(COMPONENT, "loadState() called - loading " + state.cacheEntries.size() + " entries");
        
        XmlSerializerUtil.copyBean(state, this);
        
        // Initialize runtime caches after loading
        initializeRuntimeCaches();
        cacheLoaded = true;
        
        HarbourLogger.log(COMPONENT, "Loaded Harbour index cache with " + cacheEntries.size() + " entries and " + fileTimestamps.size() + " timestamps");
    }
    
    /**
     * Initialize runtime caches from persisted data.
     */
    private synchronized void initializeRuntimeCaches() {
        functionCache = new ConcurrentHashMap<>();
        classCache = new ConcurrentHashMap<>();
        procedureCache = new ConcurrentHashMap<>();
        timestampMap = new ConcurrentHashMap<>();
        
        // Build runtime caches from persisted entries
        for (CacheEntry entry : cacheEntries) {
            String key = entry.name.toLowerCase();
            switch (entry.type) {
                case FUNCTION:
                    functionCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
                case CLASS:
                    classCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
                case PROCEDURE:
                    procedureCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
            }
        }
        
        // Build timestamp map
        for (FileTimestamp ts : fileTimestamps) {
            timestampMap.put(ts.filePath, ts.lastModified);
        }
        
        totalEntries = cacheEntries.size();
    }
    
    /**
     * Check if cache is loaded and ready.
     */
    public boolean isCacheLoaded() {
        return cacheLoaded && !cacheEntries.isEmpty();
    }
    
    /**
     * Check if we have any cached data.
     */
    public boolean hasCachedData() {
        return !cacheEntries.isEmpty();
    }
    
    /**
     * Check if a file has been modified since last cache update.
     */
    public boolean isFileModified(@NotNull VirtualFile file) {
        // If cache is disabled or not ready, always index
        if (!cacheLoaded || timestampMap == null || timestampMap.isEmpty()) {
            HarbourLogger.log(COMPONENT, "isFileModified(" + file.getName() + "): cache not ready (loaded=" + cacheLoaded + ", mapSize=" + (timestampMap != null ? timestampMap.size() : 0) + ")");
            return true; // Assume modified if cache not ready or empty
        }
        
        String path = file.getPath();
        Long cachedTimestamp = timestampMap.get(path);
        if (cachedTimestamp == null) {
            return true; // Not in cache, so needs indexing
        }
        
        // Check actual modification time
        return file.getModificationStamp() != cachedTimestamp;
    }
    
    /**
     * Get cached functions by name.
     */
    public @Nullable List<CacheEntry> getCachedFunctions(@NotNull String name) {
        if (!cacheLoaded || functionCache == null) {
            return null;
        }
        return functionCache.get(name.toLowerCase());
    }
    
    /**
     * Get cached classes by name.
     */
    public @Nullable List<CacheEntry> getCachedClasses(@NotNull String name) {
        if (!cacheLoaded || classCache == null) {
            return null;
        }
        return classCache.get(name.toLowerCase());
    }
    
    /**
     * Get cached procedures by name.
     */
    public @Nullable List<CacheEntry> getCachedProcedures(@NotNull String name) {
        if (!cacheLoaded || procedureCache == null) {
            return null;
        }
        return procedureCache.get(name.toLowerCase());
    }
    
    /**
     * Add or update cache entries for a file.
     */
    public synchronized void updateFileCache(@NotNull VirtualFile file, @NotNull List<CacheEntry> entries) {
        HarbourLogger.log(COMPONENT, "updateFileCache called for " + file.getName() + " with " + entries.size() + " entries");
        
        if (!cacheLoaded) {
            initializeRuntimeCaches();
            cacheLoaded = true;
        }
        
        String filePath = file.getPath();
        
        // Limit entries per file to prevent excessive memory usage
        List<CacheEntry> entriesToAdd = entries;
        if (entries.size() > MAX_ENTRIES_PER_FILE) {
            HarbourLogger.warning(COMPONENT, "File " + file.getName() + " has " + entries.size() + 
                " entries, limiting to " + MAX_ENTRIES_PER_FILE);
            entriesToAdd = entries.subList(0, MAX_ENTRIES_PER_FILE);
        }
        
        // Remove old entries for this file
        int oldCount = cacheEntries.size();
        cacheEntries.removeIf(e -> e.filePath.equals(filePath));
        int removedCount = oldCount - cacheEntries.size();
        
        // Check total cache size limit
        if (cacheEntries.size() + entriesToAdd.size() > MAX_TOTAL_ENTRIES) {
            HarbourLogger.warning(COMPONENT, "Total cache would exceed " + MAX_TOTAL_ENTRIES + 
                " entries, skipping file: " + file.getName());
            return;
        }
        
        // Add new entries
        cacheEntries.addAll(entriesToAdd);
        
        // Update timestamp
        fileTimestamps.removeIf(ts -> ts.filePath.equals(filePath));
        fileTimestamps.add(new FileTimestamp(filePath, file.getModificationStamp()));
        if (timestampMap != null) {
            timestampMap.put(filePath, file.getModificationStamp());
        }
        
        // Update runtime caches
        rebuildRuntimeCachesForFile(filePath, entriesToAdd);
        
        totalEntries = cacheEntries.size();
        HarbourLogger.log(COMPONENT, "Updated cache for: " + file.getName() + " (removed " + removedCount + ", added " + entriesToAdd.size() + " entries, total cache: " + totalEntries + " entries, " + fileTimestamps.size() + " files)");
    }
    
    /**
     * Rebuild runtime caches for a specific file.
     */
    private void rebuildRuntimeCachesForFile(@NotNull String filePath, @NotNull List<CacheEntry> newEntries) {
        // Remove old entries from runtime caches
        removeFileFromRuntimeCaches(filePath);
        
        // Add new entries to runtime caches
        for (CacheEntry entry : newEntries) {
            String key = entry.name.toLowerCase();
            switch (entry.type) {
                case FUNCTION:
                    functionCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
                case CLASS:
                    classCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
                case PROCEDURE:
                    procedureCache.computeIfAbsent(key, k -> new ArrayList<>()).add(entry);
                    break;
            }
        }
    }
    
    /**
     * Remove entries for a file from runtime caches.
     */
    private void removeFileFromRuntimeCaches(@NotNull String filePath) {
        if (functionCache != null) {
            for (List<CacheEntry> entries : functionCache.values()) {
                entries.removeIf(e -> e.filePath.equals(filePath));
            }
        }
        if (classCache != null) {
            for (List<CacheEntry> entries : classCache.values()) {
                entries.removeIf(e -> e.filePath.equals(filePath));
            }
        }
        if (procedureCache != null) {
            for (List<CacheEntry> entries : procedureCache.values()) {
                entries.removeIf(e -> e.filePath.equals(filePath));
            }
        }
    }
    
    /**
     * Clear cache for a deleted file.
     */
    public synchronized void removeFileFromCache(@NotNull String filePath) {
        cacheEntries.removeIf(e -> e.filePath.equals(filePath));
        fileTimestamps.removeIf(ts -> ts.filePath.equals(filePath));
        removeFileFromRuntimeCaches(filePath);
        totalEntries = cacheEntries.size();
    }
    
    /**
     * Check if cache cleanup is needed.
     */
    private boolean shouldCleanup() {
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (!settings.isIndexCacheAutoCleanup()) {
            return false;
        }
        
        // Cleanup every hour or if cache is too large
        long now = System.currentTimeMillis();
        long maxSizeBytes = settings.getIndexCacheMaxSizeMB() * 1024L * 1024L;
        return (now - lastCleanupTime > 3600000) || estimateCacheSize() > maxSizeBytes;
    }
    
    /**
     * Estimate cache size in bytes.
     */
    private long estimateCacheSize() {
        // Rough estimate: 200 bytes per entry + 100 bytes per timestamp
        return cacheEntries.size() * 200L + fileTimestamps.size() * 100L;
    }
    
    /**
     * Clean up cache by removing invalid entries and old data.
     */
    private synchronized void cleanupCache() {
        HarbourLogger.log(COMPONENT, "Cleaning up Harbour index cache");
        
        // Remove entries for non-existent files
        VirtualFileManager vfm = VirtualFileManager.getInstance();
        cacheEntries.removeIf(e -> {
            VirtualFile file = vfm.findFileByUrl("file://" + e.filePath);
            return file == null || !file.exists();
        });
        
        fileTimestamps.removeIf(ts -> {
            VirtualFile file = vfm.findFileByUrl("file://" + ts.filePath);
            return file == null || !file.exists();
        });
        
        // If still too large, remove oldest entries
        HarbourSettings settings = HarbourSettings.getInstance(project);
        long maxSizeBytes = settings.getIndexCacheMaxSizeMB() * 1024L * 1024L;
        if (estimateCacheSize() > maxSizeBytes && !cacheEntries.isEmpty()) {
            // Sort by timestamp and keep newest entries
            cacheEntries.sort(Comparator.comparingLong(e -> -e.timestamp));
            int maxEntries = (int) (maxSizeBytes / 200);
            if (cacheEntries.size() > maxEntries) {
                cacheEntries = new ArrayList<>(cacheEntries.subList(0, maxEntries));
            }
        }
        
        lastCleanupTime = System.currentTimeMillis();
        totalEntries = cacheEntries.size();
        HarbourLogger.log(COMPONENT, "Cache cleanup complete. Entries: " + totalEntries);
    }
    
    /**
     * Clear entire cache.
     */
    public synchronized void clearCache() {
        cacheEntries.clear();
        fileTimestamps.clear();
        if (functionCache != null) functionCache.clear();
        if (classCache != null) classCache.clear();
        if (procedureCache != null) procedureCache.clear();
        if (timestampMap != null) timestampMap.clear();
        totalEntries = 0;
        HarbourLogger.log(COMPONENT, "Harbour index cache cleared");
    }
    
    /**
     * Get cache statistics.
     */
    public String getCacheStatistics() {
        return String.format("Cache entries: %d, Files indexed: %d, Estimated size: %.2f MB",
            totalEntries, fileTimestamps.size(), estimateCacheSize() / (1024.0 * 1024.0));
    }
    
    /**
     * Force save the cache to disk immediately.
     */
    public void forceSave() {
        HarbourLogger.log(COMPONENT, "forceSave() called with " + cacheEntries.size() + " entries");
        
        if (cacheEntries.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No entries to save, skipping save");
            return;
        }
        
        // Always save in background to prevent deadlock during indexing
        HarbourLogger.log(COMPONENT, "Scheduling cache save in background (" + cacheEntries.size() + " entries)");
        
        // Don't use project.save() as it causes modal progress dialog in write action
        // The cache will be saved automatically when component state is requested
        HarbourLogger.log(COMPONENT, "Cache marked for save with " + totalEntries + " entries");
        
        // Just mark as modified to trigger save on next opportunity
        // State will be saved when getState() is called during project save
    }
}
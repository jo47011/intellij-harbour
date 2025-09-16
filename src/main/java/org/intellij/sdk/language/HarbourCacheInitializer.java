package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.ProjectActivity;
import kotlin.Unit;
import kotlin.coroutines.Continuation;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import java.io.FileWriter;
import java.time.LocalDateTime;

/**
 * Project activity to ensure the Harbour index cache is initialized early.
 * This helps with cache persistence by ensuring the service is created
 * when the project opens.
 */
public class HarbourCacheInitializer implements ProjectActivity {
    
    @Nullable
    @Override
    public Object execute(@NotNull Project project, @NotNull Continuation<? super Unit> continuation) {
        // Write a simple debug file to confirm startup
        try {
            String debugFile = System.getProperty("user.home") + "/log/harbour-startup-debug.txt";
            new java.io.File(System.getProperty("user.home") + "/log").mkdirs();
            try (FileWriter fw = new FileWriter(debugFile, true)) {
                fw.write(LocalDateTime.now() + " - HarbourCacheInitializer started for: " + project.getName() + "\n");
            }
        } catch (Exception e) {
            // Ignore
        }
        
        // Log immediately to verify this is being called
        HarbourLogger.log("CacheInitializer", "=== STARTUP: HarbourCacheInitializer.runActivity() called for project: " + project.getName() + " ===");
        
        // Initialize the cache service early to ensure it's ready for indexing
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings.isIndexCacheEnabled()) {
            HarbourIndexCache cache = HarbourIndexCache.getInstance(project);
            if (cache != null) {
                HarbourLogger.log("CacheInitializer", "Cache service initialized on project open for: " + project.getName());
                
                // Log cache status
                HarbourLogger.log("CacheInitializer", "Cache status - Has data: " + cache.hasCachedData() + 
                                 ", Loaded: " + cache.isCacheLoaded());
            } else {
                HarbourLogger.error("CacheInitializer", "Failed to initialize cache service for project: " + project.getName());
            }
        }
        
        // Start progressive indexing of Harbour files
        HarbourLogger.log("CacheInitializer", "=== STARTUP: About to start progressive indexing for project: " + project.getName() + " ===");
        try {
            HarbourProgressiveIndexer.startProgressiveIndexing(project);
            HarbourLogger.log("CacheInitializer", "=== STARTUP: Progressive indexing started successfully ===");
        } catch (Exception e) {
            HarbourLogger.error("CacheInitializer", "=== STARTUP: Failed to start progressive indexing: " + e.getMessage() + " ===");
            e.printStackTrace();
        }
        
        // Return Unit to indicate completion
        return Unit.INSTANCE;
    }
}
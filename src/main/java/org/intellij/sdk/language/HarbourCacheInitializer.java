package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import org.jetbrains.annotations.NotNull;

/**
 * Startup activity to ensure the Harbour index cache is initialized early.
 * This helps with cache persistence by ensuring the service is created
 * when the project opens.
 */
public class HarbourCacheInitializer implements StartupActivity {
    
    @Override
    public void runActivity(@NotNull Project project) {
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
    }
}
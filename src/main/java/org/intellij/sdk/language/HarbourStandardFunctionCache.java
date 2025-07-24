package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import org.jetbrains.annotations.NotNull;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fast cache for Harbour function classification to improve rendering performance.
 * This cache uses dynamic classification instead of hardcoded function lists.
 */
public class HarbourStandardFunctionCache {
    private static final Logger LOG = Logger.getInstance(HarbourStandardFunctionCache.class);
    private static final Map<String, Boolean> FUNCTION_CLASSIFICATION_CACHE = new ConcurrentHashMap<>();
    private static volatile boolean initialized = false;

    /**
     * Checks if a function is an external function (not defined in project) using dynamic classification.
     *
     * @param functionName The function name to check
     * @return true if it's an external function
     */
    public static boolean isStandardFunction(@NotNull String functionName) {
        String normalizedName = functionName.toLowerCase();
        
        // Check cache first
        Boolean cachedResult = FUNCTION_CLASSIFICATION_CACHE.get(normalizedName);
        if (cachedResult != null) {
            return cachedResult;
        }
        
        // If not in cache, use dynamic classification
        // Try to get from any open project (limitation of static method)
        boolean isExternal = true; // Default to external for safety
        for (Project openProject : com.intellij.openapi.project.ProjectManager.getInstance().getOpenProjects()) {
            HarbourFunctionClassificationService classificationService = 
                HarbourFunctionClassificationService.getInstance(openProject);
            if (classificationService.isInitialized()) {
                isExternal = classificationService.isExternalFunction(functionName);
                break;
            }
        }
        
        // Cache the result
        FUNCTION_CLASSIFICATION_CACHE.put(normalizedName, isExternal);
        return isExternal;
    }

    /**
     * Initialize the cache for dynamic classification.
     * This is called during plugin startup.
     */
    private static void initializeCache() {
        if (initialized) {
            return;
        }

        LOG.info("Initializing function classification cache (dynamic mode)");
        
        // No hardcoded functions to initialize - cache will be populated dynamically
        initialized = true;
        LOG.info("Function classification cache initialized in dynamic mode");
    }

    /**
     * Initialize the full cache with dynamic classification.
     * This is called at a later stage to ensure the classification service is ready.
     */
    public static void initializeFullCache(Project project) {
        LOG.info("Initializing full function classification cache");

        // Ensure provider is initialized
        HarbourStandardFunctionsProvider.initialize(project);
        
        // Ensure classification service is initialized
        HarbourFunctionClassificationService classificationService = 
            HarbourFunctionClassificationService.getInstance(project);
        
        LOG.info("Full function classification cache ready with dynamic classification");
    }

    /**
     * Add a function classification result to the cache.
     *
     * @param functionName The function name to cache
     * @param isExternal Whether the function is external (true) or internal (false)
     */
    public static void cacheFunctionClassification(@NotNull String functionName, boolean isExternal) {
        FUNCTION_CLASSIFICATION_CACHE.put(functionName.toLowerCase(), isExternal);
    }
    
    /**
     * Clear the classification cache to force re-evaluation.
     * This should be called when project files change significantly.
     */
    public static void clearCache() {
        FUNCTION_CLASSIFICATION_CACHE.clear();
        LOG.info("Function classification cache cleared");
    }

    /**
     * Initializer for the cache that runs during plugin startup.
     */
    public static class Initializer implements StartupActivity.DumbAware {
        @Override
        public void runActivity(@NotNull Project project) {
            LOG.info("Running standard function cache initializer");

            // Initialize basic cache right away
            initializeCache();

            // Schedule full initialization to happen later
            HarbourPerformanceOptimizer.submitBackgroundTask(() -> {
                initializeFullCache(project);
            });
            
            LOG.info("Function classification cache initializer completed");
        }
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import org.jetbrains.annotations.NotNull;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fast cache for standard Harbour functions to improve rendering performance.
 * This cache is initialized during plugin startup before editors are opened.
 */
public class HarbourStandardFunctionCache {
    private static final Logger LOG = Logger.getInstance(HarbourStandardFunctionCache.class);
    private static final Map<String, Boolean> STANDARD_FUNCTION_CACHE = new ConcurrentHashMap<>();
    private static volatile boolean initialized = false;

    /**
     * Checks if a function is a standard function without expensive lookups.
     *
     * @param functionName The function name to check
     * @return true if it's a standard function
     */
    public static boolean isStandardFunction(@NotNull String functionName) {
        if (!initialized) {
            // Fallback to direct check if not initialized
            return HarbourStandardFunctionsProvider.isStandardFunction(functionName);
        }

        String normalizedName = functionName.toLowerCase();
        Boolean result = STANDARD_FUNCTION_CACHE.get(normalizedName);
        return result != null && result;
    }

    /**
     * Initialize the cache with standard functions.
     * This is called during plugin startup.
     */
    private static void initializeCache() {
        if (initialized) {
            return;
        }

        LOG.info("Initializing standard function cache");

        // Add commonly used functions from annotator
        String[] commonFunctions = {
                "chr", "upper", "lower", "trim", "ltrim", "rtrim", "valtype", "transform",
                "empty", "alias", "aadd", "ascan", "asize", "atail", "len", "eval",
                "db_info", "dbf", "recno", "ordname", "str", "substr", "left", "right",
                "val", "int", "dtos", "stod", "day", "month", "year", "date",
                "time", "round", "ceiling", "floor", "max", "min", "abs", "sqrt"
        };

        for (String func : commonFunctions) {
            STANDARD_FUNCTION_CACHE.put(func.toLowerCase(), true);
        }

        // Mark as initialized
        initialized = true;
        LOG.info("Standard function cache initialized with " + STANDARD_FUNCTION_CACHE.size() + " functions");
    }

    /**
     * Initialize the full cache with all standard functions.
     * This is called at a later stage to ensure all standard functions are cached.
     */
    public static void initializeFullCache(Project project) {
        LOG.info("Initializing full standard function cache");

        // Ensure provider is initialized
        HarbourStandardFunctionsProvider.initialize(project);

        // Add all standard functions from provider (which has the complete list)
        Set<String> standardFunctions = HarbourStandardFunctionsProvider.getAllStandardFunctions();
        for (String func : standardFunctions) {
            if (!STANDARD_FUNCTION_CACHE.containsKey(func.toLowerCase())) {
                STANDARD_FUNCTION_CACHE.put(func.toLowerCase(), true);
            }
        }

        LOG.info("Full standard function cache initialized with " + STANDARD_FUNCTION_CACHE.size() + " functions");
    }

    /**
     * Add a function to the standard function cache.
     *
     * @param functionName The function name to add
     */
    public static void addStandardFunction(@NotNull String functionName) {
        STANDARD_FUNCTION_CACHE.put(functionName.toLowerCase(), true);
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
        }
    }
}
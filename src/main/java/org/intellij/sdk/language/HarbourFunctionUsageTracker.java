package org.intellij.sdk.language;

import com.intellij.openapi.Disposable;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.Disposer;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiElement;

import java.util.Map;
import java.util.Set;
import java.util.HashSet;
import java.util.WeakHashMap;
import java.util.Collections;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Tracks function usage across the project to identify "critical functions"
 * that should be treated specially during initial rendering.
 */
public class HarbourFunctionUsageTracker {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionUsageTracker.class);

    // Use WeakHashMap to allow garbage collection of disposed projects
    // Synchronized because WeakHashMap is not thread-safe
    private static final Map<Project, Map<String, AtomicInteger>> FUNCTION_USAGE = 
        Collections.synchronizedMap(new WeakHashMap<>());

    // Use WeakHashMap to allow garbage collection of disposed projects
    private static final Map<Project, Map<String, Boolean>> FUNCTION_STATUS = 
        Collections.synchronizedMap(new WeakHashMap<>());

    // Threshold for considering a function as "frequently used"
    private static final int FREQUENCY_THRESHOLD = 3;

    /**
     * Record a function usage in the project
     *
     * @param project The project
     * @param functionName The function name
     */
    public static void recordFunctionUsage(Project project, String functionName) {
        // Skip if the project is disposed
        if (project == null || project.isDisposed()) {
            return;
        }

        String normalizedName = functionName.toLowerCase();

        // Get or create project map
        Map<String, AtomicInteger> projectUsage = FUNCTION_USAGE.computeIfAbsent(
                project, p -> {
                    // Register cleanup when project is disposed
                    registerProjectCleanup(p);
                    return new ConcurrentHashMap<>();
                });

        // Increment usage count
        projectUsage.computeIfAbsent(normalizedName, k -> new AtomicInteger(0))
                .incrementAndGet();
    }
    
    /**
     * Register cleanup for when project is disposed
     */
    private static void registerProjectCleanup(Project project) {
        if (project != null && !project.isDisposed()) {
            Disposer.register(project, new Disposable() {
                @Override
                public void dispose() {
                    clearProject(project);
                }
            });
        }
    }

    /**
     * Check if a function is frequently used in the project
     *
     * @param project The project
     * @param functionName The function name
     * @return true if the function is frequently used
     */
    public static boolean isFrequentlyUsed(Project project, String functionName) {
        // Skip if the project is null or disposed
        if (project == null || project.isDisposed()) {
            return false;
        }

        String normalizedName = functionName.toLowerCase();
        Map<String, AtomicInteger> projectUsage = FUNCTION_USAGE.get(project);

        if (projectUsage == null) {
            return false;
        }

        AtomicInteger count = projectUsage.get(normalizedName);
        return count != null && count.get() >= FREQUENCY_THRESHOLD;
    }

    /**
     * Update the status of a function after it's been actually found in the project
     *
     * @param project The project
     * @param functionName The function name
     * @param isLocal Whether it's actually a local function
     */
    public static void updateFunctionStatus(Project project, String functionName, boolean isLocal) {
        // Skip if the project is null or disposed
        if (project == null || project.isDisposed()) {
            return;
        }

        String normalizedName = functionName.toLowerCase();

        // Get or create project map
        Map<String, Boolean> statusMap = FUNCTION_STATUS.computeIfAbsent(
                project, p -> {
                    // Register cleanup when project is disposed if not already registered
                    registerProjectCleanup(p);
                    return new ConcurrentHashMap<>();
                });

        // Set status
        statusMap.put(normalizedName, isLocal);
    }

    /**
     * Check if a function has been found in the project
     * This is used to determine if a function should be treated as local or external
     *
     * @param project The project
     * @param functionName The function name
     * @return true if the function has been found in the project, false otherwise
     */
    public static boolean isFunctionLocal(Project project, String functionName) {
        // Skip if the project is null or disposed
        if (project == null || project.isDisposed()) {
            return false;
        }

        String normalizedName = functionName.toLowerCase();
        Map<String, Boolean> statusMap = FUNCTION_STATUS.get(project);

        if (statusMap == null) {
            return false;
        }

        Boolean status = statusMap.get(normalizedName);
        return status != null && status;
    }

    /**
     * Clear usage data for a project
     *
     * @param project The project to clear data for
     */
    public static void clearProject(Project project) {
        FUNCTION_USAGE.remove(project);
        FUNCTION_STATUS.remove(project);
    }

    /**
     * Get the most frequently used functions in a project
     *
     * @param project The project
     * @param limit Maximum number of functions to return
     * @return Set of frequently used function names
     */
    public static Set<String> getFrequentlyUsedFunctions(Project project, int limit) {
        if (project == null || project.isDisposed()) {
            return new HashSet<>();
        }
        Map<String, AtomicInteger> projectUsage = FUNCTION_USAGE.get(project);
        Set<String> result = new HashSet<>();

        if (projectUsage == null) {
            return result;
        }

        // Sort by usage count and take top 'limit' elements
        projectUsage.entrySet().stream()
                .filter(entry -> entry.getValue().get() >= FREQUENCY_THRESHOLD)
                .sorted((a, b) -> Integer.compare(b.getValue().get(), a.getValue().get()))
                .limit(limit)
                .forEach(entry -> result.add(entry.getKey()));

        return result;
    }
}
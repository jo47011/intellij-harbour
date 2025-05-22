package org.intellij.sdk.language;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.ProcessCanceledException;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * A lightweight cache for function declaration status to improve annotator performance.
 * This is used to quickly determine if a function exists in the project without
 * running expensive PSI operations during rendering.
 */
public class HarbourFunctionDeclarationCache {
    private static final Logger LOG = Logger.getInstance(HarbourFunctionDeclarationCache.class);

    // We use a tri-state cache: true = function exists, false = function doesn't exist, null = unknown
    private static final Map<Project, Map<String, Boolean>> PROJECT_FUNCTION_STATUS = new ConcurrentHashMap<>();

    /**
     * Check if a function exists in the project.
     * This method will use the cache if available, otherwise perform a direct lookup.
     *
     * @param functionName The function name to check
     * @param project The project to search in
     * @return true if the function exists in the project, false otherwise
     */
    public static boolean functionExistsInProject(String functionName, Project project) {
        try {
            // Check for standard functions first (they're external)
            if (HarbourStandardFunctionCache.isStandardFunction(functionName)) {
                return false;
            }

            // Get or create the project's function cache
            Map<String, Boolean> functionCache = PROJECT_FUNCTION_STATUS.computeIfAbsent(
                    project, p -> new ConcurrentHashMap<>());

            // Normalize function name
            String normalizedName = functionName.toLowerCase();

            // Check if we have a cached result
            Boolean cachedResult = functionCache.get(normalizedName);
            if (cachedResult != null) {
                return cachedResult;
            }

            // Perform a direct lookup
            try {
                List<PsiElement> declarations = ReadAction.compute(() -> {
                    ProgressManager.checkCanceled();
                    HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);
                    return referenceService.findFunctions(normalizedName);
                });

                // Cache and return the result
                boolean exists = !declarations.isEmpty();
                functionCache.put(normalizedName, exists);
                return exists;
            } catch (ProcessCanceledException e) {
                throw e;
            } catch (Exception e) {
                LOG.warn("Error checking if function exists: " + normalizedName, e);
                return false;
            }
        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            LOG.error("Unexpected error in function cache", e);
            return false;
        }
    }

    /**
     * Update the cache status for a function.
     * This should be called after successful lookups to improve future performance.
     *
     * @param functionName The function name
     * @param exists Whether the function exists in the project
     * @param project The project
     */
    public static void updateFunctionStatus(String functionName, boolean exists, Project project) {
        try {
            Map<String, Boolean> functionCache = PROJECT_FUNCTION_STATUS.computeIfAbsent(
                    project, p -> new ConcurrentHashMap<>());

            functionCache.put(functionName.toLowerCase(), exists);
        } catch (Exception e) {
            LOG.error("Error updating function cache", e);
        }
    }

    /**
     * Clear the cache for a project.
     *
     * @param project The project to clear the cache for
     */
    public static void clearCache(Project project) {
        PROJECT_FUNCTION_STATUS.remove(project);
    }

    /**
     * Clear the cache for a specific function in all projects.
     * This is useful when a function is added or removed.
     *
     * @param functionName The function name to clear
     */
    public static void clearFunctionCache(String functionName) {
        String normalizedName = functionName.toLowerCase();
        for (Map<String, Boolean> cache : PROJECT_FUNCTION_STATUS.values()) {
            cache.remove(normalizedName);
        }
    }
}
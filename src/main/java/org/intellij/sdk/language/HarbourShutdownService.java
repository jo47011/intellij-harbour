package org.intellij.sdk.language;

import com.intellij.openapi.Disposable;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.openapi.util.Disposer;

/**
 * Service to ensure proper cleanup of resources when plugin is unloaded.
 * This ensures all resources are cleaned up when the IDE is closed.
 */
@Service
public final class HarbourShutdownService implements Disposable {
    private static final Logger LOG = Logger.getInstance(HarbourShutdownService.class);
    private volatile boolean disposed = false;

    public HarbourShutdownService() {
        LOG.info("Harbour plugin shutdown service initialized");
        // Register for application shutdown
        Disposer.register(ApplicationManager.getApplication(), this);
    }

    @Override
    public void dispose() {
        if (disposed) return;
        disposed = true;

        LOG.info("Starting Harbour plugin shutdown process");

        try {
            // First cancel all background tasks
            HarbourPerformanceOptimizer.shutdown();

            // Unregister listeners to prevent further events
            unregisterListeners();

            // Force clear caches in reference service
            clearReferenceCaches();

            LOG.info("Harbour plugin shutdown completed successfully");
        } catch (Exception e) {
            LOG.error("Error during Harbour plugin shutdown", e);
        }
    }

    /**
     * Force clear caches in all reference services to prevent memory leaks
     */
    private void clearReferenceCaches() {
        LOG.info("Clearing reference caches");
        try {
            // Clear caches in all projects
            Project[] projects = ProjectManager.getInstance().getOpenProjects();
            for (Project project : projects) {
                try {
                    if (!project.isDisposed()) {
                        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
                        if (service != null) {
                            service.forceClearCaches();
                        }
                    }
                } catch (Exception e) {
                    LOG.warn("Error clearing caches for project: " + project.getName(), e);
                }
            }
        } catch (Exception e) {
            LOG.warn("Error clearing reference caches", e);
        }
    }

    /**
     * Unregister any global listeners to prevent further events
     */
    private void unregisterListeners() {
        LOG.info("Unregistering global listeners");
        try {
            // Implement listener cleanup if needed
        } catch (Exception e) {
            LOG.warn("Error unregistering listeners", e);
        }
    }

    /**
     * Get the instance of this service.
     * @return the service instance
     */
    public static HarbourShutdownService getInstance() {
        return ApplicationManager.getApplication().getService(HarbourShutdownService.class);
    }
}
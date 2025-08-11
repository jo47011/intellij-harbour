package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.fileEditor.FileDocumentManagerListener;
import org.jetbrains.annotations.NotNull;

/**
 * Application-level service that registers the save listener when created.
 * This ensures the save listener is properly registered for both linting and dynamic function indexing.
 */
@Service(Service.Level.APP)
public final class HarbourSaveListenerService {
    
    public HarbourSaveListenerService() {
        // Register the save listener when this service is created
        HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Registering save listener");
        
        try {
            ApplicationManager.getApplication().getMessageBus()
                    .connect()
                    .subscribe(FileDocumentManagerListener.TOPIC, new HarbourLintOnSaveListener());
                    
            HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Save listener registered successfully");
        } catch (Exception e) {
            HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Error registering save listener: " + e.getMessage());
        }
    }
    
    /**
     * Get the instance of this service (will create it if not already created).
     */
    public static HarbourSaveListenerService getInstance() {
        return ApplicationManager.getApplication().getService(HarbourSaveListenerService.class);
    }
}
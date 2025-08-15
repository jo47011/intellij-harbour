package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.fileEditor.FileDocumentManagerListener;
import org.jetbrains.annotations.NotNull;

/**
 * Application-level service that registers the save listener when created.
 * This ensures the save listener is properly registered for both linting and dynamic function indexing.
 * NOTE: This service is no longer registered in plugin.xml to reduce startup impact.
 * It's created manually on first use.
 */
@Service(Service.Level.APP)
public final class HarbourSaveListenerService {
    
    private static volatile HarbourSaveListenerService instance;
    private volatile boolean initialized = false;
    
    public HarbourSaveListenerService() {
        // Don't register immediately - wait for first use
    }
    
    private void ensureInitialized() {
        if (!initialized) {
            synchronized (this) {
                if (!initialized) {
                    // Register the save listener when first needed
                    HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Registering save listener");
                    
                    try {
                        ApplicationManager.getApplication().getMessageBus()
                                .connect()
                                .subscribe(FileDocumentManagerListener.TOPIC, new HarbourLintOnSaveListener());
                                
                        HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Save listener registered successfully");
                        initialized = true;
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourLinter", "HarbourSaveListenerService: Error registering save listener: " + e.getMessage());
                    }
                }
            }
        }
    }
    
    /**
     * Get the instance of this service (will create it if not already created).
     * Since the service is not registered, we create it manually.
     */
    public static HarbourSaveListenerService getInstance() {
        if (instance == null) {
            synchronized (HarbourSaveListenerService.class) {
                if (instance == null) {
                    instance = new HarbourSaveListenerService();
                }
            }
        }
        instance.ensureInitialized();
        return instance;
    }
}
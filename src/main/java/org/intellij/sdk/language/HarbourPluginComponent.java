package org.intellij.sdk.language;

import com.intellij.notification.Notification;
import com.intellij.notification.NotificationType;
import com.intellij.notification.Notifications;
import com.intellij.openapi.components.ProjectComponent;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;

/**
 * Component loaded when the plugin is initialized.
 */
public class HarbourPluginComponent implements ProjectComponent {
    private static final Logger LOG = Logger.getInstance(HarbourPluginComponent.class);
    private final Project project;

    public HarbourPluginComponent(Project project) {
        this.project = project;
    }

    @Override
    public void projectOpened() {
        LOG.info("Harbour plugin component initialized");
        System.out.println("DEBUG: Harbour plugin component initialized");

        // Register structure view listeners for proper disposal
        HarbourStructureViewFactory.registerDisposableListeners(project);

        showPluginLoadedNotification();
    }

    private void showPluginLoadedNotification() {
        try {
            Notification notification = new Notification(
                    "Harbour Plugin",
                    "Harbour Plugin Loaded",
                    "Harbour/Clipper language support is now active",
                    NotificationType.INFORMATION);

            Notifications.Bus.notify(notification);
            System.out.println("Notification sent: Harbour Plugin Loaded");
        } catch (Exception e) {
            LOG.error("Failed to show notification: " + e.getMessage(), e);
            System.out.println("Failed to show notification: " + e.getMessage());
        }
    }
}
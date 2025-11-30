package org.intellij.sdk.language;

import com.intellij.notification.Notification;
import com.intellij.notification.NotificationGroup;
import com.intellij.notification.NotificationGroupManager;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.actionSystem.ex.AnActionListener;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import org.jetbrains.annotations.NotNull;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Listens for ReformatCode action to show notification when formatting Harbour files.
 * This allows showing a notification BEFORE formatting starts.
 */
public class HarbourFormatActionListener implements AnActionListener {

    // Counter for unique notification IDs to prevent coalescing
    private static final AtomicLong notificationCounter = new AtomicLong(0);

    // Store the current "formatting..." notification so it can be expired when done
    private static Notification currentStartNotification = null;

    @Override
    public void beforeActionPerformed(@NotNull AnAction action, @NotNull AnActionEvent event) {
        // Check if this is a reformat action
        String actionId = event.getActionManager().getId(action);
        if (actionId == null) return;

        // Match ReformatCode action (standard Ctrl+Alt+L)
        if (!actionId.equals("ReformatCode") && !actionId.equals("HarbourFormatAction")) {
            return;
        }

        // Check if we're formatting a Harbour file
        VirtualFile file = event.getData(CommonDataKeys.VIRTUAL_FILE);
        if (file == null) return;

        String extension = file.getExtension();
        if (extension == null || (!extension.equalsIgnoreCase("prg") && !extension.equalsIgnoreCase("ch"))) {
            return;
        }

        // Expire any previous notification
        expireStartNotification();

        // Show balloon notification at START of formatting
        Project project = event.getProject();
        if (project != null) {
            // Get unique ID for message to help prevent coalescing
            long id = notificationCounter.incrementAndGet();
            String fileName = file.getName();

            // Use invokeLater to ensure notification shows before write action starts
            ApplicationManager.getApplication().invokeLater(() -> {
                // Use the registered notification group from plugin.xml
                NotificationGroup notificationGroup = NotificationGroupManager.getInstance()
                    .getNotificationGroup("Harbour Application");

                if (notificationGroup != null) {
                    // Create notification using the registered group (ensures BALLOON type)
                    Notification notification = notificationGroup.createNotification(
                        "Harbour",
                        "Formatting " + fileName + "\u200B".repeat((int)(id % 10 + 1)),
                        NotificationType.INFORMATION
                    );
                    // Store reference for later expiration
                    currentStartNotification = notification;
                    // Show the notification - balloon will appear
                    notification.notify(project);
                }
            });
        }
    }

    /**
     * Expire the "formatting..." notification. Called by PostFormatProcessor when done.
     */
    public static void expireStartNotification() {
        if (currentStartNotification != null) {
            currentStartNotification.expire();
            currentStartNotification = null;
        }
    }
}

package org.intellij.sdk.language;

import com.intellij.notification.Notification;
import com.intellij.notification.NotificationDisplayType;
import com.intellij.notification.NotificationGroup;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.util.SystemInfo;
import org.jetbrains.annotations.NotNull;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Shows a notification when the plugin loads to verify plugin loading on Windows.
 */
public class HarbourPluginNotificationTest implements StartupActivity {
    private static final NotificationGroup NOTIFICATION_GROUP = new NotificationGroup(
        "Harbour Plugin Test", 
        NotificationDisplayType.BALLOON, 
        true
    );
    
    @Override
    public void runActivity(@NotNull Project project) {
        System.out.println("🔧 HarbourPluginNotificationTest v1.0.266 - STARTUP ACTIVITY");
        System.out.println("🔧 OS: " + SystemInfo.getOsNameAndVersion());
        System.out.println("🔧 Project: " + project.getName());
        
        // Log to file for debugging
        try {
            FileWriter fw = new FileWriter("harbour_notification_test.txt", true);
            fw.write("HarbourPluginNotificationTest startup at " + LocalDateTime.now() + "\n");
            fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
            fw.write("Project: " + project.getName() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            System.err.println("Failed to write notification test log: " + e.getMessage());
        }
        
        // Show notification to user - use current version
        String version = "1.0.310";
        String message = "Harbour Plugin v" + version + " loaded successfully on " + SystemInfo.getOsNameAndVersion();
        Notification notification = NOTIFICATION_GROUP.createNotification(
            "Harbour Plugin Test",
            message,
            NotificationType.INFORMATION
        );
        
        notification.notify(project);
        System.out.println("🔧 Notification shown: " + message);
    }
}
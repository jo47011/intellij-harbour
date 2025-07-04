package org.intellij.sdk.language;

import com.intellij.notification.*;
import com.intellij.openapi.project.Project;
import com.intellij.xdebugger.XSourcePosition;

/**
 * Notification helper for Harbour debugger
 */
public class HarbourDebuggerNotification {
    
    private static final NotificationGroup NOTIFICATION_GROUP = 
            NotificationGroupManager.getInstance().getNotificationGroup("Harbour Debugger");
    
    /**
     * Show notification when debugger stops at a breakpoint
     */
    public static void notifyBreakpointHit(Project project, String fileName, int line) {
        String message = String.format("Debugger stopped at %s:%d", fileName, line);
        
        Notification notification = NOTIFICATION_GROUP.createNotification(
                "Harbour Debugger", 
                message, 
                NotificationType.INFORMATION
        );
        
        // Show notification
        notification.notify(project);
        
        // Also play a beep sound
        // java.awt.Toolkit.getDefaultToolkit().beep();  // Commented out - will be configurable in settings later
        
        HarbourLogger.log(project, "HarbourDebuggerNotification", "Notified user: " + message);
    }
    
    /**
     * Show notification for debugger errors
     */
    public static void notifyError(Project project, String message) {
        Notification notification = NOTIFICATION_GROUP.createNotification(
                "Harbour Debugger Error", 
                message, 
                NotificationType.ERROR
        );
        
        notification.notify(project);
        
        HarbourLogger.log(project, "HarbourDebuggerNotification", "Error notification: " + message);
    }
    
    /**
     * Show notification for important debugger events
     */
    public static void notifyEvent(Project project, String title, String message) {
        Notification notification = NOTIFICATION_GROUP.createNotification(
                title, 
                message, 
                NotificationType.INFORMATION
        );
        
        notification.notify(project);
        
        HarbourLogger.log(project, "HarbourDebuggerNotification", "Event notification: " + title + " - " + message);
    }
}
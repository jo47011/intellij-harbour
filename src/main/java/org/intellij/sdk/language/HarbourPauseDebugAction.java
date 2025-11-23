package org.intellij.sdk.language;

import com.intellij.notification.Notification;
import com.intellij.notification.NotificationType;
import com.intellij.notification.Notifications;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.project.Project;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerManager;
import org.jetbrains.annotations.NotNull;

/**
 * Action to pause/break Harbour program execution at current point without requiring a breakpoint.
 * Triggered by Alt-D keyboard shortcut.
 */
public class HarbourPauseDebugAction extends AnAction {

    private static Boolean lastEnabledState = null;

    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        return ActionUpdateThread.BGT;
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        Project project = e.getProject();

        if (project == null) {
            e.getPresentation().setEnabled(false);
            return;
        }

        // Get the current debug session
        XDebugSession session = XDebuggerManager.getInstance(project).getCurrentSession();

        // Enable only if:
        // 1. A debug session is active
        // 2. The debug process is a HarbourDebuggerRemoteProcess
        // 3. The debugger is in RUNNING state (not already suspended)
        boolean shouldEnable = false;

        if (session != null && session.getDebugProcess() instanceof HarbourDebuggerRemoteProcess) {
            HarbourDebuggerRemoteProcess process = (HarbourDebuggerRemoteProcess) session.getDebugProcess();
            // Only enable when debugger is running (not suspended, not disconnected)
            shouldEnable = process.getDebuggerState() == HarbourDebuggerRemoteProcess.DebuggerState.RUNNING;

            // Log only when state changes
            if (lastEnabledState == null || lastEnabledState != shouldEnable) {
                HarbourLogger.log("HarbourPauseDebugAction", "State changed - debugger state: " + process.getDebuggerState() + ", enabled: " + shouldEnable);
                lastEnabledState = shouldEnable;
            }
        } else {
            if (lastEnabledState != null) {
                HarbourLogger.log("HarbourPauseDebugAction", "No active Harbour debug session - disabled");
                lastEnabledState = null;
            }
        }

        // Always visible but only enabled when debugging
        e.getPresentation().setEnabled(shouldEnable);
    }

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        Project project = e.getProject();

        if (project == null) {
            return;
        }

        // Get the current debug session
        XDebugSession session = XDebuggerManager.getInstance(project).getCurrentSession();

        if (session == null || !(session.getDebugProcess() instanceof HarbourDebuggerRemoteProcess)) {
            showNotification(project, "No Debug Session",
                "No active Harbour debug session found",
                NotificationType.WARNING);
            return;
        }

        HarbourDebuggerRemoteProcess process = (HarbourDebuggerRemoteProcess) session.getDebugProcess();

        // Check if debugger is in a valid state for pausing
        if (process.getDebuggerState() != HarbourDebuggerRemoteProcess.DebuggerState.RUNNING) {
            showNotification(project, "Cannot Pause",
                "Debugger is not running (current state: " + process.getDebuggerState() + ")",
                NotificationType.WARNING);
            return;
        }

        HarbourLogger.log("HarbourPauseDebugAction", "User requested pause via Alt-D");

        // Call the pause method on the debug process
        process.pause();

        // Show notification that pause was requested
        showNotification(project, "Pause Requested",
            "Debugger will pause at the next execution point",
            NotificationType.INFORMATION);
    }

    private void showNotification(Project project, String title, String content, NotificationType type) {
        Notifications.Bus.notify(
            new Notification("Harbour Application", title, content, type),
            project
        );
    }
}

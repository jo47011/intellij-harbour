package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.frame.XValue;
import com.intellij.xdebugger.frame.XValuePlace;
import com.intellij.xdebugger.impl.ui.tree.actions.XDebuggerTreeActionBase;
import com.intellij.xdebugger.impl.ui.tree.nodes.XValueNodeImpl;
import org.jetbrains.annotations.NotNull;

/**
 * Action to toggle tracepoint (watch for changes) on a variable in the debugger.
 * This action appears in the context menu when right-clicking on a variable.
 */
public class HarbourWatchForChangesAction extends AnAction {

    public HarbourWatchForChangesAction() {
        super("Watch for Changes", "Stop execution when this variable's value changes", AllIcons.Debugger.Watch);
    }

    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        return ActionUpdateThread.BGT;
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        // Check if we're in a Harbour debug session
        XDebugSession session = getActiveHarbourSession(e);
        if (session == null) {
            e.getPresentation().setEnabledAndVisible(false);
            return;
        }

        // Get the selected node from the debugger tree
        XValueNodeImpl node = XDebuggerTreeActionBase.getSelectedNode(e.getDataContext());
        if (node == null) {
            e.getPresentation().setEnabledAndVisible(false);
            return;
        }

        XValue value = node.getValueContainer();
        if (!(value instanceof HarbourDebuggerValue)) {
            e.getPresentation().setEnabledAndVisible(false);
            return;
        }

        // Show the action
        e.getPresentation().setEnabledAndVisible(true);

        // Update text based on whether tracepoint is active
        HarbourDebuggerValue harbourValue = (HarbourDebuggerValue) value;
        HarbourDebuggerRemoteProcess process = (HarbourDebuggerRemoteProcess) session.getDebugProcess();
        HarbourTracepointManager tpManager = process.getTracepointManager();

        if (tpManager != null) {
            String varName = harbourValue.getFullExpressionName();
            if (tpManager.hasTracepoint(varName)) {
                e.getPresentation().setText("Stop Watching for Changes");
                e.getPresentation().setDescription("Remove tracepoint - stop watching " + varName);
                e.getPresentation().setIcon(AllIcons.Actions.Cancel);
            } else {
                e.getPresentation().setText("Watch for Changes");
                e.getPresentation().setDescription("Add tracepoint - stop when " + varName + " changes");
                e.getPresentation().setIcon(AllIcons.Debugger.Watch);
            }
        }
    }

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        XDebugSession session = getActiveHarbourSession(e);
        if (session == null) {
            return;
        }

        XValueNodeImpl node = XDebuggerTreeActionBase.getSelectedNode(e.getDataContext());
        if (node == null) {
            return;
        }

        XValue value = node.getValueContainer();
        if (!(value instanceof HarbourDebuggerValue)) {
            return;
        }

        HarbourDebuggerValue harbourValue = (HarbourDebuggerValue) value;
        HarbourDebuggerRemoteProcess process = (HarbourDebuggerRemoteProcess) session.getDebugProcess();
        HarbourTracepointManager tpManager = process.getTracepointManager();

        if (tpManager != null) {
            String varName = harbourValue.getFullExpressionName();
            boolean isNowActive = tpManager.toggleTracepoint(varName, harbourValue.getValue());
            HarbourLogger.log("WatchForChangesAction",
                "Tracepoint toggled for " + varName + ": " + (isNowActive ? "ACTIVE" : "REMOVED"));

            // Immediately refresh the node's presentation to show/hide watch icon
            harbourValue.computePresentation(node, XValuePlace.TREE);
        }
    }

    /**
     * Get the active Harbour debug session if one exists.
     */
    private XDebugSession getActiveHarbourSession(AnActionEvent e) {
        if (e.getProject() == null) {
            return null;
        }

        XDebugSession session = XDebuggerManager.getInstance(e.getProject()).getCurrentSession();
        if (session == null) {
            return null;
        }

        // Check if this is a Harbour debug session
        if (!(session.getDebugProcess() instanceof HarbourDebuggerRemoteProcess)) {
            return null;
        }

        return session;
    }
}

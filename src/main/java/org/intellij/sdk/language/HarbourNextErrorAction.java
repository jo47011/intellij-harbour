package org.intellij.sdk.language;

import com.intellij.execution.filters.Filter;
import com.intellij.execution.filters.OpenFileHyperlinkInfo;
import com.intellij.notification.NotificationGroupManager;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.Key;
import com.intellij.openapi.wm.ToolWindow;
import com.intellij.openapi.wm.ToolWindowManager;
import org.jetbrains.annotations.NotNull;

import java.awt.*;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Action to navigate between compiler errors/warnings in the output console using F2/F8.
 * Supports both traditional ConsoleView and the newer TerminalExecutionConsole in 2024.3+.
 */
public class HarbourNextErrorAction extends AnAction {
    // Key to store error state in the project
    private static final Key<ErrorNavigationState> ERROR_STATE_KEY = Key.create("HarbourErrorNavigationState");

    // Reuse the same pattern from HarbourCompilerOutputFilter
    private static final Pattern HARBOUR_OUTPUT_PATTERN =
            Pattern.compile("(?:\\.\\\\)?(\\w+\\.prg)(?:\\((\\d+)\\)|:(\\d+):) (Warning|Error).*");

    public HarbourNextErrorAction() {
        super("Go to Next Harbour Error");
    }

    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        return ActionUpdateThread.EDT;
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        if (project == null) {
            e.getPresentation().setEnabled(false);
            return;
        }

        e.getPresentation().setEnabled(true);
    }

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        if (project == null) return;

        HarbourLogger.log("NextErrorAction", "Action triggered");

        // Get or create the error navigation state
        ErrorNavigationState state = project.getUserData(ERROR_STATE_KEY);
        if (state == null) {
            state = new ErrorNavigationState();
            project.putUserData(ERROR_STATE_KEY, state);
        }

        // If we don't have errors yet or should rescan, then scan for errors
        if (state.errors.isEmpty() || isConsoleDirty(project, state)) {
            String consoleText = getConsoleTextFromRunTab(project);
            if (consoleText == null || consoleText.isEmpty()) {
                showNotification(project, "No console text found");
                HarbourLogger.log("NextErrorAction", "No console text found");
                return;
            }

            HarbourLogger.log("NextErrorAction", "Found console text with length: " + consoleText.length());
            state.lastConsoleText = consoleText;

            // Find errors in the console text
            scanForErrors(consoleText, project, state);

            if (state.errors.isEmpty()) {
                showNotification(project, "No Harbour errors found in console");
                HarbourLogger.log("NextErrorAction", "No errors found in console output");
                return;
            }
        }

        // Move to next error
        state.currentErrorIndex = (state.currentErrorIndex + 1) % state.errors.size();
        ErrorPosition error = state.errors.get(state.currentErrorIndex);

        // Navigate to the error
        showNotification(project, "Navigating to " + error.fileName + ":" + error.lineNumber +
                " (" + (state.currentErrorIndex + 1) + " of " + state.errors.size() + ")");
        HarbourLogger.log("NextErrorAction", "Navigating to error at " + error.fileName + ":" + error.lineNumber +
                " (index " + state.currentErrorIndex + ")");

        if (error.hyperlinkInfo != null) {
            error.hyperlinkInfo.navigate(project);
        }
    }

    /**
     * Check if console content has changed since last scan
     */
    private boolean isConsoleDirty(Project project, ErrorNavigationState state) {
        String currentText = getConsoleTextFromRunTab(project);
        return !currentText.equals(state.lastConsoleText);
    }

    /**
     * Show a notification balloon
     */
    private void showNotification(Project project, String message) {
        try {
            ApplicationManager.getApplication().invokeLater(() -> {
                NotificationGroupManager.getInstance()
                        .getNotificationGroup("Harbour Compiler")
                        .createNotification(message, NotificationType.INFORMATION)
                        .notify(project);
            });
        } catch (Exception e) {
            HarbourLogger.logStackTrace("NextErrorAction", e);
        }
    }

    /**
     * Get the console text from the Run tab
     */
    private String getConsoleTextFromRunTab(Project project) {
        try {
            ToolWindowManager toolWindowManager = ToolWindowManager.getInstance(project);
            ToolWindow runWindow = toolWindowManager.getToolWindow("Run");

            if (runWindow == null || !runWindow.isVisible()) {
                HarbourLogger.log("NextErrorAction", "Run tool window not found or not visible");
                return "";
            }

            // Find terminal widget component
            Component terminalWidget = findTerminalComponent(runWindow.getComponent());
            if (terminalWidget != null) {
                HarbourLogger.log("NextErrorAction", "Found terminal widget: " + terminalWidget.getClass().getName());

                // Try to extract text using reflection
                return extractTextFromTerminal(terminalWidget);
            }

            // Fall back to standard text extraction from any component
            return extractTextFromAnyComponent(runWindow.getComponent());

        } catch (Exception e) {
            HarbourLogger.logStackTrace("NextErrorAction", e);
            return "";
        }
    }

    /**
     * Find terminal component in the component hierarchy
     */
    private Component findTerminalComponent(Component component) {
        if (component == null) return null;

        // Check if this is the terminal component we're looking for
        String className = component.getClass().getName();
        if (className.contains("TerminalExecutionConsole")) {
            return component;
        }

        // Search children
        if (component instanceof Container) {
            Container container = (Container) component;
            for (Component child : container.getComponents()) {
                Component terminal = findTerminalComponent(child);
                if (terminal != null) {
                    return terminal;
                }
            }
        }

        return null;
    }

    /**
     * Extract text from terminal component using reflection
     */
    private String extractTextFromTerminal(Component terminal) {
        try {
            // First try the terminal widget itself
            Class<?> terminalClass = terminal.getClass();

            // Try various methods that might return the terminal text
            Method[] methods = terminalClass.getMethods();
            for (Method method : methods) {
                String methodName = method.getName();
                if ((methodName.equals("getText") ||
                        methodName.equals("getTextBuffer") ||
                        methodName.equals("getBufferText") ||
                        methodName.equals("getBuffer")) &&
                        method.getParameterCount() == 0) {

                    method.setAccessible(true);
                    Object result = method.invoke(terminal);
                    if (result != null) {
                        HarbourLogger.log("NextErrorAction", "Got text via " + methodName + "()");
                        return result.toString();
                    }
                }
            }

        } catch (Exception e) {
            HarbourLogger.logStackTrace("NextErrorAction", e);
        }

        return "";
    }

    /**
     * Try to extract text from any object using reflection
     */
    private String extractTextFromObject(Object obj) {
        if (obj == null) return "";

        try {
            // Try getText method
            try {
                Method getText = obj.getClass().getMethod("getText");
                getText.setAccessible(true);
                Object result = getText.invoke(obj);
                if (result != null) {
                    return result.toString();
                }
            } catch (Exception ignored) {}

            // Try toString
            return obj.toString();

        } catch (Exception e) {
            return "";
        }
    }

    /**
     * Extract text from any Swing component
     */
    private String extractTextFromAnyComponent(Component component) {
        if (component == null) return "";

        // Check various text components
        try {
            Method getTextMethod = component.getClass().getMethod("getText");
            if (getTextMethod != null) {
                Object result = getTextMethod.invoke(component);
                if (result instanceof String) {
                    return (String) result;
                }
            }
        } catch (Exception ignored) {}

        // Check children
        if (component instanceof Container) {
            StringBuilder text = new StringBuilder();
            Container container = (Container) component;
            for (Component child : container.getComponents()) {
                String childText = extractTextFromAnyComponent(child);
                if (childText != null && !childText.isEmpty()) {
                    text.append(childText);
                }
            }
            return text.toString();
        }

        return "";
    }

    /**
     * Scans console text for error patterns and builds an index of navigable errors
     */
    private void scanForErrors(String consoleText, Project project, ErrorNavigationState state) {
        HarbourLogger.log("NextErrorAction", "Scanning for errors");

        state.errors.clear();
        state.currentErrorIndex = -1;

        // Create a temporary filter
        HarbourCompilerOutputFilter filter = new HarbourCompilerOutputFilter(project);

        // Process each line
        String[] lines = consoleText.split("\n");
        int currentPosition = 0;

        for (String line : lines) {
            Matcher matcher = HARBOUR_OUTPUT_PATTERN.matcher(line);
            if (matcher.find()) {
                HarbourLogger.log("NextErrorAction", "Found error pattern: " + line);

                String fileName = matcher.group(1);
                String lineNumberStr = matcher.group(2) != null ? matcher.group(2) : matcher.group(3);
                int lineNumber = Integer.parseInt(lineNumberStr);

                // Use the filter to get a hyperlink
                Filter.Result result = filter.applyFilter(line, currentPosition + line.length());
                OpenFileHyperlinkInfo info = null;

                if (result != null && result.getFirstHyperlinkInfo() instanceof OpenFileHyperlinkInfo) {
                    info = (OpenFileHyperlinkInfo) result.getFirstHyperlinkInfo();
                }

                // Add to errors list
                state.errors.add(new ErrorPosition(fileName, lineNumber, info));
                HarbourLogger.log("NextErrorAction", "Added error: " + fileName + ":" + lineNumber);
            }

            currentPosition += line.length() + 1; // +1 for the newline
        }

        HarbourLogger.log("NextErrorAction", "Found " + state.errors.size() + " errors in console");
    }

    /**
     * Class to store per-project navigation state
     */
    private static class ErrorNavigationState {
        int currentErrorIndex = -1;
        List<ErrorPosition> errors = new ArrayList<>();
        String lastConsoleText = "";
    }

    /**
     * Helper class to store error position information
     */
    private static class ErrorPosition {
        String fileName;
        int lineNumber;
        OpenFileHyperlinkInfo hyperlinkInfo;

        ErrorPosition(String fileName, int lineNumber, OpenFileHyperlinkInfo hyperlinkInfo) {
            this.fileName = fileName;
            this.lineNumber = lineNumber;
            this.hyperlinkInfo = hyperlinkInfo;
        }
    }
}
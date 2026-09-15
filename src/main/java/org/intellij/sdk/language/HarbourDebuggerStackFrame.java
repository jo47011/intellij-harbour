package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.ui.ColoredTextContainer;
import com.intellij.ui.SimpleTextAttributes;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.XCompositeNode;
import com.intellij.xdebugger.frame.XStackFrame;
import com.intellij.xdebugger.frame.XValueChildrenList;
import com.intellij.xdebugger.evaluation.XDebuggerEvaluator;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Represents a stack frame in the Harbour debugger.
 * Shows the current execution position and local variables.
 */
public class HarbourDebuggerStackFrame extends XStackFrame {
    private final HarbourDebuggerBaseProcess debugProcess;
    private final String functionName;
    private final String filePath;
    private final int lineNumber;
    private XSourcePosition sourcePosition;

    public HarbourDebuggerStackFrame(HarbourDebuggerBaseProcess debugProcess,
                                     String functionName,
                                     String filePath,
                                     int lineNumber,
                                     XSourcePosition sourcePosition) {
        this.debugProcess = debugProcess;
        this.functionName = functionName;
        this.filePath = filePath;
        this.lineNumber = lineNumber;
        this.sourcePosition = sourcePosition;
    }

    @Nullable
    @Override
    public XSourcePosition getSourcePosition() {
        return sourcePosition;
    }

    /**
     * Stable per-frame identity used by IntelliJ's XVariablesViewBase to save/restore
     * the variables tree expansion state across suspend events. Must NOT depend on the
     * line number, otherwise every step would create a new "frame" and collapse all
     * expanded nodes (objects, arrays, hashes).
     */
    @Override
    public Object getEqualityObject() {
        String fn = functionName != null ? functionName.toLowerCase() : "";
        String fp = filePath != null ? filePath : "";
        return fn + "@" + fp;
    }

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        // Execute on the proper thread to ensure UI safety
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            // Capture step generation at start - if it changes, a new step was requested
            long myStepGeneration = 0;

            // Wait for variables to arrive if they're not ready yet
            // This runs on a background thread, so it won't block the UI
            if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                myStepGeneration = remoteProcess.getStepGeneration();

                if (!remoteProcess.areVariablesReady()) {
                    HarbourLogger.log("HarbourDebuggerStackFrame",
                        "Variables not ready yet, waiting up to 500ms (gen=" + myStepGeneration + ")...");
                    remoteProcess.waitForVariables(500);  // Wait max 500ms

                    // Check if a new step was issued while waiting
                    if (remoteProcess.getStepGeneration() != myStepGeneration) {
                        HarbourLogger.log("HarbourDebuggerStackFrame",
                            "Step generation changed during wait, skipping UI update");
                        // Mark as complete but empty - a new frame will be created for the new position
                        node.addChildren(new XValueChildrenList(), true);
                        return;
                    }

                    if (remoteProcess.areVariablesReady()) {
                        HarbourLogger.log("HarbourDebuggerStackFrame", "Variables ready after wait");
                    } else {
                        HarbourLogger.log("HarbourDebuggerStackFrame",
                            "Timeout waiting for variables, showing what we have");
                    }
                }
            }

            Map<String, HarbourDebuggerValue> variables = debugProcess.getVariables();

            XValueChildrenList children = new XValueChildrenList();

            // DEBUGGING: Log what's actually in the variables map
            HarbourLogger.log("HarbourDebuggerStackFrame", "=== DEBUGGING VARIABLES MAP ===");
            HarbourLogger.log("HarbourDebuggerStackFrame", "Variables map size: " + variables.size());
            for (Map.Entry<String, HarbourDebuggerValue> entry : variables.entrySet()) {
                HarbourLogger.log("HarbourDebuggerStackFrame",
                    "Map entry: key='" + entry.getKey() + "', name='" + entry.getValue().getName() +
                    "', type='" + entry.getValue().getType() + "', value='" + entry.getValue().getValue() + "'");
            }
            HarbourLogger.log("HarbourDebuggerStackFrame", "=== END DEBUGGING ===");

            // Pattern to match unnamed stack slots: Local_1, Local_2, etc.
            Pattern unnamedSlotPattern = Pattern.compile("^Local_\\d+$");

            // Separate variables into regular variables and unnamed stack slots
            List<HarbourDebuggerValue> regularVariables = new ArrayList<>();
            List<HarbourDebuggerValue> stackSlots = new ArrayList<>();

            for (Map.Entry<String, HarbourDebuggerValue> entry : variables.entrySet()) {
                String key = entry.getKey();
                HarbourDebuggerValue value = entry.getValue();
                String displayName = value.getName();

                // Smart GETLIST filtering: Only filter if it's an empty system variable
                if ("GETLIST".equals(displayName) && "A".equals(value.getType()) && "Array(0)".equals(value.getValue())) {
                    if (key.startsWith("PUBLICS.")) {
                        HarbourLogger.log("HarbourDebuggerStackFrame",
                            "Filtering empty system GETLIST variable");
                        continue; // Skip this variable
                    }
                }

                // Check if this is an unnamed stack slot from LOCALS scope
                if (key.startsWith("LOCALS.") && unnamedSlotPattern.matcher(displayName).matches()) {
                    HarbourLogger.log("HarbourDebuggerStackFrame",
                        "Found unnamed stack slot: " + displayName);
                    stackSlots.add(value);
                } else {
                    regularVariables.add(value);
                }
            }

            // Sort regular variables by name (case-insensitive)
            regularVariables.sort((v1, v2) -> v1.getName().compareToIgnoreCase(v2.getName()));

            // Add regular variables first
            for (HarbourDebuggerValue value : regularVariables) {
                HarbourLogger.log("HarbourDebuggerStackFrame",
                    "Adding regular variable: name='" + value.getName() + "', value='" + value.getValue() + "'");
                children.add(value.getName(), value);
            }

            // Add unnamed stack slots as a collapsible group if there are any
            if (!stackSlots.isEmpty()) {
                // Sort stack slots by name for consistent ordering
                stackSlots.sort((v1, v2) -> v1.getName().compareToIgnoreCase(v2.getName()));

                HarbourLogger.log("HarbourDebuggerStackFrame",
                    "Adding " + stackSlots.size() + " unnamed stack slots as a group");
                HarbourUnnamedSlotsGroup slotsGroup = new HarbourUnnamedSlotsGroup(stackSlots);
                children.add(slotsGroup);
            }

            // Execute the final UI update on the EDT
            ApplicationManager.getApplication().invokeLater(() -> {
                HarbourLogger.log("HarbourDebuggerStackFrame", "Calling node.addChildren with " +
                    regularVariables.size() + " regular variables" +
                    (stackSlots.isEmpty() ? "" : " + 1 stack slots group (" + stackSlots.size() + " slots)"));
                node.addChildren(children, true);
            });
        });
    }

    @Override
    public void customizePresentation(@NotNull ColoredTextContainer component) {
        // Display just the file:line format without function name or "at"
        if (filePath != null) {
            // Remove ".\" or "./" prefix from file path if present
            String cleanPath = filePath;
            if (cleanPath.startsWith(".\\")) {
                cleanPath = cleanPath.substring(2);
            } else if (cleanPath.startsWith("./")) {
                cleanPath = cleanPath.substring(2);
            }
            component.append(cleanPath + ":" + lineNumber,
                    SimpleTextAttributes.REGULAR_ATTRIBUTES);
        } else if (functionName != null) {
            // Fallback to function name if no file path
            component.append(functionName, SimpleTextAttributes.REGULAR_ATTRIBUTES);
        }
        component.setIcon(AllIcons.Debugger.Frame);
    }

    @Nullable
    @Override
    public XDebuggerEvaluator getEvaluator() {
        return new HarbourDebuggerEvaluator(debugProcess);
    }
}
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

import java.util.Map;

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

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        // Execute on the proper thread to ensure UI safety
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
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
            
            // Sort variables globally by name (case-insensitive) before adding to UI
            variables.entrySet().stream()
                .sorted((e1, e2) -> e1.getValue().getName().compareToIgnoreCase(e2.getValue().getName()))
                .forEach(entry -> {
                    String key = entry.getKey();
                    HarbourDebuggerValue value = entry.getValue();
                    String displayName = value.getName(); // Use the clean name from the value
                    
                    // Smart GETLIST filtering: Only filter if it's an empty system variable
                    // Show GETLIST if it has content or is user-defined
                    if ("GETLIST".equals(displayName) && "A".equals(value.getType()) && "Array(0)".equals(value.getValue())) {
                        // Check if it's from PUBLICS scope (system variable) and empty
                        if (key.startsWith("PUBLICS.")) {
                            HarbourLogger.log("HarbourDebuggerStackFrame", 
                                "Filtering empty system GETLIST variable");
                            return; // Skip this variable
                        }
                    }
                    
                    HarbourLogger.log("HarbourDebuggerStackFrame", 
                        "Adding to UI (sorted): displayName='" + displayName + "', key='" + key + "', value='" + value.getValue() + "'");
                    
                    // Add to children with clean display name
                    children.add(displayName, value);
                });

            // Execute the final UI update on the EDT
            ApplicationManager.getApplication().invokeLater(() -> {
                HarbourLogger.log("HarbourDebuggerStackFrame", "Calling node.addChildren with " + children.size() + " total variables");
                node.addChildren(children, true);
            });
        });
    }

    @Override
    public void customizePresentation(@NotNull ColoredTextContainer component) {
        if (functionName != null) {
            component.append(functionName, SimpleTextAttributes.REGULAR_ATTRIBUTES);
        }
        if (filePath != null) {
            component.append(" at ", SimpleTextAttributes.REGULAR_ATTRIBUTES);
            component.append(filePath + ":" + lineNumber,
                    SimpleTextAttributes.REGULAR_ATTRIBUTES);
        }
        component.setIcon(AllIcons.Debugger.Frame);
    }

    @Nullable
    @Override
    public XDebuggerEvaluator getEvaluator() {
        return new HarbourDebuggerEvaluator(debugProcess);
    }
}
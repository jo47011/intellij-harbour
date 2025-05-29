package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.ui.ColoredTextContainer;
import com.intellij.ui.SimpleTextAttributes;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.XCompositeNode;
import com.intellij.xdebugger.frame.XStackFrame;
import com.intellij.xdebugger.frame.XValueChildrenList;
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
        Map<String, HarbourDebuggerValue> variables = debugProcess.getVariables();

        XValueChildrenList children = new XValueChildrenList();
        for (Map.Entry<String, HarbourDebuggerValue> entry : variables.entrySet()) {
            children.add(entry.getKey(), entry.getValue());
        }

        node.addChildren(children, true);
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
}
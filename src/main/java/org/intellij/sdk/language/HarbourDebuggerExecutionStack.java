package org.intellij.sdk.language;

import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.XExecutionStack;
import com.intellij.xdebugger.frame.XStackFrame;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.Arrays;
import java.util.Collections;

/**
 * Represents the call stack in the Harbour debugger.
 * Displays the current execution context and stack frames.
 */
public class HarbourDebuggerExecutionStack extends XExecutionStack {
    private final HarbourDebuggerBaseProcess debugProcess;
    private final HarbourDebuggerStackFrame topFrame;

    public HarbourDebuggerExecutionStack(HarbourDebuggerBaseProcess debugProcess,
                                         String file,
                                         int line,
                                         XSourcePosition sourcePosition) {
        super("Harbour Stack");
        this.debugProcess = debugProcess;
        this.topFrame = new HarbourDebuggerStackFrame(debugProcess, getFunctionNameFromFile(file), file, line, sourcePosition);
    }

    @Nullable
    @Override
    public XStackFrame getTopFrame() {
        return topFrame;
    }

    @Override
    public void computeStackFrames(int firstFrameIndex, @NotNull XStackFrameContainer container) {
        if (firstFrameIndex == 0) {
            container.addStackFrames(Collections.singletonList(topFrame), true);
        } else {
            container.addStackFrames(Collections.emptyList(), true);
        }
    }

    private String getFunctionNameFromFile(String filePath) {
        // Extract the function name from the file path
        String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
        fileName = fileName.substring(fileName.lastIndexOf('\\') + 1);
        if (fileName.toLowerCase().endsWith(".prg")) {
            fileName = fileName.substring(0, fileName.length() - 4);
        }
        return fileName;
    }
}
package org.intellij.sdk.language;

import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.XExecutionStack;
import com.intellij.xdebugger.frame.XSuspendContext;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/**
 * Suspend context for Harbour debugger.
 * Created when execution is suspended at a breakpoint or step.
 */
public class HarbourDebuggerSuspendContext extends XSuspendContext {
    private final HarbourDebuggerExecutionStack executionStack;

    public HarbourDebuggerSuspendContext(HarbourDebuggerBaseProcess debugProcess,
                                         String filePath,
                                         int line,
                                         XSourcePosition sourcePosition) {
        // Get the stack trace from the debug process if available
        List<HarbourDebuggerRemoteProcess.StackFrameInfo> stackTrace = null;
        if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
            stackTrace = ((HarbourDebuggerRemoteProcess) debugProcess).getCurrentStackTrace();
        }
        executionStack = new HarbourDebuggerExecutionStack(debugProcess, filePath, line, sourcePosition, stackTrace);
    }

    @Nullable
    @Override
    public XExecutionStack getActiveExecutionStack() {
        return executionStack;
    }

    @NotNull
    @Override
    public XExecutionStack[] getExecutionStacks() {
        return new XExecutionStack[]{executionStack};
    }
}
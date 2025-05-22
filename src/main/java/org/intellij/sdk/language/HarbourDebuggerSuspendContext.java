package org.intellij.sdk.language;

import com.intellij.xdebugger.frame.XExecutionStack;
import com.intellij.xdebugger.frame.XSuspendContext;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Suspend context for Harbour debugger.
 * Created when execution is suspended at a breakpoint or step.
 */
public class HarbourDebuggerSuspendContext extends XSuspendContext {
    private final HarbourDebuggerExecutionStack executionStack;

    public HarbourDebuggerSuspendContext(HarbourDebuggerProcess debugProcess,
                                         String filePath,
                                         int line) {
        executionStack = new HarbourDebuggerExecutionStack(debugProcess, filePath, line);
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
package org.intellij.sdk.language;

import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XSourcePosition;
import org.jetbrains.annotations.NotNull;

import java.util.Map;

/**
 * Base abstract class for Harbour debugger processes
 */
public abstract class HarbourDebuggerBaseProcess extends XDebugProcess {
    protected HarbourDebuggerBaseProcess(@NotNull XDebugSession session) {
        super(session);
    }
    
    public abstract Map<String, HarbourDebuggerValue> getVariables();
    
    public abstract XSourcePosition getLastPosition();
    
    public abstract void sendCommand(String command, String... args);
}
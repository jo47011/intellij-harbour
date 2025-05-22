package org.intellij.sdk.language;

import com.intellij.xdebugger.breakpoints.XBreakpointProperties;
import org.jetbrains.annotations.Nullable;

/**
 * Properties for Harbour debugger breakpoints.
 * This is required by the XLineBreakpointType interface.
 */
public class HarbourDebuggerBreakpointProperties extends XBreakpointProperties<HarbourDebuggerBreakpointProperties> {

    @Nullable
    @Override
    public HarbourDebuggerBreakpointProperties getState() {
        return this;
    }

    @Override
    public void loadState(@Nullable HarbourDebuggerBreakpointProperties state) {
        // No specific state to load for now
    }
}
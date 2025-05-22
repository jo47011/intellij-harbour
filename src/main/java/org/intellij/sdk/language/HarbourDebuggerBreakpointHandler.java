package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.breakpoints.*;
import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Breakpoint handler for Harbour debugger using file-based approach.
 */
public class HarbourDebuggerBreakpointHandler extends XBreakpointHandler<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> {
    private final HarbourDebuggerProcess debugProcess;
    private final List<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> registeredBreakpoints = new ArrayList<>();
    private final Map<XBreakpoint<?>, String> breakpointIds = new HashMap<>();

    public HarbourDebuggerBreakpointHandler(HarbourDebuggerProcess debugProcess) {
        super(HarbourDebuggerLineBreakpointType.class);
        this.debugProcess = debugProcess;
    }

    @Override
    public void registerBreakpoint(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        Project project = debugProcess.getSession().getProject();

        if (breakpoint.getSourcePosition() != null) {
            String filePath = breakpoint.getSourcePosition().getFile().getPath();
            int line = breakpoint.getSourcePosition().getLine() + 1; // 0-based to 1-based
            String breakpointId = filePath + ":" + line;

            HarbourLogger.log(project, "HarbourDebugger",
                    "Registering breakpoint at " + filePath + ":" + line);

            registeredBreakpoints.add(breakpoint);
            breakpointIds.put(breakpoint, breakpointId);

            // Note: Breakpoints are handled via init.cld file export, not direct commands
        }
    }

    @Override
    public void unregisterBreakpoint(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint,
                                     boolean temporary) {
        Project project = debugProcess.getSession().getProject();

        if (breakpoint.getSourcePosition() != null) {
            String filePath = breakpoint.getSourcePosition().getFile().getPath();
            int line = breakpoint.getSourcePosition().getLine() + 1;

            HarbourLogger.log(project, "HarbourDebugger",
                    "Unregistering breakpoint at " + filePath + ":" + line);

            registeredBreakpoints.remove(breakpoint);
            breakpointIds.remove(breakpoint);

            // Note: Breakpoints are handled via init.cld file export, not direct commands
        }
    }

    /**
     * Write breakpoints to a file in a format Harbour debugger can understand
     */
    public void writeBreakpointsToFile(File file) throws IOException {
        file.getParentFile().mkdirs();

        try (PrintWriter writer = new PrintWriter(new java.io.FileWriter(file))) {
            int count = 0;

            XBreakpointManager breakpointManager = XDebuggerManager.getInstance(
                    debugProcess.getSession().getProject()).getBreakpointManager();

            for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
                if (bp instanceof XLineBreakpoint &&
                        bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                        bp.getSourcePosition() != null) {

                    VirtualFile file2 = bp.getSourcePosition().getFile();
                    String fileName = file2.getName();
                    int line = bp.getSourcePosition().getLine() + 1;

                    writer.println("BP " + line + " " + fileName);
                    count++;
                }
            }

            HarbourLogger.log(debugProcess.getSession().getProject(), "HarbourDebugger",
                    "Exported " + count + " breakpoints to " + file.getPath());
        }
    }

    public Map<XBreakpoint<?>, String> getBreakpointIds() {
        return breakpointIds;
    }

    public List<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> getRegisteredBreakpoints() {
        return registeredBreakpoints;
    }
}
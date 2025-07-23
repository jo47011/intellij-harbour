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
    private final HarbourDebuggerBaseProcess debugProcess;
    private final List<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> registeredBreakpoints = new ArrayList<>();
    private final Map<XBreakpoint<?>, String> breakpointIds = new HashMap<>();
    private final boolean isRemoteDebugger;

    public HarbourDebuggerBreakpointHandler(HarbourDebuggerBaseProcess debugProcess) {
        super(HarbourDebuggerLineBreakpointType.class);
        this.debugProcess = debugProcess;
        this.isRemoteDebugger = debugProcess instanceof HarbourDebuggerRemoteProcess;
    }

    @Override
    public void registerBreakpoint(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        Project project = debugProcess.getSession().getProject();

        if (breakpoint.getSourcePosition() != null) {
            String filePath = breakpoint.getSourcePosition().getFile().getPath();
            int line = breakpoint.getSourcePosition().getLine() + 1; // 0-based to 1-based
            String breakpointId = filePath + ":" + line;

            // Check if breakpoint is enabled AND not globally muted
            boolean globallyMuted = debugProcess.getSession().areBreakpointsMuted();
            boolean individuallyEnabled = breakpoint.isEnabled();
            boolean isEnabled = !globallyMuted && individuallyEnabled;
            
            HarbourLogger.log(project, "HarbourDebugger",
                    "=== REGISTERING BREAKPOINT ===");
            HarbourLogger.log(project, "HarbourDebugger",
                    "Location: " + filePath + ":" + line);
            HarbourLogger.log(project, "HarbourDebugger",
                    "Globally Muted: " + globallyMuted);
            HarbourLogger.log(project, "HarbourDebugger",
                    "Individually Enabled: " + individuallyEnabled);
            HarbourLogger.log(project, "HarbourDebugger",
                    "Final Enabled State: " + isEnabled);
            HarbourLogger.log(project, "HarbourDebugger",
                    "Is Remote Debugger: " + isRemoteDebugger);
            
            // Always add to registered list so we can track state changes
            registeredBreakpoints.add(breakpoint);
            breakpointIds.put(breakpoint, breakpointId);

            // Only send enabled breakpoints to remote debugger
            if (isRemoteDebugger && isEnabled) {
                HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                if (remoteProcess.getConnection() != null && remoteProcess.getConnection().isConnected()) {
                    HarbourLogger.log(project, "HarbourDebugger",
                            "Connection is active, sending breakpoint immediately");
                    String fileName = breakpoint.getSourcePosition().getFile().getName();
                    
                    // Build breakpoint command with conditional support following harbourCodeExtension protocol
                    StringBuilder breakpointCommand = new StringBuilder();
                    breakpointCommand.append("+:").append(fileName).append(":").append(line);
                    
                    HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
                    
                    // If properties is null, try to get from custom properties storage
                    if (properties == null) {
                        properties = HarbourDebuggerBreakpointPropertiesPanel.getCustomProperties(breakpoint);
                    }
                    
                    // Also try persistent storage service
                    if (properties == null && project != null) {
                        HarbourBreakpointPropertiesStorage storage = HarbourBreakpointPropertiesStorage.getInstance(project);
                        properties = storage.getBreakpointProperties(breakpoint);
                    }
                    
                    // Critical debugging - using multiple logging methods
                    HarbourLogger.log("HarbourDebuggerBreakpointHandler", "=== BREAKPOINT REGISTRATION DEBUG ===");
                    HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Properties object: " + (properties != null ? "not null" : "NULL"));
                    HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Properties from custom storage: " + (properties != null && breakpoint.getProperties() == null));
                    
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "=== BREAKPOINT REGISTRATION: " + fileName + ":" + line);
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Breakpoint properties object: " + (properties != null ? "not null" : "NULL"));
                    
                    if (properties != null) {
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Condition: '" + properties.getCondition() + "'");
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Hit Condition: '" + properties.getHitCondition() + "'");
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Log Message: '" + properties.getLogMessage() + "'");
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Has Condition: " + properties.hasCondition());
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Has Hit Condition: " + properties.hasHitCondition());
                        HarbourLogger.log("HarbourDebuggerBreakpointHandler", "Has Log Message: " + properties.hasLogMessage());
                        
                        HarbourLogger.log(project, "HarbourDebugger", 
                                "Property values - Condition: '" + properties.getCondition() + 
                                "', Hit: '" + properties.getHitCondition() + 
                                "', Log: '" + properties.getLogMessage() + "'");
                        
                        // Add condition if present
                        if (properties.hasCondition()) {
                            String condition = properties.getCondition().replace(":", ";");
                            breakpointCommand.append(":?:").append(condition);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                    "Added condition: " + properties.getCondition());
                        }
                        
                        // Add hit condition if present
                        if (properties.hasHitCondition()) {
                            breakpointCommand.append(":C:").append(properties.getHitCondition());
                            HarbourLogger.log(project, "HarbourDebugger", 
                                    "Added hit condition: " + properties.getHitCondition());
                        }
                        
                        // Add log message if present
                        if (properties.hasLogMessage()) {
                            String logMessage = properties.getLogMessage().replace(":", ";");
                            breakpointCommand.append(":L:").append(logMessage);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                    "Added log message: " + properties.getLogMessage());
                        }
                    }
                    
                    // Use harbourCodeExtension protocol
                    debugProcess.sendCommand("BREAKPOINT");
                    debugProcess.sendCommand(breakpointCommand.toString());
                    
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Sent breakpoint command: " + breakpointCommand.toString());
                } else {
                    HarbourLogger.log(project, "HarbourDebugger",
                            "Connection not ready - breakpoint will be sent later via sendAllBreakpoints()");
                }
            } else {
                if (!isRemoteDebugger) {
                    HarbourLogger.log(project, "HarbourDebugger",
                            "Not a remote debugger - breakpoint not sent");
                } else {
                    HarbourLogger.log(project, "HarbourDebugger",
                            "Breakpoint is disabled/muted - not sending");
                }
            }
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

            // Remove breakpoint from remote debugger if using remote debugging
            if (isRemoteDebugger) {
                HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                if (remoteProcess.getConnection() != null && remoteProcess.getConnection().isConnected()) {
                    String fileName = breakpoint.getSourcePosition().getFile().getName();
                    // Use harbourCodeExtension protocol
                    debugProcess.sendCommand("BREAKPOINT");
                    debugProcess.sendCommand("-:" + fileName + ":" + line);
                }
            }
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
                        bp.getSourcePosition() != null &&
                        !debugProcess.getSession().areBreakpointsMuted() && bp.isEnabled()) { // Only include enabled and not globally muted breakpoints

                    VirtualFile file2 = bp.getSourcePosition().getFile();
                    String fileName = file2.getName();
                    int line = bp.getSourcePosition().getLine() + 1;

                    // Build breakpoint line with conditional support
                    StringBuilder breakpointLine = new StringBuilder();
                    breakpointLine.append("BP ").append(line).append(" ").append(fileName);
                    
                    // Add conditional information if available
                    if (bp.getProperties() instanceof HarbourDebuggerBreakpointProperties) {
                        HarbourDebuggerBreakpointProperties properties = 
                            (HarbourDebuggerBreakpointProperties) bp.getProperties();
                        
                        if (properties.hasCondition()) {
                            breakpointLine.append(" COND:").append(properties.getCondition());
                        }
                        
                        if (properties.hasHitCondition()) {
                            breakpointLine.append(" HIT:").append(properties.getHitCondition());
                        }
                        
                        if (properties.hasLogMessage()) {
                            breakpointLine.append(" LOG:").append(properties.getLogMessage());
                        }
                    }

                    writer.println(breakpointLine.toString());
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
    
    /**
     * Send all registered breakpoints to the remote debugger
     */
    public void sendAllBreakpoints() {
        if (isRemoteDebugger) {
            Project project = debugProcess.getSession().getProject();
            boolean globallyMuted = debugProcess.getSession().areBreakpointsMuted();
            
            HarbourLogger.log(project, "HarbourDebugger", 
                    "=== SENDING ALL BREAKPOINTS ===");
            HarbourLogger.log(project, "HarbourDebugger", 
                    "Global mute state: " + globallyMuted);
            HarbourLogger.log(project, "HarbourDebugger", 
                    "Total registered breakpoints: " + registeredBreakpoints.size());
            
            int enabledCount = 0;
            int disabledCount = 0;
            
            for (XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint : registeredBreakpoints) {
                if (breakpoint.getSourcePosition() != null) {
                    boolean individuallyEnabled = breakpoint.isEnabled();
                    boolean isEnabled = !globallyMuted && individuallyEnabled;
                    if (isEnabled) {
                        enabledCount++;
                    } else {
                        disabledCount++;
                    }
                    
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Breakpoint at " + breakpoint.getSourcePosition().getFile().getName() + 
                            ":" + (breakpoint.getSourcePosition().getLine() + 1) + 
                            " - globally muted: " + globallyMuted + 
                            ", individually enabled: " + individuallyEnabled + 
                            ", final enabled: " + isEnabled);
                }
                
                if (breakpoint.getSourcePosition() != null && !debugProcess.getSession().areBreakpointsMuted() && breakpoint.isEnabled()) {
                    String fileName = breakpoint.getSourcePosition().getFile().getName();
                    int line = breakpoint.getSourcePosition().getLine() + 1;
                    
                    // Build breakpoint command with conditional support following harbourCodeExtension protocol
                    StringBuilder breakpointCommand = new StringBuilder();
                    breakpointCommand.append("+:").append(fileName).append(":").append(line);
                    
                    HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
                    
                    // If properties is null, try to get from custom properties storage
                    if (properties == null) {
                        properties = HarbourDebuggerBreakpointPropertiesPanel.getCustomProperties(breakpoint);
                    }
                    
                    if (properties != null) {
                        // Add condition if present
                        if (properties.hasCondition()) {
                            String condition = properties.getCondition().replace(":", ";");
                            breakpointCommand.append(":?:").append(condition);
                        }
                        
                        // Add hit condition if present
                        if (properties.hasHitCondition()) {
                            breakpointCommand.append(":C:").append(properties.getHitCondition());
                        }
                        
                        // Add log message if present
                        if (properties.hasLogMessage()) {
                            String logMessage = properties.getLogMessage().replace(":", ";");
                            breakpointCommand.append(":L:").append(logMessage);
                        }
                    }
                    
                    debugProcess.sendCommand("BREAKPOINT");
                    debugProcess.sendCommand(breakpointCommand.toString());
                    
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Sent breakpoint (all): " + breakpointCommand.toString());
                }
            }
            
            HarbourLogger.log(project, "HarbourDebugger", 
                    "=== BREAKPOINTS SUMMARY ===");
            HarbourLogger.log(project, "HarbourDebugger", 
                    "Enabled: " + enabledCount + ", Disabled: " + disabledCount);
        }
    }
}
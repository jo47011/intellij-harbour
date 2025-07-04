package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.xdebugger.breakpoints.XBreakpoint;
import com.intellij.xdebugger.breakpoints.XLineBreakpoint;
import com.intellij.xdebugger.breakpoints.XLineBreakpointType;
import com.intellij.xdebugger.breakpoints.ui.XBreakpointCustomPropertiesPanel;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Line breakpoint type for Harbour debugger.
 * Defines which files support breakpoints and how they're displayed.
 * Supports conditional breakpoints with custom properties panel.
 */
public class HarbourDebuggerLineBreakpointType extends XLineBreakpointType<HarbourDebuggerBreakpointProperties> {

    public HarbourDebuggerLineBreakpointType() {
        super("harbour-line", "Harbour Line Breakpoints");
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "DEBUG: HarbourDebuggerLineBreakpointType constructor called");
    }

    @NotNull
    @Override
    public HarbourDebuggerBreakpointProperties createBreakpointProperties(@NotNull VirtualFile file, int line) {
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "=== CREATE BREAKPOINT PROPERTIES ===");
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "createBreakpointProperties() called for " + file.getName() + ":" + line);
        HarbourDebuggerBreakpointProperties props = new HarbourDebuggerBreakpointProperties();
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "Created properties object: " + props);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "Properties toString: " + props);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "=== END CREATE BREAKPOINT PROPERTIES ===");
        return props;
    }

    @Override
    public boolean canPutAt(@NotNull VirtualFile file, int line, @NotNull Project project) {
        // Be very specific - only Harbour files with our exact file type
        boolean isHarbourFile = file.getFileType() == HarbourFileType.INSTANCE;
        
        // Also check extension as backup
        String fileExtension = file.getExtension();
        boolean hasHarbourExtension = fileExtension != null && 
                (fileExtension.equalsIgnoreCase("prg") || fileExtension.equalsIgnoreCase("ch"));
        
        boolean canPut = isHarbourFile || hasHarbourExtension;
        
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "=== HARBOUR BREAKPOINT TYPE DEBUG ===");
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "canPutAt() called for " + file.getName() + 
                          " line " + line + " - result: " + canPut);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "File type: " + file.getFileType());
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "HarbourFileType.INSTANCE: " + HarbourFileType.INSTANCE);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "Is Harbour file type: " + isHarbourFile);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "File extension: " + fileExtension);
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "Has Harbour extension: " + hasHarbourExtension);
        
        // If this is a Harbour file, we MUST return true to claim ownership
        if (canPut) {
            HarbourLogger.log("HarbourDebuggerLineBreakpointType", "CLAIMING OWNERSHIP of breakpoint for Harbour file!");
        }
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "=== END HARBOUR BREAKPOINT TYPE DEBUG ===");
        
        return canPut;
    }

    @Nullable
    @Override
    public XBreakpointCustomPropertiesPanel<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> createCustomPropertiesPanel(@NotNull Project project) {
        HarbourLogger.log("HarbourDebuggerLineBreakpointType", "DEBUG: createCustomPropertiesPanel() called for project: " + project.getName());
        return new HarbourDebuggerBreakpointPropertiesPanel(project);
    }

    @NotNull
    @Override
    public String getDisplayText(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
        if (properties != null) {
            StringBuilder displayText = new StringBuilder("Harbour breakpoint");
            
            if (properties.hasCondition()) {
                displayText.append(" [").append(properties.getCondition()).append("]");
            }
            
            if (properties.hasHitCondition()) {
                displayText.append(" (hit: ").append(properties.getHitCondition()).append(")");
            }
            
            if (properties.hasLogMessage()) {
                displayText.append(" {log: ").append(properties.getLogMessage()).append("}");
            }
            
            return displayText.toString();
        }
        return "Harbour breakpoint";
    }
}
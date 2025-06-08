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
        System.out.println("DEBUG: HarbourDebuggerLineBreakpointType constructor called");
    }

    @NotNull
    @Override
    public HarbourDebuggerBreakpointProperties createBreakpointProperties(@NotNull VirtualFile file, int line) {
        System.out.println("=== CREATE BREAKPOINT PROPERTIES ===");
        System.out.println("createBreakpointProperties() called for " + file.getName() + ":" + line);
        HarbourDebuggerBreakpointProperties props = new HarbourDebuggerBreakpointProperties();
        System.out.println("Created properties object: " + props);
        System.out.println("Properties toString: " + props.toString());
        System.out.println("=== END CREATE BREAKPOINT PROPERTIES ===");
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
        
        System.out.println("=== HARBOUR BREAKPOINT TYPE DEBUG ===");
        System.out.println("canPutAt() called for " + file.getName() + 
                          " line " + line + " - result: " + canPut);
        System.out.println("File type: " + file.getFileType());
        System.out.println("HarbourFileType.INSTANCE: " + HarbourFileType.INSTANCE);
        System.out.println("Is Harbour file type: " + isHarbourFile);
        System.out.println("File extension: " + fileExtension);
        System.out.println("Has Harbour extension: " + hasHarbourExtension);
        
        // If this is a Harbour file, we MUST return true to claim ownership
        if (canPut) {
            System.out.println("CLAIMING OWNERSHIP of breakpoint for Harbour file!");
        }
        System.out.println("=== END HARBOUR BREAKPOINT TYPE DEBUG ===");
        
        return canPut;
    }

    @Nullable
    @Override
    public XBreakpointCustomPropertiesPanel<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> createCustomPropertiesPanel(@NotNull Project project) {
        System.out.println("DEBUG: createCustomPropertiesPanel() called for project: " + project.getName());
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
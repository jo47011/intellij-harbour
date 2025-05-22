package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.xdebugger.breakpoints.XLineBreakpointType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Line breakpoint type for Harbour debugger.
 * Defines which files support breakpoints and how they're displayed.
 */
public class HarbourDebuggerLineBreakpointType extends XLineBreakpointType<HarbourDebuggerBreakpointProperties> {

    public HarbourDebuggerLineBreakpointType() {
        super("harbour-line", "Harbour Line Breakpoints");
    }

    @Nullable
    @Override
    public HarbourDebuggerBreakpointProperties createBreakpointProperties(@NotNull VirtualFile file, int line) {
        return new HarbourDebuggerBreakpointProperties();
    }

    @Override
    public boolean canPutAt(@NotNull VirtualFile file, int line, @NotNull Project project) {
        // Only allow breakpoints in Harbour source files
        // Check for both file type and extension for better compatibility
        String fileExtension = file.getExtension();
        return file.getFileType() == HarbourFileType.INSTANCE ||
                (fileExtension != null && (fileExtension.equalsIgnoreCase("prg") ||
                        fileExtension.equalsIgnoreCase("ch")));
    }

    // Removed @Override since this method is not actually overriding a parent method
    public String getDisplayText(HarbourDebuggerBreakpointProperties properties) {
        return "Harbour breakpoint";
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.wm.ToolWindow;
import com.intellij.openapi.wm.ToolWindowManager;
import org.jetbrains.annotations.NotNull;

/**
 * Action to open DBF files in the Harbour DBF tool window
 */
public class HarbourDBFFileAction extends AnAction {
    
    public HarbourDBFFileAction() {
        super("Open in Harbour DBF Tool", "Open DBF file in Harbour DBF tool window", null);
    }
    
    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        if (project == null) {
            return;
        }
        
        VirtualFile file = e.getData(CommonDataKeys.VIRTUAL_FILE);
        if (file == null || !file.getName().toLowerCase().endsWith(".dbf")) {
            return;
        }
        
        // Open the DBF tool window
        ToolWindowManager toolWindowManager = ToolWindowManager.getInstance(project);
        ToolWindow toolWindow = toolWindowManager.getToolWindow("Harbour DBF");
        if (toolWindow != null) {
            toolWindow.show();
            
            // Log the file that was selected
            HarbourLogger.log("HarbourDBFFileAction", "Opened DBF tool window for file: " + file.getPath());
        }
    }
    
    @Override
    public void update(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        VirtualFile file = e.getData(CommonDataKeys.VIRTUAL_FILE);
        
        // Only enable for DBF files
        boolean enabled = project != null && 
                         file != null && 
                         file.getName().toLowerCase().endsWith(".dbf");
        
        e.getPresentation().setEnabledAndVisible(enabled);
    }
    
    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        // This action's update() method accesses VirtualFile which is fast and safe on BGT
        return ActionUpdateThread.BGT;
    }
}
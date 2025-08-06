package org.intellij.sdk.language;

import com.intellij.openapi.fileEditor.FileDocumentManager;
import com.intellij.openapi.fileEditor.FileDocumentManagerListener;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import org.jetbrains.annotations.NotNull;
import com.intellij.openapi.editor.Document;
import com.intellij.codeInsight.daemon.DaemonCodeAnalyzer;

/**
 * Listener to trigger linting when Harbour files are saved.
 */
public class HarbourLintOnSaveListener implements FileDocumentManagerListener {
    
    @Override
    public void beforeDocumentSaving(@NotNull Document document) {
        HarbourLogger.log("HarbourLinter", ">>> beforeDocumentSaving called <<<");
        
        // Get the file from the document
        VirtualFile file = FileDocumentManager.getInstance().getFile(document);
        if (file == null || !file.isValid()) {
            HarbourLogger.log("HarbourLinter", "File is null or invalid");
            return;
        }
        
        HarbourLogger.log("HarbourLinter", "File being saved: " + file.getPath() + ", Extension: " + file.getExtension());
        
        // Check if it's a Harbour file
        if (!"prg".equalsIgnoreCase(file.getExtension())) {
            HarbourLogger.log("HarbourLinter", "Not a Harbour file, skipping");
            return;
        }
        
        // Find the project
        Project project = null;
        for (Project p : ProjectManager.getInstance().getOpenProjects()) {
            if (PsiManager.getInstance(p).findFile(file) != null) {
                project = p;
                break;
            }
        }
        
        if (project == null) {
            return;
        }
        
        // Check if linting on save is enabled
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (!settings.isLintingEnabled() || !settings.isLintOnSave()) {
            return;
        }
        
        // Trigger a code analysis update for this file
        PsiFile psiFile = PsiManager.getInstance(project).findFile(file);
        if (psiFile != null) {
            HarbourLogger.log("HarbourLinter", "=== SAVE TRIGGERED - Triggering lint on save for: " + file.getName() + " ===");
            
            // Set save trigger flag for the external annotator
            String filePath = file.getPath();
            HarbourExternalAnnotator.setSaveTrigger(filePath);
            
            // Force external annotator to run
            DaemonCodeAnalyzer.getInstance(project).restart(psiFile);
        }
    }
}
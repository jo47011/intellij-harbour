package org.intellij.sdk.language;

import com.intellij.notification.Notification;
import com.intellij.notification.NotificationType;
import com.intellij.notification.Notifications;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.command.WriteCommandAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

/**
 * Action to format Harbour code
 */
public class HarbourFormatAction extends AnAction {
    private static final Logger LOG = Logger.getInstance(HarbourFormatAction.class);
    private static boolean DEBUG = true;

    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        debug("getActionUpdateThread called - Action ID: " + getClass().getName());
        return ActionUpdateThread.BGT;
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        String actionId = e.getActionManager().getId(this);
        String place = e.getPlace();
        debug("update() called - Action ID: " + actionId + ", Place: " + place);

        Project project = e.getProject();
        VirtualFile file = e.getData(CommonDataKeys.VIRTUAL_FILE);

        boolean isHarbourFile = false;
        if (project != null && file != null) {
            String extension = file.getExtension();
            isHarbourFile = extension != null && (extension.equals("prg") || extension.equals("ch"));

            debug("  File: " + file.getName() + ", Extension: " + extension + ", isHarbour: " + isHarbourFile);
        } else {
            debug("  Project or file is null");
        }

        e.getPresentation().setEnabledAndVisible(isHarbourFile);
        debug("  Setting enabled/visible: " + isHarbourFile);
    }

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        String actionId = e.getActionManager().getId(this);
        String place = e.getPlace();
        debug("*** actionPerformed() called - Action ID: " + actionId + ", Place: " + place);

        final Project project = e.getProject();
        final Editor editor = e.getData(CommonDataKeys.EDITOR);
        final VirtualFile virtualFile = e.getData(CommonDataKeys.VIRTUAL_FILE);

        if (project == null || editor == null || virtualFile == null) {
            debug("Action performed but missing required data");
            return;
        }

        debug("Processing file: " + virtualFile.getName());

        final Document document = editor.getDocument();
        final PsiFile psiFile = PsiDocumentManager.getInstance(project).getPsiFile(document);

        if (psiFile == null) {
            debug("No PSI file found for document");
            return;
        }

        // Ensure we're working with a Harbour file
        if (!(psiFile instanceof HarbourFile)) {
            debug("Not a Harbour file: " + psiFile.getClass().getName());
            return;
        }

        // Commit any pending document changes
        PsiDocumentManager.getInstance(project).commitDocument(document);

        // Perform the formatting in a write action to ensure changes are applied
        WriteCommandAction.runWriteCommandAction(project, "Format Harbour Code", null, () -> {
            try {
                // Prevent standard formatter and reference resolution during our formatting
                HarbourTokenTypeExtension.setFormattingInProgress(true);

                try {
                    // Create a formatter instance and apply our custom formatting
                    HarbourCodeFormatter formatter = new HarbourCodeFormatter(project);

                    // Apply formatting - this should now work with proper indentation
                    boolean changed = formatter.format(psiFile);

                    // Commit changes to PSI
                    PsiDocumentManager.getInstance(project).commitDocument(document);

                    // Show notification about what happened
                    String message = changed ? "Formatting applied successfully" : "No changes needed";
                    showNotification(project, "Harbour Code Formatted",
                            message + " for " + virtualFile.getName(),
                            NotificationType.INFORMATION);

                    // Force editor to redraw
                    editor.getComponent().repaint();
                } finally {
                    // Reset the formatting flag
                    HarbourTokenTypeExtension.setFormattingInProgress(false);
                }
            } catch (Exception ex) {
                LOG.warn("Error during formatting", ex);
                debug("Error during formatting: " + ex.getMessage());
                showNotification(project, "Harbour Formatting Error",
                        "Error: " + ex.getMessage(),
                        NotificationType.ERROR);
            }
        });
    }

    private void showNotification(Project project, String title, String content, NotificationType type) {
        Notifications.Bus.notify(
                new Notification("Harbour Formatter", title, content, type),
                project);
    }

    private void debug(String message) {
        if (!DEBUG) return;

        // Use centralized logging
        HarbourLogger.log("FormatAction", message);
    }
}
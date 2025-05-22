package org.intellij.sdk.language;

import com.intellij.codeInsight.generation.actions.CommentByLineCommentAction;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiFile;
import org.jetbrains.annotations.NotNull;

/**
 * Action for commenting/uncommenting lines in Harbour files.
 * The action delegates to IntelliJ's built-in CommentByLineCommentAction.
 */
public class HarbourCommentAction extends CommentByLineCommentAction {

    /**
     * Specifies that update should happen on a background thread
     * to avoid EDT warnings when accessing PSI elements.
     */
    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        return ActionUpdateThread.BGT;
    }

    /**
     * Updates the action's visibility and availability.
     */
    @Override
    public void update(@NotNull AnActionEvent e) {
        // Get project, editor, file
        Project project = e.getProject();
        Editor editor = e.getData(CommonDataKeys.EDITOR);
        PsiFile file = e.getData(CommonDataKeys.PSI_FILE);

        // Only enable the action for Harbour files with an editor
        boolean enabled = project != null && editor != null && file != null &&
                file.getLanguage() == HarbourLanguage.INSTANCE;
        e.getPresentation().setEnabledAndVisible(enabled);
    }

    /**
     * Performs the action using the parent class implementation.
     */
    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        // Get project, editor, file
        Project project = e.getProject();
        Editor editor = e.getData(CommonDataKeys.EDITOR);
        PsiFile file = e.getData(CommonDataKeys.PSI_FILE);

        if (project == null || editor == null || file == null ||
                file.getLanguage() != HarbourLanguage.INSTANCE) {
            return;
        }

        // Delegate to parent class (CommentByLineCommentAction)
        super.actionPerformed(e);
    }
}
package org.intellij.sdk.language;

import com.intellij.ide.structureView.StructureViewBuilder;
import com.intellij.ide.structureView.StructureViewModel;
import com.intellij.ide.structureView.TreeBasedStructureViewBuilder;
import com.intellij.lang.PsiStructureViewFactory;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.fileEditor.FileEditorManager;
import com.intellij.openapi.fileEditor.FileEditorManagerListener;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.Disposer;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

public class HarbourStructureViewFactory implements PsiStructureViewFactory {

    @Override
    public @Nullable StructureViewBuilder getStructureViewBuilder(@NotNull PsiFile psiFile) {
        if (!(psiFile instanceof HarbourFile harbourFile)) {
            return null;
        }

        // Get project for disposable registration
        final Project project = psiFile.getProject();

        return new TreeBasedStructureViewBuilder() {
            @Override
            public @NotNull StructureViewModel createStructureViewModel(@Nullable Editor editor) {
                // Create the model with editor for cursor tracking
                HarbourStructureViewModel model = new HarbourStructureViewModel(harbourFile, editor);

                // Register for disposal when project closes
                if (project != null && !project.isDisposed()) {
                    Disposer.register(project, model);
                }

                return model;
            }

            @Override
            public boolean isRootNodeShown() {
                return false;
            }
        };
    }

    // Register file editor manager listener to handle lifecycle events
    public static void registerDisposableListeners(Project project) {
        project.getMessageBus().connect().subscribe(
                FileEditorManagerListener.FILE_EDITOR_MANAGER,
                new FileEditorManagerListener() {
                    @Override
                    public void fileClosed(@NotNull FileEditorManager source, @NotNull VirtualFile file) {
                        // No need to do anything special here - the base IDE will handle cleanup
                        // when files are closed
                    }
                }
        );
    }
}
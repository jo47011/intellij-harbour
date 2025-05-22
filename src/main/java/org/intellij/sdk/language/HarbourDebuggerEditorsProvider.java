package org.intellij.sdk.language;

import com.intellij.openapi.fileTypes.FileType;
import com.intellij.openapi.project.Project;
import com.intellij.xdebugger.evaluation.XDebuggerEditorsProvider;
import com.intellij.xdebugger.XSourcePosition;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Editor integration for the Harbour debugger.
 * Provides support for evaluating expressions during debugging.
 */
public class HarbourDebuggerEditorsProvider extends XDebuggerEditorsProvider {

    @NotNull
    @Override
    public FileType getFileType() {
        return HarbourFileType.INSTANCE;
    }

    @NotNull
    @Override
    public com.intellij.openapi.editor.Document createDocument(@NotNull Project project,
                                                               @NotNull String text,
                                                               @Nullable XSourcePosition sourcePosition,
                                                               @NotNull com.intellij.xdebugger.evaluation.EvaluationMode mode) {
        return com.intellij.openapi.editor.EditorFactory.getInstance().createDocument(text);
    }
}
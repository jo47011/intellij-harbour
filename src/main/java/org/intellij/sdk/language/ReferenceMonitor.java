package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.ProjectActivity;
import com.intellij.openapi.diagnostic.Logger;
import kotlin.Unit;
import kotlin.coroutines.Continuation;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Monitors reference resolution in Harbour files
 */
public class ReferenceMonitor implements ProjectActivity {
    private static final Logger LOG = Logger.getInstance(ReferenceMonitor.class);

    @Nullable
    @Override
    public Object execute(@NotNull Project project, @NotNull Continuation<? super Unit> continuation) {
        LOG.info("ReferenceMonitor: Initialized for project " + project.getName());
        System.out.println("ReferenceMonitor: Initialized for project " + project.getName());
        return Unit.INSTANCE;
    }
}
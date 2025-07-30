package org.intellij.sdk.language;

import com.intellij.execution.filters.ConsoleFilterProvider;
import com.intellij.execution.filters.Filter;
import com.intellij.openapi.project.Project;
import org.jetbrains.annotations.NotNull;

/**
 * Provides console filters for Harbour compiler and runtime output.
 * This ensures that file references like "test-gui.prg(17)" are clickable in all console contexts.
 */
public class HarbourConsoleFilterProvider implements ConsoleFilterProvider {

    @NotNull
    @Override
    public Filter[] getDefaultFilters(@NotNull Project project) {
        // Provide the Harbour compiler output filter to make file references clickable
        return new Filter[] {
            new HarbourCompilerOutputFilter(project)
        };
    }
}
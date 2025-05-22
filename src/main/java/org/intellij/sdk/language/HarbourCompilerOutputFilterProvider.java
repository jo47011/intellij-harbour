package org.intellij.sdk.language;

import com.intellij.execution.filters.ConsoleFilterProvider;
import com.intellij.execution.filters.Filter;
import com.intellij.openapi.project.Project;
import org.jetbrains.annotations.NotNull;

/**
 * Provider for Harbour compiler output filters.
 * Registers the filter with the IDE to make compiler warnings/errors clickable in the console.
 */
public class HarbourCompilerOutputFilterProvider implements ConsoleFilterProvider {
    @NotNull
    @Override
    public Filter[] getDefaultFilters(@NotNull Project project) {
        return new Filter[]{new HarbourCompilerOutputFilter(project)};
    }
}
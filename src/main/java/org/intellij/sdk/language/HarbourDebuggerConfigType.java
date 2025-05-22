package org.intellij.sdk.language;

import com.intellij.execution.configurations.ConfigurationFactory;
import com.intellij.execution.configurations.ConfigurationType;
import com.intellij.execution.configurations.ConfigurationTypeUtil;
import com.intellij.execution.configurations.RunConfiguration;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.NotNullLazyValue;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;

/**
 * Configuration type for Harbour debugger.
 */
public class HarbourDebuggerConfigType implements ConfigurationType {

    @NotNull
    @Override
    public String getDisplayName() {
        return "Harbour Debugger";
    }

    @Override
    public String getConfigurationTypeDescription() {
        return "Debug Harbour applications";
    }

    @Override
    public Icon getIcon() {
        return HarbourIcons.FILE;
    }

    @NotNull
    @Override
    public String getId() {
        return "HARBOUR_DEBUG_CONFIG";
    }

    @Override
    public ConfigurationFactory[] getConfigurationFactories() {
        return new ConfigurationFactory[]{new ConfigurationFactory(this) {
            @NotNull
            @Override
            public RunConfiguration createTemplateConfiguration(@NotNull Project project) {
                return new HarbourDebuggerRunConfig(project, this, "Harbour Debug");
            }

            @Override
            public @NotNull String getId() {
                return "Harbour Debugger Factory";
            }
        }};
    }

    public static HarbourDebuggerConfigType getInstance() {
        return ConfigurationTypeUtil.findConfigurationType(HarbourDebuggerConfigType.class);
    }
}
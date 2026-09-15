package org.intellij.sdk.language;

import com.intellij.application.options.CodeStyleAbstractConfigurable;
import com.intellij.application.options.CodeStyleAbstractPanel;
import com.intellij.application.options.TabbedLanguageCodeStylePanel;
import com.intellij.lang.Language;
import com.intellij.psi.codeStyle.*;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Provides code style settings configuration for Harbour
 */
public class HarbourCodeStyleSettingsProvider extends CodeStyleSettingsProvider {
    
    @Override
    public @Nullable CustomCodeStyleSettings createCustomSettings(@NotNull CodeStyleSettings settings) {
        return new HarbourCodeStyleSettings(settings);
    }
    
    @NotNull
    @Override
    public CodeStyleConfigurable createConfigurable(@NotNull CodeStyleSettings settings, @NotNull CodeStyleSettings modelSettings) {
        return new CodeStyleAbstractConfigurable(settings, modelSettings, this.getConfigurableDisplayName()) {
            @Override
            protected @NotNull CodeStyleAbstractPanel createPanel(@NotNull CodeStyleSettings settings) {
                return new HarbourCodeStyleMainPanel(getCurrentSettings(), settings);
            }
        };
    }
    
    @Nullable
    @Override
    public String getConfigurableDisplayName() {
        return "Harbour";
    }

    @Nullable
    @Override
    public Language getLanguage() {
        return HarbourLanguage.INSTANCE;
    }
    
    private static class HarbourCodeStyleMainPanel extends TabbedLanguageCodeStylePanel {
        protected HarbourCodeStyleMainPanel(CodeStyleSettings currentSettings, CodeStyleSettings settings) {
            super(HarbourLanguage.INSTANCE, currentSettings, settings);
        }
        
        @Override
        protected void initTabs(CodeStyleSettings settings) {
            addIndentOptionsTab(settings);
            addTab(new HarbourWrappingAndBracesPanel(settings));
            addTab(new HarbourSpacesPanel(settings));
            addTab(new HarbourFormattingPanel(settings));
        }
    }
}
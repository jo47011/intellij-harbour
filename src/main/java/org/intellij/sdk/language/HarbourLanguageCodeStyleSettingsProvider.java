package org.intellij.sdk.language;

import com.intellij.application.options.IndentOptionsEditor;
import com.intellij.lang.Language;
import com.intellij.psi.codeStyle.*;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Provides code style settings for Harbour language
 */
public class HarbourLanguageCodeStyleSettingsProvider extends LanguageCodeStyleSettingsProvider {
    @NotNull
    @Override
    public com.intellij.lang.Language getLanguage() {
        return HarbourLanguage.INSTANCE;
    }

    @Nullable
    @Override
    public String getCodeSample(@NotNull SettingsType settingsType) {
        return """
                // Sample Harbour code for preview
                FUNCTION SampleFunction(param1, param2)
                   LOCAL result, count := 0
                   
                   // This is a comment
                   IF param1 > 10
                      result := param1 * param2
                   ELSE
                      result := param1 + param2
                   ENDIF
                   
                   // Loop example
                   DO WHILE count < 10
                      count++
                      ? "Count:", count
                   ENDDO
                   
                   RETURN result
                """;
    }

    @Override
    public void customizeSettings(@NotNull CodeStyleSettingsCustomizable consumer, @NotNull SettingsType settingsType) {
        if (settingsType == SettingsType.INDENT_SETTINGS) {
            consumer.showStandardOptions("INDENT_SIZE");
            consumer.showStandardOptions("TAB_SIZE");
            consumer.showStandardOptions("USE_TAB_CHARACTER");
        } else if (settingsType == SettingsType.WRAPPING_AND_BRACES_SETTINGS) {
            // Show wrapping options
            consumer.showStandardOptions("WRAP_ON_TYPING");
        }
    }
    
    @Override
    public IndentOptionsEditor getIndentOptionsEditor() {
        return new IndentOptionsEditor() {
            @Override
            protected void addComponents() {
                super.addComponents();
                // Additional components could be added here if needed
            }
        };
    }
    
    @Override
    public void customizeDefaults(@NotNull CommonCodeStyleSettings commonSettings, @NotNull CommonCodeStyleSettings.IndentOptions indentOptions) {
        // Set default indentation to 2 spaces
        indentOptions.INDENT_SIZE = 2;
        indentOptions.TAB_SIZE = 2;
        indentOptions.USE_TAB_CHARACTER = false;
        
        // Set default hard wrap to 0 (disabled)
        commonSettings.RIGHT_MARGIN = 0;
        
        // Enable hard wrap editing
        commonSettings.WRAP_LONG_LINES = false;
    }
}
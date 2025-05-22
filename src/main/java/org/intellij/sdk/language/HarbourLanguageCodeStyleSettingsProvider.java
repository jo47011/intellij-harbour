package org.intellij.sdk.language;

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
        if (settingsType == SettingsType.SPACING_SETTINGS) {
            consumer.showStandardOptions("SPACE_AROUND_ASSIGNMENT_OPERATORS");
            consumer.showStandardOptions("SPACE_AROUND_LOGICAL_OPERATORS");
            consumer.showStandardOptions("SPACE_AROUND_EQUALITY_OPERATORS");
            consumer.showStandardOptions("SPACE_AROUND_RELATIONAL_OPERATORS");
            consumer.showStandardOptions("SPACE_AFTER_COMMA");
            consumer.showStandardOptions("SPACE_BEFORE_COMMA");
        } else if (settingsType == SettingsType.WRAPPING_AND_BRACES_SETTINGS) {
            consumer.showStandardOptions("RIGHT_MARGIN");
            consumer.showStandardOptions("WRAP_ON_TYPING");
        } else if (settingsType == SettingsType.INDENT_SETTINGS) {
            consumer.showStandardOptions("INDENT_SIZE");
            consumer.showStandardOptions("TAB_SIZE");
            consumer.showStandardOptions("USE_TAB_CHARACTER");
        }
    }
}
package org.intellij.sdk.language;

import com.intellij.application.options.CodeStyle;
import com.intellij.lang.Language;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.modifier.CodeStyleSettingsModifier;
import com.intellij.psi.codeStyle.modifier.TransientCodeStyleSettings;
import com.intellij.psi.codeStyle.modifier.CodeStyleStatusBarUIContributor;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import java.util.logging.Logger;

/**
 * Sets the right margin position for Harbour files
 */
public class HarbourLineMarginProvider implements CodeStyleSettingsModifier {
    private static final Logger LOG = Logger.getLogger(HarbourLineMarginProvider.class.getName());

    @Override
    public boolean modifySettings(@NotNull TransientCodeStyleSettings settings, @NotNull PsiFile psiFile) {
        // Only modify for Harbour files
        if (!(psiFile instanceof HarbourFile)) {
            return false;
        }

        // Get the line break position from our settings
        try {
            HarbourSettings harbourSettings = HarbourSettings.getInstance(psiFile.getProject());
            if (harbourSettings != null) {
                int lineBreakPosition = harbourSettings.getLineBreakPosition();
                if (lineBreakPosition > 0) {
                    HarbourLogger.log("LineMarginProvider", "Setting right margin to: " + lineBreakPosition);

                    Language language = psiFile.getLanguage();

                    // Set the right margin directly on common settings
                    settings.getCommonSettings(language).RIGHT_MARGIN = lineBreakPosition;

                    // Also set it using the standard API
                    settings.setRightMargin(language, lineBreakPosition);

                    // Update editor settings as well
                    CodeStyle.getSettings(psiFile).setRightMargin(language, lineBreakPosition);

                    HarbourLogger.log("LineMarginProvider", "Right margin set to: " + lineBreakPosition);
                    return true;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("LineMarginProvider", "Error in margin provider: " + e.getMessage());
            e.printStackTrace();
        }

        return false;
    }

    @Override
    @Nullable
    public CodeStyleStatusBarUIContributor getStatusBarUiContributor(@NotNull TransientCodeStyleSettings settings) {
        // Return null as we don't need a custom UI contributor in the status bar
        return null;
    }

    @Override
    @NotNull
    public String getName() {
        // Return a unique name for this modifier
        return "HarbourLineMarginModifier";
    }
}
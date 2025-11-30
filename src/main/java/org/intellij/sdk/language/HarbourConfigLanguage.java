package org.intellij.sdk.language;

import com.intellij.lang.Language;

/**
 * Language definition for Harbour configuration files (.hbp, .hbc, .cfg)
 */
public class HarbourConfigLanguage extends Language {
    public static final HarbourConfigLanguage INSTANCE = new HarbourConfigLanguage();

    private HarbourConfigLanguage() {
        super("HarbourConfig");
    }
}

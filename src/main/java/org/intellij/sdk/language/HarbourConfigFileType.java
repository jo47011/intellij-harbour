package org.intellij.sdk.language;

import com.intellij.openapi.fileTypes.LanguageFileType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;

/**
 * File type for Harbour configuration files (.hbp, .hbc)
 * These files use # for line comments (shell-style comments)
 * Note: .cfg was removed - too generic/common, causes slow indexing
 */
public class HarbourConfigFileType extends LanguageFileType {
    public static final HarbourConfigFileType INSTANCE = new HarbourConfigFileType();

    protected HarbourConfigFileType() {
        super(HarbourConfigLanguage.INSTANCE);
    }

    @NotNull
    @Override
    public String getName() {
        return "Harbour Config File";
    }

    @NotNull
    @Override
    public String getDescription() {
        return "Harbour configuration file";
    }

    @NotNull
    @Override
    public String getDefaultExtension() {
        return "hbp";
    }

    @Nullable
    @Override
    public Icon getIcon() {
        return HarbourIcons.FILE;
    }
}

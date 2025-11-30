package org.intellij.sdk.language;

import com.intellij.extapi.psi.PsiFileBase;
import com.intellij.openapi.fileTypes.FileType;
import com.intellij.psi.FileViewProvider;
import org.jetbrains.annotations.NotNull;

/**
 * PSI file implementation for Harbour configuration files
 */
public class HarbourConfigFile extends PsiFileBase {
    public HarbourConfigFile(@NotNull FileViewProvider viewProvider) {
        super(viewProvider, HarbourConfigLanguage.INSTANCE);
    }

    @NotNull
    @Override
    public FileType getFileType() {
        return HarbourConfigFileType.INSTANCE;
    }

    @Override
    public String toString() {
        return "Harbour Config File";
    }
}

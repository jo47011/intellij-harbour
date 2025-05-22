package org.intellij.sdk.language;

import com.intellij.openapi.fileTypes.LanguageFileType;
import com.intellij.openapi.diagnostic.Logger;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;

public class HarbourFileType extends LanguageFileType {
  private static final Logger LOG = Logger.getInstance(HarbourFileType.class);
  public static final HarbourFileType INSTANCE = new HarbourFileType();

  protected HarbourFileType() {
    super(HarbourLanguage.INSTANCE);
    LOG.info("HarbourFileType constructed");
  }

  @NotNull
  @Override
  public String getName() {
    return "Harbour File";
  }

  @NotNull
  @Override
  public String getDescription() {
    return "Harbour language file";
  }

  @NotNull
  @Override
  public String getDefaultExtension() {
    return "prg";
  }

  @Nullable
  @Override
  public Icon getIcon() {
    // Return the Harbour icon, or null if you have no icon asset
    return HarbourIcons.FILE;
  }

}
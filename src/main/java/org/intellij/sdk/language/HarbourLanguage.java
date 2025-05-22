package org.intellij.sdk.language;

import com.intellij.lang.Language;
import org.jetbrains.annotations.NotNull;

/**
 * Language definition for Harbour.
 */
public class HarbourLanguage extends Language {
  public static final HarbourLanguage INSTANCE = new HarbourLanguage();

  private HarbourLanguage() {
    super("Harbour");
  }

  @NotNull
  @Override
  public String getDisplayName() {
    return "Harbour";
  }

  @Override
  public boolean isCaseSensitive() {
    return false;
  }
}
package org.intellij.sdk.language;

import com.intellij.lexer.FlexAdapter;
import org.intellij.sdk.language._HarbourLexer;  // needed: do not remove
import java.io.Reader;

public class HarbourLexerAdapter extends FlexAdapter {
  public HarbourLexerAdapter() {
    super(new _HarbourLexer((Reader)null));
  }
}
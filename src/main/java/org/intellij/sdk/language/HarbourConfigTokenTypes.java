package org.intellij.sdk.language;

import com.intellij.psi.tree.IElementType;
import com.intellij.psi.tree.TokenSet;

/**
 * Token types for Harbour configuration files
 */
public class HarbourConfigTokenTypes {
    public static final IElementType COMMENT = new IElementType("COMMENT", HarbourConfigLanguage.INSTANCE);
    public static final IElementType TEXT = new IElementType("TEXT", HarbourConfigLanguage.INSTANCE);

    public static final TokenSet COMMENTS = TokenSet.create(COMMENT);
}

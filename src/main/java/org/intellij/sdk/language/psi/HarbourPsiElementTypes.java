package org.intellij.sdk.language.psi;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.HarbourLanguage;
import org.jetbrains.annotations.NotNull;

public class HarbourPsiElementTypes {
    private static final Logger LOG = Logger.getInstance(HarbourPsiElementTypes.class);

    public static final IElementType IDENTIFIER = new HarbourElementType("IDENTIFIER");
    public static final IElementType FUNCTION_DECLARATION = new HarbourElementType("FUNCTION_DECLARATION");

    static {
        LOG.info("HarbourPsiElementTypes loaded");
    }

    private static class HarbourElementType extends IElementType {
        public HarbourElementType(@NotNull String debugName) {
            super(debugName, HarbourLanguage.INSTANCE);
            LOG.info("HarbourElementType created: " + debugName);
        }
    }
}
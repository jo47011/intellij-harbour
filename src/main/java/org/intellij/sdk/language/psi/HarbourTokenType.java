package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.HarbourLanguage;
import org.jetbrains.annotations.NonNls;
import org.jetbrains.annotations.NotNull;

/**
 * Custom token type for Harbour language.
 */
public class HarbourTokenType extends IElementType {
    /**
     * Create a new token type with the given debug name.
     *
     * @param debugName The debug name for this token type
     */
    public HarbourTokenType(@NotNull @NonNls String debugName) {
        super(debugName, HarbourLanguage.INSTANCE);
    }

    @Override
    public String toString() {
        return "HarbourTokenType." + super.toString();
    }
}
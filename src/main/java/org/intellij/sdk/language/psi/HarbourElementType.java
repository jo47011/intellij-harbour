package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.HarbourLanguage;
import org.jetbrains.annotations.NonNls;
import org.jetbrains.annotations.NotNull;

/**
 * Custom element type for Harbour language elements.
 */
public class HarbourElementType extends IElementType {
    public HarbourElementType(@NotNull @NonNls String debugName) {
        super(debugName, HarbourLanguage.INSTANCE);
    }

    @Override
    public String toString() {
        return "HarbourElementType." + super.toString();
    }

    /**
     * Checks if this is an identifier type
     */
    public boolean isIdentifier() {
        return toString().contains("IDENT");
    }
}
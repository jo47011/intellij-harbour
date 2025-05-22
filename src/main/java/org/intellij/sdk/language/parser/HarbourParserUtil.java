package org.intellij.sdk.language.parser;

import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.HarbourElementType;

/**
 * Utility class for the Harbour parser.
 */
public class HarbourParserUtil {
    /**
     * Creates a new element type with the given name.
     *
     * @param name the name of the element type
     * @return the new element type
     */
    public static IElementType createType(String name) {
        return new HarbourElementType(name);
    }
}
package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;

/**
 * Adapter class to map between custom token types and generated token types.
 * This ensures compatibility between our custom token definitions and the BNF-generated elements.
 */
public class HarbourTokenAdapter {
    /**
     * Maps a HarbourCustomTypes token to its equivalent in HarbourTypes
     * @param customToken The custom token from HarbourCustomTypes
     * @return The equivalent token from HarbourTypes
     */
    public static IElementType toTypesToken(IElementType customToken) {
        if (customToken == null) {
            return null;
        }

        // Map custom tokens to their generated equivalents
        String name = customToken.toString();

        // Use reflection to find the equivalent token in HarbourTypes
        try {
            java.lang.reflect.Field field = HarbourCustomTypes.class.getField(name);
            return (IElementType) field.get(null);
        } catch (Exception e) {
            // If no matching token is found, return the original
            return customToken;
        }
    }

    /**
     * Maps a HarbourTypes token to its equivalent in HarbourCustomTypes
     * @param typesToken The token from HarbourTypes
     * @return The equivalent token from HarbourCustomTypes
     */
    public static IElementType toCustomToken(IElementType typesToken) {
        if (typesToken == null) {
            return null;
        }

        // Map generated tokens to their custom equivalents
        String name = typesToken.toString();

        // Use reflection to find the equivalent token in HarbourCustomTypes
        try {
            java.lang.reflect.Field field = HarbourCustomTypes.class.getField(name);
            return (IElementType) field.get(null);
        } catch (Exception e) {
            // If no matching token is found, return the original
            return typesToken;
        }
    }
}
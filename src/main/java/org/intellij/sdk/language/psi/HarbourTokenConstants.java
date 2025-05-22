package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;

/**
 * Token constants for Harbour language.
 * Provides fallback constants for tokens that might not be properly generated.
 */
public interface HarbourTokenConstants {
    // Keywords
    IElementType STATIC = new HarbourTokenType("STATIC");
    IElementType SWITCH = new HarbourTokenType("SWITCH");
    IElementType ENDSWITCH = new HarbourTokenType("ENDSWITCH");
    IElementType CASE = new HarbourTokenType("CASE");
    IElementType OTHERWISE = new HarbourTokenType("OTHERWISE");
    IElementType EXIT = new HarbourTokenType("EXIT");
    IElementType LOOP = new HarbourTokenType("LOOP");

    // Symbols
    IElementType AT = new HarbourTokenType("AT");
    IElementType AMP = new HarbourTokenType("AMP");
    IElementType DOLLAR = new HarbourTokenType("DOLLAR");
    IElementType DOT = new HarbourTokenType("DOT");
    IElementType SEMICOLON = new HarbourTokenType("SEMICOLON");

    // Other
    IElementType MEMVAR = new HarbourTokenType("MEMVAR");
    IElementType PRIVATE = new HarbourTokenType("PRIVATE");
    IElementType TROUBLE = new HarbourTokenType("TROUBLE");
}
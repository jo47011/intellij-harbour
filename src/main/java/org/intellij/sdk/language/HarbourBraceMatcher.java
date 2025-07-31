package org.intellij.sdk.language;

import com.intellij.lang.BracePair;
import com.intellij.lang.PairedBraceMatcher;
import com.intellij.psi.PsiFile;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Handles bracket matching and auto-completion for Harbour language.
 * 
 * Features:
 * - Visual highlighting of matching brackets
 * - Auto-completion of closing brackets
 * - Support for (), [], {} pairs
 * - Smart navigation and selection
 */
public class HarbourBraceMatcher implements PairedBraceMatcher {

    /**
     * Define the bracket pairs supported in Harbour language.
     */
    private static final BracePair[] BRACE_PAIRS = new BracePair[]{
        // Parentheses - for function calls, expressions, conditions
        new BracePair(HarbourTypes.LPAREN, HarbourTypes.RPAREN, false),
        
        // Square brackets - for array access, array literals  
        new BracePair(HarbourTypes.LBRACKET, HarbourTypes.RBRACKET, false),
        
        // Curly braces - for code blocks, object literals (if supported)
        new BracePair(HarbourTypes.LBRACE, HarbourTypes.RBRACE, true)  // structural = true for code blocks
    };

    public HarbourBraceMatcher() {
        HarbourLogger.log("BraceMatcher", "HarbourBraceMatcher initialized with " + BRACE_PAIRS.length + " brace pairs");
    }

    /**
     * Returns the array of brace pairs supported by this matcher.
     * 
     * @return array of BracePair objects
     */
    @Override
    public BracePair @NotNull [] getPairs() {
        return BRACE_PAIRS;
    }

    /**
     * Determines if bracket matching should be performed at the specified position.
     * 
     * @param tokenType the token type at the current position
     * @param file the PSI file
     * @param offset the offset in the file
     * @return true if bracket matching should be performed
     */
    @Override
    public boolean isPairedBracesAllowedBeforeType(@NotNull IElementType tokenType, @Nullable IElementType contextType) {
        // Allow bracket matching before most token types, but not within strings or comments
        boolean allowed = tokenType != HarbourTypes.STRING_LITERAL &&
                         tokenType != HarbourTypes.EOL_COMMENT &&
                         tokenType != HarbourTypes.BLOCK_COMMENT;
        
        HarbourLogger.log("BraceMatcher", "isPairedBracesAllowedBeforeType - tokenType: " + tokenType + 
                         ", contextType: " + contextType + ", allowed: " + allowed);
        
        return allowed;
    }

    /**
     * Returns the start offset for code block that should be navigated to when matching braces.
     * This is primarily used for structural braces (like curly braces).
     * 
     * @param file the PSI file
     * @param openingBraceOffset offset of the opening brace
     * @return the offset to navigate to, or the same offset if no special navigation needed
     */
    @Override
    public int getCodeConstructStart(PsiFile file, int openingBraceOffset) {
        // Validate the offset to prevent IndexOutOfBoundsException
        if (openingBraceOffset < 0 || openingBraceOffset >= file.getTextLength()) {
            HarbourLogger.log("BraceMatcher", "Invalid offset: " + openingBraceOffset + 
                             ", file length: " + file.getTextLength());
            return 0; // Return safe offset
        }
        
        HarbourLogger.log("BraceMatcher", "getCodeConstructStart - file: " + file.getName() + 
                         ", offset: " + openingBraceOffset);
        
        // Return the same offset - no special navigation needed for now
        // This prevents the IndexOutOfBoundsException by not returning -1
        return openingBraceOffset;
    }
}
package org.intellij.sdk.language;

import com.intellij.codeInsight.editorActions.SimpleTokenSetQuoteHandler;
import com.intellij.psi.TokenType;
import com.intellij.psi.tree.TokenSet;
import org.intellij.sdk.language.psi.HarbourTypes;

/**
 * Handles automatic quote completion and smart quote behavior for Harbour language.
 * 
 * Features:
 * - Auto-completes closing quotes when typing opening quote
 * - Wraps selected text with quotes
 * - Smart navigation over existing closing quotes
 */
public class HarbourQuoteHandler extends SimpleTokenSetQuoteHandler {

    /**
     * Define token types where quote completion should work.
     * This includes string literals and whitespace.
     */
    public HarbourQuoteHandler() {
        super(TokenSet.create(
            HarbourTypes.STRING_LITERAL,
            TokenType.WHITE_SPACE  // Allow in whitespace for new strings
        ));
        
        HarbourLogger.log("QuoteHandler", "HarbourQuoteHandler initialized");
    }
}
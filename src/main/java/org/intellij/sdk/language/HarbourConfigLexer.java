package org.intellij.sdk.language;

import com.intellij.lexer.LexerBase;
import com.intellij.psi.TokenType;
import com.intellij.psi.tree.IElementType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Simple lexer for Harbour configuration files.
 * Tokenizes the file into lines, recognizing # comments.
 */
public class HarbourConfigLexer extends LexerBase {
    private CharSequence buffer;
    private int bufferEnd;
    private int tokenStart;
    private int tokenEnd;
    private IElementType tokenType;

    @Override
    public void start(@NotNull CharSequence buffer, int startOffset, int endOffset, int initialState) {
        this.buffer = buffer;
        this.bufferEnd = endOffset;
        this.tokenStart = startOffset;
        this.tokenEnd = startOffset;
        advance();
    }

    @Override
    public int getState() {
        return 0;
    }

    @Override
    public @Nullable IElementType getTokenType() {
        return tokenType;
    }

    @Override
    public int getTokenStart() {
        return tokenStart;
    }

    @Override
    public int getTokenEnd() {
        return tokenEnd;
    }

    @Override
    public void advance() {
        tokenStart = tokenEnd;
        if (tokenStart >= bufferEnd) {
            tokenType = null;
            return;
        }

        char c = buffer.charAt(tokenStart);

        // Handle whitespace
        if (Character.isWhitespace(c)) {
            tokenEnd = tokenStart + 1;
            while (tokenEnd < bufferEnd && Character.isWhitespace(buffer.charAt(tokenEnd))) {
                tokenEnd++;
            }
            tokenType = TokenType.WHITE_SPACE;
            return;
        }

        // Handle # comments - consume until end of line
        if (c == '#') {
            tokenEnd = tokenStart + 1;
            while (tokenEnd < bufferEnd && buffer.charAt(tokenEnd) != '\n') {
                tokenEnd++;
            }
            tokenType = HarbourConfigTokenTypes.COMMENT;
            return;
        }

        // Everything else is regular text - consume until whitespace or comment
        tokenEnd = tokenStart + 1;
        while (tokenEnd < bufferEnd) {
            char next = buffer.charAt(tokenEnd);
            if (next == '#' || next == '\n') {
                break;
            }
            tokenEnd++;
        }
        tokenType = HarbourConfigTokenTypes.TEXT;
    }

    @Override
    public @NotNull CharSequence getBufferSequence() {
        return buffer;
    }

    @Override
    public int getBufferEnd() {
        return bufferEnd;
    }
}

package org.intellij.sdk.language;

import com.intellij.lexer.Lexer;
import com.intellij.openapi.editor.DefaultLanguageHighlighterColors;
import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.editor.markup.TextAttributes;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
import org.jetbrains.annotations.NotNull;

import java.awt.*;

import static com.intellij.openapi.editor.colors.TextAttributesKey.createTextAttributesKey;

/**
 * Assign text attributes to each set of tokens
 */
public class HarbourSyntaxHighlighter extends com.intellij.openapi.fileTypes.SyntaxHighlighterBase {

  // 1) Basic sets
  public static final TextAttributesKey KEYWORD = createTextAttributesKey(
          "HARBOUR_KEYWORD", DefaultLanguageHighlighterColors.KEYWORD
  );
  public static final TextAttributesKey NUMBER = createTextAttributesKey(
          "HARBOUR_NUMBER", DefaultLanguageHighlighterColors.NUMBER
  );
  public static final TextAttributesKey STRING = createTextAttributesKey(
          "HARBOUR_STRING", DefaultLanguageHighlighterColors.STRING
  );
  public static final TextAttributesKey COMMENT = createTextAttributesKey(
          "HARBOUR_COMMENT", DefaultLanguageHighlighterColors.LINE_COMMENT
  );
  public static final TextAttributesKey OPERATOR = createTextAttributesKey(
          "HARBOUR_OPERATOR", DefaultLanguageHighlighterColors.OPERATION_SIGN
  );
  // 2) For @, & separately (if you want them to have a different color):
  public static final TextAttributesKey AT_SYMBOL = createTextAttributesKey(
          "HARBOUR_AT_SYMBOL", DefaultLanguageHighlighterColors.OPERATION_SIGN
  );
  public static final TextAttributesKey AMPERSAND = createTextAttributesKey(
          "HARBOUR_AMPERSAND", DefaultLanguageHighlighterColors.OPERATION_SIGN
  );

  // Create a custom TextAttributes for local functions (blue with configurable underline)
  private static final TextAttributes LOCAL_FUNCTION_ATTRIBUTES = new TextAttributes();
  static {
    LOCAL_FUNCTION_ATTRIBUTES.setForegroundColor(new Color(0, 102, 204)); // Blue (#0066CC)
    // Note: Don't set effect type or effect color by default - let the color scheme handle it
  }

  // Create a custom TextAttributes for external functions
  private static final TextAttributes EXTERNAL_FUNCTION_ATTRIBUTES = new TextAttributes();
  static {
    EXTERNAL_FUNCTION_ATTRIBUTES.setForegroundColor(new Color(0x97, 0xB3, 0xE8)); // Light blue (#97B3E8)
    // Note: Don't set effect type or effect color by default - let the color scheme handle it
  }

  // 3) Function colors with custom defaults
  public static final TextAttributesKey LOCAL_FUNCTION = createTextAttributesKey(
          "HARBOUR_LOCAL_FUNCTION", LOCAL_FUNCTION_ATTRIBUTES
  );
  public static final TextAttributesKey EXTERNAL_FUNCTION = createTextAttributesKey(
          "HARBOUR_EXTERNAL_FUNCTION", EXTERNAL_FUNCTION_ATTRIBUTES
  );

  // Return them in arrays
  private static final TextAttributesKey[] KEYWORD_KEYS = new TextAttributesKey[]{ KEYWORD };
  private static final TextAttributesKey[] NUMBER_KEYS  = new TextAttributesKey[]{ NUMBER };
  private static final TextAttributesKey[] STRING_KEYS  = new TextAttributesKey[]{ STRING };
  private static final TextAttributesKey[] COMMENT_KEYS = new TextAttributesKey[]{ COMMENT };
  private static final TextAttributesKey[] OPERATOR_KEYS= new TextAttributesKey[]{ OPERATOR };
  private static final TextAttributesKey[] AT_KEYS      = new TextAttributesKey[]{ AT_SYMBOL };
  private static final TextAttributesKey[] AMP_KEYS     = new TextAttributesKey[]{ AMPERSAND };
  private static final TextAttributesKey[] EMPTY_KEYS   = new TextAttributesKey[0];

  @NotNull
  @Override
  public Lexer getHighlightingLexer() {
    return new HarbourLexerAdapter();
  }

  @Override
  public TextAttributesKey @NotNull [] getTokenHighlights(IElementType tokenType) {
    // Keywords
    if (tokenType == HarbourCustomTypes.IF ||
            tokenType == HarbourCustomTypes.ELSE ||
            tokenType == HarbourCustomTypes.ELSEIF ||
            tokenType == HarbourCustomTypes.ENDIF ||
            tokenType == HarbourCustomTypes.DO ||
            tokenType == HarbourCustomTypes.WHILE ||
            tokenType == HarbourCustomTypes.ENDDO ||
            tokenType == HarbourCustomTypes.FUNCTION ||
            tokenType == HarbourCustomTypes.ENDFUNCTION ||
            tokenType == HarbourCustomTypes.PROCEDURE ||
            tokenType == HarbourCustomTypes.LOCAL ||
            tokenType == HarbourCustomTypes.STATIC ||
            tokenType == HarbourCustomTypes.CLASS ||
            tokenType == HarbourCustomTypes.ENDCLASS ||
            tokenType == HarbourCustomTypes.METHOD ||
            tokenType == HarbourCustomTypes.ENDMETHOD ||
            tokenType == HarbourCustomTypes.SWITCH ||
            tokenType == HarbourCustomTypes.ENDSWITCH ||
            tokenType == HarbourCustomTypes.CASE ||
            tokenType == HarbourCustomTypes.OTHERWISE ||
            tokenType == HarbourCustomTypes.RETURN ||
            tokenType == HarbourCustomTypes.EXIT ||
            tokenType == HarbourCustomTypes.LOOP ||
            tokenType == HarbourCustomTypes.AND ||
            tokenType == HarbourCustomTypes.OR ||
            tokenType == HarbourCustomTypes.NOT) {
      return KEYWORD_KEYS;
    }
    // Comments
    else if (tokenType == HarbourCustomTypes.EOL_COMMENT || tokenType == HarbourCustomTypes.BLOCK_COMMENT) {
      return COMMENT_KEYS;
    }
    // Strings
    else if (tokenType == HarbourCustomTypes.STRING_LITERAL) {
      return STRING_KEYS;
    }
    // Numbers
    else if (tokenType == HarbourCustomTypes.NUMBER) {
      return NUMBER_KEYS;
    }
    // Ampersand or @
    else if (tokenType == HarbourCustomTypes.AT) {
      return AT_KEYS;
    }
    else if (tokenType == HarbourCustomTypes.AMP) {
      return AMP_KEYS;
    }
    // Operators / punctuation
    else if (
            tokenType == HarbourCustomTypes.EQ     || tokenType == HarbourCustomTypes.EQEQ   ||
                    tokenType == HarbourCustomTypes.GT     || tokenType == HarbourCustomTypes.LT     ||
                    tokenType == HarbourCustomTypes.GTEQ   || tokenType == HarbourCustomTypes.LTEQ   ||
                    tokenType == HarbourCustomTypes.NEQ    || tokenType == HarbourCustomTypes.PLUS   ||
                    tokenType == HarbourCustomTypes.MINUS  || tokenType == HarbourCustomTypes.MUL    ||
                    tokenType == HarbourCustomTypes.DIV    || tokenType == HarbourCustomTypes.COLON  ||
                    tokenType == HarbourCustomTypes.COMMA  || tokenType == HarbourCustomTypes.LPAREN ||
                    tokenType == HarbourCustomTypes.RPAREN || tokenType == HarbourCustomTypes.LBRACE ||
                    tokenType == HarbourCustomTypes.RBRACE || tokenType == HarbourCustomTypes.LBRACKET ||
                    tokenType == HarbourCustomTypes.RBRACKET
    ) {
      return OPERATOR_KEYS;
    }
    return EMPTY_KEYS;
  }
}
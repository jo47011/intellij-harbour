package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;

/**
 * Concrete class with all token and element type definitions.
 */
public class HarbourTypeDefinitions {
    // Token types
    public static final IElementType PREPROC_DIRECTIVE = new HarbourTokenType("PREPROC_DIRECTIVE");
    public static final IElementType FUNCTION = new HarbourTokenType("FUNCTION");
    public static final IElementType PROCEDURE = new HarbourTokenType("PROCEDURE");
    public static final IElementType CLASS = new HarbourTokenType("CLASS");
    public static final IElementType METHOD = new HarbourTokenType("METHOD");
    public static final IElementType INHERIT = new HarbourTokenType("INHERIT");
    public static final IElementType ENDMETHOD = new HarbourTokenType("ENDMETHOD");
    public static final IElementType ENDCLASS = new HarbourTokenType("ENDCLASS");
    public static final IElementType ENDFUNCTION = new HarbourTokenType("ENDFUNCTION");
    public static final IElementType ENDPROCEDURE = new HarbourTokenType("ENDPROCEDURE");
    public static final IElementType LOCAL = new HarbourTokenType("LOCAL");
    public static final IElementType STATIC = new HarbourTokenType("STATIC");
    public static final IElementType IF = new HarbourTokenType("IF");
    public static final IElementType ELSE = new HarbourTokenType("ELSE");
    public static final IElementType ENDIF = new HarbourTokenType("ENDIF");
    public static final IElementType DO = new HarbourTokenType("DO");
    public static final IElementType WHILE = new HarbourTokenType("WHILE");
    public static final IElementType ENDDO = new HarbourTokenType("ENDDO");
    public static final IElementType FOR = new HarbourTokenType("FOR");
    public static final IElementType NEXT = new HarbourTokenType("NEXT");
    public static final IElementType SWITCH = new HarbourTokenType("SWITCH");
    public static final IElementType CASE = new HarbourTokenType("CASE");
    public static final IElementType OTHERWISE = new HarbourTokenType("OTHERWISE");
    public static final IElementType ENDSWITCH = new HarbourTokenType("ENDSWITCH");
    public static final IElementType RETURN = new HarbourTokenType("RETURN");
    public static final IElementType EXIT = new HarbourTokenType("EXIT");
    public static final IElementType LOOP = new HarbourTokenType("LOOP");
    public static final IElementType AND = new HarbourTokenType("AND");
    public static final IElementType OR = new HarbourTokenType("OR");
    public static final IElementType NOT = new HarbourTokenType("NOT");
    public static final IElementType MEMVAR = new HarbourTokenType("MEMVAR");
    public static final IElementType PRIVATE = new HarbourTokenType("PRIVATE");
    public static final IElementType LPAREN = new HarbourTokenType("LPAREN");
    public static final IElementType RPAREN = new HarbourTokenType("RPAREN");
    public static final IElementType LBRACKET = new HarbourTokenType("LBRACKET");
    public static final IElementType RBRACKET = new HarbourTokenType("RBRACKET");
    public static final IElementType LBRACE = new HarbourTokenType("LBRACE");
    public static final IElementType RBRACE = new HarbourTokenType("RBRACE");
    public static final IElementType COMMA = new HarbourTokenType("COMMA");
    public static final IElementType COLON = new HarbourTokenType("COLON");
    public static final IElementType DOUBLE_COLON = new HarbourTokenType("DOUBLE_COLON");
    public static final IElementType PLUS = new HarbourTokenType("PLUS");
    public static final IElementType MINUS = new HarbourTokenType("MINUS");
    public static final IElementType MUL = new HarbourTokenType("MUL");
    public static final IElementType DIV = new HarbourTokenType("DIV");
    public static final IElementType EQ = new HarbourTokenType("EQ");
    public static final IElementType ASSIGN = new HarbourTokenType("ASSIGN");
    public static final IElementType EQEQ = new HarbourTokenType("EQEQ");
    public static final IElementType NEQ = new HarbourTokenType("NEQ");
    public static final IElementType GT = new HarbourTokenType("GT");
    public static final IElementType LT = new HarbourTokenType("LT");
    public static final IElementType GTEQ = new HarbourTokenType("GTEQ");
    public static final IElementType LTEQ = new HarbourTokenType("LTEQ");
    public static final IElementType EXCLAM = new HarbourTokenType("EXCLAM");
    public static final IElementType DOLLAR = new HarbourTokenType("DOLLAR");
    public static final IElementType DOT = new HarbourTokenType("DOT");
    public static final IElementType DOT_NOT = new HarbourTokenType("DOT_NOT");
    public static final IElementType DOT_OR = new HarbourTokenType("DOT_OR");
    public static final IElementType DOT_AND = new HarbourTokenType("DOT_AND");
    public static final IElementType EOL_COMMENT = new HarbourTokenType("EOL_COMMENT");
    public static final IElementType BLOCK_COMMENT = new HarbourTokenType("BLOCK_COMMENT");
    public static final IElementType LOGICAL = new HarbourTokenType("LOGICAL");
    public static final IElementType IDENT = new HarbourTokenType("IDENT");
    public static final IElementType NUMBER = new HarbourTokenType("NUMBER");
    public static final IElementType STRING_LITERAL = new HarbourTokenType("STRING_LITERAL");
    public static final IElementType AT = new HarbourTokenType("AT");
    public static final IElementType AMP = new HarbourTokenType("AMP");
    public static final IElementType NIL = new HarbourTokenType("NIL");
    public static final IElementType SELF = new HarbourTokenType("SELF");
    public static final IElementType SUPER = new HarbourTokenType("SUPER");
    public static final IElementType TROUBLE = new HarbourTokenType("TROUBLE");
    public static final IElementType TO = new HarbourTokenType("TO");
    public static final IElementType DATA = new HarbourTokenType("DATA");
    public static final IElementType INIT = new HarbourTokenType("INIT");
    public static final IElementType DEFAULT = new HarbourTokenType("DEFAULT");
    public static final IElementType RUN = new HarbourTokenType("RUN");
    public static final IElementType HIDDEN = new HarbourTokenType("HIDDEN");
    public static final IElementType SEMICOLON = new HarbourTokenType("SEMICOLON");
    public static final IElementType TOKENS = new HarbourTokenType("TOKENS");
}
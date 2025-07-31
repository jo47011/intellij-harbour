package org.intellij.sdk.language.psi;

import com.intellij.psi.tree.IElementType;

/**
 * Adapter class for the lexer that forwards all token requests to HarbourTypes.
 */
public class HarbourCustomTypes {
    // Forward all token requests to HarbourTypes
    public static final IElementType IDENT = HarbourTypes.IDENT;
    public static final IElementType NUMBER = HarbourTypes.NUMBER;
    public static final IElementType STRING_LITERAL = HarbourTypes.STRING_LITERAL;
    public static final IElementType EOL_COMMENT = HarbourTypes.EOL_COMMENT;
    public static final IElementType BLOCK_COMMENT = HarbourTypes.BLOCK_COMMENT;
    public static final IElementType PREPROC_DIRECTIVE = HarbourTypes.PREPROC_DIRECTIVE;

    // Punctuation
    public static final IElementType LPAREN = HarbourTypes.LPAREN;
    public static final IElementType RPAREN = HarbourTypes.RPAREN;
    public static final IElementType LBRACKET = HarbourTypes.LBRACKET;
    public static final IElementType RBRACKET = HarbourTypes.RBRACKET;
    public static final IElementType LBRACE = HarbourTypes.LBRACE;
    public static final IElementType RBRACE = HarbourTypes.RBRACE;
    public static final IElementType COMMA = HarbourTypes.COMMA;
    public static final IElementType COLON = HarbourTypes.COLON;
    public static final IElementType DOT = HarbourTypes.DOT;
    public static final IElementType SEMICOLON = HarbourTypes.SEMICOLON;

    // Operators
    public static final IElementType PLUS = HarbourTypes.PLUS;
    public static final IElementType MINUS = HarbourTypes.MINUS;
    public static final IElementType MUL = HarbourTypes.MUL;
    public static final IElementType DIV = HarbourTypes.DIV;
    public static final IElementType ASSIGN = HarbourTypes.ASSIGN;
    public static final IElementType EQ = HarbourTypes.EQ;
    public static final IElementType EQEQ = HarbourTypes.EQEQ;
    public static final IElementType NEQ = HarbourTypes.NEQ;
    public static final IElementType GT = HarbourTypes.GT;
    public static final IElementType LT = HarbourTypes.LT;
    public static final IElementType GTEQ = HarbourTypes.GTEQ;
    public static final IElementType LTEQ = HarbourTypes.LTEQ;
    public static final IElementType DOUBLE_COLON = HarbourTypes.DOUBLE_COLON;
    public static final IElementType EXCLAM = HarbourTypes.EXCLAM;
    public static final IElementType AT = HarbourTypes.AT;
    public static final IElementType AMP = HarbourTypes.AMP;
    public static final IElementType DOLLAR = HarbourTypes.DOLLAR;

    // Keywords
    public static final IElementType FUNCTION = HarbourTypes.FUNCTION;
    public static final IElementType PROCEDURE = HarbourTypes.PROCEDURE;
    public static final IElementType CLASS = HarbourTypes.CLASS;
    public static final IElementType METHOD = HarbourTypes.METHOD;
    public static final IElementType INHERIT = HarbourTypes.INHERIT;
    public static final IElementType ENDMETHOD = HarbourTypes.ENDMETHOD;
    public static final IElementType ENDCLASS = HarbourTypes.ENDCLASS;
    public static final IElementType ENDFUNCTION = HarbourTypes.ENDFUNCTION;
    public static final IElementType ENDPROCEDURE = HarbourTypes.ENDPROCEDURE;
    public static final IElementType LOCAL = HarbourTypes.LOCAL;
    public static final IElementType STATIC = HarbourTypes.STATIC;
    public static final IElementType IF = HarbourTypes.IF;
    public static final IElementType ELSE = HarbourTypes.ELSE;
    public static final IElementType ELSEIF = HarbourTypes.ELSEIF;
    public static final IElementType ENDIF = HarbourTypes.ENDIF;
    public static final IElementType DO = HarbourTypes.DO;
    public static final IElementType WHILE = HarbourTypes.WHILE;
    public static final IElementType ENDDO = HarbourTypes.ENDDO;
    public static final IElementType FOR = HarbourTypes.FOR;
    public static final IElementType TO = HarbourTypes.TO;
    public static final IElementType NEXT = HarbourTypes.NEXT;
    public static final IElementType SWITCH = HarbourTypes.SWITCH;
    public static final IElementType CASE = HarbourTypes.CASE;
    public static final IElementType OTHERWISE = HarbourTypes.OTHERWISE;
    public static final IElementType ENDSWITCH = HarbourTypes.ENDSWITCH;
    public static final IElementType RETURN = HarbourTypes.RETURN;
    public static final IElementType EXIT = HarbourTypes.EXIT;
    public static final IElementType LOOP = HarbourTypes.LOOP;
    public static final IElementType BEGIN = HarbourTypes.BEGIN;
    public static final IElementType SEQUENCE = HarbourTypes.SEQUENCE;
    public static final IElementType RECOVER = HarbourTypes.RECOVER;
    public static final IElementType USING = HarbourTypes.USING;
    public static final IElementType END = HarbourTypes.END;

    // Logical operators
    public static final IElementType AND = HarbourTypes.AND;
    public static final IElementType OR = HarbourTypes.OR;
    public static final IElementType NOT = HarbourTypes.NOT;
    public static final IElementType DOT_AND = HarbourTypes.DOT_AND;
    public static final IElementType DOT_OR = HarbourTypes.DOT_OR;
    public static final IElementType DOT_NOT = HarbourTypes.DOT_NOT;

    // Special values
    public static final IElementType LOGICAL = HarbourTypes.LOGICAL;
    public static final IElementType NIL = HarbourTypes.NIL;
    public static final IElementType SELF = HarbourTypes.SELF;
    public static final IElementType SUPER = HarbourTypes.SUPER;

    // Additional keywords
    public static final IElementType MEMVAR = HarbourTypes.MEMVAR;
    public static final IElementType PRIVATE = HarbourTypes.PRIVATE;
    public static final IElementType TROUBLE = HarbourTypes.TROUBLE;
    public static final IElementType DATA = HarbourTypes.DATA;
    public static final IElementType INIT = HarbourTypes.INIT;
    public static final IElementType DEFAULT = HarbourTypes.DEFAULT;
    public static final IElementType RUN = HarbourTypes.RUN;
    public static final IElementType HIDDEN = HarbourTypes.HIDDEN;
}
/* ------------------------------------------------------------------------------------
   harbour.flex
   Final version: fully case-insensitive, .t./.f./.not. recognized, "hidden" recognized, etc.
------------------------------------------------------------------------------------ */
package org.intellij.sdk.language;

import com.intellij.psi.TokenType;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.HarbourCustomTypes;
// Import both token type classes
// import org.intellij.sdk.language.psi.HarbourTypes;

/**
 * Harbour flex spec
 */

%%
%class _HarbourLexer
%implements com.intellij.lexer.FlexLexer
%unicode
%type IElementType
%function advance

// Case-insensitive:
%caseless

// Lexical states
%state IN_BLOCK_COMMENT
%state IN_LINE_COMMENT
%state IN_PREPROC
%state IN_DQUOTE_STRING
%state IN_SQUOTE_STRING

// Character classes
ALPHA       = [a-zA-Z_]
ALNUM       = [a-zA-Z0-9_]
WS          = [ \t\f]
EOL         = \r|\n|\r\n
SPECIAL_CHARS = [ÄÖÜäöüß]

%%

<YYINITIAL> {
    // Comment handling
    "//"                    { yybegin(IN_LINE_COMMENT); return HarbourCustomTypes.EOL_COMMENT; }
    "/*"                    { yybegin(IN_BLOCK_COMMENT); return HarbourCustomTypes.BLOCK_COMMENT; }

    // Preprocessor directive
    "#"                     { yybegin(IN_PREPROC); return HarbourCustomTypes.PREPROC_DIRECTIVE; }

    // Multi-character operators - must be before single-character ones
    ":="                    { return HarbourCustomTypes.ASSIGN; }
    "=="                    { return HarbourCustomTypes.EQEQ; }
    "!="                    { return HarbourCustomTypes.NEQ; }
    "<>"                    { return HarbourCustomTypes.NEQ; }
    ">="                    { return HarbourCustomTypes.GTEQ; }
    "<="                    { return HarbourCustomTypes.LTEQ; }
    "::"                    { return HarbourCustomTypes.DOUBLE_COLON; }

    // Line continuation handling
    "+;"{WS}*{EOL}          { return TokenType.WHITE_SPACE; }
    ";"{WS}*{EOL}           { return TokenType.WHITE_SPACE; }

    // Harbour keywords
    "function"              { return HarbourCustomTypes.FUNCTION; }
    "procedure"             { return HarbourCustomTypes.PROCEDURE; }
    "class"                 { return HarbourCustomTypes.CLASS; }
    "method"                { return HarbourCustomTypes.METHOD; }
    "inherit"               { return HarbourCustomTypes.INHERIT; }
    "endmethod"             { return HarbourCustomTypes.ENDMETHOD; }
    "endclass"              { return HarbourCustomTypes.ENDCLASS; }
    "endfunction"           { return HarbourCustomTypes.ENDFUNCTION; }
    "endprocedure"          { return HarbourCustomTypes.ENDPROCEDURE; }
    "local"                 { return HarbourCustomTypes.LOCAL; }
    "static"                { return HarbourCustomTypes.STATIC; }
    "if"                    { return HarbourCustomTypes.IF; }
    "else"                  { return HarbourCustomTypes.ELSE; }
    "elseif"                { return HarbourCustomTypes.ELSEIF; }
    "endif"                 { return HarbourCustomTypes.ENDIF; }
    "do"                    { return HarbourCustomTypes.DO; }
    "while"                 { return HarbourCustomTypes.WHILE; }
    "enddo"                 { return HarbourCustomTypes.ENDDO; }
    "for"                   { return HarbourCustomTypes.FOR; }
    "each"                  { return HarbourCustomTypes.IDENT; } // Treat as identifier for now
    "next"                  { return HarbourCustomTypes.NEXT; }
    "switch"                { return HarbourCustomTypes.SWITCH; }
    "case"                  { return HarbourCustomTypes.CASE; }
    "otherwise"             { return HarbourCustomTypes.OTHERWISE; }
    "endswitch"             { return HarbourCustomTypes.ENDSWITCH; }
    "endcase"               { return HarbourCustomTypes.ENDCASE; }
    "return"                { return HarbourCustomTypes.RETURN; }
    "exit"                  { return HarbourCustomTypes.EXIT; }
    "loop"                  { return HarbourCustomTypes.LOOP; }
    "begin"                 { return HarbourCustomTypes.BEGIN; }
    "sequence"              { return HarbourCustomTypes.SEQUENCE; }
    "recover"               { return HarbourCustomTypes.RECOVER; }
    "using"                 { return HarbourCustomTypes.USING; }
    "end"                   { return HarbourCustomTypes.END; }
    "and"                   { return HarbourCustomTypes.AND; }
    "or"                    { return HarbourCustomTypes.OR; }
    "not"                   { return HarbourCustomTypes.NOT; }
    "memvar"                { return HarbourCustomTypes.MEMVAR; }
    "private"               { return HarbourCustomTypes.PRIVATE; }
    "logical"               { return HarbourCustomTypes.LOGICAL; }
    "nil"                   { return HarbourCustomTypes.NIL; }
    "self"                  { return HarbourCustomTypes.SELF; }
    "super"                 { return HarbourCustomTypes.SUPER; }
    "trouble"               { return HarbourCustomTypes.TROUBLE; }
    "to"                    { return HarbourCustomTypes.TO; }

    // Additional keywords for data/default/run/hidden
    "data"                  { return HarbourCustomTypes.DATA; }
    "init"                  { return HarbourCustomTypes.INIT; }
    "default"               { return HarbourCustomTypes.DEFAULT; }
    "run"                   { return HarbourCustomTypes.RUN; }
    "hidden"                { return HarbourCustomTypes.HIDDEN; }

    // .t., .f., .not., .and., .or. (case-insensitive)
    ".t."                   { return HarbourCustomTypes.LOGICAL; }
    ".f."                   { return HarbourCustomTypes.LOGICAL; }
    ".not."                 { return HarbourCustomTypes.DOT_NOT; }
    ".and."                 { return HarbourCustomTypes.DOT_AND; }
    ".or."                  { return HarbourCustomTypes.DOT_OR; }

    // Non-English special characters in identifiers or comments/strings
    "@" ({ALPHA}|{SPECIAL_CHARS}|"@")({ALNUM}|{SPECIAL_CHARS}|"@")*  { return HarbourCustomTypes.IDENT; }

    // Operators and punctuation (AFTER multi-char operators)
    "("                     { return HarbourCustomTypes.LPAREN; }
    ")"                     { return HarbourCustomTypes.RPAREN; }
    "["                     { return HarbourCustomTypes.LBRACKET; }
    "]"                     { return HarbourCustomTypes.RBRACKET; }
    "{"                     { return HarbourCustomTypes.LBRACE; }
    "}"                     { return HarbourCustomTypes.RBRACE; }
    ","                     { return HarbourCustomTypes.COMMA; }
    ":"                     { return HarbourCustomTypes.COLON; }
    "+"                     { return HarbourCustomTypes.PLUS; }
    "-"                     { return HarbourCustomTypes.MINUS; }
    "*"                     { return HarbourCustomTypes.MUL; }
    "/"                     { return HarbourCustomTypes.DIV; }
    "="                     { return HarbourCustomTypes.EQ; }
    ">"                     { return HarbourCustomTypes.GT; }
    "<"                     { return HarbourCustomTypes.LT; }
    "!"                     { return HarbourCustomTypes.EXCLAM; }
    "$"                     { return HarbourCustomTypes.DOLLAR; }
    "."                     { return HarbourCustomTypes.DOT; }
    "@"                     { return HarbourCustomTypes.AT; }
    "&"                     { return HarbourCustomTypes.AMP; }
    ";"                     { return HarbourCustomTypes.SEMICOLON; }

    // String literals - double quote
    \"                      { yybegin(IN_DQUOTE_STRING); return HarbourCustomTypes.STRING_LITERAL; }

    // String literals - single quote
    \'                      { yybegin(IN_SQUOTE_STRING); return HarbourCustomTypes.STRING_LITERAL; }

    // Numbers
    [0-9]+(\.[0-9]+)?       { return HarbourCustomTypes.NUMBER; }

    // Identifiers - must handle international characters
    ({ALPHA}|{SPECIAL_CHARS})({ALNUM}|{SPECIAL_CHARS})*  { return HarbourCustomTypes.IDENT; }

    // Whitespace
    {WS}+                   { return TokenType.WHITE_SPACE; }
    {EOL}                   { return TokenType.WHITE_SPACE; }

    // Any other character
    .                       { return TokenType.BAD_CHARACTER; }
}

<IN_DQUOTE_STRING> {
    \"                      { yybegin(YYINITIAL); return HarbourCustomTypes.STRING_LITERAL; }
    {EOL}                   { yybegin(YYINITIAL); return HarbourCustomTypes.STRING_LITERAL; }
    [^\"\r\n]+              { return HarbourCustomTypes.STRING_LITERAL; }
    // Fallback to handle any other character in string
    .                       { return HarbourCustomTypes.STRING_LITERAL; }
}

<IN_SQUOTE_STRING> {
    \'                      { yybegin(YYINITIAL); return HarbourCustomTypes.STRING_LITERAL; }
    {EOL}                   { yybegin(YYINITIAL); return HarbourCustomTypes.STRING_LITERAL; }
    [^\'\r\n]+              { return HarbourCustomTypes.STRING_LITERAL; }
    // Fallback to handle any other character in string
    .                       { return HarbourCustomTypes.STRING_LITERAL; }
}

<IN_LINE_COMMENT> {
    {EOL}                   { yybegin(YYINITIAL); return TokenType.WHITE_SPACE; }
    [^\r\n]+                { return HarbourCustomTypes.EOL_COMMENT; }
}

<IN_BLOCK_COMMENT> {
    "*/"                    { yybegin(YYINITIAL); return HarbourCustomTypes.BLOCK_COMMENT; }
    {EOL}                   { return HarbourCustomTypes.BLOCK_COMMENT; }
    [^*\r\n]+               { return HarbourCustomTypes.BLOCK_COMMENT; }
    "*"                     { return HarbourCustomTypes.BLOCK_COMMENT; }
    // Fallback to handle any other character in block comment
    .                       { return HarbourCustomTypes.BLOCK_COMMENT; }
    <<EOF>>                 { yybegin(YYINITIAL); return HarbourCustomTypes.BLOCK_COMMENT; }
}

<IN_PREPROC> {
    {EOL}                   { yybegin(YYINITIAL); return TokenType.WHITE_SPACE; }
    \"([^\"\r\n\\]|\\.)*\"  { return HarbourCustomTypes.STRING_LITERAL; }
    [^ \t\r\n\"]+           { return HarbourCustomTypes.PREPROC_DIRECTIVE; }
    {WS}+                   { return TokenType.WHITE_SPACE; }
    // Fallback to handle any other character in preprocessor directive
    .                       { return HarbourCustomTypes.PREPROC_DIRECTIVE; }
}
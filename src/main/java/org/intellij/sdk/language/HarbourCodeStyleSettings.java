package org.intellij.sdk.language;

import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.psi.codeStyle.CustomCodeStyleSettings;

/**
 * Custom code style settings for Harbour language
 */
public class HarbourCodeStyleSettings extends CustomCodeStyleSettings {
    
    // Statement indentation settings (number of spaces)
    public int LOCAL_INDENT = 0;    // Default: LOCAL at column 0
    public int RETURN_INDENT = 0;   // Default: RETURN at column 0
    public int DATA_INDENT = 0;     // Default: DATA at column 0
    public int METHOD_INDENT = 0;   // Default: METHOD at column 0
    public int MEMVAR_INDENT = 0;   // Default: MEMVAR at column 0
    public int PRIVATE_INDENT = 0;  // Default: PRIVATE at column 0
    public boolean SEQUENCE_LIKE_NORMAL_CODE = true; // Default: BEGIN SEQUENCE indented like normal code

    // Spacing settings — commas
    public boolean SPACE_AFTER_COMMA = true;       // a,b => a, b
    public boolean SPACE_BEFORE_COMMA = false;      // a , b => a, b

    // Spacing settings — operators
    public boolean SPACE_AROUND_ADDITIVE_OPERATORS = true;       // a+b => a + b  (+ -)
    public boolean SPACE_AROUND_MULTIPLICATIVE_OPERATORS = true;  // a*b => a * b  (* / %)
    public boolean SPACE_AROUND_COMPARISON_OPERATORS = true;      // a==b => a == b  (== != < > <= >=)
    public boolean SPACE_AROUND_ASSIGNMENT_OPERATOR = false;      // := always no spaces (Harbour convention)
    public boolean SPACE_AROUND_LOGICAL_OPERATORS = true;         // .and. .or. .not. with spaces

    protected HarbourCodeStyleSettings(CodeStyleSettings container) {
        super("HarbourCodeStyleSettings", container);
    }
}
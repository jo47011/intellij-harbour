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
    public boolean SEQUENCE_LIKE_NORMAL_CODE = true; // Default: BEGIN SEQUENCE indented like normal code (if/endif style)
    
    protected HarbourCodeStyleSettings(CodeStyleSettings container) {
        super("HarbourCodeStyleSettings", container);
    }
}
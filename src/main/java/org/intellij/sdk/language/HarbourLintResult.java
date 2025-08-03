package org.intellij.sdk.language;

import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.util.TextRange;

/**
 * Represents a single linting result from the Harbour compiler.
 */
public class HarbourLintResult {
    private final int line;
    private final int column;
    private final String message;
    private final HighlightSeverity severity;
    private final String errorCode;
    private TextRange textRange;

    public HarbourLintResult(int line, int column, String message, 
                           HighlightSeverity severity, String errorCode) {
        this.line = line;
        this.column = column;
        this.message = message;
        this.severity = severity;
        this.errorCode = errorCode;
    }

    public int getLine() {
        return line;
    }

    public int getColumn() {
        return column;
    }

    public String getMessage() {
        return message;
    }

    public HighlightSeverity getSeverity() {
        return severity;
    }

    public String getErrorCode() {
        return errorCode;
    }

    public TextRange getTextRange() {
        return textRange;
    }

    public void setTextRange(TextRange textRange) {
        this.textRange = textRange;
    }
}
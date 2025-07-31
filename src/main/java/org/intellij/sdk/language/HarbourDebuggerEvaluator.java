package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.util.TextRange;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.evaluation.XDebuggerEvaluator;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Harbour debugger expression evaluator.
 * Handles ALT-F8 expression evaluation and hover evaluation during debugging.
 */
public class HarbourDebuggerEvaluator extends XDebuggerEvaluator {
    private final HarbourDebuggerBaseProcess debugProcess;

    public HarbourDebuggerEvaluator(HarbourDebuggerBaseProcess debugProcess) {
        this.debugProcess = debugProcess;
    }

    @Override
    public void evaluate(@NotNull String expression, @NotNull XEvaluationCallback callback, @Nullable XSourcePosition expressionPosition) {
        HarbourLogger.log("HarbourDebuggerEvaluator", "Evaluating expression: " + expression);

        // Execute evaluation on background thread
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                // Check if expression is a simple variable name first
                String result = evaluateVariable(expression);
                if (result != null) {
                    // Found as variable, return its value
                    ApplicationManager.getApplication().invokeLater(() -> {
                        HarbourDebuggerValue value = new HarbourDebuggerValue(expression, "Unknown", result);
                        callback.evaluated(value);
                    });
                    return;
                }

                // If not a simple variable, send evaluation command to debugger
                String evaluationResult = evaluateExpression(expression);
                
                ApplicationManager.getApplication().invokeLater(() -> {
                    if (evaluationResult != null) {
                        // Create a value object with the result
                        HarbourDebuggerValue value = new HarbourDebuggerValue(expression, "Expression", evaluationResult);
                        callback.evaluated(value);
                    } else {
                        callback.errorOccurred("Cannot evaluate expression: " + expression);
                    }
                });
            } catch (Exception e) {
                HarbourLogger.logStackTrace("HarbourDebuggerEvaluator", e);
                HarbourLogger.log("HarbourDebuggerEvaluator", "Error evaluating expression: " + expression + " - " + e.getMessage());
                ApplicationManager.getApplication().invokeLater(() -> {
                    callback.errorOccurred("Error evaluating expression: " + e.getMessage());
                });
            }
        });
    }

    /**
     * Check if expression is a simple variable and return its current value
     */
    private String evaluateVariable(String expression) {
        // Clean the expression (remove spaces, etc.)
        String cleanExpression = expression.trim();
        
        // Get current variables from debug process
        var variables = debugProcess.getVariables();
        
        // Look for exact variable match
        for (var entry : variables.entrySet()) {
            HarbourDebuggerValue value = entry.getValue();
            if (cleanExpression.equals(value.getName())) {
                HarbourLogger.log("HarbourDebuggerEvaluator", 
                    "Found variable: " + cleanExpression + " = " + value.getValue());
                return value.getValue();
            }
        }
        
        // Look for case-insensitive match (Harbour is case-insensitive)
        for (var entry : variables.entrySet()) {
            HarbourDebuggerValue value = entry.getValue();
            if (cleanExpression.equalsIgnoreCase(value.getName())) {
                HarbourLogger.log("HarbourDebuggerEvaluator", 
                    "Found variable (case-insensitive): " + cleanExpression + " = " + value.getValue());
                return value.getValue();
            }
        }
        
        return null; // Not found as simple variable
    }

    /**
     * Evaluate complex expressions by sending command to debugger
     */
    private String evaluateExpression(String expression) {
        try {
            // Send evaluation command to the debug process
            // Note: This depends on the debugging protocol implementation
            // For now, we'll try to handle basic expressions
            
            HarbourLogger.log("HarbourDebuggerEvaluator", 
                "Attempting to evaluate complex expression: " + expression);
            
            // Send EVAL command to debugger if supported
            debugProcess.sendCommand("EVAL", expression);
            
            // For now, return a placeholder - this would need proper protocol implementation
            return "Expression evaluation not yet implemented for: " + expression;
            
        } catch (Exception e) {
            HarbourLogger.logStackTrace("HarbourDebuggerEvaluator", e);
            HarbourLogger.log("HarbourDebuggerEvaluator", "Failed to evaluate expression: " + expression + " - " + e.getMessage());
            return null;
        }
    }

    @Nullable
    @Override
    public TextRange getExpressionRangeAtOffset(@NotNull com.intellij.openapi.project.Project project, 
                                                @NotNull com.intellij.openapi.editor.Document document, 
                                                int offset, 
                                                boolean sideEffectsAllowed) {
        // Get the word at the cursor position for hover evaluation
        CharSequence text = document.getCharsSequence();
        if (offset >= text.length()) {
            return null;
        }

        // Find word boundaries (letters, numbers, underscore for Harbour variables)
        int start = offset;
        int end = offset;

        // Move start backwards to find beginning of word
        while (start > 0) {
            char ch = text.charAt(start - 1);
            if (Character.isLetterOrDigit(ch) || ch == '_') {
                start--;
            } else {
                break;
            }
        }

        // Move end forwards to find end of word
        while (end < text.length()) {
            char ch = text.charAt(end);
            if (Character.isLetterOrDigit(ch) || ch == '_') {
                end++;
            } else {
                break;
            }
        }

        if (start == end) {
            return null; // No word found
        }

        String word = text.subSequence(start, end).toString();
        HarbourLogger.log("HarbourDebuggerEvaluator", "Found expression for hover: " + word);

        return new TextRange(start, end);
    }
}
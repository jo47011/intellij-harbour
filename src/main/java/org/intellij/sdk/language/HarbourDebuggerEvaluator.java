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
    public void evaluate(@NotNull String expression, @NotNull XEvaluationCallback callback,
                         @Nullable XSourcePosition expressionPosition) {
        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Evaluating expression: " + expression);

        // Execute evaluation on background thread
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                // Check if expression matches a variable or object:property
                HarbourDebuggerValue found = findVariable(expression);
                if (found != null) {
                    ApplicationManager.getApplication().invokeLater(() -> {
                        HarbourDebuggerValue result = new HarbourDebuggerValue(
                            expression, found.getType(), found.getValue());
                        callback.evaluated(result);
                    });
                    return;
                }

                // If not found locally, send evaluation command to debugger
                String evaluationResult = evaluateExpression(expression);

                ApplicationManager.getApplication().invokeLater(() -> {
                    if (evaluationResult != null) {
                        HarbourDebuggerValue value = new HarbourDebuggerValue(
                            expression, "Expression", evaluationResult);
                        callback.evaluated(value);
                    } else {
                        callback.errorOccurred(
                            "Cannot evaluate expression: " + expression);
                    }
                });
            } catch (Exception e) {
                HarbourLogger.logStackTrace("HarbourDebuggerEvaluator", e);
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Error evaluating expression: " + expression +
                    " - " + e.getMessage());
                ApplicationManager.getApplication().invokeLater(() -> {
                    callback.errorOccurred(
                        "Error evaluating expression: " + e.getMessage());
                });
            }
        });
    }

    /**
     * Find a variable or object property by expression.
     * Supports simple variables (e.g. "bew"), object:property notation
     * (e.g. "bew:LGNACH" or nested "obj:prop:subprop"), and array element
     * access (e.g. "Logins[1]" or "arr[2][3]").
     * Harbour is case-insensitive so all lookups are case-insensitive.
     */
    private HarbourDebuggerValue findVariable(String expression) {
        String cleanExpression = expression.trim();
        var variables = debugProcess.getVariables();

        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Looking for '" + cleanExpression + "' in " +
            variables.size() + " variables");

        // Check for array element access (e.g. "Logins[1]", "arr[2][3]")
        if (cleanExpression.contains("[")) {
            return findArrayElement(cleanExpression, variables);
        }

        // Check for object:property notation
        if (cleanExpression.contains(":")) {
            return findObjectProperty(cleanExpression, variables);
        }

        // Simple variable lookup (case-insensitive)
        for (var entry : variables.entrySet()) {
            HarbourDebuggerValue value = entry.getValue();
            if (cleanExpression.equalsIgnoreCase(value.getName())) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Found variable: " + cleanExpression + " = " +
                    value.getValue() + " (" + value.getType() + ")");
                return value;
            }
        }

        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Variable '" + cleanExpression +
            "' not found. Available: " + variables.keySet());
        return null;
    }

    /**
     * Resolve array element access expressions like "Logins[1]" or "arr[2][3]".
     * Finds the base array variable, ensures children are loaded, then returns
     * the element at the specified index (1-based, as Harbour uses).
     */
    private HarbourDebuggerValue findArrayElement(String expression,
            java.util.Map<String, HarbourDebuggerValue> variables) {
        // Parse base variable name and indices from e.g. "Logins[1]" or "arr[2][3]"
        int firstBracket = expression.indexOf('[');
        if (firstBracket <= 0) {
            return null;
        }

        String baseName = expression.substring(0, firstBracket).trim();

        // Extract all indices from bracket expressions
        java.util.List<Integer> indices = new java.util.ArrayList<>();
        String remaining = expression.substring(firstBracket);
        while (remaining.startsWith("[")) {
            int closeBracket = remaining.indexOf(']');
            if (closeBracket < 0) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Malformed array expression: " + expression);
                return null;
            }
            String indexStr = remaining.substring(1, closeBracket).trim();
            try {
                indices.add(Integer.parseInt(indexStr));
            } catch (NumberFormatException e) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Non-numeric array index in: " + expression);
                return null;
            }
            remaining = remaining.substring(closeBracket + 1);
        }

        if (indices.isEmpty()) {
            return null;
        }

        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Array access: base=" + baseName + ", indices=" + indices);

        // Find the base variable (case-insensitive)
        HarbourDebuggerValue baseVar = null;
        for (var entry : variables.entrySet()) {
            if (baseName.equalsIgnoreCase(entry.getValue().getName())) {
                baseVar = entry.getValue();
                break;
            }
        }

        if (baseVar == null) {
            HarbourLogger.log("HarbourDebuggerEvaluator",
                "Base array variable '" + baseName + "' not found");
            return null;
        }

        // Navigate through indices
        HarbourDebuggerValue current = baseVar;
        for (int i = 0; i < indices.size(); i++) {
            int index = indices.get(i);

            if (!"A".equals(current.getType())) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Variable '" + current.getName() +
                    "' is not an array (type=" + current.getType() + ")");
                return null;
            }

            // If children not loaded, request them synchronously
            java.util.List<HarbourDebuggerValue> children = current.getChildren();
            if (children == null || children.isEmpty()) {
                if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                    HarbourDebuggerRemoteProcess remoteProcess =
                        (HarbourDebuggerRemoteProcess) debugProcess;
                    children = remoteProcess.requestArrayElementsSync(current);
                }
            }

            if (children == null || children.isEmpty()) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Could not load children for array '" +
                    current.getName() + "'");
                return null;
            }

            // Harbour arrays are 1-based, children list is 0-based
            if (index < 1 || index > children.size()) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Array index " + index + " out of bounds (1.." +
                    children.size() + ")");
                return null;
            }

            current = children.get(index - 1);
        }

        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Resolved " + expression + " = " + current.getValue() +
            " (" + current.getType() + ")");
        return current;
    }

    /**
     * Resolve object:property expressions by walking the children tree.
     * E.g. "bew:LGNACH" -> find variable BEW, then child LGNACH.
     */
    private HarbourDebuggerValue findObjectProperty(String expression,
            java.util.Map<String, HarbourDebuggerValue> variables) {
        String[] parts = expression.split(":");
        if (parts.length < 2) {
            return null;
        }

        // Find the base object variable (case-insensitive)
        String baseName = parts[0].trim();
        HarbourDebuggerValue current = null;
        for (var entry : variables.entrySet()) {
            if (baseName.equalsIgnoreCase(entry.getValue().getName())) {
                current = entry.getValue();
                break;
            }
        }

        if (current == null) {
            HarbourLogger.log("HarbourDebuggerEvaluator",
                "Base object '" + baseName + "' not found");
            return null;
        }

        // Walk the property chain through children
        for (int i = 1; i < parts.length; i++) {
            String propName = parts[i].trim();
            java.util.List<HarbourDebuggerValue> children =
                current.getChildren();

            if (children == null || children.isEmpty()) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Object '" + current.getName() +
                    "' has no loaded children, cannot resolve '" +
                    propName + "'");
                return null;
            }

            HarbourDebuggerValue found = null;
            for (HarbourDebuggerValue child : children) {
                if (propName.equalsIgnoreCase(child.getName())) {
                    found = child;
                    break;
                }
            }

            if (found == null) {
                HarbourLogger.log("HarbourDebuggerEvaluator",
                    "Property '" + propName + "' not found in '" +
                    current.getName() + "'");
                return null;
            }
            current = found;
        }

        HarbourLogger.log("HarbourDebuggerEvaluator",
            "Resolved " + expression + " = " + current.getValue() +
            " (" + current.getType() + ")");
        return current;
    }

    /**
     * Evaluate complex expressions by sending command to debugger
     */
    private String evaluateExpression(String expression) {
        try {
            // Send evaluation command to the debug process
            HarbourLogger.log("HarbourDebuggerEvaluator", 
                "Attempting to evaluate complex expression: " + expression);
            
            // Replace colons with semicolons to avoid protocol conflicts
            String safeExpression = expression.replace(":", ";");
            
            // Get current stack level (default to 1 if not available)
            int stackLevel = 1;
            
            // Send EVAL command to debugger: EVAL:stack_level:expression
            String command = String.format("%d:%s", stackLevel, safeExpression);
            
            if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                // Request evaluation and wait for response
                String result = remoteProcess.requestExpression(command);
                if (result != null) {
                    return result;
                }
            } else {
                debugProcess.sendCommand("EVAL", command);
            }
            
            // Temporary fallback
            return "Waiting for evaluation result...";
            
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

        // Find word boundaries including ':' for object:property and
        // '[', ']' for array element access
        int start = offset;
        int end = offset;

        // Move start backwards to find beginning of word
        while (start > 0) {
            char ch = text.charAt(start - 1);
            if (Character.isLetterOrDigit(ch) || ch == '_' || ch == ':'
                    || ch == '[' || ch == ']') {
                start--;
            } else {
                break;
            }
        }

        // Move end forwards to find end of word
        while (end < text.length()) {
            char ch = text.charAt(end);
            if (Character.isLetterOrDigit(ch) || ch == '_' || ch == ':'
                    || ch == '[' || ch == ']') {
                end++;
            } else {
                break;
            }
        }

        // Trim trailing colons (e.g. "bew:" without property)
        while (end > start && text.charAt(end - 1) == ':') {
            end--;
        }
        // Trim leading colons
        while (start < end && text.charAt(start) == ':') {
            start++;
        }

        if (start == end) {
            return null; // No word found
        }

        String word = text.subSequence(start, end).toString();
        HarbourLogger.log("HarbourDebuggerEvaluator", "Found expression for hover: " + word);

        return new TextRange(start, end);
    }
}
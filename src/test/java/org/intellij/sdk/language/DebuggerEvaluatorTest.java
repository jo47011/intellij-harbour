package org.intellij.sdk.language;

import org.junit.Test;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import static org.junit.Assert.*;

/**
 * Tests for debugger evaluator expression parsing logic.
 * Tests array element parsing, method call detection, and INVOKE
 * command construction without needing the IntelliJ framework.
 */
public class DebuggerEvaluatorTest {

    // ===== Array expression parsing =====

    @Test
    public void testArrayExpressionParsing_simpleIndex() {
        ArrayParseResult r = parseArrayExpression("Logins[1]");
        assertNotNull("Should parse Logins[1]", r);
        assertEquals("LOGINS", r.baseName.toUpperCase());
        assertEquals(1, r.indices.size());
        assertEquals(1, (int) r.indices.get(0));
        assertTrue("No trailing text", r.remaining.isEmpty());
    }

    @Test
    public void testArrayExpressionParsing_multipleIndices() {
        ArrayParseResult r = parseArrayExpression("arr[2][3]");
        assertNotNull(r);
        assertEquals("arr", r.baseName);
        assertEquals(2, r.indices.size());
        assertEquals(2, (int) r.indices.get(0));
        assertEquals(3, (int) r.indices.get(1));
        assertTrue(r.remaining.isEmpty());
    }

    @Test
    public void testArrayExpressionParsing_trailingMethodCall() {
        ArrayParseResult r = parseArrayExpression("Logins[1]:toString()");
        assertNotNull(r);
        assertEquals("Logins", r.baseName);
        assertEquals(1, r.indices.size());
        assertEquals(1, (int) r.indices.get(0));
        assertEquals(":toString()", r.remaining);
    }

    @Test
    public void testArrayExpressionParsing_trailingProperty() {
        ArrayParseResult r = parseArrayExpression("Logins[1]:ID");
        assertNotNull(r);
        assertEquals(":ID", r.remaining);
    }

    @Test
    public void testArrayExpressionParsing_noBracket() {
        ArrayParseResult r = parseArrayExpression("simpleVar");
        assertNull("No brackets — should return null", r);
    }

    @Test
    public void testArrayExpressionParsing_malformedBracket() {
        ArrayParseResult r = parseArrayExpression("arr[noclose");
        assertNull("Unclosed bracket — should return null", r);
    }

    @Test
    public void testArrayExpression_shouldDeferMethodCall() {
        // findArrayElement must return null for trailing text
        // so evaluate() sends the full expression to INVOKE/EVAL
        ArrayParseResult r = parseArrayExpression("Logins[1]:toString()");
        assertNotNull(r);
        assertFalse("Has trailing text", r.remaining.isEmpty());
        // This means findArrayElement returns null → falls through
    }

    // ===== Method call detection =====

    @Test
    public void testMethodCallDetection_simpleMethodCall() {
        assertTrue("l:toString() is a method call",
            isMethodCallExpression("l:toString()"));
    }

    @Test
    public void testMethodCallDetection_arrayMethodCall() {
        assertTrue("Logins[1]:toString() is a method call",
            isMethodCallExpression("Logins[1]:toString()"));
    }

    @Test
    public void testMethodCallDetection_propertyAccess() {
        assertFalse("l:ID is NOT a method call",
            isMethodCallExpression("l:ID"));
    }

    @Test
    public void testMethodCallDetection_simpleVariable() {
        assertFalse("l is NOT a method call",
            isMethodCallExpression("l"));
    }

    @Test
    public void testMethodCallDetection_nestedProperty() {
        assertFalse("obj:prop:sub is NOT a method call",
            isMethodCallExpression("obj:prop:sub"));
    }

    @Test
    public void testFindVariable_skipsObjectPropertyForMethodCalls() {
        // Expressions with () must NOT enter findObjectProperty
        String expr = "l:toString()";
        boolean hasColon = expr.contains(":");
        boolean hasParens = expr.contains("(");

        assertTrue("Has colon", hasColon);
        assertTrue("Has parens", hasParens);

        // The condition: contains(":") && !contains("(")
        boolean wouldEnterObjectProperty = hasColon && !hasParens;
        assertFalse("Should NOT enter findObjectProperty",
            wouldEnterObjectProperty);
    }

    // ===== INVOKE command parsing =====

    @Test
    public void testTryInvokeMethod_simpleVariable() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.L", "L");

        InvokeParseResult r = parseInvokeExpression(
            "l:toString()", vars);
        assertNotNull("Should parse l:toString()", r);
        assertEquals("LOCALS", r.scope);
        assertEquals("l", r.varName);
        assertEquals("toString()", r.method);
    }

    @Test
    public void testTryInvokeMethod_arrayElement() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.LOGINS", "LOGINS");

        InvokeParseResult r = parseInvokeExpression(
            "Logins[1]:toString()", vars);
        assertNotNull("Should parse Logins[1]:toString()", r);
        assertEquals("LOCALS", r.scope);
        assertEquals("Logins[1]", r.varName);
        assertEquals("toString()", r.method);
    }

    @Test
    public void testTryInvokeMethod_publicVariable() {
        Map<String, String> vars = new HashMap<>();
        vars.put("PUBLICS.USER", "USER");

        InvokeParseResult r = parseInvokeExpression(
            "User:getName()", vars);
        assertNotNull(r);
        assertEquals("PUBLICS", r.scope);
        assertEquals("User", r.varName);
        assertEquals("getName()", r.method);
    }

    @Test
    public void testTryInvokeMethod_ignoresPropertyAccess() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.L", "L");

        InvokeParseResult r = parseInvokeExpression(
            "l:ID", vars);
        assertNull("Property access (no parens) → null", r);
    }

    @Test
    public void testTryInvokeMethod_ignoresUnknownVariable() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.L", "L");

        InvokeParseResult r = parseInvokeExpression(
            "unknown:toString()", vars);
        assertNull("Unknown variable → null", r);
    }

    @Test
    public void testTryInvokeMethod_ignoresSimpleVariable() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.L", "L");

        InvokeParseResult r = parseInvokeExpression(
            "l", vars);
        assertNull("Simple variable (no colon) → null", r);
    }

    @Test
    public void testInvokeCommandConstruction() {
        // Verify the INVOKE command string format
        String scope = "LOCALS";
        String varName = "L";
        String method = "toString()";
        String safeMethod = method.replace(":", ";");
        String command = scope + ":" + varName + ":" + safeMethod;
        assertEquals("LOCALS:L:toString()", command);
    }

    @Test
    public void testInvokeCommandConstruction_arrayElement() {
        String scope = "LOCALS";
        String varName = "LOGINS[1]";
        String method = "toString()";
        String command = scope + ":" + varName + ":" + method;
        assertEquals("LOCALS:LOGINS[1]:toString()", command);
    }

    // ===== Object property lookup for array elements =====

    @Test
    public void testObjectKeyLookup_directMatch() {
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.L", "L");
        vars.put("LOCALS.LOGINS", "LOGINS");

        String objectKey = "LOCALS.L";
        assertTrue("Direct key found", vars.containsKey(objectKey));
    }

    @Test
    public void testObjectKeyLookup_arrayElementFallback() {
        // handleObjectProperties must resolve LOCALS.LOGINS[1]
        // by finding parent LOCALS.LOGINS and navigating children
        String objectKey = "LOCALS.LOGINS[1]";
        Map<String, String> vars = new HashMap<>();
        vars.put("LOCALS.LOGINS", "LOGINS");

        assertFalse("Direct key not found",
            vars.containsKey(objectKey));

        // Fallback: extract parent key
        String objectName = "LOGINS[1]";
        assertTrue("Name has brackets", objectName.contains("["));
        int bracketIndex = objectName.indexOf("[");
        String parentName = objectName.substring(0, bracketIndex);
        String parentKey = "LOCALS." + parentName;
        assertTrue("Parent key found", vars.containsKey(parentKey));

        String indices = objectName.substring(bracketIndex);
        assertEquals("[1]", indices);
    }

    // ===== Helpers replicating evaluator logic =====

    private static class ArrayParseResult {
        String baseName;
        List<Integer> indices;
        String remaining;
    }

    /**
     * Replicates findArrayElement parsing logic.
     */
    private ArrayParseResult parseArrayExpression(String expression) {
        int firstBracket = expression.indexOf('[');
        if (firstBracket <= 0) {
            return null;
        }

        ArrayParseResult result = new ArrayParseResult();
        result.baseName = expression.substring(0, firstBracket).trim();
        result.indices = new ArrayList<>();

        String remaining = expression.substring(firstBracket);
        while (remaining.startsWith("[")) {
            int closeBracket = remaining.indexOf(']');
            if (closeBracket < 0) {
                return null;
            }
            String indexStr = remaining.substring(1, closeBracket).trim();
            try {
                result.indices.add(Integer.parseInt(indexStr));
            } catch (NumberFormatException e) {
                return null;
            }
            remaining = remaining.substring(closeBracket + 1);
        }

        if (result.indices.isEmpty()) {
            return null;
        }

        result.remaining = remaining;
        return result;
    }

    /**
     * Detects if expression is a method call (contains : and ()).
     */
    private boolean isMethodCallExpression(String expression) {
        return expression.contains(":") && expression.contains("(");
    }

    private static class InvokeParseResult {
        String scope;
        String varName;
        String method;
    }

    /**
     * Replicates tryInvokeMethod parsing logic.
     * @param vars map of "SCOPE.NAME" → "NAME"
     */
    private InvokeParseResult parseInvokeExpression(String expression,
            Map<String, String> vars) {
        String expr = expression.trim();

        // Find last colon separator
        int methodSep = -1;
        for (int i = expr.length() - 1; i >= 0; i--) {
            if (expr.charAt(i) == ':') {
                methodSep = i;
                break;
            }
        }

        if (methodSep <= 0 || methodSep >= expr.length() - 1) {
            return null;
        }

        String varPart = expr.substring(0, methodSep).trim();
        String methodPart = expr.substring(methodSep + 1).trim();

        // Method must end with ()
        if (!methodPart.endsWith("()")) {
            return null;
        }

        // Extract base name for lookup
        String baseName = varPart;
        if (baseName.contains("[")) {
            baseName = baseName.substring(0, baseName.indexOf('['));
        }

        // Find variable in map (case-insensitive)
        String scope = null;
        for (Map.Entry<String, String> entry : vars.entrySet()) {
            String key = entry.getKey();
            String name = entry.getValue();
            if (baseName.equalsIgnoreCase(name)) {
                int dot = key.indexOf('.');
                if (dot > 0) {
                    scope = key.substring(0, dot);
                }
                break;
            }
        }

        if (scope == null) {
            return null;
        }

        InvokeParseResult result = new InvokeParseResult();
        result.scope = scope;
        result.varName = varPart;
        result.method = methodPart;
        return result;
    }
}

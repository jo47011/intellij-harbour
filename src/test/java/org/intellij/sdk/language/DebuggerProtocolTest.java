package org.intellij.sdk.language;

import org.junit.Test;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import static org.junit.Assert.*;

/**
 * Tests for Harbour debugger protocol parsing.
 * Tests message parsing for STOP, BREAK, variables, etc.
 * without needing the IntelliJ framework.
 */
public class DebuggerProtocolTest {

    /**
     * Test parsing STOP message format (new format).
     * Format: STOP:reason:file:line
     */
    @Test
    public void testStopMessageNewFormat() {
        String message = "STOP:BREAKPOINT:test.prg:42";
        String[] parts = message.split(":");

        assertEquals("Command type", "STOP", parts[0]);
        assertEquals("Stop reason", "BREAKPOINT", parts[1]);
        assertEquals("File name", "test.prg", parts[2]);
        assertEquals("Line number", "42", parts[3]);

        int lineNumber = Integer.parseInt(parts[3].trim());
        assertEquals("Parsed line number", 42, lineNumber);
    }

    /**
     * Test parsing STOP message old format.
     * Format: STOP:file:line
     */
    @Test
    public void testStopMessageOldFormat() {
        String message = "STOP:myprogram.prg:100";
        String[] parts = message.split(":");

        assertEquals("Command type", "STOP", parts[0]);
        assertEquals("File name", "myprogram.prg", parts[1]);
        assertEquals("Line number", "100", parts[2]);
    }

    /**
     * Test parsing BREAK acknowledgment message.
     * Format: BREAK:file:line
     */
    @Test
    public void testBreakAcknowledgment() {
        String message = "BREAK:test.prg:50";
        String[] parts = message.split(":");

        assertEquals("Command type", "BREAK", parts[0]);
        assertEquals("File name", "test.prg", parts[1]);
        assertEquals("Line number", "50", parts[2]);
    }

    /**
     * Test parsing variable message format.
     * Format: NAME:TYPE:VALUE
     */
    @Test
    public void testVariableMessageParsing() {
        // Character variable
        assertVariableParsing("cName:C:John", "cName", "C", "John");

        // Numeric variable
        assertVariableParsing("nCount:N:42", "nCount", "N", "42");

        // Logical variable
        assertVariableParsing("lFlag:L:.T.", "lFlag", "L", ".T.");

        // Date variable
        assertVariableParsing("dBirthday:D:2024-01-15", "dBirthday", "D", "2024-01-15");

        // Array variable
        assertVariableParsing("aItems:A:Array(10)", "aItems", "A", "Array(10)");

        // Object variable
        assertVariableParsing("oWindow:O:TWindow", "oWindow", "O", "TWindow");

        // Hash variable
        assertVariableParsing("hConfig:H:Hash(5)", "hConfig", "H", "Hash(5)");

        // Nil variable
        assertVariableParsing("xUnknown:U:NIL", "xUnknown", "U", "NIL");
    }

    /**
     * Test variable type validation.
     * Valid types: C, N, L, D, A, O, H, U, P
     */
    @Test
    public void testVariableTypeValidation() {
        String validTypes = "CNLDAOHUP";

        // Test valid types
        for (char type : validTypes.toCharArray()) {
            assertTrue("Type " + type + " should be valid",
                isValidVariableType(String.valueOf(type)));
        }

        // Test invalid types
        assertFalse("Type X should be invalid", isValidVariableType("X"));
        assertFalse("Type Z should be invalid", isValidVariableType("Z"));
        assertFalse("Empty type should be invalid", isValidVariableType(""));
        assertFalse("Multi-char type should be invalid", isValidVariableType("CN"));
    }

    /**
     * Test CONSOLE message parsing.
     * Format: CONSOLE:message
     */
    @Test
    public void testConsoleMessageParsing() {
        String message = "CONSOLE:Hello, World!";
        assertTrue("Should start with CONSOLE:", message.startsWith("CONSOLE:"));

        String consoleOutput = message.substring(8); // Skip "CONSOLE:"
        assertEquals("Console output", "Hello, World!", consoleOutput);
    }

    /**
     * Test CONSOLE message with colons in content.
     */
    @Test
    public void testConsoleMessageWithColons() {
        String message = "CONSOLE:Time: 12:30:45";
        String consoleOutput = message.substring(8);
        assertEquals("Should preserve colons in content", "Time: 12:30:45", consoleOutput);
    }

    /**
     * Test EXPRESSION result parsing.
     * Format: EXPRESSION:stack_level:type:value
     */
    @Test
    public void testExpressionResultParsing() {
        String message = "EXPRESSION:0:N:42";
        String[] parts = message.split(":", 4);

        assertEquals("Command", "EXPRESSION", parts[0]);
        assertEquals("Stack level", "0", parts[1]);
        assertEquals("Type", "N", parts[2]);
        assertEquals("Value", "42", parts[3]);
    }

    /**
     * Test ERROR_MSG parsing.
     */
    @Test
    public void testErrorMessageParsing() {
        String message = "ERROR_MSG:Division by zero at line 100";
        assertTrue("Should start with ERROR_MSG:", message.startsWith("ERROR_MSG:"));

        String errorMessage = message.substring(10);
        assertEquals("Error message", "Division by zero at line 100", errorMessage);
    }

    /**
     * Test ERROR_STACK parsing.
     */
    @Test
    public void testErrorStackParsing() {
        String message = "ERROR_STACK:CalledFrom: Main:123";
        assertTrue("Should start with ERROR_STACK:", message.startsWith("ERROR_STACK:"));

        String stackLine = message.substring(12);
        assertEquals("Stack line", "CalledFrom: Main:123", stackLine);
    }

    /**
     * Test variable with value containing colons.
     * Format uses limit: NAME:TYPE:VALUE (VALUE can contain colons)
     */
    @Test
    public void testVariableWithColonsInValue() {
        String message = "cTime:C:12:30:45";
        String[] parts = message.split(":", 3); // Split into max 3 parts

        assertEquals("Variable name", "cTime", parts[0]);
        assertEquals("Variable type", "C", parts[1]);
        assertEquals("Variable value should contain all colons", "12:30:45", parts[2]);
    }

    /**
     * Test handshake message parsing (executable name + PID).
     */
    @Test
    public void testHandshakeMessageParsing() {
        String executableLine = "myprogram.exe";
        String pidLine = "12345";

        assertNotNull("Executable should not be null", executableLine);
        assertNotNull("PID should not be null", pidLine);
        assertTrue("Executable should contain .exe", executableLine.endsWith(".exe"));
        assertTrue("PID should be numeric", pidLine.matches("\\d+"));
    }

    /**
     * Test command detection for multi-line responses.
     */
    @Test
    public void testMultiLineCommandDetection() {
        String[] multiLineCommands = {"STACK", "BREAK", "WORKAREAS"};

        for (String cmd : multiLineCommands) {
            assertTrue("Should detect multi-line command: " + cmd,
                isMultiLineCommand(cmd));
        }

        assertFalse("STOP should not be multi-line", isMultiLineCommand("STOP"));
        assertFalse("CONSOLE should not be multi-line", isMultiLineCommand("CONSOLE"));
    }

    /**
     * Test AREA response command detection.
     */
    @Test
    public void testAreaResponseDetection() {
        String[] areaResponses = {"FIELDS", "RECORD", "SCHEMA"};

        for (String response : areaResponses) {
            String message = "AREA:" + response + ":data";
            String[] parts = message.split(":");
            assertTrue("Should detect AREA:" + response,
                parts.length >= 2 && parts[1].equals(response));
        }
    }

    /**
     * Test unnamed stack slot pattern matching.
     * Pattern: Local_1, Local_2, etc.
     */
    @Test
    public void testUnnamedStackSlotPattern() {
        Pattern unnamedSlotPattern = Pattern.compile("^Local_\\d+$");

        // Should match
        assertTrue(unnamedSlotPattern.matcher("Local_1").matches());
        assertTrue(unnamedSlotPattern.matcher("Local_99").matches());
        assertTrue(unnamedSlotPattern.matcher("Local_999").matches());

        // Should NOT match
        assertFalse(unnamedSlotPattern.matcher("cName").matches());
        assertFalse(unnamedSlotPattern.matcher("local_1").matches()); // lowercase
        assertFalse(unnamedSlotPattern.matcher("Local_").matches()); // no number
        assertFalse(unnamedSlotPattern.matcher("Local_abc").matches()); // non-numeric
    }

    /**
     * Test GETLIST filtering logic.
     * Empty system GETLIST (PUBLIC scope) should be filtered.
     */
    @Test
    public void testGetlistFiltering() {
        // This should be filtered (empty system GETLIST in PUBLIC scope)
        String key = "PUBLICS.GETLIST";
        String name = "GETLIST";
        String type = "A";
        String value = "Array(0)";

        boolean shouldFilter = "GETLIST".equals(name) &&
            "A".equals(type) &&
            "Array(0)".equals(value) &&
            key.startsWith("PUBLICS.");

        assertTrue("Empty system GETLIST should be filtered", shouldFilter);

        // Non-empty GETLIST should NOT be filtered
        String nonEmptyValue = "Array(3)";
        boolean shouldNotFilter = "GETLIST".equals(name) &&
            "A".equals(type) &&
            "Array(0)".equals(nonEmptyValue);

        assertFalse("Non-empty GETLIST should not be filtered", shouldNotFilter);
    }

    // ===== Helper methods =====

    private void assertVariableParsing(String message, String expectedName,
                                       String expectedType, String expectedValue) {
        String[] parts = message.split(":", 3);
        assertEquals("Variable name for: " + message, expectedName, parts[0]);
        assertEquals("Variable type for: " + message, expectedType, parts[1]);
        assertEquals("Variable value for: " + message, expectedValue, parts[2]);
    }

    private boolean isValidVariableType(String type) {
        if (type == null || type.length() != 1) return false;
        return "CNLDAOHUP".contains(type);
    }

    private boolean isMultiLineCommand(String command) {
        return command.equals("STACK") ||
               command.equals("BREAK") ||
               command.startsWith("BREAK:") ||
               command.equals("WORKAREAS");
    }
}

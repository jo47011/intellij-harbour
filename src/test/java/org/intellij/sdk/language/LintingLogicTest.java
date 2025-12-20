package org.intellij.sdk.language;

import org.junit.Test;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import static org.junit.Assert.*;

/**
 * Tests for Harbour linting logic.
 * Tests error parsing patterns and syntax detection without the IntelliJ framework.
 */
public class LintingLogicTest {

    // Patterns from HarbourExternalAnnotator
    private static final Pattern ERROR_PATTERN = Pattern.compile(
        "^(.+?)\\((\\d+)\\)\\s+(Error|Warning)\\s+(E\\d+|W\\d+)?\\s*(.+)$"
    );

    private static final Pattern ERROR_PATTERN_ALT = Pattern.compile(
        "^(.+?):\\s*(\\d+):\\s*(Error|Warning):\\s*(.+)$"
    );

    private static final Pattern ERROR_PATTERN_SIMPLE = Pattern.compile(
        "^(.+?)\\((\\d+)\\)\\s*:?\\s*(Error|Warning|error|warning)\\s*:?\\s*(.+)$",
        Pattern.CASE_INSENSITIVE
    );

    /**
     * Test parsing of standard Harbour error format.
     * Format: filename(line) Error/Warning CODE message
     */
    @Test
    public void testStandardErrorFormat() {
        String errorLine = "test.prg(42) Error E0001 Syntax error";

        Matcher matcher = ERROR_PATTERN.matcher(errorLine);
        assertTrue("Should match standard error format", matcher.matches());
        assertEquals("File path", "test.prg", matcher.group(1));
        assertEquals("Line number", "42", matcher.group(2));
        assertEquals("Severity", "Error", matcher.group(3));
        assertEquals("Error code", "E0001", matcher.group(4));
        assertEquals("Message", "Syntax error", matcher.group(5));
    }

    /**
     * Test parsing of warning format.
     */
    @Test
    public void testWarningFormat() {
        String warningLine = "myfile.prg(100) Warning W0003 Variable 'nCount' is declared but not used";

        Matcher matcher = ERROR_PATTERN.matcher(warningLine);
        assertTrue("Should match warning format", matcher.matches());
        assertEquals("Severity", "Warning", matcher.group(3));
        assertEquals("Warning code", "W0003", matcher.group(4));
    }

    /**
     * Test parsing of undefined variable warning.
     */
    @Test
    public void testUndefinedVariableWarning() {
        String warningLine = "test.prg(25) Warning W0001 Ambiguous reference 'oWindow'";

        Matcher matcher = ERROR_PATTERN.matcher(warningLine);
        assertTrue("Should match undefined variable warning", matcher.matches());
        assertEquals("Line number", "25", matcher.group(2));
        assertEquals("Severity", "Warning", matcher.group(3));
        assertTrue("Should contain variable name", matcher.group(5).contains("oWindow"));
    }

    /**
     * Test parsing of alternative error format (colon-separated).
     */
    @Test
    public void testAlternativeErrorFormat() {
        String errorLine = "program.prg: 15: Error: Undefined function 'MyFunc'";

        // Standard pattern should not match
        Matcher stdMatcher = ERROR_PATTERN.matcher(errorLine);
        assertFalse("Standard pattern should not match", stdMatcher.matches());

        // Alternative pattern should match
        Matcher altMatcher = ERROR_PATTERN_ALT.matcher(errorLine);
        assertTrue("Alternative pattern should match", altMatcher.matches());
        assertEquals("File path", "program.prg", altMatcher.group(1));
        assertEquals("Line number", "15", altMatcher.group(2));
        assertEquals("Severity", "Error", altMatcher.group(3));
    }

    /**
     * Test parsing of simple error format (lowercase).
     */
    @Test
    public void testSimpleErrorFormat() {
        String errorLine = "test.prg(10) error: unexpected token";

        // Standard pattern should not match (lowercase)
        Matcher stdMatcher = ERROR_PATTERN.matcher(errorLine);
        assertFalse("Standard pattern should not match lowercase", stdMatcher.matches());

        // Simple pattern should match (case insensitive)
        Matcher simpleMatcher = ERROR_PATTERN_SIMPLE.matcher(errorLine);
        assertTrue("Simple pattern should match lowercase", simpleMatcher.matches());
    }

    /**
     * Test parsing with Windows path.
     */
    @Test
    public void testWindowsPathFormat() {
        String errorLine = "C:\\Users\\dev\\project\\test.prg(50) Error E0002 Invalid expression";

        Matcher matcher = ERROR_PATTERN.matcher(errorLine);
        assertTrue("Should match Windows path", matcher.matches());
        assertEquals("File path", "C:\\Users\\dev\\project\\test.prg", matcher.group(1));
        assertEquals("Line number", "50", matcher.group(2));
    }

    /**
     * Test parsing with spaces in path.
     */
    @Test
    public void testPathWithSpaces() {
        String errorLine = "C:\\My Projects\\harbour test\\file.prg(10) Error E0001 Test";

        Matcher matcher = ERROR_PATTERN.matcher(errorLine);
        assertTrue("Should match path with spaces", matcher.matches());
        assertEquals("File path", "C:\\My Projects\\harbour test\\file.prg", matcher.group(1));
    }

    /**
     * Test quick syntax check - unmatched quotes.
     */
    @Test
    public void testUnmatchedQuoteDetection() {
        Pattern unmatchedQuotePattern = Pattern.compile(
            "\\b\\w+\\s*\\(\\s*\"[^\"]*\"[^)\"]*(?![\"\\s]*\\))",
            Pattern.MULTILINE | Pattern.CASE_INSENSITIVE
        );

        // Should detect unmatched quote
        String badCode = "qout(\"hello\"xxx";
        assertTrue("Should detect unmatched quote", unmatchedQuotePattern.matcher(badCode).find());

        // Should NOT match valid code
        String goodCode = "qout(\"hello\")";
        assertFalse("Should not match valid code", unmatchedQuotePattern.matcher(goodCode).find());
    }

    /**
     * Test LOCAL variable with invalid character detection.
     */
    @Test
    public void testLocalWithSlashDetection() {
        Pattern localWithSlash = Pattern.compile("\\bLOCAL\\s+\\w+\\s*/");

        // Should detect invalid syntax
        String badCode = "LOCAL gaga /";
        assertTrue("Should detect LOCAL with slash", localWithSlash.matcher(badCode).find());

        // Should NOT match valid code
        String goodCode = "LOCAL gaga";
        assertFalse("Should not match valid LOCAL", localWithSlash.matcher(goodCode).find());
    }

    /**
     * Test severity mapping.
     */
    @Test
    public void testSeverityMapping() {
        // Error severity
        assertTrue("Error should be recognized", "Error".equalsIgnoreCase("error"));
        assertTrue("ERROR should be recognized", "Error".equalsIgnoreCase("ERROR"));

        // Warning severity
        assertTrue("Warning should be recognized", "Warning".equalsIgnoreCase("warning"));
        assertTrue("WARNING should be recognized", "Warning".equalsIgnoreCase("WARNING"));
    }

    /**
     * Test that non-matching lines return no match.
     */
    @Test
    public void testNonMatchingLines() {
        String[] nonMatchingLines = {
            "",
            "   ",
            "// This is a comment",
            "FUNCTION Main()",
            "LOCAL nVar",
            "Harbour Compiler 3.2.0",
            "Processing: test.prg"
        };

        for (String line : nonMatchingLines) {
            Matcher std = ERROR_PATTERN.matcher(line);
            Matcher alt = ERROR_PATTERN_ALT.matcher(line);
            Matcher simple = ERROR_PATTERN_SIMPLE.matcher(line);

            assertFalse("Non-error line should not match: " + line,
                std.matches() || alt.matches() || simple.matches());
        }
    }

    /**
     * Test unused variable warning format (W0032).
     */
    @Test
    public void testUnusedVariableWarning() {
        String warningLine = "test.prg(5) Warning W0032 Variable 'lResult' is never used";

        Matcher matcher = ERROR_PATTERN.matcher(warningLine);
        assertTrue("Should match unused variable warning", matcher.matches());
        assertEquals("Warning code", "W0032", matcher.group(4));
        assertTrue("Should contain variable name", matcher.group(5).contains("lResult"));
    }

    /**
     * Test assigned but not used warning format (W0003).
     */
    @Test
    public void testAssignedButNotUsedWarning() {
        String warningLine = "test.prg(10) Warning W0003 Variable 'cName' is assigned but not used";

        Matcher matcher = ERROR_PATTERN.matcher(warningLine);
        assertTrue("Should match assigned but not used warning", matcher.matches());
        assertEquals("Warning code", "W0003", matcher.group(4));
    }
}

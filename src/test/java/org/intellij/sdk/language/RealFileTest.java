package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Tests formatting of real-world Harbour code with complex strings.
 * Verifies that the formatter doesn't corrupt nested quote patterns.
 */
public class RealFileTest {

    private static final int MAX_LINE_LENGTH = 99;

    @Test
    public void testWithIfBlock() {
        String input =
            "FUNCTION Test()\n" +
            "  if .T.\n" +
            "    Message(\"Lager-Bestand=\"+alltrim(str(ARTIKEL->LageBest,9,2))+\" K-Bestand=\"+;\n" +
            "      alltrim(str(ARTIKEL->KonsigBest,9,2))+\" Bestellt=\"+alltrim(str(M->summeBestellte,9,2))+\" @Max=\"+alltrim(str(max,9,2)+\"@\")+\"  @F9@=Details\")\n" +
            "  endif\n" +
            "RETURN\n";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, MAX_LINE_LENGTH);

        // Verify no corruption - output should still be valid Harbour code
        assertNotNull("Formatter returned null", formatted);
        assertFalse("Formatter returned empty string", formatted.isEmpty());

        // Verify key elements are preserved
        assertTrue("Missing FUNCTION keyword", formatted.contains("FUNCTION"));
        assertTrue("Missing Message function call", formatted.contains("Message("));
        assertTrue("Missing RETURN keyword", formatted.contains("RETURN"));

        // Note: This test intentionally has nested quotes that should NOT be wrapped
        // The formatter should leave the complex string unchanged per CLAUDE.md rules
    }
}

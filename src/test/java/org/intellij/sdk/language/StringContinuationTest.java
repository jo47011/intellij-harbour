package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Quick test for string continuation handling in the formatter.
 */
public class StringContinuationTest {

    @Test
    public void testArrayLiteralWithStringConcatenation() {
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        // This is the problematic pattern from errorsys.prg
        String input =
            "function Test()\n" +
            "  if .t.\n" +
            "    Trouble(\"root\", { \"not fixed: \"+objErr:Description+\" EG_OPEN\" , ;\n" +
            "        \"Benutzer:\"+getUser():getLongId() } )\n" +
            "  endif\n" +
            "return nil\n";

        System.out.println("=== INPUT ===");
        System.out.println(input);
        System.out.println("=============");

        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        System.out.println(formatted);
        System.out.println("==============");

        // The formatted output should still be valid Harbour code
        // Check that strings are not corrupted
        assertFalse("String should not be truncated",
            formatted.contains("'+getUser():getLongId()"));

        // The original strings should be preserved or properly joined
        assertTrue("Output should contain the function call",
            formatted.contains("Trouble("));
    }
}

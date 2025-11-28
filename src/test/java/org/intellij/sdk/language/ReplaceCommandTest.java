package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class ReplaceCommandTest {

    @Test
    public void testReplaceCommandNotBrokenAfterReplace() {
        // Test that replace command is NOT broken after "replace" keyword
        // Input is a long joined line that exceeds 99 chars
        // Use deeper nesting to force line breaking
        String input =
            "FUNCTION Test()\n" +
            "  if .T.\n" +
            "    if .T.\n" +
            "      if .T.\n" +
            "          replace AUFTRAG->Komm3 with \"Max. K-Lager Menge \"+alltrim(str(maxKonsig,7,2))+\" überschritten.\"\n" +
            "      endif\n" +
            "    endif\n" +
            "  endif\n" +
            "RETURN\n";
        
        System.out.println("=== INPUT ===");
        String[] lines = input.split("\n");
        for (int i = 0; i < lines.length; i++) {
            System.out.printf("Line %d [%3d]: %s%n", i+1, lines[i].length(), lines[i]);
        }
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        System.out.println("\n=== OUTPUT ===");
        String[] outLines = formatted.split("\n");
        boolean allLinesOk = true;
        for (int i = 0; i < outLines.length; i++) {
            System.out.printf("Line %d [%3d]: %s%n", i+1, outLines[i].length(), outLines[i]);
            if (outLines[i].length() > 99) {
                System.out.println("  ^^^ TOO LONG");
                allLinesOk = false;
            }
        }
        
        // Find the line with "replace" and verify it's not broken incorrectly
        boolean foundReplace = false;
        for (String line : outLines) {
            String trimmed = line.trim().toLowerCase();
            if (trimmed.startsWith("replace")) {
                foundReplace = true;
                // Should NOT be just "replace;"
                assertFalse("Replace line should not be just 'replace;'",
                    trimmed.equals("replace;"));
                // Should contain "with" on the same line
                assertTrue("Replace line should contain 'with'",
                    trimmed.contains(" with "));
                break;
            }
        }
        assertTrue("Should find a line starting with 'replace'", foundReplace);
        assertTrue("All output lines should be <= 99 chars", allLinesOk);
    }
}

package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class FunctionCallBreakTest {

    @Test
    public void testNoBreakInsideFunctionCall() {
        // Line from fakt.prg#3099 - should NOT break inside str() function
        // Should break at + operator BEFORE the function call
        // Input has the bad break inside str() function - should be fixed
        String input =
            "FUNCTION Test()\n" +
            "  if .T.\n" +
            "        Error(ACHTUNG+\" Artikel: \"+ARTIKEL->ArtNr+\" Mind.Bestellung: \"+str(ARTIKEL->MinOrderI,9,;\n" +
            "          2),.f.)\n" +
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
        
        // Check that no line ends with ",9,;" - that would indicate breaking inside str()
        for (String line : outLines) {
            String trimmed = line.trim();
            assertFalse("Should not break inside function call parameters (found ',9,;')",
                trimmed.endsWith(",9,;"));
        }
        assertTrue("All output lines should be <= 99 chars", allLinesOk);
    }
}

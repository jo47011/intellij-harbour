package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class SelectGoTest {

    @Test
    public void testSelectGoNoSemicolonDeepNesting() {
        // Test exact context from fakt.prg#3253-3260
        String input =
            "FUNCTION Test()\n" +
            "  if .t.\n" +
            "    if Message(\"Rabatt: \"+alltrim(oGet:buffer)+\"% für alle gelieferten Artikel (\"+;\n" +
            "      AUFTRAG->ArtNr+\") übernehmen?\",\"JN\",\" \")<>\"J\"\n" +
            "      set filter to\n" +
            "      select Auftrag\n" +
            "      restscreen(,,,,s01)\n" +
            "      return .f.\n" +
            "    endif\n" +
            "  endif\n" +
            "RETURN\n";
        
        System.out.println("=== INPUT ===");
        String[] lines = input.split("\n");
        for (int i = 0; i < lines.length; i++) {
            System.out.printf("Line %d: %s%n", i+1, lines[i]);
        }
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        System.out.println("\n=== OUTPUT ===");
        String[] outLines = formatted.split("\n");
        for (int i = 0; i < outLines.length; i++) {
            System.out.printf("Line %d: %s%n", i+1, outLines[i]);
        }
        
        // Check that select doesn't have semicolon
        for (String line : outLines) {
            String trimmed = line.trim().toLowerCase();
            if (trimmed.startsWith("select ")) {
                assertFalse("select statement should NOT have semicolon: " + trimmed,
                    trimmed.endsWith(";"));
            }
        }
    }
}

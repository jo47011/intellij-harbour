package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class FaktPrgTest {

    @Test  
    public void testFaktPrgLine2987() {
        // Actual lines from fakt.prg around line 2987-2988
        String input = 
            "    Message(\"Lager-Bestand=\"+alltrim(str(ARTIKEL->LageBest,9,2))+\" K-Bestand=\"+;\n" +
            "      alltrim(str(ARTIKEL->KonsigBest,9,2))+\" Bestellt=\"+alltrim(str(M->summeBestellte,9,2))+\" @Max=\"+alltrim(str(max,9,2)+\"@\")+\"  @F9@=Details\")\n";
        
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
        
        assertTrue("All output lines should be <= 99 chars", allLinesOk);
    }

    @Test
    public void testFaktLine5242GetWhen() {
        // Line 5242 from fakt.prg - should break before 'when', not inside string
        // Wrap in FUNCTION to provide context for proper indentation
        String input = "FUNCTION test()\n" +
            "  @ 20,1 get AUFAUS->Ansprech when Message(\"Ansprechpartner eingeben   @F12@=Kundendaten übernehmen\")\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        for (String line : input.split("\n")) {
            System.out.printf("[%3d] %s%n", line.length(), line);
        }

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("\n=== OUTPUT ===");
        String[] outLines = formatted.split("\n");
        for (int i = 0; i < outLines.length; i++) {
            System.out.printf("Line %d [%3d]: %s%n", i+1, outLines[i].length(), outLines[i]);
        }

        // Should NOT have string split ("+;)
        assertFalse("Should NOT split the string", formatted.contains("\"+;"));

        // Should have break before 'when'
        boolean hasProperBreak = false;
        for (int i = 0; i < outLines.length - 1; i++) {
            if (outLines[i].trim().endsWith(";") && outLines[i+1].trim().toLowerCase().startsWith("when ")) {
                hasProperBreak = true;
                break;
            }
        }
        assertTrue("Should break BEFORE 'when' clause", hasProperBreak);
    }
}

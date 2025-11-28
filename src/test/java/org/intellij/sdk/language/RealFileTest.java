package org.intellij.sdk.language;

import org.junit.Test;

public class RealFileTest {

    @Test  
    public void testWithIfBlock() {
        String input = 
            "FUNCTION Test()\n" +
            "  if .T.\n" +
            "    Message(\"Lager-Bestand=\"+alltrim(str(ARTIKEL->LageBest,9,2))+\" K-Bestand=\"+;\n" +
            "      alltrim(str(ARTIKEL->KonsigBest,9,2))+\" Bestellt=\"+alltrim(str(M->summeBestellte,9,2))+\" @Max=\"+alltrim(str(max,9,2)+\"@\")+\"  @F9@=Details\")\n" +
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
        for (int i = 0; i < outLines.length; i++) {
            System.out.printf("Line %d [%3d]: %s%n", i+1, outLines[i].length(), outLines[i]);
            if (outLines[i].length() > 99) {
                System.out.println("  ^^^ TOO LONG");
            }
        }
    }
}

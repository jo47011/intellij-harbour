package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class ContStatementTest {

    @Test
    public void testContStatementNoSemicolon() {
        // Test exact context from fakt.prg line 3180-3188
        String input =
            "FUNCTION Test()\n" +
            "      else\n" +
            "        // lösche evtl. vorherige Mindermengenzuschläge\n" +
            "        loca for alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL .and. ;\n" +
            "          trim(AUFTRAG->tempStr)==merkArtNr + str(oGet:original,10,2)\n" +
            "        do while ! AUFTRAG->(eof())\n" +
            "          replace AUFTRAG->geloescht with \"J\"\n" +
            "          cont\n" +
            "          // BS ausgeben\n" +
            "          aSpalte[EDIT_BS_AUSGABE]:=.t.\n" +
            "        enddo\n" +
            "        go (aktRec)\n" +
            "      endif\n" +
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
        
        // Find the cont line and verify it does NOT have a semicolon
        boolean foundCont = false;
        for (String line : outLines) {
            String trimmed = line.trim().toLowerCase();
            if (trimmed.equals("cont") || trimmed.equals("cont;")) {
                foundCont = true;
                assertFalse("cont statement should NOT have semicolon added, but was: " + trimmed,
                    trimmed.endsWith(";"));
                break;
            }
        }
        assertTrue("Should find a cont statement", foundCont);
    }
}

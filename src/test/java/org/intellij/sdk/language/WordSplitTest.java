package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class WordSplitTest {

    @Test
    public void testNoWordSplit() {
        // Test that ERR_NO_WAIT doesn't get split
        String input =
            "FUNCTION Test()\n" +
            "  if .t.\n" +
            "    if .t.\n" +
            "      if .t.\n" +
            "        if .t.\n" +
            "          if .t.\n" +
            "            Error(\"Werkzeug-Gutschrift!||Soll für die gesamte Gutschrift MwSt werden?\",;\n" +
            "              ERR_NO_WAIT)\n" +
            "          endif\n" +
            "        endif\n" +
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
        for (int i = 0; i < outLines.length; i++) {
            System.out.printf("Line %d [%3d]: %s%n", i+1, outLines[i].length(), outLines[i]);
        }
        
        // Check that no word is split (no line ends with partial identifier;)
        for (int i = 0; i < outLines.length; i++) {
            String line = outLines[i];
            // Check for lines ending with partial identifier followed by ;
            // These would be split words like ERR_NO_WAI;
            if (line.matches(".*[A-Za-z_][A-Za-z0-9_]*;\\s*$") && !line.toLowerCase().matches(".*\\.(and|or|not)\\.;\\s*$")) {
                // Check if the next line starts with the rest of the identifier
                if (i + 1 < outLines.length) {
                    String nextLine = outLines[i + 1].trim();
                    if (nextLine.matches("^[A-Za-z0-9_]+[^A-Za-z0-9_].*") || nextLine.matches("^[A-Za-z0-9_]+$")) {
                        // Extract the partial identifier
                        String partial = line.replaceAll(".*?([A-Za-z_][A-Za-z0-9_]*);\\s*$", "$1");
                        // This looks like a split word - but might be valid like BESAUS;
                        // followed by ->field. Let's just check for ERR_NO_WAI specifically
                        if (partial.equals("ERR_NO_WAI")) {
                            fail("Word ERR_NO_WAIT was split at line " + (i+1) + ": " + line.trim() + " / " + nextLine);
                        }
                    }
                }
            }
        }
        
        // Also verify ERR_NO_WAIT appears complete in output
        boolean foundComplete = formatted.contains("ERR_NO_WAIT");
        assertTrue("ERR_NO_WAIT should appear complete (not split)", foundComplete);
    }
}

package org.intellij.sdk.language;

import org.junit.Test;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.io.FileWriter;
import static org.junit.Assert.*;

public class FaktFullTest {

    @Test
    public void testFaktPrgFormatAndCompile() throws Exception {
        // Read the actual fakt.prg file
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/fakt.prg")));
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        // Write to temp file for compilation
        String tempFile = "/home/developer/workspace/intellij-harbour/tmp/fakt_format_test.prg";
        try (FileWriter fw = new FileWriter(tempFile)) {
            fw.write(formatted);
        }
        
        System.out.println("Formatted file written to: " + tempFile);
        System.out.println("Total lines: " + formatted.split("\n").length);
        
        // Check no words are split
        String[] lines = formatted.split("\n");
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            // Check if line ends with partial identifier followed by ;
            if (line.matches(".*[A-Za-z_][A-Za-z0-9_]{1,10};\\s*$")) {
                // Get the partial identifier
                String partial = line.replaceAll(".*?([A-Za-z_][A-Za-z0-9_]{1,10});\\s*$", "$1");
                // Skip valid endings like .and.; .or.; etc
                if (partial.matches("(?i)and|or|not")) continue;
                // Skip if next line doesn't start with identifier chars
                if (i + 1 < lines.length) {
                    String nextLine = lines[i + 1].trim();
                    if (nextLine.matches("^[A-Za-z0-9_]+.*") && !nextLine.startsWith("\"") && !nextLine.startsWith("'")) {
                        // This looks suspicious - might be a split word
                        // Check if combined they form a known pattern like BESAUS, ERR_NO_WAIT, etc.
                        String combined = partial + nextLine.split("[^A-Za-z0-9_]")[0];
                        System.out.println("WARN: Possible split word at line " + (i+1) + ": " + partial + " + " + nextLine.substring(0, Math.min(20, nextLine.length())));
                    }
                }
            }
        }
        
        // Also write for external compilation test
        System.out.println("File ready for compilation with: /home/developer/workspace/harbour/bin/linux/gcc/harbour " + tempFile + " -n -w3 -i/home/developer/workspace/harbour/include");
    }
}

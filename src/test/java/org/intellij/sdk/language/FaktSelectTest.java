package org.intellij.sdk.language;

import org.junit.Test;
import java.nio.file.Files;
import java.nio.file.Paths;
import static org.junit.Assert.*;

public class FaktSelectTest {

    @Test
    public void testFaktPrgSelectLines() throws Exception {
        // Read the actual fakt.prg file
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/fakt.prg")));
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        String[] outLines = formatted.split("\n");
        
        // Check lines around 3253-3260 for semicolons on select/go
        System.out.println("=== Checking lines 3248-3275 ===");
        for (int i = 3247; i < Math.min(3275, outLines.length); i++) {
            System.out.printf("Line %d: %s%n", i+1, outLines[i]);
            
            String trimmed = outLines[i].trim().toLowerCase();
            if (trimmed.startsWith("select ") && !trimmed.contains("case")) {
                assertFalse("select statement at line " + (i+1) + " should NOT have semicolon: " + trimmed,
                    trimmed.endsWith(";"));
            }
            if (trimmed.startsWith("go ") || trimmed.startsWith("go(")) {
                assertFalse("go statement at line " + (i+1) + " should NOT have semicolon: " + trimmed,
                    trimmed.endsWith(";"));
            }
        }
    }
}

package org.intellij.sdk.language;

import org.junit.Test;
import java.nio.file.Files;
import java.nio.file.Paths;
import static org.junit.Assert.*;

public class SemicolonBeforeCommentTest {

    @Test
    public void testNoSemicolonBeforeComment() throws Exception {
        // Read fakt.prg and format it
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/fakt.prg")));
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        String[] outLines = formatted.split("\n");
        
        // Check lines 3285-3300 specifically
        System.out.println("=== Lines 3285-3300 ===");
        for (int i = 3284; i < Math.min(3300, outLines.length); i++) {
            System.out.printf("Line %d: %s%n", i+1, outLines[i]);
        }
        
        // Verify no code lines have semicolons before comments
        for (int i = 0; i < outLines.length - 1; i++) {
            String line = outLines[i].trim();
            String nextLine = outLines[i + 1].trim();
            
            // Skip if current line is a comment (comments can have any content)
            if (line.startsWith("//") || line.startsWith("/*") || line.startsWith("*")) {
                continue;
            }
            
            // If code line ends with ; and next line is a comment
            if (line.endsWith(";") && (nextLine.startsWith("//") || nextLine.startsWith("/*"))) {
                fail("Line " + (i+1) + " has semicolon before comment: " + line + " / " + nextLine);
            }
        }
        
        // Verify specific lines from feedback don't have semicolons
        // Line 3289 should be "select Auftrag" without semicolon
        // Line 3296 should be "go (aktRec)" without semicolon
        String line3289 = outLines[3288].trim().toLowerCase();
        assertFalse("Line 3289 should not have semicolon: " + line3289, 
            line3289.equals("select auftrag;"));
        
        String line3296 = outLines[3295].trim().toLowerCase();
        assertFalse("Line 3296 should not have semicolon: " + line3296,
            line3296.matches("go\\s*\\(aktrec\\);"));
            
        System.out.println("=== Verified: select Auftrag and go (aktRec) have no semicolons ===");
    }
}

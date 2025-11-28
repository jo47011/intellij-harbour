package org.intellij.sdk.language;

import org.junit.Test;
import java.nio.file.Files;
import java.nio.file.Paths;
import static org.junit.Assert.*;

public class SelectAuftragTest {

    @Test
    public void testSelectAuftragNoSemicolon() throws Exception {
        // Read fakt.prg and format it
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/fakt.prg")));
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        String[] outLines = formatted.split("\n");
        
        // Look for "select Auftrag" or "select auftrag" and check for semicolons
        System.out.println("=== Checking all 'select Auftrag' lines ===");
        for (int i = 0; i < outLines.length; i++) {
            String line = outLines[i];
            String trimmed = line.trim().toLowerCase();
            if (trimmed.startsWith("select auftrag") || trimmed.startsWith("select konsig")) {
                System.out.printf("Line %d: %s%n", i+1, line);
                // Check if it wrongly has a semicolon when it shouldn't
                if (trimmed.equals("select auftrag;") || trimmed.equals("select konsig;")) {
                    // This MIGHT be wrong - need to check context
                    System.out.println("  ^^^ HAS SEMICOLON - checking if valid...");
                    // Check if next line is a continuation (indented more)
                    if (i + 1 < outLines.length) {
                        String nextLine = outLines[i + 1];
                        String nextTrimmed = nextLine.trim().toLowerCase();
                        // If next line is not indented more, semicolon is wrong
                        int thisIndent = line.length() - line.stripLeading().length();
                        int nextIndent = nextLine.length() - nextLine.stripLeading().length();
                        if (nextIndent <= thisIndent && !nextTrimmed.isEmpty()) {
                            System.out.println("  ^^^ INVALID - next line not indented more: " + nextLine.trim());
                        }
                    }
                }
            }
            // Also check "go " statements
            if (trimmed.matches("go\\s*\\(.*\\);")) {
                System.out.printf("Line %d (go with ;): %s%n", i+1, line);
            }
        }
    }
}

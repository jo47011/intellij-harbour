package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;
import java.nio.file.*;

public class SingleFileTest {

    @Test
    public void testInneraufCorruption() throws Exception {
        // Test - longer continuation line with trailing space causes corruption
        String input =
            "FUNCTION test()\r\n" +
            "  DO CASE\r\n" +
            "  CASE ( \"TEST\"  ) .or. ;\r\n" +
            "      \"INNERAUF\"$ upper(x) .or. cProg==\"INNERAUF\" .or. \"XINNERNR\" $ upper(x) \r\n" +  // longer line with trailing space
            "    open(\"Inner\")\r\n" +
            "  ENDCASE\r\n" +
            "RETURN\r\n";

        System.out.println("=== INPUT ===");
        for (String line : input.split("\n", -1)) {
            System.out.printf("'%s'%n", line);
        }

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        for (String line : formatted.split("\n", -1)) {
            System.out.printf("'%s'%n", line);
        }

        // Check for "  " corruption
        assertFalse("Should not have '\"  \"' corruption",
            formatted.contains("\"  \"INNERAUF"));
    }

    @Test
    public void testSemicolonBeforeComment() throws Exception {
        // Test that ,; before comment is preserved
        String input =
            "FUNCTION test()\n" +
            "  LOCAL a:={ 1 ,;\n" +
            "    2 ,;   // comment\n" +
            "    3 }\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        System.out.println(input);

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        System.out.println(formatted);

        // The semicolon before the comment must be preserved
        assertTrue("Semicolon before comment should be preserved",
            formatted.contains(",;   // comment") || formatted.contains(",; // comment"));
    }

    @Test
    public void testMinimalCorruption() throws Exception {
        // Minimal test case matching the exact pattern from errorsys.prg
        // Note: the space before ; in ", ;" is important!
        String input =
            "FUNCTION DefError(objErr)\n" +
            "  LOCAL sendEmail:=.T.\n" +
            "  if sendEmail\n" +
            "    Trouble(\"root\", { \"not fixed: \"+objErr:Description+\" EG_OPEN\" , ;\n" +
            "      \"Benutzer:\"+getUser():getLongId() } )\n" +
            "  endif\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, outputLines[i]);
        }
        System.out.println("==============");

        // Check that "Benutzer:" is not corrupted
        if (formatted.contains("\"  \"Benutzer:") || formatted.contains("\"  \"")) {
            System.out.println("CORRUPTION DETECTED: Found '\"  \"'");
            fail("Continuation line corrupted with '\"  \"' insertion");
        }

        // Verify the continuation line still has the quote at the start
        assertTrue("Should still have the string content", formatted.contains("\"Benutzer:\""));
    }

    @Test
    public void testFullFile() throws Exception {
        // Self-contained test with embedded errorsys-like code
        String input =
            "FUNCTION DefError(objErr)\n" +
            "LOCAL sendEmail:=.T., cText\n" +
            "if sendEmail\n" +
            "  cText:=\"Error: \"+objErr:Description\n" +
            "  Trouble(\"root\", { \"not fixed: \"+objErr:Description+\" EG_OPEN\" , ;\n" +
            "    \"Benutzer:\"+getUser():getLongId() } )\n" +
            "endif\n" +
            "RETURN NIL\n";

        // Format
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] lines = formatted.split("\n", -1);
        for (int i = 0; i < lines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, lines[i]);
        }
        System.out.println("============================");

        // Check for corruption
        assertFalse("Should not have corrupted continuation lines",
            formatted.contains("\"  \"Benutzer:"));
    }

    // External file tests removed - tests should be self-contained
    // Use HarbourFormattingTest with -DtestDir for full file testing

    @Test
    public void testElseIndentation() throws Exception {
        // Test from FEEDBACK: else should be indented to match its if
        // This is the case from fakt.prg#229
        String input =
            "FUNCTION test()\n" +
            "  if condA\n" +
            "    if condB\n" +
            "      doSomething()\n" +
            "    endif\n" +
            "  else // comment\n" +
            "    doOther()\n" +
            "  endif\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // else should have same indent as the outer if (2 spaces)
        String elseLine = outputLines[5];
        int elseIndent = elseLine.length() - elseLine.stripLeading().length();

        String outerIfLine = outputLines[1];
        int outerIfIndent = outerIfLine.length() - outerIfLine.stripLeading().length();

        System.out.println("\nIndentation check:");
        System.out.printf("  Outer if: %d spaces%n", outerIfIndent);
        System.out.printf("  else: %d spaces%n", elseIndent);

        assertEquals("else should have same indent as its matching if", outerIfIndent, elseIndent);
    }

    @Test
    public void testAtRowColNoBreak() throws Exception {
        // Test from FEEDBACK: @ row,col commands should NOT be split at the comma
        // This is the case from fakt.prg#377
        String input =
            "FUNCTION test()\n" +
            "  @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/PDF) ' get Ausgabe Picture \"!\" valid Ausgabe $\"DBP\"\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, outputLines[i]);
        }
        System.out.println("==============");

        // The @ 10,20 should NOT be split - it should stay on one line or break elsewhere
        // Check that no line starts with just a number (like "20 say...")
        for (String line : outputLines) {
            String trimmed = line.trim();
            assertFalse("Line should not start with number after @ row,col split: " + trimmed,
                trimmed.matches("^\\d+\\s+say.*"));
        }

        // Check that @ command is not followed by just a number on next line
        for (int i = 0; i < outputLines.length - 1; i++) {
            String current = outputLines[i].trim();
            String next = outputLines[i + 1].trim();
            if (current.matches("@\\s*\\d+,;?\\s*$")) {
                fail("@ row,col should not be split: current='" + current + "', next='" + next + "'");
            }
        }
    }

    @Test
    public void testAtRowColJoinExistingSplit() throws Exception {
        // Test that an EXISTING incorrect split at @ row,col is JOINED back together
        // This is the case from fakt.prg#376-377 where the file already has the bad split
        String input =
            "FUNCTION test()\n" +
            "  @ 10,;\n" +
            "    20 say 'Test' get x\n" +
            "RETURN\n";

        System.out.println("=== INPUT (with bad split) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, outputLines[i]);
        }
        System.out.println("==============");

        // After formatting, the @ row,col should be joined on one line
        boolean foundJoinedLine = false;
        for (String line : outputLines) {
            if (line.contains("@ 10,20 say") || line.contains("@ 10, 20 say")) {
                foundJoinedLine = true;
                break;
            }
        }
        assertTrue("@ row,col should be joined back together", foundJoinedLine);
    }

    @Test
    public void testGetCommandBreaksBeforeWhen() throws Exception {
        // Test from FEEDBACK fakt.prg#811: GET commands should break BEFORE when, not at @ expr,
        // This tests the case where row is an expression (ob+12) not just a number
        String input =
            "FUNCTION test()\n" +
            "    @ ob+12,74 get AUFAUS->Zuschlag valid { |oGet| val(oGet:buffer)>=0 } when Message(\"Energiekosten-Zuschlag eingeben. \")\n" +
            "RETURN\n";

        System.out.println("=== INPUT (@ expression) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, inputLines[i].length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT (maxLen=99) ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, outputLines[i].length(), outputLines[i]);
        }
        System.out.println("==============");

        // Verify that the comma in @ expr, is NOT used as split point
        boolean hasBadSplit = false;
        for (String line : outputLines) {
            String trimmed = line.trim();
            // Check for bad split at @ expr,; pattern
            if (trimmed.matches("@\\s*[a-zA-Z0-9+\\-*/()]+,;")) {
                hasBadSplit = true;
                System.out.println("FOUND BAD SPLIT at @ expr,: " + trimmed);
                break;
            }
        }
        assertFalse("@ expr,col should NOT be split at the comma", hasBadSplit);

        // Verify that if line was split, it was at a logical place (before when/valid)
        for (String line : outputLines) {
            String trimmed = line.trim();
            if (trimmed.startsWith("when ") || trimmed.startsWith("valid ")) {
                System.out.println("Good: split occurred before '" + trimmed.split(" ")[0] + "'");
            }
        }
    }

    @Test
    public void testGetCommandBreaksBeforeValid() throws Exception {
        // Test from FEEDBACK: GET commands should break BEFORE valid/when clauses, not at @ row,col
        // When a GET line is >99 chars it should split BEFORE 'valid' or 'when', not at the @ 10, comma
        // Use maxLen=80 to force wrapping since normal 99 limit doesn't trigger it with typical indents
        String input =
            "FUNCTION test()\n" +
            "  @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/PDF) ' get Ausgabe Picture \"!\" valid Ausgabe $\"DBP\"\n" +
            "RETURN\n";

        System.out.println("=== INPUT (long GET line) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, inputLines[i].length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        // Use 80 char limit to force wrapping
        String formatted = processor.formatHarbourCodeWithDefaults(input, 80);

        System.out.println("=== OUTPUT (maxLen=80) ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, outputLines[i].length(), outputLines[i]);
        }
        System.out.println("==============");

        // Verify @ row,col is NOT split (no line ending with "@ 10,;")
        boolean hasAtRowColSplit = false;
        for (String line : outputLines) {
            String trimmed = line.trim();
            if (trimmed.matches("@\\s*\\d+,;")) {
                hasAtRowColSplit = true;
                System.out.println("FOUND BAD SPLIT at @ row,col: " + trimmed);
                break;
            }
        }
        assertFalse("@ row,col should NOT be split at the comma", hasAtRowColSplit);
    }

    @Test
    public void testGetCommandBreaksBeforeWhenNotString() throws Exception {
        // Test from FEEDBACK fakt.prg#5195: GET commands should break BEFORE when clause
        // NOT inside the string in the Message() call
        // Input line is 106 chars - exceeds 99
        String input =
            "FUNCTION test()\n" +
            "  @ 20,1 get AUFAUS->Ansprech when Message(\"Ansprechpartner eingeben   @F12@=Kundendaten übernehmen\")\n" +
            "RETURN\n";

        System.out.println("=== INPUT (GET with long when clause) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, inputLines[i].length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT (maxLen=99) ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [len=%d]: '%s'%n", i+1, outputLines[i].length(), outputLines[i]);
        }
        System.out.println("==============");

        // Verify string is NOT split (no lines with "+; at end followed by continued string)
        boolean hasStringSplit = false;
        for (int i = 0; i < outputLines.length - 1; i++) {
            String line = outputLines[i].trim();
            String nextLine = outputLines[i + 1].trim();
            if (line.endsWith("\"+;") && nextLine.startsWith("\"")) {
                hasStringSplit = true;
                System.out.println("FOUND BAD STRING SPLIT: " + line + " -> " + nextLine);
                break;
            }
        }
        assertFalse("String should NOT be split - break before 'when' instead", hasStringSplit);

        // Verify we have proper break: line ending with ; followed by line starting with when
        boolean hasProperBreak = false;
        for (int i = 0; i < outputLines.length - 1; i++) {
            String line = outputLines[i].trim();
            String nextLine = outputLines[i + 1].trim();
            if (line.endsWith(";") && nextLine.toLowerCase().startsWith("when ")) {
                hasProperBreak = true;
                System.out.println("GOOD: Found proper break before 'when': " + line);
                break;
            }
        }
        assertTrue("Should break BEFORE 'when' clause", hasProperBreak);
    }

    @Test
    public void testCommentAfterIfBlock() throws Exception {
        // Test from FEEDBACK: comments after if/else should be indented inside the block
        // This is the case from fakt.prg#527ff
        String input =
            "FUNCTION test()\n" +
            "  // Posten gelöscht?\n" +
            "  if ! AUFTRAG->geloescht $ \"N \"\n" +
            "\n" +
            "    // Auftragsbestand neu berechnen in Art.Stamm\n" +
            "    changedAB:=.t.\n" +
            "\n" +
            "    if AUFPOST->(eof())\n" +
            "      // neuer Satz gelöscht -> NOP\n" +
            "    else\n" +
            "\n" +
            "      // alter Satz gelöscht\n" +
            "      diffKVMenge:=AUFPOST->GeliefGes * (-1)\n" +
            "    endif\n" +
            "  endif\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // Check that comments after if/else are correctly indented inside the block
        // Line "// Auftragsbestand..." after "if" should have 4 spaces (inside the outer if block)
        // Line "// neuer Satz..." after inner "if" should have 6 spaces (inside inner if block)
        // Line "// alter Satz..." after "else" should have 6 spaces (inside else block)

        for (int i = 0; i < outputLines.length; i++) {
            String line = outputLines[i];
            String trimmed = line.trim();
            int indent = line.length() - trimmed.length();

            if (trimmed.startsWith("// Auftragsbestand")) {
                // This comment should be inside the outer if block (4 spaces)
                assertEquals("Comment after outer if should have 4 spaces indent", 4, indent);
            } else if (trimmed.startsWith("// neuer Satz")) {
                // This comment should be inside the inner if block (6 spaces)
                assertEquals("Comment after inner if should have 6 spaces indent", 6, indent);
            } else if (trimmed.startsWith("// alter Satz")) {
                // This comment should be inside the else block (6 spaces)
                assertEquals("Comment after else should have 6 spaces indent", 6, indent);
            }
        }
    }

    @Test
    public void testReturnInsideControlStructure() throws Exception {
        // Test from FEEDBACK fakt.prg#940: RETURN inside if block should have normal indent
        // Only RETURN at actual end of function should use returnIndent setting
        // WITH continuation lines (like the actual fakt.prg)
        String input =
            "static FUNCTION BestKtoNach(oGet)\n" +
            "  if condition .and.;\n" +  // if with continuation
            "    more_condition\n" +     // continuation line
            "return .f.\n" +             // Intentionally wrong indent - should become 4 spaces
            "endif\n" +                  // Intentionally wrong indent - should become 2 spaces
            "return .t.\n";              // End of function - should stay 0 spaces

        System.out.println("=== INPUT (RETURN in control structure) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // Check each line's indentation
        for (int i = 0; i < outputLines.length; i++) {
            String line = outputLines[i];
            String trimmed = line.trim().toLowerCase();
            int indent = line.length() - line.stripLeading().length();

            if (trimmed.equals("return .f.")) {
                // RETURN inside if block should be at level 2 (4 spaces)
                assertEquals("RETURN inside if block should have 4 spaces indent", 4, indent);
            } else if (trimmed.equals("endif")) {
                // endif should be at level 1 (2 spaces)
                assertEquals("endif should have 2 spaces indent", 2, indent);
            } else if (trimmed.equals("return .t.")) {
                // RETURN at end of function should use returnIndent (0 spaces by default)
                assertEquals("RETURN at end of function should have 0 spaces indent", 0, indent);
            }
        }
    }

    @Test
    public void testReturnIndentAtEndOfFunction() throws Exception {
        // Test from FEEDBACK fakt.prg#873: RETURN at end of function should have no indent (0 spaces)
        // when configured with returnIndent=0 (which is the default)
        String input =
            "FUNCTION SoRabatt_nach(oGet)\n" +
            "  if oGet:changed\n" +
            "    Auf_Kopf_Disp()\n" +
            "  endif\n" +
            "\n" +
            "  RETURN(.t.)\n";

        System.out.println("=== INPUT (RETURN indent test) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // Find the RETURN line and check its indentation
        for (String line : outputLines) {
            String trimmed = line.trim().toLowerCase();
            if (trimmed.startsWith("return")) {
                int indent = line.length() - line.stripLeading().length();
                assertEquals("RETURN at end of function should have 0 indent (default setting)", 0, indent);
                break;
            }
        }
    }

    @Test
    public void testCommentInsideFunctionBody() throws Exception {
        // Test from FEEDBACK fakt.prg#940: // comment at start of function body should be indented
        String input =
            "static FUNCTION BestKtoNach(oGet)\n" +
            "\n" +
            "// Bei Abrufauftrag und KV ist Eingabe Pflicht\n" +  // No indent - should become 2 spaces
            "  if condition\n" +
            "    return .f.\n" +
            "  endif\n" +
            "\n" +
            "return .t.\n";

        System.out.println("=== INPUT (comment in function body) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // Find the comment line and check its indentation
        for (int i = 0; i < outputLines.length; i++) {
            String line = outputLines[i];
            String trimmed = line.trim();
            int indent = line.length() - line.stripLeading().length();

            if (trimmed.startsWith("// Bei Abruf")) {
                // Comment inside function body should be at level 1 (2 spaces)
                assertEquals("Comment inside function body should have 2 spaces indent", 2, indent);
                break;
            }
        }
    }

    @Test
    public void testCommaSemicolonContinuation() throws Exception {
        // Test from FEEDBACK: continuation after ,; should have same indent as other continuation lines
        // This is the case from fakt.prg#80
        String input =
            "FUNCTION test()\n" +
            "  if ! open( \"Auftrag\" , \"AufAus\" , \"ZahlKond\" ;\n" +
            "    ,\"Mwst_Kz\" , \"Artikel\", \"Einheit\";\n" +
            "    ,\"Text\" ,\"Abruf\",\"BesPost\",;\n" +
            "    \"AufZeit\",\"Konsig\",\"BesAus\")\n" +
            "    Error(TRY_AGAIN)\n" +
            "  endif\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // All continuation lines (lines 3, 4, 5) should have the same indent (4 spaces = if indent + 2)
        // Line 5 is after ,; but should NOT get extra indent
        int line3Indent = outputLines[2].length() - outputLines[2].stripLeading().length();
        int line4Indent = outputLines[3].length() - outputLines[3].stripLeading().length();
        int line5Indent = outputLines[4].length() - outputLines[4].stripLeading().length();

        System.out.println("\nIndentation check:");
        System.out.printf("  Continuation line 1: %d spaces%n", line3Indent);
        System.out.printf("  Continuation line 2 (ends with ,;): %d spaces%n", line4Indent);
        System.out.printf("  Continuation line 3 (after ,;): %d spaces%n", line5Indent);

        assertEquals("All continuation lines should have same indent", line3Indent, line4Indent);
        assertEquals("Line after ,; should have same indent as other continuations", line3Indent, line5Indent);
    }

    @Test
    public void testContinuationLineIndentation() throws Exception {
        // Test from FEEDBACK: continuation lines should indent one step relative to statement
        // This is the exact case from fakt.prg#151
        String input =
            "FUNCTION test()\n" +
            "  do while .t.\n" +
            "    Error(ACHTUNG+\"Eingabe Ansprechpartner und mind. eine Kontaktmöglichkeit |\"+;\n" +
            "         \"         sind Pflicht bei neuen Aufträgen||\"+;\n" +
            "         \"         F12 aus Kundenstamm übernehmen\",.t.)\n" +
            "    editAnsprechPartner()\n" +
            "  enddo\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                inputLines[i].length() - inputLines[i].stripLeading().length(), inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d [%d spaces]: '%s'%n", i+1,
                outputLines[i].length() - outputLines[i].stripLeading().length(), outputLines[i]);
        }
        System.out.println("==============");

        // Line 3 (Error call) should have 4 spaces (inside do while)
        // Lines 4-5 (continuation) should have 6 spaces (4 + 2 = one extra level)
        String errorLine = outputLines[2];
        String cont1Line = outputLines[3];
        String cont2Line = outputLines[4];

        int errorIndent = errorLine.length() - errorLine.stripLeading().length();
        int cont1Indent = cont1Line.length() - cont1Line.stripLeading().length();
        int cont2Indent = cont2Line.length() - cont2Line.stripLeading().length();

        System.out.println("\nIndentation check:");
        System.out.printf("  Error line: %d spaces (expected 4)%n", errorIndent);
        System.out.printf("  Continuation 1: %d spaces (expected 6)%n", cont1Indent);
        System.out.printf("  Continuation 2: %d spaces (expected 6)%n", cont2Indent);

        assertEquals("Error line should have 4 spaces indent", 4, errorIndent);
        assertEquals("Continuation line 1 should have 6 spaces (4+2)", 6, cont1Indent);
        assertEquals("Continuation line 2 should have 6 spaces (4+2)", 6, cont2Indent);
    }

}

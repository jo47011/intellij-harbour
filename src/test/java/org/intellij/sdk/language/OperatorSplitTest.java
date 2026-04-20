package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Tests for ensuring operators like .and., .or., and -> are not split during line breaking.
 */
public class OperatorSplitTest {

    /**
     * Test that .and. operator is not split when line is broken at the 99 char limit.
     * Regression test for etikett.prg issue where ".and." became ".and;" + ". autoF12()"
     */
    @Test
    public void testAndOperatorNotSplit() {
        // Line that ends with .and. right at the limit
        String input = "      ( Message(\"Bitte Artikel-Nummer eingeben.                 @F8@=Ansicht    @F12@=Hilfe\") .and. autoF12() )";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // Should not have .and; (split .and.)
        assertFalse("Should not split .and. operator", formatted.contains(".and;"));
        // Should not have line starting with . (orphaned dot)
        assertFalse("Should not have orphaned dot at line start", formatted.contains("\n      . "));
    }

    /**
     * Test that .or. operator is not split when line is broken at the limit.
     */
    @Test
    public void testOrOperatorNotSplit() {
        // Line with .or. near the limit
        String input = "      if someCondition(param1, param2, param3, param4, param5, param6, param7) .or. anotherCondition()";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // Should not have .or; (split .or.)
        assertFalse("Should not split .or. operator", formatted.contains(".or;"));
    }

    /**
     * Test that .not. operator is not split.
     */
    @Test
    public void testNotOperatorNotSplit() {
        String input = "      if someLongFunctionName(parameter1, parameter2, parameter3, parameter4) .and. .not. empty(x)";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // Should not have .not; (split .not.)
        assertFalse("Should not split .not. operator", formatted.contains(".not;"));
    }

    /**
     * Test that -> accessor operator is not split when line is broken.
     * Regression test for faktdruc.prg issue where "LIEFAUS->Land" became "LIEFAUS-" + ">Land"
     */
    @Test
    public void testArrowOperatorNotSplit() {
        // Line with -> near the limit that would cause split
        String input = "    adresse:=getAdrBlock(LIEFAUS->Name,LIEFAUS->Partner,LIEFAUS->Strasse,LIEFAUS->Zusatz, LIEFAUS->Land,LIEFAUS->Plz,LIEFAUS->Ort)";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // Should not have line ending with - followed by line starting with >
        String[] lines = formatted.split("\n");
        for (int i = 0; i < lines.length - 1; i++) {
            if (lines[i].endsWith("-") && lines[i+1].trim().startsWith(">")) {
                fail("Arrow operator -> was split at line " + (i+1) + ": '" + lines[i] + "' / '" + lines[i+1] + "'");
            }
        }

        // Also check for -; followed by > on next line
        assertFalse("Should not have -; at end of line (split ->)", formatted.contains("-;\n") && formatted.contains("\n      >"));
    }

    /**
     * Test that multiple -> accessors in a function call are all preserved.
     */
    @Test
    public void testMultipleArrowOperatorsPreserved() {
        String input = "    result:=process(TABLE1->Field1, TABLE2->Field2, TABLE3->Field3, TABLE4->Field4, TABLE5->Field5)";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // All -> operators should be preserved (not split)
        // Count occurrences of ->
        int arrowCount = 0;
        int pos = 0;
        while ((pos = formatted.indexOf("->", pos)) >= 0) {
            arrowCount++;
            pos += 2;
        }
        assertEquals("All 5 arrow operators should be preserved", 5, arrowCount);
    }

    /**
     * Test that .t. and .f. boolean literals are not split.
     */
    @Test
    public void testBooleanLiteralsNotSplit() {
        String input = "    result:=someFunction(param1, param2, param3, param4, param5, param6, .t., .f., .true., .false.)";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // Boolean literals should not be split
        assertFalse("Should not split .t.", formatted.contains(".t;"));
        assertFalse("Should not split .f.", formatted.contains(".f;"));
        assertFalse("Should not split .true.", formatted.contains(".true;"));
        assertFalse("Should not split .false.", formatted.contains(".false;"));
    }

    /**
     * Test long GET command with .and. in when clause.
     * This is the actual pattern from etikett.prg that was failing.
     */
    @Test
    public void testGetCommandWithAndInWhenClause() {
        String input = "    @  6,18 say \"Art.Nr...:\" get RepArtikel valid { |oGet| check(oGet,\"Artikel\",.f.,.f.) } when ( Message(\"Bitte Artikel-Nummer eingeben.                 @F8@=Ansicht    @F12@=Hilfe\") .and. autoF12() )";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input + "\n", 99);

        // The .and. should remain intact
        assertFalse("Should not split .and. in GET command", formatted.contains(".and;"));

        // All lines should be <= 99 chars
        for (String line : formatted.split("\n")) {
            assertTrue("Line should be <= 99 chars: " + line.length() + " chars", line.length() <= 99);
        }

        // Idempotency: formatting the output again must produce the same result
        String prev = formatted;
        for (int pass = 2; pass <= 5; pass++) {
            String reformatted = processor.formatHarbourCodeWithDefaults(prev, 99);
            // Debug: show each pass
            if (!prev.equals(reformatted)) {
                System.out.println("=== PASS " + pass + " DIFFERS ===");
                System.out.println("IN:");
                for (String l : prev.split("\n"))
                    System.out.printf("  (%3d) |%s|%n", l.length(), l);
                System.out.println("OUT:");
                for (String l : reformatted.split("\n"))
                    System.out.printf("  (%3d) |%s|%n", l.length(), l);
            }
            assertEquals("Pass " + pass + " must be identical to previous pass", prev, reformatted);
            prev = reformatted;
        }
    }
}

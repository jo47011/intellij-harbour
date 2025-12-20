package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Tests for Harbour scope detection logic.
 * Tests the algorithm for finding procedure/function boundaries.
 */
public class HarbourScopeUtilsTest {

    /**
     * Test scope detection with multiple RETURN statements.
     * This was a bug fix - scope should NOT stop at RETURN.
     */
    @Test
    public void testMultipleReturnsInProcedure() {
        String code =
            "FUNCTION TestFunc()\n" +       // line 0
            "LOCAL lResult\n" +              // line 1
            "   IF lResult\n" +              // line 2
            "      RETURN .T.\n" +           // line 3 - first RETURN
            "   ENDIF\n" +                   // line 4
            "   lResult := DoSomething()\n" + // line 5
            "RETURN lResult\n" +             // line 6 - second RETURN
            "\n" +                           // line 7
            "FUNCTION NextFunc()\n" +        // line 8 - next function
            "RETURN NIL\n";                  // line 9

        int[] scope = findScopeForLine(code, 5); // line 5 is inside TestFunc

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0", 0, scope[0]);
        assertEquals("Scope should end at line 7 (before NextFunc)", 7, scope[1]);
    }

    /**
     * Test scope detection for STATIC PROCEDURE.
     */
    @Test
    public void testStaticProcedureScope() {
        String code =
            "STATIC PROCEDURE Helper()\n" +  // line 0
            "LOCAL cVar\n" +                 // line 1
            "   cVar := \"test\"\n" +        // line 2
            "RETURN\n" +                     // line 3
            "\n" +                           // line 4
            "FUNCTION Main()\n" +            // line 5
            "RETURN\n";                      // line 6

        int[] scope = findScopeForLine(code, 2); // line 2 is inside Helper

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0 (STATIC PROCEDURE)", 0, scope[0]);
        assertEquals("Scope should end at line 4", 4, scope[1]);
    }

    /**
     * Test scope detection for STATIC FUNCTION.
     */
    @Test
    public void testStaticFunctionScope() {
        String code =
            "STATIC FUNCTION Calculate(n)\n" + // line 0
            "LOCAL nResult\n" +                // line 1
            "   nResult := n * 2\n" +          // line 2
            "RETURN nResult\n" +               // line 3
            "\n" +                             // line 4
            "PROCEDURE Init()\n" +             // line 5
            "RETURN\n";                        // line 6

        int[] scope = findScopeForLine(code, 1);

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0 (STATIC FUNCTION)", 0, scope[0]);
        assertEquals("Scope should end at line 4", 4, scope[1]);
    }

    /**
     * Test scope detection for METHOD.
     */
    @Test
    public void testMethodScope() {
        String code =
            "METHOD New() CLASS TMyClass\n" + // line 0
            "   ::cName := \"\"\n" +          // line 1
            "RETURN Self\n" +                 // line 2
            "\n" +                            // line 3
            "METHOD Init() CLASS TMyClass\n" + // line 4
            "RETURN Self\n";                  // line 5

        int[] scope = findScopeForLine(code, 1);

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0 (METHOD)", 0, scope[0]);
        assertEquals("Scope should end at line 3", 3, scope[1]);
    }

    /**
     * Test scope detection stops at EOP (End Of Procedure) comment marker.
     */
    @Test
    public void testEOPCommentStopsScope() {
        String code =
            "FUNCTION Main()\n" +             // line 0
            "LOCAL cVar\n" +                  // line 1
            "   cVar := \"test\"\n" +         // line 2
            "RETURN\n" +                      // line 3
            "/* EOP */\n";                    // line 4

        int[] scope = findScopeForLine(code, 2);

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0", 0, scope[0]);
        assertEquals("Scope should end at line 3 (before EOP)", 3, scope[1]);
    }

    /**
     * Test element not in any procedure.
     */
    @Test
    public void testElementOutsideProcedure() {
        String code =
            "#include \"common.ch\"\n" +      // line 0
            "MEMVAR cPublicVar\n" +           // line 1
            "\n" +                            // line 2
            "FUNCTION Main()\n" +             // line 3
            "RETURN\n";                       // line 4

        int[] scope = findScopeForLine(code, 1); // line 1 is before any procedure

        assertNull("No scope should be found for code before first procedure", scope);
    }

    /**
     * Test deeply nested code still finds correct scope.
     */
    @Test
    public void testDeeplyNestedCode() {
        String code =
            "FUNCTION ProcessData()\n" +      // line 0
            "LOCAL i, j, k\n" +               // line 1
            "   FOR i := 1 TO 10\n" +         // line 2
            "      FOR j := 1 TO 10\n" +      // line 3
            "         IF i > 5\n" +           // line 4
            "            DO WHILE k < 100\n" + // line 5
            "               k++\n" +          // line 6 - deeply nested
            "            ENDDO\n" +           // line 7
            "         ENDIF\n" +              // line 8
            "      NEXT\n" +                  // line 9
            "   NEXT\n" +                     // line 10
            "RETURN k\n" +                    // line 11
            "\n" +                            // line 12
            "FUNCTION Other()\n" +            // line 13
            "RETURN\n";                       // line 14

        int[] scope = findScopeForLine(code, 6); // deeply nested line

        assertNotNull("Scope should be found", scope);
        assertEquals("Scope should start at line 0", 0, scope[0]);
        assertEquals("Scope should end at line 12", 12, scope[1]);
    }

    /**
     * Helper method that replicates the scope detection algorithm
     * from HarbourScopeUtils but works with plain text for testing.
     */
    private int[] findScopeForLine(String code, int lineNumber) {
        String[] lines = code.split("\n");

        // Find the start line (procedure/function declaration)
        int startLine = -1;
        for (int i = lineNumber; i >= 0; i--) {
            String line = i < lines.length ? lines[i].toUpperCase().trim() : "";
            if (line.startsWith("PROCEDURE ") || line.startsWith("FUNCTION ") ||
                    line.startsWith("STATIC PROCEDURE ") || line.startsWith("STATIC FUNCTION ") ||
                    line.startsWith("METHOD ")) {
                startLine = i;
                break;
            }
        }

        if (startLine == -1) {
            return null; // Not in a procedure/function
        }

        // Find the end line (next procedure/function declaration or end of file)
        // NOTE: Do NOT stop at RETURN - Harbour procedures can have multiple RETURN statements
        int endLine = lines.length - 1;
        for (int i = startLine + 1; i < lines.length; i++) {
            String line = lines[i].toUpperCase().trim();
            if (line.startsWith("PROCEDURE ") || line.startsWith("FUNCTION ") ||
                    line.startsWith("STATIC PROCEDURE ") || line.startsWith("STATIC FUNCTION ") ||
                    line.startsWith("METHOD ") || line.startsWith("/* EOP */")) {
                endLine = i - 1;
                break;
            }
        }

        return new int[] { startLine, endLine };
    }
}

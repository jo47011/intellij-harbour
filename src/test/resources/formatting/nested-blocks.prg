/*
 * Nested blocks test for Harbour formatter
 * Tests indentation of deeply nested if/do/for
 */

FUNCTION TestNestedBlocks()
LOCAL i, j, k, lFound

   lFound := .F.

   FOR i := 1 TO 10
      FOR j := 1 TO 10
         IF i > 5
            DO WHILE k < 100
               IF j > 5 .AND. i > 7
                  lFound := .T.
                  EXIT
               ENDIF
               k++
            ENDDO
         ELSE
            DO CASE
               CASE i == 1
                  ? "One"
               CASE i == 2
                  ? "Two"
               OTHERWISE
                  ? "Other"
            ENDCASE
         ENDIF
      NEXT j
   NEXT i

RETURN lFound

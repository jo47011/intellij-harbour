/*
 * Long lines test for Harbour formatter
 * Tests line wrapping at 99 chars
 */

FUNCTION TestLongLines()
LOCAL cLongString, nResult, lCondition

   // This line is intentionally long and should be wrapped by the formatter if enabled
   cLongString := "This is a very long string that exceeds the normal line length limit and should trigger line wrapping in the formatter"

   // Long condition with .and. .or.
   lCondition := nResult > 100 .AND. cLongString != NIL .OR. lCondition == .T. .AND. nResult < 999

   // Long function call
   nResult := MyVeryLongFunctionName(cLongString, nResult, lCondition, "extra param", 12345)

RETURN nResult


FUNCTION MyVeryLongFunctionName(p1, p2, p3, p4, p5)
RETURN p2 + p5

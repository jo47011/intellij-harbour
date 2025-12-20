/*
 * Simple function test for Harbour formatter
 * Tests basic function structure formatting
 */

FUNCTION TestSimple()
LOCAL cVar, nNum, lFlag

   cVar := "Hello World"
   nNum := 42
   lFlag := .T.

   IF lFlag
      ? cVar
   ENDIF

RETURN nNum


PROCEDURE TestProc()
LOCAL aArray

   aArray := {1, 2, 3}
   AEval(aArray, {|x| QOut(x)})

RETURN

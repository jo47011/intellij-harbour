/*
 * Code block wrapping test for Harbour formatter
 * Tests that code blocks {|| ...} are not split between { and |params|
 */

FUNCTION TestCodeBlocks()
LOCAL aSpalte, bResult, aData, bBlock

   // Short code block - should NOT be wrapped (fits in 99 chars)
   bBlock := {|| .T.}
   bResult := {|x| x > 0}

   // Long code block assignment with .and. operators - should wrap at .and. not after {
   aSpalte := {|oGet| val(oGet:buffer) >= 0 .and. rabatt_nach(oGet) .and. SetMyKey(asc("r"), NIL)}

   // Code block with .or. operator
   bResult := {|x| x > 100 .or. x < -100 .or. SomeFunction(x) .or. AnotherFunction(x, 42, "test")}

   // Array assignment (not a code block) - should still wrap normally at commas
   aData := {"first value", "second value", "third value", "fourth value", "fifth value", "sixth"}

RETURN NIL

/*
 * Operator test for Harbour formatter
 * Tests all operator types: .and. .or. -> :: etc.
 */

FUNCTION TestOperators()
LOCAL oObj, aData, lResult, cField

   // Logical operators
   lResult := .T. .AND. .F.
   lResult := .T. .OR. .F.
   lResult := .NOT. lResult

   // Send operator (method call)
   oObj := TMyClass():New()
   oObj:DoSomething()

   // Alias operator
   cField := CUSTOMER->NAME
   aData := {ORDERS->TOTAL, ORDERS->DATE}

   // Array access
   aData[1] := 100
   aData[2] := Date()

   // Increment/decrement
   lResult := ++aData[1]
   lResult := aData[1]++

RETURN lResult


CLASS TMyClass
   DATA cName INIT ""
   METHOD New() INLINE Self
   METHOD DoSomething() INLINE ::cName := "Test"
ENDCLASS

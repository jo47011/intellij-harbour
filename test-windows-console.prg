// test-windows-console.prg - Test case 4: Windows console debugging

PROCEDURE Main()
    LOCAL nCounter := 0
    LOCAL cMessage := "Windows console test"
    
    ? "Starting Windows console debugging test..."
    ? cMessage
    
    FOR nCounter := 1 TO 3
        ? "Counter:", nCounter
        IF nCounter == 2
            ? "This should appear in PyCharm console, not separate window!"
        ENDIF
    NEXT
    
    ? "Windows console test completed."
    ? "If you see this in PyCharm console (not separate window), the fix worked!"
RETURN
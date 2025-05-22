// Harbour minimal debug hook for console output
// Place in debug_hook.prg

#include "hbdebug.ch"

PROCEDURE Main()
   LOCAL i := 0
   
   // Start-up message to verify console is working
   QOut("Harbour program started with console debug")
   
   // Initialize debugger
   AltD(2) // Install debugger
   AltD()  // Activate debugger
   __dbgSetCBTrace({|file, line, func| QOut("DEBUG: Break at " + file + ":" + AllTrim(Str(line)))})
   
   // Continue with normal execution
   QOut("Beginning execution...")
   
   // Sample calculation to test debugger
   FOR i := 1 TO 5
      QOut("Counter: " + AllTrim(Str(i)))
   NEXT
   
   QOut("Program completed.")
RETURN
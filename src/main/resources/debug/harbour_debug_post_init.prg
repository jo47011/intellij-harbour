// Post-initialization debug hook - no __dbgEntry function at all
// Try to register debug callback after VM is fully initialized

#include <hbdebug.ch>

// No __dbgEntry function - this might be the issue

// Function to manually register debugger after program starts
FUNCTION RegisterDebugger()
   ? "Attempting to register debugger after initialization..."
   
   // Try to register ourselves as the debug handler
   __dbgSetEntry()
   Set( _SET_DEBUG, .T. )
   
   ? "Debug registration attempted"
RETURN .T.

// Test function
FUNCTION TestPostInit()
   ? "Post-init debug test"
RETURN .T.

// Manual debug entry that we'll register ourselves
PROCEDURE MyDebugEntry(nMode, uParam1, uParam2, uParam3)
   ? "Debug mode:", nMode
   IF uParam1 != NIL
      ? "Param1:", uParam1
   ENDIF
RETURN
// IntelliJ Harbour GUI Debug Handler - Minimal Version
// Activates standard Harbour debugger for GUI programs
// Automatically loads init.cld breakpoints

#pragma -B-

// Minimal debug handler to activate standard Harbour debugger for GUI programs
INIT PROCEDURE __InitHarbourGUIDebugger()
   // Enable debug mode for GUI programs
   Set( _SET_DEBUG, .T. )
   
   // Register our minimal debug entry point with VM
   __dbgSetEntry()
RETURN

// Minimal debug entry point that only handles registration
// All other events fall through to standard Harbour debugger
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   // Only handle the registration request
   IF nMode == 6  // HB_DBG_GETENTRY - register with VM
      __dbgSetEntry()
   ENDIF
   
   // Do NOT handle any other events - let standard debugger handle them
   // This allows the standard Harbour debugger to take over completely
RETURN

// Override AltD() to activate standard Harbour debugger
FUNCTION AltD()
   LOCAL lWasActive := Set( _SET_DEBUG )
   
   // Enable debug mode if not already active
   IF !lWasActive
      Set( _SET_DEBUG, .T. )
      __dbgSetEntry()
   ENDIF
   
   // Call the standard AltD() to trigger debugger break
   __dbgInvoke()
   
RETURN NIL
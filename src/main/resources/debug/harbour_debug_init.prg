// IntelliJ Harbour Debug Initialization
// Enables debug mode for standard Harbour debugger
// Used for GUI programs with -lhbdebug

#pragma -B-

// Initialize debug mode for standard Harbour debugger
INIT PROCEDURE __InitHarbourDebugMode()
   // Enable debug mode to activate standard Harbour debugger
   Set( _SET_DEBUG, .T. )
   
   // Force debugger activation at program start
   // This should trigger the standard debugger to load init.cld automatically
   __dbgInvokeDebug( .T. )
RETURN
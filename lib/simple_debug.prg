// Simple debug library - array-based to avoid hash initialization issues
// Version 1.2.27

// Static debug info storage - ultra-safe version
STATIC FUNCTION __DEBUGITEM(xValue)
   STATIC s_oDebugInfo := NIL
   
   // Ultra-safe: only set if parameter provided
   IF PCount() > 0
      s_oDebugInfo := xValue
   ENDIF
   
RETURN s_oDebugInfo

// Initialize debugger when it's safe to do so
FUNCTION __InitIntelliJDebugger()
   LOCAL oDebugInfo
   
   // Create simple array instead of hash to avoid initialization issues
   oDebugInfo := Array(20)
   oDebugInfo[1] := NIL       // socket
   oDebugInfo[2] := .F.       // lRunning
   oDebugInfo[3] := .F.       // lInternalRun 
   oDebugInfo[4] := {}        // aBreaks
   oDebugInfo[5] := {}        // aStack
   oDebugInfo[6] := {}        // aModules
   oDebugInfo[7] := NIL       // maxLevel
   oDebugInfo[8] := 0         // __dbgEntryLevel
   oDebugInfo[9] := 0         // timeCheckForDebug
   oDebugInfo[10] := .T.      // lInitialized
   
   // Store it
   __DEBUGITEM(oDebugInfo)
   
   // Mark as initialized
   ? "IntelliJ Harbour Debugger initializing (simple array mode)..."
   
RETURN .T.

// Main debug entry point - called by Harbour VM
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   LOCAL oDebugInfo
   
   // Just return immediately if debug system isn't initialized
   oDebugInfo := __DEBUGITEM()
   IF oDebugInfo == NIL
      RETURN  // Not initialized yet - completely ignore all events
   ENDIF
   
   // For now, just do nothing but don't crash
   // This proves the static library concept works
   
RETURN

// Test function to manually initialize
PROCEDURE TestInit()
   ? "Calling __InitIntelliJDebugger..."
   __InitIntelliJDebugger()
   ? "Initialization complete"
RETURN
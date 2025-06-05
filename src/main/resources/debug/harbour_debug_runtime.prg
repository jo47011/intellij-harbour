// IntelliJ Harbour Debug Library - Runtime Version 1.2.28
// Registers debugger after program starts to avoid VM initialization conflicts
#pragma -B-

// Force console mode to prevent ANSI escape sequences
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 9876  // IntelliJ debug server port
#endif

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <hboo.ch>
#include <fileio.ch>

#ifndef HB_DBG_MODULENAME
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#define HB_DBG_ENDPROC        4
#define HB_DBG_SHOWLINE       5
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_VMQUIT         8
#endif

#define CRLF Chr(13)+Chr(10)

// Global debug state - simple and safe
STATIC s_lDebuggerRegistered := .F.
STATIC s_oDebugInfo := NIL

// Main debug entry point - called by Harbour VM
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   // Handle VM registration
   IF nMode == HB_DBG_GETENTRY
      __dbgSetEntry()  // Register with VM to receive debug events
      s_lDebuggerRegistered := .T.
      RETURN
   ENDIF
   
   // Initialize debug info on first HB_DBG_MODULENAME event
   IF s_oDebugInfo == NIL .AND. nMode == HB_DBG_MODULENAME
      s_oDebugInfo := Array(10)
      s_oDebugInfo[1] := {}     // aStack
      s_oDebugInfo[2] := {}     // aModules
      s_oDebugInfo[3] := 0      // __dbgEntryLevel
      s_oDebugInfo[4] := .T.    // lInitialized
      ? "=== Debug info initialized on HB_DBG_MODULENAME (array mode) ==="
   ENDIF
   
   // Process debug events only if initialized
   IF s_oDebugInfo != NIL
      DO CASE
      CASE nMode == HB_DBG_MODULENAME  // Mode 1 - Module/Function info
         HandleModuleName(uParam1)
         
      CASE nMode == HB_DBG_LOCALNAME   // Mode 2 - Local variable name
         HandleLocalName(uParam1, uParam2)
         
      CASE nMode == HB_DBG_STATICNAME  // Mode 3 - Static variable name
         HandleStaticName(uParam1, uParam2, uParam3)
         
      OTHERWISE
         // Ignore other modes for now
      ENDCASE
   ENDIF
RETURN

// Initialize debug info when called manually
FUNCTION __InitIntelliJDebugger()
   ? "Manual debugger initialization called"
   
   // Create simple debug info structure
   s_oDebugInfo := { ;
      "socket" => NIL, ;
      "lRunning" => .F., ;
      "aStack" => {}, ;
      "aBreaks" => {}, ;
      "lInitialized" => .T. ;
   }
   
RETURN .T.

// Handle HB_DBG_MODULENAME events
STATIC PROCEDURE HandleModuleName(cModuleFunc)
   LOCAL aStack := s_oDebugInfo[1]  // aStack is at index 1
   LOCAL aFrame, i
   
   ? "Module/Function:", cModuleFunc
   
   // Create new stack frame
   aFrame := Array(6)  // Simple array structure
   aFrame[1] := cModuleFunc    // Module:Function
   aFrame[2] := ProcLine(1)    // Line
   aFrame[3] := __dbgProcLevel()-1  // Level
   aFrame[4] := {}             // Locals array
   aFrame[5] := {}             // Statics array
   aFrame[6] := Time()         // Timestamp
   
   AAdd(aStack, aFrame)
RETURN

// Handle HB_DBG_LOCALNAME events  
STATIC PROCEDURE HandleLocalName(cVarName, nIndex)
   LOCAL aStack := s_oDebugInfo[1]  // aStack is at index 1
   LOCAL aLocals
   
   IF Len(aStack) > 0
      aLocals := ATail(aStack)[4]
      AAdd(aLocals, {cVarName, nIndex, "L", __dbgProcLevel()-1})
      ? "Local variable:", cVarName, "index:", nIndex
   ENDIF
RETURN

// Handle HB_DBG_STATICNAME events
STATIC PROCEDURE HandleStaticName(nModuleIndex, nVarIndex, cVarName)
   LOCAL aStack := s_oDebugInfo[1]  // aStack is at index 1
   LOCAL aStatics
   
   IF Len(aStack) > 0
      aStatics := ATail(aStack)[5]
      AAdd(aStatics, {cVarName, nVarIndex, "S", nModuleIndex})
      ? "Static variable:", cVarName, "module:", nModuleIndex, "index:", nVarIndex
   ENDIF
RETURN

// Test function to verify the debugger is working
FUNCTION TestDebugger()
   ? "TestDebugger called"
   IF s_oDebugInfo != NIL
      ? "Debug info is initialized"
      ? "Stack frames:", Len(s_oDebugInfo[1])  // aStack is at index 1
   ELSE
      ? "Debug info is NOT initialized"
   ENDIF
RETURN .T.
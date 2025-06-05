// IntelliJ Harbour Debug Library - Final Working Version 1.2.30
// Implements proper debug registration like VSCode debugger

#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 9876
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

#ifndef HB_DBG_CS_MODULE
#define HB_DBG_CS_MODULE      1
#define HB_DBG_CS_FUNCTION    2
#define HB_DBG_CS_LINE        3
#define HB_DBG_CS_LEVEL       4
#define HB_DBG_CS_LOCALS      5
#define HB_DBG_CS_STATICS     6
#endif

#define CRLF Chr(13)+Chr(10)

// Global debug state
STATIC s_aDebugInfo := NIL
STATIC s_nLogHandle := -1

// Main debug entry point - called by Harbour VM
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   // Log all debug events to file
   LogDebugEvent(nMode, uParam1, uParam2, uParam3)
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // This is the key! VM is asking us to register
      ? "=== HB_DBG_GETENTRY received - registering debugger ==="
      __dbgSetEntry()
      ? "Debug handler registered successfully"
      
   CASE nMode == HB_DBG_MODULENAME
      ? "HB_DBG_MODULENAME:", uParam1
      HandleModuleName(uParam1)
      
   CASE nMode == HB_DBG_LOCALNAME  
      ? "HB_DBG_LOCALNAME:", uParam1, "index:", uParam2
      HandleLocalName(uParam1, uParam2)
      
   CASE nMode == HB_DBG_STATICNAME
      ? "HB_DBG_STATICNAME:", uParam3, "module:", uParam1, "index:", uParam2
      HandleStaticName(uParam1, uParam2, uParam3)
      
   CASE nMode == HB_DBG_ACTIVATE
      ? "HB_DBG_ACTIVATE - line debugging"
      
   CASE nMode == HB_DBG_SHOWLINE
      ? "HB_DBG_SHOWLINE"
      
   OTHERWISE
      ? "Other debug mode:", nMode
   ENDCASE
RETURN

// Log debug events to file for analysis
STATIC PROCEDURE LogDebugEvent(nMode, uParam1, uParam2, uParam3)
   // Open log file on first call
   IF s_nLogHandle == -1
      s_nLogHandle := FCreate("/home/developer/workspace/debug_events_final.log", FC_NORMAL)
      IF s_nLogHandle >= 0
         FWrite(s_nLogHandle, "=== IntelliJ Debug Events Log ===" + CRLF)
      ENDIF
   ENDIF
   
   // Log the event
   IF s_nLogHandle >= 0
      FWrite(s_nLogHandle, Time() + " Mode: " + Str(nMode))
      
      IF nMode == HB_DBG_MODULENAME .AND. uParam1 != NIL
         FWrite(s_nLogHandle, " Module: " + hb_CStr(uParam1))
      ELSEIF nMode == HB_DBG_LOCALNAME .AND. uParam1 != NIL
         FWrite(s_nLogHandle, " Local: " + hb_CStr(uParam1))
         IF uParam2 != NIL
            FWrite(s_nLogHandle, " Index: " + Str(uParam2))
         ENDIF
      ELSEIF nMode == HB_DBG_STATICNAME .AND. uParam3 != NIL
         FWrite(s_nLogHandle, " Static: " + hb_CStr(uParam3))
      ELSEIF nMode == HB_DBG_GETENTRY
         FWrite(s_nLogHandle, " GETENTRY - VM requesting registration")
      ENDIF
      
      FWrite(s_nLogHandle, CRLF)
   ENDIF
RETURN

// Initialize debug info structure
STATIC PROCEDURE InitDebugInfo()
   IF s_aDebugInfo == NIL
      s_aDebugInfo := Array(10)
      s_aDebugInfo[1] := {}     // aStack
      s_aDebugInfo[2] := {}     // aModules  
      s_aDebugInfo[3] := 0      // __dbgEntryLevel
      s_aDebugInfo[4] := .T.    // lInitialized
      ? "Debug info structure initialized"
   ENDIF
RETURN

// Handle HB_DBG_MODULENAME events
STATIC PROCEDURE HandleModuleName(cModuleFunc)
   LOCAL aStack, aFrame
   
   InitDebugInfo()
   aStack := s_aDebugInfo[1]
   
   // Create new stack frame
   aFrame := Array(6)
   aFrame[1] := cModuleFunc    // Module:Function
   aFrame[2] := ProcLine(1)    // Line
   aFrame[3] := __dbgProcLevel()-1  // Level
   aFrame[4] := {}             // Locals array
   aFrame[5] := {}             // Statics array
   aFrame[6] := Time()         // Timestamp
   
   AAdd(aStack, aFrame)
   
   ? "Stack frame added for:", cModuleFunc
RETURN

// Handle HB_DBG_LOCALNAME events  
STATIC PROCEDURE HandleLocalName(cVarName, nIndex)
   LOCAL aStack, aLocals
   
   IF s_aDebugInfo != NIL
      aStack := s_aDebugInfo[1]
      IF Len(aStack) > 0
         aLocals := ATail(aStack)[4]
         AAdd(aLocals, {cVarName, nIndex, "L", __dbgProcLevel()-1})
         ? "Local variable added:", cVarName, "index:", nIndex
      ENDIF
   ENDIF
RETURN

// Handle HB_DBG_STATICNAME events
STATIC PROCEDURE HandleStaticName(nModuleIndex, nVarIndex, cVarName)
   LOCAL aStack, aStatics
   
   IF s_aDebugInfo != NIL
      aStack := s_aDebugInfo[1]
      IF Len(aStack) > 0
         aStatics := ATail(aStack)[5]
         AAdd(aStatics, {cVarName, nVarIndex, "S", nModuleIndex})
         ? "Static variable added:", cVarName, "module:", nModuleIndex, "index:", nVarIndex
      ENDIF
   ENDIF
RETURN

// Test function to verify debug info collection
FUNCTION ShowDebugInfo()
   LOCAL i, aStack, aFrame
   
   IF s_aDebugInfo != NIL
      aStack := s_aDebugInfo[1]
      ? "=== Debug Info Summary ==="
      ? "Total stack frames:", Len(aStack)
      
      FOR i := 1 TO Len(aStack)
         aFrame := aStack[i]
         ? "Frame", i, ":", aFrame[1], "Line:", aFrame[2], "Level:", aFrame[3]
         ? "  Locals:", Len(aFrame[4])
         ? "  Statics:", Len(aFrame[5])
      NEXT
   ELSE
      ? "Debug info not initialized"
   ENDIF
RETURN .T.
// IntelliJ Harbour Debug Library - Restored Step Functionality
// Based on harbourCodeExtension's dbg_lib.prg
// This implements the debug protocol for IntelliJ integration
#pragma -B-

// Force console mode to prevent ANSI escape sequences
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 6110
#endif

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <hboo.ch>

#ifndef HB_DBG_CS_MODULE
#define HB_DBG_CS_MODULE      1
#define HB_DBG_CS_FUNCTION    2
#define HB_DBG_CS_LINE        3
#define HB_DBG_CS_LEVEL       4
#define HB_DBG_CS_LOCALS      5
#define HB_DBG_CS_STATICS     6
#define HB_DBG_CS_LEN         6
#endif

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

#ifndef HB_DBG_VAR_NAME
#define HB_DBG_VAR_NAME       1
#define HB_DBG_VAR_INDEX      2
#define HB_DBG_VAR_TYPE       3
#define HB_DBG_VAR_FRAME      4
#define HB_DBG_VAR_LEN        4
#endif

#define CRLF Chr(13)+Chr(10)

STATIC t_oDebugInfo
STATIC s_lConsoleRedirect := .T.  // Enable console redirection by default

// Get or create debug info
STATIC FUNCTION __DEBUGITEM(xValue)
   IF xValue != NIL
      t_oDebugInfo := xValue
   ENDIF
   IF t_oDebugInfo == NIL
      t_oDebugInfo := { ;
         "socket" => NIL, ;
         "lRunning" => .F., ;
         "lInternalRun" => .F., ;
         "aBreaks" => {=>}, ;
         "aStack" => {}, ;
         "maxLevel" => NIL, ;
         "__dbgEntryLevel" => 0, ;
         "timeCheckForDebug" => 0, ;
         "lInitialized" => .F., ;
         "lSingleStep" => .F. ;
      }
   ENDIF
RETURN t_oDebugInfo

// Main debug entry point - called by Harbour VM
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   STATIC nDebugCallCount := 0
   LOCAL t_oDebugInfo
   LOCAL tmp, i, lAdd
   LOCAL nCurrentLine, cCurrentFile, nLevel
   
   // Handle the special case where VM asks for the debugger
   IF nMode == HB_DBG_GETENTRY
      __dbgSetEntry()  // Register ourselves as the debugger
      RETURN
   ENDIF
   
   t_oDebugInfo := __DEBUGITEM()
   
   // Initialize on first real call
   IF !t_oDebugInfo["lInitialized"]
      t_oDebugInfo["lInitialized"] := .T.
      ? "IntelliJ Harbour Debugger activated"
      // Enable debugging and disable beep
      Set( _SET_DEBUG, .T. )
      Set( _SET_BELL, .F. )  // Disable beep sounds
      // Try additional ways to disable system beeps
      Set( _SET_CONSOLE, .T. )
      Set( _SET_DEVICE, "SCREEN" )
   ENDIF
   
   // Don't process if we're in internal run
   IF t_oDebugInfo["lInternalRun"]
      RETURN
   ENDIF
   
   // Debug output for first few calls
   nDebugCallCount++
   IF nDebugCallCount <= 20
      DO CASE
         CASE nMode == HB_DBG_MODULENAME
            ? "dbgEntry: MODULENAME param1:", uParam1
         CASE nMode == HB_DBG_SHOWLINE
            ? "dbgEntry: SHOWLINE line:", uParam1
         CASE nMode == HB_DBG_ACTIVATE
            ? "dbgEntry: ACTIVATE"
         OTHERWISE
            ? "dbgEntry mode:", nMode, "param1:", uParam1
      ENDCASE
   ENDIF
   
   SWITCH nMode
      CASE HB_DBG_MODULENAME
         // New module/function entered
         IF uParam1 != NIL
            i := RAt(":", uParam1)
            tmp := ATail(t_oDebugInfo["aStack"])
            lAdd := Empty(tmp) .OR. __dbgProcLevel()-1 != tmp[HB_DBG_CS_LEVEL]
         ELSE
            EXIT
         ENDIF
         
         IF lAdd
            tmp := Array(HB_DBG_CS_LEN)
         ENDIF
         
         IF i == 0
            tmp[HB_DBG_CS_MODULE] := uParam1
            tmp[HB_DBG_CS_FUNCTION] := ProcName(1)
         ELSE
            tmp[HB_DBG_CS_MODULE] := Left(uParam1, i-1)
            tmp[HB_DBG_CS_FUNCTION] := SubStr(uParam1, i+1)
         ENDIF
         
         tmp[HB_DBG_CS_LINE] := ProcLine(1)
         tmp[HB_DBG_CS_LEVEL] := __dbgProcLevel()-1
         tmp[HB_DBG_CS_LOCALS] := {}
         tmp[HB_DBG_CS_STATICS] := {}
         
         IF lAdd
            AAdd(t_oDebugInfo["aStack"], tmp)
            // Debug output
            ? "Module added to stack:", tmp[HB_DBG_CS_MODULE], "at level", tmp[HB_DBG_CS_LEVEL]
         ENDIF
         EXIT
         
      CASE HB_DBG_SHOWLINE
         // Line execution - this is where we check for breakpoints
         t_oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         
         // Update current line in stack
         IF Len(t_oDebugInfo["aStack"]) > 0
            ATail(t_oDebugInfo["aStack"])[HB_DBG_CS_LINE] := uParam1
         ENDIF
         
         CheckSocket(.F.)
         EXIT
         
      CASE HB_DBG_LOCALNAME
         // Local variable
         IF Len(t_oDebugInfo["aStack"]) > 0
            tmp := ATail(t_oDebugInfo["aStack"])
            AAdd(tmp[HB_DBG_CS_LOCALS], {uParam2, uParam1+1, "L", __dbgProcLevel()-1})
         ENDIF
         EXIT
         
      CASE HB_DBG_STATICNAME
         // Static variable
         IF Len(t_oDebugInfo["aStack"]) > 0
            tmp := ATail(t_oDebugInfo["aStack"])
            AAdd(tmp[HB_DBG_CS_STATICS], {uParam2, uParam1+1, "S", uParam3})
         ENDIF
         EXIT
         
      CASE HB_DBG_ENDPROC
         // End of procedure
         IF Len(t_oDebugInfo["aStack"]) > 0
            tmp := ATail(t_oDebugInfo["aStack"])
            IF tmp[HB_DBG_CS_LEVEL] == uParam1
               ASize(t_oDebugInfo["aStack"], Len(t_oDebugInfo["aStack"])-1)
            ENDIF
         ENDIF
         EXIT
         
      CASE HB_DBG_ACTIVATE
         // Activate debugger - this is called for each line when compiled with -b
         // We need to check for breakpoints here
         // Set the current debug entry level
         t_oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         
         // Get the current line from the call stack
         nCurrentLine := 0
         cCurrentFile := ""
         
         // Find the user code level (skip internal functions)
         FOR nLevel := 1 TO __dbgProcLevel()
            cCurrentFile := ProcFile(nLevel)
            IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
               nCurrentLine := ProcLine(nLevel)
               EXIT
            ENDIF
         NEXT
         
         // If we found a user code location, update the stack
         IF nCurrentLine > 0 .AND. !Empty(cCurrentFile)
            IF Empty(t_oDebugInfo["aStack"])
               // Create a stack entry if none exists
               tmp := Array(HB_DBG_CS_LEN)
               tmp[HB_DBG_CS_MODULE] := cCurrentFile
               tmp[HB_DBG_CS_FUNCTION] := ProcName(nLevel)
               tmp[HB_DBG_CS_LINE] := nCurrentLine
               tmp[HB_DBG_CS_LEVEL] := nLevel
               tmp[HB_DBG_CS_LOCALS] := {}
               tmp[HB_DBG_CS_STATICS] := {}
               AAdd(t_oDebugInfo["aStack"], tmp)
            ELSE
               // Update the current line in the stack
               ATail(t_oDebugInfo["aStack"])[HB_DBG_CS_LINE] := nCurrentLine
            ENDIF
         ENDIF
         
         CheckSocket(.F.)
         EXIT
         
      CASE HB_DBG_VMQUIT
         // VM is quitting - close debugger connection
         ? "DEBUG: VM Quitting"
         IF !Empty(t_oDebugInfo["socket"])
            hb_inetSend(t_oDebugInfo["socket"], "VMQUIT" + CRLF)
            hb_inetClose(t_oDebugInfo["socket"])
            t_oDebugInfo["socket"] := NIL
         ENDIF
         EXIT
   ENDSWITCH
RETURN

// Check socket and process debug commands
STATIC PROCEDURE CheckSocket(lStopSent)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL tmp, lNeedExit := .F.
   LOCAL cCurrentFile, nCurrentLine, aStack, i
   
   lStopSent := IF(Empty(lStopSent), .F., lStopSent)
   
   // Try to connect if not connected
   IF Empty(t_oDebugInfo["socket"]) .AND. t_oDebugInfo["timeCheckForDebug"] <= 14
      hb_inetInit()
      t_oDebugInfo["socket"] := hb_inetCreate(140 - t_oDebugInfo["timeCheckForDebug"]*10)
      hb_inetConnect("127.0.0.1", DBG_PORT, t_oDebugInfo["socket"])
      
      IF hb_inetErrorCode(t_oDebugInfo["socket"]) != 0
         tmp := "NO"
      ELSE
         // Send handshake
         hb_inetSend(t_oDebugInfo["socket"], HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)
         
         // Wait for response
         DO WHILE hb_inetDataReady(t_oDebugInfo["socket"]) != 1
            hb_idleSleep(0.1)
         ENDDO
         
         tmp := hb_inetRecvLine(t_oDebugInfo["socket"])
      ENDIF
      
      IF tmp != "HELLO"
         t_oDebugInfo["socket"] := NIL
         t_oDebugInfo["timeCheckForDebug"]++
      ELSE
         ? "Debugger connected on port", DBG_PORT
      ENDIF
   ENDIF
   
   IF Empty(t_oDebugInfo["socket"])
      RETURN
   ENDIF
   
   // Main command loop
   DO WHILE .T.
      IF Empty(t_oDebugInfo["socket"]) .OR. hb_inetErrorCode(t_oDebugInfo["socket"]) != 0
         t_oDebugInfo["socket"] := NIL
         t_oDebugInfo["lRunning"] := .T.
         t_oDebugInfo["aBreaks"] := {=>}
         t_oDebugInfo["maxLevel"] := NIL
         RETURN
      ENDIF
      
      DO WHILE hb_inetDataReady(t_oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(t_oDebugInfo["socket"])
         
         // If socket error occurred while reading, exit
         IF hb_inetErrorCode(t_oDebugInfo["socket"]) != 0
            EXIT
         ENDIF
         
         IF !Empty(tmp)
            ? "DEBUG: Received command:", tmp
            DO CASE
               CASE tmp == "GO"
                  t_oDebugInfo["lRunning"] := .T.
                  t_oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "STEP"
                  t_oDebugInfo["lRunning"] := .T.  // Keep running but enable single step
                  t_oDebugInfo["lSingleStep"] := .T.  // Flag for single step
                  t_oDebugInfo["maxLevel"] := NIL  // Clear any step-over state
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "NEXT"
                  t_oDebugInfo["lRunning"] := .T.
                  t_oDebugInfo["lSingleStep"] := .T.  // Single step like STEP
                  // For step-over: save current level, only stop when back at same level or higher
                  t_oDebugInfo["maxLevel"] := t_oDebugInfo["__dbgEntryLevel"]
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "OUT"
                  // Step out: run until we return to a level less than current
                  t_oDebugInfo["lRunning"] := .T.
                  t_oDebugInfo["lSingleStep"] := .T.  // Enable single step checking
                  // Set maxLevel to current level - 1 (we want to stop when we're back at caller level)
                  t_oDebugInfo["maxLevel"] := t_oDebugInfo["__dbgEntryLevel"] - 1
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "EXIT"
                  t_oDebugInfo["lRunning"] := .T.
                  t_oDebugInfo["maxLevel"] := -1
                  lNeedExit := .T.
                  
               CASE tmp == "STACK"
                  SendStack()
                  
               CASE tmp == "LOCALS"
                  SendLocals(hb_inetRecvLine(t_oDebugInfo["socket"]))
                  
               CASE tmp == "STATICS"
                  SendStatics(hb_inetRecvLine(t_oDebugInfo["socket"]))
                  
               CASE tmp == "PRIVATES"
                  SendPrivates(hb_inetRecvLine(t_oDebugInfo["socket"]))
                  
               CASE tmp == "PUBLICS"
                  SendPublics(hb_inetRecvLine(t_oDebugInfo["socket"]))
                  
               CASE tmp == "BREAKPOINT"
                  SetBreakpoint(hb_inetRecvLine(t_oDebugInfo["socket"]))
                  
               CASE Left(tmp, 8) == "ADDBREAK"
                  // Handle ADDBREAK:filename:line format
                  IF ":" $ tmp
                     SetBreakpoint("+" + SubStr(tmp, 9))  // Convert ADDBREAK:file:line to +:file:line
                  ENDIF
                  
               CASE tmp == "DISCONNECT"
                  t_oDebugInfo["socket"] := NIL
                  t_oDebugInfo["lRunning"] := .T.
                  t_oDebugInfo["aBreaks"] := {=>}
                  t_oDebugInfo["maxLevel"] := NIL
                  RETURN
            ENDCASE
         ENDIF
      ENDDO
      
      IF lNeedExit
         RETURN
      ENDIF
      
      // Check if we should stop (only when running)
      IF t_oDebugInfo["lRunning"]
         // HIGHEST PRIORITY: Single step mode  
         IF t_oDebugInfo["lSingleStep"]
            // Check if this is step-over and we're going deeper than allowed
            IF !Empty(t_oDebugInfo["maxLevel"]) .AND. t_oDebugInfo["maxLevel"] > 0 .AND. t_oDebugInfo["__dbgEntryLevel"] > t_oDebugInfo["maxLevel"]
               // In step-over mode but went deeper - don't stop, just continue
               RETURN
            ENDIF
            
            t_oDebugInfo["lSingleStep"] := .F.  // Reset flag
            t_oDebugInfo["lRunning"] := .F.     // Stop running
            // If we were in step-over mode and now at same/higher level, clear it
            IF !Empty(t_oDebugInfo["maxLevel"]) .AND. t_oDebugInfo["maxLevel"] > 0 .AND. t_oDebugInfo["__dbgEntryLevel"] <= t_oDebugInfo["maxLevel"]
               t_oDebugInfo["maxLevel"] := NIL
            ENDIF
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(t_oDebugInfo["aStack"]) > 0
                  aStack := ATail(t_oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(t_oDebugInfo["socket"], "STOP:step:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         // Check for breakpoints
         ELSEIF InBreakpoint()
            t_oDebugInfo["lRunning"] := .F.
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(t_oDebugInfo["aStack"]) > 0
                  aStack := ATail(t_oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(t_oDebugInfo["socket"], "STOP:break:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF
         
         // Check for ALTD
         IF __dbgInvokeDebug(.F.)
            t_oDebugInfo["lRunning"] := .F.
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(t_oDebugInfo["aStack"]) > 0
                  aStack := ATail(t_oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(t_oDebugInfo["socket"], "STOP:AltD:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF
      ENDIF
      
      IF t_oDebugInfo["lRunning"] .OR. Empty(t_oDebugInfo["socket"])
         RETURN
      ENDIF
      
      // When stopped, add minimal sleep to prevent CPU spinning but stay responsive
      t_oDebugInfo["lInternalRun"] := .T.
      hb_idleSleep(0.01)  // 10ms sleep
      t_oDebugInfo["lInternalRun"] := .F.
   ENDDO
RETURN

// Send call stack
STATIC PROCEDURE SendStack()
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL i, nLevel, line, module, functionName
   LOCAL aStack := t_oDebugInfo["aStack"]
   LOCAL start := 3
   
   nLevel := __dbgProcLevel()
   hb_inetSend(t_oDebugInfo["socket"], "STACK " + AllTrim(Str(nLevel-start)) + CRLF)
   
   FOR i := start TO nLevel-1
      line := ProcLine(i)
      module := ProcFile(i)
      functionName := ProcName(i)
      
      // Format: module:line:function
      hb_inetSend(t_oDebugInfo["socket"], ;
         StrTran(module, ":", ";") + ":" + ;
         AllTrim(Str(line)) + ":" + ;
         StrTran(functionName, ":", ";") + CRLF)
   NEXT
RETURN

// Send local variables
STATIC PROCEDURE SendLocals(cParams)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nLevel, nStart, nCount
   LOCAL aStack := t_oDebugInfo["aStack"]
   LOCAL i, n, cName, xValue, cType
   
   // Parse parameters: level:start:count
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   nStart := IF(Len(aParams) >= 2, Val(aParams[2]), 0)
   nCount := IF(Len(aParams) >= 3, Val(aParams[3]), 9999)
   
   hb_inetSend(t_oDebugInfo["socket"], "LOCALS" + CRLF)
   
   // Find stack frame
   n := AScan(aStack, {|x| (__dbgProcLevel() - x[HB_DBG_CS_LEVEL]) == nLevel})
   IF n > 0
      FOR i := nStart+1 TO Min(nStart+nCount, Len(aStack[n, HB_DBG_CS_LOCALS]))
         cName := aStack[n, HB_DBG_CS_LOCALS, i, HB_DBG_VAR_NAME]
         xValue := __dbgVMVarLGet(__dbgProcLevel() - nLevel, aStack[n, HB_DBG_CS_LOCALS, i, HB_DBG_VAR_INDEX])
         cType := ValType(xValue)
         
         hb_inetSend(t_oDebugInfo["socket"], ;
            cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(t_oDebugInfo["socket"], "END_LOCALS" + CRLF)
RETURN

// Send static variables (stub implementation)
STATIC PROCEDURE SendStatics(cParams)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   // Remove unused parameter warning
   HB_SYMBOL_UNUSED(cParams)
   hb_inetSend(t_oDebugInfo["socket"], "STATICS" + CRLF)
   hb_inetSend(t_oDebugInfo["socket"], "END_STATICS" + CRLF)
RETURN

// Send private variables (stub implementation)
STATIC PROCEDURE SendPrivates(cParams)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   // Remove unused parameter warning
   HB_SYMBOL_UNUSED(cParams)
   hb_inetSend(t_oDebugInfo["socket"], "PRIVATES" + CRLF)
   hb_inetSend(t_oDebugInfo["socket"], "END_PRIVATES" + CRLF)
RETURN

// Send public variables (stub implementation)
STATIC PROCEDURE SendPublics(cParams)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   // Remove unused parameter warning
   HB_SYMBOL_UNUSED(cParams)
   hb_inetSend(t_oDebugInfo["socket"], "PUBLICS" + CRLF)
   hb_inetSend(t_oDebugInfo["socket"], "END_PUBLICS" + CRLF)
RETURN

// Check if current position is a breakpoint
STATIC FUNCTION InBreakpoint()
   STATIC nCallCount := 0
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL cFile := ""
   LOCAL nLine := 0
   LOCAL cKey, i, aStack
   
   // Get current position from stack
   IF Len(t_oDebugInfo["aStack"]) > 0
      aStack := ATail(t_oDebugInfo["aStack"])
      cFile := Lower(AllTrim(aStack[HB_DBG_CS_MODULE]))
      nLine := aStack[HB_DBG_CS_LINE]
   ELSE
      // Fallback to ProcFile/ProcLine if stack is empty
      // Try different levels to find the user code
      FOR i := 2 TO 5
         cFile := ProcFile(i)
         IF !Empty(cFile) .AND. !("harbour_debug" $ Lower(cFile))
            cFile := Lower(AllTrim(cFile))
            nLine := ProcLine(i)
            EXIT
         ENDIF
      NEXT
   ENDIF
   
   // Debug output (will be removed later)
   nCallCount++
   IF nCallCount <= 10  // Only show first 10 to avoid spam
      ? "Checking breakpoint at", cFile, "line", nLine
   ENDIF
   
   // Extract just the filename without path
   i := RAt("/", cFile)
   IF i == 0
      i := RAt("\", cFile)
   ENDIF
   IF i > 0
      cFile := SubStr(cFile, i + 1)
   ENDIF
   
   cKey := cFile + ":" + AllTrim(Str(nLine))
   
   // Check if this file:line has a breakpoint
   IF hb_HHasKey(t_oDebugInfo["aBreaks"], cKey)
      ? "Breakpoint hit at", cKey
      RETURN .T.
   ENDIF
   
   // Debug: show all breakpoints if checking first few times
   IF nCallCount <= 3
      ? "Looking for:", cKey
      ? "Registered breakpoints:"
      FOR EACH i IN hb_HKeys(t_oDebugInfo["aBreaks"])
         ? "  ", i
      NEXT
   ENDIF
   
RETURN .F.

// Set a breakpoint
STATIC PROCEDURE SetBreakpoint(cParams)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL aParams, cOp, cFile, nLine, cKey, i
   
   // Parse: +/-:filename:line
   aParams := hb_ATokens(cParams, ":")
   IF Len(aParams) >= 3
      cOp := aParams[1]
      cFile := Lower(AllTrim(aParams[2]))
      nLine := Val(aParams[3])
      
      // Extract just the filename without path
      i := RAt("/", cFile)
      IF i == 0
         i := RAt("\", cFile)
      ENDIF
      IF i > 0
         cFile := SubStr(cFile, i + 1)
      ENDIF
      
      cKey := cFile + ":" + AllTrim(Str(nLine))
      
      IF cOp == "+"
         t_oDebugInfo["aBreaks"][cKey] := .T.
         hb_inetSend(t_oDebugInfo["socket"], "BREAK:" + cFile + ":" + Str(nLine) + ":" + Str(nLine) + CRLF)
         ? "Breakpoint set at", cKey
         ? "Total breakpoints:", Len(t_oDebugInfo["aBreaks"])
      ELSE
         hb_HDel(t_oDebugInfo["aBreaks"], cKey)
         ? "Breakpoint removed at", cKey
      ENDIF
   ENDIF
RETURN

// Format a value for display
STATIC FUNCTION FormatValue(xValue)
   LOCAL cType := ValType(xValue)
   LOCAL cResult
   
   DO CASE
      CASE cType == "C"
         cResult := '"' + xValue + '"'
      CASE cType == "N"
         cResult := Str(xValue)
      CASE cType == "L"
         cResult := IF(xValue, ".T.", ".F.")
      CASE cType == "D"
         cResult := DToC(xValue)
      CASE cType == "A"
         cResult := "Array(" + AllTrim(Str(Len(xValue))) + ")"
      CASE cType == "H"
         cResult := "Hash(" + AllTrim(Str(Len(xValue))) + ")"
      CASE cType == "O"
         cResult := "Object:" + xValue:ClassName()
      CASE cType == "B"
         cResult := "{||...}"
      CASE cType == "U"
         cResult := "NIL"
      OTHERWISE
         cResult := "Unknown"
   ENDCASE
   
RETURN cResult

// Custom output function to send to debugger
STATIC PROCEDURE DebugQOut(...)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL aParams := HB_AParams()
   LOCAL cOutput := ""
   LOCAL i
   
   // Build output string
   FOR i := 1 TO Len(aParams)
      IF i > 1
         cOutput += " "
      ENDIF
      cOutput += hb_CStr(aParams[i])
   NEXT
   
   // Send to console and debugger
   OutStd(cOutput + hb_eol())
   
   // Send to debugger if connected
   IF !Empty(t_oDebugInfo["socket"]) .AND. s_lConsoleRedirect
      hb_inetSend(t_oDebugInfo["socket"], "CONSOLE:" + cOutput + CRLF)
   ENDIF
RETURN

// Custom output function (no line break)
STATIC PROCEDURE DebugQQOut(...)
   LOCAL t_oDebugInfo := __DEBUGITEM()
   LOCAL aParams := HB_AParams()
   LOCAL cOutput := ""
   LOCAL i
   
   // Build output string
   FOR i := 1 TO Len(aParams)
      IF i > 1
         cOutput += " "
      ENDIF
      cOutput += hb_CStr(aParams[i])
   NEXT
   
   // Send to console and debugger
   OutStd(cOutput)
   
   // Send to debugger if connected
   IF !Empty(t_oDebugInfo["socket"]) .AND. s_lConsoleRedirect
      hb_inetSend(t_oDebugInfo["socket"], "CONSOLE:" + cOutput + CRLF)
   ENDIF
RETURN

// Override Tone() to prevent beeps
PROCEDURE Tone(...)
   // Do nothing - suppress all beeps
RETURN

// Override AltD() to trigger debugger
PROCEDURE AltD()
   LOCAL t_oDebugInfo := __DEBUGITEM()
   
   ? "AltD() called"
   
   // Ensure debugger is initialized
   IF !t_oDebugInfo["lInitialized"]
      // Manual initialization since we can't call INIT procedure
      Set( _SET_CONSOLE, .T. )
      Set( _SET_ALTERNATE, .F. )
      Set( _SET_DEVICE, "SCREEN" )
      Set( _SET_BELL, .F. )  // Disable beep sounds
      __dbgSetEntry()
      Set( _SET_DEBUG, .T. )
      t_oDebugInfo["lInitialized"] := .T.
   ENDIF
   
   // Try to connect if not connected
   IF Empty(t_oDebugInfo["socket"])
      CheckSocket(.F.)
   ENDIF
   
   // Force stop
   IF !Empty(t_oDebugInfo["socket"])
      t_oDebugInfo["lRunning"] := .F.
      // Send STOP message for AltD
      hb_inetSend(t_oDebugInfo["socket"], "STOP:AltD:" + ProcFile(1) + ":" + AllTrim(Str(ProcLine(1))) + CRLF)
      // Now process commands until we get GO
      DO WHILE !t_oDebugInfo["lRunning"] .AND. !Empty(t_oDebugInfo["socket"])
         CheckSocket(.T.)  // Pass .T. to indicate we already sent STOP
      ENDDO
   ELSE
      ? "AltD: Debugger not connected"
   ENDIF
RETURN

#pragma BEGINDUMP

#include <hbapi.h>

#if defined( HB_OS_UNIX ) || defined( __DJGPP__ )
#  include <sys/types.h>
#  include <unistd.h>
#elif defined( HB_OS_WIN )
#  include <windows.h>
#elif defined( HB_OS_OS2 ) || defined( HB_OS_DOS )
#  include <process.h>
#endif

HB_FUNC( __PIDNUM )
{
#if defined( HB_OS_WIN_CE )
   hb_retni( 0 );
#elif defined( HB_OS_WIN )
   hb_retnint( GetCurrentProcessId() );
#elif ( defined( HB_OS_OS2 ) && defined( __GNUC__ ) )
   hb_retnint( _getpid() );
#else
   hb_retnint( getpid() );
#endif
}

#pragma ENDDUMP

// Initialize the debugger when the library is loaded
INIT PROCEDURE __InitIntelliJDebugger()
   LOCAL t_oDebugInfo
   
   // Force standard console output
   Set( _SET_CONSOLE, .T. )
   Set( _SET_ALTERNATE, .F. )
   Set( _SET_DEVICE, "SCREEN" )
   Set( _SET_BELL, .F. )  // Disable beep sounds
   
   // Initialize debug info
   t_oDebugInfo := __DEBUGITEM()
   
   // Register our debugger with the VM
   __dbgSetEntry()
   
   // Enable debugging
   Set( _SET_DEBUG, .T. )
   
   ? "IntelliJ Harbour Debugger initializing..."
   
   // Set running state to true initially - don't stop until we hit a breakpoint
   t_oDebugInfo["lRunning"] := .T.
   
   // Try initial connection to debugger
   CheckSocket(.F.)
RETURN
// IntelliJ Harbour Debug Handler - COMPLETE VERSION 1.4.1
// Combines working variable names + breakpoint functionality + GLOBAL ERROR HANDLING
// Based on working VSCode pattern with socket integration

#pragma -B-
REQUEST HB_GT_STD_DEFAULT

// Windows console suppression - use environment variable control
// The GT driver will be controlled via HB_GT_LIB environment variable
// This allows flexibility without hardcoding the terminal type

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <hbhash.ch>

#ifndef DBG_PORT
#define DBG_PORT 9876  // IntelliJ debugger port
#endif

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#define HB_DBG_SHOWLINE       5
#define HB_DBG_ENDPROC        4
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

#ifndef HB_DBG_VAR_NAME
#define HB_DBG_VAR_NAME       1
#define HB_DBG_VAR_INDEX      2
#define HB_DBG_VAR_TYPE       3
#define HB_DBG_VAR_FRAME      4
#endif

#define CRLF Chr(13)+Chr(10)

// STATIC declarations must be at the top before any procedures
STATIC t_oDebugInfo
STATIC s_lSocketEnabled := .T.  // ENABLED: Socket communication needed for PyCharm breakpoints

// Static variable to track if we've hooked the error handler
// REMOVED: s_lErrorHandlerHooked - not needed with new monitoring approach
// REMOVED: s_bOriginalHandler - not needed with new monitoring approach

// REMOVED: Obsolete SetGlobalErrorHandler() and MonitoringErrorHandler() - replaced by harbour_error_monitor.prg

// REMOVED: HookUserErrorHandler - part of abandoned approach

// REMOVED: ErrorHandlerWrapper - part of abandoned approach

// Get or create debug info
STATIC FUNCTION __DEBUGITEM(xValue)
   IF xValue != NIL
      t_oDebugInfo := xValue
   ENDIF
   IF t_oDebugInfo == NIL
      t_oDebugInfo := { ;
         "socket" => NIL, ;
         "lRunning" => .T., ;
         "lInternalRun" => .F., ;
         "aBreaks" => {=>}, ;
         "aStack" => {}, ;
         "aModules" => {}, ;
         "__dbgEntryLevel" => 0, ;
         "timeCheckForDebug" => 0, ;
         "lInitialized" => .F., ;
         "lSingleStep" => .F., ;
         "maxLevel" => NIL, ;
         "debugHandle" => NIL ;
      }
   ENDIF
RETURN t_oDebugInfo

// Main debug entry point - exact VSCode pattern with socket integration
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   LOCAL i, tmp, j, vv, oDebugInfo, lAltDInvoked

   // Suppress unused parameter warnings
   HB_SYMBOL_UNUSED(uParam4)
   HB_SYMBOL_UNUSED(vv)
   
   // Add error handling and stacktrace logging
   BEGIN SEQUENCE WITH {|err| ErrorHandler(err, nMode) }

   // REMOVED - Setting error handler here conflicts with user's error handler
   // Now using EXIT procedure to wrap the error handler after all INIT procedures
   // ErrorBlock({|oError| GlobalErrorHandler(oError)})
   
   // Removed hardcoded debug log file - error handler is set silently

   // Simple error handling without complex hooks
   // We'll rely on root.inf monitoring instead
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Register with VM - this works
      __dbgSetEntry()
      
   CASE nMode == HB_DBG_MODULENAME
      // New module/function entered - build stack with variable names
      oDebugInfo := __DEBUGITEM()
      IF uParam1 != NIL
         // Set the current debug entry level
         oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         
         i := RAt(":", uParam1)
         tmp := ATail(oDebugInfo["aStack"])
         
         // Create new stack frame
         IF Empty(tmp) .OR. __dbgProcLevel()-1 != tmp[HB_DBG_CS_LEVEL]
            tmp := Array(6)
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
            AAdd(oDebugInfo["aStack"], tmp)
         ENDIF
      ENDIF
      
   CASE nMode == HB_DBG_LOCALNAME
      // Local variable - store with correct frame info
      oDebugInfo := __DEBUGITEM()
      IF Len(oDebugInfo["aStack"]) > 0
         tmp := ATail(oDebugInfo["aStack"])
         // Store: name, index, type, frame level
         AAdd(tmp[HB_DBG_CS_LOCALS], {uParam2, uParam1, "L", __dbgProcLevel()-1})
      ENDIF
      
   CASE nMode == HB_DBG_STATICNAME
      // Static variable
      oDebugInfo := __DEBUGITEM()
      IF Len(oDebugInfo["aStack"]) > 0
         tmp := ATail(oDebugInfo["aStack"])
         AAdd(tmp[HB_DBG_CS_STATICS], {uParam2, uParam1, "S", uParam3})
      ENDIF
      
   CASE nMode == HB_DBG_ENDPROC
      // End of procedure - remove stack frame
      oDebugInfo := __DEBUGITEM()
      IF Len(oDebugInfo["aStack"]) > 0
         tmp := ATail(oDebugInfo["aStack"])
         IF tmp[HB_DBG_CS_LEVEL] == uParam1
            ASize(oDebugInfo["aStack"], Len(oDebugInfo["aStack"])-1)
         ENDIF
      ENDIF
      
   CASE nMode == HB_DBG_SHOWLINE
      // Line execution - check for breakpoints
      oDebugInfo := __DEBUGITEM()
      oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
      
      lAltDInvoked := __dbgInvokeDebug()  // Check without clearing
      IF lAltDInvoked
         __dbgInvokeDebug(.T.)  // Clear the flag after detecting
      ENDIF
      
      // Update current line in stack
      IF Len(oDebugInfo["aStack"]) > 0
         ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE] := uParam1
      ENDIF
      
      // Check socket and process commands if enabled
      IF s_lSocketEnabled
         IF lAltDInvoked
            oDebugInfo["lRunning"] := .F.
         ENDIF
         CheckSocket(.F.)
      ENDIF
      
   CASE nMode == HB_DBG_ACTIVATE
      // Process stack frames with variables (VSCode pattern) + socket check
      oDebugInfo := __DEBUGITEM()
      oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
      
      // Store debug handle
      IF uParam1 != NIL
         oDebugInfo["debugHandle"] := uParam1
      ENDIF
      
      // Store the VM stack data for SendLocals to use
      IF uParam3 != NIL .AND. ValType(uParam3) == "A"
         oDebugInfo["vmStack"] := uParam3  // Store VM-provided stack
      ENDIF
      
      // Show variables like the working version
      
      IF uParam3 != NIL .AND. ValType(uParam3) == "A"
         FOR i := 1 TO Len(uParam3)
              
            // Show local variables with actual names
            FOR j := 1 TO Len(uParam3[i,HB_DBG_CS_LOCALS])
               tmp := uParam3[i,HB_DBG_CS_LOCALS,j]
               vv := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
               HB_SYMBOL_UNUSED(vv)  // Used for debugging when needed
            NEXT
         NEXT
      ENDIF
      
      // Check if this is triggered by AltD() - force stop if so
      // AltD() triggers HB_DBG_ACTIVATE and should always break
      IF s_lSocketEnabled
         // Only check for AltD stops in ACTIVATE, not regular breakpoints
         CheckSocket(IsAltDStop())
      ENDIF
      
   CASE nMode == HB_DBG_VMQUIT
      // VM is quitting
      oDebugInfo := __DEBUGITEM()
      IF !Empty(oDebugInfo["socket"])
         hb_inetSend(oDebugInfo["socket"], "VMQUIT" + CRLF)
         hb_inetClose(oDebugInfo["socket"])
         oDebugInfo["socket"] := NIL
      ENDIF
   ENDCASE
   
   END SEQUENCE
RETURN

// Error handler for debug operations - logs to PyCharm console and files
STATIC PROCEDURE ErrorHandler(oError, nMode)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL cErrorMsg
   
   // Suppress unused parameter warnings
   HB_SYMBOL_UNUSED(nMode)
   
   // Log to stderr instead of file for essential error tracking
   FWrite(2, "DEBUG ERROR: " + oError:Description + " at " + ProcName(1) + "(" + AllTrim(Str(ProcLine(1))) + ")" + CRLF)
   
   // Send error to PyCharm console if socket is available
   IF !Empty(oDebugInfo["socket"])
      cErrorMsg := "ERROR: " + oError:Description + " at " + ProcName(1) + "(" + AllTrim(Str(ProcLine(1))) + ")"
      hb_inetSend(oDebugInfo["socket"], "ERROR:" + cErrorMsg + CRLF)
   ENDIF
   
   // Removed hardcoded debug trace log file
   
   // REMOVED: Print error to stdout - causes popup console
   // Errors should only go to PyCharm console via socket or file logging
   
   // Re-raise the error so the program crashes as expected
   BREAK(oError)
   // RETURN statement removed as it's unreachable after BREAK

// Global error handler for entire application (not just debug system)
// Handles ALL runtime errors uniformly: array bounds, type mismatches, division by zero, file errors, etc.
// External function declarations from harbour_error_handler.prg  
EXTERNAL FormatErrorMessage, CollectStackTrace, FormatStackTrace, OutputError, FormatCompleteError

// All errors are displayed in PyCharm console via socket (debug mode) or stderr
FUNCTION GlobalErrorHandler(oError)
   LOCAL oDebugInfo, cCompleteError, hLogFile, cLogPath
   STATIC s_lInErrorHandler := .F.
   
   // Debug logging - ensure log directory exists
   cLogPath := "log" + hb_ps() + "global_error_handler.log"
   
   // Create log directory if it doesn't exist
   IF !hb_DirExists("log")
      MakeDir("log")
   ENDIF
   
   hLogFile := FCreate(cLogPath)
   IF hLogFile != -1
      FWrite(hLogFile, "===== GlobalErrorHandler called at " + Time() + " =====" + CRLF)
      FWrite(hLogFile, "Error description: " + oError:Description + CRLF)
      FWrite(hLogFile, "Error subsystem: " + oError:SubSystem + CRLF)
      FWrite(hLogFile, "Error code: " + Str(oError:GenCode) + CRLF)
      FWrite(hLogFile, "Error operation: " + IIF(ValType(oError:Operation) == "C", oError:Operation, "<none>") + CRLF)
      FWrite(hLogFile, "Working directory: " + CurDir() + CRLF)
      FClose(hLogFile)
   ENDIF
   
   // Prevent recursion - if we're already in error handler, just exit
   IF s_lInErrorHandler
      RETURN NIL
   ENDIF
   s_lInErrorHandler := .T.
   
   oDebugInfo := __DEBUGITEM()
   
   // Format complete error with stack trace using shared functions
   cCompleteError := FormatCompleteError(oError)
   
   // Always output to stderr and log file (for IntelliJ console)
   OutputError(cCompleteError)
   
   // Reset recursion flag before re-raising error
   s_lInErrorHandler := .F.
   
   // Re-raise the error properly to prevent "Error recovery failure"
   // Let the original error handler deal with it after we've logged it
   IF .T.  // Always true, but avoids unreachable code warning
      BREAK(oError)
   ENDIF
   
   // This return satisfies function requirement but won't be reached
   RETURN NIL

// Test function to verify error handler is working
FUNCTION TestErrorHandler()
   LOCAL aTest
   
   // Removed test error handler log file
   
   // Division by zero doesn't trigger ErrorBlock() in Harbour!
   // Use array bounds error instead - this WILL trigger ErrorBlock()
   aTest := {"a", "b", "c"}
   
   // This should trigger our global error handler (array bounds error)
   RETURN aTest[99]  // Invalid array index
   
// Check socket and process debug commands
STATIC PROCEDURE CheckSocket(lStopSent)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL tmp, lNeedExit := .F.
   LOCAL cCurrentFile, nCurrentLine, aStack, i
   LOCAL hLog  // Keep variable for existing code compatibility
   // Timeout variables removed - debugger will wait forever as requested
   
   lStopSent := IF(Empty(lStopSent), .F., lStopSent)
   
   // Simple error handling to prevent crashes
   BEGIN SEQUENCE
   
   // Removed debug trace log file - socket debugging disabled to avoid file clutter
   hLog := -1  // Keep variable for existing code compatibility
   
   // Try to connect if not connected
   IF Empty(oDebugInfo["socket"]) .AND. oDebugInfo["timeCheckForDebug"] <= 14
      // Connection attempt (logging removed)
      hb_inetInit()
      oDebugInfo["socket"] := hb_inetCreate(140 - oDebugInfo["timeCheckForDebug"]*10)
      hb_inetConnect("127.0.0.1", DBG_PORT, oDebugInfo["socket"])
      
      IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
         // Connection failed (logging removed)
         tmp := "NO"
      ELSE
         // Connection success (logging removed)
         // Send handshake
         hb_inetSend(oDebugInfo["socket"], HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)
         
         // Wait for response
         DO WHILE hb_inetDataReady(oDebugInfo["socket"]) != 1
            hb_idleSleep(0.1)
         ENDDO
         
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
         // Handshake response (logging removed)
      ENDIF
      
      IF tmp != "HELLO"
         // Handshake failed (logging removed)
         oDebugInfo["socket"] := NIL
         oDebugInfo["timeCheckForDebug"]++
      ELSE
         // Handshake success (logging removed)
      ENDIF
   ENDIF
   
   IF Empty(oDebugInfo["socket"])
      // No socket - returning (logging removed)
      BREAK
   ENDIF
   
   // Socket available - entering main loop (logging removed)
   
   // Main command loop - wait forever (timeout removed as requested)
   DO WHILE .T.
      // Removed loop counter - debugger will wait forever
      
      // Main loop iteration (logging removed)
      
      IF Empty(oDebugInfo["socket"]) .OR. hb_inetErrorCode(oDebugInfo["socket"]) != 0
         // Socket error (logging removed)
         oDebugInfo["socket"] := NIL
         oDebugInfo["lRunning"] := .T.
         oDebugInfo["aBreaks"] := {=>}
         oDebugInfo["maxLevel"] := NIL
         BREAK
      ENDIF
      
      DO WHILE hb_inetDataReady(oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
         
         // Received command (logging removed)
         
         IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
            // Socket error in command loop (logging removed)
            EXIT
         ENDIF
         
         IF !Empty(tmp)
            // Processing command (logging removed)
            DO CASE
               CASE tmp == "GO"
                  // GO command (logging removed)
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "STEP"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "NEXT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"]
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "OUT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"] - 1
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "EXIT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["maxLevel"] := -1
                  lNeedExit := .T.
                  
               CASE tmp == "STACK"
                  SendStack()
                  
               CASE Left(tmp, 6) == "LOCALS"
                  // LOCALS command (logging removed)
                  IF ":" $ tmp
                     // Calling SendLocals (logging removed)
                     SendLocals(SubStr(tmp, 8))  // LOCALS: = 7 chars, so 8 gets after colon
                  ELSE
                     // Calling SendLocals with 0 (logging removed)
                     SendLocals("0")
                  ENDIF
                  // SendLocals completed (logging removed)
                  
               CASE Left(tmp, 7) == "STATICS"
                  // STATICS command (logging removed)
                  IF ":" $ tmp
                     // Calling SendStatics (logging removed)
                     SendStatics(SubStr(tmp, 8))  // STATICS: = 8 chars  
                  ELSE
                     // Calling SendStatics with 0 (logging removed)
                     SendStatics("0")
                  ENDIF
                  // SendStatics completed (logging removed)
                  
               CASE Left(tmp, 8) == "PRIVATES"
                  // PRIVATES command (logging removed)
                  IF ":" $ tmp
                     // Calling SendPrivates (logging removed)
                     SendPrivates(SubStr(tmp, 9))  // PRIVATES: = 9 chars
                  ELSE
                     // Calling SendPrivates with 0 (logging removed)
                     SendPrivates("0")
                  ENDIF
                  // SendPrivates completed (logging removed)
                  
               CASE Left(tmp, 7) == "PUBLICS"
                  // PUBLICS command (logging removed)
                  IF ":" $ tmp
                     // Calling SendPublics (logging removed)
                     SendPublics(SubStr(tmp, 8))  // PUBLICS: = 8 chars
                  ELSE
                     // Calling SendPublics with 0 (logging removed)
                     SendPublics("0")
                  ENDIF
                  // SendPublics completed (logging removed)
                  
               CASE tmp == "BREAKPOINT"
                  // BREAKPOINT command (logging removed)
                  // BREAKPOINT command is just an acknowledgment - actual breakpoints come as ADDBREAK commands
                  
               CASE Left(tmp, 1) == "+" .OR. Left(tmp, 1) == "-"
                  // BREAKPOINT set/remove (logging removed)
                  SetBreakpoint(tmp)
                  
               CASE Left(tmp, 8) == "ADDBREAK"
                  IF ":" $ tmp
                     SetBreakpoint("+" + SubStr(tmp, 9))
                  ENDIF
                  
               CASE Left(tmp, 9) == "WORKAREAS"
                  // WORKAREAS command - enumerate all open database areas
                  SendWorkAreas()
                  
               CASE Left(tmp, 5) == "ARRAY"
                  // ARRAY command - send array elements
                  IF ":" $ tmp
                     SendArrayElements(SubStr(tmp, 7))  // ARRAY: = 6 chars, so 7 gets after colon
                  ENDIF
                  
               CASE Left(tmp, 4) == "HASH"
                  // HASH command - send hash key-value pairs
                  IF ":" $ tmp
                     SendHashElements(SubStr(tmp, 6))  // HASH: = 5 chars, so 6 gets after colon
                  ENDIF
                  
               CASE Left(tmp, 4) == "AREA"
                  // AREA commands for specific workarea details
                  IF ":" $ tmp
                     HandleAreaCommand(tmp)
                  ENDIF
                  
               CASE tmp == "DISCONNECT"
                  oDebugInfo["socket"] := NIL
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["aBreaks"] := {=>}
                  oDebugInfo["maxLevel"] := NIL
                  BREAK
            ENDCASE
         ENDIF
      ENDDO
      
      IF lNeedExit
         // lNeedExit=TRUE - exiting CheckSocket (logging removed)
         BREAK
      ENDIF
      
      // Check if we should stop
      IF oDebugInfo["lRunning"]
         // Single step mode
         IF oDebugInfo["lSingleStep"]
            // Check step-over level restrictions
            IF !Empty(oDebugInfo["maxLevel"]) .AND. oDebugInfo["maxLevel"] > 0 .AND. oDebugInfo["__dbgEntryLevel"] > oDebugInfo["maxLevel"]
               BREAK
            ENDIF
            
            oDebugInfo["lSingleStep"] := .F.
            oDebugInfo["lRunning"] := .F.
            
            // Clear step-over state if back at same/higher level
            IF !Empty(oDebugInfo["maxLevel"]) .AND. oDebugInfo["maxLevel"] > 0 .AND. oDebugInfo["__dbgEntryLevel"] <= oDebugInfo["maxLevel"]
               oDebugInfo["maxLevel"] := NIL
            ENDIF
            
            IF !lStopSent
               // Get current file and line
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:step:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
            
         // Check for breakpoints
         ELSEIF InBreakpoint()
            oDebugInfo["lRunning"] := .F.
            IF !lStopSent
               // Get current file and line
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:break:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF
         
         // Check for ALTD
         IF __dbgInvokeDebug()
            oDebugInfo["lRunning"] := .F.
            __dbgInvokeDebug(.T.)  // Clear flag after detecting
            IF !lStopSent
               // Get current file and line
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:AltD:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF
      ENDIF
      
      // Continue waiting for commands if stopped (not running)
      IF !oDebugInfo["lRunning"] .AND. !Empty(oDebugInfo["socket"])
         // Wait for debugger commands - sleep to prevent CPU spinning
         oDebugInfo["lInternalRun"] := .T.
         hb_idleSleep(0.01)
         oDebugInfo["lInternalRun"] := .F.
      ELSE
         // Running or no socket - exit
         BREAK
      ENDIF
   ENDDO
   
   // Loop ended normally - debugger will wait forever as requested
   
   END SEQUENCE
RETURN


// Send call stack
STATIC PROCEDURE SendStack()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL i, nLevel, line, module, functionName
   LOCAL start := 3
   
   nLevel := __dbgProcLevel()
   hb_inetSend(oDebugInfo["socket"], "STACK " + AllTrim(Str(nLevel-start)) + CRLF)
   
   FOR i := start TO nLevel-1
      line := ProcLine(i)
      module := ProcFile(i)
      functionName := ProcName(i)
      
      hb_inetSend(oDebugInfo["socket"], ;
         StrTran(module, ":", ";") + ":" + ;
         AllTrim(Str(line)) + ":" + ;
         StrTran(functionName, ":", ";") + CRLF)
   NEXT
RETURN

// Send local variables using VM stack data
STATIC PROCEDURE SendLocals(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nLevel, nStart, nCount
   LOCAL vmStack := oDebugInfo["vmStack"]  // Use VM-provided stack
   LOCAL i, n, cName, xValue, cType, aInfo
   LOCAL l, nStackIndex
   LOCAL aVarData := {}
   LOCAL hLog
   
   // Removed sendlocals trace log file - no hardcoded logging
   
   // Parse parameters: level:start:count
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   nStart := IF(Len(aParams) >= 2, Val(aParams[2]), 0)
   nCount := IF(Len(aParams) >= 3, Val(aParams[3]), 9999)
   
   // Debug logging
   
   IF vmStack != NIL
      FOR i := 1 TO Len(vmStack)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "LOCALS" + CRLF)
   
   // Check if we have VM stack data
   IF vmStack == NIL .OR. Len(vmStack) == 0
      hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
      RETURN
   ENDIF
   
   // For level 0, use the first (top) stack frame
   IF nLevel == 0 .AND. Len(vmStack) > 0
      nStackIndex := 1  // Use first frame for level 0
   ELSE
      // EXACT VSCode formula for stack lookup
      l := oDebugInfo["__dbgEntryLevel"] - nLevel
      
      // Find stack frame with exact matching level
      nStackIndex := 0
      FOR i := Len(vmStack) TO 1 STEP -1
         IF vmStack[i, HB_DBG_CS_LEVEL] == l
            nStackIndex := i
            EXIT
         ENDIF
      NEXT
   ENDIF
   
   // Send locals if stack frame found
   IF nStackIndex > 0 .AND. nStackIndex <= Len(vmStack)
      IF Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
         // Collect all variables first
         FOR i := 1 TO Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
            aInfo := vmStack[nStackIndex, HB_DBG_CS_LOCALS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            
            // Get variable value using stored frame level
            xValue := __dbgVMVarLGet(__dbgProcLevel() - aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            
            AAdd(aVarData, {cName, cType, FormatValue(xValue)})
         NEXT
         
         // Sort alphabetically by variable name (case-insensitive)
         ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
         
         // Send sorted variables
         n := 0
         FOR i := 1 TO Len(aVarData)
            IF n >= nStart .AND. n < nStart + nCount
               hb_inetSend(oDebugInfo["socket"], ;
                  aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
            ENDIF
            n++
         NEXT
      ENDIF
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
   
   IF hLog != -1
      FWrite(hLog, "=== SendLocals EXIT ===" + CRLF)
      FClose(hLog)
   ENDIF
RETURN

// Send static variables - FIXED VERSION with active enumeration
STATIC PROCEDURE SendStatics(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aStack := oDebugInfo["aStack"]
   LOCAL aModules := oDebugInfo["aModules"]
   LOCAL aParams, nLevel
   LOCAL i, cName, xValue, cType, aInfo
   LOCAL l, nStackIndex, cModule, nModIndex
   LOCAL aVarData := {}
   LOCAL aStaticNames := {}  // Empty array - static variables should be discovered dynamically
   LOCAL lFoundAny := .F.
   
   // Parse parameters
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   
   hb_inetSend(oDebugInfo["socket"], "STATICS" + CRLF)
   
   // Enhanced debug output
   
   // EXACT VSCode formula for stack lookup
   l := oDebugInfo["__dbgEntryLevel"] - nLevel
   
   // Check for error state and adjust if needed
   IF hb_HHasKey(oDebugInfo, "lError") .AND. oDebugInfo["lError"]
      l := l - 1  // Adjust by 1 in error state
   ENDIF
   
   // Find stack frame with exact matching level
   nStackIndex := 0
   FOR i := Len(aStack) TO 1 STEP -1
      IF aStack[i, HB_DBG_CS_LEVEL] == l
         nStackIndex := i
         EXIT
      ENDIF
   NEXT
   
   // TRY MODULE-BASED APPROACH FIRST (if stack and modules available)
   IF nStackIndex > 0
      // Get module name
      cModule := Lower(AllTrim(aStack[nStackIndex, HB_DBG_CS_MODULE]))
      
      // Find module in modules array
      nModIndex := AScan(aModules, {|v| v[1] == cModule})
      
      // Collect module statics first
      IF nModIndex > 0 .AND. Len(aModules[nModIndex]) >= 4 .AND. Len(aModules[nModIndex, 4]) > 0
         FOR i := 1 TO Len(aModules[nModIndex, 4])
            aInfo := aModules[nModIndex, 4, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            xValue := __dbgVMVarSGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            AAdd(aVarData, {cName, cType, FormatValue(xValue)})
         NEXT
         lFoundAny := .T.
      ENDIF
      
      // Collect function-local statics
      IF Len(aStack[nStackIndex, HB_DBG_CS_STATICS]) > 0
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
            aInfo := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            xValue := __dbgVMVarSGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            AAdd(aVarData, {cName, cType, FormatValue(xValue)})
         NEXT
         lFoundAny := .T.
      ENDIF
   ENDIF
   
   // FALLBACK: If no statics found via module system, try direct access
   IF !lFoundAny
      
      // NEW APPROACH: Try to access known static variables by name
      // This bypasses the broken module registration system
      
      FOR i := 1 TO Len(aStaticNames)
         IF Type(aStaticNames[i]) != "U"
            xValue := &(aStaticNames[i])
            cType := ValType(xValue)
            AAdd(aVarData, {aStaticNames[i], cType, FormatValue(xValue)})
            lFoundAny := .T.
         ENDIF
      NEXT
   ENDIF
   
   // Sort and send all statics
   IF Len(aVarData) > 0
      ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
      FOR i := 1 TO Len(aVarData)
         hb_inetSend(oDebugInfo["socket"], ;
            aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_STATICS" + CRLF)
RETURN

// Send private variables
STATIC PROCEDURE SendPrivates(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nLevel, nStart, nCount
   LOCAL nLocal, i, cName, xValue, cType
   LOCAL nAllPrivates
   LOCAL aVarData := {}
   
   // Parse parameters
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   nStart := IF(Len(aParams) >= 2, Val(aParams[2]), 0)
   nCount := IF(Len(aParams) >= 3, Val(aParams[3]), 9999)
   
   hb_inetSend(oDebugInfo["socket"], "PRIVATES" + CRLF)
   
   // Get count of private variables local to this level
   #ifdef __XHARBOUR__
      nLocal := __mvDbgInfo(HB_MV_PRIVATE)
   #else
      nLocal := __mvDbgInfo(HB_MV_PRIVATE_LOCAL, __dbgProcLevel() - nLevel)
   #endif
   
   IF nCount == 0
      nCount := nLocal
   ENDIF
   
   // Try getting all privates first
   nAllPrivates := __mvDbgInfo(HB_MV_PRIVATE)
   
   // Collect private variables first
   IF nLocal > 0
      FOR i := 1 TO nLocal
         xValue := __mvDbgInfo(HB_MV_PRIVATE_LOCAL, i, @cName, __dbgProcLevel() - nLevel)
         cType := ValType(xValue)
         // Show all private variables including GETLIST (user may define it locally)
         AAdd(aVarData, {cName, cType, FormatValue(xValue)})
      NEXT
   ELSEIF nAllPrivates > 0
      FOR i := 1 TO nAllPrivates
         xValue := __mvDbgInfo(HB_MV_PRIVATE, i, @cName)
         cType := ValType(xValue)
         // Show all private variables including GETLIST (user may define it locally)
         AAdd(aVarData, {cName, cType, FormatValue(xValue)})
      NEXT
   ENDIF
   
   // Sort alphabetically by variable name (case-insensitive)
   IF Len(aVarData) > 0
      ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
      
      // Send sorted variables
      FOR i := nStart+1 TO Min(nStart+nCount, Len(aVarData))
         hb_inetSend(oDebugInfo["socket"], ;
            aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_PRIVATES" + CRLF)
RETURN

// Send public variables
STATIC PROCEDURE SendPublics(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nStart, nCount
   LOCAL nVars, i, cName, xValue, cType
   LOCAL aVarData := {}
   
   // Parse parameters (level not used for publics)
   aParams := hb_ATokens(cParams, ":")
   nStart := IF(Len(aParams) >= 2, Val(aParams[2]), 0)
   nCount := IF(Len(aParams) >= 3, Val(aParams[3]), 9999)
   
   hb_inetSend(oDebugInfo["socket"], "PUBLICS" + CRLF)
   
   // Get public variables count
   nVars := __mvDbgInfo(HB_MV_PUBLIC)
   
   IF nCount == 0
      nCount := nVars
   ENDIF
   
   // Collect public variables first
   FOR i := 1 TO nVars
      xValue := __mvDbgInfo(HB_MV_PUBLIC, i, @cName)
      cType := ValType(xValue)
      AAdd(aVarData, {cName, cType, FormatValue(xValue)})
   NEXT
   
   // Sort alphabetically by variable name (case-insensitive)
   IF Len(aVarData) > 0
      ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
      
      // Send sorted variables
      FOR i := nStart+1 TO Min(nStart+nCount, Len(aVarData))
         hb_inetSend(oDebugInfo["socket"], ;
            aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_PUBLICS" + CRLF)
RETURN

// Check if current position is a breakpoint
STATIC FUNCTION InBreakpoint()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL cFile := ""
   LOCAL nLine := 0
   LOCAL cKey, i, aStack
   
   
   // Get current position from stack
   IF Len(oDebugInfo["aStack"]) > 0
      aStack := ATail(oDebugInfo["aStack"])
      cFile := Lower(AllTrim(aStack[HB_DBG_CS_MODULE]))
      nLine := aStack[HB_DBG_CS_LINE]
   ELSE
      // Fallback to ProcFile/ProcLine
      FOR i := 2 TO 5
         cFile := ProcFile(i)
         IF !Empty(cFile) .AND. !("harbour_debug" $ Lower(cFile))
            cFile := Lower(AllTrim(cFile))
            nLine := ProcLine(i)
            EXIT
         ENDIF
      NEXT
   ENDIF
   
   // Extract filename without path
   i := RAt("/", cFile)
   IF i == 0
      i := RAt("\", cFile)
   ENDIF
   IF i > 0
      cFile := SubStr(cFile, i + 1)
   ENDIF
   
   cKey := cFile + ":" + AllTrim(Str(nLine))
   
   // Check if this file:line has a breakpoint
   IF hb_HHasKey(oDebugInfo["aBreaks"], cKey)
      RETURN .T.
   ENDIF
   
RETURN .F.

// Check if current HB_DBG_ACTIVATE was triggered by AltD()
STATIC FUNCTION IsAltDStop()
   IF __dbgInvokeDebug()
      __dbgInvokeDebug(.T.)  // Clear flag after detecting
      RETURN .T.
   ENDIF
   
RETURN .F.

// Set a breakpoint
STATIC PROCEDURE SetBreakpoint(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, cOp, cFile, nLine, cKey, i
   
   // Parse: +/-:filename:line
   aParams := hb_ATokens(cParams, ":")
   IF Len(aParams) >= 3
      cOp := aParams[1]
      cFile := Lower(AllTrim(aParams[2]))
      nLine := Val(aParams[3])
      
      // Extract filename without path
      i := RAt("/", cFile)
      IF i == 0
         i := RAt("\", cFile)
      ENDIF
      IF i > 0
         cFile := SubStr(cFile, i + 1)
      ENDIF
      
      cKey := cFile + ":" + AllTrim(Str(nLine))
      
      IF cOp == "+"
         oDebugInfo["aBreaks"][cKey] := .T.
         hb_inetSend(oDebugInfo["socket"], "BREAK:" + cFile + ":" + Str(nLine) + ":" + Str(nLine) + CRLF)
      ELSE
         hb_HDel(oDebugInfo["aBreaks"], cKey)
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
         cResult := AllTrim(Str(xValue))
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

// Send array elements for a specific array variable
STATIC PROCEDURE SendArrayElements(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, cScope, cArrayName, nStart, nCount
   LOCAL xArray, xElement, cType, i
   LOCAL vmStack, aStack
   LOCAL nStackIndex, l
   LOCAL tmp, vName, nPrivates, nPublics, cName, xValue, nEnd
   LOCAL cBaseName, aIndices, nPos, cIndex
   
   oDebugInfo := __DEBUGITEM()
   vmStack := oDebugInfo["vmStack"]
   
   // Parse parameters: scope:arrayName:start:count
   aParams := hb_ATokens(cParams, ":")
   IF Len(aParams) < 2
      hb_inetSend(oDebugInfo["socket"], "ARRAY" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "END_ARRAY" + CRLF)
      RETURN
   ENDIF
   
   cScope := aParams[1]
   cArrayName := aParams[2]
   nStart := IF(Len(aParams) >= 3, Val(aParams[3]), 1)
   nCount := IF(Len(aParams) >= 4, Val(aParams[4]), 100)
   
   // Handle nested array notation (e.g., "FOO[2]" or "FOO[2][3]" or hash "GAGA[\"Bar\"]")
   cBaseName := cArrayName
   aIndices := {}
   
   // Extract base name and indices
   IF "[" $ cArrayName
      nPos := At("[", cArrayName)
      cBaseName := Left(cArrayName, nPos - 1)
      // Parse all indices
      cIndex := SubStr(cArrayName, nPos)
      DO WHILE "[" $ cIndex
         nPos := At("[", cIndex)
         cIndex := SubStr(cIndex, nPos + 1)
         nPos := At("]", cIndex)
         IF nPos > 0
            // Check if it's a hash key (starts with quote) or array index
            IF Left(cIndex, 1) == '"'
               // Hash key - extract string between quotes
               AAdd(aIndices, SubStr(cIndex, 2, nPos - 3))  // Skip quotes
            ELSE
               // Array index - convert to number
               AAdd(aIndices, Val(Left(cIndex, nPos - 1)))
            ENDIF
            cIndex := SubStr(cIndex, nPos + 1)
         ELSE
            EXIT
         ENDIF
      ENDDO
   ENDIF
   
   // Get the array variable based on scope
   xArray := NIL
   
   DO CASE
      CASE cScope == "LOCALS"
         // Get local variable by name
         IF vmStack != NIL .AND. Len(vmStack) > 0
            // Use the top stack frame (same as in SendLocals)
            nStackIndex := 1  // Use first frame 
            IF nStackIndex > 0 .AND. nStackIndex <= Len(vmStack)
               // Search for the variable in locals
               FOR i := 1 TO Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
                  tmp := vmStack[nStackIndex, HB_DBG_CS_LOCALS, i]
                  IF Upper(tmp[HB_DBG_VAR_NAME]) == Upper(cBaseName)
                     xArray := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
         
      CASE cScope == "PRIVATES"
         // Get private variable by name
         nPrivates := __mvDbgInfo(HB_MV_PRIVATE)
         FOR i := 1 TO nPrivates
            xValue := __mvDbgInfo(HB_MV_PRIVATE, i, @cName)
            IF Upper(cName) == Upper(cBaseName)
               xArray := xValue
               EXIT
            ENDIF
         NEXT
         
      CASE cScope == "PUBLICS"
         // Get public variable by name
         nPublics := __mvDbgInfo(HB_MV_PUBLIC)
         FOR i := 1 TO nPublics
            xValue := __mvDbgInfo(HB_MV_PUBLIC, i, @cName)
            IF Upper(cName) == Upper(cBaseName)
               xArray := xValue
               EXIT
            ENDIF
         NEXT
         
      CASE cScope == "STATICS"
         // Get static variable - this is more complex and may require module info
         // For now, send empty response
         xArray := NIL
   ENDCASE
   
   // Navigate through nested array/hash indices if any
   IF xArray != NIL .AND. Len(aIndices) > 0
      FOR i := 1 TO Len(aIndices)
         IF ValType(aIndices[i]) == "C"
            // String index - it's a hash key
            IF ValType(xArray) == "H" .AND. aIndices[i] $ xArray
               xArray := xArray[aIndices[i]]
            ELSE
               xArray := NIL
               EXIT
            ENDIF
         ELSE
            // Numeric index - it's an array index
            IF ValType(xArray) == "A" .AND. aIndices[i] > 0 .AND. aIndices[i] <= Len(xArray)
               xArray := xArray[aIndices[i]]
            ELSE
               xArray := NIL
               EXIT
            ENDIF
         ENDIF
      NEXT
   ENDIF
   
   // Send array elements
   hb_inetSend(oDebugInfo["socket"], "ARRAY" + CRLF)
   hb_inetSend(oDebugInfo["socket"], cScope + ":" + cArrayName + CRLF)
   
   IF ValType(xArray) == "A"
      // Send array elements within the requested range
      nEnd := Min(nStart + nCount - 1, Len(xArray))
      
      FOR i := nStart TO nEnd
         xElement := xArray[i]
         cType := ValType(xElement)
         hb_inetSend(oDebugInfo["socket"], ;
            AllTrim(Str(i)) + ":" + cType + ":" + FormatValue(xElement) + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_ARRAY" + CRLF)
RETURN

// Send hash elements for a specific hash variable
STATIC PROCEDURE SendHashElements(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, cScope, cHashName
   LOCAL xHash, cKey, xValue, cType
   LOCAL vmStack
   LOCAL nStackIndex
   LOCAL tmp, vName, nPrivates, nPublics, cName
   LOCAL cBaseName, aIndices, nPos, cIndex
   LOCAL aKeys, i
   
   oDebugInfo := __DEBUGITEM()
   vmStack := oDebugInfo["vmStack"]
   
   // Parse parameters: scope:hashName
   aParams := hb_ATokens(cParams, ":")
   IF Len(aParams) < 2
      hb_inetSend(oDebugInfo["socket"], "HASH" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "ERROR:Invalid hash parameters" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "END_HASH" + CRLF)
      RETURN
   ENDIF
   
   cScope := aParams[1]
   cHashName := aParams[2]
   
   // Initialize xHash to NIL
   xHash := NIL
   
   // Handle nested hash notation like "MYHASH[\"key1\"]"
   IF "[" $ cHashName
      // Extract base name and indices
      nPos := At("[", cHashName)
      cBaseName := Left(cHashName, nPos - 1)
      aIndices := {}
      cIndex := SubStr(cHashName, nPos)
      
      // Parse hash keys from notation like "[\"key1\"][\"key2\"]"
      DO WHILE "[" $ cIndex
         nPos := At("]", cIndex)
         IF nPos > 0
            // Extract key between [" and "]
            tmp := SubStr(cIndex, 3, nPos - 4)  // Skip [" and "]
            AAdd(aIndices, tmp)
            cIndex := SubStr(cIndex, nPos + 1)
         ELSE
            EXIT
         ENDIF
      ENDDO
      
      cHashName := cBaseName
   ELSE
      aIndices := {}
   ENDIF
   
   // Find the hash variable based on scope
   DO CASE
   CASE cScope == "LOCALS"
      // Search in local variables (same as arrays)
      IF vmStack != NIL .AND. Len(vmStack) > 0
         nStackIndex := 1  // Use first frame
         IF nStackIndex > 0 .AND. nStackIndex <= Len(vmStack)
            // Search for the variable in locals
            FOR i := 1 TO Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
               tmp := vmStack[nStackIndex, HB_DBG_CS_LOCALS, i]
               IF Upper(tmp[HB_DBG_VAR_NAME]) == Upper(cHashName)
                  xHash := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                  EXIT
               ENDIF
            NEXT
         ENDIF
      ENDIF
      
   CASE cScope == "STATICS"
      // Search in static variables
      IF Type(cHashName) != "U"
         xHash := &(cHashName)
      ENDIF
      
   CASE cScope == "PRIVATES"
      // Search in private variables
      nPrivates := __mvDbgInfo(HB_MV_PRIVATE)
      FOR tmp := 1 TO nPrivates
         vName := __mvDbgInfo(HB_MV_PRIVATE, tmp, @xValue)
         IF vName == cHashName
            xHash := xValue
            EXIT
         ENDIF
      NEXT
      
   CASE cScope == "PUBLICS"
      // Search in public variables
      nPublics := __mvDbgInfo(HB_MV_PUBLIC)
      FOR tmp := 1 TO nPublics
         vName := __mvDbgInfo(HB_MV_PUBLIC, tmp, @xValue)
         IF vName == cHashName
            xHash := xValue
            EXIT
         ENDIF
      NEXT
   ENDCASE
   
   // Navigate through nested hashes using indices
   IF Len(aIndices) > 0 .AND. xHash != NIL
      FOR i := 1 TO Len(aIndices)
         IF ValType(xHash) == "H" .AND. aIndices[i] $ xHash
            xHash := xHash[aIndices[i]]
         ELSE
            xHash := NIL
            EXIT
         ENDIF
      NEXT
   ENDIF
   
   // Send hash elements
   hb_inetSend(oDebugInfo["socket"], "HASH" + CRLF)
   hb_inetSend(oDebugInfo["socket"], cScope + ":" + cHashName + CRLF)
   
   IF ValType(xHash) == "H"
      // Get all hash keys
      aKeys := hb_HKeys(xHash)
      
      // Send each key-value pair
      FOR i := 1 TO Len(aKeys)
         cKey := aKeys[i]
         xValue := xHash[cKey]
         cType := ValType(xValue)
         hb_inetSend(oDebugInfo["socket"], ;
            cKey + ":" + cType + ":" + FormatValue(xValue) + CRLF)
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_HASH" + CRLF)
RETURN

// Send list of all open workareas
STATIC PROCEDURE SendWorkAreas()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aAreas := {}
   LOCAL nOldArea := Select()
   LOCAL i, aArea
   
   // Enumerate all open workareas using hb_WAEval
   hb_WAEval( {|| IIF( Used(), AAdd( aAreas, { Select(), Alias(), RecNo(), LastRec(), FCount(), IIF(IndexOrd() > 0, OrdKey(), ""), RddName() } ), NIL ) } )
   
   // Restore original workarea
   dbSelectArea( nOldArea )
   
   // Send workarea enumeration
   hb_inetSend(oDebugInfo["socket"], "WORKAREAS" + CRLF)
   
   IF Len(aAreas) > 0
      FOR i := 1 TO Len(aAreas)
         aArea := aAreas[i]
         // Format: AREA:Alias:Area:fCount:recno:reccount:scope:
         hb_inetSend(oDebugInfo["socket"], "AREA:" + ;
                     aArea[2] + ":" + ;                    // Alias
                     AllTrim(Str(aArea[1])) + ":" + ;      // Area number
                     AllTrim(Str(aArea[5])) + ":" + ;      // Field count
                     AllTrim(Str(aArea[3])) + ":" + ;      // Current record
                     AllTrim(Str(aArea[4])) + ":" + ;      // Total records
                     aArea[6] + ":" + CRLF)                // Index scope/key
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_WORKAREAS" + CRLF)
RETURN

// Handle specific area commands (AREA1:FIELDS, AREA1:RECORD, etc.)
STATIC PROCEDURE HandleAreaCommand(cCommand)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams := hb_ATokens(cCommand, ":")
   LOCAL nArea, cSubCommand, nOldArea
   
   IF Len(aParams) < 2
      RETURN
   ENDIF
   
   // Parse AREA{n}:{subcommand}
   nArea := Val(SubStr(aParams[1], 5))  // Extract number from "AREA{n}"
   cSubCommand := Upper(aParams[2])
   
   // Validate area number
   IF nArea < 1 .OR. nArea > 65535
      RETURN
   ENDIF
   
   nOldArea := Select()
   dbSelectArea( nArea )
   
   IF !Used()
      dbSelectArea( nOldArea )
      RETURN
   ENDIF
   
   DO CASE
      CASE cSubCommand == "FIELDS"
         SendAreaFields(nArea)
         
      CASE cSubCommand == "RECORD"
         SendAreaRecord(nArea)
         
      CASE cSubCommand == "SCHEMA"
         SendAreaSchema(nArea)
         
   ENDCASE
   
   dbSelectArea( nOldArea )
RETURN

// Send field structure for specific workarea
STATIC PROCEDURE SendAreaFields(nArea)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aStruct := dbStruct()
   LOCAL i, aField
   
   hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":FIELDS" + CRLF)
   
   FOR i := 1 TO Len(aStruct)
      aField := aStruct[i]
      // Format: FIELD:name:type:length:decimals:
      hb_inetSend(oDebugInfo["socket"], "FIELD:" + ;
                  aField[1] + ":" + ;                      // Field name
                  aField[2] + ":" + ;                      // Field type
                  AllTrim(Str(aField[3])) + ":" + ;        // Field length
                  AllTrim(Str(aField[4])) + ":" + CRLF)    // Decimal places
   NEXT
   
   hb_inetSend(oDebugInfo["socket"], "END_FIELDS" + CRLF)
RETURN

// Send current record data for specific workarea
STATIC PROCEDURE SendAreaRecord(nArea)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL i, xValue, cFieldName
   
   hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":RECORD" + CRLF)
   
   FOR i := 1 TO FCount()
      cFieldName := FieldName(i)
      xValue := FieldGet(i)
      
      // Format: VALUE:fieldname:type:value:
      hb_inetSend(oDebugInfo["socket"], "VALUE:" + ;
                  cFieldName + ":" + ;
                  FieldType(i) + ":" + ;
                  FormatValue(xValue) + ":" + CRLF)
   NEXT
   
   hb_inetSend(oDebugInfo["socket"], "END_RECORD" + CRLF)
RETURN

// Send complete schema information for specific workarea
STATIC PROCEDURE SendAreaSchema(nArea)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL cAlias := Alias()
   
   hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":SCHEMA" + CRLF)
   
   // Send basic info
   hb_inetSend(oDebugInfo["socket"], "INFO:ALIAS:" + cAlias + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:RDD:" + RddName() + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:RECCOUNT:" + AllTrim(Str(LastRec())) + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:RECNO:" + AllTrim(Str(RecNo())) + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:BOF:" + IF(Bof(), "T", "F") + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:EOF:" + IF(Eof(), "T", "F") + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:DELETED:" + IF(Deleted(), "T", "F") + CRLF)
   hb_inetSend(oDebugInfo["socket"], "INFO:FOUND:" + IF(Found(), "T", "F") + CRLF)
   
   // Send filter if any
   IF !Empty(DbFilter())
      hb_inetSend(oDebugInfo["socket"], "INFO:FILTER:" + DbFilter() + CRLF)
   ENDIF
   
   // Send index information if any
   IF IndexOrd() > 0
      hb_inetSend(oDebugInfo["socket"], "INFO:INDEX:" + AllTrim(Str(IndexOrd())) + CRLF)
      hb_inetSend(oDebugInfo["socket"], "INFO:INDEXKEY:" + OrdKey() + CRLF)
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_SCHEMA" + CRLF)
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

// Load breakpoints from init.cld file (IntelliJ pre-set breakpoints)
STATIC PROCEDURE LoadBreakpoints()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL cFile := "init.cld"
   LOCAL cContent, aLines, cLine, aTokens, nLine, cFileName, cKey, i, j
   
   IF !File(cFile)
      RETURN
   ENDIF
   
   cContent := hb_MemoRead(cFile)
   IF !Empty(cContent)
      aLines := hb_ATokens(cContent, Chr(10))
      FOR j := 1 TO Len(aLines)
         cLine := AllTrim(StrTran(aLines[j], Chr(13), ""))
         IF !Empty(cLine) .AND. Left(cLine, 2) == "BP"
            // Parse: BP line_number filename
            aTokens := hb_ATokens(cLine, " ")
            IF Len(aTokens) >= 3
               nLine := Val(aTokens[2])
               cFileName := Lower(AllTrim(aTokens[3]))
               
               // Extract filename without path
               i := RAt("/", cFileName)
               IF i == 0
                  i := RAt("\", cFileName)
               ENDIF
               IF i > 0
                  cFileName := SubStr(cFileName, i + 1)
               ENDIF
               
               cKey := cFileName + ":" + AllTrim(Str(nLine))
               oDebugInfo["aBreaks"][cKey] := .T.
            ENDIF
         ENDIF
      NEXT
   ENDIF
RETURN

// Initialize the debugger when the library is loaded
INIT PROCEDURE __InitIntelliJDebugger()
   LOCAL oDebugInfo

   // altd() // REMOVED - this was triggering Harbour debugger instead of PyCharm
   
   // CRITICAL FIX v1.0.349: Do NOT force console settings - interferes with main program I/O
   // Set( _SET_CONSOLE, .T. )     // REMOVED - causes qout()/wait conflicts
   // Set( _SET_ALTERNATE, .F. )   // REMOVED - causes qout()/wait conflicts  
   // Set( _SET_DEVICE, "SCREEN" ) // REMOVED - causes qout()/wait conflicts
   // Set( _SET_BELL, .F. )        // REMOVED - causes qout()/wait conflicts
   
   // Initialize debug info
   oDebugInfo := __DEBUGITEM()
   
   // Register our debugger with the VM
   __dbgSetEntry()
   
   // Enable debugging
   Set( _SET_DEBUG, .T. )
   
   // Set running state to true initially
   oDebugInfo["lRunning"] := .T.
   
   // Load pre-set breakpoints from init.cld
   LoadBreakpoints()
RETURN

// Override AltD() to trigger debugger (WORKING SOLUTION FROM GIT HISTORY)
PROCEDURE AltD()
   LOCAL t_oDebugInfo := __DEBUGITEM()
   
   // Ensure debugger is initialized
   IF !t_oDebugInfo["lInitialized"]
      // Manual initialization since we can't call INIT procedure
      // CRITICAL FIX v1.0.349: Do NOT force console settings in AltD either
      // Set( _SET_CONSOLE, .T. )     // REMOVED - causes qout()/wait conflicts
      // Set( _SET_ALTERNATE, .F. )   // REMOVED - causes qout()/wait conflicts
      // Set( _SET_DEVICE, "SCREEN" ) // REMOVED - causes qout()/wait conflicts
      // Set( _SET_BELL, .F. )        // REMOVED - causes qout()/wait conflicts
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
   ENDIF
RETURN
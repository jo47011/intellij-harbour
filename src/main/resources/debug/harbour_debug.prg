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
STATIC s_lSocketEnabled := .T.  // Enable socket communication

// Set up global error handler for entire application
INIT PROCEDURE SetGlobalErrorHandler()
   LOCAL hLog, oCurrentHandler
   
   // Get current error handler for debugging
   oCurrentHandler := ErrorBlock()
   
   // Set the global error handler - avoid recursion by using TRY/CATCH
   ErrorBlock({|oError| IIF(oError != NIL, GlobalErrorHandler(oError), NIL)})
   
   // Try to establish early socket connection for error reporting
   // Note: We cannot initialize the debug info here because it uses hash syntax
   // which may not be available yet during INIT procedures
   // The socket connection will be established when __dbgEntry is called
   
   // Removed hardcoded log files - using stderr for essential debug messages only
   // Use environment variable HB_REMOTE_DEBUG_LOG to enable debug logging if needed
RETURN

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
   LOCAL i, tmp, j, vv, oDebugInfo, lAltDInvoked, hLog

   // Suppress unused parameter warnings
   HB_SYMBOL_UNUSED(uParam4)
   HB_SYMBOL_UNUSED(vv)
   
   // Add error handling and stacktrace logging
   BEGIN SEQUENCE WITH {|err| ErrorHandler(err, nMode) }

   // altd() // REMOVED - this was triggering Harbour debugger instead of PyCharm

   // ALWAYS set global error handler when debug system is activated
   // Don't check if empty - always override to ensure our handler is active
   ErrorBlock({|oError| GlobalErrorHandler(oError)})
   
   // Removed hardcoded debug log file - error handler is set silently

   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Register with VM - this works
      __dbgSetEntry()
//       ? "IntelliJ Debug Handler registered with breakpoint support"
      
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
      
      // Enhanced AltD() detection with debugging
//       ? "=== HB_DBG_SHOWLINE DEBUG - Line", uParam1, "==="
//       ? "Checking AltD() status..."
      lAltDInvoked := __dbgInvokeDebug()  // Check without clearing
//       ? "AltD() result:", lAltDInvoked
      IF lAltDInvoked
         __dbgInvokeDebug(.T.)  // Clear the flag after detecting
      ENDIF
      
      // Update current line in stack
      IF Len(oDebugInfo["aStack"]) > 0
         ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE] := uParam1
      ENDIF
      
      // Check socket and process commands if enabled
      // Also check if AltD() was invoked to force a stop
      IF s_lSocketEnabled
         IF lAltDInvoked
//             ? "=== HB_DBG_SHOWLINE: AltD() DETECTED! ==="
            // Force a stop by setting running to false
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
//       ? "=== HB_DBG_ACTIVATE - IntelliJ Variable Display ==="
//       ? "Level:", __dbgProcLevel()
      
      IF uParam3 != NIL .AND. ValType(uParam3) == "A"
         FOR i := 1 TO Len(uParam3)
//             ? "Stack " + AllTrim(Str(i)) + ":" + uParam3[i,HB_DBG_CS_MODULE] + "-" + uParam3[i,HB_DBG_CS_FUNCTION] + ;
//               "(" + AllTrim(Str(uParam3[i,HB_DBG_CS_LINE])) + ")*" + AllTrim(Str(uParam3[i,HB_DBG_CS_LEVEL])) + ;
//               " " + AllTrim(Str(Len(uParam3[i,HB_DBG_CS_LOCALS]))) + " locals"
              
            // Show local variables with actual names
            FOR j := 1 TO Len(uParam3[i,HB_DBG_CS_LOCALS])
               tmp := uParam3[i,HB_DBG_CS_LOCALS,j]
               vv := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
               HB_SYMBOL_UNUSED(vv)  // Used for debugging when needed
//                ? "  Local " + AllTrim(Str(j)) + ": " + tmp[HB_DBG_VAR_NAME] + " (" + tmp[HB_DBG_VAR_TYPE] + ") = " + hb_CStr(vv)
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
//       ? "DEBUG: VM Quitting"
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
   LOCAL hErrorLog, i, cErrorMsg
   
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
   // ? "Error BASE/" + AllTrim(Str(oError:GenCode)) + " " + oError:Description
   // ? "Called from " + ProcName(1) + "(" + AllTrim(Str(ProcLine(1))) + ")"
   
   // Re-raise the error so the program crashes as expected
   BREAK(oError)
   // RETURN statement removed as it's unreachable after BREAK

// Global error handler for entire application (not just debug system)
// Handles ALL runtime errors uniformly: array bounds, type mismatches, division by zero, file errors, etc.
// All errors are displayed in PyCharm console via socket (debug mode) or file monitoring (normal run mode)
FUNCTION GlobalErrorHandler(oError)
   LOCAL hErrorLog, oDebugInfo, cErrorMsg, hPyCharmLog, cProcName, cProcLine, cFileName
   STATIC s_lInErrorHandler := .F.
   
   // Prevent recursion - if we're already in error handler, just exit
   IF s_lInErrorHandler
      RETURN NIL
   ENDIF
   s_lInErrorHandler := .T.
   
   // Removed hardcoded error handler log file
   
   oDebugInfo := __DEBUGITEM()
   
   // Send error to PyCharm console via socket only (no file monitoring)
   // Let's examine the error object more carefully to find the right location
   
   // Removed error object debug log file
   
   // Use ProcName(2), ProcLine(2) to skip the error handler frame
   cProcName := ProcName(2)
   cProcLine := AllTrim(Str(ProcLine(2)))
   cFileName := ProcFile(2)
   
   cErrorMsg := "RUNTIME ERROR: " + oError:Description + " at " + cProcName + "(" + cProcLine + ")"
   
   // Try to send via socket first (if connected)
   IF !Empty(oDebugInfo["socket"])
      hb_inetSend(oDebugInfo["socket"], "ERROR_MSG:" + cErrorMsg + CRLF)
      hb_inetSend(oDebugInfo["socket"], "ERROR_STACK:" + cProcName + "(" + cProcLine + ") in " + cFileName + CRLF)
   ELSE
      // No socket connection - fallback to stderr only (no hardcoded files)
      
      // Also try stderr as fallback
      FWrite(2, cErrorMsg + CRLF)
      FWrite(2, "Stack: " + cProcName + "(" + cProcLine + ") in " + cFileName + CRLF)
   ENDIF
   
   // Removed global error log file - errors are sent via socket or stderr
   
   // Reset recursion flag before re-raising error
   s_lInErrorHandler := .F.
   
   // Re-raise the error properly to prevent "Error recovery failure"
   // ABSOLUTELY NO STDOUT OUTPUT - prevents popup console completely
   IF .T.  // Always true, but avoids unreachable code warning
      BREAK(oError)
   ENDIF
   
   // This return satisfies function requirement but won't be reached
   RETURN NIL

// Test function to verify error handler is working
FUNCTION TestErrorHandler()
   LOCAL hLog, aTest
   
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
   LOCAL hLog  // Add detailed logging to trace GUI crash
   LOCAL nLoopCount, nMaxLoops  // Prevent infinite loops that crash GUI
   
   lStopSent := IF(Empty(lStopSent), .F., lStopSent)
   
   // Simple error handling to prevent crashes
   BEGIN SEQUENCE
   
   // Removed debug trace log file - socket debugging disabled to avoid file clutter
   LOCAL hLog := -1  // Keep variable for existing code compatibility
   
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
   
   // CRITICAL FIX v1.0.350: Add timeout to prevent GUI crashes from infinite loops
   nLoopCount := 0
   nMaxLoops := 1000  // Variables already declared at function start
   
   // Loop with timeout (logging removed)
   
   // Main command loop with safety timeout
   DO WHILE .T. .AND. nLoopCount < nMaxLoops
      nLoopCount++
      
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
//             ? "DEBUG: Breakpoint detected, stopping"
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
   
   // CRITICAL FIX v1.0.350: Safety exit if loop limit exceeded 
   IF nLoopCount >= nMaxLoops
      // Timeout reached - emergency exit (logging removed)
      // Emergency exit to prevent GUI crashes
      oDebugInfo["socket"] := NIL
      oDebugInfo["lRunning"] := .T.
      oDebugInfo["aBreaks"] := {=>}
   ELSE
      // Normal exit from CheckSocket (logging removed)
   ENDIF
   
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
//    ? "=== SendLocals DEBUG ==="
//    ? "Request params:", cParams
//    ? "Parsed - nLevel:", nLevel, "nStart:", nStart, "nCount:", nCount
//    ? "__dbgEntryLevel:", oDebugInfo["__dbgEntryLevel"]
//    ? "VM Stack frames count:", IF(vmStack == NIL, 0, Len(vmStack))
   
   IF vmStack != NIL
      FOR i := 1 TO Len(vmStack)
//          ? "  VM Stack[" + Str(i) + "] level:", vmStack[i, HB_DBG_CS_LEVEL], "locals:", Len(vmStack[i, HB_DBG_CS_LOCALS])
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "LOCALS" + CRLF)
   
   // Check if we have VM stack data
   IF vmStack == NIL .OR. Len(vmStack) == 0
//       ? "NO VM STACK DATA AVAILABLE"
      hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
      RETURN
   ENDIF
   
   // For level 0, use the first (top) stack frame
   IF nLevel == 0 .AND. Len(vmStack) > 0
      nStackIndex := 1  // Use first frame for level 0
//       ? "Using stack frame 1 for level 0 request"
   ELSE
      // EXACT VSCode formula for stack lookup
      l := oDebugInfo["__dbgEntryLevel"] - nLevel
//       ? "Calculated l value:", l, "(from", oDebugInfo["__dbgEntryLevel"], "-", nLevel, ")"
      
      // Find stack frame with exact matching level
      nStackIndex := 0
      FOR i := Len(vmStack) TO 1 STEP -1
//          ? "Checking VM stack[" + Str(i) + "] level:", vmStack[i, HB_DBG_CS_LEVEL], "vs target l:", l
         IF vmStack[i, HB_DBG_CS_LEVEL] == l
            nStackIndex := i
//             ? "FOUND matching VM stack frame at index:", nStackIndex
            EXIT
         ENDIF
      NEXT
   ENDIF
   
//    ? "Final nStackIndex:", nStackIndex
   
   // Send locals if stack frame found
   IF nStackIndex > 0 .AND. nStackIndex <= Len(vmStack)
//       ? "VM Stack frame found - locals count:", Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
      IF Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
         // Collect all variables first
         FOR i := 1 TO Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
            aInfo := vmStack[nStackIndex, HB_DBG_CS_LOCALS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            
//             ? "Processing local[" + Str(i) + "]:", cName, "frame:", aInfo[HB_DBG_VAR_FRAME], "index:", aInfo[HB_DBG_VAR_INDEX]
            
            // Get variable value using stored frame level
            xValue := __dbgVMVarLGet(__dbgProcLevel() - aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            
//             ? "Got value:", cName, "=", xValue, "type:", cType
            
            AAdd(aVarData, {cName, cType, FormatValue(xValue)})
         NEXT
         
         // Sort alphabetically by variable name (case-insensitive)
         ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
         
         // Send sorted variables
         n := 0
         FOR i := 1 TO Len(aVarData)
            IF n >= nStart .AND. n < nStart + nCount
//                ? "SENDING:", aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3]
               hb_inetSend(oDebugInfo["socket"], ;
                  aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
            ELSE
//                ? "SKIPPING (out of range):", aVarData[i,1], "n=" + Str(n)
            ENDIF
            n++
         NEXT
      ELSE
//          ? "No locals in VM stack frame"
      ENDIF
   ELSE
//       ? "NO VM STACK FRAME FOUND for index:", nStackIndex
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
//    ? "=== SendStatics DEBUG (FIXED VERSION) ==="
//    ? "Request params:", cParams
//    ? "Parsed nLevel:", nLevel
//    ? "__dbgEntryLevel:", oDebugInfo["__dbgEntryLevel"]
//    ? "aStack count:", Len(aStack)
//    ? "aModules count:", Len(aModules)
   
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
//          ? "Module statics found, count:", Len(aModules[nModIndex, 4])
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
//          ? "Function-local statics found, count:", Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
            aInfo := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            xValue := __dbgVMVarSGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            AAdd(aVarData, {cName, cType, FormatValue(xValue)})
         NEXT
         lFoundAny := .T.
      ENDIF
   ELSE
//       ? "NO STACK FRAME FOUND (aStack empty or nStackIndex=0)"
   ENDIF
   
   // FALLBACK: If no statics found via module system, try direct access
   IF !lFoundAny
//       ? "No module/stack statics found - trying direct enumeration..."
      
      // NEW APPROACH: Try to access known static variables by name
      // This bypasses the broken module registration system
//       ? "Trying direct static variable access by name..."
      
      // First test if Type() function works with a known variable
//       ? "Testing Type() function with 'CMESSAGE':", Type("CMESSAGE")
      
      FOR i := 1 TO Len(aStaticNames)
//          ? "Testing Type() for:", aStaticNames[i], "Result:", Type(aStaticNames[i])
         IF Type(aStaticNames[i]) != "U"
            xValue := &(aStaticNames[i])
            cType := ValType(xValue)
//             ? "Found static by name:", aStaticNames[i], "=", hb_CStr(xValue), "type:", cType
            AAdd(aVarData, {aStaticNames[i], cType, FormatValue(xValue)})
            lFoundAny := .T.
         ELSE
//             ? "Static variable not accessible:", aStaticNames[i]
         ENDIF
      NEXT
      
      IF !lFoundAny
//          ? "No static variables found by name lookup either"
      ENDIF
   ENDIF
   
   // Sort and send all statics
   IF Len(aVarData) > 0
      ASort(aVarData,,, {|a, b| Upper(a[1]) < Upper(b[1])})
      FOR i := 1 TO Len(aVarData)
         hb_inetSend(oDebugInfo["socket"], ;
            aVarData[i,1] + ":" + aVarData[i,2] + ":" + aVarData[i,3] + CRLF)
      NEXT
   ENDIF
   
//    ? "Total static variables collected:", Len(aVarData)
//    ? "=== END SendStatics ==="
   
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
   
//    ? "=== SendPrivates DEBUG ==="
//    ? "Request params:", cParams  
//    ? "Parsed - nLevel:", nLevel, "nStart:", nStart, "nCount:", nCount
//    ? "__dbgProcLevel():", __dbgProcLevel()
//    ? "Private vars count (local to level):", nLocal
   
   IF nCount == 0
      nCount := nLocal
   ENDIF
   
   // Try getting all privates first
   nAllPrivates := __mvDbgInfo(HB_MV_PRIVATE)
//    ? "Total private vars (all levels):", nAllPrivates
   
   // Collect private variables first
   IF nLocal > 0
//       ? "Collecting local privates..."
      FOR i := 1 TO nLocal
         xValue := __mvDbgInfo(HB_MV_PRIVATE_LOCAL, i, @cName, __dbgProcLevel() - nLevel)
         cType := ValType(xValue)
//          ? "Private local[" + Str(i) + "]:", cName, "=", hb_CStr(xValue), "type:", cType
         // Show all private variables including GETLIST (user may define it locally)
         AAdd(aVarData, {cName, cType, FormatValue(xValue)})
      NEXT
   ELSEIF nAllPrivates > 0
//       ? "No local privates, collecting all privates..."
      FOR i := 1 TO nAllPrivates
         xValue := __mvDbgInfo(HB_MV_PRIVATE, i, @cName)
         cType := ValType(xValue)
//          ? "Private[" + Str(i) + "]:", cName, "=", hb_CStr(xValue), "type:", cType
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
   ELSE
//       ? "No private variables found"
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
   
//    ? "=== InBreakpoint DEBUG ==="
//    ? "Custom stack count:", Len(oDebugInfo["aStack"])
//    ? "VM stack available:", (oDebugInfo["vmStack"] != NIL)
   
   // Get current position from stack
   IF Len(oDebugInfo["aStack"]) > 0
      aStack := ATail(oDebugInfo["aStack"])
      cFile := Lower(AllTrim(aStack[HB_DBG_CS_MODULE]))
      nLine := aStack[HB_DBG_CS_LINE]
//       ? "Using custom stack - file:", cFile, "line:", nLine
   ELSE
      // Fallback to ProcFile/ProcLine
//       ? "Custom stack empty, using ProcFile/ProcLine fallback"
      FOR i := 2 TO 5
         cFile := ProcFile(i)
//          ? "  ProcFile(" + Str(i) + "):", cFile, "ProcLine(" + Str(i) + "):", ProcLine(i)
         IF !Empty(cFile) .AND. !("harbour_debug" $ Lower(cFile))
            cFile := Lower(AllTrim(cFile))
            nLine := ProcLine(i)
//             ? "  SELECTED - file:", cFile, "line:", nLine
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
//    ? "Checking breakpoint key:", cKey
//    ? "Available breakpoints:", hb_HKeys(oDebugInfo["aBreaks"])
   
   // Check if this file:line has a breakpoint
   IF hb_HHasKey(oDebugInfo["aBreaks"], cKey)
//       ? "BREAKPOINT HIT at", cKey
      RETURN .T.
   ELSE
//       ? "No breakpoint at", cKey
   ENDIF
   
RETURN .F.

// Check if current HB_DBG_ACTIVATE was triggered by AltD()
STATIC FUNCTION IsAltDStop()
   // Check if AltD() was invoked using the VM's debug invoke flag
   IF __dbgInvokeDebug()
//       ? "AltD() invoked - forcing debug stop"
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
//          ? "Breakpoint set at", cKey
      ELSE
         hb_HDel(oDebugInfo["aBreaks"], cKey)
//          ? "Breakpoint removed at", cKey
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
//       ? "No init.cld file found - breakpoints will be set via socket commands"
      RETURN
   ENDIF
   
//    ? "Loading breakpoints from init.cld..."
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
//                ? "Loaded breakpoint:", cKey
            ENDIF
         ENDIF
      NEXT
//       ? "Breakpoints loaded:", Len(oDebugInfo["aBreaks"])
   ELSE
//       ? "Could not read init.cld file"
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
   
//    ? "IntelliJ Harbour Debugger with breakpoint support initializing..."
   
   // Set running state to true initially
   oDebugInfo["lRunning"] := .T.
   
   // Load pre-set breakpoints from init.cld
   LoadBreakpoints()
   
//    ? "Debugger initialized - ready for breakpoints and variable display"
RETURN

// Override AltD() to trigger debugger (WORKING SOLUTION FROM GIT HISTORY)
PROCEDURE AltD()
   LOCAL t_oDebugInfo := __DEBUGITEM()
   
//    ? "AltD() called"
   
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
   ELSE
//       ? "AltD: Debugger not connected"
   ENDIF
RETURN
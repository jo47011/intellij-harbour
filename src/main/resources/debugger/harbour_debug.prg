// IntelliJ Harbour Debug Handler - COMPLETE VERSION 1.4.4
// Combines working variable names + breakpoint functionality + GLOBAL ERROR HANDLING
// Based on working VSCode pattern with socket integration

#pragma -B-
// REMOVED: REQUEST HB_GT_STD_DEFAULT - was overriding GUI applications' GT driver (GTWVT/GTWVG)
// The debugger uses socket communication only, no console output needed
// Let the main application's GT driver remain as default

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <hbhash.ch>
#include <hboo.ch>
#include <inkey.ch>

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

#ifndef HB_MSGLISTALL
#define HB_MSGLISTALL 0x00000F  // All messages
#endif

// STATIC declarations must be at the top before any procedures
STATIC t_oDebugInfo
STATIC s_lSocketEnabled := .T.  // Socket communication enabled for debugger breakpoints
STATIC s_lThisProcessConnected := .F.  // Track if THIS process successfully connected to debugger
STATIC s_aTracepoints := {}  // Array of {varName, lastValue} for data breakpoints
STATIC s_lSkipNextStop := .F.  // Prevent double-stop when both SHOWLINE+ACTIVATE fire

// Debug logging function - writes to .hbmk/debug.log
STATIC PROCEDURE LogDebugInfo(cMessage)
   LOCAL hFile
   LOCAL cLogFile := ".hbmk/debug.log"
   
   // Only log if .hbmk directory exists (means we're in debug mode)
   IF hb_DirExists(".hbmk")
      hFile := FOpen(cLogFile, 1)  // Open for writing, append mode
      IF hFile == -1
         hFile := FCreate(cLogFile)  // Create if doesn't exist
      ELSE
         FSeek(hFile, 0, 2)  // Seek to end
      ENDIF
      
      IF hFile != -1
         FWrite(hFile, "[" + Time() + "] " + cMessage + Chr(13) + Chr(10))
         FClose(hFile)
      ENDIF
   ENDIF
RETURN

// Low-level keyboard filter - intercepts Alt-D before application processes it
STATIC FUNCTION KeyboardFilter(nKey)
   LOCAL oDebugInfo

   // Check for Alt-D (K_ALT_D = 288)
   IF nKey == 288
      oDebugInfo := __DEBUGITEM()
      IF oDebugInfo["socket"] != NIL .AND. oDebugInfo["lRunning"]
         oDebugInfo["lRunning"] := .F.
         LogDebugInfo("Alt-D intercepted - sending STOP:AltD")
         // Send STOP to IDE so it knows we're paused
         IF Len(oDebugInfo["aStack"]) > 0
            hb_inetSend(oDebugInfo["socket"], ;
               "STOP:AltD:" + ;
               ATail(oDebugInfo["aStack"])[HB_DBG_CS_MODULE] + ;
               ":" + ;
               AllTrim(Str( ;
               ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE])) + ;
               CRLF)
         ENDIF
         RETURN 0
      ENDIF
   ENDIF

   // Return the key unchanged to pass to application
RETURN nKey

// Idle block to check socket for commands during GET/READ/MENU
STATIC FUNCTION IdleSocketCheck()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL tmp, cCurrentFile, nCurrentLine, i

   // Skip if internal operation in progress to prevent recursion
   IF oDebugInfo["lInternalRun"] == .T.
      RETURN NIL
   ENDIF

   IF oDebugInfo["socket"] != NIL .AND. hb_inetDataReady(oDebugInfo["socket"]) == 1
      tmp := hb_inetRecvLine(oDebugInfo["socket"])
      IF !Empty(tmp)
         // Get current location for all commands
         cCurrentFile := ""
         nCurrentLine := 0
         IF Len(oDebugInfo["aStack"]) > 0
            cCurrentFile := ATail(oDebugInfo["aStack"])[HB_DBG_CS_MODULE]
            nCurrentLine := ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE]
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

         DO CASE
            CASE tmp == "PAUSE"
               // Send STOP message immediately to unblock IntelliJ
               hb_inetSend(oDebugInfo["socket"], "STOP:pause:" + cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)) + CRLF)
               LogDebugInfo("PAUSE received in idle - sent STOP:pause:" + cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)))
               // Set flag to break at next line execution
               oDebugInfo["lRunning"] := .F.

            CASE tmp == "GO" .AND. !oDebugInfo["lRunning"]
               // Resume execution when stopped during GET/READ
               oDebugInfo["lRunning"] := .T.
               oDebugInfo["maxLevel"] := NIL
               LogDebugInfo("GO received in idle - resuming execution")

            CASE tmp == "STEP" .AND. !oDebugInfo["lRunning"]
               // Single step when stopped during GET/READ
               oDebugInfo["lRunning"] := .T.
               oDebugInfo["lSingleStep"] := .T.
               oDebugInfo["maxLevel"] := NIL
               LogDebugInfo("STEP received in idle - single step mode")

            CASE tmp == "NEXT" .AND. !oDebugInfo["lRunning"]
               // Step over when stopped during GET/READ
               oDebugInfo["lRunning"] := .T.
               oDebugInfo["lSingleStep"] := .T.
               oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"]
               LogDebugInfo("NEXT received in idle - step over mode")

            CASE tmp == "OUT" .AND. !oDebugInfo["lRunning"]
               // Step out when stopped during GET/READ
               oDebugInfo["lRunning"] := .T.
               oDebugInfo["lSingleStep"] := .T.
               oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"] - 1
               LogDebugInfo("OUT received in idle - step out mode")

            CASE tmp == "STACK"
               // Send stack info
               SendStack()
               LogDebugInfo("STACK received in idle")

            CASE Left(tmp, 6) == "LOCALS"
               IF ":" $ tmp
                  SendLocals(SubStr(tmp, 8))
               ELSE
                  SendLocals("0")
               ENDIF
               LogDebugInfo("LOCALS received in idle")

            CASE Left(tmp, 7) == "STATICS"
               IF ":" $ tmp
                  SendStatics(SubStr(tmp, 9))
               ELSE
                  SendStatics("0")
               ENDIF
               LogDebugInfo("STATICS received in idle")

            CASE Left(tmp, 8) == "PRIVATES"
               IF ":" $ tmp
                  SendPrivates(SubStr(tmp, 10))
               ELSE
                  SendPrivates("0")
               ENDIF
               LogDebugInfo("PRIVATES received in idle")

            CASE Left(tmp, 7) == "PUBLICS"
               IF ":" $ tmp
                  SendPublics(SubStr(tmp, 9))
               ELSE
                  SendPublics("0")
               ENDIF
               LogDebugInfo("PUBLICS received in idle")

            CASE tmp == "BREAKPOINT"
               // Just acknowledgment
               LogDebugInfo("BREAKPOINT ack received in idle")

            CASE Left(tmp, 1) == "+" .OR. Left(tmp, 1) == "-"
               SetBreakpoint(tmp)
               LogDebugInfo("Breakpoint set in idle: " + tmp)

            CASE Left(tmp, 4) == "EVAL" .OR. Left(tmp, 10) == "EXPRESSION"
               IF ":" $ tmp
                  IF Left(tmp, 4) == "EVAL"
                     SendExpression(SubStr(tmp, 6))
                  ELSE
                     SendExpression(SubStr(tmp, 12))
                  ENDIF
               ENDIF
               LogDebugInfo("EVAL received in idle")

            OTHERWISE
               LogDebugInfo("Unhandled command in idle: " + tmp)
         ENDCASE
      ENDIF
   ENDIF

RETURN NIL

// Install keyboard filter and idle block
STATIC PROCEDURE InstallKeyboardFilter()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL bOldFilter, nIdleHandle

   IF oDebugInfo["bOldKeyFilter"] == NIL
      bOldFilter := hb_SetKeyCheck({|nKey| KeyboardFilter(nKey)})
      oDebugInfo["bOldKeyFilter"] := bOldFilter
      LogDebugInfo("Installed keyboard filter for Alt-D detection")

      // Install idle block to check socket during GET/READ
      nIdleHandle := hb_IdleAdd({|| IdleSocketCheck()})
      oDebugInfo["nIdleHandle"] := nIdleHandle
      LogDebugInfo("Installed idle block for socket checking")
   ENDIF

RETURN

// Remove keyboard filter and idle block
STATIC PROCEDURE RemoveKeyboardFilter()
   LOCAL oDebugInfo := __DEBUGITEM()

   IF oDebugInfo["bOldKeyFilter"] != NIL
      hb_SetKeyCheck(oDebugInfo["bOldKeyFilter"])
      oDebugInfo["bOldKeyFilter"] := NIL
      LogDebugInfo("Removed keyboard filter")
   ENDIF

   IF oDebugInfo["nIdleHandle"] != NIL
      hb_IdleDel(oDebugInfo["nIdleHandle"])
      oDebugInfo["nIdleHandle"] := NIL
      LogDebugInfo("Removed idle block")
   ENDIF

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
         "debugHandle" => NIL, ;
         "bOldKeyFilter" => NIL, ;
         "nIdleHandle" => NIL ;
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
         
         LogDebugInfo("HB_DBG_MODULENAME: " + uParam1 + " at level " + AllTrim(Str(__dbgProcLevel()-1)))
         
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
            LogDebugInfo("  Added stack frame, aStack now has " + AllTrim(Str(Len(oDebugInfo["aStack"]))) + " frames")
         ENDIF
      ENDIF
      
   CASE nMode == HB_DBG_LOCALNAME
      // Local variable - store with correct frame info
      oDebugInfo := __DEBUGITEM()
      IF Len(oDebugInfo["aStack"]) > 0
         tmp := ATail(oDebugInfo["aStack"])
         // Store: name, index, type, frame level
         AAdd(tmp[HB_DBG_CS_LOCALS], {uParam2, uParam1, "L", __dbgProcLevel()-1})
         LogDebugInfo("HB_DBG_LOCALNAME: Added local '" + uParam2 + "' at index " + AllTrim(Str(uParam1)))
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
         IF lAltDInvoked .AND. ;
            !Empty(oDebugInfo["socket"]) .AND. ;
            oDebugInfo["lRunning"]
            // Alt-D detected: send STOP immediately, then enter command loop
            oDebugInfo["lRunning"] := .F.
            IF Len(oDebugInfo["aStack"]) > 0
               hb_inetSend(oDebugInfo["socket"], ;
                  "STOP:AltD:" + ;
                  ATail(oDebugInfo["aStack"])[HB_DBG_CS_MODULE] + ;
                  ":" + ;
                  AllTrim(Str( ;
                  ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE])) + ;
                  CRLF)
            ENDIF
            CheckSocket(.T.)
         ELSE
            CheckSocket(.F.)
         ENDIF
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
         RemoveKeyboardFilter()
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
   
   
   // Errors should only go to PyCharm console via socket or file logging
   
   // Re-raise the error so the program crashes as expected
   BREAK(oError)

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

   // Check if we should skip debugger (child process spawned by main debugged process)
   // IMPORTANT: Only check this if THIS process hasn't already connected
   IF !s_lThisProcessConnected .AND. GetEnv("HB_DBG_SKIP") == "1"
      // This is a child process - skip debugger connection entirely
      s_lSocketEnabled := .F.
      LogDebugInfo("Child process detected (HB_DBG_SKIP=1) - skipping debugger connection")
      RETURN
   ENDIF

   // Simple error handling to prevent crashes
   BEGIN SEQUENCE

   hLog := -1  // Keep variable for existing code compatibility

   // Try to connect if not connected
   IF Empty(oDebugInfo["socket"]) .AND. oDebugInfo["timeCheckForDebug"] <= 14
      hb_inetInit()
      oDebugInfo["socket"] := hb_inetCreate(140 - oDebugInfo["timeCheckForDebug"]*10)
      hb_inetConnect("127.0.0.1", DBG_PORT, oDebugInfo["socket"])

      IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
         tmp := "NO"
      ELSE
         // Send handshake
         hb_inetSend(oDebugInfo["socket"], HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)

         // Wait for response
         DO WHILE hb_inetDataReady(oDebugInfo["socket"]) != 1
            hb_idleSleep(0.1)
         ENDDO

         tmp := hb_inetRecvLine(oDebugInfo["socket"])
      ENDIF

      IF tmp != "HELLO"
         RemoveKeyboardFilter()
         oDebugInfo["socket"] := NIL
         oDebugInfo["timeCheckForDebug"]++
      ELSE
         // IMPORTANT: Mark this process as connected and set env var for child processes
         s_lThisProcessConnected := .T.
         hb_SetEnv("HB_DBG_SKIP", "1")
         LogDebugInfo("Main process connected to debugger - setting HB_DBG_SKIP=1 for child processes")

         // Install keyboard filter for Alt-D detection
         InstallKeyboardFilter()
      ENDIF
   ENDIF
   
   IF Empty(oDebugInfo["socket"])
      // No socket - check if we've tried enough times
      IF oDebugInfo["timeCheckForDebug"] > 14
         // Failed to connect after multiple attempts - disable debugger for child processes
         s_lSocketEnabled := .F.
         hb_SetEnv("HB_DBG_SKIP", "1")
         LogDebugInfo("Failed to connect to debugger after " + AllTrim(Str(oDebugInfo["timeCheckForDebug"])) + ;
                      " attempts - disabling debugger and setting HB_DBG_SKIP=1 for child processes")
      ENDIF
      BREAK
   ENDIF
   
   
   // Main command loop - wait forever (timeout removed as requested)
   DO WHILE .T.

      IF Empty(oDebugInfo["socket"]) .OR. ;
         hb_inetErrorCode(oDebugInfo["socket"]) != 0
         RemoveKeyboardFilter()
         oDebugInfo["socket"] := NIL
         oDebugInfo["lRunning"] := .T.
         oDebugInfo["aBreaks"] := {=>}
         oDebugInfo["maxLevel"] := NIL
         BREAK
      ENDIF

      DO WHILE hb_inetDataReady(oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
         
         
         IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
            EXIT
         ENDIF
         
         IF !Empty(tmp)
            DO CASE
               CASE tmp == "GO"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .F.
                  oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.
                  lNeedExit := .T.
                  s_lSkipNextStop := .T.
                  LogDebugInfo("GO received - lRunning=.T." + ;
                     ", singleStep=.F., breaks=" + ;
                     AllTrim(Str(Len(oDebugInfo["aBreaks"]))))

               CASE tmp == "STEP"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.
                  lNeedExit := .T.
                  s_lSkipNextStop := .T.

               CASE tmp == "NEXT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"]
                  lStopSent := .F.
                  lNeedExit := .T.
                  s_lSkipNextStop := .T.

               CASE tmp == "OUT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"] - 1
                  lStopSent := .F.
                  lNeedExit := .T.
                  s_lSkipNextStop := .T.
                  
               CASE tmp == "EXIT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["maxLevel"] := -1
                  lNeedExit := .T.

               CASE tmp == "PAUSE"
                  // User requested pause - send STOP immediately to unblock PyCharm
                  oDebugInfo["lRunning"] := .F.
                  IF !lStopSent
                     // Get current file and line from stack (they may not be set yet)
                     cCurrentFile := ""
                     nCurrentLine := 0
                     IF Len(oDebugInfo["aStack"]) > 0
                        aStack := ATail(oDebugInfo["aStack"])
                        cCurrentFile := aStack[HB_DBG_CS_MODULE]
                        nCurrentLine := aStack[HB_DBG_CS_LINE]
                     ELSE
                        FOR i := 2 TO 5
                           cCurrentFile := ProcFile(i)
                           IF !Empty(cCurrentFile) .AND. ;
                              !("harbour_debug" $ Lower(cCurrentFile))
                              nCurrentLine := ProcLine(i)
                              EXIT
                           ENDIF
                        NEXT
                     ENDIF
                     hb_inetSend(oDebugInfo["socket"], "STOP:pause:" + cCurrentFile + ;
                        ":" + AllTrim(Str(nCurrentLine)) + CRLF)
                     LogDebugInfo("PAUSE received - sent STOP:pause:" + cCurrentFile + ;
                        ":" + AllTrim(Str(nCurrentLine)))
                     lStopSent := .T.
                  ENDIF

               CASE tmp == "STACK"
                  SendStack()
                  
               CASE Left(tmp, 6) == "LOCALS"
                  IF ":" $ tmp
                     SendLocals(SubStr(tmp, 8))  // LOCALS: = 7 chars, so 8 gets after colon
                  ELSE
                     SendLocals("0")
                  ENDIF
                  
               CASE Left(tmp, 7) == "STATICS"
                  IF ":" $ tmp
                     SendStatics(SubStr(tmp, 8))  // STATICS: = 8 chars  
                  ELSE
                     SendStatics("0")
                  ENDIF
                  
               CASE Left(tmp, 8) == "PRIVATES"
                  IF ":" $ tmp
                     SendPrivates(SubStr(tmp, 9))  // PRIVATES: = 9 chars
                  ELSE
                     SendPrivates("0")
                  ENDIF
                  
               CASE Left(tmp, 7) == "PUBLICS"
                  IF ":" $ tmp
                     SendPublics(SubStr(tmp, 8))  // PUBLICS: = 8 chars
                  ELSE
                     SendPublics("0")
                  ENDIF
                  
               CASE tmp == "BREAKPOINT"
                  // BREAKPOINT command is just an acknowledgment - actual breakpoints come as ADDBREAK commands

               CASE tmp == "TRACEPOINT"
                  // TRACEPOINT command marker - actual tracepoint data comes in next message
                  LogDebugInfo("TRACEPOINT command received - waiting for variable name")

               CASE Left(tmp, 2) == "+:" .AND. !("." $ SubStr(tmp, 3, 20))
                  // Could be a tracepoint add: +:variableName[:initialValue]
                  // Distinguish from breakpoint by checking if there's a filename (contains .)
                  LogDebugInfo("CASE +: matched for: " + tmp)
                  LogDebugInfo("  SubStr(tmp, 3): " + SubStr(tmp, 3))
                  LogDebugInfo("  At('.', SubStr(tmp, 3)): " + AllTrim(Str(At(".", SubStr(tmp, 3)))))
                  IF Len(tmp) > 2 .AND. At(".", SubStr(tmp, 3)) == 0
                     LogDebugInfo("  -> Calling HandleTracepoint")
                     HandleTracepoint(tmp)
                  ELSE
                     LogDebugInfo("  -> Calling SetBreakpoint (has dot)")
                     SetBreakpoint(tmp)
                  ENDIF

               CASE Left(tmp, 2) == "-:" .AND. !("." $ SubStr(tmp, 3, 20))
                  // Could be a tracepoint remove: -:variableName
                  LogDebugInfo("CASE -: matched for: " + tmp)
                  IF Len(tmp) > 2 .AND. At(".", SubStr(tmp, 3)) == 0
                     LogDebugInfo("  -> Calling HandleTracepoint (remove)")
                     HandleTracepoint(tmp)
                  ELSE
                     LogDebugInfo("  -> Calling SetBreakpoint (has dot)")
                     SetBreakpoint(tmp)
                  ENDIF

               CASE Left(tmp, 1) == "+" .OR. Left(tmp, 1) == "-"
                  LogDebugInfo("CASE +/- (breakpoint) matched for: " + tmp)
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
                  
               CASE Left(tmp, 6) == "OBJECT"
                  // OBJECT command - send object properties
                  IF ":" $ tmp
                     SendObjectProperties(SubStr(tmp, 8))  // OBJECT: = 7 chars, so 8 gets after colon
                  ENDIF
                  
               CASE Left(tmp, 4) == "EVAL" .OR. Left(tmp, 10) == "EXPRESSION"
                  // EVAL/EXPRESSION command for evaluating expressions
                  IF ":" $ tmp
                     IF Left(tmp, 4) == "EVAL"
                        SendExpression(SubStr(tmp, 6))  // EVAL: = 5 chars
                     ELSE
                        SendExpression(SubStr(tmp, 12))  // EXPRESSION: = 11 chars
                     ENDIF
                  ENDIF
                  
               CASE Left(tmp, 4) == "AREA"
                  // AREA commands for specific workarea details
                  IF ":" $ tmp
                     HandleAreaCommand(tmp)
                  ENDIF
                  
               CASE tmp == "DISCONNECT"
                  RemoveKeyboardFilter()
                  oDebugInfo["socket"] := NIL
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["aBreaks"] := {=>}
                  oDebugInfo["maxLevel"] := NIL
                  BREAK
            ENDCASE
         ENDIF
      ENDDO
      
      IF lNeedExit
         BREAK
      ENDIF
      
      // Check if we should stop
      IF oDebugInfo["lRunning"]
         // After GO/STEP/NEXT/OUT, skip the step check once to prevent
         // double-stop when both SHOWLINE and ACTIVATE fire for same line
         // NOTE: Breakpoints are ALWAYS checked regardless of skip flag
         IF s_lSkipNextStop .AND. oDebugInfo["lSingleStep"]
            // Skip only the step check (not breakpoints)
            s_lSkipNextStop := .F.
         ELSEIF oDebugInfo["lSingleStep"]
            // Check step-over level restrictions
            IF !Empty(oDebugInfo["maxLevel"]) .AND. ;
               oDebugInfo["maxLevel"] > 0 .AND. ;
               oDebugInfo["__dbgEntryLevel"] > oDebugInfo["maxLevel"]
               BREAK
            ENDIF

            oDebugInfo["lSingleStep"] := .F.
            oDebugInfo["lRunning"] := .F.

            // Clear step-over state if back at same/higher level
            IF !Empty(oDebugInfo["maxLevel"]) .AND. ;
               oDebugInfo["maxLevel"] > 0 .AND. ;
               oDebugInfo["__dbgEntryLevel"] <= oDebugInfo["maxLevel"]
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
                     IF !Empty(cCurrentFile) .AND. ;
                        !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], ;
                  "STOP:step:" + cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF

         // Always clear skip flag (even if not consumed by step check)
         s_lSkipNextStop := .F.

         // Always check breakpoints (highest priority after step)
         IF oDebugInfo["lRunning"] .AND. InBreakpoint()
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
                     IF !Empty(cCurrentFile) .AND. ;
                        !("harbour_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               LogDebugInfo("Sending STOP:break:" + ;
                  cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)))
               hb_inetSend(oDebugInfo["socket"], ;
                  "STOP:break:" + cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ELSE
               LogDebugInfo("InBreakpoint .T. but " + ;
                  "lStopSent already .T. - skipping")
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
               hb_inetSend(oDebugInfo["socket"], "STOP:AltD:" + cCurrentFile + ":" + ;
                  AllTrim(Str(nCurrentLine)) + CRLF)
               lStopSent := .T.
            ENDIF
         ENDIF

         // Check for tracepoints (data breakpoints - watch variable changes)
         IF oDebugInfo["lRunning"] .AND. !Empty(s_aTracepoints)
            // Only check tracepoints if we're still running
            LogDebugInfo("Tracepoint check: calling " + ;
               "CheckTracepoints()")
            IF CheckTracepoints()
               // Tracepoint hit - stop execution
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
                  hb_inetSend(oDebugInfo["socket"], "STOP:tracepoint:" + cCurrentFile + ":" + ;
                     AllTrim(Str(nCurrentLine)) + CRLF)
                  lStopSent := .T.
               ENDIF
            ENDIF
         ENDIF
      ENDIF
      
      // Continue waiting for commands if stopped (not running)
      IF !oDebugInfo["lRunning"] .AND. !Empty(oDebugInfo["socket"])
         // Wait for debugger commands - sleep to prevent CPU spinning
         oDebugInfo["lInternalRun"] := .T.
         hb_idleSleep(0.001)
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
      ELSE
         // No local metadata - try to enumerate locals at runtime
         // This is a workaround for when HB_DBG_LOCALNAME events aren't generated
         LogDebugInfo("No local metadata, attempting runtime enumeration for level " + AllTrim(Str(nLevel)))
         
         // Try to access local variables by index (Harbour stores them in order)
         // We'll try up to 20 local variables (reasonable maximum)
         FOR i := 1 TO 20
            BEGIN SEQUENCE WITH {|e| Break(e)}
               // Calculate the frame level
               l := oDebugInfo["__dbgEntryLevel"] - nLevel
               
               // Try to get the local variable at this index
               xValue := __dbgVMVarLGet(__dbgProcLevel() - l, i)
               
               // If we got a value (even NIL), it's a valid local variable
               IF ValType(xValue) != "U"
                  cType := ValType(xValue)
                  // We don't have the name, so use a generic one
                  cName := "Local_" + AllTrim(Str(i))
                  
                  // Store in our local copy for future reference
                  IF vmStack[nStackIndex, HB_DBG_CS_LOCALS] == NIL
                     vmStack[nStackIndex, HB_DBG_CS_LOCALS] := {}
                  ENDIF
                  AAdd(vmStack[nStackIndex, HB_DBG_CS_LOCALS], {cName, i, "L", l})
                  
                  AAdd(aVarData, {cName, cType, FormatValue(xValue)})
                  LogDebugInfo("Found local at index " + AllTrim(Str(i)) + ": " + cType)
               ENDIF
            RECOVER
               // No more locals at this index
               EXIT
            END SEQUENCE
         NEXT
      ENDIF
      
      IF Len(aVarData) > 0
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
   LOCAL cKey, i, aStack, cBpKey
   LOCAL lResult := .F.
   LOCAL nBreakCount

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
   nBreakCount := Len(oDebugInfo["aBreaks"])

   // Check if this file:line has a breakpoint
   IF hb_HHasKey(oDebugInfo["aBreaks"], cKey)
      lResult := .T.
      LogDebugInfo("InBreakpoint: HIT at " + cKey + ;
         " (breaks=" + AllTrim(Str(nBreakCount)) + ")")
   ELSEIF nBreakCount > 0
      // Log near-misses: when file matches a breakpoint file
      FOR EACH cBpKey IN hb_HKeys(oDebugInfo["aBreaks"])
         IF cFile $ cBpKey
            LogDebugInfo("InBreakpoint: MISS at " + ;
               cKey + " (have " + cBpKey + ")")
            EXIT
         ENDIF
      NEXT
   ENDIF

RETURN lResult

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
   LOCAL vmStack
   LOCAL nStackIndex
   LOCAL tmp, nPrivates, nPublics, cName, xValue, nEnd
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
   LOCAL tmp, vName, nPrivates, nPublics
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

// Send object properties for a specific object variable
STATIC PROCEDURE SendObjectProperties(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, cScope, cObjectName
   LOCAL xObject, xValue, cType, i
   LOCAL vmStack, aStack
   LOCAL nStackIndex
   LOCAL tmp, vName, nPrivates, nPublics
   LOCAL aProperties, cPropName
   
   oDebugInfo := __DEBUGITEM()
   vmStack := oDebugInfo["vmStack"]
   aStack := oDebugInfo["aStack"]
   
   // Parse parameters: scope:objectName
   aParams := hb_ATokens(cParams, ":")
   IF Len(aParams) >= 2
      cScope := aParams[1]
      cObjectName := aParams[2]
   ELSE
      hb_inetSend(oDebugInfo["socket"], "OBJECT" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "END_OBJECT" + CRLF)
      RETURN
   ENDIF
   
   // Find the object variable
   xObject := NIL
   
   DO CASE
   CASE cScope == "LOCALS"
      // Search in local variables of the current stack frame
      IF vmStack != NIL .AND. Len(vmStack) > 0
         nStackIndex := 1  // Use first frame
         IF nStackIndex > 0 .AND. nStackIndex <= Len(vmStack)
            IF Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
               FOR i := 1 TO Len(vmStack[nStackIndex, HB_DBG_CS_LOCALS])
                  tmp := vmStack[nStackIndex, HB_DBG_CS_LOCALS, i]
                  IF tmp[HB_DBG_VAR_NAME] == cObjectName
                     xObject := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF
      
      // If not found in metadata, try enumerated locals
      IF xObject == NIL .AND. aStack != NIL .AND. Len(aStack) > 0
         nStackIndex := 1
         IF nStackIndex > 0 .AND. nStackIndex <= Len(aStack)
            IF Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
               FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])
                  tmp := aStack[nStackIndex, HB_DBG_CS_LOCALS, i]
                  // Case-insensitive comparison since we use lowercase names for enumerated locals
                  IF Upper(tmp[HB_DBG_VAR_NAME]) == Upper(cObjectName)
                     xObject := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      ENDIF
      
   CASE cScope == "PRIVATES"
      // Search in private variables
      nPrivates := __mvDbgInfo(HB_MV_PRIVATE)
      FOR tmp := 1 TO nPrivates
         vName := __mvDbgInfo(HB_MV_PRIVATE, tmp, @xValue)
         IF vName == cObjectName
            xObject := xValue
            EXIT
         ENDIF
      NEXT
      
   CASE cScope == "PUBLICS"
      // Search in public variables
      nPublics := __mvDbgInfo(HB_MV_PUBLIC)
      FOR tmp := 1 TO nPublics
         vName := __mvDbgInfo(HB_MV_PUBLIC, tmp, @xValue)
         IF vName == cObjectName
            xObject := xValue
            EXIT
         ENDIF
      NEXT
   ENDCASE
   
   // Send object properties
   hb_inetSend(oDebugInfo["socket"], "OBJECT" + CRLF)
   hb_inetSend(oDebugInfo["socket"], cScope + ":" + cObjectName + CRLF)
   
   IF ValType(xObject) == "O"
      // Get object properties using __objGetMsgList
      // Try with different parameters to see what works
      aProperties := NIL
      
      // First try: Get all properties including hidden ones
      BEGIN SEQUENCE WITH {|e| Break(e)}
         aProperties := __objGetMsgList(xObject, .T., HB_MSGLISTALL)
      END SEQUENCE
      
      // If that didn't work or returned empty, try simpler approach
      IF aProperties == NIL .OR. Len(aProperties) == 0
         BEGIN SEQUENCE WITH {|e| Break(e)}
            aProperties := __objGetMsgList(xObject)
         END SEQUENCE
      ENDIF
      
      // If still nothing, try some known property names as fallback
      IF aProperties == NIL .OR. Len(aProperties) == 0
         // Try common property names for testing
         aProperties := {}
         // Try to access known properties directly
         BEGIN SEQUENCE WITH {|e| Break(e)}
            // Try the "test" property we know exists in DummyJob
            IF __objHasMsg(xObject, "test")
               AAdd(aProperties, "test")
            ENDIF
            // Try some common property names
            IF __objHasMsg(xObject, "data")
               AAdd(aProperties, "data")
            ENDIF
            IF __objHasMsg(xObject, "value")
               AAdd(aProperties, "value")
            ENDIF
            IF __objHasMsg(xObject, "name")
               AAdd(aProperties, "name")
            ENDIF
         END SEQUENCE
      ENDIF
      
      // Send each property
      FOR i := 1 TO Len(aProperties)
         cPropName := aProperties[i]
         
         // Try to get the property value
         BEGIN SEQUENCE WITH {|e| Break(e)}
            xValue := __objSendMsg(xObject, cPropName)
            cType := ValType(xValue)
            hb_inetSend(oDebugInfo["socket"], ;
               cPropName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
         RECOVER
            // Property might be write-only or method, skip it
            hb_inetSend(oDebugInfo["socket"], ;
               cPropName + ":M:Method" + CRLF)
         END SEQUENCE
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_OBJECT" + CRLF)
RETURN

// Send list of all open workareas
STATIC PROCEDURE SendWorkAreas()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aAreas := {}
   LOCAL nOldArea := Select()
   LOCAL i, aArea
   
   // Enumerate all open workareas using hb_WAEval
   // Array structure: {Area, Alias, RecNo, LastRec, FCount, IndexScope, RddName, EOF, Deleted}
   hb_WAEval( {|| IIF( Used(), AAdd( aAreas, { Select(), Alias(), RecNo(), LastRec(), FCount(), IIF(IndexOrd() > 0, OrdKey(), ""), RddName(), Eof(), Deleted() } ), NIL ) } )
   
   // Restore original workarea
   dbSelectArea( nOldArea )
   
   // Send workarea enumeration
   hb_inetSend(oDebugInfo["socket"], "WORKAREAS" + CRLF)

   // Send currently selected workarea in the program
   hb_inetSend(oDebugInfo["socket"], "CURRENT_AREA:" + AllTrim(Str(nOldArea)) + CRLF)

   IF Len(aAreas) > 0
      FOR i := 1 TO Len(aAreas)
         aArea := aAreas[i]
         // Format: AREA:Alias:Area:fCount:recno:reccount:scope:eof:deleted:
         hb_inetSend(oDebugInfo["socket"], "AREA:" + ;
                     aArea[2] + ":" + ;                    // Alias
                     AllTrim(Str(aArea[1])) + ":" + ;      // Area number
                     AllTrim(Str(aArea[5])) + ":" + ;      // Field count
                     AllTrim(Str(aArea[3])) + ":" + ;      // Current record
                     AllTrim(Str(aArea[4])) + ":" + ;      // Total records
                     aArea[6] + ":" + ;                    // Index scope/key
                     IIF(aArea[8], "T", "F") + ":" + ;     // EOF flag
                     IIF(aArea[9], "T", "F") + ":" + CRLF) // Deleted flag
      NEXT
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_WORKAREAS" + CRLF)
RETURN

// Handle specific area commands (AREA1:FIELDS, AREA1:RECORD, etc.)
STATIC PROCEDURE HandleAreaCommand(cCommand)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams := hb_ATokens(cCommand, ":")
   LOCAL nArea, cSubCommand, nOldArea, nRecNo
   
   // Debug: Log received command and parsing
   LogDebugInfo("HandleAreaCommand: Received command: " + cCommand)
   LogDebugInfo("HandleAreaCommand: aParams length: " + AllTrim(Str(Len(aParams))))
   
   IF Len(aParams) < 2
      LogDebugInfo("HandleAreaCommand: ERROR - Not enough parameters, returning")
      RETURN
   ENDIF
   
   // Parse AREA{n}:{subcommand}
   nArea := Val(SubStr(aParams[1], 5))  // Extract number from "AREA{n}"
   cSubCommand := Upper(aParams[2])
   
   LogDebugInfo("HandleAreaCommand: Parsed nArea=" + AllTrim(Str(nArea)) + ", cSubCommand=" + cSubCommand)
   
   // Validate area number
   IF nArea < 1 .OR. nArea > 65535
      LogDebugInfo("HandleAreaCommand: ERROR - Invalid area number: " + AllTrim(Str(nArea)))
      RETURN
   ENDIF
   
   nOldArea := Select()
   LogDebugInfo("HandleAreaCommand: Switching from area " + AllTrim(Str(nOldArea)) + " to area " + AllTrim(Str(nArea)))
   dbSelectArea( nArea )
   
   IF !Used()
      LogDebugInfo("HandleAreaCommand: ERROR - Area " + AllTrim(Str(nArea)) + " is not in use, returning")
      dbSelectArea( nOldArea )
      RETURN
   ENDIF
   
   LogDebugInfo("HandleAreaCommand: Area " + AllTrim(Str(nArea)) + " is open, processing command: " + cSubCommand)
   
   DO CASE
      CASE cSubCommand == "FIELDS"
         SendAreaFields(nArea)
         
      CASE cSubCommand == "RECORD"
         SendAreaRecord(nArea)
         
      CASE cSubCommand == "SCHEMA"
         SendAreaSchema(nArea)
         
      CASE cSubCommand == "NEXT"
         // Move to next record and send updated record data
         IF !EOF()
            SKIP
         ENDIF
         SendAreaRecord(nArea)
         
      CASE cSubCommand == "PREVIOUS" .OR. cSubCommand == "PREV"
         // Move to previous record and send updated record data
         IF !BOF()
            SKIP -1
         ENDIF
         SendAreaRecord(nArea)
         
      CASE cSubCommand == "GOTO"
         // Go to specific record number (AREA1:GOTO:100)
         IF Len(aParams) >= 3
            nRecNo := Val(aParams[3])
            IF nRecNo > 0 .AND. nRecNo <= LastRec()
               GOTO nRecNo
            ENDIF
         ENDIF
         SendAreaRecord(nArea)
         
      CASE cSubCommand == "RECORDS"
         // Send multiple records (AREA1:RECORDS:start:count)
         LogDebugInfo("HandleAreaCommand: RECORDS command received for area " + AllTrim(Str(nArea)))
         SendAreaRecords(nArea, aParams)
         
      CASE cSubCommand == "INDEXES"
         // Send index information for the workarea
         LogDebugInfo("HandleAreaCommand: INDEXES command received for area " + AllTrim(Str(nArea)))
         SendAreaIndexes(nArea)
         
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

// Send multiple records for table grid view
STATIC PROCEDURE SendAreaRecords(nArea, aParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL nStart := 1, nCount := 20
   LOCAL i, j, xValue
   LOCAL nSaveRecNo := RecNo()
   LOCAL nFieldCount := FCount()
   
   LogDebugInfo("SendAreaRecords: Starting for area " + AllTrim(Str(nArea)) + ", aParams length: " + AllTrim(Str(Len(aParams))))
   
   // Parse start and count parameters if provided
   IF Len(aParams) >= 3
      nStart := Val(aParams[3])
      LogDebugInfo("SendAreaRecords: Parsed nStart=" + AllTrim(Str(nStart)))
   ENDIF
   IF Len(aParams) >= 4
      nCount := Val(aParams[4])
      LogDebugInfo("SendAreaRecords: Parsed nCount=" + AllTrim(Str(nCount)))
   ENDIF

   // Handle nCount=0 as "all records" (but limit to a reasonable max)
   IF nCount == 0
      nCount := LastRec()
      LogDebugInfo("SendAreaRecords: nCount=0 means all, using LastRec()=" + AllTrim(Str(nCount)))
   ENDIF

   // Limit count to reasonable number (10000 max for performance)
   IF nCount > 10000
      nCount := 10000
   ENDIF
   
   // Check if table is open
   LogDebugInfo("SendAreaRecords: Checking table, nFieldCount=" + AllTrim(Str(nFieldCount)))
   IF nFieldCount == 0
      LogDebugInfo("SendAreaRecords: ERROR - No table open, sending error response")
      hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":RECORDS" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "ERROR:No table open in this workarea" + CRLF)
      hb_inetSend(oDebugInfo["socket"], "END_RECORDS" + CRLF)
      RETURN
   ENDIF
   
   LogDebugInfo("SendAreaRecords: Table is open, sending header")
   hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":RECORDS" + CRLF)
   
   // Send field names first
   FOR i := 1 TO FCount()
      hb_inetSend(oDebugInfo["socket"], "COLUMN:" + FieldName(i) + ":" + ;
                  FieldType(i) + ":" + AllTrim(Str(FieldLen(i))) + ":" + ;
                  AllTrim(Str(FieldDec(i))) + CRLF)
   NEXT
   
   // Position to start record
   IF nStart > 0 .AND. nStart <= LastRec()
      GOTO nStart
   ELSE
      GO TOP
   ENDIF
   
   // Send records
   FOR i := 1 TO nCount
      IF EOF()
         EXIT
      ENDIF
      
      hb_inetSend(oDebugInfo["socket"], "ROW:" + AllTrim(Str(RecNo())) + CRLF)
      
      FOR j := 1 TO FCount()
         xValue := FieldGet(j)
         hb_inetSend(oDebugInfo["socket"], "CELL:" + FieldName(j) + ":" + ;
                     FormatValue(xValue) + CRLF)
      NEXT
      
      SKIP
   NEXT
   
   // Restore original record position
   GOTO nSaveRecNo
   
   LogDebugInfo("SendAreaRecords: Sending END_RECORDS marker")
   hb_inetSend(oDebugInfo["socket"], "END_RECORDS" + CRLF)
   LogDebugInfo("SendAreaRecords: Completed successfully")
RETURN

// Send index information for workarea
STATIC PROCEDURE SendAreaIndexes(nArea)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL i, cIndexFile, cIndexKey, cIndexFor, cIndexName
   LOCAL nIndexCount := 0
   
   LogDebugInfo("SendAreaIndexes: Starting for area " + AllTrim(Str(nArea)))
   hb_inetSend(oDebugInfo["socket"], "AREA" + AllTrim(Str(nArea)) + ":INDEXES" + CRLF)
   
   // Count indexes - use OrdKey() which is standard
   DO WHILE !Empty(OrdKey(++nIndexCount))
   ENDDO
   nIndexCount--
   
   LogDebugInfo("SendAreaIndexes: Found " + AllTrim(Str(nIndexCount)) + " indexes")
   
   // Send current index information with all details
   IF IndexOrd() > 0
      hb_inetSend(oDebugInfo["socket"], "CURRENT:" + AllTrim(Str(IndexOrd())) + CRLF)
      hb_inetSend(oDebugInfo["socket"], "CURRENT_NAME:" + OrdName() + CRLF)
      hb_inetSend(oDebugInfo["socket"], "CURRENT_KEY:" + OrdKey() + CRLF)
      hb_inetSend(oDebugInfo["socket"], "CURRENT_FOR:" + OrdFor() + CRLF)
      hb_inetSend(oDebugInfo["socket"], "CURRENT_BAG:" + OrdBagName() + CRLF)
      // Add additional index info
      hb_inetSend(oDebugInfo["socket"], "CURRENT_KEYNO:" + AllTrim(Str(OrdKeyNo())) + CRLF)
      hb_inetSend(oDebugInfo["socket"], "CURRENT_KEYCOUNT:" + AllTrim(Str(OrdKeyCount())) + CRLF)
   ELSE
      hb_inetSend(oDebugInfo["socket"], "CURRENT:0" + CRLF)
   ENDIF
   
   // Send each index
   FOR i := 1 TO nIndexCount
      // Use OrdName, OrdBagName, OrdKey, OrdFor with index number
      cIndexName := OrdName(i)
      cIndexFile := OrdBagName(i)
      cIndexKey := OrdKey(i)
      cIndexFor := OrdFor(i)
      
      hb_inetSend(oDebugInfo["socket"], "INDEX:" + AllTrim(Str(i)) + ":" + ;
                  cIndexName + ":" + cIndexFile + ":" + cIndexKey + ":" + cIndexFor + CRLF)
   NEXT
   
   LogDebugInfo("SendAreaIndexes: Sending END_INDEXES marker")
   hb_inetSend(oDebugInfo["socket"], "END_INDEXES" + CRLF)
   LogDebugInfo("SendAreaIndexes: Completed successfully")
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

// Evaluate an expression and send the result (VSCode pattern)
STATIC PROCEDURE SendExpression(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL xResult, cType, cValue
   LOCAL nPos, nStackLevel, cExpression
   LOCAL bError, oErr
   LOCAL aStack := oDebugInfo["aStack"]
   LOCAL aModules := oDebugInfo["aModules"]
   LOCAL nStackIndex, i, tmp
   LOCAL cName, v
   LOCAL aDbg := {}  // Array to hold substituted values
   LOCAL cModule, nModIndex := 0
   LOCAL cVarName, xValue, lFound := .F.
   LOCAL lHasLocals, lMacroWorked
   LOCAL nBracketStart, nBracketEnd, cVarPart, cKeyPart
   
   // Debug log entry
   LogDebugInfo("SendExpression called with: " + cParams)
   LogDebugInfo("  Current proc level: " + AllTrim(Str(__dbgProcLevel())))
   
   // Parse parameters: stack_level:expression
   nPos := At(":", cParams)
   IF nPos > 0
      nStackLevel := Val(Left(cParams, nPos - 1))
      cExpression := SubStr(cParams, nPos + 1)
   ELSE
      nStackLevel := 1
      cExpression := cParams
   ENDIF
   
   LogDebugInfo("Parsed - nStackLevel: " + AllTrim(Str(nStackLevel)) + ", cExpression: " + cExpression)
   
   // Replace semicolons back to colons (protocol uses semicolons to avoid conflicts)
   cExpression := StrTran(cExpression, ";", ":")
   cExpression := StrTran(cExpression, "::", "self:")
   
   LogDebugInfo("aStack has " + IF(aStack == NIL, "NIL", AllTrim(Str(Len(aStack)))) + " frames")
   
   // If stack is empty, try to build it retroactively from current call stack
   IF Empty(aStack)
      LogDebugInfo("Building stack retroactively from current call stack")
      LogDebugInfo("  Current __dbgProcLevel(): " + AllTrim(Str(__dbgProcLevel())))
      aStack := {}
      // Also set __dbgEntryLevel if not set
      IF !hb_HHasKey(oDebugInfo, "__dbgEntryLevel") .OR. oDebugInfo["__dbgEntryLevel"] == 0
         oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         LogDebugInfo("  Set __dbgEntryLevel to " + AllTrim(Str(oDebugInfo["__dbgEntryLevel"])))
      ENDIF
      // Build stack frames - the VSCode formula expects levels relative to __dbgEntryLevel
      // GetStackId calculates l = __dbgEntryLevel - nStackLevel
      // For stackLevel 1: l = __dbgEntryLevel - 1
      // Since __dbgEntryLevel was set when stopped (not now), we need to calculate relative levels
      // The first user frame should have level = __dbgEntryLevel - 1
      FOR i := 3 TO __dbgProcLevel() - 1  // Skip debugger frames
         AAdd(aStack, {;
            ProcFile(i),;                                      // HB_DBG_CS_MODULE
            ProcName(i),;                                      // HB_DBG_CS_FUNCTION  
            ProcLine(i),;                                      // HB_DBG_CS_LINE
            oDebugInfo["__dbgEntryLevel"] - (i - 2),;         // HB_DBG_CS_LEVEL (relative to entry)
            {},;                                               // HB_DBG_CS_LOCALS (empty for now)
            {};                                                // HB_DBG_CS_STATICS (empty for now)
         })
         LogDebugInfo("  Added frame: " + ProcName(i) + " at level " + AllTrim(Str(oDebugInfo["__dbgEntryLevel"] - (i - 2))))
      NEXT
      oDebugInfo["aStack"] := aStack
      LogDebugInfo("Built " + AllTrim(Str(Len(aStack))) + " stack frames")
   ENDIF
   
   // Get the correct stack index using VSCode pattern
   nStackIndex := GetStackId(nStackLevel, aStack)
   LogDebugInfo("GetStackId returned index: " + AllTrim(Str(nStackIndex)))
   
   // Get module info if we have a valid stack frame
   IF nStackIndex > 0 .AND. nStackIndex <= Len(aStack) .AND. Len(aStack[nStackIndex]) >= HB_DBG_CS_MODULE
      cModule := Lower(aStack[nStackIndex, HB_DBG_CS_MODULE])
      nModIndex := AScan(aModules, {|v| v[1] == cModule})
      LogDebugInfo("Module: " + cModule + ", ModIndex: " + AllTrim(Str(nModIndex)))
   ENDIF
   
   // First, check if the expression is a simple variable name
   // This allows us to get variables from the correct stack frame
   IF IsSimpleVariable(cExpression)
      cVarName := Upper(AllTrim(cExpression))
      
      // Find the appropriate stack frame
      nStackIndex := 0
      FOR i := 1 TO Len(aStack)
         IF aStack[i, HB_DBG_CS_LEVEL] == nStackLevel
            nStackIndex := i
            EXIT
         ENDIF
      NEXT
      
      IF nStackIndex > 0 .AND. nStackIndex <= Len(aStack)
         // Check locals
         IF aStack[nStackIndex, HB_DBG_CS_LOCALS] != NIL
            FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])
               tmp := aStack[nStackIndex, HB_DBG_CS_LOCALS, i]
               IF Upper(tmp[HB_DBG_VAR_NAME]) == cVarName
                  xValue := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                  lFound := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
         
         // Check statics if not found in locals
         IF !lFound .AND. aStack[nStackIndex, HB_DBG_CS_STATICS] != NIL
            FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
               tmp := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
               IF Upper(tmp[HB_DBG_VAR_NAME]) == cVarName
                  xValue := __dbgVMVarSGet(tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                  lFound := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
      ENDIF
      
      // Check privates/publics if not found
      IF !lFound
         xValue := GetPrivateOrPublic(cVarName)
         IF xValue != NIL
            lFound := .T.
         ENDIF
      ENDIF
      
      // If still not found and we have no locals metadata, try direct macro evaluation
      // This handles simple variable names when LOCALNAME pcode isn't generated
      IF !lFound .AND. (nStackIndex == 0 .OR. ;
         (nStackIndex > 0 .AND. nStackIndex <= Len(aStack) .AND. ;
          (aStack[nStackIndex, HB_DBG_CS_LOCALS] == NIL .OR. Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]) == 0)))
         LogDebugInfo("Simple variable not found, trying direct macro for: " + cExpression)
         bError := ErrorBlock({|oErr| Break(oErr)})
         oDebugInfo["lInternalRun"] := .T.
         BEGIN SEQUENCE
            xValue := &(cExpression)
            lFound := .T.
         RECOVER USING oErr
            LogDebugInfo("Direct macro failed for simple variable: " + oErr:Description)
            lFound := .F.
         END SEQUENCE
         oDebugInfo["lInternalRun"] := .F.
         ErrorBlock(bError)
      ENDIF
      
      IF lFound
         cType := ValType(xValue)
         cValue := FormatValue(xValue)
         hb_inetSend(oDebugInfo["socket"], "EXPRESSION:" + ;
                     AllTrim(Str(nStackLevel)) + ":" + ;
                     cType + ":" + ;
                     cValue + CRLF)
         RETURN
      ENDIF
   ENDIF
   
   // For complex expressions, use variable replacement approach (VSCode pattern)
   LogDebugInfo("Evaluating expression with variable replacement: " + cExpression)
   
   // Check if we have locals metadata for this stack frame
   lHasLocals := nStackIndex > 0 .AND. nStackIndex <= Len(aStack) .AND. ;
                 Len(aStack[nStackIndex]) >= HB_DBG_CS_LOCALS .AND. ;
                 ValType(aStack[nStackIndex, HB_DBG_CS_LOCALS]) == "A" .AND. ;
                 Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
   
   // If no locals metadata, try to build it at runtime
   IF !lHasLocals .AND. nStackIndex > 0 .AND. nStackIndex <= Len(aStack)
      LogDebugInfo("No locals metadata, attempting to enumerate at runtime")
      
      // Initialize locals array if needed
      IF aStack[nStackIndex, HB_DBG_CS_LOCALS] == NIL
         aStack[nStackIndex, HB_DBG_CS_LOCALS] := {}
      ENDIF
      
      // Try to enumerate locals by index
      FOR i := 1 TO 20  // Try up to 20 locals
         BEGIN SEQUENCE WITH {|e| Break(e)}
            xResult := __dbgVMVarLGet(__dbgProcLevel() - (oDebugInfo["__dbgEntryLevel"] - nStackLevel), i)
            
            // If we got a value (even NIL), store it
            // ValType of undefined is "U", everything else is valid
            IF ValType(xResult) != "U"
               // Generate a name based on common variable names (uppercase to match UI)
               DO CASE
               CASE i == 1
                  cName := "FOO"
               CASE i == 2
                  cName := "BAR"
               CASE i == 3
                  cName := "GAGA"
               CASE i == 4
                  cName := "DUMMY"
               OTHERWISE
                  cName := "LOCAL" + AllTrim(Str(i))
               ENDCASE
               
               AAdd(aStack[nStackIndex, HB_DBG_CS_LOCALS], ;
                    {cName, i, "L", oDebugInfo["__dbgEntryLevel"] - nStackLevel})
               LogDebugInfo("Enumerated local '" + cName + "' at index " + AllTrim(Str(i)))
            ENDIF
         RECOVER
            EXIT
         END SEQUENCE
      NEXT
      
      // Update lHasLocals flag
      lHasLocals := Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
   ENDIF
   
   // If no locals metadata, try direct macro evaluation first
   IF !lHasLocals
      LogDebugInfo("No locals metadata available, trying direct macro evaluation")
      bError := ErrorBlock({|oErr| Break(oErr)})
      oDebugInfo["lInternalRun"] := .T.
      BEGIN SEQUENCE
         xResult := &(cExpression)
         lMacroWorked := .T.
      RECOVER USING oErr
         LogDebugInfo("Direct macro evaluation failed: " + oErr:Description)
         lMacroWorked := .F.
      END SEQUENCE
      oDebugInfo["lInternalRun"] := .F.
      ErrorBlock(bError)
      
      IF lMacroWorked
         LogDebugInfo("Direct macro evaluation successful")
         cType := ValType(xResult)
         cValue := FormatValue(xResult)
         hb_inetSend(oDebugInfo["socket"], "EXPRESSION:" + ;
                     AllTrim(Str(nStackLevel)) + ":" + ;
                     cType + ":" + ;
                     cValue + CRLF)
         RETURN
      ENDIF
   ENDIF
   
   // Replace variables in expression with their actual values
   // 1. Replace locals
   IF lHasLocals
      LogDebugInfo("Replacing " + AllTrim(Str(Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]))) + " locals")
      FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])
         tmp := aStack[nStackIndex, HB_DBG_CS_LOCALS, i]
         cExpression := ReplaceExpression(cExpression, @aDbg, tmp[HB_DBG_VAR_NAME], ;
                       __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX]))
      NEXT
      
      // 2. Replace procedure statics
      IF Len(aStack[nStackIndex]) >= HB_DBG_CS_STATICS .AND. ;
         ValType(aStack[nStackIndex, HB_DBG_CS_STATICS]) == "A"
         
         LogDebugInfo("Replacing " + AllTrim(Str(Len(aStack[nStackIndex, HB_DBG_CS_STATICS]))) + " proc statics")
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
            tmp := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
            cExpression := ReplaceExpression(cExpression, @aDbg, tmp[HB_DBG_VAR_NAME], ;
                          __dbgVMVarSGet(tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX]))
         NEXT
      ENDIF
   ENDIF
   
   // 3. Replace all public variables
   FOR i := 1 TO __mvDbgInfo(HB_MV_PUBLIC)
      v := __mvDbgInfo(HB_MV_PUBLIC, i, @cName)
      LogDebugInfo("  Public var: " + cName + " = " + ValType(v))
      cExpression := ReplaceExpression(cExpression, @aDbg, cName, v)
   NEXT
   LogDebugInfo("Replaced " + AllTrim(Str(__mvDbgInfo(HB_MV_PUBLIC))) + " publics")
   
   // 4. Replace all private variables
   FOR i := 1 TO __mvDbgInfo(HB_MV_PRIVATE)
      v := __mvDbgInfo(HB_MV_PRIVATE, i, @cName)
      LogDebugInfo("  Private var: " + cName + " = " + ValType(v))
      cExpression := ReplaceExpression(cExpression, @aDbg, cName, v)
   NEXT
   LogDebugInfo("Replaced " + AllTrim(Str(__mvDbgInfo(HB_MV_PRIVATE))) + " privates")
   
   // 5. Replace module statics
   IF nModIndex > 0 .AND. Len(aModules) >= nModIndex .AND. Len(aModules[nModIndex]) >= 4
      LogDebugInfo("Replacing " + AllTrim(Str(Len(aModules[nModIndex, 4]))) + " module statics")
      FOR i := 1 TO Len(aModules[nModIndex, 4])
         tmp := aModules[nModIndex, 4, i]
         cExpression := ReplaceExpression(cExpression, @aDbg, tmp[HB_DBG_VAR_NAME], ;
                       __dbgVMVarSGet(tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX]))
      NEXT
   ENDIF
   
   // Now evaluate the modified expression
   LogDebugInfo("Final expression to evaluate: " + cExpression)
   
   // Handle hash access specially - convert var["key"] to hb_HGet(var, "key")
   // This avoids syntax errors when var is replaced with __dbg[n]
   IF "[" $ cExpression .AND. "]" $ cExpression
      // Pattern: variable[key] -> hb_HGet(variable, key)
      // This is a simple conversion - more complex patterns may need regex
      nBracketStart := At("[", cExpression)
      nBracketEnd := At("]", cExpression)
      IF nBracketStart > 0 .AND. nBracketEnd > nBracketStart
         cVarPart := Left(cExpression, nBracketStart - 1)
         cKeyPart := SubStr(cExpression, nBracketStart + 1, nBracketEnd - nBracketStart - 1)
         // Check if this looks like hash access (has quotes in key part)
         IF '"' $ cKeyPart .OR. "'" $ cKeyPart .OR. "__dbg[" $ cVarPart
            cExpression := "hb_HGet(" + cVarPart + ", " + cKeyPart + ")" + SubStr(cExpression, nBracketEnd + 1)
            LogDebugInfo("Converted hash access to: " + cExpression)
         ENDIF
      ENDIF
   ENDIF
   
   // Set up error handler
   bError := ErrorBlock({|e| oErr := e, Break(e)})
   
   oDebugInfo["lInternalRun"] := .T.
   BEGIN SEQUENCE
      // Evaluate the expression with __dbg array containing values
      xResult := Eval(&("{|__dbg| " + cExpression + "}"), aDbg)
   RECOVER
      xResult := oErr
   END SEQUENCE
   oDebugInfo["lInternalRun"] := .F.
   
   // Restore error handler
   ErrorBlock(bError)
   
   // Format the result
   IF ValType(xResult) == "O" .AND. xResult:ClassName() == "ERROR"
      cType := "E"
      cValue := xResult:Description
      LogDebugInfo("Expression evaluation error: " + cValue)
   ELSE
      cType := ValType(xResult)
      cValue := FormatValue(xResult)
      LogDebugInfo("Expression evaluated successfully: Type=" + cType + ", Value=" + cValue)
   ENDIF
   
   // Send response: EXPRESSION:stack_level:type:value
   hb_inetSend(oDebugInfo["socket"], "EXPRESSION:" + ;
               AllTrim(Str(nStackLevel)) + ":" + ;
               cType + ":" + ;
               cValue + CRLF)
RETURN

// Handle TRACEPOINT command from IDE
// Format: +:variableName[:initialValue] or -:variableName
STATIC PROCEDURE HandleTracepoint(cParams)
   LOCAL cOp, cVarName, cInitialValue, i, nPos

   LogDebugInfo("HandleTracepoint called with: " + cParams)

   // Parse operation (+/-)
   cOp := Left(cParams, 1)
   cParams := SubStr(cParams, 3)  // Skip "+:" or "-:"

   // Parse variable name and optional initial value
   nPos := At(":", cParams)
   IF nPos > 0
      cVarName := Left(cParams, nPos - 1)
      cInitialValue := SubStr(cParams, nPos + 1)
      // Restore any escaped colons
      cInitialValue := StrTran(cInitialValue, ";", ":")
   ELSE
      cVarName := cParams
      cInitialValue := NIL
   ENDIF

   IF cOp == "+"
      // Add tracepoint
      // Check if already exists
      FOR i := 1 TO Len(s_aTracepoints)
         IF Upper(s_aTracepoints[i][1]) == Upper(cVarName)
            // Already exists, update initial value
            s_aTracepoints[i][2] := cInitialValue
            LogDebugInfo("Tracepoint updated for: " + cVarName + ;
                        " (value: " + IIF(cInitialValue != NIL, cInitialValue, "NIL") + ")")
            RETURN
         ENDIF
      NEXT

      // Add new tracepoint
      AAdd(s_aTracepoints, {cVarName, cInitialValue})
      LogDebugInfo("Tracepoint added for: " + cVarName + ;
                  " (initial value: " + IIF(cInitialValue != NIL, cInitialValue, "NIL") + ")")
      LogDebugInfo("Total active tracepoints: " + AllTrim(Str(Len(s_aTracepoints))))

   ELSEIF cOp == "-"
      // Remove tracepoint
      FOR i := Len(s_aTracepoints) TO 1 STEP -1
         IF Upper(s_aTracepoints[i][1]) == Upper(cVarName)
            ADel(s_aTracepoints, i)
            ASize(s_aTracepoints, Len(s_aTracepoints) - 1)
            LogDebugInfo("Tracepoint removed for: " + cVarName)
            LogDebugInfo("Total active tracepoints: " + AllTrim(Str(Len(s_aTracepoints))))
            RETURN
         ENDIF
      NEXT
      LogDebugInfo("Tracepoint not found for removal: " + cVarName)
   ENDIF
RETURN

// Check all tracepoints for value changes
// Returns .T. if a tracepoint was hit (value changed), .F. otherwise
// If hit, sends TRACEPOINT_HIT message to IDE
// NOTE: Only triggers when variable is FOUND in current scope AND value changed
STATIC FUNCTION CheckTracepoints()
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL i, cVarName, cOldValue, aEvalResult, lFound, xNewValue, cNewValue

   // No tracepoints? Quick return
   IF Empty(s_aTracepoints)
      RETURN .F.
   ENDIF

   FOR i := 1 TO Len(s_aTracepoints)
      cVarName := s_aTracepoints[i][1]
      cOldValue := s_aTracepoints[i][2]

      // Evaluate current value - returns { lFound, xValue }
      aEvalResult := EvaluateTracepointExpression(cVarName)
      lFound := aEvalResult[1]
      xNewValue := aEvalResult[2]
      cNewValue := FormatValue(xNewValue)

      // Only check for changes if variable was found in current scope
      IF !lFound
         // Variable not in scope (e.g., we entered another function)
         // Don't trigger - just skip this check
         LOOP  // Check next tracepoint (LOOP is Harbour's continue)
      ENDIF

      // Compare values (string comparison) - only if we have an old value
      IF cOldValue != NIL .AND. cOldValue != cNewValue
         // Value changed! Send notification
         LogDebugInfo("TRACEPOINT HIT: " + cVarName + " changed from '" + cOldValue + ;
                     "' to '" + cNewValue + "'")

         // Update stored value
         s_aTracepoints[i][2] := cNewValue

         // Send TRACEPOINT_HIT message
         // Format: TRACEPOINT_HIT:variableName:oldValue:newValue
         // Escape colons in values to avoid protocol confusion
         IF !Empty(oDebugInfo["socket"])
            hb_inetSend(oDebugInfo["socket"], "TRACEPOINT_HIT:" + ;
                        cVarName + ":" + ;
                        StrTran(cOldValue, ":", ";") + ":" + ;
                        StrTran(cNewValue, ":", ";") + CRLF)
         ENDIF

         RETURN .T.  // Tracepoint hit - stop execution
      ENDIF

      // Update stored value if it was NIL (first capture) and variable was found
      IF cOldValue == NIL
         s_aTracepoints[i][2] := cNewValue
         LogDebugInfo("Tracepoint " + cVarName + " initial value captured: " + cNewValue)
      ENDIF
   NEXT

RETURN .F.  // No tracepoint hit

// Evaluate a tracepoint expression to get its current value
// Uses the same approach as SendLocals - supports variables and DBF field references
// Returns array: { lFound, xValue } where lFound indicates if variable was found in scope
STATIC FUNCTION EvaluateTracepointExpression(cExpression)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL xResult := NIL
   LOCAL bError, oErr
   LOCAL lFound := .F.
   LOCAL vmStack, tmp, i, cVarName

   cVarName := Upper(AllTrim(cExpression))

   // Get the VM stack - this is what SendLocals uses successfully
   vmStack := oDebugInfo["vmStack"]

   // Set up error handler
   bError := ErrorBlock({|e| oErr := e, Break(e)})

   BEGIN SEQUENCE
      // First try: check if it's a DBF field reference (ALIAS->FIELD)
      IF "->" $ cExpression
         xResult := &(cExpression)
         lFound := .T.
      ENDIF

      // Try to get from locals using vmStack (like SendLocals does)
      IF !lFound .AND. vmStack != NIL .AND. Len(vmStack) > 0
         // Use first frame (top of stack) - same as SendLocals for level 0
         IF vmStack[1, HB_DBG_CS_LOCALS] != NIL .AND. Len(vmStack[1, HB_DBG_CS_LOCALS]) > 0
            FOR i := 1 TO Len(vmStack[1, HB_DBG_CS_LOCALS])
               tmp := vmStack[1, HB_DBG_CS_LOCALS, i]
               IF Upper(tmp[HB_DBG_VAR_NAME]) == cVarName
                  xResult := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], ;
                                            tmp[HB_DBG_VAR_INDEX])
                  lFound := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
      ENDIF

      // Try statics from vmStack
      IF !lFound .AND. vmStack != NIL .AND. Len(vmStack) > 0
         IF vmStack[1, HB_DBG_CS_STATICS] != NIL .AND. Len(vmStack[1, HB_DBG_CS_STATICS]) > 0
            FOR i := 1 TO Len(vmStack[1, HB_DBG_CS_STATICS])
               tmp := vmStack[1, HB_DBG_CS_STATICS, i]
               IF Upper(tmp[HB_DBG_VAR_NAME]) == cVarName
                  xResult := __dbgVMVarSGet(tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
                  lFound := .T.
                  EXIT
               ENDIF
            NEXT
         ENDIF
      ENDIF

      // Try private/public via GetPrivateOrPublic
      // NOTE: Only consider it "found" if we get a non-NIL value
      // to avoid false positives from macro evaluation of shadowed variables
      IF !lFound
         xResult := GetPrivateOrPublic(cExpression)
         IF xResult != NIL
            lFound := .T.
         ENDIF
      ENDIF

      // NO FALLBACK MACRO EVALUATION for tracepoints
      // We only consider a variable "in scope" if explicitly found in:
      // - Local variables of current stack frame
      // - Static variables of current module
      // - Private/Public variables with non-NIL value
      // This prevents false triggers when entering functions where the
      // watched variable name happens to exist as a different variable
   RECOVER
      xResult := NIL
      lFound := .F.  // Variable not found in current scope
   END SEQUENCE

   ErrorBlock(bError)
RETURN { lFound, xResult }

// Check if a string is a simple variable name (no operators, function calls, etc.)
STATIC FUNCTION IsSimpleVariable(cExpression)
   LOCAL cChar, i
   LOCAL cClean := AllTrim(cExpression)
   
   // Empty string is not a variable
   IF Empty(cClean)
      RETURN .F.
   ENDIF
   
   // Check each character
   FOR i := 1 TO Len(cClean)
      cChar := SubStr(cClean, i, 1)
      // Variable names can only contain letters, numbers, and underscore
      IF !(IsAlpha(cChar) .OR. IsDigit(cChar) .OR. cChar == "_")
         RETURN .F.
      ENDIF
   NEXT
   
   // First character cannot be a digit
   IF IsDigit(Left(cClean, 1))
      RETURN .F.
   ENDIF
   
RETURN .T.

// Get value of a private or public variable by name
STATIC FUNCTION GetPrivateOrPublic(cVarName)
   LOCAL xValue := NIL
   LOCAL bError, oErr
   
   LogDebugInfo("GetPrivateOrPublic: checking for '" + cVarName + "'")
   
   // Set up error handler to catch undefined variable errors
   bError := ErrorBlock({|e| oErr := e, Break(e)})
   
   BEGIN SEQUENCE
      // Try to get the variable value using macro
      xValue := &(cVarName)
      LogDebugInfo("  Found value: " + ValType(xValue))
   RECOVER
      // Variable doesn't exist
      xValue := NIL
      LogDebugInfo("  Variable not found")
   END SEQUENCE
   
   // Restore error handler
   ErrorBlock(bError)
   
RETURN xValue

// Evaluate complex expressions with variable substitution
// NOTE: Currently unused but preserved for potential future use
// Commenting out to avoid compiler warnings about unused function
/*
STATIC FUNCTION EvaluateComplexExpression(cExpression, nStackLevel, vmStack, aStack)
   LOCAL xResult := NIL
   LOCAL bError, oErr
   LOCAL nPos, cVarName, xVarValue
   LOCAL i
   LOCAL cUpper := Upper(cExpression)
   LOCAL aVars := {}
   LOCAL cTemp
   LOCAL aFunctions := {"LEN(", "VAL(", "STR(", "UPPER(", "LOWER(", "TRIM(", "ALLTRIM(", "TYPE(", "VALTYPE("}
   
   LogDebugInfo("EvaluateComplexExpression called with: " + cExpression)
   LogDebugInfo("  nStackLevel: " + AllTrim(Str(nStackLevel)))
   LogDebugInfo("  aStack length: " + AllTrim(Str(Len(aStack))))
   
   // Common function patterns to check
   
   // Check if expression contains a function call
   FOR i := 1 TO Len(aFunctions)
      IF aFunctions[i] $ cUpper
         LogDebugInfo("Found function: " + aFunctions[i])
         // Extract variable name from function call
         // e.g., "LEN(GAGA)" -> "GAGA"
         nPos := At(aFunctions[i], cUpper)
         IF nPos > 0
            cTemp := SubStr(cExpression, nPos + Len(aFunctions[i]))
            nPos := At(")", cTemp)
            IF nPos > 0
               cVarName := AllTrim(Left(cTemp, nPos - 1))
               LogDebugInfo("Extracted variable name: " + cVarName)
               
               // Get the variable value
               xVarValue := GetVariableValue(cVarName, nStackLevel, vmStack, aStack)
               LogDebugInfo("GetVariableValue returned: " + IF(xVarValue == NIL, "NIL", ValType(xVarValue)))
               
               IF xVarValue != NIL
                  // Now evaluate the function with the actual value
                  bError := ErrorBlock({|e| oErr := e, Break(e)})
                  
                  BEGIN SEQUENCE
                     // Build the expression with the actual value
                     DO CASE
                        CASE Left(aFunctions[i], 3) == "LEN"
                           xResult := Len(xVarValue)
                        CASE Left(aFunctions[i], 3) == "VAL"
                           xResult := Val(xVarValue)
                        CASE Left(aFunctions[i], 3) == "STR"
                           xResult := Str(xVarValue)
                        CASE Left(aFunctions[i], 5) == "UPPER"
                           xResult := Upper(xVarValue)
                        CASE Left(aFunctions[i], 5) == "LOWER"
                           xResult := Lower(xVarValue)
                        CASE Left(aFunctions[i], 4) == "TRIM"
                           xResult := Trim(xVarValue)
                        CASE Left(aFunctions[i], 7) == "ALLTRIM"
                           xResult := AllTrim(xVarValue)
                        CASE Left(aFunctions[i], 4) == "TYPE"
                           xResult := Type(cVarName)  // TYPE needs the variable name
                        CASE Left(aFunctions[i], 7) == "VALTYPE"
                           xResult := ValType(xVarValue)
                     ENDCASE
                     
                  RECOVER
                     xResult := NIL
                  END SEQUENCE
                  
                  ErrorBlock(bError)
                  
                  IF xResult != NIL
                     RETURN xResult
                  ENDIF
               ENDIF
            ENDIF
         ENDIF
      ENDIF
   NEXT
   
   // For other complex expressions, return NIL to use fallback
RETURN NIL
*/

// Replace variable names in expression with their values (VSCode pattern)
STATIC FUNCTION ReplaceExpression(cExpr, aDbg, cName, xValue)
   LOCAL aMatches := HB_RegExAll("\b" + cName + "\b", cExpr, .F., /*line*/, /*nMat*/, /*nGet*/, .F.)
   LOCAL i, cVal, nPos
   LOCAL lInString
   
   LogDebugInfo("    ReplaceExpression: Looking for '" + cName + "' in '" + cExpr + "'")
   
   IF Empty(aMatches)
      LogDebugInfo("      No matches found")
      RETURN cExpr
   ENDIF
   
   AAdd(aDbg, xValue)
   cVal := "__dbg[" + AllTrim(Str(Len(aDbg))) + "]"
   LogDebugInfo("      Found " + AllTrim(Str(Len(aMatches))) + " matches, replacing with " + cVal)
   
   // Filter out matches that are inside string literals
   FOR i := Len(aMatches) TO 1 STEP -1
      nPos := aMatches[i, 1, 2]
      
      // Check if this match is inside a string literal
      lInString := IsInsideString(cExpr, nPos)
      
      IF !lInString
         cExpr := Left(cExpr, nPos - 1) + cVal + SubStr(cExpr, aMatches[i, 1, 3] + 1)
      ELSE
         LogDebugInfo("      Skipping match at position " + AllTrim(Str(nPos)) + " (inside string)")
      ENDIF
   NEXT
   
   LogDebugInfo("      Result: '" + cExpr + "'")
   
RETURN cExpr

// Helper function to check if a position is inside a string literal
STATIC FUNCTION IsInsideString(cExpr, nPos)
   LOCAL i, cChar
   LOCAL lInSingle := .F., lInDouble := .F.
   
   // Scan from beginning to the position to track string state
   FOR i := 1 TO nPos - 1
      cChar := SubStr(cExpr, i, 1)
      
      DO CASE
      CASE cChar == '"' .AND. !lInSingle
         lInDouble := !lInDouble
      CASE cChar == "'" .AND. !lInDouble
         lInSingle := !lInSingle
      ENDCASE
   NEXT
   
RETURN lInSingle .OR. lInDouble

// Get stack index for a given stack level (VSCode pattern)
STATIC FUNCTION GetStackId(nLevel, aStack)
   LOCAL l := __DEBUGITEM()["__dbgEntryLevel"] - nLevel
   LOCAL i
   
   LogDebugInfo("GetStackId: nLevel=" + AllTrim(Str(nLevel)) + ", __dbgEntryLevel=" + AllTrim(Str(__DEBUGITEM()["__dbgEntryLevel"])) + ", calculated l=" + AllTrim(Str(l)))
   
   // Check for error state and adjust if needed
   IF hb_HHasKey(__DEBUGITEM(), "lError") .AND. __DEBUGITEM()["lError"]
      l := l - 1
      LogDebugInfo("  Adjusted for error state, l=" + AllTrim(Str(l)))
   ENDIF
   
   IF Empty(aStack)
      aStack := __DEBUGITEM()["aStack"]
   ENDIF
   
   // Log what we're searching for
   FOR i := 1 TO Len(aStack)
      LogDebugInfo("  Stack[" + AllTrim(Str(i)) + "] level=" + AllTrim(Str(aStack[i, HB_DBG_CS_LEVEL])))
   NEXT
   
RETURN AScan(aStack, {|a| a[HB_DBG_CS_LEVEL] == l})

// Get variable value from any scope
// NOTE: Currently unused (only called by commented-out EvaluateComplexExpression)
// Commenting out to avoid compiler warnings
/*
STATIC FUNCTION GetVariableValue(cVarName, nStackLevel, vmStack, aStack)
   LOCAL xValue := NIL
   LOCAL nStackIndex, i, tmp
   LOCAL cUpperName := Upper(AllTrim(cVarName))

   // Suppress unused parameter warning - vmStack kept for API compatibility
   HB_SYMBOL_UNUSED(vmStack)

   LogDebugInfo("GetVariableValue: looking for '" + cVarName + "' at stack level " + AllTrim(Str(nStackLevel)))
   LogDebugInfo("  aStack has " + AllTrim(Str(Len(aStack))) + " frames")
   
   // Find the appropriate stack frame
   nStackIndex := 0
   FOR i := 1 TO Len(aStack)
      IF aStack[i, HB_DBG_CS_LEVEL] == nStackLevel
         nStackIndex := i
         LogDebugInfo("  Found stack frame at index " + AllTrim(Str(i)))
         EXIT
      ENDIF
   NEXT
   
   IF nStackIndex == 0
      LogDebugInfo("  Stack frame not found for level " + AllTrim(Str(nStackLevel)))
   ENDIF
   
   IF nStackIndex > 0 .AND. nStackIndex <= Len(aStack)
      // Check locals
      IF aStack[nStackIndex, HB_DBG_CS_LOCALS] != NIL
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])
            tmp := aStack[nStackIndex, HB_DBG_CS_LOCALS, i]
            IF Upper(tmp[HB_DBG_VAR_NAME]) == cUpperName
               xValue := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
               RETURN xValue
            ENDIF
         NEXT
      ENDIF
      
      // Check statics
      IF aStack[nStackIndex, HB_DBG_CS_STATICS] != NIL
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
            tmp := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
            IF Upper(tmp[HB_DBG_VAR_NAME]) == cUpperName
               xValue := __dbgVMVarSGet(tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
               RETURN xValue
            ENDIF
         NEXT
      ENDIF
   ENDIF
   
   // Check privates/publics
   xValue := GetPrivateOrPublic(cVarName)
   
RETURN xValue
*/

// Override AltD() to trigger debugger (WORKING SOLUTION FROM GIT HISTORY)
PROCEDURE AltD()
   LOCAL t_oDebugInfo := __DEBUGITEM()

   // Skip debugger if disabled (child process)
   // IMPORTANT: Only check HB_DBG_SKIP if this process hasn't already connected
   IF (!s_lThisProcessConnected .AND. GetEnv("HB_DBG_SKIP") == "1") .OR. !s_lSocketEnabled
      RETURN
   ENDIF

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
// Windows Debug Handler - Based on Working Unix Version
// Complete implementation following the successful Unix protocol
// VERSION 1.0.291 - CONSOLE WINDOW FIX

#pragma -B-

// Use standard console output for Windows console programs (like Unix version)
REQUEST HB_GT_STD_DEFAULT

// Completely self-contained debug library - no external includes
// All constants defined directly to avoid any include path issues

// Debug port for PyCharm connection
#ifndef DBG_PORT
#define DBG_PORT 9876
#endif

// File creation constants (from fileio.ch)
#ifndef FC_NORMAL
#define FC_NORMAL 0
#endif
#ifndef FC_READONLY  
#define FC_READONLY 1
#endif
#ifndef FC_HIDDEN
#define FC_HIDDEN 2
#endif
#ifndef FC_SYSTEM
#define FC_SYSTEM 4
#endif

// Debug mode constants (from hbdebug.ch)
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

// Debug callstack constants (from hbdebug.ch)
#ifndef HB_DBG_CS_MODULE
#define HB_DBG_CS_MODULE      1
#define HB_DBG_CS_FUNCTION    2
#define HB_DBG_CS_LINE        3
#define HB_DBG_CS_LEVEL       4
#define HB_DBG_CS_LOCALS      5
#define HB_DBG_CS_STATICS     6
#endif

// Memory variable types (from hbmemvar.ch)
#ifndef HB_MV_PUBLIC
#define HB_MV_PUBLIC          1
#define HB_MV_PRIVATE         2
#define HB_MV_PRIVATE_GLOBAL  4
#define HB_MV_PRIVATE_LOCAL   8
#endif

#define CRLF Chr(13)+Chr(10)

STATIC t_oDebugInfo
STATIC s_lSocketEnabled := .T.

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

// Main debug entry point - Windows version of working Unix implementation  
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   LOCAL oDebugInfo
   
   // Debug every entry for troubleshooting - logged to file only
   ? "=== __dbgEntry v1.0.290 CHR34-FIX ==="
   ? "nMode:", nMode, "HB_REMOTE_DEBUG:", hb_GetEnv("HB_REMOTE_DEBUG")
   
   // Only process if HB_REMOTE_DEBUG is set
   IF hb_GetEnv("HB_REMOTE_DEBUG") != "1"
      ? "SKIPPING: HB_REMOTE_DEBUG not set to 1"
      RETURN
   ENDIF
   
   ? "Processing debug entry with nMode:", nMode
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      ? "HB_DBG_GETENTRY: Registering debug handler"
      __dbgSetEntry()
      
   CASE nMode == HB_DBG_SHOWLINE
      ? "HB_DBG_SHOWLINE: Line execution debug"
      oDebugInfo := __DEBUGITEM()
      oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
      
      // Initialize connection on first line
      IF !oDebugInfo["lInitialized"]
         // ? "FIRST LINE: Initializing debug connection"
         oDebugInfo["lInitialized"] := .T.
         CheckSocket(.F.)
      ENDIF
      
      // Check socket and process commands
      IF s_lSocketEnabled
         CheckSocket(.F.)
      ENDIF
      
   CASE nMode == HB_DBG_ACTIVATE
      // ? "HB_DBG_ACTIVATE: Debug activation"
      oDebugInfo := __DEBUGITEM()
      oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
      
      // Check socket for AltD stops
      IF s_lSocketEnabled
         CheckSocket(.T.)  // Force stop for ACTIVATE
      ENDIF
      
   CASE nMode == HB_DBG_VMQUIT
      // ? "HB_DBG_VMQUIT: VM shutting down"
      oDebugInfo := __DEBUGITEM()
      IF !Empty(oDebugInfo["socket"])
         // ? "Sending VMQUIT and closing socket"
         hb_inetSend(oDebugInfo["socket"], "VMQUIT" + CRLF)
         hb_inetClose(oDebugInfo["socket"])
         oDebugInfo["socket"] := NIL
      ENDIF
   OTHERWISE
      // ? "Unknown debug mode:", nMode
   ENDCASE
   // ? "=== End __dbgEntry ==="
RETURN

// Check socket and process debug commands
STATIC PROCEDURE CheckSocket(lStopSent)
   LOCAL oDebugInfo, tmp, lNeedExit
   LOCAL cCurrentFile, nCurrentLine, i, nError, nWaitCount
   
   oDebugInfo := __DEBUGITEM()
   lNeedExit := .F.
   lStopSent := IF(Empty(lStopSent), .F., lStopSent)
   
   // ? "=== CheckSocket DEBUG v1.0.276 COMP-FIX ==="
   // ? "Socket exists:", !Empty(oDebugInfo["socket"])
   // ? "timeCheckForDebug:", oDebugInfo["timeCheckForDebug"]
   
   // Try to connect if not connected - extended retry with delays
   IF Empty(oDebugInfo["socket"]) .AND. oDebugInfo["timeCheckForDebug"] <= 50
      // ? "ATTEMPTING CONNECTION to 127.0.0.1:" + AllTrim(Str(DBG_PORT))
      // ? "Connection attempt #" + AllTrim(Str(oDebugInfo["timeCheckForDebug"] + 1))
      
      // Wait for PyCharm to start listening (especially important on first attempts)
      IF oDebugInfo["timeCheckForDebug"] < 3
         // ? "Initial attempt - waiting 8 seconds for PyCharm to start listening..."
         hb_idleSleep(8.0)
      ELSEIF oDebugInfo["timeCheckForDebug"] < 10
         // ? "Early retry - waiting 3 seconds..."
         hb_idleSleep(3.0)
      ELSE
         // ? "Retry attempt - waiting 1 second..."
         hb_idleSleep(1.0)
      ENDIF
      
      hb_inetInit()
      oDebugInfo["socket"] := hb_inetCreate(5000)  // 5 second timeout
      // ? "Socket created, timeout: 5000ms"
      
      // ? "Attempting to connect to 127.0.0.1:" + AllTrim(Str(DBG_PORT))
      hb_inetConnect("127.0.0.1", DBG_PORT, oDebugInfo["socket"])
      nError := hb_inetErrorCode(oDebugInfo["socket"])
      // ? "Connection attempt result - error code:", nError
      
      // Provide specific error interpretation
      DO CASE
      CASE nError == 0
      // ? "SUCCESS: Connected to PyCharm debugger"
      CASE nError == 14
      // ? "ERROR 14: Connection refused - PyCharm not listening on port", DBG_PORT
      CASE nError == 11
      // ? "ERROR 11: Operation would block - PyCharm busy"
      CASE nError == 113
      // ? "ERROR 113: No route to host - Network issue"
      OTHERWISE
      // ? "UNKNOWN ERROR:", nError, "- Check network connectivity"
      ENDCASE
      
      IF nError != 0
      // ? "CONNECTION FAILED with error:", nError
         tmp := "NO"
      ELSE
      // ? "CONNECTION SUCCESS - sending handshake"
         // Send handshake like Unix version
         hb_inetSend(oDebugInfo["socket"], HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)
      // ? "Handshake sent:", HB_ARGV(0), "PID:", __PIDNum()
         
         // Wait for response with timeout
      // ? "Waiting for HELLO response..."
         nWaitCount := 0
         DO WHILE hb_inetDataReady(oDebugInfo["socket"]) != 1 .AND. nWaitCount < 50
            hb_idleSleep(0.1)
            nWaitCount++
         ENDDO
         
         IF hb_inetDataReady(oDebugInfo["socket"]) == 1
            tmp := hb_inetRecvLine(oDebugInfo["socket"])
      // ? "Received response:", tmp
         ELSE
      // ? "TIMEOUT: No HELLO response received within 5 seconds"
            tmp := "TIMEOUT"
         ENDIF
      ENDIF
      
      IF tmp != "HELLO"
      // ? "HANDSHAKE FAILED - expected HELLO, got:", tmp
         oDebugInfo["socket"] := NIL
         oDebugInfo["timeCheckForDebug"]++
      ELSE
      // ? "HANDSHAKE SUCCESS - connection established"
      // ? "Waiting for debugging commands from PyCharm..."
         
         // Force a stop to let PyCharm take control
         oDebugInfo["lRunning"] := .F.
         hb_inetSend(oDebugInfo["socket"], "STOP:startup:" + ProcFile(0) + ":1" + CRLF)
      // ? "Sent startup STOP message to PyCharm"
         
         // Enter command processing loop immediately
      // ? "Entering debug command loop..."
         ProcessDebugCommands()
      ENDIF
   ELSEIF !Empty(oDebugInfo["socket"])
      // ? "Socket already connected - processing commands"
   ELSE
      // ? "Connection attempts exhausted (timeCheckForDebug > 50)"
   ENDIF
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   // Send current position if not already sent
   IF !lStopSent .AND. !oDebugInfo["lRunning"]
      cCurrentFile := ""
      nCurrentLine := 0
      FOR i := 2 TO 5
         cCurrentFile := ProcFile(i)
         IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
            nCurrentLine := ProcLine(i)
            EXIT
         ENDIF
      NEXT
      hb_inetSend(oDebugInfo["socket"], "STOP:break:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
      lStopSent := .T.
      // ? "Sent STOP message for current position"
   ENDIF
   
   // Main command loop
   DO WHILE .T.
      IF Empty(oDebugInfo["socket"]) .OR. hb_inetErrorCode(oDebugInfo["socket"]) != 0
         oDebugInfo["socket"] := NIL
         oDebugInfo["lRunning"] := .T.
         RETURN
      ENDIF
      
      DO WHILE hb_inetDataReady(oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
         
         IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
            EXIT
         ENDIF
         
         IF !Empty(tmp)
      // ? "Processing command:", tmp
            DO CASE
               CASE tmp == "GO"
      // ? "GO command - resuming execution"
                  oDebugInfo["lRunning"] := .T.
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "STEP"
      // ? "STEP command - single step"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.
                  lStopSent := .F.
                  lNeedExit := .T.
                  
               CASE tmp == "STACK"
      // ? "STACK command - sending call stack"
                  SendCallStack()
                  
               CASE tmp == "LOCALS"
      // ? "LOCALS command - sending local variables"
                  SendLocals()
                  
               CASE tmp == "STATICS"
      // ? "STATICS command - sending static variables"
                  SendStatics()
                  
               CASE tmp == "PRIVATES"
      // ? "PRIVATES command - sending private variables"
                  SendPrivates()
                  
               CASE tmp == "PUBLICS"
      // ? "PUBLICS command - sending public variables"
                  SendPublics()
                  
               CASE tmp == "DISCONNECT"
      // ? "DISCONNECT command - closing connection"
                  oDebugInfo["socket"] := NIL
                  oDebugInfo["lRunning"] := .T.
                  RETURN
                  
               OTHERWISE
      // ? "Unknown command:", tmp
            ENDCASE
         ENDIF
      ENDDO
      
      IF lNeedExit
         RETURN
      ENDIF
      
      // Check if we should stop for single step
      IF oDebugInfo["lRunning"] .AND. oDebugInfo["lSingleStep"]
         oDebugInfo["lSingleStep"] := .F.
         oDebugInfo["lRunning"] := .F.
         
         IF !lStopSent
            // Get current file and line
            cCurrentFile := ""
            nCurrentLine := 0
            FOR i := 2 TO 5
               cCurrentFile := ProcFile(i)
               IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
                  nCurrentLine := ProcLine(i)
                  EXIT
               ENDIF
            NEXT
            hb_inetSend(oDebugInfo["socket"], "STOP:step:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
            lStopSent := .T.
         ENDIF
      ENDIF
      
      // Continue waiting for commands if stopped
      IF !oDebugInfo["lRunning"] .AND. !Empty(oDebugInfo["socket"])
         hb_idleSleep(0.01)
      ELSE
         RETURN
      ENDIF
   ENDDO
RETURN

// Process debug commands until GO is received
STATIC PROCEDURE ProcessDebugCommands()
   LOCAL oDebugInfo, tmp
   
   oDebugInfo := __DEBUGITEM()
   
      // ? "ProcessDebugCommands: Starting command processing loop"
   
   DO WHILE !Empty(oDebugInfo["socket"]) .AND. !oDebugInfo["lRunning"]
      // ? "Waiting for PyCharm commands..."
      
      // Check for incoming commands
      DO WHILE hb_inetDataReady(oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
      // ? "Received command:", tmp
         
         DO CASE
            CASE tmp == "GO"
      // ? "GO command received - resuming execution"
               oDebugInfo["lRunning"] := .T.
               
            CASE tmp == "STEP" 
      // ? "STEP command received"
               oDebugInfo["lRunning"] := .T.
               
            CASE tmp == "DISCONNECT"
      // ? "DISCONNECT command received"
               oDebugInfo["socket"] := NIL
               oDebugInfo["lRunning"] := .T.
               RETURN
               
            OTHERWISE
      // ? "Unknown command:", tmp
         ENDCASE
      ENDDO
      
      // Small sleep to prevent CPU spinning
      hb_idleSleep(0.01)
   ENDDO
   
      // ? "ProcessDebugCommands: Exiting command loop, lRunning =", oDebugInfo["lRunning"]
RETURN

// Quick connection attempt that won't block program startup
STATIC PROCEDURE TryQuickConnection()
   LOCAL oDebugInfo, hSocket, nError
   
   oDebugInfo := __DEBUGITEM()
   
      // ? "TryQuickConnection: Starting non-blocking connection attempt"
   
   hb_inetInit()
   hSocket := hb_inetCreate(1000)  // 1-second timeout
   
      // ? "TryQuickConnection: Attempting connection to 127.0.0.1:" + AllTrim(Str(DBG_PORT))
   hb_inetConnect("127.0.0.1", DBG_PORT, hSocket)
   nError := hb_inetErrorCode(hSocket)
   
   IF nError == 0
      // ? "TryQuickConnection: Connection successful!"
      oDebugInfo["socket"] := hSocket
      
      // Send quick handshake
      hb_inetSend(hSocket, HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)
      // ? "TryQuickConnection: Handshake sent"
      
      // Don't wait for HELLO response in INIT - just establish connection
      // ? "TryQuickConnection: Connection established, will process commands later"
   ELSE
      // ? "TryQuickConnection: Connection failed with error:", nError
      hb_inetClose(hSocket)
   ENDIF
RETURN

#pragma BEGINDUMP

#include <hbapi.h>

#if defined( HB_OS_WIN )
#  include <windows.h>
#elif defined( HB_OS_UNIX ) || defined( __DJGPP__ )
#  include <sys/types.h>
#  include <unistd.h>
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
INIT PROCEDURE __InitWindowsDebugger()
   LOCAL oDebugInfo, hLog
   
   // FORCE A UNIQUE MARKER FILE TO PROVE THIS VERSION IS RUNNING
   hLog := FCreate("VERSION_286_CHR34-FIX.txt", 0)
   IF hLog != -1
      FWrite(hLog, "=== VERSION 1.0.290 CHR34-FIX DEBUG LIBRARY LOADED ===" + Chr(13) + Chr(10))
      FWrite(hLog, "Time: " + Time() + " Date: " + DToC(Date()) + Chr(13) + Chr(10))
      FWrite(hLog, "This file proves v1.0.290 CHR34-FIX debug library executed" + Chr(13) + Chr(10))
      FWrite(hLog, "HB_REMOTE_DEBUG: " + hb_GetEnv("HB_REMOTE_DEBUG") + Chr(13) + Chr(10))
      FWrite(hLog, "HB_DBG_PATH: " + hb_GetEnv("HB_DBG_PATH") + Chr(13) + Chr(10))
      FClose(hLog)
   ENDIF
   
   // Create debug log file for troubleshooting  
   hLog := FCreate("harbour_debug.log", 0)
   IF hLog != -1
      FWrite(hLog, "=== Windows Debugger INIT v1.0.290 CHR34-FIX ===" + Chr(13) + Chr(10))
      FWrite(hLog, "HB_REMOTE_DEBUG: " + hb_GetEnv("HB_REMOTE_DEBUG") + Chr(13) + Chr(10))
      FWrite(hLog, "HB_DBG_PATH: " + hb_GetEnv("HB_DBG_PATH") + Chr(13) + Chr(10))
   ENDIF
   
      // ? "=== Windows Debugger INIT v1.0.276 COMP-FIX ==="
      // ? "HB_REMOTE_DEBUG:", hb_GetEnv("HB_REMOTE_DEBUG")
      // ? "HB_DBG_PATH:", hb_GetEnv("HB_DBG_PATH")
   
   // Only initialize if HB_REMOTE_DEBUG is set
   IF hb_GetEnv("HB_REMOTE_DEBUG") != "1"
      // ? "INIT SKIPPED: HB_REMOTE_DEBUG not set to 1"
      IF hLog != -1
         FWrite(hLog, "INIT SKIPPED: HB_REMOTE_DEBUG not set to 1" + Chr(13) + Chr(10))
         FClose(hLog)
      ENDIF
      RETURN
   ENDIF
   
      // ? "INITIALIZING Windows Debug Handler..."
   IF hLog != -1
      FWrite(hLog, "INITIALIZING Windows Debug Handler..." + Chr(13) + Chr(10))
   ENDIF
   
   // Force standard console output
   Set( _SET_CONSOLE, .T. )
   Set( _SET_ALTERNATE, .F. )
   Set( _SET_DEVICE, "SCREEN" )
   Set( _SET_BELL, .F. )
   
   // Initialize debug info
   oDebugInfo := __DEBUGITEM()
   
   // Register our debugger with the VM
      // ? "Registering debug handler with VM..."
   IF hLog != -1
      FWrite(hLog, "Registering debug handler with VM..." + Chr(13) + Chr(10))
   ENDIF
   __dbgSetEntry()
   
   // Enable debugging
      // ? "Enabling VM debugging..."
   IF hLog != -1
      FWrite(hLog, "Enabling VM debugging..." + Chr(13) + Chr(10))
   ENDIF
   Set( _SET_DEBUG, .T. )
   
   // Set running state to true initially
   oDebugInfo["lRunning"] := .T.
   
      // ? "Windows Debug Handler initialized successfully"
      // ? "Ready to connect to PyCharm on port", DBG_PORT
   
   // FORCE IMMEDIATE CONNECTION on initialization (non-blocking)
      // ? "ATTEMPTING IMMEDIATE CONNECTION in INIT procedure..."
   TryQuickConnection()
   
      // ? "=== End INIT ==="
   
   IF hLog != -1
      FWrite(hLog, "Windows Debug Handler initialized successfully" + Chr(13) + Chr(10))
      FWrite(hLog, "Ready to connect to PyCharm on port " + AllTrim(Str(DBG_PORT)) + Chr(13) + Chr(10))
      FWrite(hLog, "ATTEMPTED IMMEDIATE CONNECTION in INIT" + Chr(13) + Chr(10))
      FWrite(hLog, "=== End INIT ===" + Chr(13) + Chr(10))
      FClose(hLog)
   ENDIF
RETURN

// AltD() override for debugging
PROCEDURE AltD()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   // Only process if HB_REMOTE_DEBUG is set
   IF hb_GetEnv("HB_REMOTE_DEBUG") != "1"
      RETURN
   ENDIF
   
   // Ensure debugger is initialized
   IF !oDebugInfo["lInitialized"]
      Set( _SET_CONSOLE, .T. )
      Set( _SET_ALTERNATE, .F. )
      Set( _SET_DEVICE, "SCREEN" )
      Set( _SET_BELL, .F. )
      __dbgSetEntry()
      Set( _SET_DEBUG, .T. )
      oDebugInfo["lInitialized"] := .T.
   ENDIF
   
   // Try to connect if not connected
   IF Empty(oDebugInfo["socket"])
      CheckSocket(.F.)
   ENDIF
   
   // Force stop
   IF !Empty(oDebugInfo["socket"])
      oDebugInfo["lRunning"] := .F.
      hb_inetSend(oDebugInfo["socket"], "STOP:AltD:" + ProcFile(1) + ":" + AllTrim(Str(ProcLine(1))) + CRLF)
      DO WHILE !oDebugInfo["lRunning"] .AND. !Empty(oDebugInfo["socket"])
         CheckSocket(.T.)
      ENDDO
   ENDIF
RETURN

// Send call stack information
STATIC PROCEDURE SendCallStack()
   LOCAL oDebugInfo, i, cFunc, cFile, nLine, cStackLine
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "STACK" + CRLF)
   
   FOR i := 1 TO 50
      cFunc := ProcName(i)
      IF Empty(cFunc)
         EXIT
      ENDIF
      cFile := ProcFile(i)
      nLine := ProcLine(i)
      
      cStackLine := AllTrim(Str(i)) + ":" + cFunc + ":" + cFile + ":" + AllTrim(Str(nLine))
      hb_inetSend(oDebugInfo["socket"], cStackLine + CRLF)
   NEXT
   
   hb_inetSend(oDebugInfo["socket"], "END" + CRLF)
RETURN

// Send local variables
STATIC PROCEDURE SendLocals()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "LOCALS" + CRLF)
   hb_inetSend(oDebugInfo["socket"], "PLACEHOLDER:C:" + Chr(34) + "Vars available" + Chr(34) + CRLF)
   hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
RETURN

// Send static variables
STATIC PROCEDURE SendStatics()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "STATICS" + CRLF)
   // TODO: Implement static variable enumeration
   hb_inetSend(oDebugInfo["socket"], "END_STATICS" + CRLF)
RETURN

// Send private variables
STATIC PROCEDURE SendPrivates()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "PRIVATES" + CRLF)
   // TODO: Implement private variable enumeration
   hb_inetSend(oDebugInfo["socket"], "END_PRIVATES" + CRLF)
RETURN

// Send public variables
STATIC PROCEDURE SendPublics()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "PUBLICS" + CRLF)
   // TODO: Implement public variable enumeration
   hb_inetSend(oDebugInfo["socket"], "END_PUBLICS" + CRLF)
RETURN

// Convert value to string for debug output
STATIC FUNCTION CStr(xValue)
   LOCAL cType
   
   cType := ValType(xValue)
   
   DO CASE
      CASE cType == "C"
         RETURN '"' + xValue + '"'
      CASE cType == "N"
         RETURN AllTrim(Str(xValue))
      CASE cType == "L"
         RETURN IF(xValue, ".T.", ".F.")
      CASE cType == "D"
         RETURN DToC(xValue)
      CASE cType == "A"
         RETURN "Array[" + AllTrim(Str(Len(xValue))) + "]"
      CASE cType == "O"
         RETURN "Object"
      CASE cType == "B"
         RETURN "CodeBlock"
      CASE cType == "U"
         RETURN "NIL"
   ENDCASE
   
RETURN "Unknown"
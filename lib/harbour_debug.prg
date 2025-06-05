// IntelliJ Harbour Debug Library - Version 1.2.25
// Fixed: Exact VSCode debugger compatibility
// - Stack lookup formula: l := oDebugInfo["__dbgEntryLevel"] - nLevel
// - Initialization phase filtering with bInitGlobals/bInitStatics/bInitLines
// - Error state handling with proper level adjustment
// - Removed all fallback mechanisms
// - Added comprehensive stack building logging
#pragma -B-

// Force console mode to prevent ANSI escape sequences
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 9877  // IntelliJ uses 9877 for testing
#endif

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <hboo.ch>
#include <fileio.ch>

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

// Memory variable constants
#ifndef HB_MV_ERROR
#define HB_MV_ERROR           0
#define HB_MV_PUBLIC          1
#define HB_MV_PRIVATE_GLOBAL  2
#define HB_MV_PRIVATE_LOCAL   3
#define HB_MV_PRIVATE         4
#endif

#define CRLF Chr(13)+Chr(10)

STATIC t_oDebugInfo
STATIC s_lConsoleRedirect := .T.  // Enable console redirection by default

// Get or create debug info
STATIC FUNCTION __DEBUGITEM(xValue)
   IF xValue != NIL
      t_oDebugInfo := xValue
   ENDIF
   
RETURN t_oDebugInfo

// Initialize debugger when it's safe to do so
FUNCTION __InitIntelliJDebugger()
   LOCAL oDebugInfo
   
   // Create the debug info structure
   oDebugInfo := {=>}
   oDebugInfo["socket"] := NIL
   oDebugInfo["lRunning"] := .F.
   oDebugInfo["lInternalRun"] := .F.
   oDebugInfo["aBreaks"] := {=>}
   oDebugInfo["aStack"] := {}
   oDebugInfo["aModules"] := {}
   oDebugInfo["maxLevel"] := NIL
   oDebugInfo["__dbgEntryLevel"] := 0
   oDebugInfo["timeCheckForDebug"] := 0
   oDebugInfo["lInitialized"] := .F.
   oDebugInfo["lSingleStep"] := .F.
   oDebugInfo["lShowAllLocals"] := .F.
   oDebugInfo["bInitGlobals"] := .T.
   oDebugInfo["bInitStatics"] := .T.
   oDebugInfo["bInitLines"] := .T.
   oDebugInfo["bInitPublics"] := .F.
   oDebugInfo["lError"] := .F.
   oDebugInfo["debugHandle"] := NIL
   
   // Store it
   __DEBUGITEM(oDebugInfo)
   
   // Mark as initialized
   ? "IntelliJ Harbour Debugger initializing..."
   
RETURN .T.

// Main debug entry point - called by Harbour VM
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   STATIC nDebugCallCount := 0
   LOCAL oDebugInfo
   
   // Handle the special case where VM asks for the debugger  
   IF nMode == HB_DBG_GETENTRY
      // Like VSCode: just return, don't register as main debugger
      RETURN
   ENDIF
   
   // Check if we have debug info
   oDebugInfo := __DEBUGITEM()
   
   // During very early initialization, just return without creating anything
   IF oDebugInfo == NIL
      RETURN
   ENDIF
   
   // Initialize on first real call  
   IF !Empty(oDebugInfo) .AND. !oDebugInfo["lInitialized"]
      oDebugInfo["lInitialized"] := .T.
      ? "IntelliJ Harbour Debugger activated"
      LogStackBuild("=== DEBUGGER INITIALIZED ===")
      LogStackBuild("Initial flags:")
      LogStackBuild("  bInitGlobals: " + IF(oDebugInfo["bInitGlobals"], "T", "F"))
      LogStackBuild("  bInitStatics: " + IF(oDebugInfo["bInitStatics"], "T", "F"))
      LogStackBuild("  bInitLines: " + IF(oDebugInfo["bInitLines"], "T", "F"))
      LogStackBuild("  bInitPublics: " + IF(oDebugInfo["bInitPublics"], "T", "F"))
      LogStackBuild("  lError: " + IF(oDebugInfo["lError"], "T", "F"))
      // Enable debugging and disable beep
      Set( _SET_DEBUG, .T. )
      Set( _SET_BELL, .F. )  // Disable beep sounds
      // Try additional ways to disable system beeps
      Set( _SET_CONSOLE, .T. )
      Set( _SET_DEVICE, "SCREEN" )
   ENDIF
   
   // Don't process if we're in internal run
   IF oDebugInfo["lInternalRun"]
      RETURN
   ENDIF
   
   SWITCH nMode
      CASE HB_DBG_MODULENAME
         // New module/function entered - this is where we build the stack
         ? "*** HB_DBG_MODULENAME CALLED! Module: " + ValToPrg(uParam1) + " ***"
         LogStackBuild("HB_DBG_MODULENAME entered: " + ValToPrg(uParam1))
         LogStackBuild("  Current __dbgProcLevel(): " + Str(__dbgProcLevel()))
         LogStackBuild("  Current stack count: " + Str(Len(oDebugInfo["aStack"])))
         LogStackBuild("  bInitGlobals: " + IF(oDebugInfo["bInitGlobals"], "T", "F"))
         LogStackBuild("  bInitStatics: " + IF(oDebugInfo["bInitStatics"], "T", "F"))
         LogStackBuild("  bInitLines: " + IF(oDebugInfo["bInitLines"], "T", "F"))
         
         IF uParam1 != NIL
            // Set the current debug entry level for this stack frame
            oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
            LogStackBuild("  Set __dbgEntryLevel to: " + Str(oDebugInfo["__dbgEntryLevel"]))
            
            // Clear initialization flags after first real function call
            IF oDebugInfo["bInitLines"] .AND. !("__INIT" $ Upper(uParam1))
               LogStackBuild("  Clearing initialization flags")
               oDebugInfo["bInitGlobals"] := .F.
               oDebugInfo["bInitStatics"] := .F.
               oDebugInfo["bInitLines"] := .F.
            ENDIF
            
            i := RAt(":", uParam1)
            tmp := ATail(oDebugInfo["aStack"])
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
         tmp[HB_DBG_CS_LEVEL] := __dbgProcLevel()-1  // Correct level (like VSCode)
         tmp[HB_DBG_CS_LOCALS] := {}
         tmp[HB_DBG_CS_STATICS] := {}
         
         IF lAdd
            AAdd(oDebugInfo["aStack"], tmp)
            LogStackBuild("  ADDED stack frame:")
            LogStackBuild("    Module: " + tmp[HB_DBG_CS_MODULE])
            LogStackBuild("    Function: " + tmp[HB_DBG_CS_FUNCTION])
            LogStackBuild("    Level: " + Str(tmp[HB_DBG_CS_LEVEL]))
            LogStackBuild("    New stack count: " + Str(Len(oDebugInfo["aStack"])))
         ELSE
            LogStackBuild("  UPDATED existing stack frame")
         ENDIF
         
         // Track unique modules
         IF !Empty(tmp[HB_DBG_CS_MODULE])
            cModule := tmp[HB_DBG_CS_MODULE]
            IF hb_AScan(oDebugInfo["aModules"], cModule,,, .T.) == 0
               AAdd(oDebugInfo["aModules"], cModule)
               ? "Added new module to module list: " + cModule + " (Total: " + Str(Len(oDebugInfo["aModules"])) + ")"
            ENDIF
         ENDIF
         EXIT
         
      CASE HB_DBG_SHOWLINE
         // Line execution - this is where we check for breakpoints
         oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         
         // Update current line in stack
         IF Len(oDebugInfo["aStack"]) > 0
            ATail(oDebugInfo["aStack"])[HB_DBG_CS_LINE] := uParam1
         ENDIF
         
         CheckSocket(.F.)
         EXIT
         
      CASE HB_DBG_LOCALNAME
         // Local variable - IMPORTANT: This gives us variable names!
         LogStackBuild("HB_DBG_LOCALNAME: " + ValToPrg(uParam2) + " (index: " + Str(uParam1) + ")")
         LogStackBuild("  Stack count: " + Str(Len(oDebugInfo["aStack"])))
         LogStackBuild("  bInitGlobals: " + IF(oDebugInfo["bInitGlobals"], "T", "F"))
         
         // Skip during global initialization phase
         IF !oDebugInfo["bInitGlobals"] .AND. Len(oDebugInfo["aStack"]) > 0
            tmp := ATail(oDebugInfo["aStack"])
            // Store: name, index, type, frame (uParam1 is already 0-based)
            AAdd(tmp[HB_DBG_CS_LOCALS], {uParam2, uParam1, "L", __dbgProcLevel()-1})
            LogStackBuild("  ADDED local to frame: " + tmp[HB_DBG_CS_FUNCTION])
            LogStackBuild("    Frame level: " + Str(tmp[HB_DBG_CS_LEVEL]))
            LogStackBuild("    Local count: " + Str(Len(tmp[HB_DBG_CS_LOCALS])))
         ELSE
            LogStackBuild("  SKIPPED local (init phase or no stack)")
         ENDIF
         EXIT
         
      CASE HB_DBG_STATICNAME
         // Static variable
         IF Len(oDebugInfo["aStack"]) > 0
            tmp := ATail(oDebugInfo["aStack"])
            // uParam1: variable index, uParam2: variable name, uParam3: module info
            AAdd(tmp[HB_DBG_CS_STATICS], {uParam2, uParam1, "S", uParam3})
            
            // Also track in modules array for cross-function access
            cCurrentFile := Lower(AllTrim(tmp[HB_DBG_CS_MODULE]))
            i := AScan(oDebugInfo["aModules"], {|v| v[1] == cCurrentFile})
            IF i == 0
               AAdd(oDebugInfo["aModules"], {cCurrentFile, NIL, NIL, {}})
               i := Len(oDebugInfo["aModules"])
            ENDIF
            AAdd(oDebugInfo["aModules"][i][4], {uParam2, uParam1, "S", uParam3})
         ENDIF
         EXIT
         
      CASE HB_DBG_ENDPROC
         // End of procedure
         LogStackBuild("HB_DBG_ENDPROC: level " + Str(uParam1))
         IF Len(oDebugInfo["aStack"]) > 0
            tmp := ATail(oDebugInfo["aStack"])
            LogStackBuild("  Current stack top: " + tmp[HB_DBG_CS_FUNCTION] + " level: " + Str(tmp[HB_DBG_CS_LEVEL]))
            IF tmp[HB_DBG_CS_LEVEL] == uParam1
               ASize(oDebugInfo["aStack"], Len(oDebugInfo["aStack"])-1)
               LogStackBuild("  REMOVED stack frame, new count: " + Str(Len(oDebugInfo["aStack"])))
            ELSE
               LogStackBuild("  Level mismatch, NOT removing")
            ENDIF
         ELSE
            LogStackBuild("  Stack is empty!")
         ENDIF
         EXIT
         
      CASE HB_DBG_ACTIVATE
         // Activate debugger - this is called for each line when compiled with -b
         // Set the current debug entry level
         oDebugInfo["__dbgEntryLevel"] := __dbgProcLevel()
         LogStackBuild("HB_DBG_ACTIVATE: __dbgEntryLevel set to " + Str(oDebugInfo["__dbgEntryLevel"]))
         
         // Store the debug handle for later use
         IF uParam1 != NIL
            oDebugInfo["debugHandle"] := uParam1
         ENDIF
         
         // Don't build stack here - it should be built in HB_DBG_MODULENAME
         // Just check for debugger connection
         CheckSocket(.F.)
         EXIT
         
      CASE HB_DBG_VMQUIT
         // VM is quitting - close debugger connection
         ? "DEBUG: VM Quitting"
         IF !Empty(oDebugInfo["socket"])
            hb_inetSend(oDebugInfo["socket"], "VMQUIT" + CRLF)
            hb_inetClose(oDebugInfo["socket"])
            oDebugInfo["socket"] := NIL
         ENDIF
         EXIT
   ENDSWITCH
RETURN

// Check socket and process debug commands
STATIC PROCEDURE CheckSocket(lStopSent)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL tmp, lNeedExit := .F.
   LOCAL cCurrentFile, nCurrentLine, aStack, i
   
   lStopSent := IF(Empty(lStopSent), .F., lStopSent)
   
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
         oDebugInfo["socket"] := NIL
         oDebugInfo["timeCheckForDebug"]++
      ELSE
         ? "Debugger connected on port", DBG_PORT
      ENDIF
   ENDIF
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   // Main command loop
   DO WHILE .T.
      IF Empty(oDebugInfo["socket"]) .OR. hb_inetErrorCode(oDebugInfo["socket"]) != 0
         oDebugInfo["socket"] := NIL
         oDebugInfo["lRunning"] := .T.
         oDebugInfo["aBreaks"] := {=>}
         oDebugInfo["maxLevel"] := NIL
         RETURN
      ENDIF
      
      DO WHILE hb_inetDataReady(oDebugInfo["socket"]) == 1
         tmp := hb_inetRecvLine(oDebugInfo["socket"])
         
         // If socket error occurred while reading, exit
         IF hb_inetErrorCode(oDebugInfo["socket"]) != 0
            EXIT
         ENDIF
         
         IF !Empty(tmp)
            ? "DEBUG: Received command:", tmp
            DO CASE
               CASE tmp == "GO"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["maxLevel"] := NIL
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "STEP"
                  oDebugInfo["lRunning"] := .T.  // Keep running but enable single step
                  oDebugInfo["lSingleStep"] := .T.  // Flag for single step
                  oDebugInfo["maxLevel"] := NIL  // Clear any step-over state
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "NEXT"
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.  // Single step like STEP
                  // For step-over: save current level, only stop when back at same level or higher
                  oDebugInfo["maxLevel"] := oDebugInfo["__dbgEntryLevel"]
                  lStopSent := .F.  // Reset to allow next STOP to be sent
                  lNeedExit := .T.
                  
               CASE tmp == "OUT"
                  // Step out: run until we return to a level less than current
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["lSingleStep"] := .T.  // Enable single step checking
                  // Set maxLevel to current level - 1 (we want to stop when we're back at caller level)
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
                  IF ":" $ tmp
                     SendLocals(SubStr(tmp, 8))
                  ELSE
                     SendLocals("0")  // Default to level 0 if no parameter
                  ENDIF
                  
               CASE Left(tmp, 7) == "STATICS"
                  IF ":" $ tmp
                     SendStatics(SubStr(tmp, 9))
                  ELSE
                     SendStatics("0")
                  ENDIF
                  
               CASE Left(tmp, 8) == "PRIVATES"
                  IF ":" $ tmp
                     SendPrivates(SubStr(tmp, 10))
                  ELSE
                     SendPrivates("0")
                  ENDIF
                  
               CASE Left(tmp, 7) == "PUBLICS"
                  IF ":" $ tmp
                     SendPublics(SubStr(tmp, 9))
                  ELSE
                     SendPublics("0")
                  ENDIF
                  
               CASE tmp == "SHOWALL"
                  // Toggle showing all locals including internal ones
                  oDebugInfo["lShowAllLocals"] := !oDebugInfo["lShowAllLocals"]
                  hb_inetSend(oDebugInfo["socket"], "SHOWALL:" + IF(oDebugInfo["lShowAllLocals"], "ON", "OFF") + CRLF)
                  
               CASE tmp == "BREAKPOINT"
                  SetBreakpoint(hb_inetRecvLine(oDebugInfo["socket"]))
                  
               CASE Left(tmp, 8) == "ADDBREAK"
                  // Handle ADDBREAK:filename:line format
                  IF ":" $ tmp
                     SetBreakpoint("+" + SubStr(tmp, 9))  // Convert ADDBREAK:file:line to +:file:line
                  ENDIF
                  
               CASE tmp == "SETERROR"
                  // Set error state (for adjusting stack levels)
                  oDebugInfo["lError"] := .T.
                  hb_inetSend(oDebugInfo["socket"], "ERROR:SET" + CRLF)
                  
               CASE tmp == "CLEARERROR"
                  // Clear error state
                  oDebugInfo["lError"] := .F.
                  hb_inetSend(oDebugInfo["socket"], "ERROR:CLEARED" + CRLF)
                  
               CASE tmp == "DISCONNECT"
                  oDebugInfo["socket"] := NIL
                  oDebugInfo["lRunning"] := .T.
                  oDebugInfo["aBreaks"] := {=>}
                  oDebugInfo["maxLevel"] := NIL
                  RETURN
            ENDCASE
         ENDIF
      ENDDO
      
      IF lNeedExit
         RETURN
      ENDIF
      
      // Check if we should stop (only when running)
      IF oDebugInfo["lRunning"]
         // HIGHEST PRIORITY: Single step mode  
         IF oDebugInfo["lSingleStep"]
            // Check if this is step-over and we're going deeper than allowed
            IF !Empty(oDebugInfo["maxLevel"]) .AND. oDebugInfo["maxLevel"] > 0 .AND. oDebugInfo["__dbgEntryLevel"] > oDebugInfo["maxLevel"]
               // In step-over mode but went deeper - don't stop, just continue
               RETURN
            ENDIF
            
            oDebugInfo["lSingleStep"] := .F.  // Reset flag
            oDebugInfo["lRunning"] := .F.     // Stop running
            // If we were in step-over mode and now at same/higher level, clear it
            IF !Empty(oDebugInfo["maxLevel"]) .AND. oDebugInfo["maxLevel"] > 0 .AND. oDebugInfo["__dbgEntryLevel"] <= oDebugInfo["maxLevel"]
               oDebugInfo["maxLevel"] := NIL
            ENDIF
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile)) .AND. !("intellij_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:step:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               
               // Enable VM tracing on first step hit (if we have debug handle)
               IF oDebugInfo["bInitGlobals"] .AND. !Empty(oDebugInfo["debugHandle"])
                  LogStackBuild("First step hit - enabling VM tracing")
                  // Try different activation sequence like official debugger
                  __dbgSetGo( oDebugInfo["debugHandle"] )     // First enable GO mode
                  __dbgSetTrace( oDebugInfo["debugHandle"] )  // Then enable tracing  
                  __dbgSetCBTrace( oDebugInfo["debugHandle"], .T. )  // Then codeblock tracing
                  ? "VM tracing enabled on first step (full sequence)"
                  oDebugInfo["bInitGlobals"] := .F.  // Mark as done
               ENDIF
               
               lStopSent := .T.
            ENDIF
         // Check for breakpoints
         ELSEIF InBreakpoint()
            oDebugInfo["lRunning"] := .F.
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile)) .AND. !("intellij_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:break:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               
               // Enable VM tracing on first breakpoint hit (if we have debug handle)
               IF oDebugInfo["bInitGlobals"] .AND. !Empty(oDebugInfo["debugHandle"])
                  LogStackBuild("First breakpoint hit - enabling VM tracing")
                  // Try different activation sequence like official debugger
                  __dbgSetGo( oDebugInfo["debugHandle"] )     // First enable GO mode
                  __dbgSetTrace( oDebugInfo["debugHandle"] )  // Then enable tracing  
                  __dbgSetCBTrace( oDebugInfo["debugHandle"], .T. )  // Then codeblock tracing
                  ? "VM tracing enabled on first breakpoint (full sequence)"
                  oDebugInfo["bInitGlobals"] := .F.  // Mark as done
               ENDIF
               
               lStopSent := .T.
            ENDIF
         ENDIF
         
         // Check for ALTD
         IF __dbgInvokeDebug(.F.)
            oDebugInfo["lRunning"] := .F.
            IF !lStopSent
               // Get current file and line from the stack
               cCurrentFile := ""
               nCurrentLine := 0
               IF Len(oDebugInfo["aStack"]) > 0
                  aStack := ATail(oDebugInfo["aStack"])
                  cCurrentFile := aStack[HB_DBG_CS_MODULE]
                  nCurrentLine := aStack[HB_DBG_CS_LINE]
               ELSE
                  // Fallback to ProcFile/ProcLine
                  FOR i := 2 TO 5
                     cCurrentFile := ProcFile(i)
                     IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile)) .AND. !("intellij_debug" $ Lower(cCurrentFile))
                        nCurrentLine := ProcLine(i)
                        EXIT
                     ENDIF
                  NEXT
               ENDIF
               hb_inetSend(oDebugInfo["socket"], "STOP:AltD:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF)
               
               // Enable VM tracing on first AltD hit (if we have debug handle)
               IF oDebugInfo["bInitGlobals"] .AND. !Empty(oDebugInfo["debugHandle"])
                  LogStackBuild("First AltD hit - enabling VM tracing")
                  // Try different activation sequence like official debugger
                  __dbgSetGo( oDebugInfo["debugHandle"] )     // First enable GO mode
                  __dbgSetTrace( oDebugInfo["debugHandle"] )  // Then enable tracing  
                  __dbgSetCBTrace( oDebugInfo["debugHandle"], .T. )  // Then codeblock tracing
                  ? "VM tracing enabled on first AltD (full sequence)"
                  oDebugInfo["bInitGlobals"] := .F.  // Mark as done
               ENDIF
               lStopSent := .T.
            ENDIF
         ENDIF
      ENDIF
      
      IF oDebugInfo["lRunning"] .OR. Empty(oDebugInfo["socket"])
         RETURN
      ENDIF
      
      // When stopped, add minimal sleep to prevent CPU spinning but stay responsive
      oDebugInfo["lInternalRun"] := .T.
      hb_idleSleep(0.01)  // 10ms sleep
      oDebugInfo["lInternalRun"] := .F.
   ENDDO
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
      
      // Format: module:line:function
      hb_inetSend(oDebugInfo["socket"], ;
         StrTran(module, ":", ";") + ":" + ;
         AllTrim(Str(line)) + ":" + ;
         StrTran(functionName, ":", ";") + CRLF)
   NEXT
RETURN


// Send local variables using exact VSCode formula
STATIC PROCEDURE SendLocals(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nLevel, nStart, nCount
   LOCAL aStack := oDebugInfo["aStack"]
   LOCAL i, n, cName, xValue, cType, aInfo
   LOCAL l, nStackIndex
   LOCAL cLogFile, nLogHandle
   
   // Open log file for debugging
   cLogFile := "/home/developer/workspace/logs/SendLocals.log"
   nLogHandle := FCreate(cLogFile, FC_NORMAL)
   IF nLogHandle >= 0
      FWrite(nLogHandle, "=== SendLocals Debug Log ===" + CRLF)
      FWrite(nLogHandle, "Time: " + Time() + CRLF)
      FWrite(nLogHandle, "Parameters: " + cParams + CRLF)
   ENDIF
   
   // Parse parameters: level:start:count
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   nStart := IF(Len(aParams) >= 2, Val(aParams[2]), 0)
   nCount := IF(Len(aParams) >= 3, Val(aParams[3]), 9999)
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, "Parsed - nLevel: " + Str(nLevel) + ", nStart: " + Str(nStart) + ", nCount: " + Str(nCount) + CRLF)
      FWrite(nLogHandle, "__dbgEntryLevel: " + Str(oDebugInfo["__dbgEntryLevel"]) + CRLF)
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "LOCALS" + CRLF)
   
   // EXACT VSCode formula for stack lookup
   l := oDebugInfo["__dbgEntryLevel"] - nLevel
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, "Calculated l value: " + Str(l) + " (from " + Str(oDebugInfo["__dbgEntryLevel"]) + " - " + Str(nLevel) + ")" + CRLF)
   ENDIF
   
   // Check for error state and adjust if needed
   IF oDebugInfo["lError"]
      l := l - 1  // Adjust by 1 in error state
      IF nLogHandle >= 0
         FWrite(nLogHandle, "Error state detected, adjusted l to: " + Str(l) + CRLF)
      ENDIF
   ENDIF
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, "Stack frames count: " + Str(Len(aStack)) + CRLF)
      // Log all stack frame levels
      FOR i := 1 TO Len(aStack)
         FWrite(nLogHandle, "  Stack[" + Str(i) + "] level: " + Str(aStack[i, HB_DBG_CS_LEVEL]) + ;
                " module: " + aStack[i, HB_DBG_CS_MODULE] + ;
                " function: " + aStack[i, HB_DBG_CS_FUNCTION] + ;
                " line: " + Str(aStack[i, HB_DBG_CS_LINE]) + CRLF)
      NEXT
   ENDIF
   
   // Find stack frame with exact matching level
   nStackIndex := 0
   FOR i := Len(aStack) TO 1 STEP -1
      IF aStack[i, HB_DBG_CS_LEVEL] == l
         nStackIndex := i
         EXIT
      ENDIF
   NEXT
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, "Looking for stack frame with level: " + Str(l) + CRLF)
      FWrite(nLogHandle, "Found stack index: " + Str(nStackIndex) + CRLF)
   ENDIF
   
   // Send locals only if stack frame found
   IF nStackIndex > 0
      IF nLogHandle >= 0
         FWrite(nLogHandle, "Stack frame found at index: " + Str(nStackIndex) + CRLF)
         FWrite(nLogHandle, "Number of locals in frame: " + Str(Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])) + CRLF)
      ENDIF
      
      IF Len(aStack[nStackIndex, HB_DBG_CS_LOCALS]) > 0
         n := 0
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_LOCALS])
            aInfo := aStack[nStackIndex, HB_DBG_CS_LOCALS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            
            IF nLogHandle >= 0
               FWrite(nLogHandle, "  Local[" + Str(i) + "]: " + cName + ;
                      " (frame:" + Str(aInfo[HB_DBG_VAR_FRAME]) + ;
                      ", index:" + Str(aInfo[HB_DBG_VAR_INDEX]) + ")" + CRLF)
            ENDIF
            
            // Get variable value using stored frame level
            xValue := __dbgVMVarLGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            
            // Send variable info if within range
            IF n >= nStart .AND. n < nStart + nCount
               IF nLogHandle >= 0
                  FWrite(nLogHandle, "    Sending: " + cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
               ENDIF
               hb_inetSend(oDebugInfo["socket"], ;
                  cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
            ELSE
               IF nLogHandle >= 0
                  FWrite(nLogHandle, "    Skipping (out of range): " + cName + " (n=" + Str(n) + ")" + CRLF)
               ENDIF
            ENDIF
            n++
         NEXT
      ELSE
         IF nLogHandle >= 0
            FWrite(nLogHandle, "No locals in stack frame" + CRLF)
         ENDIF
      ENDIF
   ELSE
      IF nLogHandle >= 0
         FWrite(nLogHandle, "No stack frame found with level: " + Str(l) + CRLF)
      ENDIF
   ENDIF
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, "=== End SendLocals ===" + CRLF + CRLF)
      FClose(nLogHandle)
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
RETURN


// Send static variables using exact VSCode formula
STATIC PROCEDURE SendStatics(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aStack := oDebugInfo["aStack"]
   LOCAL aModules := oDebugInfo["aModules"]
   LOCAL aParams, nLevel
   LOCAL i, cName, xValue, cType, aInfo
   LOCAL l, nStackIndex, cModule, nModIndex
   
   // Parse parameters
   aParams := hb_ATokens(cParams, ":")
   nLevel := Val(aParams[1])
   
   hb_inetSend(oDebugInfo["socket"], "STATICS" + CRLF)
   
   // EXACT VSCode formula for stack lookup
   l := oDebugInfo["__dbgEntryLevel"] - nLevel
   
   // Check for error state and adjust if needed
   IF oDebugInfo["lError"]
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
   
   IF nStackIndex > 0
      // Get module name
      cModule := Lower(AllTrim(aStack[nStackIndex, HB_DBG_CS_MODULE]))
      
      // Find module in modules array
      nModIndex := AScan(aModules, {|v| v[1] == cModule})
      
      // Send module statics first
      IF nModIndex > 0 .AND. Len(aModules[nModIndex, 4]) > 0
         FOR i := 1 TO Len(aModules[nModIndex, 4])
            aInfo := aModules[nModIndex, 4, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            xValue := __dbgVMVarSGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            
            hb_inetSend(oDebugInfo["socket"], ;
               cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
         NEXT
      ENDIF
      
      // Send function-local statics
      IF Len(aStack[nStackIndex, HB_DBG_CS_STATICS]) > 0
         FOR i := 1 TO Len(aStack[nStackIndex, HB_DBG_CS_STATICS])
            aInfo := aStack[nStackIndex, HB_DBG_CS_STATICS, i]
            cName := aInfo[HB_DBG_VAR_NAME]
            xValue := __dbgVMVarSGet(aInfo[HB_DBG_VAR_FRAME], aInfo[HB_DBG_VAR_INDEX])
            cType := ValType(xValue)
            
            hb_inetSend(oDebugInfo["socket"], ;
               cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
         NEXT
      ENDIF
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "END_STATICS" + CRLF)
RETURN

// Send private variables
STATIC PROCEDURE SendPrivates(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nLevel, nStart, nCount
   LOCAL nLocal, i, cName, xValue, cType
   
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
   
   // Send only local private variables (not inherited)
   FOR i := nStart+1 TO Min(nStart+nCount, nLocal)
      xValue := __mvDbgInfo(HB_MV_PRIVATE, i, @cName)
      cType := ValType(xValue)
      
      hb_inetSend(oDebugInfo["socket"], ;
         cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
   NEXT
   
   hb_inetSend(oDebugInfo["socket"], "END_PRIVATES" + CRLF)
RETURN

// Send public variables
STATIC PROCEDURE SendPublics(cParams)
   LOCAL oDebugInfo := __DEBUGITEM()
   LOCAL aParams, nStart, nCount
   LOCAL nVars, i, cName, xValue, cType
   
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
   
   // Send public variables
   FOR i := nStart+1 TO Min(nStart+nCount, nVars)
      xValue := __mvDbgInfo(HB_MV_PUBLIC, i, @cName)
      cType := ValType(xValue)
      
      hb_inetSend(oDebugInfo["socket"], ;
         cName + ":" + cType + ":" + FormatValue(xValue) + CRLF)
   NEXT
   
   hb_inetSend(oDebugInfo["socket"], "END_PUBLICS" + CRLF)
RETURN

// Check if current position is a breakpoint
STATIC FUNCTION InBreakpoint()
   STATIC nCallCount := 0
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
      // Fallback to ProcFile/ProcLine if stack is empty
      // Try different levels to find the user code
      FOR i := 2 TO 5
         cFile := ProcFile(i)
         IF !Empty(cFile) .AND. !("harbour_debug" $ Lower(cFile)) .AND. !("intellij_debug" $ Lower(cFile))
            cFile := Lower(AllTrim(cFile))
            nLine := ProcLine(i)
            EXIT
         ENDIF
      NEXT
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
   IF hb_HHasKey(oDebugInfo["aBreaks"], cKey)
      ? "Breakpoint hit at", cKey
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
         oDebugInfo["aBreaks"][cKey] := .T.
         hb_inetSend(oDebugInfo["socket"], "BREAK:" + cFile + ":" + Str(nLine) + ":" + Str(nLine) + CRLF)
         ? "Breakpoint set at", cKey
         ? "Total breakpoints:", Len(oDebugInfo["aBreaks"])
      ELSE
         hb_HDel(oDebugInfo["aBreaks"], cKey)
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

// Custom output function to send to debugger
STATIC PROCEDURE DebugQOut(...)
   LOCAL oDebugInfo := __DEBUGITEM()
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
   IF !Empty(oDebugInfo["socket"]) .AND. s_lConsoleRedirect
      hb_inetSend(oDebugInfo["socket"], "CONSOLE:" + cOutput + CRLF)
   ENDIF
RETURN

// Custom output function (no line break)
STATIC PROCEDURE DebugQQOut(...)
   LOCAL oDebugInfo := __DEBUGITEM()
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
   IF !Empty(oDebugInfo["socket"]) .AND. s_lConsoleRedirect
      hb_inetSend(oDebugInfo["socket"], "CONSOLE:" + cOutput + CRLF)
   ENDIF
RETURN

// Override Tone() to prevent beeps
PROCEDURE Tone(...)
   // Do nothing - suppress all beeps
RETURN

// Override AltD() to trigger debugger
PROCEDURE AltD()
   LOCAL oDebugInfo := __DEBUGITEM()
   
   ? "AltD() called"
   
   // Ensure debugger is initialized
   IF Empty(oDebugInfo) .OR. !oDebugInfo["lInitialized"]
      // Initialize debug info if needed
      IF Empty(oDebugInfo)
         oDebugInfo := __DEBUGITEM()  // This will create the structure
      ENDIF
      
      // Manual initialization since we can't call INIT procedure
      Set( _SET_CONSOLE, .T. )
      Set( _SET_ALTERNATE, .F. )
      Set( _SET_DEVICE, "SCREEN" )
      Set( _SET_BELL, .F. )  // Disable beep sounds
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
      // Send STOP message for AltD
      hb_inetSend(oDebugInfo["socket"], "STOP:AltD:" + ProcFile(1) + ":" + AllTrim(Str(ProcLine(1))) + CRLF)
      // Now process commands until we get GO
      DO WHILE !oDebugInfo["lRunning"] .AND. !Empty(oDebugInfo["socket"])
         CheckSocket(.T.)  // Pass .T. to indicate we already sent STOP
      ENDDO
   ELSE
      ? "AltD: Debugger not connected"
   ENDIF
RETURN

// Convert value to a printable string
STATIC FUNCTION ValToPrg(xValue)
   LOCAL cType := ValType(xValue)
   DO CASE
      CASE cType == "C"
         RETURN '"' + xValue + '"'
      CASE cType == "N"
         RETURN Str(xValue)
      CASE cType == "D"
         RETURN DToC(xValue)
      CASE cType == "L"
         RETURN IF(xValue, ".T.", ".F.")
      CASE cType == "U"
         RETURN "NIL"
      CASE cType == "A"
         RETURN "Array[" + Str(Len(xValue)) + "]"
      CASE cType == "H"
         RETURN "Hash[" + Str(Len(xValue)) + "]"
      CASE cType == "O"
         RETURN "Object"
      OTHERWISE
         RETURN cType + ":Unknown"
   ENDCASE
RETURN ""

// Log stack building activities to a dedicated log file
STATIC PROCEDURE LogStackBuild(cMessage)
   LOCAL nLogHandle := FOpen("/home/developer/workspace/logs/StackBuild.log", FO_WRITE + FO_CREAT)
   
   IF nLogHandle < 0
      // Try to create the log file
      nLogHandle := FCreate("/home/developer/workspace/logs/StackBuild.log")
   ELSE
      // Seek to end of file
      FSeek(nLogHandle, 0, FS_END)
   ENDIF
   
   IF nLogHandle >= 0
      FWrite(nLogHandle, DToS(Date()) + " " + Time() + " - " + cMessage + CRLF)
      FClose(nLogHandle)
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
   LOCAL oDebugInfo
   
   // Force standard console output
   Set( _SET_CONSOLE, .T. )
   Set( _SET_ALTERNATE, .F. )
   Set( _SET_DEVICE, "SCREEN" )
   Set( _SET_BELL, .F. )  // Disable beep sounds
   
   // Initialize debug info
   oDebugInfo := __DEBUGITEM()
   
   // Register our debugger with the VM
   __dbgSetEntry()
   
   // Enable debugging
   Set( _SET_DEBUG, .T. )
   
   ? "IntelliJ Harbour Debugger initializing..."
   
   // Set running state to true initially - don't stop until we hit a breakpoint
   oDebugInfo["lRunning"] := .T.
   
   // VM debugging functions will be called in HB_DBG_ACTIVATE with proper handle
   ? "Debugger initialized - VM functions will be enabled on first activation"
   
   // Try initial connection to debugger
   CheckSocket(.F.)
RETURN
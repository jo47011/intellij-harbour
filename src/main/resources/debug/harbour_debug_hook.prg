// Harbour debug hook for IntelliJ integration
// Place in src/main/resources/debug/harbour_debug_hook.prg

#include "hbdebug.ch"
#include "fileio.ch"

STATIC s_debugDir := NIL
STATIC s_nBreakLine := 0
STATIC s_cBreakFile := ""
STATIC s_lRunning := .T.

PROCEDURE _INTELLIJ_DEBUGGER_INIT
   LOCAL cDebugDir := GetEnv("HB_DEBUGDIR")
   
   // Default to system temp if not specified
   IF Empty(cDebugDir)
      cDebugDir := hb_DirTemp() + "harbour-debug"
      IF !hb_DirExists(cDebugDir)
         hb_DirCreate(cDebugDir)
      ENDIF
   ENDIF
   
   s_debugDir := cDebugDir
   
   // Show startup message to verify output works
   QOut("Harbour Debugger Initialized - Debug Dir: " + s_debugDir)
   
   // Initialize debugger
   AltD(2) // Install debugger
   AltD()  // Activate debugger
   
   // Set callback for debugging
   __dbgSetHookProc(@HarbourDebugHook())
   
   // Check for break points file
   LoadBreakPoints()
RETURN

STATIC FUNCTION LoadBreakPoints()
   LOCAL cBreakFile := s_debugDir + hb_ps() + "hb_break.dbg"
   LOCAL nHandle, cLine
   LOCAL aBreak := {}
   
   IF hb_FileExists(cBreakFile)
      nHandle := FOpen(cBreakFile, FO_READ)
      IF nHandle != F_ERROR
         DO WHILE !FEof(nHandle)
            cLine := FReadLn(nHandle)
            IF !Empty(cLine) .AND. Left(cLine, 1) != "#"
               // Format is file:line
               aBreak := hb_ATokens(cLine, ":")
               IF Len(aBreak) >= 2
                  __dbgSetBreak(aBreak[1], Val(aBreak[2]))
               ENDIF
            ENDIF
         ENDDO
         FClose(nHandle)
      ENDIF
   ENDIF
RETURN .T.

FUNCTION HarbourDebugHook(nMode, cFile, nLine, nValue)
   LOCAL nHandle, cCommand, cParam, aVars, cVarName, xValue
   LOCAL aComponents, cValueStr
   
   DO CASE
      CASE nMode == HB_DBG_VMQUIT
         // Cleanup when VM quits
         s_lRunning := .F.
         QOut("Harbour Debug: VM exiting")
         
      CASE nMode == HB_DBG_BREAKPOINT .OR. nMode == HB_DBG_STEP
         // Stop at breakpoint or step
         s_nBreakLine := nLine
         s_cBreakFile := cFile
         
         QOut("Harbour Debug: Hit breakpoint at " + cFile + ":" + AllTrim(Str(nLine)))
         
         // Create break flag file
         nHandle := FCreate(s_debugDir + hb_ps() + "break.flag")
         IF nHandle != F_ERROR
            FWrite(nHandle, cFile + ":" + AllTrim(Str(nLine)))
            FClose(nHandle)
         ENDIF
         
         // Export variables
         ExportVariables()
         
         // Wait for command
         DO WHILE s_lRunning
            cCommand := CheckForCommand()
            IF !Empty(cCommand)
               QOut("Harbour Debug: Received command: " + cCommand)
               
               SWITCH cCommand
                  CASE "STEP_OVER"
                     __dbgSetStep()
                     EXIT
                     
                  CASE "STEP_INTO"
                     __dbgSetTrace()
                     EXIT
                     
                  CASE "RESUME"
                     __dbgSetGo()
                     EXIT
                     
                  CASE "RUN_TO"
                     // Read parameters
                     aComponents := ReadCommandParams()
                     IF Len(aComponents) >= 2
                        __dbgSetBreak(aComponents[1], Val(aComponents[2]))
                        __dbgSetGo()
                     ENDIF
                     EXIT
                     
                  CASE "STOP"
                     __dbgSetQuit()
                     EXIT
               END SWITCH
               
               EXIT // Exit wait loop once we have a command
            ENDIF
            
            hb_idleSleep(0.1) // Small delay to avoid CPU spinning
         ENDDO
   ENDCASE
   
RETURN HB_SUCCESS

STATIC FUNCTION CheckForCommand()
   LOCAL cCommandFile := s_debugDir + hb_ps() + "command.txt"
   LOCAL nHandle, cCommand := ""
   
   IF hb_FileExists(cCommandFile)
      nHandle := FOpen(cCommandFile, FO_READ)
      IF nHandle != F_ERROR
         cCommand := FReadStr(nHandle, 100)
         FClose(nHandle)
         
         // Delete command file after reading
         FErase(cCommandFile)
      ENDIF
   ENDIF
   
RETURN AllTrim(cCommand)

STATIC FUNCTION ReadCommandParams()
   LOCAL cParamFile := s_debugDir + hb_ps() + "command.txt"
   LOCAL nHandle, cLine, aParams := {}
   
   IF hb_FileExists(cParamFile)
      nHandle := FOpen(cParamFile, FO_READ)
      IF nHandle != F_ERROR
         // Skip first line (command)
         FReadLn(nHandle)
         
         // Read remaining lines as parameters
         DO WHILE !FEof(nHandle)
            cLine := FReadLn(nHandle)
            IF !Empty(cLine)
               AAdd(aParams, AllTrim(cLine))
            ENDIF
         ENDDO
         FClose(nHandle)
      ENDIF
   ENDIF
   
RETURN aParams

STATIC FUNCTION ExportVariables()
   LOCAL nHandle, x, cVarName, xValue, cType, cValueStr
   LOCAL aVars := __dbgVMVarLGet() // Get local variables
   
   nHandle := FCreate(s_debugDir + hb_ps() + "variables.txt")
   IF nHandle != F_ERROR
      // Write local variables
      FOR x := 1 TO Len(aVars)
         cVarName := aVars[x][1]
         xValue := aVars[x][2]
         cType := ValType(xValue)
         
         // Convert value to string based on type
         DO CASE
            CASE cType == "C"
               cValueStr := '"' + xValue + '"'
            CASE cType == "N"
               cValueStr := AllTrim(Str(xValue))
            CASE cType == "L"
               cValueStr := IIF(xValue, ".T.", ".F.")
            CASE cType == "D"
               cValueStr := DToC(xValue)
            CASE cType == "A"
               cValueStr := "Array(" + AllTrim(Str(Len(xValue))) + ")"
            CASE cType == "O"
               cValueStr := "Object"
            CASE cType == "U"
               cValueStr := "NIL"
            CASE cType == "B"
               cValueStr := "Block"
            OTHERWISE
               cValueStr := "?"
         ENDCASE
         
         FWrite(nHandle, cVarName + "=" + cType + ":" + cValueStr + hb_eol())
      NEXT
      
      FClose(nHandle)
   ENDIF
RETURN .T.

INIT PROCEDURE __INTELLIJ_DEBUG_INIT
   _INTELLIJ_DEBUGGER_INIT()
RETURN
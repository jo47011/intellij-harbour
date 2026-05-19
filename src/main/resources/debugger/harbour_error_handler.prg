// Shared error handling functions for IntelliJ Harbour Plugin
// This file contains core error handling logic used by both debug and run modes
// DO NOT include INIT/EXIT procedures here - those go in the mode-specific files

#ifndef CRLF
#define CRLF Chr(13)+Chr(10)
#endif

// Format the error message header
// Uses a labeled format that shows ALL fields (even when empty) so the user
// sees the full picture of the error.
FUNCTION FormatErrorMessage(oError)
   LOCAL cMessage := ""
   LOCAL cSubSystem, cDescription, cOperation, cFileName, cGenCode

   cSubSystem := IIF(ValType(oError:SubSystem) == "C", oError:SubSystem, "")
   cDescription := IIF(ValType(oError:Description) == "C", oError:Description, "")
   cOperation := IIF(ValType(oError:Operation) == "C", oError:Operation, "")
   cFileName := IIF(ValType(oError:FileName) == "C", oError:FileName, "")
   cGenCode := LTrim(Str(oError:GenCode))

   cMessage := "RUNTIME ERROR" + CRLF
   cMessage += "  Fehler   : " + cDescription + CRLF
   cMessage += "  Operation: " + cOperation + CRLF
   cMessage += "  Filename : " + cFileName + CRLF
   cMessage += "  Code     : " + cGenCode + CRLF
   cMessage += "  SubSystem: " + cSubSystem + CRLF
   cMessage += CRLF

   RETURN cMessage

// Collect the current stack trace
// Skips only our own plugin helpers by name so the user sees their full call chain
// (including error-handler functions and (b)INIT_HB blocks)
FUNCTION CollectStackTrace()
   LOCAL aStack := {}
   LOCAL i := 1
   LOCAL cProcName, nProcLine, cProcFile, cUpper

   DO WHILE .T.
      cProcName := ProcName(i)

      // Stop when we reach the top
      IF Empty(cProcName)
         EXIT
      ENDIF

      // Skip our own helper functions so they don't pollute the user's stack
      cUpper := Upper(cProcName)
      IF cUpper == "COLLECTSTACKTRACE" .OR. ;
         cUpper == "PRINTDEBUGSTACKTRACE" .OR. ;
         cUpper == "FORMATSTACKTRACE" .OR. ;
         cUpper == "FORMATERRORMESSAGE" .OR. ;
         cUpper == "FORMATCOMPLETEERROR" .OR. ;
         cUpper == "MONITORANDPASSERROR"
         i++
         LOOP
      ENDIF

      nProcLine := ProcLine(i)
      cProcFile := ProcFile(i)

      AAdd(aStack, {cProcName, nProcLine, cProcFile})

      i++
   ENDDO

   RETURN aStack

// Format stack trace for output
// Format: "  NAME(line) in file.prg" — matches RUNTIME_FUNCTION_PATTERN in
// HarbourCompilerOutputFilter so PyCharm makes both function and file clickable.
// When no file is known (e.g. (b)INIT_HB blocks), omits the " in file.prg" part.
FUNCTION FormatStackTrace(aStack)
   LOCAL cTrace := "Stack trace:" + CRLF
   LOCAL aFrame
   LOCAL cFileName

   FOR EACH aFrame IN aStack
      cTrace += "  " + aFrame[1] + "(" + LTrim(Str(aFrame[2])) + ")"

      IF !Empty(aFrame[3])
         // Show just the filename (no full path) so the user sees what they expect
         cFileName := aFrame[3]
         IF "\" $ cFileName
            cFileName := SubStr(cFileName, RAt("\", cFileName) + 1)
         ELSEIF "/" $ cFileName
            cFileName := SubStr(cFileName, RAt("/", cFileName) + 1)
         ENDIF
         cTrace += " in " + cFileName
      ENDIF

      cTrace += CRLF
   NEXT

   RETURN cTrace

// Output error message to stderr and optionally to a log file
FUNCTION OutputError(cMessage)
   LOCAL nStderr := 2  // File handle for stderr
   LOCAL hFile, cLogFile
   
   // Write to stderr - this appears in console and is captured by IntelliJ
   FWrite(nStderr, cMessage)
   
   // Always try to write to a log file for GUI applications
   // This ensures errors are visible even when stderr is not available
   // Write to root directory where the error monitor is looking
   cLogFile := "pycharm_error.log"
   hFile := FOpen(cLogFile, 1)  // Open for writing, append mode
   IF hFile == -1
      hFile := FCreate(cLogFile)  // Create if doesn't exist
   ELSE
      FSeek(hFile, 0, 2)  // Seek to end
   ENDIF
   
   IF hFile != -1
      FWrite(hFile, DToS(Date()) + " " + Time() + " PyCharm Debug Error:" + CRLF)
      FWrite(hFile, cMessage)
      FWrite(hFile, CRLF + Replicate("-", 70) + CRLF + CRLF)
      FClose(hFile)
   ENDIF
   
   RETURN NIL

// Helper function to format complete error with stack trace
FUNCTION FormatCompleteError(oError)
   LOCAL cMessage
   LOCAL aStack
   
   // Get error message
   cMessage := FormatErrorMessage(oError)
   
   // Get and format stack trace
   aStack := CollectStackTrace()
   cMessage += FormatStackTrace(aStack)
   
   RETURN cMessage

// Extract relevant error information for logging
FUNCTION GetErrorInfo(oError)
   LOCAL hInfo := {=>}
   
   // Safely extract all error properties
   hInfo["description"] := IIF(ValType(oError:Description) == "C", oError:Description, "Unknown error")
   hInfo["subsystem"] := IIF(ValType(oError:SubSystem) == "C", oError:SubSystem, "UNKNOWN")
   hInfo["gencode"] := oError:GenCode
   hInfo["operation"] := IIF(ValType(oError:Operation) == "C", oError:Operation, "")
   hInfo["filename"] := IIF(ValType(oError:FileName) == "C", oError:FileName, "")
   hInfo["candefault"] := IIF(ValType(oError:CanDefault) == "L", oError:CanDefault, .F.)
   hInfo["canretry"] := IIF(ValType(oError:CanRetry) == "L", oError:CanRetry, .F.)
   hInfo["cansubstitute"] := IIF(ValType(oError:CanSubstitute) == "L", oError:CanSubstitute, .F.)
   
   RETURN hInfo

// ================================================================================================
// PUBLIC API for users with custom ErrorBlock handlers
// ================================================================================================

/**
 * printDebugStackTrace([oError], [cExtraStack]) - Public procedure for custom error handlers
 *
 * Call this from your custom ErrorBlock handler to generate clickable stack traces
 * in PyCharm/IntelliJ console, even when using custom error handling.
 *
 * Parameters (both optional):
 *   oError      - error object; if passed, the root cause is logged
 *                 (Fehler / Operation / Filename / Code / SubSystem)
 *   cExtraStack - pre-formatted stack text. When supplied this REPLACES our
 *                 internal ProcName/ProcLine walk (no duplication). Format each
 *                 frame as "  NAME(line) in file.prg\r\n" (two-space indent —
 *                 mandatory for PyCharm clickability). Omit to let us walk for you.
 *
 * Simplest usage — let us walk the stack:
 *   FUNCTION MyCustomHandler(oError)
 *      #if defined(DBG_PORT) || defined(PYCHARM_RUN)
 *         printDebugStackTrace(oError)
 *      #endif
 *      QUIT
 *   RETURN NIL
 *
 * Advanced — supply your own stack (e.g., started at a different depth):
 *   LOCAL cExtra := "", i := 1, CRLF := Chr(13) + Chr(10)
 *   DO WHILE !Empty(ProcName(i))
 *      cExtra += "  " + Trim(ProcName(i)) + ;
 *                "(" + LTrim(Str(ProcLine(i))) + ")"
 *      IF !Empty(ProcFile(i))
 *         cExtra += " in " + ProcFile(i)
 *      ENDIF
 *      cExtra += CRLF
 *      i++
 *   ENDDO
 *   printDebugStackTrace(oError, cExtra)
 */
#if defined(DBG_PORT) || defined(PYCHARM_RUN)
// Full implementation when running in PyCharm environment
PROCEDURE printDebugStackTrace(oError, cExtraStack)
   LOCAL cStackTrace, aStack
   LOCAL hFile, cLogFile
   LOCAL lUseCallerStack := ValType(cExtraStack) == "C" .AND. !Empty(cExtraStack)

   // Format stack trace for PyCharm console pattern matching
   cStackTrace := "[" + DToS(Date()) + " " + Time() + "]" + CRLF

   // Include root cause when caller passed the error object
   IF ValType(oError) == "O"
      cStackTrace += FormatErrorMessage(oError)
   ELSE
      cStackTrace += "RUNTIME ERROR from custom ErrorBlock" + CRLF
   ENDIF

   // Use the caller's stack when supplied (avoids duplicating frames the caller
   // already walked); otherwise collect and format our own stack via ProcName/ProcLine.
   IF lUseCallerStack
      cStackTrace += "Stack trace:" + CRLF
      cStackTrace += cExtraStack
      IF Right(cExtraStack, 2) != CRLF
         cStackTrace += CRLF
      ENDIF
   ELSE
      aStack := CollectStackTrace()
      cStackTrace += FormatStackTrace(aStack)
   ENDIF

   // Write to .hbmk/pycharm_errors.log for PyCharm to detect
   IF !hb_DirExists(".hbmk")
      MakeDir(".hbmk")
   ENDIF

   cLogFile := ".hbmk" + hb_ps() + "pycharm_errors.log"
   hFile := FOpen(cLogFile, 1)
   IF hFile == -1
      hFile := FCreate(cLogFile)
   ELSE
      FSeek(hFile, 0, 2)
   ENDIF

   IF hFile != -1
      // Write in the runtime's native codepage; the plugin auto-detects
      // (UTF-8 → project charset → ISO-8859-1) when reading.
      FWrite(hFile, cStackTrace)
      FWrite(hFile, Replicate("-", 70) + CRLF + CRLF)
      FClose(hFile)
   ENDIF

   // Also output to console for immediate visibility
   ? cStackTrace

RETURN
#else
// Stub implementation for standalone compilation
PROCEDURE printDebugStackTrace(oError, cExtraStack)
   // Empty stub - does nothing when compiled outside PyCharm
   // This prevents "undefined reference" errors during standalone compilation
   HB_SYMBOL_UNUSED(oError)
   HB_SYMBOL_UNUSED(cExtraStack)
RETURN
#endif
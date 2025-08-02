// Shared error handling functions for IntelliJ Harbour Plugin
// This file contains core error handling logic used by both debug and run modes
// DO NOT include INIT/EXIT procedures here - those go in the mode-specific files

#ifndef CRLF
#define CRLF Chr(13)+Chr(10)
#endif

// Format the error message header
FUNCTION FormatErrorMessage(oError)
   LOCAL cMessage := ""
   LOCAL cSubSystem, cDescription, cOperation
   
   // Safely extract error information
   cSubSystem := IIF(ValType(oError:SubSystem) == "C", oError:SubSystem, "UNKNOWN")
   cDescription := IIF(ValType(oError:Description) == "C", oError:Description, "Unknown error")
   cOperation := IIF(ValType(oError:Operation) == "C", oError:Operation, "")
   
   // Format error header
   cMessage := "RUNTIME ERROR: " + cDescription + CRLF
   cMessage += "Error " + cSubSystem + "/" + LTrim(Str(oError:GenCode))
   
   IF !Empty(cOperation)
      cMessage += ": " + cOperation
   ENDIF
   
   cMessage += CRLF + CRLF
   
   RETURN cMessage

// Collect the current stack trace
FUNCTION CollectStackTrace()
   LOCAL aStack := {}
   LOCAL i := 3  // Skip error handler frames (start from caller of error handler)
   LOCAL cProcName, nProcLine, cProcFile
   
   // Collect all stack frames
   DO WHILE .T.
      cProcName := ProcName(i)
      
      // Stop when we reach the top
      IF Empty(cProcName)
         EXIT
      ENDIF
      
      // Skip internal init procedures
      IF "(b)" $ cProcName .OR. "$" $ cProcName
         i++
         LOOP
      ENDIF
      
      nProcLine := ProcLine(i)
      cProcFile := ProcFile(i)
      
      // Add frame to stack
      AAdd(aStack, {cProcName, nProcLine, cProcFile})
      
      i++
   ENDDO
   
   RETURN aStack

// Format stack trace for output
FUNCTION FormatStackTrace(aStack)
   LOCAL cTrace := "Stack trace:" + CRLF
   LOCAL aFrame
   LOCAL cFileName
   
   // Format each stack frame
   FOR EACH aFrame IN aStack
      // Add filename if available
      IF !Empty(aFrame[3])
         // Extract just the filename from full path
         cFileName := aFrame[3]
         IF "\" $ cFileName
            cFileName := SubStr(cFileName, RAt("\", cFileName) + 1)
         ELSEIF "/" $ cFileName
            cFileName := SubStr(cFileName, RAt("/", cFileName) + 1)
         ENDIF
         
         // Format: "  at filename.prg(line)" - matches FILE_PATTERN in filter
         cTrace += "  at " + cFileName + "(" + LTrim(Str(aFrame[2])) + ")"
      ELSE
         // Format: "  at FUNCTION(line)" - matches RUNTIME_FUNCTION_PATTERN
         cTrace += "  at " + aFrame[1] + "(" + LTrim(Str(aFrame[2])) + ")"
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
 * printDebugStackTrace() - Public procedure for custom error handlers
 * 
 * Call this from your custom ErrorBlock handler to generate clickable stack traces
 * in PyCharm/IntelliJ console, even when using custom error handling.
 * 
 * Usage in custom error handler:
 *   ErrorBlock({|oError| MyCustomHandler(oError)})
 *   
 *   FUNCTION MyCustomHandler(oError)
 *      // Your custom error logic here
 *      LogToMyDatabase(oError)
 *      
 *      // Generate PyCharm-compatible stack trace
 *      printDebugStackTrace()
 *      
 *      // Continue with your error handling
 *      QUIT
 *   RETURN NIL
 */
PROCEDURE printDebugStackTrace()
   LOCAL cStackTrace, aStack
   LOCAL hFile, cLogFile
   LOCAL i := 1
   
   // Collect current stack trace
   aStack := CollectStackTrace()
   
   // Format stack trace for PyCharm console pattern matching
   cStackTrace := "[" + DToS(Date()) + " " + Time() + "]" + CRLF
   cStackTrace += "RUNTIME ERROR from custom ErrorBlock" + CRLF
   cStackTrace += "Custom error handler called printDebugStackTrace()" + CRLF + CRLF
   cStackTrace += FormatStackTrace(aStack)
   
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
      FWrite(hFile, cStackTrace)
      FWrite(hFile, Replicate("-", 70) + CRLF + CRLF)
      FClose(hFile)
   ENDIF
   
   // Also output to console for immediate visibility
   ? cStackTrace
   
RETURN
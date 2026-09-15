// Non-intrusive error monitoring for IntelliJ integration
// This file logs errors without interfering with user's error handling
// Works with all Harbour projects, with or without custom error handling

// Error constants (avoiding include dependency)
#define ES_ERROR     2
#define EG_BOUND     1

#ifndef CRLF
#define CRLF Chr(13)+Chr(10)
#endif

STATIC s_bOriginalHandler := NIL
STATIC s_lMonitorInstalled := .F.
STATIC s_lInRecursion := .F.  // Module-level recursion guard

// Use a monitoring approach that periodically checks and wraps the error handler
INIT PROCEDURE __HbIntelliJErrorMonitor()  // Run last
   // Only install once
   IF !s_lMonitorInstalled
      // Get whatever error handler is currently installed and store it
      s_bOriginalHandler := ErrorBlock()
      
      // Wrap it with our monitor
      ErrorBlock({|oError| MonitorAndPassError(oError, s_bOriginalHandler)})
      s_lMonitorInstalled := .T.
   ENDIF
RETURN

STATIC FUNCTION MonitorAndPassError(oError, bOriginalHandler)
   LOCAL cErrorLog, hFile
   LOCAL cStackTrace
   LOCAL i := 1
   
   // CRITICAL: Prevent infinite recursion using module-level guard
   IF s_lInRecursion
      // We're already processing an error - bail out with standard behavior
      BREAK(oError)
   ENDIF
   s_lInRecursion := .T.
   
   // Capture stack trace immediately - this is the earliest point!
   // Use the same labeled German format as harbour_error_handler.prg for consistency.
   cStackTrace := "[" + DToS(Date()) + " " + Time() + "]" + CRLF
   cStackTrace += "RUNTIME ERROR" + CRLF
   cStackTrace += "  Fehler   : " + IIF(ValType(oError:description) == "C", oError:description, "") + CRLF
   cStackTrace += "  Operation: " + IIF(ValType(oError:operation) == "C", oError:operation, "") + CRLF
   cStackTrace += "  Filename : " + IIF(ValType(oError:fileName) == "C", oError:fileName, "") + CRLF
   cStackTrace += "  Code     : " + LTrim(Str(oError:genCode)) + CRLF
   cStackTrace += "  SubSystem: " + IIF(ValType(oError:subSystem) == "C", oError:subSystem, "") + CRLF
   cStackTrace += CRLF
   cStackTrace += "Stack trace:" + CRLF
   
   // Collect stack trace starting from the error point
   DO WHILE !Empty(ProcName(i))
      cStackTrace += "  " + Trim(ProcName(i)) + "(" + LTrim(Str(ProcLine(i))) + ")"
      IF !Empty(ProcFile(i))
         cStackTrace += " in " + ProcFile(i)
      ENDIF
      cStackTrace += CRLF
      i++
   ENDDO
   
   // Write to .hbmk/pycharm_errors.log
   IF !hb_DirExists(".hbmk")
      MakeDir(".hbmk")
   ENDIF
   
   cErrorLog := ".hbmk" + hb_ps() + "pycharm_errors.log"
   hFile := FOpen(cErrorLog, 1)
   IF hFile == -1
      hFile := FCreate(cErrorLog)
   ELSE
      FSeek(hFile, 0, 2)
   ENDIF
   
   IF hFile != -1
      // Write in the runtime's native codepage; PyCharm decodes using the
      // project's configured charset (set via File | Settings | File Encodings).
      FWrite(hFile, cStackTrace)
      FWrite(hFile, Replicate("-", 70) + CRLF + CRLF)
      FClose(hFile)
   ENDIF
   
   // Pass to original handler (if any)
   s_lInRecursion := .F.  // Reset flag before calling original handler
   IF ValType(bOriginalHandler) == "B"
      RETURN Eval(bOriginalHandler, oError)
   ELSE
      // Default behavior
      BREAK(oError)
   ENDIF
RETURN NIL


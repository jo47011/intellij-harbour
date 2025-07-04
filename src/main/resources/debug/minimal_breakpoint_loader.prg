// Minimal init.cld breakpoint loader for GUI programs
// This code is injected automatically when debugging GUI programs

#ifdef __HARBOUR_DEBUG__

STATIC PROCEDURE LoadInitCld()
   LOCAL cContent, aLines, cLine, aTokens, nLine, cFile, i, cKey
   LOCAL aBreakpoints := {}
   
   // Check if init.cld exists
   IF !File("init.cld")
      RETURN
   ENDIF
   
   // Read init.cld file
   cContent := hb_MemoRead("init.cld")
   IF Empty(cContent)
      RETURN
   ENDIF
   
   // Parse breakpoint lines
   aLines := hb_ATokens(cContent, Chr(10))
   FOR i := 1 TO Len(aLines)
      cLine := AllTrim(StrTran(aLines[i], Chr(13), ""))
      IF !Empty(cLine) .AND. Left(cLine, 2) == "BP"
         // Parse: BP line_number filename
         aTokens := hb_ATokens(cLine, " ")
         IF Len(aTokens) >= 3
            nLine := Val(aTokens[2])
            cFile := AllTrim(aTokens[3])
            
            // Extract filename without path for key
            cKey := cFile
            IF "/" $ cKey .OR. "\" $ cKey
               cKey := SubStr(cKey, Max(RAt("/", cKey), RAt("\", cKey)) + 1)
            ENDIF
            
            // Store breakpoint info for manual loading
            AAdd(aBreakpoints, {cKey, nLine, cFile})
         ENDIF
      ENDIF
   NEXT
   
   // Display loaded breakpoints for user information
   IF Len(aBreakpoints) > 0
      ? "=== Breakpoints loaded from init.cld ==="
      FOR i := 1 TO Len(aBreakpoints)
         ? "Breakpoint:", aBreakpoints[i,1] + ":" + AllTrim(Str(aBreakpoints[i,2]))
      NEXT
      ? "Use standard Harbour debugger (Alt+D) to activate debugging"
      ? "========================================"
   ENDIF
   
RETURN

#endif
// IntelliJ Harbour Debug Handler - FIXED VERSION 1.3.1
// Based on working VSCode pattern - NO socket operations inside debug handler

#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#include <hbdebug.ch>
#include <hbmemvar.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
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

// Main debug entry point - exact VSCode pattern
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   LOCAL i, tmp, j, vv
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Register with VM - this works
      __dbgSetEntry()
      ? "IntelliJ Debug Handler registered successfully"
      
   CASE nMode == HB_DBG_ACTIVATE
      // Safe processing during ACTIVATE only - like VSCode
      ? "=== HB_DBG_ACTIVATE - IntelliJ Variable Display ==="
      ? "Level:", __dbgProcLevel()
      
      // Process stack frames with variables (VSCode pattern)
      IF uParam3 != NIL .AND. ValType(uParam3) == "A"
         FOR i := 1 TO Len(uParam3)
            ? "Stack " + AllTrim(Str(i)) + ":" + uParam3[i,HB_DBG_CS_MODULE] + "-" + uParam3[i,HB_DBG_CS_FUNCTION] + ;
              "(" + AllTrim(Str(uParam3[i,HB_DBG_CS_LINE])) + ")*" + AllTrim(Str(uParam3[i,HB_DBG_CS_LEVEL])) + ;
              " " + AllTrim(Str(Len(uParam3[i,HB_DBG_CS_LOCALS]))) + " locals"
              
            // Show local variables with actual names (THE FIX!)
            FOR j := 1 TO Len(uParam3[i,HB_DBG_CS_LOCALS])
               tmp := uParam3[i,HB_DBG_CS_LOCALS,j]
               vv := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
               ? "  Local " + AllTrim(Str(j)) + ": " + tmp[HB_DBG_VAR_NAME] + " (" + tmp[HB_DBG_VAR_TYPE] + ") = " + hb_CStr(vv)
            NEXT
         NEXT
      ENDIF
      
      // Show module information
      IF uParam4 != NIL .AND. ValType(uParam4) == "A"
         FOR i := 1 TO Len(uParam4)
            ? "Module " + AllTrim(Str(i)) + ": " + uParam4[i,1] // Module name
         NEXT
      ENDIF
      
   OTHERWISE
      // Do nothing for other events - no socket operations
   ENDCASE
RETURN
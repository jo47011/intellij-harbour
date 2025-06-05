// Check what parameters are passed to HB_DBG_ACTIVATE
#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#include <hbdebug.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#endif

STATIC s_lRegistered := .F.

// Main debug entry point - check parameters
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   IF nMode == HB_DBG_GETENTRY
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
      ENDIF
   ELSEIF nMode == HB_DBG_ACTIVATE .AND. s_lRegistered
      ? "HB_DBG_ACTIVATE called"
      ? "uParam1 type:", ValType(uParam1), "value:", uParam1
      ? "uParam2 type:", ValType(uParam2), "value:", uParam2  
      ? "uParam3 type:", ValType(uParam3), "len:", IF(ValType(uParam3)=="A", Len(uParam3), "N/A")
      ? "uParam4 type:", ValType(uParam4), "len:", IF(ValType(uParam4)=="A", Len(uParam4), "N/A")
   ENDIF
RETURN
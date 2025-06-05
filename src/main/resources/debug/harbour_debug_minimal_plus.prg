// Minimal Plus: Just GETENTRY + MODULENAME
#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#include <hbdebug.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_MODULENAME     1
#endif

STATIC s_lRegistered := .F.

// Main debug entry point
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   IF nMode == HB_DBG_GETENTRY
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
      ENDIF
   ELSEIF nMode == HB_DBG_MODULENAME .AND. s_lRegistered
      ? "MODULENAME:", uParam1
   ENDIF
   
   // Handle nothing else to avoid crashes
RETURN
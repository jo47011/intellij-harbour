// Log only version - see what events we receive
#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#include <hbdebug.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#endif

STATIC s_lRegistered := .F.

// Main debug entry point - just count events
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   STATIC s_nEventCount := 0
   
   IF nMode == HB_DBG_GETENTRY
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
      ENDIF
   ELSE
      s_nEventCount++
      IF s_nEventCount <= 5  // Only show first 5 events
         ? "Event", s_nEventCount, "mode:", nMode
      ENDIF
   ENDIF
RETURN
// Working debug handler - GETENTRY registration + variable name capture
#include <hbdebug.ch>
#include <fileio.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#endif

STATIC s_nLogHandle := -1

// Main debug entry point - handles registration and variable names
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   // Open log file on first call
   IF s_nLogHandle == -1
      s_nLogHandle := FCreate("/home/developer/workspace/debug_events_working.log", FC_NORMAL)
      IF s_nLogHandle >= 0
         FWrite(s_nLogHandle, "=== Working Debug Events Log ===" + Chr(13) + Chr(10))
      ENDIF
   ENDIF
   
   IF nMode == HB_DBG_GETENTRY
      ? "HB_DBG_GETENTRY received - registering"
      __dbgSetEntry()
      ? "Registration complete - now should receive all debug events"
      LogEvent("GETENTRY - registered successfully")
   ENDIF
   
   // Only handle GETENTRY for now to avoid segfaults
   // TODO: Add other debug events after this is proven stable
RETURN

STATIC PROCEDURE LogEvent(cMessage)
   IF s_nLogHandle >= 0
      FWrite(s_nLogHandle, Time() + " " + cMessage + Chr(13) + Chr(10))
   ENDIF
RETURN
// Absolutely minimal debug handler - just log events to file
// No arrays, no hashes, no complex structures

#include <hbdebug.ch>
#include <fileio.ch>

#ifndef HB_DBG_MODULENAME
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#endif

// Main debug entry point - absolutely minimal
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   STATIC s_nLogHandle := -1
   
   // Handle VM registration first
   IF nMode == HB_DBG_GETENTRY
      __dbgSetEntry()  // Register with VM to receive debug events
      // Log that we've registered
      s_nLogHandle := FCreate("/home/developer/workspace/debug_events.log", FC_NORMAL)
      IF s_nLogHandle >= 0
         FWrite(s_nLogHandle, "=== REGISTERED WITH VM FOR DEBUG EVENTS ===" + Chr(13) + Chr(10))
      ENDIF
      RETURN
   ENDIF
   
   // Open log file on first call
   IF s_nLogHandle == -1
      s_nLogHandle := FCreate("/home/developer/workspace/debug_events.log", FC_NORMAL)
      IF s_nLogHandle >= 0
         FWrite(s_nLogHandle, "=== Debug Events Log ===" + Chr(13) + Chr(10))
      ENDIF
   ENDIF
   
   // Log the event
   IF s_nLogHandle >= 0
      FWrite(s_nLogHandle, "Mode: " + Str(nMode))
      
      IF nMode == HB_DBG_MODULENAME .AND. uParam1 != NIL
         FWrite(s_nLogHandle, " Module: " + hb_CStr(uParam1))
      ELSEIF nMode == HB_DBG_LOCALNAME .AND. uParam1 != NIL
         FWrite(s_nLogHandle, " Local: " + hb_CStr(uParam1))
         IF uParam2 != NIL
            FWrite(s_nLogHandle, " Index: " + Str(uParam2))
         ENDIF
      ELSEIF nMode == HB_DBG_STATICNAME .AND. uParam3 != NIL
         FWrite(s_nLogHandle, " Static: " + hb_CStr(uParam3))
      ENDIF
      
      FWrite(s_nLogHandle, Chr(13) + Chr(10))
   ENDIF
RETURN

// Cleanup function
FUNCTION __CloseDebugLog()
   STATIC s_nLogHandle := -1
   IF s_nLogHandle >= 0
      FClose(s_nLogHandle)
      s_nLogHandle := -1
   ENDIF
RETURN .T.
// Ultra minimal debug handler - exactly like the working version
#include <hbdebug.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#endif

// Main debug entry point - absolutely minimal
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   // Only handle GETENTRY to register ourselves
   IF nMode == HB_DBG_GETENTRY
      ? "HB_DBG_GETENTRY received - registering"
      __dbgSetEntry()
      ? "Registration complete"
   ENDIF
   
   // Do nothing else to avoid any complex operations
RETURN
// IntelliJ Debug Handler - VSCode Pattern Implementation
// Based on working VSCode debugger approach

#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 9876
#endif

#include <hbdebug.ch>
#include <hbmemvar.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_SHOWLINE       5
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

#define CRLF Chr(13)+Chr(10)

// Simple state tracking
STATIC s_lRegistered := .F.
STATIC s_oSocket := NIL
STATIC s_nConnectAttempts := 0

// Main debug entry point - VSCode pattern
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Critical: Register with VM (proven working)
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
      ENDIF
      
   CASE nMode == HB_DBG_ACTIVATE
      // Safe processing during ACTIVATE (VSCode pattern)
      IF s_lRegistered
         HandleActivate(uParam1, uParam2, uParam3, uParam4)
      ENDIF
      
   OTHERWISE
      // Do nothing for other events to avoid crashes
      // VM will provide all data during HB_DBG_ACTIVATE
   ENDCASE
RETURN

// Handle HB_DBG_ACTIVATE with variable information
STATIC PROCEDURE HandleActivate(uParam1, uParam2, uParam3, uParam4)
   LOCAL i, j, aStack, aFrame, aLocals, tmp, vv
   
   ? "=== HB_DBG_ACTIVATE - Level:", __dbgProcLevel()
   
   // uParam3 contains stack information with variables
   IF uParam3 != NIL .AND. ValType(uParam3) == "A"
      aStack := uParam3
      
      ? "Stack frames:", Len(aStack)
      
      FOR i := 1 TO Len(aStack)
         aFrame := aStack[i]
         ? "Frame", i, ":", aFrame[HB_DBG_CS_MODULE], "-", aFrame[HB_DBG_CS_FUNCTION]
         ? "  Line:", aFrame[HB_DBG_CS_LINE], "Level:", aFrame[HB_DBG_CS_LEVEL]
         
         // Process local variables in this frame
         aLocals := aFrame[HB_DBG_CS_LOCALS]
         ? "  Locals:", Len(aLocals)
         
         FOR j := 1 TO Len(aLocals)
            tmp := aLocals[j]
            // Get variable value safely
            vv := __dbgVMVarLGet(__dbgProcLevel() - tmp[HB_DBG_VAR_FRAME], tmp[HB_DBG_VAR_INDEX])
            ? "    Local", j, ":", tmp[HB_DBG_VAR_NAME], "(", tmp[HB_DBG_VAR_TYPE], ") =", vv
         NEXT
      NEXT
   ENDIF
   
   // Try to connect to IntelliJ (safe during ACTIVATE)
   ConnectToIntelliJ()
RETURN

// Connect to IntelliJ debug server
STATIC PROCEDURE ConnectToIntelliJ()
   
   // Only try a few times
   IF s_oSocket == NIL .AND. s_nConnectAttempts < 3
      s_nConnectAttempts++
      
      ? "Connecting to IntelliJ on port", DBG_PORT, "(attempt", s_nConnectAttempts, ")"
      
      hb_inetInit()
      s_oSocket := hb_inetCreate(10)  // Short timeout
      hb_inetConnect("127.0.0.1", DBG_PORT, s_oSocket)
      
      IF hb_inetErrorCode(s_oSocket) != 0
         ? "Connection failed"
         s_oSocket := NIL
      ELSE
         ? "Connected to IntelliJ!"
         // Send handshake
         hb_inetSend(s_oSocket, "HARBOUR_DEBUG" + CRLF + Str(__PIDNum()) + CRLF)
      ENDIF
   ENDIF
   
   // Send variable information if connected
   IF s_oSocket != NIL .AND. hb_inetErrorCode(s_oSocket) == 0
      hb_inetSend(s_oSocket, "VARIABLES_READY" + CRLF)
   ENDIF
RETURN

#pragma BEGINDUMP

#include <hbapi.h>

#if defined( HB_OS_UNIX ) || defined( __DJGPP__ )
#  include <sys/types.h>
#  include <unistd.h>
#elif defined( HB_OS_WIN )
#  include <windows.h>
#elif defined( HB_OS_OS2 ) || defined( HB_OS_DOS )
#  include <process.h>
#endif

HB_FUNC( __PIDNUM )
{
#if defined( HB_OS_WIN_CE )
   hb_retni( 0 );
#elif defined( HB_OS_WIN )
   hb_retnint( GetCurrentProcessId() );
#elif ( defined( HB_OS_OS2 ) && defined( __GNUC__ ) )
   hb_retnint( _getpid() );
#else
   hb_retnint( getpid() );
#endif
}

#pragma ENDDUMP
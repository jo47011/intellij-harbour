// Minimal Windows Debug Handler
// VERSION 1.0.282 - FILE COPY FIX

#pragma -B-

#define DBG_PORT 9876
#define CRLF Chr(13)+Chr(10)

#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_SHOWLINE       5
#define HB_DBG_VMQUIT         8

STATIC t_oDebugInfo

STATIC FUNCTION __DEBUGITEM(xValue)
   IF xValue != NIL
      t_oDebugInfo := xValue
   ENDIF
   IF t_oDebugInfo == NIL
      t_oDebugInfo := { "socket" => NIL, "lRunning" => .T. }
   ENDIF
RETURN t_oDebugInfo

PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   LOCAL oDebugInfo
   
   IF hb_GetEnv("HB_REMOTE_DEBUG") != "1"
      RETURN
   ENDIF
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      __dbgSetEntry()
      
   CASE nMode == HB_DBG_SHOWLINE
      oDebugInfo := __DEBUGITEM()
      CheckSocket(.F.)
      
   CASE nMode == HB_DBG_ACTIVATE
      oDebugInfo := __DEBUGITEM()
      CheckSocket(.T.)
      
   CASE nMode == HB_DBG_VMQUIT
      oDebugInfo := __DEBUGITEM()
      IF !Empty(oDebugInfo["socket"])
         hb_inetSend(oDebugInfo["socket"], "VMQUIT" + CRLF)
         hb_inetClose(oDebugInfo["socket"])
         oDebugInfo["socket"] := NIL
      ENDIF
   ENDCASE
RETURN

STATIC PROCEDURE CheckSocket(lStopSent)
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   IF !lStopSent .AND. !oDebugInfo["lRunning"]
      hb_inetSend(oDebugInfo["socket"], "STOP:break:test.prg:1" + CRLF)
   ENDIF
RETURN

STATIC PROCEDURE SendLocals()
   LOCAL oDebugInfo
   
   oDebugInfo := __DEBUGITEM()
   
   IF Empty(oDebugInfo["socket"])
      RETURN
   ENDIF
   
   hb_inetSend(oDebugInfo["socket"], "LOCALS" + CRLF)
   hb_inetSend(oDebugInfo["socket"], "END_LOCALS" + CRLF)
RETURN

INIT PROCEDURE __InitWindowsDebugger()
   LOCAL oDebugInfo, hLog
   
   hLog := FCreate("VERSION_282_FILECOPY.txt", 0)
   IF hLog != -1
      FWrite(hLog, "=== VERSION 1.0.282 FILECOPY DEBUG LIBRARY LOADED ===" + Chr(13) + Chr(10))
      FClose(hLog)
   ENDIF
   
   IF hb_GetEnv("HB_REMOTE_DEBUG") != "1"
      RETURN
   ENDIF
   
   oDebugInfo := __DEBUGITEM()
   
   Set( _SET_CONSOLE, .T. )
   Set( _SET_DEBUG, .T. )
   __dbgSetEntry()
   
   oDebugInfo["lRunning"] := .T.
RETURN

#pragma BEGINDUMP

#include <hbapi.h>

#if defined( HB_OS_WIN )
#  include <windows.h>
#elif defined( HB_OS_UNIX )
#  include <sys/types.h>
#  include <unistd.h>
#endif

HB_FUNC( __PIDNUM )
{
#if defined( HB_OS_WIN )
   hb_retnint( GetCurrentProcessId() );
#else
   hb_retnint( getpid() );
#endif
}

#pragma ENDDUMP
// Complete IntelliJ Harbour Debug Handler - Working Registration + Socket Connection
// Version 1.3.0 - Final working solution

#pragma -B-
REQUEST HB_GT_STD_DEFAULT

#ifndef DBG_PORT
#define DBG_PORT 9876
#endif

#include <hbdebug.ch>
#include <hbmemvar.ch>
#include <fileio.ch>

#ifndef HB_DBG_GETENTRY
#define HB_DBG_GETENTRY       6
#define HB_DBG_ACTIVATE       7
#define HB_DBG_SHOWLINE       5
#define HB_DBG_MODULENAME     1
#define HB_DBG_LOCALNAME      2
#define HB_DBG_STATICNAME     3
#endif

#define CRLF Chr(13)+Chr(10)

// Simple debug state
STATIC s_lRegistered := .F.
STATIC s_oSocket := NIL
STATIC s_nConnectAttempts := 0

// Main debug entry point
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3, uParam4)
   
   DO CASE
   CASE nMode == HB_DBG_GETENTRY
      // Critical: Register with VM first
      IF !s_lRegistered
         ? "HB_DBG_GETENTRY - registering with VM"
         __dbgSetEntry()
         s_lRegistered := .T.
         ? "Debug handler registered successfully"
      ENDIF
      
   CASE nMode == HB_DBG_ACTIVATE .OR. nMode == HB_DBG_SHOWLINE
      // Handle line debugging - connect to IntelliJ
      IF s_lRegistered
         CheckIntelliJConnection()
      ENDIF
      
   CASE nMode == HB_DBG_MODULENAME
      ? "Module/Function:", uParam1
      
   CASE nMode == HB_DBG_LOCALNAME
      ? "Local variable:", uParam1, "index:", uParam2
      
   CASE nMode == HB_DBG_STATICNAME
      ? "Static variable:", uParam3
      
   ENDCASE
RETURN

// Check and maintain IntelliJ socket connection
STATIC PROCEDURE CheckIntelliJConnection()
   LOCAL cResponse, cCurrentFile, nCurrentLine, cMessage
   
   // Try to connect if not connected and haven't tried too many times
   IF s_oSocket == NIL .AND. s_nConnectAttempts < 5
      s_nConnectAttempts++
      
      ? "Attempting to connect to IntelliJ on port", DBG_PORT, "(attempt " + Str(s_nConnectAttempts) + ")"
      
      hb_inetInit()
      s_oSocket := hb_inetCreate(30)  // 30 second timeout
      hb_inetConnect("127.0.0.1", DBG_PORT, s_oSocket)
      
      IF hb_inetErrorCode(s_oSocket) != 0
         ? "Connection failed, error:", hb_inetErrorCode(s_oSocket)
         s_oSocket := NIL
      ELSE
         ? "Connected to IntelliJ debugger!"
         
         // Send handshake
         hb_inetSend(s_oSocket, HB_ARGV(0) + CRLF + Str(__PIDNum()) + CRLF)
         
         // Wait briefly for response
         hb_idleSleep(0.1)
         
         // Check for basic response
         IF hb_inetDataReady(s_oSocket) == 1
            cResponse := hb_inetRecvLine(s_oSocket)
            ? "IntelliJ response:", cResponse
         ENDIF
      ENDIF
   ENDIF
   
   // If connected, send basic status
   IF s_oSocket != NIL .AND. hb_inetErrorCode(s_oSocket) == 0
      // Send current line info to IntelliJ
      cCurrentFile := ProcFile(1)
      nCurrentLine := ProcLine(1)
      
      IF !Empty(cCurrentFile) .AND. !("harbour_debug" $ Lower(cCurrentFile))
         cMessage := "LINE:" + cCurrentFile + ":" + AllTrim(Str(nCurrentLine)) + CRLF
         hb_inetSend(s_oSocket, cMessage)
      ENDIF
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
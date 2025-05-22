// Harbour Debug Wrapper
// Place in: src/main/resources/debug/harbour_debug_wrapper.prg

#include "hbdebug.ch"
#include "hbsocket.ch"

STATIC s_debugSocket := NIL
STATIC s_debugPort := "9876"

PROCEDURE __HARBOUR_DEBUG_INIT__()
   LOCAL cPort := GetEnv("HARBOUR_DEBUG_PORT")
   
   IF !Empty(cPort)
      s_debugPort := cPort
      __INIT_DEBUG_SOCKET()
   ENDIF
   
   // Enable debugger
   ALTD(1)
   ALTD()
RETURN

STATIC FUNCTION __INIT_DEBUG_SOCKET()
   LOCAL nPort := Val(s_debugPort)
   
   s_debugSocket := hb_socketOpen()
   IF s_debugSocket != NIL
      hb_socketConnect(s_debugSocket, "127.0.0.1", nPort)
      
      // Send initial connection message
      hb_socketSend(s_debugSocket, "CONNECTED" + Chr(10))
   ENDIF
RETURN .T.

PROCEDURE __HARBOUR_DEBUG_BREAK__(cFile, nLine)
   LOCAL cCommand
   
   IF s_debugSocket != NIL
      hb_socketSend(s_debugSocket, "BREAK" + Chr(10) + cFile + Chr(10) + Str(nLine) + Chr(10))
      
      // Wait for debug commands
      DO WHILE .T.
         cCommand := hb_socketRecv(s_debugSocket, 1024)
         IF "RESUME" $ cCommand
            EXIT
         ENDIF
      ENDDO
   ENDIF
RETURN

PROCEDURE __HARBOUR_DEBUG_EXIT__()
   IF s_debugSocket != NIL
      hb_socketSend(s_debugSocket, "TERMINATED" + Chr(10))
      hb_socketClose(s_debugSocket)
   ENDIF
RETURN

INIT PROCEDURE __DEBUG_INIT
   __HARBOUR_DEBUG_INIT__()
RETURN

EXIT PROCEDURE __DEBUG_EXIT
   __HARBOUR_DEBUG_EXIT__()
RETURN
/*
* hbmiki remote service
*
* Usage: exeName() + " -i -u -s -h"
*/

#include "miki.ch"
#include "hbwin.ch"
#include "dbinfo.ch"
#include "remserver.ch"
#include "mynetio.ch"

#include "hbgtinfo.ch"

REQUEST MY_REQ_RDDI

#define SERVICE_NAME "hbmiki-remote-service"
#define SERVICE_ANZEIGE "Miki-Programm (Remote Service)"

/**
*
* Service so installieren bzw. un-installieren (als Admin):
* (muss als User: gruhn laufen, siehe logon panel in MSC->Services)
*
* hbmiki-service.exe -i | -u
*
* Service so starten bzw. stoppen
*
* net start hbmiki-remote-service | net stop hbmiki-remote-service
*
*
* ACHTUNG folgendes geht als RPC nicht:
*
*   hb_gtInfo(HB_GTI_WINTITLE,"gppp")
*/

PROCEDURE WinMain( ... )
LOCAL cMode:=hb_PValue( 1 )

LOCAL cMsg, nError

  IF cMode == NIL
    cMode:=""
  ENDIF

  if ! getEnv("USERNAME") $ "gruhn|administrator"
    qout( "Service kann nur als Administrator gestarted werden.")
    qout( "Aktueller Benutzer: " + getEnv("USERNAME"))
    return
  endif

  SWITCH Lower( cMode )
  CASE "-i"
  CASE "-install"

    IF win_serviceInstall( SERVICE_NAME, SERVICE_ANZEIGE, Chr( 34 ) +;
      hb_ProgName() + Chr( 34 ) + " -service", WIN_SERVICE_AUTO_START )
      OutStd( "Service has been successfully installed" + hb_eol() )
    ELSE
      nError:=wapi_GetLastError()
      cMsg:=Space( 128 )
      wapi_FormatMessage( ,,,, @cMsg )
      OutStd( hb_StrFormat( "Error installing service: %1$d %2$s", nError, cMsg ) + hb_eol() )
    ENDIF
    EXIT

  CASE "-u"
  CASE "-uninstall"

    IF win_serviceDelete( SERVICE_NAME )
      OutStd( "Service has been deleted" + hb_eol() )
    ELSE
      nError:=wapi_GetLastError()
      cMsg:=Space( 128 )
      wapi_FormatMessage( ,,,, @cMsg )
      OutStd( hb_StrFormat( "Error uninstalling service: %1$d %2$s", nError, cMsg ) + hb_eol() )
    ENDIF
    EXIT

  CASE "-s"
  CASE "-service"

    IF win_serviceStart( SERVICE_NAME, @hbnetio_WinServiceEntry() )
      OutStd( "Service has started OK" + hb_eol() )
    ELSE
      OutStd( hb_StrFormat( "Service has had some problems: %1$d", wapi_GetLastError() ) +;
        hb_eol() )
    ENDIF
    EXIT

  CASE "-h"
  CASE "-help"

    OutStd( "Usage: " + getFileName(exeName()) + " -i -u -s -h")
    EXIT

  OTHERWISE

    remServer( .T., ... )

    EXIT

  ENDSWITCH

RETURN

PROCEDURE hbnetio_WinServiceEntry( ... )
LOCAL bSignal:={|| win_serviceGetStatus() != WIN_SERVICE_RUNNING }

  remServer( .F., ... )

  win_serviceSetExitCode( 0 )
  win_serviceStop()

RETURN

/******************** eof windows service implementation *************/


/******************** remote server *************/
PROCEDURE remServer( lUi )
local pSockSrv

MEMVAR specialZeige,User,QTWidget
  PUBLIC specialZeige
  PUBLIC User
PRIVATE QTWidget

  qout( "Starting hbmiki-remote-server " )

  dirchange(hb_DirBase())

  rddSetDefault(MY_RDDI)
  rddInfo( RDDI_MEMOEXT , MY_MEMO_EXTENSION , MY_RDDI )

  readProperties(getPropertiesFileName())
  setProperty("System.window.gtwvt","N")

  init(SERVER_LOGIN)
  getUser():isBackgroundTask:=.t.

  // rest all remote server logins upon start
  LoginDispatcher():new():ResetLogin(SERVER_LOGIN)
  LoginDispatcher():new():ResetLogin(REMOTE_SERVICE_LOGIN)

  ferase( SERVER_SHUTDOWN_REQUEST )
  ferase( SERVER_SHUTDOWN )

  // // SET EXCLUSIVE OFF // Netzwerk !
  // altd()
  // init_hb()
  // init(SERVER_LOGIN) // Systemparameter setzten, Auto Login als Server

  // titel("NETIO Server")

  qout("Started remote Server in: " + hb_cwd())
  qout()

  readProperties(getPropertiesFileName())
  // make sure we don't open a window as we run as service
  // FIXME: testme setProperty
  setProperty("System.window.gtwvt","N")

  pSockSrv:=NETIO_MTSERVER( NETPORT , NETSERVER , hb_cwd() , .t. ,decrypt(NETPASSWD_ENCRYPTED),NIL;
    ,NIL )
  if empty( pSockSrv )
    qout( "Cannot start NETIO server !!!" )
    wait "Press ESC key to exit..."
    quit
  endif

  trouble("remote",{"Server started: "+HB_CWD()})
  // qout()
  // qout( "Server Activated: "+HB_CWD() )
  hb_idleSleep( 0.1 )

  // neu Neustart gleich Auftragsbestand berechnen
  qout( "Berechne Auftragsbestand" )
  AufBestand()
  qout( "Auftragsbestand berechnet." )
  qout( "waiting for requests..." )

  // falls als Servcice (ohne UI), dann bis Servcice beendet wird, ohne Benutzer Interaktion
  if lUI
    DO WHILE inkey(5)<>27 .and. .not. file( SERVER_SHUTDOWN )
      hb_idleSleep( 0.1 )
    ENDDO
  else
    DO WHILE win_serviceGetStatus() == WIN_SERVICE_RUNNING .and. inkey()<>27 .and.;
      .not. file( SERVER_SHUTDOWN )
      hb_idleSleep( 5 )
    ENDDO
  endif

  trouble("remote",{"... server stopped."})
  netio_serverstop( pSockSrv, .t. )

  ferase( SERVER_SHUTDOWN_REQUEST )
  ferase( SERVER_SHUTDOWN )

return
/** eop */


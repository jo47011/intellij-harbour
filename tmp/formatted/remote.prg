/* modul: remote.prg
*
* enth�lt alle Proceduren etc. die remote aufgerufen werden, s. remServer.prg
*/

#include "Miki.ch"
#include "mynetio.ch"

#include "dbinfo.ch"

// ************************************************************************************************

// NOT _thread static, since we need this for thread "synchronisation"
static nofThreads:=0 ,stopNow:=.f.

Function server_called(callerID , cFunction , aParameters )
LOCAL start_remote, end_remote
MEMVAR User
  PUBLIC User:=NIL

  default callerID:="XX" // default to server login

  // need to call init stuff manually, no gwvt related stuff
  rddSetDefault(MY_RDDI)
  rddInfo( RDDI_MEMOEXT , MY_MEMO_EXTENSION , MY_RDDI )

  // set codepage / character set
  set( _SET_CODEPAGE, "DEWIN" )
  hb_setTermCP( "DEWIN" )

  // set current application path as default
  set default to (hb_cwd())

  SET EXCLUSIVE OFF // Netzwerk !

  qout("Starting " + cFunction + ".....")

  init(REMOTE_SERVICE_LOGIN) // Systemparameter setzten, Auto Login als Server
  getUser():isBackgroundTask:=.t.

  // re-new date, since server is running 24/7
  getUser():date:=hb_date()

  // check whether we run with ID 01 -> needed for Materialbedarf
  // if getUser():id <> "01"
  // TroubleEmail("Server running with ID: " + getUser():id)
  // endif

  // read system properties
  readProperties(getPropertiesFileName())

  qout("Now Starting " + cFunction + "....")
  start_remote:=seconds()
  trouble("remote",{toString(callerID)+"-> remote " + cFunction + " gestarted in " + hb_cwd()})
  HB_ExecFromArray( cFunction , aParameters )
  trouble("remote",{toString(callerID)+"-> remote " + cFunction + " beendet."})
  end_remote:=seconds()

  // if cFunction=="myAufbestand" .and. end_remote - start_remote <= 1
  // trouble("aufbestand", "AufBestand: Berechung zu schnell -> bitte pr�fen!")
  // endif

  qout("Finished: " + cFunction)

  logout(.f.)
  //Down() // ende aus


return .t.
/** eof */

  // ************************************************************************************************

procedure check4shutdownrequest()
  trouble("remote",{"check4shutdownrequest -> nofThreads: " + str(nofThreads)})
  if file( SERVER_SHUTDOWN_REQUEST )
    if nofThreads == 0
      trouble("remote",{"shutdown"})
      qout("now shuting down")
      logout()
      close data
      renameFile(SERVER_SHUTDOWN_REQUEST, SERVER_SHUTDOWN)
      QUIT
    else
      trouble("remote",{"shutdown request failed.  nofThreads:" + str(nofThreads) })
    endif
  endif
return
  // ************************************************************************************************


/*
* berechnet den Auftragsbestand anhand noch zu liefernder Auftr�ge
*
* Hinweis: Bisher k�nnen nur alle (!) Artikel berechnet werden, einzelne geht schief!
*
* evtl. �ber thread_mutex l�sen, s.Zeige.prg
*/
PROCEDURE myAufbestand( mail_Protokoll , quiet, lokal )
LOCAL GetList:={}
LOCAL noch_zu_liefern:=0
LOCAL treffer:=0 , protName , pos
LOCAL alleArtikel:=hb_Hash()
LOCAL offeneBestellungen:=hb_Hash()
LOCAL alleReservierungen:={}, mReserv
LOCAL wasLocked, mArtikel
LOCAL objErr, bLastHandler, count:=0
LOCAL MAX_WAIT:=3*60 // max. 3 Minuten

  default lokal:=.f.

  if stopNow
    return
  endif

  if .not. lokal

    nofThreads++

    // wait for other threads to terminate, if any
    do while nofThreads > 1 .and. count < MAX_WAIT
      stopNow:=.t.
      // trouble("threads",{toString(nofThreads)+" waiting..."})
      hb_idleSleep( 1 )
      count++
    enddo
    if count >= MAX_WAIT
      nofThreads:=1 // only this thread is still running
    endif
    stopNow:=.f.
  endif

  // trouble("threads",{toString(nofThreads)+" gestarted."})

  default mail_Protokoll:=.f.
  default quiet:=.f.

  Umgebung( WRITE_ALL )

  if ! quiet
    Message("Auftragbestand wird neu berrechnet.    Bitte warten...")
  endif

  if ! open("AufPost","AufAus","AvPost", "Artikel","BesPost","BesAus","Einheit" )
    troubleEmail("AufBestand: Dateien konnten nicht ge�ffnet werden.")
    //Error(TRY_AGAIN)
    Umgebung( LOAD ) // anstatt close data
    nofThreads--
    if ! quiet
      Message()
    endif
    RETURN
  endif

  /* Relationen setzen */
  select BesPost
  set rela to BESPOST->BestNr into BesAus

  select AufPost
  set relation to AUFPOST->aufnr into Aufaus,;
    to AUFPOST->ArtNr into avpost,;
    to AUFPOST->ArtNr into Artikel
  if ! quiet
    Message('Bitte warten ....    ')
  endif

  /*** erste Stufe ***/
  SELECT AufPost
  // seit 13.6.17 doch wieder f�r Verpackung
  // seit 17.12.22 mit offenen Auftr�gen als reserviert
  index on kwindex(AUFPOST->Kw) + AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->Erledigt=="O") .and. ;
    len(alltrim(AUFPOST->ArtNr)) <> FRACHT_LAENGE .and. ;
    AUFAUS->Aufart $ "RVKD" .and. AUFAUS->Erledigt<>"J" .and. AUFAUS->InvKZ<>"J"

  go top
  do while ! AUFPOST->(eof())
    if ! quiet
      Message("Auftrag @"+AUFPOST->AufNr+"@ wird berechnet.       Bitte warten...")
    endif

    // check whether other "new" thread wants us to quit
    if stopNow
      Umgebung( LOAD )
      nofThreads--
      return
    endif

    if AUFAUS->Erledigt=="O"
      noch_zu_liefern:=AUFPOST->Menge
    else
      noch_zu_liefern:=(AUFPOST->Menge - AUFPOST->GeliefGes)
    endif

    // if trim(AUFPOST->Artnr)=="50370355"
    // altd()
    // endif

    if noch_zu_liefern > 0

      if ARTIKEL->(eof()) // Artikel wurde gel�scht?
        // altd()
        troubleEmail("Artikel gel�scht aber in Auftrag: "+AUFPOST->AufNr+" Art:"+AUFPOST->ArtNr)
      else
        AufBestRek( AUFBESTAND_BERECHNEN , @alleArtikel , @alleReservierungen ,@offeneBestellungen;
          , AUFPOST->ArtNr , noch_zu_liefern, .t., AUFPOST->ABPostNr) // mit allen ext. Bestellungen
      endif
      select AufPost
    endif

    skip
  enddo

  /* Artikel r�ckschreiben */
  if mail_Protokoll
    Protokoll(INIT_P,"Auftrags-Bestand","Art.Nr.  Bez                           AufBest. alt      "+;
      "  neu       Diff")
  endif

  if ! quiet
    Message("Artikel-Datei wird aktualisiert.     Bitte warten...")
  endif

  // Artikel Disponiert Datei wird immer komplett �berschrieben -> wird als Semaphore benutzt
  // if ! open({"ArtReserv",.t.}) // ACHTUNG excklusiv, sollte woanders nur kurz ge�ffnet sein!
  if ! openArtReserv() // exclusive
    if lokal
      troubleEmail("Miki Service: Auftragsbestand konnte nicht neu berechnet werden.")
    else
      troubleEmail("Miki Remote Service: Auftragsbestand konnte nicht neu berechnet werden.")
    endif
    //Error(ACHTUNG+"Auftragsbestand konnte nicht neu berechnet werden." + SCHWERER_FEHLER)
    Umgebung( LOAD ) // anstatt close data
    nofThreads--
    return
  endif

  select Artikel
  go top
  do while ! eof()

    // if trim(ARTIKEL->Artnr)=="20500005"
    // altd()
    // endif

    // check whether other "new" thread wants us to quit
    if stopNow
      close ArtReserv // so it will be open on Umgebung(LOAD) in the same state as before (maybe not locked!)
      Umgebung( LOAD )
      nofThreads--
      return
    endif

    pos:=hGetPos( alleArtikel , ARTIKEL->ArtNr )
    if pos == 0
      if ARTIKEL->disponiert <> 0
        wasLocked:=isLocked()
        rec_lock( 0 , ARTIKEL->(recno()) )
        if mail_Protokoll
          Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->disponiert,11,2)+;
            " -> 0")
        endif
        replace ARTIKEL->disponiert with 0
        treffer++
        dbcommit()
        if ! wasLocked
          dbRunlock( ARTIKEL->(recno()) )
        endif
      endif
    else
      mArtikel:=hGetValueAt( alleArtikel, pos )
      // nur r�ckschreiben falls �nderung vor der 2. Nachkommastelle
      if abs( ARTIKEL->disponiert - mArtikel:disponiert )>=0.01
        wasLocked:=isLocked()
        rec_lock( 0 , ARTIKEL->(recno()) )
        if mail_Protokoll
          Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->disponiert,11,2)+ " -> " +;
            str( mArtikel:disponiert ,12 ,2 ))
        endif
        replace ARTIKEL->disponiert with mArtikel:disponiert
        treffer++
        dbcommit()
        if ! wasLocked
          dbRunlock( ARTIKEL->(recno()) )
        endif
      endif

    endif
    skip
  enddo

  // r�ckschreiben der einzelnen Reservierungen nach Artreserv.dbf
  select Artreserv
  //delete all // was zap but excl. I/O required -> caused some problems on opening
  zap

  for each mReserv in alleReservierungen
    // check whether other "new" thread wants us to quit
    // if stopNow
    // close ArtReserv // so it will be open on Umgebung(LOAD) in the same state as before (maybe not locked!)
    // Umgebung( LOAD )
    // nofThreads--
    // return
    // endif

    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
    BEGIN SEQUENCE // krit. Bereich
      add_rec(0)
      replace ARTRESERV->ArtNr with mReserv:ArtNr
      replace ARTRESERV->Art with mReserv:Art
      replace ARTRESERV->AbPostNr with mReserv:AbPostNr
      replace ARTRESERV->Menge with round(mReserv:Menge,2)
      replace ARTRESERV->Tiefe with mReserv:Tiefe
      replace ARTRESERV->LageBest with round(mReserv:LageBest,2)
      replace ARTRESERV->Disponiert with round(mReserv:Disponiert,2)
      replace ARTRESERV->FehlMenge with round(mReserv:fehlMenge,2)
      replace ARTRESERV->BestText with mReserv:bestText
      replace ARTRESERV->AlternZu with mReserv:AlternZu
      replace ARTRESERV->topFaktor with mReserv:topFaktor
    RECOVER USING objErr
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      email(MY_EMAIL,"ERROR: Bestellkarte-Absturz: ",getErrorText(objErr))
    END SEQUENCE
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  next
  dbcommitall()
  close ArtReserv // so it will be open on Umgebung(LOAD) in the same state as before (maybe not locked!)

  if mail_Protokoll
    // check whether other "new" thread wants us to quit
    if stopNow
      Umgebung( LOAD )
      nofThreads--
      return
    endif

    Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
    if treffer==0
      // if AT_HOME
      // email(MY_EMAIL,"Auf.Bestand Konsistenzcheck okay")
      // endif
    else
      protName:=Protokoll(P_FILE_NAME)
      email(MY_EMAIL,"Fehler: Auf.Bestand berechnen:"+str(treffer,5),"Bitte pr�fen",protName)
    endif
  endif

  Umgebung( LOAD ) // anstatt close data

  if ! quiet
    Message()
  endif

  nofThreads--

  check4shutdownrequest()

  // test_timers( aTimers ) // -> debug output
  // wait

RETURN
/* EOP AufBestand */

function ping()
  check4shutdownrequest()
return "pong"

function remote_ping(callerID)
  // altd() ACHTUNG: geht wenn lokal gestarted, aber danach h�ngt der Server!
  server_called(callerID , "ping" , {} )
return .t.

function remote_aufbestand(callerID, aParams)
  server_called(callerID , "myAufbestand" , aParams )
return .t.

PROCEDURE AufBestand( mail_Protokoll , quiet , background)
LOCAL objErr,okay:=.f.
  default background:=.t.
  BEGIN SEQUENCE
    Message("Server Verf�gbarkeit wird gepr�ft.   Bitte warten...")
    if ! empty(NETSERVER) .and.;
      netio_connect( NETSERVER , NETPORT, NETTIMEOUT , decrypt(NETPASSWD_ENCRYPTED) )
      //.and. (.not. (TEST_PROG .or. DEVEL_PROG)) .and. ! getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN
      if net:exists:remote_aufbestand
        Message("Auftragsbestand wird auf Server neu berechnet.   Bitte warten...")
        if background
          netio_procexec( "remote_aufbestand",getUser():id , { mail_Protokoll , quiet } )
          Message("Auftragsbestand wird auf Server neu berechnet.")
          netio_disconnect( NETSERVER, NETPORT )
        else
          okay:=net:remote_aufbestand( getUser():id , { mail_Protokoll , quiet } )
          netio_disconnect( NETSERVER, NETPORT )
          if ! quiet
            Message("Auftragsbestand wurde auf Server neu berechnet.   @Taste@","@")
          endif
        endif
        okay:=.t.
      endif
    endif
    if ! okay // lokal aufrufen
      if ! empty(NETSERVER) .and. (.not. (TEST_PROG .or. DEVEL_PROG)) ;
        ..and. ! getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN
        TroubleEmail("Remote Service AufBestand nicht verf�gbar!")
      endif
      Message("Auftragsbestand wird lokal neu berechnet.   Bitte warten...")
      myAufbestand( mail_Protokoll , quiet , .t. )
      Message()
    endif
  RECOVER USING objErr
    email(MY_EMAIL,"ERROR: Remote aufbestand not working!")
  END SEQUENCE

return
/** eof */



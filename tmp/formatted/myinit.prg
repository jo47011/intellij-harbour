/**
* contains all common functions for startup, login and update
*/

#include "MyStd.ch"
#include "mynetio.ch"

#include "setcurs.ch"
#include "dbstruct.ch"
#include "hbgtinfo.ch"
#include "dbinfo.ch"

REQUEST MY_REQ_RDDI
REQUEST HB_CODEPAGE_DE850
REQUEST HB_CODEPAGE_DEWIN
REQUEST HB_CODEPAGE_DEISO
// REQUEST HB_CODEPAGE_UTF8
REQUEST HB_LANG_DE


PROCEDURE init_hb()

  // select German Language
  hb_langSelect( "DE" )

  // set code page -> windows germany
  set( _SET_CODEPAGE, "DEWIN" )
  hb_setTermCP( "DEWIN" )

  // set( _SET_CODEPAGE, "cp1252" )
  // hb_SetTermCP( "cp1252" )

  // codepage: we need this to enable box character display with the current codepage
  hb_gtInfo( HB_GTI_COMPATBUFFER, .F. )

  // // disable closing windows
  // // see ./tests/wvtext.prg, Alternativ: Abfrage
  hb_gtInfo( HB_GTI_CLOSABLE, .f. )
  hb_gtInfo( HB_GTI_SELECTCOPY,.T.)
  hb_gtInfo( HB_GTI_RESIZABLE, .T. )

  // set font
  hb_gtInfo( HB_GTI_FONTNAME, HB_DEFAULT_FONT)
  hb_gtInfo( HB_GTI_FONTWIDTH, HB_DEFAULT_FONT_WIDTH )
  hb_gtInfo( HB_GTI_FONTQUALITY, HB_GTI_FONTQ_HIGH )

  // Enable alt-enter to switch to full screen
  hb_gtInfo( HB_GTI_ALTENTER , .t.)

  // set some default compatibility settings
  // FIXME: what is correct here?
  // set filecase upper
  // set dircase upper
  // set dirseparator "/"
  set dirseparator BACKSLASH
  // SET DBFLOCKSCHEME TO 1 // we need this, but why???

  // CDX RDD is a little quicker, but it crashes on complex index keys
  // see miki#AufPost#ind2
  // test add_rec or reindex

  rddSetDefault(MY_RDDI)
  rddInfo( RDDI_MEMOEXT , MY_MEMO_EXTENSION , MY_RDDI )

  // we need to set the errorhandler again, as it seems some of the
  // above commands change the default error handler
  // Errorsys() // remove 20160617
  ErrorBlock( {|e| DefError(e)} ) // set the default handler to my logging handler

  // create temp paths
  createTempPaths()

  // read system properties
  readProperties(getPropertiesFileName())

  // set icon & title for fram
  hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME)

  // FIXME: should be: RESOURCES+BACKSLASH+getProperty("System.icon.png","")
  // needs to be tested at customer site
  hb_gtInfo( HB_GTI_ICONFILE, getProperty("System.icon","<none>") )

  // enable mouse events
  hb_gtInfo(HB_GTI_MOUSESTATUS, 1 )

  // set mouse double click intervall
  mdblclk(val(getProperty("System.mouse.doubleclick","30")))

  // set current application path as default
  set default to (hb_cwd())

RETURN
/** eop */

/** pr�ft ob updates zu installieren sind und installiert diese */
Procedure checkCurrentVersion()
LOCAL time:=seconds()

  // check for update if not running as service
  if SYSTEM->Version<getCurrentVersion() .and. ! "service" $ getFileName(ExeName())

    mkmydir(TEMP)

    installUpdate(SYSTEM->Version)

    // l�sche alle aktuellen Logins, es kann keiner eingeloggt sein
    // und wenn, dann meistens nur weil die Daten von Prod nach Test kopiert wurden
    LoginDispatcher():new():ResetLogin()

    Message("Update beendet in "+alltrim(str(seconds()-time))+;
      " Sekunden.   Bitte @Taste@ dr�cken.","@")
  endif
return

/** z�hlt die akt. Version hoch (nur Anzeige) */
function bumpVersionTo(currentVersion,newVersion)
  @ 8,20 say "Version:"+str(newVersion,5)
return currentVersion < newVersion .and. newVersion <= getCurrentVersion()


/** Schreibt die aktuell installierte Version nach System.dbf
 */
Function commitCurrentVersion()
  if ! open({"system",.t.})
    Error(ACHTUNG+" Version konnte nicht commited werden.",.t.)
  else
    replace SYSTEM->Version with getCurrentVersion()
    trouble("Update",{"Update auf Version : "+alltrim(str(SYSTEM->Version,5))+" beendet." } )
    close data
    ferase(NO_LOGIN_FILE)

    return .t.
  endif
return .f.
/** eof */

/* myBreak ***
*
* Funktion ist n�tig um Break zu senden
*/
FUNCTION myBreak(objErr)
  if 1 > 0 // we need this to avoid "Warning W0028  Unreachable code"
    BREAK objErr
  endif
RETURN NIL
/* EOF Break */


PROCEDURE Init(kurzel,crontab)
LOCAL text

  default crontab:=.f.

  /* login erlaubt ? */
  if NO_LOGIN .and. kurzel <> SERVER_LOGIN .and. kurzel <> REMOTE_SERVICE_LOGIN
    text:='"SYSTEM-Arbeiten"'+MY_CR+MY_LF+;
      +MY_CR+MY_LF+;
      '"KEIN LOGIN m�glich."'+MY_CR+MY_LF+;
      '"Bitte sp�ter erneut versuchen"'
    extMsgBox(text)
    quit
  endif

  // set user default values
  initUser(DUMMY_USER,"1") // start with dummy user without any permission

  if ! file( HAUPT + BACKSLASH + "System.dbf" )
    text:='"Fehler"'+MY_CR+MY_LF+;
      +MY_CR+MY_LF+;
      '"DAT Verzeichnis nicht verf�gbar."'
    qout(text)
    extMsgBox(text)
    quit
  endif

  /* Farbe zuweisen */
  SET EXCLUSIVE OFF // Netzwerk !
  if ! open("System")
    text:='"Fehler"'+MY_CR+MY_LF+;
      +MY_CR+MY_LF+;
      '"System.dbf nicht verf�gbar."'
    extMsgBox(text)
    quit
  endif

  // farbe_zuweisen()
  init_set() // setze Standard-Werte

  // pr�fe auf Updates
  checkCurrentVersion()

  if getUser():id<>DUMMY_USER
    logout() // SERVER falls Update aufgespielt
  endif

  if ! mylogin(kurzel)
    // kein down(), da keine temp. Dateien etc. angelegt
    // und vor allem kein User eingeloggt
    close data
    QUIT
  endif

  /** automat. CronJobs aufrufen */
  if crontab
    if NO_LOGIN
      quit
    endif

    // erzeuge NO_LOGIN w�hrend CRONTAB
    set alte to NO_LOGIN_FILE
    set alte on
    close alte

    trouble("crontab",{"Crontab aufgerufen   ================================================="})
    CronJobs()

    // l�sche NO_LOGIN
    ferase(NO_LOGIN_FILE)
  endif

  close data

RETURN
/* EOP Init */


/* Procedure init_Sets
*
* initialisieren der Standard-Wert
*/

PROCEDURE init_set
LOCAL tempVal

  /* spez. Routinene w�hrend Entwicklungsphase (DEVEL_PROG.out existiert) */
  set key K_ALT_C to ShutDown() // eigen Shutdown-Routine
  if ! DEVEL_PROG .and. ! TEST_PROG
    SETCANCEL(.f.)
  endif

  SetKey( K_CTRL_V , {|| pasteClipBoard() } )

  // ScreenShot schicken auf ALT-P
  set key KEY_SCREENSHOT to sendScreenShot()

  // Search Screen auf CTRL-?
  setkey(KEY_SEARCH, {|| searchScreen()})

  // set keys to launch external programs for displaying artikels, customers, etc.
  // we can not use: HB_SetKeyArray() since the array from the ini file is not numeric
  for each tempVal in LAUNCH_TASTEN
    SetKey( val( tempVal ) , {|p, l, v| launchProgram(p, l, v) } )
  next

  /* Hervorhebung in Texten */
  // set key K_F3 to color_on()
  // set key K_F4 to color("OFF")

  // /** pconosle aufrufen */
  // set key KEY_PCONSOLE to Pconsole_Top()

  SET DELE ON // zeigt zur l�schung markierte s�tze NICHT
  SET confirm ON // return zur best�tigung, noch n�tig f�r Editor !

  setcursor(DEUTE_MARKE) // Cursor festlegen
  SET SCOREBOARD OFF // keine meldungszeile also zeile 22 benutzbar
  SET DATE GERMAN // Datum = Deutsch
  SET EPOCH to 1960 // Jahrhundertgrenze !
  Set( _SET_EXACT, .t.) // sucht nach absolut gleichem INDEX !

  #ifdef INFO_TASTE
  set key INFO_TASTE to Info // Informations-Proc
  #endif
  #ifdef HILFE_TASTE1
  set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
  #endif
  #ifdef HILFE_TASTE2
  set key HILFE_TASTE2 to Hilfe
  #endif
  set key asc(chr(255)) to Hilfe // n�tig f�r automat. Hilfe
  // set key K_INS to ChangeCursor()

  // Sonderzeichen Behandlung
  set key K_ALT_S to ZeigeSonderzeichen() // manuelle Eingabe mit Auswahlbox
  set key K_ALT_T to selectFont()

  Set( _SET_PATH, HAUPT ) // Suchpfad auf Hauptverzeichnis

  if DEVEL_PROG .or. TEST_PROG
    set intensity on
    setProperty("Color.normal",COLNOR_TEST)
  endif
  SETColor(COLNOR) // normale Farben einstellen
  // cls
RETURN



/* 
* sauberes herunterfahren des Programms
*
* - checkt ob Umgebung leer
* - schliesen aller Dateien
*/
PROCEDURE Down(Umg_check, waitForTasks)
LOCAL okay:=.f.
LOCAL currentLogins, bLastHandler, objErr

  default Umg_check:=.t.
  default waitForTasks:=.t.

  if Umg_check
    Umgebung(CHECK)
  endif
  close data

  logout()

  close data
  Message("Hintergrund-Jobs werden beendet.    Bitte warten...")
  if waitForTasks
    hb_threadWaitForAll()
  else
    hb_threadTerminateAll()
  endif

  // pr�fe ob Info-Email gew�nscht wenn letzter Benutzer sich ausloggt
  bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
  BEGIN SEQUENCE
    if file( LAST_LOGOUT_EMAIL )
      currentLogins:=LoginDispatcher():new():getLogins()
      if len(currentLogins) == 0
        email(MY_EMAIL,"Info: alle Logins beendet.")
        ferase( LAST_LOGOUT_EMAIL )
      endif
    endif
  RECOVER USING objErr
    email(MY_EMAIL,"ERROR: Down/LoginDispatcher.",getErrorText(objErr))
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  QUIT
RETURN
/* EOP Down */

/** Loggt den aktuellen Benutzer aus, speichert Fenstergr��e etc. */
Function logout(saveWindowPos)
Local tempPos,tempSizeX,tempSizeY,tempFullscreen,tempUser

  default saveWindowPos:=.f.

  // inform other child threads to shut down
  // FIXME: write one instance handling all threads!!!
  ZeigeClose()
  // EmailClose()

  /* l�schen der Temp. Dateien */
  TempDatei("")

  /* ausloggen des akt. Benutzer */
  if ! open( "Login","Fenster" )
    Error(getUser():getLongID()+" am:"+dtoc(date())+" um:"+time()+" konnte nicht reinitialisert "+;
      "werden !"+SCHWERER_FEHLER)
  else
    select login
    seek getUser():id
    if eof() .or. ! rec_Lock(5)
      Error(getUser():getLongID()+" am:"+dtoc(date())+" um:"+time()+" konnte nicht reinitialisert "+;
        "werden !"+SCHWERER_FEHLER)
    else
      LoginDispatcher():removeLogin(getUser():id) // remove current == logout

      if ! getUser():id == REMOTE_SERVICE_LOGIN

        if ! getUser():infoOnly
          // font speichern
          replace LOGIN->FontName with hb_gtInfo(HB_GTI_FONTNAME)
          replace LOGIN->FontSize with hb_gtInfo(HB_GTI_FONTWIDTH)
          replace LOGIN->FontBold with if(Hb_GtInfo(HB_GTI_FONTWEIGHT)==HB_GTI_FONTW_BOLD,"J","N")
        endif

        getUser():readSettings() // why do we need this here?

        // Fenster Gr��e nur beim 1. Fenster speichern!!!
        if getUser():counter=="1" .or. saveWindowPos
          select Fenster
          tempUser:=getUser():getWindowStorageID()
          FENSTER->(dbseek(left(MAIN_WINDOW_NAME+space(10),10)+left(tempUser+space(10),10)))
          if FENSTER->(eof()) // von User zum 1. Mal geöffnet
            if ! add_rec(5)
              Error(ACHTUNG+"Fenster-Gr��e kann nicht gespeichert werden.",.t.)
            else
              replace FENSTER->LISTE_KURZ with MAIN_WINDOW_NAME
              replace FENSTER->Kurzel with tempUser
            endif
          else
            rec_lock(5)
          endif
          tempsizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
          tempsizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
          temppos:=hb_gtInfo( HB_GTI_SETPOS_XY )
          tempFullscreen:=hb_gtInfo( HB_GTI_ISFULLSCREEN)
          replace FENSTER->PosX with max(temppos[1],0)
          replace FENSTER->PosY with max(temppos[2],0)
          replace FENSTER->SizeX with tempsizeX
          replace FENSTER->SizeY with tempsizeY
          replace FENSTER->Maximized with if(tempFullscreen,"J","N")
        endif
      endif
    endif

  endif
return .t.

/* 
* Einlogg-Routine
*
* R�ckgabe: String der gesperrten Fkten.
*/
FUNCTION myLogin(M_Kurzel)
LOCAL M_Pass:="." , login, i
LOCAL GetList:={},secureCount:=0,showWindowGTWVT
LOCAL shiftWindow:=0,tempPosx,tempPosy,tempUser,clientName:=CLIENT_NAME+":"+USER_NAME
LOCAL bLastHandler

  showWindowGTWVT:=(getProperty("System.window.gtwvt","J")=="J")

  if showWindowGTWVT
    Umgebung(WRITE)
  endif

  if ! open("Login","Fenster")
    Error(TRY_AGAIN)
    if showWindowGTWVT
      Umgebung(LOAD)
    endif
    RETURN(.f.)
  endif
  select Login

  // setze Fenstergr��e & Position /jetzt nach ClientName
  if showWindowGTWVT

    // setze Windows Titel mit K�rzel
    hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+if(AT_HOME,"     (Home)",""))

    // suche & setzte Fenster-Gr��e & Postion (je Rechner)

    // z�hle Anzahl akt. Programme auf diesem Client
    for i:=1 to len(LoginDispatcher():new():getLoginsByClient(ClientName))
      shiftWindow++
    next

    select Fenster
    tempUser:=getUser():getWindowStorageID()
    FENSTER->(dbseek(left(MAIN_WINDOW_NAME+space(10),10)+left(tempUser+space(10),10)))
    if ! FENSTER->(eof())
      // setze aktuelle Fenster-Groesse & Position
      if FENSTER->Maximized=="J"
        hb_gtInfo(HB_GTI_ISFULLSCREEN,.t.)
      else
        if FENSTER->SizeX>0
          hb_gtInfo(HB_GTI_SCREENSIZE , { FENSTER->SizeX, FENSTER->SizeY } )
        endif
        tempPosx:=FENSTER->PosX+shiftWindow*10
        tempPosy:=FENSTER->PosY+shiftWindow*10
        // reset when outside desktop
        if tempPosX > hb_gtInfo(HB_GTI_DESKTOPWIDTH) - 40
          tempPosX:=1
        endif
        if tempPosY > hb_gtInfo(HB_GTI_DESKTOPHEIGHT) - 40
          tempPosY:=1
        endif
        qout(" ") // needed as workaround for bug in setPos
        hb_gtInfo(HB_GTI_SETPOS_XY , {tempPosx,tempPosy} )
      endif
    endif

    select Login

  endif

  // User manuell ausw�hlen, falls keiner �bergegeben
  if valtype(m_kurzel)=="U" .or. empty(m_kurzel)
    cls
    titel(getProperty("System.programm.title","System.programm.title nicht gesetzt"))

    m_Kurzel:=space(len(LOGIN->Kurzel))
    do while ( cryptFallThru(M_Pass)<>LOGIN->Passwort .or. M_Pass=="." ;
      .or. lastkey()<>K_RETURN ) .and. (encrypt(trim(M_Pass))<>MASTER_PASS)

      if ! M_Pass=="."
        beep()

        // IF FT_CAPLOCK() // analog harbour function (untested: KSetcaps())
        IF KSetcaps()
          Error(ACHTUNG+" Feststelltaste (CAPS-Lock) ist aktiviert.",.t.)
        endif
      endif

      if secureCount>5
        Error("ACHTUNG: zu viele Versuche:"+m_Kurzel+" |"+;
          "Bitte kontaktieren Sie Herrn Weiland! ",.t.,"root")
        if showWindowGTWVT
          Umgebung(LOAD)
        endif
        RETURN(.f.)
      endif

      M_Pass:=space(len(LOGIN->Passwort))
      #ifdef HILFE_TASTE1
      set key HILFE_TASTE1 to
      #endif
      #ifdef HILFE_TASTE2
      set key HILFE_TASTE2 to
      #endif
      set key K_F12 to
      setcolor(COLWIN)
      Fenster(08,18,16,64)
      @ 10,20 say "Bitte Benutzerkennung und Passwort eingeben"
      @ 11,20 say "==========================================="
      @ 13,20 say "K�rzel  :" get M_Kurzel picture "@K!" valid { |oget| checkKurzel(oGet) };
        when Message("Bitte Mitarbeiter-K�rzel eingeben.            @Leer@=Auskunft")
      @ 15,20 say "Passwort:" get M_Pass picture "@K@!" color "W/W";
        when;
        ( Message("Bitte Passwort eingeben.                    @F8@=Passwort �ndern") .and.;
        enableNewPass()) valid disableNewPass()

      read
      setcolor(COLNOR)
      set key K_F8 to
      #ifdef HILFE_TASTE1
      set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
      #endif
      #ifdef HILFE_TASTE2
      set key HILFE_TASTE2 to Hilfe
      #endif

      /* Abbruch ? */
      if ABBRUCH
        if showWindowGTWVT
          Umgebung(LOAD)
        endif
        RETURN(.f.)
      endif

      // /** Auskunft only */
      // if empty(M_pass)
      // exit
      // endif

      secureCount++

    enddo
  else
    LOGIN->(dbseek(M_Kurzel))
    if LOGIN->(eof())
      Error("ACHTUNG: Benutzer: "+M_Kurzel+" nicht gefunden.",.t.)
      return .f.
    endif
  endif

  /* Einloggen erfolgreich  */
  select Login
  if ! rec_lock(5)
    Error(LOGIN_FAILED)
    if showWindowGTWVT
      Umgebung(LOAD)
    endif
    close data
    return .f.
  endif

  // protokolliere backdoor login
  // if ! TEST_PROG .and. ! DEVEL_PROG .and. encrypt(trim(M_Pass))==MASTER_PASS // .and. M_Kurzel <> KURZEL_DEVEL
  if encrypt(trim(M_Pass))==MASTER_PASS // .and. M_Kurzel <> KURZEL_DEVEL
    TroubleEmail(MY_EMAIL,"Login: Master Pass -> Benutzer: "+M_Kurzel)
  endif

  // suche n�chste freie Nr.
  bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
  BEGIN SEQUENCE
    login:=LoginDispatcher():new():addLogin(M_Kurzel)
    RECOVER
    Error(TOO_MANY_TERMINALS)
    if M_Kurzel == KURZEL_DEVEL
      LoginDispatcher():new():ResetLogin(KURZEL_DEVEL)
    endif

    if showWindowGTWVT
      Umgebung(LOAD)
    endif
    close data
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    return .f.
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  // initialize selected user
  initUser(login:id, login:counter)

  // setze Font je nach Login
  if showWindowGTWVT

    // setze Windows Titel mit K�rzel
    hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - "+getUser():getLongID()+;
      if(AT_HOME,"     (Home)",""))

    // suche & setzte Fenster-Gr��e & Postion (je Benutzer bzw. Rechner)

    // setze Font und Font-Gr��e
    if ! getUser():infoOnly .and. ! getUser():isGroupAccount .and.;
      ! empty(getUser():FontName) // au�er beim 1. Mal & bei dummy user
      hb_gtInfo(HB_GTI_FONTNAME,trim(getUser():FontName))
      if getUser():FontBold
        Hb_GtInfo( HB_GTI_FONTWEIGHT, HB_GTI_FONTW_BOLD )
      else
        Hb_GtInfo( HB_GTI_FONTWEIGHT, HB_GTI_FONTW_NORMAL )
      endif
      hb_gtInfo(HB_GTI_FONTWIDTH,getUser():FontSize)
      // perform this at the end, as this sends a resize event
      hb_gtInfo(HB_GTI_FONTSIZE, getUser():FontSize*2 )

      // need to set position again, as set font (resize event) centers the window again :(
      if tempPosX<>NIL
        qout(" ") // needed as workaround for bug in setPos
        hb_gtInfo(HB_GTI_SETPOS_XY , {tempPosx,tempPosy} )
      endif
    endif
  endif



  // U_FAKT:=(!empty(M_Pass) .and. LOGIN->Fakt=="J")
  // U_BANK:=(!empty(M_Pass) .and. LOGIN->Bank=="J")
  // U_MATEINAUSG:=(!empty(M_Pass) .and. LOGIN->MatEinAusg=="J")
  // U_SYSMENU:=(!empty(M_Pass) .and. LOGIN->SysMenu=="J")


  // erzeuge User Temp Verzeichnis
  mkMyDir(TEMP_USER)

  // pr�fe ob das letzte Mal sauber runtergefahren
  if LOGIN->Warning=="J" .and. ! LOGIN->Kurzel $ SERVER_LOGIN + "/" + REMOTE_SERVICE_LOGIN
    Error(ACHTUNG+"|Bitte beachten Sie in Zukunft:||Vor Auschalten des Rechners bitte das "+;
      "Programm verlassen!",.t.)
    replace LOGIN->Warning with ""
  endif

  dbcommit()
  unlock

  // pr�fe ob Info-Email gew�nscht wenn ein Benutzer sich einloggt
  if file( LOGIN_EMAIL )
    email(MY_EMAIL,"User: "+LOGIN->Kurzel+" logged in.")
    ferase( LOGIN_EMAIL )
  endif

  if showWindowGTWVT
    Umgebung(LOAD)
  endif

RETURN(.t.)
/* EOF Login */


/** Pr�ft die Eingabe des User-Kurzels,
 *  nimmt Dummy User bei Leereingabe */
static Function checkKurzel(oGet)
LOCAL result:=.f.
LOCAL dummyUser:="AU"

  if empty(oGet:buffer) // nehme dummy user
    oget:varput(dummyUser)
    keyboard chr(K_RETURN)+chr(K_RETURN)
  endif

  // suche eingegebenes K�rzel
  LOGIN->(dbseek(oGet:buffer))
  result:=! LOGIN->(eof())

return result
/** EOF */



/** Pr�ft ob Passwort leer und zwingt zur Eingabe eines neuen/sicheren Passworts#
 *
 * gibt eingegebenes Passwort zur�ck (unsch�n aber na ja)
 */
static Function enterNewPass()
LOCAL orgPass,M_Pass1, M_Pass2
LOCAL GetList:={}
LOCAL s002:=savescreen()

  if LOGIN->Gruppe=="J"
    beep()
    return ""
  endif


  Fenster(16,18,19,60)
  M_Pass1:="." ; M_Pass2:="!"
  do while ! ( M_Pass1==M_Pass2 .or. ABBRUCH )
    orgPass:=M_Pass1:=M_Pass2:=space(len(LOGIN->Passwort))
    if ! empty(trim(LOGIN->Passwort))
      @ 15,20 say "Passwort:" get orgPass picture "@!" color "W/W";
        valid cryptFallThru(OrgPass)==LOGIN->Passwort when Message("Bitte @altes@ Passwort "+;
        "eingeben.          @ESC@=Abbruch")
    endif
    @ 17,20 say "Neu     :" get M_Pass1 picture "@!" color "W/W" valid len(trim(M_Pass1))>=3;
      .and. securePass(M_Pass1);
      when Message("Bitte neues Passwort eingeben (mind. 3 Zeichen).          @ESC@=Abbruch")
    @ 18,20 say "Nochmal :" get M_Pass2 picture "@!" color "W/W";
      when Message("Bitte Passwort best�tigen.          @ESC@=Abbruch")
    read

    if ! ABBRUCH .and. M_Pass1<>M_Pass2
      Error(ACHTUNG+"|Passw�rter stimmen nicht �berein.  Bitte erneut eingeben!",.t.)
    endif
  enddo
  restscreen(,,,,s002)
  if ABBRUCH
    return ""
  endif

  Umgebung(WRITE)
  select Login
  if ! rec_lock(5)
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN ""
  endif
  Replace Login->Passwort with cryptFallThru(M_Pass1)
  dbcommit()
  unlock
  Umgebung(LOAD)

  keyboard M_Pass1+chr(K_RETURN)

return M_Pass1
/** eof */

/* Function securePass ***********************************************
*
* Pr�ft ob ein Passwort "sicher" ist
*
*/
static FUNCTION securePass(pass)
LOCAL x,i

  pass:=trim(pass)

  // pr�fe ob alle Zeichen gleich
  x:=substr(pass,1,1)
  i:=2
  do while i<=len(pass) .and. x==substr(pass,i,1)
    i++
  enddo
  if i>=len(pass)
    Error(ACHTUNG+" Passwort nicht sicher genug.",.t.)
    return .f.
  endif

return .t.
/** eof */

/* Function CryptFallThru ***********************************************
*
*  Verschluesselung der Passw�rter
*/
  #define ASCI_START 33
  #define ASCI_ENDE 125
static FUNCTION cryptFallThru(Text)
LOCAL Start:="" , i , Quer:=0,asciWert
  if empty(Text)
    RETURN(Text)
  endif
  /* summiere Quersumme , Ascii */
  for i:=1 to len(Text)
    quer+=asc(substr(Text,i,1))
  next
  for i:=len(Text) to 1 Step -1
    asciWert:=((Quer+asc(substr(Text,i,1))+i**3)%(ASCI_ENDE-ASCI_START))+ASCI_START
    Start+=chr(asciWert)
  next
RETURN(Start)

static function enableNewPass()
  set key K_F8 to enterNewPass()
  if LOGIN->Gruppe<>"J" .and. empty(LOGIN->Passwort) .and. ! LOGIN->Kurzel$"01/02/03/04/05"
    enterNewPass()
  endif
return .t.
static function disableNewPass()
  set key K_F8 to
return .t.

/** r�umt nach evtl. crontab absturz auf, l�schte shutdown.inf Dateien und schickt Email an JG */
PROCEDURE cleanupCrontab()
LOCAL fehler:=.f., datei, attachments:={}
LOCAL tempFileName1:=TEMP+BACKSLASH+getUser():getLongId()+"excel.txt"
LOCAL tempFileName2:=TEMP+BACKSLASH+getUser():getLongId()+"prog.txt"
LOCAL exeName, base

  trouble("crontab",{"Crontab Cleanup gestartet"})

  // kill hanging excel, if any
  if killByName("Excel.exe",tempFileName1) > 0
    // UPDATE-ME
    fehler:=.t.
    aadd(attachments,tempFileName1)
  endif

  // kill hanging exe
  if killByName(getFileName(ExeName()),tempFileName2) > 1
    // UPDATE-ME
    fehler:=.t.
    aadd(attachments,tempFileName2)
  endif

  if file(SHUTDOWN_S)
    fehler:=.t.
    ferase(SHUTDOWN_S)
  endif

  if file(SHUTDOWN_1)
    fehler:=.t.
    ferase(SHUTDOWN_1)
  endif

  if file(SHUTDOWN_2)
    fehler:=.t.
    ferase(SHUTDOWN_2)
  endif

  if file(SHUTDOWN_3)
    fehler:=.t.
    ferase(SHUTDOWN_3)
  endif

  if file(NO_LOGIN_FILE)
    fehler:=.t.
    ferase(NO_LOGIN_FILE)
  endif

  // UPDATE-ME
  if fehler
    datei:=dbinfo("Crontab")
    aadd(attachments,datei[D_PFAD]+BACKSLASH+datei[D_NAME]+".dbf")
    // UPDATE-ME
    email(MY_EMAIL,"Shutdown Cleaned up.","Bitte pr�fen",attachments,.f.)
    trouble("crontab",{"Crontab Cleanup f�ndig -> s. Email!"})
    ferase(tempFileName1)
    ferase(tempFileName2)
  endif

  // exe updaten?
  base:=removeExeCounter( getFileBaseName( exeName() ) )
  exeName:=base + "?.exe"
  if len(directory( exeName )) > 1
    if file(".\bin\shiftExe.bat")
      myRun(".\bin\shiftExe.bat","",.f.)
    endif
  endif

return
/** eof */


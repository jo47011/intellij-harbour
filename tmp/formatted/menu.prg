/*
* Hauptmodul:   Auswahl versch. Unterprogramm
*               alle Untermen�s
*
* Info: set order to -> use DATEI->ordsetfocus()   see mystd.ch
*/

#include "Miki.ch"

#include "hbgtinfo.ch"
#include "hbwin.ch"
#include "hbqtgui.ch"

#include "dbstruct.ch"
#include "Directry.ch"

// #include "common.ch"

// #include "rddsys.ch"
// #include "hbgtinfo.ch"
// #include "hbhrb.ch"
// #include "hbver.ch"

// #include "hbextern.ch"
// #include "hbextcdp.ch"


/* eingabe-Maske f�r Menus */
#define EINGABE_MASKE "@K ##.##.##.##"
#define MASK_LAENGE 3 // Maskenlaenge von @K
#define AUSWAHL_LAENGE Tiefe*2 + Tiefe - 1
#define AUSWAHL_EINGABE @ unt+1,36-MASK_LAENGE-AUSWAHL_LAENGE/2 say "Auswahl:" get Auswahl ;
  picture left(EINGABE_MASKE,AUSWAHL_LAENGE+MASK_LAENGE)

// #define MENU_TRENNER chr(58), needed for mouse associaton with screen content
#define MENU_TRENNER chr(58)
#define MENU_TRENNER_DISABLED "."
#define RAHMEN_SENKRECHT chr(179)

// Eingabe - Flags Men�-Punkte
#define EINGABE_FLAGS INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN + INKEY_RDOWN

/* Procedure Start
*
* Main-Procedure
*/
PROCEDURE Main(starte_bei,gesperrt)
LOCAL akt_Auswahl:=-1 // WICHTIG: Variable muss an 1. Stelle stehen, wird in getMenuPath() verwendet
LOCAL Tiefe:=3 // wieviele Menus darunter(einschl. akt)
LOCAL Auswahl:=space(AUSWAHL_LAENGE)
LOCAL li:=21 , ob:=5 , re:=59 , unt:=20
LOCAL GetList:={}
LOCAL Zeile:=0,tempVal, aktRec , tempArt
  // LOCAL qPixmap, qSplash

MEMVAR specialZeige,User,QTWidget
  PUBLIC specialZeige
  PUBLIC User
PRIVATE QTWidget

  default starte_bei:=""
  default gesperrt:=""

  // usage
  if upper(starte_bei)=="-H" .or. upper(starte_bei)=="-HELP" // -h --help
    qout("usage:  hbmiki [-h][CLD][CLEANUP][CRONTAB][NTX_CREATE][PING][EXCEL]")
    wait
    quit
  endif

  // show splash-screen
  // qPixmap:=QPixmap( "./resources/miki128.png" )
  // qSplash:=QSplashScreen()
  // qSplash:setWindowFlags( hb_bitOr( Qt_WindowStaysOnTopHint, qSplash:windowFlags() ) )
  // qSplash:setPixmap( qPixmap )
  // qSplash:setFont(QFont("Arial",12,QFont_Bold))
  // qSplash:showMessage( "wird geladen..." , 
  // hb_bitOR( Qt_AlignBottom , Qt_AlignHCenter ), QColor(Qt_black) )
  // qSplash:show()
  // QApplication():processEvents()

  // altd()

  // need to call init procedure manually
  init_hb()

  // pr�fe ob neues exe zum install bereit liegt und rufe dieses mit crontab auf
  if runHighestExe(starte_bei,gesperrt)
    return // we bail out -> no init calles so no down needed either
  endif


  if ! empty( starte_bei )

    do case
    case upper(starte_bei) $ DEBUGGER_KEYWORD // ALTD | CLD
      altd() // ok, debug on startup (ist Absicht!)
      starte_bei:=""
      init() // Systemparameter setzten, Login

    case upper(starte_bei)==CLEANUP_KEYWORD // "CLEANUP"
      if NO_LOGIN
        set alte to ".\dat\MAIL\fixme.out" ADDITIVE
        set alte on
        qout("Cleanup doppelt aufgerufen." + dtoc(Date()) + " " + time())
        close alte
      endif
      init(SERVER_LOGIN) // Systemparameter setzten,Auto Login als Server
      cleanupCrontab()
      ferase(NO_LOGIN_FILE)

      Down() // ende aus

    case upper(starte_bei) == CRONTAB_KEYWORD // "CRONTAB"
      if NO_LOGIN
        set alte to ".\dat\MAIL\fixme.out" ADDITIVE
        set alte on
        qout("Crontab doppelt aufgerufen. " + dtoc(Date()) + " " + time())
        close alte
        quit
      endif

      // if runHighestExe() // pr�fe ob neues exe zum install bereit liegt und rufe dieses mit crontab auf
      // return // we bail out -> no init calls so no down needed either
      // endif

      starte_bei:=""
      init(SERVER_LOGIN,.t.) // Systemparameter setzten, Auto Login als Server, starte Crontab
      Down() // ende aus

    case upper(starte_bei)==NTX_CREATE // "NTX_CREATE"
      starte_bei:=""
      init(SERVER_LOGIN) // Systemparameter setzten, Auto Login als Server
      reorg(.f.)
      Down()

    case upper(starte_bei)==PING // ping remote service -> shutdown if remShutRequest.inf exists
      starte_bei:=""
      init(SERVER_LOGIN) // Systemparameter setzten, Auto Login als Server
      pingRemoteService()
      Down()

    case upper(starte_bei)==EXCEL // start pending Excel jobs
      starte_bei:=""
      init(SERVER_LOGIN) // Systemparameter setzten, Auto Login als Server
      CronExcel()
      Down()

    case upper(starte_bei)=="RESET" .and. DEVEL_PROG .and. AT_HOME
      LoginDispatcher():new():ResetLogin()

      // externer Aufruf Stand-alone MIKI-Programm
    case left(starte_bei,len(LAUNCH_DIRECT)) == LAUNCH_DIRECT
      //altd()
      tempVal:=HB_ATokens( starte_bei , LAUNCH_SEP )
      if ! validateLaunchKey(tempval[LAUNCH_USER],tempval[LAUNCH_KEY])
        // WICHTIG: kein down(), da hier kein Benutzer eingeloggt ist
        // kann sich vorher nicht einloggen, da evtl. shutdown.out existiert
        quit
      endif

      init(tempval[LAUNCH_USER])
      if getUser():mayShowData
        initMiki()

        // lade anderes logo
        // hb_gtInfo( HB_GTI_ICONFILE, getProperty("System.icon.info","<none>") )

        switch tempVal[LAUNCH_ALIAS]
        case "ARTIKEL"
          if (getUser():mayEditData .or. getUser():mayEditTool)
            if len(tempVal) >= LAUNCH_DATA2
              keyboard strtran(tempVal[LAUNCH_DATA2],"|",chr(K_RETURN))
            endif
            ArtikelAendern(NIL,tempVal[LAUNCH_DATA])
          elseif getUser():mayEditStock
            ArtikelAendern({"ARTIKEL->LG_Raum","ARTIKEL->LG_Regal","ARTIKEL->LG_Fach","ARTIKEL->LG_Text",;
              "ARTIKEL->LAGEBEST"},tempVal[LAUNCH_DATA])
          endif
          exit

        case "KUNDEN"
          if getUser():DSGVO
            KundenAendern(tempVal[LAUNCH_DATA])
          endif
          exit
        case "ANGEBOT"
          if getUser():DSGVO
            Ang_erfassen(tempVal[LAUNCH_DATA] , if(len(tempVal)>=LAUNCH_DATA2, tempVal[LAUNCH_DATA2], NIL) , if(len(tempVal)>=LAUNCH_DATA3, tempVal[LAUNCH_DATA3], NIL))
          endif
          exit
        case "LIEFERAN"
          if getUser():DSGVO
            LieferantAendern(tempVal[LAUNCH_DATA])
          endif
          exit
        case "BESAUS"
          if getUser():DSGVO
            keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN)
            Best_erfassen()
          endif
          exit
        case "RECHAUS"
          if getUser():DSGVO
            keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN) + chr(K_PGDN)
            Rech_Druckwieder("B","R") // Bildschirm ohne Lieferschein
          endif
          exit
        case "BESTELLUNG"
          if getUser():DSGVO
            keyboard chr(K_RETURN) + tempVal[LAUNCH_DATA] + chr(K_RETURN)
            Best_erfassen(.f. , tempVal[LAUNCH_DATA2]) // keine Preisanfrage -> echte Bestellung mit ArtNr.
          endif
          exit
        case "MASCHINE"
          keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN)
          aend("Maschine",;
            "@�@ndern @L@�schen @S@perren @U@mben. @F6@=St�cklisten @F12@-@N@eu @K@opieren Ende @(x,ESC)@")
          exit
        case "AUFAUS"
          if open("AufAus")
            AUFAUS->(dbseek( tempVal[LAUNCH_DATA] ))
            if ! AUFAUS->(eof())
              keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN)
              if empty(AUFAUS->Ab_AufNr)
                Auf_erfassen(AUFAUS->AufArt )
              else
                // suche Rahmenauftrag um Art festzustellen Artikel / Budget
                aktRec:=AUFAUS->(recno())
                AUFAUS->(dbseek( AUFAUS->Ab_AUfNr ))
                tempArt:=AUFAUS->AufArt
                AUFAUS->(dbgoto( aktRec ))
                Auf_erfassen(AUFAUS->AufArt , tempArt )
              endif
              close data
            endif
          endif
          exit
        case "INNER"
          keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN)
          InnerEdit(.f.)
          exit
        case "INLFDNR"
          keyboard tempVal[LAUNCH_DATA] + chr(K_RETURN)
          InnerEdit(.t.)
          exit
        case "OBERBAUGRUPPEN"
          showOberBaugruppen(tempVal[LAUNCH_DATA], .t., .t.)
          exit
        case "MIKI_PROG"
          // NOP
          exit
        otherwise
          Error( ACHTUNG+tempVal[LAUNCH_ALIAS]+" konnte nicht gestarted werden."+SCHWERER_FEHLER )
          Down()
        endswitch
        starte_bei:=""
      endif

    otherwise
      if DEVEL_PROG .and. AT_HOME
        init(KURZEL_DEVEL) // Auto-Login Jochen Gruhn
      else
        init() // Systemparameter setzten, Login
      endif
    endcase
  else
    if DEVEL_PROG .and. AT_HOME
      init(KURZEL_DEVEL) // Auto-Login Jochen Gruhn
      // init() // kein Auto-Login
    else
      init() // Systemparameter setzten, Login
    endif
  endif

  initMiki()

  // hide splash screen
  // qSplash:hide()
  // qSplash:=NIL
  // qPixmap:=NIL

  do while ! left(Auswahl,2)=="99"

    if getUser():infoOnly
      starte_bei:="9"
    endif

    if ! empty( starte_bei )
      // altd()
      keyboard starte_bei+chr(K_RETURN)
    endif

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    /**** lokales Menu anzeigen ****/
    cls
    titel("M I K I - P L A S T I K")
    @ ob-1,li-2 to unt,re


    @ ob, li say "01"+MENU_TRENNER+" Arbeitsvorbereitung"
    if getUser():mayEnterFakt
      @ ob+1 ,li say "02"+MENU_TRENNER+" Fakturierung"
    endif
    if getUser():mayEnterMatMenu
      @ ob+2 ,li say "03"+MENU_TRENNER+" Material-Bedarf"
    endif

    if getUser():DSGVO
      @ ob+4 ,li say "05"+MENU_TRENNER+" Bestellung"
    endif

    @ ob+6 ,li say "06"+MENU_TRENNER+" Listen"
    if getUser():mayPrint .and. getUser():mayPrintLabel
      @ ob+7 ,li say "07"+MENU_TRENNER+" Etiketten"
    endif
    if getUser():mayShowData .or. getUser():mayEditStock
      @ ob+8 ,li say "08"+MENU_TRENNER+" Stammdaten"
    endif
    @ ob+10,li say "09"+MENU_TRENNER+" Auskunft"

    if getUser():MayEnterMateinausg
      @ ob+12,li say "11"+MENU_TRENNER+" Material Ein-/Ausgang"
    endif
    if getUser():mayEditStock
      @ ob+13,li say "12"+MENU_TRENNER+" Artikel Lager-Bestand/Ort �ndern"
    endif
    if getUser():mayEnterBank
      @ ob+14,li say "20"+MENU_TRENNER+" Bank"
    endif

    Message("Ihre Auswahl bitte.    @F1@=Info   @99@=Ende")
    AUSWAHL_EINGABE
    menuRead(@GetList)

    akt_Auswahl:=getAuswahl(Auswahl)

    /* nur w�hrend Entwicklungs-Phase */
    if lastkey()==K_ESC
      if DEVEL_PROG
        exit
      else
        loop
      endif
    endif

    protAufruf(akt_auswahl)

    do case
     case akt_Auswahl == 1       /* Arbeitsvorbereitung */
      Av_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 2 .and. getUser():mayEnterFakt
      Fakt_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 3 .and. getUser():mayEnterMatMenu       /* Material-Bedarf */
      Mat_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 4       /* Reparaturen */
      // Repa_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 5 .and. getUser():DSGVO
      Best_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 6       /* Listen */
      List_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 7  .and. (getUser():mayPrint .and. getUser():mayPrintLabel)      /* etiketten */
      Eti_Menu( right(Auswahl,len(Auswahl)-3) )

      /* stammDaten */
    case akt_Auswahl == 8 .and. ( getUser():mayShowData .or. getUser():mayEditStock )
      Stam_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 9       /* Auskunft */
      Aus_Menu( right(Auswahl,len(Auswahl)-3) ,gesperrt ,starte_bei )

    case akt_Auswahl == 11 .and. getUser():MayEnterMateinausg
      EinAus_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 12
      tempVal:={}
      if getUser():mayEditStock
        tempVal:=aJoin(tempval, {"ARTIKEL->LG_Raum","ARTIKEL->LG_Regal","ARTIKEL->LG_Fach","ARTIKEL->LG_Text", "ARTIKEL->LAGEBEST"})
      endif
      if getUser():mayEditGewicht
        tempVal:=aJoin(tempval, {"ARTIKEL->Gewicht"})
      endif
      if len(tempVal) > 0
        ArtikelAendern(tempVal)
      endif

    case akt_Auswahl == 20 .and. getUser():mayEnterBank
      Bank_Menu( right(Auswahl,len(Auswahl)-3) )


    case akt_Auswahl == 40
      Message("Server wird gepingt.    Bitte warten....")
      if pingRemoteService()
        Message("Server ponged.  Bingo.       Bitte @Taste@ dr�cken.","@")
      else
        Message("Server down :(       Bitte @Taste@ dr�cken.","@")
      endif

    case akt_Auswahl == 41
      Message(ExeName() + " Version:"+alltrim(str(getCurrentVersion())),"@")

    case akt_Auswahl == 42 .and. ( getUser():id $ KURZEL_DEVEL)
      myTest()

    case akt_Auswahl == 43 .and. ( getUser():id $ KURZEL_DEVEL )
      myTest2()


      // case akt_Auswahl == 999 .and. DEVEL_PROG // dummy call, never invoked
      // MyMemoEdit() // otherwise mymemoedit is not linked?!

    endcase

    /* Abbruch , falls nicht alle Menu-Punkte erlaubt */
    if ! empty(starte_bei) .or. getUser():infoOnly
      exit
    endif

  ENDDO

  Down() // Ende aus

RETURN
/* EOP Menu */



/* Procedure Stam_Menu
*
90* Stamm-Daten-Menu
*
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Stam_Menu(Auswahl)
LOCAL Tiefe:=2 // wieviele Menus darunter(einschl. akt)
LOCAL li , ob , re , unt
LOCAL GetList:={}
LOCAL akt_Auswahl:=-1
LOCAL Alt_Message:=""

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("S T A M M - D A T E N")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=5 ; ob:=2 ; re:=30 ; unt:=9
      @ ob, li say "Allgemein" color COLINV
      @ ob+1, li say "01"+MENU_TRENNER+" Artikel"
      if getUser():DSGVO
        @ ob+2 ,li say "02"+MENU_TRENNER+" Kunden"
        @ ob+3 ,li say "03"+MENU_TRENNER+" Lieferanten"
        @ ob+4 ,li say "04"+MENU_TRENNER+" Speditionen"
        @ ob+6 ,li say "08"+MENU_TRENNER+" Personal"
      endif
      if getUser():mayEnterSysMenu
        @ ob+7, li say "09"+MENU_TRENNER+" System-Daten"
      endif

      /* 2"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=2 ; re:=79 ; unt:=9
      @ ob, li say "Arbeitsvorbereitung" color COLINV
      @ ob+1 ,li say "11"+MENU_TRENNER+" Texte"
      @ ob+2 ,li say "12"+MENU_TRENNER+" Maschinen / Zeiten"
      @ ob+3 ,li say "13"+MENU_TRENNER+" Kostenstellen"
      // @ ob+4 ,li say "14"+MENU_TRENNER+" Kalkulations-Stamm"
      if getUser():mayEditEK .and. getUser():mayEditVK
        @ ob+5 ,li say "15"+MENU_TRENNER+" Preiskalkulation (von-bis)"
      endif
      @ ob+6 ,li say "16"+MENU_TRENNER+" AV-Nr (Sortierung)"
      @ ob+7 ,li say "17"+MENU_TRENNER+" Maschinen-Gruppen"

      /* 3"+MENU_TRENNER+" Quadrant */
      li:=5 ; ob:=10; re:=30 ; unt:=23
      @ ob, li say "Fakturation" color COLINV
      @ ob+1 ,li say "21"+MENU_TRENNER+" Rabattgruppen"
      @ ob+2 ,li say "22"+MENU_TRENNER+" Zahlungskonditionen"
      @ ob+3 ,li say "23"+MENU_TRENNER+" Liefertermine"
      @ ob+4 ,li say "24"+MENU_TRENNER+" Versandarten"
      @ ob+5 ,li say "25"+MENU_TRENNER+" Verpackungen (Paletten)"
      @ ob+6 ,li say "26"+MENU_TRENNER+" Erl�sgruppen"
      @ ob+7 ,li say "27"+MENU_TRENNER+" Textbausteine AB, Angebot etc."
      @ ob+8, li say "28"+MENU_TRENNER+" Textbausteine  Artikel"
      @ ob+9 ,li say "29"+MENU_TRENNER+" Mat.Kennziffer Artikel"
      @ ob+10,li say "30"+MENU_TRENNER+" Warennumer Intra.Stat."
      @ ob+11,li say "31"+MENU_TRENNER+" Kunden-Werbegeschenke"
      @ ob+12,li say "32"+MENU_TRENNER+" Artikel Preisgruppen"

      // @ ob+1 ,li say "21"+MENU_TRENNER+" Rabattgruppen"
      // @ ob+2 ,li say "22"+MENU_TRENNER+" Zahlungskonditionen"
      // @ ob+3 ,li say "23"+MENU_TRENNER+" Werbetexte"
      // @ ob+4 ,li say "24"+MENU_TRENNER+" Versandarten"
      // @ ob+5 ,li say "25"+MENU_TRENNER+" Verk�ufer"
      // @ ob+6 ,li say "26"+MENU_TRENNER+" Erl�sgruppen"
      // @ ob+7 ,li say "27"+MENU_TRENNER+" Liefertermine"
      // @ ob+8 ,li say "28"+MENU_TRENNER+" ArtNr. Letzte Stelle"
      // @ ob+9 ,li say "29"+MENU_TRENNER+" Kunden-Werbegeschenke"
      // @ ob+10,li say "30"+MENU_TRENNER+" Spedition"
      // @ ob+11,li say "31"+MENU_TRENNER+" Honsel K-Lager Bestand"
      // @ ob+12,li say "32"+MENU_TRENNER+" Mat.Kennziffer Artikel"
      // @ ob+13,li say "33"+MENU_TRENNER+" Paletten"


      /* 4"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=11 ; re:=79 ; unt:=23
      @ ob, li say "K-Lager" color COLINV
      @ ob+1,li say "40"+MENU_TRENNER+" K-Lager Stammdaten"
      @ ob+2,li say "41"+MENU_TRENNER+" Honsel K-Lager Bestand"

      /* 5"+MENU_TRENNER+" Quadrant ;) */
      li:=40 ; ob:=15 ; re:=79 ; unt:=23
      @ ob, li say "Sonstige" color COLINV
      if getUser():DSGVO
        @ ob+1,li say "90"+MENU_TRENNER+" Nietger�te"
      endif
      @ ob+2,li say "91"+MENU_TRENNER+" ArtNr. Letzte Stelle"
      if getUser():DSGVO
        @ ob+3,li say "92"+MENU_TRENNER+" Verk�ufer"
      endif
      @ ob+4,li say "93"+MENU_TRENNER+" Grund �nderung Artikel"
      @ ob+5,li say "94"+MENU_TRENNER+" L�nder-Kennzeichen"
      @ ob+6,li say "95"+MENU_TRENNER+" Zoll-Ausgangsstellen"
      //@ ob+7,li say "97"+MENU_TRENNER+" Daten aufs Testsystem kopieren"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif
    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
      /* allgemein */
    case akt_Auswahl == 1
      ArtikelAendern()
    case akt_Auswahl == 2 .and. getUser():DSGVO
      KundenAendern()
    case akt_Auswahl == 3 .and. getUser():DSGVO
      LieferantAendern()
    case akt_Auswahl == 4 .and. getUser():DSGVO
      aend("Spedit",;
        "@�@ndern @K@opieren @L@�schen @U@mbenennen @F4/STRG-F4@=Paletten @F6@=Kunden")

    case akt_Auswahl == 8 .and. getUser():DSGVO
      aend("Personal")
    case akt_Auswahl == 9 .and. getUser():mayEnterSysMenu
      Sys_Menu( right(Auswahl,len(Auswahl)-3) )

      /*** Arbeitsvorbereitung ***/
    case akt_Auswahl == 11
      Alt_Message:="@�@ndern @L@�schen @S@perren @F6@=St�cklisten @F12@-@N@eu @K@opieren Ende @(x,ESC)@"
      aend("Text",alt_message)
    case akt_Auswahl == 12
      Alt_Message:="@�@ndern @L@�schen @S@perren @U@mben. @F6@=St�cklisten @F12@-@N@eu @K@opieren Ende @(x,ESC)@"
      aend("Maschine",alt_message)
    case akt_Auswahl == 13
      aend("KstStamm",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Artikel @F12@-@N@eu Ende @x,ESC@")
    case akt_Auswahl == 14

    case akt_Auswahl == 15 .and. getUser():mayEditEK .and. getUser():mayEditVK
      preis_kalk()
    case akt_Auswahl == 16
      aend("AvSortNr","@�@ndern  @K@opieren  @L@�schen  @U@mbenennen @F6@=Artikel @F12@-@N@eu  "+;
        "Ende @x,ESC@")
    case akt_Auswahl == 17
      aend("MaschGr",;
        "@�@ndern @L@�schen @S@perren @U@mben. @F6@=Maschinen @F12@-@N@eu @K@opieren Ende @(x,ESC)@")

      /* Fakturierung */
    case akt_Auswahl == 21
      aend("Rabatt",;
        "@�@ndern @K@opieren @L@�schen @S@perren @F5@=ABs @F6@=Artikel")
    case akt_Auswahl == 22
      aend("ZahlKond",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Kunden @F12@-@N@eu Ende @x,ESC@")

    case akt_Auswahl == 23
      aend("LiefTerm")

    case akt_Auswahl == 24
      aend("Versart",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Kunden @F12@-@N@eu Ende @x,ESC@")
    case akt_Auswahl == 25
      Aend("Paletten")
    case akt_Auswahl == 26
      aend("Erl_Grup",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Artikel @F12@-@N@eu Ende @x,ESC@")
    case akt_Auswahl == 27
      aend("Text_kz")
    case akt_Auswahl == 28
      aend("ArtText")
    case akt_Auswahl == 29
      Aend("Mat_KZ",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Artikel @F12@-@N@eu Ende @x,ESC@")
    case akt_Auswahl == 30
      aend("IntraStat",;
        "@�@ndern @K@opieren @L@�schen @S@perren @U@mbenennen @F6@=Artikel @F12@-@N@eu Ende @x,ESC@")
    case akt_Auswahl == 31
      if open( "Werbung" , "Kunden" )
        select Werbung
        set relation to (left(WERBUNG->KDNr_Werb,5)) into Kunden
        aend("Werbung")
      endif
    case akt_Auswahl == 32
      aend("ArtPrGr", "@�@ndern @K@opieren   @L@�schen   @F6@=Artikel")

      /** K-Lager */
    case akt_Auswahl == 40
      KLag_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 41
      honselDatAend()

      /** Repa */
    case akt_Auswahl == 90 .and. getUser():DSGVO
      Stam2_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 91
      aend("LetzteSt","@�@ndern  @K@opieren  @L@�schen  @F6@=Artikel @F12@-@N@eu  Ende @x,ESC@")
      // Aend("Grund")
    case akt_Auswahl == 92 .and. getUser():DSGVO
      aend("Verkauf")
    case akt_Auswahl == 93
      Aend("Grund")
    case akt_Auswahl == 94
      aend("Land",,"LK")
    case akt_Auswahl == 95
      aend("ZollStelle")
    case akt_Auswahl == 97
      // copyDat2Test()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Stam_Menu */


/* Procedure Stam2_Menu
*
* Stamm-Daten-Menu (alte Daten, z.B. Repa)
*
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Stam2_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=5 , ob:=3 , re:=60 , unt:=23
LOCAL GetList:={}
LOCAL akt_Auswahl:=-1
LOCAL Alt_Message:=""
  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("S T A M M - D A T E N - Nietger�te")

      /* 1"+MENU_TRENNER+" Quadrant */
      ob:=3
      @ ob, li say "Produktion" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Typ"
      @ ob+2 ,li say "02"+MENU_TRENNER+" Nietger�te Produktion"

      ob:=8
      @ ob, li say "Reparaturen" color COLINV
      @ ob+1 ,li say "11"+MENU_TRENNER+" Rep. Kunden"
      @ ob+2 ,li say "12"+MENU_TRENNER+" Ger�te-Status"
      // @ ob+3 ,li say "13"+MENU_TRENNER+" Typ"
      @ ob+4 ,li say "14"+MENU_TRENNER+" Empf�nger"
      @ ob+5 ,li say "15"+MENU_TRENNER+" Produktion"
      @ ob+6, li say "16"+MENU_TRENNER+" Standort"
      @ ob+7 ,li say "17"+MENU_TRENNER+" Versand-Art"
      @ ob+8 ,li say "18"+MENU_TRENNER+" Kosten"
      @ ob+9 ,li say "19"+MENU_TRENNER+" Bemerkungen (Kunden)"
      @ ob+10,li say "20"+MENU_TRENNER+" St�rungen/Fehler"
      @ ob+11,li say "21"+MENU_TRENNER+" Beurteilungen"
      @ ob+12,li say "22"+MENU_TRENNER+" Letzte Stelle (Nietger.)"
      @ ob+13,li say "23"+MENU_TRENNER+" Ger�te-Texte (Prod.)"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif
    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      aend("Gerat")
    case akt_Auswahl == 2
      editNietGerate()

        /* Reparaturen */
    case akt_Auswahl == 11
      aend("RepKund")
    case akt_Auswahl == 12
      if open("Status","Gerat","Artikel")
        Alt_Message:="@�@ndern  @L@�schen  @S@perren  @D@upliz. @E@xportieren  @F12@-@N@eu  @K@opieren Ende @(x,ESC)@"
        aend("Status",alt_message)
      endif
    case akt_Auswahl == 14
      aend("Empfaeng")
    case akt_Auswahl == 15
      Alt_Message:="@�@ndern / @L@�schen / @S@perren / @F12@-@N@eu / Ende @(x,ESC)@"
      aend("Prod",Alt_Message,"K")
    case akt_Auswahl == 16
      aend("Standort")
    case akt_Auswahl == 17
      aend("Versand")
    case akt_Auswahl == 18
      aend("Kosten")
    case akt_Auswahl == 19
      aend("Kd_Bemer")
    case akt_Auswahl == 20
      aend("RepStamm")
    case akt_Auswahl == 21
      aend("Beurteil")
    case akt_Auswahl == 22
      aend("LetzteNi")
    case akt_Auswahl == 23
      aend("ProdText")

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Stam_Menu */



/* Procedure Sys_Menu
*
* System-Daten
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Sys_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=20 , ob:=2 , re:=60 , unt:=22
LOCAL akt_Auswahl:=-1 , zeile:=0, message:="",alt_message
LOCAL getList:={},pass:=space(5),printBuffer

  /* Benutzer berechtigt ? */
  if ! getUser():mayEnterSysMenu
    Error(NO_PERMISSION)
    RETURN
  endif

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("S Y S T E M - D A T E N")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=5 ; ob:=2 ; re:=30 ; unt:=21
      @ ob, li say "Stammdaten" color COLINV
      @ ob+1, li say "01"+MENU_TRENNER+" Drucker/Druck-Parameter"
      @ ob+2, li say "02"+MENU_TRENNER+" Listen -> Drucker"
      @ ob+3, li say "03"+MENU_TRENNER+" System-Parameter"
      @ ob+4, li say "04"+MENU_TRENNER+" Aktuelle Logins"
      // @ ob+4, li say "04"+MENU_TRENNER+" Arbeitsplatz"
      @ ob+5, li say "05"+MENU_TRENNER+" Mitarbeiter"
      @ ob+6, li say "06"+MENU_TRENNER+" Bewegung (Lagerbest.)  l�schen"
      @ ob+7, li say "07"+MENU_TRENNER+"          (Best.best.)  l�schen"
      @ ob+9 ,li say "09"+MENU_TRENNER+" Mengeneinheiten �ndern"
      @ ob+10,li say "10"+MENU_TRENNER+" Mehrwertsteuer  �ndern"
      @ ob+12,li say "12"+MENU_TRENNER+" St�ckliste wiederherstellen"
      @ ob+13,li say "13"+MENU_TRENNER+" BLZ einlesen"
      // @ ob+14,li say "14"+MENU_TRENNER+" Zoll-Warennummer Update"
      @ ob+15,li say "15"+MENU_TRENNER+" Lagerorte Miki"
      @ ob+16,li say "16"+MENU_TRENNER+" Versand-Etiketten"
      @ ob+17,li say "17"+MENU_TRENNER+" Ph�nix Rabatte bearbeiten"

      @ ob+19,li say "Inventur" color COLINV
      @ ob+20,li say "19"+MENU_TRENNER+" Inventur"

      /* 2"+MENU_TRENNER+" Quadrant */
      li:=41 ; ob:=2 ; re:=79 ; unt:=9
      @ ob, li say "Allgemein" color COLINV
      @ ob+ 1,li say "21"+MENU_TRENNER+" Tagesdatum �ndern"
      @ ob+ 2,li say "22"+MENU_TRENNER+" Preispflege (Artikel)"
      @ ob+ 3,li say "23"+MENU_TRENNER+" Preis-Kalkulation (komplett)"
      @ ob+ 4,li say "24"+MENU_TRENNER+" Preise je Lieferant �ndern"
      @ ob+ 5,li say "25"+MENU_TRENNER+" Auftrags-Bestand (Server) berechnen"
      @ ob+ 6,li say "26"+MENU_TRENNER+" Auftrags-Bestand (Lokal)  berechnen"
      @ ob+ 7,li say "27"+MENU_TRENNER+" Bestellbestand Artikel berechnen"

      @ ob+ 8,li say "28"+MENU_TRENNER+" St�cklisten �berpr�fen"
      @ ob+ 9,li say "29"+MENU_TRENNER+" Kaufartikel �berpr�fen"
      @ ob+10,li say "30"+MENU_TRENNER+" Leeres Formular   drucken"
      @ ob+11,li say "31"+MENU_TRENNER+" Leeren Brief-Kopf drucken"
      @ ob+12,li say "32"+MENU_TRENNER+" Aufrufe Men�-Eintr�ge"

      // @ ob+12,li say "33"+MENU_TRENNER+" Rechaus ab dem 19.01.2010"

      if AT_HOME .or. DEVEL_PROG
        @ ob+13,li say "33"+MENU_TRENNER+" System Menu intern"
      endif

      @ ob+14,li say "34"+MENU_TRENNER+" Fenster-Daten je Benutzer/Liste"
      @ ob+15,li say "35"+MENU_TRENNER+" Mindest-Bestellmenge berechnen"
      @ ob+16,li say "36"+MENU_TRENNER+" Crontab anzeigen/�ndern"
      @ ob+17,li say "37"+MENU_TRENNER+" Preiserh�hung Honsel"
      @ ob+18,li say "38"+MENU_TRENNER+" Preiserh�hung Honsel->AB anpassen"

      @ ob+20,li say "40"+MENU_TRENNER+" Programme beenden"
      // @ ob+20,li say "98"+MENU_TRENNER+" Jahresabschluss"

      /* Eingabe */
      li:=45 ; ob:=10 ; re:=79 ; unt:=23

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      message:="@�@ndern  @L@�schen  @S@perren  @T@est  @K@opieren  Ende @(x,ESC)@"
      aend("Drucker",Message,"T")
    case akt_Auswahl == 2
      aend("Liste")
    case akt_Auswahl == 3
      Sys_Aend()
    case akt_Auswahl == 4
      if (printBuffer:=LoginDispatcher():new():getPrintBuffer()):getNumLines()>0
        Drucker("BS")
        getUser():getCurrentPrintJob():printBuffer(printBuffer)
        getUser():getCurrentPrintJob():endDoc()
      else
        Error("Keine weiteren Benutzer eingeloggt.")
      endif
    case akt_Auswahl == 5
      Alt_Message:="@E@mail "+"@�@ndern @I@nfo @L@�schen @R@eset  @P@asswort @S@perren @F12@-@N@eu @K@opieren Ende @(x,ESC)@"
      aend("Login",Alt_Message)
    case akt_Auswahl == 6
      // loesche("Waraus") // l�sche Art.Bewegung Lagerbest.
    case akt_Auswahl == 7

    case akt_Auswahl == 09
      aend("Einheit")
    case akt_Auswahl == 10
      aend("Mwst_kz")
    case akt_Auswahl == 12
      AvStkRecall()
    case akt_Auswahl == 13
      BLZImport()
    case akt_Auswahl == 14
      // intrastatUpdate()

    case akt_Auswahl == 15
      aend("LagerOrt")

    case akt_Auswahl == 16
      aend("Vers_eti")

    case akt_Auswahl == 17
      phoenixRabattStaffel()

    case akt_Auswahl == 19
      Inv_Menu(right(Auswahl,len(Auswahl)-3))

    case akt_Auswahl == 21
      @ 1,0 clear
      Message("Bitte Passwort eingeben.")
      @ 8,30 say "Passwort:"
      pass:=GETSECRET( pass, 8, 40)
      if ! ABBRUCH .and. trim(upper(pass))=="ZORRO"
        @ 0,3 get getUser():date
        Message("Bitte Tagesdatum und Passwort eingeben.")
        read
      endif

    case akt_Auswahl == 22
      PreisPflege()
    case akt_Auswahl == 23
      Preis_check()
    case akt_Auswahl == 24
      PreisLieferant()
    case akt_Auswahl == 25
      AufBestand(.t.,.f.,.f. )
    case akt_Auswahl == 26
      Message("Auftragsbestand wird lokal neu berechnet.   Bitte warten...")
      myAufbestand( .t. , .f. , .t. )
      Message()
    case akt_Auswahl == 27
      BestBestand()

    case akt_Auswahl == 28
      StkList_check()

    case akt_Auswahl == 29
      EinkaufArt_check()

    case akt_Auswahl == 30
      LeerFormular()
    case akt_Auswahl == 31
      LeerBrief()
    case akt_Auswahl == 32
      Alt_Message:="@D@etails @�@ndern @F12@ Ende @(x,ESC)@"
      aend("Aufruf",Alt_Message,"LKS")

      /** temp. Feature */
    case akt_Auswahl == 33
      if ! (AT_HOME .or. DEVEL_PROG)
        @ Maxrow(),0 clear
        @ Maxrow(),30 say "Passwort:"
        pass:=GETSECRET( pass, @ Maxrow(), 40)
        if ABBRUCH .or. encrypt(trim(upper(pass)))<>MASTER_PASS
          loop
        endif
      endif
      dev_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 34
      aend("Fenster")
    case akt_Auswahl == 35
      MindestBestellMenge()
    case akt_Auswahl == 36
      Alt_Message:="@�@ndern @C@rontab ausf�hren @L@�schen @R@eset @S@perren @F12@-@N@eu Ende @(x,ESC)@"
      aend("Crontab",Alt_Message,"K")
    case akt_Auswahl == 37
      honselPreisErhoehung()
    case akt_Auswahl == 38
      honselABErhoehung()

      // Manueller shutdown aller anderen Programm
    case akt_Auswahl == 40
      forceQuit()

      /** hidden features ! nur fuer Systemmanager !*/
    case akt_Auswahl == 42

      // backup("Konsig")
      // altd()
      // if open("Konsig")
      // dbseek("19614"+"5015480 ")
      // if ! KONSIG->(eof()) .and. rec_lock(5)
      // tempVal:=KONSIG->Berechnet
      // replace KONSIG->Berechnet with 0
      // dbseek("19654"+"5015480 ")
      // if tempVal > 0 .and. ! KONSIG->(eof()) .and. rec_lock(5)
      // replace KONSIG->Berechnet with KONSIG->Berechnet + tempVal
      // endif
      // Message("Moved:"+str(tempVal) +"Berechnet:"+str(KONSIG->Berechnet)+"Gelief:"+str(KONSIG->GeliefGes), "@")
      // endif
      // dbcommitall()
      // dbunlockall()
      // close data
      // endif


    case akt_Auswahl == 43

    case akt_Auswahl == 98
      // JahresAbschluss()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  enddo

RETURN
/* EOP Sys_Menu */

/*
* Alles zur Inventur
*/
PROCEDURE Inv_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=18 , ob:=2 , re:=64 , unt:=22
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    cls
    titel("I N V E N T U R")
    @ ob-1,li-2 to unt,re

    @ ob, li say "K-Lager" color COLINV
    @ ob+1,li say "1"+MENU_TRENNER+" K-Lager Inv.best. intern �bernehmen"
    @ ob+2,li say "2"+MENU_TRENNER+" K-Lager Bestand anpassen lt. Z�hlung"

    @ ob+8, li say "Miki Lager" color COLINV
    @ ob+9,li say "11"+MENU_TRENNER+" Artikel Inventur-Z�hlbestand vorschlagen"

    @ ob+11, li say "Inventur-Listen" color COLINV
    @ ob+12,li say "30"+MENU_TRENNER+" Inventurliste Miki / K-Lager"
    @ ob+13,li say "31"+MENU_TRENNER+" Z�hl-Liste"
    @ ob+14,li say "32"+MENU_TRENNER+" Honsel Beistellteile detailliert"
    @ ob+15,li say "33"+MENU_TRENNER+" Honsel Beistellteile Bestands-Liste "
    @ ob+16,li say "34"+MENU_TRENNER+" Honsel Beistellteile Z�hl-Liste"
    @ ob+17,li say "35"+MENU_TRENNER+" K-Lager Artikel je Kunde-Liste"
    @ ob+18,li say "36"+MENU_TRENNER+" K-Lager Inventurliste (STRG-I)"
    @ ob+19,li say "37"+MENU_TRENNER+" Honsel ehemal. Beistellteil-Liste"

    // @ ob+17, li say "System" color COLINV

    Message("Ihre Auswahl bitte.   @Leer@=Ende")
    AUSWAHL_EINGABE
    menuRead(@GetList)

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      KinvIntBestand()
    case akt_Auswahl == 2
      KInvIntAendern()

      /** Miki Lager */
    case akt_Auswahl == 10
      // loesche_InvBestand()
    case akt_Auswahl == 11
      kopiere_InvBestand()
      // case akt_Auswahl == 12
      // inv_abschluss()

      /** Listen */
    case akt_Auswahl == 30
      Inv_Liste()
    case akt_Auswahl == 31
      Inv_Zaehl()
    case akt_Auswahl == 32
      honsBeiInvListe()
    case akt_Auswahl == 33
      honsBei2InvListe()
    case akt_Auswahl == 34
      honsBeiZaehlListe()

    case akt_Auswahl == 35
      KKundArtikelListe()
    case akt_Auswahl == 36
      KLagerBewegung()
    case akt_Auswahl == 37
      honselEhemBeistellTeile()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO


RETURN
/* EOP Inv_Menu */



/* Procedure List_Menu  *****************************************
*
* Listen
* Parameters: evtl. Vorauswahl
*/
PROCEDURE List_Menu(Auswahl)
LOCAL Tiefe:=2 // wieviele Menus darunter(einschl. akt)
LOCAL li , ob:=2 , re:=60 , unt:=23
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("L I S T E N - D R U C K E N")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=2 ; ob:=2
      @ ob, li say "Allgemein" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Artikel letzte Bewegung"
      @ ob+2 ,li say "02"+MENU_TRENNER+" Bewegung: Lager-Bestand"
      @ ob+3 ,li say "03"+MENU_TRENNER+" Artikel Bewegung pro Jahr"
      @ ob+4 ,li say "04"+MENU_TRENNER+" Material in welcher St�ckliste"
      @ ob+5 ,li say "05"+MENU_TRENNER+" Werkzeug in welcher St�ckliste"
      @ ob+6 ,li say "06"+MENU_TRENNER+" Artikel mit alternat. Material"
      @ ob+7 ,li say "07"+MENU_TRENNER+" Honsel-Preise je St�ckliste"
      @ ob+8 ,li say "08"+MENU_TRENNER+" St�ckliste (Material)"
      @ ob+9 ,li say "09"+MENU_TRENNER+" Artikel ohne St�ckliste"

      if getUser():DSGVO
        @ ob+10 ,li say "10"+MENU_TRENNER+" Ph�nix-Listen"
        @ ob+11 ,li say "11"+MENU_TRENNER+" Honsel-Preis-Liste"
      endif
      @ ob+12 ,li say "12"+MENU_TRENNER+" Neg. Artikel Verf�gbarkeits-Liste"
      @ ob+13 ,li say "13"+MENU_TRENNER+" Werkzeug-Bestands-Liste"
      @ ob+14 ,li say "14"+MENU_TRENNER+" Lager-Bestands-Liste"
      if getUser():DSGVO
        @ ob+15 ,li say "15"+MENU_TRENNER+" Werbe-Geschenke"
        @ ob+16 ,li say "16"+MENU_TRENNER+" Kalkulationspreis < EK + 20%"
      endif
      @ ob+17 ,li say "17"+MENU_TRENNER+" Artikel mit ident. Mat.Kz."
      @ ob+18 ,li say "18"+MENU_TRENNER+" Neg. Lagerbestand"
      @ ob+19 ,li say "19"+MENU_TRENNER+" Produktionsliste / vorgef. Teile"
      @ ob+20 ,li say "20"+MENU_TRENNER+" Verkaufte Artikel"

      /* 2"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=2
      if getUser():DSGVO
        @ ob, li say "Fakturierung" color COLINV
        @ ob+1 ,li say "21"+MENU_TRENNER+" Rechnungsausgangsbuch (t�gl.)"
        @ ob+2 ,li say "22"+MENU_TRENNER+" Rechn.Aus.Buch (t�gl.) wiederholen"
        @ ob+3 ,li say "23"+MENU_TRENNER+" Rechnungsausgangsbuch (Monat)"
        @ ob+4 ,li say "24"+MENU_TRENNER+" Mahnungen / F�llige Rechnungen"
        @ ob+5 ,li say "25"+MENU_TRENNER+" Preisliste"
        @ ob+6 ,li say "26"+MENU_TRENNER+" Gelangensbescheinigungen"
        @ ob+7 ,li say "27"+MENU_TRENNER+" Offene Auftr�ge"
      endif

      /* 3"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=10
      @ ob, li say "Stammdaten" color COLINV
      if getUser():DSGVO
        @ ob+1, li say "30"+MENU_TRENNER+" Kunden je Standort"
        @ ob+2, li say "31"+MENU_TRENNER+" Kunden-Liste"
        @ ob+3, li say "32"+MENU_TRENNER+" Kunden-Ums�tze"
        @ ob+4, li say "33"+MENU_TRENNER+" Umsatz pro Jahr (Versicherung)"
        @ ob+5, li say "34"+MENU_TRENNER+" Lieferanten-Liste"
      endif
      if getUser():mayCreateArticles
        @ ob+6 ,li say "35"+MENU_TRENNER+" Artikel anzeigen und l�schen"
      endif
      @ ob+7 ,li say "36"+MENU_TRENNER+" Maschinen / Zeiten  anzeigen"
      @ ob+8 ,li say "37"+MENU_TRENNER+" VK je St�ckliste (alle Artikel)"

      /* 4"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=20
      @ ob, li say "K-Lager" color COLINV
      @ ob+1 ,li say "41"+MENU_TRENNER+" K-Lager Listen."
      // @ ob+2 ,li say "42"+MENU_TRENNER+" Bewegung: K-Lager-Bestand int."
      // @ ob+3 ,li say "43"+MENU_TRENNER+" K-Lager Mindest-Bestands-Liste"
      if getUser():DSGVO
        @ ob+3 ,li say "49"+MENU_TRENNER+" weitere sonstige Listen..."
      endif

      AUSWAHL_EINGABE
      menuRead(@GetList)

    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      ArtLetztBeweg()
    case akt_Auswahl == 2
      WarausList()
    case akt_Auswahl == 3
      WarausJahrList()
    case akt_Auswahl == 4
      MatArtikelListe("M")
    case akt_Auswahl == 5
      MatArtikelListe("W")
    case akt_Auswahl == 6
      ArtAlternatMaterial()
    case akt_Auswahl == 7
      Preis_Stk_Liste()
    case akt_Auswahl == 8
      Niet_Stk_Liste()
    case akt_Auswahl == 9
      ArtOhneStck()

      /* allgemein */
    case akt_Auswahl == 10 .and. getUser():DSGVO
      Phoenix_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 11 .and. getUser():DSGVO
      Liste_Allg("HonsNr")
    case akt_Auswahl == 12
      NegVerfueg(,,,,,,"J","N") // alle Artikel anzeigen, nicht sortier nach KW
    case akt_Auswahl == 13
      Liste_Allg("Werkzeug")
    case akt_Auswahl == 14
      LagerListe()
    case akt_Auswahl == 15 .and. getUser():DSGVO
      Werbe_Menu(right(Auswahl,len(Auswahl)-3))
    case akt_Auswahl == 16 .and. getUser():DSGVO
      Liste_Allg("KA_CHECK")
    case akt_Auswahl == 17
      MatKzListe()
    case akt_Auswahl == 18
      Liste_Allg("Neg_Best")
    case akt_Auswahl == 19
      ProduktionsListe()
    case akt_Auswahl == 20
      VerkaufteArtList()


      /* Fakturierung */
    case akt_Auswahl == 21 .and. getUser():DSGVO
      RechAus(.f.) // t�gl
    case akt_Auswahl == 22 .and. getUser():DSGVO
      RechAus(.f.,.t.,.t.) // t�gl wiederholen
    case akt_Auswahl == 23 .and. getUser():DSGVO
      RechAus(.t.) // Monat
    case akt_Auswahl == 24 .and. getUser():DSGVO
      Mahnliste()
    case akt_Auswahl == 25 .and. getUser():DSGVO
      Preis_List()
    case akt_Auswahl == 26 .and. getUser():DSGVO
      GelangensList()
    case akt_Auswahl == 27 .and. getUser():DSGVO
      AuftragsListe()

      /** Stammdaten */
    case akt_Auswahl == 30 .and. getUser():DSGVO
      StandortListe()
    case akt_Auswahl == 31 .and. getUser():DSGVO
      KundenListe()
    case akt_Auswahl == 32 .and. getUser():DSGVO
      KundenUmsatz()
    case akt_Auswahl == 33 .and. getUser():DSGVO
      UmsatzJahr()
    case akt_Auswahl == 34 .and. getUser():DSGVO
      LieferantenListe()
    case akt_Auswahl == 35 .and. getUser():mayCreateArticles
      ArtLoesch()
    case akt_Auswahl == 36
      ZeitListe()
    case akt_Auswahl == 37
      rekPreisStkListe()


      /** K-Lager */
    case akt_Auswahl == 41
      List_KLager_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 49 .and. getUser():DSGVO
      List2_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 90 // versteckt
      MyRun( 'zeige '+LISTEN_AUS )
      trouble("Zeige",{ "ACHTUNG Hier evtl. Fehlerquelle, Speicher" } )
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP List_Menu */

/* 
* Listen 2"+MENU_TRENNER+" Teil
* Parameters: evtl. Vorauswahl
*/
PROCEDURE List2_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li,ob,unt:=23
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("SONSTIGE - L I S T E N - D R U C K E N")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=2 ; ob:=2
      @ ob, li say "Verschiedene" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Kostenstellen-Liste"
      @ ob+2 ,li say "02"+MENU_TRENNER+" Rohmaterial-Bedarfs-Liste"
      @ ob+3 ,li say "03"+MENU_TRENNER+" Kunden Ausfall-Versicherung"

      // @ ob+4 ,li say "04"+MENU_TRENNER+" Referenzliste Material-Kz"
      @ ob+4 ,li say "05"+MENU_TRENNER+" Lieferplan"
      @ ob+5 ,li say "06"+MENU_TRENNER+" Erl�s-Konten (R�ckrufkostenvers.)"
      @ ob+6 ,li say "07"+MENU_TRENNER+" Auftragsbestand je Kunde"
      @ ob+7 ,li say "08"+MENU_TRENNER+" Ger�te je Kunde"
      @ ob+8 ,li say "09"+MENU_TRENNER+" Artikel je Kunde"
      @ ob+9 ,li say "10"+MENU_TRENNER+" Fakt. Historie"
      @ ob+10,li say "11"+MENU_TRENNER+" Kauf-Artikel"
      @ ob+11,li say "12"+MENU_TRENNER+" Umsatz je Artikel"
      @ ob+12,li say "13"+MENU_TRENNER+" Artikel je ME (Mengeneinheit)"
      @ ob+13,li say "14"+MENU_TRENNER+" Lieferliste"
      @ ob+14,li say "15"+MENU_TRENNER+" Offene Bestellungen"
      @ ob+15,li say "16"+MENU_TRENNER+" Mehrfach-Spritzungen"
      @ ob+16,li say "17"+MENU_TRENNER+" Werkzeug-Liste"
      @ ob+17,li say "18"+MENU_TRENNER+" Umsatz-Liste EU (Intra.Stat.)"
      @ ob+18,li say "19"+MENU_TRENNER+" Umsatz je KostenSt. und Monat"
      @ ob+19,li say "20"+MENU_TRENNER+" Material Verf�gbarkeit/Toleranz"
      @ ob+20,li say "21"+MENU_TRENNER+" AB / Rechnungs-Liste"
      // @ ob+21,li say "22"+MENU_TRENNER+" Provisions-Liste"
      /* 2"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=3
      @ ob-1, li say "Inventur" color COLINV
      @ ob ,li say "30"+MENU_TRENNER+" Inventur-Men�"
      @ ob+1,li say "31"+MENU_TRENNER+" K-Lager Entnahme Liste"

      /* 3"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=8
      @ ob-1, li say "Formulare" color COLINV
      @ ob ,li say "40"+MENU_TRENNER+" Leeres Formular   drucken"
      @ ob+1,li say "41"+MENU_TRENNER+" Leeren Brief-Kopf drucken"

      /* 4"+MENU_TRENNER+" Quadrant */
      li:=40 ; ob:=12
      @ ob-1,li say "Konsistenz-Checks" color COLINV
      @ ob ,li say "50"+MENU_TRENNER+" Unbenutzte Zahl.Kond"
      @ ob+1,li say "51"+MENU_TRENNER+" Unbenutzte Mat.KZ"
      @ ob+2,li say "52"+MENU_TRENNER+" Ung�ltige Sonderzeichen Kunden/Lief."
      @ ob+3,li say "53"+MENU_TRENNER+" MindestBestellMenge/Rabatt-St. pr�f."
      @ ob+4,li say "54"+MENU_TRENNER+" MindestBestellMenge Soll/Ist pr�fen"
      @ ob+5,li say "55"+MENU_TRENNER+" Dubletten St�ckliste"
      @ ob+6,li say "56"+MENU_TRENNER+" Artikel EK / letzte Bestellung pr�f."
      @ ob+7,li say "57"+MENU_TRENNER+" Kunden Versandart/Zahlungskond."
      @ ob+8,li say "58"+MENU_TRENNER+" K-Lagerbestand Soll/Ist Abgleich"
      @ ob+9,li say "59"+MENU_TRENNER+" Dienstleistungen"
      @ ob+10,li say "60"+MENU_TRENNER+" Maschinen-Gruppen Kons.Check"

      AUSWAHL_EINGABE
      menuRead(@GetList)

    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case

      /* Verschiedene */
    case akt_Auswahl == 1
      KostenSt_Liste()
    case akt_Auswahl == 2
      RohMatBedarf()
    case akt_Auswahl == 3
      KundenUmsatzListe()
    case akt_Auswahl == 4
      // Magazine_Referenz()
    case akt_Auswahl == 5
      Liefer_Plan()
    case akt_Auswahl == 6
      Erl_Kto_Liste()
    case akt_Auswahl == 7
      Auf_KundListe()
    case akt_Auswahl == 8
      Auf_GeratListe()
    case akt_Auswahl == 9
      ArtikelKundListe()
    case akt_Auswahl == 10
      Historie()
    case akt_Auswahl == 11
      Liste_Allg("Kauf_ARTIKEL")
    case akt_Auswahl == 12
      Umsatz()
    case akt_Auswahl == 13
      Liste_Allg("ME_LISTE")
    case akt_Auswahl == 14
      Lieferliste()
    case akt_Auswahl == 15
      BestellListe()
    case akt_Auswahl == 16
      MehrfachSpritzListe()
    case akt_Auswahl == 17
      wkzList()
    case akt_Auswahl == 18
      EuUmsatzIntraStatExport(.t.)
    case akt_Auswahl == 19
      UmsatzKWList()
    case akt_Auswahl == 20
      checkMatVerfuegbar()
    case akt_Auswahl == 21
      AB_RechnungsListe()
    case akt_Auswahl == 22
      // Prov_Liste()

      /** Inventur */
    case akt_Auswahl == 30
      Inv_Menu(right(Auswahl,len(Auswahl)-3))
    case akt_Auswahl == 31
      KEntnahmeListe()

      /** Formulare */
    case akt_Auswahl == 40
      LeerFormular()
    case akt_Auswahl == 41
      LeerBrief()

      /** Konsistenz-Checks */
    case akt_Auswahl == 50
      unbenutzteZK()
    case akt_Auswahl == 51
      unbenutzteMatKZ()
    case akt_Auswahl == 52
      checkSZKdLief()
    case akt_Auswahl == 53
      MindBestRabattCheck()
    case akt_Auswahl == 54
      MindBestSollIstCheck()
    case akt_Auswahl == 55
      checkDublettenAvPost()
    case akt_Auswahl == 56
      EkCheck()
    case akt_Auswahl == 57
      KundenVersartCheck()
      // DatevEinles()
    case akt_Auswahl == 58
      BeistBestandsListe()
    case akt_Auswahl == 59
      DienstLeistungsCheck(.f.)
    case akt_Auswahl == 60
      MaschGrKonsistenzCheck()

    endcase


    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP List2_Menu */

/*
* Listen
* Parameters: evtl. Vorauswahl
*/
PROCEDURE List_KLager_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=14 , ob:=6 , re:=68 , unt:=19
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("K - L a g e r  -  L I S T E N - D R U C K E N")
      @ ob-2,li-2 to unt,re

      @ ob-1, li say "K-Lager - Allgemein" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Bewegung: K-Lager-Bestand ext."
      @ ob+2 ,li say "02"+MENU_TRENNER+" Bewegung: K-Lager-Bestand int."
      @ ob+3 ,li say "03"+MENU_TRENNER+" K-Lager Mindest-Bestands-Liste"
      @ ob+4 ,li say "04"+MENU_TRENNER+" K-Lager Artikel je Kunde-Liste"
      @ ob+5 ,li say "05"+MENU_TRENNER+" K-Lager Artikel Bestand (Honsel)"
      @ ob+7 ,li say "07"+MENU_TRENNER+" K-Lager Mind.Bestandliste(Email/Excel)"
      @ ob+9 ,li say "09"+MENU_TRENNER+" K-Lager Beistellteil in welchem Ger�t"
      @ ob+10 ,li say "10"+MENU_TRENNER+" K-Lager Beistellteile summiert je Artikel-Auswahl"
      @ ob+11 ,li say "11"+MENU_TRENNER+" K-Lager Beistellteile alle Artikel"
      @ ob+12 ,li say "12"+MENU_TRENNER+" Artikel mit K-Lager Beistellteilen (Bewegung)"


      AUSWAHL_EINGABE
      menuRead(@GetList)

    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case

      /** K-Lager */
    case akt_Auswahl == 01
      WarAusExternKlager()
    case akt_Auswahl == 02
      WarAusInternKlager()
    case akt_Auswahl == 03
      KlagMindBestListe()
    case akt_Auswahl == 04
      KKundArtikelListe()
    case akt_Auswahl == 05
      KKundArtikelListe(3, "10167-  ")
    case akt_Auswahl == 07
      KlagMindBestListe("KLager-VVG-bei-Miki-excel",KDNR_VVG)
    case akt_Auswahl == 09
      KlagGeratBeistellListe()
    case akt_Auswahl == 10
      BeistellArtikel()
    case akt_Auswahl == 11
      BeiArtDetails()
    case akt_Auswahl == 12
      ArtMitBeistell()
    endcase

    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP List_Menu */



/* Procedure Eti_Menu   *****************************************
*
* Etiketten-Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Eti_Menu(Auswahl)
LOCAL Tiefe:=2 // wieviele Menus darunter(einschl. akt)
LOCAL li:=20 , ob:=3 , re:=65 , unt:=23
LOCAL akt_Auswahl:=-1
LOCAL Message
LOCAL GetList:={}
  default Auswahl:=space(10)

  /** enable F8 -> show Etikett on screen */
  SetKey( K_F8 , {|| eti_show() } )

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("E T I K E T T E N  -  D R U C K E N")
      @ ob-1,li-2 to unt,re

      @ ob ,li say "01"+MENU_TRENNER+" Versand-Etiketten" color "R/"+getBackColor()
      @ ob+2, li say "02"+MENU_TRENNER+" Etiketten (frei gestalten)"
      @ ob+3 ,li say "03"+MENU_TRENNER+" AV-Etiketten"
      // @ ob+4 ,li say "04"+MENU_TRENNER+" UPS-Etiketten REPA"
      @ ob+5 ,li say "05"+MENU_TRENNER+" Adre�-Etiketten Kunden ohne Kd.Nr."
      @ ob+6 ,li say "06"+MENU_TRENNER+" Adre�-Etiketten Kunden mit  Kd.Nr."
      @ ob+7 ,li say "07"+MENU_TRENNER+" Adre�-Etiketten Kunden mit Anz. Paletten"
      @ ob+8 ,li say "08"+MENU_TRENNER+" Adre�-Etiketten Lieferanten"

      @ ob+10 ,li say "09"+MENU_TRENNER+" Nietger�te Nr. Etiketten fortlaufend"
      @ ob+11,li say "10"+MENU_TRENNER+" Av-Etiketten f�r Nietger�te"
      @ ob+12,li say "11"+MENU_TRENNER+" Etiketten f�r Werbegeschenke"

      @ ob+14,li say "12"+MENU_TRENNER+" UPS-Etiketten (Kunden)"
      @ ob+15,li say "13"+MENU_TRENNER+" UPS-Etiketten (Lieferanten)"
      @ ob+17,li say "15"+MENU_TRENNER+" Nietger�te Arbeitsmappe"
      @ ob+18,li say "    Fertigung (Endprodukt) Koffer+Karton"
      @ ob+19,li say "16"+MENU_TRENNER+" Lager-Etiketten"

      // Message("Ihre Auswahl bitte.   @Leer@=Ende")
      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      Versand_Etiketten()
    case akt_Auswahl == 2
      Message:="@�@ndern / @L@�schen  / @D@rucken /  @F12@-@N@eu  /  @K@opieren  /  Ende @(x,ESC)@"
      Set Key K_F5 to highlight()
      aend("Etikett",Message)
      SetKey( K_F5, NIL )
    case akt_Auswahl == 3
      Eti_Av()
    case akt_Auswahl == 4
      // Eti_Repa()
    case akt_Auswahl == 5
      Eti_Adress(ETI_OHNE_KUNDNR)
    case akt_Auswahl == 6
      Eti_Adress(ETI_MIT_KUNDNR) // Ausdruck mit Kundenr.
    case akt_Auswahl == 7
      Eti_Adress(ETI_MIT_PALANZ) // Ausdruck ohne Kundenr. aber mit Pal
    case akt_Auswahl == 8
      Eti_Adr_Lief()
    case akt_Auswahl == 9
      Eti_Typ()
    case akt_Auswahl == 10
      Eti_Typ2()
    case akt_Auswahl == 11
      Werbe_Menu( right(Auswahl,len(Auswahl)-3) )
    case akt_Auswahl == 12
      Eti_UPSKd()
    case akt_Auswahl == 13
      UPS_Lieferanten()
    case akt_Auswahl == 15
      Message:="@�@ndern / @L@�schen  / @D@rucken /  @F12@-@N@eu  /  @K@opieren  /  Ende @(x,ESC)@"
      Set Key K_F5 to highlight()
      aend("EtiRepa",Message)
      SetKey( K_F5, NIL )
    case akt_Auswahl == 16
      Eti_Lager()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

    // setze Etiketten Anzeige aus
    eti_Show({ || .t.})


  ENDDO

  /** disable F8*/
  set key K_F8 to

RETURN
/* EOP Eti_Menu */



/* 
* Phoenix/Ph�nix Listen etc.
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Phoenix_Menu(Auswahl)
LOCAL Tiefe:=2 // wieviele Menus darunter(einschl. akt)
LOCAL li:=20 , ob:=3 , re:=65 , unt:=23
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}
  default Auswahl:=space(10)

  /** enable F8 -> show Etikett on screen */
  SetKey( K_F8 , {|| eti_show() } )

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("P H O E N I X -  L I S T E N, etc.")
      @ ob-1,li-2 to unt,re

      @ ob, li say "Listen:" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Artikel Preise f. Miki"
      @ ob+2, li say "02"+MENU_TRENNER+" Artikel Preise f. Ph�nix"
      @ ob+3 ,li say "03"+MENU_TRENNER+" Versandpauschalen"
      @ ob+4 ,li say "04"+MENU_TRENNER+" Karton vs. Palette"
      @ ob+5 ,li say "05"+MENU_TRENNER+" Excel-Datei Abgleich"

      @ ob+7 ,li say "06"+MENU_TRENNER+" Verkauft / Marge  (intern)"
      @ ob+8 ,li say "07"+MENU_TRENNER+" Verkaufte Artikel (extern)"
      @ ob+9 ,li say "08"+MENU_TRENNER+" Umsatz pro Jahr"
      @ ob+10 ,li say "09"+MENU_TRENNER+" Verkauft / Jahr / Land"

      @ ob+12,li say "Sonstige:" color COLINV
      @ ob+13,li say "10"+MENU_TRENNER+" Ph�nix Preise anpassen"
      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      PhoenixArtikelPreisListe(.t.)
    case akt_Auswahl == 2
      PhoenixArtikelPreisListe(.f.)
    case akt_Auswahl == 3
      PhoenixVersandPreisListe()
    case akt_Auswahl == 4
      PhoenixKartonVsPalette()
    case akt_Auswahl == 5
      PhoenixExcelDatei()
    case akt_Auswahl == 6
      PhoenixIntVerkauft()
    case akt_Auswahl == 7
      PhoenixExtVerkauft()
    case akt_Auswahl == 8
      PhoenixUmsatz()
    case akt_Auswahl == 9
      PhoenixVerkauftProLand()
    case akt_Auswahl == 10
      PhoenixPreisAenderung()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

    // setze Etiketten Anzeige aus
    eti_Show({ || .t.})


  ENDDO

  /** disable F8*/
  set key K_F8 to

RETURN
/* EOP Eti_Menu */




/* Procedure Mat_Menu   *****************************************
*
* Material-Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Mat_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=18 , ob:=3 , re:=62 , unt:=22
LOCAL akt_Auswahl:=-1 , M_Pass:=space(len(MASTER_PASS))
LOCAL GetList:={}

  cls
  titel("M A T E R I A L  -  B E D A R F")

  /* Auftrags-Bestand komplett neu kalkulieren */
  // if ! TEST_PROG .and. message("Auftrags-Bestand neu berechnen ?  ( J / N )","JN")=="J"
  // AufBestand()
  // endif

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("M A T E R I A L  -  B E D A R F")
      @ ob-2,li-2 to unt,re

      @ ob-1, li say "Manuell:" color COLINV
      @ ob, li say "01"+MENU_TRENNER+" Bedarfsdatei bearbeiten"
      //@ ob+2 ,li say "02"+MENU_TRENNER+" Bedarfsdatei nach Mat-Kz."

      //@ ob+3 ,li say "03"+MENU_TRENNER+" Material-Bedarfs-Liste (alt)"
      @ ob+2 ,li say "03"+MENU_TRENNER+" Material-Bedarfs-Liste (Achse Zeit)"
      @ ob+3 ,li say "04"+MENU_TRENNER+" Material-Bedarfs-Liste (Server -> lokal)"

      @ ob+5 ,li say "Bedarfs-Liste (man. Reihenfolge)"
      @ ob+6 ,li say "05"+MENU_TRENNER+" mit  Gesamt-Auftragsbestand"
      @ ob+7 ,li say "06"+MENU_TRENNER+" ohne Gesamt-Auftragsbestand"

      @ ob+9,li say "08"+MENU_TRENNER+" aktueller Auftragsbestand (0 Wochen)"


      @ ob+11,li say "nach Kalenderwoche" color COLINV
      @ ob+12,li say "11"+MENU_TRENNER+" Bedarfsdatei bearbeiten"
      @ ob+13,li say "12"+MENU_TRENNER+" Bedarfsdatei nach Mat-Kz. (Lieferwoche)"
      // @ ob+11,li say "13"+MENU_TRENNER+" Bedarfsdatei nach Mat-Kz. (Fert.-woche)"

      @ ob+15,li say "14"+MENU_TRENNER+" Bedarfs-Liste (sort. nach Artikel)"
      @ ob+16,li say "15"+MENU_TRENNER+" Bedarfs-Liste (manuelle Reihenfolge)"

      @ ob+18,li say "20"+MENU_TRENNER+" Material in welchem Auftrag"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      Mat_erfassen()
    case akt_Auswahl == 2
      // Mat_MatKz()
    case akt_Auswahl == 3
      //Mat_LiRekurs()
      MaterialBedarfsListe()
    case akt_Auswahl == 4
      serverMaterialBedarfsListe()
    case akt_Auswahl == 5
      Mat_LiMan(.t.)
    case akt_Auswahl == 6
      Mat_LiMan(.f.)

    case akt_Auswahl == 8
      MatBedarfAktuell()

    case akt_Auswahl == 11
      Mat2_erfassen()
    case akt_Auswahl == 12
      Mat2_Kz() // nach lIEF.KW
    case akt_Auswahl == 13
      // Mat2_InnerKz() // nach Fert.KW
    case akt_Auswahl == 14
      MatKWList()
    case akt_Auswahl == 15
      Mat_KWMan()

    case akt_Auswahl == 20
      MatAuftrag()

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Mat_Menu */

/* Procedure EinAus_Menu   *****************************************
*
* Material-Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE EinAus_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=22 , ob:=6 , re:=58 , unt:=20
LOCAL akt_Auswahl:=-1 , M_Pass:=space(len(MASTER_PASS))
LOCAL GetList:={}


  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("MATERIAL - Ein-/Ausgang")
      @ ob-2,li-2 to unt,re

      @ ob, li say "Wareneingang" color COLINV
      @ ob+1 ,li say "01"+MENU_TRENNER+" Fertigmeldung (Miki)"
      @ ob+2 ,li say "02"+MENU_TRENNER+" Fremd-Material      "
      @ ob+3 ,li say "03"+MENU_TRENNER+" K-Lager/Beistellteil"

      @ ob+5 ,li say "04"+MENU_TRENNER+" Werkzeug Eingang (intern)"
      @ ob+6 ,li say "05"+MENU_TRENNER+" Werkzeug Eingang (extern)"

      @ ob+8 ,li say "09"+MENU_TRENNER+" Fertigmeldung (Storno)"

      @ ob+11 ,li say "Warenausgang" color COLINV
      @ ob+12 ,li say "11"+MENU_TRENNER+" Miki-Material"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      Av_Mateing() // Fertigmeldung
    case akt_Auswahl == 2
      Av_Fremd() // Fremd-Material
    case akt_Auswahl == 3
      Av_KFremd() // Fremd-Material KLager intern
    case akt_Auswahl == 4
      Av_Mateing(.t.) // Werkzeug Eingang intern
    case akt_Auswahl == 5
      Av_Fremd(.t.) // Werkzeug Eingang extern
    case akt_Auswahl == 9
      Av_MateingStorno() // Storno Fertigmeldung

    case akt_Auswahl == 11
      Av_MatAusg() // MatAusgang: Miki

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP EiNAus_Menu */



/* Procedure Best_Menu   *****************************************
*
* Bestellungs- Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Best_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=20 , ob:=6 , re:=60 , unt:=18
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("B E S T E L L U N G E N")
      @ ob-2,li-2 to unt,re

      @ ob, li say "01"+MENU_TRENNER+" Bestellung   erfassen/drucken"
      @ ob+1, li say "02"+MENU_TRENNER+" Preisanfrage erfassen/drucken"
      // @ ob+3, li say "07"+MENU_TRENNER+" Wareneingangs-Kontrolle    "
      @ ob+4, li say "08"+MENU_TRENNER+" Bestell�berwachung         "
      @ ob+5, li say "09"+MENU_TRENNER+" Offene Bestellungen        "

      @ ob+8, li say "10"+MENU_TRENNER+" Bestellungen         erledigt"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      Best_erfassen()
    case akt_Auswahl == 2
      Best_erfassen(.t.)
    case akt_Auswahl == 7
      // We_Kontrolle()
    case akt_Auswahl == 8
      Best_Plan()
    case akt_Auswahl == 9
      BestellListe()
    case akt_Auswahl == 10
      BestErledigt()
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Best_Menu */


/* Procedure Fakt_Menu   *****************************************
*
* Fakturierungs- Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Fakt_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li , ob , unt , re:=60
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      DispBegin()
      cls
      titel("F A K T U R I E R U N G")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=2 ; unt:=23 ; re:=38; ob:=3
      @ ob-1,li-1 to unt,re
      @ ob-1, li say "Standard" color COLINV
      @ ob , li say "01"+MENU_TRENNER+" Auftrag         erfassen/drucken"
      @ ob+1, li say "02"+MENU_TRENNER+" Angebot         erfassen/drucken"
      @ ob+2, li say "03"+MENU_TRENNER+" Rechnung/Lieferung     freigeben"
      @ ob+3, li say "04"+MENU_TRENNER+" Rechnungs-Druck      wiederholen"
      @ ob+4, li say "05"+MENU_TRENNER+" Rechnung              stornieren"
      @ ob+5, li say "06"+MENU_TRENNER+" Gutschrift      erfassen/drucken"

      // @ ob+7, li say "07"+MENU_TRENNER+" Ausfallmuster          freigeben"
      @ ob+7, li say "07"+MENU_TRENNER+" Hand-Lieferschein       erfassen"
      @ ob+8 ,li say "08"+MENU_TRENNER+" Kostenvoranschlag       erfassen"
      @ ob+9 ,li say "09"+MENU_TRENNER+" Spedition Abholauftrag  erfassen"

      @ ob+11,li say "10"+MENU_TRENNER+" Rahmen-Auftrag Artikel  erfassen"
      @ ob+12,li say "11"+MENU_TRENNER+" Rahmen-Auftrag Budget   erfassen"
      @ ob+13,li say "12"+MENU_TRENNER+" Rahmen-Auftr�ge    kontrollieren"
      @ ob+14,li say "13"+MENU_TRENNER+" Abruf-Auftr�ge          erfassen"
      @ ob+15,li say "14"+MENU_TRENNER+" Rep.-Auftrag (WABCO/Budget) erf."
      @ ob+16,li say "15"+MENU_TRENNER+" Auftrag/Gutschrift/KV   erledigt"
      @ ob+17,li say "16"+MENU_TRENNER+" GelangensBescheinigung  erhalten"
      @ ob+18,li say "17"+MENU_TRENNER+" Gelang.Besch. Rechnungen drucken"
      @ ob+19,li say "18"+MENU_TRENNER+" Pro-Forma-Rechnung       drucken"

      /* 2"+MENU_TRENNER+" Quadrant */
      li:=42 ; re:=78 ; unt:=15
      @ ob-1,li-1 to unt,re
      @ ob-1, li say "K-Lager" color COLINV
      @ ob ,li say "21"+MENU_TRENNER+" K-Lager Auftrag erfassen/drucken"
      @ ob+1,li say "22"+MENU_TRENNER+" K-Lager Lieferung      freigeben"
      @ ob+2,li say "23"+MENU_TRENNER+" K-Lager Lieferschein wiederholen"
      @ ob+3,li say "24"+MENU_TRENNER+" K-Lager Lieferschein  stornieren"
      @ ob+4,li say "25"+MENU_TRENNER+" K-Lager Sammelrechnung   drucken"
      @ ob+5,li say "26"+MENU_TRENNER+" K-Lager Sammelrechn.  stornieren"

      // @ ob+10,li say "27"+MENU_TRENNER+" K-Lager Lieferung  kontrollieren"
      @ ob+7 ,li say "28"+MENU_TRENNER+" K-Lager Auftrag         erledigt"
      @ ob+8 ,li say "29"+MENU_TRENNER+" K-Lager Best.Nr.   kontrollieren"
      @ ob+9 ,li say "30"+MENU_TRENNER+" K-Lager Gutschrift      erfassen"
      @ ob+10,li say "31"+MENU_TRENNER+" K-Lager Gutschrift    stornieren"
      @ ob+11,li say "32"+MENU_TRENNER+" K-Lager intern     R�cklieferung"

      /* 3"+MENU_TRENNER+" Quadrant */
      li:=42 ; re:=78 ; unt:=23 ; ob:=17
      @ ob-1,li-1 to unt,re
      @ ob-1, li say "Sonstige" color COLINV
      @ ob+0 ,li say "40"+MENU_TRENNER+" Zahlungseingang           buchen"
      @ ob+1 ,li say "41"+MENU_TRENNER+" Langzeitlieferantenerkl�rung"
      @ ob+2 ,li say "42"+MENU_TRENNER+" Intra-Stat. Datei     bearbeiten"
      @ ob+3 ,li say "43"+MENU_TRENNER+" Rechnungsdaten            �ndern"

      DispEnd()

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case

      /** Standard */
    case akt_Auswahl == 1
      Auf_erfassen("R") // Auftrag !
    case akt_Auswahl == 2
      Ang_erfassen() // Angebot
    case akt_Auswahl == 3
      Rech_frei("S") // Standard-Rechnung, kein Ausfallmuster oder
      // K-Lager
    case akt_Auswahl == 4
      Rech_Druckwieder()
    case akt_Auswahl == 5
      Rech_Storno()
    case akt_Auswahl == 6
      Auf_erfassen("G") // Gutschrift !

    case akt_Auswahl == 7
      LiefErfassen() // Hand-Lieferschein
    case akt_Auswahl == 8
      Auf_erfassen("V") // Kostenvoranschlag
    case akt_Auswahl == 9
      SpeditAuftragErfassen()

    case akt_Auswahl == 10
      Auf_erfassen("D") // Rahmenvertrag Artikel
    case akt_Auswahl == 11
      Auf_erfassen("B") // Rahmenvertrag Budget
    case akt_Auswahl == 12
      RahmenABListe()
    case akt_Auswahl == 13
      Auf_erfassen("R","D") // Abruf-Auftrag == Dispositions Auftrag (Rahmenauftrag - Artikel)

    case akt_Auswahl == 14
      Auf_erfassen("R","B") // Abruf-Auftrag Budget = Reparatur Wabco, lt. H. Weiland 24.10.16

    case akt_Auswahl == 15
      Auf_erledigt("GRVBD ") // Auftr�e erledigt
    case akt_Auswahl == 16
      GelangEingang()
    case akt_Auswahl == 17
      GelangRechnDruck()
    case akt_Auswahl == 18
      ProFormaErfassen()

    case akt_Auswahl == 12
    case akt_Auswahl == 13

      /** K-Lager */
    case akt_Auswahl == 21
      Auf_erfassen("K") // K-Lager Auftrag !
    case akt_Auswahl == 22
      Rech_frei("K") // K-Lager
    case akt_Auswahl == 23
      KonsigLSwiederholen()
    case akt_Auswahl == 24
      KonsigLSStorno()
    case akt_Auswahl == 25
      KonsigSammelRechnung()
    case akt_Auswahl == 26
      KStornoRechnung()
    case akt_Auswahl == 27
      // nop
    case akt_Auswahl == 28
      Auf_erledigt("K") // Auftr�e l�schen
    case akt_Auswahl == 29
      HonselBestNr()
    case akt_Auswahl == 30
      KGutschrift()
    case akt_Auswahl == 31
      KGutStorno()
    case akt_Auswahl == 32
      LiefErfassen() // Hand-Lieferschein = K-Lager intern R�cklieferung

      /** Zahlungen */
    case akt_Auswahl == 40
      RechAuswahl()
    case akt_Auswahl == 41
      Langzeitlieferantenerkl()
    case akt_Auswahl == 42
      IntraStatEdit()
    case akt_Auswahl == 43
      RechAdrAendern()

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Fakt_Menu */


/* Procedure Av_Menu   *****************************************
*
* Arbeitsvorbereitung- Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Av_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li, ob, re, unt
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("A R B E I T S - V O R B E R E I T U N G")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=2 ; ob:=3 ; re:=30 ; unt:=15
      @ ob, li say "Interne Auftr�ge" color COLINV
      // if getUser():mayCreateInnerOrders
      // @ ob+2 ,li say "01"+MENU_TRENNER+" Int. Bestellvorschl�ge   erfassen"
      // endif
      // @ ob+3 ,li say "02"+MENU_TRENNER+" Auftr�ge (MIKI)  erfassen/drucken"
      if getUser():mayCreateInnerOrders
        @ ob+2, li say "01"+MENU_TRENNER+" Auftr�ge               erfassen"
        @ ob+3, li say "02"+MENU_TRENNER+" Auftrags-Vorschl�ge  �bernehmen"

        @ ob+5 ,li say "04"+MENU_TRENNER+" Auftr�ge (aktive)    bearbeiten"
        @ ob+6 ,li say "05"+MENU_TRENNER+" Auftr�ge (alle)      bearbeiten"
        @ ob+7 ,li say "06"+MENU_TRENNER+" Auftr�ge als erledigt markieren"
        @ ob+9 ,li say "08"+MENU_TRENNER+" Freie Nummern          anzeigen"
        @ ob+10,li say "09"+MENU_TRENNER+" Alte Auftr�ge          anzeigen"
      endif

      /* 2"+MENU_TRENNER+" Quadrant */
      li:=42 ; ob:=3 ; re:=78 ; unt:=15
      @ ob, li say "St�cklisten" color COLINV
      @ ob+2 ,li say "11"+MENU_TRENNER+" Werkzeug  bearbeiten"
      @ ob+3 ,li say "12"+MENU_TRENNER+" Material  bearbeiten"
      @ ob+4 ,li say "13"+MENU_TRENNER+" Maschinen / Zeiten  "
      @ ob+5 ,li say "14"+MENU_TRENNER+" Instrukt. bearbeiten"
      if getUser():mayEditData
        @ ob+7 ,li say "15"+MENU_TRENNER+" St�ckliste  l�schen"
      endif
      @ ob+8 ,li say "16"+MENU_TRENNER+" St�cklisten drucken"
      @ ob+10,li say "17"+MENU_TRENNER+" Artikel-Stammdaten"

      // /* 3"+MENU_TRENNER+" Quadrant */
      // li:=2 ; ob:=15; re:=30 ; unt:=23
      // if (DEVEL_PROG .or. TEST_PROG) .and. getUser():mayCreateInnerOrders .and. getUser():mayEditData
      // @ ob, li say "NEU: Nach-Kalkulation (Test)" color COLINV
      // @ ob+1 ,li say "21"+MENU_TRENNER+" Nachkalkulation"
      // endif

      /* 4"+MENU_TRENNER+" Quadrant */
      if getUser():mayCreateInnerOrders .and. getUser():mayEditData
        ob:=16 ; li:=42 ; re:=79 ; unt:=22
        @ ob, li say "Nach-Kalkulation" color COLINV
        @ ob+1, li say "31"+MENU_TRENNER+" Nachkalkulation erfassen/�ndern"

        if getUser():id $ KURZEL_MIKI_GF+"/" + KURZEL_DEVEL .and. hasTodosNachkalk()
          @ ob+3, li say "32"+MENU_TRENNER+" Nachkalkulation �berpr�fen" color "R/"+getBackColor()
        endif

      endif

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif
    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case

      /* Innerbetr. Auftr�ge */
    case akt_Auswahl == 1 .and. getUser():mayCreateInnerOrders
      Av_Auf_Erfass(INNER_MIKI)

    case akt_Auswahl == 2 .and. getUser():mayCreateInnerOrders
      showTodosMatBedarf()

    case akt_Auswahl == 4
      InnerEdit(.f.)
    case akt_Auswahl == 5 .and. getUser():mayCreateInnerOrders
      InnerEdit(.t.)
    case akt_Auswahl == 6 .and. getUser():mayCreateInnerOrders
      InnerDelete()
    case akt_Auswahl == 8 .and. getUser():mayCreateInnerOrders
      FreieInnerNrList()
    case akt_Auswahl == 9 .and. getUser():mayCreateInnerOrders
      AlteInnerList()

      /* St�cklisten */
    case akt_Auswahl == 11
      Stk_Liste("W") // Werkzeug
    case akt_Auswahl == 12
      Stk_Liste("M") // Material
    case akt_Auswahl == 13
      Stk_Liste("V") // Zeiten / Maschinen
    case akt_Auswahl == 14
      Stk_Liste("I") // Instruktionen
    case akt_Auswahl == 15 .and. getUser():mayEditData
      Stk_loeschen() // St�ckliste l�schen
    case akt_Auswahl == 16
      Av_Auf_Erfass(INNER_STK)

    case akt_Auswahl == 17
      ArtikelAendern()


      /* Nachkalkulation */
    case akt_Auswahl == 31
      if getUser():mayCreateInnerOrders .and. getUser():mayEditData
        nachkalkerf()
      endif
    case akt_Auswahl == 32
      if getUser():id $ KURZEL_MIKI_GF+"/" + KURZEL_DEVEL .and. hasTodosNachkalk()
        showTodosNachkalk()
      endif

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Av_Menu */


/*
* Auskunfts-Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Aus_Menu(Auswahl,gesperrt,starte_bei)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=22 , ob:=3 , re:=59 , unt:=20
LOCAL akt_Auswahl:=-1
LOCAL Message:=""
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /* im Lager 3 vorschlagen */
      if starte_bei="9"
        keyboard "3"+chr(K_HOME)
      endif

      /**** lokales Menu anzeigen ****/
      cls
      titel("A U S K U N F T")
      @ ob-1,li-2 to unt,re

      if (getUser():mayEditData .or. getUser():mayEditTool .or. getUser():mayEditStock)
        @ ob, li say "01"+MENU_TRENNER+" Artikel �ndern"
      endif
      // if ! "02"$gesperrt
      // @ ob+1, li say "02"+MENU_TRENNER+" Rep. nach Ger�te-Nr."
      // endif
      if ! "03"$gesperrt
        @ ob+2, li say "03"+MENU_TRENNER+" Artikel-Liste"
      endif
      if ! "04"$gesperrt
        @ ob+3, li say "04"+MENU_TRENNER+" St�ckliste (Werkzeug)"
      endif
      if ! "05"$gesperrt
        @ ob+4, li say "05"+MENU_TRENNER+" St�ckliste (Material)"
      endif
      if ! "06"$gesperrt
        @ ob+6 ,li say "06"+MENU_TRENNER+" Material in welcher St�ckliste"
      endif
      if ! "07"$gesperrt
        @ ob+7 ,li say "07"+MENU_TRENNER+" Werkzeug in welcher St�ckliste"
      endif
      if ! "08"$gesperrt
        @ ob+8 ,li say "08"+MENU_TRENNER+" Artikel - Honsel Nr."
      endif

      if ! "10"$gesperrt
        @ ob+10 ,li say "10"+MENU_TRENNER+" Bewegungsdatei"
      endif

      if getUser():mayEnterMateinausg
        @ ob+11,li say "11"+MENU_TRENNER+" Material Ein-/Ausgang"
      endif
      if getUser():mayEditStock
        @ ob+12,li say "12"+MENU_TRENNER+" Artikel Lager-Bestand/Ort �ndern"
      endif
      if getUser():mayPrint .or. getUser():mayPrintLabel
        @ ob+13,li say "13"+MENU_TRENNER+" Etiketten drucken"
      endif
      if getUser():mayPrint .or. getUser():mayEnterMatMenu
        @ ob+14,li say "14"+MENU_TRENNER+" Material-Bedarf"
      endif

      // special case BB FIXME => make more generic
      if getUser():id == "BB"
        @ ob+16,li say "16"+MENU_TRENNER+" Lieferliste"
      endif
      // if getUser():mayEnterNietGerat
      // @ ob+16,li say "15"+MENU_TRENNER+" Nietger�te Produktion"
      // endif

      // if getUser():mayCreateInnerOrders
      // @ ob+15,li say "15"+MENU_TRENNER+" Bestellvorschl�ge erfassen"
      // endif



      AUSWAHL_EINGABE
      if starte_bei="9"
        Message("Ihre Auswahl bitte.   @99@=Ende")
      else
        Message("Ihre Auswahl bitte.    @ESC@=Ende")
      endif

      menuRead(@GetList)
    endif

    if alltrim(Auswahl) $ gesperrt .or. (lastkey()==K_RBUTTONDOWN .and. starte_bei=="9")
      akt_Auswahl:=-1
      Auswahl:=space(AUSWAHL_LAENGE)
      loop
    endif

    /* Esc=Ende */
    if ( lastkey()==K_ESC .or. lastkey()==K_RBUTTONDOWN ) .and. starte_bei<>"9"
      akt_Auswahl:=0
      loop
    endif

    // if ! empty(Auswahl)
    akt_Auswahl:=getAuswahl(Auswahl)
    // endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      if (getUser():mayEditData .or. getUser():mayEditTool)
        ArtikelAendern()
      elseif getUser():mayEditStock
        ArtikelAendern({"ARTIKEL->LG_Raum","ARTIKEL->LG_Regal","ARTIKEL->LG_Fach","ARTIKEL->LG_Te"+;
          "xt","ARTIKEL->LAGEBEST"})
      endif

    case akt_Auswahl == 2
      // Repa_Typ()
    case akt_Auswahl == 3 .and. ! "03"$gesperrt
      Repa_Artikel_Auskunft()
    case akt_Auswahl == 4 .and. ! "04"$gesperrt
      Stk_Liste("W")
    case akt_Auswahl == 5 .and. ! "05"$gesperrt
      Niet_Stk_Liste()
    case akt_Auswahl == 6 .and. ! "06"$gesperrt
      MatArtikelListe("M")
    case akt_Auswahl == 7 .and. ! "07"$gesperrt
      MatArtikelListe("W")
    case akt_Auswahl == 8 .and. ! "08"$gesperrt
      Hilfe( "HONSELARTIKEL",getNew(),"" )
    case akt_Auswahl == 10 .and. ! "10"$gesperrt
      WarausList("BS")

    case akt_Auswahl == 11 .and. getUser():mayEnterMateinausg
      EinAus_Menu( space(3) )

    case akt_Auswahl == 12 .and. getUser():mayEditStock
      ArtikelAendern({"ARTIKEL->LG_Raum","ARTIKEL->LG_Regal","ARTIKEL->LG_Fach","ARTIKEL->LG_Text",;
        "ARTIKEL->LAGEBEST"})

    case akt_Auswahl == 13 .and. (getUser():mayPrint .or. getUser():mayPrintLabel)       /* etiketten */
      Eti_Menu(right(Auswahl,len(Auswahl)-3))
    case akt_Auswahl == 14 .and. getUser():mayEnterMatMenu       /* Mat.Bedarf */
      Mat_Menu( right(Auswahl,len(Auswahl)-3) )

    case akt_Auswahl == 16 .and. getUser():id == "BB" // FIXME: special case Berger => make more generic
      Lieferliste()

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)
    M->SpecialZeige:=NIL

  enddo

RETURN
/* EOP Aus_Menu */



/* Procedure Werbe_Menu   *****************************************
*
* Etiketten-Listen f�r Werbegeschenke
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Werbe_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=25 , ob:=5 , re:=55 , unt:=21
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}
  default Auswahl:="  "

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("W E R B E G E S C H E N K E")
      @ ob-2,li-4 to unt,re

      @ ob ,li say "Listen:"
      @ ob+1, li say "============="
      @ ob+2 ,li say "01"+MENU_TRENNER+" Wein"
      @ ob+3 ,li say "02"+MENU_TRENNER+" Tisch-Kalender"
      @ ob+4 ,li say "03"+MENU_TRENNER+" Wand -Kalender"
      @ ob+5 ,li say "04"+MENU_TRENNER+" Sonstiges"
      @ ob+6 ,li say "05"+MENU_TRENNER+" Komplett"

      @ ob+8 ,li say "Etiketten"
      @ ob+9, li say "============="
      @ ob+10,li say "10"+MENU_TRENNER+" Wein"
      @ ob+11,li say "11"+MENU_TRENNER+" Tisch-Kalender"
      @ ob+12,li say "12"+MENU_TRENNER+" Wand -Kalender"
      @ ob+13,li say "13"+MENU_TRENNER+" Sonstiges "

      // Message("Ihre Auswahl bitte.   @Leer@=Ende")
      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      Werbe_Liste("WERBUNG->Geschenk1","Wein")
    case akt_Auswahl == 2
      Werbe_Liste("WERBUNG->Geschenk2","Tisch-Kalender")
    case akt_Auswahl == 3
      Werbe_Liste("WERBUNG->Geschenk3","Wein-Kalender")
    case akt_Auswahl == 4
      Werbe_Liste("WERBUNG->Geschenk4","Sonstiges")
    case akt_Auswahl == 5
      Werbe_kompl()

    case akt_Auswahl == 10
      Eti_Schmal_Werbe("WERBUNG->Geschenk1")
    case akt_Auswahl == 11
      Eti_Werbe("WERBUNG->Geschenk2")
    case akt_Auswahl == 12
      Eti_Werbe("WERBUNG->Geschenk3")
    case akt_Auswahl == 13
      Eti_Werbe("WERBUNG->Geschenk4")
    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Eti_Menu */

/* Procedure Bank_Menu   *****************************************
*
* Fakturierungs- Menu
* Parameters: evtl. Vorauswahl
*/
PROCEDURE Bank_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=18 , ob:=3 , re:=62 , unt:=20
LOCAL akt_Auswahl:=-1
LOCAL GetList:={}

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("B A N K ")
      @ ob-1,li-2 to unt,re

      @ ob , li say "01"+MENU_TRENNER+" Schecks       erfassen/drucken"
      @ ob+1, li say "02"+MENU_TRENNER+" �berweisungen erfassen/drucken"

      // @ ob+4, li say "03"+MENU_TRENNER+" Zahlungseing�nge buchen/�ndern"
      @ ob+3, li say "05"+MENU_TRENNER+" Kontobewegungen drucken"

      // @ ob+8, li say "07"+MENU_TRENNER+" Monatsabschlu�"

      @ ob+5, li to ob+5,re-2
      @ ob+6, li say "10"+MENU_TRENNER+" Bankenstamm   �ndern"
      @ ob+7, li say "11"+MENU_TRENNER+" Hausbanken    �ndern"
      @ ob+8, li say "12"+MENU_TRENNER+" Lieferanten   �ndern"
      @ ob+9, li say "13"+MENU_TRENNER+" Kunden        �ndern"

      @ ob+11, li to ob+11,re-2
      @ ob+12, li say "20"+MENU_TRENNER+" SEPA �berweisungen   erfassen"
      @ ob+13, li say "21"+MENU_TRENNER+" SEPA XML Datei pr�fen/drucken"
      @ ob+14, li say "22"+MENU_TRENNER+" SEPA XML Datei         �ndern"
      @ ob+15, li say "23"+MENU_TRENNER+" SEPA Verzeichnis       �ffnen"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif

    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 1
      ScheckErfassen()
    case akt_Auswahl == 2
      UeberErfassen()
    case akt_Auswahl == 3
      // ZahlEingang()
    case akt_Auswahl == 5
      KtoListe()
    case akt_Auswahl == 7
      // MonatsAbschluss()

    case akt_Auswahl == 10
      if open( "BankStam" , "Land")
        select BankStam
        aend("BankStam",,,,,,.f.)
      endif
    case akt_Auswahl == 11
      aend("Hausbank")
    case akt_Auswahl == 12
      aend("Lieferan","@�@ndern @B@estellk. @L@�schen @F3@=Artikel @F9@=off.Best. @F12@ @N@eu "+;
        "@K@opieren Ende @(x,ESC)@")
    case akt_Auswahl == 13
      KundenAendern()

    case akt_Auswahl == 20
      UeberErfassen(.t.)
    case akt_Auswahl == 21
      SepaFileCheck(NIL)
    case akt_Auswahl == 22
      editSepa()
    case akt_Auswahl == 23
      // �ffne Verzeichnis
      wapi_SHELLEXECUTE( 0, "open", SEPA_PFAD)

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP Bank_Menu */

/* Procedure KLag_Menu
*
* Stamm-Daten-Menu
*
* Parameters: evtl. Vorauswahl
*/
PROCEDURE KLag_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=18 , ob:=4 , re:=62 , unt:=18
LOCAL GetList:={}
LOCAL akt_Auswahl:=-1
LOCAL Alt_Message:=""
  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    Auswahl:=left(Auswahl,AUSWAHL_LAENGE)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("K-Lager Stammdaten")
      @ ob-1,li-2 to unt,re

      @ ob-1,li say "Unterj�hrig" color COLINV

      @ ob+1,li say "10"+MENU_TRENNER+" K-Lager extern erh�hen"
      @ ob+2,li say "11"+MENU_TRENNER+" K-Lager extern mindern"
      @ ob+3,li say "    Honsel-Bestand R�cklieferung"

      @ ob+5,li say "12"+MENU_TRENNER+" K-Lager-Bestand intern   �ndern"
      @ ob+6,li say "13"+MENU_TRENNER+" Beistellteile intern Art �ndern"

      @ ob+8,li say "15"+MENU_TRENNER+" Honsel VK Datei einlesen (alt)"
      @ ob+9,li say "16"+MENU_TRENNER+" Honsel VK (ehem. Beistellteile) einlesen"

      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif
    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case

    case akt_Auswahl == 10
      KExternErhoehen()
    case akt_Auswahl == 11
      KRueckLieferung()
    case akt_Auswahl == 12
      KInternAendern()
    case akt_Auswahl == 13
      KBeistEkArtikel()

    case akt_Auswahl == 15
      honselVKEinles()
    case akt_Auswahl == 16
      honselBeiEKEinles()

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP KLag_Menu */

/* Procedure dev_Menu  / devel_menu
*
* System-Daten-Menu (nur f�r mich)
*
* Parameters: evtl. Vorauswahl
*/
PROCEDURE dev_Menu(Auswahl)
LOCAL Tiefe:=1 // wieviele Menus darunter(einschl. akt)
LOCAL li:=16 , ob:=2 , re:=64 , unt:=22
LOCAL GetList:={}
LOCAL akt_Auswahl:=-1,zeile:=0

  do while ! ( akt_Auswahl=99 .or. akt_Auswahl==0 )

    // Auswahl:=left(Auswahl,AUSWAHL_LAENGE)
    Auswahl:=space(2)

    if empty(left(auswahl,2))

      /**** lokales Menu anzeigen ****/
      cls
      titel("Devel Sys-Menu")

      /* 1"+MENU_TRENNER+" Quadrant */
      li:=5 ; ob:=2 ; re:=30 ; unt:=15
      @ ob, li say "Devel" color COLINV
      @ ob+1 , li say "01"+MENU_TRENNER_DISABLED+" L�schen von Dateien" // dbase zap taugt nicht !
      @ ob+2 ,li say "02"+MENU_TRENNER_DISABLED+" Memory Anzeige"
      @ ob+3 ,li say "03"+MENU_TRENNER_DISABLED+" DBF Struktur Export -> doku.asc"
      @ ob+4 ,li say "04"+MENU_TRENNER_DISABLED+" Datei exportieren"
      @ ob+5 ,li say "05"+MENU_TRENNER_DISABLED+" Force Shutdown"
      @ ob+6 ,li say "06"+MENU_TRENNER_DISABLED+" Service (House-Keeping)"
      @ ob+7 ,li say "07"+MENU_TRENNER_DISABLED+" ASCII Tabelle ausgeben"
      @ ob+8 ,li say "08"+MENU_TRENNER_DISABLED+" Print Devel Info"
      @ ob+9 ,li say "09"+MENU_TRENNER_DISABLED+" Restore Screenshot"
      @ ob+10,li say "10"+MENU_TRENNER_DISABLED+" Config Paramter ausgeben"
      @ ob+11,li say "11"+MENU_TRENNER_DISABLED+" Config Datei einlesen"
      @ ob+12,li say "12"+MENU_TRENNER_DISABLED+" Reorganisation"
      @ ob+13,li say "13"+MENU_TRENNER_DISABLED+" Fenster-Position speichern"
      @ ob+14,li say "14"+MENU_TRENNER_DISABLED+" Crontab Cleanup (danach)"
      @ ob+15,li say "15"+MENU_TRENNER_DISABLED+" Crontab markieren"
      @ ob+16,li say "16"+MENU_TRENNER_DISABLED+" Alle Logins resetten"
      @ ob+17,li say "17"+MENU_TRENNER_DISABLED+" EMail-Adressen"
      @ ob+18,li say "18"+MENU_TRENNER_DISABLED+" Daten-Backup"
      @ ob+19,li say "19"+MENU_TRENNER_DISABLED+" Temp. dateien l�schen"

      /* 2"+MENU_TRENNER_DISABLED+" Quadrant */
      li:=42 ; ob:=2 ; re:=78 ; unt:=15
      @ ob, li say "Miki" color COLINV
      @ ob+1, li say "21"+MENU_TRENNER_DISABLED+" Email an GS wenn alles ausgeloggt sind"
      @ ob+3, li say "35"+MENU_TRENNER_DISABLED+" Waraus1 KonsCheck - akt. LagBestand"
      @ ob+4, li say "36"+MENU_TRENNER_DISABLED+" Waraus2 KonsCheck - hist.LagBestand"
      @ ob+5, li say "37"+MENU_TRENNER_DISABLED+" K-Lager Konsistenz Pr�fung"
      @ ob+6, li say "38"+MENU_TRENNER_DISABLED+" Inner / AB Konsistenz Check"
      @ ob+7, li say "39"+MENU_TRENNER_DISABLED+" Waraus Gel�schte Artikel"
      @ ob+8 ,li say "40"+MENU_TRENNER_DISABLED+" VK KonsistenzCheck"
      @ ob+9 ,li say "41"+MENU_TRENNER_DISABLED+" Artikel Verkauft Update"
      @ ob+10,li say "42"+MENU_TRENNER_DISABLED+" Ping Remote Service"
      @ ob+11,li say "43"+MENU_TRENNER_DISABLED+" Remote Auftragsbestand berechnen"

      @ ob+13,li say "44"+MENU_TRENNER_DISABLED+" Rechn.Ausgangsbuch t�gl.  - Neu berechnen"
      @ ob+14,li say "45"+MENU_TRENNER_DISABLED+" Mahnstufen berechnen"
      @ ob+15,li say "46"+MENU_TRENNER_DISABLED+" Interne Beistellteile - Korrektur K-Lager"
      @ ob+16,li say "47"+MENU_TRENNER_DISABLED+" Rechaus KonsistenzCheck"
      @ ob+17,li say "48"+MENU_TRENNER_DISABLED+" Remote Server Shutdown"
      @ ob+18,li say "49"+MENU_TRENNER_DISABLED+" Rechnungsausgangsbuch l�schen"
      unt:=21


      AUSWAHL_EINGABE
      menuRead(@GetList)
    endif
    akt_Auswahl:=getAuswahl(Auswahl)

    /* Esc=Ende */
    if lastkey()==K_ESC
      akt_Auswahl:=0
    endif

    protAufruf(akt_auswahl)
    do case
    case akt_Auswahl == 01
      zapFile()
    case akt_Auswahl == 02
      run mem /c
      // swpruncmd("",0,"","")
      wait

      qqout(memory(4))
      wait
    case akt_Auswahl == 03
      DB_DokExp()
      DB_StruExp()
    case akt_Auswahl == 04
      dumpFile(getUser():exportPATH())
    case akt_Auswahl == 05
      cls
      Titel("Manueller Shutdown")
      forceQuit()
    case akt_Auswahl == 06
      HouseKeeping()
    case akt_Auswahl == 07
      AsciiTabelle()
    case akt_Auswahl == 08
      develInfo()
    case akt_Auswahl == 09
      restScreenFromFile()
    case akt_Auswahl == 10
      cls
      Titel("System Properties")
      Drucker("BS")
      dumpProperties()
      Drucker("OFF")
    case akt_Auswahl == 11
      cls
      readProperties(PROPERTIES_FILE,.t.) // liest property file neu
    case akt_Auswahl == 12
      reorg()
    case akt_Auswahl == 13
      logout(.f.)
      init(KURZEL_DEVEL) // Auto-Login Jochen Gruhn
    case akt_Auswahl == 14
      cleanupCrontab()
    case akt_Auswahl == 15
      if Message("Crontab als @e@rledigt oder als @o@ffen markieren?","EO","E") == "E"
        fillCrontab()
      else
        if ! ABBRUCH
          clearCrontab()
        endif
      endif

    case akt_Auswahl == 16
      if DEVEL_PROG .or. TEST_PROG
        LoginDispatcher():new():ResetLogin()
        Message("Done.   @Taste@","@")
      else
        Error("Auf dem Prod.System nicht m�glich!")
      endif

    case akt_Auswahl == 17
      if open("Email","Kunden","kundSped")
        select email
        set rela to EMAIL->KundNr into Kunden
        aend("Email")
        close data
      endif
    case akt_Auswahl == 18
      autoBackupData()
    case akt_Auswahl == 19
      deleteTempFiles()
      Message("Dateien wurden gel�scht.    Bitte @Taste@ dr�cken.","@")


      /** */
    case akt_Auswahl == 21
      set alte to (LAST_LOGOUT_EMAIL)
      set alte on
      set cons off
      qout("Warte bis alle Benutzer ausgeloggt sind.")
      set cons on
      set alte off
      set alte to

      Message("Datei wurde erzeugt.   Bitte @Taste@ dr�cken.","@")

    case akt_Auswahl == 34

    case akt_Auswahl == 35
      Waraus1KonsistenzCheck()
    case akt_Auswahl == 36
      Waraus2KonsistenzCheck()
    case akt_Auswahl == 37
      KKonsistenzCheck()
    case akt_Auswahl == 38
      InnerABKonsistenzCheck()

    case akt_Auswahl == 39
      WarausDelete()

    case akt_Auswahl == 40
      VK_KonsistenzCheck()
    case akt_Auswahl == 41
      ArtVerkauftUpdate()
    case akt_Auswahl == 42
      if pingRemoteService()
        Message("Server ponged.  Bingo.       Bitte @Taste@ dr�cken.","@")
      else
        Message("Server down :(       Bitte @Taste@ dr�cken.","@")
      endif

    case akt_Auswahl == 43
      AufBestand(.t.,.f.,.t. )

    case akt_Auswahl == 44
      RechAus(.f.,.t.,.t.,.t.) // t�gl wiederholen
    case akt_Auswahl == 45
      setAllDuedates()
    case akt_Auswahl == 46
      KLagerInternKorrektur(.f.)
    case akt_Auswahl == 47
      RechausKonsistenzCheck()
    case akt_Auswahl == 48
      set alte to (SERVER_SHUTDOWN_REQUEST)
      set alte on
      set cons off
      qout("Remote Server shutdown request from: " + getUser():id)
      set cons on
      set alte off
      set alte to
      pingRemoteService()
    case akt_Auswahl == 49
      rechausLoesch()

    endcase
    Auswahl:=space(AUSWAHL_LAENGE)

  ENDDO

RETURN
/* EOP KLag_Menu */


/** liefert den num. Wert der aktuellen Auswhal (Eingabe oder Maus-Klick) */
STATIC FUNCTION getAuswahl(Auswahl)
LOCAL akt_Auswahl:=-1,screenValue
LOCAL x,mErg,countSpaces:=0

  // Maus Klick?
  do case
  case lastkey() == K_RBUTTONDOWN
    akt_Auswahl:=0 // Menu beenden
  case lastkey() == K_LBUTTONDOWN
    // finde zugeh. Menu-Auswahl
    x:=mcol()

    // Klick auf Zahl?
    if type(screenValue:=left(screenStr(mrow(),x,1),1))=="N"
      // teste links davon
      if type(screenValue:=left(screenStr(mrow(),x-1,1),1))=="N"
        x++ // positioniere auf MENU_TRENNER
      else
        x+=2 // positioniere auf MENU_TRENNER
      endif
    else // klick auf Text
      do while x>0 .and. !((screenValue:=left(screenStr(mrow(),x,1),1))$MENU_TRENNER+RAHMEN_SENKRECHT) ;
        .and. countSpaces < 5
        if screenValue==" "
          countSpaces++
        else
          countSpaces:=0
        endif
        x--
      enddo
    endif
    if x>0 .and. left(screenStr(mrow(),x,1),1)==MENU_TRENNER
      mErg:=left(screenStr(mrow(),x-2,1),1)
      mErg+=left(screenStr(mrow(),x-1,1),1)
    else
      return -1
    endif
    if type(mErg)=="N"
      akt_Auswahl:=val(mErg)
      Auswahl:=space(len(Auswahl))
    endif
  otherwise
    // normale Tastatur-Eingabe
    if Auswahl<>NIL .and. ! empty(Auswahl)
      akt_auswahl:=val(left(Auswahl,2))
    endif
  endcase

return akt_Auswahl
/** eof */

/** Standard Eingabe f�r Menu-Auswahl */
static procedure menuRead(GetList)
  SetKey( K_LBUTTONDOWN, {|| readkill(.T.) } )
  SetKey( K_RBUTTONDOWN, {|| readkill(.T.) } )
  ReadModal( GetList, NIL,NIL, EINGABE_FLAGS, .t. ) // with disable focus events
  GetList:={}
  ( Getlist ) // warum brauchen wir das? kopiert von .ppo file
  SetKey( K_LBUTTONDOWN, NIL )
  SetKey( K_RBUTTONDOWN, NIL )
return
/** eop */

/** 43. my test procedure */
static procedure MyTest2()
  RohMatBedarf(.t.) // Bedarf Rohmaterial
return
  /** eop */

  /** 42. my test procedure 1 */
static procedure MyTest()
  qout("Bingo")
return


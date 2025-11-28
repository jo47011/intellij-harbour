/* Modul Material.prg 
*
* Alles zur Material-Bedarfsliste (Achse Zeit)
*/
#include "miki.ch"
#include "zeige.ch"

#include "hbclass.ch"
#include "hbgtinfo.ch"
#include "hbqtgui.ch"

#define;
  BEW_IGNORE;
  BEW_AUFTRAG;
  +;
  BEW_AB_DISPO + BEW_AUFERFAS_E + BEW_AUFERFAS_O + BEW_INNER_OBER + BEW_INNER_EIGEN + BEW_ARTRESERV
#define BEW_NOT_IGNORE BEW_BESTELLUNG + BEW_WOCHEN_BEDARF + BEW_AUFTRAG_OBER

#define TREE_TITLES {"Artikel","Art","Baugr.","Lager"}

/* Analog MaterialBedarfsListe nur mit den Einstellungen vom Server */

PROCEDURE ServerMaterialBedarfsListe()
LOCAL GetList:={}
LOCAL art:=" "

  cls
  titel("Bedarf lokal berechnen analog zu Server Liste")
  Message("Gew�nschte Artikel-Art eingeben.   @ESC@=Abbruch")
  @ 8,20 say "Artikel Art:" get art picture "!"
  read

  if ! ABBRUCH
    if Message("Aktuelle Material-Bedarfsdatei wird �berschrieben.  Fortfahren? (@J@/@N@)","JN"," ")=="J"
      MaterialBedarfsListe(art,.t.)
    endif
  endif

return
  /** eop */



/* sortiert nach Baugruppen und Artikeln
*
* Material - Bedarfs - Liste / Baugruppe & Artikel drucken
*/
PROCEDURE MaterialBedarfsListe(preset, BSAbfrage)
LOCAL Zeile:=0 , Seite:=0, anzWochen:=0
local artikelArt:=space(5),achseZeit:="J", details:="N",nurBedarf:="J",sortOrder:="J"
LOCAL GetList:={}, ob:=4
LOCAL oWnd:=QMainWindow()
LOCAL oTree, minKW, maxKW, oai, minMax, stop:=.f., node, titel, okay
LOCAL codeblock, titelInfo
LOCAL titles:=TREE_TITLES, art
LOCAL subject:="Material-Bedarf", count
LOCAL alleListen:={}, empf, body, comment:=""

  default BSabfrage:=.f.

  Umgebung(WRITE_ALL)

  if DEVEL_PROG
    details:="J"
    nurBedarf:="N"
  endif

  if ! open( "Artikel" , "M_MEHRF", "X_MEHRF","Manuell" , "AvPost","AufAus","AufPost",;
    "BesPost" , "BesAus", "Inner","AvAus","Einheit","Text","Maschine","Auftrag","Kunden")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  // copy default values for remote service
  if getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN .or. ! BSabfrage
    kopiereServer(.f.,.f.) // ohne Abfrage
  endif
  if BSabfrage .and. getUser():id $ "JG" .and.;
    message("Hole Daten von Server? (@J@/@N@)","JN"," ")=="J"
    kopiereServer(.f.,.f.)
  endif

  if MANUELL->(reccount())==0
    if preset <> NIL
      trouble("matbedarf","Materialbedarf leer")
      Umgebung(LOAD)
      return
    endif
    Error(ACHTUNG+"Bitte zuerst Artikel in 3.1 erfassen.")
    Umgebung(LOAD)
    return
  endif

  select x_mehrf
  zap

  if preset <> NIL
    artikelArt:=preset
    details:="N"
    nurBedarf:="J"
    sortOrder:="J"
    achseZeit:="N"

    if BSabfrage .and. ! druck_BS()
      Umgebung(LOAD)
      RETURN
    endif

  else

    cls
    Titel("Material-Bedarf + Achse-Zeit anzeigen")

    @ ob,22 say "Auswahl:"
    @ ob+1,20 to ob+9,52
    @ ob+2,22 say "Artikel-Art eingeben:" get artikelArt picture "@!";
      when message("Artikel-Art eingeben: @Leer@=Alle @F@ertigung @M@ontage @E@inkauf "+;
      "@B@eistellteil, etc.")
    @ ob+4,22 say "Baugruppen als Baum :" get Details valid details $ "JN" picture "@!";
      when message("Details zu Baugruppen in Baumstruktur anzeigen? (@J@/@N@)")
    @ ob+6,22 say "Nur Bedarf..........:" get nurBedarf valid nurBedarf $ "JN" picture "@!";
      when message("Nur Artikel mit Bedarf anzeigen? (@J@/@N@)")
    @ ob+8,22 say "Sortiere nach KW....:" get sortOrder valid sortOrder $ "JN" picture "@!";
      when message("Sortiere Liste nach Kalenderwoche? (@J@/@N@)")

    @ ob+11,22 say "Achse Zeit:"
    @ ob+12,20 to ob+14,52
    @ ob+13,22 say "Achse Zeit anzeigen :" get achseZeit valid achseZeit $ "JN" picture "@!";
      wwhen message("Achse Zeit anzeigen? (@J@/@N@)")


    // @ 12,22 say "Nur Bedarf..........:" get nurBedarf valid nurBedarf $ "JN" picture "@!"
    // when message("Nur Artikel mit Bedarf anzeigen? (@J@/@N@)")
    read

    if ABBRUCH .or. ! druck_BS()
      Umgebung(LOAD)
      RETURN
    endif
  endif

  select Artikel
  set relation to ARTIKEL->ME into Einheit

  /* ACHTUNG andere order bei Bespost/Inner */
  select Inner
  INNER->(OrdSetFocus(2)) // inner
  select Bespost
  BESPOST->(OrdSetFocus(2)) // bespost
  set rela to BESPOST->BestNr into Besaus

  Message("Material-Bedarf wird bestimmt. Bitte warten... @ESC@=Abbruch")

  okay:=bedarfsDateiErstellen()

  if .not. okay .or. X_MEHRF->(reccount()) == 0
    Error("Keine DatenS�tze in Auswahl.")
    Umgebung(LOAD)
    return
  endif

  Message("Liste wird erstellt.    Bitte warten...")
  select MANUELL
  go top
  // merke Anzahl Wochen (sollte in allen Datens�tzen gleich sein)
  anzWochen:=MANUELL->Wochen

  /****************************************************************/
  /*** erstelle Achse Zeit ****************************************/
  /****************************************************************/
  if AchseZeit=="J"

    // find min max KW
    minKw:=getCurrentKW()
    maxKw:=KWincr(minKw, anzWochen)
    select x_mehrf
    go top
    do while ! X_MEHRF->(eof())
      oAI:=getoAI(OAI_GET, X_MEHRF->ArtNr)

      minMax:=oAI:getMinMaxKW()
      if minMax == NIL // ABBRUCH
        Umgebung(LOAD)
        return
      endif
      minKw:=KWMin(minKW,minMax[1])
      maxKw:=KWMax(maxKW,minMax[2])
      skip
    enddo

    // f�lle Spalten je KW
    aadd(titles, minKW)
    do while kwKleiner(minKW, maxKW) > 0
      minKW:=kwIncr(minKW)
      aadd(titles, minKW)
    enddo
    // dummy last empty column to catch resize events
    aadd(titles, "")

    oTree:=aiTree():new(oWnd, titles, 1)

    // prepare info panel
    oTree:addInfoRow("ALT-A","Artikel �ffnen")
    oTree:addInfoRow("F6","Oberbaugruppen anzeigen")
    oTree:addInfoRow("STRG-F6","Alle Oberbaugruppen anzeigen")

    // add artikel nodes to tree
    select MANUELL
    go top
    do while ! MANUELL->(eof()) .and. .not. stop
      ARTIKEL->(dbseek(MANUELL->ArtNr))
      // if empty(artikelArt) .or. getArtikelArt() $ artikelArt
      node:=populateNodeRek(oTree, MANUELL->ArtNr, artikelArt)
      oTree:addTopLevelItem(node)
      // endif
      stop:=(inkey() == K_ESC .or. lastkey() == K_ESC) // ESC gedr�ckt ?
      skip
    enddo
    // show 1st level
    oTree:getWidget():expandToDepth(0)
    // oTree:getWidget():scrollToItem(0)
    oTree:resizeColumnToContents()

    titel:="Achse Zeit (Lagerbestand)" + if(empty(artikelArt),"","  "+trim(artikelArt)+"-Artikel")
    if anzWochen > 0
      titel += "  Anzahl Wochen: " + trim(str(anzWochen,3))
    endif

    oTree:toggleKWColumns(.f., .t.) // hide empty KW in the past

    oWnd:setWindowTitle(titel)
    oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
    oWnd:setCentralWidget( oTree:getWidget() )

    oWnd:resize(min(len(titles)*48,1400),350)

    oWnd:connect(QEvent_KeyPress, { |x| matKeyPressed(x, oWnd, oTree) } )

    // // Info: no registerDialog() needed, because it is non modal and will be closed by main app
    oWnd:show()
  endif

  /****************************************************************/
  /*** erstelle "normale" Liste ***********************************/
  /****************************************************************/
  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  // FIXME
  aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." };
    )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b, .t. )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a,b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->SpecialZeige , { "" , { || .t. } , "@STRG-F6@=in allen Stkl."} )
  codeblock:="{ |a,b| rekLiAufBestArtikel( a , b , " + str(anzWochen) + ")}"
  aadd( M->SpecialZeige , { chr(K_CTRL_F9) , &codeblock , "@STRG-F9@=Auftragsbestand"} )

  titelInfo:="Material-Bedarfsliste"
  if ! empty(artikelArt)
    titelInfo += " " + alltrim(artikelArt) + "-Artikel"
  endif
  if details == "J"
    titelInfo += " Baumstruktur"
  endif
  if nurBedarf == "J"
    titelInfo += " nur Bedarf"
  else
    titelInfo += " alle, auch ohne Bedarf"
  endif
  if sortOrder == "J"
    titelInfo += " sortiert nach KW"
  else
    titelInfo += " sortiert nach Artikelnr."
  endif
  titelInfo += space(5) + " (Anzahl Wochen: "+alltrim(str(anzWochen)) + ")"

  Titel("Material-Bedarfs-Liste anzeigen")
  hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - " + alltrim(titelInfo))

  if details == "J"
    /* einzelner Bedarf ausdrucken , rekursiv je erfasste Anfrage Artikel */
    matBedarfHeader(anzWochen)
    select Manuell
    go top
    do while ! MANUELL->(eof())
      zeile:=0
      Seite++
      do while ! MANUELL->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->Unt_rand
        if matRekDruck(MANUELL->ArtNr,0,artikelArt,nurBedarf)
          ?
        endif
        select Manuell
        skip
      enddo
      ?
    enddo

    Zeile:=FormFeed(Zeile,Seite)
    getUser():getCurrentPrintJob():confirmEnd:=.t.
    Drucker("OFF")

  else
    /* einzelner Bedarf ausdrucken , chronologisch je Artikel oder nach KW */
    select X_MEHRF
    if sortOrder == "J"
      index on kwindex(X_MEHRF->KW, .t.) tag TEMP_INDEX TEMPORARY ADDITIVE
    endif

    // manuelle Auswahl -> 1 Liste f�r alle Arten
    if preset == NIL
      matBedarfHeader(anzWochen)
      go top
      do while ! eof()
        zeile:=0
        Seite++
        do while ! X_MEHRF->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->Unt_rand
          matDruckeSatz(0, artikelArt, nurBedarf)
          skip
        enddo
      enddo

      Zeile:=FormFeed(Zeile,Seite)
      getUser():getCurrentPrintJob():confirmEnd:=.t.
      Drucker("OFF")

    else // auto crontab job, 1 Liste per Art

      for each Art in alltrim(artikelArt)
        if ! BSabfrage
          Drucker("PDF","MatBed-" + art + "-Artikel")
        endif
        count:=0
        matBedarfHeader(anzWochen)
        go top
        do while ! eof()
          zeile:=0
          Seite++
          do while ! X_MEHRF->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->Unt_rand
            if matDruckeSatz(0, art, nurBedarf)
              count++
            endif
            skip
          enddo
        enddo

        getUser():getCurrentPrintJob():endDoc()
        if count>0
          if getUser():getCurrentPrintJob():pdfFullFileName<>NIL
            aadd(alleListen,getUser():getCurrentPrintJob():pdfFullFileName)
          else
            comment += "|"+no_blanks(getUser():getCurrentPrintJob():jobName,.t.)+".pdf -> leer"
          endif
        endif
        getUser():setCurrentPrintJob(NIL)

        //trouble("remote",alias() + " Art: " + art + str(count,2) + "  Anhang: " + array2readable(alleListen))

      next

      // erstelle EMail-Text
      if ! BSabfrage
        select Manuell
        go top
        body:=titelInfo+"||"
        do while .not. MANUELL->(eof())
          ARTIKEL->(dbseek(MANUELL->ArtNr))
          EINHEIT->(dbseek(ARTIKEL->ME))
          body;
            += MANUELL->ArtNr+" "+ARTIKEL->Bez1+" "+str(MANUELL->Menge,12,2)+" "+EINHEIT->Text+"|"
          skip
        enddo
        // body += "||Benutzer: " + getUser():getLongID()
        body += "|" + comment

        empf = trim(getProperty("Miki.mindbest.emails",MAIN_EMAIL))
        //trouble("remote","Empf�nger: " + empf + "  Anhang: " + array2readable(alleListen))
        email(empf,subject +;
          alltrim(str(anzWochen))+ " Wochen vom " + dtoc(getUser():date), body,alleListen)
      endif

    endif
  endif

  if AchseZeit=="J"
    oWnd:hide()
  endif

  Umgebung(LOAD)
RETURN
  /* EOP */

static function matBedarfHeader(anzWochen)
LOCAL Zeile:=0
  ? "Materialbedarfsliste vom:", dtoc(getUser():date)," Anzahl Wochen:",alltrim(str(anzWochen))
  ? "Art.Nr.     Bezeichnung                                    Auftrags Anfrage      akt.     "+;
    "Baugr.-  Vorlauf  verf�gbar                       Best.ext/int"
  ? "                                                            Bestand   Menge Lag.Best.     "+;
    "Bestand  (Wochen)      KW                "
  ? replicate("-",148)
  _____fixedHeader_____
return zeile

/*----------------------------------------------------------------------*/
/** sortiert alle Unter-Artikel in Baumstruktur ein und liefert root node zur�ck */
static function populateNodeRek(oTree, MArtNr, filterArt)
LOCAL root, child
LOCAL oAI, allMat, mat

  // get St�ckliste 1st so we now wether we have childs
  allMat:=StueckListe():new(MArtNr):getMaterial(.t.)

  oai:=getoAI(OAI_GET, MArtNr)
  root:=oAI:getQTNode(oTree, len(allMat) > 0) // wrapped if has childs

  // as of now Material only
  for each mat in allMat
    //if empty(filterArt) .or. mat:Art $ filterArt
    child:=populateNodeRek( oTree, mat:ArtNr , filterArt )
    root:addChild( child )
    //endif
  next

return root
/** eof */


/*
  * Parameter: Datei    : akt. Datei (Manuell.dbf)
*
* erstellt anhand der Manuell.dbf den benoetigten Mat.Bedarf
* und schreibt diesen -> X_mehrf.dbf
*/
static FUNCTION bedarfsDateiErstellen()
LOCAL stop:=.f., alleArtikel:={}, objErr
  //LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
LOCAL bLastHandler

  getoAI(OAI_CLEAR_ALL)
  select X_MEHRF
  zap

  BEGIN SEQUENCE // krit. Bereich
    select MANUELL
    go top
    do while ! eof() .and. .not. stop
      bedarfRek(MANUELL->ArtNr,MANUELL->Menge, 0, MANUELL->Wochen)
      select MANUELL
      stop:=(inkey() == K_ESC .or. lastkey() == K_ESC) // ESC gedr�ckt ?
      skip
    enddo
  RECOVER USING objErr
    //altd()
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    Error("Vorgang z.Zt. nicht m�glich.  Bitte erneut versuchen.")
    stop:=.t.
  END Sequence
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

RETURN ! stop
/* EOP */

/*
* ermittelt rekursiv den Mat.Bedarf der uebergeben Stk.Liste !
*
*/
static PROCEDURE bedarfRek(M_artNr,M_Menge, tiefe, anzWochen)
LOCAL merk_Satz, oAI, verfuegbar, RestBedarf, bewUnterNull

  ARTIKEL->(dbseek(M_ArtNr))

  if ARTIKEL->(eof()) .or. empty(M_ArtNr) .or. ARTIKEL->Art $ "TX" .or. ;
    inkey() == K_ESC .or. lastkey() == K_ESC // ESC gedr�ckt ?
    RETURN
  endif

  select X_MEHRF
  dbseek(M_ArtNr)
  if X_MEHRF->(eof())
    add_rec(0)
    replace X_MEHRF->ArtNr with M_artNr
    replace X_MEHRF->Reihenfolg with ARTIKEL->Reihenfolg
    replace X_MEHRF->Wochen with anzWochen

    // FIXME: was ist wenn Artikel mehrfach in verschiedenen Tiefen vorkommt?
    replace X_MEHRF->Tiefe with tiefe

    if tiefe == 1
      @ maxrow(),maxcol()-8 say out(X_MEHRF->ArtNr)
    endif

    oAI:=getoAI(OAI_GET,X_MEHRF->ArtNr)
    oAI:readBaugruppenBestand()
    //oAI:addAllAuftragsBedarf()

    if anzWochen > 0
      oAI:addWochenbedarf(M_Menge, anzWochen)
    endif

    // we ignore some bewegungen others we don't TBD
    oAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
    oAI:setIgnoreBewegungen(BEW_IGNORE, .t.)

    bewUnterNull:=oAI:lagerBestandUnterNull(,,.f.) // kein Mind.Bestand
    if bewUnterNull <> NIL
      replace X_MEHRF->KW with bewUnterNull:kw
    endif

  else
    rec_lock(0)
    oAI:=getoAI(OAI_GET,X_MEHRF->ArtNr)
    // if X_MEHRF->Tiefe <> tiefe
    // altd()
    // endif

    // FIXME: hier sollte der Wochenbedarf um die Menge erh�ht werden

  endif
  verfuegbar:=max(oAI:bestand + oAI:bestandExt - X_MEHRF->Menge,0)
  RestBedarf:=max(M_Menge - verfuegbar,0)
  replace X_MEHRF->Menge with X_MEHRF->Menge + M_Menge
  dbcommit()
  dbunlock()

  /* checke ob Unterartikel vorhanden */
  select AvPost
  seek M_ArtNr+"M"
  do while ! eof() .and. M_ArtNr==AVPOST->AvNr .and. AvPost->Art="M"
    if AVPOST->Text=="A"
      merk_Satz:=recno()
      bedarfRek(AVPOST->ArtNr, Restbedarf * AVPOST->Menge,tiefe+1,anzWochen)
      select AvPost
      go (merk_Satz)
    endif
    skip
  enddo

RETURN

/* Zeige OberBaugruppen des aktuell selektierten Artikel in einem neuen QT Tree an
*/
PROCEDURE showOberBaugruppen(ArtNr, rekursiv, zeigeListe)
LOCAL oWnd:=QMainWindow()
LOCAL lpw, oTree, minKW:=getCurrentKW()
LOCAL titles:=TREE_TITLES, titel, x, zeile:=0
LOCAL oAI, allOAIs, baugrSumme:=0

MEMVAR windowClosed
PRIVATE windowClosed:=.f.

  default rekursiv:=.f.
  default zeigeListe:=.f.

  Umgebung(WRITE_ALL)

  if ! open( "Artikel", "AvPost","AufAus","AufPost","M_Mehrf", "Waraus", ;
    "BesPost", "BesAus", "Inner", "AvAus","Einheit","Text","Maschine","Auftrag")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select WarAus
  WARAUS->(OrdSetFocus(2)) // ArtNr + Date descending
  AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr

  ARTIKEL->(dbseek(ArtNr))
  IF ARTIKEL->(eof())
    Error(ACHTUNG+"Artikel: " + artNr + " nicht gefunden.")
    Umgebung(LOAD)
    return
  endif
  EINHEIT->(dbseek(ARTIKEL->ME))

  titel:="Oberbaugruppen von Artikel: " + trim(out(artNr))
  hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - " + alltrim(titel))
  if zeigeListe
    cls
    Titel(titel)
  endif
  // if rekursiv
  // titel:="Alle " + titel
  // endif
  lpw:=QLabel(titel + " werden geladen...")
  lpw:setMargin(20)
  lpw:setFont(QFont("MS Shell Dlg 2", 16))
  lpw:setStyleSheet("QLabel { background-color : white; color : black; }")

  oWnd:setWindowTitle(titel)
  oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  oWnd:connect(QEvent_Close, { || M->windowClosed:=.t. } )
  oWnd:setCentralWidget(lpw)
  oWnd:resize(1200,300)
  oWnd:show()

  // f�lle Spalten je KW , FIXME: what is a good guess here?
  for x:=-10 to 40
    minKW:=kwIncr(getCurrentKW(), x)
    aadd(titles, minKW)
  next
  // dummy last empty column to catch resize events
  aadd(titles, "")

  oTree:=aiTree():new(oWnd, titles, 0)

  oAI:=getoAI(OAI_CLEAR_ALL) // need this otherwise wochenbedarf etc. still added
  readOberBaugruppen(oTree, lpw, titel, zeigeListe, ArtNr, NIL, 0, if(rekursiv,NIL,1))

  if ! M->windowClosed
    oTree:toggleKWColumns(.f., .t.) // hide empty KW in the past

    oWnd:setCentralWidget( oTree:getWidget() )

    oWnd:connect(QEvent_KeyPress, { |x| matKeyPressed(x, oWnd, oTree) } )
    oTree:getWidget():collapseAll()
    // oTree:getWidget():scrollToItem(0)
    oTree:resizeColumnToContents()
    oWnd:resize(min(len(oTree:aHeaders)*48,1400),350)
    // oWnd:adjustSize()
    oWnd:show()
  endif

  /****************************************************************/
  /*** erstelle "normale" Liste ***********************************/
  /****************************************************************/
  if zeigeListe
    allOAIs:=getoAI(OAI_GET_ALL, { |x| x:bestand <> 0 })
    aSort(allOAIs,,,{ |a,b| a:artNr < b:artNr })
    Drucker("BS")
    ? 'Oberbaugruppen Artikel:', artNr, '              vom:',getUser():date
    ? '------------------------------------------------------------------------------------------'+;
      '---------------'
    ? 'Art-Nr.      Bezeichnung                         Menge ME   Bestellt   Bestand Enth. Bgr. '+;
      'Letzte Bewegung'
    ? '                                                                               bei Miki'
    ? '------------------------------------------------------------------------------------------'+;
      '---------------'
    _____fixedHeader_____

    for each oAI in allOAIs
      if oAI:ArtNr <> artNr // nicht der aktuelle Artikel
        ARTIKEL->(dbseek(oAI:ArtNr))
        zeile += druckeMatArtikel(oAI:faktor, EINHEIT->ME, oAI)
        baugrSumme += ARTIKEL->LageBest * AVPOST->Menge
      endif
    next
    ? '------------------------------------------------------------------------------------------'+;
      '------------'
    ? space(76),str(baugrSumme,12,2)

    Drucker("OFF")

  endif

  Umgebung(LOAD)
RETURN
    /* EOP */

// add Oberbaugruppen nodes to tree
PROCEDURE readOberBaugruppen(oTree, lpw, titel, zeigeListe, artNr, child, tiefe, maxTiefe, faktor)
LOCAL node, oAI, oberArt

  default faktor:=1

  oAI:=getoAI(OAI_GET, ArtNr)
  if oAI:art $ "TX" .or. M->windowClosed
    if M->windowClosed
      Message("Liste abgebrochen.  Bitte warten...")
    endif
    return
  endif

  lpw:setText(titel + " werden geladen: "+out(artNr))
  if zeigeListe
    Message(titel + " werden geladen: "+out(artNr))
  endif

  // we ignore some bewegungen others we don't TBD
  oAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
  oAI:setIgnoreBewegungen(BEW_IGNORE, .t.)
  oAI:readBaugruppenBestand()
  // oAI:addAllAuftragsBedarf()
  oAI:kalkBestand()
  oAI:faktor:=faktor
  node:=oAI:getQTNode(oTree, tiefe > 1) // wrapped if has childs

  if child <> NIL .and. tiefe > 1 // don't add original request article
    node:addChild(child)
  endif

  if (len(oAI:aOberArtikel)==0 .and. tiefe > 0) .or. ;
    (maxTiefe != NIL .and. tiefe >= maxTiefe)
    oTree:addTopLevelItem(node)
  else
    for each oberArt in oAI:aOberArtikel
      readOberBaugruppen(oTree, lpw, titel, zeigeListe, oberArt[1], node:clone(), tiefe +;
        1, maxTiefe, oberArt[2] * faktor)
    next
  endif

return
/** eop */

PROCEDURE matKeyPressed( event, oWnd, oTree )
LOCAL oldQtWidget, string, artNr

  do case
    // nur Enter -> open Artikel
  case event:key() == 16777251 // Alt-Key
    // NOP

  case event:key() == 65 // A
    // ensure error warnings & messages are displayed in QTBox here
    oldQtWidget:=M->qtWidget
    if M->qtWidget == NIL
      M->qtWidget:=oWnd
    endif
    launchProgram( procname(), oTree, event:key() )
    M->qtWidget:=oldQtWidget

    // Alle OberBaugruppen anzeigen
  case hb_bitAnd(event:modifiers(), Qt_CTRL) > 0 .and. event:key == Qt_Key_F6 // CTRL-F6
    artNr:=oTree:getWidget():currentItem():text(0)
    showOberBaugruppen(artNr, .t.)

    // OberBaugruppen anzeigen
  case event:key() == 79 .or. event:key == Qt_Key_F6 // Alt-O, F6
    artNr:=oTree:getWidget():currentItem():text(0)
    showOberBaugruppen(artNr, .f.)

  otherwise
    if ! winKeyPressed( event, oWnd, oTree )
      ignore string
      // if getUser():id==KURZEL_DEVEL
      // string = "You have pressed the key: " + "<br><br>"
      // string = string + "VALUE= " + Str( event:key() ) + "<br>"
      // string = string + "KEY= " + Chr( event:key() )
      // qtMessage("Pressed: " + hb_ntos( event:key() ) )
      // altd()
      // endif
    endif

  endcase

return
/** eop */

/* 
* druckt rekrusive alles benoetigte Material der Baugruppe aus
*
* returns true wenn etwas ausgedruckt wurde
*/
static FUNCTION matRekDruck(M_ArtNr, tiefe, artikelArt, nurBedarf)
LOCAL merk_Satz
LOCAL printed:=.f.

  /* drucke akt. Satz aus */
  X_MEHRF->(dbseek(M_ArtNr))
  printed:=matDruckeSatz(tiefe*2, artikelArt, nurBedarf) .or. printed

  if tiefe == 1
    @ maxrow(),maxcol()-8 say out(X_MEHRF->ArtNr)
  endif

  select AvPost
  seek M_ArtNr+"M"
  do while ! eof() .and. M_ArtNr==AVPOST->AvNr .and. AvPost->Art="M"
    if AVPOST->Text=="A"
      merk_Satz:=recno()
      printed:=matRekDruck(AVPOST->ArtNr, Tiefe+1,artikelArt,nurBedarf) .or. printed
      select AvPost
      go (merk_satz)
    endif
    skip
  enddo

RETURN printed
/* EOP */

/*
* druckt akt. Satz aus X_mehrf aus !
*
* Paramter: in Baugruppe - true/false
*              Lr         - linker Rand (num.)
* returns: true wenn artikel gedruckt
*/
static FUNCTION matDruckeSatz(lr, artikelArt, nurBedarf, ignoreWochen)
LOCAL kom:="",m_artnr, zeile:=0
LOCAL Max:=12,maschart:=space(1)
LOCAL printed:=.f., oAI
LOCAL bewUnterNUll, bewLast

  default lr:=0
  default ignoreWochen:=.f.

  oAI:=getoAI(OAI_GET_CACHE_ONLY, X_MEHRF->ArtNr)

  if oAI == NIL .or. oAI:art $ "TX"
    RETURN printed
  endif

  // nur passende Artikel Art (Filter) ausgeben
  if ! empty(artikelArt) .and. ! oAI:art $ artikelArt
    RETURN printed
  endif

  ARTIKEL->(dbseek(X_MEHRF->ArtNr))

  m_artnr:=out(oAI:ArtNr)
  if lr<>0
    lr:=Min(Max,lr)
  endif

  if nurBedarf <> "J" .or. ! kwEmpty(X_MEHRF->KW)
    if lr==0
      ? FETT_AN,ZEIGE_ARTNR+M_ArtNr,FETT_AUS,space(0)
    else
      ? space(lr-1),ZEIGE_ARTNR+M_ArtNr,space(0)
    endif
    ?? ARTIKEl->Bez1,space(Max-lr),oAI:art,str(ARTIKEL->Disponiert,7),;
      ZEIGE_MENGE+str(X_MEHRF->Menge,7) , str(ARTIKEL->LageBest,9),;
      transstr(oAI:BaugrBestand,5,0),;
      if(oAI:baugrAnzahl > 0,"("+str(oAI:baugrAnzahl,4)+")",space(6))
    if ARTIKEL->MinPuffer > 0 .and. ARTIKEL->MinbestI > 0 .and. ! ignoreWochen
      ?? str(ARTIKEL->MinPuffer,2)
    else
      ?? space(2)
    endif

    // Lagerbestand das 1. Mal unter 0
    bewUnterNull:=oAI:lagerBestandUnterNull(,,.f.) // kein Mind.Bestand
    if bewUnterNull == NIL
      ?? space(9+1+5)
    else
      ?? str(bewUnterNull:lgNach,9),bewUnterNull:kw
    endif

    // Lagerbestand nach Anzahl der Wochen
    bewLast:=oAI:getLastBewegungAbgang()

    if ignoreWochen .or. bewLast == NIL .or. (bewUnterNull !=NIL .and.;
      bewUnterNull:lgNach == bewLast:lgNach)
      ?? space(9+1+5)
    else
      ?? str(bewLast:lgNach,9),bewLast:kw
    endif

    // HINWEIS:
    // X_MEHRF->BaugrMenge wie oft kommt Baugruppe in Rekursion vor
    // oAI:BaugrBestand wie oft kommt BAugruppe allgemein in anderen vor

    if ARTIKEL->BestExt<>0.00 .or. ARTIKEL->BestInt<>0.00
      ?? str(ARTIKEL->BestExt,7)+"/"+str(ARTIKEL->BestInt,7),"("
      // FIXME: teste leftMarg hier!
      drucke_best(ARTIKEL->ArtNr)
      ?? ")"
    endif
    printed:=.t.
  endif

RETURN printed
  /** eof */

/*
* druckt akt. Satz anhand matbedarfKW aus.
*
* returns: true wenn artikel gedruckt
*/
static FUNCTION matAktuellDruckeSatz(matBedarfKW)
LOCAL kom:="", zeile:=0
LOCAL maschart:=space(1)
LOCAL printed:=.f., oAI

  oAI:=getoAI(OAI_GET_CACHE_ONLY, matBedarfKW:ArtNr)

  if oAI == NIL .or. oAI:art $ "TX"
    RETURN printed
  endif

  ARTIKEL->(dbseek(matBedarfKW:ArtNr))

  ? FETT_AN,ZEIGE_ARTNR+out(oAI:ArtNr),FETT_AUS,space(0)
  ?? ARTIKEl->Bez1,space(12),oAI:art,str(ARTIKEL->Disponiert,7),;
    str(ARTIKEL->LageBest,9),;
    transstr(oAI:BaugrBestand,5,0),if(oAI:baugrAnzahl > 0,"("+str(oAI:baugrAnzahl,4)+")",space(6))

  // drucke Wochenbedarf in rot, wenn dieser genommen wurde
  if matBedarfKW:wochenmenge > matBedarfKW:OberArtWochenMenge
    ?? COLOR_RED+str(matBedarfKW:wochenMenge,8)+COLOR_DEFAULT
  else
    ?? str(matBedarfKW:wochenMenge,8)
  endif

  // Lagerbestand das 1. Mal unter 0
  if matBedarfKW:RelevanteBewegung == NIL
    ?? space(10+1+5+1+5)
  else
    ?? str(matBedarfKW:RelevanteBewegung:lgNach,6),space(3), matBedarfKW:LiefKW, matBedarfKW:FertKW
  endif

  // drucke Bestellungen if any
  if ARTIKEL->BestExt<>0.00 .or. ARTIKEL->BestInt<>0.00
    ?? str(ARTIKEL->BestExt,7)+"/"+str(ARTIKEL->BestInt,7),"("
    drucke_best(ARTIKEL->ArtNr)
    ?? ")"
  endif

  // drucke OberArtikel
  if matBedarfKW:OberArtNr <> NIL
    ? space(len(out(ARTIKEL->ArtNr))+1),out(matBedarfKW:OberArtNr),left(matBedarfKW:OberArtBez,25)
    ?? space(5),transstr(matBedarfKW:OberArtDisp,10,0)
    ?? transstr(matBedarfKW:OberArtBest,9,0),space(12)

    // drucke Wochenbedarf in rot, wenn dieser genommen wurde
    if matBedarfKW:OberArtWochenMenge > matBedarfKW:wochenmenge
      ?? COLOR_RED+str(matBedarfKW:OberArtWochenMenge,8)+COLOR_DEFAULT
    else
      ?? str(matBedarfKW:OberArtWochenMenge,8)
    endif
  endif

  printed:=.t.

RETURN printed
  /** eof */

/* ermoeglicht das anzeigen von Auftragbest�nden aus einer BS-Liste */
PROCEDURE rekLiAufBestArtikel( ZeilenText , ZeigeData, anzWochen )
LOCAL merkeZeige:=M->specialZeige
LOCAL mArtNr, M_Menge:=0

  ignore ZeilenText

  mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]

  BEGIN SEQUENCE // krit. Bereich
    if ZEIGE->(fieldPos("Menge" )) > 0
      M_Menge:=abs(val(ZeigeData[ ZEIGE->(fieldPos("Menge")) ]))
    endif
    RECOVER
      // NOP
  END Sequence

  if ! myEmpty( mArtNr )
    AufBestArtikel(mArtNr, M_Menge, anzWochen)
    M->specialZeige:=merkeZeige
  endif

RETURN
  /* EOP */

/*
* listet den Auftragsbestand f�r den akt. selektieren Artikel STRG-F9 aus MaterialBedarf
*
* Result: die Auftrags-Nr. falls Zeige mit RETURN beendet wird.  
*/
FUNCTION AufBestArtikel(mArtNr, Anfrage, anzWochen, printBuffer)
LOCAL BaugrText, oai
LOCAL merkSatz:=ARTIKEL->(recno())
LOCAL bew, lastMenge:=0, ABBestand:=0
LOCAL Zeile:=0, einheit
LOCAL result:=nil
LOCAL embeddedList:=( printBuffer <> NIL )

  default anzWochen:=0
  default anfrage:=0

  Umgebung(WRITE_ALL)
  if ! embeddedList
    Drucker("BS","Auftragsbestand: "+ARTIKEL->ArtNr)
    printBuffer:=printBuffer():new()
    Message("Liste wird erstellt.   Bitte warten...")
  endif

  ARTIKEL->(dbClearFilter())
  ARTIKEL->(OrdSetFocus(1))

  ARTIKEL->(dbseek(mArtNr))
  if ARTIKEL->(eof()) // should never happen
    trouble("AufBestArtikel","Artikel nicht gefunden: "+MArtNr)
  endif
  EINHEIT->(dbseek(ARTIKEL->ME))
  einheit:=EINHEIT->Text
  oAI:=ArtikelInfo():new()
  // oAI:readBaugruppenBestand()
  // oAI:addAllAuftragsBedarf()
  // oAI:kalkBestand()
  // we ignore some bewegungen others we don't TBD
  oAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
  oAI:setIgnoreBewegungen(BEW_IGNORE, .t.)
  oAI:setIgnoreBewegungen(BEW_AUFTRAG_OBER, .t.) // Ausnahme hier keine Bew. der Oberartikel

  // BaugrText:="Baugr + "
  BaugrText:=space(8)
  ->? 'Auftragsbestand:', ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(8)
  if Anfrage > 0 .or. anzWochen > 0
    ->?? "Anfrage:" , str(Anfrage,4), space(3), "Wochen:" , str(anzWochen,3)
  endif
  ->? '------------------------------------------------------------------------------------------'+;
    '---------'
  ->? 'KW    Nummer   Art.Nr.   Bezeichnung            ', ;
    COLOR_RED , BaugrText , COLOR_DEFAULT , '     Lg.Best      Auftrag      Bedarf  ME'
  ->? '------------------------------------------------------------------------------------------'+;
    '---------'
  _____fixedHeader_____

  oAI:kalkBestand()

  // Hinweis Mind.Bestand drucken falls sonst keine Eintr�ge
  // sollte normalerweise nicht vorkommen, da dann Anfrage-Menge erh�ht wird
  // und w�chentlicher Restbedarf gedruckt wird
  if len(oAI:bewegungen) == 0 .and. ARTIKEL->LageBest < ARTIKEL->MinBestI
    ->? getCurrentKW(),space(47),transstr(ARTIKEL->LageBest,11,0), einheit
    ->?? "(Mind.Bestand:",COLOR_RED,alltrim(transstr(ARTIKEL->MinbestI,11,0)),COLOR_DEFAULT,")"
  endif

  for each bew in oAI:bewegungen

    if bew:ignore
      loop
    endif

    ARTIKEL->(dbseek(mArtNr)) // notwendig, da unten bei Oberartikel evtl. ge�ndert!
    if bew:art == BEW_BESTELLUNG
      BESAUS->(dbseek(bew:nummer))
      ->??
      ->? bew:KW,COLOR_RED,ZEIGE_BESTNR + bew:nummer,if(bew:AufArt=="K","K"," "),COLOR_DEFAULT,space(0),;
        ZEIGE_KUNDNR + ZEIGE_LIEFNR+BESAUS->LiefNr,BESAUS->Kurzname
      ->? space(14),ZEIGE_ARTNR+out(mArtNr),ARTIKEL->Bez1,str(bew:lgVor,11,2)
      ->?? padl("+"+alltrim(str(bew:Menge,12,2)),12)

    elseif bew:art == BEW_INNER_EIGEN
      ->? bew:KW,ZEIGE_INNERNR + bew:nummer,space(4),;
        if(empty(bew:aufnr),space(8),"AB:" + ZEIGE_AUFNR + bew:aufnr),space(0), bew:grund
      ->? space(14),ZEIGE_ARTNR+out(mArtNr),ARTIKEL->Bez1,str(bew:lgVor,11,2)
      ->?? COLOR_RED,padl("+"+alltrim(str(bew:Menge,12,2)),12),COLOR_DEFAULT

    else
      // Auftrag (Warenausgang)
      AUFAUS->(dbseek(bew:AufNr))

      if bew:art == BEW_WOCHEN_BEDARF
        ->? COLOR_RED, bew:KW,"ohne",space(12),"w�chentlicher Rest-Bedarf",COLOR_DEFAULT
      else
        ->? bew:KW,ZEIGE_AUFNR + bew:AufNr,if(bew:AufArt=="K","K"," "),space(0),ZEIGE_KUNDNR + ;
          AUFAUS->KundNr,space(0),AUFAUS->Kurzname

        // 2. Zeile falls Versandkunde abweicht
        if AUFAUS->KundNr <> AUFAUS->V_KundNr
          KUNDEN->(dbseek(AUFAUS->V_KundNr))
          ->? space(14), ZEIGE_KUNDNR + AUFAUS->V_KundNr,space(0),KUNDEN->Kurzname
        endif
        if ! empty(bew:OberArtNr)
          ARTIKEL->(dbseek(bew:OberArtNr))
        endif
      endif
      ->? space(14),ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1, str(bew:lgVor,11,2),;
        str(bew:menge,12,2)

    endif // bew:art

    // Bedarf drucken
    if bew:lgNach < 0
      ->?? str(bew:lgNach,11),einheit // ACHTUNG: Anzeige negativ -
    else
      ->?? str(0,11),einheit
    endif
    lastMenge:=bew:lgNach

    // doch wieder mit Mindest.Best :)
    if bew:lgNach < ARTIKEL->MinbestI .and. ARTIKEL->MinbestI > 0
      ->?? "(Mind.Bestand:",COLOR_RED,alltrim(transstr(ARTIKEL->MinbestI,11,0)),COLOR_DEFAULT,")"
    endif

    ABBestand += bew:menge

  next

  ->? space(60),replicate("-",38)
  ->? space(60),str(lastMenge,9,2),einheit

  if ! embeddedList
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    Drucker("Off")

    if lastkey() == ZEIGE_RESULT
      result:=ZEIGE->AufNr
      // l�sche Tast.Puffer
      SetLastKey(0)
    endif
  endif

  Umgebung( LOAD )
RETURN result
/* EOP  */

/** druckt das Material (Liste F6) des aktuellen Artikels */
function druckeMatArtikel(mMenge,mME, oAI)
LOCAL Zeile:=0
LOCAL bestgedruckt
LOCAL Zusatz:=""

  ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(0),;
    getValueNachkomma( mMenge, 9 , mME ),EINHEIT->Text
  bestgedruckt:=.f.

  if getArtikelArt()$"FM"
    if ARTIKEL->bestInt>0

      if oAI == NIL
        Umgebung(WRITE_ALL)
        oAI:=ArtikelInfo():new()
        Umgebung(LOAD)
      endif

      ?? ARTIKEL->BestInt
      Zusatz:=oAI:getInnerNummern()
      bestgedruckt:=.t.
    endif
  else
    if ARTIKEL->bestExt>0
      ?? ARTIKEL->BestExt
      bestgedruckt:=.t.
    endif
  endif
  if ! bestgedruckt
    ?? space(9)
  endif
  ?? ARTIKEL->Lagebest, str(ARTIKEL->Lagebest * mMenge,10,2)

  // suche letzte Bestellung
  WARAUS->(dbseek(ARTIKEL->ArtNr))
  if ! WARAUS->(eof())
    ?? space(6),WARAUS->Datum
  endif

  if .not. empty(ARTIKEL->bez2)
    ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2, space(15),if(empty(Zusatz),"","("+Zusatz+")")
  elseif .not. empty(Zusatz)
    ? space(len(out(ARTIKEL->ArtNr))+len(ARTIKEL->Bez2)+1), space(15),"("+Zusatz+")"
  endif

return zeile
/** eop */

/** pr�ft alle Dienstleistungen in AB
  * und schickt email an H. Lehmann bei �nderungen
  */
PROCEDURE DienstLeistungsCheck(auto)
LOCAL header:="Dienstleistungen - Verf�gbarkeitsliste vom: " + dtoc(getUser():date)
LOCAL body:="Art.Nr.    Bezeichnung                   Lg-Bestand AB-Bestand    Bedarf|"
LOCAL Zeile:=0, seite:=0, printBuffer
LOCAL stop:=.f., printJob, filename, empf, count:=0

  default auto:=.t.

  if ! auto
    cls
    Titel("Dienstleistungen Verf�gbarkeit anzeigen")
  endif

  if ! openArtikelAendernDateien()
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  select Artikel
  set rela to ARTIKEL->ME into Einheit
  locate for ARTIKEL->Art=="D" .and. ARTIKEL->Lagebest < ARTIKEL->Disponiert

  Drucker(iif(auto,"PDF","BS"),"Dienstleistungen")

  ? header
  ? replicate("=", len(header))
  ?
  _____fixedHeader_____
  if printBuffer <> NIL
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    zeile += printBuffer:getNumLines()
  endif
  body += replicate("=",len(body)-1)+"|"

  do while ! ARTIKEL->(eof()) .and. ! stop
    Message("Liste wird erstellt.   Pr�fe @"+out(ARTIKEL->ArtNr)+"@   Bitte warten....")
    printBuffer:=printBuffer():new()
    Umgebung(WRITE_ALL)
    AufBestArtikel(ARTIKEL->ArtNr,,,printBuffer)
    Umgebung(LOAD)
    printBuffer:addNewLine()
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    zeile += printBuffer:getNumLines()

    body += out(ARTIKEL->ArtNr) + space(1) + ARTIKEL->Bez1 + space(1)
    body += str(ARTIKEL->LageBest,9,2) + str(ARTIKEL->Disponiert,11,2) + space(1)
    body += str(ARTIKEL->LageBest - ARTIKEL->Disponiert,9,2)+space(1)+EINHEIT->Text + "|"
    count++
    cont
    Stop:=stop_key()
  enddo

  printjob = getUser():getCurrentPrintJob()
  Drucker("OFF")
  filename = printjob:pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  // Dienstleistungen an H. Lehmann
  if count > 0 .and. auto
    empf = trim(getProperty("Miki.dienstleistungen.emails", MAIN_EMAIL))
    email(empf, "Dienstleistungen in ABs vom " + dtoc(getUser():date), body, FileName)
  endif

  close data
return
  /** eop */

/* 
* Material - Bedarfs - Liste aktueller Bestand - wann ins Minus
*/
PROCEDURE MatBedarfAktuell(myart)
LOCAL Zeile:=0 , Seite:=1
LOCAL parent, children, entry, mArtNr, allChildren:=hb_hash()
LOCAL oai, bewnull
LOCAL sortOrder:="W", childrenList:={}, childrenListOhneBedarf:={}, list
LOCAL alleListen:={}, empf, body, nurBedarf:="J"
LOCAL subject:="Material-Bedarf (aktuell)", auto:=.t., aktArt
LOCAL GetList:={}, comment:="", count // , printBuffer
LOCAL OberArtNr, OberAI

  if valtype(myart) == "U"
    auto:=.f.
    myart:=space(5)
  endif

  Umgebung(WRITE_ALL)
  cls
  titel("Material - Bedarfs - Liste aktueller Bestand")

  if ! open( "Artikel" , "Manuell" , "AvPost", "AvAus","Einheit", "BesAus", "BesPost","Inner", ;
    "Manuell","Aufaus", "AufPost", "M_Mehrf", "Auftrag","System", "TODO")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  getoAI(OAI_CLEAR_ALL)

  // copy default values for remote service
  Umgebung(WRITE)
  kopiereServer(.f., .f., MATERIAL_SERVER_AKT_BESTAND) // ohne Abfrage
  Umgebung(LOAD)

  if ! auto
    if MANUELL->(reccount())==0
      Error(ACHTUNG+"Bitte zuerst Artikel in 3.1 erfassen.")
      Umgebung(LOAD)
      return
    endif

    @ 8,20 say "Artikel Arten....:" get myart picture "@!" ;
      when Message("Gew�nschte Artikel-Art eingeben.   Leer = Alle   @ESC@=Abbruch")
    @ 10,20 say "Sortierung (A/W):" get sortOrder picture "!" valid sortOrder$"AW" ;
      when Message("Sortierung nach @A@rtikel oder Kalender@w@oche? (@A@/@W@)")
    @ 12,20 say "Nur Bedarf (J/N):" get nurBedarf picture "!" valid nurBedarf$"JN" ;
      when Message("Nur Artikel mit Bedarf (Bestand < 0) anzeigen? (@A@/@W@)")
    read

    if ABBRUCH
      Umgebung(LOAD)
      RETURN
    endif

    if empty(myart)
      myArt:="BDEFMX"
    endif

  endif

  Message("Materialbedarf wird berechnet.  Bitte warten...")

  select MANUELL
  replace all MANUELL->Wochen with 0 // FIXME: needed?

  go top
  do while ! MANUELL->(eof())
    @ Maxrow(),0 say MANUELL->ArtNr
    parent:=StueckListe():new(MANUELL->ArtNr,,0)
    children:=parent:getChildren("M", .t., .t.) // rekursiv
    hcopy(children, allChildren)
    skip
  enddo

  message("Liste wird erstellt.  Bitte warten...")

  // frage alle Verf�gbarkeiten ab
  for each mArtNr in allChildren:Keys
    entry:=MatBedarfKW():new()
    entry:artNr:=mArtNr
    entry:children:=allChildren[mArtNr]

    ARTIKEL->(dbseek(martnr))
    entry:disponiert:=ARTIKEL->Disponiert
    entry:art:=ARTIKEL->Art
    @ Maxrow(),0 say mArtNr
    //oAI:=getoAI(OAI_GET, mArtNr)
    oAI:=ArtikelInfo():new()

    // if trim(mArtNr) == "5006626"
    // oberAI:toQTList()
    // altd()
    // endif

    // we ignore some bewegungen others we don't TBD
    oAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
    oAI:setIgnoreBewegungen(BEW_IGNORE, .t.)

    oAI:readBaugruppenBestand()
    // oAI:addAllAuftragsBedarf()
    bewNull:=oAi:lagerBestandUnterNull(,,.f.)

    // if trim(mArtNr) == "5702000"
    // oAI:toQTList()
    // altd()
    // endif

    // Hier soll laut MW s. email vom 5.11.23 der OberArtikel mit dem max. Lagerbestand hinzugez�hlt werden
    // Der Wochenbedarf wird dann vom OberArtikel genommen und nicht vom UnterArtikel
    if getArtikelArt() == "E"
      if ARTIKEL->MinPuffer > 0
        entry:wochenMenge:=roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer)
      endif
      oberArtNr:=oAi:getOberArtikelMaxLagebest()
      if oberArtNr != NIL
        ARTIKEL->(dbseek(oberArtNr))
        oberAi:=ArtikelInfo():new()
        // we ignore some bewegungen others we don't TBD
        oberAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
        oberAI:setIgnoreBewegungen(BEW_IGNORE, .t.)
        oberAI:readBaugruppenBestand()
        // oberAI:addAllAuftragsBedarf()
      endif

      // special case: Artikel die mit 295 beginnen -> 2 Stufen hoch
      if left(mArtNr,3)=="295" .and. oberArtNr != NIL
        addBestellungen(oAI, oberAI) // pr�fe Bestellungen 2. Stufe

        //oberAI:=getoAI(OAI_GET, oberArtNr)
        // oberAI:readBaugruppenBestand()
        // oberAI:addAllAuftragsBedarf()

        oberArtNr:=oberAI:getOberArtikelMaxLagebest()
        if oberArtNr != NIL
          ARTIKEL->(dbseek(oberArtNr))
          oberAi:=ArtikelInfo():new()
          // we ignore some bewegungen others we don't TBD
          oberAI:setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
          oberAI:setIgnoreBewegungen(BEW_IGNORE, .t.)
          oberAI:readBaugruppenBestand()
          //oberAI:addAllAuftragsBedarf()
        endif
      endif

      if oberArtNr != NIL
        ARTIKEL->(dbseek(oberArtNr))

        // Ausnahme, falls Oberartikel-Art == E, dann nicht drucken (s. mail vom 12.11.23)
        if getArtikelArt() == "E" .or. ARTIKEL->(eof())
          loop
        endif
        // if trim(mArtNr) == "2952950"
        // oberAI:toQTList()
        // altd()
        // endif
        addBestellungen(oAI, oberAI) // pr�fe Bestellungen 3. Stufe

        entry:OberArtNr:=ARTIKEL->ArtNr
        entry:OberArtBez:=ARTIKEL->Bez1
        entry:OberArtDisp:=ARTIKEL->Disponiert
        entry:OberArtBest:=ARTIKEL->LageBest
        if ARTIKEL->MinPuffer > 0
          entry:OberArtWochenMenge:=roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer)
        endif

        // f�ge Lagerbestand von Oberartikel hinzu
        oAI:bestand += ARTIKEL->LageBest
        oAI:kalkBestand()

        // if trim(mArtNr) == "2952950"
        // oAI:toQTList()
        // altd()
        // endif

        ARTIKEL->(dbseek(martnr))
        bewNull:=oAi:lagerBestandUnterNull(,,.f.)
      endif
    endif

    // Ausnahme 295er Artikel nur drucken wenn Auftragsbestand vorhanden
    // seit 20231210 ohne OberArtikel // .and. entry:OberArtDisp <= 0
    if bewNull == NIL .and. (left(mArtNr,3)=="295" .or. entry:disponiert<=0)
      loop
    endif

    if bewNull == NIL .or. left(mArtNr,3)=="295"
      oAI:addWochenbedarfBisNull(entry:getMaxWochenMenge())
      entry:RelevanteBewegung:=oAi:getLastBewegungAbgang()
    else
      entry:RelevanteBewegung:=bewNull
    endif

    entry:calcFertKw()

    if sortOrder == "W" .and. bewNull == NIL // sortorder KW
      aadd(childrenListOhneBedarf, entry)
    else
      aadd(childrenList, entry)
    endif
  next

  // sortiere (optional)
  if sortOrder == "W" // sortorder KW
    childrenList:=aSort(childrenList,,,{ |a,b| a:compareKW(b) })
    childrenListOhneBedarf:=aSort(childrenListOhneBedarf,,,{ |a,b| a:compareKW(b) })
  else
    childrenList:=aSort(childrenList,,,{ |a,b| a:compareArtikel(b) })
  endif

  // l�sche alte TODO-Liste (nur nachts der Server)
  if getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN+"|"+KURZEL_DEVEL .or. AT_HOME
    select TODO
    if fil_lock()
      dele for TODO->Type == TODO_INNER_AB
      dbcommitall()
      dbunlockall()
    endif
  endif

  // drucke all children pro Artikel-Art
  for each aktArt in alltrim(myArt)
    Drucker("PDF","MatBedarfAktuell-"+aktArt,,,PDF_NO_CONFIRM)
    ? "Materialbedarfsliste vom:", dtoc(getUser():date)," Anzahl Wochen: 0"
    ? "Art.Nr.     Bezeichnung                                  Auftrags       akt.     Baugr.-   "+;
      "Wochen  verf�gbar  KW    KW   Best.ext/int"
    ? "                                                          Bestand  Lag.Best.     Bestand   "+;
      " Menge             Lief. Fert."
    ? replicate("-",148)
    _____fixedHeader_____
    count:=0

    for each list in {childrenList, childrenListOhneBedarf}
      for each entry in list
        if entry:art == aktArt
          ARTIKEL->(dbseek(entry:artNr))
          if matAktuellDruckeSatz(entry, nurBedarf)
            count++

            // if trim(entry:artnr)=="5006726"
            // altd()
            // endif

            // schreibe Datensatz in TODO-Liste (nur nachts der Server)
            if (aktArt$"FDM" .and. getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN+"|"+KURZEL_DEVEL);
              ..or. AT_HOME
              select TODO
              add_rec(0)
              replace TODO->Type WITH TODO_INNER_AB
              replace TODO->ArtNr with entry:artnr
              replace TODO->Fert_KW with entry:FertKW
              replace TODO->Lief_KW with entry:LiefKW
              replace TODO->Menge with entry:RelevanteBewegung:lgNach
            endif
          endif
        endif
      next
      if list == childrenList
        ?
        ? "Artikel mit fiktivem Wochenbedarf nach letztem realen Bedarf:"
        ? "============================================================="
      endif
    next

    // erstelle EMail-Text
    getUser():getCurrentPrintJob():endDoc()
    if auto
      if getUser():getCurrentPrintJob():pdfFullFileName<>NIL
        if count > 0
          aadd(alleListen,getUser():getCurrentPrintJob():pdfFullFileName)
        else
          comment += "|"+no_blanks(getUser():getCurrentPrintJob():jobName,.t.)+".pdf -> leer"
        endif
      endif
      getUser():setCurrentPrintJob(NIL)
    endif
  next

  // sende email
  if auto
    select Manuell
    go top
    body:=subject+" - 0 Wochen ||"
    do while .not. MANUELL->(eof())
      ARTIKEL->(dbseek(MANUELL->ArtNr))
      EINHEIT->(dbseek(ARTIKEL->ME))
      body += MANUELL->ArtNr+" "+ARTIKEL->Bez1+"|"
      skip
    enddo
    // body += "||Benutzer: " + getUser():getLongID()
    body += "|" + comment

    empf = trim(getProperty("Miki.mindbest.emails",MAIN_EMAIL))
    email(empf, subject, body, alleListen)
  endif

  Umgebung(LOAD)

return
/** eop */

/* Ausnahme Bestelleingang vom Oberartikel beachten (s. mail vom 28.11.23) */
static PROCEDURE addBestellungen(oAI, oberAI)
LOCAL bestellungen
  if ARTIKEL->BestExt > 0
    bestellungen:=oberAI:getBewegungenByArt( BEW_BESTELLUNG )
    oAI:addBewegungen(bestellungen)
  endif
return
/** eop */

CLASS MatBedarfKW

DATA artNr
DATA art
DATA Disponiert
DATA children // rekursiv in hash_table
DATA RelevanteBewegung // letzte Bewegung oder 1st under 0 ohne MindestBestand
DATA WochenMenge INIT 0
DATA FertKW // Fert.KW mit Vorlauf der vorherigen Artikel
DATA LiefKW // Lief.KW mit Vorlauf der vorherigen Artikel

DATA Tiefe init 0

  // OberArtikel Infos
DATA OberArtNr
DATA OberArtBez
DATA OberArtDisp INIT 0
DATA OberArtBest INIT 0
DATA OberArtWochenMenge INIT 0

METHOD new()
METHOD getKWOhneMind()
METHOD compareKW(other)
METHOD compareArtikel(other)
METHOD getMaxWochenMenge()
METHOD calcFertKW()

ENDCLASS

METHOD new() CLASS MatBedarfKW
RETURN self

/* return KW of Bewegung if any otherwise empty KW */
METHOD getKWOhneMind()
  if self:RelevanteBewegung==NIL .or. self:RelevanteBewegung:KW==NIL
    return "  /  "
  endif
return self:RelevanteBewegung:KW

/** compare for sorting with other MatBedarfKW  */
METHOD compareKW(other)
LOCAL aKW, bKW, result
  // aKW : self:getKWOhneMind()
  // bKW:=other:getKWOhneMind()
  aKW:=self:FertKW
  bKW:=other:FertKW
  result:=kwKleiner(aKW, bKW)
  // falls KW identisch sortiere nach ArtNr
  if result == 0
    return self:compareArtikel(other)
  endif
return result > 0

/** compare for sorting with other MatBedarfKW:ArtNr  */
METHOD compareArtikel(other)
return self:ArtNr < other:ArtNr

/** get maximum of wochenmenge, aktueller Artikel vs. OberArtikel */
METHOD getMaxWochenMenge()
return max(::wochenmenge, ::OberArtWochenMenge)

/** berechne Vorlauf Fertigung -> Fert.KW
  *
  * RelevanteBewegung muss gesetzt sein
  */
METHOD calcFertKw()
LOCAL fertDauer:=getGesFertDauer( ::ArtNr, ::RelevanteBewegung:lgNach * (-1) )
LOCAL;
  fertKW:=calcKW(::RelevanteBewegung:kw , getDauerNextArtikel(::ArtNr, ::RelevanteBewegung:lgNach);
  * (-1), fertDauer*(-1) , SYSTEM->Holidays)
  ::LiefKw:=::RelevanteBewegung:kw
  ::FertKw:=fertKW
return self

/** eoc */  



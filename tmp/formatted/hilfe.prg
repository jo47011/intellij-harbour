// todo: sukzessive alle FelderAlt() in addColumn() in Datei: Hilfdef.prg umwandeln !

// f�r Browse n�tig
#include "Hilfe.ch"
#include "MyStd.ch"
#include "Setcurs.ch"
#include "common.ch"
#include "fileio.ch"

#include "hbgtinfo.ch"


#define ARRAY len(M->aArray) > 0

#define SUCH_SPALTE M->oBrowse:nLeft+((M->oBrowse:nRight-M->oBrowse:nLeft)/2)-20

#define HILFE_INKEY_FLAGS INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN + INKEY_MWHEEL

_thread static grepSuche, grepFilter , lastAlias

/***
*
*  MyBrowse()
*
*  TBrowse-Objekt anlegen und steuern
*
* Info: oBrowse:cargo wurde fr�her als CodeBlock als Filter verwendet.
* Ist seit 26.10.2013 raus.  Jetzt sollte "index on ... tag temporary for...." verwendet werden.
*
*/
// PROCEDURE  Hilfe( ProcName, oGet/*, ReadVar */
PROCEDURE Hilfe( ProcName, oGet )

LOCAL nKey:=0 // Tastendruck
LOCAL lMore:=TRUE // Schleifenkontrolle
  // LOCAL lSavReadExit:=READEXIT( .T. ) // PfeilAuf/Ab zu verlassen des
  // READs aktivieren
LOCAL nTop:=3,nLeft:=1,nRight:=maxCol()-1 // Default-Fenstergr��e
LOCAL nBottom:=Maxrow()-3
LOCAL akt_Rec:=recno()
LOCAL selectRec , selectDatei
LOCAL lastKey

Local sizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
Local sizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
LOCAL posx:=hb_gtInfo( HB_GTI_SETPOS_XY )[1]
LOCAL posy:=hb_gtInfo( HB_GTI_SETPOS_XY )[2]
Local fontMode:=hb_gtInfo(HB_GTI_RESIZEMODE)
Local fullScreen:=hb_gtInfo(HB_GTI_ISFULLSCREEN)
LOCAL tempFontWidth:=hb_gtInfo( HB_GTI_FONTWIDTH )
LOCAL tempFontSize:=hb_gtInfo( HB_GTI_FONTSIZE )

  /* folgende Var. k�nnen im spez. Def.prog ge�ndert werden
  *  z.B. vorbrowse.prg
  */
  // FIXME: do we really need so many MemVars??? Maybe join in one Array or better user a class
MEMVAR okay,aArray,nRow,Datei,such,such_Neu,Return_Feld,SpecialHilfe,oBrowse,SecondLine,nShowRow
MEMVAR preFunction,postFunction,confirm,aktColor,merkOrdFor,keepPosition, callBackOnToggle,;
  clearBuffer
MEMVAR suchShiftRight, werkzeug

PRIVATE okay:=.t.
PRIVATE aArray:={} , nRow:=1 // F�r Array's
PRIVATE Datei:={} , such:="" , such_Neu:="" // F�r SuchText in ApplyKey
PRIVATE Return_Feld:=""
PRIVATE SpecialHilfe:=NIL // spezielle Tastenfkt.
PRIVATE callBackOnToggle:=NIL // spezielle Call back on space/mouse selection
PRIVATE postFunction:=NIL // spez. Funtkion die nach dem Beenden von Hilfe ausgef�hrt werden soll
PRIVATE preFunction:=NIL // spez. Funtkion die nach dem Darstellen des Rahmens ausgef�hrt wird
Private oBrowse
Private SecondLine:={ || .f. } // Codeblock .t. falls akt. Zeile 2. Zeile besitzt
  // cargo leider bereits belegt
Private nShowRow:=1 // number of lines for current record showing (maybe 1 or 2)
Private confirm // can be set for one return field only, can differ from set(_SET_CONFIRM)
Private clearBuffer // if set to false previous buffer will not be erased
Private aktColor:=setcolor()
PRIVATE merkOrdFor:=NIL
PRIVATE keepPosition:=.f. // if .t. the same record as upon start will be selected on end, no rec change
PRIVATE aktOrd // merke akt. Index Order
PRIVATE suchShiftRight:=.f. // shift enterd value one-by-one if not found
  // lock is kept automatically if applicaple
PRIVATE werkzeug // used in hilfdef for ordfor() clause in index


  // default is empty get field, since 20120321
  default oGet:=getnew()
  default procname:=""

  /** Remember Such-Text */

  // Neues TBrowse-Objekt mit Code-Bl�cken f�r Satzzeigerpositionierung
  // erzeugen
  M->oBrowse:=TBrowseDB( nTop, nLeft, nBottom, nRight )

  Umgebung(WRITE_ALL) // merke alle Bereiche

  // mein skip-block
  M->oBrowse:SkipBlock:={|n| Skipper(n) }

  // Benutzerdefinierte Fkten zuweisen
  M->oBrowse:=HilfDef(M->oBrowse,oGet,ProcName)
  M->aktOrd:=indexOrd()

  // testing mouse
  // IF MPRESENT()
  // // set( _SET_EVENTMASK, INKEY_ALL )
  // mshow()
  // mSetCursor( .t. ,1,1)
  // else
  // Error("Keine Maus gefunden")
  // endif

  if ! M->okay // keine Hilfe definiert
    Umgebung(LOAD)
    M->SpecialHilfe:=NIL // reset custom functions if any
    M->callBackOnToggle:=NIL // reset custom functions if any
    RETURN
  endif

  if ! empty(alias())
    M->Datei:=db_info(alias())
    M->merkOrdFor:=&(ALIAS())->(ordFor())
  endif

  // don't resize font => use additional resize space for additional columns
  hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_ROWS )

  // Kopf- und Spaltentrennzeichen setzen
  M->oBrowse:headSep:=MY_HEADSEP
  if valtype(M->oBrowse:colSep)=="C" .and. empty(M->oBrowse:colSep)
    M->oBrowse:colSep:=MY_COLSEP
  endif

  // Farbtabelle f�r die Anzeige vorgeben
  M->oBrowse:colorSpec:=COLHILFE

  // shut off highlight bar, we'll do it ourselves
  M->oBrowse:autolite:=.F.

  /** zeige alte Sortierreihefolge in Header an */
  if lastAlias == alias()
    sortByColumn( -1 )
  else
    sortByColumn( NIL )
  endif

  M->oBrowse:configure()
  //M->oBrowse:invalidate():forceStable()
  //M->oBrowse:refreshAll()
  //invalidateAll()

  // Schatten des TBrowse-Fensters erzeugen
  dispbegin()

  // setcolor( left(COLHILFE,7) )
  setcolor( COLHILFE )
  scroll( M->oBrowse:nTop-1, M->oBrowse:nLeft-1, M->oBrowse:nBottom+1, M->oBrowse:nRight+1 )

  dispend()

  printFrame()

  // neu seit 21.3.2012
  if valtype(M->preFunction)=="B"
    eval(M->preFunction)
  endif

  // Cursor-Form retten, Cursor w�hrend der Anzeige ausschalten
  setcursor( SC_NONE )

  // print message at bottom of screen
  invalidateFooters()
  bottLineHilfe()

  // removed 9.3.2012
  // such-Text anzeigen
  // applyKey( 0 ,oGet)
  suchTextInit(oGet)

  // if (oGet<>NIL .and. empty(oGet:buffer)) .or. (ALIAS())->(eof())
  // // go top, geht schief bei Arrays =>
  // oBrowse:goTop()
  // endif


  if M->oBrowse:freeze==0
    M->oBrowse:freeze:=1 // 1. Spalte festhalten !
  endif

  // setzte letzten Filter, falls vorhanden
  if ! empty(alias()) .and. ordNumber( HILFE_TEMP_INDEX ) > 0
    ordSetFocus( ordNumber( HILFE_TEMP_INDEX ) )
    // pr�fe ob aktueller Datensatz in Filter vorhanden
    if ! myempty( grepFilter ) .and. ! fieldsContain(grepFilter)
      dbgotop()
    endif
  endif

  // if lastAlias == alias() .and. ! myEmpty( grepFilter )
  // setMyFilter('fieldsContain("'+grepFilter+'")')
  // endif

  // Hauptschleife
  while lMore

    // Stabilisieren bis die Anzeige stabil ist oder eine
    // Taste gedr�ckt wird
    dispbegin() // to avoid screen flicker
    do while (nKey:=warte(, HILFE_INKEY_FLAGS ))==0 .and. ! M->oBrowse:stabilize
    enddo
    dispend()

    /** bei 2 Zeilen Taste wiederholen */
    if eval(M->secondLine) .and. ( lastKey==K_UP .or. lastKey==K_DOWN)
      lmore:=applyKey( lastKey ,oGet)

      /*
      *  Aktuellen Satz neu anzeigen, um die Anzeige
      *  falscher Daten im Netzwerk zu verhindern
      */
      // M->oBrowse:refreshCurrent():forceStable()
      dispbegin() // to avoid screen flicker
      while !M->oBrowse:stabilize() // while highlightening
        /* */
        // two lines in the browse
      enddo
      dispend()
    endif

    if ( M->oBrowse:hitTop .or. M->oBrowse:hitBottom )
      tone( 125, 0 )
    endif

    // akt. Zeile hervorheben
    highlightCurrentRow( .t. )

    // Alles klar, jetzt warte auf einen Tastendruck
    if nkey=0
      nKey:=warte( 0, HILFE_INKEY_FLAGS )
    endif

    // Zeile wieder low lighten
    highlightCurrentRow( .f. )
    // altd()

    if ( nKey == K_ESC .or. nKey==HILFE_TASTE1 .or. nKey==HILFE_TASTE2 .or. nKey == HB_K_CLOSE )
      // ESC bewirkt Abbruch
      lMore:=.F.

    else
      // Tastendruck auf das TBrowse-Objekt anwenden
      lmore:=applyKey( nKey ,oGet)

    endif
    lastKey:=nKey

  enddo

  /** l�sche letzte SHIFT-Range selection */
  toggleTempSelection(NIL,.t.)

  /** was windows resized? => set default size */
  if sizeX<>hb_gtInfo(HB_GTI_SCREENWIDTH) .or. sizeY<>hb_gtInfo(HB_GTI_SCREENHEIGHT);
    .or. fullScreen<>hb_gtInfo(HB_GTI_ISFULLSCREEN)
    // WATCHOUT: the order is significant here, do not change!!!
    hb_gtInfo(HB_GTI_ISFULLSCREEN,fullScreen)
    hb_gtInfo(HB_GTI_SCREENWIDTH,sizeX)
    hb_gtInfo(HB_GTI_SCREENHEIGHT,sizeY)
    hb_gtInfo( HB_GTI_FONTWIDTH ,tempFontWidth)
    hb_gtInfo( HB_GTI_FONTSIZE ,tempFontSize )
    qout(" ") // needed as workaround for bug in setPos
    hb_gtInfo(HB_GTI_SETPOS_XY,{posX,posY})
  endif
  hb_gtInfo( HB_GTI_RESIZEMODE, fontMode )

  // l�sche filter
  if ! inStackTrace("aend") // hmmmm
    setMyFilter()
  endif

  // merke letzte Datei, um Sortierung evtl. zu resetten
  lastAlias:=Alias()

  // seit 3.4. merkt sich Umgebung(WRITE_ALL) auch alle recno()s
  // also nach dem Load auf vom Benutzer selektierten Datensatz gehen.
  if ! (ABBRUCH .or. M->keepPosition) .and. ! empty(M->Datei) .and. ! empty(alias())
    selectDatei:=alias()
    selectRec:=(selectDatei)->(recno())
  endif

  /* falls Abbruch , gehe auf urspr. Satz */
  Umgebung(LOAD)
  if (ABBRUCH .or. M->keepPosition) .and. ! empty(M->Datei) .and. ! empty(alias())
    go (akt_Rec)
  endif

  if selectRec <> NIL .and. select( selectDatei ) > 0
    (selectDatei)->(dbgoto( selectRec ) )
  endif

  // neu seit 23.2.2012
  if valtype(M->postFunction)=="B"
    eval(M->postFunction)
  endif

  // Reset suche wenn Programm verlassen wird
  // grepSuche:=nil

  M->SpecialHilfe:=NIL // reset custom functions if any
  M->callBackOnToggle:=NIL // reset custom functions if any

RETURN



  /***
  *
  *  Skipper()
  *
  *  Benutzerdefinierte Satzzeigersteuerung (SKIP) f�r
  *  das TBrowse-Objekt.
  */
FUNCTION Skipper( nSkip )
LOCAL i:=0
LOCAL aktRec:=recno()

  do case
  case ( nSkip == 0 )
    dbSkip(0) // (wichtig im Netz)

    // workaround for buggy/wrong ordFor evaluation in dbskip(0), added 13.10.2015
    //
    // Fehler Reproduktion (Miki):
    // �ffne Programm #1
    // 11.2 Fremd Material, gebe bel. Artikel ein und �ffne (leere) Best.Nr. Auswahl (F12)
    // �ffne 2. Programm 5.1 Bestellung beliebe Bestellung und schlie�e diese wieder
    // bei BestBestand -> Umgebung(WRITE_ALL) geht's schief
    // gehe zur�ck zu Programm #1
    // dort wird diese Bestellung angezeigt, obwohl Artikel darin nicht vorkommt :(
    if ! empty(ordFor()) .and. ! &(ordFor())
      dbSkip(1)
      dbSkip(-1)
    endif

  case ( nSkip > 0 .and. !eof() )
    do while ( i < nSkip ) // Skip vorw�rts
      if ! skipForw()
        if eval(M->secondLine) // isLast2ndLine()
          i--
        endif
        exit
      endif
      if eof() //.or. isLast2ndLine()
        Skipback(.T.)
        exit
      endif
      i++
    enddo

  case ( nSkip < 0 )
    do while ( i > nSkip ) // Skip r�ckw�rts
      if ! skipBack() .or. bof()
        exit
      endif
      i--
    enddo

    // case ( nSkip == 0 .or. lastrec() == 0 ) // changed 25.1.2013
    // wichtig: ordkeycount() kostet Zeit, Abfrage selten also ans Ende
  case ( OrdKeyCount() == 0 )
    dbSkip( 0 ) // (wichtig im Netz)

  endcase

RETURN i

  /***
  *
  *   ApplyKey()
  *
  *   Tastendruck auf das TBrowse-Objekt anwenden.
  *
  *
  */

  #define SUCH_NEU substr(M->Such,len(M->Such_Neu)+1)

static FUNCTION ApplyKey( nKey ,oGet )
LOCAL Merk_Satz:=recno()
LOCAL GetList:={},bLastHandler,objErr
LOCAL i,n,tempKeys
LOCAL Inhalt,laenge,merkGrepSuche,merkGrepFilter,excel

  if valtype(nKey)<>"U" .and. nKey != 0 .and. ! isSpecialHilfeChar(nKey) > 0
    clear2ndLine()
  endif

  do case
  case nKey == K_DOWN
    // already at the end when shown 2 lines? -> nop
    if isLast2ndLine()
      return .t.
    endif

    // clear2ndLine()
    M->oBrowse:down()
    M->such:=M->such_Neu

  case nKey == K_UP
    // clear2ndLine()
    M->oBrowse:up()
    M->such:=M->such_Neu

  case nKey == K_PGDN
    // already at the end when shown 2 lines? -> nop
    if isLast2ndLine()
      return .t.
    endif

    // clear2ndLine()
    M->oBrowse:pageDown()
    M->such:=M->such_Neu

  case nKey == K_CTRL_PGDN
    // clear2ndLine()
    M->oBrowse:goBottom()
    M->such:=M->such_Neu

  case nKey == K_PGUP
    // clear2ndLine()
    M->oBrowse:pageUp()
    M->such:=M->such_Neu

  case nKey == K_CTRL_PGUP
    // clear2ndLine()
    M->oBrowse:goTop()
    M->such:=M->such_Neu

  case nKey == K_RIGHT
    // M->oBrowse:right()
    M->oBrowse:panRight()

  case nKey == K_LEFT
    // M->oBrowse:left()
    M->oBrowse:panLeft()

  case nKey == K_HOME .and. ; // CTRL_A wird extra behandelt
    hb_gtinfo( HB_GTI_KBDSHIFTS ) <> hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL )
    // clear2ndLine()
    M->oBrowse:gotop()
    M->such:=M->such_Neu

  case nKey == K_END
    // clear2ndLine()
    M->oBrowse:goBottom()
    M->such:=M->such_Neu

  case nKey == K_CTRL_LEFT
    M->oBrowse:panLeft()

  case nKey == K_CTRL_RIGHT
    M->oBrowse:panRight()

  case nKey == K_CTRL_HOME
    M->oBrowse:panHome()

  case nKey == K_CTRL_END
    M->oBrowse:panEnd()

  case nKey == K_BS // Backspace
    if ! M->such==M->such_Neu
      M->such:=left(M->such,len(M->such)-1)
    endif

    // Mouse / Maus actions
  case nKey == K_LBUTTONDOWN
    if M->oBrowse:mRowPos()==0
      sortByColumn(M->oBrowse:mColPos())
      invalidateAll()
    else
      // clear2ndLine()
      TBMouse(M->oBrowse,mRow(),mCol())

      // pr�fe ob Maus noch extra belegt ist
      if (i:=isSpecialHilfeChar(nKey)) > 0
        clear2ndLine() // wird oben nicht mehr ausgef�hrt, da isSpecialHilfeChar()
        eval( M->SpecialHilfe[i,HILFE_FUNKTION] ,M->oBrowse)
      endif

    endif
    M->such:=M->such_Neu

    // nur Header wird hier abgefangen
  case nkey == K_LDBLCLK .and. M->oBrowse:mRowPos()==0
    sortByColumn()
    invalidateAll()

    // im Bauch kann �ber M->specialHilfe definiert werden
    // case nkey == K_LDBLCLK .and. M->oBrowse:mRowPos()<>0

  case nKey == K_MWFORWARD
    clear2ndLine()
    n:=val(getProperty("System.mouse.scrollfactor","1"))
    for i:=1 to n
      M->oBrowse:Up()
    next
    M->such:=M->such_Neu

  case nKey == K_MWBACKWARD
    // already at the end when shown 2 lines? -> nop
    if isLast2ndLine()
      return .t.
    endif

    clear2ndLine()
    n:=val(getProperty("System.mouse.scrollfactor","1"))
    for i:=1 to n
      M->oBrowse:Down()
    next
    M->such:=M->such_Neu

  case (i:=isSpecialHilfeChar(nKey)) > 0 .and. M->SpecialHilfe[i,HILFE_FUNKTION] <> nil
    eval( M->SpecialHilfe[i,HILFE_FUNKTION] ,M->oBrowse)
    M->oBrowse:refreshAll()
    // // // lowlighte erst danach
    // M->oBrowse:refreshCurrent():forceStable()
    clear2ndLine()

  case nKey == -1 .or. nKey==FKT_SPECIAL // M->suchtext l�schen (Artikel-Auskunft)
    M->such:=M->such_Neu
    // Reset suche
    grepSuche:=nil
    // Filter nicht
    // grepFilter:=nil
    bottLineHilfe()

  case nKey == K_RETURN .or. nKey==K_LDBLCLK

    // if return-feld is NONE , we bail out here
    if M->Return_Feld=="NIL"
      RETURN(.f.) // Beenden von Browse
    endif

    // get return value
    if empty(M->Return_Feld)
      if ARRAY
        inhalt:=M->aArray[M->oBrowse:rowPos]
      else
        inhalt:=getKeyFieldValue(M->Datei)
      endif
    else
      // FIXME: codeblock would be the better approach
      inhalt:=&(M->Return_Feld)
    endif

    // l�sche Tastaturpuffer
    keyboard ""

    // now assign it

    if (oget:buffer)==NIL
      // self create temp. get-object, e.g. for Sonderzeichen - FIXME: we need a proper flag here
      tempKeys:=""
      // default is no clear buffer hier (alter Adel)
      if valtype(M->clearBuffer)=="L" .and. M->clearBuffer
        tempKeys += chr(K_CTRL_Y)+chr(K_HOME)+chr(K_CTRL_Y)
      endif

      tempKeys += inhalt
      keyboard( tempKeys )
    else
      Laenge:=len(oGet:Buffer)

      if ! ARRAY
        // alpha-numerisches Zielfeld
        do case
        case valtype(inhalt)=="C"
          inhalt:=left(Inhalt+space(50),laenge)
        case valtype(inhalt)=="N"
          inhalt:=left(str(Inhalt)+space(50),laenge)
        case valtype(inhalt)=="D"
          inhalt:=left(dtoc(Inhalt)+space(50),laenge)
        otherwise
          TroubleEmail("Unsupported Valtype in Hilfe:"+oGet:type+" <- "+valtype(inhalt))
        endcase
      endif

      tempKeys:=""
      // default is clear buffer hier
      if valtype(M->clearBuffer)<>"L" .or. M->clearBuffer
        tempKeys += chr(K_CTRL_Y)+chr(K_HOME)+chr(K_CTRL_Y)
      endif


      tempKeys += inhalt

      // gloable confirm on? local confirm on?
      if set(_SET_CONFIRM ) .and. (valtype(M->confirm)<>"L" .or. M->confirm)
        tempKeys += chr(K_ENTER)
      endif

      keyboard( tempKeys )

    endif

    M->clearBuffer:=NIL // Reset clear buffer

    // do case
    // case oget:type=="C"
    // // alpha-numerisches Zielfeld
    // do case
    // case valtype(inhalt)=="C"
    // oGet:varput(left(Inhalt+space(50),laenge))
    // case valtype(inhalt)=="N"
    // oGet:varput(left(str(Inhalt)+space(50),laenge))
    // case valtype(inhalt)=="D"
    // oGet:varput(left(dtoc(Inhalt)+space(50),laenge))
    // otherwise
    // TroubleEmail("Unsupported Valtype Mix in Hilfe:"+oGet:type+" <- "+valtype(inhalt))
    // endcase

    // case oget:type=="N"
    // // numerisches Zielfeld
    // do case
    // case valtype(inhalt)=="N"
    // oGet:varput(Inhalt)
    // case valtype(inhalt)=="C"
    // oGet:varput(val(Inhalt))
    // otherwise
    // TroubleEmail("Unsupported Valtype Mix in Hilfe:"+oGet:type+" <- "+valtype(inhalt))
    // endcase

    // case oget:type=="D"
    // // Datum ist Zielfeld
    // do case
    // case valtype(inhalt)=="D"
    // oGet:varput(Inhalt)
    // case valtype(inhalt)=="C"
    // oGet:varput(ctod(Inhalt))
    // otherwise
    // TroubleEmail("Unsupported Valtype Mix in Hilfe:"+oGet:type+" <- "+valtype(inhalt))
    // endcase

    // otherwise
    // TroubleEmail("Unknown Valtype in Hilfe:"+oGet:type)
    // endcase

    RETURN(.f.) // Beenden von Browse


    case nKey == K_CTRL_RETURN .or. (nKey==K_F4 .and. isSpecialHilfeChar(K_F4) == 0) // Datensatz �ndern
      if ! ARRAY .and. (getUser():mayEditData)
        if valtype(M->Datei[D_DISP])=="C" .and. Rec_lock(5)
          Umgebung(WRITE)
          setcursor(DEUTE_MARKE)
          setcolor(COLWIN)
          &(M->Datei[D_DISP])(.t.) // �ndern
          Umgebung(LOAD)
          dbcommit()
          unlock
          M->oBrowse:refreshCurrent():forceStable()
        endif
      endif

      case nKey==K_F6 .and. isSpecialHilfeChar(K_F6) == 0// Datensatz anzeigen
        if ! ARRAY .and. (getUser():mayShowData)
          if valtype(M->Datei[D_DISP])=="C"
            Umgebung(WRITE)
            setcursor(0)
            setcolor(COLWIN)
            &(M->Datei[D_DISP])(.f.) // anzeigen
            Message("Bitte @Taste@ dr�cken","@")
            keyboard ""
            Umgebung(LOAD)
            // raus am 3.2.2011
            // dbcommit()
            // unlock
          endif
        endif

        case nKey==K_F7
          // Umgebung(WRITE)
          Message()
          merkGrepSuche:=if(grepSuche==nil,space(20),left(grepSuche+space(20),20))
          setcursor(DEUTE_MARKE)
          @ maxrow(),SUCH_SPALTE say "Suche nach:" get merkGrepSuche picture "@K"
          qqout("  F8 = weitersuchen")

          // read now - with exit on resize events
          ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
          setcursor(SC_NONE)
          if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
            resizeBS()
            // Umgebung(DISMISS_NEXT)
          else
            if ! ABBRUCH
              grepSuche:=trim(merkGrepSuche)
              Message("Suche @"+grepSuche+"@")
              if ! empty(grepSuche)
                loca for fieldsContain(grepSuche) next 100000
                if eof()
                  Error(grepSuche+" nicht gefunden.",.t.)
                  go (Merk_Satz)
                endif
                M->oBrowse:refreshAll()
              endif
            endif
            bottLineHilfe()
            // Umgebung(LOAD)
          endif
          GetList:={} ; ( GetList )

    /* weitersuchen */
          case (nKey==K_F8 .or. nKey==K_ALT_F7)
    /** erste mal ? */
            if grepSuche==nil .or. empty(trim(grepSuche))
              RETURN ApplyKey( K_F7 ,oGet )
            endif

            Message("Suche @"+grepSuche+"@")
            cont
            if eof()
              Error(grepSuche+" nicht gefunden.",.t.)
              go (Merk_Satz)
            endif
            M->oBrowse:refreshAll()
            bottLineHilfe()
            // Umgebung(LOAD)

            case nKey==K_CTRL_F10 .and. DEVEL_PROG
              Message()
              merkGrepFilter:=if(grepFilter==nil,space(60),left(grepFilter+space(60),60))
              setcursor(DEUTE_MARKE)
              @ maxrow(),12 say "Devel Filter:" get merkGrepFilter picture "@K"
              // read now - with exit on resize events
              ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
              setcursor(SC_NONE)
              if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
                // Umgebung(DISMISS_NEXT)
              else
                if ! ABBRUCH
                  grepFilter:=trim(merkGrepFilter)
                  setMyFilter(grepFilter)
                  go top
                  bottLineHilfe()
                endif
              endif

              case nKey==K_F9 .and. ! ARRAY
                Message()
                merkGrepFilter:=if(grepFilter==nil,space(20),left(grepFilter+space(20),20))
                setcursor(DEUTE_MARKE)
                @ maxrow(),SUCH_SPALTE say "Filter:" get merkGrepFilter picture "@K"
                @ maxrow(),SUCH_SPALTE + 30 say "Leer = Filter l�schen"

                // read now - with exit on resize events
                ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
                setcursor(SC_NONE)
                if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
                  resizeBS()
                  // Umgebung(DISMISS_NEXT)
                else
                  if ! ABBRUCH
                    grepFilter:=trim(merkGrepFilter)
                    if empty(grepFilter)
                      setMyFilter()
                    else
                      setMyFilter('fieldsContain("'+grepFilter+'")')
                      Message("Filter @"+grepFilter+"@")
                      go top
                      bottLineHilfe()

                      if eof()
                        setMyFilter()
                        Error(grepFilter+" nicht gefunden.",.t.)
                        go (Merk_Satz)
                      endif
                    endif
                    deselectAll()
                    invalidateAll()
                    // M->oBrowse:refreshAll()
                  endif
                  bottLineHilfe()
                endif
                GetList:={} ; ( GetList )

                case nKey == 0 // M->suchtext initiailisren
                  suchTextInit(oGet)

                  case nKey == EXCEL_TASTE
                    if getUser():mayEditData
                      BEGIN SEQUENCE // krit. Bereich
                        excel:=ExcelExport():new()
                        excel:addBrowse(M->oBrowse)
                        excel:export()
                        excel:=NIL
                      RECOVER USING objErr
                        // nop Fehler bereits in Excel angezeigt
                      END SEQUENCE
                    endif

                    case HB_SetKeyGet(nKey) <> NIL .and. nKey<>INFO_TASTE // setkey gesetzt??
                      // ACHTUNG: muss nach Abfrage nkey == FKT_SPECIAL kommen!
                      // wird sonst beim Aufruf mit F12 gleich -> Absturz
                      bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
                      BEGIN SEQUENCE
                        HB_SetKeyCheck(nKey,procName(),NIL,NIL)
                        // invalidateAll()
                      RECOVER USING objErr
                        email(MY_EMAIL,"ERROR: SetKey:"+str(nKey)+;
                          " failed in Hilfe.",getErrorText(objErr))
                      END SEQUENCE
                      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

                      // Harbour resize & focus events
                      CASE nKey == HB_K_GOTFOCUS
                        M->oBrowse:refreshCurrent():forceStable()
                        // nop
                        CASE nKey == HB_K_LOSTFOCUS
                          // nop
                          CASE nKey == HB_K_RESIZE
                            resizeBS()

                            otherwise

                            suchTextInput(nKey)

                          endcase

                          suchTextDisplay()


                          RETURN(.t.) // Default, es geht weiter
/** eof */

/** l�scht die gehighlightet 2. Zeile, if applicable */
                          // STATIC PROCEDURE clear2ndLine()
                          // if eval(M->secondLine)

                          // do case
                          // case M->oBrowse:rowPos=1
                          // M->oBrowse:rowPos++
                          // M->oBrowse:refreshCurrent():forceStable()
                          // M->oBrowse:rowPos:=1
                          // case M->oBrowse:rowPos=M->oBrowse:rowCount
                          // M->oBrowse:rowPos--
                          // M->oBrowse:refreshCurrent():forceStable()
                          // M->oBrowse:rowPos++
                          // otherwise
                          // M->oBrowse:rowPos--
                          // M->oBrowse:refreshCurrent():forceStable()
                          // M->oBrowse:rowPos += 2
                          // M->oBrowse:refreshCurrent():forceStable()
                          // M->oBrowse:rowPos--
                          // endcase
                          // endif
                          // // Info muss hier stehen, soll also auch bei nur 1 Zeile ausgef�hrt werden
                          // M->oBrowse:refreshCurrent():forceStable()
                          // return
/** eop */

  /** l�scht die gehighlightet 2. Zeile, if applicable */
STATIC PROCEDURE clear2ndLine()

  M->oBrowse:refreshCurrent():forceStable()

  // if eval(M->secondLine)

  // // Note: depending on direction the line pointer maybe on 1st or on 2nd line
  // // so we clean everything around

  // // clean line above
  // if M->oBrowse:rowPos > 1
  // cleanRowAtRelPos( -1 )
  // endif

  // // clean line below
  // cleanRowAtRelPos( +1 )

  // endif

  // Info muss hier stehen, soll also auch bei nur 1 Zeile ausgef�hrt werden
  // cleanRowAtRelPos( 0 )

return
/** eop */

/** cleans the specified row (oBrowse:rowPos +/- param) */
  // static function cleanRowAtRelPos( num )
  // LOCAL lastRowPos:=M->oBrowse:rowPos
  // M->oBrowse:rowPos += Num
  // M->oBrowse:refreshCurrent():forceStable()
  // M->oBrowse:rowPos:=lastRowPos
  // return .t.
/** eof */


/** liefert .t. wenn der Cursor auf der letzten Zeile ist und diese zwei-zwilig */
static function isLast2ndLine()
return eval(M->secondLine) .and. OrdKeyNo()==OrdKeyCount()
/** eof */



  /***
  *
  *   Felder erzeugen
  *
  *
  */
PROCEDURE addMyColumn( spalte , pos )

LOCAL n:=1
LOCAL oColumn
LOCAL aStruct:=dbStruct()
LOCAL feldName:=myfieldname(Spalte[COL_NAME])
LOCAL feldLen:=0 // ,temp,tempCB,bLastHandler,objErr
LOCAL footerValue

  default Spalte[COL_TITEL]:=feldName
  default Spalte[COL_FELDNAME]:=feldName

  // num. Titel nach rechts shiften
  if type(Spalte[COL_NAME])=="N"
    if VALTYPE(Spalte[COL_BREITE]) == "N" // numerische Breite
      feldlen:=Spalte[COL_BREITE]
    else
      if fieldpos(Spalte[COL_FELDNAME]) > 0
        feldlen:=aStruct[fieldpos(Spalte[COL_FELDNAME]),3]
      else
        // FIXME: unlogisch, nimmt hier einfach den 1. Wert!
        // feldlen:=Log10(&(Spalte[COL_NAME]))
        feldlen:=10 // (FIXME: default Wert)
      endif
    endif

    // is Footer longer?
    if VALTYPE(Spalte[COL_FOOTER]) == "B"
      footerValue:=eval(Spalte[COL_FOOTER]) // make sure we eval this codeblock only once!
      if footerValue<>nil .and. len(footerValue)>feldlen
        feldlen:=len(footerValue)
      endif
    endif

    Spalte[COL_TITEL]:=replicate(" ",feldlen-len(Spalte[COL_TITEL]))+Spalte[COL_TITEL]
    // Spalte[COL_TITEL]:=right(replicate(" ",feldLen)+alltrim(Spalte[COL_TITEL]),feldLen)
  else
    // Footer defined?
    if VALTYPE(Spalte[COL_FOOTER]) == "B"
      footerValue:=eval(Spalte[COL_FOOTER]) // make sure we eval this codeblock only once!
    endif

  endif

  oColumn:=TBColumnNew( Spalte[COL_TITEL] , sBlock(Spalte) )
  /** merke Spaltendef. */
  oColumn:cargo:=Spalte
  if type(Spalte[COL_NAME])=="N"
    oColumn:colorBlock:=COL_NUMERISCH
  endif

  // Spaltenbreite definiert ???
  if VALTYPE(Spalte[COL_BREITE]) == "N" // numerische Breite
    oColumn:width(Spalte[COL_BREITE])
  endif

  // Spaltenbreite definiert ???
  if ! empty(Spalte[COL_SECOND_LINE]) // 2. Zeile
    M->secondLine:=&( "{ || ! empty("+Spalte[COL_SECOND_LINE]+") }" )
  endif

  // Spalten-Fkt., Bug here doppelt mit 2. Zeile ,jojo
  // if VALTYPE(Spalte[SPEZIAL_FUNKTION]) == "B"
  // oColumn:cargo:=Spalte[SPEZIAL_FUNKTION]
  // endif

  /* alternative Farbe */
  if VALTYPE(Spalte[COL_FARBE]) == "B" // eigener Farblook !
    oColumn:colorBlock:=Spalte[COL_FARBE]
  endif

  // Farben
  oColumn:defColor:=STANDARD_COLOR

  // Spalte dem TBrowse-Objekt hinzuf�gen
  if pos==NIL
    M->oBrowse:addColumn( oColumn )
  else
    M->oBrowse:insColumn( pos, oColumn )
  endif

  // Footer per column
  if VALTYPE(Spalte[COL_FOOTER]) == "B" .and. footerValue<>NIL
    oColumn:Footing:=footerValue
  endif

RETURN
/* EOP Felder */




  /*** sblock /Character
  * gibt Codeblock zu uebergebenen Var. zur�ck
  */
FUNCTION sBlock(spalte)
LOCAL _Cblock
  _Cblock:="{ || if(M->nShowRow<=1,"+spalte[COL_NAME]+","+spalte[COL_SECOND_LINE]+") }"
  // _Cblock:="{ |setVal| if(setVal==Nil,"+spalte[COL_NAME]+","+spalte[COL_NAME]+":=setVal) }"
RETURN &_CBlock


  /*** Cblock /Character
  * gibt Codeblock zu uebergebenen Var. zur�ck
  */
FUNCTION cBlock(x)
LOCAL _Cblock:="{ || "+x+"}"
RETURN &_CBlock

  /*** Ablock
  * gibt Codeblock zu editierenden Array. zur�ck
  */
FUNCTION aBlock()
LOCAL _Ablock:="{ || M->aArray[M->nRow] }"
RETURN &_ABlock




  /***
  *
  *  ASkipTest( <a>, <nCurrent>, <nSkip> ) --> nSkipsPossible
  *  Unterst�tzungsfunktion f�r ABrowse().
  *
  *  Ermittelt, ob es im Array <a> ausgehend von der Zeile nRow
  *  m�glich ist, den "Satzzeiger" um <nSkip> Zeilen vor- oder
  *  zur�ck zu verschieben.
  *  Die R�ckgabe gibt an, um wieviele Zeilen der "Satzzeiger"
  *  verschoben werden kann.
  *
  */
FUNCTION ASkipTest( a, nCurrent, nSkip )

  IF ( nCurrent + nSkip < 1 )

    // Das w�re ein "Skip" �ber den Anfang hinaus...
    RETURN ( -nCurrent + 1 )

  ELSEIF ( nCurrent + nSkip > LEN( a ) )

    // Das w�re ein "Skip" �ber das Ende hinaus...
    RETURN ( LEN(a) - nCurrent )

    END

    // Alles OK
    RETURN ( nSkip )

/***    jojo    noch �berarbeiten
*
*  ABrowseBlock( <a>, <x> ) --> bColumnBlock
*  Unterst�tzungsfunktion f�r ABrowse().
*
*  Erzeugt einen Code-Block zum Setzen/Abfragen
*  des Array-Elementes <a>[nRow, <x>]
*
*  Diese Funktion liefert einen Code-Block zur�ck,
*  der Bez�ge auf die lokalen Variablen <a> und
*  <x> (die beiden Parameter) enth�lt.
*
*  Die Variablen f�r den Zugriff durch den Code-Block
*  bleiben auch nach dem R�cksprung aus der Funktion erhalten.
*
*  Dies bedeutet, da� jeder Aufruf von ABrowseBlock()
*  einen Code-Block zur�ckliefert, �ber den sp�ter auf
*  die �bergebenen Werte von <a> und <x> zugegriffen
*  werden kann. Der erzeugte Block enth�lt ebenso einen
*  Bezug auf die statische Variable nRow, die von
*  ABrowse() verwendet wird, um die aktuelle Zeile in
*  dem Array zu speichern.
*
*/
FUNCTION ABrowseBlock( a )

RETURN ( {|p| IF( PCOUNT() == 0, a[M->nRow], a[M->nRow]:=p ) } )


/* FUNCTION zeile_aendern
*
* �ndern der 1. Textzeile im F2-Hilfemodus
*/
FUNCTION Zeile_Aend()
LOCAL column,getList:={}
LOCAL curs:=setcursor(DEUTE_MARKE)
LOCAL currentRow:=row(), secondRow:=.f.,Spalte

  if M->oBrowse:LeftVisible>2
    setcursor(curs)
    beep()
    RETURN .f.
  endif

  if Rec_lock(5)

    column:=M->oBrowse:getColumn( 2 )
    Spalte:=Column:cargo

    /** if pos is 2nd line talk field above */
    if eval(M->secondLine)
      if eval(column:block) == &(Spalte[COL_SECOND_LINE])
        currentRow--
        secondRow:=.t.
      endif
    endif

    M->oBrowse:Home()
    // make sure browse is stable
    WHILE ( !M->oBrowse:stabilize() )
    enddo

    // create a corresponding GET and READ it
    if Spalte==NIL // old style definition
      aadd(GetList,GetNew(row(), col(), column:block,column:heading,, M->oBrowse:colorSpec))
    else
      aadd(GetList,GetNew(currentRow, col(), fieldblock(Spalte[COL_NAME]), column:heading,, M->oBrowse:colorSpec))
    endif
    if secondRow
      if Spalte==NIL // old style definition
        // aadd(GetList,GetNew(row()+1, col(), column:block,column:heading,, M->oBrowse:colorSpec))
        // not supported, don't know 2nd line name
      else
        aadd(GetList,GetNew(currentRow+;
          1, col(), fieldblock(Spalte[COL_SECOND_LINE]), column:heading,, M->oBrowse:colorSpec))
      endif
    endif

    // READMODAL( {get} )

    // read now - with exit on resize events
    ReadModal( getList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
    if getList[1]:exitState == GE_RESIZE_EVENT .or.;
      secondRow .and. getList[2]:exitState == GE_RESIZE_EVENT
      resizeBS()
    endif

    dbcommit()
    unlock

    // falls Filter gesetzt
    if ! empty(dbfilter()) .or. ! empty(ordFor())
      dbskip(0) // changed 4.2.2013 was dbskip()
      invalidateAll()
    endif

    setcursor(curs)
    M->oBrowse:refreshCurrent():forceStable()
    if secondRow
      M->oBrowse:rowPos--
      M->oBrowse:refreshCurrent():forceStable()
      M->oBrowse:rowPos++
    endif
    M->oBrowse:colPos:=1

  endif
RETURN .t.
/* EOF */

/** Function getNewColumn
* gibt eine leere SpaltenDefiniton zurueck
* siehe Hilfe.ch
*/
Function getNewColumn
LOCAL result[COL_FELD_MAX]

  result[COL_NAME]:=""
  result[COL_TITEL]:=nil
  result[COL_BREITE]:=nil
  result[COL_FELDNAME]:=nil
  result[COL_FARBE]:=nil
  result[COL_SECOND_LINE]:=""

return result
/* eof */


/** Function myEmpty
 */
Function myEmpty(String)
  if valtype(string)=="U"
    return .t.
  endif
return empty(String)
/** eof */

  /** Returns the plain name of the specified field,
  * strips of ALIAS_NAME-> if any
  */
static function myfieldname(name)
LOCAL result:=name
  if "->"$name
    result:=substr(name,at("->",name)+2)
  endif
return result
/** eof */


    /***
    *
    *   Felder erzeugen, alte Syntax -> wird gemapped nach oColumn (s. getNewColumn)
    *
    */
PROCEDURE FelderAlt( Feld, Titel, Breite, Aender, Fkt , numerisch , Farbe )

LOCAL n:=1
LOCAL oColumn
LOCAL aStruct:=dbStruct()
  default Titel:=Feld
  default numerisch:=.f.

  ignore aender,fkt


  oColumn:=getNewColumn()
  oColumn[COL_NAME]:=Feld
  oColumn[COL_TITEL]:=Titel
  oColumn[COL_BREITE]:=Breite
  if numerisch
    // FIXME: sollte auch den Titel rechtsb�ndig darstellen,
    // dazu fehlt oColumn[COL_NUMERISCH] oder so
    oColumn[COL_FARBE]:=COL_NUMERISCH
  endif
  if farbe<>NIL
    oColumn[COL_FARBE]:=Farbe
  endif
  addMyColumn ( oColumn )

RETURN
/* EOP Felder */

    /* alter the display so that both of the two lines that belong to a record
    are displayed in the highlight color.
    */
function highlightCurrentRow( highlight )
local i,col,colColor,showColor

  /* check which area is to highlight: */
  /** JOJO: watchout: colorrect doesn't take a colorblock !!!
  * takes the n-th color of oBrowse:colorString */

  for i:=1 to M->oBrowse:colCount
    col:=M->oBrowse:getcolumn(i)
    colColor:=eval(col:colorBlock,eval(col:block))
    if highlight
      if colColor<>NIL .and. colColor[1]== RED_ON_WHITE[1]
        showColor:=RED_SELECTED
      elseif colColor<>NIL .and. colColor[1]== GRAY_ON_WHITE[1]
        showColor:=GRAY_SELECTED
      else
        showColor:=STANDARD_SELECTED
      endif
    else
      if colColor<>NIL .and. colColor[1]== RED_ON_WHITE[1]
        showColor:=RED_ON_WHITE
      elseif colColor<>NIL .and. colColor[1]== GRAY_ON_WHITE[1]
        showColor:=GRAY_ON_WHITE
      else
        showColor:=STANDARD_COLOR
      endif
    endif

    M->oBrowse:ColorRect({M->oBrowse:RowPos, i, M->oBrowse:RowPos, i}, showColor )
    if eval(M->secondLine)
      if M->nShowRow = 1
 /* browse is on the first line for this record, so highlight it and
 the following line: */
        M->oBrowse:ColorRect({M->oBrowse:RowPos+1, i, M->oBrowse:RowPos+1, i}, showColor )
      else
        // /* browse is on the second line for this record, so highlight it and
        // the previous line: */
        M->oBrowse:ColorRect({M->oBrowse:RowPos-1, i, M->oBrowse:RowPos-1, i}, showColor )
      endif
    endif
  next

return (Nil)
/** eof */


/* function to skip one record forward a time. if lNoCount is true, eof() was
reached, and nShowRow has to be corrected.
*/
function SkipForw (lNoCount)
  if lNoCount = NIL
    lNoCount:=.F.
  endif
  if lNoCount
    M->nShowRow:=1
  else
    do case
    case M->nShowRow = 1
      if ! eval(M->secondline)
        dbskip()
        /** Filter */
        if eof()
          dbskip( -1 )
          return .f.
        endif
      else
        M->nShowRow ++
      endif
    case M->nShowRow = 2
      M->nShowRow:=1
      dbSkip()
      /** Filter */
      if eof()
        dbskip( -1 )
        if eval(M->secondline)
          M->nShowRow:=2
        endif
        return .f.
      endif
    otherwise
      M->nShowRow:=1
    endcase
  endif
return .t.
  // *****************************************************************************
/* function to skip one record back a time. if lNoCount is true, bof() was
  reached, and nShowRow has to be corrected.
*/
function SkipBack (lNoCount)
LOCAL nTop:=M->oBrowse:RowPos
  if lNoCount = NIL
    lNoCount:=.F.
  endif
  if lNoCount
    dbSkip(-1)
    M->nShowRow:=2
    /** filter */
    if bof()
      return .f.
    endif
  else
    if M->nShowRow = 1
      dbSkip(-1)
      /** filter */
      if bof()
        return .f.
      endif
      if eval(M->secondline)
        M->nShowRow ++
      endif
    else
      M->nShowRow:=1
    endif
  endif
return .t.
  // *****************************************************************************


/** Prints the frame & shade around the TBrowse Window */
STATIC PROCEDURE printFrame()

  // @ M->oBrowse:ntop-1,M->oBrowse:nleft-1 to M->oBrowse:nBottom+1,M->oBrowse:nRight+1 DOUBLE // mit Rahmen
  // FIXME: we could display a customizable title here
  Fenster(M->oBrowse:ntop-1,M->oBrowse:nleft-1,M->oBrowse:nBottom+1,M->oBrowse:nRight+1,,.t.,.t.)
  showArrows()

return
/** eop */


/** prints the arrow left and right if further invisible coluumns exist */
static PROCEDURE showArrows()
    /* auf verdeckte Spalten hinweisen */
  if M->oBrowse:leftvisible > 2
    @ M->oBrowse:nBottom + 1,M->oBrowse:nLeft + 2 say " "+ARROW_LEFT+" "
  endif
  if M->oBrowse:colcount > M->oBrowse:rightvisible
    @ M->oBrowse:nBottom + 1,M->oBrowse:nRight - 2 say " "+ARROW_RIGHT+" "
  endif
return


  // /
/** prints the message at the bottom */
static PROCEDURE bottLineHilfe()
LOCAL i
LOCAL Mess:={}, result:=""

  /* evtl. Message ohne Ctrl_Return , joj sch�ner machen ! */
  if ! ARRAY .and. valtype(M->Datei[D_DISP])=="C"
    if getUser():mayEditData .and. isSpecialHilfeChar(K_F4) == 0
      aadd( mess , " @F4@=�ndern" )
    endif
    if getUser():mayShowData .and. isSpecialHilfeChar(K_F6) == 0
      aadd( mess , " @F6@=Anzeigen" )
    endif
  endif

  if ! empty(alias()) .and. ! ARRAY
    // if M->merkOrdFor==&(ALIAS())->(ordFor())
    if myEmpty( grepFilter )
      aadd( mess , " @F7@/@F8@=Suchen @F9@=Filter" )
    else
      aadd( mess , " @F7@/@F8@=Suchen @F9=Filter@" )
    endif
  endif

  /* extra-Message def. ? */
  if M->SpecialHilfe<>NIL
    for i:=1 to len(M->SpecialHilfe)
      if M->SpecialHilfe[i,HILFE_MESSAGE]<>NIL
        aadd( mess , M->SpecialHilfe[i,HILFE_MESSAGE] )
      endif
    next
  endif

  // now sort and create message
  aSort( Mess )
  aEval( mess , { |x| result += x } )

  result +=" @RETURN@=Auswahl @ESC@=Ende "

  Message( result )

return

/** setzt die index for clause (if any) auf den vorherigen Filter und
den �bergebenen Zusatz-Filter (maybe null) */
STATIC PROCEDURE setMyFilter(zusatz)
LOCAL aktRec,merkOrdKey, merkDescend
LOCAL objErr, bLastHandler

  if ARRAY
    return
  endif

  aktRec:=recno()
  merkOrdKey:=ordKey()
  merkDescend:=OrdDescend()

  // switche zuerst auf org. Index zur�ck, l�sche Spalten-Sortierung
  //sortByColumn()

  bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
  BEGIN SEQUENCE // krit. Bereich
    // clear index to original value
    if zusatz==NIL .or. empty(zusatz)
      // clear index and sort order
      sortByColumn()
    else
      Message("Daten werden gefiltert.   Bitte warten...")

      if empty(M->merkOrdFor)
        // add index clause to original value
        OrdCondSet( zusatz,;// [cForCondition>]
        {|| &(zusatz) }, ; // [<bForCondition>]
        , ; // [<lAllRecords>]
        , ; // [<bWhileCondition>]
        , ; // [<bEval>]
        , ; // [<nInterval>]
        recno(), ; // [<nStart>] ??? why recno() ??? copied from ppo file
        , ; // [<nNext>]
        , ; // [<nRecord>]
        , ; // [<lRest>]
        merkDescend , ; // [<lDescend>]
        , ; // [<reserved>]
        .t. , ; // [<lAdditive>]
        , ; // [<lCurrent>]
        , ; // [<lCustom>]
        , ; // [<lNoOptimize>]
        , ; // [<cWhileCondition>]
        .t. , ; // [<lTemporary>]
        , ; // [<lUseFilter>]
        .t. ) // [<lExclusive>]
      else
        // add index clause to original value
        OrdCondSet( M->merkOrdFor+" .and. "+zusatz,;// [cForCondition>]
        {|| &(M->merkOrdFor+" .and. "+zusatz) }, ; // [<bForCondition>]
        , ; // [<lAllRecords>]
        , ; // [<bWhileCondition>]
        , ; // [<bEval>]
        , ; // [<nInterval>]
        recno(), ; // [<nStart>] ??? why recno() ??? copied from ppo file
        , ; // [<nNext>]
        , ; // [<nRecord>]
        , ; // [<lRest>]
        merkDescend , ; // [<lDescend>]
        , ; // [<reserved>]
        .t. , ; // [<lAdditive>]
        , ; // [<lCurrent>]
        , ; // [<lCustom>]
        , ; // [<lNoOptimize>]
        , ; // [<cWhileCondition>]
        .t. , ; // [<lTemporary>]
        , ; // [<lUseFilter>]
        .t. ) // [<lExclusive>]
      endif

      if empty(merkOrdKey)
        ordCreate(, HILFE_TEMP_INDEX , "" , { || .t. })
      else
        ordCreate(, HILFE_TEMP_INDEX, merkOrdKey, {|| &(merkOrdKey)}, )
      endif

      bottLineHilfe()
    endif

  RECOVER USING objErr
    Error(getErrorDispText(objErr))
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  go (aktRec)

return

/** Gibt den BS nach einem Resize event aus */
static function resizeBS()
LOCAL helpColor:=setcolor(M->aktColor)
  cls
  setcolor(helpColor)
  M->oBrowse:nBottom:=MaxRow()-2
  M->oBrowse:nRight:=MaxCol()-1
  M->oBrowse:nTop:=2
  invalidateAll()
return .t.
/** eop */

/** Stellt den BS komplett neu dar */
function invalidateAll()
  M->nShowRow:=1
  invalidateFooters()
  M->oBrowse:configure()
  M->oBrowse:invalidate():forceStable()
  printFrame()
  bottLineHilfe()
  titel() // print last titel from calling procedure
  M->oBrowse:refreshAll()
return .t.
/** eof */

/** Stellt die Footer neu dar */
function invalidateFooters()
LOCAL i,col,existFooter:=.f.

  for i:=1 to M->oBrowse:ColCount
    col:=M->oBrowse:getcolumn(i)
    if col:footing<>NIL .and. ! empty(col:footing)
      col:Footing:=eval(col:cargo[COL_FOOTER])
      existFooter:=.t.
    endif
  next
  if existFooter
    M->oBrowse:configure()
    bottLineHilfe()
    showArrows()
  endif

return .t.
/** eof */

/** Selects all records */
FUNCTION selectAll()
LOCAL aktRec:=recno(),allreadySelected:=.t.
LOCAL wasSelected

  /** l�sche letzte SHIFT-Range selection */
  toggleTempSelection(NIL,.t.)

  // select all
  go top
  do while ! eof()
    if ! hb_HHasKey(getUser():tempSelected,recno())
      wasSelected:=hb_HHasKey( getUser():tempSelected , recno() )

      // now selected
      getUser():tempSelected[recno()]:=.t.

      // call function on toggling record selection
      if valtype( M->callBackOnToggle ) == "B" .and. ! wasSelected
        eval( M->callBackOnToggle , CALLBACK_SUM )
      endif

      allreadySelected:=.f.
    endif
    skip
  enddo

  if allreadySelected
    deselectAll()
  endif

  invalidateFooters()
  go (aktRec)
return .t.
/** eof */

/** Selects all records */
FUNCTION deselectAll()
  getUser():resetTempSelected()

  // call function on toggling record selection
  if valtype( M->callBackOnToggle ) == "B"
    eval( M->callBackOnToggle , CALLBACK_INIT )
  endif

  invalidateFooters()
return .t.
/** eof */

/** Toggled den Status des aktuellen Datensatzes -> temp. Benutzer Auswahl */
static FUNCTION toggleRecordSelection()
LOCAL selected:=TEMP_CUSTOM_SELECTED

  if selected
    // unselect
    hb_hdel(getUser():tempSelected,recno())
  else
    // select
    getUser():tempSelected[recno()]:=.t.
  endif

  // call function on toggling record selection
  if valtype( M->callBackOnToggle ) == "B"
    eval( M->callBackOnToggle , CALLBACK_SUM )
  endif

  invalidateFooters()

return .t.
/** eof */

/** toggeld das Flag ob ein Datensatz gedruckt werden soll */
function toggleTempSelection(goDown,init)
LOCAL aktRec, wasSelected

  _thread static lastRec

  // reset only?
  if init<>NIL .and. init
    lastRec:=NIL
    return .t.
  endif

  default goDown:=.t.

  // multi selection on shift?
  if (hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_SHIFT )) ;
    .and. lastRec<>NIL

    aktRec:=ordKeyNo()
    deselectAll()

    if aktRec>lastRec
      OrdKeyGoTo(lastRec)
    endif

    // selektier alle zw. letztem und aktuellem
    do while ! eof() .and. ((ordKeyNo()<=lastRec .and. aktRec<=lastRec) .or. ;
      (ordKeyNo()<=aktRec .and. aktRec>lastRec))

      wasSelected:=(hb_HHasKey( getUser():tempSelected , recno() ) .and.;
        getUser():tempSelected[recno()])

      // now selected
      getUser():tempSelected[recno()]:=.t.

      // call function on toggling record selection
      if valtype( M->callBackOnToggle ) == "B" .and. ! wasSelected
        eval( M->callBackOnToggle , CALLBACK_SUM )
      endif

      // M->oBrowse:invalidate()
      skip
    enddo
    OrdKeyGoTo(aktRec)
    M->oBrowse:configure() // Daten neu einlesen & darstellen
    invalidateFooters()

  else // single selection

    toggleRecordSelection()
    if goDown
      // artifical delay to slow down auto-repeat
      inkey(0.1)

      keyboard chr(K_DOWN)
    endif

    // falls selektiert, merke letzte Nr.
    if TEMP_CUSTOM_SELECTED
      lastRec:=ordKeyNo()
    endif

  endif

return .t.
/** eof */

/** Maus-selection nur mit shift oder ctrl */
function MouseToggleTempSelection()
LOCAL iStatus:=hb_gtinfo( HB_GTI_KBDSHIFTS )
  if hb_bitand( iStatus, HB_GTI_KBD_SHIFT ) != 0 .or. hb_bitand( iStatus, HB_GTI_KBD_CTRL ) != 0
    toggleTempSelection(.f.)
  endif
return .t.


/** Pr�ft ob der angegebene Key in der M->SpecialHilfe definiert ist, liefert Position zur�ck, ansonsten 0 */
static function isSpecialHilfeChar(nKey)
LOCAL i

  if M->SpecialHilfe == NIL
    return 0 // not found
  endif

  if nkey<>0
    for i:=1 to len(M->SpecialHilfe)
      // num. Treffer?
      if valtype(M->SpecialHilfe[i,HILFE_KEY])=="N"
        if nKey==M->SpecialHilfe[i,HILFE_KEY]
          return i
        endif
      else // alphanum. Treffer?
        // key < 255 => Keine Harbour keys wegen Mouse Events etc.
        if nKey <= 255 .and. chr(nKey)$M->SpecialHilfe[i,HILFE_KEY]
          return i
        endif
      endif
    next
  endif

return 0 // kein Treffer
/** eof */


/** liefert .t. wenn eines der DB-Felder diesen String enth�lt */
function fieldsContain(s)
LOCAL i
  s:=lower(s)
  for i:=1 to fcount()
    if valtype(fieldget(i))=="C"
      if s $ lower(fieldget(i))
        return .t.
      endif
    endif
  next
return .f.
/** eof */

/** sortiert die Tabelle nach der Spalte (abwechselnd ascending/descending)
  *
  * Parameter: col   0   = nop (clicked outside)
  *                  NIL = Sortierung l�schen
  *                  -1  = nur Anzeige der letzten Sortierung
  *                  n   = sortiert Spalte n, evtl. toggle der order
  */
STATIC PROCEDURE sortByColumn(col)
LOCAL tbColumn,oColumn,aktRec,merkFor

  _thread static lastCol,ascending

  // not for arrays or alike
  if ARRAY
    return
  endif

  aktRec:=recno()
  merkFor:=ordFor()

  // nop falls au�erhalb des Hilfe-Fensters geklickt
  if col==0
    return
  endif

  Message("Liste wird sortiert.  Bitte warten...")

  // change header of old column back to default
  if lastCol<>NIL .and. (lastCol<>col .or. col==NIL)
    tbColumn:=M->oBrowse:getcolumn(lastCol)
    if tbColumn <> NIL
      oColumn:=tbColumn:cargo
      tbColumn:heading:=trim(oColumn[COL_TITEL])
    endif
  endif

  // reset only if no col is specified
  if col==NIL

    // l�sche alten Index
    if lastCol<>NIL .or. col==NIL
      OrdDestroy( HILFE_TEMP_INDEX )
      ordSetFocus(M->aktOrd)
      go (aktRec)
    endif

    lastCol:=NIL
    ascending:=.t.
    bottLineHilfe()
    return
  endif

  if col < 0

    if lastCol == nil
      return
    endif

    // hole aktuelle Spalte (unver�ndert)
    tbColumn:=M->oBrowse:getcolumn(lastCol)
    oColumn:=tbColumn:cargo

  else // col > 0

    // hole aktuelle Spalte
    tbColumn:=M->oBrowse:getcolumn(col)
    oColumn:=tbColumn:cargo

    // sort order
    if lastCol==NIL .or. lastCol<>col
      lastCol:=col
      ascending:=.t.
    else
      ascending:=!ascending
    endif

  endif

  // now create index
  // three criterias: ascending/descending, for clause yes/no, filter in oBrowse:cargo yes/no
  if ascending
    tbColumn:heading:=trim(oColumn[COL_TITEL])+space(1)+CHAR_ASCENDING
  else // descending
    tbColumn:heading:=trim(oColumn[COL_TITEL])+space(1)+CHAR_DECENDING
  endif

  if col > 0

    // l�sche alten Index
    if lastCol<>NIL .or. col==NIL
      OrdDestroy( HILFE_TEMP_INDEX )
      ordSetFocus(M->aktOrd)
      go (aktRec)
    endif

    // instead of: index on &(oColumn[COL_NAME]) tag HILFE_TEMP_INDEX 
    // TEMPORARY ADDITIVE DESCENDING for &(aktForClause) .and. eval(M->oBrowse:cargo)
    OrdCondSet( merkFor, ; // [cForCondition>]
    if(empty(merkFor),NIL,merkFor), ; // [<bForCondition>];
    , ; // [<lAllRecords>];
    , ; // [<bWhileCondition>];
    , ; // [<bEval>];
    , ; // [<nInterval>]
    recno(), ; // [<nStart>] ??? why recno() ??? copied from ppo file;
    , ; // [<nNext>];
    , ; // [<nRecord>];
    , ; // [<lRest>]
    ! ascending , ; // [<lDescend>];
    , ; // [<reserved>]
    .t. , ; // [<lAdditive>];
    , ; // [<lCurrent>];
    , ; // [<lCustom>];
    , ; // [<lNoOptimize>];
    , ; // [<cWhileCondition>]
    .t. , ; // [<lTemporary>];
    , ; // [<lUseFilter>]
    .t. ) // [<lExclusive>]

    if oColumn[COL_SORT]==NIL
      ordCreate(, HILFE_TEMP_INDEX, (oColumn[COL_NAME]), {|| &(oColumn[COL_NAME])}, )
    else
      ordCreate(, HILFE_TEMP_INDEX, (oColumn[COL_SORT]), {|| &(oColumn[COL_SORT])}, )
    endif

    go (aktRec)
  endif

  bottLineHilfe()

return
/** eop */

/** handelt die Eingabe und Ausgabe eines Suchtextes */
STATIC PROCEDURE suchTextInput( nKey )
LOCAL Merk_Satz:=recno()
LOCAL suchZeig, aktIndex
LOCAL preSuche,ind1,ind2,n

  // ARrray Suche
  if ARRAY
    preSuche:=M->such
    M->such:=M->such+upper(chr(nKey))
    // search plain string array or 1st column of array if multiple columns
    if len(M->aArray) > 0 .and. len(M->aArray[1]) > 1
      n:=aScan( M->aArray , { |x| upper(left(x[1],len(M->Such))) == M->Such } )
    else
      n:=aScan( M->aArray , { |x| upper(left(x,len(M->Such))) == M->Such } )
    endif

    if n = 0
      M->such:=preSuche
    else
      // Update M->nRow to jump to the found array position
      M->nRow:=n
      M->oBrowse:refreshAll()
    endif
    return
  endif


  if ! ARRAY .and. len( M->such ) == 0 // immer nur 1x
    M->Datei:=db_info(alias())

    // folgendes jetzt in suchTextInput only
    // if ! valtype(such_init)=="U"
    // M->such:=such_init
    // M->such_Neu:=such_Init
    // else
    // M->such_Neu:=""
    // M->such:=M->such_Neu
    // endif
    // M->such:=M->such+if(valtype(oGet:buffer)=="C",trim(oGet:buffer),"")

    /* finde ersten Datensatz */
    if len(Indexkey(0)) > 0 .and. len( M->such ) > 0
      M->oBrowse:goTop() // we need this to ensure oBrowse is properly initialized
      suchZeig:=M->Such
      seek M->such

      /* evtl. geshiftetes Feld */
      if eof()
        if M->Datei[D_ART] $ "NS" .and. len(M->such)<getKeyFieldLen(M->datei)
          if M->Datei[D_ART]=="S"
            M->such:=M->Such_Neu+replicate(SHIFT_CHAR,getKeyFieldLen(M->datei)-len(SUCH_NEU))+;
              SUCH_NEU
          else
            M->such:=M->Such_Neu+replicate("0",getKeyFieldLen(M->datei)-len(SUCH_NEU))+SUCH_NEU
          endif
          seek M->such
          if eof()
            if (M->Datei[D_ART]=="S" .and. left(SUCH_NEU,1)=SHIFT_CHAR);
              .or. (M->Datei[D_ART]=="N" .and. left(SUCH_NEU,1)="0")
              M->such:=suchZeig
            else
              M->oBrowse:goTop()
              M->such:=M->Such_Neu
            endif
          endif
        else
          M->oBrowse:goTop()
          M->such:=M->such_Neu
        endif
      endif
    else
      M->oBrowse:goTop()
      M->such:=M->such_Neu
    endif
  endif
  If len(INDEXKEY(0)) > 0 .and. M->aktOrd > 0 .and. ! ARRAY // nur falls Index vorhanden

    /* Index umschalten  ? */
    if valtype(M->Datei[D_TOGGLE_INDEX])=="L" .and. M->Datei[D_TOGGLE_INDEX] ;
      .or. valtype(M->Datei[D_TOGGLE_INDEX])=="A"
      // find index number to toggle
      ind1:=1 // default
      ind2:=2 // default
      if valtype(M->Datei[D_TOGGLE_INDEX])=="A"
        n:=ascan(M->Datei[D_TOGGLE_INDEX],{|aArr| aArr[1]==indexOrd() .or. aArr[2]==indexOrd()})
        if n>0
          ind1:=M->Datei[D_TOGGLE_INDEX,n,1]
          ind2:=M->Datei[D_TOGGLE_INDEX,n,2]
        endif
      endif

      // schalte Spaltensortierungvor�bergehend aus
      if ordNumber( HILFE_TEMP_INDEX ) == indexOrd()
        aktIndex:=ordNumber( HILFE_TEMP_INDEX )
        ordSetFocus( ind1 )
      endif

      // now switch index
      if ISDIGIT(chr(nKey))
        if INDEXORD()=ind2 .and. ! empty(ordKey(ind1))
          //sortByColumn()
          M->such:=M->such_Neu
	  OrdSetFocus(ind1)     /* 1. Index immer der "num." */
          @ M->oBrowse:nBottom + 1,M->oBrowse:nLeft to M->oBrowse:nBottom +1,;
            M->oBrowse:nRight DOUBLE
          M->oBrowse:refreshAll()
        endif
      else
        if INDEXORD()=ind1 .and. ! empty(ordKey(ind2))
          //sortByColumn()
          M->such:=M->such_Neu
          OrdSetFocus(ind2)
          @ M->oBrowse:nBottom + 1,M->oBrowse:nLeft to M->oBrowse:nBottom +1,;
            M->oBrowse:nRight DOUBLE
          M->oBrowse:refreshAll()
        endif
      endif
    else
      // no toggle index

      // schalte Spaltensortierungvor�bergehend aus
      if ordNumber( HILFE_TEMP_INDEX ) == indexOrd()
        aktIndex:=ordNumber( HILFE_TEMP_INDEX )
        ordSetFocus( M->aktOrd )
        // ordSetFocus( 1 ) // default falls kein toggle
      endif

    endif

    /* falls vorher geshiftet */
    if ( M->Datei[D_ART]=="S" .and. left(SUCH_NEU,1)==SHIFT_CHAR );
      .or. ( M->Datei[D_ART]=="N" .and. left(SUCH_NEU,1)=="0" )
      M->such:=M->Such_Neu+right(SUCH_NEU,len(SUCH_NEU)-1)
    endif

    preSuche:=M->such
    M->such:=M->such+upper(chr(nKey))
    SEEK M->such

    // neue shift logik definiert in hilfdef: 20221106
    if M->suchShiftRight .and. eof()
      suchZeig:=M->Such
      M->such:=trim(M->Such)
      do while eof() .and. len(M->such) <= len(suchZeig)
        M->such:=" " + M->Such
        seek M->such
      enddo
      if eof()
        M->Such:=suchZeig
      endif
    endif

    // falls vorher Spalte sortiert unf Filter gesetzt
    // pr�fe ob Treffer in Filter enthalten
    if aktIndex <> NIL .and. ! myempty( grepFilter )
      do while ! eof() .and. ! fieldsContain(grepFilter)
        skip
      enddo
    endif

    /* evtl. geshiftetes Feld */
    if eof()
      suchZeig:=M->Such // merke ungeshiftetes Feld
      if M->Datei[D_ART] $ "NS" .and. len(SUCH_NEU)<getKeyFieldLen(M->datei)
        if M->Datei[D_ART]=="S"
          M->such:=M->Such_Neu+replicate(SHIFT_CHAR,getKeyFieldLen(M->datei)-len(SUCH_NEU))+;
            SUCH_NEU
        else
          M->such:=M->Such_Neu+replicate("0",getKeyFieldLen(M->datei)-len(SUCH_NEU))+SUCH_NEU
        endif
        seek M->such
        if eof()
	  /* Suche erfolglos */
          go Merk_Satz
          // removed 20.3.2012
	  // /* falls Shift-L�nge nicht ersch�pft, wieder Ursprungs-Suchwert */
          // if (M->Datei[D_ART]=="S" .and. left(SUCH_NEU,1)=SHIFT_CHAR)
          // .or. (M->Datei[D_ART]=="N" .and. left(SUCH_NEU,1)="0")
          // M->such:=suchZeig
          // else
          beep()
          M->such:=preSuche
        else
          M->oBrowse:refreshAll()
        endif
      else
	/* kein geshiftetes Feld, Suche erfolglos */
        beep()
        go Merk_Satz
        M->such:=preSuche
      endif
    else
      M->oBrowse:refreshAll()
    endif
  endif

  // schalte Spaltensortierung wieder ein, if applicable
  if aktIndex <> NIL
    OrdSetFocus( aktIndex )
  endif

return
  /** eop */

/** handelt die Eingabe und Ausgabe eines Suchtextes */
procedure suchTextInit(oGet,such_init)
LOCAL Merk_Satz:=recno()
LOCAL suchZeig

  if ! ARRAY .and. len( M->such ) == 0 // immer nur 1x
    M->Datei:=db_info(alias())
    if ! valtype(such_init)=="U"
      M->such:=such_init
      M->such_Neu:=such_Init
    else
      M->such_Neu:=""
      M->such:=M->such_Neu
    endif
    M->such:=M->such+if(valtype(oGet:buffer)=="C",trim(oGet:buffer),"")

    // special case Kund.Nr => "-" raus
    // if oGet:picture == KDNR_PICT
    // M->Such:=alltrim( strTran( M->Such , "-" ) )
    // endif

      /* finde ersten Datensatz */
    if len(Indexkey(0)) > 0 .and. ! empty( M->such )
      M->oBrowse:goTop() // we need this to ensure oBrowse is properly initialized
      seek M->such
        /* evtl. geshiftetes Feld */
      if eof()
        suchZeig:=M->Such
        if M->Datei[D_ART] $ "NS" .and. len(M->such)<getKeyFieldLen(M->datei)
          if M->Datei[D_ART]=="S"
            M->such:=M->Such_Neu+replicate(SHIFT_CHAR,getKeyFieldLen(M->datei)-len(SUCH_NEU))+;
              SUCH_NEU
          else
            M->such:=M->Such_Neu+replicate("0",getKeyFieldLen(M->datei)-len(SUCH_NEU))+SUCH_NEU
          endif
          seek M->such
          if eof()
            if (M->Datei[D_ART]=="S" .and. left(SUCH_NEU,1)=SHIFT_CHAR);
              .or. (M->Datei[D_ART]=="N" .and. left(SUCH_NEU,1)="0")
              M->such:=suchZeig
            else
              M->oBrowse:goTop()
              M->such:=M->Such_Neu
            endif
          endif
        else
          M->oBrowse:goTop()
          M->such:=M->such_Neu
        endif
      endif
    else
      M->oBrowse:goTop()
      M->such:=M->such_Neu
    endif
  endif
  suchTextDisplay()
return
  /** eop */

static procedure suchTextDisplay()
  /* anzeigen des M->suchtextes */
  if M->such==M->such_Neu // leer
    @ M->oBrowse:nBottom + 1,M->oBrowse:nLeft to M->oBrowse:nBottom +1,M->oBrowse:nRight DOUBLE
  else
    @ M->oBrowse:nBottom + 1,M->oBrowse:nLeft-10+(M->oBrowse:nRight-M->oBrowse:nLeft)/2 say ;
      " SuchText: "+substr(M->Such,len(M->Such_Neu)+1,len(M->such))+" "
  endif
  showArrows()
return
  /** eop */



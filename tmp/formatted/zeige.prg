#include "zeige.ch"
#include "MyStd.ch"
#include "Setcurs.ch"

#include "hbgtinfo.ch"
#include "hbthread.ch"

// #include "xbp.ch"

REQUEST HB_GT_WVT_DEFAULT
REQUEST HB_GT_WIN

// NOT _thread static, since we need this for thread synchronisation
static threadMutex, threads:={}

#xtranslate nOffSet => M->_aSysStuff\[ 01 \]
#xtranslate nBotRow => M->_aSysStuff\[ 02 \]
#xtranslate nBoxTop => M->_aSysStuff\[ 03 \]
#xtranslate nTopRec => M->_aSysStuff\[ 04 \]
// #xtranslate cGetStr => M->_aSysStuff\[ 05 \]
#xtranslate current => M->_aSysStuff\[ 06 \]
#xtranslate currentPrintJob => M->_aSysStuff\[ 07 \]

/** aktuelle Zeile zu Beginn ! */
#define START_CURRENT 5

/** Zeichen von rechts bei denen im Header nach dem Begriff "Seite" gesucht wird */
#define NUM_HEADER_PAGE_CHR 12

/*
*   Routine: ZeigeText()
*          :
*/
function ZeigeText(zeigeAlias,jobName,callerName,popupAllowed)
local getlist as array
local aDbfArr_ as array
local cTmpScrn as char
local cPhrase as char
local nKey as int
local nTotRecs as int
local nNewRec as int
local nOldTop as int
local lFlag as logical
local aktRec

Local sizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
Local sizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
LOCAL posx:=hb_gtInfo( HB_GTI_SETPOS_XY )[1]
LOCAL posy:=hb_gtInfo( HB_GTI_SETPOS_XY )[2]
Local fullScreen:=hb_gtInfo(HB_GTI_ISFULLSCREEN)
Local fontMode:=hb_gtInfo(HB_GTI_RESIZEMODE)
Local tempPos,tempSizeX,tempSizeY,tempFullscreen,tempIcon,i
Local xResult,tempID,tempUser,tempFontName,tempFontSize,tempFontWidth,tempFontBold
LOCAL bLastHandler, objErr, tempVal, kopieZeige, merkZeige, allLineValues
LOCAL lockError

  _thread static cGetStr:=""

MEMVAR _aSysStuff

PRIVATE _aSysStuff:={ NIL, NIL, NIL, NIL, NIL, NIL, NIL}

  default callerName:=procname(3)
  nTopRec:=1

  if zeigeAlias==NIL // kein popup/Multithread

    Umgebung(WRITE)

    // don't resize font => use additional resize space for additional columns
    hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_ROWS )

  else

    // Remember font
    tempFontName:=hb_gtInfo( HB_GTI_FONTNAME )
    tempFontBold:=hb_gtInfo( HB_GTI_FONTWEIGHT )
    tempFontWidth:=hb_gtInfo( HB_GTI_FONTWIDTH )
    tempFontSize:=hb_gtInfo( HB_GTI_FONTSIZE )
    tempIcon:=hb_gtInfo( HB_GTI_ICONFILE)

    /* allocate own GT driver */
    hb_gtReload( "WVT" )

    // don't resize font => use additional resize space for additional columns
    hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_ROWS )

    default jobname:="Liste"
    // //JobName+"   Anzeige: "+zeigeAlias)
    hb_gtInfo( HB_GTI_FONTNAME ,tempFontName )
    hb_gtInfo( HB_GTI_FONTWEIGHT,tempFontBold )
    hb_gtInfo( HB_GTI_FONTWIDTH ,tempFontWidth)
    hb_gtInfo( HB_GTI_FONTSIZE ,tempFontSize )

    hb_gtInfo( HB_GTI_WINTITLE, JobName )
    hb_gtInfo( HB_GTI_ALTENTER, .T. ) // allow alt-enter for full screen
    hb_gtInfo( HB_GTI_CLOSABLE, .F. )
    hb_gtInfo( HB_GTI_ICONFILE, tempIcon )

    addThread()

  endif

  // debug
  if trim(callerName)=="BS"
    if DEVEL_PROG
      altd() // if devel only, is okay here!
    endif
    trouble("BS-Liste",stacktrace())
  endif

  if ! open("Fenster")
    Error(ACHTUNG+"Fenster-Groesse kann nicht gesetzt werden.|"+callerName+"???",.t.,"root")
  else
    tempUser:=getUser():getWindowStorageID()
    select Fenster
    FENSTER->(dbseek(left(callerName+space(10),10)+left(tempUser+space(10),10)))
    if FENSTER->(eof()) // Liste von User zum 1. Mal geöffnet
      if zeigeAlias<>NIL .and. getUser():saveWinPos // nur bei Popup-Fenster
        qout(" ") // needed as workaround for bug in setPos
        hb_gtInfo(HB_GTI_SETPOS_XY,{posX,posY})
        // hb_gtInfo(HB_GTI_SETPOS_XY,{posX+25*len(threads),posY+25*len(threads)})
      endif
    else
      // setze aktuelle Fenster-Groesse & Position
      if FENSTER->Maximized=="J" .and. getUser():saveWinSize
        hb_gtInfo(HB_GTI_ISFULLSCREEN,.t.)
      else
        if FENSTER->SizeX>0 .and. getUser():saveWinSize
          qout(" ") // needed as workaround for bug in setSize
          hb_gtInfo(HB_GTI_SCREENSIZE , { FENSTER->SizeX, FENSTER->SizeY } )
        endif
        if getUser():saveWinPos
          qout(" ") // needed as workaround for bug in setPos
          if zeigeAlias<>NIL // nur bei Popup-Fenster
            hb_gtInfo(HB_GTI_SETPOS_XY,{ FENSTER->PosX+20, FENSTER->PosY+20} )
          else
            hb_gtInfo(HB_GTI_SETPOS_XY,{ FENSTER->PosX, FENSTER->PosY} )
          endif
        endif
      endif
    endif
  endif

  set scoreboard off
  setcursor( SC_NONE )
  setcolor(ZEIGE_COLSTD)
  @ 1,0 clear
  // cls
  // Titel("")

  // remember current print job
  currentPrintJob:=getUser():getCurrentPrintJob()

  // must do file wide statics for each call
  // nBotRow:=23
  nBotRow:=MaxRow()-1
  nOffSet:=1
  nBoxTop:=1 // Top Row of box. -> wird evtl. in showHeader �berschrieben

  if zeigeAlias==NIL // kein popup/Multithread
    select Zeige
  else
    // using Harbour mt we work on al temp. copy of the zeige.dbf
    select 0
    use (zeigeAlias) excl alias Zeige
  endif

  // l�sche trailing empty lines
  go bottom
  do while ! bof() .and. empty(ZEIGE->Line)
    delete
    skip -1
  enddo
  pack
  ZEIGE->(dbgotop())
  nTotRecs:=lastrec()

  if ShowHeader()
    current:=nBoxTop
  else
    current:=nBoxTop + Min( START_CURRENT , nTotRecs )
  endif

  // Paint first screen.
  ShowLINS()
  ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))

  BottLineZeige(popupAllowed)

  lFlag:=.F.

  while .t.
    dispLineNumber()
    setcolor(ZEIGE_COLSTD)

    nKey:=nil
    do while nKey==NIL .or. nKey==0
      // nKey:=warte(1, INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN + INKEY_MWHEEL)
      nKey:=warte(0, INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN + INKEY_RDOWN + INKEY_MWHEEL)

      if zeigeAlias<>NIL // popup/Multithread
        // check whether User wants to quit (Master thread)
        if hb_mutexSubscribe( threadMutex, 0.01 , @xResult )
          if valtype( xResult ) == "L" .and. xResult
            close Zeige
            ferase(zeigeAlias)
            removeThread()
            return .f.
          endif
        endif
      endif

    enddo

    // debugging "workarea not index" error
    // if getUser():id $ "MW/JG"
    // trouble("bespost","zeige.prg->Taste:"+str(nKey))
    // endif


    do case
    case nKey == K_ESC .or. nKey == K_RBUTTONDOWN // Escape und rechte Maus-Taste beendet Zeige
      if currentPrintJob:className()=="BSJOB"
        cTmpScrn:=SAVESCREEN()
        if currentPrintJob:confirmEnd .and.;
          message("Liste beenden?  Sind Sie sicher? (@J@/@N@)","JN"," ")<>"J"
          restscreen(,,,,cTmpScrn)
          loop
        endif
      endif
      select Zeige
      // l�sche Tast.Puffer
      SetLastKey(0)
      exit
    case nKey == ZEIGE_RESULT // Benutzer Auswahl, lastkey wird nicht gel�scht!
      select Zeige
      exit
    case nKey == K_RIGHT
      if nOffSet < 240
        nOffSet:=nOffSet +2
      endif

      ZEIGE->(dbgoto(nTopRec))
      ShowHeader()
      showlins()

    case nKey == K_LEFT
      if nOffSet >= 2
        nOffSet:=nOffSet -2
      endif

      ZEIGE->(dbgoto(nTopRec))
      ShowHeader()
      showlins()

    case nKey == K_HOME
      ZEIGE->(dbgoto(1))
      nTopRec:=1
      current:=nBoxTop
      ShowHeader()
      showlins()

    case nKey == K_CTRL_HOME // wie home nur offset auch 0
      ZEIGE->(dbgoto(1))
      nTopRec:=1
      current:=nBoxTop
      nOffSet:=1
      ShowHeader()
      showlins()

    case nKey == K_END
      if nTotRecs >= nBotRow-nBoxTop
        go bottom
        do while ! bof() .and. empty(ZEIGE->Line)
          skip -1
        enddo
        skip - (nBotRow-nBoxTop) + 1
        if bof()
          go top
        endif
        current:=nBotRow-1
      else
        // ZEIGE->(dbgoto(1))
        go bottom
        current:=nBoxTop
      endif

      nTopRec:=RECNO()
      showlins()

    case nKey == K_PGDN .or. nKey==K_SPACE
      if nTopRec + nBotRow-nBoxTop <= nTotRecs
        nTopRec:=nTopRec+nBotRow-nBoxTop
        ZEIGE->(dbgoto(nTopRec))
        showlins()
      else
        beep()
      endif

    case nKey == K_PGUP
      nNewRec:=nTopRec - (nBotRow-nBoxTop)
      if nNewRec > 0
        nTopRec:=nNewRec
      else
        nTopRec:=1
      endif

      ZEIGE->(dbgoto(nTopRec))
      showlins()

    case nKey == K_UP .or. nKey == K_MWFORWARD // Mouse-Wheel
      /** hervorgehobenen wieder lowlighten */
      if recno() == 1
        beep()
      else
        ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
        colorSay( current,0,FIELD->line,.f.,nOffSet )

        if current > nBoxTop
          skip -1
          if current > nBoxTop
            current--
          endif
          colorSay( current,0,FIELD->line,.t.,nOffSet)
        else
          if nTopRec > 1
            SCROLL(nBoxTop,0,nBotRow,maxCol(),-1)
            // Got to the new record.
            nTopRec:=nTopRec -1
            ZEIGE->(dbgoto(nTopRec))
            colorSay( nBoxTop,0,FIELD->line,.t.,nOffSet)
          else
            // If we are at the 1st record already, do nothing.
          endif
        endif
      endif


    case nKey == K_DOWN .or. nKey == K_MWBACKWARD // Mouse-Wheel
      /** hervorgehobenen wieder lowlighten */
      if current - nBoxTop + 1 == reccount() // removed 21030902: .or. eof() (but why was it there?)
        beep()
      elseif current - nBoxTop + 1 > reccount()
        // von Anfang an weniger Zeilen als Start-Reihe
        // neue Zeile highlighten
        keyboard chr(K_END)
      else
        ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
        colorSay( current,0,FIELD->line,.f.,nOffSet)

        if current < nBotRow
          skip 1
          if current < nBotRow
            current++
          endif
          colorSay( current,0,FIELD->line,.t.,nOffSet)
        else
          if nTopRec - nBoxTop + nBotRow < nTotRecs
            SCROLL(nBoxTop,0,nBotRow,maxCol(),1)
            nTopRec:=nTopRec+1
            ZEIGE->(dbgoto(nTopRec + nBotRow - nBoxTop))
          endif
          colorSay( nBotRow,0, FIELD->line,.t.,nOffSet)
        endif
      endif


      // help requested
    case nKey == 28 .or. nKey == 72 .or. nKey == 104 .or. nKey == 63
      cTmpScrn:=SAVESCREEN()

      // cls
      setcolor(ZEIGE_COLHIGH)
      Fenster(6,8,19,72,"Hilfe")

      @07,9 say " Cursor Links   - 20 Zeichen nach links"
      @08,9 say " Cursor Rechts  - 20 Zeichen nach rechts"
      @09,9 say " Cursor       - Zeile hoch / runter"
      @10,9 say " Bild-Hoch      - Seite hoch"
      @11,9 say " Bild-Runter    - Seite runter"
      @12,9 say " Home           - Gehe an den Anfang"
      @13,9 say " End            - Gehe ans Ende"
      @14,9 say " F7/F8 Suche    - ignoriere Gross/Kleinschreibung"
      @15,9 say " D  Drucke      - Drucke Liste"
      @16,9 say " STRG -P        - Druckerauswahl f�r Druck"
      @17,9 say " P  PDF  Datei  - Exportiere nach PDF Datei"
      @18,9 say " A  ASCI Datei  - Exportiere nach ASCI Datei"
      setcolor(ZEIGE_COLSTD)

      if warte(0, INKEY_KEYBOARD + HB_INKEY_GTEVENT ) == HB_K_RESIZE
        resizeBS()
      else
        restscreen(,,,,cTmpScrn)
      endif

    case nKey == K_CTRL_P
      #ifndef NO_XBP
      PrintDialog(jobName,callerName)
      #else
      // nop
      #endif

      // Send screenshot & debug information
    case nKey == KEY_SCREENSHOT
      sendScreenShot()

    case nKey == 68 .or. nKey ==100 // KEY_D
      drucke_Zeige(jobName,callerName) // auf default drucker

    case nKey == 65 .or. nKey ==97 // KEY_A
      drucke_Asc()

    case nKey == 112 .or. nKey==80
      create_PDF(jobName,callerName)

      // User wants to locate a string.
    case nKey == 83 .OR. nKey == 115 .or. nKey==K_F7 .or. nKey==250 // KEY_S
      nOldTop:=nTopRec
      ZEIGE->(dbgoto(nTopRec))
      // setcolor("I") // what is this???
      @maxrow(),0 say space(maxCol())

      setcursor(DEUTE_MARKE)
      cGetStr:=left(trim(cGetStr)+replicate(" ",25),25)
      @maxrow(),00 say "Suche nach:" GET cGetStr picture "@K"
      QQout(space(3)+"F8 = weitersuchen")

      // read now - with exit on resize events
      ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
      setcursor(SC_NONE)
      if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
        resizeBS()
      else
        if ABBRUCH
          cGetStr:=""
        endif

        if !empty(cGetStr)
          // cPhrase:=chr(34) + trim(cGetStr) + chr(34)
          cPhrase:=trim(lower(cGetStr))
          skip -Min(nBotRow-nBoxTop-1,reccount()-recno()-1) // noch optimieren ! jojo
          LOCATE FOR cPhrase $ LOWER(ZEIGE->line) NEXT 1000000
          if eof()
            Message("Nicht gefunden.           Bitte @Taste@ dr�cken.")
            nKey:=warte(0)
            nTopRec:=nOldTop
            ZEIGE->(dbgoto(nTopRec))
          else
            nTopRec:=ZEIGE->(recno())
            current:=nBoxTop
          endif
          lFlag:=.T.
        endif

        setcolor(ZEIGE_COLSTD)
        showlins()
        BottLineZeige()
      endif
      GetList:={} ; ( GetList )

      // case nKey == 71 .or. nKey == 103 // KEY_G
      // cGetStr:=left(trim(cGetStr)+replicate(" ",25),25)
      // nOldTop:=nTopRec
      // ZEIGE->(dbgoto(nTopRec))
      // setcolor("I")
      // setcursor(DEUTE_MARKE)
      // @maxRow(),0 say space(maxCol())
      // @maxRow(),0 say "Suche nach ? " GET cGetStr
      // READ
      // setcursor(SC_NONE)

      // cPhrase:=chr(34) + trim(cGetStr) + chr(34)
      // if !empty(cGetStr)
      // cGetStr:=TRIM(cGetStr)
      // LOCATE NEXT 1000000 FOR cGetStr $ ZEIGE->line
      // if eof()
      // Message("Nicht gefunden.           Bitte @Taste@ dr ken.")
      // nKey:=warte(0)
      // nTopRec:=nOldTop
      // ZEIGE->(dbgoto(nTopRec))
      // else
      // nTopRec:=recno()
      // endif
      // lFlag:=.T.
      // endif

      // setcolor(ZEIGE_COLSTD)
      // showlins()
      // BottLineZeige()

      // User wants to find the next occurrence.
    case nKey == 78 .or. nKey == 110 .or. nKey==K_F8
      if ! lFlag
        keyboard chr(K_F7)
        loop
      else
        // ZEIGE->(dbgoto(nTopRec)) , jojo so gibts kein Ende
        skip -Min(nBotRow-nBoxTop-1,reccount()-recno()-1) // noch optimieren ! jojo
        CONTINUE
        if eof()
          beep()
          setcolor("I")
          // Message("Nicht mehr gefunden.           Bitte @Taste@ dr ken.")
          // nKey:=warte(0)
          // nTopRec:=nOldTop
          ZEIGE->(dbgoto(nTopRec))
        else
          nTopRec:=recno()
        endif
        setcolor(ZEIGE_COLSTD)
        showlins()
        BottLineZeige()
      endif
      // special Function
    case valtype(M->specialZeige)=="A" .and. ;
      (i:=ascan( M->SpecialZeige , { |aArr| chr(nKey)$aArr[ZEIGE_KEY] } )) > 0
      aktRec:=ZEIGE->(recno())
      ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
      merkZeige:=M->SpecialZeige

      // now erase zeige.dbf so we work on a clean copy
      Umgebung(WRITE_ALL)
      select Zeige
      tempVal:=ZEIGE->Line
      allLineValues:=getCurrentValues()
      kopieZeige:=;
        TEMP+"\T"+getUser():getLongID()+getUser():getTempCounter()+".dbf"
      copy to (kopieZeige)
      zap

      // now eval the custom function
      eval( M->SpecialZeige[i,ZEIGE_FUNKTION] , tempVal , allLineValues )

      // recover
      Umgebung(LOAD)
      select Zeige
      zap
      appe from (kopieZeige)
      ferase( (kopieZeige) )

      go (aktRec)
      M->SpecialZeige:=merkZeige

      // Mouse / Maus clicks
    case nKey == K_LBUTTONDOWN
      if mrow() >= nBoxTop .and. mrow() < nBotRow .and. (mrow()+nTopRec - 2 < reccount())
        // alte Zeile lowlighten
        ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
        colorSay( current,0,FIELD->line,.f.,nOffSet )

        // neue Zeile highlighten
        current:=mrow()
        ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
        colorSay( current,0,FIELD->line,.t.,nOffSet)
      endif

      // case nkey == K_LDBLCLK
      // nop, should be defined via M->SpecialZeige

      // checks and launches setkeys, e.g. launch new programm for displaying Artikel, Kunden
    case HB_SetKeyGet(nKey) <> NIL // setkey gesetzt??
      bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
      aktRec:=ZEIGE->(recno())
      BEGIN SEQUENCE
        ZEIGE->(dbgoto( current - nBoxTop + nTopRec ))
        HB_SetKeyCheck( nKey , procName() , NIL , NIL )
      RECOVER USING objErr
        email(MY_EMAIL,"ERROR: SetKey:"+str(nKey)+" failed in Edit.",getErrorText(objErr))
      END SEQUENCE
      go (aktRec)
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

      // open new window showing this list
    CASE nKey == K_F4
      IF hb_MTVM() .and. ! NO_POPUP .and. popupAllowed
        select Zeige
        // we need to work on a local copy
        tempID:=CT_INC
        #define TEMP_ZEIGE_MT (TEMP_USER+BACKSLASH+"zeig"+getUser():counter+tempID+".dbf")
        copy to (TEMP_ZEIGE_MT)
        hb_threadStart(HB_THREAD_INHERIT_PUBLIC, @ZeigeText(),TEMP_ZEIGE_MT,jobname,callerName,.f.)
        // last parameter: disallow popup on already popped-up list!
      endif

      // Harbour resize & focus events
    CASE nKey == HB_K_GOTFOCUS
      // nop
    CASE nKey == HB_K_LOSTFOCUS
      // nop
    CASE nKey == HB_K_CLOSE
      exit

    CASE nKey == HB_K_RESIZE
      resizeBS()

    endcase
  enddo


  /** was windows resized? => set default size */

  // schreibe aktuelle Fenster-Groesse & Position
  if select("Fenster")>0 .and. trim(callerName)<>"BS"
    select Fenster

    tempUser:=getUser():getWindowStorageID()
    select Fenster
    FENSTER->(dbseek(left(callerName+space(10),10)+left(tempUser+space(10),10)))
    lockError:=.f.
    if FENSTER->(eof()) // Liste von User zum 1. Mal geöffnet
      if ! add_rec(5)
        Error(ACHTUNG+"Fenster-Groesse kann nicht gespeichert werden.",.t.)
        lockError:=.t.
      else
        replace FENSTER->LISTE_KURZ with callerName
        replace FENSTER->Kurzel with tempUser
      endif
    else
      rec_lock(5)
    endif

    if ! lockError
      tempsizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
      tempsizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
      temppos:=hb_gtInfo( HB_GTI_SETPOS_XY )
      tempFullscreen:=hb_gtInfo( HB_GTI_ISFULLSCREEN)
      replace FENSTER->PosX with max(temppos[1],0)
      replace FENSTER->PosY with max(temppos[2],0)
      replace FENSTER->SizeX with tempsizeX
      replace FENSTER->SizeY with tempsizeY
      replace FENSTER->Maximized with if(tempFullscreen,"J","N")
      dbcommit()
      dbunlock()
    endif

  endif

  if zeigeAlias==NIL // kein popup/Multithread
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
    // close Zeige , geht schief bei rek. Aufruf, z.B. Stuckliste aufl�sen F5
    Umgebung(LOAD)
  else
    close data
    ferase(zeigeAlias)
    removeThread()
  endif

return nil

/*
*   Routine: ShowLins()
*          :
*   Purpose: Used to display contents of file to the screen in full pages.
*          :
* Arguments: void
*          :
*  Comments: void
*          :
*/
static function showlins()
local lastrow as int
LOCAL X

  @ nBoxTop, 0 CLEAR TO nBotRow,maxCol()

  x:=nBoxTop

  while .not. eof() .and. x <= nBotRow
    colorSay( x,0,ZEIGE->line,(current==x),nOffSet)
    ZEIGE->(dbskip())
    x += 1
  enddo
  lastrow:=x-1
return .t.
/** eof */


/*
*   Routine: ShowHeader
*          :
*   Purpose: displays fixed first few header lines if BSJob:fixedHeaderLines > 0
*          :
*/
STATIC FUNCTION ShowHeader()
LOCAL x:=1 , aktRec:=ZEIGE->( recno() )
LOCAL aktColor:=setcolor(), line , newLine, pos
LOCAL headerLines:=currentPrintJob:getFixedHeaderLines()
LOCAL result

  if ( result:=len( headerLines ) > 0 )

    @ x, 0 CLEAR TO nBotRow,maxCol()

    setcolor( LIGHT_GRAY )
    for each line in headerLines
      line:=trim(line)

      // suche nach Seite in den letzten NUM_HEADER_PAGE_CHR Stellen
      if (pos:=at( "SEITE" , upper( right( trim( line ) , NUM_HEADER_PAGE_CHR ) ) ) ) > 0
        newLine:=left( right( line , NUM_HEADER_PAGE_CHR ) , pos - 1)
        if len( line ) > NUM_HEADER_PAGE_CHR
          newLine:=left( line , len(line) - NUM_HEADER_PAGE_CHR ) + newLine
        endif
      else
        newLine:=line
      endif

      colorSay( x , 0 , newLine, .f. , nOffSet)
      x++
    next
    setcolor( aktColor )

    nBoxTop:=len( headerLines ) + 1

  endif

return result
/** eof */


/* FUNCTION create_PDF
*
* druckt das akt. am BS angezeigte File -> Liste.ps
*/
FUNCTION create_PDF(jobName,callerName)
local exportName:="Zeige"+getUser():getLongID()
LOCAL GetList:={}, zeile:=0 , Seite:=1
LOCAL stop
LOCAL s001:=savescreen() // brauchen wir wegen Message()
local bsLaenge:=DRUCKER->Laenge
LOCAL headerLines:=currentPrintJob:getFixedHeaderLines()

  seekPrinter(callerName)

  if jobName==NIL
    if select("Liste")>0
      exportName:=LISTE->PDFNAME
    endif
  else
    exportName:=jobName
  endif
  exportName:=no_blanks(exportName)

  if (exportName:=openFileDialog(WRITE,getUser():exportPATH(),exportName,"pdf",nil))<>NIL
    exportName:=getFileName(exportName,.t.)

    getUser():setCurrentPrintJob(PrintJob():new())
    getUser():getCurrentPrintJob():setBackground(NIL)
    getUser():getCurrentPrintJob():printToFileOnly:=.t.
    getUser():getCurrentPrintJob():generatePDF:=.t.
    getUser():getCurrentPrintJob():confirmPDF:=.t.
    getUser():getCurrentPrintJob():pdfFilePath:=getUser():exportPath
    getUser():getCurrentPrintJob():StartDoc( exportName )

    Message("Datei wird generiert.  Bitte warten....")

    stop:=.f.
    select Zeige
    go top
    do while ! eof() .and. ! stop
      // drucke header
      zeile += printHeader( headerLines , Seite )

      do while ! eof() .and. ! stop .and.;
        zeile < DRUCKER->laenge - Max( DRUCKER->laenge - bsLaenge , 0 )

        zeile += colorprint(ZEIGE->line)
        // qout(strtran(trim(ZEIGE->line),BS_FARBE,""))
        skip
        Stop=stop_key()
      enddo
      Zeile:=FormFeed(Zeile,Seite++)
    enddo

    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(currentPrintJob)

  endif
  restscreen(,,,,s001)

RETURN .t.

/** Zeigt die akt. Zeilen-Nummer am BS an */
PROCEDURE dispLineNumber()
LOCAL line:=nTopRec - nBoxTop + current

  if line < 99
    @ 0, maxcol()-8 say "Zeile:" color COLINV
    // DevOutPict(ZEIGE->(recno()),"@B",COLINV)
    DevOutPict( str(line,2) ,"@B",COLINV)
  else
    @ 0, maxcol()-8 say "Z:" color COLINV
    // DevOutPict(ZEIGE->(recno()),"@B",COLINV)
    DevOutPict( str(line,5) ,"@B",COLINV)
  endif
return


/* FUNCTION Drucke_Zeige
*
* druckt das akt. am BS angezeigte File aus
*/
FUNCTION Drucke_Zeige(jobName,callerName)
local stop,zeile:=0,i, Seite:=1
local lastline
LOCAL s001:=savescreen() // brauchen wir wegen Message()
LOCAL aktDrucker:=DRUCKER->(recno())
local bsLaenge:=DRUCKER->Laenge
  // don't use currentPrintJob here, as drucke_zeige is called from av_kalk whene Zeige ist finished
  // so _aSysStuff is unknown!
LOCal myCurrentPrintJob:=getuser():getCurrentPrintJob()
LOCAL headerLines:=mycurrentPrintJob:getFixedHeaderLines()

  /** checke ob aus Auswahlmenu */
  if ! getUser():mayPrint
    Error(ACHTUNG+"keine Berechtigung zum Drucken.",.t.)
    return .f.
  endif

  if Message("Liste ausdrucken?  Sind Sie sicher? (@J@/@N@)","JN"," ")<>"J"
    return .f.
  endif

  Message("Datei wird gedruckt.  Bitte warten....")

  // finde letzte bedruckte Zeile
  select Zeige
  go bottom
  do while ! bof() .and. empty(ZEIGE->Line)
    skip -1
  enddo
  lastline:=recno()
  go top

  seekPrinter(callerName)
  if upper(DRUCKER->Raw)=="J"
    getUser():setCurrentPrintJob(WinPrnJob():new())
  else
    getUser():setCurrentPrintJob(PrintJob():new())
  endif
  getUser():getCurrentPrintJob():setBackground(NIL)
  getuser():getCurrentPrintJob():StartDoc( jobName )

  stop:=.f.
  go top
  do while ! eof() .and. ! stop .and. recno()<=lastline

    // oberer Rand (FIXME: sollte property in Drucker.dbf oder Liste.dbf sein
    for i:=1 to val(getProperty("System.vorschub.oben","0"))
      zeile += colorprint()
    next

    // drucke header
    zeile += printHeader( headerLines , Seite )

    // drucke Bauch
    do while ! eof() .and. ! stop .and. recno()<=lastline .and. ;
      zeile < DRUCKER->laenge - Max( DRUCKER->laenge - bsLaenge , 0 )
      zeile += colorprint(ZEIGE->line)
      skip
      Stop=stop_key()
    enddo
    if ! eof() .and. ! stop .and. recno()<=lastline
      Zeile:=FormFeed( Zeile , Seite++ )
    endif
  enddo
  // Zeile:=FormFeed(Zeile,Seite)

  getUser():getCurrentPrintJob():endDoc()
  // getUser():setCurrentPrintJob(NIL) // was currentPrintJob before 20160603
  getUser():setCurrentPrintJob( mycurrentPrintJob ) // was NIL before 20170208
  restscreen(,,,,s001)

  // BottLineZeige()

  DRUCKER->(dbgoto( aktDrucker ))

RETURN .t.
/** eof */

static FUNCTION printHeader( headerLines , Seite )
LOCAL Zeile:=0 , pos , line , newLine
  default Seite:=1

  for each line in headerLines
    line:=trim(line)

    // suche nach Seite in den letzten NUM_HEADER_PAGE_CHR Stellen
    if ( pos:=at( "SEITE" , upper( right( line , NUM_HEADER_PAGE_CHR ) ) ) ) > 0

      // aktualisiere Seitennummer und f�ge rechtsb�ndig ein
      newLine:=left( right( line , NUM_HEADER_PAGE_CHR ) , pos + 4 ) + str( seite ,4)
      if len( line ) > NUM_HEADER_PAGE_CHR
        newLine:=left( line , len(line) - NUM_HEADER_PAGE_CHR ) + newLine
      endif
      line:=newLine
    endif
    zeile += colorprint(line)
  next
return Zeile
/** eof */


/* FUNCTION Drucke_ASC
*
* druckt das akt. am BS angezeigte File -> Liste.asc
*/
static FUNCTION Drucke_Asc()
local stop,zeile:=0,exportName:=left("Zeige"+getUser():getLongID()+"    ",8)
LOCAL GetList:={}
LOCAL s001:=savescreen() // brauchen wir wegen Message()
LOCAL line, newLine, pos

  if (exportName:=openFileDialog(WRITE,getUser():exportPATH(),exportName,"txt",nil))<>NIL
    exportName:=getFileName(exportName,.t.)

    Message("Datei wird generiert.  Bitte warten....")
    set alte to (getUser():exportPath+BACKSLASH+trim(exportName)+".txt")
    set alte on
    set cons off
    stop:=.f.

    // drucke header
    for each line in currentPrintJob:getFixedHeaderLines()
      if (pos:=at( "SEITE" , upper( right( trim( line ) , NUM_HEADER_PAGE_CHR ) ) ) ) > 0
        newLine:=left( right( line , NUM_HEADER_PAGE_CHR ) , pos - 1)
        if len( line ) > NUM_HEADER_PAGE_CHR
          newLine:=left( line , len(line) - NUM_HEADER_PAGE_CHR ) + newLine
        endif
      else
        newLine:=line
      endif
      qqout(strtran(trim(newLine),BS_FARBE,""))
      qout()
    next

    // Body ausdrucken
    select Zeige
    go top
    do while ! eof() .and. ! stop
      qqout(strtran(trim(ZEIGE->line),BS_FARBE,""))
      qout()
      skip
      Stop=stop_key()
    enddo
    set alte off
    close alte
    set cons on

    Message("Datei:"+getUser():exportPath+BACKSLASH+trim(exportName)+;
      ".txt erzeugt.   Bitte @Taste@ dr�cken.","@")

    BottLineZeige()
  endif
  restscreen(,,,,s001)

RETURN .t.

/* PROCEDURE zeige_Asc
*
* f t  ergebene ASCII- Datei an Zeige.dbf
* und zeigt diese an
*/
PROCEDURE zeige_Asc(Datei)
  if ! open("Zeige")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif
  message("Datei wird f  BS-Anzeige vorbereitet.        Bitte warten....")
  zap
  append from (Datei) sdf
  ZeigeText()
  // close data
RETURN

/** Notifies all open Zeige-Threads */
Procedure ZeigeClose()
LOCAL i,numThreads:=len(Threads)

  if numThreads>0
    for i:=1 to numThreads
      hb_mutexNotify( threadMutex, .t. )
    next

    hb_idleSleep( numThreads/10 )

    // Remove NIL Thread references (concurrency problem with thread array?!)
    // numThreads:=len(Threads)
    // for i:=1 to numThreads
    // if Threads[i]==NIL
    // adel(Threads,i)
    // asize(Threads,len(Threads)-1)
    // endif
    // next

    if hb_threadWait( Threads, 1 , .t. ) < len( threads )
      Error(ACHTUNG+"Interaktive Listen-Fenster bitte manuell schliessen.",ERR_NO_WAIT)
    endif

    hb_threadWaitForAll()
    if type("M->qtWidget")<>"U" // we use QT currently
      qtError() // close MessageBox
    endif

  endif
return
/** eop */


/** Merke alle aktiven Threads */
static procedure addThread()

  // Erzeuge Mutex Knoten zur Thread-Synchronistation, falls notwendig
  if threadMutex==NIL
    threadMutex:=hb_mutexCreate()
  endif

  hb_mutexLock(threadMutex)
  aadd(Threads,hb_threadSelf())
  hb_mutexUnlock(threadMutex)
return

/** L�sche obsolete Thread */
static procedure removeThread()
  hb_mutexLock(threadMutex)
  hb_adel(Threads, ascan( Threads , hb_threadSelf() ) , .t.)
  // asize(Threads,len(Threads)-1)
  hb_mutexUnlock(threadMutex)
return


/*
*   Routine: BottLineZeige()
*          :
*   Purpose: shows key options
*          :
* Arguments: void
*          :
*  Comments: used to cleanup main code.
*/
procedure BottLineZeige(popupAllowed)
LOCAL kom:="",i
  _thread static popup

  if popupAllowed<>NIL
    popup:=popupAllowed
  endif

  if getUser():mayPrint
    kom:="@D@rucken "
  endif
  // if valtype(M->specialZeige)=="C" .and. M->specialZeige=="Etikett"
  // altd()
  // Message("Bitte @ESC@ dr�cken")
  // return
  if valtype(M->specialZeige)=="A"
    if M->SpecialZeige<>NIL
      for i:=1 to len(M->SpecialZeige)
        kom += M->SpecialZeige[i,ZEIGE_MESSAGE]+" "
      next
    endif
    // kom+=M->SpecialZeige[ZEIGE_MESSAGE]
  endif
  // Message("@"+ARROW_UP+ARROW_DOWN+ARROW_LEFT+ARROW_RIGHT+"@/@PgDn@/@PgUp@/@Home@/@End@    "+kom+"  @F7@/@F8@=Suchen @ESC@=Ende")
  IF popup .and. hb_MTVM() .and. ! NO_POPUP
    kom:="@F4@=Fenster "+kom
  endif
  Message("@PgDn@/@PgUp@ "+kom+"@F7@/@F8@=Suchen @ESC@=Ende")
return

/** Gibt den BS nach einem Resize event aus */
static function resizeBS()
LOCAL aktRec:=ZEIGE->(recno())
  nBotRow:=MaxRow()-1
  ZEIGE->(dbgoto(nTopRec))
  ShowHeader()
  showlins()
  BottLineZeige()
  titel() // print last titel from calling procedure
  ZEIGE->(dbgoto( aktRec ))
return .t.
/** eof */

/** Liefert die aktuelle Zeige.dbf als MemeoFeld zur�ck */
FUNCTION getMemoText()
LOCAL result:=""
LOCAL aktRec

  if select("Zeige")>0
    aktRec:=ZEIGE->(recno())
    ZEIGE->(dbgotop())
    do while ! ZEIGE->(eof())
      result+=ZEIGE->Line+MY_CR+MY_LF
      ZEIGE->(dbskip())
    enddo
    ZEIGE->(dbgoto(aktRec))
  endif

return result
/** eof */

/** beendet Zeige mit lastkey() == ZEIGE_RESULT */
function Zeigeauswahl()
  HB_KeyPut( ZEIGE_RESULT )
return .t.
/** eof */


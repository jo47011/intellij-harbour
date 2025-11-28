/**
* Various tools using qt
*/

#include "mystd.ch"

#include "hbclass.ch"
#include "hbqtgui.ch"
#include "hbgtinfo.ch"

STATIC qtDialogs:={}
STATIC qTimer:=NIL

PROCEDURE qtError(s,warten)
LOCAL oBox

  if s==nil // reset / dispose
    if oBox<>NIL
      oBox:setVisible(.f.)
    endif
  else

    if oBox==NIL
      oBox:=QMessageBox(M->qtWidget)
      oBox:setAttribute(Qt_WA_DeleteOnClose)
      // oBox:setWindowTitle( "Info" )
      oBox:setWindowModality(Qt_WindowModal)
      oBox:setIcon(QMessageBox_Warning)
      oBox:setWindowIcon(QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
    endif

    // workaround f�r alte Aufrufe
    if valtype(warten)=="U"
      warten:=ERR_WARTEN
    else
      if valtype(warten)=="L"
        if warten
          warten:=ERR_WARTEN
        else
          warten:=ERR_ESC
        endif
      endif
    endif

    s:=strtran(s,"|",MY_CR+MY_LF)
    oBox:setText( s )

    if DEVEL_PROG .or. TEST_PROG
      oBox:setDetailedText( getStackTraceAsString())
    endif

    // set alte to foo.txt
    // set alte on
    // qout(toString(oBox))
    // close alte

    do case
    case warten==ERR_WARTEN
      // aadd( Mess,Padc("---- Bitte Taste dr�cken ----",Max_Len) )
      oBox:exec() // modal
    case warten==ERR_ESC
      // aadd( Mess,Padc("---- ESC = Ende ----",Max_Len) )
      oBox:exec() // modal
    case warten==ERR_NO_WAIT
      // FIXME: how to remove ok button?
      // oBox:removeButton(oBox:button(QMessageBox_Ok))
      oBox:setModal(.f.)
      oBox:setWindowModality(Qt_NonModal)
      oBox:show() // Non modal
    OTHERWISE
      Error("Falscher warte-Code bei Function Error"+" :FEHLER !",.t.,"root")
    endcase

    oBox:=NIL
  endif

RETURN
/** eop */
/*----------------------------------------------------------------------*/

FUNCTION qtMessage(Text,Abfrage,defaultValue,sound)
LOCAL result:=chr(255)
LOCAL oDlg

  if Abfrage==NIL // Info only
    // FIXME: where/how shall we display a info message?
    // qtError(text,ERR_NO_WAIT)
    qtError(text,ERR_WARTEN)
  else

    // FIXME: check for valid Abfrage

    default sound:=.t.
    if sound
      Beep()
    endif

    default defaultValue:=""

    // FIXME: no message highlightening yet, need a proper textfield to do so
    text:=strtran(text,"@","")

    // alt: result = oDlg:getText( M->qtWidget, "Auswahl", text,QLineEdit_Normal,defaultValue , @nResult )

    oDlg:=QInputDialog( M->qtWidget )
    registerDialog( oDlg )

    oDlg:setTextValue( defaultValue )
    oDlg:setLabelText( text )
    oDlg:setWindowTitle( "Auswahl" )

    if oDlg:exec() == QDialog_Accepted
      result:=upper( oDlg:textValue() )
    endif

  endif

RETURN result
/** eof */

procedure selectFont()
LOCAL qFontDlg,qFont,nOK

  qFont:=QFont( alltrim(hb_gtInfo( HB_GTI_FONTNAME)))
  qFont:setPointSize(Hb_GtInfo( HB_GTI_FONTWIDTH))
  qFont:setBold(Hb_GtInfo( HB_GTI_FONTWEIGHT)==HB_GTI_FONTW_BOLD)
  // qFont:setFixedPitch( .t. )
  qFontDlg:=QFontDialog( )
  qFontDlg:setWindowTitle("Font ausw�hlen  (Standard="+HB_DEFAULT_FONT+")")
  qFontDlg:setCurrentFont( qFont )

  registerDialog( qFontDlg )

  nOK:=qFontDlg:exec()
  IF nOK == 1
    qFont:=qFontDlg:currentFont()
    // qout(qFont:key())
    hb_gtInfo( HB_GTI_FONTNAME, qFont:family())
    if qFont:bold()
      Hb_GtInfo( HB_GTI_FONTWEIGHT, HB_GTI_FONTW_BOLD )
    else
      Hb_GtInfo( HB_GTI_FONTWEIGHT, HB_GTI_FONTW_NORMAL )
    endif
    Hb_GtInfo( HB_GTI_FONTWIDTH, qFont:pointSize() )
    // perform this at the end, as this sends a resize event
    hb_gtInfo(HB_GTI_FONTSIZE, qFont:pointSize()*2 )
  else
    // nop
  endif

return
/** eop */

/**
  * L�sst Benutzer eine Datei zum Speichern eingeben/ausw�hlen
  */
FUNCTION openFileDialog(Action,Pfad,DateiName,defaultExtension,Titel, fixedRootPfad)
LOCAL oDlg,oFiles,okay:=.f.,oMb
LOCAL s001:=savescreen() // brauchen wir wegen Message()
LOCAL icon:=QIcon(RESOURCES+BACKSLASH+getProperty("System.icon.png","checked.png"))

  default fixedRootPfad:=.t.

  do while ! okay

    switch Action
    case LOAD

      default titel:="Dateinamen ausw�hlen"
      Message(titel)
      // �ffne FileDialog
      // FIXME: see qt tutorial: oModello:=QFileSystemModel(), oModello:setRootPath( "" )
      oDlg:=QFileDialog()
      oDlg:setWindowTitle( Titel )
      oDlg:setWindowIcon( icon )
      if defaultExtension<>NIL
        oDlg:setNameFilter("*."+defaultExtension)
      endif
      if Pfad<>NIL
        oDlg:setDirectory(Pfad)
      endif
      if DateiName<>NIL
        oDlg:selectFile(trim(DateiName))
      endif
      oDlg:setFileMode(QFileDialog_ExistingFile)
      oDlg:setLabelText(QFileDialog_FileName,"Datei:")
      oDlg:setLabelText(QFileDialog_LookIn,"Pfad:")
      oDlg:setLabelText(QFileDialog_FileType,"Typ:")
      oDlg:setLabelText(QFileDialog_Accept,"�ffnen")
      oDlg:setLabelText(QFileDialog_Reject,"Abbrechen")

      if fixedRootPfad
        oDlg:connect( "directoryEntered(QString)", {|e| setMyDirectory( oDlg, pfad, e, 0 ) } )
        oDlg:connect( "currentChanged(QString)" , {|e| setMyDirectory( oDlg, pfad, e, 1 ) } )
      endif

      oDlg:setReadOnly(.t.)

      // register Dialog, so it is closed when shutdown is requested
      registerDialog(oDlg)

      if oDlg:exec()==QDialog_Accepted
        oFiles:=oDlg:selectedFiles()
        dateiName:=oFiles:at(0)
      else
        restscreen(,,,,s001)
        return NIL
      endif

      if ! empty(DateiName)
        DateiName:=trim(DateiName)
        okay:=.t.
        // if defaultExtension<>NIL
        // DateiName += "."+defaultExtension
        // endif

      endif
      exit

    case WRITE

      default titel:="Dateinamen eingeben"
      Message(titel)
      // �ffne FileDialog
      oDlg:=QFileDialog()
      oDlg:setWindowTitle( Titel )
      oDlg:setWindowIcon( icon )
      if defaultExtension<>NIL
        oDlg:setNameFilter("*."+defaultExtension)
      endif
      oDlg:setDirectory(Pfad)
      if DateiName<>NIL
        oDlg:selectFile(trim(DateiName))
      endif
      oDlg:setFileMode(QFileDialog_AnyFile)
      oDlg:setLabelText(QFileDialog_FileName,"Datei:")
      oDlg:setLabelText(QFileDialog_LookIn,"Pfad:")
      oDlg:setLabelText(QFileDialog_FileType,"Typ:")
      oDlg:setLabelText(QFileDialog_Accept,"Speichern")
      oDlg:setLabelText(QFileDialog_Reject,"Abbrechen")

      // user allowed to leave ppath?
      if fixedRootPfad
        oDlg:connect( "directoryEntered(QString)", {|e| setMyDirectory( oDlg, pfad, e, 0 ) } )
        oDlg:connect( "currentChanged(QString)" , {|e| setMyDirectory( oDlg, pfad, e, 1 ) } )
      endif

      // oDlg:setReadOnly(.t.)

      // register Dialog, so it is closed when shutdown is requested
      registerDialog(oDlg)

      if oDlg:exec()==QDialog_Accepted
        oFiles:=oDlg:selectedFiles()
        dateiName:=oFiles:at(0)
      else
        restscreen(,,,,s001)
        return NIL
      endif

      if ! empty(DateiName)
        // pr�fe ob Datei bereits existiert
        if file(DateiName) .or. file(trim(DateiName+"."+defaultExtension))
          oMB:=QMessageBox()
          oMB:setText( "Datei "+DateiName+" existiert bereits."+MY_CR+MY_LF+MY_CR+MY_LF+;
            "�berschreiben?" )
          oMB:setWindowTitle( "Best�tigung" )
          oMB:setWindowFlags( Qt_Dialog )
          // ico not yet supported in hbqt (needs loading library qico.lib)
          // oMB:setWindowIcon( QIcon(getProperty("System.icon",nil)))
          oMB:setWindowIcon( icon )
          oMB:seticon( QMessageBox_Question )
          oMB:setStandardButtons( QMessageBox_Yes + QMessageBox_No )
          oMB:button(QMessageBox_Yes):setText("Ja")
          oMB:button(QMessageBox_No):setText("Nein")
          oMB:setDefaultButton( QMessageBox_Yes )
          registerDialog(oMB)
          IF oMB:exec() <> QMessageBox_Yes
            loop
          endif
        endif

        DateiName:=trim(DateiName)
        okay:=checkFileName(getFileName(DateiName,.t.))
        // if defaultExtension<>NIL
        // DateiName += "."+defaultExtension
        // endif

      endif
      exit

    endswitch
  enddo

  restscreen(,,,,s001)

return replaceWindowsSlashes( DateiName )
/** eof */

function setMyDirectory( oDlg, pfad, cDir, nMode )
LOCAL curDir:=oDlg:directory():absolutePath()

  ignore cDir, nMode

  if replaceWindowsSlashes( lower( left( curDir, len( pfad ) ) ) ) <> lower( pfad )
    oDlg:setDirectory( pfad )
  endif

  // QMessageBox():about( oDlg, str( nMode ), cDir )

return .t.
/** eof */

/* 
* druckt das akt. am BS angezeigte File (s. Zeige.prg) aus
*/
FUNCTION PrintDialog(jobName,callerName)
LOCAL lastLine,Stop,Zeile:=0
LOCAL qEditor,text,fontSize
LOCAL qPrnDlg, printer,qFormat,qCursor, dialogResult
LOCAL i , Seite:=1
LOCAL laenge:=83 // how can we calculate this? // FIXME: untested value


  /** checke ob aus Auswahlmenu */
  if ! getUser():mayPrint
    Error(ACHTUNG+"keine Berechtigung zum Drucken.",.t.)
    return .f.
  endif

  qPrnDlg:=QPrintDialog()
  // qPrnDlg:setWindowIcon( hbide_image( "hbide" ) )
  qPrnDlg:connect( "accepted(QPrinter*)", {|p| printer:=p } )
  qPrnDlg:setWindowTitle("Drucken - Windows")

  registerDialog( qprnDlg )

  dialogResult:=qprnDlg:exec()

  // why do we need this here? should be called automatically on hide
  unregisterDialog( qprnDlg )

  if (dialogResult == QDialog_Accepted)

    Message("Datei wird gedruckt.  Bitte warten....")

    fontSize:=HB_FONTSIZE_STANDARD
    seekPrinter(callerName)
    if ! LISTE->(eof())
      do case
      case LISTE->Art=="S"
        fontSize:=HB_FONTSIZE_SCHMAL
        laenge:=64 // how can we calculate this?
      case LISTE->Art=="K"
        fontSize:=HB_FONTSIZE_KLEIN
        laenge:=83 // how can we calculate this?
      case LISTE->Art=="W"
        fontSize:=HB_FONTSIZE_WINZIG
        laenge:=112 // how can we calculate this? // FIXME: untested value
      endcase
    endif

    printer:setPageMargins(15, 15, 15, 15, QPrinter_Millimeter)

    qEditor:=QTextEdit()
    qEditor:setCurrentFont(QFont("Courier",fontSize))
    qCursor:=qEditor:textCursor()
    qFormat:=qCursor:charFormat()

    // finde letzte bedruckte Zeile
    go bottom
    do while ! bof() .and. empty(ZEIGE->Line)
      skip -1
    enddo
    lastline:=recno()
    go top

    stop:=.f.
    select Zeige
    go top
    qCursor:beginEditBlock()
    do while ! eof() .and. ! stop .and. recno()<=lastline

      // oberer Rand (FIXME: sollte property in Drucker.dbf oder Liste.dbf sein
      for i:=1 to val(getProperty("System.vorschub.oben","0"))
        qCursor:insertText(HB_OSNewLine())
        zeile ++
      next

      // drucke header
      zeile += printZeigeHeader( qCursor , qFormat, Seite++ )

      // drucke Bauch
      do while ! eof() .and. ! stop .and. recno()<=lastline .and. zeile < laenge - 8

        text:=ZEIGE->Line

        do while at(BS_FARBE,text) > 0
          // drucke normalen Text bis SZ
          qCursor:insertText(substr(text,1,at(BS_FARBE,text)-1),qFormat)

          // setzte Bold & drucke Farbtext
          if qFormat:fontWeight()==QFont_Normal
            qFormat:setFontWeight(QFont_Bold)
          else
            qFormat:setFontWeight(QFont_Normal)
          endif
          text:=substr(text,at(BS_FARBE,text)+1,len(text))
        enddo

        // drucke Rest vom text
        qCursor:insertText(text,qFormat)

        qCursor:insertText(HB_OSNewLine())
        zeile++
        skip
        Stop=stop_key()
      enddo

      // qCursor:insertText( MY_FF , qFormat ) // FormFeed
      do while Zeile < laenge
        qCursor:insertText(HB_OSNewLine())
        zeile++
      enddo
      Zeile:=0

    enddo

    qCursor:endEditBlock()

    if jobName==NIL
      qEditor:setDocumentTitle("Drucke Zeige")
    else
      qEditor:setDocumentTitle(jobName)
    endif
    qEditor:Move( 5, 7 )
    qEditor:Resize( 345,365 )
    qEditor:Show()
    qEditor:print(printer)

  endif

  BottLineZeige()

RETURN .t.
/** eof */

/** Zeichen von rechts bei denen im Header nach dem Begriff "Seite" gesucht wird -> s. Zeige.prg */
  #define NUM_HEADER_PAGE_CHR 12

static FUNCTION printZeigeHeader( qCursor , qFormat, Seite )
LOCAL currentPrintJob:=getUser():getCurrentPrintJob()
LOCAL headerLines:=currentPrintJob:getFixedHeaderLines()
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
    qCursor:insertText( line , qFormat )
    qCursor:insertText(HB_OSNewLine())
    zeile++
  next

return Zeile
/** eof */

/** Merkt sich alle offenen Dialogs, schlie�t diese on shutdown
  *
  * Returns the passed dlg
  */
function registerDialog( oDlg )
LOCAL nWidth, nHeight, aPos

  aadd(qtDialogs , oDlg)
  // Info: we need to connect to both events as close does not get called on accepted() or rejected()
  oDlg:connect( QEvent_Close , { || unRegisterDialog( oDlg ) } )
  oDlg:connect( QEvent_Hide , { || unRegisterDialog( oDlg ) } )

  if M->qtWidget == NIL
    M->qtWidget:=oDlg
  endif

  // use png icon, .ico file not yet supported by QT :(
  // oDlg:setWindowIcon(QIcon( RESOURCES+BACKSLASH+getProperty("System.icon","") ) )
  oDlg:setWindowIcon(QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )

  // start repeating check for shutdown.out
  // FIXME: eigentlich nur falls modal, QDialog:isModal ist hier aber noch nicht gestezt
  IF qTimer == NIL
    qTimer:=QTimer()
    qTimer:setInterval( TIME_CHECK * 1000 )
    qTimer:connect( "timeout()", {|| if( checkShutdownRequest() > 0 , closeDialogs() , .t.) } )
    qTimer:start( TIME_CHECK * 1000 )
  endif

  // now center the dialog on main miki prog not on desktop!
  aPos:=hb_gtInfo( HB_GTI_SETPOS_XY )
  nWidth:=hb_gtInfo( HB_GTI_SCREENWIDTH )
  nHeight:=hb_gtInfo( HB_GTI_SCREENHEIGHT )
  oDlg:connect( QEvent_Show, {|| oDlg:move( aPos[ 1 ] +;
    ( ( nWidth - oDlg:width() ) / 2 ), aPos[ 2 ] + ( ( nHeight - oDlg:height() ) / 2 ) ) } )

return oDlg
/** eop */

/** L�scht die Referenz zum Dialog*/
procedure unRegisterDialog( oDlg )

  oDlg:disconnect( QEvent_Close )
  oDlg:disconnect( QEvent_Hide )
  // oDlg:disconnect( "finished(int)" )

  hb_aDel(qtDialogs , aScan( qtDialogs , oDlg) , .t. )  /** shrink it */
  if len(qtDialogs)==0
    resetTimer()
  endif

  if M->qtWidget == oDlg
    M->qtWidget:=NIL
  endif

return
/** eop */

/** Schlie�t alle registrierten Dialogs */
procedure closeDialogs()
LOCAL oDlg

  resetTimer()
  for each oDlg in qtDialogs
    if oDlg <> NIL
      oDlg:reject()
    endif
  next

return
/** eop */

/** L�scht den Timer, if any */
static procedure resetTimer()

  IF qTimer <> NIL
    qTimer:disconnect( "timeout()" )
    IF qTimer:isActive()
      qTimer:stop()
    ENDIF
    qTimer:=NIL
  endif

return
/** eop */


/** contains all inoput masks ported to QT */

#include "Miki.ch"

#include "dbstruct.ch"
#include "hbthread.ch"
#include "hbqtgui.ch"

// do we need this?
REQUEST HB_GT_WVT_DEFAULT
REQUEST HB_GT_WIN
REQUEST HB_GT_GUI

/*
*
* Main-Procedure for launching standalone qt masks
* FIXME: old stuff, may be obsolete, was in qtlaunch.prg -> also see qtlaunch.hbp
*/
PROCEDURE main(login,datei,nummer,pass)
  PUBLIC User

  // altd()

  // need to call init procedure manually
  init_hb()

  if (pass<>NIL .and. pass==QTLAUNCH_PASS) .or. DEVEL_PROG
    init(login)

    switch upper(datei)
    case "KUNDEN"
      qtKundenDisp(nummer)
      exit
    endswitch

  endif
  quit

return
/** eop */



/** Zeigt anhand der akt. Datei, die passende QT Gui an, falls vorhanden */
PROCEDURE qtDisp()
LOCAL Nummer,s01
LOCAL useThreads:=getProperty("System.qt.thread","N")

  switch upper(alias())
  case "KUNDEN"

    nummer:=KUNDEN->KundNr
    if useThreads=="N"
      s01:=savescreen()
      Message("Windows Eingabemaske wird gestartet.  Bitte warten...")
      myrun("qtLaunch",getUser():id+" "+alias()+" "+nummer+" "+QTLAUNCH_PASS)
      restscreen(,,,,s01)
    else
      hb_threadStart(HB_THREAD_INHERIT_PUBLIC, @qtKundenDisp(),nummer)
    endif

    exit
  endswitch

return
/** eop */

/** Kunden QT GUI */
PROCEDURE qtKundenDisp(KundNr)
LOCAL lay1 ,oTv,oDirModel, buttonPanel,oFoto
private oWnd,oGUI , oLeft, oRight, oOk, oCancel, oClose, oEventLoop,aInputFields
private oTV2,oTv3

  if ! open("Kunden","AufPost","AufAus","Spedit","Land","Mwst_Kz","BankStam","RechPost")
    Error(TRY_AGAIN)
    close data
    return
  endif
  select Kunden
  dbseek(KundNr)

  M->oWnd:=QWidget()
  M->oWnd:setWindowTitle( "Kunden bearbeiten" )
  M->oWnd:setwindowicon( QIcon( RESOURCES+BACKSLASH+"miki32.png" ) )
  // not working with icon file :(
  // M->oWnd:setwindowicon( QIcon( RESOURCES+BACKSLASH+"miki.ico" ) )

  // M->oWnd:setModal(.t.)

  // set flag so qt is used for error messages etc.
  M->QTWidget:=M->oWnd

  M->oGui:=hbqtui_kunden()
  // M->oGui:setParent(M->oWnd)

  // Kunden Liefer Adressen
  M->oTv2:=QTreeWidget( M->oWnd )
  M->oTv2:setHeaderHidden( .t. )
  M->oGui:q_AdrLief:addWidget(M->oTv2)

  // Kunden Rechnungs Adressen
  M->oTv3:=QTreeWidget( M->oWnd )
  M->oTv3:setHeaderHidden( .t. )
  M->oGui:q_AdrRech:addWidget(M->oTv3)

  // example directory on F4
  oTV:=QTreeView( M->oWnd )
  oDirModel:=QDirModel()
  oTV:setModel( oDirModel )

  // Bsp Artikel Liste
  M->oGui:q_tabWidget:connect( "currentChanged(int)", ;
    {|p| if(p==2,showArtikelListe(M->oGui:q_ArtikelListe ),nil)})

  // Bsp Foto
  oFoto:=QLabel( M->oWnd )
  oFoto:move( 200, 40 )
  oFoto:resize( 100, 100 )
  oFoto:SetPixmap( QPixmap( RESOURCES+BACKSLASH+"magazin.png" ) )
  M->oGui:q_Foto:addWidget(oFoto)
  M->oGui:q_Foto:addWidget(QLabel("Beispiel Foto, z.B. fur Artikel oder so"))

  M->oGui:q_AuftragListe:addWidget(QLabel("Beispiel Baum (Directory)"))
  M->oGui:q_AuftragListe:addWidget(oTV)

  M->oWnd:connect( QEvent_KeyPress , { |k| keypressed(k) } )
  // M->oWnd:connect( QEvent_Close , { || qtquit() } )

  lay1:=QVBoxLayout( M->oWnd )
  lay1:addWidget(M->oGui)

  // add buttons
  buttonPanel:=QHBoxLayout()
  lay1:addlayout( buttonPanel )

  M->oLeft:=QPushButton()
  M->oLeft:Connect( "clicked()", { || qtskip(-1,) })
  M->oLeft:SetIcon( QIcon( RESOURCES+BACKSLASH+"previous.png" ) )

  M->oRight:=QPushButton()
  M->oRight:Connect( "clicked()", { || qtskip(1) })
  M->oRight:SetIcon( QIcon( RESOURCES+BACKSLASH+"next.png" ) )

  // ok / cancel button
  M->oOk:=QPushButton()
  M->oOk:setText( "OK" )
  M->oOk:Connect( "clicked()", { || qtCommit() } )

  M->oClose:=QPushButton()
  M->oClose:setText( "Close" )
  M->oClose:Connect( "clicked()", { || qtQuit() } )

  M->oCancel:=QPushButton()
  M->oCancel:setText("Cancel")
  M->oCancel:Connect( "clicked()", { || cancel() })

  buttonPanel:addWidget( M->oLeft )
  buttonPanel:addStretch()
  buttonPanel:addWidget( M->oOk )
  buttonPanel:addWidget( M->oClose )
  buttonPanel:addWidget(M->oCancel)
  buttonPanel:addStretch()
  buttonPanel:addWidget( M->oRight )

  initWidget()


  // show 1st tab, FIXME not working when running in MT thread!!!
  M->oGui:q_tabWidget:setCurrentIndex(0)
  // M->oGui:q_tabWidget:setCurrentWidget(M->oGui:q_tabStammDaten)

  M->oWnd:resize( 1, 1 )

  M->oEventLoop:=QEventLoop( M->oWnd )
  M->oWnd:connect( QEvent_Close, {|| M->oEventLoop:exit( 0 ) } )
  M->oWnd:Show()
  M->oEventLoop:exec()

  M->oWnd:setVisible(.f.)
  close data
  M->QTWidget:=NIL
  xReleaseMemory( { M->oWnd,M->oGui,M->oLeft,M->oRight,M->oOk,M->oCancel,M->oClose,M->oEventLoop,;
    M->QTWidget, M->aInputFields } )

RETURN

procedure initWidget()

  M->oOk:setEnabled(.f.)
  M->oCancel:setEnabled(.f.)

  // read values from DB
  readFields()

  // unset filter for reading delivery adresses
  set filter to

  // Kunden Liefer Adressen
  M->oTv2:takeTopLevelItem(0)
  M->oTv2:addTopLevelItem(getLiefAdrRoot())
  M->oTv2:expandToDepth(0)

  // Kunden Rechnungs Adressen
  M->oTv3:takeTopLevelItem(0)
  M->oTv3:addTopLevelItem(getRechAdrRoot())
  M->oTv3:expandToDepth(0)

  // unset filter for reading delivery adresses
  set filter to empty(right(KUNDEN->KundNr,2))

return
/** eop*/

function qtCommit()

  // write changed values
  commitFields()
  dbcommit()
  dbunlock()

  M->oOk:setEnabled(.f.)
  M->oCancel:setEnabled(.f.)
  M->oLeft:setEnabled(.t.)
  M->oRight:setEnabled(.t.)

return .t.
/** eof */

function qtLock()

  if ! rec_lock(5)
    messageBox("Datensatz nicht verfugbar.  Bitte spater nochmal versuchen.")
    return .f.
  endif
  M->oOk:setEnabled(.t.)
  M->oCancel:setEnabled(.t.)
  M->oLeft:setEnabled(.f.)
  M->oRight:setEnabled(.f.)

  // enable all edit fields
  aEval(M->aInputFields,{|f| f:setEnabled(.t.)})

return .t.
/** eof */

function cancel()
LOCAL oMB,nButtonPressed

  if isLocked()

    oMB:=QMessageBox()
    oMB:setText( "�nderungen wirklich verwerfen?"+MY_CR+MY_LF )
    oMB:setWindowTitle( "Best�tigung" )
    oMB:setWindowFlags( Qt_Dialog )
    oMB:setStandardButtons( QMessageBox_Yes + QMessageBox_No )
    oMB:setDefaultButton( QMessageBox_Yes )
    oMB:setwindowicon( M->oWnd:windowIcon)

    // register Dialog, so it is closed when shutdown is requested
    registerDialog(oMb)

    nButtonPressed:=oMB:exec()

    IF nButtonPressed = QMessageBox_Yes
      dbunlock()
      initWidget()
    else
      return .f.
    ENDIF

    // disable all edit fields
    aEval(M->aInputFields,{|f| f:setEnabled(.f.)})

    // enable navigation keys
    M->oLeft:setEnabled(.t.)
    M->oRight:setEnabled(.t.)

  endif

return .t.
/** eof */

function qtskip(num)
  skip num
  if num > 0
    M->oLeft:setEnabled(.t.)
    if eof()
      M->oRight:setEnabled(.f.)
      go bottom
    endif
  elseif num < 0
    M->oRight:setEnabled(.t.)
    if bof()
      M->oLeft:setEnabled(.f.)
      go top
    endif
  endif
  initWidget()
return .t.
/** eof */

function qtquit()
  if cancel()
    M->oEventLoop:exit( 0 )
  endif
return .t.
/** eop */


PROCEDURE keypressed(x)

  // LOCAL string
  // string = "You have pressed the key: " + "<br><br>"
  // string = string + "VALUE= " + Str( x:key() ) + "<br>"
  // string = string + "KEY= " + Chr( x:key() )
  // messageBox("Pressed: " + hb_ntos( x:key() ) )

  switch x:key()
  case Qt_Key_F1
    M->oGui:q_tabWidget:setCurrentIndex(0)
    exit
  case Qt_Key_F2
    M->oGui:q_tabWidget:setCurrentIndex(1)
    exit
  case Qt_Key_F3
    M->oGui:q_tabWidget:setCurrentIndex(2)
    exit
  case Qt_Key_F4
    M->oGui:q_tabWidget:setCurrentIndex(3)
    exit
  case Qt_Key_F5
    M->oGui:q_tabWidget:setCurrentIndex(4)
    exit
  case Qt_Key_F6
    M->oGui:q_tabWidget:setCurrentIndex(5)
    exit
  case Qt_Key_F7
    M->oGui:q_tabWidget:setCurrentIndex(6)
    exit
  case Qt_Key_Escape
    qtquit()
    exit
  endswitch

RETURN
/** eop */

/*----------------------------------------------------------------------*/


FUNCTION xReleaseMemory( aObj )
  #if 1
LOCAL i
  FOR i:=1 TO len( aObj )
    IF hb_isObject( aObj[ i ] )
      aObj[ i ]:=NIL
    ELSEIF hb_isArray( aObj[ i ] )
      xReleaseMemory( aObj[ i ] )
    ENDIF
  NEXT
  #else
  HB_SYMBOL_UNUSED( aObj )
  #endif
RETURN nil

/*----------------------------------------------------------------------*/

/** Reads the fields from the current db record and fills the objectData */
PROCEDURE readFields()
LOCAL aStruct:=dbStruct(), feld,oFeld
LOCAL bLastHandler:=MyErrorBlock({ |objErr| ignoreBreak(objErr) }) // stelle Break ein

  M->aInputFields:={}

  // FIXME: QObject:children() would be the better way
  for each feld in aStruct
    BEGIN SEQUENCE // krit. Bereich
      switch feld[DBS_TYPE]
      case "C"
        // set field content
        oFeld:="{ || M->oGui:q_"+feld[DBS_NAME]+":setText(trim("+feld[DBS_NAME]+")) }"
        eval(&oFeld,M->oGui)

        // set field length
        oFeld:="{ || M->oGui:q_"+feld[DBS_NAME]+":setMaxLength("+alltrim(str(feld[DBS_LEN]))+") }"
        eval(&oFeld,M->oGui)

        // disable all input fields on start up
        oFeld:="{ || M->oGui:q_"+feld[DBS_NAME]+":setEnabled(.f.) }"
        eval(&oFeld,M->oGui)

        // all fields in this array will be enabled when record is locked
        // since KundNr is not editable it is not added to this array
        if feld[DBS_NAME]<>"KUNDNR"
          aadd(M->aInputFields,&("M->oGui:q_"+feld[DBS_NAME]))
        endif

        // register mouse click to lock record
        oFeld:="{ || M->oGui:q_"+feld[DBS_NAME]+":connect("+str(QEvent_MouseButtonPress)+",{|| qtlock()})}"
        eval(&oFeld)

        exit
      case "N"
        // FIXME missing num values and others
        exit
      endswitch
      RECOVER
        // NOP, field not found -> ignore it
      END

    next
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    return
/** eop */

/** Commits the fields from the current M->QTWidget to the db record */
PROCEDURE commitFields()
LOCAL aStruct:=dbStruct(), feld,oFeld,value
LOCAL bLastHandler:=MyErrorBlock({ |objErr| ignoreBreak(objErr) }) // stelle Break ein

  // FIXME: QObject:children() would be the better way
  for each feld in aStruct
    BEGIN SEQUENCE // krit. Bereich
      switch feld[DBS_TYPE]
      case "C"
        // get field value
        oFeld:="{ || M->oGui:q_"+feld[DBS_NAME]+":text()}"
        value:=eval(&oFeld,M->oGui)
        if value<>fieldget(fieldpos(feld[DBS_NAME]))
          replace &(feld[DBS_NAME]) with value
        endif
        exit
      case "N"
        // FIXME missing num values and others
        exit
      endswitch
      RECOVER
        // NOP, field not found -> ignore it
      END

    next
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    return
/** eop */

/** sortiert alle Rechn.Adressen zum aktuellen Kunden in Kunden.dbf */
Function getRechAdrRoot()
LOCAL root:=QTreeWidgetItem(), qItmc,qAdr
LOCAL merkNr,text
LOCAL aktRec:=recno()

  // find top level customer
  do while ! empty(right(KUNDEN->KundNr,2)) .and. ! KUNDEN->(bof())
    skip -1
  enddo

  // add all rechnungs adressen
  if ! KUNDEN->(bof()) .and. ! empty(KUNDEN->Name)
    merkNr:=left(KUNDEN->KundNr,5)
    root:setText( 0, KUNDEN->KundNr+" "+KUNDEN->KurzName)
    do while merkNr==left(KUNDEN->KundNr,5) .and. ! KUNDEN->(bof())
      qItmC:=QTreeWidgetItem()
      qItmC:setText( 0, KUNDEN->KundNr+" "+KUNDEN->KurzName)

      qAdr:=QTreeWidgetItem()
      text:=KUNDEN->Name+MY_CR+MY_LF+;
        KUNDEN->Partner+MY_CR+MY_LF+;
        KUNDEN->Strasse+MY_CR+MY_LF+;
        mytrim(KUNDEN->Land)+mytrim(KUNDEN->PLZ)+KUNDEN->Ort
      if ! empty(KUNDEN->Telefon)
        text+=MY_CR+MY_LF+KUNDEN->Telefon
      endif
      qAdr:setText( 0, text )
      qItmc:addChild( qAdr )

      root:addChild( qItmC )
      skip
    enddo
  endif

  go (aktRec)

return root
/** eof */

/** sortiert alle LieferAdressen zum aktuellen Kunden in Kunden.dbf */
Function getLiefAdrRoot()
LOCAL root:=QTreeWidgetItem(), qItmc,qAdr
LOCAL merkNr,text
LOCAL aktRec:=recno()

  // find top level customer
  do while ! empty(right(KUNDEN->KundNr,2)) .and. ! KUNDEN->(bof())
    skip -1
  enddo

  // add all versand adressen
  if ! KUNDEN->(bof()) .and. ! empty(KUNDEN->Name2)
    merkNr:=left(KUNDEN->KundNr,5)
    root:setText( 0, KUNDEN->KundNr+" "+KUNDEN->KurzName)
    do while merkNr==left(KUNDEN->KundNr,5) .and. ! KUNDEN->(bof())
      qItmC:=QTreeWidgetItem()
      qItmC:setText( 0, KUNDEN->KundNr+" "+KUNDEN->KurzName)

      qAdr:=QTreeWidgetItem()
      text:=KUNDEN->Name2+MY_CR+MY_LF+;
        KUNDEN->Partner2+MY_CR+MY_LF+;
        KUNDEN->Strasse2+MY_CR+MY_LF+;
        mytrim(KUNDEN->Land2)+mytrim(KUNDEN->PLZ2)+KUNDEN->Ort2
      if ! empty(KUNDEN->Telefon)
        text+=MY_CR+MY_LF+KUNDEN->Telefon
      endif
      qAdr:setText( 0, text )
      qItmc:addChild( qAdr )

      root:addChild( qItmC )
      skip
    enddo
  endif

  go (aktRec)

return root
/** eof */


/** still testing zeige -> qt */
PROCEDURE showArtikelListe(tab)
LOCAL info,oldWidget

  _thread static qbrw,kundNr

  // .or. tab:indexOf(qBrw)<0 ???
  if qBrw==NIL .or. kundNr<>KUNDEN->KundNr

    if qBrw<>NIL
      tab:removeWidget(qBrw)
    endif

    info:=QLabel("Liste wird erstellt.    Bitte warten....")
    tab:addWidget(info)
    info:show()

    qBrw:=QTextEdit()
    qBrw:setReadOnly(.t.)
    qBrw:setLineWrapMode(QTextEdit_NoWrap)
    qBrw:setFont(QFont("Courier New",10))
    oldWidget:=M->qtWidget
    M->QTWidget:=qBrw

    ArtKundListe(KUNDEN->KundNr)

    tab:removeWidget(info)
    tab:addWidget(qBrw)
    qBrw:show()
    M->QTWidget:=oldWidget

  endif
RETURN
/* EOP */


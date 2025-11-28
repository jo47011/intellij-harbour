/* Modul QT-AV Tools.prg
*
* ein paar QT GUI Features f�r Arbeitsvorbereitung (AV)
*/

#include "Miki.ch"
#include "hbqtgui.ch"

/** Bietet ein QT Dialog zur Auswahl der Druck-M�glichkeiten
* Result: .f. bei CANCEL ansonsten .t. -> also Ende
*/

function avDruckAuswahl( printOnly , innerArt , alterAuftrag, druckeDokumente, force)
LOCAL oDialog:=QDialog()
LOCAL oGui:=hbqtui_avDruckDialog()
LOCAL layout:=QVBoxLayout()
LOCAL buttonBox,okay,cancel,quit,result
LOCAL druck:="",listen:=""

  Umgebung( WRITE_ALL )

  default printOnly:=.f.
  default force:=.f. // keine Wkz Stkliste f�r 3er Artikel

  Error("Info: Druck-Auswahl in anderem Fenster beenden, um fortzufahren.",ERR_NO_WAIT)

  // connect some slots
  oGui:alles:connect( "clicked()", { || handleClick(oGui,oGui:alles)})
  oGui:ohne:connect( "clicked()", { || handleClick(oGui,oGui:ohne)})

  oGui:Material:connect( "clicked()", { || handleClick(oGui,oGui:Material)})
  oGui:Werkzeug:connect( "clicked()", { || handleClick(oGui,oGui:Werkzeug)})
  oGui:Zeit:connect( "clicked()", { || handleClick(oGui,oGui:Zeit)})
  oGui:Etikett:connect( "clicked()", { || handleClick(oGui,oGui:Etikett)})

  // set default Werte on start-up
  if AT_HOME
    // testing
    // oGui:Warenbegleitschein:setChecked(.t.)
  else
    oGui:Etikett:setChecked(.t.)
    oGui:Material:setChecked(.t.)
  endif

  if printOnly .or. innerArt==INNER_STK
    oGui:Ohne:setEnabled(.f.)
    oGui:Ohne:setChecked(.f.)
  endif

  if innerArt==INNER_STK
    oGui:Etikett:setEnabled(.f.)
    oGui:Etikett:setChecked(.f.)
  endif

  // bei bestimmten Artikel Lager-Sortierung vorschlagen
  // Auferfass ist bereits selektiert
  loca for left(AUFERFAS->artnr,3) $ getProperty("Miki.av.sortLager","")
  if ! AUFERFAS->(eof())
    oGui:sortLager:setChecked(.t.)
  endif
  loca for left(AUFERFAS->artnr,1) $ getProperty("Miki.av.werkzeug","")
  if ! AUFERFAS->(eof())
    oGui:Werkzeug:setChecked(.t.)
  endif

  // je nach Anzahl Etiketten -> Checkbox de-selektieren
  loca for AUFERFAS->EtiAnz > 0 .or. AUFERFAS->EtiAnz2 > 0
  if AUFERFAS->(eof())
    oGui:Etikett:setChecked(.f.)
  endif

  go top

  buttonBox:=QDialogButtonBox( hb_bitOr(QMessageBox_Cancel,QMessageBox_Ok,QMessageBox_Discard),;
    Qt_Horizontal,oDialog)
  okay:=buttonBox:button(QMessageBox_Ok)
  okay:connect( "clicked()", { || oDialog:done(DIALOG_OKAY)})
  okay:setShortcut(( QKeySequence("ALT+O") ))
  okay:setTooltip( "Drucken & Speichern (Alt-O oder RETURN)" )
  okay:setText( "&OK" )
  okay:setIcon( QIcon( RESOURCES+BACKSLASH+"okay.png" ) )

  quit:=buttonBox:button(QMessageBox_Discard)
  quit:connect( "clicked()", { || oDialog:done(DIALOG_QUIT)})
  quit:setShortcut(( QKeySequence("ALT+N") ))
  quit:setTooltip( "Abbruch (Alt-N )" )
  quit:setText( "Verwerfe&n" )
  quit:setIcon( QIcon( RESOURCES+BACKSLASH+"cancel.png" ) )

  cancel:=buttonBox:button(QMessageBox_Cancel)
  cancel:connect( "clicked()", { || oDialog:done(DIALOG_CANCEL)})
  cancel:setShortcut(( QKeySequence("ALT+C") ))
  cancel:setTooltip( "Zur�ck (Alt-C oder ESC)" )
  cancel:setText( "Zur�&ck" )
  cancel:setIcon( QIcon( RESOURCES+BACKSLASH+"previous.png" ) )

  buttonBox:setCenterButtons(.t.)

  layout:addWidget(oGui:oWidget)
  layout:addStretch()
  layout:addWidget(buttonBox)
  // layout:setSizeConstraint( QLayout_SetFixedSize )

  // finalize the dialog
  oDialog:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  oDialog:setWindowTitle(getProperty("System.window.title","Abfrage")+" - AV Druck")
  oDialog:setWindowFlags(hb_bitOr(Qt_CustomizeWindowHint,Qt_WindowTitleHint,;
    Qt_WindowCloseButtonHint))
  oDialog:setLayout(layout)

  // register Dialog, so it is closed when shutdown is requested
  registerDialog(oDialog)

  result:=oDialog:exec()

  if result==DIALOG_OKAY

    // innerbet. Auftr�ge
    if oGui:Material:isChecked()
      druck += "M"
    endif
    if oGui:Werkzeug:isChecked()
      druck += "W"
    endif
    if oGui:Zeit:isChecked()
      druck += "Z"
    endif
    if oGui:Etikett:isChecked() .and. innerArt <> INNER_STK
      druck += "E"
    endif

    // Bedarfs-Listen
    if oGui:EArtikel:isChecked()
      listen += "E"
    endif
    if oGui:BArtikel:isChecked()
      listen += "B"
    endif
    if oGui:DArtikel:isChecked()
      listen += "D"
    endif

    av_druck(druck,;
      (printOnly .or. innerArt==INNER_STK),;
      oGui:sortLager:isChecked(),;
      listen,;
      alterAuftrag, ;
      druckeDokumente, force)

  endif

  // FIXME: clear keyboard buffer, in case user presses K_ESC on this
  // window while dialog is showing
  // clear typeahead
  // SetLastKey(0)
  // inkeySetLast(K_RETURN)
  // HB_KEYCLEAR()
  Umgebung( LOAD )

return result
/** eop */

static function checkOthers(oGui,value)
  oGui:Material:setChecked(value)
  oGui:Werkzeug:setChecked(value)
  oGui:Zeit:setChecked(value)
  oGui:Etikett:setChecked(value)
return .t.

static function handleClick(oGui,source)
LOCAL value:=source:isChecked()
  if source == oGui:Alles
    if value
      if oGui:Ohne:isEnabled()
        oGui:Ohne:setChecked(.f.)
      endif
      checkOthers(oGui,.t.)
    endif
  elseif source == oGui:Ohne
    if value
      checkOthers(oGui,.f.)
      oGui:Alles:setChecked(.f.)
    endif
  else
    oGui:Alles:setChecked(.f.)
    if value
      oGui:Ohne:setChecked(.f.)
    endif
  endif
return .t.
/** eof */



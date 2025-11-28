
#include "miki.ch"
#include "Zeige.ch"

#include "hbclass.ch"
#include "hbqtgui.ch"

CLASS aiTree inherit qtTree

DATA showingKWs INIT {}
DATA kwOffset INIT 1 // position in headers where Kw starts
DATA filterPanel HIDDEN
DATA infoPanel HIDDEN
DATA infoLayout HIDDEN

METHOD new(oParentWidget, aHeaders, countLevel)
METHOD toggleKWColumns(show, pastOnly)
METHOD initPanels() HIDDEN
METHOD addInfoRow(key, description)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new( oParentWidget, aHeaders, countLevel)
LOCAL dock, count:=1

  ::super:new(oParentWidget, aHeaders)

  // find offset, means where KW start in title
  do while count <= len(aHeaders)
    if isKW(aHeaders[count])
      ::kwOffset:=count
      exit
    endif
    count++
  enddo

  ::getWidget():header:setDefaultAlignment(Qt_AlignCenter)
  ::getWidget():collapseAll()
  ::getWidget():setAlternatingRowColors(.t.)
  ::getWidget():setAnimated(.t.)

  ::initPanels()

  // // create filter dock widget
  dock:=QDockWidget("Filter" , oParentWidget , 0)
  dock:setWidget( ::getTreeNavigationPanel(countLevel, ::filterPanel, ::InfoPanel) )
  dock:setFeatures(hb_bitOR(QDockWidget_DockWidgetMovable,QDockWidget_DockWidgetVerticalTitleBar,;
    QDockWidget_DockWidgetFloatable))
  // dock:setFeatures( QDockWidget_DockWidgetMovable )
  oParentWidget:addDockWidget( Qt_BottomDockWidgetArea , dock )

  oParentWidget:connect(QEvent_Show, {|| ::showRowCount() })

return self
  /** eom */

/** adds line to info panel */
METHOD addInfoRow(key, description)
  ::infoLayout:addRow(key, QLabel(description))
RETURN self

METHOD initPanels()
LOCAL filterCheckbox
LOCAL filterLayout:=QVBoxLayout()

  ::filterPanel:=QWidget()
  ::infoPanel:=QWidget()
  ::infoLayout:=QFormLayout()

  // filter
  filterCheckbox:=QCheckBox("Alle &KWs")
  filterCheckbox:connect( "clicked(bool)", {|value| ::toggleKWColumns(value)})
  filterCheckbox:setCheckState(Qt_Checked)
  filterCheckbox:setTooltip( "KWs ohne Bewegung anzeigen (Alt-K)" )
  filterCheckbox:setShortcut( QKeySequence("ALT+K") )
  filterLayout:addWidget( filterCheckbox )

  // filterCheckbox:=QCheckBox("Reservierungen")
  // filterCheckbox:connect( "clicked(bool)", {|value| ::toggleReservations(value)})
  // filterCheckbox:setCheckState(Qt_Checked)
  // filterLayout:addWidget( filterCheckbox )

  ::filterPanel:setLayout(filterLayout)

  ::infoPanel:setLayout(::infoLayout)

  // q1:setStyleSheet("border:0px;")
  // q2:setStyleSheet("border:0px;")
  // q3:setStyleSheet("border:0px;")
  // infoPanel:setStyleSheet("border:1px solid rgb(195, 222, 246);")


return self
/** eom */

/** hides all unsued columns which are not in the passed showingKWs array.
  * parameter: pastonly if true only unsued columns before currentKW are hidden.
  */
METHOD toggleKWColumns(show, pastOnly)
LOCAL col

  default pastOnly:=.f.

  // hide unused columns in the past
  for col:=::kwOffset to len(::aHeaders)
    if .not. pastonly .or. kwdiff( ::aHeaders[col] , getCurrentKW() ) > 0
      if ! aContains( ::showingKWs, ::aHeaders[col] ) .and. ! empty(::aHeaders[col])
        if show
          ::getWidget():showColumn( col - 1)
        else
          ::getWidget():hideColumn( col - 1)
        endif
      endif
    else
      exit // heutige KW erreicht
    endif
  next

  ::showRowCount()

return .t.
  /** eof */



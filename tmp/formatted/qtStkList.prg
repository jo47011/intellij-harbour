/** Class for viewing a miki parts list (St�ckliste) */

#include "Miki.ch"

#include "hbqtgui.ch"
#include "hbwin.ch"
#include "hbclass.ch"

CLASS qtStkList

DATA oTree HIDDEN
DATA oTreeModel HIDDEN
DATA oWnd Hidden

METHOD new(MArtNr,mArt,titel)
METHOD populateNode(MArtNr,filterArt)
METHOD show()

METHOD getTreeWidgetItemData(MArtNr) HIDDEN
METHOD getTreeWidgetItem(MArtNr) HIDDEN

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(MArtNr,mArt,titel)

  Umgebung(WRITE)
  ::oWnd:=QMainWindow()
  ::oWnd:setWindowTitle( titel )

  ::oTree:=qtTree():new( ::oWnd , {"Artikel","Text","Menge","ME","Ort","Lg Bestand"})
  // ::oTree:=QTreeWidget( ::oWnd )

  ::oTree:addTopLevelItem( ::populateNode(MArtNr,mArt) )
  // ::oTree:expandToDepth(0)
  // ::oTree:expandAll()
  // ::oTree:setColumnCount(5)
  // ::oTree:setAlternatingRowColors(.t.)
  // ::oTree:setAnimated(.t.)

  // ::oTreeModel:=::oTree:model()
  // ::oTreeModel:setHeaderData(0,Qt_Horizontal,QVariant("Artikel"),Qt_DisplayRole)
  // ::oTreeModel:setHeaderData(1,Qt_Horizontal,QVariant("Text"),Qt_DisplayRole)
  // ::oTreeModel:setHeaderData(2,Qt_Horizontal,QVariant("Menge"),Qt_DisplayRole)
  // ::oTreeModel:setHeaderData(3,Qt_Horizontal,QVariant("ME"),Qt_DisplayRole)
  // ::oTreeModel:setHeaderData(4,Qt_Horizontal,QVariant("Ort"),Qt_DisplayRole)
  // ::oTree:setColumnWidth(0,240)
  // ::oTree:resizeColumnToContents(1)

  Umgebung(LOAD)

  ::show()
return self
/** eom */

/*----------------------------------------------------------------------*/
/** sortiert alle Unter-Artikel in Baumstruktur ein und liefert root node zur�ck */
METHOD populateNode(MArtNr,filterArt)
LOCAL root:=::getTreeWidgetItem(MArtNr)
LOCAL child
LOCAL aktArt:=ARTIKEL->(recno())
LOCAL aktAV

  ARTIKEL->(dbseek( MArtNr ))
  // FIXME: needed?
  root:setText( 0,MArtNr)
  root:setText( 1, ARTIKEL->Bez1 )
  root:setText( 2, transStr( AVPOST->Menge,12,3 ) )
  root:setText( 3, EINHEIT->Text )
  root:setText( 4, getArtikelLagerOrt(11) )
  root:setText( 5, transStr(ARTIKEL->LageBest,12,2) )

  // as of now Material only
  AVPOST->(dbseek( MArtNr + filterArt ))
  do while ! AVPOST->(eof()) .and. AVPOST->AvNr == MArtNr .and. AVPOST->Art == filterArt
    if AVPOST->Text == "T"
      TEXT->(dbseek( trim(AVPOST->ArtNr) ))
      child:=::getTreeWidgetItem( AVPOST->ArtNr )
      child:setText( 0, AVPOST->ArtNr )
      child:setText( 1, TEXT->Text )
    else
      aktAv:=AVPOST->(recno())
      child:=::populateNode( AVPOST->ArtNr , filterArt )
      AVPOST->(dbgoto(aktAv))
    endif
    root:addChild( child )
    AVPOST->(dbskip())
  enddo

  ARTIKEL->(dbgoto(aktArt))

return root
/** eof */

/*----------------------------------------------------------------------*/

/** Helper method for tree items */
METHOD getTreeWidgetItem(nr)
LOCAL result:=QTreeWidgetItem()
LOCAL qVar
  result:setTextAlignment(0,Qt_AlignTop)
  if nr<>NIL
    qVar:=QVariant(nr)
    result:setData(1,Qt_UserRole,qVar)
  endif
return result
/** eof */

/*----------------------------------------------------------------------*/
METHOD getTreeWidgetItemData(item)
LOCAL qVar,result:=NIL
  if item<>NIL
    qVar:=item:data(1,Qt_UserRole)
    result:=qVar:toInt()
  endif
return result
/** eof */

/*----------------------------------------------------------------------*/
METHOD show()
LOCAL dock

  ::oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  ::oWnd:setCentralWidget( ::oTree:getWidget() )

  // // FIXME: FilterPanel does not support multiple top level nodes yet
  // // create filter dock widget
  dock:=QDockWidget("Filter" , ::oWnd , 0)
  dock:setWidget( ::oTree:getTreeNavigationPanel() )
  dock:setFeatures(hb_bitOR(QDockWidget_DockWidgetMovable,QDockWidget_DockWidgetVerticalTitleBar,;
    QDockWidget_DockWidgetFloatable))
  ::oWnd:addDockWidget( Qt_BottomDockWidgetArea , dock )
  dock:close() // need this otherwise dock is shown twice???!

  ::oWnd:resize(550,350)

  ::oWnd:connect(QEvent_KeyPress, { |x| matKeyPressed(x, ::oWnd, ::oTree) } )
  // ::oWnd:connect( QEvent_KeyPress , { |x| winKeyPressed(x , ::oWnd , ::oTree) } )
  ::oWnd:show()
return self
/** eof */


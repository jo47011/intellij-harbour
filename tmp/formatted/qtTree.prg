/** Class for viewing data in tree format */

#include "MyStd.ch"

#include "hbqtgui.ch"
#include "hbwin.ch"
#include "hbclass.ch"

/** Fixme: filtering as of now only works with 1 root node */

static lastText, lastHitNr, numRows

CLASS qtTree

DATA oTree
DATA aHeaders
DATA rootClone INIT {}
DATA countLevel INIT 0

METHOD new( oParentWidget , aHeaders)
METHOD addTopLevelItem(oRoot)

METHOD getTreeItemData( oItem )
METHOD getCurrentItemData()
METHOD getNewTreeItem( data )
METHOD getWidget()
METHOD getTreeNavigationPanel()
METHOD filterTree(text)
METHOD filterNodes(node, text) // HIDDEN
METHOD searchTree(text)
METHOD searchNodes(node, text) // HIDDEN
METHOD getColCount()
METHOD showRowCount()
METHOD countRows( node ) // HIDDEN
METHOD resizeColumnToContents()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new( oParentWidget , aHeaders )
LOCAL i
LOCAL header:=QTreeWidgetItem()

  numRows:=QLabel()

  ::oTree:=QTreeWidget( oParentWidget )
  ::oTree:setAutoScroll(.t.)

  ::oTree:setColumnCount( len(aHeaders) )
  header:setTextAlignment( 0 , Qt_AlignRight )
  // ::oTree:setHeaderItem( header )

  // ::oTree:setAlternatingRowColors(.t.)
  // ::oTree:setAnimated(.t.)

  for i:=1 to len( aHeaders )
    ::oTree:model():setHeaderData(i-1,Qt_Horizontal,QVariant( aHeaders[i] ),Qt_DisplayRole)
  next
  ::aHeaders:=aHeaders

  // ::oTree:setColumnWidth(0,240)
  // ::oTree:setSortingEnabled(.t.)

return self
/** eom */

/*----------------------------------------------------------------------*/
/** sortiert alle Unter-Artikel in Baumstruktur ein und liefert root Item zur�ck
  * parameter: root node to add
  *            flag whether node should be added to ::rootClone (default is true)
  */
METHOD addTopLevelItem(oRoot, clone)

  default clone:=.t.

  ::oTree:addTopLevelItem( oRoot )
  if clone
    aadd(::rootClone, oRoot:clone())
  endif

  //::oTree:expandToDepth(0)
  // ::oTree:expandAll()
  ::resizeColumnToContents()
  ::oTree:setCurrentItem( oRoot )

  // ::showRowCount()

return oRoot
  /** eof */

// /** resizes all top level nodes */
METHOD resizeColumnToContents()
LOCAL i
  for i:=1 to len( ::aHeaders )
    ::oTree:resizeColumnToContents(i-1)
  next
return self

/*----------------------------------------------------------------------*/
/** Aktualisiert die Anzeige der aktuellen sichtbarer Zeilen an */
METHOD showRowCount()
  // LOCAL nRows:=::oTreemodel():rowCount() // not working so we use:
  // LOCAL nRows:=::countRows( ::oTree:topLevelItem(0) ) // counts all on 2nd level
LOCAL nrows:=0

  if ::countLevel == 0
    // counting top level items
    do while ::oTree:topLevelItem(nRows) <> NIL
      nRows++
    enddo
  else
    // counts all on 2nd level
    nRows:=::countRows( ::oTree:topLevelItem(0) )
  endif


  numRows:setText( "Anzahl Datens�tze: "+alltrim( str( nRows ,10 ) ) )

return self
/** eof */

/*----------------------------------------------------------------------*/
/** Berechnet rekursiv die Anzahl der alt. sichtbaren Datens�tze */
METHOD countRows( node , visibleOnly )
LOCAL result:=1 // current node is 1st one to count
LOCAL i

  default visibleOnly:=.t.

  if node == NIL
    return 0
  endif

  if empty(node:text(0))
    return 0
  endif

  for i:=0 to node:childCount()-1
    if ! visibleOnly .or. node:isExpanded()
      result += ::countRows( node:child(i) )
    endif
  next

return result
/** eof */


/*----------------------------------------------------------------------*/

/** Helper method for tree items */
METHOD getNewTreeItem(nr)
LOCAL result:=QTreeWidgetItem()
LOCAL qVar , i

  for i:=1 to len( ::aHeaders )
    result:setTextAlignment(i-1,Qt_AlignTop)
  next

  if nr<>NIL
    qVar:=QVariant(nr)
    result:setData(0,Qt_UserRole,qVar)
  endif

return result
/** eof */

/*----------------------------------------------------------------------*/
METHOD getTreeItemData(item)
LOCAL qVar,result:=NIL
  if item<>NIL
    qVar:=item:data(0,Qt_UserRole)
    result:=qVar:toString()
  endif
return result
/** eof */

/*----------------------------------------------------------------------*/
METHOD getWidget()
return ::oTree
/** eom */

/*----------------------------------------------------------------------*/
METHOD getCurrentItemData()
LOCAL item:=::oTree:currentItem()
return ::getTreeItemData(item)
/** eom */

/*----------------------------------------------------------------------*/

/** liefert ein Navigations panel (expand, collapse, search f�r den Tree zur�ck
  * parameters:  countlevel for showRowCount()
  *              additional panels to be added, eg. filters, infopanel etc.
  */
METHOD getTreeNavigationPanel(countLevel, ...)
LOCAL addPanels:=hb_aParams() , i
LOCAL buttonLayout:=QHBoxLayout(), buttonPanel, filterLabel:=QLabel(),filterIcon:=QLabel()
LOCAL searchLabel:=QLabel(), searchIcon:=QLabel()
LOCAL expand:=QPushButton()
LOCAL collapse:=QPushButton()
LOCAL filterEdit:=QLineEdit()
LOCAL searchEdit:=QLineEdit()

  if countLevel <> NIL
    ::countLevel:=countLevel
  endif
  ::showRowCount()

  ::oTree:connect( "itemExpanded(QTreeWidgetItem*)", { || ::showRowCount(), ::resizeColumnToContents() } )
  ::oTree:connect( "itemCollapsed(QTreeWidgetItem*)", { || ::showRowCount(), ::resizeColumnToContents() } )

  // expand & collapse
  expand:connect( "clicked()", { || ::oTree:expandAll(),::resizeColumnToContents(),::showRowCount(;
    ) })
  expand:setIcon( QIcon( RESOURCES+BACKSLASH+"plus.png" ) )
  expand:setTooltip( "Alle aufklappen (ALT +)" )
  expand:setShortcut( QKeySequence("ALT++") )

  collapse:connect( "clicked()", ;
    { || ::oTree:collapseAll(), ::resizeColumnToContents(),::showRowCount()})
  collapse:setIcon( QIcon( RESOURCES+BACKSLASH+"minus.png" ) )
  collapse:setTooltip( "Alle zuklappen (ALT -)" )
  collapse:setShortcut( QKeySequence("ALT+-") )

  buttonLayout:addWidget( expand )
  buttonLayout:addWidget( collapse )
  buttonLayout:addStretch()

  // Filter
  filterEdit:connect(QEvent_KeyPress , ;
    { |k| if(k:key()==Qt_Key_Return .or. k:key()==Qt_Key_Enter,::filterTree(filterEdit:text()),nil)})
  filterIcon:setPixmap( QPixmap(RESOURCES+BACKSLASH+"filter.png" , 0 , Qt_AutoColor) )
  filterLabel:setText("&Filter:")
  // filterLabel:setShortcut( QKeySequence("ALT+F") )
  filterLabel:setBuddy(filterEdit)
  filterEdit:setTooltip( "Daten filtern (Alt-F)" )

  buttonLayout:addWidget(filterIcon )
  buttonLayout:addWidget(filterLabel )
  buttonLayout:addWidget( filterEdit )
  buttonLayout:addStretch()

  // Suche
  searchEdit:connect(QEvent_KeyPress , ;
    { |k| if(k:key()==Qt_Key_Return .or. k:key()==Qt_Key_Enter,::searchTree(searchEdit:text()),nil)})
  searchIcon:setPixmap( QPixmap(RESOURCES+BACKSLASH+"search.png" , 0 , Qt_AutoColor) )
  searchLabel:setText("&Suche:")
  // searchLabel:setShortcut( QKeySequence("ALT+F") )
  searchLabel:setBuddy(searchEdit)
  searchEdit:setTooltip( "Datensatz suchen (Alt-F)" )

  buttonLayout:addWidget(searchIcon )
  buttonLayout:addWidget(searchLabel )
  buttonLayout:addWidget( searchEdit )
  buttonLayout:addStretch()

  // add additional custom panels
  for i:=2 to len(addPanels)
    buttonLayout:addWidget(addPanels[i])
  next
  buttonLayout:addStretch()
  buttonLayout:addWidget( numRows )

  buttonPanel:=QWidget()
  buttonPanel:setLayout(buttonLayout)

  buttonPanel:setSizePolicy(QSizePolicy_Preferred, QSizePolicy_Fixed)

return buttonPanel
/** eof */

/*----------------------------------------------------------------------*/
/** Filtert den Tree nach Elementen, die den �bergebenen Text enthalten
  */
METHOD filterTree(text)
LOCAL node, root

  // This does not work, removes too much
  ::oTree:clear()
  //::oTree:model():removeRows(0, ::oTree:TopLevelItemCount())

  if empty(text)
    for each root in ::rootClone
      ::addTopLevelItem(root:clone(), .f.)
    next
  else
    for each root in ::rootClone
      node:=::filterNodes( root:clone() , text )
      // default node:=::getNewTreeItem("empty")
      if node <> NIL
        ::oTree:addTopLevelItem( node )
      endif
    next

    // add dummy item
    if ::oTree:TopLevelItemCount() == 0
      ::oTree:addTopLevelItem( QTreeWidgetItem("Leer") )
    endif

    ::showRowCount()

  endif

  ::oTree:expandToDepth(::countLevel)
  ::resizeColumnToContents()

return .t.
/** eof */

/*----------------------------------------------------------------------*/

/** Filtert reskursiv alle Knoten, die den �bergebenen Text enthalten */
METHOD filterNodes(node, text)
LOCAL i , hit:=.f. , childHit , remove:={}

  text:=alltrim(upper(text))

  // aktuelle Node ein Treffer?
  for i:=0 to len( ::aHeaders ) - 1
    if text $ upper( node:text(i) )
      hit:=.t.
      exit
    endif
  next

  // gehe alle Kinder durch (rekursiv)
  // Knoten bleibt drinn, wenn eines der Kinder trifft!
  for i:=0 to node:childCount() - 1
    childHit:=::filterNodes( node:child(i) , text ) <> NIL
    if ! childHit
      aadd( remove , node:child(i) )
    endif
    hit:=hit .or. childHit
  next

  // now remove all childs w/o hit
  // we need 2 steps here, otherwise the childCount() will change in above loop
  for i:=1 to len(remove)
    node:removeChild( remove[i] )
  next

return if(hit,node,NIL)
/** eom */

/*----------------------------------------------------------------------*/
/*----------------------------------------------------------------------*/
/** Sucht im Tree nach dem 1. Elemen, die den �bergebenen Text enthalten
  */
METHOD searchTree(text)
LOCAL node, row:=0

  ::oTree:selectionModel:clearSelection()

  if lastText <> text
    lastText:=text
    lastHitNr:=0
  endif

  do while ::oTree:topLevelItem(row) <> NIL .and. node == NIL
    node:=::searchNodes(::oTree:topLevelItem(row++), text)
  enddo

  if node <> NIL
    node:setSelected(.t.)
    node:setExpanded(.t.)
  endif

  ::oTree:expandAll()
  //::oTree:scrollTo(39, QAbstractItemView_EnsureVisible)

  ::resizeColumnToContents()

return .t.
/** eof */

/*----------------------------------------------------------------------*/
/** Sucht rekursiv alle Nodes die den �bergebenen Text enthalten
  * returns next node found
  */
METHOD searchNodes(node, text, hitNr)
LOCAL i , hit:=NIL
  default hitNr:=0

  text:=alltrim(upper(text))

  // aktuelle Node ein Treffer?
  for i:=0 to len( ::aHeaders ) - 1
    if text $ upper( node:text(i) )
      hitNr++
      if hitNr > lastHitNr
        hit:=node
        lastHitNr:=hitNr
        return hit
      endif
    endif
  next

  // gehe alle Kinder durch (rekursiv)
  for i:=0 to node:childCount() - 1
    hit:=::searchNodes( node:child(i) , text, hitNr )
    if hit <> NIL
      return hit
    endif
  next

return NIL
/** eom */



/*----------------------------------------------------------------------*/

/** Liefert die Anzahl der Spalten */
METHOD getColCount()
return len( ::aHeaders )
/** eom */



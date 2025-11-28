/**
* Everything for the export to Excel
*
* see c:/3pp/harbour/contrib/hbwin/tests/ole.prg

* WATCHOUT: some of my function only work with 26 columns -> A1:Z1
*           AA,AB etc. not always supported
*
*
*   1031478
*
*
* Info: open / read acces to excel file, see end of this file


   IF ( oExcel:=win_oleCreateObject( "Excel.Application" ) ) != NIL
     oExcel:=openExcelWorkbook( DateiName )
     oAS:=oExcel:ActiveSheet()
     ?    oAS:Cells( 1, 1 ):Value
     oExcel:DisplayAlerts:=0
     oExcel:Quit()
   endif

* Info: set column width etc.
   oSheet:Range( "A1:A1000" ):ColumnWidth:=8
   oSheet:columns[1]:columnwidth:=8

* Info: merge cells
          oSheet:Range( "C1:D1" ):Merge()
*/


#include "mystd.ch"

#include "dbstruct.ch"
#include "excel.ch"

#include "hbclass.ch"
#include "hbqtgui.ch"
#include "hilfe.ch"

CLASS ExcelExport

DATA columns INIT {}
DATA fileName
DATA oExcel HIDDEN
DATA oSheet

METHOD new( name )
METHOD addBrowse(oBrowse)
METHOD addColumn(oExcelColumn)
METHOD addCurrentDBColumns(alternativeTitels)
METHOD addColumnsByName(aFields)
METHOD export(lConfirm,lLaunchExcel,fileName)

METHOD doit(lLaunchExcel,fileName) HIDDEN
METHOD translateFormula(text) HIDDEN
METHOD getColumnByName(name)
METHOD getColumnByPos(i)

METHOD adjustAll( numRows , numCols )
METHOD summe( row , col )
METHOD getActiveSheet()

METHOD commit( fileName )

ENDCLASS

/*----------------------------------------------------------------------*/
METHOD new( name )
LOCAL objErr
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
LOCAL oWorkBook

  BEGIN SEQUENCE // krit. Bereich

    IF ( ::oExcel:=win_oleCreateObject( "Excel.Application" ) ) == NIL
      Error("MS Excel nicht verf�gbar.||+" + win_oleErrorText())
    ELSE

      default name:=toReadable(alias())
      name:=cleanFileName(name)

      // changed: 20230721 Miki's Excel now also works like this
      oWorkBook:=::oExcel:WorkBooks:Add()

      // removed 20230930 no longer needed w/ nee
      // if .not. NEW_MIKI_SERVER .and. .not. AT_HOME
      // BEGIN SEQUENCE // krit. Bereich
      // ::oExcel:Sheets("Tabelle3"):delete()
      // ::oExcel:Sheets("Tabelle2"):delete()
      // if ! empty(name)
      // ::oExcel:Sheets("Tabelle1"):Name:=name
      // endif
      // RECOVER
      // // don't care
      // END SEQUENCE
      // endif

      ::oSheet:=::oExcel:ActiveSheet()

      // Set font for all cells
      ::oSheet:Cells:Font:Name:="Arial"
      ::oSheet:Cells:Font:Size:=12

    endif

  RECOVER USING objErr
    if objErr <> NIL
      Error(getErrorDispText(objErr),.t.,"root")
      throw( objErr )
    endif
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

RETURN self
/** eom */

/*  copies all column from passed oBrowse Object ------------------------- */
METHOD addBrowse(oBrowse)
LOCAL j:=1,oCol

  for j:=1 to oBrowse:colCount
    oCol:=ExcelColumn():new()
    oCol:title:=oBrowse:getcolumn(j):heading
    oCol:Codeblock:=oBrowse:getcolumn(j):block()
    oCol:fieldName:=oBrowse:getcolumn(j):cargo[COL_FELDNAME] // ACHTUNG Hilfe-Column Referenz

    ::addColumn(oCol)
  next

RETURN self
/** eom */

/*  adds a new Excel colum to the export list --------------------------------------*/
METHOD addColumn(oCol)
LOCAL pos

  // set some default values
  if valtype(oCol:fieldName)=="U" .or. empty(oCol:fieldName)
    oCol:fieldName:=oCol:title
  endif

  // default oCol:Codeblock:=fieldBlock( oCol:fieldName )

  if oCol:type==NIL
    // is db field -> take those values
    if (pos:=fieldPos(oCol:Fieldname)) > 0
      oCol:type:=fieldType(pos)
      oCol:len:=fieldLen(pos)
      oCol:Dec:=fieldDec(pos)
    endif
  endif

  aadd(::columns,oCol)
RETURN self
/** eom */

/* adds the columns named in aFields -----------------------------
 *
 * aFields cann be a single dimension array with all field names,
 * then the field name is used as header.
 *
 * optionally a fieldName in the array can be an array with {fieldName,title}
 * so the title will be used as header */
METHOD addColumnsByName(aFields)
LOCAL feld,oCol,i

  for each feld in aFields
    oCol:=ExcelColumn():new()
    if valtype(feld)=="A" // Mit Titel
      i:=1
      do while i<=len(feld)
        oCol[i]:=feld[i]
        i++
      enddo

      BEGIN SEQUENCE // krit. Bereich
        if fieldType(feld[1]) == "N"
          if fieldDec(feld[1]) > 0
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
          else
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
          endif
        endif
      END SEQUENCE

    else // ohne Titel
      // minimum set
      oCol:title:=feld
      oCol:fieldName:=feld

      BEGIN SEQUENCE // krit. Bereich
        if fieldDec(feld) > 0
          oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
        else
          oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
        endif
      END SEQUENCE
    endif


    // now add the column
    ::addColumn(oCol)

  next
RETURN self
/** eom */

/* adds all columns of the current selected database -----------------------------
 *
 * aTitles contains an optional array with 2 dimensional arrays per column with {"FieldName","Titel"},
 * not all fields need to specifed
*/
METHOD addCurrentDBColumns(aTitels)
LOCAL oCol,j,pos
LOCAL dbStruct:=dbStruct()

  default aTitels:={}

  for j:=1 to fcount()
    oCol:=ExcelColumn():new()
    oCol:fieldName:=dbStruct[j,DBS_NAME]
    oCol:title:=dbStruct[j,DBS_NAME] // default title
    oCol:type:=dbStruct[j,DBS_TYPE]
    oCol:len:=dbStruct[j,DBS_LEN]
    oCol:dec:=dbStruct[j,DBS_DEC]
    oCol:Codeblock:=fieldBlock( dbStruct[j,DBS_NAME] )

    if fieldType(oCol:fieldName) == "N"
      if fieldDec(oCol:fieldName) > 0
        oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
      else
        oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
      endif
    endif

    // check wheter alternative title ist defined
    for pos:=1 to len(aTitels)
      if upper(aTitels[pos,1]) == upper(dbStruct[j,DBS_NAME])
        oCol:title:=aTitels[pos,2]
        exit
      endif
    next

    // now add the column
    ::addColumn(oCol)

  next
RETURN self
/** eom */


/** auto size and alignment of columns 0..numCols */
METHOD adjustAll( numRows , numCols )
LOCAL j , allRange

  ignore numCols, j

  Message("Daten werden gespeichert.     Bitte warten...")
  // for j:=1 to numCols
  // @ maxrow(),maxcol()-10 say str( j / numCols * 100 ,3)+"%"
  // ::oSheet:Columns[j]:AutoFit()

  // // alle top aligned
  // ::oSheet:Columns[j]:VerticalAlignment = xlVAlignTop

  // next

  // ::oSheet:Range( "A1:D1" ):Columns:AutoFit()

  // changed 12.5.2016
  allRange:="A1:"+chr(63 + numCols)+alltrim(str(numRows))
  ::oSheet:Range( allRange ):Columns:VerticalAlignment = xlVAlignTop
  ::oSheet:Range( allRange ):Columns:AutoFit()

return self
/* eom */

/** F�gt die Summe der kompletten Spalte an der Position ein */
METHOD summe( row , col )
local ExcelColumnNr:=chr(64 + col)
  ::oSheet:Cells( row , col ):Value:=;
    "=summe(" + ExcelColumnNr + alltrim(str( row-1 ))+ ;
    ":" + ExcelColumnNr + alltrim(str( 2 )) + ")"
  ::oSheet:Cells( row , ExcelColumnNr ):Font:Bold:=.t.
return self
/** eom */

/** liefert das aktuelle Excel Sheet */
METHOD getActiveSheet()
return ::oSheet
/** eom */

/*  exports the data to Excel -------------- --------------------------------------*/
METHOD doit( lLaunchExcel , fileName )
LOCAL i,j,numVisColumns,value,aktRec:=recno(),cellType
LOCAL stop:=.f. , objErr , oCol
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

  BEGIN SEQUENCE // krit. Bereich

    Message("Daten werden nach Excel exportiert.    Bitte warten...")

    // drucke Titel
    i:=1
    numVisColumns:=1
    for j:=1 to len(::columns)
      oCol:=::columns[j]
      if oCol:selected
        ::oSheet :Cells( i, numVisColumns ):Value:=oCol:title
        ::oSheet :Cells( i, numVisColumns ):Font:Bold:=.t.
        oCol:ExcelColumnNr:=chr(64+j)
        if numVisColumns > 26
          oCol:ExcelColumnNr:=chr(64+ int(numVisColumns/26)) + chr(64+( numVisColumns % 26 ))
        else
          oCol:ExcelColumnNr:=chr(64+numVisColumns)
        endif
        numVisColumns++
      else
        oCol:ExcelColumnNr:=NIL
      endif
    next

    // Logo hinzuf�gen
    // ::oSheet:Pictures:Insert(RESOURCES+BACKSLASH+getProperty("System.icon.png",""))

    // gehe alle Zeilen durch
    go top
    i:=2
    do while ! eof() .and. ! stop

      @ maxrow(),;
        maxcol()-10 say if(OrdKeyCount()>0,str((OrdKeyNo()/OrdKeyCount()) * 100 ,3),"100")+"%"

      // drucke jede Spalte je Zeile
      for j:=1 to len(::columns)
        oCol:=::columns[j]
        if oCol:selected
          if oCol:codeblock == NIL
            if oCol:formula == NIL
              value:=&(oCol:fieldName)
            else
              value:=::translateFormula(oCol:formula)
              value:=strtran(value,"$row$",alltrim(str(i)))
              oCol:type:="F"
            endif
          else
            value:=eval(oCol:codeblock)
          endif
          if value<>NIL

            cellType:=if(oCol:type==NIL,valtype(value),oCol:type)
            switch cellType
            case "N" // Number, plain value
              ::oSheet:Cells( i, oCol:ExcelColumnNr ):value:=value
              if oCol:numberformat<>NIL
                ::oSheet:Cells(i, oCol:ExcelColumnNr):numberformat:=oCol:numberformat
              elseif oCol:dec<>NIL // assign default format based on decimials
                // #,##0.00;[Rot]-#,##0.00
                ::oSheet:Cells(i, oCol:ExcelColumnNr):numberformat:="#,##."+replicate("0",oCol:dec)+;
                  ";["+if(AT_HOME,"Red","Rot")+"]-#,##."+replicate("0",oCol:dec)
              endif
              exit

            case "D" // date
              if ! empty(value)
                ::oSheet:Cells( i, oCol:ExcelColumnNr ):value:=value
                // ::oSheet:Cells(i, oCol:ExcelColumnNr):numberformat:="dd/mm/yy;@"
              endif
              exit

            case "C" // alpha-num. with '
              /** Info:  ole bug, excel crashes on wrong formula, when left(value,1) == "=M�ll" */
              ::oSheet:Cells( i, oCol:ExcelColumnNr ):value:="'"+value
              exit

            case "F" // Formel
              ::oSheet:Cells( i, oCol:ExcelColumnNr ):value:=value
              if oCol:numberformat<>NIL
                ::oSheet:Cells(i, oCol:ExcelColumnNr):numberformat:=oCol:numberformat
              endif
              exit

            otherwise // and the rest we use 1:1
              ::oSheet:Cells( i, oCol:ExcelColumnNr ):value:=value
              exit

            endswitch
          endif
        endif
      next
      skip
      i++
      Stop:=(inkey()==K_ESC) // ESC gedr�ckt ?
    enddo

    if stop
      // ::oExcel:WorkBooks:Close()
      // Ohne Abfrage
      ::oExcel:DisplayAlerts:=0
      ::oExcel:Quit()
      go(aktRec)
      break
    endif

    // drucke Summen, if any
    // info: i steht bereit auf der n�chsten Zeile
    for j:=1 to len(::columns)
      oCol:=::columns[j]
      if oCol:selected .and. oCol:sum
        // FIXME: use ::summe( row , col )
        ::oSheet:Cells( i , oCol:ExcelColumnNr ):Value:=;
          "=summe(" + oCol:ExcelColumnNr + alltrim(str( i-1 ))+ ;
          ":" + oCol:ExcelColumnNr + alltrim(str( 2 )) + ")"
        ::oSheet:Cells( i , oCol:ExcelColumnNr ):Font:Bold:=.t.
      endif
    next

    // setze auto fit size for all columns
    ::adjustAll( i , numVisColumns )

    if lLaunchExcel
      // now open excel
      //::oExcel:WorkBooks:Saved:=.t.
      ::oExcel:Visible:=.T.
    else
      default fileName:="NoName.xlsx"
      ::commit( fileName )
    endif

    go(aktRec)

  RECOVER USING objErr
    if objErr <> NIL
      Error(getErrorDispText(objErr),.t.,"root")
      throw( objErr )
    endif
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
RETURN self
/** eom */

/* If lConfirm is .t. it opens Dialog asking user to confirm columns to export, and exports the data
 * if lConfirm is .f. exports the data without user interaction
  *
  * if lLaunchExcel is set Excel is launched automatically
  */
METHOD export( lConfirm , lLaunchExcel , fileName )
LOCAL oDialog:=QDialog()
LOCAL layout:=QVBoxLayout(oDialog)
LOCAL buttonBox:=QDialogButtonBox( hb_bitOr(QMessageBox_Cancel,QMessageBox_Ok),Qt_Horizontal)
LOCAL okay,cancel,result:=.f.
LOCAL j,cb,label,allCbs:={}
LOCAL s01:=savescreen()
LOCAL oCol

  default lConfirm:=.t.
  default lLaunchExcel:=.t.

  if ! lConfirm
    // export without confirmation
    result:=.t.
  else

    Error("Info: Excel-Export in anderem Fenster beenden, um fortzufahren.",ERR_NO_WAIT)

    // prepare buttons
    okay:=buttonBox:button(QMessageBox_Ok)
    okay:connect( "clicked()", { || oDialog:accept()})
    okay:setShortcut(( QKeySequence("ALT+O") ))
    okay:setTooltip( "Exportiere Daten nach Excel (Alt-O oder RETURN)" )
    okay:setIcon( QIcon( RESOURCES+BACKSLASH+"okay.png" ) )

    cancel:=buttonBox:button(QMessageBox_Cancel)
    cancel:connect( "clicked()", { || oDialog:reject()})
    cancel:setShortcut(( QKeySequence("ALT+C") ))
    cancel:setTooltip( "Abbruch (Alt-C oder ESC)" )
    cancel:setIcon( QIcon( RESOURCES+BACKSLASH+"cancel.png" ) )

    buttonBox:setCenterButtons(.t.)

    // add title & checkboxes
    label:=QLabel("Excel Export")
    label:setAlignment(Qt_AlignCenter)
    label:setFont(QFont("Arial",24,QFont_Bold))
    layout:addWidget(label)
    layout:addStretch()

    for j:=1 to len(::columns)
      oCol:=::columns[j]
      cb:=QCheckBox(alltrim(oCol:title))
      cb:setChecked(oCol:selected)
      layout:addWidget(cb)
      aadd(allCbs,cb)
    next
    layout:addStretch()

    layout:addWidget(buttonBox)
    // layout:setSizeConstraint( QLayout_SetFixedSize )

    // // finalize the dialog
    oDialog:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
    oDialog:setWindowTitle(getProperty("System.window.title","Abfrage")+" - Excel-Export")
    oDialog:setWindowFlags(hb_bitOr(Qt_CustomizeWindowHint,Qt_WindowTitleHint,;
      Qt_WindowCloseButtonHint))
    oDialog:setLayout(layout)

    // register Dialog, so it is closed when shutdown is requested
    registerDialog(oDialog)

    // no show dialog
    IF oDialog:exec() = QDialog_Accepted
      // assign checkboxes
      for j:=1 to len(::columns)
        oCol:=::columns[j]
        oCol:selected:=allCbs[j]:isChecked()
      next
      result:=.t.
    endif

  endif

  restscreen(,,,,s01)

  // now export it, if wanted
  if result
    ::doit(lLaunchExcel,fileName)
    restscreen(,,,,s01)
  endif

RETURN result
/** eom */

/*  returns the columns with the specified name (case insenstive) or NIL ------------------------- */
METHOD getColumnByName(name)
LOCAL j:=1,oCol

  name:=upper(name)

  for j:=1 to len(::columns)
    oCol:=::columns[j]
    if upper(oCol:fieldName) == name
      return oCol
    endif
  next

RETURN NIL // not found
/** eom */

/*  returns the columns at the specified position, starts with 0 ------------------------- */
METHOD getColumnByPos(i)
return ::columns[i]
/** eom */

/*  translates my formula to Excel -------------- --------------------------------------*/
METHOD translateFormula(text)
LOCAL tokens:=HB_ATokens(text,"$") , t
LOCAL oCol , value

  for each t in tokens
    t:=alltrim(t)
    if ! t $"row*/-+=()"
      oCol:=::getColumnByName(t)
      if oCol<>NIL
        if oCol:ExcelColumnNr <> NIL
          // we are fine, use the column reference
          text:=strTran(text,"$"+t+"$",oCol:ExcelColumnNr+"$row$")
        else // not visible, we try our best
          if oCol:codeblock == NIL
            value:=&(oCol:fieldName)
          else
            value:=eval(oCol:codeblock)
          endif
          switch valtype(value)
          case "N" // Number, plain value
            text:=strTran(text,"$"+t+"$",str(value))
            exit
          case "D" // date
            text:=strTran(text,"$"+t+"$",dtoc(value))
            exit
          case "C" // alpha-num. with '
            text:=strTran(text,"$"+t+"$",value)
            exit
          otherwise
            // nop
          endswitch
        endif

      endif
    endif
  next

return text
/** eom */

/*  writes excel sheet  to disk */
METHOD commit( fileName )
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
  // keine Warnung wenn Datei bereits exisitiert!
  BEGIN SEQUENCE // krit. Bereich

    ::oExcel:DisplayAlerts:=0
    //::fileName:=strtran(fileName,"\\",BACKSLASH) + ".xlsx"  // why replace \\
    if right(fileName,5) <> ".xlsx"
      ::fileName:=fileName + ".xlsx"
    else
      ::fileName:=fileName
    endif
    Trouble("excel", { ::filename, file(::filename) } )
    ::oSheet:SaveAs( ::filename )
    ::oExcel:WorkBooks:Close()
    ::oExcel:Quit()
    ::oExcel:=NIL
    RECOVER
    Error(::fileName + " konnte nicht geschrieben werden.||Datei noch offen?")
  END SEQUENCE
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

return self
/** eom */

  // /////////////////////////////////////////////////////////////////////////////////////

/** Helper Class to store column information */
CLASS ExcelColumn

DATA fieldName
DATA title
DATA formula
DATA codeblock
DATA type
DATA len
DATA dec
DATA excelColumnNr
DATA selected INIT .t.
DATA sum INIT .f.
DATA numberFormat
DATA verticalAlignment INIT 7

ENDCLASS
/** eoc - end of class */

// /////////////////////////////////////////////////////////////////////////////////////////

/** Open e excel file for reading */

FUNCTION openExcelWorkbook( fileName )
LOCAL oExcel
  IF ( oExcel:=win_oleCreateObject( "Excel.Application" ) ) != NIL
    #untranslate open(<list,...>) => db_open( { <list> } )
    oExcel:WorkBooks:open( fileName)
    #translate open(<list,...>) => db_open( { <list> } )
  endif
return oExcel
/** eof */


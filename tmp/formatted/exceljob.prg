/** Acts like a printer-job but prints to MS Excel, row by row
*/

#include "mystd.ch"

#include "hbclass.ch"

#include "hbwin.ch"
#include "hbgtinfo.ch"
#include "hbthread.ch"
#include "zeige.ch"

CLASS ExcelJob INHERIT printJob

DATA oSheet
DATA oExcel

DATA row INIT 0
DATA col INIT 1
DATA maxColumn INIT 1
DATA maxRow INIT 1

DATA currentlyRed INIT .f.

METHOD new( name )
METHOD initQueue()
METHOD print(aText,newLine)
METHOD endDoc(lAbortDoc)

METHOD bold(lBold)
METHOD large(lLarge)
METHOD small(lSmall)
METHOD little(lLittle)
METHOD tiny(lTiny)

METHOD getInitString()
METHOD setFontSize(size,lPar,specialChar,escOn,escOff) HIDDEN
METHOD formfeed(Zeile , Seite , duplex)

METHOD color(r,g,b)
METHOD colorRed()
METHOD colorDefault()

METHOD summe( row , col )
METHOD colNumberFormat( rowStart , rowEnd , col , format )

METHOD autoFitAll()
METHOD alignColumn()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new( name )
LOCAL akt_sel:=select()

  ::super:new()
  ::oExcel:=ExcelExport():new( name )
  ::oSheet:=::oExcel:getActiveSheet()

  // brauchen wie hier, wird in vielen Listen erwartet!
  if ! open("Drucker","Liste")
    select(akt_sel)
    return(.f.)
  endif
  select(akt_sel)

RETURN self

/*----------------------------------------------------------------------*/

// reset all data
METHOD initQueue()
return nil

/*----------------------------------------------------------------------*/

METHOD getInitString()
return NIL

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
LOCAL type,i

  if newline
    ::row++
    ::col:=1
  endif

  if aText==NIL .or. len(aText) == 0
    // newline only
    return NIL
  endif

  for i:=1 to len(aText)

    // checken ob character doch numerisch, wird gebarucht wegen str(...) Ausgabe
    if valtype(aText[i]) == "C" .and.;
      (type(aText[i])=="N" .or. (","$aText[i] .and. type(untransStr(aText[i]))=="N")) ;
      .and. ! kwOkay(aText[i])
      type:="N"
    else
      type:=NIL
    endif

    do case
      // nop
    case aText[i] == NIL

      // Sonderzeichen?
    case valtype(aText[i]) == "O" .and. aText[i]:className()=="PRINTSONDERZEICHEN"
      aText[i]:getPrintChars( self ) // -> calls ::bold etc.
      loop

    case valtype(aText[i]) == "C" .and. type <> "N"
      /** Info:  ole bug, excel crashes on wrong formula, when left(value,1) == "=M�ll" */
      if left( aText[i] , 1 ) == "'"
        ::oSheet:Cells( ::row , ::col ):value:=aText[i]
      else
        ::oSheet:Cells( ::row , ::col ):value:="'" + aText[i]
      endif

    case valtype(aText[i]) == "N" .or. type == "N"
      ::oSheet:Cells( ::row, ::col ):value:=aText[i]
      // if oCol:numberformat<>NIL
      // ::oSheet:Cells(i, ::col):numberformat:=oCol:numberformat
      // elseif oCol:dec<>NIL // assign default format based on decimials
      // // #,##0.00;[Rot]-#,##0.00
      // ::oSheet:Cells(i, ::col):numberformat:="#,##."+replicate("0",oCol:dec)+;
      // ";[Rot]-#,##."+replicate("0",oCol:dec)
      // endif

    case valtype(aText[i]) == "D"
      ::oSheet:Cells( ::row, ::col ):value:=aText[i]
      // ::oSheet:Cells(i, ::col):numberformat:="dd/mm/yy;@"

    otherwise
      ::oSheet:Cells( ::row ,::col ):value:="'???" + toString( aText[i] )
      trouble("valtype",{ "ACHTUNG valtype nicht definiert",valtype(aText[i]) })
      trouble("valtype",stacktrace())
    endcase

    // bold if applicable
    if ::currentlyBold
      ::oSheet:Cells( ::row ,::col ):Font:Bold:=.t.
    endif

    // red (only supported color as of now)
    if ::currentlyRed
      ::oSheet:Cells( ::row ,::col ):Font:ColorIndex:=3 // red
    endif

    ::col++

  next i

  // rememmber max. column
  if ::col > ::maxColumn
    ::maxColumn:=::col
  endif

  // rememmber max. row
  if ::row > ::maxRow
    ::maxRow:=::row
  endif

RETURN NIL
/** eof */

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
  default lAbortDoc:=.f.

  if !lAbortDoc .and. ::row > 1

    ::oExcel:adjustAll( ::maxRow , ::maxColumn )

    default ::jobName:="NoName.xlsx"
    ::oExcel:commit( ::jobName )
  else
    Error("Keine Datens�tze in Auswahl.",.t.)
  endif

RETURN NIL

/*----------------------------------------------------------------------*/
METHOD autoFitAll( )
LOCAL allRange:="A1:"+chr(63 + ::maxColumn)+alltrim(str(::maxRow))
  if ::row > 1
    ::oSheet:Range( allRange ):Columns:AutoFit()
  endif
RETURN NIL
/*----------------------------------------------------------------------*/


METHOD bold(lPar)

  if lPar // bold on
    ::currentlyBold:=.t.
  else
    ::currentlyBold:=.f.
  endif

RETURN ""

/*----------------------------------------------------------------------*/

METHOD large(lPar)
  ignore lPar
RETURN ""

/*----------------------------------------------------------------------*/

METHOD small(lPar)
  ignore lPar
RETURN ""

/*----------------------------------------------------------------------*/

METHOD little(lPar)
  ignore lPar
RETURN ""

/*----------------------------------------------------------------------*/

METHOD tiny(lPar)
  ignore lPar
RETURN ""

/*----------------------------------------------------------------------*/

METHOD color(r,g,b)
  ignore r,g,b
RETURN ""

/*----------------------------------------------------------------------*/
// red (only supported color as of now)
METHOD colorRed()
  ::currentlyRed:=.t.
RETURN PrintSonderzeichen():New( HB_COLOR ) // must be Sonderzeichen so column is not incremented

METHOD colorDefault()
  ::currentlyRed:=.f.
RETURN PrintSonderzeichen():New( HB_COLOR ) // must be Sonderzeichen so column is not incremented

/*----------------------------------------------------------------------*/
METHOD setFontSize(size,lPar,specialChar,escOn,escOff)
  ignore size,lPar,specialChar,escOn,escOff
return ""

/*----------------------------------------------------------------------*/
METHOD formfeed(Zeile , Seite , duplex)
  ignore Zeile , Seite , duplex
return ""

/*----------------------------------------------------------------------*/
METHOD summe( row , col )
  ::oExcel:summe( row, col )
return self

/*----------------------------------------------------------------------*/
METHOD colNumberFormat( rowStart , rowEnd , col , format )
LOCAL j
  for j:=rowStart to rowEnd
    ::oSheet:Cells(j, col):numberformat:=format
  next
return self

/*----------------------------------------------------------------------*/

 /** left or right align f�r die Spalte, maxRow muss �bergeben werdem. */
METHOD alignColumn( col , align)
local ExcelColumnNr:=chr(64 + col), allRange

  default align:=-4131 // xlLabelPositionLeft

  allRange:=ExcelColumnNr+"1:"+ExcelColumnNr+alltrim(str(::maxRow))
  ::oSheet:Range( allRange ):Columns:HorizontalAlignment = align

return self
/** eom */
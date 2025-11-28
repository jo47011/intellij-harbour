/** Class for collecting multiple lines for printing using harbour */

#include "mystd.ch"

#include "hbclass.ch"

CLASS printBuffer

DATA allTextLines INIT {} READONLY
DATA ignore INIT .f. // if .t. all changes to the printBuffer are ignored -> /dev/null
DATA leftMargin INIT 0

METHOD new()
METHOD addTextLine( aText )
METHOD addNewLine()
METHOD insertTextLine( pos , aText ) // inserts line at the specified position, 1 is first line
METHOD insertTopTextLine( aText ) // inserts line at the beginning
METHOD addText( aText )
METHOD addBuffer( oBuffer ) // h�ngt den Inhalt des �bergebenen printBuffers an (concat)
METHOD getText( )
METHOD getPlainText( )
METHOD getNumLines( )
METHOD getPrintableArray( aText ) HIDDEN
METHOD underLine( ) // prints - under the last line (adjust length)
METHOD popTop() // returns 1st element and shrinks the rest

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
  // nop
RETURN self

/*----------------------------------------------------------------------*/

METHOD addTextLine( aText )
  if ! ::ignore
    aadd(::allTextLines, ::getPrintableArray( aText ))
  endif
return self

/*----------------------------------------------------------------------*/
METHOD addNewLine()
  if ! ::ignore
    aadd(::allTextLines , {} )
  endif
return self

/*----------------------------------------------------------------------*/
METHOD addBuffer( oBuffer )
LOCAL text
  if ! ::ignore
    for each text in oBuffer:getText()
      ::addTextLine(text)
    next
  endif
return self

/*----------------------------------------------------------------------*/
METHOD insertTextLine( pos, aText)
  if ! ::ignore
    HB_AIns(::allTextLines,pos,::getPrintableArray( aText ),.t.)
  endif
return self

/*----------------------------------------------------------------------*/
METHOD insertTopTextLine( aText)
  if ! ::ignore
    HB_AIns(::allTextLines,1,::getPrintableArray( aText ),.t.)
  endif
return self

/*----------------------------------------------------------------------*/

METHOD addText( aText )
LOCAL lastLine:=len(::allTextLines),text

  if ! ::ignore
    if lastLine==0
      ::addTextLine(aText)
    else
      for each text in aText
        aadd(::allTextLines[lastLine],text)
      next
    endif
  endif

return self

/*----------------------------------------------------------------------*/

METHOD getText( )
return ::allTextLines

/*----------------------------------------------------------------------*/

METHOD getPlainText(separator)
LOCAL result:="" , line, i
  default separator:="\n"
  for each line in ::allTextLines
    for each i in line
      result += toString(i, .f.) + " "
    next
    result += separator
  next
return result

/*----------------------------------------------------------------------*/

METHOD getNumLines( )
return len(::allTextLines)

/*----------------------------------------------------------------------*/

METHOD underLine( char )
LOCAL copyLine, el

  default char:="-"
  copyLine:=aClone( ::allTextLines[::getNumLines()] )
  copyLine:=aDel( copyLine , 1 , .t.) // remove margin

  for each el in copyLine
    if el <> NIL
      el:=replicate(char,len(el))
    endif
  next

  ::addTextLine( copyLine )
return self

/*----------------------------------------------------------------------*/

/** adds spaces left to text based on ::leftMargin, always returns an array */
METHOD getPrintableArray( aText )
LOCAL result

  // shift lm?
  if ::leftMargin > 0

    // is Array already?
    if valtype(aText)=="A"
      // join makes a copy here so we do not change the original array
      result:=aJoin( { space( ::leftMargin - 1 ) } , aText )
    else // kein Array
      result:={ space( ::leftMargin - 1 ) , aText }
    endif

  else // no shift
    if valtype(aText) == "A"
      result:=aText
    else
      result:={ aText }
    endif

  endif
return result
/** eom */

  /*----------------------------------------------------------------------*/

/** adds spaces left to text based on ::leftMargin, always returns an array */
METHOD popTop()
LOCAL result:=NIL
  if ::getNumLines() > 0
    result:=::allTextLines[1]
    ::allTextLines:=HB_ADel(::allTextLines, result, .t.)
  endif
return result
/** eom */


#include "mystd.ch"

#include "hbclass.ch"

CLASS DummyJob INHERIT printJob

METHOD new(quiet)
METHOD initQueue() // NOP
METHOD print(aText,newLine)
METHOD endDoc(lAbortDoc)

METHOD bold(lBold)
METHOD large(lLarge)
METHOD small(lSmall)
METHOD little(lLittle)
METHOD tiny(lTiny)

METHOD color(r,g,b)

METHOD autoFitAll()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(quiet)
  ::super:new()
  if quiet==NIL .or. ! quiet
    Trouble("DummyJob", { "Fixed with DummyJob." } )
  endif
RETURN self

/*----------------------------------------------------------------------*/

METHOD initQueue()
  // NOP
return nil

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
  ignore newline,aText

RETURN NIL
/** eof */

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
  ignore lAbortDoc
RETURN NIL

/*----------------------------------------------------------------------*/


METHOD bold(lBold)
  ignore lBold
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
METHOD autoFitAll( )
RETURN NIL



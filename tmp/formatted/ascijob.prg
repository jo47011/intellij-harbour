#include "mystd.ch"

#include "hbclass.ch"

#include "hbwin.ch"
#include "hbgtinfo.ch"
#include "hbthread.ch"

CLASS ASCIJob INHERIT printJob

METHOD endDoc(lAbortDoc)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
LOCAL akt_sel:=select()
  default lAbortDoc:=.f.

  set alte off
  close alte
  set cons on

  if lAbortDoc

    // delete temp files
    ferase(::ascFullFileName)

  endif

RETURN NIL

/*----------------------------------------------------------------------*/


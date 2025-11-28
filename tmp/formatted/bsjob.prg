#include "mystd.ch"

#include "hbclass.ch"

#include "hbwin.ch"
#include "hbgtinfo.ch"
#include "hbthread.ch"
#include "zeige.ch"

#define TEMP_ZEIGE_MT (TEMP_USER+BACKSLASH+"zeig"+getUser():counter+::id+".dbf")

/**
* Displays a list on the screen using Zeige.prg.
*
* Info: set fixed header lines using mystd.ch: _____fixedHeader_____
*
*/
CLASS BSJob INHERIT printJob

DATA callerName

// position of special numbers in zeige, e.g. KundNr,ArtNr
DATA pArtNr INIT ""
DATA pKundNr INIT ""
DATA pLiefNr INIT ""
DATA pInLfdNr INIT ""
DATA pAufNr INIT ""
DATA pRechNr INIT ""
DATA pBestNr INIT ""
DATA pInnerNr INIT ""
DATA pAngNr INIT ""
DATA pMenge INIT ""

DATA fixedHeader INIT {} HIDDEN
DATA inFixedHeaderRange INIT .f. HIDDEN

METHOD new()
METHOD initQueue()
METHOD print(aText,newLine)
METHOD endDoc(lAbortDoc)
METHOD getFixedHeaderLines()
METHOD fixHeaderLines()
METHOD dropHeaderLines()

METHOD bold(lBold)
METHOD large(lLarge)
METHOD small(lSmall)
METHOD little(lLittle)
METHOD tiny(lTiny)

METHOD color(r,g,b)
METHOD formfeed(Zeile , Seite , duplex)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
LOCAL akt_sel:=select()

  ::super:new()

  if ! open("Zeige","Drucker","Liste")
    select(akt_sel)
    return(.f.)
  endif
  select Zeige // immer leer bei neuem DruckJob
  zap

  select Drucker
  seek "BS"
  if eof()
    if ! add_rec(5)
      select (akt_sel)
      RETURN NIL
    endif
    replace DRUCKER->DruckerNr with "BS"
    replace DRUCKER->Laenge with 66
    replace DRUCKER->Bez with "Bildschirm-Ausgabe"
    dbcommit()
    unlock
  endif

  select Liste
  dbseek("BS")
  if LISTE->(eof())
    add_rec(0)
    replace LISTE->Liste_Kurz with "BS"
    replace LISTE->UNT_RAND with 2
    dbcommit()
    dbunlock()
  endif

  select(akt_sel)
RETURN self

/*----------------------------------------------------------------------*/

// reset all data
METHOD initQueue()
  if ::generatePDF
    ::super:initQueue()
  endif

  ::pArtNr:=""
  ::pKundNr:=""
  ::pLiefNr:=""
  ::pInLfdNr:=""
  ::pAufNr:=""
  ::pRechNr:=""
  ::pBestNr:=""
  ::pInnerNr:=""
  ::pMenge:=""
return nil

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
LOCAL i ,tempStr
LOCAL pos , type

  _thread static zeile:=""

  if ::generatePDF
    ::super:print(aText,newLine)
  endif

  // don't print fixed header on 2nd or higher page
  if len( ::fixedHeader ) > 0 .and. ::inFixedHeaderRange
    return nil
  endif

  if newline
    ZEIGE->(dbappend())
    zeile:=""
    ::lastLineEmpty:=.t.
  endif

  if aText==NIL .or. len(aText) == 0
    // newline only
    return NIL
  endif

  // doch kein �bertrag der gemerkten Nummern auf die n�chste Zeile
  // geht sonst ohne Leerzeile schief, also immer reset
  ::pArtNr:=""
  ::pKundNr:=""
  ::pLiefNr:=""
  ::pInLfdNr:=""
  ::pAufNr:=""
  ::pRechNr:=""
  ::pAngNr:=""
  ::pBestNr:=""
  ::pInnerNr:=""
  ::pMenge:=""


  for i:=1 to len(aText)
    do case
      // nop
    case aText[i] == NIL

      // Sonderzeichen?
    case valtype(aText[i]) == "O" .and. aText[i]:className()=="PRINTSONDERZEICHEN"
      // we ignore PrintSonderZeichen and others, hope this is correct
      // qqout( aText[i]:getPrintChars( self ) )

    case valtype(aText[i]) == "C"

      // pr�fe ob Positionsangabe f�r launch vorhanden
      do while (pos:=at( ZEIGE_LAUNCH_CHAR , aText[i] )) > 0
        // find type string
        type:=substr( aText[i] , pos , 2 )

        // remove type string - 1st occurrence only
        aText[i]:=strTran(aText[i] , type , nil , 1 , 1 )

        // assign column
        switch type
        case ZEIGE_XX_ARTNR
          ::pArtNr:=substr( aText[i] , pos , len(ZEIGE->ArtNr) )
          if at(".",::pArtNr) > 0
            ::pArtNr:=invOut( substr( aText[i] , pos , len(out(ZEIGE->ArtNr)) ) )
          endif
          exit
        case ZEIGE_XX_KUNDNR
          ::pKundNr:=substr( aText[i] , pos , len(ZEIGE->KundNr) )
          exit
        case ZEIGE_XX_LIEFNR
          ::pLiefNr:=substr( aText[i] , pos , len(ZEIGE->LiefNr) )
          exit
        case ZEIGE_XX_NUMMER
          ::pInLfdNr:=substr( aText[i] , pos , len(ZEIGE->InLfdNr) )
          exit
        case ZEIGE_XX_AUFNR
          ::pAufNr:=substr( aText[i] , pos , len(ZEIGE->AufNr) )
          exit
        case ZEIGE_XX_RECHNR
          ::pRechNr:=substr( aText[i] , pos , len(ZEIGE->RechNr) )
          exit
        case ZEIGE_XX_ANGNR
          ::pAngNr:=substr( aText[i] , pos , len(ZEIGE->AngNr) )
          exit
        case ZEIGE_XX_BESTNR
          ::pBestNr:=substr( aText[i] , pos , len(ZEIGE->BestNr) )
          exit
        case ZEIGE_XX_INNERNR
          ::pInnerNr:=substr( aText[i] , pos , len(ZEIGE->InnerNr) )
          exit
        case ZEIGE_XX_INLFDNR
          ::pInLfdNr:=substr( aText[i] , pos , len(ZEIGE->InLfdNr) )
          exit
        case ZEIGE_XX_MENGE
          // ACHTUNG: L�nge der Menge kann abweichen, deswegen nehme immer ganzes Feld
          // d.h. Menge nicht mit + <irgendwas> ausser ZEIGE_MENGE+<menge>
          ::pMenge:=aText[i]
          exit
        endswitch
      enddo

      // checken ob doch numerisch
      if (type(aText[i])=="N" .and. val(aText[i]) < 0) .or. ;
        (","$aText[i] .and. type(tempstr:=untransStr(aText[i]))=="N" .and. val(tempStr) < 0)
        zeile+= " "+BS_FARBE+aText[i]+BS_FARBE
      else
        // map color postscript characster to BS color
        if aText[i]==COLOR_RED .or. aText[i]==COLOR_DEFAULT
          aText[i]:=BS_FARBE
        endif

        if aText[i]==BS_FARBE
          zeile+= aText[i]
        else
          zeile+= " "+aText[i]
        endif

      endif
    case valtype(aText[i]) == "N"
      if aText[i] < 0
        zeile+= " "+BS_FARBE+str(aText[i])+BS_FARBE
      else
        zeile+= " "+str(aText[i])
      endif
    case valtype(aText[i]) == "D"
      zeile+= " "+dtoc(aText[i])
    case valtype(aText[i]) == "L"
      if aText[i]
        zeile+= " J"
      else
        zeile+= " N"
      endif
    otherwise
      if DEVEL_PROG
        zeile+= "!!"
        Error(ACHTUNG+"unknown valtype:"+valtype(aText[i]))
      endif
      trouble("valtype",{ "ACHTUNG valtype nicht definiert",valtype(aText[i]) })
      trouble("valtype",stacktrace())
    endcase
  next i

  if ! empty(Zeile)
    ::lastLineEmpty:=.f.
  endif

  replace ZEIGE->Line with zeile
  if ! empty( ::pArtnr )
    replace ZEIGE->ArtNr with ::pArtNr
  endif
  if ! empty( ::pKundNr )
    replace ZEIGE->KundNr with ::pKundNr
  endif
  if ! empty( ::pLiefNr )
    replace ZEIGE->LiefNr with ::pLiefNr
  endif
  if ! empty( ::pInLfdNr )
    replace ZEIGE->InLfdNr with ::pInLfdNr
  endif
  if ! empty( ::pAufnr )
    replace ZEIGE->AufNr with ::pAufNr
  endif
  if ! empty( ::pRechnr )
    replace ZEIGE->RechNr with ::pRechNr
  endif
  if ! empty( ::pAngnr )
    replace ZEIGE->AngNr with ::pAngNr
  endif
  if ! empty( ::pBestnr )
    replace ZEIGE->BestNr with ::pBestNr
  endif
  if ! empty( ::pInnernr )
    replace ZEIGE->InnerNr with ::pInnerNr
  endif
  if ! empty( ::pMenge )
    replace ZEIGE->Menge with ::pMenge
  endif

RETURN NIL
/** eof */

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
  default lAbortDoc:=.f.

  if !lAbortDoc .and. ZEIGE->(reccount()) > 0

    if ::generatePDF
      // workaround: set default font if unset
      if empty(::defaultFontInitStr)
        ::defaultFontInitStr:=FONT_DEFAULT
      endif
      ::super:endDoc(lAbortDoc)
    endif

    if ::callerName==NIL
      // FIXME: there must be a smarter way!
      if procName(1)=="DRUCKER"
        ::callername:=procName(2) // called with Drucker("OFF")
      else
        ::callername:=procName(1) // called directlty in Liste with getUser():getCurrentPrintJob():endDoc()
      endif
      do case
      case ::callername=="LISTE"
        ::callername:=procName(3)
      case ::callername=="AEND"
        ::callername:=procName(1)
      endcase
    endif

    ZeigeText(NIL,::JobName,::callername,::Popup)
  else
    Error("Keine Datens�tze in Auswahl.",.t.)
  endif

RETURN NIL

/*----------------------------------------------------------------------*/
METHOD formfeed(Zeile , Seite , duplex)
  // if fixed header is set, remember we are now on 2nd or higher page in header
  if len( ::fixedHeader ) > 0
    ::inFixedHeaderRange:=.t.
  endif
return ::super:formfeed(Zeile , Seite , duplex)

/*----------------------------------------------------------------------*/

// all lines printed so far are locked on top of screen, default is none
METHOD fixHeaderLines()
LOCAL akt_sel:=select()

  // store header lines on 1st page / 1st time only
  if len( ::fixedHeader ) == 0
    ZEIGE->(dbgotop())
    do while ! ZEIGE->(eof())
      aadd( ::fixedHeader , ZEIGE->Line )
      ZEIGE->(dbskip())
    enddo
    select Zeige
    zap
    select (akt_sel)
  endif
  ::inFixedHeaderRange:=.f.

RETURN Nil

/*----------------------------------------------------------------------*/

// removes previous fixed headerlines (reset)
METHOD dropHeaderLines()
  ::fixedHeader:={}
  ::inFixedHeaderRange:=.f.
RETURN Nil

/*----------------------------------------------------------------------*/

METHOD getFixedHeaderLines()
return ::fixedHeader

/*----------------------------------------------------------------------*/


METHOD bold(lBold)
  ::currentlyBold:=lBold
RETURN BS_FARBE

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
  default r:=0
  default g:=0
  default b:=0
RETURN ::bold(r>0 .or. g>0 .or. b>0)


#include "mystd.ch"

#include "hbclass.ch"

#include "hbqtgui.ch"

CLASS QTJob INHERIT printJob

DATA qtEditor
DATA qtCursor

METHOD new()
METHOD initQueue() // NOP
METHOD print(aText,newLine)
METHOD endDoc(lAbortDoc)
METHOD formfeed(Zeile,Seite)

METHOD bold(lBold)
METHOD large(lLarge)
METHOD small(lSmall)
METHOD little(lLittle)
METHOD tiny(lTiny)

METHOD color(r,g,b)
METHOD colorRed()
METHOD colorRedLight()
METHOD colorDefault()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
  ::super:new()

  if type("M->qtWidget")<>"U" // we use QT currently
    ::qtEditor:=M->qtWidget
    ::qtCursor:=::qtEditor:textCursor()
  endif

RETURN self

/*----------------------------------------------------------------------*/

METHOD initQueue()
  ::qtCursor:beginEditBlock()
return nil

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
LOCAL i,tempStr
LOCAL qtFormat:=::qtCursor:charFormat()


  if newline // .and. ! empty(::qtEditor:toPlainText())
    ::qtCursor:insertText(HB_OSNewLine(), @qtFormat)
  endif

  if aText==NIL
    // newline only?
    return NIL
  endif

  for i:=1 to len(aText)
    do case
    case valtype(aText[i]) == "C"
      // checken ob doch numerisch
      if (type(aText[i])=="N" .and. val(aText[i]) < 0) .or. ;
        (","$aText[i] .and. type(tempstr:=untransStr(aText[i]))=="N" .and. val(tempStr) < 0)
        ::colorRed():apply(::qtEditor,@qtFormat)
        ::qtCursor:insertText(aText[i], @qtFormat)
        ::colorDefault():apply(::qtEditor,@qtFormat)
      else
        ::qtCursor:insertText(aText[i], @qtFormat)
      endif
      ::qtCursor:insertText(" ", @qtFormat)
    case valtype(aText[i]) == "N"
      if aText[i] < 0
        ::colorRed():apply(::qtEditor,@qtFormat)
        ::qtCursor:insertText(str(aText[i]), @qtFormat)
        ::qtCursor:insertText(" ", @qtFormat)
        ::colorDefault():apply(::qtEditor,@qtFormat)
      else
        ::qtCursor:insertText(str(aText[i]), @qtFormat)
        ::qtCursor:insertText(" ", @qtFormat)
      endif
    case valtype(aText[i]) == "D"
      ::qtCursor:insertText(dtoc(aText[i]), @qtFormat)
      ::qtCursor:insertText(" ", @qtFormat)
    case valtype(aText[i]) == "O"
      if aText[i]:className()=="QT_SONDERZEICHEN"
        aText[i]:apply(::qtEditor,@qtFormat)
      else
        Error(ACHTUNG+"valtype nicht definiert:"+valtype(aText[i])+SCHWERER_FEHLER)
      endif
    case valtype(aText[i]) == "U"
      ::qtCursor:insertText(aText[i], @qtFormat) // We print NIL for backward compatability
      ::qtCursor:insertText(" ", @qtFormat)
    otherwise
      Error(ACHTUNG+"valtype nicht definiert:"+valtype(aText[i])+SCHWERER_FEHLER)
    endcase
  next i

RETURN NIL
/** eof */

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
  default lAbortDoc:=.f.

  ::qtCursor:endEditBlock()
  if !lAbortDoc .and. empty(::qtEditor:toPlainText())
    Error("Keine Datens�tze in Auswahl.",.t.)
  endif


RETURN NIL


METHOD bold(lPar)
LOCAL result

  if lPar // bold on
    result:=QT_Sonderzeichen():New( HB_AN_FETT )
  else
    result:=QT_Sonderzeichen():New( HB_AUS_FETT )
  endif

RETURN result

/*----------------------------------------------------------------------*/


METHOD large(lPar)
LOCAL result

  if lPar // bold on
    result:=QT_Sonderzeichen():New( HB_AN_BREIT )
  else
    result:=QT_Sonderzeichen():New( HB_AUS_BREIT )
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD small(lPar)
LOCAL result

  if lPar // bold on
    result:=QT_Sonderzeichen():New( HB_AN_SCHMAL)
  else
    result:=QT_Sonderzeichen():New( HB_AUS_SCHMAL )
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD little(lPar)
LOCAL result

  if lPar // bold on
    result:=QT_Sonderzeichen():New( HB_AN_KLEIN )
  else
    result:=QT_Sonderzeichen():New( HB_AUS_KLEIN )
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD tiny(lPar)
LOCAL result

  if lPar // bold on
    result:=QT_Sonderzeichen():New( HB_AN_WINZIG )
  else
    result:=QT_Sonderzeichen():New( HB_AUS_WINZIG )
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD color(r,g,b)
RETURN QT_Sonderzeichen():New( HB_COLOR,r,g,b)

/*----------------------------------------------------------------------*/

METHOD colorRed()
RETURN ::color(1,0,0)
/*----------------------------------------------------------------------*/
METHOD colorRedLight()
RETURN ::color(0.5,0,0)
/*----------------------------------------------------------------------*/
METHOD colorDefault()
RETURN ::color(0,0,0)


/*----------------------------------------------------------------------*/

METHOD formfeed(Zeile,Seite)
  ignore Seite

  ::print(,.t.)
  zeile++
  ::print(,.t.)
  zeile++

  // FIXME: Display Info Message
  // if valtype(Seite)<>"U"
  // @ MaxRow(),0 say "Seite: "+alltrim(str(Seite))
  // endif
  if Seite==MAX_NOF_PAGES
    if getUser():id==SERVER_LOGIN
      keyboard chr(K_ESC)
    else
      if Message("Dokument hat �ber "+alltrim(str(MAX_NOF_PAGES))+" Seiten.  Wollen Sie "+;
        "abbrechen? (@J@/@N@)","JN","N")=="J"
        Trouble("root",{"Dokument mit �ber "+alltrim(str(MAX_NOF_PAGES))+" Seiten. Benutzer "+;
          "Abbruch"})
        // FIXME: maybe there is a smarter way to get out of a potential loop?
        down()
      endif
    endif
  endif

RETURN 0

/*----------------------------------------------------------------------*/

/*******************************************************************
 * Class QT_SONDERZEICHEN
 * Klasse zur Kapselung der Sonderzeichen (FETT_AN/AUS etc.) im Windows Druck
 *
 * Wird gebraucht, damit in einer Zeile z.B. FETT an und aus geschaltet werden kann.
 * Bsp:
 * ? WinPrnRef:bold(.t.),gaga,WinPrnRef:bold(.f.)
 * Sonst wird zuerst WinPrnRef:bold(.t.) und WinPrnRef:bold(.f.) ausgef�hrt und dann gaga gedruckt :(
 */
  CREATE CLASS QT_SONDERZEICHEN
  VAR art HIDDEN
  VAR red HIDDEN
  VAR green HIDDEN
  VAR blue HIDDEN

METHOD new( SZ,r,g,b )
METHOD apply( qtFormat )

ENDCLASS

METHOD New( SZ,r,g,b ) CLASS QT_SONDERZEICHEN
  ::art:=SZ
  if SZ==HB_COLOR
    ::red:=int(r*255)
    ::green:=int(g*255)
    ::blue:=int(b*255)
  endif
RETURN Self

METHOD apply(qtEditor,qtFormat) CLASS QT_SONDERZEICHEN
LOCAL lResult:=.t.

  do case
  case ::art == HB_AN_FETT
    qtFormat:setFontWeight(QFont_Bold)
  case ::art == HB_AUS_FETT
    qtFormat:setFontWeight(QFont_Normal)
  case ::art == HB_AN_BREIT
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_BREIT) )
  case ::art == HB_AUS_BREIT
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD) )
  case ::art == HB_AN_SCHMAL
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_SCHMAL) )
  case ::art == HB_AUS_SCHMAL
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD) )
  case ::art == HB_AN_KLEIN
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_KLEIN) )
  case ::art == HB_AUS_KLEIN
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD) )
  case ::art == HB_AN_WINZIG
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_WINZIG) )
  case ::art == HB_AUS_WINZIG
    qtFormat:setFont( QFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD) )
  case ::art == HB_COLOR
    // FIXME: color not yet working
    // if ::red>0
    // qtFormat:setFontWeight(QFont_Bold)
    // else
    // qtFormat:setFontWeight(QFont_Normal)
    // endif
    // qtFormat:foreground():setColor(Qt_red )
    qtFormat:setForeground( QBrush( QColor(::red,::green,::blue)))
    ignore qtEditor
  otherwise
    Error(ACHTUNG+"Harbour-Druck fehlgeschlagen:|         unbekanntes Sonderzeichen:",.t.)
    lResult:=.f.
  endcase

RETURN lresult
/** EOC */


#include "mystd.ch"

#include "hbclass.ch"

#include "hbwin.ch"
#include "common.ch"
#include "hbgtinfo.ch"
#include "hbthread.ch"

#define TEMP_ZEIGE_MT (TEMP_USER+BACKSLASH+getUser():getLongID()+"ze"+::id+".dbf")


/** This class prints directly to the printer using hbwin API
 * (see c:/Harbour-src/contrib/hbwin/win_tprn.prg)
 *
 * As of now we use ist for the label printing to avoid labels to be
 * cut after each label which happens using as with WIN_PRINTFILERAW
 *
 * FIXME: LISTE_SCHMAL etc. not yet working when set for entire list
 */

CLASS WinPrnJob INHERIT printJob

// Reference to Harbour WIN_PRN class (see c:/Harbour-src/contrib/hbwin/win_tprn.prg)
DATA winPrnRef
DATA lines INIT 0 HIDDEN

METHOD initQueue()
METHOD print(aText,newLine)
// METHOD printFile(fileName)
METHOD endDoc(lAbortDoc)
METHOD setFontSize(lPar,size,specialChar,escOn,escOff) HIDDEN
METHOD formfeed()

METHOD bold(lBold)
METHOD large(lLarge)
METHOD small(lSmall)
METHOD little(lLittle)
METHOD tiny(lTiny)

METHOD color(r,g,b)
METHOD setLeftMargin(lm)
METHOD printAllFonts()
METHOD getFontName()

METHOD drawBitMap( oBmp )
METHOD drawSysInfo( text )

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD initQueue()
LOCAL PrintServer:=trim(DRUCKER->PrintSrv)
LOCAL PrinterQueue
LOCAL queueName:=trim(DRUCKER->Queue)
LOCAL time:=seconds()
LOCAL RETRIES:=3, count:=0

  if AT_HOME
    PrintServer:=getProperty("System.printer.server",trim(DRUCKER->PrintSrv))
    queueName:=getProperty("System.printer.queue",trim(DRUCKER->Queue))
  endif

  if empty(PrintServer)
    PrinterQueue:=queueName
  else
    PrinterQueue:=BACKSLASH + BACKSLASH + PrintServer + BACKSLASH + queueName
  endif

  // erzeuge neues Harbour WIN_PRN Objekt
  ::winPrnRef:=WIN_PRN():New( PrinterQueue )

  ::winPrnRef:Copies:=::numCopies
  // ::winPrnRef:AskProperties:=.t.

  // qout("new:"+str(seconds()-time)+" sec");time:=seconds()

  // ::winPrnRef:Create()
  // qout("create:"+str(seconds()-time)+" sec");time:=seconds()

  // ::winPrnRef:StartDoc(::jobName)
  // qout("startDoc:"+str(seconds()-time)+" sec");time:=seconds()

  // try multiple times
  do while count <= RETRIES

    if ::winPrnRef:Create() .and. ::winPrnRef:StartDoc(::jobName)
      // great we are done
      exit
    else
      createTempPaths()
      TroubleEmail("winprnjob: created temp path")
    endif

    count++

    if count >= RETRIES
      default ::jobName:="NoName"
      Error(ACHTUNG+"Harbour-Druck fehlgeschlagen:|         "+PrinterQueue+"->"+::jobName+;
        "!",.t.,"root")
      return .f.
    endif
  enddo

  // write Test or Devel if such system
  if DEVEL_PROG
    ::drawSysInfo("Devel")
  elseif TEST_PROG .and. ! file ("NO_TEST.txt")
    ::drawSysInfo("Test")
  endif

  // setze Default Font
  ::winPrnRef:SetFont(if(empty(DRUCKER->Font),ETI_FONT_STANDARD,trim(DRUCKER->Font)),;
    ETI_FONTSIZE_STANDARD,ETI_FONT_WIDTH,0,.f.,.f.,ETI_FONT_CHARSET)

  // setze left margin
  ::setLeftMargin(val(DRUCKER->LR))

  // qout("initQ-End:"+str(seconds()-time)+" sec");time:=seconds()

return nil

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
LOCAL i, tempVal

  if newline
    ::lines++
    ::winPrnRef:NewLine()
    ::lastLineEmpty:=.t.
  endif

  for i:=1 to len(aText)
    do case
    case aText[i] == NIL

    case aText[i]:className()=="PRINTSONDERZEICHEN"
      tempVal:=aText[i]:getPrintChars( self )
      if tempVal != NIL
        ::winPrnRef:TextOut( tempVal , .f., .t., 0 )
        ::lastLineEmpty:=.f.
      endif

    case valtype(aText[i]) == "C"
      ::winPrnRef:TextOut( aText[i] , .f., .t., 0 )
      ::winPrnRef:TextOut( ' ' , .f., .t., 0 )
      ::lastLineEmpty:=.f.
    case valtype(aText[i]) == "N"
      ::winPrnRef:TextOut( str(aText[i]) , .f., .t., 0 )
      ::winPrnRef:TextOut( ' ' , .f., .t., 0 )
      ::lastLineEmpty:=.f.
    case valtype(aText[i]) == "D"
      ::winPrnRef:TextOut( dtoc(aText[i]) , .f., .t., 0 )
      ::winPrnRef:TextOut( ' ' , .f., .t., 0 )
      ::lastLineEmpty:=.f.
    case valtype(aText[i]) == "U"
      ::winPrnRef:TextOut( aText[i] , .f., .t., 0 )
      ::winPrnRef:TextOut( ' ' , .f., .t., 0 )
      ::lastLineEmpty:=.f.
    otherwise
      Error(ACHTUNG+"valtype nicht definiert:"+valtype(aText[i])+SCHWERER_FEHLER)
    endcase
  next i

RETURN NIL
/** eof */

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
LOCAL time:=seconds()
  default lAbortDoc:=.F.

  // avoid printing empty page
  if ::lines==0
    lAbortDoc:=.t.
  endif

  ::winPrnRef:endDoc(lAbortDoc)
  // qout("endDoc:"+str(seconds()-time)+" sec");time:=seconds()
  // wait

RETURN NIL

/*----------------------------------------------------------------------*/

METHOD bold(lPar)
LOCAL result

  if lPar // bold on
    // winPrnRef:bold(600)
    ::winPrnRef:bold(900)
  else
    ::winPrnRef:bold(0)
  endif

RETURN result

/*----------------------------------------------------------------------*/


METHOD large(lPar)
LOCAL result

  if lPar // bold on
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_BREIT)
  else
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD)
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD small(lPar)
LOCAL result

  if lPar // bold on
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_SCHMAL)
  else
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD)
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD little(lPar)
LOCAL result

  if lPar // bold on
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_KLEIN)
  else
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD)
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD tiny(lPar)
LOCAL result

  if lPar // bold on
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_WINZIG)
  else
    ::winPrnRef:SetFont( ETI_FONT_STANDARD, ETI_FONTSIZE_STANDARD)
  endif

RETURN result

/*----------------------------------------------------------------------*/

METHOD color(r,g,b)
  default r:=0
  default g:=0
  default b:=0
RETURN ::bold(r>0 .or. g>0 .or. b>0)

/*----------------------------------------------------------------------*/

METHOD setFontSize(lPar,size,specialChar,escOn,escOff)
  ignore specialChar,escOn,escOff

  if lPar // on
    ::winPrnRef:SetFont(ETI_FONT_STANDARD,size,{size,0})
  else
    ::winPrnRef:SetFont(ETI_FONT_STANDARD,ETI_FONTSIZE_STANDARD,{ETI_FONTSIZE_STANDARD,0})
  endif

RETURN NIL


/*----------------------------------------------------------------------*/

METHOD formfeed(Zeile,Seite)
  ignore Zeile

  ::winPrnRef:EndPage(.t.) // prepare next page (.t. ist default)

  if valtype(Seite)<>"U"
    @ MaxRow(),0 say "Seite: "+alltrim(str(Seite))
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
  endif

RETURN NIL
/*----------------------------------------------------------------------*/

  /**
  * Sets the left margin of the printer,
  * automatically calculates the right margin based on ::PageWidth and lm
  */
METHOD setLeftMargin(lm)
  ::winPrnRef:LeftMargin:=lm * ::winPrnRef:CharWidth

  // in win_tprn it gets initailized like this
  // ::LeftMargin:=win_GetDeviceCaps( ::hPrinterDC, WIN_PHYSICALOFFSETX )+lm
  // ::RightMargin:=( ::PageWidth - ::LeftMargin ) + 1
RETURN NIL
/*----------------------------------------------------------------------*/

  /**
  * Prints all fonts
  */
METHOD printAllFonts()
LOCAL x,aFonts:=::winPrnRef:GetFonts()
LOCAL nColFixed:=40 * ::winPrnRef:CharWidth
LOCAL nColTTF:=48 * ::winPrnRef:CharWidth
LOCAL nColCharSet:=60 * ::winPrnRef:CharWidth

  ::winPrnRef:NewLine()
  FOR x:=1 TO Len( aFonts ) STEP 2
    ::winPrnRef:CharSet( aFonts[ x, 4 ] )
    IF ::winPrnRef:SetFont( aFonts[ x, 1 ] )
      // Could use "IF ::winPrnRef:SetFontOk" after call to ::winPrnRef:SetFont()
      IF ::winPrnRef:FontName == aFonts[ x, 1 ] // Make sure Windows didn't pick a different font
        ::winPrnRef:TextOut( aFonts[ x, 1 ] )
        ::winPrnRef:SetPos( nColFixed )
        ::winPrnRef:TextOut( iif( aFonts[ x, 2 ], "Yes", "No" ) )
        ::winPrnRef:SetPos( nColTTF )
        ::winPrnRef:TextOut( iif( aFonts[ x, 3 ], "Yes", "No" ) )
        ::winPrnRef:SetPos( nColCharSet )
        ::winPrnRef:TextOut( Str( aFonts[ x, 4 ], 5 ) )
        ::winPrnRef:SetPos( ::winPrnRef:LeftMargin, ::winPrnRef:PosY +;
          ( ::winPrnRef:CharHeight * 2 ) )
        IF ::winPrnRef:PRow() > ::winPrnRef:MaxRow() - 16
          // Could use "::winPrnRef:NewPage()" to start a new page
          EXIT
        ENDIF
      ENDIF
    ENDIF

    ::winPrnRef:Line( 0, ::winPrnRef:PosY + 5, 2000, ::winPrnRef:PosY + 5 )
  NEXT
  ::winPrnRef:SetFont( "Lucida Console", 8, { 3, -50 } ) //

RETURN NIL
/*----------------------------------------------------------------------*/

METHOD getFontName()
return trim(::winPrnRef:FontName)
/*----------------------------------------------------------------------*/

METHOD drawBitMap( name ,posx, posy, posx2, posy2 )
LOCAL oBmp:=WIN_BMP():New()
  oBmp:loadFile(name)

  default posx:=0
  default posy:=0

  // // FIXME: rechter unterer Rand scheint nicht wirklich �nderbar?!
  if posx2==NIL
    posx2:=posx+(oBmp:DimXY[1]/::winPrnRef:CharWidth)
  else
    oBmp:DimXY[1]:=posx2-posx
  endif
  if posy2==NIL
    posy2:=posy+(oBmp:DimXY[2]/::winPrnRef:CharHeight)
  else
    oBmp:DimXY[2]:=posy2-posy
  endif

  oBmp:rect:={posx*::winPrnRef:CharWidth ,posy*::winPrnRef:CharHeight,;
    posx2*::winPrnRef:CharWidth,posy2*::winPrnRef:CharHeight}

return ::winPrnRef:DrawBitMap( oBmp )
/*----------------------------------------------------------------------*/



METHOD drawSysInfo( text )
LOCAL aOldPos:={ ::winPrnRef:PosX, ::winPrnRef:PosY }
  // TextAtFont( nPosX, nPosY, cString, cFont, nPointSize, nWidth, nBold, lUnderLine, lItalic, nCharSet,
  // lNewLine, lUpdatePosX, nColor, nAlign )
LOCAL result:=::winPrnRef:TextAtFont( 0,0, text ,"Courier",12,12,0,.f.,.f.,,.f.,.f.,120,0 )
  ::winprnRef:setPos(aOldPos[1],aOldPos[2])
return result


/*----------------------------------------------------------------------*/

// /** Testing printing entire file via WinPrn */
  // METHOD printFile(fileName)
  // if open("Zeige")
  // zap
  // appe from (filename) sdf
  // go top
  // do while ! eof()
  // ::winPrnRef:TextOut( ZEIGE->Line , .t., .t., 0 )
  // skip
  // enddo
  // endif

  // Return nil
/*----------------------------------------------------------------------*/


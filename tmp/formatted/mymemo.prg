/** Class for memo edit stuff
*
*
* see here for details: c:/Program Files/harbour-src/src/rtl/memoedit.prg
*                       c:/Program Files/harbour-src/src/rtl/teditor.prg
*/


#include "MyStd.ch"
#include "MyMemo.ch"

#include "hbclass.ch"

#include "Inkey.ch"
#include "Memoedit.ch"
#include "setcurs.ch"
#include "button.ch"
#include "hbgtinfo.ch"

_thread static grepSuche

CREATE CLASS MyMemoEditor INHERIT HBMemoEditor

DATA eventMask

METHOD new(;
  cString,;
  nTop,;
  nLeft,;
  nBottom,;
  nRight,;
  lEditMode,;
  xUserFunction,;
  nLineLength,;
  nTabSize,;
  nTextBuffRow,;
  nTextBuffColumn,;
  nWindowRow,;
  nWindowColumn )

METHOD SplitLine( nRow )
METHOD MoveCursor( nKey ) // Redefined to properly manage backspace
METHOD cleanUp() // called on exit
METHOD xDo( nStatus ) // Calls xUserFunction saving and restoring cursor position and sh
METHOD KeyboardHook( nKey )
METHOD display() // Redraw a window
METHOD RefreshLine() // Redraw a line
METHOD RefreshColumn() // Redraw a column of text
METHOD My_DispOutAt() // Draw a line with higlightening

ENDCLASS

/*----------------------------------------------------------------------*/
METHOD new(;
  cString,;
  nTop,;
  nLeft,;
  nBottom,;
  nRight,;
  lEditMode,;
  xUserFunction,;
  nLineLength,;
  nTabSize,;
  nTextBuffRow,;
  nTextBuffColumn,;
  nWindowRow,;
  nWindowColumn )

  // enable mouse events
  ::eventMask:=SET( _SET_EVENTMASK, INKEY_ALL - INKEY_MOVE ) // + HB_INKEY_GTEVENT )
  ::nWordWrapCol:=nRight

RETURN ::super:New(
  cString,;
  nTop,;
  nLeft,;
  nBottom,;
  nRight,;
  lEditMode,;
  xUserFunction,;
  nLineLength,;
  nTabSize,;
  nTextBuffRow,;
  nTextBuffColumn,;
  nWindowRow,;
  nWindowColumn )

/*----------------------------------------------------------------------*/
METHOD cleanUp() // called on exit
  SET( _SET_EVENTMASK, ::eventMask )
return self

/*----------------------------------------------------------------------*/
METHOD MoveCursor( nKey )
  Do Case

    // mouse wheel
  Case nKey == K_MWBACKWARD      /* Mouse Wheel Forward */
    nKey:=K_DOWN
  Case nKey == K_MWFORWARD     /* Mouse Wheel Backward */
    nKey:=K_UP

    // mouse clicked
    // WATCHOUT: the 1st click is a button up (!) don't know why!
  case ( nKey == K_LBUTTONDOWN ) .or. ( nKey == K_LBUTTONUP ) .or. ( nKey == K_LDBLCLK )
    if ::hitTest( mrow() , mCol() ) == HTCLIENT

      // don't add lines if user clicks below text, just go to last line
      if mRow() - ::nTop + 1 + ::nFirstRow - 1 > ::lineCount() // we bail out with K_END
        nKey:=K_PGDN
      else
        // Now apply mouse click position
        ::nRow:=mRow() - ::nTop + 1 + ::nFirstRow - 1
        ::nCol:=mCol() - ::nLeft + 1 + ::nFirstCol - 1
        // ::setpos( mrow() , mCol() )
      endif
    endif

    /** ctrl-c copy context, only when ctrl is pressed to avoid duplicate assignment of key value */
  case ( nKey == K_CTRL_C ) .and. hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL )
    hb_gtInfo( HB_GTI_CLIPBOARDDATA, ::GetText() )

  endcase

RETURN ::Super:MoveCursor( nKey )

/*----------------------------------------------------------------------*/
  // If a line of text is longer than nWordWrapCol divides it into multiple lines,
// Used during text editing to reflow a paragraph
METHOD SplitLine( nRow )

LOCAL nFirstSpace
LOCAL cLine
LOCAL cSplittedLine
LOCAL nStartRow
LOCAL nOCol
LOCAL nORow
LOCAL lMoveToNextLine
LOCAL nPosInWord
LOCAL nI

  // Do something only if Word Wrapping is on
  IF ::lWordWrap .AND. ::LineLen( nRow ) > ::nWordWrapCol

    nOCol:=::Col()
    nORow:=::Row()

    // Move cursor to next line if you will move the word which I'm over to next line
    // ie, since word wrapping happens at spaces if first space is behind cursor
    lMoveToNextLine:=RAt( " ", RTrim( ::GetLine( nRow ) ) ) < ::nCol
    nPosInWord:=Len( ::GetLine( nRow ) ) - ::nCol

    nStartRow:=nRow
    cLine:=::GetParagraph( nRow )

    DO WHILE ! Empty( cLine )

      IF Len( cLine ) > ::nWordWrapCol
        nFirstSpace:=::nWordWrapCol

        // Split line at fist space before current position
        DO WHILE !( SubStr( cLine, --nFirstSpace, 1 ) == " " ) .AND. nFirstSpace > 1
        ENDDO

        // If there is a space before beginning of line split there
        IF nFirstSpace > 1
          cSplittedLine:=Left( cLine, nFirstSpace )
        ELSE
          // else split at current cursor position
          cSplittedLine:=Left( cLine, ::nCol - 1 )
        ENDIF

        // changed by JG: wrapping line inserts CR
        // ::InsertLine( cSplittedLine, .T., nStartRow++ )
        ::InsertLine( cSplittedLine, .F., nStartRow++ )

      ELSE
        // remainder of line
        cSplittedLine:=cLine
        ::InsertLine( cSplittedLine, .F., nStartRow++ )
      ENDIF

      cLine:=Right( cLine, Len( cLine ) - Len( cSplittedLine ) )
    ENDDO

    IF lMoveToNextLine
      ::MoveCursor( K_DOWN )
      ::MoveCursor( K_HOME )
      ::MoveCursor( K_CTRL_RIGHT )
      IF nPosInWord > 0
        // from 0 since I have to take into account previous K_CTRL_RIGHT which moves me past end of word
        FOR nI:=0 TO nPosInWord
          ::MoveCursor( K_LEFT )
        NEXT
      ELSE
        IF Set( _SET_INSERT )
          ::MoveCursor( K_LEFT )
        ENDIF
      ENDIF
    ELSE
      // ::setpos( nORow, nOCol )
    ENDIF
    ::display()
  ENDIF

RETURN Self


/*----------------------------------------------------------------------*/

METHOD xDo( nStatus )
LOCAL nOldRow:=::Row()
LOCAL nOldCol:=::Col()
LOCAL nOldCur:=SetCursor()
LOCAL xResult:=Do( ::xUserFunction, nStatus, ::nRow, ::nCol - 1 , ::lEditAllow )

  hb_default( @xResult, ME_DEFAULT )

  // ::setpos( nOldRow, nOldCol )
  SetCursor( nOldCur )
  // SetCursor( iif( Set( _SET_INSERT ), SC_INSERT, SC_NORMAL ) )

  do case
  case xResult == MEMO_EDIT_START
    ::lEditAllow:=.t.
    ::SetColor( COLGET )
    ::display()
    SetKey( K_ESC , {|| HB_KeyPut(EDIT_QUIT) } )

  case xResult == MEMO_EDIT_STOP
    ::lEditAllow:=.f.
    ::SetColor( COLNOR )
    ::display()

  case xResult == MEMO_EXIT_NO_ESC
    // exits memoedit and lastkey may differ from K_ESC
    xResult:=K_ESC

  otherwise
    // nop
  endcase

RETURN xResult

  // This in an empty method which can be used by classes subclassing HBEditor to be able
// to handle particular keys.
METHOD KeyboardHook( nKey )
  // LOCAL merkGrepSuche, cString , pos , rows
  // LOCAL GetList:={}
  // LOCAL aktColor:=setcolor()

  do case
  case nKey == EDIT_QUIT
    ::lEditAllow:=.f.
    ::SetColor( COLNOR )
    ::display()
    SetKey( K_ESC , nil ) // back to default ESC is quit

    // case nKey == K_F7 // search
    // SetColor( COLNOR )
    // Message()
    // merkGrepSuche:=if(grepSuche==nil,space(20),left(grepSuche+space(20),20))
    // @ maxrow(),20 say "Suche nach:" get merkGrepSuche picture "@K"
    // qqout("  F8 = weitersuchen")

    // read
    // // read now - with exit on resize events
    // // ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)

    // Message()
    // SetColor( aktColor )

    // if ! ABBRUCH
    // cString:=::GetText()
    // pos:=at(upper(trim(merkGrepSuche)) , upper(cString))
    // if pos == 0
    // Error(merkGrepSuche+" nicht gefunden.",.t.)
    // else
    // rows:=HB_ATokens( substr(cString,1,pos-1) , MY_CR+MY_LF )

    // Message()

    // // FIXME: now go to the position
    // ::nNumRows:=len(rows)
    // // ::nCol:=len(rows[len(rows)]) - ::nLeft + 1 + ::nFirstCol - 1
    // // ::SetPos( mrow() , mCol() )
    // ::display()

    // endif
    // endif
    // return .t.

  case nKey == K_INS .and. ;
    ! (hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL ) )
    // toggle insert, for some reason need to do it manually
    Set( _SET_INSERT , ! Set( _SET_INSERT ) )

  endcase

RETURN ::super:KeyboardHook( nKey )

// Redraws a screenfull of text
METHOD display()

LOCAL i
LOCAL nOCol:=::Col()
LOCAL nORow:=::Row()

  DispBegin()

  FOR i:=0 TO Min( ::nNumRows - 1, len(::GetText) - 1 )
    ::My_DispOutAt( ::nTop +;
      i, ::nLeft,;
      PadR( SubStr( ::GetLine( ::nFirstRow + i ), ::nFirstCol, ::nNumCols ), ::nNumCols, " " ),;
      ::LineColor( ::nFirstRow + i ) )
  NEXT

  // Clear rest of editor window (needed when deleting lines of text)
  IF len(::GetText) < ::nNumRows
    hb_Scroll( ::nTop + len(::GetText), ::nLeft, ::nBottom, ::nRight,,, ::cColorSpec )
  ENDIF

  // ::setpos( nORow, nOCol )

  DispEnd()

RETURN Self

// Redraws current screen line
METHOD RefreshLine()

  ::My_DispOutAt( ::Row(), ::nLeft, PadR( SubStr( ::GetLine( ::nRow ), ::nFirstCol, ::nNumCols ),;
    ::nNumCols, " " ), ::LineColor( ::nRow ) )

RETURN Self

// Refreshes only one screen column of text (for Left() and Right() movements)
METHOD RefreshColumn()

LOCAL i

  DispBegin()

  FOR i:=0 TO Min( ::nNumRows - 1, len(::GetText) - 1 )
    ::My_DispOutAt( ::nTop +;
      i, ::Col(), SubStr( ::GetLine( ::nFirstRow + i ), ::nCol, 1 ),;
      ::LineColor( ::nFirstRow + i ) )
  NEXT

  DispEnd()

RETURN Self

// displays line with higlightening if any
METHOD My_DispOutAt(row,col,text, color) // Draw a line with higlightening
  // nicht im edit Mode
  if ::lEditAllow
    hb_DispOutAt( row,col,text, color )
  else
    @ row,col clear to row,::nright
    colorSay( row, col, text)
  endif
RETURN self

/******************   Functions ***********************************************/

/* MemoEdit user function
  *
  * supporting special keys
  */
FUNCTION MemoUserFunction( nMode, nRow, nCol, lEditMode )
LOCAL nKey:=LastKey()
LOCAL nRet:=ME_DEFAULT

  if nMode <> ME_INIT

    DO CASE
    CASE nKey == K_ESC
      nRet:=K_CTRL_W // Save with ESC

    CASE nKey == K_F1 // Hilfe-Text
      nRet:=ME_IGNORE
      if lEditMode
        Info( procname() , procline() , "" )
        // SetKey( K_ESC , {|| HB_KeyPut(EDIT_QUIT) } )
        SetLastKey(0)
      endif

      // special backspace handling
    CASE nKey == K_BS
      if (nCol == 0)
        if nRow > 1
          KeyBoard ( chr( K_UP ) + chr( K_END ) + chr( K_DEL ) )
        endif
        nRet:=ME_IGNORE
      endif

      // CASE nKey == K_CTRL_V
      // Set( _SET_INSERT, .t. )
      // nRet:=ME_PASTE

      // CASE nKey == K_CTRL_B
      // nRet:=ME_TOGGLEWRAP
      // altd()

    ENDCASE

  endif

RETURN nRet
/** eof */



/** call this function instead of memoEdit() to use this customized memo object */
FUNCTION MyMemoEdit( ;
  cString,;
  nTop,;
  nLeft,;
  nBottom,;
  nRight,;
  lEditMode,;
  xUserFunction,;
  nLineLength,;
  nTabSize,;
  nTextBuffRow,;
  nTextBuffColumn,;
  nWindowRow,;
  nWindowColumn )

LOCAL oEd

LOCAL nOldCursor

  hb_default( @nTop , 0 )
  hb_default( @nLeft , 0 )
  hb_default( @nBottom , MaxRow() )
  hb_default( @nRight , MaxCol() )
  hb_default( @lEditMode , .T. )
  hb_default( @nLineLength , nRight - nLeft + 1 )
  hb_default( @nTabSize , 4 )
  hb_default( @nTextBuffRow , 1 )
  hb_default( @nTextBuffColumn , 0 )
  hb_default( @nWindowRow , 0 )
  hb_default( @nWindowColumn , nTextBuffColumn )
  hb_default( @cString , "" )
  hb_default( @xUserFunction , "MemoUserFunction" )

  // if lEditMode // use editor above with special key handling

  // Original MemoEdit() converts Tabs into spaces oEd:=MyMemoEditor():New( StrTran( cString, Chr( 9 ), Space( 1 ) ), nTop, nLeft, nBottom, nRight, lEditMode, nLineLength, nTabSize, nTextBuffRow, nTextBuffColumn, nWindowRow, nWindowColumn )
  oEd:MemoInit( xUserFunction )
  oEd:display()

  IF ! HB_ISLOGICAL( xUserFunction ) .OR. xUserFunction
    nOldCursor:=SetCursor( iif( Set( _SET_INSERT ), SC_INSERT, SC_NORMAL ) )
    oEd:Edit()
    // always return string
    // IF oEd:Changed() .AND. oEd:Saved()
    cString:=oEd:GetText()
    // ENDIF
    SetCursor( nOldCursor )
  ENDIF

  // else
  // // zum anzeigen Standard MemoEditor verwenden
  // MemoEdit(
  // cString,;
  // nTop,;
  // nLeft,;
  // nBottom,;
  // nRight,;
  // lEditMode,;
  // xUserFunction,;
  // nLineLength,;
  // nTabSize,;
  // nTextBuffRow,;
  // nTextBuffColumn,;
  // nWindowRow,;
  // nWindowColumn )
  // endif

RETURN cString


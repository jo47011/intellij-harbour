/*
 * Harbour Project source code:
 *   CT3 GET function:
 *
 * GETSECRET()
 *
 * Copyright 2007 Przemyslaw Czerpak <druzus / at / priv.onet.pl>
 *
 * www - http://harbour-project.org
 *
 * copie from ...\harbour-src\contrib\hbct\getsecret.prg
 * we need it locally as we still use an old copy of the getsys.prg system
 *
 * FIXME: maybe move changes to getsys.prg to separate prg and use the standard getsys.prg
 *        then this file is obsolete as well
 *
 */

#include "common.ch"
#include "getexit.ch"

FUNCTION GETSECRET( cVar, nRow, nCol, lSay, xPrompt )
LOCAL nCursorRow:=ROW()
LOCAL nCursorCol:=COL()
LOCAL GetList:={}
LOCAL _cGetSecret:=cVar
LOCAL lHide:=.T.

  IF ! ISNUMBER( nRow )
    nRow:=ROW()
  ENDIF
  IF ! ISNUMBER( nCol )
    nCol:=COL()
  ENDIF
  IF ! ISLOGICAL( lSay )
    lSay:=.F.
  ENDIF

  SETPOS( nRow, nCol )
  IF xPrompt != Nil
    DEVOUT( xPrompt )
    nRow:=ROW()
    nCol:=COL() + 1
  ENDIF

  SETPOS( nRow, nCol )
  AADD( GetList, _GET_( _CGETSECRET, "_CGETSECRET",,, ) )
  ATAIL( GetList ):reader:={ |oGet, oGetList| _SECRET( @_cGetSecret, @lHide, oGet, oGetList ) }
  ATAIL( GetList ):block:={ |xNew| _VALUE( @_cGetSecret, lHide, xNew ) }
  READ

  IF lSay
    SETPOS( nRow, nCol )
    DEVOUT( _HIDE( _cGetSecret ) )
  ENDIF

  SETPOS( nCursorRow, nCursorCol )

RETURN _cGetSecret

STATIC FUNCTION _HIDE( cVar )
RETURN RANGEREPL( ASC( " " ) + 1, 255, cVar, "*" )

STATIC FUNCTION _VALUE( cVar, lHide, xNew )
  IF lHide
    RETURN _HIDE( cVar )
  ELSEIF xNew != NIL
    cVar:=PADR( xNew, LEN( cVar ) )
  ENDIF
RETURN cVar

STATIC PROCEDURE _SECRET( _cGetSecret, lHide, oGet, oGetList )
LOCAL nKey, nLen, bKeyBlock

  IF oGetList == NIL
    oGetList:=__GetListActive()
  ENDIF

  IF GetPreValidate( oGet )

    nLen:=LEN( _cGetSecret )
    oGet:SetFocus()

    DO WHILE oGet:exitState == GE_NOEXIT
      IF oGet:typeOut
        oGet:exitState:=GE_ENTER
      ENDIF

      DO WHILE oGet:exitState == GE_NOEXIT
        nKey:=INKEY( 0 )
        IF ( bKeyBlock:=SETKEY( nKey ) ) != NIL
          // ignore lHide
          lHide:=lHide
          // Hotkeys disabled: jojo 17.9.2012
          // lHide:=.F.
          // EVAL( bKeyBlock, oGetList:cReadProcName, 
          // oGetList:nReadProcLine, oGetList:ReadVar() )
          // lHide:=.T.
          LOOP
        ELSEIF nKey >= 32 .AND. nKey <= 255
          IF SET( _SET_INSERT )
            _cGetSecret:=STUFF( LEFT( _cGetSecret, nLen - 1), oGet:pos, 0, CHR( nKey ) )
          ELSE
            _cGetSecret:=STUFF( _cGetSecret, oGet:pos, 1, CHR( nKey ) )
          ENDIF
          nKey:=ASC( "*" )
        ENDIF
        GetApplyKey( oGet, nKey )
      ENDDO

      IF !GetPostValidate( oGet )
        oGet:exitState:=GE_NOEXIT
      ENDIF
    ENDDO
    oGet:KillFocus()
  ENDIF

RETURN


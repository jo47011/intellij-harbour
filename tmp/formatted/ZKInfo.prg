/************************************************************************************
 * Class ZkInfo
 *
 * liefert alle Details die zum Ausf�llen der Zahlungskond. notwending sind
 *
 ************************************************************************************/

#include "Miki.ch"
#include "hbclass.ch"

CLASS ZkInfo

DATA ZkNr
DATA Betrag
DATA Datum
DATA SktoDatum
DATA SktoProzent
DATA BetragAbzglSkto

METHOD new( zkNr )
METHOD getText()
METHOD ersetzePlatzhalter( text )
METHOD getPlatzhalter(text)

ENDCLASS

/*----------------------------------------------------------------------*/

/** erzeugt neue PDF Info Objekt
*
* Parameters: ZkNr: Zahlungskond.
*             Gersamt: Betrag
*/
METHOD new( zkNr , gesamt ) CLASS ZkInfo
  ::zkNr:=ZkNr
  ZAHLKOND->(dbseek( ::ZkNr ))

  ::Betrag:=gesamt
  ::SktoProzent:=ZAHLKOND->Skto
  ::BetragAbzglSkto:=round( ::Betrag * ( 100 - ::SktoProzent ) / 100 , 2 )
RETURN self

/*----------------------------------------------------------------------*/

METHOD getText()
LOCAL result:={}

  ZAHLKOND->(dbseek( ::ZkNr ))

  if empty( ZAHLKOND->ReText )
    aadd( result, getTransField("ZAHLKOND->Text"))
    if ! empty( ZAHLKOND->Text2 )
      aadd( result, getTransField("ZAHLKOND->Text2"))
    endif
  else

    aadd( result, ::ersetzePlatzhalter( getTransField("ZAHLKOND->ReText") ))
    if ! empty( ZAHLKOND->ReText2 )
      aadd( result, ::ersetzePlatzhalter( getTransField("ZAHLKOND->ReText2") ))
    endif

  endif

return result
/** eof */

/*----------------------------------------------------------------------*/

METHOD ersetzePlatzhalter(text)
LOCAL result:=""
LOCAL pos

  do while (pos:=at( "|" , Text )) > 0
    result += left( text , pos-1 )
    text:=substr( text , pos+1 )

    // find 2. seperator |
    pos:=at( "|" , Text )
    if pos == 0
      Error("ACHTUNG: unbekannter Platzhalter in Zahlungskondition: " + text )
    endif

    result += ::getPlatzhalter( left( Text, pos -1 ) )
    text:=substr( text , pos+1 )

  enddo
  result += text

return trim(result)
/** eof */

/*----------------------------------------------------------------------*/

METHOD getPlatzhalter(text)
LOCAL result

  do case
  case text = "BETRAG"
    result:=::Betrag
  case text = "DATUM"
    result:=::Datum
  case text = "SKTO_DAT"
    result:=::SktoDatum
  case text = "SKTO_PROZ"
    result:=::SktoProzent
  case text = "SKTO_BETR"
    result:=::BetragAbzglSkto
  otherwise
    Error("ACHTUNG: unbekannter Platzhalter in Zahlungskondition: " + text )
    result:=text
  endcase

return toString( result )
/** eof */



/************************************************************************************/
/* end of Class ZkInfo
/************************************************************************************/


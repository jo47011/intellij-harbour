/**
 * Class for EU INTRASTAT Export
 *
 * siehe
 *   - instat_dsb__intra_.pdf  - XML Format Beschreibung
 *   - svz_datei_intra.pdf     - Schl�sselverzeichnis
 *   - beispiel.xml
 *
 *  techn. Hotline:
 *
 *
 */

#include "mystd.ch"
#include "error.ch"
#include "hbmxml.ch"
#include "hbclass.ch"

// Info: we set real number as text, as we don't now how te set the number of digits :(

// A-Z,a-z,0-9 and the below characters are allowed (see Function checkIntraStatCharacters())
#define ALLOWED_SPECIAL_CHARACTERS "':?,- (+.)/=" // 20180102: added =

// relative path where "deleted" files are moved
#define DELETED_PATH "old"

#define INTRASTAT_DATE_FORMAT "yyyymmdd"
#define INTRASTAT_TIME_FORMAT "hhmm"

#define INTRASTAT_DATE_FORMAT_INFILE "yyyy-mm-dd"
#define INTRASTAT_TIME_FORMAT_INFILE "hh:mm:ss"

// FIXME: Miki stuff sollte nat�rlich ins Miki-Paket
#define KENNUNG_BAWUE "08"
#define MIKI_USTVA "3700303010"
#define UNTERSCHEIDUNGS_NUMMER "000"
#define URSPRUNGSLAND "DE"

// prefix for file name, sp�ter MIKI "Materialnummer"
// WICHTIG: testIndicator unten raus-nehmen wenn Materialnummer bekannt
#define AGREEMENT_ID "XGC40"

CLASS INTRASTAT

DATA tree READONLY // top level tree node
DATA partyID READONLY
DATA fileName // HIDDEN
DATA envelope // HIDDEN
DATA counter INIT 1

METHOD new(id,monat,jahr)
METHOD getEnvelopeId(monat,jahr)
METHOD dump(fileName)
METHOD addDeclaration(Declaration)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(monat,jahr)
LOCAL doc
LOCAL group, subgroup, node
LOCAL dateFormat:=Set( _SET_DATEFORMAT )
LOCAL timeFormat:=Set( _SET_TIMEFORMAT )

  SET DATE FORMAT TO INTRASTAT_DATE_FORMAT_INFILE
  SET TIME FORMAT TO INTRASTAT_TIME_FORMAT_INFILE

  // PSIID and Miki-PartyId
  ::partyID:=KENNUNG_BAWUE + MIKI_USTVA + "0" + UNTERSCHEIDUNGS_NUMMER

  // set XML defaults
  mxmlSetCustomHandlers( @load_c(), @save_c() )

  // begin document & header --------------------------
  ::tree:=mxmlNewXML()
  // FIXME: muss sp�ter im File ersetzt werden: "utf-8" -> "iso-8859-1" )
  doc:=mxmlNewElement( ::tree, "INSTAT" )

  ::envelope:=mxmlNewElement( doc, "Envelope" )

  node:=mxmlNewElement( ::envelope, "envelopeId" )
  mxmlNewText( node, 0, ::getEnvelopeId( monat , jahr ) )

  group:=mxmlNewElement( ::envelope, "DateTime" )
  node:=mxmlNewElement( group, "date" )
  mxmlNewText( node, 0, dtoc( Date() ) )
  node:=mxmlNewElement( group, "time" )
  mxmlNewText( node, 0, time() )

  // Adresse stat. Bundesamt
  group:=mxmlNewElement( ::envelope, "Party" )
  mxmlElementSetAttr( group, "partyType", "CC" )
  mxmlElementSetAttr( group, "partyRole", "receiver" )
  node:=mxmlNewElement( group, "partyId" )
  mxmlNewText( node, 0, "00" )
  node:=mxmlNewElement( group, "partyName" )
  mxmlNewText( node, 0, "Statistisches Bundesamt" )
  subgroup:=mxmlNewElement( group, "Address" )
  node:=mxmlNewElement( subgroup, "streetName" )
  mxmlNewText( node, 0, "Gustav-Stresemann-Ring 11" )
  node:=mxmlNewElement( subgroup, "postalCode" )
  mxmlNewText( node, 0, "65189" )
  node:=mxmlNewElement( subgroup, "cityName" )
  mxmlNewText( node, 0, "Wiesbaden" )

  // Adresse Miki-Plastik
  group:=mxmlNewElement( ::envelope, "Party" )
  mxmlElementSetAttr( group, "partyType", "PSI" )
  mxmlElementSetAttr( group, "partyRole", "sender" )
  node:=mxmlNewElement( group, "partyId" )
  mxmlNewText( node, 0, ::partyId )
  node:=mxmlNewElement( group, "partyName" )
  mxmlNewText( node, 0, "Miki-Plastik GmbH" )
  node:=mxmlNewElement( group, "interchangeAgreementId" )
  mxmlNewText( node, 0, AGREEMENT_ID )
  subgroup:=mxmlNewElement( group, "Address" )
  node:=mxmlNewElement( subgroup, "streetName" )
  mxmlNewText( node, 0, "Marconistr." )
  node:=mxmlNewElement( subgroup, "streetNumber" )
  mxmlNewText( node, 0, "16-22" )
  node:=mxmlNewElement( subgroup, "postalCode" )
  mxmlNewText( node, 0, "68309" )
  node:=mxmlNewElement( subgroup, "cityName" )
  mxmlNewText( node, 0, "Mannheim" )
  node:=mxmlNewElement( subgroup, "countryName" )
  mxmlNewText( node, 0, "Deutschland" )
  node:=mxmlNewElement( subgroup, "phoneNumber" )
  mxmlNewText( node, 0, "0621 737061" )
  node:=mxmlNewElement( subgroup, "faxNumber" )
  mxmlNewText( node, 0, "0621 733488" )
  node:=mxmlNewElement( subgroup, "e-mail" )
  mxmlNewText( node, 0, "info@miki-plastik.de" )

  // FIXME: to be removed after test
  // node:=mxmlNewElement( ::envelope,"testIndicator" )
  // mxmlNewText( node, 0, "true" )


  // end of Header


  // reset date type
  SET DATE FORMAT TO (dateFormat)
  SET TIME FORMAT TO (timeFormat)

RETURN self
/*----------------------------------------------------------------------*/


  /* Returns the file name for intrastat transfer

  "XGTEST" + "-" + refbzr + "-" + datum + "-" + uhrzeit + ".xml"

  wobei

    refbzr der Referenzberichtszeitraum im Format jjjjmm,
    datum das Datum im Format jjjjmmtt und
    uhrzeit die Uhrzeit im Formt hhmm ist.

  Beispiel:

    XGTEST-201109-20110915-1113.xml
  */
METHOD getEnvelopeId(monat,jahr)
LOCAL dateFormat:=Set( _SET_DATEFORMAT )
LOCAL timeFormat:=Set( _SET_TIMEFORMAT )
LOCAL dateTime , result

  SET DATE FORMAT TO INTRASTAT_DATE_FORMAT
  SET TIME FORMAT TO INTRASTAT_TIME_FORMAT

  dateTime:=strTran( TtoC( DateTime() ) , " " , "-" )
  result:=AGREEMENT_ID + "-" +getJahrMonatString(Monat,jahr)+"-"+dateTime

  // reset date type
  SET DATE FORMAT TO (dateFormat)
  SET TIME FORMAT TO (timeFormat)

return result
/** eom */

/*----------------------------------------------------------------------*/
METHOD dump(dumpName)

  if dumpName<>NIL
    ::fileName:=dumpName
  endif

  if ::fileName<>NIL

    // save the file
    mxmlSaveFile( ::tree, ::filename, @whitespace_cb() )

    // now adjust encoding, ouch! :(
    replaceCodepageInFile( ::fileName )

  endif

RETURN self
/*----------------------------------------------------------------------*/

METHOD addDeclaration(declaration)
LOCAL group, item, subgroup, node

  // declaration header
  group:=mxmlNewElement( ::envelope, "Declaration" )
  // node:=mxmlNewElement( group, "declarationId" )
  // mxmlNewText( node, 0, declaration:getID() )
  node:=mxmlNewElement( group, "referencePeriod" )
  mxmlNewText( node, 0, getJahrMinusMonatString( declaration:getMonat(),declaration:getJahr() ) )
  node:=mxmlNewElement( group, "PSIId" )
  mxmlNewText( node, 0, ::partyId )
  subgroup:=mxmlNewElement( group, "Function" )
  node:=mxmlNewElement( subgroup, "functionCode" )
  mxmlNewText( node, 0, "O" )
  node:=mxmlNewElement( group, "flowCode" )
  mxmlNewText( node, 0, "D" ) // Versand

  // item
  item:=mxmlNewElement( group, "Item" )
  node:=mxmlNewElement( item, "itemNumber" )
  mxmlNewText( node, 0, alltrim(str(::counter++)) )

  subgroup:=mxmlNewElement( item, "CN8" )
  node:=mxmlNewElement( subgroup, "CN8Code" )
  mxmlNewText( node, 0, no_blanks( declaration:getWarenNummer() ) )

  node:=mxmlNewElement( item, "goodsDescription" )
  mxmlNewText( node, 0, declaration:getText() )
  node:=mxmlNewElement( item, "MSConsDestCode" )
  mxmlNewText( node, 0, declaration:getLand() )
  node:=mxmlNewElement( item, "countryOfOriginCode" )
  mxmlNewText( node, 0, URSPRUNGSLAND )
  node:=mxmlNewElement( item, "netMass" )
  mxmlNewText( node, 0, alltrim( str( declaration:getGewicht() )) )
  node:=mxmlNewElement( item, "invoicedAmount" )
  mxmlNewText( node, 0, alltrim( str( declaration:getSumme() )) )
  node:=mxmlNewElement( item, "partnerId" )
  mxmlNewText( node, 0, declaration:getUStId() )

  // Art des Gesch�ftes, immer 11
  // - Endg�ltiger Kauf/Verkauf (b) 11
  subgroup:=mxmlNewElement( item, "NatureOfTransaction" )
  node:=mxmlNewElement( subgroup, "natureOfTransactionACode" )
  mxmlNewText( node, 0, "1" )
  node:=mxmlNewElement( subgroup, "natureOfTransactionBCode" )
  mxmlNewText( node, 0, "1" )

  node:=mxmlNewElement( item, "modeOfTransportCode" )
  mxmlNewText( node, 0, "3" ) // FIXME: bisher immer Stra�enverkehr
  node:=mxmlNewElement( item, "regionCode" )
  mxmlNewText( node, 0, "08" ) // BaW�



RETURN self
/*----------------------------------------------------------------------*/

/** eoc - end of class ****************************************************************/

/** Class Declaration (Record)********************************************** */
CLASS Declaration
DATA ArtNr INIT "" HIDDEN
DATA Monat INIT 1 HIDDEN
DATA Jahr INIT 1900 HIDDEN
DATA WarenNummer INIT "" HIDDEN
DATA UStId INIT "QV999999999999" HIDDEN
DATA Text INIT "" HIDDEN
DATA Land INIT "" HIDDEN
DATA Gewicht INIT 0 HIDDEN
DATA Summe INIT 0 HIDDEN

// getters & setters
METHOD setArtNr(s)
METHOD getArtNr()

METHOD setMonat(s)
METHOD getMonat()

METHOD setJahr(s)
METHOD getJahr()

METHOD setWarenNummer(s)
METHOD getWarenNummer()

METHOD setUStId(s)
METHOD getUStId()

METHOD setText(s)
METHOD getText()

METHOD setLand(s)
METHOD getLand()

METHOD setGewicht(s)
METHOD getGewicht()

METHOD setSumme(s)
METHOD getSumme()

METHOD checkUStId(s)
METHOD checkIntraStatCharacters(s,quiet)

ENDCLASS

/*----------------------------------------------------------------------*/

// getters & setters
METHOD setArtNr(s)
  ::ArtNr:=s
RETURN ::ArtNr

METHOD getArtNr()
RETURN ::ArtNr

METHOD setMonat(s)
  if s > 0 .and. s <= 12
    ::Monat:=s
  endif
RETURN ::Monat

METHOD getMonat()
RETURN ::Monat

METHOD setJahr(s)
  if s > 1990
    ::Jahr:=s
  endif
RETURN ::Jahr

METHOD getJahr()
RETURN ::Jahr

METHOD setWarenNummer(s)
  ::WarenNummer:=::checkIntraStatCharacters(s)
RETURN ::WarenNummer

METHOD getWarenNummer()
RETURN ::WarenNummer

METHOD setUStId(s)
  ::UStId:=::checkUStId(s)
RETURN ::UStId

METHOD getUStId()
RETURN ::UStId

METHOD setText(s)
  ::Text:=::checkIntraStatCharacters(s)
RETURN ::text

METHOD getText()
RETURN ::text

METHOD setLand(s)
  ::Land:=::checkIntraStatCharacters(s)
RETURN ::Land

METHOD getLand()
RETURN ::Land

METHOD setGewicht(s)
  ::Gewicht:=s
RETURN ::Gewicht

METHOD getGewicht()
RETURN ::Gewicht

METHOD setSumme(s)
  if s > 0
    ::Summe:=s
  endif
RETURN ::Summe

METHOD getSumme()
RETURN ::Summe

/** Allow for XX999999999999 format only or XX */
METHOD checkUStId(s)
LOCAL land:=substr(s,1,2)

  if ! syntaxIdentNr(s,Land,.f.)
    TroubleEmail( "IntraStat: Artikel-Nr: " + ::getArtNr() + "|"+;
      "           Waren-Nr  : " + ::getWarenNummer() + "||"+;
      "Ung"Ung�ltige UStID : "+s )
  endif

return padr(trim(s),2+12,"9")
/** eom */

/** replaces all illegal characters with space */
METHOD checkIntraStatCharacters(s,quiet)
LOCAL result:="",i,tempVal

  // if not otherwise specified we bail out on wrong characters
  default quiet:=.f.

  for i:=1 to len(s)
    tempVal:=substr(s,i,1)
    if isAlpha(tempVal) .or. isDigit(tempVal) .or. tempVal $ ALLOWED_SPECIAL_CHARACTERS
      result+= tempVal
    else
      if quiet
        result+=" " // we use blank instead of wrong characters
      else
        result+=" " // we use blank instead of wrong characters
        // ERROR
        // BREAK myErrorNew("INTRASTAT",EG_DATATYPE,,"checkIntraStatCharacters","Ung�ltiges Zeichen: "+tempVal+"| in "+s)
        TroubleEmail( "IntraStat: Artikel-Nr: " + ::getArtNr() + "|"+;
          "           Waren-Nr  : " + ::getWarenNummer() + "||"+;
          "Ung�ltiges Zeichen   : "+tempVal+;
          "|"+s )

      endif
    endif
  next
return result
/** eom */

/** eoc - end of class ****************************************************************/

/** Some utility functions ************************************************************/

static function getJahrMonatString(Monat,Jahr)
return str(jahr,4)+right("00"+alltrim(str(monat,2)),2)
/** eof */

static function getJahrMinusMonatString(Monat,Jahr)
return str(jahr,4)+"-"+right("00"+alltrim(str(monat,2)),2)
/** eof */

/** creates a new error object */
  // static FUNCTION myErrorNew(cSubSystem,nGenCode,nSubCode,cOperation,cDescription,cFileName)
  // LOCAL oResult:=errorNew()
  // oResult:SubSystem:=cSubSystem
  // oResult:genCode:=nGenCode
  // if nSubCode<>NIL
  // oResult:SubCode:=nSubCode
  // endif
  // oResult:Operation:=coperation
  // oResult:Description:=cDescription
  // oResult:FileName:=cFileName

  // oResult:CanDefault:=.f.
  // oResult:CanSubstitute:=.f.
  // oResult:CanRetry:=.f.
  // oResult:Severity:=ES_ERROR
  // return oResult
/** eof */

  /**
  * FIXME: change encoding in header is very dirty, shall we switch to another xml lib?
  * but IntraStat only accepts encoding="ISO-8859-1"
  * and minixml only supports encoding="UTF-8"
  *
  * hiernach: http://de.wikipedia.org/wiki/ISO_8859-1#ISO_8859-1_vs._ISO_8859-15_vs._Windows-1252_vs._Unicode
  *
  * kennt utf8 alle Zeichen von iso, sollte also kein Problem sein
  */
PROCEDURE replaceCodepageInFile(fileName)
LOCAL xml:=memoRead( fileName )
  xml:=strTran( xml , "utf-8" , "iso-8859-1" )
  if ! MemoWrit(fileName,xml)
    Error(ACHTUNG+" Encoding konnt nicht angepasst werden.|"+fileName,.t.)
  endif
  deleteCTRLZ(fileName)
return
/** eop */

  // PROCEDURE replaceCodepageInFile(fileName)
  // LOCAL cBuffer
  // LOCAL orgHandle, neuHandle
  // LOCAL TempFile:=TEMP+BACKSLASH+"IntraStat"+getUser():getTempCounter()+".xml"

  // neuHandle:=FCreate( TempFile, FC_NORMAL )
  // FWrite( nHandle , "xHarbour" + Chr(0) + "compiler" )
  // FClose( nHandle )

  // orgHandle:=FOpen( fileName , FO_READ )

  // ? cBuffer:=FReadStr( nHandle, 20 ) // result: xHarbour
  // ? Len( cBuffer ) // result: 8

  // FSeek(nHandle, 0, FS_SET ) // go to begin of file

  // cBuffer:=Space( 20 )
  // ? FRead( nHandle, @cBuffer, 20 ) // result: 17
  // ? Trim( cBuffer ) // result: xHarbour compiler
  // ? Asc( cBuffer[9] ) // result: 0

  // FClose( nHandle )
  // FErase( "Testfile.txt" )
  // RETURN


/***** Some XML specific stuff (copied from hbmxml\tests\custom.prg) ****************************/

/*
 * 'whitespace_cb()' - Let the mxmlSaveFile() function know when to insert
 *                     newlines and tabs...
 */

static FUNCTION whitespace_cb( hNode, nWhere )   /* O - Whitespace string or nil */
  /* I - Element node */
  /* I - Open or close tag? */

  // LOCAL hParent                          /* Parent node */
  // LOCAL nLevel                           /* Indentation level */
  LOCAL cName                            /* Name of element */

  /*
  * We can conditionally break to a new line before or after any element.
  * These are just common HTML elements...
  */

  cName:=Lower( mxmlGetElement( hNode ) )

  // return EOL or NULL depending on nodes
  IF nWhere == MXML_WS_AFTER_OPEN
    IF cName$"instat/envelope/datetime/party/address/declaration/function/item/cn8/natureoftransa"+;
      "ction" .and. ! cName$"date/time"
      RETURN hb_eol()
    endif
  ELSEIF nWhere == MXML_WS_BEFORE_OPEN
    IF cName$"instat"
      RETURN hb_eol()
    endif
  ELSEIF nWhere == MXML_WS_AFTER_CLOSE
    RETURN hb_eol()
  ENDIF

  /*
  * Return NULL for no added whitespace...
  */

RETURN nil
/** eof */


  #xtranslate _ENCODE( <xData> ) => ( hb_base64encode( hb_serialize( mxmlGetCustom( <xData> ) ) ) )
static FUNCTION load_c( node, cString )

  mxmlSetCustom( node, hb_deserialize( hb_base64decode( cString ) ) )

RETURN 0  /* 0 on success or non-zero on error */

static FUNCTION save_c( node )

RETURN _ENCODE( node ) /* string on success or NIL on error */


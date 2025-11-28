/** Datenexport im DATEV Format
 *
 *  Stand: Schnittstellen-Entwicklungsleitfaden f�r das DATEV-Format V. 1.4
 */

#include "mystd.ch"

#include "hbclass.ch"
// #include "hboo.ch"

// Header Daten
#define DATEV_FORMAT "EXTF"
#define DATEV_VERSION 141
#define DATEV_KAETGORIE 21 // Buchungsstapel
#define DATEV_FORM_NAME "Buchungsstapel"
#define DATEV_FORM_VER 1
#define DATEV_HERKUNFT "SV" // wird beim Import von Datev eh durch SV ersetzt
#define DATEV_BERATER val(getProperty("Datev.berater","0"))
#define DATEV_MANDANT val(getProperty("Datev.mandant","0"))
#define DATEV_SACHKTO_LEN 4
#define DATEV_BEZEICHN "Rechnungen" // M�rz 2011
#define DATEV_BUCH_TYP 1 // Finanzbuchhaltung

// Info: Ergebnis csv einlesen in Datev
// -> Bichf�hrung, verarbeitende T�tigkeiten, Stapelverarbeitung, Datev Format einlesen

#define BUCH_HEADER "Umsatz (ohne Soll/Haben-Kz);Soll/Haben-Kennzeichen;WKZ Umsatz;Kurs;Basis-Ums"+;
  "atz;WKZ Basis-Umsatz;Konto;Gegenkonto (ohne BU-Schl�ssel);BU-Schl�ssel;Belegdatum;Belegfeld 1;Belegfeld 2;Skonto;Buchungstext;Postensperre;Diverse Adressnummer;Gesch�ftspartnerbank;Sachverhalt;Zinssperre;Beleglink;Beleginfo - Art 1;Beleginfo - Inhalt 1;Beleginfo - Art 2;Beleginfo - Inhalt 2;Beleginfo - Art 3;Beleginfo - Inhalt 3;Beleginfo - Art 4;Beleginfo - Inhalt 4;Beleginfo - Art 5;Beleginfo - Inhalt 5;Beleginfo - Art 6;Beleginfo - Inhalt 6;Beleginfo - Art 7;Beleginfo - Inhalt 7;Beleginfo - Art 8;Beleginfo - Inhalt 8;KOST1 - Kostenstelle;KOST2 - Kostenstelle;Kost-Menge;EU-Land u. UStID;EU-Steuersatz;Abw. Versteuerungsart;Sachverhalt L+L;Funktionserg�nzung L+L;BU 49 Hauptfunktionstyp;BU 49 Hauptfunktionsnummer;BU 49 Funktionserg�nzung;Zusatzinformation - Art 1;Zusatzinformation- Inhalt 1;Zusatzinformation - Art 2;Zusatzinformation- Inhalt 2;Zusatzinformation - Art 3;Zusatzinformation- Inhalt 3;Zusatzinformation - Art 4;Zusatzinformation- Inhalt 4;Zusatzinformation - Art 5;Zusatzinformation- Inhalt 5;Zusatzinformation - Art 6;Zusatzinformation- Inhalt 6;Zusatzinformation - Art 7;Zusatzinformation- Inhalt 7;Zusatzinformation - Art 8;Zusatzinformation- Inhalt 8;Zusatzinformation - Art 9;Zusatzinformation- Inhalt 9;Zusatzinformation - Art 10;Zusatzinformation- Inhalt 10;Zusatzinformation - Art 11;Zusatzinformation- Inhalt 11;Zusatzinformation - Art 12;Zusatzinformation- Inhalt 12;Zusatzinformation - Art 13;Zusatzinformation- Inhalt 13;Zusatzinformation - Art 14;Zusatzinformation- Inhalt 14;Zusatzinformation - Art 15;Zusatzinformation- Inhalt 15;Zusatzinformation - Art 16;Zusatzinformation- Inhalt 16;Zusatzinformation - Art 17;Zusatzinformation- Inhalt 17;Zusatzinformation - Art 18;Zusatzinformation- Inhalt 18;Zusatzinformation - Art 19;Zusatzinformation- Inhalt 19;Zusatzinformation - Art 20;Zusatzinformation- Inhalt 20;St�ck;Gewicht"


// General
#define FILE_NAME DATEV_FORMAT+"_"+DATEV_FORM_NAME+"_"+getDatevFormat(Hb_dateTime())+".csv"
#define SEP_CHAR ";"
#define PIC_NUMBER "@E"
#define QUOTE '"'

// Offen: Zeichen um Textfelder verdoppeln -> Ja
// Offen: Trennzeichen am Datensatzende -> Nein (also CR/LF?)



CLASS DatevExport

DATA records INIT {}
DATA fileName

METHOD new()
METHOD add(oDatevRecord)
METHOD dump(fullFileName)
METHOD getHeader()
METHOD getDefaultFileName()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
  SET CENTURY ON
  SET TIME FORMAT TO "hhmmss"
RETURN self
/** eom */

/*  returns the default DATEV Filename --------------------------------------*/

METHOD getDefaultFileName()
RETURN FILE_NAME
/** eom */

/*  adds a new Datev record to the export list --------------------------------------*/

METHOD add(oDatevRecord)
  aadd(::records,oDatevRecord)
RETURN self
/** eom */

/*-- Returns the current header ----------------------------------------*/
METHOD getHeader()
LOCAL result
  // 1. DATEV-Format-KZ
  result:=getDatevFormat(DATEV_FORMAT)+SEP_CHAR
  // 2. Versionsnummer
  result+= getDatevFormat(DATEV_VERSION)+SEP_CHAR
  // 3. Datenkategorie
  result+= getDatevFormat(DATEV_KAETGORIE)+SEP_CHAR
  // 4. Formatname
  result+= getDatevFormat(DATEV_FORM_NAME)+SEP_CHAR
  // 5. Formatversion
  result+= getDatevFormat(DATEV_FORM_VER)+SEP_CHAR
  // 6. Erzeugt am
  result+= getDatevFormat(hb_dateTime())+SEP_CHAR
  // 7. Importier == leer
  result+= SEP_CHAR
  // 8. Herkunft
  result+= getDatevFormat(DATEV_HERKUNFT)+SEP_CHAR
  // 9. Exportiert von
  result+= getDatevFormat(getUser():id)+SEP_CHAR
  // 10. Importiert von == leer
  result+= SEP_CHAR
  // 11. Berater
  result+= getDatevFormat(DATEV_BERATER)+SEP_CHAR
  // 12. Mandant
  result+= getDatevFormat(DATEV_MANDANT)+SEP_CHAR
  // 13. Wirtschaftsjahr Begin z.B. 20110101
  result+= dtos(boy(getUser():date))+SEP_CHAR
  // 14. Sachkontenl�nge
  result+= getDatevFormat(DATEV_SACHKTO_LEN)+SEP_CHAR
  // 15. Datum von
  result+= dtos(if(len(::records)>0,::records[1]:BelegDatum,))+SEP_CHAR
  // 16. Datum bis
  result+= dtos(if(len(::records)>0,atail(::records):BelegDatum,))+SEP_CHAR
  // 17. Bezeichnung des Buchungsstapels
  if len(::records)>0
    result+= getDatevFormat(DATEV_BEZEICHN+" "+mycmonth(::records[1]:BelegDatum)+;
      str(year(::records[1]:BelegDatum)))+SEP_CHAR
  else
    result+= getDatevFormat("Leer")+SEP_CHAR
  endif
  // 18. Diktatk�rzel == leer
  result+= getDatevFormat("")+SEP_CHAR
  // 19. Buchungstyp
  result+= getDatevFormat(DATEV_BUCH_TYP)+SEP_CHAR
  // 20. Rechnungslegungszweck == Leer oder 0
  result+= getDatevFormat(0)+SEP_CHAR
  // 21. reserviert == Leer
  result+= SEP_CHAR
  // 22. W�hrungskennzeichen
  result+= getDatevFormat("EUR")+SEP_CHAR
  // 23. reserviert == Leer
  result+= SEP_CHAR
  // 24. reserviert == Leer
  result+= SEP_CHAR
  // 25. reserviert == Leer
  result+= SEP_CHAR
  // 26. reserviert == Leer
  // result+= SEP_CHAR // Kein Sep.Char am Schluss!

RETURN result
/** eom */

/*----------------------------------------------------------------------*/


/*----------------------------------------------------------------------*/
METHOD dump(fullFileName)
LOCAL rec,ant

  default fullFileName:=DATEV_DIR

  mkmydir(getBaseName(fullFileName))
  ferase(fullFileName)
  set alte to (fullFileName) Additive
  set alte on
  set cons off

  // Header first
  qqout(::getHeader())
  qout(BUCH_HEADER)

  // all records
  for each rec in ::records
    qout(rec:dump())
  next

  close alte

  deleteCTRLZ(fullFileName)

  set cons on
  cls
  titel()
  if (ant:=Message("Datev-Export generiert.   Anzeigen? (@J@/@N@/@O@rdner)","JNO","N"))$"OJ"
    // FIXME: use myrun here
    if ant=="J"
      wapi_SHELLEXECUTE( 0, 0, fullFileName, , 0, 0 ) // startet neuen Prozess ohne Show!
    else
      wapi_SHELLEXECUTE( 0, "open", getBaseName(fullFileName)) // �ffnet Ordner
    endif
  endif

return self
/** eom */
/** eoc - end of class */


/** Class DatevRecord ************************************************************** */



CLASS DatevRecord

DATA Umsatz // (ohne Soll/Haben-Kz)
DATA Soll_HabenKZ // -Kennzeichen
DATA WKZ INIT "EUR"
DATA Kurs
DATA Basis_Umsatz
DATA WKZ_Basis_Umsatz
DATA Konto
DATA Gegenkonto // (ohne BU-Schl�ssel)
DATA BU_Schluessel
DATA Belegdatum
DATA Belegfeld1
DATA Belegfeld2
DATA Skonto
DATA Buchungstext
DATA Postensperre
DATA Diverse_Adressnummer
DATA Geschaeftspartnerbank
DATA Sachverhalt
DATA Zinssperre
DATA Beleglink
DATA Beleginfo_Art1
DATA Beleginfo_Inhalt1
DATA Beleginfo_Art2
DATA Beleginfo_Inhalt2
DATA Beleginfo_Art3
DATA Beleginfo_Inhalt3
DATA Beleginfo_Art4
DATA Beleginfo_Inhalt4
DATA Beleginfo_Art5
DATA Beleginfo_Inhalt5
DATA Beleginfo_Art6
DATA Beleginfo_Inhalt6
DATA Beleginfo_Art7
DATA Beleginfo_Inhalt7
DATA Beleginfo_Art8
DATA Beleginfo_Inhalt8
DATA KOST1_Kostenstelle
DATA KOST2_Kostenstelle
DATA Kost_Menge
DATA UStID
DATA EU_Steuersatz
DATA Abw_Versteuerungsart
DATA Sachverhalt_LL
DATA Funktionsergaenzung_LL
DATA BU49Hauptfunktionstyp
DATA BU49Hauptfunktionsnummer
DATA BU49Funktionsergaenzung
DATA Zusatzinformation_Art1
DATA Zusatzinformation_Inhalt1
DATA Zusatzinformation_Art2
DATA Zusatzinformation_Inhalt2
DATA Zusatzinformation_Art3
DATA Zusatzinformation_Inhalt3
DATA Zusatzinformation_Art4
DATA Zusatzinformation_Inhalt4
DATA Zusatzinformation_Art5
DATA Zusatzinformation_Inhalt5
DATA Zusatzinformation_Art6
DATA Zusatzinformation_Inhalt6
DATA Zusatzinformation_Art7
DATA Zusatzinformation_Inhalt7
DATA Zusatzinformation_Art8
DATA Zusatzinformation_Inhalt8
DATA Zusatzinformation_Art9
DATA Zusatzinformation_Inhalt9
DATA Zusatzinformation_Art10
DATA Zusatzinformation_Inhalt10
DATA Zusatzinformation_Art11
DATA Zusatzinformation_Inhalt11
DATA Zusatzinformation_Art12
DATA Zusatzinformation_Inhalt12
DATA Zusatzinformation_Art13
DATA Zusatzinformation_Inhalt13
DATA Zusatzinformation_Art14
DATA Zusatzinformation_Inhalt14
DATA Zusatzinformation_Art15
DATA Zusatzinformation_Inhalt15
DATA Zusatzinformation_Art16
DATA Zusatzinformation_Inhalt16
DATA Zusatzinformation_Art17
DATA Zusatzinformation_Inhalt17
DATA Zusatzinformation_Art18
DATA Zusatzinformation_Inhalt18
DATA Zusatzinformation_Art19
DATA Zusatzinformation_Inhalt19
DATA Zusatzinformation_Art20
DATA Zusatzinformation_Inhalt20
DATA Stueck
DATA Gewicht

METHOD new()
METHOD dump()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new() CLASS DatevRecord
RETURN self
/** eom */
/*----------------------------------------------------------------------*/

/** Returns all data for this row / Buchung */
METHOD dump() CLASS DatevRecord
LOCAL result:="",itm,temp

  FOR EACH itm IN __objGetMsgType( self, HB_OO_MSG_DATA, HB_OO_CLSTP_EXPORTED, .F. )
    if left(itm,1)<>"_"
      temp:=__SendRawMsg(self,itm)
      result += getDatevFormat(temp)+SEP_CHAR
    endif
  next

  // remove last SEP_CHAR
  if len(result)>0
    result:=left(result,len(result)-1)
  endif

return result
/** eom */
/** eoc - end of class */

/** Some additional internal functions *******************************************/

  /* Returns the passed value as string
  * Strings -> enclosed with DATEV quote character
  * Number -> as string w/o quotes
  * Date -> TTMM   ??FIXME: where do we need this?
  */
Function getDatevFormat(value)
LOCAL result,temp

  if value==NIL
    return ""
  endif

  switch valtype(value)
  case "C"
    result:=QUOTE+trim(value)+QUOTE
    exit
  case "N"
    result:=alltrim(transform(value,"@E"))
    exit
  case "D"
    // result:=dtos(value)
    // dtos ->YYYYMMDD -> TTMMYYYY
    temp:=trim(dtos(value))
    // result:=substr(temp,7,2)+"."+substr(temp,5,2)+"."+substr(temp,1,4) // TT.MM.YYYY
    result:=substr(temp,7,2)+substr(temp,5,2) // TTMM
    exit
  case "T" // DateTime
    // 11.04.2012 200940CCC -> JJJJMMTTHHMMSS, we ignore tausendsel
    temp:=TtoC(value)
    result:=substr(temp,7,4)+substr(temp,4,2)+substr(temp,1,2)+substr(temp,12,6)+"000"
    exit
  otherwise
    Error("Datenformat nicht unterst�tzt:"+valtype(value),.t.)
  endswitch

RETURN result
/** eom */


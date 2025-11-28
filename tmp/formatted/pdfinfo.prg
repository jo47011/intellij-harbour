/************************************************************************************
 * Class PdfInfo
 *
 * liefert alle Details zu einer PDF Datei
 *
 ************************************************************************************/

#include "Miki.ch"
#include "hbclass.ch"

CLASS PDFInfo

DATA Type
DATA NameGerman HIDDEN
DATA NameEnglish HIDDEN
DATA Number
DATA Path

METHOD new( cType, cNumber, lErase )
METHOD getLocalizedName( Sprache , Zusatz )

ENDCLASS

/*----------------------------------------------------------------------*/

/** erzeugt neue PDF Info Objekt
*
* Parameters: ....
*             lErase    falls true werden alle ex. Dateien des Typs zu der Nr. gel�scht
*/
METHOD new( cType, cNumber , lErase ) CLASS PdfInfo

  ::Type:=cType
  ::Number:=allTrim( cNumber )

  default lErase:=.f.

  // suche Pfad anhand Type
  switch ::Type

    // faktdruck.prg
  case JOB_KV // Kostenvoranschlag
    ::Path:=PS_PDF_KV
    ::NameGerman:=JOB_KV
    ::NameEnglish:=JOB_EN_KV
    exit
  case JOB_AUFTRAG // Auftragsbest�tigung
    ::Path:=PS_PDF_AUFTRAG
    ::NameGerman:=JOB_AUFTRAG
    ::NameEnglish:=JOB_EN_AUFTRAG
    exit
  case JOB_LIEFERSCHEIN
    ::Path:=PS_PDF_LIEFER
    ::NameGerman:=JOB_LIEFERSCHEIN
    ::NameEnglish:=JOB_EN_LIEFERSCHEIN
    exit
  case JOB_GUTSCHRIFT
    ::Path:=PS_PDF_GUT
    ::NameGerman:=JOB_GUTSCHRIFT
    ::NameEnglish:=JOB_EN_GUTSCHRIFT
    exit
  case JOB_BEISTELL
    ::Path:=PS_PDF_BEIST
    ::NameGerman:=JOB_BEISTELL
    ::NameEnglish:=JOB_EN_BEISTELL
    exit
  case JOB_K_LIEFERSCHEIN
    ::Path:=PS_PDF_KLIEFER
    ::NameGerman:=JOB_K_LIEFERSCHEIN
    ::NameEnglish:=JOB_K_LIEFERSCHEIN // nur deutsch!
    exit
  case JOB_RECHNUNG
    ::Path:=PS_PDF_RECHN
    ::NameGerman:=JOB_RECHNUNG
    ::NameEnglish:=JOB_EN_RECHNUNG
    exit
  case JOB_RECHNUNG_E
    ::Path:=PS_PDF_RECHN_E
    ::NameGerman:=JOB_RECHNUNG
    ::NameEnglish:=JOB_EN_RECHNUNG
    exit
  case JOB_GELANG_BESCH
    ::Path:=PS_PDF_GELANG
    ::NameGerman:=JOB_GELANG_BESCH
    ::NameEnglish:=JOB_EN_GELANG_BESCH
    exit
  case JOB_HAND_LIEFERSCHEIN
    ::Path:=PS_PDF_HAND_LIEFER
    ::NameGerman:=JOB_HAND_LIEFERSCHEIN
    ::NameEnglish:=JOB_EN_HAND_LIEFERSCHEIN
    exit
  case JOB_AB_DATENBLATT
    ::Path:=PS_PDF_AB_DATBLATT
    ::NameGerman:=JOB_AB_DATENBLATT
    ::NameEnglish:=JOB_AB_DATENBLATT // nur deutsch!
    exit
  case JOB_KV_DATENBLATT
    ::Path:=PS_PDF_KV_DATBLATT
    ::NameGerman:=JOB_KV_DATENBLATT
    ::NameEnglish:=JOB_KV_DATENBLATT // nur deutsch!
    exit
  case JOB_RE_DATENBLATT
    ::Path:=PS_PDF_RE_DATBLATT
    ::NameGerman:=JOB_RE_DATENBLATT
    ::NameEnglish:=JOB_RE_DATENBLATT // nur deutsch!
    exit
  case JOB_SPEDITION_AB
    ::Path:=PS_PDF_SPEDITION
    ::NameGerman:=JOB_SPEDITION_AB
    ::NameEnglish:=JOB_EN_SPEDITION_AB
    exit
  case JOB_PRO_FORMA
    ::Path:=PS_PDF_PRO_FORMA
    ::NameGerman:=JOB_PRO_FORMA
    ::NameEnglish:=JOB_EN_PRO_FORMA
    exit

    // angebot
  case JOB_ANGEBOT
    ::Path:=PS_PDF_ANGEBOT
    ::NameGerman:=JOB_ANGEBOT
    ::NameEnglish:=JOB_EN_ANGEBOT
    exit

    // bestellung
  case JOB_PREISANFRAGE
    ::Path:=PS_PDF_PREISANF
    ::NameGerman:=JOB_PREISANFRAGE
    ::NameEnglish:=JOB_PREISANFRAGE // nur deutsch!
    exit

  case JOB_BESTELLUNG
    ::Path:=PS_PDF_BESTELL
    ::NameGerman:=JOB_BESTELLUNG
    ::NameEnglish:=JOB_BESTELLUNG // nur deutsch!
    exit

  case JOB_LLE // Langzeitlieferantenerkl�rung
    ::Path:=PS_PDF_LLE
    ::NameGerman:=JOB_LLE
    ::NameEnglish:=JOB_EN_LLE
    exit
  case JOB_WBS // Warenbegleitschein
    ::Path:=PS_PDF_WBS
    ::NameGerman:=JOB_WBS
    ::NameEnglish:=JOB_WBS
    exit

  otherwise
    Error( "Fehler: unbekannte Vorgangsart." + SCHWERER_FEHLER)
    ::Path:=PS_PDF
    ::NameGerman:="unbekannt"
    ::NameEnglish:="unknown"
    exit
  endswitch


  // l�sche alte PDF Datei (englisch & deutsch
  if lErase
    ferase( ::Path + BACKSLASH + ::getLocalizedName( DEUTSCH ) + ".pdf " )
    ferase( ::Path + BACKSLASH + ::getLocalizedName( ENGLISCH ) + ".pdf " )
  endif

RETURN self

/*----------------------------------------------------------------------*/

/** Liefert z.Zt. 1:1 die Menge, kann sp�ter abweichen bei alternativer St�ckliste je Auftrag */

METHOD getLocalizedName( Sprache , Zusatz )
  default ZuSatz:=""
RETURN ::Number + "-" + if( Sprache == DEUTSCH, ::NameGerman , ::NameEnglish ) + ZuSatz


/************************************************************************************/
/* end of Class PdfInfo
/************************************************************************************/


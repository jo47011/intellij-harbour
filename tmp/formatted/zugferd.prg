/************************************************************************************
 * Class Rechnung
 *
 * repr�sentiert eine Rechnung, kann json exportieren f�r Zugferd Rechnung.

 * unit-Codes for VPE (Verpackungseinheit)

not working:
PAC ("Package") -- used for describing a "package" generically in some contexts.
PK sometimes appears in certain local lists but may be absent in UNECE Rec�20/21.
COL = "Collection"
BDL = "Bundle"

no match:
CSK ("Casket") or other specialized codes exist if your item is physically shipped in that container.
BX = "Box"
KIT = "Kit"
CP = "Crate, plastic" (less common)
BG = "Bag" (not always appropriate)


 *
 ************************************************************************************/

#include "Miki.ch"
#include "hbclass.ch"
#include "fileio.ch"

#define E_INVOICE_POSTFIX "-E-INTERN"

CLASS Invoice
DATA rechnr
DATA sprache
DATA header INIT {}
DATA buyer INIT {}
DATA seller INIT {}
DATA items INIT {}
DATA payment
DATA forwarder
DATA ME_map INIT {;
  " " => "C62", ; // leer => St�ck
"0" => "SET", ; // VPE == Package: PA, PAC, COL, BDL or PK not working;
"1" => "C62", ; // Stk;
"2" => "SET", ; // Sz. == Set;
"3" => "MTR", ; // m;
"4" => "LTR", ; // l;
"5" => "GRM", ; // g;
"6" => "CMT", ; // cm;
"7" => "KGM", ; // kg;
"8" => "HUR", ; // Std;
"9" => "C62" ; // Pl.
}
METHOD new( cRechNr )
METHOD toJson( cFileName )
METHOD loadData()
METHOD buildJsonStructure()
METHOD createZugferdXML( cOutputFile )
METHOD createZugferdInvoice()

ENDCLASS


/**************************************************************************
 * Methode: new(cRechNr)
 *
 * Konstruktor der Klasse Rechnung. Initialisiert das Objekt mit der 
 * �bergebenen Rechnungsnummer cRechNr und l�dt die zugeh�rigen Daten 
 * aus der Datenbank.
 **************************************************************************/
METHOD new( cRechNr ) CLASS Invoice
LOCAL cRechNrLocal:=cRechNr

  ::rechnr:=cRechNrLocal
  ::loadData()

RETURN Self


/**************************************************************************
 * Methode: loadData()
 *
 * L�dt alle notwendigen Daten aus den Datenbanken (RECHAUS, RECHPOST, 
 * ZAHLKOND) um die Rechnungsstruktur aufzubauen. Ermittelt Header-, 
 * K�ufer-, Zahlungs- und Posten-Informationen inkl. globaler und 
 * artikelbezogener Rabatte.
 *
 **************************************************************************/
METHOD loadData() CLASS Invoice
LOCAL cZkText:=""
LOCAL cZkText2:=""
LOCAL cArtNr:=""
LOCAL nQty:=0.00
LOCAL nUnitPrice:=0.00
LOCAL cUnitCode:=""
LOCAL nLineValue:=0.00
LOCAL nDiscount:=0.00
LOCAL cDesc:=""
LOCAL aComments:={}, comment
LOCAL cShippMethod:=""
LOCAL item
LOCAL Paletten
LOCAL KStorno:=.f. // not yet implemented
LOCAL tempVal, aBanks
LOCAL cInvoiceType:="A1" // default ist Rechnung
LOCAL teilLieferung:=.f.

  Umgebung(WRITE_ALL)
  if ! open( "ZahlKond", "Text_Kz", "Artikel", "Einheit", "VersArt",;
    "Spedit", "Land", "RechAus", "RechPost","MAT_KZ","ArtText","MwSt_KZ")
    Umgebung(LOAD)
    RETURN Self
  ENDIF

  // RECHAUS
  SELECT RECHAUS
  RECHAUS->(dbseek(::rechnr))
  IF RECHAUS->(eof())
    Error("Rechnung:" + ::rechnr +" nicht gefunden.")
    Umgebung(LOAD)
    RETURN Self
  ENDIF

  selLandBySprache( iif(empty(RECHAUS->R_Sprache), DEUTSCH, RECHAUS->R_Sprache) )
  ::sprache:=LAND->Sprache

  // determine Versandart
  if ! empty(RECHAUS->versNr)
    VERSART->(dbseek(RECHAUS->versNr))
    if ! VERSART->(eof())
      cShippMethod:=getTranslation("allgemein.versand",::sprache)+"\n"+ ;
        trim(getTransField("VERSART->Text"))
    endif
  endif

  // additonal comments if any
  aComments:={}

  // Gelangensbescheinigungs Text
  // is this already a GelangensBescheinigungs-Rechnung? -> No need to print warning again
  if RECHAUS->GelKZ<>"J" // .and. ! Kstorno .and. ! Storno
    comment:=getGBSText(RECHAUS->Netto)
    if comment <> NIL
      comment:=strtran(comment, "�", "")
      comment:=strtran(comment, "@", "") // No highlightening supported
      comment:=strtran(comment, BACKSLASH, "")
      if ! myEmpty(comment)
        aadd(aComments, comment)
      endif
    endif
    // tempWarns:=getTranslation("AB.gelang.warnung",::Sprache)
    // tempGelangs:=getOpenGelang(RECHAUS->KundNr) // always empty
  endif

  // Rahmen-AB Hinweis
  if ! empty(RECHAUS->Ab_AufNr)
    aadd(aComments, getTranslation("allgemein.rahmenauftrag",::Sprache)+": "+RECHAUS->Ab_AufNr)
  endif

  aBanks:={;
    { ;
    "IBAN" => getProperty("Miki.zugferd.IBAN", "DE27 6704 0031 0401 1532 00"), ;
    "BIC" => getProperty("Miki.zugferd.BIC", "COBA DE FF XXX"), ;
    "BankName" => getProperty("Miki.zugferd.BankName","Commerzbank Mannheim") ;
    }, ;
    { ;
    "IBAN" => getProperty("Miki.zugferd.IBAN2", "DE76 6705 0505 0030 2528 37"), ;
    "BIC" => getProperty("Miki.zugferd.BIC2", "MANS DE 66 XXX"), ;
    "BankName" => getProperty("Miki.zugferd.BankName2","Sparkasse Rhein-Neckar Nord") ;
    }, ;
    { ;
    "IBAN" => getProperty("Miki.zugferd.IBAN3", "DE69 5451 0067 0008 5226 77"), ;
    "BIC" => getProperty("Miki.zugferd.BIC3", "PBNK DE FF 545"), ;
    "BankName" => getProperty("Miki.zugferd.BankName3","Postbank Ludwigshafen") ;
    };
    }

  ::seller:={ ;
    "ID" => RECHAUS->LiefNr, ;
    "Name" => getProperty("Miki.zugferd.name","MIKI-PLASTIK GmbH"), ;
    "LineOne" => getProperty("Miki.zugferd.StreetName","Marconistra�e 16-22"), ;
    "LineTwo" => getProperty("Miki.zugferd.AdditionalStreetName",""), ;
    "LineThree" => getProperty("Miki.zugferd.AdditionalStreetName2",""), ;
    "Postcode" => getProperty("Miki.zugferd.Postcode","68309"), ;
    "CityName" => getProperty("Miki.zugferd.CityName","Mannheim"), ;
    "CountryID" => getProperty("Miki.zugferd.CountryID","DE"), ;
    "VATID" => getProperty("Miki.zugferd.VATID","DE815310690"), ;
    "TaxID" => getProperty("Miki.zugferd.TaxID","37003/03010"), ;
    "LegalRegistrationID" => getProperty("Miki.zugferd.LegalRegistrationID","HRB 6247"), ;
    "LegalInfo" => strtran(getTranslation("zugferd.LegalInfo",::Sprache),BACKSLASH,"\n"), ;
    "Phone" => getProperty("Miki.zugferd.phone"," +49 (0)621 / 73 70 61"), ;
    "Fax" => getProperty("Miki.zugferd.fax","+49 (0)621 / 73 34 88"), ;
    "Email" => getProperty("Miki.zugferd.email","info@miki-plastik.de"), ;
    "CEO" => getProperty("Miki.zugferd.CEO","Dipl.-Ing. (FH) Marcus Weiland"), ;
    "Banks" => aBanks ;
    }
  // "IBAN" => getProperty("Miki.zugferd.IBAN","DE27 6704 0031 0401 1532 00"), // "BIC" => getProperty("Miki.zugferd.BIC","COBA DE FF XXX"), // "BankName" => getProperty("Miki.zugferd.BankName","Commerzbank Mannheim")

  ::header:={ "InvoiceNumber" => RECHAUS->RechNr, "InvoiceDate" => dateToISO(RECHAUS->ReaDat),;
    "DeliveryNoteNumber" => TRIM(RECHAUS->LiefNr),;
    "BuyerOrderReferencedDocument" => TRIM(RECHAUS->bestnr),;
    "BuyerReference" => TRIM(RECHAUS->R_KundNr), "CurrencyCode" => "EUR",;
    "NetTotal" => RECHAUS->Netto, "GrossTotal" => RECHAUS->Brutto,;
    "ForeignCurrencyCode" => RECHAUS->FREMDWAEHR, "ForeignTotalAmount" => RECHAUS->FREMDSUMME,;
    "TaxRate" => RECHAUS->MwSt, "DocumentLanguageCode" => LAND->LandKZ,;
    "GlobalDiscountBasis" => RECHAUS->Rab_Basis, "GlobalDiscount" => RECHAUS->Rab_Sum,;
    "GlobalDiscountPercent" => RECHAUS->So_Rabatt,;
    "GlobalDiscountReason" => trim(iif(RECHAUS->Rabatt_KZ="H", trim(getTranslation("allgemein.rab"+;
    "att.haendler",::sprache)), trim(getTranslation("allgemein.rabatt.sonder",::sprache))) + " " + trim(getTranslation("allgemein.rabatt.ausser",::sprache))), "GlobalSurchargeBasis" => RECHAUS->Auf_Basis, "GlobalSurcharge" => RECHAUS->Auf_Sum, "GlobalSurchargePercent" => RECHAUS->Zuschlag, "GlobalSurchargeReason" => trim(getTranslation("allgemein.zuschlag.energie",::sprache)) + " " + trim(getTranslation("allgemein.rabatt.ausser",::sprache)), "DeliveryDate" => dateToIso(RECHAUS->ReaDat), "SellerOrderNumber" => RECHAUS->AufNr, "BuyerOrderNumber" => RECHAUS->BestNr, "GelangensbescheinigungNumber" => RECHAUS->GelNr, "OrderDate" => dateToISO(RECHAUS->AufDat), "BuyerOrderDate" => dateToISO(RECHAUS->BestDat), "InvoiceType" => cInvoiceType, "CostCenter" => trim(RECHAUS->BestKonto), "FrameOrderNumber" => trim(RECHAUS->Ab_AufNr), "CreditNoteNumber" => trim(RECHAUS->Storno_Nr), "ShippingMethod" => cShippMethod, "HeaderComments" => aComments }

  ::buyer:={ ;
    "Name" => TRIM(RECHAUS->R_Name), ;
    "LineOne" => TRIM(RECHAUS->R_Partner), ;
    "LineTwo" => TRIM(RECHAUS->R_Strasse), ;
    "LineThree" => TRIM(RECHAUS->R_Zusatz), ;
    "Postcode" => TRIM(RECHAUS->R_Plz), ;
    "CityName" => TRIM(RECHAUS->R_Ort), ;
    "CountryID" => iif(TRIM(RECHAUS->R_Land)=="D","DE",TRIM(RECHAUS->R_Land)), ;
    "VATID" => TRIM(RECHAUS->IdentNr), ;
    "ContactPerson"=> trim(RECHAUS->Ansprech), ;
    "Email" => TRIM(RECHAUS->Email), ;
    "Fax" => trim(RECHAUS->Fax), ;
    "Phone" => TRIM(RECHAUS->TELEFON) ;
    }

  // ZAHLKOND
  SELECT ZAHLKOND
  ZAHLKOND->(dbseek(RECHAUS->ZkNr))
  IF ! ZAHLKOND->(eof()) // .and. ! RECHAUS->AufArt $ "GS" // nicht bei Gutschrift oder Storno
    cZkText:=TRIM(getTransField("ZAHLKOND->Text"))
    cZkText2:=TRIM(getTransField("ZAHLKOND->Text2"))
    ::payment:={ ;
      "Description" => cZkText + IIF(!EMPTY(cZkText2), " " + cZkText2, ""), ;
      "DueDate" => dateToISO(RECHAUS->Faellig), ;
      "DiscountDueDate" => IIF(EMPTY(RECHAUS->SktoFaell), NIL, dateToISO(RECHAUS->SktoFaell)), ;
      "DiscountTerms" => "" ;
      }
  ENDIF

  // Werbetext
  if ! empty(RECHAUS->TextKz_Nr)
    TEXT_KZ->(dbseek(RECHAUS->TEXTKZ_NR))
    IF ! TEXT_KZ->(eof())
      ::header["HeaderTextLines"]:={ ;
        trim(getTransField("TEXT_KZ->Text1")),;
        trim(getTransField("TEXT_KZ->Text2")),;
        trim(getTransField("TEXT_KZ->Text3")),;
        trim(getTransField("TEXT_KZ->Text4")),;
        trim(getTransField("TEXT_KZ->Text5")),;
        trim(getTransField("TEXT_KZ->Text6"));
        }
    endif
  endif

  // Spedition
  if ! empty(RECHAUS->SPEDNR)
    SPEDIT->(dbseek(RECHAUS->SPEDNR))
    IF ! SPEDIT->(eof())
      ::forwarder:={ ;
        "Name" => getTransField("SPEDIT->Name"), ;
        "Name2" => getTransField("SPEDIT->Name2"), ;
        "Street1" => trim(SPEDIT->Strasse1), ;
        "Street2" => trim(SPEDIT->Strasse2), ;
        "Country" => trim(SPEDIT->Land), ;
        "Postcode" => trim(SPEDIT->Plz), ;
        "CityName" => trim(SPEDIT->Ort), ;
        "Fax" => trim(SPEDIT->Fax), ;
        "Email" => trim(SPEDIT->Email), ;
        "Contact" => trim(SPEDIT->Ansprech), ;
        "Language" => trim(SPEDIT->Sprache);
        }
    endif
  endif

  // Line Items
  SELECT RECHPOST
  RECHPOST->(dbseek(::rechnr))
  ADEL(::items, 1, Len(::items)) // Ensure empty

  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )

  aComments:={}

  DO WHILE !RECHPOST->(eof()) .AND. RECHPOST->RechNr == ::rechnr
    cDesc:=TRIM(getTransField("RECHPOST->komm1"))
    IF ! EMPTY(getTransField("RECHPOST->komm2"))
      cDesc += "\n" + TRIM(getTransField("RECHPOST->komm2"))
    ENDIF

    // Teillieferung?
    if RECHPOST->Menge > RECHPOST->GeliefGes
      teilLieferung:=.t.
    endif

    // add comment line to previous or next real item
    if left(RECHPOST->ArtNr,1) $ "*$"
      if len(::items) > 0
        // vorheriger Artikel
        aadd(::items[len(::items)]["LineComments"], cdesc)
      else
        // 1. Posten also zum n�chsten Artikel
        aadd(aComments, cDesc)
      endif
      skip
      loop
    endif

    ARTIKEL->(dbseek(RECHPOST->ArtNr))

    // drucke Gewicht falls bei Artikel hinterlegt
    if ARTIKEL->Gewicht > 0
      aadd(aComments, getTranslation("angebot.gewicht.stk",::Sprache)+" "+;
        trim(getTransField("EINHEIT->Text"))+": "+;
        alltrim(no_trailing_zeros(ARTIKEL->Gewicht))+" kg")
    endif

    // see #define KLAGER_BESTNR_DRUCK (
    if (RECHAUS->Aufart=="K" .or. Kstorno) .and. len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE .and. ;
      ! empty(RECHPOST->LiefNr)
      aadd(aComments,getTranslation("AB.nummer",::Sprache)+RECHPOST->AufNr+" "+;
        getTranslation("LS.nummer",::Sprache)+RECHPOST->LiefNr)
    endif

    // Sonder Text bei EU-Palette und Gitterbox falls Preis 0, dann nur im Tausch
    if len(alltrim(RECHPOST->ArtNr))<= FRACHT_LAENGE .and. RECHPOST->Preis == 0 .and. ;
      aContains( paletten , alltrim(RECHPOST->ArtNr))

      tempVal:=getTranslation("allgemein.palette.kostenfrei",::Sprache)
      tempVal:=lstrip(tempVal,"(")
      tempVal:=rstrip(tempVal,")")
      aadd(aComments, tempVal)
    endif

    cArtNr:=out(RECHPOST->ArtNr, .t.)
    nQty:=RECHPOST->gelief
    nUnitPrice:=RECHPOST->Preis
    cUnitCode:=::ME_map[RECHPOST->ME]
    nLineValue:=ROUND(nUnitPrice * nQty / IIF(RECHPOST->PE $ "Hh",100,1), 2)
    nDiscount:=0.00

    IF RECHPOST->rabatt <> 0.0
      nDiscount:=ROUND(nLineValue * (RECHPOST->Rabatt/100),2)
      nLineValue:=nLineValue // - nDiscount
    ENDIF

    // as of now KW is not needed
    // if ! KWempty(RECHPOST->KW) .and. ! left(RECHPOST->KW,1) $ "*$"
    // aadd(aComments, getTranslation("allgemein.kw",::sprache)+" "+RECHPOST->KW)
    // endif

    // if ! KWempty(RECHPOST->KW_TEXT)
    // aadd(aComments, TRIM(RECHPOST->KW_TEXT))
    // endif

    // VPE Inhalt bereits als Rechnungsposten-Text hinterlegt
    // if RECHPOST->Inhalt>0
    // EINHEIT->(dbseek(RECHPOST->InhaltME))
    // comment:=trim(getTranslation("allgemein.inhalt",::sprache))+" "+;
    // alltrim(str(RECHPOST->Inhalt,10,EINHEIT->NachKomma))+" "+;
    // trim(getTransField( "EINHEIT->Text" ))
    // aadd(aComments, comment)
    // endif

    if ! empty(RECHPOST->GerVon) .or. ! empty(RECHPOST->GerBis)
      comment:=trim(getTranslation("AB.geratnummer",::sprache))+" "+RECHPOST->GerVon
      if ! empty(RECHPOST->GerBis)
        comment+= "- "+RECHPOST->GerBis
      endif
      aadd(aComments, comment)
    endif

    // Material-Kennziffer
    if ! empty(ARTIKEL->MatKz)
      MAT_KZ->(dbseek(ARTIKEL->MatKz))
      if ! MAT_KZ->(eof())
        if ! empty( getTransField( "MAT_KZ->MkzText" ) )
          aadd(aComments, trim(getTransField( "MAT_KZ->MkzText" )))
        endif
      endif
    endif

    // Artikel-Texte
    if ! empty(ARTIKEL->ArtTextNr)
      ARTTEXT->(dbseek(ARTIKEL->ArtTextNr))
      if ! ARTTEXT->(eof())
        if ! empty( getTransField( "ARTTEXT->Text" ) )
          aadd(aComments, trim(getTransField( "ARTTEXT->Text" )))
        endif
      endif
    endif

    item = { ;
      "ArticleNumber" => cArtNr, ;
      "Description" => cDesc, ;
      "InvoicedQuantity" => nQty, ;
      "UnitCode" => cUnitCode, ;
      "NetPriceProduct" => nUnitPrice, ;
      "LineTotalAmount" => nLineValue, ;
      "LineDiscountAmount" => nDiscount, ;
      "LineDiscountPercent" => RECHPOST->rabatt, ;
      "BuyerMaterialNumber" => trim(ARTIKEL->Hartnr), ;
      "LineAllowanceReason" => trim(iif(RECHPOST->RabattGr==SONDER_RABATT,;
      trim(getTranslation("allgemein.rabatt.sonder",::sprache)),;
      trim(StrTran(getTranslation("allgemein.rabatt.menge",::sprache),":","")))), ;
      "CustomsTariffNumber" => ARTIKEL->WarenNr, ;
      "CountryOfOrigin" => ARTIKEL->LandKZ, ;
      "UnitQuantity" => IIF(RECHPOST->PE $ "Hh",100,1),;
      "LineComments" => aComments ;
      }

    AADD(::items, item)

    RECHPOST->(dbskip(1))
    aComments:={}

  ENDDO


  // bestimme Rechnungsart, falls abweichend
  IF RECHAUS->AufArt $ "S"
    cInvoiceType:="S" // Storno
  elseif RECHAUS->AufArt == "G"
    cInvoiceType:="G" // Gutschrift
  elseif teilLieferung
    cInvoiceType:="D1" // Teillieferung
  ENDIF
  ::header["InvoiceType"]:=cInvoiceType

  Umgebung(LOAD)
RETURN Self


/**************************************************************************
 * Methode: buildJsonStructure()
 *
 * Baut die endg�ltige JSON-Struktur f�r eine Zugferd-konforme Rechnung auf.
 **************************************************************************/
METHOD buildJsonStructure() CLASS Invoice
LOCAL hJson:={}

  hJson:={ ;
    "Header" => ::header, ;
    "Seller" => ::seller, ;
    "Buyer" => ::buyer, ;
    "LineItems" => ::items, ;
    "PaymentTerms" => ::payment, ;
    "Forwarder" => ::forwarder ;
    }

RETURN hJson


/**********************************************************************************************
 * Methode: toJson(cFileName)
 *
 * Export the current invoice structure to a JSON file in UTF-8 encoding.
 * If no filename is given, use the invoice number + ".json".
 **********************************************************************************************/
METHOD toJson( cFileName ) CLASS Invoice
LOCAL hJson:={}
LOCAL cJson:=""
LOCAL cJsonUTF8:=""
LOCAL nHandle

  hJson:=::buildJsonStructure()
  cJson:=hb_jsonEncode(hJson, .F., .T.) // pretty print

  // Convert to UTF-8
  cJsonUTF8:=hb_StrToUTF8(cJson)

  // Write UTF-8 data manually
  nHandle:=FCreate(cFileName, FC_NORMAL)
  IF nHandle != -1
    FWrite(nHandle, cJsonUTF8) // write raw UTF-8 bytes
    FClose(nHandle)
  ELSE
    qout("Error writing JSON file: " + cFileName)
  ENDIF

RETURN Self


/**************************************************************************
* Methode: createZugferdXML()
*
* Upload the previously created JSON file to the given endpoint and download
* the ZUGFeRD XML response directly into a file using 'curl'.
* Ensure 'curl' is installed and accessible from PATH.
*
* The resulting XML file will be saved as {invoice_number}_zugferd.xml
**************************************************************************/
METHOD createZugferdXML(pdfInfo) CLASS Invoice
LOCAL ePath:=pdfInfo:path + E_INVOICE_POSTFIX
LOCAL cJsonFile:=ePath + BACKSLASH + pdfInfo:getLocalizedName( ::Sprache ) + ".json"
LOCAL cZugferdXmlFile:=ePath + BACKSLASH + pdfInfo:getLocalizedName( ::Sprache ) + ".xml"
LOCAL cCommand, nRetCode
LOCAL host:=getProperty("System.zugferd.server","")

  mkmydir(ePath)

  ::toJson(cJsonFile)

  // Construct the curl command
  // -X POST: Use POST method
  // -H "Content-Type: application/json": Send JSON content type
  // -d @file: Send the file contents as the request body
  // -o {outfile}: Save the server's response to {outfile}
  cCommand:='cmd /c curl -X POST -H "Content-Type: application/json" -d @' + cJsonFile + ;
    " http://"+host+"/v1/create_zugferd_xml -o " + cZugferdXmlFile

  nRetCode:=RUNHIDDEN( cCommand, DEBUG ) // FIXME: move mytools#myrun() once tested

  if DEVEL_PROG .and. DEBUG
    set alte to foo.txt
    set alte on
    qout(cCommand)
    close alte

    QOut( cCommand )
    wait
  endif

  if nRetCode <> 0 .or. nRetCode == NIL
    do case
    case nRetCode==7 .or. nRetCode == NIL
      Error("Print Server "+host+" nicht erreichbar.")
    otherwise
      Error("Print Server Fehler: " + alltrim(str(nRetCode)))
    endcase
    RETURN nRetCode
  ENDIF

  // Optional: Check if the result file exists and is not empty
  IF ! File(cZugferdXmlFile)
    error("Failed to download ZUGFeRD XML. Please check logs or server.")
  ENDIF

RETURN Self


/**************************************************************************
* Methode: createZugferdInvoice()
*
* Upload the previously created JSON file and the associated PDF file to the
* given endpoint, retrieve a ZUGFeRD compliant PDF invoice, and save it locally.
*
* Steps:
*  1. Generate the JSON file from invoice data using ::toJson(cJsonFile).
*  2. Use curl to POST both JSON and PDF to the /v1/create_zugferd_invoice endpoint.
*  3. Save the returned ZUGFeRD PDF to {::rechnr}_zugferd.pdf
**************************************************************************/
METHOD createZugferdInvoice(pdfInfo) CLASS Invoice
LOCAL ePath:=pdfInfo:path + E_INVOICE_POSTFIX
LOCAL cJsonFile:=ePath + BACKSLASH + pdfInfo:getLocalizedName( ::Sprache ) + ".json"
LOCAL cZugferdPdfFile:=ePath + BACKSLASH + pdfInfo:getLocalizedName( ::Sprache ) + ".pdf"
LOCAL cPdfFile:=pdfInfo:path + BACKSLASH + pdfInfo:getLocalizedName( ::Sprache ) + ".pdf"
LOCAL TempPath:=TEMP+BACKSLASH+left(getUser():getLongId(),2)+BACKSLASH
LOCAL TempFile:=TempPath+"ZugFerd-"+getUser():getTempCounter()+".txt"
LOCAL cCommand
LOCAL host:=getProperty("System.zugferd.server","")
LOCAL cStatusCode, cErrorText, jError, nRetCode

  mkmydir(ePath)

  ::toJson(cJsonFile)

  IF ! File(cPdfFile)
    Error("PDF nicht gefunden: " + cPdfFile)
    RETURN Self
  ENDIF

  // Use '<' instead of '@' to send the JSON as a plain form field
  // 'invoice_data_str' is just text now, so FastAPI sees it as a normal form field
  // -s : silent mode (no progress bar)
  // -w CODE : writes the HTTP status code to stdout
  // -o FILE : writes the response body to FILE
  cCommand:='cmd /c curl -X POST ' +;
    '-F "invoice_data_json=<'+ cJsonFile +';type=application/json" ' +;
    '-F "pdf_file=@' + cPdfFile + ';type=application/pdf" ' +;
    'http://'+host+'/v1/create_zugferd_invoice ' +;
    '-o ' + cZugferdPdfFile + ' ' +;
    '-s -w "%{http_code}" > ' + TempFile

  nRetCode:=RUNHIDDEN( cCommand, DEBUG ) // FIXME: move mytools#myrun() once tested

  if DEVEL_PROG .and. DEBUG
    set alte to foo.txt
    set alte on
    qout(cCommand)
    close alte

    QOut( cCommand )
    wait
  endif

  if nRetCode <> 0 .or. nRetCode == NIL
    do case
    case nRetCode==7 .or. nRetCode == NIL
      Error("Print Server Zugferd "+host+" nicht erreichbar.")
    otherwise
      Error("Print Server Zugferd Fehler: " + alltrim(str(nRetCode)))
    endcase
    RETURN nRetCode
  ENDIF

  // Now read the status code
  IF FILE( TempFile )
    cStatusCode:=alltrim(MEMOREAD( TempFile ))
    IF cStatusCode <> "200"
      // Request failed, reading error text
      IF FILE( cZugferdPdfFile )
        cErrorText:=MEMOREAD( cZugferdPdfFile )
        hb_jsonDecode( cErrorText, @jError)
        Error("Print Server Error:||"+ jError["detail"], .t. ,"root")
        ferase(cZugferdPdfFile)
      ELSE
        Error("Print Server Error:  No response file found.", .t., "root")
      ENDIF
    ENDIF
    ferase(TempFile)
  ELSE
    qout("Could not retrieve status code ("+TempFile+" not found).")
  ENDIF

RETURN Self



#include "mystd.ch"
#include "hbclass.ch"

/**************  Mapping of old clipper messages to harbour code ***************************
 * will be obsolete once Clipper is dead
 */

/** Handelt das ein/ausschalten des Druckers
 *
 * Parameter: Status = "ON","BS","NOP","OFF","RESET","TEST","ASCI","PDF","FAX"
 *            DruckJobName: Name fuer Postscript Datei
 *            DruckZielPfad: Pfad fuer PostScript Datei
 *            druckeAGBS: sollen die AGBs am Ende des Drucks gedruckt werden?
 *            generatePDF: soll zusätzlich eine PDF Datei erzeugt werden?
 *                         (s. miki.ch: PDF_NONE, PDF_NO_CONFIRM, PDF_YES_CONFIRM
 *
 *            Anzahl: Anzahl der Kopien, bisher nur bei HARBOUR#win_prn
 *            Popup: soll die Liste in einem neuen Fenster angezeigt werden (nur bei BS, default ist true)

 * Result: .t. on success
 *         .f. on Abbruch
 *
 */
FUNCTION Drucker(Status,DruckJobName,DruckZielPfad,druckeAGBs,generatePDF,Anzahl,BSpopup)
LOCAL aktSel:=select()
LOCAL defDrucker

  Status:=upper(Status)

  do case
  case Status=="OFF"
    if valtype(BSpopup)=="L" .and. BSpopup
      getUser():getCurrentPrintJob():popup:=BSpopup
    endif
    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(NIL)
    return .t.

  case Status=="RESET"
    if getUser():getCurrentPrintJob()<>NIL
      getUser():getCurrentPrintJob():endDoc(.t.)
      getUser():setCurrentPrintJob(NIL)
    endif
    return .t.

  case Status=="ON" .and. ! NO_DRUCKER
    if seekPrinter()
      if upper(DRUCKER->Raw)=="J"
        getUser():setCurrentPrintJob(WinPrnJob():new())
      else
        getUser():setCurrentPrintJob(PrintJob():new())
      endif
      getUser():getCurrentPrintJob():numCopies:=LISTE->Anzahl
    else
      return .f.
    endif

  case Status=="TEST" .and. ! NO_DRUCKER
    if ! open("Liste") // Drucker sollte offen und sel. sein
      select (aktSel)
      return .f.
    endif
    if upper(DRUCKER->Raw)=="J"
      getUser():setCurrentPrintJob(WinPrnJob():new())
    else
      getUser():setCurrentPrintJob(PrintJob():new())
    endif

  case Status=="PDF"
    if ! seekPrinter()
      return .f.
    endif
    defDrucker:=DRUCKER->(recno())
    getUser():setCurrentPrintJob(PrintJob():new())
    if LISTE->Landscape=="J"
      DRUCKER->(dbseek("PQ"))
    endif
    if DRUCKER->(eof())
      DRUCKER->(dbgoto(defDrucker))
    endif
    getUser():getCurrentPrintJob():printToFileOnly:=.t.
    getUser():getCurrentPrintJob():generatePDF:=.t.
    // getUser():getCurrentPrintJob():confirmPDF:=.t. unlogisch, nur bei Bedarf oder?

  case Status=="FAX"
    if seekPrinter()
      DRUCKER->(dbseek("FA")) // suche Fax Drucker
      if DRUCKER->(eof())
        return .f.
      endif
      if upper(DRUCKER->Raw)=="J"
        getUser():setCurrentPrintJob(WinPrnJob():new())
      else
        getUser():setCurrentPrintJob(PrintJob():new())
      endif
      getUser():getCurrentPrintJob():numCopies:=1
    else
      return .f.
    endif

  case upper(Status)=="NOP" // nop, zum setzen von Parametern only
    // FIXME: setting parameters prior to drucker("ON",...) does not work anymore
    if getUser():getCurrentPrintJob(.t.)==NIL // quiet, since this is intented behaviour

      // usually not reached as printJob is always initialized in user
      getUser():setCurrentPrintJob(DummyJob():new(.t.)) // quiet, since this is intented behaviour
      // changed 28.2.2012
      // getUser():setCurrentPrintJob(PrintJob():new())

      // watchout dummy PrintJob maybe overwritten by next Drucker("ON"..) call
    endif
    if select("Drucker")==0
      if ! open("Drucker")
        select (aktSel)
        return .f.
      endif
    endif
    if select("Liste")==0
      if ! open("Liste")
        select (aktSel)
        return .f.
      endif
    endif
    // neu seit 31.5.2013 -> gehe trotzdem auf den "richtigen" Drucker, wegen Blatt-Länge etc.
    if ! seekPrinter()
      return .f.
    endif
    select (aktSel)
    getUser():getCurrentPrintJob():printToFileOnly:=.t.
    getUser():getCurrentPrintJob():generatePDF:=.f.

    // removed since CLIPPER support ended
    // return .t. // watchout startDoc not called for NO operation

  case Status=="BS" .or. NO_DRUCKER
    if type("M->qtWidget")<>"U" // we use QT currently
      seekPrinter()
      getUser():setCurrentPrintJob(QTJob():new())
    else
      getUser():setCurrentPrintJob(BSJob():new())
    endif
    getUser():getCurrentPrintJob():printToFileOnly:=.t.

  case Status=="ASCI"
    getUser():setCurrentPrintJob(AsciJob():new())
    getUser():getCurrentPrintJob():printToFileOnly:=.t.

  otherwise
    Error(ACHTUNG+" Druck-Typ:"+status+" unbekannt!",.t.)
    TroubleEmail(" Druck-Typ:"+status+" unbekannt!"+SCHWERER_FEHLER)

  endcase

  if DruckJobName<>NIL
    getUser():getCurrentPrintJob():jobName:=alltrim(DruckJobName)
  endif
  if DruckZielPfad<>NIL
    getUser():getCurrentPrintJob():pdfFilePath:=DruckZielPfad
    mkmydir(DruckZielPfad)
  endif
  if druckeAGBs<>NIL
    getUser():getCurrentPrintJob():AGBs:=druckeAGBs
  endif
  if generatePDF<>NIL
    getUser():getCurrentPrintJob():generatePDF:=(generatePDF==PDF_NO_CONFIRM .or.;
      generatePDF==PDF_YES_CONFIRM)
    getUser():getCurrentPrintJob():confirmPDF:=(generatePDF==PDF_YES_CONFIRM)
  endif
  if Anzahl<>NIL
    getUser():getCurrentPrintJob():numCopies:=Anzahl
  endif
  if BSpopup<>NIL
    getUser():getCurrentPrintJob():popup:=BSpopup
  endif

  // landscape: added 20150112 -> still testing
  if LISTE->Landscape=="J"
    getUser():getCurrentPrintJob():landscape:=.t.
  endif


  getUser():getCurrentPrintJob():startDoc()

  // if ! open("Zeige","Drucker","Liste")
  // select (aktSel)
  // return(.f.)
  // endif

  select (aktSel)

return .t.
/** eof */

/** FormularDruck */
PROCEDURE FormularDruck(formular,Seite)
  default formular:=DEFAULT_FORMULAR
  ignore Seite
  getUser():getCurrentPrintJob():setBackground(formular)
return
/** eof */

/** FormFeed */
Function FormFeed( Zeile , Seite , duplex)
  getUser():getCurrentPrintJob():formfeed( Zeile , Seite , duplex )
return 0
/** eof */

/** Sucht den Drucker & Liste zum aufrufenden Programm */
Function seekPrinter(CallerName)
LOCAL progName:=procname(2)
LOCAL aktsel:=select()
LOCAL merkeDruckerNr

  // qout("1->",procName(1))
  // qout("2->",procName(2))
  // qout("3->",procName(3))
  // qout("4->",procName(4))
  // qout("5->",procName(5))
  // qout("6->",procName(6))
  // qout("7->",procName(7))
  // wait

  // search for corresponding list and printer
  if CallerName<>NIL
    progName:=callerName
  else
    // FIXME: do we really need this? -> Ausdruck aus BS-AnZeige
    if ProgName$"DRUCK_BS/DRUCKE_ZEIGE/CREATE_PDF/DRUCK_BS_EXPORT/AEND" // unschön jojo
      if procname(3)=="ZEIGETEXT" // direkt aus Zeige
        progName:=procname(6)
      else
        progName:=procname(3)
      endif
    endif
  endif

  // Ohne Druckerlaubnis -> False zurück!
  if ! getUser():mayPrint .and. ! (getUser():mayPrintLabel .and. upper(left(progname,4))="ETI_")
    select (aktSel)
    RETURN .f.
  endif

  if ! open("Drucker","Liste")
    select (aktSel)
    RETURN .f.
  endif

  /* Programm-Aufruf auf richtige Länge bringen */
  ProgName:=left(ProgName+space(50),len(LISTE->Liste_Kurz))
  select Liste
  seek ProgName // such zu druckende Ausgabe (default)
  if eof()
    if ! druck_neu(ProgName) // neu aufnehmen
      select (aktSel)
      RETURN .f.
    endif
  endif

  /* FIXME: cleanup -> suche Drucker-Parameter */
  select Drucker
  if LISTE->Landscape=="J"
    // unschoen: nur 1 mögl. Drucker für Querdruck/Landscape (schnelle Lösung)
    seek "QU"
  else
    seek LISTE->DruckerNr
  endif
  if DRUCKER->(eof())
    error(LISTE_OHNE_DRUCKER)
    select (aktSel)
    RETURN .f.
  endif

  // suche alternativen Drucker basierend auf CLIENT_NAME
  if len(DRUCKER->AltClName) > 0 .and. CLIENT_NAME $ DRUCKER->AltClName
    merkeDruckerNr:=DRUCKER->DruckerNr
    seek DRUCKER->AltDruckNr
    if DRUCKER->(eof())
      TroubleEmail("Alternativer Drucker nicht gefunden: "+merkeDruckerNr+" -> " +;
        DRUCKER->AltDruckNr)
      seek (merkeDruckerNr)
    endif
  endif

  select (aktSel)
Return .t.
/** eof */


/*******************************************************************
* Class printSonderZeichen
* Klasse zur Kapselung der Sonderzeichen (FETT_AN/AUS etc.) im PrintBuffer Druck
*
*/
  CREATE CLASS printSonderZeichen
  VAR art

METHOD new( SZ )
METHOD getPrintChars()

ENDCLASS

METHOD New( SZ ) CLASS printSonderZeichen
  ::art:=SZ
RETURN Self

METHOD getPrintChars( printJob ) CLASS printSonderZeichen
LOCAL result:=""

  // Sonderzeichen aus PrintBuffer or PrintJob
  do case
  case valtype( ::art ) == "C"
    result:=::art
  case ::art == HB_AN_FETT
    result:=printJob:bold( .t. )
  case ::art == HB_AUS_FETT
    result:=printJob:bold( .f. )
  case ::art == HB_AN_BREIT
    result:=printJob:large( .t. )
  case ::art == HB_AUS_BREIT
    result:=printJob:large( .f. )
  case ::art == HB_AN_SCHMAL
    result:=printJob:small( .t. )
  case ::art == HB_AUS_SCHMAL
    result:=printJob:small( .f. )
  case ::art == HB_AN_KLEIN
    result:=printJob:little( .t. )
  case ::art == HB_AUS_KLEIN
    result:=printJob:little( .f. )
  case ::art == HB_AN_WINZIG
    result:=printJob:tiny( .t. )
  case ::art == HB_AUS_WINZIG
    result:=printJob:tiny( .f. )
  case ::art == HB_COLOR
    // NOP
  otherwise
    Trouble("root","Harbour-Druck fehlgeschlagen:|         unbekanntes Sonderzeichen:")
  endcase

return result
/** eom */


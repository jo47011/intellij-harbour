/* Listen2.prg
*
* Enth�lt Listen (rest in Listen.prg)
*/

#include "Miki.ch"
#include "Zeige.ch"

  /* PROCEDURE Auftrag je Kunden
  *
  *  Auftr�ge je Kunde (Fakt)
  */
PROCEDURE Auf_KundListe(kundenNr,force,klager)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL von, bis, betr:=0, aktSel:=(alias()), leerzeile
LOCAL SummeRest:=0.00,gesRest:=0.00,gespos:=0,pos:=0,liFullName, indexField
LOCAL artvon,artbis,klag:="J",Ausgabe,export,objErr, monat:="J", aktMonat:=0,aktJahr:="",ZwSum:=0
LOCAL summen:={}
LOCAL sortOrder:="K" // Default ist Liefer-KW
local DateiStru:=TEMP + BACKSLASH + left(getUser():getLongId(),2)+BACKSLASH+"AufList"
LOCAL TempDatei:=getTempDateiName( db_info("Aufpost") ) + ".dbf"
LOCAL text

  default force:=.f.
  default klager:=.f.

  Umgebung(WRITE_ALL)


  if ! open("Aufaus","Kunden","aufpost","Einheit","Artikel","AvPost","Auftrag","M_Mehrf","BesAus",;
    "KundSped","ZahlKond")
    Error(TRY_AGAIN)
    cls
    Umgebung(LOAD)
    RETURN
  endif

  cls
  titel("Auftragsbestandsliste detailliert")

  if force
    select Kunden
    go bottom
    bis:=KUNDEN->KundNr
    go top
    von:=KUNDEN->KundNr
  elseif valtype(KundenNr)=="C"
    KUNDEN->(dbseek(KUNDEN->KundNr))
    bis:=KUNDEN->KundNr
    von:=KUNDEN->KundNr
  else
    bis:=von_bis("Kunden",NIL,6)
    if empty(bis)
      cls
      Umgebung(LOAD)
      RETURN
    endif
    von:=KUNDEN->KundNr

    @ 10,20 say "Mit K-Lager..............:" get KLag picture "!" valid Klag $"JN" ;
      when Message("Mit K-Lager Auftragsbestand? (@J@/@N@)")
    @ 12,20 say "Zw.Summe / Monat.........:" get monat picture "!" valid monat $"JN";
      when Message("Mit Zwischensummer pro Monat? (@J@/@N@)")
    @ 14,20 say "Sortierierung (KW/F�llig):" get sortOrder picture "!" valid sortOrder $"KF";
      when Message("Gew�nschte Sortierung? @K@=Liefer-KW oder @F@=F�lligkeitsdatum")

    read
    if ! ABBRUCH
      artvon:=artbis:=space(len(ARTIKEL->ArtNr))
      artbis:=von_bis("Artikel",20,16)
      artvon:=ARTIKEL->ArtNr
    endif

    if ABBRUCH
      cls
      Umgebung(LOAD)
      RETURN
    endif

    klager:=(KLAG=="J")

  endif

  Message("Datei wird sortiert.   Bitte warten...")

  /* Relation setzten */
  SELECT AufAus
  SET RELATION TO AUFAUS->ZkNr into ZahlKond

  SELECT AufPost
  SET RELATION TO AUFPOST->ME INTO Einheit, to AUFPOST->ArtNr into Artikel, ;
    TO AUFPOST->AufNr into AUFAUS

  copy stru exte to (DateiStru)
  select 0
  use (DateiStru) alias Stru
  add_rec(0)
  replace STRU->FIELD_NAME with "Faellig"
  replace STRU->FIELD_Type with "D"
  replace STRU->FIELD_Len with 8
  use
  select 0
  create (TempDatei) from (DateiStru) alias data

  select AufPost
  if klager
    set filter to ((AUFAUS->KundNr>=von .and. AUFAUS->KundNr<= bis) .or.;
      (AUFAUS->V_KundNr>=von .and. AUFAUS->V_KundNr<=bis) .or.;
      (AUFAUS->R_KundNr>=von .and. AUFAUS->R_KundNr<= bis)) .and. ;
      .not. AUFAUS->AufArt$"AGN" .and. AUFAUS->erledigt<>"J" .and. ;
      AUFPOST->Menge > AUFPOST->GeliefGes .and. len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE ;
      .and. (ArtVon==NIL .or. (AUFPOST->ArtNr >= ArtVon .and. AUFPOST->ArtNr <= ArtBis))
  else
    set filter to ((AUFAUS->KundNr>=von .and. AUFAUS->KundNr<= bis) .or.;
      (AUFAUS->V_KundNr>=von .and. AUFAUS->V_KundNr<=bis) .or.;
      (AUFAUS->R_KundNr>=von .and. AUFAUS->R_KundNr<= bis)) .and. ;
      .not. AUFAUS->AufArt$"AGNKI" .and. AUFAUS->erledigt<>"J" .and. ;
      AUFPOST->Menge > AUFPOST->GeliefGes .and. len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE ;
      .and. (ArtVon==NIL .or. (AUFPOST->ArtNr >= ArtVon .and. AUFPOST->ArtNr <= ArtBis))

  endif

  go top
  select data
  do while ! AUFPOST->(eof())
    add_rec(0)
    overwrite("AufPost",.t.)
    if left(DATA->KW,2)<>"X1"
      replace DATA->Faellig with getDueDate(getKWLastDate(AUFPOST->KW))
    endif
    AUFPOST->(dbskip())
  enddo

  // ACHTUNG: index for clause kann nicht zu komplex sein, deshalb jetzt so 22.1.25
  if sortOrder=="K" // LieferKW
    if monat=="J"
      indexField:="kwindex(DATA->KW)+DATA->Kundnr"
    else
      indexField:="DATA->Kundnr+kwindex(DATA->KW)"
    endif
  else // Zahlungsziel
    indexField:="dtos(DATA->Faellig)+DATA->Kundnr"
  endif

  index on &(indexField) tag TEMP_INDEX TEMPORARY ADDITIVE
  go top
  SET RELATION TO DATA->ME INTO Einheit, to DATA->ArtNr into Artikel, ;
    TO DATA->AufNr into AUFAUS

  if force
    Drucker("PDF")
  elseif valtype(KundenNr)=="C"
    Drucker("BS")
  else
    Ausgabe:=Druck_Bs("Auftrag-Kunde" , "xlsx" , .t.)
    if ABBRUCH .or. ( valtype(Ausgabe) == "L" .and. ! Ausgabe )
      cls
      Umgebung(LOAD)
      RETURN
    endif

    if valtype(Ausgabe)=="C"
      // FIXME: sollte alles in druck_bs passieren
      // beisst sich aber mit alten excel:column export
      BEGIN SEQUENCE // krit. Bereich
        export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
        getUser():setCurrentPrintJob(ExcelJob():new())
        getUser():getCurrentPrintJob():StartDoc( export )
      RECOVER USING objErr
        // nop, Fehler bereits protokolliert
      END SEQUENCE
    endif

  endif

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  // hier noch nicht, da Menge "falsch" geparst wird
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not. DATA->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    if valtype(Ausgabe) <> "C"
      text:=if(klager,"K-Lager  ","")
      text+=if(sortOrder=="F","sortiert nach F�lligkeit","")
      ? "Miki Plastik GMBH  ***  Auftragsbestandsliste  ***",space(1),;
        left(alltrim(text)+space(50),50),space(20),"vom:",getUser():date,space(10),"  Seite :",;
        str(seite,3)
      ? '----------------------------------------------------------------------------------------'+;
        '----------------------------------------------------------------------------'
      ? "KD-Nr.   Kurzname Kunde            AB-Nr. Datum   Art.Nr.    Bezeichnung                 "+;
        "   ME     Bestell    bereits       Rest    Lager- Lief.  F�llig. Rest-Wert"
      ? "                                   Bestell-Nr.                                           "+;
        "           Menge    gelief.       Menge  Bestand  Datum   Datum     (Euro)"
      ? '----------------------------------------------------------------------------------------'+;
        '----------------------------------------------------------------------------'
      _____fixedHeader_____
    else // Excel
      if Seite==1
        ? "KD-Nr.","Kurzname Kunde","AB-Nr.","Bestell-Nr.","Datum","Art.Nr.","Bezeichnung","ME",;
          "Bestell-Menge","bereits gelief.","Rest-Menge","LagerBestand","Lief.-Datum","F�llig",;
          "Rest-Wert(Euro)"
      endif
    endif

    // ** aufsummieren des gel. Betrags
    SELECT Data
    do while ! DATA->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

      do while ! DATA->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop .and. ;
        (monat<>"J" .or. ;
        ((sortOrder=="K" .and. getKWMonth(DATA->KW)==aktMonat) .or. ;
        (sortOrder<>"K" .and. month(DATA->Faellig)==aktMonat)))

        // if trim(DATA->ArtNr)=="5005311"
        // altd()
        // endif

        if upper(DATA->PE)="H"
          betr:=round((DATA->Menge-DATA->GeliefGes)*DATA->Preis/100,2);
          * ROUND(1-DATA->Rabatt/100,2)
        else
          betr:=round((DATA->Menge-DATA->GeliefGes)*DATA->Preis,2) * ROUND(1-DATA->Rabatt/100,2)
        endif
        ? AUFAUS->KundNr,left(AUFAUS->KurzName,25),ZEIGE_AUFNR+AUFAUS->AufNr
        if valtype(Ausgabe)=="C"
          ?? AUFAUS->BestNr
        endif

        ARTIKEL->(dbseek(DATA->ArtNr))

        ?? AUFAUS->AufDat, ZEIGE_ARTNR+DATA->ArtNr,;
          left(DATA->Komm1,30),EINHEIT->Text,DATA->Menge,DATA->GeliefGes,;
          ZEIGE_MENGE+str(DATA->Menge-DATA->GeliefGes,10,2),ARTIKEL->LageBest,;
          if(left(DATA->KW,2)=="X1","Abruf",DATA->KW),;
          if(empty(DATA->Faellig),space(8),DATA->Faellig),transform(betr,"@E 999,999.99")

        // drucker Versand-Kundennr wenn abweichend
        if AUFAUS->KundNr <> AUFAUS->V_KundNr
          KUNDEN->(dbseek(AUFAUS->V_KundNr))
          leerZeile:=.t.
          ? AUFAUS->V_KundNr,KUNDEN->KurzName
        else
          leerZeile:=.f.
        endif

        // drucke Versand-Kundennr wenn abweichend
        if AUFAUS->KundNr <> AUFAUS->R_KundNr
          KUNDEN->(dbseek(AUFAUS->R_KundNr))
          leerZeile:=.t.
          ? AUFAUS->R_KundNr,KUNDEN->KurzName
        else
          leerZeile:=.f.
        endif

        if ! leerZeile
          ? space(34)
        endif

        if valtype(Ausgabe)<>"C"
          ?? AUFAUS->BestNr
        endif

        if ! empty(DATA->KW_Text)
          ?? space(25),trim(DATA->KW_Text)
        endif
        if leerZeile
          ?
        endif

        ZwSum+=betr
        summerest+=betr
        pos++

        // neu war vorher bei druckeZwischenSumme(pos,summeRest)
        gesRest+=betr
        gespos++

        skip
        Stop:=stop_key()
      enddo // Zw. Monat
      if monat=="J" .and. ((sortOrder=="K" .and. getKWMonth(DATA->KW)<>aktMonat) .or.;
        (sortOrder<>"K" .and. month(DATA->Faellig)<>aktMonat)) .or. DATA->(eof())
        if ZwSum >0
          ? '------------------------------------------------------------------------------------'+;
            '--------------------------------------------------------------------------------'
          ? space(138), getAktMonat(aktMonat, aktJahr), transform(zwSum,"@E 9,999,999.99")
          ?
          if aktMonat=0
            aadd(summen, {"Abruf       ", zwSum})
          else
            aadd(summen, {getAktMonat(aktMonat, aktJahr), zwSum})
          endif
        endif
        if sortOrder=="K"
          aktMonat:=getKWMonth(DATA->KW)
          aktJahr:=substr(DATA->KW,4)
        else
          aktMonat:=month(DATA->Faellig)
          aktJahr:=left(alltrim(str(year(DATA->Faellig)))+space(4),4)
        endif
        ZwSum:=0
      endif
    enddo
    if (DATA->(eof()) .or. DATA->Kundnr > bis) .and. valtype(Ausgabe)<>"C"
      if empty( kundenNr ) // Gesamtsumme nur bei mehreren Kunden
        if monat=="J"
          ? space(121),"=========================================="
          for each zwSum in Summen
            ? space(138),zwSum[1],transform(zwSum[2],"@E 9,999,999.99")
          next
        endif
        ? space(121),"=========================================="
        ? space(121),"Gesamt:",str(gespos,6),'Position(en)',transform(gesRest,"@E 999,999,999.99")
        ? space(121),"=========================================="
      endif
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  if valtype(Ausgabe)=="C"
    // getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=40
    getUser():getCurrentPrintJob():autoFitAll( )
  endif

  getUser():getCurrentPrintJob():endDoc()

  if force
    liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
    email(MAIN_EMAIL,"Auftragsliste vom: "+dtoc(getUser():date),;
      "Auftragsliste vom: "+dtoc(getUser():date), liFullName)
  endif
  getUser():setCurrentPrintJob(NIL)

  if valtype(Ausgabe)=="C"
    if Message(export+" wurde erzeugt.  Ordner �ffnen? @J@/@N@","JN","N")=="J"
      wapi_SHELLEXECUTE( 0, "open", getUser():exportPATH())
    endif

  endif

  cls
  close data
  ferase(TempDatei)
  ferase(DateiStru)
  M->specialZeige:=NIL
  Umgebung(LOAD)

RETURN
/* EOP Auftrags_Liste */


static function druckeZwischenSumme(pos,summeRest)
LOCAL Zeile:=0
  ? space(114),'----------------------------------------'
  ? space(114),space(8),str(pos,7),'Position(en)',transform(summeRest,"@E 999,999.99")
  ? space(114),'----------------------------------------'
  ?
return zeile
  /** eof */

/* ermoeglicht das rekursive anzeigen von Auftragbest�nden am BS */
PROCEDURE zeigeLieferListe( ZeilenText , ZeigeData )
LOCAL mAufNr

  ignore ZeilenText

  mAufNr:=ZeigeData[ ZEIGE->(fieldPos("AufNr" )) ]

  if ! myEmpty( mAufNr )
    LieferLIste(,,"BS",mAufNr)
  endif

RETURN
/* EOP */



  /*
  * Auftragsposten je KW
  */
PROCEDURE LieferListe(von,bis,Ausgabe,mAufNr)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.,protName
LOCAL KLager:="N",Abruf:="N",kwMerk:="",kv:="N", offen:="J",failErledigt
LOCAL email:=.f., gges
LOCAL merkeZeige:=M->specialZeige, dauer

  default mAufNr:=space(5)

  Umgebung(WRITE_ALL)

  // KW: */10 -> Text drucken

  if ! open("Aufaus","Kunden","aufpost","Einheit","Artikel","Land","BesAus","M_Mehrf", "Auftrag",;
    "AvPost")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  cls
  titel("Lieferliste")

  /* Relation setzten */
  SELECT AufPost
  SET RELATION TO AUFPOST->ME INTO Einheit, AUFPOST->AufNr into AUFAUS, AUFPOST->ArtNr into Artikel
  select AufAus
  SET RELATION TO AUFAUS->kundnr INTO Kunden

  if valtype(von)=="U"
    if empty(mAufNr)
      von:="  /  "
      bis:="  /  "

      @ 6,20 say "Auf.Nr.       :" get mAufNr;
        valid { |oGet| empty(oGet:buffer) .or. check(oGet,"AufAus",.f.,.f.)}
      @ 8,20 say "Alternativ:"
      @ 9,18 to 18,46
      @ 10,20 say "KW von        :" get von picture "99/99" valid kwOkay( von ) .or. kwempty(von)
      @ 12,20 say "   bis        :" get bis picture "99/99" valid kwOkay( bis ) .or. kwempty(bis)
      @ 14,20 say "Mit Abruf     :" get Abruf picture "!" valid Abruf $"JN"
      @ 15,20 say "Mit KV        :" get kv picture "!" valid kv $"JN"
      @ 16,20 say "Mit K-Lager   :" get KLager picture "!" valid Klager $"JN"
      @ 17,20 say "Mit offenen AB:" get offen picture "!" valid offen $"JN"
      Message("Auswahl eingeben.        @Leer@=alle   @ESC@=Ende")

      Message("Auswahl eingeben.     @Leer@=alle   @ESC@=Ende")
      read
      if ABBRUCH
        Umgebung(LOAD)
        RETURN
      endif
    endif
  else
    email:=.t.
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b, NIL, NIL, .t. )} , "@F5@=aufl�sen" } )
  aadd( M->specialZeige , { chr(K_CTRL_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b, NIL, .t., .t. )} , "@F5@=aufl�sen" } )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  SELECT AufPost
  if empty(mAufNr)
    index on kwindex(AUFPOST->Kw)+AUFPOST->KundNr+AUFPOST->AufNr+AUFPOST->ArtNr;
      tag TEMP_IND4 TEMPORARY ADDITIVE
    dbseek(kwindex(von) , .t.)
  else
    index on kwindex(AUFPOST->Kw)+AUFPOST->KundNr+AUFPOST->AufNr+AUFPOST->ArtNr;
      tag TEMP_IND4 TEMPORARY ADDITIVE;
      for AUFPOST->AufNr==mAufNr
  endif

  if valtype(Ausgabe)=="U"
    if ! druck_BS() // Abbruch
      M->specialZeige:=merkeZeige
      Umgebung(LOAD)
      RETURN
    endif
  else
    Drucker(Ausgabe,,,,PDF_NO_CONFIRM)
  endif

  if offen=="J"
    failErledigt="J"
  else
    failErledigt="JO"
  endif

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.AUFPOST->(eof()).and. (KWempty(bis) .or.;
    kwKleiner(AUFPOST->KW,bis)>=0) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Miki Plastik GMBH  ***  Lieferliste  ***",space(32),"vom:",getUser():date,space(29),;
      "  Seite :",str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------------------------------------------'
    ? "KD-Nr.   Kurzname Kunde           AB-Nr. Datum   Art.Nr.   Bezeichnung                    "+;
      "ME     Bestell    bereits   Rest-   Lager-  Fert.- Lief."
    ? "                                                                                           "+;
      "        Menge     gelief.  Menge   Bestand Dauer  Datum"
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------------------------------------------'
    _____fixedHeader_____
    do while .not.AUFPOST->(eof()).and. (KWempty(bis) .or. kwKleiner(AUFPOST->KW,bis)>=0) .and. ! stop;
      .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand

      if empty(mAufNr)
        if AUFAUS->AufArt$"AGN" .or. AUFAUS->erledigt $ failErledigt .or. (KLager=="N".and.;
          AUFAUS->AufArt=="K") .or. (kv=="N" .and. AUFAUS->AufArt="V")
          skip
          loop
        endif
      endif

      if AUFAUS->erledigt="O"
        gges:=0
      else
        gges:=AUFPOST->GeliefGes
      endif

      if len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE .and. (AUFPOST->Menge > gges);
        .and. (Abruf=="J" .or. left(AUFPOST->KW,2)<>"X1")

        if kwMerk<>AUFPOST->KW
          kwMerk:=AUFPOST->KW
          ?
          ? "KW: "+kwMerk
          ? "========="
        endif

        dauer:=getArtikelFertigungsdauer(AUFPOST->Menge-gges)
        // if AUFAUS->AufNr=="27095"
        // altd()
        // endif

        ? AUFAUS->KundNr,left(KUNDEN->KurzName,24),ZEIGE_AUFNR+AUFAUS->AufNr,AUFAUS->AufDat,;
          ZEIGE_ARTNR+AUFPOST->ArtNr,;
          left(AUFPOST->Komm1,30),EINHEIT->Text,ZEIGE_MENGE+str(AUFPOST->Menge,10,2),gges,;
          str(AUFPOST->Menge-gges,7,0),ARTIKEL->LageBest,dauer,if(left(AUFPOST->KW,2)=="X1",;
          "Abruf",AUFPOST->KW)

        // drucke "Zollpapiere" bei Drittl�ndern
        LAND->(dbseek(left(AUFAUS->V_Land,2)))
        if ! LAND->EU $ "DJ"
          ?? COLOR_RED , "Zollpapiere" , COLOR_DEFAULT
          // drucke "offen" bei bereits berechneten
          if AUFAUS->erledigt=="O"
            ?? COLOR_RED , ", AB offen" , COLOR_DEFAULT
          endif
        else
          // drucke "offen" bei bereits berechneten
          if AUFAUS->erledigt=="O"
            ?? COLOR_RED , "AB offen" , COLOR_DEFAULT
          endif
        endif


        if ! empty(AUFPOST->KW_Text)
          ? space(70),trim(AUFPOST->KW_Text)
        endif
      endif
      skip
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  protName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if email
    email(MAIN_EMAIL,"LieferListe KW: "+von+" bis "+bis,"LieferListe KW: "+von+" bis "+;
      bis,protName,.f.,.t.)
  endif

  M->specialZeige:=merkeZeige
  Umgebung(LOAD)
RETURN
/* EOP Auftrags_Liste */


/* Druckt das Warenausgansbuch */
PROCEDURE WarAusList(Ausgabe,defaultArtNr)
LOCAL zeile,M_ArtNr,filterCond
LOCAL KopfText,Titel,Bauch,line,Bauch2,Bed2
LOCAL stop:=.f.,Seite:=0,Zeilen_Laenge
LOCAL GetList:={} , aDatei
MEMVAR beginn, ArtNrvon,ArtNrbis,d_von,d_bis,waraus_prog,buffer
PRIVATE beginn, ArtNrvon,ArtNrbis,d_von,d_bis,waraus_prog:="",buffer

  Umgebung(WRITE_ALL)

  if ! open( "Waraus","Artikel" )
    Error(TRY_AGAIN)
    cls
    Umgebung(LOAD)
    RETURN
  endif
  select Waraus
  // set relation to WARAUS->ArtNr into Artikel // ohne rela schneller
  WARAUS->(OrdSetFocus(0))
  go top
  M->beginn:=WARAUS->Datum
  WARAUS->(OrdSetFocus(1))

  KopfText:="A r t i k e l - B e w e g u n g"
  Titel:="Art.Nr.      Bezeichnung                    Bew.Dat.    Eingang    Ausgang   Bestand K-Bestand Kz Programm"
  Bauch:="{ OUT(WARAUS->ArtNr),WARAUS->Bez1,WARAUS->Datum,"+;
    "if(WARAUS->Menge>0,WARAUS->Menge,space(10)),"+;
    "if(WARAUS->Menge<0,WARAUS->Menge,space(10)),WARAUS->Best,WARAUS->KonsigBest,WARAUS->Mod_User,"+;
    "waraus2Zeige(WARAUS->Programm),if(empty(WARAUS->InLfdNr),'','Lfd.Nr. '+alltrim(WARAUS->InLfdNr)) }"

  Bauch2:="{ space(len(OUT(WARAUS->ArtNr))) , WARAUS->Bez2 }"
  Bed2:={ || ! empty(WARAUS->Bez2) }

  // Artikel vor-ausgew�hlt? z.B. aus Artikel-Stanmm
  if valtype(defaultArtNr)<>"U"
    Liste("Waraus",KopfText,Titel,Bauch,defaultArtnr,defaultArtnr,,defaultArtnr+;
      " Bewegungen",,Ausgabe, Bauch2,Bed2)
    Umgebung(LOAD)
    return
  endif

  set key K_F8 to copy_buffer("",oGet,"")

  M->ArtNrvon:=M->ArtNrbis:=space(len(ARTIKEL->ArtNr))
  M->d_von:=M->beginn
  M->d_bis:=getUser():date
  do while .t.
    cls
    titel(KopfText)
    @ 5,16 say "Ihre Auswahl:" color COLINV
    @ 6,14 to 18,68
    select Artikel
    M->waraus_prog:=left(M->waraus_prog+space(30),30)
    @ 8,16 say "Art.Nr. von:" get M->ArtNrvon picture "@K" ;
      valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)};
      when Message("1. Art.Nr eingeben.             @F12@=Hilfe")
    @ 10,16 say "        bis:" get M->ArtNrbis picture "@K" ;
      valid { |oGet| check(oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)};
      when Message("Letzte Art.Nr eingeben.         @F8@=kopieren    @F12@=Hilfe")


    @ 12,16 to 12,66
    @ 14,16 say "Datum von  :" get M->d_von valid { |oGet| warausDateCheck(oGet) } ;
      when Message("Start-Datum eingeben.       @*@=Heute @+@/@-@")
    @ 15,16 say "Datum bis  :" get M->d_bis ;
      when Message("End-Datum eingeben.       @*@=Heute @+@/@-@")
    @ 17,16 say "Text       :" get M->waraus_prog picture "@K";
      when Message("Filter Text eingeben.      @Leer@=alle   @F12@=Auswahl")
    read

    if ABBRUCH
      cls
      set key K_F8 to
      Umgebung(LOAD)
      RETURN
    endif

    if M->d_von>M->d_bis
      Error("Ung�ltiger Datumsbereich.",.t.)
      loop
    endif

    if Ausgabe=="BS"
      Drucker("BS",KopfText)
    else
      if ! druck_BS(KopfText) // Abbruch
        cls
        set key K_F8 to
        Umgebung(LOAD)
        RETURN
      endif
    endif

    if ABBRUCH
      cls
      set key K_F8 to
      Umgebung(LOAD)
      RETURN
    endif

    Message("Liste wird erstellt.  Bitte warten...")

    select Waraus
    // setzte Filter Datum,Text
    filterCond:=""
    if M->d_von >M->Beginn
      filterCond+=".and.WARAUS->Datum>=M->d_von"
    endif
    if M->d_bis <getUser():date
      filterCond+=".and.WARAUS->Datum<=M->d_bis"
    endif
    if ! empty(M->waraus_prog)
      M->Waraus_Prog:=trim(M->Waraus_Prog)
      filterCond+=".and.upper(M->waraus_prog)$upper(WARAUS->PROGRAMM)"
    endif

    // falls keine Filter ausser evtl. ArtNr. -> schnelle Variante
    if empty(filterCond)
      if empty(M->ArtNrbis)
        select Artikel
        go bottom
        M->ArtNrBis:=ARTIKEL->ArtNr
        select Waraus
      endif
      set relation to WARAUS->ArtNr into Artikel
      Liste("Waraus",KopfText,Titel,Bauch,M->ArtNrvon,M->ArtNrBis,,,,"NOP", Bauch2,Bed2)

      set key K_F8 to
      Umgebung(LOAD)
      return
    endif

    // keine Filter ausser evtl. ArtNr.
    if ! empty(M->ArtNrvon)
      filterCond+=".and.WARAUS->ArtNr>=M->ArtNrvon"
    endif
    if ! empty(M->ArtNrbis)
      filterCond+=".and.WARAUS->ArtNr<=M->ArtNrbis"
    endif

    // trim filter cond
    if left(filterCond,5)==".and."
      filterCond:=substr(filterCond,6)
    endif

    aDatei:=db_info("Waraus")
    index on &(aDatei[D_IND1]) tag TEMP_INDEX TEMPORARY ADDITIVE for &(filterCond) ;
      eval IndexProz("Bewegung") every lastrec()/20

    Message("Liste wird erstellt.  Bitte warten...       @ESC@=Abbruch")

    Zeilen_Laenge:=Max(len(KopfText)+3,len(Titel))
    line:=replicate(LINE_CHAR,Zeilen_Laenge)

    /* Ausdruck der Liste */
    Seite:=0
    stop:=.f.
    do while ! Waraus->(eof()) .and. ! stop
      Seite++
      zeile:=0
      ? KopfText+space(15)+"Seite: "+str(Seite,3)
      ? line
      ? Titel
      ? line
      _____fixedHeader_____

      /* Listen-Bauch */
      do while ! Waraus->(eof()) .and.zeile<DRUCKER->Laenge-LISTE->Unt_Rand .and. ! stop
        M_ArtNr:=Waraus->ArtNr

        getUser():getCurrentPrintJob():print( &(Bauch) , .t. )
        zeile++

        if eval( Bed2 )
          getUser():getCurrentPrintJob():print( &(Bauch2) , .t. )
          zeile++
        endif

        skip
        if Waraus->ArtNr<>M_ArtNr
          ?
          ARTIKEL->(dbseek(WARAUS->ArtNr))
        endif
        stop:=stop_key() // ESC gedr�ckt ?
      enddo

      ? line

      Zeile:=FormFeed(Zeile,Seite)

    enddo // Liste

    Drucker("Off")

  enddo
  cls
  set key K_F8 to
  Umgebung(LOAD)
RETURN
/* EOP */

static function warausDateCheck(oGet)
  if oGet:changed .and. ctod(oGet:buffer) < M->Beginn
    Error(ACHTUNG+"Bewegungen vor dem "+dtoc(M->Beginn)+" bitte in alter Bewegungsdatei anschauen.|"+;
      "         siehe Menu-Punkt 6.49.3",.t.)
    oGet:undo()
    return .f.
  endif
return .t.


  /* PROCEDURE StandortListe
  *
  */
PROCEDURE StandortListe
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL von:=" ", bis:=" ",alt
LOCAL line:=replicate("-",50)

  cls
  titel("Standort-Liste")

  if ! open("RepKund","Standort")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  // Message("Zeitraum eingeben.      @ESC@=Ende")
  select Standort
  bis:=von_bis("Standort")
  if ABBRUCH .or. STANDORT->(eof())
    close data
    clear
    RETURN
  endif

  if ! druck_BS() // Abbruch
    cls
    close data
    RETURN
  endif
  Message("Liste wird erstellt.   Bitte warten...")
  select RepKund
  index on REPKUND->Standort+REPKUND->RepKdNr tag TEMP_INDEX TEMPORARY ADDITIVE

  Stop:=stop_key()
  alt=STANDORT->StandNr
  set marg to 15
  REPKUND->(dbseek(STANDORT->StandNr))
  do while .not.STANDORT->(eof()) .and. ! Stop
    seite=seite+1
    zeile:=0
    ? "Kundenliste je Standort   vom:",getUser():date," Seite",str(seite,3)
    ? "Standort:",STANDORT->StandNr,STANDORT->Kurzbez
    ? line
    ? "Kund.Nr.   Name/Adresse"
    ? line
    do while .not.REPKUND->(eof()).and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop .and.;
      alt=REPKUND->Standort
      ? REPKUND->RepKdNr,REPKUND->Adr1,REPKUND->Standort
      ? space(len(REPKUND->RepKdNr)),REPKUND->Adr2
      ? space(len(REPKUND->RepKdNr)),REPKUND->Adr3
      ? space(len(REPKUND->RepKdNr)),REPKUND->Adr4
      ?
      skip
      Stop:=stop_key()
    enddo
    ? line
    if alt<>REPKUND->Standort
      STANDORT->(dbskip())
      REPKUND->(dbseek(STANDORT->StandNr))
      seite:=0
      alt=STANDORT->StandNr
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
  cls
  close data

RETURN
/* EOP Standort_Liste */


  /* druckt das Warenausgansbuch - Artikel pro Jahr
  *
  * Nimmt aus dem Waranausgangsbuch nur folgende Bewegungen:
  * - Fertig-Meldungen  (intern verwendet / Baugruppen)
  * - Rechnungen (extern verkauft) und KV
  *
  * Falls Ausgabe == "NOP z.B. bei crontab, berechnet er die verwendeten Artikel der
  * letzten 260 Wochen, berechnt den Mittelwert * 10 Wochen und schreibt das als
  * MindestBestand-Soll in den Artikel zur�ck.
  *
  */
PROCEDURE WarAusJahrList(Ausgabe,mArtNr,debugJahr, debugAlteVersion)
LOCAL zeile,gefertigt:=0,extern:=0,jahr,ges_extern:=0,ges_gefertigt:=0
LOCAL von,bis,stop:=.f.,Seite:=0,selArt:=" ",erst:=.t.,aktRec
LOCAL GetList:={} , erstBewegung, wochen, mindBestandMenge
LOCAL ZeitRaum:=val(getProperty("Miki.mindestbestand.zeitraum","260"))
LOCAL startDatum:=getUser():date - (zeitraum * 7)
LOCAL printBuffer:=printBuffer():new(), liFullName , i
LOCAL wasLocked

  default debugAlteVersion:=.f.

  Umgebung(WRITE_ALL)

  if ! open( "Waraus","Artikel","Einheit" )
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  Message("Berechne Mindestbestand.  Bitte warten...       @ESC@=Abbruch")

  select Waraus
  if AUSGABE == "NOP" // auto crontab
    index on WARAUS->ArtNr+dtos(WARAUS->Datum) tag TEMP_INDEX TEMPORARY ADDITIVE for;
      WARAUS->Datum >= startDatum
  else
    // Info: set filter scheint f�r 1 Artikel i.d.R. schneller zu sein
    set filter to WARAUS->Datum >= HIST_START_DATE
    // index on WARAUS->ArtNr+dtos(WARAUS->Datum) tag TEMP_INDEX TEMPORARY ADDITIVE for
    // WARAUS->Datum >= HIST_START_DATE
  endif

  // set filter to WARAUS->Datum >= ctod("30.03.21") // debug

  do while .t.
    cls
    titel("A r t i k e l - B e w e g u n g -- pro Jahr")
    extern:=0
    gefertigt:=0
    mindBestandMenge:=0
    stop:=.f.
    select Artikel

    if Ausgabe == "NOP" // auto crontab => alle Artikel
      if mArtNr == NIL
        go top
        von:=ARTIKEL->ArtNr
        go bottom
        bis:=ARTIKEL->ArtNr
      else
        von:=mArtNr
        bis:=mArtNr
      endif
      ARTIKEL->(dbseek( von ))

      Drucker(Ausgabe,"Artikel Bewegung/Jahr")
      // selArt:="E" // nur E-Artikel

    else

      /* Liste von bis */
      seite:=0; zeile:=0
      @ 4,0 clear
      if valtype(mArtNr)=="U"
        von:=bis:=space(len(ARTIKEL->ArtNr))
        bis:=von_bis("Artikel")
        if ABBRUCH
          Umgebung(LOAD)
          RETURN
        endif
        von:=ARTIKEL->ArtNr

        selArt:=" "
        @ 12,20 to 12,60
        @ 14,20 say "Artikel Art (BDEFMWX )             :" get selArt picture "!";
          valid selArt$"WBDEFMX " when Message("Artikel Art einschr�nken?   @Leer@=Alle")
        read

        if ABBRUCH .or. ! druck_BS(ARTIKEL->ArtNr+" Bewegung/Jahr") // Abbruch
          Umgebung(LOAD)
          RETURN
        endif
      else
        Drucker(Ausgabe,ARTIKEL->ArtNr+" Bewegung/Jahr")
        von:=bis:=mArtNr
        // if debugJahr <> nil
        ARTIKEL->(dbseek(mArtNr)) // wird bei debug gebraucht
        // endif
      endif

    endif // auto

    if empty(selArt)
      selArt:="WBDEFMX"
    endif

    aktRec:=ARTIKEL->(recno())
    select Artikel
    index on ARTIKEL->ArtNr tag TEMP_INDEX2 TEMPORARY ADDITIVE for getArtikelArt() $ selArt
    go (aktRec)

    Message("Liste wird erstellt.  Bitte warten...       @ESC@=Abbruch")

    do while ! stop .and. .not.ARTIKEL->(eof()).and. ARTIKEL->artnr<=bis
      seite=seite+1
      zeile:=0
      ? 'Ben�tigte Artikel pro Jahr                vom:',getUser():date,space(9),'Seite',;
        str(seite,3)
      ? 'Artikel von:',von,' bis:',bis
      ? '---------------------------------------------------------------------------'
      ? 'Art-Nr.    Art Bezeichn.  Jahr         Extern         Intern         Gesamt'
      ? '---------------------------------------------------------------------------'
      do while .not.ARTIKEL->(eof()).and. ARTIKEL->artnr<=bis .and.;
        zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        if erst

          WARAUS->(dbseek(ARTIKEL->ArtNr))
          jahr:=year(WARAUS->Datum)

          mindBestandMenge:=0
          ges_extern:=ges_gefertigt:=0
          erstBewegung:=NIL

          EINHEIT->(dbseek(ARTIKEL->ME))

          ?
          ? out(ARTIKEL->ArtNr),getArtikelArt(),ARTIKEL->Bez1
          if ! empty(ARTIKEL->Bez2)
            ? space(len(out(ARTIKEL->ArtNr))),space(len(getArtikelArt())),ARTIKEL->Bez2
          endif
          ? space(len(out(ARTIKEL->ArtNr))),space(len(getArtikelArt())),"Akt. Lager-Bestand:",;
            alltrim(transform(ARTIKEL->LageBest,"@E 999,999,999.99")),EINHEIT->Text
          ?

          if WARAUS->(eof())
            ? space(39),"*** Keine Bewegung ***"
            ARTIKEL->(dbskip())
            loop
          endif

          erst:=.f.
        endif

        // debug
        // if Ausgabe == "NOP"
        // @ 10,20 say ARTIKEL->ArtNr
        // @ 12,20 say WARAUS->(recno())
        // @ 13,20 say WARAUS->ArtNr
        // @ 13,40 say WARAUS->Datum
        // endif

        // merke Datum der 1. Bewegung
        if erstBewegung == nil .and. WARAUS->Datum >= startDatum
          erstBewegung:=WARAUS->Datum
        endif

        // seit 12.3.2014 ohne Fertig.Meldung
        // Gutschrift bei extern kann ignoriert werden, laut H. Weiland
        // elseif WARAUS_MATAUSG2 $ WARAUS->Programm .or. WARAUS_INNERNR $ WARAUS->Programm
        // .or. WARAUS_FERTIGMELD_ALT $ WARAUS->Programm .or. WARAUS_AUSGANG_ALT $ WARAUS->Programm

        // extern verkauft
        if left(WARAUS_RECHNR,5) $ WARAUS->Programm .or.;
          left(WARAUS_RECHNR_STORNO,5) $ WARAUS->Programm .or. left(WARAUS_KVNR,5) $ WARAUS->Programm
          extern+=WARAUS->Menge
          if debugJahr <> nil
            ? "extern:",WARAUS->Datum,WARAUS->Programm,WARAUS->Menge
          endif

          // summiere relevante Menge f�r Mindestbestandsberechnung
          if WARAUS->Datum >= startDatum
            mindBestandMenge += WARAUS->Menge
          endif

          // intern verwendet, z.B. Baugruppe
        elseif alltrim(WARAUS_INNERNR) $ WARAUS->Programm .or.;
          WARAUS_FERTIGMELD_ALT $ WARAUS->Programm .or.;
          WARAUS_BESTNR $ WARAUS->Programm // Neu seit 20180912
          if isWarausBuchung(debugAlteVersion)
            gefertigt+=WARAUS->Menge
            if debugJahr <> nil
              ? "intern",WARAUS->Datum,WARAUS->Programm,WARAUS->Menge
            endif

            // summiere relevante Menge f�r Mindestbestandsberechnung
            if WARAUS->Datum >= startDatum
              mindBestandMenge += WARAUS->Menge
            endif
          endif
        endif

        WARAUS->(dbskip())

        if (year(WARAUS->Datum)<>Jahr .or. WARAUS->(eof()) .or. ARTIKEL->ArtNr<>WARAUS->ArtNr)

          // dieses Jahr noch drucken?
          if (gefertigt <> 0 .or. extern <> 0)
            ? space(25),str(jahr,4),transform(myabs(extern),"@E 999,999,999.99"),;
              transform(myabs(gefertigt),"@E 999,999,999.99"),;
              transform(myabs(gefertigt) + myabs(extern),"@E 999,999,999.99")
          endif

          jahr:=year(WARAUS->Datum)
          ges_extern+=myabs(extern)
          ges_gefertigt+=myabs(gefertigt)
          extern:=gefertigt:=0

          // if trim(ARTIKEL->artnr)="50052078"
          // altd()
          // endif

          // neuer Artikel?
          if WARAUS->(eof()) .or. ARTIKEL->ArtNr <> WARAUS->ArtNr
            erst:=.t.

            // Ende = Gesamtsumme des Artikels
            ? space(34),"========================================"
            ? space(23),"Gesamt:"+transform(myabs(ges_extern),"@E 999,999,999.99"),;
              transform(myabs(ges_gefertigt),"@E 999,999,999.99"),;
              transform(myabs(ges_gefertigt) + myabs(ges_extern) ,"@E 999,999,999.99")

            // bei auto Soll Mindest.Bestand r�ckschreiben nach Artikel
            // if debugJahr <> nil .or. Ausgabe == "NOP"
            ?
            ? "Berechnung Artikel Mindest-Bestand:"
            ? "==================================="
            if erstBewegung == nil
              ? "Artikel ohne Bewegung in den letzten "+str(zeitraum,4)+" Wochen"
            else
              mindBestandMenge:=abs( mindBestandMenge )
              wochen:=max(round( (getUser():date - erstBewegung) / 7 , 0), getNumWeeks())
              ? "1. relevante Bewegung am",erstBewegung
              ? "Anzahl Wochen    :",str(wochen,8)
              if wochen > Zeitraum
                wochen:=zeitraum
                ?? "=>",wochen
              endif
              ? "Bedarf gesamt    :",transstr(mindBestandMenge,11,2)
              wasLocked:=isLocked()
              if rec_lock(5)
                if wochen = 0 // bei neuen Artikeln kann noch keine Aussage getroffen werden
                  replace ARTIKEL->MinBestS with 0
                else
                  ? "Bedarf pro Woche :",transstr(mindBestandMenge / wochen,11,2)
                  ? "Bedarf pro Jahr  :",transstr(mindBestandMenge / wochen * 52,11,2)
                  ? "Mind.Bestand Soll:    x",ARTIKEL->MinPuffer,"=>", ;
                    transstr(( mindBestandMenge / wochen ) * ARTIKEL->MinPuffer,11,2), EINHEIT->Text
                  ?
                  ? "Alternativ       :   "
                  for i:=6 to 12 step 2
                    if i<> ARTIKEL->MinPuffer
                      ?? "x"+str(i,3)+" =>", transstr(( mindBestandMenge / wochen ) * i ,11,2)
                      ? space(21)
                    endif
                  next

                  if ! debugAlteVersion
                    replace ARTIKEL->MinBestS with ;
                      round( ( mindBestandMenge / wochen ) * ARTIKEL->MinPuffer , 2 )
                  endif

                  // pr�fe bei crontab job ob Abweichung zu Soll/Ist -> LIste f. H. Weiland
                  //if ARTIKEL->MinBestI > 0 .and. abs(100 - abs(ARTIKEL->MinBestS / ARTIKEL->MinBestI) * 100) > 10
                  if ARTIKEL->MinBestI > 0 .and. ARTIKEL->MinBestS > ARTIKEL->MinBestI // 20221010
                    ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,ARTIKEL->MinBestS,ARTIKEL->MinBestI,;
                      ARTIKEL->MinBestI - ARTIKEL->MinBestS,;
                      trim(str(100-abs(ARTIKEL->MinBestS / ARTIKEL->MinBestI) * 100))+"%"
                  endif
                endif
                dbcommit()
                if ! wasLocked
                  dbunlock()
                endif
              endif
            endif

            // n�chster Artikel
            ARTIKEL->(dbskip())
          endif
        endif

        Stop=Stop_Key()
      enddo

      if Ausgabe <> "NOP"
        Zeile:=FormFeed(Zeile,Seite)
      endif
    enddo

    if debugJahr <> nil
      M->specialZeige:=nil
    else
      M->specialZeige:={ { chr(K_F5)+chr(K_LDBLCLK) , { || WarAusJahrList(Ausgabe,mArtNr,.t.)} ,;
        " @F5@=Details anzeigen " } }
    endif

    Drucker("Off")

    M->specialZeige:=nil

    // Info Email an H. Weiland falls Crontab Job
    if Ausgabe == "NOP" .and. printBuffer:getNumLines() > 0
      Drucker("PDF","MindestBestandsListeSollIst")
      printBuffer:insertTextLine( 1,"Abweichung Artikel Mindest-Bestand Soll/Ist"+space(8)+;
        "vom: "+dtoc(getUser():date))
      printBuffer:insertTextLine( 2, replicate("=",65))
      printBuffer:insertTextLine( 3, "Art.Nr.   Bezeichung                       Soll    Ist  "+;
        "Differenz")
      printBuffer:insertTextLine( 4, replicate("=",65))

      getUser():getCurrentPrintJob():printBuffer(printBuffer)
      getUser():getCurrentPrintJob():endDoc()
      liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
      email(MAIN_EMAIL,"Artikel Mindest-Bestands-Liste Soll/Ist Abweichung vom: "+dtoc(getUser():date),;
        "Bitte pr�fen", liFullName)
      getUser():setCurrentPrintJob(NIL)
    endif

    // Endlosschleife nur bei manueller Auswahl aus Men�-Liste
    if valtype(mArtNr)<>"U" .or. AUSGABE=="NOP"
      exit
    endif
  enddo

  Umgebung(LOAD)
RETURN
  /* EOP */

/* Pr�ft ob Bewegung f�r Artikel Bewegung pro Jahr relevant ist */
static function isWarausBuchung(alt)
LOCAL Zeile:=0

  if WARAUS->Menge < 0 // nur wenn Artikel intern verwendet werden!!!
    return .t.
  endif

  // pr�fe "alte" Minus-Fertigmeldung mit minus
  // Buchung Unterartikel
  if len(HB_RegEx("^"+alltrim(WARAUS_INNERNR)+".*->",trim(WARAUS->Programm))) > 0
    if alt // Temp. for debugging
      ? "Ignoriert:",WARAUS->Datum,WARAUS->Menge,WARAUS->Programm
    else
      return .t.
    endif
  endif

  // pr�fe "neue" Storno-Fertigmeldung mit minus
  if len(HB_RegEx("^"+alltrim(WARAUS_INNERNR)+".*"+WARAUS_STORNO,trim(WARAUS->Programm))) > 0
    return .t.
  endif

return .f.
/** eof */

static function myabs(x)
return abs( x )
/** eof */

  /* PROCEDURE WarausExternKLager
  *
  */
PROCEDURE WarAusExternKlager
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL von:=" ", bis:=" ", ersteKBeweg:=.f.,aktArtikel
LOCAL line:=replicate("-",102)
LOCAL lastK:=-9999999,lastM:=-9999999,ausw

  cls
  titel("K-Lager Bewegungs-Liste extern")

  if ! open("WarAus","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  select Artikel
  set filter to .not. empty(ARTIKEL->KonsigKdNr) .and. getArtikelArt()<>"B"

  do while .t.

    ersteKBeweg:=.f.
    seite:=0
    @ 2,0 clear

    bis:=von_bis("Artikel")
    if ABBRUCH .or. ARTIKEL->(eof())
      close data
      clear
      RETURN
    endif

    @ 12,19 to 17,50
    @ 13,22 say "Ihre Auswahl:"
    @ 14,22 Prompt "1. K-Lager Bewegungen   "
    @ 15,22 Prompt "2. Miki-Lager Bewegungen"
    @ 16,22 Prompt "3. Alle                 "
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw

    if ABBRUCH .or. ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif
    Message("Liste wird erstellt.   Bitte warten...")
    select WarAus
    WARAUS->(dbseek(ARTIKEL->ArtNr))
    aktArtikel:=ARTIKEL->ArtNr

    Stop:=stop_key()
    do while .not.WARAUS->(eof()) .and. ! Stop .and. left(WARAUS->ArtNr,len(bis))<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? "K-Lager extern Bewegungsliste                   vom:",getUser():date,space(30),"Seite",;
        str(seite,3)
      ? line
      ? "Art.Nr.   Bezeichnung                    Bew.Dat.   Eingang    Ausgang  Bestand  "+;
        "K-Bestand Kz Programm"
      ? line
      do while .not.WARAUS->(eof()) .and. ! Stop .and. ;
        left(WARAUS->ArtNr,len(bis))<=bis .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand

        // neuer Artikel
        if aktArtikel<>WARAUS->ArtNr
          ersteKBeweg:=.f.
          lastK:=-999999
          lastM:=-999999

          ?
          ARTIKEL->(dbskip()) // N�chster Artikel aus Filter
          aktArtikel:=ARTIKEL->ArtNr
          WARAUS->(dbseek(aktArtikel))
          if WARAUS->(eof()) .or. left(WARAUS->ArtNr,len(bis))>bis
            loop
          endif
        endif

        // erste K_Lager Bewegung?
        if !ersteKBeweg .and. WARAUS->KonsigBest<>0
          ersteKBeweg:=.t.
        endif

        if aktArtikel==WARAUS->ArtNr .and. ersteKBeweg
          if ausw==3 .or. ;
            (ausw=1 .and. lastK<>WARAUS->KonsigBest) .or. ;
            (ausw=2 .and. lastM<>WARAUS->Best)
            ? OUT(WARAUS->ArtNr),ARTIKEL->Bez1,WARAUS->Datum,;
              if(WARAUS->Menge>0,WARAUS->Menge,space(9)),;
              if(WARAUS->Menge<0,WARAUS->Menge,space(9)),WARAUS->Best,WARAUS->KonsigBest,;
              WARAUS->Mod_User,WARAUS->Programm
          endif

        endif
        lastK:=WARAUS->KonsigBest
        lastM:=WARAUS->Best
        skip

        Stop:=stop_key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

  enddo

  cls
  close data

RETURN
  /* EOP WarausKLager */

  /* PROCEDURE WarausInternKLager
  *
  */
PROCEDURE WarAusInternKlager
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL von:=" ", bis:=" ", aktArtikel,ersteKBeweg:=.f.
LOCAL line:=replicate("-",102)
LOCAL lastK:=-9999999,lastM:=-9999999,ausw

  cls
  titel("K-Lager Bewegungs-Liste intern")

  if ! open("WarAus","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  select Artikel
  set filter to .not. empty(ARTIKEL->KonsigKdNr) .and. getArtikelArt()=="B"

  do while .t.

    @ 08,19 clear to 11,78
    bis:=von_bis("Artikel")
    if ABBRUCH .or. ARTIKEL->(eof())
      close data
      clear
      RETURN
    endif

    @ 12,19 to 17,50
    @ 13,22 say "Ihre Auswahl:"
    @ 14,22 Prompt "1. K-Lager Bewegungen   "
    @ 15,22 Prompt "2. Miki-Lager Bewegungen"
    @ 16,22 Prompt "3. Alle                 "
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw

    if ABBRUCH .or. ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif

    Message("Liste wird erstellt.   Bitte warten...")
    select WarAus
    WARAUS->(dbseek(ARTIKEL->ArtNr))
    aktArtikel:=ARTIKEL->ArtNr

    Stop:=stop_key()
    do while .not.WARAUS->(eof()) .and. ! Stop .and. left(WARAUS->ArtNr,len(bis))<=bis
      seite=seite+1
      zeile:=0
      ? "K-Lager intern Bewegungsliste                   vom:",getUser():date,space(30),"Seite",;
        str(seite,3)
      ? line
      ? "Art.Nr.   Bezeichnung                    Bew.Dat.   Eingang    Ausgang  Bestand  "+;
        "K-Bestand Kz Programm"
      ? line
      do while .not.WARAUS->(eof()) .and. ! Stop .and. ;
        left(WARAUS->ArtNr,len(bis))<=bis .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand

        // neuer Artikel
        if aktArtikel<>WARAUS->ArtNr
          ersteKBeweg:=.f.
          lastK:=-999999
          lastM:=-999999
          ?
          ARTIKEL->(dbskip()) // N�chster Artikel aus Filter
          aktArtikel:=ARTIKEL->ArtNr
          WARAUS->(dbseek(aktArtikel))
          if WARAUS->(eof()) .or. left(WARAUS->ArtNr,len(bis))>bis
            loop
          endif
        endif

        // erste K_Lager Bewegung?
        if !ersteKBeweg .and. WARAUS->KonsigBest<>0
          ersteKBeweg:=.t.
        endif

        if aktArtikel==WARAUS->ArtNr .and. ersteKBeweg
          if ausw==3 .or. ;
            (ausw=1 .and. lastK<>WARAUS->KonsigBest) .or. ;
            (ausw=2 .and. lastM<>WARAUS->Best)
            // // .and. ! "Mat.Ausg" $ WARAUS->Programm .and. ! "Fertig.Meld" $ WARAUS->Programm .and.
            // // ! "Artikel-Stamm" $ WARAUS->Programm
            ? OUT(WARAUS->ArtNr),ARTIKEL->Bez1,WARAUS->Datum,;
              if(WARAUS->Menge>0,WARAUS->Menge,space(9)),;
              if(WARAUS->Menge<0,WARAUS->Menge,space(9)),WARAUS->Best,WARAUS->KonsigBest,;
              WARAUS->Mod_User,WARAUS->Programm
          endif
        endif
        lastK:=WARAUS->KonsigBest
        lastM:=WARAUS->Best

        skip
        Stop:=stop_key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo
  cls
  close data

RETURN
  /* EOP WarausKLager */

  /*
  * K-Lager Artikel je Kunde
  */
PROCEDURE KKundArtikelListe(auswahl, kdnr, auto)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.,ausw,export, preset:=.f.
LOCAL bis,von,aktKdNr,gespos:=0
LOCAL realFileName, printBuffer, tempFilter, filtercond

  default auto:=.f.

  if !;
    open("Artikel","Kunden","Einheit","KundSped","AvPost","AufAus","AufPost","Auftrag","M_Mehrf","BesAus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("K-Lager Artikel je Kunde")

  /* Relation setzten */
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit
  AVPOST->(ordSetFocus(1)) // AvNr + ArtNr

  do while .t.
    if Auswahl == NIL
      @ 2,0 clear

      bis:=von_bis("Kunden")
      if empty(bis)
        cls
        close data
        RETURN
      endif
      von:=trim(KUNDEN->KundNr)

      @ 2,0 clear
      @ 6,12 to 14,70
      @ 7,15 say "Ihre Auswahl:"
      @ 9,15 Prompt "1. Interne Beistellteile   (K-Lager Bestand)         "
      @ 10,15 Prompt "2. Interne Beistellteile   (K-Lager Inventur Bestand)"
      @ 11,15 Prompt "3. Externe K-Lager Artikel (K-Lager Bestand)         "
      @ 12,15 Prompt "4. Externe K-Lager Artikel (K-Lager Inventur Bestand)"

      @ 16,14 say "Hinweis: Excel-Liste ist mit Kalk.Preis bzw. EK"

      Message("Ihre Auswahl bitte.                  @ESC@=Ende")
      Menu to Ausw

      if ABBRUCH
        exit
      endif

      export:=Druck_Bs("Honsel",.t.,.t.) // Abbruch
      if valtype(export)=="L" .and. ! export
        exit
      endif
    else
      preset:=.t.
      ausw = Auswahl
      von:=bis:=kdnr
      if auto
        Drucker("PDF","KLager-Liste",,.f.,PDF_NO_CONFIRM)
      else
        export:=Druck_Bs("Honsel",.t.,.t.) // Abbruch
        if valtype(export)=="L" .and. ! export
          exit
        endif
      endif
    endif

    Message("Datei wird sortiert.   Bitte warten...")

    /** Spezial Funktion Zeige freischalten */
    M->specialZeige:={}
    aadd( M->specialZeige , { chr(K_F5)+;
      chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
    aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
    aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

    SELECT Artikel
    if Ausw==1 .or. Ausw==2
      // interne K-Lager
      set filter to getArtikelArt()=="B" .and. substr(ARTIKEL->KonsigKdnr,1,len(von))>=von ;
        .and. ARTIKEL->KonsigKdnr<=bis
    else
      // externe K-Lager
      filtercond:="getArtikelArt()<>'B' .and. substr(ARTIKEL->KonsigKdnr,1,"+trim(str(len(trim(von))))+")>='"+trim(von)+"' " +;
        ".and. ARTIKEL->KonsigKdnr<='"+bis+"' .and. len(alltrim(ARTIKEL->KonsigKdnr))>4"
      set filter to &(filterCond)
    endif

    index on ARTIKEL->KonsigKDnr+ARTIKEL->Artnr tag TEMP_INDEX TEMPORARY ADDITIVE
    go top

    if valtype(export)=="C" // Excel
      if ausw=1 .or. ausw=3
        exportInvDatei(.t.,export)
      else
        exportInvDatei(.f.,export)
      endif
    else

      Message("Liste wird erstellt.  Bitte warten....")
      printBuffer:=printBuffer():new()
      do while .not.ARTIKEL->(eof()).and. ARTIKEL->KonsigKdNr<=bis.and. ! stop
        aktKdNr:=ARTIKEL->KonsigKdNr
        KUNDEN->(dbseek(aktKdNr))
        seite=seite+1
        zeile:=0
        ->? "***  Miki Plastik GmbH  ***   K-Lager Artikel je Kunde  *** "
        if ausw=1 .or. ausw=2
          ->? 'Interne Beistellteile              '," ",getUser():date,"  Seite:",str(seite,3)
          ->? 'Kunde:',aktKdNr,KUNDEN->Kurzname
          ->? '------------------------------------------------------------'
          ->? "Art.Nr.    Bezeichnung               K-Lager Bestand Einheit"
        else
          ->? 'K-Lager Artikel                    '," ",getUser():date,"  Seite:",str(seite,3)
          ->? 'Kunde:',aktKdNr,KUNDEN->Kurzname
          ->? '------------------------------------------------------------'
          ->? "Art.Nr.    Bezeichnung                "
          if ausw=1
            ->?? "        Bestand   ME Honsel-Nr               (Min/Max)"
          elseif ausw=3
            ->?? "        Bestand   ME    (Min/Max)   Oberartikel     Lager  AB Best."
          else
            ->?? "K.Inv. Bestand   ME Honsel-Nr               (Min/Max)"
          endif
        endif
        ->? '------------------------------------------------------------'
        do while .not.ARTIKEL->(eof()).and. ARTIKEL->KonsigKdNr<=bis.and. ! stop ;
          .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. aktKdNr=ARTIKEL->KonsigKdNr
          ->? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(0)
          if ausw=1 .or. ausw=3
            ->?? ZEIGE_MENGE+str(ARTIKEL->KonsigBest,9,2),space(0)
          else
            ->?? ZEIGE_MENGE+str(ARTIKEL->KonsigInv,9,2),space(0)
          endif
          ->?? EINHEIT->Text
          if .not. ausw==3
            ->?? ARTIKEL->Hartnr
          endif
          if ausw=1 .or. ausw=3
            ->?? space(3),;
              left("("+alltrim(str(ARTIKEL->KonsigMind,9))+"/"+alltrim(str(ARTIKEL->KonsigMax,9))+;
              ")"+space(10),10)

            if preset .and. left(ARTIKEL->ArtNr,3)=="503"
              Umgebung(WRITE_ALL)
              AVPOST->(dbseek(ARTIKEL->ArtNr))
              if ! AVPOST->(eof())
                tempFilter:=ARTIKEL->(dbfilter())
                dbClearFilter()
                ARTIKEL->(OrdSetFocus(1)) // ArtNr
                ARTIKEL->(dbseek(AVPOST->ArtNr))
                ->?? out(ARTIKEL->ArtNr)+":", str(ARTIKEL->LageBest,9,2)+str(ARTIKEL->Disponiert,9,2),;
                  EINHEIT->Text
                ARTIKEL->(OrdSetFocus(TEMP_INDEX))
              endif
              Umgebung(LOAD)
            endif
          endif
          if len(trim(ARTIKEL->Bez2))>0
            ->? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
          endif
          gespos++
          skip
          Stop:=stop_key()
          if aktKdNr<>ARTIKEL->KonsigKdNr .or. eof() .or. ARTIKEL->KonsigKdNr>bis
            ->? '=========================================================='
            ->? space(35),str(gespos,4),'Position(en)'
            ->? '=========================================================='
            seite:=0
            gespos:=0
          endif
        enddo
        getUser():getCurrentPrintJob():printBuffer(printBuffer)
        Zeile:=FormFeed(Zeile,Seite)
      enddo

      //Drucker("OFF")
      getUser():getCurrentPrintJob():endDoc()

      if auto
        realFileName:=getUser():getCurrentPrintJob():pdfFullFileName
        getUser():setCurrentPrintJob(NIL)
        email(MAIN_EMAIL,"K-Lager-Liste Kunde:"+kdnr+" vom "+;
          dtoc(getUser():date),printBuffer:getPlainText("|"), realFileName)
        exit
      endif

    endif // valtype export

    if preset
      exit
    endif

  enddo
  cls
  close data
  M->specialZeige:=NIL
RETURN
  /* EOP Auftrags_Liste */

  /** exportiert Artikel Datei
  *
  * Paramter: KBestand:  .t. = KonsigBest
  *                      .f. = KonsigInv
  */
Function exportInvDatei(KBestand,exportName)
LOCAL GetList:={}
LOCAL s01:=savescreen()
LOCAL aktSel:=alias()
LOCAL excel, objErr, export , aFields , oCol

  default exportName:="NoName"

  Message("Datei wird erstellt.  Bitte warten.")
  select Artikel
  go top

  if mkMyDir(getUser():exportPATH())
    BEGIN SEQUENCE // krit. Bereich
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(exportName)
      excel:=ExcelExport():new()

      aFields:={ "KonsigKdNr","ArtNr","Bez1","Bez2"}
      excel:addColumnsByName( aFields )

      // jetzt den Einzel-Wert
      oCol:=ExcelColumn():new()
      oCol:title:="Einzel-Wert"
      oCol:Codeblock:=;
        { || if(getArtikelArt()$"FM",if(ARTIKEL->Schluessel=="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr),;
        if(ARTIKEL->Schluessel=="H",ARTIKEL->EkPr/100,ARTIKEL->EkPr))}
      oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
      excel:addColumn(oCol)

      if KBestand

        aFields:={ "KonsigBest"}
        excel:addColumnsByName( aFields )

        // jetzt den Gesamt-Wert
        oCol:=ExcelColumn():new()
        oCol:title:="Gesamt-Wert"
        oCol:Codeblock:={ || ARTIKEL->KonsigBest * ;
          if(getArtikelArt()$"FM",if(ARTIKEL->Schluessel=="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr),;
          if(ARTIKEL->Schluessel=="H",ARTIKEL->EkPr/100,ARTIKEL->EkPr))}
        oCol:Sum:=.t.
        oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
        excel:addColumn(oCol)

      else
        aFields:={ "KonsigInv"}
        excel:addColumnsByName( aFields )

        // jetzt den Gesamt-Wert
        oCol:=ExcelColumn():new()
        oCol:title:="Gesamt-Wert"
        oCol:Codeblock:={ || ARTIKEL->KonsigInv * ;
          if(getArtikelArt()$"FM",if(ARTIKEL->Schluessel=="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr),;
          if(ARTIKEL->Schluessel=="H",ARTIKEL->EkPr/100,ARTIKEL->EkPr))}
        oCol:Sum:=.t.
        oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
        excel:addColumn(oCol)

      endif


      // jetzt restl. gemeinsame Spalten hinzuf�gen
      aFields:={ "Hartnr","EINHEIT->Text" }
      excel:addColumnsByName( aFields )

      excel:export(.f.,.f.,export)
      Message(export+" wurde erzeugt.  @Taste@","@")
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
  endif
  restscreen(,,,,s01)
return .t.
  /** EOF */

  /*
  * Generiert PDF mit den neg. LageBest von heute uns schickt Ergebnis per Email an Miki
  */
PROCEDURE NegLageNeu()
LOCAL seite:=0, zeile:=0,i,liFullName
LOCAL Stop:=.f.,m_artNr,treffer:={},lastBest,lastDatum,count:=0

  Drucker("PDF")

  if ! open("Waraus","Artikel")
    close data
    cls
    return
  endif

  Message("Liste wird erstellt.   Bitte warten...")

  // nur vom letzten/aktuellen Datum
  select Waraus
  WARAUS->(OrdSetFocus(0))
  go bottom
  lastDatum:=WARAUS->Datum

  index on WARAUS->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for WARAUS->Datum==lastDatum
  set relation to WARAUS->ArtNr into Artikel
  go top
  do while .not. WARAUS->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Negativer Lagerbestand vom:',getUser():date,space(30),'Seite',str(seite,3)
    ? "Art.Nr.    Bezeichnung                    Bew.Dat.    Eingang    Ausgang   Bestand "+;
      "K-Bestand Kz Programm"
    ? '------------------------------------------------------------------------------------------'+;
      '------------------------------'
    do while .not. WARAUS->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      M_ArtNr:=WARAUS->ArtNr
      do while .not. WARAUS->(eof()) .and. M_ArtNr==WARAUS->ArtNr
        aadd(treffer,OUT(WARAUS->ArtNr)+" "+ARTIKEL->Bez1+" "+dtoc(WARAUS->Datum);
          +" "+if(WARAUS->Menge>0,str(WARAUS->Menge,10,2),space(10));
          +" "+if(WARAUS->Menge<0,str(WARAUS->Menge,10,2),space(10));
          +" "+str(WARAUS->Best,9,2)+" "+str(WARAUS->KonsigBest,9,2);
          +" "+WARAUS->Mod_User+" "+WARAUS->Programm)
        lastBest:=WARAUS->Best
        skip
      enddo

      if lastBest<0
        count++
        for i:=1 to len(treffer)
          ? treffer[i]
        next
        ?
      endif
      treffer:={}

      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '------------------------------'

    // if .not. WARAUS->(eof())
    Zeile:=FormFeed(Zeile,Seite)
    // else
    // ?
    // ?
    // endif
  enddo // eof()

  getUser():getCurrentPrintJob():endDoc()
  liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if count > 0
    email(MAIN_EMAIL,"Neg. Lagerbestand vom: "+dtoc(getUser():date),;
      "Neg. Lagerbestand vom: "+dtoc(getUser():date),liFullName)
  endif

  close data


RETURN
  /* EOP */


  /**
  *  druckt alle Artikel mit gleicher Mat.Kz aus
  */
PROCEDURE MatKzListe(M_MatKz)
LOCAL seite:=0,zeile:=0,Stop:=.f.
LOCAL merkKz:="."


  if ! open("Artikel","Mat_KZ")
    cls
    close data
    RETURN
  endif

  if empty(M_MatKz)

    cls
    titel("Artikel-Liste ident. Mat.Kz")


    if ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif

    Message("Liste wird erstellt.    Bitte warten...")
    select Artikel
    index on ARTIKEL->MatKz tag TEMP_INDEX TEMPORARY ADDITIVE
    dbseek( next(space(len(ARTIKEL->MatKz))) ,.t. )

  else
    Umgebung(WRITE)
    Drucker("BS")
    Message("Liste wird erstellt.    Bitte warten...")
    select Artikel
    index on ARTIKEL->MatKz tag TEMP_INDEX TEMPORARY ADDITIVE for ARTIKEL->MatKz==M_MatKz
    go top
  endif

  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    if empty(M_MatKz)
      ? 'Artikel mit identischer Material-Kennziffer   vom:',getUser():date,space(2),'Seite',;
        str(seite,3)
    endif
    ? '------------------------------------------------------------------------'
    ? 'Art.Nr.    Bezeichnung                 Mat.Kz '
    if ! empty(M_MatKz)
      ? '------------------------------------------------------------------------'
    endif

    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      if empty(M_MatKz) .and. ARTIKEL->MatKz <> MerkKz
        ? '------------------------------------------------------------------------'
        MerkKz:=ARTIKEL->MatKz
        MAT_KZ->(dbseek(merkKZ))
        aEval(HB_ATokens( MAT_KZ->MkzText , MY_CR+MY_LF),;
          { |x| getUser():getCurrentPrintJob():print({space(len(out(ARTIKEL->ArtNr))),x},.t.),zeile++,.t. })
        ?
      endif

      ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->MatKz
      if ! empty(ARTIKEL->Bez2)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop=Stop_Key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Drucker('OFF')
  if empty(M_MatKz)
    cls
    close data
  else
    Umgebung(LOAD)
  endif
RETURN
/* EOP */

  /**
  *  druckt alle Artikel mit gleicher ArtikelTextNr aus
  */
PROCEDURE ArtTextListe(M_ArtTextNr)
LOCAL seite:=0,zeile:=0,Stop:=.f.
LOCAL merkKz:="."


  if ! open("Artikel","ArtText")
    cls
    close data
    RETURN
  endif

  if empty(M_ArtTextNr)

    cls
    titel("Artikel-Liste ident. Artikel TextNr.")


    if ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif

    Message("Liste wird erstellt.    Bitte warten...")
    select Artikel
    index on ARTIKEL->ArtTextNr tag TEMP_INDEX TEMPORARY ADDITIVE
    dbseek( next(space(len(ARTIKEL->ArtTextNr))) ,.t. )

  else
    Umgebung(WRITE)
    Drucker("BS")
    Message("Liste wird erstellt.    Bitte warten...")
    select Artikel
    index on ARTIKEL->ArtTextNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      ARTIKEL->ArtTextNr==M_ArtTextNr
    go top
  endif

  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    if empty(M_ArtTextNr)
      ? 'Artikel mit identischer Artikel-Textnr.   vom:',getUser():date,space(2),'Seite',;
        str(seite,3)
    endif
    ? '------------------------------------------------------------------------'
    ? 'Art.Nr.    Bezeichnung                    Nr'
    if ! empty(M_ArtTextNr)
      ? '------------------------------------------------------------------------'
    endif

    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      if empty(M_ArtTextNr) .and. ARTIKEL->ArtTextNr <> MerkKz
        ? '------------------------------------------------------------------------'
        MerkKz:=ARTIKEL->ArtTextNr
        ARTTEXT->(dbseek(merkKZ))
        aEval(HB_ATokens( ARTTEXT->Text , MY_CR+MY_LF),;
          { |x| getUser():getCurrentPrintJob():print({space(len(out(ARTIKEL->ArtNr))),x},.t.),zeile++,.t. })
        ?
      endif

      ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->ArtTextNr
      if ! empty(ARTIKEL->Bez2)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop=Stop_Key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Drucker('OFF')
  if empty(M_ArtTextNr)
    cls
    close data
  else
    Umgebung(LOAD)
  endif
RETURN
/* EOP */


  /**
  *  druckt alle Maschinen einer Maschinengruppe aus
  */
PROCEDURE MaschGrListe(MaschGr)
LOCAL seite:=0,zeile:=0,Stop:=.f.

  Umgebung(WRITE_ALL)

  if ! open("Maschine")
    cls
    close data
    RETURN
  endif

  Drucker("BS")
  Message("Liste wird erstellt.    Bitte warten...")
  select Maschine
  index on MASCHINE->StdNr tag TEMP_INDEX TEMPORARY ADDITIVE for MASCHINE->MaschGr == MaschGR
  go top

  do while .not. MASCHINE->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Maschinen in Maschinengruppe: ' +MaschGr+'     vom:',getUser():date,space(2),'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------'
    ? 'Masch.Nr.  Bezeichnung'
    ? '------------------------------------------------------------------------'

    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      ? MASCHINE->StdNr,space(6),MASCHINE->Bez
      if MASCHINE->Art == "X"
        ?? "verschrottet"
      endif
      skip
      Stop=Stop_Key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Drucker('OFF')
  Umgebung(LOAD)

RETURN
/* EOP */

  /* PROCEDURE Honsel-BeistellInventurListe
  *
  * listet alle Beistellteile von Honsel mit KLager-Inv.Bestand auf (keine Details)
  * f�r Weitergabe an Honsel gedacht
  */
PROCEDURE honsBei2InvListe()
LOCAL Auswahl,kdFilter,kdName,zeile,seite:=0,export,expdefault
LOCAL Stop:=.f.
LOCAL excel, objErr

  cls
  titel("Honsel-Beistellteile Liste KLager-Inv.Bestand")

  if ! open("Artikel","Einheit","Kunden")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  @ 08,18 to 15,40
  @ 09,20 say "Ihre Auswahl:"
  @ 11,20 Prompt "1. Honsel - 10363"
  @ 12,20 Prompt "2. VVG    - 10167"
  @ 13,20 Prompt "3. Beide         "
  Message("Ihre Auswahl bitte.                  @ESC@=Ende")
  Menu to Auswahl
  if ABBRUCH
    close data
    cls
    RETURN
  endif


  /*** erste Stufe ***/
  SELECT Artikel
  set rela to ARTIKEL->ME into Einheit
  do case
  case Auswahl==1
    kdFilter:="10363"
    KUNDEN->(dbseek(kdFilter))
    kdName:=KUNDEN->KurzName
    expDefault:="HonselBT"
  case Auswahl==2
    kdFilter:="10167"
    KUNDEN->(dbseek(kdFilter))
    kdName:=KUNDEN->KurzName
    expDefault:="VVG_BT  "
  case Auswahl==3
    kdFilter:="10363/10167"
    KUNDEN->(dbseek("10363"))
    kdName:=trim(KUNDEN->KurzName)
    KUNDEN->(dbseek("10167"))
    kdName+="/"+trim(KUNDEN->KurzName)
    expDefault:="HONS_VVG"
  endcase

  export:=Druck_Bs(expDefault,.t.,.t.) // Abbruch
  if valtype(export)=="L" .and. ! export
    close data
    cls
    RETURN
  endif

  Message("Liste wird erstellt.    Bitte warten...")

  // export nach DBF?
  if valtype(export)=="C" // Excel

    set filter to getArtikelArt()=="B" .and. left(ARTIKEL->KonsigKdNr,5)$kdFilter .and. ;
      left(ARTIKEL->ArtNr,1)<>"E" .and. ARTIKEL->ME=EINHEIT->ME

    BEGIN SEQUENCE // krit. Bereich
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(export)
      excel:=ExcelExport():new()
      excel:addColumnsByName( ;
        { "ArtNr","EINHEIT->Text","Bez1","Bez2","Hartnr","KonsigInv" } )
      excel:export(.f.,.f.,export)
      Message(export+" wurde erzeugt.  @Taste@","@")
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
    cls
    close data
    return
  endif

  // druck oder PDF
  loca for getArtikelArt()=="B" .and.;
    left(ARTIKEL->KonsigKdNr,5)$kdFilter .and. left(ARTIKEL->ArtNr,1)<>"E"
  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite++
    zeile:=0
    ? 'Beistellteile: '+kdName+'       vom:',getUser():date,'     Seite',str(seite,3)
    ? '---------------------------------------------------------------------------'
    ? 'Art.Nr.    ME  Bezeichnung                    Honsel-Nr.            Bestand'
    ? '---------------------------------------------------------------------------'
    do while .not. ARTIKEL->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->UNT_RAND .and. ! stop
      ? out(ARTIKEL->ArtNr),EINHEIT->Text,ARTIKEL->Bez1,ARTIKEL->HartNr,ARTIKEL->KonsigInv
      if ! empty(ARTIKEL->Bez2)
        ? space(12),ARTIKEL->Bez2
      endif
      cont
      Stop:=stop_key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  drucker("OFF")
  close data
  cls
RETURN
  /* EOP honsBei2InvListe */


  #define MAX_TIEFE 10

  #command zeile++ => M->zeile++


  /* PROCEDURE Honsel-BeistellInventurListe
  *
  * listet alle Beistellteile von Honsel, sowie zugeh�rige Baugruppen und Oberartikel auf
  */
PROCEDURE honsBeiInvListe( mArtNr )
LOCAL Auswahl,kdFilter,kdName,merkSatz,resultSet,miki,honsel,sollSumme
LOCAL Stop:=.f.,erst:=.t.
MEMVAR Zeile
PRIVATE Zeile:=0

  Umgebung(WRITE_ALL)

  cls
  titel("Honsel-Beistellteile Inventurliste detailliert")

  if ! open("AvPost" ,"Artikel" ,"Kunden" )
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select AvPost
  AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel
  SELECT Artikel

  if mArtNr == nil // keine Vorgabe also abfragen

    @ 08,18 to 15,40
    @ 09,20 say "Ihre Auswahl:"
    @ 11,20 Prompt "1. Honsel - 10363"
    @ 12,20 Prompt "2. VVG    - 10167"
    @ 13,20 Prompt "3. Beide         "
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Auswahl
    if ABBRUCH .or. ! druck_BS() // Abbruch
      Umgebung(LOAD)
      RETURN
    endif

    /*** erste Stufe ***/
    Message("Liste wird erstellt.    Bitte warten...")
    do case
    case Auswahl==1
      kdFilter:="10363"
      KUNDEN->(dbseek(kdFilter))
      kdName:=KUNDEN->KurzName
    case Auswahl==2
      kdFilter:="10167"
      KUNDEN->(dbseek(kdFilter))
      kdName:=KUNDEN->KurzName
    case Auswahl==3
      kdFilter:="10363/10167"
      KUNDEN->(dbseek("10363"))
      kdName:=trim(KUNDEN->KurzName)
      KUNDEN->(dbseek("10167"))
      kdName+="/"+trim(KUNDEN->KurzName)
    endcase

    loca for getArtikelArt()=="B" .and.;
      left(ARTIKEL->KonsigKdNr,5)$kdFilter .and. left(ARTIKEL->ArtNr,1)<>"E"

  else
    // sollte bereits auf richtigem Artikel stehen
    kdFilter:=ARTIKEL->KONSIGKDNR
    KUNDEN->(dbseek(kdFilter))
    kdName:=KUNDEN->KurzName

    loca for ARTIKEL->ArtNr == mArtnr

    Drucker("BS")

  endif

  do while .not. ARTIKEL->(eof()) .and. ! stop

    if erst
      // initialisiere Seitenumbruch
      honBeiNewPage(kdFilter+" "+left(kdName+space(36),36))
      erst:=.f.
    else
      honBeiNewPage()
    endif

    do while .not.ARTIKEL->(eof()) .and.M->zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      merkSatz:=ARTIKEL->(recno())
      sollSumme:=ARTIKEL->KonsigBest
      resultSet:=rekHonsBeiList(ARTIKEL->ArtNr,0)
      miki:=resultSet[BG_BESTAND_LG_MIKI]
      honsel:=resultSet[BG_BESTAND_LG_HONSEL]

      if miki<>0 .or. honsel<>0 .or. sollSumme<>0
        // ZwischenSumme
        ? space(64),'--------------------------'
        ? space(64),str(miki,9,2),space(3),str(honsel,9,2),"= "+str(honsel+miki,9,2),"(Ist)"
        ? space(90),str(sollSumme,9,2),"(Soll)"
        ? space(90),"================"
        ? space(90),str(honsel+miki-sollSumme,9,2),"(Diff)"
        ?
      endif

      go (merkSatz)
      cont
      Stop:=stop_key()
    enddo
  enddo
  drucker("OFF")
  Umgebung(LOAD)
RETURN
  /* EOP honsBeiInvListe */



  /** listet rekursiv die beistellteile und zugeh�rige Baugruppen/Oberartikel auf */
function rekHonsBeiList(mArtNr,tiefe,druck)
LOCAL resultSet,miki,honsel:=0, lieferant:=0
LOCAL merkSatz,temp,merkArt
LOCAL i
MEMVAR Zeile
PRIVATE Zeile:=0

  default druck:=.t.

  merkArt:=ARTIKEL->(recno())

  ARTIKEL->(dbseek(mArtNr))
  // keine X-Artikel
  if getArtikelArt()=="X"
    resultSet:={}
    for i:=1 to BG_BESTAND_LENGTH
      aadd(resultSet, 0)
    next
    return resultSet
  endif
  miki:=ARTIKEL->LageBest

  // Ausnahme Dienstleistungen bei ext. Lieferanten gelten als Baugruppenbestand
  if getArtikelArt() $"D"
    lieferant:=ARTIKEL->BestExt
  endif

  // drucke OberArtikel
  if ARTIKEL->LageBest<>0 .or. ARTIKEL->KonsigBest<>0

    if druck
      ? space(tiefe*2),out(ARTIKEL->ArtNr),getArtikelArt(),ARTIKEL->Bez1,;
        space((MAX_TIEFE-tiefe)*2),ARTIKEL->LageBest
    endif

    if getArtikelArt()<>"B" .and.ARTIKEL->KonsigBest<>0
      if druck
        ?? space(3),ARTIKEL->KonsigBest
      endif
      honsel:=ARTIKEL->KonsigBest
    endif

    if ! empty(ARTIKEL->Bez2) .and. druck
      ? space(tiefe*2),space(11),ARTIKEL->Bez2
    endif
  endif

  // Seitenumbruch?
  if druck .and. M->zeile>=DRUCKER->laenge-LISTE->Unt_Rand
    honBeiNewPage()
  endif

  // drucke UnterArtikel
  AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr
  AVPOST->(dbseek(ARTIKEL->ArtNr))
  do while ! AVPOST->(eof()) .and. AVPOST->ArtNr==MArtNr
    if AVPOST->Art=="M" .and. AVPOST->Text=="A" .and. left(AVPOST->AvNr,1)<>"E"
      merkSatz:=AVPOST->(recno())
      temp:=rekHonsBeiList(AVPOST->AvNr,tiefe+1,druck)
      AVPOST->(dbGoto((merkSatz)))

      miki += temp[BG_BESTAND_LG_MIKI] * AVPOST->Menge
      honsel += temp[BG_BESTAND_LG_HONSEL] * AVPOST->Menge
      lieferant += temp[BG_BESTAND_LIEFERANT] * AVPOST->Menge

    endif
    AVPOST->(dbskip())
  enddo

  // f�lle Ergebnis-Set
  resultSet:=array(BG_BESTAND_LENGTH)
  resultSet[BG_BESTAND_LG_MIKI]:=miki
  resultSet[BG_BESTAND_LG_HONSEL]:=honsel
  resultSet[BG_BESTAND_LIEFERANT]:=lieferant

  ARTIKEL->(dbGoto((merkArt)))
return resultSet
  /** eof */

  /** listet rekursiv die beistellteile und zugeh�rige Baugruppen/Oberartikel auf
  * analog rekHonsBeiList liefert nur dern K-Lager Bestand!!!
  *
  * liefert nur den Baugruppen-Bestand bei Miki, also BG_BESTAND_LG_MIKI auf Basis von ARTIKEL->LageBest
  * inkl. ARTIKEL->LageBest des �bergebenen Artikels
  */
function baugrBestandMiki(mArtNr,tiefe)
LOCAL merkSatz,temp,merkArt
LOCAL miki:=0

  merkArt:=ARTIKEL->(recno())

  ARTIKEL->(dbseek(mArtNr))
  // keine X-Artikel
  if getArtikelArt()=="X"
    return 0
  endif
  // Ausnahme Dienstleistungen bei ext. Lieferanten gelten als Baugruppenbestand
  if getArtikelArt() $"D"
    Error("Achtung externe Dienstleistung bei: " +mArtNr+ " externer Bestand wird ignoriert.")
    return 0
  endif
  miki:=ARTIKEL->LageBest

  // drucke UnterArtikel
  AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr
  AVPOST->(dbseek(ARTIKEL->ArtNr))
  do while ! AVPOST->(eof()) .and. AVPOST->ArtNr==MArtNr
    if AVPOST->Art=="M" .and. AVPOST->Text=="A" .and. left(AVPOST->AvNr,1)<>"E"
      merkSatz:=AVPOST->(recno())
      temp:=baugrBestandMiki(AVPOST->AvNr,tiefe+1)
      AVPOST->(dbGoto((merkSatz)))

      miki += temp * AVPOST->Menge

    endif
    AVPOST->(dbskip())
  enddo

  ARTIKEL->(dbGoto((merkArt)))
return miki
  /** eof */

static procedure honBeiNewPage(kdText)
LOCAL Zeile:=0
  _thread static mySeite
  _thread static myKdText

  if valtype(kdText)<>"U"
    mySeite:=0
    myKdText:=kdText
  else
    M->Zeile:=FormFeed(M->Zeile,mySeite)
  endif

  mySeite=mySeite+1
  ? ' Beistellteile: '+myKdText+'      vom:',getUser():date,'   Seite',str(mySeite,3)
  ? ' ------------------------------------------------------------------------------------------'
  ? ' Art.Nr.  Art Bezeichnung                                     MIKI Bestand   Honsel Bestand'
  ? ' ------------------------------------------------------------------------------------------'

return
  /** eof */

  // / ACHTUNG bis hier ist Zeile umdefiniert -> M->Zeile, siehe #command
  #uncommand zeile++ => M->zeile++

  /**
  * Zeigt den aktuellen Miki-Lagerbestand, den Bestand in Baugruppen bei Miki und im K-Lager an
  * vom aktuell selektierten Artikel
  */
procedure zeigeKBestand()
LOCAL result, diff, ant
LOCAL aktRec:=ARTIKEL->(recno())

  Umgebung(WRITE_ALL)

  AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel
  result:=rekHonsBeiList(ARTIKEL->ArtNr,0,.f.)
  ARTIKEL->(dbGoto( aktRec ))

  // 20230213 wieder raus, da K-Lager wieder r�ckg�ngig
  // if ARTIKEL->KonsigKdNr=="10167-  "
  // // special case Honsel, hat kein K-Lager Bestand mehr
  // result[BG_BESTAND_LG_HONSEL]:=0
  // endif

  if getArtikelArt() $ "B"
    if ARTIKEL->KonsigKdNr=="10167-  "
      diff:=0
    else
      diff:=result[BG_BESTAND_LG_MIKI];
        + result[BG_BESTAND_LG_HONSEL] + result[BG_BESTAND_LIEFERANT] - ARTIKEL->KonsigBest
    endif
  else
    diff:=result[BG_BESTAND_LG_MIKI] + result[BG_BESTAND_LG_HONSEL] + result[BG_BESTAND_LIEFERANT];
      - ARTIKEL->KonsigBest - ARTIKEL->LageBest
  endif

  setcolor(COLWIN)
  if diff <> 0 .and. ! empty( ARTIKEL->KonsigKdNr )
    Fenster(10,4,21,40,"Baugruppen-Lagerbestand")
  else
    Fenster(10,4,18,40,"Baugruppen-Lagerbestand")
  endif

  @ 12,6 say "Einzelteile bei Miki : " + transstr( ARTIKEL->LageBest,10,2)
  @ 13,6 say "Baugruppen  bei Miki : " + ;
    transstr( if(getArtikelArt()=="X",0,result[BG_BESTAND_LG_MIKI] - ARTIKEL->LageBest) , 10 ,2)
  @ 14,6 say "Baugruppen  bei Kunde: " + transstr( result[BG_BESTAND_LG_HONSEL] ,10,2)

  if getArtikelArt() $ "D"
    @ 15,6 say "Baugruppen  bei Lief.: " + transstr( result[BG_BESTAND_LIEFERANT] ,10,2)
  endif

  @ 16,6 to 16,38

  if diff <> 0 .and. ! empty( ARTIKEL->KonsigKdNr )
    @;
      17,;
      6;
      say;
      "     Gesamt berechnet: ";
      +;
      transstr( result[BG_BESTAND_LG_MIKI] +;
      result[BG_BESTAND_LG_HONSEL] + result[BG_BESTAND_LIEFERANT],10,2)
    @ 18,6 say "     Gesamt EDV      : " + transstr( ARTIKEL->KonsigBest,10,2)
    @ 19,6 to 18,38
    @ 20,6 say "     Differenz       : " + transstr( diff,10,2)
  else
    @;
      17,;
      6;
      say;
      "               Gesamt: ";
      +;
      transstr( result[BG_BESTAND_LG_MIKI] +;
      result[BG_BESTAND_LG_HONSEL] + result[BG_BESTAND_LIEFERANT],10,2)
  endif

  ant:=Message("@D@=Details   @I@nventur-Daten   @ESC@=Ende","@")
  Umgebung(LOAD)

  // Zeige Details
  if ant == "D"
    honsBeiInvListe( ARTIKEL->ArtNr )
  elseif ant == "I"
    KLagerBewegung(ARTIKEL->ARtNr)
  endif

return
  /** eop */

  /** Listet alle ungenutzen Zahl.Kond auf */
PROCEDURE unbenutzteZK()
LOCAL allZK:={"Kunden","BesAus","AufAus","Lieferan","Rechaus","AngAus"}
LOCAL x,zeile:=0,printBuffer,treffer,alle,datei
LOCAL Stop:=.f.

  cls
  titel("�berpr�fung Zahlungs-Konditionen")

  if ! open("Zahlkond")
    Error(TRY_AGAIN)
    close data
    return
  endif

  Alle:=(Message("Alle oder nur unbenutzte? (@A@/@U@)","AU","U")=="A")

  if ABBRUCH .or. ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  zeile:=0
  ? "Zahlungskonditionen  vom",getUser():date
  ? "================================="
  select ZahlKond
  go top
  do while ! ZAHLKOND->(eof()) .and. ! Stop
    Message(ZAHLKOND->ZkNr+" "+ZAHLKOND->Text+" wird gepr�ft...")
    printBuffer:=printBuffer():new()
    treffer:=0
    ->? ZAHLKOND->ZkNr,ZAHLKOND->Text,ZAHLKOND->Text
    if alle
      ->? replicate("-",30)
    endif
    for each datei in allZK
      if select(datei)==0 .and. ! open(datei)
        ->? datei,"konnte nicht gepr�ft werden!!!"
      else
        select (Datei)
        x:=0
        loca for &(DATEI)->ZkNr==ZAHLKOND->ZkNr
        do while ! &(DATEI)->(eof()) .and. x<5
          ->? space(5),datei+":",&(DATEI)->(fieldget(1)),&(DATEI)->(fieldget(2))
          cont
          x++
          treffer++
        enddo
      endif
    next
    if alle .or. treffer==0
      ->?
      zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)
    endif
    Stop:=stop_key()

    select ZahlKond
    skip
  enddo

  getUser():getCurrentPrintJob():endDoc()
  close data
  cls
return
  /** eop */

  /** Listet alle ungenutzen Mat.KZ auf */
PROCEDURE unbenutzteMatKZ()
LOCAL allMatKZ:={"Artikel"}
LOCAL x,zeile:=0,printBuffer,treffer,alle,datei
LOCAL Stop:=.f.

  cls
  titel("�berpr�fung Mat.KZ")

  if ! open("Mat_Kz")
    Error(TRY_AGAIN)
    close data
    return
  endif

  Alle:=(Message("Alle oder nur unbenutzte? (@A@/@U@)","AU","U")=="A")

  if ABBRUCH .or. ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  zeile:=0
  ? "Material-Kennziffern vom",getUser():date
  ? "================================="

  select Mat_kz
  go top
  do while ! MAT_KZ->(eof()) .and. ! Stop
    Message(MAT_KZ->MatKZ+" wird gepr�ft...")
    printBuffer:=printBuffer():new()
    treffer:=0
    ->? MAT_KZ->MatKZ
    aEval(HB_ATokens( MAT_KZ->MkzText , MY_CR+MY_LF),;
      { |x| printBuffer:addTextLine({space(len(MAT_KZ->MatKZ)),x},.t.) })

    if alle
      ->? replicate("-",30)
    endif
    for each datei in allMatKZ
      if select(datei)==0 .and. ! open(datei)
        ->? datei,"konnte nicht gepr�ft werden!!!"
      else
        select (Datei)
        x:=0
        loca for &(DATEI)->MatKZ==MAT_KZ->MatKZ
        do while ! &(DATEI)->(eof()) .and. x<5
          ->? space(5),datei+":",&(DATEI)->(fieldget(1)),&(DATEI)->(fieldget(2))
          cont
          x++
          treffer++
        enddo
      endif
    next
    if alle .or. treffer==0
      ->?
      zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)
    endif

    Stop:=stop_key()
    select Mat_kz
    skip
  enddo

  getUser():getCurrentPrintJob():endDoc()
  close data
  cls
return
  /** eop */

  /** Listet alle Kunden/Lieferanten mit ung�ltigen SZ f�e SEPA Export */
PROCEDURE checkSZKdLief()
LOCAL zeile:=0,objErr,tempVal

  cls
  titel("Liste ung�ltige SZ f�r SEPA XML Export")

  if ! open("Kunden","Lieferan")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  zeile:=0
  ? "Ung�ltige Sonderzeichen vom",getUser():date
  ? "==========================================="

  select Kunden
  ? "Kunden:"
  go top
  do while ! KUNDEN->(eof())
    BEGIN SEQUENCE
      checkSepaCharacters(KUNDEN->Name,,"&") // $ allowed here!
    RECOVER USING objErr
      tempVal:=getErrorText(objErr)
      ? KUNDEN->KundNr,KUNDEN->Name,left(tempVal,at(MY_CR+MY_LF,tempVal))
    END SEQUENCE
    skip
  enddo

  select Lieferan
  ? "Lieferan:"
  go top
  do while ! LIEFERAN->(eof())
    BEGIN SEQUENCE
      checkSepaCharacters(LIEFERAN->Name1,,"&") // $ allowed here!
    RECOVER USING objErr
      tempVal:=getErrorText(objErr)
      ? LIEFERAN->LiefNr,LIEFERAN->Name1,left(tempVal,at(MY_CR+MY_LF,tempVal))
    END SEQUENCE
    skip
  enddo

  drucker("OFF")
  close data
  cls
return
  /** eop */


  /** Listet der letzten benutund von Werkzeugen je Jahr, ohne Doppel-Nennung */
PROCEDURE wkzList()
LOCAL zeile:=0 , Seite:=0 , werkzeuge:={}
LOCAL bis:=getUser():Date , von:=bis
LOCAL Stop:=.f. , summe:=0 , gesSumme:=0 , wkzPreis ,vk130:=0.00 , vk140:=0.00
LOCAL GetList:={} , isTest:=.f.

  cls
  titel("Werkzeug Liste")

  if ! open("AvPost","Artikel","Waraus")
    Error(TRY_AGAIN)
    close data
    return
  endif

  @ 10,28 to 17,56
  @ 11,30 say "Datum von:" get von when Message("Bitte Zeitraum eingeben.")
  @ 13,30 say "      bis:" get bis when Message("Bitte Zeitraum eingeben.")
  @ 15,30 say "VK 130...:" get vk130 when Message("VK f�r 130er Werkzeuge eingeben.")
  @ 16,30 say "VK 140...:" get vk140 when Message("VK f�r 140er Werkzeuge eingeben.")
  read

  if ABBRUCH .or. ! druck_BS() // Abbruch
    close data
    return
  endif

  if TEST_PROG
    setProperty("System.test","N")
    isTest:=.t.
  endif

  Message("Bewegungs-Datei wird durchsucht.  Bitte warten...")
  select Waraus
  index on WARAUS->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for WARAUS->Datum >= von .and. WARAUS->Datum <= bis

  Message("Liste wird erstellt.  Bitte warten...")
  go top
  do while ! WARAUS->(eof()) .and. ! Stop

    Seite++
    zeile:=0
    ? "Werkzeug-Benutzung ",von,"-",bis,space(12),"vom",getUser():date,space(7),"Seite:",;
      str(seite,3)
    ? replicate("=",84)
    ? "Wkz-Nr.   Bezeichnung                              VK  Datum   Eigner"
    ? replicate("=",84)
    do while ! WARAUS->(eof()) .and. ! Stop .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand - 2

      // suche zugeh. Wkz-St�ckliste
      select AvPost
      AVPOST->(dbseek( WARAUS->ArtNr + "W" ))
      do while ! AVPOST->(eof()) .and. WARAUS->ArtNr == AVPOST->AvNr .and. AVPOST->Art == "W"
        // Wkz gefunden?
        if left(AVPOST->ArtNr,3) $ "130/140"
          // bereits gedruckt?
          if aScan( werkzeuge , AVPOST->ArtNr ) == 0
            aadd( werkzeuge , AVPOST->ArtNr )

            // jetzt drucken
            if ARTIKEL->Preis1 > 0
              wkzPreis:=ARTIKEL->Preis1
            else
              if left(AVPOST->ArtNr,3) $ "130"
                wkzPreis:=vk130
              else
                wkzPreis:=vk140
              endif
            endif
            ARTIKEL->(dbseek( AVPOST->ArtNr ))
            if wkzPreis > 0
              ? out( AVPOST->ArtNr ) , ARTIKEL->Bez1 , transStr(wkzPreis,12,2) , WARAUS->Datum , ;
                ARTIKEL->Eigner , WARAUS->Programm
              if ! empty( ARTIKEL->Bez2 )
                ? space(len(out( AVPOST->ArtNr ))) , ARTIKEL->Bez2
              endif
              summe += wkzPreis
              gessumme += wkzPreis
            endif
          endif
          exit // we bail out, es gibt nur 1 Werkzeug je Artikel
        endif
        skip // AvPost
      enddo
      Stop:=stop_key()
      select Waraus
      skip
    enddo
    ? replicate("=",84)
    ? space(22),"Zwischensumme: ",transStr(summe,14,2),"Euro"

    if WARAUS->(eof())
      ?
      ? space(8),"Gesamt ",von,"-",bis,":",transStr(gessumme,14,2),"Euro"
    endif
    ?

    Zeile:=FormFeed(Zeile,Seite)

  enddo

  Drucker("OFF")
  close data
  cls
  if isTest
    setProperty("System.test","J")
  endif
return
  /** eop */


  /*
  *
  *  Umsatzliste Kunde je Jahr
  */
PROCEDURE UmsatzListe(mKundNr)
LOCAL jahr,jahrSumme:=0 , netto,gesamt:=0
LOCAL seite:=0, zeile:=0, stop:=.f.
LOCAL printBuffer:=printBuffer():new()
LOCAL filterJahr:=space(4)
LOCAL GetList:={}

  Umgebung(WRITE)

  cls
  titel("Umsatzliste Kunde / Jahr")

  Message("Gew�nschtes Jahr eingeben.  Leer = Alle")
  @ 10,20 say "Jahr:" get filterJahr picture "9999"
  read

  if ! druck_BS() // Abbruch
    Umgebung(LOAD)
    RETURN
  endif

  Message("Datei wird sortiert.   Bitte warten...")
  if ! open("Rechaus","Kunden")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  KUNDEN->(dbseek(mKundNr))

  SELECT Rechaus
  index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    left(RECHAUS->KundNr,5) == left(MKundNr,5) .and. ;
    (empty(filterJahr) .or. year(RECHAUS->ReaDat) == val(filterJahr))

  Message("Liste wird erstellt.  Bitte warten....")
  go top
  do while .not. RECHAUS->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Umsatz Kunde: "+KUNDEN->KundNr,KUNDEN->KurzName,"vom:",getUser():date,"Seite :",str(seite,3)
    ? '--------------------------------------------------------------------------'
    ? ' Jahr ',jahr,'              Netto'
    ? '--------------------------------------------------------------------------'

    if jahr <> year(RECHAUS->ReaDat)
      jahr:=year(RECHAUS->ReaDat)
      Netto:=0
    endif

    do while .not. RECHAUS->(eof()) .and. jahr == year(RECHAUS->ReaDat) ;
      .and.zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? RECHAUS->RechNr, RECHAUS->ReaDat,RECHAUS->Netto
      Netto += RECHAUS->Netto
      skip
    enddo

    ? replicate("-",26)
    ? jahr,space(5),transform(netto,"@E 999,999,999.99"),"Euro"
    if .not. RECHAUS->(eof()) .and. ! stop
      ?
    endif
    gesamt += Netto
    jahrSumme += Netto

    // merke Zwischensumme Jahr
    if jahr <> year(RECHAUS->ReaDat)
      ->? jahr,space(5),transform(jahrSumme,"@E 999,999,999.99"),"Euro"
      jahrSumme:=0
    endif
    FormFeed(Zeile,Seite)

  enddo

  // Zusammenfassung
  if empty(filterJahr)
    seite++
    ? "Umsatz Kunde: "+KUNDEN->KundNr,KUNDEN->KurzName,"vom:",getUser():date,"Seite :",str(seite,3)
    ? '--------------------------------------------------------------------------'
    if printBuffer:getNumLines() > 0
      getUser():getCurrentPrintJob():printBuffer(printBuffer)
      zeile += printBuffer:getNumLines()
    endif

    ? replicate("=",26)
    ? space(5),space(5),transform(gesamt,"@E 999,999,999.99"),"Euro"
    ? replicate("=",26)
    Zeile:=FormFeed(Zeile,Seite)
  endif

  Drucker("Off")

  cls
  Umgebung(LOAD)
RETURN
  /* EOP Umsatz Liste */

  /* PROCEDURE Kunden-Liste mit Umsatz
  *
  */
PROCEDURE KundenUmsatz()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis,i,netto
LOCAL Stop:=.f.
LOCAL summe, gesSumme
LOCAL numJahre:=13 // gehen bei Winzig Druck genau auf eine Seite
LOCAL start:=year(getUser():date) - numJahre + 1
LOCAL objErr, export, Ausgabe

  cls
  titel("Kunden Umsatzliste")

  if ! open("Rechaus","Kunden","KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  SELECT Rechaus
  index on RECHAUS->KundNr + dtos(RECHAUS->ReaDat) tag TEMP_INDEX TEMPORARY ADDITIVE DESCENDING;
    for year(RECHAUS->ReaDat) >= start .and. RECHAUS->KundNr <> "10000-  "

  do while ! ABBRUCH
    seite:=0; zeile:=0
    summe:=hb_hash()
    select Kunden
    /* Liste von bis */
    @ 4,0 clear
    von:=bis:=space(len(KUNDEN->KundNr))
    bis:=von_bis("Kunden")

    if ABBRUCH
      close data
      RETURN
    endif

    Ausgabe:=druck_BS("UmsatzListe",.t.,.t.)
    if ABBRUCH
      close data
      RETURN
    endif

    von:=KUNDEN->KundNr

    if valtype(Ausgabe)=="C"
      // FIXME: sollte alles in druck_bs passieren
      // beisst sich aber mit alten excel:column export
      BEGIN SEQUENCE // krit. Bereich
        export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
        getUser():setCurrentPrintJob(ExcelJob():new())
        getUser():getCurrentPrintJob():StartDoc( export )
      RECOVER USING objErr
        // nop, Fehler bereits protokolliert
      END SEQUENCE
    endif

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not. KUNDEN->(eof()).and. KUNDEN->Kundnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0

      if valtype(Ausgabe) <> "C"
        ? 'Kunden-Umsatzliste     vom:',getUser():date,space(numJahre*10),'Seite',str(seite,3)
        ? 'Kunden von:',von,' bis:',bis
        ? replicate("-",34 + numJahre*11)
      endif

      ? 'Kd.Nr.  ','Name                     '
      for i:=year(getUser():date) to start step -1
        ?? str(i,10)
      next

      if valtype(Ausgabe) <> "C"
        ? replicate("-",34 + numJahre*11)
      endif
      do while .not. KUNDEN->(eof()).and. KUNDEN->Kundnr<=bis ;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        ? kdout(KUNDEN->KundNr),KUNDEN->KurzName

        select Rechaus
        RECHAUS->(dbseek(KUNDEN->KundNr))

        i:=year(getUser():date)
        do while i >= start
          Netto:=0
          // jetzt alle Rechnungen des Kunden / Jahr aufsummieren
          do while .not. RECHAUS->(eof()) .and. i == year(RECHAUS->ReaDat) ;
            .and. RECHAUS->KundNr == KUNDEN->KundNr
            Netto += RECHAUS->Netto
            skip
          enddo

          // if netto > 0 .or. ( ! empty(KUNDEN->CREA_DATE) .and. i >= year(KUNDEN->CREA_DATE))
          if netto > 0 .or. ( i >= year(KUNDEN->CREA_DATE))
            ?? transStr(netto,10,0,.t.)
          else
            ?? space(10)
          endif

          // Summe addieren
          if hb_HHasKey( summe , i)
            summe[i]+=netto
          else
            summe[i]:=netto
          endif
          i--
        enddo

        select Kunden
        skip
        Stop=Stop_Key()
      enddo

      // am Ende, falls nicht Excel-Ausgabe
      if (KUNDEN->(eof()).or. KUNDEN->Kundnr>bis) .and. valtype(Ausgabe) <> "C"
        ? replicate("=",34 + numJahre*11)
        ? space(34)
        gessumme:=0
        for i:=year(getUser():date) to start step -1
          if hb_HHasKey( summe , i)
            ?? transStr(summe[i],10,0,.t.)
            gessumme += summe[i]
          else
            ?? space(10)
          endif
        next
        ?
        ? "Durchschnitt der letzten "+str(numJahre,2)+" Jahre:",;
          transStr(gessumme / numJahre,10,0,.t.),"Euro"
      endif
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

    if valtype(Ausgabe)=="C"
      if Message(export+" wurde erzeugt.  Ordner �ffnen? @J@/@N@","JN","N")=="J"
        wapi_SHELLEXECUTE( 0, "open", getUser():exportPATH())
      endif

    endif
  enddo
  cls
  close data
RETURN
  /* EOP Kundenliste*/

PROCEDURE UmsatzJahr()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL summe, gesSumme:=0
LOCAL jahr, region
LOCAL startJahr:=space(4), endJahr:=space(4) , Ausgabe
local DateiStru:=TEMP + BACKSLASH + left(getUser():getLongId(),2)+BACKSLASH+"tmpStr"
LOCAL TempDatei:=getTempDateiName( db_info("RechAus") ) + ".dbf"
LOCAL line:=replicate("=",50), prozSumme:=0
LOCAL allRegions:=hb_Hash(), allSumme:=hb_Hash()
LOCAL allNames:={ "Deutschland","Europa","USA","Sonstige" }, i , tempOrder


  cls
  titel("Kunden Umsatzliste pro Jahr (Versicherung)")

  Message("Bitte Zeitraum eingeben.     @Leer@=alle      @ESC@=Abbruch")

  SetKey( K_F8 , {|| __Keyboard(startJahr)} )

  @ 10,20 say "Jahr von:" get startJahr picture "9999" when Message("Start Jahr eingeben.")
  @ 12,20 say "     bis:" get endJahr picture "9999";
    when Message("Start Jahr eingeben.  @F8@=Start-Jahr kopieren ")
  read

  SetKey( K_F8 , nil)

  if ABBRUCH
    close data
    return
  endif

  Ausgabe:=druck_BS("Waraus",.f.,.t.)
  if ABBRUCH
    close data
    RETURN
  endif

  if ! open("Rechaus","Kunden","KundSped","Land")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  SELECT Rechaus
  set rela to RECHAUS->V_Land into Land

  Message("Daten werden sortiert.     Bitte warten....")
  copy stru exte to (DateiStru)
  select 0
  use (DateiStru) alias Stru
  add_rec(0)
  replace STRU->FIELD_NAME with "Region"
  replace STRU->FIELD_Type with "C"
  replace STRU->FIELD_Len with 12
  add_rec(0)
  replace STRU->FIELD_NAME with "Order"
  replace STRU->FIELD_Type with "C"
  replace STRU->FIELD_Len with 1
  use
  select 0
  create (TempDatei) from (DateiStru) alias data

  // kopiere relevante Rechnungen und setze location flag
  select Rechaus
  index on str(year(RECHAUS->ReaDat),4)+RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for (empty(startJahr) .or. year(RECHAUS->ReaDat) >= val(startJahr)) .and.;
    (empty(endJahr) .or. year(RECHAUS->ReaDat) <= val(endJahr)) .and. RECHAUS->KundNr <> "10000-  "
  go top
  jahr:=year(RECHAUS->ReaDat)
  do while ! RECHAUS->(eof())
    select data
    add_rec(0)
    overwrite("Rechaus",.t.)
    // setze flag
    if trim(RECHAUS->V_Land) == "US" .or. trim(RECHAUS->V_Land) == "USA"
      tempOrder:=3
    elseif trim(RECHAUS->V_Land) == "D" .or. trim(RECHAUS->V_Land) == "DE"
      tempOrder:=1
    elseif RECHAUS->EG == "J"
      tempOrder:=2
    else
      tempOrder:=4
    endif
    replace DATA->Order with str(tempOrder,1)
    replace DATA->Region with allNames[tempOrder]
    allRegions[tempOrder]:=DATA->Region
    prozSumme += RECHAUS->Netto

    RECHAUS->(dbskip())

    if jahr <> year(RECHAUS->ReaDat) .or. RECHAUS->(eof())
      allSumme[str(jahr,4)]:=prozSumme
      // pr�fe ob alle Regionen vorkommen, falls nein DummyRecord hinzuf�gen
      for i:=1 to len(allNames)
        if .not. hb_HHasKey(allRegions , str(i,1))
          add_rec(0)
          replace DATA->ReaDat with ctod("01.01."+str(jahr,4))
          replace DATA->order with str(i,1)
          replace DATA->Region with allNames[i]
        endif
      next
      prozSumme:=0
      jahr:=year(RECHAUS->ReaDat)
      allRegions:=hb_Hash()
    endif

  enddo

  index on str(year(DATA->ReaDat),4) + DATA->Order tag TEMP_INDEX TEMPORARY ADDITIVE

  seite:=0; zeile:=11230
  go top
  jahr:=0
  do while ! ABBRUCH .and. ! DATA->(eof())
    if jahr <> year(DATA->ReaDat)
      jahr:=year(DATA->ReaDat)
      region:=DATA->Region
      summe:=gesSumme:=0
      Message("Liste wird erstellt.    Jahr: @"+str(jahr,4)+"@     Bitte warten....")
    endif

    if zeile >= DRUCKER->laenge-LISTE->Unt_Rand
      zeile:=0
      seite++
      ? 'Jahr Region       Umsatz (Netto)',space(8),"Seite",str(seite,2)
      ? line
    endif
    do while ! ABBRUCH .and. ! DATA->(eof()) .and. jahr == year(DATA->ReaDat) .and.;
      zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      if region <> DATA->Region
        region:=DATA->Region
        summe:=0
      endif

      // aufusmmieren
      do while ! ABBRUCH .and. ! DATA->(eof()) .and. region==DATA->Region .and.;
        jahr == year(DATA->ReaDat) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        summe += DATA->Netto
        gesSumme += DATA->Netto
        skip
      enddo

      // drucken
      ? str(jahr,4),region,transform(summe,"@E 999,999,999"),EURO_SIGN,;
        str(summe/allSumme[str(jahr,4)]*100,4),"%"

      if jahr <> year(DATA->ReaDat)
        ? line
        ? space(17),transform(gessumme,"@E 999,999,999"),EURO_SIGN
        ?
      endif

      Stop=Stop_Key()
    enddo
    if zeile >= DRUCKER->laenge-LISTE->Unt_Rand
      FormFeed(Zeile,Seite)
    endif
  Enddo
  Drucker("Off")

  cls
  close data
RETURN
/* EOP UmsatzJahr*/


  /** parst den text ob spezielle WARAUS Felder vorkommen (yerk) und
  *   setzt das Zeige KZ zum launchen anderer Programm */
function waraus2Zeige( text )
LOCAL pos
  text:=trim(text)

  if getUser():getCurrentPrintJob():className()=="BSJOB"

    // AB
    if (pos:=at( WARAUS_AUFNR , text )) > 0
      pos += len( WARAUS_AUFNR )
      text:=left( text , pos-1) + ZEIGE_AUFNR + substr( text , pos )
    endif

    // Bestellung
    if (pos:=at( WARAUS_BESTNR , text )) > 0
      pos += len( WARAUS_BESTNR )
      text:=left( text , pos-1) + ZEIGE_BESTNR + substr( text , pos )
    endif

    // Rechnung
    if (pos:=at( WARAUS_RECHNR , text )) > 0
      pos += len( WARAUS_RECHNR )
      text:=left( text , pos-1) + ZEIGE_RECHNR + substr( text , pos )
    endif

    // KV seit 20180714
    if (pos:=at( WARAUS_KVNR , text )) > 0
      pos += len( WARAUS_KVNR )
      text:=left( text , pos-1) + ZEIGE_AUFNR + substr( text , pos )
    endif

  endif

return text
/** eof */

/*
* Vergleicht Versart/Zahl.Kond vom Hauptkunden
* mit R-Kunde  xxxxx-01 - xxxxx-10
*     V-Kunde  xxxxx-11 - xxxxx-99
*
* Parameter: overwrite: if true werden leere Felder bei der Versandadresse ausgef�llt
*/
PROCEDURE KundenVersartCheck( overwrite )
LOCAL seite:=0, zeile:=0, GetList:={}, mKundNr,mKurzName
LOCAL bis,mVersNr,mZkNr, erst:=.t.
LOCAL Stop:=.f., printBuffer:=printBuffer():new()

  if ! open("Kunden")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  default overwrite:=.f.

  cls
  titel("Kunden Versandart/Zahlungskond. Check ")

  if overwrite
    select Kunden
    go bottom
    bis:=KUNDEN->KundNr
    go top
    Drucker("PDF")
  else
    bis:=von_bis("Kunden")
    if empty(bis)
      cls
      close data
      RETURN
    endif

    if ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif
  endif

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.KUNDEN->(eof()) .and. KUNDEN->Kundnr<=bis.and. ! stop
    seite=seite+1
    zeile:=0
    ? "Kunden Versart / Zahlungskonditionen �bersicht",space(11),"vom:",getUser():date
    ? replicate('=',72)
    ? "KD-Nr.   Kurzname             Versand-Art    Zahlungskondition " // Spedition"
    ? replicate('=',72)
    _____fixedHeader_____

    do while .not.KUNDEN->(eof()) .and. KUNDEN->Kundnr<=bis .and. ! stop ;
      .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand

      if (mKundNr <> left(KUNDEN->KundNr,5))
        mKundNr:=left(KUNDEN->KundNr,5)
        mKurzName:=KUNDEN->Kurzname
        mVersNr:=KUNDEN->VersNr
        mZkNr:=KUNDEN->ZkNr
        // mSpedNr:=KUNDEN->SpedNr
        skip
        if (mKundNr <> left(KUNDEN->KundNr,5))
          loop
        endif
      endif

      do while .not.KUNDEN->(eof()) .and. KUNDEN->Kundnr<=bis .and. ! stop ;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. substr(KUNDEN->Kundnr,1,5)==mKundNr
        if KUNDEN->VersNr <> MVersNr .or. KUNDEN->ZkNr <> mZkNr // .or. KUNDEN->SpedNr <> mSpedNr

          // drucke HauptKunde beim 1. Konsistenz-Fehler
          if mKurzName <> nil
            if ! erst // nicht beim 1.
              ? replicate('-',72)
            endif
            erst:=.f.
            ? mKundNr,space(2),mKurzname,space(2),mVersNr,space(10),mZKNr// ,space(8),mSpedNr
            mKurzName:=NIL
          endif

          ? KUNDEN->KundNr, KUNDEN->Kurzname

          /*** Versandart ***/
          if ! empty(KUNDEN->VersNr) .and. KUNDEN->VersNr <> MVersNr
            ?? COLOR_RED
          endif
          ?? space(2),KUNDEN->VersNr,space(10)
          if KUNDEN->VersNr <> MVersNr
            if ! empty(KUNDEN->VersNr)
              ?? COLOR_DEFAULT
            else
              // r�ckschreiben if applicable
              if overwrite
                rec_lock(0)
                replace KUNDEN->VersNr with MVersNr
              endif
            endif

          endif

          /*** Zahlungskondition ***/
          if ! empty(KUNDEN->ZKNr) .and. KUNDEN->ZkNr <> mZkNr
            ?? COLOR_RED
          endif
          ?? KUNDEN->ZKNr,space(8)
          if KUNDEN->ZkNr <> mZkNr
            if ! empty(KUNDEN->ZKNr)
              ?? COLOR_DEFAULT
            else
              // r�ckschreiben if applicable
              if overwrite
                rec_lock(0)
                replace KUNDEN->ZkNr with MZkNr
              endif
            endif
          endif

          /*** Spedition ***/
          // if ! empty(KUNDEN->SpedNr) .and. KUNDEN->SpedNr <> mSpedNr
          // ?? COLOR_RED
          // endif
          // ?? KUNDEN->SpedNr,COLOR_DEFAULT
          // if KUNDEN->SpedNr <> mSpedNr
          // if ! empty(KUNDEN->SpedNr)
          // ?? COLOR_DEFAULT
          // else
          // // r�ckschreiben if applicable
          // if overwrite
          // rec_lock(0)
          // replace KUNDEN->SpedNr with MSpedNr
          // endif
          // endif

          // endif

          dbcommit()
          dbunlock()

        endif
        skip
      enddo
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  getUser():getCurrentPrintJob():endDoc()

  close data

RETURN
  /* EOP KundenVersartCheck */

  /*
  * Beistellteill Bestandsliste
  *
  */
PROCEDURE BeistBestandsListe(auto)
LOCAL zeile:=0, Seite:=0
LOCAL Stop:=.f., liFullName
local result, treffer:=0
local nurNeg:=.f.

  default auto:=.f.

  cls
  Titel("Beistellteile Bestandsliste")

  if ! open( "Artikel" , "AvPost" )
    Error(TRY_AGAIN)
    close data
    return
  endif

  if Auto
    Drucker("PDF","Beistellteile",,,PDF_NO_CONFIRM)
    nurNeg:=.t.
  else
    nurNeg:=Message("Nur abweichende? (@J@/@N@)","JN","N")=="J"
    if ABBRUCH .or. ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif
  endif

  AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel

  select Artikel
  loca for getArtikelArt() == "B" .and.;
    ! (empty( ARTIKEL->KonsigKdNr ) .or. ARTIKEL->KonsigKdNr == KDNR_LEER)
  do while ! ARTIKEL->(eof())

    seite++
    ? "Beistellteile Bestandsliste",space(32),"vom:",getUser():date,space(7),"Seite :",str(seite,3)
    ? "Art.Nr.   Bezeichnung                        Miki       Miki   VVG/Honsel K-Bestand  "+;
      "K-Bestand"
    ? "                                             Lager      Baugr. Baugruppen      Soll        "+;
      "EDV"
    ? replicate('=',94)
    _____fixedHeader_____

    do while .not. ARTIKEL->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      // Details (Baugruppen etc.) zu Lagerbestand ermitteln
      Umgebung(WRITE_ALL)
      result:=rekHonsBeiList(ARTIKEL->ArtNr,0,.f.)
      Umgebung(LOAD)

      if ! nurNeg .or.;
        abs(result[BG_BESTAND_LG_MIKI] + result[BG_BESTAND_LG_HONSEL] - ARTIKEL->KonsigBest) > 0.1
        ? ARTIKEL->Artnr,ARTIKEL->Bez1
        ?? transstr( ARTIKEL->LageBest,10,2) // Miki Lager
        ?? transstr( result[BG_BESTAND_LG_MIKI] - ARTIKEL->LageBest,10,2) // Miki in Baugruppen
        ?? transstr( result[BG_BESTAND_LG_HONSEL] ,10,2) // Honsel Baugruppen
        ?? transstr( result[BG_BESTAND_LG_MIKI] + result[BG_BESTAND_LG_HONSEL],10,2) // Summe
        ?? transstr( ARTIKEL->KonsigBest,10,2) // aktueller K-Bestand
        treffer++
      endif
      Stop:=stop_key()
      cont
    enddo
    Zeile:=FormFeed(Zeile,Seite)

  enddo

  if auto
    getUser():getCurrentPrintJob():endDoc()
    liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
    getUser():setCurrentPrintJob(NIL)

    if treffer > 0
      // email(MAIN_EMAIL,"Beistellteile K-Lager Bestandsabweichung: "+dtoc(getUser():date), email(MY_EMAIL,"Beistellteile K-Lager Bestandsabweichung: "+dtoc(getUser():date), "Bitte �berpr�fen!",liFullName)
    endif

  else
    drucker("OFF")
  endif
  cls
  close data

RETURN
  /* EOP  */

  /** exportiert Lagerort Artikel Datei
  *
  */
Procedure convertLager( exportExcel )
LOCAL GetList:={}
LOCAL s01:=savescreen(), exportName:="Artikel-Lagerort"
LOCAL l1,l2,l3,fehler, ort
LOCAL excel, objErr, export , aFields

  cls
  Titel("Konvertiere Lagerort")

  Message("Datei wird erstellt.  Bitte warten.")

  if ! open({"Artikel",.t.},"LagerOrt")
    close data
    cls
    return
  endif

  select Artikel
  replace all ARTIKEL->Temp with "" , ARTIKEL->Temp2 with ""

  set rela to substr(ARTIKEL->Temp,1,2) into LAGERORT
  go top

  do while ! ARTIKEL->(eof())

    @ 10,20 say "Artikel: " + ARTIKEL->ArtNr

    fehler:="0"
    l1:=l2:=l3:=space(2)
    ort:=alltrim(getArtikelLagerOrt())
    ort:=strtran( ort , "_" , " ")
    ort:=strtran( ort , "." , " ")
    ort:=no_blanks( ort )

    if empty( Ort )
      replace ARTIKEL->Temp with ""
      replace ARTIKEL->Temp2 with " "
      skip
      loop
    endif

    // Sondef�lle
    do case
    case "S�GERA" $ upper( ort )
      l1:="22"
      ort:=""
    case "NELLES" $ upper( ort ) .or. "SCHREIN" $ upper( ort )
      l1:="21"
      ort:=""
    otherwise

      // Lagort anhand Stelle bestimmen

      // Raum
      if type(substr(Ort,1,2)) == "N"
        l1:=substr(Ort,1,2)
        Ort:=substr( Ort,3 )

        // Regal
        if type(substr(Ort,1,2)) == "N"
          l2:=substr(Ort,1,2)
          Ort:=substr( Ort,3 )

          // Fach 3 Stellen
          if type(substr(Ort,1,3)) == "N"
            l3:=substr(Ort,1,3)
            Ort:=substr( Ort,4 )
            // Fach 2 Stellen
          elseif type(substr(Ort,1,2)) == "N"
            l3:=substr(Ort,1,2)
            Ort:=substr( Ort,3 )
            // Fach 1 Stelle
          elseif type(substr(Ort,1,1)) == "N"
            l3:=substr(Ort,1,1)
            Ort:=substr( Ort,2 )

            if alltrim(Ort) $ "lrmh"
              ort:=upper( ort )
            endif
          else
            fehler:="3"
          endif
        else
          fehler:="2"
        endif
      else
        fehler:="1"
      endif
    endcase

    ort:=alltrim( ort )

    // Wort Regal raus
    if upper( right( ort , 5 ) ) == "REGAL" .or. upper( right( ort , 3 ) ) == "REG"
      Ort:=""
    endif

    // -- erstzen mit -
    do while "--" $ ort
      ort:=strtran( ort , "--" , "-" )
    enddo
    if right( ort , 1 ) == "-"
      ort:=left ( ort , len (ort) - 1 )
    endif

    if ! empty( l3 )
      l3:=right( "000" + alltrim(l3) , 3)
    endif

    replace ARTIKEL->Temp with l1 + "." + l2 + "." + l3 + "." + ort
    replace ARTIKEL->Temp2 with fehler

    // 178er Artikel 24er Ort umschreiben in 34
    if left( ARTIKEL->ArtNr,3 ) = "178" .and. l1 == "24"
      l1:="34"
    endif

    replace ARTIKEL->LG_Raum with l1
    replace ARTIKEL->LG_Regal with l2
    replace ARTIKEL->LG_Fach with l3
    replace ARTIKEL->LG_Text with ort

    skip
  enddo

  if exportExcel

    // nur nicht leere exportieren
    set filter to ! empty( ARTIKEL->Temp2 )

    if mkMyDir(getUser():exportPATH())
      BEGIN SEQUENCE // krit. Bereich
        export:=getUser():exportPATH() + BACKSLASH + cleanFileName(exportName)
        excel:=ExcelExport():new()

        aFields:={ "ArtNr","Bez1","Bez2",{"LagerOrt","LagerOrt Alt"},{"Temp","LagerOrt Neu"},;
          {"LAGERORT->Text","Raum"},;
          {"Temp2","Fehler an Stelle"}}
        excel:addColumnsByName( aFields )

        excel:export(.f.,.f.,export)
        Message(export+" wurde erzeugt.  @Taste@","@")

        wapi_SHELLEXECUTE( 0, "open", export + ".xlsx" )

      RECOVER USING objErr
        // nop, Fehler bereits protokolliert
      END SEQUENCE
    endif

  endif

  cls
  close data

return
  /** EOF */

  /*
  * zeigt die Bewegungshistiorie eines K-Lager-Artikel an.
  *
  * Zeitraum von:
  * Sucht in Historie den Eintrag vom Jahr
  *
  *   #define WARAUS_KLAG_INV       "K-Lager Inventur: "
  *
  *  falls nicht vorhanden, wird die 1. Bewegung in dem Jahr genommen
  *
  * Zeitraum bis:
  * Sucht in Historie den Eintrag vom Folge-Jahr
  *
  *   #define WARAUS_KLAG_INV       "K-Lager Inventur: "
  *
  *  falls nicht vorhanden, wird die letzte. Bewegung in dem Jahr genommen
  *
  *
  * z.B. STRG-I im ArtikelStamm
  *
  * 3 unterst�tze K-Lager Typen
  VVG 710 - 503er Ger�te (in 2017 zum 31.12.17 gez�hlt,
  aber erst in 2017 gebucht nach Entnahme altes und neues Jahr gemischt
  s. getKLagerBestand

  VVG 800 - alle anderen Artikel au�er 503er
  K-Lager Bestand zum 24.1.17 �bernommen s. Email vom 24.1.17

  Honsel  - 503er Ger�te

  *
  * Return: false falls nicht chronologisch bzw. ein Sprung in der Menge sprich ein Fehler
  */

  #define KLAG_VVG710 1
  #define KLAG_VVG800 2
  #define KLAG_HONSEL 3

FUNCTION KLagerBewegung(mArtNr , Jahr , auto, abfrageJahr)
LOCAL zeile:=0,seite:=0
LOCAL Stop:=.f., summe, start
LOCAL tempNr, lastK
LOCAL GetList:={}, kTyp
LOCAL result:=0, ende:=.f.
LOCAL kom, export,maxRow , entnahmeJahr, erst:=.t., text

  default Jahr:=space(4)//year(getUser():date)-1
  default auto:=.f.
  default abfrageJahr:=.f.

  Umgebung(WRITE_ALL)

  if ! open("Artikel","Einheit","Kunden","Waraus","Rechaus","RechPost")
    Umgebung(LOAD)
    RETURN result
  endif

  cls
  titel("Honsel KLager-Inventur Bewegungen")

  if ! empty(mArtNr)
    if left(ARTIKEL->KonsigKdNr,5) == KDNR_VVG
      if left(ARTIKEL->ArtNr,3)=="503"
        kTyp:=KLAG_VVG710
      else
        kTyp:=KLAG_VVG800
      endif
    else
      if left(ARTIKEL->KonsigKdNr,5) == KDNR_HONSEL
        if left(ARTIKEL->ArtNr,3)=="503"
          kTyp:=KLAG_HONSEL
        endif
      endif
    endif

    if kTyp == NIL
      Error(ACHTUNG+"Nur VVG 710/800 und Honsel 503er Artikel unterst�tzt.")
      Umgebung(LOAD)
      RETURN result
    endif
  endif

  if ! auto
    if myEmpty( mArtnr )
      mArtNr:=space(len( ARTIKEL->ArtNr ))
      Message("Artikel eingeben.     @F12@=Hilfe")
      @ 8,20 say "Art.Nr.:" get MArtNr PICTURE "@K!" valid { |oGet| check(oGet,"Artikel") };
        when Message("Artikel-Nummer eingeben.   @F12@=Auswahl")
      @ 10,20 say "Jahr...:" get Jahr PICTURE "@K ####" when Message("Gew�nschtes Jahr eingeben.")
      read
      if ABBRUCH
        Umgebung(LOAD)
        return result
      endif

    else
      ARTIKEL->(dbseek( mArtNr ))
      // if ARTIKEL->KonsigIDat <> ctod("  .  .  ")
      // jahr = year(ARTIKEL->KonsigIDat)
      // endif

      @ 8,20 say "Art.Nr.: " + MArtNr + space(1) + ARTIKEL->Bez1
      @ 10,20 say "Jahr...:" get Jahr PICTURE "@K ####" when Message("Gew�nschtes Jahr eingeben.")
      if abfrageJahr
        read
        if ABBRUCH
          Umgebung(LOAD)
          return result
        endif
      endif
    endif
  endif

  if auto
    export:="Miki-" + KTyp + "-" + mArtNr
  else
    export:=Druck_Bs("KInv-"+mArtNr , .t. , .t.)
    if ABBRUCH .or. (valtype(export)=="L" .and. ! export)
      Umgebung(LOAD)
      return result
    endif
  endif

  if ! empty(jahr)
    if ! isDigit(Jahr)
      Error(ACHTUNG+"Jahr muss numerisch sein, z.B.: 2023")
      Umgebung(LOAD)
      return result
    endif
    jahr:=val(jahr)
  endif

  Message("Liste wird erstellt.  @"+mArtNr+"@  Bitte warten...")


  // export nach DBF?
  if valtype(export)=="C" // Excel
    export:=getUser():exportPATH() + BACKSLASH + cleanFileName(export)
    getUser():setCurrentPrintJob(ExcelJob():new())
    getUser():getCurrentPrintJob():StartDoc( export )
    getUser():getCurrentPrintJob():oSheet:columns( 1 ):ColumnWidth:=12
    getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=30

    ? "Datum","Art","Bewegung","Honsel-Bestand"
    // ? FETT_AN,"31.12."+str(Jahr-1,4),"Inventur",space(36),start,FETT_AUS
  endif

  select Waraus
  if empty(jahr)
    index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      WARAUS->ArtNr == ARTIKEL->Artnr .and. isKlagerBewegung()
    go top
  else
    index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      (year(WARAUS->Datum)==Jahr - 1 .or. year(WARAUS->Datum)==Jahr .or.;
      year(WARAUS->Datum)==Jahr + 1) .and. WARAUS->ArtNr == ARTIKEL->Artnr .and. isKlagerBewegung()
    loca for WARAUS_KLAG_INV + str(Jahr-1,4) == trim( WARAUS->Programm ) // suche K-Lager Inv.Eintrag
  endif

  if WARAUS->(eof())
    loca for year(WARAUS->Datum)==Jahr // nehme 1.
    skip -1
    start:=summe:=WARAUS->KonsigBest
    skip
  else
    start:=summe:=WARAUS->KonsigBest
  endif

  do while .not. WARAUS->(eof()) .and. ! stop .and. ! ende

    seite++
    zeile:=0

    if valtype(export) <> "C" // kein Excel
      text:=iif(empty(jahr),space(6),' ('+str(Jahr,4)+')')
      ? 'Bewegung '+ARTIKEL->ArtNr+' ' + ARTIKEL->Bez1 + text,'vom:',getUser():date
      ? '         '+ARTIKEL->HArtNr,space(30),'Seite',str(seite,3)
      ? '---------------------------------------------------------------------'
      ? 'Datum    Art                              Bewegung     Honsel-Bestand'
      ? '---------------------------------------------------------------------'
    endif

    do while .not. WARAUS->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->UNT_RAND .and. ! stop .and.;
      ! ende

      // Sonderfall Tag der Inventur
      // Hier kann es sein, dass eine Buchung vor und eine nach der Inventur�bernahme erfolgt ist
      // pr�fe Jahreszugeh�rigkeit anhand der Menge
      //
      // ACHTUNG: geht bei 3 oder mehr Buchungen an dem Tag schief!
      // raus am 3.11.2021
      // if WARAUS->Datum == ARTIKEL->KonsigIDat
      // if year(WARAUS->Datum)==Jahr
      // if WARAUS->KonsigBest - WARAUS->Menge <> ARTIKEL->KonsigInv
      // start:=summe:=WARAUS->KonsigBest
      // skip
      // loop
      // endif
      // else
      // if WARAUS->KonsigBest <> ARTIKEL->KonsigInv
      // skip
      // loop
      // endif
      // endif
      // endif

      if Seite == 1 .and. erst .and. ! empty(jahr)
        ? "Inventur-Bestand zum 31.12."+str(Jahr-1,4),space(22),start
        erst:=.f.
      endif
      kom:=""

      // im Folge-Jahr nur Entnahmen vom gew�nschten Jahr
      // raus am 31.10.21
      // if WARAUS->Datum > ARTIKEL->KonsigIDat
      // skip
      // loop
      // endif

      entnahmeJahr:=0

      // bei Rechnung pr�fe ob K-Lager Rechnung
      if WARAUS_RECHNR $ WARAUS->Programm .or. WARAUS_RECHNR_STORNO $ WARAUS->Programm

        entnahmeJahr:=getKlagerBewegungJahr()

        if WARAUS_RECHNR $ WARAUS->Programm
          tempNr:=trim( substr( WARAUS->Programm , len( WARAUS_RECHNR ) + 1))
        else
          tempNr:=trim(substr( WARAUS->Programm , len( WARAUS_RECHNR_STORNO ) + 1))
        endif
        RECHAUS->(dbseek( tempNr ))
        if RECHAUS->AufArt == "K" // K-Lager Rechnung, merke Details
          // Entnahme Zeitraum nicht ausdrucken
          kom:=alltrim(RECHAUS->BestNr)+" "+RECHAUS->BestKonto
        else // keine K-Lager Rechnug
          ? COLOR_RED // FIXME: must be a seperate function call (as of now)
          ?? WARAUS->Datum,WARAUS->PROGRAMM
          ?? COLOR_DEFAULT // FIXME: must be a seperate function call (as of now)
          ?? WARAUS->Menge // Ist hier nicht der K-LagerBestand, sondern nur die Bewegung!
          skip
          loop
        endif
      endif

      // 2. Bewegung vom K-Lieferschein und K-R�cklieferung ausblenden ist Miki Buchung nicht K-Lager
      if (WARAUS_KLAG_LS $ WARAUS->Programm .or. WARAUS_KLAG_STORNO_LS $ WARAUS->Programm .or.;
        WARAUS_KLAG_RUECKLIEF $ trim(WARAUS->PROGRAMM)) .and. lastK == WARAUS->KonsigBest
        skip
        loop
      endif

      // Kontroll-Summe
      Summe += WARAUS->Menge

      ? WARAUS->Datum,WARAUS->PROGRAMM,WARAUS->Menge,Summe
      if Summe <> WARAUS->KonsigBest
        ?? COLOR_RED,WARAUS->KonsigBest, "!!!", COLOR_DEFAULT
        Summe:=WARAUS->KonsigBest // reset aktuelle Kontrollsumme
      endif

      if entnahmeJahr <>0 .and. (empty(jahr) .or. entnahmeJahr <> Jahr)
        ?? entNahmeJahr,kom
      endif
      lastK:=WARAUS->KonsigBest

      skip
      Stop:=stop_key()

    enddo

    if valtype(export)<>"C" // kein Excel
      // if WARAUS->(eof())
      // ? '---------------------------------------------------------------------'
      // if Jahr == year(getUser():date)
      // ? 'Bestand aktuell:',space(33),ARTIKEL->KonsigBest
      // if Summe <> ARTIKEL->KonsigInv
      // ?? COLOR_RED,"!!!  Soll: ",COLOR_DEFAULT, Summe
      // result:=Summe
      // endif
      // endif
      // endif
      Zeile:=FormFeed(Zeile,Seite)
    endif
  enddo

  if valtype(export)=="C" // Excel
    // Excel-Summe
    maxRow:=getUser():getCurrentPrintJob():row
    // getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 4 )
    maxRow:=getUser():getCurrentPrintJob():row
    getUser():getCurrentPrintJob():colNumberFormat( 2 , maxRow , 3 , EXCEL_NUMBER_FORMAT_INTEGER2)

    // getUser():getCurrentPrintJob():bold(.t.)
    // ? FETT_AN,ctod("31.12."+str(Jahr,4)),'aktueller Bestand:',"",ARTIKEL->KonsigInv,FETT_AUS

    drucker("OFF")

    if ! auto
      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
    endif

  else
    drucker("OFF")
  endif

  Umgebung(LOAD)

RETURN result
  /* EOP */

  /*
  * listet alle Beistellteile von Honsel, sowie zugeh�rige Baugruppen und Oberartikel als Z�hlliste auf
  *
  * 30.1.2016 Menge Baugruppe wieder raus zu verwirrend
  */
PROCEDURE honsBeiZaehlListe( mArtNr )
LOCAL Auswahl,kdFilter,kdName,sollSumme
LOCAL Stop:=.f.,erst:=.t., alleBaugruppen:=hb_hash()
LOCAL Zeile:=0, Seite:=0, aArtikel , i, merkSatz, resultSet

  Umgebung(WRITE_ALL)

  cls
  titel("Honsel-Beistellteile Inventur - Z�hlliste")

  if ! open("AvPost" ,"Artikel" ,"Kunden" )
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select AvPost
  AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel
  SELECT Artikel

  if mArtNr == nil // keine Vorgabe also abfragen

    @ 08,18 to 15,40
    @ 09,20 say "Ihre Auswahl:"
    @ 11,20 Prompt "1. Honsel - 10363"
    @ 12,20 Prompt "2. VVG    - 10167"
    @ 13,20 Prompt "3. Beide         "
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Auswahl
    if ABBRUCH .or. ! druck_BS() // Abbruch
      Umgebung(LOAD)
      RETURN
    endif

    /*** erste Stufe ***/
    Message("Liste wird erstellt.    Bitte warten...")
    do case
    case Auswahl==1
      kdFilter:="10363"
      KUNDEN->(dbseek(kdFilter))
      kdName:=KUNDEN->KurzName
    case Auswahl==2
      kdFilter:="10167"
      KUNDEN->(dbseek(kdFilter))
      kdName:=KUNDEN->KurzName
    case Auswahl==3
      kdFilter:="10363/10167"
      KUNDEN->(dbseek("10363"))
      kdName:=trim(KUNDEN->KurzName)
      KUNDEN->(dbseek("10167"))
      kdName+="/"+trim(KUNDEN->KurzName)
    endcase

    loca for getArtikelArt()=="B" .and.;
      left(ARTIKEL->KonsigKdNr,5)$kdFilter .and. left(ARTIKEL->ArtNr,1)<>"E"

  else
    // sollte bereits auf richtigem Artikel stehen
    kdFilter:=ARTIKEL->KONSIGKDNR
    KUNDEN->(dbseek(kdFilter))
    kdName:=KUNDEN->KurzName

    loca for ARTIKEL->ArtNr == mArtnr

    Drucker("BS")

  endif

  do while .not. ARTIKEL->(eof()) .and. ! stop

    seite++

    ? 'Beistellteile: '+kdFilter+" "+left(kdName+space(24),24)+;
      '  vom:',getUser():date,'     Seite',str(seite,3)
    ? '---------------------------------------------------------------------------'
    ? 'Art.Nr.   Art Bezeichnung                                 Lager-  Z�hlmenge'
    ? '                                                         Bestand'
    ? '---------------------------------------------------------------------------'

    do while .not.ARTIKEL->(eof()) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      merkSatz:=ARTIKEL->(recno())
      sollSumme:=ARTIKEL->KonsigBest
      resultSet:=rekHonsBeiArtikel(ARTIKEL->ArtNr , @alleBaugruppen)
      // miki:=resultSet[BG_BESTAND_LG_MIKI]
      // honsel:=resultSet[BG_BESTAND_LG_HONSEL]
      go (merkSatz)

      // ?
      ? out(ARTIKEL->ArtNr), ARTIKEL->Bez1, getArtikelLagerOrt(12), str(ARTIKEL->LageBest,9,2),;
        " _________"

      cont
      Stop:=stop_key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  seite++

  aArtikel:=aSort( alleBaugruppen:Keys )
  i:=1
  do while i <= len( aArtikel )

    ? 'Baugruppen '+kdFilter+" "+left(kdName+space(29),29)+;
      ' vom:',getUser():date,'   Seite',str(seite,3)
    ? '-------------------------------------------------------------------------'
    ? 'Art.Nr.   Art Bezeichnung                               Lager-  Z�hlmenge'
    ? '                                                       Bestand'
    ? '-------------------------------------------------------------------------'

    do while i <= len( aArtikel ) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      mArtNr:=aArtikel[i]
      ARTIKEL->(dbseek( mArtNr ))
      if getArtikelArt() <> "X"
        // miki:=alleBaugruppen[mArtNr,BG_BESTAND_LG_MIKI]
        // honsel:=alleBaugruppen[mArtNr,BG_BESTAND_LG_HONSEL]

        ? out( ARTIKEL->ArtNr ) , ARTIKEL->Bez1 , getArtikelLagerOrt(), ;
          str( ARTIKEL->LageBest , 9 , 2), " _________"
      endif
      i++
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  drucker("OFF")
  Umgebung(LOAD)
RETURN
  /* EOP honsBeiInvListe */


  /** merkt sich rekursiv die zugeh�rigen Baugruppen/Oberartikel und Mengen */
function rekHonsBeiArtikel(mArtNr,alleBaugruppen)
LOCAL resultSet,miki,honsel:=0
LOCAL merkSatz,temp
LOCAL Zeile:=0

  ARTIKEL->(dbseek(mArtNr))
  // keine X-Artikel
  if getArtikelArt()=="X"
    return {0,0}
  endif
  miki:=ARTIKEL->LageBest

  if getArtikelArt()<>"B" .and.ARTIKEL->KonsigBest<>0
    honsel:=ARTIKEL->KonsigBest
  endif

  // suche OberArtikel
  AVPOST->(dbseek(ARTIKEL->ArtNr))
  do while ! AVPOST->(eof()) .and. AVPOST->ArtNr==MArtNr
    if left(AVPOST->AvNr,1)<>"E" .and. ! hb_HHasKey( alleBaugruppen, AVPOST->AvNr)
      merkSatz:=AVPOST->(recno())
      temp:=rekHonsBeiArtikel(AVPOST->AvNr , @alleBaugruppen)
      AVPOST->(dbGoto((merkSatz)))

      alleBaugruppen[AVPOST->AvNr]:=temp

      miki += temp[BG_BESTAND_LG_MIKI] * AVPOST->Menge
      honsel += temp[BG_BESTAND_LG_HONSEL] * AVPOST->Menge
    endif
    AVPOST->(dbskip())
  enddo

  // f�lle Ergebnis-Set
  resultSet:=array(BG_BESTAND_LENGTH)
  resultSet[BG_BESTAND_LG_MIKI]:=miki
  resultSet[BG_BESTAND_LG_HONSEL]:=honsel

return resultSet
  /** eof */

/** need this crutch as index is too lonng otherwise (data width error) */
function isKlagerBewegung()
LOCAL result

  result:=(WARAUS_KLAG_FREMD_LS $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_LS $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_STORNO_LS $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_RUECKLIEF $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_GUTSCHR $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_RECHNR $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_RECHNR_STORNO $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_RECHNR_GUTSCHR $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_INV $ trim(WARAUS->PROGRAMM) .or.;
    WARAUS_KLAG_KORREKTUR $ trim(WARAUS->PROGRAMM) .or.;
    "Inventur 2020" $ trim(WARAUS->PROGRAMM) .or.;
    "M:Austausch" $ trim(WARAUS->PROGRAMM) .or.; // wollen wir das wirklich? ab 21.3.21 mit WARAUS_KLAG_KORREKTUR Text
  ( WARAUS_BEISTELL $ trim(WARAUS->PROGRAMM) .and. getArtikelArt()$"EB" ) )

return result
  /** eop */

  /**
  Ergebnis: bei K-Lager Bewegung => Jahr der Entnahme
  andere Bewegung      => 0
  */
Static function getKlagerBewegungJahr()
LOCAL tempNr, result

  // pr�fe ob Jahr oder/und Folgejahr mit Bewegung im letzten Jahr
  if ENTNAHME_LISTE $ RECHAUS->BestKonto .or. ENTNAHME_LISTE $ RECHAUS->BestNr
    if WARAUS_RECHNR $ WARAUS->Programm
      tempNr:=trim( substr( WARAUS->Programm , len( WARAUS_RECHNR ) + 1))
    else
      tempNr:=trim(substr( WARAUS->Programm , len( WARAUS_RECHNR_STORNO ) + 1))
    endif
    RECHAUS->(dbseek( tempNr ))
    result:=getKLagerYear()
  else
    result:=year(WARAUS->Datum)
  endif

return result
  /* eof */

  /*
  *  Auftr�ge mit Kennzeichen O = Offen, also berechnet aber noch nicht geliefert
  */
PROCEDURE AuftragsListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL bis, alt , betr:=0, aktSel:=(alias()), leerzeile
LOCAL SummeRest:=0.00,gesRest:=0.00,gespos:=0,pos:=0

  if ! open("Aufaus","Kunden","aufpost","Einheit","Artikel","BesAus","AvPost","M_MEHRF","Auftrag")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Offene Auftr�ge")

  /* Relation setzten */
  SELECT AufPost
  AUFPOST->(OrdSetFocus(3)) // Auf.Nr.+ArtNr
  select AufPost
  SET RELATION TO AUFPOST->ME INTO Einheit, to AUFPOST->ArtNr into Artikel
  // select AufAus
  // SET RELATION TO AUFAUS->kundnr INTO Kunden

  select Kunden
  go bottom
  bis:=KUNDEN->KundNr
  go top

  Message("Datei wird sortiert.   Bitte warten...")

  SELECT AufAus
  index on AUFAUS->Kundnr+AUFAUS->Aufnr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    AUFAUS->erledigt $ " O"
  dbseek(KUNDEN->KundNr , .t.)
  AUFPOST->(dbseek(AUFAUS->AufNr))

  Drucker("BS")

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  // hier noch nicht, da Menge "falsch" geparst wird
  // aadd( M->specialZeige , { chr(K_F5)+chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  // aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.AUFAUS->(eof()).and. AUFAUS->Kundnr<=bis .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Miki Plastik GMBH  ***  Offene Auftr�ge  ***  ",space(30),"vom:",getUser():date,space(48),;
      "  Seite :",str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------------------------------------------------'
    ? "KD-Nr.   Kurzname Kunde           AB-Nr. Datum   Art.Nr.  Bezeichnung                    "+;
      "ME     Bestell    bereits       Rest    Lager- Lief.  Rest-Wert"
    ? "                                  Bestell-Nr.                                              "+;
      "       Menge    gelief.      Menge  Bestand  Datum     (Euro)"
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------------------------------------------------'
    _____fixedHeader_____

    alt=trim(AUFAUS->kundnr)
    do while .not.AUFAUS->(eof()).and. AUFAUS->Kundnr<=bis .and. ;
      zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

      // ** aufsummieren des gel. Betrags
      SELECT AufPost
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr==AUFAUS->AufNr .and.;
        zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        if AUFPOST->Menge > AUFPOST->GeliefGes .and. len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE
          if upper(AUFPOST->PE)="H"
            betr:=round((AUFPOST->Menge-AUFPOST->GeliefGes)*AUFPOST->Preis/100,2)
          else
            betr:=round((AUFPOST->Menge-AUFPOST->GeliefGes)*AUFPOST->Preis,2)
          endif
          ? AUFAUS->KundNr,left(AUFAUS->KurzName,24),ZEIGE_AUFNR+AUFAUS->AufNr,AUFAUS->AufDat,;
            ZEIGE_ARTNR+AUFPOST->ArtNr,;
            left(AUFPOST->Komm1,30),EINHEIT->Text,AUFPOST->Menge,AUFPOST->GeliefGes,;
            str(AUFPOST->Menge-AUFPOST->GeliefGes,10,2),ARTIKEL->LageBest,;
            if(left(AUFPOST->KW,2)=="X1","Abruf",AUFPOST->KW),transform(betr,"@E 999,999.99")
          if AUFAUS->KundNr <> AUFAUS->V_KundNr
            KUNDEN->(dbseek(AUFAUS->V_KundNr))
            leerZeile:=.t.
            ? AUFAUS->V_KundNr,left(KUNDEN->KurzName,24)
          else
            leerZeile:=.f.
            ? space(33)
          endif
          ?? AUFAUS->BestNr

          if ! empty(AUFPOST->KW_Text)
            ?? space(24),trim(AUFPOST->KW_Text)
          endif
          if leerZeile
            ?
          endif

          summerest+=betr
          pos++
        endif
        skip
      enddo
      select Aufaus
      Stop:=stop_key()
      if ! AUFPOST->(eof()) .and. AUFPOST->AufNr==AUFAUS->AufNr
        loop
      endif
      dbskip()
      AUFPOST->(dbseek(AUFAUS->AufNr))
      if alt <> trim(AUFAUS->Kundnr)
        if pos>0
          zeile += druckeZwischenSumme(pos,summeRest)
          gesRest+=summeRest
          gespos+=pos
        endif
        alt=trim(AUFAUS->kundnr)
        summeRest:=0
        betr:=0
        pos=0
      endif
    enddo
    if AUFAUS->(eof()) .or. AUFAUS->Kundnr > bis
      if pos>0 // falls bei nur 1 Kunden noch keine Zwischensumme angezeigt wurde
        zeile += druckeZwischenSumme(pos,summeRest)
      endif
      ? space(111),"========================================"
      ? space(111),"Gesamt:",str(gespos,4),'Position(en)',transform(gesRest,"@E 999,999,999.99")
      ? space(111),"========================================"
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  getUser():getCurrentPrintJob():endDoc()
  getUser():setCurrentPrintJob(NIL)

  cls
  close data

  M->specialZeige:=NIL

RETURN
/* EOP Auftrags_Liste */


  /* temp. Liste (s. update) basiert auf WarAusJahrList()
  *
  *  berechnet K_Lager Mind./Max Bestand f�r Honsel
  */
PROCEDURE VVGMindBest()
LOCAL gefertigt:=0,extern:=0,ges_extern:=0,ges_gefertigt:=0
LOCAL erst:=.t.
LOCAL GetList:={} , erstBewegung, wochen, mindBestandMenge
LOCAL ZeitRaum:=val(getProperty("Miki.mindestbestand.zeitraum","260"))
LOCAL startDatum:=getUser():date - (zeitraum * 7)
LOCAL printBuffer:=printBuffer():new()
LOCAL Bed:={ || left(ARTIKEL->KonsigKdNr,5) == "10167" .and. getArtikelArt()=="B"}

  if ! open( "Waraus",{"Artikel",.t.},"Einheit" )
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  backup("Artikel")
  Select Artikel
  ordCondSet( bed, bed,,,,, RECNO(),,,,,, .T.,,,,, .T.,, .T. )
  ordCreate(, "TempTransNtx", "ARTIKEL->ArtNr", {|| ARTIKEL->ArtNr}, )

  Message("Berechne Mindestbestand K-Lager VVG.  Bitte warten...       @ESC@=Abbruch")

  select Waraus
  index on WARAUS->ArtNr+dtos(WARAUS->Datum) tag TEMP_INDEX TEMPORARY ADDITIVE for;
    WARAUS->Datum >= HIST_START_DATE

  extern:=0
  gefertigt:=0
  mindBestandMenge:=0
  select Artikel

  go top

  Message("Liste wird erstellt.  Bitte warten...       @ESC@=Abbruch")

  do while .not.ARTIKEL->(eof())

    @ Maxrow(),0 say ARTIKEL->ArtNr
    if erst

      WARAUS->(dbseek(ARTIKEL->ArtNr))

      mindBestandMenge:=0
      ges_extern:=ges_gefertigt:=0
      erstBewegung:=NIL

      EINHEIT->(dbseek(ARTIKEL->ME))

      if WARAUS->(eof())
        ARTIKEL->(dbskip())
        loop
      endif

      erst:=.f.
    endif

    // merke Datum der 1. Bewegung
    if erstBewegung == nil .and. WARAUS->Datum >= startDatum
      erstBewegung:=WARAUS->Datum
    endif

    // seit 12.3.2014 ohne Fertig.Meldung
    // Gutschrift bei extern kann ignoriert werden, laut H. Weiland
    // elseif WARAUS_MATAUSG2 $ WARAUS->Programm .or. WARAUS_INNERNR $ WARAUS->Programm
    // .or. WARAUS_FERTIGMELD_ALT $ WARAUS->Programm .or. WARAUS_AUSGANG_ALT $ WARAUS->Programm

    // extern verkauft
    if left(WARAUS_RECHNR,5) $ WARAUS->Programm .or.;
      left(WARAUS_RECHNR_STORNO,5) $ WARAUS->Programm .or. left(WARAUS_KVNR,5) $ WARAUS->Programm

      extern+=WARAUS->Menge

      // summiere relevante Menge f�r Mindestbestandsberechnung
      if WARAUS->Datum >= startDatum
        mindBestandMenge += abs(WARAUS->Menge)
      endif

      // intern verwendet, z.B. Baugruppe
    elseif alltrim(WARAUS_INNERNR) $ WARAUS->Programm .or.;
      WARAUS_FERTIGMELD_ALT $ WARAUS->Programm .or.;
      WARAUS_BESTNR $ WARAUS->Programm // Neu seit 20180912
      if WARAUS->Menge < 0 // nur wenn Artikel intern verwendet werden!!!
        gefertigt+=WARAUS->Menge

        // summiere relevante Menge f�r Mindestbestandsberechnung
        if WARAUS->Datum >= startDatum
          mindBestandMenge += abs(WARAUS->Menge)
        endif

      endif
    endif

    WARAUS->(dbskip())

    if ARTIKEL->ArtNr<>WARAUS->ArtNr

      ges_extern+=myabs(extern)
      ges_gefertigt+=myabs(gefertigt)
      extern:=gefertigt:=0

      // neuer Artikel?
      if WARAUS->(eof()) .or. ARTIKEL->ArtNr <> WARAUS->ArtNr
        erst:=.t.

        select Artikel
        if erstBewegung == nil
          replace ARTIKEL->KonsigMind with 0
          replace ARTIKEL->KonsigMax with 0
        else
          mindBestandMenge:=abs( mindBestandMenge )
          wochen:=round( (getUser():date - erstBewegung) / 7 , 0)
          if wochen > Zeitraum
            wochen:=zeitraum
          endif
          if wochen = 0 // bei neuen Artikeln kann noch keine Aussage getroffen werden
            replace ARTIKEL->KonsigMind with 0
            replace ARTIKEL->KonsigMax with 0
          else
            replace ARTIKEL->KonsigMind with roundMaxInt( mindBestandMenge / wochen * 12 , 2 )
            replace ARTIKEL->KonsigMax with ARTIKEL->KonsigMind * 2
          endif
        endif

      endif

      // n�chster Artikel
      ARTIKEL->(dbskip())
    endif
  enddo

  close data

RETURN

  /*
  * geplanter Umsatz je KW laut Auftragsposten
  */
PROCEDURE UmsatzKWList()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.,protName
LOCAL von:="01/17", bis:="52/19", aktMonat:=""
LOCAL Summen:=hb_hash(), GesSummen:=hb_hash(), JahrSummen:=hb_hash(), abKst
LOCAL printBuffer:=printBuffer():new(), debugText, debugNr
  // LOCAL field:="ARTIKEL->Erl_Gruppe" , text:="Erl.Gruppe"
LOCAL field:="ARTIKEL->KostNr", text:="Kost.St."
LOCAL ExcelJob, export:="ABUmsatzMonat", aktJahr, aktKey, summe:=0, i , arr, key
LOCAL values7:=hb_hash(), values8:=hb_hash(), valuesSons:=hb_hash(), aMonths:=MonthNames(3)

  if ! open("Aufaus","Aufpost","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Umsatz (AB) je Kostenstelle und Monat")

  @ 9,18 to 13,50
  @ 10,20 say "KW von     :" get von picture "99/99" valid kwOkay( von ) .or. kwempty(von)
  @ 12,20 say "   bis     :" get bis picture "99/99" valid kwOkay( bis ) .or. kwempty(bis)
  Message("Kalenderwoche von/bis eingeben.     @Leer@=alle   @ESC@=Ende")
  read
  if ABBRUCH
    cls
    close data
    RETURN
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  SELECT Aufaus
  index on dtos(AUFAUS->AufDat) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    .not. AUFAUS->Aufart $ "INMPSQDB" .and.;
    kwDiff( von, getKW(AUFAUS->AufDat) ) >= 0 .and. kwDiff( bis, getKW(AUFAUS->AufDat) ) <= 0;

  go top
  export:=Druck_Bs("AB-UmsatzMonat" , .t.)

  if ABBRUCH .or. ( valtype(export) == "L" .and. ! export )
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten.")

  // Excel?
  if valtype(export)=="C"
    export:=getUser():exportPATH() + BACKSLASH + export
    excelJob:=ExcelJob():new()
    getUser():setCurrentPrintJob(excelJob)
    getUser():getCurrentPrintJob():StartDoc( export )
  endif

  Summen["7"]:=0
  Summen["8"]:=0
  Summen["Sonstige"]:=0

  JahrSummen["7"]:=0
  JahrSummen["8"]:=0
  JahrSummen["Sonstige"]:=0

  GesSummen["7"]:=0
  GesSummen["8"]:=0
  GesSummen["Sonstige"]:=0

  aktMonat:=substr(dtoc(AUFAUS->AufDat),4,2) + "/" + substr(dtoc(AUFAUS->AufDat),7,2)

  ->? "AB mit mind. 2 der " + text + " 3, 7 oder 8 gefunden:"
  ->? "==================================================="
  ->?

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.AUFAUS->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    if valtype(export)<>"C"
      ? "Miki Plastik GMBH       Umsatzliste "+von+" - "+bis,"   vom:",getUser():date,"  Seite :",;
        str(seite,3)
      ? replicate("-",93)
      ? "Monat/Jahr  Umsatz " + left(text+space(10),10) + "        7*           8*     Sonstige   "+;
        " Gesamt Jahr"
      ? replicate("-",93)
      _____fixedHeader_____
    endif
    do while .not.AUFAUS->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand
      // ? AUFAUS->AufNr,AUFAUS->AufDat
      abKst:="Sonstige"
      select AufPost
      AUFPOST->(dbseek(AUFAUS->AufNr))
      do while .not.AUFPOST->(eof()) .and. AUFPOST->AufNr == AUFAUS->AufNr.and. ! stop
        if len(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE
          ARTIKEL->(dbseek(AUFPOST->ArtNr))
          if ARTIKEL->(eof())
            ? COLOR_RED, "Artikel nicht gefunden:",AUFPOST->ArtNr,"AB:",AUFAUS->AufNr
          else
            if left(&field,1) $ "7|8"
              if abKst == "Sonstige"
                abKst:=left(&field,1)
                debugNr:=ARTIKEL->ArtNr
                debugText:="AB: " + AUFPOST->Aufnr + " Art.Nr.: "+ AUFPOST->ArtNr + " " + ;
                  ARTIKEL->Bez1 + " " + text +": " + &field
              elseif abKst <> left(&field,1)
                // Ausnahme Artiikel 2*
                if left(ARTIKEL->ArtNr,1) <> "2"
                  if left(debugNr,1) <> "2"
                    ->? debugText
                    ->?;
                      "AB: ";
                      +;
                      AUFPOST->Aufnr;
                      +;
                      " Art.Nr.: "+;
                      AUFPOST->ArtNr + " " + ARTIKEL->Bez1 + " " + text +": " + &field
                    ->?
                  endif
                  abKst:=left(&field,1)
                  debugNr:=ARTIKEL->ArtNr
                  debugText:="AB: " + AUFPOST->Aufnr + " Art.Nr.: "+ AUFPOST->ArtNr + " " + ARTIKEL->Bez1 + " " + text +": " + &field
                endif
              endif
            endif
          endif
        endif
        skip
        Stop:=stop_key()
      enddo
      Summen[abKst] += AUFAUS->Netto
      JahrSummen[abKst] += AUFAUS->Netto
      GesSummen[abKst] += AUFAUS->Netto
      select AufAus
      skip
      if val(left(aktMonat,2)) <> month(AUFAUS->AufDat) .or.;
        val(right(aktMonat,2)) <> year(AUFAUS->AufDat) - 2000
        values7[aktMonat]:=Summen["7"]
        values8[aktMonat]:=Summen["8"]
        valuesSons[aktMonat]:=Summen["Sonstige"]
        if valtype(export)<>"C"
          ? aktMonat, space(20),transStr(Summen["7"],12,0), transStr(Summen["8"],12,0),;
            transStr(Summen["Sonstige"],12,0)
        endif
        if val(right(aktMonat,2)) <> year(AUFAUS->AufDat) - 2000
          if valtype(export)<>"C"
            ? replicate("-",93)
            ? "20"+right(aktMonat,2), space(21),transStr(JahrSummen["7"],12,0), transStr(JahrSummen["8"],12,0),;
              transStr(JahrSummen["Sonstige"],12,0),transStr(sumHash(JahrSummen),12,0),"Euro"
            ?
          endif
          JahrSummen["7"]:=0
          JahrSummen["8"]:=0
          JahrSummen["Sonstige"]:=0
        endif
        aktMonat:=substr(dtoc(AUFAUS->AufDat),4,2) + "/" + substr(dtoc(AUFAUS->AufDat),7,2)
        Summen["7"]:=0
        Summen["8"]:=0
        Summen["Sonstige"]:=0
      endif
    enddo
    if valtype(export)<>"C"
      ? replicate("=",93)
      ? "Gesamt", space(19),transStr(GesSummen["7"],12,0), transStr(GesSummen["8"],12,0), ;
        transStr(GesSummen["Sonstige"],12,0),transStr(sumHash(GesSummen),12,0),"Euro"
    endif
    // Zeile:=FormFeed(Zeile,Seite)
  enddo

  // neue Excel-Liste transposed
  if valtype(export)<>"C"
    ?
    ?
    ?
  endif
  ? FETT_AN,"Jahr","KostenSt.  "
  for i:=1 to 12
    ?? aMonths[i]
    if valtype(export)<>"C" .and. i<>12 // Not Excel
      ?? space(8)
    endif
  next
  for i:=val(right(von,2)) to val(right(bis,2))
    ?? "Summen 20"+right("00"+alltrim(str(i,2)),2)
  next
  ?? FETT_AUS

  for each arr in {values7, values8, valuesSons}
    for each;
      key;
      in;
      aSort( HGetKeys(arr),,, {|a,b| right(a,2) +;
      "/" + left(a,2) < right(b,2) + "/" + left(b,2) } )
      if aktJahr <>right(key,2)
        aktJahr:=right(key,2)
        if summe <> 0
          printSumme(Summe, von, aktKey)
        endif
        ? "20"+right(key,2)
        do case
        case arr==values7
          ?? "70"
        case arr==values8
          ?? "80"
        case arr==valuesSons
          if valtype(export)=="C" // Excel
            ?? "Sonst."
          else
            ?? "So"
          endif
        endcase
        summe:=0
      endif
      ?? transstr(int(arr[key]+0.5),12,0)
      summe += arr[key]
      aktKey:=key
    next
    // fill until December
    for i:=val(left(aktKey,2))+1 to 12
      ?? 0
    next
    printSumme(Summe, von, aktKey)
    summe:=0
    ?
  next

  // Excel?
  if valtype(export)=="C"
    getUser():getCurrentPrintJob():oSheet:columns( 15 ):ColumnWidth:=17
    getUser():getCurrentPrintJob():oSheet:columns( 16 ):ColumnWidth:=17
    getUser():getCurrentPrintJob():oSheet:columns( 17 ):ColumnWidth:=17
    getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 15 )
    getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 16 )
    getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 17 )
  endif

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  protName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if AT_HOME
    Drucker("PDF","Fehler")
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    getUser():getCurrentPrintJob():endDoc()
  endif

  if valtype(export)=="C"
    Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
  endif

  cls
  close data
RETURN
/* EOP Auftrags_Liste */

static function sumHash(foo)
LOCAL result:=0, k
  for each k in foo:Keys
    result += foo[k]
  next
return result

static procedure printSumme(summe, von, bis)
LOCAL i
  for i:=val(right(von,2)) to val(right(bis,2)) - 1
    ?? 0
  next
  ?? transstr(int(Summe+0.5),12,0)
return

/** liefert den aktuellen Monat und Jahr ausgeschrieben */
static function getAktMonat(aktMonat, aktJahr)
LOCAL result:=""
LOCAL date
  if aktMonat > 0
    date:=ctod("01/"+right("00"+alltrim(str(aktMonat,2)),2)+"/2000")
    result:=mycMonth(date)+"'"+aktJahr
  endif
return left(result+space(12),12)
/** eof */



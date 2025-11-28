/* Modul:       FaktDruc.prg
*
* alles was bezgl. Fakturierung mit Ausdrucken zu tun hat
* (ausser Eti_ABLief -> Modul: Etikett.prg
*/

#include "Miki.ch"

/** folgende Abstaende sind von unten gezaehlt */
#define UNT_RAND 8 // Abstand von unt�n zur letzten druckbaren Bauchzeile

#define KLAGER_BESTNR_DRUCK (RECHAUS->Aufart=="K" .or. Kstorno) .and. ;
  len(alltrim(RECHPOST->ArtNr))>FRACHT_LAENGE


/* 
* druckt Auftrag: Posten aus Auftrag.dbf !  (alt)
*
* Parameter Ausgabe wohin
*/

FUNCTION Auftrag(Ausgabe , numAusdrucke)
LOCAL gwert:=0.00, einhNr:="",anzahl
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0
LOCAL tex1,Tex2,tex3,tex4,x
LOCAL Laenge,kom
LOCAL sonder:=.f. // SonderRabatt noch nicht gedruckt
LOCAL rahm:={ "", "" }
LOCAL postenPreis,i
LOCAL waehrung:="Euro",Adresse,Adresse2,gbsBefrDruck:=.f.,gbsWarnDruck:=.f.
LOCAL Ende,konsig:=space(7),tempText:=nil,tempGelangs:={},tempWarns:={},tempBefr:={},extraGBS:=0
LOCAL dateiName, bLastHandler, mAufNr:=AUFAUS->AufNr
LOCAL pdfInfo, objErr, paletten, frachtKosten:=0

  default Ausgabe:="D"

  // nur Email Ausgabe OHNE Druck gew�nscht?
  if Ausgabe <> "B" .and. emailOnly( EMAIL_AUFTRAG )
    Ausgabe:="PDF_QUIET"
    // Message("Info: Auftrag wird per Email verschickt.")
  endif

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(AUFAUS->Sprache)

  pdfInfo:=pdfInfo():new( if(AUFAUS->AufArt=="V",JOB_KV,JOB_AUFTRAG) , AUFAUS->AufNr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM,;
      numAusdrucke)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
  case Ausgabe=="B"
    Drucker("BS",pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // Drucker("BS")
  case Ausgabe=="PDF_QUIET" // PDF ohne Abfrage, aber mit Email
    Drucker("PDF",pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // case Ausgabe=="NOP" // PDF ohne Abfrage, sonst nix
    // Drucker("PDF",pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // neu ohne PDF: 20190126
  case Ausgabe=="NOP" // nix
    Drucker("NOP")
  endcase

  /** K-Lager Auftrag? */
  if AUFAUS->Aufart=="K"
    konsig="K-Lager"
  else
    if LAND->Sprache<>DEUTSCH
      if AUFAUS->AufArt=="V"
        konsig=getTranslation("allgemein.kostenvoranschlag",DEUTSCH)
      else
        konsig=getTranslation("allgemein.auftragsbest�tigung",DEUTSCH)
      endif
    endif
  endif

  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )

  // FormularDruck
  getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))

  // Rahmen-AB
  do case
  case AUFAUS->AufArt$"B"
    rahm[1]:=getTranslation("allgemein.rahmenauftrag",LAND->Sprache)
    rahm[2]:=getTranslation("allgemein.budget",LAND->Sprache)
  case AUFAUS->AufArt$"D"
    rahm[1]:=getTranslation("allgemein.rahmenauftrag",LAND->Sprache)
    rahm[2]:=getTranslation("allgemein.artikel",LAND->Sprache)
  case ! empty(AUFAUS->Ab_AufNr)
    rahm[1]:=getTranslation("allgemein.rahmenauftrag",LAND->Sprache)+":"
    rahm[2]:=AUFAUS->Ab_AufNr
  endcase

  if ! empty(AUFAUS->AngNr)
    if ! empty(rahm[1]) .or. ! empty(rahm[2])
      Error(ACHTUNG+"AngebotsNummer wird bisher auf Rahmen AB nicht ausgedruckt."+SCHWERER_FEHLER)
    else
      rahm[2]:=alltrim(AUFAUS->AngNr)
    endif
  endif

  Laenge:=DRUCKER->Laenge
  AUFAUS->(dbskip(0)) // Relationen aktualisieren !
  SPEDIT->(dbseek(AUFAUS->SpedNr))
  select Auftrag
  go top
  Ende:=AUFTRAG->(eof())
  do while .not. Ende
    Seite = Seite + 1
    zeile:=0

    ?;?;?;?;?

    adresse:=getAdrBlock(AUFAUS->Name,AUFAUS->Partner,AUFAUS->Strasse,AUFAUS->Zusatz, AUFAUS->Land;
      ,AUFAUS->Plz,AUFAUS->Ort)

    ? space(4),space(34),FETT_AN,space(0),konsig,FETT_AUS
    ? space(4),space(34),FETT_AN,space(0)
    if AUFAUS->AufArt=="V"
      ?? getTranslation("allgemein.kostenvoranschlag",LAND->Sprache),;
        getTranslation("allgemein.nummer",LAND->Sprache),AUFAUS->AufNr,FETT_AUS
    else
      ?? getTranslation("allgemein.auftragsbest�tigung",LAND->Sprache),;
        getTranslation("allgemein.nummer",LAND->Sprache),AUFAUS->AufNr,FETT_AUS
    endif

    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(AUFAUS->KundNr),space(1),AUFAUS->Aufdat,space(2),;
      getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5],space(23),SCHMAL_AN,rahm[1],SCHMAL_AUS
    ? space(4),Adresse[6],space(0),AUFAUS->LiefNr,AUFAUS->bestdat,space(2),SCHMAL_AN,rahm[2],;
      SCHMAL_AUS
    ? space(44),AUFAUS->bestnr
    ? space(44),AUFAUS->Ansprech
    ?
    ? space(44),AUFAUS->bestkonto

    // keine Lieferadresse falls das Werkzeug bei Miki verbleibt
    adresse:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
      AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

    if empty(AUFAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
      ? space(4),Adresse[1]
      ? space(4),Adresse[2]
      ? space(4),Adresse[3]
      ? space(4),Adresse[4],space(0),;
        if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
      ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
      ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    else
      adresse:=getAdrBlock(AUFAUS->S_Name,AUFAUS->S_Partner,AUFAUS->S_Strasse,AUFAUS->S_Zusatz,;
        AUFAUS->S_Land,AUFAUS->S_Plz,AUFAUS->S_Ort)
      adresse2:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
        AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)
      ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
      ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS
      ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
      ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
        if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache;
        ),"")
      ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
      ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
    endif
    ?
    ?
    ?

    /** Uebertrag */
    if Seite > 1
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
    endif

    /* Posten drucken */
    SELECT Auftrag
    do while Zeile < laenge - UNT_RAND - 4 .and. .not. AUFTRAG->(eof())

      // pr�fe ob Artikel Bemerkung hinterlegt -> Email
      if .not. empty(ARTIKEL->Ab_Bemerk) .and. Ausgabe $ "DP" .or. Ausgabe=="PDF_QUIET"
        email(MAIN_EMAIL,;
          "ACHTUNG: AB " + AUFAUS->AufNr + " Artikel " + out2(ARTIKEL->ArtNr) + " mit Bemerkung", ;
          "Bitte pr�fen: " + ARTIKEL->Ab_Bemerk)
      endif

      postenPreis:=AUFTRAG->Preis
      wert:=0
      do case
        /** Kommentar */
      case substr(AUFTRAG->ArtNr,1,1) $ "$*"
        if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
          exit
        endif
        zeile += Kommentar()
        if ! AUFTRAG->(eof())
          ? // Leerzeile vor n�chstem Artikel
        endif
        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(AUFTRAG->ArtNr))<=FRACHT_LAENGE

        // Zoll-Artikel mit Preis = 0 nicht ausdrucken
        if AUFTRAG->Preis == 0 .and. isZollZuschlagArtikel( AUFTRAG->ArtNr )
          skip
          loop
        endif

        // if ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
        // zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten)
        // sonder:=.t.
        // endif

        div=IIF(AUFTRAG->PE$"Hh",100,1)
        // seit 13.2.2014 Preis nicht bei K-Lager drucken
        ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
          PS_Schmal(left(getTransField("AUFTRAG->komm1"),30))
        if AUFAUS->Aufart <> "K"
          wert=ROUND(postenPreis*AUFTRAG->menge/div,2)
          ?? getMengePreis(AUFTRAG->menge,postenPreis),AUFTRAG->pe,;
            if(wert==0,"",transstr(wert,12,2))
        else
          ?? getMengePreis(AUFTRAG->menge,nil)
        endif
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        endif
        IF AUFTRAG->rabatt<>0.0 .and. wert <> 0
          ? space(38)+if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein. "+;
            "rabatt.sonder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(wert*AUFTRAG->Rabatt/100,10,2)
          wert=wert-ROUND(wert*AUFTRAG->rabatt/100,2)
        endif

        frachtKosten += wert

        // Sonder Text bei EU-Palette und Gitterbox falls Preis 0, dann nur im Tausch
        if AUFTRAG->Preis == 0 .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))), SCHMAL_AUS
          ?? getTranslation("allgemein.palette.kostenfrei",LAND->Sprache)
        endif

        /** "normaler" Artikel */
      otherwise

        // ***** neu seit 30.5.2011, z�hle Anzahl Zusatzzeilen f�r Seitenumbruch vorab
        anzahl:=2
        anzahl += zaehle_MatKz_Text(AUFTRAG->ArtNr)
        anzahl += zaehle_Artikel_Text(AUFTRAG->ArtNr)
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          anzahl+=2
        endif

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          anzahl++
        endif

        /** WarenIdentNummer */
        anzahl += printWarenIdentNummer(.t.)

        /** drucke Liefertermin aus Posten */
        if ! KWempty(AUFTRAG->KW)
          if ! empty(getTransField("AUFTRAG->komm2"))
            anzahl++
          endif
          anzahl++
        endif

        // Zusatzkommentare, z.B. �berlieferung
        if ! empty(AUFTRAG->Komm3)
          anzahl++
        endif
        if ! empty(AUFTRAG->Komm4)
          anzahl++
        endif
        if Zeile+anzahl>laenge-UNT_RAND
          exit
        endif

        // ********** ende neu


        div=IIF(AUFTRAG->PE$"Hh",100,1)
        if alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(AUFTRAG->ArtNr),SCHMAL_AUS
        endif
        ?? PS_Schmal(left(getTransField("AUFTRAG->komm1"),30))
        if AUFAUS->Aufart <> "K"
          wert=ROUND(postenPreis*AUFTRAG->menge/div,2)
          ?? getMengePreis(AUFTRAG->menge,postenPreis),AUFTRAG->pe,transStr(wert,12,2)
        else
          // K-Lager Auftrag ist immer 0 Euro
          ?? getMengePreis(AUFTRAG->menge,nil)
        endif

        if ! empty(getTransField("AUFTRAG->komm2"))
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        else
          if ! empty(ARTIKEL->Hartnr)
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
          endif
        endif

        /** merke EinheitNr */
        if empty(EinhNr)
          EinhNr:=AUFTRAG->Me
        endif

        /** drucke Mat.Kz-Text */
        zeile += drucke_MatKz_Text(AUFTRAG->ArtNr)

        /** drucke Artikel Texte */
        zeile += drucke_Artikel_Text(AUFTRAG->ArtNr)

        /** drucke Gerate-Nummer */
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          ?
          ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",AUFTRAG->GerVon
          if ! empty(AUFTRAG->GerBis)
            ?? "-",AUFTRAG->GerBis
          endif
        endif

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          ?;
            space(37)+;
            if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.sonder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(wert*AUFTRAG->Rabatt/100,10,2)

          wert=wert-ROUND(wert*ROUND(AUFTRAG->rabatt,2)/100,2)
        endif

        /** drucke WarenIdentNummer & Ursprungsland */
        zeile += printWarenIdentNummer("AufAus")

        /** drucke Liefertermin aus Posten */
        if ! KWempty(AUFTRAG->KW)
          // if ! empty(getTransField("AUFTRAG->komm2"))
          ?
          // endif
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
          getUser():getCurrentPrintJob():print( Lief_Term(AUFTRAG->KW) , .f.)
        endif

        // Zusatzkommentare, z.B. �berlieferung
        if ! empty(AUFTRAG->Komm3)
          ? SCHMAL_AN,space(len(Out(AUFTRAG->ArtNr))),SCHMAL_AUS,AUFTRAG->komm3
        endif
        if ! empty(AUFTRAG->Komm4)
          ? SCHMAL_AN,space(len(Out(AUFTRAG->ArtNr))),SCHMAL_AUS,AUFTRAG->komm4
        endif

      endcase
      gwert=gwert+wert

      skip
      /** Leerzeile zwischen 2 Artikeln */
      // changed: 31.10.2011: do while Zeile<laenge-UNT_RAND-5.and..not. AUFTRAG->(eof())
      // if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. Zeile<laenge-UNT_RAND-5.and..not. AUFTRAG->(eof())
      if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. Zeile<laenge-UNT_RAND-4 .and.;
        .not. AUFTRAG->(eof())
        ?
      endif
    enddo
    /** Ende Auftrags-Posten */

    /** Seitenumbruch ? */
    if empty(EinhNr)
      einhNr:=STANDARD_ME
    endif

    if AUFTRAG->(eof()) .and. ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
      zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten, .t.)
      sonder:=.t.
    endif

    // Berechne Gr��e GelangensBescheinigung Hinweise
    do case
    case upper(AUFAUS->EG)=="D"
      // NOP
    case upper(AUFAUS->EG)=="J"
      if AUFAUS->MwSt_KZ=="0"
        tempText:=getTranslation("AB.gelang.befreiung",LAND->Sprache)
      else
        tempText:=getTranslation("AB.gelang.erstattung.eu",LAND->Sprache)
      endif
    otherwise
      if AUFAUS->MwSt_KZ=="1"
        tempText:=getTranslation("AB.gelang.erstattung.sonst",LAND->Sprache)
      endif
    endcase

    if tempText <> NIL
      MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
      tempText:=strtran(tempText,"$MWST",transstr(MWST_KZ->Mwst,5,2)+"% = @"+;
        alltrim(transstr(round(MWST_KZ->mwst*Gwert/100,2),11,2))+" Euro@")
      tempBefr:=linewrap(tempText,COLUMN_WRAP)
      tempText:=getTranslation("AB.gelang.warnung",LAND->Sprache)
      tempWarns:=linewrap(tempText,COLUMN_WRAP)
      tempGelangs:=getOpenGelang(AUFAUS->KundNr)
    endif

    extraGBS:=0
    if ! gbsBefrDruck .and. len(tempBefr)>0
      extraGBS+=len(tempBefr)+1
    endif
    if ! gbsWarnDruck .and. len(tempGelangs)>0
      extraGBS+= len(tempGelangs)+len(tempWarns)+3
    endif

    // �bertrag oder Summe/Ende?
    if ! AUFTRAG->(eof()) .or. ;
      (zeile > Laenge - UNT_RAND-LieferTerminKopf(EinhNr,"AufAus",.t.)-extraGBS-;
      if(empty(AUFAUS->TextKz_Nr),0,1)-14)

      if AUFAUS->Aufart <> "K"
        ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
      endif

      // Platz f�r GBS Befreiungs text?
      if ! gbsBefrDruck .and. len(tempBefr)>0 .and. zeile < Laenge - UNT_RAND-len(tempBefr)-1
        zeile += printGBSBefreiung(tempBefr)
        gbsBefrDruck:=.t.
      endif

      // Platz f�r GBS Warnung text?
      if ! gbsWarnDruck .and. len(tempGelangs)>0 .and. ;
        zeile < Laenge - UNT_RAND-len(tempGelangs)-len(tempWarns)-3
        zeile += printGBSWarning(tempWarns,tempGelangs)
        gbsWarnDruck:=.t.
      endif

    else

      Ende:=.t.

      /* Liefertermine aus Auf.Kopf */
      zeile+=LieferTerminKopf(EinhNr,"AufAus")

      tex1=space(42)
      if empty(AUFAUS->IdentNr)
        tex2=space(42)
      else
        tex2=getTranslation("allgemein.identnr",LAND->Sprache,12)+AUFAUS->IdentNr
        tex2=tex2+space(42-len(tex2))
      endif
      tex3:=space(42)
      tex4:=space(42)
      ? tex1,"---------------------------------"
      mwwert=0.00
      if AUFAUS->mwst > 0.0
        ? space(42),getTranslation("allgemein.netto",LAND->Sprache,13),waehrung,;
          transStr(gwert,14,2)
        mw=transStr(AUFAUS->mwst,5,2)
        mwwert=ROUND( AUFAUS->mwst*gwert/100 ,2)
        ? space(42),mw+"% ",getTranslation("allgemein.mwst",LAND->Sprache,4)+":",waehrung,;
          transStr(mwwert,14,2)
      endif
      if AUFAUS->Aufart <> "K"
        ? tex2,getTranslation("allgemein.brutto",LAND->Sprache,13),waehrung,;
          transStr(gwert + mwwert,14,2)
        if empty(AUFAUS->FremdWaehr)
          ? tex3,"================================="
          if ! empty(tex4)
            ? SCHMAL_AN,tex4,SCHMAL_AUS
          endif
        else
          ? tex3,space(13),AUFAUS->FremdWaehr,transStr(AUFAUS->FremdSumme,15,2)
          ? tex4,"================================="
        endif
      else
        ? tex2
        ? tex3
        if ! empty(tex4)
          ? SCHMAL_AN,tex4,SCHMAL_AUS
        endif
      endif


      /** Am Ende Hinweise zum Thema GelangensBescheinigung */
      if ! gbsBefrDruck .and. len(tempBefr)>0
        zeile += printGBSBefreiung(tempBefr)
        gbsBefrDruck:=.t.
      endif

      if ! gbsWarnDruck .and. len(tempGelangs)>0
        zeile += printGBSWarning(tempWarns,tempGelangs)
        gbsWarnDruck:=.t.
      endif

      do while Zeile<laenge-UNT_RAND-9
        ?
      enddo

      kom:=Werbe_Text(AUFAUS->TextKz_Nr)
      // hier noch evtl. 1 Zeile rausholen
      x:=1
      if zeile > laenge-UNT_RAND-9
        if empty(kom[6])
          x--
        endif
      endif
      for i:=1 to x
        ? kom[i]
      next
      if AUFAUS->AufArt=="V"
        tempText:=linewrap(getTranslation("KV.danke",LAND->Sprache),35,4)
        ? kom[i++],space(5),trim(tempText[1])
        ? kom[i++],space(5),trim(tempText[2])
        ? kom[i++],space(5),trim(tempText[3])
        ? kom[i++],space(5),trim(tempText[4])
        ? kom[i++]
      else
        tempText:=linewrap(getTranslation("AB.danke",LAND->Sprache),35,4)
        ? kom[i++],space(5),trim(tempText[1])
        ? kom[i++],space(5),trim(tempText[2])
        ? kom[i++],space(5),trim(tempText[3])
        ? kom[i++],space(5),trim(tempText[4])
        ? kom[i++]
      endif

      kom[1]:=space(38)
      kom[2]:=getTranslation("allgemein.zahlkond",LAND->Sprache,20)+space(18)
      kom[3]:=getTransField("ZAHLKOND->Text")+ space(6)
      kom[4]:=getTransField("ZAHLKOND->Text2")+space(6)
      i:=1
      ? kom[i++],space(1),trim(mycenter(getTranslation("allgemein.gruesse",LAND->Sprache),35))
      ? kom[i++],space(1),trim(mycenter(getTranslation("allgemein.miki",LAND->Sprache),35))
      ? kom[i++]
      ? kom[i++]

    endif // Seitenumbruch

    /** Seitenvorschub */
    Zeile:=FormFeed(Zeile,Seite)
  enddo // .not.eof()

  /* r�ckschreiben nach Aufaus */
  /* r�ckschreiben nach ANGAUS */
  BEGIN SEQUENCE // krit. Bereich
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

    mwwert=ROUND(gwert*AUFAUS->mwst/100 ,2)
    REPLACE AUFAUS->Netto WITH Gwert
    REPLACE AUFAUS->Brutto WITH gwert + mwwert

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
  RECOVER USING objErr
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    // Fehler bereits protokolliert
    email(MAIN_EMAIL,;
      "ACHTUNG: Auftrag " +AUFAUS->AufNr+ " Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN, ;
      "Bitte dringend �berpr�fen: "+objErr:description)

    Error("ACHTUNG: Warenwert zu gro�: " + toString( gwert ) + " " + EURO_SIGN+ ;
      "||Bitte dringend �berpr�fen.",.t.)

  END SEQUENCE

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  // Email an Kunden hinterlegt?
  if Ausgabe $ "DP/PDF_QUIET" .and. ! empty( dateiName )
    sendEmails( EMAIL_AUFTRAG , dateiName )
  endif

RETURN dateiName
/* EOP Auftrag */

function printGBSBefreiung(tempBefr)
LOCAL Zeile:=0,line
  // Hinweis Befreiung und GelangensBescheinigung
  if ! getUser():getCurrentPrintJob():lastLineEmpty
    ?
  endif
  for each line in tempBefr
    ? FETT_AN,configColorPrint(line),FETT_AUS
  next
  ?
return zeile
/** eof */

static function printGBSWarning(tempWarns,tempGelangs)
LOCAL Zeile:=0,line
  /** Am Ende Hinweis, falls GelangensBescheinigung fehlt */
  if len(tempGelangs)>0
    ?
    for each line in tempWarns
      ? FETT_AN,configColorPrint(line),FETT_AUS
    next
    ?
    for each line in tempGelangs
      ? space(10),configColorPrint(line)
    next
    ?
  endif
return zeile
/** eof */


/*
*  drucken des  LS der akt. selektierten Rechnung in Rechaus
*/
FUNCTION Lieferschein(Ausgabe, anz_ls)
LOCAL summerab:=0.00 , nk:=0, anzahl
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0,i
LOCAL Laenge,Adresse,Adresse2,dateiName
LOCAL ende
LOCAL tempText,tempGelangs:={},tempWarns:={},tempBefr:={},extraGBS:=0
LOCAL gbsBefrDruck:=.f.,gbsWarnDruck:=.f.
LOCAL pdfInfo, paletten, count:=1

  default Ausgabe:="D"
  default anz_ls:=2 // Ein LS + x-1 Kopien

  // nur Email Ausgabe OHNE Druck gew�nscht?
  if Ausgabe <> "B" .and. emailOnly( EMAIL_LIEFERSCHEIN )
    Ausgabe:="PDF_QUIET"
    // qtError("Info: Lieferschein wird per Email verschickt.",.f.)
  endif

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(RECHAUS->V_Sprache)

  pdfInfo:=pdfInfo():new( JOB_LIEFERSCHEIN , RECHAUS->RechNr , .t. )

  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )

  do while count <= anz_ls
    summerab:=0.00
    nk:=0
    div:=1
    wert:=0
    rab:=0
    mwwert:=0.00
    mw:=0.00
    Seite:=0
    zeile:=0
    anzahl:=1

    do case
    case Ausgabe=="D"
      Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,if(count>1,;
        PDF_NONE,PDF_NO_CONFIRM))
    case Ausgabe=="P"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path , .t.,if(count>1,;
        PDF_NONE,PDF_NO_CONFIRM))
    case Ausgabe=="PDF_QUIET"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path , .t.,if(count>1,;
        PDF_NONE,PDF_NO_CONFIRM))
    otherwise
      Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
    endcase
    Laenge:=DRUCKER->Laenge

    if count > 1
      getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st page already
    endif

    SPEDIT->(dbseek(RECHAUS->SpedNr))
    SELECT RechPost
    SEEK RECHAUS->RechNr

    ende:=(RECHPOST->(eof()) .or. RECHPOST->RechNr<>RECHAUS->RechNr)
    do while ! Ende
      Seite = Seite + 1
      zeile:=0
      FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

      adresse:=getAdrBlock(RECHAUS->Name,RECHAUS->Partner,RECHAUS->Strasse,RECHAUS->Zusatz,;
        RECHAUS->Land,RECHAUS->Plz,RECHAUS->Ort)

      ? space(40),FETT_AN,if(LAND->Sprache<>DEUTSCH,getTranslation("allgemein.lieferschein",DEUTSCH),""),;
        FETT_AUS
      ? space(40),BREIT_AN,getTranslation("allgemein.lieferschein",LAND->Sprache),BREIT_AUS,;
        FETT_AN,getTranslation("allgemein.nummer",LAND->Sprache),RECHAUS->RechNr,FETT_AUS
      ? space(4),Adresse[1],space(23),;
        if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
      ? space(4),Adresse[2]
      ? space(4),Adresse[3],space(0),KdOut(RECHAUS->V_KundNr),space(1),RECHAUS->ReaDat,space(2),;
        getUser():id
      ? space(4),Adresse[4]
      ? space(4),Adresse[5],space(0),RECHAUS->LiefNr,RECHAUS->bestdat
      ? space(4),Adresse[6]
      ? space(44),RECHAUS->bestnr
      ? space(44),RECHAUS->Ansprech
      ?
      ? space(44),RECHAUS->bestkonto

      if empty(RECHAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
        adresse:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz, RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)
        ? space(4),Adresse[1]
        ? space(4),Adresse[2],space(11),;
          if(RECHAUS->AufNr<>SAMMEL_KZ, getTranslation("AB.nummer",LAND->Sprache)+;
          RECHAUS->AufNr,"")
        ? space(4),Adresse[3]
        ? space(4),Adresse[4],space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
        ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
      else
        adresse:=getAdrBlock(RECHAUS->S_Name,RECHAUS->S_Partner,RECHAUS->S_Strasse,RECHAUS->S_Zusatz, RECHAUS->S_Land,RECHAUS->S_Plz,RECHAUS->S_Ort)
        adresse2:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz, RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)
        ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
        ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS,space(11),;
          if(RECHAUS->AufNr<>SAMMEL_KZ,getTranslation("AB.nummer",LAND->Sprache)+RECHAUS->AufNr,"")
        ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
        ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
        ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
      endif

      ?
      ?
      ?
      SELECT RechPost

	/* Posten drucken */
      do while Zeile<laenge-UNT_RAND-3.and..not.RECHPOST->(eof()) .and.;
        RECHPOST->RechNr==RECHAUS->RechNr
        do case
	    /** Kommentar */
        case substr(RECHPOST->ArtNr,1,1) $ "$*"
          if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
            exit
          endif
          zeile += Kommentar()
          if .not.RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
            ? // Leerzeile vor n�chstem Artikel
          endif

          loop // kein skip etc. mehr notwendig !

	      /** Nur Rechn. Kommentar bzw. Menge==0 */
        case substr(RECHPOST->ArtNr,1,1)='$' .or. RECHPOST->gelief =0
	      /** NOP */

	      /** Verpackung */
        case len(alltrim(RECHPOST->ArtNr))<=FRACHT_LAENGE

          // Zoll-Artikel mit Preis = 0 nicht ausdrucken
	      if /* RECHPOST->Preis == 0 .and. */ isZollZuschlagArtikel( RECHPOST->ArtNr )
          skip
          loop
        endif

        ARTIKEL->(dbseek(RECHPOST->ArtNr))
        ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
          PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
          getMengePreis(RECHPOST->gelief,nil)
        if ! empty(getTransField("RECHPOST->komm2"))
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
        endif

        // Sonder Text bei EU-Palette und Gitterbox falls Preis 0, dann nur im Tausch
        if aContains( paletten , alltrim(RECHPOST->ArtNr))
          if RECHPOST->Preis == 0 .and. alltrim(RECHAUS->V_Land) == DEUTSCH_LAND
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))) , SCHMAL_AUS,;
              getTranslation("allgemein.palette.tausch", if(count=1,LAND->Sprache,DEUTSCH))
          else
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))) , SCHMAL_AUS,;
              getTranslation("allgemein.palette.kunde", if(count=1,LAND->Sprache,DEUTSCH))
          endif
        endif

	      /** restliche Artikel */
      otherwise
        ARTIKEL->(dbseek(RECHPOST->ArtNr))

        // ***** neu seit 30.5.2011, z�hle Anzahl Zusatzzeilen f�r Seitenumbruch vorab
        anzahl:=2
        anzahl += zaehle_MatKz_Text(RECHPOST->ArtNr)
        anzahl += zaehle_Artikel_Text(RECHPOST->ArtNr)
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          anzahl+=2
        endif

	      /** WarenIdentNummer */
        anzahl += printWarenIdentNummer(.t.)

              /* Gewicht */
        if ARTIKEL->Gewicht > 0
          anzahl++
        endif

        if Zeile+anzahl>laenge-UNT_RAND
          exit
        endif

        // ********** ende neu


        if alltrim(RECHPOST->ArtNr)==ANGEBOTS_ARTIKEL
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(RECHPOST->ArtNr),SCHMAL_AUS
        endif
        ?? PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),getMengePreis(RECHPOST->gelief)
        if ! empty(getTransField("RECHPOST->komm2"))
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
            PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
        else
          if ! empty(ARTIKEL->Hartnr)
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
          endif
        endif

	      /** ueberpruefe Mat.Kz */
        zeile += drucke_MatKz_Text(RECHPOST->ArtNr)

              /** drucke Artikel Texte */
        zeile += drucke_Artikel_Text(RECHPOST->ArtNr)

        // drucke Gewicht falls bei Artikel hinterlegt
        if ARTIKEL->Gewicht > 0
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            getTranslation("angebot.gewicht.stk",LAND->Sprache),getTransField("EINHEIT->Text")+":"
          ?? ARTIKEL->Gewicht,"kg"
        endif

	      /** drucke WarenIdentNummer & Ursprungsland */
        zeile += printWarenIdentNummer() // ohne Email

	      /** drucke Gerate-Nummer */
        if ! empty(RECHPOST->GerVon) .or. ! empty(RECHPOST->GerBis)
          ?
          ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",RECHPOST->GerVon
          if ! empty(RECHPOST->GerBis)
            ?? "-",RECHPOST->GerBis
          endif
        endif

      endcase

      skip
      if ! substr(RECHPOST->ArtNr,1,1)$'$*' // keine Leerzeile bei 2 aufeinanderfolg. Komm.
        ?
      endif
    enddo

    // Berechne Gr��e GelangensBescheinigung Hinweise
    IF upper(RECHAUS->EG)=="J"
      if RECHAUS->MwSt_KZ=="0"
        tempText:=getTranslation("AB.gelang.befreiung",LAND->Sprache)
      else
        // nicht mehr auf LS 13.8.2012
        // tempText:=getTranslation("AB.gelang.erstattung",LAND->Sprache)
        tempText:=""
      endif
      MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
      tempText:=strtran(tempText,"$MWST",transstr(MWST_KZ->Mwst,5,2)+"% = @"+;
        alltrim(transstr(round(MWST_KZ->mwst*RECHAUS->Netto/100,2),11,2))+" Euro@")
      tempBefr:=linewrap(tempText,COLUMN_WRAP)
      tempText:=getTranslation("AB.gelang.warnung",LAND->Sprache)
      tempWarns:=linewrap(tempText,COLUMN_WRAP)
      tempGelangs:=getOpenGelang(RECHAUS->KundNr)
    else
      // seit 27.10.2013 Text bei nicht-EU Kunden
      IF upper(RECHAUS->EG) <> "D" // <> J bereits oben abgefragt!
        tempText:=getTranslation("rechnung.nichtEU.text",LAND->Sprache)
        tempText:=strtran(tempText,"$DATUM",dtoc(RECHAUS->ReaDat))
        tempBefr:=linewrap(tempText,COLUMN_WRAP)
      endif
    endif

    extraGBS:=0
    if ! gbsBefrDruck .and. len(tempBefr)>0
      extraGBS+=len(tempBefr)+1
    endif
    if ! gbsWarnDruck .and. len(tempGelangs)>0
      extraGBS+= len(tempGelangs)+len(tempWarns)+3
    endif

	/** Seitenumbruch ? */
    if RECHPOST->RechNr==RECHAUS->RechNr .and. (! RECHPOST->(eof())) .or. ;
      (zeile > Laenge - UNT_RAND-14 - extraGBS)

      // // Platz f�r GBS Befreiungs text?
      // if ! gbsBefrDruck .and. len(tempBefr)>0 .and. zeile < Laenge - UNT_RAND-len(tempBefr)-2
      // zeile += printGBSBefreiung(tempBefr)
      // gbsBefrDruck:=.t.
      // endif

      // // Platz f�r GBS Warnung text?
      // if ! gbsWarnDruck .and. len(tempGelangs)>0 .and. 
      // zeile < Laenge - UNT_RAND-len(tempGelangs)-len(tempWarns)-4
      // zeile += printGBSWarning(tempWarns,tempGelangs)
      // gbsWarnDruck:=.t.
      // endif

      ? space(62),"Seite",str(seite+1,2)
    else
      ende:=.t.

	  /** Am Ende Hinweise zum Thema GelangensBescheinigung */
      if ! gbsBefrDruck .and. len(tempBefr)>0
        zeile += printGBSBefreiung(tempBefr)
        gbsBefrDruck:=.t.
      endif

      if ! gbsWarnDruck .and. len(tempGelangs)>0
        zeile += printGBSWarning(tempWarns,tempGelangs)
        gbsWarnDruck:=.t.
      endif

      do while Zeile<laenge-UNT_RAND-14
        ?
      enddo
      ? FETT_AN,SCHMAL_AN,getTranslation("LS.warnung",LAND->Sprache),SCHMAL_AUS,FETT_AUS
      tempText:=linewrap(getTranslation("LS.schluss",LAND->Sprache),72,12)
      for i:=1 to len(tempText)
        ? tempText[i]
      next
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  if count == 1
    dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  endif
  getUser():setCurrentPrintJob(NIL)

  count++
enddo

// EMail bei Kunden hinterlegt?
if Ausgabe $ "DP/PDF_QUIET" .and. ! empty( dateiName )
  sendEmails( EMAIL_LIEFERSCHEIN , dateiName )
endif

// LS per Email an Herrn Weiland (23.12.2010)
// if left(RECHAUS->KundNr,5) $ "10167|10363" .and. Ausgabe=="D"
// email(MAIN_EMAIL,;
// "Lieferschein: "+alltrim(RECHAUS->RechNr)+" Kunde: "+KdOut(RECHAUS->KundNr),;
// "Nicht K-Lager Lieferung an Honsel/VVG zur Pr�fung anbei" ,dateiName)
// endif

RETURN DateiName
/* EOP Lieferschein */


/* 
*  drucken der akt. selektierten Gutschrift in Rechaus
*/
PROCEDURE Gutschrift(Ausgabe)
LOCAL summerab:=0.00 , nk:=0 , konto:="", gwert:=0.00
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0
LOCAL Laenge
LOCAL sonder:=.f. // SonderRabatt noch nicht gedruckt
LOCAL postenPreis,Adresse
LOCAL waehrung:="Euro",konsig:=(RECHAUS->AufArt$"NM")
LOCAL storno:=(RECHAUS->AufArt$"M"),ende , faktor, bLastHandler
LOCAL pdfInfo, frachtKosten:=0, tex1, tex2
LOCAL zugferd, merke_basis:={"RABATT" => 0, "AUFSCHLAG" => 0}

  default Ausgabe:="D"

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(RECHAUS->R_Sprache)

  pdfInfo:=pdfInfo():new( JOB_GUTSCHRIFT , RECHAUS->RechNr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
  otherwise
    Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
  endcase
  Laenge:=DRUCKER->Laenge
  SELECT Rechpost
  seek RECHAUS->RechNr

  ende:=(eof() .or. RECHPOST->RechNr<>RECHAUS->RechNr)
  do while ! ende
    Seite = Seite + 1
    zeile:=0
    FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?
    select Rechaus
    if storno
      if konsig
        ? space(40),FETT_AN,"K-Lager",FETT_AUS // deutsch only
        ? space(40),FETT_AN,"GUTSCHRIFT Storno Nr."+RECHAUS->RechNr,FETT_AUS
      else
        // Gibt's noch gar nicht, nur K-Lager bisher
        ? space(40),FETT_AN,;
          if(LAND->Sprache<>DEUTSCH,getTranslation("allgemein.gutschrift",DEUTSCH),""),FETT_AUS
        ? space(40),FETT_AN,;
          getTranslation("allgemein.gutschrift",LAND->Sprache),;
          getTranslation("allgemein.storno",LAND->Sprache),;
          getTranslation("allgemein.nummer",LAND->Sprache)+RECHAUS->RechNr,FETT_AUS
      endif
    else
      if konsig
        ? space(40),FETT_AN,"K-Lager",FETT_AUS
        ? space(40),BREIT_AN,"GUTSCHRIFT",BREIT_AUS,FETT_AN," Nr."+RECHAUS->RechNr,FETT_AUS
      else
        ? space(40),FETT_AN,;
          if(LAND->Sprache<>DEUTSCH,getTranslation("allgemein.gutschrift",DEUTSCH),""),FETT_AUS
        ? space(40),BREIT_AN,getTranslation("allgemein.gutschrift",LAND->Sprache),;
          BREIT_AUS,FETT_AN,getTranslation("allgemein.nummer",LAND->Sprache)+RECHAUS->RechNr,FETT_AUS
      endif
    endif

    adresse:=getAdrBlock(RECHAUS->R_Name,RECHAUS->R_Partner,RECHAUS->R_Strasse,RECHAUS->R_Zusatz,;
      RECHAUS->R_Land,RECHAUS->R_Plz,RECHAUS->R_Ort)

    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(RECHAUS->kundnr),space(1),RECHAUS->Readat,space(2),;
      getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5],space(23),if(konsig,"",getTranslation("AB.nummer",LAND->Sprache))
    ? space(4),Adresse[6],space(0),RECHAUS->LiefNr,;
      if(ctod('  .  .  ')==RECHAUS->bestdat,space(8),RECHAUS->bestdat),;
      space(2),if(konsig,"",RECHAUS->AufNr)
    ? space(44),RECHAUS->bestnr
    ? space(44),RECHAUS->Ansprech
    ?
    ? space(44),RECHAUS->bestkonto
    if konsig
      ?
      ?
      ?
      ?
      if storno
        ?? space(44),getTranslation("rechnung.storniert",LAND->Sprache),;
          getTranslation("GS.nummer",LAND->Sprache)+RECHAUS->Storno_Nr
      endif
      ?
      ?
    else
      adresse:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz;
        , RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)

      ? space(4),Adresse[1]
      ? space(4),Adresse[2],space(0),getTransField("VERSART->Text")
      ? space(4),Adresse[3]
      ? space(4),Adresse[4]
      if storno
        ?? space(0),getTranslation("rechnung.storniert",LAND->Sprache),;
          getTranslation("GS.nummer",LAND->Sprache)+RECHAUS->Storno_Nr,
      endif
      ? space(4),Adresse[5]
      ? SPACE(4),Adresse[6]
    endif
    ?
    ?
    ?

    /** Uebertrag */
    if Seite > 1
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
    endif

    SELECT Rechpost
    /* Posten drucken */

    /** ACHTUNG Menge in RECHAUS.dbf < 0 !!! */
    do while Zeile<laenge-(UNT_RAND).and. .not.RECHPOST->(eof()) .and.;
      RECHPOST->RechNr==RECHAUS->RechNr

      postenPreis:=RECHPOST->Preis
      wert:=0
      ARTIKEL->(dbseek(RECHPOST->ArtNr))
      do case
        /** Kommentar */
      case substr(RECHPOST->ArtNr,1,1) $ "$*"
        if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
          exit
        endif
        zeile += Kommentar()
        if .not.RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
          ? // Leerzeile vor n�chstem Artikel
        endif

        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(RECHPOST->ArtNr))<= FRACHT_LAENGE
        // // Zoll-Artikel mit Preis = 0 nicht ausdrucken
        // if RECHPOST->Preis == 0 .and. isZollZuschlagArtikel( RECHPOST->ArtNr )
        // skip
        // loop
        // endif

        // if ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
        // zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten)
        // sonder:=.t.
        // endif

        div=IIF(RECHPOST->PE$"Hh",100,1)
        wert=ROUND(postenPreis*abs(RECHPOST->menge/div),2)
        ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
          PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
          getMengePreis(abs(RECHPOST->menge),postenPreis),RECHPOST->pe,;
          if(wert==0,"",transStr(wert,12,2))
        if ! empty(getTransField("RECHPOST->komm2"))
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
        endif

        // Mengenrabatt
        IF RECHPOST->rabatt<>0.0
          rab=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
          ? space(38)+if(RECHPOST->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.sond"+;
            "er",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(RECHPOST->rabatt,5,2)+"% -",transStr(rab,10,2)
          wert=wert-rab
          summerab=summerab+rab
        endif
        nk=nk+wert

        frachtKosten += wert

        /** normaler Artikel */
      otherwise
        if abs(RECHPOST->menge) > 0
          div=IIF(RECHPOST->PE$"Hh",100,1)
          wert=ROUND(postenPreis*abs(RECHPOST->menge/div),2)
          if alltrim(RECHPOST->ArtNr)==ANGEBOTS_ARTIKEL
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS
          else
            ? SCHMAL_AN,out(RECHPOST->ArtNr),SCHMAL_AUS
          endif
          ?? PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
            getMengePreis(abs(RECHPOST->menge), postenPreis),RECHPOST->pe,transStr(wert,12,2)
          if ! empty(getTransField("RECHPOST->komm2"))
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
              PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
          else
            if ! empty(ARTIKEL->Hartnr)
              ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
            endif
          endif

          /** merke Erloes-Konto */
          if empty(Konto)
            Konto=RECHPOST->Erl_Konto
          endif

          /** ueberpruefe Mat.Kz */
          zeile += drucke_MatKz_Text(RECHPOST->ArtNr)

          /** drucke Artikel Texte */
          zeile += drucke_Artikel_Text(RECHPOST->ArtNr)

          // Mengenrabatt
          IF RECHPOST->rabatt<>0.0
            rab=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            ? space(38)+if(RECHPOST->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.so"+;
              "nder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(RECHPOST->rabatt,5,2)+"% -",transStr(rab,10,2)
            wert=wert-rab
            summerab=summerab+rab
          endif

          /** drucke WarenIdentNummer & Ursprungsland */
          zeile += printWarenIdentNummer("RechAus")


        endif // menge > 0
      endcase

      gwert=gwert+wert
      skip
      /** Leerzeile zwischen 2 Artikeln */
      if ! substr(RECHPOST->ArtNr,1,1)$'$*' .and. .not.RECHPOST->(eof()) .and.;
        RECHPOST->RechNr==RECHAUS->RechNr
        ?
      endif
    enddo
    /* Rechnungs-Posten zu Ende */

    if AUFTRAG->(eof()) .and. ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
      zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten, .t., @merke_basis)
      sonder:=.t.
    endif

    /** Seitenumbruch ? */
    if RECHPOST->RechNr==RECHAUS->RechNr .and. (! RECHPOST->(eof())) .or. Zeile>laenge-UNT_RAND - 6
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
    else
      ende:=.t.

      // 2020018 added identnr
      tex1=space(42)
      if empty(RECHAUS->IdentNr)
        tex2=space(42)
      else
        tex2=getTranslation("allgemein.identnr",LAND->Sprache,12)+RECHAUS->IdentNr
        tex2=tex2+space(42-len(tex2))
      endif

      mwwert=0.00
      ? tex1,"---------------------------------"
      if RECHAUS->mwst > 0.0
        ? space(42),getTranslation("allgemein.netto",LAND->Sprache,13),waehrung,;
          transStr(gwert,14,2)

        mw=transStr(RECHAUS->mwst,5,2)
        mwwert=round(RECHAUS->mwst*gwert/100,2)
        ? space(42),mw+"% ",getTranslation("allgemein.mwst",LAND->Sprache,4)+":",waehrung,;
          transStr(mwwert,14,2)
      endif
      ? tex2,getTranslation("GS.brutto",LAND->Sprache,13),waehrung,transStr(gwert + mwwert,14,2)
      ? space(42),"================================="

      do while Zeile<laenge-UNT_RAND
        ?
      enddo
      ? space(67),konto
    endif // Seitenumbruch

    Zeile:=FormFeed(Zeile,Seite)
  enddo // .not.eof()

  /* Rechnungswerte r�ckschreiben */
  /* r�ckschreiben nach ANGAUS */
  BEGIN SEQUENCE // krit. Bereich
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

    mwwert=round(RECHAUS->mwst*gwert/100 ,2)
    faktor = if(storno,1,-1)
    replace RECHAUS->Netto WITH Gwert * faktor
    replace RECHAUS->Brutto WITH (gwert + mwwert) * faktor
    replace RECHAUS->NebenKost WITH nk * faktor
    replace RECHAUS->Rabatt WITH summerab * faktor
    // added 13.12.24 for Zugferd compliance
    if merke_basis <> NIL
      replace RECHAUS->Rab_Basis WITH merke_basis["RABATT"]
      replace RECHAUS->Auf_Basis WITH merke_basis["AUFSCHLAG"]
      replace RECHAUS->Rab_Sum WITH round(merke_basis["RABATT"] * RECHAUS->So_Rabatt/100,2)
      replace RECHAUS->Auf_Sum WITH round(merke_basis["AUFSCHLAG"] * RECHAUS->Zuschlag/100,2)
    endif

    dbcommit()
    unlock

    /* r�ckschreiben nach aufaus -> F12 */
    select Aufaus
    if AUFAUS->AufNr<>RECHAUS->AufNr
      dbseek(RECHAUS->AufNr)
    endif
    rec_lock(0)
    replace AUFAUS->Brutto WITH (gwert + mwwert) * faktor
    replace AUFAUS->erledigt with "J" // ab 27.5.15 Gutschrift immer als erledigt markiern
    dbcommit()
    unlock

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    RECOVER // USING objErr
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    // Fehler bereits protokolliert
    email(MAIN_EMAIL, "ACHTUNG: Gutschrift " +RECHAUS->RechNr+;
      " Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN, "Bitte dringend �berpr�fen.")

    Error("ACHTUNG: Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN + ;
      "||Bitte dringend �berpr�fen.",.t.)

    dbcommitall()
    dbunlockall() // is this correct?

  END SEQUENCE

  Drucker("OFF")

  // seit 19.12.2024 optionale E-Rechnung
  if Ausgabe <> "B" .and. ! empty(getProperty("System.zugferd.server",""))
    zugferd:=Invoice():new(RECHAUS->RechNr)
    zugferd:createZugferdXML(pdfInfo) // FIXME: maybe obsolete once tested
    zugferd:createZugferdInvoice(pdfInfo)
  endif

RETURN
/* EOP Gutschrift */


/* gibt LieferTermin zurueck, als Array (!) zur�ck, da evtl. schmal */
FUNCTION Lief_Term(Merk_Kw, configParameter)
LOCAL erg:=""
LOCAL aktSel:=alias()

  default configParameter:="allgemein.liefertermin"

  if .not. "*" $ Merk_Kw
    IF substr(Merk_KW,1,1)<>" "
      DO CASE
      CASE UPPER(substr(Merk_KW,1,1))="X"
        SELECT LiefTerm
        SEEK left(Merk_KW,2)
        if .not. eof()
          erg:=getTranslation(configParameter,LAND->Sprache)+" "+getTransField("LIEFTERM->Text")
        else
          erg:=getTranslation(configParameter,LAND->Sprache)+" "+;
            getTranslation("allgemein.kw",LAND->Sprache)+" "+Merk_kw
        endif
        SELECT (aktSel)
      OTHERWISE
        erg:=getTranslation(configParameter,LAND->Sprache)+" "+;
          getTranslation("allgemein.kw",LAND->Sprache)+" "+Merk_kw
      ENDCASE
    endif
  else
    erg:=getTranslation(configParameter,LAND->Sprache)+" "+(aktSel)->KW_Text
  endif

  erg:=trim( erg )

  // schmall falls zu lang
  if len( erg ) > 65
    return { SCHMAL_AN , erg , SCHMAL_AUS }
  endif

RETURN { erg }


  /** FUNCTION zaehlt die Anzahl der Zeilen von drucke_MatKz_Text()
  */
FUNCTION zaehle_MatKz_Text(ArtikelNr)
LOCAL zeile:=0
  ARTIKEL->(dbseek(ArtikelNr))
  if ! empty(ARTIKEL->MatKz)
    MAT_KZ->(dbseek(ARTIKEL->MatKz))
    if ! MAT_KZ->(eof())
      zeile:=len( HB_ATokens( getTransField( "MAT_KZ->MkzText" ) , MY_CR+MY_LF ) )
    endif
  endif
RETURN zeile
/** eof */

  /** FUNCTION drucke_MatKz_Text
  */
FUNCTION drucke_MatKz_Text(ArtikelNr)
LOCAL zeile:=0, i, max
LOCAL texte
  ARTIKEL->(dbseek(ArtikelNr))
  if ! empty(ARTIKEL->MatKz)
    MAT_KZ->(dbseek(ARTIKEL->MatKz))
    if ! MAT_KZ->(eof())
      if ! empty( getTransField( "MAT_KZ->MkzText" ) )
        texte:=HB_ATokens( getTransField( "MAT_KZ->MkzText" ) , MY_CR+MY_LF)
        max:=len(texte)
        for i:=1 to max
          if len(trim(texte[i])) > 0
            // FIXME: test out->artnr
            getUser():getCurrentPrintJob():print({SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),;
              SCHMAL_AUS,texte[i]}, .t. )
            zeile++
          endif
        next

      endif
    endif
  endif
RETURN zeile
/** eof */

/** FUNCTION zaehlt die Anzahl der Zeilen von drucke_Artikel_Text()  */
FUNCTION zaehle_Artikel_Text(ArtikelNr)
LOCAL zeile:=0
  ARTIKEL->(dbseek(ArtikelNr))
  if ! empty(ARTIKEL->ArtTextNr)
    ARTTEXT->(dbseek(ARTIKEL->ArtTextNr))
    if ! ARTTEXT->(eof())
      zeile:=len( HB_ATokens( getTransField( "ARTTEXT->Text" ) , MY_CR+MY_LF ) ) + 2
    endif
  endif
RETURN zeile
/** eof */

/** analog drucke_MatKz_Text() f�r Mat_KZ Texte  */
FUNCTION drucke_Artikel_Text(ArtikelNr)
LOCAL zeile:=0, i, max
LOCAL texte

  ARTIKEL->(dbseek(ArtikelNr))
  if ! empty(ARTIKEL->ArtTextNr)
    ARTTEXT->(dbseek(ARTIKEL->ArtTextNr))
    if ! ARTTEXT->(eof())
      if ! empty( getTransField( "ARTTEXT->Text" ) )
        getUser():getCurrentPrintJob():print({""},.t.)
        zeile++
        texte:=HB_ATokens( getTransField( "ARTTEXT->Text" ) , MY_CR+MY_LF)
        max:=len(texte)
        for i:=1 to max
          if len(trim(texte[i])) > 0
            getUser():getCurrentPrintJob():print({SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),;
              SCHMAL_AUS,texte[i]}, .t. )
            zeile++
          endif
        next
        getUser():getCurrentPrintJob():print({""},.t.)
        zeile++

      endif
    endif
  endif
RETURN zeile
/** eof */

  /*
  * druckt zugehoer. Beistellteile bei neuen Nietgeraeten
  * RECHAUS muss auf zu druckender Rechnung stehen
  *
  */
PROCEDURE BeistellTeilListe( Ausgabe , abbuchen , isStorno )
LOCAL merk_recno, merk_order
LOCAL Seite:=0,zeile:=0,aFelder

  default Ausgabe:="D"
  default abbuchen:=.t.
  default isStorno:=.f.

  RECHPOST->(dbseek(RECHAUS->RechNr))

  if ! open("Beistell", "BeisTemp")
    Error("Beistellteilliste kann nicht gedruckt werden.",.t.)
    return
  endif

  select Beistemp
  zap

  BEISTELL->(dbseek(RECHAUS->RechNr))

  // Neue Liste, hole alle Beistellteile aus St�cklisten
  if BEISTELL->(eof())

    Message("Beistellteile werden gesucht.  Bitte warten...")
    select RechPost
    do while ! eof() .and. RECHPOST->RechNr==RECHAUS->RechNr

      if ! trim(RECHPOST->ArtNr)$"$*"

        /** Neugeraete */
        ARTIKEL->(dbseek(RECHPOST->ArtNr))

        // suche Beistellteile
        select AvPost
        BeistellRek(RECHPOST->ArtNr,RECHPOST->Gelief)
        select RechPost

        // 11.4.2018: suche manuell erfasste Beistellteile in Konsig Datei
        if select("Konsig") > 0
          merk_order:=KONSIG->(indexord())
          KONSIG->(OrdSetFocus((2))) // LiefNr
          KONSIG->(dbseek( RECHPOST->LiefNr ))
          do while ! KONSIG->(eof()) .and. KONSIG->LiefNr==RECHPOST->LiefNr
            if KONSIG->GeliefGes < 0 .and. (.not. isStorno .and. KONSIG->GeliefGes <> KONSIG->Berechnet .or. ;
              (isStorno .and. KONSIG->GeliefGes == KONSIG->Berechnet))
              select Beistemp
              dbseek(KONSIG->ArtNr)
              if eof()
                ARTIKEL->(dbseek(KONSIG->ArtNr))
                add_rec(0)
                replace BEISTEMP->ArtNr with ARTIKEL->ArtNr
                replace BEISTEMP->HArtNr with ARTIKEL->HartNr
                replace BEISTEMP->KundNr with ARTIKEL->KonsigKdNr
                ARTIKEL->(dbseek(RECHPOST->ArtNr))
              endif
              replace BEISTEMP->Menge with BEISTEMP->Menge;
                + (KONSIG->GeliefGes * if(isStorno,-1,1))
              select Konsig
              rec_lock(0)
              replace KONSIG->Berechnet with if(isStorno,0,KONSIG->GeliefGes) // Nur 1x je LS
              dbcommit()
              dbunlock()
            endif
            select Konsig
            skip
          enddo
          KONSIG->(OrdSetFocus((merk_order)))
        endif

        select RechPost
      endif
      skip
    enddo
  else
    // kopiere bereits gedruckte Beistellteile
    select Beistell
    dbseek( RECHAUS->RechNr )
    do while ! BEISTELL->(eof()) .and. BEISTELL->RechNr==RECHAUS->RechNr

      // Kd. evtl. aktualisieren, falls leer
      if empty( BEISTELL->KundNr )
        ARTIKEL->(dbseek(BEISTELL->ArtNr))
        if ! empty( ARTIKEL->KonsigKdNr ) .and. rec_lock( 5)
          replace BEISTELL->KundNr with ARTIKEL->KonsigKdNr
          dbcommit()
          dbunlock()
        endif
      endif

      aFelder:=getCurrentValues()
      select BeisTemp
      add_rec(0)
      setCurrentValues( aFelder )

      select Beistell
      skip
    enddo
  endif

  /** ausdrucken ? */
  select BeisTemp
  if BEISTEMP->(reccount())>0

    // sortiere nach KundenNr und HonselNr
    index on BEISTEMP->KundNr+BEISTEMP->HartNr tag TEMP_INDEX TEMPORARY ADDITIVE
    go top

    do while ! BEISTEMP->(eof())

      // nur Email Ausgabe OHNE Druck gew�nscht?
      if emailOnly( EMAIL_BEISTELL ) .or. BEISTEMP->KundNr == RECHAUS->KundNr

        merk_recno:=BEISTEMP->(recno())

        if left(RECHAUS->KundNr,5) $ "10167|10363"
          // 1x Ausdruck als Kopie
          if Ausgabe $ "D"
            BeistellDruck( "D" , .f. , 1 , .t. )
          endif
        endif

        // 1x PDF als Orginal
        BEISTEMP->(dbgoto(merk_recno))
        BeistellDruck( "PDF" , abbuchen ) // Nur 1x abbuchen

      else

        if left(RECHAUS->KundNr,5) $ "10167|10363"
          BeistellDruck( Ausgabe , abbuchen )
        else
          BeistellDruck( "PDF" , abbuchen )
        endif

      endif


    enddo
  endif // reccount > 0

  if abbuchen
    select BeisTemp
    go top
    select Beistell
    BEISTELL->(dbseek(RECHAUS->RechNr))

    // l�sche alte
    do while ! BEISTELL->(eof()) .and. RECHAUS->RechNr == BEISTELL->RechNr
      rec_lock(0)
      delete
      skip
    enddo

    // neue anh�ngen
    append("BeisTemp",{ || .t. })
  endif
  select BeisTemp
  BEISTEMP->(OrdSetFocus((1)))
  zap

RETURN
/* EOP Beistellteilliste */

  /** internal procedure zum Drucken der Beistellteilliste
  * wir brauchen diesen Umweg, da 1x Kopie f�r Ablage gedruckt werden soll
  * und 1x Orgingal als PDF generiert */
static procedure BeistellDruck( Ausgabe , abbuchen , Anzahl, kopie)
LOCAL beiNr:=RECHAUS->RechNr
LOCAL Storno:=(RECHAUS->Aufart=="S")
LOCAL M_kundNr, Laenge
LOCAL Adresse
LOCAL Seite:=0,zeile:=0,dateiName
LOCAL pdfInfo

  pdfInfo:=pdfInfo():new( JOB_BEISTELL , alltrim(BeiNr)+"-"+left(BEISTEMP->KundNr,5) , .f. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM,;
      Anzahl)
  case Ausgabe=="P" .or. Ausgabe == "PDF"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f., PDF_NO_CONFIRM)
    // case Ausgabe=="NOP"
    // Drucker("NOP", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f., PDF_NO_CONFIRM)
    // neu 20190126
  case Ausgabe=="NOP"
    Drucker("NOP")
  otherwise
    Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
  endcase
  Laenge:=DRUCKER->Laenge
  Seite:=0

  if valtype(Kopie) == "L" .and. kopie
    getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st page already
  endif

  M_KundNr:=BEISTEMP->KundNr
  KUNDEN->(dbseek(M_KundNr))

  do while ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr

    Seite = Seite + 1
    zeile:=0
    FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

    ?
    if Storno
      ? space(40),FETT_AN,"STORNO-Beistellteil-Liste Nr."+BeiNr,FETT_AUS
    else
      ? space(40),FETT_AN,"Beistellteil-Liste Nr."+BeiNr,FETT_AUS
    endif


    adresse:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->Land;
      ,KUNDEN->Plz,KUNDEN->Ort)

    ? space(4),Adresse[1]
    ? space(4),Adresse[2],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[3],space(0),KdOut(M_KundNr),space(1),RECHAUS->ReaDat,space(2),getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5]
    ? space(4),Adresse[6]
    ?
    ? space(44),RECHAUS->bestnr
    ?
    ? space(44),RECHAUS->bestkonto

    adresse:=getAdrBlock(RECHAUS->R_Name,RECHAUS->R_Partner,RECHAUS->R_Strasse,RECHAUS->R_Zusatz,;
      RECHAUS->R_Land,RECHAUS->R_Plz,RECHAUS->R_Ort)
    ? space(4),Adresse[1]
    ? space(4),Adresse[2],space(0),"LS-Dat.:"+dtoc(RECHAUS->ReaDat)+"   Rechn.Nr.:"+RECHAUS->RechNr
    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    ?
    ?
    ?


    /* Rech.Posten drucken */
    do while Zeile<laenge-UNT_RAND-3 .and. ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr
      ARTIKEL->(dbseek(BEISTEMP->Artnr))
      EINHEIT->(dbseek(ARTIKEL->ME))
      ? SCHMAL_AN,out(BEISTEMP->ArtNr),SCHMAL_AUS,PS_Schmal(getTransField("ARTIKEL->Bez1")),;
        str(BEISTEMP->Menge,7), getTransField("EINHEIT->Text")
      ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,PS_Schmal(getTransField("ARTIKEL->bez2"))
      // abbuchen beim 1. Mal
      if abbuchen
        // if ! empty(ARTIKEL->KonsigKdNr) // ab 29.5.15 immmer, bei allen Beistellteilen
        Select Artikel
        if ! rec_lock(5)
          Error("K-Lager Bestand: "+ARTIKEL->ArtNr+" konnte nicht gebucht werden.",.t.)
        else
          aendArtKBest(BEISTEMP->Menge*(-1),WARAUS_BEISTELL + " " + BeiNr)
        endif
        // endif
        Select BeisTemp
        replace BEISTEMP->BeistellNr with BeiNr
        replace BEISTEMP->RechNr with RECHAUS->RechNr
      endif
      skip
    enddo
    if ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr
      ? space(62),"Seite "+str(seite+1,3)
    endif
    /** Blattvorschub */
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  // Email bei Kunden hinterlegt
  if Ausgabe $ "D/P/PDF" .and. ! empty( dateiName )
    if M_KundNr <> RECHAUS->KundNr
      sendEmails( EMAIL_BEISTELL , dateiName , M_KundNr )
    else
      sendEmails( EMAIL_BEISTELL , dateiName )
    endif
  endif

  // Beistellteil-Liste mit leerer KundenNr an H. Weiland schicken
  if (empty(M_KundNr) .or. M_KundNr==KDNR_LEER) .and. abbuchen // nur beim 1. Mal fr�her: Ausgabe=="D"
    email(MAIN_EMAIL,;
      "Rechnung: "+BeiNr+" - Beistellteil-Liste ohne Kunden-Nr.","Zur Pr�fung anbei",dateiName)
  endif

return
/** eop */

  /** FUNCTION Kommentar
  *
  * druckt aus akt. selektierter Datei die Kommentare
  * evtl. mehrere Saetze hintereinander
  *
  * Hinweis: nach Aufruf der Funktion KEIN Skip mehr notwendig
  *          sondern loop !
  */
FUNCTION Kommentar(print)
LOCAL Datei:=ALIAS()
LOCAL Zeile:=0,aktRec,z1,z2

  default print:=.t.

  if print

    // falls Mindest-Mengen Text, Leerzeile davor drucken
    // Vergleich an hand Text ist unsch�n :(
    if getTranslation("angebot.min.menge",DEUTSCH) $ (DATEI)->KOMM1
      ?
    endif

    do while substr((DATEI)->ArtNr,1,1)$'$*' .and. ! eof()
      z1:=getTransField(DATEI+"->komm1",LAND->Sprache)
      z2:=getTransField(DATEI+"->komm2",LAND->Sprache)
      if alltrim(z1)=="."
        ?
      else
        ? PS_Schmal(z1)
      endif
      if len(trim(z2)) > 0
        if alltrim(z2)=="."
          ?
        else
          ? PS_Schmal(z2)
        endif
      endif
      skip
    enddo

  else // nur Anzahl z�hlen

    // falls Mindest-Mengen Text, Leerzeile davor drucken
    if getTranslation("angebot.min.menge",DEUTSCH) $ (DATEI)->KOMM1
      zeile++
    endif

    aktRec:=(DATEI)->(recno())
    do while substr((DATEI)->ArtNr,1,1)$'$*' .and. ! eof()
      zeile++
      z2:=getTransField(DATEI+"->komm2",LAND->Sprache)
      if len(trim(z2)) > 0
        zeile++
      endif
      skip
    enddo
    go (aktRec)
  endif

RETURN zeile
/* EOF */

  /** 
  * druckt Liefertermine aus Auftrags-Kopf, nur DEUTSCH da obsolete (letzte AB 11/2009)
  */
Function LieferterminKopf(EinhNr,Datei,quiet)
LOCAL zeile:=0, x:=1
LOCAL feld:=datei+"->KW1",meng
LOCAL tex
LOCAL hinweis

  default quiet:=.f.

  if quiet
    set alte off
  endif

  EINHEIT->(dbseek(EinhNr))
  tex=IF(EINHEIT->(eof()),"",getTransField("EINHEIT->text"))
  do while x<=6 .and. SUBSTR(&Feld,1,1)<>" "
    meng=datei+"->Meng"+str(x,1)
    do case
    case upper(substr(&Feld,1,1))="X"
      LIEFTERM->(dbseek(left(&Feld,2)))
      if .not. LIEFTERM->(eof())
        ? "Liefertermin:",getTransField("LIEFTERM->Text"),&Meng,space(0),Tex
      else
        ? "Liefertermin: KW ",&feld,space(6),space(9),&Meng,space(0),Tex
      endif
    otherwise
      ? "Liefertermin: KW ",&feld,space(6),space(9),&Meng,space(0),Tex
    endcase
    x++
    feld=datei+"->KW"+str(x,1)
  enddo
  if x > 1
    ?
  endif

  // drucke Liefertermin Hinweis auf AB, nicht auf Angebot
  if upper(Datei)=="AUFAUS"
    hinweis:=HB_ATokens(getTranslation("AB.liefertermin.hinweis", LAND->Sprache), BACKSLASH)
    if len(hinweis) > 0
      ?
      for each tex in hinweis
        ? KLEIN_AN,tex,KLEIN_AUS
      next
    endif
  endif

  if quiet
    set alte on
  endif

return zeile
/** EOF LieferTerminKopf() */


  /* FUNCTION Werbe_Text
  *
  * Parameter: TextKz_Nr
  * R�ckgabe:  Array[7] mit gew�nschtem Text
  *            (falls numerisch -> Rabatt-Tabelle !)
  */
FUNCTION Werbe_Text(Nr)
LOCAL erg[6]
  aFill(erg,space(33))
  if ! empty(Nr)
    TEXT_KZ->(dbseek(Nr))
    erg[1]:=getTransField("TEXT_KZ->Text1")
    erg[2]:=getTransField("TEXT_KZ->Text2")
    erg[3]:=getTransField("TEXT_KZ->Text3")
    erg[4]:=getTransField("TEXT_KZ->Text4")
    erg[5]:=getTransField("TEXT_KZ->Text5")
    erg[6]:=getTransField("TEXT_KZ->Text6")
  endif
RETURN(erg)
/* EOF Werbe_Text */



  /*
  *  drucken des  LS der akt. selektierten Rechnung in Rechaus
  */
FUNCTION KonsignationsLieferschein(KonsigNr,Storno,Ausgabe,LieDatum)
LOCAL summerab:=0.00 , nk:=0
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0
LOCAL Laenge,ende,Adresse,dateiName
LOCAL pdfInfo

  default Ausgabe:="D"
  default lieDatum:=getUser():date

  /** neuer LS? */
  if valtype(KonsigNr)=="U"
    KonsigNr:=hole("KonsigNr",WRITE,.t.)
  endif

  /** Storno LS */
  if valtype(Storno)=="U"
    storno:=.f.
  endif

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(AUFAUS->Sprache)

  pdfInfo:=pdfInfo():new( JOB_K_LIEFERSCHEIN , KonsigNr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path , .t.,PDF_YES_CONFIRM)
  otherwise
    Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
  endcase
  Laenge:=DRUCKER->Laenge
  SPEDIT->(dbseek(AUFAUS->SpedNr))
  SELECT AUFTRAG
  go top

  ende:=AUFTRAG->(eof())
  do while .not. ende
    Seite = Seite + 1
    zeile:=0
    FormularDruck(getTranslation("config.formular",DEUTSCH),Seite);?;?;?;?;?

    if storno
      ? space(40),FETT_AN,"K-Lager",FETT_AUS
      ? space(40),FETT_AN,"Storno-LIEFERSCHEIN Nr. K"+alltrim(KonsigNr),FETT_AUS
    else
      ? space(40),FETT_AN,"K-Lager",FETT_AUS
      ? space(40),BREIT_AN,"LIEFERSCHEIN",BREIT_AUS,FETT_AN," Nr. K"+alltrim(KonsigNr),FETT_AUS
    endif

    adresse:=getAdrBlock(AUFAUS->Name,AUFAUS->Partner,AUFAUS->Strasse,AUFAUS->Zusatz, AUFAUS->Land;
      ,AUFAUS->Plz,AUFAUS->Ort)

    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(AUFAUS->V_KundNr),space(1),LieDatum,space(2),;
      getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5]
    ? space(4),Adresse[6],space(0),AUFAUS->LiefNr
    ? space(44),AUFAUS->bestnr
    ? space(44),AUFAUS->Ansprech
    ?
    ? space(44),AUFAUS->bestkonto

    adresse:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
      AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

    ? space(4),Adresse[1]
    ? space(4),Adresse[2],space(0),;
      if(AUFAUS->AufNr<>SAMMEL_KZ,space(3)+getTranslation("AB.nummer",LAND->Sprache)+AUFAUS->AufNr,"")
    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    ?
    ?
    ?
    // ?
    SELECT AUFTRAG

    /* Posten drucken */
    do while Zeile<laenge-UNT_RAND-4.and..not.AUFTRAG->(eof())
      do case
        /** Kommentar */
      case substr(AUFTRAG->ArtNr,1,1) $ "$*"
        // neu 20090703: drucke nur Kommentare direkt nach einem Artikel
        if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
          exit
        endif
        zeile += Kommentar()
        if ! AUFTRAG->(eof())
          ? // Leerzeile vor n�chstem Artikel
        endif

        loop // kein skip etc. mehr notwendig !

        /** Nur Rechn. Kommentar bzw. Menge==0 */
      case substr(AUFTRAG->ArtNr,1,1)='$' .or. AUFTRAG->gelief =0
        /** NOP */
        skip
        loop

      case len(alltrim(AUFTRAG->ArtNr))<=FRACHT_LAENGE
        // wird (noch) nicht gebraucht, nur innerhalb Deutschland
        // Zoll-Artikel mit Preis = 0 nicht ausdrucken
        // if AUFTRAG->Preis == 0 .and. isZollZuschlagArtikel( AUFTRAG->ArtNr )
        // skip
        // loop
        // endif

        ARTIKEL->(dbseek(AUFTRAG->ArtNr))
        ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
          PS_Schmal(left(getTransField("AUFTRAG->komm1"),30)), getMengePreis(AUFTRAG->gelief,nil)
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        endif


        /** restliche Artikel */
      otherwise
        ARTIKEL->(dbseek(AUFTRAG->ArtNr))
        if alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(AUFTRAG->ArtNr),SCHMAL_AUS
        endif
        ?? PS_Schmal(left(getTransField("AUFTRAG->komm1"),30)),getMengePreis(AUFTRAG->gelief,nil)
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        else
          if ! empty(ARTIKEL->Hartnr)
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
          endif
        endif

        /** ueberpruefe Mat.Kz */
        zeile += drucke_MatKz_Text( AUFTRAG->ArtNr )

        /** drucke Artikel Texte */
        zeile += drucke_Artikel_Text(AUFTRAG->ArtNr)

        /** Drucke Best.Nr aus Auftragskopf */
        // AUFAUS->(dbseek(AUFTRAG->AufNr))
        // if !AUFAUS->(eof()) .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
        // ?
        // ? space(len(out(ARTIKEL->ArtNr))),"Bestellnummer:",AUFAUS->BestNr
        // endif

        /** drucke Gerate-Nummer */
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          ?
          ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",AUFTRAG->GerVon
          if ! empty(AUFTRAG->GerBis)
            ?? "-",AUFTRAG->GerBis
          endif
        endif


      endcase

      select Auftrag
      skip
      if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. Zeile<laenge-UNT_RAND-4
        ?
      endif
    enddo

    /** Seitenumbruch ? */
    if (! AUFTRAG->(eof())) .or. Zeile>laenge-UNT_RAND-12
      ? space(62),"Seite",str(seite+1,2)
    else
      ende:=.t.
      do while Zeile<laenge-UNT_RAND-12
        ?
      enddo
      ?
      ? "                                        Unterschrift bei Abholung         "
      ? "                                        -------------------------         "
      ? "                                                                          "
      ? "                                                                          "
      ? "                                        .................................."
      ?
      ? "Die Ware bleibt bis zur vollst�ndigen   Unterschrift Empfangsbest�tigung"
      ? "Bezahlung unser Eigentum.               ----------------------------------"
      ? "Im �brigen gelten unsere Ihnen                                            "
      ? "bekannten Verkaufs- und                                                   "
      ? "Lieferbedingungen                       .................................."
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo


  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  // LS per Email an Herrn Weiland (23.12.2010)
  if Ausgabe=="D"
    email(MAIN_EMAIL,;
      "K-Lager Lieferschein: "+alltrim(KonsigNr)+" Kunde: "+KdOut(AUFAUS->KundNr),;
      "Zur Pr�fung anbei",dateiName)
  endif

RETURN KonsigNr
/* EOP KonsignationsLieferschein */



  /* 
  *  drucken der akt. selektierten Rechnung in Rechaus
  *  ACHTUNG: hier wird aus Rechpost.dbf NICHT aus Auftrag.dbf gedruckt !
  *           (einfacher wg. Druck-wiederholung !)
  *
  *  Parameter:   Abbuch:        "1"      Posten in Artikel.dbf abbuchen
  *                              "2"      ohne Abbuchen, mit Posten
  *                              "3"      ohne Abbuchen, ohne Posten
  *                              "Q"      Sammelrechnung Repa (obsolete)
  */

  // FIXME: kstorno scheinbar obsoelete 20.1.2016

FUNCTION Rechnung(Abbuch,KStorno,Ausgabe,buchhaltung)
LOCAL summerab:=0.00 , nk:=0 ,gwert:=0.00, Konto,ktoAlle:=.t.
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0, KstSt:="  "
LOCAL TEX
LOCAL sonder:=.f. // SonderRabatt noch nicht gedruckt
LOCAL Laenge,Debug_rechNr
LOCAL rahm:={ "", "" }
LOCAL postenPreis
LOCAL waehrung:="Euro",okay:=.f.,Adresse,rahmAbText:={}
LOCAL warausText,Ende,i
LOCAL Storno:=(RECHAUS->Aufart=="S"),anz:=1
LOCAL merkFilter,merkSatz,merkABNr,merkAbrufNr
LOCAL aktRec,aktOrd,tempText,dateiName , bLastHandler
LOCAL gbsBefrDruck:=.f.,gbsWarnDruck:=.f.,tempGelangs:={},tempWarns:={},tempBefr:={},extraGBS:=0
LOCAL pdfInfo,zkInfo, paletten, anzZoll, frachtKosten:=0
LOCAL zugferd, merke_basis:={"RABATT" => 0, "AUFSCHLAG" => 0}

  default KStorno:=.f.
  default Ausgabe:="D"
  default buchhaltung:=.f.

  // nur Email Ausgabe OHNE Druck gew�nscht?
  if Ausgabe <> "B" .and. emailOnly( EMAIL_RECHNUNG ) .and. ! buchhaltung
    Ausgabe:="PDF_QUIET"
    if Abbuch == "1" // nur 1x warnen
      // qtError("Info: Rechnung wird per Email verschickt.",.f.)
    endif
  endif

  select RechAus
  dbskip(0) // relation auf z.B. Text_Kz gesetzt
  Debug_RechNr:=RECHAUS->RechNr

  // is this already a GelangensBescheinigungs-Rechnung? -> No need to print warning again
  // ACHTUNG dies ist ein KZ ob der Hinweis bereits gedruckt wurde
  // muss also .t. sein, damit nicht mehr gedruckt wird
  gbsWarnDruck:=gbsBefrDruck:=(RECHAUS->GelKZ=="J") .or. Kstorno .or. Storno

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(AUFAUS->R_Sprache)

  // moved from top 20090404
  SPEDIT->(dbseek(AUFAUS->SpedNr))
  tex:=Werbe_Text(RECHAUS->TextKz_Nr)

  /** ueberpruefe ob relevante Posten vorhanden (keine 0-Rechnung !!!) */
  SELECT RechPost
  seek RECHAUS->RechNr
  do while RECHPOST->RechNr==RECHAUS->RechNr .and. ! eof() .and.;
    (! okay .or. Abbuch=="1" )

    // Null-Rechnung ?
    if RECHPOST->gelief<>0 .and. ! okay
      okay:=.t.
    endif

    // // Zusatz Nietgerate
    // if (Abbuch=="1") .and. len(alltrim(RECHPOST->ArtNr))> FRACHT_LAENGE
    // ZUSATZ->(dbseek(RECHPOST->ArtNr))
    // if ! ZUSATZ->(eof())
    // ZusatzNr:=RECHPOST->ArtNr
    // Endif
    // endif
    skip
  enddo
  if ! okay
    RETURN "" // FIXME: was ist hier korrekt?
  endif
  seek RECHAUS->RechNr

  pdfInfo:=pdfInfo():new( JOB_RECHNUNG , RECHPOST->RechNr , Abbuch == "1" ) // nur der 1. Druck l�scht altes pdf

  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )

  do case
  case Ausgabe=="D"
    if buchhaltung
      if Abbuch == "3" .or. Abbuch == "2"
        anz:=1
      else
        anz:=2
      endif
      Drucker("ON",pdfInfo:getLocalizedName( LAND->Sprache , "-Buch") , pdfInfo:path ,.f.,PDF_NONE;
        ,anz)
      getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st page already

    else
      // /* checken ob Kunde mehr Exemplare w�nscht ? */
      KUNDEN->(dbseek(AUFAUS->KundNr))
      if Abbuch == "2"
        anz:=1
      else
        if ! empty(KUNDEN->Re_Anz) .and. val(KUNDEN->Re_Anz)>0
          anz:=val(KUNDEN->Re_Anz)-2 // ACHTUNG: die 2 Buchaltungskopien sind fix (s.o.)
        endif
      endif

      // extra Rechnungen f�r Zoll?
      if Abbuch $ "01"
        //	if containsZollZuschlag() changed 20180707
        if ! AUFAUS->EG $ "DJ" // jetzt immer au�erhalb EU Kopien f�r Zoll-Rechnungen drucken
          anzZoll:=val( getProperty("Miki.ausland.extra.rechnungen","0") )
          anz += anzZoll
        endif
      endif

      Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path , .t.,PDF_NO_CONFIRM,;
        anz)

      if anzZoll <> NIL
        getUser():getCurrentPrintJob():startCopyText:=anzZoll + 2 // Zoll-Rechnungen alle Orginal
      endif

      if Abbuch == "2"
        getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st page already
      endif


    endif
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
  case Ausgabe=="PDF" .or. Ausgabe=="PDF_QUIET"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  otherwise
    Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
  endcase
  Laenge:=DRUCKER->Laenge

  // Kurzbezeichnung fuer Warenausgangsbuch
  if Kstorno .or. Storno
    warausText:=WARAUS_RECHNR_STORNO+RECHAUS->RechNr
  else
    warausText:=WARAUS_RECHNR+RECHAUS->RechNr
  endif

  if RECHAUS->AufArt=="K" .and. AUFAUS->InvKZ=="J"
    warausText += " (Inventur)"
  endif

  // Abrufauftrag
  if ! empty(AUFAUS->Ab_AufNr)
    rahmAbText:=getRahmABText()
  endif

  Ende:=RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
  do while .not. Ende
    Seite = Seite + 1
    zeile:=0
    getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))

    ?;?;?
    if buchhaltung
      // bei werkzeug Ident.Nr. von Rechhnungs-Empf�nger (laut Telefonat 3.1.2014 MW)
      if left(RECHAUS->V_KundNr,5) == MIKI_NR
        ? space(40),COLOR_RED,"DATEV Debitor: "+left(RECHAUS->R_KundNr,5),COLOR_DEFAULT
      else
        ? space(40),COLOR_RED,"DATEV Debitor: "+left(RECHAUS->V_KundNr,5),COLOR_DEFAULT
      endif
      ? space(40),COLOR_RED,"USt.-IdNr.   : "+RECHAUS->IdentNr,COLOR_DEFAULT
    else
      ?
      ?
    endif

    if Kstorno .or. Storno // Storno ?
      if LAND->Sprache==DEUTSCH
        ?
      else
        ? space(40),FETT_AN,getTranslation("allgemein.storno",DEUTSCH)+"-"+;
          getTranslation("allgemein.rechnung",DEUTSCH),FETT_AUS
      endif
      ? space(40),FETT_AN,;
        getTranslation("allgemein.storno",LAND->Sprache)+"-"+;
        getTranslation("allgemein.rechnung",LAND->Sprache),;
        getTranslation("allgemein.nummer",LAND->Sprache)+RECHAUS->RechNr,FETT_AUS
    else
      ? space(40),FETT_AN,;
        if(LAND->Sprache<>DEUTSCH,getTranslation("allgemein.rechnung",DEUTSCH),""),FETT_AUS
      ? space(40),BREIT_AN,;
        getTranslation("allgemein.rechnung",LAND->Sprache),;
        getTranslation("allgemein.nummer",LAND->Sprache)+RECHAUS->RechNr,BREIT_AUS
    endif

    adresse:=getAdrBlock(RECHAUS->R_Name,RECHAUS->R_Partner,RECHAUS->R_Strasse,RECHAUS->R_Zusatz,;
      RECHAUS->R_Land,RECHAUS->R_Plz,RECHAUS->R_Ort)

    if ! empty(AUFAUS->Ab_AufNr)
      rahm[1]:=getTranslation("allgemein.rahmenauftrag",LAND->Sprache)+":"
      rahm[2]:=AUFAUS->Ab_AufNr
    endif

    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(RECHAUS->R_KundNr),space(1),RECHAUS->ReaDat,space(2),;
      getUser():id
    ? space(4),Adresse[4],space(23),SCHMAL_AN,rahm[1],SCHMAL_AUS
    ? space(4),Adresse[5],space(0),RECHAUS->LiefNr
    if RECHAUS->Aufart<>"K" .and. !Kstorno // BestellDatum falls keine K-Lager Sammelrechn.
      ?? RECHAUS->bestdat
    else
      ?? space(8)
    endif
    ?? space(2),SCHMAL_AN,rahm[2],SCHMAL_AUS
    ? space(4),Adresse[6]
    ? space(44),RECHAUS->bestnr
    ? space(44),RECHAUS->Ansprech
    ?
    ? space(44),RECHAUS->bestkonto

    adresse:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz,;
      RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)

    ? space(4),Adresse[1],space(16)
    if storno
      ?? WINZIG_AN,getTranslation("rechnung.storniert",LAND->Sprache,10),WINZIG_AUS,;
        getTranslation("rechnung.nummer",LAND->Sprache,7)+RECHAUS->Storno_Nr,SCHMAL_AUS
    endif


    if RECHAUS->Aufart<>"K" .and. !Kstorno // Auftrnr falls keine K-Lager Sammelrechn.
      ? space(4),Adresse[2],space(0),getTranslation("LS.datum",LAND->Sprache),dtoc(RECHAUS->ReaDat),;
        if(RECHAUS->AufNr<>SAMMEL_KZ,space(2)+getTranslation("AB.nummer",LAND->Sprache)+RECHAUS->AufNr,"")
    else
      ? space(4),Adresse[2]
    endif

    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    ?
    ?
    ?
    /** Uebertrag */
    if Seite > 1
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
    endif

    // Falls ohne Posten setzen printjob auf Dummy
    if Abbuch == "3"
      ?
      ? COLOR_RED,"Rechnung f�r Buchhaltung --- ohne Posten ",COLOR_DEFAULT

      getUser():getCurrentPrintJob():quiet:=.t.
    endif

    SELECT RechPost
    /* Rech.Posten drucken */
    do while Zeile<laenge-UNT_RAND-if(KLAGER_BESTNR_DRUCK,8,6) ;
      .and..not.RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr

      postenPreis:=RECHPOST->Preis
      wert:=0
      do case
        /** Kommentar */
      case substr(RECHPOST->ArtNr,1,1) $ "$*"
        if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
          exit
        endif
        zeile += Kommentar()
        if .not.RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
          ? // Leerzeile vor n�chstem Artikel
        endif

        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(RECHPOST->ArtNr))<= FRACHT_LAENGE

        if RECHPOST->gelief<>0
          div=IIF(RECHPOST->PE$"Hh",100,1)
          wert=ROUND(postenPreis*RECHPOST->gelief/div,2)
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
            getMengePreis(RECHPOST->gelief,postenPreis),RECHPOST->pe,;
            if(wert==0,"",transStr(wert,12,2))
          if ! empty(getTransField("RECHPOST->komm2"))
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
              PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
          endif

          // Sonder Text bei EU-Palette und Gitterbox falls Preis 0, dann nur im Tausch
          if RECHPOST->Preis == 0 .and. aContains( paletten , alltrim(RECHPOST->ArtNr))
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
              getTranslation("allgemein.palette.kostenfrei",LAND->Sprache)
          endif

          // Mengenrabatt
          IF RECHPOST->rabatt<>0.0
            rab=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            ? space(38)+if(RECHPOST->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.so"+;
              "nder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(RECHPOST->rabatt,5,2)+"% -",transStr(rab,10,2)
            wert=wert-rab
            summerab=summerab+rab
          else
            ?
          endif
          nk=nk+wert

          frachtKosten += wert

          // drucke LS Nr zur Verpackung
          if RECHAUS->Aufart=="K" .and. ! empty(RECHPOST->LiefNr)
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,"LS Nr.:",RECHPOST->LiefNr
          endif

          /** abbuchen */
          if AbBuch=="1" .and. RECHAUS->WarKV <> "J"

            /* Kostenstelle */
            SELECT KostenSt
            ADD_REC(0)
            REPLACE KOSTENST->KostNr WITH KstSt
            REPLACE KOSTENST->AuftrNr WITH RECHPOST->RechNr
            REPLACE KOSTENST->ArtNr WITH RECHPOST->ArtNr
            REPLACE KOSTENST->KalkPr WITH ARTIKEL->KaPr
            REPLACE KOSTENST->Menge WITH RECHPOST->Gelief
            if ARTIKEL->Schluessel="H"
              REPLACE KOSTENST->Wert WITH RECHPOST->Gelief*ARTIKEL->KaPr/100
            else
              REPLACE KOSTENST->Wert WITH RECHPOST->Gelief*ARTIKEL->KaPr
            endif
            dbcommit()
            unlock

            select AvPost
            seek RECHPOST->ArtNr
            if eof()
              // seit 23.7.2010 wird keine Verpackung mehr abgebucht
              // /** Verpackung abbuchen */
              // ARTIKEL->(dbseek(RECHPOST->ArtNr))
              // ARTIKEL->(REC_LOCK(0))
              // aendArtBest(RECHPOST->Gelief*(-1),.t.,warausText)
            else
              /* St�ckliste abbuchen */
              do while ! eof() .and. RECHPOST->ArtNr==AVPOST->AvNr
                if AVPOST->Art="M" .and. AVPOST->Text="A" // Material ben�tigt
                  ARTIKEL->(dbseek(AVPOST->ArtNr))
                  ARTIKEL->(REC_LOCK(0))
                  aendArtBest(RECHPOST->Gelief*(-1)*AVPOST->Menge,warausText)
                  ARTIKEL->(dbcommit())
                  ARTIKEL->(dbunlock())

                  /* Kostenstelle */
                  SELECT KostenSt
                  ADD_REC(0)
                  REPLACE KOSTENST->KostNr WITH KstSt
                  REPLACE KOSTENST->AuftrNr WITH RECHPOST->RechNr
                  REPLACE KOSTENST->ArtNr WITH AVPOST->ArtNr
                  REPLACE KOSTENST->KalkPr WITH ARTIKEL->KaPr
                  REPLACE KOSTENST->Menge WITH RECHPOST->Gelief*(-1)*AVPOST->Menge
                  if ARTIKEL->Schluessel="H"
                    REPLACE KOSTENST->Wert WITH RECHPOST->Gelief*ARTIKEL->KaPr/100;
                      *(-1) *AVPOST->Menge
                  else
                    REPLACE KOSTENST->Wert WITH RECHPOST->Gelief*ARTIKEL->KaPr *(-1) *AVPOST->Menge
                  endif
                  dbcommit()
                  unlock
                  select AvPost
                endif
                skip
              enddo
            endif
            SELECT RechPost
          endif // Abbuch=="1"
        endif // RECHPOST->gelief<>0

        /** "normaler" Artikel */
      otherwise

        if RECHPOST->gelief <> 0
          ARTIKEL->(dbseek(RECHPOST->ArtNr))

          div=IIF(RECHPOST->PE$"Hh",100,1)
          wert=ROUND(postenPreis*RECHPOST->gelief/div,2)
          if alltrim(RECHPOST->ArtNr)==ANGEBOTS_ARTIKEL
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS
          else
            ? SCHMAL_AN,out(RECHPOST->ArtNr),SCHMAL_AUS
          endif
          ?? PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
            getMengePreis(RECHPOST->gelief,postenPreis),RECHPOST->pe,transStr(wert,12,2)
          if ! empty(getTransField("RECHPOST->komm2"))
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
              PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
          else
            if ! empty(ARTIKEL->Hartnr)
              ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,PS_Schmal(space(30))
            else
              if buchhaltung // damit das DATEV Konto unten rechtsb�ndig bleibt
                ? space(40)
              endif
            endif
          endif

          /** merke Erloes-Konto */
          if Buchhaltung
            ?? space(21),COLOR_RED+"Konto: "+RECHPOST->Erl_Konto+COLOR_DEFAULT
            if konto==NIL
              konto:=RECHPOST->Erl_Konto
            else
              if konto<>RECHPOST->Erl_Konto
                ktoAlle:=.f.
              endif
            endif
          endif

          /** ueberpruefe Mat.Kz */
          zeile += drucke_MatKz_Text(RECHPOST->ArtNr)

          /** drucke Artikel Texte */
          zeile += drucke_Artikel_Text(RECHPOST->ArtNr)

          // drucke Gewicht falls bei Artikel hinterlegt
          if ARTIKEL->Gewicht > 0
            ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
              getTranslation("angebot.gewicht.stk",LAND->Sprache),getTransField("EINHEIT->Text")+":"
            ?? ARTIKEL->Gewicht,"kg"
          endif

          /** Mengenrabatt */
          IF RECHPOST->rabatt<>0.0
            rab=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            ? space(38)+if(RECHPOST->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.so"+;
              "nder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(RECHPOST->rabatt,5,2)+"% -",transStr(rab,10,2)
            wert=wert-rab
            summerab=summerab+rab
          endif

          /** drucke Gerate-Nummer */
          if RECHAUS->Aufart<>"K" .and.;
            ( ! empty(RECHPOST->GerVon) .or. ! empty(RECHPOST->GerBis))
            ?
            ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",RECHPOST->GerVon
            if ! empty(RECHPOST->GerBis)
              ?? "-",RECHPOST->GerBis
            endif
          endif

          /** drucke WarenIdentNummer & Ursprungsland */
          zeile += printWarenIdentNummer( if(Abbuch=="1","RechAus",nil))

          /* Beim 1. Mal: Abbuchen der Posten */
          if AbBuch=="1"
            ARTIKEL->(dbseek(RECHPOST->ArtNr))
            SELECT Artikel
            if ARTIKEL->(eof())
              Error(ACHTUNG+"Artikel "+RECHPOST->ArtNr+;
                " nicht gefunden.|Wurde nicht abgebucht !!!"+SCHWERER_FEHLER)

              // 4.12.2017 doch wider rein, da Beistellteile vorher bei Fetrigmeldung ja falsch abgebucht wurden
              // jetzt also wieder zububhen
              // elseif getArtikelArt()=="B" .and. ! empty(ARTIKEL->KonsigKdNr)
              // // Ausnahme interne Beistellteile werden �ber BeistellteilListe abbgebucht
            else
              if RECHAUS->WarKV <> "J"
                KstSt:=ARTIKEL->KostNr
                // // Nietgerate Zusaetze extra verbuchen
                // if ! empty(ZusatzNr)
                // ZUSATZ->(dbseek(ZusatzNr+RECHPOST->ArtNr))
                // if ! ZUSATZ->(eof())
                // ARTIKEL->(dbseek(ZUSATZ->GerArtNr))
                // if ARTIKEL->(eof())
                // Error(ACHTUNG+"Artikel (Zusatz zu Nietger�t) "+;
                // ZUSATZ->GerArtNr+" nicht gefunden.|Wird unter Artikel "+;
                // RECHPOST->ArtNr+" abgebucht !!!"+SCHWERER_FEHLER)
                // ARTIKEL->(dbseek(RECHPOST->ArtNr))
                // endif
                // endif
                // endif

                REC_LOCK(0)
                if getArtikelArt() <> "W"
                  if RECHAUS->AufArt=="K" .or. Kstorno
                    aendArtKBest(RECHPOST->Gelief*(-1),warausText)
                  else
                    aendArtBest(RECHPOST->Gelief*(-1),warausText)

                    // Artikel im Minus? -> noch nicht fertig gemeldet,
                    // d.h. AB und LageBest von Unterartikel sind falsch
                    // Action?
                  endif
                endif

		/* herunterz�hlen der Reservierung */
                if RECHAUS->AufArt<>"K" .and. !kstorno
                  // wird bei K-Lager schon bei liefern runtergezaehlt
                  if RECHPOST->geliefges > RECHPOST->Menge

                    // Bei RahmenAB/Abrufauftrag �berlieferung r�ckschreiben
                    if ! empty(AUFAUS->Ab_AufNr)
                      aktRec:=ARTIKEL->(recno())
                      select AufPost
                      aktOrd:=AUFPOST->(indexOrd())
                      AUFPOST->(OrdSetFocus(3)) // AB Nr + ArtNr
                      dbseek(AUFAUS->Ab_AufNr+ARTIKEL->ArtNr)
                      if AUFPOST->(eof()) .or. ! rec_lock(5)
                        Error(ACHTUNG+"Artikel "+RECHPOST->ArtNr+" nicht in Rahmen-AB gefunden.||"+;
                          "        �berlieferung konnte nicht r�ckgeschrieben werden!"+SCHWERER_FEHLER)
                      else
                        replace AUFPOST->GeliefGes with AUFPOST->GeliefGes+(RECHPOST->geliefges-;
                          RECHPOST->Menge)
                        dbcommit()
                        dbunlock()
                      endif
                      AUFPOST->(OrdSetFocus(aktOrd))
                      select Artikel
                      go (aktRec)
                    endif
                  endif
                endif
              endif // not KV

              REC_LOCK(0)
              trouble("Verkauft",{ARTIKEL->ArtNr+" vorher:"+str(ARTIKEL->verkauft)+;
                " �nderung: "+str(RECHPOST->Gelief)+ " nachher: "+str(ARTIKEL->verkauft+RECHPOST->Gelief)})

              replace ARTIKEL->verkauft with ARTIKEL->verkauft+RECHPOST->Gelief
              dbcommit()
              unlock
            endif // ARTIKEL->eof()
          endif // Abbuch=="1"
          SELECT RechPost
        endif // gelief <> 0
      endcase

      // Drucke Bestellnr falls K-Lager
      if KLAGER_BESTNR_DRUCK
        AUFAUS->(dbseek(RECHPOST->AufNr))
        ?
        if ! empty(AUFAUS->BestNr)
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,"Best.Nr:"+AUFAUS->BestNr
        endif
        // AB-Nr nur drucken, falls mit LS geliefert, nicht bei GS
        if ! empty(RECHPOST->LiefNr)
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
            getTranslation("AB.nummer",LAND->Sprache)+RECHPOST->AufNr,;
            getTranslation("LS.nummer",LAND->Sprache)+RECHPOST->LiefNr
        endif
      endif

      gwert=gwert+wert
      skip
      /** Leerzeile zwischen 2 Artikeln , ausser Rep.Sammelrechnung */
      if (! substr(RECHPOST->ArtNr,1,1)$'$*') ;
        .and. (! Abbuch=="Q")
        ?
      endif
    enddo
    /** Ende Rechnungs-Posten */

    tempBefr:=linewrap(getGBSText(gWert),COLUMN_WRAP)
    tempWarns:=linewrap(getTranslation("AB.gelang.warnung",LAND->Sprache),COLUMN_WRAP)
    tempGelangs:=getOpenGelang(RECHAUS->KundNr) // always empty

    if (RECHPOST->(eof()) .or. RECHPOST->RechNr<>RECHAUS->RechNr) ;
      .and. ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
      zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten, NIL, @merke_basis)
      sonder:=.t.
    endif

    extraGBS:=0
    if ! gbsBefrDruck .and. len(tempBefr)>0
      extraGBS+=len(tempBefr)+1
    endif
    if ! gbsWarnDruck .and. len(tempGelangs)>0
      extraGBS+= len(tempGelangs)+len(tempWarns)+3
    endif

    /** Seitenumbruch ? */
    if (RECHPOST->RechNr==RECHAUS->RechNr .and. (! RECHPOST->(eof())));
      .or. (zeile > Laenge - UNT_RAND - 11 - len(rahmAbText)-extraGBS)
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)

      // Platz f�r GBS Befreiungs text?
      if ! gbsBefrDruck .and. len(tempBefr)>0 .and. zeile < Laenge - UNT_RAND-len(tempBefr)-1
        zeile += printGBSBefreiung(tempBefr)
        gbsBefrDruck:=.t.
      endif

      // Platz f�r GBS Warnung text?
      if ! gbsWarnDruck .and. len(tempGelangs)>0 .and. ;
        zeile < Laenge - UNT_RAND-len(tempGelangs)-len(tempWarns)-3
        zeile += printGBSWarning(tempWarns,tempGelangs)
        gbsWarnDruck:=.t.
      endif
    else
      Ende:=.t.

      // Falls ohne Posten setzen printjob auf Dummy
      if Abbuch == "3"
        getUser():getCurrentPrintJob():quiet:=.f.
      endif

      mwwert:=0.00
      ? tex[1]
      ? tex[2]
      if RECHAUS->mwst > 0.0
        ? tex[3]+space(9),"---------------------------------"
        ? tex[4]+space(9),getTranslation("allgemein.netto",LAND->Sprache,13),waehrung,;
          transStr(gwert,14,2)
        mw=transStr(RECHAUS->mwst,5,2)
        mwwert=ROUND(RECHAUS->mwst*gwert/100 ,2)
        ? Tex[5]+space(9),mw+"% ",getTranslation("allgemein.mwst",LAND->Sprache,4)+":",waehrung,;
          transStr(mwwert,14,2)
      else
        ? tex[3]
        ? tex[4]
        ? Tex[5]+space(9),"---------------------------------"
      endif
      ? Tex[6]+space(9),getTranslation("allgemein.brutto",LAND->Sprache,13),waehrung,;
        transStr(gwert + mwwert,14,2)
      if empty(RECHAUS->FremdWaehr)
        ? space(42),"================================="
      else
        ? space(42),space(13),RECHAUS->FremdWaehr,transStr(RECHAUS->FremdSumme,15,2)
        ? space(42),"================================="
      endif

      // Abrufauftrag
      if ! empty(AUFAUS->Ab_AufNr)
        // muss nochmal abgerufen werden, da das akt.Netto dazugez�hlt werden muss
        rahmAbText:=getRahmABText(gwert)
        for i:=1 to len(rahmAbText)
          ? rahmAbText[i]
        next
      endif

      /** Am Ende Hinweise zum Thema GelangensBescheinigung */
      if ! gbsBefrDruck .and. len(tempBefr)>0
        zeile += printGBSBefreiung(tempBefr)
        gbsBefrDruck:=.t.
      endif

      if ! gbsWarnDruck .and. len(tempGelangs)>0
        zeile += printGBSWarning(tempWarns,tempGelangs)
        gbsWarnDruck:=.t.
      endif

      do while Zeile<laenge-UNT_RAND-3
        ?
      enddo

      ? trim(getTranslation("allgemein.zahlkond",LAND->Sprache))
      ?? SCHMAL_AN,trim(getTransField("ZAHLKOND->Text")), getTransField("ZAHLKOND->Text2"),;
        SCHMAL_AUS

      zkInfo:=zkInfo():new( RECHAUS->ZkNr , round( gwert + mwwert , 2 ) )
      zkInfo:Datum:=RECHAUS->Faellig
      zkInfo:SktoDatum:=RECHAUS->SktoFaell

      tempText:=zkInfo:getText()
      for i:=1 to len(tempText)
        ? tempText[i]
      next

      ? SCHMAL_AN,space(55),SCHMAL_AUS
      if ! empty(RECHAUS->IdentNr)
        ?? getTranslation("allgemein.identnr",LAND->Sprache,12)+RECHAUS->IdentNr
      endif

      do while Zeile<laenge-UNT_RAND
        ?
      enddo
      if buchhaltung .and. konto<>NIL
        ?
        if ktoAlle
          ? space(69),COLOR_RED+konto+COLOR_DEFAULT
        else
          ? space(55),COLOR_RED+"Konto siehe Posten"+COLOR_DEFAULT // nur Deutsch auf Buchhaltungskopie!
        endif
      endif
    endif

    /** Blattvorschub */
    Zeile:=FormFeed(Zeile,Seite)
  enddo // .not. RECHPOST->(eof())

  if Debug_RechNr<>RECHAUS->RechNr // unsch�n , aber Fehler , jojo !
    Error("ACHTUNG: andere Rechnungsnummer:"+Debug_RechNr+" "+RECHAUS->RechNr+alias()+;
      SCHWERER_FEHLER)
    RECHAUS->(dbseek(Debug_RechNr))
  endif

  select Rechaus
  rec_lock(0)
  BEGIN SEQUENCE // krit. Bereich
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

    mwwert=round(RECHAUS->mwst*gwert/100 ,2)
    replace RECHAUS->Netto WITH Gwert
    replace RECHAUS->Brutto WITH (gwert + mwwert)
    replace RECHAUS->NebenKost WITH nk
    replace RECHAUS->Rabatt WITH summerab
    // added 13.12.24 for Zugferd compliance
    if merke_basis <> NIL
      replace RECHAUS->Rab_Basis WITH merke_basis["RABATT"]
      replace RECHAUS->Auf_Basis WITH merke_basis["AUFSCHLAG"]
      replace RECHAUS->Rab_Sum WITH round(merke_basis["RABATT"] * RECHAUS->So_Rabatt/100,2)
      replace RECHAUS->Auf_Sum WITH round(merke_basis["AUFSCHLAG"] * RECHAUS->Zuschlag/100,2)
    endif

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    RECOVER // USING objErr
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    // Fehler bereits protokolliert
    email(MAIN_EMAIL,;
      "ACHTUNG: Rechnung " +RECHAUS->RechNr+ " Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN, ;
      "Bitte dringend �berpr�fen.")

    Error("ACHTUNG: Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN + ;
      "||Bitte dringend �berpr�fen.",.t.)

  END SEQUENCE
  dbcommit()
  unlock

  // Budget - Abrufauftrag abbuchen
  if ! empty(AUFAUS->Ab_AufNr) .and. AbBuch=="1"
    merkSatz:=AUFAUS->(recno())
    merkAbNr:=AUFAUS->Ab_AufNr
    merkAbrufNr:=AUFAUS->AufNr
    select Aufaus
    merkFilter:=AUFAUS->(dbfilter())
    set filter to
    AUFAUS->(dbseek(merkAbNr))
    if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"BD" // .or. AUFAUS->erledigt=="J"
      Error(merkAbNr+" ist kein g�ltiger Rahmenauftrag",.t.)
    else
      if AUFAUS->AufArt$"B"
        if ! rec_lock(5)
          Error(ACHTUNG+" Rahmenauftrag "+AUFAUS->AufNr+" konnte nicht gebucht werden!"+;
            SCHWERER_FEHLER)
        else
          trouble("RahmAb",{"RahmAB: "+AUFAUS->AufNr+"  Netto:  "+str(AUFAUS->RahmBez),;
            "Abruf-AB:"+merkAbrufNr+" Netto:"+str(gwert)})
          replace AUFAUS->RahmBez with AUFAUS->RahmBez+gwert // FIXME: data width not checked
          dbcommit()
          dbunlock()
        endif
        if ! empty(merkFilter)
          set filter to &(merkFilter)
        endif
        AUFAUS->(dbgoto(Merksatz))
        if ! rec_lock(5)
          Error(TRY_AGAIN) // nicht so schlimm, da jetzt nicht mehr viel passiert
        endif
      endif
    endif
  endif

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  // hier nicht, da zuerst Beistellteilliste gedruckt werden muss
  // if Ausgabe $ "DP/PDF_QUIET" .and. ! empty( dateiName )
  // sendEmails( EMAIL_RECHNUNG , dateiName )
  // endif

  // seit 19.12.2024 optionale E-Rechnung
  if ! buchhaltung .and. Ausgabe <> "B" .and. ! empty(getProperty("System.zugferd.server",""))
    zugferd:=Invoice():new(RECHAUS->RechNr)
    zugferd:createZugferdXML(pdfInfo) // FIXME: maybe obsolete once tested
    zugferd:createZugferdInvoice(pdfInfo)
  endif

RETURN dateiName
/* EOP Rechnung */



  /** HonselNrWinzig
  *
  * Gibt die HonselNr in Winizig Font zur�ck
  * Einr�ckung bei PostScript Druck und normaler Druck verschieden
  */
Function HonselNrWinzig()
LOCAL result,nr2:=trimHonselNr(ARTIKEL->Hartnr)

  if empty(ARTIKEL->Hartnr) .and. ! empty(ARTIKEL->AltArtNr)
    nr2:=getTranslation("allgemein.alt",LAND->Sprache,4)+ARTIKEL->AltArtNr
  endif
  if DRUCKER->PostScript=="J"
    result:=left(nr2+space(19),19)+space(6)
  else
    result:=left(nr2+space(16),16)+" "
  endif
  // if DRUCKER->PostScript=="J"
  // result:=left(trimHonselNr(ARTIKEL->Hartnr)+space(19),19)+space(4)
  // else
  // result:=left(trimHonselNr(ARTIKEL->Hartnr)+space(16),16)+" "
  // endif
return result

Function trimHonselNr(hartnr)
LOCAL result:=no_blanks(Hartnr)
  if result="--"
    result:=""
  endif
return result

  /** PS_SchmalDruck
  *
  * liefert den String mit SCHMAL_AN/AUS zurueck falls Drucker = PostScript
  * ansonsten bleibt der String unver�ndert
  */
Function PS_Schmal(tempStr)
LOCAL result

  // if DRUCKER->PostScript=="J"
  // result:=space(4),SCHMAL_AN,tempStr,SCHMAL_AUS,space(1)
  // else
  // result:=tempStr
  // endif
  result:=tempStr
return result

FUNCTION getRahmABText(abrufNetto)
LOCAL aktSel:=alias()
LOCAL merkFilter:=AUFAUS->(dbfilter())
LOCAL merkSatz:=AUFAUS->(recno())
LOCAL merkAbNr:=AUFAUS->Ab_AufNr
LOCAL result:={}

  default abrufNetto:=0

  select Aufaus
  set filter to
  AUFAUS->(dbseek(merkAbNr))
  if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"BD" // .or. AUFAUS->erledigt=="J"
    trouble("root",merkAbNr+" ist kein�ltiger Rahmenauftrag")
  else
    aadd(result,"")
    aadd(result,getTranslation("AB.abruf",LAND->Sprache)+" "+merkAbNr+" "+;
      getTranslation("allgemein.vom",LAND->Sprache)+" "+dtoc(AUFAUS->AufDat))
    if AUFAUS->AufArt=="B" // Budget-Auftrag -> drucke Rest-Budget
      aadd(result,getTranslation("AB.rest",LAND->Sprache)+" "+;
        transstr(AUFAUS->Netto-AUFAUS->RahmBez-abrufNetto,11,2)+" Euro")
    endif
  endif
  set filter to &(merkFilter)
  AUFAUS->(dbgoto(Merksatz))
  select (aktSel)

return result
/** eof */

  /* 
  *  druckt eine GelangensBescheinigung zur akt. selektierten Rechnung in Rechaus
  */
FUNCTION GelangensBescheinigung(Ausgabe, Art)
LOCAL summerab:=0.00 , nk:=0
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0
LOCAL Laenge,Adresse,AdrEmpf,Adresse2,dateiName
LOCAL ende
LOCAL line,tempText,anlage,kdnr, attachments:={}
LOCAL pdfInfo

  default Art:={JOB_RECHNUNG,JOB_LIEFERSCHEIN}

  // pr�fe ob GelangensBescheinigung �berhaupt notwendig
  if trim(RECHAUS->V_Land)=="DE" .or. RECHAUS->Netto==0 .or. RECHAUS->MwSt_KZ<>"0"
    return ""
  endif
  LAND->(dbseek(left(RECHAUS->V_Land,2)))
  if LAND->EU<>"J"
    return ""
  endif

  default Ausgabe:="D"

  // nur Email Ausgabe OHNE Druck gew�nscht?
  if Ausgabe <> "B" .and. emailOnly( EMAIL_GBS )
    Ausgabe:="PDF_QUIET"
    // qtError("Info: Gelangens-Bescheinigung wird per Email verschickt.",.f.)
  endif

  for each anlage in Art // MIKI_KOPIE
    Seite:=0
    zeile:=0

    // suche Ziel Sprache je nach Empf�ngerland
    do case
    case anlage==JOB_LIEFERSCHEIN
      selLandBySprache(RECHAUS->V_Sprache)
      kdnr:=RECHAUS->V_KundNr

      AdrEmpf:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz;
        , RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)

    case anlage==JOB_RECHNUNG
      selLandBySprache(RECHAUS->R_Sprache)
      kdnr:=RECHAUS->R_KundNr

      AdrEmpf:=getAdrBlock(RECHAUS->R_Name,RECHAUS->R_Partner,RECHAUS->R_Strasse,RECHAUS->R_Zusatz;
        , RECHAUS->R_Land,RECHAUS->R_Plz,RECHAUS->R_Ort)

    otherwise
      selLandBySprache(DEUTSCH)
      kdnr:=RECHAUS->KundNr

      AdrEmpf:=getAdrBlock(RECHAUS->Name,RECHAUS->Partner,RECHAUS->Strasse,RECHAUS->Zusatz,;
        RECHAUS->Land,RECHAUS->Plz,RECHAUS->Ort)

      // getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st copy already
      // -> geht erst nach Drucker(ON...)
    endcase

    pdfInfo:=pdfInfo():new( JOB_GELANG_BESCH , alltrim(RECHAUS->RechNr)+"-"+anlage , .t. )

    do case
    case Ausgabe=="D"
      Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM,1)
    case Ausgabe=="P" .or. Ausgabe == "PDF_QUIET"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
    otherwise
      Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
    endcase
    Laenge:=DRUCKER->Laenge

    // setzte Kopie Flag bei Miki Ausdruck bereits auf 1. Seite
    if anlage <> JOB_LIEFERSCHEIN .and. anlage <> JOB_RECHNUNG
      getUser():getCurrentPrintJob():startCopyText:=1 // print Kopie on 1st copy already
    endif

    // hole aktuelle MwSt (beim Kunden ist hier keine hinterlegt)
    MWST_KZ->(dbseek("1")) // FIXME: unsch�n aber erstmal ok?!
    SPEDIT->(dbseek(AUFAUS->SpedNr))

    SELECT RechPost
    SEEK RECHAUS->RechNr

    ende:=(RECHPOST->(eof()) .or. RECHPOST->RechNr<>RECHAUS->RechNr)
    do while ! Ende
      Seite = Seite + 1
      zeile:=0
      FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

      if LAND->Sprache==DEUTSCH
        if anlage == MIKI_KOPIE
          ? space(40),SCHMAL_AN,"(Kopie f�r Ablage)",SCHMAL_AUS
        else
          ? space(40),SCHMAL_AN,"(Anlage zu "+anlage+")",SCHMAL_AUS
        endif
      else
        ? space(40),FETT_AN,getTranslation("gelang.titel",DEUTSCH),FETT_AUS,SCHMAL_AN,;
          "("+anlage+")",SCHMAL_AUS
      endif
      ? space(40),FETT_AN,COLOR_RED,getTranslation("gelang.titel",LAND->Sprache),;
        " Nr. "+RECHAUS->RechNr,FETT_AUS,COLOR_DEFAULT
      ? space(4),AdrEmpf[1],space(23),getTranslation("gelang.anlage."+anlage,LAND->Sprache)
      ? space(4),AdrEmpf[2],space(23),;
        if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
      ? space(4),AdrEmpf[3],space(0),KdOut(kdNr),space(1),RECHAUS->ReaDat,space(2),getUser():id
      ? space(4),AdrEmpf[4]
      ? space(4),AdrEmpf[5],space(0),RECHAUS->LiefNr,RECHAUS->bestdat
      ? space(4),AdrEmpf[6]
      ?
      ? space(44),RECHAUS->bestnr
      ?
      ? space(44),RECHAUS->bestkonto

      if empty(RECHAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
        adresse:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz, RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)
        ? space(4),Adresse[1]
        ? space(4),Adresse[2],space(11),;
          if(RECHAUS->AufNr<>SAMMEL_KZ,getTranslation("AB.nummer",LAND->Sprache)+RECHAUS->AufNr,"")
        ? space(4),Adresse[3]
        ? space(4),Adresse[4],space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
        ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
      else
        adresse:=getAdrBlock(RECHAUS->S_Name,RECHAUS->S_Partner,RECHAUS->S_Strasse,RECHAUS->S_Zusatz, RECHAUS->S_Land,RECHAUS->S_Plz,RECHAUS->S_Ort)
        adresse2:=getAdrBlock(RECHAUS->V_Name,RECHAUS->V_Partner,RECHAUS->V_Strasse,RECHAUS->V_Zusatz, RECHAUS->V_Land,RECHAUS->V_Plz,RECHAUS->V_Ort)
        ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
        ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS,space(11),;
          if(RECHAUS->AufNr<>SAMMEL_KZ,getTranslation("AB.nummer",LAND->Sprache)+RECHAUS->AufNr,"")
        ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
        ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
        ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
      endif
      ?
      ?
      ?
      SELECT RechPost

      if Seite==1
        MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
        tempText:=getTranslation("gelang.warnung",LAND->Sprache)
        tempText:=strtran(tempText,"$MWST",transstr(MWST_KZ->Mwst,5,2)+"% = @"+;
          alltrim(transstr(round(MWST_KZ->mwst*RECHAUS->Netto/100,2),11,2))+" Euro@")
        for each line in linewrap(tempText,COLUMN_WRAP)
          ? FETT_AN,configColorPrint(line),FETT_AUS
        next
        ?
        ?
        ?
        ?
        for each line in linewrap(getTranslation("gelang.text1",LAND->Sprache),COLUMN_WRAP)
          ? FETT_AN,configColorPrint(line),FETT_AUS
        next
        ?
        ?
        ?
        tempText:=getTranslation("gelang.datum.lieferung",LAND->Sprache)
        ? KLEIN_AN,replicate(MY_LINE_CHAR,len(tempText)),KLEIN_AUS
        ? KLEIN_AN,tempText,KLEIN_AUS
        ?
        ?
        ?
        tempText:=getTranslation("gelang.ort",LAND->Sprache)
        ? KLEIN_AN,replicate(MY_LINE_CHAR,len(tempText)),KLEIN_AUS
        ? KLEIN_AN,tempText,KLEIN_AUS
        ?
        ?
        ?
        tempText:=getTranslation("gelang.datum.bescheinigung",LAND->Sprache)
        ? KLEIN_AN,replicate(MY_LINE_CHAR,len(tempText)),KLEIN_AUS
        ? KLEIN_AN,tempText,KLEIN_AUS
        ?
        ?
        tempText:=getTranslation("gelang.unterschrift",LAND->Sprache)
        ? KLEIN_AN,replicate(MY_LINE_CHAR,len(tempText)),KLEIN_AUS
        ? KLEIN_AN,tempText,KLEIN_AUS
        ?
        Zeile:=FormFeed(Zeile,Seite)
        loop // -> next page
      elseif Seite==2
        for each line in linewrap(getTranslation("gelang.postenText",LAND->Sprache),COLUMN_WRAP)
          ? FETT_AN,configColorPrint(line),FETT_AUS
        next
      endif

      /* Posten drucken */
      do while Zeile<laenge-UNT_RAND-3.and..not.RECHPOST->(eof()) .and.;
        RECHPOST->RechNr==RECHAUS->RechNr
        do case
          /** Kommentar */
        case substr(RECHPOST->ArtNr,1,1) $ "$*"
          if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
            exit
          endif
          zeile += Kommentar()
          if .not.RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
            ? // Leerzeile vor n�chstem Artikel
          endif

          loop // kein skip etc. mehr notwendig !

          /** Nur Rechn. Kommentar bzw. Menge==0 */
        case substr(RECHPOST->ArtNr,1,1)='$' .or. RECHPOST->gelief =0
          /** NOP */

          /** Verpackung */
        case len(alltrim(RECHPOST->ArtNr))<=FRACHT_LAENGE

          ARTIKEL->(dbseek(RECHPOST->ArtNr))
          ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),;
            getMengePreis(RECHPOST->gelief,nil)
          if ! empty(getTransField("RECHPOST->komm2"))
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS,;
              PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
          endif

          /** restliche Artikel */
        otherwise
          ARTIKEL->(dbseek(RECHPOST->ArtNr))
          if alltrim(RECHPOST->ArtNr)==ANGEBOTS_ARTIKEL
            ? SCHMAL_AN,space(len(out(RECHPOST->ArtNr))),SCHMAL_AUS
          else
            ? SCHMAL_AN,out(RECHPOST->ArtNr),SCHMAL_AUS
          endif
          ?? PS_Schmal(left(getTransField("RECHPOST->komm1"),30)),getMengePreis(RECHPOST->gelief)
          if ! empty(getTransField("RECHPOST->komm2"))
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
              PS_Schmal(left(getTransField("RECHPOST->komm2"),30))
          else
            if ! empty(ARTIKEL->Hartnr)
              ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
            endif
          endif

          /** ueberpruefe Mat.Kz */
          zeile += drucke_MatKz_Text(RECHPOST->ArtNr)

          /** drucke Artikel Texte */
          zeile += drucke_Artikel_Text(RECHPOST->ArtNr)

          /** drucke Gerate-Nummer */
          if ! empty(RECHPOST->GerVon) .or. ! empty(RECHPOST->GerBis)
            ?
            ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",RECHPOST->GerVon
            if ! empty(RECHPOST->GerBis)
              ?? "-",RECHPOST->GerBis
            endif
          endif

          /** drucke WarenIdentNummer & Ursprungsland */
          zeile += printWarenIdentNummer("RechAus")

        endcase

        skip
        if ! substr(RECHPOST->ArtNr,1,1)$'$*' // keine Leerzeile bei 2 aufeinanderfolg. Komm.
          ?
        endif
      enddo

      /** Seitenumbruch ? */
      if RECHPOST->RechNr==RECHAUS->RechNr .and. (! RECHPOST->(eof())) .or. ;
        (zeile > Laenge - UNT_RAND-2)
        ? space(63),getTranslation("allgemein.seite",LAND->Sprache),str(seite+1,2)
      else
        ende:=.t.
        do while Zeile<laenge-UNT_RAND-2
          ?
        enddo
        ?
        for each line in linewrap(getTranslation("gelang.schluss",LAND->Sprache),COLUMN_WRAP)
          ? FETT_AN,line,FETT_AUS
        next
      endif
      Zeile:=FormFeed(Zeile,Seite)
    enddo

    // Drucker("Off")
    getUser():getCurrentPrintJob():endDoc()
    dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
    getUser():setCurrentPrintJob(NIL)

    if anlage;
      $ JOB_LIEFERSCHEIN + "/" + JOB_RECHNUNG + "/" + JOB_EN_LIEFERSCHEIN + "/" + JOB_EN_RECHNUNG
      aadd( attachments , dateiName )
    endif

  next

  // r�ckschreiben nach RECHAUS
  select Rechaus
  if RECHAUS->ReaDat >= ctod("01.10.2013") // GBS erst seit 2013
    rec_lock(0)
    replace RECHAUS->GelNr with RECHAUS->RechNr
    dbcommit()
    dbunlock()
  endif

  // EMails bei Kunden hinterlegt?
  if Ausgabe $ "DP/PDF_QUIET" .and. ! empty( dateiName )
    sendEmails( EMAIL_GBS , attachments )
  endif

RETURN DateiName
/* EOP GelangensBescheinigung */



/* Handlieferschein (ehemals Ausfallmuster) *********************************
*
*/
PROCEDURE HandLiefDruck(Ausgabe)
LOCAL Seite:=0,zeile:=0,Adresse
LOCAL Laenge
LOCAL tempText,i
LOCAL pdfInfo

  default Ausgabe:="D"

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(LIEFAUS->Sprache)

  pdfInfo:=pdfInfo():new( JOB_HAND_LIEFERSCHEIN , LIEFAUS->Lsnr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path , .t.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // case Ausgabe=="NOP"
    // Drucker("NOP", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // neu 20190126
  case Ausgabe=="NOP"
    Drucker("NOP")
  otherwise
    Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
  endcase

  Laenge:=DRUCKER->Laenge
  SPEDIT->(dbseek(LIEFAUS->SpedNr))
  SELECT Lieftemp
  go top

  do while .not. LIEFTEMP->(eof())
    Seite = Seite + 1
    zeile:=0
    FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

    adresse:=getAdrBlock(LIEFAUS->Name,LIEFAUS->Partner,LIEFAUS->Strasse,LIEFAUS->Zusatz, LIEFAUS-;
      >Land,LIEFAUS->Plz,LIEFAUS->Ort)

    ? space(40),FETT_AN,;
      if(LAND->Sprache<>DEUTSCH,getTranslation("allgemein.lieferschein",DEUTSCH),""),FETT_AUS
    ? space(40),BREIT_AN,getTranslation("allgemein.lieferschein",LAND->Sprache),BREIT_AUS,FETT_AN,;
      getTranslation("allgemein.nummer",LAND->Sprache)+LIEFAUS->Lsnr,FETT_AUS
    ? space(4),Adresse[1]
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(LIEFAUS->V_KundNr),space(1),LIEFAUS->AufDat,space(2),;
      getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5],space(11),LIEFAUS->bestdat
    ? space(4),Adresse[6]
    ? space(44),LIEFAUS->bestnr
    ? space(44),LIEFAUS->Ansprech
    ?
    ? space(44),LIEFAUS->bestkonto

    adresse:=getAdrBlock(LIEFAUS->V_Name,LIEFAUS->V_Partner,LIEFAUS->V_Strasse,LIEFAUS->V_Zusatz,;
      LIEFAUS->V_Land,LIEFAUS->V_Plz,LIEFAUS->V_Ort)

    ? space(4),Adresse[1]
    ? space(4),Adresse[2],space(0),;
      if(!empty(LIEFAUS->AufNr),getTranslation("AB.nummer",LAND->Sprache)+LIEFAUS->AufNr,"")
    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")

    ?
    ?
    ?
    do while Zeile<laenge-UNT_RAND-LISTE->Unt_Rand .and. .not.LIEFTEMP->(eof())
      if substr(LIEFTEMP->ArtNr,1,1)='*'
        if alltrim(LIEFTEMP->Komm1)=="."
          ?
        else
          ? PS_Schmal(getTransField("LIEFTEMP->komm1"))
        endif
        if ! empty(getTransField("LIEFTEMP->komm2"))
          if alltrim(LIEFTEMP->Komm2)=="."
            ?
          else
            ? PS_Schmal(getTransField("LIEFTEMP->komm2"))
          endif
        endif
        skip
        loop
      endif
      if substr(LIEFTEMP->ArtNr,1,1)='$' .or. LIEFTEMP->menge =0
        skip
        loop
      endif
      if alltrim(LIEFTEMP->ArtNr)==ANGEBOTS_ARTIKEL .or.;
        len(alltrim(LIEFTEMP->ArtNr))<=FRACHT_LAENGE
        ? SCHMAL_AN,space(len(out(LIEFTEMP->ArtNr))),SCHMAL_AUS
      else
        ? SCHMAL_AN,out(LIEFTEMP->ArtNr),SCHMAL_AUS
      endif
      ?? PS_Schmal(left(getTransField("LIEFTEMP->komm1"),30)),getMengePreis(LIEFTEMP->menge,nil)

      if ! empty(getTransField("LIEFTEMP->komm2"))
        ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
          PS_Schmal(left(getTransField("LIEFTEMP->komm2"),30))
      else
        if ! empty(ARTIKEL->Hartnr)
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
        endif
      endif

      /** ueberpruefe Mat.Kz */
      zeile += drucke_MatKz_Text(LIEFTEMP->ArtNr)

      /** drucke Artikel Texte */
      zeile += drucke_Artikel_Text(LIEFTEMP->ArtNr)

      /** drucke WarenIdentNummer & Ursprungsland */
      zeile += printWarenIdentNummer("LiefAus")

      ?
      skip
    enddo

    if LIEFTEMP->(eof())
      // Ausfallmuster?
      if LIEFAUS->Ausfall="J"
        do while Zeile<laenge-UNT_RAND-4
          ?
        enddo
        tempText:=linewrap(getTranslation("LS.freigabe",LAND->Sprache),71)
        for i:=1 to len(tempText)
          ? tempText[i]
        next
      endif
    else
      ?? space(62),"Seite",str(seite+1,2)
    endif

    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")

RETURN
/* EOP HandLiefDruck */

      /* analog BeistellTeilListe
      *
      * druckt zugehoer. Beistellteile bei Handlieferschein
      * LIEFAUS muss auf zu druckender Rechnung stehen
      *
      * Info: hier ohne R�ckschreiben nach beistell.dbf   // FIXME: brauchen wir das?
      *
      */
PROCEDURE BeistLiefDruck(Ausgabe)
LOCAL beiNr,M_kundNr, Laenge
LOCAL Adresse
LOCAL Seite:=0,zeile:=0,dateiName
LOCAL pdfInfo

  default Ausgabe:="D"

  LIEFPOST->(dbseek(LIEFAUS->Lsnr))
  BeiNr:=LIEFAUS->Lsnr

  if ! open("BeisTemp")
    Error("Beistellteilliste kann nicht gedruckt werden.",.t.)
    return
  endif

  Message("Beistellteilliste wird gedruckt.  Bitte warten...")

  select Beistemp
  zap

  select Liefpost
  do while ! eof() .and. LIEFPOST->Lsnr==LIEFAUS->Lsnr

    if ! trim(LIEFPOST->ArtNr)$"$*"

      /** Neugeraete */
      ARTIKEL->(dbseek(LIEFPOST->ArtNr))
      // suche Beistellteile
      select AvPost
      BeistellRek(LIEFPOST->ArtNr,LIEFPOST->Menge)
      select Liefpost

    endif
    skip
  enddo

  /** ausdrucken ? */
  select BeisTemp
  if BEISTEMP->(reccount())>0

    // sortiere nach KundenNr und HonselNr
    index on BEISTEMP->KundNr+BEISTEMP->HartNr tag TEMP_INDEX TEMPORARY ADDITIVE
    go top

    do while ! BEISTEMP->(eof())

      pdfInfo:=pdfInfo():new( JOB_BEISTELL , alltrim(BeiNr)+"-"+left(BEISTEMP->KundNr,5) , .f. )

      do case
      case Ausgabe=="D"
        Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,;
          PDF_NO_CONFIRM,2)
      case Ausgabe=="P"
        Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,;
          PDF_NO_CONFIRM)
        // case Ausgabe=="NOP"
        // Drucker("NOP", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f., PDF_NO_CONFIRM)
        // neu 10190126
      case Ausgabe=="NOP"
        Drucker("NOP")
      otherwise
        Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path )
      endcase
      Laenge:=DRUCKER->Laenge
      Seite:=0

      M_KundNr:=BEISTEMP->KundNr

      do while ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr

        Seite = Seite + 1
        zeile:=0
        FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

        ?
        ? space(40),FETT_AN,"Beistellteil-Liste Nr."+BeiNr,FETT_AUS

        KUNDEN->(dbseek(M_KundNr))
        adresse:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->;
          Land,KUNDEN->Plz,KUNDEN->Ort)

        ? space(4),Adresse[1]
        ? space(4),Adresse[2],space(23),;
          if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
        ? space(4),Adresse[3],space(0),KdOut(M_KundNr),space(1),LIEFAUS->AufDat,space(2),;
          getUser():id
        ? space(4),Adresse[4]
        ? space(4),Adresse[5]
        ? space(4),Adresse[6]
        ?
        ? space(44),LIEFAUS->bestnr
        ?
        ? space(44),LIEFAUS->bestkonto

        KUNDEN->(dbseek(LIEFAUS->KundNr))
        adresse:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->;
          Land,KUNDEN->Plz,KUNDEN->Ort)

        ? space(4),Adresse[1]
        ? space(4),Adresse[2],space(0),"LS-Dat.:"+dtoc(LIEFAUS->AufDat)
        ? space(4),Adresse[3]
        ? space(4),Adresse[4],space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
        ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
        ?
        ?
        ?

        /* Rech.Posten drucken */
        do while Zeile<laenge-UNT_RAND-3 .and. ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr
          ARTIKEL->(dbseek(BEISTEMP->Artnr))
          EINHEIT->(dbseek(ARTIKEL->ME))
          ? SCHMAL_AN,out(BEISTEMP->ArtNr),SCHMAL_AUS,PS_Schmal(getTransField("ARTIKEL->Bez1")),;
            str(BEISTEMP->Menge,7), getTransField("EINHEIT->Text")
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,PS_Schmal(getTransField("ARTIKEL->bez2"))
          // Info: Beistellteile werden separat in LiefErfassen abgebucht
          skip
        enddo
        if ! BEISTEMP->(eof()) .and. BEISTEMP->KundNr==M_KundNr
          ? space(62),"Seite "+str(seite+1,3)
        endif
        /** Blattvorschub */
        Zeile:=FormFeed(Zeile,Seite)
      enddo

      // Drucker("Off")
      getUser():getCurrentPrintJob():endDoc()
      dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
      getUser():setCurrentPrintJob(NIL)

      // Beistellteil-Liste mit leerer KundenNr an H. Weiland schicken
      if empty(M_KundNr) .or. M_KundNr==KDNR_LEER .and. Ausgabe=="D"
        email(MAIN_EMAIL,;
          "Hand-LS: "+BeiNr+" - Beistellteil-Liste ohne Kunden-Nr.",,dateiName)
      endif

    enddo
  endif // reccount > 0

  select BeisTemp
  BEISTEMP->(OrdSetFocus((1)))
  zap

RETURN
/* EOP  */
      /** liefert je nach Gr�sse der Felder Menge, EINGEIT->Text
      und PostenPreis den optimalen (k�rzesten) String
      zur�ck
      *
      * vorher: str(AUFTRAG->menge,6),EINHEIT->Text,transStr(postenPreis,7,2)
  *
  * seit 23.5.2014: str(AUFTRAG->menge,7)
      */
Function getMengePreis(menge,postenPreis)
LOCAL result,einh:=getTransField("EINHEIT->Text")
LOCAL nk:=0

  if EINHEIT->Nachkomma > 0
    nk:=2
  endif

  // Ausnahme bei 7 Stellen vor dem Komma, dann immer ohne Nachkomma-Stelle
  if Menge > 999999
    nk:=0
  endif

  if len(trim(einh))<=2 // wie gehabt
    result:=transStr(menge,7,nk,.f.)+" "+left(einh,2)
    if postenpreis != nil
      result+=" "+transStr(postenPreis,8,2)
    endif
  else
    if postenpreis == nil
      result:=transStr(menge,7,nk,.f.)+" "+einh
    else
      // FIXME: is this check < 1000 correct???
      if postenpreis<1000
        result:=transStr(menge,7,nk,.f.)+" "+einh+" "+transStr(postenPreis,7,2)
      else
        if Menge < (if(nk==0,1000000,1000))
          result:=transStr(menge,6,nk,.f.)+" "+einh
        else
          // overflow!!!
          result:=transStr(menge,7,nk,.f.)+einh
        endif
        result+=" "+transStr(postenPreis,8,2)
      endif
    endif
  endif
return result
/** eof */


/*
* KundenDatenBlatt == AB Deckblatt
*
* druckt alle Anschriften des AB Kunden, Best.Nr, Liefer- und Zahlungsbedingungen auf DEUTSCH (!) aus
*/

PROCEDURE KundenDatenBlatt(Ausgabe, MyArt, druckeGeratNr)
LOCAL Zeile:=0,Seite:=1
LOCAL Adresse,Adresse2,Adresse3,ident,ident2
LOCAL i, upsNr:="",versText:={}
LOCAL Datei , restMenge, text
LOCAL bleibtBeiMiki, merkOrd, rechnMenge
LOCAL pdfInfo, geliefert, emails:={}, tempVal, art, erst:=.t., optKdNr

  Umgebung( WRITE_ALL )

  default myArt:="A" // default ist Auftrag
  default druckeGeratNr:=.f.

  if Ausgabe=="P"
    Ausgabe:="PDF"
  else
    Ausgabe:="ON"
  endif

  // immer auf Deutsch
  LAND->(dbseek(DEUTSCH_LAND))
  VERSART->(dbseek( AUFAUS->VersNr ))

  // frei/unfrei bei Kunden/Spedition hinterlegt?
  // Hinweis: SpedNr immer aus Aufaus ist unsch�n, wird aber nicht nach Rechaus kopiert :(
  SPEDIT->(dbseek(AUFAUS->SpedNr))

  if myArt == "A" // Beiblatt AB
    Datei:="Aufaus"
    text:='Auftragsbest�tigung Nr.:'
    pdfInfo:=pdfInfo():new( JOB_AB_DATENBLATT , (DATEI)->AufNr , .t. )
    Drucker(Ausgabe, pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
  elseif myArt == "V" .or. (AUFAUS->AufArt="S" .and. AUFAUS->WarKV="J") // KV
    Datei:="Aufaus"
    text:='Kostenvoranschlag   Nr.:'
    pdfInfo:=pdfInfo():new( JOB_KV_DATENBLATT , (DATEI)->AufNr , .t. )
    Drucker(Ausgabe, pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
  else // Beiblatt Rechnung
    Datei:="Rechaus"
    text:='Auftragsbest�tigung Nr.:'
    pdfInfo:=pdfInfo():new( JOB_RE_DATENBLATT , (DATEI)->RechNr , .t. )
    Drucker(Ausgabe, pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
  endif

  bleibtBeiMiki:=(left((DATEI)->V_KundNr,5) == MIKI_NR)

  ?
  ?
  ? FETT_AN,text,BREIT_AN,(DATEI)->AufNr,BREIT_AUS,FETT_AUS,space(6),;
    "Kunden-Nr.:",FETT_AN,BREIT_AN,KdOut((DATEI)->KundNr),FETT_AUS,BREIT_AUS,;
    space(0),(DATEI)->Aufdat,space(1),AUFAUS->Mod_user

  if myArt == "R"
    ? FETT_AN,'Rechnungs-Nummer.......:',BREIT_AN,(DATEI)->RechNr,FETT_AUS,space(6),"Kunden-Nr.:",;
      FETT_AN,BREIT_AN,KdOut((DATEI)->R_KundNr),FETT_AUS,BREIT_AUS,space(0),;
      (DATEI)->ReaDat,space(1),RECHAUS->Mod_user
  endif
  ?

  // BestellDaten
  ? FETT_AN,"Bestell-Daten",FETT_AUS,space(30),"Best.Datum.....:",(DATEI)->bestdat
  ? "Best.Nummer:",(DATEI)->bestnr,space(5),"Ansprechpartner:",(DATEI)->Ansprech
  if ! empty((DATEI)->bestkonto)
    ? "Fremd-LS Nr:",(DATEI)->bestkonto
  else
    ? "            ",space(len((DATEI)->bestkonto))
  endif
  ?? space(0),"Telefon........:",(DATEI)->Telefon
  if ! empty((DATEI)->Email)
    ? space(44),"Email..........:",left( (DATEI)->Email , 30 )
  endif
  if ! empty((DATEI)->Fax)
    ? space(44),"Fax............:",(DATEI)->Fax
  endif
  ?

  // Anschriften
  KUNDEN->(dbseek((DATEI)->KundNr))
  ident:=KUNDEN->IdentNr
  KUNDEN->(dbseek((DATEI)->V_KundNr))
  ident2:=KUNDEN->IdentNr

  adresse:=getAdrBlock((DATEI)->Name,(DATEI)->Partner,(DATEI)->Strasse,(DATEI)->Zusatz,;
    (DATEI)->Land,(DATEI)->Plz,(DATEI)->Ort)

  adresse2:=getAdrBlock((DATEI)->V_Name,(DATEI)->V_Partner,(DATEI)->V_Strasse,(DATEI)->V_Zusatz,;
    (DATEI)->V_Land,(DATEI)->V_Plz,(DATEI)->V_Ort)

  // ohne Sammelstelle
  if empty((DATEI)->S_Name) .or. SPEDIT->SpedKZ == "N"
    ? FETT_AN,"Haus-Anschrift:",KdOut((DATEI)->KundNr),space(19),;
      "Versand-Anschrift:",KdOut((DATEI)->V_KundNr),FETT_AUS
    for i:=1 to len( Adresse )
      ? space(2),Adresse[i],space(9),Adresse2[i]
    next

  else // mit Sammelstelle
    adresse3:=getAdrBlock((DATEI)->S_Name,(DATEI)->S_Partner,(DATEI)->S_Strasse,(DATEI)->S_Zusatz,;
      (DATEI)->S_Land,(DATEI)->S_Plz,(DATEI)->S_Ort)

    ? FETT_AN,"Haus-Anschrift:",KdOut((DATEI)->KundNr),space(14),KLEIN_AN,;
      "Versand-Anschrift:",KdOut((DATEI)->V_KundNr),space(6),"Sammelstelle:",FETT_AUS
    for i:=1 to len( Adresse )
      ? space(2),Adresse[i],space(1),KLEIN_AN,Adresse2[i],Adresse3[i],KLEIN_AUS
    next
  endif
  ?
  ? "Ident.Nr.:",ident,space(17),"Ident.Nr.:",ident2
  ?

  // Rechnungsanschirft , Versand-Art, Zahl.Kond.
  ? FETT_AN,"Rechnungs-Anschrift:",KdOut((DATEI)->R_KundNr),space(14),;
    if(bleibtBeiMiki,"","Versandart:"), FETT_AUS

  // kundenspez. Sped.Info
  KUNDSPED->(OrdSetFocus( 2 )) // KundNr + SpedNr
  KUNDSPED->(dbseek((DATEI)->V_KundNr + AUFAUS->SpedNr ))
  if ! KUNDSPED->(eof())
    if KUNDSPED->Frei == "J" .and. ! bleibtBeiMiki
      aadd( versText, {COLOR_RED,"frei senden, Fracht berechnen",COLOR_DEFAULT})
    endif
  endif

  // fill sped.text array (2. Spalte)
  if ! bleibtBeiMiki
    if empty( SPEDIT->Name )
      aadd( versText , { COLOR_RED,"Keine Spedition bei Kunde hinterlegt",COLOR_DEFAULT } )
    else
      if VERSART->Fracht == "N"
        if ! empty( SPEDIT->SpedKdNr )
          upsNr:="(Miki-Nr:"+trim(SPEDIT->SpedKdNr)+")"
        endif
      else
        if ! empty( KUNDSPED->SpedKdNr )
          upsNr:="(Nr:"+trim(KUNDSPED->SpedKdNr)+")"
        endif
      endif
      aadd( versText , { trim(getTransField("SPEDIT->Name")), KLEIN_AN, upsNr, KLEIN_AUS } )
    endif
    if ! empty( SPEDIT->Name2 )
      aadd( versText , { trim(getTransField("SPEDIT->Name2")) })
    endif
    if ! empty( SPEDIT->Ansprech )
      aadd( versText , { trim(getTransField("SPEDIT->Ansprech")) })
    endif
    if ! empty( SPEDIT->Telefon )
      aadd( versText , { "Tel: "+trim(SPEDIT->Telefon) })
    endif
    if ! empty( SPEDIT->Fax )
      aadd( versText , { "Fax: "+trim(SPEDIT->Fax) })
    endif
    if ! empty( SPEDIT->Email )
      aadd( versText , { "Email: "+trim(SPEDIT->Email) })
    endif
  endif

  // kundenspez. Bemerkung je Spedition
  if ! KUNDSPED->(eof()) .and. VERSART->Fracht <> "N"
    if ! empty( KUNDSPED->Bemerk1 )
      aadd( versText, {KUNDSPED->Bemerk1} )
    endif
    if ! empty( KUNDSPED->Bemerk2 )
      aadd( versText, {KUNDSPED->Bemerk2} )
    endif
  endif


  KUNDEN->(dbseek((DATEI)->R_KundNr))
  ident:=KUNDEN->IdentNr

  adresse:=getAdrBlock((DATEI)->R_Name,(DATEI)->R_Partner,(DATEI)->R_Strasse,(DATEI)->R_Zusatz,;
    (DATEI)->R_Land,(DATEI)->R_Plz,(DATEI)->R_Ort)

  // if ! myArt $ "AV" // Rechnung * if Abfrage raus seit 20180712
  AUFAUS->(dbseek((DATEI)->AufNr))
  // endif

  // UpsNr drucken? // seit 12.10.14 immer
  // raus 16.2.16 (s.o.) KUNDEN->(dbseek( AUFAUS->V_KundNr ))

  ? space(2),Adresse[1],space(6),if(bleibtBeiMiki,"",getTransField("VERSART->Text"))
  ? space(2),Adresse[2],space(6)
  printSpalte2(versText , 1)
  ? space(2),Adresse[3],space(6)
  printSpalte2(versText , 2)
  ? space(2),Adresse[4],space(6)
  printSpalte2(versText , 3)
  ? space(2),Adresse[5],space(6)
  printSpalte2(versText , 4)
  ? space(2),Adresse[6],space(6)
  printSpalte2(versText , 5)
  ? space(2),space(len(Adresse[6])),space(6) // immer eine Leerzeile im rechten Block
  printSpalte2(versText , 6)
  // restzeilen 2. spalte drucken
  for i:=7 to len(versText)
    ? space(2),space(len(Adresse[6])),space(6) // immer eine Leerzeile im rechten Block
    printSpalte2(versText , i)
  next
  ? "Ident.Nr.:",ident,space(17),FETT_AN,getTranslation("allgemein.zahlkond",DEUTSCH,20),FETT_AUS
  ? space(2),space(34),space(6),getTransField("ZAHLKOND->Text")
  ? space(2),space(34),space(6),getTransField("ZAHLKOND->Text2")

  if ! empty(AUFAUS->A_Name) .or. ! empty(AUFAUS->A_Partner)
    adresse:=getAdrBlock(AUFAUS->A_Name,AUFAUS->A_Partner,AUFAUS->A_Strasse,AUFAUS->A_Zusatz,;
      AUFAUS->A_Land,AUFAUS->A_Plz,AUFAUS->A_Ort)
    ?
    ? FETT_AN,"Abweichende Rechnungs-Versandanschrift:",FETT_AUS
    ? space(2),Adresse[1]
    ? space(2),Adresse[2]
    ? space(2),Adresse[3]
    ? space(2),Adresse[4]
    ? space(2),Adresse[5]
    ? space(2),Adresse[6]
  endif

  // drucke Email-Empf�nger if any
  for each art in {EMAIL_AUFTRAG, EMAIL_BEISTELL, EMAIL_RECHNUNG, EMAIL_GBS, EMAIL_LIEFERSCHEIN}
    // 202220819 drucke auch Email von Rechnungsadresse
    if art == EMAIL_RECHNUNG
      optKdNr:=AUFAUS->R_KUNDNR
    else
      optKdNr:=NIL
    endif
    tempVal:=sendEmails(art, "dummy.txt", optKdNr, .t.)
    if ! empty(tempVal)
      aadd(emails, tempVal)
    endif
  next

  for each tempVal in emails
    if erst
      ?
      ? FETT_AN,"Emails: ", FETT_AUS
      erst:=.f.
    else
      ? FETT_AN,"        ", FETT_AUS
    endif
    ?? tempVal
  next

  // drucke einzelne Posten mit (Teil)-Liefermenge drucken
  if myArt $ "AV" // AB // seit 14.2.2015 bei Kostenvoranschlag keine Posten mehr
    ?
    SELECT Auftrag
    go top
    do while ! AUFTRAG->(eof())
      if Seite > 1
        // drucke Kopf
        ? FETT_AN,'Auftragsbest�tigung Nr.:',(DATEI)->AufNr,FETT_AUS,space(6),;
          "Kunden-Nr.:",KdOut((DATEI)->KundNr),space(2),(DATEI)->Aufdat,space(4),"Seite",str(seite,3)
        ?
      endif

      ? FETT_AN,replicate( MY_LINE_CHAR , 91 )
      ? "Art.Nr.  Artikel-Bezeichnung                        AB-Menge  Geliefert Restmenge ME "+;
        "Liefer"
      ? "                                                                                     Termin",;
        FETT_AUS
      do while ! AUFTRAG->(eof()) .and. Zeile < DRUCKER->Laenge - UNT_RAND + 4

        // Ohne Kommentare 20140623
        if substr(AUFTRAG->ArtNr,1,1) $ "$*"
          skip
          loop
        endif

        // Zoll-Artikel nicht ausdrucken
        if isZollZuschlagArtikel( AUFTRAG->ArtNr )
          skip
          loop
        endif

        if AUFTRAG->Menge == 0
          restMenge:=space(9)
        else
          restMenge:=transStr(AUFTRAG->Menge-AUFTRAG->Geliefges-AUFTRAG->Gelief,9,2)
        endif

        EINHEIT->(dbseek( AUFTRAG->ME ))
        // Hinweis: Kundendatenblatt ist komplett in Schmal, s. Listen.dbf
        // wir brauchen also KLEIN_AN um Platz zu gewinnen
        ? KLEIN_AN,out(AUFTRAG->ArtNr),KLEIN_AUS,getTransField("AUFTRAG->Komm1"),;
          transStr(AUFTRAG->Menge,10,2), transStr(AUFTRAG->GeliefGes+AUFTRAG->Gelief,10,2),;
          restMenge,getTransField("EINHEIT->Text"),AUFTRAG->KW
        if ! empty(AUFTRAG->Komm2)
          ? KLEIN_AN,space(len(out(AUFTRAG->ArtNr))),KLEIN_AUS,getTransField("AUFTRAG->Komm2")
        endif
        if ! empty(AUFTRAG->Kw_Text)
          ? AUFTRAG->Kw_text
        endif

        /** drucke WarenIdentNummer & Ursprungsland */
        zeile += printWarenIdentNummer()

        /** drucke Ger�te.Nr. */
        if druckeGeratNr
          zeile += printGeratNummer()
        endif

        // extra Leerzeile nur bei Honsel-Artikeln
        ARTIKEL->(dbseek( AUFTRAG->ArtNr ))
        if left(ARTIKEL->KonsigKdNr,5) $ "10167|10363"
          ?
        endif

        skip
      enddo
      ? replicate( MY_LINE_CHAR , 91 )
      seite++
      if ! AUFTRAG->(eof()) .and. AUFTRAG->Aufnr == AUFAUS->Aufnr
        ? space(77),"Seite",str(seite,3),"-->"
      else
        ? if(myArt=="V","KV-Datum","Auftrags-Datum:"),AUFAUS->AufDat,"(KW:",;
          getKW(AUFAUS->AufDat)+")"
      endif
      Zeile:=FormFeed(Zeile,Seite)
    enddo

  elseif myArt == "R" // Rechnung

    // ACHTUNG: hier wird AUFPOST gedruckt nicht AUFTRAG.dbf

    // Info: seit 20140623 bei Rechnung auch alle AB Posten drucken, damit Teillieferung ersichtlich wird
    select RechPost
    merkOrd:=RECHPOST->(indexord())
    index on RechPost->AbPostNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      RECHPOST->RechNr == RECHAUS->RechNr

    ?
    SELECT Aufpost
    AUFPOST->(dbseek( AUFAUS->AufNr ))
    do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr == AUFAUS->AufNr
      if Seite > 1
        // drucke Kopf
        ? FETT_AN,'Auftragsbest�tigung Nr.:',(DATEI)->AufNr,FETT_AUS,space(6),;
          "Kunden-Nr.:",KdOut((DATEI)->KundNr),space(2),(DATEI)->Aufdat,space(2),"Seite",str(seite,3)
        ?
      endif

      ? KLEIN_AN,FETT_AN,replicate( MY_LINE_CHAR , 107 )
      ? "Art.Nr.      Artikel-Bezeichnung                        AB-Menge  Geliefert  Geliefert "+;
        "Rest-Menge ME Liefer"
      ?;
        "                                                                  Re. "+RECHPOST->RechNr+;
        "     Gesamt               Termin", KLEIN_AUS,FETT_AUS
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr == AUFAUS->AufNr ;
        .and. Zeile < DRUCKER->Laenge - UNT_RAND + 3

        // ohne Kommentare 20140623
        if substr(AUFPOST->ArtNr,1,1) $ "$*"
          skip
          loop
        endif

        // Zoll-Artikel mit Preis = 0 nicht ausdrucken
        if isZollZuschlagArtikel( AUFPOST->ArtNr )
          skip
          loop
        endif

        if (AUFAUS->AufArt="V")
          geliefert:=0
        else
          geliefert:=AUFPOST->Geliefges
        endif

        if AUFPOST->Menge == 0
          restMenge:=space(10)
        else
          restMenge:=transStr(AUFPOST->Menge-geliefert,10,2)
        endif

        // suche zugeh. Rechnungsposten
        RECHPOST->(dbseek( AUFPOST->ABPostNr ))
        if RECHPOST->(eof()) // nicht in aktueller Rechnung gefunden
          rechnMenge:=space(10)
        else
          rechnMenge:=transStr( RECHPOST->Gelief , 10 , 2 )
        endif

        EINHEIT->(dbseek( AUFPOST->ME ))
        // Hinweis: Kundendatenblatt Rechnung ist komplett in Klein, s. KLEIN_AN oben
        ? KLEIN_AN,out(AUFPOST->ArtNr),getTransField("AUFPOST->Komm1"),;
          transStr(AUFPOST->Menge,10,2),rechnMenge,;
          transStr(geliefert,10,2),restMenge,;
          getTransField("EINHEIT->Text"),AUFPOST->KW
        if ! empty(AUFPOST->Komm2)
          ? space(len(out(AUFPOST->ArtNr))),getTransField("AUFPOST->Komm2")
        endif
        if ! empty(AUFPOST->Kw_Text)
          ? AUFPOST->Kw_text
        endif

        /** drucke WarenIdentNummer & Ursprungsland */
        zeile += printWarenIdentNummer() // Achtung: schaltet klein und schmal druck aus!

        // extra Leerzeile nur bei Honsel-Artikeln
        ARTIKEL->(dbseek( AUFPOST->ArtNr ))
        if left(ARTIKEL->KonsigKdNr,5) $ "10167|10363"
          ?
        endif

        skip
      enddo
      ? KLEIN_AN,replicate( MY_LINE_CHAR , 107 ),KLEIN_AUS
      seite++
      if ! AUFPOST->(eof()) .and. AUFPOST->Aufnr == AUFAUS->Aufnr
        ? space(79),"Seite",str(seite,3),"-->"
      else
        ? "Auftrags-Datum:",AUFAUS->AufDat,"(KW:",getKW(AUFAUS->AufDat)+")"
      endif
      Zeile:=FormFeed(Zeile,Seite)
    enddo

    // destroy temp. index
    select RechPost
    RECHPOST->(OrdDestroy(TEMP_INDEX))
    RECHPOST->(OrdSetFocus( merkOrd ))

  endif

  Drucker("Off")

  // still debugging
  // getUser():getCurrentPrintJob():endDoc()
  // liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
  // getUser():setCurrentPrintJob(NIL)

  Umgebung( LOAD )
RETURN
/* EOP KundenDatenBlatt */

static procedure printSpalte2(versText , pos)
LOCAL x,text
  if pos <= len( versText )
    text:=versText[pos]
    for each x in text
      ?? x
    next
  endif
return
/** eop */

/*
 * druckt Spedition-Abhol-Auftrag
 */

FUNCTION SpeditAuftragDrucken(Ausgabe)
LOCAL Seite:=1,zeile:=0, laenge, aktOrd
LOCAL Adresse, Adresse2
LOCAL dateiName, text, t , kom , i
LOCAL waehrung:="Euro", result
LOCAL Name, Fax, Tel, Ansprech, mailto, email, internEmail
LOCAL pdfInfo, aktSel:=alias(), countLF

  default Ausgabe:="D"

  // nur Email Ausgabe OHNE Druck gew�nscht?
  if Ausgabe <> "B" .and. emailOnly( EMAIL_SPEDITION )
    Ausgabe:="PDF_QUIET"
    // qtError("Info: Speditions-Abholauftrag wird per Email verschickt.",.f.)
  endif

  AUFAUS->(dbskip(0)) // Relationen aktualisieren !
  KUNDEN->(dbseek( AUFAUS->KundNr ))
  VERSART->(dbseek( AUFAUS->VersNr ))
  PALETTEN->(dbseek( ABHOL->PalNr ))
  selLandBySprache( ABHOL->Sprache )

  // falls keine Sped. hinterlegt -> nehme Kundenadresse & Sprache
  if empty( AUFAUS->SpedNr )

    adresse:=getAdrBlock(AUFAUS->Name,AUFAUS->Partner,AUFAUS->Strasse,AUFAUS->Zusatz, AUFAUS->Land;
      ,AUFAUS->Plz,AUFAUS->Ort)

    Ansprech:=AUFAUS->Ansprech
    Tel:=KUNDEN->Telefon
    Fax:=SPEDIT->Fax
    Name:=KUNDEN->KurzName
    mailto:=KUNDEN->Email

  else
    SPEDIT->(dbseek(AUFAUS->SpedNr))

    adresse:=getAdrBlock(SPEDIT->Name,SPEDIT->Name2,SPEDIT->Strasse1,SPEDIT->Strasse2, SPEDIT->Land,SPEDIT->Plz,SPEDIT->Ort)

    // goldene Ausnahme SpedNr="4" Abholung nach Absprache, trotzdem KundenNr. anzeigen
    // 19.12.16
    if SPEDIT->SpedNr == "004"
      adresse:=getAdrBlock(AUFAUS->Name,AUFAUS->Partner,AUFAUS->Strasse,AUFAUS->Zusatz, AUFAUS->Land,AUFAUS->Plz,AUFAUS->Ort)

      mailto:=trim(KUNDEN->Email)
      EMAIL->(dbseek( KUNDEN->KundNr + "S" ))
      if ! EMAIL->(eof())
        if ! empty(mailto)
          mailto += MY_CR+MY_LF
        endif
        mailto+=trim(EMAIL->Email)
      endif

    else
      mailto:=""
      for each email in {"SPEDIT->Email","SPEDIT->Email2","SPEDIT->Email3","SPEDIT->Email4"}
        if ! empty( &( email ))
          mailTo += &( email ) + MY_CR+MY_LF
        endif
      next
    endif

    Ansprech:=SPEDIT->Ansprech
    Tel:=SPEDIT->Telefon
    Fax:=SPEDIT->Fax
    Name:=getTransField("SPEDIT->Name")

  endif

  pdfInfo:=pdfInfo():new( JOB_SPEDITION_AB , AUFAUS->AufNr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_YES_CONFIRM)
  case Ausgabe=="PDF_QUIET" // keine Ausgabe
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
  case Ausgabe=="B"
    Drucker("BS")
  endcase

  Laenge:=DRUCKER->Laenge

  // FormularDruck
  getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))

  ?;?;?;?;?

  ? space(4),Adresse[1],FETT_AN,space(0),getTranslation("abhol.betreff",LAND->Sprache),;
    getTranslation("allgemein.nummer",LAND->Sprache),AUFAUS->AufNr,FETT_AUS
  ? space(4),Adresse[2],space(23),;
    if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
  ? space(4),Adresse[3]
  ? space(4),Adresse[4],space(0),KdOut(AUFAUS->KundNr),space(1),getUser():date,space(2),;
    getUser():id
  ? space(4),Adresse[5]
  ? space(4),Adresse[6]
  ? space(44),space(6), AUFAUS->bestdat
  ?
  ? FETT_AN,if(empty(ansprech),space(5),"z.Hd.") , Ansprech , FETT_AUS,space(5),AUFAUS->bestnr
  if ! empty(Tel)
    ? "Tel.:",Tel
    countLF:=0
  else
    countLF:=1
  endif
  if ! empty( Fax )
    ? "Fax.:" , Fax
  else
    countLF++
  endif
  for i:=1 to countLF
    ?
  next

  ? space(44),AUFAUS->bestkonto // ist Lieferschein-Nr
  // ?

  // keine Lieferadresse falls das Werkzeug bei Miki verbleibt
  adresse:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz, AUFAUS;
    ->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

  if empty(AUFAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
    ? space(4),Adresse[1]
    ? space(4),Adresse[2]
    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6],space(0),Name
  else
    adresse:=getAdrBlock(AUFAUS->S_Name,AUFAUS->S_Partner,AUFAUS->S_Strasse,AUFAUS->S_Zusatz,;
      AUFAUS->S_Land,AUFAUS->S_Plz,AUFAUS->S_Ort)
    adresse2:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
      AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

    ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
    ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS
    ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
    ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
      if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
    ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),Name
  endif
  ?
  ?
  ?

  ? ABHOL->Komm1
  ? ABHOL->Komm2
  if ! empty( ABHOL->Komm3 )
    ? ABHOL->Komm3
  endif
  if ! empty( ABHOL->Komm4 )
    ? ABHOL->Komm4
  endif
  ?
  if empty(ABHOL->UhrZeit) .or. ABHOL->UhrZeit == "  :  " // ohne Uhrzeit?
    text:=strtran(getTranslation("abhol.datum",LAND->Sprache),"$ABHOL_DATUM",dtoc(ABHOL->Datum))
  else
    text:=strtran(getTranslation("abhol.zeit",LAND->Sprache),"$ABHOL_DATUM",dtoc(ABHOL->Datum))
    text:=strtran(text,"$ABHOL_UHRZEIT",ABHOL->UhrZeit)
  endif
  text:=linewrap(text,COLUMN_WRAP)
  for each t in text
    ? t
  next
  ?
  text:=linewrap(getTranslation("abhol.oeffnungszeiten",LAND->Sprache),COLUMN_WRAP)
  for each t in text
    ? t
  next
  ?
  ?
  select EINHEIT
  loca for EINHEIT->Text == "Stk"
  ? space(9),getTransField("PALETTEN->Text1"),transstr(ABHOL->Menge,7,0),;
    getTransField("EINHEIT->Text")
  if ! empty(PALETTEN->Text2)
    ? space(9),getTransField("PALETTEN->Text2")
  endif
  if ! empty(PALETTEN->Text3)
    ? space(9),getTransField("PALETTEN->Text3")
  endif
  ?
  loca for EINHEIT->Text == "kg "
  ? space(9),getTranslation("abhol.gewicht",LAND->Sprache,26),transstr(ABHOL->Gewicht,11,2),;
    getTransField("EINHEIT->Text")
  loca for EINHEIT->Text == "m  "
  ? space(9),getTranslation("abhol.hoehe",LAND->Sprache,26),transstr(ABHOL->Hoehe,11,2),;
    getTransField("EINHEIT->Text")

  select (aktSel)
  ?
  if ABHOL->Frei == "J"
    ? space(9),getTranslation("abhol.frei",LAND->Sprache)
    if ! empty( SPEDIT->SpedKdnr )
      ? space(9),getTranslation("abhol.kdnr",LAND->Sprache),"Miki-Plastik:",SPEDIT->SpedKdnr
    endif

  else
    ? space(9),getTranslation("abhol.unfrei",LAND->Sprache)

    aktOrd:=KUNDSPED->(OrdSetFocus(2))
    KUNDSPED->(dbseek( AUFAUS->V_KundNr + AUFAUS->SpedNr ))
    if ! empty( KUNDSPED->SpedKdnr )
      ? space(9),getTranslation("abhol.kdnr",LAND->Sprache),KUNDSPED->SpedKdnr
    endif
    KUNDSPED->(OrdSetFocus( aktOrd ))

  endif
  ?
  ? getTranslation("abhol.anfahrt",LAND->Sprache)
  ?
  ? space(39),"--------------------------------"
  if AUFAUS->mwst > 0.0
    ? space(39),getTranslation("allgemein.netto",LAND->Sprache,13)+waehrung,;
      transStr(ABHOL->Netto,14,2)
    ? space(39),;
      transStr(ABHOL->mwst,5,2)+"% "+getTranslation("allgemein.mwst",LAND->Sprache,4)+":",;
      waehrung, transStr(ROUND( ABHOL->Netto*ABHOL->MwSt/100 , 2) ,14,2)
  endif

  kom:=Werbe_Text(ABHOL->TextKz_Nr)
  i:=1
  ? kom[i++],space(5),getTranslation("allgemein.brutto",LAND->Sprache,13)+waehrung,;
    transStr(ABHOL->Brutto,14,2)
  ? kom[i++],space(5),"================================"
  ? kom[i++],space(5),trim(padl(getTranslation("abhol.zzgl",LAND->Sprache),32))
  ? kom[i++]
  ? kom[i++],space(3),trim(mycenter(getTranslation("allgemein.gruesse",LAND->Sprache),35))
  ? kom[i++],space(3),trim(mycenter(getTranslation("allgemein.miki",LAND->Sprache),35))

  /** Seitenvorschub */
  Zeile:=FormFeed(Zeile,Seite)

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if Ausgabe $ "DP/PDF_QUIET" .and. ! empty( dateiName )

    internEmail:=if( DEVEL_PROG , MAIN_EMAIL , getTranslation("abhol.email.absender",DEUTSCH) )
    if Message("Abholauftrag per Email an " + ;
      strtran(internEmail , "@" , "\@" ) + " weiterleiten? (@J@/@N@)","JN"," ")=="J"

      result:=EMail( internEmail , getTranslation("abhol.email.betreff",LAND->Sprache) , "Bitte weiterleiten an: " + MY_CR+MY_LF + mailTo + MY_CR+MY_LF + MY_CR+MY_LF + "======================"+ MY_CR+MY_LF + aaToToken( lineWrap( strtran( getTranslation("abhol.email.text",LAND->Sprache ) , "$ABHOL_NR", AUFAUS->AufNr ) ) , MY_CR+MY_LF ) , dateiName, .f. , .t. )

      if result
        Error("Email wurde zum weiterleiten an: " + internEmail + " versendet.")
      endif
    endif

    // EMailClient( mailTo ,;
    // getTranslation("abhol.email.betreff",LAND->Sprache) ,;
    // aaToToken( lineWrap( getTranslation("abhol.email.text",LAND->Sprache) ) , MY_CR+MY_LF ) ,;
    // dateiName , ;
    // {{ "" , getTranslation("abhol.email.absender",LAND->Sprache) , WIN_MAPI_TO }} )

  endif

RETURN DateiName
/* EOP Auftrag */

/*
*
* druckt eine Pro-Forma-Rechnung mit den Posten aus Auftrag.dbf
* ACHTUNG: nimmt AUFTRAG->Gelief anstatt AUFTRAG->menge wegen m�gl. Teillieferung
*
* Parameter Ausgabe wohin
*/

PROCEDURE ProFormaDrucken(Ausgabe , myLand )
LOCAL gwert:=0.00, einhNr:="",anzahl
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0
LOCAL tex1,Tex2,tex3,tex4
LOCAL Laenge
LOCAL sonder:=.f. // SonderRabatt noch nicht gedruckt
LOCAL postenPreis
LOCAL waehrung:="Euro",Adresse,Adresse2
LOCAL Ende,tempText:="" , bLastHandler
LOCAL pdfInfo, i, frachtKosten:=0

  default Ausgabe:="D"
  default myLand:=AUFAUS->R_Sprache

  // FIXME: added 20200319, testen ob ok?
  select AufAus
  set relation to AUFAUS->textkz_Nr into Text_Kz,to AUFAUS->zknr into zahlkond,;
    to AUFAUS->versNr into versart

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(myLand)

  pdfInfo:=pdfInfo():new( JOB_PRO_FORMA , AUFAUS->AufNr , .t. )

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
  case Ausgabe=="B"
    Drucker("BS")
    // case Ausgabe=="NOP" // keine Ausgabe
    // Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    // neu 20190126
  case Ausgabe=="NOP" // keine Ausgabe
    Drucker("NOP")
  endcase

  // FormularDruck
  getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))

  Laenge:=DRUCKER->Laenge
  AUFAUS->(dbskip(0)) // Relationen aktualisieren !
  SPEDIT->(dbseek(AUFAUS->SpedNr))

  IF ! upper(AUFAUS->EG) $ "DJ"
    tempText:=getTranslation("rechnung.nichtEU.text",LAND->Sprache)
    tempText:=strtran(tempText,"$DATUM",dtoc(AUFAUS->AufDat))
    tempText:=linewrap(tempText,COLUMN_WRAP)
  endif

  select Auftrag
  go top
  Ende:=AUFTRAG->(eof())
  do while .not. Ende
    Seite = Seite + 1
    zeile:=0

    ?;?;?;?;?

    adresse:=getAdrBlock(AUFAUS->R_Name,AUFAUS->R_Partner,AUFAUS->R_Strasse,AUFAUS->R_Zusatz,;
      AUFAUS->R_Land,AUFAUS->R_Plz,AUFAUS->R_Ort)

    ?
    ? space(4),space(34),FETT_AN,space(0), getTranslation("allgemein.proforma_rechnung",LAND->Sprache),;
      getTranslation("AB.nummer",LAND->Sprache),AUFAUS->AufNr,FETT_AUS

    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),KdOut(AUFAUS->KundNr),space(1),AUFAUS->Aufdat,space(2),;
      getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5]
    ? space(4),Adresse[6],space(0),AUFAUS->LiefNr,AUFAUS->bestdat
    ? space(44),AUFAUS->bestnr
    ? space(44),AUFAUS->Ansprech
    ?
    ? space(44),AUFAUS->bestkonto

    // keine Lieferadresse falls das Werkzeug bei Miki verbleibt
    adresse:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
      AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

    if empty(AUFAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
      ? space(4),Adresse[1]
      ? space(4),Adresse[2]
      ? space(4),Adresse[3]
      ? space(4),Adresse[4],space(0),;
        if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
      ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
      ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    else
      adresse:=getAdrBlock(AUFAUS->S_Name,AUFAUS->S_Partner,AUFAUS->S_Strasse,AUFAUS->S_Zusatz,;
        AUFAUS->S_Land,AUFAUS->S_Plz,AUFAUS->S_Ort)
      adresse2:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
        AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)
      ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
      ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS
      ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
      ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
        if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
      ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
      ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
    endif
    ?
    ?
    ?

    /** Uebertrag */
    if Seite > 1
      ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
    endif

    /* Posten drucken */
    SELECT Auftrag
    do while Zeile < laenge - UNT_RAND - 4 .and. .not. AUFTRAG->(eof())
      postenPreis:=AUFTRAG->Preis
      wert:=0
      do case
        /** Kommentar */
      case substr(AUFTRAG->ArtNr,1,1) $ "$*"
        if ! (Zeile<laenge-UNT_RAND-Kommentar(.f.))
          exit
        endif
        zeile += Kommentar()
        if ! AUFTRAG->(eof())
          ? // Leerzeile vor n�chstem Artikel
        endif
        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(AUFTRAG->ArtNr))<=FRACHT_LAENGE
        if AUFTRAG->Gelief == 0 // nur falls Menge eingegeben
          skip
          loop
        endif

        div=IIF(AUFTRAG->PE$"Hh",100,1)
        ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
          PS_Schmal(left(getTransField("AUFTRAG->komm1"),30))
        wert=ROUND(postenPreis*AUFTRAG->Gelief/div,2)
        ?? getMengePreis(AUFTRAG->Gelief,postenPreis),AUFTRAG->pe,;
          if(wert==0,"",transstr(wert,12,2))
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        endif

        // Mengenrabatt
        IF AUFTRAG->rabatt<>0.0 .and. wert <> 0
          ? space(38)+if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein. "+;
            "rabatt.sonder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(wert*AUFTRAG->Rabatt/100,10,2)
          wert=wert-ROUND(wert*AUFTRAG->rabatt/100,2)
        endif

        frachtKosten += wert

        /** "normaler" Artikel */
      otherwise

        if AUFTRAG->Gelief == 0 // nur falls Menge eingegeben
          skip
          loop
        endif

        // ***** neu seit 30.5.2011, z�hle Anzahl Zusatzzeilen f�r Seitenumbruch vorab
        anzahl:=2
        anzahl += zaehle_MatKz_Text(AUFTRAG->ArtNr)
        anzahl += zaehle_Artikel_Text(AUFTRAG->ArtNr)
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          anzahl+=2
        endif

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          anzahl++
        endif

        /** WarenIdentNummer */
        anzahl += printWarenIdentNummer(.t.)

        /** drucke Liefertermin aus Posten */
        if ! KWempty(AUFTRAG->KW)
          if ! empty(getTransField("AUFTRAG->komm2"))
            anzahl++
          endif
          anzahl++
        endif

        // Zusatzkommentare, z.B. �berlieferung
        if ! empty(AUFTRAG->Komm3)
          anzahl++
        endif
        if ! empty(AUFTRAG->Komm4)
          anzahl++
        endif
        if Zeile+anzahl>laenge-UNT_RAND
          exit
        endif

        // ********** ende neu


        div=IIF(AUFTRAG->PE$"Hh",100,1)
        if alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(AUFTRAG->ArtNr),SCHMAL_AUS
        endif
        ?? PS_Schmal(left(getTransField("AUFTRAG->komm1"),30))
        if AUFAUS->Aufart <> "K"
          wert=ROUND(postenPreis*AUFTRAG->Gelief/div,2)
          ?? getMengePreis(AUFTRAG->Gelief,postenPreis),AUFTRAG->pe,transStr(wert,12,2)
        else
          ?? getMengePreis(AUFTRAG->Gelief,nil)
        endif
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,;
            PS_Schmal(left(getTransField("AUFTRAG->komm2"),30))
        else
          if ! empty(ARTIKEL->Hartnr)
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
          endif
        endif

        /** merke EinheitNr */
        if empty(EinhNr)
          EinhNr:=AUFTRAG->Me
        endif

        /** drucke Mat.Kz-Text */
        zeile += drucke_MatKz_Text(AUFTRAG->ArtNr)

        /** drucke Artikel Texte */
        zeile += drucke_Artikel_Text(AUFTRAG->ArtNr)

        /** drucke Gerate-Nummer */
        if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
          ?
          ? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",AUFTRAG->GerVon
          if ! empty(AUFTRAG->GerBis)
            ?? "-",AUFTRAG->GerBis
          endif
        endif

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          ?;
            space(38)+;
            if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.sonder",LAND->Sprache,18), getTranslation("allgemein.rabatt.menge",LAND->Sprache,18)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(wert*AUFTRAG->Rabatt/100,10,2)

          wert=wert-ROUND(wert*ROUND(AUFTRAG->rabatt,2)/100,2)
        endif

        /** drucke WarenIdentNummer & Ursprungsland */
        zeile += printWarenIdentNummer("AufAus")

        /** drucke Liefertermin aus Posten */
        if ! KWempty(AUFTRAG->KW)
          // if ! empty(getTransField("AUFTRAG->komm2"))
          ?
          // endif
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
          getUser():getCurrentPrintJob():print( Lief_Term(AUFTRAG->KW) , .f.)

        endif

        // Zusatzkommentare, z.B. �berlieferung
        if ! empty(AUFTRAG->Komm3)
          ? SCHMAL_AN,space(len(Out(AUFTRAG->ArtNr))),SCHMAL_AUS,AUFTRAG->komm3
        endif
        if ! empty(AUFTRAG->Komm4)
          ? SCHMAL_AN,space(len(Out(AUFTRAG->ArtNr))),SCHMAL_AUS,AUFTRAG->komm4
        endif

      endcase
      gwert=gwert+wert

      skip
      /** Leerzeile zwischen 2 Artikeln */
      // changed: 31.10.2011: do while Zeile<laenge-UNT_RAND-5.and..not. AUFTRAG->(eof())
      // if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. Zeile<laenge-UNT_RAND-5.and..not. AUFTRAG->(eof())
      if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. Zeile<laenge-UNT_RAND-4.and..not. AUFTRAG->(eof())
        ?
      endif
    enddo
    /** Ende Auftrags-Posten */

    if AUFTRAG->(eof()) .and. ! sonder .and. AUFAUS->AufArt<>"B" // Ausnahme Rahmenauftrag Budget
      zeile += drucke_rabatt_zuschlag("AUFAUS", @gwert, frachtkosten, .t.)
      sonder:=.t.
    endif

    /** Seitenumbruch ? */
    if empty(EinhNr)
      einhNr:=STANDARD_ME
    endif

    // �bertrag oder Summe/Ende?
    if ! AUFTRAG->(eof()) .or. ;
      (zeile > Laenge - UNT_RAND-LieferTerminKopf(EinhNr,"AufAus",.t.)-;
      if(empty(AUFAUS->TextKz_Nr),0,1) - 14 - ;
      if(len(tempText)==0,0,len(tempText)+1))

      if AUFAUS->Aufart <> "K"
        ?
        ? space(47),getTranslation("allgemein.uebertrag",LAND->Sprache,13),transStr(gwert,14,2)
      endif

    else

      Ende:=.t.

      /* Liefertermine aus Auf.Kopf */
      zeile+=LieferTerminKopf(EinhNr,"AufAus")

      if len(tempText) > 0
        ?
        for i:=1 to len(tempText)
          ? tempText[i]
        next
      endif

      tex1=space(41)
      if empty(AUFAUS->IdentNr)
        tex2=space(41)
      else
        tex2=getTranslation("allgemein.identnr",LAND->Sprache,12)+AUFAUS->IdentNr
        tex2=tex2+space(41-len(tex2))
      endif
      tex3=space(41)
      tex4=space(41)
      ? tex1,space(0),"--------------------------------"
      mwwert=0.00
      if AUFAUS->mwst > 0.0
        ? space(42),getTranslation("allgemein.netto",LAND->Sprache,13)+waehrung,;
          transStr(gwert,14,2)
        mw=transStr(AUFAUS->mwst,5,2)
        mwwert=ROUND( AUFAUS->mwst*gwert/100 ,2)
        ? space(42),mw+"% "+getTranslation("allgemein.mwst",LAND->Sprache,4)+":",waehrung,;
          transStr(mwwert,14,2)
      endif
      if AUFAUS->Aufart <> "K"
        ? tex2,space(0),;
          getTranslation("allgemein.brutto",LAND->Sprache,13)+waehrung,transStr(gwert + mwwert,14,2)
        ? tex3,space(0),"================================"
      else
        ? tex2
        ? tex3
      endif
      ?

    endif // Seitenumbruch

    /** Seitenvorschub */
    Zeile:=FormFeed(Zeile,Seite)
  enddo // .not.eof()

  // r�ckschreiben nach Abhol.dbf
  if select("Abhol") > 0
    BEGIN SEQUENCE // krit. Bereich
      bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

      replace ABHOL->Netto with gwert
      replace ABHOL->Brutto with gwert + mwwert
      replace ABHOL->MwSt with AUFAUS->MwSt

      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      RECOVER
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

      // Fehler bereits protokolliert
      // fehler( objErr )

      email(MAIN_EMAIL, "ACHTUNG: Abholauftrag " +AUFAUS->AufNr+;
        " Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN, "Bitte dringend �berpr�fen.")

      Error("ACHTUNG: Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN + ;
        "||Bitte dringend �berpr�fen.",.t.)

    END SEQUENCE
  endif

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  // dateiName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

RETURN
/* EOP Auftrag */

/* druckt Warenidentnummer & Urpsrungsland des aktuellen Artikels
  *
  * Paramater Info: .t. -> kein Druck Zeilen werden nur gez�hlt
  *                 "Alias()" -> Details aus dieser Datei werden im Fehlerfall in Email verschickt
  */
function printWarenIdentNummer(info)
LOCAL aktLandRec, aktSprache, aktFontSizeString
LOCAL subject,body, ausnahmen
LOCAL Zeile:=0

  // Ausnahme Angebotsartikel
  // if alltrim(ARTIKEL->ArtNr) == ANGEBOTS_ARTIKEL
  // return 0
  // endif

  if valtype(info)=="L" .and. info
    return if(empty(ARTIKEL->WarenNr),0,1)
  endif

  if empty(ARTIKEL->WarenNr) .and. len(trim( ARTIKEL->ArtNr )) > 6
    // EMail an H. Weiland
    ausnahmen:=HB_ATokens( getProperty("Miki.fakt.warennr.leer","") , ":" )
    if valtype(info)=="C" .and. aScan( ausnahmen , alltrim(ARTIKEL->ArtNr) ) == 0
      subject:="Artikel ohne Warenidentnummer: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1
      body:=""
      switch upper( info )
      case "AUFAUS"
        body+="AB-Nr  : "+AUFAUS->AufNr +MY_CR+MY_LF
        body+="Kunde  : "+AUFAUS->KundNr+" "+AUFAUS->KurzName +MY_CR+MY_LF
        exit
      case "RECHAUS"
        body+="Re-Nr  : "+RECHAUS->RechNr +MY_CR+MY_LF
        body+="Kunde  : "+RECHAUS->KundNr+" "+RECHAUS->KurzName +MY_CR+MY_LF
        exit
      case "LIEFAUS"
        body+="LS-Nr  : "+LIEFAUS->LSNr+MY_CR+MY_LF
        body+="Kunde  : "+LIEFAUS->KundNr+" "+LIEFAUS->KurzName +MY_CR+MY_LF
        exit
      endswitch

      body += "Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1 +MY_CR+MY_LF
      body += "K�rzel : "+getUser():id +MY_CR+MY_LF
      email(MAIN_EMAIL,subject,body)
    endif
  else // ausdrucken

    aktFontSizeString:=getUser():getCurrentPrintJob():fontSizeString

    ? SCHMAL_AN,space(len(Out(ARTIKEL->ArtNr))),SCHMAL_AUS,KLEIN_AN,;
      getTranslation("AB.warenidentnummer",LAND->Sprache), ARTIKEL->WarenNr
    if ! empty(ARTIKEL->LandKZ)
      aktLandRec:=LAND->(recno())
      aktSprache:=LAND->Sprache
      LAND->(dbseek(ARTIKEL->LandKz))
      ?? getTranslation("AB.ursprungsland",aktSprache),getTransField("LAND->Name",aktSprache)
      LAND->(dbgoto( aktLandRec ))
    endif
    ?? KLEIN_AUS
    ?? getUser():getCurrentPrintJob():setFontSizeString( aktFontSizeString ) // MUST be in seperate line!
  endif

return Zeile
/** eop */

  /*
  * druckt Warenbegleitschein: Posten aus Auftrag oder Auferfas (Parameter Datei)
  */

PROCEDURE Warenbegleitschein(Ausgabe,fromRechnung)
LOCAL Seite:=0,zeile:=0
LOCAL Adresse,Adresse2
LOCAL temp, brauchtVerpackung, erstArtikel, pdfName
LOCAL pdfInfo, upsNr, myKomm1,myKomm2, Paletten, palNr, verpNr
LOCAL verpackungen, verpackung, mArtNrs, verpackungenAB:=hb_hash()
LOCAL restMenge,menge1, mengenString, t , gesVerpMenge, isPhoenixVerp
LOCAL printBuffer, myArt

  default Ausgabe:="D"
  default fromRechnung:=.f.

  Umgebung( WRITE_ALL )

  pdfInfo:=pdfInfo():new( JOB_WBS , AUFAUS->AufNr , .t. )

  // Ausnahme Honsel und VVG oder Miki als Empf�nger
  if left(AUFAUS->KundNr,5) $ KDNR_HONSEL + KDNR_VVG .or. ;
    left(AUFAUS->V_KundNr,5) $ KDNR_HONSEL + KDNR_VVG + MIKI_NR
    Umgebung( LOAD )
    return
  endif

  SPEDIT->(dbseek( AUFAUS->SpedNr ))
  VERSART->(dbseek( AUFAUS->VersNr ))
  KUNDEN->(dbseek( AUFAUS->V_KundNr ))

  /** Miki intern -> immer in Deutsch */
  selLandBySprache(DEUTSCH)

  SPEDIT->(dbseek(AUFAUS->SpedNr))
  // UpsNr drucken? // seit 12.10.14 immer
  KUNDSPED->(OrdSetFocus( 2 )) // KundNr + SpedNr
  KUNDSPED->(dbseek(AUFAUS->V_KundNr + AUFAUS->SpedNr ))
  if ! KUNDSPED->(eof()) .and. ! empty( KUNDSPED->SpedKdNr )
    upsNr:="(Nr:"+trim(KUNDSPED->SpedKdNr)+")"
  endif

  paletten:=HB_ATokens( getProperty("Miki.palette.artnr","") , ":" )

  for each myArt in {"FM","ED",""}

    select AUFTRAG
    if empty(myArt)
      set filter to AUFTRAG->geloescht$"N " .and. .not. AUFTRAG->ART $ "FMED" // falls es noch andere Arten gibt
    else
      set filter to AUFTRAG->geloescht$"N " .and. AUFTRAG->ART $ myArt
    endif

    go top
    do while .not. AUFTRAG->(eof())

      pdfName:=pdfInfo:getLocalizedName( LAND->Sprache , "-"+alltrim(AUFTRAG->ArtNr)+"-"+;
        getKWFileName(AUFTRAG->KW))

      do case
      case Ausgabe=="D"
        Drucker("ON", pdfName , pdfInfo:path ,.f.,PDF_NO_CONFIRM)
      case Ausgabe=="P"
        Drucker("PDF", pdfName , pdfInfo:path ,.f.,PDF_YES_CONFIRM)
      case Ausgabe=="B"
        Drucker("BS")
      case Ausgabe=="NOP" // PDF ohne Abfrage, sonst nix
        //Drucker("PDF",pdfName , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
        // Neu 20190126
        Drucker("NOP")
      endcase

      printBuffer:=printBuffer():new()

      Seite = 1
      zeile:=0

      zeile += wbsKopf()

      ->? FETT_AN,mycenter("Versanddaten",75),FETT_AUS

      adresse:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
        AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)

      if empty(AUFAUS->S_Name) .or. SPEDIT->SpedKZ == "N"
        ->? space(4),Adresse[1]
        ->? space(4),Adresse[2]
        ->? space(4),Adresse[3],space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ->? space(4),Adresse[4],space(0),getTransField("VERSART->Text")
        ->? space(4),Adresse[5],space(0),getTransField("SPEDIT->Name")
        ->? space(4),Adresse[6],space(0),SCHMAL_AN, upsNr, SCHMAL_AUS
      else
        adresse:=getAdrBlock(AUFAUS->S_Name,AUFAUS->S_Partner,AUFAUS->S_Strasse,AUFAUS->S_Zusatz,;
          AUFAUS->S_Land,AUFAUS->S_Plz,AUFAUS->S_Ort)
        adresse2:=getAdrBlock(AUFAUS->V_Name,AUFAUS->V_Partner,AUFAUS->V_Strasse,AUFAUS->V_Zusatz,;
          AUFAUS->V_Land,AUFAUS->V_Plz,AUFAUS->V_Ort)
        ->? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
        ->? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS
        ->? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS,space(0),;
          if(!empty(getTransField("VERSART->Text")),getTranslation("allgemein.versand",LAND->Sprache),"")
        ->? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),getTransField("VERSART->Text")
        ->? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
        ->? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),upsNr
      endif
      ?
      ->? replicate( MY_LINE_CHAR , 75 )
      ->? FETT_AN,myCenter("Artikel",75),FETT_AUS

      // seit 20180707 ein WBS pro Artikel
      // reset variables
      verpackungenAB:=hb_hash()
      erstArtikel:=.f.

      /* Posten drucken */
      SELECT AUFTRAG
      do while Zeile < DRUCKER->Laenge - UNT_RAND - 4 .and. (! erstArtikel .or.;
        len(alltrim( AUFTRAG->ArtNr )) <= FRACHT_LAENGE) .and. .not. AUFTRAG->(eof())

        restMenge:=AUFTRAG->Menge - AUFTRAG->GeliefGes - AUFTRAG->Gelief

        if restMenge <= 0
          skip
          loop
        endif

        // merke Verpackung
        if len(alltrim( AUFTRAG->ArtNr )) <= FRACHT_LAENGE

          verpackungenAB[alltrim(AUFTRAG->ArtNr)]:=;
            getVerpackungsMenge(verpackungenAB, AUFTRAG->ArtNr) + restMenge

        else // normaler Artikel

          // bei Teillieferung (Rechnung) nur ge�nderte Artikel drucken, 20180714
          if fromRechnung .and. AUFTRAG->Gelief == 0
            skip
            // gehe auf n�chsten echten Artikel
            do while len(alltrim( AUFTRAG->ArtNr )) <= FRACHT_LAENGE .and. .not. AUFTRAG->(eof())
              skip
            enddo
            exit
          endif

          if myArt=="F" .or. myArt ==""
            erstArtikel:=.t.
          endif

          // keine Zoll-Zuschl�ge (& Paletten) auf WBS drucken
          if ! isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and.;
            ! aContains( paletten , alltrim(AUFTRAG->ArtNr))

            ARTIKEL->(dbseek( AUFTRAG->ArtNr ))

            ->? SCHMAL_AN,out(AUFTRAG->ArtNr),SCHMAL_AUS, PS_Schmal(left(AUFTRAG->komm1,30))
            ->?? getMengePreis(restMenge,nil),"Lagerort:",getArtikelLagerOrt(13)
            ->? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
              PS_Schmal(left(AUFTRAG->komm2,30)),space(11), "Liefer-KW  :",AUFTRAG->KW

	    /** drucke Gerate-Nummer */
            if ! empty(AUFTRAG->GerVon) .or. ! empty(AUFTRAG->GerBis)
              ?
              ->? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS,"Ger�te Nr.",AUFTRAG->GerVon
              if ! empty(AUFTRAG->GerBis)
                ->?? "-",AUFTRAG->GerBis
              endif
            endif

            // Spezialfall Ph�nix -> Verpackungen extrahieren
            if isPhoenixAuftrag()
              if isPhoenixSpeditionsArtikel( AUFTRAG->ArtNr )

                // Palette
                palNr:=getProperty("Miki.wbs.phoenix.palette","")
                verpackungenAB[palNr]:=getVerpackungsMenge(verpackungenAB, palNr) + restMenge

                // Schrumpfverpackung?
                brauchtVerpackung:=HB_ATokens( getProperty("Miki.palette.brauchtverpackung.artnr","") , ":" )
                if aContains( brauchtVerpackung , palNr )
                  verpNr:=getProperty("Miki.palette.verpackung.artnr","")
                  verpackungenAB[verpNr]:=getVerpackungsMenge(verpackungenAB, verpNr ) + restMenge

                endif

              elseif ! isPhoenixPaketdienstArtikel( AUFTRAG->ArtNr ) .and.;
                ! isZollZuschlagArtikel(AUFTRAG->ArtNr)
                // Kartons, alle VPE
                verpNr:=getProperty("Miki.wbs.phoenix.karton","")
                verpackungenAB[verpNr]:=getVerpackungsMenge(verpackungenAB, verpNr ) + restMenge
              endif

            endif
          endif


        endif

        skip

      enddo
      /** Ende AUFTRAGs-Posten */

      if (myArt == "F" .or. myArt == "") .and. ! erstArtikel // Artikel nicht drucken, da bei Teillieferung unver�ndert
        loop
      endif

      zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)

      verpackungen:=HB_ATokens( getProperty("Miki.wbs.verpackung","") , ":" )

      // Seitenumbruch (einfach gehalten, da i.d.R. nicht notwendig)
      if Zeile >= DRUCKER->Laenge - ( len(verpackungen)*2 + 10 )
	/** Seitenvorschub */
        Zeile:=FormFeed(Zeile,Seite)
        zeile += wbsKopf()
        ?
        ?
      endif

      // ?
      ? replicate( MY_LINE_CHAR , 75 )
      ? FETT_AN,myCenter("Verpackung + Versand",75),FETT_AUS

      ? "Anz.  Art.-Nr. Verp.   Bezeichnung",space(7),"Inhalt Gesamt Datum   Name"
      ? "Verp.           Nr.               ",space(7)," Verp.  Menge"
      ? replicate( MY_LINE_CHAR , 75 )
      ?

      select Artikel // brauchen wir damit Umgebung die recno in StueckListe() speichert
      for each verpackung in verpackungen

        mengenString:=""

        // falls mehrere Verpackung nimm die letzte
        if "," $ verpackung

          temp:=HB_ATokens( verpackung , "," )
          ARTIKEL->(dbseek( getVerpackungArtNr( temp[len(temp)] ) ))

          gesVerpMenge:=0
          mengenString:=""
          isPhoenixVerp:=.f.
          for each t in temp
            menge1:=getVerpackungsMenge( verpackungenAB , t )
            if menge1 > 0
              isPhoenixVerp:=isPhoenixSpeditionsArtikel( t )
              gesVerpMenge += menge1
              if empty( mengenString )
                mengenString:=alltrim(str(menge1,7,0))
              else
                mengenString += "," + alltrim(str(menge1,7,0))
              endif
            endif
          next

          // falls isPhoenixSpeditionsArtikel dann nur 1x Gesamt-Menge
          if isPhoenixVerp
            mengenString:=alltrim(str(gesVerpMenge,7,0))
          endif
          mengenString:=myCenter(alltrim(mengenString),5)

        else
          ARTIKEL->(dbseek( getVerpackungArtNr( verpackung )))
          menge1:=getVerpackungsMenge( verpackungenAB , verpackung )
          if menge1 > 0
            mengenString:=myCenter(alltrim(str(menge1,7,0)),5)
          endif
        endif

        // if empty( ARTIKEL->Bez2 )
        // myKomm1:=space(len( ARTIKEL->Bez1 ))
        // myKomm2:=ARTIKEL->Bez1
        // else
        myKomm1:=ARTIKEL->Bez1
        myKomm2:=ARTIKEL->Bez2
        // endif

        // hole Miki Art.Nr aus St�ckliste
        mArtNrs:=StueckListe():new( ARTIKEL->ArtNr, ARTIKEL->Art ):getMaterial()

        if empty(mengenString)
          ? FETT_AN,replicate("_",5),FETT_AUS
        else
          ? FETT_AN,mengenString,FETT_AUS
        endif

        if len(mArtNrs)>0
          ?? SCHMAL_AN,out( mArtNrs[1]:artNr ),SCHMAL_AUS
        else
          ?? SCHMAL_AN,space(len(out(ARTIKEL->ArtNr))),SCHMAL_AUS
        endif
        ?? padr( removePhoenix( verpackung ) ,6), KLEIN_AN,myKomm1,KLEIN_AUS

	/* 2. Zeile */
        ? space(23),KLEIN_AN,myKomm2,KLEIN_AUS,space(1),;
          FETT_AN,"_____  _____  ______  _______",FETT_AUS

      next


      ? KLEIN_AUS, replicate( MY_LINE_CHAR , 75 )
      ?
      ?
      ? FETT_AN,"Versendet/geliefert am:_____________ (Datum) ______________________ (Name)",;
        FETT_AUS

      /** Seitenvorschub */
      Zeile:=FormFeed(Zeile,Seite)

      Drucker("Off")
    enddo // .not.eof()

  next // Art

  Umgebung( LOAD )

RETURN
/* EOP */

static function wbsKopf()
LOCAL zeile:=0
  ? space(16),FETT_AN,space(0), getTranslation("allgemein.wbs",LAND->Sprache),;
    getTranslation("allgemein.miki",LAND->Sprache),FETT_AUS

  ?? space(7),"vom",getUser():date
  ? replicate( MY_LINE_CHAR , 75 )

  ? SCHMAL_AN,"AB-Nr. Kunden-Nr. Kurz-Name       Bestell-Nr. Kd        Telefon-Nr./Fax-Nr.",;
    SCHMAL_AUS
  ? AUFAUS->AufNr,KdOut(AUFAUS->KundNr),;
    KLEIN_AN,AUFAUS->KurzName,AUFAUS->BestNr, alltrim(AUFAUS->Telefon),alltrim( AUFAUS->Fax ),KLEIN_AUS

  ? replicate( MY_LINE_CHAR , 75 )
return zeile

/** druckt die Menge der �bergebenen Verpackung aus, if applicable */
static function getVerpackungsMenge( verpackungenAB , verpackung )
LOCAL result:=0
  if HHasKey( verpackungenAB , alltrim( verpackung ) )
    result:=verpackungenAB[ alltrim( verpackung ) ]
  endif
return result
/** eop */

  /*
  *  druckt ein fast leeres Deckblatt zum Versand an eine alternat.  Rechnungsadresse
  *  s. Kunden F6
  */

Procedure rechnDeckblatt(Ausgabe)
LOCAL Seite:=0,zeile:=0
LOCAL Laenge, Adresse,i

  // drucke Deckblatt mit alternat. Rechnungsadresse, if applicable
  if ( empty(RECHAUS->A_Name) .and. empty(RECHAUS->A_Partner) ) .or. ! Ausgabe $ "D"
    return
  endif

  Drucker("ON", RECHAUS->RechNr + "-Deckblatt" , nil ,.f.,PDF_NONE,1)

  // FormularDruck
  getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))

  Laenge:=DRUCKER->Laenge
  adresse:=getAdrBlock(AUFAUS->A_Name,AUFAUS->A_Partner,AUFAUS->A_Strasse,AUFAUS->A_Zusatz, AUFAUS;
    ->A_Land,AUFAUS->A_Plz,AUFAUS->A_Ort)

  for i:=1 to 7
    ?
  next
  ? space(4),Adresse[1]
  ? space(4),Adresse[2]
  ? space(4),Adresse[3]
  ? space(4),Adresse[4]
  ? space(4),Adresse[5]
  ? space(4),Adresse[6]

  for i:=1 to 18
    ?
  next

  ? FETT_AN,"Rechnung bitte an diese Adresse mit diesem Deckblatt versenden.",FETT_AUS

  /** Seitenvorschub */
  Zeile:=FormFeed(Zeile,Seite)
  Drucker("OFF")

return
/** eop*/

/** liefert die �bergebene Verpackung ohne Phoenix Versand Artikel */
static function removePhoenix( verpackung )
LOCAL values:=HB_ATokens( verpackung , "," ) , v
LOCAL result:=""
  for each v in values
    if ! isPhoenixSpeditionsArtikel( v )
      if empty(result)
        result:=v
      else
        result += ","+v
      endif
    endif
  next
return result
/** eof */


/* druckt Ger�te-nummern des aktuellen Artikels aus auftrag.dbf*/
function printGeratNummer()
LOCAL Zeile:=0, aktFontSizeString, text

  Umgebung( WRITE_ALL )

  select Konsig
  index on KONSIG->Artnr+kwindex(KONSIG->KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for KONSIG->AufNr==AUFTRAG->AufNr .and. KONSIG->ArtNr == AUFTRAG->Artnr .and. ;
    (! empty(KONSIG->GerVon) .or. ! empty(KONSIG->GerBis))
  go top

  if ! KONSIG->(eof())

    text:=getTranslation("AB.geratnummer",LAND->Sprache)

    aktFontSizeString:=getUser():getCurrentPrintJob():fontSizeString
    do while ! KONSIG->(eof())
      ? SCHMAL_AN,space(len(Out(ARTIKEL->ArtNr))),SCHMAL_AUS,;
        KLEIN_AN, text, KONSIG->Liedat,KONSIG->GerVon,"-",KONSIG->GerBis,KLEIN_AUS
      text:=space(len(text))
      skip
    enddo

    ?? getUser():getCurrentPrintJob():setFontSizeString( aktFontSizeString ) // MUST be in seperate line!
  endif

  Umgebung( LOAD )

return zeile
  /** eof */

      /** Liefert ein Array mit einer Zeile je offenere GelangensBescheinigung zur�ck
      *
      * RECHAUS muss ge�ffnet sein, ehemals in rechnung() druck
      *
      */
static FUNCTION getOpenGelang(KundNr)
  ignore KundNr
return {} // disabled 25.5.2012
  // static FUNCTION getOpenGelang(KundNr)
  // LOCAL result:={}
  // LOCAL aktSel:=alias()
  // LOCAL aktRec,tempText

  // select Rechaus
  // aktRec:=recno()
  // loca for RECHAUS->KundNr==KundNr .and. ! empty(RECHAUS->GelNr) .and. 
  // empty(RECHAUS->GelEing) .and. empty(RECHAUS->GelReNr)
  // if ! RECHAUS->(eof())
  // MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
  // do while ! RECHAUS->(eof())
  // tempText:=getTranslation("AB.gelang.warnung.posten",LAND->Sprache)
  // tempText:=strtran(tempText,"$GELNR",RECHAUS->GelNr)
  // tempText:=strtran(tempText,"$DATUM",dtoc(RECHAUS->ReaDat))
  // tempText:=strtran(tempText,"$MWST",str(MWST_KZ->Mwst,5,2)+"% = @"+;
  // alltrim(transstr(round(MWST_KZ->mwst*RECHAUS->Netto/100,2),11,2))+" Euro@")
  // aadd(result,tempText)
  // cont
  // enddo
  // endif
  // go (aktRec)
  // select (aktSel)

  // return result
/** eof */



/* Liefert GelangensBescheinigungsText je nach Empf�nger und Mwst */
function getGBSText(gWert)
LOCAL tempText:=NIL
  // Berechne Gr��e GelangensBescheinigung Hinweise
  do case
  case upper(RECHAUS->EG)=="D"
    // NOP
  case upper(RECHAUS->EG)=="J"
    if RECHAUS->MwSt_KZ=="0"
      tempText:=getTranslation("rechnung.gelang.befreiung",LAND->Sprache)
    else
      tempText:=getTranslation("AB.gelang.erstattung.eu",LAND->Sprache)
    endif
  otherwise
    if RECHAUS->MwSt_KZ=="1"
      tempText:=getTranslation("AB.gelang.erstattung.sonst",LAND->Sprache)
    else
      tempText:=getTranslation("rechnung.nichtEU.text",LAND->Sprache)
      tempText:=strtran(tempText,"$DATUM",dtoc(RECHAUS->ReaDat))
    endif
  endcase

  if tempText <> NIL
    MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
    tempText:=strtran(tempText,"$MWST",transstr(MWST_KZ->Mwst,5,2)+"% = @"+;
      alltrim(transstr(round(MWST_KZ->mwst*Gwert/100,2),11,2))+" Euro@")
  endif

return tempText
/** eof */


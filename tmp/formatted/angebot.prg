/* Modul: Angebot.prg   (geh�rt zu Fakt,Fakt2,FaktDruc)
*
* enth�lt alles bzgl. Angebote
* Druck in: Fakt_dru.prg
*/

#include "Miki.ch"
#define TEMP_NUMMER right("*****"+getUser():getLongID(),len(ANGAUS->AngNr))

/** folgende Abstaende sind von unten gezaehlt */
#define UNT_RAND 8 // FIXME: warum nicht "LISTE->Unt_Rand" ?

/* erfassen von Angeboten
*/
PROCEDURE Ang_erfassen(kopAngNr, kopArtNr, kopKundNr)
LOCAL Ende:=.f. , changed:=.f.,changedKopf:=.f.
LOCAL ant:="N" , M_AngNr:=""
LOCAL GetList:={}
LOCAL Auswahl:=0
LOCAL Ausgabe:="D"
MEMVAR MerkNr // ,Ang_Kopie
PRIVATE MerkNr:=0 // , Ang_Kopie:=.f.

  cls
  Titel("Angebote  erfassen/drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag" , "AngAus" , "ZahlKond" ,"Mat_Kz";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "AngPost";
    ,"Rabatt" , "Text_Kz" ,"Kunden" ,"Land" , "Verkauf", "KundSped";
    ,"Erl_Grup", "Maschine", "LiefTerm" ,"Text" ,"Spedit","AvPost","ArtText")


    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  SELECT Auftrag
  SET RELATION To AUFTRAG->ArtNr INTO ARTIKEL, TO AUFTRAG->ME INTO Einheit
  select artikel
  set relation to ARTIKEL->ME into Einheit
  select AngAus
  set relation to ANGAUS->textkz_Nr into Text_Kz,to ANGAUS->zknr into zahlkond,;
    to ANGAUS->versNr into versart

  if kopAngNr <> NIL .and. .not. empty(kopAngNr)
    ANGAUS->(dbseek(kopAngNr))
    if ANGAUS->(eof())
      Error(ACHTUNG+" Angebot: " + kopAngNr + " nicht gefunden.")
    else
      // ang_Kopie( .f. ) // kopiere Angebot ohne Abfrage
      // doch nicht neu erfassen/kopieren, sondern nur anzeigen
      keyboard kopAngNr + chr(K_RETURN)
    endif
  endif

  // neues Angebot mit vorgegebenen Kunden (STRG-G im Kunden)
  if kopKundNr <> NIL .and. .not. empty(kopKundNr)
    keyboard chr(K_RETURN) + kopKundNr + chr(K_RETURN)
  endif

  // neues Angebot mit vorgegebenen Artikel (STRG-G im Artikel)
  if kopArtNr <> NIL .and. .not. empty(kopArtNr)
    keyboard chr(K_RETURN) // springe direkt auf Kundennr.
  endif

  do while ! Ende

    /* Kopf eingeben */
    select AngAus

    go bottom
    skip // leeren Satz anzeigen
    M->MerkNr:=0
    @ 2,0 clear
    Ang_Kopf_Disp()
    Ende:=Ang_Kopf(0) // 1. Mal komplett editieren
    changedKopf:=getUpdated()

    // if M->Ang_kopie
    // M->ang_Kopie:=.f.
    // loop
    // endif

    /* gehe auf editierten Satz */
    select AngAus
    if M->MerkNr==0 .or. Ende
      loop
    endif
    go M->MerkNr


    /*** Posten kopieren ***/
    select AngPost
    seek ANGAUS->AngNr

    select Auftrag
    zap

    /* alle passenden Posten kopieren */
    if ! ANGAUS->AngNr==TEMP_NUMMER // altes Angebot
      select AngPost
      do while ANGPOST->AngNr==ANGAUS->AngNr .and. ! eof()
        select Auftrag
        add_rec(0)
        overwrite("Angpost",.t.)
        replace AUFTRAG->AufNr with ANGPOST->AngNr
        select AngPost
        skip
      enddo
    endif

    // default Wert f�r Summe = N, ebenso bei "alten" unbekannten Angeboten
    // Summe merken seit 22.2.2015
    if ! ANGAUS->Summe $ "JN"
      replace ANGAUS->Summe with "N"
    endif

    // neues Angebot mit vorgegebenen Artikel (STRG-A)
    if kopArtNr <> NIL .and. .not. empty(kopArtNr)
      keyboard kopArtNr + chr(K_RETURN)
      // aber nur 1x
      kopArtNr:=NIL
    endif

    /*** Posten editieren **/
    changed:=(Ang_Bauch() .or. changedKopf)

    /* Auswahl-Menu */
    setcolor(COLWIN)
    Fenster(5,16,13,62)
    @ 6,20 say 'Drucken als:'
    @ 8,20 say 'Angebot         '
    @ 10,20 say 'Summe ausdrucken?' get ANGAUS->Summe Picture "!" valid ANGAUS->Summe $"JN";
      when Message("Summe ausdrucken? (@J@/@N@)?")
    @ 12,20 say 'Drucker/Bildschirm/PDF/Excel (D/B/P/E) ' get Ausgabe Picture "!" valid Ausgabe $"DBPE";
      when Message("Ausgabe auf @D@rucker, @B@ildschrim, @P@DF Datei oder @E@xcel?")
    read

    if ABBRUCH .and. changed
      SetLastKey(0)
      HB_KEYCLEAR()
      Ausgabe:="P"
    endif

    // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
    // do while ! Login_change(12,20,"Sachbearbeiter: ")
    // enddo
    setcolor(COLNOR)

    /* neue Ang.Nr. vergeben */
    if ANGAUS->AngNr==TEMP_NUMMER // neuer Satz
      /* hole akt. Ang.Nr, schreiben */
      M_AngNr:=hole("AngNr",WRITE,.t.)
      /* checken ob nicht schon vorhanden */
      select AngAus
      seek M_AngNr
      if ! eof()
        Error("Angebots"+NUMMER_DOPPELT)
      endif
      do while ! eof()
        Message("Suche n�chste freie Angebots-Nummer.  Bitte warten...")
        M_AngNr:=hole("AngNr",WRITE,.t.)
        seek M_AngNr
      enddo
      go M->MerkNr
      rec_lock(0)
      replace ANGAUS->AngNr with M_AngNr
    endif

    dbcommitall()

    /* zuerst Angebot drucken scheint f�r User schneller ! */
    /* Nachteil: AngAus l�nger gelockt :( */
    if ABBRUCH
      if changed
        Angebot(Ausgabe)
      endif
    else
      /* Angebot drucken */
      Message("Angebot: @"+ANGAUS->AngNr+"@ wird gedruckt.  Bitte warten...")
      Angebot(Ausgabe)
    endif

    /*** Posten r�ckschreiben ***/
    Message("Angebot wird gespeichert.  Bitte warten...")
    /* merke alle editierten Angebote */
    select Auftrag
    go top
    select AngPost
    seek ANGAUS->AngNr
    do while ! eof() .and. ANGPOST->AngNr==ANGAUS->AngNr
      rec_lock(0)
      delete
      skip
    enddo

    /* evtl. restl. neue Posten anh�ngen */
    do while ! AUFTRAG->(eof())
      add_rec(0)
      replace ANGPOST->AngNr with ANGAUS->AngNr
      replace ANGPOST->ArtNr with AUFTRAG->ArtNr
      replace ANGPOST->KOMM1 with AUFTRAG->KOMM1
      replace ANGPOST->KOMM2 with AUFTRAG->KOMM2
      replace ANGPOST->E_KOMM1 with AUFTRAG->E_KOMM1
      replace ANGPOST->E_KOMM2 with AUFTRAG->E_KOMM2
      replace ANGPOST->MENGE with AUFTRAG->MENGE
      replace ANGPOST->PREIS with AUFTRAG->PREIS
      replace ANGPOST->RABATTGR with AUFTRAG->RABATTGR
      replace ANGPOST->KZ with AUFTRAG->KZ
      replace ANGPOST->GELIEF with AUFTRAG->GELIEF
      replace ANGPOST->KW with AUFTRAG->KW
      replace ANGPOST->KW_TEXT with AUFTRAG->KW_TEXT
      replace ANGPOST->ME with AUFTRAG->ME
      replace ANGPOST->PE with AUFTRAG->PE
      replace ANGPOST->RABATT with AUFTRAG->RABATT
      replace ANGPOST->KUNDNR with ANGAUS->KUNDNR
      replace ANGPOST->GELIEFGES with AUFTRAG->GELIEFGES
      replace ANGPOST->AUFART with ANGAUS->AUFART
      replace ANGPOST->ERL_GRUPPE with AUFTRAG->ERL_GRUPPE
      replace ANGPOST->ERL_KONTO with AUFTRAG->ERL_KONTO
      replace ANGPOST->ERL_KZ with AUFTRAG->ERL_KZ
      replace ANGPOST->AUFDAT with ANGAUS->AUFDAT
      AUFTRAG->(dbskip(1))
    enddo

    dbcommitall()
    unlock all

    changed:=.f.
    checkUSALimit("Angaus")

  enddo // Ende Auftrags-Erfassung

  /* neuen Datensatz l�schen ? */
  select AngAus
  seek TEMP_NUMMER
  do while ! eof() .and. ANGAUS->AngNr==TEMP_NUMMER
    rec_lock(0)
    delete
    skip
  enddo

  select Auftrag
  zap // immer leer !

  close data

RETURN
/* EOP Ang_erfassen */


/* 
* Eingabe des Angebot-kopfes
*
* Parameters: 0 == komplett �nderbar
*             1 == AngNr fix , Rest �nderbar
*             2 == nur anzeigen
* R�ckgabe  : Ende ja/nein
*/
FUNCTION Ang_Kopf(Edit)
LOCAL GetList:={}
LOCAL M_AngNr
LOCAL ob:=1
LOCAL orgAltF8:=SetKey( K_F8 )

  if edit==0
    M_AngNr:=hole("AngNr",LOAD) // hole neuste AnegbotsNr, nur lesen
    @ ob+1,14 get M_AngNr picture '@K #####' valid { |oGet| shift(oGet) .and. AngNr_nach(oGet) };
      when ( Message('Angebotsnummer eingeben.          @F12@=Hilfe') )
    setCargo(ATail(GetList),CARGO_UPDATE_IGNORE,.t.) // �nderungen an ABNr setzen nicht slUpdated
  else
    @ ob+1,14 say ANGAUS->AngNr
  endif

  /* anschriften */
  // @ ob+2,38 get ANGAUS->KundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",.f.) .and. A_KdNr_nach(oGet) } when {|| SetKey(K_F3,{|| Ang_Kopie()}),Message("Kunden-Nummer eingeben.              @F3@=kopieren    @F12@=Hilfe")}
  @ ob+2,38 get ANGAUS->KundNr PICTURE KDNR_PICT;
    valid { |oGet| check(oGet,"Kunden",.f.) .and. A_KdNr_nach(oGet) } when Message("Kunden-Nummer "+;
    "eingeben.          @F12@=Hilfe")
  @ ob+4,38 get ANGAUS->V_KundNr PICTURE KDNR_PICT;
    valid;
    {;
    |oGet|;
    check(oGet,"Kunden",.f.);
    .and. V_A_KdNr_nach(oGet) .and. MySetKey( K_F8 , orgAltF8 )} when Message("Kundennummer "+;
    "Versand eingeben   @F8@=Kund.Nr. kopieren   @F12@=Hilfe") .and. MySetKey( K_F8 , { || copyAngKundNr() } )

  // @ ob+8,38 get ANGAUS->R_KundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",.f.) .and. R_A_KdNr_nach(oGet) } when Message("Kundennummer Rechnung eingeben   @F12@=Hilfe")

  // Sprache jetzt immer
  @ ob+8,49 get ANGAUS->Sprache picture "!" valid { |oGet| nachSprache(oGet) }

  /* Datum,Art,Bestkto */
  @ ob+3,14 GET ANGAUS->AufDat when Message('Angebotsdatum eingeben.       @*@=Heute @+@/@-@')
  @ ob+5,14 get ANGAUS->VersNr picture "@9" valid { |oGet| check(oGet,"VersArt",.f.) };
    when Message('Versandart eingeben.             @F12@=Hilfe')
  @ ob+6,14 get ANGAUS->SpedNr picture "@9";
    when { || AngSpedVor() } valid { |oGet| AngSpedNach(oGet) }

  @ ob+9,1 GET ANGAUS->BestKonto when Message('Bestellkonto eingeben.')
  @ ob+11,1 GET ANGAUS->BestDat when Message('Bestelldatum eingeben.       @*@=Heute @+@/@-@')
  @ ob+13,1 GET ANGAUS->BestNr when Message('Bestell - Nr. eingeben.')

  @ ob+15,1 say "Fremd-W�hrung:" GET ANGAUS->FremdWaehr Picture "@!";
    when Message('Fremdw�hrung K�rzel eingeben.')
  @ ob+16,1 say "Fremd-Summe..:" GET ANGAUS->FremdSumme picture "@S10";
    when Message('Summe in Fremdw�hrung eingeben.')

  /* Zahlungskond. */
  @ ob+12,39 get ANGAUS->So_Rabatt valid { |oGet| val(oGet:buffer)>=0 .and. AngRabatt_nach(oGet) };
    when Message("Sonder/H�ndler-Rabatt eingeben. ")
  @ ob+12,69 get ANGAUS->Zuschlag valid { |oGet| val(oGet:buffer)>=0 };
    when Message("Energiekosten-Zuschlag eingeben. ")
  @ ob+13,39 get ANGAUS->ZKNr picture "@9";
    valid { |oGet| check(oGet,"ZahlKond",.f.) .and. Ang_Kopf_disp() } when Message("Zahlungskondi"+;
    "tion eingeben.   @F12@=Hilfe")
  @ ob+15,39 get ANGAUS->Gueltig when Message("Angebotsg�ltigkeit eingeben.")

  @ ob+16,39 get ANGAUS->TextKz_Nr picture "@!" ;
    valid { |oGet| check(oGet,"Text_Kz").and. Ang_Kopf_disp()};
    when Message("Werbe - Text KZ eingeben.     @F12@=Hilfe")

  /* Zoll-Zuschlag hinzuf�gen bei nicht EU Kunden? */
  @ ob+21,45 get ANGAUS->ZollZuschl picture "!" valid {|oGet| nachZollZuschlag(oGet,"Angaus")};
    when Message('Zoll/Eur1 Zuschlag automatisch hinzuf�gen? (@J@/@N@)')

  /* Ph�nix Fracht automatisch berechnen?  s. auch property: phoenix.fracht.automatisch */
  @ ob+21,75 get ANGAUS->PhoenixFr picture "!" ;
    when Message('Ph�nix Fracht automatisch hinzuf�gen? (@J@/@N@)')

  if ! edit==2
    read
  endif
  MySetKey( K_F10 , nil )

RETURN( empty(ANGAUS->KundNr) .or. ANGAUS->KundNr==KDNR_LEER )
/* EOF AngKopf */

/* Function AngRabatt_nach()
*
* wird nach Eingabe des SoRabatts beim Angebot ausgef�hrt
*/
FUNCTION AngRabatt_nach(oGet)
  if oGet:changed .and. val(oGet:buffer)>0 .and. empty(KUNDEN->Rabatt_KZ)
    if Message("Sonderrabatt ? ( J / N ) ","JN")=="J"
      replace ANGAUS->Rabatt_KZ with " "
    else
      replace ANGAUS->Rabatt_KZ with "H"
    endif
    Ang_Kopf_Disp()
  endif

RETURN(.t.)



/* Funktionen f�r Kopfeingabe   *************************
*/
/* nach Ang.Nr */
STATIC FUNCTION AngNr_nach(oGet)
LOCAL M_AngNr

  if ! lastkey()==K_RETURN
    RETURN(.f.)
  endif
  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
  endif

  select AngAus

  /* vorher neuer Satz, jetzt immer noch */
  if oGet:buffer==TEMP_NUMMER
    go M->MerkNr
  else
    /* vorher neuer Satz jetz umentschieden */
    seek TEMP_NUMMER
    if ! eof()
      rec_lock(0)
      delete
    endif

    seek oGet:buffer
    if eof()
      /* neue vorgeschlagene Nr. �bernommen */
      if oGet:original==oGet:Buffer
        oget:varput(TEMP_NUMMER)
        oGet:updateBuffer()
        if ! add_rec(5) // Satz bleibt gelockt
          Error("AngAus.dbf"+DATEI_EXCL)
          RETURN(.f.)
        endif
        M->MerkNr:=recno()
        REPLACE ANGAUS->AngNr WITH TEMP_NUMMER
        REPLACE ANGAUS->AufDat WITH getUser():date
        REPLACE ANGAUS->BestDat WITH getUser():date
        REPLACE ANGAUS->MWST_KZ WITH "1"
        MWST_KZ->(dbseek("1"))
        REPLACE ANGAUS->MWST WITH MWST_KZ->MWST
        replace ANGAUS->Gueltig with getTranslation("angebot.gueltig",DEUTSCH)
      else
        M_AngNr:=hole("AngNr",LOAD) // hole akt. Ang.Nr, lesen
        Error("Angebot: "+oget:buffer+NICHT_VORHANDEN)
        oget:varput(M_AngNr)
        oGet:updateBuffer()
        oGet:killfocus()
        oGet:setfocus()
        M->MerkNr:=0
        RETURN(.f.)
      endif
    else
      if ! Rec_Lock(5)
        Error(SATZ_EXCL)
        RETURN(.f.)
      endif
      M->MerkNr:=recno()
    endif

  endif

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(ANGAUS->Sprache)

  Ang_kopf_disp()
  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  // sicher(WRITE) // merke akt. Werte

RETURN(.t.)
/* EOF AngNr_nach */


/* nach KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
FUNCTION A_KdNr_nach(oGet)
LOCAL spedits

  set key K_F3 to
  if oGet:changed
    REPLACE ANGAUS->Name WITH KUNDEN->Name
    REPLACE ANGAUS->KurzName WITH KUNDEN->KurzName
    REPLACE ANGAUS->Partner WITH KUNDEN->Partner
    REPLACE ANGAUS->Strasse WITH KUNDEN->Strasse
    REPLACE ANGAUS->Zusatz WITH KUNDEN->Zusatz
    REPLACE ANGAUS->Plz WITH KUNDEN->PLZ
    REPLACE ANGAUS->Land WITH KUNDEN->Land
    REPLACE ANGAUS->Ort WITH KUNDEN->Ort
    REPLACE ANGAUS->Sprache WITH KUNDEN->Sprache

    // Sammelstelle
    REPLACE ANGAUS->S_Name WITH KUNDEN->S_Name
    REPLACE ANGAUS->S_Partner WITH KUNDEN->S_Partner
    REPLACE ANGAUS->S_Strasse WITH KUNDEN->S_Strasse
    REPLACE ANGAUS->S_Zusatz WITH KUNDEN->S_Zusatz
    REPLACE ANGAUS->S_Plz WITH KUNDEN->S_PLZ
    REPLACE ANGAUS->S_Land WITH KUNDEN->S_Land
    REPLACE ANGAUS->S_Ort WITH KUNDEN->S_Ort

    /* Versand-KundenNr */
    if KUNDEN->VA <> "J" // Versandanschrift gleich
      REPLACE ANGAUS->V_KundNr WITH ANGAUS->KundNr
      REPLACE ANGAUS->V_Name WITH KUNDEN->Name2
      REPLACE ANGAUS->V_Partner WITH KUNDEN->Partner2
      REPLACE ANGAUS->V_Strasse WITH KUNDEN->Strasse2
      REPLACE ANGAUS->V_Zusatz WITH KUNDEN->Zusatz2
      REPLACE ANGAUS->V_Plz WITH KUNDEN->PLZ2
      REPLACE ANGAUS->V_Land WITH KUNDEN->Land2
      REPLACE ANGAUS->V_Ort WITH KUNDEN->Ort2
      REPLACE ANGAUS->V_Sprache WITH KUNDEN->Sprache2

      // VA ebenfalls nach Lieferanschrift (5.5.15)
      REPLACE ANGAUS->VersNr WITH KUNDEN->VersNr

      // Spedition ebenfalls nach Lieferanschrift (16.11.15)
      spedits:=getKundSpedits( KUNDEN->KundNr )
      if len(spedits) == 1 // ansonsten muss der Benutzer manuell ausw�hlen!
        REPLACE ANGAUS->SpedNr WITH spedits[1]
      else
        REPLACE ANGAUS->SpedNr WITH ""
      endif

    else
      REPLACE ANGAUS->V_KundNr WITH ""
    endif
    /* Rechnungs-Anschrift */
    // if empty(KUNDEN->RechAnschr) // Rechnungsanschrift gleich
    // REPLACE ANGAUS->R_KundNr WITH ANGAUS->KundNr
    // REPLACE ANGAUS->R_Name WITH KUNDEN->Name
    // REPLACE ANGAUS->R_Partner WITH KUNDEN->Partner
    // REPLACE ANGAUS->R_Strasse WITH KUNDEN->Strasse
    // REPLACE ANGAUS->R_Zusatz WITH KUNDEN->Zusatz
    // REPLACE ANGAUS->R_Plz WITH KUNDEN->PLZ
    // REPLACE ANGAUS->R_Land WITH KUNDEN->Land
    // REPLACE ANGAUS->R_Ort WITH KUNDEN->Ort
    // else
    // REPLACE ANGAUS->R_KundNr WITH ""
    // endif

    REPLACE ANGAUS->So_Rabatt WITH KUNDEN->So_Rabatt
    REPLACE ANGAUS->Rabatt_Kz WITH KUNDEN->Rabatt_KZ

    // Ausnahme Honsel ohne Energiekostenzuschlag 21.3.23
    if left(ANGAUS->KundNr,5) $ getProperty("Miki.energiekostenzuschlag.ausnahme","")
      REPLACE ANGAUS->Zuschlag WITH 0
    else
      REPLACE ANGAUS->Zuschlag WITH val(getProperty("Miki.energiekostenzuschlag","0.0"))
    endif


    // Hinweis: hier werden die Zahlungskond. vom Hauptkunde genommen,
    // da kein Rechngsempf�nger erfasst wird bzw. bekannt ist
    // Telefonat H. Weiland 5.5.2015
    REPLACE ANGAUS->ZKNr WITH KUNDEN->ZKNr


    setzeMwstEgKZ("Angaus")

    // pr�fe ob Werkzeug und andere Artikel gemischt, bei ausl�nd. Kunden nicht zul�ssig
    // nur Hinweis!!!
    checkWerkzeug(.t.)

    REPLACE ANGAUS->LiefNr WITH KUNDEN->Lfd_Nr
    REPLACE ANGAUS->IdentNr WITH KUNDEN->IdentNr

    ANGAUS->(dbcommit())

    selLandBySprache(ANGAUS->Sprache)

    Ang_kopf_disp()
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif

RETURN(.t.)
/* EOF LiefNr_nach */


/* nach Versand-KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
FUNCTION V_A_KdNr_nach(oGet)
LOCAL spedits

  if oGet:changed
    REPLACE ANGAUS->V_Name WITH KUNDEN->Name2
    REPLACE ANGAUS->V_Partner WITH KUNDEN->Partner2
    REPLACE ANGAUS->V_Strasse WITH KUNDEN->Strasse2
    REPLACE ANGAUS->V_Zusatz WITH KUNDEN->Zusatz2
    REPLACE ANGAUS->V_Plz WITH KUNDEN->PLZ2
    REPLACE ANGAUS->V_Land WITH KUNDEN->Land2
    REPLACE ANGAUS->V_Ort WITH KUNDEN->Ort2

    if trim(ANGAUS->V_Land) $ getProperty("Miki.phoenix.fracht.automatisch","")
      REPLACE ANGAUS->PhoenixFr with "J"
    else
      REPLACE ANGAUS->PhoenixFr with "N"
    endif

    spedits:=getKundSpedits( KUNDEN->KundNr )
    if len(spedits) == 1 // ansonsten muss der Benutzer manuell ausw�hlen!
      REPLACE ANGAUS->SpedNr WITH spedits[1]
    else
      REPLACE ANGAUS->SpedNr WITH ""
    endif

    REPLACE ANGAUS->V_Sprache WITH KUNDEN->Sprache2

    // VA ebenfalls nach Lieferanschrift (5.5.15)
    REPLACE ANGAUS->VersNr WITH KUNDEN->VersNr

    setzeMwstEgKZ("Angaus")

    // pr�fe ob Werkzeug und andere Artikel gemischt, bei ausl�nd. Kunden nicht zul�ssig
    // nur Hinweis!!!
    checkWerkzeug(.t.)

    // Sammelstelle
    REPLACE ANGAUS->S_Name WITH KUNDEN->S_Name
    REPLACE ANGAUS->S_Partner WITH KUNDEN->S_Partner
    REPLACE ANGAUS->S_Strasse WITH KUNDEN->S_Strasse
    REPLACE ANGAUS->S_Zusatz WITH KUNDEN->S_Zusatz
    REPLACE ANGAUS->S_Plz WITH KUNDEN->S_PLZ
    REPLACE ANGAUS->S_Land WITH KUNDEN->S_Land
    REPLACE ANGAUS->S_Ort WITH KUNDEN->S_Ort

    Ang_kopf_disp()

    selLandBySprache(ANGAUS->Sprache)

    ANGAUS->(dbcommit())
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif
RETURN(.t.)
/* EOF V_A_KdNr_Nach */

/* 
* gibt den AuftragsKopf auf den BS aus
*/
FUNCTION Ang_Kopf_Disp
LOCAL ob:=1
  // ** Kopf-Display
  @ ob+1,1 say 'Angebot Nr.:'
  @ ob+3,1 say 'Datum......:'

  @ ob+5,1 say "Vers.-  Art:"
  @ ob+5,18 say left(VERSART->Text,11)
  @ ob+6,1 say "Spedition..:"

  SPEDIT->(dbseek(ANGAUS->SpedNr))
  @ ob+6,18 say SPEDIT->Name

  @ ob+8,1 say "Lieferschein-Nr.:"
  @ ob+10,1 say "Best.Datum......:"
  @ ob+12,1 say "Best.Nr. Anfrage:"

  @ ob+1,27 say "Angebots-Anschr:"
  @ ob+2,27 say 'Kd.Nr:'
  @ ob+1,49 say ANGAUS->Name
  @ ob+2,49 say ANGAUS->Ort

  @ ob+3,27 say "Versand-Anschr:"
  @ ob+4,27 say 'Kd.Nr:'

  @ ob+8,40 say 'Sprache:'
  if ! empty(ANGAUS->Sprache) .and. ANGAUS->Sprache<>DEUTSCH
    @ ob+8,52 say "Englisch"
  else
    @ ob+8,52 say "Deutsch "
  endif

  if ! empty(ANGAUS->S_Name)
    @ ob+5,27 say "->Sammelstelle"
  else
    @ ob+5,27 say space(14)
  endif

  @ ob+3,49 say ANGAUS->V_Name
  @ ob+4,49 say ANGAUS->V_Partner
  @ ob+5,49 say ANGAUS->V_Strasse
  @ ob+6,49 say ANGAUS->V_Land
  @ ob+6,53 say ANGAUS->V_PLZ
  @ ob+6,59 say ANGAUS->V_Ort

  // @ ob+7,27 say "Rechnungs-Anschr:"
  // @ ob+8,27 say 'Kd.Nr:'
  // @ ob+7,47 say ANGAUS->R_Name
  // @ ob+8,47 say ANGAUS->R_Partner
  // @ ob+9,47 say ANGAUS->R_Strasse
  // @ ob+10,47 say ANGAUS->R_Land
  // @ ob+10,51 say ANGAUS->R_PLZ
  // @ ob+10,47 say ANGAUS->R_Ort

  // setColor(COLERR)
  // @ ob+10,27 say 'Euro'
  // setColor(COLNOR)
  @ ob+10,66 say "MWST:"
  @ ob+10,72 say alltrim(str(ANGAUS->MWSt,5,2)+"%")+" "
  @ ob+11,27 to ob+11,78

  if ANGAUS->Rabatt_KZ="H"
    @ ob+12,27 say "H�nd.Rab. :"
  else
    @ ob+12,27 say "Sond.Rab. :"
  endif
  @ ob+12,45 say "Energiekosten-Zuschlag:"

  @ ob+13,27 say "Zahl.Kond.:"
  ZAHLKOND->(dbseek(ANGAUS->ZkNr))
  @ ob+13,45 say ZAHLKOND->Text
  @ ob+14,45 say ZAHLKOND->Text2

  @ ob+15,27 say "G�ltigkeit:"

  @ ob+16,27 say "Text-KZ:"
  TEXT_KZ->(dbseek(ANGAUS->TEXTKZ_NR))
  @ ob+16,45 say TEXT_KZ->Text1
  @ ob+17,45 say TEXT_KZ->Text2
  @ ob+18,45 say TEXT_KZ->Text3
  @ ob+19,45 say TEXT_KZ->Text4
  // @ ob+19,45 say TEXT_KZ->Text5
  // @ ob+20,45 say TEXT_KZ->Text6

  @ ob+20,27 to ob+20,78

  @ ob+21,27 say "Zoll-Zuschlag:"
  @ ob+21,48 say "Ph�nix Fracht automatisch:"

RETURN(.t.)
/* EOF */

/** nach EIngabe der Sprache */
static function nachSprache( oGet )

  if ! oGet:buffer $ DEUTSCH+ENGLISCH
    return .f.
  endif

  selLandBySprache( oGet:buffer )

  replace ANGAUS->Gueltig with getTranslation("angebot.gueltig", LAND->Sprache)
  REPLACE ANGAUS->Sprache WITH oGet:buffer
  REPLACE ANGAUS->V_Sprache WITH oGet:buffer

  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  Ang_kopf_disp()

  // falls mit zru�ck aus Editor gekommen, diesen beenden, um Sprach-Wechsel zu erzwingen
  // if oldValue<>ANGAUS->Sprache .and. inStackTrace("Edit")
  // HB_KeyPut(K_PGDN)
  // HB_KeyPut(EDIT_QUIT)
  // endif

return .t.
/** eof */

/* Function Ang_Bauch  ****************************************
*
* Eingabe des Ang.Bauches, Editor-definitionen
*
* R�ckgabe:     .t. falls �nderungen gemacht wurden
*/


FUNCTION Ang_Bauch()
LOCAL aFelder,result,starteBeiRecno
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  set key K_F5 to toggleSprache()
  set key K_F11 to zeigeMatText()
  do while ! ABBRUCH .or. starteBeiRecno==NIL
    aFelder:={}

    select Auftrag

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_NEW_FKT]:={ || Ang_Satz_nach() }
    aKopf[EDIT_ERSATZ_ARRAY]:={ || Ang_Text()}
    aKopf[EDIT_KOPF_FKT]:={ || zurueckKopf() } // wird im Doppelmodus bei Eingabe

    aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("ANGAUS","AUFTRAG->Menge",41) .and. ;
      checkePhoenixVPE(aKopf,aFelder,"ANGAUS") .and. SetMyKey( asc("r") , NIL)}

    aKopf[EDIT_AFTER_MODE_CHANGE]:={ || pruefeZuschlaege("Angaus") }

    aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
    aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen
    aKopf[EDIT_ZEIGE_ANZAHL]:={ || len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE } // z�hle alle Artikel

    if valtype(starteBeiRecno)=="N"
      aKopf[EDIT_START_REC]:=starteBeiRecno
    endif


    // Text
    aKopf[EDIT_EXTRA_FKT]:={}
    aadd( aKopf[EDIT_EXTRA_FKT],{ "R"," @R@abatt-Tab.", { || zeigeRabattTabelle()}})
    aadd(aKopf[EDIT_EXTRA_FKT],{ "L","@L@�schen ", { || KonsistenzLoesch() } } )
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F5),"", { || Showfertdauer(10) } } )
    aadd( aKopf[EDIT_EXTRA_FKT] , { chr(K_CTRL_S)," @STRG-S@=Ersatzt.", { || addErsatzteile() } } )

    // von K ausgef�hrt
    /* Feld-Definitionen */
    // Artikel-Nr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe      @F4@=Honsel-Nr.       @ESC@=Ende"
    aSpalte[EDIT_ERSATZ_1]:={ || trim(AUFTRAG->ArtNr)$"*$" }

    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_AFTER]:={;
      |oGet| ( trim(oGet:Buffer)$"$*" .or. check(oGet,"Artikel",.f.)) .and. AngArtNrNach(oGet) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    if LAND->Sprache==DEUTSCH
      aadd( aKopf[EDIT_EXTRA_FKT] , { chr(K_F5)," @F5@=Englisch ", { || toggleSprache() } } )

      aSpalte[EDIT_NAME]:="Komm1"
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Text eingeben"

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="Komm2"
      aSpalte[EDIT_MESSAGE]:="Text eingeben"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    else
      aadd( aKopf[EDIT_EXTRA_FKT] , { chr(K_F5)," @F5@=Deutsch", { || toggleSprache() } } )

      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm1,E_Komm1)"
      aSpalte[EDIT_NAME_GET]:="E_Komm1"
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG-> E_Komm1),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyGTextPosten()})}
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm2,E_Komm2)"
      aSpalte[EDIT_NAME_GET]:="E_Komm2"
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG->E_Komm2),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyGTextPosten()})}
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif
    aadd( aKopf[EDIT_EXTRA_FKT] , { chr(K_F11)," @F11@=Texte", { || zeigeMatText() } } )

    // Menge
    aSpalte[EDIT_NAME]:="Menge"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MASKE]:="9999999.99"
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_BEFORE]:={ || SetMyKey( asc("r") , { || zeigeRabattTabelle()} ) }
    aSpalte[EDIT_AFTER]:={ |oGet| Ang_Menge_nach(oGet,aFelder) .and. SetMyKey( asc("r") , NIL) }
    aSpalte[EDIT_MESSAGE]:="Menge eingeben.     @R@abatt-Tabelle anzeigen"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Mengeinheit
    aSpalte[EDIT_NAME]:="right(space(3)+trim(getTransField('EINHEIT->Text')),3)"
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_POS_X]:=7
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Preis
    aSpalte[EDIT_NAME]:="Preis"
    aSpalte[EDIT_TITEL]:="Preis"
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_BEFORE]:={ || SetMyKey( asc("r") , { || zeigeRabattTabelle()} ) }
    aSpalte[EDIT_AFTER]:={ |oGet| angpreisNach(oGet) .and. SetMyKey( asc("r") , NIL) }
    aSpalte[EDIT_MESSAGE]:="Preis in @Euro@ eingeben.       @R@abatt-Tabelle anzeigen"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    // Rabatt
    aSpalte[EDIT_NAME]:="Rabatt"
    aSpalte[EDIT_TITEL]:="Rabatt"
    aSpalte[EDIT_POS_X]:=3 // um 3 nach rechts verschoben
    aSpalte[EDIT_MESSAGE]:="Rabatt eingeben.       @R@abatt-Tabelle anzeigen"
    aSpalte[EDIT_BEFORE]:={ || SetMyKey( asc("r") , { || zeigeRabattTabelle()} ) }
    aSpalte[EDIT_AFTER]:={;
      |oGet| val(oGet:buffer)>=0 .and. rabatt_nach(oGet) .and. SetMyKey( asc("r") , NIL) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Rabatt-Gruppe
    aSpalte[EDIT_NAME]:="RabattGr"
    aSpalte[EDIT_POS_X]:=5 // um 3 nach rechts verschoben
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetMyKey( asc("r") , { || zeigeRabattTabelle()} ) }
    aSpalte[EDIT_AFTER]:={ |oGet| RabattGrNach(oGet,aFelder) .and. SetMyKey( asc("r") , NIL) }
    aSpalte[EDIT_MESSAGE]:="Rabatt-Gruppe  eingeben.    @R@abatt-Tabelle anzeigen   @F12@=Hilfe"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Kalenderwoche
    aSpalte[EDIT_NAME]:="Kw"
    aSpalte[EDIT_TITEL]:="Woche"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben.           @*@=Text"
    aSpalte[EDIT_AFTER]:={ |oGet| Ang_kw_nach(oGet) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Kalenderwoche
    aSpalte[EDIT_NAME]:="KW_Text"
    aSpalte[EDIT_TITEL]:="LieferText"
    aSpalte[EDIT_MESSAGE]:="Liefertext eingeben."
    aSpalte[EDIT_BEFORE]:={ || left(AUFTRAG->kw,1)=="*" }
    aSpalte[EDIT_POS_X]:=-40 // um 20 nach links verschoben
    aSpalte[EDIT_POS_Y]:=2 // 3. Zeile

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Mengeinheit
    aSpalte[EDIT_NAME]:="Me"
    aSpalte[EDIT_TITEL]:="ME"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Preiseinheit
    aSpalte[EDIT_NAME]:="Pe"
    aSpalte[EDIT_TITEL]:="PE"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Lagerbestand
    aSpalte[EDIT_TITEL]:="  Lg.Best."
    aSpalte[EDIT_NAME]:="getArtikelLageBest()"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    /**** ENDE Feld-Definitionen ***/

    result:=Edit(aFelder,aKopf)
    starteBeiRecno:=AUFTRAG->(recno())

  enddo
  set key K_F5 to
  set key K_F8 to
  set key K_F11 to
  SetMyKey( asc("r") , NIL)

RETURN( aKopf[EDIT_CHANGED] )
/* EOF Ang_Bauch */


/* Function Ang_Text ***************************
*
* alternativ Spaltendef. bei Text eingabe *
* Ersatz-Array
*/
FUNCTION Ang_Text
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={;
    |oGet| ( trim(oGet:Buffer)$"$*" .or. check(oGet,"Artikel",.f.)) .and. AngArtNrNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Info: Kommentare ohne englische �bersetzung, immer der deutsche

  // Text
  if LAND->Sprache==DEUTSCH
    aSpalte[EDIT_NAME]:="Komm1"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Deutscher Text eingeben"
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    aSpalte[EDIT_NAME]:="Komm2"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Deutscher Text eingeben"
    aSpalte[EDIT_POS_Y]:=2 // 3. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  else
    aSpalte[EDIT_NAME]:="E_Komm1"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    aSpalte[EDIT_NAME]:="E_Komm2"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"
    aSpalte[EDIT_POS_Y]:=2 // 3. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  endif

RETURN(aFelder)
/* EOF Ang_Text */


/* Function Ang_kw_nach
*
* wird nach Eingabe der Kalenderwoche ausgef�hrt
* evtl. Eingabe von LieferText
*/
FUNCTION Ang_kw_nach(oGet)
LOCAL GetList:={}
LOCAL Zeile:=row()+1
LOCAL woche:=left(oGet:buffer,2)
LOCAL jahr:=right(oGet:buffer,2)

  if left(oGet:buffer,1) $ "*"
    // Message("Liefertext eingeben.")
    // @ Zeile,45 get AUFTRAG->KW_Text
    // read
    // @ Zeile,45 say AUFTRAG->KW_Text
  else

    if ! kwEmpty( oGet:buffer )
      if (val(woche)<=0 .or. val(woche)>53 .or. 2000+val(jahr) < year(getUser():date) )
        if ! check(oGet,"LiefTerm",.f.,.f.)
          Error(ACHTUNG+"Ung�ltige Kalenderwoche.",.t.)
          return .f.
        endif
      endif
    endif

    replace AUFTRAG->Kw_Text with ""

  endif

RETURN(.t.)


/* Function AngArtNrNach
*
* wird nach Eingabe der ArtikelNummer ausgef�hrt
*/
static FUNCTION AngArtNrNach(oGet)
LOCAL paletten,land

  // keine Fracht-Verpackungsartikel manuell �ndernbar falls Ph�nix-Artikel
  if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. ! "*" $ AUFTRAG->ArtNr .and.;
    isPhoenixAuftrag()

    if ANGAUS->PhoenixFr <> "N"
      land=getProperty("Miki.phoenix.fracht.automatisch","")
      Error(ACHTUNG+"Fracht & Verpackung wird bei Ph�nix-Auftrag nach|"+;
        "         "+land+" automatisch berechnet.||"+;
        "         Zum �ndern bitte Kennzeichen in Kopfdaten auf N setzen")
      keyboard chr(K_ESC) // we bail out
      return(.f.)
    endif
  endif

  // pr�fe ob Zoll-Artikel
  if ANGAUS->ZollZuschl == "J" .and. isZollZuschlagArtikel( AUFTRAG->ArtNr )
    Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.||"+;
      "Zum �ndern bitte Zollzuschlag in Kopfdaten auf N setzen")
    return .f.
  endif

  if oGet:changed
    if trim(oGet:Buffer)$"$*"
      if ! trim(oGet:original)$"*"
        REPLACE AUFTRAG->komm1 WITH ""
        REPLACE AUFTRAG->komm2 WITH ""
        REPLACE AUFTRAG->E_komm1 WITH ""
        REPLACE AUFTRAG->E_komm2 WITH ""
      endif
    else
      replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
      replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
      replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
      replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2

      // Preis nur kopieren, falls keine Fracht oder Verpackun bzw. falls diese berechnet wird
      paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
      if len(alltrim(AUFTRAG->ArtNr)) >3 .or.;
        (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
        (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J") ;
        .and. ! ( ANGAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))) // neu 20160921
        replace AUFTRAG->Preis WITH ARTIKEL->Preis1
      else
        replace AUFTRAG->Preis WITH 0
      endif

      replace AUFTRAG->Me WITH ARTIKEL->ME
      replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
      replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
      replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
      select Erl_Grup
      seek AUFTRAG->Erl_Gruppe
      if .not. eof()
        DO CASE
        CASE ANGAUS->MWST_KZ="1"
          replace AUFTRAG->Erl_Konto WITH ERL_GRUP->Inland
          replace AUFTRAG->Erl_Kz WITH "In"
        CASE ANGAUS->EG=="J"
          replace AUFTRAG->Erl_Konto WITH ERL_GRUP->Eg
          replace AUFTRAG->Erl_Kz WITH "EG"
        OTHERWISE
          if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
            replace AUFTRAG->Erl_Konto WITH ERL_GRUP->Sonst
            replace AUFTRAG->Erl_Kz WITH "So"
          endif
        ENDCASE
      endif
      SELECT Auftrag
    endif

    // pr�fe ob Werkzeug und andere Artikel gemischt, bei ausl�nd. Kunden nicht zul�ssig
    if ! checkWerkzeug(.f.)
      return .f.
    endif

    dispEditorSumme("ANGAUS","AUFTRAG->Menge",41)
  endif
RETURN(.t.)
/* EOF Ang_Nach */

/* Function Ang_Satz_nach()
*
* wird nach hinzuf�gen eines neuen Satzes ausgef�hrt
*/
FUNCTION Ang_Satz_nach
  replace AUFTRAG->KundNr with ANGAUS->KundNr
  replace AUFTRAG->AufDat with ANGAUS->AufDat
RETURN(.t.)

/** Pr�ft ob bei ausl�nd. Kunden Werkzeug und andere Artikel gemeinsam angeboten werden */
static FUNCTION checkWerkzeug(alle)
LOCAL aktRec:=recno(),aktSel:=alias()
LOCAL okay:=.t. // we're optimistic

  // kein Problem bei deutschen Kunden oder neuen Angeboten
  if upper(ANGAUS->EG) == "D" .or. AUFTRAG->(reccount()) == 0
    return .t.
  endif

  if alle // alle Datens�tze pr�fen
    select Auftrag
    loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()=="W"
    if ! AUFTRAG->(eof())
      loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()<>"W"
      okay:=AUFTRAG->(eof())
    endif
    select (aktSel)
  else
    // nur aktuellen Datensatz pr�fen

    // bei Werkzeug und EG Kunden -> Mwst berechnen / pr�fen
    IF len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE
      // Werkzeug eingegeben
      if getArtikelArt()=="W"
        // suche nicht Werkzeuge in Auftrag.dbf (!)
        loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()<>"W"
        if AUFTRAG->(eof())
          // alles okay, setze Mwst
          if ANGAUS->MwSt_KZ=="0"
            // bei Werkzeuglieferung an EU Kunden, Mehrwertsteuer berechnen
            replace ANGAUS->Mwst_KZ with "1"
            MWST_KZ->(dbseek("1"))
            REPLACE ANGAUS->MwSt WITH MWST_KZ->MwSt
          endif
        else
          okay:=.f.
        endif
        go (aktRec)

      else // getArtikelArt()<>"W"
        // Nicht-Werkzeug eingegeben
        // suche nicht Werkzeuge in Auftrag.dbf (!)
        loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()=="W"
        if AUFTRAG->(eof())
          if ANGAUS->MwSt_KZ=="1"
            // bei Nicht-Werkzeuglieferung an ausl�nd. Kunden, keine Mehrwertsteuer berechnen
            replace ANGAUS->Mwst_KZ with "0"
            MWST_KZ->(dbseek("0"))
            REPLACE ANGAUS->MwSt WITH MWST_KZ->MwSt
          endif
        else
          okay:=.f.
        endif
      endif
    endif
  endif
  go (aktRec)

  if ! okay
    Error("Hinweis: Mehrwertsteuer bei Werkzeugen und andere Artikeln|"+;
      "         k�nnen bei ausl�nd. Kunden abweichen.")
  endif

  //return okay
return .t. // seit 31.3.17 trotzdem erlaubt (nur Angebot)
/** eof */


/*
*
* wird nach Eingabe des Rabatts ausgef�hrt
*/
static FUNCTION RabattGrNach(oGet,aFelder)
LOCAL aSpalte

  if ! check(oGet,"Rabatt")
    return .f.
  endif

  if (oGet:changed())
    oGet:assign()
    assignRabatt()

    aSpalte:=aFelder[getColPosByName(aFelder,"RabattGr")]
    aSpalte[EDIT_BS_AUSGABE]:=.t.
  endif

return .t.
/** eof */


/** kopiert f�r den aktuellen Artikel & Menge den passenden Rabatt */
static procedure assignRabatt()
LOCAL x:=getMengenRabattStaffel(AUFTRAG->RabattGr,AUFTRAG->Menge)
LOCAL feldRab,feldPreis

  if x<=0
    // keine Rabattstaffel
    // Info: Preis wird in diesem Fall nicht mehr �berschrieben, s. Fragen 25.10.2013
    // kann evtl. der falsche/alte Preis einer vorherigen Rabatttabelle sein.
    if AUFTRAG->Preis == 0
      REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
    endif
    REPLACE AUFTRAG->Rabatt WITH 0

  else // Rabatt-Tabelle

    // Rabatt absolut -> Preis
    feldPreis="RABATT->Preis"+str(x,1)
    if &(feldPreis)>0
      REPLACE AUFTRAG->Preis WITH &(feldPreis)
      REPLACE AUFTRAG->Rabatt WITH 0
    else // Rabatt in %
      feldRab ="RABATT->Rab"+str(x,1)
      if alltrim(AUFTRAG->ArtNr) <> ANGEBOTS_ARTIKEL
        REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
      endif
      REPLACE AUFTRAG->Rabatt WITH &(feldRab)
    endif
  endif
return
/** eop */

/* Function Ang_Menge_nach
*
* wird nach Eingabe der Menge ausgef�hrt
*/
FUNCTION Ang_Menge_nach(oGet,aFelder)
LOCAL aktRec,merkMenge,merkArtNr,aSpalte
LOCAL s01,ant

  if oGet:changed .and. len(alltrim(AUFTRAG->ArtNr)) >3 .or.;
    (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
    (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J")

    assignRabatt()

    // pr�fe MindestBestellMenge
    aSpalte:=aFelder[getColPosByName(aFelder,"Menge")]
    aSpalte[EDIT_BS_AUSGABE]:=.f.
    merkArtNr:=AUFTRAG->ArtNr
    aktRec:=recno()

    if oGet:VarGet()>0 .and. oGet:VarGet() < ARTIKEL->MinOrderI
      s01:=savescreen()
      Error(ACHTUNG+" Artikel: "+ARTIKEL->ArtNr+" Mind.Bestellung: "+;
        str(ARTIKEL->MinOrderI,9,2),.f.)
      ant:=Message("@I@gnorieren, @A@nzeigen oder @B@erechnen?","IAB"," ")
      if ABBRUCH
        restscreen(,,,,s01)
        return .f.
      endif

      // l�sche evtl. vorherige Mindermengenzuschl�ge
      dele for (alltrim(AUFTRAG->ArtNr)=="*" .or. alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL) .and. ;
        trim(AUFTRAG->tempStr)==merkArtNr + str(oGet:original,10,2)
      go (aktRec)
      // BS ausgeben
      aSpalte[EDIT_BS_AUSGABE]:=.t.

      switch ant
      case "A"
        merkMenge:=oGet:VarGet()

        insertBlank(.f.)
        Ang_Satz_nach()
        ARTIKEL->(dbseek(merkArtNr))
        replace AUFTRAG->ArtNr with "*"
        replace AUFTRAG->KOMM1 with space(TAB_SPACES)+getTranslation("angebot.min.menge",DEUTSCH)+;
          " "+alltrim(str(ARTIKEL->MinOrderI))
        replace AUFTRAG->KOMM2 with space(TAB_SPACES)+getTranslation("angebot.min.zuschlag",DEUTSCH)+;
          " "+alltrim(str((ARTIKEL->MinOrderI)*ARTIKEL->Preis1,12,2))
        replace AUFTRAG->E_KOMM1 with space(TAB_SPACES)+getTranslation("angebot.min.menge",ENGLISCH)+;
          " "+alltrim(str(ARTIKEL->MinOrderI))
        replace AUFTRAG->E_KOMM2 with space(TAB_SPACES)+getTranslation("angebot.min.zuschlag",ENGLISCH)+;
          " "+alltrim(str((ARTIKEL->MinOrderI)*ARTIKEL->Preis1,12,2))
        // merke zugeh. Art.Nr. & Menge f�r sp�tere �nderungen
        replace AUFTRAG->TempStr with merkArtNr+str(merkMenge,10,2)
        go (aktRec)

        exit
      case "B"
        merkMenge:=oGet:VarGet()

        insertBlank(.f.)
        Ang_Satz_nach()
        ARTIKEL->(dbseek(merkArtNr))
        replace AUFTRAG->ArtNr with ShiftArtikel(ANGEBOTS_ARTIKEL)
        replace AUFTRAG->KOMM1 with getTranslation("angebot.min.menge",DEUTSCH)+;
          " "+alltrim(str(ARTIKEL->MinOrderI))
        replace AUFTRAG->KOMM2 with getTranslation("angebot.min.zuschlag",DEUTSCH)+;
          " "+alltrim(str((ARTIKEL->MinOrderI)*ARTIKEL->Preis1,12,2))
        replace AUFTRAG->E_KOMM1 with getTranslation("angebot.min.menge",ENGLISCH)+;
          " "+alltrim(str(ARTIKEL->MinOrderI))
        replace AUFTRAG->E_KOMM2 with getTranslation("angebot.min.zuschlag",ENGLISCH)+;
          " "+alltrim(str((ARTIKEL->MinOrderI)*ARTIKEL->Preis1,12,2))
        // merke zugeh. Art.Nr. & Menge f�r sp�tere �nderungen
        replace AUFTRAG->TempStr with merkArtNr+str(merkMenge,10,2)
        replace AUFTRAG->MENGE with 1
        replace AUFTRAG->PREIS with (ARTIKEL->MinOrderI-merkMenge)*ARTIKEL->Preis1
        go (aktRec)

        exit
      otherwise
        if getUser():id<>KURZEL_MIKI_GF
          email(MAIN_EMAIL,;
            "Angebot ohne Hinweis zur Mindest-Menge",;
            "Angebot :"+ANGAUS->AngNr+"|"+;
            "Kunde...:"+ANGAUS->KundNr+ANGAUS->KurzName+"|"+;
            "Benutzer:"+getUser():id+"||"+;
            ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"|"+;
            "Menge...............:"+str(oGet:VarGet())+"|"+;
            "Mindest-Bestellmenge:"+str(ARTIKEL->MinOrderI)+"||"+;
            "Bitte pr�fen")
        endif
      endswitch
      restscreen(,,,,s01)
    else
      // l�sche evtl. vorherige Mindermengenzuschl�ge
      loca for (alltrim(AUFTRAG->ArtNr)=="*" .or. alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL) .and. ;
        trim(AUFTRAG->tempStr)==merkArtNr + str(oGet:original,10,2)
      do while ! AUFTRAG->(eof())
        delete
        cont
        // BS ausgeben
        aSpalte[EDIT_BS_AUSGABE]:=.t.
      enddo
      go (aktRec)
    endif

    dispEditorSumme("ANGAUS","AUFTRAG->Menge",41)
  endif
RETURN(.t.)
/* EOF Ang_Menge_Nach() */

/** wird nach Eingabe des Preises ausgef�hrt */
static function angpreisNach(oGet)
LOCAL s01

  // Hinweis, falls bei Fracht/Verpackung der Preis ge�ndert wurde,
  // obwohl dieser normalerweise nicht berechnet wird
  if oGet:changed .and. val(oGet:buffer) <> 0
    if (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="N" )
      s01:=savescreen()
      Error(ACHTUNG+"Verpackung wird bei diesem Kunde normalerweise nicht berechnet.",.f.)
      if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J" .or. ABBRUCH
        oGet:varput(0)
        oGet:updateBuffer()
      endif
      restscreen(,,,,s01)
    elseif (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "N") .or. ABBRUCH
      s01:=savescreen()
      Error(ACHTUNG+"Fracht wird bei diesem Kunde normalerweise nicht berechnet.",.f.)
      if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J"
        oGet:varput(0)
        oGet:updateBuffer()
      endif
      restscreen(,,,,s01)
    endif
  endif

return .t.
/** eof */



/* Procedure Angebot   ******************************************
*
* druckt Posten aus Auftrag.dbf !  (alt)
*
* Parameter Ausgabe wohin
*/
PROCEDURE Angebot(Ausgabe)
LOCAL summerab:=0.00 , nk:=0 , konto:="", EinhNr:=""
LOCAL gwert:=0.00
LOCAL div:=1,wert:=0,rab:=0,mwwert:=0.00,mw:=0.00
LOCAL Seite:=0,zeile:=0,kom,i,ende,line
LOCAL Laenge,MerkRabgr:="",Rabatt_mehrf:=.f.,MerkMindMenge:=-1
LOCAL waehrung, preiskom
LOCAL postenPreis,Anzahl,adresse,Adresse2
LOCAL tempBefr:={}, tempText:=nil
LOCAL gbsBefrDruck:=.f., nr
LOCAL bLastHandler, sonder:=.f.
LOCAL pdfInfo, paletten, frachtKosten:=0
LOCAL excel,objErr

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(ANGAUS->Sprache)

  pdfInfo:=pdfInfo():new( JOB_ANGEBOT , ANGAUS->AngNr , .t. )

  select Auftrag
  go top

  do case
  case Ausgabe=="D"
    Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  case Ausgabe=="P"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
  case Ausgabe=="NOP"
    Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
  case Ausgabe=="B"
    Drucker("BS")
  case Ausgabe=="E"
    BEGIN SEQUENCE // krit. Bereich
      excel:=ExcelExport():new()
      if LAND->Sprache=="D"
        excel:addColumnsByName({;
          { "out2(ArtNr)", "Artikel-Nr."},;
          {"Komm1", "Bezeichung"},;
          {"Komm2", "Bezeichung 2"},;
          "Menge",;
          {"Preis/IIF(PE$'Hh',100,1)","Preis"},;
          "Rabatt",;
          "KW",;
          {"EINHEIT->Text","Einheit"}})
      else
        excel:addColumnsByName({;
          { "out2(ArtNr)", "Article-No."},;
          {"E_Komm1", "Description"},;
          {"E_Komm2", "Description 2"},;
          {"Menge","Amount"},;
          {"Preis/IIF(PE$'Hh',100,1)","Price"},;
          {"Rabatt","Discount"},;
          {"KW","Week"},;
          {"EINHEI{"EINHEIT->E_Text","Unit"}})
      endif

      // set decimals on price
      excel:getColumnByName("Preis/IIF(PE$'Hh',100,1)"):numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT

      excel:export()
      excel:=NIL
    RECOVER USING objErr
      Error(getErrorDispText(objErr))
    END SEQUENCE
    return
  endcase

  Laenge:=DRUCKER->Laenge
  SPEDIT->(dbseek(ANGAUS->SpedNr))

  // pr�fe ob unterschiedl. Rabattgruppen angegeben sind
  do while ! AUFTRAG->(eof())
    /** merke RabattGruppe */
    if ! empty(AUFTRAG->RabattGr)
      if AUFTRAG->RabattGr<>SONDER_RABATT
        nr:=AUFTRAG->RabattGr
      else
        nr:=ARTIKEL->RabattGr
      endif
      if ! empty(MerkRabGr) .and. ( MerkRabGr <> nr .or. MerkMindMenge <> ARTIKEL->MinOrderI )
        Rabatt_mehrf:=.t.
        exit
      endif
      MerkRabGr:=nr
      MerkMindMenge:=ARTIKEL->MinOrderI
    endif
    skip
  enddo

  go top
  Ende:=AUFTRAG->(eof())
  do while .not. Ende
    Seite = Seite + 1
    zeile:=0
    FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

    adresse:=getAdrBlock(ANGAUS->Name,ANGAUS->Partner,ANGAUS->Strasse,ANGAUS->Zusatz, ANGAUS->Land;
      ,ANGAUS->Plz,ANGAUS->Ort)

    ? space(40),FETT_AN,if(LAND->Sprache<>"D",getTranslation("allgemein.angebot",DEUTSCH),""),;
      FETT_AUS
    ? space(40),BREIT_AN,;
      getTranslation("allgemein.angebot",LAND->Sprache),;
      getTranslation("allgemein.nummer",LAND->Sprache)+ANGAUS->AngNr,BREIT_AUS
    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2],space(23)
    ? space(4),Adresse[3],space(0),;
      KdOut(ANGAUS->KundNr),space(1),ANGAUS->Aufdat,space(2),getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5]
    ? space(4),Adresse[6],space(0),ANGAUS->LiefNr,ANGAUS->bestdat
    ?
    ? space(44),ANGAUS->bestnr
    ?
    ? space(44),ANGAUS->bestkonto

    if empty(ANGAUS->S_Name)
      adresse:=getAdrBlock(ANGAUS->V_Name,ANGAUS->V_Partner,ANGAUS->V_Strasse,ANGAUS->V_Zusatz,;
        ANGAUS->V_Land,ANGAUS->V_Plz,ANGAUS->V_Ort)
      ? space(4),Adresse[1]
      ? space(4),Adresse[2],space(0)
      if len(trim(ANGAUS->gueltig))>32
        ?? SCHMAL_AN,ANGAUS->gueltig,SCHMAL_AUS
      else
        ?? trim(ANGAUS->gueltig)
      endif
      ? space(4),Adresse[3]
      ? space(4),Adresse[4],space(0),;
        if(!empty(VERSART->Text).or.;
        !empty(SPEDIT->Name), getTranslation("allgemein.versand",LAND->Sprache),"")
      ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
      ? space(4),Adresse[6],space(0),getTransField("SPEDIT->Name")
    else
      adresse:=getAdrBlock(ANGAUS->S_Name,ANGAUS->S_Partner,ANGAUS->S_Strasse,ANGAUS->S_Zusatz,;
        ANGAUS->S_Land,ANGAUS->S_Plz,ANGAUS->S_Ort)
      adresse2:=getAdrBlock(ANGAUS->V_Name,ANGAUS->V_Partner,ANGAUS->V_Strasse,ANGAUS->V_Zusatz,;
        ANGAUS->V_Land,ANGAUS->V_Plz,ANGAUS->V_Ort)
      ? KLEIN_AN,Adresse[1],Adresse2[1],KLEIN_AUS
      ? KLEIN_AN,Adresse[2],Adresse2[2],KLEIN_AUS,space(0),;
        getTranslation("angebot.gueltig",LAND->Sprache)
      ? KLEIN_AN,Adresse[3],Adresse2[3],KLEIN_AUS
      ? KLEIN_AN,Adresse[4],Adresse2[4],KLEIN_AUS,space(0),;
        if(!empty(VERSART->Text).or.;
        !empty(SPEDIT->Name),getTranslation("allgemein.versand",LAND->Sprache),"")
      ? KLEIN_AN,Adresse[5],Adresse2[5],KLEIN_AUS,space(0),getTransField("VERSART->Text")
      ? KLEIN_AN,Adresse[6],Adresse2[6],KLEIN_AUS,space(0),getTransField("SPEDIT->Name")
    endif
    ?
    // ? space(EURO_LEFT),FETT_AN,"EURO",FETT_AUS
    ?
    ?

    /* Posten drucken */
    SELECT Auftrag
    do while Zeile<laenge-UNT_RAND-2 .and. .not.AUFTRAG->(eof())
      postenPreis:=AUFTRAG->Preis
      wert:=0
      do case
        /** Kommentar */
      case substr(AUFTRAG->ArtNr,1,1) $ "$*"
        if ! (Zeile < laenge - UNT_RAND - Kommentar(.f.) )
          exit
        endif
        zeile += Kommentar()
        if ! AUFTRAG->(eof())
          ? // Leerzeile vor n�chstem Artikel
        endif

        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(AUFTRAG->ArtNr))<=FRACHT_LAENGE


        // Fracht mit KW? dann pr�fe Zeilen-Umbruch
        if ! KWempty(AUFTRAG->KW) .and. Zeile>=laenge-UNT_RAND-2
          exit
        endif

        // Zoll-Artikel mit Preis = 0 nicht ausdrucken
        if AUFTRAG->Preis == 0 .and. isZollZuschlagArtikel( AUFTRAG->ArtNr )
          skip
          loop
        endif

        // Sonderfall bei Angebot, drucke Zuschlag & Rabatt am Ende nach Fracht & Verpackung
        // if ! sonder
        // zeile += drucke_rabatt_zuschlag("ANGAUS", @gwert, frachtkosten)
        // sonder:=.t.
        // endif

        div=IIF(AUFTRAG->PE$"Hh",100,1)
        wert=ROUND(postenPreis*AUFTRAG->menge/div,2)
        ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,left(getTransField("AUFTRAG->komm1"),30),;
          getMengePreis(AUFTRAG->menge,postenPreis),AUFTRAG->pe,if(wert==0,"",transStr(wert,12,2))
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,left(getTransField("AUFTRAG->kom"+;
            "m2"),30)
        endif

        paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
        // Sonder Text bei EU-Palette und Gitterbox falls Preis 0, dann nur im Tausch
        if AUFTRAG->Preis == 0 .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            getTranslation("allgemein.palette.kostenfrei",LAND->Sprache)
        endif

        IF AUFTRAG->rabatt<>0.0
          ?;
            space(11)+;
            if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.sonder",LAND->Sprache,44), getTranslation("allgemein.rabatt.menge",LAND->Sprache,44)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(abs(wert)*AUFTRAG->Rabatt/100,11,2)
          wert=wert-ROUND(wert*AUFTRAG->rabatt/100,2)
          // else // 2023013: raus, wieso hier extra Leerzeil?
          // ?
        endif

        frachtKosten += wert

        /** Liefertermin */
        if ! KWempty(AUFTRAG->KW)
          ?
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
          getUser():getCurrentPrintJob():print( Lief_Term(AUFTRAG->KW) , .f.)
        endif

        /** "normale" Artikel */
      otherwise

        // *** neu seit 14.6.2011, z�hle Anzahl Zusatzzeilen f�r Seitenumbruch vorab
        anzahl:=2
        /** ueberpruefe Mat.Kz */
        anzahl += zaehle_MatKz_Text(AUFTRAG->ArtNr)
        /** ueberpruefe Artikel Text */
        anzahl += zaehle_Artikel_Text(AUFTRAG->ArtNr)

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          anzahl++
        endif

        /** Rabatt-Tabelle */
        if ! empty(AUFTRAG->RabattGr) .and. Rabatt_mehrf
          kom:=Rabatt_Tab(AUFTRAG->RabattGr,,ARTIKEL->minOrderI)
          aeval( kom , { |x| if(empty(x),nil,anzahl++) })
        endif

        /** Liefertermin */
        if ! KWempty(AUFTRAG->KW)
          anzahl+=2
        endif
        if Zeile+anzahl>laenge-UNT_RAND
          exit
        endif
        // ********** ende neu

        div=IIF(AUFTRAG->PE$"Hh",100,1)
        wert=ROUND(postenPreis*AUFTRAG->menge/div,2)
        if len(alltrim(AUFTRAG->ArtNr)) < ARTNR_LAENGE
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(AUFTRAG->ArtNr),SCHMAL_AUS
        endif
        ?? left(getTransField("AUFTRAG->komm1"),30)

        if ! (len(alltrim(AUFTRAG->ArtNr)) < ARTNR_LAENGE .and. AUFTRAG->menge == 0)
          ?? getMengePreis(AUFTRAG->menge,postenPreis),AUFTRAG->pe
          if AUFTRAG->Menge==1 .and. ! empty(AUFTRAG->RabattGr)
            ?? space(1),getTranslation("angebot.grundpreis",LAND->Sprache)
          else
            ?? transstr(wert,12,2)
          endif
        endif
        if ! empty(getTransField("AUFTRAG->komm2"))
          ? WINZIG_AN,HonselNrWinzig(LAND->Sprache),WINZIG_AUS,;
            left(getTransField("AUFTRAG->komm2",LAND->Sprache),30)
        else
          if ! empty(ARTIKEL->Hartnr)
            ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS
          endif
        endif

        /** merke EinheitNr */
        if empty(EinhNr)
          EinhNr:=AUFTRAG->Me
        endif

        /** ueberpruefe Mat.Kz */
        zeile += drucke_MatKz_Text(AUFTRAG->ArtNr)

        /** ueberpruefe Artikel Text */
        zeile += drucke_Artikel_Text(AUFTRAG->ArtNr)

        /** Mengenrabatt */
        IF AUFTRAG->rabatt<>0.0
          ?;
            space(11)+;
            if(AUFTRAG->RabattGr==SONDER_RABATT, getTranslation("allgemein.rabatt.sonder",LAND->Sprache,44), getTranslation("allgemein.rabatt.menge",LAND->Sprache,44)), transStr(AUFTRAG->rabatt,5,2)+"% -",transStr(abs(wert)*AUFTRAG->Rabatt/100,11,2)
          wert=wert-ROUND(wert*ROUND(AUFTRAG->rabatt,2)/100,2)
        endif

        // drucke Gewicht falls bei Artikel hinterlegt
        if ARTIKEL->Gewicht > 0
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,;
            getTranslation("angebot.gewicht.stk",LAND->Sprache),getTransField("EINHEIT->Text")+":"
          ?? ARTIKEL->Gewicht,"kg"
        endif

        // drucke WarenIdentNummer & Ursprungsland
        if len(alltrim(AUFTRAG->ArtNr)) >= ARTNR_LAENGE
          zeile += printWarenIdentNummer("AngAus")
        endif

        /** Liefertermin */
        if ! KWempty(AUFTRAG->KW)
          ?
          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS
          getUser():getCurrentPrintJob():print( Lief_Term(AUFTRAG->KW) , .f.)
        endif

        /** drucke RabattGruppe je Posten? */
        if ! empty(AUFTRAG->RabattGr) .and. Rabatt_mehrf
          kom:=Rabatt_Tab(AUFTRAG->RabattGr,,ARTIKEL->minOrderI)
          ?
          for each line in kom
            if ! empty(line)
              ? line
            endif
          next
        endif

      endcase

      gwert=gwert+wert
      skip
      /** Leerzeile zwischen 2 Artikeln */
      if ! substr(AUFTRAG->ArtNr,1,1)$'$*' .and. .not.AUFTRAG->(eof())
        // keine Leerzeile bei 2 aufeinanderfolg. Komm.
        ?
      endif
    enddo
    /** Ende Auftrags-Posten */

    // Berechne Gr��e GelangensBescheinigung Hinweise
    do case
    case upper(ANGAUS->EG)=="D"
      // NOP
    case upper(ANGAUS->EG)=="J"
      if ANGAUS->MwSt_KZ=="0"
        tempText:=getTranslation("AB.gelang.befreiung",LAND->Sprache)
      else
        tempText:=getTranslation("AB.gelang.erstattung.eu",LAND->Sprache)
      endif
    otherwise
      if ANGAUS->MwSt_KZ=="1"
        tempText:=getTranslation("AB.gelang.erstattung.sonst",LAND->Sprache)
      endif
    endcase

    if tempText <> NIL
      MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
      tempText:=strtran(tempText,"$MWST",transstr(MWST_KZ->Mwst,5,2)+"% = @"+;
        alltrim(transstr(round(MWST_KZ->mwst*ANGAUS->Netto/100,2),11,2))+" Euro@")
      tempBefr:=linewrap(tempText,COLUMN_WRAP)
    endif

    if AUFTRAG->(eof()) .and. ! sonder
      zeile += drucke_rabatt_zuschlag("ANGAUS", @gwert, frachtkosten, .t.)
      sonder:=.t.
    endif

    /** Seitenumbruch ? */
    if empty(EinhNr)
      einhNr:=STANDARD_ME
    endif
    if ! AUFTRAG->(eof()) .or. ;
      (zeile > Laenge - UNT_RAND -14 -;
      LieferTerminKopf(EinhNr,"AngAus",.t.)-;
      if(empty(ANGAUS->TextKz_Nr),0,6)-;
      if(Rabatt_mehrf,0,1))

      do while Zeile<laenge-UNT_RAND-1
        ?
      enddo
      ? space(67),FETT_AN,getTranslation("allgemein.seite",LAND->Sprache),str(seite+1,2),FETT_AUS

      // GBS remove on Angebot 19.6.2012
      // // Platz f�r GBS Befreiungs text?
      // if ! gbsBefrDruck .and. len(tempBefr)>0 .and. zeile < Laenge - UNT_RAND-len(tempBefr)-1
      // zeile += printGBSBefreiung(tempBefr)
      // gbsBefrDruck:=.t.
      // endif

    else
      Ende:=.t.

      /* Liefertermine aus Auf.Kopf */
      zeile+=LieferTerminKopf(EinhNr,"AngAus")

      /** Waehrung */
      waehrung:="Euro"

      /** RAbatt-Tabelle */
      SELECT Auftrag
      if ! empty(ANGAUS->TextKz_Nr)
        kom:=Werbe_Text(ANGAUS->TextKz_Nr)
      else
        kom:=Werbe_Text("") // leer
      endif

      // Summe (optional)
      if ANGAUS->Summe == "J"
        ? space(42),"---------------------------------"
        mwwert=0.00
        if ANGAUS->mwst > 0.0
          ? space(42),getTranslation("allgemein.netto",LAND->Sprache,13),waehrung,;
            transStr(gwert,14,2)
          mw=transStr(ANGAUS->mwst,5,2)
          mwwert=ROUND( ANGAUS->mwst*gwert/100 ,2)
          ? space(42),mw+"% "+getTranslation("allgemein.mwst",LAND->Sprache,4)+": ",waehrung,;
            transStr(mwwert,14,2)
        endif
        ? kom[1],space(8),getTranslation("angebot.brutto",LAND->Sprache,13),waehrung,;
          transStr(gwert + mwwert,14,2)
        ? space(56),ANGAUS->FremdWaehr,transStr(ANGAUS->FremdSumme,15,2)


        ? kom[2],space(8),"================================="
        i:=3
      else
        ? space(42),"================================="
        ? Kom[1],space(9)
        preisKom:=getTranslation("angebot.preise",LAND->Sprache)+" "+waehrung+" "
        if ANGAUS->mwst > 0.0
          preisKom += getTranslation("angebot.zzgl",LAND->Sprache)+" "+transstr(ANGAUS->Mwst,5,2)+"% "+;
            getTranslation("allgemein.mwst",LAND->Sprache)
        else
          preisKom:=space(8)+preisKom
        endif
        ?? SCHMAL_AN,PreisKom,SCHMAL_AUS
        i:=2
      endif
      do while i<=6 .and. ! empty(kom[i])
        ? kom[i++]
      enddo

      /** Am Ende Hinweise zum Thema GelangensBescheinigung */
      // GBS remove on Angebot 19.6.2012
      // if ! gbsBefrDruck .and. len(tempBefr)>0
      // zeile += printGBSBefreiung(tempBefr)
      // gbsBefrDruck:=.t.
      // endif

      // gehe ans Ende der Seite
      do while Zeile<laenge-UNT_RAND-10
        ?
      enddo

      // drucke Rabatt-Tabelle
      if ! empty(MerkRabGr) .and. ! Rabatt_mehrf
        kom:=Rabatt_Tab(MerkRabGr,.t.,MerkMindMenge)
        ? kom[1]
      else
        kom:=Rabatt_Tab("")
      endif
      tempText:=linewrap(getTranslation("angebot.danke",LAND->Sprache),31,3)
      ? kom[2]
      ? kom[3]
      ? kom[4]
      ? kom[5]
      ? kom[6],tempText[1]
      ? kom[7],tempText[2]
      ? kom[8],tempText[3]
      ? getTranslation("allgemein.zahlkond",LAND->Sprache,20)
      ? getTransField("ZAHLKOND->Text"),space(8),;
        mycenter(getTranslation("allgemein.gruesse",LAND->Sprache),31)
      ? getTransField("ZAHLKOND->Text2"),space(8),;
        mycenter(getTranslation("allgemein.miki",LAND->Sprache) ,31)
    endif // Seitenumbruch

    Zeile:=FormFeed(Zeile)

  enddo // .not.eof()

  /* r�ckschreiben nach ANGAUS */
  BEGIN SEQUENCE // krit. Bereich
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

    mwwert=ROUND(gwert*ANGAUS->mwst/100 ,2)
    REPLACE ANGAUS->Netto WITH Gwert
    REPLACE ANGAUS->Brutto WITH gwert + mwwert

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    RECOVER // USING objErr
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    // Fehler bereits protokolliert
    email(MAIN_EMAIL,;
      "ACHTUNG: Angebot " +ANGAUS->AngNr+ " Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN,;
      "Bitte dringend �berpr�fen.")

    Error("ACHTUNG: Warenwert zu gro�: " + toString( gwert ) + " "+EURO_SIGN + ;
      "||Bitte dringend �berpr�fen.",.t.)

  END SEQUENCE

  Drucker("Off")

RETURN
  /* EOP Angebot */

function drucke_rabatt_zuschlag(Datei, gwert, frachtkosten, leerzeile, merke_basis)
LOCAL Zeile:=0, text, fill:=0

  default leerzeile:=.f.

  if gwert == 0 .and. frachtkosten == 0
    return 0
  endif

  /** Sonderrabatt */
  If (DATEI)->So_Rabatt > 0.0
    if (DATEI)->Rabatt_KZ="H"
      text:=getTranslation("allgemein.rabatt.haendler",LAND->Sprache,24)
    else
      text:=getTranslation("allgemein.rabatt.sonder",LAND->Sprache,24)
    endif
    fill:=len(text)-len(trim(text))

    if leerzeile
      ?
      leerzeile:=.f.
    endif

    ? space(11)+trim(text)
    ?? KLEIN_AN,getTranslation("allgemein.rabatt.ausser",LAND->Sprache,33),KLEIN_AUS,;
      space(fill)+transstr((DATEI)->So_rabatt,5,2)+"% -",;
      transstr((gwert-frachtKosten)*(DATEI)->So_Rabatt/100,11,2)
    if merke_basis <> NIL
      merke_basis["RABATT"]:=gwert-frachtKosten
    endif
    gwert=gwert-ROUND((gwert-frachtKosten)*(DATEI)->So_RAbatt/100,2)
  endif

  /** Energiekostenzuschlag */
  If (DATEI)->Zuschlag > 0.0
    text:=getTranslation("allgemein.zuschlag.energie",LAND->Sprache,24)
    fill:=len(text)-len(trim(text))
    if leerzeile
      ?
    endif
    ? space(11)+trim(text)
    ?? KLEIN_AN,getTranslation("allgemein.rabatt.ausser",LAND->Sprache,33),KLEIN_AUS,;
      space(fill)+transstr((DATEI)->Zuschlag,5,2)+"%  ",;
      transstr((gwert-frachtKosten)*(DATEI)->Zuschlag/100,11,2)
    if merke_basis <> NIL
      merke_basis["AUFSCHLAG"]:=gwert-frachtKosten
    endif
    gwert=gwert+ROUND((gwert-frachtKosten)*(DATEI)->Zuschlag/100,2)
  endif

  if Zeile > 0
    ?
  endif
return Zeile
/** eof */


/* PROCEDURE Ang_Kopie()
*
* kopiert Angebot
*/
PROCEDURE Ang_Kopie(Abfrage)
LOCAL ant:="" , Quelle:={} , zeile:=0 , i,M_AngNr,orgNr:=ANGAUS->AngNr
LOCAL merksatz
LOCAL GetList:={}

  if empty(ANGAUS->KundNr) .or. ANGAUS->KundNr==KDNR_LEER
    Error(ACHTUNG+" bitte vorher zu kopierendes Angebot ausw�hlen!",.t.)
    return
  endif

  default Abfrage:=.t.

  If ! abfrage .or. Message("Neues Angebot erzeugen (@J@/@N@) ?","JN")=="J"
    M_AngNr:=hole("AngNr",WRITE,.t.)
    select AngAus
    /* Kopiere KopfSatz */
    for i:=2 to fcount()
      aadd(Quelle,&("ANGAUS->"+fieldname(i)))
    next
    add_rec(0)
    replace ANGAUS->AngNr with M_AngNr
    for i:=2 to fcount()
      fieldput(i,quelle[i-1])
    next

    /* kopiere Bauchdaten als OriginalDaten zurueck nach AngPost */
    select Angpost
    dbseek(OrgNr)
    merksatz:=ANGPOST->(recno())
    do while (! ANGPOST->(eof())) .and. ANGPOST->AngNr==OrgNr
      merksatz:=ANGPOST->(recno())
      quelle:={}
      for i:=2 to fcount()
        aadd(Quelle,&("ANGPOST->"+fieldname(i)))
      next
      add_rec(0)
      replace ANGPOST->AngNr with M_AngNr
      for i:=2 to fcount()
        fieldput(i,quelle[i-1])
      next
      go (merksatz)
      skip
    enddo

    clear gets

    /** jojo :( */
    if procname(9)=="EDIT" // kommt aus Bauch
      keyboard chr(K_ESC)+ chr(K_ESC)+ chr(K_ESC)+ M_AngNr +CHR(K_RETURN)
    else
      // M->ang_kopie:=.t.
      keyboard M_AngNr+CHR(K_RETURN)
    endif

  endif
RETURN
/* EOF Ang_Kopie */

/* FUNCTION Rabatt_tab
*
* Parameter: TextKz_Nr
* R�ckgabe:  Array[8] mit gew�nschtem RabattText
*/
static FUNCTION Rabatt_tab(Nr,shiftBottom,mindestMenge)
LOCAL erg[8],x,i,Meng:="RABATT->Meng",Rab

  default shiftBottom:=.f.

  /* Rabatt-Gruppe */
  /* initialisieren */
  aEval( erg , { |a,x| if(a=nil,erg[x]:=space(44),nil) } )

  if ! empty(Nr)
    // seit 5.11.2013 Tabelle auch drucken bei Sonderrabatt
    // .and. upper(nr)<>SONDER_RABATT // nicht bei Artikel-Sonderrabatt
    if nr == SONDER_RABATT
      // nr:=ARTIKEL->RabattGr // unsch�n aber so ist es bei sp�teren �nderungen

      // 13.3.17 wieder raus, bei Sonderrabatt Ausgabe Mind.Menge if applicable
      if mindestMenge > 0
        erg[1]:=left(space(len(out(AUFTRAG->ArtNr))+1) + ;
          getTranslation("angebot.min.menge",LAND->Sprache)+ " " + alltrim(str(mindestMenge))+;
          " "+getTransField("EINHEIT->Text")+space(44),44)
      endif
      return (erg)
    endif

    Rab:="RABATT->Preis"
    RABATT->(dbseek(Nr))
    if RABATT->Preis1 > 0 // absolute Preis, z.B. bei Phoenix Regalteilern 305er Artikel
      RABATT->(dbseek(Nr))
      erg[1]:=getTranslation("angebot.tabelle.preis",LAND->Sprache,44)
      erg[2]:=left(replicate("-",len(trim(erg[1])))+space(44),44)
      i:=1
      if mindestMenge>0
        erg[3]:=alltrim(str(mindestMenge))+" "
      else
        erg[3]:=""
      endif
      erg[3]+=getTranslation("allgemein.bis",LAND->Sprache,4)+alltrim(str(&(Meng+str(i,1))-1,8))+" "+;
        getTransField("EINHEIT->Text")+" = "+;
        getTranslation("angebot.grundpreis",LAND->Sprache)
      erg[3]:=left(erg[3]+space(44),44)
      x:=4
      do while x <=8 .and. i<=9 .and. &(Meng+str(i,1)) > 0
        erg[x]:=getTranslation("allgemein.ab",LAND->Sprache,4)+str(&(Meng+str(i,1)),8)+;
          "-"+transstr(&(Rab+str(i,1)),9,2)
        i++
        if i<=9 .and. &(Meng+str(i,1)) > 0
          erg[x]+="|"+getTranslation("allgemein.ab",LAND->Sprache,2)+str(&(Meng+str(i,1)),8)+;
            "-"+transstr(&(Rab+str(i,1)),9,2)
          erg[x]:=left(erg[x]+space(44),44)
        else
          erg[x]:=left(erg[x]+"|"+space(44),44)
        endif
        i++ ; x++
      enddo
    else // Rabatt in % (Standard)
      Rab:="RABATT->Rab"
      RABATT->(dbseek(Nr))
      erg[1]:=getTranslation("angebot.tabelle.rabatt",LAND->Sprache,44)
      erg[2]:=left(replicate("-",len(trim(erg[1])))+space(44),44)
      i:=1
      if mindestMenge>0
        erg[3]:=alltrim(str(mindestMenge))+" "
      else
        erg[3]:=""
      endif
      erg[3]+=getTranslation("allgemein.bis",LAND->Sprache,4)+alltrim(str(&(Meng+str(i,1))-1,8))+" "+;
        getTransField("EINHEIT->Text")+" = "+;
        getTranslation("angebot.grundpreis",LAND->Sprache)
      erg[3]:=left(erg[3]+space(44),44)
      x:=4
      do while x <=8 .and. i<=9 .and. &(Meng+str(i,1)) > 0
        erg[x]:=getTranslation("allgemein.ab",LAND->Sprache,4)+str(&(Meng+str(i,1)),8)+;
          " -"+transstr(&(Rab+str(i,1)),5,2)+"% "
        i++
        if i<=9 .and. &(Meng+str(i,1)) > 0
          erg[x]+="| "+getTranslation("allgemein.ab",LAND->Sprache,4)+str(&(Meng+str(i,1)),8)+;
            " -"+transstr(&(Rab+str(i,1)),5,2)+"% "
          erg[x]:=left(erg[x]+space(44),44)
        else
          erg[x]:=left(erg[x]+"|"+space(44),44)
        endif
        i++ ; x++
      enddo
    endif

    // removed 17.8.2011, warum brauchen wir das???
    // // nur falls komplett !
    // if empty(erg[4])
    // aEval( erg , { |x| erg[x]:=space(44) } )
    // endif
  endif

  if shiftBottom // shiftet all leer Zeilen vom Ende an den Anfang -> align bottom
    do while empty(erg[7])
      for i:=6 to 1 step -1
        erg[i+1]:=erg[i]
      next
      erg[1]:=space(44)
    enddo
  endif

RETURN(erg)
/* EOF Rabatt_Tab */

/* Function Rabatt_nach()
*
* wird nach Eingabe des Rabatts ausgef�hrt
*/
static FUNCTION Rabatt_nach(oGet)
  if oGet:changed
    if val(oGet:buffer)>0 .and. Message("Sonderrabatt ? ( J / N ) ","JN")=="J"
      replace AUFTRAG->RabattGr with SONDER_RABATT
    else
      if AUFTRAG->RabattGr==SONDER_RABATT
        replace AUFTRAG->RabattGr with ""
      endif
    endif
    dispEditorSumme("ANGAUS","AUFTRAG->Menge",41)
  endif

RETURN(.t.)

/** Wird bei Z - Zur�ck aus Bach in Kopf ausgef�hrt */
static function zurueckKopf()
  Ang_Kopf_Disp()
  Ang_Kopf(1)
  HB_KeyPut(EDIT_QUIT)
return .t.
/** eof */

static function zeigeRabattTabelle()
LOCAL tempDatei:=db_info("RABATT")

  Umgebung( WRITE )
  setcolor(COLWIN)
  if ! empty( AUFTRAG->RabattGr ) .and. AUFTRAG->RabattGr <> SONDER_RABATT
    RABATT->(dbseek(AUFTRAG->Rabattgr))
  else
    RABATT->(dbseek(ARTIKEL->Rabattgr))
  endif
  &(TempDatei[D_DISP])(.f.,.f.,.t.)
  Message("Bitte @Taste@ dr�cken","@")
  Umgebung( LOAD )

return .t.
/** eof */

/** kopiert die akt. Kundennr. nach oget (Versand.KundNr.) */
static function copyAngKundNr()
  keyboard ANGAUS->KundNr + chr(K_RETURN)
return .t.
/** eof */


/* wird vor Eingabe der  Spedition Nr ausgef�hrt
*/
static FUNCTION AngSpedVor()
LOCAL aktRec:=KUNDEN->(recno())
LOCAL Spedits

  MySetKey( K_F10 , {|p1,oGet| Hilfe("SpedAuswahl-Angebot",oGet,p1)})
  Message('Spedition eingeben.         @F10@=Kundenvorgabe     @F12@=Auswahl')

  if empty(ANGAUS->SpedNr) // oGet:buffer
    KUNDEN->(dbseek(ANGAUS->V_KundNr))
    spedits:=getKundSpedits( ANGAUS->V_KundNr )
    if len(spedits) > 1
      HB_KeyPut(K_F10)
    endif

    KUNDEN->(dbgoto( aktRec ))
  endif

RETURN(.t.)
/* EOF Sped_nach */

/* wird nach Eingabe der  Spedition Nr ausgef�hrt
  * Schreibt Nr zur�ck nach Kunden, falls dort leer
*/
static FUNCTION AngSpedNach(oGet)
LOCAL aktRec:=KUNDEN->(recno())

  if ! check(oGet,"Spedit")
    return .f.
  endif

  Message()

  MySetKey( K_F10 , nil )
  Ang_Kopf_disp()
return .t.
/** eof */

  /** Pr�ft ob Posten bereits beliefert -> darf nicht gel�scht werden
  * oder ob ein Posten bereits ein innerbetr. Auftrag existiert
  */
static function konsistenzLoesch()

  // pr�fe ob Zoll-Artikel
  if ANGAUS->ZollZuschl == "J" .and. isZollZuschlagArtikel( AUFTRAG->ArtNr )
    Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.||"+;
      "Zum �ndern bitte Zollzuschlag in Kopfdaten auf N setzen")
    return .f.
  endif

  // now delete via editor.prg
  HB_KeyPut(EDIT_DELETE)

return .t.
/** eof */

/* F�gt alle Ersatzteile des aktuellen Artikels hinzu */
static function addErsatzteile()
LOCAL Material, mat
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL aktRec2:=AUFTRAG->(recno())
LOCAL aktSel:=alias()
LOCAL copy0:=nil

  ARTIKEL->(dbseek( AUFTRAG->ArtNr))
  if ARTIKEL->(eof())
    Error(ACHTUNG+"Bitte zuerst g�ltigen Artikel eingeben.")
    ARTIKEL->(dbgoto( aktRec ))
    return .f.
  endif

  if ! getArtikelArt() $ "FM"
    Error(ACHTUNG+"Kein Fertigungs- oder Montageartikel.")
    ARTIKEL->(dbgoto( aktRec ))
    return .f.
  endif

  if Message("Erstazteile hinzuf�gen? (@J@/@N@)","JN","J")=="J"
    // hole St�ckliste / Ersatzteile
    Material:=Stueckliste():new( ARTIKEL->ArtNr, ARTIKEL->Art ):getMaterial( .f. )
    for each mat in Material
      ARTIKEL->(dbseek( mat:ArtNr ))
      if ! ARTIKEL->(eof())
        if ARTIKEL->Preis1 == 0
          if copy0 == NIL
            copy0:=( Message("Artikel mit Preis 0 ebenfalls kopieren? (@J@/@N@)","JN","J")=="J" )
          endif
          // Artikel mit Preis 0 auslassen?
          if ! copy0
            loop
          endif
        endif

        SELECT Auftrag
        insertBlank(.f.)
        ARTIKEL->(dbseek( mat:ArtNr )) // needed wg. rela auf AUFTRAG->Artmr
        Ang_Satz_nach()
        replace AUFTRAG->ArtNr with ARTIKEL->ArtNr
        replace AUFTRAG->Menge WITH 1
        replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
        replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
        replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
        replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2
        replace AUFTRAG->Preis WITH ARTIKEL->Preis1
        replace AUFTRAG->Me WITH ARTIKEL->ME
        replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
        // replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
        replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
        dbcommit()
      endif
    next
    select (aktSel)
    AUFTRAG->(dbgoto( aktRec2 ))
    ARTIKEL->(dbgoto( aktRec ))
    HB_KeyPut(EDIT_BS_REFRESH)
  endif
return .t.
/** eof */


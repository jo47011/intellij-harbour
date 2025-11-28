/* Modul: Liefer.prg
*
* enth�lt alles bzgl. Hand-Lieferscheinen
*/

#include "Miki.ch"

#define TEMP_NUMMER right("*****"+getUser():getLongID(),len(LIEFAUS->LSNr))

/* erfassen von Hand-Lieferscheinen
*
*
*/
PROCEDURE LiefErfassen()
LOCAL Ende:=.f. , Taste:=0
LOCAL ant:="N" , M_LSNr:="",M_AufNr:=""
LOCAL GetList:={},merkNr,Ausgabe:="D",diff
MEMVAR emailAbweichend
PRIVATE emailAbweichend:=0 // is ignored here

  cls
  Titel("Hand-Lieferschein erfassen/drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Lieftemp" , "LiefAus" , "ZahlKond" ,"Aufaus","AufPost",;
    "Artikel", "Einheit" , "VersArt" , "Liefpost","BeisTemp",;
    "Kunden","Lieferan","Land","Spedit","AvPost","Mat_KZ","KundSped","ArtText")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select AufPost
  AUFPOST->(OrdSetFocus(3)) // AufNr+ArtNr

  /* Relationen setzten */
  SELECT Lieftemp
  SET RELATION To LIEFTEMP->ArtNr INTO ARTIKEL, TO LIEFTEMP->ME INTO Einheit
  select artikel
  set relation to ARTIKEL->ME into Einheit
  select liefaus
  set relation to LIEFAUS->versNr into versart

  do while ! Ende

    cls
    Titel()

    /* l�sche Lieftemps-Datei */
    select Lieftemp
    zap

    /* Kopf eingeben */
    select Liefaus

    go bottom
    skip // leeren Satz anzeigen
    LS_Kopf_disp()
    Ende:=! LS_Kopf(0)

    if Ende
      loop
    endif

    // pr�fe ob Ansprechpartner bei EU Partner eingegeben
    LAND->(dbseek(left(LIEFAUS->Land,2)))

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(LIEFAUS->Sprache)

    /* alle passenden Posten kopieren */
    if LIEFAUS->LSNr<>TEMP_NUMMER // alter Auftrag

      select Liefpost
      seek LIEFAUS->LSNr
      do while ! LIEFPOST->(eof()) .and. LIEFPOST->LSNr==LIEFAUS->LSNr
        select Lieftemp
        add_rec(0)
        overwrite("Liefpost")
        // merke vorherige Menge, falls abegbucht wird
        if LIEFTEMP->Abbuch=="J"
          replace LIEFTEMP->Menge_alt with LIEFTEMP->Menge
          replace LIEFTEMP->ArtNr_alt with LIEFTEMP->ArtNr
        endif
        replace LIEFTEMP->Abbuch_alt with LIEFTEMP->Abbuch
        select Liefpost
        skip
      enddo

    endif

    /*** Posten editieren **/
    Taste:=LS_Bauch()

    // falls AB neu erfasst und keine Posten -> Abfrage verwerfen
    if LIEFAUS->LSNr==TEMP_NUMMER .and. LIEFTEMP->(reccount())==0
      if Message("Lieferschein verwerfen?  (@J@/@N@)","JN")<>"N"
        loop
      endif
    endif

    /* Auswahl-Menu */
    Ausgabe:="D"
    setcolor(COLWIN)
    Fenster(5,16,13,57)
    @ 6,20 say 'Drucken als:'
    @ 8,20 say "Lieferschein"
    Message("Ausgabe auf @D@rucker ?           @ESC@=Abbruch ")
    @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/P) ' get Ausgabe Picture "!" valid Ausgabe $"DBP"
    read
    setcolor(COLNOR)

    // falls AB neu erfasst und keine Posten -> Abfrage verwerfen
    if ABBRUCH
      ant:=" "
      do while ! ant $ "JN"
        ant:=Message("�nderungen verwerfen?  (@J@/@N@)","JN","N")
        if ABBRUCH
          ant:=" "
        endif
      enddo
      if ant =="J"
        loop
      endif
      Ausgabe:="NOP"
    endif

    /* neue Auf.Nr. vergeben */
    if LIEFAUS->LSNr==TEMP_NUMMER // neuer Satz
      merkNr:=LIEFAUS->(recno())

      /* hole akt. Auft.Nr, schreiben */
      M_LSNr:=hole("LSNr",WRITE,.t.)

      /* checken ob nicht schon vorhanden */
      select Liefaus
      seek M_LSNr
      if ! eof()
        Error("Lieferschein-"+NUMMER_DOPPELT)
      endif
      do while ! eof()
        Message("Suche n�chste freie LS-Nummer.  Bitte warten...")
        M_LSNr:=hole("LSNr",WRITE,.t.)
        seek M_LSNr
      enddo
      go (MerkNr)
      rec_lock(0)
      replace LIEFAUS->LSNr with M_LSNr

    endif

    dbcommitall()

    Message("Lieferschein: @"+LIEFAUS->LSNr+"@ wird gedruckt.  Bitte warten...")
    HandLiefDruck(Ausgabe)

    /*** Posten r�ckschreiben ***/
    Message("Lieferschein wird gespeichert.  Bitte warten...")

    select Beistemp
    zap

    select Liefpost
    seek LIEFAUS->Lsnr
    // l�sche alte Posten, if any
    do while ! eof() .and. LIEFPOST->Lsnr==LIEFAUS->Lsnr
      rec_lock(0)
      delete
      skip
    enddo

    /* neue Posten anh�ngen */
    select Lieftemp
    go top
    select LiefPost
    do while ! LIEFTEMP->(eof())
      add_rec(0)
      overwrite("Lieftemp")
      replace LIEFPOST->Lsnr with LIEFAUS->Lsnr

      // abbuchen?
      if ! alltrim(LIEFTEMP->ARtNr)$"$*"+ANGEBOTS_ARTIKEL

        // gleicher oder neuer Artikel Nr
        if empty(LIEFPOST->ArtNr_alt) .or. LIEFPOST->ArtNr==LIEFPOST->ArtNr_Alt
          // 4 F�lle
          do case
          case LIEFPOST->Abbuch=="J" .and. LIEFPOST->Abbuch_ALT=="J"
            diff:=LIEFPOST->Menge_Alt-LIEFPOST->Menge // differenz alt/neu buchen
          case LIEFPOST->Abbuch=="J" .and. LIEFPOST->Abbuch_ALT<>"J"
            diff:=LIEFPOST->Menge *(-1) // neue Menge abbuchen
          case LIEFPOST->Abbuch<>"J" .and. LIEFPOST->Abbuch_ALT=="J"
            diff:=LIEFPOST->Menge_Alt // nur alte Menge buchen
          case LIEFPOST->Abbuch<>"J" .and. LIEFPOST->Abbuch_ALT<>"J"
            diff:=0 // nix buchen
          otherwise
            // should never happen!
            TroubleEmail("Liefbuch:"+LIEFPOST->Abbuch+LIEFPOST->Abbuch_Alt)
          endcase
        else // Artikel-Nr ge�ndert

          // buche alten zuerst wieder zu
          diff:=LIEFPOST->Menge_Alt // nur alte Menge buchen
          select Artikel
          ARTIKEL->(dbseek(LIEFPOST->ArtNr_alt))
          rec_lock(0)
          aendArtBest(diff,WARAUS_LIEFNR+LIEFAUS->Lsnr)
          // interner K-Lager Artikel?
          if getArtikelArt()=="B" // .and. ! empty(ARTIKEL->KonsigKdNr)
            aendArtKbest(diff,WARAUS_LIEFNR + LIEFAUS->Lsnr)
          endif
          dbcommit()
          dbunlock()
          select LiefPost

          // neuen unten abbuchen
          diff:=LIEFPOST->Menge *(-1) // neue Menge abbuchen
          ARTIKEL->(dbseek(LIEFPOST->ArtNr))
        endif

        if diff<>0
          select Artikel
          rec_lock(0)
          aendArtBest(diff,WARAUS_LIEFNR+LIEFAUS->Lsnr)
          // interner K-Lager Artikel?
          if getArtikelArt()=="B" // .and. ! empty(ARTIKEL->KonsigKdNr)
            aendArtKbest(diff,WARAUS_LIEFNR + LIEFAUS->Lsnr)
          endif
          dbcommit()
          dbunlock()

          // suche Beistellteile, falls Artikel kein internes Beistellteil
          if ! trim(LIEFPOST->ArtNr)$"$*" .and. ;
            ! (getArtikelArt()=="B" .and. ! empty( left( ARTIKEL->KonsigKdNr,5 ) ))
            select AvPost
            BeistellRek(LIEFPOST->ArtNr,diff) // nur Differenz buchen
          endif

          select LiefPost
        endif
      endif

      LIEFTEMP->(dbskip(1))
    enddo

    dbcommitall()
    unlock all

    // zuerst Beistelle Dieffernz abbuchen
    select Beistemp
    go top
    do while ! BEISTEMP->(eof())
      ARTIKEL->(dbseek( BEISTEMP->ArtNr ))
      // if ! empty(ARTIKEL->KonsigKdNr)
      Select Artikel
      if ! rec_lock(5)
        Error("K-Lager Bestand: "+ARTIKEL->ArtNr+" konnte nicht gebucht werden.",.t.)
      else
        aendArtKBest(BEISTEMP->Menge,WARAUS_BEISTELL + " " + LIEFAUS->LsNr) // Menge ist schon negativ
      endif
      select Beistemp
      // endif
      skip
    enddo

    // Beistellteil-Liste nach r�ckschreiben, da dort aus LiefPost gedruckt wird.
    BeistLiefDruck(Ausgabe)

  enddo // Ende Lieftemps-Erfassung

  /* neuen Datensatz l�schen ? */
  select Liefaus
  seek TEMP_NUMMER
  do while ! eof() .and. LIEFAUS->Lsnr==TEMP_NUMMER
    rec_lock(0)
    delete
    skip
  enddo

  close data
  AufBestand()

RETURN
/* EOP LS_erfassen */

/* Function LS_Kopf
*
* Eingabe des Lieferschein-Kopfes
*
* Parameters: 0 == komplett �nderbar
*             1 == Lsnr fix , Rest �nderbar
*             2 == nur anzeigen
* R�ckgabe  : Ende ja/nein
*/
FUNCTION LS_Kopf(Edit)
LOCAL GetList:={}
LOCAL M_Lsnr
LOCAL ob:=0
  if edit==0
    M_Lsnr:=hole("Lsnr",LOAD) // hole neuste AuftragsNr, nur lesen
    @ ob+2,14 get M_Lsnr picture '@K #####' ;
      valid { |oGet| shift(oGet) .and. Lsnr_nach(oGet) };
      when ( Message('Lieferscheinnummer eingeben.             @F12@=Hilfe'))
  else
    @ ob+2,14 say LIEFAUS->Lsnr
  endif

  @ ob+3,14 GET LIEFAUS->AufNr valid { |oGet| LS_AufNr_Nach(oGet) };
    when Message("Auftragsnummer eingeben (optional)    @F8@=AB Artikel kopieren  @F12@=Hilfe")

  @ ob+2,38 get LIEFAUS->KundNr PICTURE KDNR_PICT;
    valid { |oGet| KundNr_nach(oGet) .and. MySetKey( K_F3 ,nil )} when Message('Kunden-Nummer '+;
    'eingeben. @F3@=Lieferanten @F5@=Sprache �ndern @F8@=AB Artikel  @F12@=Hilfe') .and. MySetKey( K_F3 , {|| Hilfe("Hand-LS,LiefNr",getNew()) } )

  @ ob+4,38 get LIEFAUS->V_KundNr PICTURE KDNR_PICT;
    valid { |oGet| VKundNr_nach(oGet) .and. MySetKey( K_F3 ,nil )} when Message("Kundennummer "+;
    "Versand eingeben @F3@=Lieferanten @F5@=Sprache @F8@=AB Artikel   @F12@=Hilfe") .and. MySetKey( K_F3 , {|| Hilfe("Hand-LS,LiefNr",getNew()) } )

  /* Datum,Art,Bestkto */
  @ ob+5,14 GET LIEFAUS->AufDat when Message('Lieferscheindatum eingeben        @*@=Heute @+@/@-@')
  @ ob+6,14 get LIEFAUS->VersNr picture "@9" ;
    valid { |oGet| check(oGet,"VersArt",.t.,.f.);
    .and. LS_Kopf_disp() } when Message('Versandart eingeben.             @F12@=Hilfe')

  @ ob+7,14 get LIEFAUS->SpedNr picture "@9" ;
    when { || AufSpedVor("LiefAus") } valid { |oGet| AufSpedNach(oGet) .and. LS_kopf_disp() }


  @ ob+11,1 GET LIEFAUS->BestKonto when Message('Best.Text eingeben.')

  @ ob+13,1 GET LIEFAUS->BestDat valid ! empty(LIEFAUS->BestDat);
    when Message('Bestelldatum eingeben        @*@=Heute @+@/@-@')
  @ ob+15,1 GET LIEFAUS->BestNr when Message('Bestell - Nr. eingeben.')

  // Ausfallmuster
  @ ob+10,49 say "Ausfallmuster:" get LIEFAUS->Ausfall Picture "!" valid LIEFAUS->Ausfall $"JN" ;
    when Message("Ausfallmuster (@J@/@N@)")

  // Ansprechpartner
  @ ob+20,1 get LIEFAUS->Ansprech
  @ ob+22,1 get LIEFAUS->Email picture "@S47" valid {|oget| isValidEmail(oget)}
  @ ob+20,49 get LIEFAUS->Telefon
  @ ob+22,49 get LIEFAUS->Fax

  if edit<>2
    set key K_F8 to copyABPosten()
    set key K_F5 to aendSprache()
    read
    set key K_F3 to
    set key K_F5 to
    set key K_F8 to
  endif

RETURN ! (empty(LIEFAUS->KundNr) .or. LIEFAUS->KundNr==KDNR_LEER)
/* EOF AufKopf */

/* Function LS_Kopf_disp
*
* gibt den LieftempsKopf auf den BS aus
*/
FUNCTION LS_Kopf_Disp
LOCAL ob:=0

  // needed falls mit Zur�ck aus Bauch kommt
  select LiefAus

  @ ob+2,1 say 'LS-Nr......:'
  @ ob+3,1 say 'AB-Nr......:'

  @ ob+5,1 say 'Datum......:'
  @ ob+6,1 say "Versand-Art:"
  if empty(LIEFAUS->VersNr)
    @ ob+6,18 say space(11)
  else
    @ ob+6,18 say left(VERSART->Text,11)
  endif

  @ ob+7,1 say "Spedition..:"
  if empty(LIEFAUS->SpedNr)
    @ ob+8,1 say space(30)
  else
    SPEDIT->(dbseek(LIEFAUS->SpedNr))
    @ ob+8,1 say left(SPEDIT->Name,30)
  endif


  // Best.Konto wird als Lieferschein.Nr. benutzt, 23.2.2012
  @ ob+10,1 say "Best.Text.......:"
  @ ob+12,1 say "Best.Datum......:"
  @ ob+14,1 say "Best.Nr. Anfrage:"

  @ ob+19,1 say "Name Ansprechpartner:"
  @ ob+21,1 say "Email:"
  @ ob+19,49 say "Tel:"
  @ ob+21,49 say "Fax:"

  @ ob+1,32 say "Auftrag-Anschr:"
  @ ob+2,32 say 'Kd.Nr:'
  if ! empty(LIEFAUS->Sprache) .and. LIEFAUS->Sprache<>DEUTSCH
    @ ob+1,40 say "(engl) "
  endif
  @ ob+1,49 say LIEFAUS->Name
  @ ob+2,49 say LIEFAUS->Ort

  @ ob+3,32 say "Versand-Anschr:"
  @ ob+4,32 say 'Kd.Nr:'
  @ ob+3,49 say LIEFAUS->V_Name
  @ ob+4,49 say LIEFAUS->V_Partner
  @ ob+5,49 say LIEFAUS->V_Strasse
  @ ob+6,49 say LIEFAUS->V_Land
  @ ob+6,52 say LIEFAUS->V_PLZ
  @ ob+6,58 say LIEFAUS->V_Ort

  @ ob+17,1 to ob+17,78


RETURN(.t.)
/* EOF LS_Kopf_Disp */


/* Funktionen f�r Kopfeingabe   *************************
  * nach LS.Nr */
STATIC FUNCTION LSNr_nach(oGet)

  if ! lastkey()==K_RETURN
    RETURN(.f.)
  endif
  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
  endif

  select LiefAus

  /* vorher neuer Satz, jetzt immer noch */
  if oGet:buffer==TEMP_NUMMER
    seek TEMP_NUMMER
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      RETURN(.f.)
    endif
  else
    /* vorher neuer Satz jetzt umentschieden */
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
          Error("Liefaus.dbf"+DATEI_EXCL)
          RETURN(.f.)
        endif
        M->MerkNr:=recno()
        M->MerkNr:=recno()
        REPLACE LIEFAUS->LSNr WITH TEMP_NUMMER
        REPLACE LIEFAUS->AufDat WITH getUser():date
        REPLACE LIEFAUS->BestDat WITH getUser():date
        REPLACE LIEFAUS->Ausfall WITH "N"
      else
        Error("Lieferschein nicht vorhanden.")
        return .f.
      endif

    else // ! eof
      // gefunden und immer richtige AuftrArt, dank filter
      if ! Rec_Lock(5)
        Error(SATZ_EXCL)
        RETURN(.f.)
      endif

      /** w�hle Sprache je nach Empf�nger */
      selLandBySprache(LIEFAUS->Sprache)
    endif

  endif

  LS_kopf_disp()
  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe

RETURN(.t.)
/* EOF LSNr_nach */


/* nach Eingabe der AB-Nummer ausgef�hrt
  * entweder leer oder ex. AB
*/
static FUNCTION LS_AufNr_nach(oGet)

  if oGet:changed
    if ! empty(oGet:buffer)
      if check(oGet,"AufAus",.f.,.f.)
        // kopiere alle passenden Felder aus Aufaus
        overwrite("AufAus",.t.)
        setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
        LIEFAUS->(dbcommit())
        LIEFAUS->(dbskip(0))
        LS_Kopf_disp()

        // kopiere alle Posten? FIXME
      else
        return .f.
      endif
    endif
  endif
return .t.
/** eof */


/* Versand-KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
static FUNCTION KundNr_nach(oGet)

  if oGet:changed

    // pr�fe Lieferanten zu erst => keine unn�tige Warnung: Lieferant ex. nicht
    LIEFERAN->(dbseek(left(oGet:buffer,5)))
    if LIEFERAN->(eof())
      // Kunden pr�fen
      if ! check(oGet,"Kunden",.f.,.f.)
        return .f.
      else
        REPLACE LIEFAUS->KurzName WITH KUNDEN->KurzName
        REPLACE LIEFAUS->Name WITH KUNDEN->Name2
        REPLACE LIEFAUS->Partner WITH KUNDEN->Partner2
        REPLACE LIEFAUS->Strasse WITH KUNDEN->Strasse2
        REPLACE LIEFAUS->Zusatz WITH KUNDEN->Zusatz2
        REPLACE LIEFAUS->Plz WITH KUNDEN->PLZ2
        REPLACE LIEFAUS->Land WITH KUNDEN->Land2
        REPLACE LIEFAUS->Ort WITH KUNDEN->Ort2
        REPLACE LIEFAUS->VersNr WITH KUNDEN->VersNr
        REPLACE LIEFAUS->Sprache WITH KUNDEN->Sprache
      endif
    else // Lieferant gefunden
      REPLACE LIEFAUS->KurzName WITH LIEFERAN->KurzName
      REPLACE LIEFAUS->Name WITH LIEFERAN->Name1
      REPLACE LIEFAUS->Partner WITH LIEFERAN->Name2
      REPLACE LIEFAUS->Strasse WITH LIEFERAN->Strasse
      REPLACE LIEFAUS->Zusatz WITH LIEFERAN->Zusatz
      REPLACE LIEFAUS->Plz WITH LIEFERAN->PLZ
      REPLACE LIEFAUS->Land WITH LIEFERAN->Land
      REPLACE LIEFAUS->Ort WITH LIEFERAN->Ort
      REPLACE LIEFAUS->VersNr WITH LIEFERAN->VersNr
      LAND->(dbseek(left(LIEFAUS->Land,2)))
      REPLACE LIEFAUS->Sprache WITH LAND->Sprache
    endif


    LS_kopf_disp()

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(LIEFAUS->Sprache)

    LIEFAUS->(dbcommit())
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif
RETURN(.t.)
/* EOF KundNr_Nach */

/* nach Versand-KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
static FUNCTION VKundNr_nach(oGet)

  if oGet:changed

    // pr�fe Lieferanten zu erst => keine unn�tige Warnung: Lieferant ex. nicht
    LIEFERAN->(dbseek(left(oGet:buffer,5)))
    if LIEFERAN->(eof())
      // Kunden pr�fen
      if ! check(oGet,"Kunden",.f.,.f.)
        return .f.
      else
        REPLACE LIEFAUS->V_Name WITH KUNDEN->Name2
        REPLACE LIEFAUS->V_Partner WITH KUNDEN->Partner2
        REPLACE LIEFAUS->V_Strasse WITH KUNDEN->Strasse2
        REPLACE LIEFAUS->V_Zusatz WITH KUNDEN->Zusatz2
        REPLACE LIEFAUS->V_Plz WITH KUNDEN->PLZ2
        REPLACE LIEFAUS->V_Land WITH KUNDEN->Land2
        REPLACE LIEFAUS->V_Ort WITH KUNDEN->Ort2
      endif
    else // Lieferant gefunden
      REPLACE LIEFAUS->V_Name WITH LIEFERAN->Name1
      REPLACE LIEFAUS->V_Partner WITH LIEFERAN->Name2
      REPLACE LIEFAUS->V_Strasse WITH LIEFERAN->Strasse
      REPLACE LIEFAUS->V_Zusatz WITH LIEFERAN->Zusatz
      REPLACE LIEFAUS->V_Plz WITH LIEFERAN->PLZ
      REPLACE LIEFAUS->V_Land WITH LIEFERAN->Land
      REPLACE LIEFAUS->V_Ort WITH LIEFERAN->Ort
    endif

    LS_kopf_disp()

    LIEFAUS->(dbcommit())
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif
RETURN(.t.)
/* EOF KundNr_Nach */


/* Function LS_Bauch  ****************************************
*
* Eingabe des Lieferschein.Bauches, Editor-definitionen
*
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
FUNCTION LS_Bauch()
LOCAL aFelder,result,starteBeiRecno
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  set key K_F5 to toggleSprache()
  do while ! ABBRUCH .or. starteBeiRecno==NIL
    aFelder:={}
    select Lieftemp

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_ERSATZ_ARRAY]:={ || Auf_Text()}

    aKopf[EDIT_NEW_FKT]:={ || LS_Satz_nach() }
    // wird im Doppelmodus bei Eingabe von Z - zur�ck
    aKopf[EDIT_KOPF_FKT]:={ || LS_Kopf_Disp() .and. LS_Kopf(1) }

    /* Feld-Definitionen */
    // Artikel-Nr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.     @F12@=Hilfe      @F4@=Honsel-Nr.     @ESC@=Ende"
    aSpalte[EDIT_ERSATZ_1]:={ || trim(LIEFTEMP->ArtNr)$"*$" }
    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_AFTER]:={|oGet| ( Artnr_nach(oGet)) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aKopf[EDIT_GESPERRT]:="L"
    aKopf[EDIT_EXTRA_FKT]:={ { "L"," @L@�schen ", { || Konsistenzloesch() } } }

    // Text
    if LAND->Sprache==DEUTSCH
      aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=Englisch ", { || toggleSprache() } })

      aSpalte[EDIT_NAME]:="Komm1"
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Text eingeben."

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="Komm2"
      aSpalte[EDIT_MESSAGE]:="Text eingeben."
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    else
      aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=Deutsch ", { || toggleSprache() } })

      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm1,E_Komm1)"
      aSpalte[EDIT_NAME_GET]:="E_Komm1"
      aSpalte[EDIT_FARBE]:={ || if(empty(LIEFTEMP-> E_Komm1),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyLSTextPosten()})}
      aSpalte[EDIT_AFTER]:={ || MySetKey( K_F8 , NIL) }
      aSpalte[EDIT_AUSGABE]:=.t.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm2,E_Komm2)"
      aSpalte[EDIT_NAME_GET]:="E_Komm2"
      aSpalte[EDIT_FARBE]:={ || if(empty(LIEFTEMP->E_Komm2),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyLSTextPosten()})}
      aSpalte[EDIT_AFTER]:={ || MYSetKey( K_F8 , NIL) }
      aSpalte[EDIT_AUSGABE]:=.t.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Menge
    aSpalte[EDIT_NAME]:="Menge"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_AFTER]:={ |oGet| mengeNach( oGet ) }
    aSpalte[EDIT_MASKE]:="9999999.99"
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_MESSAGE]:="Menge eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Mengeinheit
    aSpalte[EDIT_NAME]:="right(space(3)+trim(getTransField('EINHEIT->Text')),3)"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Abbuchen-KZ
    aSpalte[EDIT_TITEL]:="Abbuchen"
    aSpalte[EDIT_NAME]:="Abbuch"
    aSpalte[EDIT_POS_X]:=3
    aSpalte[EDIT_MASKE]:="!"
    aSpalte[EDIT_BEFORE]:={ || ! alltrim(LIEFTEMP->ARtNr)$"$*"+ANGEBOTS_ARTIKEL }
    aSpalte[EDIT_AFTER]:={ |oget| oGet:buffer$"JN"}
    aSpalte[EDIT_MESSAGE]:="Artikel abbuchen? (@J@/@N@)"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    /**** ENDE Feld-Definitionen ***/
    result:=Edit(aFelder,aKopf)
    starteBeiRecno:=LIEFTEMP->(recno())
  enddo
  set key K_F5 to
  set key K_F8 to

RETURN( result )
/* EOF LS_Bauch */

/* Function LS_Satz_nach()
*
* wird nach hinzuf�gen eines neuen Satzes ausgef�hrt
*/
static FUNCTION LS_Satz_nach
  replace LIEFTEMP->KundNr with LIEFAUS->KundNr
  replace LIEFTEMP->AufDat with LIEFAUS->AufDat
  replace LIEFTEMP->Abbuch with "N" // default ist NICHT abbuchen
RETURN(.t.)

/* Function Artnr_nach
*
* wird nach Eingabe der ArtikelNummer ausgef�hrt
*/
static FUNCTION Artnr_nach(oGet)
  if oGet:changed

    do case
    case trim(oGet:Buffer)$"$*"
      if ! trim(oGet:original)$"$*"
        REPLACE LIEFTEMP->komm1 WITH ""
        REPLACE LIEFTEMP->komm2 WITH ""
        replace LIEFTEMP->komm3 WITH ""
        replace LIEFTEMP->komm4 WITH ""
        REPLACE LIEFTEMP->E_komm1 WITH ""
        REPLACE LIEFTEMP->E_komm2 WITH ""
      endif
    case check(oGet,"Artikel",.f.,.f.)

      // pr�fe ob Artikel in AB vorkommt
      if ! empty(LIEFAUS->AufNr)
        AUFPOST->(dbseek(LIEFAUS->AufNr+oGet:buffer))
        if AUFPOST->(eof())
          Error(ACHTUNG+"Artikel kommt nicht im selektierten Auftrag: "+LIEFAUS->AufNr+" vor!",.t.)
        endif
      endif

      replace LIEFTEMP->komm1 WITH ARTIKEL->Bez1
      replace LIEFTEMP->komm2 WITH ARTIKEL->Bez2
      replace LIEFTEMP->komm3 WITH ""
      replace LIEFTEMP->komm4 WITH ""
      replace LIEFTEMP->E_komm1 WITH ARTIKEL->E_Bez1
      replace LIEFTEMP->E_komm2 WITH ARTIKEL->E_Bez2

      replace LIEFTEMP->Me WITH ARTIKEL->ME
      SELECT Lieftemp
    otherwise
      if Message("Soll der Angebots-Artikel: "+;
        ANGEBOTS_ARTIKEL+" verwendet werden? (@J@/@N@)","JN","J")<>"J" .or. ABBRUCH
        return .f.
      endif
      oGet:varPut(ShiftArtikel(ANGEBOTS_ARTIKEL))
      oGet:updateBuffer()
    endcase

  endif
RETURN(.t.)
/* EOF ArtNr_Nach */

/*
* wird nach Eingabe der Menge ausgef�hrt
*/
static FUNCTION MengeNach(oGet)
  if val( oGet:buffer ) == 0
    Error(ACHTUNG+"Artikel mit Menge 0 werden nicht ausgedruckt!",.t.)
  elseif val( oGet:buffer ) < 0
    Error(ACHTUNG+"Negative Menge nicht zul�ssig!",.t.)
    return .f.
  endif
return .t.
/** eof */

/** �ndern der Sprache F5 */
static function aendSprache()
LOCAL ob:=0,oldValue:=LIEFAUS->Sprache
LOCAL GetList:={},s01:=savescreen()

  if empty(LIEFAUS->Sprache)
    replace LIEFAUS->Sprache with DEUTSCH
  endif

  Message("Sprache eingeben.      @D@eutsch oder @E@nglisch       @F12@=Auswahl")
  @ ob+4,47 get LIEFAUS->Sprache picture "!" valid LIEFAUS->Sprache $ DEUTSCH+ENGLISCH
  read
  restscreen(,,,,s01)

  LS_kopf_disp()

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(LIEFAUS->Sprache)

  // falls mit zru�ck aus Editor gekommen, diesen beenden, um Sprach-Wechsel zu erzwingen
  if oldValue<>LIEFAUS->Sprache .and. inStackTrace("Edit")
    HB_KeyPut(K_PGDN)
    HB_KeyPut(EDIT_QUIT)
  endif

return .t.
/** eof */

/** Pr�ft ob Posten bereits beliefert -> darf nicht gel�scht werden */
static function konsistenzloesch()
  if LIEFTEMP->Menge_Alt > 0
    Error(ACHTUNG+"Posten wurde bereits beliefert.||         Kann nicht gel�scht werden!",.t.)
    return .f.
  endif
  HB_KeyPut(EDIT_DELETE) // l�sche Datensatz �ber edit.prg
return .t.


/** Kopiert beim aktuellen Artikel die dt. Bezeichnung auf die engl. */
static FUNCTION copyLSTextPosten()

  if empty(LIEFTEMP->E_Komm1) .or.;
    Message("Englischen Text �berschreiben?  (@J@/@N@)","JN","N")=="J"
    replace LIEFTEMP->E_Komm1 with LIEFTEMP->Komm1
    replace LIEFTEMP->E_Komm2 with LIEFTEMP->Komm2
  endif

return .t.
/** eof */

/** Kopiert alle Artikel aus der AB */
static FUNCTION copyABPosten()
LOCAL count:=0

  if empty(LIEFAUS->AufNr)
    Error(ACHTUNG+"Bitte zuerst AB-Nummer.",.t.)
    return .f.
  endif


  if Message("Alle Posten aus Auftrag @"+LIEFAUS->AufNr+"@ �bernehmen?  (@J@/@N@)","JN","N")=="J"
    Umgebung(WRITE_ALL)

    SELECT Lieftemp
    delet for empty(LIEFTEMP->ArtNr)
    pack

    select AufPost
    AUFPOST->(OrdSetFocus(1))
    dbseek(LIEFAUS->AufNr)
    do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr==LIEFAUS->AufNr
      SELECT Lieftemp
      add_rec(0)
      replace LIEFTEMP->ARTNR with AUFPOST->ARTNR
      replace LIEFTEMP->KOMM1 with AUFPOST->KOMM1
      replace LIEFTEMP->KOMM2 with AUFPOST->KOMM2
      replace LIEFTEMP->KOMM3 with AUFPOST->KOMM3
      replace LIEFTEMP->KOMM4 with AUFPOST->KOMM4
      replace LIEFTEMP->E_KOMM1 with AUFPOST->E_KOMM1
      replace LIEFTEMP->E_KOMM2 with AUFPOST->E_KOMM2
      replace LIEFTEMP->MENGE with AUFPOST->MENGE
      replace LIEFTEMP->ABBUCH with "N"
      replace LIEFTEMP->ME with AUFPOST->ME
      count++
      select AufPost
      dbskip()
    enddo
    Error(str(count,5)+" Posten kopiert.",.t.)

    Umgebung(LOAD)

  endif

return .t.
/** eof */


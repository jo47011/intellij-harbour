/* Modul:  Fakt2.prg    enth�lt Teile der Fakturierung.
*/

#include "Miki.ch"
// #include "repa.ch"

#define RECHNUNG_EDIT 0
#define RECHNUNG_OKAY 1
#define RECHNUNG_QUIT 2

/*
*  freigeben von Rechnungen
*
*  Parameters Art:
*                  K=K-Lager (Konsignationslager)
*                  S=standard
*
*                  A=Ausfallmuster  (obsolete)
*/
PROCEDURE Rech_frei(Art)
LOCAL M_KundNr:=".", M_Artnr,M_FreiNr:=".",kom
LOCAL Taste, GetList:={}, Titel,KonsigLSNr
LOCAL Art_Text,exit:=.f.,Ausgabe:="D",gedruckt:=.f.
LOCAL merkArt,merkFilter,merkSatz,merkABNr,aDatei,erledigt
LOCAL dateiName, okay, druckeWBS
LOCAL paletten, numPaletten, verpackungen, numVerpackung, s01
LOCAL subject, body

MEMVAR zollManuell
PRIVATE zollManuell:=.f.

  cls
  do case
  case Art=="A"
    Error("Bitte Hand-Lieferschein verwenden!")
    return
  case Art=="K"
    Titel="K-Lager Lieferscheine freigeben"
    Art_Text:="K-Lieferschein"
  otherwise
    Titel="Rechnungen/Lieferscheine freigeben"
    Art_Text:="Rechnung"
  endcase

  Titel(Titel)

  if ! openRechnDateien()
    return
  endif

  M_KundNr:=space(len(KUNDEN->KundNr))
  // do while ! empty(M_KundNr)
  do while ! exit
    @ 1,0 clear
    Titel(Titel)

    M->zollManuell:=.f.

    // neu 2.2.2012, Aufaus Datensatz wurde ge-lockt, also wieder freigeben
    dbcommitall()
    unlock all

    Message("Kundennummer eingeben.           @F12@=Hilfe")
    @ 2,10 say "Kund.Nr.:" get M_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
    read
    if ABBRUCH
      exit:=.t.
      loop
    endif

    // letzte Artikel-Nr wieder vorschlagen
    // if ! empty(M_ArtNr)
    // keyboard M_ArtNr
    // endif

    @ 1,0 clear
    @ 2,0 say "Kund.Nr.: "+KdOut(KUNDEN->KundNr)
    @ 2,25 say KUNDEN->KurzNAme

    // ACHTUNG rela wird unten noch mal ge�ndert
    Select Aufpost
    set relation to AUFPOST->ArtNr into Artikel, AUFPOST->AufNr into AufAus

    /* Hilfe automat. vorschlagen */
    aDatei:=db_info("AufPost")
    if Art=="K"
      index on &(aDatei[D_IND2]) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        AUFPOST->Menge > AUFPOST->GeliefGes .and. AUFPOST->KundNr==KUNDEN->KundNr .and.;
        AUFPOST->AufArt$"K" .and. ! (alltrim(AUFPOST->ArtNr) $ "$*") .and. AUFAUS->erledigt<>"J"
      Hilfe("FAKT,K-AUFTRAG MIT FILTER",getnew(),"AufpostNr")
    else
      index on &(aDatei[D_IND2]) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFPOST->AufArt$"V") .and.;
        AUFPOST->KundNr==KUNDEN->KundNr .and. AUFPOST->AufArt$"RV" .and. ! (alltrim(AUFPOST->ArtNr) $ "$*") .and. AUFAUS->erledigt<>"J"
      Hilfe("FAKT,AUFTRAG MIT FILTER",getnew(),"AufpostNr")
    endif
    M_ArtNr:=AUFPOST->ArtNr
    M_FreiNr:=AUFPOST->AufNr
    Select Aufpost
    AUFPOST->(OrdSetFocus(1))
    // Muss hier stehen, da ansonsten nach dem kopiern der falsche Posten und Auftrag selektiert ist.
    set relation to AUFPOST->ArtNr into Artikel

    keyboard ""

    /* Abbruch Artikel-Auswahl ? */
    if ABBRUCH .or. empty(AUFPOST->AufNr)
      loop
    endif

    /* ist Auftrag ? */
    if AUFPOST->AufArt$"BD"
      Error(ACHTUNG+" RahmenAuftrag kann nicht direkt freigegeben werden.",.t.)
      loop
    endif

    /* ist Auftrag ? */
    if ! AUFPOST->AufArt$"RKV"
      Error(ACHTUNG+" Auftrag ist nicht als Rechnung erfasst.|Kann nicht freigegeben werden.",.t.)
      loop
    endif

    AUFAUS->(dbseek(M_FreiNr))
    select AufPost

    if AUFAUS->(eof())
      Error(AUFPOST->AufNr+" nicht vorhanden !"+SCHWERER_FEHLER)
      loop
    endif

    /** pr�fe Ident.Nr. */
    if ! checkIdentNr(AUFAUS->V_KundNr)
      loop
    endif

    /* Auftragsposten kopieren */
    select Auftrag
    zap

    // neu 2.2.2012, Aufaus Datensatz locken um parallele Verarbeitung zu verhindern
    select AufAus
    if ! rec_lock(5)
      Error(TRY_AGAIN)
      loop
    endif

    select AufPost
    seek AUFAUS->AufNr

    @ 1,0 say "Auf.Nr..: "+AUFAUS->AufNr
    @ 1,16 say AUFAUS->AufDat
    @ 1,25 say "Best.Nr.: "+AUFAUS->BestNr
    kom:=""
    if ! empty(AUFAUS->R_Sprache) .and. AUFAUS->R_Sprache<>DEUTSCH
      kom+="Re: engl. "
    endif
    if ! empty(AUFAUS->V_Sprache) .and. AUFAUS->V_Sprache<>DEUTSCH
      kom+="LS: engl. "
    endif
    kom:=alltrim(kom)
    if len(kom)>0
      @ 1,80-len(kom) say kom
    endif
    setColor(COLERR)
    @ 2,75 say 'Euro'
    setColor(COLNOR)

    /* alle passenden Posten kopieren */
    do while AUFPOST->AufNr==M_FreiNr .and.!AUFPOST->(eof())
      if substr(AUFPOST->ArtNr,1,1)<>'$' .and.;
        (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->AufArt=="V") .or. trim(AUFPOST->ArtNr)=="*" .and. AUFAUS->erledigt<>"J"

        select Auftrag
        add_rec(0)
        overwrite("AufPost")

        // bei K_Lager aktuellen Preis aus Artikel-Stamm holen
        if AUFAUS->AufArt == "K"
          ARTIKEL->(dbseek( AUFTRAG->ArtNr ))
          replace AUFTRAG->Preis WITH ARTIKEL->Preis1
        elseif AUFAUS->AufArt == "V" // KV ist bereits abgebucht
          replace AUFTRAG->Gelief WITH AUFPOST->Menge
          replace AUFTRAG->GeliefGes WITH 0
        endif

        select AufPost
      endif
      skip
    enddo

    // gehe auf passende Versandart
    VERSART->(dbseek(AUFAUS->VersNr))

    // Zur�ck auf 1. Posten des Auftrags
    AUFPOST->(dbseek(M_FreiNr))

    // pr�fe ob Rahmenauftrag Budget
    merkArt:=NIL
    if ! empty(AUFAUS->Ab_AufNr)
      merkFilter:=AUFAUS->(dbfilter())
      merkSatz:=AUFAUS->(recno())
      merkAbNr:=AUFAUS->Ab_AufNr

      select Aufaus
      AUFAUS->(dbseek(merkAbNr))
      if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"BD" // .or. AUFAUS->erledigt=="J"
        Error(ACHTUNG+" Rahmenauftrag "+AUFAUS->AufNr+" konnte nicht gebucht werden!"+;
          SCHWERER_FEHLER)
      else
        merkArt:=AUFAUS->Aufart
      endif
      set filter to &(merkFilter)
      AUFAUS->(dbgoto(Merksatz))
      select Auftrag

      if merkArt="B" // Budget Rahmen-Auftrag
        budgetRahmAbStatus(.f.,.f.)
        SetKey( K_F10, {|| budgetRahmAbStatus(.t.,.f.)} )
      endif
    endif

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(AUFAUS->Sprache)

    // Rechnung bearbeiten bis Abbruch oder Druck
    okay:=RECHNUNG_EDIT
    do while okay == RECHNUNG_EDIT

      /*** Posten editieren **/
      Taste:=Rech_Bauch(merkArt)

      /** ueberpruefe ob Posten ausgewaehlt ! */
      select Auftrag
      locate for AUFTRAG->gelief <> 0
      if eof()
        okay:=RECHNUNG_QUIT
        loop
      endif

      // pr�fe Paletten/Verpackungsanzahl bei Speditions-Versand
      SPEDIT->(dbseek( AUFAUS->SpedNr ))
      if SPEDIT->SpedKz == "J"

        if KUNDEN->PalKto <> "N"
          paletten:=HB_ATokens( getProperty("Miki.palette.artnr","") , ":" )
          sum AUFTRAG->gelief to numPaletten for aContains( paletten , alltrim(AUFTRAG->ArtNr))
          if numPaletten == 0
            s01:=savescreen()
            Error(ACHTUNG+"Speditionsversand, Bitte Anzahl der Paletten eingeben.",ERR_NO_WAIT)
            if Message("@ESC@ = Paletten eingeben.   @F@ = ohne Eingabe @f@ortfahren?","F"," ")<>"F" .or.;
              ABBRUCH
              restscreen(,,,,s01)
              loop
            endif
            restscreen(,,,,s01)
          endif
        endif

        if ! isPhoenixAuftrag()
          // pr�fe zugeh�rige (Schrumpf-)Verpackungen
          paletten:=HB_ATokens( getProperty("Miki.palette.brauchtverpackung.artnr","") , ":" )
          sum AUFTRAG->gelief to numPaletten for aContains( paletten , alltrim(AUFTRAG->ArtNr))

          verpackungen:=HB_ATokens( getProperty("Miki.palette.verpackung.artnr","") , ":" )
          sum;
            AUFTRAG->gelief to numVerpackung for aContains( verpackungen , alltrim(AUFTRAG->ArtNr))

          if numPaletten <> numVerpackung
            s01:=savescreen()
            Error(ACHTUNG+"Anzahl Paletten und Verpackungen weicht ab.||"+;
              "         " + alltrim(str(numPaletten,8,0)) + " Palette"+if(numPaletten>1,"n"," ")+"|"+;
              "         " + alltrim(str(numVerpackung,8,0)) + " Verpackung"+if(numVerpackung==1,"  ","en"),;
              ERR_NO_WAIT)
            if Message("Trotzdem fortfahren? (@J@/@N@)","JN"," ")<>"J" .or. ABBRUCH
              restscreen(,,,,s01)
              loop
            endif
            restscreen(,,,,s01)
          endif
        endif
      endif // Speditionsversand

      select Auftrag
      go top

      Message("Rechung @d@rucken?    @ESC@ = Abbruch oder weiter bearbeiten.")
      setcolor(COLWIN)
      Fenster(5,16,13,57)
      @ 6,20 say 'Drucken als:'
      @ 8,20 say Art_Text
      @ 10,20 say 'Drucker (D) ' get Ausgabe Picture "!" valid Ausgabe $"D"
      read

      setcolor(COLNOR)
      if ABBRUCH
        if Message("�nderungen @v@erwerfen oder Rechnung weiter @b@earbeiten? ( V / B ) ","VB"," ")=="B" ;
          .or. ABBRUCH
          okay:=RECHNUNG_EDIT
        else
          okay:=RECHNUNG_QUIT
        endif
        loop
      endif
      okay:=RECHNUNG_OKAY

      // Kostenvoranschlag wandeln in AB (bei 1. Rechnung)
      if AUFAUS->Aufart=="V"

        do while empty(AUFAUS->BestNr)
          setcolor(COLWIN)
          Fenster(16,16,18,57)
          Message("Bestell-Nummer bitte eingeben.")
          @ 17,18 say "Best-Nr.:" get AUFAUS->BestNr valid {|| len(trim((AUFAUS->BestNr)))>3 }
          read
          setcolor(COLNOR)

          if ABBRUCH
            if Message("Eingabe abbrechen?  @Z@ur�ck zur Rechnung oder @f@ortfahren? (@Z@/@F@)","ZF"," ");
              == "Z"
              okay:=RECHNUNG_EDIT
              exit
            endif
          endif

        enddo

        if okay == RECHNUNG_EDIT
          loop
        endif

        s01:=savescreen()
        Error("Info: Kostenvoranschlag: "+AUFAUS->AufNr+" wird in AB umgewandelt.",.f.)
        if Message("Bitte best�tigen.  @Z@ur�ck zur Rechnung oder @f@ortfahren? (@Z@/@F@)","ZF"," ");
          == "Z" .or. ABBRUCH
          okay:=RECHNUNG_EDIT
          restscreen(,,,,s01)
          loop
        endif
        restscreen(,,,,s01)
        replace AUFAUS->Aufart with "R"
        replace AUFAUS->WarKV with "J"
      endif

    enddo

    // bei Abbruch ohne Druck und speichern raus
    if okay == RECHNUNG_QUIT
      dbcommitall()
      unlock all
      loop
    endif

    gedruckt:=.t.

    /*** Posten r�ckschreiben ***/
    do case
    case ART=="K" // K-Lager
      /** nur umbuchen von LageBest auf HonselBest */
      KonsigLSNr=KonsignationsLieferschein()
      KonsigRueckschreiben(KonsigLSNr)

    otherwise

      auf_rech(AUFAUS->Aufart) // schreibe akt. Satz aus Aufaus->Rechaus

      if AUFAUS->ReBeiBlatt <> "N"
        KundenDatenBlatt( Ausgabe , "R" )
      endif

      // Lieferschein wird nicht gedruckt bei Werkzeug, dass bei Miki verbleibt
      if left(AUFAUS->V_KundNr,5) <> MIKI_NR
        Lieferschein()
      endif

      // Info: falls Email, dann Rechnung und Beistellteilliste gemeinsam per Email
      rechnDeckblatt(Ausgabe)
      dateiName:=Rechnung("1") // mit Abbuchen, da 1. Mal
      Rechnung("0",,,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
      // Muss nach Rechnung gedruckt werden, greift auf RECHAUS->Netto zu
      GelangensBescheinigung()
      BeistellTeilListe()

      // Hinweis, Email zu Rechnung erst nach Beistellteilliste, da diese automat. angeh�ngt wird
      if Ausgabe $ "DP" .and. ! empty( dateiName )
        sendEmails( EMAIL_RECHNUNG , dateiName )

        // pr�fe ob Paletten eingegeben -> falls nein email an MW
        if SPEDIT->SpedKz == "J" .and. KUNDEN->PalKto <> "N"

          paletten:=HB_ATokens( getProperty("Miki.palette.artnr","") , ":" )
          SELECT Auftrag
          sum AUFTRAG->gelief to numPaletten for aContains( paletten , alltrim(AUFTRAG->ArtNr))
          if numPaletten == 0
            // H. Weiland per Email informieren
            subject:="Speditionsversand ohne Eingabe Paletten-Anzahl"
            body:="AB-Nr: "+AUFAUS->AufNr +MY_CR+MY_LF
            body+="Kunde: "+AUFAUS->KundNr+" "+AUFAUS->KurzName +MY_CR+MY_LF
            body+="Re.Nr: "+RECHAUS->RechNr+" anbei."+MY_CR+MY_LF

            // EMail an H. Weiland
            email(MAIN_EMAIL,subject,body,dateiName)
          endif
        endif

      endif

      // pr�fe ob noch offene Posten in Auftrag -> dann Warenbegleitschein drucken
      druckeWBS:=.f.
      SELECT Auftrag
      go top
      do while .not. eof() .and. ! druckeWBS
        if AUFTRAG->Menge > AUFTRAG->GeliefGes + AUFTRAG->Gelief .and. AUFTRAG->Gelief > 0 .and.;
          len(alltrim( AUFTRAG->ArtNr )) > FRACHT_LAENGE
          druckeWBS:=.t.
        endif
        skip
      enddo
      if druckeWBS
        Warenbegleitschein(Ausgabe,.t.)
      endif

    endcase

    // pr�fe ob alle Posten der AB komplett geliefert -> dann als erledigt markieren
    // seit 15.6.2016 ohne Fracht/Verpackung zu beachten
    select AufPost
    AUFPOST->(dbseek( M_FreiNr ))
    erledigt:=.t.
    do while ! AUFPOST->(eof()) .and. M_FreiNr == AUFPOST->AufNr .and. erledigt
      if len(alltrim( AUFPOST->ArtNr )) > FRACHT_LAENGE
        erledigt:=(AUFPOST->Menge <= AUFPOST->GeliefGes)
      endif
      skip
    enddo
    select AufAus
    AUFAUS->(dbseek(M_FreiNr))
    if ! AUFAUS->(eof())
      if erledigt .and. .not. AUFAUS->erledigt$"JO"
        if ! rec_lock(5)
          Error(TRY_AGAIN)
        else
          replace AUFAUS->erledigt with "J"
          gedruckt:=.t.
        endif
        dbcommitall()
        unlock all
        Message("Auftrag @"+M_FreiNr+"@ komplett beliefert. Wurde als erledigt markiert.   "+;
          "@Taste@ dr�cken","@")
      endif
    endif

    dbcommitall()
    unlock all

    // drucke AB Beiblatt f�r K-Lager LS, falls AB nicht erledigt
    if ART=="K" .and. AUFAUS->ReBeiBlatt <> "N" .and. AUFAUS->erledigt <> "J" .and. gedruckt
      KundenDatenBlatt( Ausgabe , "A" , .t.)
    endif

    // neu: seit 29.9.19 hier in der loop und nicht erst beim Beenden
    if gedruckt
      AufBestand()
    endif

  enddo

  close data
  set key K_F10 to

RETURN
/* EOP  */


  /* Function Rech_Bauch  ****************************************
  *
  * Eingabe des Rechn.Bauches, Editor-definitionen
  * R�ckgabe:     Taste mit der Editor verlasen wurde
  *
  * Parameter: Art des Rahmenauftrags, falls es ein Abrufauftrag ist, maybe null
  */
STATIC FUNCTION Rech_Bauch(merkArt)
LOCAL aFelder,result,starteBeiRecno
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  set key K_F5 to toggleSprache()
  do while ! ABBRUCH .or. starteBeiRecno==NIL
    aFelder:={}
    select Auftrag

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
    // aKopf[EDIT_NEW_FKT]:={ || Auf_Satz_nach() }
    aKopf[EDIT_EXTRA_FKT]:={ { "S"," @S@uchen ", { || SaRech_Such(aFelder,aKopf)} }}

    aKopf[EDIT_AFTER_MODE_CHANGE]:={ || pruefeRechZuschlaege() }
    // aKopf[EDIT_FKT_IMMER]:={ || MySetKey( K_F6, nil ) }

    aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("AUFAUS","AUFTRAG->Gelief",48) }
    aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
    aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen
    aKopf[EDIT_ZEIGE_ANZAHL]:={ || len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE } // z�hle alle Artikel
    aKopf[EDIT_ERSATZ_ARRAY]:={ || Auf_Text()}

    if AUFAUS->AufArt=="V" // Kostenvoranschlag
      aKopf[EDIT_GESPERRT]:="ZN�AEL"
    else
      aadd(aKopf[EDIT_EXTRA_FKT],{ "M"," @M@enge �bernehmen ", ;
        { || copyMenge(aFelder,aKopf) .and. dispEditorSumme("AUFAUS","AUFTRAG->Gelief",48)}})

      if merkArt="B" // Budget Rahmen-Auftrag
        aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F10)," @F10@=Rahm.AB ", { || budgetRahmAbStatus(.t.,.f.;
          )}})
      endif

      aKopf[EDIT_GESPERRT]:="LZ"
      aadd(aKopf[EDIT_EXTRA_FKT],{ "L","", { || KonsistenzLoesch() } } ) // Kommentare d�rfen gel�scht werden
    endif

    /* Feld-Definitionen */
    // Artikel-Nr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_NAME_GET]:="Fracht"
    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_BEFORE]:={ || RechArtNrVor() }
    aSpalte[EDIT_AFTER]:=;
      { |oGet| ( trim(oGet:Buffer)$"*" .or. check(oGet,"Artikel",.f.)) .and. RechArtNrNach(oGet) }
    aSpalte[EDIT_MESSAGE]:=;
      "Artikel-Nummer eingeben.   @F12@=Hilfe   @F4@=Honsel-Nr.   @ESC@=Ende"
    aSpalte[EDIT_ERSATZ_1]:={ || trim(AUFTRAG->ArtNr) $ "*" }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    if LAND->Sprache==DEUTSCH
      aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=Englisch ", { || toggleSprache() }})

      aSpalte[EDIT_NAME]:="Komm1"
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Text eingeben"
      aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="Komm2"
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Text eingeben"
      aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    else
      aadd(aKopf[EDIT_EXTRA_FKT], { chr(K_F5)," @F5@=Deutsch ", { || toggleSprache() } } )

      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm1,E_Komm1)"
      aSpalte[EDIT_NAME_GET]:="E_Komm1"
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG-> E_Komm1),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_BEFORE]:=;
        {|| len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. MySetKey( K_F8 , {|| copyGTextPosten()}) }
      aSpalte[EDIT_AFTER]:={ || SetKey( K_F8 , NIL) ,.t. }

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm2,E_Komm2)"
      aSpalte[EDIT_NAME_GET]:="E_Komm2"
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG->E_Komm2),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_BEFORE]:=;
        {|| len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. MySetKey( K_F8 , {|| copyGTextPosten()}) }
      aSpalte[EDIT_AFTER]:={ || SetKey( K_F8 , NIL) ,.t. }

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Menge
    aSpalte[EDIT_NAME]:="Menge-Geliefges"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MASKE]:="9999999.99"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Geliefert
    aSpalte[EDIT_NAME]:="Gelief"
    aSpalte[EDIT_MASKE]:="9999999.99"
    aSpalte[EDIT_MESSAGE]:="Lieferung eingeben."
    aSpalte[EDIT_BS_AUSGABE]:=.t.
    aSpalte[EDIT_AFTER]:={ |oGet| RechFreiMenge(oGet) }
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Mengeinheit
    aSpalte[EDIT_NAME]:="right(space(3)+trim(getTransField('EINHEIT->Text')),3)"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Preis
    aSpalte[EDIT_NAME]:="Preis"
    aSpalte[EDIT_TITEL]:="Preis"
    aSpalte[EDIT_MESSAGE]:="Preis (Euro) eingeben."
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }
    aSpalte[EDIT_AFTER]:={ |oGet| PreisNach(oGet,merkArt) .and. checkePhoenixFracht(oGet)}

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    // Rabatt
    aSpalte[EDIT_NAME]:="Rabatt"
    aSpalte[EDIT_TITEL]:="Rabatt"
    aSpalte[EDIT_POS_X]:=1
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // GerateNr von
    aSpalte[EDIT_NAME]:="GerVon"
    aSpalte[EDIT_MESSAGE]:="Ger�te-Nummer @von@ eingeben."
    aSpalte[EDIT_POS_X]:=-6
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MASKE]:="@9"
    aSpalte[EDIT_BEFORE]:={ || left(AUFTRAG->ArtNr,3)$"503/504" }
    aSpalte[EDIT_AFTER]:={ |oGet| GerVon_Nach(oGet) }
    aSpalte[EDIT_AUSGABE]:=.t.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // GerateNr bis
    aSpalte[EDIT_NAME]:="GerBis"
    aSpalte[EDIT_MESSAGE]:="Ger�te-Nummer @bis@ eingeben."
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_POS_X]:=3
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    // aSpalte[EDIT_BEFORE]:={ || left(AUFTRAG->ArtNr,3)$"503/504" }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Kalenderwoche
    aSpalte[EDIT_NAME]:="Kw"
    aSpalte[EDIT_TITEL]:="Woche"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    /**** ENDE Feld-Definitionen ***/
    result:=Edit(aFelder,aKopf)
    starteBeiRecno:=AUFTRAG->(recno())
  enddo
  set key K_F5 to

RETURN( result )
/* EOF RechBauch */



/*
* wird vor Eingabe der ArtikelNummer ausgef�hrt
* nur Artikel mit len(alltrim(ArtNr)) <= FRACHT_LAENGE und Beistellteile
*/
static FUNCTION RechArtNrVor()
LOCAL aktSel:=Alias()
LOCAL result:=.f.

  // /* mit F5 hinzuf�gen von Beistellteilen m�glich - 4.12.17 */
  // SetKey( K_F6, {|| addBeistellteile()} )

  // Fracht/Versand geht immer
  if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
    return .t.
  endif

  // Beistellteile vorhandener Artikel sind erlaubt
  result:=left(AUFTRAG->TempStr,1) $ "B"

return result
/* eof */


/* wird nach Eingabe der ArtikelNummer ausgef�hrt
* nur Artikel mit len(alltrim(ArtNr)) <= FRACHT_LAENGE
*/
static FUNCTION RechArtNrNach(oGet)
LOCAL paletten, isTeil:=.f.

  if isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and. AUFAUS->ZollZuschl == "J"
    if getUser():id <> KURZEL_MIKI_GF .and. getUser():id <> KURZEL_DEVEL
      Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.")
      return .f.
    endif

    if M->zollManuell .or. ;
      Message("Zoll-Zuschl�ge bei dieser Rechnung manuell bearbeiten? (@J@/@N@)","JN","N")=="J"
      M->zollManuell:=.t.
      // continue!
    else
      return .f.
    endif
  endif

  if oGet:changed

    // nur Eingabe Beistellteile & Fracht
    if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE

      // Teil aus St�ckliste (rekursiv) ist erlaubt
      isTeil:=isAllowedTeil()
      if ! isTeil
        Error(ACHTUNG+"hier nur Eingabe von Fracht oder enthaltenen Beistellteilen m�glich.",.t.)
        RETURN(.f.)
      endif

    else // Fracht �ndern nicht mehr m�glich 2018115, nur noch neu-Eingabe

      if AUFTRAG->ABPostNr <> 0
        Error(ACHTUNG+"�ndern der Fracht- & Verpackungsartikel nicht m�glich.||"+;
          "         Bitte einen neuen Datensatz erfassen (Taste N).")
        RETURN(.f.)
      endif
    endif

    replace AUFTRAG->AufNr WITH AUFAUS->AufNr

    if trim(oGet:Buffer)$"*"

      if ! trim(oGet:original)$"*"
        REPLACE AUFTRAG->komm1 WITH ""
        REPLACE AUFTRAG->komm2 WITH ""
        REPLACE AUFTRAG->E_komm1 WITH ""
        REPLACE AUFTRAG->E_komm2 WITH ""
      endif
    else // Fracht & Verpackung
      if ! isTeil .and. isPhoenixAuftrag()
        Error(ACHTUNG+"Ph�nix Artikel enthalten bereits Fracht & Verpackung.",.t.)
        RETURN(.f.) // seit 14.4.15 erlaubt, seit 9.3.2016 wieder verboten

        // if isPhoenixPauschaleArtikel(AUFTRAG->ArtNr)
        // Error(ACHTUNG+"Artikel: " + AUFTRAG->ArtNr + " kann nur automatisch hinzugef�gt werden.|"+
        // "         Bitte Taste F4 oder anderen Fracht-Artikel verwenden.")
        // return .f.
        // endif
      endif

      replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
      replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
      replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
      replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2

      // Preis nur �bernehmen, falls dieser berechnet wird
      // keine Berechnung bei Ph�nixauftr�gen, VPE enth�lt bereits Verpackung
      // keine Berechnung bei innerdeutschen Paletten Lieferung (seit 7.3.2016)
      paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
      if (((len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
        (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J")) ;
        .and. ! ( AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))))

        replace AUFTRAG->Preis WITH ARTIKEL->Preis1
      endif

      if isTeil
        replace AUFTRAG->Preis WITH ARTIKEL->Preis1
        replace AUFTRAG->TempStr WITH "B"
      else
        replace AUFTRAG->TempStr WITH ""
      endif

      replace AUFTRAG->Me WITH ARTIKEL->ME
      replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
      replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
      replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
      select Erl_Grup
      seek AUFTRAG->Erl_Gruppe
      if .not. eof()
        DO CASE
        CASE AUFAUS->MWST_KZ="1"
          replace AUFTRAG->Erl_Konto WITH ERL_GRUP->Inland
          replace AUFTRAG->Erl_Kz WITH "In"
        CASE AUFAUS->EG=="J"
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
  endif

  // Beistellteile Key wieder aus
  // SetKey( K_F6, nil )

RETURN(.t.)
/* EOF Rech_Nach */

/* Function GerVon_nach  **********************************
*
* wird nach Eingabe der GerVon Nummer ausgef�hrt
*/
FUNCTION GerVon_nach(oGet)
  // if oGet:changed
  if empty(oGet:Buffer)
    Replace AUFTRAG->GerBis with ""
    if lastkey()==K_RETURN
      if Message("Ger�te-Nummer leer? (@J@/@N@)","JN","N")<>"J"
        return .f.
      endif
    endif
  else
    Replace AUFTRAG->GerBis with alltrim(str(val(oGet:Buffer)+AUFTRAG->Gelief-1,5))
  endif
  // endif
RETURN(.t.)
/* EOF GerVon_Nach */


/*
* kopiert den Auftragskopf nach Rechaus, vergibt neue Rech.Nr.
* kopiert die Posten aus Auftrag -> RechPost
*
* Parameter:    Rechart:  "G"   Gutschrift
*                         "R"   Rechnung
*                         "A"   Ausfallmuster (obsolete)
*                         "Q"   Sammel-Rechnung Repa (obsolete)
*                         "K"   Sammel-Rechnung K-Lager
*                         "N"   Gutschrift K-Lager
*                         "M"   Gutschrift K-Lager - Storno
*
*/
PROCEDURE Auf_Rech(RechArt)
LOCAL RechNr:=hole("RechNr",WRITE,.t.)
LOCAL GetList:={}

  if RechArt$"GN"
    Message("Gutschrift @"+RechNr+"@ wird gedruckt.   Bitte warten...")
  else
    Message("Rechnung: @"+RechNr+"@ wird gedruckt.   Bitte warten...")
  endif

  select Rechaus
  seek RechNr
  do while ! eof()
    Error("Rechnungs"+NUMMER_DOPPELT)
    Message("Suche n�chste freie Rechnungs-Nummer.  Bitte warten...")
    RechNr:=hole("RechNr",WRITE,.t.)
    seek RechNr
  enddo

  if RechArt=="K" // Konsig
    Auf_Ko_KRech(RechNr,RechArt)
  else
    Auf_Ko_Rech(RechNr,RechArt)
  endif

  aufPostRechPost(RechArt)


RETURN
/* EOP Auf_Rech */

/*
* Markieren einzelner Auftr�ge als erledigt
*/
PROCEDURE Auf_Erledigt(Filter_AufArt)
LOCAL Taste:=0 , M_AufNr , ant:="N" , count:=0
LOCAL GetList:={} , ende:=.f. , text, merkArt //, innerKom
MEMVAR defAuftrArt,istAbrufAuftrag,filterAufArt
PRIVATE defAuftrArt:=" ",istAbrufAuftrag,filterAufArt

  M->istAbrufAuftrag:=NIL // hier nicht anders m�glich

  if ! open("AufAus","AufPost" , "Einheit" ,"Auftrag","Artikel","AvPost","Spedit","Konsig",;
    "VersArt","Abruf","Inner","BesAus","BesPost","Land","Liefaus")
    close data
    Error(TRY_AGAIN)
    cls
    RETURN
  endif

  /* Relationen setzen */
  SELECT Auftrag
  SET RELATION To AUFTRAG->ArtNr INTO ARTIKEL, TO AUFTRAG->ME INTO Einheit

  // select Auftrag
  select AufAus
  if Filter_AufArt<>NIL
    M->filterAufArt:=Filter_AufArt // needed so filter can be evaluated in sub-routines
    set filter to AUFAUS->AufArt $ M->FilterAufArt
  endif

  do while ! ende
    cls
    Titel("Auftr�ge / Gutschrift  erledigt")
    M_AufNr:=space(len(AUFAUS->AufNr))
    Message("Auftragsnummer eingeben.           @F12@=Hilfe")
    @ 2,1 say 'Auftrag Nr.:'
    @ 2,14 get M_AufNr picture '@K #####';
      valid { |oGet| shift(oGet) .and. check(oGet,"AufAus",.f.,.f.) }
    read
    if ABBRUCH
      ende:=.t.
      loop
    endif

    select AufAus
    seek M_AufNr
    if eof()
      Error(ACHTUNG+"Auftrag nicht vorhanden !")
      loop
    endif
    if AUFAUS->InvKz=="J"
      AUFPOST->(dbseek(AUFAUS->AufNr))
      if ! AUFPOST->(eof())
        Error(ACHTUNG+" Inventur Auftrag kann nicht gel�scht werden!")
        loop
      endif
    endif

    SELECT AufPost
    SEEK M_AufNr

    M->defAuftrArt:=AUFAUS->AufArt

    @ 5,0 clear
    Auf_Kopf_disp()
    Auf_Kopf(2) // auftrag anzeigen
    ////dispABStatus()
    Message("Taste dr�cken.","@")
    // if ABBRUCH
    // loop
    // endif

    if ! empty(AUFAUS->Ab_AufNr)
      merkArt:=getRahmABArt()
    endif

    // kopiere Posten
    select Auftrag
    zap

    AUFPOST->(dbseek(AUFAUS->AufNr))
    if ! append("AufPost", { || AUFPOST->AufNr==AUFAUS->AufNr } )
      Error("Keine Posten vorhanden.",.t.)
      loop
    endif

    Auf_Bauch(merkArt,.t.) // view only
    // Auf_post_anzeig()
    @ 1+1,14 say AUFAUS->AufNr
    //dispABStatus()

    text:=if(AUFAUS->AufArt=="G","Gutschrift","Auftrag")

    switch AUFAUS->erledigt
    case "J" // erledigt
      ant:=Message(text+" @w@iederherstellen oder @o@ffen   @ESC@=Abbruch  (@W@/@O@/@ESC@) ","WO")
      exit
    case "O" // offen
      ant:=Message(text+;
        " @w@iederherstellen oder @e@rledigt  @ESC@=Abbruch  (@W@/@E@/@ESC@) ","WE")
      exit
    otherwise // "neu"
      ant:=Message(text+" @e@rledigt oder @o@ffen @ESC@=Abbruch  (@E@/@O@/@ESC@) ","EO")
    endswitch
    if ABBRUCH
      loop
    endif

    switch ant
    case "W" // Auftrag war als erledigt markiert - r�ckg�ngig machen
      if AUFAUS->erledigt $ "JO"
        aufRecall()

        SELECT Liefaus
        LIEFAUS->(dbseek(AUFAUS->AufNr))
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        replace LIEFAUS->erledigt with " "
        dbcommit()
        dbunlock()

        count++
      endif
      exit
    case "E" // Auftrag wird als erledigt markiert
      SELECT Aufaus
      rec_lock(0)
      replace AUFAUS->erledigt with "J"
      dbcommit()
      dbunlock()
      //dispABStatus()

      SELECT Liefaus
      LIEFAUS->(dbseek(AUFAUS->AufNr))
      rec_lock(0)
      replace LIEFAUS->erledigt with "J"
      dbcommit()
      dbunlock()

      // seit 10.7.19 auch innerbetr. Auftr�ge als erledigt deklarieren
      // Message("Innerbetriebliche Auftr�ge werden gesucht.   Bitte warten...")
      // select Inner
      // Protokoll(INIT_P,"AB: " + AUFAUS->AufNr + " wurde als erledigt markiert.",;
      // "Bitte folgende innerbetrieblichen Auftr�ge von der Tafel entfernen:"+space(7))

      // INNER->(OrdSetFocus(4)) // aufNr
      // INNER->(dbseek(AUFAUS->AufNr))
      // innerKom:=""
      // do while ! INNER->(eof()) .and. INNER->AufNr == AUFAUS->AufNr
      // rec_lock(0)
      // replace INNER->erledigt with "J"
      // innerKom += " " + INNER->InnerNr
      // ARTIKEL->(dbseek(INNER->ArtNr))
      // EINHEIT->(dbseek(ARTIKEL->ME))
      // Protokoll(PROTOKOLL, INNER->InnerNr+space(1)+INNER->ArtNr+space(1)+ARTIKEL->Bez1+space(1)+str(INNER->Menge,9,2)+ // space(1)+EINHEIT->Text+"   Fert.KW: " + INNER->Fert_KW)
      // dbcommit()
      // dbunlock()
      // skip
      // enddo
      // Protokoll(PRINT_P)

      // if len(innerKom) > 0
      // Error("INFO: "+text+": "+AUFAUS->AufNr+" als erledigt markiert.||"+;
      // "      Folgende innerbetr. Auftr�ge ebenso:|"+;
      // "      " + alltrim(innerKom)+"||"+;
      // "      Liste wurde gedruckt.", .t.)
      // else
      Error("INFO: "+text+": "+AUFAUS->AufNr+" als erledigt markiert.",.t.)
      //endif
      count++
      exit
    case "O" // Auftrag wird als offen markiert
      // K-Lager oder Rahmen-ABs k�nnen nicht als offen deklariert werden
      if AUFAUS->AufArt <> "R"
        Error("Nur normale ABs k�nnen als offen deklariert werden.")
      else
        SELECT Aufaus
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        replace AUFAUS->erledigt with "O"
        dbcommit()
        dbunlock()
        //dispABStatus()

        SELECT Liefaus
        LIEFAUS->(dbseek(AUFAUS->AufNr))
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        replace LIEFAUS->erledigt with "O"
        dbcommit()
        dbunlock()

        Error("INFO: "+text+": "+AUFAUS->AufNr+" als offen markiert.",.t.)
        count++
      endif
      exit
    endswitch

  enddo

  /* Auftrags-Bestand neu kalkulieren */
  if count > 0
    select AufAus
    set filter to
    close data
    AufBestand()
  endif

  cls
  close data

RETURN
/* EOP Auf_Erledigt */



/* Procedure Auf_Ko_Rech
*
* erzeugt Rechnungs-Kopf aus Aufaus
*
*/
STATIC PROCEDURE Auf_Ko_Rech(RechNr,RechArt)

  /* Auftrags-Kopf  ->  Rechaus */
  ADD_REC(0)
  overwrite("Aufaus",.t.)
  replace RECHAUS->RechNr WITH RechNr
  replace RECHAUS->ReaDat WITH getUser():date
  replace RECHAUS->Aufart WITH RechArt

  // Mahnstufe & F�lligkeit setzen
  if ! Rechart $ "GS" // nicht bei Gutschrift oder Storno
    setDuedate()
  endif

  // hier kein unlock ! , da nach Druck noch Nebenkosten etc. nachgetragen werden !

RETURN
/* EOP Auf_Ko_Rech */

/* Procedure Auf_Ko_KRech
*
* erzeugt Rechnungs-Kopf aus Aufaus f�r K-Lager Sammelrechnung
* Alle 3 Anschriften sind identisch!
*
*/
STATIC PROCEDURE Auf_Ko_KRech(RechNr,RechArt)

  /* Auftrags-Kopf  ->  Rechaus */
  ADD_REC(0)
  overwrite("Aufaus",.t.)
  replace RECHAUS->RechNr WITH RechNr
  replace RECHAUS->ReaDat WITH getUser():date
  replace RECHAUS->Aufart WITH RechArt

  // neu 20200706: �bernehme aktuelle MwSt aus MwSt Stammdaten
  MWST_KZ->(dbseek(AUFAUS->Mwst_kZ)) // FIXME: unsch�n aber erstmal ok?!
  if RECHAUS->MwSt <> MWST_KZ->MwSt
    replace RECHAUS->MwSt WITH MWST_KZ->MwSt
  endif

  // Mahnstufe & F�lligkeit setzen
  setDuedate()

  // hier kein unlock ! , da nach Druck noch Nebenkosten etc. nachgetragen werden !

RETURN
/* EOP Auf_Ko_KRech */


/** Kopiert alle Posten aus Auftrag.dbf nach RechPost */
// FIXME: clean me up!!!
static procedure aufPostRechPost(RechArt)
LOCAL Merk_Order
LOCAL aktRec:=ARTIKEL->(recno())

  /*** �bernahme -> RECHPOST.DBF ***/
  SELECT Auftrag
  go top
  do while .not. eof()

    /* Gutschrift gleich geliefert */
    if RechArt$"NG"
      replace AUFTRAG->gelief with AUFTRAG->Menge
    endif

    // ignoriere Artikel mit gelieferter 0 Menge
    if AUFTRAG->Gelief == 0 .and. ! trim(AUFTRAG->ArtNr)=="*"
      skip
      loop
    endif

    /* r�ckschreiben Lieferung -> Auftrags-Posten */
    // if ! Rechart $ "QAK" // kein Ausfallmuster,Sammelrechnung(repa)

    if ! Rechart $ "GNQAK"

      SELECT AufPost
      Merk_Order:=AUFPOST->(IndexOrd())

      // neu seit 7.5.2010
      // jetzt ohne add_rec, 22.2.2012
      if ! empty(AUFTRAG->ABPostNr) // nicht bei hinzugef�gten!!!

        // suche zugeh. Auftragposten
        AUFPOST->(OrdSetFocus(5)) // ABPostNr
        dbseek(AUFTRAG->ABPostNr)

        if AUFPOST->(eof())
          if RECHAUS->Aufart=="S" // bei Storno-Rechnung nicht okay!
            Error(ACHTUNG+"Auftragsposten: "+RECHAUS->AbPostNr+" nicht gefunden."+SCHWERER_FEHLER )
          else
            // nop, das ist ok, Posten ist neu, ge�ndert am 28.6.12
            // Error(ACHTUNG+"Artikel konnte in AB:@"+AUFTRAG->ABPostNr+"@ nicht abgetragen werden!"+
            // SCHWERER_FEHLER)
          endif
        else
          if RECHAUS->WarKV <> "J" .or. AUFPOST->Menge > AUFPOST->GeliefGes // seit 20180712, 20190909 nicht mehr bei KV!
            if rec_lock(0)
              // Liefermenge anpassen
              REPLACE AUFPOST->GeliefGes WITH AUFPOST->GeliefGes + AUFTRAG->Gelief
              REPLACE AUFPOST->Gelief WITH 0
              dbcommit()
              dbunlock()
            else
              Error(ACHTUNG+"Artikel konnte in AB nicht abgetragen werden!"+SCHWERER_FEHLER)
            endif
          endif
        endif
        AUFPOST->(OrdSetFocus(Merk_Order))

      endif

      select auftrag

    endif

    // rueckschreiben nach Rechpost

    // K-Lager Rechnungsposten je Konsig-Auftrag
    if RechArt=="K"
      if AUFTRAG->Gelief > 0
        select Konsig
        KONSIG->(OrdSetFocus(3)) // KundNr+Art.Nr
        KONSIG->(dbseek(RECHAUS->KundNr+AUFTRAG->ArtNr))

        if KONSIG->(eof())
          // d�rfte nie passieren
          Error(ACHTUNG+" Konsig Datei konnte nicht abgetragen werden.",.t.)
          email(MY_EMAIL," Konsig Datei konnte nicht abgetragen werden."+RECHAUS->KundNr+;
            AUFTRAG->ArtNr)
        endif

        // suche naechsten offenen Auftrag des Kundens/Artikels
        do while ! KONSIG->(eof()) .and. KONSIG->KundNr==RECHAUS->KundNr .and.;
          KONSIG->ArtNr==AUFTRAG->ArtNr .and. AUFTRAG->Gelief>0
          if KONSIG->Berechnet < KONSIG->GeliefGes
            assignKonsig(Min(KONSIG->GeliefGes-KONSIG->Berechnet,AUFTRAG->Gelief))
          endif
          dbskip()
        enddo
        select Auftrag
        if AUFTRAG->Gelief > 0
          // Ausnahme Inventur-Auftrag: lege neue Konsig Eintrag an
          if AUFAUS->InvKZ=="J"
            /** neuen Posten in Konsig wieder als nicht berechnet markieren */
            select Konsig
            add_rec(0)
            replace KONSIG->AufNr with AUFAUS->AufNr
            replace KONSIG->KundNr with AUFAUS->KundNr
            // replace KONSIG->LiefNr with KonsigLSNr
            replace KONSIG->Liedat with getUser():date
            replace KONSIG->ArtNr with AUFTRAG->ArtNr
            replace KONSIG->Komm1 with AUFTRAG->Komm1
            replace KONSIG->Komm2 with AUFTRAG->Komm2
            replace KONSIG->Menge with AUFTRAG->Gelief
            replace KONSIG->Preis with AUFTRAG->Preis
            replace KONSIG->Rabattgr with AUFTRAG->Rabattgr
            replace KONSIG->Rabatt with AUFTRAG->Rabatt
            replace KONSIG->KZ with AUFTRAG->KZ
            replace KONSIG->ME with AUFTRAG->ME
            replace KONSIG->PE with AUFTRAG->PE
            replace KONSIG->KW with AUFTRAG->KW
            REPLACE KONSIG->GeliefGes WITH AUFTRAG->Gelief
            REPLACE KONSIG->Erl_Gruppe With AUFTRAG->Erl_Gruppe
            REPLACE KONSIG->Erl_Konto With AUFTRAG->Erl_Konto
            REPLACE KONSIG->Erl_Kz With AUFTRAG->Erl_Kz
            REPLACE KONSIG->GerVon With AUFTRAG->GerVon
            REPLACE KONSIG->GerBis With AUFTRAG->GerBis
            REPLACE KONSIG->AbPostNr With AUFTRAG->AbPostNr
            assignKonsig(AUFTRAG->Gelief)
            select Auftrag
          else
            Error(ACHTUNG+" Artikel:"+AUFTRAG->ArtNr+" konnte nicht berechnet werden.|          "+;
              "Rest-Menge in AB:"+ str(AUFTRAG->gelief),.t.)
            trouble("Klager"," Artikel:"+AUFTRAG->ArtNr+" konnte nicht berechnet werden.|         "+;
              " Rest-Menge in AB:"+ str(AUFTRAG->gelief),.t.)
          endif
        endif

      elseif AUFTRAG->gelief < 0 // nur K-Lager Inventurrechnung

        // schreibe RECHPOST Eintrag
        SELECT RechPost
        ADD_REC(0)
        REPLACE RECHPOST->AufNr WITH RECHAUS->AufNr
        REPLACE RECHPOST->Kundnr WITH RECHAUS->KundNr
        REPLACE RECHPOST->RechNr WITH RECHAUS->RechNr
        REPLACE RECHPOST->ReaDat WITH getUser():date
        REPLACE RECHPOST->ArtNr With AUFTRAG->ArtNr
        REPLACE RECHPOST->Komm1 With AUFTRAG->Komm1
        REPLACE RECHPOST->Komm2 With AUFTRAG->Komm2
        REPLACE RECHPOST->E_Komm1 With AUFTRAG->E_Komm1
        REPLACE RECHPOST->E_Komm2 With AUFTRAG->E_Komm2
        REPLACE RECHPOST->AbPostNr WITH AUFTRAG->ABPostNr
        REPLACE RECHPOST->Menge With AUFTRAG->Menge
        REPLACE RECHPOST->RabattGr With AUFTRAG->RabattGr
        REPLACE RECHPOST->Rabatt With AUFTRAG->Rabatt
        REPLACE RECHPOST->Erl_Gruppe With AUFTRAG->Erl_Gruppe
        REPLACE RECHPOST->Erl_Konto With AUFTRAG->Erl_Konto
        REPLACE RECHPOST->Erl_Kz With AUFTRAG->Erl_Kz
        REPLACE RECHPOST->KZ WITH AUFTRAG->KZ
        REPLACE RECHPOST->Kw WITH AUFTRAG->Kw
        REPLACE RECHPOST->Kw_Text WITH AUFTRAG->Kw_Text
        REPLACE RECHPOST->Me WITH AUFTRAG->Me
        REPLACE RECHPOST->PE WITH AUFTRAG->PE
        REPLACE RECHPOST->Preis With AUFTRAG->Preis
        REPLACE RECHPOST->gelief WITH AUFTRAG->Gelief
        REPLACE RECHPOST->GeliefGes WITH AUFTRAG->Geliefges
        REPLACE RECHPOST->GerVon WITH AUFTRAG->GerVon
        REPLACE RECHPOST->GerBis WITH AUFTRAG->GerBis
        REPLACE RECHPOST->LiefNr WITH KONSIG->LiefNr

        // added 20171119
        replace RECHPOST->Inhalt with AUFTRAG->Inhalt
        replace RECHPOST->InhaltME with AUFTRAG->InhaltME

        dbcommit()
        unlock

        /** neuen Posten in Konsig wieder als nicht berechnet markieren */
        select Konsig
        add_rec(0)
        replace KONSIG->AufNr with AUFAUS->AufNr
        replace KONSIG->KundNr with AUFAUS->KundNr
        // replace KONSIG->LiefNr with KonsigLSNr
        replace KONSIG->Liedat with getUser():date
        replace KONSIG->ArtNr with AUFTRAG->ArtNr
        replace KONSIG->Komm1 with AUFTRAG->Komm1
        replace KONSIG->Komm2 with AUFTRAG->Komm2
        replace KONSIG->Menge with abs( AUFTRAG->Menge )
        replace KONSIG->Preis with AUFTRAG->Preis
        replace KONSIG->Rabattgr with AUFTRAG->Rabattgr
        replace KONSIG->Rabatt with AUFTRAG->Rabatt
        replace KONSIG->KZ with AUFTRAG->KZ
        replace KONSIG->ME with AUFTRAG->ME
        replace KONSIG->PE with AUFTRAG->PE
        replace KONSIG->KW with AUFTRAG->KW
        REPLACE KONSIG->GeliefGes WITH abs( AUFTRAG->Gelief )
        REPLACE KONSIG->Erl_Gruppe With AUFTRAG->Erl_Gruppe
        REPLACE KONSIG->Erl_Konto With AUFTRAG->Erl_Konto
        REPLACE KONSIG->Erl_Kz With AUFTRAG->Erl_Kz
        REPLACE KONSIG->GerVon With AUFTRAG->GerVon
        REPLACE KONSIG->GerBis With AUFTRAG->GerBis
        REPLACE KONSIG->AbPostNr With AUFTRAG->AbPostNr
        dbcommit()
        unlock
        select Auftrag

      endif // gelief>0

    else // Rechart<>K

      // Standard rueckschreiben -> Rechpost
      IF AUFTRAG->gelief<>0 .or. trim(AUFTRAG->ArtNr)=="*"
        SELECT RechPost
        ADD_REC(0)
        REPLACE RECHPOST->AufNr WITH AUFTRAG->AufNr
        REPLACE RECHPOST->Kundnr WITH RECHAUS->KundNr
        REPLACE RECHPOST->RechNr WITH RECHAUS->RechNr
        REPLACE RECHPOST->ReaDat WITH getUser():date
        REPLACE RECHPOST->ArtNr With AUFTRAG->ArtNr
        REPLACE RECHPOST->Komm1 With AUFTRAG->Komm1
        REPLACE RECHPOST->Komm2 With AUFTRAG->Komm2
        REPLACE RECHPOST->E_Komm1 With AUFTRAG->E_Komm1
        REPLACE RECHPOST->E_Komm2 With AUFTRAG->E_Komm2
        REPLACE RECHPOST->AbPostNr WITH AUFTRAG->ABPostNr
        REPLACE RECHPOST->Menge With AUFTRAG->Menge * if(Rechart$"GN",(-1),1)
        // if ! RechArt=="A" // Ausfallmuster OHNE Preis
        REPLACE RECHPOST->Preis With AUFTRAG->Preis
        // endif
        REPLACE RECHPOST->RabattGr With AUFTRAG->RabattGr
        REPLACE RECHPOST->Rabatt With AUFTRAG->Rabatt
        REPLACE RECHPOST->Erl_Gruppe With AUFTRAG->Erl_Gruppe
        REPLACE RECHPOST->Erl_Konto With AUFTRAG->Erl_Konto
        REPLACE RECHPOST->Erl_Kz With AUFTRAG->Erl_Kz
        REPLACE RECHPOST->KZ WITH AUFTRAG->KZ
        // if Rechart=="A" // ausfallmuster
        // REPLACE RECHPOST->gelief WITH 0
        // REPLACE RECHPOST->GeliefGes WITH 0
        // else
        if AUFAUS->AufArt == "V" // KV ist bereits abgebucht
          REPLACE RECHPOST->gelief WITH AUFTRAG->Menge
          REPLACE RECHPOST->GeliefGes WITH RECHPOST->Gelief
        else
          REPLACE RECHPOST->gelief WITH AUFTRAG->Gelief * if(Rechart$"NG",(-1),1)
          REPLACE RECHPOST->GeliefGes WITH RECHPOST->Gelief
        endif
        // ge�ndert am 2.12.2009
        // REPLACE RECHPOST->GeliefGes WITH AUFTRAG->Geliefges+AUFTRAG->Gelief
        // endif
        REPLACE RECHPOST->Kw WITH AUFTRAG->Kw
        REPLACE RECHPOST->Kw_Text WITH AUFTRAG->Kw_Text
        REPLACE RECHPOST->Me WITH AUFTRAG->Me
        REPLACE RECHPOST->PE WITH AUFTRAG->PE
        REPLACE RECHPOST->GerVon WITH AUFTRAG->GerVon
        REPLACE RECHPOST->GerBis WITH AUFTRAG->GerBis

        // added 20171119
        replace RECHPOST->Inhalt with AUFTRAG->Inhalt
        replace RECHPOST->InhaltME with AUFTRAG->InhaltME

        dbcommit()
        unlock

      endif // Rechart="K"

      select Auftrag

    endif
    skip
  enddo
return
/** eop */

procedure assignKonsig(menge)
LOCAL aktSel:=alias()

  if REC_LOCK(0)
    REPLACE KONSIG->Berechnet WITH KONSIG->Berechnet+menge
    replace AUFTRAG->Gelief with AUFTRAG->Gelief-menge
  endif
  dbcommit()
  dbunlock()

  // schreibe RECHPOST Eintrag je Konsig Auftrag
  SELECT RechPost
  ADD_REC(0)
  REPLACE RECHPOST->AufNr WITH KONSIG->AufNr
  REPLACE RECHPOST->Kundnr WITH RECHAUS->KundNr
  REPLACE RECHPOST->RechNr WITH RECHAUS->RechNr
  REPLACE RECHPOST->ReaDat WITH getUser():date
  REPLACE RECHPOST->ArtNr With AUFTRAG->ArtNr
  REPLACE RECHPOST->Komm1 With AUFTRAG->Komm1
  REPLACE RECHPOST->Komm2 With AUFTRAG->Komm2
  REPLACE RECHPOST->E_Komm1 With AUFTRAG->E_Komm1
  REPLACE RECHPOST->E_Komm2 With AUFTRAG->E_Komm2
  REPLACE RECHPOST->AbPostNr WITH AUFTRAG->ABPostNr
  REPLACE RECHPOST->Menge With AUFTRAG->Menge
  REPLACE RECHPOST->RabattGr With AUFTRAG->RabattGr
  REPLACE RECHPOST->Rabatt With AUFTRAG->Rabatt
  REPLACE RECHPOST->Erl_Gruppe With AUFTRAG->Erl_Gruppe
  REPLACE RECHPOST->Erl_Konto With AUFTRAG->Erl_Konto
  REPLACE RECHPOST->Erl_Kz With AUFTRAG->Erl_Kz
  REPLACE RECHPOST->KZ WITH AUFTRAG->KZ
  REPLACE RECHPOST->Kw WITH AUFTRAG->Kw
  REPLACE RECHPOST->Kw_Text WITH AUFTRAG->Kw_Text
  REPLACE RECHPOST->Me WITH AUFTRAG->Me
  REPLACE RECHPOST->PE WITH AUFTRAG->PE
  REPLACE RECHPOST->Preis With AUFTRAG->Preis
  REPLACE RECHPOST->gelief WITH menge
  REPLACE RECHPOST->GeliefGes WITH AUFTRAG->Geliefges+menge
  REPLACE RECHPOST->GerVon WITH AUFTRAG->GerVon
  REPLACE RECHPOST->GerBis WITH AUFTRAG->GerBis
  REPLACE RECHPOST->LiefNr WITH KONSIG->LiefNr

  // added 20171119
  replace RECHPOST->Inhalt with AUFTRAG->Inhalt
  replace RECHPOST->InhaltME with AUFTRAG->InhaltME

  dbcommit()
  unlock

  select(aktSel)
return

/* Procedure Rech_Druckwieder() ******************************************
*
*  druckt eine alte Rechnung (wiederholen)
*/
PROCEDURE Rech_Druckwieder(Ausgabe,Art)
LOCAL M_RechNr:=".",m1
LOCAL GetList:={}, dateiName, shift:=0, gbsArt, anz_ls:=1

  default Ausgabe:="D"
  default Art:="B" // Beides drucken Re & LS

  cls
  Titel("Rechnung drucken")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! openRechnDateien()
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  select RechPost
  set relation to RECHPOST->ME into Einheit
  select aufaus
  /**  set relation to AUFAUS->textkz_Nr into Text_Kz,to AUFAUS->zknr into zahlkond,to AUFAUS->versNr into versart */
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  do while ! empty(M_RechNr)
    cls
    Titel("Rechnung drucken")
    M_RechNr:=space(len(RECHAUS->RechNr))
    Message("Rechnungsnummer eingeben.           @F12@=Hilfe")
    @ 4,10 say "Rech.Nr.:" get M_RechNr;
      valid { |oGet| shift(oGet) .and. check(oGet,"RechAus",.t.,.f.) }
    read
    if empty(M_RechNr) .or. lastkey()==K_ESC
      loop
    endif

    /* Auswahl-Menu */
    setcolor(COLWIN)
    Fenster(5,16,15,57)
    @ 6,20 say 'Drucken als:'
    do case
    CASE RECHAUS->Aufart$"GN"
      m1='   Gutschrift '+RECHAUS->RechNr
    CASE RECHAUS->Aufart$"M"
      m1='   K-Gutschrift Storno '+RECHAUS->RechNr
      // CASE RECHAUS->Aufart="A"
      // m1=' Ausfallmuster'+RECHAUS->RechNr
    OTHERWISE
      m1='   Rechnung '+RECHAUS->RechNr
    ENDCASE
    @ 8,20 say m1

    Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
    if RECHAUS->AufArt$"GNMSK" // au�er GS, Storno, K-Lager
      shift:=0
      art:="B"
    else
      @ 10,20 say 'Rechnung/Liefersch/Beides (R/L/B)' get art Picture "!" valid Art $"RLB"
      @ 14,20 say 'Anzahl Lieferschein Kopien (0-3)  1'
      shift:=2
    endif
    @ 10 + shift,20 say 'Drucker/Bildschirm/PDF    (D/B/P)' get Ausgabe Picture "!";
      valid Ausgabe $"DBP"
    read

    if lastkey()==K_ESC
      setcolor(COLNOR)
      @ 6,0 clear
      loop
    endif

    if art$"LB" .and. Ausgabe=="D"
      // FIXME: Anz. LS bei Spedit + Paletten = 2
      // if SPEDIT->SpedKz .and. xxx
      // anz_ls:=2
      // else
      // anz_ls:=1
      // endif
      @ 14,20 say 'Anzahl Lieferschein Kopien (0-3) ' get anz_ls picture "9" valid anz_ls <=3
      read
    endif
    setcolor(COLNOR)

    if lastkey()==K_ESC
      @ 6,0 clear
      loop
    endif


    /* Satz locken */
    SELECT RechAus
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      loop
    endif

    AUFAUS->(dbseek(RECHAUS->AufNr))
    do case
    case RECHAUS->AufArt$"GNM"
      rechnDeckblatt(Ausgabe)
      Gutschrift(Ausgabe)
    case RECHAUS->AUfArt $ "RV" // REchnung, + ( Kostenvoranschlag sollte nicht vorkommen)
      if RECHAUS->AUfArt == "R" .and. Ausgabe$"DP" .and. AUFAUS->ReBeiBlatt <> "N" .and. Art $ "RB"
        KundenDatenBlatt( Ausgabe , "R" )
      endif

      if ART $ "LB"
        Lieferschein(Ausgabe, anz_ls + 1)
      endif

      if Art $ "RB"
        rechnDeckblatt(Ausgabe)
        dateiName:=Rechnung("0",,Ausgabe) // ohne Abbuchen !
        if Ausgabe=="D"
          Rechnung("0",,Ausgabe,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
        endif
        BeistellTeilListe(Ausgabe,.f.) // jetzt immer, jojo 28.9.98
      endif

      GBSart:={}
      if Art $ "RB"
        aadd(GBSart, JOB_RECHNUNG)
      endif
      if ART $ "LB"
        aadd(GBSart, JOB_LIEFERSCHEIN)
      endif
      // wird jetzt immer gedruckt
      GelangensBescheinigung(Ausgabe, GBSArt) // Muss nach Rechnung gedruckt werden, greift auf RECHAUS->Netto zu

    case RECHAUS->AUfArt $ "S" // Storno Rechnung

      // Info: bei K-Lager ist (AUFAUS->Aufart=="K") == true
      if Ausgabe$"DP" .and. AUFAUS->ReBeiBlatt <> "N"
        KundenDatenBlatt( Ausgabe , "R" )
      endif

      rechnDeckblatt(Ausgabe)
      dateiName:=Rechnung("0",(AUFAUS->Aufart=="K"),Ausgabe) // ohne Abbuchen !
      if Ausgabe=="D"
        Rechnung("0",(AUFAUS->Aufart=="K"),Ausgabe,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
      endif
      // GelangensBescheinigung(Ausgabe) // Muss nach Rechnung gedruckt werden, greift auf RECHAUS->Netto zu
      BeistellTeilListe(Ausgabe,.f.) // jetzt wieder, 26.5.15

      // case RECHAUS->AUfArt $ "A" // Ausfall-Muster
      // Ausfall(Ausgabe)

    case RECHAUS->AUfArt $ "K" // K-Lager
      // rechnDeckblatt(Ausgabe)
      dateiName:=Rechnung("0",,Ausgabe) // ohne Abbuchen !
      if Ausgabe=="D"
        Rechnung("2",,Ausgabe,.t.) // ohne Abbuchen, mit Posten , Kopie f�r Ablage
        Rechnung("3",,Ausgabe,.t.) // ohne Abbuchen, ohne Posten , Kopie f�r Buchhaltung
      endif
      BeistellTeilListe(Ausgabe,.f.) // jetzt immer, jojo 28.9.98

    otherwise
      if Art $ "RB"
        if Ausgabe$"DP" .and. AUFAUS->ReBeiBlatt <> "N"
          KundenDatenBlatt( Ausgabe , "R" )
        endif
        rechnDeckblatt(Ausgabe)
        dateiName:=Rechnung("0",,Ausgabe) // ohne Abbuchen !
        Rechnung("0",,Ausgabe,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
        BeistellTeilListe(Ausgabe,.f.) // jetzt immer, jojo 28.9.98
      endif
    endcase

    // Hinweis, Email zu Rechnung erst nach Beistellteilliste, da diese automat. angeh�ngt wird
    if Ausgabe $ "DP" .and. ! empty( dateiName )
      sendEmails( EMAIL_RECHNUNG , dateiName )
    endif

  enddo

  close data
RETURN
/* EOP auf_Druckwieder */



/* Function RechFreiMenge  **********************************
*
* wird nach Eingabe der Menge bei Rechnungsfreigabe ausgefuehrt
* keine Ueberlieferung bei K-Lager
*/
FUNCTION RechFreiMenge(oGet)
LOCAL result:=.t.
  if oGet:changed
    if left(AUFTRAG->TempStr,1)=="B" .and. val(oGet:Buffer) > 0
      Error(ACHTUNG+"Fehlende Beistellteile bitte mit Minus eingeben.",.t.)
      return .f.
    endif

    result:=RechFrei2Menge( val( oGet:buffer ))
  endif // oget:changed
RETURN result
/* EOF RechFreiMenge */

/*
* wird nach Eingabe der Menge bei Rechnungsfreigabe ausgefuehrt
* keine Ueberlieferung bei K-Lager
*/
FUNCTION RechFrei2Menge( mMenge )
LOCAL result:=.t.,s01
LOCAL aktKW,aktRec , istNull, paletten

  // gehe auf passenden Artikel
  ARTIKEL->(dbseek(AUFTRAG->ArtNr))

  // NACHKOMMA Stellen erlaubt?
  if AUFTRAG->Gelief-int(AUFTRAG->Gelief) > 0 .and. EINHEIT->Nachkomma == 0
    Error(ACHTUNG+" Nachkommastellen bei ME: "+EINHEIT->Text+" nicht zugelassen.",.t.)
    return .f.
  endif

  if AUFAUS->AufArt=="K"

    // hier kein Storno erlaubt
    if AUFTRAG->gelief<0 .and. getArtikelArt()<>"B"
      Error(ACHTUNG+" K-Lager Storno hier nicht m�glich.|Bitte anderen Menu-Punkt verwenden",.t.)
      return .f.
    endif

    // Fracht darf �berliefert werden
    if LEN(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
      return .t.
    endif

    // ueberliefert?
    if AUFTRAG->Gelief > (AUFTRAG->Menge-AUFTRAG->GeliefGes)
      Error(ACHTUNG+" K-Lager Auftrag kann nicht �berliefert werden.",.t.)
      return .f.
    endif

    // K-Lager Auftrags Max.Menge erreicht?
    // nop


    // genug Artikel auf Lager?
    if AUFTRAG->Gelief > ARTIKEL->LageBest
      result:=Message("Menge �berschreitet MIKI-Bestand (@"+alltrim(str(ARTIKEL->LageBest,11,2))+ ;
        "@).  Trotzdem liefern? ( J / N ) ","JN")=="J"
    endif

  else

    // Ph�nix keine Teilieferung und Fracht Pauschale immer automatisch berechnen
    // FIXME: Ausnahme bei nicht automat. Fracht gew�nscht 20240722
    // .and. ! trim(AUFTRAG->ArtNr)=="4357001" s. email vom 22.7.24
    if (isPhoenixAuftrag()) .and. AUFTRAG->Menge > 0 .and. AUFAUS->PhoenixFr <> "N" // nur bei "alten" Posten

      // immer max. Menge
      if AUFTRAG->Gelief<>0 .and. AUFTRAG->Gelief <> AUFTRAG->Menge-AUFTRAG->GeliefGes
        Error(ACHTUNG+"Posten in Ph�nix Auft�gen k�nnen nur komplett beliefert werden.|"+;
          "         Ansonsten bitte die AB anpassen.")
        replace AUFTRAG->Gelief with AUFTRAG->Menge-AUFTRAG->GeliefGes
      endif

      // zugeh�rige Fracht ebenfalls freigeben
      if ! isPhoenixPauschaleArtikel(AUFTRAG->ArtNr) .or. isZollZuschlagArtikel(AUFTRAG->ArtNr)
        istNull:=(AUFTRAG->Gelief == 0)
        aktKW:=AUFTRAG->KW
        aktRec:=AUFTRAG->(recno())
        go top
        do while ! AUFTRAG->(eof())
          // if AUFTRAG->KW == aktKW
          replace AUFTRAG->Gelief with if(istNull,0,AUFTRAG->Menge-AUFTRAG->GeliefGes)
          // endif
          skip
        enddo
        AUFTRAG->(dbgoto( aktRec ))
      endif
    endif

    // ueberliefert?
    if AUFTRAG->Gelief>(AUFTRAG->Menge-AUFTRAG->GeliefGes) .and.;
      len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE
      s01:=savescreen()
      Error(ACHTUNG+" Posten �berliefert.",ERR_NO_WAIT)
      if Message("Sind Sie sicher ? (@J@/@N@)","JN")<>"J"
        restscreen(,,,,s01)
        return .f.
      endif
      restscreen(,,,,s01)
    endif

  endif // K-Lager Auftrag

  // Ger�teNr anpassen
  if ! empty(AUFTRAG->GerVon) .and. result
    if mMenge == 0
      Replace AUFTRAG->GerBis with ""
      Replace AUFTRAG->GerVon with ""
    else
      Replace AUFTRAG->GerBis with alltrim(str(mMenge+val(AUFTRAG->Gervon)-1,5))
    endif
  endif

  // Hinweis, falls Preis = 0, au�er bei innerdeutschem Palettenversand
  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
  if AUFTRAG->Gelief > 0 .and. AUFTRAG->Preis = 0 ;
    .and. ! ( AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr)))
    s01:=savescreen()
    Error(ACHTUNG+"Preis = 0",ERR_NO_WAIT)
    if Message("Trotzdem fortfahren? (@J@/@N@)","JN")<>"J"
      restscreen(,,,,s01)
      return .f.
    endif
    restscreen(,,,,s01)
  endif

  // Hinweis, bei Werkzeug wird nicht abgebucht
  if AUFTRAG->Gelief > 0 .and. getArtikelArt()=="W"
    Error("Hinweis: Werkzeug Lagerbestand wird nicht automatisch abgetragen.",.t.)
  endif

RETURN result
/* EOF RechFreiMenge */


/** �bernimmt den Posten komplett,
     kopiert die Menge nach Gelief */
static function copyMenge(aFelder,aKopf)
LOCAL result , x

  // Zoll-Zuschlag �ndern erlaubt?
  if isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and. AUFAUS->ZollZuschl == "J"
    if AUFTRAG->Gelief == AUFTRAG->Menge-AUFTRAG->GeliefGes
      return .t.
    endif

    if getUser():id <> KURZEL_MIKI_GF .and. getUser():id <> KURZEL_DEVEL
      Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.")
      return .f.
    endif

    if M->zollManuell .or. ;
      Message("Zoll-Zuschl�ge bei dieser Rechnung manuell bearbeiten? (@J@/@N@)","JN","N")=="J"
      M->zollManuell:=.t.
      // continue!
    else
      return .f.
    endif

  endif

  replace AUFTRAG->Gelief with AUFTRAG->Menge-AUFTRAG->GeliefGes
  result:=RechFrei2Menge( AUFTRAG->Gelief )

  pruefeRechZuschlaege()

  if result

    // Ger�te-Nummer eingeben?
    if left(AUFTRAG->ArtNr,3)$"503/504"
      x:=getColPosByName(aFelder,"GerVon")
      if x==0
        troubleEmail("Feld Ger�te-Nummer nicht gefunden.")
      else
        aKopf[EDIT_GET_OFFSET]:=x
        keyboard "a" // �ndern
      endif
    else
      keyboard chr(K_DOWN)
    endif
  endif
return result

  /** wird nach Eingabe des Preises ausgef�hrt (nur Abrufauftr�ge)
  *
  *
  * Paramater: alwaysShow, if false calculation is only shown when rest<0
  *            isAB: kommt aus Abrufauftrag, andere Auftr�ge m�ssen einbezogen werden
  *                  ansonsten in Rechn.Freigabe, ohne andere ABs
  *            commitErledigt: falls true, werden komplett erledigte Auftr�ge als erledigt markiert
  *
  * Result: true falls das Budget nicht ausreicht
  */
function budgetRahmAbStatus(alwaysShow,isAB,commitErledigt)
LOCAL merkArt:=" ",merkFilter,merkABSatz,merkABNr,merkNetto,merkBez:=0,gwert,ewert,rest:=0,absWert:=0
LOCAL GetList:={},s01,merkSatz
LOCAL text

  default alwaysShow:=.f.
  default isAB:=.f.
  default commitErledigt:=.f.

  s01:=savescreen()

  // Rahmenauftrag?
  if ! empty(AUFAUS->Ab_AufNr)
    merkFilter:=AUFAUS->(dbfilter())
    merkABSatz:=AUFAUS->(recno())
    merkAbNr:=AUFAUS->Ab_AufNr

    select Aufaus
    set filter to
    AUFAUS->(dbseek(merkAbNr))
    if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"B" // .or. AUFAUS->erledigt=="J"
      Error(merkAbNr+" ist kein g�ltiger Rahmenauftrag",.t.)
      set filter to &(merkFilter)
    else
      merkArt:=AUFAUS->Aufart
      merkNetto:=AUFAUS->Netto
      merkbez:=AUFAUS->RahmBez
    endif
    select Auftrag

    if merkArt="B" // Budget Rahmen-Auftrag

      Message("Budget wird berechnet.   Bitte warten...")

      merkSatz:=AUFTRAG->(recno())

      // summiere andere Posten der akt. AB
      sum AUFTRAG->Preis*(AUFTRAG->Menge-AUFTRAG->GeliefGes)/if(AUFTRAG->PE=="H",100,1)*;
        ROUND(1-AUFTRAG->Rabatt/100,2) to gwert for merkSatz<>AUFTRAG->(recno())
      // abzgl. Rabatt auf auftrag
      gwert=gwert-ROUND(gwert*AUFAUS->So_Rabatt/100,2)

      // Andere ABs summieren?
      if isAb
        select AufPost
        Umgebung(WRITE) // save current relations
        set relation to AUFPOST->AufNr into AufAus
        sum AUFPOST->Preis*(AUFPOST->Menge-AUFPOST->GeliefGes)/if(AUFPOST->PE=="H",100,1)*;
          ROUND(1-AUFPOST->Rabatt/100,2) to absWert ;
          for AUFAUS->AB_AufNr==merkAbNr .and. AUFAUS->(recno())<>merkAbSatz // alle au�e aktueller
        Umgebung(LOAD) // restore relations
        AUFAUS->(dbseek(merkAbNr))
        select Auftrag
      endif

      // aktueller Posten
      AUFTRAG->(dbgoto(merkSatz))
      ewert:=AUFTRAG->Preis*(AUFTRAG->Menge-AUFTRAG->GeliefGes)/if(AUFTRAG->PE=="H",100,1)
      // abzgl. Rabatt auf posten
      ewert=ewert-ROUND(ewert*AUFTRAG->Rabatt/100,2)
      // abzgl. Rabatt auf auftrag
      ewert=ewert-ROUND(ewert*AUFAUS->So_Rabatt/100,2)

      // Rest Menge
      rest:=merkNetto-merkBez-gwert-ewert-absWert

      if rest<=0 .or. alwaysShow

        if isAB
          text:="Info: Rahmenauftrag "+merkAbNr+"||"+;
            "      Gesamt-Guthaben..............: "+transstr(merkNetto,11,2)+"|"+;
            "      Bereits abgerechnet..........: "+transstr(merkBez,11,2)+"|"+;
            "      Andere Abruf-Auftr�ge........: "+transstr(absWert,11,2)+"|"+;
            "      Andere Posten in akt. Auftrag: "+transstr(gwert,11,2)+"|"+;
            "      Jetziger Abruf...............: "+transstr(ewert,11,2)+"|"+;
            "                                       ========="+"|"+;
            "      Rest Menge...................: "+transstr(rest,11,2)+" Euro"
        else

          text:="Info: Rahmenauftrag "+merkAbNr+"||"+;
            "      Gesamt-Guthaben....: "+transstr(merkNetto,11,2)+"|"+;
            "      Bereits abgerechnet: "+transstr(merkBez,11,2)+"|"+;
            "      Andere Posten in AB: "+transstr(gwert,11,2)+"|"+;
            "      Jetziger Abruf.....: "+transstr(ewert,11,2)+"|"+;
            "                             ========="+"|"+;
            "      Rest Menge.........: "+transstr(rest,11,2)+" Euro"
        endif
        Error(text, .t.)


      endif

      // erledigt??
      if AUFAUS->erledigt<>"J" .and. rest<=0
        if commitErledigt
          if Message("Rahmenauftrag @"+merkAbNr+;
            "@ komplett abgerufen. Als erledigt markieren? (@J@/@N@)","JN","J")=="J"
            select AufAus
            if ! rec_lock(5)
              Error(TRY_AGAIN)
            else
              replace AUFAUS->erledigt with "J"
              dbcommit()
              dbunlock()
            endif
          endif
        endif

        // email kommt �ber crontab
        // subject:="Artikel: "+AUFTRAG->ArtNr+" - Budgetauftrag ausgesch�pft."
        // body+="Auftrag....: "+AUFAUS->AufNr +MY_CR+MY_LF
        // body+="Kunde......: "+AUFAUS->KundNr+" "+AUFAUS->KurzName +MY_CR+MY_LF
        // body+="K�rzel: "+getUser():id +MY_CR+MY_LF
        // body+=MY_CR+MY_LF
        // body+="Evtl. sollte ein neuer Budget-Rahmanauftrag mit dem Kunden vereinbart werden." + MY_CR+MY_LF
        // body+=MY_CR+MY_LF
        // body+=strtran(text,"|",MY_CR+MY_LF)

        // EMail an H. Weiland
        // email(MAIN_EMAIL,subject,body)
        //

      endif
      restscreen(,,,,s01)
    endif

    select Aufaus
    set filter to &(merkFilter)
    AUFAUS->(dbgoto(MerkABsatz))
    select Auftrag


  endif

return (round(rest,2) >= 0)
/** eof */

/* drucken von GelangensBescheinigungs-Rechnungen
*/
PROCEDURE GelangRechnDruck()
LOCAL M_RechNr
LOCAL aktRec
LOCAL i,GetList:={}
LOCAL line, tempText ,merkReNr

  cls
  Titel("GelangensBescheinigungs-Rechnungen drucken")

  if ! openRechnDateien()
    close data
    return
  endif
  MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(

  select Rechaus
  set filter to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing) .and. empty(RECHAUS->GelReNr)
  go top

  do while ! ABBRUCH
    cls
    Titel("GelangensBescheinigungs-Rechnungen drucken")
    M_RechNr:=space(len(RECHAUS->RechNr))
    Message("Gelangensbescheinigungs-Nummer eingeben.           @F12@=Hilfe")
    @ 4,10 say "Rech.Nr.:" get M_RechNr;
      valid { |oGet| shift(oGet) .and. check(oGet,"RechAus",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif

    // Kopf anzeigen
    aktRec:=RECHAUS->(recno())
    gelDisp()

    // Posten anzeigen
    select Rechpost
    RECHPOST->(dbseek(RECHAUS->RechNr))
    @ 14,0 say ""
    qout("Art.Nr    Bezeichnung                                                  Menge    Preis   "+;
      " KW")
    i:=15
    do while i<maxrow() .and. ! RECHPOST->(eof()) .and. RECHPOST->RechNr==RECHAUS->RechNr
      qout(out(RECHPOST->ArtNr),RECHPOST->Komm1,RECHPOST->Menge,RECHPOST->Preis,RECHPOST->KW)
      i++
      skip
    enddo

    if Message("Gelangens-Bescheinigungs-Rechnung drucken? (@J@/@N@)","JN","N")=="J"

      // erzeuge Rechnung
      Message("Rechn:"+RECHAUS->GelNr+" wird gedruckt.   Bitte warten...")

      LAND->(dbseek(left(RECHAUS->V_Land,2)))
      AUFAUS->(dbseek(RECHAUS->AufNr))

      /* Auftragsposten erzeugen */
      select Auftrag
      zap

      // 1. Info Text
      tempText:=getTranslation("rechnung.gelang.text1",LAND->Sprache)
      for each line in linewrap(tempText,len(AUFTRAG->komm1))
        line:=strtran(line,"$GELNR",RECHAUS->GelNr)
        add_rec(0)
        replace AUFTRAG->AufNr WITH RECHAUS->AufNr
        replace AUFTRAG->ArtNr WITH "*"
        REPLACE AUFTRAG->komm1 WITH line
      next

      // 2. Posten berechnen
      add_rec(0)
      ARTIKEL->(dbseek(ShiftArtikel(ANGEBOTS_ARTIKEL)))
      replace AUFTRAG->AufNr WITH RECHAUS->AufNr
      replace AUFTRAG->ArtNr WITH ShiftArtikel(ANGEBOTS_ARTIKEL)
      tempText:=getTranslation("rechnung.gelang.posten1",LAND->Sprache)
      tempText:=strtran(tempText,"$GELNR",RECHAUS->GelNr)
      tempText:=strtran(tempText,"$DATUM",dtoc(RECHAUS->ReaDat))
      tempText:=strtran(tempText,"$NETTO",alltrim(transstr(RECHAUS->Netto,11,2)))
      REPLACE AUFTRAG->komm1 WITH tempText
      tempText:=getTranslation("rechnung.gelang.posten2",LAND->Sprache)
      tempText:=strtran(tempText,"$GELNR",RECHAUS->GelNr)
      tempText:=strtran(tempText,"$DATUM",dtoc(RECHAUS->ReaDat))
      tempText:=strtran(tempText,"$NETTO",alltrim(transstr(RECHAUS->Netto,11,2)))
      REPLACE AUFTRAG->komm2 WITH tempText
      replace AUFTRAG->Menge WITH 1
      replace AUFTRAG->Gelief WITH 1
      replace AUFTRAG->Preis WITH RECHAUS->Netto*MWST_KZ->Mwst/100
      replace AUFTRAG->Me WITH ARTIKEL->ME
      replace AUFTRAG->Pe WITH ARTIKEL->Schluessel

      // Leerzeile
      add_rec(0)
      replace AUFTRAG->AufNr WITH RECHAUS->AufNr
      replace AUFTRAG->ArtNr WITH "*"

      // 2. Info Text
      tempText:=getTranslation("rechnung.gelang.text2",LAND->Sprache)
      for each line in linewrap(tempText,len(AUFTRAG->komm1))
        add_rec(0)
        replace AUFTRAG->AufNr WITH RECHAUS->AufNr
        replace AUFTRAG->ArtNr WITH "*"
        REPLACE AUFTRAG->komm1 WITH line
      next

      // �bernehmen nach Rechnung
      auf_rech(AUFAUS->Aufart) // schreibe akt. Satz aus Aufaus->Rechaus

      // l�sche manche Voreinstellung vom Auftrag
      replace RECHAUS->ZkNr with getTranslation("rechnung.gelang.zahlkond",LAND->Sprache)
      replace RECHAUS->VersNr with ""
      replace RECHAUS->GelKZ with "J"
      merkReNr:=RECHAUS->RechNr

      // drucken
      rechnDeckblatt("D")
      Rechnung("1") // mit Abbuchen, da 1. Mal
      Rechnung("0",,,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung

      // r�ckschreiben in ursprungs Rechnung
      select Rechaus
      go (aktRec)
      rec_lock(0)
      replace RECHAUS->GelRenr with merkReNr
      dbcommit()
      dbunlock()

    endif
    SetLastKey(0)

  enddo

  close data
return
/** eof */

FUNCTION openRechnDateien()
  Message("Dateien werden ge�ffnet.  Bitte warten...")
  if ! open( "Auftrag","AufAus" , "ZahlKond" , "Text_Kz" ,"Aufpost";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" ;
    ,"Rabatt" ,"WarAus" , "AvPost","Spedit","Mat_Kz","BesPost","Inner";
    ,"Kunden" , "Land", "RechAus" , "RechPost","Erl_Grup","KostenSt","Email", "KundSped" ;
    ,"LiefTerm" , "Verkauf" , "Maschine" , "Text","ArtText")
    // letzte Zeile waren noch bei RechDruckWiederholen dabei = alter Adel???

    Error(TRY_AGAIN)
    close data
    RETURN .f.
  endif
  /* Relationen setzen */
  select AufPost
  set relation to AUFPOST->ArtNr into Artikel

  select Auftrag
  SET RELATION TO AUFTRAG->ME INTO Einheit, To AUFTRAG->ArtNr INTO ARTIKEL

  select RechPost
  set relation to RECHPOST->Me into Einheit

  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart
return .t.
/** eof */


/* Buchen der erhaltenen GelangensBescheinigungen
*/
PROCEDURE GelangEingang()
LOCAL M_GelNr,exit:=.f.
LOCAL GetList:={}
LOCAL merkNr,neuRechNr,merkGelNr
LOCAL TempText,Line
  cls
  Titel("Eingang GelangensBescheinigung")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Rechaus","Mwst_KZ" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
  select Rechaus

  // nur offene, ACHTUNG: hier auch berechnete
  set filter to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing)

  do while ! exit
    M_GelNr:=space(len(RECHAUS->GelNr))
    cls
    Titel()

    Message("GelangensBescheinigungs-Nummer eingeben.           @F12@=Hilfe")
    @ 2,20 say "Gel.Nr.:" get M_GelNr PICTURE "@9"
    read
    if ABBRUCH
      exit:=.t.
      loop
    endif

    Message("Bescheinigung wird gesucht.  Bitte warten...")
    loca for RECHAUS->GelNr==M_GelNr
    if EOF()
      set filter to ! empty(RECHAUS->GelNr)
      loca for RECHAUS->GelNr==M_GelNr
      if EOF()
        Error(ACHTUNG+M_GelNr+;
          " nicht gefunden.  Bitte Nr. kontrollieren.||         F12 = Auswahl",.t.)
      else
        Error(ACHTUNG+M_GelNr+" bereits gebucht.  Eingang am: "+dtoc(RECHAUS->GelEing),.t.)
      endif
      set filter to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing)
      loop
    endif

    gelDisp()

    if Message("Eingang GelangensBescheinigung verbuchen? (@J@/@N@)","JN"," ")=="J"
      if ! rec_lock(5)
        Error(TRY_AGAIN)
      else
        replace RECHAUS->GelEing with getUser():date
        dbcommit()
        dbunlock()
      endif

      // Storno-Rechnung generieren?
      if ! empty(RECHAUS->GelReNr)
        if Message("Storno-Rechnung erzeugen? (@J@/@N@)","JN","J")=="J"
          if ! openRechnDateien()
            return
          endif
          merkNr:=RECHAUS->RechNr
          merkGelNr:=RECHAUS->GelReNr

          // erzeuge Rechnung
          Message("Storno Rechnung wird gedruckt.   Bitte warten...")

          AUFAUS->(dbseek(RECHAUS->AufNr))

          /* Auftragsposten erzeugen */
          AUFAUS->(dbseek(RECHAUS->AufNr))
          select Auftrag
          zap

          // 1. Info Text
          LAND->(dbseek(left(RECHAUS->V_Land,2)))
          tempText:=getTranslation("rechnung.gelang.storno.text",LAND->Sprache)
          for each line in linewrap(tempText,len(AUFTRAG->komm1))
            line:=strtran(line,"$GELNR",RECHAUS->GelNr)
            add_rec(0)
            replace AUFTRAG->AufNr WITH RECHAUS->AufNr
            replace AUFTRAG->ArtNr WITH "*"
            REPLACE AUFTRAG->komm1 WITH line
          next


          // ACHTUNG: wir stornieren die GelangensBescheinigung-Rechnung, nicht die ursp.!
          select Rechaus
          set filter to
          RECHAUS->(dbseek(merkGelNr))
          RECHPOST->(dbseek(RECHAUS->RechNr))
          select Rechpost
          RECHPOST->(dbseek(RECHAUS->RechNr))
          do while RECHPOST->RechNr==RECHAUS->RechNr .and. ! RECHPOST->(eof())
            if alltrim(RECHPOST->ArtNr)==ANGEBOTS_ARTIKEL
              select Auftrag
              add_rec(0)
              replace AUFTRAG->ArtNr WITH RECHPOST->ArtNr
              replace AUFTRAG->AufNr WITH RECHPOST->AufNr
              replace AUFTRAG->komm1 WITH RECHPOST->Komm1
              replace AUFTRAG->komm2 WITH RECHPOST->Komm2
              replace AUFTRAG->Preis WITH RECHPOST->Preis
              replace AUFTRAG->Me WITH RECHPOST->ME
              replace AUFTRAG->Pe WITH RECHPOST->PE
              replace AUFTRAG->Rabattgr WITH RECHPOST->RabattGr
              replace AUFTRAG->Erl_Gruppe WITH RECHPOST->Erl_Gruppe
              replace AUFTRAG->Menge with RECHPOST->Menge*(-1)
              replace AUFTRAG->Gelief with RECHPOST->Gelief*(-1)
              replace AUFTRAG->GeliefGes with RECHPOST->GeliefGes*(-1)
              select Rechpost
            endif
            skip
          enddo

          // �bernehmen nach Rechnung
          auf_rech(AUFAUS->Aufart) // schreibe akt. Satz aus Aufaus->Rechaus

          // l�sche manche Voreinstellung vom Auftrag
          replace RECHAUS->ZkNr with ""
          replace RECHAUS->VersNr with ""
          REPLACE RECHAUS->Storno_Nr with merkNr
          neuRechNr:=RECHAUS->RechNr

          // drucken
          rechnDeckblatt("D")
          Rechnung("1") // mit Abbuchen, da 1. Mal
          Rechnung("0",,,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung

          // r�ckschreiben in ursprungs Rechnung
          select Rechaus
          set filter to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing)
          RECHAUS->(dbseek(merkNr))
          REPLACE RECHAUS->Storno_Nr with neuRechNr
          rec_lock(0)
          dbcommit()
          dbunlock()
        endif
      endif
    endif

  enddo
  close data
  cls
return
/** eop */

/** Zeigt den akt. Rechaus-Posten / GelangensBescheinigung an */
static procedure gelDisp()
  @ 5,18 to 14,66
  @ 6,20 say "Kund.Nr.: "+KdOut(RECHAUS->KundNr)
  @ 7,30 say RECHAUS->KurzNAme

  @ 9,20 say "AB.Nr...: "+RECHAUS->AufNr
  @ 10,20 say "Rech.Nr.: "+RECHAUS->RechNr
  @ 10,48 say "Datum: "+dtoc(RECHAUS->ReaDat)

  @ 12,20 say "Netto...: "+transstr(RECHAUS->Netto,10,2)+" Euro"
  @ 13,20 say "Mwst....: "+transstr(RECHAUS->Netto*MWST_KZ->MWSt/100,10,2)+" Euro"

  if ! empty(RECHAUS->GelReNr)
    @ 15,20 say "ACHTUNG GelangensBescheinigung bereits berechnet!" COLOR COLINV
    @ 16,20 say "Rechn.Nr.: "+RECHAUS->GelReNr COLOR COLINV
  endif
return
/** eop */


/** Stellt den aktuell selektierten und erledigten Auftrag wieder aktiv */
procedure aufRecall()
LOCAL;
  text:=if(AUFAUS->AufArt=="G","Gutschrift",if(AUFAUS->AufArt=="V" .or.;
  AUFAUS->warKV="J","Kostenvoranschlag","Auftrag"))

  SELECT Aufaus
  if ! rec_lock(5)
    Error(TRY_AGAIN)
    return
  endif
  replace AUFAUS->erledigt with " "
  dbcommit()
  dbunlock()

  //dispABStatus()

  Error("INFO: "+text+": "+AUFAUS->AufNr+" wieder hergestellt.")
return
/** eop */

/*
 * Erfassen von Speditions-Abhol-Auftr�gen
 */
PROCEDURE SpeditAuftragErfassen() // AbholAuftrag
LOCAL Ende:=.f.
LOCAL M_AufNr
LOCAL GetList:={} , Ausgabe:=if(AT_HOME,"P","D")
MEMVAR MerkNr,defAuftrArt,istAbrufAuftrag, Datum, teilLiefErfasst
MEMVAR zollManuell
PRIVATE MerkNr:=0
PRIVATE defAuftrArt:="P"
PRIVATE istAbrufAuftrag:=NIL , teilLiefErfasst
PRIVATE zollManuell:=.f.

  cls
  Titel("Speditions-Abholauftr�ge  erfassen/drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! openRechnDateien() .or. ! open("Abhol","Paletten")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  // setABFilter("R") // nur normale ABs und KVs
  select Aufaus
  set filter to  /* empty(AUFAUS->Ab_AufNr) .and. */  .not. AUFAUS->AufArt$"GKN"

  do while ! Ende
    @ 1,0 clear
    M_AufNr:=space(len( AUFAUS->AufNr ))
    @ 2,1 say 'Auftrag Nr.:'
    @ 2,14 get M_AufNr picture '@K #####' ;
      valid { |oGet| shift(oGet) .and. check(oGet,"AufAus",.f.,.f.) };
      when Message('Auftragsnummer eingeben.             @F12@=Hilfe')
    read

    select AufAus
    if (Ende:=ABBRUCH) .or. ! rec_lock(5)
      loop
    endif

    Auf_Kopf_Disp()
    Auf_Kopf(2)

    select Abhol
    ABHOL->(dbseek( AUFAUS->Aufnr ))
    if ABHOL->(eof())
      add_rec(0)
      replace ABHOL->AufNr with AUFAUS->AufNr
      // replace ABHOL->UhrZeit with "07:30"
      replace ABHOL->ProForma with if( upper(AUFAUS->EG) $ "JD", "N", "J" )
      replace ABHOL->TeilLiefer with "N"
      replace ABHOL->TextKz_Nr WITH AUFAUS->textkz_Nr

      // falls keine Sped. hinterlegt -> nehme Kundenadresse & Sprache
      if empty( AUFAUS->SpedNr ) .or. AUFAUS->SpedNr == "004" // Abholung nach Absprache
        replace ABHOL->Sprache with AUFAUS->Sprache
      else
        replace ABHOL->Sprache with SPEDIT->Sprache
      endif

    else
      if ! rec_lock(5)
        Error(TRY_AGAIN)
        close data
        RETURN
      endif

    endif

    // kopiere Posten f�r Druck
    AUFPOST->(dbseek( AUFAUS->AufNr ))
    select Auftrag
    zap
    append("AufPost", { || AUFPOST->AufNr==AUFAUS->AufNr } )
    // Gesamt-Menge beim 1. Mal immer vorschlagen
    replace all AUFTRAG->Gelief with 0

    setcolor(COLWIN)
    Fenster(3,10,21,75,"Abholauftrag")

    if empty(ABHOL->Datum) .or. ABHOL->Datum < getUser():date
      replace ABHOL->Datum with getUser():date
    endif

    M->teilLiefErfasst:=.f.
    showSpedition()
    @ 5,12 say "Spedition.........:" get AUFAUS->SpedNr picture "@9";
      when Message("Spedition eingeben.   @Leer@ = Kunde ist Abholer    @ESC@ = Abbruch") ;
      valid { |oGet| abholSpedNrNach(oGet) }

    @ 7,12 say "Verf�gbar ab......:" get ABHOL->Datum when Message("Abholdatum eingeben.")
    @ 7,48 say "Uhrzeit..:" get ABHOL->UhrZeit when Message("Abhol-Uhrzeit eingeben.") picture "99:99";
      valid { |oGet| zeitCheck(oGet) }

    @ 9,12 say "Sprache...........:" get ABHOL->Sprache ;
      picture"!" valid ABHOL->Sprache $ "ED" .and. message() ;
      when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")

    @ 9,48 say "Textbaustein:" get ABHOL->TextKz_Nr picture "@K@!";
      valid { |oGet| check(oGet,"Text_Kz") } when Message("Werbe - Text KZ eingeben.     "+;
      "@F12@=Hilfe")

    @ 11,12 say "Kommentar.........:" get ABHOL->Komm1 when Message("Kommentar eingeben.")
    @ 12,12 say "                   " get ABHOL->Komm2 when Message("Kommentar eingeben.")
    @ 13,12 say "                   " get ABHOL->Komm3 when Message("Kommentar eingeben.")
    @ 14,12 say "                   " get ABHOL->Komm4 when Message("Kommentar eingeben.")

    @ 15,12 say "Paletten" color COLINV
    @ 16,12 say "Art...............:" get ABHOL->PalNr ;
      when Message("Palleten-Art eingeben.   @F12@ = Auswahl") ;
      valid { |oGet| palettNrNach( oGet ) }

    PALETTEN->(dbseek( ABHOL->PalNr ))
    palettNrNach()

    @ 18,12 say "Anzahl............:" get ABHOL->Menge valid ABHOL->Menge > 0;
      when Message("Anzahl eingeben.")
    qqout( "  St�ck")
    @ 19,12 say "H�he..............:" get ABHOL->Hoehe when Message("H�he eingeben.")
    qqout( " m")
    @ 20,12 say "Gewicht...........:" get ABHOL->Gewicht when Message("Gewicht eingeben.")
    qqout( " kg")

    @ 18,48 say "Versand frei..........:" get ABHOL->Frei picture "!" ;
      valid { |oGet| freiNach( oGet ) } ;
      when Message("Versand kostenfrei?   (@J@/@N@)")
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
    @ 19,48 say "�ndern / Teillieferung:" get ABHOL->TeilLiefer picture "!";
      valid { |oGet| teilLieferNach(oGet)} when Message("Pro-Forma Rechnung bearbeiten / "+;
      "Teillieferung?   (@J@/@N@)")
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klausel wird auch bei ESC durchgesetzt
    // -> bei PgDn auch

    @ 20,48 say "Pro-Forma-Rechnung....:" get ABHOL->proForma picture "!" valid ABHOL->proForma $ "JN";
      when Message("Pro-Forma-Rechnung drucken?   (@J@/@N@)")
    read

    setcolor(COLNOR)
    // if ABBRUCH
    // AUFAUS->(dbunlock())
    // loop
    // endif

    Ausgabe:=Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?","DBP","D")
    if ABBRUCH
      AUFAUS->(dbunlock())
      loop
    endif

    if ABHOL->proForma == "J"
      ProFormaDrucken(Ausgabe,ABHOL->Sprache)
    else
      if ABHOL->TeilLiefer == "J"
        ProFormaDrucken("NOP") // brauchen wir wegen Summe Brutto/Netto
      else
        replace ABHOL->Brutto with AUFAUS->Brutto
        replace ABHOL->Netto with AUFAUS->Netto
        replace ABHOL->MwSt with AUFAUS->MwSt
      endif
    endif

    // jetzt drucken
    SpeditAuftragDrucken(Ausgabe)

    dbcommitall()
    dbunlockall()

  enddo

  close data
return
/** eop */

/*
 * Erfassen von Pro-Forma-Rechnung
 * �hnlich zu SpeditAuftragErfassen()
 */
PROCEDURE ProFormaErfassen() // Rechnung
LOCAL Ende:=.f.
LOCAL M_AufNr
LOCAL GetList:={} , Ausgabe:=if(AT_HOME,"P","D")
MEMVAR MerkNr,defAuftrArt,istAbrufAuftrag, Datum, zollManuell
PRIVATE MerkNr:=0
PRIVATE defAuftrArt:="P"
PRIVATE istAbrufAuftrag:=NIL
PRIVATE zollManuell:=.f.

  cls
  Titel("Pro-Forma-Rechnung   erfassen/drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! openRechnDateien()
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  setABFilter("R") // nur normale ABs

  do while ! Ende

    M->zollManuell:=.f.

    @ 1,0 clear
    M_AufNr:=space(len( AUFAUS->AufNr ))
    @ 2,1 say 'Auftrag Nr.:'
    @ 2,14 get M_AufNr picture '@K #####' ;
      valid { |oGet| shift(oGet) .and. check(oGet,"AufAus",.f.,.f.) };
      when Message('Auftragsnummer eingeben.             @F12@=Hilfe')
    read

    select AufAus
    if (Ende:=ABBRUCH) .or. ! rec_lock(5)
      loop
    endif

    Auf_Kopf_Disp()
    Auf_Kopf(2)

    // kopiere Posten f�r Druck
    AUFPOST->(dbseek( AUFAUS->AufNr ))
    select Auftrag
    zap
    append("AufPost", { || AUFPOST->AufNr==AUFAUS->AufNr } )
    // Gesamt-Menge beim 1. Mal immer vorschlagen
    replace all AUFTRAG->Gelief with AUFTRAG->Menge

    // Rechnungsbauch bearbeiten
    selLandBySprache( AUFAUS->Sprache )
    Rech_Bauch(NIL) // kein Rahmenauftrag
    SetLastKey(0)

    Ausgabe:=Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?","DBP","D")
    if ABBRUCH
      AUFAUS->(dbunlock())
      loop
    endif

    ProFormaDrucken(Ausgabe)

    dbcommitall()
    dbunlockall()

  enddo

  close data
return
/** eop */

static function freiNach( oGet)
return ABBRUCH .or. oGet:buffer $ "JN"
/** eof */

static function showSpedition()
  if empty( AUFAUS->SpedNr )
    @ 5,37 say AUFAUS->KurzName
  else
    SPEDIT->(dbseek(AUFAUS->SpedNr))
    @ 5,37 say SPEDIT->Name
  endif
return .t.
/** eof */


// wird nach eingabe der Paletten-Nr ausgef�hrt
static function palettNrNach( oGet )
  if oGet <> nil .and. ! check( oGet , "Paletten" , .f. , .f. )
    return .f.
  endif

  @ 16,12 + 23 say PALETTEN->Text1
  @ 17,12 + 23 say PALETTEN->Text2

return .t.
/** eof */

/*
*Pr�ft auf g�ltige Uhrzeit-Eingabe
*/
static FUNCTION ZeitCheck(oGet)
LOCAL buff:=alltrim(oGet:Buffer)

  /* zur�ck immer erlaubt */
  if lastkey()==K_UP
    oget:undo()
    RETURN(.t.)
  endif

  /* UhrZeit checken ! */
  if val(left(oGet:Buffer,2)) > 23 .or. len(trim(right(oGet:Buffer,2)))=1 .or.;
    val(right(oGet:Buffer,2)) > 59
    RETURN(.f.)
  endif

RETURN(.t.)
/* EOF */


/** wird nach Eingabe der Teillieferung ausgef�hrt */
static function teilLieferNach(oGet)
  if ! oGet:buffer $ "JN"
    return .f.
  endif

  if M->teilLiefErfasst .and. ! oGet:changed
    return .t.
  endif

  // if oGet:changed .and. lastkey() <> K_UP
  if lastkey() <> K_UP

    Umgebung(WRITE) // save current relations

    if oGet:buffer == "J"
      setcolor(COLNOR)
      // Teillieferung editieren?
      M->teilLiefErfasst:=.t.
      selLandBySprache( ABHOL->Sprache )
      Rech_Bauch(NIL) // kein Rahmenauftrag
      SetLastKey(0)
    else
      // komplett Lieferung
      select Auftrag
      replace all AUFTRAG->Gelief with AUFTRAG->Menge
    endif
    Umgebung(LOAD) // restore relations

  endif

return .t.
/** eof */

/*
*  �ndern der Rechnungsadresse bei "alten" Rechungen
*/
PROCEDURE RechAdrAendern()
LOCAL M_RechNr:=".", ob:=0, ant:=" "
LOCAL GetList:={}, ende:=.f., M_KundNr:=KDNR_LEER
MEMVAR defAuftrArt,istAbrufAuftrag,emailAbweichend
PRIVATE defAuftrArt:=" ",istAbrufAuftrag:=NIL
PRIVATE emailAbweichend:=0

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! openRechnDateien()
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  set key K_F5 to aendRSprache()

  /* Relationen setzten */
  select RECHAUS
  do while ! ende
    cls
    Titel("Rechnungsadresse �ndern")

    M_RechNr:=space(len(RECHAUS->RechNr))
    Message("Rechnungsnummer eingeben.        @F5@=Sprache �ndern   @F12@=Hilfe")
    @ 4,10 say "Rech.Nr.:" get M_RechNr;
      valid { |oGet| shift(oGet) .and. check(oGet,"RechAus",.t.,.f.) }
    read
    if ABBRUCH
      ende:=.t.
      dbunlockall()
      loop
    endif
    if empty(M_RechNr)
      Keyboard chr(HILFE_TASTE1)
      loop
    endif

    /* Satz locken */
    SELECT RechAus
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      loop
    endif

    select Aufaus
    AUFAUS->(dbseek(RECHAUS->AufNr))
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      dbunlockall()
      loop
    endif

    M->defAuftrArt:=AUFAUS->AufArt

    @ 2,0 clear

    Rech_Kopf_Disp()

    @ ob+2,38 get RECHAUS->KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) .and. RechAdrNach(oGet)};
      when Message('Kunden-Nummer eingeben.     @F5@=Sprache     @F12@=Hilfe')

    @ ob+4,38 get RECHAUS->V_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) .and. RechAdrNach(oGet)} ;
      when Message("Kundennummer Versand eingeben   @F5@=Sprache   @F12@=Hilfe")

    @ ob+8,38 get RECHAUS->R_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) .and. RechAdrNach(oGet) };
      when Message("Kundennr. Rechnung eingeben      @F5@=Sprache   @F12@=Hilfe")

    @ ob+14,1 say "Best.Nr. Anfrage:"
    @ ob+15,1 GET RECHAUS->BestNr when Message('Bestell - Nr. eingeben.')

    if RECHAUS->R_Land <> DEUTSCH_LAND
      @ ob+16,;
        1 say "Fremd-W�hrung: "GET RECHAUS->FremdWaehr Picture "@!" when Message('Fremdw�hrung '+;
        'K�rzel eingeben.')
      @ ob+17,1 say "Fremd-Summe..: "GET RECHAUS->FremdSumme when Message('Summe in Fremdw�hrung '+;
        'eingeben.')
    endif

    @ ob+13,32 say "Zahl.Kond.:" get RECHAUS->ZkNr ;
      valid { |oGet| zkNr_nach(oGet) };
      when Message("Zahlungskondition eingeben.   @F12@=Hilfe")
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

    @ ob+15,32 say "Versandart:" get RECHAUS->VersNr ;
      valid { |oGet| VersNr_nach(oGet) } ;
      when Message('Versandart eingeben.             @F12@=Hilfe')
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

    read
    setDuedate()

    dbcommitall()
    dbunlockall()

    if ABBRUCH
      loop
    endif

    Rech_Kopf_Disp()

    Message("Bitte @Taste@ dr�cken.","@")
  enddo

  cls
  close data
  set key K_F5 to
return
  /** eop */

/** �ndern der Adresse bei Rechnung*/
static function RechAdrNach(oGet)
LOCAL s01

  if oGet:changed

    KUNDEN->(dbseek( oGet:Buffer ))

    do case
    case upper(oGet:Name) == "RECHAUS->KUNDNR"
      REPLACE RECHAUS->KundNr WITH KUNDEN->KundNr
      REPLACE RECHAUS->Name WITH KUNDEN->Name
      REPLACE RECHAUS->Partner WITH KUNDEN->Partner
      REPLACE RECHAUS->Strasse WITH KUNDEN->Strasse
      REPLACE RECHAUS->Zusatz WITH KUNDEN->Zusatz
      REPLACE RECHAUS->Plz WITH KUNDEN->PLZ
      REPLACE RECHAUS->Land WITH KUNDEN->Land
      REPLACE RECHAUS->Ort WITH KUNDEN->Ort
      REPLACE RECHAUS->Sprache WITH KUNDEN->Sprache
      REPLACE RECHAUS->KurzName WITH KUNDEN->KurzName

	/* automat. AB �ndern, ohne Abfrage 27.9.17 */
      REPLACE AUFAUS->KundNr WITH KUNDEN->KundNr
      REPLACE AUFAUS->Name WITH KUNDEN->Name
      REPLACE AUFAUS->KurzName WITH KUNDEN->KurzName
      REPLACE AUFAUS->Partner WITH KUNDEN->Partner
      REPLACE AUFAUS->Strasse WITH KUNDEN->Strasse
      REPLACE AUFAUS->Zusatz WITH KUNDEN->Zusatz
      REPLACE AUFAUS->Plz WITH KUNDEN->PLZ
      REPLACE AUFAUS->Land WITH KUNDEN->Land
      REPLACE AUFAUS->Ort WITH KUNDEN->Ort
      REPLACE AUFAUS->Sprache WITH KUNDEN->Sprache

    case upper(oGet:Name) == "RECHAUS->V_KUNDNR"
      REPLACE RECHAUS->V_KundNr WITH KUNDEN->KundNr
      REPLACE RECHAUS->V_Name WITH KUNDEN->Name2
      REPLACE RECHAUS->V_Partner WITH KUNDEN->Partner2
      REPLACE RECHAUS->V_Strasse WITH KUNDEN->Strasse2
      REPLACE RECHAUS->V_Zusatz WITH KUNDEN->Zusatz2
      REPLACE RECHAUS->V_Plz WITH KUNDEN->PLZ2
      REPLACE RECHAUS->V_Land WITH KUNDEN->Land2
      REPLACE RECHAUS->V_Ort WITH KUNDEN->Ort2
      REPLACE RECHAUS->V_Sprache WITH KUNDEN->Sprache2
      REPLACE RECHAUS->IdentNr WITH KUNDEN->IdentNr

	/* automat. AB �ndern, ohne Abfrage 27.9.17 */
      REPLACE AUFAUS->V_KundNr WITH AUFAUS->KundNr
      REPLACE AUFAUS->V_Name WITH KUNDEN->Name2
      REPLACE AUFAUS->V_Partner WITH KUNDEN->Partner2
      REPLACE AUFAUS->V_Strasse WITH KUNDEN->Strasse2
      REPLACE AUFAUS->V_Zusatz WITH KUNDEN->Zusatz2
      REPLACE AUFAUS->V_Plz WITH KUNDEN->PLZ2
      REPLACE AUFAUS->V_Land WITH KUNDEN->Land2
      REPLACE AUFAUS->V_Ort WITH KUNDEN->Ort2
      REPLACE AUFAUS->V_Sprache WITH KUNDEN->Sprache2


    case upper(oGet:Name) == "RECHAUS->R_KUNDNR"
      REPLACE RECHAUS->R_KundNr WITH KUNDEN->KundNr
      REPLACE RECHAUS->R_Name WITH KUNDEN->Name
      REPLACE RECHAUS->R_Partner WITH KUNDEN->Partner
      REPLACE RECHAUS->R_Strasse WITH KUNDEN->Strasse
      REPLACE RECHAUS->R_Zusatz WITH KUNDEN->Zusatz
      REPLACE RECHAUS->R_Plz WITH KUNDEN->PLZ
      REPLACE RECHAUS->R_Land WITH KUNDEN->Land
      REPLACE RECHAUS->R_Ort WITH KUNDEN->Ort
      REPLACE RECHAUS->R_Sprache WITH KUNDEN->Sprache

	/* automat. AB �ndern, ohne Abfrage 27.9.17 */
      REPLACE AUFAUS->R_KundNr WITH KUNDEN->KundNr
      REPLACE AUFAUS->R_Name WITH KUNDEN->Name
      REPLACE AUFAUS->R_Partner WITH KUNDEN->Partner
      REPLACE AUFAUS->R_Strasse WITH KUNDEN->Strasse
      REPLACE AUFAUS->R_Zusatz WITH KUNDEN->Zusatz
      REPLACE AUFAUS->R_Plz WITH KUNDEN->PLZ
      REPLACE AUFAUS->R_Land WITH KUNDEN->Land
      REPLACE AUFAUS->R_Ort WITH KUNDEN->Ort
      REPLACE AUFAUS->R_Sprache WITH KUNDEN->Sprache

      if ! ( empty(RECHAUS->A_Name) .and. empty(RECHAUS->A_Partner) )
        s01:=savescreen()
        kunAlternativDisp(2, "RECHAUS") // anzeigen
        if Message("Alternative Rechnungsadresse ebenfalls �ndern? (@J@/@N@)","JN","N")=="J"
          kunAlternativDisp(0 , "RECHAUS") // anzeigen

	    /* automat. AB �ndern, ohne Abfrage 27.9.17 */
          REPLACE AUFAUS->A_Name WITH RECHAUS->A_Name
          REPLACE AUFAUS->A_Partner WITH RECHAUS->A_Partner
          REPLACE AUFAUS->A_Strasse WITH RECHAUS->A_Strasse
          REPLACE AUFAUS->A_Zusatz WITH RECHAUS->A_Zusatz
          REPLACE AUFAUS->A_Plz WITH RECHAUS->A_PLZ
          REPLACE AUFAUS->A_Land WITH RECHAUS->A_Land
          REPLACE AUFAUS->A_Ort WITH RECHAUS->A_Ort
        endif
        restscreen(,,,,s01)
      endif
    endcase

    Rech_Kopf_Disp()
  endif
return .t.
/** eof */

/** �ndern der Sprache F5 bei Rechnung*/
static function aendRSprache(p1)
LOCAL ob:=0,oldValue:=AUFAUS->Sprache
LOCAL GetList:={},s01:=savescreen()

  // Abbruch falls aus Hilfe F12 kommt
  if p1 == "APPLYKEY"
    return .f.
  endif

  Message("Sprache eingeben.      @D@eutsch oder @E@nglisch       @F12@=Auswahl")
  @ ob+2,47 get RECHAUS->Sprache picture "!" valid RECHAUS->Sprache $ DEUTSCH+ENGLISCH
  @ ob+4,47 get RECHAUS->V_Sprache picture "!" valid RECHAUS->V_Sprache $ DEUTSCH+ENGLISCH
  @ ob+8,47 get RECHAUS->R_Sprache picture "!" valid RECHAUS->R_Sprache $ DEUTSCH+ENGLISCH
  read
  restscreen(,,,,s01)

  Rech_Kopf_Disp()

return .t.
/** eof */

static procedure Rech_Kopf_Disp()
LOCAL ob:=0

  @ ob+11,2 to ob+11,78

  @ ob+2,1 say 'Auftrags-Nr..:'
  @ ob+2,16 say RECHAUS->AufNr
  @ ob+3,1 say 'Rechnungs-Nr.:'
  @ ob+3,16 say RECHAUS->RechNr
  @ ob+5,1 say 'Datum........:'
  @ ob+5,16 say RECHAUS->AufDat

  @ ob+1,32 say "Auftrag-Anschr:"
  @ ob+2,32 say 'Kd.Nr:'
  @ ob+1,49 say RECHAUS->Name
  @ ob+2,49 say RECHAUS->Ort

  if ! empty(RECHAUS->V_Sprache) .and. RECHAUS->V_Sprache<>DEUTSCH
    @ ob+3,40 say "(engl)  "
  endif
  @ ob+3,49 say RECHAUS->V_Name
  @ ob+4,49 say RECHAUS->V_Partner
  @ ob+5,49 say RECHAUS->V_Strasse
  @ ob+6,49 say RECHAUS->V_Land
  @ ob+6,52 say RECHAUS->V_PLZ
  @ ob+6,58 say RECHAUS->V_Ort

  @ ob+3,32 say "Versand-Anschr:"
  @ ob+3,49 say RECHAUS->V_Name
  @ ob+4,32 say 'Kd.Nr:'
  @ ob+4,49 say RECHAUS->V_Partner
  @ ob+5,49 say RECHAUS->V_Strasse
  @ ob+6,49 say RECHAUS->V_Land
  @ ob+6,52 say RECHAUS->V_PLZ
  @ ob+6,58 say RECHAUS->V_Ort

  @ ob+7,32 say "Rechnung-Anschr:"
  @ ob+8,32 say 'Kd.Nr:'
  if ! empty(RECHAUS->R_Sprache) .and. RECHAUS->R_Sprache<>DEUTSCH
    @ ob+7,41 say "(engl)"
  endif

  @ ob+7,49 say RECHAUS->R_Name
  @ ob+8,49 say RECHAUS->R_Partner
  @ ob+9,49 say RECHAUS->R_Strasse
  @ ob+10,49 say RECHAUS->R_Land
  @ ob+10,52 say RECHAUS->R_PLZ
  @ ob+10,58 say RECHAUS->R_Ort

  if ! empty(RECHAUS->A_Name) .or. ! empty(RECHAUS->A_Partner)
    @ ob+12,49 say "Alternative Rechnungsadresse:"
    @ ob+14,49 say RECHAUS->A_Name
    @ ob+15,49 say RECHAUS->A_Partner
    @ ob+16,49 say RECHAUS->A_Strasse
    @ ob+17,49 say RECHAUS->A_Land
    @ ob+17,52 say RECHAUS->A_PLZ
    @ ob+17,58 say RECHAUS->A_Ort
  endif

return
/** eop */


/** �berpr�ft nach Beendigung des Edit-Modus ob Zuschl�ge f�r Zoll f�llig werden */
static Function pruefeRechZuschlaege()
LOCAL gesamtWert:=0 , changed:=.f.

LOCAL Datei:="AUFAUS"

  // falls temp. auf manuell gestellt -> bail out
  if type("M->zollManuell")=="L" .and. M->zollManuell
    return .t.
  endif

  Umgebung(WRITE_ALL)

  // Zoll / EUR1 Zuschl�ge

  // l�sche alle vorher hinzugef�gten unbelieferten Zoll/EUR1 Zuschl�ge
  if ! (DATEI)->EG $ "DJ" .and. (DATEI)->ZollZuschl == "J"
    select Auftrag
    go top
    do while ! AUFTRAG->(eof())
      if isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and. AUFTRAG->Gelief > 0
        replace AUFTRAG->Gelief with 0
        changed:=.t.
      endif
      skip
    enddo

    gesamtWert:=summeAuftrag( Datei , "AUFTRAG->Gelief")

    // Zoll Zuschlag f�r nicht EU Empf�nger?
    SPEDIT->(dbseek( (DATEI)->SpedNr ))
    if SPEDIT->SpedKz == "J" .and. isPhoenixAuftrag() // seit 31.5.2016
      if gesamtWert > 0 // bei Palettenversand Ph�nix immer
        berechneZoll( getProperty("Miki.zoll.aufschlag.gross","") , Datei)
        changed:=.t.
      endif
    else
      if gesamtWert > val( getProperty("Miki.zoll.aufschlag.limit","1000") )
        berechneZoll( getProperty("Miki.zoll.aufschlag.klein","") , Datei)
        changed:=.t.
      endif
    endif

    // GesamtWert hier nochmal berechnen, kann sich mit Zoll Aufschlag ge�ndert haben.
    gesamtWert:=summeAuftrag( Datei , "AUFTRAG->Gelief")

    // EUR1 Erkl�rung Pauschale dazu bei Wert > 6000 Euro
    // seit 17.9.2016 nur noch f�r Pr�ferenzl�nder
    LAND->(dbseek(left((DATEI)->V_Land,2)))
    if LAND->LLE=="J" .and.;
      gesamtWert > val( getProperty("Miki.zoll.aufschlag.EUR1.limit","6000") )
      berechneZoll( getProperty("Miki.zoll.aufschlag.EUR1","") , Datei)
      changed:=.t.
    endif

  endif

  Umgebung( LOAD )

  if changed
    HB_KeyPut(EDIT_BS_REFRESH)
    keyboard chr(K_HOME) // needed since recno may has changed

    dispEditorSumme("AUFAUS","AUFTRAG->Gelief",48)
  endif

return .t.
/** eof */

/** Berechnet den angegeben Pauschal-Artikel => setze Menge auf 1 */
static procedure berechneZoll( mArtNr )
LOCAL aktOrd

  loca for AUFTRAG->ArtNr == ShiftArtikel( mArtNr )
  if AUFTRAG->(eof())
    // hole urspr�nglichen Zoll-Artikel aus AB
    // kann bei Teillieferungen vorkommen
    aktOrd:=AUFPOST->(IndexOrd())
    AUFPOST->(OrdSetFocus(3))
    AUFPOST->(dbseek( AUFAUS->AufNr + ShiftArtikel( mArtNr ) ))
    if AUFPOST->(eof()) // nicht vorhanden -> exit
      AUFPOST->(OrdSetFocus(aktOrd))
      return
    endif

    select Auftrag
    add_rec(0)
    overwrite("AufPost")
    AUFPOST->(OrdSetFocus(aktOrd))
  endif

  // 1x berechnen
  replace AUFTRAG->GeliefGes with 0
  replace AUFTRAG->Gelief with 1

return
/** eof */

  /** Nur Kommentare d�rfen hier gel�scht werden
  */
static function konsistenzLoesch()

  if alltrim(AUFTRAG->ArtNr) == "*" .or. ;
    (AUFTRAG->ABPostNr == 0 .and. (len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE))
    // now delete via editor.prg
    HB_KeyPut(EDIT_DELETE)
    return .t.
  endif

  // pr�fe auf Beistellteile
  if left(AUFTRAG->TempStr,1) $ "B"
    // now delete via editor.prg
    HB_KeyPut(EDIT_DELETE)
    return .t.
  endif

return .f.
/** eof */


/** wir beim SpeditAuftrag nach Eingabe der Sped.Nr. ausgef�hrt */
static function abholSpedNrNach( oget )
LOCAL aktOrd

  if ABBRUCH
    return .t.
  endif

  if ! check( oGet , "Spedit" , .t. , .t. )
    return .f.
  endif

  if oGet:changed .or. empty( ABHOL->Frei )
    aktOrd:=KUNDSPED->(OrdSetFocus(2))
    KUNDSPED->(dbseek( AUFAUS->V_KundNr + oGet:buffer ))
    if ! KUNDSPED->(eof()) .or. oGet:changed
      replace ABHOL->Frei with KUNDSPED->Frei
      setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
    endif
    KUNDSPED->(OrdSetFocus( aktOrd ))
  endif

  showSpedition()

return .t.
/** eof */


/** pr�ft ob der aktuelle Artikel als Teil in Auftrag.dbf vorkommt */
static function isAllowedTeil()
LOCAL result:=.f.
LOCAL aktArtNr:=AUFTRAG->ArtNr

  // 4.11.2018 nur Beistellteile erlaubt
  if ARTIKEL->KonsigKdNr <> AUFAUS->KundNr
    return .f.
  endif

  Umgebung(WRITE_ALL)

  select Auftrag
  go top
  do while ! AUFTRAG->(eof()) .and. ! result
    if len(trim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. aktArtNr <> AUFTRAG->ArtNr
      Message("Artikel @"+out(AUFTRAG->ArtNr)+"@ werden gesucht.   Bitte warten....")
      result:=StueckListe():new( AUFTRAG->ArtNr ):containsChild( aktArtNr , .t. )
      select Auftrag
    endif
    skip
  enddo

  Umgebung( LOAD )

return result
/** eof */




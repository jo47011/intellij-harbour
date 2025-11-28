/* Modul: Fakt.prg   (siehe auch Fakt2.prg)
*
* enth�lt alles bzgl. Fakturierung: erfassen,l�schen, etc.
* Druck in: Fakt_dru.prg
*/

#include "Miki.ch"
#include "Getexit.ch"

#define TEMP_NUMMER right("*****"+getUser():getLongID(),len(AUFAUS->AufNr))
#define RAHMAB_VORSCHLAG "Vorschlag aus RahmAB"

#define EMAIL_ABWEICHENDE_ZAHLKOND 1
#define EMAIL_ABWEICHENDE_VERSART 2
#define EMAIL_ABWEICHENDE_SPEDITION 4

/* erfassen von Auftr�gen / Gutschriften
*
* Parameter:  R - Rechnung (Auftrags)
* Auftr_Art   G - Gutschrift
*             K - KLager Auftrag
*             I - KLager Inventur Auftrag
*             D - Dispositions Auftrag (Rahmenauftrag - Artikel)
*             B - Dispositions Auftrag (Rahmenauftrag - Budget)
*             V - Kostenvoranschlag (analog R, nur anderer Text)
*
* kein Aufruf hier aber zur Info:
*              N - KLager-Gutschrift
*              M - KLager-Gutschrift Storno
*              A - Ausfallmuster (jetzt Handlieferschein s. liefer.prg, liefaus etc.)
*              P - Pickup = Abholauftrag Spedition
*              S - Storno Rechnung
*              Q - Sammel-Rechnung Repa (obsolete?!)
*
* --> siehe miki.ch AB_

*
* Parameter Abruf: falls gesetzt muss AB_Aufnr (Rahmenauftrag) einggeben werden
*
*/
PROCEDURE Auf_erfassen(Auftr_Art,Abruf)
LOCAL Ende:=.f. , changedAB:=.f.,changedKopf:=.f.
LOCAL ant:="N" , M_AufNr:=""
LOCAL GetList:={}
LOCAL erst:=.t.,M_Order
LOCAL Auswahl:=0 , Ausgabe:="D",zeile:=0,erneut:="J",merkArt,tempSum
LOCAL anzahl, loeschNr,diffKVMenge, text
LOCAL subject, body, tempMwst
MEMVAR MerkNr,defAuftrArt,istAbrufAuftrag,emailAbweichend
PRIVATE MerkNr:=0 , versandChanged
PRIVATE defAuftrArt:=Auftr_Art
PRIVATE istAbrufAuftrag
PRIVATE emailAbweichend:=0

  default Abruf:=NIL
  istAbrufAuftrag:=Abruf

  cls
  do case
  case M->istAbrufAuftrag <> NIL
    Titel("Abruf - Auftrag  erfassen/drucken")
  case Auftr_Art=="V" // Kostenvoranschlag
    Titel("Kostenvoranschlag  erfassen/drucken")
  case Auftr_Art=="G" // Gutschrift
    Titel("Gutschriften  erfassen/drucken")
  case Auftr_Art=="K" // K-Lager
    Titel("Konsignationslager-Auftr�ge  erfassen/drucken")
  case Auftr_Art=="I" // Inventur K-Lager
    Titel("K-Lager Inventur-Auftrag / Rechnung drucken")
  case Auftr_Art=="D"
    Titel("Rahmenauftrag - Artikel erfassen/drucken")
  case Auftr_Art=="B"
    Titel("Rahmenauftrag - Budget  erfassen/drucken")
  otherwise
    Titel("Auftr�ge  erfassen/drucken")
  endcase

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag" , "AufAus" , "ZahlKond" ;
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "Aufpost","AvPost";
    , "Rabatt" , "Text_Kz","Kunden" , "RechAus" , "RechPost" , "KundSped", "KdKontakt";
    ,"Erl_Grup", "Maschine", "LiefTerm", "Verkauf","Land","ZeitErf";
    ,"Text" ,"Abruf","Spedit","Inner","Mat_Kz","BesPost",;
    "AufZeit","Konsig","BesAus","Email","ArtText")


    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  SELECT Auftrag
  SET RELATION To AUFTRAG->ArtNr INTO ARTIKEL, TO AUFTRAG->ME INTO Einheit

  INNER->(OrdSetFocus(3))
  select artikel
  set relation to ARTIKEL->ME into Einheit
  select aufaus
  set relation to AUFAUS->textkz_Nr into Text_Kz,to AUFAUS->zknr into zahlkond,;
    to AUFAUS->versNr into versart

  do while ! Ende

    setABFilter(Auftr_art)

    M->emailAbweichend:=0

    /* l�sche Abruf-Datei, wird je bearbeiteter Auftrag benutz */
    select Abruf
    zap

    /* l�sche Auftrags-Datei */
    select Auftrag
    set filter to
    zap

    // neu: filter auf ungel�schte Posten
    set filter to AUFTRAG->geloescht$"N "

    /* Kopf eingeben */
    select AufAus

    go bottom
    skip // leeren Satz anzeigen
    M->MerkNr:=0
    M->versandChanged:=.f.
    @ 2,0 clear
    Auf_Kopf_Disp()

    Ende:=! Auf_Kopf(0)

    changedKopf:=getUpdated()

    /* gehe auf editierten Satz  */
    select AufAus
    if M->MerkNr==0 .or. Ende
      loop
    endif
    go M->MerkNr

    // pr�fe ob Ansprechpartner bei EU Partner eingegeben
    LAND->(dbseek(left(AUFAUS->V_Land,2)))
    // if trim(AUFAUS->V_Land)<>"DE" .and. LAND->EU=="J"
    if ! Auftr_Art $ "GKI" .and. AUFAUS->AufNr==TEMP_NUMMER // .and. ! DEVEL_PROG // jetzt bei allen neuen ABs
      do while ((emptyOr2Simple(AUFAUS->Ansprech,3) .or. ;
        (emptyOr2Simple(AUFAUS->Telefon,3).and. emptyOr2Simple(AUFAUS->Email,3).and.;
        emptyOr2Simple(AUFAUS->Fax,3))))

        Error(ACHTUNG+"Eingabe Ansprechpartner und mind. eine Kontaktm�glichkeit |"+;
          "         sind Pflicht bei neuen Auftr�gen||"+;
          "         F12 aus Kundenstamm �bernehmen",.t.)

        editAnsprechPartner()
      enddo

      // Sonderfall Ungarn
      do while (trim(AUFAUS->Land)==UNGARN_LAND .or. trim(AUFAUS->V_Land)==UNGARN_LAND .or. ;
        trim(AUFAUS->R_Land)==UNGARN_LAND .or. trim(AUFAUS->S_Land)==UNGARN_LAND) .and. ;
        (emptyOr2Simple(AUFAUS->Ansprech,5) .or. emptyOr2Simple(AUFAUS->Telefon,5))

        Error(ACHTUNG+"F�r Ungarn sind Eingabe Ansprechpartner und Tel.Nr Pflicht.|"+;
          "         F12 aus Kundenstamm �bernehmen",.t.)

        editAnsprechPartner()

      enddo

    endif

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(AUFAUS->Sprache)

    // Art Rahmenauftrag merken Budget "B" oder Artikel "D"
    merkArt:=NIL
    if ! empty(AUFAUS->Ab_AufNr)
      merkArt:=getRahmABArt()
    endif
    /* alle passenden Posten kopieren */
    if AUFAUS->AufNr == TEMP_NUMMER
      if Auftr_Art=="I" // Inventur K-Lager -> Posten �bernahme anbieten
        if Message("Posten aus Honseldaten generieren? (@J@/@N@)","JN"," ")=="J"
          if ! open("Honselda")
            Error(TRY_AGAIN)
          else
            Message("Posten werden �bernommen.   Bitte warten...")
            go top
            do while ! HONSELDA->(eof())

              if HONSELDA->HonselBest > 0
                ARTIKEL->(dbseek( HONSELDA->ArtNr ))

                select Auftrag
                add_rec(0)
                // replace AUFPOST->AufNr with mAbNr
                replace AUFTRAG->KundNr with AUFAUS->KundNr // wurde evtl. ge�ndert
                replace AUFTRAG->ArtNr with HONSELDA->ArtNr
                replace AUFTRAG->Komm1 with HONSELDA->Bez2
                replace AUFTRAG->Komm2 with HONSELDA->Bez3
                replace AUFTRAG->Menge with HONSELDA->HonselBest

                ARTIKEL->(dbseek( HONSELDA->ArtNr ))
                REPLACE AUFTRAG->Art WITH getArtikelArt()
                replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
                replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2
                replace AUFTRAG->Me WITH ARTIKEL->ME
                replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
                replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
                replace AUFTRAG->Preis with ARTIKEL->Preis1

                // added 20171119
                replace AUFTRAG->Inhalt with ARTIKEL->Inhalt
                replace AUFTRAG->InhaltME with ARTIKEL->InhaltME

                // replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr

                replace AUFTRAG->ABPostNr with val(hole("ABPostNr",WRITE,.t.))

                select Honselda
              endif
              skip
            enddo
          endif
        endif
      endif
      select Auftrag

    else // alter Auftrag

      select AufPost
      seek AUFAUS->AufNr
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr==AUFAUS->AufNr
        select Auftrag
        add_rec(0)
        overwrite("AufPost")

        // Erl�sgruppe des Posten �berpr�fen / anpassen
        assignErlGruppe( AUFTRAG->Erl_Gruppe )

        select AufPost
        skip
      enddo

      // bei AbrufAuftr�gen Posten merken -> Abruf.dbf
      if AUFTRAG->(reccount()) > 0 .and. merkArt<>NIL .and. merkArt $ "D"
        select Auftrag
        go top
        do while ! eof()
          if len(trim(AUFTRAG->ArtNr)) > 1
            select ABRUF
            seek AUFTRAG->ArtNr
            if eof()
              add_rec(0)
              replace ABRUF->ArtNr with AUFTRAG->ArtNr
            endif
            replace ABRUF->Menge with ABRUF->Menge-AUFTRAG->Menge
            replace ABRUF->ME with AUFTRAG->ME
            select Auftrag
          endif
          skip
        enddo
      endif

      // pr�fe auf Ph�nix-Zuschl�ge
      // if AUFTRAG->(reccount()) > 0 .and. M->versandChanged
      if M->versandChanged
        pruefeZuschlaege()
      endif

    endif

    do case
    case merkArt="D" // Artikel Rahmen-Auftrag
      set key K_F10 to artRahmAbMenge()
    case merkArt="B" // Budget Rahmen-Auftrag
      // need to do it like this, so p,l,v (default clipper) values are ignored
      SetKey( K_F10, {|| budgetRahmAbStatus(.t.,.t.)} )
    endcase

    /*** Posten editieren **/
    if AUFAUS->erledigt=="J"
      Error("Hinweis: Auftrag ist erledigt.  Kann hier nur angezeigt werden.")

      Auf_Bauch(merkArt,.t.) // view only
      // Auf_post_anzeig()
      @ 1+1,14 say AUFAUS->AufNr
      loop // we bail out
    endif

    ChangedAB:=(Auf_Bauch(merkArt) .or. ChangedKopf)

    // falls AB neu erfasst und keine Posten -> Abfrage verwerfen
    loeschNr:=""
    if OrdKeyCount() == 0
      if AUFAUS->AufNr==TEMP_NUMMER // neuer Auftrag
        if Message("Auftrag verwerfen?  (@J@/@N@)","JN")<>"N"
          loop
        endif
      else // ex. Auftrag
        text:=if(AUFAUS->AufArt=="V","Kostenvoranschlag","Auftrag")
        if Message(text+" ist leer.  "+ text+" l�schen?  (@J@/@N@)","JN") =="J"
          loeschNr:=AUFAUS->AufNr
        endif
      endif
    endif

    /* Auswahl-Menu */
    if empty( loeschNr )
      setcolor(COLWIN)
      Fenster(5,16,13,57)
      anzahl:=1
      @ 6,20 say 'Drucken als:'
      do case
      case AUFAUS->AufArt=="G" // Gutschrift
        @ 8,20 say "Gutschrift"
        Message("Ausgabe auf @D@rucker ?           @ESC@=Abbruch ")
        @ 10,20 say 'Drucker (D) ' get Ausgabe Picture "!" valid Ausgabe $"D"
        if AUFAUS->Brutto<>0
          Umgebung(WRITE)
          Error(ACHTUNG+"Gutschrift bereits gedruckt.|Soll die Gutschrift erneut berechnet werden "+;
            "?",.f.)
          erneut:=Message("Gutschrift erneut berechnen ? (@J@/@N@)","JN")
          if erneut=="N" .or. ABBRUCH
            keyboard chr(K_ESC) // ABbruch
          endif
          Umgebung(LOAD)
        endif
        read

      case AUFAUS->AufArt=="R" // Auftragsbest�tigung
        @ 8,20 say 'Auftragsbest�tigung'
        @ 10,20 say 'Anzahl Ausdrucke..............' get Anzahl Picture "9" valid Anzahl > 0;
          when Message("Anzahl Ausdrucke eingeben.      @ESC@=Abbruch")
        @ 12,20 say 'Drucker/Bildschirm/PDF (D/B/P)' get Ausgabe Picture "!" valid Ausgabe $"DBP" ;
          when Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
        read

      case AUFAUS->AufArt=="V" // Kostenvoranschlag
        @ 8,20 say 'Kostenvoranschlag '
        @ 10,20 say 'Anzahl Ausdrucke..............' get Anzahl Picture "9" valid Anzahl > 0;
          when Message("Anzahl Ausdrucke eingeben.      @ESC@=Abbruch")
        @ 12,20 say 'Drucker/Bildschirm/PDF (D/B/P)' get Ausgabe Picture "!" valid Ausgabe $"DBP";
          when Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
        read

      case AUFAUS->AufArt=="K" .and. AUFAUS->InvKZ <> "J" // K-Lager Auftrag
        @ 8,20 say 'K-Lager Auftrag'
        @ 10,20 say 'Anzahl Ausdrucke..............' get Anzahl Picture "9" valid Anzahl > 0;
          when Message("Anzahl Ausdrucke eingeben.      @ESC@=Abbruch")
        @ 12,20 say 'Drucker/Bildschirm/PDF (D/B/P)' get Ausgabe Picture "!" valid Ausgabe $"DBP";
          when Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
        read

      case AUFAUS->AufArt=="K" .and. AUFAUS->InvKZ=="J" // K-Lager Inventur Auftrag
        @ 8,20 say 'K-Lager Inventur - Sammel-Rechnung'
        @ 12,20 say 'Drucker (D)' get Ausgabe Picture "!" valid Ausgabe $"D";
          when Message("Ausgabe auf @D@rucker.  Bitte best�tigen.   @ESC@=Abbruch")
        read

      case AUFAUS->AufArt$"BD" // Rahmen Auftrag
        @ 8,20 say 'Rahmen Auftrag'
        @ 10,20 say 'Anzahl Ausdrucke..............' get Anzahl Picture "9" valid Anzahl > 0;
          when Message("Anzahl Ausdrucke eingeben.      @ESC@=Abbruch")
        @ 12,20 say 'Drucker/Bildschirm/PDF (D/B/P)' get Ausgabe Picture "!" valid Ausgabe $"DBP";
          when Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
        read

      case AUFAUS->AufArt=="N" // K-Lager Gutschrift
        // Nop, hier nicht m�glich
        loop // noch nicht freigegeben

      otherwise // default: Angebot
        @ 8,20 say 'Angebot         '
        Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
        @ 10, 20 say 'Drucker/Bildschirm/PDF (D/B/PDF) ' get Ausgabe Picture "!";
          valid Ausgabe $"DBP"
        read
      endcase


      // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
      // do while ! Login_change(12,20,"Sachbearbeiter: ")
      // enddo
      setcolor(COLNOR)

      if ABBRUCH .and. changedAB
        SetLastKey(0)
        HB_KEYCLEAR()
        Ausgabe:="P"
      endif
    endif

    /* neue Auf.Nr. vergeben */
    if AUFAUS->AufNr==TEMP_NUMMER // neuer Satz
      /* hole akt. Auft.Nr, schreiben */
      M_AufNr:=hole("AufNr",WRITE,.t.)
      /* checken ob nicht schon vorhanden */
      select AufAus
      seek M_AufNr
      if ! eof()
        Error("Auftrags"+NUMMER_DOPPELT)
      endif
      do while ! eof()
        Message("Suche n�chste freie Auftrags-Nummer.  Bitte warten...")
        M_AufNr:=hole("AufNr",WRITE,.t.)
        seek M_AufNr
      enddo
      go M->MerkNr
      rec_lock(0)
      replace AUFAUS->AUFNr with M_AufNr

      // l�sche aus Rahmenvertrag - Artikel vorgeschlagenen mit Menge 0
      if ! empty(AUFAUS->Ab_AufNr)
        select Auftrag
        delete for AUFTRAG->tempStr==RAHMAB_VORSCHLAG .and. AUFTRAG->Menge==0
      endif


      // temp. workaround f�r neue ABs in 2020
      tempMwst:=getABMwst() // FIXME: remove in 2021
      if tempMwst <> AUFAUS->MwSt
        replace AUFAUS->MwSt with tempMwst
      endif

    endif

    dbcommitall()

    /*****   drucken   *****************************************************/
    // zuerst Auftrag drucken scheint f�r User schneller
    // Nachteil: Aufaus l�nger gelockt :( */

    if ! ABBRUCH
      /* Auftrag drucken */
      DO CASE
      CASE AUFAUS->AufArt="G"

        if AUFTRAG->(reccount())>0
          /* Auftrags-Kopf  ->  Rechaus */
          auf_rech(AUFAUS->Aufart)
          Message("Gutschrift: @"+RECHAUS->RechNr+"@ wird gedruckt.  Bitte warten...")
          /* Gutschrift drucken */
          Gutschrift()
        endif

      CASE AUFAUS->AufArt$"RBD"
        /** "normaler" Auftrag */
        Message("Auftrag: @"+AUFAUS->AufNr+"@ wird gedruckt.  Bitte warten...")
        if Ausgabe$"DP" // .and. ! (TEST_PROG.or.DEVEL_PROG)
          if AUFAUS->ReBeiBlatt <> "N" .and. empty( loeschNr )
            KundenDatenBlatt(Ausgabe)
          endif
          Warenbegleitschein(Ausgabe)
        endif
        Auftrag(Ausgabe,anzahl)


      CASE AUFAUS->AufArt$"V"
        /** Kostenvoranschlag */
        Message("Kostenvoranschlag: @"+AUFAUS->AufNr+"@ wird gedruckt.  Bitte warten...")
        // if Ausgabe$"DP"
        // KundenDatenBlatt(Ausgabe)
        // endif
        if Ausgabe$"DP" .and. AUFAUS->ReBeiBlatt <> "N" .and. empty( loeschNr )
          KundenDatenBlatt(Ausgabe,"V")
        endif
        Auftrag(Ausgabe,anzahl)

      CASE AUFAUS->AufArt$"K" .and. AUFAUS->InvKZ <> "J"
        /** K-Lager Auftrag */
        Message("Auftrag: @"+AUFAUS->AufNr+"@ wird gedruckt.  Bitte warten...")
        if Ausgabe$"DP" .and. AUFAUS->ReBeiBlatt <> "N" .and. empty( loeschNr )
          KundenDatenBlatt(Ausgabe) // wird wie normale AB behandelt
          // if Ausgabe$"D"
          // Warenbegleitschein("Auftrag")
          // endif
        endif
        Auftrag(Ausgabe,anzahl)

      CASE AUFAUS->AufArt$"K" .and. AUFAUS->InvKZ=="J"
        /** K-Lager Inventur Rechnung */
        // tempSum:=0
        // dispEditorSumme("AUFAUS",,,@tempSum)
        KInventurSammelRechnung()

        /** K-Lager Gutschrift */
      CASE AUFAUS->AufArt$"N"
        // Nop, hier nicht m�glich

      OTHERWISE
        Error(ACHTUNG+" AuftragsArt "+AUFAUS->AufArt+" noch nicht vorgesehen !"+SCHWERER_FEHLER)

      ENDCASE

      // jetzt wieder beim Druck direkt
      // if Ausgabe $ "DP" .and. ! empty( dateiName )
      // sendEmails( EMAIL_AUFTRAG , dateiName )
      // endif

    endif

    /*** Posten r�ckschreiben ******************************************************************/
    Message("Auftrag wird gespeichert.  Bitte warten...")

    select AufAus
    setABFilter() // AB Filter l�schen

    M_order:=AUFPOST->(IndexOrd())
    AUFPOST->(OrdSetFocus(5)) // ABPostNr

    select Auftrag
    set filter to // mit gel�schten!
    go top

    do while ! AUFTRAG->(eof())
      // suche zugeh. Posten in AufPost
      AUFPOST->(dbseek(AUFTRAG->ABPostNr))

      diffKVMenge:=0

      // Posten gel�scht?
      if ! AUFTRAG->geloescht $ "N "

        // Auftragsbestand neu berechnen in Art.Stamm
        changedAB:=.t.

        if AUFPOST->(eof())
          // neuer Satz gel�scht -> NOP
        else

          // alter Satz gel�scht
          diffKVMenge:=AUFPOST->GeliefGes * (-1)
          bucheVKArtikel( AUFPOST->ArtNr, diffKVMenge , AUFPOST->AufNr)

          select AufPost
          rec_lock(0)
          delete
          dbcommit()
          dbunlock()
          select Auftrag

          // AufBestand( { AUFTRAG->ArtNr } )

        endif

      else // nicht gel�scht

        // nicht gefunden -> neuer Satz -> neu anlegen bzw. alten Satz l�schen
        select AufPost
        if ! AUFPOST->(eof())
          // Info: alter Datensatz kann nicht wiederverwendet werden,;
          // da sonst die Reihenfolge bei nachtr�glich eingef�gten nicht mehr stimmt.;
          // Alternativ m�sste man eine PosNr einf�hren mit entspr. Index.
          diffKVMenge:=AUFPOST->GeliefGes * (-1) // alte Menge wieder zubuchen

          // pr�fe ob Artikel-Nr. ge�ndert wurde (neu 20181108)
          if AUFTRAG->ArtNr <> AUFPOST->ArtNr
            bucheVKArtikel( AUFPOST->ArtNr, diffKVMenge , AUFPOST->AufNr)
            diffKVMenge:=0
          endif

          rec_lock(0)
          delete
          dbcommit()
          dbunlock()
        endif

        add_rec(0)
        overwrite("Auftrag")
        // muss hier gesetzt werden, da vorher evtl. nur temp. Nr. JG***
        replace AUFPOST->AufNr with AUFAUS->AufNr
        replace AUFPOST->KundNr with AUFAUS->KundNr // wurde evtl. ge�ndert
        diffKVMenge += AUFPOST->GeliefGes
        bucheVKArtikel( AUFPOST->ArtNr, diffKVMenge , AUFPOST->AufNr)

      endif

      select Auftrag
      skip
    enddo
    AUFPOST->(OrdSetFocus(1)) // AufNr (default)

    // neu: filter auf ungel�schte Posten
    select Auftrag
    set filter to AUFTRAG->geloescht$"N "
    go top

    /******************  Rahmenauftrag? ******************************************/
    if ABRUF->(RECCOUNT()) > 0 .or. ! empty(AUFAUS->Ab_AufNr)

      // pr�fe Art des Rahmenauftrags
      if merkArt==NIL
        merkArt:=getRahmABArt()
      endif

      // Artikel Rahmen-Auftrag
      switch merkArt
      case "B" // Rahmenauftrag - Budget
        budgetRahmAbStatus(.f.,.t.,.t.)
        exit
      case "D" // Rahmenauftrag - Artikel
        select AufPost
        M_order:=AUFPOST->(IndexOrd())
        AUFPOST->(OrdSetFocus(3)) // AufNr+Anr

        // Mengen�nderung in Rahmen-Auftrag zur�ckschreiben
        select Auftrag
        go top
        do while ! AUFTRAG->(eof())
          if len(alltrim(AUFTRAG->ArtNr))>1
            Message("Artikel: @"+AUFTRAG->ArtNr+"@ wird abgetragen.   Bitte warten...")
            select Abruf
            ABRUF->(dbseek(AUFTRAG->ArtNr))
            if ABRUF->(eof())
              tempSum:=0
            else
              // ABRUF->Menge ist hier negativ!!!
              tempSum:=abs(ABRUF->Menge)
              delete // nur 1x abziehen, falls Artikel �fters in AB vorkommt
            endif

            // jetzt auf alle offene Posten der Rahmen-AB verteilen
            select AufPost
            tempSum:=AUFTRAG->Menge - tempSum

            rahmAbtrag( AUFAUS->KundNr , AUFTRAG->ArtNr , tempSum , AUFTRAG->ME )
          endif
          select Auftrag
          skip
        enddo

        // restl. Posten in Abruf sind aus AB gel�scht und m�ssen abgezogen werden
        select Abruf
        go top
        do while ! ABRUF->(eof())
          if len(alltrim(ABRUF->Artnr))>1
            rahmAbtrag( AUFAUS->KundNr , ABRUF->ArtNr , ABRUF->Menge , ABRUF->ME )
          endif
          skip
        enddo
        zap // immer leer

        /** Auftrag erledigt ? */
        rahmAberledigt()

      endswitch
    endif


    // AB l�schen falls leer und best�tigt
    if ! empty(loeschNr)
      select AufAus
      dbseek( loeschNr )
      rec_lock(0)
      delete
    endif

    dbcommitall()
    unlock all

    // Auftragsbestand neu berechnen jetzt nach jedem Auftrag, seit 8.9.2013
    if changedAB

      resetABMatKennzeichen()
      checkUSALimit("Aufaus")
      AufBestand()

      // seit 13.2.14 Zahl.Kond. vom Rechn.epf�nger pr�fen, seit 20180717 erst am Ende, wegen der neuen AB-Nr.
      KUNDEN->(dbseek(AUFAUS->R_KundNr))
      if KUNDEN->(eof()) .or. empty(KUNDEN->ZKNr)
        subject:="Rechnungsempf�nger ohne Zahlungskonditionen: "+KUNDEN->KundNr
        body:="AB-Nr: "+AUFAUS->AufNr +MY_CR+MY_LF
        body+="Kunde: "+AUFAUS->KundNr+" "+AUFAUS->KurzName +MY_CR+MY_LF
        body+="Re.Kd: "+KUNDEN->KundNr+" "+KUNDEN->KurzName;
          + " ohne Zahlungskonditionen!" +MY_CR+MY_LF
        body+="K�rzel: "+getUser():id +MY_CR+MY_LF
        // EMail an H. Weiland
        email(MAIN_EMAIL,subject,body)
      endif

      // pr�fe Material Verf�gbarkeit
      // if AUFAUS->AufArt$"RBD"
      // checkMaterialVerfuegbar()
      // endif

      changedAb:=.f.
    endif

    // pr�fe ob Email an H. Weiland , z.B. wegen abweichender Versart etc.
    sendEmailMW( M->emailAbweichend )

  enddo // Ende Auftrags-Erfassung

  /* neuen Datensatz l�schen ? */
  select AufAus
  seek TEMP_NUMMER
  do while ! eof() .and. AUFAUS->AufNr==TEMP_NUMMER
    rec_lock(0)
    delete
    skip
  enddo

  close data
  set key K_F9 to
  set key K_F10 to
  Ang_Hotkey("OFF")

RETURN
/* EOP Auf_erfassen */


/* Function Auf_Kopf
*
* Eingabe des Auftrag-kopfes
*
* Parameters: 0 == komplett �nderbar
*             1 == AufNr fix , Rest �nderbar
*             2 == nur anzeigen
* R�ckgabe  : Ende ja/nein
*/
FUNCTION Auf_Kopf(Edit)
LOCAL GetList:={}
LOCAL M_AufNr
LOCAL ob:=0

  if edit==0
    M_AufNr:=hole("AufNr",LOAD) // hole neuste AuftragsNr, nur lesen
    @ ob+2,14 get M_AufNr picture '@K #####' ;
      valid { |oGet| shift(oGet) .and. AufNr_nach(oGet) };
      when ( Message('Auftragsnummer eingeben.             @F12@=Hilfe') .and. Ang_Hotkey("OFF") )
    setCargo(ATail(GetList),CARGO_EXIT_ALLOWED,.t.) // Valid Klause darf hier mit ESC durchgesetzt
    setCargo(ATail(GetList),CARGO_UPDATE_IGNORE,.t.) // �nderungen an ABNr setzen nicht slUpdated
  else
    @ ob+2,14 say AUFAUS->AufNr
  endif

  // Rahmenauftrag / Abrufauftrag
  if M->istAbrufAuftrag<>NIL
    @ ob+3,14 GET AUFAUS->AB_AufNr valid { |oGet| Ab_AufNr_Nach(oGet) };
      when Ab_aufnr_vor() .and. Message("Rahmenauftragsnummer eingeben      @F12@=Hilfe")
    setCargo(ATail(GetList),CARGO_EXIT_ALLOWED,.t.) // Valid Klause darf hier mit ESC durchgesetzt
  endif


  /* anschriften */
  // mit Angebots-Uebernahme au�er bei RahmenAB und Abruf Artikel
  if ((empty(AUFAUS->KundNr) .or. AUFAUS->KundNr==KDNR_LEER) ;
    .and. ! M->defAuftrArt$"BD" .and. M->istAbrufAuftrag <> "D") .or.;
    M->istAbrufAuftrag == "B" // immer bei Budget-Abruf 20240419

    @ ob+2,38 get AUFAUS->KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) .and. KundNr_nach(oGet)};
      when ( Message("Kunden-Nummer eingeben.   " +;
      if( empty( AUFAUS->KundNr) .or. M->istAbrufAuftrag == "B", " @F3@=Angebot �bernehmen " , "" ) + ;
      "  @F5@=Sprache �ndern  @F12@=Hilfe") .and. Ang_Hotkey("ON") )
  else
    @ ob+2,38 get AUFAUS->KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) .and. KundNr_nach(oGet)};
      when Message('Kunden-Nummer eingeben.     @F5@=Sprache     @F12@=Hilfe')
  endif
  if M->istAbrufAuftrag <> NIL
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klause wird auch bei ESC durchgesetzt
  else
    setCargo(ATail(GetList),CARGO_EXIT_ALLOWED,.t.) // Valid Klause darf hier mit ESC durchgesetzt
  endif

  @ ob+4,38 get AUFAUS->V_KundNr PICTURE KDNR_PICT;
    when ( Message("Kundennummer Versand eingeben  @F5@=Sprache @F6@=Sammelstelle @F12@=Hilfe") ;
    .and. Ang_Hotkey("OFF") ;
    .and. MySetKey( K_F6 , {|| sammelEdit()}) ) ;
    valid { |oGet| check(oGet,"Kunden",.f.) .and. V_KundNr_nach(oGet) .and. MySetKey( K_F6 , nil) }
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  @ ob+8,38 get AUFAUS->R_KundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",;
    .f.) .and. R_KundNr_nach(oGet) .and. MySetKey( K_F6 ,;
    nil) } when Message("Kundennr. Rechnung "+ "eingeben   @F5@=Sprache  @F6@=alternat. Rechn. "+;
    "Adresse  @F12@=Hilfe") .and. MySetKey( K_F6 , {|| alternativeAdrEdit()})
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  /* Datum,Art,Bestkto */
  @ ob+5,14 GET AUFAUS->AufDat when Message('Auftragsdatum eingeben        @*@=Heute @+@/@-@')
  @ ob+6,14 get AUFAUS->VersNr picture "@9" ;
    valid { |oGet| VersNr_nach(oGet) ;
    .and. Auf_kopf_disp() } when Message('Versandart eingeben.             @F12@=Hilfe')
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+7,14 get AUFAUS->SpedNr picture "@9" valid { |oGet| AufSpedNach(oGet) .and. Auf_kopf_disp() };
    when { || AufSpedVor() }

  @ ob+11,1 GET AUFAUS->BestKonto valid {|oGet| bestKtoNach(oGet)} ;
    when Message('Lieferschein-Nummer eingeben.')
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+13,1 GET AUFAUS->BestDat valid ! empty(AUFAUS->BestDat) when Message('Bestelldatum '+;
    'eingeben        @*@=Heute @+@/@-@')
  @ ob+15,1 GET AUFAUS->BestNr when Message('Bestell - Nr. eingeben.') .and. BestNrVor() ;
    valid {|oGet| bestNrNach(oGet)}
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  if AUFAUS->R_Land <> DEUTSCH_LAND
    @ ob+16,1 say "Fremd-W�hrung:" GET AUFAUS->FremdWaehr Picture "@!" when Message('Fremdw�hrung '+;
      'K�rzel eingeben.')
    @ ob+17,1 say "Fremd-Summe..:" GET AUFAUS->FremdSumme when Message('Summe in Fremdw�hrung '+;
      'eingeben.')
  endif

  if ! M->defAuftrArt$"IKG" // nicht bei K-Lager und Gutschrift
    @ ob+12,43 get AUFAUS->So_Rabatt valid { |oGet| val(oGet:buffer)>=0 .and. SoRabatt_nach(oGet) } ;
      when Message("Sonder/H�ndler-Rabatt eingeben. ")

    @ ob+12,74 get AUFAUS->Zuschlag valid { |oGet| val(oGet:buffer)>=0 } ;
      when Message("Energiekosten-Zuschlag eingeben. ")

    @ ob+13,43 get AUFAUS->ZKNr picture "@9" ;
      valid { |oGet| zkNr_nach(oGet) };
      when Message("Zahlungskondition eingeben.   @F12@=Hilfe")
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

    @ ob+13,59 get AUFAUS->MWSt_Kz picture "@9" valid { |oGet| check(oGet,"Mwst_kz",;
      .f.) .and. Auf_Mwst_nach(oGet) } when Auf_Mwst_vor() .and. Message("MWST - KZ eingeben.     "+;
      "      @F9@=Ident.Nr. �ndern    @F12@=Hilfe")
    @ ob+14,74 get AUFAUS->TextKz_Nr picture "@K@!" valid { |oGet| check(oGet,;
      "Text_Kz") } when Message("Werbe - Text KZ eingeben.     @F12@=Hilfe")


    /* Rechnungsbeiblatt drucken? */
    @ ob+16,51 get AUFAUS->ReBeiBlatt valid AUFAUS->ReBeiBlatt $ "JN" picture "!" ;
      when Message('Rechnungsbeiblatt drucken? (@J@/@N@)')

    /* Zoll-Zuschlag hinzuf�gen bei nicht EU Kunden? */
    @ ob+17,51 get AUFAUS->ZollZuschl picture "!" valid {|oGet| nachZollZuschlag(oGet)};
      when Message('Zoll/Eur1 Zuschlag automatisch hinzuf�gen? (@J@/@N@)')

    /* Ph�nix Fracht automatisch berechnen?  s. auch property: phoenix.fracht.automatisch */
    @ ob+17,58 get AUFAUS->PhoenixFr picture "!" ;
      when Message('Ph�nix Fracht automatisch hinzuf�gen? (@J@/@N@)')

    // Ansprechpartner, siehe auch editAnsprechPartner()
    @ 20, 1 get AUFAUS->Ansprech;
      when;
      Message("Ansprechpartner eingeben   @F12@=Kundendaten "+;
      "�bernehmen") .and. MYSetKey( K_F12 , {|p1,oGet| copy_kunden_kontakt(oGet,;
      p1) } ) valid MYSetKey( K_F12 , {|p1,oGet| Hilfe(p1,oGet)} )

    @ 22,1 get AUFAUS->Email picture "@S47" ;
      valid {|oget| isValidEmail(oget) .and. MYSetKey( K_F12 , {|p1,oGet| Hilfe(p1,oGet)} )} ;
      when Message("Email-Adresse eingeben   @F12@=Kundendaten �bernehmen") .and.;
      MYSetKey( K_F12 , {|p1,oGet| copy_kunden_kontakt(oGet,p1) } )

    @ 20,49 get AUFAUS->Telefon when Message("Telefonnummer eingeben   @F12@=Kundendaten �bernehmen") ;
      .and. MYSetKey( K_F12 , {|p1,oGet| copy_kunden_kontakt(oGet,p1) } ) ;
      valid MYSetKey( K_F12 , {|p1,oGet| Hilfe(p1,oGet)} )

    @ 22,49 get AUFAUS->Fax when Message("Faxnummer eingeben   @F12@=Kundendaten �bernehmen") ;
      .and. MYSetKey( K_F12 , {|p1,oGet| copy_kunden_kontakt(oGet,p1) } ) ;
      valid MYSetKey( K_F12 , {|p1,oGet| Hilfe(p1,oGet)} )

  endif
  if ! edit==2
    set key K_F5 to aendSprache()
    read
    set key K_F5 to
  endif
  set key K_F9 to

RETURN ! (empty(AUFAUS->KundNr) .or. AUFAUS->KundNr==KDNR_LEER)
/* EOF AufKopf */

/* Function SoRabatt_nach()
*
* wird nach Eingabe des SoRabatts ausgef�hrt
*/
FUNCTION SoRabatt_nach(oGet)
  if oGet:changed .and. val(oGet:buffer)>0 .and. empty(KUNDEN->Rabatt_KZ)
    if Message("Sonderrabatt ? ( J / N ) ","JN")=="J"
      replace AUFAUS->Rabatt_KZ with " "
    else
      replace AUFAUS->Rabatt_KZ with "H"
    endif
    Auf_Kopf_Disp()
  endif

RETURN(.t.)


/*
* wird nach Eingabe der Versandart ausgef�hrt
*/
FUNCTION VersNr_nach(oGet)
LOCAL aktRec:=KUNDEN->(recno())

  if M->defAuftrArt=="I" .and. empty(oGet:buffer) // Ausnahme K-Lager Inventur-Auftrag
    return .t.
  endif

  if ! check(oGet,"VersArt",if(AUFAUS->AufArt$"G",.t.,.f.))
    return .f.
  endif

  if oGet:changed
    KUNDEN->(dbseek( AUFAUS->V_KundNr ))
    if oGet:buffer <> KUNDEN->VersNr .and. ! empty( oGet:buffer) .and. ! empty(KUNDEN->VersNr)
      if Message("Abweichende Versandart verwenden? ( J / N ) ","JN") <> "J" .or. ABBRUCH
        return .f.
      endif
      M->emailAbweichend:=hb_bitOr( M->emailAbweichend , EMAIL_ABWEICHENDE_VERSART )
    endif
    KUNDEN->(dbgoto( aktRec ))
  endif

RETURN(.t.)
/** eof */

/*
* wird nach Eingabe der Zahlungskondition ausgef�hrt
*/
FUNCTION ZkNr_nach(oGet)
LOCAL aktRec:=KUNDEN->(recno())

  if ! check(oGet,"ZahlKond",.f.)
    return .f.
  endif

  if oGet:changed
    KUNDEN->(dbseek( AUFAUS->R_KundNr ))
    if oGet:buffer <> KUNDEN->ZkNr .and. ! empty( KUNDEN->ZkNr )
      if Message("Abweichende Zahlungskonditionen verwenden? ( J / N ) ","JN") <> "J" .or. ABBRUCH
        return .f.
      endif
      M->emailAbweichend:=hb_bitOr( M->emailAbweichend , EMAIL_ABWEICHENDE_ZAHLKOND )
    endif
    KUNDEN->(dbgoto( aktRec ))
  endif

RETURN(.t.)
/** eof */


/* Function BestKtoNach()
*
* wird nach Eingabe des Best.Kontos/Lieferscheinnr ausgef�hrt
*/
static FUNCTION BestKtoNach(oGet)

  // Bei Abrufauftrag und KV ist Eingabe Pflicht
  if (AUFAUS->AufArt$"V" .or. M->istAbrufAuftrag) <> NIL .and.;
    ( empty(oGet:buffer) .or. ;
    (oGet:changed .and. ! lastkey()==K_UP .and. emptyOr2Simple(oGet:buffer , 5) ))
    return .f.
  endif

return .t.
/** eof */

/* Function BestNrVor()
*
* wird vor Eingabe der Best.Nummer ausgef�hrt
*/
static FUNCTION BestNrVor()

  // bei KV und Abrufauftrag nicht �nderbar
  if AUFAUS->Aufart$"V" .or. M->istAbrufAuftrag <> NIL
    return .f.
  endif

return .t.
/** eof */

/* Function BestNrNach()
*
* wird nach Eingabe des Best.Nummer ausgef�hrt
*/
static FUNCTION BestNrNach(oGet)

  // Bei Rahmenauftrag und ist Eingabe Pflicht
  if empty(oGet:buffer) .or. ;
    ( oGet:changed .and. AUFAUS->AufArt$"BDKRA" .and. ! lastkey()==K_UP ;
    .and. emptyOr2Simple(oGet:buffer , 5) )
    return .f.
  endif

return .t.
/** eof */




/* Funktionen f�r Kopfeingabe   *************************
*/
/* nach Auft.Nr */
STATIC FUNCTION AufNr_nach(oGet)
LOCAL M_AufNr, aktRec, tempArt

  if ! lastkey()==K_RETURN
    RETURN(.f.)
  endif
  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
  endif

  select AufAus

  /* vorher neuer Satz, jetzt immer noch */
  if oGet:buffer==TEMP_NUMMER
    go M->MerkNr
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
          Error("Aufaus.dbf"+DATEI_EXCL)
          RETURN(.f.)
        endif
        M->MerkNr:=recno()
        if M->defAuftrArt=="I" // Ausnahme K-Lager Inventur-Auftrag
          REPLACE AUFAUS->AufArt WITH "K" // ACHTUNG abweichend zu M->defAuftrArt
          REPLACE AUFAUS->InvKZ WITH "J"
          REPLACE AUFAUS->BestNr WITH "Inventur "+alltrim(str(year(getUser():date)-1)) // letzes Jahr
        else
          REPLACE AUFAUS->AufArt WITH M->defAuftrArt
        endif
        REPLACE AUFAUS->AufNr WITH TEMP_NUMMER
        REPLACE AUFAUS->AufDat WITH getUser():date
        REPLACE AUFAUS->BestDat WITH getUser():date
        REPLACE AUFAUS->MWST_KZ WITH "1"
        if M->defAuftrArt <> "G" // Ausnahme Gutschrift
          REPLACE AUFAUS->Zuschlag WITH val(getProperty("Miki.energiekostenzuschlag","0.0"))
        endif
        MWST_KZ->(dbseek("1"))
        REPLACE AUFAUS->MWST WITH MWST_KZ->MWST
        REPLACE AUFAUS->ReBeiBlatt with "J"
      else

        // evtl. falsche Auftragsart
        set filter to
        seek oGet:buffer
        if eof()
          M_AufNr:=hole("AufNr",LOAD) // hole akt. Auft.Nr, lesen
          Error("Auftrag: "+oget:buffer+NICHT_VORHANDEN)
          oget:varput(M_AufNr)
          oGet:updateBuffer()
          oGet:killfocus()
          oGet:setfocus()
          M->MerkNr:=0
          setAbFilter(M->defAuftrArt)
          RETURN(.f.)
        else // falsche Auftr.Art
          if M->istAbrufAuftrag == NIL .and. !empty(AUFAUS->Ab_AufNr)
            Error(ACHTUNG+" �ndern von Abrufauftrag nur unter Menupunkt 2.13 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->istAbrufAuftrag <> NIL .and. empty(AUFAUS->Ab_AufNr)
            Error(ACHTUNG+" Kein Abrufauftrag!")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt=="G" .and. Aufaus->Aufart <> "G"
            Error(ACHTUNG+" Nur �ndern von Gutschriften m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"G" .and. Aufaus->Aufart == "G"
            Error(ACHTUNG+" �ndern von Gutschriften nur unter Menupunkt 2.6 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"K" .and. Aufaus->Aufart == "K"
            Error(ACHTUNG+" �ndern von K-Lager Auftrag nur unter Menupunkt 2.21 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"I" .and. Aufaus->Aufart == "K" .and. AUFAUS->InvKZ=="J"
            Error(ACHTUNG+" �ndern von Inventur K-Lager Auftrag nur unter Menupunkt 8.9.19.7 "+;
              "m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"N" .and. Aufaus->Aufart == "N"
            Error(ACHTUNG+" �ndern von K-Lager Gutschrift noch nicht m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt=="K" .and. AUFAUS->Aufart<>"K"
            Error(ACHTUNG+"Kein K-Lager Aufftrag.",.t.)
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"D" .and. Aufaus->Aufart == "D"
            Error(ACHTUNG+" �ndern von Rahmenauftrag Artikel nur unter Menupunkt 2.10 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"B" .and. Aufaus->Aufart == "B"
            Error(ACHTUNG+" �ndern von Rahmenauftrag Budget nur unter Menupunkt 2.11 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt=="D" .and. Aufaus->Aufart <> "D"
            Error(ACHTUNG+" nur Rahmenauftrag m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt=="B" .and. Aufaus->Aufart <> "B"
            Error(ACHTUNG+" nur Rahmenauftrag m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt=="V" .and. Aufaus->Aufart <> "V"
            Error(ACHTUNG+" nur Kostenvoranschlag m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          elseif M->defAuftrArt<>"V" .and. Aufaus->Aufart == "V"
            Error(ACHTUNG+" �ndern von Kostenvoranschlag nur unter Menupunkt 2.8 m�glich !")
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          else
            Error(ACHTUNG+" Auftragsart:"+Aufaus->Aufart+" kann hier nicht bearbeitet werden."+;
              SCHWERER_FEHLER)
            M->MerkNr:=0
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          endif

        endif
      endif
    else // ! eof

      // pr�fe ob Auftrag bereits erledigt, dann nur anzeigen
      if AUFAUS->erledigt=="J"
        oGet:killfocus()
        Auf_Kopf_disp()
        Auf_Kopf(2) // auftrag anzeigen
        Message("Bitte @Taste@ dr�cken","@")
        keyboard chr(K_PGDN) // we bail out
      else

        // pr�fe auf korrekte Abrufauftrags-Art, if applicable
        // kann trotz Filter schief gehen
        if M->istAbrufAuftrag <> NIL .and. oGet:changed
          // suche Rahmenauftrag um Art festzustellen Artikel / Budget
          set filter to
          aktRec:=AUFAUS->(recno())
          AUFAUS->(dbseek( AUFAUS->Ab_AUfNr ))
          tempArt:=AUFAUS->AufArt
          setAbFilter(M->defAuftrArt)
          AUFAUS->(dbgoto( aktRec ))
          if tempArt <> M->istAbrufAuftrag
            if M->istAbrufAuftrag == "B"
              Error(ACHTUNG+" Hier nur Abrufauftrag Budget m�glich!")
            else
              Error(ACHTUNG+" Hier nur Abrufauftrag Artikel m�glich!")
            endif
            setAbFilter(M->defAuftrArt)
            RETURN(.f.)
          endif
        endif

        // gefunden und immer richtige AuftrArt, dank filter
        if ! Rec_Lock(5)
          Error(SATZ_EXCL)
          RETURN(.f.)
        endif
      endif
      M->MerkNr:=recno()

      /** w�hle Sprache je nach Empf�nger */
      selLandBySprache(AUFAUS->Sprache)
    endif

  endif

  Auf_kopf_disp()
  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  // sicher(WRITE) // merke akt. Werte

RETURN(.t.)
/* EOF AufNr_nach */


/* nach KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
static FUNCTION KundNr_nach(oGet)
LOCAL spedits, rahmAbNr

  if oGet:changed

    if ! IS_KUNDE_AB
      Error(ACHTUNG+" Nur Hauptkunden zul�ssig.||Keine Versand- oder Rechnungsadressen."+;
        "||Bitte Eingabe �berpr�fen",.t.)
      return .f.
    endif

    if empty(KUNDEN->Name) .and. empty(KUNDEN->Partner)
      Error(ACHTUNG+" leere Kunden-Adresse nicht mehr zul�ssig.",.t.)
      return .f.
    endif

    if ! M->defAuftrArt$"B"
      rahmAbNr:=getBudgetAuftragNr(oGet:buffer)
      if ! empty(rahmAbNr)
        Error(ACHTUNG+"F�r "+trim(KUNDEN->KurzName)+" existiert ein Rahmenauftrag:"+rahmAbNr+".||"+;
          "         Bitte evtl. Men�-Punkt 2.14 verwenden",.t.)
      endif
    endif

    REPLACE AUFAUS->Name WITH KUNDEN->Name
    REPLACE AUFAUS->KurzName WITH KUNDEN->KurzName
    REPLACE AUFAUS->Partner WITH KUNDEN->Partner
    REPLACE AUFAUS->Strasse WITH KUNDEN->Strasse
    REPLACE AUFAUS->Zusatz WITH KUNDEN->Zusatz
    REPLACE AUFAUS->Plz WITH KUNDEN->PLZ
    REPLACE AUFAUS->Land WITH KUNDEN->Land
    REPLACE AUFAUS->Ort WITH KUNDEN->Ort
    REPLACE AUFAUS->Sprache WITH KUNDEN->Sprache

    // Sammelstelle
    REPLACE AUFAUS->S_Name WITH KUNDEN->S_Name
    REPLACE AUFAUS->S_Partner WITH KUNDEN->S_Partner
    REPLACE AUFAUS->S_Strasse WITH KUNDEN->S_Strasse
    REPLACE AUFAUS->S_Zusatz WITH KUNDEN->S_Zusatz
    REPLACE AUFAUS->S_Plz WITH KUNDEN->S_PLZ
    REPLACE AUFAUS->S_Land WITH KUNDEN->S_Land
    REPLACE AUFAUS->S_Ort WITH KUNDEN->S_Ort
    REPLACE AUFAUS->S_Sprache WITH KUNDEN->S_Sprache

    /* Versand-KundenNr */
    if KUNDEN->VA <> "J" // Versandanschrift gleich
      if empty(KUNDEN->Name2) .and. empty(KUNDEN->Partner2)
        Error(ACHTUNG+" leere Kunden-Adresse nicht mehr zul�ssig.",.t.)
        return .f.
      endif

      REPLACE AUFAUS->V_KundNr WITH AUFAUS->KundNr
      REPLACE AUFAUS->V_Name WITH KUNDEN->Name2
      REPLACE AUFAUS->V_Partner WITH KUNDEN->Partner2
      REPLACE AUFAUS->V_Strasse WITH KUNDEN->Strasse2
      REPLACE AUFAUS->V_Zusatz WITH KUNDEN->Zusatz2
      REPLACE AUFAUS->V_Plz WITH KUNDEN->PLZ2
      REPLACE AUFAUS->V_Land WITH KUNDEN->Land2
      REPLACE AUFAUS->V_Ort WITH KUNDEN->Ort2
      REPLACE AUFAUS->V_Sprache WITH KUNDEN->Sprache2

      // pr�fe auf DATEV-Nummern Kreislauf - Deutschland oder Drittland
      if ! checkDatevNr( AUFAUS->V_KundNr , AUFAUS->V_Land )
        return .f.
      endif

      if ! checkIdentNr(oGet:buffer)
        return .f.
      endif

      // Ident.Nr. und MwSt nach Lieferanschrift
      REPLACE AUFAUS->IdentNr WITH KUNDEN->IdentNr
      setzeMwstEgKZ()

      // Spedition ebenfalls nach Lieferanschrift (16.11.15)
      spedits:=getKundSpedits( KUNDEN->KundNr )
      if len(spedits) == 1 // ansonsten muss der Benutzer manuell ausw�hlen!
        REPLACE AUFAUS->SpedNr WITH spedits[1]
      else
        REPLACE AUFAUS->SpedNr WITH ""
      endif

      // VA ebenfalls nach Lieferanschrift (5.5.15)
      if M->defAuftrArt <> "I" // Ausnahme K-Lager Inventur-Auftrag
        REPLACE AUFAUS->VersNr WITH KUNDEN->VersNr
      endif

    else
      REPLACE AUFAUS->V_KundNr WITH ""
    endif
    /* Rechnungs-Anschrift */
    if empty(KUNDEN->RechAnschr) // Rechnungsanschrift gleich
      REPLACE AUFAUS->R_KundNr WITH AUFAUS->KundNr
      REPLACE AUFAUS->R_Name WITH KUNDEN->Name
      REPLACE AUFAUS->R_Partner WITH KUNDEN->Partner
      REPLACE AUFAUS->R_Strasse WITH KUNDEN->Strasse
      REPLACE AUFAUS->R_Zusatz WITH KUNDEN->Zusatz
      REPLACE AUFAUS->R_Plz WITH KUNDEN->PLZ
      REPLACE AUFAUS->R_Land WITH KUNDEN->Land
      REPLACE AUFAUS->R_Ort WITH KUNDEN->Ort
      REPLACE AUFAUS->R_Sprache WITH KUNDEN->Sprache

      // ZK ebenfalls nach Rechn.anschrift (5.5.15)
      REPLACE AUFAUS->ZKNr WITH KUNDEN->ZKNr

      // alternative Rechnungsadresse
      REPLACE AUFAUS->A_Name WITH KUNDEN->A_Name
      REPLACE AUFAUS->A_Partner WITH KUNDEN->A_Partner
      REPLACE AUFAUS->A_Strasse WITH KUNDEN->A_Strasse
      REPLACE AUFAUS->A_Zusatz WITH KUNDEN->A_Zusatz
      REPLACE AUFAUS->A_Plz WITH KUNDEN->A_PLZ
      REPLACE AUFAUS->A_Land WITH KUNDEN->A_Land
      REPLACE AUFAUS->A_Ort WITH KUNDEN->A_Ort

    else
      REPLACE AUFAUS->R_KundNr WITH ""

      // l�sche alternative Rechnungsadresse 20180308
      altAdrDel()

    endif

    REPLACE AUFAUS->So_Rabatt WITH KUNDEN->So_Rabatt
    REPLACE AUFAUS->Rabatt_KZ WITH KUNDEN->Rabatt_KZ

    REPLACE AUFAUS->LiefNr WITH KUNDEN->Lfd_Nr

    // Ausnahme Honsel ohne Energiekostenzuschlag 21.3.23
    if left(AUFAUS->KundNr,5) $ getProperty("Miki.energiekostenzuschlag.ausnahme","")
      REPLACE AUFAUS->Zuschlag WITH 0
    endif

    AUFAUS->(dbcommit())

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(AUFAUS->Sprache)

    // Hinweis falls Werkzeug und andere Artikel gemeinsam angeboten werden
    // geht bei ausl�nd. Kunden nicht
    checkWerkzeug()

    Auf_kopf_disp()
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif

RETURN(.t.)
/* EOF LiefNr_nach */


/* nach Versand-KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
static FUNCTION V_KundNr_nach(oGet)
LOCAL spedits

  if oGet:changed

    if ! IS_KUNDE_VERSAND
      Error(ACHTUNG+" Nur Versandkunden (-11 bis -99) zul�ssig.||Bitte Eingabe �berpr�fen",.t.)
      return .f.
    endif

    if ! checkIdentNr(oGet:buffer)
      return .f.
    endif

    if empty(KUNDEN->Name2) .and. empty(KUNDEN->Partner2)
      Error(ACHTUNG+" leere Kunden-Adresse nicht mehr zul�ssig.",.t.)
      return .f.
    endif

    REPLACE AUFAUS->V_Name WITH KUNDEN->Name2
    REPLACE AUFAUS->V_Partner WITH KUNDEN->Partner2
    REPLACE AUFAUS->V_Strasse WITH KUNDEN->Strasse2
    REPLACE AUFAUS->V_Zusatz WITH KUNDEN->Zusatz2
    REPLACE AUFAUS->V_Plz WITH KUNDEN->PLZ2
    REPLACE AUFAUS->V_Land WITH KUNDEN->Land2
    REPLACE AUFAUS->V_Ort WITH KUNDEN->Ort2
    if M->defAuftrArt <> "I" // Ausnahme K-Lager Inventur-Auftrag
      REPLACE AUFAUS->VersNr WITH KUNDEN->VersNr
    endif

    if trim(AUFAUS->V_Land) $ getProperty("Miki.phoenix.fracht.automatisch","")
      REPLACE AUFAUS->PhoenixFr with "J"
    else
      REPLACE AUFAUS->PhoenixFr with "N"
    endif

    // Spedition ebenfalls nach Lieferanschrift (5.5.15)
    spedits:=getKundSpedits( KUNDEN->KundNr )
    if len(spedits) == 1 // ansonsten muss der Benutzer manuell ausw�hlen!
      REPLACE AUFAUS->SpedNr WITH spedits[1]
    else
      REPLACE AUFAUS->SpedNr WITH ""
    endif

    // pr�fe auf DATEV-Nummern Kreislauf - Deutschland oder Drittland
    if ! checkDatevNr( AUFAUS->V_KundNr , AUFAUS->V_Land )
      return .f.
    endif

    // IdentNr und Mwst anhand der Versandanschrift
    REPLACE AUFAUS->IdentNr WITH KUNDEN->IdentNr
    setzeMwstEgKZ()

    REPLACE AUFAUS->V_Sprache WITH KUNDEN->Sprache2

    // Sammelstelle
    REPLACE AUFAUS->S_Name WITH KUNDEN->S_Name
    REPLACE AUFAUS->S_Partner WITH KUNDEN->S_Partner
    REPLACE AUFAUS->S_Strasse WITH KUNDEN->S_Strasse
    REPLACE AUFAUS->S_Zusatz WITH KUNDEN->S_Zusatz
    REPLACE AUFAUS->S_Plz WITH KUNDEN->S_PLZ
    REPLACE AUFAUS->S_Land WITH KUNDEN->S_Land
    REPLACE AUFAUS->S_Ort WITH KUNDEN->S_Ort
    REPLACE AUFAUS->S_Sprache WITH KUNDEN->S_Sprache

    Auf_kopf_disp()

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(AUFAUS->Sprache)

    // Hinweis falls Werkzeug und andere Artikel gemeinsam angeboten werden
    // geht bei ausl�nd. Kunden nicht
    checkWerkzeug()

    M->versandChanged:=.t.

    AUFAUS->(dbcommit())
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif
RETURN(.t.)
/* EOF V_KundNr_Nach */

/** Setzt die Mwst und EG Kennzeichen anhand des akt. Kunden */
PROCEDURE setzeMwstEgKZ(Datei)
LOCAL aktRec
LOCAL aktEG, aktMwstKZ

  default datei:="Aufaus"
  aktEG:=&(datei)->EG
  aktMwstKZ:=&(datei)->MwSt

  // nehme MwSt anhand Lieferanschrift, au�er bei EU Kunden, da h�ngts vom Werkzeug ab oder nicht
  // if ! empty(&(datei)->MwSt_Kz) .and. upper(KUNDEN->EG)=="J"
  if upper(KUNDEN->EG)=="D"
    REPLACE &(datei)->MwSt_Kz WITH KUNDEN->MwSt_Kz
    MWST_KZ->(dbseek(KUNDEN->Mwst_Kz))
    REPLACE &(datei)->MwSt WITH MWST_KZ->MwSt

    // bei abweichender MwSt Textbaustein vorschlagen
    if KUNDEN->MwSt_kz<>"1" .and. upper(datei)=="AUFAUS"
      REPLACE AUFAUS->TextKz_Nr WITH getProperty("fakt.13b","4 ")
    endif

  else
    // EU Kunde und Nicht EU-Kunde, pr�fe auf Werkzeug -> Mwst wird berechnet
    aktRec:=recno()
    loca for len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. getArtikelArt()=="W"
    if ! eof()
      go (aktRec)
      replace &(datei)->Mwst_KZ with "1"
      MWST_KZ->(dbseek("1"))
    else
      go (aktRec)
      replace &(datei)->Mwst_KZ with "0"
      MWST_KZ->(dbseek("0"))
    endif
    REPLACE &(datei)->MwSt WITH MWST_KZ->MwSt
  endif
  REPLACE &(datei)->EG WITH KUNDEN->EG

  if ! (DATEI)->EG $ "DJ"
    REPLACE &(datei)->ZollZuschl WITH "J"
  else
    REPLACE &(datei)->ZollZuschl WITH "N"
  endif

return
/** eop */

/* nach Rechnungs-KundenNummer
*  steht auf richtigem Satz in Kunden, da check(oGet) !
*/
static FUNCTION R_KundNr_nach(oGet)

  if oGet:changed

    if ! IS_KUNDE_RECHNUNG
      Error(ACHTUNG+" Nur Rechnungskunden (-01 bis -10) zul�ssig.||Bitte Eingabe �berpr�fen",.t.)
      return .f.
    endif

    if empty(KUNDEN->Name) .and. empty(KUNDEN->Partner)
      Error(ACHTUNG+" leere Kunden-Adresse nicht mehr zul�ssig.",.t.)
      return .f.
    endif

    if left(AUFAUS->V_KundNr,5) == MIKI_NR
      copyIdentFromRechnungsAdresse()
    endif

    REPLACE AUFAUS->R_Name WITH KUNDEN->Name
    REPLACE AUFAUS->R_Partner WITH KUNDEN->Partner
    REPLACE AUFAUS->R_Strasse WITH KUNDEN->Strasse
    REPLACE AUFAUS->R_Zusatz WITH KUNDEN->Zusatz
    REPLACE AUFAUS->R_Plz WITH KUNDEN->PLZ
    REPLACE AUFAUS->R_Land WITH KUNDEN->Land
    REPLACE AUFAUS->R_Ort WITH KUNDEN->Ort
    REPLACE AUFAUS->R_Sprache WITH KUNDEN->Sprache

    // alternative Rechnungsadresse
    REPLACE AUFAUS->A_Name WITH KUNDEN->A_Name
    REPLACE AUFAUS->A_Partner WITH KUNDEN->A_Partner
    REPLACE AUFAUS->A_Strasse WITH KUNDEN->A_Strasse
    REPLACE AUFAUS->A_Zusatz WITH KUNDEN->A_Zusatz
    REPLACE AUFAUS->A_Plz WITH KUNDEN->A_PLZ
    REPLACE AUFAUS->A_Land WITH KUNDEN->A_Land
    REPLACE AUFAUS->A_Ort WITH KUNDEN->A_Ort

    REPLACE AUFAUS->ZKNr WITH KUNDEN->ZKNr

    if KUNDEN->So_Rabatt <> 0
      REPLACE AUFAUS->So_Rabatt WITH KUNDEN->So_Rabatt
      REPLACE AUFAUS->Rabatt_KZ WITH KUNDEN->Rabatt_KZ
    endif

    AUFAUS->(dbcommit())

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(AUFAUS->Sprache)

    Auf_kopf_disp()
    // setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif

RETURN(.t.)
/* EOF A_KundNr_Nach */

/* vor Mwst
*/
FUNCTION Auf_Mwst_vor()
  set key K_F9 to IdentNrEdit()
RETURN(.t.)
/* EOF MWst_nach */

/* nach Mwst
*/
FUNCTION Auf_Mwst_nach(oGet)
  set key K_F9 to
  if oGet:changed
    MWST_KZ->(dbseek(oGet:Buffer))
    REPLACE AUFAUS->MWSt WITH MWST_KZ->Mwst
    Auf_kopf_disp()
  endif
RETURN(.t.)
/* EOF MWst_nach */

/** Freie Eingabe der IdentNr. */
static function IdentNrEdit()
LOCAL GetList:={},s01
LOCAL before:=AUFAUS->IdentNr
  s01:=savescreen()

  @ 14,32 say "Ident-Nr.:" get AUFAUS->IdentNr picture "@!" ;
    when Message("Ident-Nummer eingeben.        @F12@=Hilfe")
  @ 14,60 say "EU:" get AUFAUS->EG picture "@!" valid AUFAUS->EG$"JND";
    when Message("EU Mitglied?        @J@/@N@/@D@")
  read
  restscreen(,,,,s01)

  @ 14,32 say "Ident-Nr.: " + AUFAUS->IdentNr
  @ 14,60 say "EU: " + AUFAUS->EG

  if before <> AUFAUS->IdentNr
    trouble("IdentNr",{"Manuell ge�ndert von: "+before+" nach: "+AUFAUS->IdentNr})
  endif

return .t.

/* wird vor Eingabe der  Spedition Nr ausgef�hrt
*/
FUNCTION AufSpedVor( datei )
LOCAL aktRec:=KUNDEN->(recno()), spedits

  default Datei:="AUFAUS"

  MySetKey( K_F10 , {|p1,oGet| Hilfe("SpedAuswahl",oGet,p1)})
  Message('Spedition eingeben.         @F10@=Kundenvorgabe     @F12@=Auswahl')

  if empty(&(DATEI)->SpedNr) .and. ( type("m->defauftrart") =="U" .or. M->defAuftrArt <> "I")
    KUNDEN->(dbseek(AUFAUS->V_KundNr))
    spedits:=getKundSpedits( AUFAUS->V_KundNr )
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
FUNCTION AufSpedNach(oGet)
LOCAL aktRec:=KUNDEN->(recno())
LOCAL Spedits

  if ! check(oGet,"Spedit")
    return .f.
  endif

  // r�ckschreiben der Kundennr. falls leer im Kundenstamm
  if oGet:changed
    Umgebung(WRITE_ALL)

    spedits:=getKundSpedits( AUFAUS->V_KundNr )
    if len(spedits) == 0
      KUNDEN->(dbseek(AUFAUS->V_KundNr))
      select KundSped
      if add_rec(5)
        replace KUNDSPED->KundNr with KUNDEN->KundNr
        replace KUNDSPED->SpedNr with oGet:buffer
        // FIXME: Abfrage Bemerkung, SpedKdnr etc. gew�nscht
        // replace KUNDSPED->Bemerkung with
        // replace KUNDSPED->SpedKdNr with
        // replace KUNDSPED->Frei with
        dbcommit()
        dbunlock()
      endif
    endif


    if ! aContains( spedits , oGet:buffer )
      if Message("Abweichende Spedition verwenden? ( J / N ) ","JN") <> "J" .or. ABBRUCH
        Umgebung(LOAD)
        return .f.
      endif
      // set email flag
      M->emailAbweichend:=hb_bitOr( M->emailAbweichend , EMAIL_ABWEICHENDE_SPEDITION )
    else
      // unset email flag
      M->emailAbweichend:=hb_BitAnd( 0 , EMAIL_ABWEICHENDE_SPEDITION )
    endif

    Umgebung(LOAD)

    M->versandChanged:=.t.
    KUNDEN->(dbgoto( aktRec ))
  endif

  Message()
  MySetKey( K_F10 , nil )

RETURN(.t.)
/* EOF Sped_nach */

/* vor AB_Auft.Nr */
FUNCTION AB_AufNr_vor()
LOCAL aktSel:=alias()
LOCAL Merk_satz:=AUFAUS->(recno())

  // Rahmenauftrags ABMr nur beim 1. Mal editierbar
  if ! empty(AUFAUS->AB_AufNr) .and. AUFAUS->AufNr<>TEMP_NUMMER
    return .f.
  endif

  setABFilter() // AB Filter l�schen
  Aufaus->(Dbgoto(Merk_satz))

return .t.
/** eof */

/* nach AB_Auft.Nr */
FUNCTION AB_AufNr_nach(oGet)
LOCAL merkArt // , neuAbNr
LOCAL orgValues,feld
LOCAL Merk_satz:=AUFAUS->(recno()) // wird gebraucht, da zur Rahmen-AB gesprungen wird

  select AufAus

  if ! check(oGet,"Aufaus",.f.,.f.)
    Aufaus->(Dbgoto(Merk_satz))
    return .f.
  endif

  if oGet:changed

    // Ist Rahmen-AB
    if ! (AUFAUS->AufArt$'BD' .and. AUFAUS->erledigt<>'J')
      Error(ACHTUNG+"kein g�ltiger Rahmenauftrag.")
      Aufaus->(Dbgoto(Merk_satz))
      return .f.
    endif

    if ! empty(oGet:buffer)

      if AUFAUS->AufArt$"B" // Budget
        AUFAUS->(dbseek(oGet:buffer))
        if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"B"
          Error(oGet:buffer+" ist kein g�ltiger Rahmenauftrag",.t.)
          Aufaus->(Dbgoto(Merk_satz))
          return .f.
        endif
      else // Artikel "D"

        AUFAUS->(dbseek(oGet:buffer))
        if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"D"
          Error(oGet:buffer+" ist kein g�ltiger Rahmenauftrag",.t.)
          Aufaus->(Dbgoto(Merk_satz))
          return .f.
        endif

        // FIXME: this would be better if we knew the artnr
        // // suche 1. offene Rahmen-AB des Artikels der mit F12 ausgew�hlt wurde :(
        // if (neuAbNr:=getRahmenABNr( AUFPOST->ArtNr )) == NIL
        // Error(oGet:buffer+" ist kein g�ltiger Rahmenauftrag",.t.)
        // Aufaus->(Dbgoto(Merk_satz))
        // return .f.
        // endif

        // // nehme evtl. �ltere AB
        // oGet:varput( neuAbNr )
        // AUFAUS->(dbseek(oGet:buffer))
      endif

      merkArt:=AUFAUS->AufArt
      orgValues:=getCurrentValues()
      AUFAUS->(dbgoto(Merk_satz))

      for each feld in {"KUNDNR","KURZNAME","NAME","PARTNER","STRASSE","LAND","PLZ","ORT","V_KUNDNR",;
        "V_NAME","V_PARTNER","V_STRASSE","V_LAND","V_PLZ","V_ORT",;
        "S_NAME","S_PARTNER","S_STRASSE","S_LAND","S_PLZ","S_ORT",;
        "A_NAME","A_PARTNER","A_STRASSE","A_LAND","A_PLZ","A_ORT",;
        "R_KUNDNR","R_NAME",;
        "R_PARTNER","R_STRASSE","R_LAND","R_PLZ","R_ORT","VersNr","SpedNr","BestKonto",;
        "BestDat","BestNr","So_Rabatt","TextKz_Nr","ZKNr","LiefNr",;
        "MwSt_Kz","MwSt","EG","IdentNr"}
        replace &(feld) with orgValues[fieldPos(feld)]
      next
    endif
    // Ausgabe der gesamten GetListe
    setCargo(oGet,CARGO_DISP_GETLIST,.t.)
    auf_kopf_disp()

    // kopiere alle Posten aus Rahmenvertrag Artikel als Vorschlag
    if merkArt=="D"
      select Auftrag
      zap
      select AufPost
      seek (oget:buffer)
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr==oget:buffer
        if AUFPOST->Menge > AUFPOST->GeliefGes
          select Auftrag
          add_rec(0)
          overwrite("AufPost")
          replace AUFTRAG->Menge with 0
          replace AUFTRAG->KW with ""
          replace AUFTRAG->KW_Text with ""
          replace AUFTRAG->tempStr with RAHMAB_VORSCHLAG
          replace AUFTRAG->AufArt with "R" // ist jetzt kann normaler Auftrag f�r Rechnung
          replace AUFTRAG->GeliefGes with 0 // bereits geliefert
          replace AUFTRAG->ABPostNr with val(hole("ABPostNr",WRITE,.t.))
          select AufPost
        endif
        skip
      enddo
      select aufaus
    endif
  endif

  select AufAus
  setABFilter(M->defAuftrArt) // Filter wurde vorher in AB_AufNr_vor() ge�ndert
  Aufaus->(Dbgoto(Merk_satz))

RETURN(.t.)
/* EOF AB_AufNr_nach */

/*
* gibt den AuftragsKopf auf den BS aus
*/
FUNCTION Auf_Kopf_Disp
LOCAL ob:=0

  // needed falls mit Zur�ck aus Bauch kommt
  select AufAus

  if valtype(M->defAuftrArt)=="U"
    M->defAuftrArt:=" "
  endif
  // ** Kopf-Display
  do case
  case M->defAuftrArt=="G"
    @ ob+2,1 say 'Gutschrift :'
  case M->defAuftrArt $ "KI"
    @ ob+2,1 say 'K-Auftr.Nr.:'
  otherwise
    @ ob+2,1 say 'Auftrag Nr.:'
  endcase

  if M->istAbrufAuftrag <> NIL
    @ ob+3,1 say 'Rahmen ABNr:'
  endif

  @ ob+5,1 say 'Datum......:'
  @ ob+6,1 say "Versand-Art:"
  if empty(AUFAUS->VersNr)
    @ ob+6,18 say space(11)
  else
    @ ob+6,18 say left(VERSART->Text,11)
  endif

  @ ob+7,1 say "Spedition..:"
  if empty(AUFAUS->SpedNr)
    @ ob+8,1 say space(30)
  else
    SPEDIT->(dbseek(AUFAUS->SpedNr))
    @ ob+8,1 say left(SPEDIT->KurzName,30)
  endif

  // Best.Konto wird als Lieferschein.Nr. benutzt, 23.2.2012
  @ ob+10,1 say "Lieferschein-Nr.:"
  @ ob+12,1 say "Best.Datum......:"
  @ ob+14,1 say "Best.Nr. Anfrage:"

  if ! M->defAuftrArt $ "IKG"
    @ ob+19,1 say "Name Ansprechpartner:"
    @ ob+21,1 say "Email:"
    @ ob+19,49 say "Tel:"
    @ ob+21,49 say "Fax:"
  endif

  @ ob+1,32 say "Auftrag-Anschr:"
  @ ob+2,32 say 'Kd.Nr:'
  // if ! empty(AUFAUS->Sprache) .and. AUFAUS->Sprache<>DEUTSCH
  // @ ob+1,40 say "(engl) "
  // endif
  @ ob+1,49 say AUFAUS->Name
  @ ob+2,49 say AUFAUS->Ort

  @ ob+3,32 say "Versand-Anschr:"
  @ ob+4,32 say 'Kd.Nr:'
  if ! empty(AUFAUS->V_Sprache) .and. AUFAUS->V_Sprache<>DEUTSCH
    @ ob+3,40 say "(engl)  "
  endif
  @ ob+3,49 say AUFAUS->V_Name
  @ ob+4,49 say AUFAUS->V_Partner
  @ ob+5,49 say AUFAUS->V_Strasse
  @ ob+6,49 say AUFAUS->V_Land
  @ ob+6,52 say AUFAUS->V_PLZ
  @ ob+6,58 say AUFAUS->V_Ort
  if ! empty(AUFAUS->S_Name)
    @ ob+5,32 say "->Sammelstelle"
  else
    @ ob+5,32 say space(14)
  endif
  if AUFAUS->EG=="J"
    @ ob+6,42 say "(EU)"
  else
    @ ob+6,42 say space(4)
  endif

  // seit 13.2.14 immer mit Anzeige der Sprache
  @ ob+2,47 say AUFAUS->Sprache
  @ ob+4,47 say AUFAUS->V_Sprache
  @ ob+8,47 say AUFAUS->R_Sprache


  @ ob+7,32 say "Rechnung-Anschr:"
  @ ob+8,32 say 'Kd.Nr:'
  if ! empty(AUFAUS->R_Sprache) .and. AUFAUS->R_Sprache<>DEUTSCH
    @ ob+7,41 say "(engl)"
  endif
  @ ob+7,49 say AUFAUS->R_Name
  @ ob+8,49 say AUFAUS->R_Partner
  @ ob+9,49 say AUFAUS->R_Strasse
  @ ob+10,49 say AUFAUS->R_Land
  @ ob+10,52 say AUFAUS->R_PLZ
  @ ob+10,58 say AUFAUS->R_Ort

  // setColor(COLERR)
  // @ ob+10,32 say 'Euro'
  // setColor(COLNOR)

  if !M->defAuftrArt$"IKG" // nicht bei K-Lager und Gutschrift

    @ ob+11,32 to ob+11,78

    if AUFAUS->Rabatt_KZ="H"
      @ ob+12,32 say "H�nd.Rab.:"
    else
      @ ob+12,32 say "Sond.Rab.:"
    endif
    @ ob+13,32 say "Zahl.Kond:"

    @ ob+12,50 say "Energiekosten-Zuschlag:"
    @ ob+13,50 say "MWST...:"
    @ ob+13,64 say alltrim(str(AUFAUS->MWSt,5,2)+"%")+" "

    @ ob+14,32 say "Ident-Nr.: " + AUFAUS->IdentNr
    @ ob+14,65 say "Text-KZ:"

    @ ob+15,32 to ob+15,78

    @ ob+16,32 say "Rechnungsbeiblatt:"
    @ ob+17,32 say "Zoll-Zuschlag:"
    @ ob+16,54 say "Ph�nix Fracht automatisch"

    @ ob+18,2 to ob+18,78

  endif

  dispABStatus()
RETURN(.t.)
/* EOF Auf_Kopf_Disp */

/** seit 15.12.23 immer anzeigen */
static procedure dispABStatus()
  switch AUFAUS->erledigt
  case "J" // erledigt
    @ 1,1 say "Erledigt" color "R/"+getBackColor()
    exit
  case "O" // offen
    @ 1,1 say "Offen" color "R/"+getBackColor()
    exit
  otherwise // "neu"
    @ 1,1 say space(10)
  endswitch
return


/** �ndern der Sprache F5 Auftrag */
static function aendSprache(p1)
LOCAL ob:=0,oldValue:=AUFAUS->Sprache
LOCAL GetList:={},s01:=savescreen()

  // Abbruch falls aus Hilfe F12 kommt
  if p1 == "APPLYKEY"
    return .f.
  endif

  if empty(AUFAUS->Sprache)
    replace AUFAUS->Sprache with DEUTSCH
  endif
  if empty(AUFAUS->V_Sprache)
    replace AUFAUS->V_Sprache with DEUTSCH
  endif
  if empty(AUFAUS->R_Sprache)
    replace AUFAUS->R_Sprache with DEUTSCH
  endif

  Message("Sprache eingeben.      @D@eutsch oder @E@nglisch       @F12@=Auswahl")
  @ ob+2,47 get AUFAUS->Sprache picture "!" valid AUFAUS->Sprache $ DEUTSCH+ENGLISCH
  @ ob+4,47 get AUFAUS->V_Sprache picture "!" valid AUFAUS->V_Sprache $ DEUTSCH+ENGLISCH
  @ ob+8,47 get AUFAUS->R_Sprache picture "!" valid AUFAUS->R_Sprache $ DEUTSCH+ENGLISCH
  read
  restscreen(,,,,s01)

  Auf_kopf_disp()

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(AUFAUS->Sprache)

  // falls mit zru�ck aus Editor gekommen, diesen beenden, um Sprach-Wechsel zu erzwingen
  if oldValue<>AUFAUS->Sprache .and. inStackTrace("Edit")
    HB_KeyPut(K_PGDN)
    HB_KeyPut(EDIT_QUIT)
  endif

return .t.
/** eof */


/* Function Auf_Bauch  ****************************************
*
* Eingabe des Auftr.Bauches, Editor-definitionen
*
* Parameter:    merkArt: D oder B falls Abrufauftrag
*
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/


FUNCTION Auf_Bauch(merkArt,view_only)
LOCAL aFelder,starteBeiRecno
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL ende:=.f.
PRIVATE summeBestellte

  default view_only:=.f.

  set key K_F5 to toggleSprache()
  do while ! ende .or. starteBeiRecno==NIL
    aFelder:={}
    select Auftrag

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_ERSATZ_ARRAY]:={ || Auf_Text()}

    aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen
    // z�hle alle Artikel
    aKopf[EDIT_ZEIGE_ANZAHL]:=;
      { || AUFTRAG->geloescht$"N " .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE }
    // wird im Doppelmodus bei Eingabe von Z - zur�ck
    aKopf[EDIT_KOPF_FKT]:={ || editABKopf(aKopf, view_Only) }

    if view_only
      aKopf[EDIT_GESPERRT]:="KN�AEL"
      aKopf[EDIT_EXTRA_FKT]:={}
      aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("AUFAUS") }
      aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
    else
      aKopf[EDIT_NEW_FKT]:={ || Auf_Satz_nach() }

      // wird nach Beenden der Eingabe ausgef�hrt
      aKopf[EDIT_BEFORE_EDIT_FKT]:={ || dispEditorSumme("AUFAUS")}
      aKopf[EDIT_BEFORE_ZEILE]:={ || checkePhoenixBeliefert()}
      aKopf[EDIT_AFTER_MODE_CHANGE]:={ || pruefeZuschlaege() }

      aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("AUFAUS") .and. ;
        checkeKW(aKopf,aFelder) .and. checkePhoenixVPE(aKopf,aFelder) .and. checkeEnglish() }
      aKopf[EDIT_DELETE_FKT]:={ || myDelete() }

      // von K ausgef�hrt
      /* Sammelrechnung ? */
      aKopf[EDIT_GESPERRT]:="�AL"
      aKopf[EDIT_EXTRA_FKT]:={}
      aadd(aKopf[EDIT_EXTRA_FKT],{ "A"," @�@ndern " , { || KonsistenzAend() } } )
      aadd(aKopf[EDIT_EXTRA_FKT],{ "�","" , { || KonsistenzAend() } } )
      aadd(aKopf[EDIT_EXTRA_FKT],{ "L","@L@�schen ", { || KonsistenzLoesch() } } )

      aadd(aKopf[EDIT_EXTRA_FKT], ;
        { chr(K_CTRL_M), "@STRG-M@=alt.Stkl." , { || AlternatMaterialErfassen(AUFTRAG->ArtNr) }})

      do case
      case merkArt="D" // Artikel Rahmen-Auftrag
        aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F10)," @F10@=Rahmen-AB ", { || artRahmAbMenge()}})
      case merkArt="B" // Budget Rahmen-Auftrag
        aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F10)," @F10@=Rahm.AB ", { || budgetRahmAbStatus(.t.,;
          .t.)}})
      endcase
    endif

    /* Feld-Definitionen */
    // Artikel-Nr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.     @F12@=Hilfe      @F4@=Honsel-Nr.     @ESC@=Ende"
    aSpalte[EDIT_ERSATZ_1]:={ || trim(AUFTRAG->ArtNr)$"*$" }
    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_BEFORE]:={ || empty(AUFTRAG->InLfdNr)}
    aSpalte[EDIT_AFTER]:={|oGet| ( trim(oGet:Buffer)$"$*" .or. check(oGet,"Artikel",.f.,.f.)) .and. ;
      ArtnrNach(oGet,aFelder) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

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
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG-> E_Komm1),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_TITEL]:="Text"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyGTextPosten()})}
      aSpalte[EDIT_AFTER]:={ || MySetKey( K_F8 , NIL) }
      aSpalte[EDIT_AUSGABE]:=.t.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Text
      aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm2,E_Komm2)"
      aSpalte[EDIT_NAME_GET]:="E_Komm2"
      aSpalte[EDIT_FARBE]:={ || if(empty(AUFTRAG->E_Komm2),"R/"+getBackColor(),COLNOR) }
      aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben.   @F8@=deutschen Text kopieren"
      aSpalte[EDIT_MASKE]:=replicate("X",30)
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
      aSpalte[EDIT_BEFORE]:=;
        { || getUser():mayEditEnglishText .and. MySetKey( K_F8 , {|| copyGTextPosten()})}
      aSpalte[EDIT_AFTER]:={ || MYSetKey( K_F8 , NIL) }
      aSpalte[EDIT_AUSGABE]:=.t.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Menge
    aSpalte[EDIT_NAME]:="Menge"
    aSpalte[EDIT_TITEL]:="Menge/Gel."
    if merkArt<>"S" .and. AUFAUS->AufArt=="G"
      // negativ, wir brauchen 1 Stelle mehr, geht sonst schief in AUFPOSTRECHPOST(1125)
      aSpalte[EDIT_MASKE]:="999999.99"
    else
      aSpalte[EDIT_MASKE]:="9999999.99"
    endif
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_BEFORE]:={ |oGet| MengeVor(oGet) }
    aSpalte[EDIT_AFTER]:={ |oGet| MengeNach(oGet,merkArt,aFelder) }
    aSpalte[EDIT_MESSAGE]:="Menge eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Gelief
    if merkArt=="S" .or. AUFAUS->AufArt<>"G" // nicht bei Gutschrift
      aSpalte[EDIT_NAME]:="GeliefGes"
      aSpalte[EDIT_MASKE]:="9999999.99"
      aSpalte[EDIT_EDIT]:=.f.
      aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Honsel-Nr.
    aSpalte[EDIT_NAME]:="ARTIKEL->HArtNr"
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_POS_X]:=15
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    // Mengeinheit
    aSpalte[EDIT_TITEL]:="ME"
    aSpalte[EDIT_NAME]:="right(space(3)+trim(getTransField('EINHEIT->Text')),3)"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // GerateNr von
    // aSpalte[EDIT_NAME]:="GerVon"
    // aSpalte[EDIT_MESSAGE]:="Ger�te-Nummer @von@ eingeben."
    // // aSpalte[EDIT_POS_X]:=-6
    // aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    // aSpalte[EDIT_MASKE]:="99999"
    // aSpalte[EDIT_BEFORE]:={ || left(AUFTRAG->ArtNr,3)$"503/504" }
    // aSpalte[EDIT_AFTER]:={ |oGet| ABGerVon_Nach(oGet) }
    // aSpalte[EDIT_AUSGABE]:=.t.

    // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    // aSpalte:=e_fill() // initialisieren

    // // GerateNr bis
    // aSpalte[EDIT_NAME]:="GerBis"
    // aSpalte[EDIT_EDIT]:=.f.
    // aSpalte[EDIT_POS_X]:=6
    // aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

    // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    // aSpalte:=e_fill() // initialisieren

    // seit 13.2.14 bei K-Lager AB ohne Preise
    if merkArt=="S" .or. AUFAUS->AufArt<>"K" .or. M->defAuftrArt=="I"

      // Preis
      aSpalte[EDIT_NAME]:="Preis"
      aSpalte[EDIT_TITEL]:="Euro"
      aSpalte[EDIT_MASKE]:="99999.99"
      aSpalte[EDIT_AFTER]:={ |oGet| PreisNach(oGet,merkArt) }
      aSpalte[EDIT_AUSGABE]:=.t.
      aSpalte[EDIT_MESSAGE]:="Preis in @Euro@ eingeben.      @F10@=Rahmen-ABs"

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Preiseinheit
      aSpalte[EDIT_NAME]:="Pe"
      aSpalte[EDIT_EDIT]:=.f.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren


      // Rabatt
      aSpalte[EDIT_NAME]:="Rabatt"
      aSpalte[EDIT_TITEL]:="Rab."
      // aSpalte[EDIT_POS_X]:=3 // um 3 nach rechts verschoben
      // aSpalte[EDIT_BEFORE]:={ || AUFAUS->AufArt<>"K" }
      aSpalte[EDIT_AFTER]:={ |oGet| val(oGet:buffer)>=0 .and. Auf_rabatt_nach(oGet,aFelder) }
      aSpalte[EDIT_MESSAGE]:="Rabatt eingeben."


      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Kalenderwoche
    aSpalte[EDIT_NAME]:="Kw"
    aSpalte[EDIT_TITEL]:="Woche"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben.           @*@=Text"
    aSpalte[EDIT_AFTER]:={ |oGet| AufKWnach(oGet,aFelder) }
    // aSpalte[EDIT_AFTER]:={ |oGet| AufKWnach(oGet) .and. checkePhoenixVPE(aKopf,aFelder) }
    // // INfo: checkePhoenixVPE wird hier gebraucht, damit Zeile nach Umrechnung nochal ausgegeben wird.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Kalenderwoche
    // Info: seit 7.5.2013 bei AB kein Freitext mehr
    // aSpalte[EDIT_NAME]:="KW_Text"
    // aSpalte[EDIT_TITEL]:="LieferText"
    // aSpalte[EDIT_MESSAGE]:="Liefertext eingeben."
    // aSpalte[EDIT_BEFORE]:={ || left(AUFTRAG->kw,1)=="*" }
    // aSpalte[EDIT_AFTER]:={ || ! empty(AUFTRAG->kw_text) .or. lastkey()==K_UP}
    // aSpalte[EDIT_POS_X]:=-46 // nach links verschoben
    // aSpalte[EDIT_POS_Y]:=2 // 2. Zeile

    // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    // aSpalte:=e_fill() // initialisieren

    // Lagerbestand
    aSpalte[EDIT_TITEL]:="  Lg.Best."
    aSpalte[EDIT_NAME]:="getArtikelLageBest()"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    /**** ENDE Feld-Definitionen ***/

    Edit(aFelder,aKopf)
    starteBeiRecno:=AUFTRAG->(recno())

    ende:=ABBRUCH

    // if ! pruefeZuschlaege()
    // starteBeiRecno:=NIL // edit again
    // endif

  enddo
  set key K_F5 to
  set key K_F8 to

RETURN( aKopf[EDIT_CHANGED] )
/* EOF Auf_Bauch */


/* Function Auf_Text ***************************
*
* alternativ Spaltendef. bei Text eingabe *
* Ersatz-Array
  *
  * ACHTUNG: wird aus Ls_Bauch mit Datei LiefTemp.dbf
  *          und aus Auf_Bauch mit Auftrag.dbf        verwendet!!!
*/
FUNCTION Auf_Text
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| trim(oGet:Buffer)$"$*" }
  // fixed 20181129
  // aSpalte[EDIT_AFTER]:={ |oGet| ( trim(oGet:Buffer)$"$*" .or. check(oGet,"Artikel",.f.)) .and. // ArtnrNach(oGet,aFelder) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.   *=Kommentar   @F12@=Hilfe    @F4@=Honsel-Nr.   @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  if LAND->Sprache==DEUTSCH
    aSpalte[EDIT_NAME]:="Komm1"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Text eingeben"
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    aSpalte[EDIT_NAME]:="Komm2"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Text eingeben"
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  else
    aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm1,E_Komm1)"
    aSpalte[EDIT_NAME_GET]:="E_Komm1"
    aSpalte[EDIT_FARBE]:={ || if(empty((Alias())->E_Komm1),"R/"+getBackColor(),COLNOR) }
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    aSpalte[EDIT_NAME]:="if(empty(E_Komm1),Komm2,E_Komm2)"
    aSpalte[EDIT_NAME_GET]:="E_Komm2"
    aSpalte[EDIT_FARBE]:={ || if(empty((Alias())->E_Komm2),"R/"+getBackColor(),COLNOR) }
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_MASKE]:="@X"
    aSpalte[EDIT_MESSAGE]:="Englischer Text eingeben"
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),;
      .t. }
    aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  endif

RETURN(aFelder)
/* EOF Auf_Text */





/* Function Auf_Satz_nach()
*
* wird nach hinzuf�gen eines neuen Satzes ausgef�hrt
*/
FUNCTION Auf_Satz_nach
  // replace AUFTRAG->AufNr with AUFAUS->AufNr // nicht hier, da es noch temp. Nr. sein kann
  replace AUFTRAG->KundNr with AUFAUS->KundNr
  replace AUFTRAG->AufArt with AUFAUS->AufArt
  replace AUFTRAG->AufDat with AUFAUS->AufDat
  replace AUFTRAG->ABPostNr with val(hole("ABPostNr",WRITE,.t.))
RETURN(.t.)

/* Function AufKWnach
*
* wird nach Eingabe der Kalenderwoche ausgef�hrt
* evtl. Eingabe von LieferText
*/
FUNCTION AufKWnach(oGet,aFelder)
LOCAL GetList:={}
LOCAL Zeile:=row()+1
LOCAL woche:=left(oGet:buffer,2)
LOCAL jahr:=right(oGet:buffer,2)
LOCAL result, aSpalte, diff
LOCAL aktRec , aktKW, s01, allKWs:=.f.

  // bei Phoenix-Auftrag nur 1 KW zulassen, wegen Lieferpauschalen
  if isPhoenixAuftrag() .and. AUFAUS->PhoenixFr <> "N"
    aktRec:=AUFTRAG->(recno())
    loca for len(alltrim( AUFTRAG->ArtNr )) > FRACHT_LAENGE .and. AUFTRAG->KW <> oGet:buffer .and. ;
      ! KWempty( AUFTRAG->KW )

    if ! AUFTRAG->(eof())
      s01:=savescreen()
      aktKW:=AUFTRAG->Kw
      Error(ACHTUNG+"Ph�nix-Auftrag, keine Teillieferung m�glich.|"+;
        "         Bitte separate AB erfassen oder alle Posten �ndern.",ERR_NO_WAIT)
      If Message("KW in allen Posten anpassen? (@J@/@N@)","JN"," ") <> "J" .or. ABBRUCH
        restscreen(,,,,s01)
        AUFTRAG->(dbgoto( aktRec ))
        oget:varput( aktKW )
        return .f.
      endif
      restscreen(,,,,s01)

      // alle KWs anpassen
      allKWs:=.t.
    endif
    AUFTRAG->(dbgoto( aktRec ))
  endif

  // automat. zugef�gte Angebots-Artikel ohne Pflicht-Eingabe Liefer-KW
  if alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL .and. ! empty(AUFTRAG->TempStr)
    result:=.t.
  else
    result:=KW_Okay(woche,jahr)
  endif

  diff:=kwDiff(getCurrentKW(),oget:buffer)
  if result .and. diff > 52 .and. .not. getUser():id==KURZEL_DEVEL
    s01:=savescreen()
    Error(ACHTUNG+"KW liegt �ber 1 Jahr ("+alltrim(str(diff,3))+;
      " Wochen) in der Zukunft.|", ERR_NO_WAIT)
    If Message("Trotzdem fortfahren?  (@J@/@N@)","JN"," ")<>"J"
      result:=.f.
    endif
    restscreen(,,,,s01)
  endif

  if result
    updateInnerKW()
    if allKWs
      updateAllKW(oGet)
    else
      updateFrachtKW(oGet)
    endif
    //checkeMehrfach(aFelder , oGet)
    aSpalte:=aFelder[getColPosByName(aFelder,"KW")]
    aSpalte[EDIT_BS_AUSGABE]:=.t.
  endif

RETURN result


/** �berpr�ft ob die KW zw. 01-53 liegt oder aus LiefTerm �bernommen ist,
    leer ist nicht zugelassen
    bei Gutschrift keine Pr�fung und falls Menge==0 oder bei Fracht */
static Function KW_Okay(woche,jahr)
LOCAL tempVal

  // nicht bei:
  if AUFAUS->AufArt$"G" .or. AUFTRAG->Menge=0 .or. len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE ;
    .or. lastkey() == K_UP
    // freie Eingabe nicht mehr erlaubt seit 7.5.2013
    // .or. left(woche,1)=="*"
    return .t.
  endif

  if KWempty(woche)
    if M->defAuftrArt == "I" // Ausnahme K-Lager Inventur-Auftrag
      // replace AUFTRAG->KW with "*"
      // replace AUFTRAG->KW_Text with "Inventur"
      return .t.
    else
      Error(ACHTUNG+" Eingabe des Liefertermins ist Pflicht.",.t.)
      return .f.
    endif
  endif

  if M->defAuftrArt == "I" .and. left(woche,1)=="*" // Ausnahme K-Lager Inventur-Auftrag
    return .t.
  endif

  // Liefertermin aus Datei-Vorgabe?
  // LIEFTERM->(dbseek(woche))
  // if LIEFTERM->(eof())

  // seit 1.2.13 nur noch bestimmte Liefertermine in AB zugelassen
  if AUFAUS->Aufart<> "V" .and. ! woche $ getProperty("Miki.ab.liefkw","X1")
    if (val(woche)<=0 .or. val(woche)>53 .or. val(jahr)<=0)
      tempVal:=strtran( getProperty("Miki.ab.liefkw","X1") , ";"," ")
      Error(ACHTUNG+"Ung�ltiger Liefertermin.||"+;
        "         G�ltige spez. Liefertermine sind:"+tempVal,.t.)
      return .f.

      // falls AB von heute -> �berpr�fen Zeitraum KW
    elseif kwKleiner( woche+"/"+jahr , getKW(AUFAUS->AufDat) ) == 1
      Error(ACHTUNG+" Liefertermin liegt vor dem Datum der AB: "+dtoc(AUFAUS->AufDat)+" - "+;
        getKW(AUFAUS->AufDat),.t.)
      return .f.
    endif
  endif
return .t.


/** �berpr�ft nach Beendigung des Editos ob g�ltige KW eingegeben, l�scht ZeitErf.dbf */
static Function checkeKW(aKopf,aFelder)
LOCAL woche:=left(AUFTRAG->KW,2)
LOCAL jahr:=right(AUFTRAG->KW,2)
LOCAL result,x

  set key K_F9 to
  set key K_F3 to

  if empty(AUFTRAG->ArtNr)
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
    return .t.
  endif

  // automat. zugef�gte Angebots-Artikel ohne Pflicht-Eingabe Liefer-KW
  if alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL .and. ! empty(AUFTRAG->TempStr)
    return .t.
  endif

  result:=KW_Okay(woche,jahr)

  if result .or. empty(AUFTRAG->ArtNr)
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  else

    // suche Feld mit KW (kannn je nach Programm-Art variieren
    x:=getColPosByName(aFelder,"KW")
    if x==0
      troubleEmail("KW nicht gefunden.")
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif

    return .f.
  endif

  if left(woche,1)=="*" .and. len(trim(AUFTRAG->KW_text))<3
    Error(ACHTUNG+" Liefertext muss eingegeben werden.  Mind. 3 Zeichen",.t.)
    x:=getColPosByName(aFelder,"KW_Text")
    if x==0
      troubleEmail("KW_text nicht gefunden.")
      return .t. // my bug, we allow exit here so user can proceed
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif
    return .f.

  endif

return .t.
/** eof */



/** �berpr�ft nach Beendigung des Editos ob Pheonix Artikel umgerechnet werden m�ssen */
Function checkePhoenixVPE(aKopf,aFelder,Datei)
LOCAL oberArtnr,anzKartons,x,feldPreis,feldRab,erg,merkEinh
LOCAL s01

  default datei:="Aufaus"

  ignore aKopf

  if empty(AUFTRAG->ArtNr)
    return .t.
  endif

  // pr�fe ob Phoenix-Artikel -> automat. Oberartikel mit Karton inkl. verwenden
  if (oberArtnr:=getParentPhoenix(AUFTRAG->ArtNr))<>NIL

    s01:=savescreen()

    erg:=" "
    Error("Soll der Artikel in die VPE des Kunden umgerechnet werden?",ERR_NO_WAIT)
    do while empty(erg) .or. ABBRUCH
      erg:=message("Soll der Artikel in die VPE des Kunden umgerechnet werden? (@J@/@N@)","JN","J")
    enddo

    restscreen(,,,,s01)
    if erg=="J"

      /** w�hle Sprache je nach Empf�nger */
      selLandBySprache((Datei)->Sprache)

      select Auftrag
      // orgValues:=getCurrentValues()

      // // f�ge neuen Oberartikel hinzu (davor)
      // ZeileEinfuegen(aKopf,aFelder,nil,.t.)
      // setCurrentValues(orgValues)
      merkEinh:=getTransField("EINHEIT->Text")
      ARTIKEL->(dbseek(oberArtnr))
      replace AUFTRAG->Komm3 WITH ;
        "("+getTranslation("AB.entspricht",LAND->Sprache)+" Art.Nr.: "+AUFTRAG->ArtNr+" "+;
        alltrim(str(AUFTRAG->Menge,12,0))+" "+alltrim(merkEinh)+")"
      replace AUFTRAG->ArtNr with oberArtNr
      anzKartons:=int(AUFTRAG->Menge/AVPOST->Menge)
      if anzKartons<>(AUFTRAG->Menge/AVPOST->Menge)
        anzKartons++ // Kartons aufrunden
      endif

      replace AUFTRAG->Menge with anzKartons
      replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
      replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
      // komm3 s.o.
      replace AUFTRAG->komm4 WITH ""
      replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
      replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2
      replace AUFTRAG->Me WITH ARTIKEL->ME
      replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
      replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr

      // Rabatt-Staffel
      if ! AUFTRAG->RabattGr $ "  00SoSO" .and. len(alltrim(AUFTRAG->ArtNr)) >3 .or.;
        (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
        (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J")
        x:=getMengenRabattStaffel(AUFTRAG->RabattGr,AUFTRAG->Menge)
        if x<=0
          // keine Rabattstaffel
          REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
          REPLACE AUFTRAG->Rabatt WITH 0
        else // Rabatt-Tabelle
          // Rabatt absolut -> Preis
          feldPreis="RABATT->Preis"+str(x,1)
          if &(feldPreis)>0
            REPLACE AUFTRAG->Preis WITH &(feldPreis)
            REPLACE AUFTRAG->Rabatt WITH 0
          else // Rabatt in %
            feldRab ="RABATT->Rab"+str(x,1)
            REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
            REPLACE AUFTRAG->Rabatt WITH &(feldRab)
          endif
        endif
      endif

      // // wandle aktuellen Datensatz in Kommentar um
      // skip 1
      // Orgartnr:=AUFTRAG->ArtNr
      // replace AUFTRAG->ArtNr with "*"
      // replace AUFTRAG->Preis WITH 0
      // replace AUFTRAG->Komm1 WITH space(TAB_SPACES)+;
      // "(Art.Nr.: "+orgArtNr+" "+alltrim(str(AUFTRAG->Menge,12,0))+" "+alltrim(EINHEIT->Text)+")"
      // // FIXME: replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
      // replace AUFTRAG->Komm2 WITH ""

      // Ausgabe der akt. Zeile
      Error(ACHTUNG+"Ph�nix Artikel in Kundeneinheit umgerechnet.",.t.)
      aFelder[getColPosByName(aFelder,"Kw"),EDIT_AUSGABE]:=.t.
    endif
  endif

return .t.
/** eof */

/** �berpr�ft ob ein Ph�nix-Artikel bereits beliefert wurde, dann nicht editierbar! */
static Function checkePhoenixBeliefert()
  if AUFTRAG->GeliefGes > 0 .and. isPhoenixOberArtikel( AUFTRAG->ArtNr )
    Error(ACHTUNG+;
      "Ph�nix-Artikel wurde bereits geliefert.||         Kann nicht bearbeitet werden!",.t.)
    return .f.
  endif
return .t.
/** eof */



/* Function ArtnrNach
*
* wird nach Eingabe der ArtikelNummer ausgef�hrt
*/
static FUNCTION ArtnrNach(oGet,aFelder)
LOCAL M_order,merkArt,merkAufnr,subject,body,s01,aktRec, setzeMwst, aktKW, land

  ignore aFelder

  // keine Fracht-Verpackungsartikel manuell �ndernbar falls Ph�nix-Artikel
  if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. ! "*" $ AUFTRAG->ArtNr .and.;
    isPhoenixAuftrag()

    if AUFAUS->PhoenixFr <> "N"
      land=getProperty("Miki.phoenix.fracht.automatisch","")
      Error(ACHTUNG+"Fracht & Verpackung wird bei Ph�nix-Auftrag nach|"+;
        "         "+land+" automatisch berechnet.||"+;
        "         Zum �ndern bitte Kennzeichen in Kopfdaten auf N setzen")
      keyboard chr(K_ESC) // we bail out
      return(.f.)
    endif
  endif

  // pr�fe ob Zoll-Artikel
  if AUFAUS->ZollZuschl == "J" .and. isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and.;
    ! M->defAuftrArt $ "G"
    Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.||"+;
      "Zum �ndern bitte Zollzuschlag in Kopfdaten auf N setzen")
    return .f.
  endif

  if oGet:changed

    // Nur K-Lager Artikel zulassen bei K-Auftrag
    if AUFAUS->AufArt=="K" .and. len(alltrim(ARTIKEL->ArtNr))>5 .and. ;
      left(ARTIKEL->KonsigKdNr,5)<>left(AUFAUS->KundNr,5)
      Error(ACHTUNG+"Artikel ist f�r Kunde:"+left(AUFAUS->KundNr,5)+" nicht f�r K-Lager "+;
        "freigegeben!",.t.)
      return(.f.)
    endif

    // Nur K-Lager Artikel extern zulassen bei K-Auftrag
    if AUFAUS->AufArt=="K" .and. getArtikelArt()=="B"
      Error(ACHTUNG+"Artikel ist interner K-Lager Artikel|         und nicht f�r K-Lager extern "+;
        "freigegeben!",.t.)
      return(.f.)
    endif

    // keine X-Artikel
    if getArtikelArt()=="X"
      Error(ACHTUNG+"X-Artikel nicht zugelassen!",.t.)
      return(.f.)
    endif

    // pr�fe ob Fertigungs-Artikel eine Zeit-St�ckliste hat.
    if getArtikelArt() $ "FM" .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. ;
      ! isPhoenixOberArtikel( AUFTRAG->ArtNr )
      M_Order:=AVPOST->(indexOrd())
      AVPOST->(OrdSetFocus(1)) // AVNr+Art
      AVPOST->(dbseek(oGet:buffer+"V"))
      if AVPOST->(eof())
        Error(ACHTUNG+oget:buffer+" hat keine Zeit/Maschinen St�ckliste.||"+;
          "         Bitte zu erst anlegen.")
        AVPOST->(OrdSetFocus(M_Order))
        return .f.
      endif
      AVPOST->(OrdSetFocus(M_Order))
    endif

    if AUFAUS->AufArt<>"K" .and. ! (empty(ARTIKEL->KonsigKdNr) .or. ARTIKEL->KonsigKdNr==KDNR_LEER)
      Error(ACHTUNG+" K-Lager Artikel.",.t.)
      // FIXME: testing KLager Artikel in normalem Auftrag
      // Error(ACHTUNG+" K-Lager Artikel.  Bitte Menu-Punkt 2.21 verwenden.",.t.)
      // return .f.
    endif

    // passe EG Kennzeichen an, wenn Werkzeug
    // Hinweis: i.d.R. bleibt ein Wkz bei Miki, Mwst muss also berechnet werden
    // Als Empf�nger (Vers.Adr) wird oft ein Leerkunde 1003 ohne Adresse, aber in D angegeben
    if getArtikelArt()=="W" .and. upper(AUFAUS->EG) == "D"
      LAND->(dbseek(left(AUFAUS->Land,2)))
      if LAND->EU == "J"
        replace AUFAUS->EG with "J"
      endif
    endif

    // bei Werkzeug und EG Kunden -> Mwst berechnen
    IF len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. upper(AUFAUS->EG) <> "D"
      aktRec:=recno()
      // Werkzeug eingegeben
      if getArtikelArt()=="W"
        // suche nicht Werkzeuge in Auftrag.dbf (!)
        loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()<>"W"
        if ! eof()
          Error(ACHTUNG+"Werkzeuge und andere Artikel k�nnen bei ausl�nd. Kunden|"+;
            "         nicht gemeinsam berechnet werden.",.t.)
          go (aktRec)
          return .f.
        endif
        go (aktRec)

        if AUFAUS->MwSt_KZ=="0" .or. AUFAUS->AufArt=="G"
          setzeMwst:=.t.
          if AUFAUS->AufArt=="G" // Abfrage bei Gutschrift
            s01:=savescreen()
            Error("Werkzeug-Gutschrift!||Soll f�r die gesamte Gutschrift MwSt werden?",;
              ERR_NO_WAIT)
            if Message("Mehrwertsteuer berechnen? (@J@/@N@)","JN","J") == "N" .or. ABBRUCH
              setzeMwst:=.f.
            endif
            restscreen(,,,,s01)
          endif

          if setzeMwst
            // bei Werkzeuglieferung an ausl�nd. Kunden, Mehrwertsteuer berechnen
            replace AUFAUS->Mwst_KZ with "1"
            MWST_KZ->(dbseek("1"))
            REPLACE AUFAUS->MwSt WITH MWST_KZ->MwSt
          endif
        endif

      else
        // Nicht-Werkzeug eingegeben
        if getArtikelArt()<>"W"
          // suche nicht Werkzeuge in Auftrag.dbf (!)
          loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()=="W"
          if ! eof()
            Error(ACHTUNG+"Werkzeuge und andere Artikel k�nnen bei ausl�nd. Kunden|"+;
              "         nicht gemeinsam berechnet werden.",.t.)
            go (aktRec)
            return .f.
          endif
          go (aktRec)

          if AUFAUS->MwSt_KZ=="1"
            // bei Nicht-Werkzeuglieferung an ausl�nd. Kunden, keine Mehrwertsteuer berechnen
            replace AUFAUS->Mwst_KZ with "0"
            MWST_KZ->(dbseek("0"))
            REPLACE AUFAUS->MwSt WITH MWST_KZ->MwSt
          endif
        endif
      endif
    endif

    // bei Werkzeug: nehme Miki als Versandadresse
    if getArtikelArt()=="W"
      if left(AUFAUS->V_KundNr,5) <> MIKI_NR
        copyMikiAdresse()
      endif
    endif

    // Rahmenauftrag? nur passende Artikel zulassen
    if ! empty(AUFAUS->Ab_AufNr)
      if len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE

        // pr�fe Art des Rahmenauftrags
        merkArt:=getRahmABArt()

        if merkArt=="B" // Budget
          // nop?
        else // merkArt=="D" // Disposition (Artikel)
          if getRahmenABNr( AUFTRAG->ArtNr ) == NIL
            Error(ACHTUNG+" Artikel in keinem Rahmenauftrag des Kunden: "+AUFAUS->Kurzname+;
              " erfasst.",.t.)
            return .f.
          endif
        endif
      endif
    else // kein Rahmenauftrag

      // bei Kostenvoranschlag keine Artikel ohne VK
      if AUFAUS->Aufart$"V" .and. ARTIKEL->Preis1==0 .and.;
        len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE
        Error(ACHTUNG+"Artikel hat keinen Preis.|         Kann im KV nicht verwendet werden.",.t.)
        subject:="KV Artikel ohne Preis: "+out(ARTIKEL->ArtNr)
        body:="Artikel: "+out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+MY_CR+MY_LF
        body+="verwendet in Auftrag: "+AUFAUS->AufNr+MY_CR+MY_LF
        body+="K�rzel: "+getUser():id+MY_CR+MY_LF
        // EMail an H. Weiland
        email(MAIN_EMAIL,subject,body)
        return .f.
      endif

      if AUFAUS->Aufart$"RKVA"
        if (merkAufNr:=getRahmenABNr( AUFTRAG->ArtNr ) ) <> NIL
          s01:=savescreen()
          Error(ACHTUNG+" F�r Artikel :"+AUFTRAG->ArtNr+" existiert ein Rahmenauftrag: "+;
            merkAufNr,.f.)
          if Message("Trotzdem fortfahren?  (@J@/@N@)","JN")=="J"
            restscreen(,,,,s01)
            subject:="Ignorierter Rahmenauftrag - Kunde: "+AUFAUS->KundNr+" "+AUFAUS->Kurzname
            body:="Artikel: "+out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+MY_CR+MY_LF
            body+="Rahmen-Auftrag: "+merkAufNr+MY_CR+MY_LF
            body+="verwendet in Auftrag: "+AUFAUS->AufNr+MY_CR+MY_LF
            body+="K�rzel: "+getUser():id+MY_CR+MY_LF
            // EMail an H. Weiland
            email(MAIN_EMAIL,subject,body)
          else
            restscreen(,,,,s01)
            return .f.
          endif
        endif
      endif
    endif

    if trim(oGet:Buffer)$"$*"
      if ! trim(oGet:original)$"$*"
        REPLACE AUFTRAG->Art WITH ""
        REPLACE AUFTRAG->komm1 WITH ""
        REPLACE AUFTRAG->komm2 WITH ""
        replace AUFTRAG->komm3 WITH ""
        replace AUFTRAG->komm4 WITH ""
        REPLACE AUFTRAG->E_komm1 WITH ""
        REPLACE AUFTRAG->E_komm2 WITH ""
      endif
    else
      copyArtikelValues()

      switch AUFAUS->Aufart
      case "V"
        // bei Kostenvoranschlag Liefertermin auf XA setzen
        replace AUFTRAG->KW with getProperty("Miki.kv.liefkw","XA")
        exit
      case "K"
        // bei K-Lager Artikel: suche letzten Rabatt
        if AUFAUS->AufArt=="K"
          select Konsig
          set filter to KONSIG->ArtNr==oGet:Buffer
          go bottom
          if KONSIG->Rabatt<>0
            replace AUFTRAG->Rabatt WITH KONSIG->Rabatt
          endif
          set filter to
          select Auftrag
        endif
        exit
      endswitch

      oGet:assign()

      // neu 20171024: setze KW von Verpackung auf Artikel oben dran
      if len(alltrim(AUFTRAG->ArtNr)) < FRACHT_LAENGE .and. KWempty(AUFTRAG->KW)
        aktRec:=recno()
        do while KWempty(AUFTRAG->KW) .and. ! AUFTRAG->(bof())
          skip -1
        enddo
        aktKW:=AUFTRAG->KW
        go (aktRec)
        replace AUFTRAG->KW with aktKW
      endif


      /* pr�fe auf MengenRabatt */
      if AUFTRAG->Menge > 0
        pruefeMengenRabatt()
      endif

    endif
    dispEditorSumme("AUFAUS")
  endif

RETURN(.t.)
/* EOF ArtNr_Nach */

/** kopiert alle relevanten Werte aus Artikel.dbf nach Auftrag */
static procedure copyArtikelValues()
LOCAL paletten

  REPLACE AUFTRAG->Art WITH getArtikelArt()
  replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
  replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
  replace AUFTRAG->komm3 WITH ""
  replace AUFTRAG->komm4 WITH ""
  replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
  replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2

  // Preis nur kopieren, falls keine Fracht oder Verpackung bzw. falls diese berechnet wird
  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
  if (len(alltrim(AUFTRAG->ArtNr)) >3 .or.;
    (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
    (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J") ) ;
    .and. ! ( AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr)))
    replace AUFTRAG->Preis WITH ARTIKEL->Preis1
  else
    replace AUFTRAG->Preis WITH 0
  endif

  replace AUFTRAG->Me WITH ARTIKEL->ME
  replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
  replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
  // replace Kost WITH ARTIKEL->KostNr
  replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe

  assignErlGruppe( AUFTRAG->Erl_Gruppe )

  // added 20171119
  replace AUFTRAG->Inhalt with ARTIKEL->Inhalt
  replace AUFTRAG->InhaltME with ARTIKEL->InhaltME

  SELECT Auftrag
return
/** eop */

static procedure assignErlGruppe( GrNr )
LOCAL aktSel:=alias()
  select Erl_Grup
  seek GrNr
  if .not. ERL_GRUP->(eof())
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
  select (aktSel)
return
/** eop */


/* Function MengeVor
*
* wird vor Eingabe der Auftrags Menge ausgef�hrt
*/
static FUNCTION MengeVor(oGet)
LOCAL max,s01
  ignore oget

  if M->defAuftrArt $ "IK" // nur bei K-Lager

    s01:=savescreen()
    Message("M�gliche Menge wird berechnet.  Bitte warten....")

    set key K_F9 to ArtAuftragsListe()
    M->summeBestellte:=sumKBestellte()
    max:=ARTIKEL->KonsigMax - ARTIKEL->KonsigBest - M->summeBestellte
    Message("Lager-Bestand="+alltrim(str(ARTIKEL->LageBest,9,2))+" K-Bestand="+;
      alltrim(str(ARTIKEL->KonsigBest,9,2))+" Bestellt="+alltrim(str(M->summeBestellte,9,2))+;
      " @Max="+alltrim(str(max,9,2)+"@")+"  @F9@=Details")
    restscreen(,,,,s01)

  else // normaler Auftrag
    if EINHEIT->Zeit=="J"
      set key K_F3 to FaktZeitErfass(nil,oGet,nil)
      set key K_F9 to
      Message("Anzahl Stunden/Minuten eingeben.    @F3@=Zeit-Erfassung")
    else
      set key K_F3 to
      set key K_F9 to ArtAuftragsListe()
      Message("Menge eingeben.    @F9@=Auftr�ge anzeigen  @F10@=Rahmen-ABs")
    endif
  endif

return .t.
/** EOF */


/* Function MengeNach
*
* wird nach Eingabe der Menge ausgef�hrt
*/
static FUNCTION MengeNach(oGet,merkArt,aFelder)
LOCAL body,subject,ueberliefert,wert
LOCAL M_Menge:=oGet:buffer
LOCAL maxLief,maxKonsig
LOCAL merkMenge,merkArtNr,aSpalte,aktRec,s01

  if oGet:changed

    if AUFTRAG->Menge < 0 .and. AUFAUS->InvKz <> "J"
      Error(ACHTUNG+" Negative Anzahl nicht m�glich.",.t.)
      return .f.
    endif

    if AUFTRAG->GeliefGes>0 .and. AUFTRAG->Menge < AUFTRAG->GeliefGes .and. AUFTRAG->Menge > 0 ;
      .and. ! AUFAUS->AufArt="V" // Ausnahme KV
      Error(ACHTUNG+"Posten wurde bereits beliefert.||         Min. Menge:"+;
        str(AUFTRAG->GeliefGes,11,2),.t.)
      return .f.
    endif

    // NACHKOMMA Stellen erlaubt?
    if AUFTRAG->Menge-int(AUFTRAG->Menge) > 0 .and. EINHEIT->Nachkomma == 0
      Error(ACHTUNG+" Nachkommastellen bei ME: "+EINHEIT->Text+" nicht zugelassen.",.t.)
      return .f.
    endif

    if AUFAUS->Aufart<>"G" .and. AUFTRAG->Menge > ARTIKEL->LageBest .and.;
      len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
      Error(ACHTUNG+" Nur noch "+alltrim(str(ARTIKEL->LageBest))+" auf Lager.|          Bitte "+;
        "R�cksprache wegen Liefertermin halten.",.t.)
    endif

    // K-Lager Auftrags Max.Menge erreicht?
    if AUFAUS->AufArt=="K" .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. ;
      AUFTRAG->Menge>0 .and. M->defAuftrArt <> "I" // Ausnahme K-Lager Inventur-Auftrag

      // ueberliefert?
      ueberliefert:=AUFTRAG->Menge+ARTIKEL->KonsigBest+M->summeBestellte - ARTIKEL->KonsigMax
      if ueberliefert>0
        wert:=if(ARTIKEL->Schluessel=="H",ueberliefert*ARTIKEL->Preis1/100, ueberliefert*ARTIKEL->;
          Preis1)

        Error(ACHTUNG+" K-Lager Maximal Bestand ("+alltrim(str(ARTIKEL->KonsigMax))+;
          ")  |          um "+ alltrim(str(ueberliefert,9,2))+" (="+alltrim(str(wert,11,2))+;
          " Euro) �berschritten.",.t.)

        if Message("Wirklich �berliefern ? ( J / N ) ","JN")=="J"
          subject:="Konsig. Artikel: "+out(ARTIKEL->ArtNr)+" -- �berliefert"
          body:="Konsig. Artikel "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" �berliefert"+MY_CR+MY_LF
          body+="Auftrag Nr:       "+space(6)+AUFAUS->Aufnr+MY_CR+MY_LF
          body+="Auftrags-Menge:   "+str(AUFTRAG->Menge,11,2)+MY_CR+MY_LF
          body+="Reserviert:       "+str(M->summeBestellte,11,2)+MY_CR+MY_LF
          body+="K-Lager max.:     "+str(ARTIKEL->KonsigMax,11,2)+MY_CR+MY_LF
          body+="K-Lager akt.:     "+str(ARTIKEL->KonsigBest,11,2)+MY_CR+MY_LF
          body+="�berliefert:      "+str(ueberliefert,11,2)+MY_CR+MY_LF
          body+="VK:              "+str(ARTIKEL->Preis1,11,2)+ARTIKEL->Schluessel+MY_CR+MY_LF
          body+=MY_CR+MY_LF
          body+="Warenwert �berliefert:"+str(wert,11,2)+" Euro"+MY_CR+MY_LF
          // EMail an H. Weiland
          email(MAIN_EMAIL,subject,body)
          replace AUFTRAG->Komm3 with ""
          replace AUFTRAG->Komm4 with ""
          set key K_F9 to
          //checkeMehrfach(aFelder , oGet)
          return .t.
        else
          maxLief:=max(0,ARTIKEL->KonsigMax - ARTIKEL->KonsigBest-M->summeBestellte)
          maxKonsig:=ARTIKEL->KonsigMax
          if maxLief<oget:original
            oget:varput(oGet:original)
            oget:changed:=.f.
          else
            oget:varput(maxLief)
          endif
          oGet:updateBuffer()

          replace AUFTRAG->Komm3 with "Max. K-Lager Menge "+alltrim(str(maxKonsig,7,2))+;
            " �berschritten."
          replace AUFTRAG->Komm4 with "Bestellt:"+alltrim(M_Menge)+if(M->summeBestellte>0,;
            " disp:"+alltrim(str(M->summeBestellte,7,2)),"")+" gel:"+alltrim(oGet:buffer)
          Error("Info an Honsel:||"+AUFTRAG->Komm3+"|"+AUFTRAG->Komm4,.t.)

          // textCodeBlock:={ || KommentarZeile("Max. K-Lager Menge "+alltrim(str(maxKonsig,7,2))+" �berschritten.","Bestellt:"+alltrim(M_Menge)+if(M->summeBestellte>0," disp:"+alltrim(str(M->summeBestellte,7,2)),"")+" gel:"+alltrim(oGet:buffer)) } // ZeileEinfuegen(aKopf,aFelder,TextCodeBlock)

          set key K_F9 to
          //checkeMehrfach(aFelder , oGet)
          return .t.
        endif
      else // ueberliefert > 0
        replace AUFTRAG->Komm3 with ""
        replace AUFTRAG->Komm4 with ""
      endif // ueberliefert > 0
    endif


    // Rahmenauftrag? Menge pr�fen
    if ! empty(AUFAUS->Ab_AufNr) .and. len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE
      if merkArt=="D" // Artikel
        if ! artRahmAbMenge( .t. )
          return .f.
        endif
      elseif merkArt=="B" // Budget
        if ! budgetRahmAbStatus(.f.,.t.)
          Error(ACHTUNG+"Rahmenauftrag Budget kann nicht �berliefert werden.",.t.)
          return .f.
        endif
      endif
    endif

    pruefeMengenRabatt()

    // pr�fe MindestBestellMenge
    if AUFAUS->AufArt <> "V" .and. AUFAUS->InvKz <> "J"
      aSpalte:=aFelder[getColPosByName(aFelder,"Menge")]
      aSpalte[EDIT_BS_AUSGABE]:=.f.
      merkArtNr:=AUFTRAG->ArtNr
      aktRec:=recno()
      if oGet:VarGet()>0 .and. oGet:VarGet() < ARTIKEL->MinOrderI .and. getArtikelArt() <> "E"
        s01:=savescreen()
        Error(ACHTUNG+" Artikel: "+ARTIKEL->ArtNr+" Mind.Bestellung: "+;
          str(ARTIKEL->MinOrderI,9, 2),.f.)
        if Message("@I@gnorieren oder @M@indermengenzuschlag berechnen?","IM"," ")=="M"
          merkMenge:=oGet:VarGet()

          // l�sche evtl. vorherige Mindermengenzuschl�ge
          replace AUFTRAG->geloescht with "J" for alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL .and. ;
            trim(AUFTRAG->tempStr)==merkArtNr + str(oGet:original,10,2)
          go (aktRec)
          insertBlank(.f.)
          Auf_Satz_nach()
          ARTIKEL->(dbseek(merkArtNr))
          replace AUFTRAG->ArtNr with ShiftArtikel(ANGEBOTS_ARTIKEL)
          replace AUFTRAG->KOMM1 with getTranslation("AB.min.menge",DEUTSCH)+;
            " "+alltrim(str(ARTIKEL->MinOrderI))
          replace AUFTRAG->KOMM2 with getTranslation("AB.min.zuschlag",DEUTSCH)
          replace AUFTRAG->E_KOMM1 with getTranslation("AB.min.menge",ENGLISCH)+;
            " "+alltrim(str(ARTIKEL->MinOrderI))
          replace AUFTRAG->E_KOMM2 with getTranslation("AB.min.zuschlag",ENGLISCH)
          replace AUFTRAG->MENGE with 1
          replace AUFTRAG->PREIS with (ARTIKEL->MinOrderI-merkMenge)*ARTIKEL->Preis1;
            / if(ARTIKEL->Schluessel="H",100,1)

          // merke zugeh. Art.Nr. & menge f�r sp�tere �nderungen
          replace AUFTRAG->tempStr with merkArtNr+str(merkMenge,10,2)
          go (aktRec)

          // BS ausgeben
          aSpalte[EDIT_BS_AUSGABE]:=.t.

        else
          if ABBRUCH
            restscreen(,,,,s01)
            return .f.
          endif
          if getUser():id<>KURZEL_MIKI_GF
            email(MAIN_EMAIL,;
              "Auftrag ohne Mindermengenzuschlag",;
              "Auftrag :"+AUFAUS->AufNr+"|"+;
              "Kunde...:"+AUFAUS->KundNr+" "+AUFAUS->KURZNAME+"|"+;
              "Benutzer:"+getUser():id+"||"+;
              ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"|"+;
              "Menge...............:"+str(oGet:VarGet())+"|"+;
              "Mindest-Bestellmenge:"+str(ARTIKEL->MinOrderI)+"||"+;
              "Bitte pr�fen")
          endif
        endif
        restscreen(,,,,s01)
      else
        // l�sche evtl. vorherige Mindermengenzuschl�ge
        loca for alltrim(AUFTRAG->ArtNr)==ANGEBOTS_ARTIKEL .and. ;
          trim(AUFTRAG->tempStr)==merkArtNr + str(oGet:original,10,2)
        do while ! AUFTRAG->(eof())
          replace AUFTRAG->geloescht with "J"
          cont
          // BS ausgeben
          aSpalte[EDIT_BS_AUSGABE]:=.t.
        enddo
        go (aktRec)
      endif
    endif

    // 20180711: KV immer gleich beliefert
    if AUFAUS->AufArt=="V"
      replace AUFTRAG->GeliefGes with AUFTRAG->Menge
    endif

    dispEditorSumme("AUFAUS")
  endif
  set key K_F9 to
  set key K_F3 to
  //checkeMehrfach(aFelder , oGet)
RETURN(.t.)
/* EOF Auf_Menge_Nach() */

/* Mengenrabatt ??? */
static procedure pruefeMengenRabatt()
LOCAL paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
LOCAL x,feldRab,feldPreis

  if (! AUFTRAG->RabattGr $ "  00SoSO" .and. len(alltrim(AUFTRAG->ArtNr)) >3 ) .or.;
    (((len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
    (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "J")) ;
    .and. ! ( AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))))

    x:=getMengenRabattStaffel(AUFTRAG->RabattGr,AUFTRAG->Menge)
    if x<=0
      // keine Rabattstaffel
      REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
      REPLACE AUFTRAG->Rabatt WITH 0
    else // Rabatt-Tabelle
      // Rabatt absolut -> Preis
      feldPreis="RABATT->Preis"+str(x,1)
      if &(feldPreis)>0
        REPLACE AUFTRAG->Preis WITH &(feldPreis)
        REPLACE AUFTRAG->Rabatt WITH 0
      else // Rabatt in %
        feldRab ="RABATT->Rab"+str(x,1)
        REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1
        REPLACE AUFTRAG->Rabatt WITH &(feldRab)
      endif
    endif
  endif
return
/** eop */

/* Function Auf_Rabatt_nach()
*
* wird nach Eingabe des Rabatts bei AB ausgef�hrt
*/
static FUNCTION Auf_Rabatt_nach(oGet,aFelder)
LOCAL s01:=savescreen(),aktRec,merkArtnr,merkRabGr

  if oGet:changed

    if val(oGet:buffer)>0 .and. Message("Sonderrabatt ? ( J / N ) ","JN")=="J"
      replace AUFTRAG->RabattGr with SONDER_RABATT
    else
      if AUFTRAG->RabattGr==SONDER_RABATT
        replace AUFTRAG->RabattGr with ""
      endif
    endif

    if AUFAUS->AufArt=="K"
      select Konsig
      set filter to KONSIG->ArtNr==AUFTRAG->ArtNr
      go bottom
      if KONSIG->Rabatt<>val(oGet:buffer) .or. KONSIG->RabattGr <> AUFTRAG->RabattGr
        if KONSIG->RabattGr==SONDER_RABATT
          Error(ACHTUNG+"Sonder-Rabatt bisher: "+alltrim(str(KONSIG->Rabatt))+"%",.f.)
        else
          Error(ACHTUNG+"Mengen-Rabatt bisher: "+alltrim(str(KONSIG->Rabatt))+"%",.f.)
        endif
        if Message("Rabatt: "+alltrim(oGet:buffer)+"% f�r alle gelieferten Artikel ("+;
          AUFTRAG->ArtNr+") �bernehmen?","JN"," ")<>"J"
          set filter to
          select Auftrag
          restscreen(,,,,s01)
          return .f.
        endif
      endif

      // schreibe Rabatt in alle bereits gelieferten, die noch nicht berechnet sind
      set filter to KONSIG->ArtNr==AUFTRAG->ArtNr .and. KONSIG->geliefGes>KONSIG->berechnet
      go top
      do while ! KONSIG->(eof())
        if ! rec_lock(5)
          Error(ACHTUNG+"Rabatt konnte nicht zugewiesen werden:"+AUFTRAG->ArtNr,.t.,"root")
        else
          replace KONSIG->Rabatt with val(oGet:buffer)
          replace KONSIG->RabattGr with AUFTRAG->RabattGr
        endif
        dbcommit()
        dbunlock()
        skip
      enddo
      set filter to
      select Auftrag
      // jetzt gleichen Artikel in akt. Auftrag suchen
      aktRec:=AUFTRAG->(recno())
      merkArtnr:=AUFTRAG->ArtNr
      merkRabGr:=AUFTRAG->RabattGr
      replace AUFTRAG->Rabatt with val(oGet:buffer),AUFTRAG->RabattGr with merkRabGr ;
        for AUFTRAG->ArtNr==merkArtNr
      go (aktRec)
      // Ausgabe des BS Editors falls Artikel mehrfach vorkommt
      aFelder[getColPosByName(aFelder,"Rabatt")][EDIT_BS_AUSGABE]:=.t.
    endif

    //checkeMehrfach(aFelder , oGet)

    dispEditorSumme("AUFAUS")

  endif
  restscreen(,,,,s01)
return .t.
/** eof */

/** Summiert alle bestellten Posten je Artikel in AufPost und
    inkl. der Bestellungen im akt. Auftrag (nur KLager) */
static Function sumKBestellte()
LOCAL bestellt:=0
LOCAL aktAuftragsSatz:=AUFTRAG->(recno())
LOCAL M_order:=AUFPOST->(IndexOrd())
LOCAL M_ArtNr:=AUFTRAG->ArtNr
LOCAL M_recno:=AUFAUS->(recno())
LOCAL aktAufaus:=AUFAUS->(recno())
LOCAL M_KundNr:=AUFAUS->KundNr
LOCAL M_AufNr:=AUFAUS->AufNr

  // ACHTUNG: hier AufBest top level je Kunde neu berechnen,;
  // disponiert verwenden geht nicht!!!
  select Aufpost
  AUFPOST->(OrdSetFocus(2)) // KundNr+Art
  dbseek(M_KundNr+"K"+M_ArtNr)

  do while ! AUFPOST->(eof()) .and. AUFPOST->KundNr==M_KundNr .and. AUFPOST->AufArt=="K" ;
    .and. AUFPOST->ArtNr==M_ArtNr

    AUFAUS->(dbseek( AUFPOST->AufNr ))
    if AUFPOST->AufNr<>M_AufNr .and. AUFPOST->Menge > AUFPOST->GeliefGes .and.;
      AUFAUS->erledigt<>"J"
      bestellt+=(AUFPOST->Menge-AUFPOST->GeliefGes)
    endif
    skip
  enddo
  AUFAUS->(dbgoto( aktAufaus ))

  select aufpost
  AUFPOST->(OrdSetFocus(m_order))
  select auftrag

  // Addiere aktuellen Auftrag (Berabeitungsstand)
  go top
  do while ! AUFTRAG->(eof())
    if AUFTRAG->ArtNr==M_ArtNr .and. aktAuftragsSatz<>AUFTRAG->(recno())
      bestellt+=(AUFTRAG->Menge-AUFTRAG->GeliefGes)
    endif
    skip
  enddo
  go (aktAuftragsSatz)


  // ACHTUNG: hier AufBest top level je Kunde neu berechnen,;
  // disponiert verwenden geht nicht!!!;
  // select AufPost;
  // set rela to AUFPOST->AufNr into AufAus;
  // set filter to AUFAUS->KundNr==M_KundNr .and. AUFAUS->AufArt=="K" .and. ;
  // AUFAUS->AufNr<>M_AufNr .and. AUFPOST->ArtNr==M_ArtNr .and.;
  // AUFPOST->Menge > AUFPOST->GeliefGes
  // go top
  // do while ! AUFPOST->(eof())
  // bestellt+=(AUFPOST->Menge-AUFPOST->GeliefGes)
  // skip
  // enddo

  // set rela to
  // set filter to
  // select aufaus
  // go (M_recno)
  // select auftrag

  // // Addiere aktuellen Auftrag (Berabeitungsstand)
  // go top
  // do while ! AUFTRAG->(eof())
  // if AUFTRAG->ArtNr==M_ArtNr .and. aktAuftragsSatz<>AUFTRAG->(recno())
  // bestellt+=(AUFTRAG->Menge)
  // endif
  // skip
  // enddo
  // go (aktAuftragsSatz)

return bestellt
/**EOF */




/* FUNCTION Ang_HotKey()
*
* schaltet �bernahme Angebot auf F3
*/
FUNCTION Ang_HotKey(status)
  if status="ON"
    set key K_F3 to Ang_Ueber()
  else
    set key K_F3 to
  endif
RETURN .t.

/* bietet Hilfe mit Angeboten an, und �bernimmt selkt. als Auftrag */
PROCEDURE Ang_Ueber( ProcName, oGet )
LOCAL ant:="",zeile:=0, liefkw:="  /  "
LOCAL GetList:={} , merk_Farbe

  ignore procname

  if empty(oGet:Buffer) .or. oGet:buffer==KDNR_LEER .or. M->istAbrufAuftrag == "B"
    if open( "AngAus", "AngPost" )
      Hilfe("ANGEBOTE/UEBERNAHME",getnew(),"Blubb")
      keyboard ""
      if ! ABBRUCH

        select AufAus
        /* Kopiere KopfSatz */
        overwrite("AngAus",.t.)
        replace AUFAUS->AufArt with "R" // default kann sp�ter raus !
        replace AUFAUS->AufDat with getUser():date
        replace AUFAUS->BESTDAT with getUser():date
        replace AUFAUS->BESTNr with ""

        Umgebung(WRITE)
        merk_Farbe:=setcolor(COLWIN)
        Fenster(9,19,16,60,"Auftragsdaten eingeben")
        @ 11,21 say "Best.Datum" GET AUFAUS->BestDat valid ! empty(AUFAUS->BestDat) ;
          when Message('Bestelldatum eingeben        @*@=Heute @+@/@-@')
        @ 13,21 say "Best.Nr." GET AUFAUS->BestNr when Message('Bestell - Nr. eingeben.') ;
          valid {|oGet| bestNrNach(oGet)}
        @ 15,21 say "Liefer-KW" GET liefKW picture "!!/99" ;
          when Message('Liefer-Kalenderwoche eingeben.') valid kwOkay(liefKw)
        read
        setcolor(merk_Farbe)
        Umgebung(LOAD)

        KUNDEN->(dbseek(AUFAUS->KundNr))

        /* kopiere Bauchdaten */
        select Auftrag
        zap
        select AngPost
        dbseek(ANGAUS->AngNr)
        do while ANGPOST->AngNr==ANGAUS->AngNr .and. ! eof()
          select Auftrag
          add_rec(0)
          overwrite("AngPost",.t.)
          Auf_Satz_nach()

          // l�sche KW falls nicht g�ltig
          if .not. KWempty(liefKw)
            replace AUFTRAG->KW with liefKw
          elseif ! kwOkay( AUFTRAG->KW )
            replace AUFTRAG->KW with ""
          endif

          // 14.7.2023 L�sche KW Freitext
          replace AUFTRAG->KW_Text with ""

          select AngPost
          skip
        enddo

        // pr�fe auf aktuelle MwSt
        MWST_KZ->(dbseek(AUFAUS->MWST_KZ))
        if AUFAUS->Mwst <> MWST_KZ->MwSt
          replace AUFAUS->Mwst with MWST_KZ->MwSt
          Error(ACHTUNG+"MwSt wurde angepasst: " + str(AUFAUS->Mwst) + "%||"+;
            "         Bitte pr�fen.", .t.)
        endif

        Auf_Kopf_Disp()
        keyboard chr(13)
        oGet:changed:=.f. // Get ist NICHT ver�ndert
        setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
      endif // Abbruch
    endif
  else
    Ang_Hotkey("OFF")
    Error(ACHTUNG+" Angebot �bernehmen geht nur bei leerer Kundennummer.",.t.)
    Ang_Hotkey("ON")
  endif
RETURN

/** pr�ft ob Kunden eine Ident-Nr hat, wenn nicht Warung und Email an H. Weiland */
FUNCTION checkIdentNr(kundNr)
LOCAL GetList:={}
LOCAL s01:=savescreen()
LOCAL idNr:=KUNDEN->IdentNr

  Umgebung(WRITE)

  KUNDEN->(dbseek(kundnr))
  do while upper(KUNDEN->EG)$"J" .and.;
    (empty(KUNDEN->IdentNr) .or. ! syntaxIdentNr(KUNDEN->IdentNr,KUNDEN->Land))
    Error(ACHTUNG+"||Empf�nger "+KundNr+" "+trim(KUNDEN->kurzname)+" ohne Ident.Nr.",.t.)

    setcolor(COLWIN)
    Fenster(12,40,14,68)
    Message("Kunden-Identnummer bitte eingeben.")
    @ 13,42 say "Ident-Nr.:" get idNr picture "@!" valid syntaxIdentNr(idNR,KUNDEN->Land)
    read
    setcolor(COLNOR)

    if ABBRUCH .or. empty(idNr)
      If Message("Achtung Ident.Nr. muss eingegeben werden.   Wirklich beenden?  (@J@/@N@)",;
        "JN")=="J"
        Umgebung(LOAD)
        restscreen(,,,,s01)
        return .f.
      endif
      loop // try again
    else
      select Kunden
      if ! rec_lock(5)
        Error(TRY_AGAIN)
      else
        replace KUNDEN->IdentNr with idNr
        dbcommit()
        dbunlock()
        if getUser():id<>KURZEL_MAIN_CUSTOMER
          email(MAIN_EMAIL,;
            "Neue Ident.Nr f�r Kunde: "+KundNr+" "+trim(KUNDEN->Kurzname)+;
            " Ident.Nr.:"+KUNDEN->IdentNr,;
            "AB....: "+AUFAUS->AufNr+MY_CR+MY_LF+;
            "Kunde : "+KundNr+" "+trim(KUNDEN->Kurzname)+MY_CR+MY_LF+;
            "Id.Nr.: "+KUNDEN->IdentNr+MY_CR+MY_LF+;
            "Benutzer: "+getUser():id)
        endif
      endif
    endif
  enddo
  Umgebung(LOAD)
return .t.
/** eop */

/** setzt den Filter von Aufaus, je nach AufArt */
procedure setABFilter(Auftr_Art)
  select AufAus
  do case
  case Auftr_art==NIL
    set filter to
  case M->istAbrufAuftrag <> NIL
    set filter to ! empty(AUFAUS->Ab_AufNr)
  case Auftr_Art=="G" // Gutschrift
    set filter to AUFAUS->AufArt=="G"
  case Auftr_Art=="K" // K-Lager
    set filter to AUFAUS->AufArt=="K" .and. AUFAUS->InvKZ <> "J"
  case Auftr_Art=="I" // K-Lager Inventur
    set filter to AUFAUS->AufArt=="K" .and. AUFAUS->InvKZ=="J"
  case Auftr_Art=="D" // Rahmenauftrag Artikel
    set filter to AUFAUS->AufArt=="D"
  case Auftr_Art=="B" // Rahmenauftrag Budget
    set filter to AUFAUS->AufArt=="B"
  case Auftr_Art=="V" // Kostenvoranschlag
    set filter to AUFAUS->AufArt=="V"
  case Auftr_Art=="N" // K-Lager - Gutschrift
    // Nop, hier nicht m�glich
  otherwise
    set filter to empty(AUFAUS->Ab_AufNr) .and. .not. AUFAUS->AufArt$"VBDGKN"
  endcase
return
/** eop*/

/** liefert die Auftrags Art des zugeordneten Rahmenauftrags
*  zur�ck, Abrufauftrag in Aufaus muss selektiert sein
  */

FUNCTION getRahmABArt()
LOCAL aktSel:=alias(),result:=NIL
LOCAL merkFilter:=AUFAUS->(dbfilter())
LOCAL merkSatz:=AUFAUS->(recno())
LOCAL merkAbNr:=AUFAUS->Ab_AufNr

  select Aufaus
  set filter to
  AUFAUS->(dbseek(merkAbNr))
  if AUFAUS->(eof()) .or. ! AUFAUS->AufArt$"BD" // .or. AUFAUS->erledigt=="J"
    Error(merkAbNr+" ist kein g�ltiger Rahmenauftrag",.t.)
  else
    result:=AUFAUS->AufArt
  endif
  set filter to &(merkFilter)
  AUFAUS->(dbgoto(Merksatz))
  select (aktSel)

return result
/** eof */

/** wird nach Eingabe des Preises ausgef�hrt */
function preisNach(oGet,merkArt)
LOCAL s01, paletten

  // Wert zu gro�???
  if AUFTRAG->Menge*AUFTRAG->Preis > 999999999 .or. AUFTRAG->Menge*AUFTRAG->Preis < -99999999
    Error(ACHTUNG+" Max. Wert pro Posten ist 999.999.999,99.",.t.)
    return .f.
  endif

  // Rahmenauftrag Budget pr�fen
  if ! empty(AUFAUS->Ab_AufNr) .and. len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE
    if merkArt=="B" // Budget
      if ! budgetRahmAbStatus(.f.,.t.)
        Error(ACHTUNG+"Rahmenauftrag Budget kann nicht �berliefert werden.",.t.)
        return .f.
      endif
    endif
  endif

  // Hinweis, falls bei Fracht/Verpackung der Preis ge�ndert wurde,
  // obwohl dieser normalerweise nicht berechnet wird
  if oGet:changed
    if (len(alltrim(AUFTRAG->ArtNr)) == 2 .and. VERSART->Verpack =="N" )
      if val(oGet:buffer) <> 0
        s01:=savescreen()
        Error(ACHTUNG+"Verpackung wird bei diesem Kunde normalerweise nicht berechnet.",.f.)
        if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J" .or. ABBRUCH
          oGet:varput(0)
          oGet:updateBuffer()
        endif
        restscreen(,,,,s01)
      endif
    elseif (len(alltrim(AUFTRAG->ArtNr)) == 3 .and. VERSART->Fracht == "N")
      if val(oGet:buffer) <> 0
        s01:=savescreen()
        Error(ACHTUNG+"Fracht wird bei diesem Kunde normalerweise nicht berechnet.",.f.)
        if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J"
          oGet:varput(0)
          oGet:updateBuffer()
        endif
        restscreen(,,,,s01)
      endif
    endif
  endif

  // 8.11.2013 jetzt mit Warnung falls Preis = 0, au�er bei innerdeutschen Palettenversand
  paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )
  if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. val(oGet:buffer) == 0 .and.;
    lastkey() <> K_UP .and. ! ( AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr)))
    s01:=savescreen()
    Error(ACHTUNG+"Preis = 0 Euro",.f.)
    if Message("Trotzdem fortfahren? (@J@/@N@)","JN") <> "J" .or. ABBRUCH
      restscreen(,,,,s01)
      return .f.
    endif
    restscreen(,,,,s01)
  endif


return .t.
/** eof */

static function FaktZeitErfass(p1,oget,p2)
LOCAL gesStd:=0,zeitTemp
LOCAL s01,fehler:=.f.

  ignore p1,p2

  select Zeiterf
  zap

  // kopiere alte Posten aus AufZeit
  select AufZeit
  dbseek(AUFTRAG->ABPostNr)
  do while ! AUFZEIT->(eof()) .and. AUFTRAG->ABPostNr==AUFZEIT->ABPostNr
    select ZeitErf
    add_rec(0)
    replace ZEITERF->Start with AUFZEIT->Start
    replace ZEITERF->Ende with AUFZEIT->Ende
    replace ZEITERF->Pause with AUFZEIT->Pause
    replace ZEITERF->Personen with AUFZEIT->Personen
    select AufZeit

    if rec_lock(5)
      delete
    endif

    skip
  enddo

  s01:=savescreen()
  fakt_zeit_erfass(.t.)
  select Zeiterf
  go top
  do while .not. eof()
    // addiere Industrieminuten
    zeitTemp:=ZeitDif(ZEITERF->Start,ZEITERF->Ende,ZEITERF->Pause,,,ZEITERF->Personen)
    if zeitTemp<0 // Fehler bei Zeiteingabe
      restscreen(,,,,s01)
      Error(ACHTUNG+" fehlerhafte Zeiteingabe: "+str(ZEITERF->Start,5,2)+" - "+;
        str(ZEITERF->Ende, 5,2),.t.)
      fehler:=.t.
    else
      // if ZEITERF->Personen>1
      // zeitTemp:=ZeitTemp*ZEITERF->Personen
      // endif
      // FIXME: stimmt das???
      // gesStd +=INDMin( zeitTemp )
      gesStd += zeitTemp
    endif

    // kopiere nach AufZeit
    select AufZeit
    add_rec(0)
    replace AUFZEIT->Start with ZEITERF->Start
    replace AUFZEIT->Ende with ZEITERF->Ende
    replace AUFZEIT->Pause with ZEITERF->Pause
    replace AUFZEIT->Personen with ZEITERF->Personen

    replace AUFZEIT->ABPostNr with AUFTRAG->ABPostNr
    select Zeiterf

    skip
  enddo
  restscreen(,,,,s01)
  select Auftrag
  if gesStd>=0
    oGet:varput(gesStd)
    oGet:updateBuffer()

    // 20180711: KV immer gleich beliefert
    if AUFAUS->AufArt=="V"
      replace AUFTRAG->GeliefGes with oGet:varput(gesStd)
    endif

    if ! fehler
      keyboard chr(K_RETURN) // to avoid wrong sum on user abort (ESC)
    endif
  endif

return .t.

  /** Pr�ft ob Posten bereits beliefert -> darf nicht gel�scht werden
  * oder ob ein Posten bereits ein innerbetr. Auftrag existiert
  */
static function konsistenzLoesch()

  if AUFTRAG->GeliefGes > 0 .and. ! AUFAUS->AufArt="V" // Ausnahme KV
    Error(ACHTUNG+"Posten wurde bereits beliefert.||         Kann nicht gel�scht werden!",.t.)
    return .f.
  endif

  // pr�fe ob Zoll-Artikel
  if AUFAUS->ZollZuschl == "J" .and. isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and.;
    ! M->defAuftrArt $ "G"
    Error(ACHTUNG+"Zoll-Zuschl�ge werden automatisch hinzugef�gt.||"+;
      "Zum �ndern bitte Zollzuschlag in Kopfdaten auf N setzen")
    return .f.
  endif

  // pr�fen ob bereits innerbetr. Auftrag gedruckt
  // if ! empty(AUFTRAG->InLfdNr) .and. trim(AUFTRAG->InLfdNr) <> AB_NUR_LAGER
  // .and. trim(AUFTRAG->InLfdNr) <> AB_ALTER_ADEL
  // INNER->(dbseek(AUFTRAG->InLfdNr))

  // s01:=savescreen()
  // if INNER->(eof())
  // Error("Innerbetr. Auftrag:"+alltrim(AUFTRAG->InLfdNr)+"/"+INNER->InnerNr+;
  // " nicht gefunden.||"+AUFTRAG->AufNr+" "+AUFTRAG->ArtNr + SCHWERER_FEHLER )
  // // Info: Datensatz wird trotzdem gel�scht
  // else

  // if ! INNER->gedruckt $ INNER_DRUCK_NEU + INNER_DRUCK_LEER
  // Error(ACHTUNG+;
  // "Posten ist bereits innerbetr. Auftrag:"+alltrim(AUFTRAG->InLfdNr)+"/"+INNER->InnerNr+;
  // " zugewiesen.||"+;
  // "         Wenn Sie diesen Datensatz l�schen, werden alle innerbetr. Auftr�ge,|"+;
  // "         die zu diesem Posten geh�ren, gel�scht!",ERR_NO_WAIT)
  // If Message("Trotzdem fortfahren? (@J@/@N@)","JN"," ")<>"J"
  // restscreen(,,,,s01)
  // return .f.
  // endif
  // restscreen(,,,,s01)
  // endif

  // endif
  // endif

  // now delete via editor.prg
  HB_KeyPut(EDIT_DELETE)

return .t.
  /** eof */

static function myDelete()
  // Satz nicht l�schen, sondern nur als gel�scht markieren, falls Auftrag bereits existiert
  replace AUFTRAG->Geloescht with "J"

  // update KW falls noch andere Artikel dazu in AB sind
  // FIXME: was ist wenn nein? Soll der innerbetr. Auftrag gel�scht werden?
  // warte auf Feedback von MW 14.10.14
  updateInnerKW()

  pruefeZuschlaege()

  dispEditorSumme("AUFAUS")
return .t.


  /** Pr�ft ob ein Posten bereits ein innerbetr. Auftrag existiert ->
  * muss innerbetr. Auftrag ebenfalls �ndern
  */
static function konsistenzAend()
LOCAL s01

  // pr�fen ob bereits innerbetr. Auftrag erstellt
  if ! empty(AUFTRAG->InLfdNr) .and. trim(AUFTRAG->InLfdNr) <> AB_NUR_LAGER ;
    .and. trim(AUFTRAG->InLfdNr) <> AB_ALTER_ADEL
    s01:=savescreen()
    INNER->(dbseek(AUFTRAG->InLfdNr))
    if ! INNER->gedruckt $ INNER_DRUCK_NEU + INNER_DRUCK_LEER + INNER_DRUCK_NOCHMAL
      Error(ACHTUNG+"Posten ist bereits innerbetr. Auftrag: "+alltrim(AUFTRAG->InLfdNr)+"/"+;
        trim(INNER->InnerNr)+" zugewiesen.||"+;
        "         Wenn Sie diesen Datensatz bearbeiten, m�ssen die |"+;
        "         innerbetrieblichen Auftr�ge ebenfalls neu bearbeitet werden!",ERR_NO_WAIT)
      If Message("Trotzdem fortfahren? (@J@/@N@)","JN"," ")<>"J"
        restscreen(,,,,s01)
        return .f.
      endif
      restscreen(,,,,s01)
    endif
  endif

  // now edit line via editor.prg
  HB_KeyPut(EDIT_LINE_EDIT)

return .t.
/** eof */

/** pr�ft und zeigt die Menge aller Rahmenauftr�ge des Artikels an */
static function artRahmAbMenge( abfrage )
LOCAL merkArt:=getRahmABArt()
LOCAL restmenge,merkSatz,merkArtNr,gesAbruf,AufMerkSatz
LOCAL mengeAltAbruf,gesMenge,gesLiefMenge,M_order
LOCAL abNrs:=""

  default Abfrage:=.f.

  if merkArt="D" // Artikel Rahmen-Auftrag

    if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
      return .t.
    endif

    if getRahmenABNr( AUFTRAG->ArtNr ) == NIL
      Error(ACHTUNG+" Artikel in keinem Rahmenauftrag von: "+AUFAUS->Kurzname+" gefunden.",.t.)
      AUFPOST->(OrdSetFocus(m_order))
      select Auftrag
      return .f.
    endif

    // Anmerkung: Summenbildung extra hier, da i.d.R. nur 1 Posten je Artikel & Abruf

    // summiere offene Gesamt-Menge aller Posten dieses Artikels in Rahmen-AB
    gesMenge:=0
    gesLiefMenge:=0
    AufMerksatz:=AUFAUS->(recno())
    select AufPost
    AUFPOST->(OrdSetFocus(2)) // KundNr+Anr
    AUFPOST->(dbseek(AUFAUS->KundNr+"D" + AUFTRAG->ArtNr ))
    do while ! AUFPOST->(eof()) .and. AUFPOST->KundNr ==AUFAUS->KundNr .and.;
      AUFPOST->ArtNr==AUFTRAG->ArtNr .and. AUFPOST->AufArt == "D"
      AUFAUS->(dbseek( AUFPOST->AufNr ))
      if AUFAUS->erledigt <> "J"
        gesMenge+=AUFPOST->Menge
        gesLiefMenge+=AUFPOST->GeliefGes

        if ! AUFPOST->AufNr $ abNrs
          abNrs += AUFPOST->AufNr + " "
        endif
      endif
      AUFAUS->(dbgoto(AufMerksatz))
      skip
    enddo
    select AufPost
    AUFPOST->(OrdSetFocus(m_order))

    // summiere alle bereits erfassten Mengen in aktuellen Auftrag
    select Auftrag
    merkSatz:=AUFTRAG->(recno())
    merkArtNr:=AUFTRAG->ArtNr
    gesAbruf:=0
    go top
    do while ! AUFTRAG->(eof())
      // addiere alle au�er aktuellen Datensatz
      if AUFTRAG->ArtNr==merkArtNr .and. AUFTRAG->(recno())<>merkSatz
        gesAbruf+=AUFTRAG->Menge
      endif
      skip
    enddo
    AUFTRAG->(dbgoto(MerkSatz))

    // hole urspr. MengenSumme dieses Auftrags (falls kein Neu-Auftrag)
    ABRUF->(dbseek(AUFTRAG->ArtNr))
    if ABRUF->(eof())
      mengeAltAbruf:=0
    else
      // mengeAltAbruf ist hier negativ!!!
      mengeAltAbruf:=abs(ABRUF->Menge)
    endif

    restmenge:=gesMenge-gesLiefMenge+mengeAltAbruf-gesAbruf-AUFTRAG->Menge

    Error("Info: Rahmenauftrag "+AbNrs+"||"+;
      "      Gesamt-Menge.....: "+transstr(gesMenge,11,2)+"|"+;
      "      Bereits abgerufen: "+transstr(gesLiefMenge-mengeAltAbruf,11,2)+"|"+;
      "      Jetziger Abruf...: "+transstr(gesAbruf+AUFTRAG->Menge,11,2)+"|"+;
      "                          =========="+"|"+;
      "      Rest Menge.......: "+transstr(restMenge,11,2),.t.)

    select Auftrag

    // neu 20160819
    if restMenge < 0 .and. getUser():id $ KURZEL_MAIN_CUSTOMER + "|" + KURZEL_DEVEL + "AB" // Frau Berndt
      if Message("Auftrag �berliefern? (@J@/@N@)","JN","N") =="J" .and. ! ABBRUCH
        return .t.
      endif
    endif

  endif
return restMenge >= 0
/** eof */

/** Kopiert beim aktuellen Artikel die dt. Bezeichnung auf die engl. */
FUNCTION copyGTextPosten()

  if empty(AUFTRAG->E_Komm1) .or.;
    Message("Englischen Text �berschreiben?  (@J@/@N@)","JN","N")=="J"
    replace AUFTRAG->E_Komm1 with AUFTRAG->Komm1
    replace AUFTRAG->E_Komm2 with AUFTRAG->Komm2
  endif

return .t.
/** eof */


/** kopiert die Miki Adresse als Versandadresse, z.VB. bei Werkzeug dass bei Miki bleibt */
STATIC PROCEDURE copyMikiAdresse()
LOCAL aktRec:=KUNDEN->(recno())

  KUNDEN->(dbseek( MIKI_NR ))
  if KUNDEN->(eof())
    Error(ACHTUNG+"Kunde Miki nicht gefunden: " + MIKI_NR + SCHWERER_FEHLER)
    return
  endif
  REPLACE AUFAUS->V_KundNr WITH KUNDEN->KundNr
  REPLACE AUFAUS->V_Name WITH KUNDEN->Name2
  REPLACE AUFAUS->V_Partner WITH KUNDEN->Partner2
  REPLACE AUFAUS->V_Strasse WITH KUNDEN->Strasse2
  REPLACE AUFAUS->V_Zusatz WITH KUNDEN->Zusatz2
  REPLACE AUFAUS->V_Plz WITH KUNDEN->PLZ2
  REPLACE AUFAUS->V_Land WITH KUNDEN->Land2
  REPLACE AUFAUS->V_Ort WITH KUNDEN->Ort2
  REPLACE AUFAUS->V_Sprache WITH KUNDEN->Sprache2

  if M->defAuftrArt <> "I" // Ausnahme K-Lager Inventur-Auftrag
    REPLACE AUFAUS->VersNr WITH KUNDEN->VersNr
  endif

  // Sammelstelle
  REPLACE AUFAUS->S_Name WITH KUNDEN->S_Name
  REPLACE AUFAUS->S_Partner WITH KUNDEN->S_Partner
  REPLACE AUFAUS->S_Strasse WITH KUNDEN->S_Strasse
  REPLACE AUFAUS->S_Zusatz WITH KUNDEN->S_Zusatz
  REPLACE AUFAUS->S_Plz WITH KUNDEN->S_PLZ
  REPLACE AUFAUS->S_Land WITH KUNDEN->S_Land
  REPLACE AUFAUS->S_Ort WITH KUNDEN->S_Ort
  REPLACE AUFAUS->S_Sprache WITH KUNDEN->S_Sprache

  copyIdentFromRechnungsAdresse()

  KUNDEN->(dbgoto(aktRec))
return
/** eop */

/** Kopiert die Ident.Nr. von Rechhnungs-Empf�nger (laut Telefonat 3.1.2014 MW)
  */
static procedure copyIdentFromRechnungsAdresse()
LOCAL aktRec:=KUNDEN->(recno())

  KUNDEN->(dbseek( AUFAUS->R_KundNr ))
  REPLACE AUFAUS->IdentNr WITH KUNDEN->IdentNr
  Error("Info: Versand-Adresse wurde auf Miki-Plastik gesetzt.||"+;
    "      Ident.Nr. laut Rechnungsadresse: "+AUFAUS->IdentNr+" AB:"+AUFAUS->AufNr,.t.)

  trouble("IdentNr",{"Ident.Nr. von Rechn.Adresse �bernommen: "+AUFAUS->IdentNr})

  if ! checkIdentNr( AUFAUS->R_KundNr )
    email(MAIN_EMAIL,"AB: "+AUFAUS->AufNr+" bitte Ident-Nr. pr�fen.")
  endif
  KUNDEN->(dbgoto(aktRec))

return
/** eop */

/** Pr�ft ob bei ausl�nd. Kunden Werkzeug und andere Artikel gemeinsam angeboten werden */
static FUNCTION checkWerkzeug()
LOCAL aktRec:=recno(),aktSel:=alias()
LOCAL okay:=.t. // we're optimistic

  // kein Problem bei deutschen Kunden oder neuen Angeboten
  if upper(AUFAUS->EG) == "D" .or. AUFTRAG->(reccount()) == 0
    return .t.
  endif

  select Auftrag
  loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()=="W"
  if ! AUFTRAG->(eof())
    loca for len(alltrim(AUFTRAG->ArtNr))>FRACHT_LAENGE .and. getArtikelArt()<>"W"
    okay:=AUFTRAG->(eof())
  endif
  select (aktSel)

  if ! okay
    Error(ACHTUNG+"Werkzeuge und andere Artikel k�nnen bei ausl�nd. Kunden|"+;
      "         nicht gemeinsam berechnet werden.",.t.)
  endif

return okay
/** eof */

  /** pr�ft ob der Artikel-Text ge�ndert wurde und gibt Hinweis auf
  *   englischen Text, if applicable
  */
static FUNCTION checkeEnglish()
LOCAL aktColor, s01
LOCAL x:=10 , y:=25
LOCAL GetList:={}
LOCAL subject, body
LOCAL aktRec:=AUFPOST->(recno())
LOCAL aktOrd:=AUFPOST->(indexOrd())
LOCAL identisch

  if empty( AUFTRAG->ArtNr )
    return .t.
  endif

  if inStackTrace("LineEdit") // ouch!

    // temp. nur falls Eingabe aktuell in Deutsch
    if LAND->Sprache==DEUTSCH


      // Englisch notwendig?
      if AUFAUS->Sprache == ENGLISCH .or. AUFAUS->V_Sprache == ENGLISCH .or.;
        AUFAUS->R_Sprache == ENGLISCH .or. AUFAUS->S_Sprache == ENGLISCH

        // wurde ge�ndert?
        AUFPOST->(OrdSetFocus( 5 )) // ABPostNr
        AUFPOST->(dbseek( AUFTRAG->ABPostNr ))
        // neuer Datensatz -> vergleiche mit Artikel
        if empty(AUFTRAG->ABPostNr) .or. AUFPOST->(eof())
          identisch:=( left(AUFTRAG->Komm1,30) == ARTIKEL->Bez1 .and.;
            left(AUFTRAG->E_Komm1,30) == ARTIKEL->E_Bez1 .and.;
            left(AUFTRAG->Komm2,30) == ARTIKEL->Bez2 .and.;
            left(AUFTRAG->E_Komm2,30) == ARTIKEL->E_Bez2 )
        else // ge�nderter Datensatz -> vergeleiche mit AufPost
          identisch:=( AUFTRAG->Komm1 == AUFPOST->Komm1 .and. AUFTRAG->E_Komm1 == AUFPOST->E_Komm1 ;
            .and. AUFTRAG->Komm2 == AUFPOST->Komm2 .and. AUFTRAG->E_Komm2 == AUFPOST->E_Komm2)
        endif

        if ! identisch
          aktColor:=setcolor(COLWIN)
          s01:=savescreen()

          Fenster(x-2,y-2,x+2,y+31,"Englische Bezeichnung:")
          set key K_F8 to copyGermanText(NIL,oGet,NIL)
          Message("Bitte englische Bezeichnung eingeben.   @F8@=deutschen Text kopieren")
          @ x,y get AUFTRAG->E_Komm1 picture replicate("X",30)
          @ x+1,y get AUFTRAG->E_Komm2 picture replicate("X",30)
          read
          set key K_F8 to

          restscreen(,,,,s01)
          setcolor(aktColor)

          // Email an H. Weiland, falls nicht erfasst
          if len(trim(AUFTRAG->E_Komm1)) <=5 .or. ;
            (AUFTRAG->E_Komm1 = AUFTRAG->Komm1 .and. AUFTRAG->E_Komm2 = AUFTRAG->Komm2)
            subject:="AB englischen Text bitte pr�fen: "+out(AUFTRAG->ArtNr)
            body:=""
            body+="Artikel:  "+out(AUFTRAG->ArtNr)+MY_CR+MY_LF
            body+="Deutsch:  "+AUFTRAG->Komm1+MY_CR+MY_LF
            body+="          "+AUFTRAG->Komm2+MY_CR+MY_LF
            body+="Englisch: "+AUFTRAG->E_Komm1+MY_CR+MY_LF
            body+="          "+AUFTRAG->E_Komm2+MY_CR+MY_LF
            body+="verwendet in Auftrag: "+AUFAUS->AufNr+" "+AUFAUS->Kurzname+MY_CR+MY_LF
            body+="K�rzel: "+getUser():id+MY_CR+MY_LF
            // EMail an H. Weiland
            email(MAIN_EMAIL,subject,body)
          endif

        endif
        AUFPOST->(OrdSetFocus( aktOrd ))
        AUFPOST->(dbgoto(aktRec))
      endif
    endif
  endif

return .t.
/** eof */

/** Kopiert beim aktuellen Artikel die dt. Bezeichnung auf die engl. */
static FUNCTION copyGermanText(p1,oGet)

  ignore p1

  if empty(AUFTRAG->E_Komm1) .or.;
    Message("Englischen Text �berschreiben?  (@J@/@N@)","JN","N")=="J"
    replace AUFTRAG->E_Komm1 with AUFTRAG->Komm1
    replace AUFTRAG->E_Komm2 with AUFTRAG->Komm2

    // Ausgabe akt. Get
    setCargo(oGet,CARGO_DISP_GETLIST,.t.)
    oGet:exitState:=GE_TOP
    oGet:KillFocus()

  endif

return .t.
/** eof */


/**
  * schickt Emails an H. Weiland, falls abweichende Versart etc.
  */
static procedure sendEmailMW(flags)
LOCAL subject:="AB mit abweichenden Stammdaten - Kunde: "+KUNDEN->KundNr
LOCAL body:="Auftrag: "+AUFAUS->AufNr + MY_CR+MY_LF + ;
  "Kunde  : "+KUNDEN->KundNr+" "+trim(KUNDEN->KurzName) + MY_CR+MY_LF + ;
  "K�rzel : "+getUser():id +MY_CR+MY_LF
LOCAL aktRec:=KUNDEN->(recno())
LOCAL Spedits , i

  if flags == 0
    return
  endif

  if HB_BitAnd( flags , EMAIL_ABWEICHENDE_VERSART) > 0
    body += MY_CR+MY_LF
    KUNDEN->(dbseek( AUFAUS->V_KundNr ))
    VERSART->(dbseek( KUNDEN->VersNr ))
    body+="Versand-Art" + MY_CR+MY_LF
    body+="===========" + MY_CR+MY_LF
    body+="Kunde  : "
    body+="Nr. " + KUNDEN->VersNr + " " + VERSART->Text + MY_CR+MY_LF
    VERSART->(dbseek( AUFAUS->VersNr ))
    body+="Auftrag: "
    body+="Nr. " + AUFAUS->VersNr + " " + VERSART->Text + MY_CR+MY_LF
  endif

  if HB_BitAnd( flags , EMAIL_ABWEICHENDE_ZAHLKOND) > 0
    body += MY_CR+MY_LF
    KUNDEN->(dbseek( AUFAUS->R_KundNr ))
    ZAHLKOND->(dbseek( KUNDEN->ZKNr ))
    body+="Zahlungskonditionen" + MY_CR+MY_LF
    body+="===================" + MY_CR+MY_LF
    body+="Kunde  : "
    body+="Nr. ";
      + KUNDEN->ZkNr + " " + trim(ZAHLKOND->Text)+" "+trim(ZAHLKOND->Text2) + MY_CR+MY_LF
    ZAHLKOND->(dbseek( AUFAUS->ZkNr ))
    body+="Auftrag: "
    body+="Nr. ";
      + AUFAUS->ZkNr + " " + trim(ZAHLKOND->Text)+" "+trim(ZAHLKOND->Text2) + MY_CR+MY_LF
  endif

  if HB_BitAnd( flags , EMAIL_ABWEICHENDE_SPEDITION) > 0
    spedits:=getKundSpedits( KUNDEN->KundNr )
    KUNDEN->(dbseek( AUFAUS->V_KundNr ))

    body += MY_CR+MY_LF
    body+="Spedition" + MY_CR+MY_LF
    body+="=========" + MY_CR+MY_LF
    for i:=1 to len( spedits )
      SPEDIT->(dbseek( spedits[i] ))
      body+="Kunde  : Sped.Nr. " + SPEDIT->SpedNr + " " + SPEDIT->Name + MY_CR+MY_LF
    next
    SPEDIT->(dbseek( AUFAUS->SpedNr ))
    body+= MY_CR+MY_LF
    body+="Auftrag: "
    body+="Sped.Nr. " + AUFAUS->SpedNr + " " + SPEDIT->Name + MY_CR+MY_LF

  endif

  // sende EMail an H. Weiland
  email(MAIN_EMAIL,subject,body)

  KUNDEN->(dbgoto( aktRec ))

return
/** eop */

  /** tr�gt die �bergebene Menge von offenen Rahmenauftr�gen des Kunden ab
  *
  * mMEnge kann pos. oder neg. sein.
  *
  * D - Dispositions Auftrag (Rahmenauftrag - Artikel)
  */
static procedure rahmAbtrag( mKundNr, mArtNr, mMenge , mME )
LOCAL diff
LOCAL subject,body

  if mMenge == 0 // no changes
    return
  endif

  Umgebung(WRITE_ALL)

  // abtragen Menge pos.
  if mMenge > 0

    select AufPost
    index on dtos(AUFPOST->AufDat) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      AUFPOST->KundNr == mKundNr .and. AUFPOST->ArtNr == mArtNr .AND. AUFPOST->AufArt == "D"

    go top
    do while ! AUFPOST->(Eof()) .and. mMenge > 0
      if AUFPOST->Menge > AUFPOST->GeliefGes .and. rec_lock(5)
        diff:=AUFPOST->Menge - AUFPOST->GeliefGes
        replace AUFPOST->GeliefGes with AUFPOST->GeliefGes + Min( diff, mMenge )
        mMenge -= Min( diff, mMenge )
      endif
      skip // Aufpost
    enddo

    // alle abgetragen?
    if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE .and. mMenge > 0 // sollte nicht passieren
      KUNDEN->(dbseek( mKundNr ))
      EINHEIT->(dbseek( mME ))
      subject:="Artikel: "+AUFTRAG->ArtNr+" - Rahmenauftr�ge �berliefert."
      body:="Kunde......: "+mKundNr+" "+KUNDEN->KurzName +MY_CR+MY_LF
      body+="Auftrag....: "+AUFAUS->AufNr +MY_CR+MY_LF
      body+="�berliefert: "+ str(mMenge,9,2) + " "+EINHEIT->Text + MY_CR+MY_LF
      body+="K�rzel: "+getUser():id +MY_CR+MY_LF
      // EMail an H. Weiland
      email(MAIN_EMAIL,subject,body)
    else

      // Rahmen-ABs komplett beliefert?
      if AUFPOST->(eof())
        go bottom
        if AUFPOST->Menge <= AUFPOST->GeliefGes
          KUNDEN->(dbseek( mKundNr ))
          EINHEIT->(dbseek( mME ))
          subject:="Artikel: "+AUFTRAG->ArtNr+" - Rahmenauftr�ge alle beliefert."
          body:="Artikel....: "+AUFTRAG->ArtNr+" "+AUFTRAG->komm1 +MY_CR+MY_LF
          body+="Auftrag....: "+AUFAUS->AufNr +MY_CR+MY_LF
          body+="Rahmen-AB..: "+AUFAUS->AB_AufNr +MY_CR+MY_LF
          body+="Kunde......: "+mKundNr+" "+KUNDEN->KurzName +MY_CR+MY_LF
          body+="K�rzel: "+getUser():id +MY_CR+MY_LF
          body+=MY_CR+MY_LF
          body+="Evtl. sollte ein neuer Rahmanauftrag mit dem Kunden vereinbart werden.";
            + MY_CR+MY_LF
          // EMail an H. Weiland
          email(MAIN_EMAIL,subject,body)
        endif
      endif
    endif

  else // mMenge < 0

    select AufPost
    index on dtos(AUFPOST->AufDat) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      AUFPOST->KundNr == mKundNr .and. AUFPOST->ArtNr == mArtNr .AND. AUFPOST->AufArt == "D"

    go bottom
    do while ! AUFPOST->(bof()) .and. mMenge < 0
      if rec_lock(5)
        if AUFPOST->GeliefGes > 0
          diff:=AUFPOST->GeliefGes
          replace AUFPOST->GeliefGes with AUFPOST->GeliefGes - Min( diff, abs( mMenge ) )
          mMenge += Min( diff, abs( mMenge ) )

          // Auftrag wiederherstellen falls bereits als erledigt markiert
          AUFAUS->(dbseek( AUFPOST->AufNr ))
          if AUFAUS->erledigt == "J"
            select Aufaus
            rec_lock(0)
            replace AUFAUS->erledigt with " "
            dbcommit()
            dbunlock()
            select AufPost
          endif
        endif
      endif
      skip -1 // Aufpost
    enddo

    // keine Rahmen-ABs mehr gefunden
    if mMenge < 0
      KUNDEN->(dbseek( mKundNr ))
      EINHEIT->(dbseek( mME ))
      subject:="Artikel: "+AUFTRAG->ArtNr+" - Rahmenauftr�ge konnten nicht zur�ckgesetzt werden."
      body:="Kunde......: "+mKundNr+" "+KUNDEN->KurzName +MY_CR+MY_LF
      body+="Auftrag:...: "+AUFAUS->AufNr +MY_CR+MY_LF
      body+="�berliefert: "+ alltrim(str(mMenge,9,2)) + " "+EINHEIT->Text + MY_CR+MY_LF
      body+="K�rzel: "+getUser():id +MY_CR+MY_LF
      // EMail an H. Weiland
      email(MAIN_EMAIL,subject,body)
    endif

  endif

  Umgebung(LOAD)
return
/** eop */

  /** Geht auf den 1. offenen Rahmen-AB.
  *
  * liefert die AbNr oder NIL wenn nicht gefunden
  */
static function getRahmenABNr( mArtNr )
LOCAL result:=nil
LOCAL mKundNr:=AUFAUS->KundNr
  // pr�fe ob Rahmenauftrag f�r Artikel & Kunde existiert

  Umgebung(WRITE_ALL)

  select AufAus
  setABFilter() // AB Filter l�schen
  set filter to
  select AufPost
  set rela to AUFPOST->AufNr into Aufaus
  AUFPOST->(OrdSetFocus(2)) // KundNr + AufArt + Anr
  AUFPOST->(dbseek(mKundNr+"D" + mArtNr ))
  do while ! AUFPOST->(eof()) .and. mKundNr == AUFPOST->KundNr .and.;
    mArtNr == AUFPOST->ArtNr .and. AUFPOST->AufArt=="D"
    if AUFPOST->Menge > AUFPOST->GeliefGes .and. AUFAUS->erledigt<>"J"
      result:=AUFPOST->AufNr
    endif
    skip
  enddo

  Umgebung(LOAD)

return result
/** eof */

static procedure rahmAberledigt()
LOCAL mRecnr, abnrs:="", erledigt

  Umgebung(WRITE_ALL)

  // pr�fe ob alle Posten der Rahmen-ABs komplett geliefert -> dann als erledigt markieren
  // oder umgekehrt wieder aktivieren bei �nderung

  Message("Rahmenauftr�ge werden gepr�ft.   Bitte warten...")

  select Auftrag
  go top
  do while ! AUFTRAG->(eof())
    if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
      skip
      loop
    endif

    select Aufpost
    AUFPOST->(OrdSetFocus( 4 )) // ArtNr
    dbseek( AUFTRAG->ArtNr )
    do while ! AUFPOST->(eof()) .and. AUFPOST->ArtNr == AUFTRAG->ArtNr
      if ! AUFPOST->AufNr $ abNrs
        abNrs += ":" + AUFPOST->AufNr
        mRecNr:=AUFPOST->(recno())

        AUFAUS->(dbseek( AUFPOST->AufNr ))
        if AUFAUS->erledigt <> "J"
          select AufPost
          AUFPOST->(OrdSetFocus( 1 )) // AufNr
          AUFPOST->(dbseek( AUFAUS->AufNr ))
          erledigt:=.t.
          do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr==AUFAUS->AufNr .and. erledigt
            erledigt:=(AUFPOST->Menge <= AUFPOST->GeliefGes)
            skip
          enddo

          if erledigt
            select AufAus
            rec_lock(0,.t.)
            replace AUFAUS->erledigt with "J"
            dbcommit()
            dbunlock()
            select AufPost
          endif

        endif

        AUFPOST->(OrdSetFocus( 4 )) // ArtNr
        AUFPOST->(dbgoto( mRecNr ))
      endif
      skip
    enddo

    select Auftrag
    skip
  enddo

  Umgebung(LOAD)

return
/** eop */

static function sammelEdit()
LOCAL GetList:={}
LOCAL li:=20 , ob:=10
LOCAL orgAltF8:=SetKey( K_F8 , { |p1,oGet| sammelDelete(p1,oGet) } )

  Umgebung(WRITE_ALL)

  setcolor(COLWIN)

  Message("Adresse Sammelstelle eingeben.   @F8@=Sammelstelle f�r dies AB l�schen")
  Fenster(ob,li,ob+8,li+44,"Sammelstelle:")

  @ ob+8,li+14 say ""
  @ ob+ 2,li+2 get AUFAUS->S_Name picture"@K"
  @ ob+ 3,li+2 get AUFAUS->S_Partner picture"@K"
  @ ob+ 4,li+2 get AUFAUS->S_Strasse picture"@K"
  @ ob+ 5,li+2 get AUFAUS->S_Zusatz picture"@K"
  @ ob+ 6,li+2 get AUFAUS->S_land picture "@!" ;
    valid { |oGet| empty(AUFAUS->S_Name) .or. (check(oGet,"Land",.f.,.f.) .and. nachKundLandS(oGet))}
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 6,li+5 get AUFAUS->S_Plz picture"@K"
  @ ob+ 6,li+13 get AUFAUS->S_Ort picture"@K"
  LAND->(dbseek(left(AUFAUS->S_Land,2)))
  @ ob+ 7,li+2 say trim(LAND->Name)

  @ ob+ 7,li+22 say "Sprache:" get AUFAUS->S_Sprache picture"!" ;
    valid AUFAUS->S_Sprache $ "ED" .and. message() ;
    when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")

  read
  SetKey( K_F8 , orgAltF8)

  Umgebung( LOAD )

return .t.
/** eop */

static function alternativeAdrEdit()
LOCAL GetList:={}
LOCAL li:=20 , ob:=10
LOCAL orgAltF8:=SetKey( K_F8 , { |p1,oGet| altAdrDelete(p1,oGet) } )

  Umgebung(WRITE_ALL)

  setcolor(COLWIN)

  Message("Alternative Rechnungs-Adresse eingeben.   @F8@=Adresse f�r dies AB l�schen")
  Fenster(ob,li,ob+8,li+44,"Alternative Rechnungs-Adresse:")

  @ ob+8,li+14 say ""
  @ ob+ 2,li+2 get AUFAUS->A_Name picture"@K"
  @ ob+ 3,li+2 get AUFAUS->A_Partner picture"@K"
  @ ob+ 4,li+2 get AUFAUS->A_Strasse picture"@K"
  @ ob+ 5,li+2 get AUFAUS->A_Zusatz picture"@K"
  @ ob+ 6,li+2 get AUFAUS->A_land picture "@!" ;
    valid { |oGet| empty(AUFAUS->A_Name) .or. (check(oGet,"Land",.f.,.f.) )}
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 6,li+5 get AUFAUS->A_Plz picture"@K"
  @ ob+ 6,li+13 get AUFAUS->A_Ort picture"@K"
  LAND->(dbseek(left(AUFAUS->A_Land,2)))
  @ ob+ 7,li+2 say trim(LAND->Name)

  read
  SetKey( K_F8 , orgAltF8)

  Umgebung( LOAD )

return .t.
/** eop */

static function sammelDelete(p1,oGet)

  ignore p1

  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe

  replace AUFAUS->S_Name with ""
  replace AUFAUS->S_Partner with ""
  replace AUFAUS->S_Strasse with ""
  replace AUFAUS->S_Zusatz with ""
  replace AUFAUS->S_Land with ""
  replace AUFAUS->S_PLZ with ""
  replace AUFAUS->S_ORT with ""
  replace AUFAUS->S_Sprache with ""

return .t.
/** eof */

static function altAdrDelete(p1,oGet)
  ignore p1
  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  altAdrDel()
return .t.
/** eop */

static function altAdrDel()
  replace AUFAUS->A_Name with ""
  replace AUFAUS->A_Partner with ""
  replace AUFAUS->A_Strasse with ""
  replace AUFAUS->A_Zusatz with ""
  replace AUFAUS->A_Land with ""
  replace AUFAUS->A_PLZ with ""
  replace AUFAUS->A_ORT with ""


return .t.
/** eof */

/** �berpr�ft nach Beendigung des Edit-Modus ob Zuschl�ge f�r Zoll f�llig werden,
  sowie den Ph�nix-Versand als Palette oder Paket */
Function pruefeZuschlaege(Datei)
LOCAL text:="" , aktKW, pauschArtNr
LOCAL anzKartons:=0, anzPaletten:=0 , gesKartons:=0 , gesPaletten:=0
LOCAL kartonsProPalette, pauschalePaletten:=0, pauschaleKartons:=0
LOCAL pauschaleMenge, pauschalePreis, spedNrKartons, spedNrPaletten // topLine
LOCAL result:=.t. // we#re optimistic
LOCAL gesamtWert:=0 , changed:=.f., aktRec
LOCAL isPhoenixAB, oneTime:=.t.

  default datei:="Aufaus"

  // nicht bei erledigten ABs und bei Gutschriften
  if upper(Datei)=="AUFAUS" .and. ((DATEI)->erledigt == "J" .or. M->defAuftrArt $ "G")
    return .t.
  endif

  // Zoll / EUR1 Zuschl�ge f�r alle Artikel weiter unten
  Umgebung(WRITE_ALL)

  // pr�fe Ph�nix Versand Pauschalen
  isPhoenixAB:=isPhoenixAuftrag()
  do while oneTime
    oneTime:=.f.
    if isPhoenixAB .and. (DATEI)->PhoenixFr <> "N"

      changed:=.t.

      kartonsProPalette:=val( getProperty("Miki.phoenix.kartons.palette","20") )

      // Hole Pauschalwerte
      if selectPhoenixPauschale((DATEI)->V_KundNr , PAUSCHALE_KARTON)
        pauschaleKartons:=KUNDSPED->VK
        spedNrKartons:=KUNDSPED->SpedNr
      else
        Error(ACHTUNG+"Kunde: "+(DATEI)->V_KundNr+" keine Pauschale f�r Kartons hinterlegt.")
        loop // ab zu zoll zuschlag
      endif

      if selectPhoenixPauschale((DATEI)->V_KundNr , PAUSCHALE_PALETTE)
        pauschalePaletten:=KUNDSPED->VK
        spedNrPaletten:=KUNDSPED->SpedNr
      else
        Error(ACHTUNG+"Kunde: "+(DATEI)->V_KundNr+" keine Pauschale f�r Paletten hinterlegt.")
        loop // ab zu zoll zuschlag
      endif

      // // Ausnahme Paletten innerhalb Deutschland -> immer Sped.Hofmann
      // if left((DATEI)->V_Land,2) == DEUTSCH_LAND .and. spedNrPaletten != NIL

      // // pr�fe auf Hofmann
      // if spedNrPaletten <> getProperty("Miki.phoenix.spedition.DE","")
      // Error(ACHTUNG+"Spedition in Deutschland f�r Ph�nix-Artikel weicht ab.|"+;
      // "         Bitte beim Kunden oder miki.cfg �ndern.|"+;
      // "         bei Kunde: " + spedNrPaletten + " config: " + ;
      // getProperty("Miki.phoenix.spedition.DE",""))
      // if Message("Trotzdem fortfahren?  (@J@/@N@)","JN","N") <> "J"
      // Umgebung( LOAD )
      // return .f.
      // endif
      // M->emailAbweichend:=hb_bitOr( M->emailAbweichend , EMAIL_ABWEICHENDE_SPEDITION )
      // endif
      // endif

      // l�sche alle vorher hinzugef�gten unbelieferten Ph�nix Pauschale Artikel
      select Auftrag
      go top
      do while ! AUFTRAG->(eof())
        if isPhoenixPauschaleArtikel( AUFTRAG->ArtNr ) .and. AUFTRAG->GeliefGes == 0
          if upper(DATEI)=="AUFAUS"
            replace AUFTRAG->Geloescht with "J"
          else
            delete
          endif
          changed:=.t.
        endif
        skip
      enddo

      if changed .and. upper(DATEI)=="ANGAUS"
        pack
      endif

      // sortiere alle 305er Ph�nix nach KW
      index on kwindex(AUFTRAG->Kw) + AUFTRAG->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        isPhoenixOberArtikel( AUFTRAG->ArtNr ) .and. AUFTRAG->GeliefGes == 0

      // addiere Menge je KW
      go top
      do while ! AUFTRAG->(eof())
        aktKW:=AUFTRAG->KW
        anzKartons:=0
        anzPaletten:=0
        do while ! AUFTRAG->(eof()) .and. aktKW == AUFTRAG->KW
          anzKartons += AUFTRAG->Menge
          skip
        enddo

        // pr�fe Versandart

        // pr�fe ob Palettenversand oder Karton auf Grund der Menge
        // oder auf Grund des Preises
        if anzKartons >= kartonsProPalette .or. ;
          ( pauschalePaletten > 0 .and. anzKartons * pauschaleKartons > pauschalePaletten )

          anzPaletten:=kartons2paletten( anzKartons )

          if anzPaletten == 1
            text += "KW: " + aktKw + str( anzPaletten , 5,0)+ " Palette"+MY_CR+MY_LF
          else
            text += "KW: " + aktKw + str( anzPaletten , 5,0)+ " Paletten"+MY_CR+MY_LF
          endif

          anzKartons:=0
          gesPaletten += anzPaletten

        else // nur Kartonversand

          if anzKartons == 1
            text += "KW: " + aktKw + str( anzKartons , 10,2) + " Karton"+MY_CR+MY_LF
          else
            text += "KW: " + aktKw + str( anzKartons , 10,2) + " Kartons"+MY_CR+MY_LF
          endif

          gesKartons += anzKartons

        endif

        // Pauschalen-Artikel hinzuf�gen
        text += MY_CR+MY_LF
        if anzKartons > 0
          text += "    Pauschale Kartons:"+MY_CR+MY_LF
          pauschArtNr:=getPhoenixArtikelPauschaleKarton( (DATEI)->V_Land )
          pauschaleMenge:=anzKartons
          pauschalePreis:=pauschaleKartons

          replace (DATEI)->SpedNr with spedNrKartons

        else
          text += "    Pauschale Paletten:"+MY_CR+MY_LF
          pauschArtNr:=getPhoenixArtikelPauschalePalette( (DATEI)->V_Land )
          pauschaleMenge:=anzPaletten
          pauschalePreis:=pauschalePaletten

          if ! empty( (DATEI)->SpedNr ) .and. (DATEI)->SpedNr <> spedNrPaletten
            replace (DATEI)->SpedNr with spedNrPaletten
            Error(ACHTUNG+"Spedition wurde aus Kundenstamm �bernommen.||"+;
              "         Falls abweichende Spedition gew�nscht bitte beim Kunden|"+;
              "         mit entsprechender Versandart PP/PK hinterlegen.")
          endif

        endif

        aktRec:=AUFTRAG->(ordKeyNo())
        addPauschale( pauschArtNr , Datei )

        replace AUFTRAG->Menge with pauschaleMenge

        // Ausnahme innerdeutscher Versand mit Hofmann (zahlt Ph�nix)
        if left((DATEI)->V_Land,2) == DEUTSCH_LAND .and. anzKartons == 0 .and.;
          spedNrPaletten == getProperty("Miki.phoenix.spedition.DE","")
          REPLACE AUFTRAG->Preis WITH KUNDSPED->Aufschlag + KUNDSPED->Versand
        else
          REPLACE AUFTRAG->Preis WITH pauschalePreis
        endif

        // nehme aktuelle KW
        replace AUFTRAG->KW with aktKw

        // Anzeige f�r Benutzer erg�nzen
        text += "    " + aktKw + " " + AUFTRAG->ArtNr + " " + AUFTRAG->Komm1 + ;
          str( AUFTRAG->Preis * AUFTRAG->Menge , 10 ,2 ) + EURO_SIGN + MY_CR+MY_LF

        if ! empty( AUFTRAG->Komm2 )
          text += space(14) + AUFTRAG->Komm2 + MY_CR+MY_LF
        endif
        text += MY_CR+MY_LF

        AUFTRAG->(OrdKeyGoTo( aktRec ))

      enddo // AUFTRAG->(eof())

      AUFTRAG->(OrdSetFocus( 0 ))

      // Kartons & Paletten nicht in einer AB zulassen!
      if gesPaletten > 0 .and. gesKartons > 0
        text:="ACHTUNG: Paletten und Kartonversand k�nnen nicht in einer AB realsiert."+MY_CR+MY_LF+;
          "         werden.   Bitte separate AB anlegen." + MY_CR+MY_LF + + MY_CR+MY_LF + text

        setcolor(COLWIN)
        Fenster(14,1,23,77,"Fehler")
        Message("@ESC@=Ende")
        MemoEdit(text,15,2,22,76, .f.,,100)
        setcolor(COLNOR)

        result:=.f.

        // else

        // // �nderungen Benutzer anzeigen
        // topLine:=if(len(HB_ATokens( text ,MY_CR+MY_LF)) > 8,5,15)
        // setcolor(COLWIN)
        // Fenster(topLine - 1,1,23,77,"Versand als")
        // Message(ARROW_UP+ARROW_DOWN+"      @ESC@=Ende")
        // MemoEdit(text,topLine,2,22,76, .f.,,100)
        // setcolor(COLNOR)

      endif

    endif
  enddo

  // alle Artikel!!!
  // Zoll / EUR1 Zuschl�ge f�r alle Artikel
  SPEDIT->(dbseek( (DATEI)->SpedNr ))

  // l�sche alle vorher hinzugef�gten unbelieferten Zoll/EUR1 Zuschl�ge
  if (DATEI)->ZollZuschl == "J" .and. ! (DATEI)->EG $ "DJ"
    select Auftrag
    go top
    do while ! AUFTRAG->(eof())
      if isZollZuschlagArtikel( AUFTRAG->ArtNr ) .and. AUFTRAG->GeliefGes == 0
        if upper(DATEI)=="AUFAUS"
          replace AUFTRAG->Geloescht with "J"
        else
          delete
        endif
        changed:=.t.
      endif
      skip
    enddo
    if changed .and. upper(DATEI)=="ANGAUS"
      pack
    endif
  endif

  gesamtWert:=summeAuftrag( Datei )

  // Zoll Zuschlag f�r nicht EU Empf�nger?
  if (DATEI)->ZollZuschl == "J" .and. ! (DATEI)->EG $ "DJ"
    if isPhoenixAB .and. SPEDIT->SpedKz == "J" // seit 31.5.2016
      // Palette Ph�nix immer 100 Euro
      addPauschale( getProperty("Miki.zoll.aufschlag.gross","") , Datei , .f.) // am Ende
      changed:=.t.
    else // ansonsten 50 Euro

      // ab 14.6.2016 wieder nur falls > limit
      if gesamtWert > val( getProperty("Miki.zoll.aufschlag.limit","1000") )
        addPauschale( getProperty("Miki.zoll.aufschlag.klein","") , Datei , .f.) // am Ende
        changed:=.t.
      endif

      // bis 20160614: jetzt doch wieder raus, lt. H. Weiland verwirrt.
      // addPauschale( getProperty("Miki.zoll.aufschlag.klein","") , Datei , .f.) // am Ende
      // changed:=.t.
      // // bei <= 1000 Euro mit Preis 0
      // if gesamtWert <= val( getProperty("Miki.zoll.aufschlag.limit","1000") )
      // REPLACE AUFTRAG->Preis WITH 0
      // endif
    endif

    // GesamtWert hier nochmal berechnen, kann sich mit Zoll Aufschlag ge�ndert haben.
    gesamtWert:=summeAuftrag( Datei )

    // EUR1 Erkl�rung Pauschale dazu bei Wert > 6000 Euro
    // seit 17.9.2016 nur noch f�r Pr�ferenzl�nder
    LAND->(dbseek(left((DATEI)->V_Land,2)))
    if LAND->LLE=="J" .and.;
      gesamtWert > val( getProperty("Miki.zoll.aufschlag.EUR1.limit","6000") )
      addPauschale( getProperty("Miki.zoll.aufschlag.EUR1","") , Datei , .f.) // am Ende
      changed:=.t.
    endif

  endif

  Umgebung( LOAD )

  if changed
    HB_KeyPut(EDIT_BS_REFRESH)
    keyboard chr(K_HOME) // needed since recno may has changed

    if upper(Datei)=="AUFAUS"
      dispEditorSumme(Datei)
    else
      dispEditorSumme("ANGAUS","AUFTRAG->Menge",41)
    endif
  endif

return result
/** eof */

/** F�gt den angegeben Pauschal-Artikel zum Auftrag hinzu */
static procedure addPauschale( mArtNr , Datei, before)
LOCAL aktFocus

  default before:=.t.

  ARTIKEL->(dbseek( ShiftArtikel( mArtNr )))

  if ARTIKEL->(eof())
    Error(ACHTUNG+"Artikel: + " + mArtNr + " Pauschale Versand / Zoll nicht gefunden.|"+;
      "         Bitte anlegen!")
  else

    select Auftrag
    aktFocus:=AUFTRAG->(OrdSetFocus( 0 ))

    // add_rec(0)
    if before
      insertBlank(.t.) // before
    else
      append blank
    endif
    replace AUFTRAG->KundNr with (DATEI)->KundNr // wurde evtl. ge�ndert
    replace AUFTRAG->ArtNr with ShiftArtikel( mArtNr )
    REPLACE AUFTRAG->Art WITH getArtikelArt()
    replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
    replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
    replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
    replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2
    replace AUFTRAG->Me WITH ARTIKEL->ME
    replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
    replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
    replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
    REPLACE AUFTRAG->Rabatt WITH 0

    replace AUFTRAG->ABPostNr with val(hole("ABPostNr",WRITE,.t.))

    // Standard-Menge f�r Zuschl�ge Zoll, Eur1
    replace AUFTRAG->Menge with 1
    REPLACE AUFTRAG->Preis WITH ARTIKEL->Preis1

    replace AUFTRAG->ABPostNr with val(hole("ABPostNr",WRITE,.t.))

    // added 20171119
    replace AUFTRAG->Inhalt with ARTIKEL->Inhalt
    replace AUFTRAG->InhaltME with ARTIKEL->InhaltME

    dbcommit()

    AUFTRAG->(OrdSetFocus( aktFocus ))

  endif
return
/** eof */

/** liefert die Gesamtsumme abzgl. Rabatten des akt. Auftrags */
function summeAuftrag(KopfDatei,mengenFeld,displaySumme)
LOCAL gesamtWert:=0, wert, fracht:=0
LOCAL aktRec:=recno()
LOCAL datei:=alias(), sonder, zuschlag

  default mengenFeld:="AUFTRAG->Menge"
  default displaySumme:=.f.

  // ermittle Gesamtwert
  go top
  do while ! &(DATEI)->(eof())

    // als gel�schte markierte ignorieren
    if fieldpos( "geloescht" ) == 0 .or. &(DATEI)->geloescht $ "N "

      wert:=round(&(mengenFeld)*&(DATEI)->Preis / if(&(DATEI)->PE=="H",100,1),2)
      if &(DATEI)->Rabatt<>0
        wert:=wert - round(wert*&(DATEI)->Rabatt/100,2)
      endif

      if len(alltrim(&(DATEI)->ArtNr)) <= FRACHT_LAENGE
        fracht+= wert
      else
        gesamtWert+= wert
      endif

      // endif
    endif
    skip

  enddo
  go (aktRec)

  // Sonder-Rabatt auf Gesamt AB nur f�r Artikel, nicht f�r Fracht und Verpackung
  if (KOPFDATEI)->(fieldpos( "So_Rabatt" )) > 0 .and. (KOPFDATEI)->So_Rabatt <> 0
    sonder:=round(gesamtWert*(KOPFDATEI)->So_Rabatt/100,2)
    gesamtWert -= sonder
  endif

  // Energiekosten-Zuschlag
  if (KOPFDATEI)->(fieldpos( "Zuschlag" )) > 0 .and. (KOPFDATEI)->Zuschlag <> 0
    zuschlag:=round(gesamtWert*(KOPFDATEI)->Zuschlag/100,2)
    gesamtWert += zuschlag
  endif

  if displaySumme
    @ maxrow()-3,0 say space(maxcol())
    @ maxrow()-2,1 to maxrow()-2,maxcol()-1
    @ maxrow()-1,20 say space(60)

    gesamtWert:=summeAuftrag( KopfDatei, mengenFeld)

    if valtyp(sonder) == "N"
      @ maxrow()-1,18 say "Rabatt:"+transstr(sonder,9,2)+" "+EURO_SIGN
    endif
    if valtyp(zuschlag) == "N"
      @ maxrow()-1,38 say "Zuschlag:"+transstr(zuschlag,10,2)+" "+EURO_SIGN
    endif
    @ maxrow()-1,61 say "Netto:"+transstr(gesamtWert,10,2)+" "+EURO_SIGN
  endif

return round(gesamtWert+fracht,2)
/** eof */

  /** Gibt Summen-Zeile und andere Posten Infos am Ende des Auftrags am BS aus
  *
  */
function dispEditorSumme(KopfDatei,mengenFeld,pos)
  ignore pos

  summeAuftrag( KopfDatei, mengenFeld, .t.)

RETURN .t.
/** eof */


/** wird nach Eingabe des ZollZuschlags Flags J/N in den Kopfdaten ausgef�hrt */
function nachZollZuschlag(oGet,Datei)
LOCAL aktSel:=alias()
  if oGet:changed
    if ! oGet:buffer $ "JN"
      return .f.
    endif
    if oGet:Buffer=="J"
      select Auftrag
      pruefeZuschlaege(Datei)
      select (aktSel)
    endif
  endif
return .t.
/** eof */

/** wird bei Taste Z aus Editor -> zur�ck in den AB Kopf ausgef�hrt */
static function editABKopf(aKopf, viewOnly)
LOCAL aktSel:=alias()

  default viewOnly:=.f.

  M->versandChanged:=.f.
  Auf_Kopf_Disp()
  Auf_Kopf(if(viewOnly,2,1))
  if viewOnly
    Message("Bitte @Taste@ dr�cken","@")
  else
    if getUpdated()
      aKopf[EDIT_CHANGED]:=.t.
    endif
    // if AUFTRAG->(reccount()) > 0 .and. M->versandChanged
    if M->versandChanged
      select Auftrag
      pruefeZuschlaege()
    endif
  endif
  select (aktSel)
return .t.
/** eof */

/** �bernimmt die KW in folgende Fracht-Artikel */
static function updateFrachtKW(oGet)
LOCAL aktRec:=AUFTRAG->(recno())
  if oGet:changed .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
    skip
    do while len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. ! AUFTRAG->(eof())
      // nur Verpackung keine Fracht
      if len(alltrim(AUFTRAG->ArtNr)) < FRACHT_LAENGE
        replace AUFTRAG->Kw with oGet:Buffer
      endif
      skip
    enddo
    go (aktRec)
  endif
return .t.
/** eof */

/** �bernimmt die KW in alle Postem (z.B. bei Phoenix) */
static function updateAllKW(oGet)
LOCAL aktRec:=AUFTRAG->(recno())
  if oGet:changed
    go top
    do while ! AUFTRAG->(eof())
      if len(alltrim(AUFTRAG->ArtNr)) > 1 // ausser Kommentar
        replace AUFTRAG->Kw with oGet:Buffer
      endif
      skip
    enddo
    go (aktRec)
  endif
return .t.
  /** eof */

/* bucht beim KV (Kostenvoranschlag) den Artikel (bzw. bei Fracht die St�ckliste) gleich ab.
*/
static procedure bucheVKArtikel( mArtNr, diffKVMenge , mAufNr)
LOCAL aktSel:=alias()
  if diffKVMenge <> 0 .and. M->defAuftrArt <> "I" // Inventur-Auftrag ist bereist gebucht
    if len(alltrim(mArtNr))<= FRACHT_LAENGE
      select AvPost
      seek mArtNr
      /* St�ckliste abbuchen */
      do while ! eof() .and. mArtNr==AVPOST->AvNr
        if AVPOST->Art="M" .and. AVPOST->Text="A" // Material ben�tigt
          ARTIKEL->(dbseek(AVPOST->ArtNr))
          ARTIKEL->(REC_LOCK(0))
          aendArtBest(diffKVMenge *(-1) * AVPOST->Menge , WARAUS_KVNR+mAufNr)
          dbcommit()
          unlock
          select AvPost
        endif
        skip
      enddo
    else
      ARTIKEL->(dbseek(mArtNr))
      select Artikel
      rec_lock(0)
      aendArtBest(diffKVMenge * (-1) , WARAUS_KVNR + mAufNr)
      dbcommit()
      unlock
    endif
    select (aktSel)
  endif
return
/** eop */



/*
* zum summieren der Arbeitszeit
*/
static PROCEDURE fakt_Zeit_erfass()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE_ALL)

  select ZeitErf
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=8 // N: Begin des Eingabe-Berreiches BS
  // aKopf[EDIT_ENDE_Y]:=18 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-5 // N: Ende des Eingabe-Berreiches BS abzgl. von MaxRow()
  aKopf[EDIT_LM]:=30
  aKopf[EDIT_RM]:=76
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->ZEITERF->Pause:="N", _FIELD->ZEITERF->Personen:=1 }
  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_DRAW_FRAME]:="Zeit-Erfassung"

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Start"
  aSpalte[EDIT_TITEL]:="Start"
  aSpalte[EDIT_AFTER]:={ |oGet| Zeit_Eingabe(oGet) }
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Arbeits-Beginn eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Ende"
  aSpalte[EDIT_TITEL]:="Ende"
  aSpalte[EDIT_AFTER]:={ |oGet| Zeit_Eingabe(oGet) }
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Arbeits-Ende eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Pause"
  aSpalte[EDIT_TITEL]:="Pause"
  aSpalte[EDIT_AFTER]:={ |oGet| oget:Buffer$"JN"}
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Pause durchgearbeitet ? (@J@/@N@)"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(ZeitDif(ZEITERF->Start,ZEITERF->Ende,ZEITERF->Pause,.t.,.t.,ZEITERF->Personen),5,2)"
  aSpalte[EDIT_TITEL]:=" Zeit"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MASKE]:="99.99"
  aSpalte[EDIT_SUMME]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Personen"
  aSpalte[EDIT_TITEL]:="Pers."
  aSpalte[EDIT_MASKE]:="9"
  aSpalte[EDIT_MESSAGE]:="Anzahl der beteiligten Mitarbeiter eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf,.f.) // edit without restoring windows size, since this is an embedded editor
  Umgebung(LOAD)

RETURN
/* EOP */



  /** liefert den MwstSatz zur aktuellen AB,
  Ausnahme falls Lieferung noch in 2020, dann 16%
  FIXME: remove me in 2021
  */
static function getABMwst()
LOCAL result:=AUFAUS->Mwst
LOCAL in2020:=.f.
LOCAL aktSel:=alias()
LOCAL aktRec:=AUFTRAG->(recno())

  if result==19
    select Auftrag
    go top
    do while ! AUFTRAG->(eof()) .and. .not. in2020
      in2020:=right(AUFTRAG->Kw,2)=="20"
      skip
    enddo
    if in2020
      result:=16.00
    endif
    AUFTRAG->(dbgoto( aktRec ))
    select (aktSel)
  endif
return result
  /** eof */


/** L�scht das Lagerbestand OK Kennzeichen in allen Artikeln der AB rekursiv */
static procedure resetABMatKennzeichen()
LOCAL children, mArtNr
  select Auftrag
  go top
  do while ! AUFTRAG->(eof())
    if len(alltrim(ARTIKEL->ArtNr)) > FRACHT_LAENGE
      resetArtikelMatKennzeichen(AUFAUS->AufNr)
      children:=StueckListe():new(ARTIKEL->ArtNr,,1):getChildren("M",.t.,.t.)
      for each mArtNr in children:Keys
        ARTIKEL->(dbseek(martnr))
        resetArtikelMatKennzeichen(AUFAUS->AufNr)
      next
      select Auftrag
    endif
    skip
  enddo

return
  /** eop */

/* l�scht das Bestand OK kennzeichen des aktuellen Artikels, falls ABNr nicht darin enthalten
  => dann erscheint Artikel wieder in Liste: checkMatVerfuegbar()
*/
static procedure resetArtikelMatKennzeichen(aufnr)
LOCAL aktSel:=alias()
  if ! empty(ARTIKEL->Best_OK) .and. ! aufnr $ ARTIKEL->Best_OK
    select Artikel
    if rec_lock(5)
      replace ARTIKEL->Best_OK with ""
      dbcommit()
      dbunlock()
    endif
    select (aktSel)
  endif
return
  /* EOP */

  /** pr�ft ob f�r den Kunden ein Budget Rahmenauftrag existiert.
  * Falls ja: liefert AB Nr, ansonsten empty String
  */
static function getBudgetAuftragNr(kdnr)
LOCAL aktSel:=alias()
LOCAL aktRec:=AUFAUS->(recno())
LOCAL result

  setABFilter() // AB Filter l�schen
  select Aufaus
  loca for AUFAUS->AufArt == "B" .and. AUFAUS->erledigt<>'J' .and. AUFAUS->KundNr==kdnr
  result:=AUFAUS->AufNr
  AUFAUS->(dbgoto( aktRec ))
  select (aktSel)
  setAbFilter(M->defAuftrArt)

return result
/** eof */

/* kopiert Kunden-Kontaktdaten in Auftragskopf */
static function copy_kunden_kontakt(oGet, p1)
LOCAL var, fields:={"Ansprech", "Email", "Telefon", "Fax" }

  ignore p1

  Hilfe("KundKontakt", getnew(), "Blubb")

  if ! KDKONTAKT->(eof()) .and. lastkey()==K_RETURN
    // HB_KEYCLEAR()
    // if message("Alle Felder �bernehmen?  (@J@=Alle/@N@=nur aktuelles Feld)","JN","J")=="N"
    // fields:={substr(oGet:Name, at(">",oGet:Name)+1)}
    // endif

    if ! ABBRUCH
      for each var in fields
        replace &("AUFAUS->"+var) with &("KDKONTAKT->"+var)
      next
      keyboard chr(K_RETURN)
      setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
    endif
  endif

return .t.
  /** eof */

static procedure editAnsprechPartner()
LOCAL GetList:={}

  MYSetKey( K_F12 , {|p1,oGet| copy_kunden_kontakt(oGet,p1) } )

  @ 20,1 get AUFAUS->Ansprech;
    when Message("Ansprechpartner eingeben   @F12@=Kundendaten �bernehmen")
  @ 22,1 get AUFAUS->Email picture "@S47" valid {|oget| isValidEmail(oget)} ;
    when Message("Email-Adresse eingeben   @F12@=Kundendaten �bernehmen")
  @ 20,49 get AUFAUS->Telefon when Message("Telefonnummer eingeben   @F12@=Kundendaten �bernehmen")
  @ 22,49 get AUFAUS->Fax when Message("Faxnummer eingeben   @F12@=Kundendaten �bernehmen")

  read

  MYSetKey( K_F12 , {|p1,oGet| Hilfe(oGet,p1)} )

return
/** eop */  
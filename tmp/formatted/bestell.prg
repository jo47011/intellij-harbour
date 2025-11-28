/* Modul: Bestell.prg
*
* enth�lt alles bzgl. Bestellungen: erfassen,l�schen,drucken
*/

#include "Miki.ch"

#define TEMP_NUMMER right("*****"+getUser():getLongID(),len(BESAUS->BestNr))
#define MINDEST_LAENGE 4 // alles was kleiner ist ist innerbetr.

/* erfassen von Bestellungen
*
* Parameter: nurPreisanfrage
*            mArtNr -> falls nicht leer wird dieser bei einer neuen Bestellung hinzugef�gt
*                      s. launchNeueBestellung
*/
PROCEDURE Best_erfassen(nurPreisanfrage,mArtNr,mBesPostNr)
LOCAL Ende:=.f., Ausgabe, changed:=.f.,changedKopf:=.f.
LOCAL ant:="N", Summe, Wert, deleteBestellung
LOCAL GetList:={}
LOCAL Quelle:="",M_BestNr, okay, startRec, verpackungen, veredelung, istNeu , sucheMatKz, aktRec
LOCAL Parents, mat , neueBestellung , temp, diff, Material
MEMVAR MerkNr
PRIVATE MerkNr:=0

  default nurPreisanfrage:=.f.

  Umgebung(WRITE_ALL)

  cls

  if ! open( "Bestell" , "BesAus" , "ZahlKond" ,"BestKart" ,"LiefTerm";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "Lieferan", "Kunden", "KdKontakt";
    ,"AvPost" , "System" , "WarAus" , "BesPost" , "Text_Kz";
    ,"Mat_kz","Land","Auftrag", "AufAus", "AufPost","M_Mehrf","ArtText")

    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  /* Relationen setzten */
  select Bestell
  SET RELATION TO BESTELL->ArtNr INTO Artikel, to BESTELL->ME INTO EINHEIT
  select BesAus
  set relation to BESAUS->Mwst_Kz into MWst_kz,BESAUS->VersNr into VersArt
  go bottom
  skip // leeren Satz anzeigen

  do while ! Ende

    select BesAus

    if nurPreisanfrage
      Titel("Preisanfrage erfassen/drucken")
      add_rec(0) // temp. dummy Datensatz
      // REPLACE BESAUS->BestNr with "PrAnf"
      REPLACE BESAUS->AufDat WITH getUser():date
      REPLACE BESAUS->BestDat WITH getUser():date
      REPLACE BESAUS->MWST_KZ WITH "1"
      // REPLACE BESAUS->erledigt with "J" // just in case
      MWST_KZ->(dbseek("1"))
      REPLACE BESAUS->MWST WITH MWST_KZ->MWST
      M->MerkNr:=recno()
    else
      Titel("Bestellung  erfassen/drucken")
      go bottom
      M->MerkNr:=0
      skip // leeren Satz anzeigen
    endif

    /* Kopf eingeben */
    @ 2,0 clear
    Best_Kopf_Disp(nurPreisanfrage)
    Ende:=Best_Kopf(if(nurPreisanfrage,1,0)) // editierbar
    changedKopf:=getUpdated()

    /* gehe auf editierten Satz */
    select BesAus
    if M->MerkNr==0 .or. Ende
      if nurPreisanfrage
        // temp. BESAUS Datensatz l�schen
        select BesAus
        delete
      endif
      loop
    endif
    go M->MerkNr

    dbcommitall()

    /*** Posten kopieren ***/
    select Bestell
    zap

    // neu: filter auf ungel�schte Posten
    set filter to BESTELL->geloescht$"N "

    istNeu:=(BESAUS->BestNr == TEMP_NUMMER)

    if istNeu // neue Bestellung
      if mArtnr <> NIL // �bernehme Artikel-Vorschlag aus launchNeueBestellung?
        select Bestell
        add_rec(0)
        replace BESTELL->LiefNr with BESAUS->LiefNr
        replace BESTELL->ArtNr with mArtNr
        copyArtikelDaten(nurPreisanfrage)
        select BesPost
      endif
    else // vorhandene Bestellung
      select BesPost
      BESPOST->(OrdSetFocus(1)) // BestNr
      seek BESAUS->BestNr

      // hier eigentlich: append("BesPost", { || BESPOST->BestNr==BESAUS->BestNr } ,.t.)
      // aber schneller direkt, da abbuchen je Posten
      do while BESPOST->BestNr==BESAUS->BestNr .and. ! eof()
        rec_lock(0) // FIXME: why? wird unten doch gleich wieder aufgehoben?
        select Bestell
        add_rec(0)
        overwrite("BesPost")
        select BesPost
        dbcommit()
        dbunlock()

        if mBesPostNr == BESPOST->BesPostNr
          startRec:=BESTELL->(recno())
        endif

        skip
      enddo
    endif

    /*** Posten editieren **/
    okay:=.f.
    deleteBestellung:=.f.
    veredelung:=.f.
    neueBestellung:=.f.
    do while ! okay

      if BESAUS->erledigt=="J"
        changed:=best_Bauch(.f.,.t. , mArtNr<>nil , startRec ) // keine Preisanfrage, aber nur Anzeige
        if ! changed // Posten k�nnen seit 31.1.15 doch ge�ndert werden (auch aus Bestellkarte)
          okay:=.t.
          loop // we bail out
        endif
      else
        changed:=Best_Bauch(nurPreisanfrage , .f. , mArtNr<>nil , startRec )
      endif

      changed:=(changed .or. ChangedKopf)

      // falls Bestellung neu erfasst und keine Posten -> Abfrage verwerfen
      select Bestell
      loca for BESTELL->Menge > 0
      if BESTELL->(eof())
        ant:=" "
        do while ! ant $ "JN"
          if BESAUS->BestNr==TEMP_NUMMER
            ant:=Message("Bestellung verwerfen?  (@J@/@N@)","JN")
          else
            ant:=Message("Bestellung ist leer.  Bestellung l�schen?  (@J@/@N@)","JN")
          endif
        enddo
        if ! ABBRUCH .and. ant == "J"
          okay:=.f.
          if BESAUS->BestNr <> TEMP_NUMMER
            deleteBestellung:=.t.
          endif
          if mArtnr <> NIL // l�sche Artikel-Vorschlag aus launchNeueBestellung?
            mArtnr:=nil
          endif
          exit
        endif

      endif

      okay:=.t.

      // pr�fe Mindest.Bestellwert des Lieferanten
      if LIEFERAN->MindWert>0
        // addiere aktuellen Bestellwert
        select Bestell
        go top
        summe:=0
        do while ! BESTELL->(eof())
          wert:=BESTELL->Menge*BESTELL->Preis / iif(BESTELL->PE$"Hh",100,1)
          wert = wert - wert * BESTELL->rabatt/100
          summe += wert
          skip
        enddo

        if summe > 0 .and. summe < LIEFERAN->MindWert
          Error(ACHTUNG+" Mindestbestellwert bei "+LIEFERAN->Kurzname+": |"+;
            "|          Aktueller Bestellwert : "+transstr(summe,9,2) + EURO_SIGN + ;
            "|          Mindest   Bestellwert : "+transstr(LIEFERAN->MindWert,9,2) + EURO_SIGN ,.t.)

          if getUser():id <> KURZEL_MIKI_GF .and. getUser():id <> KURZEL_DEVEL
            okay:=Message("Fortfahren trotz unterschrittenem Mindestbestellwert? (@J@/@N@)","JN","N") == "J"
            if okay
              email(MAIN_EMAIL,;
                "Bestellung mit unterschrittenem Mindestbestellwert!  Best.Nr.: "+BESAUS->BestNr,;
                "Bitte pr�fen:||Mindestbestellwert bei "+LIEFERAN->Kurzname+" |"+;
                "|Bestell-Nummer        : "+BESAUS->BestNr + ;
                "|Aktueller Bestellwert : "+transstr(summe,9,2) + EURO_SIGN + ;
                "|Mindest   Bestellwert : "+transstr(LIEFERAN->MindWert,9,2) + EURO_SIGN ,.t.)
            endif
          endif
        endif

      endif

      // pr�fe ob Eingabe von Verpackungen bei diesem Lieferanten Pflicht ist.
      if okay .and. ! empty(LIEFERAN->Verpackung)
        verpackungen:=HB_ATokens(strtran(LIEFERAN->Verpackung," ","") ,",")
        select Bestell
        loca for aContains( verpackungen , alltrim(BESTELL->ArtNr) ) .and. BESTELL->Menge > 0
        if BESTELL->(eof())
          if at( "," , LIEFERAN->Verpackung) == 0
            Error(ACHTUNG+" Bitte Verpackung: " + LIEFERAN->Verpackung + "eingeben.")
          else
            Error(ACHTUNG+" Bitte Verpackungen: " + LIEFERAN->Verpackung + "eingeben.")
          endif
          okay:=.f.
        endif
      endif

      // pr�fe ob Veredeleung M+W mit Weiterleitung an Fa. Rieker
      if okay .and. BESAUS->LiefNr == getProperty("Miki.bestell.veredelung.von","") .and. ;
        BESAUS->V_LiefNr <> getProperty("Miki.bestell.veredelung.an","")
        // pr�fe ob Bestellung einen Artikel mit entspr. MatKz enth�lt
        select Bestell
        go top
        sucheMatKz:=getProperty( "Miki.bestell.veredelung.matkz" )
        do while ! BESTELL->(eof()) .and. ! veredelung .and. ! empty(sucheMatKz)
          veredelung:=(ARTIKEL->MatKz == sucheMatKz)
          skip
        enddo
        if veredelung
          aktRec:=LIEFERAN->(recno())
          LIEFERAN->(dbseek( getProperty("Miki.bestell.veredelung.an","") ))
          if LIEFERAN->(eof())
            Error(ACHTUNG+"Veredelung wird weitergeleitet an:||"+;
              "         Lieferant: " + getProperty("Miki.bestell.veredelung.an","") + " nicht gefunden.")
          else
            Error(ACHTUNG+"Veredelung wird weitergeleitet an:||"+;
              "         "+LIEFERAN->LiefNr + " "+ LIEFERAN->KurzName)
            replace BESAUS->V_LiefNr with LIEFERAN->LiefNr
            REPLACE BESAUS->V_Name WITH LIEFERAN->Name1
            REPLACE BESAUS->V_Partner WITH LIEFERAN->Name2
            REPLACE BESAUS->V_Strasse WITH LIEFERAN->Strasse
            REPLACE BESAUS->V_Zusatz WITH LIEFERAN->Zusatz
            REPLACE BESAUS->V_Plz WITH LIEFERAN->PLZ
            REPLACE BESAUS->V_Land WITH LIEFERAN->Land
            REPLACE BESAUS->V_Ort WITH LIEFERAN->Ort
            LIEFERAN->(dbgoto(aktRec))
          endif
        endif


      endif

    enddo // ! okay

    // Bestellung l�schen?
    if deleteBestellung

      trouble("BestProt",{BESAUS->BestNr+" Bestellung manuell gel�scht"})

      select BesPost
      dbseek( BESAUS->BestNr )
      do while ! BESPOST->(eof()) .and. BESAUS->BestNr == BESPOST->BestNr
        rec_lock(0)
        delete
        dbcommit()
        skip
      enddo
      select BesAus
      rec_lock(0)
      delete
      select Bestell
      zap
      dbcommitall()
      loop
    endif

    // Bestellung verwerfen? (neu erfasste ohne Posten)
    if ! okay
      loop
    endif

    /* ausdrucken, r�ckschreiben */
    Ausgabe:="D"
    setcolor(COLWIN)
    Fenster(5,16,13,57)
    @ 6,20 say 'Drucken als:'
    if nurPreisanfrage
      @ 8,20 say ' A. Preisanfrage '
    else
      @ 8,20 say ' A. Bestellung: '
      if BESAUS->BestNr==TEMP_NUMMER // neuer Satz
        QQOut( Hole("BestNr",LOAD) )
      else
        QQOut( BESAUS->BestNr )
      endif
    endif
    Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
    @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/P) ' get Ausgabe Picture "!" valid Ausgabe $"DBP"
    read
    // Login_change(12,20,"Sachbearbeiter: ")
    setcolor(COLNOR)

    if ABBRUCH .and. changed
      SetLastKey(0)
      HB_KEYCLEAR()
      Ausgabe:="P"
    endif

    if nurPreisanfrage
      Best_Drucken(Ausgabe,.t.)

      // Posten nicht r�ckschreiben & temp. BESAUS Datensatz l�schen
      select BesAus
      delete
      loop
    endif

    // leere Bestellung anlegen sollte gehen

    /* neue Best.Nr. vergeben */
    if BESAUS->BestNr==TEMP_NUMMER // neuer Satz
      /* hole akt. Best.Nr, schreiben */
      M_BestNr:=hole("BestNr",WRITE,.t.)
      /* checken ob nicht schon vorhanden */
      select BesAus
      seek M_BestNr
      if ! eof()
        Error("Bestell"+NUMMER_DOPPELT)
      endif
      do while ! eof()
        Message("Suche n�chste freie Bestell-Nummer.  Bitte warten...")
        M_BestNr:=hole("BestNr",WRITE,.t.)
        seek M_BestNr
      enddo
      go M->MerkNr
      rec_lock(0)
      replace BESAUS->BestNr with M_BestNr

      // pr�fe Sammelbest.Posten
      if select("SammelBest") > 0
        select SammelBest
        dbseek( TEMP_NUMMER )
        do while ! SAMMELBEST->(eof())
          rec_lock(0)
          replace SAMMELBEST->BestNr with M_BestNr
          dbcommit()
          dbunlock()
          dbseek( TEMP_NUMMER )
        enddo
        select BesAus
      endif

    endif

    if ABBRUCH
      if changed
        Best_Drucken(Ausgabe)
      endif
    else
      Message("Bestellung: @"+BESAUS->BestNr+"@ wird gedruckt.  Bitte warten...")
      Best_Drucken(Ausgabe)
    endif

    /*** Posten r�ckschreiben ***/
    BESPOST->(OrdSetFocus(4)) // BesPostNr
    select Bestell

    set filter to // mit gel�schten!
    go top
    do while ! BESTELL->(eof())

      // suche zugeh. Posten in BestPost
      BESPOST->(dbseek(BESTELL->BesPostNr))

      // Posten gel�scht?
      diff:=0
      if ! BESTELL->geloescht $ "N "
        if BESPOST->(eof())
          // neuer Satz gel�scht -> NOP
        else
          // Satz in Bespost ebenfalls l�schen
          select BesPost
          diff:=BESPOST->Menge * (-1)
          rec_lock(0)
          delete
          dbcommit()
          dbunlock()
          select Bestell
        endif

      else // nicht gel�scht

        // nicht gefunden -> neuer Satz -> neu anlegen
        select BesPost
        if ! BESPOST->(eof())
          // Info: alter Datensatz kann nicht wiederverwendet werden,
          // da sonst die Reihenfolge bei nachtr�glich eingef�gten nicht mehr stimmt.
          // Alternativ m�sste man eine PosNr einf�hren mit entspr. Index.
          rec_lock(0)
          diff:=BESPOST->Menge * (-1)
          delete
          dbcommit()
          dbunlock()
        endif

        add_rec(0)
        overwrite("BESTELL")
        replace BESPOST->BestNr with BESAUS->Bestnr
        replace BESPOST->LIEFNR with BESAUS->LIEFNR
        replace BESPOST->AufDat with BESAUS->AufDat
        if empty(BESPOST->BesPostNr) // Info: alte BesPostNr bleibt erhalten!
          replace BESPOST->BesPostNr with val(Hole( "BesPostNr" , WRITE , .t. ))
        endif
        diff += BESPOST->Menge
      endif

      BestBestand(BEST_EXT,BESTELL->ArtNr)

      // 20190314: Ausnahme Dienstleistung, Untermaterial gleich abbuchen
      if getArtikelArt() $"D" .and. diff <> 0
        material:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getMaterial( .t. ) // nur Artikel
        for each mat in Material
          if mat:Text == "A"
            SELECT Artikel
            SEEK mat:ArtNr
            if .not. eof()
              REC_LOCK(0)
              aendArtBest( mat:Menge * diff * (-1) , WARAUS_DL_BESTELLUNG + BESPOST->BestNr)
              dbcommit()
              UNLOCK
            endif
          endif
        next
      endif

      select Bestell
      BESTELL->(dbskip(1))

    enddo
    BESPOST->(OrdSetFocus(1)) // BestNr


    dbcommitall()
    unlock all

    // falls nur ein best. Datensatz bearbeitet werden sollte -> danach raus
    if mBesPostNr <> nil
      Ende:=.t.
    endif

    if mArtnr <> NIL // l�sche Artikel-Vorschlag aus launchNeueBestellung?
      mArtnr:=nil
    endif

    if changed

      /*** bei Veredelung Folge_bestellung automatisch anlegen ***/
      if veredelung .and. istNeu
        // 2. Veredelungs-Bestellung automatisch anlegen
        verpackungen:=HB_ATokens(strtran(LIEFERAN->Verpackung," ","") ,",")

        select Bestell
        zap
        BESPOST->(dbseek(BESAUS->BestNr))
        sucheMatKz:=getProperty( "Miki.bestell.veredelung.matkz" )
        LIEFERAN->(dbseek( getProperty( "Miki.bestell.veredelung.an" )))

        // pr�fe ob relevante Artikel vorkommen vorab
        do while ! BESPOST->(eof()) .and. BESPOST->BestNr == BESAUS->BestNr
          ARTIKEL->(dbseek( BESPOST->ArtNr ))
          if ARTIKEL->MatKz == sucheMatKz
            parents:=Stueckliste():new( ARTIKEL->ArtNr, ARTIKEL->Art ):getParents( "M" )
            select Bestell
            for each mat in Parents
              neueBestellung:=.t.
            next
          endif
          select BesPost
          skip
        enddo

        // neue Bestellung / Veredelung erzeugen?
        if neueBestellung
	  /* hole akt. Best.Nr, schreiben */
          M_BestNr:=hole("BestNr",WRITE,.t.)
	  /* checken ob nicht schon vorhanden */
          select BesAus
          seek M_BestNr
          if ! eof()
            Error("Bestell"+NUMMER_DOPPELT)
          endif
          do while ! eof()
            Message("Suche n�chste freie Bestell-Nummer.  Bitte warten...")
            M_BestNr:=hole("BestNr",WRITE,.t.)
            seek M_BestNr
          enddo
          go M->MerkNr
          rec_lock(0)
          replace BESAUS->RefBestNr with M_BestNr

          temp:=getCurrentValues()
          add_rec(0)
          setCurrentValues(temp)
          replace BESAUS->BestNr with M_BestNr
          replace BESAUS->RefBestNr with temp[ fieldpos( "BestNr" ) ]
          // Adressen anpassen
          replace BESAUS->LiefNr WITH LIEFERAN->LiefNr
          REPLACE BESAUS->KurzName WITH LIEFERAN->KurzName
          REPLACE BESAUS->Name WITH LIEFERAN->Name1
          REPLACE BESAUS->Partner WITH LIEFERAN->Name2
          REPLACE BESAUS->Strasse WITH LIEFERAN->Strasse
          REPLACE BESAUS->Zusatz WITH LIEFERAN->Zusatz
          REPLACE BESAUS->Plz WITH LIEFERAN->PLZ
          REPLACE BESAUS->Land WITH LIEFERAN->Land
          REPLACE BESAUS->Ort WITH LIEFERAN->Ort
          REPLACE BESAUS->KundNr WITH LIEFERAN->LiefNr // obsolete???

          select Lieferan
          seek MIKI_NR
          REPLACE BESAUS->V_LiefNr WITH LIEFERAN->LiefNr
          REPLACE BESAUS->V_Name WITH LIEFERAN->Name1
          REPLACE BESAUS->V_Partner WITH LIEFERAN->Name2
          REPLACE BESAUS->V_Strasse WITH LIEFERAN->Strasse
          REPLACE BESAUS->V_Zusatz WITH LIEFERAN->Zusatz
          REPLACE BESAUS->V_Plz WITH LIEFERAN->PLZ
          REPLACE BESAUS->V_Land WITH LIEFERAN->Land
          REPLACE BESAUS->V_Ort WITH LIEFERAN->Ort

          // jetzt Posten erzeugen, muss nach EWrstellung von BESAUS gemacht werden
          // da in copyEKPreis vom Lieferanten/Besaus abh�ngt
          BESPOST->(dbseek(BESAUS->RefBestNr))
          do while ! BESPOST->(eof()) .and. BESPOST->BestNr == BESAUS->RefBestNr
            ARTIKEL->(dbseek( BESPOST->ArtNr ))
            if ARTIKEL->MatKz == sucheMatKz
              parents:=Stueckliste():new( ARTIKEL->ArtNr, ARTIKEL->Art ):getParents( "M" )
              select Bestell
              for each mat in Parents
                ARTIKEL->(dbseek( mat:ArtNr ))
                add_rec(0)
                copyArtikelDaten( .f. ) // mit Preis
                replace BESTELL->ArtNr with mat:ArtNr
                replace BESTELL->Menge with BESPOST->Menge * mat:Menge
                replace BESTELL->Kw with BESPOST->KW
                replace BESTELL->Kw_Text with BESPOST->KW_Text
                replace BESTELL->BesPostNr with 0
              next
            else // Verpackung?
              if aContains( verpackungen , alltrim(BESPOST->ArtNr) ) .and. BESPOST->Menge > 0
                select Bestell
                add_rec(0)
                overwrite("BesPost")
              endif

            endif
            select BesPost
            skip
          enddo

          Message("Bestellung: @"+BESAUS->BestNr+"@ wird gedruckt.  Bitte warten...")
          Best_Drucken(Ausgabe)

          // Posten r�ckschreiben
          select Bestell
          go top
          do while ! BESTELL->(eof())
            select BesPost
            add_rec(0)
            overwrite("BESTELL")
            replace BESPOST->BestNr with BESAUS->Bestnr
            replace BESPOST->LIEFNR with BESAUS->LIEFNR
            replace BESPOST->AufDat with BESAUS->AufDat
            replace BESPOST->BesPostNr with val(Hole( "BesPostNr" , WRITE , .t. ))
            select Bestell
            BestBestand(BEST_EXT,BESTELL->ArtNr)
            skip
          enddo
        endif
      else // ! (veredelung .and. istNeu)
        if ! empty(BESAUS->RefBestNr)
          Error("Hinweis: Veredelung - bitte auch Bestellung: " + BESAUS->RefBestNr + " pr�fen.")
        endif
      endif

      AufBestand()
      changed:=.f.
    endif

  enddo

  /* neuen Datensatz l�schen ? */
  select BesAus
  seek TEMP_NUMMER
  do while ! eof() .and. BESAUS->BestNr==TEMP_NUMMER
    rec_lock(0)
    delete
    skip
  enddo

  Umgebung(LOAD)

RETURN
/* EOP Best_erfassen */


/* Eingabe des Bestellungskopfes
  *
  * Parameters: 0 == editierbar
  *             1 == editierbar ausser BestNr
  *             2 == nur anzeigen
  * R�ckgabe  : letzter Tastendruck
  */
static FUNCTION Best_Kopf(edit)
LOCAL GetList:={}
LOCAL M_BestNr
LOCAL ob:=1
LOCAL oldF11:=SetKey( K_F11 , nil)

  if edit==0
    M_BestNr:=hole("BestNr",LOAD) // hole neuste Best.Nr, nur lesen
    @ ob+1,14 get M_BestNr picture '@K #####' valid { |oGet| shift(oGet) .and. BestNr_nach(oGet) };
      when ( Message('Bestellnummer eingeben.         @F10@=Artikel   @F12@=Hilfe') )
    @ ob+1,20 say "(F10)" color "R/"+getBackColor()
    setCargo(ATail(GetList),CARGO_UPDATE_IGNORE,.t.) // �nderungen an ABNr setzen nicht slUpdated
  else
    @ ob+1,14 say BESAUS->BestNr
  endif
  set key K_F10 to Best_Art_Karte()

  @ ob+2,14 get BESAUS->LiefNr PICTURE "@K" ;
    valid { |oGet| check(oGet,"Lieferan",.f.) .and. LiefNr_nach(oGet) } ;
    when Message('Lieferanten-Nummer eingeben.     @F10@=Bestellkarte      @F12@=Hilfe')
  @ ob+3,14 GET BESAUS->AufDat when Message('Bestelldatum eingeben.       @*@=Heute @+@/@-@')

  @ ob+5,14 get BESAUS->VersNr valid { |oGet| check(oGet,"VersArt",.t.) .and. Best_Kopf_Disp()};
    when Message('Versandart eingeben.             @F12@=Hilfe')
  @ ob+6,14 GET BESAUS->Ansprech when Message('Ansprechpartner eingeben.')
  @ ob+7,14 GET BESAUS->BestKonto when Message('Anfrage-Text eingeben.')
  @ ob+8,14 GET BESAUS->BestDat;
    when Message('Datum Bestellanfrage eingeben.       @*@=Heute @+@/@-@')

  @ ob+4,38 get BESAUS->V_LiefNr PICTURE "@K";
    valid;
    { |oGet| check(oGet,"Lieferan",.t.) .and. V_liefNr_nach(oGet) } when Message("Lieferantennr. "+;
    "Versand eingeben.          @F12@=Hilfe")

  // Sprache jetzt immer
  @ ob+8,39 get BESAUS->Sprache picture "!" valid { |oGet| nachSprache(oGet) }

  @ ob+11,40 get BESAUS->So_Rabatt when Message("Sonder-Rabatt eingeben. ")
  @ ob+12,40 get BESAUS->ZKNr valid { |oGet| check(oGet,"ZahlKond",.t.) };
    when Message("Zahlungskondition eingeben.   @F12@=Hilfe")
  @ ob+11,60 get BESAUS->TextKz_Nr valid { |oGet| check(oGet,"Text_Kz",.t.) };
    when Message("Werbe - Text KZ eingeben.     @F12@=Hilfe")

  if ! edit==2
    read
  endif
  set key K_F10 to
  SetKey( K_F5 , oldF11)


RETURN( empty(BESAUS->LiefNr) )
/* EOF BestKopf */



  /* Funktionen f�r Kopfeingabe   *************************
  */
/* nach Best.Nr */
STATIC FUNCTION BestNr_nach(oGet)
LOCAL M_BestNr
  // STATIC MerkNr, removed 20110719, seems obsolete

  /* Eingabe korrekt ? */
  if ! lastkey()==K_RETURN
    RETURN(.f.)
  endif
  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
  endif
  if len(alltrim(oGet:Buffer)) < MINDEST_LAENGE
    Error(ACHTUNG+" Hier keine innerbetr. Bestellungen.|"+;
      "Bitte Benutzen sie Men�-Pkt. 01.01. f�r �nderungen.")
    RETURN(.f.)
  endif

  select BesAus

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
        if ! add_rec(5) // Satz bleibt gelockt
          Error("BESAUS.dbf"+DATEI_EXCL)
          RETURN(.f.)
        endif
        M->MerkNr:=recno()
        REPLACE BESAUS->BestNr WITH TEMP_NUMMER
        REPLACE BESAUS->AufDat WITH getUser():date
        REPLACE BESAUS->BestDat WITH getUser():date
        REPLACE BESAUS->MWST_KZ WITH "1"
        MWST_KZ->(dbseek("1"))
        REPLACE BESAUS->MWST WITH MWST_KZ->MWST
        dbcommit()
      else
        M_BestNr:=hole("BestNr",LOAD) // hole akt. Auft.Nr, lesen
        Error("Bestellung: "+oget:buffer+NICHT_VORHANDEN)
        oget:varput(M_BestNr)
        oGet:updateBuffer()
        oGet:killfocus()
        oGet:setfocus()
        M->MerkNr:=0
        RETURN(.f.)
      endif
    else
      // pr�fe ob erledigt
      if BESAUS->erledigt == "J"
        oGet:killfocus()
        Best_Kopf_Disp()
        Best_Kopf(2) // display only
        Message("Bitte @Taste@ dr�cken","@")
        keyboard chr(K_PGDN) // we bail out
      else
        if ! Rec_Lock(5)
          Error(SATZ_EXCL)
          RETURN(.f.)
        endif
      endif
      M->MerkNr:=recno()
    endif

  endif

  Best_Kopf_Disp()
  setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  // sicher(WRITE) // merke akt. Werte

RETURN(.t.)
/* EOF BestNr_nach */


  /* nach LieferantenNummer
  *  steht auf richtigem Satz in Lieferan, da check(oGet) !
  */
FUNCTION LiefNr_nach(oGet)
LOCAL Merk
  if oGet:changed
    REPLACE BESAUS->KurzName WITH LIEFERAN->KurzName
    REPLACE BESAUS->Name WITH LIEFERAN->Name1
    REPLACE BESAUS->Partner WITH LIEFERAN->Name2
    REPLACE BESAUS->Strasse WITH LIEFERAN->Strasse
    REPLACE BESAUS->Zusatz WITH LIEFERAN->Zusatz
    REPLACE BESAUS->Plz WITH LIEFERAN->PLZ
    REPLACE BESAUS->Land WITH LIEFERAN->Land
    REPLACE BESAUS->Ort WITH LIEFERAN->Ort
    REPLACE BESAUS->Sprache WITH LIEFERAN->Sprache
    REPLACE BESAUS->KundNr WITH LIEFERAN->LiefNr // obsolete???

    REPLACE BESAUS->Ansprech WITH LIEFERAN->Ansprech

    IF EMPTY(BESAUS->V_LiefNr)
      select Lieferan
      merk=recno()
      seek MIKI_NR
      REPLACE BESAUS->V_LiefNr WITH LIEFERAN->LiefNr
      REPLACE BESAUS->V_Name WITH LIEFERAN->Name1
      REPLACE BESAUS->V_Partner WITH LIEFERAN->Name2
      REPLACE BESAUS->V_Strasse WITH LIEFERAN->Strasse
      REPLACE BESAUS->V_Zusatz WITH LIEFERAN->Zusatz
      REPLACE BESAUS->V_Plz WITH LIEFERAN->PLZ
      REPLACE BESAUS->V_Land WITH LIEFERAN->Land
      REPLACE BESAUS->V_Ort WITH LIEFERAN->Ort
      go merk
    Endif
    REPLACE BESAUS->So_Rabatt WITH LIEFERAN->So_Rabatt
    REPLACE BESAUS->ZKNr WITH LIEFERAN->ZKNr
    REPLACE BESAUS->VersNr WITH LIEFERAN->VersNr
    REPLACE BESAUS->MwSt_Kz WITH LIEFERAN->MwSt_Kz
    MWST_KZ->(dbseek(LIEFERAN->Mwst_Kz))
    REPLACE BESAUS->MwSt WITH MWST_KZ->MwSt

    Best_Kopf_Disp()
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif

RETURN(.t.)
/* EOF LiefNr_nach */


  /* nach Versand-LieferantenNummer
  *  steht auf richtigem Satz in Lieferan, da check(oGet) !
  */
FUNCTION V_LiefNr_nach(oGet)
  if oGet:changed
    REPLACE BESAUS->V_Name WITH LIEFERAN->Name1
    REPLACE BESAUS->V_Partner WITH LIEFERAN->Name2
    REPLACE BESAUS->V_Strasse WITH LIEFERAN->Strasse
    REPLACE BESAUS->V_Zusatz WITH LIEFERAN->Zusatz
    REPLACE BESAUS->V_Plz WITH LIEFERAN->PLZ
    REPLACE BESAUS->V_Land WITH LIEFERAN->Land
    REPLACE BESAUS->V_Ort WITH LIEFERAN->Ort
    Best_Kopf_Disp()
  endif

RETURN(.t.)
/* EOF LiefNr_nach */


  /* FUNCTION Best_Kopf_Disp
  *
  * gibt den Bestellkopf auf den BS aus
  */
FUNCTION Best_Kopf_Disp(nurPreisanfrage)
LOCAL ob:=1
  _thread static onlyPreisAnfrage

  if nurPreisanfrage<>NIL
    onlyPreisAnfrage:=nurPreisanfrage
  else
    default onlyPreisAnfrage:=.f.
  endif

  // ** Kopf-Display
  if ! onlyPreisAnfrage
    @ ob+1,1 say 'Bestell Nr.:'
  endif
  @ ob+2,1 say 'Lief.Nr....:'
  @ ob+3,1 say '        Dat:'

  @ ob+5,1 say "Versand-Art:"
  @ ob+5,18 say left(VERSART->Text,11)
  @ ob+6,1 say "Ansprechpa.:"
  @ ob+7,1 say "Anfrage....:"
  @ ob+8,1 say "Anfrage-Dat:"


  @ ob+1,30 say "Rechn.-Anschr..:"
  @ ob+3,30 say "Versand-Anschr.:"
  @ ob+5,30 say space(30)
  @ ob+4,30 say 'Li.Nr.:'
  @ ob+1,47 say BESAUS->Name
  @ ob+2,47 say BESAUS->Ort
  @ ob+3,47 say BESAUS->V_Name
  @ ob+4,47 say BESAUS->V_Strasse
  @ ob+5,47 say BESAUS->V_Land
  @ ob+5,51 say BESAUS->V_PLZ
  @ ob+6,47 say BESAUS->V_Ort

  @ ob+8,30 say 'Sprache:'
  if ! empty(BESAUS->Sprache) .and. BESAUS->Sprache<>DEUTSCH
    @ ob+8,42 say "Englisch"
  else
    @ ob+8,42 say "Deutsch "
  endif

  @ ob+10,30 to ob+10,78

  @ ob+11,30 say "Sond.Rab.:"
  @ ob+12,30 say "Zahl.Kond:"

  @ ob+11,50 say "Text-KZ:"
  @ ob+12,50 say "MWST...:"
  @ ob+13,2 to ob+13,78

  @ ob+12,60 say alltrim(str(BESAUS->MWSt,5,2)+"%")+" "

  // @ ob+14,1 say "LieferTermine:"
  // @ ob+16,1 say "KW:"
  // @ ob+16,12 say "Menge:"
  // * @ ob+16,25 say "ME:"
  // @ ob+16,36 say "KW:"
  // @ ob+16,46 say "Menge:"
  // * @ ob+16,60 say "ME:"

RETURN(.t.)
/* EOP Best_Kopf_Disp */


/** nach EIngabe der Sprache */
static function nachSprache( oGet )

  if ! oGet:buffer $ DEUTSCH+ENGLISCH
    return .f.
  endif

  selLandBySprache( oGet:buffer )
  Best_Kopf_Disp()

return .t.
/** eof */

  /* 
  * Eingabe des Best.Bauches, Editor-definitionen
  * R�ckgabe:     Taste mit der Editor verlasen wurde
  */


STATIC FUNCTION Best_Bauch(nurPreisanfrage , viewOnly , autoLaunch, starteBeiRecno )
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  default viewOnly:=.f.
  default autoLaunch:=.f.

  select Bestell

  set key K_F10 to Art_F10Karte()
  mySetKey( K_F11 , {|p1,oGet| sammelBestellung(nurPreisanfrage,oGet,p1) })
  set key K_F5 to meAuswahl()
  // SetKey( K_F5, {|| } )

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->BESTELL->LiefNr:=BESAUS->LiefNr }
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Best_Text()}
  aKopf[EDIT_FKT_IMMER]:={ || checke_Best_Nach(aKopf,aFelder,nurPreisanfrage,autoLaunch) }
  aKopf[EDIT_KOPF_FKT]:={ || Best_Kopf_Disp() .and. Best_Kopf(1) } // wird im Doppelmodus bei Eingabe
  aKopf[EDIT_DELETE_FKT]:={ || _FIELD->BESTELL->Geloescht:="J",;
    dispEditorSumme("BESAUS","BESTELL->Menge",49) }

  aKopf[EDIT_EXTRA_FKT]:={ { "B" , " @B@est.karte" ,;
    { || Art_BestKarte(getUser():mayEditData) } } }
  aadd(aKopf[EDIT_EXTRA_FKT],{ "hH" , " @H@istorie", { || liefBestHist( BESTELL->LiefNr,ARTIKEL->ArtNr ) }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ "L","", { || KonsistenzLoesch() } } )
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F4),"", { || NegVerfueg(getArtikelArt(),ARTIKEL->ArtNr)};
    })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F9)," @F9@=Best.", { || LiefBestellListe() } } )
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F11)," @F11@=Sammelbest.", { || sammelBestellung(;
    nurPreisanfrage) } } )
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F9),"", { || AufBestArtikel(BESTELL->ArtNr)} })

  aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("BESAUS","BESTELL->Menge",49) }
  aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
  aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen
  aKopf[EDIT_ZEIGE_ANZAHL];
    := { || BESTELL->geloescht$"N " .and. len(alltrim(BESTELL->ArtNr)) > FRACHT_LAENGE } // z�hle alle Artikel

  if viewOnly
    aKopf[EDIT_GESPERRT]:="KN�AEL"
    aadd(aKopf[EDIT_EXTRA_FKT],{ "A�","", { || bestellEdit() } } )
  endif

  if valtype(starteBeiRecno)=="N"
    aKopf[EDIT_START_REC]:=starteBeiRecno
    HB_KeyPut(EDIT_LINE_EDIT) // default edit
  endif

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER];
    :={;
    |oGet|;
    ( trim(oGet:Buffer)$"*" .or. check(oGet,"Artikel",.f.)) .and. ArtnrNach(oGet,nurPreisanfrage)}
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.   @F11@=Sammelbestellung   @F12@=Hilfe    @ESC@=Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || trim(BESTELL->ArtNr) $ "*" }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_MESSAGE]:="Text eingeben         @F10@=Bestellkarte   @F11@=Sammelbest."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm2"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MESSAGE]:="Text eingeben         @F10@=Bestellkarte   @F11@=Sammelbest."
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Mengeinheit
  aSpalte[EDIT_NAME]:="ME"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Mengeinheit
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="  "
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MESSAGE]:={ || "Menge in "+EINHEIT->Text+" eingeben   @F5@=Eingabe-Einheit �ndern  "+;
    " @F10@=Bestellkarte"}
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME") }
  aSpalte[EDIT_BEFORE]:={ || meEingabeCheck("ME") }
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oGet| MengeNach(oGet,"ME",nurPreisanfrage)}

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis
  aSpalte[EDIT_TITEL]:="Preis"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_NAME]:="Preis"
  aSpalte[EDIT_MESSAGE]:={;
    || " Preis "+if(BESTELL->PE=="H","(%) ","")+" pro "+EINHEIT->Text+" in Euro eingeben.  "+;
    "@F5@=Eingabe-Einheit �ndern   @F10@=Bestellkarte" }
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME") }
  aSpalte[EDIT_BEFORE]:={ || meEingabeCheck("ME") }
  aSpalte[EDIT_AFTER]:={ |oGet| preisNach(oGet)}
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // 2. Mengeneinheit Wert
  aSpalte[EDIT_NAME]:="ME2"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_X]:=-16
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren aSpalte[EDIT_POS_X]:=-10


  // Mengeinheit Text
  aSpalte[EDIT_NAME]:="getBestMe2Text()"
  aSpalte[EDIT_POS_X]:=-14
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // 2. Menge
  aSpalte[EDIT_NAME]:="Menge2"
  aSpalte[EDIT_MESSAGE]:={ || "Menge in "+getBestMe2Text()+" eingeben.   @F5@=Eingabe-Einheit "+;
    "�ndern   @F10@=Bestellkarte"}
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MASKE]:="@Z"
  aSpalte[EDIT_POS_X]:=-10
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME2") }
  aSpalte[EDIT_BEFORE]:={ || meEingabeCheck("ME2") }
  aSpalte[EDIT_AFTER]:={ |oGet| MengeNach(oGet,"ME2",nurPreisanfrage)}

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis
  aSpalte[EDIT_NAME]:="Preis2"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:={ || "Preis pro "+getBestMe2Text()+" in @Euro@ eingeben.  "+;
    "@F5@=Eingabe-Einheit �ndern   @F10@=Bestellkarte"}
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME2") }
  aSpalte[EDIT_BEFORE]:={ || meEingabeCheck("ME2") }
  aSpalte[EDIT_AFTER]:={ |oGet| preisNach(oGet)}
  aSpalte[EDIT_MASKE]:="@Z"
  aSpalte[EDIT_POS_X]:=0
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Gelief
  aSpalte[EDIT_NAME]:="if(BESTELL->BesPostNr==0,'',"+;
    "'Gel:'+str(GeliefGes,9,2)+' ' + EINHEIT->Text+' Rest:'+str(max(Menge-GeliefGes,0),9,2)+ ' ' + "+;
    "EINHEIT->Text)"
  aSpalte[EDIT_TITEL]:=" Gel"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_X]:=-33
  aSpalte[EDIT_POS_Y]:=2 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preiseinheit
  aSpalte[EDIT_NAME]:="'PE: '+ BESTELL->PE"
  aSpalte[EDIT_POS_X]:=4
  aSpalte[EDIT_POS_Y]:=2 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Rabatt
  aSpalte[EDIT_NAME]:="Rabatt"
  aSpalte[EDIT_TITEL]:="Rab %"
  // aSpalte[EDIT_POS_X]:=1 // um 1 nach rechts verschoben
  aSpalte[EDIT_MESSAGE]:="Rabatt eingeben."
  aSpalte[EDIT_AFTER]:=IS_POSITIVE
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis abzgl. Rabatt
  aSpalte[EDIT_NAME]:="getNettoEndPreis(1)"
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME") }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis abzgl. Rabatt
  aSpalte[EDIT_NAME]:="getNettoEndPreis(2)"
  aSpalte[EDIT_FARBE]:={ || meFarbe("ME2") }
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche Lieferung
  aSpalte[EDIT_NAME]:="'KW:'"
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_POS_Y]:=2 // 3. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  aSpalte[EDIT_NAME]:="Kw"
  aSpalte[EDIT_MASKE]:="!!/99"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_POS_Y]:=2 // 3. Zeile
  aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben.           @*@=Text"
  aSpalte[EDIT_AFTER]:={ |oGet| Best_kw_nach(oGet,nurPreisanfrage) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  aSpalte[EDIT_NAME]:="KW_Text"
  aSpalte[EDIT_TITEL]:="LieferText"
  aSpalte[EDIT_MESSAGE]:="Liefertext eingeben."
  aSpalte[EDIT_BEFORE]:={ || left(BESTELL->kw,1)=="*" }
  aSpalte[EDIT_AFTER]:={ || ! empty(BESTELL->kw_text) .or. lastkey()==K_UP}
  aSpalte[EDIT_POS_X]:=-45 // nach links verschoben
  aSpalte[EDIT_POS_Y]:=3 // 4. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Lagerbestand
  aSpalte[EDIT_TITEL]:="  Lg.Best."
  aSpalte[EDIT_NAME]:="getArtikelLageBest()"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

  Edit(aFelder,aKopf)

  SetKey( K_F5 , NIL)
  set key K_F11 to
  set key K_F10 to

RETURN( aKopf[EDIT_CHANGED] )
/* EOF Best_Bauch */

/** vor Eingabe der Menge wird der User gefragt in welcher Einheit er erfassen will */
static function meEingabeCheck( feldName )
LOCAL Auswahl:="" , value

  do case
  case feldName == "ME"
    if empty(BESTELL->ME2) // keine 2. ME hinterlegt
      return .t.
    endif

    // Benutzer fragen, falls noch nicht erfasst
    if empty( BESTELL->EingabeME )
      meAuswahl()
    endif

  case feldName == "ME2"
    if empty(BESTELL->ME2) // keine 2. ME hinterlegt
      return .f.
    endif

  endcase

  // current value
  value:=fieldget(fieldpos( feldName ))

return value == BESTELL->EingabeME
/** eof */

/** graut die nicht Eingabe-Einheit aus */
static function meFarbe( feldName )
  if ! empty(BESTELL->ME2)
    do case
    case feldName == "ME"
      if BESTELL->ME <> BESTELL->EingabeME
        return "N+/"+getBackColor() // grey / gray / grau
      endif

    case feldName == "ME2"
      if BESTELL->ME2 <> BESTELL->EingabeME
        return "N+/"+getBackColor() // grey / gray / grau
      endif

    endcase
  endif

return nil // default farbe
/** eof */

/** Auswahl der gew�nschten Eingabe-ME */
static function meAuswahl(p1,p2,p3)
LOCAL Auswahl:=BESTELL->EingabeME
LOCAL erst:=.t.
LOCAL oldF5:=SetKey( K_F5 , nil)

  ignore p1,p2

  do while ! auswahl $ BESTELL->ME + BESTELL->ME2 .or. erst
    erst:=.f.
    auswahl:=Message("Mengeneingabe in @"+BESTELL->ME+"@ = " + trim(EINHEIT->Text) + " oder @"+;
      BESTELL->ME2+"@ = " + getBestMe2Text()+"?", BESTELL->ME + BESTELL->ME2 , ;
      BESTELL->EingabeME)
  enddo

  if Auswahl <> BESTELL->EingabeME
    replace BESTELL->EingabeME with Auswahl

    if p3 <> nil // Aufruf �ber hotkey also "switch" der ME
      if Auswahl == BESTELL->ME
        if "MENGE" $ p3
          keyboard chr(K_UP) + chr(K_UP)
        else
          keyboard chr(K_UP)
        endif
      else
        keyboard chr(K_DOWN)
      endif
    endif

    // not yet impleented in lineedit nur in after_edit_fkt :(
    // if Auswahl == BESTELL->ME
    // x:=getColPosByName(aFelder,"Menge")
    // else
    // x:=getColPosByName(aFelder,"Menge2")
    // endif
    // if x==0
    // troubleEmail("Menge nicht gefunden.")
    // else
    // aKopf[EDIT_GET_OFFSET]:=x
    // // leave current field
    // keyboard chr(K_ESC) + "�"
    // endif
  endif
  SetKey( K_F5 , oldF5)

return .t.
/** eof */


  /* Function MengeNach()
  *
  * wird nach Eingabe der Menge ausgef�hrt
  */
static FUNCTION MengeNach(oGet , meFeld , nurPreisanfrage )
LOCAL me:=fieldget(fieldpos( meFeld ))
LOCAL aktRec

  default nurPreisanfrage:=.f.

  // NACHKOMMA Stellen erlaubt?
  EINHEIT->(dbseek( me ))
  if val(oGet:buffer) - int(val(oGet:buffer)) > 0 .and. EINHEIT->Nachkomma == 0
    aktRec:=EINHEIT->(recno())
    EINHEIT->(dbseek( me ))
    Error(ACHTUNG+" Nachkommastellen bei ME: "+EINHEIT->Text+" nicht zugelassen.",.t.)
    EINHEIT->(dbgoto(aktRec))
    return .f.
  endif

  // jeweils die 2. Menge umrechnen
  berechneMenge( oGet:name , val(oGet:buffer) )

  if ! nurPreisanfrage

    /* MindestBestellMenge �berpr�fen */
    if oGet:changed .and. len(alltrim(BESTELL->ArtNr)) >3 .or.;
      (len(alltrim(BESTELL->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
      (len(alltrim(BESTELL->ArtNr)) == 3 .and. VERSART->Fracht == "J")

      if oGet:VarGet() < ARTIKEL->MinOrderI
        Error(ACHTUNG+" Artikel: "+ARTIKEL->ArtNr+" Mind.Bestellung: "+str(ARTIKEL->MinOrderI,9,2))
      endif

      /* falls Preis anhand Bestellkarte */
      if BESTELL->TempKz == "K"
        if ! copyEKMengeBestKart(oGet,BESTELL->Menge)
          select Bestell
          return .f.
        endif
      endif

    endif
  endif

  // pr�fe Menge > 0 , FIXME: aKopf[EDIT_FKT_IMMER] wird mit RETURN durchlaufen nicht ausgef�hrt
  // if len(alltrim(BESTELL->ArtNr)) >3 .and. ! ABBRUCH
  // if (oget:name == "Menge" .and. BESTELL->Menge <= 0 .and. empty(BESTELL->Me2) ) .or.;
  // (oget:name == "Menge2" .and. BESTELL->Menge2 <= 0 )
  // Error(ACHTUNG+" Menge > 0 muss eingegeben werdern.",.t.)
  // select Bestell
  // return .f.
  // endif
  // endif

  select Bestell

RETURN(.t.)
/* EOF MengeNach */


/** passt die 2. Menge je nach ME an */
static procedure berechneMenge( feld , menge )
  if ARTIKEL->ME_Faktor > 0
    if BESTELL->ME == ARTIKEL->ME
      if feld == "Menge"
        EINHEIT->(dbseek( ARTIKEL->ME2 )) // Zieleinheit der nicht eingegeben Menge
        Replace BESTELL->Menge2 WITH round( menge * ARTIKEL->ME_Faktor , EINHEIT->Nachkomma)
      else // Menge2
        EINHEIT->(dbseek( ARTIKEL->ME )) // Zieleinheit der nicht eingegeben Menge
        Replace BESTELL->Menge WITH round( menge / ARTIKEL->ME_Faktor , EINHEIT->Nachkomma)
      endif
    else // BESTELL->ME == ARTIKEL->ME2
      if feld == "Menge"
        EINHEIT->(dbseek( ARTIKEL->ME )) // Zieleinheit der nicht eingegeben Menge
        Replace BESTELL->Menge2 WITH round( menge / ARTIKEL->ME_Faktor , EINHEIT->Nachkomma)
      else // Menge2
        EINHEIT->(dbseek( ARTIKEL->ME2 )) // Zieleinheit der nicht eingegeben Menge
        Replace BESTELL->Menge WITH round( menge * ARTIKEL->ME_Faktor , EINHEIT->Nachkomma)
      endif
    endif
  endif
return
/** eop */

  /*
  *
  * wird nach Eingabe des Preises ausgef�hrt
  */
static FUNCTION preisNach(oGet)
LOCAL s01

  // zur�ck ist erlaubt
  if lastkey() == K_UP
    return .t.
  endif

  // Hinweis, falls bei Fracht/Verpackung der Preis ge�ndert wurde,
  // obwohl dieser normalerweise nicht berechnet wird
  if oGet:changed .and. val(oGet:buffer) <> 0
    if (len(alltrim(BESTELL->ArtNr)) == 2 .and. VERSART->Verpack =="N" )
      s01:=savescreen()
      Error(ACHTUNG+"Verpackung wird bei diesem Lieferanten normalerweise nicht berechnet.",.f.)
      if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J" .or. ABBRUCH
        oGet:varput(0)
        oGet:updateBuffer()
      endif
      restscreen(,,,,s01)
    elseif (len(alltrim(BESTELL->ArtNr)) == 3 .and. VERSART->Fracht == "N") .or. ABBRUCH
      s01:=savescreen()
      Error(ACHTUNG+"Fracht wird bei diesem Lieferanten normalerweise nicht berechnet.",.f.)
      if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J"
        oGet:varput(0)
        oGet:updateBuffer()
      endif
      restscreen(,,,,s01)
    endif

    // 2. Preis anpassen
    if oGet:name == "Preis"
      if ! empty(BESTELL->ME2) .and. ARTIKEL->ME_Faktor <> 0
        if BESTELL->ME == ARTIKEL->ME // Bestellkarte wird immer in ME des Artikel gef�hrt
          Replace BESTELL->Preis2 WITH round( val(oGet:buffer) / ARTIKEL->ME_Faktor , 2) // umrechnen
        else
          Replace BESTELL->Preis2 WITH round( val(oGet:buffer) * ARTIKEL->ME_Faktor , 2) // umrechnen
        endif
      endif
    else // Preis2
      if BESTELL->ME == ARTIKEL->ME // Bestellkarte wird immer in ME des Artikel gef�hrt
        Replace BESTELL->Preis WITH round( val(oGet:buffer) * ARTIKEL->ME_Faktor , 2) // umrechnen
      else
        Replace BESTELL->Preis WITH round( val(oGet:buffer) / ARTIKEL->ME_Faktor , 2) // umrechnen
      endif
    endif

  endif



RETURN(.t.)
/* EOF preisNach */

  /* Function Best_Text ***************************
  *
  * alternativ Spaltendef. bei Text eingabe *
  * Ersatz-Array
  */
STATIC FUNCTION Best_Text
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| ( trim(oGet:Buffer)$"*" .or. check(oGet,"Artikel",.f.)) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:="@X"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES)) } ),;
    .t. }
  aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }
  aSpalte[EDIT_MESSAGE]:="Text eingeben                 @TAB@=Einschub"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm2"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_POS_Y]:=2
  aSpalte[EDIT_MASKE]:="@X"
  aSpalte[EDIT_BEFORE]:={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES)) } ),;
    .t. }
  aSpalte[EDIT_AFTER]:={ || SetKey( K_TAB , NIL),.t. }
  aSpalte[EDIT_MESSAGE]:="Text eingeben                 @TAB@=Einschub"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren
RETURN(aFelder)
/* EOF Best_Text */



  /* Function Best_kw_nach
  *
  * wird nach Eingabe der Kalenderwoche ausgef�hrt
  * evtl. Eingabe von LieferText
  */
static FUNCTION Best_kw_nach(oGet,nurPreisanfrage,mengenFeld,artnrFeld)
LOCAL GetList:={}
LOCAL Zeile:=row()+1
LOCAL woche:=left(oGet:buffer,2)
LOCAL jahr:=right(oGet:buffer,2)

  // Bei Preisanfrage Eingabe Liefertermin keine Pflicht
  if nurPreisanfrage .and. KWempty(oGet:buffer)
    return .t.
  endif

  default mengenFeld:="BESTELL->Menge"
  default artnrFeld:="BESTELL->ArtNr"

  if left(oGet:buffer,1) $ "*"
    // Message("Liefertext eingeben.")
    // @ Zeile,45 get BESTELL->KW_Text
    // read
    // @ Zeile,45 say BESTELL->KW_Text
  else
    replace BESTELL->Kw_Text with ""
  endif


RETURN(KW_Best_Okay(woche,jahr,nurPreisanfrage, &(mengenFeld) , &(artnrFeld) ))

  /** �berpr�ft ob die KW zw. 01-53 liegt oder aus LiefTerm �bernommen ist,
  leer ist nicht zugelassen
  bei Gutschrift keine Pr�fung und falls Menge==0 oder bei Fracht */
static Function KW_Best_Okay(woche,jahr,nurPreisanfrage,myMenge,myArtNr)

  // bei Preisanfrage keine Pflicht
  if nurPreisanfrage .and. kwempty(woche) .or. lastkey() == K_UP
    return .t.
  endif

  // nicht bei:
  if myMenge = 0 .or. len(alltrim(myArtNr)) <= FRACHT_LAENGE .or. left(BESTELL->Kw,1)=="*"
    return .t.
  endif

  if empty(woche) .and. BESAUS->erledigt<>"J"
    Error(ACHTUNG+" Eingabe des Liefertermins ist Pflicht.",.t.)
    return .f.
  endif

  // Liefertermin aus Datei-Vorgabe?
  LIEFTERM->(dbseek(woche))
  if LIEFTERM->(eof()) .and. BESAUS->erledigt<>"J"
    if (val(woche)<=0 .or. val(woche)>53 .or. val(jahr)<=0)
      Error(ACHTUNG+" Ung�ltiger Liefertermin.",.t.)
      return .f.

      // falls AB von heute -> �berpr�fen Zeitraum KW
    elseif kwKleiner( woche+"/"+jahr , getKW(BESAUS->AufDat) ) == 1
      Error(ACHTUNG+" Liefertermin liegt vor dem Datum der Bestellung: "+dtoc(BESAUS->AufDat)+" - "+;
        getKW(BESAUS->AufDat),.t.)
      return .f.
    endif
  endif
return .t.
/** eof */




  /* Function artnrNach
  *
  * wird nach Eingabe der ArtikelNummer ausgef�hrt
  */
FUNCTION artnrNach(oGet,nurPreisanfrage)
LOCAL aktRec, art

  if getArtikelArt() $ "FM" .and. len(alltrim(ARTIKEL->ArtNr))>FRACHT_LAENGE
    Error(ACHTUNG+oGET:buffer+" ist Fertigungs/Montage-Artikel. ||"+;
      "        Darf nicht extern bestellt werden.",.t.)
    return .f.
  endif

  // pr�fe ob Artikel-Nr ge�ndert, nicht erlaubt bei Dienstleistung
  if ! empty(BESTELL->BesPostNr) .and. oGet:buffer <> oget:original
    aktRec:=ARTIKEL->(recno())
    ARTIKEL->(dbseek(oGet:original))
    art:=getArtikelArt()
    ARTIKEL->(dbgoto(aktRec))
    if getArtikelArt() $"D" .or. art=="D"
      Error(ACHTUNG+"Dienstleistungs-Artikel kann nicht ge�ndert werden.||" +;
        "         Bitte Posten l�schen und neu erfassen.",.t.)
      return .f.
    endif
  endif

  if oGet:changed
    if trim(oGet:Buffer)="*"
      if ! trim(oGet:original)=="*"
        REPLACE BESTELL->komm1 WITH ""
        REPLACE BESTELL->komm2 WITH ""
        REPLACE BESTELL->E_komm1 WITH ""
        REPLACE BESTELL->E_komm2 WITH ""
      endif
    else
      copyArtikelDaten(nurPreisanfrage)
    endif
  endif

  // 27.4.15 kopiere letzte AB-Nr als Best.Kto-Nr.
  // 11.5.15 wieder raus
  // if empty( BESAUS->BESTKONTO )
  // Umgebung( WRITE )
  // abnr:=getLastAufNr(oGet:buffer)
  // if ! empty(abNr) .and. 
  // Message("Bestellkonto auf @"+"AB: " + abNr +"@ setzen? (@J@/@N@)","JN","J")== "J"
  // replace BESAUS->BESTKONTO with "AB: " + abNr
  // endif
  // Umgebung( LOAD )
  // endif


RETURN(.t.)


/** kopiert alle relevanten Daten des Artikel in den aktuellen Best.Posten */
static procedure copyArtikelDaten(nurPreisanfrage)
  REPLACE BESTELL->ArtNr WITH ARTIKEL->ArtNr
  REPLACE BESTELL->komm1 WITH ARTIKEL->Bez1
  REPLACE BESTELL->komm2 WITH ARTIKEL->Bez2
  REPLACE BESTELL->E_komm1 WITH ARTIKEL->E_Bez1
  REPLACE BESTELL->E_komm2 WITH ARTIKEL->E_Bez2
  REPLACE BESTELL->Pe WITH ARTIKEL->Schluessel
  REPLACE BESTELL->Me WITH ARTIKEL->ME
  REPLACE BESTELL->ME2 WITH ARTIKEL->ME2

  if ! nurPreisanfrage
    // Preis nur kopieren, falls keine Fracht oder Verpackun bzw. falls diese berechnet wird
    if len(alltrim(BESTELL->ArtNr)) >3 .or.;
      (len(alltrim(BESTELL->ArtNr)) == 2 .and. VERSART->Verpack =="J" ) .or. ;
      (len(alltrim(BESTELL->ArtNr)) == 3 .and. VERSART->Fracht == "J")
      copyEKPreis()
    endif
  endif

return
/** eop */



  /* Bestellkarte im Kopf anzeigen
  */
static PROCEDURE Best_Art_Karte()
LOCAL M_ArtNr:=space(len(ARTIKEL->ArtNr))
LOCAL GetList:={} , erg:=""
  Umgebung(WRITE)
  setcolor(COLWIN)
  Fenster(4,20,6,40)
  Message("Artikel-Nummer eingeben.     @F12@=Hilfe")
  @ 5,22 say "Art.Nr.:" get M_ArtNr picture "@!" valid { |oGet| check(oGet,"Artikel",.f.,.f.) }
  read
  if ! ABBRUCH .and. ! empty(M_ArtNr)
    erg:=Art_BestKarte(getUser():mayEditData)
    select BesAus
    rec_lock(0) // unsch�n jojo
    if empty(BESAUS->LiefNr)
      replace BESAUS->LiefNr with erg
    endif
  endif
  Umgebung(LOAD)
RETURN
/* EOP Best_art_Karte */

/** liefert den Einzelpreis abzgl. Rabatt */
function getNettoEndPreis(Zeile)
LOCAL result:=space(8)
  if BESTELL->Rabatt>0
    if Zeile == 1
      result:=alltrim(str(BESTELL->Preis*(100-BESTELL->Rabatt)/100,10,2)) + " "+ EURO_SIGN
    else
      result:=alltrim(str(BESTELL->Preis2*(100-BESTELL->Rabatt)/100,10,2)) + " "+ EURO_SIGN
    endif
  endif
return left( result + space(8) , 8 )
/** eof */

/** liefert den Einheitentext zur 2. ME des aktuellen Artikels */
function getBestMe2Text()
LOCAL aktRec:=EINHEIT->(recno())
LOCAL result
  EINHEIT->(dbseek(BESTELL->ME2))
  result:=EINHEIT->Text
  EINHEIT->(dbgoto(aktRec))
return result
/** eof */

/** liefert den Artikel Lagerbestand mit ME */
function getArtikelLageBest()
LOCAL result:=str(ARTIKEL->LageBest,9,2)
LOCAL aktRec:=EINHEIT->(recno())

  EINHEIT->(dbseek( ARTIKEL->ME ))
  result += space(1) + EINHEIT->Text
  EINHEIT->(dbgoto(aktRec))

return result
/** eof */


/** �berpr�ft nach Beendigung des Editos ob g�ltige KW eingegeben */
static Function checke_Best_Nach(aKopf,aFelder,nurPreisanfrage,autoLaunch)
LOCAL woche:=left(BESTELL->KW,2)
LOCAL jahr:=right(BESTELL->KW,2)
LOCAL x

  ignore autoLaunch

  if empty(BESTELL->ArtNr)
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
    return .t.
  endif

  // pr�fe Menge > 0
  // if len(alltrim(BESTELL->ArtNr)) >3 .and. BESTELL->Menge <= 0 .and. BESTELL->Menge2 <= 0
  // if ! autoLaunch
  // Error(ACHTUNG+" Menge > 0 muss eingegeben werdern.",.t.)
  // endif
  // x:=getColPosByName(aFelder,"Menge")
  // if x==0
  // troubleEmail("Menge nicht gefunden.")
  // else
  // aKopf[EDIT_GET_OFFSET]:=x
  // endif
  // return .f.
  // endif


  /* MindestBestellMenge �berpr�fen */
  if ! nurPreisanfrage .and.;
    BESTELL->Preis <= 0 .and. getArtikelArt()<>"B" .and. ! empty(BESTELL->ArtNr) ;
    .and. ! trim(BESTELL->ArtNr)=="*";
    .and. BESTELL->Menge<>0 .and. len(alltrim(BESTELL->ArtNr)) > FRACHT_LAENGE

    if getUser():id == KURZEL_MIKI_GF .or. getUser():id == KURZEL_DEVEL
      // Error(ACHTUNG+" Preis sollte eingegeben werden.  Ausnahmeregelung f�r Herr Weiland",.t.)
    else
      Error(ACHTUNG+" Preis muss eingegeben werden.",.t.)

      // suche Feld mit Preis (kannn je nach Programm-Art variieren
      x:=getColPosByName(aFelder,"Preis")
      if x==0
        troubleEmail("Preis nicht gefunden.")
      else
        aKopf[EDIT_GET_OFFSET]:=x
      endif
      return .f.
    endif
  else
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  endif

  // pr�fe G�ltigkeit der Liefer-KW
  if KW_best_Okay(woche,jahr,nurPreisanfrage,BESTELL->Menge,BESTELL->ArtNr)
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  else
    // suche Feld mit KW (kannn je nach Programm-Art variieren
    x:=getColPosByName(aFelder,"Kw")
    if x==0
      troubleEmail("Kw nicht gefunden.")
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif
    return .f.
  endif

  if left(woche,1)=="*" .and. len(trim(BESTELL->KW_text))<3
    Error(ACHTUNG+" Liefertext muss eingegeben werden.  Mind. 3 Zeichen",.t.)
    // suche Feld mit Liefertext (kannn je nach Programm-Art variieren
    x:=getColPosByName(aFelder,"KW_Text")
    if x==0
      troubleEmail("Kw_text nicht gefunden.")
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif
    return .f.
  else
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  endif


return .t.
/** eof */


  /** Summiert alle offenen internen / externen Bestellungen aller Artikel bzw. eines Artikels
  *
  *  s. crontab BESTBESTAND
  *
  *  Parameter: extint:   0 - NIL = Beide
  *                       1       = extern
  *                       2       = intern
  *             ArtNr     optional, falls angegeben wird nur f�r diesen Artikel berechnet
  *
  * Ergebnis Best-Bestand falls nur extern oder nur intern f�r 1 Artikel, ansonsten 0
  */
function BestBestand(IntExt,MArtNr)
LOCAL sum,sumAB,aktSel:=alias()
LOCAL tempMenge, isLock

  default intext:=BEST_BEIDE // beide

  Umgebung( WRITE_ALL )

  if mArtnr==NIL
    cls
    Titel("Bestellbestand aktualisieren")
  endif

  if ! open("Artikel","BesAus","BesPost","Inner")
    Umgebung( LOAD )
    return 0
  endif

  Message("Bestellbestand wird aktualisiert.  Bitte warten...")

  // externe Bestellungen
  if intext=BEST_BEIDE .or. intext==BEST_EXT

    select BesPost
    set rela to BESPOST->BestNr into BesAus
    index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for BESAUS->Erledigt<>"J" .and. alltrim(BESPOST->ArtNr)<>"*"
    // set filter to BESAUS->Erledigt<>"J" .and. alltrim(BESPOST->ArtNr)<>"*"
    // BESPOST->(OrdSetFocus(2)) // Art.Nr.

    select Artikel
    if mArtnr==NIL
      go top
    else
      ARTIKEL->(dbseek(MArtNr))
    endif
    do while ! ARTIKEL->(eof()) .and. (MArtNr==NIL .or. MArtNr==ARTIKEL->ArtNr)
      BESPOST->(dbseek(Artikel->Artnr))
      // if mArtnr==NIL
      // @ 10,20 say "Art.Nr.: "+ARTIKEL->ArtNr
      // endif
      sum:=0
      do while ! BESPOST->(eof()) .and. BESPOST->ArtNr==ARTIKEL->ArtNr .and. ! ARTIKEL->(eof())
        if BESPOST->ArtNr=ARTIKEL->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes // keine �berliefert. mit -
          tempMenge:=BESPOST->Menge - BESPOST->GeliefGes
          // abweichende Mengeneinheit?
          if ARTIKEL->ME <> BESPOST->ME
            // Umrechnung bekannt
            if ARTIKEL->ME2 == BESPOST->Me
              tempMenge:=tempMenge / ARTIKEL->ME_Faktor
            else
              troubleemail(ACHTUNG + BESPOST->ArtNr+" "+BESPOST->Me+" Umrechnung nicht bekannt !" )
            endif
          endif
          sum+= tempMenge
        endif
        BESPOST->(dbskip())
      enddo
      if ARTIKEL->BestExt <> sum
        isLock:=isLocked()
        if ! rec_lock(5)
          trouble("BestBest", {ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->BestExt)+;
            " extern konnte nicht gesetzt werden."})
        else
          replace ARTIKEL->BestExt with sum
        endif
        dbcommit()
        if ! isLock
          dbunlock()
        endif
      endif
      skip
    enddo
  endif

  // interne Bestellungen
  if intext=BEST_BEIDE .or. intext==BEST_INT
    select Inner
    INNER->(OrdSetFocus(2)) // Art.Nr.

    select Artikel
    if mArtnr==NIL
      go top
    else
      ARTIKEL->(dbseek(MArtNr))
    endif
    do while ! ARTIKEL->(eof()) .and. (MArtNr==NIL .or. MArtNr==ARTIKEL->ArtNr)
      // erst alle inner. Auftr�ge ab 300!!!
      INNER->(dbseek(ARTIKEL->Artnr))
      // if mArtnr==NIL
      // @ 10,20 say "Art.Nr.: "+ARTIKEL->ArtNr
      // endif
      sum:=0
      sumAB:=0
      do while ! INNER->(eof()) .and. INNER->ArtNr==ARTIKEL->ArtNr .and. ! ARTIKEL->(eof())
        // keine �berlieferten mit -, und nur ab #100
        if INNER->ArtNr=ARTIKEL->ArtNr .and. INNER->Menge > INNER->GeliefGes

          sum+= INNER->Menge - INNER->GeliefGes
          if INNER->MengeAB > INNER->GeliefGes
            sumAB+= INNER->MengeAB - INNER->GeliefGes
          endif
        endif
        INNER->(dbskip())
      enddo

      // r�ckschreiben
      if ARTIKEL->Bestint <> sum .or. ARTIKEL->BestAB <> sumAB
        isLock:=isLocked()
        if ! rec_lock(5)
          trouble("BestBest", {ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->Bestint)+;
            " intern konnte nicht gesetzt werden."})
        else
          trouble("BestProt",{ARTIKEL->ArtNr+" Bestellt NEU:"+str(sum)+" AB:"+str(sumAB),;
            "LageBest vorher:"+str(ARTIKEL->LageBest)})
          replace ARTIKEL->Bestint with sum
          replace ARTIKEL->BestAB with sumAB
        endif
        dbcommit()
        if ! isLock
          dbunlock()
        endif
      endif
      skip
    enddo
  endif

  Umgebung( LOAD )

return sum
/** eop */


  /* Bestellungen als erledigt markieren
  */
PROCEDURE BestErledigt()
LOCAL Taste:=0,ant
LOCAL ob:=1, count:=0
LOCAL L_BestNr:=""
LOCAL GetList:={}

  cls
  Titel("Bestellung als erledigt markieren")

  if ! open( "Bestell" , "BesAus" , "ZahlKond" ;
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "Lieferan","LiefTerm";
    ,"AvPost" , "System" , "WarAus" , "BesPost" , "Text_Kz";
    ,"AufAus" , "AufPost" , "Auftrag" , "M_Mehrf","Kunden")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  select Bestell
  SET RELATION TO BESTELL->ArtNr INTO Artikel, to BESTELL->ME INTO EINHEIT
  select BesAus
  set relation to BESAUS->Mwst_Kz into MWst_kz,BESAUS->VersNr into VersArt
  go bottom
  skip // leeren Satz anzeigen

  do while ! ( Taste==K_ESC )

    /* Kopf eingeben */
    select BesAus
    L_BestNr:=space(len(BESAUS->BestNr))
    @ ob+1,0 clear
    @ ob+1,1 say 'Bestell Nr.:'
    @ ob+1,14 get L_BestNr picture '@K #####';
      when;
      Message("Bestellnummer eingeben.      @F12@=Hilfe");
      valid { |oGet| check(oGet,"BesAus",.f.,.f.) }
    read
    Taste:=lastkey()

    exactseek(L_BestNr)
    if eof() .or. Taste==K_ESC
      loop
    endif
    Best_Kopf_Disp()
    Best_Kopf(2) // display only
    @ 1+1,14 say BESAUS->BestNr
    Message("Taste dr�cken.","@")
    if ABBRUCH
      loop
    endif

    // posten kopieren
    select Bestell
    zap
    BESPOST->(dbseek(BESAUS->BestNr))
    if ! append("BesPost", { || BESPOST->BestNr==BESAUS->BestNr } )
      Error("Keine Posten vorhanden.",.t.)
    else
      best_Bauch(.f.,.t.) // keine Preisanfrage, aber nur Anzeige
    endif

    if BESAUS->erledigt=="J"
      ant:=Message("Bestellung @w@iederherstellen -- @ESC@=Abbruch ( @W@ / @ESC@) ","W")
    else
      ant:=Message("Bestellung @e@rledigt  -- @ESC@=Abbruch ( @E@ / @ESC@) ","E")
    endif
    if ABBRUCH
      loop
    endif

    count++

    if ant="W" // Bestellung war als erledigt markiert - r�ckg�ngig machen
      if BESAUS->erledigt=="J"
        SELECT Besaus
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        replace BESAUS->erledigt with " "
        dbcommit()
        dbunlock()
        Error("INFO: Bestellung: "+BESAUS->BestNr+" wieder hergestellt.",.t.)
      endif
    elseif ant="E" // Bestellung wird als erledigt markiert

      // pr�fe ob alle Posten beliefert
      select Bestell
      loca for BESTELL->GeliefGes == 0
      if ! BESTELL->(eof())
        ant:=Message("Best. enth�lt unbelieferte Posten.  Trotzdem als erledigt markieren? (@J@/@N@)",;
          "JN"," ")
        if ABBRUCH .or. ant <> "J"
          loop
        endif
      else
        loca for BESTELL->GeliefGes/BESTELL->Menge*100 < 90
        if ! BESTELL->(eof())
          ant:=Message("Best. enth�lt Posten die zu weniger als 90% beliefert sind. "+;
            "Trotzdem erledigt? (@J@/@N@)", "JN"," ")
          if ABBRUCH .or. ant <> "J"
            loop
          endif
        endif
      endif

      SELECT Besaus
      if ! rec_lock(5)
        Error(TRY_AGAIN)
        loop
      endif
      replace BESAUS->erledigt with "J"
      dbcommit()
      dbunlock()
      Error("INFO: Bestellung: "+BESAUS->BestNr+" als erledigt markiert.",.t.)
    endif

  enddo

  if count>0
    BestBestand(BEST_EXT)
    AufBestand()
  endif
  close data
  set key K_F5 to

RETURN
/* EOP Best_loeschen */

  /** Pr�ft ob Posten bereits beliefert -> darf nicht gel�scht werden
  * oder ob ein Posten bereits ein innerbetr. Auftrag existiert
  */
static function konsistenzLoesch()

  if BESTELL->GeliefGes > 0
    Error(ACHTUNG+"Posten wurde bereits beliefert.||         Kann nicht gel�scht werden!",.t.)
    return .f.
  endif

  // now delete via editor.prg
  HB_KeyPut(EDIT_DELETE)

return .t.
/** eof */

/** erlaubt nach Abfrage das Editieren obwohl eigentlich gesperrt ist */
static function bestellEdit()
  if Message("Bestellung bereits erledigt.  Trotzdem bearbeiten? (@J@/@N@)","JN","N") == "J"
    HB_KeyPut(EDIT_LINE_EDIT) // default edit
  endif
return .t.
/** eof */

  /*** holt den EK-Preis des aktuellen Artikels (Bestell.dbf)
  *
  * falls vorhanden nimmt er den j�ngsten Eintrag aus
  * - letzte Bestellung
  * - Bestellkarte
  *
  * falls keine vorhanden nimmt er den EK
  */
static Procedure copyEKPreis()
LOCAL aktOrd

  Umgebung( WRITE_ALL )

  // suche Bestellkarte
  BESTKART->( dbseek( BESTELL->ArtNr + BESAUS->LiefNr ) )

  // suche letzte Bestellung
  select BesPost
  aktOrd:=BESPOST->(indexOrd())
  BESPOST->(OrdSetFocus(3)) // LiefNr + ArtNr
  dbseek( BESTELL->ArtNr+BESAUS->LiefNr )

  if BESPOST->(eof())
    if BESTKART->(eof()) // beide nicht gefunden -> nehme Artikel->EK
      copyEKArtikel()
    else
      copyEKBestellKarte() // Bestkarte
    endif
  else
    if BESTKART->(eof())
      copyEKBespost() // letzte Bestellung
    else
      // beide gefunden -> nehme den j�ngsten
      BESAUS->(dbseek(BESPOST->BestNr))
      if BESAUS->BESTDAT > BESTKART->Datum
        copyEKBespost() // letzte Bestellung
      elseif BESTKART->Datum > BESAUS->BESTDAT
        copyEKBestellKarte() // Bestkarte
      else
        // beide vom gleichen Tag -> EK sollte am selben Tag nicht abweichen
        copyEKBestellKarte() // Bestkarte
      endif

    endif

  endif
  BESPOST->(aktOrd)
  select Bestell

  // l�sche 2. Preis und Menge, falls ArtNr �berschrieben wurde
  if empty(BESTELL->ME2)
    REPLACE BESTELL->Menge2 WITH 0
    REPLACE BESTELL->Preis2 WITH 0
  endif

  Umgebung( LOAD )
return
/** eop */

/** kopiert den Preis aus der Bestellkarte */
static procedure copyEKBestellKarte
  REPLACE BESTELL->Me WITH BESTKART->LiefME
  REPLACE BESTELL->Rabatt WITH BESTKART->Rabatt
  REPLACE BESTELL->Pe WITH ARTIKEL->Schluessel
  REPLACE BESTELL->TempKz WITH "K"

  // Hinweis wird evtl. unten umgerechnet
  REPLACE BESTELL->Preis WITH BESTKART->Preis1

  // berechne 2. ME
  if ! empty(ARTIKEL->ME2) .and. ARTIKEL->ME_Faktor > 0

    if BESTELL->ME == ARTIKEL->ME
      REPLACE BESTELL->ME2 with ARTIKEL->ME2
      REPLACE BESTELL->Preis2 WITH BESTELL->Preis / ARTIKEL->ME_Faktor
    else
      REPLACE BESTELL->ME2 with ARTIKEL->ME
      REPLACE BESTELL->Preis2 WITH BESTELL->Preis // ist schon umgerechnet

      // 1. Preis hier umrechnen
      REPLACE BESTELL->Preis WITH BESTELL->Preis / ARTIKEL->ME_Faktor
    endif

  endif
return

/** kopiert den Preis aus der letzten Bestellung */
static procedure copyEKBespost
  REPLACE BESTELL->ME WITH BESPOST->ME
  REPLACE BESTELL->Pe WITH BESPOST->Pe
  REPLACE BESTELL->Preis WITH BESPOST->Preis
  REPLACE BESTELL->TempKz WITH "B"

  if ! empty(BESPOST->ME2)
    REPLACE BESTELL->ME2 WITH BESPOST->ME2
    REPLACE BESTELL->Preis2 WITH BESPOST->Preis2
  endif

  REPLACE BESTELL->Rabatt WITH BESPOST->Rabatt

  // umrechnen falls unterschiedliche Mengeneinheit
  // -> entf�llt, da auch ME aus Bespost �bernommen wird
return
/** eop */

static procedure copyEKArtikel()
  REPLACE BESTELL->Preis WITH ARTIKEL->EKPR
  REPLACE BESTELL->Pe WITH ARTIKEL->Schluessel
  REPLACE BESTELL->TempKz WITH "A"

  // berechne 2. ME
  if ! empty(ARTIKEL->ME2) .and. ARTIKEL->ME_Faktor > 0
    if BESTELL->ME == ARTIKEL->ME
      REPLACE BESTELL->ME2 with ARTIKEL->ME2
      REPLACE BESTELL->Preis2 WITH BESTELL->Preis / ARTIKEL->ME_Faktor
    else
      REPLACE BESTELL->ME2 with ARTIKEL->ME
      REPLACE BESTELL->Preis2 WITH BESTELL->Preis * ARTIKEL->ME_Faktor
    endif
  endif

return
/** eop */

/** kopiert Preis bei Mengen�nderung anhand der j�ngsten Rabattkarte */
static function copyEKMengeBestKart(oGet, bestellMenge)
LOCAL i,pr,men,treffer:=.f., faktor, mindMenge, ant:=""
LOCAL aktSel:=alias()

  // suche Bestellkarte erneut, falls Artikel nicht neu erfasst wurde
  // Hinweis: m�gliche Fehlerquelle, falls alte Bestellung bearbeitet wird
  select BestKart
  dbseek(BESTELL->ArtNr+BESAUS->LiefNr)
  faktor:=if( ARTIKEL->ME_Faktor > 0, ARTIKEL->ME_Faktor , 1 )

  if eof()
    Error(ACHTUNG+"Keine Bestellkarte gefunden oder Bestellkarte noch offen.|"+;
      "         Nehme Artikel EK!!!",.t.)
    if BESTELL->ME == ARTIKEL->ME
      Replace BESTELL->Preis WITH ARTIKEL->EKPR
      if ! empty(BESTELL->ME2)
        Replace BESTELL->Preis2 WITH round( ARTIKEL->EKPR / faktor , 2) // umrechnen
      endif
    else
      Replace BESTELL->Preis WITH round( ARTIKEL->EKPR / faktor , 2) // umrechnen
      if ! empty(BESTELL->ME2)
        Replace BESTELL->Preis WITH ARTIKEL->EKPR
      endif
    endif
    select (aktSel)
    return .t.
  else
    // Replace BESTELL->Preis WITH 0
    for i:=1 to 4
      pr:="BESTKART->Preis"+str(i,1)
      men:="BESTKART->Menge"+str(i,1)
      if &(pr) <> 0.00 .and. (( BESTELL->ME == ARTIKEL->ME .and. ;
        flexCompare( round(bestellMenge,2) , round(&(men),2) , 0.05 ) >= 0 ) .or.;
        ( BESTELL->ME == ARTIKEL->ME2 .and. ;
        flexCompare( round(bestellMenge,2) , round(&(men)*ARTIKEL->ME_Faktor ,2), 0.05 ) >=0 ))

        treffer:=.t.

        if BESTELL->ME == ARTIKEL->ME // Bestellkarte wird immer in ME des Artikel gef�hrt
          // Hinweis BESTKART->LiefME ist Wunscheinheit des Lieferanten
          Replace BESTELL->Preis WITH round( &(pr) , 2)
          if ! empty(BESTELL->ME2)
            Replace BESTELL->Preis2 WITH round( &(pr) / faktor , 2) // umrechnen
          endif
        else
          Replace BESTELL->Preis WITH round( &(pr) / faktor , 2) // umrechnen
          if ! empty(BESTELL->ME2)
            Replace BESTELL->Preis2 WITH round( &(pr) , 2)
          endif
        endif
      endif
    next

    // falls Best.Karten Mindestmenge nicht erreicth -> Hinweis & Preis = 0
    if ! treffer
      REPLACE BESTELL->Preis WITH 0
      Replace BESTELL->Preis2 WITH 0

      mindMenge:=BESTKART->Menge1

      // umrechnen in 2. ME?
      if ! empty(ARTIKEL->ME2) .and. ARTIKEL->ME_Faktor > 0 .and. BESTELL->EingabeME <> ARTIKEL->ME
        mindMenge:=mindMenge * ARTIKEL->ME_Faktor
      endif

      EINHEIT->(dbseek(BESTELL->EingabeME))

      if oGet == nil
        Error(ACHTUNG+"Mindestmenge in Bestellkarte: "+alltrim(str(mindMenge,9,0))+" "+;
          EINHEIT->Text,.t.)
        select (aktSel)
        return .f.
      else
        Umgebung(WRITE)
        Error(ACHTUNG+"Mindestmenge in Bestellkarte: "+alltrim(str(mindMenge,9,0))+" "+;
          EINHEIT->Text, ERR_NO_WAIT)
        do while ! ant $"JN"
          ant:=Message("Mindestmenge aus Bestellkarte: "+alltrim(str(mindMenge,9,0))+" "+EINHEIT->Text+;
            " �bernehmen? (@J@/@N@)","JN"," ")
        enddo
        if ant== "J"
          select Bestell
          oget:varput(mindMenge)
          keyboard chr(K_RETURN)
          Umgebung(LOAD)
          return .f. // go again
        else
          Umgebung(LOAD)
        endif
      endif
    endif

    // raus 27.2.15, Rabatt ist bereits in Bestellkarten-Preis enthalten
    // s. z.B. Art 897015.5
    // irgendwann wieder rein :(
    REPLACE BESTELL->Rabatt WITH BESTKART->Rabatt

  endif
  select (aktSel)
return .t.
/** eop */

/*
 * Sammelbestellung erfassen
 */
static function SammelBestellung(nurPreisanfrage,oGet)
LOCAL ant, mFeld, kwFeld , i, meinPreis1:=nil, meinPreis2:=nil, gesamtMenge
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX] , starteBeiRecno
LOCAL oldF5:=SetKey( K_F5 , { || toggleME()} )
LOCAL aktSel:=alias() // yes we need this, since we want sammelbest to stay open
LOCAL aktRec, mArtNr

PRIVATE ME

  default nurPreisanfrage:=.f.

  if ! open( "Artikel", "SammelTemp","SammelBest")
    Error(TRY_AGAIN)
    select (aktSel)
    RETURN .f.
  endif

  Umgebung(WRITE_ALL)

  select SammelBest
  dbseek(BESAUS->BestNr)

  select SammelTemp
  zap

  do while ! SAMMELBEST->(eof()) .and. SAMMELBEST->BestNr == BESAUS->BestNr
    add_rec(0)
    overwrite("SammelBest")
    select SammelBest
    rec_lock(0)
    delete
    dbunlock()
    skip
    select SammelTemp
  enddo

  if SAMMELTEMP->(reccount()) == 0
    // kopiere aktuellen Artikel, sollte auf grund bespost selektiert sein
    add_rec(0)
    replace SAMMELTEMP->ArtNr with ARTIKEL->ArtNr
  endif

  // setcolor(COLWIN)
  // Fenster(4,20,6,40)
  set relation to SAMMELTEMP->ArtNr into Artikel
  go top // gehe auf 1. Artikel


  // Daten werden immer in Einheit des Artikels gespeichert
  // alle Einheiten bei mehreren Artikel sind identisch, also nur den 1. nehmen
  M->ME:=ARTIKEL->ME

  // immer am Anfang kg anzeigen
  if ! empty( ARTIKEL->ME ) .and. ! empty( ARTIKEL->ME2 ) .and.;
    EINHEIT_KG $ ARTIKEL->ME + ARTIKEL->ME2 .and. ARTIKEL->ME <> EINHEIT_KG
    toggleME()
  endif

  Inkey() // remove last key from buffer
  do while ! ABBRUCH .or. starteBeiRecno==NIL

    EINHEIT->(dbseek( M->ME ))

    aFelder:={}
    select SammelTemp
    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=11 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_ENDE_Y]:=-3 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_LM]:=01 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_RM]:=78 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile

    aKopf[EDIT_EXTRA_FKT]:={}
    aKopf[EDIT_DRAW_FRAME]:="Sammel-Bestellung erfassen "
    if ! EINHEIT->(eof())
      aKopf[EDIT_DRAW_FRAME] += "("+alltrim( EINHEIT->Kommentar ) +")"
    endif

    if ! empty( ARTIKEL->ME ) .and. ! empty( ARTIKEL->ME2 )
      aadd(aKopf[EDIT_EXTRA_FKT], { chr(K_F5)," @F5@=Einheit", { || toggleMe() }})
    endif

    if valtype(starteBeiRecno)=="N"
      aKopf[EDIT_START_REC]:=starteBeiRecno
    endif

    /* Feld-Definitionen */
    aSpalte:=e_fill() // initialisieren
    // Artikel-Nr.
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_AFTER]:=;
      { |oGet| check(oGet,"Artikel",.f.,.f.) .and. sammelArtNrNach(aKopf,aFelder) }
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="left(ARTIKEL->Bez1,17)"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Menge1"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MESSAGE]:="Menge 1 eingeben."
    aSpalte[EDIT_MESSAGE]:="Menge eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Kw1"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_POS_X]:=4
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."
    aSpalte[EDIT_AFTER];
      :={ |oGet| SAMMELTEMP->Menge1 == 0 .or. Best_kw_nach(oGet,nurPreisanfrage,"SAMMELTEMP->Meng"+;
      "e1","SAMMELTEMP->ArtNr") }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Menge2"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MESSAGE]:="Menge 2 eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Kw2"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_POS_X]:=4
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."
    aSpalte[EDIT_AFTER];
      :={ |oGet| SAMMELTEMP->Menge2 == 0 .or. Best_kw_nach(oGet,nurPreisanfrage,"SAMMELTEMP->Meng"+;
      "e2","SAMMELTEMP->ArtNr") }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Menge3"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MESSAGE]:="Menge 3 eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Kw3"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_POS_X]:=4
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."
    aSpalte[EDIT_AFTER];
      :={ |oGet| SAMMELTEMP->Menge3 == 0 .or. Best_kw_nach(oGet,nurPreisanfrage,"SAMMELTEMP->Meng"+;
      "e3","SAMMELTEMP->ArtNr") }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Menge4"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MESSAGE]:="Menge 4 eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Kw4"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_POS_X]:=4
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."
    aSpalte[EDIT_AFTER];
      :={ |oGet| SAMMELTEMP->Menge4 == 0 .or. Best_kw_nach(oGet,nurPreisanfrage,"SAMMELTEMP->Meng"+;
      "e4","SAMMELTEMP->ArtNr") }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Menge5"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_MESSAGE]:="Menge 5 eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Kw5"
    aSpalte[EDIT_MASKE]:="!!/99"
    aSpalte[EDIT_POS_X]:=4
    aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."
    aSpalte[EDIT_AFTER];
      :={ |oGet| SAMMELTEMP->Menge5 == 0 .or. Best_kw_nach(oGet,nurPreisanfrage,"SAMMELTEMP->Meng"+;
      "e5","SAMMELTEMP->ArtNr") }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    Edit(aFelder,aKopf)
    starteBeiRecno:=SAMMELTEMP->(recno())

  enddo

  /* schreibe Bestellkarte zur�ck */
  if SAMMELTEMP->(reccount())>0 .and. ;
    Message("Bestellposten erzeugen? (@J@/@N@)","JN") == "J"

    ant:="J"
    select Bestell
    loca for ! empty(BESTELL->ArtNr)
    if BESTELL->(eof())
      ant:=Message("Vorhandene Posten in Bestellung �berschreiben? (@J@/@N@)","JN")

      if ABBRUCH .and. Message("Sammelbestellung verwerfen? (@J@/@N@)","JN")=="J"
        Umgebung(LOAD)
        SetKey( K_F5 , oldF5)
        select (aktSel) // yes we need this, since we want sammelbest to stay open
        return .t.
      endif

    endif

    select Bestell
    if ant == "J"
      replace all BESTELL->Geloescht with "J"
    else
      replace BESTELL->Geloescht with "J" for empty( BESTELL->ArtNr )
    endif

    // erzeuge Posten
    select SammelTemp
    go top // needed for rela

    /* schreibe Sammelbestellung zur�ck, immer in Einheit des Artikels */
    if M->ME <> ARTIKEL->ME
      toggleValues()
    endif

    go top
    do while ! SAMMELTEMP->(eof())
      aktRec:=SAMMELTEMP->(recno())
      mArtNr:=SAMMELTEMP->ArtNr
      meinPreis1:=meinPreis2:=NIL

      // summiere die Menge aller (!) Posten des Artikels
      // war so gew�nscht (Anfang 2015) speziell f�r Artikel mit dem gleichen Material
      go top
      sum SAMMELTEMP->Menge1 + ;
        SAMMELTEMP->Menge2 + ;
        SAMMELTEMP->Menge3 + ;
        SAMMELTEMP->Menge4 + ;
        SAMMELTEMP->Menge5 ;
        to gesamtMenge for mArtNr == SAMMELTEMP->ArtNr
      dbgoto( aktRec )

      for i:=1 to 5
        mFeld:="SAMMELTEMP->Menge"+str(i,1)
        kwFeld:="SAMMELTEMP->KW"+str(i,1)
        if &(mFeld) > 0
          select Bestell
          add_rec(0)
          replace BESTELL->LiefNr with BESAUS->LiefNr
          replace BESTELL->ArtNr with SAMMELTEMP->ArtNr
          replace BESTELL->PE with ARTIKEL->Schluessel
          copyArtikelDaten( .f. ) // mit Preis wegen ME Reihenfolge
          // copyArtikelDaten( .t. ) // ohne Preis
          replace BESTELL->KW with &(kwFeld)
          replace BESTELL->EingabeME with M->ME

          if BESTELL->ME == ARTIKEL->ME
            replace BESTELL->Menge with &(mFeld)
            berechneMenge( "Menge" , &(mFeld) )

          else
            replace BESTELL->Menge2 with &(mFeld)
            berechneMenge( "Menge2" , &(mFeld) )

          endif

          // kopiere Preis
          if meinPreis1 == nil

            if ! copyEKMengeBestKart(nil,gesamtMenge)
              HB_KeyPut(K_F11) // restart
            else
              // okay also merke preis
              meinPreis1:=BESTELL->Preis
              meinPreis2:=BESTELL->Preis2
            endif
          else // �bernehme Preis vom 1. Artikel

            replace BESTELL->Preis with meinPreis1
            replace BESTELL->Preis2 with meinPreis2

          endif

        endif
        select SammelTemp
      next

      SAMMELTEMP->(dbskip())
    enddo
  endif

  // Sammel-Posten r�ckschreiben, immer in Einheit des Artikels
  Select SammelTemp
  go top // needed so rela to Artikel is adjusted
  if M->ME <> ARTIKEL->ME
    toggleValues()
  endif
  replace all SAMMELTEMP->BestNr with BESAUS->BestNr
  go top

  select SammelBest
  append("SammelTemp")

  dbcommitall()
  //dbunlockall() removed 20170411 also releases lock on BESAUS!

  SetKey( K_F5 , oldF5)
  Umgebung(LOAD)
  select (aktSel) // yes we need this, since we want sammelbest to stay open

  if oGet <> NIL
    HB_KeyPut(K_ESC) // quit edit modus if applicable
  endif

  dispEditorSumme("BESAUS","BESTELL->Menge",49)
  HB_KeyPut(EDIT_BS_REFRESH)
  HB_KeyPut(K_HOME)

RETURN .t.
/* EOP Sammelbestellung */

/** Schaltet die ME im Editor-Bauch um */
static function toggleME(p1,oGet)

  ignore p1

  ARTIKEL->(dbseek( SAMMELTEMP->ArtNr ))

  if ! empty(ARTIKEL->ME2)

    // need this, otherwise get field will overwrite toggled value if it is a Menge
    if oGet != nil
      oGet:killFocus()
    endif

    toggleValues()

    // beende akt. Editor -> wird neu gestartet mit neuer Sprache
    if inStackTrace("LineEdit") // ouch!
      HB_KeyPut(K_ESC)
    endif
    HB_KeyPut(EDIT_QUIT)

  endif

return .t.
/** eof */

/** Rechnet Menge und Preis anhand des ME_Faktors des Artikels um */
static function toggleValues()
LOCAL neuME

  // nur falls 2. Einheit hinterlegt
  if empty( ARTIKEL->ME2 )
    return .f.
  endif

  Umgebung(WRITE_ALL)

  if M->ME == ARTIKEL->ME
    neuMe:=ARTIKEL->ME2
  else
    neuMe:=ARTIKEL->ME
  endif

  select SammelTemp
  go top

  do while ! SAMMELTEMP->(eof())
    ARTIKEL->(dbseek( SAMMELTEMP->ArtNr ))

    // nur wenn 2 MEs im Artikel hinterlegt
    if ! empty( ARTIKEL->Me2 )

      if M->ME == ARTIKEL->ME
        replace SAMMELTEMP->Menge1 with SAMMELTEMP->Menge1 * ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge2 with SAMMELTEMP->Menge2 * ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge3 with SAMMELTEMP->Menge3 * ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge4 with SAMMELTEMP->Menge4 * ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge5 with SAMMELTEMP->Menge5 * ARTIKEL->ME_Faktor

      else
        replace SAMMELTEMP->Menge1 with SAMMELTEMP->Menge1 / ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge2 with SAMMELTEMP->Menge2 / ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge3 with SAMMELTEMP->Menge3 / ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge4 with SAMMELTEMP->Menge4 / ARTIKEL->ME_Faktor
        replace SAMMELTEMP->Menge5 with SAMMELTEMP->Menge5 / ARTIKEL->ME_Faktor

      endif
    endif
    skip

  enddo

  M->ME:=neuMe
  EINHEIT->(dbseek( M->ME ))
  Umgebung(LOAD)

return .t.
/** eof */

  /** pr�ft auf korrekte ME
  *
  * FIXME: pr�ft nur die 1. ME :(
  */
static function sammelArtNrNach(aKopf,aFelder)
  // if ! EINHEIT_KG $ ARTIKEL->ME + ARTIKEL->ME2
  // Error(ACHTUNG+"Artikel wird nicht in kg gef�hrt.||"+;
  // "         Zusammenfassen nicht m�glich.",.t.)
  // return .f.
  // endif

  if empty(M->ME)
    M->ME:=ARTIKEL->ME

    // immer am Anfang kg anzeigen
    if EINHEIT_KG $ ARTIKEL->ME + ARTIKEL->ME2 .and. ARTIKEL->ME <> EINHEIT_KG
      toggleValues()
    endif

    EINHEIT->(dbseek( M->ME ))

    aKopf[EDIT_DRAW_FRAME]:="Sammel-Bestellung erfassen ("+alltrim( EINHEIT->Kommentar ) +")"
    drawEditFrame(aKopf,aFelder,aKopf[EDIT_DRAW_FRAME])

  else
    if ! M->ME $ ARTIKEL->ME + ARTIKEL->ME2
      Error(ACHTUNG+"Artikel wird in anderer Einheit gef�hrt.||"+;
        "         Zusammenfassen nicht m�glich.",.t.)
      return .f.
    endif
  endif
return .t.
/** eof */


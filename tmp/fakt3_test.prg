/* Modul:  Fakt3.prg    enth�lt Teile des Fakturierung-sprog, K-Lager
*/

#include "Miki.ch"
#include "Zeige.ch"
// #include "repa.ch"

#define MAX_HART_NR replicate(chr(255),20)


/* Procedure KStornoRechnung() ******************************************
*
*  erzeugt auf Basis einer existierenden Rechnung eine Storno-Rechnung
*/
PROCEDURE KStornoRechnung
LOCAL M_Rechnr:=".",StRechnr
LOCAL Titel:="K-Lager Rechnung stornieren"
LOCAL GetList:={},okay,gedruckt:=.f.
  // LOCAL Temp_Datei:=TEMP + "\temp"+getUser():getLongID()+".dbf"
LOCAL Temp_Datei:=getTempDateiName( db_info("RechAus") ) + ".dbf"
LOCAL stornoMenge,teilLieferung

  cls
  Titel(Titel)
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "AufAus" , "ZahlKond","Rabatt" , "Text_Kz" ,"AvPost";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "Aufpost";
    ,"Kunden" , "RechAus" , "RechPost", "Verkauf","Mat_Kz";
    ,"Erl_Grup", "Maschine", "LiefTerm","Spedit","Land";
    ,"Text","Konsig","Email")


    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  select RechPost
  set relation to RECHPOST->ME into Einheit
  select Konsig


  // select aufaus
  /**  set relation to AUFAUS->textkz_Nr into Text_Kz,to AUFAUS->zknr into zahlkond,to AUFAUS->versNr into versart */
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart


  do while ! empty(M_Rechnr)
    cls
    Titel(Titel)
    select rechaus
    set filter to RECHAUS->AufArt=="K"
    M_Rechnr:=space(len(RECHAUS->RechNr))
    Message("Rechnungsnummer eingeben.           @F12@=Hilfe")
    @ 4,10 say "Rech.Nr.:" get M_Rechnr valid { |oGet| shift(oGet) }
    read
    if empty(M_Rechnr) .or. lastkey()==K_ESC
      loop
    endif

    set filter to

    RECHAUS->(dbseek(M_Rechnr))
    if RECHAUS->(eof())
      loop
    endif

    /* Auswahl-Menu */
    IF RECHAUS->Aufart<>"K"
      Error(ACHTUNG+" Nur K-Lager Rechnung kann hier als Storno-Rechnung gedruckt werden.",.t.)
      loop
    endif
    IF ! empty(RECHAUS->Storno_Nr)
      Error(ACHTUNG+" Rechnung bereits storniert! Siehe Rechn.Nr. "+RECHAUS->Storno_Nr,.t.)
      loop
    endif
    setcolor(COLWIN)
    okay:=" "
    Message("Drucken als Storno-Rechnung? (@J@/@N@)")
    Fenster(7,16,13,57)
    @ 8,20 say 'Drucken als:'
    @ 10,20 say "Storno-Rechnung"
    @ 12,20 say "Okay:" get okay picture "!" valid okay $ "JN"
    read
    // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
    // do while ! Login_change(12,20,"Sachbearbeiter: ")
    // enddo
    setcolor(COLNOR)
    @ 7,0 clear
    if lastkey()==K_ESC .or. okay<>"J"
      loop
    endif

    // added 20090404
    AUFAUS->(dbseek(RECHAUS->AufNr))
    if AUFAUS->InvKZ=="J" .and. AUFAUS->erledigt=="J"
      select Aufaus
      rec_lock(0)
      replace AUFAUS->erledigt with " "
      // added 20160218
      Select Aufpost
      AUFPOST->(dbseek(RECHAUS->AufNr))
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr == RECHAUS->AufNr
        rec_lock(0)
        // setze alle gelieferten auf 0, da keine Teillieferung bei Inventur AB/Rechnung
        replace AUFPOST->Gelief with 0, AUFPOST->GeliefGes with 0
        dbcommit()
        dbunlock()
        skip
      enddo
      select Aufaus
      dbcommit()
      dbunlock()
    endif

    /* Satz locken */
    SELECT RechAus
    seek M_Rechnr
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      loop
    endif

    StRechNr:=hole("RechNr",WRITE,.t.)
    Message("Storno-Rechnung: @"+StRechNr+"@ wird gedruckt.  Bitte warten...")

    /* Rechnungsposten kopieren */
    Select Aufpost
    AUFPOST->(OrdSetFocus(3)) // AuFNr+Anr

    select RechPost
    copy stru to (temp_datei)
    seek RECHAUS->RechNr
    select 0
    use (temp_datei) exclusive alias kopie

    /* alle passenden Rechnungs-Posten kopieren -> temp. Datei*/
    do while RECHPOST->RechNr==M_Rechnr .and. ! RECHPOST->(eof())
      select KOPIE
      add_rec(0)
      overwrite("RechPost")
      REPLACE KOPIE->Gelief With KOPIE->Gelief * (-1)
      REPLACE KOPIE->GeliefGes With KOPIE->GeliefGes * (-1)
      REPLACE KOPIE->RechNr WITH StRechNr
      REPLACE KOPIE->ReaDat WITH getUser():date
      select RechPost
      skip
    enddo

    /** kopiere Storno Rechnungs Posten zurueck nach RechPost */
    select KOPIE
    go top
    do while .not. eof()
      select RechPost
      add_rec(0)
      overwrite( "Kopie" )
      dbcommit()
      dbunlock()

      /** Posten in Konsig wieder als nicht berechnet markieren */
      select Konsig
      KONSIG->(dbseek(RECHPOST->AufNr+RECHPOST->ArtNr))
      // KONSIG->(dbseek(RECHAUS->KundNr+RECHPOST->ArtNr))
      // ACHTUNG: hier (noch) keine genaue Zuordnung
      // geht schief falls gl. Artikel mit unterschiedl. Preisen geliefert

      if RECHPOST->gelief < 0 // Normale Storno
        stornoMenge:=abs(RECHPOST->gelief)

        // do while ! KONSIG->(eof()) .and. KONSIG->KundNr==RECHAUS->KundNr;
          do while ! KONSIG->(eof()) .and. KONSIG->AufNr==RECHPOST->AufNr;
          .and. KONSIG->ArtNr==RECHPOST->ArtNr .and. stornoMenge>0

        if KONSIG->Berechnet > 0
          teilLieferung:=Min(KONSIG->Berechnet,stornoMenge)
          if REC_LOCK(0)
            REPLACE KONSIG->Berechnet WITH KONSIG->Berechnet-teilLieferung
            dbcommit()
            dbunlock()
            stornoMenge:=stornoMenge - teilLieferung
          endif
        endif
        skip
      enddo

      // FIXME: was ist bei KLager-Inventurauftrag
      if stornoMenge>0
        Error(ACHTUNG+str(stornoMenge,8)+" x "+RECHPOST->ArtNr+" konnten nicht zugewiesen werden.",;
          .t.,"root")
      endif

    else // RECHPOST->gelief > 0
      // pos. Menge in Storno Rechnung kann nur bei Inv.Rechnung passieren (KLager-Inventurauftrag)
      // -> Alle Konsig.db Eintr�ge der Inv.AB l�schen
      rec_lock(0)
      delete
    endif

      /** K-Lager Bestand wieder erhoehen */
    select Artikel
    dbseek(RECHPOST->ArtNr)
    if ! Rec_Lock(5)
      Error(ACHTUNG+" "+RECHPOST->ArtNr+" K-Lager konnte nicht geschrieben werden. Bitte "+;
        "kontrollieren",.t.)
    else
      aendArtKBest(RECHPOST->Gelief*(-1),WARAUS_RECHNR_STORNO + RECHPOST->RechNr)
    endif

    // verkaufte Artikel runterzaehlen
    select Artikel
    if rec_lock(5)
      trouble("Verkauft",{ARTIKEL->ArtNr+" vorher:"+str(ARTIKEL->verkauft)+;
        " �nderung: "+str(RECHPOST->Gelief)+ " nachher: "+str(ARTIKEL->verkauft+RECHPOST->Gelief)})

      replace ARTIKEL->verkauft with ARTIKEL->verkauft+RECHPOST->Gelief
      dbcommit()
      dbunlock()
    endif

    select KOPIE
    skip
  enddo

  select KOPIE
  use

    /** erzeuge Storno Rechnungs Kopf */
  select RechAus
  REPLACE RECHAUS->Storno_Nr with StRechNr
  dbcommit()
  dbunlock()
  copy stru to (temp_datei)
  select 0
  use (temp_datei) exclusive alias Kopie

    /* Rechnungs-Kopf kopieren */
  select KOPIE
  add_rec(0)
  overwrite("RechAus")
  REPLACE KOPIE->Storno_Nr with KOPIE->RechNr
  REPLACE KOPIE->RechNr WITH StRechNr
  REPLACE KOPIE->ReaDat WITH getUser():date
  replace KOPIE->Aufart WITH "S"
  // replace KOPIE->gedruckt WITH " "
  replace KOPIE->SumNr WITH ""
  replace KOPIE->Netto WITH RECHAUS->Netto * (-1)
  replace KOPIE->Brutto WITH RECHAUS->Brutto * (-1)
  replace KOPIE->NebenKost WITH RECHAUS->NebenKost * (-1)
  replace KOPIE->Rabatt WITH RECHAUS->Rabatt * (-1)

    /** kopiere Storno Rechnungs Kopf zurueck nach RechAus */
  select RechAus
  add_rec(0)
  overwrite( "Kopie" )
  close( "Kopie" )
  ferase( (temp_Datei ) )

  dbcommitall()
  UNLOCK all

  gedruckt:=.t.
  Rechnung("0",.t.) // ohne Abbuchen, aber als Storno
  Rechnung("0",,,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
  BeistellTeilListe(,,.t.) // auch hier, da BT zur�ck gebucht werden

enddo

// neu: 28.11.11
if gedruckt
  close data
  AufBestand()
endif

close data
ferase( Temp_Datei )

RETURN
/* EOP KStornoRechnung */



/*
* aktualisert die Posten aus Auftrag -> in Aufpost und Artikel
*
* Parameter: KonsigLSNr -> aktuelle LS Nr
*            Storno -> .t. falls Storno LS, Feld kann auch leer sein,
*            dann kein Storno
* */
PROCEDURE KonsigRueckschreiben(KonsigLSNr,Storno)
LOCAL Merk_Order,warausText
LOCAL wasLocked

  /** Storno LS */
  if valtype(Storno)=="U"
    storno:=.f.
  endif

  if ! open( "Konsig")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  SELECT AufPost
  Merk_Order:=IndexOrd()
  AUFPOST->(OrdSetFocus(5)) // AbPostNr

  SELECT Auftrag
  go top
  do while .not. eof()
    IF AUFTRAG->gelief<>0

      // 11.4.2018: Verpackung und Beistellteile werden nicht abgebucht
      if alltrim(AUFTRAG->tempStr) <> "B" .and. len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
        // alle normalen Artikel, und �bernommene Fracht Artikel

        // seit 31.5.2013 nheme ABPostNr

        /** Auftragsposten ruckschreiben */
        SELECT AufPost
        AUFPOST->(dbseek( AUFTRAG->ABPostNr ))

        // rueckschreiben
        if ! AUFPOST->(eof()) .and. REC_LOCK(0)
          REPLACE AUFPOST->GeliefGes WITH AUFPOST->GeliefGes+AUFTRAG->Gelief
          REPLACE AUFPOST->Gelief WITH 0
        else
          if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE
            email(MY_EMAIL,"K-Lager Zuweisungs Problem - Stufe 2","Bei AB:"+AUFAUS->AufNr+" Art:"+;
              AUFTRAG->ArtNr+" Menge:"+str(AUFTRAG->Gelief))
          endif
        endif
        dbcommit()
        UNLOCK

        /** Artikel ruckschreiben */
        if len(alltrim(AUFTRAG->ArtNr)) > FRACHT_LAENGE // Fracht wird nicht abgebucht

          ARTIKEL->(dbseek(AUFTRAG->ArtNr))
          SELECT Artikel
          if ARTIKEL->(eof())
            Error(ACHTUNG+"Artikel "+AUFTRAG->ArtNr+" nicht gefunden.|Wurde nicht abgebucht !!!"+;
              SCHWERER_FEHLER)
          else
            REC_LOCK(0)
            if storno
              warausText:=WARAUS_KLAG_STORNO_LS+KonsigLSNr+" "+WARAUS_AUFNR+AUFAUS->AufNr+" H:"+;
                AUFAUS->BestNr
            else
              warausText:=WARAUS_KLAG_LS+KonsigLSNr+" "+WARAUS_AUFNR+AUFAUS->AufNr+" H:"+;
                AUFAUS->BestNr
            endif
            aendArtKBest(AUFTRAG->Gelief,warausText)
            aendArtBest(AUFTRAG->Gelief*(-1),warausText)
            dbcommit()
            unlock
          endif // ! Fracht
        endif // ARTIKEL->eof()

      endif // ! FRACHT .or. Menge > 0
    endif // AUFTRAG->gelief <> 0

    /** Konsig Datei schreiben */
    // nur bei neuen LS, nicht bei Storno (<0)
    IF (!storno)
      // raus 11.4.2018: .and. ( AUFTRAG->gelief>0 .or. len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE)
      // jetzt auch mit Beistellteilen!
      select konsig
      add_rec(0)
      replace KONSIG->AufNr with AUFAUS->AufNr
      replace KONSIG->KundNr with AUFAUS->KundNr
      replace KONSIG->LiefNr with KonsigLSNr
      replace KONSIG->Liedat with getUser():date
      replace KONSIG->ArtNr with AUFTRAG->ArtNr
      replace KONSIG->Komm1 with AUFTRAG->Komm1
      replace KONSIG->Komm2 with AUFTRAG->Komm2
      replace KONSIG->Menge with AUFTRAG->Menge
      replace KONSIG->Preis with AUFTRAG->Preis
      replace KONSIG->Rabattgr with AUFTRAG->Rabattgr
      replace KONSIG->Rabatt with AUFTRAG->Rabatt
      replace KONSIG->KZ with AUFTRAG->KZ
      replace KONSIG->ME with AUFTRAG->ME
      replace KONSIG->PE with AUFTRAG->PE
      replace KONSIG->KW with AUFTRAG->KW
      REPLACE KONSIG->GeliefGes WITH AUFTRAG->Gelief
      // geandert am 15.7.2009
      // REPLACE KONSIG->Gelief WITH AUFTRAG->Gelief
      REPLACE KONSIG->Erl_Gruppe With AUFTRAG->Erl_Gruppe
      REPLACE KONSIG->Erl_Konto With AUFTRAG->Erl_Konto
      REPLACE KONSIG->Erl_Kz With AUFTRAG->Erl_Kz
      REPLACE KONSIG->GerVon With AUFTRAG->GerVon
      REPLACE KONSIG->GerBis With AUFTRAG->GerBis
      REPLACE KONSIG->AbPostNr With AUFTRAG->AbPostNr
      dbcommit()
      unlock
    endif

    select Auftrag
    skip
  enddo

  // seit 25.10.14 bei Storno Klager-AB wieder aktivieren, falls AB als erledigt markiert
  if Storno .and. AUFAUS->erledigt=="J"
    select Aufaus
    wasLocked:=isLocked()
    if wasLocked .or. rec_lock(5)
      replace AUFAUS->erledigt with " "
      dbcommit()
    endif
    if ! wasLocked
      dbunlock()
    endif
  endif

  SELECT AufPost
  AUFPOST->(OrdSetFocus(Merk_Order))

RETURN
/* EOP  */

/*
* wiederholt K-Lager LS Druck
*/
PROCEDURE KonsigLSwiederholen()
LOCAL KonsigLSNr:="foo"
LOCAL GetList:={},Ausgabe:="D",merkeDatum:=getUser():date

  cls
  Titel("Konsignationslager Lieferscheindruck wiederholen")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "Artikel", "Einheit" , "VersArt" ;
    ,"Konsig" ,"Spedit","Mat_Kz","Kunden","Land" )


    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select AufAus
  set relation to AUFAUS->versNr into versart
  select Auftrag
  set relation to AUFTRAG->Me into Einheit
  select Konsig
  KONSIG->(OrdSetFocus(2))

  do while ! empty(KonsigLSNr)
    @ 2,0 clear

    KonsigLSNr:=space(len(KONSIG->LiefNr))
    Message("Lieferscheinnr. eingeben.           @F12@=Hilfe         @ESC@=Ende")
    @ 2,10 say "Lieferschein Nr.:" get KonsigLSNr PICTURE "@9"
    read
    if ABBRUCH .or. empty(KonsigLSNr)
      loop
    endif

    /* Auswahl-Menu */
    setcolor(COLWIN)
    Fenster(5,16,13,57)
    @ 6,20 say 'Drucken als:'
    @ 8,20 say ' Lieferschein K'+alltrim(KonsigLSNr)
    Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
    @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/P) ' get Ausgabe Picture "!" valid Ausgabe $"DBP"
    read

    /* eingeloggter Benutzer best�tigen/�ndern */
    // do while ! Login_change(12,20,"Sachbearbeiter: ")
    // enddo
    setcolor(COLNOR)

    // rechsshift
    KonsigLSNr:=right("     "+alltrim(KonsigLSNr),len(KONSIG->LiefNr),5)
    KONSIG->(dbseek(KonsigLSNr))

    if ! ABBRUCH .and. ! KONSIG->(eof())
      // kopiere posten
      merkeDatum:=KONSIG->LieDat
      AUFAUS->(dbseek(KONSIG->AufNr))
      select Auftrag
      zap
      do while KONSIG->LiefNr==KonsigLSNr .and. ! KONSIG->(eof())
        //	if KONSIG->GeliefGes > 0
        select Auftrag
        add_rec(0)
        replace AUFTRAG->ArtNr with KONSIG->ArtNr
        replace AUFTRAG->Komm1 with KONSIG->Komm1
        replace AUFTRAG->Komm2 with KONSIG->Komm2
        replace AUFTRAG->Menge with KONSIG->Menge
        replace AUFTRAG->Preis with KONSIG->Preis
        replace AUFTRAG->Rabattgr with KONSIG->Rabattgr
        replace AUFTRAG->Rabatt with KONSIG->Rabatt
        replace AUFTRAG->KZ with KONSIG->KZ
        // geandert am 15.7.2009
        // replace AUFTRAG->Gelief with KONSIG->Gelief
        replace AUFTRAG->Gelief with KONSIG->GeliefGes
        replace AUFTRAG->GeliefGes with KONSIG->GeliefGes
        replace AUFTRAG->ME with KONSIG->ME
        replace AUFTRAG->PE with KONSIG->PE
        replace AUFTRAG->AufNr with KONSIG->AufNr
        REPLACE AUFTRAG->Erl_Gruppe With KONSIG->Erl_Gruppe
        REPLACE AUFTRAG->Erl_Konto With KONSIG->Erl_Konto
        REPLACE AUFTRAG->Erl_Kz With KONSIG->Erl_Kz
        REPLACE AUFTRAG->GerVon With KONSIG->GerVon
        REPLACE AUFTRAG->GerBis With KONSIG->GerBis
        REPLACE AUFTRAG->AbPostNr With KONSIG->AbPostNr
        //	endif
        select Konsig
        dbskip()
      enddo

      // drucken
      KonsignationsLieferschein(KonsigLSNr,.f.,Ausgabe,merkeDatum)
    endif
  enddo

  cls
  close data

RETURN
/* EOP KonsigLSwiederholen */

/* 
*  freigeben von K-Lager Rechnungen
*/
PROCEDURE KonsigSammelRechnung
LOCAL M_KundNr:=".",M_ArtNr:="."
LOCAL Taste, GetList:={},teilLieferung:=0,okay,gedruckt:=.f.
LOCAL Entnahmeliste,datVon:=ctod('  .  .  '),datBis:=ctod('  .  .  ')
LOCAL tempVon,tempBis,merkAufNr, bereitsBearbeitet:=.f.
LOCAL DateiName
LOCAL paletten:=HB_ATokens( getProperty("Miki.palette.kostenfrei.innerdeutsch.artnr","") , ":" )

  cls
  Titel("Konsignations-Lager Sammelrechnung drucken")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "ZahlKond" , "Text_Kz" ,"Konsig";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" ,"Land";
    ,"Rabatt" ,"WarAus" , "AvPost","Spedit","Mat_Kz","KundSped";
    ,"Kunden" , "RechAus" , "RechPost","Erl_Grup","KostenSt","EMail")

    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  /* Relationen setzen */

  // removed 20090404
  // select Auftrag
  // set relation to AUFTRAG->AufNr into AUFAUS

  // added 20141112
  // select Auftrag
  // set relation to AUFTRAG->ArtNr into

  select RechPost
  set relation to RECHPOST->Me into Einheit
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  /** K-Lager bisher nur Deutsch */
  selLandBySprache(DEUTSCH)

  do while ! empty(M_KundNr)
    @ 1,0 clear
    bereitsBearbeitet:=.f.

    M_KundNr:=space(len(KUNDEN->KundNr))
    Message("Kundennummer eingeben.           @F12@=Hilfe")
    @ 2,10 say "Kund.Nr......:" get M_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif

    Entnahmeliste:=space(5)
    @ 2,0 clear
    @ 2,0 say "Kund.Nr.: "+KdOut(KUNDEN->KundNr)
    @ 2,22 say KUNDEN->KurzNAme

    @ 3,0 say "Entnahmeliste:" get EntnahmeListe // valid .not. empty(Entnahmeliste)
    @ 3,22 say "von" get DatVon valid .not. empty(DatVon)
    @ 3,35 say "bis" get DatBis valid checkSameYear( DatVon, DatBis ) .or. lastkey() == K_UP
    read
    if ABBRUCH
      loop
    endif
    tempVon:=dtoc(DatVon)
    tempBis:=dtoc(DatBis)
    @ 3,0 say "Entnahmeliste: "+EntnahmeListe
    @ 3,22 say "von " + tempVon
    @ 3,35 say "bis " + tempBis

    Select Konsig
    KONSIG->(OrdSetFocus(3)) // nach Kundnr+Anr

    /* Auftragsposten kopieren */
    Message("Liste wird erstellt.  Bitte warten...")
    select Auftrag
    zap
    M_ArtNr:="."
    merkAufNr:=nil
    select Konsig
    seek M_KundNr

    /* alle passenden Posten kopieren */
    do while KONSIG->KundNr==M_KundNr .and. ! eof()
      if len(alltrim(KONSIG->ArtNr)) > FRACHT_LAENGE .and. KONSIG->Berechnet<KONSIG->GeliefGes
        select Auftrag

        // merke passenden 1. Auftrag, sehr unschoen!
        if valtype(merkAufNr)=="U" .and. ! empty(KONSIG->AufNr)
          merkAufNr:=KONSIG->AufNr
        endif

        // fasse gleiche Artikel zusammen -> Achtung: ABPostNr wird vom 1. genommen :(
        if KONSIG->ArtNr<>M_ArtNr
          add_rec(0)
          overwrite("Konsig",.t.)
          replace AUFTRAG->GeliefGes with KONSIG->Geliefges-KONSIG->Berechnet

          // kopiere HonselNr
          ARTIKEL->(dbseek(AUFTRAG->ArtNr))
          // @ 10,20 say AUFTRAG->ArtNr
          replace AUFTRAG->TempStr with ARTIKEL->HartNr

          // seit 13.2.14: nehme aktuellen VK aus Artikel
          replace AUFTRAG->Preis WITH ARTIKEL->Preis1

        else
          replace AUFTRAG->GeliefGes with AUFTRAG->GeliefGes+KONSIG->GeliefGes-KONSIG->Berechnet
          replace AUFTRAG->Gelief with AUFTRAG->Gelief+KONSIG->Gelief
          // nehme immer letzen Rabatt
          replace AUFTRAG->Rabatt with KONSIG->Rabatt
          replace AUFTRAG->RabattGr with KONSIG->RabattGr
        endif
        M_ArtNr:=KONSIG->ArtNr
        select Konsig
        if KONSIG->Gelief>0
          bereitsBearbeitet:=.t.
          if REC_LOCK(0)
            REPLACE KONSIG->Gelief WITH 0 // Eingabe nicht mehr merken
          endif
          dbcommit()
          dbunlock()
        endif

      endif
      skip
    enddo

    if empty(merkAufNr)
      Error(ACHTUNG+" kein Auftrag fur Kunden:"+M_KundNr+" vorhanden.",.t.)
      loop
    endif
    AUFAUS->(dbseek(merkAufNr))

    if bereitsBearbeitet
      Error(ACHTUNG+"Sammelrechnung enth�lt gespeicherte Werte."+;
        "|         Bitte pr�fen!",.t.)
    endif

    // Verpackungen/Fracht kopieren -> sollen ans Ende
    M_ArtNr:="."
    select Konsig
    seek M_KundNr
    /* alle passenden Posten kopieren */
    do while KONSIG->KundNr==M_KundNr .and. ! eof()
      if len(alltrim(KONSIG->ArtNr)) <= FRACHT_LAENGE ;
        .and. KONSIG->Berechnet < KONSIG->GeliefGes .and. ;
        substr(KONSIG->ArtNr,1,1)<>'$'
        select Auftrag
        // neuer Artikel?
        if KONSIG->ArtNr<>M_ArtNr
          add_rec(0)
          overwrite("Konsig",.t.)
          replace AUFTRAG->GeliefGes with KONSIG->Geliefges - KONSIG->Berechnet
          replace AUFTRAG->komm3 with "LS: "+KONSIG->LiefNr

          // schreibe max. HonselNr -> Fracht ans Ende
          replace AUFTRAG->TempStr with MAX_HART_NR

          // seit 13.2.14: nehme aktuellen VK aus Artikel
          // seit 7.3.16: Ausnahme bei Paletten und innerdeutscher Lieferung, dort ohne Preis
          ARTIKEL->(dbseek(AUFTRAG->ArtNr))
          if AUFAUS->EG == "D" .and. aContains( paletten , alltrim(AUFTRAG->ArtNr))
            replace AUFTRAG->Preis WITH 0
          else
            replace AUFTRAG->Preis WITH ARTIKEL->Preis1
          endif

        else
          replace AUFTRAG->GeliefGes with AUFTRAG->GeliefGes;
            + KONSIG->GeliefGes - KONSIG->Berechnet
          if len(trim(AUFTRAG->komm3)) < 34
            replace AUFTRAG->komm3 with trim(AUFTRAG->komm3)+" "+KONSIG->LiefNr
          else
            replace AUFTRAG->komm4 with trim(AUFTRAG->komm4)+" "+KONSIG->LiefNr
          endif
        endif
        // zu lieferende Menge immer komplett �bernehmen
        replace AUFTRAG->Gelief with AUFTRAG->GeliefGes
        M_ArtNr:=KONSIG->ArtNr
        select Konsig
        if KONSIG->Gelief>0
          if REC_LOCK(0)
            REPLACE KONSIG->Gelief WITH 0 // Eingabe nicht mehr merken
          endif
          dbcommit()
          dbunlock()
        endif
      endif
      skip
    enddo

    /*** Posten editieren **/
    Taste:=SaRech_Bauch()

    /** ueberpruefe ob Posten ausgewaehlt ! */
    select Auftrag
    locate for AUFTRAG->gelief <> 0
    if ! eof()
      go top

      setcolor(COLWIN)
      Fenster(5,16,13,57)
      @ 6,20 say 'Drucken als:'
      @ 8,20 say "K-Lager Rechnung"
      okay:="J"
      @ 10,20 say "Okay:" get okay picture "!" valid okay $ "JN"
      read

      /* eingeloggter Benutzer best�tigen/�ndern */
      // do while ! Login_change(12,20,"Sachbearbeiter: ")
      // enddo
      setcolor(COLNOR)
      if lastkey()==K_ESC .or. okay<>"J"
        if Message("�nderungen speichern ? ( J / N ) ","JN","J")=="N" .or. ABBRUCH
          loop
        else
          // rueckschreiben der Menge nach Konsig
          SELECT Auftrag
          go top
          do while .not. AUFTRAG->(eof())
            if AUFTRAG->Gelief > 0
              select Konsig
              KONSIG->(OrdSetFocus(3)) // KundNr+Art.Nr
              KONSIG->(dbseek(KUNDEN->KundNr+AUFTRAG->ArtNr))
              if KONSIG->(eof())
                // neu eingegebene Fracht & Kommentare
                if trim(AUFTRAG->ArtNr)<>"*"
                  // duerfte nicht passieren
                  Error(ACHTUNG+" Artikel:"+AUFTRAG->ArtNr+;
                    " konnte nicht gespeichert werden!",.t.,"root")
                endif // ANr<>"*"
              else // KONSIG->(eof())

                // suche naechsten offenen Auftrag des Kundens/Artikels
                do while ! KONSIG->(eof()) .and. KONSIG->KundNr==KUNDEN->KundNr ;
                  .and. KONSIG->ArtNr==AUFTRAG->ArtNr .and. AUFTRAG->Gelief>0
                  if KONSIG->Berechnet < KONSIG->GeliefGes
                    teilLieferung:=Min(KONSIG->GeliefGes-KONSIG->Berechnet, AUFTRAG->Gelief)
                    if REC_LOCK(5)
                      REPLACE KONSIG->Gelief WITH KONSIG->Gelief + teilLieferung // bis 20.1.2016
                      replace AUFTRAG->Gelief with AUFTRAG->Gelief-teilLieferung
                    endif
                    dbcommit()
                    unlock
                  endif
                  dbskip()
                enddo
                select Auftrag
                if AUFTRAG->Gelief > 0
                  troubleEmail("Artikel:" + KONSIG->ArtNr + ;
                    " konnte keinem Konsig-Eintrag zugeordnet werden.  Rest: " + str( AUFTRAG->Gelief ) )
                endif
              endif

            endif // gelief>0
            dbskip()
          enddo
        endif
        loop
      endif

      // sortiere nach Honselnr
      select auftrag
      index on AUFTRAG->TempStr+AUFTRAG->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE

      /*** Posten r�ckschreiben ***/
      auf_rech("K") // schreibe akt. Satz aus Aufaus->Rechaus

      select Auftrag
      AUFTRAG->(OrdDestroy(TEMP_INDEX))
      AUFTRAG->(OrdSetFocus(0))

      // schreibe Entnahmeliste & Datumszeitraum in Kopfdaten
      select RECHAUS
      // if rec_lock(5) Satz ist bereits gelockt
      replace RECHAUS->BestNr with ENTNAHME_LISTE+" "+Entnahmeliste
      replace RECHAUS->BestKonto with tempVon+" - "+tempBis

      gedruckt:=.t.
      // rechnDeckblatt(Ausgabe)
      dateiName:=Rechnung("1") // mit Abbuchen, da 1. Mal
      Rechnung("2",,,.t.) // ohne Abbuchen, mit Posten , Kopie f�r Ablage
      Rechnung("3",,,.t.) // ohne Abbuchen, ohne Posten , Kopie f�r Buchhaltung
      BeistellTeilListe() // jetzt immer, jojo 28.9.98

      // Email zu Rechnung erst nach Beistellteilliste, da diese automat. angeh�ngt wird
      if ! empty( dateiName )
        sendEmails( EMAIL_RECHNUNG , dateiName )
      endif

    endif // ! eof

    // endif // Posten speichern

    dbcommitall()
    unlock all

  enddo

  // neu: 28.11.11
  if gedruckt
    close data
    AufBestand()
  endif

  close data
RETURN
/* EOP */

/* Function SammelRech_Bauch  ****************************************
*
* Eingabe des SamellRechn.Bauches, Editor-definitionen K-Lager
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
STATIC FUNCTION SaRech_Bauch
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  select Auftrag

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || SaRechNeuSatz() }
  aKopf[EDIT_EXTRA_FKT]:={ { "S"," @S@uchen ", { || SaRech_Such(aFelder,aKopf)} }}
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Auf_Text()}
  aKopf[EDIT_GESPERRT]:="LEZ" // l�schen,einf�gen,Kopf

  aKopf[EDIT_ZEIGE_ANZAHL]:={ || AUFTRAG->gelief<>0 }

  aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispEditorSumme("AUFAUS","AUFTRAG->Gelief",50) }
  aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
  aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen

  aadd(aKopf[EDIT_EXTRA_FKT],{ "L","@L@�schen ", { || KonsistenzLoesch() } } )

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_NAME_GET]:="Fracht"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_BEFORE]:={ || alltrim(AUFTRAG->ArtNr)$"*" .or. empty(AUFTRAG->ArtNr) }
  // aSpalte[EDIT_AFTER]:={ |oGet| ( trim(oGet:Buffer)$"*" .or. check(oGet,"Artikel",.f.)) .and. RechArtNrNach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_AFTER]:={ |oGet| trim(oGet:Buffer)$"*" } // nur Text erlaubt
  aSpalte[EDIT_MESSAGE]:="* f�r Kommentar eingeben.     @ESC@=Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || trim(AUFTRAG->ArtNr) $ "*" }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="if(TempStr=='"+ MAX_HART_NR + "', replicate(' ',20),TempStr)" // ist "HartNr"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_MESSAGE]:="Text eingeben"
  aSpalte[EDIT_POS_X]:=11
  aSpalte[EDIT_BEFORE]:={ || alltrim(AUFTRAG->ArtNr)="*" }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm2"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_POS_X]:=11
  aSpalte[EDIT_MESSAGE]:="Text eingeben"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_BEFORE]:={ || alltrim(AUFTRAG->ArtNr)="*" }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Geliefges"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MASKE]:="99999"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Geliefert
  aSpalte[EDIT_NAME]:="Gelief"
  aSpalte[EDIT_MASKE]:="99999"
  aSpalte[EDIT_MESSAGE]:="Entnahme-Menge eingeben."
  // aSpalte[EDIT_MESSAGE]:="Lieferung eingeben.              @F5@=Rabatt �ndern"
  // aSpalte[EDIT_BEFORE]:={ || SetKey( K_F5 , {|| F5_Rabatt() } ),.t. }
  aSpalte[EDIT_AFTER]:={ |oGet| SaRechFreiMenge(oGet,aKopf ) }

  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile


  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis
  aSpalte[EDIT_NAME]:="Preis"
  aSpalte[EDIT_TITEL]:="Preis"
  aSpalte[EDIT_MESSAGE]:="Preis (Euro) eingeben."
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // Rabatt
  aSpalte[EDIT_NAME]:="Rabatt"
  aSpalte[EDIT_TITEL]:="Rabatt"
  // aSpalte[EDIT_POS_X]:=3 // um 3 nach rechts verschoben
  aSpalte[EDIT_MESSAGE]:="Rabatt eingeben."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  aSpalte[EDIT_NAME]:="Kw"
  aSpalte[EDIT_TITEL]:="Woche"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  // Info: seit 7.5.2013 bei AB kein Freitext mehr m�glich, sollte also leer sein, au�er bei alten
  aSpalte[EDIT_NAME]:="KW_Text"
  aSpalte[EDIT_TITEL]:="LieferText"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_X]:=-11 // um 11 nach links verschoben
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

RETURN( Edit(aFelder,aKopf) )
/* EOF SaRech_Bauch */


/* Function SaRechFreiMenge  **********************************
*
* wird nach Eingabe der Menge bei K-Lager SammelRechnung ausgefuehrt
* keine Ueberlieferung bei K-Lager
*/
FUNCTION SaRechFreiMenge(oGet,aKopf)

  if oGet:changed

    // Fracht darf �berliefert werden
    if LEN(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
      SetKey( K_F5 , NIL)
      return .t.
    endif

    if AUFTRAG->Gelief > AUFTRAG->GeliefGes
      Error(ACHTUNG+" K-Lager Auftrag kann nicht ueberliefert werden.",.t.)
      return .f.
    endif
    if AUFTRAG->Gelief < 0
      Error(ACHTUNG+" K-Lager Storno nicht m�glich.|Bitte anderen Menu Punkt verwenden",.t.)
      return .f.
    endif
    dispEditorSumme("AUFAUS","AUFTRAG->Gelief",50)

    if aKopf[EDIT_ZEIGE_ANZAHL]<>NIL
      zeigeAnzahl(aKopf)
    endif

  endif
  SetKey( K_F5 , NIL)
RETURN(.t.)
/* EOF RechFreiMenge */

/* 
*  stornieren von K-Lager Lieferscheinen
*/
PROCEDURE KonsigLSStorno()
LOCAL KonsigLSNr:="foo",NeuKonsigLSNr,okay
LOCAL GetList:={}
  cls
  Titel("Konsignationslager Lieferschein stornieren")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "Artikel", "Einheit" , "VersArt" ;
    ,"Konsig" ,"Spedit","Mat_Kz","AufPost","Land";
    ,"Kunden" )


    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select Auftrag
  set relation to AUFTRAG->Me into Einheit
  select AufAus
  set relation to AUFAUS->versNr into versart
  select Konsig
  KONSIG->(OrdSetFocus(2))

  do while ! empty(KonsigLSNr)
    @ 2,0 clear

    KonsigLSNr:=space(len(KONSIG->LiefNr))
    Message("Lieferscheinnr. eingeben.           @F12@=Hilfe         @ESC@=Ende")
    @ 2,10 say "Lieferschein Nr.:  K" get KonsigLSNr PICTURE "@9"
    read
    if ABBRUCH .or. empty(KonsigLSNr)
      loop
    endif

    // rechsshift
    KonsigLSNr:=right("     "+alltrim(KonsigLSNr),len(KONSIG->LiefNr),5)
    KONSIG->(dbseek(KonsigLSNr))

    if ! KONSIG->(eof())

      // pruefe ob bereits berechnet
      do while KONSIG->LiefNr==KonsigLSNr .and. ! KONSIG->(eof()) .and. KONSIG->Berechnet == 0
        skip
      enddo
      if KONSIG->LiefNr==KonsigLSNr .and. ! KONSIG->(eof()) .and. KONSIG->Berechnet <> 0
        Error(ACHTUNG+" Rechnung bereits gedruckt|Lieferschein kann nicht storniert werden.",.t.)
        loop
      endif
      KONSIG->(dbseek(KonsigLSNr))

      setcolor(COLWIN)
      Fenster(7,16,13,57)
      @ 8,20 say 'Drucken als:'
      @ 10,20 say "Storno-Lieferschein"
      okay:="J"
      @ 12,20 say "Okay:" get okay picture "!" valid okay $ "JN"
      read
      // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
      // do while ! Login_change(12,20,"Sachbearbeiter: ")
      // enddo
      setcolor(COLNOR)
      @ 7,0 clear
      if lastkey()==K_ESC .or. okay<>"J"
        loop
      endif

      // kopiere posten
      AUFAUS->(dbseek(KONSIG->AufNr))
      select Auftrag
      zap
      do while KONSIG->LiefNr==KonsigLSNr .and. ! KONSIG->(eof())
        select Auftrag
        add_rec(0)
        replace AUFTRAG->ArtNr with KONSIG->ArtNr
        replace AUFTRAG->Komm1 with KONSIG->Komm1
        replace AUFTRAG->Komm2 with KONSIG->Komm2
        replace AUFTRAG->Menge with KONSIG->Menge
        replace AUFTRAG->Preis with KONSIG->Preis
        replace AUFTRAG->KW with KONSIG->KW
        replace AUFTRAG->Rabattgr with KONSIG->Rabattgr
        replace AUFTRAG->Rabatt with KONSIG->Rabatt
        replace AUFTRAG->KZ with KONSIG->KZ
        // geandert am 15.7.2009
        // replace AUFTRAG->Gelief with KONSIG->Gelief*(-1)
        replace AUFTRAG->Gelief with KONSIG->GeliefGes*(-1)
        replace AUFTRAG->GeliefGes with KONSIG->GeliefGes
        replace AUFTRAG->ME with KONSIG->ME
        replace AUFTRAG->PE with KONSIG->PE
        replace AUFTRAG->AufNr with KONSIG->AufNr
        REPLACE AUFTRAG->Erl_Gruppe With KONSIG->Erl_Gruppe
        REPLACE AUFTRAG->Erl_Konto With KONSIG->Erl_Konto
        REPLACE AUFTRAG->Erl_Kz With KONSIG->Erl_Kz
        REPLACE AUFTRAG->AbPostNr With KONSIG->AbPostNr
        select Konsig
        if rec_lock(0)
          delete
          // replace KONSIG->Berechnet with KONSIG->GeliefGes
          dbcommit()
          dbunlock()
        endif

        dbskip()
      enddo

      // drucken mit neuer LsNr
      NeuKonsigLSNr:=KonsignationsLieferschein(,.t.)
      KonsigRueckschreiben(NeuKonsigLSNr,.t.)

    endif
    select Konsig
  enddo

  cls
  close data

RETURN
/* EOP KonsigLSStorno */

/**
 * Suche nach Artikel oder Honsel Nr in aktuellen Posten
  * ACHTUNG: wir haben nicht die aktuelle Zeile am Anfang, d.h wir
  * springen bei einem Resize auf den 1. Satz
  */
Function SaRech_Such(aFelder,aKopf)
LOCAL tempSuche,numSuche
LOCAL laenge,merk_order,Zeile:=aKopf[EDIT_START_Y]
LOCAL merk_satz:=recno()
LOCAL GetList:={}
  _thread static suche

  if suche==NIL
    suche:=space(19)
  endif

  do while ! ABBRUCH

    @ maxrow(),00 clear
    @ maxrow(),00 say "Suche nach Honsel-Nr.:" GET suche
    QQout(space(10)+"ESC = Ende")

    // read now - with exit on resize events
    ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_GTEVENT)
    if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
      Zeile:=resizeBSAus(aFelder,AKopf,Zeile)
    endif
    GetList:={} ; ( GetList )

    if !ABBRUCH
      tempSuche:=alltrim(suche)
      laenge:=len(tempSuche)
      // Art.Nr?
      locate for left(AUFTRAG->ArtNr,laenge)==tempSuche
      if AUFTRAG->(eof())
        // suche HonselNr
        select Artikel
        Merk_Order:=IndexOrd()
        ARTIKEL->(OrdSetFocus(2)) // HonselNr
        ARTIKEL->(dbseek(tempSuche))
        ARTIKEL->(OrdSetFocus(merk_order))
        if ARTIKEL->(EOF()) // suche nur HonselNr numerisch
          Message("Suche Honsel-Nr. numerisch                 @Bitte warten@")
          numSuche:=FaxNr(tempSuche)
          laenge:=len(numSuche)
          loca for faxnr(ARTIKEL->Hartnr)==numSuche
        endif
        select Auftrag

        if ! ARTIKEL->(eof())
          locate for AUFTRAG->ArtNr==ARTIKEL->ArtNr
        endif

      endif
      if AUFTRAG->(eof())
        Beep()
      else
        PageOut(aFelder,aKopf)
        return aKopf[EDIT_START_Y]
      endif
    endif

  enddo

  go (merk_satz)
  PageOut(aFelder,aKopf)

return zeile
/** EOP SaRech_Such */

/* Procedure Rech_Storno ******************************************
*
*  stornieren von Rechnungen
*/
PROCEDURE Rech_Storno()
LOCAL orgRechNr:="foo",NeuRechNr,okay,gedruckt:=.f.
LOCAL GetList:={},merkGelReNr
  cls
  Titel("Rechnungen stornieren")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "ZahlKond" , "Text_Kz" ,"Aufpost";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "KundSped";
    ,"Rabatt" ,"WarAus" , "AvPost","Spedit","Mat_Kz","Konsig";
    ,"Kunden" , "RechAus" , "RechPost","Erl_Grup","KostenSt","Land","EMail")

    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  select RechPost
  set relation to RECHPOST->ME into Einheit
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  select rechaus

  do while ! empty(orgRechNr)
    @ 2,0 clear

    // nur Rechnungen k�nnen storniert werden
    select Rechaus
    set filter to RECHAUS->AufArt$"R"

    orgRechNr:=space(len(RECHAUS->RechNr))
    Message("Rechnungs-Nr. eingeben.           @F12@=Hilfe         @ESC@=Ende")
    @ 2,10 say "Rechnung Nr.:" get orgRechNr PICTURE "@9"
    read
    if ABBRUCH .or. empty(orgRechNr)
      loop
    endif

    set filter to
    RECHAUS->(dbseek(orgRechNr))

    if ! RECHAUS->(eof())

      IF RECHAUS->Aufart=="K"
        Error(ACHTUNG+" K-Lager Rechnung kann hier nicht storniert werden.|"+;
          "          Bitte anderen Menu-Punkt verwenden.",.t.)
        loop
      endif

      IF ! RECHAUS->Aufart$"RV"
        Error(ACHTUNG+" Nur Rechnungen k�nnen hier storniert werden.",.t.)
        loop
      endif

      // pruefe ob bereits storniert
      if ! empty(RECHAUS->Storno_Nr)
        Error(ACHTUNG+" Rechnung bereits storniert.  Siehe Storno Rechnung Nr.:"+;
          RECHAUS->Storno_Nr,.t.)
        loop
      endif

      /** w�hle Sprache je nach Empf�nger */
      selLandBySprache(RECHAUS->Sprache)

      // Rechnung kopieren & anzeigen
      RECHPOST->(dbseek(RECHAUS->RechNr))
      select Auftrag
      zap
      do while RECHPOST->RechNr==orgRechNr .and. ! RECHPOST->(eof())
        select Auftrag
        add_rec(0)
        replace AUFTRAG->ArtNr with RECHPOST->ArtNr
        replace AUFTRAG->ArtNr with RECHPOST->ArtNr
        replace AUFTRAG->Komm1 with RECHPOST->Komm1
        replace AUFTRAG->Komm2 with RECHPOST->Komm2
        replace AUFTRAG->E_Komm1 with RECHPOST->E_Komm1
        replace AUFTRAG->E_Komm2 with RECHPOST->E_Komm2
        replace AUFTRAG->Menge with RECHPOST->Menge
        replace AUFTRAG->Preis with RECHPOST->Preis
        replace AUFTRAG->KW with RECHPOST->KW
        replace AUFTRAG->Rabatt with RECHPOST->Rabatt
        replace AUFTRAG->Rabattgr with RECHPOST->Rabattgr
        replace AUFTRAG->KZ with RECHPOST->KZ
        replace AUFTRAG->Gelief with RECHPOST->Gelief
        replace AUFTRAG->GeliefGes with RECHPOST->GeliefGes
        replace AUFTRAG->ME with RECHPOST->ME
        replace AUFTRAG->PE with RECHPOST->PE
        replace AUFTRAG->AufNr with RECHPOST->AufNr
        REPLACE AUFTRAG->Erl_Gruppe With RECHPOST->Erl_Gruppe
        REPLACE AUFTRAG->Erl_Konto With RECHPOST->Erl_Konto
        REPLACE AUFTRAG->Erl_Kz With RECHPOST->Erl_Kz
        REPLACE AUFTRAG->ABPostNr With RECHPOST->AbPostNr
        select RECHPOST

        dbskip()
      enddo

      if AUFTRAG->(reccount())>0
        @ 2,38 say RECHAUS->KundNr+" "+RECHAUS->Kurzname
        Auf_Bauch("S",.t.)
      endif

      okay:=" "
      Message("Drucken als Storno-Rechnung? (@J@/@N@)")
      setcolor(COLWIN)
      Fenster(7,16,13,57)
      @ 8,20 say 'Drucken als:'
      @ 10,20 say "Storno-Rechnung"
      @ 12,20 say "Okay:" get okay picture "!" valid okay $ "JN"
      read
      // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
      // do while ! Login_change(12,20,"Sachbearbeiter: ")
      // enddo
      setcolor(COLNOR)
      @ 7,0 clear
      if lastkey()==K_ESC .or. okay<>"J"
        loop
      endif

      // kopiere posten
      AUFAUS->(dbseek(RECHAUS->AufNr))

      // geht nur, wenn AB noch nicht geloescht -> flicken!
      if AUFAUS->(eof())
        Error(ACHTUNG+" Auftrag:"+RECHAUS->AufNr+" bereits geloescht.|Rechnung kann nicht "+;
          "storniert werden",.t.)
        loop
      endif

      // Auftrag wieder herstellen, falls bereits erledigt
      if AUFAUS->erledigt $ "JO"
        aufRecall()

        if AUFAUS->warKV $ "J" // Kostenvoranschlag KZ wieder �ndern
          select AufAus
          rec_lock(0)
          REPLACE AUFAUS->AufArt With "V"
        endif
      endif


      // Storno Rechnung negativ -> Menge * -1
      select Auftrag
      replace all AUFTRAG->Menge with AUFTRAG->Menge*(-1),;
        AUFTRAG->Gelief with AUFTRAG->Gelief*(-1),;
        AUFTRAG->GeliefGes with AUFTRAG->GeliefGes*(-1)

      auf_rech("S") // schreibe akt. Satz aus Aufaus->Rechaus
      // ge�ndert am 4.12.2017
      // auf_rech(AUFAUS->Aufart) // schreibe akt. Satz aus Aufaus->Rechaus
      select RechAus
      REPLACE RECHAUS->Storno_Nr with orgRechNr
      // hier kein unlock ! , da nach Druck noch Nebenkosten etc. nachgetragen werden !

      gedruckt:=.t.

      KundenDatenBlatt( "D" , "R" )

      rechnDeckblatt("D")
      Rechnung("1") // mit Abbuchen, da 1. Mal
      Rechnung("0",,,.t.) // ohne Abbuchen, Kopie f�r Buchhaltung
      BeistellTeilListe() // auch hier, da BT zur�ck gebucht werden

      // schreibe Storno_Nr in ursp. RECHAUS Datensatz
      NeuRechNr:=RECHAUS->RechNr
      select RechAus
      RECHAUS->(dbseek(orgRechNr))
      if rec_lock(0)
        REPLACE RECHAUS->Storno_Nr with neuRechNr
        if ! empty(RECHAUS->GelReNr) .or. ! empty(RECHAUS->GelNr) // l�sche zugeh. GBS
          merkGelReNr:=RECHAUS->GelReNr
          REPLACE RECHAUS->GelReNr with ""
          REPLACE RECHAUS->GelNr with ""
          REPLACE RECHAUS->GelEing with LEER_DAT
        endif
        dbcommit()
        dbunlock()
      endif

      // falls die stornierte eine GBS Rechnung war -> l�sche Verweis in Org.Rechnung
      if RECHAUS->GelKZ=="J"
        loca for RECHAUS->GelReNr==orgRechnr
        do while ! RECHAUS->(eof())
          rec_lock(0)
          replace RECHAUS->GelReNr with ""
          cont
        enddo
      endif

      // storniere & l�sche GBS Rechnung falls vorhanden
      if merkGelReNr<>NIL .and. ! empty(merkGelReNr)
        If Message("Zugeh�rige GBS Rechnung @"+merkGelReNr+"@ ebenfalls stornieren?","JN","J")=="J"
          keyboard merkGelReNr+chr(K_RETURN)
          merkGelReNr:=NIL
          loop
        endif
        merkGelReNr:=NIL
      endif

      // Falls bereits Intra.Stat. Meldung erfolgt und Warenwert > 5000 Euro -> Email
      if RECHAUS->IntraStat == "J" .and. RECHAUS->Netto >= 5000
        email(MAIN_EMAIL,"Intra.Stat. Rechnung wurde storniert",+;
          "Folgende Rechnung wurde bereits per xml-Datei an das stat.Bundesamt gemeldet.|"+;
          "Bitte evtl. manuell nachmelden.||"+;
          "Rech.Nr.: "+RECHAUS->RechNr+"|"+;
          "Kund.Nr.: "+RECHAUS->KundNr+" "+RECHAUS->KurzName+"|"+;
          "Netto   : "+str(RECHAUS->Netto) +" Euro" )
      endif

    endif
  enddo

  // neu: 28.11.11
  if gedruckt
    close data
    AufBestand()
  endif

  cls
  close data

RETURN
/* EOP Rech_Storno() */


/* Procedure HonselBestNr *****************************************
*
*/
PROCEDURE HonselBestNr()
LOCAL Taste:=0 , M_HonselNr,M_KundNr:="."
LOCAL GetList:={},count:=0
  if ! open("AufAus","Aufpost","Kunden","Artikel")
    close data
    Error(TRY_AGAIN)
    cls
    RETURN
  endif

  cls
  Titel("Honsel Bestellnummer kontrollieren")

  select AufPost
  AUFPOST->(OrdSetFocus(2))
  set relation to AUFPOST->AufNr into Aufaus,AUFPOST->ArtNr into Artikel

  set filter to AUFPOST->KundNr==KUNDEN->KundNr .and.;
    AUFPOST->AufArt$"K" .and. len(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE .and. AUFAUS->erledigt<>"J"
  // AUFPOST->Menge > AUFPOST->GeliefGes

  index on AUFAUS->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE

  M_KundNr:=space(len(KUNDEN->KundNr))
  do while ! ABBRUCH
    @ 1,0 clear

    Message("Kundennummer eingeben.           @F12@=Hilfe")
    @ 2,10 say "Kund.Nr......:" get M_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif

    @ 2,0 clear
    @ 2,0 say "Kund.Nr.: "+KdOut(KUNDEN->KundNr)
    @ 2,22 say KUNDEN->KurzNAme

    M_HonselNr:=space(len(AUFAUS->BestNr))
    Message("Bestellnummer eingeben.           @F12@=Hilfe")
    @ 5,0 say 'Bestell Nr.:'
    @ 5,13 get M_HonselNr picture '@K'
    read
    if ABBRUCH
      loop
    endif

    keyboard M_HonselNr
    Hilfe("HonselBestNr",getnew(),"M_HonselNr")

  enddo

  cls
  close data

return

/* Function SaRechNeuSatz()
*
* wird nach hinzuf�gen eines neuen Satzes ausgef�hrt
*/
FUNCTION SaRechNeuSatz
  replace AUFTRAG->TempStr with MAX_HART_NR
RETURN(.t.)

/* Procedure KGutschrift
*
*  erfassen von K-Lager Gutschrift
*
*/
PROCEDURE KGutschrift
LOCAL M_KundNr:=".",M_ArtNr:=".",M_AufNr:=""
LOCAL Taste, GetList:={},okay
LOCAL Entnahmeliste,datVon:=ctod('  .  .  '),datBis:=ctod('  .  .  ')
LOCAL tempVon,tempBis,best_kto:="",best_nr:=""
MEMVAR defAuftrArt
PRIVATE defAuftrArt:="N" // K-Lager Gutschrift

  cls
  Titel("Konsignations-Lager Gutschrift erfassen")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "ZahlKond" , "Text_Kz" ,"Konsig";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" ;
    ,"Rabatt" ,"WarAus" , "AvPost","Spedit","Mat_Kz","Land";
    ,"Kunden" , "RechAus" , "RechPost","Erl_Grup","KostenSt")


    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  /* Relationen setzen */

  select RechPost
  set relation to RECHPOST->Me into Einheit
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  do while ! empty(M_KundNr)
    @ 1,0 clear

    M_KundNr:=space(len(KUNDEN->KundNr))
    M_AufNr:=""
    Message("Kundennummer eingeben.           @F12@=Hilfe")
    @ 2,10 say "Kund.Nr......:" get M_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif

    Entnahmeliste:=space(5)
    @ 2,0 clear
    @ 2,0 say "Kund.Nr.: "+KdOut(KUNDEN->KundNr)
    @ 2,22 say KUNDEN->KurzNAme

    @ 3,0 say "Entnahmeliste:" get EntnahmeListe // valid .not. empty(Entnahmeliste)
    @ 3,22 say "von" get DatVon valid .not. empty(DatVon)
    @ 3,35 say "bis" get DatBis valid checkSameYear( DatVon, DatBis ) .or. lastkey() == K_UP
    read
    if ABBRUCH .or. empty(DatVon)
      loop
    endif
    tempVon:=dtoc(DatVon)
    tempBis:=dtoc(DatBis)
    @ 3,0 say "Entnahmeliste: "+EntnahmeListe
    @ 3,22 say "von " + tempVon
    @ 3,35 say "bis " + tempBis

    select Auftrag
    zap
    M_ArtNr:="."
    select Konsig
    seek M_KundNr

    /*** Posten editieren **/
    Taste:=KGut_Bauch()

    /** ueberpruefe ob Posten ausgewaehlt ! */
    select Auftrag
    locate for AUFTRAG->gelief <> 0
    if eof()
      loop
    endif

    go top

    setcolor(COLWIN)
    Fenster(5,16,13,57)
    @ 6,20 say 'Drucken als:'
    @ 8,20 say "K-Lager Gutschrift"
    okay:="J"
    @ 10,20 say "Okay:" get okay picture "!" valid okay $ "JN"
    read

    // /* eingeloggter Benutzer best�tigen/�ndern */
    // do while ! Login_change(12,20,"Sachbearbeiter: ")
    // enddo
    setcolor(COLNOR)
    if lastkey()==K_ESC .or. okay<>"J"
      loop
    endif

    best_nr:=ENTNAHME_LISTE+" "+Entnahmeliste
    best_kto:=tempVon+" - "+tempBis

    /* erzeuge neuen Auftrag / Gutschrift */
    M_AufNr:=hole("AufNr",WRITE,.t.)
    select AUFAUS
    add_rec(0)
    replace AUFAUS->AUFNr with M_AufNr
    replace AUFAUS->AufArt with "N"
    replace AUFAUS->BestKonto with best_kto
    replace AUFAUS->BestNr with best_nr
    replace AUFAUS->Aufdat WITH getUser():date
    replace AUFAUS->KundNr with KUNDEN->KundNr
    REPLACE AUFAUS->Name WITH KUNDEN->Name
    REPLACE AUFAUS->KurzName WITH KUNDEN->KurzName
    REPLACE AUFAUS->Partner WITH KUNDEN->Partner
    REPLACE AUFAUS->Strasse WITH KUNDEN->Strasse
    REPLACE AUFAUS->Zusatz WITH KUNDEN->Zusatz
    REPLACE AUFAUS->Plz WITH KUNDEN->PLZ
    REPLACE AUFAUS->Land WITH KUNDEN->Land
    REPLACE AUFAUS->Ort WITH KUNDEN->Ort
    REPLACE AUFAUS->R_KundNr WITH AUFAUS->KundNr
    REPLACE AUFAUS->R_Name WITH KUNDEN->Name
    REPLACE AUFAUS->R_Partner WITH KUNDEN->Partner
    REPLACE AUFAUS->R_Strasse WITH KUNDEN->Strasse
    REPLACE AUFAUS->R_Zusatz WITH KUNDEN->Zusatz
    REPLACE AUFAUS->R_Plz WITH KUNDEN->PLZ
    REPLACE AUFAUS->R_Land WITH KUNDEN->Land
    REPLACE AUFAUS->R_Ort WITH KUNDEN->Ort
    REPLACE AUFAUS->So_Rabatt WITH KUNDEN->So_Rabatt
    REPLACE AUFAUS->ZKNr WITH KUNDEN->ZKNr
    // REPLACE AUFAUS->VersNr WITH KUNDEN->VersNr
    REPLACE AUFAUS->MwSt_Kz WITH KUNDEN->MwSt_Kz
    MWST_KZ->(dbseek(KUNDEN->Mwst_Kz))
    REPLACE AUFAUS->MwSt WITH MWST_KZ->MwSt
    // REPLACE AUFAUS->LiefNr WITH KUNDEN->Lfd_Nr
    REPLACE AUFAUS->IdentNr WITH KUNDEN->IdentNr
    REPLACE AUFAUS->EG WITH KUNDEN->EG

    // sortiere nach Honselnr
    select auftrag
    replace all AUFTRAG->AufNr with AUFAUS->AufNr
    index on AUFTRAG->TempStr+AUFTRAG->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE

    /*** Posten r�ckschreiben ***/
    auf_rech("N") // schreibe akt. Satz aus Aufaus->Rechaus

    select Auftrag
    AUFTRAG->(OrdDestroy(TEMP_INDEX))
    AUFTRAG->(OrdSetFocus(0))
    // set index to FIXED: removed 10.1.2015

    // rueckschreiben der Menge nach Konsig
    SELECT Auftrag
    go top
    do while .not. AUFTRAG->(eof())
      select Konsig
      add_rec(0)
      replace KONSIG->AufNr with AUFAUS->AufNr
      replace KONSIG->Liedat with getUser():date
      replace KONSIG->ArtNr with AUFTRAG->ArtNr
      replace KONSIG->Komm1 with AUFTRAG->Komm1
      replace KONSIG->Komm2 with AUFTRAG->Komm2
      replace KONSIG->Menge with AUFTRAG->Menge
      // replace KONSIG->Gelief with AUFTRAG->Gelief
      replace KONSIG->GeliefGes with AUFTRAG->Gelief
      replace KONSIG->Preis with AUFTRAG->Preis
      replace KONSIG->Rabatt with AUFTRAG->Rabatt
      replace KONSIG->Rabattgr with AUFTRAG->Rabattgr
      replace KONSIG->KZ with AUFTRAG->KZ
      replace KONSIG->ME with AUFTRAG->ME
      replace KONSIG->PE with AUFTRAG->PE
      replace KONSIG->KW with AUFTRAG->KW
      REPLACE KONSIG->Erl_Gruppe With AUFTRAG->Erl_Gruppe
      REPLACE KONSIG->Erl_Konto With AUFTRAG->Erl_Konto
      REPLACE KONSIG->Erl_Kz With AUFTRAG->Erl_Kz
      REPLACE KONSIG->GerVon With AUFTRAG->GerVon
      REPLACE KONSIG->GerBis With AUFTRAG->GerBis
      REPLACE KONSIG->AbPostNr With AUFTRAG->ABPostNr
      REPLACE KONSIG->KundNr With KUNDEN->KundNr
      dbcommit()
      unlock

      // K-Lager Bestand in Artikel Stamm erh�hen
      select Artikel
      dbseek(AUFTRAG->ArtNr)
      if ! Rec_Lock(5)
        Error(ACHTUNG+" Artikel:"+AUFTRAG->ArtNr+;
          " K-Lagerbestand konnte nicht angepasst werden.",.t.)
      else
        aendArtKBest(AUFTRAG->Gelief,WARAUS_KLAG_GUTSCHR + RECHAUS->RechNr)
      endif
      dbcommit()
      unlock

      select Auftrag
      dbskip()
    enddo

    // schreibe Entnahmeliste & Datumszeitraum in Kopfdaten
    select RECHAUS
    // if rec_lock(5) Satz ist bereits gelockt
    replace RECHAUS->BestKonto with best_kto
    replace RECHAUS->BestNr with best_nr

    // drucken
    Gutschrift()

    // endif // Posten speichern

    dbcommitall()
    unlock all

  enddo

  close data
RETURN
/* EOP  */

/* Function KGut_Bauch  ****************************************
*
* Eingabe des K-Lager Gutschrift.Bauches, Editor-definitionen K-Lager
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
STATIC FUNCTION KGut_Bauch(view_only)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  default view_only:=.f.

  select Auftrag

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Auf_Text()}

  if view_only
    aKopf[EDIT_GESPERRT]:="KN�AELZ"
    aKopf[EDIT_EXTRA_FKT]:={}
  else
    // aKopf[EDIT_NEW_FKT]:={ || SaRechNeuSatz() }
    // aKopf[EDIT_EXTRA_FKT]:={ { "S"," @S@uchen ", { || SaRech_Such(aFelder,aKopf)} } }
    aKopf[EDIT_GESPERRT]:="Z" // l�schen,einf�gen,Kopf
  endif

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  // aSpalte[EDIT_NAME_GET]:="Fracht"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={;
    |oGet| ( trim(oGet:Buffer)$"*" .or. check(oGet,"Artikel",.f.)) .and. KGut_Anr_nach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe      @F4@=Honsel-Nr.      @ESC@=Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || trim(AUFTRAG->ArtNr) $ "*" }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_MESSAGE]:="Text eingeben"
  // aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Komm2"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:=replicate("X",30)
  aSpalte[EDIT_MESSAGE]:="Text eingeben"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  // aSpalte[EDIT_BEFORE]:={ || len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Geliefert
  aSpalte[EDIT_NAME]:="Gelief"
  aSpalte[EDIT_MASKE]:="99999"
  aSpalte[EDIT_MESSAGE]:="Menge - Gutschrift eingeben."
  // aSpalte[EDIT_MESSAGE]:="Menge - negative Entnahme eingeben.              @F5@=Rabatt �ndern"
  // aSpalte[EDIT_BEFORE]:={ || SetKey( K_F5 , {|| F5_Rabatt() } ),.t. }
  aSpalte[EDIT_AFTER]:={ |oGet| KGutMenge(oGet) }

  // aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Preis
  aSpalte[EDIT_NAME]:="Preis"
  aSpalte[EDIT_TITEL]:="Preis"
  aSpalte[EDIT_MESSAGE]:="Preis (Euro) eingeben."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // Rabatt
  aSpalte[EDIT_NAME]:="Rabatt"
  aSpalte[EDIT_TITEL]:="Rabatt"
  aSpalte[EDIT_POS_X]:=3 // um 3 nach rechts verschoben
  aSpalte[EDIT_MESSAGE]:="Rabatt eingeben."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // // Kalenderwoche
  // aSpalte[EDIT_NAME]:="Kw"
  // aSpalte[EDIT_TITEL]:="Woche"
  // aSpalte[EDIT_EDIT]:=.f.

  // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  // aSpalte:=e_fill() // initialisieren

  // // Kalenderwoche
  // aSpalte[EDIT_NAME]:="KW_Text"
  // aSpalte[EDIT_TITEL]:="LieferText"
  // aSpalte[EDIT_EDIT]:=.f.
  // aSpalte[EDIT_POS_X]:=-11 // um 11 nach links verschoben
  // aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  // aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

RETURN( Edit(aFelder,aKopf) )
/* EOF KGut_Bauch */

/* Function KGut_Anr_nach  **********************************
*
* wird nach Eingabe der ArtikelNummer ausgef�hrt
*/
FUNCTION KGut_Anr_nach(oGet)

  if oGet:changed
    // replace AUFTRAG->AufNr WITH AUFAUS->AufNr
    if trim(oGet:Buffer)$"*"
      if ! trim(oGet:original)$"*"
        REPLACE AUFTRAG->komm1 WITH ""
        REPLACE AUFTRAG->komm2 WITH ""
        REPLACE AUFTRAG->E_komm1 WITH ""
        REPLACE AUFTRAG->E_komm2 WITH ""
      endif
    else
      // keine Fracht
      if len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE
        Error(ACHTUNG+" K-Lager Gutshrift - Eingabe von Fracht nicht erlaubt.",.t.)
        return .f.
      endif
      // nur passende K-Lager Artikel
      if left(ARTIKEL->KonsigKdNr,5)<>left(KUNDEN->KundNr,5) .or. getArtikelArt()="B"
        Error(ACHTUNG+" Kein externer K-Lager Artikel f�r Kunde "+left(KUNDEN->KundNr,5)+".",.t.)
        return .f.
      endif
      replace AUFTRAG->komm1 WITH ARTIKEL->Bez1
      replace AUFTRAG->komm2 WITH ARTIKEL->Bez2
      replace AUFTRAG->E_komm1 WITH ARTIKEL->E_Bez1
      replace AUFTRAG->E_komm2 WITH ARTIKEL->E_Bez2
      replace AUFTRAG->Preis WITH ARTIKEL->Preis1

      replace AUFTRAG->Me WITH ARTIKEL->ME
      replace AUFTRAG->Pe WITH ARTIKEL->Schluessel
      replace AUFTRAG->Rabattgr WITH ARTIKEL->RabattGr
      replace AUFTRAG->Erl_Gruppe WITH ARTIKEL->Erl_Gruppe
      select Erl_Grup
      seek AUFTRAG->Erl_Gruppe
      if .not. eof()

        // Hinweis: prinzipiell Abfrage nach Land m�glich, geht
        // aber noch nicht wegen alter Adel (sprich falsche
        // L�nderkennungen) bei alten Rechnungen

        DO CASE
        CASE KUNDEN->MWST_KZ="1"
          replace AUFTRAG->Erl_Konto WITH ERL_GRUP->Inland
          replace AUFTRAG->Erl_Kz WITH "In"
        CASE KUNDEN->EG=="J"
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
RETURN(.t.)
/* EOF KGut_Anr_nach */

/* Function KGutMenge  **********************************
*
* wird nach Eingabe der Menge bei K-Lager Gutshcrift ausgefuehrt
*/
FUNCTION KGutMenge(oGet)

  if oGet:changed

    if val(oGet:buffer) < 0
      Error(ACHTUNG+" Negative Anzahl nicht m�glich.",.t.)
      return .f.
    endif

    // Gutschrift: Best.Menge immer gleich LieferMenge
    replace AUFTRAG->Menge with val(oGet:buffer)

    // Rabatt Hotkey loeschen
    SetKey( K_F5 , NIL)
  endif
RETURN(.t.)
/* EOF RechFreiMenge */

/* Procedure KGutStorno() ******************************************
*
*  storniert eine K-Lager Gutschrift 1:1
*/
PROCEDURE KGutStorno
LOCAL M_RechNr:=".",Ausgabe:="D",StRechNr,berechnet
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()+".dbf"
LOCAL GetList:={}
  cls
  Titel("K-Lager Gutschrift stornieren")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "AufAus" , "ZahlKond","Rabatt" , "Text_Kz" ,"AvPost";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" , "Aufpost";
    ,"Kunden" , "RechAus" , "RechPost", "Verkauf","Mat_KZ";
    ,"Spedit","Text","Konsig","Land","Auftrag")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzten */
  select RechPost
  set relation to RECHPOST->ME into Einheit
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  do while ! empty(M_RechNr)
    cls
    Titel("K-Lager Gutschrift stornieren")
    select Rechaus
    set filter to RECHAUS->AufArt="N"
    go top
    M_RechNr:=space(len(RECHAUS->RechNr))
    Message("Gutschriftsnummer eingeben.           @F12@=Hilfe")
    @ 2,10 say "Gutschrift-Nr.:" get M_RechNr;
      valid { |oGet| shift(oGet) .and. check(oGet,"RechAus",.t.,.f.) }
    read
    set filter to
    if empty(M_RechNr) .or. lastkey()==K_ESC
      loop
    endif
    Message("Gutschrift wird gepr�ft.     Bitte warten...")

    if ! empty(RECHAUS->Storno_Nr)
      Error(ACHTUNG+" Gutschrift bereits storniert.  Siehe Nr:"+RECHAUS->Storno_Nr,.t.)
      loop
    endif

    // pr�fe ob Artikel aus Gutschrift bereits wieder berechnet
    select RechPost
    seek RECHAUS->RechNr
    berechnet:=.f.
    do while RECHPOST->RechNr==M_Rechnr .and. ! RECHPOST->(eof())
      if len(alltrim(RECHPOST->ArtNr))<= FRACHT_LAENGE
        skip
        loop
      endif
      KONSIG->(dbseek(RECHAUS->AufNr+RECHPOST->ArtNr))
      if KONSIG->(eof()) .or. KONSIG->Berechnet > 0
        berechnet:=.t.
        exit
      endif
      // suche passenden Datensatz
      do while abs(RECHPOST->Menge)<>ABS(KONSIG->Menge) .and.;
        RECHPOST->AufNr==KONSIG->AufNr .and. ;
        ! RECHPOST->(eof()) .and. RECHPOST->ArtNr==KONSIG->ArtNr
        KONSIG->(dbskip())
      enddo
      if KONSIG->(eof()) .or. RECHPOST->AufNr<>KONSIG->AufNr .or. KONSIG->Berechnet > 0 .or. ;
        RECHPOST->ArtNr<>KONSIG->ArtNr
        berechnet:=.t.
        exit
      endif
      // okay, teste n�chsten Satz
      skip
    enddo

    if berechnet
      Error(ACHTUNG+" Artikel "+RECHPOST->ArtNr+" aus Gutschrift "+M_Rechnr+;
        " bereits wieder berechnet.";
        +"|          Gutschrift kann nicht storniert werden.",.t.)
      loop
    endif

    // jetzt am BS anzeigen

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(RECHAUS->Sprache)

    // Rechnung kopieren & anzeigen
    RECHPOST->(dbseek(RECHAUS->RechNr))
    select Auftrag
    zap
    do while RECHPOST->RechNr==RECHAUS->RechNr .and. ! RECHPOST->(eof())
      select Auftrag
      add_rec(0)
      replace AUFTRAG->ArtNr with RECHPOST->ArtNr
      replace AUFTRAG->ArtNr with RECHPOST->ArtNr
      replace AUFTRAG->Komm1 with RECHPOST->Komm1
      replace AUFTRAG->Komm2 with RECHPOST->Komm2
      replace AUFTRAG->E_Komm1 with RECHPOST->E_Komm1
      replace AUFTRAG->E_Komm2 with RECHPOST->E_Komm2
      replace AUFTRAG->Menge with RECHPOST->Menge
      replace AUFTRAG->Preis with RECHPOST->Preis
      replace AUFTRAG->KW with RECHPOST->KW
      replace AUFTRAG->Rabatt with RECHPOST->Rabatt
      replace AUFTRAG->Rabattgr with RECHPOST->Rabattgr
      replace AUFTRAG->KZ with RECHPOST->KZ
      replace AUFTRAG->Gelief with RECHPOST->Gelief
      replace AUFTRAG->GeliefGes with RECHPOST->GeliefGes
      replace AUFTRAG->ME with RECHPOST->ME
      replace AUFTRAG->PE with RECHPOST->PE
      replace AUFTRAG->AufNr with RECHPOST->AufNr
      REPLACE AUFTRAG->Erl_Gruppe With RECHPOST->Erl_Gruppe
      REPLACE AUFTRAG->Erl_Konto With RECHPOST->Erl_Konto
      REPLACE AUFTRAG->Erl_Kz With RECHPOST->Erl_Kz
      REPLACE AUFTRAG->ABPostNr With RECHPOST->AbPostNr
      select RECHPOST

      dbskip()
    enddo

    /*** Posten editieren **/
    KGut_Bauch(.t.)

    /* Auswahl-Menu */
    setcolor(COLWIN)
    Fenster(7,16,13,57)
    @ 8,20 say "Storno-Gutschrift"
    Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?")
    @ 10,20 say 'Drucker/Bildschirm/PDF (D/B/P) ' get Ausgabe Picture "!" valid Ausgabe $"DBP"
    read

    // /* eingeloggter Benutzer best�tigen/�ndern , Abbruch nur mit Panik-Taste */
    // do while ! Login_change(12,20,"Sachbearbeiter: ")
    // enddo
    setcolor(COLNOR)
    @ 6,0 clear
    if lastkey()==K_ESC
      loop
    endif

    /* Satz locken */
    SELECT RechAus
    if ! Rec_Lock(5)
      Error(SATZ_EXCL)
      loop
    endif

    AUFAUS->(dbseek(RECHAUS->AufNr))

    StRechNr:=hole("RechNr",WRITE,.t.)
    Message("Storno-Gutschrift: @"+StRechNr+"@ wird gedruckt.  Bitte warten...")

    /* Rechnungsposten kopieren */
    Select Aufpost
    AUFPOST->(OrdSetFocus(3)) // AuFNr+Anr

    select RechPost
    copy stru to (temp_datei)
    seek RECHAUS->RechNr
    select 0
    use (temp_datei) exclusive alias tempDatei

    /* alle passenden Rechnungs-Posten kopieren -> temp. Datei*/
    do while RECHPOST->RechNr==M_Rechnr .and. ! RECHPOST->(eof())
      select tempDatei
      add_rec(0)
      overwrite("RechPost")
      REPLACE TEMPDATEI->Menge With TEMPDATEI->Menge * (-1)
      REPLACE TEMPDATEI->Gelief With TEMPDATEI->Gelief * (-1)
      REPLACE TEMPDATEI->GeliefGes With TEMPDATEI->GeliefGes * (-1)
      REPLACE TEMPDATEI->RechNr WITH StRechNr
      REPLACE TEMPDATEI->ReaDat WITH getUser():date
      select RechPost
      skip
    enddo

    /** kopiere Storno Rechnungs Posten zurueck nach RechPost */
    select TEMPDATEI
    go top
    do while .not. eof()
      select RechPost
      add_rec(0)
      overwrite( "TEMPDATEI" )
      dbcommit()
      dbunlock()

      /** K-Lager Bestand wieder erhoehen */
      select Artikel
      dbseek(RECHPOST->ArtNr)
      if ! Rec_Lock(5)
        Error(ACHTUNG+" "+RECHPOST->ArtNr+" K-Lager konnte nicht geschrieben werden. Bitte "+;
          "kontrollieren",.t.)
      else
        aendArtKBest(RECHPOST->Gelief*(-1),WARAUS_RECHNR_GUTSCHR + RECHPOST->RechNr)
      endif

      // verkaufte Artikel runterzaehlen
      select Artikel
      if rec_lock(5)
        trouble("Verkauft",{ARTIKEL->ArtNr+" vorher:"+str(ARTIKEL->verkauft)+;
          " �nderung: "+str(RECHPOST->Gelief)+ " nachher: "+str(ARTIKEL->verkauft+RECHPOST->Gelief)})

        replace ARTIKEL->verkauft with ARTIKEL->verkauft+RECHPOST->Gelief
        dbcommit()
        dbunlock()
      endif

      select TEMPDATEI
      skip
    enddo

    /** Posten in Konsig wieder l�schen */
    select Konsig
    KONSIG->(dbseek(RECHAUS->AufNr))
    do while ! KONSIG->(eof()) .and. KONSIG->AufNr==RECHAUS->AufNr
      if ! REC_LOCK(5)
        Error("Gutschrift:"+M_Rechnr+" Artikel:"+KONSIG->ArtNr+" K-Lager Lieferung konnte nicht "+;
          "gel�scht werden.",.t.)
      else
        delete
        dbcommit()
        dbunlock()
      endif
      skip
    enddo



    select TEMPDATEI
    use

    /** erzeuge Storno Rechnungs Kopf */
    select RechAus
    REPLACE RECHAUS->Storno_Nr with StRechNr
    dbcommit()
    dbunlock()
    copy stru to (temp_datei)
    select 0
    use (temp_datei) exclusive alias TEMPDATEI

    /* Rechnungs-Kopf kopieren */
    select TEMPDATEI
    add_rec(0)
    overwrite("RechAus")
    REPLACE TEMPDATEI->RechNr WITH StRechNr
    REPLACE TEMPDATEI->ReaDat WITH getUser():date
    replace TEMPDATEI->Aufart WITH "M"
    // replace TEMPDATEI->gedruckt WITH " "
    replace TEMPDATEI->SumNr WITH ""
    replace TEMPDATEI->Netto WITH RECHAUS->Netto * (-1)
    replace TEMPDATEI->Brutto WITH RECHAUS->Brutto * (-1)
    replace TEMPDATEI->NebenKost WITH RECHAUS->NebenKost * (-1)
    replace TEMPDATEI->Rabatt WITH RECHAUS->Rabatt * (-1)

    /** kopiere Storno Rechnungs Kopf zurueck nach RechAus */
    select RechAus
    add_rec(0)
    overwrite( "TEMPDATEI" )
    REPLACE RECHAUS->Storno_Nr with M_RechNr
    close( "TEMPDATEI" )
    ferase( (temp_Datei ) )

    Gutschrift(Ausgabe)

    dbcommitall()
    UNLOCK all


  enddo

  close data
RETURN
/* EOP auf_Druckwieder */


/*
*  druckt eine K-Lager Rechnung basierend auf einem K-Lager Inventru Auftrag
*/
PROCEDURE KInventurSammelRechnung()
LOCAL GetList:={},gedruckt:=.f.
LOCAL DateiName, merkRecno

  Umgebung(WRITE_ALL)

  select Auftrag
  // Automatische "neue" Menge �bernehmen
  repla AUFTRAG->Gelief with AUFTRAG->Menge for AUFTRAG->Gelief == 0 // beim 1. Mal

  // wozu? raus 20190109
  // locate for AUFTRAG->Gelief <> 0
  // if eof()
  // Umgebung(LOAD)
  // return
  // endif

  // cls
  // Titel("K-Lager Inventur Sammelrechnung drucken")
  // Message("Dateien werden ge�ffnet.  Bitte warten...")

  Message("Rechnung wird erstellt.  Bitte warten...")

  if ! open( "Auftrag","AufAus" , "ZahlKond" , "Text_Kz" ,"Konsig";
    ,"Mwst_Kz" , "Artikel", "Einheit" , "VersArt" ,"Land";
    ,"Rabatt" ,"WarAus" , "AvPost","Spedit","Mat_Kz";
    ,"Kunden" , "RechAus" , "RechPost","Erl_Grup","KostenSt","EMail")

    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif
  /* Relationen setzen */

  select RechPost
  set relation to RECHPOST->Me into Einheit
  select RECHAUS
  set relation to RECHAUS->textkz_Nr into Text_Kz,to RECHAUS->zknr into zahlkond,;
    to RECHAUS->versNr into versart

  /** K-Lager bisher nur Deutsch */
  selLandBySprache(DEUTSCH)

  Select Konsig
  KONSIG->(OrdSetFocus(3)) // nach Kundnr+Anr
  KUNDEN->(dbseek( AUFAUS->KundNr ))

  /** ueberpruefe ob Posten ausgewaehlt ! */
  select Auftrag
  go top

  // sortiere nach Honselnr
  select auftrag
  index on AUFTRAG->TempStr+AUFTRAG->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE

  /*** Posten r�ckschreiben ***/
  merkRecno:=AUFAUS->(recno())
  auf_rech("K") // schreibe akt. Satz aus Aufaus->Rechaus
  Message("Inventur-Rechnung: @"+RECHAUS->RechNr+"@ wird gedruckt.  Bitte warten...")

  select Auftrag
  AUFTRAG->(OrdDestroy(TEMP_INDEX))
  AUFTRAG->(OrdSetFocus(0))

  // rechnDeckblatt(Ausgabe)

  // mit Abbuchen, da 1. Mal, nur PDF da direkt an VVG per Email
  dateiName:=Rechnung("1" , nil , "PDF")
  // Rechnung("2",,,.t.) // ohne Abbuchen, mit Posten , Kopie f�r Ablage
  Rechnung("3",,,.t.) // ohne Abbuchen, ohne Posten , Kopie f�r Buchhaltung
  BeistellTeilListe() // jetzt immer, jojo 28.9.98

  // Email zu Rechnung erst nach Beistellteilliste, da diese automat. angeh�ngt wird
  if ! empty( dateiName )
    sendEmails( EMAIL_RECHNUNG , dateiName )
  endif

  select Auftrag
  repla all AUFTRAG->GeliefGes with AUFTRAG->Menge

  select AufAus
  AUFAUS->(dbgoto( merkRecno ))
  // alle:="J"

  // neu 20180416, KonsigInv Bestand anpassen (Honsel hat gez�hlt, d.h. gewinnt)
  // 20200131: Fehler korrigiert muss KonsigBest sein!!!
  // select Auftrag
  // go top
  // do while ! AUFTRAG->(eof())
  // select Artikel
  // ARTIKEL->(dbseek( AUFTRAG->ArtNr ))
  // if ARTIKEL->(eof()) .or. ! rec_lock(0)
  // Error("Artikel: "+ AUFTRAG->ArtNr + "in Auftrag: " + AUFAUS->AufNr + ", Konsig Best. konnte nicht aktualisiert werden: " + SCHWERER_FEHLER)
  // else
  // aendArtKbest( AUFTRAG->GeliefGes * (-1) , "Inventur 2020")
  // dbcommit()
  // dbunlock()
  // Message("Konsig-Inventur-Bestand wird angepasst: " + ARTIKEL->ArtNr)
  // endif
  // select Auftrag

  // // if AUFTRAG->Menge > AUFTRAG->GeliefGes
  // // Alle:="N"
  // // altd()
  // // endif

  // skip
  // enddo

  replace AUFAUS->erledigt with "J"

  dbcommitall()
  unlock all

  // if Alle <> "J"
  // Error(ACHTUNG+"AB nicht erledigt.  |"+;
  // "         Nicht alle Artikel konnten berechnet werden.",.t.)
  // endif

  // AufBestand()

  Umgebung(LOAD)
RETURN
/* EOP KInventurSammelRechnung */

  /*
  * Listet alle Artikel, die im Zeitraum x an einen Kunden geliefert wurden. LLE
  */
PROCEDURE Langzeitlieferantenerkl()
LOCAL M_KundNr, von:=year(getUser():date)-1, bis:=year(getUser():date)
LOCAL GetList:={}, M_Sprache:=" ", Adresse1, Adresse2
LOCAL laender, temp, emailText
LOCAL line, stop:=.f. , zeile:=0,Seite,liFullName, i
LOCAL Ende:=.f., pdfInfo, Ausgabe, Zusatz
LOCAL ob:=2, s01
LOCAL lleVon:=ctod( "01.01."+str(year(getUser():date),4))
LOCAL lleBis:=ctod( "31.12."+str(year(getUser():date),4))

  if ! open("Artikel","Kunden","Rechaus","Rechpost","Einheit","Land","KundSped","Auftrag")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif
  select Rechpost
  set rela to RECHPOST->RechNr into RECHAUS
  select Auftrag
  set rela to AUFTRAG->ArtNr into Artikel
  select Artikel
  set rela to ARTIKEL->LandKz into Land

  cls
  Titel("Langzeit-Lieferantenerkl�rung drucken")

  M_KundNr:=space(len(KUNDEN->KundNr))
  Message("Kundennummer eingeben.  HauptKunde = Alle Lieferadressen         @F12@=Hilfe")
  @ ob,5 say "Kunden-Nr.:" get M_KundNr PICTURE KDNR_PICT;
    valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
  read
  if ABBRUCH
    close data
    return
  endif

  @ ob+1,3 to ob+14,75
  @ ob,27 say KUNDEN->KurzName

  adresse1:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->Land,;
    KUNDEN->Plz,KUNDEN->Ort)
  adresse2:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->Land,;
    KUNDEN->Plz,KUNDEN->Ort)

  M_Sprache:=KUNDEN->Sprache

  @ ob+2,5 say "LLE von:" get lleVon valid { |oget| lleDatumVon( oGet )} ;
    when Message("Bitte das Start-Datum der Langzeit-Lieferantenerkl�rung eingeben.")
  @ ob+2,23 say "bis:" get lleBis valid { |oget| lleDatumBis( oGet )} ;
    when Message("Bitte das End-Datum der Langzeit-Lieferantenerkl�rung eingeben.")
  @ ob+2,40 say "Daten von:" get von Picture "9999";
    when Message("Zeitraum Beginn eingeben.")
  @ ob+2,56 say "bis:" get bis Picture "9999" valid bis >= von;
    when Message("Zeitraum Beginn eingeben.")
  @ ob+4,5 say "Sprache:" get M_Sprache Picture "!" valid M_Sprache $ DEUTSCH+ENGLISCH;
    when Message("Sprache @D@eutsch / @E@nglisch eingeben.")

  @ ob+6,5 say "1. Adresse:"
  for i:=1 to len(adresse1)
    @ ob + 6 + i,5 get Adresse1[i] when Message("1. Adresse eingeben.")
  next

  @ ob+6, 40 say "2. Adresse:"
  for i:=1 to len(adresse2)
    @ ob + 6 + i,40 get Adresse2[i] when Message("2. Adresse eingeben.")
  next
  read

  if ABBRUCH
    close data
    return
  endif

  Message("Artikel werden gesucht.     Bitte warten...   @ESC@=Abbruch")

  // Artikel bestimmen
  select Auftrag
  zap

  select Rechpost
  index on RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    empty(RECHAUS->Storno_Nr) .and. RECHPOST->GeliefGes > 0 .and. ;
    len(alltrim(RECHPOST->ArtNr))>6 .and. year(RECHPOST->ReaDat)>=von .and. year(RECHPOST->ReaDat)<=bis;
    .and. (empty(right(M_KundNr,2)) .and. ; // Hauptkunde -> also alle
  (left(RECHAUS->V_KundNr,5) == left(M_KundNr,5) .or. left(RECHAUS->KundNr,5) == left(M_KundNr,5)) ;
    .or.;
    (!empty(right(M_KundNr,2)) .and. ; // Versandkunde -> also nur den genau
  (RECHAUS->V_KundNr == M_KundNr .or. RECHAUS->KundNr == M_KundNr)))
  go top

  emailText:=""
  laender:=hb_Hash()
  Seite:=0
  zeile:=0

  do while .not. RECHPOST->(eof()) .and. ! stop
    select Auftrag
    loca for AUFTRAG->ArtNr == RECHPOST->ArtNr
    if AUFTRAG->(eof())
      add_rec(0)
      replace AUFTRAG->ArtNr with RECHPOST->ArtNr
    endif
    select Rechpost
    skip
    stop:=(inkey() == K_ESC)
  enddo

  if stop
    close data
    return
  endif

  do while ! ende
    // Posten bearbeiten
    LLE_Bauch()

    // pr�fe auf fehlende L�nderkennzeichen
    select Auftrag
    loca for empty(ARTIKEL->LandKZ)
    if ! AUFTRAG->(eof())
      s01:=savescreen()
      Error( ACHTUNG+"LLE enth�lt Artikel ohne L�nderkennzeichen.|"+;
        "         Diese Artikel werden nicht ausgedruckt.",ERR_NO_WAIT)
      if Message("LLE trotzdem @d@rucken oder weiter @b@earbeiten?      @ESC@=Abbruch   (@D@/@B@)",;
        "DB"," ")=="B"
        restscreen(,,,,s01)
        loop
      endif
      restscreen(,,,,s01)

      if ABBRUCH
        close data
        return
      endif

    endif

    // FIXME: ohne Abfrage Dateiname -> & Datum
    Ausgabe:=Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?","DBP","D")
    if ABBRUCH
      ende = (Message("Daten @v@erwerfen oder weiter @b@earbeiten?  (@V@/@B@)","VB"," ")=="V")
      if ende
        close data
        return
      endif
      loop

    else
      ende:=.t.
    endif

  enddo

  pdfInfo:=pdfInfo():new( JOB_LLE , M_KundNr , .t. )
  zusatz:="-"+getFileStyleDate(lleVon,.f.)+"-"+getFileStyleDate(lleBis,.f.)
  do case
  case Ausgabe == "B"
    Drucker("BS")
  case Ausgabe == "D"
    Drucker("ON",pdfInfo:getLocalizedName( M_Sprache , zusatz ),pdfInfo:path,;
      .f.,PDF_NO_CONFIRM)
  case Ausgabe == "P"
    Drucker("PDF",pdfInfo:getLocalizedName( M_Sprache , zusatz ),pdfInfo:path,;
      .f.,PDF_NO_CONFIRM)
  endcase

  if getUser():getCurrentPrintJob():className() <> "BSJOB"
    getUser():getCurrentPrintJob():setBackground(getTranslation("config.briefohne",M_Sprache))
  endif


  // jetzt drucken
  ?
  ?
  ?
  ? space(58),getTranslation("allgemein.seite",M_Sprache),"  1"
  ? space(4),Adresse1[1]
  ? space(4),Adresse1[2]
  ? space(4),Adresse1[3]
  ? space(4),Adresse1[4]
  ? space(4),Adresse1[5]
  ? space(4),Adresse1[6]
  ?
  ?
  for each line in linewrap( getTranslation("langzeitlieferant.titel",M_Sprache) , 72 )
    ? FETT_AN,line,FETT_AUS
  next
  ?
  ? getTranslation("langzeitlieferant.titel2",M_Sprache)
  ?

  Seite:=0
  select Auftrag
  go top
  do while ! AUFTRAG->(eof()) .and. ! stop
    Seite = Seite + 1
    if Seite > 1
      ?
      ?
      ?
      ? space(58),getTranslation("allgemein.seite",M_Sprache),str(Seite,3)
    endif

    ? getTranslation("langzeitlieferant.spaltentitel",M_Sprache)
    ? "===================================================================="
    do while ! AUFTRAG->(eof()) .and. ! stop .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand

      if empty( ARTIKEL->LandKZ )
        emailText += ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" ohne L�nderkennzeichen.|"
      elseif ! ARTIKEL->LandKz $ ":XX:"; // XX werden ignoriert
        .or. getArtikelArt() $ "W" // Werkzeuge werden ignoriert


        LAND->(dbseek( ARTIKEL->LandKZ ))

        if ! ARTIKEL->LandKz $ DEUTSCH_LAND
          if LAND->(eof())
            emailText += ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" Land:"+ARTIKEL->LandKZ+" nicht "+;
              "gefunden.|"
          else
            if LAND->LLE=="J" .and. ! LAND->EU $ DEUTSCH_LAND+"J" // nur falls au�erhalb EU
              laender[ ARTIKEL->LandKz ]:=.t.
            endif
          endif

          // englischer Text vorhanden?
          if M_Sprache <> DEUTSCH .and. empty( ARTIKEL->E_Bez1 )
            emailText += ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" englische Bezeichnung fehlt.|"
          endif
        endif

        if ARTIKEL->LandKz $ DEUTSCH_LAND .or. LAND->LLE=="J"
          ? ZEIGE_ARTNR+out2(ARTIKEL->ArtNr),space(2),getTransfield("ARTIKEL->Bez1",M_Sprache),space(4),;
            ARTIKEL->LandKZ,"-",trim(left(getTransField("LAND->Name",M_Sprache),20))

          ? WINZIG_AN,HonselNrWinzig(),WINZIG_AUS,space(3),getTransfield("ARTIKEL->Bez2",M_Sprache),;
            space(4),ARTIKEL->WarenNr
        endif

      endif
      skip
      stop:=stop_key() // ESC gedr�ckt ?
    enddo
    Zeile:=FormFeed(Zeile,Seite)

  enddo

  // Schlusstext drucken
  ?
  ?
  ?
  ? getTranslation("langzeitlieferant.schluss",M_Sprache)
  ? FETT_AN
  ? space(4),Adresse2[1]
  ? space(4),Adresse2[2]
  ? space(4),Adresse2[3]
  ? space(4),Adresse2[4]
  ? space(4),Adresse2[5]
  ? space(4),Adresse2[6]
  ? FETT_AUS
  for each line in linewrap( getTranslation("langzeitlieferant.schluss2",M_Sprache) ,72 )
    ? line
  next
  ?

  // auflisten aller LLE nicht EU-Staaten
  temp:=""
  select Land
  go top
  do while ! LAND->(eof())
    if LAND->LLE == "J" .and. ! LAND->EU $ DEUTSCH_LAND+"J"
      temp+=trim(getTransField("LAND->Name",M_Sprache)) + " " +;
        trim(getTransField("LAND->LLEText",M_Sprache)) + " ("+LAND->LandKz+") - "
    endif
    skip
  enddo

  // remove last seperator
  if right( temp , 3 ) == " - "
    temp:=left( temp, len(temp) - 3 )
  endif

  // drucke L�nder-KZ nicht EU
  for each line in linewrap( temp ,72 )
    ? line
  next

  // Seitenumbruch, falls keine Artikel geliefert wurden
  if zeile > DRUCKER->laenge - LISTE->Unt_Rand - 12
    Zeile:=FormFeed(Zeile,Seite)
    ?
    ?
    ?
    ?
    ?
  endif

  // keine Kumulierung?
  ?
  ? getTranslation("langzeitlieferant.kum.text",M_Sprache)
  if len( laender ) > 0
    ?? "   "
  else
    ?? FETT_AN," X ",FETT_AUS
  endif
  ?? getTranslation("langzeitlieferant.kum.nein",M_Sprache)

  // mit Kumulierung?
  ? space(len( getTranslation("langzeitlieferant.kum.text",M_Sprache) ))
  if len( laender ) > 0
    ?? FETT_AN," X ",FETT_AUS
  else
    ?? "   "
  endif
  ?? getTranslation("langzeitlieferant.kum.ja",M_Sprache)
  // L�nder auflisten
  if len( laender ) > 0
    temp:=""
    for each line in laender:keys
      temp += line + " "
    next
    ?? FETT_AN,temp,FETT_AUS // FIXME: linewrap, do we need this?
  endif

  ? getTranslation("langzeitlieferant.ende1",M_Sprache)

  // Zeitraum
  ?
  ? FETT_AN,;
    strtran(strtran(getTranslation("langzeitlieferant.zeitraum",M_Sprache),"$VON",dtoc(lleVon)), "$BIS",dtoc(lleBis)),FETT_AUS
  ?

  temp:=strtran(strtran( getTranslation("langzeitlieferant.ende2",M_Sprache),;
    "$DATUM",dtoc(getUser():date)) , ;
    "$KUNDE",trim(strtran(KUNDEN->Name," VS","")))

  for each line in linewrap( temp ,72 )
    ? line
  next

  getUser():getCurrentPrintJob():endDoc()
  if len(emailText)>0 .and. getUser():getCurrentPrintJob():className() <> "BSJOB"
    liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
    if M_Sprache == DEUTSCH
      email(MAIN_EMAIL,;
        "Artikel ohne L�nderkennzeichen",;
        "Artikel wurden in der Langzeitlieferanten-Erkl�rung nicht aufgelistet.||Bitte �berpr�fen!||"+;
        emailText,liFullName)
    else
      email(MAIN_EMAIL,;
        "Artikel ohne L�nderkennzeichen / fehlende engl. �bersetzung",;
        "Artikel wurden in der Langzeitlieferanten-Erkl�rung nicht aufgelistet|"+;
        "bzw. bei fehlender �bersetzung nur in Deutsch.||"+;
        "Bitte �berpr�fen!||"+;
        emailText,liFullName)
    endif
  endif
  getUser():setCurrentPrintJob(NIL)

  cls
  close data
return
/**eop */

static function lleDatumVon( oGet )
LOCAL today:=getUser():date

  if today - ctod( oGet:buffer ) > 365
    Error(ACHTUNG+"Langzeitlieferanten-Erkl�rung kann max. 1 Jahr|"+;
      "        in die Vergangenheit best�tigt werden.",.t.)
    return .f.
  endif

  // if today > ctod( oGet:buffer )
  // bis:=today
  // endif


return .t.
/** eof */

static function lleDatumBis( oGet )
LOCAL today:=getUser():date

  // if von < today .and. ctod( oGet:buffer ) > today
  // Error(ACHTUNG+"Langzeitlieferanten-Erkl�rung kann nicht gleichzeitig|"+;
  // "          in die Vergangenheit und in die Zukunft best�tigt werden.",.t.)
  // oGet:buffer:=dtoc( today )
  // oGet:assign()
  // return .f.
  // endif

  if ctod( oGet:buffer ) - today > 2*365
    Error(ACHTUNG+"Langzeitlieferanten-Erkl�rung kann max. 2 Jahre|"+;
      "         in die Zukunft best�tigt werden.",.t.)
    return .f.
  endif

return .t.
/** eof */

  /*
  * Eingabe der Posten der Langzeitlieferanten-Erkl�rung LLE
*
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/


FUNCTION LLE_Bauch()
LOCAL aFelder,result
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  set key K_F5 to toggleSprache()
  set key K_F11 to zeigeMatText()

  aFelder:={}
  select Auftrag

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=8 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-3 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile

  // von K ausgef�hrt
  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe      @ESC@=Ende"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_FARBE]:={ || if(empty(ARTIKEL->LandKZ),"R/"+getBackColor(),COLNOR) }
  aSpalte[EDIT_AFTER]:={ |oGet| ( check(oGet,"Artikel",.f.)) } // kein leeres Feld erlaubt

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Bezeichnung"
  aSpalte[EDIT_FARBE]:={ || if(empty(ARTIKEL->LandKZ),"R/"+getBackColor(),COLNOR) }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez2"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={ || if(empty(ARTIKEL->LandKZ),"R/"+getBackColor(),COLNOR) }
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->LandKZ"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MESSAGE]:="L�nder-Kennzeichen eingeben.         @F12@=Hilfe      @ESC@=Ende"
  aSpalte[EDIT_MASKE]:="!!"
  aSpalte[EDIT_TITEL]:="Ursprungsland"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_BEFORE]:={ || beforeKZ() }
  aSpalte[EDIT_AFTER]:={ || afterKZ() }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="left(LAND->Name,30)"
  aSpalte[EDIT_POS_X]:=-11
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->WarenNr"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={ || if(empty(ARTIKEL->LandKZ),"R/"+getBackColor(),COLNOR) }
  aSpalte[EDIT_POS_X]:=-11
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/
  result:=Edit(aFelder,aKopf)

  set key K_F5 to
  set key K_F11 to

RETURN( result )
/* EOF LLE_Bauch */

static function beforeKZ()
LOCAL result
  select Artikel
  result:=rec_lock(5)
  select Auftrag
return result
/** eof */

static function afterKZ()
  ARTIKEL->(dbcommit())
  ARTIKEL->(dbunlock())
return .t.
/** eof */

static function checkSameYear( datVon, DatBis )
  if DatVon > DatBis
    Error(ACHTUNG+"von Datum kann nicht gr��er als bis-Datum sein",.t.)
    return .f.
  endif
  if year(Datvon) <> year(DatBis)
    Error(ACHTUNG+"Zeitraum muss im gleichen Jahr liegen.||        Wichtig f�r die Inventur!",.t.)
    return .f.
  endif
return .t.

static function konsistenzLoesch()

  // pr�fe ob Kommentar
  if alltrim(AUFTRAG->ArtNr) $ "$*"
    // now delete via editor.prg
    HB_KeyPut(EDIT_DELETE)
  endif

return .t.
/** eof */




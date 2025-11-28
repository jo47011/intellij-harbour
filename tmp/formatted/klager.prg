// Modul: KLager.prg
//
// enth�lt K-Lager relevanten Proceduren
// siehe auch Fakt3.prg
// /

#include "Miki.ch"

#define BESTAND_FEHLT -999.99

/** Procedure honselVKEinles
 *
 * liest die Honsel-VK-Datei an
 *
 * FehlerCodes:
 * 1 - ohne Miki Nr bei import
 * 2 - K-Lager Artikel kommt nicht in Liste vor
 * 3 - Artikel ist in Liste, aber kein K-Lager Artikel
 */
Procedure honselVKEinles
LOCAL DateiName:="Honsel  "
LOCAL GetList:={},zeile:=0
LOCAL MKundNr:="10363",MArtNr:=".",MHonselNr:=".",okay:=.t.
LOCAL time,Ergebnis:=getUser():exportPATH()+BACKSLASH+"HonselVK.dbf"
LOCAL Ergeb2:=getUser():exportPATH()+BACKSLASH+"ArtFehlt.dbf"
LOCAL HonselTeil:=""
LOCAL Temp_Ind:=TEMP+"\temp"+getUser():getLongID()
LOCAL Temp_Ind2:=TEMP+"\temp2"+getUser():getLongID()
LOCAL Datei:=db_info("Artikel")

  /* �ffnen der ben�tigten Dateien */
  if ! open( {"Artikel",.t.},{"HonselVK",.t.}) .or. ! mkmydir(getUser():exportPATH())
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  cls
  Titel("Honsel VK Datei einlesen")

  do while ! ABBRUCH
    @ 4,10 say "Kunden-Nr...: " + MKundNr
    @ 6,10 say "Datei-Name..:" get DateiName;
      when Message("CSV Datei-Name (Komma-separierte ASCI Datei) eingeben.         @ESC@=Ende")
    ?? ".csv"
    read

    if ABBRUCH
      loop
    endif

    if ! file(alltrim(DateiName)+".csv")
      Error(ACHTUNG+" Datei:"+alltrim(DateiName)+".csv nicht gefunden!",.t.)
      loop
    endif

    time:=seconds()

    Message("Artikeldaten werden vorbereitet, bitte warten.")
    select Artikel
    repla all ARTIKEL->Temp with trim(no_blanks(ARTIKEL->HartNr)), ARTIKEL->Temp2 with " "

    index on ARTIKEL->temp to (temp_ind) eval IndexProz() every lastrec()/20
    set index to (Datei[D_PFAD]+BACKSLASH+trim(left(Datei[D_NAME],7))+"1"),(temp_ind)

    Message("Honsel VK Datei wird importiert.")
    select HonselVK
    zap
    // Info: FParse() importiert in Array!
    append from (alltrim(DateiName)+".csv") delimited
    index on HONSELVK->Teil to (temp_ind2) eval IndexProz() every lastrec()/20
    go top
    do while ! HONSELVK->(eof())
      Message("Honsel Inventur Datei wird importiert.    @"+HONSELVK->Teil+"@")
      // Honsel Nr dopplet?
      if honselTeil==trim(HONSELVK->Teil)
        replace HONSELVK->Kommentar3 with "Honsel-Nr. doppelt."
      else
        honselTeil:=trim(HONSELVK->Teil)
      endif

      // suche anhand Miki Nr
      MArtNr:=alltrim(no_blanks(deleteString(substr(HONSELVK->Selektion,2),".")))
      if empty(MArtNr)
        replace HONSELVK->Kommentar1 with "Miki Art.Nr fehlt."
      else
        Artikel->(ordSetFocus(1))
        ARTIKEL->(dbseek(MArtNr))
        if ARTIKEL->(eof())
          replace HONSELVK->Kommentar1 with "Miki Art.Nr nicht gefunden."
        endif
      endif

      // MikiNr nicht gefunden -> suche anhand HonselNr
      if ARTIKEL->(eof()) .or. empty(MartNr)
        Artikel->(ordSetFocus(2))
        ARTIKEL->(dbseek(HonselTeil))
        if ARTIKEL->(eof()) .or. empty(HONSELVK->Teil)
          replace HONSELVK->Kommentar2 with "Honsel Nummer nicht gefunden."
        else
          // Artikel bereits vorgekommen?
          // sollte unn�tig sein, da entweder HonselNr doppelt (bereits erw�hnt)
          // oder an dieser Stelle Miki Art.Nr. falsch!
          // if ARTIKEL->Temp2=="H"
          // replace HONSELVK->Kommentar3 with trim(HONSELVK->Kommentar3)+" XXX"
          // endif
          replace HONSELVK->Kommentar2 with "Miki Art.Nr: M "+out(ARTIKEL->ArtNr)

          if ARTIKEL->Preis1==0 .and. getArtikelArt()<>"B"
            replace HONSELVK->Ek150210 with "Preis pr�fen"
          else
            if ARTIKEL->Schluessel=="H"
              replace HONSELVK->Ek150210 with alltrim(str(ARTIKEL->Preis1/100,12,2))
            else
              replace HONSELVK->Ek150210 with alltrim(str(ARTIKEL->Preis1,12,2))
            endif
          endif
          select Artikel
          // rec_lock(0)
          replace ARTIKEL->Temp2 with "H"
          // dbcommit()
          // dbunlock()
          select HonselVK
        endif
      else
        // Artikel anhand MikiNr gefunden

        // Artikel bereits vorgekommen?
        if ARTIKEL->Temp2=="H"
          replace HONSELVK->Kommentar3 with trim(HONSELVK->Kommentar3)+" Miki Art.Nr doppelt."
        endif

        // vergleiche Honsel-Nr
        if trim(ARTIKEL->Temp)<>honselTeil
          replace HONSELVK->Kommentar1 with "Miki Art.Nr gefunden."
          replace HONSELVK->Kommentar2 with "Honsel-Nr. falsch!"
        endif
        // replace HONSELVK->Kommentar2 with "Miki Art.Nr: M "+out(ARTIKEL->ArtNr)
        if ARTIKEL->Preis1==0 .and. getArtikelArt()<>"B"
          replace HONSELVK->Ek150210 with "Preis pr�fen"
        else
          if ARTIKEL->Schluessel=="H"
            replace HONSELVK->Ek150210 with alltrim(str(ARTIKEL->Preis1/100,12,2))
          else
            replace HONSELVK->Ek150210 with alltrim(str(ARTIKEL->Preis1,12,2))
          endif
        endif
        select Artikel
        // rec_lock(0)
        replace ARTIKEL->Temp2 with "H"
        // dbcommit()
        // dbunlock()
        select HonselVK
      endif
      skip
    enddo

    Message("Exportiere Ergebnis nach "+Ergebnis)
    select HonselVK
    copy to (Ergebnis)

    Message("Exportiere fehlende Artikel nach "+Ergeb2)
    select Artikel
    copy fields ArtNr,Bez1,Bez2,;
      HartNr;
      to;
      (Ergeb2);
      for alltrim(left(ARTIKEL->HartNr,12))==left(ARTIKEL->HartNr,12) .and.;
      trim(ARTIKEL->Temp2)<>"H" .and. ! (left(ARTIKEL->KonsigKdNr,5)=="10167" .and. getArtikelArt()<>"B")

    Message(Ergebnis+", ArtFehlt.dbf aktualisiert. Zeit (sec):"+str(seconds()-time),"@")

  enddo

  cls
  close data
  ferase(temp_ind)
  ferase(temp_ind2)
return
/** EOP honselvkEinles */


/** FUNCTION sucheKInvAuftrag()
 *
 * sucht den letzten K-Inventur Auftrag zu diesem Kunden
 * Falls vom letzten Jahr wird nach Abfrage ein neuer Auftrag angelegt
 *
 * Liefert AufNr zur�ck
 */
static Function sucheKInvAuftrag(KonsigKdNr)
LOCAL erg,neu:=.f. , Spedits
  Umgebung(WRITE)

  Message("K-Lager Inventur Auftrag wird gesucht.   Bitte warten....")

  select AufAus
  set filter to AUFAUS->InvKZ=="J" .and. AUFAUS->KundNr==KonsigKdNr
  go bottom
  if AUFAUS->(eof())
    set filter to
    neu:=.t.
  else
    set filter to
    // pr�fe Jahresdatum
    if year(AUFAUS->Aufdat)<>year(getUser():date)
      if Message("Letzte Inventur: @"+dtoc(AUFAUS->Aufdat)+"@.   Neuen Inv. Auftrag @31.12."+;
        alltrim(str(year(getUser():date)-1))+"@ anlegen?  @J@/@N@","JN","N")=="J"
        neu:=.t.
      else
        Umgebung(LOAD)
        return erg // nil
      endif
    endif
  endif

  if neu
    // erzeuge neuen akt. Inventur Auftrag
    if ! open("Kunden","MWST_KZ")
      Error(ACHTUNG+" K-Lager Inventur Auftrag konnte nicht angelegt werden.  Bitte erneut "+;
        "versuchen.",.t.)
      Umgebung(LOAD)
      return erg // nil
    endif
    KUNDEN->(dbseek(KonsigKdNr))

    select Aufaus
    add_rec(0)
    REPLACE AUFAUS->AufNr WITH hole("AufNr",WRITE,.t.)
    REPLACE AUFAUS->InvKz WITH "J"
    REPLACE AUFAUS->AufDat WITH getUser():date
    REPLACE AUFAUS->BestDat WITH getUser():date
    if left(KonsigKdNr,5)=="10167"
      REPLACE AUFAUS->BestNr WITH "Invent. VVG 31.12."+alltrim(str(year(getUser():date)-1)) // letzes Jahr
    else
      REPLACE AUFAUS->BestNr WITH "Invent. Honsel 31.12."+alltrim(str(year(getUser():date)-1)) // letzes Jahr
    endif
    REPLACE AUFAUS->AufArt WITH "K"
    REPLACE AUFAUS->MWST_KZ WITH "1"
    MWST_KZ->(dbseek("1"))
    REPLACE AUFAUS->MWST WITH MWST_KZ->MWST

    REPLACE AUFAUS->KundNr WITH KUNDEN->KundNr
    REPLACE AUFAUS->Name WITH KUNDEN->Name
    REPLACE AUFAUS->KurzName WITH KUNDEN->KurzName
    REPLACE AUFAUS->Partner WITH KUNDEN->Partner
    REPLACE AUFAUS->Strasse WITH KUNDEN->Strasse
    REPLACE AUFAUS->Zusatz WITH KUNDEN->Zusatz
    REPLACE AUFAUS->Plz WITH KUNDEN->PLZ
    REPLACE AUFAUS->Land WITH KUNDEN->Land
    REPLACE AUFAUS->Ort WITH KUNDEN->Ort
    /* Versand-KundenNr */
    if KUNDEN->VA <> "J" // Versandanschrift gleich
      REPLACE AUFAUS->V_KundNr WITH AUFAUS->KundNr
      REPLACE AUFAUS->V_Name WITH KUNDEN->Name2
      REPLACE AUFAUS->V_Partner WITH KUNDEN->Partner2
      REPLACE AUFAUS->V_Strasse WITH KUNDEN->Strasse2
      REPLACE AUFAUS->V_Zusatz WITH KUNDEN->Zusatz2
      REPLACE AUFAUS->V_Plz WITH KUNDEN->PLZ2
      REPLACE AUFAUS->V_Land WITH KUNDEN->Land2
      REPLACE AUFAUS->V_Ort WITH KUNDEN->Ort2
      REPLACE AUFAUS->VersNr WITH KUNDEN->VersNr
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
      REPLACE AUFAUS->ZKNr WITH KUNDEN->ZKNr
    else
      REPLACE AUFAUS->R_KundNr WITH ""
    endif

    REPLACE AUFAUS->So_Rabatt WITH KUNDEN->So_Rabatt

    // FIXME: KLager bisher nur Inland, deswegen ok. Ansonsten LieferAdress f�r Mwst nehmen!
    REPLACE AUFAUS->MwSt_Kz WITH KUNDEN->MwSt_Kz
    MWST_KZ->(dbseek(KUNDEN->Mwst_Kz))
    REPLACE AUFAUS->MwSt WITH MWST_KZ->MwSt
    REPLACE AUFAUS->LiefNr WITH KUNDEN->Lfd_Nr
    REPLACE AUFAUS->IdentNr WITH KUNDEN->IdentNr
    REPLACE AUFAUS->EG WITH KUNDEN->EG

    if select("KundSped") == 0
      open("KundSped")
    endif

    spedits:=getKundSpedits( KUNDEN->KundNr )
    if len(spedits) > 1 // ansonsten muss der Benutzer manuell ausw�hlen!
      REPLACE AUFAUS->SpedNr WITH spedits[1]
    endif
    dbcommit()
    dbunlock()
  endif
  Umgebung(LOAD)

return AUFAUS->AufNr
/** eof */

/** Erh�ht den externen KLagerBestand ohne Schummeln
 *
 *  Honsel hat mehr Artikel als wir dachten.
 *  Artikel muss bereits selektiert sein
 */
static Function KInvBestInc(mydiff,InvAufNr)
LOCAL diff:=abs(mydiff)
LOCAL sammelRechn:=.f.

  // suche zugeh. Inventur Auftrag
  if valtype(InvAufNr)=="U"
    InvAufNr:=sucheKInvAuftrag(ARTIKEL->KonsigKdNr)
    if valtype(InvAufNr)=="U"
      // Umgebung(LOAD)
      return .f.
    endif
  endif

  @ 17,8 say "Auftr.Nr....: "+AUFAUS->AufNr
  @ 18,8 say "Auftr.Datum : "+dtoc(AUFAUS->AufDat)
  @ 19,8 say "Best.Nr.....: "+AUFAUS->BestNr
  @ 20,8 say "Erh�he Bestand um: "+alltrim(str(diff))

  if Message("Vorschlag �bernehmen? ( @J@ / @N@ ) ","JN")=="J"
    // erstmal ohne berechnen
    // sammelRechn:=Message("In Sammelrechnung �bernehmen ? ( @J@ / @N@ ) ","JN","J")=="J"

    select Konsig
    // erzeuge neue "Schein-Lieferung"
    if ! add_rec(5)
      Error(TRY_AGAIN)
    else
      replace KONSIG->AufNr with AUFAUS->AufNr
      replace KONSIG->KundNr with ARTIKEL->KonsigKdNr
      replace KONSIG->LieDat with AUFAUS->AufDat
      replace KONSIG->ArtNr with ARTIKEL->ArtNr
      replace KONSIG->Komm1 with ARTIKEL->Bez1
      replace KONSIG->Komm2 with ARTIKEL->Bez2
      replace KONSIG->Menge with diff
      if sammelRechn
        replace KONSIG->Gelief with diff // gleich zum Abrechnen vorschlagen
      endif
      REPLACE KONSIG->GeliefGes WITH diff // Bereits geliefert
      replace KONSIG->Preis with ARTIKEL->Preis1
      // replace KONSIG->Rabattgr with AUFPOST->Rabattgr
      // replace KONSIG->KZ with AUFPOST->KZ
      replace KONSIG->ME with ARTIKEL->ME
      replace KONSIG->PE with ARTIKEL->Schluessel
      // replace KONSIG->KW with AUFPOST->KW
      REPLACE KONSIG->Erl_Gruppe With ARTIKEL->Erl_Gruppe
      // REPLACE KONSIG->Erl_Konto With AUFPOST->Erl_Konto
      // REPLACE KONSIG->Erl_Kz With AUFPOST->Erl_Kz
      // replace KONSIG->LiefNr with M_KonsigLSNr
      // replace KONSIG->Liedat with M_LSDat
      // REPLACE KONSIG->GerVon With AUFTRAG->GerVon
      // REPLACE KONSIG->GerBis With AUFTRAG->GerBis

      // FIXME: was ist mit der AbPostNr hier
      // REPLACE KONSIG->AbPostNr With AUFTRAG->ABPostNr
      dbcommit()
      unlock
    endif
    // endif // SammelRechn

    select Artikel
    if ! rec_lock(5)
      Error(ACHTUNG+;
        " Artikel wird benutzt.  K-Lager Bestand konnte nicht aktualisiert werden!",.t.)
    else
      aendArtKBest(diff,AUFAUS->BestNr)
      dbcommit()
      dbunlock()
    endif // rec_lock konsig
    return .t.
  endif // Vorschlag �bernehmen
return .f.
/** eof /**
	
/** Erniedrigt den externen KLagerBestand ohne Schummeln
 *
 *  Honsel hat weniger Artikel als wir dachten.
 *  Artikel muss bereits selektiert sein
 */
static Function KInvBestDec(mydiff,InvAufNr)
LOCAL diff:=abs(mydiff) // ist positiv
LOCAL sammelRechn:=.f.
LOCAL M_order,rest,menge

  // suche aktuellen Inventur-Auftrag
  if valtype(InvAufNr)=="U"
    InvAufNr:=sucheKInvAuftrag(ARTIKEL->KonsigKdNr)
    if valtype(InvAufNr)=="U"
      // Umgebung(LOAD)
      return .f.
    endif
  endif

  @ 17,8 say "Auftr.Nr....: "+AUFAUS->AufNr
  @ 18,8 say "Auftr.Datum : "+dtoc(AUFAUS->AufDat)
  @ 19,8 say "Best.Nr.....: "+AUFAUS->BestNr
  @ 20,8 say "Erniedrige Bestand um: "+alltrim(str(diff))
  if Message("Vorschlag �bernehmen? ( @J@ / @N@ ) ","JN")=="J"
    // suche bisherige K-Lager Lieferungen
    select Konsig
    m_order:=KONSIG->(IndexOrd())
    KONSIG->(OrdSetFocus(3))
    seek ARTIKEL->KonsigKdNr+ARTIKEL->ArtNr

    rest:=diff
    /* alle passenden Posten durchgehen */
    do while KONSIG->KundNr==ARTIKEL->KonsigKdNr .and. KONSIG->ArtNr==ARTIKEL->ArtNr ;
      .and. ! KONSIG->(eof()) .and. rest > 0
      if KONSIG->Berechnet<KONSIG->GeliefGes
        // als berechnet markieren
        menge:=Min(rest,KONSIG->GeliefGes-KONSIG->Berechnet)
        rec_lock(0)
        replace KONSIG->Berechnet with KONSIG->Berechnet+menge
        rest:=rest-menge
        dbcommit()
        dbunlock()
      endif
      skip
    enddo
    KONSIG->(OrdSetFocus(m_Order))

    // if rest > 0
    // Error(ACHTUNG+" zu wenig K-Lieferungen zum l�schen.  Fehler kann ignoriert werden.",.t.)
    // endif

    select Artikel
    if ! rec_lock(5)
      Error(ACHTUNG+;
        " Artikel wird benutzt.  K-Lager Bestand konnte nicht aktualisiert werden!",.t.)
    else
      aendArtKBest(diff*(-1),AUFAUS->BestNr)
      dbcommit()
      dbunlock()
    endif // rec_lock konsig
    return .t.
  endif // Vorschlag �bernehmen
return .f.
/** eof */




/** Verarbeitet Honsel-Inventur-Datei
 *
 * Parameter
 */
Procedure H_InvVerabeiten( inFenster )
LOCAL GetList:={}
LOCAL li:=4
LOCAL re:=73
LOCAL ob:=4
  _thread static InvAufNr
  default inFenster:=.f.

  Umgebung(WRITE)

  ARTIKEL->(dbseek(HONSELDA->Miki_Nr))
  if ARTIKEL->(eof())
    if ! empty(HONSELDA->Honsel_nr)
      select Artikel
      locate for trim(no_blanks(HONSELDA->Honsel_nr))==trim(no_blanks(ARTIKEL->Hartnr))
    endif
    if ARTIKEL->(eof()) .or. empty(HONSELDA->Honsel_nr)
      Error(ACHTUNG+" Artikel:"+HONSELDA->Miki_Nr+" existiert nicht in Artikel-Stamm.",.t.)
      Umgebung(LOAD)
      return
    endif
  endif

  if inFenster
    setcolor(COLWIN)
  endif
  honsdisp(.f.,.f.)

  // keine Artikel die in Honsel Liste fehler
  if HONSELDA->HonselBest=BESTAND_FEHLT
    Message("Artikel fehlt in Honsel Liste, d.h. KLager Bestand von Honsel unbekannt. @Taste@","@")
    Umgebung(LOAD)
    return
  endif

  // K-Lager extern?
  if getArtikelArt()=="B"
    Message("Artikel ist @interner@ K-Lager Artikel. Zur Bestands�nderung bitte Fremdeingang (AV) "+;
      "benutzen.    Bitte @Taste@ dr�cken","@")
    Umgebung(LOAD)
    return
  endif

  // stimmen HonselNummern uerbein?
  if ! empty(HONSELDA->Honsel_nr) .and.;
    trim(no_blanks(HONSELDA->Honsel_nr))<>trim(no_blanks(ARTIKEL->Hartnr))
    // @ 8,28 say ARTIKEL->HartNr color COLERR
    if Message("Honsel-Nr nicht identisch!  Trotzdem weiterverarbeiten? ( @J@ / @N@ ) ","JN")=="N"
      Umgebung(LOAD)
      return
    endif
  endif

  // stimmen KundeNr uerbein?
  if ! empty(HONSELDA->Konsigkdnr) .and. left(HONSELDA->Konsigkdnr,5)<>left(ARTIKEL->KonsigKdNr,5)
    // @ 8,66 say Artikel->KonsigKdNr color COLERR
    // todo: besser verbieten???
    if Message("Kunden-Nr nicht identisch!  Trotzdem weiterverarbeiten? ( @J@ / @N@ ) ","JN")=="N"
      Umgebung(LOAD)
      return
    endif
  endif

  // 1. Fall: Bestand stimmt ueberein
  do case
  case HONSELDA->HonselBest == HONSELDA->MikiBest
    Error("Lagerbestand stimmt �berein.",.t.)
    // nop
  case HONSELDA->HonselBest > HONSELDA->MikiBest
    // 2. Fall: Honsel hat mehr Artikel als wir wussten => Schummeln
    if KInvBestInc(HONSELDA->HonselBest-HONSELDA->MikiBest,@InvAufNr)
      select HonselDa
      rec_lock(0)
      replace HONSELDA->MikiBest with HONSELDA->HonselBest
      dbcommit()
      dbunlock()
      honsdisp(.f.,.f.)
      Message("Datensatz verarbeitet.           Bitte @Taste@ dr�cken.","@")
    endif

  otherwise // HONSELDA->HonselBest < HONSELDA->MikiBest
    // 3. Fall: Honsel hat weniger Artikel als wir wussten
    // => berechnen, Bestand aktualisieren
    if KInvBestDec(HONSELDA->HonselBest-HONSELDA->MikiBest,@InvAufNr)
      select HonselDa
      rec_lock(0)
      replace HONSELDA->MikiBest with HONSELDA->HonselBest
      dbcommit()
      dbunlock()
      honsdisp(.f.,.f.)
      Message("Datensatz verarbeitet.           Bitte @Taste@ dr�cken.","@")
    endif // Vorschlag �bernehmen
  endcase

  Umgebung(LOAD)

return
/** eop */



/** K-Lager Betand extern erh�hen (manuell), mit schummeln */
Procedure KExternErhoehen
LOCAL M_ArtNr,diff
LOCAL GetList:={}
LOCAL li:=4
LOCAL re:=73
LOCAL ob:=4

  cls
  Titel("Honsel K-Lager Bestand erh�hen")
  if ! open("Artikel","Konsig","AufAus","Kunden")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  M_ArtNr:=space(len(ARTIKEL->ArtNr))
  do while .not. ABBRUCH
    @ ob+ 1,li-2 clear
    Message("Bitte Artikel-Nummer eingeben.    @F12@=Hilfe")
    @ ob+ 3,li say "Miki Artnr............:" get M_ArtNr valid { |oGet| check(oGet,"Artikel",.f.) }
    read

    if ! ABBRUCH

      if empty(left(ARTIKEL->KonsigKdNr,5))
        Error(ACHTUNG+" kein K-Lager Artikel.",.t.)
        loop
      endif
      if getArtikelArt()=="B"
        Error(ACHTUNG+"Artikel ist ein K-Lager-Artikel intern|"+;
          "         Zur Bestands�nderung bitte Fremdeingang (AV) oder 8.40.12 verwenden.",.t.)
        loop
      endif

      select Konsig
      set rela to KONSIG->AufNr into Aufaus
      set filter to KONSIG->ArtNr=ARTIKEL->ArtNr .and. KONSIG->KundNr=ARTIKEL->KonsigKdNr .and. ;
        AUFAUS->AufArt="K" // keine Gutschriften
      go bottom

      if KONSIG->(eof())
        // noch keine K-Lager Lieferung vorhanden -> Hinweis
        Error(ACHTUNG+"noch keine K-Lager Lieferung vorhanden.||"+;
          "         Bitte regul�ren Auftrag & Lieferschein erfassen,|"+;
          "         danach evtl. MIKI-LagerBestand manuell anpassen.",.t.)
        loop
      endif

      @ ob+ 1,li-2 to ob+10,re+2
      @ ob+ 4,li say "Honsel Artnr..........: " + ARTIKEL->HartNr
      @ ob+ 4,li+50 say "Kunden-Nr:  " + ARTIKEL->KonsigKdNr

      @ ob+ 6,li say "Bezeichnung...........: " + ARTIKEL->Bez1
      @ ob+ 7,li say "                        " + ARTIKEL->Bez2

      Message("Bitte die Menge der neuen 'Lieferung' / Erh�hung eingeben.")
      diff:=0
      @ ob+ 9,li+50 say "Miki: " + alltrim(str(ARTIKEL->KonsigBest,9,2))
      @ ob+ 9,li say "Erh�hung.............:" get diff picture "9999999.99" valid diff>0
      read
      if ! ABBRUCH
        AUFAUS->(dbseek(KONSIG->AufNr))
        if AUFAUS->(eof())
          Error(ACHTUNG+" Auftrag:"+KONSIG->Aufnr+" nicht gefunden."+SCHWERER_FEHLER)
        endif
        @ 17,8 say "Auftr.Nr....: "+AUFAUS->AufNr
        @ 18,8 say "Auftr.Datum : "+dtoc(AUFAUS->AufDat)
        @ 19,8 say "Best.Nr.....: "+AUFAUS->BestNr
        @ 20,8 say "Erh�he Bestand um: "+alltrim(str(diff))
        if Message("Vorschlag �bernehmen? ( @J@ / @N@ ) ","JN")=="J"
          // neu seit 4.10.2010
          // ACHTUNG: Erh�hung wird komplett auf letzte Lieferung geschrieben
          // kann falls die Menge > als eigentl. geliefert wurde auffallen
          // Alternative: aufteilen auf alle bereits gelieferten
          // 4.10.2010: besprochen mit H. Weiland, brauchen wir erstmal nicht
          Message("Letzte Lieferung wird gesucht.   Bitte warten....")
          select Konsig
          // set filter to KONSIG->ArtNr=ARTIKEL->ArtNr .and. KONSIG->KundNr=ARTIKEL->KonsigKdNr
          // go bottom
          if ! rec_lock(5)
            Error(TRY_AGAIN)
          else
            REPLACE KONSIG->GeliefGes WITH KONSIG->GeliefGes+diff
            dbcommit()
            dbunlock()
            select Artikel
            if ! rec_lock(5)
              Error(ACHTUNG+" Artikel wird benutzt.  K-Lager Bestand konnte nicht aktualisiert "+;
                "werden!",.t.)
            else
              aendArtKBest(diff,WARAUS_KLAG_LS +;
                KONSIG->LiefNr+" AB:"+AUFAUS->AufNr+" H:"+AUFAUS->BestNr)
              dbcommit()
              dbunlock()
            endif
          endif
          Message("K-Lagerbestand erh�ht.           Bitte @Taste@ dr�cken.","@")
        endif
      endif // abbruch
    endif

  enddo

  cls
  close data
return

/** Honsel K-Lager Betand erh�hen/vermindern (manuell) */
Procedure KInternAendern
LOCAL M_ArtNr,komm:=space(30),diff,mind:=0
LOCAL GetList:={}
LOCAL li:=4
LOCAL re:=73
LOCAL ob:=4

  cls
  Titel("K-Lager Bestand intern �ndern")
  if ! open("Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  M_ArtNr:=space(len(ARTIKEL->ArtNr))
  do while .t.
    @ ob-2,li say "Erh�ht/vermindert den internen K-Lager-Bestand."
    @ ob-1,li say "Der Miki-Bestand wird nicht ge�ndert."
    @ ob+ 1,li-2 clear
    Message("Bitte Artikel-Nummer eingeben.    @F12@=Hilfe")
    @ ob+ 3,li say "Miki Artnr............: " get M_ArtNr;
      valid { |oGet| check(oGet,"Artikel",.f.) }
    read

    if ABBRUCH
      exit
    else

      if empty(left(ARTIKEL->KonsigKdNr,5))
        Error(ACHTUNG+" kein K-Lager Artikel.",.t.)
        loop
      endif
      if getArtikelArt()<>"B"
        Error(ACHTUNG+"Artikel ist ein K-Lager-Artikel extern!|         Zur Bestands�nderung "+;
          "bitte Menu-Punkt 8.40.10/11 verwenden.",.t.)
        loop
      endif
      mind:=ARTIKEL->KonsigMind

      @ ob+ 1,li-2 to ob+11,re+2
      @ ob+ 4,li say "Honsel Artnr..........: " + ARTIKEL->HartNr
      @ ob+ 4,li+50 say "Kunden-Nr:  " + ARTIKEL->KonsigKdNr

      @ ob+ 6,li say "Bezeichnung...........: " + ARTIKEL->Bez1
      @ ob+ 7,li say "                        " + ARTIKEL->Bez2

      diff:=0
      @ ob+ 8,li say "K.Lager Mind.Bestand :" get mind picture "9999999.99" valid mind >=0;
        when Message("Bitte K-Lager Mindestbestand eingeben.")
      @ ob+ 9,;
        li+40 say "K-Lagerbestand intern: " + alltrim(str(ARTIKEL->KonsigBest,9,2)) + space(9)
      @ ob+ 9,li say "Erh�hung.............:" get diff picture "9999999.99";
        when Message("Bitte die Menge der �nderung (@+@/@-@) eingeben.")

      @ ob+ 10,li say "Kommentar............:" get komm valid lastkey() ==K_UP .or. len(alltrim(komm))>5 ;
        when Message("Bitte Kommentar f�r BewegungsDatei (mind. 5 Zeichen) eingeben.")
      read
      if ! ABBRUCH
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        aendArtKBest(diff,komm)
        replace ARTIKEL->KonsigMind with mind
        dbcommit()
        dbunlock()
        @ ob+ 9,;
          li+40 say "K-Lagerbestand intern: " + alltrim(str(ARTIKEL->KonsigBest,9,2)) + space(9)
        Message("K-Lager Bestand wurde angepasst.   Bitte Taste dr�cken.","@")
      endif
    endif

  enddo

  cls
  close data
return

/**
 * liest die Honsel-Inventur-Datei ein
 *
 * Statistik:
 * Zu Haus  lokal auf C:   51 sec
 * xp-Gruhn lokal auf C:  sec
 * xp-Gruhn       auf F:   906 sec
 * Weiland        auf F:   sec
 *
 * FehlerCodes:
 * 1 - ohne oder falsche Miki-Nr bei import
 * 2 - K-Lager Artikel kommt nicht in Liste vor
 * 3 - Artikel ist in Liste, aber kein K-Lager Artikel
 * 4 - HonselNr. ist falsch
  *
  * FIXME: use direct Excel import
  *
  * DateiStruktur �ndern via update.prg
  tempVal:="Honselda"
    datei:=db_Info(tempVal)
    tempArray:={;
    {"SELEKTION","C",    12,    0},;         // Miki-Nr laut Honsel
    {"HONSEL_NR","C",    19,    0},;         // Honsel-Nr
    {"BEZ1","C",    30,    0},;              // Bez. laut Honsel
    {"BEZ1b","C",    30,    0},;              // Bez.2 laut Honsel
    {"HONSELBEST","N",     9,    2},;        // Z�hlbestand Honsel
    {"MIKI_NR","C",     9,    0},;
    {"HONSELVK","N",     9,    2},;
    {"HONSELWERT","N",     9,    2},;
    {"MIKIBEST","N",     9,    2},;
    {"BEZ2","C",    30,    0},;
    {"BEZ3","C",    30,    0},;
    {"FIRMA","C",     3,    0},;
    {"LO","N",     9,    2},;
    {"FEHLER","C",     1,    0},;
    {"KONSIGKDNR","C",     8,    0},;
    {"DIFF","N",     9,    2},;
    {"VK","N",    12,    2},;
    {"DIFFWERT","N",    12,    2}}
    myDBcreate(upper(datei[D_PFAD])+BACKSLASH+tempVal+'.dbf',tempArray)

 */
Procedure honselDatEinles
LOCAL DateiName:=space(30)
LOCAL GetList:={},zeile:=0
LOCAL MKundNr:=space(5),MArtNr:=".",MHonselNr:=".",okay:=.t.
LOCAL time, m503:=" "
LOCAL oExcel, oAS, objErr, summe


  if ! open("System")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  cls
  Titel("Honsel Inventur Datei einlesen")

  Error("INFO: Bitte vorher Inventurbestand �bernehmen.")
  if ABBRUCH
    close data
    return
  endif

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Kunden" , {"Artikel",.t.} , {"HonselDa",.t.} , "System" , "KundSped")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  @ 4,10 say "Kunden-Nr...: " get MKundNr valid mKundNr $ KDNR_HONSEL + "|" + KDNR_VVG ;
    when Message("Kunde eingeben Honsel/VVG   @F12@=Auswahl")
  @ 6,10 say "Inkl. 503er Artikel: " get m503 picture "!" valid m503 $ "JNX" ;
    when Message("@J@=Alle   @N@=ohne 503er  @X@=exklusiv nur 503er")
  read
  if ABBRUCH
    close data
    return
  endif

  if (Dateiname:=openFileDialog(LOAD,IMPORT,NIL,"xlsx",nil))==NIL
    close data
    return
  endif

  select Artikel
  ARTIKEL->(OrdSetFocus(1))

  time:=seconds()

  select Artikel
  repla all ARTIKEL->Temp with trim(no_blanks(ARTIKEL->HartNr)) // wird f. sp�teren import ben�tigt

  select HonselDa
  HONSELDA->(OrdSetFocus(0))
  zap

  // ACHTUNG with ";" geht anscheinend nicht, vorher manuell alle Kommas in Excel Datei ersetzen
  // oder mit OpenOffice exportieren
  // Info: FParse() importiert in Array!
  // append from (alltrim(DateiName)) delimited // Codepage "DEWIN"

  // direkt aus Excel Datei einlesen, seit 13.2.16
  IF ( oExcel:=win_oleCreateObject( "Excel.Application" ) ) == NIL
    Error("EXCEL muss installiert sein!")
    close data
    return
  endif

  oExcel:=openExcelWorkbook( DateiName )
  oAS:=oExcel:ActiveSheet()
  zeile:=2 // starte in 2. Zeile, ignoriere �berschrift
  do while ! empty( oAS:Cells( zeile , 1 ):Value )
    BEGIN SEQUENCE
      add_rec(0)
      replace HONSEL_NR with toString( oAS:Cells( zeile , 1 ):Value ) // Honsel-Nr
      replace SELEKTION with toString( oAS:Cells( zeile , 3 ):Value ) // Miki-Nr laut Honsel
      replace BEZ1 with toString( oAS:Cells( zeile , 2 ):Value ) // Bez. laut Honsel
      replace HONSELBEST with oAS:Cells( zeile , 5 ):Value // Z�hlbestand Honsel
    RECOVER using objErr
      altd() // okay im Fehlerfall in Debug Modus
      qout(zeile)
      wait
    END SEQUENCE
    zeile++
  enddo
  oExcel:DisplayAlerts:=0
  oExcel:Quit()
  zeile:=0

  sum HONSELDA->HONSELBEST to summe
  Error("Kontrollsumme alle Best�nde zusammen: " + transStr(summe) )

  Message("Honsel Inventur Datei wird importiert.")
  select HonselDa
  go top
  do while ! HONSELDA->(eof())
    MArtNr:=alltrim(no_blanks(deleteString(HONSELDA->Selektion,".")))
    if left(MartNr,1) == "M"
      MArtNr:=substr( MArtNr, 2)
    endif

    if ! empty(MArtNr)
      ARTIKEL->(dbseek(MArtNr))
    endif

    Message("Honsel Inventur Datei wird importiert.    @"+HONSELDA->Honsel_Nr+"@")
    if ARTIKEL->(eof()) .or. empty(MartNr)
      replace HONSELDA->Fehler with "1"
      select Artikel
      MHonselNr:=no_blanks(HONSELDA->Honsel_Nr)
      locate for ARTIKEL->Temp==MHonselNr
      if ! ARTIKEL->(eof()) .and. ! empty(HONSELDA->Honsel_Nr)
        schreibeHonselDa(MKundNr)
      else
        // replace HONSELDA->Miki_Nr with MArtNr
        replace HONSELDA->KonsigKdNr with MKundNr
      endif
      select HonselDa
    else
      // okay gefunden anhand Miki Nr
      schreibeHonselDa(MKundNr)

      // Honsel Nr korrekt?
      if ARTIKEL->temp<>no_blanks(HONSELDA->Honsel_Nr)
        replace HONSELDA->Fehler with "4"
      endif
    endif

    // Ausnahme 503er
    if (m503="N" .and. left(ARTIKEL->ArtNr,3)=="503") .or.;
      (m503=="X" .and. left(ARTIKEL->ArtNr,3)<>"503")
      delete
    endif

    skip
  enddo

  Message("Importiere fehlende Artikel.")
  select HonselDa
  HONSELDA->(OrdSetFocus(1))
  select Artikel
  set filter to left(ARTIKEL->KonsigKdNr,5)=MKundNr .and. getArtikelArt()<>"B" .and.;
    ((m503="N" .and. left(ARTIKEL->ArtNr,3)<>"503") .or. (m503=="X" .and.;
    left(ARTIKEL->ArtNr,3)=="503") .or. (m503=="J"))

  go top
  do while ! ARTIKEL->(eof())
    HONSELDA->(dbseek(ARTIKEL->ArtNr))
    Message("Importiere fehlende Artikel.          "+ARTIKEL->ArtNr)
    if HONSELDA->(eof())
      select Honselda
      add_rec(0)
      replace HONSELDA->Miki_Nr with ARTIKEL->ArtNr
      replace HONSELDA->Honsel_Nr with ARTIKEL->HartNr
      replace HONSELDA->Bez2 with ARTIKEL->Bez1
      replace HONSELDA->Bez3 with ARTIKEL->Bez2
      replace HONSELDA->HonselBest with BESTAND_FEHLT
      replace HONSELDA->MikiBest with ARTIKEL->KonsigInv
      replace HONSELDA->Fehler with "2"
      replace HONSELDA->KonsigKdNr with MKundNr
      select Artikel
    endif
    skip
  enddo
  set filter to

  // kopiere alle Art.Nr f�r ALT-A
  select HonselDa
  replace all HONSELDA->ArtNr with HONSELDA->Miki_Nr

  DateiName:=space(30)
  Message("Honsel Datei importiert.   Bitte @Taste@ drucken.  Zeit (sec):"+str(seconds()-time),"@")

  cls
  close data
return
/** EOP honselDatEinles */

static procedure schreibeHonselDa(mKundNr)

  replace HONSELDA->Miki_Nr with ARTIKEL->ArtNr
  replace HONSELDA->MikiBest with ARTIKEL->KonsigInv
  replace HONSELDA->Bez2 with ARTIKEL->Bez1
  replace HONSELDA->Bez3 with ARTIKEL->Bez2
  // replace HONSELDA->Diff with HONSELDA->HonselBest-HONSELDA->MikiBest
  // seit 18.2.2016 negiert -> da import als AB/Rechnung
  replace HONSELDA->Diff with HONSELDA->MikiBest - HONSELDA->HonselBest
  if ARTIKEL->Schluessel=="H"
    replace HONSELDA->VK with ARTIKEL->Preis1/100
  else
    replace HONSELDA->VK with ARTIKEL->Preis1
  endif
  replace HONSELDA->DiffWert with HONSELDA->VK*HONSELDA->diff

  if left(ARTIKEL->KonsigKdNr,5)<>MKundNr
    replace HONSELDA->Fehler with "3"
  else
    replace HONSELDA->KonsigKdNr with MKundNr
  endif
return
/** eop */


/*
 * �ndern des externen KLager Bestandes auf Basis der Inventur (kein Schummeln)
*/
PROCEDURE KInvExtAendern()
LOCAL M_ArtNr
LOCAL GetList:={}, diff, result

  cls
  titel("K-Lager Bestand extern �ndern - Inventur")

  if ! open("Artikel","Aufaus","AvPost","Konsig","BesPost","Inner","Mehrfach")
    close data
    Error(TRY_AGAIN)
    return
  endif

  Protokoll(INIT_P,"K-Lager Extern Inventur Bestand ge�ndert","Art.Nr.  Bez                       "+;
    "        Diff K-LagerBest. (neu)")

  select Artikel
  M_ArtNr:=space(len(ARTIKEL->ArtNr))
  do while .t.
    diff:=0
    @ 1,0 clear
    Message("Artikel-Nummer eingeben.     @F12@=Hilfe")
    @ 5,14 say "Art.Nr.:" get M_ArtNr picture "@!" valid { |oGet| check(oGet,"Artikel",.f.,.f.) }
    read
    if ABBRUCH .or. empty(M_ArtNr)
      exit
    endif
    ArtDisp(.f.,.f.)

    if empty(left(ARTIKEL->KonsigKdNr,5))
      Error(ACHTUNG+" kein K-Lager Artikel.",.t.)
      loop
    endif
    if getArtikelArt()=="B"
      Error(ACHTUNG+"Artikel ist ein K-Lager-Artikel intern|         Zur Bestands�nderung bitte "+;
        "Fremdeingang (AV) oder Menu-Punkt 8.40.12 verwenden.",.t.)
      loop
    endif

    Message("�nderung K-Lager Bestand eingeben (+/-).           @ESC@=Ende")
    setcolor(COLWIN)
    Fenster(13,6,15,40)

    @ 14,08 say "K-Bestand �nderung (+/-):" get diff picture "99999";
      valid (diff + ARTIKEL->KonsigBest)>=0
    read
    if ABBRUCH .or. diff==0
      setcolor(COLNOR)
      loop
    endif
    Fenster(13,6,21,47)
    @ 14,08 say "K-Bestand �nderung (+/-):" +str(diff,5)

    if diff>0
      result:=KInvBestInc(diff)
    else
      result:=KInvBestDec(diff)
    endif
    setcolor(COLNOR)
    if result
      artdisp(.f.,.f.)
      Message("Datensatz verarbeitet.           Bitte @Taste@ dr�cken.","@")
      Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"  "+str(diff,5)+" "+;
        str(ARTIKEL->KonsigBest,9,2))
    endif
  enddo

  Protokoll(PRINT_P,,,,.t.)
  cls
  close data
return
/** eop */


/** �berpr�ft die Datenkonsistenz: ARTIKEL->KonsigBest vs. Konsig.dbf (offene Lieferungen)
*/
Function KKonsistenzCheck()
LOCAL M_KundNr,M_ArtNr,summe,M_recno,protName
  cls
  titel("K-Lager Konsistenz-Check")

  if ! open("Artikel","Konsig")
    close data
    cls
    return .f.
  endif

  // @ 9,19 to 15,60
  // @ 10,21 say 'Dieser Vorgang dauert einige Zeit !'
  // @ 12,21 say 'Bitte Best�tigen (b) '

  // IF ! upper(chr(warte(0))) == "B"
  // cls
  // close data
  // return
  // ENDIF


  select Konsig
  index on KONSIG->KundNr+KONSIG->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for KONSIG->GeliefGes <> KONSIG->Berechnet

  go top
  Protokoll(INIT_P,"K-Lager Konsistenz Check.  Bitte folgende Artikel �berpr�fen:",;
    "Auf.Nr.   Datum      Gelief      Berechnet      Offen")

  // pr�fe ob Anzahl in Konsig.dbf ident zu ARTIKEL->KonsigBest
  do while ! KONSIG->(eof())
    M_KundNr:=KONSIG->KundNr
    M_ArtNr:=KONSIG->ArtNr
    M_recno:=KONSIG->(recno())
    @ 12,21 say M_ArtNr
    summe:=0
    // kein Fracht
    do while len(alltrim(KONSIG->ArtNr)) <= FRACHT_LAENGE
      skip
    enddo

    // nachz�hlen & vergleichen mit Art. Stamm
    do while ! KONSIG->(eof()) .and. M_KundNr==KONSIG->KundNr .and. M_ArtNr==KONSIG->ArtNr
      if KONSIG->GeliefGes <> KONSIG->Berechnet
        summe+= (KONSIG->GeliefGes-KONSIG->Berechnet)
      endif
      skip
    enddo
    ARTIKEL->(dbseek(M_ArtNr))

    if summe<>ARTIKEL->KonsigBest
      // protokollieren
      Protokoll(PROTOKOLL,"Artikel:"+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"  Kunde:"+M_KundNr)
      go (M_recno)
      do while ! KONSIG->(eof()) .and. M_KundNr==KONSIG->KundNr .and. M_ArtNr==KONSIG->ArtNr
        if KONSIG->GeliefGes <> KONSIG->Berechnet
          Protokoll(PROTOKOLL,KONSIG->AufNr+"   "+dtoc(KONSIG->LieDat)+" "+;
            str(KONSIG->GeliefGes,10,2)+"     "+str(KONSIG->Berechnet,10,2)+" "+;
            str(KONSIG->GeliefGes-KONSIG->Berechnet,10,2))
        endif
        skip
      enddo
      Protokoll(PROTOKOLL,"Artikel K.Bestand:"+str(ARTIKEL->KonsigBest,9,2)+"          Summe:"+;
        str(summe,7,0),"")
    endif
  enddo

  // pr�fe ob ARTIKEL->KonsigBest > 0 und KEIN Eintrag in Konsig.dbf oder kein K-Lager Artikel
  select Artikel
  go top
  do while ! ARTIKEL->(eof())
    if getArtikelArt()<>"B" .and. ARTIKEL->KonsigBest>0
      KONSIG->(dbseek(ARTIKEL->KonsigKdNr+ARTIKEL->ArtNr))
      if KONSIG->(eof()) .or. empty(ARTIKEL->KonsigKdNr)
        // protokollieren
        Protokoll(PROTOKOLL,"Artikel:"+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"  Kunde:"+ARTIKEL->KonsigKdNr+;
          "K-Lager-Best.:"+str(ARTIKEL->KonsigBest,9,2))
        Protokoll(PROTOKOLL,"         ohne Eintrag in Konsig.dbf")
      endif
    endif
    skip
  enddo

  @ 9,0 clear
  if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen!")
    protName:=Protokoll(P_FILE_NAME)
    email(MAIN_EMAIL,"Fehler: KLager Konsistenzcheck","Bitte pr�fen",protName)
  else
    // if ! AT_HOME
    // email(MIKI_MAIN_EMAIL,"KLager-Konsistenzcheck okay","Alles okay.")
    // endif
    // email(MY_EMAIL,"KLager-Konsistenzcheck okay","Alles okay.")
  endif

  cls
  close data
return .t.
/** eof */


/*
*
* �bernimmt den aktuellen K-LagerBestand als KInvBestand f�r interne Beistellteile
*/
PROCEDURE KInvIntBestand
LOCAL GetList:={} , Taste:=0
LOCAL currentYear:=year(getUser():date)
LOCAL mDatum:=ctod("31.12."+str(currentYear-1,4))
LOCAL mKundNr:=space(5) , Art:=" "

  cls
  titel("K-Lager Inventurbestand intern �bernehmen")

  if ! open("Artikel", "Kunden", "KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif



  @ 5,08 to 11,76
  @ 6,10 say "Bestand oder Historie: " get Art picture "!" valid Art $ "BH";
    when Message("Art eingeben: @B@estand oder Daten aus @H@istorie? (@B@/@H@)")
  @ 8,10 say "�bernimmt den K-LagerBestand"
  @ 9,10 say "aktuell oder zum Datum als KLager-InventurBestand."
  @ 10,10 say "Nur interne Beistellteile"
  read
  if ABBRUCH
    cls
    close data
    return
  endif

  if art == "B" // Bestand
    mDatum:=getUser():date
    @ 12,08 to 21,76
    @ 13,10 say "�bernimmt den externen K-LagerBestand zum aktuellen Datum."
    @ 15,10 say "Datum / Stichtag..:" + dtoc(mDatum)
  else

    @ 12,08 to 21,76
    @ 13,10 say "�bernimmt den externen K-LagerBestand zum eingegeben Datum."
    @ 15,10 say "Datum / Stichtag..:" get mDatum when Message("Z�hl-Datum eingeben.")
  endif

  @ 17,10 say "K-Lager Kunden-Nr.:" get mKundNr valid mKundNr $ KDNR_HONSEL + "|" + KDNR_VVG ;
    when Message("Kunde eingeben Honsel/VVG   @F12@=Auswahl")
  read

  if ! ABBRUCH

    if Message("Bitte best�tigen @J@=Bestand zum " + dtoc(mDatum) + ;
      " �bernehmen.  @N@/@ESC@=Abbruch","JN"," ") == "J"

      backup("Artikel","pre-KLager-int-Inventurbestand-"+alltrim(TtoS(getUser():date)))
      Message("K-Lager Inventurbestand wird aktualisiert.  Bitte warten...")

      select Artikel
      set filter to ! empty(left(ARTIKEL->KonsigKdNr,5)) .and. getArtikelArt() == "B"

      // Rechnungsposten des Jahres aufaddieren und abziehen
      Protokoll(INIT_P,"K-Lager Intern �bernahme zum "+dtoc(mDatum),;
        "Art.Nr.   Bezeichnung                       Bestand")

      go top
      do while ! ARTIKEL->(eof())

        Message("K-Lager Inventurbestand @"+out(ARTIKEL->ArtNr)+"@ wird aktualisiert.  Bitte "+;
          "warten...")

        select Artikel
        rec_lock(0)

        if Art == "B" // Bestand
          replace ARTIKEL->KonsigInv WITH ARTIKEL->KonsigBest
          replace ARTIKEL->KonsigIDat with mDatum
        else // Daten aus Historie (nachtr�glich)
          replace ARTIKEL->KonsigInv WITH getKLagerBestand(ARTIKEL->ArtNr,mDatum,.t.), ;
            ARTIKEL->KonsigIDat with mDatum
          Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->KonsigInv))
        endif

        dbcommit()
        dbunlock()
        skip
      enddo

      Protokoll(PRINT_P)

    endif
  endif

  cls
  close data

RETURN
/* EOP */


/** Honsel K-Lager R�cklieferung (manuell) */
Procedure KRueckLieferung
LOCAL M_ArtNr,minder:=0
LOCAL GetList:={},teilLieferung,rest
LOCAL li:=4
LOCAL re:=73
LOCAL ob:=4
LOCAL ende:=.f.

  cls
  Titel("Honsel K-Lager R�cklieferung / Bestand mindern")
  if ! open("Artikel","Konsig")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  do while .not. ende
    select Artikel
    M_ArtNr:=space(len(ARTIKEL->ArtNr))
    minder:=0
    @ ob+ 1,li-2 clear to ob+10,re+2
    Message("Bitte Artikel-Nummer eingeben.    @F12@=Hilfe")
    @ ob+ 3,li say "Miki Artnr............: " get M_ArtNr;
      valid { |oGet| check(oGet,"Artikel",.f.) }
    read

    if ABBRUCH
      ende:=.t.
      loop
    endif

    if empty(left(ARTIKEL->KonsigKdNr,5))
      Error(ACHTUNG+" kein K-Lager Artikel.",.t.)
      loop
    endif
    if getArtikelArt()=="B"
      Error(ACHTUNG+"Artikel ist ein K-Lager-Artikel intern|         Zur Bestands�nderung bitte "+;
        "Fremdeingang (AV) oder Menu-Punkt 8.40.12 verwenden.",.t.)
      loop
    endif

    @ ob+ 1,li-2 to ob+10,re+2
    @ ob+ 4,li say "Honsel Artnr..........: " + ARTIKEL->HartNr
    @ ob+ 4,li+50 say "Kunden-Nr:  " + ARTIKEL->KonsigKdNr

    @ ob+ 6,li say "Bezeichnung...........: " + ARTIKEL->Bez1
    @ ob+ 7,li say "                        " + ARTIKEL->Bez2

    Message("Bitte Menge der R�cklieferung eingeben.")
    @ ob+ 9,li+50 say "Akt. K-Bestand: " + alltrim(str(ARTIKEL->KonsigBest,9,2))
    @ ob+ 9,li say "K-Lager R�cklieferung:" get minder picture "9999999.99";
      valid minder>0 .and. minder<=ARTIKEL->KonsigBest
    read
    if ! ABBRUCH
      if Message("Eingabe verarbeiten?  Sind Sie sicher ? (@J@/@N@)","JN")=="J"
        if ! REC_LOCK(5)
          Error(TRY_AGAIN)
        else
          aendArtKBest(minder*(-1),WARAUS_KLAG_RUECKLIEF)
          aendArtBest(minder,WARAUS_KLAG_RUECKLIEF)

          rest:=minder

          // DatenS�tze in Konsig.dbf anpassen (evtl. l�schen?)
          select Konsig
          KONSIG->(OrdSetFocus(3)) // KundNr+Art.Nr
          KONSIG->(dbseek(ARTIKEL->KONSIGKDNR+M_artNr))
          // suche naechsten offenen Auftrag des Kundens/Artikels
          do while rest>0 .and. ! KONSIG->(eof()) .and. KONSIG->KundNr==ARTIKEL->KONSIGKDNR ;
            .and. KONSIG->ArtNr==M_artNr
            if KONSIG->Berechnet < KONSIG->GeliefGes
              teilLieferung:=Min( KONSIG->GeliefGes - KONSIG->Berechnet , rest )
              if REC_LOCK(5)
                REPLACE KONSIG->GeliefGes WITH KONSIG->GeliefGes - teilLieferung
                // REPLACE KONSIG->Gelief WITH KONSIG->Gelief-teilLieferung
                rest:=rest - teilLieferung
              endif
              dbcommit()
              unlock
            endif
            dbskip()
          enddo
          select Artikel
          dbcommit()
          dbunlock()
        endif
      endif
    endif

  enddo

  cls
  close data
return


/*
 * �ndern des internen KLager Bestandes (intern) auf Basis der Inventur (kein Schummeln)
  *
  * ACHTUNG hier d�rfen auch normale Baugruppen ge�ndert werden, die keine K-Lager Artikel sind,
  * aber K-Lager Artikel enthalten k�nnen.
*/
PROCEDURE KInvIntAendern()
LOCAL today:=getUser():date
LOCAL aktJahr:=year(today)
LOCAL GetList:={}, diff, BewGrund, bestandStichtag, klagBestandVorher
LOCAL Zeile:=0, Seite:=0
LOCAL Stop:=.f.

  cls
  titel("K-Lager Bestand intern �ndern - Inventur")

  if ! open("Einheit" , "Avpost" , "AvAus", "Waraus", "Kunden","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  if bewGrund==NIL
    bewGrund:=left( "Inventur " + str( aktJahr -1 , 4) + space(28) , 28)
  endif

  backup("Artikel","pre-"+bewGrund)

  @ 7,12 to 21,74
  @ 08,14 say "Alle Artikel mit einem gez�hlten Lagerbestands in "+alltrim(str(aktJahr))

  @ 10,14 say "- Artikel-Bestand wird angepasst."
  @ 11,14 say "- Eintrag in Bewegungshistorie wird geschrieben:"
  @ 12,14 say "  " + bewGrund

  @ 14,14 say "Falls es ein K-Lager Artikel intern ist, zus�tzlich:"
  @ 15,14 say "- K-Lager-Bestand wird angepasst."
  @ 16,14 say "- K-Lager-Inventur-Bestand wird angepasst."

  @ 18,14 say "Falls der Artikel Beistellteile enth�lt, zus�tzlich:"
  @ 19,14 say "- K-Lager-Bestand aller Beistellteile wird angepasst."
  @ 20,14 say "- K-Lager-Inventur-Bestand Beistellteile wird angepasst."

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  select Artikel
  loca for year(ARTIKEL->InvDate) == aktJahr

  do while .not. ARTIKEL->(eof())
    seite++
    zeile:=0
    ? 'Inventur-�bernahme vom:',getUser():date,space(72), 'Seite',str(seite,3)
    ? replicate('-',121)
    ? 'Art.Nr.     ME  Bezeichnung                    Inv.Datum   Bestand   Z�hlung Differenz'
    ?? ' K-Lager Alt       Neu  Differenz'
    ? replicate('-',121)
    _____fixedHeader_____
    do while .not. ARTIKEL->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->UNT_RAND .and. ! stop
      Message("Artikel @"+out(ARTIKEL->ArtNr)+"@ wird verarbeitet.")
      // if trim(ARTIKEL->ArtNr) == "5062040"
      // altd()
      // endif
      bestandStichtag:=getLagerBestand(ARTIKEL->ArtNr, ARTIKEL->InvDate)
      diff:=ARTIKEL->InvBestand - bestandStichtag
      if ARTIKEL->Lagebest + diff < 0 // kein Lagerbestand unter 0
        diff:=ARTIKEL->Lagebest*(-1)
      endif
      klagBestandVorher:=ARTIKEL->KonsigBest

      if diff <> 0
        // jetzt Lagerbestand, K-Lagerbestand und Unterbaugruppen anpassen
        rec_lock(0)

        // aktueller Lagerbestand anpassen
        aendArtBest( diff , BewGrund )

        // pr�fe ob Beistellteile (KLager intern) enthalten sind
        aendArtRekKbest( ARTIKEL->ArtNr , diff , BewGrund, .t. )

        // update KLager Inv.Bestand
        if getArtikelArt()=="B" .and. ! empty(ARTIKEL->KonsigKdNr)
          replace ARTIKEL->KonsigInv WITH ARTIKEL->KonsigBest
          replace ARTIKEL->KonsigIDat with today
        endif

        dbcommit()
        dbunlock()
      endif

      ? out(ARTIKEL->ArtNr),EINHEIT->Text,ARTIKEL->Bez1
      ?? ARTIKEL->InvDate, str(bestandStichtag,9,2), ARTIKEL->InvBestand,str(diff,9,2), space(3)
      ?? str(klagBestandVorher,9,2), ARTIKEL->KonsigBest,;
        str(ARTIKEL->KonsigBest-klagBestandVorher,9,2)

      if ! empty(ARTIKEL->Bez2)
        ? space(10),ARTIKEL->Bez2
      endif
      cont
      Stop:=stop_key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  if ! AT_HOME
    AufBestand()
  endif

  drucker("OFF")

  cls
  close data
return
    /** eop */

/* Holt den letzten LagerBestand zum Datum aus Waraus */
static function getLagerBestand(mArtNr, mDatum)
LOCAL aktSel:=Alias()
  select Waraus
  index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    WARAUS->ArtNr == mArtnr .and. WARAUS->Datum <= mDatum
  // find last entry
  go bottom
  select (aktSel)
return WARAUS->Best
/** eof */



function honselDatExport
LOCAL excel,objErr,oCol, export, Merk_Satz

  if ! mkMyDir(getUser():exportPATH())
    return .f.
  endif

  Umgebung( WRITE_ALL )

  if (export:=openFileDialog(WRITE,getUser():exportPATH(),export,EXCEL_EXTENSION,nil))<>NIL
    Message("Datei wird erstellt.  Bitte warten.")
    Merk_Satz:=RECNO()
    BEGIN SEQUENCE // krit. Bereich
      excel:=ExcelExport():new()

      excel:addCurrentDBColumns({;
        {"Selektion","Miki Nr. (Honsel)"},;
        {"Honsel_nr","Honsel Nr."},;
        {"Bez1","Bezeichnung (Honsel)"},;
        {"HonselBest","Honsel Bestand"},;
        {"MikiBest","Miki Bestand"},;
        {"ArtNr","Art.Nr. (Miki)"},;
        {"Bez2","Bez1 (Miki)"},;
        {"Bez3","Bez2 (Miki)"},;
        {"KonsigKdNr","K-Lager Kund.Nr."}})

      // f�ge Spalte eigene Honsel Nr
      oCol:=ExcelColumn():new()
      oCol:fieldName:="ARTIKEL->HartNr"
      oCol:title:="Honsel Nr. (Miki)"
      oCol:selected:=.f.
      excel:addColumn(oCol)

      // f�ge Spalte Kalk.Preis hinzu, aber nicht selektiert
      oCol:=ExcelColumn():new()
      oCol:title:="ARTIKEL->KaPr"
      oCol:Codeblock:={ || if(ARTIKEL->Schluessel=="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr) }
      oCol:selected:=.f.
      excel:addColumn(oCol)

      oCol:=ExcelColumn():new()
      oCol:title:="Inventur-Wert"
      oCol:formula:="=( $ARTIKEL->KaPr$ * $HonselBest$ )"
      oCol:Sum:=.t.
      oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
      oCol:selected:=.f.
      excel:addColumn(oCol)

      // deselektiere manche Spalten
      oCol:=excel:getColumnByName("BEZ1B"):selected:=.f.
      oCol:=excel:getColumnByName("Miki_Nr"):selected:=.f.
      oCol:=excel:getColumnByName("HonselVK"):selected:=.f.
      oCol:=excel:getColumnByName("HonselWert"):selected:=.f.
      oCol:=excel:getColumnByName("Firma"):selected:=.f.
      oCol:=excel:getColumnByName("LO"):selected:=.f.
      oCol:=excel:getColumnByName("KonsigKdNr"):selected:=.f.

      // ersetze Fehler durch Text
      oCol:=excel:getColumnByName("Fehler"):Codeblock:={ || getInvFehlerText() }

      // kalkuliere DiffWert in Excel
      oCol:=excel:getColumnByName("DiffWert"):formula:="=( $DIFF$ * $VK$ )"
      oCol:=excel:getColumnByName("DiffWert"):sum:=.t.

      if excel:export(.f.,.f.,export)
        Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
      endif
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
    excel:=NIL
    go (merk_satz)
  endif

  Umgebung( LOAD)

return .t.
/** eof */

static function getInvFehlerText()
LOCAL result:=""
  if ! empty(HONSELDA->Fehler)
    result:=getProperty("Miki.inventur.fehler."+HONSELDA->Fehler,"unbekannter Fehler: "+;
      HONSELDA->Fehler)
  endif
return result
/** eof */

/* Berechnet den KLager-Inv.Bestand eines Artikels wie folgt

  �bernimmt den externen K-LagerBestand
  f�r das gew�hlte Jahr als KLager-InventurBestand.

  Es wird der K-Bestand aus der Historie zum Datum genommen,
  und alle Entnahmen im Folgejahr mit Enddatum im eingegebenen Jahr
  werden abgezogen.

  Diese Variante gilt 2016/2017 f�r 503er Ger�te von VVG 710 mit  flag: zaehleFolgeJahr
  Diese Variante gilt 2016/2017 f�r andere Teile von VVG 800 ohne flag: zaehleFolgeJahr
*/
Function getKLagerBestand(mArtNr,mDatum,prot,zaehleFolgeJahr)
LOCAL count:=0
LOCAL aktSel:=alias()
LOCAL mYear:=year(mDatum)

  default zaehleFolgeJahr:=.f.
  default prot:=.f.

  // suche Bestand zum Datum
  select Waraus
  index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    WARAUS->ArtNr == mArtnr .and. WARAUS->Datum <= mDatum
  // find last entry
  go bottom

  if zaehleFolgeJahr

    ARTIKEL->(dbseek( MArtNr ))
    select RechPost
    set rela to RECHPOST->RechNr into Rechaus

    index on RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for RECHPOST->ArtNr==mArtNr .and. RECHAUS->AufArt=="K" .and. ;
      year(RECHAUS->ReaDat)==mYear+1 .and. ; // nur Folgejahr!!!
    left(ARTIKEL->KONSIGKdNr,5) $ KDNR_HONSEL+"/"+KDNR_VVG .and. getArtikelArt()<>"B" .and.;
      getKLagerYear() == mYear

    go top
    do while ! RECHPOST->(eof())
      count:=0
      mArtNr:=RECHPOST->ArtNr

      do while ! RECHPOST->(eof()) .and. mArtNr == RECHPOST->ArtNr
        count += RECHPOST->Gelief
        skip
      enddo

      if prot .and. count <> 0
        Protokoll(PROTOKOLL,out(ARTIKEL->ArtNr)+" " + ARTIKEL->Bez1 + str(WARAUS->KonsigBest,10);
          + str(count,15) + str( WARAUS->KonsigBest - count , 14 ))
      endif

    enddo
  endif

  select (aktSel)

return WARAUS->KonsigBest - count
/* eof */

/* Liefert das KLager Entnahme Jahr
  * parsed dazu das Feld RECHAUS->BestKonto :(
  * und vergleicht nur das Enddatum!
  */
function getKLagerYear()
LOCAL bis, temp
LOCAL result:=0
LOCAL bLastHandler

  if ! empty( RECHAUS->BestKonto )

    BEGIN SEQUENCE // krit. Bereich
      bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

      if ENTNAHME_LISTE $ RECHAUS->BestKonto .or. ENTNAHME_LISTE $ RECHAUS->BestNr
        temp:=RECHAUS->BestKonto
        if ENTNAHME_LISTE $ RECHAUS->BestKonto
          temp:=trim( substr(RECHAUS->BestKonto , 1, len(ENTNAHME_LISTE) +1) )
        endif

        bis:=ctod( substr( temp , 12, 8 ) )
        result:=year(bis)
      endif

      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      RECOVER // USING objErr
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      // NOP
    END SEQUENCE
  endif

return result
/* eof */



/* 
* Artikel Art B <-> E �ndern f�r interne KLager Beistellteile
*/
PROCEDURE KBeistEkArtikel
LOCAL GetList:={}
LOCAL MyArt:=" ", M_KundNr

  cls
  titel("Beistellteile Art �ndern")

  if ! open("Kunden","KundSped","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  M_KundNr:=space(len(KUNDEN->KundNr))

  @ 10,18 say "Bei alle internen Beistellteile des Kunden mit EK > 0"
  @ 11,18 say "wird die Art �berschrieben."

  @ 13,18 to 17,69
  @ 14,20 say "Kunde....:" get M_KundNr picture KDNR_PICT valid { |oGet| check(oGet,"Kunden") } ;
    when Message("Kunden eingeben.        @F12@=Auswahl    @ESC@=Ende")
  @ 16,20 say "Artikel-Art �ndern:" get MyArt picture "!" valid MyArt$"EB" ;
    when message("Neue Artikel Art eingeben.   @B@ oder @E@")
  read
  if ABBRUCH
    close data
    clear
    RETURN
  endif

  Message("Artikel Art wird ge�ndert.   Bitte warten....")
  backup("Artikel","pre-Beistell-Art-�ndern")
  Protokoll(INIT_P,"Beistellteile Artikel Art ge�ndert -> " + myArt)

  select Artikel
  loca for ARTIKEL->Art==if(MyArt=="E","B","E") .and.;
    ARTIKEL->KonsigKdNr==M_kundNr .and. ARTIKEL->EKPR > 0

  do while ! ARTIKEL->(eof())
    if ! rec_lock(5)
      Error(ACHTUNG+"Artikel: "+ out(ARTIKEL->ArtNr)+" konnte nicht angepasst werden.")
    else
      @ maxrow(),maxcol()-8 say out(ARTIKEL->ArtNr)
      replace ARTIKEL->Art with MyArt
      if myArt == "B"
        replace ARTIKEL->Kapr with 0
      endif
      dbcommit()
      dbunlock()
      Protokoll(PROTOKOLL,out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+" "+ARTIKEL->Bez2+" EK:"+;
        str(ARTIKEL->EkPr))
    endif
    cont
  enddo

  if myArt=="E"
    Message("EK wird neu berechnet")
    Preis_EWArtikel()
  endif

  Protokoll(P_CREATE_PDF)

  close data
  clear
RETURN
/** eop */


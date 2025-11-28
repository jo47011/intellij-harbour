/** Bestell2.prg
 *
 * enthaelt Teile der Bestellung, sowie Bestellung drucken
 */

#include "Miki.ch"
#include "Zeige.ch"

/** folgende Abstaende sind von unten gezaehlt */
#define UNT_RAND 8

// Bestellkarte Historieneintrag in Grau bzw. leer
#define BEST_HISTORIE { || if(BESTTEMP->Historie == 'J', 'N+/'+getBackColor() , nil) }
#define BEST_HISTORIE_LEER { || if(BESTTEMP->Historie == 'J', 'W/W,W/W,W/W,W/W,W/W' , nil) }


/* Best_Plan    *********************************************************
*
* aktuelle Bestell�berwachung
*
* Hinweis: alter Adel, k�nnte durch LiefBestellListe oder BestellListe ersetzt werden
*/

PROCEDURE Best_Plan
LOCAL KalWoch:=space(5),abruf:="N"
LOCAL x:=1,gel:=0,Pseudo_gel:=0
LOCAL Feld:="",MengVar:=""
LOCAL Seite:=0 , zeile:=0
LOCAL Stop:=.f. , Taste:=0
LOCAL GetList:={}

  cls
  if ! open( "BesAus" , "BesPost" , "BestPlan" ,"Einheit")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzen */
  select BesPost
  SET RELATION to BESPOST->BestNr INTO Besaus
  select BestPlan
  SET RELATION to BESTPLAN->ME INTO Einheit
  // seit 24.3.2012 erledigte Bestellungen ausblenden
  set filter to BESAUS->Erledigt<>"J"

  Titel("Bestell�berwachung")

  Message("Bitte gew�nschte Kalenderwoche eingeben.")
  @ 8,12 to 12,55
  @ 9,14 say "Kalenderwoche..................:" get kalwoch PICTURE "!!/99"
  @ 11,14 say "mit Abrufauftr�gen ?  ( J / N ):" get abruf PICTURE "!" valid Abruf $"JN"
  read
  taste=lastkey()
  if kalwoch="  /  " .or. Taste = K_ESC
    clear
    close data
    return
  endif
  Message("Bitte warten...               Datei wird erstellt.")

  SELECT BestPlan
  zap
  SELECT BesPost
  Go Top
  do while .not. eof() .and. ! stop
    do while .not. eof() .and. ! stop .and. ( ;
      .not. (BESPOST->Menge > BESPOST->GeliefGes .and. kwKleiner(BesPOST->kw,kalwoch)>=0);
      .or. ( Abruf="N" .and. substr(BESPOST->Kw,1,2) $ " 00  ") )
      skip
    enddo
    if ! KWempty(BESPOST->KW)
      SELECT BestPlan
      ADD_REC(5)
      REPLACE BESTPLAN->BestNr WITH BESPOST->Bestnr
      REPLACE BESTPLAN->ArtNr WITH BESPOST->ArtNr
      REPLACE BESTPLAN->Bez1 WITH BESPOST->Komm1
      REPLACE BESTPLAN->KW WITH BESPOST->KW
      REPLACE BESTPLAN->Menge WITH BESPOST->Menge - BESPOST->GeliefGes
      REPLACE BESTPLAN->ME WITH BESPOST->ME
      REPLACE BESTPLAN->Kunde WITH BESAUS->LiefNr
      REPLACE BESTPLAN->KurzName WITH BESAUS->KurzName
    else
      x=1
      gel=0
      pseudo_gel=BESPOST->GeliefGes
      Feld="BESAUS->KW"+str(x,1)
      MengVar="BESAUS->Meng"+str(x,1)
      do while ! KWempty(&Feld) .and. kwKleiner(&Feld,kalwoch) <= 0 ;
        .and. ! stop
        MengVar="BESAUS->Meng"+str(x,1)
        gel=gel + &MengVar
        if gel > Pseudo_Gel
          SELECT BestPlan
          ADD_REC(5)
          REPLACE BESTPLAN->BestNr WITH BESPOST->Bestnr
          REPLACE BESTPLAN->ArtNr WITH BESPOST->ArtNr
          REPLACE BESTPLAN->Bez1 WITH BESPOST->Komm1
          REPLACE BESTPLAN->KW WITH &Feld
          REPLACE BESTPLAN->Menge WITH gel-Pseudo_Gel
          REPLACE BESTPLAN->ME WITH BESPOST->ME
          REPLACE BESTPLAN->Kunde WITH BESAUS->LiefNr
          REPLACE BESTPLAN->KurzName WITH BESAUS->KurzName
          Pseudo_Gel = gel
          // ? "gel:",str(gel,9,2),"     Pseudo_gel:",str(Pseudo_gel,9,2),"  Menge:",str(&mengVar,9,2)
        endif
        x=x+1
        if x > 6
          exit
        endif
        Feld="BESAUS->KW"+str(x,1)
      enddo
    endif
    SELECT BesPost
    skip
  enddo

  SELECT BestPlan
  if reccount()==0
    @ 22,0 clear
    ERROR("Keine Lieferungen mehr!")
    clear
    // SET Confirm off // raus am 16.2.2012
    close data
    return
  endif
  Message("Bitte warten...               Datei wird sortiert.")
  reindex
  go top

  /* Ausgabe auf Drucker oder BS */
  if ! druck_Bs()
    close data
    RETURN
  endif

  Stop:=stop_key()
  do while .not.eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Bestellungen f�r Kalenderwoche:',kalwoch,'     vom:',getUser():date,space(23),'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------------------------'
    ? 'Lief. Name       Best.Nr. Art.Nr.     Bezeichnung                        Menge ME    KW'
    ? '------------------------------------------------------------------------------------------'
    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? BESTPLAN->Kunde,substr(BESTPLAN->Kurzname,1,10),ZEIGE_BESTNR+BESTPLAN->BestNr,space(2),;
        ZEIGE_ARTNR+OUT(BESTPLAN->ArtNr),space(1),BESTPLAN->bez1,BESTPLAN->Menge,EINHEIT->Text
      if kwKleiner(BESTPLAN->kw,kalwoch) >= 0
        ?? " ",BESTPLAN->kw
      endif
      skip
      Stop:=stop_key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  drucker("Off")
  CLOSE DATA
RETURN
/* EOP Best_Plan */



/* Function WE_Druck  ******************************************
*
*   Wareneingang-Protokoll
*/

FUNCTION WE_Druck
LOCAL seite:=0, Zeile:=0,proz:=0
LOCAL SumSoll:=0.00,SumIst:=0.00,SumPreis:=0.00
LOCAL stop:=.f.
  if ! Drucker('ON')
    return(.f.)
  endif
  Stop:=stop_key()
  SELECT Warenein
  go top
  do while .not.eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'WARENEINGANGS - PROTOKOLL    vom:',getUser():date,space(20),LIEFERAN->kurzName,space(23),;
      'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '---------------------------------'
    ? 'Art.Nr.    Lief.Nr.   Bezeichnung                      Menge  Gewicht       Soll        '+;
      'Ist   Differenz           Ges-Preis'
    ? '------------------------------------------------------------------------------------------'+;
      '---------------------------------'
    do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? Out(WARENEIN->ArtNr),WARENEIN->LsNr,WARENEIN->Komm1,WARENEIN->Menge,WARENEIN->Gewicht,;
        WARENEIN->Soll,WARENEIN->Ist,str(WARENEIN->Ist-WARENEIN->Soll,11,2)
      sumIst =SumIst +WARENEIN->Ist
      sumSoll=SumSoll+WARENEIN->Soll
      if WARENEIN->soll <> 0
        Proz=ROUND(((WARENEIN->Ist-WARENEIN->Soll)/WARENEIN->soll*100),2)
        if WARENEIN->Schluessel="H"
          ?? space(0),str(Proz,6,2)+"%",str(WARENEIN->Menge*WARENEIN->Preis*Proz/10000,11,2)
          sumpreis=sumpreis+ROUND(WARENEIN->Menge*WARENEIN->Preis*Proz/10000,2)
        else
          ?? space(0),str(Proz,6,2)+"%",str(WARENEIN->Menge*WARENEIN->Preis*Proz/100,11,2)
          sumpreis=sumpreis+ROUND(WARENEIN->Menge*WARENEIN->Preis*Proz/100,2)
        endif
      else
        ?? " ***"
      endif
      if .not. empty(WARENEIN->komm2)
        ? space(len(out(WARENEIN->ArtNr))),WARENEIN->komm2
      endif
      skip
      Stop:=stop_key()
    enddo
    ? '------------------------------------------------------------------------------------------'+;
      '-------------------------------'
    ? space(68),str(SumSoll,10,3),str(SumIst,10,3),space(18),str(SumPreis,12,2)

    Zeile:=FormFeed(Zeile,Seite)

  enddo
  Drucker("OFF")
  cls
return(.t.)
/* EOF We_Druck */




/* PROCEDURE Art_BestKarte
*
* erfassen und anzeigen der Artikel-BestellKarte
*/
FUNCTION Art_BestKarte(edit)
LOCAL GetList:={}
LOCAL erg:="",MartNr:=ARTIKEL->ArtNr, orgOrder
LOCAL aFelder:={} , posx, posy, merkRecno, starteBeiRecno
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE_ALL)

  if ! open( "BestKart","Lieferan" ,"BestTemp")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN("")
  endif

  select BestTemp
  zap
  set relation to BESTTEMP->LiefNr into Lieferan

  /* hole BestellKarte, inkl. lock */
  select BestKart
  BESTKART->(dbseek(MArtNr))
  do while ! BESTKART->(eof()) .and. MArtNr==BESTKART->ArtNr
    if ! rec_lock(5,.t.) // BestKarte gelockt lassen!
      dbunlockall()
      Umgebung(LOAD)
      RETURN("")
    endif
    select BestTemp
    add_rec(0)
    overwrite( "BestKart" )
    select BestKart
    skip
  enddo

  // Hinweis: Herr Weiland wollte hier Historien-Eintr�ge (�pfel) mit
  // Bestellkarten-Eintr�gen (Birnen) gemischt. Das habe ich
  // nach sehr langem hin und her mit Herrn Weiland auf dessen
  // ausdr�cklichen Wunsch wieder eingef�hrt. Zitat von mir:
  // "Ich gebe auf!" => Kunde ist K�nig 14.1.2015
  //
  // Allerdings werden die Eintr�ge nicht in die Bestellkarte
  // geschrieben, sondern hier aus der Bestellhistorie zur Bestkarte
  // inzugef�gt.

  orgOrder:=BESPOST->(indexOrd())
  select BesPost
  index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for mArtNr == BESPOST->ArtNr
  go top
  do while ! BESPOST->(eof())
    // pr�fe ob Bestellung bereits in Bestellkarte vorkommt -> dann nicht anzeigen
    // unlogisch, aber Wunsch von H. Weiland 02/2015

    // 14.3.2015 wieder raus, alle anzeigen

    select BESTTEMP
    // loca for BESTTEMP->BestNr == BESPOST->BestNr .and. BESTTEMP->Historie <> "J"
    // if eof()
    add_rec(0)
    copy2Besttemp()
    // endif
    select BesPost
    skip
  enddo
  BESPOST->(OrdDestroy(TEMP_INDEX))
  BESPOST->(OrdSetFocus( orgOrder ))

  // sortiere temp. Bestkarte
  // Reihenfolge: neue Rabattstaffel (ohne zugeh. Bestellung) oben
  // falls Rabattstaffel benutzt (mit zugeh. Bestellung) dann nach Bestellposten
  select BESTTEMP
  index;
    on;
    mydescend(BESTTEMP->Datum)+if(empty(BESTTEMP->BestNr),"00000",mydescend(BESTTEMP->BestNr))+;
    if(empty(BESTTEMP->gekauft) .or.;
    BESTTEMP->Historie <> "J","B",;
    "A")+BESTTEMP->LiefNr+BESTTEMP->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE

  EINHEIT->(dbseek( ARTIKEL->ME ))

  set key K_F5 to toggleME()
  do while ! ABBRUCH .or. starteBeiRecno==NIL
    aFelder:={}
    select BestTemp
    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=11 // N: Begin des Eingabe-Berreiches BS
    // aKopf[EDIT_ENDE_Y]:=22 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_LM]:=00 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_RM]:=79 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_GESPERRT]:={ || if(BESTTEMP->Historie == "J", "�ZLKZ" , "�KZ" ) }

    if ! edit
      aKopf[EDIT_GESPERRT]:="�ZLNEK"
    endif

    if valtype(starteBeiRecno)=="N"
      aKopf[EDIT_START_REC]:=starteBeiRecno
    endif

    aKopf[EDIT_EXTRA_FKT]:={}
    aadd(aKopf[EDIT_EXTRA_FKT],{ "A�","", { || bestkartEdit() } } )

    if ! empty( ARTIKEL->ME2 )
      // hole anderen Einheittext f�r Message
      merkRecno:=EINHEIT->(recno())
      if EINHEIT->ME == ARTIKEL->ME
        EINHEIT->(dbseek( ARTIKEL->ME2 ))
      else
        EINHEIT->(dbseek( ARTIKEL->ME ))
      endif
      aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@="+;
        alltrim(EINHEIT->Kommentar), { || toggleMe() }})
      // zur�ck zur aktuellen Einheit
      EINHEIT->(dbgoto( merkRecno ))
    endif
    aKopf[EDIT_DRAW_FRAME]:="L i e f e r a n t e n    ("+alltrim( EINHEIT->Kommentar ) +")"

    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F9)," @F9@=off.Best.", { || LiefBestellListe() }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ "bB" , " @B@=neue Best.", { || launchNeueBestellung() }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ "hH" , " @H@/@STRG-H@istorie", ;
      { || liefBestHist( BESTTEMP->LiefNr,ARTIKEL->ArtNr) }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_H) , "", { || liefBestHist( nil,ARTIKEL->ArtNr) }})

    aKopf[EDIT_NEW_FKT]:=;
      { || _FIELD->BESTTEMP->LiefME:=EINHEIT->ME, _FIELD->BESTTEMP->Datum:=getUser():date }

    // /* Fenster-Rahmen */
    // setcolor(COLWIN)
    // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]-1 clear to aKopf[EDIT_ENDE_Y]+1,aKopf[EDIT_RM]+1
    // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]+25 say "L i e f e r a n t e n"
    // setcolor(COLNOR)


    /* Feld-Definitionen */
    aSpalte:=e_fill() // initialisieren
    // Lieferanten-Nr.
    aSpalte[EDIT_NAME]:="LiefNr"
    aSpalte[EDIT_TITEL]:="Lief."
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Lieferan",.f.,.f.) .and. Art_Lief_Nach() }
    aSpalte[EDIT_MESSAGE]:="Lieferanten-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="'ME:'"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_MESSAGE]:="Bevorzugte Mengeneinheit des Lieferanten eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="LiefME"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_AFTER]:={ |oGet| me_nach(oGet) .and. check4toggle(oGet,aKopf,aFelder) }
    aSpalte[EDIT_MESSAGE]:="Bevorzugte Mengeneinheit des Lieferanten eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="LiefMeDisp()"
    aSpalte[EDIT_TITEL]:="Name"
    aSpalte[EDIT_POS_X]:=2
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="left(LIEFERAN->Kurzname,20)"
    aSpalte[EDIT_TITEL]:="Name"
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="LIEFERAN->Telefon"
    aSpalte[EDIT_TITEL]:="Telefon"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="'Datum:'"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Datum"
    aSpalte[EDIT_TITEL]:="Erf.Datum"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_POS_X]:=8
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE
    aSpalte[EDIT_MESSAGE]:="Erfassungs-Datum eingeben         @*@=Heute @+@/@-@"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // 3. Zeile Rabatt
    posy:=2
    posx:=21
    aSpalte[EDIT_NAME]:="'Rabatt:'"
    aSpalte[EDIT_POS_Y]:=posy
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Rabatt"
    aSpalte[EDIT_POS_Y]:=posy
    aSpalte[EDIT_POS_X]:=posx + 7
    aSpalte[EDIT_AFTER]:={ |oGet| rab_nach(oGet) }
    // aSpalte[EDIT_MASKE]:="@Z"
    aSpalte[EDIT_MESSAGE]:="Rabatt in % eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // 1. & 2. Zeile
    posx:=0
    posy:=0
    aSpalte[EDIT_NAME]:="'Menge: '+EINHEIT->Text"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posy
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="'Preis:'"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 1
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    posx:=2
    aSpalte[EDIT_NAME]:="Menge1"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
    aSpalte[EDIT_MASKE]:="9999999"
    aSpalte[EDIT_POS_Y]:=posY
    aSpalte[EDIT_MESSAGE]:="Menge 1 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Preis1"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_MASKE]:="9999.99"
    aSpalte[EDIT_POS_Y]:=posY + 1
    aSpalte[EDIT_MESSAGE]:="Preis 1 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="str(Preis1-Preis1*Rabatt/100,7,2)"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 2
    aSpalte[EDIT_FARBE];
      :={ || if(BESTTEMP->Preis1<>0,"R/"+getBackColor(), getBackColor()+"/"+getBackColor()) }
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    posx:=1
    aSpalte[EDIT_NAME]:="Menge2"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
    aSpalte[EDIT_MASKE]:="9999999"
    aSpalte[EDIT_POS_Y]:=posY
    aSpalte[EDIT_MESSAGE]:="Menge 2 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Preis2"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_MASKE]:="9999.99"
    aSpalte[EDIT_POS_Y]:=posY + 1
    aSpalte[EDIT_MESSAGE]:="Preis 2 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="str(Preis2-Preis2*Rabatt/100,7,2)"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 2
    aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis2<>0,"R/W","W/W") }
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    posx:=1
    aSpalte[EDIT_NAME]:="Menge3"
    aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY
    aSpalte[EDIT_MASKE]:="9999999"
    aSpalte[EDIT_MESSAGE]:="Menge 3 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Preis3"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 1
    aSpalte[EDIT_MASKE]:="9999.99"
    aSpalte[EDIT_MESSAGE]:="Preis 3 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="str(Preis3-Preis3*Rabatt/100,7,2)"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 2
    aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis3<>0,"R/W","W/W") }
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    posx:=1
    aSpalte[EDIT_NAME]:="Menge4"
    aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY
    aSpalte[EDIT_MASKE]:="9999999"
    aSpalte[EDIT_MESSAGE]:="Menge 4 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Preis4"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 1
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_MASKE]:="9999.99"
    aSpalte[EDIT_MESSAGE]:="Preis 4 eingeben."
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="str(Preis4-Preis4*Rabatt/100,7,2)"
    aSpalte[EDIT_POS_X]:=posx
    aSpalte[EDIT_POS_Y]:=posY + 2
    aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis4<>0,"R/W","W/W") }
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE_LEER

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Hinweis: bei der Bestellkarte zeigt er hier vorerst die KW des Erfass.Datum an
    // da lt. MW die Zuodnung zur Bestellung nicht korrekt ist.
    aSpalte[EDIT_NAME]:="if(BESTTEMP->Historie == 'J', getKW(BESTTEMP->gekauft) , space(5) )"
    aSpalte[EDIT_TITEL]:="KW"
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="if(empty(BESTTEMP->BestNr),space(5),'Nr.:')"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // FIXME: s.o. Zuordnung zur Bestellung k�nnte bei alten Posten falsch sein
    aSpalte[EDIT_NAME]:="BESTTEMP->BestNr"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_EDIT]:=.f.
    aSpalte[EDIT_FARBE]:=BEST_HISTORIE

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    Edit(aFelder,aKopf)
    starteBeiRecno:=BESTTEMP->(recno())
  enddo

  erg:=BESTTEMP->LiefNr

  if aKopf[EDIT_CHANGED]
    /* schreibe Bestellkarte zur�ck */
    if EINHEIT->ME <> ARTIKEL->ME
      toggleMe() // immer in 1. Einheit des Artikels speichern
    endif

    // remove history entries from temp card
    select BestTemp
    dele for BESTTEMP->Historie == "J"
    go top

    select BestKart
    BESTKART->(dbseek(MArtnr))
    // l�sche alte Best.Karte
    do while ! BESTKART->(eof()) .and. MArtNr==BESTKART->ArtNr
      rec_lock(0)
      delete
      BESTKART->(dbskip())
    enddo
    // h�nge neu an
    BESTTEMP->(dbgotop())
    append("BestTemp",{ || .t. })

  endif
  dbcommitall()
  dbunlockall()

  Umgebung(LOAD)

  set key K_F5 to

RETURN(erg)
/* EoF Art_BestKarte */


/* FUNCTION Rab_nach
*
* wird nach Eingabe des Rabtts bei Bestellkarte ausgef�hrt
*/
FUNCTION Rab_nach(oGet)
  if oGet:changed()
    if val(oGet:Buffer) < 0
      // Neg. Rabatt nicht m�glich!
      return .f.
    endif
    // if val(oGet:Buffer) <> 0 .and. rec_lock(5)
    // replace BESTTEMP->Menge2 with 0
    // replace BESTTEMP->Menge3 with 0
    // replace BESTTEMP->Menge4 with 0
    // replace BESTTEMP->Preis2 with 0
    // replace BESTTEMP->Preis3 with 0
    // replace BESTTEMP->Preis4 with 0
    // endif
  endif
RETURN .t.
/* EOF Rab_nach() */

/*
* wird nach Eingabe der Mengeneinheit ausgef�hrt
*/
FUNCTION Me_nach(oGet) // wichtig Methode nicht umbenennen
LOCAL aktRec:=EINHEIT->(recno())
LOCAL errText, aktText

  if oGet:changed()
    if empty(oGet:buffer)
      Error(ACHTUNG+"Mengeneinheit des Lieferanten muss eingegeben werden.")
      return .f.
    endif

    if ! check(oGet,"Einheit",.f.,.f.)
      return .f.
    endif

    // pr�fe Mengeneinheit
    if ! oGet:buffer $ ARTIKEL->ME + ARTIKEL->ME2
      Einheit->(dbseek(ARTIKEL->ME))
      errText:=alltrim( EINHEIT->Text )
      if ! empty( ARTIKEL->ME2 )
        Einheit->(dbseek(ARTIKEL->ME2))
        errText += " und "+ alltrim( EINHEIT->Text )
      endif
      Error(ACHTUNG+"Bestellung nur in hinterlegten Mengeneinheiten zugelassen:|| "+;
        "        "+errText,.t.)
      EINHEIT->(dbgoto(aktRec))
      return .f.
    endif
    aktText:=EINHEIT->Kommentar

    EINHEIT->(dbgoto(aktRec)) // zur�ck auf Display Einheit

  endif

RETURN .t.
/* EOF Rab_nach() */

/** pr�ft ob aktuelle Einheit ge�ndert wurde bzw. abweicht und rechnet alle Posten um */
function check4toggle(oGet,aKopf,aFelder)
  // zeige Rabatttabelle immer in Wunscheinheit des akt. Lieferanten beim Editieren
  if oGet:Buffer <> EINHEIT->ME .and. oGet:changed
    toggleValues()
    aFelder[getColPosByName(aFelder,"LiefME")][EDIT_BS_AUSGABE]:=.t.
    drawEditFrame( aKopf, aFelder , "L i e f e r a n t e n    ("+alltrim( EINHEIT->Kommentar ) +;
      ")" )
  endif
return .t.
/** eof */




/*
* Anzeige der Mengeneinheit Lieferanten
*/
FUNCTION LiefMeDisp()
LOCAL aktRec, result
  if BESTTEMP->LiefME <> EINHEIT->ME
    aktRec:=EINHEIT->(recno())
    EINHEIT->(dbseek( BESTTEMP->LiefME ))
    result:=EINHEIT->Text
    EINHEIT->(dbgoto( aktRec ))
  else
    result:=EINHEIT->Text
  endif
RETURN result
/* EOF */


/* FUNCTION Art_Lief_Nach
*
* wird nach Eingabe der Lieferantennr. bei Artikel-Bestellkarte ausgef.
*/
FUNCTION Art_Lief_Nach
  replace BESTTEMP->ArtNr with ARTIKEL->ArtNr
RETURN(.t.)
/* EOF Art_Lief_nach */


/* PROCEDURE Lief_BestKarte
*
* erfassen und anzeigen der Artikel-BestellKarte je Lieferant
*/
PROCEDURE Lief_BestKarte()
LOCAL GetList:={},mLiefNr:=LIEFERAN->LiefNr
LOCAL aFelder:={} , posx, posy
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE)

  if ! open( "BestKart","Lieferan" ,"BestTemp","Artikel","Einheit")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif


  select BestKart
  BESTKART->(OrdSetFocus(2)) // Lieferant
  select BestTemp
  zap
  set relation to BESTTEMP->ArtNr into Artikel
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  /* hole BestellKarte, inkl. lock */
  select BestKart
  BESTKART->(dbseek(MLiefNr))
  do while ! BESTKART->(eof()) .and. MLiefNr==BESTKART->Liefnr
    rec_lock(0,.t.) // BestKarte gelockt lassen!
    select BestTemp
    add_rec(0)
    overwrite( "BestKart" )
    select BestKart
    skip
  enddo


  select BestTemp
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  // aKopf[EDIT_ENDE_Y]:=22 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_LM]:=00 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=79 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="K"
  aKopf[EDIT_DRAW_FRAME]:="Bestell-Karte"

  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ "bB" , " @B@=neue Best.", { || launchNeueBestellung() }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ "hH" , " @H@/@STRG-H@istorie", { || liefBestHist( BESTTEMP->LiefNr,;
    ARTIKEL->ArtNr) }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_H) , "", { || liefBestHist( nil,ARTIKEL->ArtNr) }})
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->BESTTEMP->Datum:=getUser():date }

  // /* Fenster-Rahmen */
  // setcolor(COLWIN)
  // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]-1 clear to aKopf[EDIT_ENDE_Y]+1,aKopf[EDIT_RM]+1
  // setcolor(COLNOR)


  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  // Artikel-Nr.
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.,.f.) .and. Lief_Art_Nach() }
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="'ME:'"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MESSAGE]:="Bevorzugte Mengeneinheit des Lieferanten eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="LiefME"
  aSpalte[EDIT_POS_Y]:=2
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oGet| me_nach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Bevorzugte Mengeneinheit des Lieferanten eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="LiefMeDisp()"
  aSpalte[EDIT_TITEL]:="Name"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_POS_Y]:=2
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  aSpalte[EDIT_NAME]:="left(ARTIKEL->Bez1,17)"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  aSpalte[EDIT_NAME]:="'Dat:'"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_MESSAGE]:="Erfassungs-Datum eingeben         @*@=Heute @+@/@-@"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Datum"
  aSpalte[EDIT_TITEL]:="Erf.Datum"
  aSpalte[EDIT_POS_Y]:=2
  aSpalte[EDIT_POS_X]:=8
  aSpalte[EDIT_MESSAGE]:="Erfassungs-Datum eingeben         @*@=Heute @+@/@-@"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // 3. Zeile Rabatt
  posy:=2
  posx:=18
  aSpalte[EDIT_NAME]:="'Rabatt:'"
  aSpalte[EDIT_POS_Y]:=posy
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Rabatt"
  aSpalte[EDIT_POS_Y]:=posy
  aSpalte[EDIT_POS_X]:=posx + 7
  aSpalte[EDIT_AFTER]:={ |oGet| rab_nach(oGet) }
  // aSpalte[EDIT_MASKE]:="@Z"
  aSpalte[EDIT_MESSAGE]:="Rabatt in % eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // 1. & 2. Zeile
  posx:=0
  posy:=0
  aSpalte[EDIT_NAME]:="'Menge: '+EINHEIT->Text"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posy
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Preis:'"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  posx:=2
  aSpalte[EDIT_NAME]:="Menge1"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
  aSpalte[EDIT_POS_Y]:=posY
  aSpalte[EDIT_MESSAGE]:="Menge 1 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Preis1"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 1
  aSpalte[EDIT_MASKE]:="9999.99"
  aSpalte[EDIT_MESSAGE]:="Preis 1 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(Preis1-Preis1*Rabatt/100,7,2)"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 2
  aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis1<>0,"R/W","W/W") }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  posx:=1
  aSpalte[EDIT_NAME]:="Menge2"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
  aSpalte[EDIT_POS_Y]:=posY
  aSpalte[EDIT_MESSAGE]:="Menge 2 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Preis2"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 1
  aSpalte[EDIT_MASKE]:="9999.99"
  aSpalte[EDIT_MESSAGE]:="Preis 2 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(Preis2-Preis2*Rabatt/100,7,2)"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 2
  aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis2<>0,"R/W","W/W") }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  posx:=1
  aSpalte[EDIT_NAME]:="Menge3"
  aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY
  aSpalte[EDIT_MESSAGE]:="Menge 3 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Preis3"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 1
  aSpalte[EDIT_MASKE]:="9999.99"
  aSpalte[EDIT_MESSAGE]:="Preis 3 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(Preis3-Preis3*Rabatt/100,7,2)"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 2
  aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis3<>0,"R/W","W/W") }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  posx:=1
  aSpalte[EDIT_NAME]:="Menge4"
  aSpalte[EDIT_TITEL]:="Menge/"+EURO_SIGN
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY
  aSpalte[EDIT_MESSAGE]:="Menge 4 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Preis4"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 1
  aSpalte[EDIT_MASKE]:="9999.99"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Preis 4 eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(Preis4-Preis4*Rabatt/100,7,2)"
  aSpalte[EDIT_POS_X]:=posx
  aSpalte[EDIT_POS_Y]:=posY + 2
  aSpalte[EDIT_FARBE]:={ || if(BESTTEMP->Preis4<>0,"R/W","W/W") }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="getKW(BESTTEMP->gekauft)"
  aSpalte[EDIT_TITEL]:="KW"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  Edit(aFelder,aKopf)

  BESTTEMP->(dbgotop())

  /* schreibe Bestellkarte zur�ck */
  if aKopf[EDIT_CHANGED]
    select BestKart
    // l�sche alte
    BESTKART->(dbseek(MLiefNr))
    do while ! BESTKART->(eof()) .and. BESTKART->LiefNr==MLiefNr
      rec_lock(0)
      delete
      BESTKART->(dbskip())
    enddo
    // kopiere neue
    append("BestTemp",{ || .t. })

  endif
  dbcommitall()
  dbunlockall()

  Umgebung(LOAD)

RETURN
/* EoP Lief_BestKarte */

/* FUNCTION Lief_Art_Nach
*
* wird nach Eingabe der Artikel-nr. bei Liefer.-Bestellkarte ausgef.
*/
FUNCTION Lief_Art_Nach
  replace BESTTEMP->LiefNr with LIEFERAN->LiefNr
RETURN(.t.)
/* EOF Art_Lief_nach */

/* PROCEDURE Art_F10Karte
*
* ruft die Artikel-Bestellkarte auf, und blockiert F10
*/
PROCEDURE Art_F10Karte
LOCAL merk_Lief:=LIEFERAN->(recno())

  set key K_F10 to
  Art_BestKarte(getUser():mayEditData)
  set key K_F10 to Art_F10Karte()
  LIEFERAN->(dbgoto(merk_Lief))

RETURN






/* 
* ausdrucken der akt. selek. Bestellung in BesAus
*/


PROCEDURE Best_Drucken(Ausgabe,nurPreisanfrage)
LOCAL Seite:=0
LOCAL Zeile:=0,ende
LOCAL Merk_Kw:="",Merk_KwText:=""
LOCAL Wert:=0,GWert:=0 , x:=0 , div:=0 , mw:=0.00
LOCAL EinhNr:="", sonder:=.f., Laenge, mwwert:=0.00
LOCAL postenPreis,bestNr
LOCAL waehrung:="Euro",Adresse
LOCAL schlusstext:={}, nk
LOCAL pdfInfo, mailText:="", sollMenge, TempText, text, kom[3]

  default nurPreisanfrage:=.f.

  if nurPreisanfrage
    bestNr:=space(len(BESAUS->BestNr))
    Message("Preisanfrage wird gedruckt.  Bitte warten...")

    pdfInfo:=pdfInfo():new( JOB_PREISANFRAGE , getUser():getLongID() , .t. )
    do case
    case Ausgabe="D"
      Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM,1)
    case Ausgabe="P"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM;
        ,1)
    case Ausgabe="NOP"
      Drucker("NOP")
    otherwise
      Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.)
    endcase
  else
    bestNr:=BESAUS->BestNr
    Message("Bestellung-Nr.: @"+BestNr+"@ wird gedruckt.  Bitte warten...")

    pdfInfo:=pdfInfo():new( JOB_BESTELLUNG , BestNr , .t. )
    do case
    case Ausgabe="D"
      Drucker("ON", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    case Ausgabe="P"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_YES_CONFIRM)
    case Ausgabe="NOP"
      Drucker("PDF", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.,PDF_NO_CONFIRM)
    otherwise
      Drucker("BS", pdfInfo:getLocalizedName( LAND->Sprache ) , pdfInfo:path ,.t.)
    endcase
  endif

  Laenge:=DRUCKER->Laenge

  /** w�hle Sprache je nach Empf�nger */
  selLandBySprache(BESAUS->Sprache)

  select Bestell
  go top
  Ende:=BESTELL->(eof())
  do while .not. Ende
    Seite = Seite + 1
    Zeile:=0
    FormularDruck(getTranslation("config.formular",LAND->Sprache),Seite);?;?;?;?;?

    adresse:=getAdrBlock(BESAUS->Name,BESAUS->Partner,BESAUS->Strasse,BESAUS->Zusatz, BESAUS->Land;
      ,BESAUS->Plz,BESAUS->Ort)

    // 5.11.2013 drucke eigene Kund.Nr bei Lieferant
    if open("Lieferan")
      LIEFERAN->(dbseek(BESAUS->LiefNr))
    endif

    SELECT BesAus
    ?
    ?? space(40),BREIT_AN,;
      if(nurPreisanfrage, getTranslation("bestellung.preisanfrage",LAND->Sprache), getTranslation("bestellung.bestellung",LAND->Sprache)),bestnr,BREIT_AUS
    ? space(4),Adresse[1],space(23),;
      if(Seite>1,getTranslation("allgemein.seite",LAND->Sprache)+str(seite,3),"")
    ? space(4),Adresse[2]
    ? space(4),Adresse[3],space(0),LIEFERAN->KdNr,BESAUS->AufDat,space(2),getUser():id
    ? space(4),Adresse[4]
    ? space(4),Adresse[5],space(0),BESAUS->LiefNr,space(4),BESAUS->bestdat
    ? space(4),Adresse[6]
    ? space(44),BESAUS->Ansprech
    ? space(44),BESAUS->bestkonto
    ?
    ?

    adresse:=getAdrBlock(BESAUS->V_Name,BESAUS->V_Partner,BESAUS->V_Strasse,BESAUS->V_Zusatz,;
      BESAUS->V_Land,BESAUS->V_Plz,BESAUS->V_Ort,trim(BESAUS->Land)<>"DE")
    ? space(4),Adresse[1]
    ? space(4),Adresse[2]
    ? space(4),Adresse[3]
    ? space(4),Adresse[4],space(0),;
      if(!empty(VERSART->Text),getTranslation("allgemein.versand",LAND->Sprache),"")
    ? space(4),Adresse[5],space(0),getTransField("VERSART->Text")
    ? space(4),Adresse[6]
    ?
    ?
    // ? space(EURO_LEFT),FETT_AN,"EURO",FETT_AUS
    ?

    /** Uebertrag */
    if Seite > 1
      ? space(51),getTranslation("allgemein.uebertrag",LAND->Sprache,17),"�bertrag:",;
        transStr(gwert,13,2)
    endif

    /* Posten drucken */
    SELECT Bestell
    do while Zeile < Laenge-UNT_RAND-2 .and. .not.BESTELL->(eof())
      postenPreis:=BESTELL->Preis
      wert:=0
      do case
        /** Kommentar */
      case substr(BESTELL->ArtNr,1,1) $ "$*"
        zeile += Kommentar()
        if .not.BESTELL->(eof())
          ? // Leerzeile vor n�chstem Artikel
        endif

        loop // kein skip etc. mehr notwendig !

        /** Verpackung */
      case len(alltrim(BESTELL->ArtNr))<=FRACHT_LAENGE
        /** Sonderrabatt */
        If BESAUS->So_Rabatt > 0.0 .and. ! Sonder
          ? space(41),;
            getTranslation("allgemein.rabatt.sonder",LAND->Sprache,13)+;
            transStr(BESAUS->So_rabatt,5,2)+"% -", transStr(gwert*BESAUS->So_Rabatt/100,10,2)
          gwert=gwert-gwert*BESAUS->So_RAbatt/100
        endif

        div=IIF(BESTELL->PE$"Hh",100,1)
        ? SCHMAL_AN,Out(BESTELL->ArtNr),SCHMAL_AUS,left(getTransField("BESTELL->komm1"),30)
        wert=Postenpreis*BESTELL->menge/div
        if ! (nurPreisanfrage .and. postenPreis==0)
          ?? getMengePreis(BESTELL->menge,postenPreis),BESTELL->pe,;
            if(wert==0,"",transStr(wert,12,2))
        endif
        ? SCHMAL_AN,space(len(out(BESTELL->ArtNr))),SCHMAL_AUS,;
          left(getTransField("BESTELL->komm2"),30)
        IF BESTELL->rabatt<>0.0

          ?? space(6),getTranslation("bestellung.rabatt",LAND->Sprache,7)+transStr(BESTELL->rabatt,5,2)+;
            "% - ",transStr(wert*BESTELL->Rabatt/100,10,2)
          wert=wert-wert*BESTELL->rabatt/100
        endif

        /** "normaler" Artikel */
      otherwise
        div=IIF(BESTELL->PE$"Hh",100,1)
        wert=postenPreis*BESTELL->menge/div

        // AngebotsArtikel 9999 nicht mehr drucken
        if alltrim(BESTELL->ArtNr)==ANGEBOTS_ARTIKEL
          ? SCHMAL_AN,space(len(out(BESTELL->ArtNr))),SCHMAL_AUS
        else
          ? SCHMAL_AN,out(BESTELL->ArtNr),SCHMAL_AUS
        endif
        ?? left(getTransField("BESTELL->komm1"),30)

        if nurPreisanfrage .and. postenPreis==0
          ?? getMengePreis(BESTELL->menge,NIL)
        else
          ?? getMengePreis(BESTELL->menge,postenPreis),BESTELL->pe,transStr(wert,12,2)
        endif
        ? WINZIG_AN,HonselNrWinzig(DEUTSCH),WINZIG_AUS,left(getTransField("BESTELL->komm2"),30)

        /** merke EinheitNr */
        if empty(EinhNr)
          EinhNr:=BESTELL->Me
        endif

        /** 2. Mengeneinheit? */
        ARTIKEL->(dbseek( BESTELL->ArtNr ))
        if ! ARTIKEL->(eof()) .and. ! empty( ARTIKEL->Me2 )

          EINHEIT->(dbseek( BESTELL->ME2 ))
          ?? getMengePreis(BESTELL->menge2 , NIL) // 2. Preis wird nicht ausgedruckt

          IF BESTELL->rabatt<>0.0
            ? space( 40 )
          endif
        endif

        /** Rabatt */
        IF BESTELL->rabatt<>0.0
          ?? space(6),getTranslation("bestellung.rabatt",LAND->Sprache,7)+transStr(BESTELL->rabatt,5,2)+;
            "% - ",transStr(wert*BESTELL->Rabatt/100,10,2)
          wert=wert-wert*BESTELL->rabatt/100
        endif

        /* setze Merker in Bestellkarte */
        if ! nurPreisanfrage .and. BESTELL->TempKZ == "K"
          select BestKart
          BESTKART->(dbseek(BESTELL->ArtNr+BESAUS->LiefNr))
          if ! BESTKART->(eof()) .and. rec_lock(0)
            replace BESTKART->gekauft with BESAUS->AufDat
            replace BESTKART->BestNr with BESAUS->BestNr
            dbcommit()
            unlock
          endif

        endif
        select Bestell

      endcase
      gwert=gwert+wert

      /** ueberpruefe Mat.Kz */
      zeile += drucke_MatKz_Text(BESTELL->ArtNr)

      /** ueberpruefe Artikel Text */
      zeile += drucke_Artikel_Text(BESTELL->ArtNr)

      /** drucke Liefertermin aus Posten */
      if ! KWempty(BESTELL->KW)
        if ! empty(BESTELL->komm2)
          ?
        endif
        ? SCHMAL_AN,space(len(out(BESTELL->ArtNr))),SCHMAL_AUS
        getUser():getCurrentPrintJob():print( Lief_Term( BESTELL->KW , "bestellung.liefertermin" );
          , .f.)

      endif

      // abweichender EK -> Info Email an MW

      // falls Abweichung > 0.009 wegen Rundungsproblematik
      nk = set(_SET_DECIMALS ,4)

      ARTIKEL->(dbseek( BESTELL->ArtNr ))
      if ! nurPreisanfrage .and. BESTELL->Rabatt == 0 .and.;
        (( abs(ARTIKEL->EkPr - BESTELL->Preis) > 0.009 .and. ARTIKEL->ME == BESTELL->ME) .or. (ARTIKEL->ME_Faktor<>0 .and. abs(ARTIKEL->EkPr / ARTIKEL->ME_Faktor - BESTELL->Preis) > 0.009 .and. ARTIKEL->ME2 == BESTELL->ME))

        // Ausnahme Werkzeug Dienstleistung, etc,
        if len(alltrim(ARTIKEL->ArtNr)) > 5 .and. ! getArtikelArt()$"WD" .and.;
          ! left(ARTIKEL->ArtNr,2)=="00"
          // pr�fe ob Rabatttabelle verwendet, falls nein -> Email
          BESTKART->( dbseek( BESTELL->ArtNr + BESAUS->LiefNr ) )

          if BESTELL->ME == ARTIKEL->ME
            sollMenge:=BESTKART->Menge1
          else
            sollMenge:=BESTKART->Menge1 * ARTIKEL->ME_Faktor
          endif

          if BESTKART->(eof()) .or. ( BESTELL->Menge < sollMenge .and. BESTELL->ME == ARTIKEL->ME) ;
            .or. ( ARTIKEL->ME_Faktor > 0 .and. ;
            BESTELL->Menge < sollMenge .and. BESTELL->ME <> ARTIKEL->ME)

            EINHEIT->(dbseek( ARTIKEL->ME ))
            mailText += out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+" EK...........:"+transstr(ARTIKEL->EkPr,12,2)+;
              +" "+EURO_SIGN+" ("+alltrim(EINHEIT->Kommentar)+")"+MY_CR+MY_LF

            EINHEIT->(dbseek( BESTELL->ME ))
            mailText += space(len(out(ARTIKEL->ArtNr)))+" "+ARTIKEL->Bez2+" Bestell-Preis:"+;
              transstr(BESTELL->Preis,12,2)+" "+EURO_SIGN+" ("+alltrim(EINHEIT->Kommentar)+")"+MY_CR+MY_LF

            mailText += MY_CR+MY_LF
            mailText += space(len(out(ARTIKEL->ArtNr))+1)+"Bestell-Menge: "+;
              transstr(BESTELL->Menge,12,2)+" "+alltrim(EINHEIT->Kommentar)+MY_CR+MY_LF

            if ! BESTKART->(eof())
              mailText += space(len(out(ARTIKEL->ArtNr))+1)+"Soll   -Menge: "+;
                transstr(SollMenge,12,2)+" "+alltrim(EINHEIT->Kommentar)+MY_CR+MY_LF
            endif
            mailText += MY_CR+MY_LF
          endif
        endif
      endif
      set(_SET_DECIMALS ,nk)

      skip
      /** Leerzeile zwischen 2 Artikeln */
      if ! substr(BESTELL->ArtNr,1,1)$'$*'
        ?
      endif
    enddo
    /** Ende Bestell-Posten */

    if empty(EinhNr)
      einhNr:=STANDARD_ME
    endif

    /** Seitenumbruch ? */
    if ! BESTELL->(eof()) .or. ;
      (zeile > Laenge - UNT_RAND-LieferTerminKopf(EinhNr,"BesAus",.t.)-;
      Iif(BESAUS->So_Rabatt > 0.0 .and. ! sonder,1,0)-;
      Iif(empty(BESAUS->TextKz_Nr),0,3)-;
      14)

      ? space(51),"�bertrag:",transStr(gwert,13,2)
    else
      Ende:=.t.
      /** Sonderrabatt */
      If BESAUS->So_Rabatt > 0.0 .and. ! Sonder
        ? space(41),;
          getTranslation("allgemein.rabatt.sonder",LAND->Sprache,13)+;
          transStr(BESAUS->So_rabatt,5,2)+ "% - ",transStr(gwert*BESAUS->So_Rabatt/100,10,2)
        gwert=gwert-gwert*BESAUS->So_RAbatt/100
      endif

      /* Liefertermine aus Auf.Kopf */
      zeile+=LieferTerminKopf(EinhNr,"BesAus")

      if nurPreisanfrage // Preisanfrage ohne Summe, nur 1 Ausdruck
        tempText:=linewrap(getTranslation("bestellung.schlusstext",LAND->Sprache))
        for each text in tempText
          aadd(schlussText, text)
        next
      else
        /** Summe nur auf letzter Seite */
        ? space(46),"-----------------------------"
        if BESAUS->mwst > 0.0
          ? space(46),;
            getTranslation("allgemein.netto",LAND->Sprache,12)+waehrung+transStr(gwert,13,2)
          mw=transStr(BESAUS->mwst,5,2)
          mwwert=round(BESAUS->mwst*gwert/100,2)
          ? space(46),;
            mw+"% "+getTranslation("allgemein.mwst",LAND->Sprache,4)+":"+waehrung+;
            transStr(mwwert,13,2)
        endif
        ? space(46),;
          getTranslation("bestellung.wert",LAND->Sprache,12)+waehrung+transStr(gwert + mwwert,13,2)
        ? space(46),"============================="
        ZAHLKOND->(dbseek(BESAUS->ZKNr))
        TEXT_KZ->(dbseek(BESAUS->TextKz_Nr))

        tempText:=linewrap(getTranslation("bestellung.schlusstext2",LAND->Sprache))
        for each text in tempText
          aadd(schlussText, text)
        next
      endif

      kom[1]:=getTranslation("allgemein.zahlkond",LAND->Sprache)
      kom[2]:=getTransField("ZAHLKOND->Text")
      kom[3]:=getTransField("ZAHLKOND->Text2")

      If .not. empty(BESAUS->TextKz_Nr)
        do while Zeile<Laenge-UNT_RAND-10
          ?
        enddo
        ? Text_KZ->Text1
        ? Text_KZ->Text2
        ? Text_KZ->Text3
        ? Text_KZ->Text4
        ? Text_KZ->Text5 ,space(7),schlusstext[1]
        ? Text_KZ->Text6 ,space(7),schlusstext[2]
        ? space(33) ,space(7),schlusstext[3]
        ? kom[1]
        ? kom[2] ,space(8),mycenter(getTranslation("allgemein.gruesse",LAND->Sprache),31)
        ? kom[3] ,space(8),"        MIKI PLASTIK GMBH"
      else
        do while Zeile<Laenge-UNT_RAND-6
          ?
        enddo
        ? kom[1] ,space(20),schlusstext[1]
        ? kom[2] ,space(8),schlusstext[2]
        ? kom[3] ,space(8),schlusstext[3]
        ?
        ? space(33),space(7),mycenter(getTranslation("allgemein.gruesse",LAND->Sprache),31)
        ? space(33),space(7),"        MIKI PLASTIK GMBH"
      endif
    endif

    Zeile:=FormFeed(Zeile)
  enddo // .not.eof()

  SELECT BesAus
  Drucker("OFF")

  /* etiketten drucken */
  if ! nurPreisanfrage .and. Ausgabe=="D"
    Eti_Best()
  endif

  // Email an MW?
  if len(mailText) > 0 .and. Ausgabe <> "NOP"
    email(MAIN_EMAIL,;
      "Bestellung mit abweichendem Preis/Menge: "+BESAUS->BestNr+" "+BESAUS->KurzName,;
      mailText + "||Bitte pr�fen.",;
      pdfInfo:path + BACKSLASH + pdfInfo:getLocalizedName( LAND->Sprache ) + ".pdf" )
  endif


RETURN
/* EOP */

/** Schaltet die ME im Editor-Bauch um */
static function toggleME(p1,oGet)

  ignore p1

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

return .t.
/** eof */

/** Rechnet Menge und Preis anhand des ME_Faktors des Artikels um */
static function toggleValues()
LOCAL aktRec:=BESTTEMP->(recno())
  // nur wenn 2 MEs im Artikel hinterlegt
  if ! empty( ARTIKEL->Me2 )

    if EINHEIT->ME == ARTIKEL->ME
      EINHEIT->(dbseek( ARTIKEL->ME2 ))

      replace all BESTTEMP->Menge1 with BESTTEMP->Menge1 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge2 with BESTTEMP->Menge2 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge3 with BESTTEMP->Menge3 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge4 with BESTTEMP->Menge4 * ARTIKEL->ME_Faktor

      replace all BESTTEMP->Preis1 with BESTTEMP->Preis1 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis2 with BESTTEMP->Preis2 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis3 with BESTTEMP->Preis3 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis4 with BESTTEMP->Preis4 / ARTIKEL->ME_Faktor

    else
      EINHEIT->(dbseek( ARTIKEL->ME ))

      replace all BESTTEMP->Menge1 with BESTTEMP->Menge1 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge2 with BESTTEMP->Menge2 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge3 with BESTTEMP->Menge3 / ARTIKEL->ME_Faktor
      replace all BESTTEMP->Menge4 with BESTTEMP->Menge4 / ARTIKEL->ME_Faktor

      replace all BESTTEMP->Preis1 with BESTTEMP->Preis1 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis2 with BESTTEMP->Preis2 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis3 with BESTTEMP->Preis3 * ARTIKEL->ME_Faktor
      replace all BESTTEMP->Preis4 with BESTTEMP->Preis4 * ARTIKEL->ME_Faktor

    endif
  endif

  BESTTEMP->(dbgoto(aktRec))
return .t.
/** eof */

/** ruft bei Bestellkarteintr�gen aus der Bestell-Historie die
*   Bestellung auf */
function bestkartEdit()
  if BESTTEMP->Historie == "J"

    // HB_KeyPut(K_ALT_B) // alternativ: externes Fenster mit Bestellung

    Umgebung( WRITE_ALL )

    select bespost
    set rela to

    keyboard BESTTEMP->BestNr + chr(K_RETURN) + chr(K_PGDN)

    Best_erfassen(,,BESTTEMP->BesPostNr)

    // evtl. �nderungen neu laden
    BESPOST->(OrdSetFocus(4)) // BesPostNr
    BESPOST->(dbseek( BESTTEMP->BesPostNr ))
    select BestTemp
    if ! BESPOST->(eof())
      copy2Besttemp()
    endif

    Umgebung( LOAD )
  else
    HB_KeyPut(EDIT_LINE_EDIT) // default edit
  endif
return .t.
/** eof */

/** kopiert den aktuellen Datensatz von BesPost nach BestTemp */
static function copy2Besttemp()
LOCAL objErr
  replace BESTTEMP->Artnr with BESPOST->ArtNr
  replace BESTTEMP->LiefNr with BESPOST->LiefNr
  replace BESTTEMP->BesPostNr with BESPOST->BesPostNr
  BEGIN SEQUENCE // brauchen wir, da bei Werkzeug die Preie zu gro� sind
    if BESPOST->Me == ARTIKEL->ME
      replace BESTTEMP->Menge1 with BESPOST->Menge
      replace BESTTEMP->Preis1 with BESPOST->Preis
    elseif BESPOST->Me == ARTIKEL->ME2
      if ARTIKEL->ME_Faktor == 0
        TroubleEmail("Artikel Div 0 ARTIKEL->ArtNr:"+ARTIKEL->ArtNr+"BESPOST->ArtNr:"+;
          BESPOST->ArtNr)
        // FIXME: Temp Info wegen Div / X Problem s. Email vom 17.1.25 7:56
      else
        replace BESTTEMP->Menge1 with BESPOST->Menge / ARTIKEL->ME_Faktor
        replace BESTTEMP->Preis1 with BESPOST->Preis * ARTIKEL->ME_Faktor
      endif
    endif
  RECOVER USING objErr
    email(MY_EMAIL,"ERROR: Bestellkarte-Absturz: ",getErrorText(objErr))
  END SEQUENCE
  replace BESTTEMP->Rabatt with BESPOST->Rabatt
  replace BESTTEMP->Datum with BESPOST->AufDat
  replace BESTTEMP->Gekauft with BESPOST->AufDat
  replace BESTTEMP->BestNr with BESPOST->BestNr
  replace BESTTEMP->LiefME with BESPOST->ME
  replace BESTTEMP->Historie with "J"
return .t.
/**eof */


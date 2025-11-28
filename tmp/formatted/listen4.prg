
/* Listen4
*
* Enth�lt Listen (Teil4)
*/

#include "Miki.ch"
#include "Zeige.ch"


/* PROCEDURE Kostenst_liste()
*/
PROCEDURE KostenSt_Liste
LOCAL Merk_KostNr , gesamt:=0.00 , plus:=0.00 , minus:=0.00
LOCAL Merk_ArtNr , ArtGes:=0.00 , Artplus:=0.00 , Artminus:=0.00, AMengeP:=0.00,AMengeM:=0.00
LOCAL seite:=0, zeile:=0 , kom , zw_sum:=0
LOCAL Stop:=.f., kom1 , summiert , Merk_Text, Ausw

  cls
  titel("Kostenstellen - Liste")

  if ! open("Artikel","Einheit","kostenSt","KstStamm")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif
  /* Relationen setzten */
  SELECT Artikel
  set relation to ARTIKEL->ME into Einheit
  SELECT KostenSt
  set relation to KOSTENST->artnr into artikel,to KOSTENST->KostNr into KstStamm

  @ 8,23 to 16,50
  @ 9,25 say "summiert nach:"
  @ 11,25 Prompt "1. Artikel     "
  @ 12,25 Prompt "2. Kostenstelle"
  @ 14,25 Prompt "3. Komplett    "
  Message("Ihre Auswahl bitte.                  @ESC@=Ende")
  Menu to Ausw
  summiert:=substr("AKG",ausw,1) // Artikel/Kostenst./Gesamt

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  Message("Liste wird erstellt.   Bitte warten...")

  select KostenSt
  if summiert == "A"
    KOSTENST->(OrdSetFocus(2)) // kostenst
  endif

  go top
  Merk_KostNr:=KOSTENST->Kostnr
  Merk_Artnr:=KOSTENST->Artnr
  Merk_Text:=KSTSTAMM->Bez
  do while ! eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'K O S T E N S T E L L E - LISTE       vom:',getUser():date,space(46),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '------------------'
    if summiert=="K" // sumiert je Kostenstelle
      ? 'KSt. Bezeichnung                                                                 Eingang '+;
        'Eu   Ausgang Eu'
    elseif summiert=="G" // gesamte Liste
      ? 'Auf.Nr.  Art-Nr.   Bezeichnung                            Menge   Kalk.Preis    ME   '+;
        'Eingang Eu   Ausgang Eu'
      ? '----------------------------------------------------------------------------------------'+;
        '--------------------'
    else // je Artikel
      ? 'Art-Nr.   Bezeichnung                        Eingang     Ausgang    ME  Kalk.Preis   '+;
        'Eingang Eu   Ausgang Eu'
      ? '----------------------------------------------------------------------------------------'+;
        '--------------------'
    endif
    do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      if summiert <> "K"
        ? Merk_KostNr+":"
        ? "==="
        kom1:=space(len(Merk_KostNr+space(2)+Merk_Text))
      else
        kom1:=Merk_KostNr+space(2)+Merk_Text
      endif
      do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and.;
        Merk_KostNr==KOSTENST->Kostnr .and. ! stop
        kom=iif(KOSTENST->wert>=0,KOSTENST->wert,space(13)+str(KOSTENST->wert,12,2))
        if summiert=="G" // Gesamt
          ? KOSTENST->AuftrNr,out(KOSTENST->artnr),ARTIKEL->bez1,space(3),KOSTENST->Menge,;
            KOSTENST->Kalkpr
          if ARTIKEL->Schluessel=="H"
            ??"%"
          else
            ?? space(1)
          endif
          ?? EINHEIT->Text,kom
        endif

        if KOSTENST->wert > 0
          plus+=KOSTENST->wert
          Artplus+=KOSTENST->wert
        else
          minus+=KOSTENST->wert
          Artminus+=KOSTENST->wert
        endif
        if KOSTENST->Menge > 0
          AMengeP+=KOSTENST->Menge
        else
          AMengeM+=KOSTENST->Menge
        endif
        gesamt=gesamt+KOSTENST->wert
        skip

        /**** summiert je Artikel ***/
        if summiert=="A" .and. KOSTENST->ArtNr <> Merk_Artnr // je Artikel
          ARTIKEL->(dbseek(Merk_ArtNr))
          kom:=if( ARTIKEL->Schluessel=="H" , "%" , " ")
          ? out(Merk_artnr),ARTIKEL->bez1,str(AMengeP,11,2),str(AMengeM,11,2);
            ,kom,EINHEIT->Text,str(ARTIKEL->KaPr,11,2),str(ArtPlus,12,2),str(ArtMinus,12,2)
          Merk_Artnr:=KOSTENST->Artnr
          ArtGes:=Artplus:=Artminus:=AMengeP:=AMengeM:=0.00
          dbskip(0) // wg. Rela auf Artikel !
        endif
        stop:=stop_key() // ESC gedr�ckt ?
      enddo
      if summiert <> "K"
        ? space(82),"-------------------------"
      endif
      ? kom1+space(63),str(plus,12,2),str(minus,12,2)
      ? space(82),str(minus,12,2)
      ? space(82),"------------"
      ? space(82),str(plus+minus,12,2)
      ?

      /* neue Kostenstelle ? */
      if Merk_kostNr<>KOSTENST->Kostnr
        /* Merke Summe der jew. Kostenstelle */
        select KstStamm
        seek Merk_KostNr
        if eof()
          Error(ACHTUNG+Merk_KostNr+" nicht vorhanden.|Bitte erst als Kostenstelle anlegen !")
        else
          Rec_Lock(0) // unsch�n, wird aber eh nur von H. Milz allein benutzt , jojo
          replace KSTSTAMM->Summe with gesamt
          dbcommit()
          unlock
        endif
        select KostenSt
        gesamt=0.00
        plus:=0.00
        minus:=0.00
        Merk_KostNr:=KOSTENST->Kostnr
        Merk_Text:=KSTSTAMM->Bez
      endif

    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  /* Ausdruck Summen je Kostenstelle */
  gesamt:=zw_sum:=0
  select KstStamm
  go top
  Merk_KostNr:=left(KSTSTAMM->KostNr,1)
  do while ! eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'K O S T E N S T E L L E - LISTE       vom:',getUser():date
    ? '---------------------------------------------------'
    ? 'Kost.St. Bezeichnung         Summe Euro'
    ? '---------------------------------------------------'
    do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? KSTSTAMM->KostNr,space(5),KSTSTAMM->Bez,KSTSTAMM->Summe
      gesamt=gesamt+KSTSTAMM->Summe
      Zw_Sum=Zw_Sum+KSTSTAMM->Summe
      skip
      if Merk_KostNr<>left(KSTSTAMM->KostNr,1)
        ? '---------------------------------------------------'
        ? 'Zwischensumme:         ',Zw_sum
        ?
        zw_sum:=0
        Merk_KostNr:=left(KSTSTAMM->KostNr,1)
      endif
      stop:=stop_key() // ESC gedr�ckt ?
    enddo
    if eof()
      ? '---------------------------------------------------'
      ? 'Gesamt:',space(15),gesamt
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Drucker("Off")

  // if Message("Kostenstellen-Datei l�schen ?  ( @J@ / @N@ )","JN")=="J"
  // Message("Bitte warten...")
  // close data
  // if ! open( { "KostenSt" , .t. } )
  // Error(DATEI_EXCL)
  // else
  // zap
  // endif
  // endif

  cls
  close data
RETURN
/* EOP KostenSt_Liste */



/*
*  listet alle Oberartikel auf in denen akt. Artikel als Material/Wkz. vorkommt
*
*  Parameter:   M_Art   "M"=Material
*                       "W"=Werkzeug
*/
PROCEDURE MatArtikelListe(M_Art)
LOCAL GetList:={}
LOCAL von,bis
LOCAL Stop:=.f.
LOCAL Merk_satz

  Umgebung(WRITE_ALL)

  if ! open("Artikel","Einheit","AvPost","BesAus")
    Error(TRY_AGAIN)
    cls
    Umgebung(LOAD)
    RETURN
  endif
  merk_Satz:=ARTIKEL->(recno())

  /* Relationen setzten */
  SELECT AvPost
  SET RELATION TO AVPOST->ME INTO Einheit, to AVPOST->AvNr INTO Artikel // auf OberArtikel
  select Artikel
  ARTIKEL->(OrdSetFocus(1))
  ARTIKEL->(dbgoto( merk_Satz )) // brauchen wir wegen rela setzen, s. oben

  // interaktive Eingabe der Art.Nr.
  if M_Art <> NIL // kommt aus Menu -> manuelle Eingabe
    cls
    if M_Art="M"
      titel("Material in welcher St�ckliste")
    else
      titel("Werkzeug in welcher St�ckliste")
    endif

    do while ! ABBRUCH
      /* Liste von bis */
      @ 4,0 clear
      von:=bis:=space(len(ARTIKEL->ArtNr))
      bis:=von_bis("Artikel")

      if ABBRUCH .or. ! druck_BS() // Abbruch
        M->specialZeige:=NIL
        Umgebung(LOAD)
        RETURN
      endif

      /** Spezial Funktion Zeige freischalten */
      M->specialZeige:={}
      aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Ver"+;
        "f." } )
      aadd( M->specialZeige , { chr(K_CTRL_H) , { |a,b| HB_SYMBOL_UNUSED(a), WarAusJahrList("BS",b;
        [ZEIGE->(fieldPos("ArtNr" ))]) }, "@STRG-H@" })
      aadd( M->specialZeige , { chr(K_F5)+;
        chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
      aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."};
        )

      MatArtStkListe(M_art,ARTIKEL->ArtNr,bis)

      Drucker("Off")
    enddo

  else // AutoStart mit akt. Artikel
    select Artikel
    Drucker("BS",ARTIKEL->ArtNr+" in St�cklisten")

    /** Spezial Funktion Zeige freischalten */
    M->specialZeige:={}
    aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf.";
      } )
    aadd( M->specialZeige , { chr(K_CTRL_H) , { |a,b| HB_SYMBOL_UNUSED(a), WarAusJahrList("BS",b[ZEIGE->(fieldPos("ArtNr" ))]) }, "@STRG-H@" })
    aadd( M->specialZeige , { chr(K_F5)+;
      chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
    aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )

    if getArtikelArt()=="W"
      MatArtStkListe("W")
    else
      MatArtStkListe("M")
    endif
    Drucker("Off",,,,,,.f.) // ohne Popup!!!
    select Artikel
    go (merk_Satz)
  endif
  Umgebung(LOAD)
  M->specialZeige:=NIL
RETURN
/* EOP Mat_Artikel */

/*
*  ruft rekursiv die MatArtListe auf
*
*  Parameter:   ZeigeData
*/
PROCEDURE rekMatArtListe( ZeilenText , ZeigeData )
LOCAL mArtNr, merk_Satz

  ignore ZeilenText

  mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]

  if ! myEmpty( MArtNr )

    merk_Satz:=ARTIKEL->(recno())
    Umgebung(WRITE_ALL)

    /* Relationen setzten */
    SELECT AvPost
    SET RELATION TO AVPOST->ME INTO Einheit, to AVPOST->AvNr INTO Artikel // auf OberArtikel

    select Artikel
    ARTIKEL->(dbClearFilter())
    ARTIKEL->(OrdSetFocus(1))
    ARTIKEL->(dbgoto( merk_Satz )) // brauchen wir wegen rela setzen, s. oben

    Drucker("BS")
    MatArtStkListe(nil,mArtNr,mArtNr)
    Drucker("Off",,,,,,.f.) // ohne Popup!!!

    Umgebung(LOAD)

  endif

return
/** eop */


/** Listet das Material/Werkzeug auf die in den Artikel vorkommen
    vom akt. Artikel bis zum �bergegbenen bis-Artikel */
Procedure MatArtStkListe(M_art,von,bis)
LOCAL seite:=0, zeile:=0, baugrSumme:=0
LOCAL Stop:=.f.,aktSel:=alias()
LOCAL ArtAkt:=""
LOCAL merkOrd
LOCAL parents , p

  Umgebung(WRITE_ALL)

  aaddUnique( M->SpecialZeige , { "m" , { |a , b| aendStkList( a , b , "M") } , "@M@=Mat."} )
  aaddUnique( M->SpecialZeige , { "w" , { |a , b| aendStkList( a , b , "W") } , "@W@=Wkz."} )
  aaddUnique( M->SpecialZeige , { "i" , { |a , b| aendStkList( a , b , "I") } , "@I@=Ins."} )

  default M_Art:="M"
  default von:=ARTIKEL->ArtNr
  default bis:=ARTIKEL->ArtNr // default ist nur akt. Artikel

  if select("WarAus")==0
    if ! open("Waraus")
      Error(TRY_AGAIN)
      Umgebung(LOAD)
      return
    endif
  endif
  select WarAus
  WARAUS->(OrdSetFocus(2)) // ArtNr + Date descending

  if select("AvPost")==0
    if ! open("AvPost")
      Error(TRY_AGAIN)
      Umgebung(LOAD)
      return
    endif
  endif

  select AvPost
  merkOrd:=AVPOST->(merkOrd)
  AVPOST->(OrdSetFocus(2)) // Unterartikel+Hauptartikel
  dbseek(von,.t.)

  Message("Liste wird erstellt.   Bitte warten...")

  do while .not.eof().and. AVPOST->ArtNr<=bis .and. ! stop
    seite=seite+1
    zeile:=0
    if von==bis
      ? 'Materialliste Artikel:',von,'              vom:',getUser():date,space(12),'Seite',;
        str(seite,3)
    else
      ? 'Materialliste je Artikel:',von,' bis:',bis,'         vom:',getUser():date,space(12),;
        'Seite',str(seite,3)
    endif
    ? '------------------------------------------------------------------------------------------'+;
      '---------------'
    ? 'Art-Nr.      Bezeichnung                         Menge ME   Bestellt   Bestand Enth. Bgr. '+;
      'Letzte Bewegung'
    ? '                                                                               bei Miki'
    ? '------------------------------------------------------------------------------------------'+;
      '---------------'
    _____fixedHeader_____
    do while .not.eof().and. AVPOST->ArtNr<=bis;
      .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      if AVPOST->Art=M_Art .and. AVPOST->Text="A"
        If ArtAkt<>AVPOST->ArtNr
          SELECT Artikel
          SEEK AVPOST->ArtNr
          if Zeile > 5
            ?
          endif
          ? ZEIGE_ARTNR+out(AVPOST->ArtNr),ARTIKEL->Bez1
          ? REPLICATE("=",len(AVPOST->ArtNr))
          ArtAkt:=AVPOST->ArtNr
          select AvPost
          dbskip(0) // wg. Rela
        endif

        zeile += druckeMatArtikel(AVPOST->Menge , AVPOST->ME)
        baugrSumme += ARTIKEL->LageBest * AVPOST->Menge

      endif
      skip

      If ArtAkt<>AVPOST->ArtNr
        // pr�fe auf alternatives Material
        // Neu 25.7.16
        if ! empty( parents:=StueckListe():new(ArtAkt):getAlternativeParents() )
          ?
          ? "Alternatives Material f�r:"
          ? "=========================="
          for each p in parents
            ARTIKEL->(dbseek( p:ArtNr ))
            druckeMatArtikel(ARTIKEL->MatFaktor , ARTIKEL->ME)
            baugrSumme += ARTIKEL->LageBest * ARTIKEL->MatFaktor
          next
        endif
      endif

      Stop=Stop_Key()
    enddo

    ? '------------------------------------------------------------------------------------------'+;
      '--------------'
    ? space(76),str(baugrSumme,12,2)

    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Umgebung(LOAD)

return
/** eop */

/* PROCEDURE Liefer_Plan
*
*  listet alle noch zu t�tigen Auftr�ge/Lieferungen auf
*
*/
PROCEDURE Liefer_Plan
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL kalwoch:=space(5),Abruf:="N",AbrufBed
LOCAL pseudo_gel:=0.00, Feld , MengVar, x, gel,altkw:=""


  cls
  titel("Lieferplan drucken")

  if ! open("AufAus","AufPost","LiefPlan")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /* Relationen setzten */
  SELECT AufPost
  SET RELATION TO AUFPOST->AufNr INTO Aufaus

  Message("Bitte gew�nschte Kalenderwoche eingeben.")
  @ 8,18 to 12,60
  @ 9,20 say "Kalenderwoche..................:" get kalwoch PICTURE "!!/99"
  @ 11,20 say "mit Abrufauftr�gen ?  ( J / N ):" get abruf PICTURE "!" valid Abruf $"JN"
  read
  if kalwoch="  /  " .or. ABBRUCH
    cls
    close data
    RETURN
  endif

  if ! druck_BS() // Abbruch
    cls
    close data
    RETURN
  endif

  Message("Liste wird erstellt.  Bitte warten...")

  AbrufBed:={ || (Abruf='N' .and. upper(substr(AUFPOST->Kw,1,2)) $ ' 00  X1X2X3X4X5X6X7X8X9X0') }

  SELECT LiefPlan
  zap
  SELECT AufPost
  Go Top
  do while .not. eof()
    do while .not. eof() .and. ;
      .not. (AUFPOST->Menge > AUFPOST->GeliefGes .and. LEN(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE;
      .and. kwKleiner(AUFPOST->kw,kalwoch) <= 0 )
      skip
    enddo
    if ! KWempty(AUFPOST->KW)
      /* Kalenderwoche je Posten */
      If .not. eval(AbrufBed)
        SELECT LiefPlan
        ADD_REC(5)
        REPLACE LIEFPLAN->AufNr WITH AUFPOST->Aufnr
        REPLACE LIEFPLAN->ArtNr WITH AUFPOST->ArtNr
        REPLACE LIEFPLAN->Bez1 WITH AUFPOST->Komm1
        REPLACE LIEFPLAN->KW WITH AUFPOST->KW
        REPLACE LIEFPLAN->Menge WITH AUFPOST->Menge - AUFPOST->GeliefGes
        REPLACE LIEFPLAN->Kunde WITH AUFAUS->KundNr
        REPLACE LIEFPLAN->KurzName WITH AUFAUS->KurzName
      endif
    else
      /* Kalenderwoche je Auftrag */
      x:=1
      gel:=0
      pseudo_gel:=AUFPOST->GeliefGes
      Feld:="AUFAUS->KW"+str(x,1)
      MengVar:="AUFAUS->Meng"+str(x,1)
      do while ! KWempty(&(Feld)) .and. kwKleiner(&(Feld),kalwoch) <= 0
        MengVar="AUFAUS->Meng"+str(x,1)
        gel=gel + &(MengVar)
        if gel > Pseudo_Gel .and. .not. eval(AbrufBed)
          SELECT LiefPlan
          ADD_REC(5)
          REPLACE LIEFPLAN->AufNr WITH AUFPOST->Aufnr
          REPLACE LIEFPLAN->ArtNr WITH AUFPOST->ArtNr
          REPLACE LIEFPLAN->Bez1 WITH AUFPOST->Komm1
          REPLACE LIEFPLAN->KW WITH &(Feld)
          REPLACE LIEFPLAN->Menge WITH gel-Pseudo_Gel
          REPLACE LIEFPLAN->Kunde WITH AUFAUS->KundNr
          REPLACE LIEFPLAN->KurzName WITH AUFAUS->KurzName
          Pseudo_Gel = gel
          // ? "gel:",str(gel,9,2),"     Pseudo_gel:",str(Pseudo_gel,9,2),"  Menge:",str(&(mengVar),9,2)
        endif
        x=x+1
        if x > 6
          exit
        endif
        Feld="AUFAUS->KW"+str(x,1)
      enddo
    endif
    SELECT AufPost
    skip
  enddo

  SELECT LiefPlan
  if reccount()==0
    ERROR(ACHTUNG+"Keine Lieferungen mehr zu t�tigen !",.t.)
    cls
    close data
    RETURN
  endif
  go top

  altKw:=LIEFPLAN->Kw
  do while .not.eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Lieferplan f�r Kalenderwoche:',kalwoch,'       vom:',getUser():date,space(16),'Seite',;
      str(seite,3)
    ? '----------------------------------------------------------------------------------------'
    ? 'KdNr. Kunde       Auftr.Nr. Art.Nr.     Bezeichnung                        Menge     KW'
    ? '----------------------------------------------------------------------------------------'
    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      if altkw<>LIEFPLAN->Kw
        ?
        altKw:=LIEFPLAN->Kw
      endif
      ? LIEFPLAN->Kunde,substr(LIEFPLAN->Kurzname,1,10),LIEFPLAN->AufNr,space(4),;
        OUT(LIEFPLAN->ArtNr),space(1),LIEFPLAN->bez1,LIEFPLAN->Menge
      if kwKleiner(LIEFPLAN->kw,kalwoch) < 0
        ?? " ",LIEFPLAN->kw
      endif
      skip
      Stop=Stop_Key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker('OFF')
  CLOSE DATA
  clear
RETURN
/* EOP Liefer_Plan */

/* PROCEDURE Historie
*
*/
PROCEDURE Historie
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f. , bed
LOCAL linie
LOCAL KdAlt,ArtKz,M_Bez:="N"
MEMVAR datvon, datbis,M_KundNr,M_ArtNr
PRIVATE datvon:=getUser():date, datbis:=getUser():date,M_KundNr,M_ArtNr

  cls
  titel("Fakturierung-Historie")

  if ! open("Kunden","Artikel","RechPost","RechAus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /** Relationen setzen */
  select RechPost
  set rela to RECHPOST->RechNr into Rechaus

  do while ! ABBRUCH
    bed:=""
    seite:=0
    stop:=.f.
    M->M_KundNr:=space(len(KUNDEN->KundNr))
    M->M_ArtNr:=space(len(ARTIKEL->ArtNr))
    Message("Zeitraum, Artikel oder/und Kunden eingeben.      @ESC@=Ende")
    @ 7,18 to 11,40
    @ 8,20 say "Datum von:" get M->datvon
    @ 10,20 say "      bis:" get M->datbis

    @ 13,18 to 17,69
    @ 14,20 say "Kunde....:" get M->M_KundNr picture KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden") }
    @ 16,20 say "Art.Nr...:" get M->M_ArtNr picture "@K!" valid { |oGet| check(oGet,"Artikel") }
    @ 16,43 say "Art.Bez. drucken (J/N):" get M_Bez picture "!" valid M_Bez$"JN"
    read
    if ABBRUCH .or. M->datvon > M->datbis
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
    if M_Bez=="J"
      linie:=replicate("-",93)
    else
      linie:=replicate("-",62)
    endif


    bed:="RECHPOST->ReaDat>=M->datvon .and. RECHPOST->ReaDat<=m->datbis .and. len(alltrim(RECHPOST->ArtNr))>"+str(FRACHT_LAENGE,2)

    if ! empty(M_KundNr)
      bed+=" .and. RECHPOST->KundNr==M->M_KundNr"
    endif
    if ! empty(M_ArtNr)
      bed+=" .and. RECHPOST->ArtNr==M->M_ArtNr"
    endif

    SELECT RechPost
    RECHPOST->(OrdSetFocus(2)) // rechpost
    set Filter to &(bed)
    go top
    do while .not. eof() .and. ! stop
      Seite=Seite+1
      zeile:=0
      if ! empty(M->M_KundNr)
        ? "Kunde  :",KUNDEN->KundNr,KUNDEN->KurzName,space(2)
      endif
      if ! empty(M->M_ArtNr)
        ? "Artikel:",ARTIKEL->ArtNr,ARTIKEL->Bez1
      endif
      ? linie
      if M_Bez=="J"
        ? 'Fakturierung-Historie                vom:',M->DatVon,' bis:',M->DatBis,space(17),;
          'Seite',str(seite,3)
        ? "Rech.Nr. Re.Dat. Art.Nr.  Bezeichnung                         Menge     Preis Rabatt  "+;
          "So.Rab."
      else
        ? 'vom:',M->DatVon,' bis:',M->DatBis,space(23),'Seite',str(seite,3)
        ? "Rech.Nr. Re.Dat. Art.Nr.       Menge     Preis Rabatt  So.Rab."
      endif
      ? linie
      kdAlt:=""
      do while .not. eof() .and. ! stop .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand
        if kdAlt<>RECHPOST->KundNr
          kdAlt:=RECHPOST->KundNr
          KUNDEN->(dbseek(RECHPOST->KundNr))
          ? RECHPOST->KundNr,KUNDEN->KurzName
        endif
        if RECHPOST->aufNr==SAMMEL_KZ
          ArtKz:="*"
        else
          ArtKz:=" "
        endif
        if M_Bez=="J"
          ? ArtKz,RECHPOST->RechNr,RECHPOST->ReaDat,RECHPOST->ArtNr,left(RECHPOST->komm1,30),;
            RECHPOST->Gelief,RECHPOST->Preis
        else
          ? ArtKz,RECHPOST->RechNr,RECHPOST->ReaDat,RECHPOST->ArtNr,RECHPOST->Gelief,;
            RECHPOST->Preis
        endif
        if RECHPOST->Rabatt > 0
          ?? sTR(RECHPOST->Rabatt,5,2)+"%"
        else
          ?? space(5+1)
        endif
        if RECHAUS->SO_Rabatt > 0
          ?? space(1),str(RECHAUS->So_Rabatt,5,2)+"%"
        endif
        Stop:=stop_key()
        skip
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo // eof()
  cls
  close data
RETURN
/* EOP Ers_Einz_Ausw */



/* PROCEDURE Umsatz
*
* FIXME: Sonderrabatt wird nicht korrekt abgezogen  
*/
PROCEDURE Umsatz()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f. , bed
LOCAL linie:=replicate("-",78)
LOCAL MonatAlt
LOCAL SummeNetto,SummeRabatt,kom:="",wert,SummeMenge
LOCAL GesamtNetto:=0,GesamtRabatt:=0,GesamtMenge
MEMVAR datvon, datbis,M_KundNr,M_ArtNr
PRIVATE datvon:=getUser():date, datbis:=getUser():date,M_KundNr,M_ArtNr

  cls
  titel("Umsatz je Artikel")

  if ! open("Kunden","Artikel","RechPost","RechAus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /** Relationen setzen */
  select RechPost
  set rela to RECHPOST->RechNr into Rechaus, to RECHPOST->ArtNr into Artikel

  set key K_F8 to copy_buffer("",oGet,"")

  do while ! ABBRUCH
    bed:=""
    seite:=0
    stop:=.f.
    SummeNetto:=SummeRabatt:=SummeMenge:=0
    GesamtNetto:=GesamtRabatt:=GesamtMenge:=0


    cls
    titel("Umsatz-Liste")

    Message("Zeitraum und Artikel eingeben.      @ESC@=Ende")
    M_Artnr:=space(len(ARTIKEL->ArtNr))
    @ 5,18 to 9,45
    @ 6,20 say "Datum von:" get M->datvon
    @ 8,20 say "      bis:" get M->datbis
    @ 11,20 say "Artikel..:" get M_ArtNr picture "@K" valid { |oGet| check(Oget,"Artikel",.t.,.f.)}
    // @ 12,20 say "Mat.Kz...:" get Mat_Kz picture MAT_PICT
    read

    if ABBRUCH
      cls
      close data
      set key K_F8 to
      RETURN
    endif

    if ! druck_BS() // Abbruch
      cls
      close data
      set key K_F8 to
      RETURN
    endif
    Message("Liste wird erstellt.   Bitte warten...")

    bed:="RECHPOST->ReaDat>=M->datvon .and. RECHPOST->ReaDat<=m->datbis .and. len(alltrim(RECHPOST->ArtNr))>"+str(FRACHT_LAENGE,2)

    // if ! empty(Mat_Kz)
    // bed+=" .and. ARTIKEL->MatKz==Mat_Kz"
    // endif
    if ! empty(M_ArtNr)
      bed+=" .and. RECHPOST->ArtNr==M->M_ArtNr"
    endif

    SELECT RechPost
    set Filter to &(bed)
    go top
    do while .not. eof() .and. ! stop
      Seite=Seite+1
      zeile:=0
      if ! empty(M_ArtNr)
        kom:="Art.Nr.: "+M_ArtNr+space(6)
      endif
      ? 'Umsatz-Liste ',kom,' vom:',M->DatVon,' bis:',M->DatBis,space(0),'Seite',str(seite,3)
      ? linie
      ? "Monat      Jahr          Menge          Netto         Rabatt         Umsatz"
      ? linie
      MonatAlt:=ctod("01.01.80")
      do while .not. eof() .and. ! stop .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand

        MonatAlt:=RECHPOST->ReaDat
        SummeNetto:=SummeRabatt:=SummeMenge:=0.00
        do while month(MonatAlt)==month(RECHPOST->ReaDat) .and. .not. eof() .and. ! stop
          wert:=RECHPOST->gelief*RECHPOST->Preis
          wert /= IIF(RECHPOST->PE$"Hh",100,1)
          SummeNetto += wert
          SummeMenge += RECHPOST->gelief
          if RECHPOST->Rabatt > 0
            SummeRabatt += wert*RECHPOST->Rabatt/100
            wert -= wert*RECHPOST->Rabatt/100
          endif
          if RECHAUS->SO_Rabatt > 0
            SummeRabatt += wert*RECHAUS->SO_Rabatt/100
          endif
          Stop:=stop_key()
          skip
        enddo

        ? left(myCMonth(MonatAlt)+space(10),9),year(MonatAlt),Transform(SummeMenge,"@Z "+;
          "999,999,999.99"),Transform(SummeNetto,"@Z 999,999,999.99"),Transform(SummeRabatt,"@Z 999,999,999.99"),Transform(SummeNetto-SummeRabatt,"999,999,999.99")
        gesamtNetto+= SummeNetto
        gesamtMenge+= SummeMenge
        gesamtRabatt+= SummeRabatt

      enddo
      ? linie
      ? space(15),Transform(GesamtMenge,"@Z 999,999,999.99"),;
        Transform(GesamtNetto,"999,999,999.99"),Transform(Gesamtrabatt,"999,999,999.99"),;
        Transform(GesamtNetto-GesamtRabatt,"999,999,999.99")
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo // eof()
  cls
  close data

  set key K_F8 to
RETURN
/* EOP Ers_Einz_Ausw */

/** PROCEDURE Lager-Liste
*
*/
PROCEDURE LagerListe()
LOCAL ArtNrVon,ArtNrBis
  // LOCAL summe1:=0,summe2:=0,summe3:=0,Summe0:=0
LOCAL GetList:={} , Zeile:=0,kom,divisor
LOCAL Ausw,bed,Seite,stop:=.f.,bis,line
MEMVAR buffer
PRIVATE buffer:=""

  cls
  Titel("Lager-Liste")

  if ! open( "Artikel" , "Einheit")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif
  /* Relation setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  set key K_F8 to copy_buffer("",oGet,"")

  do while ! ABBRUCH

    // summe1:=0;summe2:=0;summe3:=0;Summe0:=0
    cls
    titel("Lagerbestands-Liste")
    // summe1:=summe2:=summe3:=0
    kom:=""
    stop:=.f.

    Artnrvon:=ArtNrbis:=space(len(ARTIKEL->ArtNr))
    @ 8,20 say "ArtikelNr. von:" get ArtNrvon picture "@K";
      valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)}
    @ 10,20 say "           bis:" get ArtNrbis picture "@K";
      valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)}
    read

    if ABBRUCH
      cls
      close data
      RETURN
    endif

    Message("Art der Liste ausw�hlen.        @ESC@=Ende")
    @ 14,20 to 17,60
    @ 15,22 prompt "1. EK, Kalk.Pr, VK"
    @ 16,22 prompt "2. nur VK         "
    menu to ausw
    if ABBRUCH
      cls
      close data
      RETURN
    endif

    if ! druck_BS() // Abbruch
      cls
      close data
      RETURN
    endif

    Message("Liste wird erstellt.   Bitte warten...")
    bed:={ || ARTIKEL->LageBest > 0 }

    if empty(ArtNrBis)
      go bottom
      ArtNrBis:=ARTIKEL->ArtNr
    else
      kom += "bis Art.Nr. "+ArtNrBis
    endif
    bis:=ArtNrBis

    if ! empty(ArtNrVon)
      dbseek(ArtNrvon)
      kom:="von Art.Nr. "+ArtNrVon + kom
    else
      go top
    endif

    Seite:=0
    do while .not.eof() .and. ARTIKEL->artnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'L A G E R - BESTANDSLISTE                 vom:',getUser():date,space(22),'Seite',;
        str(seite,3)
      if ! empty(kom)
        ? kom
      endif
      ? "Art-Nr.  KZ Bezeichnung                        Menge ME  KstSt. Lagerort"
      if ausw==1 // alle Preise
        ?? "            EK     Kalk.Pr.           VK"
        line = replicate("-",113)
      else // nur VK
        ?? "            VK"
        line = replicate("-",87)
      endif
      ? line
      do while .not.eof() .and. ARTIKEL->artnr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        if eval(bed)
          divisor:=if(ARTIKEL->Schluessel=="H",100,1)
          // Summe0 += ARTIKEL->LageBest
          if ausw==1 // alle Preise
            ? OUT(ARTIKEL->ArtNr),ARTIKEL->INV_KZ,ARTIKEL->Bez1,ARTIKEL->Lagebest,EINHEIT->Text,;
              ARTIKEL->KostNr,getArtikelLagerOrt(14), ;
              str(ARTIKEL->EKPR*ARTIKEL->LageBest/divisor,12,2),;
              str(ARTIKEL->KaPr*ARTIKEL->LageBest/divisor,12,2),;
              str(ARTIKEL->Preis1*ARTIKEL->LageBest/divisor,12,2)

            // Summe1 += round(ARTIKEL->EKPR*ARTIKEL->LageBest/divisor,2)
            // Summe2 += round(ARTIKEL->KaPr*ARTIKEL->LageBest/divisor,2)
            // Summe3 += round(ARTIKEL->Preis1*ARTIKEL->LageBest/divisor,2)
          else // nur VK
            ? OUT(ARTIKEL->ArtNr),ARTIKEL->Inv_KZ,ARTIKEL->Bez1,ARTIKEL->Lagebest,EINHEIT->Text,;
              ARTIKEL->KostNr,getArtikelLagerOrt(14),str(ARTIKEL->Preis1*ARTIKEL->LageBest/divisor,12,2)
            // Summe3 += round(ARTIKEL->Preis1*ARTIKEL->LageBest/divisor,2)
          endif
        endif

        skip
        Stop=Stop_Key()
      enddo
      ? line
      // if ausw==1 // alle Preise
      // ? space(39),str(Summe0,12,2),space(15),str(Summe1,12,2),str(Summe2,12,2),Str(Summe3,12,2)
      // else // nur VK
      // ? space(39),str(Summe0,12,2),space(15),str(Summe3,12,2)
      // endif

      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo
  set key K_F8 to
  cls
  close data
RETURN
/* EOP */


/* PROCEDURE Kunden-Liste
*
*/
PROCEDURE KundenListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis
LOCAL Stop:=.f.

  cls
  titel("Kundenliste")

  if ! open("Kunden","KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  do while ! ABBRUCH
    seite:=0; zeile:=0
    /* Liste von bis */
    @ 4,0 clear
    von:=bis:=space(len(KUNDEN->KundNr))
    bis:=von_bis("Kunden")

    if ABBRUCH .or. ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not.eof().and. KUNDEN->Kundnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Kundenliste           vom:',getUser():date,space(26),'Seite',str(seite,3)
      ? 'Kunden von:',von,' bis:',bis
      ? '--------------------------------------------------------------------------'
      ? 'Kundennr.   Name/Adresse'
      ? '--------------------------------------------------------------------------'
      do while .not.eof().and. KUNDEN->Kundnr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        ? kdout(KUNDEN->KundNr),space(2),KUNDEN->Name
        ? space(len(kdout(KUNDEN->KundNr))),space(2),KUNDEN->Partner
        ? space(len(kdout(KUNDEN->KundNr))),space(2),KUNDEN->Strasse
        ? space(len(kdout(KUNDEN->KundNr))),space(2),KUNDEN->Land,KUNDEN->Plz,KUNDEN->Ort
        ? space(len(kdout(KUNDEN->KundNr))),space(2),KUNDEN->Telefon
        ?

        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo
  cls
  close data
RETURN
/* EOP Kundenliste*/

/* PROCEDURE Lieferanten-Liste
*
*/
PROCEDURE LieferantenListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis
LOCAL Stop:=.f.

  cls
  titel("Lieferantenliste")

  if ! open("Lieferan")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  do while ! ABBRUCH
    seite:=0; zeile:=0
    /* Liste von bis */
    @ 4,0 clear
    von:=bis:=space(len(LIEFERAN->LiefNr))
    bis:=von_bis("Lieferan")

    if ABBRUCH .or. ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not.eof().and. LIEFERAN->Liefnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Lieferantenliste        vom:',getUser():date,space(26),'Seite',str(seite,3)
      ? 'Lieferanten von:',von,' bis:',bis
      ? '--------------------------------------------------------------------------'
      ? 'Lief.Nr.   Name/Adresse'
      ? '--------------------------------------------------------------------------'
      do while .not.eof().and. LIEFERAN->Liefnr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        ? LIEFERAN->Liefnr,space(4),LIEFERAN->Name1
        ? space(len(LIEFERAN->Liefnr)),space(4),LIEFERAN->Name2
        ? space(len(LIEFERAN->Liefnr)),space(4),LIEFERAN->Strasse
        ? space(len(LIEFERAN->Liefnr)),space(4),LIEFERAN->Land,LIEFERAN->Plz,LIEFERAN->Ort
        ? space(len(LIEFERAN->Liefnr)),space(4),LIEFERAN->Telefon
        ?

        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")
  enddo
  cls
  close data
RETURN
/* EOP Lieferantenliste*/

/* 
*  listet alle Artikel ohne Stueckliste auf
*/
PROCEDURE ArtOhneStck()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis,letzteBewegung
LOCAL Stop:=.f.
LOCAL ArtAkt:="",kom

  cls
  titel("Artikel ohne St�ckliste")

  if ! open("Artikel","AvAus","AvPOst","Waraus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  Message("Warenausgang wird sortiert.   Bitte warten...")

  /* Relationen setzten */
  select avpost
  AVPOST->(OrdSetFocus(2))
  select Waraus
  WARAUS->(OrdSetFocus(2))
  SELECT Artikel
  SET RELATION TO Artikel->ArtNr INTO AvPost,TO Artikel->ArtNr INTO AvAus

  do while ! ABBRUCH
    /* Liste von bis */
    seite:=0; zeile:=0
    @ 4,0 clear
    von:=bis:=space(len(ARTIKEL->ArtNr))
    bis:=von_bis("Artikel")
    if ABBRUCH
      loop
    endif

    if ABBRUCH .or. ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    // merke von
    von:=ARTIKEL->ArtNr

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not.eof().and. ARTIKEL->artnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Artikel ohne St�ckliste          vom:',getUser():date,space(12),'Seite',str(seite,3)
      ? 'Artikel von:',von,' bis:',bis
      ? '--------------------------------------------------------------------------'
      ? 'Art-Nr.   Bezeichnung                      Bewegung   Bestand LagerOrt'
      ? '--------------------------------------------------------------------------'
      do while .not.eof().and. ARTIKEL->ArtNr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        if (AVPOST->(eof()) .and. AVAUS->(eof()))
          // letzte Bewegung
          letzteBewegung:="  .  .  "

          WARAUS->(dbseek(ARTIKEL->ArtNr))
          if (! WARAUS->(EOF()))
            letzteBewegung:=WARAUS->Datum
          endif

          kom=trim(ARTIKEL->bez1)
          ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(1),letzteBewegung,ARTIKEL->Lagebest,;
            getArtikelLagerOrt(14)
          if .not. empty(ARTIKEL->bez2)
            ? space(len(out(AVPOST->AvNr))),ARTIKEL->Bez2
          endif
        endif
        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")


    // loeschen ?
    IF Message("Artikel und Stuecklisten wirklich loeschen ? ( @$@==J / @N@ )","$N")=="$"

      if ABBRUCH .or. ! druck_BS() // Abbruch
        close data
        RETURN
      endif

      ? 'Artikel geloescht          vom:',getUser():date,space(12)
      ? 'Artikel von:',von,' bis:',bis
      ? '--------------------------------------------------------------------------'
      ? 'Art-Nr.   Bezeichnung                          '
      ? '--------------------------------------------------------------------------'

      select Artikel
      ARTIKEL->(dbseek(von))
      do while .not.eof().and. ARTIKEL->artnr<=bis

        if (AVPOST->(eof()) .and. AVAUS->(eof()))
          ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1
          rec_lock(0)
          delete
        endif
        skip
      enddo
      ? '--------------------------------------------------------------------------'
      Drucker("Off")

    endif


  enddo
  cls
  close data
RETURN
/* EOP ArtOhneStck */

/* PROCEDURE ArtLetztBeweg()
*
*  listet alle Artikel ohne Stueckliste auf
*
*/
PROCEDURE ArtLetztBeweg()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis,letzteBewegung,programm,selArt,setzeX,datVon:=ctod("  .  .  "),startDate
LOCAL Stop:=.f.
LOCAL ArtAkt:="",kom,UR

  cls
  titel("Artikel letzte Bewegung")

  if ! open("Artikel","Waraus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  Message("Warenausgang wird sortiert.   Bitte warten...")

  /* Relationen setzten */
  select Waraus
  WARAUS->(OrdSetFocus(0))
  go top
  startDate:=WARAUS->Datum
  WARAUS->(OrdSetFocus(2))
  SELECT Artikel

  do while .t.
    /* Liste von bis */
    select Waraus
    set filter to
    select Artikel
    set filter to

    seite:=0; zeile:=0
    Stop:=.f.
    @ 4,0 clear
    von:=bis:=space(len(ARTIKEL->ArtNr))
    bis:=von_bis("Artikel")
    if ABBRUCH
      cls
      close data
      RETURN
    endif

    setzeX:="N"
    selArt:=space(5)
    datVon:=startDate
    @ 12,20 to 12,60
    @ 14,20 say "Artikel Art (BDEFMWX )             :" get selArt picture "@!" when;
      Message("Artikel Art(en) einschr�nken?   @Leer@=Alle")
    @ 16,20 say "Artikel ohne Bewegung auf X setzen:" get setzeX picture "!" valid setzeX$"JN" when;
      Message("Artikel ohne Bewegung auf X = Ex-Artikel setzen?")
    @ 18,20 say "ab Datum (inkl.)                  :" get DatVon;
      valid;
      DatVon>=startDate;
      .or.empty(DatVon) when Message("Start-Datum (mind. "+dtoc(startDate)+") eingeben.   "+;
      "@Leer@=alle")
    read

    if ABBRUCH
      loop
    endif

    if setzeX=="J"
      if Message("Artikel ohne Bewegung auf X = Ex-Artikel setzen?  Bitte best�tigen (@b@)","B")<>"B"
        loop
      endif
      Message("Artikel-Datei wird kopiert.  @Bitte warten@")
      backup("Artikel")
    endif

    if ABBRUCH .or. ! druck_BS("Artikel-Letzte-Bewegung") // Abbruch
      loop
    endif

    UR:=LISTE->UNT_RAND

    // merke von
    von:=ARTIKEL->ArtNr

    Message("Liste wird erstellt.   Bitte warten...")
    if DatVon>startDate
      select Waraus
      set filter to WARAUS->Datum>=DatVon
    endif

    if ! empty(selArt)
      select Artikel
      set filter to getArtikelArt() $ selArt
      loca for ARTIKEL->ArtNr>=von
    endif

    select Artikel
    do while .not.ARTIKEL->(eof()).and. ARTIKEL->artnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Artikel letzte Bewegung          vom:',getUser():date,space(34),'Seite',str(seite,3)
      ? 'Artikel von:',von,' bis:',bis
      ? '----------------------------------------------------------------------------------------'+;
        '----'
      ? 'Art-Nr.   Bezeichnung                       Bewegung  Art  Bestand LagerOrt    KST  '+;
        'Verkauft'
      ? '----------------------------------------------------------------------------------------'+;
        '----'
      do while .not.eof().and. ARTIKEL->ArtNr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        // if (AVPOST->(eof()) .and. AVAUS->(eof()))
        // letzte Bewegung
        letzteBewegung:=ctod("  .  .  ")
        programm:=""

        WARAUS->(dbseek(ARTIKEL->ArtNr))
        if (! WARAUS->(EOF()))
          // neu 20080805, keine manuellen Bewegungen
          do while !WARAUS->(bof()) .and. ARTIKEL->ArtNr==WARAUS->Artnr ;
            .and. ("Artikel-Stamm" $ WARAUS->Programm )
            WARAUS->(dbskip(1))
          enddo
          if !WARAUS->(bof()) .and. !WARAUS->(eof()) .and. ARTIKEL->ArtNr==WARAUS->Artnr
            letzteBewegung:=WARAUS->Datum
            programm:=WARAUS->Programm
          endif
        endif
        if WARAUS->(bof()) .or. WARAUS->(eof()) .or. ARTIKEL->ArtNr<>WARAUS->Artnr
          // keine Bewegung vorhanden
          if setzeX=="J" .and. getArtikelArt()<>"T"
            // select Artikel
            if ! rec_lock(5)
              Error(TRY_AGAIN)
            else
              replace ARTIKEL->Art with "X"
              dbcommit()
              dbunlock()
              Programm:="Art auf X gesetzt!"
            endif
          endif
        endif

        kom=trim(ARTIKEL->bez1)
        ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1
        if getArtikelArt()=="T"
          ?? space(2),space(10),getArtikelArt()
        else
          ?? space(2),letzteBewegung,space(1),getArtikelArt(),ARTIKEL->Lagebest,getArtikelLagerOrt(12),;
            ARTIKEL->KostNr,str(ARTIKEL->verkauft,9,2),programm
        endif
        if .not. empty(ARTIKEL->bez2)
          ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
        endif
        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

  enddo
  cls
  close data
RETURN
/* EOP ArtLetztBeweg */



/* PROCEDURE ArtLoesch()
*
*  listet alle Artikel mit zugehor. Stuecklisten auf
*
*/
PROCEDURE ArtLoesch()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis,letzteBewegung,merkArtNr,waraus
LOCAL Stop:=.f.
LOCAL ArtAkt:="",kom

  cls
  titel("Artikel loeschen")

  if ! open("Artikel","AvAus","AvPOst","Waraus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /* Relationen setzten */
  select avpost
  AVPOST->(OrdSetFocus(2))
  select Waraus
  WARAUS->(OrdSetFocus(2))
  SELECT Artikel
  SET RELATION TO Artikel->ArtNr INTO AvAus

  do while ! ABBRUCH
    /* Liste von bis */
    seite:=0; zeile:=0
    @ 4,0 clear
    von:=bis:=space(len(ARTIKEL->ArtNr))
    bis:=von_bis("Artikel")
    if ABBRUCH
      loop
    endif

    Umgebung(WRITE)

    if ABBRUCH .or. ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    // merke von
    von:=ARTIKEL->ArtNr

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not.eof().and. ARTIKEL->artnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Artikel loeschen          vom:',getUser():date,space(12),'Seite',str(seite,3)
      ? 'Artikel von:',von,' bis:',bis
      ? '------------------------------------------------------------------------------------'
      ? 'Art-Nr.   Bezeichnung                          Letzte Bewegung Bestand   LagerOrt'
      ? '------------------------------------------------------------------------------------'
      do while .not.eof().and. ARTIKEL->ArtNr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        // letzte Bewegung
        letzteBewegung:="  .  .  "

        WARAUS->(dbseek(ARTIKEL->ArtNr))
        if (! WARAUS->(EOF()))
          letzteBewegung:=WARAUS->Datum
        endif

        kom=trim(ARTIKEL->bez1)
        ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(7),letzteBewegung,space(2),ARTIKEL->Lagebest,;
          getArtikelLagerOrt(20)
        if .not. empty(ARTIKEL->bez2)
          ? space(len(out(AVPOST->AvNr))),ARTIKEL->Bez2
        endif

        // Stueckliste drucken?
        if (!AVAUS->(eof()))
          ? space(9),"ACHTUNG Artikel hat Stueckliste."
        endif

        merkArtnr:=ARTIKEL->ArtNr
        select AvPost
        AVPOST->(dbseek(ARTIKEL->ArtNr))
        if (!AVPOST->(eof()))
          ? space(9),"ACHTUNG Artikel kommt in folgenden Stuecklisten vor:"
        endif
        do while (!AVPOST->(eof())) .and. AVPOST->ArtNr==merkArtNr
          ARTIKEL->(dbseek(AVPOST->AvNr))
          ? space(9),AVPOST->AvNr,ARTIKEL->Bez1
          AVPOST->(dbskip())
        enddo
        select Artikel
        ARTIKEL->(dbseek(merkArtNr))
        ?

        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

    Umgebung(LOAD)
    /***************** Artikel loeschen???     */

    IF Message("Artikel und Stuecklisten wirklich loeschen ? ( @$@==J / @N@ )","$N")=="$"

      if ABBRUCH .or. ! druck_BS() // Abbruch
        close data
        RETURN
      endif

      waraus:=(Message("Eintr�ge in Bewegungsdatei ebenfalls l�schen ? ( @J@ / @N@ )","JN")=="J")

      ? 'Artikel geloescht          vom:',getUser():date,space(12)
      ? 'Artikel von:',von,' bis:',bis
      ? '----------------------------------------------------------------------------------'
      ? 'Art-Nr.   Bezeichnung                           LagerOrt'
      ? '----------------------------------------------------------------------------------'

      ARTIKEL->(dbseek(von))
      do while .not.eof().and. ARTIKEL->artnr<=bis .and. ! stop

        ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(6),getArtikelLagerOrt(30)

        // Stueckliste loeschen?
        if (!AVAUS->(eof()))
          select AVAUS
          rec_lock(0)
          delete
          ?? " * plus Stueckliste."
        endif

        merkArtnr:=ARTIKEL->ArtNr
        select AvPost
        AVPOST->(dbseek(ARTIKEL->ArtNr))
        do while (!AVPOST->(eof())) .and. AVPOST->ArtNr==merkArtNr
          rec_lock(0)
          delete
          AVPOST->(dbskip())
        enddo

        // Waraus loeschen
        if waraus
          select Waraus
          WARAUS->(dbseek(ARTIKEL->ArtNr))
          do while (!WARAUS->(eof())) .and. WARAUS->ArtNr==merkArtNr
            rec_lock(0)
            delete
            WARAUS->(dbskip())
          enddo
        endif

        // Artikel loeschen
        select Artikel
        ARTIKEL->(dbseek(merkArtNr))
        rec_lock(0)
        delete

        skip
      enddo
      dbcommitall()
      dbunlockall()
      Drucker("Off")

    endif

  enddo
  cls
  close data
RETURN
/* EOP ArtLoesch */

/* PROCEDURE ZeitListe()
*
*  listet alle Zeiten mit zugehor. Stuecklisten auf
*
*/
PROCEDURE ZeitListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL von,bis,merkStdNr
LOCAL Stop:=.f.
LOCAL ArtAkt:=""

  cls
  titel("Machinen / Zeiten anzeigen")

  if ! open("Maschine","AvPOst","Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  // Filter setzen
  select avpost
  index on AVPOST->ArtNr+AVPOST->AvNr tag TEMP_INDEX TEMPORARY ADDITIVE for;
    AVPOST->Text=="A" .and. AVPOST->Art=="V"
  select Maschine

  do while ! ABBRUCH
    /* Liste von bis */
    seite:=0; zeile:=0; stop:=.f.
    @ 4,0 clear
    von:=bis:=space(len(MASCHINE->StdNr))
    bis:=von_bis("Maschine")
    if ABBRUCH
      loop
    endif

    Umgebung(WRITE)

    if ABBRUCH .or. ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    // merke von
    von:=MASCHINE->StdNr

    Message("Liste wird erstellt.   Bitte warten...")

    do while .not.eof().and. MASCHINE->Stdnr<=bis .and. ! stop
      seite=seite+1
      zeile:=0
      ? 'Maschinen / Zeiten       vom:',getUser():date,space(12),'Seite',str(seite,3)
      ? 'von:',von,' bis:',bis
      ? '--------------------------------------------------------------------------'
      ? 'Nr.   Bezeichnung'
      ? '--------------------------------------------------------------------------'
      do while .not.eof().and. MASCHINE->StdNr<=bis;
        .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
        ? MASCHINE->StdNr,MASCHINE->Bez

        // Stueckliste drucken?
        merkStdNr:=MASCHINE->StdNr
        select AvPost
        AVPOST->(dbseek(MASCHINE->StdNr))
        if (!AVPOST->(eof()))
          ? space(3),"kommt in folgenden Stuecklisten vor:"
          ?
        endif
        do while (!AVPOST->(eof())) .and. trim(AVPOST->ArtNr)==merkStdNr
          ARTIKEL->(dbseek(AVPOST->AvNr))
          ? space(3),AVPOST->AvNr,ARTIKEL->Bez1
          AVPOST->(dbskip())
        enddo
        select Maschine
        ?

        skip
        Stop=Stop_Key()
      enddo
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

    Umgebung(LOAD)

  enddo
  cls
  close data
RETURN
/* EOP >ZeitLoesch */

/* PROCEDURE Erl�s-Konten-Liste
*
*  einzeln je Posten oder summiert
*
*  FIXME: SO_Rabatt wird hier auch noch auf Fracht berechnet, das ist falsch
*         aber Liste ist mehr oder weniger obsolete  
*
*/
PROCEDURE Erl_Kto_Liste
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL Sum_in:=0.00,sum_eg:=0.00,sum_so:=0.00, sum_all:=0
LOCAL Merk_gr,Merk_Te,wert,tab
LOCAL in:=0.00,eg:=0.00,so:=0.00,erst:=.t.,gesamt
  static selektion, von, bis, post

  default selektion:=left(getProperty("Miki.erlgrup.auswahl","")+space(60),60)
  default von:=getUser():date
  default bis:=getUser():date
  default post:="N"

  cls
  titel("Erl�skonten - Liste drucken")

  if ! open("Rechaus","Erl_Grup","RechPost")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  // Relationen setzten
  SELECT RechPost
  SET RELATION TO RECHPOST->RechNr INTO Rechaus,to RECHPOST->Erl_Gruppe into Erl_Grup

  @ 7,3 to 16,75
  @ 8,5 say "von:" get von when message("Zeitraum Anfang eingeben.")
  @ 10,5 say "bis:" get Bis when message("Zeitraum Ende eingeben.")
  @ 13,5 say "Auswahl:" get selektion PICTURE "@K" ;
    when message("Auswahl an Erl�sgruppen_nummern eingeben. Leertaste als Trennzeichen.  @Leer@=Alle.")
  @ 15,5 say "Posten ausdrucken...:" get post PICTURE "!" valid post $"JjNn" ;
    when message("Einzelne Posten ausdrucken? (@J@/@N@)")
  read
  if empty(von) .or. empty(bis) .or. ABBRUCH .or. ! druck_BS()
    clear
    close data
    return
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  index on RECHPOST->Erl_Gruppe+RECHPOST->Erl_Konto tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    (von<=RECHPOST->ReaDat .and. RECHPOST->ReaDat<=Bis) .and.;
    (empty(selektion) .or. (RECHPOST->Erl_Gruppe $ selektion .and. ! empty(RECHPOST->Erl_Gruppe))) .and. alltrim(RECHPOST->Artnr) <> "*"
  go top

  stop:=Stop_Key()
  do while .not. eof() .and. ! stop
    Zeile=0
    Seite=Seite+1
    ?
    ? "Ums�tze nach Erl�skonten: "+dtoc(von)+" bis "+dtoc(bis)
    ?
    If post $ "Jj"
      ? "Gruppe                           Re.Nr.     Art.Nr.            Inland             EU    "+;
        "Drittl�nder          Summe"
      ? "----------------------------------------------------------------------------------------"+;
        "--------------------------"
    else
      ? "Gruppe                                    Inland             EU    Drittl�nder          "+;
        "Summe"
      ? "----------------------------------------------------------------------------------------"+;
        "-----"
    endif
    do while .not. eof() .and. Zeile < DRUCKER->Laenge-LISTE->Unt_Rand .and. ! Stop

      Merk_gr=RECHPOST->Erl_Gruppe
      Merk_Te=ERL_GRUP->Text
      in=0.00
      eg=0.00
      so=0.00
      erst=.t.
      do while Merk_Gr=RECHPOST->Erl_Gruppe .and. .not. eof() .and. ! stop
        wert=RECHPOST->Gelief*RECHPOST->Preis
        If RECHPOST->PE="H"
          wert=wert/100
        endif
        Wert=wert-wert*RECHPOST->Rabatt/100 // abzgl. Posten-Rabatt
        Wert=wert-wert*RECHAUS->So_Rabatt/100 // abzgl. Sonder-Rabatt
        DO CASE
        CASE RECHPOST->Erl_Kz="In"
          tab=1
          In=In+wert
        CASE RECHPOST->Erl_Kz="EG"
          tab=12+1+3
          EG=EG+wert
        OTHERWISE
          tab=24+2+5
          So=So+wert
        ENDCASE
        If post $ "Jj"
          If erst
            ? Merk_Gr,Merk_Te,ZEIGE_RECHNR+RECHPOST->RechNr,space(3),ZEIGE_ARTNR+RECHPOST->ArtNr,;
              space(tab),transform(wert,"999,999,999.99")
            erst=.f.
          else
            ? Space(2),space(30),ZEIGE_RECHNR+RECHPOST->RechNr,space(3),;
              ZEIGE_ARTNR+RECHPOST->ArtNr,space(tab),transform(wert,"999,999,999.99")
          endif
        endif
        skip
        stop:=Stop_Key()
      enddo
      gesamt:=in+eg+so
      If post $ "Jj"
        ? "--------------------------------------------------------------------------------------"+;
          "----------------------------"
        ? space(2),space(30),space(20),transform(in,"999,999,999.99"),;
          transform(eg,"999,999,999.99"),transform(so,"999,999,999.99") ,;
          transform(gesamt,"999,999,999.99"),"EURO"
        ?
      else
        ? Merk_gr,Merk_Te,transform(in,"999,999,999.99"), transform(eg,"999,999,999.99"),;
          transform(so,"999,999,999.99") ,transform(gesamt,"999,999,999.99"),"EURO"
      endif
      Sum_In=Sum_In+In
      Sum_EG=Sum_Eg+EG
      Sum_So=Sum_So+So
      SUM_All += gesamt
    enddo
    If post $ "Jj"
      ? "========================================================================================"+;
        "=========================="
      ? space(2),space(51),transform(Sum_in,"999,999,999.99"),transform(sum_eg,"999,999,999.99"),;
        transform(sum_so,"999,999,999.99") ,transform(sum_all,"999,999,999.99"),"EURO"
    else
      ? "----------------------------------------------------------------------------------------"+;
        "-----"
      ? space(2),space(30),transform(Sum_in,"999,999,999.99"),transform(sum_eg,"999,999,999.99"),;
        transform(sum_so,"999,999,999.99") ,transform(sum_all,"999,999,999.99"),"EURO"
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
  cls
  close data

RETURN
/* EOP */

  /** Pr�ft alle RahmenAB auf Zeit, Mengen oder     Budget Limits
  *
  * Paramter: Abfrage -> false: ohne Abfrage, automat. mit Limits -> email schicken (Crontab)
  *
  *  FIXME: SO_Rabatt wird hier auch noch auf Fracht berechnet, das ist falsch
  *         aber RahmenAbs haben i.d.R. keine Fracht
  */
PROCEDURE RahmenABListe(Abfrage)
LOCAL rest,Zeile:=0,stop:=.f.,liFullName,merkNr,count:=0,zeitLimit,merkZeit,erst
LOCAL Seite:=1,merkSatz,merkFilter,lr:=2,rechnWert,merkAbrufNr:="",header:=.f.
LOCAL merkPost,merkArtnr,header2,summeAb:=0,eWert
MEMVAR von,bis,alle // geht sonst nicht im "set filter to &(merkFilter)"
PRIVATE von,bis,alle:=.f.

  default Abfrage:=.t.

  cls
  titel("Rahmenauftr�ge kontrollieren")

  if ! open("AufPost","AufAus","System","Einheit","Rechaus","Kunden","KundSped")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if Abfrage
    M->bis:=von_bis("Kunden")
    if empty(M->bis)
      cls
      close data
      RETURN
    endif
    M->von:=KUNDEN->KundNr

    M->alle:=Message("@A@lle Auftr�ge anzeigen oder nur @o@ffene? (@A@/@O@)","AO","O")=="A"

    if ! Druck_BS()
      cls
      RETURN
    endif
    @ 2,0 clear
    Message("Liste wird erstellt.  Bitte warten...")
  else
    Drucker("PDF",,,,PDF_NO_CONFIRM)
  endif


  select AufPost
  set rela to AUFPOST->Me into Einheit

  // ***** Rahmenauftr�ge Artikel ***********************
  select AufAus
  if empty(M->bis)
    set filter to AUFAUS->AufArt$"D" .and. (M->alle .or. AUFAUS->Erledigt<>"J")
  else
    set filter to AUFAUS->AufArt$"D" .and. (M->alle .or. AUFAUS->Erledigt<>"J") .and. ;
      AUFAUS->KundNr>=M->von .and. AUFAUS->KundNr<=M->bis
  endif
  merkFilter:=AUFAUS->(dbfilter())

  seite:=0
  go top
  do while ! AUFAUS->(eof())
    zeile:=0
    // drucke Posten des Rahmeauftrags
    merkNr:=AUFAUS->AufNr
    select AufPost
    AUFPOST->(dbseek(AUFAUS->AufNr))
    do while ! AUFPOST->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop ;
      .and. AUFAUS->AufNr==AUFPOST->AufNr

      if M->alle .or. left(AUFPOST->KW,1)<>"X"
        count++

        if ! header
          header:=.t.
          if Abfrage
            ? "Rahmenvertr�ge Artikel - akt. KW:"+getCurrentKW()
          else
            ? "Auslaufende Rahmenvertr�ge Artikel - akt. KW:"+getCurrentKW()
          endif
          ? replicate("=",140)
          ? "AB-Nr.    Kd.Nr.  Kurzname                     Art.nr.  Bezeichnung                  "+;
            "                 Menge    Geliefert      Rest   Lief.KW"
          ? replicate("=",140)
        endif

        ? AUFAUS->Aufnr,space(2),AUFAUS->KundNr,AUFAUS->Kurzname,;
          AUFPOST->ArtNr,AUFPOST->Komm1,str(AUFPOST->Menge)+" - "+;
          +str(AUFPOST->GeliefGes)+" = "+str(AUFPOST->Menge-AUFPOST->GeliefGes,7,2)+;
          " "+EINHEIT->Text,AUFPOST->KW

        // drucke Abrufe zu Posten
        merkSatz:=AUFAUS->(recno())
        merkPost:=AUFPOST->(recno())
        merkArtNr:=AUFPOST->ArtNr
        select AufAus
        set filter to
        loca for AUFAUS->Ab_AufNr==merkNr
        header2:=.f.
        do while ! AUFAUS->(eof())
          select AufPost
          AUFPOST->(dbseek(AUFAUS->AufNr))
          do while ! AUFPOST->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop;
            .and. AUFAUS->AufNr==AUFPOST->AufNr

            if merkArtNr==AUFPOST->ArtNr // could be tuned with indexord 3

              if ! header2
                header2:=.t.
                ?
                ? space(lr),"Abrufe:"
                ? space(lr),"======="
              endif

              rest:=AUFPOST->Menge-AUFPOST->GeliefGes
              if Abfrage .or. rest/AUFPOST->Menge*100 <= SYSTEM->RahmProz .or.;
                KWDiff(getCurrentKW(),AUFPOST->Kw) <= SYSTEM->RahmZeit
                if LEN(alltrim(AUFPOST->ArtNr)) > 1

                  ? space(lr),AUFAUS->Aufnr,AUFAUS->KundNr,AUFAUS->Kurzname,;
                    AUFPOST->ArtNr,AUFPOST->Komm1,str(AUFPOST->Menge)+" - "+;
                    +str(AUFPOST->GeliefGes)+" = "+str(AUFPOST->Menge-AUFPOST->GeliefGes,7,2)+;
                    " "+EINHEIT->Text,AUFPOST->KW
                endif
              endif
            endif

            Stop=Stop_Key()
            skip
          enddo
          select Aufaus
          cont // n�chster Abrufauftrag
        enddo

        // zur�ck auf Rahmenauftr�ge
        set filter to &(merkFilter)
        AUFAUS->(dbgoto(Merksatz))
        AUFPOST->(dbgoto(MerkPost))
        if header2
          ?
        endif
        select AufPost
      endif

      Stop=Stop_Key()
      skip
    enddo
    select AufAus

    skip
  enddo

  if count > 0
    ?
    ?
  endif

  // ******* Rahmenauftr�ge Budget *************************************
  select Aufpost
  set filter to
  select Aufaus
  if empty(M->bis)
    set filter to AUFAUS->AufArt$"B" .and. (M->Alle .or. AUFAUS->Erledigt<>"J")
  else
    set filter to AUFAUS->AufArt$"B" .and. (M->Alle .or. AUFAUS->Erledigt<>"J") .and. ;
      AUFAUS->KundNr>=M->von .and. AUFAUS->KundNr<=M->bis
  endif
  merkFilter:=AUFAUS->(dbfilter())

  header:=.f.
  Seite:=0
  go top
  do while ! AUFAUS->(eof())
    zeile:=0
    do while ! AUFAUS->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
      merkNr:=AUFAUS->AufNr
      merkSatz:=AUFAUS->(recno())
      zeitLimit:=.f.
      // pr�fe auf Zeit-Limit bei automat. Crontab Job
      if ! Abfrage
        select Aufpost
        set filter to AUFPOST->AufNr==merkNr
        go top
        do while ! AUFPOST->(eof()) .and. ! zeitLimit
          zeitLimit:=KWDiff(getCurrentKW(),AUFPOST->Kw) <= SYSTEM->RahmZeit
          if zeitLimit
            merkZeit:=AUFPOST->KW
          endif
          skip
        enddo
        set filter to
        select AUFAUS
      endif

      if Abfrage .or. (AUFAUS->Netto-AUFAUS->RahmBez)/AUFAUS->Netto*100 <= SYSTEM->RahmProz .or.;
        zeitLimit
        if ! header
          header:=.t.
          if Abfrage
            ? "Rahmenvertr�ge Budget - akt. KW:"+getCurrentKW()
          else
            ? "Auslaufende Rahmenvertr�ge Budget - akt. KW:"+getCurrentKW()
          endif
          ? replicate("=",45)
        endif
        rechnWert:=0
        ?
        ? AUFAUS->Aufnr,AUFAUS->KundNr+AUFAUS->Kurzname
        ? "Gesamt-Wert:",transstr(AUFAUS->Netto,11,2)
        ? "Abgerufen..:",transstr(AUFAUS->RahmBez,11,2)
        ? "Rest.......:",transstr(AUFAUS->Netto-AUFAUS->RahmBez,11,2),;
          "Euro  (nur Rechnungen ohne offene Auftr�ge)"
        if zeitLimit
          ?? "   Lief.KW:",merkZeit
        endif
        ?
        erst:=.t.
        summeAb:=0
        count++

        // drucke alle Abruf-Auftragsposten zum Budget Auftrag
        merkAbrufNr:=""
        select aufaus
        set filter to AUFAUS->Ab_AufNr==merkNr
        go top
        do while ! AUFAUS->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop
          merkAbrufNr:=merkAbrufNr + AUFAUS->AufNr+"/"

          // 26.11.2012 jetzt nur noch mit Ausdruck der offenen (!) AB Posten
          select Aufpost
          AUFPOST->(dbseek(AUFAUS->AufNr))
          do while ! AUFPOST->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! Stop .and.;
            AUFPOST->AufNr==AUFAUS->AufNr
            if LEN(alltrim(AUFPOST->ArtNr)) > 1 .and. AUFPOST->Menge>AUFPOST->GeliefGes
              if erst
                ? "Offene Abruf-Auftr�ge:"
                ? "Ab-Nr. Art.Nr  Bezeichnung                                   Menge     Gelief.         "+;
                  "Rest           Wert Lief.KW"
                ? replicate("=",114)
                erst:=.f.
              endif
              eWert:=round((AUFPOST->Menge-;
                AUFPOST->GeliefGes)*AUFPOST->Preis/if(AUFPOST->PE=="H",100,1),2)
              // Posten Rabatt
              if AUFPOST->Rabatt>0
                eWert:=round(eWert*(100-AUFPOST->Rabatt)/100,2)
              endif
              // Sonder Rabatt
              if AUFAUS->So_Rabatt>0
                eWert:=round(eWert*(100-AUFAUS->So_Rabatt)/100,2)
              endif
              ? AUFPOST->AufNr,AUFPOST->ArtNr,AUFPOST->Komm1,AUFPOST->Menge,AUFPOST->GeliefGes,;
                AUFPOST->Menge-AUFPOST->GeliefGes,EINHEIT->Text,str(eWert,10,2),AUFPOST->KW
              summeAb += eWert

            endif
            Stop=Stop_Key()
            skip
          enddo
          select AUFAUS
          skip
        enddo

        if SummeAB<>0
          ? replicate("=",114)
          ? space(93),str(SummeAb,12,2),"Euro"
        endif

        // zugeh. Rechnungen ausdrucken
        select Rechaus
        loca for ! empty(RECHAUS->AufNr) .and. RECHAUS->AufNr $ merkAbrufNr
        if ! RECHAUS->(eof())
          ?
          ? "Alle Rechnungen:"
        endif
        do while ! RECHAUS->(eof())
          ? "Rechn.Nr.:",RECHAUS->RechNr,RECHAUS->ReaDat,RECHAUS->Netto
          rechnWert+=RECHAUS->Netto
          cont
        enddo
        if rechnWert<>0
          ? replicate("=",37)
          ? space(24),str(rechnWert,12,2),"Euro"
          ?
        endif
        select AufAus

        // gehe auf ursp. Rahmenvertrag
        set filter to &(merkFilter)
        AUFAUS->(dbgoto(Merksatz))
      endif
      skip
    enddo
  enddo

  getUser():getCurrentPrintJob():endDoc()
  if ! Abfrage
    liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
    if count>0
      email(MAIN_EMAIL,;
        "Auslaufende Rahmenauftr�ge vom: "+dtoc(getUser():date),"Bitte �berpr�fen!",liFullName)
    endif
  endif
  getUser():setCurrentPrintJob(NIL)

  close data
return
/** eop */

/** Listet alle Artikel auf bei denen die Mindest-Bestellmenge (Soll) > als die 1. Stufe der Rabatt-Tabelle
  */
procedure MindBestRabattCheck(quiet)
LOCAL Zeile:=0,count:=0

  default quiet:=.f.

  cls
  Titel("Mindest-Bestellmenge / Rabattstaffel Check")

  if quiet
    Drucker("PDF")
  else
    if ! druck_BS() // Abbruch
      close data
      RETURN
    endif
  endif

  if ! open( "Artikel","Rabatt","Einheit" , "ArtMinOrd")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten...")

  select Artikel
  set rela to ARTIKEL->RabattGr into Rabatt, ARTIKEL->ME into Einheit
  locate for ! empty(ARTIKEL->RabattGr) .and.;
    ARTIKEL->MinOrderS>0 .and. ARTIKEL->MinOrderS >= RABATT->Meng1 .and. ! getArtikelArt()$"XT"
  if ! ARTIKEL->(eof())
    ? "Artikel mit Mindest-Bestellmenge (Soll) gr��er als 1. Stufe der Rabatt-Staffel vom:",;
      getUser():date
    ? "=========================================================================================="+;
      "=="
  endif
  do while ! ARTIKEL->(eof())
    ARTMINORD->(dbseek(ARTIKEL->ArtNr))
    if ARTMINORD->MinOrderS <> ARTIKEL->MinOrderS // nur falls Wert sich ge�ndert hat
      ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,"Mindest-Bestellmenge:",ARTIKEL->MinOrderS,EINHEIT->Text
      ? space(len(out(ARTIKEL->ArtNr))),"Rabbattgruppe:",ARTIKEL->RabattGr,"    1. Stufe:",;
        RABATT->Rab1,"%",space(10),RABATT->Meng1,EINHEIT->Text
      ? space(len(out(ARTIKEL->ArtNr))),"verkauft:",ARTIKEL->verkauft
      ?
      count++

      select ArtMinOrd
      if ARTMINORD->(eof())
        add_rec()
        select Artikel
        replace ARTMINORD->ArtNr with ARTIKEL->ArtNr
      else
        rec_lock(0)
      endif

      replace ARTMINORD->MinOrderS with ARTIKEL->MinOrderS
      dbcommit()
      dbunlock()
      select Artikel

    endif

    cont
  enddo
  if quiet
    getUser():getCurrentPrintJob():endDoc()
    if count>0
      email(MAIN_EMAIL,;
        "Artikel mit Mindest-Bestellmenge (Soll) gr��er als 1. Stufe der Rabatt-Staffel vom: "+;
        dtoc(getUser():date),"Bitte �berpr�fen!",getUser():getCurrentPrintJob():pdfFullFileName)
    endif
    getUser():setCurrentPrintJob(NIL)
  else
    drucker("OFF")
  endif

  cls
  close data
return
/** eop */

/** Listet alle Artikel auf bei denen die Mindest-Bestellmenge (Soll) > die Ist-Menge ist
  */
procedure MindBestSollIstCheck(quiet)
LOCAL Zeile:=0,count:=0

  default quiet:=.f.

  cls
  Titel("Mindest-Bestellmenge / Soll/Ist Check")

  if quiet
    Drucker("PDF")
  else
    if ! druck_BS() // Abbruch
      close data
      RETURN
    endif
  endif

  if ! open( "Artikel","Rabatt","Einheit" )
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten...")

  select Artikel
  set rela to ARTIKEL->RabattGr into Rabatt, ARTIKEL->ME into Einheit
  locate for ARTIKEL->MinOrderS>0 .and.;
    ARTIKEL->MinOrdInt>0 .and. ARTIKEL->MinOrderS > ARTIKEL->MinOrdInt .and. ! getArtikelArt()$"XT"
  if ! ARTIKEL->(eof())
    ? "Artikel Mindest-Bestellmenge Soll gr��er als Ist-Wert   vom:",getUser():date
    ? "======================================================================"
    ? "Art.Nr.    Bezeichnung     Mindest-Bestellmenge Soll    Ist  Differenz"
    ? "======================================================================"
  endif
  do while ! ARTIKEL->(eof())
    ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(3),ARTIKEL->MinOrderS,ARTIKEL->MinOrdInt,;
      str(ARTIKEL->MinOrdInt-ARTIKEL->MinOrderS,6),EINHEIT->Text
    count++
    cont
  enddo
  if quiet
    getUser():getCurrentPrintJob():endDoc()
    if count>0
      email(MAIN_EMAIL,;
        "Artikel mit Mindest-Bestellmenge Soll gr��er als Ist-Wert vom: "+;
        dtoc(getUser():date),"Bitte �berpr�fen!",getUser():getCurrentPrintJob():pdfFullFileName)
    endif
    getUser():setCurrentPrintJob(NIL)
  else
    drucker("OFF")
  endif

  cls
  close data
return
/** eop */

/** Listet alle Artikel Mit Mehfrachspritzungen auf
  */
procedure MehrfachSpritzListe()
LOCAL Zeile:=0,count:=0
LOCAL merkArtNr, art

  cls
  Titel("Mehrfach-Spritzungen")

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  if ! open( "Artikel","Mehrfach")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  art:=Message("Nur sortenreine Mehrfachspritzungen?  (@J@/@N@/@A@lle)","JNA")

  Message("Liste wird erstellt.  Bitte warten...")

  select Mehrfach
  go top
  ? "Mehrfach-Spritzungen          vom:",getUser():date
  ? "============================================================================"
  ? "Art.Nr. Menge Bezeichnung                                   Nutzen"
  ? "============================================================================"
  do while ! MEHRFACH->(eof())
    if (art == "J" .and. (MEHRFACH->Nutzen1<>1 .or. MEHRFACH->Nutzen2<>1)) .or. ;
      (art == "N" .and. (MEHRFACH->Nutzen1==1 .and. MEHRFACH->Nutzen2==1))
      skip
      loop
    endif
    ARTIKEL->(dbseek(MEHRFACH->ArtNr))
    ? out(MEHRFACH->ArtNr),space(0),ARTIKEL->Bez1
    merkArtNr:=MEHRFACH->ArtNr
    do while ! MEHRFACH->(eof()) .and. merkArtNr==MEHRFACH->ArtNr
      ARTIKEL->(dbseek(MEHRFACH->ANr))
      ? "  ->",MEHRFACH->Menge,"x",out(MEHRFACH->ANr),ARTIKEL->Bez1,;
        str(MEHRFACH->Nutzen1,2)+"/"+str(MEHRFACH->Nutzen2,2)
      if ! empty(MEHRFACH->Gruppe)
        ?? "Gruppe:",MEHRFACH->Gruppe
      endif
      skip
    enddo
  enddo
  drucker("OFF")

  cls
  close data
return
/** eop */

/* Listet den Umsatz f�r ein Kostenstelle auf
*/
PROCEDURE UmsatzKostenStelle(KostStNr)
LOCAL vonDat:=ctod( "01" + substr( dtoc( getUser():date ) , 3 ) )
LOCAL bisDat:=getUser():date
LOCAL ArtNrvon,ArtNrBis
LOCAL gesamt:=0
LOCAL seite:=0, zeile:=0 , Stop:=.f.
LOCAL GetList:={}

  Umgebung( WRITE_ALL )

  cls
  titel("Kostenstellen - Liste: "+KostStNr)

  if ! open("Artikel","Einheit","kostenSt","KstStamm")
    Error(TRY_AGAIN)
    cls
    Umgebung( LOAD )
    RETURN
  endif
  /* Relationen setzten */
  select Artikel
  set rela to ARTIKEL->ME into Einheit
  SELECT KostenSt
  set relation to KOSTENST->artnr into artikel

  KSTSTAMM->( dbseek(KostStNr) )
  ArtNrvon:=ArtNrBis:=space(len(ARTIKEL->ArtNr))

  @ 7,25 to 15,50
  @ 8,27 say "Datum von  :" get vonDat when Message("Zeitraum ausw�hlen.")
  @ 10,27 say "      bis  :" get bisDat
  @ 12,27 say "Art.Nr. von:" get ArtNrvon;
    valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)} when Message("1. Art.Nr "+;
    "eingeben.             @F12@=Hilfe")
  @ 14,27 say "        bis:" get ArtNrbis ;
    valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)};
    when Message("Letzte Art.Nr eingeben.         @F8@=kopieren    @F12@=Hilfe")
  read
  if ABBRUCH
    Umgebung( LOAD )
    RETURN
  endif

  Drucker("BS")

  Message("Liste wird erstellt.   Bitte warten...")
  if empty(ArtnrVon)
    ARTIKEL->(dbgotop())
    ArtNrVon:=ARTIKEL->ArtNr
  endif
  if empty(ArtnrBis)
    ARTIKEL->(dbgobottom())
    ArtNrbis:=ARTIKEL->ArtNr
  endif
  index on KOSTENST->(recno()) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    KOSTENST->KostNr == KostStNr .and. ;
    KOSTENST->Mod_Date >= vonDat .and. KOSTENST->Mod_Date <=bisDat .and. ;
    KOSTENST->ArtNr >= ArtNrvon .and. KOSTENST->ArtNr <= ArtNrBis ;
    eval myIndexProgress() every lastrec()/20

  go top
  do while ! eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'K O S T E N S T E L L E - LISTE       vom:',getUser():date,space(44),'Seite',str(seite,3)
    ? replicate('-',106)
    ? 'Datum   Auf.Nr.     Art Art-Nr.   Bezeichnung                        Menge   Kalk.Preis    '+;
      'ME  Wert (Euro)'
    ? replicate('-',106)
    do while .not. KOSTENST->(eof()).and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? KOSTENST->Mod_Date,KOSTENST->AuftrNr,KOSTENST->Art,out(KOSTENST->artnr),ARTIKEL->bez1,;
        KOSTENST->Menge,KOSTENST->Kalkpr,;
        if(ARTIKEL->Schluessel=="H","%"," "), EINHEIT->Text,KOSTENST->wert

      if ! empty(KOSTENST->Grund)
        ? space(8),KOSTENST->Grund
      endif
      gesamt=gesamt+KOSTENST->wert
      skip
      stop:=stop_key() // ESC gedr�ckt ?
    enddo
    if KOSTENST->(eof())
      ? replicate('-',106)
      ? KSTSTAMM->Bez+space(70),"Euro:",transstr(gesamt,14,2)
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  Drucker("Off")

  Umgebung( LOAD )
RETURN
/* EOP KostenSt_Liste */

/** gibt den Status der Indizierung rechts unten am BS aus */
static function myIndexProgress
  DispOutAt( maxrow() , maxCol()-8 , if(lastrec()>0,str((recno()/lastrec()) * 100 ,3),"100")+"%" )
return .t.
/** eof */


/* Druckt verkaufte Artikel (Rechnung) von mehreren Artikel  */
PROCEDURE VerkaufteArtList(Ausgabe)
LOCAL GetList:={}
LOCAL zeile, KopfText , stop:=.f.,Seite:=0
LOCAL ArtNrvon,ArtNrbis,d_von,d_bis
LOCAL mRechnNr, mMenge
LOCAL excel, objErr, export, oCol, bed, fracht:=" ",mKundName:=space(28), text
MEMVAR buffer
PRIVATE buffer

  Umgebung(WRITE_ALL)

  cls
  titel(kopfText)

  if ! open("Rechaus","RechPost","Kunden","Einheit","Artikel","avaus","AvPost")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  set key K_F8 to copy_buffer("",oGet,"")

  kopfText:="Verkaufte Artikel"

  ArtNrvon:=ArtNrbis:=space(len(ARTIKEL->ArtNr))
  d_von:=ctod("01.01."+str(year(getUser():date),4))
  d_bis:=getUser():date
  do while .t.
    cls
    titel(kopfText)
    @ 5,16 say "Ihre Auswahl:" color COLINV
    @ 6,14 to 20,68
    select Artikel
    @ 8,16 say "Art.Nr. von:" get ArtNrvon picture "@K" ;
      valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)};
      when Message("1. Art.Nr eingeben.             @F12@=Hilfe")
    @ 10,16 say "        bis:" get ArtNrbis picture "@K" ;
      valid { |oGet| check(Oget,"Artikel",.t.,.f.) .and. Ausgabe(oGet)};
      when Message("Letzte Art.Nr eingeben.         @F8@=kopieren    @F12@=Hilfe")


    @ 12,16 to 12,66
    @ 14,16 say "Datum von  :" get d_von ;
      when Message("Start-Datum eingeben.       @*@=Heute @+@/@-@")
    @ 15,16 say "Datum bis  :" get d_bis ;
      when Message("End-Datum eingeben.       @*@=Heute @+@/@-@")

    @ 17,16 say "Kd-Kurzname:" get mKundName picture "@!" when Message("Kunde-Kurzname eingeben.")
    @ 18,16 say "Fracht/Verpackung:" get fracht picture "!" ;
      when Message("Mit @F@racht & Verpackung, ohne = @leer@, @A@lles eingeben.")
    read

    if ABBRUCH
      cls
      set key K_F8 to
      Umgebung(LOAD)
      RETURN
    endif

    if d_von>d_bis
      Error("Ung�ltiger Datumsbereich.",.t.)
      loop
    endif

    Ausgabe:=druck_BS( cleanFileName(KopfText) , .t. , .t.)
    if ABBRUCH .or. ( valtype(Ausgabe) == "L" .and. ! Ausgabe )
      cls
      set key K_F8 to
      Umgebung(LOAD)
      RETURN
    endif

    bed:="RECHPOST->ReaDat >= ctod('"+dtoc(d_von)+"') .and. RECHPOST->ReaDat <= ctod('"+dtoc(d_bis)+"')"
    text:="von "+dtoc(d_von)+" bis "+dtoc(d_bis)
    if fracht=" "
      bed += ".and. len(alltrim(RECHPOST->ArtNr)) > "+str(FRACHT_LAENGE,1)
      text += " ohne Fracht"
    elseif fracht="F"
      bed += ".and. len(alltrim(RECHPOST->ArtNr)) <= "+str(FRACHT_LAENGE,1)
      text += " nur Fracht"
    endif

    if ! empty(ArtnrVon)
      bed += ".and. RECHPOST->ArtNr >= "+ArtNrVon
      text+=" Art.Nr. >= "+trim(ArtNrVon)
    endif
    if ! empty(ArtnrBis)
      bed += ".and. RECHPOST->ArtNr <= "+ArtNrBis
      text+=" Art.Nr. <= "+trim(ArtNrBis)
    endif

    if ! empty(mKundName)
      bed += ".and. '"+trim(mKundName)+"'$RECHAUS->KurzName"
      text+=" Kunde: "+trim(mKundName)
    endif

    Message("Liste wird erstellt.  Bitte warten...")

    /** Relationen setzen */
    select RechPost
    set rela to RECHPOST->V_KundNr into Kunden, RECHPOST->ME into Einheit , ;
      RECHPOST->RechNr into Rechaus
    select RechAus
    set rela to RECHAUS->V_KundNr into Kunden // ACHTUNG hier Versandkunde

    select RechPost
    index on RECHPOST->Rechnr+RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for &(bed)
    //! left(RECHPOST->ArtNr,3) == "530" .AND. 

    /** Spezial Funktion Zeige freischalten */
    M->specialZeige:={}
    aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf.";
      } )
    aadd( M->specialZeige , { chr(K_F5)+;
      chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
    aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )

    if ! ABBRUCH .and. ( valtype(Ausgabe) <> "L" .or. Ausgabe )
      if valtype(Ausgabe)=="C" // Excel
        Message("Datei wird erstellt.  Bitte warten.")
        if mkMyDir(getUser():exportPATH())
          BEGIN SEQUENCE // krit. Bereich
            export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
            excel:=ExcelExport():new()
            excel:addColumnsByName( {{ "ArtNr", "Artikel-Nr."}} )

            oCol:=ExcelColumn():new()
            oCol:title:="Bezeichnung"
            oCol:len:=32
            oCol:Codeblock:=;
              { || if(empty(RECHPOST->Komm2),RECHPOST->Komm1,RECHPOST->Komm1+MY_LF+RECHPOST->Komm2) }
            excel:addColumn(oCol)

            excel:addColumnsByName( {;
              { "RECHAUS->Rechnr","Rechn.Nr."},;
              { "RECHAUS->ReaDat","Rechn.Datum"},;
              { "RECHAUS->BestNr", "Bestell-Nummer" }})

            oCol:=ExcelColumn():new()
            oCol:fieldName:="Gelief"
            oCol:title:="Geliefert"
            // oCol:Sum:=.t.
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
            oCol:Codeblock:=;
              { || if(RECHPOST->ME == "0",val( VPE2ME(RECHPOST->ArtNr, RECHPOST->gelief)[1]),RECHPOST->Gelief) }
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="ME"
            oCol:title:="ME"
            oCol:Codeblock:=;
              { || if(RECHPOST->ME == "0",VPE2ME(RECHPOST->ArtNr, RECHPOST->gelief)[2],EINHEIT->Text) }
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:title:="Preis"
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_EURO
            oCol:Codeblock:=;
              { || ROUND( RECHPOST->Preis * RECHPOST->Gelief / IIF(RECHPOST->PE$"Hh",100,1) , 2) }
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:title:="Rabatt %"
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
            oCol:Codeblock:={ || (RECHAUS->So_Rabatt + RECHPOST->Rabatt) * -1 }
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:title:="Aufschlag %"
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
            oCol:Codeblock:={ || RECHAUS->Zuschlag }
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:title:="Gesamt-Preis"
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_EURO
            oCol:Codeblock:={ || getPostenPreis() }
            excel:addColumn(oCol)

            excel:addColumnsByName( {;
              { "KUNDEN->KurzName", "Empf�nger" }};
              )

            // oCol:=ExcelColumn():new()
            // oCol:fieldName:="VPE"
            // oCol:title:="Verpackungs-Einheit"
            // // oCol:Sum:=.t.
            // oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
            // oCol:Codeblock:=
            // { || if(RECHPOST->ME == "0",RECHPOST->gelief, 0) }
            // excel:addColumn(oCol)

            // oCol:=ExcelColumn():new()
            // oCol:fieldName:="ME-VPE"
            // oCol:title:=""
            // oCol:Codeblock:=
            // { || if(RECHPOST->ME == "0",EINHEIT->Text,"") }
            // excel:addColumn(oCol)

            excel:export(.f.,.f.,export)

            Message(export+" wurde erzeugt.  @Taste@","@")
          RECOVER USING objErr
            // nop, Fehler bereits protokolliert
          END SEQUENCE
        endif
        // ende we bail out
        Umgebung(LOAD)
        return
      endif
    endif

    Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

    go top
    do while .not. RECHPOST->(eof()) .and. ! stop
      Seite=Seite+1
      Zeile:=0
      ? 'Verkaufte Artikel '+left(text+space(80),80),'Seite',str(seite,3)
      ? '----------------------------------------------------------------------------------------'+;
        '------------------------'
      ? "Datum    Re.Nr. Art.Nr     Bezeichnung                Menge Verpackungs      Preis   "+;
        "Kd.Nr.    Empf�nger"
      ? "         AB-Nr. Best.Nr                                         Einheit       Euro"
      ? '----------------------------------------------------------------------------------------'+;
        '------------------------'
      _____fixedHeader_____

      do while .not. RECHPOST->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

        // Leerzeile bei neuem Artikel
        if mRechnNr == nil
          mRechnNr:=RECHPOST->RechNr
        elseif mRechnNr <> RECHPOST->RechNr
          ?
          mRechnNr:=RECHPOST->RechNr
        endif

        // drucke Posten
        mMenge:={ "" , "" }
        if RECHPOST->ME == "0" // VPE
          mMenge:=VPE2ME(RECHPOST->ArtNr, RECHPOST->gelief)
        endif

        ? RECHPOST->ReaDat,ZEIGE_RECHNR+RECHPOST->Rechnr,space(0),ZEIGE_ARTNR+RECHPOST->ArtNr,;
          left(RECHPOST->Komm1,30)
        ?? getValueNachkomma( RECHPOST->Gelief , 9 , RECHPOST->ME ), EINHEIT->Text,;
          transstr(ROUND( RECHPOST->Preis * RECHPOST->Gelief / IIF(RECHPOST->PE$"Hh",100,1) , 2),;
          10,2), space(2)
        ?? RECHAUS->V_KundNr, KUNDEN->KurzName
        ? space(8),ZEIGE_AUFNR+RECHAUS->AufNr,space(0),RECHAUS->BestNr
        if ! empty( mMenge[1] )
          ?? space(15), mMenge[1], mMenge[2]
        endif
        ?

        skip
        Stop:=stop_key()
      enddo // Blattl�nge

      Zeile:=FormFeed(Zeile,Seite)
      mRechnNr:=nil
    enddo // eof()
    Drucker("Off")

  enddo // infinite loop

  Umgebung(LOAD)

RETURN
/* EOP */


static function VPE2ME( mArtNr, mMenge )
LOCAL erg:={ "" , "" }

  Umgebung(WRITE_ALL)

  select AvPost
  dbseek( mArtNr )
  if ! AVPOST->(eof())
    EINHEIT->(dbseek( AVPOST->ME ))
    erg:={ getValueNachkomma( AVPOST->Menge * mMenge , 9 , AVPOST->ME ) , EINHEIT->Text }
  endif

  Umgebung(LOAD)

return erg
/** eof */


  /* Artikel K-Lager Mindestbestands-Liste */
PROCEDURE KlagMindBestListe(Ausgabe,mKundNr)
LOCAL Bauch:="" ,Bauch2:="" , Titel:="",KopfText:="", Bed:={ || .t.}
LOCAL FeldNr,d_von,d_bis,m_einheit:=" ",m_kundnr:=space(8)
LOCAL GetList:={} , Ausw, ListNames
LOCAL excel, export, oCol, emailText, Zeile:=0, Seite:=0, liFullName
LOCAL exportPath:=getBaseName( exeName() ) + "\DAT\TEMP"+BACKSLASH+getUser():id

  Umgebung(WRITE_ALL)

  ignore oCol

  if ! open( "Artikel" , "Einheit","Kunden","kundSped","AvPost")
    Error(TRY_AGAIN)
    cls
    Umgebung(LOAD)
    RETURN
  endif
  /* Relation setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  cls
  titel("K-Lager Mindest-Bestands-Liste")

  if mKundNr == Nil

    Message("Bitte Kunden-Nummer eingeben.       @F12@=Hilfe")
    @ 7,20 say "Kund.Nr.:" get M_kundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
    read
    if ! ABBRUCH
      @ 9,18 to 18,60
      @ 10,20 say "Ihre Auswahl:"
      @ 12,20 Prompt "1. K-Lager extern - nur Minderbestand"
      @ 13,20 Prompt "2. K-Lager extern - Alle             "
      @ 14,20 Prompt "3. K-Lager intern - nur Minderbestand"
      @ 15,20 Prompt "4. K-Lager intern - Alle             "
      @ 17,20 Prompt "5. K-Lager intern - Excel inkl. Baugr"
      Message("Ihre Auswahl bitte.                  @ESC@=Ende")
      Menu to Ausw
    endif

    if ABBRUCH
      cls
      Umgebung(LOAD)
      RETURN
    endif

    if Ausw <> 5
      Ausgabe:=Druck_Bs("KINTERN " , "xlsx" , .t.)
    else
      Ausgabe:="KINTERN"
    endif

  else
    M_kundNr:=mKundNr
    Ausw:=5
  endif

  KopfText:="K-Lager Mindest-Bestandsliste: "+KUNDEN->Kurzname
  Titel:="Art.Nr.    Bezeichnung                    Honsel-Nr.          ME  VK (Euro)    Max.Best. Akt.Bestand Mind.Best. Differenz"
  Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Hartnr,EINHEIT->Text,str(ARTIKEL->Preis1,9,2),If(ARTIKEL->Schluessel=='H','%',' '),ARTIKEL->KonsigMax,ARTIKEL->KonsigBest,ARTIKEL->KonsigMind,ARTIKEL->KonsigBest-ARTIKEL->KonsigMind}"

  do case
  case ausw=1
    Bed:={;
      ||;
      ARTIKEL->KonsigKdNr==M_KundNr;
      .and. getArtikelArt()<>"B" .and. ARTIKEL->KonsigBest<ARTIKEL->KonsigMind }
  case ausw=2
    Bed:={ || ARTIKEL->KonsigKdNr==M_KundNr .and. getArtikelArt()<>"B" }
  case ausw=3
    Bed:={;
      ||;
      ARTIKEL->KonsigKdNr==M_KundNr;
      .and. getArtikelArt()=="B" .and. ARTIKEL->KonsigBest<ARTIKEL->KonsigMind }
  case ausw=4
    Bed:={ || ARTIKEL->KonsigKdNr==M_KundNr .and. getArtikelArt()=="B"}
  case ausw=5
    Bed:={ || left(ARTIKEL->KonsigKdNr,len(M_KundNr))==M_KundNr .and. getArtikelArt()=="B" .and. ;
      (ARTIKEL->KonsigMind > 0 .or. ARTIKEL->KonsigMax > 0 )}
  endcase

  select Artikel
  go top
  d_von:=ARTIKEL->ArtNr
  go bottom
  d_bis:=ARTIKEL->ArtNr

  /* Liste ausdrucken / anzeigen */
  if ! ABBRUCH .and. ( valtype(Ausgabe) <> "L" .or. Ausgabe )
    if valtype(Ausgabe)=="C"
      Message("Datei wird erstellt.  Bitte warten.")
      select Artikel
      // set filter to &(bed)
      // ACHTUNG: geht hier schief bei Umgebung(LOAD) !!!
      // dbSetFilter( bed , "*unkown* see listen4.prg" )

      // index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE 
      // for &bed

      ordCondSet( bed, bed,,,,, RECNO(),,,,,, .T.,,,,, .T.,, .T. )
      ordCreate(, "TempTransNtx", "ARTIKEL->ArtNr", {|| ARTIKEL->ArtNr}, )

      //if mkMyDir(getUser():exportPATH())
      if mkMyDir(exportPATH)
        if Ausgabe != "KLager-VVG-bei-Miki-excel" // per email als PDF, server geht nicht als excel
          drucker("PDF", "K-Lager-VVG")
          go top
          do while ! ARTIKEL->(eof())
            seite=seite+1
            ? Ausgabe,space(80),"vom: ",getUser():date,space(19),'Seite',str(seite,3)
            ? "Art.Nr.    Bezeichnung                    Hartnr          Einheit    Konsig "+;
              "Baugruppen Auftrags  Verf�gbar   "+ "Konsig    Konsig      Bedarf  Bedarf"
            ? "                                                                       Best.      "+;
              "Best.    Best.             "+ "   Min       Max         Min     Max"
            ? replicate("=",145)
            do while .not.ARTIKEL->(eof()).and.zeile<DRUCKER->laenge-LISTE->Unt_Rand
              ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1, ARTIKEL->Hartnr, EINHEIT->Text,;
                str(ARTIKEL->KonsigBest,9,0), str(getKBaugrBestand(),9,0),;
                str(ARTIKEL->Disponiert,9,0), str(ARTIKEL->LageBest - ARTIKEL->Disponiert,9,0),;
                str(ARTIKEL->KonsigMind,9,0),str(ARTIKEL->KonsigMax,9,0),;
                str(if(ARTIKEL->KonsigMind==0,0,Max(ARTIKEL->KonsigMind -;
                (ARTIKEL->LageBest - ARTIKEL->Disponiert),0)),9,0),;
                str(if(ARTIKEL->KonsigMax==0,0,Max(ARTIKEL->KonsigMax -;
                (ARTIKEL->LageBest - ARTIKEL->Disponiert),0)),9,0)
              skip
            enddo
            Zeile:=FormFeed(Zeile,Seite)
          enddo

          getUser():getCurrentPrintJob():endDoc()
          liFullName:=getUser():getCurrentPrintJob():pdfFullFileName

          // erzeuge neg.Verf�gbarkeitsliste f�r Sonderartikel
          select Artikel
          Bed:={ || left(ARTIKEL->KonsigKdNr,len(M_KundNr))==M_KundNr .and. getArtikelArt()=="B" .and. ;
            ( ARTIKEL->KonsigMind <= 0 .and. ARTIKEL->KonsigMax <= 0 )}

          ListNames:=NegVerfueg("B",NIL,.t.,bed)

          emailText:="Bitte weiterleiten."
          if len(ListNames) == 0
            emailText += "||Nur Mindestbestand-Liste anbei, keine Sonderartikel."
          else
            emailText += "||Mindestbestand-Liste und Sonderartikel anbei."
          endif

          // Excel Datei hinzuf�gen
          ListNames:=HB_aIns( ListNames , 1, liFullName , .t.)

          //email(MY_EMAIL,"K-Lager Mindest-Bestandsliste VVG vom: "+dtoc(getUser():date),emailText,ListNames)
          email(MAIN_EMAIL,"K-Lager Mindest-Bestandsliste VVG vom: "+;
            dtoc(getUser():date),emailText,ListNames)

        else
          export:=exportPATH + BACKSLASH + cleanFileName(Ausgabe) + "-" + dtos(getUser():date)
          //export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe) + "-" + dtos(getUser():date)
          excel:=ExcelExport():new()

          if ausw <> 5 // alte Liste vor 20180911
            excel:addColumnsByName( ;
              { "ArtNr","Bez1","Hartnr",{"EINHEIT->Text","Einheit"},;
              { "ARTIKEL->Preis1", "VK" },;
              { "If(ARTIKEL->Schluessel=='H','%',' ')" , "E/H"},;
              "KonsigMax","KonsigBest","KonsigMind"} )

            excel:export(.f.,.f.,export)
            Message(export+" wurde erzeugt.  @Taste@","@")

          else // Neue Liste 20180911: inkl Baugruppen-Bestand

            excel:addColumnsByName( { ;
              "ArtNr",;
              {"Bez1","Bezeichnung"},;
              "Hartnr",;
              {"EINHEIT->Text","Einheit"}})

            oCol:=ExcelColumn():new()
            oCol:fieldName:="KonsigBest"
            oCol:title:="Konsig.Best."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="getKBaugrBestand()"
            oCol:title:="Baugr.Best."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="Disponiert"
            oCol:title:="Auftrags-Best."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="ARTIKEL->LageBest - ARTIKEL->Disponiert"
            oCol:title:="Verf�gbar"
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="KonsigMind"
            oCol:title:="Konsig.Min."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="KonsigMax"
            oCol:title:="Konsig.Max."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="if(ARTIKEL->KonsigMind==0,0,Max(ARTIKEL->KonsigMind - (ARTIKEL->LageBest - ARTIKEL->Disponiert),0))"
            oCol:title:="Bedarf Min."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            oCol:=ExcelColumn():new()
            oCol:fieldName:="if(ARTIKEL->KonsigMax==0,0,Max(ARTIKEL->KonsigMax - (ARTIKEL->LageBest - ARTIKEL->Disponiert),0))"
            oCol:title:="Bedarf Max."
            oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
            excel:addColumn(oCol)

            excel:oSheet:columns( 2 ):ColumnWidth:=40
            excel:oSheet:columns( 3 ):ColumnWidth:=22
            //excel:oSheet:Range( "E1:M1000" ):ColumnWidth:=14
            excel:oSheet:Range( "E1:M1" ):ColumnWidth:=14

            excel:export(.f.,.f.,export)

            // erzeuge neg.Verf�gbarkeitsliste f�r Sonderartikel
            select Artikel
            Bed:={ || left(ARTIKEL->KonsigKdNr,len(M_KundNr))==M_KundNr .and. getArtikelArt()=="B" .and. ;
              ( ARTIKEL->KonsigMind <= 0 .and. ARTIKEL->KonsigMax <= 0 )}

            ListNames:=NegVerfueg("B",NIL,.t.,bed)

            emailText:="Bitte weiterleiten."
            if len(ListNames) == 0
              emailText += "||Nur Excel-Liste anbei, keine Sonderartikel."
            else
              emailText += "||Excel-Liste und Sonderartikel anbei."
            endif

            // Excel Datei hinzuf�gen
            ListNames:=HB_aIns( ListNames , 1, excel:fileName , .t.)

            //email(MY_EMAIL,"K-Lager Mindest-Bestandsliste VVG vom: "+dtoc(getUser():date),emailText,ListNames)
            email(MAIN_EMAIL,"K-Lager Mindest-Bestandsliste VVG vom: "+;
              dtoc(getUser():date),emailText,ListNames)

            if mKundNr == Nil
              Message(excel:fileName+" wurde erzeugt.  @Taste@","@")
            endif

          endif
        endif // pdf email
      endif
      set filter to
    else
      Liste("Artikel",KopfText,Titel,Bauch,d_von,d_bis,FeldNr,"KLagMind",Bed,"NOP")
    endif
  endif
  Umgebung(LOAD)

return
/** eop */

  /**
  * Liefert den Bestand in Baugruppen bei Miki und im K-Lager
  * vom aktuell selektierten Artikel
  */
function getKBaugrBestand()
LOCAL result
LOCAL aktRec:=ARTIKEL->(recno())

  Umgebung(WRITE_ALL)

  ARTIKEL->(OrdSetFocus(1)) // ArtNr
  AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel
  result:=rekHonsBeiList(ARTIKEL->ArtNr,0,.f.)

  Umgebung(LOAD)

  if result== nil
    return 0
  endif

return;
  round(result[BG_BESTAND_LG_MIKI] +;
  result[BG_BESTAND_LG_HONSEL] + result[BG_BESTAND_LIEFERANT] - ARTIKEL->LageBest,2)
/** eop */

  /*
  */
PROCEDURE KEntnahmeListe
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL line:=replicate("-",104)
LOCAL mKundNr:="10167-  ", Export
Local Datvon:=Ctod("01.01.19"), datbis:=ctod("31.12.19"), inkl503:="N"
LOCAL maxRow, mArtNr, summe:=0, lastRechNr

  cls
  titel("K-Lager Entnahme-Liste")

  if ! open("Rechaus","Rechpost","Artikel","AufAus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  seite:=0
  @ 2,0 clear

  @ 4 ,10 say "Kunden-Nr  :" get MKundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",.f.) } ;
    when Message("Kundennummer eingeben.    @F12@=Hilfe")
  @ 6,10 say "Datum von:  " get datvon
  @ 8,10 say "Datum bis:  " get datbis
  @ 10,10 say "Inkl. 503:  " get inkl503 picture "!" valid inkl503 $ "JN"
  read

  if ABBRUCH
    close data
    clear
    RETURN
  endif
  @ 4,40 say KUNDEN->KurzName

  export:=Druck_Bs("Entnahmen-"+str(year(DatVon),4),.t.,.t.) // Abbruch
  if valtype(export)=="L" .and. ! export
    cls
    close data
    RETURN
  endif
  Message("Liste wird erstellt.   Bitte warten...")

  // export nach Excel?
  if valtype(export)=="C" // Excel
    export:=getUser():exportPATH() + BACKSLASH + cleanFileName(export)
    getUser():setCurrentPrintJob(ExcelJob():new())
    getUser():getCurrentPrintJob():StartDoc( export )
    getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=23
    getUser():getCurrentPrintJob():oSheet:columns( 3 ):ColumnWidth:=40
  endif


  select RechPost
  set rela to RECHPOST->RechNr into Rechaus, to RECHPOST->AufNr into AufAus

  index on RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for;
    (left(RECHAUS->KundNr,5)==left(mKundNr,5) .or. left(RECHAUS->V_KundNr,5)==left(mKundNr,5)) .and.;
    AUFAUS->InvKz <> "J" .and. ;
    (RECHAUS->ReaDat>=datvon .and. RECHAUS->ReaDat<=datbis) .and.;
    (inkl503=="J" .or. left(RECHPOST->ArtNr,3)<>"503") .and.;
    len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE .and.;
    alltrim(RECHPOST->ArtNr) <> "009700"

  go top
  Stop:=stop_key()
  mArtNr:=RECHPOST->ArtNr
  do while .not.RECHPOST->(eof()) .and. ! Stop
    seite=seite+1
    zeile:=0
    if valtype(export)=="C" // Excel
      ? "Miki.Nr. ","Honsel-Nr.","Bezeichnung","Menge"
    else
      ? "K-Lager Entnahme-Liste :",dtoc(datVon)+" - "+ dtoc(datbis),space(30),"Seite",str(seite,3)
      ? line
      ? "Miki.Nr. ","Honsel-Nr."+space(9),"Bezeichnung"+space(57),"Menge"
      ? line
    endif
    do while .not.RECHPOST->(eof()) .and. ! Stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand
      @ 24,0 say mArtNr
      do while .not.RECHPOST->(eof()) .and. ! Stop .and.;
        zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. mArtNr == RECHPOST->ArtNr
        summe += RECHPOST->Gelief
        lastRechNr:=RECHPOST->RechNr
        skip
        Stop:=stop_key()
      enddo

      ARTIKEL->(dbseek( mArtNr ))
      if valtype(export)=="C" // Excel
        ? OUT(mArtNr),ARTIKEL->HArtNr,;
          ARTIKEL->Bez1+if(empty(ARTIKEL->Bez2),"",chr(10)+ARTIKEL->Bez2),summe
      else
        ? OUT(mArtNr),ARTIKEL->HArtNr,;
          ARTIKEL->Bez1+if(empty(ARTIKEL->Bez2),space(30),ARTIKEL->Bez2),summe // ,lastRechNr
      endif
      mArtNr:=RECHPOST->ArtNr
      summe:=0
    enddo
    Zeile:=FormFeed(Zeile,Seite)

  enddo

  if valtype(export)=="C" // Excel
    // Excel-Summe
    maxRow:=getUser():getCurrentPrintJob():row
    getUser():getCurrentPrintJob():colNumberFormat( 2 , maxRow , 7 , EXCEL_NUMBER_FORMAT_INTEGER2)

    drucker("OFF")

    Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")

  else
    drucker("OFF")
  endif

  cls
  close data

RETURN
  /* EOP */

/** Pr�ft rekursive alle Artikel der AB (rekursiv) mit zu wenig relativem Lagerbestand
  * und sendet evtl. Email
  */
procedure checkMatVerfuegbar(auto)
LOCAL toleranz:=val( getProperty("Miki.material.reserve","0") )
LOCAL header:="Material - Verf�gbarkeitsliste vom: " + dtoc(getUser():date)
LOCAL body
LOCAL Zeile:=0, seite:=0, printBuffer
LOCAL stop:=.f., printJob, filenames:={}, count:=0, line, myArt, Arten:="FDE"

  default auto:=.f.

  if ! auto
    cls
    Titel("Material Verf�gbarkeit anzeigen")
  endif

  if ! open("Artikel","Einheit","AvPost","AufAus","AufPost","Auftrag","M_Mehrf","BesAus","Kunden")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  select Artikel
  set rela to ARTIKEL->ME into Einheit

  if .not. auto
    arten:=Message("Artikel Art ausw�hlen: @F@/@D@/@E@","FDE"," ")
  endif

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  for each myart in arten
    Drucker(iif(auto,"PDF","BS"),"MaterialCheck-"+myArt)
    printBuffer:=printBuffer():new()
    if auto
      ? header
      ? replicate("=", len(header))
      ?
    else
      if ABBRUCH
        cls
        close data
        return
      endif
    endif
    body:="Art.Nr.    Art Bezeichnung               Bestand: Lager    Inner.  Bestellt    Ext. AB    Bedarf"
    ? body
    ? replicate("-", len(body))
    _____fixedHeader_____
    // getUser():getCurrentPrintJob():printBuffer(printBuffer)
    // zeile += printBuffer:getNumLines()
    body += "|" + replicate("=",len(body))


    Message("Liste @"+myart+"@ wird erstellt.      Bitte warten....")

    loca for ARTIKEL->Art $ myArt .and.;
      len(alltrim(ARTIKEL->ArtNr)) > FRACHT_LAENGE .and. empty(ARTIKEL->Best_OK) .and. ARTIKEL->Lagebest > 0 .and. ARTIKEL->Disponiert > 0 .and. abs(ARTIKEL->Lagebest + ARTIKEL->BestInt + ARTIKEL->BestExt - ARTIKEL->Disponiert) < 10

    do while .not. ARTIKEL->(eof())
      line:=ZEIGE_ARTNR+out(ARTIKEL->ArtNr);
        + space(2) + ARTIKEL->Art + space(2) + ARTIKEL->Bez1 + space(1)

      line += str(ARTIKEL->LageBest,9,2) + str(ARTIKEL->BestInt,10,2) + str(ARTIKEL->BestExt,10,2) + ;
        str(ARTIKEL->Disponiert,11,2) + space(1)

      line;
        +=;
        str(ARTIKEL->LageBest +;
        ARTIKEL->BestInt + ARTIKEL->BestExt - ARTIKEL->Disponiert,9,2)+space(1)+ EINHEIT->Text

      ->? line

      body += "|" + line
      count++
      cont
      Stop:=stop_key()
    enddo

    printjob = getUser():getCurrentPrintJob()
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    Drucker("OFF")
    aadd(filenames, printjob:pdfFullFileName)
  next

  // Dienstleistungen an H. Weiland per Mail
  if count > 0 .and. auto
    email(MAIN_EMAIL, "Material Verf�gbarkeit vom " + dtoc(getUser():date), body, FileNames )
  endif
  M->specialZeige:=NIL

return
/** eop */

/* 
*  listet alle Artikel mit alternat. Material auf.
*/
PROCEDURE ArtAlternatMaterial()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.

  cls
  titel("Artikel mit alternativem Material")

  if ! open("Artikel")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  Message("Liste wird erstellt.   Bitte warten...")
  index on dtos(ARTIKEL->MatDatum)+ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    ! empty(ARTIKEL->MatArtNr)

  go top
  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Artikel mit alternativem Material          vom:',getUser():date,space(7),'Seite',;
      str(seite,3)
    ? '--------------------------------------------------------------------------'
    ? 'Datum    Art-Nr.    Bezeichnung                        Faktor    Alt. Mat.'
    ? '--------------------------------------------------------------------------'
    _____fixedHeader_____
    do while .not.eof() .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? ARTIKEL->MatDatum, ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(1),;
        ARTIKEL->MatFaktor,"x",ARTIKEL->MatArtNr
      if .not. empty(ARTIKEL->bez2)
        ? space(9+len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop=Stop_Key()
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
  cls
  close data
RETURN
/* EOP ArtOhneStck */


  /* Artikel K-Lager Ger�te je Beistellteil */
PROCEDURE KlagGeratBeistellListe()
LOCAL GetList:={} , stueck, stop:=.f., parent
LOCAL Zeile:=0, Seite:=0
LOCAL M_KundNr, parents, artRec, printBuffer:=printBuffer():new(), line_content, el, nur_honsel:="J"

  if ! open("Artikel", "Einheit", "Kunden", "AvPost","WarAus","Rechpost", "KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif
  M_KundNr:=space(len(KUNDEN->KundNr))

  /* Relation setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  AVPOST->(ordSetFocus(2))
  WARAUS->(OrdSetFocus(2)) // desc

  cls
  titel("K-Lager Ger�te je Beistellteil-Liste")

  Message("Bitte Kunden-Nummer eingeben.       @F12@=Hilfe")
  @ 7,20 say "Kund.Nr...................:" get M_kundNr PICTURE KDNR_PICT;
    valid { |oGet| check(oGet,"Kunden",.f.,.f.) }
  @ 10,20 say "Empf�nger nur Honsel (J/N):" get nur_honsel PICTURE "!" valid nur_honsel$"JN"
  read

  if ABBRUCH
    close data
    cls
    return
  endif

  @ 8,20 say KUNDEN->KurzName

  if ! druck_BS() // Abbruch
    close data
    RETURN
  endif

  Message("Liste wird erstellt.   Bitte warten...")

  select RECHPOST
  index on RECHPOST->ArtNr+RECHPOST->KundNr tag TEMP_INDEX TEMPORARY ADDITIVE UNIQUE

  select Artikel
  loca for ARTIKEL->Art=="B" .and. ARTIKEL->KonsigKdNr==M_KundNr

  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Ger�te/Artikel je Beistellteil                  vom:',getUser():date,space(22),'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--------------'
    ? 'Honsel ArtNr        Miki-ArtNr Bezeichnung                           Menge ME  Letzte '+;
      'Bewegung Empf�nger'
    ? '------------------------------------------------------------------------------------------'+;
      '--------------'
    _____fixedHeader_____
    do while .not. ARTIKEL->(eof()) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      // restl. Zeilen nach Seitenumbruch drucken?
      if printBuffer:getNumLines() > 0
        do while zeile<DRUCKER->laenge-LISTE->Unt_Rand+3 .and. printBuffer:getNumLines() > 0
          line_content:=printBuffer:popTop()
          ?
          for each el in line_content
            ?? el
          next
        enddo
        ?
      endif
      if zeile>DRUCKER->laenge-LISTE->Unt_Rand-3
        exit
      endif

      // neues Beistellteil
      ARTIKEL->(dbseek( ARTIKEL->ArtNr ))
      ? ARTIKEL->HArtNr, ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,str(1,12,0),EINHEIT->Text
      ? space(len(ARTIKEL->HArtNr)+1+len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      ? replicate("=", 61)
      artRec:=ARTIKEL->(recno())
      stueck:=StueckListe():new(ARTIKEL->Artnr, ARTIKEL->Art, 1)
      parents:=stueck:getTopParents()
      printBuffer:=printBuffer():new()
      for each parent in parents
        if ! left(parent[1],1)=="E"
          ARTIKEL->(dbseek( parent[1] ))
          WARAUS->(dbseek(ARTIKEL->ArtNr))
          ->? ARTIKEL->HArtNr, ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,str(parent[2],12,0),;
            EINHEIT->Text, space(6),dtoc(WARAUS->Datum),;
            array2readable(get_rechkunde(ARTIKEL->ArtNr, nur_honsel))
          ->? space(len(ARTIKEL->HArtNr)+1+len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
        endif
      next
      do while zeile<DRUCKER->laenge-LISTE->Unt_Rand+3 .and. printBuffer:getNumLines() > 0
        line_content:=printBuffer:popTop()
        ?
        for each el in line_content
          ?? el
        next
      enddo

      ARTIKEL->(dbgoto(artRec))
      Stop:=stop_key()
      ?
      cont
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  if printBuffer:getNumLines() > 0
    do while printBuffer:getNumLines() > 0
      line_content:=printBuffer:popTop()
      ?
      for each el in line_content
        ?? el
      next
    enddo
    ?
  endif

  Drucker("Off")
  close data

  // reset all ArtikelInfos
  getoAI( OAI_CLEAR_ALL )

return
  /** eop */

/* Liefert ein Array mit Kunden-Nummern, die den Artikel erhalten haben. */
static function get_rechkunde(mArtNr, nur_honsel)
LOCAL result:=hb_hash()
  RECHPOST->(dbseek(mArtNr))
  do while ! RECHPOST->(eof()) .and. mArtNr==RECHPOST->ArtNr
    if nur_honsel == "N" .or. left(RECHPOST->KundNr,5)$"10167/10363"
      if empty(right(RECHPOST->KundNr,2))
        result[left(RECHPOST->KundNr,5)]:=.t.
      else
        result[RECHPOST->KundNr]:=.t.
      endif
    endif
    RECHPOST->(dbskip())
  enddo
return HGetKeys(result)

  /* PROCEDURE Honsel-Beistell-Liste E/B-Artikel
  *
  * listet alle Beistellteile von Honsel wahlweise mit ARTIKEL->Art E oder B oder beide
  * f�r Weitergabe an Honsel gedacht
  */
PROCEDURE honselEhemBeistellTeile()
LOCAL kdFilter,kdName,zeile,seite:=0
LOCAL Stop:=.f.
LOCAL summe:=0, preise
LOCAL artFilter

  cls
  titel("Honsel-Beistellteile Liste KLager.Inv.Bestand")

  if ! open("Artikel","Einheit","Kunden")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  SELECT Artikel
  set rela to ARTIKEL->ME into Einheit
  kdFilter:="10167"
  KUNDEN->(dbseek(kdFilter))
  kdName:=KUNDEN->KurzName

  preise:=Message("EK-Preis und Summe anzeigen? (@J@/@N@)","JN")
  if ABBRUCH
    close data
    cls
    RETURN
  endif

  artFilter:=Message("Artikel-Art: nur @E@-Artikel, @B@eistellteile oder @A@lle? (@E@/@B@/@A@)","EBA")
  if ABBRUCH
    close data
    cls
    RETURN
  endif
  if artFilter == "A"
    artFilter:="B/E"
  endif


  if ! Druck_Bs() // Abbruch
    close data
    cls
    RETURN
  endif

  Message("Liste wird erstellt.    Bitte warten...")


  // druck oder PDF
  loca for getArtikelArt() $ artFilter .and.;
    left(ARTIKEL->KonsigKdNr,5)$kdFilter .and. left(ARTIKEL->ArtNr,1)<>"E"
  do while .not. ARTIKEL->(eof()) .and. ! stop
    seite++
    zeile:=0
    ? 'Beistellteile: '+kdName+'       vom:',getUser():date,'    Seite',str(seite,3)
    ? '--------------------------------------------------------------------------'
    if preise == "J"
      ?? '-----------------------'
    endif
    ? 'Art.Nr.    ME  Bezeichnung                    Honsel-Nr.           Bestand'
    if preise == "J"
      ?? "    EK-Preis  Ges-Preis"
    endif
    ? '--------------------------------------------------------------------------'
    if preise == "J"
      ?? '-----------------------'
    endif
    do while .not. ARTIKEL->(eof()) .and. zeile<DRUCKER->Laenge-LISTE->UNT_RAND .and. ! stop
      ? out(ARTIKEL->ArtNr),EINHEIT->Text,ARTIKEL->Bez1,ARTIKEL->HartNr,str(ARTIKEL->KonsigInv,8,0)
      if preise == "J"
        ?? ARTIKEL->EKPR, str(ARTIKEL->EKPR*ARTIKEL->KonsigInv,10,2), EURO_SIGN
        summe += round(ARTIKEL->EKPR*ARTIKEL->KonsigInv,2)
      endif
      if ! empty(ARTIKEL->Bez2)
        ? space(14),ARTIKEL->Bez2
      endif
      cont
      Stop:=stop_key()
    enddo
    if preise == "J"
      ? replicate("=", 100)
      ? space(76),"Summe:", transstr(summe,14,2),EURO_SIGN
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  drucker("OFF")
  close data
  cls
RETURN
/* EOP */

  /* 
  * listet alle Artikel in denen ein Beistellteil (von Honsel) vorkommt mit ARTIKEL->Art E/B
  */
PROCEDURE ArtMitBeistell()
LOCAL zeile:=0,seite:=0
LOCAL Stop:=.f.
LOCAL summeEk:=0, summeKaPr:=0, ka, ek, aktRec, mArtNr

  cls
  titel("Artikel mit Honsel-Beistellteilen")

  if ! open( "Artikel" , "AvPost","Einheit","BeisTemp","Manbeist","WarAus")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  if ! druck_BS()
    cls
    close data
    return
  endif

  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5), { |a,b| zeigeBeistellListe(a,b)} , "@F5@=Beistellteile" } )

  /* Relationen setzen */
  WARAUS->(OrdSetFocus(2)) // desc
  select Artikel
  set relation to ARTIKEL->ME into Einheit
  select Beistemp
  set relation to BEISTEMP->ArtNr into Artikel

  select Artikel
  set filter to ! left(ARTIKEL->ArtNr,1)=="E" .and. ! getArtikelArt() $ "X"
  go top
  Message("Bitte warten")
  do while ! ARTIKEL->(eof()) .and. ! stop
    seite++
    ? "Artikel mit Honsel Beistellteilen     vom:",getUser():date,space(0),"Seite:",str(seite,3)
    ? "Art.Nr     Bezeichnung         Beist.Teile Summe: EK   Kalk.Pr. Bewegung"
    ? replicate("=",72)

    do while Zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! ARTIKEL->(eof()) .and. ! stop
      // extrahiere Beistellteile rekursiv
      @ 24,0 say "Pr�fe "+out(ARTIKEL->ArtNr)
      aktRec:=ARTIKEL->(recno())
      mArtNr:=ARTIKEL->ArtNr
      select Beistemp
      zap
      BeistellRek(mArtNr,1,NIL,"10167-  ")

      /** ausdrucken ? */
      select BeisTemp
      go top
      if ! BEISTEMP->(eof())
        summeEk:=summeKaPr:=0
        do while ! BEISTEMP->(eof())
          ka=IIF(ARTIKEL->Schluessel="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr)
          ek=IIF(ARTIKEL->Schluessel="H",ARTIKEL->EKPr/100,ARTIKEL->EKPr)
          summeEk += ek * BEISTEMP->Menge
          summeKaPr += ka * BEISTEMP->Menge
          BEISTEMP->(dbskip())
        enddo
        ARTIKEL->(dbGoto( aktRec ))
        if summeEk > 0 .and. ARTIKEL->Preis1 > 0 // .and. ARTIKEL->verkauft==0
          WARAUS->(dbseek(ARTIKEL->ArtNr))
          //if WARAUS->(eof())
          ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,str(summeEK,10,2), str(summeKaPr,10,2),;
            dtoc(WARAUS->Datum)
          ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
          //endif
        endif
      endif
      ARTIKEL->(dbGoto( aktRec ))
      select Artikel
      skip
      stop:=stop_key() // ESC gedr�ckt ?
    enddo
    Zeile:=FormFeed(Zeile,Seite++)
  enddo
  Drucker("Off")
  close data
return
/** eop */

/** Liste mit allen Rohmaterial, dass ins Minus geht.

  Rohmaterial: sind alle 295er Artikel
  Ins Minus bisher nur basierend auf �bergeordneten innerbetr. Auftr�gen.
*/
procedure RohMatBedarf(auto)
LOCAL oAi, bew, seite:=0, zeile:=0
LOCAL Stop:=.f., empf
LOCAL printBuffer:=printBuffer():new()
LOCAL bewegungen:={}, nTotal, fehler, alleInner:="", aktRec, bedarf, lagebest

  default auto:=.f.

  cls
  titel("Rohmaterial-Bedarfs-Liste")

  if ! open("Artikel","Inner","AVPOST","Einheit","AufPost","BesPost","BesAus")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  if auto
    Drucker("PDF","RohMatBedarf",,.f.,PDF_NO_CONFIRM)
  else
    if ! druck_BS() // Abbruch
      Error(TRY_AGAIN)
      cls
      close data
      return
    endif
  endif

  /* Relationen setzten */
  select BesPost
  BESPOST->(OrdSetFocus(5)) // ArtNr + KW
  set relation to BESPOST->BestNr into BesAus

  SELECT Artikel
  set relation to ARTIKEL->ME into Einheit

  Message("Liste wird erstellt.   Bitte warten...")

  ARTIKEL->(dbseek("295")) // Rohmaterial
  seite=seite+1
  zeile:=0
  ->? 'Rohmaterial-Bedarf Artikel:',space(17),'vom:',getUser():date,space(10),'Seite',str(seite,3)
  ->? '------------------------------------------------------------------------------------------'+;
    '-------------------'
  ->? 'Art-Nr.      Bezeichnung                 Lagerbestand Gesamt ME     Bedarf in KW  Bestellt '+;
    'ME     KW  Interne'
  ->? '                                              aktuell Bedarf                        extern '+;
    '          Auftr�ge'
  ->? '------------------------------------------------------------------------------------------'+;
    '-------------------'

  do while .not.eof() .and. left(ARTIKEL->ArtNr,3)="295" .and. ! stop
    @ 24,0 say out(ARTIKEL->ArtNr)
    lageBest:=max(ARTIKEL->Lagebest, 0)
    // if trim(ARTIKEL->ArtNr)=="2951810"
    // altd()
    // endif
    if ARTIKEL->Disponiert <= lageBest
      aktRec:=ARTIKEL->(recno())
      oAI:=hasBewegungUnterNull(@bewegungen, NIL) // ursp. Material, kein alternat. Material
      do while oAI <> NIL .and. ! empty(ARTIKEL->MatArtNr)
        ARTIKEL->(dbseek(ARTIKEL->MatArtNr))
        oAI:=hasBewegungUnterNull(@bewegungen, oAI) // alternat. Material
      enddo
      ARTIKEL->(dbGoto( aktRec ))
    endif
    skip
  enddo

  // sortiere nach KW & drucke bedarf
  aSort(bewegungen,,, { |beweg1,beweg2| beweg1:compare(beweg2) > 0 } )
  for each bew in bewegungen
    ARTIKEL->(dbseek(bew:artnr))
    // if trim(ARTIKEL->ArtNr)=="2952910"
    // altd()
    // endif

    bedarf:=lageBest + bew:cargo // cargo is negativ
    if ! empty(bew:cargo4) // -> parentAI, also alternat. Material
      ->? "Alternatives Material:"
      // hole Lagerbestand vom urspr. nicht alternatv Material
      bedarf:=lageBest+bew:cargo4:bestand + bew:cargo
    endif

    // lt. Herr Weiland soll der Gesamt-Bedarf in der KW wo der Artikel ins Minus geht gedruckt werden
    ->? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,lageBest,str(bew:cargo,7,2),EINHEIT->Text,;
      str(bedarf,8,2),bew:KW

    // 1. externe Bestellungen drucken, if any
    if ARTIKEL->BestExt > 0
      fehler:=.f.
      BESPOST->(dbseek(ARTIKEL->ArtNr))
      do while ! BESPOST->(eof()) .and. BESAUS->Erledigt == "J" .and.;
        BESPOST->ArtNr == ARTIKEL->ArtNr
        BESPOST->(dbskip())
      enddo
      if BESPOST->ArtNr == ARTIKEL->ArtNr
        // umrechnen?
        if BESPOST->ME <> ARTIKEL->ME
          if ARTIKEL->ME2 == BESPOST->Me
            EINHEIT->(dbseek(ARTIKEL->ME))
            nTotal:=BESPOST->Menge / ARTIKEL->ME_Faktor
          else
            EINHEIT->(dbseek(BESPOST->ME))
            nTotal:=BESPOST->Menge
            fehler:=.t.
          endif
        else
          EINHEIT->(dbseek(ARTIKEL->ME))
          nTotal:=BESPOST->Menge
        endif
        ->?? str(nTotal,9,2)

        if fehler
          ->?? COLOR_RED,EINHEIT->Text,COLOR_DEFAULT
        else
          ->?? EINHEIT->Text
        endif
        ->?? BESPOST->KW
      endif

      // weitere Bestellungen in 2. Zeile
      bew:cargo3:=""
      BESPOST->(dbskip())
      do while ! BESPOST->(eof()) .and. BESPOST->ArtNr == ARTIKEL->ArtNr
        if BESAUS->Erledigt <> "J"
          // umrechnen?
          if BESPOST->ME <> ARTIKEL->ME
            if ARTIKEL->ME2 == BESPOST->Me
              EINHEIT->(dbseek(ARTIKEL->ME))
              nTotal:=BESPOST->Menge / ARTIKEL->ME_Faktor
            else
              EINHEIT->(dbseek(BESPOST->ME))
              nTotal:=BESPOST->Menge
              fehler:=.t.
            endif
          else
            EINHEIT->(dbseek(ARTIKEL->ME))
            nTotal:=BESPOST->Menge
          endif
          bew:cargo3 += str(nTotal,9,2) + " " +EINHEIT->Text+ " " + BESPOST->KW
        endif
        BESPOST->(dbskip())
      enddo
    else
      ->?? space(19)
    endif

    /* innerbetr. Auftr�ge */
    ->?? space(2), bew:cargo2

    if ! myempty(bew:cargo3)
      ->? space(80),bew:cargo3
    endif

  next


  getUser():getCurrentPrintJob():printBuffer(printBuffer)
  Zeile:=FormFeed(Zeile,Seite)

  getUser():getCurrentPrintJob():endDoc()
  if auto .and. len(bewegungen) > 0
    empf = trim(getProperty("Miki.mindbest.emails",MAIN_EMAIL))
    email(empf,"Rohmaterial Bedarf " +;
      dtoc(getUser():date),printBuffer:getPlainText("|"),;
      getUser():getCurrentPrintJob():pdfFullFileName)
  endif
  getUser():setCurrentPrintJob(NIL)

  close data
return
/** eop */


  /** liefert den Gesamt Preis des akt. Rechn.Posten zzgl Aufschlag abzgl Rabatt */
static function getPostenPreis
LOCAL preis:=RECHPOST->Preis * RECHPOST->Gelief / IIF(RECHPOST->PE$"Hh",100,1)
LOCAL proz:=RECHAUS->Zuschlag - RECHAUS->So_Rabatt - RECHPOST->Rabatt
LOCAL result:=preis

  if proz <> 0
    result:=result + result*proz/100
  endif
return result

  /** Pr�ft ob der Artikel unter Null geht vom selektieten Artikel,
  f�gt diese Bewegung zum bewegungen array (parameter) hinzu,
  und liefert dann den oAI zur�ck ansonsten NIL
  */
static function hasBewegungUnterNull(bewegungen, parentAI)
LOCAL oAI:=ArtikelInfo():new(BEW_INNER_OBER+BEW_BESTELLUNG)
LOCAL alleInner:="", nTotal:=0, bew, bewUnterNull
LOCAL result:=NIL, cloneBewegungen:={}

  oAI:checkValid()

  // f�ge Bewegungen von parentOI hinzu (bei alternat. Material)
  if parentAI <> NIL
    AEval( parentAI:bewegungen, { | oObj | AAdd( cloneBewegungen, oObj:Clone() ) } )
    oAI:addBewegungen(cloneBewegungen)
  endif

  // enable inner bewegungen
  for each bew in oAI:bewegungen
    bew:ignore:=.f.
    nTotal += bew:gesmenge
    alleInner += bew:Nummer
  next

  bewUnterNull:=oai:lagerBestandUnterNull(,,.f.) // ohne Mind.Bestand
  if bewUnterNull<>NIL
    // wichtig �berschreibe ein paar Werte f�r Druck unten
    bewUnterNull:artnr:=ARTIKEL->ArtNr
    bewUnterNull:cargo:=nTotal
    bewUnterNull:cargo2:=alleInner
    bewUnterNull:cargo4:=parentAI
    aadd(bewegungen, bewUnterNull)
    result:=oAI
  endif

return result
/** eof */



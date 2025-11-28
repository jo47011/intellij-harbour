
#include "Miki.ch"
#include "Zeige.ch"
#include "hbclass.ch"

#define ME_MIKI 1
#define ME_LIEF 2

#define NEG_VERF_MINDEST_BESTAND_ART "FE"


/* PROCEDURE Preis-Liste
*
*  mit auswahl: Kalk-Preis , EK , VK
*               nach St�ckliste oder Mat.Kz
*
*/
PROCEDURE Preis_List
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f., Gruppe , gesamt,Bed
LOCAL kom,Preisein,pr, akt_pr,akt_ti
LOCAL Auswahl,matKz

  cls
  titel("Preis - Liste drucken")

  if ! open("Artikel","GruppSum","Einheit")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /* Relationen setzten */
  select GruppSum
  zap
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit

  Message("Bitte Preis ausw�hlen.               @ESC@=Ende")
  @ 7,23 to 11,50
  @ 8,25 prompt "1. Kalkulations-Preis"
  @ 9,25 prompt "2. Einkaufs    -Preis"
  @ 10,25 prompt "3. Verkaufs    -Preis"
  Menu to Auswahl

  if ABBRUCH
    cls
    close data
    RETURN
  endif

  /* w�hle Preis */
  do case
  case Auswahl==1
    akt_Pr:="ARTIKEL->KaPr"
    akt_ti:="Kalk.Preis"
  case Auswahl==2
    akt_Pr:="ARTIKEL->EkPr"
    akt_ti:="  EK-Preis"
  case Auswahl==3
    akt_Pr:="ARTIKEL->Preis1"
    akt_ti:="  VK-Preis"
  endcase

  Message("Materialkennziffer St�ckliste eingeben.    @F12@=Hilfe")
  MatKz:=space(len(ARTIKEL->MatKz))
  @ 13,20 say "Material-Kennziffer:" get matkz PICTURE MAT_PICT;
    valid { |oGet| check(oGet,"Mat_KZ",.f.,.f.) }
  read

  if ABBRUCH .or. ! druck_BS() // Abbruch
    close data
    cls
    RETURN
  endif
  Message("Liste wird erstellt.  Bitte warten....")

  /* nach Mat.Kz */
  select Artikel
  go top
  Bed:={ || ARTIKEL->MatKZ==matkz }
  Gruppe=substr(ARTIKEL->Artnr,1,3)
  gesamt=0.00
  Stop:=stop_key()
  do while .not.eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'P R E I S - L I S T E  ('+akt_ti+')           vom:',getUser():date,space(8),'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------------'
    ? 'Art-Nr.   Bezeichnung                       Menge ME   '+akt_ti+'         Wert'
    ? '------------------------------------------------------------------------------'
    do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and.;
        Gruppe=Substr(ARTIKEL->ArtNr,1,3) .and. ! stop
        do while (! eval(Bed) .or. len(alltrim(ARTIKEL->artnr)) <= FRACHT_LAENGE );
          .and. .not. eof() .and. ! stop
          skip
          Stop:=stop_key()
        enddo
        if eof()
          loop
        endif
        kom=trim(ARTIKEL->bez1)
        if .not. empty(ARTIKEL->bez2)
          kom=kom+', '+trim(ARTIKEL->bez2)
        endif
        kom=substr(kom+space(29),1,29)
        IF ARTIKEL->Schluessel="H"
          PreisEin="%"
          Pr=&(akt_pr)/100
        else
          PreisEin=" "
          Pr=&(akt_pr)
        endif
        if ARTIKEL->ME $ "01 "
          ? out(ARTIKEL->artnr),kom,str(ARTIKEL->LageBest,9,0),EINHEIT->Text,;
            str(&(akt_pr),11,2)+PreisEin,str(ARTIKEL->LageBest*Pr,11,2)
        else
          ? out(ARTIKEL->artnr),kom,str(ARTIKEL->LageBest,9,0),EINHEIT->Text,;
            str(&(akt_pr),11,2)+PreisEin,str(ARTIKEL->LageBest*Pr,11,2)
        endif
        gesamt=gesamt+(ARTIKEL->LageBest*Pr)
        skip
        Stop:=stop_key()
      enddo
      // ** schreiben in temp. Datei: GruppSum
      if Gruppe<>Substr(ARTIKEL->ArtNr,1,3)
        SELECT GruppSum
        ADD_REC(0)
        REPLACE Nummer with Gruppe
        REPLACE Summe with gesamt
        SELECT Artikel
        ? '------------------------------------------------------------------------------'
        ? space(66),str(gesamt,11,2)
        ?
        gesamt=0.00
      else
        ? '------------------------------------------------------------------------------'
        ? space(51),"Zwischensumme:",str(gesamt,11,2)
        ?
      endif
      // **
      Gruppe=substr(ARTIKEL->Artnr,1,3)
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  // *** Gruppenzusammenstellung *********************
  SELECT GruppSum
  go top
  gesamt=0.00
  do while .not.eof() .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'Gruppenzusammenstellung   (kalk.Preis)        vom:',getUser():date,space(8),'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------------'
    ? 'Gruppe               Summe'
    ? '--------------------------'
    do while .not.eof().and.zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? GRUPPSUM->Nummer,space(9), GRUPPSUM->summe
      gesamt=gesamt+ GRUPPSUM->summe
      skip
      Stop:=stop_key()
    enddo
    ? '--------------------------'
    ? space(14),str(gesamt,11,2)
    ?
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
  zap
  cls
  close data
RETURN
/* EOP Preis_List */

/* nach St�ckliste */
PROCEDURE Preis_Stk_Liste
LOCAL GetList:={}
LOCAL M_AvNr,ant,ges_Menge:=1,Export
LOCAL excel, objErr
LOCAL aFields,oCol

  cls
  titel("Ersatzteil -St�ckliste drucken")

  if ! open("Artikel","Einheit","AvAus","AvPost","Text","Instrukt")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={{ chr(K_F5), { |text, ZeigeData| rekStklist(text, ZeigeData)} , " @F5@=aufl�s"+;
    "en " }}

  /* Relationen setzten */
  select AvAus
  set relation to AVAUS->Avnr into Artikel
  select AvPost
  set relation to AVPOST->ArtNr into Artikel, to AVPOST->ArtNr into Text
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit

  do while ! ABBRUCH
    M_AvNr:=space(len(AVAUS->AvNr))
    Message("St�ckliste und Menge eingeben.     @F12@=Hilfe")
    @ 8,20 say "St�cklisten-Nummer:" get M_AvNr Picture "@!";
      valid { |oGet| check(oGet,"AvAus",.f.,.f.) }
    @ 10,20 say "Menge.............:" get ges_Menge PICTURE "99999"
    read

    if ABBRUCH // Abbruch
      M->specialZeige:=NIL
      close data
      cls
      RETURN
    endif

    ant:=Message("Ausgabe auf Drucker, Bildschrirm , Honsel oder Excel (@D@/@B@/@H@/@E@) ?","BDHE";
      ,"B")

    if ABBRUCH // Abbruch
      M->specialZeige:=NIL
      close data
      cls
      RETURN
    endif

    if ant$"HE"
      /** Transfer an Honsel */
      if ! open("Ersatz")
        M->specialZeige:=NIL
        cls
        close data
        RETURN
      endif
      zap
    endif

    if ant=="D"
      Drucker("ON")
    else
      Drucker("BS")
    endif

    StkListe(M_AvNr,ges_Menge,ant)

    /** kopiere an Honsel */
    if ant=="H"
      select ersatz
      if mkMyDir(getUser():exportPATH())
        export =getUser():exportPATH() + BACKSLASH+ cleanFileName(M_AvNr)
        BEGIN SEQUENCE // krit. Bereich
          excel:=ExcelExport():new()

          aFields:={ "POS" }
          excel:addColumnsByName( aFields )

          oCol:=ExcelColumn():new()
          oCol:fieldName:="ME"
          oCol:title:="Menge"
          oCol:numberFormat:=EXCEL_NUMBER_FORMAT_INTEGER
          excel:addColumn(oCol)

          aFields:={;
            {"ARTNR","Art.Nr."},;
            {"BEZ1","Bezeichnung"},;
            {"BEZ2","Bezeichnung 2"},;
            {"PREIS","Preis"},;
            {"H","PE"},;
            {"GEW","Gewicht"},;
            {"MASS","Ma�e"},;
            {"HONSEL_NR","Honsel-Nr."},;
            {"LAGERORT","Lagerort" } }
          excel:addColumnsByName( aFields )

          excel:export(.f.,.f.,export)
          Message(Export+" wurde erzeugt.  @Taste@","@")
        RECOVER USING objErr
          // nop, Fehler bereits protokolliert
        END SEQUENCE

        select zeige
        go top
      endif

    elseif ant=="E"
      /** Kopie fuer Weiland */
      select ersatz
      if mkMyDir(getUser():exportPATH())
        export =getUser():exportPATH() + BACKSLASH+ cleanFileName(M_AvNr)
        BEGIN SEQUENCE // krit. Bereich
          excel:=ExcelExport():new()
          excel:addCurrentDBColumns()
          excel:export(.f.,.f.,export)
          Message(Export+" wurde erzeugt.  @Taste@","@")
        RECOVER USING objErr
          // nop, Fehler bereits protokolliert
        END SEQUENCE
        select zeige
        go top
      endif
    endif

    set Margin to 0
    Drucker("Off")

  enddo
  M->specialZeige:=NIL
  cls
  close data
RETURN
/* EOP */


/* Preis_stkListe je Artikel
*/
PROCEDURE StkListe(M_AvNr,ges_Menge,ant)
LOCAL seite:=0, zeile:=0,x,MMenge,TempVar,wert,kom
LOCAL Stop:=.f.,M_bez1,M_bez2,M_me,ges:=0
LOCAL Zeichen:="",i:=0,meng,proz,tempStr:=""
LOCAL line,title

  ges:=Seite:=0

  Message("Liste wird erstellt.  Bitte warten....")
  set Margin to 8

  /* hole Stk-Listen-Text aus Artikel.dbf */
  ARTIKEL->(dbseek(AVAUS->AvNr))
  M_bez1:=ARTIKEL->Bez1
  M_bez2:=ARTIKEL->Bez2
  EINHEIT->(dbseek(ARTIKEL->ME))
  M_Me:=EINHEIT->Text

  select AvPost
  dbseek(AVAUS->AvNr)
  do while .not. AVPOST->(eof()) .and. AVAUS->AvNr=AVPOST->AvNr
    Seite=Seite+1

    zeile:=0 ; x:=1
    ? "Ersatzteilliste:",space(10),FETT_AN,M_Bez1,FETT_AUS,ges_Menge,M_Me,space(23),getUser():date
    ? out(M_AvNr),space(16),M_Bez2
    ?
    for each tempVar in getStkListBemMaterial()
      ? tempVar
    next
    title='Pos.     Bg. St ME  Bezeichnung                     Art.Nr.      Stk.Pr.    Gew.(kg)   '+;
      ' Ma�e       Hons.Art.Nr.'
    line=replicate("-",len(title))
    ? line
    ? title
    ? line
    x=1
    do while .not. AVPOST->(eof()) .and. AVAUS->AvNr=AVPOST->AvNr
      if AVPOST->Art="M".and. .not. empty(AVPOST->ArtNr) // Material
        If AVPOST->Text="A" // Artikel
          MMenge=IIF(ARTIKEL->Schluessel="H",AVPOST->Menge/100,AVPOST->Menge)
          Kom =IIF(ARTIKEL->Schluessel="H","%"," ")
          wert=MMenge*ges_Menge*ARTIKEL->Preis1
          meng:=str(ges_Menge*AVPOST->Menge,3,0)
          ges=ges+wert
          proz:=if(ARTIKEL->Schluessel=="H","%"," ")
          tempStr:=ARTIKEL->Masse
          while "-"$tempStr
            tempStr:=substr(tempstr,1,at("-",tempStr)-1)+"x"+substr(tempstr,at("-",tempStr)+;
              1,len(tempStr))
          enddo
          /* letztes x raus, falls nur 2 Dimensional */
          if right(trim(tempStr),1)=="x"
            tempStr:=substr(tempstr,1,rat("x",tempStr)-1)+" "+substr(tempstr,rat("x",tempStr)+;
              1,len(tempStr))
          endif

          ? AVPOST->HonselPos,space(4)
          if ARTIKEL->Art=="M" // war ARTIKEL->Baugruppe == "J"
            ?? FETT_AN,"*",FETT_AUS
          else
            ?? space(1)
          endif
          ?? space(0),ZEIGE_MENGE+meng,EINHEIT->Text,ARTIKEL->Bez1,space(0),ZEIGE_ARTNR+Out(AVPOST->ArtNr),;
            str(ARTIKEL->Preis1,6,2),proz,space(0),ARTIKEL->Gewicht,space(0),tempStr,space(0),ARTIKEL->HArtNr
          if .not. empty(ARTIKEL->Bez2)
            ? space(len(AVPOST->HonselPos)),space(4),space(2),space(len(EINHEIT->Text)),;
              ARTIKEL->Bez2
          endif
        else // Text
          zeichen:=left(TEXT->Text,1)
          // Strich ?
          if (zeichen $ "-=*") .and.;
            ( alltrim(TEXT->Text)==Replicate(Zeichen,len(alltrim(TEXT->Text))) )
            ? Replicate(Zeichen,len(title))
          else
            ? TEXT->Text
          endif
        endif
      endif

      /** kopiere an Honsel */
      if ant$"HE"
        select Ersatz
        add_rec(0)
        replace ERSATZ->Pos with AVPOST->HonselPos
        // if ! empty(AVPOST->HonselPos)
        replace ERSATZ->ME with ges_Menge*AVPOST->Menge
        replace ERSATZ->Bez1 with ARTIKEL->Bez1
        replace ERSATZ->Bez2 with ARTIKEL->Bez2
        replace ERSATZ->Artnr with out(AVPOST->ArtNr)
        replace ERSATZ->KZ with ARTIKEL->WKZ
        replace ERSATZ->Preis with ARTIKEL->Preis1
        replace ERSATZ->PE with IIF(ARTIKEL->Schluessel="H",100,1)
        replace ERSATZ->H with IIF(ARTIKEL->Schluessel="H","H","E")
        replace ERSATZ->Gew with ARTIKEL->Gewicht
        replace ERSATZ->Mass with tempStr
        replace ERSATZ->Honsel_Nr with ARTIKEL->HartNr
        replace ERSATZ->LagerOrt with getArtikelLagerOrt(11)
        // endif
        select AvPost
      endif

      skip
    enddo
    ? '------------------------------------------------------------------------------------------'+;
      '--------------'
    ? space(24),"* = vormont. Baugruppe/ St. = Menge pro Ger�t / Ma�e in mm"
    // Instruktionen drucken
    select Instrukt
    dbseek(AVAUS->AvNr)
    do while ! eof() .and. AVAUS->AvNr==INSTRUKT->AvNr
      aEval(HB_ATokens(INSTRUKT->InsText , MY_CR+MY_LF) , { |x| zeile += colorprint(x , .t.) })
      skip
    enddo
  enddo

RETURN
/* EOP */

/* VK rekuriv pro St�ckliste */
PROCEDURE rekPreisStkListe()
LOCAL GetList:={}
LOCAL M_AvNr,ges_Menge:=1,Export
LOCAL excel, objErr, updateStructure
LOCAL linie:=replicate('-',115), parent, children, child, mArtNr, zeile:=0
LOCAL Temp_Datei:=TEMP + "\matbed"+getUser():getLongID()+".dbf"

  cls
  titel("VK - alle Artikel je - St�ckliste drucken")

  if ! open("Artikel","Einheit","AvAus","AvPost")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /** Spezial Funktion Zeige freischalten */
  //M->specialZeige:={{ chr(K_F5), { |text| rekStklist(text)} , " @F5@=aufl�sen " }}

  /* Relationen setzten */
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit

  do while ! ABBRUCH
    M_AvNr:=space(len(AVAUS->AvNr))
    Message("St�ckliste und Menge eingeben.     @F12@=Hilfe")
    @ 8,20 say "St�cklisten-Nummer:" get M_AvNr Picture "@!";
      valid { |oGet| check(oGet,"AvAus",.f.,.f.) }
    @ 10,20 say "Menge.............:" get ges_Menge PICTURE "99999"
    read

    if ABBRUCH // Abbruch
      exit
    endif

    /* Ausgabe auf Drucker, BS, PDF oder Excel */
    export:=Druck_Bs("MatBedarf-"+trim(m_AvNr),.t.,.t.)
    if (valtype(export)=="L" .and. ! export) .or. ABBRUCH
      exit
    endif

    // export nach DBF?
    if valtype(export)=="C"
      updateStructure:={;
        {"ArtNr" ,"C", 8,0},;
        {"Art" ,"C", 1,0},;
        {"Bez1" ,"C", 30,0},;
        {"Bez2" ,"C", 30,0},;
        {"Menge" ,"N", 9,2},;
        {"Preis" ,"N", 9,2},;
        {"PE" ,"N", 3,0},;
        {"Bestand" ,"N", 9,2},;
        {"Disponiert" ,"N", 9,2},;
        {"Verfuegbar" ,"N", 9,2},;
        {"LagerOrt" ,"C", 13,0}}

      dbCreate(Temp_Datei ,updateStructure)
      sele 0
      // TODO: catch error
      use (Temp_Datei) excl alias expDatei

      drucker("NOP")
      set cons off
    else
      ? "St�ckliste f�r Artikel:",out(M_AvNr),FETT_AN,ARTIKEL->Bez1,FETT_AUS,space(3),str(ges_Menge,8,2),;
        EINHEIT->Text,space(1),getUser():date
      ? linie
      ? 'Art.Nr.      Bezeichnung                              VK     Menge ME    Lg.Best   '+;
        'reserv verf�gbar  Lg.Ort     Art'
      ? linie
      _____fixedHeader_____
    endif

    ARTIKEL->(dbseek(M_AvNr))

    parent:=StueckListe():new(M_AvNr, ARTIKEL->Art, ges_Menge)
    children:=parent:getChildren("M", .t., .t.)


    for each mArtNr in children:Keys
      ARTIKEL->(dbseek(martnr))
      child:=children[mArtNr]
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Preis1, str(child:menge,9,2),;
        EINHEIT->Text, ARTIKEL->Lagebest,str(ARTIKEL->disponiert,8,2),;
        str(ARTIKEL->LageBest-ARTIKEL->disponiert,9,2), getArtikelLagerOrt(13),getArtikelArt()

      // kopiere f�r Excel Export
      if valtype(export)=="C"
        select ExpDatei
        add_rec(0)
        replace EXPDATEI->Artnr with out(child:ArtNr)
        replace EXPDATEI->Bez1 with ARTIKEL->Bez1
        replace EXPDATEI->Bez2 with ARTIKEL->Bez2
        replace EXPDATEI->Preis with ARTIKEL->Preis1
        replace EXPDATEI->PE with IIF(ARTIKEL->Schluessel="H",100,1)
        replace EXPDATEI->Menge with child:Menge
        replace EXPDATEI->LagerOrt with getArtikelLagerOrt(11)
        replace EXPDATEI->Bestand with ARTIKEL->LageBest
        replace EXPDATEI->Disponiert with ARTIKEL->Disponiert
        replace EXPDATEI->Verfuegbar with ARTIKEL->LageBest-ARTIKEL->Disponiert
        // endif
      endif
    next


    /** Excel */
    if valtype(export)=="C"
      select expDatei
      if mkMyDir(getUser():exportPATH())
        BEGIN SEQUENCE // krit. Bereich
          export:=getUser():exportPATH()+BACKSLASH+export
          excel:=ExcelExport():new()
          excel:addCurrentDBColumns()
          excel:export(.f.,.f.,export)
          Message(Export+" wurde erzeugt.  @Taste@","@")
        RECOVER USING objErr
          // nop, Fehler bereits protokolliert
        END SEQUENCE
      endif
    endif

    set Margin to 0
    Drucker("Off")

  enddo
  M->specialZeige:=NIL
  cls
  close data
  ferase(Temp_Datei)

RETURN
/* EOP Preis_Stk_Liste */


/* Ermoeglicht das rekursive anzeigen von Stuecklisten */
PROCEDURE rekStkList(text, ZeigeData)
LOCAL M_AvNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]
LOCAL M_Menge:=ZeigeData[ ZEIGE->(fieldPos("Menge" )) ]
LOCAL recNr:=ZEIGE->(recno())
LOCAL AVrecNr:=AVAUS->(recno())
  _thread static count

  ignore text

  if valtype(count)<>"N" .or. count>=99
    count=0
  else
    count++
  endif

  // kom:=right("00"+alltrim(str(count,2)),2)
  // kopieZeige:=TEMP+"\L"+getUser():getLongID()+kom

  AVAUS->(dbseek(M_AvNr))

  if AVAUS->(eof()) .or. ! getArtikelArt() $ STKLIST_ARTIKEL
    beep()
  else
    // Umgebung(WRITE)
    // select Zeige
    // copy to (kopieZeige)
    // zap

    Drucker("BS")
    StkListe(M_AvNr,M_Menge,"@")
    Drucker("Off",,,,,,.f.) // ohne Popup!!!

    // Umgebung(LOAD)
    // select Zeige
    // zap
    // appe from (kopieZeige)
    // go (recNr)
  endif
  AVAUS->(dbgoto(AvrecNr))

RETURN
/* EOP */



/*
* Inventur - Liste drucken
*/

PROCEDURE Inv_Liste
LOCAL GetList:={}
LOCAL Auswahl:=0,Seite:=0,Zeile:=0
LOCAL Bauch:="",Titel:="",KopfText:=""
LOCAL NeuWert:=1.00 // 1.00 Euro !!!
LOCAL gruppe,alt,gesamt:="",EinzPr
LOCAL grupsum:=0.00 , tex1
LOCAL x,bges,gges , bis, KLager,klag:=" ",invBest:="A",bestand
LOCAL Stop:=.f.,kom,kopfLaenge:=0
LOCAL neue_Seite:=.t.,export,updateStructure
LOCAL datum:=getUser():date,vonArt
LOCAL excel, objErr

MEMVAR YYY0,YYY1,YYY2,YYY3,YYY4,YYY5,YYY6,YYY7,YYY8,YYY9
PRIVATE YYY0:=0.00,YYY1:=0.00,YYY2:=0.00,YYY3:=0.00,YYY4:=0.00,YYY5:=0.00,YYY6:=0.00,YYY7:=0.00,;
  YYY8:=0.00,YYY9:=0.00 // gesamt Wert


  cls
  Titel(" Inventur - Liste drucken ")

  if ! open( "Artikel" , "Einheit","System","Kunden","Waraus","RechAus","Rechpost" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  if empty( bis:=von_bis("Artikel") )
    close data
    cls
    RETURN
  endif

  @ 11,18 to 15,56
  @ 12,20 say "Datum....................:" get datum
  @ 13,20 say "Miki oder K-Lager Bestand:" get Klag picture "!" valid klag $ "MK"
  @ 14,20 say "Inventur Bestand.........:" get InvBest picture "!" valid InvBest $ "AH";
    when KLag=="K" .and. Message("@A@=aktueller Wert aus Feld Inv.Bestand  @H@=Bestand aus "+;
    "Bew.historie zum Datum")
  read

  if ABBRUCH
    close data
    cls
    RETURN
  endif

  KLager:=(KLag=="K")

  if KLager
    @ 16,18 to 20,56
    @ 17,20 say "Ihre Auswahl:"
    @ 18,20 Prompt "1. Honsel - 10363"
    @ 19,20 Prompt "2. VVG    - 10167"
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Auswahl
    if ABBRUCH
      close data
      cls
      RETURN
    endif
    vonArt:=ARTIKEL->ArtNr

    if Auswahl=1
      set filter to left(ARTIKEL->KonsigKdNr,5)=="10363"
      KUNDEN->(dbseek("10363"))
      kom:=left(KUNDEN->KurzName,17)
    else
      set filter to left(ARTIKEL->KonsigKdNr,5)=="10167"
      KUNDEN->(dbseek("10167"))
      kom:=left(KUNDEN->KurzName,17)
    endif
    message("Artikel werden gesucht.  Bitte warten...")
    locate for ARTIKEL->ArtNr>=vonArt
  endif

  /* Ausgabe auf Drucker oder BS */
  export:=Druck_Bs("Inventur",.t.,.t.) // Abbruch
  if valtype(export)=="L" .and. ! export
    close data
    RETURN
  endif

  message("Liste wird erstellt.  Bitte warten...")

  // export nach DBF?
  if valtype(export)=="C"
    updateStructure:={;
      {"ArtNr" ,"C", 8,0},;
      {"Art" ,"C", 1,0},;
      {"Bez1" ,"C", 30,0},;
      {"Bez2" ,"C", 30,0},;
      {"ME" ,"C", 3,0},;
      {"Bestand" ,"N", 9,2},;
      {"Einheit" ,"C", 2,0},;
      {"Preis" ,"N", 11,2},;
      {"Wert" ,"N", 11,2}}

    dbCreate(getUser():exportPATH()+BACKSLASH+trim(export) ,updateStructure)
    sele 0
    // TODO: catch error
    use (getUser():exportPATH()+BACKSLASH+trim(export)) excl alias expDatei

    drucker("NOP")
    set cons off
  endif

  select Artikel
  Stop:=stop_key()
  gruppe:=substr(ARTIKEL->ArtNr,1,3)
  do while .not.eof().and. ARTIKEL->artnr<=bis .and. ! stop
    alt=substr(ARTIKEL->artnr,1,1)
    do while ! alt $ "0123456789" .and. ! ARTIKEL->(eof()) .and. ARTIKEL->artnr<=bis
      skip
      alt=substr(ARTIKEL->artnr,1,1)
    enddo
    gesamt="YYY"+alt
    do while .not.eof().and. ARTIKEL->artnr<=bis.and.zeile<DRUCKER->laenge-LISTE->Unt_Rand ;
      .and. alt==substr(ARTIKEL->artnr,1,1) .and. ! stop
      if gruppe<>substr(ARTIKEL->ArtNr,1,3)
        gruppe:=substr(ARTIKEL->ArtNr,1,3)
        grupsum:=0.00
      endif
      do while .not.eof().and. ARTIKEL->artnr<=bis.and.zeile<DRUCKER->laenge-LISTE->Unt_Rand ;
        .and. gruppe==substr(ARTIKEL->ArtNr,1,3) .and. ! stop

        if InvBest == "A" // akt. Inventur Bestand
          bestand:=if(KLager,ARTIKEL->KonsigInv,ARTIKEL->InvBestand)
        else // Bestand aus Historie
          bestand:=if(KLager,getKLagerBestand(ARTIKEL->ArtNr,Datum,.f.,.t.),ARTIKEL->InvBestand)
        endif
        if bestand > 0 .or. getArtikelArt()=="T"

          if neue_Seite
            seite=seite+1
            if KLager
              ? 'I N V E N T U R - L I S T E   K-Lager     vom:',datum,kom,'Seite',str(seite,3)
            else
              ? 'I N V E N T U R - L I S T E               vom:',datum,space(17),'Seite',;
                str(seite,3)
            endif
            ? '-----------------------------------------------------------------------------------'
            ? 'Art.Nr.   Bezeichnung                   Art  Inv.Best ME         Wert      Ges-Wert'
            ? '-----------------------------------------------------------------------------------'
            _____fixedHeader_____
            kopfLaenge:=Zeile
            neue_Seite:=.f.
          endif

          do case
            /* alter Artikel mit Pauschalwert 1 Euro */
          case getArtikelArt()=="X"
            // nop seit 1.12.2010
            // ? out(ARTIKEL->artnr),ARTIKEL->bez1,getArtikelArt(),space(1),bestand,EINHEIT->Text,space(13),str(NeuWert,11,2)
            // &gesamt=&gesamt+NeuWert
            // grupsum=grupsum+NeuWert

            /* normaler Kaufartikel */
          case getArtikelArt()=="E"
            EinzPr=IF(ARTIKEL->Schluessel="H",ARTIKEL->EkPr/100,ARTIKEL->EkPr)
            tex1=IF(ARTIKEL->Schluessel="H","%"," ")
            ? out(ARTIKEL->artnr),ARTIKEL->bez1,getArtikelArt(),space(0),bestand,EINHEIT->Text,;
              right(str(ARTIKEL->EkPr),11,2),tex1,str(EinzPr*bestand,11,2)
            &(gesamt)=ROUND(&(gesamt)+EinzPr*bestand,2)
            grupsum=ROUND(grupsum+EinzPr*bestand,2)

            if .not. empty(ARTIKEL->bez2)
              ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->bez2
            endif

            /* Dienstleistung */
          case getArtikelArt()=="D"
            EinzPr=ARTIKEL->KaPr
            IF ARTIKEL->Schluessel="H"
              EinzPr:=EinzPr/100
              tex1:="%"
            else
              tex1:=" "
            endif
            ? out(ARTIKEL->artnr),ARTIKEL->bez1,getArtikelArt(),space(0),bestand,EINHEIT->Text,;
              str(ARTIKEL->KaPr,11,2),tex1,str(EinzPr*bestand,11,2)
            &(gesamt)=ROUND(&(gesamt)+EinzPr*bestand,2)
            grupsum=ROUND(grupsum+EinzPr*bestand,2)

            if .not. empty(ARTIKEL->bez2)
              ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->bez2
            endif


            /* Fertigungsartikel / Montageartikel (Eigenherstellung) */
          case getArtikelArt() $ "FM"
            EinzPr=ARTIKEL->KaPr
            IF ARTIKEL->Schluessel="H"
              EinzPr:=EinzPr/100
              tex1:="%"
            else
              tex1:=" "
            endif
            ? out(ARTIKEL->artnr),ARTIKEL->bez1,getArtikelArt(),space(0),bestand,EINHEIT->Text,;
              str(ARTIKEL->KaPr,11,2),tex1,str(EinzPr*bestand,11,2)
            &(gesamt)=ROUND(&(gesamt)+EinzPr*bestand,2)
            grupsum=ROUND(grupsum+EinzPr*bestand,2)

            if .not. empty(ARTIKEL->bez2)
              ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->bez2
            endif


            /** ohne Beistellteille */
          case getArtikelArt()=="B"
            // NOP

            /** Werkzeug, geh�rt i.d.R. dem Kunden -> kein Wert */
          case getArtikelArt()=="W"
            // NOP

            /** T-Artikel */
          case getArtikelArt()=="T"
            // raus seit 20.12.2010
            // if ! KLager
            // ? out(ARTIKEL->artnr),ARTIKEL->bez1
            // endif

            /** ansonsten unbekannt */
          otherwise
            ? FETT_AN,"ART unbekannt:",FETT_AUS,out(ARTIKEL->artnr),ARTIKEL->bez1,getArtikelArt(),space(0),;
              bestand,EINHEIT->Text
          endcase

          // export nach DBF?
          if valtype(export)=="C" .and. getArtikelArt()$"DEFM"
            select expDatei
            add_rec(0)
            replace EXPDATEI->ArtNr WITH ARTIKEL->ArtNr
            replace EXPDATEI->Art WITH getArtikelArt()
            replace EXPDATEI->Bez1 WITH ARTIKEL->Bez1
            replace EXPDATEI->Bez2 WITH ARTIKEL->Bez2
            replace EXPDATEI->Bestand WITH bestand
            replace EXPDATEI->ME WITH EINHEIT->Text
            replace EXPDATEI->Preis WITH einzPr
            replace EXPDATEI->Wert WITH EinzPr*bestand

            select Artikel
            message("Liste wird erstellt.  @"+ARTIKEL->ArtNr+"@    Bitte warten...")
          endif

        endif
        skip
        Stop:=stop_key()
      enddo // Gruppe
      if gruppe<>substr(ARTIKEL->ArtNr,1,3) .and. grupSum<>0 .and. ! neue_seite
        ? '-----------------------------------------------------------------------------------'
        ? space(69),grupsum
        ?
      endif
    enddo

    // * drucke Zusammenfassung ************************************
    if zeile > kopfLaenge // Nur wenn etwas gedruckt wurde
      if ! neue_seite
        Zeile:=FormFeed(Zeile,Seite)
        neue_seite:=.t.
      endif
    endif
    if ARTIKEL->(eof()) .or. ARTIKEL->artnr > bis // Zusammenfassung

      // ignore fixed header lines here on screen display
      if getUser():getCurrentPrintJob():className() == "BSJOB"
        getUser():getCurrentPrintJob():fixHeaderLines()
      endif

      ?
      ? 'Gruppe             Ges-Wert'
      ? '---------------------------'
      x=0
      bges=0
      gges=0
      do while x < 10
        gesamt="YYY"+str(x,1)
        if &gesamt <> 0
          ? str(x,3),space(8),transform(&gesamt,"999,999,999.99")
        endif
        gges=gges+&gesamt
        x=x+1
      enddo
      ? '---------------------------'
      ? space(12),transform(gges,"999,999,999.99")
    endif
  enddo
  Drucker('OFF')
  set cons on

  // export nach DBF?
  if valtype(export)=="C"
    if mkMyDir(getUser():exportPATH())
      select expDatei
      BEGIN SEQUENCE // krit. Bereich
        export:=getUser():exportPATH() + BACKSLASH + cleanFileName(export)
        excel:=ExcelExport():new()
        excel:addCurrentDBColumns()
        excel:export(.f.,.f.,export)
        Message(export+" wurde erzeugt.  @Taste@","@")
      RECOVER USING objErr
        // nop, Fehler bereits protokolliert
      END SEQUENCE
    endif
  endif
  close data

RETURN
/* EOP */


/* Inventur-Z�hl-Liste */
PROCEDURE Inv_Zaehl
LOCAL von,bis,mydatum:=date()
LOCAL Gruppe , laenge , alt , Seite:=0 , Zeile:=0
LOCAL Stop:=.f.,druckeBest:="J",sortOrt:="N",mitWerkzeug:="J"
LOCAL GetList:={}, artFilter:="", lg_Raum, lg_Regal, lg_Fach, lg_Text, li:=35

  if ! open( "Einheit","Artikel" )
    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  cls
  Titel('Artikel Inventur-Z�hl - Liste drucken')

  if empty( bis:=von_bis("Artikel",NIL,6 ))
    close data
    cls
    RETURN
  endif
  von:=ARTIKEL->ArtNr
  lg_Raum:=space(len(ARTIKEL->LG_RAUM))
  lg_Regal:=space(len(ARTIKEL->Lg_Regal))
  lg_Fach:=space(len(ARTIKEL->Lg_Fach))
  lg_Text:=space(len(ARTIKEL->Lg_text))

  @ 4,18 to 22,70
  @ 10,20 to 10,68
  @ 12,20 say "Lagerbestand drucken?   :" get druckeBest picture "!" valid druckeBest$"JN" when;
    Message("Lagerbestand drucken?  @J@/@N@")
  @ 14,20 say "Lagerort (Leer = Alle)  :" get lg_Raum picture "@K 99";
    when Message("Lagerort @Raum@ eingeben.    @F12@=Auswahl") ;
    valid { |oGet| oFill(oGet,"0",.t.) .and. check(oGet,"LagerOrt",.t.,.f.) }
  @ 14,li+13 say "."
  @ 14,li+14 get LG_Regal picture "@K 99" when Message("Lagerort @Regal@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ 14,li+16 say "."
  @ 14,li+17 get LG_Fach picture "@K 999" when Message("Lagerort @Fach@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ 14,li+20 say "."
  @ 14 ,li+21 get LG_Text picture "@K" when Message("Lagerort Zusatztext eingeben.")

  @ 16,20 say "Sortiert nach Lagerort? :" get sortOrt picture "!" valid sortOrt$"JN" when;
    Message("Liste nach Lager-Ort sortieren?  @J@/@N@")
  @ 18,20 say "Mit Werkzeug?           :" get mitWerkzeug picture "!" valid mitWerkzeug $ "JN" when;
    Message("Inklusive Werkzeug ausdrucken?  @J@/@N@")

  @ 20,20 say "Datum...................:" get mydatum
  read

  if ABBRUCH .or. ! druck_BS() // Abbruch
    cls
    close data
    RETURN
  endif
  message("Liste wird erstellt.  Bitte warten...")


  // sortiere nach Lagerort
  if sortOrt=="J"
    if mitWerkzeug == "J"
      artFilter:="T"
    else
      artFilter:="TW"
    endif
    index on getArtikelLagerOrt(11)+ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      ! getArtikelArt() $ artFilter .and. ARTIKEL->ArtNr>=von .and. ARTIKEL->ArtNr<=bis .and. ;
      filterLagerOrt(LG_Raum , LG_Regal , LG_Fach , LG_Text)
  else
    if mitWerkzeug <> "J"
      artFilter:="W"
    endif
    set;
      filter;
      to;
      !;
      getArtikelArt();
      $;
      artFilter;
      .and.;
      ARTIKEL->ArtNr>=von;
      .and. ARTIKEL->ArtNr<=bis .and. filterLagerOrt(LG_Raum , LG_Regal , LG_Fach , LG_Text)
  endif
  go top

  laenge:=DRUCKER->Laenge
  Stop:=stop_key()
  gruppe:=if(sortOrt<>"J",substr(ARTIKEL->ArtNr,1,3),getArtikelLagerOrt(11))
  do while .not.ARTIKEL->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? 'I N V E N T U R - Z � H L - L I S T E           vom:',mydatum,space(19),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '---'
    ? 'Art.Nr.    Bezeichnung                    '+if(druckeBest=="J","  Bestand","         ")+;
      ' ME              L-Ort           Z�hlmenge'
    ? '------------------------------------------------------------------------------------------'+;
      '---'
    ?
    _____fixedHeader_____

    alt=substr(ARTIKEL->artnr,1,1)
    do while .not.ARTIKEL->(eof()) .and. zeile<laenge-LISTE->Unt_Rand .and. ! stop

      if (sortOrt<>"J" .and. gruppe<>substr(ARTIKEL->ArtNr,1,3)) .or.;
        (sortOrt=="J" .and. getArtikelLagerOrt(11) <> gruppe)

        gruppe:=if(sortOrt<>"J",substr(ARTIKEL->ArtNr,1,3),getArtikelLagerOrt(11))
        if zeile>5 // Nicht oben auf neuer Seite
          ? '------------------------------------------------------------------------------------'+;
            '-------'
          ?
        endif
      endif
      do while .not.ARTIKEL->(eof()) .and. zeile<laenge-LISTE->Unt_Rand ;
        .and. ! stop;
        .and. ((sortOrt<>"J" .and. gruppe==substr(ARTIKEL->ArtNr,1,3)) .or.;
        (sortOrt=="J" .and. getArtikelLagerOrt(11) == gruppe))

        if getArtikelArt()$"T"
          ? out(ARTIKEL->artnr),ARTIKEL->bez1
          if ! empty(ARTIKEL->Bez2)
            ? space(9),ARTIKEL->bez2
          endif
        else
          ? out(ARTIKEL->artnr),ARTIKEL->bez1,if(druckeBest=="J",ARTIKEL->LageBest,space(9)),;
            EINHEIT->Text,getArtikelLagerOrt(11),"__________   ____________"
          ? space(len(out(ARTIKEL->artnr))),ARTIKEL->bez2
        endif
        Stop:=stop_key()
        skip

        // newpage bei neuer Artikel Obergruppe
        if sortOrt<>"J" .and. alt<>substr(ARTIKEL->artnr,1,1)
          exit
        endif
      enddo // Gruppe
      // newpage bei neuer Artikel Obergruppe
      if sortOrt<>"J" .and. alt<>substr(ARTIKEL->artnr,1,1)
        exit
      endif
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
  close data
  cls
RETURN





/* PROCEDURE Werbe_Liste
*
*/
PROCEDURE Werbe_Liste(Art,Titel)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f. ,v_stor:=space(1) , sum:=0,export
LOCAL excel, objErr

  cls
  titel("Werbegeschenke - Liste")

  if ! open("Werbung")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  // set filter to &(art) > 0
  dbSetFilter( {|| &(art) > 0}, &(art) > 0 )

  export:=druck_BS("WerbeGeschenke",.t.,.t.) // ALLOW_EXPORT,ALLOW_PDF
  if valtype(export)=="L" .and. ! export
    cls
    close data
    RETURN
  elseif valtype(export)=="C" // export nach DBF
    BEGIN SEQUENCE // krit. Bereich
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(export)
      excel:=ExcelExport():new()
      excel:addCurrentDBColumns()
      excel:export(.f.,.f.,export)
      Message(export+" wurde erzeugt.  @Taste@","@")
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
    cls
    close data
    return
  endif
  Message("Liste wird erstellt.   Bitte warten...")

  go top
  do while .not. eof() .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Werbegeschenke: '+left(Titel+space(15),15)+'               Seite',str(seite,3)
    ? '-------------------------------------------------------'
    ? 'Kd.Nr.     Adresse                             Anzahl'
    ? '-------------------------------------------------------'
    do while .not. eof() .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? WERBUNG->KdNr_werb,space(1),WERBUNG->Adr1, space(8),&(art)
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr2
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr3
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr4
      ?
      sum += &(art)
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '-------------------------------------------------------'
    ? space(len(WERBUNG->KdNr_werb)+3+len(WERBUNG->Vertreter)+7),str(sum,4,0)
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()
  Drucker("Off")
  cls
  close data
RETURN
/* Werbe_Liste() */

/* PROCEDURE Werbe_kompl
*
*/
PROCEDURE Werbe_kompl()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f. ,v_stor:=space(1) , sum1:=0,sum2:=0,sum3:=0,sum4:=0
  cls
  titel("Werbegeschenke - Liste")

  if ! open("Werbung")
    Error(TRY_AGAIN)
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
  go top
  do while .not. eof() .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Werbegeschenke: '+space(15)+'               Seite',str(seite,3)
    ? '---------------------------------------------------------------------'
    ? 'Kd.Nr.     Adresse                      Wein Tischk. Wandk. Sonstiges'
    ? '---------------------------------------------------------------------'
    do while .not. eof() .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? WERBUNG->KdNr_werb,space(1),WERBUNG->Adr1, WERBUNG->Geschenk1,space(3),WERBUNG->Geschenk2,;
        space(3),WERBUNG->Geschenk3,space(3),WERBUNG->Geschenk4
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr2
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr3
      ? space(len(WERBUNG->KdNr_werb)+2),WERBUNG->Adr4
      ?
      sum1 += WERBUNG->Geschenk1
      sum2 += WERBUNG->Geschenk2
      sum3 += WERBUNG->Geschenk3
      sum4 += WERBUNG->Geschenk4
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '---------------------------------------------------------------------'
    ? space(len(WERBUNG->KdNr_werb)+len(WERBUNG->Vertreter)-1),str(sum1,6,0),str(sum2,6,0),;
      str(sum3,6,0),str(sum4,6,0)
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()
  Drucker("Off")
  cls
  close data
RETURN
/* Werbe_Liste() */


/*
  * liefert summeEK und summeKaPr als Array zur�ck
  * s. auch BeistellArtikelDetails()
*/
Function BeistellArtikel(mArtNr)
LOCAL seite:=0, zeile:=0, GetList:={},laenge
LOCAL ant
LOCAL excel, objErr, export:="Beistellteile", preise
LOCAL summeEk:=0, summeKaPr:=0, ek, ka

  Umgebung(WRITE_ALL)

  cls
  Titel(" Beistellteile je Artikel - Liste drucken ")


  if ! open( "Artikel" , "AvPost","Einheit","BeisTemp","Manbeist")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN {0,0}
  endif

  if mArtNr == NIL
    BTArtBauch()
  endif

  select Beistemp
  zap

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit
  select Beistemp
  set relation to BEISTEMP->ArtNr into Artikel

  // extrahiere Beistellteile rekursiv
  if mArtNr == NIL
    select Manbeist
    go top
    do while ! MANBEIST->(eof())
      select AvPost
      BeistellRek(MANBEIST->ArtNr,MANBEIST->Menge,"506")
      //BeistellRek(MANBEIST->ArtNr,MANBEIST->Menge,NIL,ARTIKEL->KonsigKdNr)
      select Manbeist
      skip
    enddo
  else
    ARTIKEL->(dbseek(mArtNr))
    BeistellRek(mArtNr,1,"506")
    //BeistellRek(mArtNr,1,NIL, mKdNr)
  endif

  /** ausdrucken ? */
  select BeisTemp
  go top
  if BEISTEMP->(eof())
    Error(ACHTUNG+" Keine Beistellteile gefunden.",.t.)
  else
    if mArtNr == NIL
      ant:=Message("Ausgabe auf @D@rucker, @B@ildschrirm , @P@DF Datei, @H@onsel "+;
        "(@D@/@B@/@P@/@H@) ?", "BDPH","B")
    else
      ant:="B"
    endif
    if ABBRUCH
      cls
      Umgebung(LOAD)
      RETURN {0,0}
    endif

    Message("Liste wird erstellt.   Bitte warten...")
    do case
    case ant=="H"
      select BeisTemp
      if mkMyDir(getUser():exportPATH())
        if (export:=openFileDialog(WRITE,getUser():exportPATH(),export,"xlsx",nil)) == NIL
          cls
          Umgebung(LOAD)
          RETURN {0,0}
        endif
        BEGIN SEQUENCE // krit. Bereich
          excel:=ExcelExport():new()
          excel:addColumnsByName( ;
            { "ArtNr","ARTIKEL->Bez1","ARTIKEL->Bez2","Menge","EINHEIT->Text","Hartnr" } )
          excel:export(.f.,.f.,export)
          Message(export+" wurde erzeugt.  @Taste@","@")
        RECOVER USING objErr
          // nop, Fehler bereits protokolliert
        END SEQUENCE
      endif
      cls
      Umgebung(LOAD)
      RETURN {0,0}
    case ant=="D"
      Drucker("ON")
    case ant=="P"
      if (export:=openFileDialog(WRITE,getUser():exportPATH(),export,"pdf",nil)) == NIL
        cls
        Umgebung(LOAD)
        RETURN {0,0}
      endif

      Drucker("PDF",getFileName(export, .t.), getUser():exportPATH(), .f.,PDF_YES_CONFIRM)
    otherwise
      Drucker("BS")
    endcase

    if mArtNr == NIL
      preise:=Message("Preise anzeigen (@J@/@N@)","JN","J") == "J"
      Seite:=1
      ? "Artikelauswahl                           vom:",getUser():date,space(9),"Seite:",;
        str(seite,3)
      ? "============================================================================="
      select Manbeist
      go top
      do while ! MANBEIST->(eof())
        ARTIKEL->(dbseek(MANBEIST->ArtNr))
        ? ZEIGE_ARTNR+out(MANBEIST->ArtNr),ARTIKEL->Bez1,MANBEIST->Menge,EINHEIT->Text,;
          ARTIKEL->HartNr
        skip
      enddo

      ?
      ?
    else
      preise:=.t.
    endif

    Laenge:=DRUCKER->Laenge

    select BeisTemp

    do while ! BEISTEMP->(eof())
      ? "Beistellteile in Auswahl                 vom:",getUser():date
      if mArtNr == NIL
        ?? space(9),"Seite:",str(seite,3)
      endif
      ? replicate("=",if(preise,114,88))
      ? "Art.Nr       Bezeichnung                          Menge  ME Honsel-Nr.          Kd.Nr."
      if preise
        ?? "            EK   Kalk.Preis"
      endif
      ? replicate("=",if(preise,114,88))

      do while Zeile<laenge-LISTE->Unt_Rand .and. ! BEISTEMP->(eof())
        ARTIKEL->(dbseek(BEISTEMP->ArtNr))
        ? ZEIGE_ARTNR+out(BEISTEMP->ArtNr),ARTIKEL->Bez1,BEISTEMP->Menge,EINHEIT->Text,;
          ARTIKEL->HartNr,ARTIKEL->KonsigKDNr
        if preise
          ka=IIF(ARTIKEL->Schluessel="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr)
          ek=IIF(ARTIKEL->Schluessel="H",ARTIKEL->EKPr/100,ARTIKEL->EKPr)
          ?? str(ek*BEISTEMP->Menge,12,2), str(ka*BEISTEMP->Menge,12,2)
          summeEk += ek * BEISTEMP->Menge
          summeKaPr += ka * BEISTEMP->Menge
        endif
        skip
      enddo
      ? replicate("=",if(preise,114,88))
      if preise
        ? space(88),str(summeEk,12,2),str(summeKaPr,12,2)
      endif
      Zeile:=FormFeed(Zeile,Seite++)
    enddo
    Drucker("Off")
  endif

  cls
  Umgebung(LOAD)
RETURN {summeEk,summeKaPr}


/* ermoeglicht das anzeigen von Beistellteilen aus BS Liste */
PROCEDURE zeigeBeistellListe( ZeilenText , ZeigeData )
LOCAL mArtNr

  ignore ZeilenText

  mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]

  if ! myEmpty( mArtNr )
    BeistellArtikel(mArtNr)
  endif

RETURN
/* EOP */

PROCEDURE BTArtBauch()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  /* Relationen setzen */
  select manbeist
  // zap
  set relation to MANBEIST->ArtNr into Artikel

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z" // Kopf

  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Artikel-Nr."
  aSpalte[EDIT_MASKE]:="@K!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT ]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Bedarf
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MESSAGE]:="Menge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren
  /**** ENDE Feld-Definitionen ***/

  /*** Eingabe / Drucke ****/
  Edit(aFelder,aKopf)

  set rela to
RETURN
/* EOP BTArtBauch */

/*
 * Zeigt die offenen Auftr�ge des akt. selektiern Artikels am BS an
 * Artikel Datei, AvPost und AvAus muss ge�ffnet sein
*
*/
PROCEDURE ArtAuftragsListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0
LOCAL Feld,Summe,i,Meng
LOCAL aufausFilter:=AUFAUS->(dbfilter())
LOCAL aufausRec:=AUFAUS->(recno())

  Umgebung(WRITE_ALL)
  Drucker("BS","Offene Auftr�ge "+ARTIKEL->ArtNr)
  Message("Liste wird erstellt.   Bitte warten...")

  M->specialZeige:={}
  aadd( M->specialZeige , { "Ll" , { |a,b| ZeigeLieferLIste(a,b) } ," @L@ieferstatus" } )

  select Aufaus
  set filter to
  select Aufpost
  set relation to AUFPOST->AufNr into Aufaus
  set;
    filter;
    to;
    AUFPOST->AufArt $ "KRVDB".and.AUFPOST->GeliefGes < AUFPOST->Menge .and. AUFAUS->erledigt<>"J"
  AUFPOST->(OrdSetFocus(4)) // Artikel-Nr+Auf.Nr

  SEEK ARTIKEL->ArtNr
  do while .not. eof() .and. AUFPOST->ArtNr=ARTIKEL->ArtNr .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Offene Auftr�ge - Artikel: '+ARTIKEL->ArtNr,space(47),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '---'
    ? "Auf.Nr   Datum   Kunde                           Menge     Gelief       Rest  KW     "+;
      "Best.Nr."
    ? '------------------------------------------------------------------------------------------'+;
      '---'
    _____fixedHeader_____

    do while .not. AUFPOST->(eof()) .and. AUFPOST->ArtNr=ARTIKEL->ArtNr;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? ZEIGE_AUFNR+AUFAUS->AufNr,if(AUFAUS->AufArt$"BD","R",if(AUFAUS->AufArt$"K","K"," ")),;
        AUFAUS->AufDat,ZEIGE_KUNDNR+AUFAUS->KundNr, substr(AUFAUS->KurzName,1,17),AUFPOST->Menge,;
        AUFPOST->GeliefGes, str(AUFPOST->Menge-AUFPOST->GeliefGes,10,2)
      if .not. empty(AUFPOST->KW)
        ?? space(0),AUFPOST->KW
      else
        i:=1
        Feld:="AUFAUS->KW"+str(i,1)
        summe:=AUFPOST->GeliefGes
        if ! empty(&Feld) .and. alltrim(&Feld)<>"/"
          ?? space(0),AUFPOST->Menge,AUFPOST->GeliefGes,str(AUFPOST->Menge-AUFPOST->GeliefGes,7)
        endif

        do while i <= 6 .and. ! empty(&(Feld)) .and. alltrim(&Feld)<>"/"
          Meng:="AUFAUS->Meng"+str(i,1)
          ? space(41),str( &(Meng) , 7 ),str( Min( Summe , &(Meng) ) , 7),;
            str( &(Meng) - Min( Summe,&(Meng) ) , 7),&(Feld)
          summe:=Max( summe - &(Meng) , 0 )
          i++
          Feld:="AUFAUS->KW"+str(i,1)
        enddo
      endif
      ?? space(0),AUFAUS->BestNr

      // Aufsummieren, aber bei Abrufauftr�gen nicht die Menge und
      // Lieferung, da die bereits im Rahmen-AB enthalten ist.
      if empty(AUFAUS->AB_AufNr)
        M_Menge+=AUFPOST->Menge
        M_Geliefges+=AUFPOST->GeliefGes
      else
        // ACHTUNG die Menge des Abruf-Auftrags ist bereits bei der Rahmen-AB als geliefert berechnet
        M_Menge+=0
        M_Geliefges -= (AUFPOST->Menge - AUFPOST->GeliefGes)
      endif
      M_Rest+=(AUFPOST->Menge - AUFPOST->GeliefGes)

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '---'
    ? space(43),str(M_Menge,10,2),str(M_GeliefGes,10,2),str(M_Rest,10,2)
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  select AufPost
  set Filter to

  // removed 20180703
  // ****** K-Lager Lieferungen (if any) ******************
  // if open("Konsig")
  // set relation to KONSIG->AufNr into Aufaus
  // loca for KONSIG->ArtNr==ARTIKEL->ArtNr .and. KONSIG->GeliefGes>KONSIG->Berechnet
  // .and. AUFAUS->erledigt<>"J"

  // do while .not. KONSIG->(eof()) .and. ! stop
  // Seite=Seite+1
  // Zeile:=0
  // ? 'K-Lager Lieferungen - Artikel: '+ARTIKEL->ArtNr,space(43),'Seite',str(seite,3)
  // ? '---------------------------------------------------------------------------------------------'
  // ? "Auf.Nr   Datum   Kunde                           Menge  Berechnet       Rest  KW     Best.Nr."
  // ? '---------------------------------------------------------------------------------------------'
  // do while .not. KONSIG->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
  // ? AUFAUS->AufNr,space(1),AUFAUS->AufDat,ZEIGE_KUNDNR+AUFAUS->KundNr,;
  // substr(AUFAUS->KurzName,1,17),KONSIG->GeliefGes,KONSIG->Berechnet,;
  // str(KONSIG->GeliefGes-KONSIG->Berechnet,10,2)
  // if .not. empty(KONSIG->KW)
  // ?? space(0),KONSIG->KW
  // endif
  // ?? space(0),AUFAUS->BestNr

  // M_Rest+=(KONSIG->GeliefGes - KONSIG->Berechnet)

  // cont
  // Stop:=stop_key()
  // enddo // Blattl�nge
  // ? '---------------------------------------------------------------------------------------------'
  // ? space(43),space(10),space(10),str(M_Rest,10,2)
  // Zeile:=FormFeed(Zeile,Seite)
  // enddo // eof()
  // endif

  Drucker("Off")
  select Aufaus
  set filter to &(aufausFilter) // not yet supported in Umgebung()
  go (aufausRec)

  Umgebung(LOAD)

RETURN
/* ArtAuftragsListeListe() */


/*
 * Zeigt die offenen Bestellungen des akt. selektiern Artikels am BS an
 * Artikel Datei, Inner, Einheit, BesPost und BesAus muss ge�ffnet sein
 *
  * Parameter: SumBest, SumInt sind egal, werden nur als R�ckgabewert aus NegVerfueg Liste benutzt
  *            Bedarf, BedarfKw = optional, falls angegeben wird bis der Bedarf gedeckt ist alle Bestellungen
  *                               nach dieser KW in rot gedruckt -> m�ssen vorgezogen werden.
 */
PROCEDURE ArtBestellListe(printBuffer,SumBest,SumInt, Bedarf, BedarfKW)
LOCAL seite:=0, zeile:=0, count:=0
LOCAL Stop:=.f.
LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0,M_Ausschuss:=0
LOCAL embeddedList:=( printBuffer <> NIL )
LOCAL merkMe:=0, isRed:=.f.

  default bedarf:=0
  default bedarfKW:=nil

  Umgebung(WRITE_ALL)

  if ! embeddedList
    Drucker("BS","Offene Best. "+ARTIKEL->ArtNr)
    printBuffer:=printBuffer():new()
    Message("Liste wird erstellt.   Bitte warten...")
  endif

  // externe Bestellungen
  SELECT BesPost
  set relation to BESPOST->BestNr into BesAus
  index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for BESPOST->ArtNr=ARTIKEL->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes ;
    .and. BESAUS->Erledigt<>"J" // Nur offene Bestellungen anzeigen

  go top
  do while .not. BESPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    if embeddedList
      ->?
      ->? "BestNr. Datum   Lieferant                    Menge     Gelief.      Rest ME   KW"
      ->? '-----------------------------------------------------------------------------------'
    else
      // nicht im PrintBuffer druken, da fixedHeader sonst (noch) nicht geht
      ? 'Offene Bestellungen - Artikel: '+ARTIKEL->ArtNr+'                     Seite',str(seite,3)
      ? '-----------------------------------------------------------------------------------'
      ? "BestNr. Datum   Lieferant                    Menge     Gelief.      Rest ME   KW"
      ? '-----------------------------------------------------------------------------------'
      _____fixedHeader_____
    endif


    do while .not. BESPOST->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      EINHEIT->(dbseek(BESPOST->ME)) // Einheit der Bestellung
      ->? BESAUS->BestNr,space(0),BESAUS->AufDat,ZEIGE_LIEFNR+BESAUS->LiefNr,;
        substr(BESAUS->KurzName,1,17), transstr(BESPOST->Menge,10,0),;
        transstr(BESPOST->GeliefGes,10,0), transstr(BESPOST->Menge-BESPOST->GeliefGes,10,0),;
        EINHEIT->Text
      count++
      if .not. empty(BESPOST->KW) .and. KWokay(BESPOST->KW) // 9.4.2015 ohne Abruf-Auftr�ge

        if left(BESPOST->KW,1)=="*"
          ->?? space(0),trim(BESPOST->KW_text)
        else
          // drucke in rot falls �berf�llig
          if bedarfKW <> nil .and. ! empty(bedarfKW) .and. kwOkay(bedarfKW) .and.;
            kwKleiner( BESPOST->KW , bedarfKW ) < 0 .and. Bedarf > 0
            ->?? COLOR_RED
            isRed:=.t.
          endif

          ->?? space(0),BESPOST->KW

          if isRed
            ->?? "vorziehen!",COLOR_DEFAULT
            isRed:=.f.
          endif

          // Restbedarf auch berechnen falls vor BedarfsKW
          bedarf:=Max( Bedarf - (BESPOST->Menge-BESPOST->GeliefGes) , 0 )

        endif
      endif

      /* Aufsummieren */
      if ARTIKEL->ME == BESPOST->Me
        M_Menge+=BESPOST->Menge
        M_Geliefges+=BESPOST->GeliefGes
        M_Rest+=(BESPOST->Menge - BESPOST->GeliefGes)
        if hb_BitAnd( merkMe , ME_MIKI ) <> ME_MIKI // Artikel ME
          merkME:=merkME + ME_MIKI
        endif
      else
        /** abweichende Mengeneinheit ? */
        // Umrechnung bekannt
        if ARTIKEL->ME2 == BESPOST->Me // Addition immer in Artikel ME
          M_Menge += ( BESPOST->Menge / ARTIKEL->ME_Faktor )
          M_Geliefges+= ( BESPOST->GeliefGes / ARTIKEL->ME_Faktor )
          M_Rest+= ( (BESPOST->Menge - BESPOST->GeliefGes) / ARTIKEL->ME_Faktor )
          if hb_BitAnd( merkMe , ME_LIEF) <> ME_LIEF // Lieferanten ME
            merkME:=merkME + ME_LIEF
          endif
        else
          TroubleEmail(BESPOST->ArtNr+" "+BESPOST->Me + " Umrechnung nicht bekannt !")
        endif
      endif

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    EINHEIT->(dbseek(ARTIKEL->ME)) // Einheit des Artikels!
    if count > 1
      ->? '-----------------------------------------------------------------------------------'
      // Einheit des Artikels immer anzeigen
      ->? space(39),transstr(M_Menge,10,0),transstr(M_GeliefGes,10,0),transstr(M_Rest,10,0),;
        EINHEIT->Text

      // Lieferanten ME nur falls in Bestellungen verwendet
      if hb_BitAnd( merkMe , ME_LIEF) == ME_LIEF
        EINHEIT->(dbseek( ARTIKEL->ME2 ))
        ->? space(39),str(round( M_Menge * ARTIKEL->ME_Faktor,2 ) ,10,2),;
          str(round( M_GeliefGes * ARTIKEL->ME_Faktor,2 ) ,10,2),;
          str(round( M_Rest * ARTIKEL->ME_Faktor ,2 ) ,10,2 ),EINHEIT->Text
      endif
    endif

    if .not. BESPOST->(eof())
      Zeile:=FormFeed(Zeile,Seite)
    else
      ->?
      // ->?
    endif
  enddo // eof()
  BESPOST->(OrdDestroy(TEMP_INDEX))

  sumBest:=M_Rest

  // interne Bestellungen
  count:=0
  SELECT Inner
  index on KWIndex(INNER->Fert_KW) + KWIndex(INNER->Lief_KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for INNER->ArtNr==ARTIKEL->ArtNr .and. INNER->Erledigt <> "J" .and. isInnerHauptArbeitsgang()
  go top
  do while .not. INNER->(eof()) .and. INNER->ArtNr=ARTIKEL->ArtNr .and. ! stop
    Seite=Seite+1
    Zeile:=0
    if embeddedList
      ->?
    else
      ->? 'Interne Bestellungen - Artikel: '+ARTIKEL->ArtNr
      ->? '--------------------------------------------------------------------------------'
    endif
    ->? "InnerNr. Datum       Menge       Ausschuss    Gelief    Rest ME Fert.KW  Lief.KW"
    ->? '--------------------------------------------------------------------------------'
    do while .not. INNER->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ->? ZEIGE_INNERNR+INNER->InnerNr,space(2),INNER->AufDat,;
        getMengStr2(INNER->Menge,INNER->MengeAB),INNER->Ausschuss, INNER->GeliefGes,;
        str(Max(INNER->Menge-INNER->GeliefGes,0),7),EINHEIT->Text,space(0),INNER->Fert_KW,;
        space(2),INNER->Lief_KW
      if empty(INNER->AufNr)
        if ! empty(INNER->Grund)
          ->? space(7),INNER->Grund
        endif
      else
        AUFAUS->(dbseek(INNER->AufNr))
        ->? space(7),AUFAUS->AufNr,AUFAUS->Kurzname
      endif
      count++
      if ! empty(INNER->Bemerkung)
        aEval(HB_ATokens(INNER->Bemerkung,MY_CR+MY_LF),;
          { |x| getUser():getCurrentPrintJob():print({space(7),x},.t.),zeile++,.t. })
      endif
      /* Aufsummieren */
      M_Menge+=INNER->Menge
      M_Geliefges+=INNER->GeliefGes
      M_Ausschuss+=INNER->Ausschuss
      M_Rest+=Max(INNER->Menge - INNER->GeliefGes,0)

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    if count > 1
      ->? '--------------------------------------------------------------------------------'
      ->? space(16),str(M_Menge,9,2),space(5),str(M_Ausschuss,9,2),str(M_GeliefGes,9,2),str(M_Rest,7,0),;
        EINHEIT->Text
    endif
    if .not. INNER->(eof())
      Zeile:=FormFeed(Zeile,Seite)
    else
      ->?
    endif
  enddo // eof()
  INNER->(OrdDestroy(TEMP_INDEX))

  sumInt:=M_Rest

  if ! embeddedList
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    Drucker("Off")
  endif
  Umgebung(LOAD)

RETURN
/* eop */

/*
 * Zeigt die Artikel an die ein Kunde bekommen hat
  *
  * seit 12.4.2014 auch alle Versand- und AB-Adressen
  */
PROCEDURE ArtKundListe(MKundNr)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,bez:="",kom,sortierung,verpackung
LOCAL mArtNr, div, wert, gesWertAB:=0 , gesWertRechn:=0 , gesWertVersand:=0
LOCAL excel, objErr, export, Ausgabe, oCol

  default MKundNr:=""

  Umgebung(WRITE_ALL)

  if ! open("Rechaus","RechPost","Einheit","Artikel","avaus","AvPost","AvAus", "Inner")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  // set filter to len(alltrim(RECHPOST->ArtNr))>FRACHT_LAENGE // .and. RECHPOST->KundNr==MKundNr
  sortierung:=Message("Sortiert nach @A@rtikeln oder @R@echnungsnummer?  (@A@/@R@)","AR","R")
  if ABBRUCH
    Umgebung(LOAD)
    RETURN
  endif

  verpackung:=Message("Verpackung ausdrucken?  (@J@/@N@)","JN","N")
  if ABBRUCH
    Umgebung(LOAD)
    RETURN
  endif

  /* Excel exportiern oder Liste ausdrucken / anzeigen */
  Ausgabe:=Druck_Bs("Kunde-"+alltrim(mKundNr)+"-Artikel" , "xlsx" , .t.)
  if ABBRUCH .or. ( valtype(Ausgabe) == "L" .and. ! Ausgabe )
    Umgebung(LOAD)
    RETURN
  endif

  select Rechpost
  set rela to RECHPOST->RechNr into Rechaus, to RECHPOST->ME into Einheit
  Message("Liste wird sortiert.   Bitte warten...")

  if sortierung == "A"
    index on RECHPOST->ArtNr+RECHPOST->Rechnr tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for (RECHAUS->KundNr==MKundNr .or. RECHAUS->V_KundNr==MKundNr .or. RECHAUS->R_KundNr==MKundNr );
      .and. (verpackung == "J" .or. len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE)
  else
    index on RECHPOST->Rechnr tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for (RECHAUS->KundNr==MKundNr .or. RECHAUS->V_KundNr==MKundNr .or. RECHAUS->R_KundNr==MKundNr) ;
      .and. (verpackung == "J" .or. len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE)
  endif

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." };
    )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->SpecialZeige , { "m" , { |a , b| aendStkList( a , b , "M") } , "@M@=Mat."} )

  if ! ABBRUCH .and. ( valtype(Ausgabe) <> "L" .or. Ausgabe )
    if valtype(Ausgabe)=="C"
      Message("Datei wird erstellt.  Bitte warten.")
      if mkMyDir(getUser():exportPATH())
        BEGIN SEQUENCE // krit. Bereich
          export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
          excel:=ExcelExport():new()
          excel:addColumnsByName( {{ "ArtNr", "Artikel-Nr."}} )

          oCol:=ExcelColumn():new()
          oCol:title:="Bezeichnung"
          oCol:Codeblock:=;
            { || if(empty(RECHPOST->Komm2),RECHPOST->Komm1,RECHPOST->Komm1+MY_LF+RECHPOST->Komm2) }
          excel:addColumn(oCol)

          excel:addColumnsByName( {;
            { "RECHAUS->ReaDat","Rechn.Datum"},;
            { "RECHAUS->BestNr", "Bestell-Nummer" }})

          oCol:=ExcelColumn():new()
          oCol:fieldName:="Gelief"
          oCol:title:="Geliefert"
          oCol:Sum:=.t.
          oCol:numberFormat:=EXCEL_NUMBER_FORMAT_DEFAULT
          excel:addColumn(oCol)

          excel:addColumnsByName( {;
            { "EINHEIT->Text", "ME"} ;
            } )
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
    ? 'Artikel / Rechnung je Kunde: '+MKundNr+KUNDEN->KurzName,space(33),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------'
    ? "Datum    Re.Nr. Art.Nr   Bezeichnung                            Preis      Menge Rabatt "+;
      "Sond.Rab    Wert Art"
    ? "         AB-Nr. Best.Nr"
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------'
    _____fixedHeader_____

    do while .not. RECHPOST->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      // Leerzeile bei Sortierung nach Artikel
      if sortierung == "A"
        if mArtNr == nil
          mArtNr:=RECHPOST->ArtNr
        elseif mArtNr <> RECHPOST->ArtNr
          ?
          mArtNr:=RECHPOST->ArtNr
        endif
      endif

      // berechne Wert abzgl. Rabatte
      div=IIF(RECHPOST->PE$"Hh",100,1)
      wert=abs(ROUND(RECHPOST->Preis * RECHPOST->menge/div,2))
      IF RECHPOST->rabatt<>0.0
        wert= wert - ROUND(wert * RECHPOST->Rabatt /100,2)
      endif
      IF RECHAUS->SO_Rabatt <> 0.0
        wert= wert - ROUND(wert * RECHAUS->SO_Rabatt/100,2)
      endif

      // nur bei akt. Kunden
      kom:=NIL
      if MKundNr == RECHAUS->KundNr
        kom:=myAddKom(kom,"AB")
        geswertAB += wert
      endif
      if MKundNr == RECHAUS->V_KundNr
        kom:=myAddKom(kom,"Versand")
        geswertVersand += wert
      endif
      if MKundNr == RECHAUS->R_KundNr
        kom:=myAddKom(kom,"Rechnung")
        geswertRechn += wert
      endif
      if kom<>NIL

        // drucke Posten
        ? RECHPOST->ReaDat,ZEIGE_RECHNR+RECHPOST->Rechnr,space(0),ZEIGE_ARTNR+RECHPOST->ArtNr,;
          left(RECHPOST->Komm1,30),;
          RECHPOST->Preis/if(RECHPOST->PE=="H",100,1),RECHPOST->Gelief,RECHPOST->Rabatt,space(1),;
          RECHAUS->SO_Rabatt,transstr(wert,9,2),kom

        ? space(8),ZEIGE_AUFNR+RECHAUS->AufNr,space(0),RECHAUS->BestNr

        // drucke Empf�nger falls abweichend
        if RECHAUS->V_KundNr <> MKundNr
          KUNDEN->(dbseek( RECHAUS->V_KundNr ))
          ?? space(20),"Empf�nger:",RECHAUS->V_KundNr,KUNDEN->KurzName
        endif
        ?

      endif
      skip
      Stop:=stop_key()
    enddo // Blattl�nge

    if RECHPOST->(eof())
      ? '----------------------------------------------------------------------------------------'+;
        '----------------------'
      ? "Gesamt-Umsatz AB:",transstr(gesWertAB,13,2),"Versand:",transstr(geswertVersand,13,2),;
        "Rechnung:",transstr(gesWertRechn,13,2)
    endif
    Zeile:=FormFeed(Zeile,Seite)
    mArtNr:=nil
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* EOP */

/** f�gt die Art zum Kommentar dazu, mit Kommas getrennt */
static function myAddKom(kom,text)
  if kom==NIL
    kom:=text
  else
    kom:=kom+", "+text
  endif
return kom
/** eof */


/* PROCEDURE KundeArtListe
 *
 * Zeigt die Kunden an die einen Artikel bekommen haben
*
*/
PROCEDURE KundArtListe(MArtNr)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,bez:="",gesMenge:=0
  default MArtNr:=""

  Umgebung(WRITE_ALL)

  if ! open("Rechaus","RechPost")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select RechPost
  // set rela to RECHPOST->RechNr into Rechaus
  set filter to RECHPOST->ArtNr==MArtNr

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")


  go top
  do while .not. RECHPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Kunde (Rechnung) je Artikel: '+MArtNr,ARTIKEL->Bez1,space(7),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--'
    ? "Datum     Re.Nr AB-Nr. Art.Nr               Preis      Menge Rabatt Sond.Rab Kd.Nr.   "+;
      "Kd.Bez"
    ? "          Best.Nr"
    ? '------------------------------------------------------------------------------------------'+;
      '--'
    _____fixedHeader_____

    do while .not. RECHPOST->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      RECHAUS->(dbseek(RECHPOST->RechNr))
      ? RECHPOST->ReaDat,space(0),ZEIGE_RECHNR+RECHPOST->Rechnr,ZEIGE_AUFNR+RECHPOST->AufNr,space(0),;
        ZEIGE_ARTNR + out(RECHPOST->ArtNr),;
        RECHPOST->Preis/if(RECHPOST->PE=="H",100,1),;
        RECHPOST->Gelief,RECHPOST->Rabatt,space(1),RECHAUS->SO_Rabatt,space(1),;
        ZEIGE_KUNDNR + RECHAUS->KundNr,RECHAUS->KurzName

      // 2. Zeile ?
      if RECHAUS->KundNr <> RECHAUS->V_KundNr
        KUNDEN->(dbseek( RECHAUS->V_KundNr ))
        ? space(9),RECHAUS->BestNr,space(40),RECHAUS->v_KundNr,KUNDEN->Kurzname
        ?
      else
        if ! empty(RECHAUS->BestNr)
          ? space(9),RECHAUS->BestNr
        endif
      endif
      gesMenge+=RECHPOST->Gelief
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    if RECHPOST->(eof())
      ? '----------------------------------------------------------------------------------------'+;
        '----'
      ? space(37),transstr(gesMenge,22,2)
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/*
 *
 * Zeigt die Kunden zu einer Referenz-Datei an, z.B. Spedition, VersArt, etc.
  *
  * nimmt das Hauptfeld der aktuellen Datei und sucht dieses im Kundenstamm
*
*/
PROCEDURE KundWertListe(additionalOrCondition)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL datei:=db_info( Alias() )
LOCAL fieldValue:=getKeyFieldValue( datei )
LOCAL fieldName:=getKeyFieldName( datei )
LOCAL mytext:=trim( fieldget( 2 )) // Obacht!

  Umgebung(WRITE_ALL)

  if ! open("Kunden")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Kunden
  if additionalOrCondition == NIL .or. valtype( additionalOrCondition ) <> "B" // nur FeldWert z.B. ZKNr
    set filter to KUNDEN->(fieldget( fieldPos ( fieldName ))) == fieldValue
  elseif KUNDEN->(fieldPos ( fieldName )) > 0 // FeldWert z.B. ZKNr und extra Condition
    set filter to KUNDEN->(fieldget( fieldPos ( fieldName ))) == fieldValue .OR. ;
      eval( additionalOrCondition ,fieldValue )
  else // nur extra condition
    set filter to eval( additionalOrCondition , fieldValue )
  endif

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  go top
  do while .not. KUNDEN->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Kunden mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",str(seite,3)
    ? "----------------------------------------------------------------"
    ? "Kund.Nr.  Name"
    ? "----------------------------------------------------------------"
    _____fixedHeader_____
    do while .not. KUNDEN->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? KUNDEN->KundNr,space(0),KUNDEN->KurzName
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/*
 *
 * Zeigt die ABs zu einer Referenz-Datei an, z.B. Spedition, VersArt, etc.
  *
  * nimmt das Hauptfeld der aktuellen Datei und sucht dieses in den ABs
*
*/
PROCEDURE ABWertListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL datei:=db_info( Alias() )
LOCAL fieldValue:=getKeyFieldValue( datei )
LOCAL fieldName:=getKeyFieldName( datei )
LOCAL mytext:=trim( fieldget( 2 )) // Obacht!
LOCAL erst:=.t.

  Umgebung(WRITE_ALL)

  // Auftr�ge
  if ! open("Aufaus")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Aufaus
  set filter to AUFAUS->(fieldget( fieldPos ( fieldName ))) == fieldValue

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  go top
  do while .not. AUFAUS->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Angebote & Auftr�ge mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",str(seite,3)
    ? "-----------------------------------------------------------------------"
    ? "Nummer Datum    Kd.Nr.   Name"
    ? "-----------------------------------------------------------------------"
    _____fixedHeader_____
    if erst
      ? "Auftr�ge:"
      ? "========="
      erst:=.f.
    endif
    do while .not. AUFAUS->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? ZEIGE_AUFNR + AUFAUS->AufNr,space(0),AUFAUS->AufDat,AUFAUS->KundNr,AUFAUS->Kurzname

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  // Angebote
  if ! open("Angaus")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Angaus
  set filter to ANGAUS->(fieldget( fieldPos ( fieldName ))) == fieldValue

  erst:=.t.
  go top
  do while .not. ANGAUS->(eof()) .and. ! stop
    if Seite == 0
      ? "Angebote & Auftr�ge mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",;
        str(seite,3)
      ? "-----------------------------------------------------------------------"
      ? "Nummer Datum     Kd.Nr.   Name"
      ? "       Art.Nr.   Bezeichnung                                  Menge"
      ? "-----------------------------------------------------------------------"
      _____fixedHeader_____
    else
      _____fixedHeader_____ // need this here, otherwise body is not printed
    endif
    if erst
      ?
      ? "Angebote:"
      ? "========="
      erst:=.f.
    endif
    Seite=Seite+1
    Zeile:=0
    do while .not. ANGAUS->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? ANGAUS->AngNr,space(0),ANGAUS->AufDat,ANGAUS->KundNr,ANGAUS->Kurzname

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  // Kunden, if applicable
  if ! open("Kunden")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Kunden
  if fieldPos ( fieldName ) > 0
    set filter to KUNDEN->(fieldget( fieldPos ( fieldName ))) == fieldValue

    erst:=.t.
    go top
    do while .not. KUNDEN->(eof()) .and. ! stop
      if Seite == 0
        ? "Kunden mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",str(seite,3)
        ? "----------------------------------------------------------------"
        ? "Kund.Nr.  Name"
        ? "----------------------------------------------------------------"
        _____fixedHeader_____
      else
        _____fixedHeader_____ // need this here, otherwise body is not printed
      endif
      if erst
        ?
        ? "Kunden:"
        ? "========="
        erst:=.f.
      endif
      Seite=Seite+1
      Zeile:=0
      do while .not. KUNDEN->(eof()) ;
        .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

        ? KUNDEN->KundNr,space(0),KUNDEN->KurzName
        skip
        Stop:=stop_key()
      enddo // Blattl�nge
      Zeile:=FormFeed(Zeile,Seite)
    enddo // eof()
  endif

  // Lieferan, if applicable
  if ! open("Lieferan")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Lieferan
  if fieldPos ( fieldName ) > 0
    set filter to LIEFERAN->(fieldget( fieldPos ( fieldName ))) == fieldValue

    erst:=.t.
    go top
    do while .not. LIEFERAN->(eof()) .and. ! stop
      if Seite == 0
        ? "Lieferanten mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",str(seite,3)
        ? "----------------------------------------------------------------"
        ? "Lief.Nr.  Name"
        ? "----------------------------------------------------------------"
        _____fixedHeader_____
      else
        _____fixedHeader_____ // need this here, otherwise body is not printed
      endif
      if erst
        ?
        ? "Lieferant:"
        ? "=========="
        erst:=.f.
      endif
      Seite=Seite+1
      Zeile:=0
      do while .not. LIEFERAN->(eof()) ;
        .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

        ? LIEFERAN->LiefNr,space(0),LIEFERAN->KurzName
        skip
        Stop:=stop_key()
      enddo // Blattl�nge
      Zeile:=FormFeed(Zeile,Seite)
    enddo // eof()
  endif

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */


/*
 *
 * Zeigt die ABs zu einer Referenz-Datei (hier Posten!) an, z.B. LiefTerm, Rabattgruppe
  *
  * nimmt das Hauptfeld der aktuellen Datei und sucht dieses in den ABs
*
*/
PROCEDURE ABPostListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL datei:=db_info( Alias() )
LOCAL fieldValue:=getKeyFieldValue( datei )
LOCAL fieldName:=getKeyFieldName( datei )
LOCAL mytext:=fieldget( 2 ) // Obacht!
LOCAL erst:=.t.

  if valtype( myText ) == "C"
    mytext:=trim( myText )
  else
    mytext:=""
  endif

  Umgebung(WRITE_ALL)

  // Auftr�ge
  if ! open("Aufaus","AufPost","Einheit")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select AufPost
  set filter to left(AUFPOST->(fieldget( fieldPos ( fieldName ))),len(fieldValue)) == fieldValue
  set rela to AUFPOST->AufNr into AufAus , to AUFPOST->ME into Einheit

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  go top
  do while .not. AUFAUS->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Angebote & Auftr�ge mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",str(seite,3)
    ? "-----------------------------------------------------------------------"
    ? "Nummer Datum   Kd.Nr.   Name"
    ? "       Art.Nr. Bezeichnung                                    Menge"
    ? "-----------------------------------------------------------------------"
    _____fixedHeader_____
    if erst
      ? "Auftr�ge:"
      ? "========="
      erst:=.f.
    endif
    do while .not. AUFAUS->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? ZEIGE_AUFNR + AUFAUS->AufNr,space(0),AUFAUS->AufDat,AUFAUS->KundNr,AUFAUS->Kurzname
      ? space(len(AUFAUS->AufNr)+1),AUFPOST->ArtNr,AUFPOST->Komm1,AUFPOST->Menge,EINHEIT->Text

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  // Angebote
  if ! open("Angaus","AngPost")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Angpost
  set filter to left(ANGPOST->(fieldget( fieldPos ( fieldName ))),len(fieldValue)) == fieldValue
  set rela to ANGPOST->Angnr into Angaus , to ANGPOST->ME into Einheit

  erst:=.t.
  go top
  do while .not. ANGAUS->(eof()) .and. ! stop
    if Seite == 0
      ? "Angebote & Auftr�ge mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'","Seite",;
        str(seite,3)
      ? "-----------------------------------------------------------------------"
      ? "Nummer Datum    Kd.Nr.   Name"
      ? "       Art.Nr.  Bezeichnung                                   Menge"
      ? "-----------------------------------------------------------------------"
      _____fixedHeader_____
    else
      _____fixedHeader_____ // need this here, otherwise body is not printed
    endif
    if erst
      ?
      ? "Angebote:"
      ? "========="
      erst:=.f.
    endif


    Seite=Seite+1
    Zeile:=0
    do while .not. ANGAUS->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? ANGAUS->Angnr,space(0),ANGAUS->AufDat,ANGAUS->KundNr,ANGAUS->Kurzname
      ? space(len(ANGAUS->Angnr)+1),ANGPOST->ArtNr,ANGPOST->Komm1,ANGPOST->Menge,EINHEIT->Text

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/* Zeigt die Artikel an bei denen die �bergebenen Werte vorkommen, z.B. AvSortNr, ErlGruppe
*
  * nimmt das Hauptfeld der aktuellen Datei und sucht dieses im Artikelstamm
*/
PROCEDURE ArtikelWertListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL datei:=db_info( Alias() )
LOCAL fieldValue:=getKeyFieldValue( datei )
LOCAL fieldName:=getKeyFieldName( datei )
LOCAL mytext:=""

  Umgebung(WRITE_ALL)

  if ! open("Artikel","Waraus","AvAus","AvPost","Einheit","Besaus")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    Return
  endif

  WARAUS->(OrdSetFocus(2)) // descending
  select Artikel

  // nehme 2. Feld als Beschreibung, ouch! -> Obacht!
  if fieldType( 2 ) == "C"
    mytext:=trim( fieldget( 2 ))
  endif


  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")
  index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for ARTIKEL->(fieldget( fieldPos ( fieldName ))) == fieldValue

  go top
  do while .not. ARTIKEL->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Artikel mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"'",'Seite',str(seite,3)
    ? '------------------------------------------------------'
    ? "Art.Nr.      Bezeichnung               Letzte Bewegung"
    ? '------------------------------------------------------'
    _____fixedHeader_____

    do while .not. ARTIKEL->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      WARAUS->(dbseek( ARTIKEL->ArtNr ))
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,space(1),WARAUS->Datum
      if ! empty(ARTIKEL->Bez2)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* EOP */


/* Zeigt die Artikel an bei denen die letzte Stelle der Art.Nr. �bereinstimmt
*
  * nimmt das Hauptfeld der aktuellen Datei und sucht dieses im Artikelstamm
*/
PROCEDURE ArtikelLetzteStelle()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL datei:=db_info( Alias() )
LOCAL fieldValue:=LETZTEST->LetzteSt
LOCAL mytext:=trim( LETZTEST->Text )

  Umgebung(WRITE_ALL)

  if ! open("Artikel")
    Error(TRY_AGAIN)
    cls
    Return
  endif

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")
  index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for right(ARTIKEL->ArtNr,1) == fieldValue

  go top
  do while .not. ARTIKEL->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Artikel mit "+datei [D_KURZ]+": "+fieldValue,"'"+mytext+"' -",'Seite',str(seite,3)
    ? '---------------------------------------------------'
    ? "Art.Nr.   Bezeichnung"
    ? '---------------------------------------------------'

    do while .not. ARTIKEL->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1
      if ! empty(ARTIKEL->ArtNr)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '----------'
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* EOP */





/* 
 * Zeigt die offenen Bestellungen aller Artikel  an
 * Artikel Datei, Inner, BesPost und BesAus muss ge�ffnet sein
*/
PROCEDURE BestellListe(force)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,GetList:={}
LOCAL alle:="N", thisWeek:=getCurrentKW()
LOCAL liFullName
  default force:=.f.

  cls
  titel("Offene Bestellung")

  if force
    Drucker("PDF")
  else
    message("@J@=Alle offene Bestellungen, @N@=nur offenen f�llige Bestellungen")
    @ 12,20 say "Alle Bestellungen?" get alle picture "!" valid alle $"JN"
    read
    if ABBRUCH .or. ! druck_BS() // Abbruch
      cls
      RETURN
    endif
  endif

  if ! open("BesPost","BesAus","Einheit")
    Error(TRY_AGAIN)
    close data
    cls
    return
  endif

  Message("Liste wird erstellt.   Bitte warten...")

  // externe Bestellungen
  SELECT BesPost
  set rela to BESPOST->BestNr into BesAus

  if alle=="J"
    set filter to len(alltrim(BESPOST->ArtNr))>FRACHT_LAENGE .and. ;
      round(BESPOST->Menge,0) > round(BESPOST->GeliefGes,0) .and. BESAUS->Erledigt<>"J"
  else
    set filter to len(alltrim(BESPOST->ArtNr))>FRACHT_LAENGE .and. ;
      round(BESPOST->Menge,0) > round(BESPOST->GeliefGes ,0) ;
      .and. kwKleiner(BESPOST->KW,thisWeek)>0 .and. BESAUS->Erledigt<>"J"
  endif

  index on kwindex(BESPOST->Kw)+BESPOST->BestNr+BESPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE
  go top
  do while .not. BESPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Offene Bestellungen extern                             vom:',getUser():date,'KW:',thisWeek,;
      space(37),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '-------------------------------------'
    ? "BestNr. Datum   ArtNr     Bezeichnung                              Lieferant               "+;
      "   Menge   Gelief.   Rest ME   KW"
    ? '------------------------------------------------------------------------------------------'+;
      '-------------------------------------'
    do while .not. BESPOST->(eof());
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      EINHEIT->(dbseek( BESPOST->ME ))
      ? BESAUS->BestNr,space(0),BESAUS->AufDat,ZEIGE_ARTNR+BESPOST->ArtNr,BESPOST->Komm1,;
        ZEIGE_LIEFNR+BESAUS->LiefNr,substr(BESAUS->KurzName,1,17),str(BESPOST->Menge,8,0),;
        str(BESPOST->GeliefGes,8,0),str(BESPOST->Menge-BESPOST->GeliefGes,7),EINHEIT->Text
      if .not. empty(BESPOST->KW)
        if left(BESPOST->KW,1)=="*"
          ?? space(0),trim(BESPOST->KW_text)
        else
          ?? space(0),BESPOST->KW
        endif
      endif

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '-------------------------------------'

    if .not. BESPOST->(eof())
      Zeile:=FormFeed(Zeile,Seite)
    else
      ?
      ?
    endif
  enddo // eof()

  getUser():getCurrentPrintJob():endDoc()
  liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if force
    email(MAIN_EMAIL,"Offene Bestellungen vom: "+dtoc(getUser():date),;
      "Offene Bestellungen vom: "+dtoc(getUser():date),liFullName)
  endif

  close data

RETURN
/* EOP */


/** liefert einen standardisierten String mit beiden Mengen (ext & intern) */
static Function getMengStr2(anzahl,anzAB)
LOCAL result:=str(anzahl,9,2)

  ignore anzAb

  // if anzAB== NIL .or. anzAB==0 // nur Miki
  // result+="(Miki)"
  // elseif anzAB==anzahl // nur externe AB
  // result+="(ext.)"
  // else // gemischt
  // result+="("+alltrim(str(anzAB,7))+")"
  // endif
return left(result+space(17),17)
/** eof */

/*
 * Zeigt die offenen interner Bestellungen des akt. selektiern Artikels und dessen Oberartikels am BS an
 * Artikel Datei, Inner, Einheit, BesPost und BesAus muss ge�ffnet sein
 */
PROCEDURE ArtInnerListe()
LOCAL zeile:=0
LOCAL Stop:=.f.
LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0,M_Ausschuss:=0
LOCAL parents , faktor , pos
LOCAL aktArtnr:=ARTIKEL->ArtNr, aktRec:=ARTIKEL->(recno())
LOCAL LagerBestand:=ARTIKEL->LageBest

  Umgebung(WRITE_ALL)

  Drucker("BS","Innerbetr. Auftr�ge: "+ARTIKEL->ArtNr)
  Message("Liste wird erstellt.   Bitte warten...")

  // hole alle Oberartikel 1. Ebene dar�ber
  parents:=Stueckliste():new( ARTIKEL->ArtNr, ARTIKEL->Art, 1 ):getParents( "M" )

  SELECT Inner
  index on kwIndex(INNER->Lief_KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for INNER->Erledigt <> "J" .and. isInnerHauptArbeitsgang()

  Zeile:=0
  ? 'Interne Bestellungen - Artikel: '+aktArtnr
  ? '--------------------------------------------------------------------------------------------'
  ? "InnerNr. Datum       Menge       Ausschuss    Gelief    Rest ME Fert.KW  Lief.KW Lg.Best ME "
  ? '--------------------------------------------------------------------------------------------'
  _____fixedHeader_____

  go top
  do while .not. INNER->(eof()) .and. ! stop
    // falls Artikel oder parent Artikel
    pos:=0
    if INNER->ArtNr == aktArtnr .or. ;
      (pos:=aScan( parents , { |stkListe| stkListe:artNr == INNER->ArtNr } ) ) > 0

      if pos == 0
        faktor:=-1
      else
        faktor:=(-1) / parents[ pos ]:menge
      endif

      LagerBestand += INNER->Menge * faktor // Faktor ist bereits negativ

      ? ZEIGE_INNERNR+INNER->InnerNr,space(2),INNER->AufDat,;
        getMengStr2(INNER->Menge * faktor , INNER->MengeAB * faktor),;
        str(INNER->Ausschuss * faktor , 7,2) , str( INNER->GeliefGes * faktor , 9,2) ,;
        str(Max(INNER->Menge * faktor - INNER->GeliefGes * faktor,0) ,7),EINHEIT->Text,space(0),;
        INNER->Fert_KW, space(2),INNER->Lief_KW, str(lagerbestand,7),EINHEIT->Text

      if ! empty(INNER->AufNr)
        AUFAUS->(dbseek(INNER->AufNr))
        ? space(7),AUFAUS->AufNr,AUFAUS->Kurzname
      else
        if ! empty(INNER->Grund)
          ? space(7),INNER->Grund
        endif
      endif

      if pos > 0
        ARTIKEL->(dbseek( parents[ pos ]:ArtNr ))
        ? space(7),out(ARTIKEL->ArtNr),ARTIKEL->Bez1
        if ! empty( ARTIKEL->Bez2 )
          ? space(7),space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
        endif
      endif

      ARTIKEL->(dbgoto(aktRec))

      if ! empty(INNER->Bemerkung)
        aEval(HB_ATokens(INNER->Bemerkung,MY_CR+MY_LF),;
          { |x| getUser():getCurrentPrintJob():print({space(7),x},.t.),zeile++,.t. })
      endif
      ?

      /* Aufsummieren */
      M_Menge += INNER->Menge * faktor
      M_Geliefges += INNER->GeliefGes * faktor
      M_Ausschuss += INNER->Ausschuss * faktor
      M_Rest += Max(INNER->Menge - INNER->GeliefGes,0) * faktor
    endif

    skip
    Stop:=stop_key()
  enddo // eof()
  ? '--------------------------------------------------------------------------------------------'
  ? space(16),str(M_Menge,9,2),space(5),str(M_Ausschuss,9,2),str(M_GeliefGes,9,2),str(M_Rest,7,0),;
    EINHEIT->Text

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/*
 * Generiert PDF mit Artikel mit neg. Verf�gbarkeit (ARTIKEL->disponiert)
   und schickt Ergebnis per Email an Miki
*
*   verwendet printBuffer als Hilfskonstrukt zum sp�teren Druck nach Pr�fung
*   s. mystd.ch
*   #command ->?  [<list,...>] => printBuffer:addTextLine( { <list> } )
*
*   offene Bestellungen werden mit ArtBestellListe() gedruckt
*/
FUNCTION NegVerfueg(selArt,mArtNr,VVGListe,bed,orgMindBest,orgDetails,alleMitBedarf,sortKW)
LOCAL GetList:={}
LOCAL Stop:=.f.,body:="",M_KundNr:="",Art
LOCAL alleListen:={}, items:={}, item
LOCAL Ausgabe:="BS"
LOCAL von, bis
LOCAL merk_order, empf
LOCAL auto:=(selArt != nil), subject, myLoop:=.t.
LOCAL merkeEArtikel:=hb_Hash(), mindBest,details, merkIndex

LOCAL reservierungen, reserv_unsorted, zeile

  default VVGListe:=.f.
  default bed:={|| .t.}
  default orgMindBest:="N"
  default orgDetails:="J"
  default alleMitBedarf:="N"
  default sortKW:="J"

  trouble("crontab", "Negverfueg 1" )
  Umgebung(WRITE_ALL)

  if ! open("Artikel","Einheit","BesPost","BesAus","Inner","AufAus","AufPost","Kunden","AvPost")
    Umgebung(LOAD)
    return NIL
  endif

  if auto
    if mArtNr == NIL
      select Artikel
      go bottom
      bis:=ARTIKEL->ArtNr
      go top
      von:=ARTIKEL->ArtNr
    else
      ARTIKEL->(dbseek( mArtNr ))
      von:=ARTIKEL->ArtNr
      bis:=ARTIKEL->ArtNr
      Drucker("BS")
    endif

  else
    M_KundNr:=space(len(KUNDEN->KundNr))

    cls
    Titel("Artikel Liste - Neg. Verf�gbarkeit")

    if empty( bis:=von_bis("Artikel",,6) )
      Umgebung(LOAD)
      RETURN NIL
    endif
    von:=ARTIKEL->ArtNr
    selArt:=" "

    @ 10,18 to 20,45
    @ 11,20 say "Artikel-Art..........:" get selArt picture "!";
      when Message('@Leer@=Alle @B@eisst. @D@ienstl. @E@inkaufs-Art. @F@ert.-Art. @M@ontage '+;
      '@T@ext @W@erkzeug E@x@-Artikel') valid selArt $ ALLE_ARTIKEL_ARTEN+" "

    @ 13,20 say "Bestell Details......:" get orgDetails picture "!" when;
      Message('Bestell Details anzeigen?  (@J@/@N@)') valid orgDetails $ "JN"

    @ 15,20 say "Kunden-Nr.:" get M_KundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.t.,.f.) } when Message("Kunden-Filter eingeben.   "+;
      "@Lerr@=Alle   @F12@=Auswahl")

    @ 17,20 say "Alle mit Bedarf......:" get alleMitBedarf PICTURE "!" valid alleMitBedarf$"JN";
      when Message("Alle Artikel mit Auftragsbestand anzeigen.")

    @ 19,20 say "Sortier nach KW......:" get sortKW PICTURE "!" valid sortKW$"JN";
      when Message("Liste nach KW sortieren.")

    Read
    If ABBRUCH .or. ! druck_BS() // Abbruch
      Umgebung(LOAD)
      RETURN NIL
    endif

    if empty(selArt) // alle selektiert
      selArt:=strTran( ALLE_ARTIKEL_ARTEN , "W" , "" ) // ausser Werkzeug
    endif

  endif

  M->specialZeige:={}
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Message("Liste wird erstellt.   Bitte warten...")

  select Aufpost
  index on AUFPOST->ArtNr+AUFPOST->AufNr tag TEMP_IND4 TEMPORARY ADDITIVE for ;
    AUFPOST->AufArt $ "KRVBD" .and. AUFAUS->erledigt<>"J" .and. AUFAUS->AufArt<>"G" .and.;
    (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->Erledigt=="O") .and. AUFPOST->AufArt == AB_DISPO_ARTIKEL

  merkIndex:=AUFPOST->(OrdSetFocus(1))
  set relation to AUFPOST->AufNr into Aufaus

  select BesPost
  BESPOST->(OrdSetFocus(2))
  set rela to BESPOST->BestNr into BesAus

  INNER->(OrdSetFocus(2))

  select Artikel
  set rela to ARTIKEL->ME into Einheit

  trouble("crontab", "Negverfueg 2" )

  reserv_unsorted:=aEval(copyArtReserv(), {|reserv| ! empty(reserv:AlternZu)})
  reservierungen:=aSort(reserv_unsorted,,, {|r1,r2| r1:Artnr<r2:Artnr .or.;
    (r1:Artnr==r2:Artnr .and. r1:AlternZu<r2:AlternZu) })

  for each Art in selArt

    trouble("crontab", "Negverfueg 3: " + art )

    mindBest:=orgMindBest
    details:=orgDetails

    merkeEArtikel:=hb_Hash()
    select Artikel
    if Auto .and. mArtNr == NIL
      if VVGListe
        Drucker("PDF","Miki-Sonderartikel-Bedarf")
      else
        Drucker("PDF","ArtikelVerfueg-"+art)
      endif
    endif

    if mArtNr == NIL
      index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        for ARTIKEL->Art $ art .and. ARTIKEL->ArtNr<>ZEIT_ARTIKEL .and. ;
        Max(ARTIKEL->LageBest,0) - Max(ARTIKEL->disponiert,0) < ARTIKEL->MinbestI .and. ;
        ( empty(M_KundNr) .or. M_KundNr==KDNR_LEER .or. ARTIKEL->KONSIGKDNR == M_KundNr ) .and.;
        ARTIKEL->ArtNr >= von .and. ARTIKEL->ArtNr <= bis .and. eval(bed)
    else
      index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        ffor ARTIKEL->ArtNr == mArtNr .and. ARTIKEL->Art $ art .and. ARTIKEL->ArtNr<>ZEIT_ARTIKEL
    endif

    myLoop:=.t.
    do while myLoop
      items:={}
      go top
      do while .not. ARTIKEL->(eof()) .and. ! stop
        @ maxrow(),0 say ART+" "+ARTIKEL->ArtNr

        // Ausnahme: Fracht, Phoenix Artikel == VPE Regalteiler und Mischungen (999 AV Reihenfolge)
        if martnr == NIL .and. ;
          (len(alltrim(ARTIKEL->ArtNr)) <= FRACHT_LAENGE .or. ;
          left(ARTIKEL->ArtNr,len(PHOENIX_OBER_ARTIKEL)) == PHOENIX_OBER_ARTIKEL .or. ;
          (ARTIKEL->Reihenfolg == INNER_ANS_ENDE .and. getArtikelArt() <> "E") .or. ;
          alltrim(ARTIKEL->ArtNr)==ANGEBOTS_ARTIKEL)
          skip
          loop
        endif

        // Ausnahme E-Artikel ohne Preis z.B. 002000 WKZ Kosten
        if getArtikelArt()=="E" .and. ARTIKEL->EkPr == 0
          skip
          loop
        endif

        // pr�fe 1. Bewegung bei der Lagerbestand ins Minus geht
        // if trim(ARTIKEL->ArtNr)=="20500105"
        // altd()
        // endif
        item:=NegVerfuegItem():new(ARTIKEL->ArtNr)
        item:oAI:=ArtikelInfo():new()
        item:bewUnterNull:=item:oai:lagerBestandUnterNull(,,mindBest=="J")
        if item:bewUnterNull == NIL
          // bei Anzeige am BS STRG-F4 immer anzeigen oder falls alleMitBedarf
          if martNr <> NIL .or. alleMitBedarf=="J"
            item:bewUnterNull:=Bewegung():new()
          endif
        endif
        if Art $ "ED"
          // 27.8.2015: wenn bereits offene Bestellungen vorhanden
          // sind, dann gilt Mind.Bestand nicht mehr
          // externe Bestellungen
          if item:bewUnterNull != NIL .AND. (mindBest=="J")
            SELECT BesPost
            merk_order:=BESPOST->(indexord())
            // Nur offene Bestellungenpr�fen
            index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
              for BESPOST->ArtNr=ARTIKEL->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes ;
              .and. BESAUS->Erledigt<>"J"

            if (BESPOST->(OrdKeyCount()) > 0)
              item:bewUnterNull:=NIL // we bail out
            endif

            BESPOST->(OrdSetFocus(merk_order))
            BESPOST->(OrdDestroy(TEMP_INDEX))
            select Artikel
          endif
        endif

        if item:bewUnterNull == NIL
          skip
          loop
        endif

        // spezial behandlung in 2 Listen gesplittet, mit und ohne Mind.Bestand
        // Artikel die in der 1. Liste ohne Mind.Bestand auftauchen
        // sollen nicht in der 2. auftauchen
        if Art $ NEG_VERF_MINDEST_BESTAND_ART
          if mindBest=="N"
            hb_HSet( merkeEArtikel , ARTIKEL->ArtNr , .t. )
          else // mit Mind.Bestand
            if hb_HHasKey( merkeEArtikel , ARTIKEL->ArtNr )
              skip
              loop
            endif
          endif
        endif

        aadd(items, item)

        select Artikel
        skip

        Stop=stop_key()
      enddo // Artikel loop

      // sortiere nach KW und drucke Liste
      if sortKW=="J"
        items:=aSort(items,,,{ |a,b| a:compareKW(b) })
      endif
      zeile:=negverfDruck(art, items, martnr, details, auto, mindBest, VVGListe, zeile, merkIndex)

      // Special Case: E-Artikel 2 Listen auf einer (mit und ohne Mind.Bestand)
      if art $ NEG_VERF_MINDEST_BESTAND_ART .and. mindBest == "N"
        // jetzt 2. Liste basierend auf MindestBestand
        mindBest:="J"
        details:="N"
      else
        myLoop:=.f.
        zeile:=0
      endif

    enddo // myLoop f�r 2. E-Liste

    trouble("crontab", "Negverfueg 4" )

    // jetzt 3. Liste f�r alternat. Material, if applicable
    ARTIKEL->(OrdSetFocus( 1 )) // ArtNr ohne Filter
    negVerfAltMat( art , mArtNr, reservierungen)

    if auto
      getUser():getCurrentPrintJob():endDoc()
      subject:="Neg. Verf�gbarkeits "
      if len(items) > 0
        if getUser():getCurrentPrintJob():pdfFullFileName<>NIL
          aadd(alleListen,getUser():getCurrentPrintJob():pdfFullFileName)
        endif
        body+=subject+art+"-Artikel gepr�ft -> siehe Anhang."+MY_CR+MY_LF
      else
        body+=subject+art+"-Artikel gepr�ft -> okay."+MY_CR+MY_LF
      endif

      getUser():setCurrentPrintJob(NIL)
    endif

  next

  // automat. generiert (crontab) -> Email an H. Weiland
  trouble("crontab", "Negverfueg 5" )
  if VVGListe
    // NOP, no email etc.
  elseif auto .and. mArtNr == NIL

    empf = trim(getProperty("Miki.mindbest.emails",MAIN_EMAIL))
    subject:="Neg. Verf�gbarkeits-Liste vom: "
    if len(alleListen)==0
      email(empf,subject + dtoc(getUser():date)+" okay.",body)
    else
      email(empf,subject + dtoc(getUser():date),body,alleListen)
    endif
  else // manuelle Liste -> ausdrucken

    getUser():getCurrentPrintJob():confirmPDF:=.t.
    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(NIL)

  endif

  trouble("crontab", "Negverfueg 6" )
  Umgebung(LOAD)

RETURN alleListen
  /* EOP */

/** drucke negative Verf�gbarkeits-Liste aus bzw. in Datei */
static;
  function negverfDruck(art, items, martnr, details, auto, mindBest, VVGListe, zeile, merkIndex)
LOCAL seite:=1, item, current, i
LOCAL M_ArtNr, Bedarf, BaugrBest, bestandText, Stop:=.f., printBuffer
LOCAL sumInt:=0 , sumBest:=0

  // f�r alte Listen-Typ
LOCAL lageBest,dispo
LOCAL tempText, tempValue, rahmAb,mindestBest, aInnerNrs

  default zeile:=0 // standard ist neue Liste auf neue Seite, Ausnahme 2. E-Liste

  current:=1
  do while current<=len(items)
    // 2. E-Liste mit Leerzeilen am Anfang
    if ( art $ NEG_VERF_MINDEST_BESTAND_ART .and. mindBest == "J" )
      ?
      ?
    endif

    if VVGListe
      ? "Miki-Plastik Bedarf Sonderartikel  vom:",getUser():date,space(45),"Seite",str(seite,3)
    else
      if mindBest=="J"
        ? COLOR_RED,"Mindest-Bestands-Liste '"+art+"'",COLOR_DEFAULT,"       vom:",getUser():date,;
          space(45),"Seite",str(seite,3)
      else
        ? "Neg. Verf�gbarkeits-Liste '"+art+"'     vom:",getUser():date,space(45),"Seite",;
          str(seite,3)
      endif
    endif
    ? "Art.Nr.      Bezeichnung                    ME    Lager-        Baugr.-  Auftrags-   "+;
      "Verf�gbar    KW  AB-Nr"
    ? "                                                  Bestand       Bestand    Bestand         "+;
      "                "
    ? "=========================================================================================="+;
      "================="
    _____fixedHeader_____

    do while current<=len(items) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      // drucke nach Seitenumbruch?
      if printBuffer<>NIL .and. printBuffer:getNumLines() > 0
        zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)
      endif
      printBuffer:=printBuffer():new()

      item:=items[current]
      ARTIKEL->(dbseek( item:artnr ))

      bedarf:=Max(ARTIKEL->LageBest,0) - ARTIKEL->disponiert // hier ohne Mind.Bedarf
      baugrBest:=getOberBaugruppenBestand(ARTIKEL->ArtNr, getArtikelArt() == "F" )

      // if trim(ARTIKEL->ArtNr)=="2300761"
      // altd()
      // endif

      if abs(ARTIKEL->LageBest) < 1 .and. ARTIKEL->LageBest <> 0
        bestandText:=transstr(ARTIKEL->LageBest,9,2)
      else
        bestandText:=transstr(ARTIKEL->LageBest,9,0)
      endif
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,EINHEIT->Text,bestandText,;
        transstr(baugrBest[1],7,0),if(baugrBest[1] > 0,"("+str(baugrBest[2],3)+")",space(5)),;
        transstr(ARTIKEL->disponiert,10,0),transstr(bedarf,11,0)
      ?? space(0),item:bewUnterNull:kw,item:bewUnterNull:aufnr

      if art $ "FM"
        tempText:=item:oai:getInnerNummern()
        if len(tempText) > 0
          aInnerNrs:=lineWrap(tempText,25)
          ?? "(" + aInnerNrs[1]
          for i:=2 to len(aInnerNrs)
            ? space(106),aInnerNrs[i]
          next
          ?? ")"
        endif
      endif

      // drucke Honsel-Artnr, if applicable
      if ! realEmpty(ARTIKEL->HartNr)
        if ARTIKEL->MinbestI > 0
          ?? "Mind.Bestand:",alltrim(transstr( ARTIKEL->MinbestI , 11,0 ))
        endif
        ? space(len(out(ARTIKEL->ArtNr))),"Honsel-Nr:",ARTIKEL->HartNr
      else
        if ARTIKEL->MinbestI > 0
          ?? "Mind.Bestand:",alltrim(transstr( ARTIKEL->MinbestI , 11,0))
        endif
      endif

      M_ArtNr:=ARTIKEL->ArtNr

      if ART <> "F" // alter Listentyp

        // Kunden-Bestellungen (Liefertermin extern), nur Rahmen AB
        select Aufpost
        merkIndex:=AUFPOST->(OrdSetFocus(merkIndex))
        dbseek(M_ArtNr)
        rahmAb:=0
        do while .not. AUFPOST->(eof()) .and. ! stop .and. AUFPOST->ArtNr=M_ArtNr
          rahmAb += AUFPOST->Menge-AUFPOST->GeliefGes
          skip
          Stop=stop_key()
        enddo // AufPost
        merkIndex:=AUFPOST->(OrdSetFocus(merkIndex))

        select Artikel

        // Drucke Posten der einzelnen Bestellungen
        // externe Bestellungen
        // interne Bestellungen
        if details == "J" .or. auto
          printBuffer:leftMargin:=10
          ArtBestellListe(printBuffer,@SumBest,@SumInt,abs(bedarf),item:bewUnterNull:kw)
        else
          // use dummy print buffer, wir brauchen die Berechnung
          ArtBestellListe(printBuffer():new(),@SumBest,@SumInt,abs(bedarf),item:bewUnterNull:kw)
        endif

        lageBest:=Max(ARTIKEL->LageBest,0)
        mindestBest:=ARTIKEL->MinBestI
        dispo:=ARTIKEL->disponiert - RahmAb

        // FIX 18.9.2013, pr�fe mit neuer Axe Zeit ob Artikel gedruckt wird oder nicht
        // aber erst wenn alle innerbetr. Auftr�ge mit KW laufen
        // merkeUnterNull:=ArtikelInfo():new():lagerBestandUnterNull()

        // ausdrucken? -> checken ob zu wenige Artikel intern bestellt
        // Hinweis: E schon umgestellt, der Rest noch nicht
        if art $ "ED" .or. ;
          (art$"BD" .and. dispo>LageBest+sumBest-mindestBest) .or.;
          (art$"X" .and. dispo>0 .and. dispo>LageBest+sumInt+sumBest)

          if sumInt>0 .or. sumBest>0
            tempValue:=LageBest+sumBest-dispo
            if tempValue < 0
              tempText:=alltrim(transstr(tempValue,11,0))
              ->? space(63-len(tempText)),"Fehlbestand:", tempText,COLOR_DEFAULT
              ->? space(63-len(tempText)),replicate("=",13+len(tempText))
              ->?

              // drucke details
              if details == "J"
                // oAI:=ArtikelInfo():new() # FIXME: obsolete?
                printBuffer:leftMargin:=3
                item:oAI:getLagerBestandDetails( printBuffer )
                printBuffer():addNewLine()
              endif
            endif
          endif
        endif

      else // ART=="F" , neuer Listen-Typ (Achse Zeit inner / AB)

        if details == "J" .and. (! empty(MArtNr) .or. item:bewUnterNull <> NIL)
          printBuffer:leftMargin:=3
          printBuffer():addNewLine()
          item:oAI:getLagerBestandDetails( printBuffer )
          printBuffer():addNewLine()
        endif

      endif
      current++

      // drucke printbuffer wenn er auf die Seite passt
      if zeile + printBuffer:getNumLines() < DRUCKER->laenge - LISTE->Unt_Rand
        zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)
        printBuffer:=printBuffer():new()
      endif

    enddo // Blattl�nge / items
    if current<len(items) .or. zeile + 6 > DRUCKER->laenge - LISTE->Unt_Rand
      Zeile:=FormFeed(Zeile,Seite)
      Seite=Seite+1
    endif

  enddo

return zeile
/** eof */

static function negVerfAltMat( art , mArtNr , reservierungen)
LOCAL Count:=0
LOCAL zeile:=0, reserv, x
LOCAL currentArtNr,currentAltNr, gesMenge

  for x:=1 to len(reservierungen)
    reserv:=reservierungen[x]
    ARTIKEL->(dbseek( reserv:AlternZu ))
    if getArtikelArt() $ art .and. ;
      ( mArtNr == NIL .or. mArtNr == reserv:AlternZu .or. mArtNr == reserv:ArtNr )
      // summiere je ArtNr
      currentArtNr:=reserv:ArtNr
      currentAltNr:=reserv:AlternZu
      gesMenge:=0
      do while currentArtNr == reserv:ArtNr .and. currentAltNr == reserv:AlternZu .and.;
        x < len(reservierungen)
        gesMenge += reserv:Menge
        x++
        reserv:=reservierungen[x]
      enddo
      if count == 0
        ?
        ?
        ? "Alternatives Material geplant:"
        ? "=============================="
      endif
      count++
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,EINHEIT->Text,transstr(ARTIKEL->LageBest,9,0)
      ? "->"
      ARTIKEL->(dbseek( currentArtNr ))
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,EINHEIT->Text,transstr(ARTIKEL->LageBest,9,0),;
        space(13),str(GesMenge,10,0)
      ?
    endif
  next
return zeile


/*
 * Zeigt die Paletten an, die die aktuelle Spedition in den letzten 5 Jahren bekommen hat
*/
PROCEDURE SpeditPaletten( details )
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f., mYear, mArtNr
LOCAL paletten:=HB_ATokens( getProperty("Miki.palette.artnr","") , ":" )
LOCAL summe, erst

  Umgebung(WRITE_ALL)

  if ! open("RechPost","RechAus","Artikel")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select RechPost
  set rela to RECHPOST->RechNr into RechAus

  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  index on str(year(RECHAUS->ReaDat),4)+RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    RECHAUS->SpedNr == SPEDIT->SpedNr .and. year(RECHAUS->ReaDat) > year(getUser():date) - 5 .and.;
    aContains( paletten , alltrim(RECHPOST->ArtNr))

  Drucker("BS")

  ? "Paletten-Lieferung an ", SPEDIT->SpedNr,SPEDIT->Kurzname
  ? '--------------------------------------------------------------------'
  ? 'Jahr  Art.Nr.  Bezeichnung                               Menge'
  ? '--------------------------------------------------------------------'
  _____fixedHeader_____

  go top
  do while .not. RECHPOST->(eof()) .and. ! stop
    mYear:=year(RECHAUS->ReaDat)
    erst:=.t.
    do while .not. RECHPOST->(eof()) .and. ! stop .and. mYear == year(RECHAUS->ReaDat)
      mArtNr:=RECHPOST->ArtNr
      summe:=0
      do while .not. RECHPOST->(eof()) .and. ! stop .and. mYear == year(RECHAUS->ReaDat) ;
        .and. mArtNr == RECHPOST->ArtNr
        summe += RECHPOST->gelief
        if details
          ? RECHPOST->RechNr,RECHAUS->ReaDat,RECHAUS->KundNr,RECHAUS->KurzName,;
            str(RECHPOST->Gelief,9,0),"St�ck"
        endif
        skip
      enddo

      // jetzt drucken
      if summe > 0

        if details
          ? space(55),"------------"
        endif

        if erst
          ? str(mYear,4)
          erst:=.f.
        else
          ? space(4)
        endif
        ARTIKEL->(dbseek( mArtNr ))
        ?? ARTIKEL->Artnr,ARTIKEL->Bez1,space(7),str(summe,8,0),"St�ck"
        if ! empty( ARTIKEL->Bez2)
          ? space(4),space(len(ARTIKEL->Artnr)),ARTIKEL->Bez2
        endif

        if details
          ?
        endif

      endif

    enddo

  enddo

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/*
* ermoeglicht das rekursive der Neg.Verf�gbarkeitsliste */
PROCEDURE rekNegList(ZeilenText , ZeigeData)
LOCAL MartNr, MArt
LOCAL aktRec:=ARTIKEL->(recno())

  Umgebung(WRITE_ALL)

  Message("Liste wird erstellt.   Bitte warten...")

  if open("AvPost","AvAus","Artikel")

    AVPOST->(dbclearRelation())
    AVAUS->(dbclearRelation())

    ignore ZeilenText

    MArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]
    ARTIKEL->(dbseek( mArtNr ))
    mArt:=getArtikelArt()
    ARTIKEL->(dbgoto( aktRec ))

    NegVerfueg(mArt,mArtNr)

  endif

  Umgebung(LOAD)

return
  /** eop */


/*
  * liefert alle Beistellteile f�r jeden Artikel mit Beistellteilen auf -> Fa. Honsel
  * s. auch BeistellArtikel()
*/
PROCEDURE BeiArtDetails()
LOCAL seite:=0, zeile:=0, GetList:={},laenge
LOCAL ant
LOCAL export:="Beistellteile"
LOCAL aktRec, klagKundNr:=KDNR_VVG, mArtNr, mBez1,mBez2, mHartNr

  Umgebung(WRITE_ALL)

  cls
  Titel(" Beistellteile je Artikel - Liste drucken ")


  if ! open( "Artikel" , "AvPost","Einheit","BeisTemp")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit
  select Beistemp
  set relation to BEISTEMP->ArtNr into Artikel

  // Ausgabe ausw�hlen & starten
  ant:=Message("Ausgabe auf @D@rucker, @B@ildschrirm oder @P@DF Datei (@D@/@B@/@P@) ?", "BDP","B")
  if ABBRUCH
    cls
    Umgebung(LOAD)
    RETURN
  endif
  do case
  case ant=="D"
    Drucker("ON")
  case ant=="P"
    if (export:=openFileDialog(WRITE,getUser():exportPATH(),export,"pdf",nil)) == NIL
      cls
      Umgebung(LOAD)
      RETURN
    endif

    Drucker("PDF",getFileName(export, .t.), getUser():exportPATH(), .f.,PDF_YES_CONFIRM)
  otherwise
    Drucker("BS")
  endcase
  Laenge:=DRUCKER->Laenge

  select Artikel
  loca for ARTIKEL->Art $ "MF" .and. len(alltrim(ARTIKEL->ArtNr)) > FRACHT_LAENGE
  do while ! ARTIKEL->(eof())

    // extrahiere Beistellteile rekursiv
    aktRec:=ARTIKEL->(recno())
    mArtNr:=ARTIKEL->ArtNr
    mBez1:=ARTIKEL->Bez1
    mBez2:=ARTIKEL->Bez2
    mHartNr:=ARTIKEL->HartNr

    select Beistemp
    zap
    BeistellRek(mArtNr,1,NIL,klagKundNr)

    /** ausdrucken ? */
    select BeisTemp
    go top
    if ! BEISTEMP->(eof())
      Message("@"+out(mArtNr)+"@Liste wird erstellt.   Bitte warten...")

      ? ZEIGE_ARTNR+out(mArtNr),mBez1,mHartNr
      ? space(len(out(mArtNr))),mBez2
      ?

      select BeisTemp
      do while ! BEISTEMP->(eof())
        ? "Art.Nr     Bezeichnung                          Menge ME  Honsel-Nr.          Kd.Nr."
        ? replicate("=",86)

        do while Zeile<laenge-LISTE->Unt_Rand .and. ! BEISTEMP->(eof())
          ARTIKEL->(dbseek(BEISTEMP->ArtNr))
          ? ZEIGE_ARTNR+out(BEISTEMP->ArtNr),ARTIKEL->Bez1,BEISTEMP->Menge,EINHEIT->Text,;
            ARTIKEL->HartNr,ARTIKEL->KonsigKDNr
          skip
        enddo
        ? replicate("=",86)
        Zeile:=FormFeed(Zeile,Seite++)
      enddo
    endif
    select Artikel
    ARTIKEL->(dbgoto( aktRec ))
    cont
  enddo
  Drucker("Off")

  cls
  Umgebung(LOAD)
return
/** eop */

CLASS NegVerfuegItem

DATA artNr
DATA bewUnterNull
DATA oAI

METHOD new()
METHOD compareKW(other)

ENDCLASS

METHOD new(artNr)
  self:artNr:=artnr
RETURN self

/** compare for sorting with other NegVerfuegItem */
METHOD compareKW(other)
LOCAL result
  result:=kwKleiner(self:bewUnterNull:kw, other:bewUnterNull:kw) > 0
return result


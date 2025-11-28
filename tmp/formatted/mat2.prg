/* Modul Material.prg
*
* Alles zu Material 2. Teil
*/
#include "miki.ch"
#include "zeige.ch"

#define UR 8 // unterer Rand f. Listen
#define TRENN "I"

PROCEDURE Mat2_erfassen()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  /* �ffnen der ben�tigten Dateien */
  if ! open("AufPost","AufAus","AvPost","Artikel" ,"Manuell" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  /* Relationen setzen */
  select AufPost
  set relation to AUFPOST->aufnr into Aufaus,;
    to AUFPOST->ArtNr into avpost,;
    to AUFPOST->ArtNr into Artikel
  select Manuell
  set relation to MANUELL->ArtNr into Artikel


  Titel("Material-Datei Manuell erfassen")

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer dern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z" // Kopf

  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Artikel-Nr."
  aSpalte[EDIT_MASKE]:="@K!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf en
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT ]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf en
  aSpalte:=e_fill() // initialisieren

  // Bedarf
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Rest-Liefermenge"
  aSpalte[EDIT_MESSAGE]:="Liefermenge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf en
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  aSpalte[EDIT_NAME]:="KW"
  aSpalte[EDIT_TITEL]:="KW"
  aSpalte[EDIT_POS_X]:=3
  aSpalte[EDIT_MASKE]:="99/99"
  aSpalte[EDIT_MESSAGE]:="Kalenderwoche eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf en
  aSpalte:=e_fill() // initialisieren

  // Kalenderwoche
  aSpalte[EDIT_NAME]:="trim(text)"
  aSpalte[EDIT_TITEL]:="Auftrag"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MASKE]:=replicate("X",20)

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf en
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

  /*** Eingabe / Drucke ****/
  Edit(aFelder,aKopf)

  close data
RETURN
/* EOP Mat_erfassen */


/* PROCEDURE Mat2_Kz
*
* erstellt manuelle Material-Bedarfsdatei anhand von Mat.Kz und Auftragsposten
*
*
*/
PROCEDURE Mat2_Kz
LOCAL Mat_Kz,noch_zu_liefern
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()
LOCAL GetList:={}
LOCAL i,summe,fertig:=.f.,meng,kw,feld,feldmeng

  if ! open("Manuell","Artikel","AufPost","AufAus","Mat_KZ")
    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  select AufPost
  set relation to AUFPOST->ArtNr into Artikel, to AUFPOST->AufNr into AufAus
  /* hier Manuell-Datei mit Index */
  select Manuell
  zap
  index on MANUELL->ArtNr+MANUELL->KW tag TEMP_INDEX TEMPORARY ADDITIVE

  cls
  Titel("Material-Bedarfs-Datei erstellen: Mat.Kz")

  Mat_KZ:=space(len(ARTIKEL->MatKz))
  Message("Gew schte Material-Kz eingeben.     @F12@=Hilfe   @Leer@=alle    @ESC@=Ende")
  @ 10,20 say "Material-Kz:" get Mat_KZ Picture MAT_PICT;
    valid { |oGet| check(oGet,"Mat_KZ",.f.,.f.) }
  read

  if ! ABBRUCH
    Message("Material-Bedarfs-Datei wird erstellt.      Bitte warten...")
    @ 12,20 say "Auftrag:"
    select Manuell
    zap
    select AufPost
    set filter to (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->Erledigt=="O") .and. ;
      len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE;
      .and.(!deleted()).and.AUFAUS->Aufart$"RVD" .and. AUFAUS->erledigt<>"J"
    go top
    do while ! eof()
      if ARTIKEL->MatKz==Mat_KZ

        @ 12,31 say AUFPOST->AufNr
        noch_zu_liefern:=(AUFPOST->Menge - AUFPOST->GeliefGes)
        if noch_zu_liefern > 0
          i:=1
          summe:=AUFPOST->GeliefGes
          fertig:=.f.
          kw:=space(len(AUFPOST->Kw))
          do while ! fertig .and. i<=6
            // kw je Posten
            if ! empty(AUFPOST->Kw)
              kw:=AUFPOST->Kw
              Meng:=noch_zu_liefern
              noch_zu_liefern:=0
              fertig:=.t.
            else
              // kw aus Auftragskopf
              Feld:="AUFAUS->KW"+str(i,1)
              FeldMeng:="AUFAUS->Meng"+str(i,1)
              if empty(&Feld) .or. alltrim(&Feld)=="/"
                if &(FeldMeng) > 0
                  kw:="??/  "
                else
                  // fertig:=.t.
                  i++
                  loop
                endif
              endif

              // noch Restlieferungen zu best. Termin
              if summe <= &(FeldMeng)
                kw:=&(Feld)
                meng:=&(FeldMeng)-summe
                noch_zu_liefern-=meng
                summe:=0
              else
                summe-=&(FeldMeng)
                i++
                loop
              endif
              i++
            endif

            // nehme akt. Jahr falls kein Jahr angegeben
            if empty(right(kw,2))
              kw:=left(kw,3)+right(str(year(getUser():date),4),2)
            endif
            SELECT Manuell
            dbseek(AUFPOST->ArtNr+Kw)
            if eof()
              ADD_REC(5)
              REPLACE MANUELL->ArtNr WITH AUFPOST->ArtNr
              REPLACE MANUELL->KW WITH KW
            else
              rec_lock(0)
            endif
            REPLACE MANUELL->Menge WITH MANUELL->Menge + Meng
            REPLACE MANUELL->Text WITH trim(MANUELL->Text)+AUFPOST->AufNr
            SELECT AufPost
          enddo
        endif

        // noch RestMenge ohne Liefertermin ?
        if noch_zu_Liefern > 0
          SELECT Manuell
          kw:="??/"+right(str(year(getUser():date),4),2)
          dbseek(AUFPOST->ArtNr+kw)
          if eof()
            ADD_REC(5)
            REPLACE MANUELL->ArtNr WITH AUFPOST->ArtNr
            REPLACE MANUELL->KW WITH KW
          else
            rec_lock(0)
          endif
          REPLACE MANUELL->Menge WITH MANUELL->Menge + noch_zu_liefern
          REPLACE MANUELL->Text WITH trim(MANUELL->Text)+AUFPOST->AufNr
          SELECT AufPost
        endif

      endif
      skip
    enddo

  endif


  /** suche Artikel, die auch in anderen Mat.Kz. mit AuftragsBestand vorkommen ! */
  // Protokoll(INIT_P,"Check Artikel-AB und LW-Bestand !")
  // select Manuell
  // go top
  // do while ! eof()
  // MerkArtNr:=MANUELL->ArtNr
  // summe:=0
  // Auftrag:=""
  // do while ! eof() .and. MANUELL->ArtNr==MerkArtNr
  // summe+=MANUELL->Menge
  // Auftrag+= trim(MANUELL->Text)
  // skip
  // enddo
  // ARTIKEL->(dbseek(MerkArtNr))
  // if ARTIKEL->Disponiert<>summe
  // Protokoll(PROTOKOLL,MerkArtNr+str(ARTIKEL->disponiert,10,2)+str(summe,10,2)+Auftrag)
  // endif
  // enddo
  // Protokoll(PRINT_P)

  /* kopiere Manuell-Datei: Reihenfolge ohne Index ! */
  select Manuell
  copy to (temp_datei)
  zap
  appe from (temp_datei)

  cls
  close data

  ferase( (temp_Datei ) )

RETURN
/* EOP */



/* PROCEDURE  bed_datei_erstellen
*
* Parameter: Datei    : akt. Datei (Manuell.dbf)
*
* erstellt anhand der Manuell.dbf den benoetigten Mat.Bedarf
* und schreibt diesen -> M_Mehrf.dbf
*
* der richtig akt. Auftragsbestand (ARTIKEL->disponiert) wird vorausgesetzt!
* nur die Anfrage-Menge wird hochgezaehlt !
*
*
*/
PROCEDURE bed2_Datei_erst()
LOCAL inclBaugr:=" "

  select M_MEHRF
  zap

  // inclBaugr:=Message("Baugruppen aufl�sen ? Tiefe (@0-9@,@Leer@=alle)","0123456789 �")
  if inclBaugr==chr(255)
    inclBaugr:=" "
  endif

  Message("Material-Bedarf wird bestimmt.      Bitte warten...")
  /* vorkalkulieren, H�ufigkeit bestimmen */
  select MANUELL
  go top
  do while ! eof() .and. ! ABBRUCH
    bed2_rek(MANUELL->ArtNr,MANUELL->Menge,inclBaugr,0)
    select MANUELL
    skip
  enddo
  Message("Material-Bedarf wurde bestimmt.")
RETURN
/* EOP bed_Datei_erst() */


/* PROCEDURE bed_rek()
*
* ermittelt rekursiv den Mat.Bedarf der uebergeben Stk.Liste !
*
* geht bis zur angegeben Tiefe !
*/
PROCEDURE bed2_rek(M_artNr,M_Menge,inclBaugr,tiefe)
LOCAL merk_Satz
LOCAL Restbedarf,verfuegbar

  ARTIKEL->(dbseek(M_ArtNr))

  select M_MEHRF
  dbseek(M_ArtNr)
  if M_MEHRF->(eof())
    add_rec(0)
    replace M_MEHRF->ArtNr with M_artNr
    // replace M_MEHRF->Baugruppe with ARTIKEL->Baugruppe
    replace M_MEHRF->Reihenfolg with ARTIKEL->Reihenfolg
  else
    rec_lock(0)
  endif
  verfuegbar:=max(max(ARTIKEL->LageBest,0) - ARTIKEL->disponiert-M_MEHRF->Menge,0)
  RestBedarf:=max(M_Menge - verfuegbar,0)
  replace M_MEHRF->Menge with M_MEHRF->Menge+M_Menge
  replace M_MEHRF->Anzahl with M_MEHRF->Anzahl+1
  dbcommit()
  dbunlock()

  /* checke ob Unterartikel vorhanden */
  if (empty(inclBaugr) .or. tiefe<=val(inclBaugr)) .and. ;
    ARTIKEL->Art $ STKLIST_ARTIKEL
    select AvPost
    seek M_ArtNr+"M"
    do while ! eof() .and. M_ArtNr==AVPOST->AvNr .and. AvPost->Art="M"
      if AVPOST->Text=="A"
        merk_Satz:=recno()
        bed2_rek(AVPOST->ArtNr, RestBedarf*AVPOST->Menge,inclBaugr,tiefe+1)
        select AvPost
        go (merk_Satz)
      endif
      skip
    enddo
  endif

RETURN

/* Procedure MatKWList
*
* Material - Bedarfs - Liste nach Kalenderwoche
*/
PROCEDURE MatKWList()
LOCAL Zeile:=0 , Seite:=0, i
LOCAL allKW:={}
LOCAL titel

  cls
  Titel("Material-Bedarfs-Liste / KW drucken")


  if ! open( "Artikel" , "M_MEHRF" ,"Manuell" , "AvPost","AufAus","AufPost",;
    "BesPost","Inner","Mat_Man")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  /* ACHTUNG andere order bei Bespot/Inner */
  select Inner
  INNER->(OrdSetFocus(2)) // inner
  select Bespost
  BESPOST->(OrdSetFocus(2)) // bespost

  if ABBRUCH .or. ! druck_BS()
    cls
    close data
    RETURN
  endif

  bed2_datei_erst()

  /** bestimme alle vorkommenden Kalenderwochen */
  select M_MEHRF
  M_MEHRF->(OrdSetFocus(2)) // M_MEHRF
  go top
  do while ! eof()
    aadd(allKW,M_MEHRF->Kw)
    skip
  enddo
  M_MEHRF->(OrdSetFocus(1))

  /* einzelner Bedarf ausdrucken */
  titel:=space(31)+TRENN
  for i:=1 to len(allKw)
    titel+=allKw[i]+space(1)
  next
  titel+="  Bedarf Bestellt"

  select M_MEHRF
  SET RELATION to M_MEHRF->ArtNr INTO Artikel
  go top
  do while ! eof()
    zeile:=0
    Seite++
    ? FETT_AN,titel,FETT_AUS
    ? replicate("-",len(titel))

    do while ! eof() .and. zeile<DRUCKER->Laenge-LISTE->Unt_Rand
      zeile += drucke_KwZeile(allKw)
      ? replicate("-",len(titel))
    enddo
    Zeile:=FormFeed(Zeile,Seite)

  enddo

  Drucker("OFF")

  close data
  cls
RETURN
/* EOP */


/** FUNCTION  drucke_kwZeile()
*
* drucke KW-Zeile je Artikel
*/
FUNCTION drucke_KWZeile(allKw,tiefe)
LOCAL Zeile:=0,i
LOCAL aktArtNr,Zeile1,Zeile2,Zeile3
LOCAL summe,bestellt,aktLgBest,diff
LOCAL aktBez1,aktBez2
  default tiefe:=1

  select M_MEHRF

  i:=1
  summe:=0
  aktArtNr:=M_MEHRF->ArtNr
  aktBez1:=ARTIKEL->bez1
  aktBez2:=ARTIKEL->bez2
  if getArtikelArt()$"FM"
    bestellt:=ARTIKEL->bestInt
  else
    bestellt:=ARTIKEL->bestExt
  endif
  aktLgBest:=ARTIKEL->LageBest

  if valtype(tiefe)=="U" .or. tiefe==0
    // zeile1:=FETT_AN,out(aktArtnr)+"  ",FETT_AUS,space(19)+TRENN
    zeile1:=out(aktArtnr)+"  "+space(19)+TRENN
  else
    // einruecken
    // zeile1:=FETT_AN,"  "+out(aktArtnr),FETT_AUS,space(19)+TRENN
    zeile1:="  "+out(aktArtnr)+space(19)+TRENN
  endif
  zeile2:=aktBez1+TRENN
  zeile3:="Lg."+str(aktLgBest,7,0)+space(20)+TRENN

  // drucke alle KW je Artikel in 1 Zeile
  do while ! eof() .and. aktArtNr==M_MEHRF->ArtNr
    // suche position der akt. KW
    do while i<=len(allkw) .and. kwKleiner(allKw[i],M_MEHRF->Kw)==1
      zeile1+=space(6)
      zeile2+=space(6)
      i++
    enddo

    /** Zwischensumme anzeigen ? */
    zeile1+= str(M_MEHRF->Menge ,6)
    summe+=M_MEHRF->Menge
    zeile2+=+str(aktLgBest-summe,6)
    i++

    /* setze KZ, dass Satz schon gedruckt */
    replace M_MEHRF->gedruckt with "*"

    skip
  enddo

  /** restl. Spalten auffuellen */
  do while i++ <= len(allKw)
    zeile1+=space(6)
    zeile2+=space(6)
  enddo

  diff:=aktLgBest+bestellt-summe
  ? zeile1,TRENN
  ? zeile2,TRENN,str(min(aktLgBest-summe,0),6),str(bestellt,6,0),if(diff<0,str(diff,6),"")
  ? zeile3,space(len(zeile2)-len(zeile3))+TRENN
  if bestellt <> 0
    ?? " ("
    drucke_best(aktArtNr)
    ?? ")"
  endif
RETURN zeile
/* EOF */





/*===============================================================
*
* bis hier hin Variante 3. des Materialbedarfs
* (nach KW)
*
* ab hier Kombination: manuelle Reihenfolge & KW
*
* Procedure Mat_KWMan
*
*/
PROCEDURE Mat_KWMan()
LOCAL Zeile:=0 , Seite:=0,i
LOCAL allKW:={}
LOCAL titel,summe:=0.00,bestellt:=0.00
LOCAL merk_Satz,merk_Reih

  cls
  Titel("Material-Bedarfs-Liste / KW drucken")


  if ! open( "Artikel" , "M_MEHRF" ,"Manuell" , "AvPost","AufAus","AufPost",;
    "BesPost","Inner","Mat_Man")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif
  /* ACHTUNG andere order bei Bespot/Inner */
  select Inner
  INNER->(OrdSetFocus(2)) // inner
  select Bespost
  BESPOST->(OrdSetFocus(2)) // bespost

  if ABBRUCH .or. ! druck_BS()
    cls
    close data
    RETURN
  endif

  bed2_datei_erst()

  /** bestimme alle vorkommenden Kalenderwochen */
  select M_MEHRF
  M_MEHRF->(OrdSetFocus(2)) // m_Mehrf
  go top
  do while ! eof()
    aadd(allKW,M_MEHRF->Kw)
    skip
  enddo
  M_MEHRF->(OrdSetFocus(1))

  /* einzelner Bedarf ausdrucken */
  titel:=space(31)+TRENN
  for i:=1 to len(allKw)
    titel+=allKw[i]+space(1)
  next
  titel+="  Bedarf Bestellt"

  select M_MEHRF
  M_MEHRF->(OrdSetFocus(3))
  SET RELATION to M_MEHRF->ArtNr INTO Artikel

  locate for ! empty(right(M_MEHRF->Reihenfolg,1))
  go top
  do while ! eof()
    zeile:=0
    Seite++
    ? FETT_AN,titel,FETT_AUS
    ? replicate("-",len(titel))

    do while ! eof() .and. zeile<DRUCKER->Laenge-LISTE->Unt_Rand
      select M_Mehrf
      merk_satz:=M_MEHRF->(recno())
      merk_Reih:=M_MEHRF->Reihenfolg
      M_MEHRF->(OrdSetFocus(1))
      go (merk_satz)
      zeile+=rek_druck4(M_MEHRF->ArtNr,0,0,allKw)
      select M_MEHRF
      M_MEHRF->(OrdSetFocus(3))
      go (merk_satz)
      cont
      if merk_Reih<>M_MEHRF->Reihenfolg
        ? space(2)+"--"+merk_Reih+replicate("-",24+len(allkw)*6+20)
        ?
      endif
    enddo
    ?
    ?
  enddo

  Zeile:=FormFeed(Zeile,Seite)

  Drucker("OFF")

  close data
  cls
RETURN
/* EOP */

/* FUNCTION  Rek_druck4()
*
* druckt rekrusive alles benoetigte Material der Baugruppe aus
* 4. Variante  (Kombination)
*
* Rueckgabe: Anzahl der gedruckten Zeilen
*/
FUNCTION rek_druck4(M_ArtNr,tiefe,zeile,allKw)
LOCAL merk_Satz,aktGedr:=.f.
LOCAL verfueg:=0

  M_MEHRF->(dbseek(M_ArtNr))
  /** Artikel an dieser Stelle drucken ? */
  if M_MEHRF->(eof()) .or. (tiefe <> 0 .and. ! empty(M_MEHRF->Reihenfolg))
    RETURN zeile
  endif

  /* drucke akt. Satz aus */
  if empty(M_MEHRF->gedruckt)
    select M_MEHRF
    zeile += drucke_KwZeile(allKw,tiefe)
    aktGedr:=.t.
  endif

  if getArtikelArt() $ STKLIST_ARTIKEL
    /* suche weiteres Material in StkListe */
    select AvPost
    seek M_ArtNr+"M"
    do while ! eof() .and. M_ArtNr==AVPOST->AvNr .and. AvPost->Art="M"
      if AVPOST->Text=="A"
        merk_Satz:=recno()
        rek_druck4(AVPOST->ArtNr, Tiefe+1,zeile,allKw)
        select AvPost
        go (merk_satz)
      endif
      skip
    enddo
  endif

  if aktGedr .and. tiefe==0
    ? space(31)+replicate("-",len(allKw)*6)
  endif

RETURN zeile
/* EOP */


  /*** ab hier obsolete Listen f�r Frank Schmitt ****************************************/
/* 
* Material - Bedarfs - Liste / Baugruppe & Artikel manuelle Reihenfolge drucken
*/
PROCEDURE Mat_LiMan(disponiert)
LOCAL Zeile:=0 , Seite:=0
LOCAL Merk_satz,Merk_Reih,erst:=.t.
LOCAL getList:={}, ausgabe, export,objErr
LOCAL maxRow

  default disponiert:=.t.

  cls
  Titel("Material-Bedarfs-Liste / manuelle Reihenfolge")


  if ! open( "Artikel" , "M_MEHRF","Manuell" , "AvPost","AufAus","AufPost",;
    "BesPost" , "Inner","AvAus","Einheit","Text")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif


  // Fenster(11,18,13,56)
  // Message("Aktuellen Auftragsbestand zur Anfrage-Menge hinzuaddieren?  (@J@/@N@)")
  // @ 12,20 say "Zuz�glich akt. Auftragsbestand:" get disp picture "!" valid disp$"JN"
  // read

  if ABBRUCH
    cls
    close data
    RETURN
  endif

  Ausgabe:=Druck_Bs("Material-Bedarf" , "xlsx" , .t.)
  if ABBRUCH .or. ( valtype(Ausgabe) == "L" .and. ! Ausgabe )
    cls
    close data
    RETURN
  endif

  if valtype(Ausgabe)=="C"
    // FIXME: sollte alles in druck_bs passieren
    // beisst sich aber mit alten excel:column export
    BEGIN SEQUENCE // krit. Bereich
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
      getUser():setCurrentPrintJob(ExcelJob():new())
      getUser():getCurrentPrintJob():StartDoc( export )
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
  endif

  select Artikel
  set relation to ARTIKEL->ME into Einheit

  /* ACHTUNG andere order bei Bespot/Inner */
  select Inner
  INNER->(OrdSetFocus(2)) // inner
  select Bespost
  BESPOST->(OrdSetFocus(2)) // bespost

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." };
    )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b, .t. )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  bed2_datei_erst()

  Message("Liste wird erstellt.    Bitte warten...")

  /* Bedarfs-Datei ausdrucken */
  if valtype(Ausgabe)<>"C"
    bed_Manuell_druck()
  endif

  /* einzelner Bedarf ausdrucken , je Ordnung */
  select M_MEHRF
  M_MEHRF->(OrdSetFocus(3))
  SET RELATION to M_MEHRF->ArtNr INTO Artikel

  locate for ! empty(M_MEHRF->Reihenfolg) .and. M_MEHRF->Reihenfolg<>INNER_ANS_ENDE

  // ohne Seitenumbruch
  zeile:=0
  if valtype(Ausgabe)<>"C"
    ? space(2)+"Material-Bedarf / ",FETT_AN,"manuelle Reihenfolge"
    if disponiert
      ?? "mit Gesamt-Auftragsbestand "
    else
      ?? "ohne Gesamt-Auftragsbestand"
    endif
    ?? FETT_AUS,space(31),"vom:",getUser():date
    Mat3_Kopf_Text(disponiert)
  else // Excel
    ? "","","Art.Nr.","Art","Honsel-Nr","Bezeichnung","", "Auftrags-Bestand","Anfrage-Menge",;
      "akt.Lag.Best.","verf�gbar","Bestellt"
  endif

  do while ! eof()
    select M_Mehrf
    merk_satz:=M_MEHRF->(recno())
    merk_Reih:=M_MEHRF->Reihenfolg
    M_MEHRF->(OrdSetFocus(1))
    go (merk_satz)
    rek_druck3(M_MEHRF->ArtNr,0,disponiert, valtype(Ausgabe)=="C")
    select M_MEHRF
    M_MEHRF->(OrdSetFocus(3))
    go (merk_satz)
    cont
    if merk_Reih<>M_MEHRF->Reihenfolg
      ? space(2)+"-- "+trim(merk_Reih)+" --"
      ?
    endif
  enddo

  /** drucke Hauptartikel ohne Ordnung */
  locate for M_MEHRF->Reihenfolg<>INNER_ANS_ENDE
  do while ! eof()
    select M_Mehrf
    merk_satz:=M_MEHRF->(recno())
    if empty(M_MEHRF->gedruckt)
      if erst
        if valtype(Ausgabe)<>"C"
          ? "??"+replicate("-",60)
        endif
        erst:=.f.
      endif
      M_MEHRF->(OrdSetFocus(1))
      rek_druck3(M_MEHRF->ArtNr,0,disponiert)
      select M_MEHRF
      M_MEHRF->(OrdSetFocus(3))
      go (merk_satz)
    endif
    cont
  enddo

  /* einzelner Bedarf ausdrucken , je restl. Artikel */
  select M_MEHRF
  M_MEHRF->(OrdSetFocus(1))
  loca for M_MEHRF->gedruckt<>"*"
  if ! eof()
    if valtype(Ausgabe)<>"C"
      ? space(2)+"Material-Bedarf / ",FETT_AN,"Artikel",FETT_AUS,space(38),"vom:",getUser():date
      Mat3_Kopf_Text(disponiert)
    else
      ?
      ?
    endif

    do while ! eof()
      drucke_3satz(0,disponiert)
      cont
    enddo
  endif

  // l�sche relas von M_Mehrf wird bei STRG-F9 rekLiAufBestArtikel ohne verwendet
  dbclearRelation()

  Zeile:=FormFeed(Zeile)
  // Drucker("OFF")

  if valtype(Ausgabe)=="C"
    // delete column 1 and 2
    getUser():getCurrentPrintJob():oSheet:columns(1):delete()
    getUser():getCurrentPrintJob():oSheet:columns(1):delete()
    getUser():getCurrentPrintJob():oSheet:columns(3):delete() // ohne Honsel-Nr.
    getUser():getCurrentPrintJob():autoFitAll( )

    // colorize some rows
    maxRow:=getUser():getCurrentPrintJob():row
    getUser():getCurrentPrintJob():colNumberFormat( 2 , maxRow , 8 , EXCEL_NUMBER_FORMAT_INTEGER2)

  endif

  getUser():getCurrentPrintJob():endDoc()
  getUser():setCurrentPrintJob(NIL)

  if valtype(Ausgabe)=="C"
    if Message(export+" wurde erzeugt.  Ordner �ffnen? @J@/@N@","JN","N")=="J"
      wapi_SHELLEXECUTE( 0, "open", getUser():exportPATH())
    endif

  endif

  M->specialZeige:=NIL

  close data
  cls

RETURN
/* EOP */


/* PROCEDURE Rek_druck3()
*
* druckt rekrusive alles benoetigte Material der Baugruppe aus
* 3. Variante
*/
PROCEDURE rek_druck3(M_ArtNr,tiefe,disponiert,druckeHonselNr)
LOCAL merk_Satz
LOCAL verfueg:=0
  default disponiert:=.t. // addiere akt. AB Bestand zur Anfrage Menge

  M_MEHRF->(dbseek(M_ArtNr))
  /** Artikel an dieser Stelle drucken ? */
  if tiefe <> 0 .and. ! empty(M_MEHRF->Reihenfolg)
    RETURN
  endif

  /* drucke akt. Satz aus */
  drucke_3Satz(tiefe*2,disponiert,druckeHonselNr)

  if disponiert
    verfueg:=max(ARTIKEL->LageBest,0) - ARTIKEL->Disponiert - M_MEHRF->Menge
  else
    verfueg:=max(ARTIKEL->LageBest,0) - M_MEHRF->Menge
  endif

  /* suche weiteres Material in StkListe */
  // if verfueg < 0 .and. (tiefe==0 .or. M_MEHRF->Baugruppe<>"J")

  if getArtikelArt() $ STKLIST_ARTIKEL
    select AvPost
    seek M_ArtNr+"M"
    do while ! eof() .and. M_ArtNr==AVPOST->AvNr .and. AvPost->Art="M"
      if AVPOST->Text=="A"
        merk_Satz:=recno()
        rek_druck3(AVPOST->ArtNr, Tiefe+1,disponiert,druckeHonselNr)
        select AvPost
        go (merk_satz)
      endif
      skip
    enddo
  endif

RETURN
/* EOP */


/* PROCEDURE drucke_3Satz()
*
* druckt akt. Satz aus M_Mehrf aus !
*
* Paramter: in Baugruppe - true/false
*              Lr         - linker Rand (num.)
*              druckeHonselNr   - treu/false  
*/
static PROCEDURE drucke_3Satz(lr,disponiert,druckeHonselNr)
LOCAL Baugr:=" ",m_artnr, verfueg,zeile:=0
LOCAL Max:=8,bestellt
  default lr:=0
  default disponiert:=.t. // addiere akt. AB Bestand zur Anfrage Menge
  default druckeHonselNr:=.f.

  if disponiert
    verfueg:=max(ARTIKEL->LageBest,0) - ARTIKEL->Disponiert - M_MEHRF->Menge
  else
    verfueg:=max(ARTIKEL->LageBest,0) - M_MEHRF->Menge
  endif

  // ohne Anzahl der vorkommnisse: 31.10.2011
  // kom:="*"+str(M_MEHRF->Anzahl,2)+"*"

  Baugr:=if(ARTIKEL->Art=="M","*"," ")
  m_artnr:=out(M_MEHRF->ArtNr)


  if lr<>0
    // doch wieder einruecken fuer H. Weiland 21.5.2000
    lr:=Min(Max,lr)
  endif

  if M_MEHRF->gedruckt=="*"
    ? space(lr)+Baugr,space(0),ZEIGE_ARTNR+M_ArtNr,ARTIKEL->Art,;
      if(druckeHonselNr,ARTIKEL->HartNr,space(0))
    ?? ARTIKEl->Bez1,space(Max-lr),ARTIKEL->Disponiert,transform(M_MEHRF->Menge,"@Z")
  else
    ? space(lr)+Baugr,space(0),ZEIGE_ARTNR+M_ArtNr,ARTIKEL->Art,;
      if(druckeHonselNr,ARTIKEL->HartNr,space(0))
    ?? ARTIKEl->Bez1,space(Max-lr),ARTIKEL->Disponiert,transform(M_MEHRF->Menge,"@Z"),;
      ARTIKEL->LageBest, verfueg

    bestellt:=if(getArtikelArt()$"FM",ARTIKEL->BestInt,ARTIKEL->BestExt)

    if Bestellt<>0.00
      ?? Bestellt,space(0)// ,"("
      drucke_best(ARTIKEL->ArtNr,111,18)
      // ?? ")"
    endif

    /* setze KZ, dass Satz schon gedruckt */
    replace M_MEHRF->gedruckt with "*"
  endif

RETURN




/* druckt manuell erf. Artikel (Kopfdatei) + liefertermine
*/
PROCEDURE Bed_Manuell_druck()
LOCAL start:=87
LOCAL umbruch:=start+20
LOCAL count:=start
LOCAL zeile:=0,x,feld,meng

  Umgebung(WRITE)

  select Aufpost
  AUFPOST->(OrdSetFocus(4)) // AnR+Datum

  /* Bedarfs-Datei ausdrucken */
  select Manuell
  go top
  ? space(2)+"Material-Bedarf / Artikel",space(71),"  vom:",getUser():date
  ? space(2)+replicate("-",114)
  ? space(2)+"Art.Nr.     Art Bezeichnung                                Auf.Best.   Anfrage     "+;
    "Gesamt  Liefertermine"
  ? space(2)+replicate("-",114)
  do while ! eof()
    ARTIKEL->(dbseek(MANUELL->ArtNr))
    ? space(2)+ZEIGE_ARTNR+out(MANUELL->ArtNr),ARTIKEL->Art,space(0),ARTIKEL->Bez1,space(8),;
      ARTIKEL->disponiert, str(MANUELL->Menge,10,2),str(ARTIKEL->disponiert+MANUELL->Menge,10,2)

    /* suche Liefertermine */
    select aufpost
    dbseek(MANUELL->ArtNr)
    do while ! eof() .and. MANUELL->ArtNr==AUFPOST->ArtNr
      if AUFPOST->AufArt $ "KRVD" .and. (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->Erledigt=="O");
        .and. AUFAUS->erledigt<>"J"

        if ! KWempty(AUFPOST->kw)
          ?? " ("+AUFPOST->kw,str(AUFPOST->Menge,7)+")"
          count:=count + 2+5+1+7
        endif
        /* Liefertermine aus Auf.Kopf */
        x=1
        AUFAUS->(dbseek(AUFPOST->AufNr))
        feld="AUFAUS->KW1"
        do while x<=6 .and. SUBSTR(&Feld,1,1)<>" "
          meng="AUFAUS->Meng"+str(x,1)
          ?? " ("+&feld,str(&(meng),6)+")"
          count:=count + 2+5+1+6
          feld="AUFAUS->KW"+str(x,1)
          x++
          /* Umbruch ? */
          if count > umbruch
            count:=start
            ? space(start)
          endif
        enddo
      endif
      skip
      /* Umbruch ? */
      if count > umbruch
        count:=start
        ? space(start)
      endif
    enddo
    select MANUELL
    skip
  enddo
  ? space(2)+replicate("=",114)
  ?


  Umgebung(LOAD)
RETURN

/* Ausgabe der �berschrift */
PROCEDURE Mat3_Kopf_Text(disponiert)
LOCAL Zeile:=0

  ? space(2)+replicate("-",114)
  ? space(2)+"Art.Nr.      Art Bezeichnung                               "
  if disponiert
    ?? FETT_AN,"Auftrags     Anfrage",FETT_AUS,"      akt.    verf�gbar  Bestellt"
    ? space(62),FETT_AN,"Bestand       Menge ",FETT_AUS,"Lag.Best.                    "
  else
    ?? "Auftrags     ",FETT_AN,"Anfrage",FETT_AUS,"     akt.    verf�gbar  Bestellt"
    ? space(62),"Bestand       ",FETT_AN,"Menge",FETT_AUS,"Lag.Best.                    "
  endif
  ? space(2)+replicate("-",114)
RETURN


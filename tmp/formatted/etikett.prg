/* Modul Etikett.prg
*
* Alles wass mit Etiketten zu tun hat
*/
#include "Miki.ch"

PROCEDURE Versand_Etiketten
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Etistru" , "Artikel" , "Einheit" , "Vers_Eti" ,"AvPost","Mat_Kz")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  eti_Show({ || eti_vdruck(.t.)})

  Titel("Versand-Etiketten")

  /* Relationen setzen */
  select Etistru
  set rela to ETISTRU->ArtNr into artikel, to ETISTRU->Me into Einheit;
    , to ETISTRU->VersandNr into vers_eti

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z" // Kopf gesperrt
  aKopf[EDIT_EXTRA_FKT]:={ { chr(K_F8)," @F8@=Ansicht ", {|| eti_Show()} } }
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->SPRACHE:="D"}

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. eti_nach(oGet,.t.) }
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F8@=Ansicht    @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT ]:=.f.
  aSpalte[EDIT_POS_X]:=2

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Etiketten-Typ-Nr
  aSpalte[EDIT_NAME]:="VersandNr"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Vers_Eti",.f.) } // kein leeres Feld erlaubt
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MESSAGE]:="Etiketten-Art eingeben.    @M@=Miki/@H@=Honsel     @F12@=Hilfe    @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Sprache"
  aSpalte[EDIT_TITEL]:="Sprache"
  aSpalte[EDIT_MASKE]:="@!"
  aSpalte[EDIT_AFTER]:={ || (alias())->sprache $ "DE " }
  aSpalte[EDIT_MESSAGE]:="Sprache eingeben.    @D@eutsch / @E@nglisch"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Anzahl Ausdrucke
  aSpalte[EDIT_NAME]:="Anz"
  aSpalte[EDIT_TITEL]:="Anzahl Eti."
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MESSAGE]:="Anzahl Etiketten eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Inhalt"
  aSpalte[EDIT_TITEL]:="Inhalt"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MESSAGE]:="Menge/Packungsinhalt auf Etikett eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen aSpalte:=e_fill() // initialisieren
  /**** ENDE Feld-Definitionen ***/


  /*** Eingabe / Drucke ****/
  Edit(aFelder,aKopf)
  if reccount() > 0 .and. Message("Etiketten ausdrucken ?  ( J / N )","JN")=="J"
    Eti_Vdruck(.f.)
    select Etistru
    zap
  endif

  close data
RETURN


/* Procedure Eti_Av *********************************************
*
* Etikettendruck aus Av, �hnlich Eti_Versand
*/
PROCEDURE Eti_Av
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Etistru","Inner";
    , "Artikel" , "Einheit" , "Vers_Eti" , "AvPost" , "Maschine" ,"Aufaus","Kunden" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  eti_Show({ || Eti_Av_Druck(1,.t.) })

  Titel("Etiketten Arbeitsvorbereitung")

  /* Relationen setzen */
  select Etistru
  set rela to ETISTRU->ArtNr into artikel, to ETISTRU->Me into Einheit;
    , to ETISTRU->VersandNr into vers_eti

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z" // Kopf gesperrt
  aKopf[EDIT_EXTRA_FKT]:={ { chr(K_F8)," @F8@=Ansicht ", {|| eti_Show()} } }
  aKopf[EDIT_INDEX_FELD]:={ || empty(ETISTRU->InnerNr)}

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Artikel-Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. eti_nach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F8@=Ansicht    @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT ]:=.f.
  aSpalte[EDIT_POS_X]:=4

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Inner-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="InnerNr"
  aSpalte[EDIT_TITEL]:="Nr."
  aSpalte[EDIT_MASKE]:=replicate("9",len(INNER->InnerNr))
  aSpalte[EDIT_AFTER]:={ |oGet| etiInnerNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Innerbetriebliche Produktionsnummer eingeben.   @F12@=Auswahl"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Anz"
  aSpalte[EDIT_TITEL]:="Anzahl"
  aSpalte[EDIT_MASKE]:="9"
  aSpalte[EDIT_POS_X]:=10
  aSpalte[EDIT_MESSAGE]:="Anzahl Etiketten @Tafel@ eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="EtiAnz2"
  aSpalte[EDIT_POS_X]:=10
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_MESSAGE]:="Anzahl Etiketten @Stechkarte@ eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/



  /*** Eingabe / Drucke ****/
  Edit(aFelder,aKopf)
  if reccount() > 0 .and. Message("Etiketten ausdrucken ?  ( J / N )","JN")=="J"
    select Etistru
      /* jojo kann raus, da keine Drucker-Schachtelung m�glich !
      *if ! drucker("on")
      *  Error(TRY_AGAIN)
      *  close data
      *  RETURN
      *endif
      */
    go top
    do while ! eof()
      INNER->(dbseek(ETISTRU->InnerNr))
      Eti_Av_Druck(ETISTRU->Anz,,,ETI_TAFEL) // drucke Etikett je Posten
      Eti_Av_Druck(ETISTRU->EtiAnz2,,,ETI_STECHKARTE) // drucke Etikett je Posten
      skip
    enddo
    select Etistru
    zap
      /* jojo raus
      *  drucker("off")
      */
  endif

  close data
RETURN
/* EOP Eti_Av */



/* Function eti_Nach
*
* Fkt. die nach Eingabe der ArtNr. ausgef�hrt wird
*/
// FUNCTION Eti_Nach(oGet/*,aFelder,Zeile*/  )
static FUNCTION Eti_Nach(oGet,convertPhoenix)
LOCAL parent,merkME
  if oGet:changed // Relation gesetzt

    default convertPhoenix:=.f.

    merkME:=ARTIKEL->ME

    // Phoenix-Artikel
    if convertPhoenix .and. (parent:=getParentPhoenix(ARTIKEL->ArtNr))<>NIL
      ARTIKEL->(dbseek(parent))
      REPLACE ETISTRU->ArtNr WITH parent
    else
      dbskip(0)
      // REPLACE ETISTRU->ArtNr WITH oget:varget()
    endif

    if ARTIKEL->Inhalt > 0 .and. ! empty(ARTIKEL->InhaltME)
      REPLACE ETISTRU->Me WITH ARTIKEL->InhaltME
    else
      REPLACE ETISTRU->Me WITH ARTIKEL->ME
    endif
    REPLACE ETISTRU->Bez1 WITH ARTIKEL->Bez1
    REPLACE ETISTRU->Bez2 WITH ARTIKEL->Bez2
    REPLACE ETISTRU->Pe WITH ARTIKEL->Schluessel
    REPLACE ETISTRU->Form WITH ARTIKEL->FormRahmen
    // REPLACE ETISTRU->Nutzen WITH ARTIKEL->Nutzen
    REPLACE ETISTRU->Inhalt WITH ARTIKEL->Inhalt
    if getUser():id $ "MO/BB"
      REPLACE ETISTRU->VersandNr WITH "H" // Honsel
    else
      REPLACE ETISTRU->VersandNr WITH "M" // default Miki
    endif

    REPLACE ETISTRU->Anz WITH 1

  endif
RETURN(.t.)

/* Function etiInnerNach()
*
* wird nach Eingabe der Innerbetr. Prod.Nr. ausgef�hrt bei Av Etiketten ausgef�hrt
*/
STATIC FUNCTION etiInnernach(oGet)
  if oGet:changed()

    /* keine LeerEingabe */
    if empty(oGet:Buffer)
      RETURN(lastkey()==K_UP)
    endif

    // shift eti-nummer nach rechts, jetzt 4-stellig
    oGet:buffer:=right(space(4)+alltrim(oGet:buffer),4)
    oGet:varput(oGet:buffer)

    SELECT Inner
    SEEK oGet:Buffer
    if ! eof() .and. ETISTRU->ArtNr<>INNER->ArtNr
      Error(ACHTUNG+"Auftrag:"+oGet:Buffer+" ist Artikel: "+INNER->ArtNr+" zugewiesen !")
      select EtiStru
      RETURN(.f.)
    endif

    if eof()
      Error(ACHTUNG+"Auftrag:"+oGet:Buffer+" ist nicht Artikel: "+ETISTRU->ArtNr+" zugewiesen !")
      select EtiStru
      RETURN(.f.)
    endif
    select EtiStru

  endif

  /* zur�ck immer erlaubt */
  if lastkey()==K_UP
    RETURN(.t.)
  endif

  /** leer nicht erlaubt */
  if empty(oGet:Buffer)
    return .f.
  endif

RETURN(.t.)
/* EOF InnerNr_Nach */


/*** Versand-Etiketten drucken **********************************
*
*/
FUNCTION Eti_Vdruck(inShow)
LOCAL erst:=0 , x
LOCAL Zeile:=0
LOCAL append:=.f., texte, i
  default inShow:=.f.

  select Etistru
  go top
  do while .not. eof()

    if ETISTRU->anz>0 .or. inShow

      if inShow
        Drucker("BS")
        if ETISTRU->(reccount())==1
          ETISTRU->(dbgotop())
          if empty(ETISTRU->ArtNr)
            replace ETISTRU->ArtNr with "4100500"
            append:=.t.
          endif
        endif
      else
        Drucker("ON","Versand:"+str(ETISTRU->anz,3)+"x"+OUT(ETISTRU->ArtNr),,,,ETISTRU->anz)
      endif

      if ! inShow
        x:=1
      else
        x:=0
      endif

      zeile:=0
      ?? VERS_ETI->Text1
      ? VERS_ETI->Text2
      // ? VERS_ETI->Text4
      ? getTranslation("allgemein.artnr",ETISTRU->Sprache), trim(OUT(ARTIKEL->ArtNr))
      if ETISTRU->VersandNr == "H"
        if ! empty(ARTIKEL->HartNr) .or. ! empty(ARTIKEL->HLgOrt)
          ? "Honsel:", trim(no_blanks(ARTIKEL->HartNr)),ARTIKEL->HLgOrt
        endif
      endif
      if ETISTRU->Sprache $ " D"
        ? ARTIKEL->Bez1
        ? ARTIKEL->Bez2
      else
        ? ARTIKEL->E_Bez1
        ? ARTIKEL->E_Bez2
      endif

      if isPhoenixOberArtikel( ARTIKEL->Artnr ) .and. ! empty(ARTIKEL->MatKz)
        MAT_KZ->(dbseek(ARTIKEL->MatKz))
        if ! MAT_KZ->(eof()) .and. ! empty( MAT_KZ->MkzText )
          texte:=HB_ATokens( MAT_KZ->MkzText , MY_CR+MY_LF)
          for i:=1 to 3
            if (len(texte))>=1
              ? texte[i]
            endif
          next
        endif
      else
        ? "---------------------------------"
        ? space(13),left(getTranslation("allgemein.inhalt",ETISTRU->Sprache)+":    ",8),;
          transform(ETISTRU->Inhalt,"@Z"),if(ETISTRU->Sprache$" D",EINHEIT->Text,EINHEIT->E_Text)
      endif

      erst=erst+1

      Drucker("OFF")
    endif
    skip

  enddo // eof()

  if append
    ETISTRU->(dbgotop())
    replace ETISTRU->ArtNr with ""
  endif

RETURN .t.



/* 
*  druckt f�r selektierten (!) innerbetr. Auftrag pro Artikel ein St�cklisten-Etiketten
*
* Parameter:    Anzahl der gew�nschten Etiketten
*               Innerbetr. Auftragsnr.
*               aMehrfArtikel - Array mit zugeh. Artikeln bei Mehrfachspritzungen
*               Art - ETI_TAFEL oder ETI_STECHKARTE
*/
  #define ETI_LEN 40
PROCEDURE Eti_Av_Druck(AnzahlEtiketten,inShow,aMehrfArtikel,art)
LOCAL zeit
LOCAL tempVal,sp,gesamt:=0
LOCAL Zeile:=0
LOCAL topLiefKW , i, maxlen

  default AnzahlEtiketten:=1

  if (AnzahlEtiketten == 0)
    return
  endif

  Umgebung( WRITE_ALL )

  default inShow:=.f.

  // suche Haupt-Maschinen
  select AvPost
  AVPOST->(dbseek(INNER->ArtNr+"V"))
  do while ! eof() .and. AVPOST->AvNr=INNER->ArtNr .and. AVPOST->Art="V"
    // Nur Hauptmaschinen
    if (AVPOST->Text="A" .and. AVPOST->HauptKZ=="H") .and.;
      (empty(INNER->MaschNr) .or. INNER->MaschNr == trim(AVPOST->ArtNr))
      zeit:=AVPOST->Menge
      select Maschine
      SEEK trim(AVPOST->ArtNr)
      if MASCHINE->(eof())
        SELECT AVPOST
        skip
        loop
      endif

      if Zeit<>0
        gesamt:=INNER->Menge/zeit
      else
        gesamt:=0
      endif
      gesamt += AVPOST->RuestZeit

      topLiefKW:=INNER->Lief_Kw

      if inShow
        Drucker("BS")
        ?
      else
        Drucker("ON","AV-Eti-"+;
          alltrim(dispInnerNr(INNER->InnerNr, INNER->ArbGang)),,,,AnzahlEtiketten)
      endif

      // nehme aktuellen Datensatz aus Inner.dbf
      ARTIKEL->(dbseek(INNER->ArtNr))

      EINHEIT->(dbseek(ARTIKEL->ME))

      /** 1. Zeile */
      // ?? BREIT_AN
      // ?? PrintSonderZeichen():new(left(INNER->InnerNr,3)) // w/o spaces
      // ?? BREIT_AUS

      // TextAtFont( nPosX, nPosY, cString, cFont,
      // nPointSize, nWidth, nBold, lUnderLine, lItalic, nCharSet,
      // lNewLine, lUpdatePosX, nColor, nAlign )
      if getuser():getcurrentprintjob():className()=="WINPRNJOB"
        getUser():getCurrentPrintJob():winPrnRef:TextAtFont;
          ( 0,0, alltrim(dispInnerNr(INNER->InnerNr, INNER->ArbGang)) ,;
          if(empty(DRUCKER->Font),ETI_FONT_STANDARD,trim(DRUCKER->Font)),;
          ETI_FONTSIZE_BREIT,ETI_FONT_WIDTH,900,.f.,.f.,ETI_FONT_CHARSET,.f.,.t.,120,0 )
      endif
      ?? BREIT_AUS

      // Stunden in Tage
      if art == ETI_STECHKARTE
        ?? FETT_AN,space(0),"Stechkarte",FETT_AUS,"Ft="+INNER->Fert_Kw,;
          "Lf="+topLiefKW
      else
        tempVal:=getStdTagText(gesamt,STDTAG_KURZ)
        sp = space(1)
        maxlen:=12
        if len(tempVal) < maxlen
          sp = space( maxlen - len(tempVal))
        endif
        ?? tempVal+sp+"Ft="+INNER->Fert_Kw,"Lf="+topLiefKW
      endif


      /** 2. Zeile */
      ? alltrim(str(INNER->Menge,6)),trim(EINHEIT->Text),MASCHINE->StdNr,"=",MASCHINE->Bez

      // drucke alle Artikel bei Mehrfachspritzungen in winzig nebeneinander
      if aMehrfArtikel <> NIL
        for i:=1 to len( aMehrfArtikel )
          if i / 2 <> int (i / 2) // alle ungeraden ein Umbruch also 1,3,5,...
            ?
          endif
          ARTIKEL->(dbseek(aMehrfArtikel[i,1]))
          ?? WINZIG_AN,trim(out(aMehrfArtikel[i,1])),ARTIKEL->Bez1,WINZIG_AUS
        next
      else
        /** 3. Zeile */
        ? SCHMAL_AN,trim(out(ARTIKEL->ArtNr)),SCHMAL_AUS,ARTIKEL->Bez1
        ? SCHMAL_AN,space(len(trim(out(ARTIKEL->ArtNr)))),SCHMAL_AUS,ARTIKEL->Bez2
      endif

      ? replicate("-",ETI_LEN)
      if ! empty(ARTIKEL->Formrahmen)
        ? "Formrahmen/WKZ-Nr.:",ARTIKEL->Formrahmen
      endif
      if empty(INNER->AufNr)
        // Miki-Auftrag
        // FIXME: sp�ter Unterscheidung weiviel Miki intern, wieviel ext. AB
        // tempval:="Miki: "+alltrim(transstr(INNER->Menge,11,2,.t.,.t.))+" "+EINHEIT->text+" "+;
        tempval:=trim(INNER->Grund)
        if len(tempval)>ETI_LEN
          ? SCHMAL_AN,tempval,SCHMAL_AUS
        else
          ? tempVal
        endif
      else
        AUFAUS->(dbseek(INNER->AufNr))
        // transstr(INNER->Menge,11,2,.t.,.t.)+" "+EINHEIT->text
        // FIXME: was MengeAB transstr(INNER->MengeAb,11,2,.t.,.t.)+" "+EINHEIT->text
        if len( AUFAUS->AufNr+" "+trim(AUFAUS->Kurzname) ) > ETI_LEN
          ? SCHMAL_AN,FETT_AN,AUFAUS->AufNr,FETT_AUS,trim(AUFAUS->Kurzname),SCHMAL_AUS
        else
          ? FETT_AN,AUFAUS->AufNr,FETT_AUS,trim(AUFAUS->Kurzname)
        endif

        // Versandkunde abweichend?
        if AUFAUS->kundnr <> AUFAUS->V_KundNr
          KUNDEN->(dbseek(AUFAUS->V_KundNr))
          if len( "Empf. "+trim(KUNDEN->Kurzname) ) > ETI_LEN
            ? SCHMAL_AN,FETT_AN,"Empf. "+trim(KUNDEN->Kurzname),SCHMAL_AUS
          else
            ? "Empf. "+trim(KUNDEN->Kurzname)
          endif
        endif

      endif
      if Zeile<=5
        ?
      endif
      if AVPOST->Ruestzeit>0 .and. zeile < 7 // / Info es gehen 8 Zeilen auf 1 Etikett,
        // 1. Zeile wird aber nicht gez�hlt, da mit ?? angefanegn wird
        ? "R�stzeit Soll:",transstr(AVPOST->Ruestzeit,5,2,.f.,.t.),"Std",FETT_AN,;
          "Ist:___________",FETT_AUS
      endif

      Drucker("OFF")

    endif // Text="A" .and. Art="V"
    SELECT AvPost
    skip
  enddo

  Umgebung( LOAD )

RETURN


/* 
*  druckt f�r selektierten (!) innerbetr. Auftrag pro Artikel ein Dienstleistungs-Etikett
*/
PROCEDURE Eti_DL_Druck(AnzahlEtiketten,inShow)
LOCAL tempVal,gesamt:=0
LOCAL Zeile:=0
LOCAL merkDat, merkLiefNr

  default AnzahlEtiketten:=1

  if (AnzahlEtiketten == 0)
    return
  endif

  Umgebung( WRITE_ALL )

  default inShow:=.f.

  // nehme aktuellen Datensatz aus Inner.dbf
  ARTIKEL->(dbseek(INNER->ArtNr))
  EINHEIT->(dbseek(ARTIKEL->ME))
  if inShow
    Drucker("BS")
    ?
  else
    Drucker("ON","AV:"+dispInnerNr(INNER->InnerNr, INNER->ArbGang),,,,AnzahlEtiketten)
  endif

  if getuser():getcurrentprintjob():className()=="WINPRNJOB"
    getUser():getCurrentPrintJob():winPrnRef:TextAtFont;
      ( 0,0, alltrim(dispInnerNr(INNER->InnerNr, INNER->ArbGang)) ,;
      if(empty(DRUCKER->Font),ETI_FONT_STANDARD,trim(DRUCKER->Font)),;
      ETI_FONTSIZE_BREIT,ETI_FONT_WIDTH,900,.f.,.f.,ETI_FONT_CHARSET,.f.,.t.,120,0 )
  endif
  ?? BREIT_AUS

  tempVal:=getStdTagText(gesamt,STDTAG_KURZ)
  ?? " Dienstleistung  Ft="+INNER->Fert_Kw,"Lf="+INNER->Lief_Kw

  /** 2. Zeile */
  ? alltrim(str(INNER->Menge,6)),trim(EINHEIT->Text)
  ? replicate("-",ETI_LEN)

  ? FETT_AN,"Externe Folge-Dienstleistung beachten:",FETT_AUS
  ? out(ARTIKEL->ArtNr), ARTIKEL->Bez1
  if ! empty(ARTIKEL->bez2) .and. trim(ARTIKEL->Bez2)<>"."
    ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
  endif
  if open("BesPost","BesAus","Lieferan")
    select BesPost
    BESPOST->(OrdSetFocus(3)) // BESPOST->ArtNr+BESPOST->LiefNr+mydescend(BESPOST->AufDat)
    BESPOST->(dbseek(ARTIKEL->ArtNr))
    if .not. BESPOST->(eof())
      BESAUS->(dbseek( BESPOST->BestNr ))
      merkDat:=BESAUS->BestDat
      do while .not. BESPOST->(eof()) .and. BESPOST->ArtNr=ARTIKEL->Artnr
        BESAUS->(dbseek( BESPOST->BestNr ))
        if merkDat <= BESAUS->BestDat
          merkLiefNr:=BESAUS->LiefNr
        endif
        skip
      enddo
      if ! empty( merkLiefNr )
        LIEFERAN->(dbseek(merkLiefNr))
        ? LIEFERAN->LiefNr,LIEFERAN->Kurzname
        ? if(empty(LIEFERAN->Telefon),"","Tel:"+LIEFERAN->Telefon)
      endif
    endif
  endif
  Drucker("OFF")

  Umgebung( LOAD )

RETURN


/* Procedure Eti_Druck ********************************************
*
* druckt aktuell selektiertes Etikett aus (etikett.dbf/etirepa.dbf)
*
*/
PROCEDURE Eti_Druck(inShow)
LOCAL x:=1,ob:=4, li:=12, GetList:={}
LOCAL Zeile:=0
  default inShow:=.f.

  if REC_LOCK(5)
    @ ob+13,li say "Anzahl:" get _FIELD->anz picture "99"
    read
  else
    return
  endif

  if ABBRUCH
    dbunlock()
    return
  endif

  if inShow
    Drucker("BS")
  else

    Drucker("ON",alltrim("Eti. frei: "+str(_FIELD->anz))+"x"+trim(_FIELD->Eti1)+' '+trim(_FIELD->Eti2);
      ,,,,_FIELD->anz)
  endif

  zeile:=0
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti1,.f.)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti2)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti3)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti4)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti5)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti6)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti7)
  zeile += colorprint(space(_FIELD->lr)+_FIELD->Eti8)

  Drucker("OFF")
  dbunlock()
RETURN



/* Procedure Best_Etikett
*
* drucken der Bestell-Etiketten
*/
PROCEDURE Eti_Best(inShow)
LOCAL Kw:="", Meng:=""
LOCAL Zeile:=0 , x:=0
  default inShow:=.f.

  SELECT Bestell
  go top
  // SET RELATION TO BESTELL->ArtNr INTO Artikel, to BESTELL->ME INTO EINHEIT
  do while .not. eof()

    // Schnitt nach jedem Etikett -> vorerst einzelne Jobs
    if inShow
      Drucker("BS")
    else
      Drucker("ON","Bestellung")
    endif

    zeile:=0
    if len(alltrim(BESTELL->ArtNr)) <= FRACHT_LAENGE
      skip
      loop
    endif

    // seit 12.4.2015 ohne KW in BesAus!
    // if empty(BESAUS->kw1)
    ?? BESAUS->name
    ? "("+BESAUS->Liefnr+")"
    ? "Best.-"+BESAUS->Bestnr+"-"+dtoc(BESAUS->Aufdat)+space(5)+"KW",BESTELL->kw
    ? "---------------------------------"
    ? BESTELL->komm1
    ?
    ? out(BESTELL->ArtNr),alltrim(str(BESTELL->menge,10,Min(EINHEIT->Nachkomma,2))),EINHEIT->Text
    if BESTELL->Menge2 > 0
      EINHEIT->(dbseek( BESTELL-> ME2 ))
      ?? "=",alltrim(str(BESTELL->menge2,10,Min(EINHEIT->Nachkomma,2))),EINHEIT->Text
    endif
    ? "Lag.",getArtikelLagerOrt( ETI_LEN - 6)
    ?
    // else
    // x=1
    // kw="BESAUS->KW"+str(x,1)
    // meng="BESAUS->MENG"+str(x,1)
    // do while .not. empty(&kw) .and. x <= 6
    // ? BESAUS->name
    // ? "("+BESAUS->Liefnr+")"
    // ? "Best.-"+BESAUS->BestNr+"-"+dtoc(BESAUS->Aufdat)+space(5)+"KW "
    // ?? &kw
    // ? "---------------------------------"
    // ? BESTELL->komm1
    // ?
    // ? Out(BESTELL->ArtNr),&meng,EINHEIT->Text
    // ? "Lag.",getArtikelLagerOrt( ETI_LEN - 6)
    // ?
    // x=x+1
    // if x <= 6
    // kw="BESAUS->KW"+str(x,1)
    // meng="BESAUS->MENG"+str(x,1)
    // endif
    // enddo
    // endif
    skip

    Drucker('OFF')

  enddo

  // SET RELATION TO
return
/* EOP Eti_Druck */



/*
* Adress-Etiketten Kunden
*/
PROCEDURE Eti_Adress(Typ)
LOCAL MKundNr,Anz:=0,Anz2:=0,ttext:=""
LOCAL GetList:={}
  eti_show({ || Eti_Adr_druck(Typ,.t.) })
  default typ:=ETI_OHNE_KUNDNR

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Kunden" , "Spedit" , "Land" , "KundSped","KundZoll","KdKontakt")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  switch Typ
  case 0
    ttext:=" - ohne Kunden-Nr."
    exit
  case 1
    ttext:=" - mit Kunden-Nr."
    exit
  case 2
    ttext:=" - Paletten"
    exit
  endswitch

  do while .t.
    cls
    Titel("Adre� - Etiketten  KUNDEN" + ttext)
    Anz:=0
    Anz2:=0

    select Kunden
    MKundNr:=space(len(KUNDEN->KundNr))
    @ 4 ,10 say "Kunden-Nr..........:" get MKundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) } when Message("Kundennummer eingeben.             "+;
      "@F8@=Ansicht    @F12@=Hilfe")
    read

    if ABBRUCH
      exit
    endif

    KunDisp(.f.)

    if typ == ETI_MIT_PALANZ
      Message("Anzahl Paletten eingeben.            @ESC@=Ende")
      setcolor(COLWIN)
      Fenster(14,44,16,70)
      @ 15,46 say "Anzahl Paletten:" get Anz2 Picture "99"
      read
      setcolor(COLNOR)
    else
      Message("Anzahl gew�nschter Etiketten eingeben.            @ESC@=Ende")
      setcolor(COLWIN)
      Fenster(14,4,16,70)
      @ 15,5 say "Anzahl Etiketten:" get Anz Picture "99"
      @ 15,45 say "Anzahl Etiketten:" get Anz2 Picture "99"
      read
      setcolor(COLNOR)
    endif

    if ! ABBRUCH
      Umgebung(WRITE)
      Message("Etiketten werden gedruckt.  Bitte warten...")
      select Kunden
      if Anz>0
        Eti_Adr_druck(typ,.f.,Anz)
      endif
      if Anz2>0
        Eti_Ver_druck(typ,.f.,anz2)
      endif
      Umgebung(LOAD)
    endif

  enddo

  close data
RETURN
/* EOP */

/* Procedure Eti_Adr_Lief****************************************
*
* Adress-Etiketten Lieferanten
*/
PROCEDURE Eti_Adr_Lief
LOCAL MLiefNr,Anz:=0
LOCAL GetList:={}
  eti_show({ || Eti_Lie_druck(.t.) })

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Lieferan" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  cls
  Titel("Adre� - Etiketten  LIEFERANTEN")

  do while .t.
    MLiefNr:=space(len(LIEFERAN->LiefNr))
    @ 2 ,14 say "Lieferanten -Nr....:" get MLiefNr valid { |oGet| check(oGet,"Lieferan",.f.) };
      when Message("Lieferantennummer eingeben.             @F8@=Ansicht    @F12@=Hilfe")
    read

    if ABBRUCH
      exit
    endif

    LieDisp(.f.)
    Message("Anzahl gew�nschter Etiketten eingeben.            @ESC@=Ende")
    setcolor(COLWIN)
    Fenster(14,28,16,60)
    @ 15,30 say "Anzahl Etiketten:" get Anz Picture "99"
    read
    setcolor(COLNOR)
    read

    if ! ABBRUCH .and. Anz > 0
      Message("Etiketten werden gedruckt.  Bitte warten...")
      // for i:=1 to Anz
      Eti_Lie_druck(.f.,anz)
      // next i
    endif
    @ 2,0 clear
  enddo

  close data
RETURN
/* EOP Eti_Repa */



/*
* druckt einzelne Adress-Etiketten
  */
FUNCTION Eti_Adr_Druck(Typ,inShow,Anzahl)
LOCAL Zeile:=0,adresse
  default typ:=ETI_OHNE_KUNDNR
  default inShow:=.f.
  default Anzahl:=1

  adresse:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->Land,;
    KUNDEN->Plz,KUNDEN->Ort)

  if inShow
    Drucker("BS")
  else
    Drucker("ON","Kunden: "+trim(KUNDEN->KundNr),,,,Anzahl)
  endif

  if TYP == ETI_MIT_KUNDNR
    ? KUNDEN->KundNr
  endif

  ? Adresse[1]
  ? Adresse[2]
  ? Adresse[3]
  ? Adresse[4]
  ? Adresse[5]
  ? Adresse[6]

  Drucker("OFF")

RETURN .t.
/* EOP */

/* Procedure Eti_Ver_Druck() **********************************
*
* druckt einzelne Versand-Adress-Etiketten
*
*/
static FUNCTION Eti_Ver_Druck(typ,inShow,Anzahl)
LOCAL Zeile:=0,Adresse,drJobAnz:=1,i,line
LOCAL maxlines:=6

  default typ:=ETI_OHNE_KUNDNR
  default inShow:=.f.
  default Anzahl:=1

  if TYP == ETI_MIT_KUNDNR
    drJobAnz:=anzahl
    anzahl:=1
  elseif Typ == ETI_MIT_PALANZ
    maxlines:=5
  endif

  adresse:=getAdrBlock(KUNDEN->Name2,KUNDEN->Partner2,KUNDEN->Strasse2,KUNDEN->Zusatz2, KUNDEN->Land2,KUNDEN->Plz2,KUNDEN->Ort2,.f.,maxlines)

  for i:=1 to Anzahl
    if inShow
      Drucker("BS")
    else
      Drucker("ON","Versand: "+KUNDEN->KundNr,,,,drJobAnz)
    endif

    if TYP == ETI_MIT_KUNDNR
      ? KUNDEN->KundNr
    endif

    for line:=1 to len(Adresse)
      ? Adresse[line]
    next

    if Typ == ETI_MIT_PALANZ
      ?
      ? "Palette: " + alltrim(str(i,2))+" von "+alltrim(str(Anzahl,2))
    endif
  next

  Drucker("OFF")
RETURN .t.
/* EOP Eti_Ver_Druck() */

/* Procedure Eti_Lie_Druck() **********************************
*
* druckt einzelne Adress-Etiketten LIeferanten
*
*/
FUNCTION Eti_Lie_Druck(inShow,Anzahl)
LOCAL Zeile:=0,Adresse
  default inShow:=.f.
  default Anzahl:=1

  if inShow
    Drucker("BS")
  else
    Drucker("ON","Lieferant: "+LIEFERAN->LiefNr,,,,Anzahl)
  endif

  adresse:=getAdrBlock(LIEFERAN->Name1,LIEFERAN->Name2,LIEFERAN->Strasse,LIEFERAN->Zusatz,;
    LIEFERAN->Land,LIEFERAN->Plz,LIEFERAN->Ort)

  ? Adresse[1]
  ? Adresse[2]
  ? Adresse[3]
  ? Adresse[4]
  ? Adresse[5]
  ? Adresse[6]

  Drucker("OFF")
RETURN .t.
/* EOP Eti_Lie_Druck() */

/* PROCEDURE Eti_Typ
*
* drucke Etiketten je Ger�t (Repa)
*/
PROCEDURE Eti_Typ
LOCAL getList:={} , y
LOCAL M_RepGerNr,EtiAnz:=0
MEMVAR Jahr
PRIVATE Jahr:=space(4)

  eti_show({ || eti_typ_druck(1,.t.)})

  if ! open("Gerat")
    cls
    close data
    RETURN
  endif

  cls
  titel("Etiketten je Typ")

  do while ! ABBRUCH


    @ 4,0 clear
    M_RepGerNr:=space(len(GERAT->RepGerNr))
    Message("Bitte Typ-Nummer eingeben.                 @F8@=Ansicht    @F12@=Hilfe")
    @ 8,18 say "Typ......:" get M_RepGerNr valid { |oGet| check(oGet,"Gerat",.f.,.f.) }
    read

    if ! ABBRUCH
      /* hole Status */
      M->Jahr:=substr(dtoc(getUser():date),4,2)+"."+substr(dtoc(getUser():date),7,2)

      set key K_F10 to GerDisp3()
      GerDisp2(.f.)
      EtiAnz:=0
      Message("Anzahl gew�nschte Etiketten eingeben.    @F10@ = aktuelle Nummer �ndern")
      @ 18,18 say "Anzahl Etiketten:" get EtiAnz Picture "999"
      read
      set key K_F10 to

      if ! ABBRUCH .and. EtiAnz > 0 .and. Message("Etiketten drucken ? (@J@/@N@)","JN")=="J"
        y:=GERAT->Eti_Nr + EtiAnz*4

        eti_typ_druck(etianz)

        select Gerat
        rec_lock(0)
        replace GERAT->Eti_Nr with y
        dbcommit()
        dbunlock()
      endif
    endif
  enddo
  cls
  close data
RETURN
/* EOP Eti_Typ() */

/** druckt einzlenes Etikett je typ */
FUNCTION Eti_typ_druck(etikett,inShow)
LOCAL x,Ende_x , Zeile,i
LOCAL Anzahl:=4
LOCAL EtiAnz:=Etikett*Anzahl
  default inShow:=.f.

  if inShow
    Drucker("BS")
  else
    Drucker("ON","Nietg.")
  endif
  x:=GERAT->Eti_Nr
  Ende_x:=GERAT->Eti_Nr + Etikett
  do while x < Ende_x
    Zeile:=0
    ?
    for i:=1 to Anzahl
      ?? "Typ ",GERAT->RepGerNr+" "
    next
    ?
    for i:=1 to Anzahl
      ?? "========."
    next
    ?
    for i:=1 to Anzahl
      ?? "Ger�te  ."
    next
    ?
    for i:=1 to Anzahl
      ?? "Nr.     ."
    next
    ?
    for i:=1 to Anzahl
      ?? "--------."
    next
    ?
    for i:=1 to Anzahl
      ?? "  "+M->Jahr+" ."
    next
    ?
    for i:=0 to Anzahl-1
      ?? str(x+i*Etikett,7)+" ."
    next
    ?
    x++

    if ! (x < Ende_x)
      exit // avoid FF on last label
    endif

    Zeile:=FormFeed(Zeile)
  enddo
  Drucker("OFF")
RETURN .t.
/* EOF */


/* PROCEDURE Eti_Typ2
*
* drucke Etiketten je Ger�t (Repa)
*/
PROCEDURE Eti_Typ2
LOCAL getList:={}
LOCAL M_RepGerNr,EtiAnz:=0
LOCAL RepArtikel,kom
MEMVAR Jahr
PRIVATE Jahr:=space(4)

  eti_show({ || Eti_2typ_druck(1,"HONSEL",.t.)})

  if ! open("Gerat","LetzteNi","Artikel","Prod")
    cls
    close data
    RETURN
  endif

  /** relationen setzen */
  select Prod
  PROD->(OrdSetFocus(4))
  set relation to PROD->ArtNr into Artikel

  cls
  titel("AV-Etiketten f�r Nietger�te")

  do while ! ABBRUCH


    @ 2,0 clear
    @ 3,16 to 11,60
    M_RepGerNr:=space(len(GERAT->RepGerNr))
    RepArtikel:=space(len(ARTIKEL->ArtNr))
    EtiAnz:=0
    @ 4,18 say "Typ......:" get M_RepGerNr;
      valid { |oGet| check(oGet,"Gerat",.f.,.f.) .and. typDisp() } when Message("Bitte Typ-Nummer "+;
      "eingeben.                 @F8@=Ansicht    @F12@=Hilfe")
    @ 6,18 say "Art.Nr...:" get RepArtikel valid { |oGet| check(oGet,"Artikel",.f.,.f.) };
      when;
      ( Message("Bitte Artikel-Nummer eingeben.                 @F8@=Ansicht    @F12@=Hilfe") .and;
      . autoF12() )
    @ 8,18 say "Anzahl...:" get EtiAnz Picture "999";
      when Message("Anzahl gew�nschte Etiketten eingeben.    @F10@ = aktuelle Nummer �ndern")
    read

    if ! ABBRUCH


      // suche Empf�nger anhand letzte beide Stellen
      LETZTENI->(dbseek(right(ARTIKEL->ArtNr,2)))
      if LETZTENI->(eof())
        kom:="HONSEL"
      else
        kom:=LETZTENI->Text
      endif

      if ! ABBRUCH .and. EtiAnz > 0
        Eti_2typ_druck(etiAnz,kom)
      endif
    endif
  enddo
  cls
  close data
RETURN
/* EOP Eti_Typ2() */

/** druckt einz. Etikett fuer eti_typ2 */
FUNCTION Eti_2typ_druck(EtiAnz,kom,inShow)
LOCAL x,y,Ende_x , Zeile:=0
  default inShow:=.f.

  if inShow
    Drucker("BS")
  else
    Drucker("ON","Nietg.")
  endif
  x:=GERAT->Eti_Nr
  y:=Ende_x:=GERAT->Eti_Nr + EtiAnz
  do while x < Ende_x
    Zeile:=0
    ?? FETT_AN,"* TYP "+GERAT->RepGerNr+" *  "+kom,FETT_AUS
    ? ARTIKEL->Bez1
    ? ARTIKEL->Bez2
    ? Replicate("-",34)
    ? "Artikel Nr. ",FETT_AN,ARTIKEL->ArtNr,FETT_AUS
    ? Replicate("*",34)
    ? " Menge:                 Stck."
    ? Replicate("*",34)

    if ! (x < Ende_x)
      exit // avoid FF on last label
    endif

    Zeile:=FormFeed(Zeile)
    x++
  enddo
  Drucker("OFF")
RETURN .t.
/*EOF*/


/*** Werbegeschenke Etiketten drucken **********************************
*
* Parameter Art    = gew�nschte Geschenkart
*           Anzahl = Anzahl Etiketten
*
*/
PROCEDURE Eti_Werbe(Art)
LOCAL Zeile:=0 , x
LOCAL bis:=""
  if ! open( "Werbung" )
    cls
    close data
    RETURN
  endif

  cls
  titel("Werbegeschenke - Etiketten drucken")

  if empty(bis:=von_bis("Werbung"))
    cls
    close data
    RETURN
  endif
  Message("Bitte warten.        Etiketten werden gedruckt.")

  Drucker("ON","Werbegeschenk: "+WERBUNG->KdNr_werb)
  select Werbung
  go top
  do while .not. eof() .and. left(WERBUNG->KdNr_werb,len(bis)) <= bis
    x:=1
    if &(art) > 0
      do while x <= LISTE->Anzahl
        zeile:=0
        ?? WERBUNG->Adr1 ,space(5) , if(&(art)>1,"("+alltrim(str(&(art),2))+")","")
        ? WERBUNG->Adr2
        ? WERBUNG->Adr3
        ?
        ? WERBUNG->Adr4
        x++
        Zeile:=FormFeed(Zeile)
      enddo
    endif
    skip
  enddo // eof()

  // FIMXE: using Harbour this proce will print an empty label at the end
  // Maybe ignore bug, as method is used once a year!!!

  Drucker("OFF")
  close data

RETURN

/*** Werbegeschenke Etiketten drucken **********************************
*
* Parameter Art    = gew�nschte Geschenkart
*
*/
PROCEDURE Eti_Schmal_Werbe(Art)
LOCAL Zeile:=0 , x , bis
  if ! open( "Werbung" )
    cls
    close data
    RETURN
  endif

  cls
  titel("Werbegeschenke - Etiketten drucken")

  if empty(bis:=von_bis("Werbung"))
    cls
    close data
    RETURN
  endif


  Message("Bitte warten.        Etiketten werden gedruckt.")
  Drucker("ON","Werbegeschenk: "+WERBUNG->KdNr_werb)
  select Werbung
  // set filter to &(art) > 0
  do while .not. eof() .and. left(WERBUNG->KdNr_werb,len(bis)) <= bis
    x:=1
    if &(art) > 0
      do while x <= LISTE->Anzahl
        zeile:=0
        ?? SCHMAL_AN,WERBUNG->Adr1 ,space(5) , if(&(art)>1,"("+alltrim(str(&(art),2))+")","  ")
        ? SCHMAL_AN,WERBUNG->Adr2
        ? SCHMAL_AN,WERBUNG->Adr3
        ?
        ? SCHMAL_AN,WERBUNG->Adr4,SCHMAL_AUS
        Zeile:=FormFeed(Zeile)
        x++
      enddo
    endif
    skip
  enddo // eof()

  // FIMXE: using Harbour this proce will print an empty label at the end

  Drucker("OFF")
  close data

RETURN

FUNCTION eti_show(block)
LOCAL zeile:=0
  _thread static showBlock

  if valtype(block)=="B"
    showBlock:=block
  else
    if valtype(showBlock)<>"B"
      Error(ACHTUNG+"keine Vorschau vorhanden.",.t.)
    else
      Umgebung(WRITE)
      // // FIXME: Etikett
      // M->SpecialZeige:="Etikett"

      @ 1,0 clear
      qout(showBlock)
      eval(showBlock)

      M->SpecialZeige:=NIL
      Umgebung(LOAD)
    endif
  endif

RETURN .t.



/* Procedure Eti_UPSKd ********************************************
*
* druckt Etiketten f�r UPS
*
*/
PROCEDURE Eti_UPSKd
LOCAL Zeile:=0,MKundNr
LOCAL x:=1 // Default 3 falls kein UPS
LOCAL Anzahl:=0,li:=12,ob:=2
LOCAL GetList:={}
LOCAL Ende:=.f.,Adresse
LOCAL Datei:=db_info("Kunden")
  eti_show({ || eti_upsdr(datei, .t.)})


  /* �ffnen der ben�tigten Dateien */
  if ! open( Datei[D_NAME] )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  do while ! Ende
    cls
    select (Datei[D_NAME])
    Titel("UPS - Etiketten "+upper(Datei[D_KURZ]))

    MKundNr:=space(len(KUNDEN->KundNr))
    @ 4 ,10 say "Kunden-Nr..........:" get MKundNr PICTURE KDNR_PICT;
      valid { |oGet| check(oGet,"Kunden",.f.) } when Message("Kundennummer eingeben.             "+;
      "@F8@=Ansicht    @F12@=Hilfe")
    read

    if ABBRUCH
      Ende:=.t.
      loop
    endif

    adresse:=getAdrBlock((DATEI[D_NAME])->Name,(DATEI[D_NAME])->Partner,(DATEI[D_NAME])->Strasse,;
      (DATEI[D_NAME])->Zusatz,(DATEI[D_NAME])->Land,(DATEI[D_NAME])->Plz,;
      (DATEI[D_NAME])->Ort)

    @ ob+4,li-2 to ob+11,li+40
    @ ob+ 5,li get Adresse[1]
    @ ob+ 6,li get Adresse[2]
    @ ob+ 7,li get Adresse[3]
    @ ob+ 8,li get Adresse[4]
    @ ob+ 9,li get Adresse[5]
    @ ob+10,li get Adresse[6]
    clear gets
    @ ob+12,li say "Anzahl:" get Anzahl picture "99"
    read

    if ABBRUCH
      loop
    endif
    for x:=1 to Anzahl
      zeile += eti_upsdr(datei)
    next
  enddo

  // removed 8.6.2011, seems obsolete with new label printer
  // if Zeile > 0
  // Drucker("ON")
  // Zeile:=FormFeed(Zeile)
  // Drucker("OFF")
  // endif


RETURN
/* EOP */


/* Procedure UPS_Eti ********************************************
*
* druckt Etiketten f�r UPS
*
*/
PROCEDURE UPS_Lieferanten
LOCAL Zeile:=0,MLiefNr
LOCAL Anzahl:=0,li:=12,ob:=2,x
LOCAL GetList:={}
LOCAL Ende:=.f.,Adresse
LOCAL Datei:=db_info("Lieferan")
  eti_show({ || eti_upsdr(datei)})


  /* �ffnen der ben�tigten Dateien */
  if ! open( Datei[D_NAME] )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  do while ! Ende
    cls
    select (Datei[D_NAME])
    Titel("UPS - Etiketten "+upper(Datei[D_KURZ]))

    MLiefNr:=space(len(LIEFERAN->LiefNr))
    @ 4 ,10 say "Lieferanten-Nr.....:" get MLiefNr valid { |oGet| check(oGet,"Lieferan",.f.) };
      when Message("Lieferanten-Nummer eingeben.             @F8@=Ansicht    @F12@=Hilfe")
    read

    if ABBRUCH
      Ende:=.t.
      loop
    endif

    adresse:=getAdrBlock((DATEI[D_NAME])->Name1,(DATEI[D_NAME])->Name2,(DATEI[D_NAME])->Strasse,;
      (DATEI[D_NAME])->Zusatz,(DATEI[D_NAME])->Land,(DATEI[D_NAME])->Plz,;
      (DATEI[D_NAME])->Ort)

    @ ob+4,li-2 to ob+11,li+40
    @ ob+ 5,li get Adresse[1]
    @ ob+ 6,li get Adresse[2]
    @ ob+ 7,li get Adresse[3]
    @ ob+ 8,li get Adresse[4]
    @ ob+ 9,li get Adresse[5]
    @ ob+10,li get Adresse[6]
    clear gets
    @ ob+12,li say "Anzahl:" get Anzahl picture "99"
    read

    if ABBRUCH
      loop
    endif
    for x:=1 to Anzahl
      zeile += eti_upsdr(datei)
    next
  enddo


RETURN
/* EOP */

/** Function Ups_dr_lief
 */
Function Eti_Upsdr(datei,inShow)
LOCAL Zeile:=0
LOCAL x:=1 // Default 3 falls kein UPS
LOCAL Adresse
  default inShow:=.f.

  if Datei[D_NAME]=="KUNDEN"
    adresse:=getAdrBlock(KUNDEN->Name,KUNDEN->Partner,KUNDEN->Strasse,KUNDEN->Zusatz, KUNDEN->Land;
      ,KUNDEN->Plz,KUNDEN->Ort)

  else
    adresse:=getAdrBlock(LIEFERAN->Name1,LIEFERAN->Name2,LIEFERAN->Strasse,LIEFERAN->Zusatz,;
      LIEFERAN->Land,LIEFERAN->Plz,LIEFERAN->Ort)
  endif
  if inShow
    Drucker("BS")
  else
    Drucker("On","UPS")
  endif
  // 1xEmpf�nger
  // 1 kleines Etikett mit 2x Empf�nger
  /* Etikett ganz klein doppelt Empf�nger */
  zeile:=0
  ?? KLEIN_AN,left(Adresse[1],25) ,left(Adresse[1],25) ,KLEIN_AUS
  ? KLEIN_AN,left(Adresse[2],25) ,left(Adresse[2],25) ,KLEIN_AUS
  ? KLEIN_AN,left(Adresse[3],25) ,left(Adresse[3],25) ,KLEIN_AUS
  ? KLEIN_AN,left(Adresse[4],25) ,left(Adresse[4],25) ,KLEIN_AUS
  ? KLEIN_AN,left(Adresse[5],25) ,left(Adresse[5],25) ,KLEIN_AUS
  ? KLEIN_AN,left(Adresse[6],25) ,left(Adresse[6],25) ,KLEIN_AUS
  Zeile:=FormFeed(Zeile)

  /* 1 x etikett gross Empf�nger s.u. */
  zeile:=0
  ?? KLEIN_AN,"Empf�nger:",KLEIN_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[1],25) ,SCHMAL_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[2],25) ,SCHMAL_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[3],25) ,SCHMAL_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[4],25) ,SCHMAL_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[5],25) ,SCHMAL_AUS
  ? KLEIN_AN,"          ",KLEIN_AUS,SCHMAL_AN,left(Adresse[6],25) ,SCHMAL_AUS


  Drucker("Off")

Return zeile
/** EOF*/

FUNCTION TypDisp()
  QQout(" "+GERAT->Bezeichn)
RETURN .t.
/** workaround: geht automat. in F12 */
FUNCTION AutoF12()
  keyboard chr(HILFE_TASTE1)
RETURN .t.

/*** Lager Etiketten drucken **********************************
*
*/
PROCEDURE Eti_Lager
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL anzahl,Zeile:=0
  // eti_show({ || eti_vdruck()})

  ignore anzahl

  cls
  titel("Lager - Etiketten drucken")

  /* �ffnen der ben�tigten Dateien */
  if ! open( "Etistru" , "Artikel","AvPost" )
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /* Relationen setzen */
  select Etistru
  set rela to ETISTRU->ArtNr into artikel

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z" // Kopf gesperrt
  // aKopf[EDIT_EXTRA_FKT]:={ { chr(K_F8)," @F8@=Ansicht ", {|| eti_Show()} } }

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Artikel-Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. eti_nach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F8@=Ansicht    @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT ]:=.f.
  aSpalte[EDIT_POS_X]:=4

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Anz"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_POS_X]:=6
  aSpalte[EDIT_MESSAGE]:="Menge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/



  /*** Eingabe / Drucke ****/
  Edit(aFelder,aKopf)
  if reccount() > 0 .and. Message("Etiketten ausdrucken ?  ( J / N )","JN")=="J"
    go top
    Message("Bitte warten.        Etiketten werden gedruckt.")
    do while .not. ETISTRU->(eof())
      Drucker("ON","Eti-Lager"+str(ETISTRU->anz,3)+"x"+OUT(ETISTRU->ArtNr),,,,ETISTRU->anz)
      zeile:=0
      // ?
      ? "Artikel Nr.",BREIT_AN,substr(ARTIKEL->ArtNr,1,3),;
        substr(ARTIKEL->ArtNr,4,3)+"."+substr(ARTIKEL->ArtNr,7),BREIT_AUS
      ? ARTIKEL->Bez1
      ? ARTIKEL->Bez2
      ? "Lag.",getArtikelLagerOrt( ETI_LEN - 6)

      Drucker("OFF")

      skip
    enddo // eof()

  endif

  select Etistru
  zap
  close data
RETURN



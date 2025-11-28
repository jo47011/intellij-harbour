/* Modul: Phoenix.prg
*
* enth�lt alle Sonderregeln / Funktionen zu Ph�nix spez. Artikeln
*
* z.B.
*/

#include "Miki.ch"

#include "excel.ch"
#include "error.ch"

/** Liefert den 1. zugeh. Ober-Artikel, die den �bergebenen Artikel enth�lt
  *
  * AVPOST muss ge�ffnet sein, ist danach an der richtigen Position
  * Ergebnis ist gefundene Art.Nr. oder NIL falls nicht vorhanden.
  */
FUNCTION getParentPhoenix(cArtNr)
LOCAL avpostOrder:=AVPOST->(indexord ())
LOCAL result:=NIL
  if left(cArtNr,len(PHOENIX_TEIL_ARTIKEL)) == PHOENIX_TEIL_ARTIKEL
    AVPOST->(OrdSetFocus(2)) // AVPOST->ArtNr + AVPOST->AvNr
    AVPOST->(dbseek(cArtNr))
    do while ! AVPOST->(eof()) .and. cArtNr == AVPOST->ArtNr
      if left(AVPOST->AvNr,len(PHOENIX_OBER_ARTIKEL)) == PHOENIX_OBER_ARTIKEL
        // FIXME: Artikel darf nur in einer Phoenix St�ckliste vorkommen
        result:=AVPOST->AvNr
        exit
      endif
      AVPOST->(dbskip())
    enddo
    AVPOST->(OrdSetFocus(avpostOrder))
  endif
Return result
/** eof */

/** Liefert den 1. zugeh. Ph�nix Unter-Artikel aus der Material-St�ckliste
  *
  * AVPOST muss ge�ffnet sein, ist danach an der richtigen Position
  * Ergebnis ist gefundene Art.Nr. oder NIL falls nicht vorhanden.
  */
FUNCTION getSonPhoenix(cArtNr)
LOCAL avpostOrder:=AVPOST->(indexord ())
LOCAL result:=NIL
  if left(cArtNr,len(PHOENIX_OBER_ARTIKEL)) == PHOENIX_OBER_ARTIKEL
    AVPOST->(OrdSetFocus(1)) // AVPOST->AvNr + AVPOST->ArtNr
    AVPOST->(dbseek(cArtNr))
    do while ! AVPOST->(eof()) .and. cArtNr == AVPOST->AvNr
      if left(AVPOST->ArtNr,len(PHOENIX_TEIL_ARTIKEL)) == PHOENIX_TEIL_ARTIKEL
        // FIXME: Artikel darf nur in einer Phoenix St�ckliste vorkommen
        result:=AVPOST->ArtNr
        exit
      endif
      AVPOST->(dbskip())
    enddo
    AVPOST->(OrdSetFocus(avpostOrder))
  endif
Return result
/** eof */

/** liefert true/fals ob ein Artikel ein Ph�nix-OberArtikel ist (305er Phoenix) */
function isPhoenixOberArtikel(cArtnr)
return left(cArtNr,len(PHOENIX_OBER_ARTIKEL)) == PHOENIX_OBER_ARTIKEL
/** eof */

/** liefert true/fals ob ein Artikel ein Ph�nix-UnterArtikel ist (310er Phoenix) */
  // ACHTUNG: Identifizierung so NICHT m�glich, es gibt auch andere 310er Artikel 12.5.16
  // function isPhoenixUnterArtikel(cArtnr)
  // return left(cArtNr,len(PHOENIX_TEIL_ARTIKEL)) == PHOENIX_TEIL_ARTIKEL
/** eof */


/** pr�ft ob ein Auftrag (AUFTRAG.dbf) einen Ph�nix-Artikel 305er enth�lt */
function isPhoenixAuftrag()
LOCAL aktRec:=AUFTRAG->(recno())
LOCAL result
LOCAL aktSel:=alias()
  select Auftrag
  loca for isPhoenixOberArtikel( AUFTRAG->ArtNr )
  result:=! AUFTRAG->(eof())
  AUFTRAG->(dbgoto( aktRec ))
  select( aktSel )
return result
/** eof */

function checkePhoenixFracht(oGet)
LOCAL s01
  if (len(alltrim(AUFTRAG->ArtNr)) <= FRACHT_LAENGE .and. isPhoenixAuftrag() .and. ;
    ! isPhoenixPauschaleArtikel(AUFTRAG->ArtNr))
    if val(oGet:buffer) <> 0
      s01:=savescreen()
      Error(ACHTUNG+" Ph�nix Artikel enthalten bereits Fracht & Verpackung.",.f.)
      if Message("Preis trotzdem berechnen? (@J@/@N@)","JN") <> "J"
        oGet:varput(0)
        oGet:updateBuffer()
      endif
      restscreen(,,,,s01)
    endif
  endif
return .t.
/** eof */


/*
* erfassen und anzeigen der Speditionen je Kunde
*/
FUNCTION KundSpedit()
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL okay, deSpedNr

  Umgebung(WRITE_ALL)

  if ! open( "KundSped","Spedit","Kunden","KdSpedTemp","Artikel","KundZoll")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN("")
  endif

  select KdSpedTemp
  zap
  set relation to KDSPEDTEMP->SpedNr into Spedit

  /* hole alle Speditionen des Kundens */
  select KundSped
  KUNDSPED->(dbseek(KUNDEN->KundNr))
  do while ! KUNDSPED->(eof()) .and. KUNDSPED->KundNr == KUNDEN->KundNr
    select KdSpedTemp
    add_rec(0)
    overwrite( "KundSped" )
    select KundSped
    skip
  enddo

  select KdSpedTemp
  aFelder:={}
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_LM]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=5 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"

  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ "K"," @K@opieren", { || KundSpedCopy() } } )
  aadd(aKopf[EDIT_EXTRA_FKT],{ "Z"," @Z@ollstellen", { || KundZollstellen() } } )
  // aadd(aKopf[EDIT_EXTRA_FKT],{ "A�","", { || bestkartEdit() } } )

  aKopf[EDIT_DRAW_FRAME]:="Spedition/Paket-Dienstleister"

  aKopf[EDIT_NEW_FKT]:={ || _FIELD->KDSPEDTEMP->KundNr:=KUNDEN->KundNr }

  // 20160307 wieder raus -> s. fkt.old
  // aKopf[EDIT_AFTER_EDIT_FKT]:={ || checkHofmann() }

  // /* Fenster-Rahmen */
  // setcolor(COLWIN)
  // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]-1 clear to aKopf[EDIT_ENDE_Y]+1,aKopf[EDIT_RM]+1
  // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]+25 say "L i e f e r a n t e n"
  // setcolor(COLNOR)


  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="SpedNr"
  aSpalte[EDIT_TITEL]:="Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Spedit",.f.,.t.) }
  aSpalte[EDIT_MESSAGE]:="Speditions-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="SPEDIT->Kurzname"
  aSpalte[EDIT_TITEL]:="Name/Bemerk./Kd.Nr."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Bemerk1"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_MESSAGE]:="Bemerkung 1. Zeile eingeben."
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Bemerk2"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_MESSAGE]:="Bemerkung 2. Zeile eingeben."
  aSpalte[EDIT_POS_Y]:=2 // 3. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Kd.Nr.:'"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=3 // 4. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="SpedKdNr"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_MESSAGE]:="Kundennummer bei Spedition eingeben."
  aSpalte[EDIT_POS_X]:=8
  aSpalte[EDIT_POS_Y]:=3 // 4. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Art"
  aSpalte[EDIT_NAME_GET]:="KDSPEDTEMP->Art"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MASKE]:="@K!!"
  aSpalte[EDIT_AFTER]:={ |oGet| kundSpeditNachArt(oGet) }
  aSpalte[EDIT_MESSAGE]:="Art eingeben.   @PK@=Pauschale Karton  @PP@=Pauschale Palette      @F12@ = Hilfe"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Frei"
  aSpalte[EDIT_TITEL]:="Frei"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_BEFORE]:={ || ! KDSPEDTEMP->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON}
  aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer $ "JN" }
  aSpalte[EDIT_MESSAGE]:="@J@ = Frei senden, Fracht berechnen."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Zollstellen: ' + left(getKdSpedZollstellen(),39)"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=3 // 4. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="EK"
  aSpalte[EDIT_TITEL]:="EK-Fr."
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_BEFORE]:={ || KDSPEDTEMP->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON}
  aSpalte[EDIT_MESSAGE]:="Einkaufspreis eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| calcVersandPauschale(oGet) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Aufschlag"
  aSpalte[EDIT_TITEL]:="Aufschlag"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_BEFORE]:={ || KDSPEDTEMP->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON}
  aSpalte[EDIT_MESSAGE]:="Aufschlag Verwaltungskosten in Euro eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| calcVersandPauschale(oGet) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Versand"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_BEFORE]:={ || KDSPEDTEMP->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON}
  aSpalte[EDIT_MESSAGE]:="Aufschlag Versand- & Verpackungskosten in Euro eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| calcVersandPauschale(oGet) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="if(empty(ArtNr),'','Art.Nr:' + ArtNr)"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_POS_X]:=10

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  aSpalte[EDIT_NAME]:="KalkPreis"
  aSpalte[EDIT_TITEL]:="Kalk.Pr."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="VK"
  aSpalte[EDIT_TITEL]:="VK"
  aSpalte[EDIT_BEFORE]:={ || KDSPEDTEMP->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON}
  aSpalte[EDIT_MESSAGE]:="Verkaufspreis eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  okay:=.f.
  do while ! okay
    Edit(aFelder,aKopf)

    // pr�fe ob VK > Kalk.Preis
    deSpedNr:=getProperty("Miki.phoenix.spedition.DE","")
    loca for KDSPEDTEMP->KalkPreis > KDSPEDTEMP->VK .and. KDSPEDTEMP->spedNr <> deSpedNr

    if KDSPEDTEMP->(eof()) .or. ! aKopf[EDIT_CHANGED]
      okay:=.t.
    else
      okay:=Message("Achtung VK kleiner als Kalk.Preis.  Trotzdem beenden? (@J@/@N@)","JN","N")=="J"
    endif
  enddo

  select Kunden
  dbcommit()
  dbunlock()

  // r�ckschreiben nach SpedKund
  if aKopf[EDIT_CHANGED]
    select KundSped
    KUNDSPED->(dbseek(KUNDEN->KundNr))
    do while ! KUNDSPED->(eof()) .and. KUNDSPED->KundNr == KUNDEN->KundNr
      rec_lock(0)
      delete
      skip
    enddo

    // h�nge neu an
    KDSPEDTEMP->(dbgotop())
    append("KDSPEDTEMP",{ || .t. })
    dbcommitall()
    dbunlockall()
  endif

  Umgebung(LOAD)

RETURN .t.
/* eof */

static function kundSpeditNachArt(oGet)
LOCAL propPauschale, propArtikel, mArtNr
LOCAL aktRec:=KDSPEDTEMP->(recno()), s01

  if oGet:changed

    if ! empty(oGet:buffer) .and. ! oGet:buffer $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON
      return .f.
    endif

    SPEDIT->(dbseek( KDSPEDTEMP->SpedNr ))
    if oGet:buffer $ PAUSCHALE_PALETTE .and. SPEDIT->SpedKz == "N"
      Error(ACHTUNG+"Spedition ist als Paketdienstleister markiert.||"+;
        "         Eingabe nicht m�glich.")
      return .f.
    elseif oGet:buffer $ PAUSCHALE_KARTON .and. SPEDIT->SpedKz == "J"
      Error(ACHTUNG+"Spedition ist nicht als Paketdienstleister markiert.||"+;
        "         Eingabe nicht m�glich.")
      return .f.
    endif

    // pr�fe ob Art bereits zugewiesen
    if ! empty(oGet:buffer)
      loca for KDSPEDTEMP->Art == oGet:Buffer .and. KDSPEDTEMP->(recno()) <> aktRec
      if ! KDSPEDTEMP->(eof())
        KDSPEDTEMP->(dbgoto( aktRec ))
        Error(ACHTUNG+ oGet:Buffer + " kann nur 1x zugewiesen werden.")
        return .f.
      endif
      KDSPEDTEMP->(dbgoto( aktRec ))
    endif

    // Paletten innerhalb Deutschland -> immer Sped.Hofmann -> ansonsten Hinweis
    if left(KUNDEN->Land2,2) == DEUTSCH_LAND .and. KDSPEDTEMP->Art == PAUSCHALE_PALETTE

      // pr�fe auf Hofmann
      if KDSPEDTEMP->SpedNr <> getProperty("Miki.phoenix.spedition.DE","")
        s01:=savescreen()
        Error(ACHTUNG+"Spedition in Deutschland f�r Ph�nix-Artikel weicht ab.|"+;
          "         Bitte beim Kunden oder miki.cfg �ndern.|"+;
          "         bei Kunde: " + KDSPEDTEMP->SpedNr + " config: " + ;
          getProperty("Miki.phoenix.spedition.DE","") , ERR_NO_WAIT)
        if Message("Trotzdem fortfahren?  (@J@/@N@)","JN","N") <> "J"
          restscreen(,,,,s01)
          return .f.
        endif
        restscreen(,,,,s01)
      endif
    endif


    // hole Pauschale & Versandartikel aus config Datei
    if KDSPEDTEMP->Art == PAUSCHALE_KARTON
      propPauschale:="Miki.kunden.paketdienst.aufschlag"
      propArtikel:="Miki.kunden.paketdienst.artikel"
    elseif KDSPEDTEMP->Art == PAUSCHALE_PALETTE
      propPauschale:="Miki.kunden.spedition.aufschlag"
      propArtikel:="Miki.kunden.spedition.artikel"
    else
      // keine Pauschale also alles zur�ck setzen und raus
      replace KDSPEDTEMP->Aufschlag with 0
      replace KDSPEDTEMP->ArtNr with ""
      replace KDSPEDTEMP->Versand with 0
      return .t.
    endif

    // innerdeutsch / EU Kunde oder restl. Welt?
    if KUNDEN->EG $ "J"
      propPauschale += ".EU"
      propArtikel += ".EU"
    elseif KUNDEN->EG $ "D"
      propPauschale += ".DE"
      propArtikel += ".DE"
    endif

    replace KDSPEDTEMP->Aufschlag with val(getProperty(propPauschale,"0"))

    mArtNr:=ShiftArtikel(getProperty(propArtikel,""))
    ARTIKEL->(dbseek(mArtNr))
    if ARTIKEL->(eof())
      Error(ACHTUNG + "Artikel: " + mArtNr + "("+propArtikel+") nicht gefunden.|" +;
        "           Bitte anlegen.",.t.)
      replace KDSPEDTEMP->ArtNr with ""
      replace KDSPEDTEMP->Versand with 0
      return .f.
    else
      replace KDSPEDTEMP->ArtNr with ARTIKEL->ArtNr
      replace KDSPEDTEMP->Versand with ARTIKEL->Preis1 // VK
    endif
    replace KDSPEDTEMP->Frei with "N"

    calcVersandPauschale(oGet)

  endif

return .t.
/** eof */

static function calcVersandPauschale(oGet)
  if (oGet:changed)
    oget:assign()
    replace KDSPEDTEMP->KalkPreis with KDSPEDTEMP->EK + KDSPEDTEMP->Aufschlag + KDSPEDTEMP->Versand
  endif
return .t.
/** eof */

/** Preisliste Ph�nix Artikel und Versandkosten je Standort */
Procedure PhoenixArtikelPreisListe(details)
LOCAL DateiName:="Phoenix-Artikel"
LOCAL objErr , export , cols, ExcelJob
LOCAL zeile:=0 , mArtNr , farbe , x , mBez2
LOCAL feldMenge, feldPreis, stop:=.f., Seite:=0, rab
LOCAL verkauftOnly:=.f.

  cls
  Titel("Ph�nix Preis-Liste (Artikel)")

  if ! open("Artikel","Rabatt","Mat_KZ")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if details
    DateiName += "-Miki"
    verkauftOnly:=Message("Nur verkaufte Artikel anzeigen? (@J@/@N@)","JN","N")=="J"
  endif

  export:=Druck_Bs(DateiName , .t.)

  if ABBRUCH .or. ( valtype(export) == "L" .and. ! export )
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten.")

  BEGIN SEQUENCE // krit. Bereich

    if valtype(export)=="C"
      export:=getUser():exportPATH() + BACKSLASH + export
      excelJob:=ExcelJob():new()
      getUser():setCurrentPrintJob(excelJob)
      getUser():getCurrentPrintJob():StartDoc( export )
    endif

    /*** Liste mit ArtikelPreisen je Menge / Rabattstaffel */
    select Artikel
    set filter to isPhoenixOberArtikel( ARTIKEL->ArtNr ) .and. getArtikelArt() $ "FM" .and. ;
      (! verkauftOnly .or. ARTIKEL->verkauft > 0)
    go top
    do while ! ARTIKEL->(eof())
      seite++
      if valtype(export) <> "C"
        ? "Ph�nix-Artikel Preisliste vom ",getUser():Date,space(32),"Seite:"+str(Seite,3)
        ? replicate("=",82)
        ? "Art.Nr.  ", "Bezeichung",space(26),"VPE (Stk)"
        if details
          ?? "Verkauft (VPE)"
        endif
        ? replicate("=",82)
      else
        ? "Art.Nr.  ", "Bezeichung","","VPE (Stk)"
        if details
          ?? "Verkauft (VPE)"
        endif
      endif

      do while ! ARTIKEL->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        RABATT->(dbseek( ARTIKEL->RabattGr ))

        if substr(ARTIKEL->ArtNr,7,1) == "0"
          farbe:="hellgrau"
          mArtNr:=ARTIKEL->ArtNr
          mBez2:=ARTIKEL->Bez2
          // mBez2:=left( ARTIKEL->Bez2 , at( "hellgrau" , ARTIKEL->Bez2 ) - 1)
        else
          farbe:="Farbe   "
          mArtNr:=ARTIKEL->ArtNr
          mBez2:=ARTIKEL->Bez2
          // mBez2:=left( ARTIKEL->Bez2 , at( "elfenbein" , ARTIKEL->Bez2 ) - 1)
        endif

        if valtype(export)=="C"
          ? "'"+out(mArtNr),getArtikelText(),Farbe , ARTIKEL->Inhalt
          if details
            ?? ARTIKEL->verkauft
          endif
        else
          ? out(mArtNr),ARTIKEL->Bez1,Farbe , ARTIKEL->Inhalt
          if details
            ?? ARTIKEL->verkauft
          endif
          ? space(len(out(mArtNr))),mBez2

          if ! empty( ARTIKEL->MatKz )
            MAT_KZ->(dbseek( ARTIKEL->MatKz ))
            aEval(HB_ATokens( MAT_KZ->MkzText , MY_CR+;
              MY_LF),;
              {;
              |x|;
              if(empty(x),nil,getUser():getCurrentPrintJob():print({space(len(out(ARTIKEL->ArtNr));
              ),x},.t.)),zeile++,.t. })
          endif

        endif

        ?
        ? space(len(out(mArtNr))),"   St�ck","  Menge","  Rabatt","          VK      "
        if details
          ?? space(0)," Marge%","    Diff."
        endif
        ? space(len(out(mArtNr))),"        ","  (VPE)","        ","(VPE inkl. Karton)"
        if valtype(export)=="C"
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 2):HorizontalAlignment:=xlHAlignRight
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 4):HorizontalAlignment:=xlHAlignRight
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 5):HorizontalAlignment:=xlHAlignRight
        endif
        ? space(len(out(mArtNr))) , str( ARTIKEL->Inhalt , 8 , 0 ), str(1,7),space(8),ARTIKEL->Preis1 ,;
          EURO_SIGN + space(4)

        // Marge
        if details .and. ARTIKEL->KaPr <> 0
          ?? str(ARTIKEL->Preis1 / ARTIKEL->KaPr * 100 - 100 , 7 , 2 ) + "%" ,;
            str(ARTIKEL->Preis1 - ARTIKEL->KaPr , 8 , 2) , EURO_SIGN
        endif

        // drucke Rabatte
        feldMenge="RABATT->Meng1"
        x:=0
        do while x < 10 .and. &FeldMenge > 0
          x=x+1
          feldMenge="RABATT->Meng"+str(x,1)
          feldPreis="RABATT->Preis"+str(x,1)
          rab:=100 - 100 * &("RABATT->Preis"+str(x,1)) / ARTIKEL->Preis1

          if &FeldMenge > 0
            ? space(len(out(mArtNr))) , str(&(feldMenge) * ARTIKEL->Inhalt , 8,0) , ;
              &(feldMenge) , str(rab,7,2)+"%" , &(feldPreis) , EURO_SIGN + space(4)

            // Marge
            if details .and. ARTIKEL->KaPr <> 0
              ?? str(&(feldPreis) / ARTIKEL->KaPr * 100 - 100 , 7 , 2 ) + "%" ,;
                str(&(feldPreis) - ARTIKEL->KaPr , 8 , 2) , EURO_SIGN
            endif

          endif
        enddo
        ?
        skip
        Stop:=stop_key()
      enddo

      if ARTIKEL->(eof())
        ?
        ? "Die ausgewiesenen Preise sind Nettopreise in Euro und verstehen sich"
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ? "zuz�glich der gesetzlichen Mehrwertsteuer."
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ?
        ? "VPE = Verpackungseinheit (packaging unit)"
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

      endif

      Zeile:=FormFeed(Zeile,Seite)

    enddo

    if valtype(export)=="C"
      // set width of description column (autowrap)
      getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=40
    endif

    drucker("OFF")

    if valtype(export)=="C"
      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
    endif

  RECOVER USING objErr
    Error("Fehler Excel Export: "+objErr:description , .t.)
  END SEQUENCE

  close data

return
/** eop */

/** Preisliste Ph�nix Artikel und Versandkosten je Standort */
Procedure PhoenixVersandPreisListe()
LOCAL DateiName:="Phoenix-Versand"
LOCAL objErr , mLand , export, excelJob, cols, mitVersand:="N"
LOCAL zeile:=0, pp,pk
LOCAL stop:=.f., Seite:=0
LOCAL spedNrPaletten:=getProperty("Miki.phoenix.spedition.DE","")
LOCAL landKZ:=space(2)
LOCAL GetList:={}

  cls
  Titel("Ph�nix Preis-Liste (Versand-Pauschale)")

  if ! mkMyDir(getUser():exportPATH())
    return
  endif

  if ! open("Kunden","KundSped","Land","Artikel")
    Error(TRY_AGAIN)
    close data
    return
  endif

  @ 8,26 to 13,54
  Message("Land eingeben.    @F12@=Auswahl   @Leer@=Alle")
  @ 9,28 say "Land...........:" get landKZ picture "!!" valid {|oget| check(oget,"Land",.t.,.f.)} ;
    when Message("L�nderk�rzel eingeben.  @Leer@=Alle   @F12@=Auswahl")
  @ 11,28 say "Versandadressen:" get mitVersand picture "!" valid mitVersand $ "JN" ;
    when Message("Versandadressen 12345-XX anzeigen? (@J@/@N@)")
  read

  if ABBRUCH
    close data
    return
  endif

  if ! empty(landKZ)
    @ 9,28 say left(LAND->Name,26)
  endif

  export:=Druck_Bs(DateiName , .t.)

  if ABBRUCH .or. ( valtype(export) == "L" .and. ! export )
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten.")

  BEGIN SEQUENCE // krit. Bereich

    if valtype(export)=="C"
      export:=getUser():exportPATH() + BACKSLASH + export
      excelJob:=ExcelJob():new()
      getUser():setCurrentPrintJob(excelJob)
      getUser():getCurrentPrintJob():StartDoc( export )
    endif

    /*** Liste mit Versandpauschale je Kunde & Spedition */
    select KundSped
    set filter to KUNDSPED->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON

    select Kunden
    set rela to KUNDEN->KundNr into KundSped
    index on KUNDEN->Land2 + KUNDEN->KurzName tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for ! KUNDSPED->(eof()) .and. ( empty(landKZ) .or. landKZ == KUNDEN->Land2 ) ;
      .and. ( mitVersand=="J" .or. empty(right(KUNDEN->KundNr,2)))

    go top
    do while ! KUNDEN->(eof())
      seite++
      if valtype(export) <> "C"
        ? "Ph�nix-Versand Preisliste vom ",getUser():Date,space(20),"Seite:"+str(Seite,3)
        ? replicate("=",70)
        ? "Kund.Nr. Name/Adresse                         Pauschale      Pauschale"
        ? "                                             pro Karton    pro Palette"
        ? replicate("=",70)
      else
        if Seite == 1
          ? "Kund.Nr.","Name/Adresse","","Pauschale pro Karton","","","Pauschale pro Palette",""
        endif
      endif
      ?

      do while ! KUNDEN->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        // Drucke Land
        if mLand <> KUNDEN->Land2
          mLand:=KUNDEN->Land2
          LAND->(dbseek( mLand ))
          ? FETT_AN,LAND->LandKZ,LAND->Name,FETT_AUS
          ?
        endif

        // hole Pauschalen
        pp:=pk:=0
        do while KUNDSPED->KundNr == KUNDEN->KundNr
          if KUNDSPED->Art == PAUSCHALE_PALETTE
            pp:=KUNDSPED->VK

            // Ausnahme 109 Hofmann in Deutschland, das bezahlt Ph�nix
            if spedNrPaletten == KUNDSPED->SpedNr .and. KUNDEN->EG == "D"
              // pp:=KUNDSPED->Aufschlag + KUNDSPED->Versand
              pp = NIL // ge�ndert am 17.5.2016, alle immer 0, dann extra Text am Ende
            endif

          elseif KUNDSPED->Art == PAUSCHALE_KARTON
            pk:=KUNDSPED->VK
          endif
          KUNDSPED->(dbskip())
        enddo

        ? KUNDEN->KundNr,KUNDEN->Name,
        ? space(len(KUNDEN->KundNr)),KUNDEN->Partner,space(1),transstr(PK,7,2),EURO_SIGN,;
          space(4)
        if (pp != NIL )
          ?? transstr(PP,7,2),EURO_SIGN
        else
          ?? space(6)+"*"
        endif
        ? space(len(KUNDEN->KundNr)),KUNDEN->Strasse
        ? space(len(KUNDEN->KundNr)),KUNDEN->Zusatz
        ? space(len(KUNDEN->KundNr)),KUNDEN->land + " " + KUNDEN->Plz + KUNDEN->Ort
        ?

        if ! KUNDEN->EG $ "DJ"
          ? space(len(KUNDEN->KundNr)),FETT_AN,"Zollzuschlag pro Lieferung" + space(5),FETT_AUS
          ARTIKEL->(dbseek( ShiftArtikel( getProperty("Miki.zoll.aufschlag.klein","") )))
          ?? space(1),str(ARTIKEL->Preis1,10,2) ,EURO_SIGN
          ARTIKEL->(dbseek( ShiftArtikel( getProperty("Miki.zoll.aufschlag.gross","") )))
          ?? space(1),str(ARTIKEL->Preis1,10,2) ,EURO_SIGN

          // Hinweis ab Karton Zuschlag erst ab Summe x (z.Zt. 1000 Euro)
          ? space(len(KUNDEN->KundNr)),space(20),space(8),"falls Gesamtwert"
          ? space(len(KUNDEN->KundNr)),space(20),space(16),"> "+;
            getProperty("Miki.zoll.aufschlag.limit","0") , EURO_SIGN
          ?

          // Hinweis EUR1 Zuschlag ab Summe y (z.Zt. 6000 Euro)
          ARTIKEL->(dbseek( ShiftArtikel( getProperty("Miki.zoll.aufschlag.EUR1","") )))
          ? space(len(KUNDEN->KundNr)),FETT_AN,"Zuschlag f�r EUR1-Erkl�rung" + space(4) , FETT_AUS
          ?? space(1),str(ARTIKEL->Preis1,10,2) ,EURO_SIGN
          ?? space(1),str(ARTIKEL->Preis1,10,2) ,EURO_SIGN
          ? space(len(KUNDEN->KundNr)),space(20),space(8),"falls Gesamtwert" ,space(0),;
            space(0),"falls Gesamtwert"
          ? space(len(KUNDEN->KundNr)),space(20),space(16),"> "+;
            getProperty("Miki.zoll.aufschlag.EUR1.limit","0") , EURO_SIGN, space(5),;
            "> " + getProperty("Miki.zoll.aufschlag.EUR1.limit","0") , EURO_SIGN
          ?

        endif

        skip
        Stop:=stop_key()
      enddo

      // Hinweis auf letzte Seite
      if KUNDEN->(eof())
        // ?
        // ? "F�r den Versand in nicht EU-L�nder wird zus�tzlich je Lieferung ein"
        // if valtype(export)=="C"
        // cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
        // excelJob:oSheet:Range(cols):merge()
        // endif

        // ARTIKEL->(dbseek( ShiftArtikel( getProperty("Miki.zoll.aufschlag","") )))
        // ? "Zoll-Aufschlag in H�he von "+alltrim(str(ARTIKEL->Preis1)) + " Euro f�llig."
        // if valtype(export)=="C"
        // cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
        // excelJob:oSheet:Range(cols):merge()
        // endif

        ?
        ? "Die ausgewiesenen Preise sind Nettopreise in Euro und verstehen sich"
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ? "zuz�glich der gesetzlichen Mehrwertsteuer."
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ?
        ? "* = wird durch Spedition Hofmann direkt mit Ph�nix abgerechnet."
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

      endif

      Zeile:=FormFeed(Zeile,Seite)
    enddo

    drucker("OFF")

    if valtype(export)=="C"
      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
    endif

  RECOVER USING objErr
    Error("Fehler Excel Export: "+objErr:description , .t.)
  END SEQUENCE

  close data

return
/** eop */

/** pr�ft ob eine Artikel-Nr zu den automatisch hinzugef�gten Artikeln geh�rt */
function isPhoenixPauschaleArtikel(mArtNr)
return isPhoenixSpeditionsArtikel(mArtNr) .or. isPhoenixPaketdienstArtikel(mArtNr)
/** eof */

/** pr�ft ob eine Artikel-Nr zu den automatisch hinzugef�gten Artikeln geh�rt */
function isPhoenixSpeditionsArtikel(mArtNr)
  mArtNr:=alltrim( mArtNr )

  if getProperty("Miki.kunden.spedition.artikel.DE") == mArtNr
    return .t.
  endif

  if getProperty("Miki.kunden.spedition.artikel.EU") == mArtNr
    return .t.
  endif

  if getProperty("Miki.kunden.spedition.artikel") == mArtNr
    return .t.
  endif

return .f.
/** eof */

/** pr�ft ob eine Artikel-Nr zu den automatisch hinzugef�gten Artikeln geh�rt */
function isPhoenixPaketdienstArtikel(mArtNr)
  mArtNr:=alltrim( mArtNr )

  if getProperty("Miki.kunden.paketdienst.artikel.DE") == mArtNr
    return .t.
  endif

  if getProperty("Miki.kunden.paketdienst.artikel.EU") == mArtNr
    return .t.
  endif

  if getProperty("Miki.kunden.paketdienst.artikel") == mArtNr
    return .t.
  endif

return .f.
/** eof */


/** liefert die hinterlegte Artikel-Nr f�r Ph�nix Pauschalen f�r Paletten */
function getPhoenixArtikelPauschalePalette(mLand)
LOCAL result:=""

  LAND->(dbseek( mLand ))
  switch LAND->EU
  case "D"
    result:=getProperty("Miki.kunden.spedition.artikel.DE","")
    exit
  case "J"
    result:=getProperty("Miki.kunden.spedition.artikel.EU","")
    exit
  otherwise
    result:=getProperty("Miki.kunden.spedition.artikel","")
    exit
  endswitch

return result
/** eof */

/** liefert die hinterlegte Artikel-Nr f�r Ph�nix Pauschalen f�r Kartons */
function getPhoenixArtikelPauschaleKarton(mLand)
LOCAL result:=""

  LAND->(dbseek( mLand ))
  switch LAND->EU
  case "D"
    result:=getProperty("Miki.kunden.paketdienst.artikel.DE","")
    exit
  case "J"
    result:=getProperty("Miki.kunden.paketdienst.artikel.EU","")
    exit
  otherwise
    result:=getProperty("Miki.kunden.paketdienst.artikel","")
    exit
  endswitch

return result
/** eof */

/** liefert die Versandpauschale hinterlegt beim Kunden/Spedition (KUNDSPED) */
function selectPhoenixPauschale(mKundNr,mArt)
LOCAL result:=.f.
LOCAL aktSel:=alias()

  select KundSped
  KUNDSPED->(dbseek( mKundNr ))
  do while KUNDSPED->KundNr == mKundNr .and. ! KUNDSPED->(eof())
    if KUNDSPED->Art == mArt
      result:=.t.
      exit
    endif
    skip
  enddo

  select (aktSel)

return result
/** eof */

/** liefert die Anzahl der ben�tigten Paletten f�r die angegebene Anzahl Kartons */
function kartons2paletten( anzKartons )
LOCAL kartonsProPalette:=val( getProperty("Miki.phoenix.kartons.palette",20) )
LOCAL anzPaletten:=int( anzKartons / kartonsProPalette )

  // addiere 1 Palette f�r restl. Kartons
  if AnzKartons - (anzPaletten * kartonsProPalette) > 0
    anzPaletten++
  endif
return anzPaletten
/** eof */

/** listet break even Karton vs Paletten Versand aller Kunden-Speditionen mit PP und PK */
Procedure PhoenixKartonVsPalette()
LOCAL zeile:=0, pp,pk,ppName,pkName
LOCAL stop:=.f., Seite:=0, anzahl

  cls
  Titel("Karton vs Palette - Ph�nix Preis-Liste")

  if ! open("Kunden","KundSped","Spedit","Artikel")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if ! Druck_BS()
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten.")

  /*** Liste mit Versandpauschale je Kunde & Spedition */
  select KundSped
  set filter to KUNDSPED->Art $ PAUSCHALE_PALETTE + "a" + PAUSCHALE_KARTON

  select Kunden
  set rela to KUNDEN->KundNr into KundSped
  index on KUNDEN->Land2 + KUNDEN->KurzName tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for ! KUNDSPED->(eof())

  go top
  do while ! KUNDEN->(eof())
    seite++
    ? "Karton vs. Palette ",getUser():Date,space(48),"Seite:"+str(Seite,3)
    ? replicate("=",87)
    ? "Kund.Nr. Name                                 max. Anzahl          Preis          Preis"
    ? "                                                  Kartons        Kartons      1 Palette"
    ? replicate("=",87)

    do while ! KUNDEN->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

      // hole Pauschalen
      pp:=pk:=0
      do while KUNDSPED->KundNr == KUNDEN->KundNr
        SPEDIT->(dbseek( KUNDSPED->SpedNr ))
        if KUNDSPED->Art == PAUSCHALE_PALETTE
          pp:=KUNDSPED->VK
          ppName:=SPEDIT->Name
        elseif KUNDSPED->Art == PAUSCHALE_KARTON
          pk:=KUNDSPED->VK
          pkName:=SPEDIT->Name
        endif
        KUNDSPED->(dbskip())
      enddo

      // berechne die Anzahl max. Kartons / break even f�r Paletten
      anzahl:=int( PP / PK )

      ? KUNDEN->KundNr,KUNDEN->Name,space(1),anzahl, anzahl*PK,EURO_SIGN,space(4),PP,EURO_SIGN
      ? space(len(KUNDEN->KundNr)), PAUSCHALE_KARTON , str(pk,7,2),pkName
      ? space(len(KUNDEN->KundNr)), PAUSCHALE_PALETTE , str(pp,7,2),ppName
      ?

      // if ! KUNDEN->EG $ "DJ"
      // ? space(len(KUNDEN->KundNr)),FETT_AN,"Zollzuschlag pro Lieferung" + space(12),FETT_AUS,;
      // space(1),getProperty("Miki.zoll.aufschlag.klein",""),EURO_SIGN,;
      // space(4),getProperty("Miki.zoll.aufschlag.gross",""),EURO_SIGN
      // ?
      // endif

      skip
      Stop:=stop_key()
    enddo

    Zeile:=FormFeed(Zeile,Seite)
  enddo

  drucker("OFF")

  close data

return
/** eop */

/** 42. my test procedure */
Procedure PhoenixExcelDatei()
LOCAL oExcel , oas, i ,artikelNr, Dateiname, newName
LOCAL startZeile:=6

  Titel("Ph�nix Excel Datei Abgleich")

  if (Dateiname:=openFileDialog(LOAD,IMPORT,NIL,"xls*",nil))==NIL
    close data
    return
  endif

  if open( "Artikel","Rabatt")
    IF ( oExcel:=openExcelWorkbook( dateiName ) ) != nil
      oAS:=oExcel:ActiveSheet()

      Message("Bitte warten...")
      Protokoll(INIT_P,"Ph�nix Excel Datei Abgleich      vom " + dtos(getUser():date))

      // now do it
      i:=startZeile
      ArtikelNr:="foo"
      do while ! empty( ArtikelNr )
        ArtikelNr:=getPhoenixArtNr( oAs , i )
        if empty(ArtikelNr)
          loop
        endif

        ARTIKEL->(dbseek( ArtikelNr ))
        if ARTIKEL->(eof())
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Artikel nicht gefunden!")
        endif

        RABATT->(dbseek( ARTIKEL->RabattGr ))

        if ARTIKEL->Inhalt <> oAS:Cells( i , 8 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte H - Inhalt falsch. Soll:"+;
            str( ARTIKEL->Inhalt , 6,0)+" Ist: " + str( oAS:Cells( i , 8 ):Value , 6 , 0 ))
          oAS:Cells( i , 8 ):Interior:ColorIndex = 4
          oAS:Cells( i , 8 ):value:=ARTIKEL->Inhalt
        endif

        if ARTIKEL->Preis1 <> oAS:Cells( i , 11 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte K - VK falsch. Soll:"+;
            str( ARTIKEL->Preis1 , 9,2)+" Ist: " + str( oAS:Cells( i , 11 ):Value , 9 , 2 ))
          oAS:Cells( i , 11 ):Interior:ColorIndex = 4
          oAS:Cells( i , 11 ):value:=ARTIKEL->Preis1
        endif

        if RABATT->Meng1 <> oAS:Cells( i , 12 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte L - VK falsch. Soll:"+;
            str( RABATT->Meng1 , 6,0)+" Ist: " + str( oAS:Cells( i , 12 ):Value , 6 , 0 ))
          oAS:Cells( i , 12 ):Interior:ColorIndex = 4
          oAS:Cells( i , 12 ):value:=RABATT->Meng1
        endif
        if RABATT->Preis1 <> oAS:Cells( i , 13 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte M - VK falsch. Soll:"+;
            str( RABATT->Preis1 , 9,2)+" Ist: " + str( oAS:Cells( i , 13 ):Value , 9 , 2 ))
          oAS:Cells( i , 13 ):Interior:ColorIndex = 4
          oAS:Cells( i , 13 ):value:=RABATT->Preis1
        endif

        if RABATT->Meng2 <> oAS:Cells( i , 14 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte N - VK falsch. Soll:"+;
            str( RABATT->Meng2 , 6,0)+" Ist: " + str( oAS:Cells( i , 14 ):Value , 6 , 0 ))
          oAS:Cells( i , 14 ):Interior:ColorIndex = 4
          oAS:Cells( i , 14 ):value:=RABATT->Meng2
        endif
        if RABATT->Preis2 <> oAS:Cells( i , 15 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte O - VK falsch. Soll:"+;
            str( RABATT->Preis2 , 9,2)+" Ist: " + str( oAS:Cells( i , 15 ):Value , 9 , 2 ))
          oAS:Cells( i , 15 ):Interior:ColorIndex = 4
          oAS:Cells( i , 15 ):value:=RABATT->Preis2
        endif

        if RABATT->Meng3 <> oAS:Cells( i , 16 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte P - VK falsch. Soll:"+;
            str( RABATT->Meng3 , 6,0)+" Ist: " + str( oAS:Cells( i , 16 ):Value , 6 , 0 ))
          oAS:Cells( i , 16 ):Interior:ColorIndex = 4
          oAS:Cells( i , 16 ):value:=RABATT->Meng3
        endif
        if RABATT->Preis3 <> oAS:Cells( i , 17 ):Value
          Protokoll(PROTOKOLL,ArtikelNr+" Zeile "+str(i,3) + " Spalte Q - VK falsch. Soll:"+;
            str( RABATT->Preis3 , 9,2)+" Ist: " + str( oAS:Cells( i , 17 ):Value , 9 , 2 ))
          oAS:Cells( i , 17 ):Interior:ColorIndex = 4
          oAS:Cells( i , 17 ):value:=RABATT->Preis3
        endif
        i++
      enddo

      // now add missing artikel
      select Artikel
      loca for left(ARTIKEL->ArtNr,3)=="305" .and. getArtikelArt()$"FM"
      i:=startZeile
      do while ! ARTIKEL->(eof())
        ArtikelNr:=getPhoenixArtNr( oAs , i )
        do while ! empty( ArtikelNr ) .and. ArtikelNr < ARTIKEL->ArtNr
          ArtikelNr:=getPhoenixArtNr( oAs , i )
          i++
        enddo

        // Nicht gefunden? -> einf�gen
        if ArtikelNr <> ARTIKEL->ArtNr
          Protokoll(PROTOKOLL,ARTIKEL->ArtNr + " " + ARTIKEL->Bez1 + " -> fehlt in Liste.")
          i--
          oAS:rows(i):insert()
          oAS:rows(i):Interior:ColorIndex = 4
          oAS:Cells( i, 1 ):Value:="'"+left(ARTIKEL->ArtNr,3)+"."+substr(ARTIKEL->ArtNr,4,3)+"."+;
            substr(ARTIKEL->ArtNr,7)
          oAS:Cells( i , 8 ):value:=ARTIKEL->Inhalt
          oAS:Cells( i , 11 ):value:=ARTIKEL->Preis1
          RABATT->(dbseek( ARTIKEL->RabattGr ))
          oAS:Cells( i , 12 ):value:=RABATT->Meng1
          oAS:Cells( i , 13 ):value:=RABATT->Preis1
          oAS:Cells( i , 14 ):value:=RABATT->Meng2
          oAS:Cells( i , 15 ):value:=RABATT->Preis2
          oAS:Cells( i , 16 ):value:=RABATT->Meng3
          oAS:Cells( i , 17 ):value:=RABATT->Preis3
        endif

        cont
      enddo

      newName:=getUser():exportPATH()+BACKSLASH + ;
        getFileName( Dateiname , .t. ) + "-aktualisiert" + getFileExt( Dateiname )
      oExcel:DisplayAlerts:=0
      oAS:SaveAs( newName )
      oExcel:WorkBooks:Close()
      oExcel:Quit()

      Message("Datei " + newName + " erzeugt.    @Taste@","@")

      Protokoll(P_CREATE_PDF,,,,.t.)
      close data

    endif

  endif
return
/** eof */

static function getPhoenixArtNr( oAs , i )
LOCAL wert:=oAS:Cells( i, 1 ):Value
LOCAL result:=""

  BEGIN SEQUENCE

    if ! myEmpty( wert )
      result:=left( ShiftArtikel( no_Dots( wert ) ) + space(8) , 8 )
    endif

    RECOVER
    altd() // okay im Fehlerfall
    qqout(result)
  END SEQUENCE

return result

function getKdSpedZollstellen(datei)
LOCAL result:=""

  default Datei:="KDSPEDTEMP"

  KUNDZOLL->(dbseek( (DATEI)->KundNr + (DATEI)->SpedNr ))
  do while ! KUNDZOLL->(eof()) .and. KUNDZOLL->KundNr == (DATEI)->KundNr .and. ;
    KUNDZOLL->SpedNr == (DATEI)->SpedNr
    result += KUNDZOLL->ZollNr + " "
    KUNDZOLL->(dbskip())
  enddo
return alltrim(result)
/** eof */

/** Ph�nix vverkaufte Artikel / Marge Liste */
Procedure PhoenixIntVerkauft()
LOCAL DateiName:="Phoenix-Verkauft-Int"
LOCAL objErr , export , ExcelJob
LOCAL zeile:=0 , mArtNr, verkauft
LOCAL stop:=.f., Seite:=0

  cls
  Titel("Ph�nix verkaufte Artikel / Marge")

  if ! open("Artikel","AvPost","Waraus")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if (export:=openFileDialog(WRITE,getUser():exportPATH(),DateiName,EXCEL_EXTENSION,nil))<>NIL
    Message("Datei wird erstellt.  Bitte warten.")

    BEGIN SEQUENCE // krit. Bereich

      excelJob:=ExcelJob():new()
      getUser():setCurrentPrintJob(excelJob)
      getUser():getCurrentPrintJob():StartDoc( export )

      /*** Liste mit ArtikelPreisen je Menge / Rabattstaffel */
      select Artikel
      set filter to isPhoenixOberArtikel( ARTIKEL->ArtNr ) .and. getArtikelArt() $ "FM"
      go top
      do while ! ARTIKEL->(eof())
        seite++
        if Seite == 1
          ? FETT_AN,"Art.Nr.  ","Bezeichung","VPE-Inhalt","Kalk.Preis","VK","Diff (Euro)", "Marge (%)",;
            "RabattGruppe","Gut-Menge Stk" , "D/Std Durchschnitt", "D/Std Vorgabe","Verkaufte VPE",FETT_AUS
        endif

        do while ! ARTIKEL->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

          // 305er Artikel
          ? "'"+out(ARTIKEL->ArtNr), ARTIKEL->Bez1, ARTIKEL->Inhalt, ARTIKEL->KaPr, ARTIKEL->Preis1,;
            ARTIKEL->Preis1 - ARTIKEL->KAPR , ARTIKEL->Zuschl_I, ARTIKEL->RabattGr

          // 310er Artikel
          mArtNr:=getSonPhoenix( ARTIKEL->ArtNr )
          if mArtNr == NIL
            altd() // ok im Fehlerfall
            ?? "310er Artikel fehlt"
          else
            // KALKSTAM->(dbseek( mArtNr))
            // ?? KALKSTAM->DMengeAB,KALKSTAM->DMenge,KALKSTAM->Menge

            // bestimme Anzahl verkauft Anhand gefertigter Artikel, besprochen mit MW am 28.4.16
            verkauft:=0
            WARAUS->(dbseek( mArtNr))
            do while ! WARAUS->(eof()) .and. WARAUS->ArtNr == mArtNr
              if WARAUS->Menge > 0 // z�hle alle Eing�nge
                verkauft += WARAUS->Menge
              endif
              WARAUS->(dbskip())
            enddo

            ?? str( verkauft / ARTIKEL->Inhalt ,9,2)
          endif
          ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2

          ?
          skip
          Stop:=stop_key()
        enddo

        Zeile:=FormFeed(Zeile,Seite)

      enddo

      drucker("OFF")

      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")

    RECOVER USING objErr
      Error("Fehler Excel Export: "+objErr:description , .t.)
    END SEQUENCE

  endif

  close data

return
/** eop */

/** Ph�nix verkaufte Artikel Liste extern f�r Ph�nix
  *
  */
Procedure PhoenixExtVerkauft()
LOCAL DateiName:="Phoenix-Verkauft", filterJahr
LOCAL zeile:=0 , mArtNr, mGelief, mInhalt, mgesGelief:=0, gesStueck:=0, mBez1,mBez2
LOCAL stop:=.f., Seite:=0
LOCAL GetList:={}, export, Ausgabe
LOCAL line:=replicate("=",83), Summe:=0, mNetto, rab, wert, div

  Umgebung(WRITE)

  do while .t.
    filterJahr:=space(4)

    cls
    Titel("Ph�nix verkaufte Artikel (etxern)")

    @ 10,20 say "Jahr:   " get filterJahr picture "9999" valid val(filterJahr) > 0 ;
      wwhen Message("Gew�nschtes Jahr eingeben.")

    read

    if ABBRUCH
      exit
    endif

    Ausgabe:=Druck_Bs("Phoenix-Verkauft-"+filterJahr , .t. , .t.)
    if ABBRUCH .or. (valtype(Ausgabe)=="L" .and. ! Ausgabe)
      loop
    endif

    Message("Liste wird erstellt.  Bitte warten....")

    if valtype(Ausgabe)=="C" // Excel
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
      getUser():setCurrentPrintJob(ExcelJob():new())
      getUser():getCurrentPrintJob():StartDoc( export )
      getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=40
    endif

    if ! open("Artikel","Rechpost","Rechaus")
      Error(TRY_AGAIN)
      exit
    endif

    select Rechpost
    set rela to RECHPOST->RechNr into Rechaus, RECHPOST->ArtNr into Artikel

    /*** Liste mit ArtikelPreisen je Menge / Rabattstaffel */
    index on RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      isPhoenixOberArtikel( RECHPOST->ArtNr ) .and. getArtikelArt() $ "FM" .and. ;
      year(RECHPOST->ReaDat) == val(filterJahr)

    go top
    do while ! RECHPOST->(eof())
      if valtype(Ausgabe)=="C" // Excel
        ? "Art.Nr.","Bezeichung","VPE","VPE-Inhalt","St�ck"
      else
        ? "Ph�nix: verkaufte Artikel in " + filterJahr
        ? line
        ? "Art.Nr.   Bezeichung                           VPE    VPE-Inhalt  St�ck  VK (netto)"
        ? line
        _____fixedHeader_____
      endif
      seite++
      do while ! RECHPOST->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        // aufsummieren je Artikel
        mArtNr:=RECHPOST->ArtNr
        mBez1:=ARTIKEL->Bez1
        mBez2:=ARTIKEL->Bez2
        mInhalt:=RECHPOST->Inhalt
        mNetto:=0
        mGelief:=0
        do while ! RECHPOST->(eof()) .and. mArtNr == RECHPOST->ArtNr .and.;
          mInhalt == RECHPOST->Inhalt
          mGelief += RECHPOST->geliefges

          // Netto Wert berechnen
          div=IIF(RECHPOST->PE$"Hh",100,1)
          wert=ROUND(RECHPOST->Preis*RECHPOST->gelief/div,2)
          IF RECHPOST->rabatt<>0.0
            rab=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            wert=wert-rab
          endif
          If RECHAUS->So_Rabatt > 0.0
            rab=ROUND(wert*ROUND(RECHAUS->So_Rabatt,2)/100,2)
            wert=wert-rab
          endif
          mNetto += wert
          skip
        enddo

        if mGelief == 0
          loop
        endif

        // 305er Artikel
        ? out(mArtNr), mBez1, transstr(mGelief,9,0), str(mInhalt,10,0),;
          transstr(mGelief * mInhalt,9,0),, transstr(mNetto,11,2)
        if ! empty(mBez2)
          ? space(len(out(ARTIKEL->ArtNr))),mBez2
        endif

        mgesGelief += mGelief
        gesStueck += mGelief * mInhalt
        Summe += mNetto

        Stop:=stop_key()
      enddo

      if ! RECHPOST->(eof())
        Zeile:=FormFeed(Zeile,Seite)
      endif

    enddo

    if valtype(Ausgabe)=="C" // Excel
      // Excel-Summe
      getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 3 )
      getUser():getCurrentPrintJob():summe( getUser():getCurrentPrintJob():row + 1 , 5 )

      // maxRow:=getUser():getCurrentPrintJob():row
      // getUser():getCurrentPrintJob():colNumberFormat( 2 , maxRow , 3 , EXCEL_NUMBER_FORMAT_INTEGER2)
    else
      ? line
      ? space(40),transstr(mgesGelief,9,0),space(10),transstr(gesStueck,9,0),transstr(summe,11,2)
    endif

    drucker("OFF")

    if valtype(Ausgabe)=="C"
      if Message(export+" wurde erzeugt.  Ordner �ffnen? @J@/@N@","JN","N")=="J"
        wapi_SHELLEXECUTE( 0, "open", getUser():exportPATH())
      endif
    endif

  enddo

  close data
  Umgebung(LOAD)

return
/** eop */

  /*
  *  Umsatzliste Ph�nix je Jahr
  */
PROCEDURE PhoenixUmsatz()
LOCAL jahr,netto,kalk,marge,sumNetto:=0,sumKalk:=0,sumMarge:=0,div
LOCAL seite:=0, zeile:=0, stop:=.f., wert,kosten
LOCAL printBuffer:=printBuffer():new()
LOCAL filterJahr:=space(4)
LOCAL GetList:={}

  Umgebung(WRITE)

  cls
  titel("Umsatzliste Ph�nix / Jahr")

  if ! druck_BS() // Abbruch
    Umgebung(LOAD)
    RETURN
  endif

  Message("Datei wird sortiert.   Bitte warten...")
  if ! open("Rechpost","Artikel","RechAus")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select RechPost
  index on year(RECHPOST->ReaDat) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    isPhoenixOberArtikel(RECHPOST->ArtNr) .and.;
    year(RECHPOST->ReaDat) > 2010

  set rela to RECHPOST->RechNr into Rechaus, RECHPOST->ArtNr into Artikel

  Message("Liste wird erstellt.  Bitte warten....")
  go top
  zeile:=0
  ? "Umsatz Ph�nix                              vom:",getUser():date
  ? '--------------------------------------------------------'
  ? ' Jahr           Kalk.Preis     VK (Netto)          Marge'
  ? '--------------------------------------------------------'

  do while .not. RECHPOST->(eof()) .and. ! stop
    if jahr <> year(RECHPOST->ReaDat)
      jahr:=year(RECHPOST->ReaDat)
      Netto:=kalk:=marge:=0
    endif

    do while .not. RECHPOST->(eof()) .and. jahr == year(RECHPOST->ReaDat) ;
      .and.zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      div=IIF(RECHPOST->PE$"Hh",100,1)
      kosten:=round( ARTIKEL->KaPr * RECHPOST->Gelief / div , 2)
      wert=ROUND(RECHPOST->Preis * RECHPOST->gelief/div,2)
      If RECHAUS->So_Rabatt > 0.0
        wert -= ROUND(wert*RECHAUS->So_RAbatt/100,2)
      endif

      kalk += kosten
      Netto += wert
      marge += wert - kosten

      skip
    enddo

    ? jahr,space(5),transform(kalk,"@E 999,999,999.99"),transform(netto,"@E 999,999,999.99"),;
      transform(marge,"@E 999,999,999.99")

    sumKalk += Kalk
    sumNetto += Netto
    sumMarge += Marge

  enddo

  ? '--------------------------------------------------------'
  ? space(11),transform(sumkalk,"@E 999,999,999.99"),transform(sumnetto,"@E 999,999,999.99"),;
    transform(summarge,"@E 999,999,999.99")

  FormFeed(Zeile,Seite)

  Drucker("Off")

  cls
  Umgebung(LOAD)
RETURN
/* EOP Umsatz Liste */


/** */
static Procedure KundSpedCopy()
LOCAL orgKundNr:=KUNDEN->KundNr
LOCAL mKundNr:=space(len(KUNDEN->KundNr))
LOCAL kopieAlias:="Kopie"
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()
LOCAL GetList:={} , ant, zielRec

  Umgebung(WRITE_ALL)

  @ Maxrow(),0 clear
  @ Maxrow(),12 say "Speditionen Kopieren nach:" get mKundNr picture KDNR_PICT;
    valid { |oGet| check(oGet,"Kunden",.f.)}
  read

  select Kunden
  KUNDEN->(dbseek( mKundNr ))
  if KUNDEN->(eof()) .or. ! rec_lock(5 , .t. )
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    return
  endif
  zielRec:=KUNDEN->(recno())

  if ! ABBRUCH .and. ! empty(mKundNr)
    KUNDSPED->(dbseek( mKundNr ))
    if ! KUNDSPED->(eof())
      ant:=;
        Message("Vorhandene Speditionen bei Zielkunde l�schen?  (@J@/@N@)","JN"," ")

      if ABBRUCH
        Umgebung(LOAD)
        KUNDEN->(dbrunlock( zielRec ))
        return
      endif

      if ant == "J"
        select KundSped
        do while ! KUNDSPED->(eof()) .and. KUNDSPED->KundNr == mKundNr
          rec_lock(0)
          delete
          skip
        enddo

        select Kundzoll
        KUNDZOLL->(dbseek( mKundNr ))
        do while ! KUNDZOLL->(eof()) .and. KUNDZOLL->KundNr == mKundNr
          rec_lock(0)
          delete
          skip
        enddo
      endif

    endif

    // now do the copy vodoo
    select KundSped
    copy to (temp_Datei) for KUNDSPED->KundNr == orgKundNr

    sele 0
    use (temp_datei) alias (kopieAlias) excl
    go top
    do while ! (kopieAlias)->(eof())
      replace (kopieAlias)->KundNr with MKundNr // all geht net???
      skip
    enddo
    go top
    sele KundSped
    append(kopieAlias)
    close(kopieAlias)

    // copy Zollstellen
    select KundZoll
    copy to (temp_Datei) for KUNDZOLL->KundNr == orgKundNr

    sele 0
    use (temp_datei) alias (kopieAlias) excl
    go top
    do while ! (kopieAlias)->(eof())
      replace (kopieAlias)->KundNr with MKundNr // all geht net???
      skip
    enddo
    go top
    sele KundZoll
    append(kopieAlias)
    close(kopieAlias)

    KUNDEN->(dbrunlock( zielRec ))

  endif

  Umgebung(LOAD)
return
/** eof */

procedure phoenixRabattStaffel(auto)
LOCAL rabatte:={} , feld , i
LOCAL allePreise:=hb_hash()

  default auto:=.f.

  cls
  titel("Ph�nix Rabatt-Staffel bearbeiten")

  if ! open("Artikel","Rabatt")
    close data
    return
  endif

  select Rabatt
  dbseek( PHOENIX_RABATT_GRUPPE )
  if RABATT->(eof())
    add_rec()
    replace RABATT->RabattGr with PHOENIX_RABATT_GRUPPE
    replace RABATT->Rab1 with 4.91
    replace RABATT->Rab2 with 5.90
    replace RABATT->Rab3 with 6.88
    replace RABATT->Rab4 with 7.37
  else
    if ! rec_lock(5)
      Error(TRY_AGAIN)
      close data
      return
    endif
  endif

  if .not. auto
    PhoenixRabattDisp(.t.,.f.)
  endif
  dbcommit()
  dbunlock()

  if auto .or. Message("Rabbatgruppen aller Ph�nix-Artikel anpassen? (@J@/@N@)","JN"," ")=="J"

    Message("Rabbatgruppen werden angepasst.   Bitte warten...")

    // merke zu kopierende Werte
    for i:=1 to 9
      feld:="RABATT->rab"+str(i,1)
      aadd( Rabatte , &(feld) )
    next


    select Artikel
    loca for isPhoenixOberArtikel( ARTIKEL->ArtNr ) .and.;
      ! empty( ARTIKEL->RabattGr ) .and. getArtikelArt() $ "FM"
    do while ! ARTIKEL->(eof())
      select Rabatt
      dbseek( ARTIKEL->RabattGr )
      if ! RABATT->(eof()) .and. rec_lock(0)

        // pr�fe ob alle Artikel den gleichen Preis haben
        if hb_HHasKey( allePreise, ARTIKEL->RabattGr)
          if allePreise[ARTIKEL->RabattGr] <> ARTIKEL->Preis1
            Error(ACHTUNG + "Artikel: " + ARTIKEL->ArtNr + " Preis weicht ab:|"+;
              str(ARTIKEL->Preis1) + " ungleich " + str(allePreise[ARTIKEL->RabattGr]) +;
              "|RabattGr: " + ARTIKEL->RabattGr)
          endif
        else
          allePreise[ARTIKEL->RabattGr]:=ARTIKEL->Preis1
        endif

        for i:=1 to 9
          feld:="RABATT->Meng"+str(i,1)
          if &(feld) > 0
            feld:="RABATT->Preis"+str(i,1)
            replace &(feld) with ARTIKEL->Preis1 * (100 - Rabatte[i]) / 100
          endif
        next
        dbcommit()
        dbunlock()
      endif
      select Artikel
      @ Maxrow(),0 say ARTIKEL->ArtNr
      cont
    enddo
  endif

  if .not. auto
    close data
  endif

return
/** eop */

/** Ph�nix verkaufte Artikel pro Land und Jahr
  *
  * ACHTUNG: diese Liste verwendet die Daten von vor 2016 aus dem DAT\Phoenix Verzeichnis
  *          da sich ab 2016 die VPE (Inhalt) ge�ndert haben
  */
Procedure PhoenixVerkauftProLand()
LOCAL DateiName:="Phoenix-Verkauft-Jahr-Land"
LOCAL objErr , export , ExcelJob
LOCAL zeile:=0 , mArtNr
LOCAL stop:=.f., Seite:=0
LOCAL Laender , verpInhalt, details:="N"
LOCAL GetList:={} , filterJahr:="2015" , i

  cls
  Titel("Ph�nix verkaufte Artikel pro Land und Jahr")

  if ! open("Artikel","AvPost","RechPost","Rechaus","Mat_KZ")
    Error(TRY_AGAIN)
    close data
    return
  endif

  if ! file( DAT_PHOENIX + BACKSLASH + "Artikel.dbf")
    Error("Alte Artikel Datei nicht gefunden:||"+DAT_PHOENIX + BACKSLASH + "Artikel.dbf")
    close data
    return
  endif

  select 0
  use (DAT_PHOENIX + BACKSLASH + "Artikel.dbf") alias ArtAlt
  index on ARTALT->ArtNr tag TEMP_IND2 TEMPORARY ADDITIVE

  select 0
  use (DAT_PHOENIX + BACKSLASH + "Mat_Kz.dbf") alias Mat_Alt
  index on MAT_Alt->MatKz tag TEMP_IND3 TEMPORARY ADDITIVE

  @ 10,20 say "Jahr:   " get filterJahr picture "9999";
    valid filterJahr $ "2010|2011|2012|2013|2014|2015" when Message("Gew�nschtes Jahr (max. 2015) "+;
    "eingeben.")

  @ 12,20 say "Details:" get details picture "!" valid details $ "JN";
    when Message("Rechnungsdetails anzeigen? (@J@/@N@)")

  read

  if ABBRUCH
    close data
    return
  endif

  if Details == "J"
    DateiName += "-Details"
  endif

  select Artikel // -> SheetName :(
  if (export:=openFileDialog(WRITE,getUser():exportPATH(),DateiName,EXCEL_EXTENSION,nil))<>NIL
    Message("Datei wird erstellt.  Bitte warten.")

    BEGIN SEQUENCE // krit. Bereich

      excelJob:=ExcelJob():new()
      getUser():setCurrentPrintJob(excelJob)
      getUser():getCurrentPrintJob():StartDoc( export )

      // rechpost filtern
      select RechPost
      index on RECHPOST->ArtNr + RECHPOST->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        year(RECHPOST->ReaDat) == val(filterJahr)

      select Artikel
      set filter to isPhoenixOberArtikel( ARTIKEL->ArtNr ) .and. getArtikelArt() $ "FM" // nur 305er, ohne X-Artikel
      go top
      do while ! ARTIKEL->(eof()) .and. ! stop
        seite++
        if Seite == 1
          ? FETT_AN,"Art.Nr.  ","Bezeichung                   ","VPE-Inhalt","Verkauft",FETT_AUS
        endif

        do while ! ARTIKEL->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

          mArtNr:=getSonPhoenix( ARTIKEL->ArtNr ) // 310er Artikel

          // hole Verpackungsinhalt f�r 305er Artikel aus alter Artikel Datei vom 10.1.2016
          ARTALT->(dbseek( ARTIKEL->ArtNr ))
          if ARTALT->(eof())
            Error( "Fehler: Artikel " + + " in 2015 nicht gefunden" )
            ? "Fehler: Artikel " + ARTIKEL->ArtNr + "  in 2015 nicht gefunden -> Inhalt = 1"
            verpInhalt:=1
          else
            verpInhalt:=ARTALT->Inhalt
          endif

          @ 16,20 say out(ARTIKEL->ArtNr) + space(1) + ARTIKEL->Bez1
          @ 17,20 say space(len(out(ARTIKEL->ArtNr))) + space(1) + ARTIKEL->Bez2
          if empty(mArtNr)
            @ 19,20 say space(40)
            ?? space(0),space(0),"Fertigungsartikel-Artikel 310... fehlt"
          else
            @ 19,20 say out(mArtNr) + " Inhalt:" + str(verpInhalt,6)
          endif

          Laender:=hb_hash()

          // 305er
          zeile += getPhoenixVerkauftProJahr(ARTIKEL->ArtNr , verpInhalt, @Laender , details , .f.)

          // 310er
          if ! empty(mArtNr)
            zeile += getPhoenixVerkauftProJahr(mArtNr , 1 , @Laender , details , .t.)
          endif

          // drucke Land je Artikel
          if len( Laender:keys ) > 0
            if Details == "J"
              ?
              ? space(0),"Summe:"
            endif
            for i:=1 to len( Laender:keys )
              ? space(0),HGetKeyAt( Laender, i ) ,space(0), HGetValueAt( Laender, i )
            next
            ?
          else // ihne Bewegung nur F-Artikel anzeigen

            if getArtikelArt() $ "FM"
              ? "'"+out(ARTIKEL->ArtNr), getArtikelTextAlt(), verpInhalt
            endif

          endif

          select Artikel
          skip
          Stop:=stop_key()
        enddo

        Zeile:=FormFeed(Zeile,Seite)

      enddo

      // set width of description column (autowrap)
      getUser():getCurrentPrintJob():autoFitAll( )
      getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=40

      drucker("OFF")

      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")

    RECOVER USING objErr
      altd() // okay im Fehlerfall
      Error("Fehler Excel Export: "+objErr:description , .t.)
    END SEQUENCE

  endif

  close data

return
/** eop */


static function getPhoenixVerkauftProJahr(myArtNr , mInhalt, Laender , details , fett)
LOCAL aktSel:=alias()
LOCAL Zeile:=0

  // suche verkaufte Artikel in RechPost
  select RechPost
  dbseek( myArtNr )

  do while ! RECHPOST->(eof()) .and. RECHPOST->ArtNr == myArtNr
    RECHAUS->(dbseek( RECHPOST->RechNr ))

    if len( Laender:keys ) == 0
      ? "'"+out(ARTIKEL->ArtNr), getArtikelTextAlt(), mInhalt
    endif

    if Details == "J"
      if fett
        ? FETT_AN,"ohne VPE"
      else
        if getArtikelArt()=="X"
          ? "X-Artikel"
        else
          ? space(0)
        endif
      endif
      ??;
        out(myArtNr)+" Re:";
        +;
        RECHPOST->RechNr;
        +;
        " vom ";
        +;
        dtoc(RECHPOST->ReaDat);
        + " (" + RECHAUS->V_Land + ")" + str( RECHPOST->Gelief , 9 , 0 ) + " x ", mInhalt ,;
        mInhalt*RECHPOST->Gelief, FETT_AUS
    endif

    if hb_HHasKey( Laender, RECHAUS->V_Land)
      Laender[ RECHAUS->V_Land ] += mInhalt*RECHPOST->Gelief
    else
      Laender[ RECHAUS->V_Land ]:=mInhalt*RECHPOST->Gelief
    endif

    skip
  enddo
  select (aktSel)
return Zeile
/** eop */

static function getArtikelTextAlt()
LOCAL Result:=ARTIKEL->Bez1 + MY_LF + ARTIKEL->Bez2
LOCAL Texte

  if ! empty( ARTIKEL->MatKz )
    MAT_ALT->(dbseek( ARTIKEL->MatKz ))
    if MAT_ALT->(eof())
      // falls in alter Datei nicht gefunden, nehme 1. Zeile vom neuen Text (yerk)
      MAT_KZ->(dbseek( ARTIKEL->MatKz ))
      texte:=HB_ATokens( MAT_KZ->MkzText , MY_CR+MY_LF)
    else
      texte:=HB_ATokens( MAT_ALT->MkzText , MY_CR+MY_LF)
    endif
    Result += MY_LF + MY_LF + trim(texte[1])
  endif
return result
/** eof */

static function getArtikelText()
LOCAL Result:=ARTIKEL->Bez1 + MY_LF + ARTIKEL->Bez2

  if ! empty( ARTIKEL->MatKz )
    MAT_KZ->(dbseek( ARTIKEL->MatKz ))
    Result += MY_LF + MY_LF + trim(MAT_KZ->MkzText)
  endif

return result
/** eof */

/** Preis�nderung in % Ph�nix Artikel */
Procedure PhoenixPreisAenderung()
LOCAL DateiName:="Phoenix-Artikel"
LOCAL objErr , export , cols, ExcelJob
LOCAL zeile:=0 , mArtNr , farbe , x , mBez2
LOCAL feldMenge, feldPreis, stop:=.f., Seite:=0, rab
LOCAL verkauftOnly:=.f., von, bis, proz:=0.00
LOCAL GetList:={}, M_grund:=space(30)

  cls
  Titel("Ph�nix Preis-�nderung (Artikel)")

  if ! open("Artikel","Rabatt","Mat_KZ","ArtPreis")
    Error(TRY_AGAIN)
    close data
    return
  endif

  von:=bis:=space(len(ARTIKEL->ArtNr))
  bis:=von_bis("Artikel")

  @ 12,20 say "Preis�nderung in Prozent (%):" get proz picture "99.99";
    when Message ("Preis�nderung in % angeben")
  @ 14,20 say "Grund:" get M_grund picture "@K" valid ! emptyOr2Simple(M_grund,5) ;
    when Message("Grund f�r Preis�nderung eingeben (mind 5 Zeichen)  @F12@=Auswahl  @ESC@=Ende")
  read
  if ABBRUCH .or. proz == 0
    close data
    return
  endif

  export:=Druck_Bs(DateiName , .t.)

  if ABBRUCH .or. ( valtype(export) == "L" .and. ! export )
    close data
    return
  endif

  Message("Liste wird erstellt.  Bitte warten.")

  BEGIN SEQUENCE // krit. Bereich

    if valtype(export)=="C"
      export:=getUser():exportPATH() + BACKSLASH + export
      excelJob:=ExcelJob():new()
      getUser():setCurrentPrintJob(excelJob)
      getUser():getCurrentPrintJob():StartDoc( export )
    endif

    Message("Backup wird erstellt.   Bitte warten...")
    backup("Artikel","pre-PreisePhoenix")

    /*** Liste mit ArtikelPreisen je Menge / Rabattstaffel */
    select Artikel
    set filter to isPhoenixOberArtikel( ARTIKEL->ArtNr ) .and. getArtikelArt() $ "FM" .and.;
      ARTIKEL->Artnr>=von .and. ARTIKEL->Artnr<=bis
    go top
    do while ! ARTIKEL->(eof())
      seite++
      if valtype(export) <> "C"
        ? "Ph�nix-Artikel Preis�nderung vom ",getUser():Date,space(32),"Seite:"+str(Seite,3)
        ? replicate("=",82)
        ? "Art.Nr.  ", "Bezeichung",space(26),"VPE (Stk)"
        ? replicate("=",82)
      else
        ? "Art.Nr.  ", "Bezeichung","","VPE (Stk)"
      endif

      do while ! ARTIKEL->(eof()) .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop

        RABATT->(dbseek( ARTIKEL->RabattGr ))

        rec_lock(0)
        replace ARTIKEL->Preis1 with ARTIKEL->Preis1 * (100 + proz) / 100
        dbcommit()
        dbunlock()

        // Preis �nderung, schreibe Historie
        addPreisHistorie(M_Grund)

        if substr(ARTIKEL->ArtNr,7,1) == "0"
          farbe:="hellgrau"
          mArtNr:=ARTIKEL->ArtNr
          mBez2:=ARTIKEL->Bez2
          // mBez2:=left( ARTIKEL->Bez2 , at( "hellgrau" , ARTIKEL->Bez2 ) - 1)
        else
          farbe:="Farbe   "
          mArtNr:=ARTIKEL->ArtNr
          mBez2:=ARTIKEL->Bez2
          // mBez2:=left( ARTIKEL->Bez2 , at( "elfenbein" , ARTIKEL->Bez2 ) - 1)
        endif

        if valtype(export)=="C"
          ? "'"+out(mArtNr),getArtikelText(),Farbe , ARTIKEL->Inhalt
        else
          ? out(mArtNr),ARTIKEL->Bez1,Farbe , ARTIKEL->Inhalt
          ? space(len(out(mArtNr))),mBez2

          if ! empty( ARTIKEL->MatKz )
            MAT_KZ->(dbseek( ARTIKEL->MatKz ))
            aEval(HB_ATokens( MAT_KZ->MkzText , MY_CR+;
              MY_LF),;
              {;
              |x|;
              if(empty(x),nil,getUser():getCurrentPrintJob():print({space(len(out(ARTIKEL->ArtNr));
              ),x},.t.)),zeile++,.t. })
          endif

        endif

        ?
        ? space(len(out(mArtNr))),"   St�ck","  Menge","  Rabatt","          VK      "
        ? space(len(out(mArtNr))),"        ","  (VPE)","        ","(VPE inkl. Karton)"
        if valtype(export)=="C"
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 2):HorizontalAlignment:=xlHAlignRight
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 4):HorizontalAlignment:=xlHAlignRight
          getUser():getCurrentPrintJob():oSheet:cells( excelJob:row , 5):HorizontalAlignment:=xlHAlignRight
        endif
        ? space(len(out(mArtNr))) , str( ARTIKEL->Inhalt , 8 , 0 ), str(1,7),space(8),ARTIKEL->Preis1 ,;
          EURO_SIGN + space(4)

        // drucke Rabatte
        feldMenge="RABATT->Meng1"
        x:=0
        do while x < 10 .and. &FeldMenge > 0
          x=x+1
          feldMenge="RABATT->Meng"+str(x,1)
          feldPreis="RABATT->Preis"+str(x,1)
          rab:=100 - 100 * &("RABATT->Preis"+str(x,1)) / ARTIKEL->Preis1

          if &FeldMenge > 0
            ? space(len(out(mArtNr))) , str(&(feldMenge) * ARTIKEL->Inhalt , 8,0) , ;
              &(feldMenge) , str(rab,7,2)+"%" , &(feldPreis) , EURO_SIGN + space(4)

          endif
        enddo
        ?
        skip
        Stop:=stop_key()
      enddo

      if ARTIKEL->(eof())
        ?
        ? "Die ausgewiesenen Preise sind Nettopreise in Euro und verstehen sich"
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ? "zuz�glich der gesetzlichen Mehrwertsteuer."
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

        ?
        ? "VPE = Verpackungseinheit (packaging unit)"
        if valtype(export)=="C"
          cols:="A"+alltrim(str(excelJob:row))+":E"+alltrim(str(excelJob:row))
          excelJob:oSheet:Range(cols):merge()
        endif

      endif

      Zeile:=FormFeed(Zeile,Seite)

    enddo

    if valtype(export)=="C"
      // set width of description column (autowrap)
      getUser():getCurrentPrintJob():oSheet:columns( 2 ):ColumnWidth:=40
    endif

    phoenixRabattStaffel(.t.) // ohne Abfrage

    drucker("OFF")

    if valtype(export)=="C"
      Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")
    endif

  RECOVER USING objErr
    Error("Fehler Excel Export: "+objErr:description , .t.)
  END SEQUENCE

  close data

return
/** eop */



/* Modul Av.prg
*
* alles zur Arbeitvorbereitung - Mehrfachspritzung
*/

#include "Miki.ch"
#include "hbclass.ch"

/* 
* erfassen und anzeigen der Mehrfachspritzungen
*/
PROCEDURE Art_Mehrfach(mArtNr)
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL aktSatz:=ARTIKEL->(recno())
LOCAL starteBeiRecno, n1, n2, tempVal
LOCAL cb_duplicates:={ || (alias())->ANr + (alias())->Gruppe }

MEMVAR M_ArtNr
PRIVATE M_ArtNr:=ARTIKEL->Artnr

  Umgebung(WRITE_ALL)

  if ARTIKEL->Art <> "W"
    M->M_ArtNr:=Stueckliste():new(M->M_ArtNr):getFirstWerkzeug()
    if M->M_ArtNr == NIL .or. empty(M->M_ArtNr) .or. ARTIKEL->(eof())
      Umgebung(LOAD)
      return
    endif
    ARTIKEL->(dbseek( M->M_ArtNr ))
    if ARTIKEL->(eof())
      Umgebung(LOAD)
      return
    endif
  endif

  if ! open("MehrFach","MehrTemp","AvPost")
    select Artikel
    Umgebung(LOAD)
    RETURN
  endif

  select MehrTemp
  zap
  set relation to MEHRTEMP->ANr into Artikel

  /* hole alle zugeh. Artikel */
  MEHRFACH->(dbseek(M->M_ArtNr))
  do while ! MEHRFACH->(eof()) .and. M->M_ArtNr==MEHRFACH->ArtNr
    select MehrTemp
    add_rec(0)
    overwrite("MehrFach")
    select MehrFach
    // rec_lock(0) -> erst unten beim r�ckschreiben!
    // delete

    // starte bei vorgegebenem Artikel if applicable
    if mArtnr == MEHRTEMP->ANr
      starteBeiRecno:=MEHRTEMP->(recno())
    endif

    MEHRFACH->(dbskip())
  enddo

  select MehrTemp

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=10 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-2 // N: Anzeige BS bis, Zeile von untere BS Rand hochgez�hlt
  aKopf[EDIT_LM]:=04 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="KL"
  aKopf[EDIT_EXTRA_FKT]:={ { "L"," @L@�schen ", { || MehrfKonsistenzloesch(aKopf) } } }
  // aKopf[EDIT_ZEIGE_ANZAHL]:={ || .t. } // z�hle alle Artikel
  // aKopf[EDIT_CLS_EXTRA_ROWS]:=-2 // clear screen to last row of screen
  aKopf[EDIT_DRAW_FRAME]:="Mehrfach-Spritzung ("+out(M->M_ArtNr)+")"
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->MEHRTEMP->Gruppe:=getMaxGruppe() }
  if valtype(starteBeiRecno)=="N" .and. MEHRTEMP->(reccount()) > 6
    aKopf[EDIT_START_REC]:=starteBeiRecno
  endif

  // /* Fenster-Rahmen */
  // setcolor(COLWIN)
  // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]-1 clear to aKopf[EDIT_ENDE_Y]+1,aKopf[EDIT_RM]+1
  // @ aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]+25 say "Mehrfach-Spritzung"
  // setcolor(COLNOR)

  // kalkuliere und zeige Nutzen an
  aKopf[EDIT_BEFORE_EDIT_FKT]:={ || kalkNutzenFraction(aKopf) } // davor auch -> um x-fach anzuzeigen
  aKopf[EDIT_AFTER_EDIT_FKT]:={;
    || checkDuplicatesOk(cb_duplicates) .and. kalkNutzenFraction(aKopf) }

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  // Artikel-Nr.
  aSpalte[EDIT_NAME]:="ANr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| mehrfAnrNach(oGet)}
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Bezeichnung"
  aSpalte[EDIT_EDIT]:=.f.


  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez2"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  // aSpalte[EDIT_AFTER]:={ |oGet| kalkNutzenFraction(oGet,aKopf) }
  // aSpalte[EDIT_BS_AUSGABE]:=.t.
  // aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Menge eingeben.                                  @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Nutzen Divident
  aSpalte[EDIT_NAME]:="Nutzen1"
  aSpalte[EDIT_TITEL]:="Ma.Nutzen"
  aSpalte[EDIT_MASKE]:="99"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // geteilt durch
  aSpalte[EDIT_NAME]:="'/'"
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_POS_X]:=-8
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Nutzen Divisor
  aSpalte[EDIT_NAME]:="Nutzen2"
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_MASKE]:="99"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Gruppe
  aSpalte[EDIT_NAME]:="Gruppe"
  aSpalte[EDIT_TITEL]:="Gruppe"
  aSpalte[EDIT_POS_X]:=7
  aSpalte[EDIT_AFTER]:={ |oGet| gruppeNach(oGet)}
  aSpalte[EDIT_DUPLICATES]:=cb_duplicates
  aSpalte[EDIT_MASKE]:="999"
  aSpalte[EDIT_BS_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Gruppe eingeben   0-9 oder leer.            @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  Edit(aFelder,aKopf)
  if aKopf[EDIT_CHANGED] .or. aKopf[EDIT_CARGO]<>NIL
    /* l�sche alte MehrfachSpritzungen */
    select MehrFach
    MEHRFACH->(dbseek(M->M_ArtNr))
    do while ! MEHRFACH->(eof()) .and. M->M_ArtNr==MEHRFACH->ArtNr
      rec_lock(0)
      delete
      MEHRFACH->(dbskip())
    enddo

    /* schreibe MehrfachSpritzung zur�ck */
    select MehrTemp
    set relation to

    index on MEHRTEMP->Gruppe+MEHRTEMP->Anr tag TEMP_INDEX TEMPORARY ADDITIVE EXCLUSIVE
    MEHRTEMP->(dbgotop())
    // merke Nutzen der 1. Gruppe
    n1:=MEHRTEMP->Nutzen1
    n2:=MEHRTEMP->Nutzen2
    do while ! eof()
      if ! empty(MEHRTEMP->ANr)

        select MehrFach
        add_rec(0)
        overwrite("MehrTemp")
        replace MEHRFACH->ArtNr with M->M_ArtNr

        // pr�fe ob Satz gel�scht werden sollte und Benutzer sich umentschieden hat
        if aKopf[EDIT_CARGO]<>NIL .and. hb_HHasKey( aKopf[EDIT_CARGO], MEHRTEMP->ANr)
          aKopf[EDIT_CARGO][MEHRTEMP->ANr]:=.f.
        endif

        // ab 20241117 immer r�ckschreiben, AVPOST->Nutzen1 und AVPOST->Nutzen2 sind der Nutzen der 1. Gruppe
        select AvPost
        dbseek(MEHRTEMP->ANr+"V")
        do while ! AVPOST->(eof()) .and. MEHRTEMP->ANr==AVPOST->AvNr .and. AVPOST->Art=="V"
          if AVPOST->Text=="A"
            if ! rec_lock(5)
              ERROR("R�ckschreiben in St�ckliste:"+AVPOST->AvNr+" nicht m�glich! Bitte erneut "+;
                "versuchen!",.t.)
            else
              replace AVPOST->Nutzen1 with MEHRTEMP->Nutzen1
              replace AVPOST->Nutzen2 with MEHRTEMP->Nutzen2
              dbcommit()
              dbunlock()
            endif
          endif
          skip
        enddo

      endif
      select MehrTemp
      skip
    enddo


    // jetzt alle gel�schten Mehrfachspritzungen den Nutzen 1/1 zur�ck schreiben
    if aKopf[EDIT_CARGO]<>NIL
      for each tempVal IN aKopf[EDIT_CARGO]:Keys
        select AvPost
        dbseek(tempVal+"V")
        do while ! AVPOST->(eof()) .and. tempVal==AVPOST->AvNr .and. AVPOST->Art=="V"
          if AVPOST->Text=="A"
            if ! rec_lock(5)
              ERROR("R�ckschreiben in St�ckliste:"+AVPOST->AvNr+" nicht m�glich! Bitte erneut "+;
                "versuchen!",.t.)
            else
              replace AVPOST->Nutzen1 with 1
              replace AVPOST->Nutzen2 with 1
              dbcommit()
              dbunlock()
            endif
          endif
          skip
        enddo
      next
    endif


    ARTIKEL->(dbgoto(aktSatz))

    dbcommitall()
    dbunlockall()
  endif

  Umgebung(LOAD)

RETURN
  /* EoF */

/* Liefert die max. Gruppe zur�ck oder 000 falls keine vorhanden. */
static function getMaxGruppe()
LOCAL aktRec:=MEHRTEMP->(recno())
LOCAL aktSel:=alias()
LOCAL result:="000"
  select MehrTemp
  go top
  do while ! MEHRTEMP->(eof())
    if MEHRTEMP->Gruppe > result
      result:=MEHRTEMP->Gruppe
    endif
    skip
  enddo
  select (aktsel)
  MEHRTEMP->(dbgoto(aktRec))
return result
/** eop */

static function mehrfAnrNach(oGet)
  if oget:changed

    if ! check(oGet,"Artikel",.f.,.f.)
      return .f.
    endif

    // pr�fe das Werkzeug in Artikel-St�ckliste gelistet ist
    AVPOST->(dbseek(oGet:buffer+"W"))
    if ! AVPOST->(eof())
      select AvPost
      do while AVPOST->AvNr==oGet:buffer .and. AVPOST->Art=="W"
        if AVPOST->ArtNr == M->M_ArtNr
          select Mehrtemp
          replace MEHRTEMP->ArtNr with M->M_ArtNr
          return .t.
        endif
        skip
      enddo
    endif
    select Mehrtemp

    Error(ACHTUNG+"Werkzeug ist nicht in Artikel-St�ckliste: " +out(oGet:Buffer) + " hinterlegt.")
    return .f.

  endif
return .t.
/** eof */

static function gruppeNach(oGet)
  if oget:changed
    oGet:varput(padLeft(alltrim(oGet:buffer),3,"0"))
  endif
return .t.
/** eof */

/** berechnet den jeweiligen Bruchteil/Anteil der Einzelteile aller MehrfachSpritzungen z.B. 1/4 */
static function kalkNutzenFraction(aKopf)
LOCAL aktRec:=recno(),fraction
LOCAL material:=hb_hash()
LOCAL summe:=hb_hash(), pos:=1
  // LOCAL ,mat, m, matCount:=0, mArtNr

  Umgebung(WRITE_ALL)

  // bestimme Gruppenzugeh�rigkeit anhand von Material in St�ckliste
  if MEHRTEMP->(reccount()) == 0
    Umgebung(LOAD)
    return .t.
  elseif MEHRTEMP->(reccount()) == 1
    replace MEHRTEMP->Nutzen1 with 1
    replace MEHRTEMP->Nutzen2 with 1
  else
    // // pre 20200512: automat. Berechnung der Gruppen/Nutzen anhand des Materials
    // go top
    // do while ! MEHRTEMP->(eof())
    // matCount:=0
    // if ! empty(MEHRTEMP->ANr)
    // mat:=Stueckliste():new( MEHRTEMP->ANr ):getMaterial( .t. ) // nur Artikel
    // // remove non kg or zero based Material
    // for each m in mat
    // ARTIKEL->(dbseek(m:artNr))
    // EINHEIT->(dbseek(ARTIKEL->ME))
    // if lower(trim(EINHEIT->Text)) $ "g|kg" .and. m:menge > 0
    // matCount++
    // mArtNr:=m:artNr
    // endif
    // next
    // if matCount == 0
    // ERROR(ACHTUNG+"Artikel: " +out(MEHRTEMP->ANr) + " kein Material in St�ckliste gefunden..")
    // elseif matCount > 1
    // ERROR(ACHTUNG+"Artikel: " +out(MEHRTEMP->ANr) + " Material in St�ckliste nicht eindeutig.")
    // else
    // material[MEHRTEMP->ANr]:=mArtNr
    // if hb_HHasKey(summe , mArtNr )
    // summe[martNr] += MEHRTEMP->Menge
    // else
    // summe[martNr]:=MEHRTEMP->Menge
    // endif
    // endif
    // endif
    // skip
    // enddo

    // // Nutzen und Gruppe r�ckschreiben
    // go top
    // do while ! MEHRTEMP->(eof())
    // if hb_HHasKey(material , MEHRTEMP->ANr )
    // mat:=material[MEHRTEMP->ANr]
    // if len(summe)==1
    // replace MEHRTEMP->Gruppe with " "
    // else
    //       replace MEHRTEMP->Gruppe with str(/** len(summe) + 1 - */ hGetPos( summe , mat ),1)
    // endif
    // fraction:=reduceFraction( MEHRTEMP->Menge , summe[mat] )
    // replace MEHRTEMP->Nutzen1 with fraction[1]
    // replace MEHRTEMP->Nutzen2 with fraction[2]
    // endif
    // skip
    // enddo

    // manuelle Gruppen-Zuweisung gew. v. H. Weiland, Rest-Risko: Nutzen-Berechnung wurde abgesegnet
    go top
    do while ! MEHRTEMP->(eof())
      if ! empty(MEHRTEMP->ANr)
        if hb_HHasKey(summe , MEHRTEMP->gruppe )
          summe[MEHRTEMP->gruppe] += MEHRTEMP->Menge
        else
          summe[MEHRTEMP->gruppe]:=MEHRTEMP->Menge
        endif
      endif
      skip
    enddo

    // Nutzen per Gruppe berechnen
    go top
    do while ! MEHRTEMP->(eof())
      if ! empty(MEHRTEMP->ANr)
        if hb_HHasKey(summe , MEHRTEMP->gruppe )
          fraction:=reduceFraction( MEHRTEMP->Menge, summe[MEHRTEMP->gruppe])
        else
          fraction=reduceFraction(1,1)
        endif
        replace MEHRTEMP->Nutzen1 with fraction[1]
        replace MEHRTEMP->Nutzen2 with fraction[2]
      endif
      skip
    enddo

    // zeige Nutzen an
    if len(summe) > 0
      @ aKopf[EDIT_START_Y]-2,63 say alltrim(str(hGetValueAt(summe,1),3))+"-fach  "
    endif

  endif
  go (aktRec)

  HB_KeyPut(EDIT_BS_REFRESH)
  Umgebung(LOAD)

return .t.
/** eof */

  /** L�scht Datensatz und setzt merkt sich gel�schten Satz, um sp�ter
  Nutzen in St�ckliste auf 1/1 zu setzen */
static function Mehrfkonsistenzloesch(aKopf)

  if aKopf[EDIT_CARGO]==NIL
    aKopf[EDIT_CARGO]:=hb_hash()
  endif
  aKopf[EDIT_CARGO][MEHRTEMP->ANr]:=.t.

  delete
  kalkNutzenFraction(aKopf)
  HB_KeyPut(K_HOME)

return .t.
  /** eof */


/************************************************************************************
* liefert zu �bergebenem Artikel den Mehrfachnutzen im Werkzeug
*
* falls kein Datensatz gefunden wird, wird ist Nutzen 1 und WkzNr = NIL
************************************************************************************/

CLASS Mehrfach

DATA artNr
DATA wkzNr INIT NIL
DATA Menge INIT 1
DATA Nutzen1 INIT 1
DATA Nutzen2 INIT 1
DATA Gruppe INIT " "

METHOD new( mArtNr, Gruppe )
METHOD isMehrfach()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(mArtNr, Gruppe) CLASS Mehrfach
LOCAL aktSel:=Alias(), merkOrder
LOCAL aktRec , werkzeugGruppen, suchString, pos

  if mArtNr <> NIL

    ::artNr:=mArtNr

    If select("Mehrfach")==0
      if ! open("MehrFach")
        Error(TRY_AGAIN)
        select(aktSel)
        return self
      endif
    endif

    aktRec:=MEHRFACH->(recno())

    // 20210515 hole 1. Werkzeug aus St�ckliste
    // 20241102 falls Gruppe angegeben dann Werkzeug der Gruppe, ansonsten das 1.
    werkzeugGruppen:=Stueckliste():new(mArtNr):getWerkzeugGruppen()
    if len(werkzeugGruppen) > 0
      if valtype(Gruppe) <> "U" // Gruppe vorausgew�hlt
        pos:=aScan(werkzeugGruppen, {|x| x[2]==Gruppe })
        if pos==0 // should never happen
          Error(ACHTUNG+"Gruppe: "+ Gruppe + " nicht gefunden.")
          Trouble("root","Gruppe: "+ Gruppe + " nicht gefunden.  Artikel: "+mArtnr)
          MEHRFACH->(dbgoto(aktRec))
          select(aktSel)
          return NIL
        endif
        suchString:=mArtNr + werkzeugGruppen[pos][1] + werkzeugGruppen[pos][2]
      else // keine Gruppe angegeben, nehme erstes Werkzeug
        suchString:=mArtNr + werkzeugGruppen[1][1]
      endif

      select Mehrfach
      merkOrder:=MEHRFACH->(indexOrd())
      MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr + Gruppe == Artikel + Werkzeug + Gruppe
      MEHRFACH->(dbseek(suchString))
      MEHRFACH->(OrdSetFocus(merkOrder))
      select (aktsel)
      if ! MEHRFACH->(eof())
        ::Menge:=MEHRFACH->Menge
        ::Nutzen1:=MEHRFACH->Nutzen1
        ::Nutzen2:=MEHRFACH->Nutzen2
        ::WkzNr:=MEHRFACH->ArtNr // Hinweis: ArtNr ist hier Werkzeug-Nr
        ::Gruppe:=MEHRFACH->Gruppe
      else // EOF: should ever happen
        Error(ACHTUNG+"Mehrfach: "+ suchString + " nicht gefunden.")
        Trouble("root","Mehrfach: "+ suchString + " nicht gefunden.")
        MEHRFACH->(dbgoto(aktRec))
        select(aktSel)
        return NIL
      endif
    endif
    MEHRFACH->(dbgoto(aktRec))
    select(aktSel)

  endif

RETURN self
/** eom */

METHOD isMehrfach() CLASS Mehrfach
return ::Nutzen1 > 1 .or. ::Nutzen2 > 1
/** eom */

/************************************************************************************/
/* end of Class Mehrfach
/************************************************************************************/


/** Klasse und Funktionen zum Berechnen div. Artikel-Informationen
*
* z.B. Lagerbestand auf Zeitachse
*/

#include "miki.ch"
#include "Zeige.ch"

#include "hbclass.ch"
#include "hbqtgui.ch"

#define COLOR_TODAY QColor(209, 247, 233)

static alloAIs // Referenz auf alle aktuellen


/** Liest und analysiert den Lagerbestand des aktuellen Artikels auf der Achse Zeit */

CLASS ArtikelInfo

DATA artNr READONLY
DATA art READONLY
DATA bestand // READONLY FIXME: disable again once mat aktuell liste is clear
DATA bestandExt READONLY
DATA baugrBestand INIT 0 READONLY // wird nur mit ::readBaugruppenBestand gelesen (kein Default!)
DATA baugrAnzahl INIT 0 READONLY // wird nur mit ::readBaugruppenBestand gelesen (kein Default!)
DATA mindBestand READONLY
DATA Einheit READONLY
DATA isValid INIT .f.
DATA bewegungen INIT {} // HIDDEN
DATA aOberArtikel INIT {} READONLY // ALLE Ober-Artikel des akt. Artikels
DATA artFilter INIT NIL // if specified, only those will be loaded
DATA faktor INIT 1

// flags ob Daten schon hinzugef�gt wurden
DATA auftragsBedarfAdded INIT .f. READONLY

METHOD new(artFilter)
METHOD checkValid()
METHOD readData( ignoreRahmenAB ) HIDDEN
METHOD readBaugruppenBestand()
METHOD lagerBestandUnterNull( datum , toleranz, mindBest )
METHOD getLagerBestandDetails(PrintBuffer)
METHOD getLagerBestand(bisKW)
METHOD getLastLagerBestand()
METHOD getLastBewegungAbgang()
METHOD getLagerFrei(bewegung)
METHOD getBewegungAB(abPostNr)
METHOD getBewegungInner(inLfdNr)
METHOD getBewegungenByArt( Art )
METHOD kalkBestand()
METHOD addCurrentInner()
METHOD getInnerNummern()
METHOD getABNummern()
METHOD getBestNummern()
METHOD addWochenbedarf(Anfrage, anzWochen)
METHOD addWochenbedarfBisNull(wochenMenge)
METHOD addBewegungen(bewegungen)
METHOD setIgnoreBewegungen(Art,value)
METHOD getOberArtikelMaxLagebest()

METHOD isSeitenplatte() HIDDEN

METHOD toPDF()
METHOD toBS()
METHOD toQTList()
METHOD toQTAchseZeit(minKW,maxKW)
METHOD getQTNode(oTree, wrapped, showIgnore)
METHOD getMinMaxKW()
METHOD print(indent)
METHOD debug(prefix)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(artFilter)
LOCAL aktSel:=alias()
LOCAL avOrd:=AVPOST->(indexord())
LOCAL avRec:=AVPOST->(recno())
LOCAL einRec:=EINHEIT->(recno())

  if ARTIKEL->(eof())
    Error("ArtikelInfo: Artikel not found",.t.,"root")
    return NIL
  endif

  EINHEIT->(dbseek(ARTIKEL->ME))

  ::artNr:=ARTIKEL->ArtNr
  ::art:=getArtikelArt()
  ::bestand:=ARTIKEL->LageBest
  ::bestandExt:=ARTIKEL->BestExt
  ::mindBestand:=ARTIKEL->MinbestI
  ::einheit:=EINHEIT->Text
  ::artFilter:=artFilter

  // suche alle OberArtikel zum akt. Artikel
  select AvPost
  AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  dbseek(::ArtNr)
  do while .not. AVPOST->(eof()).and. AVPOST->ArtNr == ::ArtNr
    if AVPOST->Art=="M"
      aadd( ::aOberArtikel , {AVPOST->AvNr,AVPOST->Menge} )
    endif
    skip
  enddo

  AVPOST->(ordSetFocus(avord))
  AVPOST->(dbgoto(avRec))
  EINHEIT->(dbgoto(einRec))
  select (aktsel)

  // add to cache
  default allOAIs:=hb_hash()
  allOAIs[::artNr]:=self

RETURN self

/*----------------------------------------------------------------------*/

/** Pr�ft ob Standard Bewegungen eingelesen sind, wenn nein werden diese eingelesen */
METHOD checkValid()
  if ! ::isValid
    ::readData()
    if ! ::isValid
      troubleEmail("ArtikelInfo - Bewegungen konnten nicht gelesen werden: "+ ::ArtNr )
      return .f. // error w�re besser
    endif
  endif
return .t.

/*----------------------------------------------------------------------*/

METHOD readData( ignoreRahmenAB )
LOCAL bew
LOCAL posNr, alleAbPostNr:={}, reservierungen, reserv
  // LOCAL sAufMenge,sAufgesmenge , minKW, ersteBew, ArtReserv
  // LOCAL numInner, mAufNr,posNrAll, unterNullKW, unterNullBew, hasArtReserv:=.f.

  default ignoreRahmenAB:=.f.

  Umgebung(WRITE_ALL)

  if ! open("AufPost","Aufaus","Inner","BesPost","Artikel","AvPost")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    return self
  endif

  if ::artFilter == NIL .or. BEW_AUFTRAG $ ::artFilter

    select AufPost
    set rela to AUFPOST->AufNr into Aufaus
    index on kwindex(AUFPOST->KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for AUFPOST->ArtNr == ::artNr .and. AUFAUS->erledigt<>"J" .and. AUFAUS->AufArt<>"G" .and. ;
      (AUFPOST->Menge > AUFPOST->GeliefGes .or. AUFAUS->Erledigt=="O")

    go top
    do while ! AUFPOST->(eof())
      bew:=bewegung():new()
      bew:art:=BEW_AUFTRAG
      bew:artNr:=AUFPOST->ArtNr
      bew:KW:=AUFPOST->Kw
      if AUFPOST->Menge > AUFPOST->GeliefGes
        bew:menge:=(AUFPOST->Menge - AUFPOST->GeliefGes) * (-1)
        bew:aufmenge:=(AUFPOST->Menge - AUFPOST->GeliefGes) * (-1)
        bew:aufgesmenge:=AUFPOST->Menge * (-1)
      elseif AUFAUS->Erledigt=="O" // neu 17.12.22 offen -> reservierung bleibt
        bew:menge:=AUFPOST->Menge * (-1)
        bew:aufmenge:=AUFPOST->Menge * (-1)
        bew:aufgesmenge:=AUFPOST->Menge * (-1)
      endif
      bew:gesmenge:=AUFPOST->Menge * (-1)
      bew:nummer:=AUFPOST->AufNr
      bew:aufnr:=AUFPOST->AufNr
      bew:inLfdNr:=AUFPOST->InLfdNr
      bew:AbPostNr:=AUFPOST->AbPostnr
      bew:AufArt:=AUFPOST->AufArt
      bew:aufdat:=AUFPOST->AufDat
      bew:datum:=AUFPOST->Aufdat
      // gilt nur, wenn innerbetr. Auftr�ge automat. generiert werden und noch nicht gedruckt sind
      // bew:ignore:=empty( AUFPOST->InLfdNr ) .and. AUFPOST->Art $ "FX"
      // if ignoreRahmenAB .and. bew:AufArt == BEW_AB_DISPO
      // bew:ignore:=.t.
      // endif

      // 20180815: Auftragsposten werden jetzt �ber ARTRESERV eingelesen (dadurch rekursiv)
      bew:ignore:=.t.
      aadd(::bewegungen,bew)
      skip
    enddo
    AUFPOST->(OrdDestroy(TEMP_INDEX))
    AUFPOST->(ordSetFocus(5)) // AbPostNr
  endif

  if ::artFilter == NIL .or. BEW_INNER_EIGEN $ ::artFilter
    // Inner eigene, ACHTUNG hier Liefer-KW als KW !
    select Inner
    index on kwindex(INNER->Lief_KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for INNER->ArtNr == ::artNr .and. INNER->erledigt<>"J" .and. isInnerHauptArbeitsgang() .and. ;
      INNER->Menge > INNER->GeliefGes
    go top
    do while ! INNER->(eof())
      ::addCurrentInner()
      skip
    enddo
    INNER->(OrdDestroy(TEMP_INDEX))
  endif

  if ::artFilter == NIL .or. BEW_INNER_OBER $ ::artFilter
    // Inner von Ober-Artikel (FIXME: ??? ACHTUNG hier Fert-KW als KW !)
    select Inner
    index on kwindex(INNER->Fert_KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for aScan( ::aOberArtikel ,{ |ober| ober[1]==INNER->artNr} ) > 0;
      .and. INNER->erledigt<>"J" .and. isInnerHauptArbeitsgang() .and. INNER->Menge > INNER->GeliefGes
    go top
    do while ! INNER->(eof())
      bew:=bewegung():new()
      bew:art:=BEW_INNER_OBER
      bew:artNr:=INNER->ArtNr
      posNr:=aScan( ::aOberArtikel , { |ober| ober[1]==INNER->artNr})
      bew:menge:=(INNER->Menge - INNER->GeliefGes) * ::aOberArtikel[posNr,2] * (-1)
      bew:gesmenge:=INNER->Menge * ::aOberArtikel[posNr,2] * (-1)
      bew:KW:=INNER->Lief_kw
      // bew:KW:=INNER->Fert_kw
      bew:oberArtNr:=INNER->ArtNr
      bew:nummer:=INNER->InnerNr
      bew:inLfdNr:=INNER->InLfdNr
      bew:datum:=INNER->Aufdat
      bew:AbPostNr:=INNER->AbPostnr
      if INNER->AbPostnr <> 0
        AUFPOST->(dbseek( INNER->AbPostnr ))
        bew:aufnr:=AUFPOST->AufNr
        bew:aufdat:=AUFPOST->AufDat
        // if AUFPOST->Menge > AUFPOST->GeliefGes
        // 	bew:aufmenge:=(AUFPOST->Menge - AUFPOST->GeliefGes) * (-1)
        // 	bew:aufgesmenge:=AUFPOST->Menge * (-1)
        // endif
        bew:aufkw:=AUFPOST->KW
      endif
      bew:grund:=INNER->Grund
      bew:tiefe:=INNER->Tiefe
      aadd(::bewegungen,bew)
      skip
    enddo
    INNER->(OrdDestroy(TEMP_INDEX))
  endif


  if ::artFilter == NIL .or. BEW_BESTELLUNG $ ::artFilter
    // Bestell-Posten
    select Bespost
    set rela to BESPOST->BestNr into BesAus
    index on kwindex(BESPOST->KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for BESPOST->ArtNr == ::artNr .and. BESAUS->erledigt<>"J" .and. BESPOST->Menge > BESPOST->GeliefGes
    go top
    do while ! BESPOST->(eof())
      bew:=bewegung():new()
      bew:art:=BEW_BESTELLUNG
      bew:artNr:=BESPOST->ArtNr
      bew:menge:=BESPOST->Menge - BESPOST->GeliefGes
      bew:gesmenge:=BESPOST->Menge

      // abweichende Mengeneinheit?
      ARTIKEL->(dbseek( ::artNr ))
      if ARTIKEL->ME <> BESPOST->ME
        // Umrechnung bekannt
        if ARTIKEL->ME2 == BESPOST->Me
          bew:menge:=bew:menge / ARTIKEL->ME_Faktor
          bew:gesmenge:=bew:gesmenge / ARTIKEL->ME_Faktor
        else
          Error(ACHTUNG+"Bestellung: " + BESPOST->Bestnr +"||"+;
            "       "+BESPOST->ArtNr + " " + BESPOST->Me + " Umrechnung nicht bekannt !" + SCHWERER_FEHLER)
        endif
      endif

      bew:KW:=BESPOST->Kw
      bew:nummer:=BESPOST->BestNr
      bew:BesPostNr:=BESPOST->BESPOSTNR
      bew:datum:=BESPOST->AufDat
      aadd(::bewegungen,bew)
      skip
    enddo
    BESPOST->(OrdDestroy(TEMP_INDEX))
  endif

  // Einlesen der Auftragsposten �ber ArtReserv, dadurch rekursiv
  if ::artFilter == NIL .or. BEW_ARTRESERV $ ::artFilter
    // Artikel reserviert, seit 20180814
    // f�r neg. Verf�gbar: Lagerbestands-Bewegungen ohne direkte Zuordnung zu innerbetr. Auftr�gen
    // FIXME: alternatv. Material
    reservierungen:=copyArtReserv(::artNr)
    // set rela to ARTRESKOP->AbPostNr into AufPost
    // index on AUFPOST->AufNr tag TEMP_INDEX2 TEMPORARY ADDITIVE 
    // for ARTRESKOP->ArtNr == ::artNr

    AUFPOST->(ordSetFocus(5)) // AbPostNr

    go top
    for each reserv in reservierungen
      // pr�fe ob inner betr. Auftrag dazu bereits erfasst
      AUFPOST->(dbseek( reserv:AbPostNr ))
      // if AUFPOST->(eof()) .or. reserv:AbPostNr<>AUFPOST->abPostNr
      // altd()
      // endif
      bew:=bewegung():new()
      bew:art:=BEW_ARTRESERV
      bew:artNr:=::ArtNr

      bew:aufKW:=AUFPOST->Kw
      bew:KW:=AUFPOST->Kw
      bew:aufnr:=AUFPOST->AufNr
      bew:oberArtNr:=AUFPOST->ArtNr
      bew:aufdat:=AUFPOST->AufDat
      bew:AbPostNr:=AUFPOST->AbPostnr
      aadd(::bewegungen,bew)
      bew:tiefe:=reserv:Tiefe

      // bew:faktor:=StueckListe():new( AUFPOST->ArtNr ):getChildCount( ::ArtNr , .t. )
      bew:faktor:=reserv:topFaktor
      bew:menge:=reserv:Menge * (-1)
      //bew:aufgesmenge:=bew:faktor * AUFPOST->Menge
    next
  endif

  // disable alle Ober-Bewegung, wenn AB hinterlegt
  // seit 20180821: immer alle Ober Bewegungen raus, lt. H. Weiland kein Problem!!!
  for each bew in ::bewegungen
    if bew:art $ BEW_INNER_OBER  /* .and. ! empty(bew:aufnr) */ .or. left(bew:kw,2)=="X1"
    bew:ignore:=.t.
  endif
next

::isValid:=.t.

Umgebung(LOAD)

RETURN self

  /*----------------------------------------------------------------------*/

// merke Bestand/Anzahl aller Oberbaugruppen (rekursiv!)
// FIXME: could be tuned if multiple oAI are read
METHOD readBaugruppenBestand()
LOCAL baugrBest:=getOberBaugruppenBestand(::ArtNr, .t. )
  ::baugrBestand:=baugrBest[1]
  ::baugrAnzahl:=baugrBest[2]
return self

  /*----------------------------------------------------------------------*/

  /**
  * liefert den Lagerbestand der f�r diese Bewegung (also davor) verf�gbar ist.
  */
METHOD getLagerFrei( bew )
return Max( bew:lgVor , 0 )
/** eom */


  /*----------------------------------------------------------------------*/

  /**
  * sortiert alle Bewegungen nach KW, ignoriert Bewegungen mit ignore == .t.
  * berechnet den jeweiligen Lagerbestand zum Zeitpunkt
  * und liefert all (einschl. der ignorierten) Bewegungen als Array zur�ck
  */
METHOD kalkBestand()
LOCAL bew
LOCAL lastBestand:=Max(::bestand,0) // seit 25.3.19 wird neg.Lagerbestand ignoriert

  if .not. ::checkValid()
    return {}
  endif

  // Bei Dienstleistungen Baugruppen bei Lieferant hinzuz�hlen
  // if ::Art $"D"
  // lastBestand += Max(ARTIKEL->BestExt, 0)
  // endif

  // sortiere alle Bewegungen nach KW und Menge (Eingang immer zuerst!)
  aSort(::bewegungen,,, { |beweg1,beweg2| beweg1:compare(beweg2) > 0 } )

  // berechne Saldos Lagerbestand
  for each bew in ::bewegungen
    bew:lgVor:=lastBestand
    if bew:ignore
      bew:lgNach:=lastBestand // Menge dieser Bewegung wird ignoriert
    else
      bew:lgNach:=lastBestand + bew:menge
      lastBestand:=bew:lgNach
    endif
  next

return ::bewegungen

  /*----------------------------------------------------------------------*/

/** Liefert die Bewegung mit der abPostNummer zur�ck */
METHOD getBewegungAB(nummer)
LOCAL posNr:=0

  // lese bewegungen ein und berechne Lagerbedarf
  if .not. ::checkValid()
    return NIL
  endif

  posNr:=aScan( ::Bewegungen , { |bew| bew:art $ BEW_AUFTRAG .and. bew:AbPostNr == nummer })

return if(posNr==0,NIL,::Bewegungen[posNr])
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert die Bewegung mit der inLfdNr zur�ck */
METHOD getBewegungInner(nummer)
LOCAL posNr:=0

  // lese bewegungen ein und berechne Lagerbedarf
  if .not. ::checkValid()
    return NIL
  endif

  posNr:=aScan( ::Bewegungen , ;
    { |bew| bew:art $ BEW_INNER_EIGEN+BEW_INNER_OBER+BEW_AUFERFAS_E+BEW_AUFERFAS_O .and. ;
    bew:inLfdNr == nummer })

return if(posNr==0,NIL,::Bewegungen[posNr])
/** eom */
/*----------------------------------------------------------------------*/

/** Liefert alle Bewegungen der �bergebeben Art als Array zur�ck */
METHOD getBewegungenByArt( filterArt )
LOCAL result:={}

  // lese bewegungen ein und berechne Lagerbedarf
  if .not. ::checkValid()
    return result
  endif

  aEval( ::Bewegungen , { |bew| if( bew:art $ filterArt , aadd( result , bew ) , NIL) })

  // sortiere Ergebnis nach KW und Menge (Eingang immer zuerst!)
  aSort( result ,,, { |beweg1,beweg2| beweg1:compare(beweg2) > 0 } )

return result
/** eom */


/*----------------------------------------------------------------------*/

/** pr�ft bis zum �bergebenen Datum (default ist alle) ob der
  *   Lagerbestand unter den Mindest-Bestand (!) absackt.
  *
  *   Returns: wenn ja, dann die Bewegung wo der Bestand unter 0 geht ansonsten NIL
  *
  *   Hinweis: hier werden alle Bewegungen in Betracht gezogen auch welche die auf ignore gesetzt sind.
  *
  *   Toleranz: %-Wert der AB-Menge die mind. vorhanden sein muss
  *             z.B. 10%, wenn 100 angefragt werden, m�ssen mind. noch 10 da sein
  *             gilt nur, wenn kein Mind.Bestand. eingegeben ist
  *
  */
METHOD lagerBestandUnterNull(datum, toleranz, mindBest)
LOCAL posNr:=1 , bew , bisKW
LOCAL result:=NIL
LOCAL lastBew

  default toleranz:=0
  default mindBest:=.t.

  if datum <> NIL
    if valtype(datum)=="C"
      bisKW:=datum
    else
      bisKW:=getKW(Datum)
    endif
  endif

  // lese bewegungen ein
  if .not. ::checkValid()
    return result
  endif

  if len( ::bewegungen ) > 0
    // setze alle ignore auf .f. , WARUM? -> raus
    // aEval( ::bewegungen , { |r| r:ignore:=.f. } )

    ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff
    bew:=::bewegungen[posNr]
    do while posNr <= len( :: bewegungen ) .and. (Datum == NIL .or. kwKleiner(bew:kw,bisKW) >= 0 )
      bew:=::bewegungen[posNr]
      if ! bew:ignore
        lastBew:=bew
        if bew:lgNach < 0 // Treffer falls Bestand unter 0
          result:=bew
          exit
        endif
      endif
      posNr++
    enddo
  endif

  // pr�fe letzte (!) Bewegung auf Mindestbestand
  if MindBest
    if lastBew == NIL // keine Bewegung, pr�fe aktuelle Situation
      if ::mindBestand > 0 .and. ::mindBestand > ::bestand
        result:=bewegung():new()
        result:kw:=getCurrentKW()
      endif
    else
      if result == NIL .and. lastBew:lgNach < ::mindBestand .or. ; // Mindest-Bestand
        (::art == "E" .and. ::mindBestand == 0 .and. bew:menge * toleranz / 100 > bew:lgNach ) // Toleranz
        result:=lastBew
      endif
    endif
  endif

RETURN result
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert den verf�gbaren Lagerbestand der letzten Bewegung
  */
METHOD getLastLagerBestand()
LOCAL l:=len(::bewegungen)
  if l == 0
    return ::bestand
  endif
return(::bewegungen[l]:lgNach)

/*----------------------------------------------------------------------*/

/** Liefert die letzte Bewegung mit Abgang
  */
METHOD getLastBewegungAbgang()
LOCAL l:=len(::bewegungen), x:=0
  if l > 0
    do while l > x
      if ::bewegungen[l-x]:menge < 0
        return ::bewegungen[l-x]
      endif
      x+=1
    enddo
  endif
return NIL
/*----------------------------------------------------------------------*/


/** Liefert den verf�gbaren Lagerbestand zum Datum
  *   Default ist heute also der akt. Lagerbestand ARTIKEL->LageBest
  */
METHOD getLagerBestand( bisKW )
LOCAL posNr:=1 , bew

  if bisKW == NIL
    return ::bestand
  endif

  // berechne Lagerbedarf
  if .not. ::checkValid()
    return -99999
  endif

  if len( ::bewegungen ) > 0
    ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff
    do while posNr <= len( :: bewegungen )
      bew:=::bewegungen[posNr]
      if kwKleiner(bew:kw,bisKW) < 0
        posNr-- // der voher ist der letzte Treffer
        exit
      endif
      posNr++
    enddo

    // kein Treffer, nehme also den letzte Bestand
    if posNr==0 // der erste ist schon zu sp�t
      return ::bestand
    endif

    // falls kein Treffer, nimm den letzten
    if posNr > len( :: bewegungen )
      posNr:=len( :: bewegungen )
    endif

    // Falls Treffer ignoriert werden soll, nehme vorherigen
    bew:=::bewegungen[posNr]
    do while bew:ignore .and. posNr > 0
      posNr--
      if posNr==0 // der erste ist schon zu sp�t
        return ::bestand
      endif
      bew:=::bewegungen[posNr]
    enddo

    return bew:lgNach
  endif

RETURN ::bestand
/** eom */

/*----------------------------------------------------------------------*/
METHOD isSeitenplatte()
LOCAL artNrMontageStart:=trim(getProperty("Miki.negverf�g.montage.start",""))
LOCAL artNrMontageEnde:=trim(getProperty("Miki.negverf�g.montage.ende",""))
LOCAL result
  result:=left(::ArtNr,len(artNrMontageStart)) >= artNrMontageStart .and. ;
    left(::ArtNr,len(artNrMontageEnde)) <= artNrMontageEnde
return result

/*----------------------------------------------------------------------*/

// liefert einen PrintBuffer mit Details zum Artikel und Bestand zur�ck (FIXME: is empty)
METHOD getLagerBestandDetails(printBuffer)
LOCAL bew

  Umgebung(WRITE_ALL)

  if .not. ::checkValid()
    Umgebung(LOAD)
    return printBuffer
  endif

  AUFPOST->(ordSetFocus(5)) // AbPostNr
  AUFPOST->(dbClearFilter())

  default printBuffer:=printBuffer():new()

  ->? "InnerNr. Datum     Menge (Rest)     KW   | AB-Nr. Datum     Menge (Bedarf)   KW     Diff | "+;
    " Lg-Best."
  printBuffer:underLine()

  ->? space(88), "|", str(::bestand,9)

  // jetzt alle Bewegungen hinzuf�gen
  for each bew in ::bewegungen

    if ! bew:ignore

      ->? ZEIGE_INNERNR+left(bew:nummer + space(8) , 8)
      ->?? bew:datum
      ->?? transform(bew:gesmenge, "@Z 999999" )
      if bew:menge == 0
        ->?? space(9)
      else
        ->?? left( "(" + alltrim(transform(bew:menge, "@Z 999999" )) + ")" + space(9),9)
      endif
      ->?? left(bew:kw + space(5) , 5)
      ->?? "|"

      if empty( bew:aufNr )
        if bew:AbPostNr <> NIL .and. bew:AbPostNr > 0
          AUFPOST->(dbseek( bew:AbPostNr ))
          ->?? COLOR_RED,ZEIGE_AUFNR+AUFPOST->Aufnr + "  erledigt!!!" + space(27), COLOR_DEFAULT
        else
          ->?? left(bew:grund+space(45),45)
        endif
      else
        ->?? ZEIGE_AUFNR+left(bew:aufnr + space(6) , 6)
        ->?? bew:aufdat
        ->?? transform(bew:aufgesmenge, "@Z 999999" )
        if bew:aufmenge == 0
          ->?? space(9)
        else
          ->?? left( "(" + alltrim(transform(bew:aufmenge, "@Z 999999" )) + ")" + space(9),9)
        endif
        ->?? left(bew:aufkw + space(5) , 5)
        if empty(bew:menge)
          ->?? space(6)
        else
          ->?? transform(max(bew:aufmenge - bew:gesmenge,0), "@Z 999999" )
        endif
      endif
      ->?? "|"

      // if bew:oberArtNr <> ::ArtNr
      // 	->?? ZEIGE_ARTNR+left(bew:oberArtNr+space(8),8)
      // else
      // 	->?? space(8)
      // endif
      ->?? str( bew:lgNach ,9 )

      if getUser():id==KURZEL_DEVEL
        ->?? bew:AbPostNr
      endif

    endif

  next

  Umgebung(LOAD)

return printBuffer

/*----------------------------------------------------------------------*/

/**
  * F�gt den aktuellen Datensatz aus Inner (s. av.prg) hinzu
  * Falls dieser bereits hinzugef�gt wird der alte �berschrieben
  * und ignore auf .f. gesetzt
  *
  * Ergebnis: das hinzugef�gte Bewegungs-Objekt, oder NIL falls nicht relevanter Artikel
  */
METHOD addCurrentInner()
LOCAL bew:=NIL , posNr , altNr

  if INNER->artNr == ::ArtNr .or. ;
    (posNr:=aScan( ::aOberArtikel,{ |ober| ober[1] == INNER->artNr })) > 0

    altNr:=aScan( ::Bewegungen , ;
      { |bew| bew:art $ BEW_INNER_EIGEN .and. bew:inLfdNr == INNER->InLfdNr })
    if altNr > 0
      bew:=::bewegungen[ altNr ]
      altd() // ok, nur bei Fehler
      bew:ignore:=.f.
    else
      bew:=bewegung():new()
      bew:artNr:=INNER->ArtNr
      bew:art:=BEW_INNER_EIGEN
    endif

    bew:menge:=INNER->Menge - INNER->GeliefGes
    bew:gesmenge:=INNER->Menge
    bew:KW:=INNER->Lief_kw
    bew:nummer:=INNER->InnerNr
    bew:inLfdNr:=INNER->InLfdNr
    bew:datum:=INNER->Aufdat
    bew:AbPostNr:=INNER->AbPostnr
    if INNER->AbPostnr <> 0
      AUFPOST->(dbseek( INNER->AbPostnr ))
      bew:aufnr:=AUFPOST->AufNr
      bew:aufdat:=AUFPOST->AufDat
      bew:oberArtNr:=INNER->ArtNr
      // if AUFPOST->Menge > AUFPOST->GeliefGes
      // 	bew:aufmenge:=(AUFPOST->Menge - AUFPOST->GeliefGes) * (-1)
      // endif
      bew:aufkw:=AUFPOST->KW
    endif
    bew:grund:=INNER->Grund
    bew:tiefe:=INNER->Tiefe
    aadd(::bewegungen , bew)
  endif
return bew
/** eom */


/*----------------------------------------------------------------------*/


/** exportiert den aktuellen Stand nach PDF */
METHOD toPDF()
LOCAL zeile:=0 // temp
  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff
  Umgebung(WRITE_ALL)
  set cons off
  Drucker("ON","OAI-"+alltrim(ARTIKEL->ArtNr))
  ? "Verf�gbarkeit Artikel:",out(ARTIKEL->ArtNr),ARTIKEL->Bez1
  if ! empty(ARTIKEL->Bez2)
    ? space(32),ARTIKEL->Bez2
  endif
  ? replicate("=",63)
  ?
  getUser():getCurrentPrintJob():printBuffer( ::getLagerBestandDetails() )
  Drucker("OFF")
  Umgebung(LOAD)
  set cons on
return self
/** eom */

/** zeigt den aktuellen Stand am Bildschirm an*/
METHOD toBS()
LOCAL zeile:=0 // temp
  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff
  Umgebung(WRITE_ALL)
  set cons off
  Drucker("BS","Auftragsbestand - "+alltrim(ARTIKEL->ArtNr))
  getUser():getCurrentPrintJob():printBuffer( ::getLagerBestandDetails() )
  Drucker("OFF")
  Umgebung(LOAD)
  set cons on
return self
  /** eom */

/** liefert als array die erste und letzte Bewegung zur�ck */
METHOD getMinMaxKW()
LOCAL result:={getCurrentKW(), getCurrentKW()}
LOCAL minKW, maxKW, bew

  ARTIKEL->(dbseek( ::artNr ))

  if .not. ::checkValid()
    return NIL
  endif

  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff

  if len(::bewegungen) == 0
    return result
  endif

  for each bew in ::bewegungen
    if ! bew:ignore
      if minKw == NIL
        minKw:=bew:kw
      endif
      maxKW:=bew:Kw
    endif
  next

  result:={minKW, maxKW}

return result
/** eom */

/** zeigt den aktuellen Stand in einer QTList an */
METHOD toQTList()
LOCAL zeile:=0 // temp
LOCAL oWnd:=QMainWindow()
LOCAL oTree , node , root
LOCAL bew , i , qFont
LOCAL titles:={"Art","KZ","Nummer","Datum","KW","Menge","Lg Nach"}

  ARTIKEL->(dbseek( ::artNr ))

  // we ignore some bewegungen others we don't TBD
  // setIgnoreBewegungen(BEW_NOT_IGNORE, .f.)
  // setIgnoreBewegungen(BEW_IGNORE, .t.)

  if getUser():id==KURZEL_DEVEL
    aadd(titles , "inLfdNr")
    aadd(titles , "AbPostNr")
  endif

  oTree:=qtTree():new( oWnd , titles )

  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff

  root:=oTree:getNewTreeItem(::Artnr)
  root:setText( 0 , ::ArtNr)

  // aktueller Lagerbestand als 1. Datensatz
  node:=QTreeWidgetItem()
  i:=0
  node:setText( i, "Lagerbestand:" )
  node:setText( ++i , "" )
  node:setText( ++i , "" )
  node:setText( ++i , dtoc( getUser():date ) )
  node:setText( ++i , getCurrentKW() )
  node:setText( ++i , "" )
  node:setText( ++i , str( ::bestand ,12,2 ) )
  node:setTextAlignment( i , Qt_AlignRight )
  root:addChild( node )

  // jetzt alle Bewegungen hinzuf�gen
  for each bew in ::bewegungen
    node:=QTreeWidgetItem()

    i:=0
    switch bew:art
    case BEW_AUFTRAG
      if bew:AufArt == BEW_AB_DISPO
        node:setText( i, "Rahmen-AB: ")
      else
        node:setText( i, "AB: ")
      endif
      exit
    case BEW_ARTRESERV
      node:setText( i, "AB: ("+bew:oberArtNr+")" )
      exit
    case BEW_INNER_EIGEN
      node:setText( i, "Inner: ")
      exit
    case BEW_INNER_OBER
      node:setText( i, "Inner: ("+bew:oberArtNr+")" )
      exit
    case BEW_BESTELLUNG
      node:setText( i, "Bestellung: " )
      exit
    case BEW_AUFERFAS_E
      node:setText( i, "neu: ")
      exit
    case BEW_AUFERFAS_O
      node:setText( i, "neu: ("+bew:oberArtNr+")" )
      exit
    endswitch

    node:setText( ++i , bew:art )

    if empty( bew:nummer )
      if empty( bew:aufnr )
        node:setText( ++i , alltrim(bew:inLfdNr) )
      else
        node:setText( ++i , alltrim(bew:aufnr) )
      endif
    else
      node:setText( ++i , alltrim(bew:nummer) )
    endif

    if valtype(bew:datum)=="D"
      node:setText( ++i , dtoc( bew:datum ) )
    else
      ++i
    endif
    node:setText( ++i , bew:kw )
    node:setText( ++i , str( bew:menge ,12 ,2 ))
    node:setTextAlignment( i , Qt_AlignRight )
    i++
    if ! bew:ignore
      node:setText( i , str( bew:lgNach ,12,2 ) )
      node:setTextAlignment( i , Qt_AlignRight )

      if bew:lgNach < ::mindBestand // Mindest-Bestand
        node:setForeground( i , QBrush( QColor( Qt_red ) , Qt_SolidPattern ) )
      endif

    endif

    if getUser():id==KURZEL_DEVEL
      node:setText( ++i , bew:inLfdNr )
      if bew:AbPostNr <> NIL
        node:setText( ++i , str( bew:AbPostNr,8) )
      endif
    endif

    // Farben zuweisen

    // ignore -> grau
    if bew:ignore
      for i:=0 to oTree:getColCount()
        node:setForeground( i , QBrush( QColor( if( bew:art==BEW_AUFTRAG , Qt_red , Qt_darkGray );
          ) , Qt_SolidPattern ) )
      next
    endif

    // Falls neu erfasste -> kursiv
    if bew:art $ BEW_AUFERFAS_E + BEW_AUFERFAS_O
      for i:=0 to oTree:getColCount()
        qFont:=node:font(i)
        qFont:setBold( .t. )
        node:setFont(i , qFont )
      next
    endif

    root:addChild( node )
  next

  oTree:addTopLevelItem(root)

  oWnd:setWindowTitle( "Artikel: "+ ::artNr+" "+ARTIKEL->Bez1+"   (Lagerbestand)" )
  oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  oWnd:setCentralWidget( oTree:getWidget() )

  // addQTDock(oWnd,oTree)

  oWnd:resize(550,350)

  oWnd:connect(QEvent_KeyPress, { |x| matKeyPressed(x, oWnd, oTree) } )

  // // Info: no registerDialog() needed, because it is non modal and will be closed by main app
  oWnd:show()

return self
// /** eom */

/** zeigt die Achse Zeit des Artikel in einer QTList an */
METHOD getQTNode(oTree, wrapped, showIgnore)
LOCAL currentKW
LOCAL nodeBewegung,nodeText, root, wrapperNode, text
LOCAL column, line:=1
LOCAL allRows:={}, tooltip, lastBew, bew

  default wrapped:=.f.
  default showIgnore:=.f.

  // debugNr:=getProperty("System.debug.artnr","")
  // if ! empty(debugNr) .and. alltrim(::artNr) == alltrim(debugNr)
  // altd() // ok da abh�ngig von System.debug.artnr
  // endif

  root:=oTree:getNewTreeItem(::Artnr)
  root:setText(0, ::ArtNr)
  root:setText(1, ::art)
  root:setTextAlignment(1, Qt_AlignCenter)
  root:setText(2, str(::baugrBestand,12,0))
  root:setTextAlignment(2, Qt_AlignRight)
  if len(::bewegungen) == 0
    root:setText( 3, str( ::bestand, 12, 0) )
    root:setTextAlignment(3, Qt_AlignRight)
    if ::bestand < 0
      root:setForeground(3, QBrush(QColor(Qt_red)), Qt_SolidPattern)
    endif
  endif

  if wrapped
    wrapperNode:=oTree:getNewTreeItem("Details")
    root:addChild( wrapperNode )
  else
    wrapperNode:=root
  endif
  column:=oTree:kwoffset - 2 // we write Lagerbestand in 1st column before KW

  // jetzt alle Bewegungen hinzuf�gen
  for each bew in ::bewegungen
    lastBew:=bew

    // we ignore some
    if ! showIgnore .and. bew:ignore
      loop
    endif

    // find KW column
    if currentKW <> bew:kw
      // info: this is still the last column here!
      line:=1
      currentKW:=bew:kw
      root:setText( column, str( bew:lgVor, 12, 0) )
      root:setTextAlignment(column, Qt_AlignRight)
      aaddUnique(oTree:showingKWs,bew:kw)

      // find col position in titles by KW
      column:=aScan(oTree:aHeaders, bew:kw) - 1
      if column <= 0
        // troubleEmail("ArtikelInfo - KW: " + bew:KW + " nicht gefunden.  Art.Nr: "+ ::ArtNr )
        // altd() // ok nur bei Fehler
        loop // KW not found we bail out
      endif

    else
      line++
    endif

    // get current row/node
    if len(allRows) >= line
      nodeBewegung:=allRows[line,1]
      nodeText:=allRows[line,2]
    else
      nodeBewegung:=QTreeWidgetItem()
      nodeText:=QTreeWidgetItem()
      aadd(allRows, { nodeBewegung, nodeText} )
      wrapperNode:addChild( nodeText )
      wrapperNode:addChild( nodeBewegung )
    endif

    tooltip:=""

    switch bew:art
    case BEW_AUFTRAG
      if bew:aufArt=="K"
        text:="K:  " + bew:aufNr
      else
        text:="AB: " + bew:aufNr
      endif
      exit
    case BEW_AUFTRAG_OBER
      if bew:aufArt=="K"
        text:="K:  " + bew:aufNr
      else
        text:="AB: " + bew:aufNr
      endif
      tooltip:=bew:oberArtNr
      exit
    case BEW_ARTRESERV
      text:="Res: " + bew:aufNr
      tooltip:=bew:oberArtNr
      exit
    case BEW_INNER_EIGEN
      text:="Inner: " + alltrim(bew:nummer)
      tooltip:=::artnr
      exit
    case BEW_INNER_OBER
      text:="Inner: " + alltrim(bew:nummer)
      tooltip:=bew:oberArtNr
      exit
    case BEW_BESTELLUNG
      text:="Best: " + alltrim(bew:nummer)
      exit
    case BEW_WOCHEN_BEDARF
      text:="Bedarf"
      tooltip:="restlicher Bedarf je Woche"
      exit
    endswitch

    nodeBewegung:setText(column, str(bew:menge, 9, 2))
    nodeBewegung:setTextAlignment(column, Qt_AlignRight)
    nodeText:setText(column , text)
    nodeText:setTextAlignment(column, Qt_AlignRight)

    if ! empty(tooltip)
      nodeBewegung:setToolTip(column,tooltip)
      nodeText:setToolTip(column,tooltip)
    endif

    if bew:menge < 0
      nodeBewegung:setForeground(column, QBrush(QColor(Qt_red)), Qt_SolidPattern)
    elseif bew:menge > 0
      nodeBewegung:setFont(column, QFont("Courier New",10,QFont_Bold))
    endif

    if bew:ignore
      nodeBewegung:setForeground(column, QBrush(QColor(Qt_darkGray)), Qt_SolidPattern)
      nodeText:setForeground(column, QBrush(QColor(Qt_darkGray)), Qt_SolidPattern)
    endif

    if bew:lgNach < 0
      root:setForeground(column, QBrush(QColor(Qt_red), Qt_SolidPattern))
    endif

  next

  // add last lagerbestand
  if lastbew <> NIL
    root:setText( column, str(lastBew:lgNach, 12, 0) )
    root:setTextAlignment(column, Qt_AlignRight)
  endif

  // highlight current week
  column:=aScan(oTree:aHeaders,getCurrentKW()) - 1
  for line:=0 to wrapperNode:childCount() - 1
    wrapperNode:child(line):setBackground(column, QBrush(COLOR_TODAY), Qt_SolidPattern)
  next
  wrapperNode:setBackground(column, QBrush(COLOR_TODAY), Qt_SolidPattern)
  if wrapped
    root:setBackground(column, QBrush(COLOR_TODAY), Qt_SolidPattern)
  endif

return root
// /** eom */

/** zeigt die Achse Zeit des Artikel in einer QTList an */
METHOD toQTAchseZeit(minKW,maxKW)
LOCAL oWnd:=QMainWindow()
LOCAL oTree
LOCAL currentKW, minMax
LOCAL titles:={"Artikel","Art","Baugr.","Lager"}

  ARTIKEL->(dbseek( ::artNr ))

  // we ignore some bewegungen others we don't TBD
  //::setIgnoreBewegungen(BEW_ARTRESERV + BEW_AUFTRAG, .f.)
  //::setIgnoreBewegungen(BEW_IGNORE, .t.)

  if minKw == NIL
    minMax:=::getMinMaxKW()
    if minMax == NIL // ABBRUCH
      return self
    endif
    currentKw:=minMax[1]
    maxKw:=minMax[2]
  else
    currentKw:=minKW
  endif

  // f�lle Spalten je KW
  aadd(titles, currentKW)
  do while kwKleiner(currentKW, maxKW) > 0
    currentKW:=kwIncr(currentKW)
    aadd(titles, currentKW)
  enddo
  // dummy last empty column to catch resize events
  aadd(titles, "")

  oTree:=aiTree():new(oWnd, titles)

  oTree:addTopLevelItem(::getQTNode(oTree, .f., .t.)) // not wrapped, but show ignore

  oTree:getWidget():header:setDefaultAlignment(Qt_AlignCenter)

  oWnd:setWindowTitle( "Artikel: "+ ::artNr+" "+ARTIKEL->Bez1+"   (Lagerbestand)" )
  oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  oWnd:setCentralWidget( oTree:getWidget() )

  oWnd:resize(min(len(titles)*48,1400),350)

  oWnd:connect(QEvent_KeyPress, { |x| matKeyPressed(x, oWnd, oTree) } )

  // // Info: no registerDialog() needed, because it is non modal and will be closed by main app
  oWnd:show()

return self
  // /** eom */


/** zeigt den ArtikelInfos am Bildschirm an*/
METHOD print(indent)
LOCAL b

  default indent:=0

  qout()
  qqout(space(indent), ::artNr ,space(0))
  qqout(space(indent), ::art ,space(0))
  qqout(space(indent), ::bestand ,space(0))
  qqout(space(indent), ::mindBestand ,space(0))
  qqout(space(indent), ::Einheit ,space(0))
  qqout(space(indent), ::isValid ,space(0))
  qout(space(indent), "Bewegungen:",len(::bewegungen) ,space(0))
  for each b in ::bewegungen
    b:print(10)
  next
  // qout(space(indent), "OberArtikel:", len(::aOberArtikel) ,space(0))
  // for each b in ::aOberArtikel
  // qout(space(indent + 10),b[1],b[2])
  // next
return self
/** eom */

/** liefert alle internen  Auftragsnummern des Artikels zur�ck */
METHOD getInnerNummern()
LOCAL result:="" , bew

  if ::checkValid()
    for each bew in ::bewegungen
      if bew:art $ BEW_INNER_EIGEN
        result += alltrim(bew:nummer) + " "
      endif
    next
  endif

return trim(result)
/** eof */

/** liefert alle externen  Auftragsnummern des Artikels zur�ck */
METHOD getABNummern(rekursiv)
LOCAL result:="" , bew
  default rekursiv:=.f.

  if ::checkValid()
    for each bew in ::bewegungen
      if bew:art $ BEW_AUFTRAG + iif(rekursiv,BEW_AUFTRAG_OBER,"") + BEW_ARTRESERV
        if ! bew:aufnr $ result
          result += bew:aufnr + " "
        endif
      endif
    next
  endif

return trim(result)
/** eof */

/** liefert alle externen Bestellnummern des Artikels zur�ck */
METHOD getBestNummern()
LOCAL result:="" , bew

  if ::checkValid()
    for each bew in ::bewegungen
      if bew:art $ BEW_BESTELLUNG
        result += bew:nummer + " "
      endif
    next
  endif

return trim(result)
/** eof */

/*** externe Funtkionen zu ArtikelInfo ***********************************************************************/  

/** liefert den oAI (object ArtikelInfo) zum �bergebenen Artikel oder zum akt. Auferfassg Satz (gechached!),
  * falls ArtNr NIL
  * reset == .t. l�scht den Cache
  *
  * s. oai.ch:
#define OAI_GET                 0   // default
#define OAI_GET_CACHE_ONLY      1   // returns oAI only if already read, otherwise NIL
#define OAI_GET_ALL             2   // returns array of all read oAIs
#define OAI_CLEAR_CURRENT       3
#define OAI_CLEAR_ALL           4
#define OAI_DEBUG               5
  *
  */

function getoAI(action, mArtnr)
LOCAL copyAllOAIs, artNr

  // if mArtNr<>NIL .and. trim(mArtNr) == "5005093"
  // altd()
  // endif

  default action:=OAI_GET

  /* return array of all read oAIs */
  if action == OAI_GET_ALL
    if mArtnr == NIL
      aCopy(alloAIS, copyAllOAIs)
    else
      copyAllOAIs:={}
      for each artNr in alloAIs:Keys
        if eval(mArtNr, alloAIs[artNr])
          aadd(copyAllOAIs, alloAIs[artNr])
        endif
      next

    endif
    return copyAllOAIs
  endif

  /* print all know oAIs, debugging */
  if action == OAI_DEBUG
    for each mArtNr in alloAIs:Keys
      alloAIs[mArtNr]:print()
    next
    wait
    return NIL
  endif

  if alloAIs == NIL .or. action == OAI_CLEAR_ALL
    alloAIs:=hb_hash()

    if mArtnr == NIL .or. action == OAI_CLEAR_ALL
      return NIL
    endif
  endif

  // debug message, default Wert sollte unn�tig sein
  if mArtnr == NIL
    troubleEmail("ArtikelInfo - getOIA ohne ArtikelNr: ")
    default mArtnr:=AUFERFAS->ArtNr
  endif

  if hb_HHasKey( alloAIs , mArtNr )
    if action == OAI_CLEAR_CURRENT
      HDel( alloAIS , mArtNr )
      return NIL
    endif
  else

    if action == OAI_GET_CACHE_ONLY
      return NIL // not found, no read in!
    endif

    // neu einlesen
    ARTIKEL->(dbseek(mArtNr))
    alloAIs[mArtNr]:=ArtikelInfo():new()
    alloAIs[mArtNr]:checkValid()
  endif

return alloAIS[ mArtNr ]
/**  eof */  

/** F�gt die angegebene Menge verteilt auf die Wochen als Bedarf hinzu */
METHOD addWochenbedarf(Anfrage, anzWochen)
LOCAL currentKW:=getCurrentKW()
LOCAL aktKW:=KWIncr(currentKW,1)
LOCAL bew, oberArt, oAI, aktSel:=alias()
LOCAL wochenMenge:=0, diff
LOCAL maxKW // , bestellung:=.f.
LOCAL RestBestand, dlVerfuegbar, bedarfKW:=NIL

  Umgebung(WRITE_ALL)

  // lese bewegungen ein und berechne Lagerbedarf
  if .not. ::checkValid()
    Umgebung(LOAD)
    return NIL
  endif

  default anzWochen:=0
  maxKW:=KWIncr(aktKW, anzWochen)

  ARTIKEL->(dbseek(::ArtNr))

  // debugNr:=getProperty("System.debug.artnr","")
  // if ! empty(debugNr) .and. alltrim(::artNr) == alltrim(debugNr)
  // altd() // ok da abh�ngig von System.debug.artnr
  // endif

  // nur Wochenbedarf wenn Oberbaugruppenbestand im Minus, finde startKW
  for each oberArt in ::aOberArtikel
    oai:=getoAI(OAI_GET_CACHE_ONLY, oberArt[1]) // nur bereits geladene Oberartikel
    if oai <> NIL
      bew:=oAI:lagerBestandUnterNull(,,.f.) // OberArtikel Bedarf
      if bew <> NIL
        if bedarfKW == NIL .or. (kwDiff(bew:kw, bedarfKw) > 0 .and. kwDiff(bew:kw, maxKw) > 0)
          bedarfKW:=bew:KW
        endif
      endif
    endif
  next

  // add Wochen nur wenn Bedarf Oberartikel (s.o.) oder der Artikel selbst ins Minus geht
  bew:=::lagerBestandUnterNull(,,.f.) // self Bedarf
  if bew <> NIL
    if bedarfKW == NIL .or. (kwDiff(bew:kw, bedarfKw) > 0 .and. kwDiff(bew:kw, maxKw) > 0)
      bedarfKW:=bew:KW
    endif
  endif

  // Bei E- und D-Artikeln: wenn bereits offene externe Bestellungen vorhanden
  // sind, dann gilt Mind.Bestand nicht mehr
  // if ARTIKEL->Art $ "ED"
  // SELECT BesPost
  // // Nur offene Bestellungenpr�fen
  // index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE // for BESPOST->ArtNr=ARTIKEL->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes // .and. BESAUS->Erledigt<>"J" .and. ( kwDiff(BESPOST->KW, currentKW) <= 0 .or. BESPOST->GeliefGes == 0)

  // // gefunden?
  // if (BESPOST->(OrdKeyCount()) > 0)
  // bestellung = .t.
  // endif
  // select (aktSel)
  // endif

  if (bedarfKW <> NIL .or. Anfrage > 0) // .and. ! bestellung
    if bedarfKW <> NIL
      aktKW:=bedarfKW
    endif

    // Vorlauf je nach Artikel-Stamm (Mind.Best/Puffer)
    if ARTIKEL->MinPuffer > 0 .and. ARTIKEL->MinbestI > 0
      aktKw:=KWIncr( aktKw, ARTIKEL->MinPuffer * (-1))
      if kWDiff(aktKw, currentKW) >= 0
        aktKw:=kwIncr(currentKW, 1)
      endif
    endif

    // berechne neue Anzahl der Wochen und Wochenmenge
    anzWochen:=KWDiff(aktKW, maxKW)
    if ARTIKEL->MinPuffer > 0
      wochenMenge:=roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer)
    endif
    if anzWochen > 0
      wochenMenge:=max(wochenMenge, roundUp(Anfrage / AnzWochen))
    endif

    // f�lle Wochen auf, bis MaxKW oder Artikel ins Minus geht
    RestBestand:=::bestand
    do while (KWDiff(aktKW, maxKW) > 0 .or. RestBestand > 0) .and. wochenMenge > 0

      // subtrahiere Rest-Menge der bereits vorhanden K-Lager Auftr�ge je KW
      diff:=0
      for each bew in ::bewegungen
        if bew:art $ BEW_AUFTRAG + BEW_AUFTRAG_OBER .and. aktKW == bew:KW .and. bew:AufArt == "K"
          diff += Abs(bew:Menge)
        endif
      next

      // if aktKw=="05/19" .and. ::artnr=="5005222 "
      // altd()
      // endif

      // pr�fe ob in der neuen KW immer noch mind. ein Oberartikel im Minus,
      // kann sich bei DL �ndern, da extern bei Lieferanten
      dlVerfuegbar:=.t.
      do while KWDiff(aktKW, maxKW) > 0 .and. dlVerfuegbar
        dlVerfuegbar:=.f. // only stay in loop in one special case, see below
        for each oberArt in ::aOberArtikel
          oai:=getoAI(OAI_GET_CACHE_ONLY, oberArt[1]) // nur bereits geladene Oberartikel
          if oai <> NIL .and. OAI:art == "D" // nur bei Dienstleistungen, es gibt i.d.R. nur 1 Parent!
            if oAI:getLagerBestand(aktKW) > 0 // OberArtikel Bestand zum Datum
              dlVerfuegbar:=.t.
              aktKW:=kwIncr(aktKw)
              loop
            endif
          endif
        next
      enddo

      // f�ge neuen Datensatz hinzu falls notwendig
      if wochenMenge > diff
        bew:=bewegung():new()
        bew:art:=BEW_WOCHEN_BEDARF
        bew:artNr:=::ArtNr
        bew:KW:=aktKw
        bew:aufMenge:=(wochenMenge - Diff) * (-1)
        bew:menge:=(wochenMenge - Diff) * (-1)
        bew:nummer:="ohne"
        bew:aufnr:="ohne AB"
        bew:ignore:=.f.
        aadd(::bewegungen,bew)
        RestBestand += bew:menge
      endif
      aktKW:=kwIncr(aktKw)

    enddo
  endif

  Umgebung(LOAD)
return self
  /** eom */

/** Braucht die RestMenge nach der letzten Bewegung auf bis unter 0 */
METHOD addWochenbedarfBisNull(wochenMenge)
LOCAL bew, aktKW, RestBestand

  default wochenMenge:=0

  Umgebung(WRITE_ALL)

  // lese bewegungen ein und berechne Lagerbedarf
  if .not. ::checkValid()
    Umgebung(LOAD)
    return NIL
  endif

  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff

  ARTIKEL->(dbseek(::ArtNr))

  // finde letzte Bewegung
  bew:=::getLastBewegungAbgang()
  if bew == NIL
    aktKW:=getCurrentKW()
    RestBestand:=::bestand
  elseif kwKleiner(bew:kw, getCurrentKW()) > 0 // falls in der Vergangenheit, nehme heutiges Datum
    aktKW:=getCurrentKW()
    RestBestand:=bew:lgNach
  else
    aktKW:=KWincr(bew:KW)
    RestBestand:=bew:lgNach
  endif

  // berechne neue Anzahl der Wochen und Wochenmenge
  if ARTIKEL->MinPuffer > 0 .and. wochenMenge == 0
    wochenMenge:=roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer)
  endif

  // f�lle Wochen auf, bis MaxKW oder Artikel ins Minus geht
  do while RestBestand >= 0 .and. wochenMenge > 0
    // f�ge neuen Bewegungs-Datensatz hinzu
    bew:=bewegung():new()
    bew:art:=BEW_WOCHEN_BEDARF
    bew:artNr:=::ArtNr
    bew:KW:=aktKw
    bew:aufMenge:=wochenMenge * (-1)
    bew:menge:=wochenMenge * (-1)
    bew:nummer:="ohne"
    bew:aufnr:="ohne AB"
    bew:ignore:=.f.
    aadd(::bewegungen,bew)
    RestBestand += bew:menge
    aktKW:=kwIncr(aktKw)
  enddo

  Umgebung(LOAD)
return self
  /** eom */

/** f�gt �bergebenes Array mit Bewegungen hinzu */
METHOD addBewegungen(bewegungen)
  ::bewegungen:=aJoin(::bewegungen, bewegungen)
return self
/** eom */

/* setzt die �bergebenen Bewegungs-Arten auf ignore */  
METHOD setIgnoreBewegungen(Art, ignoreIt)
LOCAL bew
  for each bew in ::bewegungen
    if bew:art $ Art
      bew:ignore:=ignoreIt
    endif
  next
return self

METHOD debug(prefix)
LOCAL bew, datei

  default prefix:=""

  datei:="debug-" + prefix + alltrim(::artnr)
  // getUniqueCounter(COUNTER_INCREASE)
  set alte to &(datei)
  set alte on
  set cons off
  ::kalkBestand() // sortiert die Bewegungen vor dem Zugriff
  qout("Anzahl: " +str(len(::bewegungen)))
  for each bew in ::bewegungen
    bew:print()
  next
  set alte off
  set cons on
  close alte
return self

/** Liefert die Art.Nr. des Oberartikels mit dem max. positiven Lagebestand zur�ck (s. email vom 5.11.23)
  * falls keiner Bestand hat, dann keinen (s. email vom 18.12.23)
  */
METHOD getOberArtikelMaxLagebest()
LOCAL oberArt, result , max:=0
LOCAL aktRec:=ARTIKEL->(recno())

  for each oberArt in ::aOberArtikel
    ARTIKEL->(dbseek(oberArt[1]))
    if ARTIKEL->LageBest > max
      result:=ARTIKEL->ArtNr
      max:=ARTIKEL->LageBest
    endif
  next
  ARTIKEL->(dbgoto(aktRec))
return result
/** eom */



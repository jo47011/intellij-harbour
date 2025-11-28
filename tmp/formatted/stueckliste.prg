/************************************************************************************
 * Class StueckListe
 *
 * sollte der einzige Zugriff auf eine StueckListe sein -> Konsistent-Checks
 * z.B. falls f�r eine AB eine alternative St�ckliste verwendet werden soll
 *
 ************************************************************************************/

#include "Miki.ch"
#include "hbclass.ch"


CLASS StueckListe

DATA artNr
DATA art
DATA text
DATA Menge INIT 0 // Menge aus St�ckliste AVPOST->Menge
DATA GesamtMenge INIT 0 // Menge aus St�ckliste AVPOST->Menge * ben�tigte Menge

// FIXME: move the following values to a subclass!
DATA LagerBestand // wird bisher nur optional gesetzt
DATA LagerOrt // wird bisher nur optional gesetzt
DATA BestText INIT "" // 1. KW einer evtl. offenen Bestellung (nur optional gesetzt)
DATA position // wird bisher nur optional gesetzt

// Zeiten

METHOD new( cArtNr , cArt , nMenge )
METHOD getParents( Art )
METHOD getPreviousArtikel( cArt, nMenge )
METHOD getNextArtikel( cArt, nMenge )
METHOD getParentsCount( Art )
METHOD getTopParents()
METHOD getChildren( Art , nurArtikel, rekursiv )
METHOD getMaschinen(nurHauptMaschinen)
METHOD getAlternativeMaschinen()
METHOD getMaschinenByGroup(MaschGr)
METHOD getMaterial( nurArtikel, ArtNr )
METHOD getZeiten( maschNr, HauptKZ, mitGruppenNr )
METHOD getWerkzeuge()
METHOD getFirstWerkzeug()
METHOD getWerkzeugGruppen()
METHOD getWerkzeugMenge()
METHOD getWerkzeugNutzen()
METHOD hasMehrfachEntry()
METHOD getBuchMaterial( Art, mMenge, maxExtKW )
METHOD containsChild( cArtNr , rekursiv )
METHOD getChildCount( cArtNr , rekursiv)
METHOD getAlternativeMaterial()
METHOD getAlternativeParents()
METHOD getAlternativeMaterialInfo()
METHOD getAlternativeTopMaterialInfo()
METHOD getMaterialPreis()

METHOD getChildCountRek( cArtNr , rekursiv, rMenge ) HIDDEN
METHOD getAlternativeTopParents() HIDDEN
METHOD getRekAlternativeMaterial() HIDDEN
METHOD sortkWkzNachStueckliste(werkzeuge, mitGruppenNr) HIDDEN
METHOD getArtikelArt() HIDDEN

  // METHOD clone()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new( cArtNr , cArt , nMenge ) CLASS StueckListe
LOCAL text:=""
  ::artNr:=left(cArtNr+space(ARTNR_GES_LAENGE), ARTNR_GES_LAENGE) // extend art.nr. lengt to 10 characters
  ::art:=cArt
  if valtype(nMenge)=="N"
    ::Menge:=nMenge
  endif
RETURN self

/*----------------------------------------------------------------------*/

  // METHOD clone() CLASS StueckListe
  // LOCAL result:=StueckListe():new(::artNr, ::art, ::Menge)
  // result:text:=::text
  // result:GesamtMenge:=::GesamtMenge
  // result:LagerBestand:=::LagerBestand
  // result:LagerOrt:=::LagerOrt
  // result:BestText:=::BestText
  // result:position:=::position
  // RETURN result


/*----------------------------------------------------------------------*/

/** Liefert alle Artikel-Nr. der Ober-Artikel des Artikels zur�ck (als Array)
*
*
*/
METHOD getParents( avPostArt, ArtikelArt ) CLASS StueckListe
LOCAL result:={}
LOCAL aktOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL aktRec:=AVPOST->(recno())
LOCAL artRec:=ARTIKEL->(recno())
LOCAL aktSel:=alias(), avMenge

  // suche alle OberArtikel zum akt. Artikel
  select AvPost
  AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  dbseek( ::ArtNr )
  do while .not. AVPOST->(eof()).and. trim(AVPOST->ArtNr) == trim(::ArtNr)
    if avPostArt == NIL .or. AVPOST->Art $ avPostArt
      if valtype(ArtikelArt)<>"U"
        ARTIKEL->(dbseek( AVPOST->AvNr ))
        if ! ARTIKEL->Art $ ArtikelArt
          ARTIKEL->(dbgoto(artRec))
          skip
          loop
        endif
        ARTIKEL->(dbgoto(artRec))
      endif
      avMenge:=1
      if valtype(::Menge)=="N" .and. AVPOST->Menge<>0
        avMenge:=::Menge / AVPOST->Menge
      endif

      aadd( result , StueckListe():new( AVPOST->AvNr , AVPOST->Art , avMenge ) )
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( aktOrd ))
  AVPOST->(dbgoto(aktRec))

RETURN result

/** Liefert alle Artikel-Nr. der Ober-Artikel des Artikels zur�ck (als Array), rekursiv
*
* ACHTUNG: Logik bisher nehme immer den Parent mit dem h�chsten Lagerbestand oder den 1.
*/
METHOD getPreviousArtikel( cArt, menge, rekResult ) CLASS StueckListe
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL parents, p, maxBestand:=0, hit
  //LOCAL hauptArtNr:=left(::ArtNr,6)

  default rekResult:={}
  default menge:=1

  parents:=::getParents("M", cArt)
  if len(parents) > 0
    // suche den mit max. Lagerbestand
    for each p in parents
      //if hauptArtNr==left(p:ArtNr,6) // nur bei ident. ersten 6 Ziffern, disabled 20240229
      ARTIKEL->(dbseek( p:ArtNr)) // FIXME: maybe assign in getParents() already?
      if ARTIKEL->LageBest > maxBestand
        maxBestand:=ARTIKEL->LageBest
        hit:=p
      endif
      // endif
    next

    // nehme 1. falls alle ohne Lagerbestand
    if valtype(hit)=="U" // .and. hauptArtNr==left(parents[1]:ArtNr,6)
      hit:=parents[1]
    endif

    if valtype(hit)<>"U"
      hit:LagerBestand:=maxBestand
      aadd( rekResult , hit)
      hit:getPreviousArtikel(cArt, hit:Menge, @rekResult)
    endif

  endif

  ARTIKEL->(dbgoto(aktRec))

RETURN rekResult

/** Liefert alle Artikel-Nr. der Unter-Artikel des Artikels zur�ck (als Array), rekursiv
*
* ACHTUNG: Logik bisher nehme immer den Parent mit dem h�chsten Lagerbestand oder den 1.
*/
METHOD getNextArtikel( cArt, menge, rekResult ) CLASS StueckListe
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL children, child, maxBestand:=0, hit, first
  //LOCAL hauptArtNr:=left(::ArtNr,6)

  default rekResult:={}
  default menge:=1

  children:=::getChildren("M",.t.,.f.) // nur Artikel & nicht rekursiv
  if len(children) > 0
    // suche den mit max. Lagerbestand
    for each child in children
      //if hauptArtNr==left(p:ArtNr,6) // nur bei ident. ersten 6 Ziffern, disabled 20240229
      ARTIKEL->(dbseek( child:ArtNr)) // FIXME: maybe assign in getChildren() already?
      if (valtype(ARTIKEL->Art)=="U" .or. ARTIKEL->Art $ cArt)
        if valtype(first)=="U" // merke 1.
          first:=child
        endif
        if ARTIKEL->LageBest > maxBestand
          maxBestand:=ARTIKEL->LageBest
          hit:=child
        endif
      endif
      // endif
    next

    // nehme 1. falls alle ohne Lagerbestand
    if valtype(hit)=="U" // .and. hauptArtNr==left(children[1]:ArtNr,6)
      hit:=first
    endif

    if valtype(hit)<>"U"
      hit:LagerBestand:=maxBestand
      aadd( rekResult , hit)
      hit:getNextArtikel(cArt, hit:Menge, @rekResult)
    endif

  endif

  ARTIKEL->(dbgoto(aktRec))

RETURN rekResult

/*----------------------------------------------------------------------*/

/** Liefert die Anzahl der Ober-Artikel des Artikels zur�ck
*
*
*/
METHOD getParentsCount( cArt ) CLASS StueckListe
LOCAL result:=0
LOCAL aktOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias()

  // suche alle OberArtikel zum akt. Artikel
  select AvPost
  AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  dbseek( ::ArtNr )
  do while .not. AVPOST->(eof()).and. trim(AVPOST->ArtNr) == trim(::ArtNr)
    if cArt == NIL .or. AVPOST->Art $ cArt
      result++
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( aktOrd ))
  AVPOST->(dbgoto(aktRec))

RETURN result

/** Liefert alle Artikel-Nr. und Menge der obersten Artikel (rekursiv) des Artikels zur�ck (als Array) */
METHOD getTopParents(result) CLASS StueckListe
LOCAL aktOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias()
LOCAL artRec:=ARTIKEL->(recno())
LOCAL stueck

  default result:={}

  // suche alle OberArtikel zum akt. Artikel
  select AvPost
  AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  dbseek( ::ArtNr )
  if AVPOST->(eof()) .and. ::getArtikelArt() $ "MF"
    aadd( result , {::artNr, ::menge})
  else
    do while .not. AVPOST->(eof()).and. trim(AVPOST->ArtNr) == trim(::ArtNr)
      if AVPOST->Art $ "M"
        ARTIKEL->(dbseek( AVPOST->AvNr ))
        stueck:=StueckListe():new( AVPOST->AvNr , ARTIKEL->Art , AVPOST->Menge * ::menge )
        result:=stueck:getTopParents(result)
      endif
      skip
    enddo
  endif

  select (aktSel)
  AVPOST->(OrdSetFocus( aktOrd ))
  AVPOST->(dbgoto(aktRec))
  ARTIKEL->(dbgoto(artRec))

RETURN result

/** Liefert alle Artikel-Nr. der Unter-Artikel des Artikels zur�ck (als Hashtable mit key: ArtNr) */
METHOD getChildren( cArt, nurArtikel, rekursiv, rekResult ) CLASS StueckListe
LOCAL aktOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias(), stueck

  default nurArtikel:=.t.
  default rekResult:=hb_Hash()
  default rekursiv:=.f.

  // suche alle UnterArtikel zum akt. Artikel
  select AvPost
  AVPOST->(ordSetFocus(1)) // AvNr + ArtNr

  dbseek( ::ArtNr )
  do while .not. AVPOST->(eof()).and. AVPOST->AvNr == ::ArtNr
    if (cArt == NIL .or. AVPOST->Art $ cArt) .and. (!nurArtikel .or. AVPOST->Text="A")
      if hb_HHasKey( rekResult, AVPOST->ArtNr)
        stueck:=rekResult[AVPOST->ArtNr]
        stueck:menge += (::Menge*AVPOST->Menge)
      else
        stueck:=StueckListe():new( AVPOST->ArtNr , AVPOST->Art , ::Menge*AVPOST->Menge )
        rekResult[AVPOST->ArtNr]:=stueck
      endif
      if rekursiv
        stueck:getChildren(cArt, nurArtikel, rekursiv, @rekResult)
      endif
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( aktOrd ))
  AVPOST->(dbgoto(aktRec))

RETURN rekResult

/*----------------------------------------------------------------------*/

/** Liefert .t. wenn ein Artikel in einer Material-Unterst�ckliste vorkommt
*
* ArtNr: gesuchter Artikel
* Rekursiv: falls .f. (default) wird nur 1 Ebene darunter gepr�ft, ansonsten alle (rekursiv)
*
*/
METHOD containsChild( cArtNr , rekursiv ) CLASS StueckListe
LOCAL result:=.f.
LOCAL aktOrd:=AVPOST->(indexOrd())
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias()

  default rekursiv:=.f.

  // suche UnterArtikel
  select AvPost
  AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  dbseek(cArtNr + ::ArtNr )
  if ! AVPOST->(eof()) // auf akt. Ebene gefunden
    result:=.t.
  endif

  if rekursiv .and. ! result // such rekursiv weiter
    AVPOST->(ordSetFocus(1)) // AvNr
    dbseek(::ArtNr + "M")
    do while .not. AVPOST->(eof()) .and. AVPOST->AvNr == ::ArtNr .and. AVPOST->Art=="M" .and.;
      ! result
      result:=StueckListe():new( AVPOST->ArtNr ):containsChild( cArtNr , rekursiv )
      skip
    enddo
  endif

  AVPOST->(ordSetFocus(aktOrd))
  AVPOST->(dbgoto(aktRec))
  select (aktSel)
RETURN result

/** Liefert die wie oft Artikel in einer Material-Unterst�ckliste vorkommt
*
* ArtNr: gesuchter Artikel
* Rekursiv: falls .f. (default) wird nur 1 Ebene darunter gepr�ft, ansonsten alle (rekursiv)
* rMenge: internal
*
*/
METHOD getChildCount( cArtNr , rekursiv ) CLASS StueckListe

  // if ::ArtNr == cArtNr
  // return 1
  // endif

return ::getChildCountRek( cArtNr , rekursiv, 1 )
/** eom */

/** Liefert die wie oft Artikel in einer Material-Unterst�ckliste vorkommt
*
* ArtNr: gesuchter Artikel
* Rekursiv: falls .f. (default) wird nur 1 Ebene darunter gepr�ft, ansonsten alle (rekursiv)
* rMenge: internal
*
*/
METHOD getChildCountRek( cArtNr , rekursiv, rMenge ) CLASS StueckListe
LOCAL aktOrd:=AVPOST->(indexOrd())
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias()
LOCAL result:=0

  default rekursiv:=.f.
  default rMenge:=1

  if ::ArtNr == cArtNr
    return rMenge
  endif

  // suche UnterArtikel
  select AvPost
  // AVPOST->(ordSetFocus(2)) // ArtNr + AvNr

  // dbseek(cArtNr + ::ArtNr )
  // if ! AVPOST->(eof()) // auf akt. Ebene gefunden
  // do while ! AVPOST->(eof()) .and. AVPOST->ArtNr == cArtNr .and. AVPOST->AvNr == ::ArtNr // auf akt. Ebene gefunden
  // if AVPOST->Art=="M"
  // 	result += AvPost->Menge * rMenge
  // endif
  // skip
  // enddo
  // endif

  // if rekursiv // such rekursiv weiter
  AVPOST->(ordSetFocus(1)) // AvNr
  dbseek(::ArtNr + "M")
  do while .not. AVPOST->(eof()) .and. AVPOST->AvNr == ::ArtNr .and. AVPOST->Art=="M"

    result;
      +=;
      StueckListe():new( AVPOST->ArtNr ):getChildCountRek( cArtNr , rekursiv , AVPOST->Menge *;
      rMenge )
    skip
  enddo
  // endif

  AVPOST->(ordSetFocus(aktOrd))
  AVPOST->(dbgoto(aktRec))
  select (aktSel)

RETURN result

/*----------------------------------------------------------------------*/

/** Liefert alle Maschineneintr�ge (Haupt- und Neben) aus der Zeit-St�ckliste als Array
  * default ist alle.
*/
METHOD getMaschinen(nurHauptMaschinen)
LOCAL result:={}
LOCAL aktOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL aktRec:=AVPOST->(recno())
LOCAL aktSel:=alias()
LOCAL maschKz

  default nurHauptMaschinen:=.f.
  if nurHauptMaschinen
    maschKZ:="H"
  else
    maschKZ:="HN"
  endif

  select AvPost
  AVPOST->(ordSetFocus(1)) // AvNr

  dbseek( ::ArtNr )
  do while .not. AVPOST->(eof()).and. AVPOST->AvNr == ::ArtNr
    if AVPOST->Art == "V" // nur Zeit-St�cklisten
      if (AVPOST->HauptKZ $ MaschKz .and. AVPOST->Text=="A")
        aadd( result , trim( AVPOST->ArtNr ) )
      endif
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( aktOrd ))
  AVPOST->(dbgoto(aktRec))

return result
/** eom */

/** Liefert alle Maschineneintr�ge (Haupt- und Neben) aus der Zeit-St�ckliste als Array
  * inkl alle Maschinen der Maschinen-Gruppe inkl. der Obergruppen.  
*/
METHOD getAlternativeMaschinen(inklVerschrottet)
LOCAL maschnr, result:={}
LOCAL aktRec:=MASCHINE->(recno())

  default inklVerschrottet:=.f.

  for each maschNr in ::getMaschinen()
    aadd( result , maschNr)

    MASCHINE->(dbseek( maschNr ))
    if ! empty(MASCHINE->MaschGr) .and. MASCHINE->Status <> "X"
      result:=aJoinUnique(result, ::getMaschinenByGroup(MASCHINE->MaschGr, inklVerschrottet))
    endif
    MASCHINE->(dbgoto(aktRec))
  next

return result
/** eom */

/** Liefert alle Maschinen der Maschinen-Gruppe inkl. der Obergruppen.
*/
METHOD getMaschinenByGroup(MaschGr, inklVerschrottet)
LOCAL result:={}
LOCAL aktRec:=MASCHINE->(recno())
LOCAL aktRecGr:=MASCHGR->(recno())
LOCAL aktSel:=alias()

  default inklVerschrottet:=.f.

  MASCHINE->(dbgotop())
  do while ! MASCHINE->(eof())
    if maschGr == MASCHINE->MaschGr .and. (inklVerschrottet .or. MASCHINE->Status <> "X")
      aadd( result , MASCHINE->StdNr)
    endif
    MASCHINE->(dbskip())
  enddo
  MASCHINE->(dbgoto(aktRec))

  // rekursiv Untergruppe if applicable
  select MaschGr
  MASCHGR->(dbseek(MaschGr))
  if ! MASCHGR->(eof()) .and. ! empty(MASCHGR->ChildGr)
    result:=aJoinUnique(result, ::getMaschinenByGroup(MASCHGR->ChildGr))
    cont
  endif
  MASCHGR->(dbgoto(aktRecGr))
  select (aktSel)

return result
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert alles Material (jeweils als Instanz dieser Klasse) aus der Mat-St�ckliste als Array

  Parameter:
    nurArtikel: falls true werden nur Artikel zur�ck geliefert
    ArtNr: (optional) falls angegeben wird nur dieses Material zur�ckgeliefert
*/
METHOD getMaterial( nurArtikel, mArtNr )
LOCAL result:={} , mat
LOCAL avOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL avRec:=AVPOST->(recno())
LOCAL aktSel:=alias()

  default nurArtikel:=.t.

  select AvPost
  AVPOST->(ordSetFocus(1)) // AvNr == normale St�ckliste
  dbseek( ::ArtNr + "M")
  do while .not. AVPOST->(eof()).and. AVPOST->AvNr == ::ArtNr .and. AVPOST->Art=="M"
    if (AVPOST->Text=="A" .or. ! nurArtikel) .and. (mArtNr == NIL .or. mArtNr==AVPOST->ArtNr)

      mat:=StueckListe():new( AVPOST->ArtNr , AVPOST->Art, AVPOST->Menge)
      mat:text:=AVPOST->Text

      aadd( result , mat)
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( avOrd ))
  AVPOST->(dbgoto(avRec))

return result
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert alle Zeiten (jeweils ZeitStueckListe s.u.) aus der Zeiten-St�ckliste als Array
  * optionale Parameter:
  *    - MaschNr (AVPOST->StdNr) -> nur diese werden kopiert
  *    - HauptKz -> falls gesetzt nur diese werden kopiert
  *    - mitGruppenNr -> falls true wird zeit:MaschGr := MASCHINE->MaschGr gesetzt
*/
METHOD getZeiten( maschnr, HauptKZ, mitGruppenNr)
LOCAL result:={} , zeit
LOCAL avOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
LOCAL avRec:=AVPOST->(recno())
LOCAL aktSel:=alias()

  default mitGruppenNr:=.f.

  select AvPost
  AVPOST->(ordSetFocus(1)) // AvNr == normale St�ckliste
  dbseek( ::ArtNr + "V" )
  do while .not. AVPOST->(eof()).and. AVPOST->AvNr == ::ArtNr .and. AVPOST->Art == "V"
    if AVPOST->Text=="A" .and. ;
      (valtype(maschNr) == "U" .or. maschNr == alltrim(AVPOST->ArtNr)) .and. ;
      (valtype(HauptKZ) == "U" .or. HauptKZ == alltrim(AVPOST->HauptKZ))

      zeit:=ZeitStueckListe():new( AVPOST->ArtNr , AVPOST->Art, AVPOST->Menge)
      zeit:text:=AVPOST->Text
      zeit:HauptKZ:=AVPOST->HauptKZ
      zeit:Automat:=AVPOST->Automat
      zeit:Nutzen1:=AVPOST->Nutzen1
      zeit:Nutzen2:=AVPOST->Nutzen2
      zeit:RuestZeit:=AVPOST->RuestZeit
      zeit:SollMenge:=AVPOST->sollMenge

      if mitGruppenNr
        MASCHINE->(dbseek(trim(AVPOST->ArtNr)))
        zeit:maschGr:=MASCHINE->MASCHGR
      endif

      aadd( result , zeit)
    endif
    skip
  enddo

  select (aktSel)
  AVPOST->(OrdSetFocus( avOrd ))
  AVPOST->(dbgoto(avRec))

return result
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert alle Werkzeuge aus der Mehrfach.dbf (Taste T) als Array mit den Artikel-Nummern.
  *
  * Falls mitGruppenNr als Array {ArtNr, GruppenNr, Nutzen1, Nutzen2}
  *
  * 20210515: sortiert nach Reihenfolge in St�ckliste
*/
METHOD getWerkzeuge(mitGruppenNr, sorted)
LOCAL result:={}
LOCAL avOrd
LOCAL avRec
LOCAL aktSel:=alias()

  default sorted:=.t.
  default mitGruppenNr:=.f.

  if open("Mehrfach")
    avOrd:=MEHRFACH->(indexOrd())
    avRec:=MEHRFACH->(recno())

    select MEHRFACH
    MEHRFACH->(ordSetFocus(2)) // ArtNr, nicht Werkzeug
    MEHRFACH->(dbseek( ::ArtNr ))
    do while .not. MEHRFACH->(eof()).and. MEHRFACH->ANr == ::ArtNr
      aaddUnique( result , if(mitGruppenNr, ;
        {MEHRFACH->ArtNr, MEHRFACH->Gruppe, MEHRFACH->Nutzen1, MEHRFACH->Nutzen2} , ;
        MEHRFACH->ArtNr))
      skip
    enddo

    MEHRFACH->(OrdSetFocus( avOrd ))
    MEHRFACH->(dbgoto(avRec))
  endif
  select (aktSel)

  if len(result) == 0
    return result
  endif

  if sorted
    result:=::sortkWkzNachStueckliste(result, mitGruppenNr)
  endif

return result
/** eom */

/*----------------------------------------------------------------------*/

/** Liefert die Artikel-Nummern des ersten Werkzeug aus der Mehrfach.dbf (Taste T).
  *
  * Falls es mehrere gibt kommt eine Warnung am BS und das erste wird genommen.
  * NIL falls kein Werkzeug hinterlegt.
*/
METHOD getFirstWerkzeug()
LOCAL werkzeuge:=::getWerkzeuge()
LOCAL merkOrder:=MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr == Artikel + Werkzeug
LOCAL result:=NIL

  if len(werkzeuge) > 0
    MEHRFACH->(dbseek( ARTIKEL->ArtNr + werkzeuge[1]))
    if ! MEHRFACH->(eof())
      if len(werkzeuge) > 1
        Error(ACHTUNG+"Mehrere Werkzeuge gefunden:||"+array2readable(werkzeuge)+"||"+;
          "Nehme erstes Werkzeug aus St�ckliste: "+werkzeuge[1])
      endif
      result:=werkzeuge[1]
      MEHRFACH->(OrdSetFocus(merkOrder))
    endif
  endif

return result

/*----------------------------------------------------------------------*/
/** sortiert das �bergebene Array nach der Reihenfolge der Werkzeuge in der St�ckliste */
METHOD sortkWkzNachStueckliste(werkzeuge, mitGruppenNr)
LOCAL result:={} , wkzOK:={}, diff
LOCAL avOrd, avRec
LOCAL aktSel:=alias()
LOCAL merkFilter:=AVPOST->(dbfilter())
LOCAL i

  default mitGruppenNr:=.f.

  if open("AvPost")
    AVPOST->(DbClearFilter())
    avOrd:=AVPOST->(indexOrd()) // Info: ohne Umgebung, ansonsten flackert's
    avRec:=AVPOST->(recno())
    AVPOST->(ordSetFocus(1)) // AvNr == normale St�ckliste
    dbseek( ::ArtNr + "W")

    do while .not. AVPOST->(eof()) .and. AVPOST->AvNr == ::ArtNr .and. AVPOST->Art=="W"
      if AVPOST->Text=="A"
        for i:=1 to len(werkzeuge)
          if mitGruppenNr
            if werkzeuge[i,1] == AVPOST->Artnr
              aaddUnique( result , werkzeuge[i])
              aadd(wkzOK, werkzeuge[i])
            endif
          else
            if werkzeuge[i]==AVPOST->Artnr
              aaddUnique( result , werkzeuge[i])
              aadd(wkzOK, werkzeuge[i])
            endif
          endif
        next
      endif
      skip
    enddo

    diff = aDiff(werkzeuge, wkzOK)
    if len(diff) > 0
      if getUser():getCurrentPrintJob() == NIL
        Error(ACHTUNG+"Werkzeuge fehlen in St�ckliste:||"+array2readable(diff))
      else
        Protokoll(PROTOKOLL,out(::ArtNr)+" "+ARTIKEL->Bez1+space(8)+;
          "Werkzeuge fehlen in St�ckliste: "+array2readable(diff))
      endif
    endif

    set filter to &(merkFilter)
  endif

  select (aktSel)
  AVPOST->(OrdSetFocus( avOrd ))
  AVPOST->(dbgoto(avRec))

return result

/*----------------------------------------------------------------------*/
/** Liefert alle Werkzeuge aus der Mehrfach.dbf (Taste T) als Array:
  *
  *  {ArtNr, GruppenNr, Nutzen1, Nutzen2}
*/
METHOD getWerkzeugGruppen()
return ::getWerkzeuge(.t.)

/*----------------------------------------------------------------------*/

/** Liefert die Werkzeug Menge (ARIKEL->WkzNutzen) (alt: des 1. Werkzeugs) aus der Mehrfach.dbf (Taste T).
  *
  * NEU: liefert ein Array von int mit der Menge aller vorkommenden Werkzeuge/Gruppen
*/
METHOD getWerkzeugMenge()
LOCAL wkz, merkOrder, zwSumme, myGruppe
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL result:={}

  // Werkzeug?
  ARTIKEL->(dbseek( ::ArtNr ))
  if ARTIKEL->Art == "W" // artikel ist werkzeug
    MEHRFACH->(dbseek(::ArtNr))
    do while ! MEHRFACH->(eof()) .and. ::ArtNr==MEHRFACH->ArtNr
      zwSumme:=0
      myGruppe:=MEHRFACH->Gruppe
      do while ! MEHRFACH->(eof()) .and. ::ArtNr==MEHRFACH->ArtNr .and. myGruppe==MEHRFACH->Gruppe
        zwSumme += MEHRFACH->Menge
        MEHRFACH->(dbskip())
      enddo
      aaddUnique(result, int(zwSumme))
    enddo
  else
    // Artikel
    merkOrder:=MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr == Artikel + Werkzeug
    for each wkz in ::getWerkzeuge()
      MEHRFACH->(dbseek( ::ArtNr + wkz))
      do while ! MEHRFACH->(eof()) .and. ::ArtNr==MEHRFACH->ANr
        aaddUnique(result, int(MEHRFACH->Menge))
        MEHRFACH->(dbskip())
      enddo
    next
    MEHRFACH->(OrdSetFocus(merkOrder))
  endif

  if len(result)==0
    aadd(result,1) // default ist 1
  endif
  ARTIKEL->(dbgoto(aktRec))

return result
  /** eom */

/** Liefert die Werkzeug Nutzen (MEHRFACH->Nutzen1 / MEHRFACH->Nutzen2) als array of int
  *
  * NEU: liefert ein Array von int mit der Nutzen aller vorkommenden Werkzeuge/Gruppen
*/
METHOD getWerkzeugNutzen()
LOCAL wkz, merkOrder
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL result:={}

  // Werkzeug?
  ARTIKEL->(dbseek( ::ArtNr ))
  if .not. ARTIKEL->Art == "W" // artikel ist KEIN werkzeug
    // Artikel
    merkOrder:=MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr == Artikel + Werkzeug
    for each wkz in ::getWerkzeuge()
      MEHRFACH->(dbseek( ::ArtNr + wkz))
      do while ! MEHRFACH->(eof()) .and. ::ArtNr==MEHRFACH->ANr
        aaddUnique(result, {MEHRFACH->Nutzen1, MEHRFACH->Nutzen2})
        MEHRFACH->(dbskip())
      enddo
    next
    MEHRFACH->(OrdSetFocus(merkOrder))
  endif

  if len(result)==0
    aadd(result,{1,1}) // default ist 1/1 -> ganzer Nutzen
  endif
  ARTIKEL->(dbgoto(aktRec))

return result
  /** eom */

/** Liefert .t. wenn es f�r den Artikel Mehrfach Eintr�ge gibt */
METHOD hasMehrfachEntry()
LOCAL aktRec:=MEHRFACH->(recno())
LOCAL result:=.f., merkOrder

  if ::getArtikelArt() == "W"
    MEHRFACH->(dbseek( ::ArtNr))
    result:=! MEHRFACH->(eof())
  else
    merkOrder:=MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr == Artikel + Werkzeug
    MEHRFACH->(dbseek( ::ArtNr))
    result:=! MEHRFACH->(eof())
    MEHRFACH->(OrdSetFocus(merkOrder))
    MEHRFACH->(dbGoto(aktRec))
  endif

return result
/** eof */

/* internal workaround if art not specified upon creation 20250924 */
METHOD getArtikelArt()
LOCAL artRec

  if myempty(::art)
    artRec:=ARTIKEL->(recno())
    ARTIKEL->(dbseek(::ArtNr))
    ::Art:=ARTIKEL->Art
    ARTIKEL->(dbgoto(artRec))
    troubleemail("Stueckliste Art fehlt => fixed "+::ArtNr+" => "+::art)
  endif

return ::art



/*----------------------------------------------------------------------*/

/** Liefert ist des zu buchendes Material inkl. aktuell ben�tigtes alternatives Material
    Art: die Art der Berechung
       AUFBESTAND_STATUS:  nur aktuelle Status Abfrage, mit allen Reservierungen etc.,
                           geht immer nur 1 Ebene tiefer egal welcher Lagerbestand vom TopArtikel vorhanden
                           au�er bei alternat. Material STRG-M da bis genug Bestand da ist

       AUFBESTAND_ABFRAGE: aktuelle Abfrage, alte Reserveriungen (ARTIKEL->disponiert) werden ignoriert
                           geht nicht rek. in alle Ebenen runter, sondern nur auf 1. Ebene

       AUFBESTAND_BERECHNEN: wird neu berechnet, alte Reserveriungen (ARTIKEL->disponiert) werden ignoriert
                             geht rek. in alle Ebenen runter
    mMenge:    ben�tigte Menge
    maxExternKW: falls .f. dann ohne externe Bestellungen (default)
                 falls .t. dann mit externe Bestellungen
                 falls eine KW dann inkl. aller Bestellungen, die bis zu dieser KW geliefert werden. 
*/
METHOD getBuchMaterial( art, mMenge, maxExtKW )
LOCAL result:={} , mat, mat2
Local alleArtikel:=hb_Hash()
LOCAL offeneBestellungen:=hb_Hash()
LOCAL alleReservierungen:={}

  Umgebung(WRITE_ALL)

  AufBestRek(art , @alleArtikel , @alleReservierungen, @offeneBestellungen, ::ArtNr , mMenge,;
    maxExtKW )

  for each mat2 in alleReservierungen

    if mat2:ArtNr <> ::Artnr .and. mat2:disponiert <> 0 // ungleich 0, da neg. Buchung hier m�glich!
      ARTIKEL->(dbseek( mat2:ArtNr ) )
      mat:=StueckListe():new( mat2:ArtNr , mat2:Art, mat2:topFaktor )
      mat:gesamtMenge:=mat2:disponiert
      mat:text:=if(mat2:Art=="T","T","A")
      mat:BestText:=mat2:BestText
      mat:LagerBestand:=mat2:LageBest
      mat:LagerOrt:=getArtikelLagerOrt(30)
      aadd( result , mat)
    endif
  next

  Umgebung(LOAD)
return result
/** eom */

/*----------------------------------------------------------------------*/

METHOD getAlternativeMaterial() CLASS StueckListe
LOCAL artRec:=ARTIKEL->(recno())
LOCAL artOrd:=ARTIKEL->(OrdSetFocus(1)) // Art.Nr.
LOCAL result
  ARTIKEL->(dbseek( ::ArtNr ) )
  result:=ARTIKEL->MatArtNr
  ARTIKEL->(OrdSetFocus( artOrd ))
  ARTIKEL->(dbgoto(artRec))
return result
/** eom */


/*----------------------------------------------------------------------*/

METHOD getAlternativeParents() CLASS StueckListe
LOCAL artRec:=ARTIKEL->(recno())
LOCAL artOrd:=ARTIKEL->(OrdSetFocus(3)) // MatArtNr (alternat. St�ckliste)
LOCAL result:={}

  ARTIKEL->(dbseek( ::ArtNr ) )
  do while ! ARTIKEL->(eof()) .and. ARTIKEL->MatArtnr == ::Artnr
    aadd( result , StueckListe():new( ARTIKEL->ArtNr , "M" , ARTIKEL->MatFaktor ))
    ARTIKEL->(dbskip())
  enddo

  ARTIKEL->(OrdSetFocus( artOrd ))
  ARTIKEL->(dbgoto(artRec))
return result
/** eom */

/*----------------------------------------------------------------------*/

METHOD getAlternativeTopMaterialInfo() CLASS StueckListe
LOCAL result:="", parent , topMaterial, mat

  topMaterial:=::getAlternativeTopParents()

  for each mat in topMaterial
    for each parent in mat:getParents("M")
      result += parent:getAlternativeMaterialInfo() + MY_CR+MY_LF
      result += replicate("-",63) + MY_CR+MY_LF
    next
  next

return result
/** eom */

/*----------------------------------------------------------------------*/
METHOD getAlternativeTopParents() CLASS StueckListe
LOCAL parents:=::getAlternativeParents() , p
LOCAL result:={}

  if len(parents) == 0
    return { self } // no more parent -> return current
  endif

  for each p in parents
    result:=aJoin( result , p:getAlternativeTopParents() )
  next

return result
/** eom */
/*----------------------------------------------------------------------*/

METHOD getRekAlternativeMaterial(altMaterial) CLASS StueckListe
LOCAL artRec:=ARTIKEL->(recno())
LOCAL artOrd:=ARTIKEL->(OrdSetFocus(1)) // Art.Nr.
LOCAL stkListe

  ARTIKEL->(dbseek( ::ArtNr ) )

  if ! empty( ARTIKEL->MatArtNr )

    stkListe:=StueckListe():new( ARTIKEL->MatArtNr)
    stkListe:menge:=ARTIKEL->MatFaktor
    stkListe:gesamtMenge:=ARTIKEL->MatFaktor * ::gesamtMenge
    aadd( altMaterial , stkListe )

    stkListe:getRekAlternativeMaterial(@altMaterial)
  endif

  ARTIKEL->(OrdSetFocus( artOrd ))
  ARTIKEL->(dbgoto(artRec))
return .t.
/** eom */


METHOD getAlternativeMaterialInfo() CLASS StueckListe
LOCAL material:=::getMaterial()
LOCAL mat, mat2 , altMaterial:={}
LOCAL result:=""

  ARTIKEL->(dbseek( ::ArtNr ) )
  result += space(44) + "St�ckzahl      Faktor" + MY_CR+MY_LF
  result += ::ArtNr + " " + ARTIKEL->Bez1 + MY_CR+MY_LF

  for each mat in Material
    mat:gesamtMenge:=mat:Menge
    aadd( altMaterial , mat )
    ::getRekAlternativeMaterial(mat , @altMaterial)
    for each mat2 in altMaterial
      ARTIKEL->(dbseek( mat2:ArtNr ) )
      result += mat2:ArtNr + " " + ARTIKEL->Bez1 + ;
        transstr( mat2:GesamtMenge , 12, 3) + transstr( mat2:Menge , 12, 3) + MY_CR+MY_LF
    next
  next

return result

/*----------------------------------------------------------------------
  * liefert die Summe des Kalk.Preises aller Eintr�ge aus der Material-St�ckliste
  */

METHOD getMaterialPreis() CLASS StueckListe
LOCAL material:=::getMaterial()
LOCAL mat
LOCAL result:=0, faktor
LOCAL aktRec:=ARTIKEL->(recno())

  for each mat in Material
    ARTIKEL->(dbseek( mat:ArtNr ) )
    faktor:=if(ARTIKEL->Schluessel=="H",100,1)
    result += (mat:Menge * ARTIKEL->KaPr / faktor)
  next

  ARTIKEL->(dbgoto(aktRec))

return result
  /** eom */

  /*----------------------------------------------------------------------*/


/************************************************************************************/
/* end of Class StueckListe
/************************************************************************************/

/** temp Datensatz zur Berechnung des Auftragsbestands */
CLASS ArtikelDisponiert // Reservierung

DATA artNr
DATA art
DATA menge INIT 0
DATA Einheit
DATA Text INIT ""
DATA Tiefe
DATA lageBest INIT 0
DATA disponiert INIT 0
DATA fehlMenge INIT 0
DATA BestText INIT ""
DATA AlternZu INIT "" // was AlternativeZu
DATA topFaktor INIT 1
DATA AbPostNr
DATA MatArtNr
DATA MatFaktor

METHOD new(mArtNr)
METHOD print(indent)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(mArtNr,mArt) CLASS ArtikelDisponiert
  ::artNr:=mArtNr
  ::art:=mArt
RETURN self

METHOD print(indent) CLASS ArtikelDisponiert
  default indent:=0

  qout(::className())
  qout("artNr                 :",::artNr)
  qout("art                   :",::art)
  qout("menge                 :",::menge )
  qout("Einheit               :",::Einheit)
  qout("Text                  :",::Text )
  qout("Tiefe                 :",::Tiefe)
  qout("lageBest              :",::lageBest )
  qout("disponiert            :",::disponiert )
  qout("fehlMenge             :",::fehlMenge )
  qout("BestText              :",::BestText )
  qout("AlternativeZu         :",::AlternZu )
  qout("topFaktor             :",::topFaktor )
  qout("AbPostNr              :",::AbPostNr)
  qout("MatArtNr              :",::MatArtNr)
  qout("MatFaktor             :",::MatFaktor)
  qout(replicate("-",20))

RETURN self

/************************************************************************************/
/* end of Class ArtikelDisponiert
/************************************************************************************/


/************************************************************************************
 * Class ZeitStueckListe
 ************************************************************************************/
CLASS ZeitStueckListe INHERIT StueckListe

DATA HauptKZ
DATA Automat
DATA Nutzen1
DATA Nutzen2
DATA RuestZeit
DATA SollMenge
DATA maschGr

METHOD getMaschNr()
ENDCLASS

/*----------------------------------------------------------------------*/

METHOD getMaschNr() CLASS ZeitStueckListe
return trim(::artNr)

/************************************************************************************/
/* end of Class ZeitStueckListe
/************************************************************************************/


/* Modul Material.prg 
*
* Alles zur Material-Bedarfsliste (Achse Zeit)
*/
#include "miki.ch"
#include "zeige.ch"

#include "hbclass.ch"

procedure showTodosMatBedarf()
LOCAL StckListen, StckListen_ordered, stkList, topArtNrs:={}, Zeile:=0
LOCAL aktRec, isParent,matKW, parents:=hb_hash(), mArtNr, montage

  cls
  titel("Innerbetr. Auftr�ge lt. Mat.Bedarf erstellen")
  if ! open("TODO", "Artikel","AvPost","Inner","Einheit","BesAus","Aufaus","BesPost")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select TODO
  set rela to TODO->ArtNr into Artikel
  select Artikel
  set rela to ARTIKEL->ME into Einheit
  select TODO

  montage:=Message("Mit Montage-Artikel (@J@/@N@)","JN","N")=="J"
  if ABBRUCH
    close data
    return
  endif

  Drucker("BS")

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )
  aadd( M->specialZeige , { chr(K_RETURN), { |a,b| createInnerAuftrag( a , b )} , "@Return@=inner"+;
    "betr. Auftrag" } )

  Message("Liste wird erstellt.  Bitte warten....")
  index on kwindex(TODO->Fert_KW) + TODO->ARtNr tag TEMP_INDEX TEMPORARY ADDITIVE;
    for TODO->Type==TODO_INNER_AB

  // finde alle parents innerhalb der TODO-Liste
  go top
  do while ! TODO->(eof())
    // if trim(TODO->artnr)$"5015480"
    // altd()
    // endif
    if TODO->Menge < 0 .and. ARTIKEL->Art $ "FD" + iif(montage,"M","")
      StckListen:=getPreviousArtikelStkList(TODO->ArtNr,"DFM", TODO->Menge)
      isParent:=.t.
      aktRec:=TODO->(recno())
      TODO->(OrdSetFocus(1)) // ArtNr
      for each stkList in StckListen
        ARTIKEL->(dbseek(stkList:ArtNr))
        if ARTIKEL->Art $ "FD" + iif(montage,"M","")
          TODO->(dbseek(TODO_INNER_AB+stkList:ArtNr))
          if ! TODO->(eof())
            isParent:=.f.
            exit
          endif
        endif
      next
      TODO->(OrdSetFocus(TEMP_INDEX))
      TODO->(dbgoto(aktRec))

      if isParent
        matKW:=MatBedarfKW():new()
        matKW:ArtNr:=TODO->Artnr
        matKW:FertKW:=TODO->Fert_KW
        matKW:LiefKW:=TODO->Lief_KW
        matKW:children:={}
        parents[TODO->ArtNr]:=matKW
      endif

    endif
    skip
  enddo

  // ordne alle TODOS den parents zu
  go top
  do while ! TODO->(eof())
    @ Maxrow(), 0 say TODO->Fert_KW
    // if trim(TODO->artnr)$"5015480"
    // altd()
    // endif
    if ARTIKEL->Art $ "FMD" .and. ! hb_HHasKey(parents, TODO->ArtNr)
      for each mArtNr in parents:keys
        if StueckListe():new(mArtNr):containsChild(TODO->ArtNr, .t.)
          matKW:=MatBedarfKW():new()
          matKW:ArtNr:=TODO->Artnr
          matKW:FertKW:=TODO->Fert_KW
          matKW:LiefKW:=TODO->Lief_KW
          aadd(parents[mArtNr]:children, matKW)
        endif
      next
    endif
    skip
  enddo

  ?"Art.Nr.     Art  Bezeichnung                       KW    KW         Menge ME  Lagerbest.  "+;
    "Inner.Nr."
  ?"                                                   Lief. Fert."
  ? replicate("-",99)
  _____fixedHeader_____

  StckListen_ordered:=aSort(parents:values ,,,{ |a,b| a:compareKW(b) })

  // drucke alle parents & childs
  TODO->(OrdSetFocus(1)) // ArtNr
  for each stkList in StckListen_ordered
    TODO->(dbseek(TODO_INNER_AB+stkList:ArtNr))
    // if trim(TODO->artnr)$"5015480"
    // altd()
    // endif
    if ARTIKEL->Art $ "FD" + iif(montage,"M","")
      ? ZEIGE_ARTNR+out(TODO->ArtNr),space(1),ARTIKEL->Art,space(1),ARTIKEL->Bez1,space(2),TODO->Lief_KW,;
        TODO->Fert_KW,space(0),str(iif(TODO->Menge<0,TODO->Menge*(-1),0),9), EINHEIT->Text, ;
        ARTIKEL->Lagebest

      // drucke Bestellungen if any
      if ARTIKEL->BestExt<>0.00 .or. ARTIKEL->BestInt<>0.00
        drucke_best(ARTIKEL->ArtNr)
      endif

      drucke_mat_children(parents[stkList:ArtNr])
      ?
    endif
  next

  Drucker("OFF")

  close data
return

static function createInnerAuftrag( a , b )
LOCAL artNr:=left( ltrim(a), len(ARTIKEL->ArtNr)+1 )

  ignore b

  artNr:=deleteString(artNr,".")
  if empty(artnr)
    return .f.
  endif

  TODO->(dbseek(TODO_INNER_AB+ArtNr))
  if TODO->(eof())
    Error(ACHTUNG+"TODO-Eintrag nicht gefunden.")
  else
    setcursor(DEUTE_MARKE)
    Av_Auf_erfass( INNER_TODO )
    setcursor(0)
  endif
return .t.

  /** drucke alle children rekursiv */
static procedure drucke_mat_children(stkList)
LOCAL zeile:=0
LOCAL stkList2, StckListen_ordered

  if stkList:children <> NIL

    StckListen_ordered:=aSort(stkList:children ,,,{ |a,b| a:compareKW(b) })

    // drucke all children
    TODO->(OrdSetFocus(1)) // ArtNr
    for each stkList2 in StckListen_ordered
      TODO->(dbseek(TODO_INNER_AB+stkList2:ArtNr))
      IF TODO->(eof())
        ARTIKEL->(dbseek(stkList2:ArtNr))
      endif
      if ARTIKEL->Art $ "FD"
        ? space(1),ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Art,space(1),ARTIKEL->Bez1,space(2),;
          TODO->Lief_KW, TODO->Fert_KW,space(0),str(iif(TODO->Menge<0,TODO->Menge*(-1),0),9),;
          EINHEIT->Text, ARTIKEL->Lagebest
        // drucke Bestellungen if any
        if ARTIKEL->BestExt<>0.00 .or. ARTIKEL->BestInt<>0.00
          drucke_best(ARTIKEL->ArtNr)
        endif
      endif

      drucke_mat_children(stkList2)
    next
  endif

return


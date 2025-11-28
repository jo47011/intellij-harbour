/* Modul Av.prg
*
* alles zur Arbeitvorbereitung
*/

#include "Miki.ch"
#include "Setcurs.ch"
#include "hbclass.ch"
#include "hbgtinfo.ch"
#include "Getexit.ch"

#define GRAYED_OUT { || if( AUFERFAS->Erledigt=="J" , "N+/"+getBackColor() , NIL) }

/* erfassen von Auftr�gen
*
* Auftrags/Aufrus-Arten:
*  INNER_MIKI -> innerbetr. Auftr�ge ohne ext. AB, also rein Miki
*  INNER_STK  -> nur Artikel/St�cklisten drucken
*  INNER_EDIT -> editieren exist. Auftr�ge, innerArt wird je nach Auswahl gesetzt
*
*
* AUFERFAS->gedruckt und INNER->gedruckt  s. INNER_DRUCK_NEU#miki.ch  etc.
*  " " oder "N" falls noch nicht gedruckt
*  "J"          falls gedruckt
*  "X"          falls bereits gedruckt und nach �nderung in AB noch mal gedruckt werden muss
*  "A"          alter Adel -> man. Reservierung vor der Umstellung (s. update.prg)
*
*/
PROCEDURE Av_Auf_erfass( orgArt , editLfdNr , viewOnly )
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL alterAuftrag:=.f.
LOCAL okay:=.f., result
LOCAL innerArt , merkNr
LOCAL keys:=HB_SetKeySave()

MEMVAR currentOrder
PRIVATE currentOrder
  M->currentOrder:=1

  default viewOnly:=.f.

  cls
  Umgebung(WRITE_ALL)

  if !;
    open( "AvPost" , "Artikel" , "Kunden" ,"Einheit","Text" , "Inner" ,"BesPost","BesAus","AufPost", "Aufaus","Mehrfach","Auftrag","M_Mehrf","System","AvAus")

    Error(TRY_AGAIN)
    Umgebung(LOAD) // anstatt close data
    RETURN
  endif

  // reset all ArtikelInfos
  getoAI( OAI_CLEAR_ALL )

  switch orgArt

    // freie innerbetr. Auftr�ge f�r Miki intern
  case INNER_MIKI
    titel("Interne Auftr�ge (Miki) erfassen")
    if ! open("InnMiki") // -> Alias Auferfas
      Error(TRY_AGAIN)
      Umgebung(LOAD) // anstatt close data
      RETURN
    endif
    zap // Muss immer leer sein, da ansonsten keine Locks auf AB gesetzt, z.B. nach Absturz
    innerArt:=INNER_MIKI
    exit

    // St�ckliste drucken only
  case INNER_STK
    titel("St�cklisten drucken")
    if ! open("InnStk") // -> Alias Auferfas
      Error(TRY_AGAIN)
      Umgebung(LOAD) // anstatt close data
      RETURN
    endif
    zap // Muss immer leer sein, da ansonsten keine Locks auf AB gesetzt, z.B. nach Absturz
    innerArt:=INNER_STK
    exit

    // editieren bereits vorhandener innerbe. Auftr�ge
  case INNER_EDIT
    titel("Interne Auftr�ge �ndern")
    if ! open("InnEdit") // -> Alias Auferfas
      Error(TRY_AGAIN)
      Umgebung(LOAD) // anstatt close data
      RETURN
    endif
    zap // Muss immer leer sein, da ansonsten keine Locks auf AB gesetzt, z.B. nach Absturz

    select Inner
    INNER->(OrdSetFocus(3)) // InlfdNr, Alle, ohne Filter erledigt

    // w�hle Auftrag aus
    if empty(editLfdNr)
      Error(ACHTUNG+"keine Inner.Lfd.Nr. �bergeben."+SCHWERER_FEHLER)
      Umgebung(LOAD) // anstatt close data
      RETURN
    else
      INNER->(dbseek(editLfdNr))
    endif

    // flag merken dass Auftrag bereits existiert
    alterAuftrag:=.t.
    innerArt:=INNER_MIKI

    // kopiere alle aus der gleichen Mappe -> alle Artikel einer evtl. Mehrfachspritzung
    merkNr:=INNER->InnerNr
    INNER->(OrdSetFocus(7)) // InnnerNr, alle nicht erledigten, auch die ungedruckten, alle Arbeitsg�nge
    INNER->(dbseek( merkNr ))
    do while ! INNER->(eof()) .and. INNER->InnerNr == merkNr
      if .not. rec_lock(5,.t.) // inner satz gelocked seit 202141126
        Error(TRY_AGAIN)
        dbunlockall()
        Umgebung(LOAD) // anstatt close data
        RETURN
      endif
      select AufErfas
      add_rec(0)
      overwrite("Inner")
      replace AUFERFAS->KonsCheck with " " // reset Kons.Check Flag on edit
      select Inner
      skip
    enddo

    exit

    // erzeuge innerbetr. Auftrag anhand von aktuellem TODO-Eintrag
  case INNER_TODO
    titel("Interne Auftr�ge erstellen von TODO")
    if ! open("InnEdit") // -> Alias Auferfas
      Error(TRY_AGAIN)
      Umgebung(LOAD) // anstatt close data
      RETURN
    endif
    zap // Muss immer leer sein, da ansonsten keine Locks auf AB gesetzt, z.B. nach Absturz

    innerArt:=INNER_MIKI

    select AufErfas
    add_rec(0)
    //replace AUFERFAS->ArtNr with TODO->ArtNr
    replace AUFERFAS->Fert_KW with TODO->Fert_KW
    replace AUFERFAS->Lief_KW with TODO->Lief_KW
    replace AUFERFAS->Menge with TODO->Menge*(-1)

    keyboard "A" + TODO->ArtNr + chr(K_RETURN)

    exit
  otherwise
    Error(ACHTUNG+"unbekannte orgArt:"+toString(orgArt)+SCHWERER_FEHLER)
    Umgebung(LOAD) // anstatt close data
    RETURN
  endswitch

  INNER->(OrdSetFocus(7)) // InnnerNr, alle nicht erledigten, auch die ungedruckten, alle Arbeitsg�nge

  /* Relationen setzen & temp. Indices erstellen */
  Select Aufpost
  set relation to AUFPOST->AufNr into AufAus, to AUFPOST->ArtNr into Artikel

  select AufAus
  index on AUFAUS->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for AUFAUS->Erledigt <> "J" .and. AUFAUS->AufArt $ "RKBDA"

  Select Artikel
  set relation to ARTIKEL->ME into Einheit

  // kann erst hier gesetzt werden, da auferfas (alias) erst oben ja nach innerart ge�ffnet wird
  select AufErfas
  set relation to AUFERFAS->ArtNr into Artikel // , to AUFERFAS->ArtNr into AvAus


  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_ENDE_Y]:=-6 // N: Anzeige BS von unten
  aKopf[EDIT_INDEX_FELD]:={ || empty(AUFERFAS->ArtNr) }
  aKopf[EDIT_DELETE_FKT]:={ || _FIELD->AUFERFAS->Geloescht:="J" }

  // Werte auf alle Kinder kopieren, evtl. Datens�tze hinzuf�gen
  aKopf[EDIT_AFTER_EDIT_FKT]:={ |result | myAfterEdit(result , aKopf , alterAuftrag ) }

  // wird nach Eingabe des Posten ausgef�hrt
  aKopf[EDIT_EXTRA_FKT]:={}
  switch innerArt
  case INNER_STK
    aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_GESPERRT]:="Z"
    aKopf[EDIT_FKT_IMMER]:={ || Disp_Inner(innerArt) }
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F3)," @F3@=Bem.", { || editInnerBemerkung()}})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=aufl." , { || callMyStkListLind() }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})
    exit
  case INNER_MIKI
  case INNER_EDIT
    aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_NEW_FKT]:={ || _FIELD->AUFERFAS->EtiAnz:=1 , _FIELD->AUFERFAS->EtiAnz2:=1 }
    if viewOnly
      aKopf[EDIT_GESPERRT]:="KN�AELZ"
    elseif alterAuftrag
      aKopf[EDIT_GESPERRT]:="ELNZ" // l = l�schen seit 11.3.2014 wieder enabled
      aadd(aKopf[EDIT_EXTRA_FKT],{ "L"," @L@�schen ", { || KonsistenzLoesch() } } )
      // Hinweis Filter wird unten in der Loop gesetzt
    else
      aKopf[EDIT_GESPERRT]:="ZL"
      aadd(aKopf[EDIT_EXTRA_FKT],{ "L"," @L@�schen ", { || KonsistenzLoesch() } } )
    endif
    aKopf[EDIT_FKT_IMMER]:={;
      || Disp_Inner(innerArt) .and. checkeAVkw(aFelder,aKopf,innerArt,alterAuftrag) }
    aadd(aKopf[EDIT_EXTRA_FKT],{ "D","@D@rucken",{ || exitAndPrint(aKopf)}})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F2),"",{ || toggleReihenfolge(aFelder,aKopf)}})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F3)," @F3@=Bem.", { || editInnerBemerkung()}})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F4)," @F4@=Mappen-Nr", { || assignNextInnerNr(aFelder,aKopf;
      ,.t.) }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=aufl." , { || callMyStkListLind() }})
    aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})

    exit
  endswitch

  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F4),"", { || NegVerfueg(getArtikelArt(),ARTIKEL->ArtNr)};
    })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F5),"", { || showFertDauer(10, AUFERFAS->Menge)} })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F2),"", { || AufBestArtikel(AUFERFAS->ArtNr)} })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F9),"", { || AufBestArtikel(AUFERFAS->ArtNr)} })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F9)," @F9@=ABs", { || ArtAuftragsListe()} })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F10)," @F10@=int.", { || ArtBestellListe()} })
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_CTRL_F10),"", { || getoAI(OAI_GET, AUFERFAS->ArtNr):toQTList(;
    ) } })

  // Artikel-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_AFTER]:={ |oGet| AufArtnrNach(oGet,innerArt) }
  aSpalte[EDIT_FARBE]:=GRAYED_OUT
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.      @F12@=Hilfe"
  aSpalte[EDIT_BS_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinaFelder,aKopfzuf�gen
  aSpalte:=e_fill() // initialisieren

  if innerArt $ INNER_AB + INNER_MIKI
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="if(empty(Reihenfolg),space(5),'('+Reihenfolg+')')"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_FARBE]:={ || "N+/"+getBackColor() }
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  endif

  if innerArt $ INNER_AB + INNER_MIKI
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="if(empty(AUFERFAS->Gruppe),space(11),'Gruppe: '+AUFERFAS->Gruppe)"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_FARBE]:={ || "N+/"+getBackColor() }
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  endif

  // Text
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Bez1"
  aSpalte[EDIT_TITEL]:="Bezeichnung"
  aSpalte[EDIT_FARBE]:=GRAYED_OUT
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  // Text
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Bez2"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_FARBE]:=GRAYED_OUT
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  if innerArt==INNER_MIKI
    // AufNr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="AufNr"
    aSpalte[EDIT_TITEL]:="Auf.Nr."
    aSpalte[EDIT_MASKE]:="@K"
    Aspalte[EDIT_BEFORE]:={ |oGet| aufNrVor(oGet) }
    aSpalte[EDIT_AFTER]:={ |oGet| aufNrNach( oGet ) }
    aSpalte[EDIT_MESSAGE]:="AB-Nummer eingeben (optional)  @F8@=kopieren   @F12@=Hilfe"
    aSpalte[EDIT_BS_AUSGABE]:=.t.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Grund
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="Grund"
    aSpalte[EDIT_BEFORE]:={ || empty(AUFERFAS->AufNr) .and. ;
      mySetKey( K_F8 , {|p1,oGet| copyLastGrund(p1,oGet) })}
    aSpalte[EDIT_AFTER]:={ |oGet| grundNach(oGet) }
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_MESSAGE]:="Grund eingeben (optional)    @F8@=kopieren   @F12@=Auswahl  @F12@=Hilfe"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  endif

  // Menge f�r MIKI
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_TITEL]:="Menge/Rest"
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_MASKE]:="99999.99" // max 5 Stell eingeben!
  aSpalte[EDIT_BEFORE]:={ || AUFERFAS->Erledigt<>"J" }
  aSpalte[EDIT_FARBE]:=;
    { || if(AUFERFAS->Menge>0 .and. AUFERFAS->Menge<ARTIKEL->MinOrdInt,"R/"+getBackColor(),NIL)}
  aSpalte[EDIT_MESSAGE]:="Gesamt Fertigungs-Menge eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| InnerMengeNach(oGet) }
  aSpalte[EDIT_BS_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte))    // neues Feld hinzuf�gen*/*/*/

  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="AUFERFAS->Menge-AUFERFAS->GeliefGes"
  aSpalte[EDIT_MASKE]:="99999.99" // max 5 Stell eingeben!
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_FARBE]:=;
    { || if(AUFERFAS->GeliefGes>0,NIL,"W/W")} // nur anzeigen falls bereits gel.
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte))    // neues Feld hinzuf�gen*/*/*/

  // Einheit
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen aSpalte:=e_fill() // initialisieren

  if innerArt $ INNER_AB + INNER_MIKI
    // Kalenderwoche Liefertermin
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="Lief_Kw"
    aSpalte[EDIT_TITEL]:="Lief."
    aSpalte[EDIT_MASKE]:="99/99"
    aSpalte[EDIT_AFTER]:={ |oGet| LiefkwNach(oGet, innerArt==INNER_MIKI ,alterAuftrag) }
    aSpalte[EDIT_BEFORE]:={ || empty(AUFERFAS->AufNr) .or. left(AUFERFAS->Lief_kw,1)=="X" }
    aSpalte[EDIT_FARBE]:={ || if(! kwempty(AUFERFAS->Lief_kw).and. ;
      kwKleiner(AUFERFAS->Lief_kw,getCurrentKW())>=0,"R/"+getBackColor(),NIL)}
    aSpalte[EDIT_MESSAGE]:="Kalenderwoche Lieferung eingeben."
    aSpalte[EDIT_AUSGABE]:=.t.
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen


    // Kalenderwoche Fertigungstermin
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="Fert_Kw"
    aSpalte[EDIT_TITEL]:="KW"
    aSpalte[EDIT_MASKE]:="99/99"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_AFTER]:={ |oGet| FertkwNach(oGet,alterAuftrag) }
    aSpalte[EDIT_FARBE]:={ || if(! kwempty(AUFERFAS->Fert_kw).and. ;
      (kwKleiner(AUFERFAS->Fert_kw,getCurrentKW())>=0 .or. ;
      (! empty(AUFERFAS->Lief_kw) .and. kwKleiner(AUFERFAS->Fert_kw,AUFERFAS->Lief_kw)<0)),;
      "R/"+getBackColor(),NIL)}

    aSpalte[EDIT_MESSAGE]:="Kalenderwoche Fertigung eingeben."
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Mappe / InnerNr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="InnerNr"
    aSpalte[EDIT_TITEL]:="Mappe"
    aSpalte[EDIT_EDIT]:=.f.
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Mappe / InnerNr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="EtiAnz"
    aSpalte[EDIT_TITEL]:="Eti."
    aSpalte[EDIT_MESSAGE]:="Anzahl Etiketten @Tafel@ (mit Ausdruck Fertigungsdauer) eingeben."
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Mappe / InnerNr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="EtiAnz2"
    aSpalte[EDIT_POS_Y]:=1
    aSpalte[EDIT_MESSAGE]:="Anzahl Etiketten @Stechkarte@ (ohne Ausdruck Fertigungsdauer) eingeben."
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  endif

  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="getInfoDummyField()"
  if innerArt == INNER_MIKI
    aSpalte[EDIT_POS_X]:=-60
    aSpalte[EDIT_POS_Y]:=3
  else
    aSpalte[EDIT_POS_X]:=-60
    aSpalte[EDIT_POS_Y]:=2
  endif
  aSpalte[EDIT_FARBE]:=GRAYED_OUT
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  /**** ENDE Feld-Definitionen ***/

  go top
  do while ! okay

    //if (innerArt $ INNER_EDIT + INNER_MIKI .and. alterAuftrag) .or. innerArt $ INNER_STK
    if innerArt $ INNER_EDIT + INNER_MIKI + INNER_STK
      // neu: filter auf ungel�schte Posten
      set filter to AUFERFAS->geloescht$"N "
    endif

    /* editiere Datei */
    Edit(aFelder,aKopf)

    if viewOnly
      Umgebung(DISMISS_NEXT) // l�sche aktuelle Umgebung, sonst wird der BS gel�scht
      HB_SetKeySave(keys) // restore hot keys
      return
    endif

    go top
    if AUFERFAS->(reccount())==0 .or. empty(AUFERFAS->ArtNr)
      okay:=.t. // fertig
    else
      loca for ! empty( AUFERFAS->ArtNr ) .and. AUFERFAS->Menge > 0
      if AUFERFAS->(eof()) .or. (alterAuftrag .and. ! aKopf[EDIT_CHANGED])
        okay:=.t.
        select Auferfas
        zap
      else
        // buchen & drucken

        if innerArt <> INNER_STK // Ausnahme bei St�ckliste drucken, 20190916
          AUFERFAS->(DbClearFilter()) // kann bei InnerEdit mit Markierung geloescht vorkommen, FIXME: wieso???
        endif

        // Info: korrekte Auferfas Datei (Alias) ist bereits ge�ffnet und somit in Av_Druck korrekt
        result:=avDruckAuswahl(.f.,innerArt,alterAuftrag,,orgArt==INNER_STK)
        switch result
        case DIALOG_OKAY
          okay:=.t.
          if alterAuftrag
            select Auferfas
            zap
          endif
          exit
        case DIALOG_QUIT
          // Alles verwerfen
          select Auferfas
          zap
          aKopf[EDIT_CHANGED]:=.f.
          okay:=.t.
          exit
        case DIALOG_CANCEL
        case DIALOG_ESCAPE
          // NOP -> zur�ck auf los
          exit
        endswitch

      endif
    endif
  enddo

  Umgebung(LOAD) // anstatt close data

  // release all locked ABs and inner items
  dbunlockall()

  // reset all ArtikelInfos
  getoAI( OAI_CLEAR_ALL )

  // ARTIKEL->Disponiert neu berechnen
  if aKopf[EDIT_CHANGED] .and. innerArt $ INNER_AB + INNER_MIKI
    AufBestand()
  endif

  HB_SetKeySave(keys) // restore hot keys
RETURN
/* EOF */


/** kopiert den letzten nicht leeren Grund aus vorherigem S�tzen */
static function copyLastGrund(p1,oGet)
LOCAL aktRec:=recno(),merkGrund
  ignore p1

  do while ! bof() .and. ( empty(AUFERFAS->Grund) .or. aktRec==recno())
    skip -1
  enddo

  merkGrund:=AUFERFAS->Grund
  go (aktRec)
  if ! empty(merkGrund)
    oGet:varput(merkGrund)
    oGet:updateBuffer()
  endif
return .t.
/** eof */

/** kopiert die letzte nicht leere AB-Nr aus vorherigem S�tzen */
static function copyLastAufNr(p1,oGet)
LOCAL aktRec:=recno(),merkAufNr
  ignore p1

  do while ! bof() .and. ( empty(AUFERFAS->AufNr) .or. aktRec==recno())
    skip -1
  enddo

  merkAufNr:=AUFERFAS->AufNr
  go (aktRec)
  if ! empty(merkAufNr)
    oGet:varput(merkAufNr)
    oGet:updateBuffer()
  endif
return .t.
/** eof */


/** falls ein Oberartikel eine Dienstleistung ist liefert die Funktion
  * die Dauer f�r alle Folgeartikel zur�ck
  */
function getDauerNextArtikel(MArtNr, mMenge)
LOCAL result:=0, dlArtNr, dlArtNrs
LOCAL AktRec:=ARTIKEL->(recno())
  dlArtNrs:=getPreviousArtikelStkList( mArtNr,,mMenge )
  for each dlArtNr in dlArtNrs
    ARTIKEL->(dbseek( dlArtNr:ArtNr ))
    if getArtikelArt() <> "M"
      result += getGesFertDauer(ARTIKEL->Artnr, mMenge)
    endif
  next
  ARTIKEL->(dbgoto( aktRec ))
return result
/** eof */

/** Liefert die zugeh. Artikel, die den �bergebenen Artikel enth�lt -> Gegenteil zu getNextArtikel()
  *
  * liefert ein Array mit allen Art.Nr. der Folge-Dienstleistungen und Artikeln,
  * je nach Art, ansonsten {}
  * 
  */
FUNCTION getPreviousArtikelStkList(ArtNr, art, menge)
LOCAL stklist
LOCAL result
  default art:="DFM" // Dienstleistungen und Fertigungsartikel als Default
  default menge:=1
  stklist:=StueckListe():new(Artnr,, Menge)
  result:=stklist:getPreviousArtikel(art, menge) // rekursiv
Return result
/** eof */

/** Liefert die zugeh. Artikel, die der Artikel enth�lt -> Gegenteil zu getPreviousArtikelStkList()
  *
  * liefert ein Array mit allen Art.Nr. der Folge-Dienstleistungen und Artikeln,
  * je nach Art, ansonsten {}
  * 
  */
FUNCTION getNextArtikelStkList(ArtNr, art, menge)
LOCAL stklist
LOCAL result
  default art:="DF" // Dienstleistungen und Fertigungsartikel als Default
  stklist:=StueckListe():new(Artnr,, Menge)
  result:=stklist:getNextArtikel(art, menge) // rekursiv
Return result
/** eof */


  /** berechnet die Fertigungsdauer f�r einen Artikel
  *
  * Summe der Zeit & R�stzeit aller HauptMaschinen, Ergebnis in Stunden
  */
function getGesFertDauer(MArtNr,Anzahl)
LOCAL summe:=0
LOCAL merkOrd:=AVPOST->(indexOrd())
LOCAL aktSel:=alias()
LOCAL aktRec:=ARTIKEL->(recno())

  // ohne Menge keine Dauer ;)
  if Anzahl==0
    return 0
  endif

  // Dienstleistingsdauer aus Artikel-Stamm
  ARTIKEL->(dbseek( mArtNr ))
  if ARTIKEL->Art=="D" // Dienstleistung min. 1 Woche Vorlauf
    summe:=ARBEITS_TAGE * ARBEITS_STUNDEN * max(ARTIKEL->DLWochen, 1)
  else
    summe:=ARBEITS_TAGE * ARBEITS_STUNDEN * ARTIKEL->DLWochen
  endif
  if getArtikelArt() <> "D"
    // normaler Artikel, hole Zeiten aus St�ckliste
    AVPOST->(OrdSetFocus(1)) // AVNr+Art
    SELECT AvPost
    SEEK MArtNr+"V"
    do while .not. AVPOST->(eof()) .and. AVPOST->AvNr=MArtNr .and. AVPOST->Art="V"
      if AVPOST->Text=="A" .and. AVPOST->HauptKZ=="H" // HauptMaschinen
        // Fertigungs-Zeit
        if AVPOST->Menge <> 0.00
          summe+=round(Anzahl/AVPOST->Menge,2)
        endif

        // R�stzeit?
        if AVPOST->RuestZeit>0
          summe += AVPOST->RuestZeit
        endif

      endif
      skip
    enddo
    select (aktSel)
    AVPOST->(OrdSetFocus(merkOrd))
  endif
  ARTIKEL->(dbgoto( aktRec ))

return summe
/** eof */

// /** berechnet die R�stzeit f�r einen Artikel
// *
// * Summe der R�stzeit aller HauptMaschinen, Ergebnis in Stunden
// */
  // function getGesRuestDauer(MArtNr)
  // LOCAL summe:=0
  // LOCAL merkOrd:=AVPOST->(indexOrd())
  // LOCAL aktSel:=alias()

  // AVPOST->(OrdSetFocus(1)) // AVNr+Art
  // SELECT AvPost
  // SEEK MArtNr+"V"
  // do while .not. AVPOST->(eof()) .and. AVPOST->AvNr=MArtNr .and. AVPOST->Art="V"
  // if AVPOST->Text=="A" .and. AVPOST->HauptKZ=="H" // HauptMaschinen

  // // R�stzeit?
  // if AVPOST->RuestZeit>0
  // summe += AVPOST->RuestZeit
  // endif

  // endif
  // skip
  // enddo
  // select (aktSel)
  // AVPOST->(OrdSetFocus(merkOrd))

  // return summe
// /** eof */


/* wird nach Eingabe der Artikel-Nr. ausgef�hrt */
static FUNCTION AufArtNrNach(oGet,innerArt)
LOCAL merkOrd:=AVPOST->(indexOrd())

  if ! check(oGet,"Artikel",.f.,.f.) .or. lastkey() == K_UP
    return .f.
  endif

  if ! getArtikelArt() $ "FMD"
    Error(ACHTUNG+oget:buffer+" ist kein Fertigungs- oder Montageartikel.|"+;
      "        Kein innerbetr. Auftrag m�glich.",.t.)
    return .f.
  endif
  if left(ARTIKEL->ArtNr,1) == "E"
    Error(ACHTUNG+oget:buffer+" ist Ersatzteilliste.|"+;
      "        Kein innerbetr. Auftrag m�glich.",.t.)
    return .f.
  endif
  if oGet:changed()
    // pr�fe ob vorher Mehrfachspritzung, dann �ndern der Art.Nr verbieten
    if ! empty(AUFERFAS->Werkzeug)
      Error(ACHTUNG+"Mehrfachspritzguss-Artikel kann nicht ge�ndert werden.||"+;
        "         Falls notwendig: Zeile bitte l�schen.",.t.)
      return .f.
    endif

    // pr�fe ob Artikel eine Zeit-St�ckliste hat.
    AVPOST->(OrdSetFocus(1)) // AVNr+Art
    AVPOST->(dbseek(oGet:buffer+"V"))
    if AVPOST->(eof()) .and. innerArt <> INNER_STK
      Error(ACHTUNG+oget:buffer+" hat keine Zeit/Maschinen St�ckliste.||"+;
        "         Bitte zu erst anlegen.")
      AVPOST->(OrdSetFocus(merkOrd))
      return .f.
    endif
    AVPOST->(OrdSetFocus(merkOrd))

    oGet:assign()

    dbskip(0)

    replace AUFERFAS->Bez1 with ARTIKEL->Bez1
    replace AUFERFAS->Bez2 with ARTIKEL->Bez2
    replace AUFERFAS->Art with getArtikelArt()
    replace AUFERFAS->Reihenfolg with ARTIKEL->Reihenfolg
    replace AUFERFAS->Fert_Offs with WOCHEN_OFFSET
    if empty(AUFERFAS->InLfdNr)
      replace AUFERFAS->InLfdNr with hole("InlfdNr",WRITE,.t.)
    endif

    // l�sche alles bezgl. evtl. hinterlegter AB 20190306
    if AUFERFAS->AbPostnr > 0
      replace AUFERFAS->AufNr with ""
      replace AUFERFAS->AbPostnr with 0
      replace AUFERFAS->Grund with AUFAUS->Kurzname
    endif

    // setze Menge auf 1 bei St�cklistendruck
    if innerArt == INNER_STK .and. AUFERFAS->Menge == 0
      replace AUFERFAS->Menge with 1
    endif

    // setze Mappen-Nr, if applicable
    if empty(AUFERFAS->InnerNr)
      if ! assignNextInnerNr()
        return .f.
      endif
    endif

  endif

  /* anzeige bisherige Auftr�ge */
  disp_inner(innerArt)
RETURN(.t.)
/* EOF Auf_ArtNr_nach */




/** liefert die n�chste freie innerbetr. Nummer zur�ck */
static function assignNextInnerNr(aFelder,aKopf,confirm)
LOCAL oldNr , prodNr, addedRecords:=.f.

  // nur falls g�ltiger Datensatz selektiert
  // keine Nr. f�r Dienstleistungen oder 0-Menge
  // fast INNER_IGNORE_POSTEN hier ;)
  if AUFERFAS->Art=="D" .or. ;
    (! empty(AUFERFAS->AufNr) .and. AUFERFAS->Menge==0)
    // NOP
    return .t.
  endif

  if confirm<>NIL .and. confirm
    if ! AUFERFAS->gedruckt $ INNER_DRUCK_NEU + INNER_DRUCK_LEER
      Error(ACHTUNG+"Auftrag ist bereits gedruckt.  ||"+;
        "         Mappen-Nr. kann ge�ndert werden.|"+;
        "         Bitte Mappe: "+AUFERFAS->InnerNr+" �berpr�fen.")
      return .t.
    endif

    if Message("Neue innerbetr. Mappe zuweisen? (@J@/@N@)","JN"," ")<>"J"
      return .f.
    endif
  endif

  prodNr:=getNextInnerNr()

  if prodNr == NIL
    return .f.
  endif

  select AufErfas
  oldNr:=AUFERFAS->InnerNr
  replace AUFERFAS->InnerNr with prodNr

  // kopiere �nderungen auf andere Artikel des Werkzeugs
  if ! empty(AUFERFAS->Werkzeug)
    // alle Artikel des Werkzeugs in die gleiche Mappe
    addedRecords:=copyMehrfach( oldNr , AUFERFAS->InnerNr )
  endif

  // kopiere �nderungen auf andere Arbeitsg�nge
  if ! empty(AUFERFAS->ArbGang)

    // kopiere alle Arbeitsg�nge in die gleiche Mappe
    addedRecords:=copyArbeitsGang() .or. addedRecords

    // addDienstleistung()
  endif

  // Hinweis: hier keine konkrete Spalte gegeben
  if addedRecords .and. aFelder<>NIL .and. aKopf<>NIL
    PageOut(aFelder,aKopf)
  endif

return .t.
/** eof */


/* Function GrundNach()
*
* wird nach Eingabe des Grundes ausgef�hrt
*/
static FUNCTION GrundNach(oGet)

  if lastkey()<>K_UP .and. empty(AUFERFAS->AufNr) .and. empty(oGet:Buffer)
    Error(ACHTUNG+"AB-Nr. oder Grund m�ssen eingegeben werden.")
    return .f.
  endif

  if ! empty( oGet:buffer) .and. emptyOr2Simple(oGet:Buffer,5)
    Error(ACHTUNG+"Bitte korrekten Grund eingeben.  Mind. 5 Zeichen.  F12=Auswahl")
    return .f.
  endif

  // Bingo
  mySetKey( K_F8 , NIL )

return .t.

/*
* wird nach Eingabe des AufNr ausgef�hrt
*/
static FUNCTION AufNrNach(oGet)
LOCAL resultKW , count, aktRec
LOCAL merkKw, merkAbPostNr, merkArtnr

  // empty is okay
  if empty(oGet:Buffer)
    replace AUFERFAS->AbPostNr with 0
    mySetKey( K_F8 , NIL )
    set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
    set key HILFE_TASTE2 to Hilfe
    return .t.
  endif

  if oGet:changed

    if ! check(oGet,"AufAus",.f.,.f.)
      return .f.
    endif

    if AUFAUS->Erledigt=="J" // sollte nie passieren, da for clause
      Error(ACHTUNG+"Auftrag ist bereits ereldigt.")
      return .f.
    endif

    aktRec:=AUFAUS->(recno()) // geht in Umgebung schief, da Aufpost rela gesetzt ist

    // pr�fe ob Artikel direkt in AB vorkommt -> �bernehme Menge und KW
    Umgebung( WRITE_ALL )
    AUFPOST->(OrdSetFocus(3)) // AufNr + ArtNr
    AUFPOST->(dbseek( oGet:buffer + AUFERFAS->ArtNr ))
    if ! AUFPOST->(eof())
      select Aufpost
      skip

      // kommt Artikel mehrfach in AB vor? -> manuelle Auswahl
      if oGet:buffer == AUFPOST->AufNr .and. AUFERFAS->ArtNr == AUFPOST->ArtNr
        Hilfe("AV,AUFTRAG MIT FILTER | TOPLEVEL",getnew(),"")
        if ABBRUCH .or. lastkey()==HILFE_TASTE1 .or. lastkey()==HILFE_TASTE2
          Umgebung( LOAD )
          return .f.
        endif
      else
        // zur�ck auf den 1. und einzigen Treffer
        AUFPOST->(dbseek( oGet:buffer + AUFERFAS->ArtNr ))
      endif
      replace AUFERFAS->AbPostNr with AUFPOST->AbPostNr
      replace AUFERFAS->Menge with AUFPOST->Menge - AUFPOST->GeliefGes
      replace AUFERFAS->Lief_KW with AUFPOST->KW

      // berechne top level Fert.KW (immer!)
      replace AUFERFAS->FertDauer with getGesFertDauer(AUFERFAS->ArtNr,AUFERFAS->Menge)
      resultKW:=calcKW(AUFERFAS->Lief_KW , AUFERFAS->Fert_offs +;
        getDauerNextArtikel(AUFERFAS->ArtNr, AUFERFAS->Menge) * (-1), AUFERFAS->FertDauer*(-1) ,;
        SYSTEM->Holidays)
      replace AUFERFAS->Fert_KW with resultKW

    else // pr�fe ob Artikel als Unterartikel vorkommt

      AUFPOST->(dbseek( oGet:buffer ))
      count:=0
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr == oGet:buffer
        if StueckListe():new( AUFPOST->ArtNr ):containsChild( AUFERFAS->ArtNr , .t. )
          // gefunden
          count++
          merkKw:=AUFPOST->Kw
          merkAbPostNr:=AUFPOST->AbPostNr
          merkArtNr:=AUFPOST->ArtNr
        endif
        select Aufpost
        skip
      enddo

      // kommt Artikel mehrfach in AB vor? -> manuelle Auswahl
      if count > 1
        // gehe wieder auf 1. Treffer, wegen Filter in Hilfdef
        AUFPOST->(dbseek( oGet:buffer ))
        Hilfe("AV,AUFTRAG MIT FILTER | REKURSIV",getnew(),"")
        if ABBRUCH .or. lastkey()==HILFE_TASTE1 .or. lastkey()==HILFE_TASTE2
          Umgebung( LOAD )
          return .f.
        endif
        merkAbPostNr:=AUFPOST->AbPostNr
        merkArtNr:=AUFPOST->ArtNr
        merkKw:=AUFPOST->Kw
      endif

      // eindeutigen AB-Posten gefunden
      if count > 0
        if isPhoenixOberArtikel( merkArtnr )
          AUFPOST->(OrdSetFocus(5))
          AUFPOST->(dbseek( merkAbPostNr ))
          ARTIKEL->(dbseek( merkArtNr ))
          replace AUFERFAS->Menge with (AUFPOST->Menge - AUFPOST->GeliefGes) * ARTIKEL->Inhalt
        endif

        replace AUFERFAS->Lief_KW with merkKW
        // berechne top level Fert.KW (immer!)
        replace AUFERFAS->FertDauer with getGesFertDauer(AUFERFAS->ArtNr,AUFERFAS->Menge)
        resultKW:=calcKW(AUFERFAS->Lief_KW, AUFERFAS->Fert_offs +;
          getDauerNextArtikel(AUFERFAS->ArtNr, AUFERFAS->Menge) * (-1), AUFERFAS->FertDauer*(-1) ,;
          SYSTEM->Holidays)
        replace AUFERFAS->Fert_KW with resultKW
        replace AUFERFAS->AbPostNr with merkAbPostNr

      else // nicht gefunden!!!
        Error(ACHTUNG+"Artikel ist nicht in Auftrag enthalten.||"+;
          "         Bitte andere AB.Nr. oder leer eingeben")
        Umgebung( LOAD )
        mySetKey( K_F8 , NIL )
        set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
        set key HILFE_TASTE2 to Hilfe
        return .f.
      endif

    endif
    Umgebung( LOAD )
    AUFAUS->(dbgoto( aktRec ))

    replace AUFERFAS->Grund with AUFAUS->Kurzname

  endif

  mySetKey( K_F8 , NIL )
  set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
  set key HILFE_TASTE2 to Hilfe
return .t.

  /**
  * sucht aktuellen Auftragsposten in innerbetrt. Auftr�gen und passt evtl. die KW an
  */
procedure updateInnerKW()
LOCAL resultKW, innerNrs:={}
LOCAL minKw, nr, innerAnzeige, line

  if "*" $ AUFAUS->AufNr .or. AUFTRAG->AbPostNr==0 // neue AB -> bail out
    return
  endif

  // jetzt AbPostNr seit 15.12.23
  // Hinweis: m�ssen Nr aus Aufaus nehmen, da bei neuen AB Posten noch nicht gesetzt
  //mAufNr:=AUFAUS->AufNr

  Umgebung( WRITE_ALL )

  select Inner
  INNER->(OrdSetFocus(5)) // INNER->AbPostNr
  INNER->(dbseek( str(AUFTRAG->AbPostnr,8) ))
  if ! INNER->(eof())

    do while ! INNER->(eof()) .and. AUFTRAG->AbPostNr == INNER->AbPostNr

      minKw:=AUFTRAG->KW

      // raus 15.12.23
      // if AUFTRAG->AbPostNr > 0 .and. AUFTRAG->AbPostNr == INNER->AbPostNr
      // minKw:=AUFTRAG->KW
      // elseif AUFTRAG->ArtNr == INNER->ArtNr
      // // 21.10.14 raus, da ansonsten bei neuen Satz erfassen in ext. AB
      // // alle innerbetr. Auftr�ge des Artikels aktualisiert werden
      // // minKw:=AUFTRAG->KW
      // else

      // // pr�fe ob Artikel mehrfach in AB als Unterartikel vorkommt
      // select Auftrag
      // aktRec:=AUFTRAG->(recno())

      // // gehe auf 1. Posten in AB
      // AUFTRAG->(dbgotop())

      // do while ! AUFTRAG->(eof())
      // if AUFTRAG->Geloescht <> "J"
      // if StueckListe():new( AUFTRAG->ArtNr ):containsChild( INNER->ArtNr , .t. )
      // // gefunden
      // minKw:=kwMin( minKw , AUFTRAG->KW )
      // endif
      // select Auftrag
      // endif
      // skip
      // enddo
      // AUFTRAG->(dbgoto( aktRec ))
      // endif

      if minKw <> NIL .and. INNER->Lief_KW <> minKw
        select Inner
        if rec_lock(5)
          replace INNER->Lief_KW with minKW

          resultKW:=calcKW(INNER->Lief_KW , INNER->Fert_offs +;
            getDauerNextArtikel(INNER->ArtNr, INNER->Menge) * (-1), INNER->FertDauer*(-1) ,;
            SYSTEM->Holidays)
          replace INNER->Fert_KW with resultKW
          dbcommit()
          dbunlock()

          aaddUnique(innerNrs, INNER->InnerNr)
        else
          Error(ACHTUNG+"Innerbetr. Auftrag: "+ INNER->InnerNr + " konnte nicht aktualisiert werden.||" +;
            "         AB: "+AUFAUS->AufNr+" Posten: "+str(AUFTRAG->AbPostNr)+;
            SCHWERER_FEHLER)
        endif
      endif

      select Inner
      skip
    enddo

    if len( innerNrs ) > 0
      innerAnzeige:=""
      for each line in linewrap(array2readable(innerNrs),50)
        innerAnzeige += line+"|"
      next
      Error("Folgende innerbetr. Auftr�ge wurden aktualisiert: ||"+ innerAnzeige + ;
        "||Bitte evtl. an der Tafel anpassen.",ERR_NO_WAIT)
      if Message("Etiketten ausdrucken? (@J@/@N@)","JN"," ")=="J"
        select Inner
        INNER->(OrdSetFocus(7)) // InnnerNr, alle nicht erledigten, auch die ungedruckten, alle Arbeitsg�nge
        for each nr in innerNrs
          INNER->(dbseek( nr ))
          if INNER->(eof())
            troubleEmail("Inner-Nr nicht gefunden: " + nr)
          else
            InnerDruck("E") // Etikett drucken
          endif
        next
      endif
    endif
  endif

  Umgebung( LOAD )

return
/** eop */


/* Function InnerMengeNach()
*
* wird nach Eingabe der Menge ausgef�hrt
*/
static FUNCTION InnerMengeNach(oGet)
LOCAL fehlMenge,s01 , resultKW

  if lastkey()==K_UP
    return .t.
  endif

  if oGet:VarGet()<0
    Error(ACHTUNG+"Menge darf nicht negativ sein.||"+;
      "Zum �ndern von innnerbetr. Auftr�gen bitte anderen Men�-Punkt verwenden.")
    return .f.
  endif

  if ARTIKEL->MinOrdInt>0 .and. oGet:VarGet() < ARTIKEL->MinOrdInt
    fehlMenge:=ARTIKEL->MinOrdInt-oGet:VarGet()
    s01:=savescreen()
    Error(ACHTUNG+"Artikel: "+ARTIKEL->ArtNr+" Mind.Bestellung: "+str(ARTIKEL->MinOrdInt,9,2)+;
      " "+EINHEIT->Text+"||"+;
      "         Fehlende Anzahl:"+str(fehlMenge,9,2),.f. )
    if Message("Auf Mindest-Menge aufstocken? (@J@/@N@)","JN","J")=="J"
      oget:varput(ARTIKEL->MinOrdInt)
      oGet:updateBuffer()
    endif
    restscreen(,,,,s01)
    if ABBRUCH
      return .f.
    endif
  endif

  // Fert. KW anpassen, if applicable
  if oGet:changed
    // berechne top level Fert.KW
    replace AUFERFAS->FertDauer with getGesFertDauer(AUFERFAS->ArtNr,AUFERFAS->Menge)
    if ! empty( AUFERFAS->Lief_KW )
      resultKW:=calcKW(AUFERFAS->Lief_KW , AUFERFAS->Fert_offs +;
        getDauerNextArtikel(AUFERFAS->ArtNr, AUFERFAS->Menge) * (-1), AUFERFAS->FertDauer*(-1) ,;
        SYSTEM->Holidays)
      replace AUFERFAS->Fert_KW with resultKW
    endif
  endif

RETURN(.t.)
/* EOF InnerMengeNach */


/** gibt die GesamtMenge und die Einheit am BS zur�ck, und Nutzen falls <> 1/1 */
function getInfoDummyField()
LOCAL result:="" , zeit

  // Nutzen
  if AUFERFAS->nutzen1>1 .or. AUFERFAS->nutzen2>1
    result += " Nutzen: "+alltrim(str(AUFERFAS->nutzen1,2))+"/"+alltrim(str(AUFERFAS->nutzen2,2))
  endif

  // Dienstleistungs?
  if AUFERFAS->Art=="D"
    result += " DL: "
  endif

  // Fertigungs-Dauer
  if ! empty(AUFERFAS->ArtNr)
    zeit:=getStdTagText(AUFERFAS->FertDauer)
    if ! empty(zeit)
      result += " Zeit: " + zeit
    endif
  endif

  // Arbeitsgang
  if ! empty(AUFERFAS->ArbGang)
    result += " Arbeitsgang " + AUFERFAS->ArbGang + " ("+AUFERFAS->MaschNr+")"
  endif

return left(ltrim(result)+space(65),65)
/** eof */


/* Function AV_kw_nach
*
* wird nach Eingabe der Kalenderwoche ausgef�hrt
*
*  �berpr�ft ob die KW zw. 01-53 liegt oder aus LiefTerm �bernommen ist,
*  leer ist nicht zugelassen
*/
static FUNCTION FertkwNach(oGet, alterAuftrag)
LOCAL resultKW

  if oGet:changed()

    if ! KWokay(oGet:buffer)
      return .f.
    endif

    if lastkey() == K_UP
      return .t.
    endif

    if ! AV_KW_Okay(oGet:buffer,"Fert.KW",,alterAuftrag)
      return .f.
    endif

    // max 1 Jahr in die Zukunft
    if kwDiff(getCurrentKW(),AUFERFAS->Fert_KW) > getNumWeeks() .and. ! DEVEL_PROG
      Error(ACHTUNG+"Lieferzeit darf max. 1 Jahr betragen.")
      return .f.
    endif

    oGet:assign()

    // kalkuliere die Lief-KW vorher, damit bei der Eingabe sichtbar
    if ! kwempty(AUFERFAS->Fert_KW)
      replace AUFERFAS->FertDauer with getGesFertDauer(AUFERFAS->ArtNr,AUFERFAS->Menge)

      // seit 7.10.14 keine �nderung falls AB hinterlegt, da Liefertermin vorgegeben
      // Sonderfall AB hinterlegt, aber Liefertemin ist in Vergangenheit
      if empty( AUFERFAS->AufNr ) .or. ! checkLiefFertKW()

        // Hinweis: rechnet hier ab Montag morgen (Offset==0) hoch
        // vorhandenes Offset in der Woche wird ignoriert
        resultKW:=calcKW(AUFERFAS->Fert_KW , AUFERFAS->Fert_offs +;
          getDauerNextArtikel(AUFERFAS->ArtNr, AUFERFAS->Menge) * (+1), AUFERFAS->FertDauer*(+1),;
          SYSTEM->Holidays)
        replace AUFERFAS->Lief_KW with resultKW
      endif
    endif

  endif

return .t.
/** eof */

  /** pr�ft dass der Liefertermin nach der Fert.KW ist */
static function checkLiefFertKW()
LOCAL result:=.t., s01
  if ! AV_KW_Okay( AUFERFAS->Lief_KW )
    s01:=savescreen()
    Error(ACHTUNG+"Liefertermin liegt in Vergangenheit bzw. vor Fert.KW",.f.)
    result:=Message("Liefertermin neu berechnen? (@J@/@N@)","JN","N")<>"J"
    restscreen(,,,,s01)
  endif
return result
  /** eof */

/* Function LiefkwNach
*
* wird nach Eingabe der Lief.Kalenderwoche ausgef�hrt
*
*  �berpr�ft ob die KW zw. 01-53 liegt oder aus LiefTerm �bernommen ist,
*  leer ist nicht zugelassen
*/
static FUNCTION LiefkwNach(oGet , emptyAllowed , alterAuftrag)
LOCAL result:=AV_KW_Okay( oGet:buffer , NIL , emptyAllowed ,alterAuftrag)
LOCAL resultKW

  default alterAuftrag:=.f.

  if ! KWokay(oGet:buffer)
    return .f.
  endif

  if lastkey()==K_UP
    return .t.
  endif

  if kwEmpty(oGet:buffer)
    return .f.
  endif

  if result .and. (oGet:changed() .or. kwEmpty(AUFERFAS->Fert_KW))
    // max 1 Jahr in die Zukunft
    if kwDiff(getCurrentKW(),AUFERFAS->Lief_KW) > getNumWeeks() .and. ! DEVEL_PROG
      Error(ACHTUNG+"Lieferzeit darf max. 1 Jahr betragen.")
      return .f.
    endif

    // berechne top level Fert.KW (immer!)
    replace AUFERFAS->FertDauer with getGesFertDauer(AUFERFAS->ArtNr,AUFERFAS->Menge)
    resultKW:=calcKW(AUFERFAS->Lief_KW , AUFERFAS->Fert_offs +;
      getDauerNextArtikel(AUFERFAS->ArtNr, AUFERFAS->Menge) * (-1), AUFERFAS->FertDauer*(-1) ,;
      SYSTEM->Holidays)
    replace AUFERFAS->Fert_KW with resultKW
  endif

  // leere Eingabe nicht erlaubt!!!
return result
/** eof */

/** �berpr�ft nach Beendigung des Editos ob g�ltige KW eingegeben */
static Function checkeAVkw(aFelder,aKopf,innerArt,alterAuftrag)
LOCAL result
LOCAL x

  ignore innerArt

  result:= AV_KW_Okay( AUFERFAS->Lief_KW , NIL , /* innerArt == INNER_MIKI */ ,alterAuftrag)

  // // ACHTUNG hier Ausnahme, da kein Lief_KW bei AB-Auftrag nicht editierbar
  // // sonst endlos loop
  // if ! empty(AUFERFAS->Lief_KW)
  // aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  // return .t.
  // endif

  aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld

  // 20180927: wieder raus: Hinweis gen�gt, keine Pflichteingabe mehr, da Liefertermin aus AB �bernommen wird.
  if result // .or. ! empty( AUFERFAS->AufNr )
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  else

    x:=getColPosByName(aFelder,"Lief_Kw")

    if x==0
      troubleEmail("KW nicht gefunden.")
      return .t. // my bug, we allow exit here so user can proceed
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif
    return .f.
  endif

return .t.
/** eof */

/** wird nach Eingabe der Zeile aufgerufen */
static function myAfterEdit(editResult , aKopf , alterAuftrag )
LOCAL is1stTime:=.f., Zeiten

  mySetKey( K_F8 , NIL )
  set key HILFE_TASTE1 to Hilfe // Hilfe-Proc
  set key HILFE_TASTE2 to Hilfe

  if editResult == EDIT_RESULT_UNCHANGED .or. empty(AUFERFAS->ArtNr) .or. chr(lastkey()) $ "lL"
    return .t.
  endif

  // .and. innerArt <> INNER_STK )
  // seit 20190916 bei St�ckliste drucken - l�schen erlaubt

  // zuerst KW etc. eingeb (ist Pflicht)
  if ! eval(aKopf[EDIT_FKT_IMMER])
    return .f.
  endif

  // Mehrere Arbeitsg�nge werden gesondert behandelt
  // pr�fe auf Hauptmaschinen
  zeiten:=StueckListe():new( AUFERFAS->ArtNr ):getZeiten( NIL, "H")

  // Mehrfach-Artikel werden gesondert behandelt
  if isMehrfach()
    // jetzt Werte auf andere Mehrfach-Artikel kopieren
    if copyMehrfach(nil,nil,alterAuftrag,zeiten) .and. aKopf[EDIT_MODUS] == 2
      if alterAuftrag
        HB_KeyPut(EDIT_BS_REFRESH)
      else
        HB_KeyPut(K_ESC)
        HB_KeyPut("N")
      endif
    else
      HB_KeyPut(EDIT_BS_REFRESH)
    endif
  endif

  // kein Mehrfach-Artikel, pr�fe auf mehrere Arbeitsg�nge
  if len(Zeiten) > 1
    // jetzt Werte auf andere Arbeitsg�nge kopieren
    if copyArbeitsGang(Zeiten) .and. aKopf[EDIT_MODUS] == 2
      // addDienstleistung()
      HB_KeyPut(K_ESC)
      HB_KeyPut("N")
    else
      // addDienstleistung()
      HB_KeyPut(EDIT_BS_REFRESH)
    endif
    // else
    // if addDienstleistung()
    // HB_KeyPut(K_ESC)
    // HB_KeyPut("N")
    // endif
  endif


return .t.
/** eof */

/** �berpr�ft nach Eingabe eines Postens ob weitere Posten auf Grund
  * von Mehrfach-Nutzen hinzugef�gt werden sollen.
  */
static Function isMehrfach()
LOCAL mehrf:=NIL, werkzeugGruppen, gruppe:=NIL
LOCAL aktRec:=AUFERFAS->(recno()), altGruppe

  werkzeugGruppen:=Stueckliste():new(AUFERFAS->ArtNr):getWerkzeugGruppen()

  // keine Mehrfachspritzguss-Artikel, also raus
  if len(werkzeugGruppen) == 0
    return .f.
  endif

  // Mehrfachspritzguss-Artikel mit mehreren Gruppen -> w�hle passende Gruppe aus
  if len(werkzeugGruppen) > 1
    do while ABBRUCH .or. Gruppe == NIL .or. mehrf == NIL
      if ! empty(AUFERFAS->Gruppe)
        keyboard trim(AUFERFAS->Gruppe)
      endif
      Hilfe("MEHRFACHSPRITZUNG-GRUPPEN",getnew(),"Blubb")
      gruppe:=MEHRFACH->Gruppe
      mehrf:=Mehrfach():new( AUFERFAS->ArtNr, gruppe )
    enddo
  else
    gruppe:=werkzeugGruppen[1][2]
    mehrf:=Mehrfach():new( AUFERFAS->ArtNr, gruppe )
  endif


  // pr�fe auf Mehrfach-Nutzen
  if mehrf<>NIL .and. mehrf:isMehrfach()
    if empty(AUFERFAS->Werkzeug) .or. AUFERFAS->Gruppe <> mehrf:Gruppe
      if AUFERFAS->Gruppe <> mehrf:Gruppe .and. ! empty(AUFERFAS->Gruppe)
        altGruppe:=AUFERFAS->Gruppe
        repla;
          AUFERFAS->geloescht;
          with "J" for AUFERFAS->Gruppe == altGruppe .and. AUFERFAS->(recno()) <> aktRec
        AUFERFAS->(dbgoto( aktRec ))
      endif
      // Neu oder andere Gruppe gew�hlt
      replace AUFERFAS->Nutzen1 with mehrf:Nutzen1
      replace AUFERFAS->Nutzen2 with mehrf:Nutzen2
      replace AUFERFAS->Werkzeug with mehrf:WkzNr
      replace AUFERFAS->Gruppe with mehrf:Gruppe
    endif
    return .t.
  endif

return .f.
/** eof */

/** kopiert alle Artikel eines Werkzeugs bzw. kopiert die Menge,
*   Grund, Innernutzen etc. bei �nderung auf die anderen Artikel des Werkzeugs
  *
  * Parameter alle optional:
  *     addNewRecords = .t. fehlende Artikel des Werkzeugs/Auftrags werden hinzugef�gt
  *     AufNr - falls <> NIL werden nur Mehrfach-Artikel aus dieser AB kopiert
  *     altMappeNr - die alte Mappen-Nr falls diese ge�ndert wird, damit man andere Artikel findet
  *
  * Returns true if new records have been added
  */
static function copyMehrfach( aktMappeNr , neueMappeNr , alterAuftrag, Zeiten)
LOCAL aktRec
LOCAL mehrf, merkEtiAnz, merkEtiAnz2
LOCAL addedRecords:=.f.

  default aktMappeNr:=AUFERFAS->InnerNr
  default neueMappeNr:=AUFERFAS->InnerNr
  default alterAuftrag:=.f.
  default zeiten:={}

  select AufErfas
  aktRec:=recno()
  AUFERFAS->(OrdSetFocus(0))

  // merke Nutzen & Werkzeug des aktuellen Artikels

  // changed 20180109:
  mehrf:=Mehrfach():new( AUFERFAS->ArtNr, AUFERFAS->Gruppe)
  merkEtiAnz:=AUFERFAS->EtiAnz
  merkEtiAnz2:=AUFERFAS->EtiAnz2

  // �bernehme immer alle Artikel aus Werkzeug
  select MehrFach
  seek mehrf:WkzNr
  do while ! MEHRFACH->(eof()) .and. MEHRFACH->ArtNr==mehrf:WkzNr
    // akt. Datensatz?
    if MEHRFACH->Anr <> AUFERFAS->ArtNr .and. MEHRFACH->Gruppe == mehrf:Gruppe
      if addMehrfach( mehrf, MEHRFACH->Anr , aktMappeNr , neueMappeNr , merkEtiAnz , merkEtiAnz2 ,;
        alterAuftrag )
        addedRecords:=.t.
      endif
    endif
    skip
  enddo

  // jetzt andere Arbeitsg�nge anlegen
  if len(Zeiten) > 1
    select AufErfas
    loca for AUFERFAS->Werkzeug == mehrf:WkzNr
    do while ! AUFERFAS->(eof()) .and. AUFERFAS->Werkzeug==mehrf:WkzNr
      copyArbeitsGang(Zeiten)
      skip
    enddo
    // addDienstleistung()
  endif

  select AufErfas
  go (aktRec)

return addedRecords
/** eof */

/** F�gt einen neuen Mehrfach-Artikel hinzu bzw. updated diesen.
  *
  * Returns true if new records have been added
  */
static;
  function;
  addMehrfach( mehrf, mArtNr , aktMappeNr , neueMappeNr , mEtiAnz , mEtiAnz2 , alterAuftrag)
LOCAL aDateiFelder , mehrf2
LOCAL aktRec:=AUFERFAS->(recno())
LOCAL aktSel:=alias()
LOCAL merkFilter:=AUFERFAS->(dbfilter())
LOCAL result:=.f.

  // merke aktuelle Werte des Artikel aus Auferfas
  select Auferfas
  aDateiFelder:=getCurrentValues()

  AUFERFAS->(DbClearFilter()) // FIXME: 20200925: why?

  // suche ob anderer Mehrfach-Artikel bereits existiert
  loca for AUFERFAS->ArtNr==mArtNr .and. AUFERFAS->Werkzeug==mehrf:WkzNr .and. ;
    ( AUFERFAS->InnerNr == aktMappeNr .or. AUFERFAS->InnerNr == neueMappeNr)

  if AUFERFAS->(eof())

    // bei alten Auftr�gen keine Datens�tze mehr hinzuf�gen
    if alterAuftrag .and. aDateiFelder[fieldpos("GeliefGes")] > 0
      Error(ACHTUNG+"Posten bereits fertiggemeldet.  Mehrfach-Artikel werden nicht hinzugef�gt.")
      select Auferfas
      set filter to &(merkFilter)
      AUFERFAS->(dbgoto( aktRec ))
      select (aktSel)
      return result
    endif

    // neuen Datensatz hinzuf�gen
    ARTIKEL->(dbseek( mArtNr ))

    Add_rec(0)
    setCurrentValues(aDateiFelder)

    replace AUFERFAS->ArtNr with mArtNr
    replace AUFERFAS->Bez1 with ARTIKEL->Bez1
    replace AUFERFAS->Bez2 with ARTIKEL->Bez2
    replace AUFERFAS->Art with getArtikelArt()
    replace AUFERFAS->Reihenfolg with ARTIKEL->Reihenfolg
    replace AUFERFAS->InLfdNr with hole("InlfdNr",WRITE,.t.)
    replace AUFERFAS->Neu with "N"
    result:=.t.

  else
    // // no undelete available
  endif

  mehrf2:=Mehrfach():new( mArtNr, AUFERFAS->Gruppe )

  replace AUFERFAS->Werkzeug with mehrf2:WkzNr
  replace AUFERFAS->Nutzen1 with mehrf2:Nutzen1
  replace AUFERFAS->Nutzen2 with mehrf2:Nutzen2
  if mehrf:Nutzen1 <> 0 .and. mehrf:Nutzen2 <> 0
    replace AUFERFAS->Menge with round(aDateiFelder[fieldpos("Menge")] * mehrf:Nutzen2 / mehrf:Nutzen1 * mehrf2:Nutzen1/mehrf2:Nutzen2, 0)
  endif
  replace AUFERFAS->Grund with aDateiFelder[fieldpos("Grund")]
  replace AUFERFAS->Fert_KW with aDateiFelder[fieldpos("Fert_Kw")]
  replace AUFERFAS->Lief_KW with aDateiFelder[fieldpos("Lief_KW")]
  replace AUFERFAS->EtiAnz with mEtiAnz
  replace AUFERFAS->EtiAnz2 with mEtiAnz2

  // neu 20180817
  replace AUFERFAS->AufNr with aDateiFelder[fieldpos("AufNr")]
  replace AUFERFAS->AbPostNr with aDateiFelder[fieldpos("AbPostNr")]


  // Mappen-Nr ge�ndert?
  if neueMappeNr <> NIL
    replace AUFERFAS->InnerNr with neueMappeNr
  endif
  select Auferfas
  set filter to &(merkFilter)
  AUFERFAS->(dbgoto( aktRec ))
  select (aktSel)

return result
  /** eof */

/** kopiert alle Arbeitsg�nge eines Artikels
  * also alle Hauptmaschinen aus der Zeitst�ckliste
  *
  * Returns true if new records have been added
  */
static function copyArbeitsGang( Zeiten )
LOCAL aktRec:=AUFERFAS->(recno())
LOCAL aktRecCurrent:=recno()
LOCAL aSatz
LOCAL aktSel:=alias()
LOCAL mInnerNr:=AUFERFAS->InnerNr
LOCAL pos, addedRecords:=.f.
LOCAL mArtNr:=AUFERFAS->ArtNr

  // suche ob anderer Arbeitsg�nge bereits existiert
  select Auferfas
  aSatz:=getCurrentValues()
  loca for aktRec <> AUFERFAS->(recno()) .and.;
    AUFERFAS->InnerNr == mInnerNr .and. mArtNr == AUFERFAS->ArtNr .and. ! empty(AUFERFAS->ArbGang)

  if AUFERFAS->(eof()) // Neue Datens�tze anlegen
    go (aktRec)
    replace AUFERFAS->ArbGang with "A"
    replace AUFERFAS->MaschNr with Zeiten[1]:getMaschNr()
    for pos:=2 to len(zeiten)
      add_rec(0)
      setCurrentValues( aSatz )
      replace AUFERFAS->ArbGang with chr(64+pos)
      replace AUFERFAS->MaschNr with Zeiten[pos]:getMaschNr()
      replace AUFERFAS->InLfdNr with hole("InlfdNr",WRITE,.t.)
      replace AUFERFAS->NkNr with "" // neu 20210515
    next
    addedRecords:=.t.
  else
    do while ! AUFERFAS->(eof())
      // nur Werte kopieren
      for pos:=1 to fcount()
        if ! upper(fieldname(pos)) $ "ARBGANG|MASCHNR|INLFDNR"
          fieldPut(pos,aSatz[pos])
        endif
      next
      cont
    enddo
  endif

  select (aktSel)
  go (aktRecCurrent)
  AUFERFAS->(dbgoto( aktRec ))

return addedRecords
/** eof */



/** �berpr�ft ob die KW zw. 01-53 liegt oder aus LiefTerm �bernommen ist,
    leer ist nicht zugelassen */
static Function AV_KW_Okay(kw,text,emptyAllowed,alterAuftrag)
LOCAL woche:=left(kw,2)
LOCAL jahr:=right(kw,2)

  default text:="Liefertermin"
  default emptyAllowed:=.f.
  default alterAuftrag:=.f.

  // okay falls editor - leersatz
  if empty(AUFERFAS->ArtNr) .or. AUFERFAS->Menge == 0 .or. lastkey() == K_UP
    return .t.
  endif

  if empty(woche)
    if emptyAllowed
      return .t.
    else
      Error(ACHTUNG+" Eingabe "+text+"ist Pflicht.",.t.)
      return .f.
    endif
  endif

  if ! KWokay(kw)
    Error(ACHTUNG+text+" ung�ltig.",.t.)
    return .f.
  endif

  // falls Datum von heute -> �berpr�fen Zeitraum KW
  if ! alterAuftrag .and. kwKleiner( kw , getCurrentKW() ) == 1 .and.;
    .not. getUser():id $ KURZEL_MAIN_CUSTOMER+"AB" // H. Weiland & F. Berndt
    Error(ACHTUNG+text+" liegt in der Vergangenheit.  Akt.KW: "+ getCurrentKW(),.t.)
    return .f.
  endif

  // neu 20240216: pr�fe Lief_LW nach Fert_KW
  if text=="Liefertermin" .and. kwKleiner(AUFERFAS->Fert_kw,AUFERFAS->Lief_kw ) < 0
    Error(ACHTUNG+text+" liegt vor Fert.KW.",.t.)
    return .f.
  endif

return .t.
/** eof */


/** �ndert die Reihenfolge / Index
  */
function toggleReihenfolge(aFelder,aKopf)

  if M->currentOrder == 2
    M->currentOrder:=1
  else
    M->currentOrder:=2
  endif

  sortDatei(aFelder,aKopf)

return .t.
/** eof */



/** Sortiert die Datei anhand der akt. Sortierung neu (M->currentOrder)
  * Hinweis: Datei wird inidiziert, dann kopiert und zur�ck kopiert
  * wegen Problemen beim Editor bzgl. einf�gen, anh�ngen, etc.
  */
function sortDatei(aFelder,aKopf)
LOCAL TempFile:=TEMP+BACKSLASH+"SortF"+getUser():getLongID()

  Message("Daten werden sortiert.   Bitte warten...")

  if M->currentOrder == 1
    index on descend(kwIndex(AUFERFAS->Lief_Kw))+str(AUFERFAS->tiefe,3)+AUFERFAS->ArtNr ;
      tag TEMP_IND2 TEMPORARY ADDITIVE
  else
    index on if(empty(AUFERFAS->Reihenfolg),"ZZZ",AUFERFAS->Reihenfolg) + ;
      if( empty(AUFERFAS->ArtNr),replicate("Z",len(AUFERFAS->ArtNr)),AUFERFAS->ArtNr);
      tag TEMP_IND2 TEMPORARY ADDITIVE
  endif

  copy to (tempFile)
  AUFERFAS->(OrdSetFocus(0))
  AUFERFAS->(OrdDestroy(TEMP_IND2))
  zap
  append from(tempFile)
  ferase (tempFile + ".dbf")
  ferase (tempFile + MY_MEMO_EXTENSION)

  PageOut(aFelder,aKopf)
  keyboard chr(K_HOME)
return .t.
/** eof */





/* FUNCTION  Disp_Inner
*
* zeigt die innerbetr. Auftr�ge zu akt. Artikel in Auferfas.dbf auf BS an
*/
FUNCTION Disp_Inner(innerArt)
LOCAL x:=maxrow()-5
LOCAL li:=0
LOCAL merkFarbe:=setcolor()

  @ x,0 clear

  // gebe Anzahl Posten gefiltert/ungefiltert aus
  @ x,0 to x++,79
  @ x,0 say "Anzahl Posten: "
  qqout(alltrim(str(AUFERFAS->(OrdKeyCount()))))
  qqout("           sortiert nach: ")
  // ohne Filter haben beide die gleiche Anzahl
  // qqout(getMyKeyCount(1))
  // qqout(getMyKeyCount(2))
  if innerArt $ INNER_AB + INNER_MIKI
    if M->currentOrder == 1
      setcolor("R/"+getBackColor())
    endif
    qqout(" KW ")
    setcolor(merkFarbe)
    qqout("/")
    if M->currentOrder == 2
      setcolor("R/"+getBackColor())
    endif
    qqout(" AV ")
    setcolor(merkFarbe)
    @ x,65 say "F2 = umschalten"
  else
  endif
  x++
  @ x,0 to x++,79

  // zeige Details zu Artikel
  @ x,0 say "Lager-Bestand  :"+str(ARTIKEL->LageBest,9,2)+;
    " reserviert:"+str(ARTIKEL->Disponiert,15,2)+space(8)
  if ARTIKEL->Disponiert > ARTIKEL->LageBest
    setcolor("R/"+getBackColor())
  endif
  qqout( "Bedarf: "+str( Max( ARTIKEL->Disponiert-ARTIKEL->LageBest , 0 ),12,2) )
  setcolor(merkFarbe)

  x++
  @ x,0 say "Mindest-Bestand:"+str(ARTIKEL->MinbestI,9,2)+ ;
    " interne Auftr�ge:"+str(ARTIKEL->BestInt,9,2) +;
    space(7)+" Mind-Menge:"+str(ARTIKEL->MinOrdInt,9,2)

RETURN(.t.)
/* EOF Disp_Inner */



/** zum bearbeiten der Bemerkung je Posten */
function editInnerBemerkung()
LOCAL s01:=savescreen()
LOCAL aktColor:=setcolor(COLWIN)
LOCAL text
  _thread static lastBemerkung

  Fenster(12,1,21,77,"Bemerkung")
  Message("Bemerkung zu Artikel: "+(ALIAS())->ArtNr+" eingeben.    @F8@=kopieren   @ESC@=Ende")
  SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
  SetKey( K_F8 , {|| __Keyboard(lastBemerkung)} )
  text:=MyMemoEdit((ALIAS())->Bemerkung,13,2,20,76, .t.)
  Set Key K_ESC to
  Set Key K_F8 to
  replace (ALIAS())->Bemerkung with text
  lastBemerkung:=(ALIAS())->Bemerkung
  restscreen(,,,,s01)
  setcolor(aktColor)
return .t.
/** eof */


/** stellt die Inner-Nr zum Anzeigen am BS um, lt. Kundenwunsch
* z.Zt.  right shift only, 4 Zeichen + 1 Zeichen Arbeitsgang (default A)
*/
function dispInnerNr(innernr, arbgang)
return innernr + left(trim(arbgang)+"A",1)
/** eof */

  /** Liefert die nummer (numerisch) folgenderma�en als String zur�ck:
  4 Stellen nach rechts geshiftet
  */
function getInnerShifted(nummer)
LOCAL anz
  if valtype(nummer)=="C"
    if isAllDigit(alltrim(nummer))
      anz:=4
      else// mit Arbeitsgang A,B,... am Ende
      anz:=5
    endif
  else
    anz:=4
    nummer:=str(nummer)
  endif
return right(space(anz)+alltrim(nummer),anz)

/** liefert die n�chste freie Mappen-Nr (InnerNr) als String zur�ck  */
function getNextInnerNr()
LOCAL loopCount:=0
LOCAL aktRec:=AUFERFAS->(recno())
LOCAL innerOrd:=INNER->(indexOrd())
LOCAL prodNr:=val(hole("InnerNr",WRITE))
LOCAL aktSel:=ALIAS()
LOCAL ende:=.f.

  // falls hole schief geschlagen ist, beginne am Anfang
  if prodNr < INNER_NR_BEGINN
    prodNr:=INNER_NR_BEGINN
  endif

  select Inner
  go top
  do while (! ende)
    dbseek(getInnerShifted(prodNr))
    // pr�fe ob bereits in akt. Auftrag Erfassung verwendet
    select AufErfas
    loca for AUFERFAS->InnerNr==getInnerShifted(prodNr)
    select Inner
    ende:=INNER->(eof()) .and. AUFERFAS->(eof()) .and. ;
      ! alltrim(str(prodNr)) $ getProperty("Miki.av.inner.kostenst","")
    if ! ende
      prodNr++
      loop
    endif
    if prodNr>=INNER_NR_END
      if loopCount++ > 1 // exit after 2nd loop since all numbers are taken
        exit
      endif
      prodNr:=INNER_NR_BEGINN
      ende:=.f.
    endif
  enddo
  INNER->(OrdSetFocus(innerOrd))
  select AufErfas
  go (aktRec)

  if prodNr==INNER_NR_END
    Error(ACHTUNG+"Alle Arbeits-Mappen belegt.|"+;
      "         Bitte zuerst innerbetr. Auftr�ge abschlie�en."+SCHWERER_FEHLER)
    select (aktSel)
    return NIL
  endif

  // Inner-Nr r�ckschreiben
  if open("System") .and. rec_lock(5)
    if prodNr<INNER_NR_END
      replace SYSTEM->InnerNr with prodNr+1
    else
      replace SYSTEM->InnerNr with INNER_NR_BEGINN
    endif
    dbcommit()
    dbunlock()
  endif
  select (aktSel)

return getInnerShifted(prodnr)
/** eof */

/*----------------------------------------------------------------------*/

/** ruft die St�ckliste Lind, aufl�sen F5 auf, je nach Auftragsart mit oder ohne Menge */
static function callMyStkListLind()
  if empty( AUFERFAS->AufNr )
    MyStkListLind( row() , AUFERFAS->Menge )
  else
    // Auftragsbestand enth�lt diesen Artikel bereits, also ohne Menge
    MyStkListLind( row() , 0 )
  endif
return .t.
/** eof */

/** wird vor Eingabe der Auf.Nr ausgef�hrt */
static function AufNrVor(oGet)
  ignore oGet

  set key K_F8 to copyLastAufNr(p1,oGet)
  set key HILFE_TASTE1 to myAufBestArtikel(p1,oGet)
  set key HILFE_TASTE2 to myAufBestArtikel(p1,oGet)

return .t.
/** eof */

static function myAufBestArtikel(p1,oGet)
LOCAL result:=NIL

  ignore p1

  // eine Zeile h�her -> dann sind wir auf dem 1. Posten
  keyboard chr( K_UP )

  M->specialZeige:={{ chr(K_RETURN) , { || ZeigeAuswahl() } , " @RETURN@=Ausw." }}
  result:=AufBestArtikel(AUFERFAS->ArtNr)
  M->specialZeige:=NIL

  if result != NIL .and. ! empty( result )
    oGet:varput( result )
    oGet:changed:=.t.
    oGet:updateBuffer()
    keyboard chr( K_RETURN )
    return .t.
  endif

return .t.
/** eof */

  /** markiert Posten nur als gel�scht (bisher nur bei InnerEdit)
  */
static function konsistenzLoesch()
LOCAL aktRec:=AUFERFAS->(recno())
LOCAL mInnerNr:=AUFERFAS->InnerNr

  if AUFERFAS->GeliefGes > 0
    Error(ACHTUNG+;
      "Artikel wurde bereits fertig-gemeldet.||         Kann nicht gel�scht werden!",.t.)
    return .f.
  endif

  if ! empty(AUFERFAS->ArbGang)
    if AUFERFAS->ArbGang<>ARBEITSGANG_DL // Dienstleistung darf man einzeln l�schen
      // alle anderen Arbeitsg�nge als gel�scht markieren
      repla;
        AUFERFAS->geloescht;
        with "J" for aktRec <> AUFERFAS->(recno()) .and. AUFERFAS->InnerNr == mInnerNr
      AUFERFAS->(dbgoto( aktRec ))

      // now delete via editor.prg
      HB_KeyPut(EDIT_DELETE)
    endif
  endif

return .t.
/** eof */

/**  beendet edit mit CHANGED == .t. */
static function exitAndPrint(aKopf)
  aKopf[EDIT_CHANGED]:=.t.
  keyboard chr( K_ESC )
return .t.
/** eof */

/** Zeigt die Kalk.�bersicht (F8) an */
function kalkUeber()

  /* anzeige �bersicht */
  Hilfe("AV_KALK: KALK-UEBER",getnew(),"Blubb")

return .t.
/** eof */



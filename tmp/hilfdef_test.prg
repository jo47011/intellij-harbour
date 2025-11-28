/* Def. der einzelnen Hilfe-Fenster
*
*/

#include "Miki.ch"
#include "hilfe.ch"
#include "hbgtinfo.ch"

#xtranslate suchtext( <x> ) => suchTextInit( oGet , <x> )
#xtranslate suchtext() => suchTextInit( oGet , chr(255) )

#define TEXT_EDIT {K_F3 , { || zeile_aend() } ," @F3@=Text" }

#define HIGHLIGHT_CUSTOM_SELECTED iif(TEMP_CUSTOM_SELECTED,RED_ON_WHITE, NIL )
#define;
  HIGHLIGHT_DUEDATE;
  iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , iif(RECHAUS->Mahnstufe > 0 , RED_ON_WHITE,;
  NIL) )

#define;
  INTRASTAT_FARBE;
  {;
  ||;
  iif( RECHPOST->IntraStat=="X" , RED_ON_WHITE , iif( RECHAUS->IntraStat=="J" , GRAY_ON_WHITE ,;
  NIL ) ) }

#define ARRAY_COLSEP " | "
/*
* Altes Hilfskonrukt zum definieren der Hilfe/Auswahlliste-Spalten.  Wird aus Hilfe.prg aufgerufen.
*
* Default - Werte Bildschirm sind:
* oBrowse:nTop    :=5
* oBrowse:nBottom :=MaxRow()-3
* oBrowse:nLeft   :=1
* oBrowse:nRight  :=MaxCol()-1
*
* Spaltendef:
*   oBrowse, Feld
*            Titel      default: Feld-Name
*            Breite     default: Max(Feld,Titel)
*            �nderbar   default: .f.
*            Spalten-Fkt.
*/
FUNCTION HilfDef( oBrowse , oGet , cProg)
LOCAL oColumn,i,sz_chr,sz_asci , text, tempVal, aktRec

  if ! valtype(oGet)=="O" // kein offenes Get-Objekt
    M->okay:=.f. // Ende Hilfe
    RETURN oBrowse
  endif

  /* setzen der Default Werte */
  // go top
  oBrowse:GoTopBlock:={ || dbgotop() }
  // go bottom
  oBrowse:GoBottomBlock:={ || dbgobottom() }

  DO CASE

    /*** Artikel   ***/
  CASE ("ARTNR" $ upper(oGet:Name) .or. "M->ARTNR"== upper(oGet:Name) .or. "ANR"== upper(oGet:Name));
    .and. ! "HARTNR" $ upper(oGet:Name) // .or. cProg=="BeistellTeile"

    // special case alternat. Material
    if upper(oGet:Name) == "EDITMATARTNR"
      // definiere Spezial-Funktion bei Abruf-Auftragsnr, da in der gleichen Datei referenziert wird
      M->keepPosition:=.t.
    endif

    open("Artikel")

    if getUser():mayEditData

      M->SpecialHilfe:={ TEXT_EDIT ,;
        { K_ALT_E , { || E_ArtDisp(M->oBrowse:rowPos+2,46) }, nil } ,;
        { K_F4 , nil , nil } ,; // disabled
      { K_F5 , { || addEnglColumn(M->oBrowse) }, nil } ,;
        { K_F6 , { || MatArtikelListe() } , ;
        " @F5@=D"+chr(29)+"E @F6@=in St�ckl." } }

    endif

    add_artikel_columns(oBrowse)

    /*** Honsel-Artikel   ***/
  CASE cProg=="HONSELARTIKEL"
    // changed 20170411, da man mit der enstpr. Permission hier auch �ndern kann
    if ! openArtikelAendernDateien()
      Error(TRY_AGAIN)
      M->okay:=.f.
      RETURN oBrowse
    endif
    select Artikel
    ARTIKEL->(OrdSetFocus(2)) // Honsel-Nr
    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    endif

    M->clearBuffer:=.t. // clear buffer upon selection

    // M->Return_Feld:="ARTIKEL->ArtNr" // gebe Art.Nr. zur�ck

    // such-Text initialisieren
    // if ! empty(left(ARTIKEL->HArtNr,8))
    // SuchText( ARTIKEL->HArtNr )
    // endif

    oBrowse:nTop:=2

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "HArtNr" , "Honsel.Nr." )
    felderAlt( "Out(ArtNr)" , "Art.Nr." )
    felderAlt( "Bez1" , "Bezeichnung" ,,.t.)
    felderAlt( "Art" , " ")
    felderAlt( "Wkz" , " ")
    felderAlt( "LageBest" , "Lg-Best.")
    felderAlt( "LagerOrt" , "Lager-Ort")
    felderAlt( "Preis1" , "VK")
    felderAlt( "Bez2" , "Bezeichnung 2" ,,.t.)

  CASE cProg=="ARTIKEL AUSKUNFT"

    open("Artikel")

    M->Return_Feld:="NIL"

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F4 , nil , nil })
    aadd( M->SpecialHilfe , { K_CTRL_F4 , { || NegVerfueg(getArtikelArt(),ARTIKEL->ArtNr)} , nil };
      )
    aadd( M->SpecialHilfe , { K_F5 , { || MyStkListLind() }, " @F5@=aufl�sen" } )
    aadd( M->SpecialHilfe , { K_F6 , { || MatArtikelListe() }, ;
      " @F6@=in Stkl." } )
    aadd( M->SpecialHilfe , { "hH" , { || WarAusList("BS",ARTIKEL->ArtNr) }, " @H@istorie" } )

    // Instruktionen anzeigen d�rfen alle
    if getUser():mayEditData
      text:=""
    else
      text:=" @I@nstrukt."
    endif
    aadd(M->SpecialHilfe , { K_ALT_I , { || showInstruktion() },""})
    aadd(M->SpecialHilfe , { "iI" , { || showInstruktion() },text})
    aadd( M->SpecialHilfe, { K_LDBLCLK , { || MyStkListLind() }, "" } )

    // keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)

    oBrowse:nTop:=3
    oBrowse:nLeft:=0
    oBrowse:nRight:=maxcol()

    // /* Spalten-Definition */
    // /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   ,numerisch*/
    // // (nur aus Komp.gr�nden)
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Out(ArtNr)"
    oColumn[COL_TITEL]:="Art.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez1"
    oColumn[COL_TITEL]:="Bezeichnung"
    oColumn[COL_SECOND_LINE]:="Bez2"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Art"
    oColumn[COL_TITEL]:="Art"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LageBest"
    oColumn[COL_TITEL]:="Bestand"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LG_Raum+'.'+LG_Regal+'.'+Lg_Fach"
    oColumn[COL_TITEL]:="Raum.Regal.Fach"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LG_Text"
    oColumn[COL_TITEL]:="Lg Text"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="if(getArtikelArt()$'FM',str(ARTIKEL->BestInt,8,2),str(ARTIKEL->BestExt,8,2))"
    oColumn[COL_TITEL]:="Bestellt"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Formrahmen"
    oColumn[COL_TITEL]:="Formrahmen"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="left(get_best()+space(30),30)"
    oColumn[COL_TITEL]:="Best.Nr (Lief.KW)"
    oColumn[COL_BREITE]:=30
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="HartNr"
    oColumn[COL_TITEL]:="Honsel Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    // oColumn[COL_NAME]:="if(empty(ARTIKEL->KonsigKdNr),space(9),KonsigBest)"
    oColumn[COL_NAME]:="KonsigBest"
    oColumn[COL_TITEL]:="K-Lager Best."
    addMyColumn ( oColumn )


    /*** HonselDaten   ***/
  CASE "HONSEL_NR" $ upper(oGet:Name) .or. "M->XMIKI_NR"== upper(oGet:Name)
    open("HonselDa")
    // if getUser():mayEditData
    // M->SpecialHilfe:={ TEXT_EDIT }
    // endif

    if getUser():mayEditData
      M->SpecialHilfe:={{ "iI" , { || H_InvVerabeiten(.t.) }, " @I@nventur" }}
      aadd( M->SpecialHilfe , { "eE" , { || honselDatExport(.t.) }, " @E@xport" } )
    endif

    M->Return_Feld:="HONSELDA->Miki_Nr" // gebe Art.Nr. zur�ck
    oBrowse:nTop:=2

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Out(Miki_nr)"
    oColumn[COL_TITEL]:="Miki-Art.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez1"
    oColumn[COL_TITEL]:="Bezeichnung"
    // oColumn[COL_SECOND_LINE]:="Bez2"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="HonselBest"
    oColumn[COL_TITEL]:="Honsel-Bst"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MikiBest"
    oColumn[COL_TITEL]:="Miki-Bst"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="HonselBest-MikiBest"
    oColumn[COL_TITEL]:="Diff."
    // oColumn[COL_BREITE]:=5
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="HONSEL_NR"
    oColumn[COL_TITEL]:="Honsel-Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Fehler"
    addMyColumn ( oColumn )


    /*** Rahmen-Auftr�ge ***/
  CASE "AUFAUS->AB_AUFNR" $ upper(oGet:Name) // muss vor "AUFNR" $ upper(oGet:Name) s.u. stehen

    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    M->Return_Feld:="AUFAUS->AufNr" // gebe AB.Nr. zur�ck

    // Info Umgebung speichert jetzt auch relas, d.h. diese wird automat. zur�ckgesetzt
    select aufpost
    set rela to AUFPOST->AufNr into AUFAUS

    index on AUFPOST->ArtNr+AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      AUFAUS->AufArt $ M->istAbrufAuftrag .and. AUFAUS->erledigt<>'J' .and. ;
      AUFPOST->GeliefGes < AUFPOST->Menge

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "AUFPOST->ArtNr" , "Art.Nr" )
    felderAlt( "AUFPOST->Komm1" , "Bezeichnung" )
    // felderAlt( "str(AUFPOST->Menge-AUFPOST->GeliefGes,9,2)" , "Rest",,,,.t. )
    felderAlt( "str(AUFPOST->Menge-AUFPOST->GeliefGes,9,2)" , "     Rest" )
    felderAlt( "AUFPOST->KW" , "KW" )
    felderAlt( "AUFAUS->AufNr" , "AB-Nr." )
    felderAlt( "KdOut(AUFAUS->KundNr)" , "Kd.Nr." )
    felderAlt( "AUFAUS->Kurzname" , "Name" )
    felderAlt( "AUFPOST->Menge" , "Menge" )
    felderAlt( "AUFPOST->GeliefGes" , "Gelief." )
    felderAlt( "AUFAUS->Aufdat" , "Datum" )
    felderAlt( "KdOut(AUFAUS->V_KundNr)" , "Versand Kd.Nr." )
    felderAlt( "KdOut(AUFAUS->R_KundNr)" , "Rechnung Kd.Nr." )

    // definiere Spezial-Funktion bei Abruf-Auftragsnr, da in der gleichen Datei referenziert wird
    M->keepPosition:=.t.

    /*** Auftr�ge ***/
  CASE "AUFNR" $ upper(oGet:Name)

    M->SpecialHilfe:={ ;
      { "Ll" , { || LieferLIste(,,"BS",AUFAUS->AufNr) } ," @L@ieferstatus" } }

    keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)

    open("Aufaus")
    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="AB.Nr."
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KundNr"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="BestNr"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    // Rahmenauftrag Budget -> extra Felder
    if type("m->defAuftrArt")=="C" .and. M->defAuftrArt$"B"
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="Netto"
      oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
      addMyColumn ( oColumn )

      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="Netto-RahmBez"
      oColumn[COL_TITEL]:="Rest"
      oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
      addMyColumn ( oColumn )

      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="RahmBez"
      oColumn[COL_TITEL]:="Abgerufen"
      oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
      addMyColumn ( oColumn )
    endif

    oColumn:=getNewColumn()
    oColumn[COL_BREITE]:=17 // 2 Rechnungen werden max. angezeigt
    oColumn[COL_NAME]:="getRechnrByAufNr()"
    oColumn[COL_TITEL]:="Rech.Nr."
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Brutto"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Erledigt"
    oColumn[COL_TITEL]:="Erl"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="if(AUFAUS->AufArt$'GK',AUFAUS->Aufart,' ')"
    oColumn[COL_TITEL]:="Art"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="if(AUFAUS->Aufart=='B','Budget',if(AUFAUS->Aufart=='D','Artikel',AB_AufNr+'  '))"
    oColumn[COL_TITEL]:="Rahmen-AB"
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="V_KundNr"
    oColumn[COL_TITEL]:="Versand Kd.Nr."
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="R_KundNr"
    oColumn[COL_TITEL]:="Rechnung Kd.Nr."
    oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    /*** Hand-Lieferschein   ***/
  CASE "LSNR" $ upper(oGet:Name) .and. alias()=="LIEFAUS"

    // pre 20181219: Auswahl nach Artikeln nicht mehr gew�nscht
    //
    // M->Return_Feld:="LIEFAUS->LSNr" // gebe AB.Nr. zur�ck

    // // AB-Posten vorbereiten f�r Auswahl
    // select liefpost
    // set rela to LIEFPOST->LSNr into LIEFAUS
    // index on LIEFPOST->ArtNr+LIEFPOST->LSNr tag TEMP_INDEX TEMPORARY ADDITIVE for 
    // len(alltrim(LIEFPOST->Artnr))>FRACHT_LAENGE .and. LIEFAUS->Erledigt<>"J"

    // // raus am 17.4.2013, da Umgebung jetzt auch relas speichert
    // // ACHTUNG: rela muss danach wieder von Hand zur�ck gesetzt werden -> s. M->postFunction!!!
    // // so lange relation in Umgebung(READ/WRITE) noch nicht gespeichert werden
    // // M->postFunction:={|| LIEFPOST->(dbclearRelation()),LIEFPOST->(OrdSetFocus(1))}

    // /* Spalten-Definition */
    // /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // felderAlt( "LIEFPOST->ArtNr" , "Art.Nr" )
    // felderAlt( "LIEFPOST->Komm1" , "Bezeichnung" )
    // felderAlt( "LIEFPOST->Menge" , "Menge" )
    // felderAlt( "LIEFAUS->LSNr" , "LS.Nr." )
    // felderAlt( "LIEFAUS->AufNr" , "Auf.Nr." )
    // felderAlt( "KdOut(LIEFAUS->KundNr)" , "Kd.Nr." )
    // felderAlt( "LIEFAUS->Kurzname" , "Name" )
    // felderAlt( "LIEFAUS->Aufdat" , "Datum" )

    // // definiere Spezial-Funktion bei Abruf-Auftragsnr, da in der gleichen Datei referenziert wird
    // M->keepPosition:=.t.

    open("Liefaus")
    oBrowse:nLeft:=0
    oBrowse:nRight:=80
    oBrowse:goBottom()

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LSNr"
    oColumn[COL_TITEL]:="LS.Nr."
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="AB.Nr."
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    oColumn[COL_BREITE]:=6
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KundNr"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="BestNr"
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Erledigt"
    oColumn[COL_TITEL]:="AB Erledigt"
    oColumn[COL_FARBE]:={ || iif(LIEFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    /*** Auftr�ge nach BestellNr ***/
  CASE "HONSELNR" $ upper(oGet:Name) .or. cProg=="HONSELBESTNR"

    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    if cProg=="HONSELBESTNR"
      // keine R�ckgabe
      M->Return_Feld:="NIL"
    endif

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   ,numerisch */
    felderAlt( "AUFAUS->BestNr" , "Best.Nr." )
    felderAlt( "out(ArtNr)" , "Art.Nr." )
    felderAlt( "left(Komm1,30)" , "Bezeichnung" )
    felderAlt( "AufNr" , "Auftr." )
    felderAlt( "kw" , "LW" )
    felderAlt( "transform(Menge-GeliefGes,'9999999')" , "Rest" , 7 ,,,.t.)
    felderAlt( "str(geliefges,7)" , "gel." , , .f. )
    felderAlt( "str(Menge,7)" , "best." )
    felderAlt( "ARTIKEL->LageBest" , "LagerBest." )
    felderAlt( "if(AUFPOST->AufArt$'GK',AUFPOST->Aufart,' ')", " " ,1, ,,,{ || { 7, 8 } } )
    felderAlt( "ARTIKEL->Hartnr" , "Honsel.Nr." )

    // 1. und 2. Spalte festhalten, HINWEIS: muss hier am Ende stehen!
    oBrowse:freeze:=2

    /*** Angebote ***/
  CASE "ANGNR" $ upper(oGet:Name) .or. cProg=="ANGEBOTE/UEBERNAHME"
    open("AngAus")
    M->suchShiftRight:=.t.

    keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "AngNr" , "Ang.Nr" )
    felderAlt( "Aufdat" , "Datum" )
    felderAlt( "KdOut(KundNr)" , "Kd.Nr." )
    felderAlt( "Kurzname" , )
    felderAlt( "Brutto" , )

    /*** Rechnungen ***/
  CASE "RECHNR" $ upper(oGet:Name)
    open("Rechaus")

    keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RechNr"
    oColumn[COL_TITEL]:="Rech.Nr."
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ReaDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="Auftr.Nr."
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KdOut(KundNr)"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Brutto"
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Netto"
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="BestNr"
    oColumn[COL_FARBE]:={ || iif( ! empty( RECHAUS->Bezahlt ) , GRAY_ON_WHITE , NIL ) }
    // oColumn[COL_FARBE]:={ || iif(AUFAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufArt"
    oColumn[COL_TITEL]:="Art"
    addMyColumn ( oColumn )

    /*** Rechnungen / Zahlungseingang ***/
  CASE cProg=="RECHBEZAHLT"
    open("Rechaus")

    // keyboard(chr(K_END)) // gehe ans Ende

    M->SpecialHilfe:={}
    aadd(M->SpecialHilfe,{K_RETURN , { || RechBezahlt() }, "" })
    aadd(M->SpecialHilfe,{K_F5 , { || toggleZahlIndex() }, " @F5@=alle/nur f�llige " })
    // aadd(M->SpecialHilfe,{ "mM" , { || zeile_aend() } ," @M@ahnstufe" })

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RechNr"
    oColumn[COL_TITEL]:="Re.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Mahnstufe"
    oColumn[COL_TITEL]:="MS"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ReaDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KdOut(KundNr)"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Brutto"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Faellig"
    oColumn[COL_TITEL]:="F�llig"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="Auftr.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufArt"
    oColumn[COL_TITEL]:="Art"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="BestNr"
    oColumn[COL_TITEL]:="Best.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ZkNr"
    oColumn[COL_TITEL]:="Zahl.Kond."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ZAHLKOND->Text"
    oColumn[COL_TITEL]:="Zahlungskonditionen"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ZAHLKOND->Text2"
    oColumn[COL_TITEL]:="Zahlungskonditionen"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bezahlt"
    oColumn[COL_TITEL]:="bez. am"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_DUEDATE }
    addMyColumn ( oColumn )

    /*** GelangensBescheinigungen/Rechnungen anzeigen ***/
  CASE "GELNR" $ upper(oGet:Name)
    open("Rechaus")

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RechNr"
    oColumn[COL_TITEL]:="Rech.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ReaDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="GelNr"
    oColumn[COL_TITEL]:="GBS Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KdOut(KundNr)"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="Auftr.Nr."
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Netto"
    oColumn[COL_FARBE]:={ || HIGHLIGHT_CUSTOM_SELECTED }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufArt"
    oColumn[COL_TITEL]:="Art"

    /*** Stunden, Zeit AV ***/
  CASE "STDNR" $ upper(oGet:Name) .or. upper(oGet:Name)=="M->NACH";
    .or.;
      upper(oGet:Name)=="M->MASCH";
      .or. upper(oGet:Name)=="MASCHNR" .or. upper(oGet:Name)=="NKPOST->MASCHNR"
    open("Maschine")
    oBrowse:nLeft:=0
    oBrowse:nRight:=maxcol()

    M->SpecialHilfe:={ { K_F6 , { || stdStkListe() } , " @F6@=in St�ckl." } }


    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "StdNr" , "Nr" )
    felderAlt( "MaschGr" , "Gr" )
    felderAlt( "Bez" , "Text")
    felderAlt( "HauptKZ" , "KZ")
    felderAlt( "Art" , "Art")
    felderAlt( "Kosten" , "Kosten H")
    felderAlt( "KostenNe" , "Kosten N")
    felderAlt( "Ruestzeit" , "R�stzeit")
    felderAlt( "KostenSt","KostenSt.")

    /*** St�ckliste AV ***/
  CASE "AVNR" $ upper(oGet:Name)
    open("AvAus")

    oBrowse:goBottom()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "out(AvNr)" , "Nr" )
    felderAlt( "trim(ARTIKEL->Bez1)+' '+ARTIKEL->bez2" , "Text" , 60 , .f. )


    /*** Mat.Kz Magazine ***/
  CASE "MATKZ" $ upper(oGet:Name) .or. "MAT_KZ" $ upper(oGet:Name)
    open("Mat_Kz")
    oBrowse:nLeft:=1
    oBrowse:nRight:=78
    // sortByColumn(1)

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || MatKzListe(MAT_KZ->MatKz) }, " @F6@=in Artikel" } )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MatKz"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    for i:=1 to 6
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="get_token('MAT_KZ->MkzText',"+str(i,1)+")"
      oColumn[COL_SORT]:=".t."
      oColumn[COL_BREITE]:=32
      oColumn[COL_TITEL]:="Text"+str(i,1)
      addMyColumn ( oColumn )
    next

    /*** Artikel Texte ***/
  CASE "ARTTEXTNR" $ upper(oGet:Name)
    open("ArtText")
    oBrowse:nLeft:=1
    oBrowse:nRight:=78
    // sortByColumn(1)

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || ArtTextListe(ARTTEXT->ArtTextNr) }, " @F6@=in Artikel" };
      )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ArtTextNr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    for i:=1 to 6
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="get_token('ARTTEXT->Text',"+str(i,1)+")"
      oColumn[COL_SORT]:=".t."
      oColumn[COL_BREITE]:=32
      oColumn[COL_TITEL]:="Text"+str(i,1)
      addMyColumn ( oColumn )
    next

    /*** Texte AV ***/
  CASE "TEXTNR" $ upper(oGet:Name) .and. ! "PRODTEXT" $ upper(oGet:Name)
    open("Text")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "TextNr" , "Nr" )
    felderAlt( "Text" , "Text")

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || textStkListe() } , " @F6@=in Stkl." } )

    /*** Sortierung AV ***/
  CASE "REIHENFOLG" $ upper(oGet:Name)
    open("AvSortNr")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    else
      M->SpecialHilfe:={ }
    endif

    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelWertListe() } , " @F6@=in Artikel" } )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "Reihenfolg" , "Nr" )
    felderAlt( "Text" , "Text")

    /*** Maschinen-Gruppe AV ***/
  CASE "MASCHGR" $ upper(oGet:Name) .or. "CHILDGR" $ upper(oGet:Name)
    open("MaschGr")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    else
      M->SpecialHilfe:={ }
    endif

    if "CHILDGR" $ upper(oGet:Name)
      // definiere Spezial-Funktion bei Abruf-Auftragsnr, da in der gleichen Datei referenziert wird
      M->keepPosition:=.t.
    endif

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "MaschGr" , "Nr" )
    felderAlt( "Bez" , "Bezeichnung")
    felderAlt( "ChildGr" , "Ober-Gruppe" )

    /*** Lieferanten ***/
  CASE "LIEFNR" $ upper(oGet:Name) .or. cProg=="Hand-LS,LiefNr"
    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT, { K_CTRL_N,;
        { || toggleMissingNumbers(oBrowse, "LIEFERAN", "LiefNr", "KurzName", "LIEFERAN->Name1 + ' ' + LIEFERAN->Name2", {80}, oGet, cProg) }, " @STRG-N@=Freie Nummern" } }
    endif
    open("Lieferan")

    if cProg=="Hand-LS,LiefNr"
      M->Return_Feld:="LIEFERAN->LiefNr+chr(13)" // we need this as the get field KundNr is longer
    endif

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "LiefNr" , "Nr" )
    felderAlt( "KurzName" , "Kurzname")
    felderAlt( "trim(Name1)+' '+Name2" , "Name" ,40 , .f. )
    felderAlt( "Strasse" , "Stra�e" )
    felderAlt( "Zusatz" ,)
    felderAlt( "Land+space(1)+Plz+space(1)+Ort","Ort" )
    felderAlt( "EIban","IBAN 1" )
    felderAlt( "PIban","IBAN 2" )


    /*** VersandArten ***/
  CASE "VERSNR" $ upper(oGet:Name)
    open("VersArt")
    oBrowse:nLeft:=20
    oBrowse:nRight:=67

    M->SpecialHilfe:={ { K_F6 , { || ABWertListe() } , " @F6@=in AB/Angebot" } }

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "VersNr" , "Nr" )
    felderAlt( "Text" , "Text")
    felderAlt( "VerPack" , "Verp.")
    felderAlt( "Fracht" , "Fracht")

    /*** Zahlungskonditionen ***/
  CASE "ZKNR" $ upper(oGet:Name)
    open("ZahlKond")
    // oBrowse:nLeft:=10
    // oBrowse:nRight:=70

    M->SpecialHilfe:={ { K_F6 , { || ABWertListe() } , " @F6@=in AB/Angebot" } }

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "ZKNr" , "Nr" )
    felderAlt( "Text" , "Text")
    felderAlt( "Text2" , "")
    felderAlt( "Skto" ,"Skto %")
    felderAlt( "SktoTage" ,"Skto-Tage")
    felderAlt( "SktoMonate" ,"Skto-Monate")
    felderAlt( "Tage" ,"F�llig-Tage")
    felderAlt( "Monate" ,"F�llig-Monate")

    /*** KostenStelle ***/
  CASE "KOSTST" $ upper(oGet:Name) .or. "KOSTENST" $ upper(oGet:Name) .or. "KSTSTNE" $ upper(oGet:Name) ;
    .or. "KOSTNR" $ upper(oGet:Name)
    open("KstStamm")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    else
      M->SpecialHilfe:={ }
    endif
    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelWertListe() } , " @F6@=in Artikel" } )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "KostNr" , "Nr" )
    felderAlt( "Inland" , )
    felderAlt( "Eg" , )
    felderAlt( "Sonst" , )
    felderAlt( "Bez" , "Bezeichnung")

    /*** Bestellung KopfDatei ***/
  CASE "BESTNR" $ upper(oGet:Name)
    open("BesAus")

    keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="BestNr"
    oColumn[COL_TITEL]:="Nr."
    oColumn[COL_FARBE]:={ || iif(BESAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Aufdat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:={ || iif(BESAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LiefNr"
    oColumn[COL_TITEL]:="Lief.Nr."
    oColumn[COL_FARBE]:={ || iif(BESAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzname"
    oColumn[COL_FARBE]:={ || iif(BESAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Erledigt"
    oColumn[COL_TITEL]:="Erl."
    oColumn[COL_FARBE]:={ || iif(BESAUS->Erledigt=="J",GRAY_ON_WHITE, NIL ) }
    addMyColumn ( oColumn )

    /*** Werbe-Text Bestellung ***/
  CASE "TEXTKZ_NR" $ upper(oGet:Name)
    open("Text_Kz")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    M->SpecialHilfe:={ { K_F6 , { || ABWertListe() } , " @F6@=in AB/Angebot" } }

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "TextKz_Nr" , "Nr" )
    felderAlt( "trim(Text1)+' '+Text2", "Text" , 60 , .f. )
    felderAlt( "trim(Text3)+' '+Text4", "Text" , 60 , .f. )

    /*** Auftragsposten mit Filter ***/
  CASE cProg=="FAKT,AUFTRAG MIT FILTER"
    oBrowse:nLeft:=0
    oBrowse:nRight:=80
    // open("AufPost") // ACHTUNG index mit for clause ist bereits erstellt und selektiert

    suchtext( KUNDEN->kundnr+"R" )
    oBrowse:gotop()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   ,numerisch */
    felderAlt( "out(ArtNr)" , "Art.Nr." )
    felderAlt( "left(Komm1,30)" , "Bezeichnung" )
    felderAlt( "kw" , "LW" )
    felderAlt( "transform(Menge-GeliefGes,'9999999')" , "Rest" , 7 ,,,.t.)
    felderAlt( "str(geliefges,7)" , "gel." , , .f. )
    felderAlt( "str(Menge,7)" , "best." )
    felderAlt( "AufNr" , "Auftr." )
    felderAlt( "ARTIKEL->LageBest" , "LagerBest." )
    felderAlt( "if(AUFPOST->AufArt$'GK',AUFPOST->Aufart,' ')", " " ,1, ,,,{ || { 7, 8 } } )

    if getUser():id==KURZEL_DEVEL
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="ABPostNr"
      oColumn[COL_TITEL]:="AB-PostNr"
      // oColumn[COL_BREITE]:=4
      addMyColumn ( oColumn )
    endif

    /*** K-LagerAuftragsposten mit Filter ***/
  CASE cProg=="FAKT,K-AUFTRAG MIT FILTER"

    oBrowse:nLeft:=0
    oBrowse:nRight:=80
    // open("AufPost") // ACHTUNG index mit for clause ist bereits erstellt und selektiert

    // such-text initialisieren
    suchtext( KUNDEN->kundnr+"K" )
    oBrowse:gotop()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   ,numerisch */
    felderAlt( "out(ArtNr)" , "Art.Nr." )
    felderAlt( "left(Komm1,30)" , "Bezeichnung" )
    felderAlt( "kw" , "LW" )
    felderAlt( "transform(Menge-GeliefGes,'9999999')" , "Rest" , 7 ,,,.t.)
    felderAlt( "str(geliefges,7)" , "gel." , , .f. )
    felderAlt( "str(Menge,7)" , "best." )
    felderAlt( "AufNr" , "Auftr." )
    felderAlt( "ARTIKEL->LageBest" , "LagerBest." )
    felderAlt( "if(AUFPOST->AufArt$'GK',AUFPOST->Aufart,' ')", " " ,1, ,,,{ || { 7, 8 } } )

    /*** AV-Auftragsposten mit Filter ***/
  CASE "AV,AUFTRAG MIT FILTER" $ cProg
    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    M->Return_Feld:="NIL"

    if "TOPLEVEL" $ cProg
      index on AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        AUFERFAS->AufNr == AUFPOST->AufNr .and. AUFERFAS->ArtNr == AUFPOST->ArtNr
    else
      index on AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        AUFERFAS->AufNr == AUFPOST->AufNr .and. containsChild( AUFPOST->ArtNr, AUFERFAS->ArtNr )
    endif

    // go top
    oBrowse:GoTop()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   ,numerisch */
    felderAlt( "out(ArtNr)" , "Art.Nr." )
    felderAlt( "left(Komm1,30)" , "Bezeichnung" )
    felderAlt( "kw" , "LW" )
    felderAlt( "transform(Menge-GeliefGes,'9999999')" , "Rest" , 7 ,,,.t.)
    felderAlt( "str(geliefges,7)" , "gel." , , .f. )
    felderAlt( "str(Menge,7)" , "best." )
    felderAlt( "AufNr" , "Auftr." )
    felderAlt( "ARTIKEL->LageBest" , "LagerBest." )
    felderAlt( "if(AUFPOST->AufArt$'GK',AUFPOST->Aufart,' ')", " " ,1, ,,,{ || { 7, 8 } } )

    if getUser():id==KURZEL_DEVEL
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="ABPostNr"
      oColumn[COL_TITEL]:="AB-PostNr"
      // oColumn[COL_BREITE]:=4
      addMyColumn ( oColumn )
    endif

    /*** Kunden ***/
  CASE "KUNDNR" $ upper(oGet:Name) .or. "KONSIGKDNR" $ upper(oGET:Name)
    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT, { K_CTRL_N, { || toggleMissingNumbers(oBrowse, "Kunden", "KundNr",;
        "KurzName", "Name", {10, 50}, oGet, cProg) }, " @STRG-N@=Freie Nummern" } }
    endif
    open("Kunden")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "KdOut(KundNr)" , "Nummer" )
    felderAlt( "KurzName" , )
    felderAlt( "Name" , )
    felderAlt( "Partner" , )
    felderAlt( "Strasse" , "Stra�e" )
    felderAlt( "Zusatz" ,)
    felderAlt( "Land+space(1)+Plz+space(1)+Ort","Ort" )
    felderAlt( "array2readable(getKundSpeditKdNrs(KUNDEN->KundNr))" , "Sped./UPS-Nr" , 30)
    felderAlt( "IdentNr" )

    /*** Kunden ***/
  CASE upper(cProg)=="BANK,KUNDEN"
    /** Standard-Kunden-Hilfe */
    hilfdef(oBrowse,getNew(,,,"KundNr","Bank"))

    /** gebe KundNr in LieferanteNr-Style zurueck */
    M->Return_Feld:="left(KUNDEN->KundNr,len(LIEFERAN->LiefNr))"

    /*** MengenEinheit    ***/
  CASE "ME" == upper(oGet:Name) .or. "ARTIKEL->ME2" == upper(oGet:Name) .or. "ME2" == upper(oGet:Name) .or.;
    "INHALTME" $ upper(oGet:Name) .or. ;
    "->ME" == right(upper(oGet:Name),4) .or. "->XME" == right(upper(oGet:Name),5)
    open("Einheit")
    oBrowse:nTop:=7
    oBrowse:nBottom:=20
    oBrowse:nLeft:=26
    oBrowse:nRight:=62

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "ME" , "Nr" )
    felderAlt( "Text" , "Einheit")
    felderAlt( "Kommentar" ,"Bez." )
    felderAlt( "NachKomma" ,"Nachkommast." )

    /*** innerbetr. Auftrags-Posten , alle ***/
  CASE ( "INLFDNR" $ upper(oGet:Name) .and. alias()<>"SYSTEM" ) .or. ;
    ""INNERAUF"$ upper(oGet:Name) .or. cProg=="INNERAUF" .or. "XINNERNR" $ upper(oGet:Name)
    open("Inner")

    #define MY_INNER_FARBE ;
      { || iif(cProg=="INNER-AUFTR�GE AUSWAHL",NIL, ;
      iif(INNER->Erledigt=="J",GRAY_ON_WHITE, ;
      iif(! INNER->Gedruckt $ "JA",RED_ON_WHITE, NIL ) ) ) }

    // oBrowse:nLeft:=05
    // oBrowse:nRight:=73

    if ! "INLFDNR" $ upper(oGet:Name) // aus aend.prg
      M->Return_Feld:="INNER->InnerNr"
    endif

    if ! "XINNERNR" $ upper(oGet:Name) // aus aend.prg
      M->suchShiftRight:=.t.
    endif

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F4 , nil , nil }) // F4 gesperrt

    /* Spalten-Definition */
    if "INLFDNR" $ upper(oGet:Name) // nicht aus aend.prg
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="InLfdNr"
      oColumn[COL_TITEL]:="Lfd.Nr."
      oColumn[COL_FARBE]:=MY_INNER_FARBE
      addMyColumn ( oColumn )
    endif

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="InnerNr"
    oColumn[COL_TITEL]:="Mappe"
    oColumn[COL_FARBE]:=MY_INNER_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="out(artnr)"
    oColumn[COL_TITEL]:="Art.Nr."
    oColumn[COL_FARBE]:=MY_INNER_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez1"
    oColumn[COL_TITEL]:="Bezeichnug"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="AB"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Menge"
    oColumn[COL_TITEL]:="Menge"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="transform(Menge-GeliefGes,'999999.99')"
    oColumn[COL_TITEL]:="Rest"
    oColumn[COL_FARBE]:=COL_NUMERISCH
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="GeliefGes"
    oColumn[COL_TITEL]:="Prod."
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Ausschuss"
    oColumn[COL_TITEL]:="davon Ausschuss"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Aufdat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Lief_kw"
    oColumn[COL_TITEL]:="Lief.KW"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Fert_kw"
    oColumn[COL_TITEL]:="Fert.KW"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MengeAB"
    oColumn[COL_TITEL]:="Menge AB"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Erledigt"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Grund"
    oColumn[COL_FARBE]:=MY_INNER_FARBE

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="InLfdNr"
    oColumn[COL_TITEL]:="Lfd.Nr."
    oColumn[COL_FARBE]:=MY_INNER_FARBE
    addMyColumn ( oColumn )

    /*** innerbetr. Auftrags-Posten , alle Arbeitsg�nge***/
  CASE "MINNERNR" $ upper(oGet:Name)
    open("Inner")
    INNER->(OrdSetFocus(7)) // InnerNr + ArbGang, nur offenen

    #define MY_INNER_FARBE2 { || iif(empty(INNER->NkNr),NIL,GRAY_ON_WHITE)}

    // oBrowse:nLeft:=05
    // oBrowse:nRight:=73

    M->suchShiftRight:=.t.

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F4 , nil , nil }) // F4 gesperrt

    M->Return_Feld:="dispInnerNr(InnerNr,ArbGang)"

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="dispInnerNr(InnerNr,ArbGang)"
    oColumn[COL_TITEL]:="Mappe"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2
    oColumn[COL_BREITE]:=5
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="out(artnr)"
    oColumn[COL_TITEL]:="Art.Nr."
    oColumn[COL_FARBE]:=MY_INNER_FARBE2
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez1"
    oColumn[COL_TITEL]:="Bezeichnug"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AufNr"
    oColumn[COL_TITEL]:="AB"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Menge"
    oColumn[COL_TITEL]:="Menge"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="transform(Menge-GeliefGes,'999999.99')"
    oColumn[COL_TITEL]:="Rest"
    oColumn[COL_FARBE]:=COL_NUMERISCH
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="GeliefGes"
    oColumn[COL_TITEL]:="Prod."
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Ausschuss"
    oColumn[COL_TITEL]:="davon Ausschuss"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Aufdat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Lief_kw"
    oColumn[COL_TITEL]:="Lief.KW"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Fert_kw"
    oColumn[COL_TITEL]:="Fert.KW"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MengeAB"
    oColumn[COL_TITEL]:="Menge AB"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Erledigt"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Grund"
    oColumn[COL_FARBE]:=MY_INNER_FARBE2

    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="InLfdNr"
    oColumn[COL_TITEL]:="Lfd.Nr."
    oColumn[COL_FARBE]:=MY_INNER_FARBE2
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:='if(empty(INNER->NKNr),"N","J")'
    oColumn[COL_TITEL]:="Nachkalk."
    oColumn[COL_FARBE]:=MY_INNER_FARBE2
    addMyColumn ( oColumn )



    /*** innerbetr. Auftrags-Posten , nur gleiche Artikel ***/
    // Hinweis: muss nach obigem XINNERNr kommen
  CASE ("INNERNR"$ upper(oGet:Name) .and. alias()<>"SYSTEM")

    open("Inner")
    INNER->(OrdSetFocus(2)) // artnr+innernr
    // oBrowse:nLeft:=05
    // oBrowse:nRight:=73

    M->Return_Feld:="INNER->InnerNr"
    M->suchShiftRight:=.t.


    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F4 , nil , nil }) // F4 gesperrt

    /* Filter */
    // oBrowse:cargo:={ || ARTIKEL->Artnr==INNER->ArtNr }
    index on INNER->ArtNr+INNER->InnerNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      ARTIKEL->Artnr==INNER->ArtNr .and. INNER->Erledigt<>'J' .and. isInnerHauptArbeitsgang()

    // // go top
    // oBrowse:GoTopBlock:={ || dbseek(ARTIKEL->ArtNr) }

    // // go bottom
    // oBrowse:GoBottomBlock:={ || dbseek(next( ARTIKEL->ArtNr ) ,.t.) , if(SkipBack(.t.),NIL,oBrowse:goTop()) }

    // // such-Text initialisieren
    // SuchText( ARTIKEL->ArtNr )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt. ,numerisch  */
    // (nur aus Komp.gr�nden)
    felderAlt( "InnerNr" , "Auf.Nr" )
    felderAlt( "AufDat", "Datum")
    felderAlt( "ArtNr" , "Art.Nr" )
    felderAlt( "Menge" , "Menge")
    felderAlt( "GeliefGes" , "Prod." , , .f. )
    felderAlt( "Ausschuss" , "davon Ausschuss")
    felderAlt( "transform(Menge-GeliefGes,'999999.99')" , "Rest" , 9 , .f. ,, .t. )
    felderAlt( "Lief_kw" , "Lief.KW." , , .f. )
    felderAlt( "Fert_kw" , "Fert.KW." , , .f. )
    felderAlt( "AufNr" , "AB" )
    felderAlt( "MengeAB" , "Menge AB")
    felderAlt( "erledigt")
    felderAlt( "InlfdNr" , "lfd.Nr" )

    /*** ausserbetr. Auftrags-Posten , nur gleiche Artikel ***/
  CASE "AUSSERNR"$ upper(oGet:Name)
    open("BesPost")
    oBrowse:nLeft:=00
    oBrowse:nRight:=80

    if getUser():id==KURZEL_MAIN_CUSTOMER .or. getUser():id==KURZEL_DEVEL
      M->SpecialHilfe:={}
      aadd(M->SpecialHilfe,{K_F5 , { || alleBesPost() }, " @F5@=Alle anzeigen" })
    endif

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt. ,numerisch  */
    // (nur aus Komp.gr�nden)
    felderAlt( "BestNr" , "Best." )
    felderAlt( "AufDat", "Datum")
    felderAlt( "LiefNr", "Lief.")
    felderAlt( "left(LIEFERAN->KurzName,20)" , "Name", )
    felderAlt( "Menge" , "Menge")
    felderAlt( "GeliefGes" , "Gelief." , , .f. )
    felderAlt( "transform(Menge-GeliefGes,'99999.99')" , "Rest" , 9 , .f. ,, .t. )
    felderAlt( "KW" )
    // felderAlt( "EINHEIT->Text","ME")


    /*** Rabattgruppen ***/
  CASE "RABATTGR" $ upper(oGet:Name)
    open("Rabatt")

    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    else
      M->SpecialHilfe:={ }
    endif
    aadd( M->SpecialHilfe , { K_F5 , { || ABPostListe() } , " @F5@=in AB/Angebot" } )
    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelWertListe() } , " @F6@=in Artikel" } )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "RabattGr" , "Gruppe" )
    felderAlt( "Meng1" , "Menge" )
    felderAlt( "Rab1" , "Rab." )
    felderAlt( "Preis1" , "Preis" )
    felderAlt( "Meng2" , "Menge" )
    felderAlt( "Rab2" , "Rab." )
    felderAlt( "Preis2" , "Preis" )
    felderAlt( "Meng3" , "Menge" )
    felderAlt( "Rab3" , "Rab." )
    felderAlt( "Preis3" , "Preis" )
    felderAlt( "Meng4" , "Menge" )
    felderAlt( "Rab4" , "Rab." )
    felderAlt( "Preis4" , "Preis" )
    felderAlt( "Meng5" , "Menge" )
    felderAlt( "Rab5" , "Rab." )
    felderAlt( "Preis5" , "Preis" )
    felderAlt( "Meng6" , "Menge" )
    felderAlt( "Rab6" , "Rab." )
    felderAlt( "Preis6" , "Preis" )
    felderAlt( "Meng7" , "Menge" )
    felderAlt( "Rab7" , "Rab." )
    felderAlt( "Preis7" , "Preis" )
    felderAlt( "Meng8" , "Menge" )
    felderAlt( "Rab8" , "Rab." )
    felderAlt( "Preis8" , "Preis" )
    felderAlt( "Meng9" , "Menge" )
    felderAlt( "Rab9" , "Rab." )
    felderAlt( "Preis9" , "Preis" )

    /*** Verk�ufer ***/
  CASE "VERKNR" $ upper(oGet:Name) .or. "VERTRET" $ upper(oGet:Name)
    open("Verkauf")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "VerkNr" , "Nummer" )
    felderAlt( "Text" , "Name" )
    felderAlt( "Adr1" , "Adresse")
    felderAlt( "Adr2" , "Adresse")
    felderAlt( "Konto" , "Konto" )
    felderAlt( "Mwst_Kz" , "Mwst_Kz")

    /*** Erl�sgruppe ***/
  CASE "ERL_GR" $ upper(oGet:Name)
    open("Erl_Grup")
    oBrowse:nLeft:=10
    oBrowse:nRight:=70

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelWertListe() } , " @F6@=in Artikel" } )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "Erl_gruppe" , "Nummer" )
    felderAlt( "Inland" , )
    felderAlt( "Eg" , )
    felderAlt( "Sonst" , )
    felderAlt( "Text" , )

    /*** Liefertermine ***/
  CASE "KW" == upper(oGet:Name) .or. "->KW" == right(upper(oGet:Name),4) .or. ;
    "->XKW" == right(upper(oGet:Name),5) .or. upper(oget:name) $ "KW1/KW2/KW3/KW4/KW5"
    open("LiefTerm")
    oBrowse:nLeft:=10
    oBrowse:nRight:=70

    M->SpecialHilfe:={ { K_F6 , { || ABPostListe() } , " @F6@=in AB/Angebot" } }

    // such-text initialisieren
    // suchtext( "X" )

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "KW" , "Nummer" )
    felderAlt( "Text" , )

    /*** Speditionsauswahl je Kunde -> muss vor der regl. Sped.Auswahl stehen ***/
  CASE "SPEDAUSWAHL" $ upper(cProg)

    open("KundSped","Spedit")
    select KundSped
    set rela to KUNDSPED->Spednr into Spedit

    if "ANGEBOT" $ upper(cProg)
      index on KUNDSPED->KundNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        KUNDSPED->KundNr == ANGAUS->V_KundNr
    else
      index on KUNDSPED->KundNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        KUNDSPED->KundNr == AUFAUS->V_KundNr
    endif

    M->Return_Feld:="KUNDSPED->SpedNr"

    oBrowse:nTop:=10
    oBrowse:nBottom:=16

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="SpedNr"
    oColumn[COL_TITEL]:="Sped.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="SPEDIT->KurzName"
    oColumn[COL_TITEL]:="Name"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Art"
    oColumn[COL_TITEL]:="Art"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bemerk1"
    oColumn[COL_TITEL]:="Bemerk1"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Frei"
    oColumn[COL_TITEL]:="Frei"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="SpedKdNr"
    oColumn[COL_TITEL]:="Kd.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="VK"
    oColumn[COL_TITEL]:="Pauschale"
    addMyColumn ( oColumn )

    /*** Spedition ***/
  CASE "SPEDNR" $ upper(oGet:Name)
    open("Spedit")
    oBrowse:nLeft:=2
    oBrowse:nRight:=78

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "SpedNr" , "Nr." )
    felderAlt( "KurzName" , )
    felderAlt( "Name" , )
    felderAlt( "Name2" , )
    felderAlt( "Land" , )
    felderAlt( "PLZ" , )
    felderAlt( "Ort" , )
    felderAlt( "Telefon" , )
    felderAlt( "SpedKZ" , )

    /*** Liste     ***/
  CASE "LISTE_KURZ" $ upper(oGet:Name) .and. alias()=="FENSTER"
    open("Fenster")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "Liste_Kurz" , "Liste" )
    felderAlt( "Kurzel" , "Benutzer" )


    /*** Liste     ***/
  CASE "LISTE_KURZ" $ upper(oGet:Name)
    open("Liste")
    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "Liste_Kurz" , "Liste" )
    felderAlt( "Bez" , "Bezeichnung")
    // felderAlt( "Rechner" , "Rechner", , .f.)
    felderAlt( "DruckerNr" , "Drucker", , .f.)


    /*** Drucker ***/
  CASE "DRUCKERNR" $ upper(oGet:Name)
    open("Drucker")

    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "DruckerNr" , "Nr." )
    felderAlt( "Bez" , "Bezeichnung" )
    felderAlt( "Queue" , "Queue" )
    // felderAlt( "Rechner" , "Rechner" )
    // felderAlt( "Lokal" , "Lokal", , .f.)

    /*** Etikett  (repa)  ***/
  CASE "ETIKETTNR" $ upper(oGet:Name)
    open("Etikett")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "EtikettNr" , "Nr" )
    felderAlt( "alltrim(trim(eti1)+' '+trim(eti2)+' '+trim(eti3)+' '+trim(eti4))" , "Text" , 60 ,;
      .f. )

    /*** Etikett  (repa)  ***/
  CASE "ETIREPANR" $ upper(oGet:Name)
    open("EtiRepa")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "out(EtiRepaNr)" , "Art.Nr." )
    felderAlt( "alltrim(trim(eti1)+' '+trim(eti2)+' '+trim(eti3)+' '+trim(eti4))" , "Text" , 60 ,;
      .f. )

    /*** Empf�nger (repa)  ***/
  CASE "EMPFNR" $ upper(oGet:Name) .or. "EMPFAENG" $ upper(oGet:Name)
    open("Empfaeng")
    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "EmpfNr" , "Nr" )
    felderAlt( "Bez" , "Bezeichnung" )

    /*** Ger�te   (repa)  ***/
  CASE "REPGERNR" $ upper(oGet:Name) .or. "TYP" $ upper(oGet:Name)
    open("Gerat")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "RepGerNr" , "Nr" )
    felderAlt( "Bezeichn" , "Bezeichnung")
    felderAlt( "Artnr" , "Art.Nr." )
    felderAlt( "Status" , "Status" )

    /*** Repaus   (repa)  ***/
  CASE "BELEGNR" $ upper(oGet:Name) // .or. cProg=="KV_ANZEIG"
    open("RepAus")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "BelegNr" , "Rep.Nr." )
    felderAlt( "RepNr1" , "Kd-Rep.Nr.")
    felderAlt( "Typ" )
    felderAlt( "GeratNr" , "Ger�te Nr." )
    felderAlt( "if(REPAUS->Abrech$'UV',REPAUS->Abrech+' ',if(REPAUS->dr_stat$'FG',if(REPAUS->dr_stat=='F','KV','FR'),REPAUS->dr_stat+space(1)))", "Gedr." )
    felderAlt( "Eingang" ,"Eingang", , , , ,{ || iif( empty(REPAUS->Ruckliefer).and.;
      !empty(REPAUS->Eingang), { 7, 8 }, { 5, 6 } ) })
    felderAlt( "Ruckliefer", "R�ck.Dat.")
    felderAlt( "LiefDat1")
    felderAlt( "RepKdNr" , "Kd.Nr." )
    felderAlt( "KundBez" , "Kunde" )
    felderAlt( "GeratBez" , "Ger�t" )
    felderAlt( "out(REPAUS->Artnr)" , "Art.Nr.")

    /*** Kosten   (repa)  ***/
  CASE "REPKSTNR" $ upper(oGet:Name) .or. "ABRECH" $ upper(oGet:Name)
    open("Kosten")
    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    /* suchtext initialisieren (leer !) */
    SuchText()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "RepKstNr" , "Nr" )
    felderAlt( "Text" )
    felderAlt( "Pauschal","Pauschale")

    /*** Rep.Kunden (repa)  ***/
  CASE "REPKDNR" $ upper(oGet:Name) .or. "VERSKDNR" $ upper(oGet:Name)
    if getUser():mayEditData
      M->SpecialHilfe:={ TEXT_EDIT }
    endif
    open("RepKund")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "RepKdNr" , "Kd.Nr." )
    felderAlt( "Kurz" , "Kurzname")
    felderAlt( "Standort" , )
    felderAlt( "Adr4" , "Adresse")
    felderAlt( "Adr1" , "Adresse")
    felderAlt( "Adr2" , "Adresse")
    felderAlt( "Adr3" , "Adresse")
    felderAlt( "Adr4" , "Adresse")

    /*** Rep.Stamm (neu)  ***/
  CASE ("REPSTNR" $ upper(oGet:Name) .or. "NEUNR" $ upper(oGet:Name))
    open("Repstamm")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "RepStNr" , "Nr." )
    felderAlt( "Text" , "Text" )


    /*** Bemerkungen      ***/
  CASE "KD_BEM" $ upper(oGet:Name)
    open("Kd_Bemer")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "Kd_Bem_Nr" , "Nr." )
    felderAlt( "Text" , "Text" )

    /*** Bemerkung (repa)  ***/
  CASE "BEMERKNR" $ upper(oGet:Name)
    oBrowse:nLeft:=0
    oBrowse:nRight:=80
    open("Beurteil")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "BemerkNr" , "Nr." )
    felderAlt( "memotran(BEURTEIL->Text,' ',' ')" , "Text" ,75 )
    felderAlt( "substr(memotran(BEURTEIL->Text,' ',' '),75)" , "Text" ,75 )

    /*** Produktion (repa)  ***/
  CASE "GERATNR" $ upper(oGet:Name)
    open("Prod")

    /* checken ob Gerat ge�ffnet */
    if select("Gerat") <= 0
      Error("Typ noch nicht selektiert !"+SCHWERER_FEHLER)
      M->okay:=.t.
    endif

    /* Filter, nur selber Typ , wie in Gerat */
    // oBrowse:cargo:={ || GERAT->RepGerNr==PROD->Typ }
    index on PROD->GeratNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      GERAT->RepGerNr==PROD->Typ

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "GeratNr" , "Ger.Nr." )
    felderAlt( "RepKdNr" , "KdNr." )
    felderAlt( "Liefdat" , "Lief.Dat." )
    felderAlt( "Status" , "St" )
    felderAlt( "Empfaeng" , "Empf." )
    felderAlt( "AnzRep" , "Anz." )
    felderAlt( "RepDat" , "Rep.Dat." )
    felderAlt( "ArtNr" , "Art.Nr." )
    felderAlt( "Bezeichn" , "Bezeichnung" )
    felderAlt( "Typ" , "Typ" )

    /*** Produktion-Text (repa)  ***/
  CASE "PRODTEXTNR" $ upper(oGet:Name)
    open("ProdText")

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "ProdTextNr" , "Nr." )
    felderAlt( "memotran(PRODTEXT->Text,' ',' ')" , "Text" ,75 )
    felderAlt( "substr(memotran(PRODTEXT->Text,' ',' '),75)" , "Text" ,75 )

    /*** Produktion (repa) , nur Gerate selben Typs mit unterschiedl. ArtNr  ***/
  CASE "REPARTIKEL" $ upper(oGet:Name)
    open("Prod")
    PROD->(OrdSetFocus(4))
    set relation to PROD->ArtNr into Artikel

    oBrowse:nTop:=6
    oBrowse:nBottom:=22

    M->Return_Feld:="PROD->ArtNr" // gebe Art.Nr. zur�ck

    /* checken ob Gerat ge�ffnet */
    if select("Gerat") <= 0
      Error("Typ noch nicht selektiert !"+SCHWERER_FEHLER)
      M->okay:=.t.
    endif

    /* Filter, nur selber Typ , wie in Gerat */
    // oBrowse:cargo:={ || GERAT->RepGerNr==PROD->Typ }
    index on PROD->GeratNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      GERAT->RepGerNr==PROD->Typ

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "GeratNr" , "Ger.Nr." )
    felderAlt( "Out(PROD->ArtNr)" , "Art.Nr." )
    felderAlt( "ARTIKEL->Bez1" , "Bezeichnung" ,,.t.)
    felderAlt( "getArtikelArt()" , "Art" )
    felderAlt( "ARTIKEL->LageBest" , "LagerBestand")
    felderAlt( "getArtikelLagerOrt(20)" , "Lager-Ort")
    felderAlt( "ARTIKEL->Preis1" , "VK")
    felderAlt( "ARTIKEL->Bez2" , "Bezeichnung 2" ,,.t.)


    /*** Artikel < FRACHT_LAENGE  ***/
  CASE "FRACHT" $ upper(oGet:Name)
    open("Artikel")
    // endif

    /* Filter, nur Auftr�ge des sel. Kunden ! */
    // oBrowse:cargo:={ || len(alltrim(ARTIKEL->ArtNr)) <= FRACHT_LAENGE }
    index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      len(alltrim(ARTIKEL->ArtNr)) <= FRACHT_LAENGE

    // go bottom
    // oBrowse:GoBottomBlock:={ || Fracht_Post_Bottom() }

    oBrowse:gotop()

    oBrowse:nLeft:=2
    oBrowse:nRight:=78
    oBrowse:nTop:=2

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Out(ArtNr)"
    oColumn[COL_TITEL]:="Art.Nr."
    addMyColumn ( oColumn )

    // ACHTUNG: "Bezeichnung" muss 2. Spalte sein (s. addEnglColumn())
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez1"
    oColumn[COL_TITEL]:="Bezeichnung"
    oColumn[COL_SECOND_LINE]:="Bez2"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="WKZ"
    oColumn[COL_TITEL]:=""
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LageBest"
    oColumn[COL_TITEL]:="Lg-Best."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LG_Raum+'.'+LG_Regal+'.'+Lg_Fach"
    oColumn[COL_TITEL]:="Raum.Regal.Fach"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LG_Text"
    oColumn[COL_TITEL]:="Lg Text"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(Preis1,7,2)"
    oColumn[COL_TITEL]:="     VK"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="AltArtNr"
    oColumn[COL_TITEL]:="Alte Nr."
    addMyColumn ( oColumn )

    // /* Spalten-Definition */
    // /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // // (nur aus Komp.gr�nden)
    // felderAlt( "Out(ArtNr)" , "Art.Nr." )
    // felderAlt( "Bez1" , "Bezeichnung" ,,.t.)
    // felderAlt( "Wkz" , " ")
    // felderAlt( "LageBest" , "Lg-Best.")
    // felderAlt( "LagerOrt" , "Lager-Ort")
    // felderAlt( "Preis1" , "VK")
    // felderAlt( "Bez2" , "Bezeichnung 2" ,,.t.)


    /*** Mehrfachspritzung Gruppen Auswahl ***/
  CASE (cProg=="MEHRFACHSPRITZUNG-GRUPPEN")
    open("Artikel", "Mehrfach","Einheit")

    // memory Variable needed for temp index below
    M->werkzeug:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getFirstWerkzeug()

    select Artikel
    set relation to ARTIKEL->ME into Einheit

    select Mehrfach
    set rela to MEHRFACH->ANr into Artikel

    index on MEHRFACH->Gruppe+MEHRFACH->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      MEHRFACH->ArtNr==M->werkzeug
    M->postFunction:={|| MEHRFACH->(OrdDestroy( TEMP_INDEX )) }

    oBrowse:gotop()

    oBrowse:nLeft:=2
    oBrowse:nRight:=78
    oBrowse:nTop:=6

    M->Return_Feld:="NIL"

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Out(ARTIKEL->ArtNr)"
    oColumn[COL_TITEL]:="Art.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ARTIKEL->Bez1"
    oColumn[COL_TITEL]:="Bezeichnung"
    oColumn[COL_SECOND_LINE]:="ARTIKEL->Bez2"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="EINHEIT->Text"
    oColumn[COL_TITEL]:="ME"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MEHRFACH->Menge"
    oColumn[COL_TITEL]:="Menge"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(MEHRFACH->Nutzen1,2)+'/'+str(MEHRFACH->Nutzen2,2)"
    oColumn[COL_TITEL]:="Ma.Nutzen"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="MEHRFACH->Gruppe"
    oColumn[COL_TITEL]:="Gruppe"
    addMyColumn ( oColumn )

    /*** AV: Kalkulations-�bersicht (neu 2019), Nachkalkulation ***/
  CASE (cProg=="AV_KALK: KALK-UEBER" .or. cProg=="AV_KALK2: KALK-UEBER")

    if getUser():mayCreateInnerOrders .and. getUser():mayEditData
      M->SpecialHilfe:={ ;
        { "aA" , { |oBrowse| NK_Satz_ausfall(oBrowse) } ," @A@usfall." } ,;
        { "kK" , { || NK_kopieren() } ," @K@op." } ,;
        { "lL" , { |oBrowse| NK_Satz_loeschen(oBrowse) } ," @L@�sch" } ,;
        { "vV" , { |oBrowse| nkSum(oBrowse, .t.) } ," @V@orgaben" } ,;
        { K_F4 , { |oBrowse| nkBrowseEdit(oBrowse) } ," @F4@=�ndern" } }
    else
      M->SpecialHilfe:={}
    endif

    // keine R�ckgabe
    M->Return_Feld:="NIL"
    oBrowse:nLeft:=0
    oBrowse:nRight:=80
    oBrowse:nTop:=4
    oBrowse:nBottom:=18

    open("NkArtikel","NKPost","Personal","NKZeit","Maschine","Einheit")

    select Artikel
    set rela to ARTIKEL->ME into Einheit
    select NKPost
    set rela to NKPOST->NKNr+ARTIKEL->ArtNr into NkArtikel,;
      to NKPOST->PersNr into Personal,;
      to NKPOST->MaschNr into Maschine

    filterMaschGroup(oBrowse)

    // gehe auf ersten Satz
    oBrowse:goTop()

    aktRec:=EINHEIT->(recno())
    EINHEIT->(dbseek(NKPOST->ME))
    tempVal:=EINHEIT->Text
    EINHEIT->(dbgoTo(aktRec))
    if empty(tempVal)
      tempVal:="Mat"
    endif

    /* Summe anzeigen */
    NKSum(oBrowse)

    // ** Spalten-Definition
    /*   oBrowse,        Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt. , numerisch, Farbe   */
    FelderAlt( "MaschNr" , "Ma." ,3, .f. ,,,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) })
    FelderAlt( "PersNr" , "PNr." ,3, .f. ,,,{ || iif( len(trim(NKPOST->PersNr))>3, RED_ON_WHITE,;
      iif( NKPOST->Ausfall=="J", { 7, 8 }, )) })
    FelderAlt( "PERSONAL->Kurzel" , "" ,2, .f. ,,,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) })
    FelderAlt( "Datum" , "Datum" , , , , ,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) })
    FelderAlt( "str(kalkRuestzeit(RuestZeit),5,2)", "R�stz." , , , , ,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) } )
    FelderAlt( "str(kalkNutzen(GutMenge),7,0)" , "  Menge" , , , , ,{ || iif( NKPOST->Ausfall=="J";
      , { 7, 8 }, ) })
    FelderAlt( "str(getNKStkStd(),8,2)" , " "+EINHEIT->Text+;
      "/Std" ,, .t. ,,,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) } )
    if left(ARTIKEL->ArtNr,1) $ "3"
      FelderAlt( "str(kalkMatStk(MatZug),7,3)", right("  "+alltrim(tempVal),3)+"/"+;
        EINHEIT->Text, , , , ,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) } )
    endif
    FelderAlt( "str(kalkNutzen(Ausschuss),7,0)", "Ausschu�" , , , , ,{ || iif( NKPOST->Ausfall=="J", { 7, 8 }, ) } )
    FelderAlt( "if(GutMenge=0,space(6),str(100*Ausschuss/GutMenge,6,2))", "   %",6 ,,,,{ || iif(;
      NKPOST->Ausfall=="J", { 7, 8 }, ) } )
    FelderAlt( "str(getZeitMitNutzen(),5,2)", "Zeit" , , , , ,{ || iif( NKPOST->Ausfall=="J", { 7,;
      8 }, ) } )
    if DEVEL_PROG
      FelderAlt( "Ausfall", "Ausfall" )
    endif


  CASE "MASCHINE->STATUS" == upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],1)"

    M->aArray:={ "  - Aktiv", "X - Verschrottet" }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

    /*** Status   (repa)  ***/
  CASE "STATUS" $ upper(oGet:Name) .or. "STAT_ART" $ upper(oGet:Name)
    open("Status")

    if "STAT_ART" $ upper(oGet:Name)
      M->Return_Feld:="STATUS->ArtNr" // gebe Art.Nr. zur�ck
    else
      if select("Artikel") > 0
        /* Filter, nur selbe ArtNr*/
        // oBrowse:cargo:={ || subRepArtikel(ARTIKEL->ArtNr)==subRepArtikel(STATUS->ArtNr)}
        index on STATUS->Status tag TEMP_INDEX TEMPORARY ADDITIVE for ;
          subRepArtikel(ARTIKEL->ArtNr)== subRepArtikel(STATUS->ArtNr)

        // // go top
        // oBrowse:GoTopBlock:={ || dbseek(subRepArtikel(ARTIKEL->ArtNr)) }

        // // go bottom
        // oBrowse:GoBottomBlock:={ || dbseek(next(subRepArtikel(ARTIKEL->ArtNr)),.t.),;
        // if(SkipBack(.t.),NIL,oBrowse:goTop()) }

        // // such-text initialisieren
        // suchtext( subRepArtikel(ARTIKEL->ArtNr) )
      endif
    endif


    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    // felderAlt( "Typ" )
    felderAlt( "ArtNr","Art.Nr." )
    felderAlt( "Status")
    felderAlt( "Bez1" , "Bezeichnung")
    felderAlt( "Bez2" , "Bezeichnung")

    /*** Versand (repa)  ***/
  CASE "REPVERNR" $ upper(oGet:Name)
    open("Versand")
    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    SuchText()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "RepVerNr" , "Nr." )
    felderAlt( "Text" , "Text" )

    /*** Login           ***/
  CASE "KURZEL" $ upper(oGet:Name) .or. "REPKURZ" $ upper(oGet:Name) ;
    .or. "MITARB" $ upper(oGet:Name)
    open("Login")
    oBrowse:nTop:=3
    oBrowse:nLeft:=2
    oBrowse:nRight:=78

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "Kurzel" , "K�rzel" )
    felderAlt( "Name" )
    felderAlt( "StammDat" ,"DSVGO" )
    felderAlt( "Fakt" )
    felderAlt( "Bank" )
    felderAlt( "Drucken" )
    felderAlt( "StammDat" )
    felderAlt( "SysMenu" )
    felderAlt( "ArtLagBest" )
    felderAlt( "EK_Aend" )
    felderAlt( "VK_Aend" )
    felderAlt( "Werkzeug" )
    felderAlt( "MatEinAusg" )
    felderAlt( "Etikett" )
    felderAlt( "Stk_Mat" )
    felderAlt( "Stk_Wkz" )
    felderAlt( "Stk_Ins" )
    felderAlt( "Stk_Zeit" )
    felderAlt( "NurAusk" )
    felderAlt( "ArtikelAnl" ,"Art.anlegen" )
    felderAlt( "ArtikelArt" ,"Artikel-Art �ndern" )

    /*** Personal        ***/
  CASE "PERSNR" $ upper(oGet:Name) .or. "PERSNRS" $ upper(oGet:Name) .or. "M->PERS"== upper(oGet:Name)
    open("Personal")
    oBrowse:nLeft:=6
    oBrowse:nRight:=74

    if "PERSNRS" $ upper(oGet:Name)
      M->clearBuffer:=.f. // don't clear buffer upon selection
    endif

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "PersNr" , "Pers.Nr.")
    felderAlt( "Kurzel" , "K�rzel")
    felderAlt( "Name" )
    felderAlt( "StdLohn","Std.Lohn")
    felderAlt( "Kostenst","Kst.St.")

    // /*** Letzte Stelle   ***/
    // CASE "LETZTEST" $ upper(oGet:Name)
    // open("LetzteSt")
    // oBrowse:nLeft:=10
    // oBrowse:nRight:=70

    // /* Spalten-Definition */
    // /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // // (nur aus Komp.gr�nden)
    // felderAlt( "LetzteSt" , "Letzte St.")
    // felderAlt( "Text" )

    /*** Letzte Stelle   ***/
  CASE "LETZTENI" $ upper(oGet:Name)
    open("LetzteNi")
    oBrowse:nLeft:=10
    oBrowse:nRight:=70

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "LetzteNi" , "Letzte St.")
    felderAlt( "Text" )

    /*** Vers_Eti **/
  CASE "VERSANDNR" $ upper(oGet:Name)
    open("Vers_Eti")

    /* suchtext initialisieren (leer !) */
    SuchText()

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "VersandNr" , "Nr" )
    felderAlt( "trim(Text1)+' '+trim(Text2)" , "Text" , 60 , .f. )
    felderAlt( "trim(Text2)+' '+trim(Text3)" , "Text" , 60 , .f. )

    /*** Werbeung (Fakt)  ***/
  CASE "KDNR_WERB" $ upper(oGet:Name)
    open("Werbung","Kunden")
    select Werbung

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "KdNr_Werb" , "Nr." )
    felderAlt( "Vertreter" )
    felderAlt( "KurzName" ,"Kunde")
    felderAlt( "trim(Adr1)+' '+trim(Adr4)" , "Adresse" ,60 , .f. )
    felderAlt( "trim(Adr2)+' '+trim(Adr3)" , "Adresse", 60 , .f. )

    /*** Mehrwertsteuer ***/
  CASE "MWSTNR" $ upper(oGet:Name) .or. "MWST_KZ" $ upper(oGet:Name)
    open("Mwst_Kz")
    oBrowse:nTop:=10
    oBrowse:nBottom:=20
    oBrowse:nLeft:=30
    oBrowse:nRight:=60

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "MwstNr" , "Nr" )
    felderAlt( "Mwst" , "MwSt" )


    /*** Banken */
  CASE "BLZ" $ upper(oGet:Name) .or. cProg="BLZ IMPORT"
    open("BankStam")
    oBrowse:nLeft:=2
    oBrowse:nRight:=78

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "Blz")
    felderAlt( "left(BankBez,42)" , "Name" )
    felderAlt( "BIC" )
    felderAlt( "Land")

    // /*** Banken */
  CASE "BIC" $ upper(oGet:Name)
    open("BankStam")
    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    // FIXME: toggle Focus geht hier schief
    BANKSTAM->(OrdSetFocus(3))
    // sortByColumn(1)
    M->Return_Feld:="BANKSTAM->BIC"

    // definiere Spezial-Funktion bei Abruf-Auftragsnr, da in der gleichen Datei referenziert wird
    M->keepPosition:=.t.

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "BIC" )
    felderAlt( "Blz")
    felderAlt( "left(BankBez,42)" , "Name" )
    felderAlt( "Land")

    /*** HausBanken */
  CASE "BANKNR" $ upper(oGet:Name)
    open("HausBank","BankStam")
    select Hausbank
    set rela to HAUSBANK->Blz into BankStam

    oBrowse:nLeft:=5
    oBrowse:nRight:=75

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    felderAlt( "BankNr" , "Nr")
    felderAlt( "left(BANKSTAM->BankBez,40)" , "Name" )
    felderAlt( "Blz" )
    felderAlt( "Ktonr" , "KontoNr." )
    felderAlt( "AufGeb" , "Auft.geb." )

    /*** KonsignationsLieferschein ***/
  CASE "KONSIGLSNR" $ upper(oGet:Name)
    open("Konsig")

    M->Return_Feld:="KONSIG->LiefNr"

    /* Filter, nur Auftr�ge des sel. Kunden ! */
    // oBrowse:cargo:={ || ! (alltrim(KONSIG->ArtNr) $ "$*")}


    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "LiefNr" , "LS-Nr" )
    felderAlt( "AufNr" , "Auftrags-Nr" )
    felderAlt( "KundNr" , "Kunde")
    felderAlt( "LieDat" , "Datum")
    felderAlt( "ArtNr" , "Artikel")
    felderAlt( "Komm1" , "Bezeichnung")

  CASE cProg=="ArtPreis"
    open("ArtPreis","Artikel")
    select ArtPreis

    /* Filter, nur akt. Artikel ! */
    // oBrowse:cargo:={ || ARTIKEL->Artnr==ARTPREIS->ArtNr }
    index on ARTPREIS->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      ARTIKEL->Artnr==ARTPREIS->ArtNr

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Datum"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(EKPreis,9,2)"
    oColumn[COL_TITEL]:="       EK"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(KalkPreis,9,2)"
    oColumn[COL_TITEL]:="Kalk.Pr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(VKPreis,9,2)"
    oColumn[COL_TITEL]:="       VK"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="if(KalkPreis==0 .or. VKPreis==0,space(4),str(((VKPreis/KalkPreis)-1)*100,3,0)+'%')"
    oColumn[COL_TITEL]:="Auf."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Grund"
    oColumn[COL_TITEL]:="Grund"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(BeiEK,8,2)"
    oColumn[COL_TITEL]:=" Bei. EK"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(BeiKaPr,8,2)"
    oColumn[COL_TITEL]:="Bei. Ka."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurzel"
    oColumn[COL_TITEL]:="K�"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Art"
    addMyColumn ( oColumn )

  CASE cProg=="KundKontakt"
    oBrowse:nTop:=10
    oBrowse:nBottom:=20

    M->Return_Feld:=""

    open("KdKontakt","Kunden")
    select KdKontakt
    index on KdKontakt->KundNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      KDKONTAKT->KundNr $ AUFAUS->KundNr+"|"+AUFAUS->V_KundNr+"|"+AUFAUS->R_KundNr

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KundNr"
    oColumn[COL_TITEL]:="Kd.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Ansprech"
    oColumn[COL_TITEL]:="Ansprechpartner"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Email"
    oColumn[COL_TITEL]:="Email/Telefon/FAX"
    oColumn[COL_SECOND_LINE]:="trim(KDKONTAKT->Telefon)+if(!empty(KDKONTAKT->Fax),', '+trim(KDKONTAKT->Fax),'')"
    oColumn[COL_BREITE]:=28
    addMyColumn ( oColumn )

  CASE cProg=="TODO/NACHKALK"
    M->Return_Feld:="NIL"

    if getUser():mayEditData
      M->SpecialHilfe:={}
      aadd( M->SpecialHilfe , { K_SPACE, { || toggleTempSelection(.t.)}," @LEERTASE@=markieren"})
      aadd( M->SpecialHilfe , { K_F4 , nil, nil }) // disabled
      aadd( M->SpecialHilfe , { K_F5 , { || addEnglColumn(M->oBrowse) }, nil })
      aadd( M->SpecialHilfe , { K_F6 , { || MatArtikelListe() }, " @F5@=D"+chr(29)+"E @F6@=in "+;
        "St�ckl." })
    endif

    add_artikel_columns(oBrowse)

    // Farbe f�r Selection hinzuf�gen
    for i:=1 to oBrowse:colCount
      oColumn:=oBrowse:getcolumn(i)
      oColumn:colorBlock:={ || HIGHLIGHT_CUSTOM_SELECTED }
    next

  CASE cProg=="TODO/MATBEDARF"
    M->Return_Feld:="NIL"

    if getUser():mayEditData
      M->SpecialHilfe:={}
      aadd( M->SpecialHilfe , { K_SPACE, { || toggleTempSelection(.t.)}," @LEERTASE@=markieren"})
      aadd( M->SpecialHilfe , { K_F4 , nil, nil }) // disabled
      aadd( M->SpecialHilfe , { K_F5 , { || addEnglColumn(M->oBrowse) }, nil })
      aadd( M->SpecialHilfe , { K_F6 , { || MatArtikelListe() }, " @F5@=D"+chr(29)+"E @F6@=in "+;
        "St�ckl." })
    endif

    add_artikel_columns(oBrowse)

    // Farbe f�r Selection hinzuf�gen
    for i:=1 to oBrowse:colCount
      oColumn:=oBrowse:getcolumn(i)
      oColumn:colorBlock:={ || HIGHLIGHT_CUSTOM_SELECTED }
    next

  CASE "ARTIKEL->ART" == upper(oGet:Name) .or. "SELART" == upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=08
    oBrowse:nBottom:=18

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],1)"

    M->aArray:={ "B - Beistellteil","D - Dienstleistung","E - Einkauf-Artikel","F - "+;
      "Fertigungsartikel","M - Montage","T - Text","W - Werkzeug","X - Ex-Artikel" }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE "KDZOLLTEMP->ART" == upper(oGet:Name) .or. "ZOLLSTELLE->ART" == upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],1)"

    M->aArray:={ ;
      "B - Binnenschiff",;
      "E - Eisenbahn",;
      "L - Luft",;
      "S - Strasse",;
      "� - �berseeschiff",;
      }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE "KDSPEDTEMP->ART" == upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],2)"

    M->aArray:={ "   - Standard",;
      PAUSCHALE_KARTON + " - Pauschale Karton",;
      PAUSCHALE_PALETTE + " - Pauschale Palette" }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE "NKERF->ART" == upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],1)"

    M->aArray:={ "Z - Zeiten / Menge",;
      "M - Material",;
      "A - Artikel",;
      }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE "RETEXT" $ upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="trim(left(M->aArray[M->oBrowse:rowPos],at('-',M->aArray[M->oBrowse:rowPos])-1))+space(1)"
    M->confirm:=.f. // no return after selection, we stay in the same field
    M->clearBuffer:=.f. // don't clear buffer upon selection

    M->aArray:={ ;
      "|BETRAG|    - Gesamt-Betrag",;
      "|DATUM|     - F�lligkeitsdatum",;
      "",;
      "|SKTO_DAT|  - F�lligkeitsdatum Skontozeitraum",;
      "|SKTO_PROZ| - Skonto %",;
      "|SKTO_BETR| - Gesamt-Betrag abzgl. Skonto",;
      }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Platzhalter", ABlock(M->aArray))
    oColumn:width(30)
    oBrowse:addColumn( oColumn )

  CASE "EMAIL->ART" == upper(oGet:Name)
    oBrowse:nLeft:=28
    oBrowse:nRight:=74
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->Return_Feld:="trim(left(M->aArray[M->oBrowse:rowPos],at('-',M->aArray[M->oBrowse:rowPos])-1))"

    M->aArray:={ EMAIL_AUFTRAG + " - Auftrag" , ;
      EMAIL_BEISTELL + " - Beistellteile",;
      EMAIL_GBS + " - Gelangensbescheinigung",;
      EMAIL_LIEFERSCHEIN + " - Lieferschein",;
      EMAIL_RECHNUNG + " - Rechnung" , ;
      EMAIL_SPEDITION + " - Spedition" }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE "SPRACHE" $ upper(oGet:Name)
    oBrowse:nLeft:=30
    oBrowse:nRight:=70
    oBrowse:nTop:=10
    oBrowse:nBottom:=17

    M->aArray:={ "D - Deutsch","E - Englisch" }

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos]+space(1),1)"

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Sprache", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )


  CASE "WARAUS_PROG" $ upper(oGet:Name)
    oBrowse:nLeft:=44
    oBrowse:nRight:=70
    oBrowse:nTop:=06
    oBrowse:nBottom:=15

    // no return after selection, we stay in the same field
    M->confirm:=.f.

    M->aArray:={ WARAUS_INNERNR , WARAUS_FREMD_LS , WARAUS_KLAG_FREMD_LS , ;
      WARAUS_KLAG_RUECKLIEF , WARAUS_MANUELL , WARAUS_RECHNR , WARAUS_MATAUSG2 }

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Art", ABlock(M->aArray))
    oColumn:width(25)
    oBrowse:addColumn( oColumn )

  CASE cProg=="SONDERZEICHEN"
    oBrowse:nLeft:=60
    oBrowse:nRight:=70
    oBrowse:nTop:=06
    oBrowse:nBottom:=15

    // SZ
    M->aArray:={}
    sz_chr:=SONDERZEICHEN_CHR
    sz_asci:=SONDERZEICHEN_ASCII
    for i:=1 to len(sz_chr)
      aadd( M->aArray, chr(sz_chr[i])+str(sz_asci[i],8) )
    next

    // returns one sign only
    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos]+space(1),1)"
    M->confirm:=.f.

    oColumn:=TBColumnNew( "SZ   ASCI", ABlock(M->aArray))
    oBrowse:addColumn( oColumn )

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

  CASE "PROGNAME"$upper(oGet:Name)
    open("Aufruf")

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ProgName"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ProgNr"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Bez"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Anzahl"
    addMyColumn ( oColumn )

    /*** Queues ***/
  CASE "QUEUE" $ upper(oGet:Name)
    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Spalten-Definition */
    M->aArray:=WIN_PRINTERLIST()
    if empty(M->aArray)
      M->aArray:={""}
    endif
    oColumn:=TBColumnNew( "Queues", ABrowseBlock( M->aArray ))
    oColumn:=TBColumnNew( "Queues", ABlock( M->aArray ))
    oColumn:width(30)
    oBrowse:addColumn( oColumn )

    /*** Bank-Auswahl bei Lieferant ***/
  CASE "AUFAUS->IDENTNR" == upper(oGet:Name)
    oBrowse:nLeft:=5
    oBrowse:nRight:=75
    oBrowse:nTop:=6
    oBrowse:nBottom:=12

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Spalten-Definition */
    M->aArray:={}
    KUNDEN->(dbseek(AUFAUS->KundNr))
    aadd(M->aArray,KUNDEN->IdentNr+" "+KUNDEN->Kurzname+" "+KUNDEN->Land+" "+KUNDEN->Plz+" "+;
      +" "+KUNDEN->Ort)
    KUNDEN->(dbseek(AUFAUS->V_KundNr))
    aadd(M->aArray,KUNDEN->IdentNr+" "+KUNDEN->Kurzname+" "+KUNDEN->Land+" "+KUNDEN->Plz+" "+;
      +" "+KUNDEN->Ort)
    KUNDEN->(dbseek(AUFAUS->R_KundNr))
    aadd(M->aArray,KUNDEN->IdentNr+" "+KUNDEN->Kurzname+" "+KUNDEN->Land+" "+KUNDEN->Plz+" "+;
      +" "+KUNDEN->Ort)

    oColumn:=TBColumnNew( "Ident.Nr.       Name                                  Adresse", ABlock(;
      M->aArray ))
    // oColumn:width(50)
    oBrowse:addColumn( oColumn )

  CASE "NKMATNR" == upper(oGet:Name)
    oBrowse:nLeft:=14
    oBrowse:nRight:=70
    oBrowse:nTop:=08
    oBrowse:nBottom:=18

    M->Return_Feld:="left(M->aArray[M->oBrowse:rowPos],8)"

    M->aArray:=getNKMaterialVorschlag(NKERF->Art)

    if len(M->aArray)==0

      if left(NKMEHRF->Artnr,1) == "3"
        Error("Kein Material (7....) in St�ckliste hinterlegt.",.t.)
      elseif left(NKMEHRF->Artnr,1) == "4"
        Error("Kein Material (9....) in St�ckliste hinterlegt.",.t.)
      else
        Error("Kein Material in St�ckliste hinterlegt.||"+;
          "3er Artikel -> Material 7...|"+;
          "4er Artikel -> Material 9...",.t.)
      endif
      M->okay:=.f.
      RETURN oBrowse
    endif

    // Der "skip"-Block erh�ht bzw. erniedrigt nRow
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest( M->aArray, M->nRow, nSkip ), ;
      M->nRow += nSkip, ;
      nSkip ;
      }

    // Der "go top"-Block setzt nRow auf 1
    oBrowse:goTopBlock:={ || M->nRow:=1 }

    // Der "go bottom"-Block setzt nRow auf die L�nge des Arrays.
    oBrowse:goBottomBlock:={ || M->nRow:=LEN( M->aArray ) }

    /* Bezeichnung */
    oColumn:=TBColumnNew( "Artnr    Bezeichnung", ABlock(M->aArray))
    //oColumn:width(25)
    oBrowse:addColumn( oColumn )


  CASE cProg=="EditSepa"

    open("ZahlAus")
    oBrowse:nTop:=3
    oBrowse:nLeft:=3
    oBrowse:nRight:=maxcol()

    set filter to file(SEPA_PFAD+BACKSLASH+"MIKI-"+trim(no_blanks(left(BANKSTAM->BankBez,11)))+;
      "-"+ZAHLAUS->SepaNr+".xml")
    // set dele off

    // keine R�ckgabe bei Auswahl
    M->Return_Feld:="NIL"

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="SepaNr"
    oColumn[COL_TITEL]:="SepaNr"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LiefNr"
    oColumn[COL_TITEL]:="Nummer"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Kurz"
    oColumn[COL_TITEL]:="Name"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Soll_Euro"
    oColumn[COL_TITEL]:="Betrag"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Skto_Euro"
    oColumn[COL_TITEL]:="Skonto"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Datum"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ZahlNr"
    oColumn[COL_TITEL]:="lfd. Nr"
    addMyColumn ( oColumn )

  CASE "KUNDEN->LAND"$upper(oGet:Name) .or. "LANDKZ"$upper(oGet:Name) .or.;
    "A_LAND"$upper(oGet:Name) .or. "S_LAND"$upper(oGet:Name) .or.;
    "V_LAND"$upper(oGet:Name) .or.;
    "LIEFERAN->LAND"$upper(oGet:Name) .or. "SPEDIT->LAND"$upper(oGet:Name)
    open("Land")

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LandKZ"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Name"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="EU"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_TITEL]:="Pr�ferenzland"
    oColumn[COL_NAME]:="LLE"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_TITEL]:="EFTA"
    oColumn[COL_NAME]:="EFTA"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Sprache"
    addMyColumn ( oColumn )

  CASE "SUMNR"$upper(oGet:Name)
    open("Summen")

    M->Return_Feld:="SUMMEN->SumNr"

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="SumNr"
    oColumn[COL_TITEL]:="Nummer"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Datum"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="M_NETTO"
    oColumn[COL_TITEL]:="Netto (Monat)"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="J_NETTO"
    oColumn[COL_TITEL]:="Netto (Jahr)"
    addMyColumn ( oColumn )

    /*** Paletten   ***/
  CASE "PALNR" $ upper(oGet:Name)
    open("Paletten")
    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    /* Spalten-Definition */
    felderAlt( "PalNr" , "Nr.")

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text1"
    oColumn[COL_TITEL]:="Bezeichnung"
    oColumn[COL_SECOND_LINE]:="Text2"
    addMyColumn ( oColumn )

    /*** Letzte Stelle   ***/
  CASE "LETZTEST" $ upper(oGet:Name)
    open("LetzteSt")
    oBrowse:nLeft:=10
    oBrowse:nRight:=70

    /* Spalten-Definition */
    /*   oBrowse, Feld   ,      Titel    , Breite  ,�nderbar   , Spalten-Fkt.   */
    // (nur aus Komp.gr�nden)
    felderAlt( "LetzteSt" , "Letzte St.")
    felderAlt( "Text" )

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelLetzteStelle() }, " @F6@=Artikel" } )


    /*** Intrastat-Rechnungsposten ***/
  CASE upper( cProg )=="INTRASTATEDIT"

    M->SpecialHilfe:={}
    aadd(M->SpecialHilfe,{ K_F5 , { || intrastatToggle() } ," @F5@=Intrastat.Meldung An/Aus" })

    /* Spalten-Definition */
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RECHAUS->RechNr"
    oColumn[COL_TITEL]:="Rech.Nr."
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RECHAUS->ReaDat"
    oColumn[COL_TITEL]:="Datum"
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ArtNr"
    oColumn[COL_TITEL]:="Art.Nr."
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="left(Komm1,30)"
    oColumn[COL_TITEL]:="Bezeichnung"
    oColumn[COL_SECOND_LINE]:="left(Komm2,30)"
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="GeliefGes"
    oColumn[COL_TITEL]:="Menge"
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KdOut(RECHAUS->KundNr)"
    oColumn[COL_TITEL]:="Kd.Nr."
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="RECHAUS->Kurzname"
    oColumn[COL_FARBE]:=INTRASTAT_FARBE
    addMyColumn ( oColumn )

  CASE "CRONNAME"$upper(oGet:Name)
    open("Crontab")

    M->Return_Feld:="CRONTAB->CronName"

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="CronName"
    oColumn[COL_TITEL]:="Bezeichnung"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="dowName(CRONTAB->WochenTag)"
    oColumn[COL_TITEL]:="Wochentag"
    oColumn[COL_SORT]:="dowShift(CRONTAB->Wochentag)"
    oColumn[COL_BREITE]:=12
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="mycmonth(ctod('01.'+alltrim(str(CRONTAB->Monat))+'.13'))"
    oColumn[COL_TITEL]:="Monat"
    oColumn[COL_SORT]:="CRONTAB->Monat"
    oColumn[COL_BREITE]:=12
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Datum"
    addMyColumn ( oColumn )

  CASE "GRUND"$upper(oGet:Name)
    open("Grund")

    if ! "XGRUND"$upper(oGet:Name) // beim �ndern der Grund-Texte muss er die Nr. zur�ckgeben
      // ansonsten nur den Text
      M->Return_Feld:="GRUND->Text"
    endif

    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="GrundNr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text"
    oColumn[COL_TITEL]:="Grund"
    addMyColumn ( oColumn )


    /*** Lagerorte Miki ***/
  CASE "LGNR" $ upper(oGet:Name) .or. "LG_RAUM" $ upper(oGet:Name)
    open("LagerOrt")

    oBrowse:nLeft:=10
    oBrowse:nRight:=70

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="LgNr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text"
    oColumn[COL_TITEL]:="Bezeichnung"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="KurzText"
    oColumn[COL_TITEL]:="Kurz-Bezeichnung"
    addMyColumn ( oColumn )


    /*** Farbe Plantafel */
  CASE "FARBE" $ upper(oGet:Name)
    open("Farbe")

    oBrowse:nLeft:=20
    oBrowse:nRight:=60

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="HexVal"
    addMyColumn ( oColumn )

    /*** Lagerorte Miki ***/
  CASE "ZOLLNR" $ upper(oGet:Name) .or. upper(cProg)=="ZOLLSTELLE"
    open("ZollStelle")

    // oBrowse:nLeft:=10
    // oBrowse:nRight:=70

    if upper(cProg)=="ZOLLSTELLE"
      M->Return_Feld:="ZOLLSTELLE->ZollNr + space(1) + trim(ZOLLSTELLE->Ort)"
    endif


    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ZollNr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_TITEL]:="Name"
    oColumn[COL_NAME]:="Name"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_TITEL]:="Ort"
    oColumn[COL_NAME]:="left(Ort,25)"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text"
    oColumn[COL_TITEL]:="Beschreibung"
    addMyColumn ( oColumn )


  CASE "PRGR"$upper(oGet:Name)
    open("ArtPrGr")

    if getUser():mayEditData

      M->SpecialHilfe:={ TEXT_EDIT, { K_F6 , { || artPrGrListe() } , "E @F6@=in Artikel" } }

    endif
    oBrowse:nLeft:=2
    oBrowse:nRight:=78

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="PrGr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ProzGerat"
    oColumn[COL_TITEL]:="Erh. Ger�t %"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ProzTeil"
    oColumn[COL_TITEL]:="Erh. Ersatzteil %"
    addMyColumn ( oColumn )


  CASE "WARENNR"$upper(oGet:Name)
    open("IntraStat")

    M->SpecialHilfe:={}
    aadd( M->SpecialHilfe , { K_F6 , { || ArtikelWertListe() } , " @F6@=in Artikel" } )

    oBrowse:nLeft:=0
    oBrowse:nRight:=80

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="WarenNr"
    oColumn[COL_TITEL]:="Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text1"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text2"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text3"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Text4"
    addMyColumn ( oColumn )


  CASE cProg=="StornoFertigmeldung"
    M->Return_Feld:="NIL"
    keyboard(chr(K_END)) // gehe ans Ende (FIXME: gab es hier nicht eine "bessere" Methode?)
    oBrowse:nTop:=5

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="ArtNr"
    oColumn[COL_TITEL]:="Art.Nr."
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Datum"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Menge"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Best"
    oColumn[COL_TITEL]:="Lg.Bestand"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Mod_User"
    oColumn[COL_TITEL]:="Kz"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Programm"
    addMyColumn ( oColumn )

    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="Inlfdnr"
    addMyColumn ( oColumn )

  OTHERWISE

    M->okay:=.f.

  ENDCASE

  if DEVEL_PROG .and. M->okay .and. getProperty("System.debug","N")=="J"
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="str(Recno(),8)"
    oColumn[COL_TITEL]:="   Recno"
    addMyColumn ( oColumn )

    if fieldpos("Crea_Date")>0
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="if(empty(crea_user),space(20),dtoc(crea_date)+' '+myTime(crea_time)+' '+Crea_User)"
      oColumn[COL_TITEL]:="Creation"
      addMyColumn ( oColumn )
    endif

    if fieldpos("Mod_Date")>0
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="if(empty(mod_user),space(20),dtoc(mod_date)+' '+myTime(mod_time)+' '+Mod_User)"
      oColumn[COL_TITEL]:="Modification"
      addMyColumn ( oColumn )
    endif
  endif

RETURN oBrowse
/* EOF HilfDef */


/** f�gt an der 2. Pos. eine Spalte mit engl. Texten hinzu */
function addEnglColumn(oBrowse)
LOCAL oColumn,Spalte

  Spalte:=oBrowse:getColumn(2):cargo
  if Spalte<>NIL
    if Spalte[COL_NAME]=="Bez1" .or. Spalte[COL_NAME]=="ARTIKEL->Bez1"
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="ARTIKEL->E_Bez1"
      oColumn[COL_TITEL]:="Bezeichnung (Englisch)"
      oColumn[COL_SECOND_LINE]:="ARTIKEL->E_Bez2"
      addMyColumn(oColumn,2)

      M->secondLine:=;
        &( "{ || ! empty("+Spalte[COL_SECOND_LINE]+") .or. ! empty("+oColumn[COL_SECOND_LINE]+") }" )

    elseif Spalte[COL_NAME]=="E_Bez1" .or. Spalte[COL_NAME]=="ARTIKEL->E_Bez1"
      oBrowse:delColumn( 2 )
      Spalte:=oBrowse:getColumn(2):cargo
      M->secondLine:=&( "{ || ! empty("+Spalte[COL_SECOND_LINE]+") }" )
    endif
    invalidateAll()
  endif

return .t.
  /** eof */

  /** liefert einen String mit allen Rechnungen zu dem aktuell selektierten Auftrag */
function getRechnrByAufNr()
LOCAL result:=""
LOCAL aktSel:=alias()
LOCAL aktRec:=(aktSel)->(recno())
  if open("RechAus")
    RECHAUS->(OrdSetFocus(2)) // AufNr
    RECHAUS->(dbseek(AUFAUS->AufNr))
    do while ! RECHAUS->(eof()) .and. RECHAUS->AufNr == AUFAUS->AufNr
      result += RECHAUS->RechNr + " "
      skip
    enddo
    select (aktSel)
    if aktRec <> (aktSel)->(recno())
      (aktSel)->(dbgoTo(aktRec))
    endif
  endif
return trim(result)


  /* Tokenize a field by CR/LF and return x-th token.*/
function get_token(feld, pos)
LOCAL tokens:=HB_ATokens(&(feld), MY_CR+MY_LF)
  if pos <= len(tokens)
    return tokens[pos]
  endif
return ""
  /** eof */

  /* f�gt alle standard Artikel Spalten hinzu */
static procedure add_artikel_columns(oBrowse)
LOCAL oColumn

  oBrowse:nLeft:=0
  oBrowse:nRight:=80
  oBrowse:nTop:=2

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="Out(ARTIKEL->ArtNr)"
  oColumn[COL_TITEL]:="Art.Nr."
  oColumn[COL_BREITE]:=12
  addMyColumn ( oColumn )

  // ACHTUNG: "Bezeichnung" muss 2. Spalte sein (s. addEnglColumn())
  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->Bez1"
  oColumn[COL_TITEL]:="Bezeichnung"
  oColumn[COL_SECOND_LINE]:="ARTIKEL->Bez2"
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->Art"
  oColumn[COL_TITEL]:="A"
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->WKZ"
  oColumn[COL_TITEL]:=""
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->LageBest"
  oColumn[COL_TITEL]:="Lg-Best."
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="str(ARTIKEL->Preis1,9,2)"
  oColumn[COL_TITEL]:="     VK"
  oColumn[COL_FELDNAME]:="Preis1"
  addMyColumn ( oColumn )

  if getUser():id==KURZEL_MIKI_GF .or. getUser():id==KURZEL_DEVEL
    oColumn:=getNewColumn()
    oColumn[COL_NAME]:="if(ARTIKEL->Preis1=0,space(4),ARTIKEL->Zuschl_I)"
    oColumn[COL_TITEL]:="%"
    oColumn[COL_BREITE]:=4
    addMyColumn ( oColumn )

    if getUser():id==KURZEL_DEVEL
      oColumn:=getNewColumn()
      oColumn[COL_NAME]:="ARTIKEL->Disponiert"
      oColumn[COL_TITEL]:="AB Bestand"
      addMyColumn ( oColumn )
    endif
  endif

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->LG_Raum+'.'+ARTIKEL->LG_Regal+'.'+ARTIKEL->Lg_Fach"
  oColumn[COL_TITEL]:="Raum.Regal.Fach"
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->LG_Text"
  oColumn[COL_TITEL]:="Lg Text"
  addMyColumn ( oColumn )

  // oColumn:=getNewColumn()
  // oColumn[COL_NAME]:="getArtikelLagerOrt(20)"
  // oColumn[COL_BREITE]:=40
  // oColumn[COL_TITEL]:="Test"
  // addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->Reihenfolg"
  oColumn[COL_TITEL]:="AV-Nr."
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->WarenNr"
  oColumn[COL_TITEL]:="Waren-Nr."
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->AltArtNr"
  oColumn[COL_TITEL]:="Alte Nr."
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->KonsigKdNr"
  oColumn[COL_TITEL]:="K-Lager Kd.Nr"
  addMyColumn ( oColumn )

  oColumn:=getNewColumn()
  oColumn[COL_NAME]:="ARTIKEL->LandKZ"
  oColumn[COL_TITEL]:="Land"
  addMyColumn ( oColumn )
return

/***
* Helper function for LIEFNR missing number display (STRG-N)
*
* Toggles between normal DB view and array view with missing numbers.
* Array view shows: LiefNr, KurzName, Name (missing numbers in red)
***/

  // Toggle inline display of missing numbers (generic for any database/field)
  // Parameters: oBrowse, cDbAlias, cNrField, cField1, cField2, aFilterPrefixes, oGet, cProg
// NEW APPROACH: Simplified without STATIC caching issues
static function toggleMissingNumbers(oBrowse, cDbAlias, cNrField, cField1, cField2, aFilterPrefixes, oGet, cProg);
  // Only keep session cache for performance
  STATIC cachedMissingNumbers:=NIL
  STATIC cachedDbAlias:=""
  STATIC savedIndexOrder:=0
  STATIC savedReturnFeld:=""

LOCAL minNr, maxNr, i
LOCAL oColumn, combinedArray
LOCAL cNrFieldVal, cField1Val, cField2Val
LOCAL nKey, nMaxNr, aborted
LOCAL lastNr, currentNr, gapNr, nCounter
LOCAL nMaxRec, nMaxNrWidth
LOCAL j, cPrefix
LOCAL nPrefixMin, nPrefixMax, nGapStart, nGapEnd
LOCAL savedNr:=""

  Umgebung(WRITE_ALL)

  select (cDbAlias)

  // Check if database changed - clear cache
  if cachedDbAlias != cDbAlias
    cachedMissingNumbers:=NIL
    cachedDbAlias:=cDbAlias
  endif

  // Detect current mode by checking M->aArray
  // Empty = DB mode, Non-empty = showing missing numbers
  if len(M->aArray) == 0
    // ===== SWITCH TO MISSING NUMBERS VIEW =====

    // Save current state
    savedReturnFeld:=M->Return_Feld

    // Save current position
    if .not. eof()
      savedNr:=alltrim(&(cDbAlias + "->" + cNrField))
    endif

    // Check if we have cached data for this session
    if cachedMissingNumbers == NIL
      // Build missing numbers array
      Message("Freie Nummern werden gesucht, bitte warten...")

      // Save current index order and set to 1 (numeric sort)
      savedIndexOrder:=indexOrd()
      dbSetOrder(1)

      // Get min/max numbers
      dbGoTop()
      if eof()
        Message("Keine Datensaetze vorhanden")
        Umgebung(LOAD)
        return NIL
      endif
      cNrFieldVal:=alltrim(&(cDbAlias + "->" + cNrField))
      minNr:=val(cNrFieldVal)

      dbGoBottom()
      cNrFieldVal:=alltrim(&(cDbAlias + "->" + cNrField))
      maxNr:=val(cNrFieldVal)

      // Build array with gaps
      combinedArray:={}
      lastNr:=max(1, minNr - 10) - 1
      nMaxNr:=min(maxNr + 10, 99999)
      aborted:=.f.
      nCounter:=0
      nMaxRec:=Reccount()

      dbGoTop()
      do while .not. eof()
        nCounter++

        // Progress message
        if nCounter % 100 == 0
          Message("Lese Datensatz " +;
            ltrim(str(nCounter)) + " / " + ltrim(str(nMaxRec)) + " @ESC@=Abbruch")
          nKey:=Inkey()
          if nKey == K_ESC
            aborted:=.t.
            exit
          endif
        endif

        cNrFieldVal:=alltrim(&(cDbAlias + "->" + cNrField))
        if .not. empty(cNrFieldVal) .and. isdigit(cNrFieldVal)
          currentNr:=val(cNrFieldVal)

          // Add missing numbers between last and current
          if aFilterPrefixes == NIL .or. len(aFilterPrefixes) == 0
            // No filter
            for gapNr:=max(lastNr + 1, max(1, minNr - 10)) to min(currentNr - 1, nMaxNr)
              aadd(combinedArray, { str(gapNr, 8), .t., str(gapNr, 8), "", "" })
            next
          else
            // With filter - only add numbers matching prefix
            for j:=1 to len(aFilterPrefixes)
              cPrefix:=alltrim(str(aFilterPrefixes[j]))
              nPrefixMin:=val(cPrefix + replicate("0", 5 - len(cPrefix)))
              nPrefixMax:=val(cPrefix + replicate("9", 5 - len(cPrefix)))
              nGapStart:=max(lastNr + 1, nPrefixMin)
              nGapEnd:=min(currentNr - 1, nPrefixMax)

              if nGapStart <= nGapEnd
                for gapNr:=max(nGapStart, max(1, minNr - 10)) to min(nGapEnd, nMaxNr)
                  aadd(combinedArray, { str(gapNr, 8), .t., str(gapNr, 8), "", "" })
                next
              endif
            next
          endif

          // Add current record
          if currentNr >= max(1, minNr - 10) .and. currentNr <= nMaxNr
            cField1Val:=alltrim(&(cDbAlias + "->" + cField1))
            if valtype(cField1Val) != "C"
              cField1Val:=""
            endif

            if empty(cField2)
              cField2Val:=""
            elseif "->" $ cField2 .or. "+" $ cField2 .or. " " $ cField2
              cField2Val:=alltrim(&cField2)
            else
              cField2Val:=alltrim(&(cDbAlias + "->" + cField2))
            endif
            if valtype(cField2Val) != "C"
              cField2Val:=""
            endif

            aadd(combinedArray, { cNrFieldVal, .f., cNrFieldVal, cField1Val, cField2Val })
          endif

          lastNr:=currentNr
        endif
        dbSkip()
      enddo

      // Add missing numbers after last record
      if .not. aborted
        if aFilterPrefixes == NIL .or. len(aFilterPrefixes) == 0
          for gapNr:=lastNr + 1 to nMaxNr
            aadd(combinedArray, { str(gapNr, 8), .t., str(gapNr, 8), "", "" })
          next
        else
          for j:=1 to len(aFilterPrefixes)
            cPrefix:=alltrim(str(aFilterPrefixes[j]))
            nPrefixMin:=val(cPrefix + replicate("0", 5 - len(cPrefix)))
            nPrefixMax:=val(cPrefix + replicate("9", 5 - len(cPrefix)))
            nGapStart:=max(lastNr + 1, nPrefixMin)
            nGapEnd:=min(nMaxNr, nPrefixMax)

            if nGapStart <= nGapEnd
              for gapNr:=nGapStart to nGapEnd
                aadd(combinedArray, { str(gapNr, 8), .t., str(gapNr, 8), "", "" })
              next
            endif
          next
        endif
      endif

      // Cache for session
      cachedMissingNumbers:=combinedArray
    else
      // Use cached data
      combinedArray:=cachedMissingNumbers
    endif

    // Set array and position
    M->aArray:=combinedArray
    M->nRow:=iif(len(combinedArray) > 0, 1, 0)

    // Find saved position
    if .not. empty(savedNr)
      for i:=1 to len(M->aArray)
        if alltrim(M->aArray[i][3]) == savedNr
          M->nRow:=i
          exit
        endif
      next
    endif

    // Calculate column width
    nMaxNrWidth:=8
    for i:=1 to len(combinedArray)
      nMaxNrWidth:=max(nMaxNrWidth, len(alltrim(combinedArray[i][3])))
    next

    // Remove all existing columns
    do while oBrowse:colCount > 0
      oBrowse:delColumn(1)
    enddo

    // Add array-based columns
    oColumn:=TBColumnNew("Nr", { || iif(M->nRow > 0 .and.;
      M->nRow <= len(M->aArray), alltrim(M->aArray[M->nRow][3]), "") })
    oColumn:width:=nMaxNrWidth
    oColumn:colorBlock:={;
      ||;
      iif(M->nRow > 0 .and. M->nRow <= len(M->aArray) .and.;
      M->aArray[M->nRow][2], RED_ON_WHITE, NIL) }
    oBrowse:addColumn(oColumn)

    oColumn:=TBColumnNew("Kurzname", { || iif(M->nRow > 0 .and.;
      M->nRow <= len(M->aArray), M->aArray[M->nRow][4], "") })
    oColumn:colorBlock:={;
      ||;
      iif(M->nRow > 0 .and. M->nRow <= len(M->aArray) .and.;
      M->aArray[M->nRow][2], RED_ON_WHITE, NIL) }
    oBrowse:addColumn(oColumn)

    oColumn:=TBColumnNew("Name", { || iif(M->nRow > 0 .and.;
      M->nRow <= len(M->aArray), M->aArray[M->nRow][5], "") })
    oColumn:width:=40
    oColumn:colorBlock:={;
      ||;
      iif(M->nRow > 0 .and. M->nRow <= len(M->aArray) .and.;
      M->aArray[M->nRow][2], RED_ON_WHITE, NIL) }
    oBrowse:addColumn(oColumn)

    // Set array navigation blocks
    oBrowse:skipBlock:={ |nSkip| nSkip:=ASkipTest(M->aArray, M->nRow, nSkip),;
      M->nRow:=max(1, min(M->nRow + nSkip, len(M->aArray))), nSkip }
    oBrowse:goTopBlock:={ || M->nRow:=iif(len(M->aArray) > 0, 1, 0) }
    oBrowse:goBottomBlock:={ || M->nRow:=max(1, len(M->aArray)) }

    // Set Return_Feld for array
    M->Return_Feld:="alltrim(M->aArray[M->nRow][3])"

    // Add "N" key handler to SpecialHilfe
    aadd(M->SpecialHilfe, { "nN", { || jumpToNextFreeNumber(oBrowse) }, " @N@=Naechste freie" })

    Umgebung(LOAD)

    // Display the help message (bottLineHilfe is static in hilfe.prg so we use Message directly)
    Message("Freie Nummern Anzeige @N@=Naechste freie @CTRL-N@=zurueck @RETURN@=Auswahl @ESC@=Ende")

  else
    // ===== SWITCH BACK TO DB VIEW =====

    // Clear array
    M->aArray:={}

    // Remove all columns first
    do while oBrowse:colCount > 0
      oBrowse:delColumn(1)
    enddo

    // Rebuild original columns - hilfdef() adds columns and sets goTopBlock/goBottomBlock
    // NOTE: hilfdef() also recreates SpecialHilfe with original entries (including CTRL-N)
    hilfdef(oBrowse, oGet, cProg)

    // Restore database navigation blocks (hilfdef doesn't set skipBlock)
    oBrowse:skipBlock:={|n| Skipper(n) }

    // Restore original index order
    if savedIndexOrder > 0
      dbSetOrder(savedIndexOrder)
    endif

    // Restore original Return_Feld (was pointing to M->aArray before)
    // Note: savedReturnFeld might be empty string "", which is valid, so always restore
    M->Return_Feld:=savedReturnFeld

    Umgebung(LOAD)

  endif

  // Refresh browse
  oBrowse:configure()
  oBrowse:refreshAll():forceStable()

return NIL
/***
 * Jump to next free (missing) number in the array
 * Used when free numbers are displayed (showingMissing mode)
 ***/
static function jumpToNextFreeNumber(oBrowse)
LOCAL i, found

  // Search forward from current position + 1
  found:=.f.
  for i:=M->nRow + 1 to len(M->aArray)
    // Element [2] is the "missing" flag (.t. = free number)
    if M->aArray[i][2] == .t.
      M->nRow:=i
      oBrowse:refreshAll()
      found:=.t.
      exit
    endif
  next

  // If not found: show message
  if .not. found
    Message("Keine weiteren freien Nummern")
    Inkey(0.5) // Show briefly
    Message("Freie Nummern Anzeige       @RETURN@=Auswahl  @CTRL-N@ zurueck  @N@=Naechste freie")
  endif

return found
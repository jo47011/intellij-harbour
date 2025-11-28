/* Modul:       Av_Waren
*
* Alles zum AV: Wareneingang/Ausgang
*/

#include "Miki.ch"

/*** 
* Wareneingang
*
*   FertigMeldung MIKI
*/
PROCEDURE Av_Mateing(nurWerkzeug)
LOCAL aFelder:={} , getList:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
  default nurWerkzeug:=.f.

  cls
  if nurWerkzeug
    titel("Werkzeug Eingang - intern")
  else
    titel("F E R T I G M E L D U N G")
  endif

  if ! open( "MatEing" , "Artikel" , "Einheit" , "Inner" , "KostenSt","AvAus";
    ,"AvPost" , "BesPost" , "BesAus" , "KstStamm","MehrFach","AufPost")

    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  MEHRFACH->(OrdSetFocus(2)) // ANr + ArtNr == Artikel + Werkzeug
  AUFPOST->(OrdSetFocus(5)) // AbPostNr
  INNER->(OrdSetFocus(2)) // ArtNr+InnerNr
  select MatEing
  set relation to MATEING->Me into Einheit, to MATEING->ArtNr into Artikel
  // ,to MATEING->ArtNr+MATEING->InnerNr into Inner
  go top

  /* eingeloggter Benutzer best�tigen/�ndern */
  // Login_change(4,10,"K�rzel........:")

  if ABBRUCH
    cls
    close data
    RETURN
  endif
  @ 4,10 say "K�rzel........: "
  qqout( getUser():id )

  SetKey( K_F5 , { || MyStkListLind( row() , 0 ) })
  SetKey( K_F6 , { || MatArtikelListe() })
  SetKey( K_F9 , { |p1,p2| warenEinOrt("MATEING",aFelder,p1,p2)} )

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_INDEX_FELD ]:={|| MATEING->Menge == 0 .and. MATEING->Ausschuss==0}
  aKopf[EDIT_AFTER_EDIT_FKT]:={ || clearTempIndex() }
  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=aufl." , { || MyStkListLind( row() , 0 ) }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F9) ," @F9@=Lagerort �ndern " , { || warenEinOrt("MATEING",;
    aFelder) } } )

  aadd(aKopf[EDIT_EXTRA_FKT], ;
    { chr(K_CTRL_M), "" , { || AlternatMaterialErfassen(MATEING->ArtNr) }})


  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  if nurWerkzeug
    aSpalte[EDIT_AFTER]:={ |oGet| Av_WKZ_ArtNr_nach(oGet,"Mateing")}
  else
    aSpalte[EDIT_AFTER]:={ |oGet| Av_ME_ArtNr_nach(oGet,"Mateing")}
  endif
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="InnerNr"
  aSpalte[EDIT_TITEL]:="Auftrag (intern)"
  aSpalte[EDIT_MASKE]:="@K !999"
  aSpalte[EDIT_BEFORE]:={ |oGet| InnerNrVor(oGet) }
  aSpalte[EDIT_AFTER]:={ |oGet| lastkey() == K_UP .or. InnerNrNach(oGet,"MatEing") }
  aSpalte[EDIT_MESSAGE]:="Innerbetr. Auftrag zuordnen.            @F12@=Auswahl          @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Rest-Menge anzeigen
  aSpalte[EDIT_NAME]:="left(if(!empty(InnerNr),'Rest-Menge: '+alltrim(str(Rest-Menge,12,2)),'')+space(22),22)"
  aSpalte[EDIT_POS_X]:=-12
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MASKE]:="99999.99"
  aSpalte[EDIT_AFTER]:={ |oGet| maxConfirm( oGet , 10000 ) .and. val(oGet:Buffer) >= 0} // FIXME: enable again
  aSpalte[EDIT_MESSAGE]:="Gut-Menge eingeben.       @F9@ = Lagerort �ndern"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_POS_X]:=1

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Ausschuss
  aSpalte[EDIT_NAME]:="Ausschuss"
  aSpalte[EDIT_TITEL]:="Ausschuss"
  aSpalte[EDIT_AFTER]:={ |oGet| nach_ausschuss(oGet)}
  aSpalte[EDIT_MESSAGE]:="Davon Ausschuss eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit anzeigen
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // LagerOrt
  aSpalte[EDIT_NAME]:="Ort"
  aSpalte[EDIT_TITEL]:="Lg-Ort/Bestand"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // akt. Bestand anzeigen
  aSpalte[EDIT_NAME]:="str(ARTIKEL->LageBest,9,2)+space(1)+EINHEIT->Text"
  aSpalte[EDIT_POS_X]:=-2
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kostenstelle
  aSpalte[EDIT_NAME]:="KostSt"
  aSpalte[EDIT_TITEL]:="KSt."
  aSpalte[EDIT_MASKE]:="@9@K"
  aSpalte[EDIT_AFTER]:={;
    |oGet| lastkey()==K_UP .or. empty((Alias())->ArtNr) .or. check(oGet,"KstStamm",.f.) }
  aSpalte[EDIT_MESSAGE]:="Kostenstelle mu� eingeben werden."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf)

  /* Auswahl-Menu */
  loca for MATEING->Menge <> 0 .or. MATEING->Ausschuss <> 0
  if ! MATEING->(eof()) .and. Message("Fertigmeldung verbuchen ?  (@J@/@N@)","JN","J") == "J"
    Av_Eing_Druck()
    AufBestand()
  endif
  close data

  set Key K_F5 to
  set Key K_F6 to
  set Key K_F9 to
  cls
RETURN
/* EOP */

/* wird nach Eingabe des Ausschuss ausgef�hrt */
static FUNCTION nach_ausschuss(oGet)

  if val(oGet:buffer) < 0
    return .f.
  endif

  if val(oGet:buffer) > MATEING->Menge .and. MATEING->Menge > 0
    Error(ACHTUNG+"Ausschuss muss kleiner als die Gutmenge sein.||"+;
      "         Zum Buchen von nur Ausschuss bitte Gutemenge 0 eingeben.")
    return .f.
  endif
return .t.
/** eof */


/*** 
* Wareneingang Fremd-Material
*/
PROCEDURE Av_Fremd(nurWerkzeug)
LOCAL aFelder:={} , getList:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX], M_BestNr, M_LS_Nr
LOCAL verbuchen
LOCAL mybestnr
LOCAL all_BestNr

  default nurWerkzeug:=.f.

  cls
  if nurWerkzeug
    titel("Werkzeug Eingang - extern")
  else
    titel("F R E M D - M A T E R I A L")
  endif

  if ! open( "FremdEin", "Artikel", "Einheit", "BesPost" ,"BesAus", "KostenSt", "AvAus";
    ,"AvPost", "KstStamm", "Lieferan","Inner","Text","Mehrfach")

    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  select BesAus
  set filter to BESAUS->Erledigt <> "J"

  M_BestNr:=space(len(BESAUS->BestNr))
  @ 10,20 say 'Bestell Nr.:' get M_BestNr picture '@K #####' ;
    when Message("Bestellnummer eingeben.   @Return@/@ESC@=Weiter      @F12@=Hilfe") ;
    valid { |oGet| check(oGet,"BesAus",.t.,.f.) }
  read

  if ABBRUCH
    cls
    close data
    RETURN
  endif

  if lastkey() == K_RETURN .and. ! empty(M_BestNr)

    M_LS_Nr:=space(len(FREMDEIN->LS_Nr))
    @ 12,20 say 'Lieferschein-Nr.:' get M_LS_Nr valid len(alltrim(M_LS_Nr)) > 2 ;
      when Message("Lieferscheinnummer eingeben       @ESC@=ohne LS-Nr. weiter.")
    read

    select FremdEin
    dele for ! empty(FREMDEIN->BestNr)
    BESPOST->(dbseek( BESAUS->BestNr ))
    do while ! BESPOST->(eof()) .and. BESPOST->BestNr==BESAUS->BestNr
      if len(alltrim(BESPOST->ArtNr)) > FRACHT_LAENGE .and. BESPOST->Menge > BESPOST->GeliefGes
        select FremdEin
        add_rec(0)
        replace FREMDEIN->ArtNr with BESPOST->ArtNr
        replace FREMDEIN->BestNr with BESPOST->BestNr
        replace FREMDEIN->BesPostNr with BESPOST->BesPostNr
        replace FREMDEIN->Me with BESPOST->ME
        replace FREMDEIN->Ort with getArtikelLagerOrt(11)
        replace FREMDEIN->KostSt with ARTIKEL->KostNr
        REPLACE FREMDEIN->LS_Nr WITH M_LS_Nr
        REPLACE FREMDEIN->Lg_Raum WITH ARTIKEL->Lg_Raum
        REPLACE FREMDEIN->Lg_Regal WITH ARTIKEL->Lg_Regal
        REPLACE FREMDEIN->Lg_Fach WITH ARTIKEL->Lg_Fach
        REPLACE FREMDEIN->Lg_Text WITH ARTIKEL->Lg_Text
        REPLACE FREMDEIN->Menge_Best WITH BESPOST->Menge - BESPOST->GeliefGes
      endif
      select BesPost
      skip
    enddo
  endif

  select BesPost
  set rela to BESPOST->LiefNr into Lieferan, to BESPOST->BestNr into Besaus

  select BesAus
  set filter to

  select BesPost
  index on BESPOST->BesPostNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    BESPOST->Menge > BESPOST->GeliefGes .and. BESAUS->Erledigt <> "J"

  select FremdEin
  set relation to FREMDEIN->Me into Einheit,to FREMDEIN->ArtNr into Artikel,;
    to FREMDEIN->BesPostNr into BesPost
  go top

  @ 4,10 say "K�rzel........: "
  qqout( getUser():id )

  SetKey( K_F5 , { || MyStkListLind( row() , 0 ) })
  SetKey( K_F6 , { || MatArtikelListe() })
  SetKey( K_F9 , { |p1,p2| warenEinOrt("FremdEin",aFelder,p1,p2)} )

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_INDEX_FELD ]:=2
  aKopf[EDIT_AFTER_EDIT_FKT]:={ || checkeMe(aKopf,aFelder) .and. clearFremdTempIndex() }
  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=aufl." , { || MyStkListLind( row() , 0 ) }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})
  aadd(aKopf[EDIT_EXTRA_FKT], { chr(K_F9) ," @F9@=Lagerort �ndern " , { || warenEinOrt("FremdEin",;
    aFelder) } } )
  aadd(aKopf[EDIT_EXTRA_FKT],{ "M"," @M@enge �bernehmen ", { || copyMenge()}})


  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  if nurWerkzeug
    aSpalte[EDIT_AFTER]:={ |oGet| Av_WKZ_ArtNr_nach(oGet,"FremdEin")}
  else
    aSpalte[EDIT_AFTER]:={ |oGet| Av_ME_ArtNr_nach(oGet,"FremdEin")}
  endif
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  aSpalte[EDIT_NAME]:="BestNr"
  aSpalte[EDIT_NAME_GET]:="AusserNr"
  aSpalte[EDIT_TITEL]:="Best.Nr."
  aSpalte[EDIT_MASKE]:="@K "+replicate("9",len(FREMDEIN->BestNr))
  aSpalte[EDIT_BEFORE]:={ || BestNrVor() }
  aSpalte[EDIT_AFTER]:={ |oGet| lastkey() == K_UP .or. BestNrNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Bestellung zuordnen.      @F10@=ohne Best.Nr.     @F12@=Hilfe         @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="LS_Nr"
  aSpalte[EDIT_TITEL]:="LS.Nr."
  aSpalte[EDIT_AFTER]:={ |oGet| nachLiefNr(oGet) }
  aSpalte[EDIT_MESSAGE]:="Lieferschein-Nummer eingeben."
  aSpalte[EDIT_UEBERTRAG]:=.t. // carry on
  aSpalte[EDIT_BS_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit eingeben
  aSpalte[EDIT_NAME]:="ME"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_BEFORE]:={ || !empty(ARTIKEL->ME2) }
  aSpalte[EDIT_MASKE]:="9"
  aSpalte[EDIT_AFTER]:={ |oGet| meNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Mengeneinheit eingeben.       @F12@ = Hilfe"
  aSpalte[EDIT_POS_X]:=6
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MASKE]:="99999.99"
  aSpalte[EDIT_AFTER]:={ |oGet| maxConfirm( oGet , 10000 ) }
  aSpalte[EDIT_MESSAGE]:="Menge eingeben.           @F9@ = Lagerort �ndern"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // 2. Menge
  aSpalte[EDIT_NAME]:="getAvMe2Menge()"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_X]:=-1
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit anzeigen
  // aSpalte[EDIT_NAME]:={ |oGet| if(empty(ARTIKEL->Me2),space(3),getAvMeText(oGet)) }
  aSpalte[EDIT_NAME]:="if(empty(ARTIKEL->Me),space(3),getFremdMeText())"
  aSpalte[EDIT_TITEL]:=""
  // aSpalte[EDIT_FARBE]:={ || if( !empty(BESPOST->BestNr) .and. BESPOST->ME<>ARTIKEL->ME,COLINV,COLNOR) }
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // 2. Mengeinheit
  aSpalte[EDIT_NAME]:="if(empty(ARTIKEL->Me2),space(3),getAvMe2Text())"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // // Rest-Menge anzeigen
  aSpalte[EDIT_NAME]:="if(!empty(BestNr),Max(BESPOST->Menge-BESPOST->GeliefGes,0),'')"
  aSpalte[EDIT_TITEL]:="     Rest"
  aSpalte[EDIT_MASKE]:="999999.99"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit anzeigen
  // aSpalte[EDIT_NAME]:={ |oGet| if(empty(ARTIKEL->Me2),space(3),getAvMeText(oGet)) }
  aSpalte[EDIT_NAME]:="if(empty(ARTIKEL->Me),space(3),getBestellMeText())"
  aSpalte[EDIT_TITEL]:=""
  // aSpalte[EDIT_FARBE]:={ || if( !empty(BESPOST->BestNr) .and. BESPOST->ME<>ARTIKEL->ME,COLINV,COLNOR) }
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_X]:=0

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // akt. Bestand anzeigen
  aSpalte[EDIT_TITEL]:="Auf Lager"
  aSpalte[EDIT_NAME]:="getWarenLagebest()"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // LagerOrt
  aSpalte[EDIT_NAME]:="getLagerOrt(Lg_Raum,Lg_Regal,Lg_Fach,Lg_Text)"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // // Kostenstelle
  // aSpalte[EDIT_NAME]:="KostSt"
  // aSpalte[EDIT_TITEL]:="KSt"
  // aSpalte[EDIT_MASKE]:="@9@K"
  // aSpalte[EDIT_AFTER]:={ |oGet| lastkey()==K_UP .or. empty((Alias())->ArtNr) .or.check(oGet,"KstStamm",.f.) }
  // aSpalte[EDIT_MESSAGE]:="Kostenstelle mu� eingeben werden.              @F5@ = Lagerort �ndern"

  // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  // aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf)

  loca for FREMDEIN->Menge > 0
  verbuchen:=.not. FREMDEIN->(eof())

  select BesPost

  /* Auswahl-Menu */
  if verbuchen .and. Message("Fremd-Material verbuchen ?  (@J@/@N@)","JN","J") == "J"
    Av_FremdEing_Druck()

    // pr�fe ob alle Posten der Bestellungen komplett geliefert -> dann als erledigt markieren
    select FremdEin
    go top
    all_BestNr:={}
    DBEval( {|| aaddUnique( all_BestNr, FREMDEIN->BestNr)} )
    for each mybestnr in all_bestnr
      checkBestellErledigt( mybestnr )
    next
    select FremdEin

    // jetzt l�schen
    dele for FREMDEIN->Menge == 0
    pack

  endif

  set Key K_F5 to
  set Key K_F6 to
  set Key K_F9 to
  SetKey( K_F10 , nil )
  close data
  cls
RETURN
/* EOP av_Fremdg */

/** wird nach Eingabe der Lieferscheinnr. ausgef�hrt */
function nachLiefNr(oget)
LOCAL bestNr, aktRec:=recno()

  if lastkey() == K_UP
    return .t.
  endif

  if .not. len(alltrim(oGet:buffer))>2
    return .f.
  endif

  if oGet:changed()
    bestNr:=FREMDEIN->BestNr
    replace FREMDEIN->LS_Nr with oget:buffer ;
      for FREMDEIN->BestNr==BestNr .and. empty(FREMDEIN->LS_Nr)
    dbgoto(aktRec)
  endif

return .t.
  /** eof */

/** �bernimmt den Posten komplett,
     kopiert die Menge nach Gelief */
static function copyMenge()
  REPLACE FREMDEIN->Menge WITH FREMDEIN->Menge_Best
  keyboard chr(K_DOWN)
return .t.


  /** liefert den Einheitentext */
function getFremdMeText()
LOCAL aktRec:=EINHEIT->(recno())
LOCAL result:=space(3)
  EINHEIT->(dbseek( FREMDEIN->ME ))
  result:=EINHEIT->Text
  EINHEIT->(dbgoto(aktRec))
return result
/** eof */

/** liefert den Einheitentext */
function getBestellMeText()
LOCAL aktRec:=EINHEIT->(recno())
LOCAL result:=space(3)
  EINHEIT->(dbseek( BESPOST->ME ))
  result:=EINHEIT->Text
  EINHEIT->(dbgoto(aktRec))
return result
/** eof */

/** liefert den Einheitentext zur 2. ME des aktuellen Artikels */
function getAvMe2Text()
LOCAL aktRec:=EINHEIT->(recno())
LOCAL result:=space(3)
  if ! empty(ARTIKEL->Me2) .and. ! empty( FREMDEIN->Me )
    // suche andere Einheit
    if FREMDEIN->Me==ARTIKEL->ME2
      EINHEIT->(dbseek(ARTIKEL->ME))
      result:=EINHEIT->Text
      EINHEIT->(dbgoto(aktRec))
    else
      EINHEIT->(dbseek(ARTIKEL->ME2))
      result:=EINHEIT->Text
      EINHEIT->(dbgoto(aktRec))
    endif
  endif
return result
/** eof */


/** liefert die Menge zur 2. ME des Artikels */
function getAvMe2Menge()
LOCAL result:=space(9)
  if ! empty(ARTIKEL->Me2) .and. ! empty( FREMDEIN->Me )
    // suche andere Einheit
    if FREMDEIN->Me==ARTIKEL->ME2
      result:=str( round(FREMDEIN->Menge / ARTIKEL->ME_Faktor,2) , 9 , 2)
    else
      result:=str( round(FREMDEIN->Menge * ARTIKEL->ME_Faktor,2) , 9 , 2)
    endif
  endif
return result
/** eof */

function getWarenLagebest()
LOCAL aktRec:=EINHEIT->(recno())
LOCAL result
  EINHEIT->(dbseek(ARTIKEL->ME))
  result:=left(alltrim(str(ARTIKEL->LageBest,8,2) + space(1) + EINHEIT->Text)+space(12),12)
  EINHEIT->(dbgoto(aktRec))
return result
/** eof */

/*
* wird nach Eingabe der Einheit ausgef�hrt
*/
static FUNCTION meNach(oGet)
LOCAL text

  if lastkey() == K_UP
    return .t.
  endif

  if ! check(oGet,"Einheit",.f.,.f.)// kein leeres Feld erl
    Error(ACHTUNG+"bitte Mengeneinheit eingeben.")
    return .f.
  endif

  if ! empty( ARTIKEL->ME2 )
    if ! oget:Buffer $ ARTIKEL->ME+ARTIKEL->ME2
      Einheit->(dbseek(ARTIKEL->ME2))
      text:=ARTIKEL->ME2 + " = " + alltrim(EINHEIT->Kommentar)
      Einheit->(dbseek(ARTIKEL->ME))
      Error(ACHTUNG+"Mengeneingabe in:||        "+ARTIKEL->ME + " = " + alltrim(EINHEIT->Kommentar)+;
        " oder "+text,.t.)
      return .f.
    endif
  endif

return .t.
/** eof */

  // 14.9.2012
/* 
* wird nach Eingabe der Artikel-Nr. ausgef�hrt
*/
static FUNCTION Av_ME_ArtNr_nach(oGet,datei,klagerintern)
LOCAL altArtikel:=""

  // 14.9.2012
  if empty(oGet:buffer)
    return .f.
  endif

  default klagerintern:=.f.
  if oGet:changed()

    if ! check(oGet,"Artikel",.f.,.f.)
      return .f.
    endif

    if getArtikelArt()=="W"
      Error(ACHTUNG+;
        "hier keine Werkzeuge zugelassen.|         Bitte anderen Men�-Punkt verwenden.",.t.)
      return .f.
    endif

    if klagerintern .and. (getArtikelArt()<>"B" .or. empty(ARTIKEL->KonsigKdNr))
      Error(ACHTUNG+"Artikel ist nicht als interner K-Lager Artikel deklariert.|         Konsig-Kundenr muss gesetzt sein und Artikel Art muss 'B' sein.",.t.)
      return .f.
    endif

    // seit 29.5.15 alle Beistellteile �ber diesen Men�punkt
    // if klagerintern .and. ! left(ARTIKEL->KonsigKdNr,5) $ "10167|10363"
    // Error(ACHTUNG+"Nur VVG und Honsel Artikel erlaubt.",.t.)
    // return .f.
    // endif

    if ! klagerintern //
      if getArtikelArt()=="B"
        Error(ACHTUNG+"Artikel ist Beistellteil.|         Bitte anderen Men�-Punkt verwenden.",.t.)
        return .f.
      endif

    endif

    // keine Verpackungen
    if len(alltrim(oGet:buffer))<=FRACHT_LAENGE
      AVPOST->(dbseek(oGet:buffer))
      if ! AVPOST->(eof())
        /* St�ckliste suchen */
        do while ! AVPOST->(eof()) .and. oGet:buffer==AVPOST->AvNr
          if AVPOST->Art="M" .and. AVPOST->Text="A" // Material ben�tigt
            altArtikel+=AVPOST->ArtNr+" "
          endif
          AVPOST->(dbskip())
        enddo
      endif
      Error(ACHTUNG+"Eingang Fracht/Verpackung kann nicht gebucht werden.|"+;
        if(empty(altArtikel),"","|"+space(9)+"Bitte unter: "+altArtikel+" verbuchen."),.t.)
      return .f.
    endif

    oGet:assign()

    // Einheit nicht bei Fremdeingang �bernehmen falls mehrere hinterlegt
    // da muss man die ME manuell eingeben
    if ! (Datei == "FremdEin" .and. ! empty(ARTIKEL->ME2))
      replace (DATEI)->Me with ARTIKEL->ME
    endif
    replace (DATEI)->Ort with getArtikelLagerOrt(11)
    replace (DATEI)->KostSt with ARTIKEL->KostNr
    dbskip(0)
    EINHEIT->(dbseek(ARTIKEL->ME))

    // Innerbetr.Nr. l�schen, 20120423 // FIXME: Warum???
    if (DATEI)->(fieldPos( "InnerNr" )) > 0
      replace (DATEI)->InnerNr with ""
    endif
    if (DATEI)->(fieldPos( "AbPostNr" )) > 0
      replace (DATEI)->AbPostNr with 0
    endif

    // kopiere Lagerort
    if (DATEI)->(fieldpos("Lg_Raum")) > 0
      REPLACE (DATEI)->Lg_Raum WITH ARTIKEL->Lg_Raum
      REPLACE (DATEI)->Lg_Regal WITH ARTIKEL->Lg_Regal
      REPLACE (DATEI)->Lg_Fach WITH ARTIKEL->Lg_Fach
      REPLACE (DATEI)->Lg_Text WITH ARTIKEL->Lg_Text
    endif

    // neu 20200215: falls ArtNr ge�ndert Best.Nr nochmal eingeben, wg BesPostNr
    if upper(datei)=="FREMDEIN"
      replace (DATEI)->BestNr with ""
      replace (DATEI)->BesPostNr WITH 0
    endif

    // SetKey( K_F4, NIL )

  endif
RETURN(.t.)
/* EOF AV_ME_ArtNr_nach() */


/* Function AV_WKZ_ArtNr_nach()
*
* wird nach Eingabe der Artikel-Nr. ausgef�hrt bei Werkzeug-Modus
*/
static FUNCTION Av_WKZ_ArtNr_nach(oGet,datei)

  // 14.9.2012
  if empty(oGet:buffer)
    return .f.
  endif

  if oGet:changed()

    if ! check(oGet,"Artikel",.f.,.f.)
      return .f.
    endif

    if left(ARTIKEL->KonsigKdNr,5) $ "10167|10363" .and. getArtikelArt()=="B"
      Error(ACHTUNG+"Artikel ist als interner K-Lager Artikel deklariert.|         Bitte anderen "+;
        "Men�-Punkt verwenden.",.t.)
      return .f.
    endif

    if getArtikelArt()<>"W"
      Error(ACHTUNG+;
        "hier nur Werkzeuge zugelassen.|         Bitte anderen Men�-Punkt verwenden.",.t.)
      return .f.
    endif

    oGet:assign()
    dbskip(0)
    replace (DATEI)->Me with ARTIKEL->ME
    replace (DATEI)->Ort with getArtikelLagerOrt(11)
    replace (DATEI)->KostSt with ARTIKEL->KostNr
    EINHEIT->(dbseek(ARTIKEL->ME))

    // Innerbetr.Nr. l�schen, beu 20210423
    if (DATEI)->(fieldPos( "InnerNr" )) > 0
      replace (DATEI)->InnerNr with ""
    endif

    REPLACE (DATEI)->Lg_Raum WITH ARTIKEL->Lg_Raum
    REPLACE (DATEI)->Lg_Regal WITH ARTIKEL->Lg_Regal
    REPLACE (DATEI)->Lg_Fach WITH ARTIKEL->Lg_Fach
    REPLACE (DATEI)->Lg_Text WITH ARTIKEL->Lg_Text

    // SetKey( K_F4, NIL )
    // neu 20200215: falls ArtNr ge�ndert Best.Nr nochmal eingeben, wg BesPostNr
    if (DATEI)->(fieldpos("BestNr")) > 0
      replace (DATEI)->BestNr with ""
      replace (DATEI)->BesPostNr WITH 0
    endif

  endif
RETURN(.t.)
/* EOF AV_ME_ArtNr_nach() */



/*
*
* Setzt filter der Bestellposten auf akt. Art.nr vor Eingabe der Best.Nr.
*/
static FUNCTION BestNrVor(force)
LOCAL aktSel:=alias()

  default force:=.f.

  SetKey( K_F10 , {|| fremdOhneBest()} )

  select BesPost
  index on BESPOST->BestNr tag TEMP_IND2 TEMPORARY ADDITIVE ;
    for BESPOST->ArtNr == FREMDEIN->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes ;
    .and. BESAUS->Erledigt <> "J"
  select (aktSel)

  if force .or. (lastkey()<>K_UP .and. FREMDEIN->BesPostNr == 0)
    keyboard chr(HILFE_TASTE1)
  endif

return .t.
/** eof */

/*
* zeigt alle passenden Bestell-Posten an, auch die erledigten
*/
FUNCTION alleBesPost()

  select BesPost
  index on BESPOST->BestNr tag TEMP_IND2 TEMPORARY ADDITIVE ;
    for BESPOST->ArtNr == FREMDEIN->ArtNr

return .t.
/** eof */

/*
*
* Eingabe�berpr�fung der richtigen Best.Nr.
*/
static FUNCTION BestNrNach(oGet)
LOCAL einhText, numPosten, mBestPostNr

  // leer nicht m�glich
  if empty( oGet:buffer )
    keyboard chr(HILFE_TASTE1)
    return .f.
  endif

  if oGet:changed

    /* zur�ck erlaubt */
    if lastkey()==K_UP // changed 20120423, daf�r undo() // .and. ! oGet:changed
      oget:undo()
      BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr
      SetKey( K_F10 , nil )
      RETURN(.t.)
    endif

    /** falls ohne Best.Nr und Kommentar eingegeben */
    if trim(oGet:buffer)=="0" .and. ! empty(FREMDEIN->Kommentar)
      SetKey( K_F10 , nil )
      BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr
      return .t.
    endif

    // falls manuell eingegeben, pr�fe ob mehr als ein Posten vorhanden
    // FIXME: eine Abfrage inHelp oder so w�re besser,
    // sonst nimmt er nur bei der 1. Bestellung immer den ersten
    // bei folgenden Bestellungen fragt er, falls es mehr als 1 Posten gibt.
    if oGet:Buffer <> BESPOST->BestNr
      // suche passende Posten
      select BesPost
      go top // Index mit Filter noch gesetzt
      numPosten:=0
      do while ! BESPOST->(eof())
        if BESPOST->BestNr == oGet:Buffer
          if mBestPostNr == NIL
            mBestPostNr:=BESPOST->BestPostNr
          endif
          numPosten++
        endif
        skip
      enddo
      select Fremdein

      // kein Treffer
      if numPosten == 0
        SetKey( K_F10 , nil )
        return .f.

        // genau 1 Treffer -> ok, nehme 1.
      elseif numPosten == 1
        BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr
        BESPOST->(dbseek( mBestPostNr ))
        if BESPOST->(eof())
          Error(ACHTUNG+"Bestellposten nicht gefunden:"+str(mBestPostNr)+SCHWERER_FEHLER)
          bestNrVor(.t.) // reindex & manuelle Auswahl
          return .f.
        endif

        // mehrere Treffer -> manuelle Auswahl
      elseif numPosten > 1
        bestNrVor(.t.) // reindex & manuelle Auswahl
        return .f.
      endif

    endif

    BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr

    if ABBRUCH .and. FREMDEIN->BesPostNr == 0
      keyboard chr(K_UP) // zur�ck auf Artikel
      SetKey( K_F10 , nil )
      return .t.
    endif

    if BESPOST->ME <> ARTIKEL->ME
      Einheit->(dbseek(BESPOST->Me))
      einhText:=EINHEIT->Text
      Einheit->(dbseek(ARTIKEL->ME))

      // wird ME automat umgerechnet?
      if (FREMDEIN->ME==ARTIKEL->ME .and. BESPOST->ME==ARTIKEL->ME2) .or.;
        (FREMDEIN->ME==ARTIKEL->ME2 .and. BESPOST->ME==ARTIKEL->ME)
        Error(ACHTUNG+"Bestellung in    "+einhText+"|"+;
          "         Artikel Einheit: "+EINHEIT->Text+"||"+;
          "         Bitte Umrechnung in 2. Zeile beachten.",.t.)
        replace FREMDEIN->Me with BESPOST->ME
      else
        Error(ACHTUNG+"Bestellung in    "+einhText+"|"+;
          "         Artikel Einheit: "+EINHEIT->Text+"||"+;
          "         Bitte Einheit beachten!",.t.)
      endif
    endif
    replace FREMDEIN->BesPostNr with BESPOST->BesPostNr
    dbcommit()
    dbskip(0)
  else
    BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr
  endif // changed

  SetKey( K_F10 , nil )

RETURN .t.
/* EOF */



/*
* Ausdruck und verbuchen der Fertigmeldung
*/
static PROCEDURE Av_Eing_Druck
  // LOCAL MatEinNr:=Hole("MatEinNr",WRITE,.t.)
LOCAL Zeile:=0 , wert:=0 , i:=0
LOCAL merkSatz,orgValues

  select MatEing
  go top
  // Drucker("ON")
  // ? "MIKI PLASTIK KG  *** Wareneingangsprotokoll ***   vom",getUser():date
  // ? '------------------------------------------------------------------------------'
  // ? "Art-Nr.   Bezeichnung                   Auf.Nr.  Ka.-Preis     Menge L-Bestand"
  // ? '------------------------------------------------------------------------------'
  do while ! eof()
    if MATEING->Menge <> 0 .or. MATEING->Ausschuss <> 0
      Message("Artikel: @"+(ALIAS())->ArtNr+"@ wird verbucht.    Bitte warten...")
      select MatEing

      /* akt. Artikel, St�ckliste etc.  verbuchen  */
      av_fert_buch()
    endif

    ARTIKEL->(dbseek(MATEING->ArtNr))
    select MatEing

    /* Pr�fen ob auch Oberartikel automat. zu-gebucht werden soll -> Phoenix Artikel */
    if getParentPhoenix(MATEING->ArtNr)<>NIL
      // kopiere akt. Datensatz
      merkSatz:=MATEING->(recno())
      orgValues:=getCurrentValues()
      add_rec(0)
      setCurrentValues(orgValues)
      replace MATEING->ArtNr with AVPOST->AvNr
      // seit 20180820, buche kompletten Lagerbestand von Ph�nix-Unterartikel, wird oben bei av_fert_buch ja gebucht
      // dann wird auch bereits vorhandener Lagerbestand verpackt
      replace MATEING->Menge with int( ARTIKEL->LageBest /* MATEING->Menge */ / AVPOST->Menge)   // nur ganze Kartons fertigmelden
      replace MATEING->Ausschuss with 0
      dbskip(0)
      /* akt. Artikel, St�ckliste etc.  verbuchen  */
      av_fert_buch()
      select MatEing
      delete
      go (merkSatz)
    endif

    //deleteAlternatMat() // raus am 17.7.2021

    /* raus: 20161123 Satz erfolgreich verbucht+gedruckt -> l�schen */
    /* wieder rein: 20181123 deleteAlternatMat jetzt hier in loop */
    select MatEing
    delete
    skip
  enddo
  // ? '------------------------------------------------------------------------------'
  // ? 'Eingangs-Nr.',MatEinNr,space(31),'Warenwert Euro',str(wert,12,2)
  // ? '------------------------------------------------------------------------------'
  // ? 'ENDE DER LISTE'
  // ?
  // ? '##############################################################################'
  // for i:=1 to BLATT_VORSCHUB
  // ?
  // next
  // Drucker("OFF")

  pack

RETURN
/* eop */


/*
  * Ausdruck und verbuchen des FRemd-Einganges
*/
STATIC PROCEDURE Av_FremdEing_Druck()
  // LOCAL MatEinNr:=Hole("MatEinNr",WRITE,.t.)
LOCAL Zeile:=0 , wert:=0 , i:=0
LOCAL lagerMenge // wieviel wird dem Lager zugebucht in ME des Artikel, i.d.R. == FREMDEIN->Menge
LOCAL Ueberlief:=0, ueberliefProz, kom
LOCAL meText,mengenText

  select FremdEin
  go top
  // Drucker("ON")
  // ? "MIKI PLASTIK KG  *** Wareneingangsprotokoll ***   vom",getUser():date
  // ? '------------------------------------------------------------------------------'
  // ? "Art-Nr.   Bezeichnung                   Auf.Nr.  Ka.-Preis     Menge L-Bestand"
  // ? '------------------------------------------------------------------------------'
  do while ! eof()
    if FREMDEIN->Menge <> 0 .or. trim(FREMDEIN->BestNr)=="0"
      Message("Artikel: @"+(ALIAS())->ArtNr+"@ wird verbucht.    Bitte warten...")

      // Benutze BesAus als Semaphore (neu 25.3.2013)
      select BesAus
      SEEK FREMDEIN->BestNr
      if ! BESAUS->(eof())
        if ! rec_lock(5)
          Error(ACHTUNG+"Artikel: "+FREMDEIN->ArtNr+" konnte nicht verbucht werden.||"+;
            "         Bestellung bitte vorher schlie�en." + SCHWERER_FEHLER)
          select FRemdEin
          skip
          loop
        endif
      endif

      /** merke Mengeneinheit */
      lagerMenge:=FREMDEIN->Menge
      EINHEIT->(dbseek( FREMDEIN->ME ))
      meText:=EINHEIT->Text
      mengenText:=transstr(FREMDEIN->Menge,11,2) + " " + meText

      /* Best. zuweisen */
      SELECT BesPost
      BESPOST->(OrdSetFocus(4)) // BestPostNr
      // seit 5.11.2014 -> hier nicht mehr temp Index da:
      // we do not get an update on added records on local indices
      // see here: https://groups.google.com/forum/#!topic/harbour-users/cM5IfrEF110
      BESPOST->(dbseek( FREMDEIN->BesPostNr ))

      if BESPOST->(eof()) .and. trim(FREMDEIN->BestNr) <> "0"
        Error(ACHTUNG+"Artikel: "+FREMDEIN->ArtNr+" konnte nicht verbucht werden.||"+;
          "         Bestellposten gel�scht?" + SCHWERER_FEHLER)
        select FRemdEin
        skip
        loop
      endif

      /** abweichende Mengeneinheit ? */
      if ARTIKEL->ME <> FREMDEIN->Me
        // Umrechnung bekannt
        if ARTIKEL->ME2 == FREMDEIN->Me
          lagerMenge:=FREMDEIN->Menge / ARTIKEL->ME_Faktor

          // merke Einheit
          EINHEIT->(dbseek( ARTIKEL->ME ))
          mengenText += "entspr. " + alltrim(transstr(lagerMenge,11,2)) + " " + EINHEIT->Text
          EINHEIT->(dbseek( FREMDEIN->ME ))

        else
          Error(ACHTUNG +;
            FREMDEIN->ArtNr+" "+FREMDEIN->Me+" Umrechnung nicht bekannt !" + SCHWERER_FEHLER )
          return // we bail out
        endif
      endif

      if BESPOST->(eof()) .or. BESPOST->BestNr <> FREMDEIN->BestNr
        /* eof() d�rfte nur bei BestNr="0" passieren !*/
        UeberLief:=FREMDEIN->Menge
        trouble("fremdein","Fremdeingang Artikel: "+FREMDEIN->ArtNr+" ohne Bestellposten: " +;
          str(UeberLief) )

      else // EOF()

        if ! REC_LOCK(5)
          Error(ACHTUNG+"Artikel: "+FREMDEIN->ArtNr+" konnte nicht verbucht werden." +;
            SCHWERER_FEHLER)
          select FRemdEin
          skip
          loop
        endif

        ueberlief:=0
        if BESPOST->ME == FREMDEIN->Me
          replace BESPOST->GeliefGes WITH BESPOST->GeliefGes+FREMDEIN->Menge // hier in ME der Bestellung!
        else
          // ME abweichend -> umrechnen
          if FREMDEIN->ME == ARTIKEL->Me
            replace BESPOST->GeliefGes WITH BESPOST->GeliefGes + ;
              round( FREMDEIN->Menge * ARTIKEL->ME_Faktor ,2)
          else
            replace BESPOST->GeliefGes WITH BESPOST->GeliefGes + ;
              round( FREMDEIN->Menge / ARTIKEL->ME_Faktor ,2)
          endif
        endif

        // Email an H. Weiland wenn �berliefert > 20%
        ueberliefProz:=( ( BESPOST->GeliefGes / BESPOST->Menge ) - 1) * 100
        if ueberliefProz > 20
          EINHEIT->(dbseek( BESPOST->ME ))
          BESAUS->(dbseek( FREMDEIN->BestNr ))
          email(MAIN_EMAIL,;
            "Fremdeingang Art.Nr.:"+FREMDEIN->ArtNr+" �berliefert um "+str(ueberliefProz,3,0)+"%",;
            "|Best.Nr.: "+FREMDEIN->BestNr+" "+BESAUS->KurzName+;
            "|Benutzer: "+getUser():id+;
            "|Artikel : "+FREMDEIN->ArtNr+ARTIKEL->Bez1+;
            "|Bestellt: "+transstr( BESPOST->Menge ,11,2)+" "+EINHEIT->Text+;
            "|Eingang : "+mengenText+;
            "|Gel.Ges.: "+transstr(BESPOST->GeliefGes ,11,2)+" "+EINHEIT->Text+;
            "|Grund   : "+FREMDEIN->Kommentar)
        endif

      endif

      /* Lagerbestand verbuchen */
      SELECT Artikel
      rec_lock(0)

      // Kommentar f�r Bewegungsdatei festlegen
      if trim(FREMDEIN->BestNr)="0" .and. ! empty(FREMDEIN->Kommentar)
        kom:=alltrim(FREMDEIN->Kommentar)+" "+WARAUS_LSNR+FREMDEIN->LS_Nr
        // Mail an H. Weiland
        email(MAIN_EMAIL,;
          "Fremdeingang ohne Best.Nr. Art.Nr.:"+FREMDEIN->ArtNr+" Grund:"+FREMDEIN->Kommentar,;
          "Fremdeingang ohne Best.Nr.|"+;
          "|Benutzer: "+getUser():id+;
          "|Artikel : "+FREMDEIN->ArtNr+ARTIKEL->Bez1+;
          "|Menge   : "+mengenText+;
          "|Grund   : "+FREMDEIN->Kommentar)
      else
        kom:=WARAUS_BESTNR+FREMDEIN->BestNr+" "+WARAUS_LSNR+FREMDEIN->LS_Nr
      endif

      aendArtBest(lagerMenge,kom)

      // BestellBestand neu berechnen
      BestBestand(BEST_EXT,FREMDEIN->ArtNr)

      // Lagerort ge�ndert? FIXME: geht bei �berlieferung schief
      If ! empty( FREMDEIN->LG_Raum) .or. ! empty( FREMDEIN->Lg_Text)
        REPLACE ARTIKEL->Lg_Raum WITH FREMDEIN->Lg_Raum
        REPLACE ARTIKEL->Lg_Regal WITH FREMDEIN->Lg_Regal
        REPLACE ARTIKEL->Lg_Fach WITH FREMDEIN->Lg_Fach
        REPLACE ARTIKEL->Lg_Text WITH FREMDEIN->Lg_Text
      endif

      /* Kostenstelle */
      select FRemdEin
      // raus am 11.12.2009
      // rein am 18.02.2010 abends
      // ab 21.2.2010 nur noch bei DL = Dienstleistung
      // 20190314: raus wird jetzt bei ext. Bestellung abgebucht
      // if getArtikelArt()=="D"
      //   /*** Stk-Liste abbuchen **/
      // // FIXME: wirklich nur bei DL?
      // assignKostenStelle( KOSTST_BESTELLUNG , FREMDEIN->BestNr ,, FREMDEIN->Kommentar )

      //   /*** Stk-Liste abbuchen **/
      // SELECT AvPost
      // SEEK FREMDEIN->ArtNr+"M"
      // if .not. eof() // St�ckliste vorhanden

      // do while FREMDEIN->ArtNr = AVPOST->AvNr .and. .not. eof() .and. AVPOST->Art="M"

      // if AVPOST->Text="A" // Material ben�tigt
      // SELECT Artikel
      // SEEK AVPOST->ArtNr
      // if .not. eof()
      // REC_LOCK(0)
      // aendArtBest( FREMDEIN->Menge * AVPOST->Menge * (-1) , kom )

      // // Auftragsbestand neu berechnen
      // AufBestand()
      // endif
      // dbcommit()
      // UNLOCK
      // endif

      // // ** KostenStelle abbuchen
      // select FRemdEin
      // assignKostenStelle( KOSTST_BESTELLUNG , FREMDEIN->BestNr , AVPOST->Menge*(-1) ,;
      // FREMDEIN->Kommentar )

      // SELECT AvPost
      // skip
      // enddo
      // else
      //     /* keine St�ckliste vorhanden, nichts abbuchen ! */
      // endif
      // endif

      /* drucken */
      ARTIKEL->(dbseek(FREMDEIN->ArtNr))
      // ? OUT(FREMDEIN->ArtNr),ARTIKEL->Bez1,FREMDEIN->BestNr,if(ARTIKEL->Schluessel="H","%"," "),str(ARTIKEL->KaPr,9,2),FREMDEIN->Menge,ARTIKEL->LageBest
      // if .not. empty(ARTIKEL->Bez2)
      // ? out(space(len(FREMDEIN->ArtNr))),ARTIKEL->Bez2
      // endif
      if ARTIKEL->Schluessel="H"
        wert=wert+ARTIKEL->KaPr*FREMDEIN->Menge/100
      else
        wert=wert+ARTIKEL->KaPr*FREMDEIN->Menge
      endif

    endif

    /* Satz erfolgreich verbucht+gedruckt -> l�schen */
    select FremdEin
    replace FREMDEIN->Menge with 0 // werden sp�ter gel�scht
    skip
  enddo
  // ? '------------------------------------------------------------------------------'
  // ? 'Eingangs-Nr.',MatEinNr,space(31),'Warenwert Euro',str(wert,12,2)
  // ? '------------------------------------------------------------------------------'
  // ? 'ENDE DER LISTE'
  // ?
  // ? '##############################################################################'
  // Zeile:=FormFeed(Zeile)
  // pack
  // Drucker("OFF")

  // Protokoll(PRINT_P)

RETURN
/* eop */

/*
* FertigMeldung(MIKI)
*/

static FUNCTION Av_Fert_Buch
LOCAL aktOrd , buchMenge, buchMengeAB
LOCAL M_Kz,M_Kz_Aus , fremdMaterial:=.f.
LOCAL Material, mat, refWarausNr

  /* Artikel verbuchen und als Semaphore locken */
  select Artikel
  REC_LOCK(0)

  // falls keine Best. zugewiesen
  if alltrim(MATEING->InnerNr)="0" .or. empty(MATEING->InnerNr) .and. MATEING->Menge<>0
    Error(ACHTUNG+" Bestellung mu� zugeordnet werden !|Artikel:"+ARTIKEL->ArtNr+" Auftrag:"+;
      MATEING->InnerNr+"|"+INFO_LINE)
  endif

  /* Best. zuweisen */
  SELECT Inner
  SEEK ARTIKEL->ArtNr+MATEING->InnerNr
  if ! INNER->(eof()) // normaler innerbetr. Auftrag
    if ! REC_LOCK(5)
      Error(ACHTUNG+"Artikel: "+MATEING->ArtNr+" konnte nicht verbucht werden.")
      dbcommitall()
      dbunlockall()
      RETURN(.f.)
    endif

    // Hauptartikel
    fremdMaterial:=.f.
    M_Kz:="*"
    M_KZ_Aus:="A"

    // Buchmenge ist Menge OHNE �berlieferung
    buchMenge:=min( Max( INNER->Menge - INNER->GeliefGes , 0) , MATEING->Menge )
    buchMengeAB:=min( Max( INNER->MengeAB - INNER->GeliefGes , 0 ) , MATEING->Menge )

    // Best.Bestand abbuchen, falls innerbetr. Auftrag zugeordnet
    aendBestInt(buchMenge * (-1), buchMengeAB * (-1) , "Fertig.Meld. "+MATEING->InnerNr )

    // r�ckschreiben nach Inner
    replace INNER->GeliefGes WITH INNER->GeliefGes + MATEING->Menge
    // +MATEING->Ausschuss seit 6.3.2013 ohne!!!
    replace INNER->Ausschuss WITH INNER->Ausschuss + MATEING->Ausschuss

    // Neuer Datensatz �bernehme Menge als Vorgabe
    if INNER->Menge == 0
      replace INNER->Menge WITH MATEING->Menge
    endif

    select Inner

  else
    // 170er etc. Auftr�ge nur Kostenstellen-Buchung ohne Auftrag
    // kein Hauptartikel , also Zusatzmaterial

    fremdMaterial:=.t.
    M_KZ:="Z"
    M_KZ_Aus:="Q"
    // FIXME: wie Zusatzmaterial verbuchen
    buchMenge:=NIL // wird vorerst nicht gebucht!
    buchMengeAB:=NIL
    // suche Haupt-Artikel in Inner.dbf, au�er bei 100er Mappen das sind nur Kostenstellen
    if ! empty( MATEING->InLfdNr )
      aktOrd:=INNER->(indexOrd())
      INNER->(OrdSetFocus(3))
      INNER->(dbseek( MATEING->InLfdNr ))
      INNER->(OrdSetFocus(aktOrd))
      if INNER->(eof())
        Error(ACHTUNG+"Artikel: "+MATEING->ArtNr+" innerbetr. Auftrag:"+alltrim(MATEING->InLfdNr)+;
          " nicht gefunden."+SCHWERER_FEHLER)
      endif
    endif
  endif

  // Lagerbestand verbuchen
  SELECT Artikel
  // GesamtMenge (Gut & Aussschuss zubuchen)
  // Sonderfall nur Ausschuss gebucht 20221202
  if MATEING->Menge > 0
    refWarausNr:=aendArtBest(MATEING->Menge+MATEING->Ausschuss, WARAUS_INNERNR+;
      alltrim(MATEING->InnerNr),,INNER->InLfdNr)
  endif

  // Lagerbestand bei Ausschuss erniedrigen
  if MATEING->Ausschuss > 0
    SELECT Artikel
    aendArtBest(MATEING->Ausschuss*(-1),WARAUS_INNERNR+alltrim(MATEING->InnerNr)+" " +;
      WARAUS_AUSSCHUSS,,INNER->InLfdNr,refWarausNr)
  endif

  // Info: ab hier ehemals av_Stk_Buch

  /* ge�nderter LagerOrt ? */
  If ! empty( MATEING->LG_Raum) .or. ! empty( MATEING->Lg_Text)
    REPLACE ARTIKEL->Lg_Raum WITH MATEING->Lg_Raum
    REPLACE ARTIKEL->Lg_Regal WITH MATEING->Lg_Regal
    REPLACE ARTIKEL->Lg_Fach WITH MATEING->Lg_Fach
    REPLACE ARTIKEL->Lg_Text WITH MATEING->Lg_Text
  endif

  select Mateing
  assignKostenStelle( KOSTST_FERTIGMELDUNG , MATEING->InLfdNr ,, MATEING->Grund )

  /*** Stk-Liste abbuchen **/

  /* buche alle Unterartikel */
  Material:=Stueckliste():new( MATEING->ArtNr ):getBuchMaterial(AUFBESTAND_ABFRAGE, MATEING->Menge;
    + MATEING->Ausschuss)

  for each mat in Material
    if mat:Text == "A"
      SELECT Artikel
      SEEK mat:ArtNr
      if .not. eof()
        REC_LOCK(0)
        aendArtBest( mat:GesamtMenge * (-1) , WARAUS_INNERNR +;
          alltrim(MATEING->InnerNr)+" ->"+MATEING->Artnr,, MATEING->InLfdNr,refWarausNr)
        dbcommit()
        UNLOCK
      endif

      // ** KostenStelle abbuchen
      select Mateing
      assignKostenStelle(KOSTST_FERTIGMELDUNG , MATEING->InLfdNr , mat:menge*(-;
        1) , MATEING->Grund )

    endif

  next

  SELECT MatEing

  dbcommitall()
  dbunlockall()

RETURN(.t.)
/* EOP */




/************************************
*
*    WarenAusgang  MIKI
*
*/
PROCEDURE Av_MatAusg()
LOCAL aFelder:={} , getList:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  cls
  titel("M I K I  -  MATERIALENTNAHME")

  if ! open( "MatAusg", "Artikel", "Einheit", "Inner", "KostenSt", "AvPost" ,"AvAus", "KstStamm",;
    "Text")

    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  select Inner
  INNER->(OrdSetFocus(2)) // ArtNr+InnerNr
  select MATAUSG
  set relation to MATAUSG->Me into Einheit,to MATAUSG->ArtNr into Artikel
  // ,to MATAUSG->ArtNr+MATAUSG->InnerNr into Inner
  go top

  /* eingeloggter Benutzer best�tigen/�ndern */
  // Login_change(4,10,"K�rzel........:")
  // if ABBRUCH
  // cls
  // close data
  // RETURN
  // endif
  @ 4,10 say "K�rzel........: "
  qqout( getUser():id )

  SetKey( K_F5 , { || MyStkListLind( row() , 0 ) })
  SetKey( K_F6 , { || MatArtikelListe() })
  SetKey( K_F9 , { |p1,p2| warenEinOrt("MATAUSG",aFelder,p1,p2)} )

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_INDEX_FELD ]:=2
  aSpalte[EDIT_EDIT]:=.f.

  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F5)," @F5@=aufl." , { || MyStkListLind( row() , 0 ) }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F6)," @F6@=in Stkl", { || MatArtikelListe() }})
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_F9) ," @F9@=Lagerort �ndern " , { || warenEinOrt("MATAUSG",;
    aFelder) } } )

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. Av_MA_ArtNr_nach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="InnerNr"
  aSpalte[EDIT_TITEL]:="Auf.Nr. / Grund"
  aSpalte[EDIT_MASKE]:="@K !999"
  aSpalte[EDIT_BEFORE]:={ |oGet| InnerNrVor(oGet) }
  aSpalte[EDIT_AFTER]:={ |oGet| InnerNrNach(oGet,"MatAusg") }
  aSpalte[EDIT_MESSAGE]:="Innerbetr. Auftrag zuordnen.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Grund"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AFTER]:={ |oGet| ! emptyOr2Simple(oGet:Buffer,8) .or. lastkey()==K_UP }
  aSpalte[EDIT_MESSAGE]:="Grund eingeben.  Mind. 8 Zeichen           @F9@=kopieren   @ESC@=Ende"
  aSpalte[EDIT_POS_Y]:=2 // 3. Zeile
  aSpalte[EDIT_COPY_FIELD]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge/Best."
  aSpalte[EDIT_MESSAGE]:="Menge eingeben.       @F9@ = Lagerort �ndern"
  aSpalte[EDIT_MASKE]:="99999.99"
  aSpalte[EDIT_AFTER]:={ |oGet| maxConfirm( oGet , 10000 ) }
  // aSpalte[EDIT_BEFORE]:={ || SetKey( K_F3 , {|| Av_bestellt_anzeigen()} ),.t. }
  // aSpalte[EDIT_AFTER]:={ || SetKey( K_F3 , NIL),.t.}
  aSpalte[EDIT_POS_X]:=17


  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // akt. Bestand anzeigen
  aSpalte[EDIT_NAME]:="ARTIKEL->LageBest"
  aSpalte[EDIT_MASKE]:="999999.99"
  aSpalte[EDIT_POS_X]:=16 // 24 Zeichen rechts
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Rest-Menge anzeigen
  aSpalte[EDIT_NAME]:="if(!empty(InnerNr),Rest,'')"
  aSpalte[EDIT_TITEL]:="Rest"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // Einheit anzeigen
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kalk.Preis anzeigen
  aSpalte[EDIT_NAME]:="'Ka.Pr.:'+str(ARTIKEL->KaPr,9,2)"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_POS_X]:=3
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // LagerOrt
  aSpalte[EDIT_NAME]:="Ort"
  aSpalte[EDIT_TITEL]:="Lagerort"
  aSpalte[EDIT_MESSAGE]:="Lagerort eingeben."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kostenstelle
  aSpalte[EDIT_NAME]:="KostSt"
  aSpalte[EDIT_TITEL]:="KSt."
  aSpalte[EDIT_MASKE]:="@9@K"
  aSpalte[EDIT_AFTER]:={;
    |oGet| lastkey()==K_UP .or. empty((Alias())->ArtNr) .or.check(oGet,"KstStamm",.f.) }
  aSpalte[EDIT_MESSAGE]:="Kostenstelle mu� eingeben werden."
  aSpalte[EDIT_POS_X]:=0

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf)

  /* Auswahl-Menu */
  if MATAUSG->(reccount())>0 .and.;
    Message("Material-Entnahme verbuchen ?  (@J@/@N@)","JN","J") == "J"
    MatEntnahmeBuch()
  endif

  set Key K_F5 to
  set Key K_F6 to
  set Key K_F9 to
  close data
  cls
RETURN
/* EOP */

/** �ndern des Lagerorts in der aktuellen temp. Datei */
function warenEinOrt(datei,aFelder,p1,oget)
LOCAL GetList:={}
LOCAL aktColor , s01
LOCAL aSpalte, pos
LOCAL ob:=6 , li:=30
LOCAL confirmOld

  if ! alias() $ "MATEING|MATAUSG|FREMDEIN" .or. empty((alias())->ArtNr)
    return .t.
  endif

  if oGet <> nil
    // workaround: abweichender Feldname z.B. AusserNr
    if (pos:=getColPosByName(aFelder,oGet:Name)) == 0
      return .t.
    endif

    aSpalte:=aFelder[pos]
    aSpalte[EDIT_BS_AUSGABE]:=.t.
    ignore p1
  endif

  aktColor:=setcolor(COLWIN)
  s01:=savescreen()

  Fenster(ob+4,li-2,ob+6,li+32,"Artikel "+(alias())->ArtNr+":")
  @ ob+5,li say "Lagerort:" get (DATEI)->LG_Raum picture "@K 99" ;
    when Message("Lagerort @Raum@ eingeben.    @F12@=Auswahl") ;
    valid { |oGet| oFill(oGet,"0",.t.) .and. check(oGet,"LagerOrt",.t.,.t.) }
  @ ob+5,li+12 say "."
  @ ob+5,li+13 get (DATEI)->LG_Regal picture "@K 99" when Message("Lagerort @Regal@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ ob+5,li+15 say "."
  @ ob+5,li+16 get (DATEI)->LG_Fach picture "@K 999" when Message("Lagerort @Fach@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ ob+5,li+19 say "."
  @ ob+5,li+20 get (DATEI)->LG_Text picture "@K" when Message("Lagerort Zusatztext eingeben.")
  confirmOld:=Set(_SET_CONFIRM , .f.)
  read
  Set(_SET_CONFIRM , confirmOld)
  setcolor(aktColor)
  restscreen(,,,,s01)

  if ABBRUCH .and.;
    (! empty((DATEI)->Lg_Raum) .or. ! empty((DATEI)->Lg_Regal) .or. ! empty((DATEI)->Lg_Fach) .or. ! empty((DATEI)->Lg_Text)) .and. Message("Lagerort-�nderungen verwerfen?  (@J@/@N@)","JN")=="J"
    REPLACE (DATEI)->Lg_Raum WITH ""
    REPLACE (DATEI)->Lg_Regal WITH ""
    REPLACE (DATEI)->Lg_Fach WITH ""
    REPLACE (DATEI)->Lg_Text WITH ""
  else
    replace (DATEI)->Ort with getLagerOrt( (DATEI)->Lg_Raum, (DATEI)->Lg_Regal, (DATEI)->Lg_Fach,(;
      DATEI)->Lg_Text, len((DATEI)->Ort))
  endif

return .t.
/** eof */



/* Function AV_MA_ArtNr_nch()
*
* wird nach Eingabe der Artikel-Nr. ausgef�hrt
*/
FUNCTION Av_MA_ArtNr_nach(oGet)
  if oGet:changed()
    oGet:assign()
    dbskip(0)
    replace MATAUSG->Me with ARTIKEL->ME
    replace MATAUSG->Ort with getArtikelLagerOrt(11)
    replace MATAUSG->KostSt with ARTIKEL->KostNr
    // Innerbetr.Nr. l�schen, beu 20210423
    replace MATAUSG->InnerNr with ""

    // kopiere Lagerort
    REPLACE MATAUSG->Lg_Raum WITH ARTIKEL->Lg_Raum
    REPLACE MATAUSG->Lg_Regal WITH ARTIKEL->Lg_Regal
    REPLACE MATAUSG->Lg_Fach WITH ARTIKEL->Lg_Fach
    REPLACE MATAUSG->Lg_Text WITH ARTIKEL->Lg_Text


  endif
RETURN(.t.)
/* EOF AV_MA_ArtNr_nach() */

/**
* wird vor Eingabe der innerbetr. Nr ausgef�hrt
*/
static FUNCTION InnerNrVor()
LOCAL aktSel:=select()

  select Inner
  index on INNER->InnerNr+INNER->ArtNr tag TEMP_IND3 TEMPORARY ADDITIVE ;
    for ARTIKEL->Artnr==INNER->ArtNr .and. INNER->Erledigt<>"J" .and. isInnerHauptArbeitsgang()

  select (aktSel)

return .t.
/** eof */

/* Function Inn_nach_Alle()
  *
  * wird nach Eingabe Innerbetr. Nr. ausgef�hrt
  * bei Materialentnahme MIKI
  * Achtung hier wird nicht gepr�ft ob Art.Nr. zu innerbetr. Auftrag geh�rt
  * -> buchen von Zusatzmaterial m�glich
  *
  * Auftrag muss aber existieren
*/
FUNCTION InnerNrNach(oGet,Datei)
LOCAL akt_sel:=select() , merk_Satz,okay:=.f.,stklistFound:=.f.
LOCAL s001,merkInnerRec, merkInnerNr, merkLiefKW, merkFertKW
LOCAL aktOrd:=INNER->(indexOrd())
LOCAL werkzeuge, werkzeug, found:=.f., lfdNr

  /* zur�ck erlaubt */
  if lastkey()==K_UP
    oget:undo()
    RETURN(.t.)
  endif

  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
    RETURN(.f.)
  endif

  if oGet:changed()

    oGet:varput(getInnerShifted(val(oGet:buffer)))
    oGet:updateBuffer()

    /* Ausnahme Kostenstelle bei 1xx - Auftr�gen */
    if alltrim(oGet:Buffer) $ getProperty("Miki.av.inner.kostenst","")

      // if ! getUser():id $ "JG|AB|MW"
      // Error(ACHTUNG+"Nur AB + MW k�nnen direkt auf Kostenstelle buchen.")
      // return .f.
      // endif

      KOSTENST->(dbseek(right(oGet:Buffer,2)))
      if ! KOSTENST->(eof())
        replace (DATEI)->KostSt with right(oGet:Buffer,2)
        okay:=.t.
      endif

    endif

    if ! okay
      select Inner
      INNER->(OrdSetFocus(2)) // wieder ArtNr+Auftr.Nr
      seek ARTIKEL->ArtNr+oGet:Buffer
      if eof()
        INNER->(OrdSetFocus(1)) // Nur pr�fen nach Inner-Auftr.Nr.
        seek oGet:Buffer
        INNER->(OrdSetFocus(2)) // wieder ArtNr+Auftr.Nr
        merk_satz:=ARTIKEL->(recno())
        if eof()
          Error(ACHTUNG+"Auftrag: "+oGet:Buffer+" nicht vorhanden !")
          INNER->(OrdSetFocus( aktOrd )) // wieder auf index mit for clause
          select (akt_sel)
          RETURN(.f.)
        else
          // such alte Artikel-Nr, wurde evtl. ge�ndert???
          if sucheAlternativeNummer(db_info("Artikel"),(DATEI)->ArtNr,.f.) // ohne Abfrage
            merkInnerRec:=INNER->(recno())
            INNER->(dbseek(ARTIKEL->ArtNr+oGet:Buffer))
            if ! INNER->(eof())
              s001:=savescreen()
              Error(ACHTUNG+"Artikel-Nr. wurde ge�ndert: "+ARTIKEL->AltArtNr+"->"+;
                ARTIKEL->ArtNr,ERR_NO_WAIT)
              if Message("Mit neuer Artikel-Nr @"+ARTIKEL->ArtNr+;
                "@ weiterarbeiten?  (@J@/@N@)","JN")=="J"
                // unsch�n aber einfach: keyboard zur�ck, InnerNr muss nochmal eingegeben werden
                keyboard chr(K_UP)+ARTIKEL->ArtNr+chr(K_RETURN)
              endif
              restscreen(,,,,s001)
              ARTIKEL->(dbgoto(merk_Satz))
              INNER->(OrdSetFocus( aktOrd )) // wieder auf index mit for clause
              select (akt_sel)
              return .f.
            endif
            INNER->(dbgoto(merkInnerRec))
          else
            // // es ex. der innbetr. Auftrag f�r einen anderen Artikel
            // // pr�fen ob in St�ckliste
            // select AVPOST
            // AVPOST->(dbseek(INNER->ArtNr+"M"))
            // do while ! AVPOST->(eof()) .and. AVPOST->AvNr==INNER->ArtNr .and. AVPOST->Art=="M"
            // if AVPOST->ArtNr==(DATEI)->ArtNr // Bingo

            // 17.7.2021 komplett raus, nur noch Artikel aus innerbetr. Auftrag, hmmm....
            // s001:=savescreen()
            // Error(ACHTUNG+"Auftrag "+oGet:Buffer+" ist Artikel "+INNER->ArtNr+" zugeordnet!",ERR_NO_WAIT)
            // if Message("Artikel "+(DATEI)->ArtNr+" auf diesen Auftrag buchen? (@J@/@N@)","JN")=="J"
            // stklistFound:=.t.
            // endif
            // restscreen(,,,,s001)
            // 17.7.2021

            // exit
            // endif
            // skip
            // enddo

            // 2.11.24 alle Artikel im selben Werkzeug, da Gruppe in Fertigung evtl. ge�ndert
            werkzeuge:=Stueckliste():new(INNER->ArtNr):getWerkzeuge()
            if len(werkzeuge) > 0
              // already on correct inner record see above
              lfdNr:=INNER->InLfdNr
              merkInnerNr:=INNER->InnerNr
              merkLiefKW:=INNER->Lief_KW
              merkFertKW:=INNER->Fert_KW
              INNER->(OrdSetFocus(3)) // InLfdNr
              INNER->(dbseek(lfdNr))
              do while ! INNER->(eof()) .and. lfdNr == INNER->InLfdNr .and. .not. found
                for each werkzeug in werkzeuge
                  select Mehrfach
                  MEHRFACH->(dbseek(ARTIKEL->ArtNr+werkzeug)) // index auf Artikel + Werkzeug
                  if ! MEHRFACH->(eof())
                    found:=.t.
                    // add new record to inner.dbf
                    select Inner
                    add_rec(0)
                    replace INNER->ArtNr WITH ARTIKEL->ArtNr
                    replace INNER->Bez1 WITH ARTIKEL->Bez1
                    replace INNER->Bez2 WITH ARTIKEL->Bez2
                    replace INNER->InLfdNr WITH hole("InlfdNr",WRITE,.t.)
                    replace INNER->InnerNr with merkInnerNr
                    replace INNER->Lief_KW with merkLiefKW
                    replace INNER->Fert_KW with merkFertKW
                    replace INNER->Grund with INNER_FERTIGMELDUNG
                    exit
                  endif
                next
                skip
              enddo
            endif
            if .not. found
              restscreen(,,,,s001)
              ARTIKEL->(dbgoto(merk_Satz))
              INNER->(OrdSetFocus( aktOrd )) // wieder auf index mit for clause
              select (akt_sel)
              return .f.
            endif
          endif

          // wieder ge�ndert zuerst am 22.4.2012 raus (s.o.), jetzt wieder rein 21.6.2012
          /* kostenstelle von Hauptartikel des zugeh�r. Auftrags */
          ARTIKEL->(dbseek(INNER->ArtNr))
          replace (DATEI)->KostSt with ARTIKEL->KostNr
          ARTIKEL->(dbgoto(merk_Satz))

        endif
      else
        /* kostenstelle Hauptartikel default */
        replace (DATEI)->KostSt with ARTIKEL->KostNr
      endif
      replace (DATEI)->Rest with Max(INNER->Menge-INNER->GeliefGes,0)
      replace (DATEI)->InLfdNr with INNER->InLfdNr
      if (DATEI)->(fieldPos( "AbPostNr" )) > 0
        replace (DATEI)->AbPostNr with INNER->AbPostNr
      endif
    endif
    INNER->(OrdSetFocus( aktOrd )) // wieder auf index mit for clause
    select (akt_sel)
  endif

RETURN(.t.)
/* EOF InnerNrnach */

static function clearTempIndex()
  // inner index mit for clause wieder l�schen
  INNER->(OrdDestroy(TEMP_INDEX))
  INNER->(OrdSetFocus(2))
return .t.
/** eof */

static function clearFremdTempIndex()
  BESPOST->(OrdDestroy(TEMP_IND2))
  BESPOST->(OrdSetFocus(TEMP_INDEX)) // BesPostNr
return .t.
/** eof */

/* Function Av_Ausg_Buch()
*
*  verbucht einen Datensatz aus Matausg.dbf (MIKI)
*/
static FUNCTION Av_Ausg_Buch

  SELECT Artikel
  IF ! REC_LOCK(5)
    Error(ACHTUNG+"Artikel:  "+MATAUSG->ArtNr+" konnte nicht verbucht werden.")
    RETURN(.f.)
  endif

  /* Kostenstelle schreiben */
  select Matausg
  // assignKostenStelle( KOSTST_WARENAUSGANG , MATAUSG->InnerNr , -1 )
  assignKostenStelle( KOSTST_WARENAUSGANG , MATAUSG->InLfdNr , -1 , MATAUSG->Grund )

  /* Artikel verbuchen */
  aendArtBest(MATAUSG->Menge*(-1),WARAUS_MATAUSG2 +;
    alltrim(MATAUSG->InnerNr)+" "+MATAUSG->Grund,,MATAUSG->InLfdNr)

  // debug
  if MATAUSG->InLfdNr == NIL .and. ! file("lfdnr.out")
    troubleEmail("InLfdNr ist NIL: "+ARTIKEL->ArtNr+str(MATAUSG->Menge,13,2))
  endif

  /* LagerOrt r�ckschreiben */
  /* ge�nderter LagerOrt ? */
  If ! empty( MATAUSG->LG_Raum) .or. ! empty( MATAUSG->Lg_Text)
    REPLACE ARTIKEL->Lg_Raum WITH MATAUSG->Lg_Raum
    REPLACE ARTIKEL->Lg_Regal WITH MATAUSG->Lg_Regal
    REPLACE ARTIKEL->Lg_Fach WITH MATAUSG->Lg_Fach
    REPLACE ARTIKEL->Lg_Text WITH MATAUSG->Lg_Text
  endif

  dbcommitall()
  unlock all

RETURN(.t.)
/* EOP Av_Ausg_Buch */


/* Procedure MatEntnahmeBuch
*
* Ausdruck und verbuchen des Warenausgangs MIKI
*/
static Procedure MatEntnahmeBuch
LOCAL Zeile:=0 , wert:=0 , i:=0

  INNER->(OrdSetFocus(1)) // aktive InnerNr

  select MatAusg
  go top
  do while ! eof()
    if MATAUSG->Menge <> 0
      Message("Artikel: @"+(ALIAS())->ArtNr+"@ wird verbucht.    Bitte warten...")
      /* Artikel verbuchen */
      if ! Av_Ausg_Buch()
        select MatAusg
        skip
        loop
      endif
      ARTIKEL->(dbseek(MATAUSG->ArtNr))

      if ARTIKEL->Schluessel=="H"
        wert=wert+ARTIKEL->KaPr*MATAUSG->Menge/100
      else
        wert=wert+ARTIKEL->KaPr*MATAUSG->Menge
      endif

    endif
    /* Satz erfolgreich verbucht+gedruckt -> l�schen */
    select MatAusg
    delete
    skip
  enddo
  pack

RETURN
/* EOP MatEntnahmeBuch */


/*** Procedure av_KFremd()     *********************************
* Wareneingang (Fremd - KLager)
*
*/
PROCEDURE Av_KFremd
LOCAL aFelder:={} , getList:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL mKundNr

  cls
  titel("FREMD -MATERIAL / K-Lager - Beistellteile")

  if !;
    open( "KFREMDEI", "Artikel", "Einheit", "KostenSt", "AvPost", "KstStamm", "Kunden","BesPost","BesAus")

    cls
    close data
    RETURN
  endif

  /* Relationen setzen */
  select KFREMDEI
  set relation to KFREMDEI->Me into Einheit,to KFREMDEI->ArtNr into Artikel
  go top

  /* eingeloggter Benutzer best�tigen/�ndern */
  // Login_change(4,10,"K�rzel........:")

  // if ABBRUCH
  // cls
  // close data
  // RETURN
  // endif
  @ 4,10 say "K�rzel........: "
  qqout( getUser():id )

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_INDEX_FELD ]:=1
  aKopf[EDIT_FKT_IMMER]:={ || checke_LSNr(aKopf,aFelder) } // wird nach Eingabe des Posten ausgef�hrt

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  // aSpalte[EDIT_BEFORE]:=
  // { || SetKey( K_F4 , {|| Hilfe("HONSELARTIKEL",getNew(),"" ) } ),.t. }
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and.;
    Av_ME_ArtNr_nach(oGet,"KFREMDEI",.t.) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:=;
    "Artikel-Nummer eingeben.      @F4@=Honsel-Nr.     @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->HartNr"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge/Best."
  aSpalte[EDIT_MASKE]:="99999.99"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_POS_X]:=1
  aSpalte[EDIT_AFTER]:={ |oGet| maxConfirm( oGet , 10000 ) }
  aSpalte[EDIT_MESSAGE]:="Menge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // akt. Bestand anzeigen
  aSpalte[EDIT_NAME]:="ARTIKEL->LageBest"
  aSpalte[EDIT_MASKE]:="999999.99"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kunde anzeigen
  aSpalte[EDIT_NAME]:="left(ARTIKEL->KonsigKdNr,5)"
  aSpalte[EDIT_TITEL]:="Kunde"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  aSpalte[EDIT_NAME]:="LS_Nr"
  aSpalte[EDIT_TITEL]:="Lieferschein.Nr."
  aSpalte[EDIT_AFTER]:={ |oGet|len(alltrim(oGet:buffer))>2 }
  aSpalte[EDIT_MESSAGE]:="Lieferschein-Nummer eingeben.     @F9@=kopieren"
  aSpalte[EDIT_POS_Y]:=1 // 2. Zeile
  aSpalte[EDIT_COPY_FIELD]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit anzeigen
  aSpalte[EDIT_NAME]:="Me"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Einheit anzeigen
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // LagerOrt
  aSpalte[EDIT_NAME]:="Ort"
  aSpalte[EDIT_TITEL]:="Lagerort / KSt."
  aSpalte[EDIT_MESSAGE]:="Lagerort eingeben."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kostenstelle
  aSpalte[EDIT_NAME]:="KostSt"
  // aSpalte[EDIT_TITEL]:="KSt"
  aSpalte[EDIT_MASKE]:="@9@K"
  aSpalte[EDIT_AFTER]:={;
    |oGet| lastkey()==K_UP .or. empty((Alias())->ArtNr) .or.check(oGet,"KstStamm",.f.) }
  aSpalte[EDIT_MESSAGE]:="Kostenstelle mu� eingeben werden."
  aSpalte[EDIT_POS_X]:=12
  aSpalte[EDIT_POS_Y]:=1

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf)

  /* Auswahl-Menu */
  if KFREMDEI->(reccount())>0 .and.;
    Message("Fremd-Material verbuchen ?  (@J@/@N@)","JN","J") == "J"
    go top
    do while ! eof()
      if KFREMDEI->Menge <> 0
        Message("Artikel: @"+(ALIAS())->ArtNr+"@ wird verbucht.    Bitte warten...")

        /* Lagerbestand verbuchen */
        SELECT Artikel
        if ! rec_lock(5)
          Error(ACHTUNG+"Artikel @"+ARTIKEL->ArtNr+"@ konnte nicht verbucht werden !|Falscher "+;
            "Lager- und Bestellbestand."+SCHWERER_FEHLER)
        else

          aendArtBest(KFREMDEI->Menge,WARAUS_FREMD_LS + KFREMDEI->LS_Nr)
          aendArtKBest(KFREMDEI->Menge,WARAUS_KLAG_FREMD_LS + KFREMDEI->LS_Nr)

          // seit 24.2.15 mit r�ckschreiben in Bestellung
          select BesPost
          BESPOST->(OrdSetFocus(3)) // BESPOST->ArtNr+BESPOST->LiefNr+mydescend(BESPOST->AufDat)

          mKundNr:=ARTIKEL->KonsigKdNr
          // map Honsel/VVG KundenNr to LieferantenNr.
          if left(ARTIKEL->KonsigKdNr,5) == KDNR_HONSEL
            mKundNr:=LIEFNR_HONSEL
          elseif left(ARTIKEL->KonsigKdNr,5) == KDNR_VVG
            mKundNr:=LIEFNR_VVG
          endif

          dbseek( KFREMDEI->ArtNr + mKundNr )
          if ! BESPOST->(eof())
            select BesAus
            BESAUS->(dbseek(BESPOST->BestNr))
            if BESAUS->(eof()) .or. ! rec_lock(0)
              Error(ACHTUNG+"Artikel @"+ARTIKEL->ArtNr+"@ Bestellung:"+BESPOST->BestNr+;
                " konnte nicht abgebucht werden !"+SCHWERER_FEHLER)
            else
              select BesPost
              if rec_lock(0)
                replace BESPOST->GeliefGes WITH BESPOST->GeliefGes + KFREMDEI->Menge
              endif
              dbcommit()
              dbunlockall()
              // BestBestand(BEST_EXT,BESPOST->ArtNr)
            endif
            checkBestellErledigt( BESPOST->Bestnr )
          endif
        endif

      endif

      /* Satz erfolgreich verbucht+gedruckt -> l�schen */
      select KFREMDEI
      delete
      skip
    enddo
    pack
  endif

  close data
  cls
RETURN
/* EOP AV_KFremd */

/** Pr�ft ob Lieferschein-Nummer eingegeben ist */
Function checke_LSNr(aKopf,aFelder)
LOCAL x

  if KFREMDEI->Menge > 0 .and. empty(KFREMDEI->LS_NR)
    Error(ACHTUNG+" Eingabe der Lieferschein-Nummer ist Pflicht!",.t.)
    // suche Feld mit KW (kannn je nach Programm-Art variieren
    x:=getColPosByName(aFelder,"LS_Nr")
    if x==0
      troubleEmail("LS_Nr nicht gefunden.")
    else
      aKopf[EDIT_GET_OFFSET]:=x
    endif

    return .f.
  else
    aKopf[EDIT_GET_OFFSET]:=1 // starte wieder beim 1. Feld
  endif
return .t.


/** fragt den Grund bei Wareneingang ohne Best.Nr. ab */
static function fremdOhneBest()
LOCAL GetList:={}
LOCAL s001:=savescreen()
  _thread static lastGrund

  if lastGrund!=nil .and. empty(FREMDEIN->kommentar)
    replace FREMDEIN->kommentar with lastGrund
  endif

  setcolor(COLWIN)
  Fenster(7,30,9,70)
  @ 8,32 say "Grund:" get FREMDEIN->kommentar valid ! emptyOr2Simple(FREMDEIN->kommentar,3);
    when Message("Grund f�r Eingang ohne Bestellnummer eingeben (mind 3 Zeichen)  @F12@=Auswahl  "+;
    "@ESC@=Ende")
  read
  setcolor(COLNOR)
  restscreen(,,,,s001)
  if ! ABBRUCH
    // merke akt. Grund
    if ! empty(FREMDEIN->kommentar)
      lastGrund:=FREMDEIN->kommentar
    endif

    replace FREMDEIN->BestNr with "0"

    // gehe auf n�chstes Feld
    keyboard chr(K_RETURN)
  endif
return ! ABBRUCH

/** schreibt die aktuelle Buchung nach KostenSt.dbf
  *
  * Artikel muss selektiert sein!
  */
static procedure assignKostenStelle( mArt , Nummer , faktor , Grund )
LOCAL aktDatei:=alias()
  If .not. empty((AKTDATEI)->KostSt)

    default faktor:=1

    // ** KostenStelle zubuchen
    SELECT KostenSt
    ADD_REC(0)
    REPLACE KOSTENST->KostNr WITH (AKTDATEI)->KostSt
    REPLACE KOSTENST->Art WITH mArt
    REPLACE KOSTENST->AuftrNr WITH Nummer // if( nurBest , (AKTDATEI)->BestNr , (AKTDATEI)->InLfdNr )
    REPLACE KOSTENST->ArtNr WITH ARTIKEL->ArtNr
    REPLACE KOSTENST->KalkPr WITH ARTIKEL->KaPr
    REPLACE KOSTENST->Menge WITH (AKTDATEI)->Menge * faktor // ?? +MATEING->Ausschuss
    if ARTIKEL->Schluessel="H"
      REPLACE KOSTENST->Wert WITH (AKTDATEI)->Menge*ARTIKEL->KaPr/100 * faktor
    else
      REPLACE KOSTENST->Wert WITH (AKTDATEI)->Menge*ARTIKEL->KaPr * faktor
    endif
    if Grund <> NIL
      REPLACE KOSTENST->Grund WITH Grund
    endif
    dbcommit()
    unlock

  endif
return
/** eop */

/** �berpr�ft nach Beendigung des Editos ob g�ltige ME eingegeben wurde */
static Function checkeME(aKopf,aFelder)

  if ! empty(FREMDEIN->ArtNr) .and. FREMDEIN->Menge <> 0
    if empty( FREMDEIN->ME ) .or. ! FREMDEIN->ME $ ARTIKEL->ME+ARTIKEL->ME2
      Error(ACHTUNG+" Mengeneinheit muss eingegeben werden.",.t.)
      aKopf[EDIT_GET_OFFSET]:=getColPosByName(aFelder,"ME")
      return .f.
    endif
  endif

return .t.
/** eof */

/** pr�ft ob die aktuelle selektierte Bestellung erledigt ist und markiert diese entsprechend. */
procedure checkBestellErledigt(MBestNr)
LOCAL aktOrd:=BESPOST->(indexord())
LOCAL erledigt:=.t.
LOCAL erledigt_fast:=.t.

  BESPOST->(OrdSetFocus(1)) // BestNr

  select BesPost
  BESPOST->(dbseek( MBestNr ))
  if BESAUS->Erledigt<>"J" .and. ! BESAUS->(eof())
    do while ! BESPOST->(eof()) .and. MBestNr == BESPOST->BestNr .and. (erledigt .or.;
      erledigt_fast)
      if len(alltrim(BESPOST->ArtNr)) > FRACHT_LAENGE // ignoriere Fracht & Verpackung komplett
        erledigt:=(round(BESPOST->Menge,0) <= round(BESPOST->GeliefGes,0))
        erledigt_fast:=(round(BESPOST->Menge*.8,0) <= round(BESPOST->GeliefGes,0)) // minus 20%
      endif
      skip
    enddo
    if .not. erledigt .and. erledigt_fast
      erledigt:=Message("Bestellung "+MBestNr+" fast komplett beliefert.  Als erledigt markieren? "+;
        "(@J@/@N@)","JN"," ")=="J"
    endif
    if erledigt
      select Besaus
      BESAUS->(dbseek( MBestNr )) // brauchen wir, da BesPost geskipped wurde!
      if ! BESAUS->(eof()).and. BESAUS->erledigt<>"J"
        if ! rec_lock(5)
          Error(TRY_AGAIN)
        else
          replace BESAUS->erledigt with "J"
          dbcommit()
          dbunlock()
          Message("Bestellung: "+MBestNr+;
            " wurde komplett geliefert und als erledigt markiert.   @Taste@","@")
        endif
      endif
    endif
  endif

  BESPOST->(OrdSetFocus(aktOrd)) // BesPostNr
return
/** eop */


/* FertigMeldung MIKI STORNO */
PROCEDURE Av_MateingStorno()
LOCAL mArtNr
LOCAL GetList:={}
LOCAL TempFile:=TEMP+BACKSLASH+"StorFM"+getUser():getLongID()
LOCAL Zeile:=0 , stornoWarausNr

  cls
  titel("STORNO: F E R T I G M E L D U N G")

  if ! open( "Artikel" , "Einheit" , "Waraus", "Inner", "AvPost")
    cls
    close data
    RETURN
  endif

  do while ! ABBRUCH

    mArtNr:=space(len(ARTIKEL->ArtNr))
    @ 2,0 clear
    @ 2,0 say "Artnr: " get mArtNr valid { |oGet| check(oGet,"Artikel",.f.,.f.) };
      when Message("Bitte Artikel-Nummer eingeben.    @F12@=Hilfe")
    read

    if ! ABBRUCH .and. ! empty(mArtNr)
      @ 2,20 say ARTIKEL->Bez1
      @ 3,20 say ARTIKEL->Bez2
      Message("Fertigmeldungen werden gesucht.  Bitte warten...")
      select Waraus
      set filter to
      copy to (tempFile) for WARAUS->ArtNr == mArtNr .and. ;
        len(HB_RegEx("^"+WARAUS_INNERNR+"[0-9]{3,4}$",trim(WARAUS->Programm))) > 0
      sele 0
      use (tempFile) alias FertigMeld EXCL
      go top
      Hilfe("StornoFertigmeldung",getnew(),"Blubb")

      if ! ABBRUCH
        @ 4,0 clear
        qout("Art.Nr.      Bezeichnung                    Bew.Dat.    Eingang    Ausgang")
        qout("==========================================================================")
        qout(OUT(FERTIGMELD->ArtNr),FERTIGMELD->Bez1,FERTIGMELD->Datum, if(FERTIGMELD->Menge>0,;
          FERTIGMELD->Menge,space(10)), if(FERTIGMELD->Menge<0,FERTIGMELD->Menge,space(10)))
        qout(space(len(OUT(FERTIGMELD->ArtNr))) , FERTIGMELD->Bez2)

        if message("Fertigmeldung wirklich stornieren? (@J@/@N@)","JN")=="J"
          stornoWarausNr:=FERTIGMELD->WarausNr
          Message("Buchungen werden gesucht.  Bitte warten...")
          select WarAus
          if stornoWarausNr == 0 // old sytle
            set filter to WARAUS->Mod_Date == FERTIGMELD->Mod_Date ;
              .and. trim(FERTIGMELD->Programm) $ WARAUS->Programm;
              .and. abs(FERTIGMELD->Mod_Time - WARAUS->Mod_Time) < 5 // within 5 seconds, unsch�n :(
          else // new style now w/ reference nr.
            set;
              filter to WARAUS->RefWarNr == stornoWarausNr .or. WARAUS->WarausNr == stornoWarausNr
          endif
          go top

          Drucker("BS")
          ? "Folgende Buchungen wurden storniert:"
          ?
          ? "Art.Nr.    Bezeichnung                    Bew.Dat.    Eingang    Ausgang   Bestand "+;
            "K-Bestand Kz Programm"
          ? "===================================================================================="+;
            "==================="
          do while ! WARAUS->(eof())
            if FERTIGMELD->ArtNr == WARAUS->ArtNr ;
              .or. StueckListe():new( FERTIGMELD->ArtNr ):containsChild( WARAUS->ArtNr , .t. )
              Av_Fert_Storno(mArtNr)
              Message("Buche: " + out(WARAUS->ArtNr))
              // markiere als storniert
              rec_lock(0)
              replace WARAUS->Programm with trim(WARAUS->Programm)+" "+WARAUS_STORNIERT
              dbcommit()
              dbunlock()

              // anzeigen
              ? OUT(WARAUS->ArtNr),WARAUS->Bez1,WARAUS->Datum,;
                if(WARAUS->Menge>0,WARAUS->Menge,space(10)),;
                if(WARAUS->Menge<0,WARAUS->Menge,space(10)),WARAUS->Best,WARAUS->KonsigBest,WARAUS->Mod_User,;
                waraus2Zeige(WARAUS->Programm),if(empty(WARAUS->InLfdNr),'','Lfd.Nr. '+alltrim(WARAUS->InLfdNr))
              ? space(len(OUT(WARAUS->ArtNr))) , WARAUS->Bez2
            endif
            skip
          enddo
          Drucker("OFF")
        endif
      endif
      close FertigMeld
    endif
    if ! ABBRUCH
      AufBestand()
      BestBestand()
    endif
  enddo

  close data
  ferase(tempFile)
return
/** eop */

/*
* FertigMeldung (Storno), storniert Buchung aus av_fert_buch()
*/

static FUNCTION Av_Fert_Storno(mArtNr)
LOCAL aktSel:=alias()
LOCAL aktRec:=recno()

  /* Artikel verbuchen und als Semaphore locken */
  select Artikel
  ARTIKEL->(dbseek( WARAUS->ArtNr ))
  REC_LOCK(0)

  /* Best. zuweisen */
  if ! empty(WARAUS->InLfdNr) .and. WARAUS->ArtNr==mArtNr
    SELECT Inner
    OrdSetFocus(3) // InLfdNr
    INNER->(dbSEEK(WARAUS->InLfdNr))
    if INNER->(eof()) // normaler innerbetr. Auftrag
      troubleEmail("InLfdNr " + WARAUS->InLfdNr + " nicht gefunden.")
    else
      rec_lock(0)

      if ! INNER->(eof()) .and. trim(INNER->Grund)==INNER_FERTIGMELDUNG
        // l�schen wenn neu angelegt �ber FertigMeldung
        delete
      else
        // r�ckschreiben nachInner Storno
        if ! WARAUS_AUSSCHUSS $ WARAUS->Programm
          replace INNER->GeliefGes WITH max(INNER->GeliefGes - WARAUS->Menge,0)
        else
          replace INNER->Ausschuss WITH max(INNER->Ausschuss - WARAUS->Menge,0)
        endif
      endif
      dbcommit()
      dbunlock()
    endif
  endif


  // Lagerbestand r�ckbuchen
  SELECT Artikel
  aendArtBest(WARAUS->Menge*(-1),trim(WARAUS->Programm)+" "+ WARAUS_STORNO ,,INNER->InLfdNr)

  // Hinweis: Kostenstelle wird (noch) nicht storniert
  // assignKostenStelle( KOSTST_FERTIGMELDUNG , MATEING->InLfdNr ,, MATEING->Grund )

  select (aktSel)
  dbgoto(aktRec)

RETURN(.t.)
/* EOP */



/* Modul Material.prg
*
* Alles zu Material
*/
#include "miki.ch"
#include "Zeige.ch"

#define STACK_PUSH 1
#define STACK_POP_ALL 2

PROCEDURE Mat_erfassen()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX], ausw

MEMVAR anzWochen
PRIVATE anzWochen:=1

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

  cls
  Titel("Material-Datei bearbeiten")

  if getUser():id $ "MW/JG"
    @ 7,12 to 14,70
    @ 8,15 say "Auswahl:"
    @ 10,15 Prompt "1. Lokal                                  "
    @ 11,15 Prompt "2. Server: Material Bedarf      (x Wochen)"
    @ 12,15 Prompt "3. Server: Akt. Material Bedarf (0 Wochen)"
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw

    if ABBRUCH
      close data
      RETURN
    endif
    @ 7,12 clear
  else
    ausw = 1 // default nur lokal endif
  endif

  // hole Server Daten if applicable
  if ausw == 1
    Titel("Material-Datei bearbeiten - Lokal")
  elseif ausw == 2
    Titel("Material-Datei bearbeiten - Server (x Wochen)")
    kopiereServer(.f., .f.)
  elseif ausw == 3
    Titel("Material-Datei bearbeiten - Server (0 Wochen)")
    kopiereServer(.f., .f., MATERIAL_SERVER_AKT_BESTAND)
  endif
  select Manuell
  go top

  if ausw == 3 .or. anzahlWochenEingabe( (MANUELL->(reccount()) > 0) , aKopf)

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=5 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
    aKopf[EDIT_GESPERRT]:="Z"
    aKopf[EDIT_EXTRA_FKT]:={}
    if ausw <> 3 // Nicht bei 0 Wochen
      aadd(aKopf[EDIT_EXTRA_FKT],{ "W"," @W@ocheneingabe", { || anzahlWochenEingabe(.f., aKopf) };
        } )
      aKopf[EDIT_NEW_FKT]:={ || _FIELD->MANUELL->Wochen:=M->anzWochen }
    endif

    // Artikel-Nr
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_TITEL]:="Artikel-Nr."
    aSpalte[EDIT_MASKE]:="@K!"
    aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. matArtNrEingabe(oGet)} // kein leeres Feld erlaubt
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Text
    aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
    aSpalte[EDIT_TITEL]:="Text"
    aSpalte[EDIT_EDIT ]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Bedarf
    aSpalte[EDIT_NAME]:="ARTIKEL->Disponiert"
    aSpalte[EDIT_TITEL]:="Auf.Best."
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    if ausw <> 3 // Nicht bei 0 Wochen
      // Anfrage
      aSpalte[EDIT_NAME]:="Menge"
      aSpalte[EDIT_TITEL]:="Anfrage"
      aSpalte[EDIT_MASKE]:="999999.99"
      aSpalte[EDIT_POS_X]:=3 // um 3 nach rechts verschoben
      aSpalte[EDIT_MESSAGE]:="Anfrage-Menge eingeben."

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif

    // Bestellt-Menge anzeigen
    aSpalte[EDIT_NAME]:="if(getArtikelArt()$'FM',ARTIKEL->BestInt,ARTIKEL->BestExt)"
    aSpalte[EDIT_TITEL]:="Bestellt"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren


    /**** ENDE Feld-Definitionen ***/

    /*** Eingabe / Drucke ****/
    Edit(aFelder,aKopf)

  endif

  // schreibe Server Daten if applicable
  if valtype(aKopf[EDIT_CHANGED])=="L" .and. aKopf[EDIT_CHANGED]
    if ausw == 2
      kopiereServer(.t., .f.)
    elseif ausw == 3
      kopiereServer(.t., .f., MATERIAL_SERVER_AKT_BESTAND)
    endif
  endif

  close data
RETURN
/* EOP Mat_erfassen */

static FUNCTION anzahlWochenEingabe(nurAusgabe, aKopf)
LOCAL GetList:={}, merkeWochen

  default nurAusgabe:=.f.

  select Manuell
  go top
  // ist bei allen Posten identisch, wenn kein Posten vorhanden 0
  M->anzWochen:=MANUELL->Wochen
  merkeWochen:=M->anzWochen

  Message("Anzahl Wochen eingeben.     @ESC@=Abbruch")
  @ 1,0 say "Anzahl Wochen:" get M->anzWochen valid {|oget| nachAnzahlWochen(oGet)}
  if ! nurAusgabe
    read
    if ! ABBRUCH .and. M->anzWochen <> merkeWochen
      aKopf[EDIT_CHANGED]:=.t.
    endif
  endif

return .not. ABBRUCH
  /** eop */

  /** Kopiere die Materialbedearfsliste auf den Server und zur�ck */
FUNCTION kopiereServer(hin, Abfrage, source)
LOCAL anz, result:=.f., bLastHandler, objErr

  default hin:=.t.
  default Abfrage:=.t.
  default source:=MATERIAL_SERVER

  Umgebung(WRITE_ALL)
  select Manuell

  if hin
    COUNT for .not. empty(MANUELL->ArtNr) to anz
    if anz == 0
      Error("Bitte zuerst Datens�tze erfassen.")
      Umgebung(LOAD)
      return .f.
    endif

    if .not. Abfrage .or.;
      Message("Aktuelle Material-Bedarfs-Anfrage @auf@ Server kopieren? (@J@/@N@)","JN"," ")=="J"
      copy to (source)
      go top
      // neu 20191211: make additional backup
      if ! file(DAT_BACKUP)
        dirMake(DAT_BACKUP)
      endif
      copy to (DAT_BACKUP+"\Manuell01-" + hb_TtoS(hb_DateTime()) +".dbf")
      go top
      result:=.t.

      if Abfrage
        Message("Daten wurden @auf@ den Server kopiert.    @Taste@","@")
      endif
    endif
  else
    if .not. Abfrage .or.;
      Message("Aktuelle Material-Bedarfs-Anfrage @vom@ Server holen? (@J@/@N@)","JN"," ")=="J"
      BEGIN SEQUENCE // krit. Bereich
        bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
        zap
        append from (source)
        go top
        if Abfrage
          Message("Daten wurden @vom@ Server kopiert.    @Taste@","@")
        endif
      RECOVER USING objErr
        // nop, 1st time copy from other list
        if source <> MATERIAL_SERVER
          TroubleEmail("Aktueller Materialbedarf -> kopiere Wochenliste")
          append from (MATERIAL_SERVER)
          repla all MANUELL->Wochen with 0
          repla all MANUELL->Menge with 0
          go top
        endif
      END SEQUENCE
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      result:=.t.
    endif
  endif
  Umgebung(LOAD)
  anzahlWochenEingabe(.t.)

  HB_KeyPut(EDIT_BS_REFRESH)
return result
  /** eop */

static function nachAnzahlWochen(oGet)
LOCAL aktRec:=MANUELL->(recno())
  if val(oGet:Buffer) < 0
    Error(ACHTUNG+"Mindest Anzahl Wochen ist 0.")
    return .f.
  endif

  select Manuell
  go top
  do while ! MANUELL->(eof())
    replace MANUELL->Wochen WITH M->anzWochen
    if ARTIKEL->MinPuffer <> 0
      replace MANUELL->Menge WITH roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer) * MANUELL->Wochen
    endif
    skip
  enddo

  MANUELL->(dbgoto(aktRec))
  HB_KeyPut(EDIT_BS_REFRESH)
return .t.

static function matArtNrEingabe(oget)
  if oget:changed
    if MANUELL->Wochen == 0 .and. M->anzWochen > 0
      replace MANUELL->Wochen with M->anzWochen
    endif
    if ARTIKEL->MinBestS > 0
      replace MANUELL->Menge WITH roundUp(ARTIKEL->MinBestS / ARTIKEL->MinPuffer) * MANUELL->Wochen
    else
      replace MANUELL->Menge WITH 0
    endif
  endif
return .t.



/* PROCEDURE MatAuftrag
*
* bestimmt in elchen Auftrag eingegebenes MAterial vorkommt
*
*/
PROCEDURE MatAuftrag()
LOCAL MArtNr,Stop:=.f.
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()
LOCAL Zeile:=0, GetList:={},Summe:=0,rest,details:="N"

  cls
  titel("Material in welchem Auftrag")

  if ! open("Aufpost","AufAus","Artikel","AvPost","Einheit")
    cls
    close data
    RETURN
  endif
  Message("Dateien werden vorbereitet.   Bitte warten...")
  select Artikel
  copy fields ArtNr,LageBest,Temp_pr to (temp_datei)
  select 0
  use (temp_datei) exclusive alias ART_BESTAND
  index on ART_BESTAND->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE

  select AufPost
  AUFPOST->(OrdSetFocus(3)) // AufNr+ArtNr
  set rela to AUFPOST->AufNr into AufAus
  set filter to AUFAUS->AufArt $ "KRVD" .and. len(alltrim(AUFPOST->ArtNr))> FRACHT_LAENGE ;
    .and. AUFAUS->erledigt<>"J"
  MArtNr:=space(len(ARTIKEL->ArtNr))

  do while ! ABBRUCH
    Summe:=0
    Message("gew�nschtes Material eingeben.     @F12@=Hilfe")
    @ 10,10 say "Art.Nr.:" get MArtNr PICTURE "@K!" valid { |oGet| check(oGet,"Artikel") };
      when Message("Material-Art.Nr. eingeben.         @F12@=Hilfe")
    @ 12,10 say "Details:" get details PICTURE "!" valid details$"JN";
      when Message("Details zu Unterartikeln anzeigen.")
    read

    if ! ABBRUCH .and. ! empty(MartNr)
      EINHEIT->(dbseek(ARTIKEL->ME))

      Message("Artikel Datei wird initialisiert.   Bitte warten....")
      select ART_BESTAND
      go top
      do while ! ART_BESTAND->(eof())
        replace ART_BESTAND->temp_pr with ART_BESTAND->LageBest
        skip
      enddo

      Drucker("BS")
      ? "Material in welchem Auftrag: "+MArtNr
      ?;
        "Auf.Nr. Artikel  Bezeichnung                             Auftr.Menge      Bedarf: "+;
        EINHEIT->Text
      ? "====================================================================================="

      Message("Bitte warten...")
      select aufpost
      go top
      do while ! AUFPOST->(eof()) .and. ! stop
        rest:=AUFPOST->Menge-AUFPOST->GeliefGes
        if rest > 0
          ARTIKEL->(dbseek(AUFPOST->ArtNr))
          if AUFPOST->ArtNr<>MArtNr
            rest:=rekMat(AUFPOST->ArtNr,MArtNr,rest,1,details=="J")
          endif
          if rest <> 0
            ? AUFPOST->AufNr,AUFPOST->ArtNr,AUFPOST->komm1,AUFPOST->Menge,space(10)
            if rest>0
              ?? str(rest,9,2)
              summe+=rest
            endif
            if details=="J"
              ?
            endif
          endif
          Message("Bitte warten...     Auftrag:"+AUFPOST->AufNr)
        endif
        select aufpost
        skip
        Stop:=stop_key()
      enddo
      ? "===================================================================================="
      ? space(74),str(summe,9,2)

      Drucker("OFF")
      // if Message("Liste ausdrucken ?  ( @J@ / @N@ )","JN")=="J"
      // Drucke_Zeige()
      // endif
    endif
  enddo
  cls
  close data
  ferase( (Temp_Datei) )
RETURN
/* EOF */



/* FUNCTION rekMat
*
* PARAMTER: gew�nschter Oberartikel, Material
*
* checkt ob Material in gew�nschtem Oberartikel vorkommt
*/
static FUNCTION rekMat(Artikel,Material,Menge,tiefe,details)
LOCAL erg:=0,zeile:=0
LOCAL aktSatz,Rest_Bedarf,tempResult,merkLageBest

  // nicht bei EK Artikeln
  ARTIKEL->(dbseek(Artikel))
  if ! getArtikelArt() $ STKLIST_ARTIKEL
    return 0
  endif
  ART_BESTAND->(dbseek(Artikel))

  Rest_Bedarf:=Max(Menge - Max(ART_BESTAND->temp_pr,0),0)
  merkLageBest:=Max(ART_BESTAND->temp_pr,0)
  replace ART_BESTAND->temp_pr with max(ART_BESTAND->Temp_pr-Menge,0)
  dbunlock()
  dbcommit()
  select AvPost

  if Rest_Bedarf > 0
    AVPOST->(dbseek(Artikel+"M"))
    do while ! eof() .and. AVPOST->AvNr==Artikel .and. AVPOST->Art=="M"
      if AVPOST->ArtNr==Material
        tempResult:=Rest_Bedarf*AVPOST->Menge
        if details .and. tempResult <> 0
          ?;
            space(tiefe*2)+" "+AVPOST->AvNr+" "+str(AVPOST->Menge,9,3)+"x "+AVPOST->ArtNr+" "+;
            "Bedarf:"+str(Rest_Bedarf*AVPOST->Menge,9,2)+" "+"Bestand:"+str(merkLageBest,9,2)+" "+;
            "Result:"+str(tempResult,9,2)
          // stackDetails(STACK_PUSH, // space(tiefe*2)+" "+AVPOST->AvNr+" "+str(AVPOST->Menge,9,3)+"x "+AVPOST->ArtNr+" "+"Bedarf:"+str(Rest_Bedarf*AVPOST->Menge,9,2)+" "+"Bestand:"+str(merkLageBest,9,2)+" "+"Result:"+str(tempResult,9,2))
          // merkDetails:=stackDetails(STACK_POP_ALL)
          // for i:=1 to len(merkDetails)
          // ? merkDetails[i]
          // next
        endif
        RETURN tempResult
      else
        aktSatz:=recno()
        tempResult:=rekMat(AVPOST->ArtNr,Material,Rest_Bedarf*AVPOST->Menge,tiefe+1,details)
        if tempResult > 0
          erg+=tempResult
        endif
        go (aktSatz)
        if details .and. tempResult <> 0
          // stackDetails(STACK_PUSH, // space(tiefe*2)+" "+AVPOST->AvNr+" "+str(AVPOST->Menge,9,3)+"x "+AVPOST->ArtNr+" "+"Bedarf:"+str(Rest_Bedarf*AVPOST->Menge,9,2)+" "+"Bestand:"+str(merkLageBest,9,2))
          ?;
            space(tiefe*2)+" "+AVPOST->AvNr+" "+str(AVPOST->Menge,9,3)+"x "+AVPOST->ArtNr+" "+;
            "Bedarf:"+str(Rest_Bedarf*AVPOST->Menge,9,2)+" "+"Bestand:"+str(merkLageBest,9,2)
        endif
        skip
      endif
    enddo
  endif

RETURN( erg )
/* EOF */


/* 
*  druckt zu akt. Artikel-Satz die vorhanden Bestellnr. (inner&ausser) aus
*
* leftMarg ist der Einschub (anzahl der Spaces), falls ein Umbruch gebraucht wird
* rightMarg ist die Breite der zu bedruckenden Spalte, z.B. 15 f�r 3xBestNr a 5 Zeichen
*
* ACHTUNG: IndexOrder==2 wird bei Inner & besPost vorrausgesetzt !  -> 15.12.14 raus, ging als schief
*/

PROCEDURE drucke_best(M_ArtNr,leftMarg,rightMarg)
LOCAL sel:=alias()
LOCAL aktOrdBest:=BESPOST->(indexOrd())
LOCAL aktOrdInner:=INNER->(indexOrd())
LOCAL zeile:=0
LOCAL aPrinted:={},lenPrinted:=0
  default leftMarg:=0
  default rightMarg:=0

  default M_ArtNr:=ARTIKEL->ArtNr

  if select("BesAus")==0
    if ! open("BesAus")
      trouble("drucke_best")
      return
    endif
  endif

  SELECT BesPost

  // debugging "workarea not index" error -> FIXME: should be obsolete
  if BESPOST->(indexord()) == 0
    close BesPost
    if AT_HOME
      TroubleEmail( "Bespost no index" , "Bespost no index" )
      qout("Bingo")
    endif
    if ! open("BesPost")
      trouble("bespost","no index -> could not fix it")
      return
    endif
    trouble("bespost","no index -> fixed")
  endif

  BESPOST->(OrdSetFocus(2))
  SEEK M_ArtNr
  do while .not. eof() .and. BESPOST->ArtNr=M_ArtNr
    BESAUS->(dbseek(BESPOST->BestNr))
    if BESAUS->erledigt<>"J" .and. BESPOST->Menge > BESPOST->GeliefGes // Nur offene Bestellungen anzeigen
      if aScan(aPrinted,BESPOST->BestNr)==0
        // checke Umbruch
        if leftMarg>0 .and. lenPrinted + len(BESPOST->BestNr) > rightMarg
          ? space(leftMarg)
          lenPrinted:=0
        endif

        ?? ZEIGE_BESTNR+BESPOST->BestNr
        aAdd(aPrinted,BESPOST->BestNr)
        lenPrinted+=len(BESPOST->BestNr)+1

        if ! kwEmpty( BESPOST->KW )
          if "*" $ BESPOST->KW
            ?? "("+alltrim(BESPOST->KW_Text)+")"
          else
            ?? "("+BESPOST->KW+")"
          endif
          lenPrinted+=len(BESPOST->KW)+3
        endif

      endif
      skip
    else
      skip
    endif
  enddo

  aPrinted:={}
  lenPrinted:=0

  /* innerbetr. Auftr�ge */
  SELECT Inner
  INNER->(OrdSetFocus(2))
  SEEK M_ArtNr
  do while .not. eof() .and. INNER->ArtNr=M_ArtNr
    if aScan(aPrinted,INNER->InnerNr)==0
      // checke Umbruch
      if leftMarg>0 .and. lenPrinted >= rightMarg-2
        ? space(leftMarg)
        lenPrinted:=0
      endif

      ?? ZEIGE_INNERNR+INNER->InnerNr
      aAdd(aPrinted,INNER->InnerNr)
      lenPrinted+=len(INNER->InnerNr)+1

      if ! kwEmpty( INNER->Lief_KW )
        ?? "("+INNER->Lief_KW+")"
        lenPrinted+=len(INNER->Lief_KW)+3
      endif

    endif
    skip
  enddo

  SELECT (sel)
  BESPOST->(OrdSetFocus(aktOrdBest))
  INNER->(OrdSetFocus(aktOrdInner))
RETURN
/* EOP drucke_best */


/* 
*  gibt String zu akt. Artikel-Satz mit vorhanden Bestellnr. (inner&ausser) zurueck
*
* ACHTUNG: IndexOrder==2 wird bei Inner & besPost vorrausgesetzt !
*/
FUNCTION get_best()
LOCAL sel:=ALIAS()
LOCAL result:=""

  if ! open("Besaus")
    return result
  endif

  SELECT BesPost
  SEEK ARTIKEL->ArtNr
  do while .not. eof() .and. BESPOST->ArtNr=ARTIKEL->ArtNr
    BESAUS->(dbseek( BESPOST->BestNr ))
    if BESAUS->erledigt<>"J" .and. BESPOST->Menge > BESPOST->GeliefGes
      result+=BESPOST->BestNr+space(1)
      if ! KWempty(BESPOST->KW)
        result+="("+BESPOST->KW+") "
      endif
    endif
    skip
  enddo

  /* innerbetr. Auftr�ge */
  SELECT Inner
  SEEK ARTIKEL->ArtNr
  do while .not. eof() .and. INNER->ArtNr=ARTIKEL->ArtNr
    if INNER->Erledigt<>"J" .and. INNER->Menge > INNER->GeliefGes
      result+=INNER->InnerNr+space(1)
      if ! KWempty(INNER->Lief_Kw)
        result+="("+INNER->Lief_Kw+") "
      endif
    endif
    skip
  enddo
  select (sel)

RETURN result
/* EOP */


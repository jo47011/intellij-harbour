/* Modul: NachKalk.prg
*
* enth�lt alles zur "neuen" Nachkalkulation, ab 1.3.2017

Info:

Maschine.dbf      = Maschinen Stammdaten

NKPost.dbf        = Posten der Nachkalk., Zeiten und gebrauchtes Material (Artikel)
NKErf.dbf         = Temp. Datei zu oben

NKArtikel.dbf     = NK Kopf Daten: Artikel (Nutzen etc.)
NkMehrf           = Temp. Datei zu oben

NKZeit.dbf        = Eingabe der Zeiten (von, bis, Menge, Ausschuss)
ZeitErf.dbf       = Temp. Datei zu oben

*/

#include "Miki.ch"
#include "Setcurs.ch"
#include "hbclass.ch"
#include "zeige.ch"
#include "hbgtinfo.ch"

// Toleranzgrenze, bei ueberschreiten wird Email bei Nachkalk. versendet
#define TOLERANZ 0.10 // 10 Prozent
#define MASCH_GROUP_3er "3er"

Procedure nachkalkerf(openNkNr)
LOCAL GetList:={}
LOCAL zeile, mMaschNr, maschinen, mInnerNr, aktrec, mNkNr, mArbgang
LOCAL isMehrfachspritzung
LOCAL gesMatMenge, merkME, tempMehrfach, zeitJ, zeitN, matJ, matN, okay
LOCAL changed, mGelief
LOCAL HauptMaschinen, ruestZeit, merkMatNr, material, printBuffer, s01

MEMVAR merkArtNr, merkGruppe
PRIVATE merkArtNr, merkGruppe

  Umgebung(WRITE_ALL)

  cls
  titel("Nachkalkulation")

  if ! open("Artikel","Personal","Maschine","NKPost","NKErf","NKArtikel","NkMehrf", "Inner","AvPost",;
    "ZeitErf","NKZeit","MaschGr","Einheit","WarAus", "TODO")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif
  INNER->(OrdSetFocus( 6 )) // NkNr
  WARAUS->(OrdSetFocus( 3 )) // inLfdNr + Artnr

  default mInnerNr:=space(len( INNER->InnerNr ) +1 ) // zzg. Arbeitsgang (optional)

  do while .t.
    cls
    titel("Nachkalkulation")

    // gebe Semaphore frei, von vorheriger Eingabe
    dbcommitall()
    dbunlockall()

    if valtype(openNkNr) == "U"
      INNER->(OrdSetFocus( 1 )) // InnerNr nur nicht erledigte, ohne Arbeitsg�nge, also nur 1x je Mappe
      mInnerNr:=space(len( INNER->InnerNr ) +1 ) // zzg. Arbeitsgang (optional)
      @ 2,0 say "Inner.Nr.:" get mInnerNr picture "@K !99!!";
        when Message("Innerbetr. Mappen-Nummer eingeben.    @F12@=Auswahl") ;
        valid { |oGet| nachkalkInnerNach(oGet) }
      read
      INNER->(OrdSetFocus( 6 )) // NkNr
      if ABBRUCH
        exit
      endif
    else
      INNER->(dbseek(openNkNr))
      if INNER->(eof())
        Umgebung(LOAD)
        return
      endif
    endif

    select NkMehrf
    zap
    select NKErf
    zap

    isMehrfachspritzung:=INNER->Nutzen1 > 1 .or. INNER->Nutzen2 > 1
    mNkNr:=INNER->NkNr
    M->merkArtNr:=INNER->ArtNr
    mInnerNr:=INNER->InnerNr
    mArbgang:=INNER->ArbGang

    changed:=.f.

    // neuanlage?
    if empty(INNER->NkNr) // isNeu

      // pr�fe ob Fertigmeldung bereits erfasst.
      if empty(INNER->ArbGang) .or. INNER->ArbGang=="A"
        mGelief:=INNER->GeliefGes
      else
        // nicht Hauptarbeitsg�nge werden auf Hauptarbeitsgang fertig gemeldet
        aktrec:=INNER->(recno())
        INNER->(OrdSetFocus( 1 )) // InnerNr nur nicht erledigte
        INNER->(dbseek(mInnerNr))
        mGelief:=INNER->GeliefGes
        INNER->(OrdSetFocus( 6 )) // NkNr
        INNER->(dbgoto(aktrec))
      endif

      if ! isMehrfachspritzung .and. mGelief <= 0
        Error(ACHTUNG+"Bitte zuerst Fertigmeldung ("+out(INNER->ArtNr,.t.)+") erfassen.")
        loop
      endif

      mNkNr:=hole("NKNr",WRITE,.t.)

      // kopiere alle Hauptmaschinen vom 1. Artikel
      // INFO: brauchen wir noch so, wegen bereits existierenden innerbetr. Auftr�gen
      // kann sp�te evtl. raus
      maschinen:=StueckListe():new( INNER->ArtNr ):getMaschinen( .t. )
      for each mMaschNr in Maschinen
        if empty(INNER->ArbGang) .or. INNER->MaschNr == mMaschNr

          // hole ruestzeit von Hauptmaschine
          HauptMaschinen:=Stueckliste():new(M->merkArtNr):getZeiten(mMaschNr,"H")
          if len(HauptMaschinen) > 0
            ruestZeit:=HauptMaschinen[1]:RuestZeit
          endif

          // f�ge Datensatz hinzu
          select NkErf
          add_rec(0)
          replace NKERF->NkNr with mNKNr
          replace NKERF->Art with "Z"
          replace NKERF->MaschNr with mMaschNr
          replace NKERF->Datum with getUser():date
          replace NKERF->RuestZeitS with Ruestzeit
          replace NKERF->Vorgabe with "J"
        endif
      next

      // kopiere alle Artikel aus Inner.dbf
      select Inner
      aktrec:=INNER->(recno())
      INNER->(OrdSetFocus( 7 )) // InnerNr nur nicht erledigte
      INNER->(dbseek(mInnerNr+mArbgang))
      do while INNER->InnerNr == mInnerNr .and. INNER->ArbGang == mArbGang .and. ! INNER->(eof())
        if ! rec_lock(5 , .t.) // keep locked as semaphore
          dbunlockall()
          Umgebung(LOAD)
          return
        endif

        tempMehrfach:=Mehrfach():new(INNER->Artnr)

        select Nkmehrf
        add_rec(0)
        replace NKMEHRF->NkNr with mNkNr
        replace NKMEHRF->ArtNr with INNER->ArtNr
        replace NKMEHRF->InLfdNr with INNER->InLfdNr
        replace NKMEHRF->MengeZug with max(tempMehrfach:Menge,1)
        replace NKMEHRF->Nutzen1 with INNER->Nutzen1
        replace NKMEHRF->Nutzen2 with INNER->Nutzen2
        replace NKMEHRF->Gruppe with INNER->Gruppe
        replace NKMEHRF->Datum with getUser():date

        dbcommit()
        dbunlock()

        select Inner
        skip
      enddo
      INNER->(OrdSetFocus( 6 )) // NkNr
      INNER->(dbgoto(aktrec))

    else
      // FIXME: pr�fe ober innerbetr. Auftrag sich ge�ndert hat!

      // kopiere Artikel evtl. Mehrfach
      NKARTIKEL->(dbseek(INNER->NKNr))
      do while NKARTIKEL->NkNr == INNER->NKNr .and. ! NKARTIKEL->(eof())
        select Nkmehrf
        add_rec(0)
        overwrite("NKARTIKEL")
        tempMehrfach:=Mehrfach():new(NKARTIKEL->Artnr)
        if NKMEHRF->MengeZug <> max(tempMehrfach:Menge,1)
          s01:=savescreen()
          Error("ACHTUNG: Artikel-Nutzen hat sich ge�ndert||" +;
            "         Artikel   : " + out(NKARTIKEL->Artnr) +"||"+;
            "         Nutzen alt: " + str(NKMEHRF->MengeZug,3) +"|"+;
            "         Nutzen neu: " + str(max(tempMehrfach:Menge,1),3), .f.)
          if message("Neuen Nutzen �bernehmen?  (@J@/@N@)","JN")=="J"
            replace NKMEHRF->MengeZug with max(tempMehrfach:Menge,1)
            changed:=.t.
          endif
          restscreen(,,,,s01)
        endif

        NKARTIKEL->(dbskip())
      enddo

      select Inner
      aktrec:=INNER->(recno())
      do while INNER->NKNr == mNknr .and. ! INNER->(eof())
        if ! rec_lock(5 , .t.) // keep locked as semaphore
          dbunlockall()
          Umgebung(LOAD)
          return
        endif
        skip
      enddo
      INNER->(dbgoto(aktrec))

      // NachKalkulation kopieren & bearbeiten
      NKPOST->(dbseek(mNkNr))
      select NkErf
      append("NKPost",{ || NKPOST->NkNr == mNKNr})

    endif

    //***** Nutzen bearbeiten, nur bei Mehrfachspritzung ******
    if isMehrfachspritzung
      titel("Nachkalkulation / Nutzen")
      changed:=NKNutzenEdit()

      // Artikel oben anzeigen
      @ 1,0 clear
      @ 1,0 say "Inner   Artikel                                       Soll-Menge  Rest Menge/Zug"
      @ 2,0 say dispInnerNr(mInnerNr,mArbGang)
      
      Zeile:=2
      select Nkmehrf
      INNER->(OrdSetFocus( 3 ))   // inLfdNr
      go top
      do while ! NKMEHRF->(eof())
        INNER->(dbseek(NKMEHRF->InLfdNr))
        if INNER->GeliefGes == 0 .or. empty(INNER->Gruppe)
          setcolor("R/"+getBackColor())
        endif
        @ zeile, 6 say out(INNER->ArtNr)
        qqout( space(0),INNER->Bez1,INNER->AufNr,str(INNER->Menge,8,0), str(INNER->Menge - INNER->GeliefGes,8,0) )
        qqout( space(1),str(NKMEHRF->MengeZug,2))
        setcolor(COLNOR)
        zeile++
        NKMEHRF->(dbskip())
      enddo
      zeile++
      INNER->(OrdSetFocus( 1 ))   // innernr

    else   // keine Mehrfachspritzung
      
      select Inner
      
      // Artikel oben anzeigen
      @ 1,0 clear
      @ 1,0 say "Inner.Nr. Artikel                                                Menge     Rest"
      @ 2,0 say dispInnerNr(mInnerNr,mArbGang)
      @ 2,10 say out(INNER->ArtNr)
      qqout( space(0),INNER->Bez1,INNER->AufNr,space(4),str(INNER->Menge,8,0), str(INNER->Menge - INNER->GeliefGes,8,0) )
      zeile:=3

    endif

    //********* Zeiten & Menge bearbeiten *****************************************    
    titel("Nachkalkulation / Zeiten & Menge")
    okay:=.f.
    do while ! okay
      changed:=NachKalkEdit(zeile, mNkNr, isMehrfachspritzung) .or. changed

      if ! changed
        exit
      endif
      
      // pr�fe ob bei allen Datens�tze Menge eingegeben
      select NKErf
      go top

      zeitJ:=zeitN:=0
      matJ:=matN:=0
      do while ! NKERF->(eof())
        if NKERF->Art=="Z"
          if NKERF->GutMenge > 0 .or. NKERF->Ausschuss > 0
            zeitJ++
          else
            zeitN++
          endif
        elseif NKERF->Art=="M"
          if isMaterial(NIL, INNER->ArtNr, NKERF->ArtNr)
            if NKERF->MatMenge > 0
              matJ++
            else
              matN++
            endif
          endif
        endif
        skip
      enddo
      go top

      // pr�fe alle Zeiteingaben
      if zeitJ == 0
        if Message("Nachkalkulation verwerfen?  (@J@/@N@)","JN"," ")=="J"
          INNER->(OrdSetFocus( 6 )) // NkNr
          INNER->(dbseek(mNkNr))
          do while INNER->NkNr == mNKNr .and. ! INNER->(eof())
            rec_lock(0)  //  should still be locked, enabled 20220917
            replace INNER->NkNr with ""
            skip
          enddo
          loescheNachkalkEintraege(mNKNr)
          exit
        endif
      elseif ZeitN == 0
        okay:=.t.
      else
        Error(ACHTUNG+"alle Datens�tze m�ssen erfasst werden.")
      endif

      // pr�fe Material Eingabe
      if isMatPflicht() .and. matJ == 0 .and. okay
        Error(ACHTUNG+"Material-Verbrauch muss eingegeben werden.")
        if matN == 0
          keyboard "NM"+chr(K_RETURN) // schlage neuen Material Eintrag vor
        endif
        okay:=.f.
      endif
    enddo

    if ! okay
      if valtype(openNKNr) == "U"
        loop
      else
        exit
      endif
    endif

    // r�ckschreiben NKNr
    if empty( INNER->NkNr )
      // Inner should be still locked
      aktRec:=INNER->(recno())
      select Inner
      INNER->(OrdSetFocus( 7 ))   // nur nicht erledigte, inkl. aller Arbeitsg�nge
      INNER->(dbseek( mInnerNr + mArbgang ))
      do while INNER->InnerNr == mInnerNr .and. INNER->ArbGang == mArbGang .and. ! INNER->(eof())
        rec_lock(0)   // should still be locked
        replace INNER->NkNr with mNkNr
        skip
      enddo
      INNER->(OrdSetFocus( 6 ))  // NK
      INNER->(dbgoto(aktrec))
    endif

    // r�ckschreiben Kopf: Nutzen & Maschinen & Artikel
    loescheNachkalkEintraege(mNKNr)

    // berechne (zus�tzliche) Material
    // Laut MW am 27.8.2020 immer nur ein Material pro Gruppe, also keine �pfel & Birnen
    select NKErf
    go top
    gesMatMenge:=0
    merkME:=NIL
    merkMatNr:=""
    do while ! NKERF->(eof())
      if NKERF->Art=="M"
        gesMatMenge += NKERF->MatMenge
        merkME:=NKERF->ME
        merkMatNr:=NKERF->ArtNr
      endif
      skip
    enddo
    
    go top
    if merkME <> NIL
      do while ! NKERF->(eof())
        if NKERF->Art=="Z"
          replace NKERF->MatMenge with gesMatMenge 
          replace NKERF->MatZug with gesMatMenge / (NKERF->GutMenge + NKERF->Ausschuss)
          replace NKERF->ME with merkME
        endif
        skip
      enddo
    endif

    // kopiere Material-Faktor bei Mehrfachspritzungen
    // hole aus jeder Artikel St�ckliste die Menge des Materials
    // und setze diese in Relation zur Gesamtmenge
    if NKMEHRF->(reccount()) > 1 .and. merkMatNr <> NIL .and. ! empty(merkMatNr) // isMehrfachspritzung
      select Nkmehrf
      NKMEHRF->(dbgotop())
      gesMatMenge:=0
      do while ! NKMEHRF->(eof())
        // hole AvMenge f�r Material
        material:=Stueckliste():new(NKMEHRF->ArtNr):getMaterial(.t.,merkMatNr)
        if len(Material) == 0
          Error(ACHTUNG+"Material: " + merkMatNr + " nicht in St�ckliste: " + NKMEHRF->ArtNr+"||"+;
          "         Aufteilung Materialbedarf auf einzelne Artikel ist evtl. falsch.")
        else
          replace NKMEHRF->MatMenge with (material[1]:menge * NKMEHRF->MengeZug)
          gesMatMenge += NKMEHRF->MatMenge
        endif
        skip
      enddo

      // 2. Runde Faktor r�ckschreiben
      NKMEHRF->(dbgotop())
      do while ! NKMEHRF->(eof())
        if NKMEHRF->MatMenge == 0
          replace NKMEHRF->MatFaktor with 0
        else
          replace NKMEHRF->MatFaktor with NKMEHRF->MatMenge / gesMatMenge
        endif
        skip
      enddo
    endif

    NKMEHRF->(dbgotop())
    select NKArtikel
    append("NkMehrf",{ || .t. })
    
    printBuffer:=NKBucheMaterial(mInnerNr)

    NKERF->(dbgotop())
    select NKPost
    append("NKErf",{ || .t. })

    // NachKalkulation abgeschlossen
    if okay

      if INNER->Erledigt<>"J" .and. ;
      (empty(mArbGang) .or. len(getFehlendeNachkalkNummern(mInnerNr, mArbGang))==0)
        if Message("Nachkalkulation abgeschlossen?  Mappe freigeben? (@J@/@N@)","JN","N")=="J"
          // Bestellung als erledigt markieren
          SELECT Inner
          aktRec:=INNER->(recno())
          INNER->(OrdSetFocus( 7 )) // InnerNr nur nicht erledigte, inkl. Arbeitsg�nge
          INNER->(dbseek(mInnerNr))
          do while .not. INNER->(eof()) .and. INNER->InnerNr==mInnerNr 
            REC_LOCK(0)
            replace INNER->erledigt with "J"
            dbcommit()
            UNLOCK
            skip
          enddo
          INNER->(OrdSetFocus( 6 )) // NkNr
          INNER->(dbgoto(aktrec))
          BestBestand( BEST_INT , m->merkArtNr )
          AufBestand()
          select Artikel
          Message("Mappe: @"+mInnerNr+"@ wieder frei gegeben.    Bitte @Taste@ dr�cken","@")
        endif
      else
        if valtype(openNkNr) == "U"
          Message("Mappe: @"+mInnerNr+mArbgang+"@ wurde verbucht.    Bitte @Taste@ dr�cken","@")
        endif
      endif

      // sende Email?
      NKpruefeAbweichung(printBuffer)      
        
    endif
    
    dbcommitall()
    dbunlockall()

    if valtype(openNkNr) <> "U"
      exit
    endif
    
  enddo

  Umgebung(LOAD)
return
  /* eop */

  /** wird nach der Eingabe der innerNr ausgef�hrt.
  Pr�ft auch auf korrekten Arbeitsgang
  */
static function nachkalkInnerNach(oGet)
LOCAL aktRec:=INNER->(recno()), tempNr
LOCAL aktOrd:=INNER->(OrdSetFocus( 7 )) // InnerNr nur nicht erledigte, inkl. Arbeitsg�nge
LOCAL mInnerNr:=getInnerShifted(oGet:buffer)

  if empty(oGet:buffer)
    Keyboard chr(HILFE_TASTE1)
    INNER->(OrdSetFocus( aktOrd ))
    return .f.
  endif

  INNER->(dbseek(mInnerNr))
  if INNER->(eof()) .or. (isAllDigit(alltrim(oget:buffer)) .and. .not. empty(INNER->ArbGang))
    // suche ohne optionales A (Standard auf Etikett bei Auftr�gen mit nur 1 Arbeitsgang)
    if right(trim(mInnerNr),1)=="A"
      tempNr:=strtran(mInnerNr,"A"," ")
      INNER->(dbseek(tempNr))
      if ! INNER->(eof())
        INNER->(OrdSetFocus( aktOrd ))
        return .t.
      endif
      Error(oget:Buffer+" nicht gefunden.")
      INNER->(OrdSetFocus( aktOrd ))
      return .f.
    else
      Error(oget:Buffer+" nicht gefunden.||Evtl. bitte Arbeitsgang (A,B,C,...) mit eingeben.")
      Keyboard chr(K_END)
      return .f.
    endif
  endif

  INNER->(OrdSetFocus( aktOrd ))
return .t.
/** eof */

  /** Nur bei folgenden F-Artikeln ist der Eintrag als Material zu behandeln
  und wird entsprechend zu/abgebucht:

  3er Artikel -> 7er Material
  4er Artikel -> 9er Material
  */  
static function isMaterial(art,avnr,artnr)
return (art==NIL .or. art == "F") .and. 
  ((left(AvNr,1) $ "3" .and. left(ArtNr,1) $ "7") .or.;
  (left(AvNr,1) $ "4" .and. left(ArtNr,1) $ "9"))
/** eof */

static function isMatPflicht()
LOCAL material, temp, matStart
LOCAL result:=.f.

  if INNER->Art == "F" // Pflicht nur bei Fertigungsartikeln

    if left(INNER->ArtNr,1) $ "3"
      matStart:="7"
    elseif left(INNER->ArtNr,1) $ "4"
      matStart:="9"
    endif

    material:=StueckListe():new(INNER->ArtNr):getMaterial(.t.)
    temp:=aScan(material, {|x| left(x:artnr,1)==matStart})
    if temp > 0
      Umgebung(WRITE_ALL)
      select NKErf
      go top
      do while ! NKERF->(eof()) .and. ! result
        if ! empty(NKERF->MaschNr)
          MASCHINE->(dbseek(NKERF->MaschNr))
          if MASCHINE->(eof())
            trouble("Maschine: " + NKERF->MaschNr + " nicht gefunden.")
          endif
          result:=MASCHINE->MatBedarf == "J"
        endif
        skip
      enddo
      Umgebung(LOAD)
    endif
  endif
return result
/** eof */    

/** Buche Material Differenz zur Fertigmeldung
  und zwar nur bei
   - 3er Artikel und in St�ckliste Material mit 7...
   - 4er Artikel                            mit 9...

*/
static function NKBucheMaterial(mInnerNr)
LOCAL diff, count:=0, warausMenge1, warausMenge2
LOCAL printBuffer:=printBuffer():new()
LOCAL allMatArtNrs:={}, myMe, erst

  ARTIKEL->(dbseek(INNER->ArtNr))
  EINHEIT->(dbseek(ARTIKEL->ME))
  myMe:=EINHEIT->Text
  ->? "Nachkalkulation: " + mInnerNr + "   vom",getUser():Date
  ->?
  ->? ZEIGE_ARTNR+out(INNER->ArtNr),ARTIKEL->Bez1
  if ! empty(ARTIKEL->Bez1)
    ->? space(len(out(INNER->ArtNr))),ARTIKEL->Bez2
  endif
  ->?
  ->? "Pers.Nr. Masch. R�stzeit   Zeit Gut-Menge Ausschu�"

  ->? "--------------------------------------------------"

  // Ausdruck der Zeit-Eingabe
  select NKErf
  NKERF->(dbgotop())
  do while ! NKERF->(eof())
    if NKERF->Art=="Z"
      ->? left(NKERF->PersNr,3),space(6),NKERF->MaschNr,space(3),NKERF->RuestZeit,NKERF->Zeit,space(1),;
        NKERF->GutMenge,space(0),NKERF->Ausschuss,myMe
    endif
    NKERF->(dbskip())
  enddo

  set filter to // auch geloeschte
  NKERF->(dbgotop())
  erst:=.t.
  do while ! NKERF->(eof())
    if NKERF->Art=="M" .and. ! empty(NKERF->ArtNr)

      if erst
        erst:=.f.
        ->?
        ->? "Art.Nr.  Bezeichnung                             Menge"
        ->? "------------------------------------------------------"
      endif


      ARTIKEL->(dbseek(NKERF->ArtNr))
      ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,space(4),NKERF->MatMenge
      if NKERF->geloescht$"J"
        ->?? "(gel�scht)"
      else
        ->?? "(erfasst)"
      endif
    endif

    if (NKERF->Art=="M" .and.;
      isMaterial(INNER->Art, INNER->ArtNr, NKERF->ArtNr)) .or. (NKERF->Art=="A")

      if NKERF->Art=="M"
        aadd(allMatArtNrs, NKERF->ArtNr)
      endif

      diff:=0
      warausMenge1:=warausMenge2:=0

      if NKERF->geloescht$"J"
        diff:=NKERF->MatBuch
      else
        if NKERF->MatBuch <> NKERF->MatMenge .and. ! empty(INNER->InLfdNr)

          // Fertigmeldung pr�fen -> nur Differenz buchen
          // bei isMehrfachspritzung nach allen inLfdNr suchen

          select Nkmehrf
          go top
          do while ! NKMEHRF->(eof())
            WARAUS->(dbseek(NKMEHRF->InLfdNr+NKERF->Artnr))
            // buche eingegebenes Material zur�ck
            do while ! WARAUS->(eof()) .and. WARAUS->InlfdNr==NKMEHRF->InLfdNr .and.;
              WARAUS->ArtNr==NKERF->Artnr
              if alltrim(WARAUS_INNERNR) $ WARAUS->Programm // FertigMeldung
                warausMenge1 += WARAUS->Menge
              elseif WARAUS_NACHKALK $ WARAUS->Programm // Nachkalk
                warausMenge2 += WARAUS->Menge
              endif
              WARAUS->(dbskip())
            enddo
            NKMEHRF->(dbskip())
          enddo

          diff:=-warausMenge1 -warausMenge2 - NKERF->MatMenge
        endif

        if Diff <> 0
          // replace NKERF->WarAusBuch with warausDiff
          if warausMenge1 <> 0
            ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,warausMenge1," (Fertig-Meldung)"
          endif
          if warausMenge2 <> 0
            ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,warausMenge2," (Nachkalk vorher)"
          endif

          /* Artikel verbuchen */
          select Artikel
          if ! ARTIKEL->(eof()) .and. rec_lock(5)
            ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,str(diff,14,3),"(gebucht)"
            aendArtBest(diff,WARAUS_NACHKALK + mInnerNr,,INNER->InLfdNr)
            dbcommit()
            dbunlock()
          else
            Error(ACHTUNG+"Material: "+out(NKERF->ArtNr)+" konnte nicht gebucht werden.||Menge:"+;
              str(diff,10,2),.t.,"root")
          endif
          if NKERF->Art=="M"
            count++
          endif
        endif
        replace NKERF->MatBuch with NKERF->MatMenge
      endif
      select NKErf
    endif
    skip
  enddo

  // filter auf ungel�schte Posten
  select NKErf
  set filter to NKERF->geloescht$"N "
  go top

  // buche alternat. Material zur�ck
  if count > 0
    if NKMEHRF->(reccount()) == 0 // temp. for debug only, added 20201008
      // obsolete NKMEHRF sollte immer 1 Artikel enthalten
      Error(ACHTUNG+"NKBucheMaterial ohne NKMEHRF Eintrag.  InnerNr "+;
        out(INNER->InLfdNr),.t.,"root")
      bucheAlternatMatZurueck(INNER->Art, INNER->ArtNr, NKMEHRF->InLfdNr, allMatArtNrs,;
        printbuffer, mInnerNr)
    else
      select Nkmehrf
      go top
      do while ! NKMEHRF->(eof())
        bucheAlternatMatZurueck(INNER->Art, NKMEHRF->ArtNr, NKMEHRF->InLfdNr, allMatArtNrs,;
          printbuffer, mInnerNr)
        skip
      enddo
    endif
  endif

return printBuffer
  /** eop */

  /** Bucht Material zur�ck was bei der FertigMeldung gebucht wurde, aber bei der Nachkalk. nicht erfasst */
static;
  procedure bucheAlternatMatZurueck(art, mArtNr, mInLfdNr, allMatArtNrs, printbuffer, mInnerNr)
LOCAL aktSel:=alias()
LOCAL summe:=0 , materialNr
LOCAL buchungen:=hb_hash()

  if left(mArtNr,1) $ "3|4"
    WARAUS->(dbseek(mInLfdNr))
    do while ! WARAUS->(eof()) .and. WARAUS->InlfdNr==mInLfdNr
      materialNr:=WARAUS->ArtNr
      do while ! WARAUS->(eof()) .and. WARAUS->InlfdNr==mInLfdNr .and. materialNr == WARAUS->ArtNr
        if isMaterial(Art, mArtNr, WARAUS->ArtNr)
          // Nur FertigMeldung oder Nachkalk
          if (alltrim(WARAUS_INNERNR) $ WARAUS->Programm .or. WARAUS_NACHKALK $ WARAUS->Programm) .and. ;
            .not. aContains(allMatArtNrs, WARAUS->ArtNr)
            summe += WARAUS->Menge
          endif
        endif
        WARAUS->(dbskip())
      enddo
      if summe <> 0
        buchungen[materialNr]:=summe
      endif
    enddo
  endif

  if len(buchungen) > 0
    ->? "R�ckbuchungen Fertigmeldungen:"
    ->? "------------------------------"

    // Jetzt r�ckbuchen, extra hier da ansonsten waraus in der loop ge�ndert wird
    for each materialNr in buchungen:Keys
      summe:=buchungen[materialNr]
      select Artikel
      ARTIKEL->(dbseek(materialNr))
      ->? ARTIKEL->ArtNr,ARTIKEL->Bez1,summe * (-1)
      if ! ARTIKEL->(eof()) .and. rec_lock(5)
        aendArtBest(Summe * (-1),WARAUS_NACHKALK + mInnerNr,,mInLfdNr)
        dbcommit()
        dbunlock()
      endif
    next
  endif

  select (aktSel)
return
/** eop */


static procedure loescheNachkalkEintraege(mNKnr)
LOCAL aktSel:=alias()
LOCAL tempVal
  for each tempval in {"NKARTIKEL", "NKPOST"}
    &(tempval)->(dbseek(mNkNr))
    select (tempval)
    do while &(tempval)->NKNr == mNKNr .and. ! &(tempval)->(eof())
      rec_lock(0)
      dbDelete()
      dbcommit()
      dbunlock()
      dbskip(0) // workaround: ansonsten delete flag geht verloren
      dbskip()
    enddo
  next
  select (aktSel)
return

static function NKNutzenEdit( )
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL aktFocus:=INNER->(OrdSetFocus( 3 )) // inlfdnr
LOCAL Status, line:=0

  select Nkmehrf
  set rela to NKMEHRF->InLfdNr into Inner
  Status:=getMehrfachStatus()
  go top

  @ 1,0 clear
  @ 1,0 say "Inner.Nr. " + left(trim(INNER->InnerNr)+"A",4)
  if len(status) > 0
    @ 2,0 say mycenter(status) color COLERR
    line:=1
  endif

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=5 + line // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="NLZ"
  // aKopf[EDIT_FKT_IMMER]:={ || NKdispNutzen() }

  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ chr(K_RETURN) ," @RETURN@ = weiter", { || HB_KeyPut(EDIT_QUIT) } } )

  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="INNER->ArtNr"
  aSpalte[EDIT_TITEL]:="Nr."
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={;
    || if(INNER->GeliefGes==0 .or. empty(INNER->Gruppe),"R/"+getBackColor(),COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="INNER->Bez1"
  aSpalte[EDIT_TITEL]:="Bezeichnung"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={;
    || if(INNER->GeliefGes==0 .or. empty(INNER->Gruppe),"R/"+getBackColor(),COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="INNER->Gruppe"
  aSpalte[EDIT_TITEL]:="Gruppe"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={;
    || if(INNER->GeliefGes==0 .or. empty(INNER->Gruppe),"R/"+getBackColor(),COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="MengeZug"
  aSpalte[EDIT_TITEL]:="Menge/Zug"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MASKE]:="99"
  aSpalte[EDIT_FARBE]:={;
    || if(INNER->GeliefGes==0 .or. empty(INNER->Gruppe),"R/"+getBackColor(),COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="INNER->Menge"
  aSpalte[EDIT_TITEL]:="Vorgabe"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={ || if(getNKAbweichung(),"W/R",COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="INNER->GeliefGes"
  aSpalte[EDIT_TITEL]:="Fertigmeld."
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_FARBE]:={;
    || if(INNER->GeliefGes==0 .or. empty(INNER->Gruppe),"R/"+getBackColor(),COLNOR) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  /**** ENDE Feld-Definitionen ***/
  Edit(aFelder,aKopf)

  INNER->(OrdSetFocus( aktFocus ))
  select Nkmehrf
  set rela to

  if aKopf[EDIT_CHANGED]
    kalkNutzenVerteilung()
  endif


RETURN( aKopf[EDIT_CHANGED] )
  /** eof */

// berechne Nutzen wenn Menge pro Zug ge�ndert
static function kalkNutzenVerteilung()
LOCAL mehrfSumme, fraction
LOCAL aktSel:=alias()

  select NKMehrf
  go top
  sum NKMEHRF->MengeZug to mehrfSumme

  // Nutzen per Gruppe berechnen
  go top
  do while ! NKMEHRF->(eof())
    fraction:=reduceFraction( NKMEHRF->MengeZug, mehrfSumme)
    replace NKMEHRF->Nutzen1 with fraction[1]
    replace NKMEHRF->Nutzen2 with fraction[2]
    skip
  enddo

  select(aktsel)

return .t.
/** eof */

/*
* zum Erfassen der Arbeitszeit Nachkalkulation
*/
STATIC FUNCTION NachKalkEdit(startZeile , mNkNr, isMehrfachspritzung)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  select NKErf
  set rela to NKERF->MaschNr into Maschine, to NKERF->ArtNr into Artikel
  select Artikel
  set rela to ARTIKEL->ME into Einheit
  select NKErf
  // filter auf ungel�schte Posten
  set filter to NKERF->geloescht$"N "

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=startZeile + 3 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-3 // N: Ende des Eingabe-Berreiches BS abzgl. von MaxRow()
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_INDEX_FELD]:={;
    || (NKERF->Art $ "AM" .and. empty(NKERF->ArtNr) .and. NKERF->Vorgabe<>"J") .or.;
    (NKERF->Art == "Z" .and. NKERF->Zeit == 0 .and. NKERF->GutMenge == 0 .and.;
    NKERF->Vorgabe<>"J") }
  aKopf[EDIT_ERSATZ_ARRAY]:={ || NKZusatzMat()}
  aKopf[EDIT_NEW_FKT]:={;
    || if(empty(NKERF->ArtNr),_FIELD->NKERF->Art:="M",_FIELD->NKERF->Art:="Z"), _FIELD->NKERF->NkNr:=mNkNr, _FIELD->NKERF->Datum:=getUser():date }

  aKopf[EDIT_AFTER_EDIT_FKT]:={ || nkZeitCheck() }
  aKopf[EDIT_DELETE_FKT]:={ || _FIELD->NKERF->Geloescht:="J" }
  if isMehrfachspritzung
    aKopf[EDIT_KOPF_FKT]:={ || NKNutzenEdit() }
  endif

  aKopf[EDIT_EXTRA_FKT]:={}
  aadd(aKopf[EDIT_EXTRA_FKT],{ " L"," @L@�schen ", { || KonsistenzLoesch() } } )
  //Aadd(aKopf[EDIT_EXTRA_FKT], { "D"," @D@rucken", { || Stk_druck()} } )

  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Art"
  aSpalte[EDIT_NAME_GET]:="NKERF->Art"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="!!!"
  aSpalte[EDIT_AFTER]:={ |oGet| NKERF->Art$"AMZ" .and. NKArtNach(oGet)}
  aSpalte[EDIT_MESSAGE]:="Art eingeben.  @Z@eiten/Menge  @M@aterial  @A@rtikel  @F12@=Auswahl   @ESC@ = Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || NKERF->Art $ "AM" }
  aSpalte[EDIT_AUSGABE]:=.t. // n�tig , falls Zuschlag

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Personal-Nr
  aSpalte[EDIT_NAME]:="PersNr"
  aSpalte[EDIT_TITEL]:="Pers.Nr."
  aSpalte[EDIT_MASKE]:="@K 999"
  aSpalte[EDIT_UEBERTRAG]:=.t. // carry on
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Personal",.f.,.f.) .and. changeDate(oget) }
  aSpalte[EDIT_MESSAGE]:="Personal-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="MaschNr"
  aSpalte[EDIT_TITEL]:="Masch."
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MASKE]:="999"
  aSpalte[EDIT_AFTER]:={;
    |oGet| check(oGet,"Maschine", .f., .f.) .and. NkkopfMaschNach(oGet) .and. changeDate(oget) }
  aSpalte[EDIT_MESSAGE]:="Maschinen-Nummer eingeben.          @F12@ = Auswahl           @ESC@ = Ende"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte[EDIT_NAME]:="MASCHINE->Bez"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_FARBE]:={|| "N+/"+getBackColor()} // gray
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_TITEL]:="R�stzeit"
  aSpalte[EDIT_NAME]:="'Soll:'+str(RuestZeitS,5,2)"
  aSpalte[EDIT_NO_HIGHLIGHT]:=.t.
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="RuestZeit"
  aSpalte[EDIT_TITEL]:="Ist"
  aSpalte[EDIT_BEFORE]:={ || MySetKey( K_F8 , {|p1,oGet| copyRuestZeit(oGet,p1)})}
  aSpalte[EDIT_AFTER]:={;
    |oGet| nachRuestZeit(oget) .and. changeDate(oget) .and. MySetKey( K_F8 , NIL)}
  aSpalte[EDIT_MESSAGE]:="Ben�tigte R�stzeit eingeben.    @F8@ Vorgabe �bernehmen"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Zeit"
  aSpalte[EDIT_TITEL]:="Zeit"
  aSpalte[EDIT_BEFORE]:={ || setNkZeitKeys(1) }
  aSpalte[EDIT_AFTER]:={ |oGet| nkZeitNach(oGet) .and. changeDate(oget) .and. setNkZeitKeys(0)}
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_MASKE]:="@K 99.99"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Gesamt-Zeit (Industrie-Minuten) eingeben.   @F3@=Zeit-Erfassung"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="getNKZeitString()"
  aSpalte[EDIT_NO_HIGHLIGHT]:=.t.
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="GutMenge"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_TITEL]:="Gut-Menge"
  aSpalte[EDIT_AFTER]:={ |oGet| changeDate(oget) }
  aSpalte[EDIT_MASKE]:="9999999"
  aSpalte[EDIT_MESSAGE]:="Gutmenge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Ausschuss"
  aSpalte[EDIT_TITEL]:="Ausschu�"
  aSpalte[EDIT_MASKE]:="9999999"
  aSpalte[EDIT_AFTER]:={ |oGet| changeDate(oget) }
  aSpalte[EDIT_MESSAGE]:="Ausschu� eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/
  Edit(aFelder,aKopf)

  MySetKey( K_F8 , NIL)
  setNkZeitKeys(0)

RETURN( aKopf[EDIT_CHANGED] )
/* EOF */

static function changeDate(oget)
  if oGet == NIL .or. oGet:changed
    replace NKERF->Datum with getUser():date
  endif
return .t.
/** eof */

static function setNkZeitKeys(ON)
LOCAL k, keys:={ K_F3 }
  if ON > 0
    for each k in keys
      MySetKey( k , {|p1,oget| nkZeitNach(oGet,.t.,p1)})
    next
  else
    for each k in keys
      MySetKey( k , NIL)
    next
  endif
return .t.
/** eof */

/* wird nach Eingabe der R�stzeit ausgef�hrt */
static function nachRuestZeit( oGet )
  if val(oGet:buffer) <= 0 .and. ! ABBRUCH .and. NKERF->RuestZeitS <> 0
    Error(ACHTUNG+"R�stzeit muss eingegeben werden.")
    return .f.
  endif
  if ! getUser():id==KURZEL_MAIN_CUSTOMER
    if (val(oGet:buffer) > 6 .and. ! ABBRUCH .and. NKERF->RuestZeitS == 0) .or.;
      (val(oGet:buffer) > 2 * NKERF->RuestZeitS .and. NKERF->RuestZeitS > 0)
      Error(ACHTUNG+"R�stzeit zu lang.  Bitte R�cksprache mit H. Weiland.")
      return .f.
    endif
  endif
return .t.
/** eof */

/* kopiert die Soll-R�stzeit */
static function copyRuestZeit( oGet )
  // Fehler kann passieren, wenn F8 bei Anzeige einer Fehlermeldung (R�stzeit muss eingegeben werden) gedr�ckt wird
  BEGIN SEQUENCE // krit. Bereich
    oGet:varput(NKERF->RuestZeitS)
    keyboard chr(K_RETURN)
  END Sequence
return .t.
/** eof */

/* wird nach Eingabe der Maschinen-Nummer im Kopf ausgef�hrt */
static function NkkopfMaschNach( oGet )
LOCAL aktRec:=NKERF->(recno())
LOCAL HauptMaschinen

  if MASCHINE->Status == "X"
    Error(ACHTUNG+"Maschine ist als verschrottet deklariert.  ||"+;
      "         Bitte in St�ckliste anpassen.")
  endif

  if oget:changed()

    // pr�fe ob Maschine in Maschinengruppen zugelassen
    if ! aContains( StueckListe():new(M->merkArtNr):getAlternativeMaschinen(), oGet:Buffer)
      Error(ACHTUNG+"Maschine nicht in St�ckliste oder Maschinengruppe.")
      return .f.
    endif

    // �bernehme R�stzeit von Hauptmaschine
    HauptMaschinen:=Stueckliste():new(M->merkArtNr):getZeiten(oGet:buffer,"H")
    if len(HauptMaschinen) > 0
      replace NKERF->RuestZeitS with HauptMaschinen[1]:RuestZeit
    endif

  endif
return .t.
/** eof */

/* 
* alternativ Spaltendef. bei Nachkalk editieren -> ZusatzMaterial
*/
static FUNCTION NKZusatzMat()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]

  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Art"
  aSpalte[EDIT_MASKE]:="!!!"
  aSpalte[EDIT_AFTER]:={ |oGet| NKERF->Art$"AMZ" .and. NKArtNach(oGet)}
  aSpalte[EDIT_MESSAGE]:="Art eingeben.  @Z@eiten/Menge  @M@aterial  @A@rtikel  @F12@=Auswahl   @ESC@ = Ende"
  aSpalte[EDIT_AUSGABE]:=.t. // n�tig , falls Zuschlag

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /* Feld-Definitionen */
  // Artikel-Nr
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_NAME_GET]:="NKMatNr"
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.,.f.) .and. NKArtNrNach(oGet)}
  if NKERF->Art=="A"
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.      @F12@=Auswahl         @ESC@=Ende"
  else
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer Material eingeben.      @F12@=Auswahl         @ESC@=Ende"
  endif
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Bez1"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Bez2"
  aSpalte[EDIT_POS_X]:=2
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Verbrauch:'"
  aSpalte[EDIT_POS_X]:=8
  aSpalte[EDIT_NO_HIGHLIGHT]:=.t.
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_MESSAGE]:="Gebrauchtes Material (gesamt) eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| val(oGet:buffer) > 0 .or. lastkey()==K_UP}
  aSpalte[EDIT_NAME]:="MatMenge"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_NO_HIGHLIGHT]:=.t.
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


RETURN(aFelder)
  /* EOF Ang_Text */


/* wird nach Eingabe der Art ausgef�hrt */
static function NKArtNach( oGet )
LOCAL aktRec:=NKERF->(recno())
LOCAL maxLfdNr:=0, okay:=.f.

  ignore oGet

  // Spezial-Fall Artikel nur bei bestimmten Maschinen (Spritzguss) und falls in St�ckliste
  if oGet:buffer=="A"
    go top
    do while .not. NKERF->(eof())
      if NKERF->MaschNr >= "301" .and. NKERF->MaschNr <= "315"
        okay:=.t.
        exit
      endif
      skip
    enddo
    NKERF->(dbgoto( aktRec ))
    if ! okay
      Error(ACHTUNG+"Artikel Eingabe nur bei Spritzguss m�glich.")
      return .f.
    endif
  endif

  // setze laufende Posten-Nummer
  if NKERF->lfdNr == 0
    go top
    do while .not. NKERF->(eof())
      maxLfdNr:=max(maxLfdNr,NKERF->lfdNr)
      skip
    enddo
    NKERF->(dbgoto( aktRec ))
    replace NKERF->lfdNr with maxLfdNr+1
  endif

return .t.
/** eof */

static function NKArtNrNach( oGet )
LOCAL isChild:=.f.
LOCAL aktSel:=alias()
LOCAL aktRec:=recno()
LOCAL stueckliste, merkOrder, gesamtMenge, altMat, allArtNrs:={}

  if oget:changed()

    if NKERF->MatBuch > 0
      Error(ACHTUNG+"Nachkalk bereits verbucht.  Posten kann nicht ge�ndert werden.||"+;
        "         Alternativ Posten l�schen und neu erfassen.")
      return .f.
    endif

    select Nkmehrf
    go top
    do while ! NKMEHRF->(eof()) .and. ! isChild
      Stueckliste:=StueckListe():new( NKMEHRF->ArtNr )
      aadd(allArtNrs, out(NKMEHRF->ArtNr, .t.))
      isChild:=StueckListe:containsChild( oGet:Buffer , .t. )
      skip
    enddo
    select(aktSel)

    // special case: Artikel bei Spritzguss
    if NKERF->Art=="A"
      if ! isChild
        Error(ACHTUNG+"Nur Artikel die in folgenden Artikeln enthalten sind|"+;
          "         k�nnen erfasst werden:||"+;
          "         "+array2readable( allArtNrs))
        return .f.
      endif

      // pr�fe das kein Material als Artikel erfasst wird
      if isMaterial(NIL, INNER->ArtNr, oGet:Buffer)
        Error(ACHTUNG+"Material bitte mit Art='M' erfassen")
        return .f.
      endif

    elseif NKERF->Art=="M"

      // pr�fe ob Material zu Artikel passt
      if (left(INNER->ArtNr,1) $ "3" .and. .not. left(oget:buffer,1) $ "7")
        Error(ACHTUNG+"Nur 7er Material zugelassen.")
        return .f.
      endif
      if (left(INNER->ArtNr,1) $ "4" .and. .not. left(oget:buffer,1) $ "9")
        Error(ACHTUNG+"Nur 7er Material zugelassen.")
        return .f.
      endif

      // 20220131 wieder raus -> Konsequenzen alle klar?
      // pr�fe dass Material nur 1x eingegeben wird -> FIXME: das soll raus
      loca for NKERF->ArtNr == oget:buffer .and. NKERF->(recno()) <> aktRec
      // loca for NKERF->Art == "M" .and. NKERF->(recno()) <> aktRec
      if ! NKERF->(eof())
        Error(ACHTUNG+"Material bereits erfasst.")
        NKERF->(dbgoto( aktRec ))
        return .f.
      endif
      NKERF->(dbgoto( aktRec ))
    endif
    // obsolete NKMEHRF sollte immer 1 Artikel enthalten 20201008
    // if NKMEHRF->(reccount()) == 0 // keine Mehrfachspritzung nehme 1. Artikel
    // isChild:=StueckListe:containsChild( oGet:Buffer , .t. )
    // endif

    select(aktSel)

    if ! isChild
      // pr�fe alternat. Material
      for each altMat in getNKMaterialVorschlag()
        isChild:=isChild .or. oGet:buffer == left(altMat,len(oget:buffer))
      next
      if ! isChild
        Error(ACHTUNG+"Artikel nicht in St�ckliste enthalten.")
        return .f.
      endif
    endif

    ARTIKEL->(dbseek( oGet:Buffer ))
    replace NKERF->Bez1 with ARTIKEL->Bez1
    replace NKERF->Bez2 with ARTIKEL->Bez2
    replace NKERF->ME with ARTIKEL->ME

    // Menge vorschlagen bei Vakuum (4er Artikel)
    if NKERF->MatMenge == 0 .and. left(M->merkArtNr,1)=="4"
      sum NKERF->GutMenge + NKERF->Ausschuss to gesamtMenge for NKERF->Art == "Z"
      NKERF->(dbgoto( aktRec ))
      merkOrder:=AVPOST->(OrdSetFocus( 2 )) // ArtNr + AvNr
      AVPOST->(dbseek( ARTIKEL->ArtNr + M->merkArtNr ))
      if ! AVPOST->(eof())
        replace NKERF->MatMenge with AVPOST->Menge * gesamtMenge
      endif
      AVPOST->(OrdSetFocus( merkOrder ))
    endif

  endif
return .t.

/* nach Eingabe von/bis bzw. der Zeit werden die anderen Felder angepasst */
static function nkZeitNach(oGet, force)
LOCAL s01:=savescreen(),zeitTemp
LOCAL zeitEintrag
LOCAL zeiten, automat:=.f., allePersonen, tempVal
LOCAL aktSel:=alias()

  default force:=.f.

  /* zur�ck immer erlaubt */
  if lastkey()==K_UP
    oget:undo()
    RETURN(.t.)
  endif

  // bei manueller Eingabe pr�fe ob noch Zeiteintr�ge vorhanden sind
  if ! force .and. oget:changed
    NKZEIT->(dbseek( NKERF->NKNr + str(NKERF->lfdNr,3) ))
    if ! NKZEIT->(eof())
      if Message("Vorhandene Zeiteintr�ge l�schen?  (@J@/@N@)","JN"," ")=="J"
        NKZEIT->(dbseek( NKERF->NKNr + str(NKERF->lfdNr,3) ))
        myDelete("NKZeit", { || NKZEIT->NKNr == NKERF->NKNr .and. NKZEIT->lfdNr == NKERF->lfdNr })
      endif
    endif
  endif

  // hole automat. Nutzen j/n aus Zeit St�ckliste
  PERSONAL->(dbseek( NKERF->PersNr ))
  if empty(PERSONAL->Kurzel)
    automat:=.t.
  else
    zeiten:=Stueckliste():new( M->merkArtNr ):getZeiten(NKERF->MaschNr)
    if len(zeiten) > 0
      automat:=(zeiten[1]:automat == "J")
    endif
  endif

  if force .or. ((empty(oGet:buffer) .or. val(oget:buffer) == 0) .and. lastkey() == K_RETURN)

    // kopiere Zeiten zum bearbeiten
    select ZeitErf
    zap
    NKZEIT->(dbseek( NKERF->NKNr + str(NKERF->lfdNr,3) ))
    append("NKZeit", {|| NKZEIT->NKNr == NKERF->NKNr .and. NKZEIT->lfdNr == NKERF->lfdNr})

    // erfasse Zeiten (ZeitEdit)
    setNkZeitKeys(0)
    if NK_Zeit_erfass(automat)
      NKZEIT->(dbseek( NKERF->NKNr + str(NKERF->lfdNr,3) ))
      myDelete("NKZeit", { || NKZEIT->NKNr == NKERF->NKNr .and. NKZEIT->lfdNr == NKERF->lfdNr })

      /* summieren der Arbeitszeit */
      SELECT ZeitErf
      go top
      zeitEintrag:=zeitEintrag():new()
      // allePersonen:={left(NKERF->PersNr,3)}
      allePersonen:={}
      do while .not. ZEITERF->(eof())
        // Industrieminuten
        zeitTemp:=ZeitDif(ZEITERF->Start,ZEITERF->Ende,ZEITERF->Pause,.t.,.t.,ZEITERF->Personen)
        if zeitTemp<0 // Fehler bei Zeiteingabe
          select (aktSel)
          return .f.
        endif

        // neu 20220511: jetzt immer bei mehreren Personen parallel, Maschine egal.
        // s. email vom 1.5.2022 ca. 6:30 Uhr
        // neue Ausnahme 20201022: falls mehrere Personen daran arbeiten, dann nacheinander
        // nur bei Montage (Masch.Nr 870) wird parallel gearbeitet
        // if ZEITERF->Personen>1 .and. NKERF->MaschNr == "870" // FIXME: KZ in Maschinenstamm
        // zeitTemp:=ZeitTemp*ZEITERF->Personen
        // endif

        zeitEintrag:add(ZEITERF->GutMenge, ZEITERF->Ausschuss, zeitTemp )

        // merke alle Personen
        aEval(HB_ATokens(ZEITERF->PersNr," "), { |x| aaddUnique(allePersonen,x)})

        // kopiere nach NKZeit
        select NKZeit
        add_rec(0)
        overwrite("ZeitErf", .t.)
        replace NKZEIT->NKNr with NKERF->NkNr
        replace NKZEIT->lfdNr with NKERF->lfdNr
        dbcommit()
        dbunlock()
        select Zeiterf

        skip
      enddo

      // �bernehme Pers.Nr aus Zeiterfassung, falls ursrp. eingegebene nicht enthalten
      if len(allePersonen) > 0 .and. aScan(allePersonen,NKERF->PersNr) == 0
        replace NKERF->PersNr with allePersonen[1]
      endif

      select NKErf
      // aktuallisiere aktuellen Datensatz
      tempVal:=getPersNrSorted(allePersonen, NKERF->PersNr)
      if tempVal <> NKERF->PersNr
        replace NKERF->PersNr with tempVal
      endif

      replace NKERF->GutMenge with zeitEintrag:GutMenge
      replace NKERF->Ausschuss with zeitEintrag:Ausschuss
      replace NKERF->Zeit with zeitEintrag:GesStd

      if force
        keyboard chr(K_PGDN) // Ende der Eingabe
      endif
      changeDate()
    endif
    select (aktSel)
    setNkZeitKeys(1)
    restscreen(,,,,s01)
  endif

return .t.
  /** eof */

static function getPersNrSorted(alle, haupt)
LOCAL ohne
  haupt:=left(haupt,3)
  ohne := hb_aDel(alle , aScan( alle , haupt) , .t. )  /** shrink it */
return haupt + " " + array2readable(aSort(ohne), " ")


/** Helper class to sum up time entries */
class ZeitEintrag
DATA GutMenge INIT 0
DATA Ausschuss INIT 0
DATA GesStd INIT 0

METHOD new(Gut,Aus,GesStd)
METHOD addEintrag(zeitEintrag)
METHOD add(Gut,Aus,GesStd)
ENDCLASS

METHOD new(GutMenge,Ausschuss,GesStd)
  if valtype(GutMenge)=="N"
    ::GutMenge:=GutMenge
  endif
  if valtype(Ausschuss)=="N"
    ::Ausschuss:=Ausschuss
  endif
  if valtype(GesStd)=="N"
    ::GesStd:=GesStd
  endif
return self

METHOD addEintrag(zeitEintrag)
  ::GutMenge += zeitEintrag:GutMenge
  ::Ausschuss += zeitEintrag:Ausschuss
  ::GesStd += zeitEintrag:GesStd
return self

METHOD add(GutMenge,Ausschuss,GesStd)
  ::GutMenge += GutMenge
  ::Ausschuss += Ausschuss
  ::GesStd += GesStd
return self

/** eoc ZeitEintrag */  

  /** pr�ft ob  eine Zeit einegegeben ist */
static function nkZeitCheck()
  if NKERF->Art=="Z" .and. empty(NKERF->Zeit) .and. (NKERF->GutMenge > 0 .or. NKERF->Ausschuss > 0)
    Error(ACHTUNG+"Zeit muss eingegeben werden.")
    return .f.
  endif
  MySetKey( K_F8 , NIL)
return .t.

function getNKMaterialVorschlag(art)
LOCAL result:={} , mat
LOCAL aktSel:=alias()
LOCAL aktArt:=ARTIKEL->(recno())
LOCAL aktRec:=NKMEHRF->(recno())

  default art:="M"

  select Nkmehrf
  go top
  do while ! NKMEHRF->(eof())
    for each mat in StueckListe():new( NKMEHRF->ArtNr ):getMaterial( .t. )
      result:=nkAaddUnique( result , mat:ArtNr, art )

      // 20220131 zeige alternat Material an
      ARTIKEL->(dbseek( mat:ArtNr ))
      if .not. empty(ARTIKEL->MatArtNr)
        result:=nkAaddUnique( result , ARTIKEL->MatArtNr, "M" )
      endif

    next
    skip
  enddo

  // obsolete NKMEHRF sollte immer 1 Artikel enthalten 20201008
  // if NKMEHRF->(reccount()) == 0 // keine Mehrfachspritzung nehme 1. Artikel
  // for each mat in StueckListe():new( M->merkArtNr ):getMaterial( .t. )
  // result:=nkAaddUnique( result , mat:ArtNr )
  // next
  // endif

  ARTIKEL->(dbgoto( aktArt ))
  NKMEHRF->(dbgoto( aktRec ))
  select (aktSel)

return asort(result)
    /** eof */

/** f�gt das Material zum Array, wenn die Bedingung erf�llt wird:
  3er Artikeln 7er Material oder
  4er Artikeln 9er Material oder
*/
static function nkAaddUnique(result, myartnr, art)
LOCAL isMat:=isMaterial(NIL, INNER->ArtNr, myArtNr)
  ARTIKEL->(dbseek( myArtNr ))
  if (art=="M" .and. isMat) .or. (art=="A" .and. ! isMat)
    aaddUnique(result, myartnr + space(1) + ARTIKEL->Bez1 )
  endif
return result

/****
* Anzeigen der SUMME bzw. Durchschnitt der Kosten in F8 Nachkalkulations-�bersicht
*/

FUNCTION NKSum(oBrowse, edit, allGroups)
LOCAL merk_Farbe:=setcolor()
LOCAL Vk_soll:=0.00,VK_Ist:=0.00
LOCAL GetList:={}
LOCAL orgAltF8, summen
LOCAL M_RuestZeit, M_Menge, M_Stunde, M_MatStk
LOCAL shiftDisp:=-1
LOCAL aktSel:=alias() , MaschinenText, MaschNr, group
LOCAL wasLocked

  static groups

  if oBrowse == NIL
    groups:=NIL
    return .t.
  endif

  if allGroups <> NIL
    groups:=allGroups
  endif

  default edit:=.f.

  setcolor(COLNOR)

  summen:=NachKalkSummen():new(ARTIKEL->ArtNr)

  if edit
    Umgebung(WRITE)
    orgAltF8:=SetKey( K_F8, {|p1,oGet| summen:CopyVorgabe(oget,p1)})
    setcursor(DEUTE_MARKE)
    M_RuestZeit:=summen:RuestZeit
    M_Menge:=summen:mengeAB
    M_Stunde:=summen:Stunde
    M_MatStk:=summen:MatStk
    Message("Vorgaben eingeben.   @F8@=Durchschnitt �bernehmen")
    @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 21 get summen:RuestZeit picture "99.99"
    @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 28 get summen:mengeAB picture "9999999"
    @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 37 get summen:Stunde picture "9999.99" ;
      when Message("Vorgaben eingeben.   @F8@=Durchschnitt �bernehmen")

    if left(ARTIKEL->ArtNr,1) $ "3"
      @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 45 get summen:MatStk picture "999.999" ;
        when Message("Vorgaben eingeben.   @F8@=Durchschnitt �bernehmen")
    endif
    select Artikel
    wasLocked:=ARTIKEL->(isLocked())
    if rec_lock(5)
      @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 54 get ARTIKEL->WKZ ;
        when Message("Artikel Kennzeichen eingeben.")
    endif
    select (aktSel)
    read
    SetKey( K_F8 , orgAltF8)
    setcursor( SC_NONE )

    summen:commit()
    if .not. wasLocked
      ARTIKEL->(dbcommit())
      ARTIKEL->(dbunlock())
    endif

    Umgebung(LOAD)

  endif // Display only

  // clear some lines only, not the message line
  @ oBrowse:nBottom + 2,0
  @ oBrowse:nBottom + 3,0
  @ oBrowse:nBottom + 4,0
  @ oBrowse:nBottom + 5,0

  @ oBrowse:nBottom + 3,oBrowse:nLeft say "Durchschnittswerte->" + space(1+shiftDisp);
    + str(summen:DRuestZeit,5,2) + space(2) ;
    + str(summen:DMengeAB,7,0) + space(1) ;
    + str(summen:DStunde ,8,2) + space(0)
  if left(ARTIKEL->ArtNr,1) $ "3"
    @ oBrowse:nBottom + 3, oBrowse:nLeft + shiftDisp + 44 say str(summen:DMatStk ,8,3)
  endif

  @ oBrowse:nBottom + 4 , oBrowse:nLeft say "Vorgaben----------->" + space(1+shiftDisp);
    + str(summen:RuestZeit,5,2) + space(2) ;
    + str(summen:mengeAB,7,0) + space(1) ;
    ++ str(summen:stunde,8,2) + space(0)
  if left(ARTIKEL->ArtNr,1) $ "3"
    @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 44 say str(summen:MatStk ,8,3)
  endif
  @ oBrowse:nBottom + 4 , oBrowse:nLeft + shiftDisp + 54 say ARTIKEL->WKZ

  /* suche Zuschlag in St�ckliste */
  vk_ist:=if(ARTIKEL->Schluessel=="H",ARTIKEL->Preis1/100,ARTIKEL->Preis1)
  vk_soll:=if(ARTIKEL->Schluessel=="H",ARTIKEL->Soll_VK/100,ARTIKEL->Soll_VK)
  if vk_soll>0 .and. vk_soll > vk_ist
    setcolor("R/W")
  endif
  @ oBrowse:nBottom + 3,oBrowse:nLeft+59 say "VK-Soll:"+str(vk_soll,10,2)
  @ oBrowse:nBottom + 4,oBrowse:nLeft+59 say "VK-Ist :"+str(vk_ist,10,2)
  setcolor(merk_Farbe)

  if Groups <> NIL
    // Maschinen-Namen oben anzeigen
    @ oBrowse:nTop-3,0
    MaschinenText:=""

    @ oBrowse:nTop - 2,0
    @ oBrowse:nTop - 2,oBrowse:nLeft say "Gruppe  : "
    for each group in groups:keys
      if MASCHINE->Maschgr == group .or. NKPOST->MaschNr == group .or. ;
        (group == MASCH_GROUP_3er .and. left(MASCHINE->MaschGr,1) =="3")
        setcolor(COLINV)
        for each maschnr in asort(groups[group])
          MASCHINE->(dbseek( maschNr ))
          MaschinenText += MASCHINE->StdNr+" "+trim(MASCHINE->Bez)+ "   "
        next
      endif
      qqout(group +" (" + array2readable(asort(groups[group])," ") + ")")
      setcolor(COLNOR)
      qqout(space(3))
    next
    @ oBrowse:nTop-3,0 say "Maschine: " + MaschinenText
    dbskip(0)
  else
    // Maschinen-Namen oben anzeigen
    @ oBrowse:nTop-2,0
    @ oBrowse:nTop-3,0
    @ oBrowse:nTop-2,0 say "Maschine: " + MASCHINE->StdNr+" "+MASCHINE->Bez
  endif

  setcolor(merk_Farbe)

RETURN(.t.)
  /** eof */

/*----------------------------------------------------------------------*/

  /** Kalkuliert die Summen/Durchschnitte der Nachkalkulation je Artikel / Gruppe
  *
  *  Achtung: einige Relationen & Filter m�ssen vorher gesetzt sein,
  *           s. NKpruefeAbweichung() oder hilfdef#kalk-ueber als Beispiel   
  */
class NachKalkSummen

DATA DMatStk INIT 0 // Durchschnittswerte
DATA DMengeAB INIT 0
DATA DStunde INIT 0
DATA DRuestzeit INIT 0

DATA MatStk INIT 0 // Vorgaben
DATA MengeAB INIT 0
DATA Ruestzeit INIT 0
DATA Stunde INIT 0

DATA M_MatStk // Kopie der Initial-Werte
DATA M_MengeAB
DATA M_Ruestzeit
DATA M_Stunde

DATA Anzahl INIT 0
DATA MaschNr INIT "   "
DATA ArtNr

  // raus 202410114: DATA WkzNutzen INIT 1

METHOD new(artNr) // Neue Durchschnittswerte berechnen
METHOD copyVorgabe()
METHOD commit()
METHOD commitAvMatMenge()
ENDCLASS

METHOD new(mArtNr)
LOCAL SumMengeStd:=0, SumGutMenge:=0
LOCAL SumRuestZeit:=0, SumMatStk:=0 , matAnz:=0
LOCAL ruestAnz:=0, pos
LOCAL aktSel:=alias()
LOCAL merkRec:=NKPOST->(recno())
LOCAL stueckliste, HauptMaschinen, Material, maschine, treffer

  ::ArtNr:=mArtNr

  ARTIKEL->(dbseek( ::ArtNr ))
  stueckliste:=Stueckliste():new(mArtNr, ARTIKEL->Art)
  HauptMaschinen:=stueckliste:getZeiten(,"H",.t.)
  Material:=stueckliste:getMaterial(.t.)

  if left(ARTIKEL->ArtNr,1) $ "3" .and. len(Material) > 0
    if (pos:=ascan(Material, {|mat| isMaterial(NIL,ARTIKEL->ArtNr,mat:artNr)})) > 0
      ::matStk:=Material[pos]:menge
    endif
  endif

  // ::WkzNutzen:=val(Stueckliste():new(ARTIKEL->ArtNr):getWerkzeugMenge())

  select Nkpost
  go top
  do while ! NKPOST->(eof())
    if NKPOST->Ausfall <> "J"
      ::Anzahl++
      if NKPOST->Zeit > 0
        SumMengeStd+= getNKStkStd()
      endif
      SumGutMenge+=kalkNutzen(NKPOST->GutMenge)

      if NKPOST->RuestZeit > 0
        SumRuestZeit += kalkRuestzeit(NKPOST->RuestZeit)
        ruestAnz++
      endif

      if NKPOST->MatZug > 0
        SumMatStk += kalkMatStk(NKPOST->MatZug)
        matAnz++
      endif

    endif

    // pr�fe ob Maschine mit gleicher Gruppe in St�ckliste
    if maschine == NIL
      MASCHINE->(dbseek(NKPOST->MaschNr))
      treffer:=aScan(HauptMaschinen, {|x| (empty(MASCHINE->Maschgr) .and.;
        NKPOST->MaschNr == trim(x:artnr)) .or. (! empty(MASCHINE->Maschgr) .and.;
        MASCHINE->Maschgr == x:maschgr) })
      if treffer > 0
        Maschine:=HauptMaschinen[treffer]
      endif
    endif

    skip
  enddo
  go (MerkRec)
  select (aktSel)

  // special case: 3er Gruppe und Hauptmaschine in St�ckliste noch nicht verwendet
  // => nehme 1. 3er Hauptmaschine aus Zeitst�ckliste neu: 20230426
  if maschine == NIL .and. left(ARTIKEL->ArtNr,1) $ "3" .and. ::Anzahl > 0 .and.;
    len(HauptMaschinen) > 0
    treffer:=aScan(HauptMaschinen, {|x| left(x:maschgr,1)=="3" })
    if treffer > 0
      Maschine:=HauptMaschinen[treffer]
    endif
  endif

  if maschine <> NIL
    ::maschNr:=Maschine:getMaschNr()
    ::mengeAB:=Maschine:sollMenge
    ::stunde:=Maschine:Menge
    ::RuestZeit:=Maschine:RuestZeit // raus 202410114 / ::WkzNutzen
  else
    // nehme Ruestzeit aus HauptMaschinen-Stamm
    MASCHINE->(dbseek(NKPOST->MaschNr))
    ::ruestzeit:=MASCHINE->RuestZeit // raus 202410114 / ::WkzNutzen
  endif

  if ::Anzahl > 0
    ::DStunde:=SumMengeStd / ::Anzahl
    ::DMengeAB:=SumGutMenge / ::Anzahl
  endif
  if RuestAnz > 0
    ::DRuestZeit:=SumRuestZeit / ruestAnz
  endif
  if MatAnz > 0
    ::DMatStk:=SumMatStk / MatAnz
  endif

  // merke orginal Werte
  ::M_matStk:=::matStk
  ::M_mengeAB:=::mengeAB
  ::M_stunde:=::stunde
  ::M_RuestZeit:=::RuestZeit

return self

METHOD copyVorgabe(oGet)
  if upper(oGet:name) == "SUMMEN:RUESTZEIT"
    oGet:varput(::DRuestZeit)
    keyboard chr(K_RETURN)
  elseif upper(oGet:name) == "SUMMEN:MENGEAB"
    oGet:varput(::DMengeAB)
    keyboard chr(K_RETURN)
  elseif upper(oGet:name) == "SUMMEN:STUNDE"
    oGet:varput(::DStunde)
    keyboard chr(K_RETURN)
  elseif upper(oGet:name) == "SUMMEN:MATSTK"
    oGet:varput(::DMatStk)
    keyboard chr(K_RETURN)
  endif
return .t.

// schreibt die Werte wieder zur�ck in die St�ckliste
METHOD commit()
LOCAL treffer:=.f.
  // Schreibe Materialverbrauch in St�ckliste
  if ::M_MatStk <> ::MatStk
    ::commitAvMatMenge()
  endif

  // schreibe Maschinen-Werte nach Zeitst�ckliste
  if ::M_RuestZeit <> ::RuestZeit .or. ::M_MengeAB <> ::mengeAB .or. ::M_Stunde <> ::Stunde

    // suche Maschine in St�ckliste
    Umgebung(WRITE_ALL)
    select AvPost
    AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr
    AVPOST->(dbseek(left(::maschNr+space(len(AVPOST->ArtNr)),len(AVPOST->ArtNr)) + ::ArtNr))
    do while ! AVPOST->(eof()) .and. ::ArtNr == AVPOST->AvNr .and. ::MaschNr==trim(AVPOST->ArtNr)
      if AVPOST->HauptKz=="H" .and. AVPOST->Art=="V" .and. AVPOST->Text=="A" .and. rec_lock(5)
        replace AVPOST->ruestzeit with ::ruestzeit // falsch, raus 20210228 * ::WkzNutzen
        replace AVPOST->sollMenge with ::mengeAB
        replace AVPOST->Menge with ::Stunde
        dbcommit()
        dbunlock()
        treffer:=.t.

        // Setze Menge f�r alle Nebenmaschinen die nach der
        // aktuellen Hauptmaschine und vor der n�chsten HM kommen
        if ::M_Stunde <> ::Stunde
          AVPOST->(OrdSetFocus(1)) // AvNr
          skip
          do while ! eof() .and. ! (AVPOST->HauptKZ=="H" .and. AVPOST->Text=="A") .and.;
            ::ArtNr == AVPOST->AvNr
            if (AVPOST->HauptKZ=="N" .and. AVPOST->Text=="A") .and. rec_lock(5)
              replace AVPOST->Menge with ::Stunde
              dbcommit()
              dbunlock()
            endif
            skip
          enddo
          AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr
        endif

        exit // we bail out, nur f�r eine HauptMaschine mit evtl. folgenden Nebenmaschinen

      endif
      skip
    enddo
    if ! treffer
      Error(ACHTUNG+"Maschine: " + ::MaschNr + " nicht in Zeitst�ckliste hinterlegt.||"+;
        "         Vorgaben konnten nicht gespeichert werden.")
    endif

    Umgebung(LOAD)
  endif

return self

/** setzt die AV Menge des Materials (falls eindeutig) */
METHOD commitAvMatMenge()
LOCAL count:=0, treffer

  Umgebung(WRITE_ALL)
  select AvPost
  AVPOST->(dbseek(::ArtNr))
  do while ! AVPOST->(eof()) .and. ::ArtNr == AVPOST->AvNr
    if AVPOST->Art=="M" .and. AVPOST->Text=="A" .and. AVPOST->Menge > 0
      // Special case 3er und 4er Artikel
      if left(AVPOST->AvNr,1) $ "3|4"
        if isMaterial(NIL, AVPOST->AvNr, AVPOST->ArtNr)
          count++
          treffer:=AVPOST->(recno())
        endif
      else
        count++
        treffer:=AVPOST->(recno())
      endif
    endif
    skip
  enddo

  if count == 1
    AVPOST->(dbgoto(treffer))
    if rec_lock(5)
      replace AVPOST->Menge with ::MatStk
      dbcommit()
      dbunlock()
    endif
  elseif count == 0
    Error(ACHTUNG+"Keine Materialeintr�ge gefunden.||Bitte manuell in St�ckliste �ndern.")
    launchNewProgram( "ARTIKEL", ::ArtNr, "M|")
  else
    Error(ACHTUNG+"Mehrere Materialeintr�ge gefunden.||Bitte manuell in St�ckliste �ndern.")
    launchNewProgram( "ARTIKEL", ::ArtNr, "M|")
  endif

  Umgebung(LOAD)

return self
/** eop */


/* EOC NachKalkSummen ----------------------------------------------------------------------*/


/*
* l�sche einzelnen Satz aus Kalk.�bersicht heraus
*/
FUNCTION NK_Satz_loeschen(oBrowse)
LOCAL isAlteNachkalk:=empty(NKARTIKEL->InLfdNr)
LOCAL mNKNr:=NKPOST->NkNr, count:=0, Gruppe

  // pr�fe ob noch Eintr�ge vorhanden (nur neue Nachkalk)
  if ! isAlteNachkalk
    Umgebung(WRITE_ALL)
    select NkPost
    NKPOST->(OrdSetFocus(1)) // NkNr
    NKPOST->(dbseek(mNkNr))
    do while NKPOST->NkNr == mNKNr .and. ! NKPOST->(eof())
      if NKPOST->Art=="Z"
        count++
      endif
      skip
    enddo
    if count > 1
      Error(ACHTUNG+"Nachkalkulation enth�lt "+alltrim(str(count,2))+" Arbeitsg�nge.||"+;
        "Wenn Sie nur einzelne Arbeitsg�nge l�schen wollen nehmen Sie: Taste F4|"+;
        "Ansonsten werden hier alle Arbeitsg�nge dieser Nachkalkulation gel�scht.")
    endif
    Umgebung(LOAD)
  endif

  if Message("Nachkalkulation wirklich l�schen ?  ( @J@ / @N@ )","JN")=="J"
    if ! REC_LOCK(5)
      Error(SATZ_EXCL)
      RETURN(.F.)
    endif

    if empty(MASCHINE->MaschGr)
      gruppe:=NKPOST->MaschNr
    else
      gruppe:=MASCHINE->MaschGr
    endif

    Umgebung(WRITE_ALL)
    NKPOST->(OrdSetFocus(1)) // NkNr
    NKPOST->(OrdDestroy(TEMP_INDEX)) // komisch: kann Datensatz nicht l�schen mit forclause()

    delete
    dbcommit()
    dbunlock()
    dbskip(0) // workaround: ansonsten delete flag geht verloren
    oBrowse:RefreshAll()
    oBrowse:ForceStable()
    // oBrowse:gotop()
    // keyboard(chr(K_HOME)) // gotop alleine geht scheinbar net

    // pr�fe ob noch Eintr�ge vorhanden (nur neue Nachkalk)
    if ! isAlteNachkalk
      NKPOST->(OrdSetFocus(1)) // NkNr
      NKPOST->(dbseek(mNkNr))
      if NKPOST->(eof())
        select Inner
        INNER->(OrdSetFocus(6)) // NkNr
        INNER->(dbseek(mNkNr))
        do while INNER->NkNr == mNKNr .and. ! INNER->(eof())
          if rec_lock(0)
            replace INNER->NkNr with ""
            dbcommit()
            dbunlock()
          endif
          skip
        enddo
      endif
      loescheNachkalkEintraege(mNKNr)
    endif

    setMaschGroupFilter(oBrowse:cargo)

    Umgebung(LOAD)
    NKSum(oBrowse)
  endif

RETURN(.t.)
/* EOF */

/*
* markiert einen einzelnen Satz aus Kalk.�bersicht als Ausfallmuster
*/
FUNCTION NK_Satz_ausfall(oBrowse)

  ignore oBrowse

  if ! REC_LOCK(5)
    Error(SATZ_EXCL)
    RETURN(.F.)
  endif

  Umgebung(WRITE_ALL)

  NKPOST->(OrdSetFocus(1)) // NkNr
  NKPOST->(OrdDestroy(TEMP_INDEX)) // komisch: kann Datensatz nicht �ndern mit forclause()

  if NKPOST->Ausfall=="J"
    REPLACE NKPOST->Ausfall WITH "N"
  else
    REPLACE NKPOST->Ausfall WITH "J"
  endif

  dbcommitall()
  dbunlockall()

  setMaschGroupFilter(oBrowse:cargo)
  Umgebung(LOAD)

  NKSum(oBrowse)
  oBrowse:RefreshAll()
  oBrowse:ForceStable()

  // gehe auf n�chste Zeile
  keyboard chr(K_DOWN)
RETURN(.t.)
/* EOF Kalk_Satz_loeschen */


/*
* Nachkalkulation auf anderen Artikel kopieren
*/
FUNCTION NK_kopieren()
LOCAL M_ArtNr:=space(len(ARTIKEL->ArtNr)), mNKNr
LOCAL kopieAlias:="Kopie"
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()
LOCAL GetList:={}
LOCAL sourceArtNr:=ARTIKEL->ArtNr
LOCAL sourceNKNr:=NKPOST->NKNr, Datei

  Umgebung(WRITE_ALL)

  setcursor(DEUTE_MARKE)
  @ Maxrow(),0 clear
  @ Maxrow(),20 say "Kopieren nach Art.Nr.:" get M_ArtNr valid { |oGet| check(oGet,"Artikel",.f.) }
  read
  setcursor( SC_NONE )
  if ! ABBRUCH

    if M_artNr==sourceArtNr
      Error("Kalkulation kann nicht auf sich selbst kopiert werden.",.t.)
      Umgebung(LOAD)
      return .f.
    endif

    // FIXME: l�sche vorherige Kalk.? obsolete?
    // if Message("Vorhandene Kalkulationsdaten �berschreiben?  Sind Sie sicher? ( @J@ / @N@ ) ","JN")<>"J"

    Message("Kalkulation wird nach: "+M_artNr+" kopiert.    Bitte warten...")

    /** kopiere Posten */
    mNkNr:=hole("NKNr",WRITE,.t.)

    for each datei in { "NKPost", "NkArtikel", "NKZeit" }
      sele (DATEI)
      copy to (temp_Datei) for sourceNKNr==(DATEI)->NKNr
      sele 0
      use (temp_datei) alias (kopieAlias) excl
      go top
      do while ! (kopieAlias)->(eof())
        replace (kopieAlias)->NKNr with mNkNr // all geht net???
        if Datei=="NkArtikel"
          replace (kopieAlias)->ArtNr with m_artNr
        endif
        skip
      enddo
      go top
      sele (DATEI)
      append(kopieAlias)
      close(kopieAlias)
    next

    Message("Kalkulation wurde nach: "+M_artNr+" kopiert.    Bitte @Taste@ dr�cken.","@")

    // keyboard chr(K_HOME)
    // workaround as otherwise additional line is displayes in F8 overview
    // reason: hilfe.prg#clear2ndLine()
    keyboard chr(K_ESC) + chr(K_F8)

  endif
  Umgebung(LOAD)
RETURN(.t.)
/* EOF Kalk_Satz_loeschen */

  /** L�scht evtl. eingegebene Zeiten
  */
static function konsistenzLoesch()

  if ! getUser():id $ "MW/AB" .and. NKERF->Vorgabe == "J"
    Error("L�schen von vorgegebenen Datens�tzen nicht m�glich.")
    return .f.
  endif

  NKZEIT->(dbseek( NKERF->NKNr + str(NKERF->lfdNr,3) ))
  myDelete("NKZeit", { || NKZEIT->NKNr == NKERF->NKNr .and. NKZEIT->lfdNr == NKERF->lfdNr }, .t.)

  // now delete via editor.prg
  HB_KeyPut(EDIT_DELETE)

return .t.
/** eof */

function nkBrowseEdit(oBrowse)
LOCAL GetList:={} , gruppe
  ignore oBrowse

  Umgebung(WRITE_ALL)
  setcursor(DEUTE_MARKE)

  if empty(MASCHINE->MaschGr)
    gruppe:=NKPOST->MaschNr
  else
    gruppe:=MASCHINE->MaschGr
  endif

  if empty(NKARTIKEL->InLfdNr)
    if rec_lock(5)
      NKPOST->(OrdSetFocus(1)) // NkNr
      NKPOST->(OrdDestroy(TEMP_INDEX)) // komisch: kann Datensatz nicht �ndern mit forclause()
      @ oBrowse:rowPos + 5 , oBrowse:nLeft get NKPOST->MaschNr;
        valid { |oGet| check(oGet,"Maschine",.f.) }
      read
      dbcommit()
      dbunlock()
    endif
  else

    NKPOST->(OrdSetFocus( 1 )) // NKNr
    NKPOST->(OrdDestroy(TEMP_INDEX)) // index geht nicht: kann Datensatz nicht �ndern mit forclause()
    //NKPOST->(OrdKeyDel(NKPOST->(ordKey()))) // index geht nicht: kann Datensatz nicht �ndern mit forclause()
    select Inner
    INNER->(OrdSetFocus( 6 )) // NKNr
    INNER->(dbseek( NKPOST->NkNr ))

    if INNER->(eof())
      Error(ACHTUNG+" Nachkalkulation nicht gefunden.",.t.)
      TroubleEmail("Inner-NKNr nicht gefunden: " + NKPOST->NkNr + "  Bitte pr�fen!")
    else
      nachkalkerf(INNER->NkNr)
    endif
  endif

  setMaschGroupFilter(oBrowse:cargo)

  Umgebung(LOAD)
  dbskip(0)
  oBrowse:refreshCurrent()

return .t.
/** eof */

function getNKZeitString()
LOCAL zeit:=ZeitMin(NKERF->Zeit)
LOCAL std:=int(zeit)
LOCAL min:=(zeit - std) * 100
return "(" + str(std,2,0) + "h " + str(min,2,0)+"min)"
/** eof */


/* Berechnet in der Kalk.�bersicht Artikel F8 bei neuen Eint�gen den Nutzen ein:
 *
 * Bei Mehrfachspritzungen: wird mal Nutzen im Werkzeug Taste T multipliziert (Z�ge gemeldet)
 * ansonten: mit ARTIKEL->Wkz Nutzen f. Kalk mulipliziert. (St�ck gemeldet)
  */
function kalknutzen(value)
LOCAL result:=value
  if NKARTIKEL->MengeZug > 1
    result:=value * NKARTIKEL->MengeZug
  endif
return result
  /** eof */

/* Berechnet in der Kalk.�bersicht Artikel F8 bei neuen Eint�gen den Nutzen
  */
function getNKStkStd()
  // LOCAL result:=kalknutzen(NKPOST->GutMenge)
  // LOCAL Zeit:=NKPOST->Zeit + NKPOST->RuestZeit
LOCAL result:=kalknutzen(NKPOST->GutMenge+NKPOST->Ausschuss)
LOCAL Zeit:=getZeitMitNutzen()

  if Zeit = 0
    result:=0
  else
    result:=result / Zeit
  endif

return result
  /** eof */

/* Berechnet die Zeit anhand des Nutzen.
  *
  * i.d.R. 1:1 aus NKPOST,
  * ausser MASCHINE->Nutzen=="J", dann wird duch den Nutzen geteilt.
  */
function getZeitMitNutzen()
  MASCHINE->(dbseek(NKPOST->MaschNr))
  if ! MASCHINE->(eof()) .and. MASCHINE->Nutzen=="J" .and. NKARTIKEL->Nutzen2 <> 0
    return NKPOST->Zeit * NKARTIKEL->Nutzen1 / NKARTIKEL->Nutzen2
  endif
return NKPOST->Zeit
/* eof */


/** Liefert das Material pro St�ck basierend auf Menge Zug und evtl. anderen Artikeln im Werkzeug */
function kalkMatStk(MatZug)
LOCAL result:=MatZug

  if NKARTIKEL->MengeZug > 1
    result:=result / NKARTIKEL->MengeZug
  endif

  if NKARTIKEL->MatFaktor <> 0
    result:=result * NKARTIKEL->MatFaktor
  endif

return result
/** eof */

/** Liefert die R�stzeit relativ zu der Anzahl anderen Artikeln im Werkzeug (Nutzen) */
function kalkRuestzeit(zeit)
LOCAL result:=zeit

  if NKARTIKEL->Nutzen1 > 1 .or. NKARTIKEL->Nutzen2 > 1
    result:=result * NKARTIKEL->Nutzen1 / NKARTIKEL->Nutzen2
  endif

return result
/** eof */

/* 
* zum erfassen der Arbeitszeit Nachkalkulation
  *
*/
Function NK_Zeit_erfass(automatisch)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  default automatisch:=.f.

  Umgebung(WRITE_ALL)

  select ZeitErf
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=8 // N: Begin des Eingabe-Berreiches BS
  // aKopf[EDIT_ENDE_Y]:=18 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-5 // N: Ende des Eingabe-Berreiches BS abzgl. von MaxRow()
  aKopf[EDIT_LM]:=16 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->ZEITERF->Pause:=if(automatisch,"J","N"),;
    _FIELD->ZEITERF->Personen:=if(automatisch,0,1), _FIELD->ZEITERF->PersNr:=NKERF->PersNr }
  aKopf[EDIT_INDEX_FELD]:={ || ZEITERF->start == 0.00 .and. ZEITERF->ende == 0.00 }

  aKopf[EDIT_GESPERRT]:="Z"
  aKopf[EDIT_DRAW_FRAME]:="Zeit-Erfassung"

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="PersNr"
  aSpalte[EDIT_NAME_GET]:="PersNrs"
  aSpalte[EDIT_TITEL]:="Pers.Nummern"
  // aSpalte[EDIT_BEFORE]:={ || NKPersNrsVor() }
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AFTER]:={ |oGet| NKPersNrsNach(oGet, automatisch) }
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Liste aller Personal-Nummern, mit Leerzeichen getrennt, eingeben.  @F12@=Auswahl"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Personen"
  aSpalte[EDIT_TITEL]:="Anz."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Start"
  aSpalte[EDIT_TITEL]:="Start"
  aSpalte[EDIT_AFTER]:={ |oGet| Zeit_Eingabe(oGet) }
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Arbeits-Beginn eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Ende"
  aSpalte[EDIT_TITEL]:="Ende"
  aSpalte[EDIT_AFTER]:={ |oGet| Zeit_Eingabe(oGet) .and. nachZeitEnde(oget)}
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Arbeits-Ende eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Pause"
  aSpalte[EDIT_TITEL]:="Pause"
  aSpalte[EDIT_AFTER]:={ |oGet| oget:Buffer$"JN"}
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Pause durchgearbeitet ? (@J@/@N@)"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="str(ZeitDif(ZEITERF->Start,ZEITERF->Ende,ZEITERF->Pause,.t.,.t.,ZEITERF->Personen),5,2)"
  aSpalte[EDIT_TITEL]:=" Zeit"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MASKE]:="99.99"
  aSpalte[EDIT_SUMME]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="GutMenge"
  aSpalte[EDIT_TITEL]:="GutMenge"
  aSpalte[EDIT_MESSAGE]:="Gutmenge eingeben."
  aSpalte[EDIT_MASKE]:="9999999"
  aSpalte[EDIT_SUMME]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Ausschuss"
  aSpalte[EDIT_TITEL]:="Ausschu�"
  aSpalte[EDIT_MESSAGE]:="Ausschu� eingeben."
  aSpalte[EDIT_MASKE]:="9999999"
  aSpalte[EDIT_SUMME]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren
  /**** ENDE Feld-Definitionen ***/

  /* editiere Datei */
  Edit(aFelder,aKopf,.f.) // edit without restoring windows size, since this is an embedded editor
  Umgebung(LOAD)

RETURN( aKopf[EDIT_CHANGED] )
/* EOP */

static function nachZeitEnde(oGet)
  if val(oget:buffer) <= ZEITERF->Start
    Error(ACHTUNG+"Ende muss nach Start liegen.")
    return .f.
  endif
return .t.

  // static function NKPersNrsVor()
  // keyboard chr(K_END) + " "
  // return .t.
//   /** eof */

static function NKPersNrsNach(oGet, automatisch)
LOCAL result:={}, current, temp:=alltrim(oGet:buffer)+"|"
LOCAL pos
LOCAL aktRec:=PERSONAL->(recno())
  if oGet:changed() .or. ZEITERF->Start == 0
    do while len(temp) > 0
      pos:=1
      do while pos <= len(temp)
        if isdigit(substr(temp,pos,1))
          pos++
        else
          current:=left(temp,pos-1)
          if len(current) < 3 // stuff w/ zeros if applicaple
            current:=right("00"+current,3)
          elseif len(current) > 3
            Error(ACHTUNG+" Ung�ltige Pers.Nr: "+current)
            return .f.
          endif
          // pr�fe ob nr vorhanden
          PERSONAL->(dbseek( current , .f. ))
          if PERSONAL->(eof())
            Error(ACHTUNG+" Pers.Nr: "+current+" nicht gefunden.")
            PERSONAL->(dbgoto( aktRec ))
            return .f.
          endif
          temp:=alltrim(substr(temp, pos+1))
          pos:=1
          // aaddUnique(result, current)
          aadd(result, current)
        endif
      enddo
    enddo
    oget:varput(array2readable(result," "))
    PERSONAL->(dbgoto( aktRec ))
    if automatisch
      if len(result)>1
        Error(ACHTUNG+"Maschine l�uft automatisch, aber mehrere Personen eingegeben.")
        replace ZEITERF->Personen with len(result)
      else
        replace ZEITERF->Personen with 0
      endif
    else
      replace ZEITERF->Personen with len(result)
    endif
  endif
return .t.
/** eof */

/* liefert allen Nummern die zu dem Eintrag in inner.dbf noch keine NachKalk. erfasst ist,
  relevant f�r mehrere Arbeitsg�nge
  *
  * Falls aktueller mArbGang angegeben wird dieser und alle X-Arbeitsg�nge excludiert.
  * Ansonsten werden alle au�er alle X-Arbeitsg�nge zur�ck geliefert.
  */
function getFehlendeNachkalkNummern(mInnerNr, mArbGang)
LOCAL aktRec:=INNER->(recno())
LOCAL merk_order:=INNER->(indexord())
LOCAL ant:="", result:=""

  INNER->(OrdSetFocus( 7 )) // inkl. aller Arbeitsg�nge
  INNER->(dbseek( mInnerNr )) // gehe auf 1. Satz des inner Auftrags
  do while ! INNER->(EOF()) .and. INNER->InnerNr == mInnerNr
    if INNER->ArbGang <> "X" .and. (mArbGang==NIL .or. INNER->ArbGang <> mArbGang)
      NKPOST->(dbseek(INNER->NKNr))
      if NKPOST->(eof())
        result += dispInnerNr(INNER->Innernr,INNER->ArbGang)
      endif
    endif
    INNER->(dbskip())
  enddo
  select Inner
  INNER->(OrdSetFocus( merk_order ))
  INNER->(dbgoto(aktRec))
return result
  /** eof */


  /** Pr�ft welche Maschinen/Gruppe in der Nachkalk nicht in der Zeitst�ckliste sind. */
procedure MaschGrKonsistenzCheck()
LOCAL stueckliste, maschtext
LOCAL HauptMaschinen, gedruckt:=hb_hash(), alleGruppen, masch

  cls
  Titel("Konsistenzcheck - Maschinengruppen")
  Message("Bitte warten...")

  Protokoll(INIT_P,"Nachkalkulation mit falscher Maschinen-Nummer")
  if open("NKPost","NKArtikel","AvPost","Maschine","MaschGr", "Artikel")

    select NKPost
    set rela to NKPOST->NKnr into NKArtikel
    index on NKPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for NKPOST->Art=="Z"
    go top
    do while ! NKPOST->(eof())

      stueckliste:=Stueckliste():new(NKARTIKEL->ArtNr)
      HauptMaschinen:=stueckliste:getZeiten(,"H",.t.)

      if empty(NKPOST->MaschNr) .and. len(HauptMaschinen) > 0 .and. rec_lock(5)
        replace NKPOST->MaschNr with HauptMaschinen[1]:getMaschNr()
        dbcommit()
        dbunlock()
      endif

      if hb_HHasKey(gedruckt, NKARTIKEL->ArtNr)
        if ascan(gedruckt[NKARTIKEL->ArtNr], NKPOST->MaschNr) > 0
          skip // bereits gedruckt
          loop
        endif
      else
        gedruckt[NKARTIKEL->ArtNr]:={}
      endif
      aadd(gedruckt[NKARTIKEL->ArtNr], NKPOST->MaschNr)

      if aScan(HauptMaschinen, {|x| NKPOST->MaschNr == x:getmaschNr()}) == 0
        alleGruppen:={}
        for each masch in HauptMaschinen
          MASCHINE->(dbseek(masch:getMaschNr()))
          alleGruppen:=aJoinUnique( alleGruppen, getMaschGroups(MASCHINE->MaschGr) )
        next

        MASCHINE->(dbseek(NKPOST->MaschNr))

        if ! aContains(alleGruppen , MASCHINE->Maschgr)
          ARTIKEL->(dbseek(NKARTIKEL->ArtNr))
          maschtext:=""
          if MASCHINE->(eof())
            maschtext:="gel�scht"
          elseif MASCHINE->Status=="X"
            maschtext:="verschrottet"
          endif
          Protokoll(PROTOKOLL, ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" Maschine: "+NKPOST->MaschNr +;
            " Gruppe: " + MASCHINE->MaschGr + " fehlt in St�ckliste. " + maschtext)
        endif
      endif
      skip
    enddo
    Protokoll(P_CREATE_PDF,,,,.t.)
    close data
  endif
return

/** liefert alle OberMaschinenGruppen rekursiv */
function getMaschGroups(MaschGr)
LOCAL result:={}
  if ! empty(MaschGr)
    aadd(result, MaschGr)
    MASCHGR->(dbseek(MaschGr))
    if ! empty(MASCHGR->ChildGr)
      result:=aJoinUnique(result, getMaschGroups(MASCHGR->ChildGr))
    endif
  endif
return result


/** filtert die einzelnen Maschinen-Gruppen in der F8 Nachkalkulations-�bersicht */
function filterMaschGroup(oBrowse, increment)
LOCAL x, maschinen, tempGroup
  static allGroups
  static groupPos

  if increment == NIL // 1st time
    allGroups:=hb_hash()
    groupPos:=0

    select NKPost
    index on NKPOST->ArtNr+dtos(NKPOST->Datum)+str(999-val(NKPOST->MaschNr),3);
      tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      &(getMaschGroupFilter()) DESCENDING

    // gehe auf ersten Satz
    NKPOST->(dbgoTop())
    do while ! NKPOST->(eof())
      if left(MASCHINE->MaschGr,1) =="3" // Spritzguss-Maschinen zusammenfassen
        tempGroup:=MASCH_GROUP_3er
        groupPos:=1
      elseif empty(MASCHINE->MaschGr)
        tempGroup:=NKPOST->MaschNr
      else
        tempGroup:=MASCHINE->MaschGr
      endif
      if ! hb_HHasKey(allGroups, tempGroup)
        allGroups[tempGroup]:={}
      endif
      aaddUnique(allGroups[tempGroup], NKPOST->MaschNr)
      skip
    enddo
    if len(allGroups) > 1
      aadd( M->SpecialHilfe , { K_PLUS, { |oBrowse| filterMaschGroup(oBrowse,+1) } ," @+@=weiter"})
      aadd( M->SpecialHilfe , { K_MINUS, { |oBrowse| filterMaschGroup(oBrowse,-;
        1) } ," @-@=zur�ck"})
      groupPos:=1 // show 1st group only

      // suche 1. Maschine in ZeitStueckListe
      maschinen:=StueckListe():new( ARTIKEL->ArtNr, ARTIKEL->Art ):getMaschinen( .t. )
      if len(maschinen) > 0
        MASCHINE->(dbseek(maschinen[1]))
        // suche Position in all group array
        for x:=1 to len(allGroups)
          if MASCHINE->MaschGr == allGroups:keys[x] .or. MASCHINE->StdNr == allGroups:keys[x]
            groupPos:=x
            exit
          endif
        next
      endif
    endif

  else
    if increment > 0
      groupPos++ // show next group
      if groupPos > len(allGroups)
        groupPos:=1 // show 1st group
      endif
    else
      groupPos-- // show next group
      if groupPos < 1
        groupPos:=len(allGroups) // show last group
      endif
    endif
  endif

  // adjust filter if applicaple
  if groupPos == 0
    NKSum() // reset only
  else
    setMaschGroupFilter(allGroups:keys[groupPos])
    oBrowse:cargo:=allGroups:keys[groupPos] // merke Gruppe in oBrowse

    oBrowse:RefreshAll()
    oBrowse:ForceStable()
    oBrowse:gotop()

    /* Summe anzeigen */
    NKSum(oBrowse,.f.,allGroups)

    keyboard(chr(K_HOME)) // gotop alleine geht scheinbar net
  endif

return .t.
/** eof */

/** liefert die Filter Condition f�r NKPost
  */  
static function getMaschGroupFilter()
LOCAL merkOrdKey:=NKPOST->(ordKey())
return 'ARTIKEL->ArtNr==NKARTIKEL->ArtNr .and. NKPOST->Art=="Z" .and. NKARTIKEL->MengeZug > 0'

  /** setzt den Index-Filter f�r NKPost auf diese Maschinen-Gruppe
  relas m�ssen gestezt sein, s. hilfdef#kalk-ueber
  */  
procedure setMaschGroupFilter(Gruppe)
LOCAL merkOrdKey:=NKPOST->(ordKey())
LOCAL filter:=getMaschGroupFilter()
LOCAL aktSel:=alias()
LOCAL aktRec:=(AKTSEL)->(recno())

  select NKPost
  if Gruppe <> NIL
    if Gruppe == MASCH_GROUP_3er
      filter += ' .and. left(MASCHINE->MaschGr,1) =="3" '
    else
      filter;
        += ' .and. (MASCHINE->Maschgr == "' + Gruppe + '" .or. NKPOST->MaschNr == "' + Gruppe + '")'
    endif
  endif

  // setze for clause f�r index
  OrdCondSet( filter ,;// [cForCondition>]
  {|| &(filter) }, ; // [<bForCondition>]
  , ; // [<lAllRecords>]
  , ; // [<bWhileCondition>]
  , ; // [<bEval>]
  , ; // [<nInterval>]
  recno(), ; // [<nStart>] ??? why recno() ??? copied from ppo file
  , ; // [<nNext>]
  , ; // [<nRecord>]
  , ; // [<lRest>]
  .t. , ; // [<lDescend>]
  , ; // [<reserved>]
  .t. , ; // [<lAdditive>]
  , ; // [<lCurrent>]
  , ; // [<lCustom>]
  , ; // [<lNoOptimize>]
  , ; // [<cWhileCondition>]
  .t. , ; // [<lTemporary>]
  , ; // [<lUseFilter>]
  .t. ) // [<lExclusive>]

  ordCreate(, TEMP_INDEX, merkOrdKey, {|| &(merkOrdKey)}, )
  //qout(ordCount())
  (AKTSEL)->(dbgoto(aktRec))
return
/** eop */

/** pr�fe Abweichung der Nachkalk zum Durchschnitt -> sende evtl.Email */
static procedure NKpruefeAbweichung(printBuffer)
LOCAL summen, protName, print:=.f., emailText

  Umgebung(WRITE_ALL)

  default printBuffer:=printBuffer():new()

  select Artikel
  set rela to ARTIKEL->ME into Einheit
  select NKPost
  set rela to NKPOST->NKNr+ARTIKEL->ArtNr into NkArtikel,;
    to NKPOST->PersNr into Personal,;
    to NKPOST->MaschNr into Maschine

  INNER->(OrdSetFocus( 6 )) // NkNr

  NKERF->(dbgoTop())
  select NKPost
  NKPOST->(dbseek(NKERF->NkNr))

  do while ! NKPOST->(eof()) .and. NKPOST->NkNr == NKERF->NkNr
    if NKPOST->Art=="Z"
      ARTIKEL->(dbseek(M->merkArtNr))
      MASCHINE->(dbseek(trim(NKPOST->MaschNr)))
      if left(MASCHINE->MaschGr,1) =="3" // Spritzguss-Maschinen zusammenfassen
        setMaschGroupFilter(MASCH_GROUP_3er)
      else
        setMaschGroupFilter(NKPOST->MaschNr)
      endif

      summen:=NachKalkSummen():new(M->merkArtNr)

      ->?
      ->?
      ->?
      ->? "F8 �bersicht:"
      ARTIKEL->(dbseek(M->merkArtNr))
      ->? "Maschine/Gruppe R�stzeit            Menge ",space(3),EINHEIT->Text+"/Std",;
        if(left(M->merkArtNr,1) $ "3",space(2)+"Mat/"+EINHEIT->Text,"")
      ->? "------------------------------------------------------"+;
        if(left(M->merkArtNr,1) $ "3","----------","")

      ->? NKPOST->MaschNr

      if abs(kalkRuestzeit(NKPOST->RuestZeit) - summen:Ruestzeit) > summen:Ruestzeit*TOLERANZ
        ->?? COLOR_RED
        print:=.t.
      endif
      ->?? str(kalkRuestzeit(NKPOST->RuestZeit),20),COLOR_DEFAULT

      if abs(kalkNutzen(NKPOST->GutMenge) - summen:MengeAB) > summen:MengeAB*TOLERANZ
        ->?? COLOR_RED
        print:=.t.
      endif
      ->?? str(kalkNutzen(NKPOST->GutMenge),16),COLOR_DEFAULT

      if abs(getNKStkStd() - summen:Stunde) > summen:Stunde*TOLERANZ
        ->?? COLOR_RED
        print:=.t.
      endif
      ->?? str(getNKStkStd(),12,2),COLOR_DEFAULT

      if left(M->merkArtNr,1) $ "3"
        if abs(kalkMatStk(NKPOST->MatZug) - summen:MatStk) > summen:MatStk*TOLERANZ
          ->?? COLOR_RED
          print:=.t.
        endif
        ->?? str(kalkMatStk(NKPOST->MatZug),9,3),COLOR_DEFAULT
      endif

      if print
        ->?
        ->? COLOR_RED,"Vorgaben:",COLOR_DEFAULT
        ->? MASCHINE->MaschGr,str(summen:Ruestzeit,21),str(summen:MengeAB,16),;
          str(summen:Stunde,12,2)
        if left(M->merkArtNr,1) $ "3"
          ->?? summen:MatStk
        endif

        // schreibe Artikel nach TODO Liste
        addTodoNachkalk(M->merkArtNr)

        Drucker("PDF")
        getUser():getCurrentPrintJob():printBuffer(printBuffer)
        getUser():getCurrentPrintJob():endDoc()
        protName:=getUser():getCurrentPrintJob():pdfFullFileName

        emailText:=printBuffer:getPlainText("|")
        emailText:=strtran(emailText, COLOR_RED, "")
        emailText:=strtran(emailText, COLOR_DEFAULT, "")
        getUser():setCurrentPrintJob(NIL)
        email(MAIN_EMAIL,"Nachkalkulation " + INNER->InnerNr + " bitte pr�fen",emailText,protName)
        exit // we bail out, one email per nachkalk
      endif
    endif
    skip
  enddo

  Umgebung(LOAD)
return
  /** eop */

/* F�ge Artikel zu NachKalk-TODOS */
static procedure addTodoNachkalk(mArtNr)
LOCAL aktSel:=alias()
  TODO->(dbseek(TODO_NACHKALK+mArtNr))
  if TODO->(eof())
    select TODO
    add_rec(0)
    replace TODO->Type with TODO_NACHKALK
    replace TODO->ArtNr with M->merkArtNr
    dbcommit()
    dbunlock()
    select (aktSel)
  endif
return
/** eof */

/* Pr�ft ob offene TODOs f�r Nachkalk. existieren. */
function hasTodosNachkalk()
LOCAL result:=.f.
  BEGIN SEQUENCE // krit. Bereich
    if open("TODO")
      dbseek(TODO_NACHKALK)
      result:=! eof()
      close data
    endif
  END Sequence
return result

procedure showTodosNachkalk()
LOCAL ende:=.f., rec

  cls
  titel("Nachkalkulation kontrollieren")
  if ! open("TODO", "Artikel","AvPost","Inner")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select Artikel
  set rela to TODO_NACHKALK+ARTIKEL->ArtNr into TODO
  index on ARTIKEL->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    ! TODO->(eof()) .and. TODO->Type == TODO_NACHKALK .and. ARTIKEL->ArtNr == TODO->ArtNr

  go top
  do while ! ende
    Hilfe("TODO/NACHKALK",getnew(),"Blubb")
    ende:=ABBRUCH
    if lastkey()==K_RETURN
      hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - Artikel: "+out(ARTIKEL->ArtNr)+" "+;
        trim(ARTIKEL->Bez1))
      kalkUeber()
      hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME)
      getUser():tempSelected[ARTIKEL->(recno())]:=.t. // see TEMP_CUSTOM_SELECTED
      keyboard(trim(TODO->ArtNr)+chr(K_DOWN))
    endif
  enddo

  if len(getUser():tempSelected) > 0
    if message("Markierte Datens�tze aus TODO Liste l�schen? (@J@/@N@)","JN"," ")=="J"
      select Artikel
      for each rec in getUser():tempSelected:keys
        ARTIKEL->(dbgoTo(rec))
        select TODO
        if rec_lock(5)
          delete
        endif
      next
      dbcommitall()
      dbunlockall()
    endif
  endif

  close data
return

  /** Liefert je nach Fertigmeldungen einen Status/Info bzgl. des innerbetr. Auftrags

  - WENN alle Artikel Fertigmeldungen der bestellten Gruppe >0 DANN "OK";

  - WENN die Fertigmeldungen von ein oder mehreren Artikel der
    bestellten Gruppe =0 DANN Abgleich ob die Fertigmeldungen mit
    einer anderen Gruppe kompatibel sind (wenn ja, Gefahr erkannt
    Gefahr gebannt, Meldung "Gruppen�nderung o.�.. Wenn nein DANN
    Meldung "neue Gruppierung erkannt";

  - WENN Fertigmeldung von Artikel aus einer anderen Gruppierung >0
    DANN Meldung "neue Gruppierung erkannt"

  s. Mail vom 19.11.24
  
  */
static function getMehrfachStatus()
LOCAL allArtNrs:={}, allWerkzeuge:={}, Werkzeug
LOCAL gruppNr, fehler:={}, gruppenFehler:=.f., tempGruppen:=hb_hash(), diff:=NIL
LOCAL gruppe, treffer:={}

  Umgebung(WRITE_ALL)

  select Nkmehrf
  go top
  gruppNr:=NKMEHRF->Gruppe
  do while ! NKMEHRF->(eof())
    if gruppNr <> NKMEHRF->Gruppe
      aadd(Fehler, out(NKMEHRF->ArtNr,.t.)+" nicht in Gruppe: "+gruppNr)
      gruppenFehler:=.t.
    elseif INNER->GeliefGes <= 0
      aadd(Fehler, out(NKMEHRF->ArtNr,.t.)+" noch nicht fertiggemeldet")
    endif

    if INNER->GeliefGes > 0
      // merkee all fertig gemeldeten Artikel
      aaddUnique(allArtNrs, NKMEHRF->ArtNr)

      // merke alle Werkzeuge
      allWerkzeuge:=aJoinUnique(allWerkzeuge, Stueckliste():new(NKMEHRF->ArtNr):getWerkzeuge())
    endif

    skip
  enddo

  if len(Fehler) == 0
    Umgebung(LOAD)
    return ""
  endif

  // 1. Fall Gruppen Mix, finde alternative Gruppe

  // hole alle Gruppen f�r alle relevanten Werkzeuge
  for each werkzeug in allWerkzeuge
    MEHRFACH->(dbseek( werkzeug ))
    do while .not. MEHRFACH->(eof()).and. MEHRFACH->ArtNr == werkzeug
      if ! hb_HHasKey(tempGruppen, MEHRFACH->Gruppe)
        tempGruppen[MEHRFACH->Gruppe]:={}
      endif
      aaddUnique(tempGruppen[MEHRFACH->Gruppe], MEHRFACH->ANr)
      MEHRFACH->(dbskip())
    enddo
  next

  for each gruppe in tempGruppen:keys
    diff:=aDiff(tempGruppen[Gruppe], allArtNrs)
    if len(diff)==0 // Gruppe passt
      aaddUnique(treffer, gruppe)
    endif
  next

  // potentielle neue Gruppe gefunden
  if len(treffer) > 0
    Umgebung(LOAD)
    return "Gruppe: "+array2readable(treffer)
  endif

  // 1. Fehlerfall Artikel nicht fertiggemeldet
  if .not. gruppenFehler
    Error(ACHTUNG+"|"+ array2readable(fehler, "|"))
    Umgebung(LOAD)
    return array2readable(fehler)
  endif

  // und nu?

  Umgebung(LOAD)
return "Gruppierung unklar, bitte pr�fen."
/** eof */

  /** liefert .t. wenn die fertig gemeldetete Menge mehr als 10% abweicht */
static function getNKAbweichung()
LOCAL diff:=abs(INNER->Menge-INNER->GeliefGes)
LOCAL toleranz:=INNER->Menge/10
return diff > toleranz
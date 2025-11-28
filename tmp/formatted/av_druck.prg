/*
* alles zum Druck der Arbeitvorbereitung
*/

#include "Miki.ch"
#include "Zeige.ch"

#define BEDARFS_LIST_DETAILS {AVPOST->ArtNr,ARTIKEL->Bez1,str(AUFERFAS->Menge*AVPOST->Menge,11,2),;
  EINHEIT->Text,AUFERFAS->Fert_KW, "Mappe:"+AUFERFAS->InnerNr,AUFERFAS->Menge,;
  "x Art.Nr.:"+AUFERFAS->ArtNr,"  Lief-KW:"+AUFERFAS->Lief_KW}

#define INNER_IGNORE_POSTEN (AUFERFAS->Menge==0 .or. ;
  left( AUFERFAS->ArtNr , len(PHOENIX_OBER_ARTIKEL) ) == PHOENIX_OBER_ARTIKEL )

#define POS_ART_NR 1
#define POS_MENGE 3
#define POS_KW 5

/* 
* druckt Material, Zeit etc. Bedarf je Av-Auftrag
*
* PARAMETER gew�nschte Bedarfs-Art:
*       W       Werkzeug
*       M       Material
*       S       Mischung
*       E       Etikett
*
* raus am 30.11.2024
*       I       Instruktionen
*       Z       Zeit
*       K       Kalkulation
*
* Ergebnis: .t. wenn erfolgreich
*/
Function;
  AV_Druck( Bedarf, printOnly, sortLager, bedarfsListen, alterAuftrag, druckeDokumente, force )

LOCAL Zeile:=0,mehrfachArtikel:={},mehrfWkz,mehrfInNr,mehrfEtiAnz,mehrfEtiAnz2,altArtNr
LOCAL E_Artikel:={},D_Artikel:={},B_Artikel:={},X_Artikel:={}
LOCAL merkOrder, allInnerNrs:={}, myInnerNr, buffers
LOCAL blindDruck:=empty( Bedarf ), mArbGang
LOCAL wkzPrintBuffer, wkzPrintBuffers:=hb_hash(), printBuffer
LOCAL matPrintBuffer, matPrintBuffers:=hb_hash()
LOCAL zeitPrintBuffer, zeitPrintBuffers:=hb_hash(), maschinen

  default printOnly:=.f.
  default alterAuftrag:=.f.
  default sortLager:=.f.
  default druckeDokumente:=.f.
  default force:=.f. // wenn gesetzt werden auch f�r nicht 3er Artikel WKZ St�ckliste etc. gedruckt

  cls
  Umgebung(WRITE_ALL)

  if blindDruck
    titel("Arbeitsvorbereitung buchen")
  else
    titel("Arbeitsvorbereitung drucken")
  endif

  if ! open("Artikel" , "AvPost" , "Text" , "Maschine" , "Instrukt","AufAus";
    ,"Einheit", "AvAus","Inner","AufPost","Rabatt","Mehrfach")
    Error(TRY_AGAIN)
    Umgebung(LOAD) // anstatt close data
    RETURN .f.
  endif

  // �ffne Auferfas == Alias f�r InnerAb etc.
  if select("Auferfas")==0
    if ! open( "InnEdit")
      Error(TRY_AGAIN)
      Umgebung(LOAD) // anstatt close data
      RETURN .f.
    endif
  endif

  /* Relationen setzen */
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit
  SELECT AufErfas
  set relation to AUFERFAS->ArtNr into Artikel // , to AUFERFAS->ArtNr into AvAus
  SELECT AVPost
  SET RELATION TO AVPOST->ArtNr INTO Artikel, TO AVPOST->ArtNr INTO Text,;
    TO AVPOST->ArtNr into Maschine, TO AVPOST->ME INTO Einheit
  select AuFPost
  AUFPOST->(OrdSetFocus(5)) // AUFPOST->ABPostNr

  Select AufErfas
  if eof()
    Error(ACHTUNG+"Auftragserfassungs-Datei ist leer !",.t.)
    Umgebung(LOAD) // anstatt close data
    RETURN .t.
  endif

  // sortiere anhand Inner-Nr, damit Mehrfachspritzungen zusammen gedruckt werden
  // und die Haupt-Artikel (Tiefe==0) zuerst kommen -> falls diese phys. gel�scht werden sollen
  index on AUFERFAS->InLfdNr tag TEMP_INDEX TEMPORARY ADDITIVE

  mehrfWkz:=space(len(AUFERFAS->Werkzeug))
  mArbGang:=AUFERFAS->ArbGang

  go top
  do while ! eof()

    /** Innerbetriebl. Auftrag  -> Inner.dbf r�ckschreiben **/
    if empty(AUFERFAS->InnerNr) .and. ! INNER_IGNORE_POSTEN
      Error("Innerbetr. Nummer fehlt bei Artikel: "+AUFERFAS->ArtNr)
      skip
      loop
    endif

    // l�sche Mappen-Nr falls zu ignorierender Posten
    if ! empty(AUFERFAS->InnerNr) .and. INNER_IGNORE_POSTEN
      replace AUFERFAS->InnerNr with ""
    endif

    aaddUnique( allInnerNrs, AUFERFAS->InnerNr)

    if blindDruck
      Message("Bitte warten...      Artikel: @"+Out(AUFERFAS->ArtNr)+"@ wird gespeichert.")
    else
      Message("Bitte warten...      Artikel: @"+Out(AUFERFAS->ArtNr)+"@ wird gedruckt.")
    endif

    if ! printOnly

      // 0-Mengen Posten werden ignoriert
      if AUFERFAS->Menge == 0
        select AufErfas
        skip
        loop
      endif

      if alterAuftrag // alter Auftrag ************************************

        SELECT Inner
        INNER->(OrdSetFocus(3)) // InlfdNr
        INNER->(dbseek(AUFERFAS->InLfdNr))

        // r�ckschreiben
        if INNER->(eof()) // kann passieren nach Mengen-Erh�hung, dass neue Unter-Baugruppen dazu kommen
          if AUFERFAS->Geloescht == "J" // seit 11.3.2014 mit l�schen -> hier ignore , da neuer Satz
            select AufErfas
            skip
            loop
          endif

          // neuen Satz hinzuf�gen
          if ! ADD_REC(0)
            Error("Anlegen innerbetr. Auftrag: Inner"+AUFERFAS->InnerNr+SCHWERER_FEHLER)
            select AufErfas
            skip
            loop
          endif
          REPLACE INNER->AufDat with getUser():date
        else

          // alten Satz �berschreiben bzw. l�schen
          rec_lock(0)
          if AUFERFAS->Geloescht == "J" // seit 11.3.2014 mit l�schen
            delete
            dbcommit()
            dbunlock()
            select AufErfas
            skip
            loop
          endif

        endif

        // falls Art.Nr. ge�ndert -> Bestbestand des "alten" Artikels neu berechnen
        // Hinweis: passiert auch falls Posten eingef�gt wurden, aber so what!
        altArtNr:=NIL
        if INNER->ArtNr <> AUFERFAS->ArtNr
          altArtNr:=INNER->ArtNr
        endif

        select Inner
        // normal abspeichern
        overwrite("Auferfas")

        if altArtNr <> NIL
          select Artikel
          seek altArtNr
          if .not. eof() .and. REC_LOCK(5)
            // BestellBestand neu berechnen
            BestBestand( BEST_INT , altArtNr )
            dbcommit()
            dbunlock()
          endif
        endif

      else // neuer Auftrag ************************************

        // pr�fe obe InnerNr / Mappe bereits vergeben -> dann erzeuge neuen innerbetr. Auftrag
        SELECT Inner
        SEEK AUFERFAS->InnerNr

        // nur bei Mehrfach-Spritzung sind mehrere Artikel je innerbetr. Auftrag zugelassen
        // oder nachtr�glicher �nderung
        if ! INNER->(eof()) .and. AUFERFAS->Werkzeug<>INNER->Werkzeug
          Error(ACHTUNG+"Auftrag:"+AUFERFAS->InnerNr+" ist bereits Artikel: "+INNER->ArtNr+;
            " zugewiesen !")
          select AufErfas
          skip
          loop
        endif

        // erzeuge innerbetr. Auftrag
        select Inner
        if ! ADD_REC(0)
          Error("Anlegen innerbetr. Auftrag: Inner"+AUFERFAS->InnerNr+SCHWERER_FEHLER)
          select AufErfas
          skip
          loop
        endif

        overwrite("AufErfas")
        REPLACE INNER->AufDat with getUser():date

      endif // neuer Auftrag Ende ***********************************

      // ** Artikel -> Bestellt
      select Artikel
      seek AUFERFAS->ArtNr
      if .not. eof() .and. (druckeDokumente .or. isInnerHauptArbeitsgang()) .and. REC_LOCK(5)
        // BestellBestand neu berechnen
        BestBestand(BEST_INT,AUFERFAS->ArtNr)
      endif

      dbcommitall()
      dbunlockall()

    endif // ! printonly

    // Flag ob gedruckt "immer" r�ckschreiben
    if INNER->Gedruckt <> INNER_DRUCK_ALT
      if INNER->InLfdNr == AUFERFAS->InLfdNr
        select Inner
        rec_lock(0)
        REPLACE INNER->Gedruckt with INNER_DRUCK_GEDRUCKT
        dbcommit()
        dbunlock()
      endif
    endif

    select AufErfas

    // 0-Mengen werden nicht gedruckt -> aus Auserfas l�schen
    if INNER_IGNORE_POSTEN
      delete
      skip
      loop
    endif

    // / ab hier nur noch Druck, ohne buchen
    if druckeDokumente .or. isInnerHauptArbeitsgang()

      /* Etiketten drucken, bei Mehrfach-Spritzung wird unten ein Sammeletikett geruckt. */
      if "E" $ Bedarf .and. empty(AUFERFAS->Werkzeug)
        if AUFERFAS->Art=="D"
          /* Dienstleistung: nur Etikett drucken */
          Eti_Dl_Druck(AUFERFAS->EtiAnz)
          SELECT AufErfas
          skip
          loop
        else
          Eti_Av_Druck( AUFERFAS->EtiAnz,,,ETI_TAFEL )
          Eti_Av_Druck( AUFERFAS->EtiAnz2,,,ETI_STECHKARTE )
        endif
      endif

      /* Material */
      if "M" $ Bedarf .and. empty(AUFERFAS->Werkzeug) // Info Mehrf.Mat.Bedarf wird summiert & am Ende gedruckt
        Titel("Material drucken")
        matPrintBuffer:=Mat_Druck( {{ AUFERFAS->ArtNr , AUFERFAS->Menge, AUFERFAS->FERT_KW }} ,;
          AUFERFAS->InnerNr,sortLager,AUFERFAS->Bemerkung,AUFERFAS->AbPostNr)
        if matPrintBuffer <> NIL
          if ! hb_HHasKey(matPrintBuffers, AUFERFAS->InnerNr)
            matPrintBuffers[AUFERFAS->InnerNr]:={}
          endif
          aadd(matPrintBuffers[AUFERFAS->InnerNr], matPrintBuffer)
        endif
      endif

      /* Werkzeug */
      // nur Spritzgussartikel seit 11.12.2024
      if "W" $ Bedarf .and. (left(AUFERFAS->ArtNr,1) $ "3" .or. force)
        maschinen:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getMaschinen(.t.) // nur Hauptmaschinen
        if force .or. ascan(maschinen, { |nr| left(nr,1)=="3"}) > 0
          wkzPrintBuffer:=Wkz_Druck(AUFERFAS->ArtNr,space(5),AUFERFAS->InnerNr,AUFERFAS->Menge,0)
          if wkzPrintBuffer <> NIL
            if ! hb_HHasKey(wkzPrintBuffers, AUFERFAS->InnerNr)
              wkzPrintBuffers[AUFERFAS->InnerNr]:={}
            endif
            aadd(wkzPrintBuffers[AUFERFAS->InnerNr], wkzPrintBuffer)
          endif
        endif
      endif

      /* Instruktionen */
      if "I" $ Bedarf
        Ins_Druck(AUFERFAS->ArtNr,space(5),AUFERFAS->InnerNr,AUFERFAS->Menge,0)
      endif

      /* Zeit */
      if "Z" $ Bedarf .or. "V" $ Bedarf
        zeitPrintBuffer:=Zeit_Druck(AUFERFAS->ArtNr,space(5),AUFERFAS->InnerNr,AUFERFAS->Menge,0)
        if zeitPrintBuffer<>NIL
          if ! hb_HHasKey(zeitPrintBuffers, AUFERFAS->InnerNr)
            zeitPrintBuffers[AUFERFAS->InnerNr]:={}
          endif
          aadd(zeitPrintBuffers[AUFERFAS->InnerNr], zeitPrintBuffer)
        endif
      endif

      if AUFERFAS->InnerNr <> INNER_TEMP_NR
        // merke alle X-Artikel
        if getArtikelArt()=="X"
          aadd(X_Artikel,{AUFERFAS->ArtNr,ARTIKEL->Bez1,AUFERFAS->Menge,EINHEIT->Text, AUFERFAS->InnerNr+space(3),AUFERFAS->Fert_KW})
        endif

        // merke aus Material-St�ckliste E,B,D Artikel
        if bedarfsListen<>NIL .and. ! empty(bedarfsListen)
          select AVPOST
          AVPOST->(dbseek(AUFERFAS->ArtNr+"M"))
          do while .not. AVPOST->(eof()) .and. AVPOST->AvNr=AUFERFAS->ArtNr .and. AVPOST->Art="M"
            ARTIKEL->(dbseek(AVPOST->ArtNr))
            switch getArtikelArt()
            case "E"
              if "E" $ bedarfsListen
                aadd(E_Artikel,BEDARFS_LIST_DETAILS)
              endif
              exit
            case "D"
              if "D" $ bedarfsListen
                aadd(D_Artikel,BEDARFS_LIST_DETAILS)
              endif
            case "B"
              if "B" $ bedarfsListen
                aadd(B_Artikel,BEDARFS_LIST_DETAILS)
              endif
              exit
            endswitch
            skip
          enddo
        endif
      endif
    else // kein HauptArbeitsgang, nur Etikett drucken
      if "E" $ Bedarf .and. empty(AUFERFAS->Werkzeug)
        if AUFERFAS->Art=="D"
          /* Dienstleistung: nur Etikett drucken */
          Eti_Dl_Druck(AUFERFAS->EtiAnz)
          SELECT AufErfas
          skip
          loop
        else
          Eti_Av_Druck( AUFERFAS->EtiAnz,,,ETI_TAFEL )
          Eti_Av_Druck( AUFERFAS->EtiAnz2,,,ETI_STECHKARTE )
        endif
      endif
    endif

    // merke Werkzeug und Artikel bei Mehrfach-Spritzung
    if ! empty(AUFERFAS->Werkzeug)
      if aScan( mehrfachArtikel , { |x| x[1] == AUFERFAS->ArtNr} ) == 0
        aaddUnique( mehrfachArtikel , { AUFERFAS->ArtNr , AUFERFAS->Menge, AUFERFAS->FERT_KW } )
        mehrfInNr:=AUFERFAS->InnerNr
        mehrfEtiAnz:=AUFERFAS->EtiAnz
        mehrfEtiAnz2:=AUFERFAS->EtiAnz2
        mehrfWkz:=AUFERFAS->Werkzeug
      endif
    endif

    /* erfolgreich verbucht , l�schen */
    SELECT AufErfas
    delete
    skip

    // Mehrfachspritzung fertig?
    if len(mehrfachArtikel)>0 .and.;
      (AUFERFAS->ArbGang <> mArbGang .or. AUFERFAS->Werkzeug<>mehrfWkz)

      // sortiere Mehrfach-Artikel chronologisch anhand Art.Nr.
      mehrfachArtikel:=aSort( mehrfachArtikel , , , { |a,b| a[1] < b[1]} )

      // drucke letztes Sammel-Etikett
      if "E" $ Bedarf
        // gehe wieder auf 1. aktuellen Datensatz
        merkOrder:=INNER->(indexord ())
        INNER->(OrdSetFocus(7)) // Innernr + Arbgang
        INNER->(dbseek(mehrfInNr + mArbGang))
        Eti_Av_Druck( mehrfEtiAnz , .f. , mehrfachArtikel,ETI_TAFEL)
        Eti_Av_Druck( mehrfEtiAnz2 , .f. , mehrfachArtikel,ETI_STECHKARTE)
        INNER->(OrdSetFocus(merkOrder))
      endif

      // drucke summiertes Material bei Mehrf.Spritzung
      if "M" $ Bedarf .and. AUFERFAS->Werkzeug<>mehrfWkz .and. len(mehrfachArtikel)>0
        matPrintBuffer:=Mat_Druck(mehrfachArtikel,mehrfInNr,sortLager,AUFERFAS->Bemerkung,AUFERFAS;
          ->AbPostNr)
        if ! hb_HHasKey(matPrintBuffers, mehrfInNr)
          matPrintBuffers[mehrfInNr]:={}
        endif
        aadd(matPrintBuffers[mehrfInNr], matPrintBuffer)
      endif
      mehrfachArtikel:={}
      mArbGang:=AUFERFAS->ArbGang
    endif

  enddo

  // Sammeldruck pro Auftrag
  for each myInnerNr in allInnerNrs
    getUser():setCurrentPrintJob(PrintJob():new())
    seekPrinter("WKZ_DRUCK")
    getUser():getCurrentPrintJob():StartDoc("AV-"+myInnerNr)
    zeile:=0
    for each buffers in {matPrintBuffers, zeitPrintBuffers, wkzPrintBuffers}
      if hb_HHasKey(Buffers, myInnerNr)
        if zeile > 0 // .and. buffers <> zeitPrintBuffers // Mat & Zeit darf zusammen
          zeile:=FormFeed( zeile ) // kein duplex mehr 13.12.24
        endif
        for each printBuffer in Buffers[myInnerNr]
          if zeile > 0 .and.;
            zeile + printBuffer:getNumLines() > DRUCKER->laenge-LISTE->Unt_Rand - 3
            zeile:=FormFeed( zeile ) // kein duplex mehr 13.12.24
          endif
          getUser():getCurrentPrintJob():printBuffer( printBuffer )
          getUser():getCurrentPrintJob():print( { "" } )
          getUser():getCurrentPrintJob():print( { "" } )
          getUser():getCurrentPrintJob():print( { "" } )
          zeile += printBuffer:getNumLines() + 3
        next
      endif
    next
    // jetzt drucken
    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(NIL)
  next

  /* l�schen der temp. Auftrags-Datei */
  select AufErfas
  if alterAuftrag
    zap
  else
    pack
  endif

  // drucke bzw. verschicke E,B,D Artikel
  if len(E_Artikel)>0
    druckeBedarfsListe("Ben�tigte Einkaufs-Artikel",E_Artikel)
  endif
  if len(B_Artikel)>0
    druckeBedarfsListe("Ben�tigte Beistellteile",B_Artikel)
  endif
  if len(D_Artikel)>0
    druckeBedarfsListe("Ben�tigte Dienstleistungen",D_Artikel)
  endif

  // schicke X-Artikel an H. Weiland
  if len(X_Artikel)>0
    xArtikelAVListe("Folgende X-Artikel werden in innerbetr. Auftr�gen verwendet.",X_Artikel)
  endif

  Umgebung(LOAD) // anstatt close data

RETURN .t.
/* EOP Av_Druck() */



/* 
* druckt den Werkzeug-bedarf je Artikel (St�ckliste)
*
* Parameter:    ArtikelNr.
*               AuftragsNr.
*               Prod.Nr
*               Anzahl
*/
static function wkz_druck(Art_Nr,Auf_Nr,Prod,Anzahl,AnzAB)
LOCAL x:=1 , tempVar
LOCAL printBuffer:=printBuffer():new()

  Titel("Werkzeug drucken")

  Umgebung( WRITE_ALL )

  SELECT AvPost
  SEEK Art_Nr+"W"
  if eof()
    Umgebung( LOAD )
    RETURN NIL
  endif

  ARTIKEL->(dbseek(Art_Nr))
  AVAUS->(dbseek(Art_Nr))

  ->?? SCHMAL_AN
  ->? '###################################################################################'
  ->? 'PROD.',space(68),getUser():date
  ->? space(26),'W E R K Z E U G - ANFORDERUNG'
  ->? Prod,space(5),Auf_Nr,space(12),'- Artikel',FETT_AN,OUT(Art_Nr),FETT_AUS,'-',space(9),;
    'WKZ-Nutzen:',;
    array2readable(Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugMenge())+'-fach'
  ->? '***********************************************************************************'
  ->? OUT(Art_Nr),ARTIKEL->Bez1,right(space(39)+trim(getArtikelLagerOrt()),39)
  if ! empty(ARTIKEL->bez2)
    ->? space(len(out(Art_nr))),ARTIKEL->Bez2,'Bestellmenge',getMengenString(Anzahl,AnzAB,9)
  endif
  ->? '***********************************************************************************'
  for each tempVar in getStkListBemWerkzeug()
    ->? tempVar
  next

  SELECT AvPost
  SEEK Art_Nr+"W"
  do while .not. eof() .and. AVPOST->AvNr=Art_Nr .and. AVPOST->Art="W"
    If AVPOST->Text="A" // Artikel
      ->? Out(AVPOST->ArtNr),ARTIKEL->Bez1,str(AVPOST->Menge,10,EINHEIT->NachKomma),;
        EINHEIT->Text,padL(trim(getArtikelLagerOrt(24)),24 )
      if .not. empty(ARTIKEL->Bez2)
        ->? space(len(Out(AVPOST->ArtNr))),ARTIKEL->Bez2
      endif
    else // Text
      ->? FETT_AN,TEXT->Text,FETT_AUS
    endif
    skip
  enddo
  ->? '==================================================================================='
  ->?
  ->?? SCHMAL_AUS

  Umgebung( LOAD )
RETURN printBuffer
/* EOP */

/*
* druckt den Materialbedarf je Artikel (St�ckliste)
*/
static FUNCTION Mat_Druck(allArtNrMenge,mInnerNr,sortiertNachLagerOrt,bemerkung,mAbPostNr)
LOCAL x:=1 , printBuffer:=printBuffer():new()
LOCAL wert:=0.00, tempvar, MatBemerkung:=NIL
LOCAL Zeile:=0,merkDat,mArtNrMenge, merkLiefNr:="", nextStkList, nextStkLists
LOCAL allMaterial:={}, mat, pos:=0, proEinheit, mat_bedarf:=hb_hash(), berechn_art, material, erst

  Umgebung( WRITE_ALL )

  // im Titel nur 1. Artikel drucken
  ARTIKEL->(dbseek(allArtNrMenge[1,1]))
  ->? "################################################################################"
  ->? 'PROD.                     Material-Bedarfsanforderung                  ',getUser():date
  ->? mInnerNr,space(24),"- Artikel",FETT_AN,OUT(ARTIKEL->ArtNr),FETT_AUS,"-",space(6),"WKZ-Nutzen:",;
    array2readable(Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugMenge())+"-fach"
  ->? "********************************************************************************"

  for each mArtNrMenge in allArtNrMenge

    // merke Bemerkung aus 1. Artikel mit Bemerkung
    if MatBemerkung == NIL
      AVAUS->(dbseek( mArtNrMenge[1] ))
      MatBemerkung:=getStkListBemMaterial()
    endif

    // jetzt drucken
    ARTIKEL->(dbseek(mArtNrMenge[1]))
    EINHEIT->(dbseek(ARTIKEL->ME))
    ->? ARTIKEL->bez1,OUT(ARTIKEL->ArtNr),getMengenString(mArtNrMenge[2],nil,9),;
      padr(if(ARTIKEL->LageBest<9999,"(Lg-Best:","(Lg:")+;
      alltrim(transstr(ARTIKEL->LageBest,7,EINHEIT->NachKomma))+")",15),getArtikelLagerOrt(13)
    if ! empty(ARTIKEL->bez2) .and. trim(ARTIKEL->Bez2)<>"."
      ->? ARTIKEL->Bez2
    endif

    // was getReservedMaterial(), vor 20229123
    berechn_art:=iif(mAbPostNr==NIL, AUFBESTAND_STATUS, AUFBESTAND_ABFRAGE )
    if material == NIL
      // beim 1. drucke komplette St�ckliste, nicht nur Artikel
      material:=Stueckliste():new( mArtNrMenge[1] ):getBuchMaterial( berechn_art, mArtNrMenge[2],;
        mArtNrMenge[3])
      allMaterial:=aClone(material)
      erst:=.t.
    else
      // Bei folgendenen (Mehrfachspr.) drucke nur Artikel
      material:=Stueckliste():new( mArtNrMenge[1] ):getBuchMaterial( berechn_art, mArtNrMenge[2],;
        mArtNrMenge[3])
      erst:=.f.
    endif

    for each mat in material
      mat:position:=pos++
      If mat:Text="A" // Artikel

        // summiere Material �ber alle Artikel
        if hb_HHasKey( mat_bedarf, mat:artnr)
          mat_bedarf[mat:artnr]:menge += mat:menge
          mat_bedarf[mat:artnr]:gesamtMenge += mat:gesamtMenge
        else
          mat_bedarf[mat:artNr]:=mat
          if ! erst // f�ge Mehrfachspritzung Folge-Artikel hinzu
            aadd(allMaterial, mat)
          endif
        endif

        // bei Mehrfachspritzung Menge Material je Artikel ausdrucken
        if len( allArtNrMenge ) > 1
          ARTIKEL->(dbseek(mat:ArtNr))
          EINHEIT->(dbseek(ARTIKEL->ME))
          ->? space(58),KLEIN_AN,;
            padLeft(" * "+alltrim(transstr(mat:GesamtMenge / mArtNrMenge[2],9,EINHEIT->NachKomma)) + " " +;
            trim(EINHEIT->Text),13),"=",;
            padLeft(alltrim(transstr(mat:GesamtMenge,9,EINHEIT->NachKomma)) + " " +;
            trim(EINHEIT->Text),13),KLEIN_AUS
        endif
      endif

    next
  next

  // ** checken ob vorhanden ???
  if allMaterial == NIL .or. len(allMaterial) == 0
    Umgebung( LOAD )
    RETURN printBuffer
  endif

  wert=0
  ->? "********************************************************************************"

  // sortiere nach LagerOrt?
  if sortiertNachLagerOrt
    allMaterial:=aSort( allMaterial , , , { |a,b| sortMaterial(a,b) })
  endif

  // drucke Bemerkung aus Material-St�ckliste, rela to AVAUS wird oben gesetzt
  for each tempVar in MatBemerkung
    ->? tempVar
  next

  for each mat in allMaterial
    If mat:Text="A" // Artikel
      mat:=get_sum_mat_bedarf(@mat_bedarf, mat:artnr)
      if .not. mat == NIL
        ARTIKEL->(dbseek(mat:ArtNr)) // lieber manuell, da zu viele relas auf Artikel zeigen!
        EINHEIT->(dbseek(ARTIKEL->ME))

        // bei alternativ. Material kann der 2. Eintrag ohne Lagerbestand sein
        if mat:LagerBestand < mat:GesamtMenge .and. mat:art == "E"
          ->?
          ->? FETT_AN,"Artikel Lagerbestand nicht ausreichend.  Bitte pr�fen!",FETT_AUS
          ->?
        endif

        if EINHEIT->ME=="1" .and. mat:menge <> int(mat:menge) // Ausnahme Nachkommastellen bei St�ck
          proEinheit:=transstr(mat:Menge,11,3)
        else
          proEinheit:=transstr(mat:Menge,11,EINHEIT->NachKomma)
        endif
        ->? Out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->KostNr,space(0),;
          padLeft("p.E. " + alltrim(proEinheit) + " " +;
          trim(EINHEIT->Text)+"",32)
        if ! empty(ARTIKEL->bez2) .and. trim(ARTIKEL->Bez2)<>"."
          ->? out(space(len(ARTIKEL->ArtNr))),ARTIKEL->Bez2
        endif
        ->? space(len(ARTIKEL->ArtNr))," --------------------------------------------------------"+;
          "------------"
        ->? transstr(mat:GesamtMenge,9,EINHEIT->Nachkomma)

        ->?? EINHEIT->Text,"L.Ort:",getArtikelLagerOrt(13),transstr(ARTIKEL->KaPr,12,2)+EURO_SIGN,;
          IF(ARTIKEL->Schluessel="H","%"," "),
        ->?? "Lagerbestand:",;
          padLeft(transstr(mat:LagerBestand,9,EINHEIT->NachKomma)+" "+alltrim(EINHEIT->Text),14)

        if mat:LagerBestand < mat:GesamtMenge // .and. mat:art == "E" ACHTUNG ist hier M f�r Material
          ->? space(52),"Fehlbestand:",;
            padLeft(transstr(mat:GesamtMenge -;
            mat:LagerBestand,9, EINHEIT->NachKomma)+" "+alltrim(EINHEIT->Text),14)
        endif

        if ! empty(mat:BestText)
          ->? padL( alltrim("Erwarteter Bestelleingang: "+mat:BestText) , 80)
        endif

        if ARTIKEL->Schluessel="H"
          wert=wert+ mat:GesamtMenge *ARTIKEL->KaPr / 100
        else
          wert=wert+ mat:GesamtMenge *ARTIKEL->KaPr
        endif
      endif

    else // Text
      TEXT->(dbseek(trim( mat:ArtNr )))
      ->? FETT_AN,TEXT->Text,FETT_AUS
    endif
    ->? "================================================================================"
    skip
  next
  ->? space(52),"WARENWERT Euro",transstr(wert,12,2)

  if ! empty(bemerkung)
    ->?
    ->? bemerkung
  endif

  // pr�fe ob als n�chstes eine Dienstleistung ansteht -> dann Hinweis
  // Info: bei Mehrfachspritzung wird hier nur der 1. Artikel gepr�ft
  // z.B. Artikel 505365.0 -> DL 505365.9 verzinken

nextStkLists:=getPreviousArtikelStkList( allArtNrMenge[1,1], "D" )
if len(nextStkLists) >0
  for each nextStkList in nextStkLists
    ARTIKEL->(dbseek( nextStkList:ArtNr ))
    ->?
    ->? FETT_AN,"Bitte externe Folge-Dienstleistung beachten:",FETT_AUS
    ->? out(ARTIKEL->ArtNr), ARTIKEL->Bez1,space(5),"Wochen:",alltrim(str(ARTIKEL->DLWochen,5,2))
    if ! empty(ARTIKEL->bez2) .and. trim(ARTIKEL->Bez2)<>"."
      ->? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
    endif
    if open("BesPost","BesAus","Lieferan")
      select BesPost
      BESPOST->(OrdSetFocus(3)) // BESPOST->ArtNr+BESPOST->LiefNr+mydescend(BESPOST->AufDat)
      BESPOST->(dbseek(ARTIKEL->ArtNr))
      if .not. BESPOST->(eof())
        BESAUS->(dbseek( BESPOST->BestNr ))
        merkDat:=BESAUS->BestDat
        do while .not. BESPOST->(eof()) .and. BESPOST->ArtNr=ARTIKEL->Artnr
          BESAUS->(dbseek( BESPOST->BestNr ))
          if merkDat <= BESAUS->BestDat
            merkLiefNr:=BESAUS->LiefNr
          endif
          skip
        enddo
        if ! empty( merkLiefNr )
          LIEFERAN->(dbseek(merkLiefNr))
          ->?
          ->? "Letzter Lieferant:"
          ->? LIEFERAN->LiefNr,LIEFERAN->Kurzname,;
            if(empty(LIEFERAN->Telefon),"","Tel:"+LIEFERAN->Telefon)
        endif
      endif
    endif
  next
endif

// FIXME: brauchen wir das?
// Zeile:=FormFeed(Zeile)

Umgebung( LOAD )

RETURN printBuffer
/* EOF */




  /* Procedure Ins_Druck *******************************************
  *
  * druckt Instruktionen zu zugeh�riger St�ckliste
  *
  * Parameter:    ArtikelNr.
  *               AuftragsNr.
  *               Prod.Nr
  *               Anzahl
  */
static PROCEDURE Ins_Druck(Art_Nr,Auf_Nr,Prod,Anzahl,AnzAB)
LOCAL Zeile:=0

  Umgebung( WRITE_ALL )

  Titel("Instruktionen drucken")

  SELECT Artikel
  SEEK Art_Nr

  SELECT Instrukt
  SEEK Art_Nr
  If .not. eof()
    Drucker("ON")
    ?? SCHMAL_AN
    ? '################################################################################'
    ? 'PROD.',space(65),getUser():date
    ? space(26),'A R B E I T S - Instruktion'
    ? Prod,space(5),Auf_Nr,space(12),'- Artikel',OUT(Art_Nr),'-',space(5),'WKZ-Nutzen:',;
      array2readable(Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugMenge())+'-fach'
    ? '********************************************************************************'
    ? OUT(Art_Nr),ARTIKEL->Bez1,space(13),'Bestellmenge',getMengenString(Anzahl,AnzAB,9)
    if ! empty(ARTIKEL->bez2)
      ? space(len(out(Art_nr))),ARTIKEL->Bez2
    endif
    ? '********************************************************************************'
    SELECT Instrukt
    do while .not. eof() .and. INSTRUKT->AvNr=Art_Nr
      aEval(HB_ATokens(INSTRUKT->InsText , MY_CR+MY_LF) , { |x| zeile += colorprint(x , .t.) })

      // ? INSTRUKT->Text
      skip
    enddo
    ? '================================================================================'
    ?
    ?? SCHMAL_AUS
    Zeile:=FormFeed(Zeile)
    Drucker("OFF")
  endif

  Umgebung( LOAD )

RETURN
/* EOP InsDruck */

/* Procedure Zeit_Druck *******************************************
*
* druckt Zeit-Bedarf zu zugeh�riger St�ckliste
*
* Parameter:    ArtikelNr.
*               AuftragsNr.
*               Prod.Nr
*               Anzahl
*/
static function Zeit_Druck(Art_Nr,Auf_Nr,Prod,Anzahl,AnzAB)
LOCAL Summe:=0.00,tempVal
LOCAL printBuffer:=printBuffer():new()

  Umgebung( WRITE_ALL )

  Titel("Zeitbedarf drucken")

  SELECT AvPost
  SEEK Art_Nr+"V"
  /* checken ob vorhanden ? */
  if eof()
    Umgebung( LOAD )
    RETURN NIL
  endif

  SELECT Artikel
  SEEK Art_Nr

  ->? '################################################################################'
  ->? 'PROD.',space(65),getUser():date
  ->? space(20),'M A S C H I N E N / Z E I T - B E D A R F'
  ->? Prod,space(5),Auf_Nr,space(12),'- Artikel',OUT(Art_Nr),'-',space(5),'WKZ-Nutzen:',;
    array2readable(Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugMenge())+'-fach'
  ->? '********************************************************************************'
  ->? OUT(Art_Nr),ARTIKEL->Bez1,space(13),'Bestellmenge',getMengenString(Anzahl,AnzAB,9)
  if ! empty(ARTIKEL->bez2)
    ->? space(len(out(Art_nr))),ARTIKEL->Bez2
  endif
  ->? '********************************************************************************'
  SELECT AvPost
  SEEK Art_Nr+"V"
  do while .not. eof() .and. AVPOST->AvNr=Art_Nr .and. AVPOST->Art="V"
    switch AVPOST->Text
    case "A" // Artikel
      if AVPOST->Menge <> 0.00
        if AVPOST->HauptKZ=="H"
          ->? str(Anzahl/AVPOST->Menge ,9,2),"Stunde(n)"
          summe+=round(Anzahl/AVPOST->Menge,2)
        else
          ->? space(19)
        endif
        ->?? AVPOST->HauptKZ,MASCHINE->StdNr,"=",MASCHINE->Bez,space(3),str(AVPOST->Menge,9,2)
      else
        // if MASCHINE->RuestZeit<>"J"
        ->? space(9),"Stunde(n)",MASCHINE->Bez
        // else
        // // ->? MASCHINE->Stunden,"Stunde(n)",MASCHINE->Bez
        // // summe+=MASCHINE->Stunden
        // ->? str(val(AVPOST->ArtNr),9),"Stunde(n)",MASCHINE->Bez
        // summe+=val(AVPOST->ArtNr)
        // endif
      endif
      if .not. empty(ARTIKEL->Bez2)
        ->? out(space(len(AVPOST->ArtNr))),ARTIKEL->Bez2
      endif

      // R�stzeit?
      if AVPOST->HauptKZ=="H" .and. AVPOST->RuestZeit>0
        ->? str(AVPOST->RuestZeit,9,2),"Stunde(n) R�stzeit"
        summe += AVPOST->RuestZeit
      endif

      exit
    otherwise // Text
      ->? TEXT->Text
    endswitch
    skip
  enddo

  // Stunden in Tage umrechnen
  tempVal:=getStdTagText(summe)

  ->? "----------------"
  ->? str(summe,9,2)," = ",tempVal
  ->? '================================================================================'

  Umgebung( LOAD )
RETURN printBuffer
/* EOP Zeit_druck */



/*
* druckt Kalkulation/Preisliste zu zugeh�riger St�ckliste
*
* Parameter:    ArtikelNr.
*               AuftragsNr.
*               Anzahl
*               Druck (bool)
*               VK (bool)
*               force (auch ohne Stueckliste fortfahren, z.B. bei Dienstleistung
*               isLock (bool) ist der Artikel bereits gelocked  // FIXME: use DbRecordInfo(DBRI_LOCKED)
*                                                               //        or DbRLockList()
*/

  #define TOLERANZ 0.05

PROCEDURE Kal_Druck(Art_Nr,Anzahl,AnzAB,Druck,VK,force,isLock)
LOCAL vorhanden:=.f., Vk_Merk,count:=0
LOCAL MatSum:=0,ZeiSum:=0,Zubetr,VKSum:=0 // AltText:="X"
LOCAL pr,kom,FertMenge:=0,faktor
LOCAL Zeile:=0,localKZ,merkKaPr,postenVK,merkArtikelArt,merkEK,Merk_VK_Aend:=space(8),gesamt
LOCAL sollZuschlag,istZuschlag,kosten,ruestKosten,preisEinheit,nk
LOCAL allMaterial, mat, allZeiten, zeit, tempWkzNutzen

  Umgebung( WRITE_ALL )

  default druck:="ON"
  default VK:=.f.
  default force:=.f.
  default isLock:=.f.

  // Titel("Kalkulation drucken")

  SELECT AvPost
  SEEK Art_Nr+"M"
  if ! found()
    seek Art_Nr+"V"
    if eof() .and. ! force

      // Kalk. auf 0 setzen
      SELECT Artikel
      SEEK Art_Nr
      if getArtikelArt()<>"W" .and. ( isLock .or. rec_lock(5) )
        replace ARTIKEL->KaPr with 0
        replace ARTIKEL->KalkDatum with getUser():date
        replace ARTIKEL->Soll_vk with 0
        dbcommit()
        if ! isLock
          unlock
        endif
      endif

      Umgebung( LOAD )
      RETURN
    endif
  endif

  /* gehe auf passenden Artikel */
  SELECT Artikel
  SEEK Art_Nr
  /* Merker l�schen, da Kalkulation gedruckt */
  if upper(druck)=="ON"
    localKZ:=AKTUELLES_KZ
  else
    localKZ:=ARTIKEL->WKZ
  endif
  merkKaPr:=ARTIKEL->KaPr
  merkEK:=ARTIKEL->EKPr
  merkArtikelArt:=getArtikelArt()
  sollZuschlag:=ARTIKEL->Zuschl_S
  if open("ArtPreis")
    ARTPREIS->(dbseek(next(ARTIKEL->ArtNr),.t.))
    ARTPREIS->(dbskip(-1))
    if ARTPREIS->ArtNr==Art_Nr
      Merk_VK_Aend:=dtoc(ARTPREIS->Datum)
    endif
  endif

  faktor:=if(ARTIKEL->Schluessel=="H",100,1)
  VK_Merk=ARTIKEL->Preis1

  preisEinheit:=if(Anzahl==1,EURO_SIGN+"/Stk","Euro ")

  Drucker(if(Druck=="ALT","BS",Druck),ARTIKEL->ArtNr+" Preis.Kalk.")
  if druck$"NOP/ALT"
    DRUCKER->(dbseek("TE"))
    // set cons off // raus am 4.12.2012
  endif

  ? '#############################################################################'
  ? ARTIKEL->bez1,localKZ,FETT_AN,space(0),ZEIGE_ARTNR+OUT(Art_nr),FETT_AUS,space(0),"Kalk.Mg:",;
    getMengenString(Anzahl,AnzAB)
  tempWkzNutzen:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugMenge()
  if len(tempWkzNutzen) > 0
    ?? 'WKZNZ.',array2readable(tempWkzNutzen)+'-fach'
  endif
  if VK
    ?? "          VK"
  endif
  ? '*******************************************************************************'
  if VK
    ?? "***********"
  endif

  // seit 22.11.16 wieder ohne alternat. Material, verf�lscht sonst alle Preise
  // allMaterial:=Stueckliste():new( Art_Nr ):
  // getReservedMaterial( 0 , Anzahl , NIL , AUFBESTAND_STATUS)
  allMaterial:=Stueckliste():new( Art_Nr, ARTIKEL->Art ):getMaterial( .t. ) // nur Artikel

  count:=0
  for each mat in allMaterial
    // If mat:Text="A" // Artikel
    /* suche passenden Artikel */
    ARTIKEL->(dbseek(mat:ArtNr)) // keine Rela gesetzt !

    // if AltText="A"
    // ? '------------------------------------------------------------------'
    // endif
    if ARTIKEL->Art=="B" .and. ! empty(ARTIKEL->KonsigKdNr)
      pr:=0 // seit 20210610 ohne Beistellteile
    else
      pr=IIF(ARTIKEL->Schluessel="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr)
    endif
    kom=IIF(ARTIKEL->Schluessel="H" , ')%' , ') ' )+EURO_SIGN+space(1)
    nk:=EINHEIT->NachKomma
    IF right(str(Anzahl*mat:Menge,10,3),3)=="000"
      nk:=0
    endif
    ? str(Anzahl*mat:Menge,7,nk),EINHEIT->Text,ARTIKEL->Bez1,ARTIKEL->Wkz,;
      ZEIGE_ARTNR+Out(mat:ArtNr)+"("+str(ARTIKEL->KaPr,8,2)+kom,str(Pr*Anzahl*mat:Menge,8,2)
    if VK
      postenVK:=Anzahl*mat:Menge*ARTIKEL->Preis1 / ;
        IIF(ARTIKEL->Schluessel="H" , 100 , 1 )

      ?? str(postenVK,11,2),"("+str(ARTIKEL->Zuschl_I,4,0)+"%)"
      VKSum+=postenVK

      ARTPREIS->(dbseek(next(ARTIKEL->ArtNr),.t.))
      ARTPREIS->(dbskip(-1))
      if ARTPREIS->ArtNr==ARTIKEL->ArtNr
        ?? dtoc(ARTPREIS->Datum)
      endif

    endif
    MatSum=MatSum + Pr*Anzahl*mat:Menge
    count++
    // endif
  next

  // Falls letzter Material Artikel drucke Summe
  if count > 0
    ? '-------------------------------------------------------------------------------'
    if VK
      ?? "-----------"
    endif
    kom:=if(anzahl==1," "," "+alltrim(str(anzahl,6))+" ")
    ? "Materialkosten "+left("pro"+kom+"St�ck"+space(19),19),space(28),;
      preisEinheit+str(MatSum,10,2)
    if VK
      ?? str(VKSum,11,2)
      ? "--------------------------------------------------------------------==========="
    endif
  endif

  // Zeiten
  allZeiten:=Stueckliste():new( Art_Nr, ARTIKEL->Art ):getZeiten()

  count:=0
  for each zeit in allZeiten
    DO CASE
    CASE zeit:Text="A" // Artikela
      if merkArtikelArt=="D" // Dienstleistung
        // 20.7.2009 wird ab sofort ignorert, gleicher Text s.u.
      else
        /* suche passenden Artikel */
        ARTIKEL->(dbseek(zeit:ArtNr)) // keine Rela gesetzt !
        MASCHINE->(dbseek(zeit:ArtNr)) // keine Rela gesetzt !

        if count==0
          ? 'Fertigungskost.=                          Nutzen  x Ma.Satz/Soll'
        endif
        count++
        // Maschinen-Kosten
        kosten:=if(zeit:HauptKZ=="H" .and. zeit:Automat=="N",MASCHINE->Kosten,MASCHINE->KostenNe)
        kom=IIF(zeit:Menge*Kosten=0 .or.;
          zeit:Nutzen2==0 ,space(9),;
          str(AnZahl/zeit:Menge*Kosten * zeit:Nutzen1/zeit:Nutzen2 ,9,2))
        ? MASCHINE->StdNr,"=",MASCHINE->Bez+if(Anzahl>1,str(Anzahl,7,2),space(7)),;
          str(zeit:Nutzen1,2)+"/"+left(alltrim(str(zeit:Nutzen2,2))+space(2),2),"x"+;
          str(kosten,8,2)+"/"+left(alltrim(str(zeit:Menge,7,2))+space(7),7),kom

        ZeiSum=ZeiSum;
          +;
          IIF(zeit:Menge*Kosten=0 .or.;
          zeit:Nutzen2==0, 0, Anzahl/zeit:Menge*Kosten * zeit:Nutzen1/zeit:Nutzen2 )
        ?? preisEinheit

        // R�stzeit
        if zeit:RuestZeit>0
          ? "R�stzeit =",str(zeit:RuestZeit,5,2),"Stunde(n)"
          if zeit:SollMenge > 0
            kosten:=if(zeit:HauptKZ=="H",MASCHINE->Kosten,MASCHINE->KostenNe)
            ruestKosten:=zeit:RuestZeit/zeit:SollMenge*kosten
            if zeit:nutzen2 > 0
              ruestKosten *= zeit:Nutzen1/zeit:Nutzen2
            endif
            ?? "/",left(alltrim(str(zeit:SollMenge,7))+" Stk"+space(12),12),;
              "x",str(zeit:Nutzen1,2)+"/"+left(alltrim(str(zeit:Nutzen2,2))+space(2),2),;
              "x",str(kosten,7,2),EURO_SIGN+"/Std",str(ruestKosten*Anzahl,10,2)
            ZeiSum=ZeiSum + round(ruestKosten*Anzahl,2)
            ?? preisEinheit
          endif
        endif

        /** merke 1. Fert.Menge */
        if zeit:Menge > 0 .and. FertMenge==0
          FertMenge:=zeit:Menge
        endif

      endif
    CASE zeit:Text="T" // Text
      TEXT->(dbseek(zeit:ArtNr))
      ? TEXT->Text
    ENDCASE
    skip
  next

  // Dienstleistung
  if merkArtikelArt=="D"
    if select("System")==0
      open("System")
    endif

    ? "Externe Dienstleistung",merkEK," Euro + "+str(SYSTEM->Aufschlag,6,2)+"%",space(4),;
      "Wert Euro"+str(merkEK*(1+SYSTEM->Aufschlag/100),10,2)
    ZeiSum=ZeiSum + merkEK*(1+SYSTEM->Aufschlag/100)
  endif

  gesamt:=round(Matsum+ZeiSum,2)
  ZuBetr=gesamt*sollZuschlag/100
  ? '-----------------------------------------------------------------------------'
  if VK
    ?? "-----------"
  endif

  ? "Artikel-Nr.:",FETT_AN,;
    ZEIGE_ARTNR+out(Art_Nr)+space(1)+"("+localKZ+space(1)+dtoc(getUser():date)+")",FETT_AUS,;
    space(5),"Fertigungskosten",preisEinheit,str(ZeiSum,9,2)
  ??

  if VK
    ?? str(VKSum,11,2)
  endif

  ? "-------------------------",space(18),"Ges.Kalku-kosten",preisEinheit,FETT_AN,str(gesamt,9,2),;
    FETT_AUS
  ? space(44),"-----------------------====================="
  ? space(21),"Soll VK-Preis: +",str(sollZuschlag,9,2)+"% ("+str(ZuBetr,9,2)+") Euro",;
    str(gesamt+Zubetr,10,2)+space(2)+"("+dtoc(getUser():date)+")"
  if gesamt<>0
    istZuschlag:=(VK_Merk/gesamt-1)*100
  else
    istZuschlag:=1.00
  endif
  ? space(21),"Ist  VK-Preis: +",FETT_AN,if(gesamt=0,space(9),str(istZuschlag,9,2))+"%",FETT_AUS,;
    "("+str(gesamt*istZuschlag/100,9,2)+") Euro",FETT_AN,str(VK_Merk,10,2),FETT_AUS,;
    " ("+Merk_VK_Aend+")"
  ? "-----------------------------------------------------------------------------------------"
  ?

  /* rueckschreiben Haupt-Artikel */
  SELECT Artikel
  SEEK Art_Nr
  if ARTIKEL->KaPr<> round((ZeiSum+MatSum)*faktor/Anzahl ,2) .or.;
    ARTIKEL->Soll_vk<> round((ZeiSum+MatSum+Zubetr)*faktor/Anzahl,2) .or.;
    ARTIKEL->Zuschl_I <> round(istZuschlag,0)

    if isLock .or. rec_lock(5)
      replace ARTIKEL->KaPr with round((ZeiSum+MatSum)*faktor/Anzahl ,2)
      replace ARTIKEL->KalkDatum with getUser():date
      replace ARTIKEL->Soll_vk with round((ZeiSum+MatSum+Zubetr)*faktor/Anzahl,2)
      if istZuschlag<=9999.5
        replace ARTIKEL->Zuschl_I with round(istZuschlag,0)

        // if DEVEL_PROG
        // Protokoll(PRINT_P,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->KaPr)+;
        // str(ARTIKEL->Preis1)+str(ARTIKEL->Zuschl_I,4))
        // endif
      endif

      if upper(druck)=="ON"
        replace ARTIKEL->Kalk_Druck with " "
        replace ARTIKEL->WKZ with AKTUELLES_KZ
      else
        if abs(MerkKaPr - ARTIKEL->KaPr) > TOLERANZ
          replace ARTIKEL->Kalk_Druck with "*"
        endif
      endif
      dbcommit()
      if ! isLock
        unlock
      endif
    endif
  endif

  // Rabattgruppe ausdrucken
  if VK .and. ! empty( ARTIKEL->RabattGr )
    getUser():getCurrentPrintJob():printBuffer( getRabattStaffel() )
  endif

  if Druck=="ALT"
    // Alles nach Alte Datei geschrieben, nicht drucken
    // NOP
  else
    Drucker("OFF")
  endif

  Umgebung( LOAD )
RETURN
/* EOP Kal_druck */

/** druckt das �bergebene Array als Liste */
static PROCEDURE druckeBedarfsListe(header,daten)
LOCAL Zeile:=0,Seite:=0,i:=1,j
LOCAL oAI,merkArtnr , RestLagerBest

  // sortiere nach ArtNr & KW
  ASort( daten ,,, {|x,y| x[POS_ART_NR]+kwIndex(x[POS_KW]) < y[POS_ART_NR]+kwIndex(y[POS_KW]) } )

  Drucker("BS")
  do while i <= len(daten)
    zeile:=0
    seite++
    ? Header,"vom",getUser():date
    ? "Art.Nr.  Bezeichnung                          Menge ME   KW     Bestand    Bedarf"
    ? "================================================================================="
    do while i <= len(daten) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand
      if merkArtnr <> daten[i,POS_ART_NR]
        ARTIKEL->( dbseek(daten[i,POS_ART_NR]) )
        merkArtnr:=daten[i,POS_ART_NR]
        oAI:=ArtikelInfo():new()
        RestLagerBest:=oAi:getLagerBestand( daten[i,POS_KW] )
      endif
      ?
      for j:=1 to POS_KW
        ?? daten[i,j]
      next
      // Drucke RestLagerbestand
      ?? str(RestLagerbest,9,2),str(RestLagerbest-val(daten[i,POS_MENGE]),9,2)
      RestLagerbest -= val(daten[i,POS_MENGE])
      ? space(10)
      for j:=POS_KW+1 to len(daten[i])
        ?? daten[i,j]
      next

      i++
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  Drucker("Off")
return
/** eop */

/** druckt das �bergebene Array als Liste */
static PROCEDURE xArtikelAVListe(header,daten)
LOCAL Zeile:=0,Seite:=0,tempVal,i:=1,liFullName

  Drucker("PDF")
  do while i <= len(daten)
    zeile:=0
    seite++
    ? Header,space(20),"Datum",getUser():date
    ? "Art.Nr.  Bezeichnung                        Menge ME  Mappe  KW"
    ? "=================================================================="
    do while i <= len(daten) .and.zeile<DRUCKER->laenge-LISTE->Unt_Rand
      ?
      for each tempVal in daten[i]
        ?? tempVal
      next
      i++
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo
  getUser():getCurrentPrintJob():endDoc()
  liFullName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  email(MAIN_EMAIL,"AV: verwendete X-Artikel vom: "+;
    dtoc(getUser():date),"Bitte �berpr�fen!",liFullName)

return
/** eop */

/** liefert einen standardisierten String mit beiden Mengen (ext & intern) */
static Function getMengenString(anzahl,anzAB,padLeft)
LOCAL result:=alltrim(transstr(anzahl,9,2,.f.,.t.)) + " "+alltrim(EINHEIT->Text)

  ignore anzAb

  if padLeft <> NIL
    result:=padl(result,padLeft)
  endif

  // if anzAB==0 // nur Miki
  // result+="(Miki)"
  // elseif anzAB==anzahl // nur externe AB
  // result+="(ext.)"
  // else // gemischt
  // result+="(ext."+alltrim(str(anzAB,7))+")"
  // endif
return result
/** eof */


/** Liefert einen printBuffer mit der aktuellen Rabatt-Staffel analg zu RabDisp (ARTIKEL - R) */
static FUNCTION getRabattStaffel()
LOCAL printBuffer:=printBuffer():new()
LOCAL Feld , i , rab , rabPreis
LOCAL artPreis:=if( ARTIKEL->Preis1 == 0 , 1 , ARTIKEL->Preis1 )

  RABATT->(dbseek( ARTIKEL->RabattGr ))
  if RABATT->(eof())
    return NIL
  endif

  ->? space(30),"Rabatt-Gruppe: "+ARTIKEL->RabattGr,"  Menge  Rab %          VK   Marge %"
  for i:=1 to 9
    feld:="RABATT->meng"+str(i,1)
    if &feld == 0
      exit
    endif

    ->? space(49),&feld

    // "Eingabe" Preis
    if &("RABATT->Preis"+str(i,1)) > 0
      rab:=100 - 100 * &("RABATT->Preis"+str(i,1)) / artPreis
      ->?? str(rab,5,2)
      feld:="RABATT->preis"+str(i,1)
      ->?? &feld
      rabPreis:=&("RABATT->Preis"+str(i,1))
    else // "Eingabe" Rabatt
      if &("RABATT->Rab"+str(i,1)) > 0
        feld:="RABATT->rab"+str(i,1)
        ->?? &feld
        rabPreis:=artPreis - artPreis * &("RABATT->Rab"+str(i,1)) / 100
        ->?? str(rabPreis,12,2)
      else
        rabPreis:=0
      endif
    endif

    // Marge
    if ARTIKEL->KAPR <> 0
      ->?? str(rabPreis / ARTIKEL->KAPR * 100 - 100 , 7 , 2 ) , "%"
    endif
  next

return printBuffer
/** eof */

static FUNCTION sortMaterial(a,b)
  if a:LagerOrt == b:LagerOrt
    return a:position < b:position
  endif
return a:LagerOrt < b:LagerOrt
/** eof */

/** druckt die Etiketten f�r den aktuell selektierten Inner-Datensatz
  *
  * Parameter Selektion: wenn nil wird Auswahl QT GUI angezeigt, ansonsten direkt die Selektion (z.B. "E") gedruckt
  */  
procedure InnerDruck(selektion, druckeDokumente)
LOCAL aktRec, merkNr , merk_order, merkWkz, merkDat

  Umgebung( WRITE_ALL )

  // kopiere akt Auferfass Datei weg
  if open("InnEdit") // -> Alias Auferfas
    aktRec:=INNER->(recno())
    zap

    // kopiere alle passenden Posten
    if empty(INNER->Werkzeug)
      if add_rec(5)
        overwrite("Inner",.t.)
      endif
    else // kopiere alle anderen Mehrfachspritzung des Werkzeugs

      // 13.11.2013 Hinweis vorher konnten auch erledigte gedruckt werden
      // da das Werkzeug aber anhand der InnerNr identifiziert wird kann es diese doppelt geben
      // also wieder raus
      merkNr:=INNER->InnerNr
      merkWkz:=INNER->Werkzeug
      merkDat:=INNER->AufDat
      merk_order:=INNER->(indexord())

      INNER->(OrdSetFocus(1)) // nach innernr, ohne ereldigte
      INNER->(dbseek( merkNr ))
      do while ! INNER->(eof()) .and. INNER->InnerNr == merkNr ;
        .and. merkWkz == INNER->Werkzeug .and. merkDat == INNER->AufDat
        select Auferfas
        if add_rec(5)
          overwrite("Inner",.t.)
        endif
        select Inner
        skip
      enddo

      INNER->(OrdSetFocus(merk_order))
      INNER->(dbgoto(aktRec))

    endif

    // innerbetr. Auftrag nur drucken, ACHTUNG schlie�t alle Dateien
    select Auferfas
    if empty(selektion)
      avDruckAuswahl(.t. , INNER_MIKI,,druckeDokumente )
    else
      // Auswahl, printonly=.t., sortLager:=.f., bedarfsListen:=.f., alterAuftrag:=.t.
      av_druck(selektion,.t.,.f.,.f.,.t.,druckeDokumente)
    endif

  endif
  Umgebung( LOAD )
return
  /* eop */

/** druckt alle ge�nderten Preiskalkulationsbl�tter (Artikel) von bis aus */
PROCEDURE Preis_Kalk
LOCAL von,bis,merknr

  if open("Artikel" ,"Text","Maschine";
    ,"Einheit" , "Avpost" , "AvAus","MEHRFACH")

    cls
    titel("Preiskalkulationsbl�tter drucken")

    select AvPost
    SET RELATION TO AVPOST->ArtNr INTO Artikel, TO AVPOST->ArtNr INTO Text,;
      TO AVPOST->ArtNr into Maschine, TO AVPOST->ME INTO Einheit

    von:=bis:=space(len(ARTIKEL->ArtNr))
    bis:=von_bis("Artikel")

    if ! ABBRUCH

      Message("Preis-Kalkulation wird gedruckt.   Bitte warten...")
      select Artikel
      do while ! eof() .and. ARTIKEL->Artnr<=bis
        merkNr:=ARTIKEL->(recno())
        if ! empty(ARTIKEL->Kalk_druck)
          Kal_druck(ARTIKEL->ArtNr,if(ARTIKEL->Schluessel=="H",100,1),0,"ON",.t.,(getArtikelArt()=;
            ="D"),.f.)
          ARTIKEL->(dbgoto(merkNr))
        endif
        skip
      enddo
    endif
  endif

  cls
  close data
RETURN

/**
  Liefert das summierte Material und setzte dieses in dem Summen Array auf NIL
  Liefert NIL falls Material nicht gefunden (bereits verwendet und gel�scht).
*/
static function get_sum_mat_bedarf(mat_bedarf, artnr)
LOCAL result
  if hb_HHasKey( mat_bedarf, artnr)
    result:=mat_bedarf[artnr]
    hdel(mat_bedarf, artnr)
    return result
  endif
return NIL
/** eof */



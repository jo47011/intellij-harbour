/* modul: Allg_Miki.prg
*
* enth�lt alle globalen, Miki-spez. Proceduren
*/

#include "Miki.ch"
#include "mynetio.ch"
#include "Zeige.ch"

#include "error.ch"
#include "Directry.ch"
#include "hbinkey.ch"
#include "hbgtinfo.ch"
#include "hbthread.ch"
#include "hbclass.ch"

#define AV_REKURSION "ACHTUNG: Max. Stucklisten-Tiefe erreicht! |"+;
  "         Schleife (?) in Stuckliste: "


/* 
* nur �ber diese Prozeduren darf der Lagerbestand ge�ndert werden.
* automat. protollieren in Waraus.dbf
*
* Artikel-Satz muss selektiert und gelockt sein !
*
* Parameters:   Bewegung  Menge
*               Text      alternativer Text zu ProgrammName (optional)
*               Datum     optionales alternatives Datum, default ist "heute"
*
* Returns:      Die lfd Nr. aus Waraus: WarausNr
*/
Function aendArtBest(Bewegung,Text,datum,InnerLfdNummer, refWarausNr)
LOCAL bLastHandler, objErr, result

  default text:=procname(1)
  default datum:=getUser():date

  /** Lagerbestand */
  Bewegung:=round(Bewegung,2)

  // ACHTUNG: Artikel-Lagerbest wird nicht mehr exkl. nur hier ge�ndert,
  // siehe auch z:b. Disp2.prg#artLageBest()
  // trouble("Waraus",{ARTIKEL->ArtNr+" LageBest Menge:"+str(Bewegung)+" "+text,;
  // "LageBest vorher:"+str(ARTIKEL->LageBest)})

  BEGIN SEQUENCE // krit. Bereich
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

    replace ARTIKEL->LageBest with ARTIKEL->LageBest + Bewegung
    dbcommit()

    // schreibe Bewegungs-Historie
    result:=addWaraus(Bewegung,text,datum,.f.,InnerLfdNummer, refWarausNr)

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
  RECOVER USING objErr
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    if ! valtype(objErr)=="O"
      Error("Kein Error-Objekt �bergeben: Art.Bestand"+SCHWERER_FEHLER)
    endif

    if ( objErr:genCode == EG_DATAWIDTH )
      // Fehler bereits protokolliert
      email(MAIN_EMAIL,;
        "Artikel Lagerbestand zu gro�: "+ARTIKEL->ArtNr,"Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+;
        "||Menge:"+toString(ARTIKEL->LageBest + Bewegung)+"||Bitte dringend �berpr�fen.")

      Error("ACHTUNG: Artikel Lagerbestand zu gro�: "+ARTIKEL->ArtNr+;
        "||Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+;
        "|Fehlerhafter Bestand: "+toString(ARTIKEL->LageBest + Bewegung)+;
        "||Bitte dringend �berpr�fen.",.t.)
    else
      TroubleEmail("Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+;
        "||Menge:"+toString(ARTIKEL->LageBest + Bewegung)+;
        "||Bitte dringend �berpr�fen.","Fehler Artikel-Bestand.  Error: " + str(objErr:genCode))
    endif

  END SEQUENCE
RETURN result
/* EOF Bewegung */

/* Procedure aendArtKbest
*
* nur �ber diese Prozedur darf der K-LagerLagerbestand ge�ndert werden.
* automat. protollieren in Waraus.dbf
*
* Artikel-Satz muss selektiert und gelockt sein !
*
* Parameters:   Bewegung  Menge
*               Text      alternativer Text zu ProgrammName (optional)
*               Datum     optionales alternatives Datum, default ist "heute"
*/
PROCEDURE aendArtKbest(Bewegung,Text,datum,InnerLfdNummer)
  default text:=procname(1)
  default datum:=getUser():date

  /** Konsig.Bestand */
  Bewegung:=round(Bewegung,2)

  // trouble("Waraus",{ARTIKEL->ArtNr+" KonsigBest Menge:"+str(Bewegung)+" "+text,;
  // "LageBest vorher:"+str(ARTIKEL->LageBest)})

  replace ARTIKEL->KonsigBest with ARTIKEL->KonsigBest + Bewegung
  dbcommit()

  // schreibe Bewegungs-Historie
  addWaraus(Bewegung,text,datum,.t.,InnerLfdNummer)

RETURN
/* EOF Bewegung */

/* 
* nur �ber diese Prozedur darf der Best-Bestand eines Artikel ge�ndert werden.
*
* Artikel-Satz muss selektiert und gelockt sein !
*
* Parameters:   Bewegung  Menge
*               Bewegung MengeAB = Menge die durcht ext. ABs bestimmt wurde
*               Text      alternativer Text zu ProgrammName (optional)
*               Datum     optionales alternatives Datum, default ist "heute"
*/
PROCEDURE aendBestInt(Bewegung,BewegAB,Text,datum)
  default text:=procname(1)
  default datum:=getUser():date

  /* Bestell-Bestand ? */
  Bewegung:=round(Bewegung,2)

  trouble("BestProt",{ARTIKEL->ArtNr+" Bestellt Menge:"+str(Bewegung)+" "+text,;
    "LageBest vorher:"+str(ARTIKEL->LageBest)})

  // Bewegung gesamt
  replace ARTIKEL->BestInt with ARTIKEL->BestInt + Bewegung
  if ARTIKEL->BestInt < 0
    replace ARTIKEL->BestInt with 0.00
  endif

  // Bewegung AB
  replace ARTIKEL->BestAB with ARTIKEL->BestAB + BewegAB
  if ARTIKEL->BestAB < 0
    replace ARTIKEL->BestAB with 0.00
  endif
  dbcommit()

  // schreibe Bewegungs-Historie
  // addBestProt(Bewegung,text,datum)

RETURN
/* EOF Bewegung */


/** 
 * schreibt neuen Datensatz nach Waraus,
 * der passende Artikel Datensatz selektiert
 *
 */
function addWaraus(mengeM,text,datum,klager,InnerLfdNummer, refWarausNr)
LOCAL aktSel:=alias(), result
  default datum:=getUser():date
  default klager:=.f.

  /* Bewegung protokollieren */
  if select("Waraus")==0
    do while ! open("Waraus")
      Message("Bewegungsdatei wird ge�ffnet.   Bitte warten...")
    enddo
  endif

  SELECT WARAUS
  ADD_REC(0)

  result:=val(hole("WarausNr",WRITE))
  REPLACE WARAUS->WarausNr WITH result
  REPLACE WARAUS->Artnr WITH ARTIKEL->ARTNR
  REPLACE WARAUS->Bez1 WITH ARTIKEL->Bez1
  REPLACE WARAUS->Bez2 WITH ARTIKEL->Bez2
  REPLACE WARAUS->Datum WITH datum
  REPLACE WARAUS->Ek WITH ARTIKEL->EKPr
  REPLACE WARAUS->Menge WITH mengeM
  REPLACE WARAUS->Best WITH ARTIKEL->LageBest
  REPLACE WARAUS->Ort WITH getArtikelLagerOrt( len(WARAUS->Ort) )
  REPLACE WARAUS->Me WITH ARTIKEL->ME
  if klager
    REPLACE WARAUS->Lg WITH ARTIKEL->LageBest // Ursprungswert !!
  else
    REPLACE WARAUS->Lg WITH ARTIKEL->LageBest - mengeM // Ursprungswert !!
  endif
  REPLACE WARAUS->KostNr WITH ARTIKEL->KOSTNR
  REPLACE WARAUS->Schl WITH ARTIKEL->Schluessel
  REPLACE WARAUS->Programm WITH alltrim(text)
  REPLACE WARAUS->KonsigBest WITH ARTIKEL->KonsigBest
  if InnerLfdNummer <> NIL
    REPLACE WARAUS->InLfdNr WITH InnerLfdNummer
  endif
  if refWarausNr <> NIL
    REPLACE WARAUS->RefWarNr WITH refWarausNr
  endif
  dbcommit()
  unlock

  // trouble("Waraus", {ARTIKEL->ArtNr+" "+left(text+space(40),40)+" **"+str(WARAUS->(recno()))+"** "})

  select (aktSel)

return result
  /** eop */


/*
  * Schreibt Preishistorien Eintrag
  *
  * Nimmt den aktuellen Artikel.
  */
Function addPreisHistorie(bewGrund, kalkText)
LOCAL aktSel:=alias()
LOCAL wasOpen:=(select("Artpreis") > 0 )

  if ! wasOpen .and. ! open("ArtPreis")
    Error(ACHTUNG+" Preis-Historie konnte nicht geschrieben werden.",.t.,"root")
    select(aktSel)
    return .f.
  endif

  if bewGrund == NIL .or. len(bewGrund) < 3
    Error(ACHTUNG+" Preis-Historie: Grund muss anggeben werden.")
    select(aktSel)
    return .f.
  endif

  // schreibe Preis-Historie
  select Artpreis
  add_rec(0)
  replace ARTPREIS->ArtNr with ARTIKEL->ArtNr
  replace ARTPREIS->Art with getArtikelArt()
  replace ARTPREIS->EKPreis with ARTIKEL->EKPr
  replace ARTPREIS->KalkPreis with ARTIKEL->KaPr
  replace ARTPREIS->VKPreis with ARTIKEL->Preis1
  replace ARTPREIS->BeiEK with ARTIKEL->BeiEK
  replace ARTPREIS->BeiKaPr with ARTIKEL->BeiKaPr
  replace ARTPREIS->Datum with getUser():date
  replace ARTPREIS->Kurzel with getUser():id
  replace ARTPREIS->Grund with bewGrund
  if kalkText <> NIL
    replace ARTPREIS->KalkDetail with kalkText
  endif

  dbcommit()
  dbunlock()

  if ! wasOpen
    close ArtPreis
  endif
  select(aktSel)

  trouble("PreisProt", ARTIKEL->ArtNr+" nachher  Ka.Pr.:"+str(ARTIKEL->KaPr)+" "+;
    " VK.Pr.:"+str(ARTIKEL->Preis1)+" "+ " EK.Pr.:"+str(ARTIKEL->EKPr) )

return .t.
/** eop */


/* PROCEDURE Preispfelge
*
* aktualisert Ek-Preis anhand von Preisgrupp
* ersetzt Ka-Pr mit Ek-Pr.*1.2
*/
PROCEDURE PreisPflege
LOCAL GetList:={} , Taste:=0,V_Pr:=".",V_Preis
  cls
  titel("Artikel-Preispflege")

  if ! open("Artikel","AvPost","System")
    cls
    close data
    RETURN
  endif

  select Artikel

  do while Taste<>12 .and. .not. empty(V_Pr)
    Message("Preisgruppe und neuer Kilopreis eingeben.")
    V_Pr=space(4)
    V_Preis=0.00
    @ 2,0 clear
    @ 9,18 to 13,48
    @ 10,20 say "Preisgruppe:" get V_Pr PICTURE "9999";
      when Message("Bitte gew�nschte Preisgruppe eingeben.")
    @ 12,20 say "Preis......:" get V_Preis PICTURE "999999999.99" ;
      when Message("Bitte neuen EK-Preis in @Euro@ je Gewicht eingeben")
    read
    if ABBRUCH .or. empty(V_Pr)
      loop
    endif
    if Message("Bitte best�tigen (@b@)","@")=="B"

      Message("Preise werden aktualisiert.  Bitte warten...")
      locate for ARTIKEL->PrGr=V_Pr
      do while .not. eof()
        if ARTIKEL->Gewicht <> 0
          @ 14,20 say ARTIKEL->ArtNr
          @ 14,30 say ARTIKEL->Bez1
          if ! REC_LOCK(5)
            Error(ACHTUNG+ARTIKEL->ArtNr+" konnte nicht ge�ndert werden !")
          else
            replace ARTIKEL->EkPr WITH round(ARTIKEL->Gewicht*V_Preis,2)
            replace ARTIKEL->Preis2 WITH V_Preis
            if ARTIKEL->KaPr < ARTIKEL->EkPr*((100+SYSTEM->Aufschlag)/100)
              replace ARTIKEL->KaPr WITH ARTIKEL->EkPr*((100+SYSTEM->Aufschlag)/100)
            endif
          endif
          dbcommit()
          UNLOCK
        endif
        cont
      enddo
    endif
  enddo
  cls
  close data
RETURN
/* EOP */

/*
* aktualisert den Ek-Preis eines Lieferanten in allen Bestellkarten
* falls das der letzte Preis war, wird auch der EK im Artikel ge�ndert.  
*/
PROCEDURE PreisLieferant
LOCAL GetList:={} , MLiefNr:=space(5),proz:=0.0, bewGrund:=space(28)
LOCAL letzteME, letzerPreis

  cls
  titel("Artikel-Preispflege je Lieferant")

  if ! open("Artikel","BestKart","BesPost","ArtPreis")
    cls
    close data
    RETURN
  endif

  Message("Backup wird erstellt.   Bitte warten...")
  backup("Artikel","pre-PreisLieferant")
  backup("ArtPreis","pre-PreisLieferant")
  backup("BestKart","pre-PreisLieferant")

  select BesPost
  index on BESPOST->ArtNr+mydescend(BESPOST->AufDat) tag TEMP_INDEX TEMPORARY ADDITIVE // ArtNr + Datum neu zuerst
  select BestKart
  index on BESTKART->ArtNr+mydescend(BESTKART->Datum) tag TEMP_INDEX TEMPORARY ADDITIVE // ArtNr + Datum neu zuerst

  if getUser():id==KURZEL_DEVEL
    MLiefNr:="80069"
    bewGrund:="Preiserh�hung +3,8% Wieland"
    proz:=3.8
  endif

  @ 2,0 clear
  @ 9,18 to 15,66
  @ 10,20 say "Lieferant:" get MLiefNr PICTURE "@9" valid { |oGet| preisLiefDisp(oGet) };
    when Message("Lieferant eingeben   @F12@=Auswahl.")
  @ 12,20 say "Aufschlag:" get proz PICTURE "99.99" ;
    when Message("Bitte Aufschalg in Prozent eingeben.")
  qqout(" %")
  @ 14,20 say "Grund....:" get BewGrund valid ! emptyOr2Simple(BewGrund,3) ;
    when Message("Grund f�r Bestands�nderung eingeben (mind 3 Zeichen)  @F12@=Hilfe   @ESC@=Ende")
  read
  if ABBRUCH .or. proz==0
    close data
    return
  endif

  if Message("Bitte best�tigen (@b@)","@")=="B"

    Message("Preise werden gepr�ft.  Bitte warten...")
    Protokoll(INIT_P,"Preis-Anpassung: "+LIEFERAN->Kurzname+" �nderung: "+str(proz,5,2)+" %",;
      "Art.Nr.   Bez                            Preis alt       neu")

    select Artikel
    go top
    do while .not. ARTIKEL->(eof())
      @ 16,20 say ARTIKEL->ArtNr
      @ 16,30 say space(len(ARTIKEL->Bez1))

      // suche letzte Bestellkarten-Eintrag vom Artikel ohne Lieferant
      BESTKART->( dbseek( ARTIKEL->ArtNr ) )
      // suche letzte Bestellung
      BESPOST->(dbseek( ARTIKEL->ArtNr ))

      letzerPreis:=0

      // falls die j�ngste Bewegung der beiden zum Lieferanten passt
      if (BESPOST->LiefNr == MLiefNr .and. BESPOST->AufDat > BESTKART->Datum) .or. ;
        (BESPOST->LiefNr == MLiefNr .and. BESTKART->LiefNr == MLiefNr .and. ;
        BESPOST->AUFDAT == BESTKART->Datum)
        letzerPreis:=BESPOST->Preis
        letzteME:=BESPOST->Me
      elseif (BESTKART->LiefNr == MLiefNr .and. BESPOST->AufDat < BESTKART->Datum)
        letzerPreis:=BESTKART->Preis1
        letzteME:=BESTKART->LiefMe
      endif

      if letzerPreis > 0
        @ 16,30 say ARTIKEL->Bez1

        select Bestkart
        add_rec(0)
        replace BESTKART->ArtNr with ARTIKEL->ArtNr
        replace BESTKART->LiefNr with MLiefNr
        replace BESTKART->Menge1 with 1
        replace BESTKART->Preis1 with letzerPreis * ( 100 + proz) / 100
        replace BESTKART->LiefME with letzteMe
        replace BESTKART->Datum with getUser():date

        Protokoll(PROTOKOLL,ARTIKEL->ArtNr+space(1)+ARTIKEL->Bez1+space(1)+str(letzerPreis,9,2)+;
          space(1)+str(BESTKART->Preis1,9,2), if (empty(ARTIKEL->Bez2),NIL,space(9)+ARTIKEL->Bez2))

        // Artikel Preis �ndern
        select Artikel
        if ! REC_LOCK(5)
          Error(ACHTUNG+ARTIKEL->ArtNr+" konnte nicht ge�ndert werden !")
        else
          replace ARTIKEL->EkPr WITH BESTKART->Preis1
          // if ARTIKEL->KaPr < ARTIKEL->EkPr*((100+SYSTEM->Aufschlag)/100)
          // replace ARTIKEL->KaPr WITH ARTIKEL->EkPr*1.2
          // endif
        endif
        dbcommit()
        UNLOCK

        // schreibe Preis-Historie
        addPreisHistorie(BewGrund)

      endif
      select Artikel
      skip
    enddo
    Protokoll(P_CREATE_PDF,,,,.t.)
  endif

  cls
  close data
RETURN
/* EOP */

static function preisLiefDisp(oGet)
  if ! check(oGet,"Lieferan",.f.)
    return .f.
  endif
  @ 10,37 Say LIEFERAN->KurzName
return .t.

/*
* �berpr�ft alle Ka.Pr anhand von St�ckliste
* aktualisiert: ARTIKEL->KaPr
*
* druckt Preiskalk. falls Kalk.Pr sich aendert !
*
*/
  #define TOLERANZ 0


PROCEDURE Preis_check(Abfrage)
LOCAL Tiefe:=0
LOCAL Merk_ArtNr,Merk_Anzahl,Merk_KaPr
LOCAL ant:="J"
LOCAL Stop:=.f. , Zeile:=0
LOCAL fehler:={}, f , protname

  default Abfrage:=.t.

  cls
  titel("Preis-Kalkulation")

  if Abfrage
    ant:=Message("Der Vorgang dauert einige Zeit.  Sind Sie sicher ? (@J@/@N@)","JN")
  endif
  IF ABBRUCH .or. ant=="N"
    cls
    close data
    return
  ENDIF

  @ 11,19 to 15,60
  @ 12,21 say "Bitte warten......     "
  @ 14,21 say "E und W Artikel werden berechnet."

  // zuerst Einkauf und W-Artikel,
  // wird von 2. Preisberechnung �berschrieben falls St�ckliste vorhanden
  Preis_EWArtikel()


  @ 11,19 to 15,60
  @ 12,21 say "Bitte warten......     "
  @ 14,21 say "St�ckliste-Tiefe wird ermittelt."

  if !;
    open( "Artikel" , "AvPost" , "AvAus","Maschine","Text","Einheit","BesPost","BesAus","Mehrfach")
    Error(TRY_AGAIN)
    close data
    cls
    RETURN
  endif


  select AvAus
  go top

  /* St�cklisten-Tiefe ermitteln */
  do while ! AVAUS->(eof())
    rec_lock(0)
    @ 16,21 say AVAUS->AvNr
    select AvPost
    replace AVAUS->Tiefe with Tiefe(AVAUS->AvNr , 0)
    if AVAUS->Tiefe > MAX_LOOP
      if TiefeError(AVAUS->AvNr , 0)
        exit // Bei Schleife Ausstieg
      endif
    endif
    dbcommit()
    unlock
    select AvAus

    skip
  enddo

  @ 14,21 say "Datei wird sortiert.            "
  select AvAus
  index on str(AVAUS->Tiefe,2)+AVAUS->AvNr tag TEMP_INDEX TEMPORARY ADDITIVE

  /* Relationen setzen , unschoen da zu viele, spaeter optimieren ! jojo*/
  SELECT AVPost
  SET RELATION TO AVPOST->ArtNr INTO Artikel, TO AVPOST->ArtNr INTO Text,;
    TO AVPOST->ArtNr into Maschine, TO AVPOST->ME INTO Einheit

  /* neu berechnen der jeweiligen St�ckliste */
  @ 14,21 say "Preise werden neu kalkuliert."
  select AvAus
  go top
  set cons off
  Tiefe:=-1
  do while ! eof() .and. ! stop
    @ 16,21 say "Tiefe:"+str(AVAUS->Tiefe,2)+" : "+AVAUS->AvNr

    Merk_artNr:=AVAUS->AvNr
    ARTIKEL->(dbseek(merk_ArtNr))

    if getArtikelArt() $ STKLIST_ARTIKEL .and. ! getArtikelArt()=="W"
      Merk_Anzahl:=if(ARTIKEL->Schluessel=="H",100,1)
      Merk_KaPr:=ARTIKEL->KaPr

      // kalkuliere ohne Druck
      Kal_druck(Merk_ArtNr,merk_Anzahl,0,"NOP")

      if DEVEL_PROG .and. Merk_KaPr <> ARTIKEL->KaPr
        aadd( Fehler , ARTIKEL->ArtNr + " " + ARTIKEL->Bez1 + " vorher: " + str(Merk_KaPr,12,2)+;
          " nachher:" + str(ARTIKEL->KaPr,12,2))
      endif

      stop:=stop_key() // ESC gedr�ckt ?
    endif

    skip
  enddo

  if len(fehler) > 0
    Protokoll(INIT_P,"Kalk-Preis Konsistenzcheck","Art.Nr.    Bez                            alt  "+;
      "           neu")
    for each f in fehler
      Protokoll(PROTOKOLL,f)
    next
    Protokoll(P_CREATE_PDF,,,,.t.)
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Fehler: Kalku-Preis Konsistenzcheck: "+;
      str(len(fehler),5),"Bitte pr�fen",protName)
  endif
  set cons on
  cls
  close data


RETURN


/* FUNCTION Tiefe
*
* ermittelt rukursiv die max. Tiefe einer St�ckliste
*/
FUNCTION Tiefe(Artikel,Tiefe,auto)
LOCAL Max_Tiefe:=Tiefe
LOCAL Merk_Satz

  // im Fehlerfall raus
  if Tiefe > MAX_LOOP
    return tiefe
  endif

  seek Artikel+"M"
  do while ! eof() .and. Artikel==AVPOST->AvNr .and. AvPost->Art="M"
    if Max_Tiefe <= MAX_LOOP
      merk_Satz:=recno()
      // if DEVEL_PROG
      // Protokoll(PROTOKOLL ,space(tiefe*2)+AVPOST->AvNr+"->"+AVPOST->ArtNr)
      // endif
      Max_Tiefe:=Max( Tiefe(AVPOST->ArtNr,tiefe+1, auto) , Max_Tiefe )
      go (merk_satz)
    endif

    skip
  enddo

RETURN(Max_Tiefe)
/* EOF Tiefe */

/*
*
* ermittelt im FehlerFall d.h. bei �berschreiten der max. Tiefe den B�sewicht
*/
FUNCTION TiefeError( Artikel )
LOCAL mArtnr , result:=.f.
  if (mArtNr:=TiefeErrorRek(Artikel , 0 ) ) <> nil
    Error(AV_REKURSION + "||" + mArtNr ,.t.,"root")
    result:=.t.
  endif
return result
/*
*
* ermittelt im FehlerFall d.h. bei �berschreiten der max. Tiefe den B�sewicht
*/
FUNCTION TiefeErrorRek(Artikel , Tiefe )
LOCAL Max_Tiefe:=Tiefe
LOCAL Merk_Satz , result

  static mainArtNr
  if Tiefe == 0
    mainArtNr:=AVPOST->AvNr
  endif

  seek Artikel+"M"
  do while ! eof() .and. Artikel==AVPOST->AvNr .and. AvPost->Art="M"
    if mainArtNr == AVPOST->ArtNr
      // Liefere die Ebene dr�ber zur�ck
      return AVPOST->AvNr + " -> " + AVPOST->ArtNr
    endif

    merk_Satz:=recno()
    result:=TiefeErrorRek( AVPOST->ArtNr , tiefe+1 )
    go (merk_satz)

    if result != nil
      result:=AVPOST->AvNr + " -> " + result
      return result
    endif

    skip
  enddo

RETURN nil
/* EOF Tiefe */

/* FUNCTION Mat_Kz()
*
* l�scht Punkte und Striche
* f�llt mit evtl. fehlenden Nullen auf
*/
FUNCTION Mat_Kz(tempStr)
LOCAL MatKz:=tempStr
LOCAL inStr,praestr

  if empty(left(MatKz,2))
    RETURN space(len(TempStr))
  else

    /* f�hrende Nullen */
    praestr=left(MatKz,2)
    if len(alltrim((praestr))) < 2
      praestr = "0"+alltrim(praeStr)
    endif

    /* mittlere Nullen */
    inStr=substr(MatKz,4,3)
    if ! empty(inStr)
      do while len(alltrim(inStr)) < 3
        inStr = "0"+alltrim(inStr)
      enddo
    endif
  endif

  /* str wieder herstellen */
RETURN(praestr + inStr + substr(MatKz,8))


/**
*
* setzt den Inventurbestand aller Artikel auf den akt LagerBestand, Jahresende !
*/
PROCEDURE kopiere_InvBestand()
LOCAL mDatum:=ctod("31.12."+str(year(getUser():date)-1,4))
LOCAL GetList:={}
  cls
  titel("Inventurbestand kopieren")

  @ 9,8 to 14,72
  @ 10,10 say "Setzt den Inventurbestand aller EFD-Artikel"
  @ 11,10 say "auf den LagerBestand am Stichtag."

  @ 13,10 say "Datum / Stichtag..:" get mDatum when Message("Z�hl-Datum eingeben.")
  read

  if ! ABBRUCH

    backup("Artikel","pre-Inventurbestand")

    if ! open("Artikel","Waraus")
      Error(TRY_AGAIN )
      cls
      close data
      RETURN
    endif
    select Artikel
    go top
    Message("Lagerbestand wird kopiert.  Bitte warten....")
    do while ! ARTIKEL->(eof())

      if getArtikelArt()$"EFMD" // WICHTIG: keine B- und W-Artikel, die geh�ren nicht MIKI-Plastik!

        Message("Artikel: @" + ARTIKEL->ArtNr + "@")

        // suche Bestand zum Datum
        select Waraus
        index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
          WARAUS->ArtNr == ARTIKEL->ArtNr .and. WARAUS->Datum <= mDatum
        // find last entry
        go bottom

        select Artikel
        rec_lock(0)
        replace ARTIKEL->InvDate with mDatum
        replace ARTIKEL->InvBestand with WARAUS->Best
        dbcommit()
        dbunlock()
      endif

      skip
    enddo
    dbcommitall()
    cls
    close data
    RETURN
  endif
  cls
  close data
RETURN
/** EOP */





/* PROCEDURE EinkaufArt_check **************************************
*
* �berpr�ft auf Einkaufartikel (EK > 0), die Stueckliste besitzen
*/
PROCEDURE EinkaufArt_check
LOCAL merkArtnr

  cls
  titel("Einkaufsartikel �berpr�fen")

  @ 9,19 to 15,60
  @ 10,21 say 'Dieser Vorgang dauert einige Zeit !'
  @ 12,21 say 'Bitte Best�tigen (b) '

  IF ! upper(chr(warte(0))) == "B"
    cls
    close data
    return
  ENDIF

  @ 12,21 say "Bitte warten......     "

  if ! open( "Artikel" , "AvPost" , "AvAus")
    Error(TRY_AGAIN)
    close data
    cls
    RETURN
  endif

  Protokoll(INIT_P,"Einkaufsartikel mit Stuecklisten"+space(3)+"vom "+;
    dtoc(getUser():date),"ArtNr.    Bezeichnung  ")

  select Artikel
  loca for ARTIKEL->EkPr > 0
  do while ! eof()
    AVAUS->(dbseek(ARTIKEL->ArtNr))
    if ! AVAUS->(eof())
      Protokoll(PROTOKOLL , ARTIKEL->ArtNr+space(1)+ARTIKEL->Bez1 )
    endif
    cont
  enddo

  /* LIste ausdrucken */
  Protokoll(PRINT_P)

  Protokoll(INIT_P,"Stuecklistenposten ohne Stuecklisten"+space(3)+"vom "+;
    dtoc(getUser():date),"StueckListe    ArtNr.")

  select AvPost
  go top
  merkArtnr:=""
  do while ! eof()
    if merkArtnr<> AVPOST->AvNr
      AVAUS->(dbseek(AVPOST->AvNr))
      if AVAUS->(eof())
        Protokoll(PROTOKOLL , AVPOST->AvNr+space(2)+AVPOST->ArtNr)
        rec_lock(0)
        delete
        dbcommit()
        dbunlock()
      endif
      merkArtnr:=AVPOST->AvNr
    endif
    skip
  enddo

  /* LIste ausdrucken */
  Protokoll(PRINT_P)



  cls
  close data
RETURN



/*
* gibt die Art.Nr formatiert mit Pkt. und Minus zur�ck, aber OHNE Leerzeichen

  XXXXXX.XXX-X

  Immer 12 Zeichen!
  
*/
FUNCTION Out(Artikel, trimit)
LOCAL result

  default trimit:=.f.

  if len(trim(Artikel)) > 6
    if len(trim(Artikel)) > 9
      result:=left(Artikel,6)+"."+substr(Artikel,7,3)+"."+substr(Artikel,10)
    else
      result:=left(Artikel,6)+"."+substr(Artikel,7)
    endif
  else
    result:=left(Artikel,6)+" "+substr(Artikel,7)
  endif

  result:=left(result+space(12),12)
  if trimit
    result:=trim(result)
  endif
RETURN result

/*
* gibt die Art.Nr formatiert mit Pkt. und Minus UND Leerzeichen zur�ck

  XXX XXX.XXX-X
  
  Immer 13 Zeichen!
*/

FUNCTION Out2(Artikel)
LOCAL result:=out(Artikel)
  if len(trim(result)) > 3
    RETURN( left(result,3)+" "+substr(result,4) )
  endif
RETURN result

/* Function KdOut
*
* gibt die Kund.Nr formatiert mit "-" zur�ck
*/
FUNCTION KdOut(Kunde)
  // if len(trim(Kunde)) > 5
  // RETURN( left(Kunde,5)+"-"+substr(Kunde,6,2) )
  // endif
  // RETURN( left(Kunde,5)+" "+substr(Kunde,5,2) )
RETURN( Kunde )


/* 
* gibt die Art.Nr bis zum "Pkt." nach rechts geshiftet zurueck
*/
FUNCTION ShiftArtikel(Artikel)
LOCAL Result:=Artikel
  if len(alltrim(Artikel)) < SHIFT_ARTIKEL
    result:=replicate(" ",SHIFT_ARTIKEL-len(alltrim(Artikel)))+alltrim(Artikel)
    result+= replicate(" ",ARTNR_GES_LAENGE-len(result))
  endif
RETURN( result )
/* EOF */



/** eof */

/**
  * liefert die KW plus/minus Anzahl der Tage (nur 5 Wochentage) zur�ck im Format WW/YY
  * ber�cksichtigt die Betriebsferien
  *
  * Parameter: kw       = Die Kalenderwoche zu Beginn
  *            offset   = Anzahl der Stunden in der KW wo wir starten, also z.B. 7.7 f�r Dienstag morgen
  *            stunden  = Anzahl der Stunden die dazu kommen oder abgezogen werden sollen
  *            holidays = KWs die ignoriert werden / Betriebsferien (optional)
  *                       siehe SYSTEM->Holidays, z.B.:  31/13,32/13
  *
  * KW 03/12 minus Eine Stunde ergibt bei Offset 0 bereits KW 02/12!
  *
  * Result: KW
  */
Function calcKW( kw , offset , stunden , holidays )
LOCAL resultJahr,numWeeks
LOCAL resultKW, holidayKW , holidayKWs
LOCAL resultOffset:=stunden + offset
LOCAL resultWoche:=val(left(kw,2))

  if holidays <> NIL
    holidays:=trim(holidays)
  endif

  // Info: we bail out on invalid KW or 0 hours to add
  if kwempty(KW) .or. "X" $ upper(kw) .or. "*" $ upper(kw) .or. stunden == 0
    return kw
  endif

  // dazu z�hlen
  if stunden > 0

    // wochen hochz�hlen falls offset >= 38.5
    do while resultOffset >= ARBEITS_TAGE * ARBEITS_STUNDEN
      resultWoche++
      resultOffset -= ARBEITS_TAGE * ARBEITS_STUNDEN
    enddo

    resultJahr:=val(right(kw,2))
    do while resultWoche> (numWeeks:=getNumWeeks(resultJahr))
      resultJahr++
      resultWoche -= numWeeks
    enddo

    resultKW:=right("00"+alltrim(str(resultWoche,2)),2)+"/"+right("00"+;
      alltrim(str(resultJahr,2)),2)

    // Betriebsferien hinzu addieren?
    if holidays <> NIL
      holidayKWs:=aSort( HB_ATokens( holidays , "," ) ,,, { |kw1,kw2| kwKleiner( kw1 , kw2 ) > 0 };
        )
      For each holidayKW in holidayKWs
        holidayKW:=trim(holidayKW)
        if ! kwOkay(holidayKW)
          Trouble("Holidays",{"Ung�ltige KW in System->Holidays:"+holidayKW})
          loop
        endif
        // liegt holiday kw im Zeitraum?
        if kwKleiner( resultKw , holidayKW ) >=0 .and. kwKleiner( holidayKW , resultKW ) >= 0
          // Z�hle eine Woche hinzu, ohne Betriebsferien zu beachten!
          resultKW:=calcKW( resultKW , 0 , ARBEITS_STUNDEN * ARBEITS_TAGE )
        endif
      next
    endif

  else

    // wochen runterz�hlen falls offset < 0
    do while resultOffset < ARBEITS_TAGE * ARBEITS_STUNDEN * (-1)
      resultWoche--
      resultOffset += ARBEITS_TAGE * ARBEITS_STUNDEN
    enddo

    resultJahr:=val(right(kw,2))
    do while resultWoche<=0
      resultJahr--
      if resultJahr<0
        resultJahr:=99
      endif
      resultWoche += getNumWeeks(resultJahr)
    enddo

    resultKW:=right("00"+alltrim(str(resultWoche,2)),2)+"/"+right("00"+;
      alltrim(str(resultJahr,2)),2)

    // Betriebsferien abziehen?
    if holidays <> NIL
      // sortiere Betriebsferien KWs absteigend und pr�fe der Reihe nach
      holidayKWs:=aSort( HB_ATokens( holidays , "," ) ,,, { |kw1,kw2| kwKleiner( kw1 , kw2 ) < 0 };
        )
      For each holidayKW in holidayKWs
        holidayKW:=trim(holidayKW)
        if ! kwOkay(holidayKW)
          Trouble("Holidays",{"Ung�ltige KW in System->Holidays:"+holidayKW})
          loop
        endif
        // liegt holiday kw im Zeitraum?
        // if resultKW <= holidayKW <= kw
        if kwKleiner( resultKW , holidayKW ) >=0 .and. kwKleiner( holidayKW , kw ) >= 0
          // Ziehe eine Woche hinzu, ohne Betriebsferien zu beachten!
          resultKW:=calcKW( resultKW , 0 , ARBEITS_STUNDEN * ARBEITS_TAGE *(-1) )
        endif
      next
    endif

  endif

return resultKW
/** eof */


/*
* Anzeig der Ger�te je Kunde
*/
PROCEDURE Repa_Artikel_Auskunft()

  cls
  titel("A R T I K E L - Auskunft")

  if !;
    open("Artikel","Einheit","avaus","AvPost","Text","BesPost","Inner","Aufaus","Auftrag","AufPost","M_Mehrf","Kunden")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select BesPost
  BESPOST->(OrdSetFocus(2))
  select Inner
  INNER->(OrdSetFocus(2))
  select Artikel
  set relation to ARTIKEL->ME into Einheit

  do while .not. ABBRUCH

    Hilfe( "ARTIKEL AUSKUNFT" , getNew() )

    if ! ABBRUCH
      keyboard( ARTIKEL->Artnr + chr(FKT_SPECIAL))
    endif

  enddo

  cls
  close data

RETURN

Procedure LeerFormular()
LOCAL Zeile:=0,i,x,anz:=1,sprache:=DEUTSCH
LOCAL GetList:={}

  if ! open("Land")
    Error(TRY_AGAIN)
  endif

  cls
  Titel("Leeres Formular drucken")
  Message("Bitte Sprache und Anzahl eingeben.")
  @ 8,20 say "Sprache (D/E):" get sprache picture "!" valid sprache $ DEUTSCH+ENGLISCH
  @ 10,20 say "Anzahl Ausdrucke:" get anz picture "99"
  read

  if ! ABBRUCH

    Message("Formulare werden gedruckt.  Bitte warten...")

    /** w�hle Sprache je nach Empf�nger */
    selLandBySprache(Sprache)

    ignore x,i

    if ! seekPrinter("LEERFORMUL")
      Error(TRY_AGAIN)
      return
    endif

    getUser():setCurrentPrintJob(PrintJob():new())
    getUser():getCurrentPrintJob():numCopies:=anz
    getUser():getCurrentPrintJob():startCopyText:=-1 // never print Kopie on empty form
    getUser():getCurrentPrintJob():setBackground(getTranslation("config.formular",LAND->Sprache))
    // getUser():getCurrentPrintJob():setBackground(if(sprache==DEUTSCH,MIKI_FORMULAR,MIKI_FORMULAR_EN))
    getUser():getCurrentPrintJob():AGBs:=.t.
    getUser():getCurrentPrintJob():StartDoc( "Formular" )
    ?
    ?
    FormFeed()
    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(NIL)


  endif

return

Procedure LeerBrief()
LOCAL Zeile:=0,i,x,anz:=1
LOCAL GetList:={},sprache:=DEUTSCH
LOCAL Adresse:="J"

  if ! open("Land")
    Error(TRY_AGAIN)
  endif

  cls
  Titel("Leeren Brief-Kopf drucken")
  Message("Bitte Anzahl eingeben.")
  @ 7,18 to 13,42
  @ 8,20 say "Sprache (D/E):" get sprache picture "!" valid sprache $ DEUTSCH+ENGLISCH
  @ 10,20 say "Adresse (J/N):" get adresse picture "!" valid Adresse $ "JN"
  @ 12,20 say "Anzahl Ausdrucke:" get anz picture "99"
  read

  if ! ABBRUCH
    Message("Formulare werden gedruckt.  Bitte warten...")

    ignore x,i

    if ! seekPrinter("LEERBRIEF")
      return
    endif

    /** w�hle Sprache */
    selLandBySprache(Sprache)

    getUser():setCurrentPrintJob(PrintJob():new())
    getUser():getCurrentPrintJob():numCopies:=anz
    if Adresse == "J"
      getUser():getCurrentPrintJob():setBackground(getTranslation("config.brief",LAND->Sprache))
    else
      getUser():getCurrentPrintJob():setBackground(getTranslation("config.briefohne",LAND->Sprache;
        ))
    endif
    getUser():getCurrentPrintJob():startCopyText:=-1 // never print Kopie on empty form
    getUser():getCurrentPrintJob():StartDoc( "Brief-Kopf" )
    ?
    ?
    FormFeed()
    getUser():getCurrentPrintJob():endDoc()
    getUser():setCurrentPrintJob(NIL)

  endif

return

/** Workaround f�r Bug der St�cklisten l�scht
 * Mit dieser Fkt. kann man gel�schte S�tze aus AvPost wiederherstellen
 */
Procedure AvStkRecall()
LOCAL GetList:={},mArtNr

  cls
  titel("St�ckliste wiederherstellen")

  if ! open("AvPost","AvAus","Artikel")
    Error(TRY_AGAIN)
    close data
    return
  endif

  mArtNr:=space(len(ARTIKEL->ArtNr))

  Message("Bitte Artikel-Nummer eingeben.    @F12@=Hilfe")
  @ 8,20 say "Miki Artnr: " get mArtNr valid { |oGet| check(oGet,"Artikel",.f.) }
  read

  if ! ABBRUCH .and. ! empty(mArtNr)
    Message("Bitte warten...")
    set dele off
    select AvPost
    locate for AVPOST->AvNr==mArtNr
    if AVPOST->(eof())
      Error("Keine Kopie mehr vorhanden.  Bitte kontaktieren Sie Herrn Gruhn.",.t.)
    else
      if ! AVPOST->(deleted())
        Error("St�ckliste war nicht gel�scht.",.t.)
      else
        do while ! AVPOST->(eof())
          if rec_lock(5)
            recall
          endif
          cont
        enddo
        Message("St�ckliste wieder hergestellt.          Bitte @Taste@ dr�cken","@")
      endif
    endif
    set dele on
  endif

  close data
return
/** eop */



/** pr�ft bei allen ob der akt. LagerBestand mit der letzten Bewegung �bereinstimmt */
// findet nur Fehler falls letzte Bewegung vor diesem Check falsch
Function Waraus1KonsistenzCheck()
LOCAL treffer:=0,protName
  cls
  titel("Waraus 1 - KonsistenzCheck")

  if ! open("Artikel","Waraus")
    return .f.
  endif

  Protokoll(INIT_P,"Waraus1 Konsistenzcheck", "Art.Nr.   Bez                             LageBest "+;
    "lt.Waraus      Diff   Bewegung Datum    Programm")
  select WarAus
  WARAUS->(OrdSetFocus(2)) // desc
  select Artikel
  go top
  do while ! ARTIKEL->(eof())
    WARAUS->(dbseek(ARTIKEL->ArtNr))
    Message("Bitte warten:"+ARTIKEL->ArtNr)
    if ! WARAUS->(eof()) .and. WARAUS->Best<>ARTIKEL->LageBest .and. year(WARAUS->Datum)>2000
      treffer++
      Protokoll(PROTOKOLL,ARTIKEL->ARtNr+" "+ARTIKEL->Bez1+str(ARTIKEL->LageBest,10,2)+;
        str(WARAUS->Best,10,2)+" "+str(ARTIKEL->LageBest-WARAUS->Best,8,2)+" "+;
        str(WARAUS->Menge,10,2)+" "+dtoc(WARAUS->Datum)+" "+WARAUS->Programm)
    endif
    skip
  enddo
  Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
  if treffer==0
    if AT_HOME
      // email(MY_EMAIL,"Waraus 1 Konsistenzcheck okay")
      // else
      // email(MIKI_MAIN_EMAIL,"Waraus 1 Konsistenzcheck okay")
    endif
  else
    protName:=Protokoll(P_FILE_NAME)
    // if ! AT_HOME
    // email(MIKI_MAIN_EMAIL,"Fehler: Waraus 1 Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
    // endif
    email(MY_EMAIL,"Fehler: Waraus 1 Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
  endif

  close data
return .t.
/** eop*/

/** pr�ft ob der akt. LagerBestand mit der letzten Bewegung �bereinstimmt */
// Teil 2 -> falscher ARTIKEL->LagerBestand, Waraus Datensatz �berlesen
Function Waraus2KonsistenzCheck()
LOCAL treffer:=0,protName
LOCAL CheckDat:=date()-1 // ctod('15.11.2010')
LOCAL merkLageBest,merkArtnr,absatz:=.f.
  cls
  titel("Waraus 2 - KonsistenzCheck")

  if ! open("Artikel","Waraus")
    return .f.
  endif

  treffer:=0
  Protokoll(INIT_P,"Waraus2 Konsistenzcheck",;
    "Art.Nr.  Bez                           LageBest alt   Menge LageBest neu  Datum Programm")
  select WarAus
  WARAUS->(OrdSetFocus(1)) // ascending

  select Artikel
  go top
  do while ! ARTIKEL->(eof())
    Message("Bitte warten:"+ARTIKEL->ArtNr)

    WARAUS->(dbseek(ARTIKEL->ArtNr+dtos(checkDat)))
    if ! WARAUS->(eof()) .and. WARAUS->Datum==CheckDat // Artikel wurde "heute" bewegt
      merkArtNr:=WARAUS->ArtNr
      WARAUS->(dbskip(-1)) // Gehe auf vorhergehenden
      if merkArtNr<>WARAUS->ArtNr // Artikel noch nie vorher bewegt
        // Gehe wieder auf n�chsten
        WARAUS->(dbseek(ARTIKEL->ArtNr+dtos(checkDat)))
      endif

      merkLageBest:=WARAUS->Best
      WARAUS->(dbskip(1)) // Gehe auf den n�chsten
      // �berpr�fe alle folgenden
      do while merkArtNr==WARAUS->ArtNr .and. ! WARAUS->(eof())
        if merkLageBest<>WARAUS->Lg
          treffer++
          absatz:=.t.
          WARAUS->(dbskip(-1)) // Gehe auf den vorherigen
          Protokoll(PROTOKOLL,ARTIKEL->ARtNr+" "+ARTIKEL->Bez1+str(WARAUS->Lg,10,2)+;
            str(WARAUS->Menge,10,2)+str(WARAUS->Best,10,2)+" "+dtoc(WARAUS->Datum)+" "+;
            left(WARAUS->Programm,20)+WARAUS->MOD_User+str(WARAUS->(recno())))
          WARAUS->(dbskip(1)) // Gehe auf den "aktuellen"
          Protokoll(PROTOKOLL,ARTIKEL->ARtNr+" "+ARTIKEL->Bez1+str(WARAUS->Lg,10,2)+;
            str(WARAUS->Menge,10,2)+str(WARAUS->Best,10,2)+" "+dtoc(WARAUS->Datum)+" "+;
            left(WARAUS->Programm,20)+WARAUS->MOD_User+str(WARAUS->(recno())))
        endif
        merkLageBest:=WARAUS->Best
        WARAUS->(dbskip())
      enddo
      // Pr�fe akt. Lagerbestand mit letzter Bewegung
      if ARTIKEL->LageBest<>merkLageBest
        if ! absatz // falls vorher kein Fehler
          WARAUS->(dbskip(-1)) // Gehe auf den vorherigen
          Protokoll(PROTOKOLL,ARTIKEL->ARtNr+" "+ARTIKEL->Bez1+str(WARAUS->Lg,10,2)+;
            str(WARAUS->Menge,10,2)+str(WARAUS->Best,10,2)+" "+dtoc(WARAUS->Datum)+" "+;
            left(WARAUS->Programm,20)+WARAUS->MOD_User+str(WARAUS->(recno())))
          WARAUS->(dbskip(1)) // Gehe auf den "aktuellen"
        endif
        Protokoll(PROTOKOLL,"Abweichender Lagerbestand:"+space(33)+str(ARTIKEL->Lagebest,10,2))
      endif
    endif
    if absatz
      absatz:=.f.
      Protokoll(PROTOKOLL,"---")
    endif
    ARTIKEL->(dbskip())
  enddo
  Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
  if treffer>0
    // Protokoll(PRINT_P)
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Fehler: Waraus 2 Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
  endif

  close data
return .t.
/** eop*/


/** pr�ft ob Bewegungen existieren, deren Artikel gel�scht wurde */
Function WarausDelete()
LOCAL treffer:=0,protName,erst:=.t.
  cls
  titel("Waraus - Delete - KonsistenzCheck")

  if ! open("Artikel","Waraus")
    Error(TRY_AGAIN)
    return .f.
  endif

  Protokoll(INIT_P,"Bewegungsdatei Konsistenzcheck","Art.Nr.    Bew.Dat.    Menge   Bestand "+;
    "K-Bestand Kz Programm")

  select Waraus
  set rela to WARAUS->ArtNr into Artikel
  loca for ARTIKEL->(eof())
  do while ! WARAUS->(eof())
    @ 12,20 say WARAUS->ArtNr
    treffer++
    Protokoll(PROTOKOLL,OUT(WARAUS->ArtNr)+" "+dtoc(WARAUS->Datum)+str(WARAUS->Menge,10,2)+;
      str(WARAUS->Best,10,2)+str(WARAUS->KonsigBest,10,2)+WARAUS->Mod_User+" "+WARAUS->Programm)
    cont
  enddo

  if treffer > 0
    Protokoll(PROTOKOLL,"")
    erst:=.t.
  endif

  Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
  protName:=Protokoll(P_FILE_NAME)
  if treffer > 0
    email(MAIN_EMAIL,"Bewegungsdatei Konsistenzcheck gel�schte Artikel","Bitte pr�fen",protName)
  endif
  close data
return .t.

/** eof */

/* FUNCTION  HonselArtikel
*
* falls EingabeFeld: ArtNr -> suche nach HonselNr
*/
FUNCTION HonselArtikel( ProcName, oGet, ReadVar )
  ignore procname
  if valtype(oGet) == "O" // Object

    if "ARTNR" $ upper(oGet:Name) .or. "M->ARTNR"== upper(oGet:Name)

      Umgebung(WRITE_ALL)
      Hilfe( "HONSELARTIKEL",getNew(),ReadVar )
      Umgebung(LOAD)

    endif

  endif
RETURN .t.
/* EOF */

/** rechnet f�r den akt. selekt. Artikel die Preiskalk aus
 *
 * Parameter Ausgabe "BS","ON" oder "NOP" (keine Anzeige)
 */
function preisKalkArtikel(anzeige,isLock)
LOCAL Merk_Satz:=recno()
LOCAL Merk_artNr:=ARTIKEL->ArtNr
LOCAL Merk:=if(ARTIKEL->Schluessel=="H",100,1)
LOCAL dienstLeistung:=(getArtikelArt()=="D")

  Umgebung( WRITE_ALL )

  Message("Preis-Kalkulation wird gedruckt.   Bitte warten...")

  select AvPost
  SET RELATION TO AVPOST->ArtNr INTO Artikel, TO AVPOST->ArtNr INTO Text,;
    TO AVPOST->ArtNr into Maschine, TO AVPOST->ME INTO Einheit
  Kal_druck(Merk_ArtNr,merk,0,Anzeige,.t.,dienstLeistung,isLock)

  Umgebung( LOAD )
return .t.
/** eof */


/* ermoeglicht das rekursive anzeigen von Preiskalk */
PROCEDURE rekPreisKalk(text, ZeigeData)
LOCAL mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]
LOCAL recNr:=ZEIGE->(recno())
LOCAL test:=strtran(text,BS_FARBE,"")
LOCAL aktRec:=ARTIKEL->(recno())

  ARTIKEL->(dbseek(mArtNr))

  if ARTIKEL->(eof()) .or. ! getArtikelArt() $ STKLIST_ARTIKEL
    beep()
    ARTIKEL->(dbgoto(aktRec))
  else
    // kom:=getUser():getTempCounter()
    // kopieZeige:=TEMP+"\T"+getUser():getLongID()+kom+".dbf"

    // Umgebung(WRITE)
    // select Zeige
    // copy to (kopieZeige)
    // zap

    Select Artikel
    preisKalkArtikel("BS")

    // Umgebung(LOAD)
    // select Zeige
    // zap
    // appe from (kopieZeige)
    // ferase( (kopieZeige) )
    // go (recNr)
    ARTIKEL->(dbgoto(aktRec))
  endif

RETURN
/* EOP */


/*
 *
 * Updated ARTIKEL->verkauft anhand der vorhandnen Rechnungsposten (seit 1.4.1995)
*
*/
FUNCTION ArtVerkauftUpdate()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,bez:="",gesMenge:=0
LOCAL MArtNr:="", protName

  cls
  titel("Artikel Verkauft Update")

  backup("Artikel")


  if ! open({"Artikel",.t.},"Rechaus","RechPost")
    Error(TRY_AGAIN)
    cls
    RETURN .f.
  endif

  Message("Artikel-Verkauft wird auf 0 gesetzt.")
  select Artikel
  replace all ARTIKEL->Temp with str(ARTIKEL->verkauft), ARTIKEL->verkauft with 0

  select RechPost
  Message("Artikel-Verkauft Update.  Rechnungsposten werden sortiert.   Bitte warten...")
  index on RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for len(alltrim(RECHPOST->ArtNr))>FRACHT_LAENGE .and. RECHPOST->ReaDat>=HIST_START_DATE

  Protokoll(INIT_P,"Artikel Konsistenzcheck","Artikel                                verkauft "+;
    "vorher         nachher")

  go top
  do while .not. RECHPOST->(eof())
    gesMenge:=0
    ARTIKEL->(dbseek(RECHPOST->ArtNr))
    if ARTIKEL->(eof())
      skip
      loop
    endif

    do while .not. RECHPOST->(eof()) .and. RECHPOST->ArtNr==ARTIKEL->ArtNr
      gesMenge+=RECHPOST->gelief
      skip
    enddo // Blattl�nge
    select Artikel
    // if rec_lock(5)
    replace ARTIKEL->verkauft with gesMenge
    // dbcommit()
    // dbunlock()
    Message("Artikel:"+ARTIKEL->ArtNr+" verkauft:"+str(gesMenge,10))

    if ARTIKEL->verkauft <> val(ARTIKEL->Temp) .and. alltrim(ARTIKEL->ArtNr) <> ANGEBOTS_ARTIKEL
      Protokoll(PROTOKOLL,ARTIKEL->ArtNr+space(1)+ARTIKEL->Bez1+ARTIKEL->Temp+;
        str(ARTIKEL->verkauft))
    endif

    // endif
    select RechPost
  enddo // eof()

  if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen!",,,.f.)
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Artikel Verkauft pr�fen","Bitte pr�fen",protName)
  endif

  close data

RETURN .t.
/* EOF */

/* PROCEDURE Stklist_check **************************************
*
* �berpr�ft die St�cklisten auf loops
*/
PROCEDURE StkList_check(auto)
LOCAL tiefe:=0,protName
  default auto:=.f.

  cls
  titel("St�cklisten �berpr�fen")

  if ! auto
    @ 9,19 to 15,60
    @ 10,21 say 'Dieser Vorgang dauert einige Zeit !'
    @ 12,21 say 'Bitte Best�tigen (b) '

    IF ! upper(chr(warte(0))) == "B"
      cls
      close data
      return
    ENDIF
  endif

  @ 12,21 say "Bitte warten......     "
  @ 14,21 say "St�ckliste-Tiefe wird ermittelt."

  if ! open( "Artikel" , "AvPost" , "AvAus")
    Error(TRY_AGAIN)
    close data
    cls
    RETURN
  endif


  select AvAus
  go top

  /* St�cklisten-Tiefe ermitteln */
  Protokoll(INIT_P,"St�cklisten �berpr�fen"+space(37)+"vom "+dtoc(getUser():date))
  do while ! AVAUS->(eof())
    @ 16,21 say AVAUS->AvNr
    select AvPost
    if (tiefe:=Tiefe(AVAUS->AvNr,0,auto)) >= MAX_LOOP
      Protokoll(PROTOKOLL , "in St�ckliste:"+AVAUS->AvNr+" Max. Teife erreicht:"+str(tiefe,3),"")
    endif
    select AvAus
    skip
  enddo

  if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
    protName:=Protokoll(P_FILE_NAME)
    email(MAIN_EMAIL,"Fehler: St�ckliste Tiefe Konsistenzcheck.","Bitte pr�fen",protName)
  endif
  // /* LIste ausdrucken */
  // Protokoll(PRINT_P)
  cls
  close data
RETURN
/** eop */



/** Berechnet die Kalk.Preise aller E und W Artikel */
Procedure Preis_EWArtikel

  if ! open("Artikel","System","AvPost")
    Error(ACHTUNG+" Artikel.dbf nicht verf�gbar.",.t.)
  else
    Protokoll(INIT_P,"Artikel E/W Preiskalkulation")
    select Artikel
    set filter to getArtikelArt()$"EW"
    go top
    do while ! ARTIKEL->(eof())

      if ARTIKEL->KaPr <> round(ARTIKEL->EKPr*((100+SYSTEM->Aufschlag)/100),2)

        // pr�fe ob St�ckliste vorhanden, dann wird Preis in Preis_Check() �berschrieben
        // sprich kann hier ignoriert werden
        AVPOST->(dbseek(ARTIKEL->ArtNr+"M"))
        if AVPOST->(eof())
          Protokoll(PROTOKOLL,out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+;
            str(ARTIKEL->KaPr)+" -> "+str(ARTIKEL->EKPr*((100+SYSTEM->Aufschlag)/100)))

          if rec_lock(5)
            replace ARTIKEL->KaPr with ARTIKEL->EKPr*((100+SYSTEM->Aufschlag)/100)
            if ARTIKEL->KaPr <>0
              if ((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100>9999.5
                Protokoll(PROTOKOLL,;
                  " Zuschlag:"+str(((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100,10,2)+;
                  " ist zu gross.",.t.)
              else
                replace ARTIKEL->Zuschl_I with ((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100
              endif
            endif
            replace ARTIKEL->Kalk_Druck with "*"
          endif
          dbcommit()
          dbunlock()
        endif
      endif
      skip
    enddo
    if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen!",,,.f.)
      email(MY_EMAIL,"E/W Artikel Kalk.Preis Berechnung.","Bitte pr�fen",Protokoll(P_FILE_NAME))
    endif
  endif
  close data
return
/** eop */


/** F�hrt ein paar Miki-spez. Initialisierungs Aufrufe aus */
Procedure initMiki()

  // set some special MIKI keys
  #ifdef HONSEL_TASTE
  set key HONSEL_TASTE to HonselArtikel // Hilfe-Proc
  #endif

  SetKey( K_CTRL_V , {|| pasteClipBoard( { "AV_INSTRUKT" } ) } )
  // SetKey( EXCEL_TASTE , {|| exportExcel() } )

  // pr�fe Import Verzeichnis bei MW und JG only
  // if getUser():id==KURZEL_DEVEL
  // aFiles:=directory(IMPORT+BACKSLASH+"blz*.txt")
  // for i:=1 to len(aFiles)
  // Titel("Bankleitzahlen Import")
  // Error("Bankleitzahlen-Datei gefunden:"+IMPORT+BACKSLASH+aFiles[i,F_NAME],ERR_NO_WAIT)
  // if Message("BLZ Datei importieren?  (@J@/@N@)","JN","J")=="J"
  // BLZImport(IMPORT+BACKSLASH+aFiles[i,F_NAME])
  // endif
  // next
  // endif

  if DEVEL_PROG .or. TEST_PROG
    // SetKey( K_CTRL_F8 , {|| __keyboard("3800901"+chr(13)) } )
    SetKey( K_CTRL_F8 , {|| __keyboard("4100500"+chr(13)) } )
  endif

return
/** eop */


/** Geht auf den passenden Datensatz in Rabatt an Hand der
  * Rabatt-Tabell und der Menge und liefert die gefunden Position 1-9
  * zur�ck
  *
  * Result: 0 hei�t "not found"
  */

FUNCTION getMengenRabattStaffel(RabattGr,Menge)
LOCAL aktSel:=alias()
LOCAL feldMenge,x
LOCAL result:=0

  select Rabatt
  seek RabattGr
  if .not. eof()
    x=1
    feldMenge="Meng"+str(x,1)
    do while x < 10 .and. &FeldMenge<=Menge .and. &FeldMenge > 0
      x=x+1
      feldMenge="Meng"+str(x,1)
    enddo
    if x>1
      x-- // ist ja schon gr��er
    endif
    feldMenge="Meng"+str(x,1)
    if x < 10 .and. &FeldMenge<=Menge .and. &FeldMenge > 0
      result:=x
    endif
  endif
  SELECT (aktSel)
return result
/** eof */


/*
* merke akt. �nderungsdatum, Artikel muss selektiert sein
*/
FUNCTION Pr_Prot(oGet,kalk,schreibeHist,presetGrund)
LOCAL Merk_Satz:=recno(),preGrund
LOCAL Merk_artNr:=ARTIKEL->ArtNr
LOCAL Merk:=if(ARTIKEL->Schluessel=="H",100,1)
LOCAL dienstLeistung:=(getArtikelArt()=="D")
LOCAL GetList:={}, KalkText:="",tempStr,tempWert
LOCAL s01:=savescreen(),i,merkKaPr,sendEmail:=.t.
LOCAL aSatz:=getCurrentValues()

  _thread static M_grund

  Umgebung( WRITE_ALL )

  if M_Grund==NIL
    M_grund:=space(30)
  endif

  default kalk:=.t.
  default schreibeHist:=.t.

  if oGet==NIL .or. oGet:changed

    // debug kann sp�ter raus

    if oGet<>NIL
      if oGet:Name == "ARTIKEL->Preis1"
        trouble("PreisProt", ARTIKEL->ArtNr+" vorher  Ka.Pr.:"+str(ARTIKEL->KaPr)+" "+;
          " VK.Pr.:"+str(oGet:original) )
      elseif oGet:Name == "ARTIKEL->EKPR"
        trouble("PreisProt", ARTIKEL->ArtNr+" vorher  Ka.Pr.:"+str(ARTIKEL->KaPr)+" "+;
          " EK.Pr.:"+str(oGet:original) )
      endif
    endif

    // merke vorherigen Kalk.Preis
    merkKaPr:=ARTIKEL->KaPr

    // replace ARTIKEL->VK_Aend with substr(dtoc(getUser():date),4,2)+"/"+right(dtoc(getUser():date),2)

    if oGet<>NIL
      oGet:assign()
    endif

    Message("Preis-Kalkulation: "+ARTIKEL->ArtNr+" wird gespeichert.   Bitte warten...")
    if getArtikelArt() $ "WE"
      if select("System")==0
        if ! open("System")
          Error(ACHTUNG+" Aufschlag konnte nicht gelesen werden.|Bitte erneut versuchen.",.t.)
          select Artikel
          restscreen(,,,,s01)
          Umgebung( LOAD )
          setCurrentValues( aSatz )
          return .f.
        endif
        select Artikel
      endif
      replace ARTIKEL->KaPr with ARTIKEL->EKPr*((100+SYSTEM->Aufschlag)/100)
      if ARTIKEL->KaPr <>0
        if ((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100>9999.5
          Error(ACHTUNG+" Zuschlag:"+str(((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100,10,2)+;
            " ist zu gross.",.t.)
        else
          replace ARTIKEL->Zuschl_I with ((ARTIKEL->Preis1/ARTIKEL->KaPr)-1)*100
        endif
      endif
      replace ARTIKEL->Kalk_Druck with "*"
      if oGet<>NIL
        setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
      endif

    else

      if kalk .and. getArtikelArt() $ STKLIST_ARTIKEL
        // Kalk. erstellen
        select AvPost
        SET RELATION TO AVPOST->ArtNr INTO Artikel, TO AVPOST->ArtNr INTO Text,;
          TO AVPOST->ArtNr into Maschine, TO AVPOST->ME INTO Einheit
        Kal_druck(Merk_ArtNr,merk,0,"ALT",.t.,dienstLeistung,.t.)
        select AvPost
        set relation to

        set alte off
        set cons on
        close alte
        kalkText:=getMemoText()
        getUser():setCurrentPrintJob(NIL)
      endif
    endif

    select Artikel
    go (Merk_Satz) // INFO: wird gebraucht, wegen obiger rela von AvPost

    restscreen(,,,,s01)
    if oGet <> NIL
      dispArtikelWerte()
    endif

    // Grund eingeben, seit 27.4.15 nach Anzeige der neuen Werte
    if schreibeHist .and. ( oGet==NIL .or. oGet:changed )
      if oGet==NIL
        preGrund:=M_Grund
        M_Grund:=presetGrund
      elseif empty(ARTIKEL->Schluessel) // unsch�n, aber bei neuen Datensatz keine Grund Abfrage
        M_Grund:=left("Neu"+space(30),30)
      else
        // Grund erfassen
        setcolor(COLWIN)
        Fenster(11,30,13,70)
        @ 12,32 say "Grund:" get M_grund picture "@K" valid ! emptyOr2Simple(M_grund,5) ;
          when Message("Grund f�r Preis�nderung eingeben (mind 5 Zeichen)  @F12@=Auswahl  @ESC@=Ende")
        read
        setcolor(COLNOR)
        restscreen(,,,,s01)
        if ABBRUCH
          Umgebung( LOAD )
          setCurrentValues( aSatz )
          return .f.
        endif
      endif
    endif

    // schreibe Preis-Historie
    addPreisHistorie(M_Grund, KalkText)

    // Auto-Grund nach kopieren nicht merken
    if oGet==NIL
      M_Grund:=preGrund
    endif

    // we bail out on Artikel Kopieren (no real get input)
    if oGet==NIL
      Umgebung( LOAD )
      return .t.
    endif

    // schicke Email an H. Weiland falls jemand anders Preis �ndert
    if ! getUser():id $ "MW/JG"

      // nicht bei Neuanlge
      i:=1
      while ( !Empty(ProcName(i)) )
        if "SATZ_NEU" $ ProcName(i)
          Umgebung( LOAD )
          return .t.
        endif
        i++
      enddo

      do case
      case "EKPR"$oGet:name
        tempStr:="EK"
      case "Preis1"$oGet:name
        tempStr:="EK"
      case "Art"$oGet:name
        tempStr:="Artikel-Art"
        sendEmail:=(merkKaPr<>ARTIKEL->KaPr)
      otherwise
        tempStr:="Andere"
      endcase

      if valtype(Oget:Original)=="N"
        tempWert:="vorher :"+str(Oget:Original,9,2)+"|nachher:"+oget:Buffer
      else
        tempWert:="vorher :"+Oget:Original+"|nachher:"+oget:Buffer
        if empty(Oget:Original) // Vorher leer -> Neuanlage
          Umgebung( LOAD )
          return .t.
        endif
      endif

      if ! TEST_PROG .and. sendEmail // seit 20120326 Email nur noch bei ge�nderten Kalk.Preis
        email(MAIN_EMAIL,;
          "Artikel Preis �nderung: "+ARTIKEL->ArtNr,"Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+;
          "||"+tempStr+":"+"|"+tempWert+;
          "|Grund  : "+trim(M_Grund)+" ("+getUser():id+")|Datum  : "+dtoc(date())+"  Uhrzeit: "+time())
      endif

    endif


  endif

  Umgebung( LOAD )
RETURN(.t.)
/** eof */


/** Rechnet Stunden in Tage und Stunden um.
  *
  * liefert array mit {Tage,Stunde} zur�ck
  */
function getStundenToTage(gesamt)
LOCAL StdTag:=ARBEITS_STUNDEN , stunden , tage
LOCAL aktSel:=alias()

  // Info round is needed otherwise 1.000 is renognized as int
  tage:=round( int( gesamt / stdtag ) , 2)
  stunden:=round( (gesamt / stdtag - tage ) * StdTag , 2)

  // immer aufrunden
  if IsInteger(Stunden)
    stunden:=int(stunden)
  else
    if stunden>0
      stunden:=int(stunden)+1
    else
      stunden:=int(stunden)-1
    endif
  endif
  if stunden >= ARBEITS_STUNDEN
    tage++
    stunden:=0
  elseif stunden <= ARBEITS_STUNDEN * (-1)
    tage--
    stunden:=0
  endif

  if ! empty(aktSel)
    select (aktSel)
  endif

return {Tage,Stunden}
/** eof */

FUNCTION IsInteger( nNumber )
RETURN ( nNumber - Int(nNumber) == 0 )

/** Liefert die Stunden als Text:  x Tage y Stunden */
function getStdTagText( dauer , kurzForm , laenge)
LOCAL tempVal:=getStundenToTage(dauer)
LOCAL result:=""

  default kurzForm:=STDTAG_NORMAL

  // Kurzform optional
  if kurzForm == STDTAG_TINY
    result:=alltrim(str(tempVal[1],6,0))+"T "+alltrim(str(tempVal[2]))+"S"
  else
    // tage
    if tempVal[1]>0
      if tempVal[1]==1
        result += alltrim(str(tempVal[1],6,0))+" Tag "
      else
        result += alltrim(str(tempVal[1],6,0))+" Tage "
      endif
    endif

    // Stunden
    if tempVal[2]>0
      if kurzForm == STDTAG_KURZ
        result += alltrim(str(tempVal[2]))+" Std"
      else
        if tempVal[2]>1
          result += alltrim(str(tempVal[2]))+" Stunden"
        else
          result += alltrim(str(tempVal[2]))+" Stunde"
        endif
      endif
    endif
  endif

  if valtype(laenge)=="N"
    result:=left(result+space(laenge),laenge)
  endif

return result
/** eof */


/** Liefert die Anzahl der "angebrochenen" Wochen auf Basis der Miki-Wochen-Stunden
  * z.B.
  9h   -> 1 Woche
  40h  -> 2 Wochen  
  */
function getWochen( stunden )
LOCAL tempVal:=stunden/ARBEITS_STUNDEN/ARBEITS_TAGE
LOCAL result:=round(tempVal,0)
  if result==0 .and. stunden > 0
    return 1
  endif
return result
/** eof */



/** berechnet die Mindest-Bestellmenge f�r alle (!) Fertigungs-Artikel
  * nur f�r Artikel mit R�stzeiten in der Zeit-St�ckliste relevant
  *
  * Top-Down, l�uft nachts per crontab
  *
  */
procedure MindestBestellMenge(quiet)
LOCAL Zeile:=0,alleMengen:=hb_Hash(), mengen, mArtnr, schnitt,m,maxMenge,abweichung,maxFound
LOCAL Spalte

  default quiet:=.f.

  if quiet
    drucker("NOP")
  else
    cls
    Titel("Mindest-Bestellmenge berechnen")

    @ 9,19 to 15,60
    @ 10,21 say 'Dieser Vorgang dauert einige Zeit !'

    if ! druck_BS() // Abbruch
      close data
      RETURN
    endif

    @ 12,21 say "Bitte warten......     "

  endif

  if ! open( "Artikel" , "AvPost", "Maschine", "Mehrfach")
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  // setzte alle Mindest.Bestell-Soll Werte vorher auf 0
  Message("Soll-Werte werden initialisiert.   Bitte warten....")
  select Artikel
  locate for getArtikelArt()$"XFM"
  go top
  do while ! ARTIKEL->(eof())
    if ARTIKEL->MinOrderS>0 .and. rec_lock(5)
      replace ARTIKEL->MinOrderS with 0
      dbcommit()
      dbunlock()
    endif
    cont
  enddo

  // jetzt berechnen
  ? "Art.Nr.    Bezeichnung              Mindest.Best vorher nachher"
  ? "============================================================================================"+;
    "============"
  ? "Details: RuestZeit x MaschinenKosten x Nutzen / (Kalk.Preis * Zuschlag - Kalk.Preis) = "+;
    "Mind.Bestellmenge"
  ? "                                                                                       "+;
    "rot==�bernommen"
  ? "============================================================================================"+;
    "============"

  select Artikel
  go top
  do while ! ARTIKEL->(eof())

    if getArtikelArt()$"XFM" .and. ARTIKEL->Preis1>0 // .and. ARTIKEL->verkauft>0
      // Suche alle Unter-Artikel mit R�stzeit
      Message("@"+ARTIKEL->ArtNr+"@ wird berechnet.    Bitte warten...")

      ? FETT_AN,"H:"+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,FETT_AUS
      if ARTIKEL->KaPr==0
        ?? "Kalk.Preis ist 0 -> Datensatz wird ignoriert."
      else
        ?? round(ARTIKEL->Preis1/ARTIKEL->KaPr*100,2),"%"
        if ARTIKEL->Preis1/ARTIKEL->KaPr>1
          rekMindBest(@alleMengen,ARTIKEL->ArtNr,ARTIKEL->Preis1/ARTIKEL->KaPr,0) // VK=KaPr*Zuschlag
        endif
      endif
    endif
    skip
  enddo

  // Auswertung der Mengen pro Artikel und r�ckschreiebn nach Artikel-Stamm
  Zeile:=FormFeed(Zeile)
  ? "Zusammenfassung:"
  ? "================"

  abweichung:=(val(getProperty("Miki.mindestbestell.abweichung","50"))+100)/100

  select Artikel
  for each mArtNr in alleMengen:Keys
    Message("Artikel: @"+mArtNr+"@ wird aktualisiert.   Bitte warten")
    mengen:=alleMengen[mArtNr]
    ARTIKEL->(dbseek(mArtNr))
    if ARTIKEL->(eof())
      TroubleEmail("Fehlende Artikel in MindestBestellMenge: "+mArtNr)
    else
      ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1

      // sortiere und summiere alle Mengen je Artikel
      // aSort(mengen)
      schnitt:=0
      for each m in mengen
        schnitt += m
      next
      schnitt:=schnitt/len(mengen)
      maxMenge:=round(schnitt*abweichung,2)
      maxFound:=0

      ? space(len(out(ARTIKEL->ArtNr))),DURCHSCHNITT_SIGN,alltrim(str(schnitt)),"*",;
        alltrim(str(abweichung))+"% = Max:",alltrim(str(maxmenge))

      // jetzt schauen welche zu arg abweichen
      Spalte:=26
      ? space(len(out(ARTIKEL->ArtNr))),"Mindest-Mengen:"
      for each m in mengen
        if m<=maxMenge
          ?? alltrim(str(m))
          spalte += len(alltrim(str(m)))
          maxFound:=max(maxFound,m)
        else
          ?? "("+alltrim(str(m))+")"
          spalte += len(alltrim(str(m)))+2
        endif
        // Umbruch?
        if spalte > 70
          ? space(len(out(ARTIKEL->ArtNr)))
          spalte:=len(out(ARTIKEL->ArtNr))
        endif
      next

      if ! rec_lock(5)
        TroubleEmail("Artikel nicht verf�gbar in MindestBestellMenge: "+mArtNr)
      else
        ?? FETT_AN,"->"+alltrim(str(maxFound)),FETT_AUS
        replace ARTIKEL->MinOrderS with maxFound
        dbcommit()
        dbunlock()
      endif

    endif
  next

  if quiet
    set cons on
  else
    drucker("OFF")
  endif
  cls
  close data
return
/** eop */

/** berechnet rekursiv die Mindest-Bestellmenge f�r alle Fertigungs-Artikel
  * nur f�r Artikel mit R�stzeiten in der Zeit-St�ckliste relevant
  *
  * bottom-up
  *
  * Artikel muss selektiert sein
  */
static procedure rekMindBest(alleMengen,mArtNr,zuschlag,tiefe,highRecno,details,gedruckteArtikel)
LOCAL aktRec,aktAvPost,aktSel:=alias()
LOCAL Zeile:=0,druckeDetails
LOCAL ruestKosten,mindestBest

  default details:=.t.
  default gedruckteArtikel:={}

  if Zuschlag > 0

    aktRec:=ARTIKEL->(recno())

    // addiere R�stzeit aus Zeit-St�ckliste
    // Hinweis: hier auch bei automat. Maschinen volle R�stkosten berechnen
    select AvPost
    AVPOST->(dbseek(mArtNr+"V"))
    do while ! AVPOST->(eof()) .and. AVPOST->Art=="V" .and. AVPOST->AvNr==mArtNr
      if AVPOST->Text=="A" .and. AVPOSt->RuestZeit>0
        MASCHINE->(dbseek(trim(AVPOST->ArtNr)))
        ruestKosten:=AVPOSt->RuestZeit * ;
          if(AVPOST->HauptKZ=="H" .and. AVPOST->Automat=="N",MASCHINE->Kosten,MASCHINE->KostenNe)

        // Mindesmenge merken, falls gr��er
        if ruestKosten>0
          select Artikel
          ARTIKEL->(dbseek(mArtNr))
          if ( round(ARTIKEL->KaPr * Zuschlag, 2) - ARTIKEL->KaPr) == 0
            ? space(tiefe*2),ARTIKEL->ArtNr,"FEHLER Divisor ist 0: Kalk.Preis:",ARTIKEL->KaPr,;
              "Marge:", str(1-Zuschlag,5,2)+"%"
          else
            mindestBest:=ruestKosten / ( round(ARTIKEL->KaPr * Zuschlag,2) - ARTIKEL->KaPr)
            if int(mindestBest)<>mindestBest
              mindestBest:=int(mindestBest)+1
            endif

            druckeDetails:=(details .or. ARTIKEL->(recno())==highRecno)

            // jeden Artikel nur 1x drucken, falls keine Details
            if ARTIKEL->(recno())==highRecno .and. ! details
              if ascan(gedruckteArtikel,ARTIKEL->ArtNr)>0
                druckeDetails:=.f.
              endif
            endif

            // highlighte aktuellen Artikel, wenn er aus ArtikelStamm kommt siehe MindBestArtikel()
            if druckeDetails
              if ARTIKEL->(recno())==highRecno .and. details
                ? FETT_AN
              else
                ?
              endif
              ?? space(tiefe*2),out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->MinOrderS,;
                str(mindestBest,7)
              ? space(tiefe*2),"--> Details:",AVPOSt->RuestZeit,"x",;
                if(AVPOST->HauptKZ=="H" .and. AVPOST->Automat=="N",MASCHINE->Kosten,MASCHINE->KostenNe),"x",;
                alltrim(getMehrfNutzen()),"/ (",;
                alltrim(str(ARTIKEL->KaPr,12,2)),"x",alltrim(str(Zuschlag,12,2)),"-",;
                alltrim(str(ARTIKEL->KaPr,12,2)),") ="
            endif
            if hb_HHasKey( alleMengen, mArtNr)
              aadd(alleMengen[mArtNr],mindestBest)
            else
              alleMengen[mArtNr]:={mindestBest}
            endif
            if details .or. ARTIKEL->(recno())==highRecno
              ?? alltrim(str(mindestBest))
            endif

            // merke gedruckter Artikel 1x, falls Druck ohne Details gew�nscht
            if ascan(gedruckteArtikel,ARTIKEL->ArtNr)==0
              aadd(gedruckteArtikel,ARTIKEL->ArtNr)
            endif

          endif
        endif
      endif
      select AvPost
      skip
    enddo

    // gehe eine Ebene tiefer
    select AvPost
    AVPOST->(dbseek(mArtNr+"M"))
    do while ! AVPOST->(eof()) .and. AVPOST->Art=="M" .and. AVPOST->AvNr==mArtNr
      if AVPOST->Text=="A"
        // gehe eine Ebene tiefer
        aktRec:=ARTIKEL->(recno())
        aktAvPost:=AVPOST->(recno())
        rekMindBest(@alleMengen,AVPOST->ArtNr,zuschlag,tiefe+1,highRecno,details,gedruckteArtikel)
        AVPOST->(dbgoto(aktAvPost))
        ARTIKEL->(dbgoto(aktRec))
      endif
      skip
    enddo

    select(aktSel)

  endif

return
/** eop */

/** berechnet die Mindest-Bestellmenge f�r den aktuell selektiern Artikel
  * nur f�r Artikel mit R�stzeiten in der Zeit-St�ckliste relevant
  *
  */
procedure MindBestArtikel(details)
LOCAL Zeile:=0,alleMengen:=hb_Hash(), mengen, mArtnr, schnitt,m,maxMenge,abweichung,maxFound
LOCAL Spalte,aktRec:=ARTIKEL->(recno()),alleOberArtikel:=hb_hash(),merkOrd
LOCAL s01:=savescreen()

  Message("Mindest-Bestellmenge wird berechnet.   Bitte warten...")

  // aktueller Artikel bereits verkauft? -> zur Berechnung hinzuf�gen
  if getArtikelArt()$"XFM" .and. ARTIKEL->Preis1>0 // .and. ARTIKEL->verkauft>0
    alleOberArtikel[ARTIKEL->ArtNr]:=.t.
  endif

  // suche alle Oberartikel mit VK die bereits verkauft worden sind.
  select AvPost
  merkOrd:=AVPOST->(indexord())
  AVPOST->(OrdSetFocus(2)) // Unterartikel+Hauptartikel
  rekOberArtikel(@alleOberArtikel,ARTIKEL->ArtNr)
  AVPOST->(OrdSetFocus(merkOrd))

  Drucker("BS")
  // jetzt berechne alle gefundenen Oberartikel
  ? "Art.Nr.    Bezeichnung              Mindest.Best vorher nachher"
  ? "============================================================================================"+;
    "============"
  ? "Details: RuestZeit x MaschinenKosten x Nutzen / (Kalk.Preis * Zuschlag - Kalk.Preis) = "+;
    "Mind.Bestellmenge"
  ? "============================================================================================"+;
    "============"

  for each mArtNr in alleOberArtikel:Keys
    ARTIKEL->(dbseek(mArtNr))
    ? FETT_AN,"H:"+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,FETT_AUS
    if ARTIKEL->KaPr==0
      ?? "Kalk.Preis ist 0 -> Datensatz wird ignoriert."
    else
      ?? round(ARTIKEL->Preis1/ARTIKEL->KaPr*100-100,2),"%"
      if ARTIKEL->Preis1/ARTIKEL->KaPr>1
        // VK=KaPr*Zuschlag
        rekMindBest(@alleMengen,ARTIKEL->ArtNr,ARTIKEL->Preis1/ARTIKEL->KaPr,0,aktRec,details)
      endif
    endif
  next

  // Auswertung der Mengen pro Artikel und r�ckschreiebn nach Artikel-Stamm
  ?
  ?
  ? "Zusammenfassung:"
  ? "================"

  abweichung:=(val(getProperty("Miki.mindestbestell.abweichung","50"))+100)/100

  select Artikel
  if len(alleMengen)==0
    go (aktRec)
    if ARTIKEL->MinOrderS<>0 .and. rec_lock(5)
      replace ARTIKEL->MinOrderS with 0
      dbcommit()
      dbunlock()
    endif

  else
    for each mArtNr in alleMengen:Keys
      Message("Artikel: @"+mArtNr+"@ wird aktualisiert.   Bitte warten")
      mengen:=alleMengen[mArtNr]
      ARTIKEL->(dbseek(mArtNr))
      if ARTIKEL->(eof())
        TroubleEmail("Fehlende Artikel in MindestBestellMenge: "+mArtNr)
      else

        // drucke nur aktuellen Artikel aus
        if ARTIKEL->(recno())== aktRec
          ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1
        endif

        // sortiere und summiere alle Mengen je Artikel
        // aSort(mengen)
        schnitt:=0
        for each m in mengen
          schnitt += m
        next
        schnitt:=schnitt/len(mengen)
        maxMenge:=round(schnitt*abweichung,2)
        maxFound:=0
        if ARTIKEL->(recno())== aktRec
          ? space(len(out(ARTIKEL->ArtNr))),DURCHSCHNITT_SIGN,alltrim(str(schnitt)),"*",;
            alltrim(str(abweichung))+"% = Max:",alltrim(str(maxmenge))
        endif

        // jetzt schauen welche zu arg abweichen
        if ARTIKEL->(recno())== aktRec
          ? space(len(out(ARTIKEL->ArtNr))),"Mindest-Mengen:"
          Spalte:=26
        endif
        for each m in mengen
          if m<=maxMenge
            if ARTIKEL->(recno())== aktRec
              ?? alltrim(str(m))
              spalte += len(alltrim(str(m)))
            endif
            maxFound:=max(maxFound,m)
          else
            if ARTIKEL->(recno())== aktRec
              ?? "("+alltrim(str(m))+")"
              spalte += len(alltrim(str(m)))+2
            endif
          endif
          // Umbruch?
          if ARTIKEL->(recno())== aktRec .and. spalte > 70
            ? space(len(out(ARTIKEL->ArtNr)))
            spalte:=len(out(ARTIKEL->ArtNr))
          endif
        next

        if ! rec_lock(5)
          TroubleEmail("Artikel nicht verf�gbar in MindestBestellMenge: "+mArtNr)
        else
          if ARTIKEL->(recno())== aktRec
            ? FETT_AN,"-> Mindest-Bestellmenge: "+alltrim(str(maxFound)),FETT_AUS
          endif
          replace ARTIKEL->MinOrderS with maxFound
          dbcommit()
          dbunlock()
        endif
      endif
    next
  endif

  drucker("OFF")

  select Artikel
  go (aktRec)
  restscreen(,,,,s01)
return
/** eop */

/** sucht rekursiv alle OberArtikel mit VK, die bereits verkauft worden sind */
static procedure rekOberArtikel(alleOberArtikel,mArtNr)
LOCAL aktRec

  dbseek(mArtNr)
  do while .not. AVPOST->(eof()).and. AVPOST->ArtNr==mArtNr
    if AVPOST->Art=="M"
      ARTIKEL->(dbseek(AVPOST->AvNr))
      if getArtikelArt()$"XFM" .and. ARTIKEL->Preis1>0 // .and. ARTIKEL->verkauft>0
        if ! hb_HHasKey( alleOberArtikel, AVPOST->AvNr)
          alleOberArtikel[AVPOST->AvNr]:=.t.
        endif
      endif

      // suche OberArtikel
      aktRec:=AVPOST->(recno())
      rekOberArtikel(@alleOberArtikel,AVPOST->AvNr)
      AVPOST->(dbgoto(aktRec))
    endif
    skip
  enddo
return



/** liefert ob ein Feld leer ist bzw nur aus "  -  -" besteht */
function realEmpty(s)
return myEmpty(s) .or. empty(strtran(s,"-",""))

/** Dubletten Check St�ckliste */
procedure checkDublettenAvPost()
LOCAL mAvNr,mArtNr,mBez,myArt,protName, erst:=.f.

  cls
  Titel("Dubletten Check St�ckliste")

  Protokoll(INIT_P,"Dubletten - St�ckliste")
  if open("AvPost","Artikel")
    select AvPost
    AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr

    for each myArt in {"M"}
      erst:=.t.
      set filter to AVPOST->Text=="A" .and. AVPOST->Art==myArt .and. left(AVPOST->AvNr,1) <> "E"
      go top
      do while ! AVPOST->(eof())
        mArtNr:=AVPOST->ArtNr
        do while ! AVPOST->(eof()) .and. mArtNr == AVPOST->ArtNr
          mAvNr:=AVPOST->AvNr
          @ 12,20 say "Pr�fe: "+myArt+" "+AVPOST->ArtNr
          skip
          if mArtNr == AVPOST->ArtNr .and. mAvNr == AVPOST->AvNr .and.;
            ! mAvNr $ "4105510  /3000590  "
            if erst
              if myArt == "M"
                Protokoll(PROTOKOLL,"Material-St�cklisten:")
              else
                Protokoll(PROTOKOLL,"Werkzeug-St�cklisten:")
              endif
              erst:=.f.
            endif
            ARTIKEL->(dbseek(mAvNr))
            mBez:=ARTIKEL->Bez1
            ARTIKEL->(dbseek(mArtNr))
            Protokoll(PROTOKOLL,mAvNr+" "+AVPOST->Art+" "+mBez+" -> "+mArtNr+" "+ARTIKEL->Bez1+;
              " ist doppelt.")
            skip
          endif
        enddo
      enddo
    next

    if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
      protName:=Protokoll(P_FILE_NAME)
      email(MAIN_EMAIL,"Fehler: Dubletten in St�ckliste.","Bitte pr�fen",protName)
    endif
    close data
  endif
  cls

return
/** eof */

/** Avaus Check St�ckliste */
procedure checkAvAus()
LOCAL protName

  cls
  Titel("AVAUS Check St�ckliste")

  Protokoll(INIT_P,"AvAus - St�ckliste")
  if open("AvPost","AvAus","Artikel")
    select AvPost
    go top
    do while ! AVPOST->(eof())
      ARTIKEL->(dbseek( AVPOST->AvNr ))
      if ARTIKEL->(eof())
        Protokoll(PROTOKOLL,AVPOST->AvNr+" Artikel nicht gefunden.")
      else
        AVAUS->(dbseek( ARTIKEL->ArtNr ))
        if AVAUS->(eof())
          Protokoll(PROTOKOLL,AVPOST->AvNr+" AVAUS St�ckliste nicht gefunden.")
        endif
      endif
      @ Maxrow(),30 say AVPOST->AvNr
      skip
    enddo

    if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
      protName:=Protokoll(P_FILE_NAME)
      email(MAIN_EMAIL,"Fehler: AvAus in St�ckliste.","Bitte pr�fen",protName)
    endif
    close data
  endif
  cls

return
/** eof */



/** kopiert rekursiv die ben�tigten Baugruppen zu allen Auftragsposten
* des Artikel nach Auftrag.dbf, merkt sich vorkommende Artikel und
* verbrauchten Lagerbestand in M_Mehrf.dbf
*/
procedure rekAufBest(mArtNr , tiefe, faktor)
LOCAL merkSatz
LOCAL parents, p

  default faktor:=1

  ARTIKEL->(dbseek(mArtNr))

  // drucke UnterArtikel
  if ARTIKEL->disponiert<>0 .or. ! empty( ARTIKEL->MatArtNr ) // .or. len( altParents ) > 0

    // merke vorkommenden Artikel Datensatz
    select M_Mehrf
    dbseek(ARTIKEL->ArtNr)
    if M_MEHRF->(eof())
      add_rec(0)
      replace M_MEHRF->ArtNr with ARTIKEL->ArtNr
      // INFO: hier vom aktuellen Artikel ohne ARTIKEL->Disponiert
      replace M_MEHRF->LageBest with Max(ARTIKEL->LageBest,0)
    endif

    // kopiere zugeh�r. AuftragsNr.
    Select AufPost
    AUFPOST->(dbseek(mArtNr))
    do while ! AUFPOST->(eof()) .and. AUFPOST->ArtNr==mArtNr
      AUFAUS->(dbseek(AUFPOST->AufNr))
      if (AUFAUS->erledigt<>"J" .or. AUFAUS->Erledigt=="O") .and. AUFPOST->AufArt $ "KRVD" .and.;
        AUFAUS->InvKZ<>"J" .and. AUFPOST->GeliefGes < AUFPOST->Menge
        // merke Auftrag
        select Auftrag

        loca for trim(AUFTRAG->tempStr)==trim(str(AUFPOST->ABPostNr))
        if AUFTRAG->(eof())
          add_rec(0)
          overwrite("AufPost")
          // merke Satz.Nr. um doppelte Auflisting bei Rekursion zu vermeiden
          replace AUFTRAG->tempStr with trim(str(AUFPOST->AbPostnr))
        endif
        select AufPost
      endif

      skip
    enddo

    // drucke OberArtikel
    select AvPost
    AVPOST->(dbseek(MArtNr))
    do while ! AVPOST->(eof()) .and. AVPOST->ArtNr==MArtNr
      if AVPOST->Text=="A"
        merkSatz:=AVPOST->(recno())
        rekAufBest( AVPOST->AvNr , tiefe+1, faktor * AVPOST->Menge)
        AVPOST->(dbGoto((merkSatz)))
      endif
      AVPOST->(dbskip())
    enddo

  endif

  // drucke alternatives Material (OberArtikel), if applicable
  // Neu 25.7.16
  if ! empty( parents:=StueckListe():new(MArtNr):getAlternativeParents() )
    for each p in parents
      rekAufBest( p:ArtNr , tiefe+1, faktor * p:Menge)
    next
  endif

return
/** eof */


/** liefert die aktuelle Material Bemerkung als Array zur�ck.
  * Auch Leerzeichen, falls diese nicht am Ende sind */
FUNCTION getStkListBemMaterial()
LOCAL i , tempVar
LOCAL result:={}
  for i:=4 to 1 step -1
    tempVar="AVAUS->Bem" + str( i , 1 )
    if ! empty( &tempVar ) .or. len( result ) > 0
      HB_AIns( result , 1 , &tempVar , .t. )
    endif
  next
return result
/** eof */

/** liefert die aktuelle Werkzeug Bemerkung als Array zur�ck.
  * Auch Leerzeichen, falls diese nicht am Ende sind */
FUNCTION getStkListBemWerkzeug()
LOCAL i , tempVar
LOCAL result:={}
  for i:=4 to 1 step -1
    tempVar="AVAUS->WKZ_Bem" + str( i , 1 )
    if ! empty( &tempVar ) .or. len( result ) > 0
      HB_AIns( result , 1 , &tempVar , .t. )
    endif
  next
return result
/** eof */

  /** pr�ft den DATEV Nummern-Kreislauf und das zugeh. Land
  *
  * 10000 - 49999 Kunden in Deutschland
  * 50000 - 79999 Kunden au�erhalb Deutschland
  *
  * ab 80000 Lieferanten, wird hier nicht gepr�ft
  */
FUNCTION checkDatevNr(mKundNr,mLand,warn)
  default warn:=.t.
  mLand:=trim(mLand)

  if left(mKundNr,1) $ "1234"
    if mLand <> "DE" .and. mLand <> "D"
      if warn
        Error(ACHTUNG+"DATEV Nummern 10000 - 49999 nur f�r Kunden in Deutschland zugelassen.||"+;
          "         Bitte Nummer ("+mKundNr+") oder Land ("+mLand+") anpassen.",.t.)
      endif
      return .f.
    endif
  elseif left(mKundNr,1) $ "567"
    if (mLand == "DE" .or. mLand == "D") .and. empty(right(mKundNr,2))
      if warn
        Error(ACHTUNG+"DATEV Nummern 50000 - 79999 nur f�r Kunden au�erhalb Deutschlands zugelassen.||"+;
          "         Bitte Nummer ("+mKundNr+") oder Land ("+mLand+") anpassen.",.t.)
      endif
      return .f.
    endif
  else
    if warn
      Error(ACHTUNG+"nur DATEV Nummern von 10000 - 79999 zugelassen.||"+;
        "         Bitte Nummer ("+mKundNr+") oder Land ("+mLand+") anpassen.",.t.)
    endif
    return .f.
  endif
Return .t.
/** eof */


  /** Exportiert die EU Exporrt eines Monats nach xml
  *
  * analog: EU_Umsatz() Liste
  */
Procedure EuUmsatzIntraStatExport(Abfrage,testOnly,Datum)
LOCAL intraExport
LOCAL myDate , count:=0
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL betr,nr
LOCAL ohneWarenNr:="" , ohneGewicht:="" , body, pfad
LOCAL gesNetto:=0.00,gespos:=0,pos:=0
LOCAL Monat, jahr,myName, Ende:=.f.
LOCAL printBuffer, wert , listDateiName, i
LOCAL M_KundNr,M_KurzName,M_ReaDat,M_RechNr,rab
LOCAL text, xmlDateiName, objErr
LOCAL declaration, frachtKosten, menge // , gesamtKosten
LOCAL cMonat, Ausgabe, M_UStNr

  default Abfrage:=.t.
  default testOnly:=.f.

  cls
  titel("Umsatzliste EU - Intra.Stat. XML-Datei")

  if ! Abfrage // automat. nachts um 2Uhr, also w�hle den Vortag als Datum

    if Datum == nil
      myDate:=getUser():date
      jahr:=year(myDate)
      Monat:=month(myDate)
      do while month(myDate)==month(getUser():date) .and. year(mydate)==year(getUser():date)
        myDate--
      enddo
      Monat-- // Vormonat
      if Monat == 0
        Monat = 12
        jahr--
      endif
    else
      myDate:=Datum
      jahr:=year(myDate)
      Monat:=month(myDate)
    endif
    myName:="EU-Umsatz-"+left(dtos(myDate),6)
    Drucker("PDF",myName)
    cMonat:=myCMonth(ctod("01."+str(monat,2)+".80"))
  else // mit Abfrage

    myDate:=getUser():date
    jahr:=year(myDate)
    Monat:=month(myDate)

    do while ! Ende
      @ 5,28 to 20,46
      Message("Bitte Monat ausw�hlen.           @ESC@=Ende")
      for i:=1 to 12
        @ 5+i,30 prompt chr(64+i)+". "+left(myCMonth(ctod("01."+str(i,2)+".80"))+space(10),10)
      next
      @ 5+i+1,30 prompt "Y. Jahr  "+str(jahr,4)
      Menu to Monat
      if Monat==13 // Jahr wechseln
        message("Neues Jahr eingeben.")
        @ 5+i+1,30 say "                "
        @ 5+i+1,30 say "   Jahr:" get Jahr picture "9999"
        read
        loop
      endif
      Ende:=.t.
    enddo
    if Monat==0 // ESC
      cls
      close data
      RETURN
    endif

    myName:="EU-Umsatz-" + str(jahr,4) + right("00"+alltrim(str(Monat,2)),2)
    myDate:=ctod( "01." + right("00"+alltrim(str(Monat,2)),2) + "." + str(jahr,4) )
    cMonat:=myCMonth( myDate )

    Ausgabe:=Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?","DBP","D")
    if ABBRUCH
      cls
      RETURN
    endif
    do case
    case Ausgabe == "B"
      Drucker("BS")
    case Ausgabe == "D"
      Drucker("ON",myName,,.f.,PDF_NO_CONFIRM)
    case Ausgabe == "P"
      Drucker("PDF",myName,,.f.,PDF_NO_CONFIRM)
    endcase

  endif

  Message("Datei wird sortiert.   Bitte warten...")
  if ! open("Rechaus","Kunden","Rechpost","Artikel","IntraStat","Land")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /* "Filter" setzten */
  SELECT Rechpost
  index on RECHPOST->RechNr tag TEMP_IND2 TEMPORARY ADDITIVE for ;
    RECHPOST->IntraStat <> "X"

  SELECT Rechaus
  index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    RECHAUS->EG=="J" .and. month(RECHAUS->readat)=Monat .and. year(RECHAUS->readat)=Jahr;
    .and. empty( RECHAUS->STORNO_NR ).and. RECHAUS->AufArt <> "G" ;
    .and. ! ( RECHAUS->MwSt > 0 .or. left(RECHAUS->V_KundNr,5) == MIKI_NR )

  // .and. len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE

  Message("Liste wird erstellt.  Bitte warten....")

  BEGIN SEQUENCE // krit. Bereich

    intraExport:=IntraStat():new( Monat,Jahr )
    printBuffer:=printBuffer():new()

    go top
    do while .not. RECHAUS->(eof()) .and. ! stop
      seite=seite+1
      zeile:=0
      ? "Miki Plastik GMBH  * EU Umsatz "+str(Monat,2)+"/"+str(jahr,4)+" *   vom:",;
        getUser():date,space(6),"Seite :",str(seite,3)
      ? '----------------------------------------------------------------------------------------'+;
        '--'
      ? 'KD-Nr.   Name                           RE-Datum -Nummer  USt.Id.Nr           Netto '+;
        '(Euro)'
      ? '----------------------------------------------------------------------------------------'+;
        '--'
      do while .not. RECHAUS->(eof()) .and.zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

        // -> jetzt im filter / index on
        // bei Werkzeug was bei Miki bleibt -> nicht in Liste
        // if RECHAUS->MwSt > 0 .or. left(RECHAUS->V_KundNr,5) == MIKI_NR
        // skip
        // loop
        // endif

        // noch Reste vom Umbruch �brig?
        if printBuffer:getNumLines() > 0
          getUser():getCurrentPrintJob():printBuffer(printBuffer)
          zeile += printBuffer:getNumLines()
          printBuffer:=printBuffer():new()
          gespos++
          skip
          loop
        endif

        // ** aufsummieren des gel. Betrags
        betr=0
        M_KundNr:=RECHAUS->V_KundNr
        M_KurzName:=setLength( RECHAUS->V_Name , 30 )
        M_ReaDat:=RECHAUS->ReaDat
        M_RechNr:=RECHAUS->RechNr
        M_UStNr:=RECHAUS->IdentNr

        SELECT RechPost
        RECHPOST->(dbseek( RECHAUS->RechNr ))
        nr=RECHPOST->rechnr

        // summiere Fracht auf
        frachtKosten:=0
        // gesamtKosten:=0
        menge:=0
        do while nr=RECHPOST->rechnr .and. .not. RECHPOST->(eof())
          wert:=ROUND( RECHPOST->Preis * RECHPOST->Gelief / IIF(RECHPOST->PE$"Hh",100,1) , 2)

          // Ausnahme Dienstleistungen
          ARTIKEL->(dbseek( RECHPOST->ArtNr ))
          // if getArtikelArt() $ "D"
          // skip
          // loop
          // endif

          // Rabatt abziehen
          IF RECHPOST->rabatt<>0.0
            rab:=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            wert=wert-rab
          endif

          if len(alltrim(RECHPOST->ArtNr)) <= FRACHT_LAENGE
            frachtKosten += wert
          else
            //gesamtKosten += wert
            menge += RECHPOST->Gelief
          endif
          skip
        enddo

        // jetzt nochmal: drucken und xml erzeugen
        RECHPOST->(dbseek( RECHAUS->RechNr ))
        do while nr=RECHPOST->rechnr .and. .not. RECHPOST->(eof())

          // Fracht wird nicht separat ausgewiesen
          // Dienstleistungen ebenso nicht
          ARTIKEL->(dbseek( RECHPOST->ArtNr ))
          if len(alltrim(RECHPOST->ArtNr)) <= FRACHT_LAENGE // .or. getArtikelArt() $ "D"
            skip
            loop
          endif

          // Wert je Posten
          wert:=ROUND( RECHPOST->Preis * RECHPOST->Gelief / IIF(RECHPOST->PE$"Hh",100,1) , 2)

          // Rabatt
          IF RECHPOST->rabatt<>0.0
            rab:=ROUND(wert*ROUND(RECHPOST->Rabatt,2)/100,2)
            wert=wert-rab
          endif

          // FrachtKosten prozentual zuschlagen

          // anhand der Kosten
          // wert += round( FrachtKosten * wert / gesamtKosten , 2 )

          // anhand der Menge
          wert += round( FrachtKosten * RECHPOST->Gelief / menge , 2 )

          betr+= wert
          // if Details == "J", jetzt immer mit details
          ->? space(4),KLEIN_AN,str(RECHPOST->Gelief,7),"x",out(RECHPOST->ArtNr),RECHPOST->komm1,space(7),;
            transStr(wert,11,2),KLEIN_AUS
          ARTIKEL->(dbseek( RECHPOST->ArtNr ))
          ->? space(4),KLEIN_AN,space(9),ARTIKEL->WarenNr,space(1),RECHPOST->Komm2,KLEIN_AUS
          // endif

          // pr�fe Warennr und Gewicht
          INTRASTAT->( dbseek( ARTIKEL->WarenNr ) )
          if INTRASTAT->(eof())
            ohneWarenNr += RECHPOST->Artnr+" "+RECHPOST->Komm1+"|"
            INTRASTAT->( dbseek( MIKI_WAREN_NUMMER ) )
          endif
          if ARTIKEL->Gewicht <= 0
            ohneGewicht += RECHPOST->Artnr+" "+RECHPOST->Komm1+"|"
          endif

          // now create intra stat xml entry
          count++
          declaration:=Declaration()
          declaration:setArtNr( ARTIKEL->ArtNr )
          declaration:setMonat( month( RECHAUS->ReaDat ))
          declaration:setJahr( year( RECHAUS->ReaDat ))
          declaration:setWarenNummer( INTRASTAT->WarenNr )
          declaration:setUStId( RECHAUS->IdentNr )
          declaration:setText(left( alltrim(INTRASTAT->Text1) + alltrim(INTRASTAT->Text2) , 80 ))
          declaration:setLand(left(RECHAUS->V_LAND,2))
          declaration:setGewicht( round( ARTIKEL->Gewicht * RECHPOST->Gelief , 0 ) )
          // FIXME: Fracht muss umgerechnet werden
          declaration:setSumme( round( wert ,0 ) )

          intraExport:addDeclaration(declaration)

          // n�chster Rechnungsposten
          skip
        enddo
        select Rechaus

        // Zuschlag & Sonderrabatt
        If RECHAUS->So_Rabatt > 0.0
          wert -= ROUND((wert-frachtkosten)*ROUND(RECHAUS->So_Rabatt,2)/100,2)
        endif
        If RECHAUS->Zuschlag > 0.0
          wert += ROUND((wert-frachtkosten)*ROUND(RECHAUS->Zuschlag,2)/100,2)
        endif

        // nur falls Posten gedruckt wurden
        if printBuffer:getNumLines() > 0

          // jetzt addieren
          gespos++
          gesnetto += betr

          // Details zu Kunden drucken
          KUNDEN->(dbseek( M_KundNr ))
          printBuffer:insertTopTextLine( KUNDEN->IdentNr )
          printBuffer:insertTopTextLine( {;
            KdOut(M_KundNr),M_KurzName,M_ReaDat,space(1),M_RechNr,space(0),M_UStNr,transStr( betr , 12,2 ) })
          ->? // Leerzeile nach jeder Rechnung

          // markieren, das an BA gemeldet
          rec_lock(0)
          replace RECHAUS->IntraStat with "J"
          dbcommit()
          dbunlock()

          // passen die Details noch auf die aktuelle Seite?
          if zeile + 1 + printBuffer:getNumLines() >= DRUCKER->laenge - LISTE->Unt_Rand
            gespos--
            exit // -> noch mal neu auf n�chster Seite
          endif

          getUser():getCurrentPrintJob():printBuffer(printBuffer)
          zeile += printBuffer:getNumLines()
          printBuffer:=printBuffer():new()

        endif

        Stop:=stop_key()
        skip

      enddo

      // falls leer, Hinweis drucken, damit Liste auch erzeugt wird
      if count == 0
        ?
        ? "Keine Posten ins EU Ausland geliefert."
        ? COLOR_RED,"HINWEIS: XML Datei muss trotzdem hochgeladen werden",COLOR_DEFAULT
      endif

      if eof()
        text:="Gesamt-Summe: "
      else
        text:="Zwischensumme:"
      endif
      ? space(56),'=================================='
      ? padr( text, 54) , str(gespos,4) , 'Position(en)',transstr(gesnetto,13,2),"Euro"
      ? space(56),'=================================='
      Zeile:=FormFeed(Zeile,Seite)
    enddo

    // testonly: create the XML if all tests are ok
    if testonly .and. empty(ohneWarenNr) .and. empty(ohneGewicht)
      testonly:=.f.
      // mark regular EU Umsatz as done
      Umgebung( WRITE_ALL )
      select Crontab
      locate for trim(CRONTAB->CRONName) == "EU_UMSATZ" .and. CRONTAB->Monat == Monat
      if ! CRONTAB->(eof())
        rec_lock(0)
        replace CRONTAB->Datum with getUser():date
        dbcommit()
        dbunlock()
      endif
      Umgebung( LOAD )
    endif

    // Now save the file
    if ! testOnly
      mkmydir(INTRA_STAT_PFAD)
      xmlDateiName:=INTRA_STAT_PFAD+BACKSLASH + intraExport:getEnvelopeId(Monat,Jahr) + ".xml"
      intraExport:dump(xmlDateiName)
    endif

    // Drucker("Off")
    getUser():getCurrentPrintJob():endDoc()
    listDateiName:=getUser():getCurrentPrintJob():pdfFullFileName
    getUser():setCurrentPrintJob(NIL)

  RECOVER USING objErr
    Error("Fehler Intra.Stat. Export: "+objErr:description + SCHWERER_FEHLER)
    // we bail out
    cls
    return
  END SEQUENCE

  close data

  // email senden
  if listDateiName <> nil // Abfrage $ "PD"

    // Fehler enthalten?
    body:=""
    if empty(ohneWarenNr)
      body += "Alle Artikel mit Waren-Nummer:   OK|"
    else
      body += "Artikel ohne oder mit falscher Waren-Nummer:|" + ohneWarenNr+"|"
    endif
    if empty(ohneGewicht)
      body += "Alle Artikel mit Gewichtsangabe: OK|"
    else
      body += "Artikel ohne Gewicht:|" + ohneGewicht
    endif

    if testOnly
      email(MAIN_EMAIL,;
        "Zur Pr�fung vorab: EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4),;
        "EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4)+"||Anzahl Posten:"+str(count)+"||"+body,;
        {listDateiName},.f.,.t.)
    else

      // kopiere Datei nach Verzeichnis von H. Weiland und per email schicken
      // at home: "c:\schrott\Intrastat XML-Datei"
      pfad:=if(AT_HOME , INTRASTAT_VERZ_HOME , INTRASTAT_VERZEICHNIS) + BACKSLASH + ;
        str(jahr,4) + BACKSLASH + cMonat
      mkmydir( pfad )
      fileCopy( xmlDateiName , pfad + BACKSLASH + getFileName( xmlDateiName ) )
      fileCopy( listDateiName , pfad + BACKSLASH + getFileName( listDateiName ) )

      // // FIXME: email not working at home :(
      // if AT_HOME
      // Drucker("PDF")
      // qout("WICHTIG: Intra.Stat. XML-Datei / EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4),
      // "EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4)+"||Anzahl Posten:"+str(count)+"||"+body)
      // drucker("OFF")
      // else
      email(MAIN_EMAIL,;
        "WICHTIG: Intra.Stat. XML-Datei / EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4),;
        "EU-Umsatzliste "+ cMonat + " " + str(year(myDate),4)+"||Anzahl Posten:"+str(count)+"||"+body,;
        {listDateiName,xmlDateiName},.f.,.t.)
      //endif

      if Abfrage
        if day( getUser():date ) >= 5 // bereits automat. per Crontab geschickt
          Message("XML Datei wurde per Email gesendet.   @Taste@","@")
        else
          Error("XML Datei per Email gesendet.||"+;
            "Wenn Sie am 5. des Monats die Datei nochmal per Email erhalten wollen,|"+;
            "geben Sie bitte J ein.",ERR_NO_WAIT)
          if Message("Datei am 5. des Monats nochmal versenden?","JN") <> "J"
            if open("Crontab")
              LOCA for alltrim(CRONTAB->CRONNAME) == "EU_UMSATZ" .and.;
                CRONTAB->Monat == month( myDate )
              if CRONTAB->(eof()) .or. ! rec_lock( 5 )
                TroubleEmail("Crontab Eintrag EU_Umsatz nicht gefunden.")
              else
                replace CRONTAB->datum with getUser():date
              endif
              dbcommit()
              dbunlock()
              close data
            endif
          endif
        endif
      endif

    endif
  endif

  cls
return
/** eop */

/* erfassen und anzeigen der Emails je Kunde */
PROCEDURE EmailKunden(mKundNr , edit)
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE)

  if ! open( "Kunden","Email","EmailTemp")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  // kopiere alle Emails
  select EmailTemp
  zap
  EMAIL->(dbseek(MKundNr))
  append("Email",{ || MKundNr==EMAIL->KundNr})

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=11 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-2 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_LM]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->EMAILTEMP->KundNr:=MKundNr,_FIELD->EMAILTEMP->Druck:="J",;
    _FIELD->EMAILTEMP->InfoFlag:="N"}
  aKopf[EDIT_INDEX_FELD]:={ || empty(EMAILTEMP->Art) .or. empty(EMAILTEMP->Email) }
  aKopf[EDIT_GESPERRT]:="K"
  if ! edit
    aKopf[EDIT_GESPERRT]+="�ZLNE"
  endif
  aKopf[EDIT_DRAW_FRAME]:="EMail - Adressen"

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  // Lieferanten-Nr.
  aSpalte[EDIT_NAME]:="Art"
  aSpalte[EDIT_NAME_GET]:="EMAIL->Art"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer $ ;
    EMAIL_AUFTRAG+EMAIL_BEISTELL+EMAIL_RECHNUNG+EMAIL_LIEFERSCHEIN+EMAIL_SPEDITION+EMAIL_GBS}

  aSpalte[EDIT_MESSAGE]:="Email-Ausl�ser / Art eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Email"
  aSpalte[EDIT_TITEL]:="Email"
  aSpalte[EDIT_MASKE]:="@S50"
  aSpalte[EDIT_BEFORE]:={ || MySetKey( K_F8 , {|p1,oGet| keyboardMail(oGet,p1)})}
  aSpalte[EDIT_AFTER]:={ |oGet| ("@" $ oGet:buffer .or. lastkey() == K_UP ) .and. ;
    MySetKey( K_F8 , NIL)}
  aSpalte[EDIT_UEBERTRAG]:=.t. // carry on
  aSpalte[EDIT_MESSAGE]:="Email-Adresse eingeben.        @F8@=Miki-Adresse   @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="memotran(InfoText,' ',' ')"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_MASKE]:=replicate("X",50)
  aSpalte[EDIT_POS_Y]:=1

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Druck"
  aSpalte[EDIT_TITEL]:="Druck"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_POS_X]:=46
  aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer $ "JN" .or. lastkey() == K_UP }
  aSpalte[EDIT_MESSAGE]:="Ausdruck gew�nscht? (@J@/@N@)"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Nummer"
  aSpalte[EDIT_TITEL]:="Nummer"
  aSpalte[EDIT_MASKE]:="99999"
  aSpalte[EDIT_BEFORE]:={ |oGet| nummerVor(oGet)}
  aSpalte[EDIT_AFTER]:={ |oGet| nummerNach(oGet) .or. lastkey() == K_UP }
  aSpalte[EDIT_MESSAGE]:="Anzahl der Ereignisse eingeben (0-9) oder @leer@=immer"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="InfoFlag"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_POS_X]:=0
  aSpalte[EDIT_AFTER]:={ |oGet| nachInfoText(oGet) }
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Email-Text versenden/�ndern? (@J@/@N@)"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  Edit(aFelder,aKopf)

  if aKopf[EDIT_CHANGED]
    /* schreibe Emails zur�ck */
    select Email
    EMAIL->(dbseek(MKundNr))
    do while ! EMAIL->(eof()) .and. MKundNr==EMAIL->KundNr
      rec_lock(0)
      delete
      EMAIL->(dbskip())
    enddo
    // h�nge neu an
    EMAILTEMP->(dbgotop())
    append("Emailtemp",{ || .t. })

    dbcommitall()
    dbunlockall()
  endif

  select EmailTemp
  zap

  MySetKey( K_F8 , NIL)
  Umgebung(LOAD)

RETURN
  /* EoF */

function keyboardMail(oGet)
  oGet:varput("")
  keyboard chr(K_HOME) + MAIN_EMAIL
return .t.
  /** eof */

static function nachInfoText(oGet)
LOCAL s01 , ant
LOCAL aktColor, text

  if oGet:changed
    if ! oGet:buffer $ "JN"
      return .f.
    endif
    if lastkey() == K_UP
      return .t.
    endif

    if oGet:Buffer == "J"

      /* Email Text bearbeiten */
      s01:=savescreen()
      aktColor:=setcolor(COLWIN)
      Fenster(12,1,21,77,"Email-Text")
      Message("Email-Text eingeben.      @ESC@=Ende")
      SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
      text:=MyMemoEdit(EMAILTEMP->InfoText,13,2,20,76, .t.)
      replace EMAILTEMP->InfoText with text
      replace EMAILTEMP->InfoOrder with HB_MD5(text)
      Set Key K_ESC to
      restscreen(,,,,s01)
      setcolor(aktColor)

    else
      ant:=Message("Email-Text @d@eaktivieren, @l@�schen oder @ESC@=Abbruch? (@D@/@L@/@ESC@)","DL";
        ," ")
      if ABBRUCH
        return .f.
      endif
      if ant == "L"
        replace EMAILTEMP->InfoText with ""
      endif
    endif
  else

    // auto open text for miki recipiernt
    if oGet:buffer == "J" .and. trim(EMAILTEMP->Email) = MAIN_EMAIL
      oGet:changed:=.t.
      return nachInfoText(oGet)
    endif
  endif

return .t.
/**eof */

static function nummerVor(oGet)
LOCAL aktSel:=alias()

  oGet:Name:="AUFNR"
  Message("AB-Nummer eingeben.     @F12@=Auswahl")

return .t.
/** eof */

static function nummerNach(oGet)
  if oGet:changed
    AUFAUS->(dbseek(oGet:buffer))
    if AUFAUS->(eof())
      Error(ACHTUNG+"Auftrag: " + oGet:buffer + " nicht vorhanden.")
      return .f.
    elseif AUFAUS->KundNr <> KUNDEN->KundNr
      Error(ACHTUNG+"Auftrag: " + oGet:buffer + " geht an falschen Kunden.")
      return .f.
    endif
  endif
return .t.
/** eof */

/**
  * using hb_ZipFile(), Ergebnis DateiName im Erfolgsfall
  */
Function autoBackupData(openWindow)
LOCAL aFiles, path , sources:={}
LOCAL myDat:=getUser():date , i
LOCAL compression:=9
LOCAL destDir:=hb_cwd() + "temp"
LOCAL zipName:=destDir + BACKSLASH + "miki-dat-"+getFileStyleDate()+".zip"

  default openWindow:=.t.

  trouble("backup",{"Wird gestartet."})

  Message("Datensicherung wird erzeugt.      Bitte warten...")

  for each path in { HAUPT , AV, BANK, BEST, ETI, FAKT , MAT , REPA , DAT_PHOENIX}
    // strip absolute path
    path:=substr( path , len(hb_cwd()) + 1 )

    aFiles:=directory( path + BACKSLASH + "*.dbf" )
    for i:=1 to len(aFiles)
      aadd( sources , path + BACKSLASH + aFiles[i,F_NAME] )
    next

    aFiles:=directory( path + BACKSLASH + "*" + MY_MEMO_EXTENSION )
    for i:=1 to len(aFiles)
      aadd( sources , path + BACKSLASH + aFiles[i,F_NAME] )
    next
  next

  mkmydir( destDir )
  if !;
    hb_ZipFile( zipName , sources , compression, {|cFile| Message("Compressing: "+;
    cFile)} ,.t.,nil,.t.,.t.)
    TroubleEMail("Backup fehlgeschlagen.")
    return nil
  endif

  if openWindow
    wapi_SHELLEXECUTE( 0, "open", destDir) // �ffnet Ordner
  endif
  trouble("backup",{"Beendet:"+zipName})

return zipName
/** eop */

/**
  * l�schte alle Backupdaten, die �lter sind als num Tage
  * liefert die Anzahl der gel�schten zur�ck
  */
Function deleteBackupData(num)
LOCAL aFiles, count:=0 , i
LOCAL destDir:=hb_cwd() + "temp"

  Message("Datensicherung wird aufger�umt.      Bitte warten...")

  aFiles:=directory( destDir + BACKSLASH + "*.zip" )
  for i:=1 to len(aFiles)
    if getUser():date - aFiles[i,F_DATE] > num
      ferase( destDir + BACKSLASH + aFiles[i,F_NAME] )
      count++
    endif
  next

return count
/** eop */

/** 
  * rekursiver Aufruf der Stueckliste -> speichert aller Beistellteile
  *
  * AVPOST muss vorher selektiert werden, so ist die Rekursion schneller
 */
Procedure BeistellRek(mArtNr,M_Menge,prefixArtikel,konsigKdNr)
LOCAL aktRec

  // if trim(mArtNr)="501750"
  // altd()
  // endif

  // BeiStellTeil merken
  // seit 11.5.2012 inkl. Top-Level Artikel, falls Beistellteil
  if (konsigKdNr == NIL .and. getArtikelArt()=="B") .or. (prefixArtikel <> NIL .and.;
    getArtikelArt()=="E" .and. left(ARTIKEL->ArtNr,len(prefixArtikel))==prefixArtikel) .or. (konsigKdNr <> NIL .and. getArtikelArt() $ "BE" .and. left(ARTIKEL->KonsigKdNr,len(konsigKdNr)) == konsigKdNr) // neu 20121211 Aufl�sung Honsel K-Lager
    select BEISTEMP // wird hier als temp. Datei zweckentfremdet
    dbseek(mArtNr)
    if eof()
      add_rec(0)
      replace BEISTEMP->ArtNr with mArtNr
      replace BEISTEMP->HArtNr with ARTIKEL->HartNr
      replace BEISTEMP->KundNr with ARTIKEL->KonsigKdNr
    endif
    replace BEISTEMP->Menge with BEISTEMP->Menge + M_Menge
    select AvPost
  endif

  AVPOST->(dbseek(mArtNr+"M"))
  do while ! AVPOST->(eof()) .and. mArtNr==AVPOST->AvNr .and. AVPOST->Art=="M" // nur Material !
    ARTIKEL->(dbseek(AVPOST->ArtNr))

    // neu seit 4.12.17 fliegen Beistellteile mit Menge 0 raus
    // H. Weiland hat teilw. einfach die Menge in der St�ckliste auf 0 gesetzt, s. z.B. 5019440

    /** rekursiver Aufruf */
    if len(alltrim(AVPOST->ArtNr)) > FRACHT_LAENGE .and. AVPOST->Menge > 0
      aktRec:=AVPOST->(recno())
      BeistellRek(AVPOST->ArtNr,AVPOST->Menge*M_Menge,prefixArtikel, konsigKdNr)
      AVPOST->(dbgoto(aktRec))
    endif
    AVPOST->(dbskip())
  enddo
return
/** EOP */

  /** pr�ft ob f�r die Art und den aktuellen Kunden eine Email Benachrichtigung gew�nscht ist.
  s. Taste E im Kundenstamm */
FUNCTION sendEmails( art , dateiName , optionaleKdNr, nurAnfrage )
LOCAL kdNr, bez, kurz, emails, nummer:="", abNummer
LOCAL attachments, extraText:=""
LOCAL suchKdNr , pdfInfo, subject , intro
LOCAL lastOrderMD5, emailSent:=.f.
LOCAL aktSel:=alias(), filename

  default nurAnfrage:=.f.

  if valtype( DateiName ) == "C"
    attachments:={ dateiName }
  elseif valtype( DateiName ) == "A"
    attachments:=dateiName
  endif

  switch art
  case EMAIL_AUFTRAG
    kdNr:=AUFAUS->KundNr
    kurz:=AUFAUS->KurzName
    nummer:=AUFAUS->AufNr
    abNummer:=AUFAUS->AufNr
    bez:="Auftrag"
    extraText:=strtran(getTranslation("AB.email.text",LAND->Sprache), BACKSLASH, MY_CR+MY_LF)
    exit

  case EMAIL_SPEDITION
    kdNr:=AUFAUS->KundNr
    kurz:=AUFAUS->KurzName
    nummer:=AUFAUS->AufNr
    abNummer:=AUFAUS->AufNr
    bez:="Abhol-Auftrag"
    exit

  case EMAIL_LIEFERSCHEIN
    if nurAnfrage
      kdNr:=AUFAUS->V_KundNr
      abNummer:=AUFAUS->AufNr
    else
      kdNr:=RECHAUS->KundNr
      kurz:=RECHAUS->KurzName
      nummer:=RECHAUS->RechNr
      abNummer:=RECHAUS->AufNr
    endif
    bez:="Lieferschein"
    extraText:=strtran(getTranslation("LS.email.text",LAND->Sprache), BACKSLASH, MY_CR+MY_LF)
    exit

  case EMAIL_BEISTELL
    if nurAnfrage
      kdNr:=AUFAUS->KundNr
      abNummer:=AUFAUS->AufNr
    else
      if optionaleKdNr <> nil
        extraText:="Beistellteile von Kunde: " + optionaleKdNr
      endif
      kdNr:=RECHAUS->KundNr
      kurz:=RECHAUS->KurzName
      nummer:=RECHAUS->RechNr
      abNummer:=RECHAUS->AufNr
    endif
    bez:="Beistellteil-Liste"
    exit

  case EMAIL_RECHNUNG
    if nurAnfrage
      kdNr:=AUFAUS->KundNr
      abNummer:=AUFAUS->AufNr
    else
      kdNr:=RECHAUS->KundNr
      kurz:=RECHAUS->KurzName
      nummer:=RECHAUS->RechNr
      abNummer:=RECHAUS->AufNr
      extraText:=strtran(getTranslation("rechnung.email.text",LAND->Sprache), BACKSLASH, MY_CR+;
        MY_LF)

      // Beistellteilliste hinzuf�gen
      pdfInfo:=pdfInfo():new( JOB_BEISTELL , alltrim(RECHAUS->RechNr)+"-"+;
        left(RECHAUS->KundNr,5) , .f. )
      filename:=pdfInfo:path + BACKSLASH + pdfInfo:getLocalizedName( LAND->Sprache ) + ".pdf"
      if file(filename)
        aadd( attachments , filename)
      endif

      // GBS hinzuf�gen
      pdfInfo:=pdfInfo():new( JOB_GELANG_BESCH , alltrim(RECHAUS->RechNr)+"-" +;
        JOB_RECHNUNG , .f. )
      filename:=pdfInfo:path + BACKSLASH + pdfInfo:getLocalizedName( RECHAUS->R_Sprache ) + ".pdf"
      if file(filename)
        aadd( attachments , filename)
      endif

    endif
    bez:="Rechnung"

    exit

  case EMAIL_GBS
    if nurAnfrage
      kdNr:=AUFAUS->KundNr
      abNummer:=AUFAUS->AufNr
    else
      kdNr:=RECHAUS->KundNr
      kurz:=RECHAUS->KurzName
      nummer:=RECHAUS->RechNr
      abNummer:=RECHAUS->AufNr
    endif
    bez:="Gelangens-Bescheinigung"
    exit

  otherwise
    troubleEmail("Email-Art "+toString(art)+" unbekannt.")
    select(aktSel)
    return ""

  endswitch

  if optionaleKdNr <> nil
    suchKdNr:=optionaleKdNr
  else
    suchKdNr:=KDNr
  endif

  // pr�fe auf Email-Versand
  select Email
  index on getEmailSortorder() tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for ! empty( EMAIL->Email )

  EMAIL->(dbseek( suchkdNr + art ))
  do while ! EMAIL->(eof()) .and. EMAIL->KundNr == suchkdNr .and. EMAIL->Art == Art
    lastOrderMD5:=EMAIL->InfoOrder
    intro:=""
    emails:=""
    do while ! EMAIL->(eof()) .and. EMAIL->KundNr == suchkdNr .and. EMAIL->Art == Art .and. ;
      lastOrderMD5 == EMAIL->InfoOrder

      // falls spez. Nummer hinterlegt, nur wenn diese �bereinstimmt (added 20180308)
      if empty(EMAIL->Nummer) .or. EMAIL->Nummer == abNummer
        emails += trim(EMAIL->Email) + ", "
        if EMAIL->InfoFlag == "J"
          intro:=EMAIL->InfoText
        endif
      endif

      EMAIL->(dbskip())
    enddo
    if ! empty(emails) .and. ! nurAnfrage
      // truncate last komma
      emails:=left(emails,len(emails)-2)
      if emails = MAIN_EMAIL
        subject:=" *INFO*"
      else
        subject:=" bitte weiterleiten."
        intro += "Bitte Anhang weiterleiten an:||"
      endif

      email(MAIN_EMAIL,bez+space(1)+nummer+subject,intro+"|"+;
        "Kd.Nr.: " + kdNr + "|"+;
        "Name..: " + kurz + "|"+;
        "EMails: " + emails + "|"+;
        extraText + "|"+;
        getEmailFooter() ,;
        attachments,.f.,.t.)

      if emailOnly( Art ) .and. ! emailSent // just once
        emailSent:=.t.
        Error("Info: "+bez+" wurde per Email versendet an:||      " + MAIN_EMAIL , .t.)
      endif
    endif

  enddo

  select(aktSel)
return if(empty(emails),"",bez + " an: " + left(emails,len(emails)-2))
    /** eop */

function getEmailSortorder()
LOCAL result:=EMAIL->KundNr+EMAIL->Art+EMAIL->InfoOrder
return result

  /** pr�ft ob f�r die Art und den aktuellen Kunden eine Email Benachrichtigung gew�nscht ist
  und liefert true wenn kein Ausdruck gew�nscht ist.
  s. Taste E im Kundenstamm */
function emailOnly( art )
LOCAL kdNr, aktRec:=EMAIL->(recno())

  switch art
  case EMAIL_AUFTRAG
    kdNr:=AUFAUS->KundNr
    exit

  case EMAIL_LIEFERSCHEIN
    kdNr:=RECHAUS->KundNr
    exit

  case EMAIL_RECHNUNG
    kdNr:=RECHAUS->KundNr
    exit

  case EMAIL_GBS
    kdNr:=RECHAUS->KundNr
    exit

  case EMAIL_BEISTELL
    kdNr:=BEISTEMP->KundNr
    exit

  case EMAIL_SPEDITION
    kdNr:=AUFAUS->KundNr
    exit

  endswitch

  // pr�fe auf Email-Versand
  EMAIL->(dbseek( kdNr + art ))
  if EMAIL->(eof()) // keine email hinterlegt
    EMAIL->(dbgoto(aktRec))
    return .f.
  endif

  do while ! EMAIL->(eof()) .and. EMAIL->KundNr == kdNr .and. EMAIL->Art == Art
    // wenn bei einer Email Druck == "J" hinterlegt, dann wird gedruckt
    if ! empty( EMAIL->Email ) .and. EMAIL->Druck == "J"
      EMAIL->(dbgoto(aktRec))
      return .f.
    endif
    EMAIL->(dbskip())
  enddo

  EMAIL->(dbgoto(aktRec))
return .t. // nur email gew�nscht, kein Druck
/** eop */

/** zeigt die Mat.KZ Texte des aktuellen Artikels an */
function zeigeMatText()
  if empty(ARTIKEL->MatKz)
    beep()
  else
    Umgebung( WRITE_ALL )
    if ! open("Mat_Kz")
      Error(TRY_AGAIN)
    else
      setcolor(COLWIN)
      MAT_KZ->(dbseek(ARTIKEL->MatKz))
      MKzDisp(.f.,.f.)
      Message("Bitte @Taste@ dr�cken","@")
    endif
    Umgebung( LOAD )
  endif

return .t.
/** eof */

/** zeigt den Artikel-Text des aktuellen Artikels an */
function zeigeArtikelText()
  if empty(ARTIKEL->Arttextnr)
    beep()
  else
    Umgebung( WRITE_ALL )
    if ! open("ArtText")
      Error(TRY_AGAIN)
    else
      setcolor(COLWIN)
      ARTTEXT->(dbseek(ARTIKEL->Arttextnr))
      ATeDisp(.f.,.f.)
      Message("Bitte @Taste@ dr�cken","@")
    endif
    Umgebung( LOAD )
  endif

return .t.
/** eof */

/*
*
* Anzeige kl. Taschenrechner um das Gewicht von x Artikeln zu berechnen
*/
Procedure calcGewicht()
LOCAL GetList:={}
LOCAL text1,text2
LOCAL tempValue:=1

  Umgebung( WRITE_ALL )

  EINHEIT->(dbseek(ARTIKEL->ME))
  text1:=alltrim(EINHEIT->Text)
  EINHEIT->(dbseek(ARTIKEL->ME2))
  text2:=alltrim(EINHEIT->Text)
  EINHEIT->(dbseek(ARTIKEL->ME))

  setcolor(COLWIN)
  Fenster(14,33,16,66,if(ARTIKEL->ME$"57" .or.;
    ARTIKEL->ME2$"57","Gewicht berechnen:","Umrechnen:" ))
  Message("Anzahl "+text1+" eingeben.")
  @ 15,35 get tempValue picture "999999.99"
  qqout(" " + text1 +" = " + alltrim( transstr(tempValue * ARTIKEL->ME_FAktor,9,4))+" "+text2 )
  read

  if ! ABBRUCH
    @ 15,51 say left(alltrim( str(tempValue * ARTIKEL->ME_FAktor,12,4)) +" "+text2 + space(12),12)
    Message("Bitte @Taste@ dr�cken","@")
  endif

  Umgebung( LOAD )
return
/** eof */

/** liefert die artnr einer Verpackung (2 Stellen) auf die richtige L�nge gepadded */
function getVerpackungArtNr(nr)
return space(4)+alltrim(nr) // FIXME: too hardcoded!
/** eof */

/** pr�ft auf veraltete AB-Posten
*/
Function AufausKonsistenzCheck2()
LOCAL count:=0, protName
  cls
  titel("Aufaus - KonsistenzCheck - Alte Posten")

  Protokoll(INIT_P,"Veraltete AB Posten - Konsistenzcheck AB.Nr.  Kd.Nr.   Name", "Art.Nr. "+;
    "Bezeichnung                                                                        Rest-Menge     KW ")

  if open("Inner","Aufpost","Aufaus")
    select AufPost
    set rela to AUFPOST->AufNr into Aufaus
    set filter to AUFAUS->erledigt<>"J" .and. len(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE ;
      .and. AUFPOST->Menge > AUFPOST->GeliefGes;
      .and. kwDiff(getCurrentKW(),AUFPOST->KW) < -9
    go top
    do while ! AUFPOST->(eof())
      Protokoll(PROTOKOLL, AUFPOST->AufNr +;
        space(3);
        +;
        AUFAUS->KundNr;
        +;
        space(1);
        +;
        AUFAUS->Kurzname;
        +;
        space(1);
        +;
        AUFPOST->ArtNr;
        +;
        space(1);
        +;
        AUFPOST->Komm1;
        + space(1) + str(AUFPOST->Menge - AUFPOST->GeliefGes,12,2) + space(3) + AUFPOST->KW )
      count++
      skip
    enddo

    // sende email?
    if count > 0
      Protokoll(P_CREATE_PDF)
      protName:=Protokoll(P_FILE_NAME)
      email(MAIN_EMAIL,"Fehler: Aufaus Konsistenzcheck:"+str(count,5),"Bitte pr�fen",protName)
    endif

  else
    email(MY_EMAIL,"Fehler: Aufaus Konsistenzcheck open")
  endif

  close data
return .t.
/** eop*/


/** pr�ft offene AB-Posten und schitk email, falls Liefertermin f�llig.
*/
Function OffeneABCheck()
LOCAL count:=0, protName
LOCAL header:="AB.Nr. Datum    Kunde                                 Art.Nr.    Bezeichnung                                  Menge      KW"
LOCAL posten
LOCAL mailText:=header + MY_CR+MY_LF + replicate("=",len(header)) + MY_CR+MY_LF

  cls
  titel("Offene ABs - f�llige Liefertermine")

  Protokoll(INIT_P,"Offene ABs - f�llige Liefertermine",header )

  if open("Aufpost","Aufaus")
    select Aufpost
    set rela to AUFPOST->AufNr into Aufaus
    set filter to AUFAUS->erledigt=="O" .and. len(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE ;
      .and. kwDiff(getCurrentKW(),AUFPOST->KW) <= 0
    go top
    do while ! AUFPOST->(eof())
      posten:=AUFPOST->AufNr;
        +;
        space(2);
        +;
        dtoc(AUFAUS->AufDat);
        +;
        space(1);
        +;
        AUFAUS->KundNr;
        +;
        space(1);
        +;
        AUFAUS->Kurzname;
        +;
        space(1);
        +;
        out(AUFPOST->ArtNr);
        + space(1) + AUFPOST->Komm1 + space(1) + str(AUFPOST->Menge,9,2) + space(3) + AUFPOST->KW
      Protokoll(PROTOKOLL, Posten)
      mailText += Posten + MY_CR+MY_LF
      count++
      skip
    enddo

    // sende email?
    if count > 0
      Protokoll(P_CREATE_PDF)
      protName:=Protokoll(P_FILE_NAME)
      email(MAIN_EMAIL,"Offene ABs - f�llige Liefertermine", mailText + "||Bitte pr�fen.",protName)
    endif

  else
    email(MY_EMAIL,"Fehler: Offene ABs Konsistenzcheck open")
  endif

  close data
return .t.
/** eop*/


/** pr�ft bei allen ABs die Summe der Posten mit der Gesamt-Summe �bereinstimmt
  * Sowie auf veraltetet AB-Posten
*/
Function AufausKonsistenzCheck()
LOCAL sNetto, fracht, wert
LOCAL treffer:={} , protName

  cls
  titel("Aufaus - KonsistenzCheck")

  Protokoll(INIT_P,"AB - Konsistenzcheck","AB.Nr.   Datum      Netto Posten      Netto AB     "+;
    "Differenz")

  if open("AufAus","Aufpost")
    select AufAus
    // alle ABs au�er K-Lager und Gutschrift, die sind immer 0 Nettowert
    set filter to ! AUFAUS->AufArt $ "GK" // .and. AUFAUS->Erledigt<>"J"
    go top
    do while ! AUFAUS->(eof())
      // if AUFAUS->AufNr == "25189"
      // altd()
      // endif
      select AufPost
      AUFPOST->(dbseek( AUFAUS->AufNr ))
      sNetto:=0
      fracht:=0
      do while ! AUFPOST->(eof()) .and. AUFPOST->AufNr == AUFAUS->AufNr
        wert:=round(AUFPOST->Preis*AUFPOST->Menge / if(AUFPOST->PE=="H",100,1),2)
        IF AUFPOST->rabatt<>0.0
          wert -= ROUND(wert*ROUND(AUFPOST->Rabatt,2)/100,2)
        endif

        // merke alles ab der 1. Fracht f�r Sonderrabatt
        if len(alltrim(AUFPOST->ArtNr))<=FRACHT_LAENGE .or. ;
          (AUFAUS->Aufdat < ctod("08.06.2017") .and. fracht > 0)
          fracht += wert
        endif

        sNetto += wert

        skip
      enddo

      // Sonderrabatt / Zuschlag
      if AUFAUS->AufArt<>"B" // bei Rahmenauftrag Budget Sonderrabatt nicht abziehen!
        If AUFAUS->So_Rabatt > 0.0
          sNetto -= ROUND((sNetto-fracht)*AUFAUS->So_RAbatt/100,2)
        endif
        If AUFAUS->Zuschlag > 0.0
          sNetto += ROUND((sNetto-fracht)*AUFAUS->Zuschlag/100,2)
        endif
      endif

      if round(sNetto,2) <> AUFAUS->Netto
        aadd( treffer , AUFAUS->AufNr )
        Protokoll(PROTOKOLL, AUFAUS->AufNr + space(3) + dtoc(AUFAUS->AufDat) + ;
          transstr(sNetto,15,2)+ transstr(AUFAUS->Netto,14,2) + ;
          transstr(sNetto - AUFAUS->Netto, 14,2))

        // Fix issue -> one email only
        select AufAus
        if rec_lock(5)
          replace AUFAUS->Netto with round(sNetto,2)
          dbcommit()
          dbunlock()
        endif

      endif
      select Aufaus
      skip
    enddo

    // sende email?
    if len(treffer) > 0
      Protokoll(P_CREATE_PDF)
      protName:=Protokoll(P_FILE_NAME)
      email(MY_EMAIL,"Fehler: Aufaus Konsistenzcheck:"+str(len(treffer),5),"Bitte pr�fen",protName)
    endif

  else
    email(MY_EMAIL,"Fehler: Aufaus Konsistenzcheck open")
  endif

  close data
return .t.
/** eop*/

/** pr�ft bei allen innerbetr. ABS ob die ABPostNr noch existiert
*/
Function InnerABKonsistenzCheck()
LOCAL count:=0 , protName

  cls
  titel("Inner - AB-PostNr - KonsistenzCheck")

  Protokoll(INIT_P,"Inner AB - Konsistenzcheck",;
    "Diese innerbetr. Auftr�ge haben eine nicht mehr g�ltige oder erledigte AB hinterlegt.",;
    "InnerNr.  Art.Nr.     AB.Nr.   AbPostNr   Erledigt",,,"InnerABKonsCheck")

  if open("Inner","Aufpost","Aufaus")
    select AufPost
    AUFPOST->(OrdSetFocus(5))
    select Inner
    go top
    do while ! INNER->(eof())
      if INNER->AbPostnr > 0 .and. empty(INNER->KonsCheck)
        AUFPOST->(dbseek( INNER->AbPostnr ))
        AUFAUS->(dbseek( INNER->AufNr ))
        if AUFPOST->(eof()) .or. AUFAUS->(eof()) .or. AUFAUS->Erledigt=="J"
          count++
          Protokoll(PROTOKOLL, INNER->InnerNr +;
            space(6);
            +;
            INNER->ArtNr;
            +;
            space(3);
            + INNER->AufNr + space(3) + + str(INNER->AbPostnr) + space(4)+AUFAUS->erledigt)
          if rec_lock(5)
            replace INNER->KonsCheck with "J"
            dbcommit()
            dbunlock()
          endif
        endif
      endif
      skip
    enddo

    INNER->(OrdSetFocus(3)) // inlFdnr
    select AufPost
    set rela to AUFPOST->AufNr into Aufaus
    AUFPOST->(OrdSetFocus(1))
    go top
    do while ! AUFPOST->(eof())
      if AUFAUS->erledigt <> "J" .and. len(alltrim(AUFPOST->ArtNr)) > FRACHT_LAENGE .and.;
        ! empty(AUFPOST->InLfdNr)
        INNER->(dbseek( AUFPOST->InLfdNr ))
        if INNER->(eof())
          count++
          if count > 1
            Protokoll(PROTOKOLL, "","Externe ABs mit Referenzen zu nicht mehr existenten inneren "+;
              "ABs:")
          endif
          Protokoll(PROTOKOLL, space(len(INNER->InnerNr)) +;
            space(6) + AUFPOST->ArtNr + space(3) + AUFPOST->AufNr + space(3) + AUFPOST->InLfdNr)
        endif
      endif
      skip
    enddo

    // sende email?
    if count > 0
      Protokoll(P_CREATE_PDF)
      protName:=Protokoll(P_FILE_NAME)
      email(MAIN_EMAIL,"Fehler: Inner/Aufaus Konsistenzcheck:"+;
        str(count,5),"Bitte pr�fen",protName)
    endif

  else
    email(MY_EMAIL,"Fehler: Inner/Aufaus Konsistenzcheck open")
  endif

  close data
return .t.
/** eop*/


/** pr�ft bei allen Kunden ob ein Kunden mit Versand-Land DE ohne EG Kennzeichen existiert
  * sowie auf D-Kunden ohne MwSt
  */
function KundenKonsistenzCheck()
LOCAL treffer:=0,protName
LOCAL ausnahmen:=HB_ATokens( getProperty("Miki.kunden.mwst.leer","") , ":" )

  cls
  titel("Kunden - KonsistenzCheck")

  if ! open("Kunden","Mwst_Kz")
    return .f.
  endif
  select Kunden

  Protokoll(INIT_P,"Kunden Konsistenzcheck", "KdNr.    Kurzname")

  // EG-Kennzeichen
  loca for KUNDEN->Land2 == DEUTSCH_LAND .and. KUNDEN->EG<>"D"
  do while ! KUNDEN->(eof())
    treffer++
    Protokoll(PROTOKOLL,KUNDEN->KundNr+ " " + KUNDEN->Kurzname + " V-Land:" + KUNDEN->Land2 + ;
      " EG:" + KUNDEN->EG)
    cont
  enddo

  // MwSt
  set rela to KUNDEN->MWST_KZ into MwSt_KZ
  loca for KUNDEN->Land2 == DEUTSCH_LAND .AND.;
    ( KUNDEN->MWST_KZ == "0" .or. empty( KUNDEN->MWST_KZ ))
  do while ! KUNDEN->(eof())
    if aScan( ausnahmen , KUNDEN->KundNr ) == 0
      treffer++
      Protokoll(PROTOKOLL, KUNDEN->KundNr+space(1)+KUNDEN->KurzName, space(len(KUNDEN->KundNr)+1)+;
        KUNDEN->Land2+space(1)+KUNDEN->PLZ2+space(1)+KUNDEN->Ort2+space(1)+;
        "MwSt: ";
        +;
        KUNDEN->MWST_KZ+space(1)+str(MWST_KZ->MwSt,5,2)+"%   angelegt am:"+dtoc(KUNDEN->crea_date))
    endif
    cont
  enddo

  Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")

  if treffer > 0
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Fehler: Kunden Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
  endif

  close data
return .t.
/** eop*/


/** liefert den Wert als String basierend auf der Anzahl der Nachkommastellen */
function getValueNachkomma(wert,laenge,ME)
LOCAL result:=wert
LOCAl aktSel:=alias()

  if open("Einheit")
    dbseek(ME)
    if ! eof()
      result:=str( wert, laenge ,EINHEIT->NACHKOMMA)
    endif
  endif
  select( aktSel )
return result
/** eof */

/** korrigiert fehlerhaften K-Lager-Bestand von Fremdteilen bei Miki (interne Beistellteile) */
Procedure KLagerInternKorrektur(quiet)
LOCAL kom

  Umgebung(WRITE_ALL)

  default quiet:=.t.

  Message("K-Lager Bestand wird neu berrechnet.    Bitte warten...")

  if ! quiet
    // K_Lager Korrektur nach Zuweisung KdKd bei nicht Honsel/VVG Kunden
    Protokoll(INIT_P,"Beistellteile K-Lager-Bestand Korrektur",;
      "Art.Nr.  Bezeichnung                              Alt           Neu     Differenz")

    backup("Artikel","KLager-Korrektur")
  endif


  if open( "Artikel" , "AvPost" )

    AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel

    select Artikel
    loca for getArtikelArt() == "B" // .and. ! empty( ARTIKEL->KonsigKdNr )
    do while ! ARTIKEL->(eof())

      kom:=KLagerInternBerechnen(ARTIKEL->ArtNr)

      if ! empty(kom) .and. ! quiet
        Protokoll( PROTOKOLL , kom)
      endif

      cont
    enddo
  endif
  if ! quiet
    Protokoll(P_CREATE_PDF)
  endif
  Umgebung(LOAD)

return
/** eop */

/** berechnet den K-Lager-Bestand von Fremdteilen bei Miki (interne Beistellteile) */
function KLagerInternBerechnen(mArtNr)
LOCAL diff,tempVal,kom:=""
LOCAL aktOrd:=AVPOST->(indexord())

  if ! empty(left(ARTIKEL->KonsigKdNr,5)) .and. getArtikelArt() == "B"

    AVPOST->(OrdSetFocus(2)) // UnterArtikel / Oberartikel

    select Artikel
    dbseek(mArtNr)

    // Details (Baugruppen etc.) zu Lagerbestand ermitteln
    Umgebung(WRITE_ALL)
    tempVal:=rekHonsBeiList(ARTIKEL->ArtNr,0,.f.)
    Umgebung(LOAD)

    if tempVal[BG_BESTAND_LG_MIKI] + tempVal[BG_BESTAND_LG_HONSEL] <> ARTIKEL->KonsigBest

      diff:=(tempVal[BG_BESTAND_LG_MIKI] + tempVal[BG_BESTAND_LG_HONSEL]) - ARTIKEL->KonsigBest

      kom:=ARTIKEL->Artnr + " "+ARTIKEL->Bez1+;
        transstr( ARTIKEL->KonsigBest,14,2) +; // aktueller K-Bestand
      transstr( tempVal[BG_BESTAND_LG_MIKI] + tempVal[BG_BESTAND_LG_HONSEL],14,2) + ;
        transstr( diff ,14 , 2 ) + "  Kd:" +ARTIKEL->KonsigKdNr

      if dbRLOCK() // rec_lock(5) w/o user interaction
        aendArtKbest( diff , WARAUS_KLAG_KORREKTUR)
        dbcommit()
        dbunlock()
      else
        kom += " Fehler: Datensatz gelockt."
      endif

    endif

    AVPOST->(OrdSetFocus( aktOrd ))
  endif

return kom
/** eop */

function runHighestExe( starte_bei,gesperrt )
LOCAL exeName:=getFileBaseName( exeName() )
LOCAL dir,newProg

  // remove trailing digit, if already is a 2nd versione.g. miki1.exe
  if isDigit( right( exeName ,1 ) )
    exeName:=left( exeName , len(exeName) -1 )
  endif

  dir:=directory( exeName + "?.exe")
  if len(dir) > 1
    // call highest name
    newProg:=dir[len(dir) , F_NAME]
    if newProg <> getFileName( exeName() )
      wapi_SHELLEXECUTE(,,newProg, starte_bei + " " + gesperrt )
      // myRun( newProg , CRONTAB_KEYWORD , .f. )
      return .t.
    endif
  endif
return .f.
/** eof */

/** summiert den Lagerbestand in der �bergeordneten Baugruppen des Artikels
  * nicht mehr rekursiv 5.10.2016
  * raus 29.8.2016: so lange AVPOST->Volatile=="J"
  * rein 1.3.2017:  so lange AVPOST->Volatile<>"N"
  * wieder rekursiv aber nur f�r F-Artikel: 22.2.2019
  *
  * Returns: Array mit {Bestand in Baugruppen, Anzahl vorkommender Baugruppen }
  */
function getOberBaugruppenBestand(mArtNr, rekursiv, tiefe)
LOCAL result:=0
LOCAL aktRec, count:=0, tempResult
LOCAL avpost_order:=AVPOST->(indexord())
LOCAL art_order:=ARTIKEL->(indexord())
LOCAL aktSel:=alias()
LOCAL avRec:=AVPOST->(recno())
LOCAL artRec:=ARTIKEL->(recno())

  // alles au�er Ersatzteil-listen
  if left(AVPOST->AvNr,1) == "E"
    return { 0 , 0 }
  endif

  default tiefe:=0

  // if tiefe == 1
  // return { 0 , 0 }
  // endif

  if getArtikelArt()=="X"
    return { 0 , 0 }
  endif

  default tiefe:=0

  // Umgebung(WRITE_ALL)

  ARTIKEL->(OrdSetFocus(1))

  AVPOST->(OrdSetFocus(2)) // ArtNr + AvNr
  select AvPost
  dbseek( mArtNr )

  do while .not. AVPOST->(eof()).and. AVPOST->ArtNr==mArtNr
    if AVPOST->Art=="M" .and. AVPOST->Text=="A" .and. left(AVPOST->AvNr,1)<>"E"// .and. AVPOST->Volatile <> "N"
      aktRec:=AVPOST->(recno())
      ARTIKEL->(dbseek( AVPOST->AvNr ))
      result += max(ARTIKEL->Lagebest,0) * AVPOST->Menge
      if getArtikelArt() $ "D"
        result += max(ARTIKEL->BestExt,0) * AVPOST->Menge
      endif
      count++
      if rekursiv
        tempResult:=getOberBaugruppenBestand( AVPOST->AvNr , rekursiv, tiefe+1 )
        result += tempResult[1]
        count += tempResult[2]
      endif
      AVPOST->(dbgoto( aktRec ))
    endif
    skip
  enddo

  // Umgebung(LOAD)
  ARTIKEL->(OrdSetFocus(art_order))
  AVPOST->(OrdSetFocus(avpost_order))
  ARTIKEL->(dbgoto( artRec ))
  AVPOST->(dbgoto( avRec ))
  select (aktSel)

return { Max(result,0) , count }
/** eof */


/** �ffnet im gleichen Fenster die Material St�ckliste des Artikels der in Zeige selektiert ist */
PROCEDURE aendStkList( ZeilenText , ZeigeData , art)
LOCAL mArtNr

  ignore ZeilenText

  mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]

  if ! myEmpty( MArtNr )

    Umgebung(WRITE_ALL)

    setcursor(DEUTE_MARKE)

    /* Relationen setzten */
    SELECT AvPost
    SET RELATION TO AVPOST->ME INTO Einheit, to AVPOST->AvNr INTO Artikel // auf OberArtikel
    select Artikel
    ARTIKEL->(OrdSetFocus(1))
    ARTIKEL->(dbseek( mArtNr ))

    keyboard chr(K_RETURN)
    Stk_Liste(art , mArtNr)

    Umgebung(LOAD)

  endif

return
/** eop */


/** liefert .t. wenn der aktuell selektierte Kunde eine Spedition mit SpedNr=Value hinterlegt hat */
function kundSpeditExists(value)
  KUNDSPED->(dbseek( KUNDEN->KundNr + value ))
return ! KUNDSPED->(eof())
/** eof */

/** liefert ein Array mit allen beim �bergebenen Kunden hinterlegten Speditionsnummern zur�ck */
function getKundSpedits(mKundNr)
LOCAL result:={}
LOCAL aktRec:=KUNDSPED->(recno())
  KUNDSPED->(dbseek( mKundNr ))
  do while ! KUNDSPED->(eof()) .and. KUNDSPED->KundNr == mKundNr
    aadd( result , KUNDSPED->SpedNr )
    KUNDSPED->(dbskip())
  enddo
  KUNDSPED->(dbgoto( aktRec ))
return result
/** eof */

/** liefert ein Array mit allen beim �bergebenen Kunden hinterlegten Kunden-Speditionsnummern zur�ck */
function getKundSpeditKdNrs(mKundNr)
LOCAL result:={}
LOCAL aktRec:=KUNDSPED->(recno())
  KUNDSPED->(dbseek( mKundNr ))
  do while ! KUNDSPED->(eof()) .and. KUNDSPED->KundNr == mKundNr
    if ! empty( KUNDSPED->SpedKdNr )
      aadd( result , alltrim(KUNDSPED->SpedKdNr) )
    endif
    KUNDSPED->(dbskip())
  enddo
  KUNDSPED->(dbgoto( aktRec ))
return result
/** eof */

/*
* erfassen und anzeigen der Zollstellen je Kunde
*/
FUNCTION KundZollstellen()
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE_ALL)

  if ! open( "KundZoll","ZollStelle","Kunden","KdZollTemp")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN("")
  endif

  select Kdzolltemp
  zap
  set relation to KDZOLLTEMP->ZollNr into ZollStelle

  /* hole alle Speditionen des Kundens */
  select KundZoll
  KUNDZOLL->(dbseek(KUNDEN->KundNr+KDSPEDTEMP->SpedNr))
  do while ! KUNDZOLL->(eof()) .and. KUNDZOLL->KundNr == KUNDEN->KundNr .and. ;
    KUNDZOLL->SpedNr == KDSPEDTEMP->SpedNr
    select Kdzolltemp
    add_rec(0)
    overwrite( "KundZoll" )
    select KundZoll
    skip
  enddo

  select Kdzolltemp
  aFelder:={}
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=9 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_LM]:=7 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"

  aKopf[EDIT_EXTRA_FKT]:={}
  // aadd(aKopf[EDIT_EXTRA_FKT],{ "A�","", { || bestkartEdit() } } )

  aKopf[EDIT_DRAW_FRAME]:="Zollstelle f�r Spedition: " + KDSPEDTEMP->SpedNr

  aKopf[EDIT_NEW_FKT]:={ || _FIELD->KDZOLLTEMP->KundNr:=KUNDEN->KundNr ,;
    _FIELD->KDZOLLTEMP->SpedNr:=KDSPEDTEMP->SpedNr}

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="ZollNr"
  aSpalte[EDIT_TITEL]:="Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oGet| zollNrNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Dienststellen-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Art"
  aSpalte[EDIT_NAME_GET]:="KDZOLLTEMP->Art"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MASKE]:="@K!"
  aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer $ "BELS�" }
  aSpalte[EDIT_MESSAGE]:="Art eingeben.         @F12@ = Hilfe   @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="dispZollArt(KDZOLLTEMP->Art)"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ZOLLSTELLE->Name"
  aSpalte[EDIT_TITEL]:="Name / Ort / Bemerkung"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ZOLLSTELLE->Ort"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ZOLLSTELLE->Text"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=2

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Text"
  aSpalte[EDIT_MASKE]:="@K"
  aSpalte[EDIT_MESSAGE]:="Bemerkung eingeben."
  aSpalte[EDIT_POS_Y]:=3

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  Edit(aFelder,aKopf)

  if aKopf[EDIT_CHANGED]
    // r�ckschreiben nach SpedKund
    select KundZoll
    KUNDZOLL->(dbseek(KUNDEN->KundNr+KDSPEDTEMP->SpedNr))
    do while ! KUNDZOLL->(eof()) .and. KUNDZOLL->KundNr == KUNDEN->KundNr .and. ;
      KUNDZOLL->SpedNr == KDSPEDTEMP->SpedNr
      rec_lock(0)
      delete
      skip
    enddo

    // h�nge neu an
    KDZOLLTEMP->(dbgotop())
    append("KDZOLLTEMP",{ || .t. })
    dbcommitall()
    dbunlockall()
  endif

  Umgebung(LOAD)

RETURN .t.
/* EoF Art_BestKarte */

function dispZollArt( art )
LOCAL result:=""
  switch Art
  case "B"
    result:="Binnenschiff"
    exit
  case "E"
    result:="Eisenbahn"
    exit
  case "L"
    result:="Luft"
    exit
  case "S"
    result:="Strasse"
    exit
  case "�"
    result:="�berseeschiff"
    exit
  endswitch
return left( result + space(14) , 14)
/** eof */

static function zollNrNach( oGet )
  if oget:changed
    if ! check(oGet,"ZollStelle",.f.,.t.)
      return .f.
    endif

    if empty(KDZOLLTEMP->Art)
      replace KDZOLLTEMP->Art with ZOLLSTELLE->Art
    endif
  endif
return .t.
/** eof */

/*
*  berechnet rekursiv das ben�tigte Material zu �bergebener St�ckliste
  * es wird gepr�ft ob eine alternat. St�ckliste STRG-M f�r fehlendes Material hinterlegt ist.

  Parameter:
    myArt: Art der Berechnung:

       AUFBESTAND_STATUS:  nur aktuelle Status Abfrage, mit allen Reservierungen etc.,
                           geht immer nur 1 Ebene tiefer egal welcher Lagerbestand vom TopArtikel vorhanden
                           au�er bei alternat. Material STRG-M da bis genug Bestand da ist

       AUFBESTAND_ABFRAGE: aktuelle Abfrage, alte Reserveriungen (ARTIKEL->disponiert) werden ignoriert
                           geht nicht rek. in alle Ebenen runter, sondern nur auf 1. Ebene

       AUFBESTAND_BERECHNEN: wird neu berechnet, alte Reserveriungen (ARTIKEL->disponiert) werden ignoriert
                             geht rek. in alle Ebenen runter

    alleArtikel: Array von ArtikelDisponiert mit allen Artikeln die Auftragsbestand haben (summiert)
    alleReservierungen: Array von ArtikelDisponiert mit allen Einzelreservierungen (nicht summiert)
                        -> ArtReserv.dbf
    mArtNr:    die Arikel-Nr.
    mMenge:    ben�tigte Menge
    maxExternKW: falls .f. dann ohne externe Bestellungen (default)
                 falls .t. dann mit externe Bestellungen
                 falls eine KW dann inkl. aller Bestellungen, die bis zu dieser KW geliefert werden.
  
    mAbPostNr: Referenz zum Auftragsposten (darf 0 sein)
    Tiefe:     Rekursions-Tiefe, starte bei 0
    alternativeZu: mit STRG-M kann einem Artikel ein Alternativ-Material zugewiesen werden,
                   das wird hier reserviert, wenn das "normale" Material nicht auslangt
    topFaktor: der Faktor des Materials zum Top-Level Artikel der AB
                       bei tiefer veraschachteltem Material das Produkt aller Faktoren!
  */


FUNCTION;
  AufBestRek( myArt , alleArtikel , alleReservierungen, offeneBestellungen, mArtNr , mMenge ,;
  maxExternKW, mAbPostNr , Tiefe , alternativeZu , topFaktor )
LOCAL RestBedarf, mArtikel, mReserv,mReserv2, alternatRest
LOCAL Material, mat, topParent
LOCAL aktSel:=alias()

  default mAbPostNr:=0
  default Tiefe:=0
  default topFaktor:=1
  default maxExternKW:=.f.

  if Tiefe > MAX_LOOP
    Error(AV_REKURSION + mat:artNr,.t.,"root")
    return mMenge
  endif

  // if trim(mArtNr) == "38268219"
  // altd()
  // endif

  ARTIKEL->(dbseek( mArtNr ))
  if ! hb_HHasKey( offeneBestellungen , mArtNr )
    if isKw(maxExternKW) .or. (valtype(maxExternKW) == "L" .and. maxExternKW)
      offeneBestellungen[ mArtNr ]:=getBestExtern(maxExternKW)
    else
      offeneBestellungen[ mArtNr ]:={0,""}
    endif
  endif

  if hb_HHasKey( alleArtikel , mArtNr )
    mArtikel:=alleArtikel[mArtNr]
  else
    mArtikel = ArtikelDisponiert():new( mArtNr , getArtikelArt() )
    // 20220202: jetzt ohne offene Bestell-Menge
    // 20220730: jetzt D-Artikel mit offener Bestellung
    if ARTIKEL->Art == "D"
      mArtikel:LageBest:=max(ARTIKEL->LageBest + offeneBestellungen[ mArtikel:ArtNr ][1],0) // offene Bestell-Menge
    else
      mArtikel:LageBest:=max(ARTIKEL->LageBest,0)
    endif
    mArtikel:disponiert:=if( myArt != AUFBESTAND_STATUS , 0 , ARTIKEL->disponiert)
    mArtikel:Einheit:=ARTIKEL->ME
    mArtikel:BestText:=offeneBestellungen[ mArtikel:ArtNr ][2] // offene Bestell-KWs
    mArtikel:MatArtNr:=ARTIKEL->MatArtNr
    mArtikel:MatFaktor:=ARTIKEL->MatFaktor
    mArtikel:topFaktor:=topFaktor
    alleArtikel[ mArtNr ]:=mArtikel
  endif

  // merke einzelene Reservierungen (im Speicher ist schneller als in Artreserv.dbf)
  mReserv = ArtikelDisponiert():new( mArtNr , getArtikelArt() )
  mReserv:Tiefe:=Tiefe
  // 20220202: jetzt ohne offene Bestell-Menge
  // 20220730: jetzt D-Artikel mit offener Bestellung
  if ARTIKEL->Art == "D"
    mReserv:LageBest:=ARTIKEL->LageBest + offeneBestellungen[ mArtikel:ArtNr ][1] // offene Bestell-Menge
  else
    mReserv:LageBest:=max(ARTIKEL->LageBest,0)
  endif
  mReserv:disponiert:=if( myArt != AUFBESTAND_STATUS , 0 , ARTIKEL->disponiert )
  mReserv:Einheit:=ARTIKEL->ME
  mReserv:BestText:=offeneBestellungen[ mArtikel:ArtNr ][2] // offene Bestell-KWs
  mReserv:MatArtNr:=ARTIKEL->MatArtNr
  if alternativeZu != NIL
    mReserv:AlternZu:=alternativeZu
  endif
  mReserv:topFaktor:=topFaktor
  mReserv:MatFaktor:=ARTIKEL->MatFaktor
  mReserv:AbPostNr:=mAbPostNr
  mReserv:menge:=mMenge
  aadd( alleReservierungen , mReserv)

  /* Artikel Bestand reservieren */
  if myart <> AUFBESTAND_BERECHNEN .and. tiefe == 0
    //if tiefe == 0
    RestBedarf:=mMenge
  else
    RestBedarf:=mMenge - max(max(mArtikel:LageBest,0) - max(mArtikel:disponiert,0) , 0 )
  endif

  //if RestBedarf <= 0 .and. mMenge >0 .and. (hb_bitand(myart, AUFBESTAND_STATUS) == 0 .and. tiefe == 0)
  //if RestBedarf <= 0 .and. (hb_bitand(myart, AUFBESTAND_STATUS) == 0 .and. tiefe == 0)
  if RestBedarf <= 0 // .and. tiefe == 0
    mArtikel:disponiert:=mArtikel:disponiert + mMenge
    mReserv:disponiert:=mMenge // merke absolute Menge

  else // RestBedarf > 0

    // alternatives Material bei Platte/Meter immer nur ein Vielfaches der AVPOST->Menge nehmen,
    // z:b. bei ben�tigter 1/2 Platte kann man nicht 3/4 nehmen sondern nur 1/2
    // der Rest dann vom Alternativ-Material

    // laut Telefonat mit H. Weiland wieder aus: 20220128, bis Anwendungsfall wieder auftaucht
    // EINHEIT->(dbseek( mArtikel:Einheit))
    // if EINHEIT->(eof())
    // Error("Artikel: " + out(ARTIKEL->ArtNr) + " Einheit:"+mArtikel:Einheit+": nicht gefunden",.t.,"root")
    // else
    // if EINHEIT->Vielfach == "J" .and. topFaktor <> 1
    // FIXME
    // restModulo:=mod(RestBedarf , topFaktor)
    // RestBedarf:=RestBedarf - restModulo
    // endif
    // endif

    // kein alternatives Material hinterlegt
    if empty( mArtikel:MatArtNr )

      if alternativeZu != NIL
        mArtikel:disponiert:=mArtikel:disponiert + mMenge - RestBedarf
        mReserv:disponiert:=mMenge - RestBedarf
        return RestBedarf // alt. Material konte nicht komplett reserviert werden
      endif

      mArtikel:disponiert:=mArtikel:disponiert + mMenge
      mReserv:disponiert:=mMenge // merke absolute Menge

      // jetzt St�ckliste 1 Ebene tiefer reservieren
      if mArtikel:Art $ STKLIST_ARTIKEL .and. (tiefe == 0 .or. myArt == AUFBESTAND_BERECHNEN)
        // Info bei Fertigmeldung nur bei alternat. Material tiefer gehen!

        Material:=Stueckliste():new( mArtNr, getArtikelArt() ):getMaterial( .f. )

        /* rekursiver Aufruf, Unterartikel */
        for each mat in Material
          if mat:Text=="A"
            if mat:Menge <> 0 // seit 1.7.19 alle mit 0 in Mat.St�ckliste raus
              AufBestRek(myArt , @alleArtikel , @alleReservierungen, @offeneBestellungen, mat:ArtNr , RestBedarf * mat:Menge , maxExternKW, mAbPostNr , Tiefe+1 , NIL , mat:Menge )
            endif
          elseif mat:text=="T" .and.;
            hb_bitand(myart, AUFBESTAND_STATUS + AUFBESTAND_ABFRAGE) > 0 .and. tiefe == 0
            // auf 1. Ebene auch Texte hinzuf�gen
            mReserv = ArtikelDisponiert():new( mat:ArtNr , mat:text )
            mReserv:Tiefe:=Tiefe
            mReserv:disponiert:=1 // werden ansonsten nicht ausgedruckt
            aadd( alleReservierungen , mReserv)
          endif
        next

      endif

      // alternatives Material hinterlegt
    else // ! empty( mArtikel:MatArtNr )

      if RestBedarf < offeneBestellungen[ mArtikel:ArtNr ][1] // bestellte Menge reicht aus
        offeneBestellungen[ mArtikel:ArtNr ][1] -= RestBedarf

        mArtikel:disponiert:=mArtikel:disponiert + mMenge
        mReserv:disponiert:=mMenge

      else

        RestBedarf:=RestBedarf - offeneBestellungen[ mArtikel:ArtNr ][1] // offene Bestell-Menge
        offeneBestellungen[ mArtikel:ArtNr ][1]:=0 // bestellmenge "verbraucht"

        // RestBedarf wird bei alternat. Material abgebucht oder wieder "hochgereicht"
        mArtikel:disponiert:=mArtikel:disponiert + mMenge - RestBedarf
        mReserv:disponiert:=mMenge - RestBedarf

        // gleiche Tiefe pr�fe alt. Material
        topParent:=if(alternativeZu == NIL, mArtNr , alternativeZu)
        if (alternatRest:=AufBestRek(myArt , @alleArtikel , @alleReservierungen, @offeneBestellungen, mArtikel:MatArtNr , RestBedarf * mArtikel:MatFaktor, maxExternKW, mAbPostNr , Tiefe , topParent , topFaktor * mArtikel:MatFaktor ) ) == 0
          // alt. Material konnte verbucht werden

        else
          if alternativeZu != NIL
            return alternatRest // alt. Material konte nicht komplett reserviert werden
          else
            // wenn alternatives Material nicht verf�gbar, bleibt das urspr. Material reserviert.
            mArtikel:disponiert:=mArtikel:disponiert + ( alternatRest / mArtikel:MatFaktor)

            // eigener Eintrag in Reserveriungstabelle f�r Fehlbestand
            mReserv2 = ArtikelDisponiert():new( mArtNr , getArtikelArt() )
            mReserv2:Tiefe:=Tiefe
            // nehme hier Rest-Lagerbestand, nicht den aktuellen
            mReserv2:LageBest:=Max(mArtikel:Lagebest - mArtikel:disponiert + mMenge - RestBedarf,0)
            mReserv2:MatArtNr:=mArtikel:MatArtNr
            mReserv2:MatFaktor:=mArtikel:MatFaktor
            mReserv2:AbPostNr:=mAbPostNr
            mReserv2:menge:=(alternatRest / mArtikel:MatFaktor )
            mReserv2:Einheit:=mArtikel:Einheit
            mReserv2:disponiert:=(alternatRest / mArtikel:MatFaktor )
            mReserv2:fehlMenge:=(alternatRest / mArtikel:MatFaktor )
            mReserv2:topFaktor:=alleArtikel[ mArtNr ]:topFaktor
            aadd( alleReservierungen , mReserv2)

          endif
        endif
      endif
    endif
  endif

RETURN 0
  /* eop */

/* Liefert die externe Bestellmenge zur�ck, die bis zu der �bergebenenen KW geliefert wird.
  Falls KW==NIL dann 0
*/
static function getBestExtern(maxExternKW)
LOCAL result:=0, BestText:=""
LOCAL bestRec:=BESPOST->(recno())
LOCAL bestAusRec:=BESAUS->(recno())
LOCAL merk_order:=BESPOST->(indexord()), tempMenge

  if ARTIKEL->BestExt > 0
    BESPOST->(OrdSetFocus(2)) // Art.Nr
    BESPOST->(dbseek( ARTIKEL->ArtNr ))
    do while ! BESPOST->(eof()) .and. BESPOST->ArtNr == ARTIKEL->ArtNr
      BESAUS->(dbseek( BESPOST->BestNr ))
      if BESAUS->Erledigt<>"J" .and.;
        (!isKw(maxExternKW) .or. kwKleiner(BESPOST->KW, maxExternKW) >= 0)
        tempMenge:=BESPOST->Menge - BESPOST->GeliefGes
        // abweichende Mengeneinheit?
        if ARTIKEL->ME <> BESPOST->ME
          // Umrechnung bekannt
          if ARTIKEL->ME2 == BESPOST->Me
            tempMenge:=round(tempMenge / ARTIKEL->ME_Faktor,2)
          else
            troubleemail(ACHTUNG + BESPOST->ArtNr+" "+BESPOST->Me+" Umrechnung nicht bekannt !" )
          endif
        endif
        result+= tempMenge
        // merke Lief.KW f�r Material-Bedarfsanforderung
        EINHEIT->(dbseek( BESPOST->ME ))
        BestText;
          +=;
          alltrim(transstr(BESPOST->Menge -;
          BESPOST->GeliefGes,8,0))+" "+trim(EINHEIT->Text) + " in " + BESPOST->KW + " "
      endif
      BESPOST->(dbskip())
    enddo
  endif
  BESPOST->(dbgoto(bestRec))
  BESAUS->(dbgoto(bestAusRec))
return {result,bestText}
/** eof */


/** bearbeiten des alternativen Materials bei einem Artikel */
function AlternatMaterialErfassen(mArtNr)
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL aktOrd:=ARTIKEL->(OrdSetFocus(1)) // Art.Nr.
LOCAL wasLocked:=ARTIKEL->(isLocked())
LOCAL aktSel:=alias()
LOCAL result:=.f.
LOCAL GetList:={}
LOCAL editMatArtNr
LOCAL ob:=11
LOCAL merkeArtNr:=ARTIKEL->MatArtNr
LOCAL merkeFaktor:=ARTIKEL->MatFaktor

  // ACHTUNG STRG-M und Taste Return haben den gleichen keycode
  if hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL )

    Umgebung(WRITE_ALL)

    select Artikel
    ARTIKEL->(dbseek( mArtNr ) )
    if ! ARTIKEL->(eof()) .and. rec_lock(5)
      result:=.t.

      if rec_lock(5)
        editMatArtNr:=ARTIKEL->MatArtNr

        if ARTIKEL->MatFaktor == 0
          replace ARTIKEL->MatFaktor with 1
          merkeFaktor:=ARTIKEL->MatFaktor
        endif

        setcolor(COLWIN)
        Fenster(ob,38,ob+2,77,"Alternatives Material")
        @ ob+1,40 say "Art.Nr.:" get editMatArtNr valid { |oget| nachMatArtikel(oGet)};
          when Message("Alternatives Material eingeben.   @STRG-F6@=Details anzeigen  @F12@=Auswahl")

        @ ob+1,59 say "Faktor:" get ARTIKEL->MatFaktor valid { |oGet| nachMatFaktor(oGet) } ;
          when Meswhen Message("Umrechnung eingeben:  Akt. Material = neues Material x @Faktor@")
        read

        if merkeArtNr <> ARTIKEL->MatArtNr .or. merkeFaktor <> ARTIKEL->MatFaktor
          replace ARTIKEL->MatDatum with getUser():date
        endif

        dbcommit()
        if ! wasLocked
          dbunlock()
        endif
      endif

      if merkeArtNr <> ARTIKEL->MatArtNr .or. merkeFaktor <> ARTIKEL->MatFaktor
        AufBestand()
        if empty(ARTIKEL->MatArtNr)
          trouble("alternatives-Material", {"gel�scht:", mArtNr+"-> vorher: "+merkeArtnr+;
            " Faktor:" + trim(str(merkeFaktor))})
        else
          trouble("alternatives-Material", {"erfasst:", mArtNr+"->"+ARTIKEL->MatArtNr+" Faktor:" +;
            trim(str(ARTIKEL->MatFaktor))})
        endif
      endif

    endif

    Umgebung(LOAD)
  endif
return .t.
/** eof */

static function nachMatArtikel( oGet )
LOCAL result
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL aktArtNr:=ARTIKEL->ArtNr

  result:=check(oGet,"Artikel",.t.,.f.)
  if ARTIKEL->MatArtNr == aktArtNr
    Error(ACHTUNG+"Artikel bereits bei Ziel-Artikel hinterlegt.||"+;
      "         Bitte pr�fen!")
    result:=.f.
    // zur�ck auf Eingabe Artikel
    ARTIKEL->(dbgoto(aktRec))
  else
    // zur�ck auf Eingabe Artikel
    ARTIKEL->(dbgoto(aktRec))
    if ARTIKEL->ArtNr == oGet:buffer
      Error(ACHTUNG+"ung�ltige Eingabe.")
      result:=.f.
    else
      if oGet:changed
        replace ARTIKEL->MatArtNr with oGet:buffer
      endif
    endif
  endif
return result
/** eof */

static function nachMatFaktor( oGet )
LOCAL result:=.t.
  ignore oget
  if ARTIKEL->MatFaktor <= 0
    Error(ACHTUNG+"ung�ltige Eingabe.")
    result:=.f.
  endif
return result
/** eof */

/** Anzeigen des alternativen Materials bei einem Artikel */
procedure AlternatMaterialAnzeigen(mArtNr)
LOCAL stkListe,result
LOCAL ob:=5,li:=2,unt:=18,re:=78

  Umgebung(WRITE_ALL)

  setcolor(COLWIN)

  stkListe:=Stueckliste():new(mArtNr)
  result:=stkListe:getAlternativeTopMaterialInfo()
  Message(ARROW_UP+ARROW_DOWN+"      @ESC@=Ende")
  Fenster(ob,li,unt,re , "Alternatives Material" )
  MyMemoEdit( result , ob + 1,li + 2,unt - 1,re - 1 , .f. )

  Umgebung(LOAD)

return
/** eof */

/** pr�ft bei Bestellungen neg. Liefermenge vorkommt
  * 1. Vorfall: s. Email H. Weiland vom 5.3.17
*/
Function BestellKonsistenzCheck()
LOCAL treffer:=0 , protName
  cls
  titel("Bestell - KonsistenzCheck")

  Protokoll(INIT_P,"Bestellung - Konsistenzcheck","Best.Nr.  Artikel   GeliefGes")

  if open("BesPost")
    locate for BESPOST->GeliefGes < 0
    do while ! BESPOST->(eof())
      Protokoll(PROTOKOLL, BESPOST->BestNr +;
        " " + BESPOST->ARtNr + " " + str(BESPOST->GeliefGes,5) )
      treffer++
      cont
    enddo

    // sende email?
    if treffer > 0
      Protokoll(P_CREATE_PDF)
      protName:=Protokoll(P_FILE_NAME)
      email(MY_EMAIL,"Fehler: Bestellung Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)

    endif

  else
    email(MY_EMAIL,"Fehler: Bestell Konsistenzcheck open")
  endif

  close data
return .t.
/** eop*/

/** pr�ft ob eine Artikel-Nr zu den automatisch hinzugef�gten Zoll Zuschl�gen geh�rt */
function isZollZuschlagArtikel(mArtNr)
  mArtNr:=alltrim( mArtNr )

  if getProperty("Miki.zoll.aufschlag.klein") == mArtNr
    return .t.
  endif

  if getProperty("Miki.zoll.aufschlag.gross") == mArtNr
    return .t.
  endif

  if getProperty("Miki.zoll.aufschlag.EUR1") == mArtNr
    return .t.
  endif

return .f.
/** eof */

/** Parameter: Datei (Aufaus oder Angaus)
*/
function checkUSALimit(Datei)
LOCAL rSumme:=0, aSumme:=0, aktSumme:=0, netto, gesamt
LOCAL Jahr , vJahr
LOCAL limit:=val(getProperty("Miki.umsatz.USA.limit","50000"))
LOCAL aktAufNr:=""
LOCAL alleJahre:={}
LOCAL protName

  Umgebung(WRITE_ALL)
  Message("USA Umsatz wird gepr�ft.  Bitte warten...")

  if upper(Datei) == "AUFAUS"
    if ! trim((DATEI)->R_Land) == "US" .and. ! trim((DATEI)->R_Land) == "USA"
      Umgebung(LOAD)
      return .t.
    endif


    aktAufNr:=AUFAUS->AufNr
    aadd( alleJahre , substr(dtoc(AUFAUS->AufDat),7,2) )
    // pr�fe ob Lieferung im Folgejahr
    select Auftrag
    go top
    do while ! AUFTRAG->(eof())
      jahr:=substr(AUFTRAG->Kw,4,2)
      if ! empty(jahr) .and. jahr <> substr(dtoc(AUFAUS->AufDat),7,2)
        aaddUnique( alleJahre , substr(AUFTRAG->Kw,4,2) )
      endif
      dbskip()
    enddo
  else
    if ! trim((DATEI)->V_Land) == "US" .and. ! trim((DATEI)->V_Land) == "USA"
      Umgebung(LOAD)
      return .t.
    endif
    aadd( alleJahre , substr(dtoc(ANGAUS->AufDat),7,2) )
  endif

  if ! open("Rechaus","AufAus","AufPost")
    Umgebung(LOAD)
    return .t.
  endif

  Protokoll(INIT_P,"USA Umsatz")

  for each jahr in alleJahre
    vJahr:=val("20"+Jahr)

    // summiere Rechnungen
    select Rechaus
    set filter to (trim(RECHAUS->R_Land) == "US" .or. trim(RECHAUS->R_Land) == "USA") .and. ;
      vJahr == year(RECHAUS->ReaDat)

    sum RECHAUS->Netto to rSumme

    // summiere Auftr�ge
    select AufPost
    set rela to AUFPOST->AufNr into AUFAUS
    index on AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      (trim(AUFAUS->R_Land) == "US" .or. trim(AUFAUS->R_Land) == "USA") .and.;
      jahr == substr(AUFPOST->KW,4,2) .and. AUFAUS->Erledigt<>"J" .and. len(alltrim(AUFPOST->ArtNr))>FRACHT_LAENGE to aSumme

    Protokoll(PROTOKOLL,"","Auf.Nr. Kunde                        Art.Nr.     KW  Rest-Menge  "+;
      "Netto-Wert")
    Protokoll(PROTOKOLL,replicate("-",75))

    aktSumme:=0
    netto:=0
    go top
    do while ! AUFPOST->(eof())
      if aktAufNr <> AUFAUS->AufNr
        netto:=(Max(AUFPOST->Menge-AUFPOST->GeliefGes,0));
          * AUFPOST->Preis / if( AUFPOST->PE=="H" , 100 , 1)
        if AUFPOST->Rabatt > 0
          netto:=netto - netto * AUFPOST->Rabatt / 100
        endif
        Protokoll(PROTOKOLL,AUFAUS->AufNr+"  "+AUFAUS->KurzName+" "+out(AUFPOST->ArtNr)+" "+AUFPOST->KW+;
          str(AUFPOST->Menge-AUFPOST->GeliefGes,12,2)+str(netto,12,2))
        aSumme += netto
      endif
      skip
    enddo
    // So.Rabatt & Zuschlag
    if AUFAUS->SO_Rabatt > 0
      aSumme -= netto * AUFAUS->SO_Rabatt / 100
    endif
    if AUFAUS->Zuschlag > 0
      aSumme += netto * AUFAUS->Zuschlag / 100
    endif

    // summiere akt. Datei (Angebot oder Auftrag)
    select Auftrag
    go top
    do while ! AUFTRAG->(eof())
      if substr(AUFTRAG->KW,4,2)==jahr
        netto:=(AUFTRAG->Menge-AUFTRAG->GeliefGes);
          * AUFTRAG->Preis / if( AUFTRAG->PE=="H" , 100 , 1)
        if AUFTRAG->Rabatt > 0
          netto:=netto - netto * AUFTRAG->Rabatt / 100
        endif
        aktSumme += netto
      endif
      skip
    enddo
    // So.Rabatt & Zuschlag
    if (DATEI)->SO_Rabatt > 0
      aktSumme -= netto * (DATEI)->SO_Rabatt / 100
    endif
    if (DATEI)->Zuschlag > 0
      aktSumme += netto * (DATEI)->Zuschlag / 100
    endif

    gesamt = rSumme + aSumme + aktSumme

    if rSumme + aSumme < limit .and. gesamt > limit
      Error(ACHTUNG+"USA Umsatz 20"+jahr+" �berschreitet Limit: "+;
        alltrim(transform(Limit,"@E 999,999,999"))+" Euro||"+;
        "         Rechnungen      :" +transform(rSumme,"@E 999,999,999")+" Euro|"+ "         "+;
        "offene Auftr�ge :" +transform(aSumme,"@E 999,999,999")+" Euro|"+ "         aktuelle Eingabe:" +transform(aktSumme,"@E 999,999,999")+" Euro|"+ "         ---------------------------------"+"|"+ "         Gesamt          :" +transform(gesamt,"@E 999,999,999")+" Euro|"+ "|"+ "         Details kommen per Email")

      // Email bei AB
      if upper(Datei) == "AUFAUS"

        Protokoll(PROTOKOLL,"","")
        select Rechaus
        go top
        Protokoll(PROTOKOLL,"Re.Nr Kunde                           Datum       Netto")
        Protokoll(PROTOKOLL,replicate("-",55))
        do while ! RECHAUS->(eof())
          Protokoll(PROTOKOLL,RECHAUS->RechNr+" "+RECHAUS->KurzName+" "+dtoc(RECHAUS->ReaDat)+;
            str(RECHAUS->Netto,12,2))
          skip
        enddo

        Protokoll(P_CREATE_PDF)
        protName:=Protokoll(P_FILE_NAME)

        email(MAIN_EMAIL,;
          "USA Umsatz 20"+jahr+" �berschreitet Limit: "+ alltrim(transform(Limit,"@E 999,999,999"))+" Euro",;
          "Auftrag         : " + aktAufNr +"||"+;
          "Rechnungen      :" +transform(rSumme,"@E 999,999,999")+" Euro|"+;
          "offene Auftr�ge :" +transform(aSumme,"@E 999,999,999")+" Euro|"+;
          "aktuelle Eingabe:" +transform(aktSumme,"@E 999,999,999")+" Euro|"+;
          "---------------------------------|"+;
          "Gesamt          :" + transform(gesamt,"@E 999,999,999")+" Euro|||", protName)

      endif
    endif

  next // Jahre

  Umgebung(LOAD)

return .t.
  /** eof */

/** pr�ft bei allen Rechnungen des Tages ob diese in der Historie eingetragen sind. */
Function RechausKonsistenzCheck()
LOCAL protName
LOCAL Stop:=.f.
LOCAL today:=getUser():date - 1
  //LOCAL today:=ctod("19.10.18")

  cls
  titel("Rechaus - KonsistenzCheck")

  if ! open("Rechpost","Rechaus","Waraus","Artikel","AufAus")
    return .f.
  endif

  Message("Liste wird erstellt.  Bitte warten...")

  Protokoll(INIT_P,"Rechaus Konsistenzcheck","Auf.Nr  Datum  Rech.Nr Datum  Kunde                 "+;
    "                 Art.Nr.      Menge")

  select WarAus
  index on WARAUS->ArtNr + dtos( WARAUS->Datum ) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    year(WARAUS->Datum) >= year(today)-3 // do no search all => speed up

  select RechPost
  set rela to RECHPOST->RechNr into Rechaus, to RECHPOST->AufNr into Aufaus,;
    to RECHPOST->ArtNr into Artikel
  loca for RECHPOST->ReaDat == today

  do while ! RECHPOST->(eof()) .and. ! stop
    if len(alltrim(RECHPOST->ArtNr)) > 6 .and. ! RECHAUS->AufArt $ "G" .and.;
      ! getArtikelArt() $ "W"
      Message("Pr�fe Rech.Nr.:" + RECHPOST->RechNr + " Artikel:" + RECHPOST->Artnr)
      select WarAus
      loca for WARAUS->ArtNr==RECHPOST->ArtNr .and.;
        (RECHPOST->RechNr $ WARAUS->Programm .or. RECHAUS->AufNr $ WARAUS->Programm)
      if WARAUS->(eof())
        Protokoll(PROTOKOLL,RECHAUS->AufNr+" "+dtoc(AUFAUS->AufDat)+" "+RECHPOST->RechNr+" "+;
          dtoc(RECHPOST->ReaDat)+" "+;
          RECHAUS->KundNr+" "+RECHAUS->Kurzname+" "+RECHPOST->Artnr+" "+str(RECHPOST->Menge))
      endif
      select RechPost
    endif
    cont
    stop:=stop_key() // ESC gedr�ckt ?
  enddo

  if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen!",,,.f.)
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Rechaus-Konsistenzcheck pr�fen","Bitte pr�fen",protName)
  endif

  close data
return .t.
/** eop*/

/** pr�ft dass bei keinem Artikel mehrere Werkzeuge hinterlegt sind. */
Function MehrfachKonsistenzCheck()
LOCAL protName
LOCAL werkzeuge
LOCAL today:=getUser():date - 1
LOCAL ausnahmen:=getProperty("Miki.konsistenzcheck.werkzeug.mehrfach","")
LOCAL gruppen, treffer, gruppe, artnr, entry

  cls
  titel("Mehrfach - KonsistenzCheck")

  if ! open("Mehrfach","Artikel","AvPost")
    close data
    return .f.
  endif

  Message("Liste wird erstellt.  Bitte warten...")

  Protokoll(INIT_P,"Taste-t Konsistenzcheck","Art.Nr.  Bezeichnung                            "+;
    "Werkzeug")
  select artikel
  loca for ARTIKEL->Art $"MF"
  do while ! ARTIKEL->(eof())
    if ! ARTIKEL->ArtNr $ Ausnahmen
      werkzeuge:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art):getWerkzeugGruppen()
      if len(werkzeuge) > 1
        gruppen:=hb_hash()
        treffer:=.f.
        for each entry in werkzeuge
          artnr:=entry[1]
          gruppe:=entry[2]
          if hb_HHasKey( gruppen, gruppe)
            aadd(gruppen[gruppe], artnr)
            treffer:=.t.
          else
            gruppen[gruppe]:={artnr}
          endif
        next
        if treffer
          Protokoll(PROTOKOLL,out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+space(8)+;
            array2readable(werkzeuge),;
            if(empty(ARTIKEL->Bez2),nil,space(len(out(ARTIKEL->ArtNr)))+" "+ARTIKEL->Bez2))
        endif
      endif
    endif
    cont
  enddo

  if Protokoll(P_CREATE_PDF,"Bitte �berpr�fen!",,,.f.)
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Taste-T-Konsistenzcheck pr�fen","Bitte pr�fen",protName)
  endif

  close data
return .t.
/** eop*/


/* FUNCTION zur eingabe des Typs bei Repa/Prod
*/
FUNCTION Typ_repa
LOCAL GetList:={}
LOCAL M_RepGerNr

  if ! open("Gerat","Empfaeng","RepKund","Prod")
    Error(TRY_AGAIN)
    RETURN .f.
  endif
  select Prod
  set rela to PROD->Empfaeng into Empfaeng, PROD->RepKdnr into RepKund

  @ 23,0 clear
  M_RepGerNr:=space(len(GERAT->RepGerNr))
  Message("Typ eingeben.            @F12@=Hilfe")
  @ 6,25 say "Typ:" get M_RepGerNr valid { |oGet| check(oGet,"Gerat",.f.,.f.) }
  read
  if ABBRUCH
    return .f.
  endif
  M->vor_index:=M_RepGerNr
  select Prod
RETURN ! empty(M_RepGerNr)
/* EOF */

/* FUNCTION zur eingabe der Art.Nr. bei Status
*/
FUNCTION Art_Status
LOCAL GetList:={}
LOCAL M_ArtNr

  if ! open("Artikel")
    Error(TRY_AGAIN)
    RETURN .f.
  endif

  set key K_F3 to repArtAnzeig()
  @ 23,0 clear
  M_ArtNr:=space(len(ARTIKEL->ArtNr))
  Message("Artikel eingeben.         @F3@=Anzeige Status-Artikel        @F12@=Hilfe")
  @ 6,25 say "Art.Nr.:" get M_ArtNr valid { |oGet| check(oGet,"Artikel",.f.,.f.) }
  read
  set key K_F3 to
  if ABBRUCH
    return .f.
  endif
  M->vor_index:=subRepArtikel(M_ArtNr)
  select Status
RETURN ! empty(M_ArtNr)
/* EOF */

/** Liefert den Lagerort des aktuellen Artikels in der gew�nschten L�nge */
function getArtikelLagerOrt( laenge )
return;
  getLagerOrt( ARTIKEL->LG_Raum , ARTIKEL->LG_Regal , ARTIKEL->LG_Fach , ARTIKEL->LG_Text , laenge)
/** eof */

/** Liefert den Lagerort anhand der einzelnen Parameter in der gew�nschten L�nge */
function getLagerOrt( LG_Raum , LG_Regal , LG_Fach , LG_Text , laenge )
LOCAL result:=""
LOCAL aktSel

  if ! empty(Lg_Raum)
    result += "." + Lg_Raum

    if ! empty(Lg_Regal)
      result += "." + Lg_Regal
    endif

    if ! empty(Lg_Fach)
      result += "." + Lg_Fach
    endif
  endif

  if ! empty(Lg_Text)
    result += "." + Lg_Text
  endif

  if left(result,1) == "."
    result:=substr( result , 2 )
  endif

  if len( result ) == 2 // evtl. nur Raum eingegeben, dann Text anh�ngen
    aktSel:=alias()
    open("LagerOrt")
    LAGERORT->(dbseek( result ))
    if laenge==nil .or. laenge >= len( result ) + len( LAGERORT->Text )
      result += " " + LAGERORT->Text
    else
      result += " " + LAGERORT->KurzText
    endif
    select( aktSel )
  endif

  result:=alltrim( result )

return if( laenge==nil , result , left(result + space(laenge) , laenge ) )
/** eof */

/** Liefert eine Filter beding. f�r den Lagerort anhand der einzelnen Parameter  */
function filterLagerOrt( LG_Raum , LG_Regal , LG_Fach , LG_Text )
LOCAL result:=""

  if ! empty(Lg_Raum)
    result += ".and. ARTIKEL->Lg_Raum=='" + Lg_Raum +"'"
  endif

  if ! empty(Lg_Regal)
    result += ".and. ARTIKEL->Lg_Regal=='" + Lg_Regal +"'"
  endif

  if ! empty(Lg_Fach)
    result += ".and. ARTIKEL->Lg_Fach=='" + Lg_Fach +"'"
  endif

  if ! empty(Lg_Text)
    result += ".and. ARTIKEL->Lg_Text=='" + Lg_Text +"'"
  endif

  if len(result) == 0
    return .t.
  endif

  result:=substr(result, 6) // remove leading .and.

return &result
/** eof */

/* Returns die Artikel Art des aktuellen Artikels
  */
FUNCTION getArtikelArt()
return ARTIKEL->Art

/*
* Service Porcedure zum L�schen des t�gl. Rechnungsausgangsbuch
* l�scht den ausgwew�hlten Eintrag und alle neueren (!) aus Summen.dbf
* und setzt den Merker in den Rechnungen zur�ck.  
*/
PROCEDURE rechausLoesch
LOCAL GetList:={} , SumNr

  cls
  titel("Rechnungsausgangsbuch l�schen")

  if ! open("Summen","Rechaus")
    cls
    close data
    RETURN
  endif

  Select Summen
  go bottom
  sumNr:=SUMMEN->SumNr
  Message("Bitte Nr. Rechnungsausgangsbuch eingeben.    @F12@=Auswahl2")
  @ 10,20 say "Nr.:" get SumNr valid { |oGet| check(oGet,"Summen",.f.,.f.)}
  read

  if ! ABBRUCH .and.;
    message("Rechaus.Nr.:" + SumNr + " und alle (!) neueren l�schen? (@J@/@N@)","JN"," ")=="J"
    loca for SUMMEN->SumNr >= sumNr
    do while ! SUMMEN->(eof())
      Message("L�sche Rechaus.Nr.:" + SUMMEN->SumNr + "    Bitte warten...")
      select Rechaus
      loca for RECHAUS->SumNr == SUMMEN->SumNr
      do while ! RECHAUS->(eof())
        rec_lock(0)
        replace RECHAUS->SumNr with ""
        dbcommit()
        dbunlock()
        cont
      enddo
      select Summen
      rec_lock(0)
      delete
      dbcommit()
      dbunlock()
      cont
    enddo
  endif
  close data

return
/** eop */



/* erfassen und anzeigen der prod. Nietger�te */
PROCEDURE editNietGerate()
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL M_RepGerNr, ant, body

  Umgebung(WRITE_ALL)

  if ! open( "Gerat", "GeratErf", "GeratProd", "Artikel")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  do while .t.
    @ 2,0 clear
    M_RepGerNr:=space(len(GERAT->RepGerNr))
    Message("Typ eingeben.            @F12@=Hilfe")
    @ 2,0 say "Typ:" get M_RepGerNr valid { |oGet| check(oGet,"Gerat",.f.,.f.) }
    read

    if ABBRUCH
      exit
    endif
    @ 2,20 say GERAT->Bezeichn
    @ 4,0 say "Ger�te-Nummern:"

    Message("Ger�te werden kopiert.  Bitte warten...")

    select GeratProd
    go top
    select GeratErf
    zap

    set rela to GERATERF->ArtNr into Artikel
    dbseek( M_RepGerNr )
    append("GeratProd",{ || GERATPROD->RepGerNr==M_RepGerNr})

    /* Kopf-Definitionen */
    aKopf[EDIT_START_Y]:=8 // N: Begin des Eingabe-Berreiches BS
    aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
    aKopf[EDIT_NEW_FKT]:={ || neuGeratProd()}
    aKopf[EDIT_INDEX_FELD]:=5 // Art.Nr. entscheidet ob Leersatz
    aKopf[EDIT_GESPERRT]:="K"
    aKopf[EDIT_AFTER_EDIT_FKT]:={ || checkeGeratNr() }
    aKopf[EDIT_CHANGED]:=.f.

    /* Feld-Definitionen */
    aSpalte:=e_fill() // initialisieren

    // aSpalte[EDIT_NAME]:="space(0)"
    // aSpalte[EDIT_TITEL]:="Ger�te-Nr."
    // aSpalte[EDIT_EDIT]:=.f.

    // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    // aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="GerVon"
    aSpalte[EDIT_TITEL]:="   von"
    aSpalte[EDIT_MASKE]:="@K 999999"
    aSpalte[EDIT_AFTER]:={ |oGet| nachGerNrVon(oGet) }
    aSpalte[EDIT_MESSAGE]:="1. Ger�te-Nummer eingeben"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="GerBis"
    aSpalte[EDIT_TITEL]:="   bis"
    aSpalte[EDIT_MASKE]:="@K 999999"
    aSpalte[EDIT_AFTER]:={ |oGet| nachGerNrBis(oGet) }
    aSpalte[EDIT_BS_AUSGABE]:=.t.
    aSpalte[EDIT_MESSAGE]:="Letzte Ger�te-Nummer eingeben"

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="Anzahl"
    aSpalte[EDIT_TITEL]:="Anzahl"
    aSpalte[EDIT_AFTER]:={ |oGet| nachGerAnzahl(oGet) }
    aSpalte[EDIT_BS_AUSGABE]:=.t.
    aSpalte[EDIT_MESSAGE]:="Anzahl Ger�te eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="FertDat"
    aSpalte[EDIT_TITEL]:="Fert.Datum"
    aSpalte[EDIT_MESSAGE]:="Fertigungs-Datum eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="ArtNr"
    aSpalte[EDIT_TITEL]:="Art.Nr."
    aSpalte[EDIT_MASKE]:="@K@!"
    aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe      @F4@=Honsel-Nr.       @ESC@=Ende"

    aSpalte[EDIT_AFTER]:={ |oGet| ( trim(oGet:Buffer)$"$*" .or. check(oGet,"Artikel",.f.))} // kein leeres Feld erlaubt

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="memotran(Bemerkung,' ',' ')"
    aSpalte[EDIT_TITEL]:="Bemerkung"
    aSpalte[EDIT_MASKE]:=replicate("X",50)
    aSpalte[EDIT_BEFORE]:={ || editGeratBemerkung() }
    // aSpalte[EDIT_AFTER]:={ || foo() }
    aSpalte[EDIT_BS_AUSGABE]:=.t.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    if reccount() > 0
      keyboard("N") // f�ge neuen Datensatz hinzu
    endif
    Edit(aFelder,aKopf)

    if aKopf[EDIT_CHANGED]
      ant:=space(1)
      do while ! ant $ "JN"
        ant:=message("�nderungen speichern? (@J@/@N@)","JN"," ")
      enddo
      if ant == "J"
        Message("Ger�te werden kopiert.  Bitte warten...")

        select GeratErf
        loca for GERATERF->Changed == "J"
        body:="Bemerkung:||"
        do while ! GERATERF->(eof())
          body+=;
            "Ger�te-Nummern: " + alltrim(GERATERF->GerVon) + " - " + alltrim(GERATERF->GerBis) + "|" + ;
            "Artikel-Nr.: " + GERATERF->ArtNr + " " + ARTIKEL->Bez1 + "||" + ;
            memotran(GERATERF->Bemerkung,'|','|')+"||"+replicate("-",52)+"|"
          replace GERATERF->Changed with "N"
          cont
        enddo
        email(MAIN_EMAIL,"Nietger�te Info: "+ GERAT->Bezeichn,body)

        /* schreibe Ger�te zur�ck */
        select GeratErf
        go top
        select GeratProd
        go top
        myDelete("GeratProd",{ || GERATPROD->RepGerNr==M_RepGerNr})
        append("GeratErf",{ || .t.})
      endif
    endif
  enddo

  Umgebung(LOAD)

RETURN
/* EoF */

function neuGeratProd()
LOCAL aktRec:=GERATERF->(recno())
LOCAL lastNr:=getNextNumber()
  replace GERATERF->RepGerNr with GERAT->RepGerNr
  replace GERATERF->GerVon with padLeft(alltrim(str(lastNr)),6)
  // replace GERATERF->GerBis with trim(str(lastNr))
  // replace GERATERF->Anzahl with 1
  replace GERATERF->FertDat with getUser():date
  dbcommit()
return .t.

static function nachGerNrVon(oGet)
LOCAL aktRec:=GERATERF->(recno())
LOCAL lastNr:=NIL
  if oget:changed()
    lastNr:=getNextNumber()
    if val(oGet:buffer) < lastNr
      Error(ACHTUNG+"Nummer muss gr��er/gleich " + trim(str(lastnr)) + " sein.")
      return .f.
    endif
    if ! empty(GERATERF->GerBis) .and. val(oGet:buffer) < val(GERATERF->GerBis)
      Error(ACHTUNG+"Nummer muss kleiner/gleich " + GERATERF->GerBis + " sein.")
      return .f.
    endif

    // shift right
    if trim(oGet:buffer) <> oGet:Buffer
      oGet:varput(padLeft(alltrim(oGet:buffer),6))
    endif

    // adjust bis if applicable
    if val(oGet:buffer) > val(GERATERF->GerBis)
      replace GERATERF->GerBis with oGet:buffer
      replace GERATERF->Anzahl with 1
    endif
  endif
return .t.

static function nachGerNrBis(oGet)
  if oget:changed()
    if val(oGet:buffer) < val(GERATERF->GerVon)
      Error(ACHTUNG+"Nummer muss gr��er/gleich " + GERATERF->GerVon + " sein.")
      return .f.
    endif

    // shift right
    if trim(oGet:buffer) <> oGet:Buffer
      oGet:varput(padLeft(alltrim(oGet:buffer),6))
    endif
    replace GERATERF->Anzahl with val(GERATERF->GerBis) - val(GERATERF->GerVon) + 1
  endif
return .t.

static function nachGerAnzahl(oGet)
  if oget:changed()
    replace GERATERF->GerBis with padLeft(alltrim(str(val(GERATERF->GerVon) +;
      val(oGet:buffer) - 1)), 6)
  endif
return .t.

/** zum bearbeiten der Bemerkung je Posten */
function editGeratBemerkung()
LOCAL s01:=savescreen(), text
LOCAL aktColor:=setcolor(COLWIN)
  Fenster(12,1,21,77,"Bemerkung")
  Message("Bemerkung eingeben.    @ESC@=Ende")
  SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
  text:=MyMemoEdit((ALIAS())->Bemerkung,13,2,20,76, .t.)
  Set Key K_ESC to
  if trim((ALIAS())->Bemerkung) <> trim(text)
    replace (ALIAS())->Bemerkung with text
    replace GERATERF->Changed with "J"
  endif
  restscreen(,,,,s01)
  setcolor(aktColor)

  SetLastKey(K_ESC)

return .t.
/** eof */

static function checkeGeratNr()
  if ! empty(GERATERF->GerBis) .and. val(GERATERF->GerBis) < val(GERATERF->GerVon)
    Error(ACHTUNG+"Nummerneingabe ung�ltig.  Bitte korrigieren.")
    return .f.
  endif
return .t.
  /** eof */

static function getNextNumber()
LOCAL aktRec:=GERATERF->(recno())
LOCAL lastNr:=NIL
  if reccount() > 1
    go bottom
    do while ! bof() .and. empty(GERATERF->GerBis)
      dbskip(-1)
    enddo
    if ! bof()
      lastNr:=val(GERATERF->GerBis) + 1
    endif
    GERATERF->(dbgoto( aktRec ))
  endif

  if lastNr == NIL
    lastNr:=GERAT->Eti_Nr
  endif
return lastNr



/* 
* berechnet die Stunden/Minuten zw. 2 Zeiteingabe
*  ist Pause=="J" wird w�hrend der Mittagszeit keine Pause abgezogen
*
  * ACHTUNG: seit 20220523 wird bei 0 Personen die Zeit einfach addiert also Faktor 1 nicht 0
*/
FUNCTION ZeitDif(Begin, Ende, Pause, nullOK, indMinuten, anzPersonen)
LOCAL Std, Min, result

  default nullOK:=.f.
  default indMinuten:=.f.

  if valtype(anzPersonen) == "U" .or. anzPersonen == 0
    anzPersonen:=1
  endif

  if ! nullOK .and. Ende==Begin
    ERROR("ACHTUNG Zeiteingabe = 0",.t.)
    return 0
  endif

  if nullOK .and. (Ende==0 .or. Begin == 0)
    return 0
  endif

  /* Berechnung der Stunden */
  Std:=(int(Ende)-int(Begin))
  if Std < 0
    if left(procname(1),10)="KALK_ZEIT_"
      ERROR("Fehlerhafte Zeiteingabe.",.t.)
    endif
    return(-1) // Error
  endif

  /* Berechnung der Minuten */
  Min:=(Ende-int(Ende))*100-(Begin-int(Begin))*100
  If Min < 0
    Min+=60
    Std--
  endif


  /* incl. Pause ? */
  if Pause=="N" .and. ( begin <= MITTAGENDE .or. Ende >= MITTAGANF )
    DO CASE
    CASE begin <= MITTAGANF .and. Ende <= MITTAGANF // nicht
      // NOP
    CASE begin >= MITTAGENDE.and. Ende >= MITTAGENDE // nicht
      // NOP
    CASE begin <= MITTAGANF .and. Ende >= MITTAGENDE // Komplett
      Min-=(MITTAGENDE-MITTAGANF) * 100
    CASE begin <= MITTAGANF .and. Ende <= MITTAGENDE // erste 'H�lfte' der Pause
      Min-=(Ende-MITTAGANF) * 100
    CASE begin >= MITTAGANF .and. Ende >= MITTAGENDE // letzte 'H�lfte' der Pause
      Min-=(begin-MITTAGANF) * 100
    OTHERWISE
      Min-=Ende-Begin // ausschl. innerhalb der Pause
    ENDCASE
    if Min < 0
      Min+=60
      Std--
    endif
  endif

  if indMinuten
    result:=round(Std+Min/60,2)
  else
    result:=round(Std+Min/100,2)
  endif

RETURN result * anzPersonen
/* EOF */

/* FUNCTION Zeit_eingabe
*
* pr�ft einen String auf Zeitlogischen Ausdruck
*/
FUNCTION Zeit_Eingabe(oGet)
LOCAL buff:=alltrim(oGet:Buffer)

  /* zur�ck immer erlaubt */
  if lastkey()==K_UP
    oget:undo()
    RETURN(.t.)
  endif

  /* UhrZeit checken ! */
  if val(left(oGet:Buffer,2)) > 23
    Error(ACHTUNG+"Uhrzeit > 23 Stunden nicht m�glich",.t.)
    RETURN(.f.)
  endif

  if len(trim(right(oGet:Buffer,2)))=1 .or.val(right(oGet:Buffer,2)) > 59
    Error(ACHTUNG+"Uhrzeit > 59 Minuten nicht m�glich",.t.)
    RETURN(.f.)
  endif

  if fieldPos("Start") > 0 .and. fieldPos("Ende") > 0
    if (ALIAS())->Ende > 0 .and. (ALIAS())->Start > (ALIAS())->Ende .and.;
      upper(oget:Name) $ "START/ENDE"
      Error(ACHTUNG+"Beginn liegt nach Ende.",.t.)
      RETURN(.f.)
    endif
  endif

RETURN(.t.)
/* EOF */

/** temp function, sp�ter obsolete
  kopiert die EKPr aus TArtikel (Test) in den Artikel */
procedure TestEKUpdate()
  if ! TEST_PROG
    Error("Auf dem Prod.System nicht empfohlen!!!")
  endif
  if message("EK aus Test-System �bernehmen? (@J@/@N@)", "JN"," ")=="J"
    if open("Artikel")
      select 0
      use (".\import\Artikel.dbf") alias Test
      index on TEST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE EXCLUSIVE

      select Artikel
      loca for ARTIKEL->Art=="B" .and. ! empty(ARTIKEL->KonsigKdNr)
      Protokoll(INIT_P,"Artikel �bernahme EK Preise Beistellteile","ArtNr     Bezeichung          "+;
        "          Art KdNr          EK Prod            Test")
      do while ! ARTIKEL->(eof())
        TEST->(dbseek( ARTIKEL->Artnr))
        if ARTIKEL->EkPr <> TEST->EKPr .and. rec_lock(0)
          Protokoll(PROTOKOLL,out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+" "+ARTIKEL->Art+space(1)+;
            ARTIKEL->KonsigKdNr+ str(ARTIKEL->EKPr,14,2) + " => " + str(TEST->EkPr,12,2))
          replace ARTIKEL->EkPr with TEST->EKPr
          replace ARTIKEL->Art with "E"
          dbcommit()
          dbunlock()
        endif
        cont
      enddo
    endif
    Protokoll(P_CREATE_PDF,,,,.t.)
    close data
    Preis_Check(.f.) // ohne Abfrage !
  endif
return
  /** eop */


/** Markiere Artikel dass Lagerbestand kontrolliert/ok ist */
procedure toggleMarkArtikelBestand()
LOCAL oai, ABs:=""

  if empty(ARTIKEL->Best_OK)
    Umgebung(WRITE)
    Message("ABs werden gesucht.   Bitte warten...")
    oai:=ArtikelInfo():new()
    //oai:addAllAuftragsBedarf()
    ABs:=oai:getABNummern(.t.)
    if empty(ABs)
      ABs:="ohne"
    endif
    Umgebung(LOAD)
  endif

  // r�ckschreiben
  select Artikel
  if rec_lock(5)
    replace ARTIKEL->Best_OK with ABs
    dbcommit()
    dbunlock()
  endif
return
/** eop */

function getEmailFooter()
LOCAL;
  temp:=strtran(getTranslation("allgemein.email.footer",LAND->Sprache), BACKSLASH+" ", MY_CR+MY_LF)
return temp
  /** eof */



/** Listet alle Unterartikel (M oder/und F) auf mit Summe der R�st und Fertigungs-Zeiten */
procedure listArtikelZeiten()
LOCAL children, child, mArtNr, parent
LOCAL Zeile:=0, Menge:=1, art:="B"
LOCAL akt_Farbe:=setcolor(), aktArtNr:=ARTIKEL->ArtNr
LOCAL Stueckliste, Maschinen, maschine, RuestZeit, stkstunde
LOCAL gesRuestZeit:=0, gesZeit:=0, total:=0
LOCAL GetList:={}

  Umgebung(WRITE_ALL)
  setcolor(COLWIN)
  @ 9,28 clear to 13,50
  @ 9,28 to 13,50
  @ 10,30 say "Menge......:" get Menge picture "99999";
    when Message("Zeiten berechnen.   Bitte Menge eingeben.")
  @ 12,30 say "Art (F/M/B):" get art picture "!" valid ART $ "FMB" when ;
    Message("Art eingeben.   @F@ertigungsartikel/@M@ontageartikel/@B@eides.")
  // read ->
  Read
  setcolor(akt_Farbe)
  if ABBRUCH
    Umgebung(LOAD)
    return
  endif

  parent:=StueckListe():new(ARTIKEL->ArtNr, ARTIKEL->Art, Menge)
  children:=parent:getChildren("M",.t.,.t.)
  children[parent:artNr]:=parent // add Hauptartikel to Liste

  Drucker("BS")
  ? "Art.Nr       Bezeichnung                   Art       Menge Stk/Std R�stz. Zeit"
  ? "=============================================================================="
  for each mArtNr in children:Keys
    ARTIKEL->(dbseek(martnr))
    if (art=="B" .and. ARTIKEL->Art $ "FM") .or. (art<>"B" .and. ARTIKEL->Art $ art)
      child:=children[mArtNr]

      if mArtnr==aktArtNr
        ? COLOR_RED
      else
        ?
      endif
      ?? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Art,str(child:menge,12,2),COLOR_DEFAULT

      stueckliste:=Stueckliste():new(mArtNr, ARTIKEL->Art)
      Maschinen:=stueckliste:getZeiten(,,.t.) // alle Maschinen inkl. Nebenmaschinen
      ruestZeit:=0
      stkstunde:=1
      // raus 20241014: nutzen:=val(stueckliste:getWerkzeugMenge())
      for each maschine in Maschinen
        ruestZeit:=Maschine:RuestZeit // raus 20241014: / nutzen
        stkstunde:=Maschine:Menge
        MASCHINE->(dbseek(maschine:artNr))
        if mArtnr==aktArtNr
          ? COLOR_RED
        else
          ?
        endif
        ?? space(len(out(ARTIKEL->ArtNr))),MASCHINE->HauptKz+":  ",maschine:artNr,MASCHINE->bez,;
          str(StkStunde,7,2),str(RuestZeit,5,2),str(child:menge/StkStunde,7,2),COLOR_DEFAULT
        gesRuestZeit += RuestZeit
        gesZeit += child:menge/StkStunde
      next
    endif
  next
  ? "=============================================================================="
  ? space(59),str(gesRuestZeit,10,2),str(gesZeit,7,2)
  ?
  total = gesRuestZeit + gesZeit
  ?;
    padl("Gesamtzeit: "+alltrim(str(int(total)))+"h "+alltrim(str((total-int(total))*60,6,0))+;
    "min",78)

  Drucker("OFF")
  Umgebung(LOAD)
return
  /** eop */


/* 
  * liest Preise f�r ehem. Beistellteile ein:
  *  - �bernimmt VK f�r alle Artikel in der Liste
  *  - Berechnet BeiEK und BeiKaPr f�r alle Artikel neu
  *  - Berechnet f�r diese Artikel den VK  (Diff + 30%) und schreibt Preishistorie
  */
procedure honselBeiEKEinles()
LOCAL DateiName:=".\import\test.csv", rows, row
LOCAL Zeile:=0, notFound:={}

  cls
  titel("Honsel Preisliste (ehem. Beistellteile) einlesen")

  if ! AT_HOME
    if (Dateiname:=openFileDialog(LOAD,IMPORT,NIL,"csv",nil))==NIL
      close data
      return
    endif
  endif

  if open("Artikel", "Artpreis")
    select Artikel
    rows:=FParse(DateiName, ";")
    for each row in rows
      message("Suche: "+row[1])

      locate for trim(no_blanks(row[1]))==Trim(no_blanks(ARTIKEL->Hartnr))
      if ARTIKEL->(eof())
        aadd(notFound, row)
      else
        rec_lock(0)
        replace ARTIKEL->EKPR with val(row[3])
        replace ARTIKEL->KAPR with ARTIKEL->EKPR * 1.2
        dbcommit()
        dbunlock()
        addPreisHistorie("Honsel Preiserh�hung")
      endif
    next

    if len(notFound) > 0
      drucker("BS")
      ? "Folgende Artikel wurden nicht gefunden:"
      for each row in notFound
        ? row[1], row[2], row[3]
      next
      drucker("OFF")
    endif
  endif
  close data

  SummierBeistellJeArtikel()

return
/** eop */

  /*
  * - summiere alle Beistellteile (rek) pro Artikel mit Konsig-Kd.Nr 10167
  * - schreibe die Summe in den Art.Stamm & Preishistorie
  * - erh�he VK Um Differenz + 30%
  */
PROCEDURE SummierBeistellJeArtikel()
LOCAL summeEk:=0, summeKaPr:=0, ka, ek, aktRec, mArtNr, isBeistellteil
LOCAL diff, neuVK, Zeile:=0, histText, tz

  cls
  titel("Summiere Honsel-Beistellteile je Artikel")

  if ! open( "Artikel" , "AvPost","Einheit","BeisTemp","Manbeist")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  Drucker("PDF")
  ? "Honsel Preiserh�hung vom "+dtoc(getUser():date)
  ? replicate("=",30)
  ? "Art.Nr.  Bezeichung                       Art Beistell. Ka.Pr   Diff     TZ             VK"
  ? "                                              vorher  nachher          +30%       vorher  "+;
    "nachher"
  ? replicate("=",97)

  /* Relationen setzen */
  select Artikel
  set relation to ARTIKEL->ME into Einheit
  select Beistemp
  set relation to BEISTEMP->ArtNr into Artikel

  select Artikel
  set filter to ! left(ARTIKEL->ArtNr,1)=="E" .and. .not. ARTIKEL->Art $ "X"
  go top
  Message("Bitte warten")
  do while ! ARTIKEL->(eof())
    // extrahiere Beistellteile rekursiv
    @ 24,0 say "Pr�fe "+out(ARTIKEL->ArtNr)
    aktRec:=ARTIKEL->(recno())
    mArtNr:=ARTIKEL->ArtNr
    isBeistellteil:=(getArtikelArt() $ "B" .and. ARTIKEL->KonsigKdNr == "10167-  ")
    // if trim(ARTIKEL->artnr)="5017890"
    // altd()
    // endif
    select Beistemp
    zap
    BeistellRek(mArtNr,1,NIL,"10167-  ")

    /** aufsummieren **/
    select BeisTemp
    go top
    if ! BEISTEMP->(eof()) .or. isBeistellteil
      summeEk:=summeKaPr:=0
      do while ! BEISTEMP->(eof())
        ka=IIF(ARTIKEL->Schluessel="H",ARTIKEL->KaPr/100,ARTIKEL->KaPr)
        ek=IIF(ARTIKEL->Schluessel="H",ARTIKEL->EKPr/100,ARTIKEL->EKPr)
        summeEk += round(ek * BEISTEMP->Menge,2)
        summeKaPr += round(ka * BEISTEMP->Menge,2)
        BEISTEMP->(dbskip())
      enddo
      ARTIKEL->(dbGoto( aktRec ))

      diff:=round(summeKaPr - ARTIKEL->BeiKaPr, 2)
      if diff > 0
        select Artikel
        tz:=round(diff*1.3, 2)
        neuVK:=ARTIKEL->Preis1 + tz
        histText:=alltrim(str(ARTIKEL->BeiKaPr,11,2))+"->"+alltrim(str(summeKapr,11,2))+"="+;
          alltrim(str(diff,11,2))+"+30% =>"+ alltrim(str(tz,11,2))+EURO_SIGN+" TZ"

        ? out(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Art,str(ARTIKEL->BeiKaPr,8,2),;
          str(summeKaPr,8,2),str(diff,6,2),str(tz,6,2), ARTIKEL->Preis1,str(neuVk,8,2)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2

        if rec_lock(0)
          replace ARTIKEL->BeiEK with summeEK
          replace ARTIKEL->BeiKaPr with summeKaPr
          replace ARTIKEL->Preis1 with neuVK
        endif
        dbcommit()
        dbunlock()

        // schreibe Preis-Historie
        addPreisHistorie(histText)

      endif
    endif
    ARTIKEL->(dbGoto( aktRec ))
    select Artikel
    skip
  enddo
  Drucker("OFF")
  close data
return
/** eop */

  /*
  * kopiere Daten aufs Test-System
  */
PROCEDURE copyDat2Test()
LOCAL dir:=getProperty("System.test.dir","P:\MikiTest")
LOCAL Auswahl, logins:=getLogins(dir), login

  cls
  titel("Daten von PROD -> TEST kopieren")

  @ 5,12 to 10,70
  @ 6,15 say "Auswahl:"
  @ 8,15 Prompt "1. Datenbestand gestern Abend (schnell)"
  @ 9,15 Prompt "2. Aktueller Datenbestand     (langsam)"

  if len(logins) > 0
    @ 12,15 say "Folgende Benutzer sind im Test-System eingeloggt:"
    for each login in logins
      qout(space(14),login)
    next
  endif

  Message("Ihre Auswahl bitte.                  @ESC@=Ende")
  Menu to Auswahl

  if ABBRUCH
    close data
    return
  endif

  if len(logins) > 0
    if .not. Message("Eingeloggte Benutzer im Testsystem ignorieren?  (@J@/@N@)","JN"," ") == "J"
      close data
      return
    endif
  endif

  if Auswahl == 0
    Message("Backup wird erstellt.    Bitte warten...")
    autoBackupData(.f.)
  endif


  close data
  cls
return

  /** Temp. Procedure, sp�ter obsolete? */
PROCEDURE honselPreisErhoehung()
LOCAL mArtNr, altPreis, allArtNr:=hb_hash(), children, child, maxGr
LOCAL Grund:=left("Preiserh�hung Honsel"+space(30),30)
LOCAL GetList:={}
LOCAL erhoehung, lastArtNr:=""
LOCAL oExcel, oAS, objErr, DateiName:=hb_cwd()+".\import\Preise.xlsx"
LOCAL ArtNrVon, ArtNrBis, PrGr, Proz, Zeile, gr, GeratProz, text, neuGr

  cls
  titel("Preiserh�hung Honsel / Artikel-Preisgruppen")

  @ 10,20 say "Grund:" get grund
  read

  if ABBRUCH
    cls
    return
  endif

  if ! AT_HOME
    backup("Artikel","pre-Preis-Erhoehung")
  endif

  if open("Artikel","AvPost","ArtPreis","ArtPrGr")
    select Artikel

    Protokoll(INIT_P, "Honsel Preiserh�hung")

    oExcel:=openExcelWorkbook( DateiName )
    oAS:=oExcel:ActiveSheet()
    zeile:=2 // starte in 2. Zeile, ignoriere �berschrift
    do while ! empty( oAS:Cells( zeile , 1 ):Value )
      BEGIN SEQUENCE
        if oAS:Cells( zeile , 5 ):Value != NIL .or. oAS:Cells( zeile , 6 ):Value != NIL
          ArtNrVon:=trim(no_blanks(no_dots(oAS:Cells( zeile , 2 ):Value)))
          ArtNrBis:=trim(no_blanks(no_dots(oAS:Cells( zeile , 3 ):Value)))
          PrGr:=oAS:Cells( zeile , 4 ):Value
          if oAS:Cells( zeile , 5 ):Value == NIL
            GeratProz:=0
          else
            GeratProz:=oAS:Cells( zeile , 5 ):Value
          endif
          if oAS:Cells( zeile , 6 ):Value == NIL
            Proz:=0
          else
            Proz:=oAS:Cells( zeile , 6 ):Value
          endif
          text:=oAS:Cells( zeile , 7 ):Value

          // Preisgruppe anlegen
          ARTPRGR->(dbseek(trim(PrGr)))
          if ARTPRGR->(eof()) .and. .not. empty(PrGr)
            select ArtPrGr
            add_rec(0)
            replace ARTPRGR->PrGr with prgr
            replace ARTPRGR->text with text
            if Geratproz <> NIL
              replace ARTPRGR->ProzGerat with GeratProz
            endif
            if proz <> NIL
              replace ARTPRGR->ProzTeil with proz
            endif
            dbcommit()
            dbunlock()
            select Artikel
          endif

          ARTIKEL->(dbseek(ArtNrVon, .t.)) // soft seek
          do while ! ARTIKEL->(eof()) .and. trim(ARTIKEL->ArtNr) <= ArtNrBis

            // add Ober-Artikel
            if hb_HHasKey( allArtNr, ARTIKEL->ArtNr)
              aaddUnique(allArtNr[ARTIKEL->ArtNr],prgr)
            else
              allArtNr[ARTIKEL->ArtNr]:={prgr}
            endif

            // schreibe Gruppe nach Artikel-Stamm
            rec_lock(0)
            replace ARTIKEL->PrGr with PrGr
            dbcommit()
            dbunlock()

            // add Unter-Artikel
            children:=StueckListe():new(ARTIKEL->ArtNr, ARTIKEL->Art, 1):getChildren("M",.t.,.t.)
            for each child in children
              if hb_HHasKey( allArtNr, child:artNr)
                aaddUnique(allArtNr[child:artNr],prgr)
              else
                allArtNr[child:artNr]:={prgr}
              endif
            next
            ARTIKEL->(dbskip())
          enddo
        endif
      RECOVER using objErr
        altd() // okay im Fehlerfall in Debug Modus
        qout(zeile)
        wait
      END SEQUENCE
      zeile++
    enddo
    oExcel:DisplayAlerts:=0
    oExcel:Quit()
    zeile:=0

    // Material erh�hen
    select Artikel
    for each mArtNr in allArtNr:keys
      // if trim(mArtNr) == "5110955"
      // altd()
      // endif
      ARTIKEL->(dbseek( mArtNr ))
      // finde h�chste Gruppe f�r Ersatzteil
      if empty(ARTIKEL->PrGr)
        maxGr:=""; erhoehung:=0
        for each gr in allArtNr[martNr]
          ARTPRGR->(dbseek(gr))
          if ARTPRGR->ProzTeil > erhoehung
            maxGr:=gr
            erhoehung:=ARTPRGR->ProzTeil
          endif
        next
        if ARTIKEL->Preis1 > 0 .and. ! empty(substr(maxGr,4)) .and. erhoehung > 0
          neuGr:=left(ARTIKEL->ArtNr,3)+substr(maxGr,4)
          rec_lock(0)
          replace ARTIKEL->PrGr with neuGr
          dbcommit()
          dbunlock()
          // Artikel PreisGruppe anlegen, falls noch nicht vorhanden
          ARTPRGR->(dbseek(neuGr))
          if ARTPRGR->(eof())
            select ArtPrGr
            add_rec(0)
            replace ARTPRGR->PrGr with neuGr
            // replace ARTPRGR->text with text
            replace ARTPRGR->ProzTeil with erhoehung
            dbcommit()
            dbunlock()
            select Artikel
          endif
        endif
      else
        ARTPRGR->(dbseek(ARTIKEL->PrGr))
        maxGr:=ARTIKEL->PrGr // Gruppe f�r Ger�t eindeutig (aus Excel Liste)
        erhoehung:=ARTPRGR->ProzGerat
      endif
      altPreis:=ARTIKEL->Preis1
      if erhoehung > 0
        if ARTIKEL->Preis1 > 0
          rec_lock(0)
          replace ARTIKEL->Preis1 with round((ARTIKEL->Preis1 * (1 + erhoehung/100))+0.005,2)
          schreibeHistorie(grund, erhoehung)
          protokoll(PROTOKOLL, out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+" ["+;
            left(array2readable(allArtNr[martNr]," ")+"] -> "+ARTIKEL->PrGr+space(40),40)+;
            str(erhoehung,6,2)+"%   VK:"+str(altPreis,11,2)+" ->"+str(ARTIKEL->Preis1,11,2))
          dbcommit()
          dbunlock()
        else
          protokoll(PROTOKOLL, out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+" ["+;
            left(array2readable(allArtNr[martNr]," ")+"] -> "+ARTIKEL->PrGr+space(40),40)+"          VK: 0")
        endif
      endif

    next
    Protokoll(P_CREATE_PDF,,,,.t.)

    // setze alle Prozente auf 0 um doppelt Ausf�hrung zu verhindern
    select ArtPrGr
    go top
    do while ! ARTPRGR->(eof())
      rec_lock(0)
      replace ARTPRGR->ProzGerat with 0
      replace ARTPRGR->ProzTeil with 0
      dbcommit()
      dbunlock()
      skip
    enddo

    // importierte Datei nach done schieben
    mkMyDir(IMPORT_DONE)
    frename( replaceWindowsSlashes( DateiName ) , IMPORT_DONE +;
      BACKSLASH + getFileName(DateiName) )

    close data
  endif
return

/** schreibt einen Eintrag in die Preishistorie, mit den aktuellen Artikel Preisen */
static procedure schreibeHistorie(grund, proz)
  // schreibe Preis-Historie
  select ArtPreis
  add_rec(0)
  replace ARTPREIS->ArtNr with ARTIKEL->ArtNr
  replace ARTPREIS->Art with getArtikelArt()
  replace ARTPREIS->EKPreis with ARTIKEL->EKPr
  replace ARTPREIS->KalkPreis with ARTIKEL->KaPr
  replace ARTPREIS->VKPreis with ARTIKEL->Preis1
  replace ARTPREIS->Datum with getUser():date
  replace ARTPREIS->Kurzel with "MW"
  replace ARTPREIS->Grund with trim(Grund)+" "+alltrim(str(proz,6,2))+"%"
  select Artikel

return

  /** Erh�ht die VKs in allen offen ABs von 10167 und 10363 (Honsel & VVG) */
PROCEDURE honselABErhoehung()

  if !;
    open("Aufaus","Kunden","aufpost","Einheit","Artikel","AvPost","Auftrag","M_Mehrf","BesAus","KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("VK Anpassung offene ABs von 10167/10363")

  if Message("Neue Artikel VKs in offene ABs Honsel & VVG �bernehmen?","JN"," ")=="J" .and.;
    ! ABBRUCH

    Message("Datei wird sortiert.   Bitte warten...")

    /* Relation setzten */
    SELECT AufPost
    SET RELATION TO AUFPOST->ME INTO Einheit, to AUFPOST->ArtNr into Artikel,;
      TO AUFPOST->AufNr into AUFAUS

    index on AUFPOST->Kundnr+AUFPOST->AufNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for (left(AUFAUS->KundNr,5)$"10167/10363" .or.;
      left(AUFAUS->V_KundNr,5)$"10167/10363" .or.;
      left(AUFAUS->R_KundNr,5)$"10167/10363") .and.;
      ! AUFAUS->AufArt$"AGN" .and. AUFAUS->erledigt<>"J" .and. AUFPOST->GeliefGes < AUFPOST->Menge

    Protokoll(INIT_P, "Honsel AB Preisanpassung")

    go top
    do while ! AUFPOST->(eof())
      Message("Kopiere AB-Nr.: "+AUFPOST->AufNr)
      if AUFPOST->Preis <> ARTIKEL->Preis1
        protokoll(PROTOKOLL, AUFPOST->AufNr+" "+AUFAUS->KurzName+" "+out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+;
          " VK:"+str(AUFPOST->Preis,11,2)+" ->"+str(ARTIKEL->Preis1,11,2))
        rec_lock(0)
        replace AUFPOST->Preis with ARTIKEL->Preis1
        dbcommit()
        dbunlock()
      endif
      skip
    enddo

    Protokoll(P_CREATE_PDF,,,,.t.)
    close data
  endif
return

/* Storniere Waraus / Historien Buchung anhand von ProgrammNamen */
procedure undoWaraus()
LOCAL progr:="Fe.Meld. 170 ->5015483 Storno"
LOCAL length:=len(progr)
LOCAL text:="Fehlbuchung: Fe.Meld. 170"
LOCAL aktRec, stornoMenge, zeile:=0

  if ! message("Korrigiere Waraus?  (@J@/@N@)","JN"," ")=="J"
    cls
    return
  endif

  if ! open("Waraus","Artikel")
    Error(TRY_AGAIN)
    close data
    cls
    RETURN
  endif

  // Korigiere mehrfach ausf�hrung

  select Waraus
  loca for trim(WARAUS->Programm)==text

  drucker("BS")
  ? "Korrigier Doppel-Storniere Artikel Bewegungen:"

  do while ! WARAUS->(eof())

    if WARAUS->(recno()) <= 1124816
      stornoMenge:=WARAUS->Best
      aktRec:=WARAUS->(recno())
      ARTIKEL->(dbseek(WARAUS->ArtNr))
      select Artikel
      if rec_lock(5)
        Replace ARTIKEL->LageBest with stornoMenge
        dbcommit()
        dbunlock()
      endif
      ?;
        ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(WARAUS->Menge,10,2)+" "+dtoc(WARAUS->Datum)+" "+;
        WARAUS->Programm+" "+str(ARTIKEL->LageBest)
      select Waraus
      WARAUS->(dbGoto( aktRec ))
    else
      if rec_lock(5)
        ? WARAUS->ArtNr+" "+str(WARAUS->Menge,10,2)+" "+dtoc(WARAUS->Datum)+" deleted"
        delete
        dbcommit()
        dbunlock()
      endif
    endif
    cont
  enddo
  drucker("OFF")
  close data

  // select Waraus
  // loca for left(WARAUS->Programm,length)==progr

  // drucker("BS")
  // ? "Storniere Artikel Bewegungen:"

  // do while ! WARAUS->(eof())
  // stornoMenge:=WARAUS->Menge
  // // urspr. Buchung ohne Storno Text
  // if empty(WARAUS->InLfdNr)
  // if rec_lock(5)
  // replace WARAUS->Programm with left(WARAUS->Programm, len(trim(WARAUS->Programm))-6)
  // dbcommit()
  // dbunlock()
  // endif
  // else
  // // Unterbuchung r�ckg�ngig machen
  // aktRec:=WARAUS->(recno())
  // ARTIKEL->(dbseek(WARAUS->ArtNr))
  // select Artikel
  // if rec_lock(5)
  // ? ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(WARAUS->Menge,10,2)+" "+dtoc(WARAUS->Datum)+" "+WARAUS->Programm
  // aendArtBest(stornoMenge*(-1),text)
  // dbcommit()
  // dbunlock()
  // endif
  // select Waraus
  // WARAUS->(dbGoto( aktRec ))
  // endif
  // cont
  // enddo
  // drucker("OFF")
  // close data

return

/* opens artreserv nicht exkl. und returned ArtResKop als liste   */
function copyArtReserv(mArtNr)
LOCAL result:={}, reserv
LOCAL aktSel:=alias()
  if openArtReserv(13,.f.) // not exclusive
    if mArtNr == NIL
      go top
    else
      ARTRESERV->(dbseek(mArtNr))
    endif
    do while ! ARTRESERV->(eof()) .and. (mArtNr==NIL .or. ARTRESERV->ArtNr == mArtnr)
      reserv = ArtikelDisponiert():new( ARTRESERV->ArtNr, ARTRESERV->Art)
      reserv:Tiefe:=ARTRESERV->Tiefe
      reserv:LageBest:=ARTRESERV->LageBest
      reserv:AbPostNr:=ARTRESERV->AbPostNr
      reserv:menge:=ARTRESERV->Menge
      reserv:disponiert:=ARTRESERV->Disponiert
      reserv:fehlMenge:=ARTRESERV->FehlMenge
      reserv:topFaktor:=ARTRESERV->topFaktor
      reserv:AlternZu:=ARTRESERV->AlternZu
      aadd( result , reserv)
      ARTRESERV->(dbskip())
    enddo
    close ARTRESERV
    select (aktSel)
  endif
return result
/** eof */


/** return true if 1st St�ckliste contains 2nd artNr */
FUNCTION containsChild(pArtNr, mArtNr)
LOCAL stueck:=StueckListe():new( pArtNr )
return stueck:containsChild( mArtNr , .t. )
  /** eof */

PROCEDURE DeleteCDXRecursive(cDir)
LOCAL aFiles, aSubDirs, cFile, cSubDir

  close data

  // Get all .cdx files in the current directory
  aFiles:=Directory(cDir + "*.*")
  FOR EACH cFile IN aFiles
    IF Lower(Right(cFile[1], 4)) == ".cdx" // Check if file extension is .cdx (case-insensitive)
      @ 24,0 say "Deleting: " + cDir + cFile[1]+space(10)
      IF FErase(cDir + cFile[1]) <> 0
        TroubleEmail("Index kann nicht gel�scht werden: "+cDir + cFile[1])
      ENDIF
    endif
  NEXT

  // Get all subdirectories in the current directory
  aSubDirs:=Directory(cDir + "*.*", "D") // Fetch directories only
  FOR EACH cSubDir IN aSubDirs
    IF cSubDir[1] != "." .AND. cSubDir[1] != ".." // Ignore special entries
      DeleteCDXRecursive(cDir + cSubDir[1] + BACKSLASH) // Recur for subdirectory
    ENDIF
  NEXT
RETURN

/** pr�ft ob es innerbetr. Auftr�ge mit geloescht=="J" gibt.

Kam am 6.2.25 vor, mehrere innerbetr. Auftr�ge waren in Inner.dbf als geloescht markiert
(f�lschlicherweise)

Letztes Ereignis: 10.11.25, alle innerbetr. Auftr�ge mit der gleichen AB: 28292

FIXME: obsoelete sobald Fehler gefunden.
*/
procedure checkInnerGeloescht()
LOCAL protName, count:=0

  if open("Inner","Artikel")
    Protokoll(INIT_P,"Innerbetr. Auftr�ge wieder herstellen","AB.Dat. Inner.Lfd.Nr. Mappe         "+;
      "   Art.Nr.     Bezeichnung                         Menge")

    select Inner
    loca for INNER->geloescht=="J"
    set rela to INNER->ArtNr into Artikel

    do while ! INNER->(eof())
      @ 24,0 say INNER->InLfdNr

      protokoll(PROTOKOLL, dtoc(INNER->AufDat)+" "+INNER->INLFDNR+" "+INNER->InnerNr+"             "+;
        out(INNER->ArtNr)+" "+ARTIKEL->Bez1+" "+str(INNER->Menge))
      count++

      if rec_lock(5)
        replace INNER->geloescht with " "
        dbcommit()
        dbunlock()
      else
        protokoll(PROTOKOLL, "Fehler!!!")
      endif

      cont
    enddo
    Protokoll(P_CREATE_PDF,,,,.t.)
    protName:=Protokoll(P_FILE_NAME)
    if count > 0
      email(MY_EMAIL,"Fehler: Inner->Gel�scht: "+alltrim(str(count)),"Bitte pr�fen",protName)
    endif
    close data
  endif


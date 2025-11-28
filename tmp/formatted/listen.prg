/* Listen
*
* Enth�lt alle Listen (rest in Listen2.prg)
*/

#include "Zeige.ch"
#include "Miki.ch"
#include "error.ch"
#include "Setcurs.ch"
#include "hbclass.ch"

/* Procedure Liste_allg  ******************************************
*
* enth�lt einfache generelle Listen-Generationen
*/
PROCEDURE Liste_Allg(cDatei)
LOCAL Bauch:="" ,Bauch2:="" , Titel:="",KopfText:="", Bed:={ || .t.}
LOCAL von,bis,FeldNr,m_einheit:=" ",m_kundnr:=space(8)
LOCAL GetList:={} , Ausw
LOCAL kom:=""

MEMVAR buffer
PRIVATE buffer:=""

  do CASE
    /* Artikel-Liste neg. Bestand */
  case upper(cDatei)=="NEG_BEST"
    if ! open( "Artikel" , "Einheit")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif
    /* Relation setzen */
    select Artikel
    set relation to ARTIKEL->ME into Einheit

    KopfText:="L A G E R - Bestandsliste  (neg. Bestand)"
    Titel:="Art.Nr.   Bezeichnung                LagerBestand  ME  Lagerort"
    Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Lagebest"+;
      ",EINHEIT->Text,getArtikelLagerOrt(30) }"

    Bed:={ || ARTIKEL->LageBest < 0 }

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,von,bis,FeldNr,"Neg.Lagerbestand",Bed)

    /* Artikel-Liste Kauf-Artikel */
  case upper(cDatei)=="KAUF_ARTIKEL"
    if ! open( "Artikel" , "Einheit")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif
    /* Relation setzen */
    select Artikel
    set relation to ARTIKEL->ME into Einheit

    KopfText:="Kauf-Artikel"
    Titel:="Art.Nr.   Bezeichnung                LagerBestand  ME  Lagerort              EK"
    Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Lagebest"+;
      ",EINHEIT->Text,getArtikelLagerOrt(11),ARTIKEL->EkPr }"

    Bed:={ || ARTIKEL->EkPr > 0 }

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,von,bis,FeldNr,"KaufArtikel", Bed )

    /* Artikel-Liste EK - KaPr < 20 % */
  case upper(cDatei)=="KA_CHECK"
    if ! open( "Artikel" , "Einheit")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif
    /* Relation setzen */
    select Artikel
    set relation to ARTIKEL->ME into Einheit

    KopfText:="Kalkulationspreisliste"
    Titel:="Art.Nr.   Bezeichnung                 LagerBestand           EK      Kalk.Pr.   %   "
    Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Lagebest"+;
      ",ARTIKEL->EKPr,ARTIKEL->KaPr,space(0),str((ARTIKEL->KaPr-ARTIKEL->EKPr)/ARTIKEL->EKPr*100,5,2) }"

    Bed:={ || ARTIKEL->KaPr<>0 .and. ARTIKEL->EkPr<>0 .and.;
      ((ARTIKEL->KaPr-ARTIKEL->EKPr)/ARTIKEL->EKPr*100) <= 19.99 }

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,von,bis,FeldNr,"KalkCheck", Bed )

    /* Artikel-Liste Mind.Best */
  case upper(cDatei)=="WERKZEUG"
    if ! open( "Artikel" , "Einheit")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif
    /* Relation setzen */
    select Artikel
    set relation to ARTIKEL->ME into Einheit

    KopfText:="L A G E R - BESTANDSLISTE (Werkzeuge)"
    Titel:="Art-Nr.   Bezeichnung                        Menge ME  Lagerort     Artikel  Eigner"
    Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Lagebest"+;
      ",EINHEIT->Text,getArtikelLagerOrt(11),ARTIKEL->Formrahmen,ARTIKEL->Eigner }"

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,von,bis,FeldNr,"Werkzeug",Bed)

    /* Honsel-Liste */
  case upper(cDatei)=="HONSNR"
    if ! open( "Artikel")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif

    cls
    titel("Honsel-Liste")
    @ 9,23 to 14,50
    @ 10,25 say "sortiert nach:"
    @ 12,25 Prompt "1. Artikel-Nr."
    @ 13,25 Prompt "2. HONSEL -Nr."
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw

    if ABBRUCH
      cls
      close data
      RETURN
    endif

    if Ausw=2
      Message("Datei wird sortiert.  Bitte warten...")
      index on ARTIKEL->HartNr tag TEMP_INDEX TEMPORARY ADDITIVE
      feldnr:=fieldpos("HartNr")
    endif

    KopfText:='Ersatzteilliste f�r HONSEL-Nietger�te      Stand:'
    Titel:='HONSEL-Nr.          Art.Nr.   Bezeichnung                              VK   ME   PE'
    Bauch:="{ ARTIKEL->HartNr,OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Preis1"+;
      ",space(2),ARTIKEL->ME,space(2),ARTIKEL->Schluessel }"

    Bed:={ || ! empty(ARTIKEL->HArtNr) }
    von:="" // keine Abfrage Artikel von bis mehr !

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,von,bis,FeldNr,"HonselErs", Bed )

    /* Liste je ME */
  case upper(cDatei)=="ME_LISTE"
    if ! open( "Artikel")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif

    cls
    titel("Artikel-Liste je ME")
    @ 9,23 to 14,50
    @ 10,25 say "Mengeneinheit:" get M_Einheit
    Message("Ihre Auswahl bitte.                  @F12@=Hilfe")
    read

    if ABBRUCH .or. empty(M_Einheit)
      cls
      close data
      RETURN
    endif

    Message("Datei wird sortiert.  Bitte warten...")
    set filter to ARTIKEL->ME=M_Einheit

    KopfText:='Artikel-Liste mit Einheit='+M_Einheit
    Titel:='Artikel-Nr.        Bezeichnung                              VK   ME   PE'
    Bauch:="{ OUT(ARTIKEL->ArtNr),ARTIKEL->Bez1,ARTIKEL->Preis1"+;
      ",space(2),ARTIKEL->ME,space(2),ARTIKEL->Schluessel }"

    von:="" // keine Abfrage Artikel von bis mehr !

    /* Liste ausdrucken / anzeigen */
    Liste("Artikel",KopfText,Titel,Bauch,,,,"Einheit")

  endcase

  cls
  close data
RETURN

/*
* erstellt einfache Liste:
* Parameter: cDatei:    Datei
*            KopfText:  Kopf-Zeile
*            Titel      Titel-Zeile
*            Bauch      Array Listen-Zeile
*            d_von      von-Wert aus vorhergehender Abfrag   , dann hier keine
*            d_bis      bis-Wert aus vorhergehender Abfrag   , Abfrage mehr !
*            FeldNr     Index-relevante FeldNr  , default:=1
*            BS_Titel   alternativer BS-Titel, default datei[D_KURZ]-Liste
*            Bed        zu erf�llende Bedingung (Codeblock)
*            Bauch2     Array Listen- 2. Zeile
*            Bed2       zu erf�llende Bedingung (Codeblock) 2. Zeile
*/
PROCEDURE Liste(cDatei,KopfText,Titel,Bauch,d_von,d_bis,FeldNr,Bs_Titel,Bed,Ausgabe,Bauch2,Bed2)
LOCAL GetList:={}
LOCAL Seite
LOCAL E_Zeile:=8 , E_Spalte:=20
LOCAL Zeile:=0
LOCAL von,bis , Zeilen_Laenge
LOCAL sel:=select()
LOCAL Laenge,Eingabe:=.t.
LOCAL UR,line
LOCAL Stop:=.f.
LOCAL Datei:=db_info(cDatei)

MEMVAR v,b,buffer
PRIVATE v,b
PRIVATE buffer:=""

  default FeldNr:=1
  default BS_Titel:=KopfText // Datei[D_KURZ]+" - Liste"
  default Bed:={ || .t. }

  set key K_F8 to copy_buffer("",oGet,"")

  von:="M->V"+fieldname(FeldNr)
  Bis:="M->B"+fieldname(FeldNr)
  &von:=space(len(&(FieldName(FeldNr))))
  &bis:=space(len(&(FieldName(FeldNr))))

  do while ! (ABBRUCH .and. empty(&von))

    cls
    titel(BS_Titel+" drucken")
    stop:=.f.
    Seite:=0

    if ! valtype(d_von)=="U"
      Eingabe:=.f.
      &von:=d_von
      &bis:=d_bis
    else

      &von:=space(len(&(FieldName(FeldNr))))
      &bis:=space(len(&(FieldName(FeldNr))))

      if Datei[D_ART]=="N"
        @ E_Zeile,E_Spalte say "von:" get &von PICTURE "@#";
          when;
          Message("1. "+Datei[D_KURZ]+" eingeben.     @Leer@=1. Datensatz");
          valid { |oGet| M->Buffer:=oGet:buffer, .t.}
        @ E_Zeile+2,E_Spalte say "bis:" get &bis PICTURE "@#";
          when Message("Letzten "+Datei[D_KURZ]+" eingeben.      @F8@=kopieren     @Leer@=letzter "+;
          "Datensatz")
      else
        @ E_Zeile,E_Spalte say "von:" get &von PICTURE "@!";
          when;
          Message("1. "+Datei[D_KURZ]+" eingeben      @Leer@=1. Datensatz");
          valid { |oGet| M->Buffer:=oGet:buffer, .t.}
        @ E_Zeile+2,E_Spalte say "bis:" get &bis PICTURE "@!";
          when Message("Letzten "+Datei[D_KURZ]+" eingeben.      @F8@=kopieren     @Leer@=letzter "+;
          "Datensatz")
      endif
      read

      if lastkey()==K_ESC
        set key K_F8 to
        close data
        RETURN
      endif
    endif

    select (sel)

    if empty(&bis) // bis letzten Datensatz
      go bottom
      &bis:=&(fieldname(FeldNr))
    endif

    if empty(&von) // von 1. Datensatz
      go top
      &von:=&(fieldname(FeldNr))
    else
      if indexord() > 0
        dbSeek( &(von) , .t. )
      endif
    endif

    do case
    case Ausgabe=="D"
      drucker("ON",BS_Titel)
    case Ausgabe=="BS"
      drucker("BS",BS_Titel)
    case Ausgabe=="PDF"
      drucker("PS",BS_Titel)
    case Ausgabe=="NOP"
    otherwise
      if ! druck_BS(BS_Titel) // Abbruch
        set key K_F8 to
        close data
        RETURN
      endif
      Message("Liste wird erstellt.  Bitte warten...       @ESC@=Abbruch")
    endcase

    Laenge:=DRUCKER->Laenge
    UR:=LISTE->UNT_RAND

    v:=&von
    b:=&bis

    KopfText:=left(KopfText+space(52),52)+" vom: "+dtoc(getUser():date)
    Zeilen_Laenge:=Max(len(KopfText)+10,len(Titel))
    line:=replicate(LINE_CHAR,Zeilen_Laenge)
    KopfText+=space(Zeilen_Laenge-len(KopfText)-9)+"Seite "

    // for i:=32 to 255
    // ? str(i,3),replicate(chr(i),20)
    // next
    // Zeile:=FormFeed(Zeile,Seite)

    /* Ausdruck der Liste */
    do while ! eof() .and. &(fieldname(FeldNr)) <= b .and. ! stop
      Seite++
      zeile:=0
      ? KopfText+str(Seite,3)
      ? line
      ? Titel
      ? line
      _____fixedHeader_____

      stop:=stop_key() // ESC gedr�ckt ?
      /* Listen-Bauch */
      do while ! eof() .and. &(fieldname(FeldNr)) <= b .and. Zeile < Laenge - UR .and. ! stop
        if eval(Bed)

          getUser():getCurrentPrintJob():print( &(Bauch) , .t. )
          zeile++

          // spezial L�sungen f�r ALT-Tasten z.B. Alt-B in Waraus
          if Ausgabe=="BS"
            if (alias()=="WARAUS")
              if WARAUS_BESTNR $ WARAUS->Programm
                replace ZEIGE->BestNr with ;
                  substr( WARAUS->Programm , at( WARAUS_BESTNR , WARAUS->Programm ) + len(WARAUS_BESTNR) , 5 )
              endif
              if ! empty( WARAUS->InLfdNr )
                replace ZEIGE->InLfdNr with WARAUS->InLfdNr
              endif
            endif
          endif

          if valtype(Bed2) <> "U" .and. eval(Bed2)

            getUser():getCurrentPrintJob():print( &(Bauch2) , .t. )
            zeile++

          endif
        endif
        skip
        stop:=stop_key() // ESC gedr�ckt ?
      enddo

      // ? line
      Zeile:=FormFeed(Zeile,Seite)

    enddo // Liste

    // Anmerkung: Drucker: JobName wird hier gel�scht, nimmt beim
    // nach dem 1. Mal in der loop wieder liste.dbf :(
    Drucker("Off")

    if ! Eingabe
      exit
    endif

  enddo // Endlos-Eingabe

  set key K_F8 to
RETURN
/* EOP Liste */


/*
* Rechnungsausgangsbuch
*
* Parameter:    Monat   .t. den kompletten Monat
*                       .f. nur die noch nicht gedruckten (t�gl.)
*
*/
PROCEDURE RechAus(Monat,Abfrage,wiederholen,overwrite)
LOCAL myDate:=getUser():date
LOCAL jahr
LOCAL Auswahl
LOCAL seite:=0,kom,vor
LOCAL pic:="@E 999,999.99"
LOCAL picSumme:="@E 999,999,999.99"
LOCAL Zeile:=0,i, Ende:=.f.,Getlist:={}
LOCAL sumNr, tempVal

LOCAL Stand_M_Netto:=0.00, Stand_M_Nben:=0.00, Stand_M_Mwst:=0.00, Stand_M_Betrag:=0.00
LOCAL Stand_M_Inl:=0.00, Stand_M_Ausl:=0.00, stand_M_pos:=0
LOCAL Stand_J_Netto:=0.00, Stand_J_Nben:=0.00, Stand_J_Mwst:=0.00, Stand_J_Betrag:=0.00
LOCAL Stand_J_Inl:=0.00, Stand_J_Ausl:=0.00, stand_J_pos:=0
LOCAL summenetto:=0.00,summemwst:=0.00,summebrutto:=0.00,summenben:=0.00,summerabatt:=0.00
LOCAL summeinl:=0.00,summeausl:=0.00,pos:=0
LOCAL count:=0,text
LOCAL myName:="RechAus-"+dtos(myDate),myPfad:=PS_PDF_REAUS,realFileName,kdnr, Ausgabe

  default Abfrage:=.t.
  default wiederholen:=.f.
  default overwrite:=.f. // berechnte Werte werden �berschrieben -> debug only!

  if ! Abfrage // automat. nachts um 2Uhr, also w�hle den Vortag als Datum
    if Monat
      do while month(myDate)==month(getUser():date) .and. year(mydate)==year(getUser():date)
        myDate--
      enddo
    else
      myDate--
    endif
  endif

  if ! open("Rechaus",{ "Summen" , .t. })
    close data
    cls
    if ! Abfrage
      break createErrorObject ("Rechaus oder Summen.dbf nicht verf�gbar.","RechAus","open",EG_OPEN)
    endif
    RETURN
  endif

  cls
  if Monat
    titel(' Rechnungsausgangsbuch Monat drucken')
    myName:="RechAus-"+left(dtos(myDate),6)
  else
    titel(' Rechnungsausgangsbuch (t�gl.) drucken')
    if Abfrage

      if wiederholen
        Select Summen
        go bottom
        sumNr:=SUMMEN->SumNr
        Message("Bitte Nr. Rechnungsausgangsbuch eingeben.    @F12@=Auswahl2")
        @ 10,20 say "Nr.:" get SumNr valid { |oGet| check(oGet,"Summen",.f.,.f.)}
        read

        if ABBRUCH
          close data
          cls
          return
        endif

        myDate:=SUMMEN->Datum

        SUMMEN->(dbskip(-1))
        if myDate==SUMMEN->Datum .and. SUMMEN->Datum<ctod("12.12.11")
          Error(ACHTUNG+" Rechnungsausgangsbuch vom: "+dtoc(mydate)+;
            " doppelt.||         Bitte 1. Datensatz ausw�hlen.",.t.)
          close data
          cls
          return
        endif


        // if BOF()
        // Error(ACHTUNG+" 1. Rechnungsausgangsbuch kann nicht wiederholt werden.",.t.)
        // close data
        // cls
        // return
        // endif

      else
        Error(ACHTUNG+"Rechnungsausgangsbuch wird jetzt automatisch|"+;
          "         als PDF ausgedruckt.",ERR_NO_WAIT)
        if Message("Trotzdem fortfahren?  (@J@/@N@)     @ESC@=Abbruch","JN")<>"J" .or. ABBRUCH
          cls
          close data
          return
        endif

        @ 5,0 clear
        @ 10,20 say "Datum:" get myDate ;
          when Message("Alle nicht gedruckten Rechnung bis einschl. diesem Datum drucken.  @ESC@=Abbruch")
        read

        if ABBRUCH
          close data
          cls
          return
        endif

      endif
    endif
  endif

  jahr:=year(myDate)
  Auswahl:=month(myDate)

  if Monat
    if Abfrage
      do while ! Ende
        @ 5,28 to 20,46
        Message("Bitte Monat ausw�hlen.           @ESC@=Ende")
        for i:=1 to 12
          @ 5+i,30 prompt chr(64+i)+". "+left(myCMonth(ctod("01."+str(i,2)+".80"))+space(10),10)
        next
        @ 5+i+1,30 prompt "Y. Jahr  "+str(jahr,4)
        Menu to Auswahl
        if Auswahl==13 // Jahr wechseln
          message("Neues Jahr eingeben.")
          @ 5+i+1,30 say "                "
          @ 5+i+1,30 say "   Jahr:" get Jahr picture "9999"
          read
          loop
        endif
        Ende:=.t.
      enddo
      if Auswahl==0 // ESC
        cls
        close data
        RETURN
      endif
    endif

    /* Filter setzen */

    select RechAus
    SET FILTER TO month(RECHAUS->readat)=Auswahl .and. year(RECHAUS->readat)=Jahr

    myName:="RechAus-"+str(Jahr,4)+right("0"+alltrim(str(Auswahl,2)),2)

  else

    if ! wiederholen
      select RechAus

      Message("Rechnungsausgangsbuch wird gepr�ft.  Bitte warten...")
      /* checken ob noch Vormonats-Rechnungen */
      locate for empty(RECHAUS->SumNr) .and. month(RECHAUS->ReaDat)<month(myDate) ;
        .and. ! empty(RECHAUS->ReaDat) .and. year(RECHAUS->readat)=Jahr

      if ! eof()
        if Abfrage
          Error(ACHTUNG+"Rechnungen des Monats: "+myCMonth(RECHAUS->ReaDat)+" noch nicht komplett "+;
            "gedruckt.|Bitte Tagesdatum r�cksetzten und Ausgangsbuch erneut drucken.",.t.)
          cls
          close data
          RETURN
        else
          tempVal:=myCMonth(RECHAUS->ReaDat)
          cls
          close data
          break createErrorObject ("Rechnungen des Monats: "+tempVal+" noch nicht komplett "+;
            "gedruckt.|Bitte Tagesdatum r�cksetzten und Ausgangsbuch erneut drucken.","RechAus","check",EG_CORRUPTION)
        endif
      endif
    endif


    /* Filter setzen */
    select Rechaus
    if wiederholen
      SET FILTER TO RECHAUS->SumNr==sumNr
      select Summen
    else
      SET FILTER TO empty(RECHAUS->sumnr) .and. RECHAUS->ReaDat<=myDate
      select Summen
      go bottom
    endif

    /* Hole Zw_Summen */
    if month(myDate)==month(SUMMEN->Datum)
      Stand_M_Netto:=SUMMEN->M_Netto
      Stand_M_Nben:=SUMMEN->M_Nben
      Stand_M_Mwst:=SUMMEN->M_Mwst
      Stand_M_Betrag:=SUMMEN->M_Betrag
      Stand_M_Inl:=SUMMEN->M_Inl
      Stand_M_Ausl:=SUMMEN->M_Ausl
      stand_M_pos:=SUMMEN->M_pos
    endif
    if year(myDate)==year(SUMMEN->Datum)
      Stand_J_Netto:=SUMMEN->J_Netto
      Stand_J_Nben:=SUMMEN->J_Nben
      Stand_J_Mwst:=SUMMEN->J_Mwst
      Stand_J_Betrag:=SUMMEN->J_Betrag
      Stand_J_Inl:=SUMMEN->J_Inl
      Stand_J_Ausl:=SUMMEN->J_Ausl
      stand_J_pos:=SUMMEN->J_pos
    endif
  endif // Monat

  if Abfrage
    Ausgabe:=Message("Ausgabe auf @D@rucker, @B@ildschrim oder in @P@DF Datei ?","DBP","D")
    if ABBRUCH
      cls
      RETURN
    endif
    @ 2,0 clear

    do case
    case Ausgabe == "B"
      Drucker("BS")
    case Ausgabe == "D"
      Drucker("ON",myName,myPfad,.f.,PDF_NO_CONFIRM)
    case Ausgabe == "P"
      Drucker("PDF",myName,myPfad,.f.,PDF_NO_CONFIRM)
    endcase
  else
    Drucker("ON",myName,myPfad,.f.,PDF_NO_CONFIRM)
  endif

  Message("Rechnungsausgangsbuch wird erstellt.  Bitte warten...")
  set marg to 6

  select Rechaus
  go top
  do while .not. RECHAUS->(eof())
    seite=seite+1
    Zeile:=0
    if Monat
      ? "Miki Plastik GMBH    *** Rechnungsausgangsbuch ***   (Monat)  vom:",myDate,space(7),;
        "Seite",str(Seite,3)
    else
      ? "Miki Plastik GMBH    *** Rechnungsausgangsbuch ***   (t�gl.)  vom:",myDate,space(7),;
        "Seite",str(Seite,3)
    endif
    ? "------------------------------------------------------------------------------------------"+;
      "---"
    ? "KD-Nr.   N a m e                            RE-Nummer AB-Nr.      Netto       MWST  "+;
      "RE-Betrag"
    ? "DATEV    PLZ / Ort                            -Datum  MWST%        Euro       Euro       "+;
      "Euro"
    ? "------------------------------------------------------------------------------------------"+;
      "---"
    do while .not. eof() .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand
      do case
      case RECHAUS->Aufart$"NG"
        kom:="GS"
      case RECHAUS->Aufart="A"
        kom:="Au"
      case RECHAUS->Aufart="S"
        kom:="St"
      otherwise
        kom:="Re"
      endcase

      count++
      ? KdOut(RECHAUS->Kundnr),RECHAUS->name,kom,RECHAUS->RechNr,space(0),RECHAUS->AufNr

      // bei werkzeug DATEV.Nr. von Rechhnungs-Empf�nger (laut Telefonat 3.1.2014 MW)
      if left(RECHAUS->V_KundNr,5) == MIKI_NR
        kdNr:=RECHAUS->R_KundNr
      else
        kdNr:=RECHAUS->V_KundNr
      endif

      if left(kdNr,5) <> left(RECHAUS->Kundnr,5)
        ? COLOR_RED , kdOut(kdNr) , COLOR_DEFAULT
      else
        ? space(len( kdOut(kdNr) ))
      endif

      ?? left(trim(RECHAUS->plz)+" "+RECHAUS->ort,34),RECHAUS->ReaDat,str(RECHAUS->mwst,5,2)+"%",
      ?? transform(RECHAUS->Netto,pic),transform(round(RECHAUS->netto*RECHAUS->mwst/100,2),pic),;
        transform(RECHAUS->Brutto,pic)

      /** aufsummieren */
      summenetto += RECHAUS->netto
      summemwst += round(RECHAUS->netto*RECHAUS->Mwst/100,2)
      summebrutto+= RECHAUS->brutto
      summenben += RECHAUS->nebenkost
      Pos++
      IF RECHAUS->MWST_KZ="0" // Ausland
        summeausl += RECHAUS->netto
      else // Inland
        summeinl += RECHAUS->netto
      endif

      skip
    enddo

    ? "------------------------------------------------------------------------------------------"+;
      "---"

    /** Seitenumbruch ? */
    if .not. eof()
      Zeile:=FormFeed(Zeile,Seite)
    else
      vor:=18*2 + 9
      if DRUCKER->Laenge-LISTE->Unt_Rand-zeile > vor
        do while zeile< DRUCKER->laenge - LISTE->Unt_Rand - vor
          ?
        enddo
      else
        Zeile:=FormFeed(Zeile,Seite)
        /**drucke Titelzeile */
        Seite++
        if Monat
          ? "Miki Plastik GMBH    *** Rechnungsausgangsbuch ***   (Monat)  vom:",myDate,space(5),;
            "Seite",str(Seite,3)
        else
          ? "Miki Plastik GMBH    *** Rechnungsausgangsbuch ***   (t�gl.)  vom:",myDate,space(5),;
            "Seite",str(Seite,3)
        endif
        ? "--------------------------------------------------------------------------------------"+;
          "-----"
        ?
      endif

      if Monat

        /* Jahr aufsummieren, Kontroll-Summe */
        SET FILTER TO year(RECHAUS->readat)=Jahr .and. month(RECHAUS->readat)<=Auswahl
        go top
        do while ! eof()
          Stand_J_Netto += RECHAUS->Netto
          Stand_J_Nben += RECHAUS->Nebenkost
          Stand_J_Mwst += round(RECHAUS->netto*RECHAUS->Mwst/100,2)
          Stand_J_Betrag += RECHAUS->brutto
          Stand_J_Pos++
          IF RECHAUS->MWST_KZ="0" // Ausland
            Stand_J_Ausl += RECHAUS->netto
          else
            Stand_J_Inl += RECHAUS->netto
          endif

          skip
        enddo

        ? "-------------------------------------------------------"
        ? "                                Kumulativ-Summen (Euro)"
        ? "                                    Monat          Jahr"
        ? "-------------------------------------------------------"
        ?;
          "Gesammtnettowert           "+transform(summenetto ,picSumme);
          +transform(Stand_J_Netto,picSumme)
        ?;
          "   - Inland                "+transform(summeinl ,picSumme);
          +transform(Stand_J_Inl,picSumme)
        ?;
          "   - Ausland               "+transform(summeausl ,picSumme);
          +transform(Stand_J_Ausl,picSumme)
        ?;
          "   - Nebenkosten/Verp.     "+transform(summenben ,picSumme);
          +transform(Stand_J_nben,picSumme)
        ?;
          "   - Mehrwertsteuer        "+transform(summemwst ,picSumme);
          +transform(Stand_J_Mwst,picSumme)
        ?;
          "   - Rechnungsendwert      "+transform(summebrutto,picSumme);
          +transform(Stand_J_Betrag,picSumme)
        ? "   - Positionen            "+str(pos,14)+str(Stand_J_Pos,14)
        ? "-------------------------------------------------------"

      else
        /* t�gl. noch aufsummieren */
        Stand_M_Netto +=summenetto
        Stand_M_Nben +=summenben
        Stand_M_Mwst +=summemwst
        Stand_M_Betrag+=summebrutto
        Stand_M_Inl +=summeinl
        Stand_M_Ausl +=summeausl
        Stand_M_Pos +=pos
        Stand_J_Netto +=summenetto
        Stand_J_Nben +=summenben
        Stand_J_Mwst +=summemwst
        Stand_J_Betrag+=summebrutto
        Stand_J_Inl +=summeinl
        Stand_J_Ausl +=summeausl
        Stand_J_Pos +=pos

        ? "---------------------------------------------------------------"
        ? "                                   Kumulativ-Summen (Euro)"
        ? "                                Tag         Monat          Jahr"
        ? "---------------------------------------------------------------"
        ? "Gesammtnettowert     "+transform(summenetto,picSumme) +transform(Stand_M_Netto ,picSumme) +;
          transform(Stand_J_Netto,picSumme)
        ? "- Inland             "+transform(summeinl ,picSumme) +transform(STand_M_Inl ,picSumme) +;
          transform(Stand_J_Inl,picSumme)
        ? "- Ausland            "+transform(summeausl ,picSumme) +transform(STand_M_Ausl ,picSumme) +;
          transform(Stand_J_Ausl,picSumme)
        ? "- Nebenkost./Verp.   "+transform(summenben ,picSumme) +transform(Stand_M_nben ,picSumme) +;
          transform(Stand_J_nben,picSumme)
        ? "- Mehrwertsteuer     "+transform(summemwst ,picSumme) +transform(Stand_M_Mwst ,picSumme) +;
          transform(Stand_J_Mwst,picSumme)
        ? "- Rechnungsendwert   "+transform(summebrutto,picSumme)+transform(Stand_M_Betrag,picSumme) +;
          transform(Stand_J_Betrag,picSumme)
        ? "- Positionen         "+str(pos,14)+str(Stand_M_Pos,14)+str(Stand_J_Pos,14)
        ? "---------------------------------------------------------------"

      endif
      Zeile:=FormFeed(Zeile,Seite)
    endif
  enddo

  // Drucker("Off")
  getUser():getCurrentPrintJob():endDoc()
  realFileName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if ! Monat .and. count>0 .and. ! wiederholen .and. ;
    (! Abfrage .or. Message("Ausdruck in Ordnung ? ( @J@ / @N@ ) ","JN")=="J")
    Message("Rechnungsausgangsbuch wird gespeichert.  Bitte warten...")
    IF FIL_LOCK(3)
      /* Summen speichern */
      select Summen

      if overwrite
        SUMMEN->(dbseek( sumNr ))
        rec_lock(0)
      else // neuer Datensatz
        go bottom
        sumNr:=right("00000"+alltrim(str(val(SUMMEN->SumNr)+1,5)),5)
        add_rec(0)
        replace SUMMEN->SumNr with SumNr
      endif

      replace SUMMEN->M_Netto with Stand_M_Netto
      replace SUMMEN->M_Nben with Stand_M_Nben
      replace SUMMEN->M_Mwst with Stand_M_Mwst
      replace SUMMEN->M_Betrag with Stand_M_Betrag
      replace SUMMEN->M_Inl with Stand_M_Inl
      replace SUMMEN->M_Ausl with Stand_M_Ausl
      replace SUMMEN->M_pos with stand_M_pos
      replace SUMMEN->J_Netto with Stand_J_Netto
      replace SUMMEN->J_Nben with Stand_J_Nben
      replace SUMMEN->J_Mwst with Stand_J_Mwst
      replace SUMMEN->J_Betrag with Stand_J_Betrag
      replace SUMMEN->J_Inl with Stand_J_Inl
      replace SUMMEN->J_Ausl with Stand_J_Ausl
      replace SUMMEN->J_pos with stand_J_pos
      replace SUMMEN->Datum with myDate

      select rechaus
      /* gedr. Rechnungen markieren */
      REPLACE ALL RECHAUS->SumNr WITH sumNr
      dbcommitall()
      unlock

    else
      if Abfrage
        ERROR(ACHTUNG+"Rechnungsausgangsbuch konnte nicht als gedruckt markiert werden.|"+;
          TRY_AGAIN)
      else
        break;
          createErrorObject;
          ("Summen.dbf nicht verf�gbar/schreiben.","RechAus","write",EG_CORRUPTION)
      endif
    endif
  endif

  if ! Abfrage .or. Ausgabe $ "PD"
    text:=if(Monat,"(monatl.)","(t�gl.)")
    // Email immer schicken auch bei Sperre
    if count > 0
      email(MAIN_EMAIL,"Rechnungsausgangsbuch "+text+" vom "+dtoc(myDate),;
        "Rechnungsausgangsbuch "+text+" vom "+dtoc(myDate),realFileName,.f.,.t.)
    else // Count =0
      email(MAIN_EMAIL,"Rechnungsausgangsbuch "+text+" vom "+dtoc(myDate)+" ist leer.",;
        "Rechnungsausgangsbuch "+text+" vom "+dtoc(myDate)+" ist leer.",nil,.f.,.t.)
    endif
  endif

  set filter to
  close data
  set marg to

  cls
RETURN
/* EOP Rechaus */

    /* PROCEDURE Niet-Stk_Liste()
*
*   St�ckliste je Nietgeraet
*
*  Parameter: Drucker (boolean)
*             falls aus Auskunft KEIN Drucker moeglich !
*
*/
PROCEDURE Niet_Stk_Liste()
LOCAL GetList:={}
LOCAL M_AvNr,M_Menge:=1

  cls
  titel("St�ckliste je Material drucken")

  if !;
    open("Artikel","Einheit","avaus","AvPost","Text","BesPost","Inner","Login","Aufaus","AufPost","Auftrag","Besaus","M_Mehrf")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." };
    )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  /* ACHTUNG andere order bei Bespot/Inner */
  select Inner
  INNER->(OrdSetFocus(2)) // inner
  select Bespost
  BESPOST->(OrdSetFocus(2)) // bespost
  /* Relationen setzten */
  select AvAus
  set relation to AVAUS->Avnr into Artikel
  select AvPost
  set relation to AVPOST->ArtNr into Artikel, to AVPOST->ArtNr into Text
  SELECT Artikel
  SET RELATION TO ARTIKEL->ME INTO Einheit

  M_AvNr:=space(len(AVAUS->AvNr))
  do while ! ABBRUCH
    Message("St�ckliste und Menge eingeben.     @F12@=Hilfe")
    @ 8,20 say "St�cklisten-Nummer:" get M_AvNr picture "@!";
      valid { |oGet| check(oGet,"AvAus",.f.,.f.) }
    @ 10,20 say "Menge.............:" get M_Menge picture "99999"
    read

    if ABBRUCH
      close data
      cls
      M->specialZeige:=NIL
      RETURN
    endif
    if getUser():mayPrint
      if ! druck_bs()
        M->specialZeige:=NIL
        close data
        cls
        RETURN
      endif
    else
      Drucker("BS")
    endif
    Message("Liste wird erstellt.  Bitte warten....")

    StkListLind(M_AvNr,M_Menge)

    Drucker("Off",,,,,,.f.) // ohne Popup!!!
  enddo
  M->specialZeige:=NIL
  cls
  close data
RETURN
/* EOP NietStk_Liste */


/*
 * druckt Stueckliste je Artikel
*/
static PROCEDURE StkListLind(M_AvNr, M_Menge, rekBedarf, zeigeFertigungsdauer, ignoreMenge)
LOCAL seite:=0, zeile:=0,x,TempVar
LOCAL Stop:=.f.,ges_Menge:=1,M_bez1,M_bez2,M_me,ges:=0,M_LgBest
LOCAL Zeichen:="",i:=0,bedarf
LOCAL linie:=replicate('-',132)
LOCAL akt_sel:=select()
LOCAL akt_rec:=recno()
LOCAL fertigungsdauer:=0

  default rekBedarf:=.f.
  default ignoreMenge:=.f.

  if valtype(zeigeFertigungsdauer) == "L" .and. zeigeFertigungsdauer
    fertigungsdauer:=M_Menge
  endif

  /* hole Stk-Listen-Text aus Artikel.dbf */
  // ARTIKEL->(dbseek(AVAUS->AvNr))
  AVAUS->(dbseek(M_AvNr))
  ARTIKEL->(dbseek(M_AvNr))
  M_bez1:=ARTIKEL->Bez1
  M_bez2:=ARTIKEL->Bez2
  M_LgBest=ARTIKEL->LageBest
  EINHEIT->(dbseek(ARTIKEL->ME))
  M_Me:=EINHEIT->Text

  select AvPost
  AVPOST->(OrdSetFocus(1)) // Hauptartikel + Unterartikel
  dbseek(M_AvNr)
  do while .not. AVPOST->(eof()) .and. AVAUS->AvNr=AVPOST->AvNr
    Seite=Seite+1

    zeile:=0 ; x:=1
    ? "St�ckliste f�r Artikel:",out(AVAUS->AvNr),FETT_AN,M_Bez1,FETT_AUS,space(3),;
      str(M_Menge,8,2),M_ME,space(1),getUser():date
    ? "                       ",space(len(out(AVAUS->AvNr))),M_Bez2,"Lg."+str(M_LgBest),M_ME
    for each tempVar in getStkListBemMaterial()
      ? tempVar
    next
    ? linie
    ? 'Art.Nr.      Bezeichnung                        Menge ME    Lg.Best   reserv verf�gbar    '+;
      'Bedarf Lg.Ort       Art  Bestellt Best.Nr.'
    ? linie
    _____fixedHeader_____

    x=1
    do while .not. AVPOST->(eof()) .and. AVAUS->AvNr=AVPOST->AvNr
      if AVPOST->Art="M".and. .not. empty(AVPOST->ArtNr) // Material
        ARTIKEL->(dbseek(AVPOST->ArtNr))
        If AVPOST->Text="A" // Artikel
          bedarf:=ARTIKEL->LageBest-max(ARTIKEL->disponiert,0)
          if .not. ignoreMenge
            bedarf -= (AVPOST->Menge*M_Menge)
          endif
          if bedarf>0
            bedarf:=0
          else
            bedarf:=abs(bedarf)
          endif
          zeile += printArtikelZeile(rekBedarf, m_menge, AVPOST->Menge, bedarf,NIL,fertigungsdauer)

          // 20210724 zeige alternat Material an
          // 20211117 zeige alternat Material rekrusiv
          zeile += drucke_alt_mat_rek(rekBedarf, bedarf, fertigungsdauer)

        else // Text
          TEXT->(dbseek(trim(AVPOST->ArtNr)))
          zeichen:=left(TEXT->Text,1)
          // Strich ?
          if (zeichen $ "-=*#") .and.;
            ( alltrim(TEXT->Text)==Replicate(Zeichen,len(alltrim(TEXT->Text))) )
            ? Replicate(Zeichen,104)
          else
            ? TEXT->Text
          endif
        endif
      endif
      skip
    enddo
    ? linie
  enddo
  SELECT (akt_sel)
  go (akt_rec)
RETURN
  /* EOP */

  /* drucke rek. alternatives Material */
static function drucke_alt_mat_rek(rekBedarf, bedarf, fertigungsdauer)
LOCAL faktor, aktArtrec , altBedarf, Zeile:=0
  // 20210724 zeige alternat Material an
  if .not. empty(ARTIKEL->MatArtNr)
    default fertigungsdauer:=0
    faktor:=ARTIKEL->MATFAKTOR
    aktArtrec:=ARTIKEL->(recno())
    ARTIKEL->(dbseek(ARTIKEL->MatArtNr))
    // seit 28.11.2021 ohne Ber�cksichtigung aktueller Reservierungen
    // altbedarf:=ARTIKEL->LageBest-ARTIKEL->disponiert-(faktor*bedarf)
    altbedarf:=ARTIKEL->LageBest-(faktor*bedarf)
    if altbedarf>0
      altbedarf:=0
    else
      altbedarf:=abs(altbedarf)
    endif
    zeile += printArtikelZeile(rekBedarf, bedarf, faktor, altbedarf, .t., fertigungsdauer)
    zeile += drucke_alt_mat_rek(rekBedarf, altbedarf)
    ARTIKEL->(dbgoto( aktArtrec ))
  endif
return zeile

static function printArtikelZeile(rekBedarf, m_menge, faktor, bedarf, highlight, fertigungsdauer)
LOCAL Zeile:=0
LOCAL rekValue:=.f.

  if rekBedarf .or. faktor*M_Menge > bedarf
    rekValue:=.t.
  endif

  default highlight:=.f.
  default fertigungsdauer:=0

  if highlight
    ? COLOR_RED
  else
    ?
  endif
  ?? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1,;
    if(!rekValue,ZEIGE_MENGE,'')+str(faktor*M_Menge,9,3),EINHEIT->Text, ARTIKEL->Lagebest,;
    str(ARTIKEL->disponiert,8,2),str(ARTIKEL->LageBest-ARTIKEL->disponiert,9,2), FETT_AN,;
    if(rekValue,ZEIGE_MENGE,'')+str(bedarf,9,2),FETT_AUS,getArtikelLagerOrt(13),getArtikelArt(),;
    space(0)
  if getArtikelArt() $ "FM"
    ?? ARTIKEL->BestInt
  else
    ?? ARTIKEL->BestExt
  endif
  if ARTIKEL->BestExt > 0 .or. ARTIKEL->BestInt >0
    drucke_best(ARTIKEL->ArtNr) // aus MaterialBedarf
  endif
  if empty(ARTIKEL->Bez2)
    if fertigungsdauer > 0
      ? space(len(out(ARTIKEL->ArtNr))),space(len(ARTIKEL->Bez2))
    endif
  else
    ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
  endif
  if fertigungsdauer > 0
    ?? space(3),getArtikelFertigungsdauer(fertigungsdauer)
  endif
  ?? COLOR_DEFAULT
return zeile
/* eof */



/*
* ermoeglicht das rekursive anzeigen von Stuecklisten (Lind) */
PROCEDURE rekLiStkList(ZeilenText , ZeigeData, rekBedarf, fertigungsdauer, ignoreMenge)
LOCAL M_Menge:=0, M_avNr
LOCAL merkeZeige:=M->specialZeige, objErr

  Umgebung( WRITE_ALL )
  if ! open("Artikel","Einheit","avaus","AvPost","Text","BesPost","Inner","Login")
    Error(TRY_AGAIN)
    Umgebung( LOAD )
    return
  endif

  ignore ZeilenText
  default fertigungsdauer:=.f.

  M_AvNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]
  if myEmpty( M_AvNr )
    Umgebung( LOAD )
    return
  endif

  ARTIKEL->(dbClearFilter())
  ARTIKEL->(OrdSetFocus(1))

  AVAUS->(dbseek(M_AvNr))
  ARTIKEL->(dbseek(M_AvNr))

  if ! AVAUS->(eof()) .and. getArtikelArt() $ STKLIST_ARTIKEL

    BEGIN SEQUENCE // krit. Bereich
      M_Menge:=abs(val(ZeigeData[ ZEIGE->(fieldPos("Menge" )) ]))
    RECOVER USING objErr
      // NOP
    END Sequence

    if M_Menge == 0
      // altd()
      // unsch�n Menge wird immer noch aus Text geparst
      M_Menge:=val(substr( strtran( ZeilenText , BS_FARBE, "" ) ,46,9))
      if ARTIKEL->LageBest-ARTIKEL->disponiert > 0
        M_Menge=M_Menge - (ARTIKEL->LageBest-ARTIKEL->disponiert)
        if M_Menge<0
          M_Menge=0
        endif
      endif
    endif


    /** Spezial Funktion Zeige freischalten */
    M->specialZeige:={}
    aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf.";
      } )
    aadd( M->specialZeige , { chr(K_F5)+chr(K_LDBLCLK) , ;
      { |a,b| rekLiStklist( a , b, rekBedarf, fertigungsdauer, ignoreMenge )} , "@F5@=aufl�sen" } )
    aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
    aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

    Drucker("BS")
    StkListLind(M_AvNr, M_Menge, rekBedarf, fertigungsdauer, ignoreMenge)
    Drucker("Off",,,,,,.f.) // ohne Popup!!!

    M->specialZeige:=merkeZeige

  endif

  Umgebung( LOAD )

RETURN
/* EOP */

Procedure MyStkListLind(zeile,menge)
LOCAL GetList:={}
LOCAL spalte:=50
LOCAL akt_Farbe:=setcolor()

  default Menge:=1
  default zeile:=row()+2
  if zeile>=maxRow()
    zeile:=maxRow()-1
  endif

  Umgebung( WRITE_ALL )
  setcolor(COLWIN)

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." };
    )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )
  aadd( M->specialZeige , { chr(K_F10), { |a,b| myArtBestellListe(a,b)} , "@F10@=Best. ext/int" } )
  aadd( M->specialZeige , { chr(K_CTRL_H) , { |a,b| HB_SYMBOL_UNUSED(a), WarAusJahrList("BS",b[ZEIGE->(fieldPos("ArtNr" ))]) }, "@STRG-H@" })

  Fenster(zeile-1,spalte-2,zeile+1,spalte+20)

  SetKey( K_F5, {|| readkill(.T.) } )
  SetKey( K_LBUTTONDOWN, {|| readkill(.T.) } )

  setcursor(DEUTE_MARKE)
  Message("Menge eingeben.      @F5@/@Maustaste@=weiter")
  @ zeile,spalte say "Menge:" get Menge picture "99999"
  // read ->
  ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD +;
    HB_INKEY_GTEVENT + INKEY_LDOWN );GetList:={};( GetList )
  // ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_ALL,,, ) ;GetList:={};( GetList )
  setcolor(akt_Farbe)
  setcursor( SC_NONE )
  SetKey( K_F5, NIL )

  if ! ABBRUCH
    cls
    Drucker("BS")
    StkListLind(ARTIKEL->ArtNr,menge)
    Drucker("Off",,,,,,.f.) // ohne Popup!!!
    // Drucker("Off") // mit Popup!!!
  endif

  M->specialZeige:=NIL
  SetKey( K_LBUTTONDOWN, NIL )
  Umgebung( LOAD )
return


  #define MAX_TIEFE 10


/*
* Liste aller Artikel mit VK abweichend von letzten Historien Eintrag
*/
PROCEDURE VK_HistCheck()
LOCAL mArtNr
LOCAL treffer:=0,protName
  // LOCAL bekannt:="3006350/3200170/3200230/3200240/3800988/3817140/38541779/3900901/5000800"
LOCAL bekannt:="5000800"

  Protokoll(INIT_P,"Artikel-Preis Historie Pr�fung")
  if open("Artikel","ArtPreis")
    select Artikel
    go top
    do while ! ARTIKEL->(eof())
      mArtNr:=ARTIKEL->ArtNr
      select ArtPreis
      dbseek( mArtNr )
      // finde den letzten
      do while ! ARTPREIS->(eof()) .and. ARTPREIS->ArtNr=mArtNR
        skip
      enddo
      skip -1
      if getArtikelArt() <> "T" .and. ARTIKEL->Preis1 > 0 .and. ! trim(ARTIKEL->ArtNr) $ bekannt .and. ;
        ( ARTPREIS->ArtNr <> mArtNR .or. ARTPREIS->VKPreis <> ARTIKEL->Preis1 )
        treffer++
        Protokoll(PROTOKOLL,mArtNr + " " + getArtikelArt() + " " + ARTIKEL->Bez1+ " " + ;
          str( ARTIKEL->Preis1 , 12 , 2 ) )
      endif
      select Artikel
      skip
    enddo

    Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
    close data

    if treffer > 0
      protName:=Protokoll(P_FILE_NAME)
      email(MY_EMAIL,"Fehler: VK Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
    endif

  endif
return



  /*
* Liste aller Artikel mit Rechnungen aber ohne VK
*/
PROCEDURE VK_KonsistenzCheck()
LOCAL zeile:=0, GetList:={}
LOCAL treffer:=0,protName
LOCAL startDate:=ctod("01.01.2006")
LOCAL Ausnahmen:={"5005485 "}

  if ! open("Artikel","Rechpost","Rechaus")
    close data
    clear
    return
  endif

  Protokoll(INIT_P,"Artikel ohne VK", "ArtNr   Bez1                            verkauft "+;
    "Modifiziert Rechn.Dat  Nr.       Menge       Preis")
  select RechPost
  index on RECHPOST->ArtNr+RECHPOST->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE EXCLUSIVE descending
  select Artikel
  set filter to len(trim(ARTIKEL->ArtNr))>6 .and. ARTIKEL->Preis1==0 ;
    .and. dtoc(ARTIKEL->Mod_Date)<>"  .  .  " .and. Date()-ARTIKEL->Mod_Date <= 1 .and.;
    ARTIKEL->MOD_User<>SERVER_LOGIN
  // nur falls in den letzten 1 Tage ge�ndert
  go top
  do while ! ARTIKEL->(eof())
    RECHPOST->(dbseek(ARTIKEL->ArtNr))
    if ! RECHPOST->(eof()) .and. RECHPOST->Preis>0 .and. RECHPOST->ReaDat>=startDate .and. ;
      ! aContains(Ausnahmen, ARTIKEL->ArtNr)
      RECHAUS->(dbseek(RECHPOST->RechNr))
      Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+str(ARTIKEL->verkauft,8)+" "+;
        dtoc(ARTIKEL->Mod_Date)+" "+ARTIKEL->MOD_User+" "+dtoc(RECHAUS->ReaDat)+" "+;
        RECHAUS->RechNr+" "+str(RECHPOST->Menge,11,2)+" "+str(RECHPOST->Preis,11,2))
      treffer++
    endif
    Message("VK Check: "+ARTIKEL->ArtNr)
    skip
  enddo
  Protokoll(P_CREATE_PDF,"Bitte �berpr�fen !")
  if treffer > 0
    protName:=Protokoll(P_FILE_NAME)
    email(MY_EMAIL,"Fehler: VK Konsistenzcheck:"+str(treffer,5),"Bitte pr�fen",protName)
  endif
  close data
  cls
return


/*
 * Zeigt die offenen Bestellungen des akt. selektiern Lieferanten am BS an
 * Lieferan Datei muss ge�ffnet sein
*
*/
PROCEDURE LiefBestellListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL TempFile:=TEMP+BACKSLASH+"Best"+getUser():getLongID()
  // LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0,Z_Menge:=0,Z_Geliefges:=0,Z_Rest:=0
LOCAL MArtNr

  Umgebung(WRITE_ALL)

  M->specialZeige:={}
  // aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." } )
  aadd( M->specialZeige , { chr(K_F5) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Drucker("BS","Offene Best. "+LIEFERAN->LiefNr+" "+LIEFERAN->KurzName)

  Message("Liste wird erstellt.   Bitte warten...")

  if ! open("BesPost","BesAus","Artikel","Einheit")
    Umgebung(LOAD)
    return
  endif

  select BesPost
  set rela to BESPOST->BestNr into BesAus,BESPOST->ArtNr into Artikel,BESPOST->ME into Einheit

  copy to (tempFile) for ;
    BESPOST->LiefNr==LIEFERAN->LiefNr .and. BESPOST->Menge - BESPOST->GeliefGes >= 1 ;
    .and. BESAUS->Erledigt<>"J" .and. len(alltrim(BESPOST->ArtNr)) > FRACHT_LAENGE

  select 0
  use (tempFile) alias BEST_KOPIE EXCL
  index on kwindex(BEST_KOPIE->Kw) + BEST_KOPIE->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE EXCLUSIVE

  set rela to BEST_KOPIE->BestNr into BesAus,BEST_KOPIE->ArtNr into Artikel,;
    BEST_KOPIE->ME into Einheit
  // BEST_KOPIE->(OrdSetFocus(2)) // ArtNr
  // Nur offene Bestellungen anzeigen
  // seit 24.3.2012 erledigte Bestellungen ausblenden
  // set filter to BEST_KOPIE->LiefNr==LIEFERAN->LiefNr .and. BEST_KOPIE->Menge > BEST_KOPIE->GeliefGes // .and. BESAUS->Erledigt<>"J"



  go top
  mArtNr:=BEST_KOPIE->ArtNr
  do while .not. BEST_KOPIE->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Offene Bestellungen - Lieferant: '+LIEFERAN->LiefNr+' '+LIEFERAN->Kurzname+'Seite',;
      str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '-------------'
    ? "BestNr. Datum   Art.Nr.   Bezeichnung                                 Menge   Gelief.   "+;
      "Rest ME   KW"
    ? '------------------------------------------------------------------------------------------'+;
      '-------------'
    _____fixedHeader_____

    do while .not. BEST_KOPIE->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? BESAUS->BestNr,space(0),BESAUS->AufDat,ZEIGE_ARTNR+BEST_KOPIE->ArtNr,BEST_KOPIE->Komm1,;
        str(BEST_KOPIE->Menge,8,0),str(BEST_KOPIE->GeliefGes,8,0),;
        str(BEST_KOPIE->Menge-BEST_KOPIE->GeliefGes,7), EINHEIT->Text
      if left(BEST_KOPIE->KW,1)=="*"
        ?? space(0),trim(BEST_KOPIE->KW_text)
      else
        ?? space(0),BEST_KOPIE->KW
      endif
      if ! empty(BEST_KOPIE->Komm2)
        ? space(25),BEST_KOPIE->Komm2
      endif

      /* Aufsummieren */
      // M_Menge+=BEST_KOPIE->Menge
      // M_Geliefges+=BEST_KOPIE->GeliefGes
      // M_Rest+=(BEST_KOPIE->Menge - BEST_KOPIE->GeliefGes)

      // Z_Menge+=BEST_KOPIE->Menge
      // Z_Geliefges+=BEST_KOPIE->GeliefGes
      // Z_Rest+=(BEST_KOPIE->Menge - BEST_KOPIE->GeliefGes)

      skip

      // Zwischensumme?
      // if mArtNr<>BEST_KOPIE->ArtNr
      // ? '------------------------------------------------------------------------------------------------------'
      // ? space(65),str(Z_Menge,8,0),str(Z_GeliefGes,8,0),str(Z_Rest,7,0)
      // ?
      // Z_Menge:=Z_Geliefges:=Z_Rest:=0
      // mArtNr:=BEST_KOPIE->ArtNr
      // endif
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '-------------'
    // ? "Gesamt:"+space(58),str(M_Menge,8,0),str(M_GeliefGes,8,0),str(M_Rest,7,0)

    if .not. BEST_KOPIE->(eof())
      Zeile:=FormFeed(Zeile,Seite)
    else
      ?
      ?
    endif
  enddo // eof()

  Drucker("Off")
  M->specialZeige:={}
  Umgebung(LOAD)
  ferase(tempFile + ".*")

RETURN
/* LiefBestellListeListe() */


/* Zeigt alte Bestellungen des akt. selektiern Lieferanten am BS an
 * Lieferan Datei muss ge�ffnet sein
 *
 * Parameter: mArtNr falls eingegeben werden nur Bestellungen dieses Artikels angezeigt
 *            mLiefNr falls eingegeben werden nur Bestellungen dieses Lieferanten angezeigt
*
*/
PROCEDURE LiefBestHist(mLiefNr,mArtNr)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL G_Geliefges:=0,Z_Geliefges:=0,G_wert:=0,Z_Wert:=0,wert
LOCAL sortierung
LOCAL line:=replicate("-",116)
LOCAL line2:=replicate("=",116), kom

  Umgebung(WRITE_ALL)

  M->specialZeige:={}
  //aadd( M->specialZeige , { chr(K_CTRL_F4), { |a,b| rekNegList( a , b )} , "@STRG-F4@=Neg.Verf." } )
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Drucker("BS","Gelieferte Best. "+LIEFERAN->LiefNr+" "+LIEFERAN->KurzName)
  Message("Liste wird erstellt.   Bitte warten...")

  if ! open("BesPost","BesAus","Artikel","Einheit","AvPost")
    Umgebung(LOAD)
    return
  endif

  SELECT BesPost
  set rela to BESPOST->BestNr into BesAus , BESPOST->ArtNr into Artikel , BESPOST->ME into Einheit,;
    BESPOST->LiefNr into Lieferan

  BESPOST->(OrdSetFocus(2)) // ArtNr

  if mArtNr == nil

    sortierung:=Message("Sortiert nach @A@rtikeln oder @B@estellnummer?  (@A@/@B@)","AB","B")
    if ABBRUCH
      Error(TRY_AGAIN)
      Umgebung(LOAD)
      RETURN
    endif

    // Info: mLiefNr == nil .and. mArtNr == nil gibt's net, das w�ren alle

    // Nur bereits gelieferte Bestellungen anzeigen
    if sortierung == "A"
      index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        for BESPOST->LiefNr==MLiefNr .and. BESPOST->GeliefGes > 0
    else
      index on BESPOST->BestNr+BESPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        for BESPOST->LiefNr==MLiefNr .and. BESPOST->GeliefGes > 0
    endif
    go top
    mArtNr:=BESPOST->ArtNr
  else
    // alle, hier auch die offenen
    if myempty( mLiefNr )
      index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        for mArtNr == BESPOST->ArtNr
    else // nur der Lieferant
      index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
        for BESPOST->LiefNr==MLiefNr .and. mArtNr == BESPOST->ArtNr
    endif
  endif

  go top
  do while .not. BESPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    if myempty( mLiefNr )
      ? "Gelieferte Bestellungen - Artikel: "+ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+"Seite",str(seite,3)
      ? line
      ? "BestNr. Datum   Lief.Nr.  Name                              Bestellt Gelief. ME       "+;
        "Preis Rabatt So.Rab Wert(Euro)"
      ? line
    else
      ? "Gelieferte Bestellungen - Lieferant: "+LIEFERAN->LiefNr+" "+LIEFERAN->Kurzname+"Seite",;
        str(seite,3)
      ? line
      ? "BestNr. Datum   Art.Nr.  Bezeichnung                        Bestellt Gelief. ME       "+;
        "Preis Rabatt So.Rab Wert(Euro)"
      ? line
    endif
    _____fixedHeader_____

    do while .not. BESPOST->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      wert:=BESPOST->GeliefGes*BESPOST->Preis;
        /if(BESPOST->PE=="H",100,1);
      // (100-BESPOST->Rabatt)/100*(100-BESAUS->So_Rabatt)/100

      if myempty( mLiefNr )
        kom:=ZEIGE_LIEFNR+LIEFERAN->LiefNr + space(5) + LIEFERAN->Kurzname + space(4)
      else
        kom:=ZEIGE_ARTNR+BESPOST->ArtNr + " " + left(BESPOST->Komm1,30)
      endif

      ? BESAUS->BestNr,space(0),BESAUS->AufDat,kom,;
        transstr(BESPOST->Menge,9,0),transstr(BESPOST->GeliefGes,9,0),space(0),EINHEIT->Text,;
        transstr(BESPOST->Preis,10,2),;
        transform(BESPOST->Rabatt,"@ZE99,99"),transform(BESAUS->So_Rabatt,"@ZE99,99"),transstr(wert,12,2)
      if ! myempty( mLiefNr ) .and. ! empty(BESPOST->Komm2)
        ? space(24),left(BESPOST->Komm2,30)
      endif

      /* Aufsummieren */
      G_Geliefges+=BESPOST->GeliefGes
      G_wert+=wert
      Z_Geliefges+=BESPOST->GeliefGes
      Z_wert+=wert

      skip

      // Zwischensumme?
      if mArtNr<>BESPOST->ArtNr .and. ! BESPOST->(eof())
        ? line
        ? space(61),transstr(Z_GeliefGes,13,0),space(26),transstr(Z_wert,13,2)
        ?
        Z_Geliefges:=Z_Wert:=0
        mArtNr:=BESPOST->ArtNr
      endif

      Stop:=stop_key()
    enddo // Blattl�nge

    if .not. BESPOST->(eof())
      Zeile:=FormFeed(Zeile,Seite)
    else
      ? line2
      ? "Gesamt:"+space(54),transstr(G_GeliefGes,13,0),space(26),transstr(G_wert,13,2)
      ?
      ?
    endif
  enddo // eof()

  Drucker("Off")
  M->specialZeige:={}
  Umgebung(LOAD)

RETURN
/* eop */


/* PROCEDURE IdentNrChek
*
* Pr�ft alle Ident.Nr
*/
PROCEDURE IdentNrCheck()

  if ! open({"Kunden",.t.},"Land")
    Error(TRY_AGAIN)
    close data
    cls
    return
  endif

  Protokoll(INIT_P,"Kunden Ident.Nummern Check")
  select Kunden
  go top
  do while ! KUNDEN->(eof())
    if ! empty(KUNDEN->IdentNr)

      // remove blanks
      if at(" ",trim(KUNDEN->IdentNr))>0
        replace KUNDEN->IdentNr with no_blanks(KUNDEN->IdentNr)
      endif

      // remove "-"
      if at("-",trim(KUNDEN->IdentNr))>0
        replace KUNDEN->IdentNr with deleteString(KUNDEN->IdentNr,"-")
      endif

      // upper ID Nr
      if KUNDEN->IdentNr<>upper(KUNDEN->IdentNr)
        replace KUNDEN->IdentNr with upper(KUNDEN->IdentNr)
      endif

      if ! syntaxIdentNr(KUNDEN->IdentNr,KUNDEN->Land,.f.)
        Protokoll(PROTOKOLL,KUNDEN->KundNr+" "+KUNDEN->KurzName+" "+KUNDEN->Land+" "+KUNDEN->Ort+" "+;
          KUNDEN->IdentNr)
        replace KUNDEN->IdentNr with ""
      endif

    endif
    skip
  enddo
  if Protokoll(P_CREATE_PDF,"Ident.Nummern wurden gel�scht!",,,.f.)
    email(MY_EMAIL,"Kunden Ident.Nr Check","Bitte pr�fen",Protokoll(P_FILE_NAME))
  endif
  close data
  cls
return
/** eop */

/** Druckt die Gelangensbescheinigungen */
procedure GelangensList(Abfrage)
LOCAL Seite:=0,Zeile,count:=0
LOCAL gesSum:=0,gesMwst:=0,realFileName
LOCAL ausw,faellig:=val(getProperty("Miki.gelang.faellig","21"))

  default abfrage:=.t.

  cls
  titel("Gelangensbescheinigungen drucken")

  if ! open("Rechaus","Mwst_Kz")
    cls
    if ! Abfrage
      break createErrorObject ("Rechaus.dbf nicht verf�gbar.","GelangensList","open",EG_OPEN)
    endif
    close data
    return
  endif
  MWST_KZ->(dbseek("1")) // default mwst satz hardcoded :(
  select Rechaus

  if Abfrage
    setcolor(COLWIN)
    Fenster(6,20,12,44,"Listen-Auswahl")
    @ 8,22 Prompt "A. Alle      "
    @ 9,22 Prompt "O. Nur offene"
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw
    setcolor(COLNOR)

    if ABBRUCH
      cls
      close data
      return
    endif

    switch Ausw
    case 1
      set filter to ! empty(RECHAUS->GelNr)
      exit
    case 2
      set;
        filter;
        to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing) .and. empty(RECHAUS->GelReNr)
      exit
    endswitch

    if ! Druck_BS("GelangensBescheinigungen")
      cls
      close data
      return
    endif
  else
    set;
      filter to ! empty(RECHAUS->GelNr) .and. empty(RECHAUS->GelEing) .and. empty(RECHAUS->GelReNr)
    Drucker("PDF","GelangensListe",,.f.,PDF_NO_CONFIRM)
  endif

  go top
  do while ! RECHAUS->(eof())
    count++
    seite=seite+1
    Zeile:=0
    ? "Gelangens-Bescheinigungen vom",getUser():date,space(6),"Seite",str(Seite,3)
    ?
    ? "Re.Nr Kd.Nr.     Firma                         Datum        Netto       MwSt Eingang "+;
      "Berechnet"
    ? replicate("-",85)
    _____fixedHeader_____

    do while .not. eof() .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand


      ? RECHAUS->GelNr,RECHAUS->KundNr,space(1),RECHAUS->KurzName
      if getUser():date-RECHAUS->ReaDat >= faellig .and. empty(RECHAUS->GelEing) .and.;
        empty(RECHAUS->GelReNr)
        ?? COLOR_RED
      endif
      ?? RECHAUS->ReaDat,RECHAUS->Netto,transstr(RECHAUS->Netto*MWST_KZ->Mwst/100,10,2),;
        RECHAUS->GelEing
      if ! empty(RECHAUS->GelReNr)
        ?? RECHAUS->GelReNr
      endif
      ?? COLOR_DEFAULT
      gesSum += RECHAUS->Netto
      gesMwst += round(RECHAUS->Netto*MWST_KZ->Mwst/100,2)
      count++
      skip
    enddo

    if RECHAUS->(eof())
      ? space(40),replicate("=",36)
      ? space(40),"Gesamtsumme:",transstr(gesSum,12,2),transstr(gesMwst,10,2)
    endif
    if ! RECHAUS->(eof())
      Zeile:=FormFeed(Zeile)
    endif
  enddo

  getUser():getCurrentPrintJob():endDoc()
  realFileName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  close data

  if ! Abfrage
    if count > 0
      email(MAIN_EMAIL,"Gelangensbescheinigungs-Liste vom "+dtoc(getUser():date),;
        "Gelangensbescheinigungs-Liste vom "+dtoc(getUser():date),realFileName)
    else // Count =0
      email(MAIN_EMAIL,"Gelangensbescheinigungs-Liste vom "+dtoc(getUser():date)+" ist leer.",;
        "Gelangensbescheinigungs-Liste vom "+dtoc(getUser():date)+" ist leer.")
    endif
  endif

return
/** eop */

/*
 * Zeigt die Kunden an die einen Artikel angeboten bekommen haben
*/
PROCEDURE ArtAngebotListe(MArtNr)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,bez:="",gesMenge:=0
  default MArtNr:=""

  Umgebung(WRITE)

  if ! open("Angaus","AngPost")
    Error(TRY_AGAIN)
    cls
    RETURN
  endif

  select Angpost
  set filter to ANGPOST->ArtNr==MArtNr

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  M->specialZeige:={}
  aadd( M->SpecialZeige , { "" , { || .t. } , "@ALT-G@=neues Angebot"} )

  go top
  do while .not. ANGPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Kunde (Angebot) je Artikel: '+out(MArtNr),ARTIKEL->Bez1,space(6),'Seite',str(seite,3)
    ? '-------------------------------------------------------------------------------------'
    ? "Datum     Ang.Nr       Preis      Menge Rabatt Sond.Rab Kd.Nr.   KdBez"
    ? "          Best.Nr"
    ? '-------------------------------------------------------------------------------------'
    _____fixedHeader_____

    do while .not. ANGPOST->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ANGAUS->(dbseek(ANGPOST->AngNr))
      ? ANGPOST->AufDat,ZEIGE_ANGNR+ANGPOST->Angnr,ANGPOST->Preis/if(ANGPOST->PE=="H",100,1),;
        ANGPOST->Menge,ANGPOST->Rabatt,space(1),ANGAUS->SO_Rabatt,space(1),ZEIGE_KUNDNR+ANGAUS->KundNr,;
        ANGAUS->KurzName
      if ! empty(ANGAUS->BestNr)
        ? space(9),ANGAUS->BestNr
      endif
      gesMenge+=ANGPOST->Menge
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '-------------------------------------------------------------------------------------'
    ? space(24),transstr(gesMenge,14,2)
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

RETURN
/* eop */

/*
 * Zeigt die Artikel an die ein Kunde angeboten bekommen hat
*/
PROCEDURE KundAngebotsListe(MKundNr)
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.,bez:="", summe:=0
  default MKundNr:=""

  Umgebung(WRITE)

  if ! open("Angaus","Angpost","Artikel","Avpost","Einheit")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    Return
  endif

  select Angpost
  set filter to len(alltrim(ANGPOST->ArtNr))>FRACHT_LAENGE .and. ANGPOST->KundNr==MKundNr
  if Message("Sortiert nach @A@rtikeln oder Angebots-@N@ummer?  (@A@/@N@)","AN","N")=="A"
    Message("Liste wird sortiert.   Bitte warten...")
    index on ANGPOST->ArtNr+ANGPOST->Angnr tag TEMP_INDEX TEMPORARY ADDITIVE
  endif

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")


  go top
  do while .not. ANGPOST->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Artikel / Angebot je Kunde: '+MKundNr+KUNDEN->KurzName,space(28),'Seite',str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------'
    ? "Datum     Ang.Nr  Art.Nr       Bezeichnung                             Preis      Menge "+;
      "Rabatt  Sond.Rab Netto"
    ? "          Best.Nr                                                                          "+;
      "              Summe"
    ? '------------------------------------------------------------------------------------------'+;
      '--------------------'
    _____fixedHeader_____

    do while .not. ANGPOST->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ANGAUS->(dbseek(ANGPOST->Angnr))
      ? ANGPOST->AufDat,ZEIGE_ANGNR+ANGPOST->Angnr,space(2),ZEIGE_ARTNR+out(ANGPOST->ArtNr),;
        left(ANGPOST->Komm1,30), ANGPOST->Preis/if(ANGPOST->PE=="H",100,1),ANGPOST->Menge,;
        ANGPOST->Rabatt,space(1), ANGAUS->SO_Rabatt,;
        transform(ANGAUS->Netto,"@E 9,999,999")+" Euro"
      if ! empty(ANGAUS->BestNr)
        ? space(9),ANGAUS->BestNr
      endif
      summe += ANGAUS->Netto
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '------------------------------------------------------------------------------------------'+;
      '-----------------------'
    ? space(98),transform(Summe,"@E 9,999,999")+" Euro"
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  close angpost
  Umgebung(LOAD)

RETURN
/* EOP */

/** zeigt die St�cklisten an in denen der akt. selektierte Text vorkommt
* liefert die Anzahl als Ergebnis zur�ck
*/
function textStkListe()
LOCAL result:=0
LOCAL Zeile:=0

  Umgebung(WRITE_ALL)
  if ! open("Artikel","AvPost")
    Error(ACHTUNG+" St�cklisten konnten nicht gepr�ft/gel�scht werden.",.t.)
  else
    select AvPost
    set filter to AVPOST->Text=="T"
    AVPOST->(OrdSetFocus(2))
    AVPOST->(dbseek(TEXT->TextNr))
    if ! AVPOST->(eof())
      Message("St�cklisten werden durchsucht.            Bitte warten...")
      Drucker("BS",TEXT->TextNr+" in St�cklisten")
      ? "Zeit:",TEXT->TextNr,trim(TEXT->Text)," kommt in folgenden St�cklisten vor:"
      ? replicate("=",80)
      do while ! AVPOST->(eof()) .and. trim(AVPOST->ArtNr)==TEXT->TextNr
        ARTIKEL->(dbseek(AVPOST->AvNr))
        ? AVPOST->AvNr,AVPOST->Art,ARTIKEL->Bez1,AVPOST->Menge
        result++
        skip
      enddo
      ? replicate("=",80)
      drucker("OFF")
    endif
  endif
  Umgebung(LOAD)

return result
/** eof */

/** zeigt die St�cklisten an in denen die akt. selektierte Zeit vorkommt
* liefert die Anzahl als Ergebnis zur�ck
*/
function stdStkListe()
LOCAL result:=0
LOCAL Zeile:=0

  Umgebung(WRITE_ALL)
  if ! open("Artikel","AvPost","Mehrfach")
    Error(ACHTUNG+" St�cklisten konnten nicht ge�ffnet werden.",.t.)
  else
    select AvPost
    set filter to AVPOST->Text=="A" .and. AVPOST->Art=="V"
    AVPOST->(OrdSetFocus(2))
    AVPOST->(dbseek(MASCHINE->StdNr))
    if ! AVPOST->(eof())
      Message("St�cklisten werden durchsucht.            Bitte warten...")
      Drucker("BS",MASCHINE->StdNr+" in St�cklisten")
      ? "Zeit:",MASCHINE->StdNr,trim(MASCHINE->Bez)," kommt in folgenden St�cklisten vor:"
      ? replicate("=",80)
      do while ! AVPOST->(eof()) .and. trim(AVPOST->ArtNr)==MASCHINE->StdNr
        ARTIKEL->(dbseek(AVPOST->AvNr))
        ? AVPOST->AvNr,ARTIKEL->Art,ARTIKEL->Bez1,AVPOST->Menge,AVPOST->HauptKz, getMehrfNutzen()
        result++
        skip
      enddo
      ? replicate("=",80)
      drucker("OFF")
    endif
  endif
  Umgebung(LOAD)

return result
/** eof */


/*
 *
 * Offene / f�llige Rechnungen je Kunde
 */
PROCEDURE MahnListe(Ausgabe,MKundNr)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.,protName, summe:=0
LOCAL Mahnstuf:=1, karenzD, karenzA, sortOrder:="K"
LOCAL sortFelder:="RECHAUS->RechNr"
LOCAL line, lastMonth, zwSumme:=0
LOCAL startDat

  Umgebung(WRITE_ALL)

  if ! open("Rechaus","Zahlkond")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  cls
  titel("F�llige Rechnungen - Liste")

  if valtype(Ausgabe)=="U"
    MahnStuf:=0
    sortOrder:="Z"
    startDat:=ctod("01.01."+str(year(getUser():date),4))

    @ 8,14 to 16,66
    @ 10,16 say "Rechnungen"
    @ 10,16 say "Drucken ab Mahnstufe  :" get Mahnstuf picture "9";
      when Message("Bitte die gew�nschte Mindest-Mahnstufe eingeben.    @ESC@=Abbruch")
    @ 12,16 say "Drucken ab Rechn.Datum:" get StartDat picture "9";
      when Message("Bitte das gew�nschte Start-Rechnungs-Datum eingeben.    @ESC@=Abbruch")
    @ 14,16 say "Sortiert nach Rechung, Kunde oder Zahlungsziel:" get sortOrder picture "!";
      valid sortOrder $"KRZ" when Message( "Sortiert nach @R@echung, @K@unde oder @Z@ahlungsziel? "+;
      " (@R@/@K@/@Z@)")
    read

    if ABBRUCH .or. ! druck_BS()
      Umgebung(LOAD)
      RETURN
    endif

    if sortOrder == "K"
      sortFelder:="RECHAUS->KundNr + RECHAUS->RechNr"
    elseif sortOrder == "Z"
      sortFelder:="RECHAUS->Faellig"
    endif

  else
    Drucker(Ausgabe)
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  karenzD:=val( getProperty("Miki.mahnung.deutschland","") )
  karenzA:=val( getProperty("Miki.mahnung.ausland","") )

  SELECT Rechaus
  if valtype(MKundNr) == "C"
    Mahnstuf:=0
    index on &(sortFelder) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for RECHAUS->Mahnstufe >= mahnstuf .and. empty( RECHAUS->Bezahlt ) .and. RECHAUS->Brutto > 0;
      .and. ( Mahnstuf == 0 .or.;
      (left(RECHAUS->Land,2) == DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzD ) .or.;
      (left(RECHAUS->Land,2) <> DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzA ) ) ;
      .and. empty(RECHAUS->STORNO_NR) .and. RECHAUS->KundNr == MkundNr // einziger Unterschied!
  else
    index on &(sortFelder) tag TEMP_INDEX TEMPORARY ADDITIVE ;
      for RECHAUS->Mahnstufe >= mahnstuf .and. empty( RECHAUS->Bezahlt ) .and. RECHAUS->Brutto > 0;
      .and. ( Mahnstuf == 0 .or.;
      (left(RECHAUS->Land,2) == DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzD ) .or.;
      (left(RECHAUS->Land,2) <> DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzA ) );
      .and. empty(RECHAUS->STORNO_NR) .and. (startDat==NIL .or. RECHAUS->ReaDat>=startDat)
  endif

  /* Relation setzten */
  SELECT Rechaus
  SET RELATION TO RECHAUS->ZkNr into Zahlkond

  Message("Liste wird erstellt.  Bitte warten....")
  go top
  do while .not. RECHAUS->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    if sortOrder == "Z"
      line=replicate("-",99)
    else
      line=replicate("-",87)
    endif
    ? "Miki Plastik GMBH  ***  f�llige Rechnungen  ***",space(11),"vom:",getUser():date,,;
      "  Seite ",str(seite,3)
    ?
    ? "KD-Nr.   N a m e                  RE-Nummer RE-Dat.  AB-Nr.     Brutto F�llig Mahnstufe"
    if sortOrder == "Z"
      ?? space(5),"Summe"
    endif
    ? line
    _____fixedHeader_____
    do while .not. RECHAUS->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand

      ? ZEIGE_KUNDNR + KdOut(RECHAUS->Kundnr),RECHAUS->KurzName,RECHAUS->RechNr,RECHAUS->ReaDat,;
        ZEIGE_AUFNR + RECHAUS->AufNr

      // drucke f�llige in rot
      if ( Mahnstuf > 0 .or.;
        (left(RECHAUS->Land,2) == DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzD ) .or.;
        (left(RECHAUS->Land,2) <> DEUTSCH_LAND .and. getUser():Date >= RECHAUS->Faellig + karenzA ) )
        ?? COLOR_RED
        ?? transStr(RECHAUS->Brutto,11,2), RECHAUS->Faellig,space(4),RECHAUS->Mahnstufe,;
          COLOR_DEFAULT
      else
        ?? transStr(RECHAUS->Brutto,11,2), RECHAUS->Faellig,space(4),RECHAUS->Mahnstufe
      endif

      if sortOrder == "Z"
        zwSumme += RECHAUS->Brutto
        ?? transstr(zwSumme,12,2)
      else
        if getUser():getCurrentPrintJob():className() == "BSJOB"
          ? space(33)
        else
          ? space(37),WINZIG_AN
        endif

        if empty(ZAHLKOND->Text2)
          ?? trim(ZAHLKOND->Text)
        else
          ?? trim(ZAHLKOND->Text) + ",", trim(ZAHLKOND->Text2)
        endif
        if getUser():getCurrentPrintJob():className() <> "BSJOB"
          ?? WINZIG_AUS
        endif
      endif

      summe += RECHAUS->Brutto
      skip

      if sortOrder == "Z"
        if lastMonth<>NIL .and. month(lastMonth) <> month(RECHAUS->Faellig)
          ? line
          ? space(41), left(cmonth(lastMonth)+space(9),9),str(year(lastMonth)),;
            transStr(zwSumme,12,2)
          ?
          zwSumme:=0
        endif
        lastMonth:=RECHAUS->Faellig
      endif

    enddo

    if RECHAUS->(eof())
      if sortOrder == "Z"
        ? replicate("=",99)
        ? space(84) , transStr( summe, 14 , 2)
      else
        ? replicate("=",87)
        ? space(55) , transStr( summe, 14 , 2)
      endif
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  getUser():getCurrentPrintJob():endDoc()
  protName:=getUser():getCurrentPrintJob():pdfFullFileName
  getUser():setCurrentPrintJob(NIL)

  if Ausgabe=="PDF"
    email(MAIN_EMAIL,"F�llige Rechnungen: " + str( OrdKeyCount() , 4 ) , "anbei" , protName)
  endif

  Umgebung(LOAD)
RETURN
/* EOP Auftrags_Liste */

  /**
  * Vergleicht den Artikel EK mit der letzten Bestellung
  */
procedure EkCheck()
local me1 , me2

  cls
  Titel("Artikel EK vs Bestellung Konsistenzcheck")
  Message("Liste wird erstellt.    Bitte warten...")

  if open("Artikel","BesPost","BestKart","BesAus","Einheit")
    Protokoll(INIT_P,"Abweichende Preise Artikel EK - letzte Bestellung ")
    BESPOST->(OrdSetFocus( 3 ))
    select Artikel
    set filter to len(alltrim(ARTIKEL->ArtNr)) > 5 .and. ! getArtikelArt()$"WD" .and. ;
      ! left(ARTIKEL->ArtNr,2)=="00"
    go top
    do while ! eof()
      BESPOST->(dbseek( ARTIKEL->ArtNr ))
      if ! eof()
        // pr�fe Preis
        if BESPOST->Rabatt == 0 .and. ARTIKEL->EkPr <> BESPOST->Preis .and. BESPOST->Preis > 0
          // pr�fe ob Rabatttabelle verwendet, falls nein -> Email
          BESTKART->( dbseek( BESPOST->ArtNr + BESAUS->LiefNr ) )
          if BESTKART->(eof()) .or. BESPOST->Menge < BESTKART->Menge1
            // hole Mengeneinheit
            EINHEIT->(dbseek( ARTIKEL->ME ))
            me1:=EINHEIT->Kommentar
            EINHEIT->(dbseek( BESPOST->ME ))
            me2:=EINHEIT->Kommentar

            BESAUS->(dbseek( BESPOST->BestNr ))
            Protokoll( PROTOKOLL , out(ARTIKEL->ArtNr)+" "+ARTIKEL->Bez1+"    EK...........:"+;
              transstr(ARTIKEL->EkPr,12,2)+ " Euro ("+alltrim(me1)+")",;
              BESPOST->BestNr+" "+BESAUS->Kurzname+" "+dtoc(BESAUS->BestDat)+" Bestell-Preis:"+;
              transstr(BESPOST->Preis,12,2)+ " Euro ("+alltrim(me2)+")" ,"")
          endif
        endif
      endif
      skip
    enddo
    Protokoll(P_CREATE_PDF)
    wapi_SHELLEXECUTE( 0, 0, Protokoll(P_FILE_NAME), , 0, 0 ) // startet neuen Prozess ohne Show!

    close data
  endif
return
/** eof */


  /**
  * Zeigt am BS die Fertigungsdauer f�r eine bestimmte Menge des aktuellen Artikels an
  *
  * in beide Richtungen der Fertigungshierarchie
  * AVPOST muss offen sein
  */
Procedure showFertDauer(zeile, menge)
LOCAL GetList:={}, spalte:=26, printBuffer

  Umgebung( WRITE_ALL )
  default Menge:=1
  default zeile:=row()+2
  if zeile>=maxRow()
    zeile:=maxRow()-1
  endif

  setcolor(COLWIN)
  Fenster(zeile-1,spalte-2,zeile+3,spalte+38)

  SetKey( K_F5, {|| readkill(.T.) } )
  SetKey( K_SH_F5, {|| readkill(.T.) } )
  SetKey( K_CTRL_F5, {|| readkill(.T.) } )
  SetKey( K_LBUTTONDOWN, {|| readkill(.T.) } )

  setcursor(DEUTE_MARKE)
  Message("Menge eingeben.      @F5@/@Maustaste@=weiter")
  @ zeile,spalte say "Menge:" get Menge picture "99999"
  // read ->
  ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD +;
    HB_INKEY_GTEVENT + INKEY_LDOWN );GetList:={};( GetList )
  // ReadModal( GetList, NIL,NIL,INKEY_KEYBOARD + HB_INKEY_ALL,,, ) ;GetList:={};( GetList )
  setcursor( SC_NONE )
  SetKey( K_F5, NIL )
  SetKey( K_SH_F5, NIL )
  SetKey( K_CTRL_F5, NIL )

  if ! ABBRUCH .and. Menge > 0
    Drucker("BS")
    printBuffer:=getFertDauerPrintBuffer(menge)
    getUser():getCurrentPrintJob():printBuffer(printBuffer)
    Drucker("OFF")
  endif

  Umgebung( LOAD )
return
/** eop */

/** Liefert einen printBuffer mit der Fertigungsdauer des akt. Artikels */
function getFertDauerPrintBuffer(menge)
LOCAL printBuffer:=printBuffer():new()
LOCAL dlDauer:=0,dl
LOCAL dlArtnrs
LOCAL linie:=replicate('-',72)
LOCAL aktRec:=ARTIKEL->(recno())
LOCAL art, summe, wochen, text:="", count:=0

  ->? "Fertigungsdauer - STRG-F5"
  ->?
  ->? "Art.Nr.     Art Bezeichnung                     Menge ME    Dauer"
  ->? linie

  for each art in {"next","current","prev"}
    summe:=0
    ARTIKEL->(dbgoto( aktRec ))

    if art=="next"
      dlArtnrs:=getNextArtikelStkList(ARTIKEL->ArtNr,, Menge)
      text:=""
    elseif art=="current"
      dlArtnrs:={Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art,Menge)}
      text:=""
    else
      dlArtnrs:=getPreviousArtikelStkList(ARTIKEL->ArtNr,, Menge)
      text:="Vorlauf"
    endif

    if len(dlArtnrs) > 0
      // ->? text
      // ->? linie

      for each dl in dlArtnrs
        ARTIKEL->(dbseek( dl:ArtNr ))
        EINHEIT->(dbseek( ARTIKEL->ME))
        dlDauer:=getGesFertDauer(dl:ArtNr, dl:Menge)
        ->? out(ARTIKEL->ArtNr), getArtikelArt(),"",ARTIKEL->Bez1,"", str(dl:Menge,5),;
          EINHEIT->Text," "
        if getArtikelArt() <> "M"
          ->?? getStdTagText(dlDauer,,18)
          summe += dlDauer
          count++
        else
          // FIXME: should be COLOR_GREY
          ->?? COLOR_RED,getStdTagText(dlDauer,,18),COLOR_DEFAULT
        endif
      next
      if count > 0
        wochen:=getWochen(summe)
        ->? linie
        ->? str(wochen,3),left(iif(wochen>1,"Wochen ","Woche ")+text+space(53),53),;
          getStdTagText(summe,,24)
        ->?
      endif
    endif
  next

  ARTIKEL->(dbgoto( aktRec ))

return printBuffer

/*
 * Alle Rechnungen des Kunden
 */
PROCEDURE RechnListe(MKundNr)
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.,summe:=0
LOCAL sortFelder:="RECHAUS->RechNr"

  Umgebung(WRITE_ALL)

  if ! open("Rechaus","Zahlkond")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  cls
  titel("Rechnungen je Kunde: "+MKundNr+KUNDEN->KurzName)

  Drucker("BS")

  Message("Datei wird sortiert.   Bitte warten...")

  select Rechaus
  index on &(sortFelder) tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for RECHAUS->Brutto > 0 .and. RECHAUS->KundNr == MkundNr .and. empty(RECHAUS->STORNO_NR)

  /* Relation setzten */
  SELECT Rechaus
  SET RELATION TO RECHAUS->ZkNr into Zahlkond

  Message("Liste wird erstellt.  Bitte warten....")
  go top
  do while .not. RECHAUS->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Miki Plastik GMBH  ***  Rechnungen  ***",space(11),"vom:",getUser():date,,"  Seite ",;
      str(seite,3)
    ? replicate("-",87)
    ? "KD-Nr.   N a m e                  RE-Nummer RE-Dat.  AB-Nr.     Brutto Bezahl-Datum"
    ? replicate("-",87)
    _____fixedHeader_____
    do while .not. RECHAUS->(eof()) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand
      ? ZEIGE_KUNDNR + KdOut(RECHAUS->Kundnr),RECHAUS->KurzName,ZEIGE_RECHNR + RECHAUS->RechNr,;
        RECHAUS->ReaDat,ZEIGE_AUFNR + RECHAUS->AufNr,transStr(RECHAUS->Brutto,11,2)
      if empty(RECHAUS->Bezahlt)

        ?? COLOR_RED,"F�llig:",RECHAUS->Faellig,"MS:",RECHAUS->Mahnstufe
        if getUser():getCurrentPrintJob():className() == "BSJOB"
          ? space(33)
        else
          ? space(37),WINZIG_AN
        endif

        if empty(ZAHLKOND->Text2)
          ?? trim(ZAHLKOND->Text)
        else
          ?? trim(ZAHLKOND->Text) + ",", trim(ZAHLKOND->Text2)
        endif
        if getUser():getCurrentPrintJob():className() <> "BSJOB"
          ?? WINZIG_AUS
        endif
        ?? COLOR_DEFAULT

      else
        ?? RECHAUS->Bezahlt
      endif


      summe += RECHAUS->Brutto
      skip
    enddo

    if RECHAUS->(eof())
      ? replicate("-",87)
      ? space(55) , transStr( summe, 14 , 2)
    endif
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  getUser():getCurrentPrintJob():endDoc()
  getUser():setCurrentPrintJob(NIL)

  Umgebung(LOAD)
RETURN
/* EOP Auftrags_Liste */

/* Zeigt die freien innerbetr. Auftragsnummern an */
Procedure FreieInnerNrList()
LOCAL i , nr , count:=0, col:=0 , maxCol:=6
LOCAL Zeile:=0
LOCAL kostenStNr:=getProperty("Miki.av.inner.kostenst","")

  cls
  Titel("Freie innerbetr. Auftragsnummern anzeigen")

  Message("Nummern werden gesucht.   Bitte warten...")

  if open("Inner")
    Drucker("BS")
    ? "Freie innerbetriebliche Auftragsnummern   vom",getUser():Date
    ? "======================================================"
    _____fixedHeader_____
    ?

    for i:=INNER_NR_BEGINN to INNER_NR_END
      nr:=getInnerShifted(i)
      if ! alltrim(nr) $ kostenStNr
        INNER->(dbseek( nr ))
        if INNER->(eof())
          ?? nr
          col++
          count++
          if col > maxCol
            col:=0
            ?
          endif
        endif
      endif
    next

    ? "======================================================"
    ? "Anzahl freie Nummern:",str(count,4)
    Drucker("OFF")
  endif

  close data
  cls
return
/** eop */

/* Zeigt die lange nicht benutzen innerbetr. Auftragsnummern an */
Procedure AlteInnerList()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.
LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0,M_Ausschuss:=0
LOCAL currentKW:=getCurrentKW()

  cls
  Titel(' "Alte" Auftragsnummern anzeigen')

  Umgebung(WRITE_ALL)

  if ! open("Inner","Artikel","AufAus","Einheit")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    return
  endif

  Drucker("BS","Alte Innerbetr. Auftr�ge")
  Message("Liste wird erstellt.   Bitte warten...")

  select Artikel
  set rela to ARTIKEL->ME into Einheit

  SELECT Inner
  index on kwIndex(INNER->Lief_KW) tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for INNER->Erledigt <> "J" .and. isInnerHauptArbeitsgang() .and. ;
    kwDiff(INNER->Lief_KW, currentKW) > 4

  set rela to INNER->ArtNr into Artikel

  go top
  do while .not. INNER->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? 'Interne Bestellungen - Liefertermin um 4 Wochen �berschritten    aktuelle KW:' + currentKW
    ? '----------------------------------------------------------------------------------'
    ? "InnerNr. Datum       Menge    Gelief    Rest ME Fert.KW  Lief.KW"
    ? '----------------------------------------------------------------------------------'
    _____fixedHeader_____

    do while .not. INNER->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      ? ZEIGE_INNERNR+INNER->InnerNr,space(2),INNER->AufDat,INNER->Menge, str( INNER->GeliefGes , 9,2) ,;
        str(Max(INNER->Menge - INNER->GeliefGes,0) ,7),EINHEIT->Text,space(0),;
        INNER->Fert_KW, space(2),INNER->Lief_KW

      ? space(7),out(INNER->ArtNr),ARTIKEL->Bez1

      if ! empty( ARTIKEL->Bez2 )
        ? space(7),space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif

      if ! empty(INNER->AufNr)
        AUFAUS->(dbseek(INNER->AufNr))
        ? space(7),AUFAUS->AufNr,AUFAUS->Kurzname, AUFAUS->AufDat
      else
        if ! empty(INNER->Grund)
          ? space(7),INNER->Grund
        endif
      endif

      if ! empty(INNER->Bemerkung)
        aEval(HB_ATokens(INNER->Bemerkung,MY_CR+MY_LF),;
          { |x| getUser():getCurrentPrintJob():print({space(7),x},.t.),zeile++,.t. })
      endif
      ?

      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    ? '----------------------------------------------------------------------------------'
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)
return
/** eop */

/** ruft ArtBestellListe auf, selektier passenden Artikel vorher */
function myArtBestellListe( ZeilenText , ZeigeData )
LOCAL mArtNr:=ZeigeData[ ZEIGE->(fieldPos("ArtNr" )) ]

  ignore ZeilenText

  Umgebung(WRITE_ALL)
  ARTIKEL->(dbseek(mArtNr))
  ArtBestellListe()
  Umgebung(LOAD)
return .t.
/** eof */

/** Listet alle vorzufertigen Teile mit Unterbaugruppen/schritten auf
  *
  * Einstieg sind jeweils der tiefste Artikel in der Hierarchie mit Mind.Bestand.Ist
  *
  * Falls Artikel aus mehr als einem Artikel bestehen, z�hlen Sie zur Montage
  * vorher ist es Produktion / Vorfertigung
  */
PROCEDURE ProduktionsListe()
LOCAL seite:=0, zeile:=0, printBuffer, debugPrintBuffer,selArt
LOCAL Stop:=.f. , bedarf, sumBaugruppen, debug:="N" , aktRec
LOCAL GetList:={}, von,bis, nurMindBest:="J" , bestVorhanden, merk_order, bestellOnly:="J"

  Umgebung(WRITE_ALL)

  if ! open("Artikel","AvPost","AvAus","Einheit","BesPost","BesAus","Inner")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  cls
  titel("Produktions-Liste - Artikel mit Mind.Bestand")

  if empty( bis:=von_bis("Artikel") )
    Umgebung(LOAD)
    RETURN
  endif
  von:=ARTIKEL->ArtNr
  selArt:=" "

  @ 12,18 to 18,58
  @ 13,20 say "Artikel-Art...:" get selArt picture "!";
    when Message('@Leer@=Alle @B@eisst. @D@ienstl. @E@inkaufs-Art. @F@ert.-Art. @T@ext @W@erkzeug '+;
    'E@x@-Artikel') valid selArt $ ALLE_ARTIKEL_ARTEN+" "

  // @ 15,20 say "Lagerbestand Baugruppen anzeigen:" get debug picture "!" when // Message('Details/Baugruppen zur Berechnung des Bestands anzeigen?  (@J@/@N@)') valid debug $ "JN"

  @ 15,20 say "Nur Artikel mit Bedarf anzeigen:  " get nurMindBest picture "!" when;
    Message('Nur Artikel unter Mind.Bestand anzeigen?  (@J@/@N@)') valid nurMindBest $ "JN"

  @ 17,20 say "Artikel mit Bestellung ausblenden:" get bestellOnly picture "!";
    when;
    Message('Artikel mit offener externen Bestellung nicht anzeigen?  (@J@/@N@)');
    valid bestellOnly $ "JN"

  Read
  If ABBRUCH .or. ! druck_BS() // Abbruch
    Umgebung(LOAD)
    RETURN
  endif

  if empty(selArt) // alle selektiert
    selArt:=ALLE_ARTIKEL_ARTEN
  endif

  SELECT BesPost
  set relation to BESPOST->BestNr into BesAus

  Message("Liste wird erstellt.   Bitte warten...")

  // select AvAus
  // go top
  // do while .not. AVAUS->(eof()) .and. ! stop
  // // pr�fe ob in keiner anderen St�ckliste vorkommt = nur oberste Ebene
  // select Avpost
  // AVPOST->(OrdSetFocus( 2 ))
  // AVPOST->(dbseek(AVAUS->AvNr))
  // AVPOST->(OrdSetFocus( 1 ))
  // if AVPOST->(eof())
  // childHasMindBestand( alleArtikel , AVAUS->AvNr )
  // endif

  // select Avaus
  // skip
  // enddo

  M->specialZeige:={}
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )

  AVPOST->(OrdSetFocus( 2 ))
  printBuffer:=printBuffer():new()

  // i:=1
  // do while i <= len( alleArtikel:keys )
  select Artikel
  do while ! ARTIKEL->(eof()) .and. ARTIKEL->Artnr<=bis .and. ! stop
    seite=seite+1
    zeile:=0
    ?"Produktions-Liste",space(11),"vom:",getUser():date,,"  Seite ",str(seite,3)
    ?replicate("-",98)
    ?"Art.Nr.   Bezeichnung                    ME    Mindest-    Lager Baugruppen   Auftrags   "+;
      "Verf�gbar"
    ?"                                               Bestand   Bestand    Bestand    Bestand      "+;
      "      "
    ?replicate("-",98)
    _____fixedHeader_____
    do while ! ARTIKEL->(eof()) .and. ARTIKEL->Artnr<=bis .and.;
      zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop

      // Nur Artikel mit MindestBestand und der gew�hlten Art
      if ARTIKEL->MinbestI == 0 .or. (! empty(selArt) .and. ! getArtikelArt() $ selArt )
        skip
        loop
      endif

      // 27.8.2015: wenn bereits offene Bestellungen vorhanden
      // sind, dann gilt Mind.Bestand nicht mehr
      // externe Bestellungen
      if getArtikelArt() == "E"
        SELECT BesPost

        // Nur offene Bestellungenpr�fen
        index on BESPOST->ArtNr+BESPOST->BestNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
          for BESPOST->ArtNr=ARTIKEL->ArtNr .and. BESPOST->Menge > BESPOST->GeliefGes ;
          .and. BESAUS->Erledigt<>"J"

        go top
        bestVorhanden:=(! BESPOST->(eof()))

        BESPOST->(OrdSetFocus(merk_order))
        BESPOST->(OrdDestroy(TEMP_INDEX))
        select Artikel
        if bestellOnly == "J" .and. bestVorhanden
          skip
          loop
        endif
      endif // Art == E

      // summiere Baugruppen
      aktRec:=ARTIKEL->(recno())
      debugPrintBuffer:=PrintBuffer():new()
      sumBaugruppen:=summiereBaugruppen( ARTIKEL->ArtNr , ARTIKEL->ME , 0 , debugPrintBuffer)
      ARTIKEL->(dbgoto( aktRec ))

      // drucke Eregbnis
      EINHEIT->(dbseek( ARTIKEL->ME ))
      bedarf:=Max(ARTIKEL->LageBest,0) - ARTIKEL->disponiert

      if nurMindBest == "J" .and. ARTIKEL->MinBestI < (bedarf + sumBaugruppen)
        skip
        loop
      endif

      // drucke Bedarf*/
      ->?ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1, EINHEIT->Text,space(2),ARTIKEL->MinBestI,;
        str(ARTIKEL->LageBest,9,0), str(sumBaugruppen,10) , str(ARTIKEL->disponiert,9,0), str(bedarf,9,0)

      // debug output Summe vorstufen
      if debug=="J" .and. debugPrintBuffer:getNumLines() > 0
        debugPrintBuffer:insertTopTextLine( space(26)+"Baugruppen:" )
        debugPrintBuffer:insertTopTextLine( { "" } )
        debugPrintBuffer:addNewLine()
        printBuffer:addBuffer(debugPrintBuffer)
      endif

      // Drucke Posten der einzelnen Bestellungen
      // externe Bestellungen & interne Bestellungen
      printBuffer:leftMargin:=10
      ArtBestellListe(printBuffer)
      printBuffer:leftMargin:=0

      zeile+=getUser():getCurrentPrintJob():printBuffer(printBuffer)
      printBuffer:=printBuffer():new()

      skip
      stop:=stop_key() // ESC gedr�ckt ?

    enddo
  enddo

  getUser():getCurrentPrintJob():endDoc()
  getUser():setCurrentPrintJob(NIL)

  Umgebung(LOAD)
RETURN
/* EOP Auftrags_Liste */

/** pr�ft alle Unterartikel rekursiv, ob sie einen Mind.Bestand haben
*  falls ja wir der tiefste Artikel davon in die HashTabelle alleArtikel eingef�gt
*/
  // static function childHasMindBestand( alleArtikel , mArtNr )
  // LOCAL hasChildwithMindBestand:=.f.
  // LOCAL aktRec:=AVPOST->(recno()) , count:=0

  // if hb_HHasKey( alleArtikel , mArtNr )
  // return .f.
  // endif

  // select AvPost
  // dbseek( mArtNr )

  // do while .not. AVPOST->(eof()).and. AVPOST->AvNr==mArtNr
  // if AVPOST->Art=="M" .and. AVPOST->Text=="A"
  // count++
  // hasChildwithMindBestand:=childHasMindBestand( alleArtikel , AVPOST->ArtNr ) 
  // .and. hasChildwithMindBestand
  // endif
  // skip
  // enddo

  // if count > 0 .AND. ! hasChildwithMindBestand // 1. Fertigungsstufe wird ignoriert
  // // Artikel ist letzter in Hierarchie mit Mind.Bestand
  // ARTIKEL->(dbseek( mArtNr ))
  // if ARTIKEL->MinbestI > 0 .and. getArtikelArt() $ "FM"
  // alleArtikel[mArtNr]:=.t.
  // endif
  // endif

  // AVPOST->(dbgoto( aktRec ))

  // return hasChildwithMindBestand
/** eof */

/** summiert den Lagerbestand aller untergeordneter Baugruppen des Artikels (rekursiv)
  * so lange die Einheit identisch ist */
static function summiereBaugruppen(mArtNr , mME , tiefe, printBuffer , anzahl)
LOCAL result:=0
LOCAL aktRec, aktSel:=alias()

  select AvPost
  dbseek( mArtNr )

  do while .not. AVPOST->(eof()).and. AVPOST->ArtNr==mArtNr
    if AVPOST->Art=="M" .and. AVPOST->Text=="A"
      aktRec:=AVPOST->(recno())
      ARTIKEL->(dbseek( AVPOST->AvNr ))
      if ARTIKEL->ME == mME
        if ARTIKEL->Preis1 == 0
          result;
            +=;
            summiereBaugruppen( ARTIKEL->ArtNr , ARTIKEL->ME ,tiefe+1 , printBuffer, AVPOST->Menge)
        else
          result += ARTIKEL->Lagebest
        endif
      endif
      AVPOST->(dbgoto( aktRec ))
      // exit // take 1st record only!
    endif
    skip
  enddo

  select ( aktSel )
  ARTIKEL->(dbseek( mArtNr ))
  if tiefe > 0 .and. ARTIKEL->Lagebest > 0
    result += ARTIKEL->Lagebest * Anzahl
    ->? space(25), ARTIKEL->ArtNr, ARTIKEL->Bez1,str(ARTIKEL->LageBest,9)
  endif

return result
/** eof */


  /*
  *  Ger�te je Kunde (K-Lager)
  */
PROCEDURE Auf_GeratListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL datVon:=ctod('  .  .  '),datBis:=ctod('  .  .  ')
LOCAL Stop:=.f.
LOCAL artvon,artbis,Ausgabe, mKundNr:="10167-  "

  if ! open("Kunden","konsig","Artikel","KundSped")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Ger�te-Liste detailliert")

  @ 10,20 say "Kunde:" get mKundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",.f.)} ;
    when Message("Kunde eingeben  @F12@=Auswahl")
  @ 12,20 say "von  :" get DatVon when Message("Zeitraum eingeben oder @leer@ f�r alle.")
  @ 13,20 say "bis  :" get DatBis // valid DatBis >= DatVon
  read

  if ABBRUCH
    close data
    return
  endif

  artvon:=artbis:=space(len(ARTIKEL->ArtNr))
  artbis:=von_bis("Artikel",20,15)
  artvon:=ARTIKEL->ArtNr

  Message("Datei wird sortiert.   Bitte warten...")

  select Konsig
  index on KONSIG->Kundnr+kwindex(KONSIG->KW) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    KONSIG->KundNr==mKundNr .and. (empty(DatVon) .or. KONSIG->Liedat >= DatVon) .and.;
    (empty(DatBis) .or. KONSIG->Liedat <= DatBis) .and. (empty(artVon) .or. KONSIG->ArtNr >= artVon) .and. (empty(artBis) .or. KONSIG->ArtNr <= ArtBis) .and. (! empty(KONSIG->GerVon) .or. ! empty(KONSIG->GerBis))


  /* Relation setzten */
  SET RELATION TO KONSIG->ArtNr into Artikel
  go top
  Ausgabe:=Druck_Bs("Ger�te-Kunde")

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.KONSIG->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Miki Plastik GMBH  ***  Ger�teliste Kunde:",mKundNr,KUNDEN->KurzName,"***  vom:",;
      getUser():date,"Seite :",str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '------------------'
    ? "AB-Nr. Datum   Art.Nr.  Bezeichnung                              Ger�te-Nummern"
    ? '-------------------------------------------------------------------------------'
    _____fixedHeader_____

    do while .not.KONSIG->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand
      ? KONSIG->AufNr,KONSIG->Liedat,KONSIG->ArtNr,KONSIG->Komm1,KONSIG->GerVon,"-",KONSIG->GerBis
      if ! empty(KONSIG->Komm2)
        ? space(30), KONSIG->Komm2
      endif
      Stop:=stop_key()
      skip
    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  drucker("OFF")
  close data

  M->specialZeige:=NIL

RETURN
/* EOP Auftrags_Liste */


  /*
  *  Auftr�ge mit zugeh. Rechnungen
  */
PROCEDURE AB_RechnungsListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL Stop:=.f.
LOCAL von:=getUser():date,bis:=getUser():date
LOCAL monSumme:=0, gesSumme:=0, aktMonat

  if ! open("AufAus","Rechaus")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Offene Auftr�ge / Rechnungen")

  @ 7,28 to 12,52
  @ 8,30 say "Datum von :" get von when message("Rechnung Datumsbereich Anfang eingeben.")
  @ 10,30 say "Datum bis :" get bis when message("Rechnung Datumsbereich Ende eingeben.")
  read
  if ABBRUCH
    cls
    close data
    return
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  SELECT RechAus
  index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE ;
    for RECHAUS->ReaDat >= von .and. RECHAUS->ReaDat <= bis

  set relation to RECHAUS->AufNr into AufAus

  if ! druck_BS() // Abbruch
    cls
    close data
    RETURN
  endif

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.RECHAUS->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Miki Plastik GMBH  - Umsatz          vom:",getUser():date,space(9),"Seite :",str(seite,3)
    ? replicate('-', 72)
    ? "Rechnungen                                        Netto   Auftrag"
    ? "Nr.   Datum    Kunde                             Umsatz   Nr.   Datum"
    ? replicate('-', 72)
    _____fixedHeader_____
    aktMonat:=getMonth(RECHAUS->ReaDat)
    do while .not.RECHAUS->(eof()).and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ! stop
      ? RECHAUS->RechNr, RECHAUS->ReaDat, RECHAUS->Kurzname,transform(RECHAUS->Netto,"@E "+;
        "999,999,999"),space(1),AUFAUS->AufNr,AUFAUS->AufDat
      monSumme += RECHAUS->Netto
      gesSumme += RECHAUS->Netto
      RECHAUS->(dbskip())
      // Zwischensumme?
      if aktMonat <> getMonth(RECHAUS->ReaDat)
        ? space(40), replicate('-',14)
        ? 'Monat:', aktMonat,space(30),transform(monSumme,"@E 999,999,999"),'Euro'
        ?
        aktMonat:=getMonth(RECHAUS->ReaDat)
        monSumme:=0
      endif
    enddo
    stop:=stop_key() // ESC gedr�ckt ?

    // Gesamtsumme?
    if RECHAUS->(eof())
      ? space(40), replicate('=',19)
      ? 'Gesamt:', space(35),transform(gesSumme,"@E 999,999,999"),'Euro'
    endif

    Zeile:=FormFeed(Zeile,Seite)
  enddo

  getUser():getCurrentPrintJob():endDoc()
  getUser():setCurrentPrintJob(NIL)

  cls
  close data

  M->specialZeige:=NIL

RETURN
/* EOP Auftrags_Liste */


  /*
  *  Artikel je Kunde
  */
PROCEDURE ArtikelKundListe()
LOCAL seite:=0, zeile:=0, GetList:={}
LOCAL datvon:=ctod("01.01."+str(year(getUser():date))), datbis:=getUser():date
LOCAL Stop:=.f.
LOCAL artvon,artbis,Ausgabe, mKundNr:="     -  "
LOCAL summen:=hb_hash(), aktJahr, aktArtikel, aktGelief, aktWert, aktEinheit, anzPosten, gesamtWert
LOCAL div, wert

  if ! open("Rechpost", "Rechaus", "Artikel","Kunden", "KundSped","Einheit")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Artikel je Kunde / Jahr")

  @ 10,20 say "Kunde:" get mKundNr PICTURE KDNR_PICT valid { |oGet| check(oGet,"Kunden",.f.)} ;
    when Message("Kunde eingeben  @F12@=Auswahl")
  @ 12,20 say "von  :" get DatVon when Message("Zeitraum eingeben oder @leer@ f�r alle.")
  @ 13,20 say "bis  :" get DatBis // valid DatBis >= DatVon
  read

  if ABBRUCH
    close data
    return
  endif

  artvon:=artbis:=space(len(ARTIKEL->ArtNr))
  artbis:=von_bis("Artikel",20,15)
  artvon:=ARTIKEL->ArtNr

  Message("Datei wird sortiert.   Bitte warten...")

  /* Relation setzten */
  select Artikel
  SET RELATION TO ARTIKEL->ME into Einheit
  select rechpost
  SET RELATION TO RECHPOST->ArtNr into Artikel, TO RECHPOST->RechNr into Rechaus

  // filter
  index on str(year(RECHPOST->ReaDat))+RECHPOST->ArtNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    rechpost->KundNr==mKundNr .and. (empty(DatVon) .or. RECHPOST->ReaDat >= DatVon) .and.;
    (empty(DatBis) .or. RECHPOST->ReaDat <= DatBis) .and. (empty(artVon) .or. RECHPOST->ArtNr >= artVon) .and. (empty(artBis) .or. RECHPOST->ArtNr <= ArtBis) .and. len(alltrim(RECHPOST->artnr)) > FRACHT_LAENGE .and. alltrim(RECHPOST->ArtNr) <> ANGEBOTS_ARTIKEL

  go top
  Ausgabe:=Druck_Bs("Artikel-Kunde")

  /** Spezial Funktion Zeige freischalten */
  M->specialZeige:={}
  aadd( M->specialZeige , { chr(K_F5)+;
    chr(K_LDBLCLK) , { |a,b| rekLiStklist( a , b )} , "@F5@=aufl�sen" } )
  aadd( M->SpecialZeige , { chr(K_F6) , { |a , b| rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )
  aadd( M->specialZeige , { chr(K_CTRL_F9), { |a,b| rekLiAufBestArtikel( a , b )} , "@STRG-F9@=ABs" } )

  aktJahr:=year(RECHPOST->ReaDat)
  aktArtikel:=RECHPOST->Artnr
  aktGelief:=0
  aktWert:=0
  anzPosten:=0
  gesamtWert:=0

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.RECHPOST->(eof()) .and. ! stop
    seite=seite+1
    zeile:=0
    ? "Artikelliste Kunde:",mKundNr,KUNDEN->KurzName,"  vom:",getUser():date,"Seite :",str(seite,3)
    ? '------------------------------------------------------------------------------------------'+;
      '-------------'
    ? 'Art.Nr.   Bezeichnung                              Re-Nr. Datum       Preis      Menge     '+;
      'Netto-Gesamt'
    ? '------------------------------------------------------------------------------------------'+;
      '-------------'
    _____fixedHeader_____

    aktJahr:=year(RECHPOST->ReaDat)
    do while .not.RECHPOST->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and.;
      aktJahr == year(RECHPOST->ReaDat)

      do while .not.RECHPOST->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and.;
        aktJahr == year(RECHPOST->ReaDat) .and. aktArtikel == RECHPOST->Artnr

        // berechne Wert abzgl. Rabatte
        div=IIF(RECHPOST->PE$"Hh",100,1)
        wert=abs(ROUND(RECHPOST->Preis * RECHPOST->menge/div,2))
        IF RECHPOST->rabatt<>0.0
          wert= wert - ROUND(wert * RECHPOST->Rabatt /100,2)
        endif
        IF RECHAUS->SO_Rabatt <> 0.0
          wert= wert - ROUND(wert * RECHAUS->SO_Rabatt/100,2)
        endif

        ? RECHPOST->ArtNr,RECHPOST->Komm1,RECHPOST->RechNr,RECHPOST->ReaDat,;
          transstr(RECHPOST->Preis,9,2),RECHPOST->PE, transstr(RECHPOST->Gelief,8,0),;
          EINHEIT->Text, transstr(wert,12,2), EURO_SIGN
        if ! empty(RECHPOST->Komm2)
          ? space(len(RECHPOST->ArtNr)), RECHPOST->Komm2
        endif
        aktGelief += RECHPOST->Gelief
        aktWert += Wert
        anzPosten++
        aktEinheit:=EINHEIT->Text
        Stop:=stop_key()
        skip
      enddo

      // neuer Artikel -> Zwischensumme
      if aktArtikel <> RECHPOST->Artnr
        if anzPosten > 1
          ? space(78),"------------------------"
          ? space(75),transstr(aktGelief,10,0),aktEinheit, transstr(aktWert,12,2), EURO_SIGN
        endif
        ?
        if hb_HHasKey( summen, aktArtikel)
          summen[aktArtikel] += aktGelief
        else
          summen[aktArtikel]:=aktGelief
        endif

        gesamtWert += aktWert
        aktArtikel:=RECHPOST->Artnr
        aktGelief:=0
        aktWert:=0
        anzPosten:=0

        if RECHPOST->(eof())
          ? '------------------------------------------------------------------------------------'+;
            '-------------------'
          ? space(67),"Gesamtwert (netto):", transstr(Gesamtwert,15,2), EURO_SIGN
        endif
      endif

    enddo
    Zeile:=FormFeed(Zeile,Seite)
  enddo

  // // Gesamtsumme
  // seite=seite+1
  // ? "SUMME: Artikelliste Kunde:",mKundNr,KUNDEN->KurzName,"  vom:",getUser():date, "Seite :",str(seite,3)
  // ? "Verkaute Artikel vom",DatVon, "-", DatBis
  // ? '======================================================'
  // ? 'Art.Nr.   Bezeichnung                            Menge'
  // ? '======================================================'
  // for each aktArtikel in Summen:Keys
  // _____fixedHeader_____

  // ARTIKEL->(dbseek(aktArtikel))
  // ? ARTIKEL->ArtNr,ARTIKEL->Bez1, Summen[aktArtikel], EINHEIT->Text
  // if ! empty(ARTIKEL->Bez2)
  // ? space(len(ARTIKEL->ArtNr)), ARTIKEL->Bez2
  // endif

  // next
  // ? '============================================================='

  drucker("OFF")
  close data

  M->specialZeige:=NIL

RETURN
/* EOP Auftrags_Liste */

procedure artPrGrListe()
LOCAL seite:=0, zeile:=0
LOCAL Stop:=.f.

  Umgebung(WRITE_ALL)

  if ! open("Artikel")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN
  endif

  select Artikel
  set filter to ARTIKEL->PrGr == ARTPRGR->PrGr

  Drucker("BS")
  Message("Liste wird erstellt.   Bitte warten...         @ESC@=Abbruch")

  go top
  do while .not. ARTIKEL->(eof()) .and. ! stop
    Seite=Seite+1
    Zeile:=0
    ? "Artikel mit Preisgruppe: "+ARTPRGR->PrGr,'Seite',str(seite,3)
    ? '---------------------------------------------------'
    ? "Art.Nr.    Bezeichnung                              "
    ? '---------------------------------------------------'
    _____fixedHeader_____

    do while .not. ARTIKEL->(eof()) ;
      .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand .and. ! stop
      ? ZEIGE_ARTNR+out(ARTIKEL->ArtNr),ARTIKEL->Bez1
      if ! empty(ARTIKEL->Bez2)
        ? space(len(out(ARTIKEL->ArtNr))),ARTIKEL->Bez2
      endif
      skip
      Stop:=stop_key()
    enddo // Blattl�nge
    Zeile:=FormFeed(Zeile,Seite)
  enddo // eof()

  Drucker("Off")
  Umgebung(LOAD)

return


/*
* Umsatz je Kunde f�r Versicherung
// 1x j�hrlich
// -> KZ f�r in Versicherung oder ignorieren -> nachmelden unterj�hrig m�glich
// nur die kritischen aufnehmen -> spart Geld bei der Police
// Abfrage von Kunden-Limit oder max. Zahlungsziel im Alianz Portal
//
// Wir ben�tigen optimalerweise den maximalen Au�enstand (Saldo) auf Nettobasis, der auflaufen ;
  k�nnte (bis zum Zeitpunkt des Lieferstopps wegen �berf�lligkeit).
//
// Der Deckungsbedarf sollte den maximalen Au�enstand abbildet und dies als die sogenannte ;
  ?Versicherungssumme? aufgef�hrt werden.
//
// Weiterhin ben�tigen wir die Angabe �ber die Zahlungsziele (von Minimum bis Maximum) sowie den ;
  versicherbaren Umsatz auf Nettobasis pro Jahr.
*/
PROCEDURE KundenUmsatzListe()
LOCAL Zeile:=0, Seite:=0, GetList:={}, stop:=.f.
LOCAL mJahr:=year(getUser():date)
LOCAL minValue:=0
LOCAL aktKundNr
LOCAL Ausgabe, export, kdRechnungen
LOCAL nMaxNetto:=0, aMaxRech, maxRow
LOCAL objErr, rech
LOCAL sumIt:="J"

  if ! open("Rechpost", "Rechaus","Kunden", "Zahlkond")
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif

  cls
  titel("Umsatz je Kunde / Jahr")

  @ 3,2 say "Berechnung des Deckungsbedarf der Kunden mit Umsatz ab dem eingegeben Jahr."
  @ 5,2 say "Falls unten bei addieren ein J eingegeben wird:"
  @ 7,2 say "wird f�r jede Rechnung ab dem eingegeben Jahr der Zeitraum bis zum"
  @ 8,2 say "Zahlungsziel genommen, und alle Rechnungen in diesem Zeitraum werden summiert."
  @ 9,2 say "Davon der h�chste => maximaler Au�enstand, Saldo auf Nettobasis."

  @ 11,2 say "Falls unten bei addieren ein N eingegeben wird:"
  @ 12,2 say "wird nur jeweils die h�chste Rechnung ab dem eingegeben Jahr genommen."

  @ 14,2 say "Kunden mit Vers.KZ=N werden nicht angezeigt, siehe Kundenstamm Vers.KZ"

  @ 16,2 say "Ab Jahr (inklusive)..................:" get mJahr PICTURE "@9";
    when Message("1. zu berechnendes Jahr eingeben  " + "@F12@=Auswahl")
  @ 17,2 say "Mindest-Summe (Netto)................:" get minValue picture "@9" ;
    when Message("Bitte den Netto-Mindest-Betrag eingeben   (0==Alle).")
  @ 18,2 say "Rechnungen per Zahlungsziel addieren :" get sumIt picture "!" valid sumIt $"JN" ;
    when Message("Rechnungen im Zeitraum der offenen Zahlungen addieren? (@J@/@N@)")
  read

  if ABBRUCH
    close data
    return
  endif

  Message("Datei wird sortiert.   Bitte warten...")

  /* Relation setzten */
  select rechaus
  SET RELATION TO RECHAUS->KundNr into Kunden

  // filtered index
  index on RECHAUS->KundNr+dtos(RECHAUS->ReaDat) tag TEMP_INDEX TEMPORARY ADDITIVE for ;
    year(RECHAUS->ReaDat)>=mJahr .and. KUNDEN->AusfVers<>"N"

  go top
  Ausgabe:=Druck_Bs("Ausfallversicherungsliste", .t.)

  //altd()

  if valtype(Ausgabe)=="C" // Excel
    BEGIN SEQUENCE // krit. Bereich
      export:=getUser():exportPATH() + BACKSLASH + cleanFileName(Ausgabe)
      getUser():setCurrentPrintJob(ExcelJob():new())
      getUser():getCurrentPrintJob():StartDoc( export )
    RECOVER USING objErr
      // nop, Fehler bereits protokolliert
    END SEQUENCE
  endif

  Message("Liste wird erstellt.  Bitte warten....")
  do while .not.RECHAUS->(eof()) .and. ! stop

    seite=seite+1
    zeile:=0
    if valtype(export)=="C" // Excel
      if seite==1
        ? "Name Firma (inkl. Rechtsform)",	"Zusatz Name", "Strasse1",	"Zusatz Strasse", "PLZ",;
          "Ort", "Land", "ID-Nummer", "Deckungsbedarf bei Kunden", "Waehrung", "Zahlungsziel",;
          	"Kund.Nr.", "Rechnungs-Nummern"
      endif
    else
      ? "Name Firma (inkl. Rechtsform)",	"Zusatz Name", "Strasse1",	"Zusatz Strasse", "PLZ",;
        "Ort", "Land", "ID-Nummer", "Deckungsbedarf bei Kunden", "Waehrung", "Zahlungsziel",;
        	"Kund.Nr.", "Rechnungs-Nummern"
      ? replicate("=", 80)
    endif

    _____fixedHeader_____

    do while .not.RECHAUS->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand

      aktKundNr:=RECHAUS->KundNr
      kdRechnungen:={}
      do while .not.RECHAUS->(eof()) .and. ! stop .and. zeile<DRUCKER->laenge-LISTE->Unt_Rand .and. ;
        aktKundNr == RECHAUS->KundNr

        // add new invoice to sum list
        aadd(kdRechnungen, VersRechnung():new())

        // now add to other invoices if in same time frame
        if sumit=="J"
          for each rech in kdRechnungen
            if .not. RECHAUS->RechNr $ rech:rechnr
              if RECHAUS->ReaDat >= rech:readat .and. RECHAUS->ReaDat <= rech:faellig
                rech:rechnr += ","+RECHAUS->RechNr
                rech:nettoSumme += RECHAUS->Netto
              endif
            endif
          next
        endif


        Stop:=stop_key()
        skip
      enddo // Kunde

      // if left(aktkundNr,5)=="10013"
      // altd()
      // endif

      if len(kdRechnungen) > 0

        FOR EACH rech IN kdRechnungen
          IF rech:nettoSumme > nMaxNetto
            nMaxNetto:=rech:nettoSumme
            aMaxRech:=rech
          ENDIF
        NEXT rech

        if aMaxRech<>NIL .and. aMaxRech:nettoSumme > minValue
          KUNDEN->(dbseek(aktKundNr))
          ZAHLKOND->(dbseek(aMaxRech:ZkNr))

          ? KUNDEN->Name, KUNDEN->Partner, KUNDEN->Strasse, KUNDEN->Zusatz, KUNDEN->PLZ, KUNDEN->Ort, ;
            KUNDEN->Land, KUNDEN->IDENTNR, aMaxRech:nettoSumme, "EURO", ;
            trim(ZAHLKOND->Text)+" "+ZAHLKOND->Text2, aktKundNr, aMaxRech:rechNr
        endif
        nMaxNetto:=0
        aMaxRech:=NIL
      endif

    enddo // Seitenumbruch
    Zeile:=FormFeed(Zeile,Seite)
  enddo // Liste

  if valtype(export)=="C" // Excel
    // Excel-Summe
    maxRow:=getUser():getCurrentPrintJob():row
    getUser():getCurrentPrintJob():colNumberFormat( 2 , maxRow , 9 , EXCEL_NUMBER_FORMAT_DEFAULT) // Deckungsbedarf
    // getUser():getCurrentPrintJob():summe(maxRow,9) // Summe Deckugsbedarf
    getUser():getCurrentPrintJob():alignColumn(13) // Rechnungsnummer nach links da Spalte sehr breit werden kann

    drucker("OFF")

    Message("@"+export+"@ wurde erstellt.  Bitte @Taste@ dr�cken.","@")

  else
    drucker("OFF")
  endif
  cls
  close data

RETURN
 /* EOP */


CLASS VersRechnung

DATA rechnr
DATA readat
DATA nettoSumme
DATA faellig
DATA zknr

METHOD new()

ENDCLASS

METHOD new()
  ::rechnr:=RECHAUS->RechNr
  ::readat:=RECHAUS->ReaDat
  ::nettoSumme:=RECHAUS->Netto
  ::faellig:=RECHAUS->Faellig
  ::zkNr:=RECHAUS->ZKNr
RETURN self


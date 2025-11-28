/* Modul: Bank.prg
*
* enth�lt alles bzgl. Bank, Ueberweisung etc.
*
* s. miki.ch:
* #define UEBERWEISUNGS_KZ   "�"
* #define SCHECK_KZ          "S"
* #define SEPA_KZ            "O"    // online IBAN/SEPA �berweisung
*
*/

#include "Miki.ch"

#include "hbqtgui.ch"

#define LISTE_COLSEP "|"

/** Schecks ***********************************************************/

/* erfassen von Scheck
*
*/
PROCEDURE ScheckErfassen()
LOCAL GetList:={}
LOCAL M_BankNr,M_Datum

  cls
  Titel("Schecks  erfassen/drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Hausbank","Scheck_t","ZAHLAUS","Lieferan","BankStam","Kunden")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  /** Relationen setzen */
  select Scheck_t
  set relation to SCHECK_T->LiefNr into Lieferan,;
    to SCHECK_T->LiefNr into Kunden


  m_BankNr:=space(len(HAUSBANK->BankNr))
  do while ! ABBRUCH
    cls
    Titel("Schecks  erfassen/drucken")

    Message("Hausbank eingeben.             @F12@=Hilfe")
    @ 2,2 say "Hausbank:" get M_BankNr picture "@9" valid { |oGet| check(oGet,"Hausbank",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    @ 2,20 say left(BANKSTAM->BankBez,40)
    @ 3,20 say HAUSBANK->AufGeb
    @ 2,64 say "BLZ: "+HAUSBANK->Blz
    @ 3,64 say "Kto: "+HAUSBANK->KtoNr

    ScheckBauch()

    setcolor(COLWIN)
    Fenster(10,26,14,46)
    M_Datum:=getUser():date
    @ 12,28 say "Datum:" get M_Datum
    read
    setcolor(COLNOR)
    if ! ABBRUCH
      ScheckDruck(M_Datum)
      select Scheck_T
      zap
    endif
  enddo

  set key K_F3 to
  cls
  close data
return
/** eop ScheckErfassen */


/** Scheck-Bauch */
FUNCTION ScheckBauch()
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  select Scheck_t

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  // aKopf[EDIT_ENDE_Y]:=21
  aKopf[EDIT_ENDE_Y]:=-2
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_INDEX_FELD]:={ || SCHECK_T->Betr_Euro==0.00 }

  /* Feld-Definitionen */
  // Lieferanten-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="LiefNr"
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_MESSAGE]:="Lief./Kunden-Nummer eingeben.     @F3@=Kunden    @F12@=Lieferanten     @ESC@=Ende"
  aSpalte[EDIT_TITEL]:="Li.Nr"
  // aSpalte[EDIT_UEBERTRAG]:=.t.
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oGet| BankliefNrNach(oGet) .and. ! empty(oGet)}
  aSpalte[EDIT_BEFORE]:={ || SetKey( K_F3 , {|| Hilfe("Bank,Kunden",getNew(),"") } ),.t. }
  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kurzname
  aSpalte[EDIT_NAME]:="if(empty(_FIELD->LiefNr),space(20),getKurzName())"
  aSpalte[EDIT_TITEL]:="Name"
  aSpalte[EDIT_EDIT]:=.f.


  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Fremde Rechn.Nr.
  aSpalte[EDIT_NAME]:="FremdNr"
  aSpalte[EDIT_TITEL]:="Nr. fr/ei Betr."
  aSpalte[EDIT_MESSAGE]:="Fremd-Rechnungsnummer eingeben"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // eigene Rechn.nr.
  aSpalte[EDIT_NAME]:="eigenNr"
  aSpalte[EDIT_AFTER]:={ |oGet| EigenNach(oGet) }
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_MESSAGE]:="Eigene Rechnungsnummer eingeben"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Euro
  aSpalte[EDIT_NAME]:="Betr_Euro"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_POS_X]:=6
  aSpalte[EDIT_MESSAGE]:="@Euro@-Betrag eingeben."
  aSpalte[EDIT_MASKE]:="999999.99"
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Skonto
  aSpalte[EDIT_NAME]:="Skonto"
  aSpalte[EDIT_TITEL]:="Skto"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oget| checkBankSkto( oGet) }
  aSpalte[EDIT_MESSAGE]:="Skonto eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Sk-Betrag
  aSpalte[EDIT_NAME]:="str(Betr_Euro*Skonto/100,7,2)"
  aSpalte[EDIT_TITEL]:="Sk-Bet."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Netto
  aSpalte[EDIT_NAME]:="str(Betr_Euro*(100-Skonto)/100,7,2)"
  aSpalte[EDIT_TITEL]:="Netto"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

RETURN( Edit(aFelder,aKopf) )
/* EOF Scheck_Bauch */


/** ScheckDruck
 */
Procedure ScheckDruck(M_Datum)
LOCAL Zeile:=0,Snetto:=0,Sbrutto:=0,SSk:=0
LOCAL kopf,aktLiefNr
LOCAL betr,sk_betr,netto,kurz,zweck
LOCAL kom1,kom2,kom,schecknr,num1,nachk,net1,kto1,Adresse
LOCAL aktCp

  index on SCHECK_T->LiefNr tag TEMP_INDEX TEMPORARY ADDITIVE
  go top
  // Drucker("BS")
  Drucker("ON")
  // set marg to 5

  do while ! eof()
    aktLiefNr:=SCHECK_T->LiefNr
    zweck:=""
    Zeile:=0 ; Snetto:=0 ; Sbrutto:=0 ; SSk:=0

    /** gehe auf passenden Lieferanten/Kunden */
    Adresse:=getAdresse(aktLiefNr)
    kopf="("+left(alltrim(getKurzname()),13)+"-"+aktLiefNr+")"
    ? space(val(DRUCKER->LR)-1), mytranslate(HAUSBANK->Aufgeb),space(3),mytranslate(kopf)

    ? space(val(DRUCKER->LR)-1), '�����������������������������������������������������'
    ? space(val(DRUCKER->LR)-1), "Ihre Bel.Nr.    Uns.Bel.Nr. Skonto  Rechn.Betrag"
    kurz:="EUR"
    ?? FETT_AN,"(Euro)",FETT_AUS
    ? space(val(DRUCKER->LR)-1), '�����������������������������������������������������'

    do while ! eof() .and. aktLiefNr==SCHECK_T->LiefNr

      betr:=SCHECK_T->Betr_Euro
      sk_betr:=round(betr*SCHECK_T->Skonto/100,2)
      netto:=betr-sk_betr
      zweck+=alltrim(SCHECK_T->EigenNr)+"/"

      ? space(val(DRUCKER->LR)-1),mytranslate(SCHECK_T->FremdNr),mytranslate(SCHECK_T->EigenNr),;
        transform(sk_betr,"@E 999,999.99"),transform(Betr,"@E 999,999,999.99")
      Ssk += sk_betr
      SNetto += netto
      SBrutto+= betr
      skip
    enddo
    do while Zeile < 14
      ?
    enddo
    ? space(val(DRUCKER->LR)-1), space(14),"                �����������������"
    ? space(val(DRUCKER->LR)-1), space(14),"Rechnungsbetrag:",space(1),;
      transform(SBrutto,"@E 999,999,999.99")
    ? space(val(DRUCKER->LR)-1), space(14),"     ./. Skonto:",space(1),transform(SSk,"@E "+;
      "999,999,999.99")
    ? space(val(DRUCKER->LR)-1), space(14)," Zahlungsbetrag:",space(1),FETT_AN,;
      transform(SNetto,"@E 999,999,999.99"),kurz,FETT_AUS
    do while Zeile < 23
      ?
    enddo

    /** gehe auf passenden Lieferanten/Kunden */
    Adresse:=getAdresse(aktLiefNr)
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    ? space(val(DRUCKER->LR)-1), substr(mytranslate(BANKSTAM->BankBez),1,22),HAUSBANK->KtoNr,;
      space(6),;
      substr(HAUSBANK->Blz,1,3)+" "+substr(HAUSBANK->Blz,4,3)+' '+substr(HAUSBANK->Blz,7,2)
    do while Zeile < 28
      ?
    enddo

    kom1="***"+alltrim(transform(Snetto,"@E 999,999,999.99"))+"***"
    kom2="**"+alltrim(transform(Snetto,"@E 999,999,999.99"))+"**"
    kom=kom1+space(24-len(kom1))+Kurz+space(6)+kom2

    ? space(val(DRUCKER->LR)-1), space(5),kom
    ?
    ?
    ? space(val(DRUCKER->LR)-1), space(30),space(8),"Mannheim"
    ?
    ? space(val(DRUCKER->LR)-1), space(5),mytranslate(Adresse[1]),space(2),M_datum
    ? space(val(DRUCKER->LR)-1), space(5),mytranslate(Adresse[2])
    ? space(val(DRUCKER->LR)-1), space(5),mytranslate(Adresse[3]),mytranslate(HAUSBANK->ScheckTe1)
    ? space(val(DRUCKER->LR)-1), space(5),space(34), mytranslate(HAUSBANK->ScheckTe2)
    ? space(val(DRUCKER->LR)-1), space(5),trim(mytranslate(Adresse[4])),mytranslate(Adresse[5]),;
      mytranslate(Adresse[6])
    ?
    ?
    // ?
    // ?


    // ** Hole neue ScheckNummer
    ScheckNr:=Hole("ScheckNr",WRITE,.t.)
    num1=alltrim(right("000000000000"+alltrim(ScheckNr),12))
    nachk=right("00"+alltrim(str((SNetto-int(Snetto))*100,2)),2)
    net1=alltrim(right("000000000000"+alltrim(str(int(SNetto),11,0))+nachK,11))
    kto1=alltrim(right("000000000000"+alltrim(substr(alltrim(HAUSBANK->KtoNr),1,10)),10))

    // trouble("OCR","wird doch noch benutzt.")
    aktCP:=set( _SET_CODEPAGE, "EN" )

    // OCR
    ? space(val(DRUCKER->LR)-1), OCR_AN
    ?
    ? space(val(DRUCKER->LR)-1), num1+chr(188),kto1+chr(190),;
      net1+chr(189)+space(1)+HAUSBANK->Blz+chr(188),"01"+chr(190)
    ? space(val(DRUCKER->LR)-1), OCR_AUS
    aktCP:=set( _SET_CODEPAGE, aktCP )


    do while zeile < DRUCKER->Laenge
      ?
    enddo

    /** rueckschreiben nach ScheckAus */
    SELECT ZAHLAUS
    // /** suche letzte Nr. */
    // if month(M_datum)==12
    // go bottom
    // else
    // Monat:=right("0"+alltrim(str(month(M_Datum)+1)),2)
    // dbseek(HAUSBANK->BankNr+Monat,.t.)
    // skip -1
    // endif
    // if HAUSBANK->BankNr==ZAHLAUS->BankNr .and. month(M_Datum)==val(left(ZAHLAUS->pos,2))
    // tPos:=next(right(ZAHLAUS->Pos,4))
    // MPos:=right("0"+alltrim(str(month(M_Datum))),2)+tPos
    // else
    // MPos:=right("0"+alltrim(str(month(M_Datum))),2)+"0001"
    // endif

    ADD_REC(0)
    REPLACE ZAHLAUS->BankNr WITH HAUSBANK->BankNr
    REPLACE ZAHLAUS->ZahlNr WITH ScheckNr
    // REPLACE ZAHLAUS->Pos WITH MPos
    REPLACE ZAHLAUS->KZ WITH SCHECK_KZ
    REPLACE ZAHLAUS->LiefNr WITH aktLiefNr
    REPLACE ZAHLAUS->Kurz WITH getKurzname()
    REPLACE ZAHLAUS->Zweck WITH left(zweck,len(zweck)-1)
    // REPLACE ZAHLAUS->Zweck2 WITH eigenNr
    // REPLACE ZAHLAUS->BuchDat WITH M_Datum
    // REPLACE ZAHLAUS->Tag WITH str(day(M_Datum),2)
    REPLACE ZAHLAUS->Soll_Euro WITH SNetto
    REPLACE ZAHLAUS->Skto_Euro WITH sSk
    // REPLACE ZAHLAUS->Skto_Proz WITH geht net, da mehrere Posten evtl. addiert
    REPLACE ZAHLAUS->Skto_Proz WITH ssk/(sNetto+ssk)*100

    REPLACE ZAHLAUS->Datum WITH getUser():date
    REPLACE ZAHLAUS->BuchDat WITH M_Datum

    SELECT Scheck_t

    /** rueckschreiben nach Hausbank */
    sumMonat(HAUSBANK->BankNr,month(M_Datum))
    HAUSBANK->(dbunlock())

    select SCHECK_T

  enddo
  set marg to
  Drucker("OFF")

  select Scheck_T
  SCHECK_T->(OrdSetFocus(0))

return
/** eop ScheckDrucken */

/********************************* Ueberweisungen ****************************************/

/* erfassen von Ueberweisungen
*
*/
PROCEDURE UeberErfassen(mitSepa,bankNr,execDate)
LOCAL GetList:={}
LOCAL M_Datum,fileName,M_BankNr,ant
LOCAL testFile:=SEPA_PFAD+BACKSLASH+"foo"+getUser():getTempCounter()+".txt"
LOCAL bLastHandler
LOCAL sepaBanken:=getProperty("Miki.hausbank.sepa","")

  default mitSepa:=.f.

  // falls Sepa pr�fe Schreib-Rechte vorher
  if mitSepa
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle quiet Break ein
    BEGIN SEQUENCE // krit. Bereich
      mkmydir(SEPA_PFAD)
      createEmptyFile(testFile)
      ferase(testFile)
      RECOVER // USING objErr
      Error(ACHTUNG+"Sie haben keine Schreibrechte f�r folgenden Ordner:||"+;
        "         "+SEPA_PFAD+"||"+;
        "         SEPA �berweisung nicht m�glich!" + SCHWERER_FEHLER)
      return
    end sequence
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
  endif // SepaTest

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Hausbank","Ueber_t","ZAHLAUS","Lieferan","BankStam","Kunden")
    Error("Info: Es kann nur 1 Bank-Programm gleichzeitig ge�ffnet sein.")
    close data
    RETURN
  endif

  /** Relationen setzen */
  select UEBER_T
  set relation to UEBER_T->LiefNr into Lieferan, to UEBER_T->BankAusw into Bankstam,;
    to UEBER_T->LiefNr into Kunden

  if mitSepa
    m_BankNr:=substr(alltrim(sepaBanken),1,2)
  else
    m_BankNr:=space(len(HAUSBANK->BankNr))
  endif

  do while ! ABBRUCH
    cls
    if mitSepa
      Titel("SEPA XML �berweisungen  erfassen/drucken")
    else
      Titel("�berweisungen  erfassen/drucken")
    endif

    if BankNr<>NIL
      m_BankNr:=bankNr
    endif

    Message("Hausbank eingeben.             @F12@=Hilfe")
    @ 2,2 say "Hausbank:" get M_BankNr picture "@9" valid { |oGet| check(oGet,"Hausbank",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    @ 2,20 say left(BANKSTAM->BankBez,40)
    @ 3,20 say HAUSBANK->AufGeb
    @ 2,64 say "BLZ: "+HAUSBANK->Blz
    @ 3,64 say "Kto: "+HAUSBANK->KtoNr

    // Warnung bei Commerzbank, falls kein SEPA genommen wird
    if M_BankNr=="02" .and. ! mitSepa
      Error("Hinweis: �berweisungen von der Commerzbank|         sollten per SEPA Datei "+;
        "ausgef�hrt werden.", ERR_NO_WAIT)
      if Message("Trotzdem mit �berweisungstr�gern fortfahren? (@J@/@N@)","JN"," ")<>"J"
        return
      endif
    endif

    if mitSepa .and. ! M_BankNr $ sepaBanken
      Error("SEPA �berweisungen nur f�r folgende Hausbanken: " + sepaBanken, .t.)
      loop
    endif

    UeberBauch(mitSepa)

    go top
    if reccount()==0 .or. (reccount()==1 .and. UEBER_T->Betr_euro<=0)
      loop
    endif

    setcolor(COLWIN)
    Fenster(10,26,14,46)
    if execDate==NIL
      M_Datum:=getUser():date
    else
      M_Datum:=execDate
    endif
    @ 12,28 say "Datum:" get M_Datum
    read
    setcolor(COLNOR)

    if ABBRUCH
      loop
    endif

    // Warnung bei Commerzbank, falls kein SEPA genommen wird
    if M_BankNr=="02" .and. ! mitSepa
      Error("Hinweis: �berweisungen von der Commerzbank|         sollten per SEPA Datei "+;
        "ausgef�hrt werden.", ERR_NO_WAIT)
      if Message("@�@berweisungstr�ger drucken oder @S@epa Datei erstellen? (@�@/@S@)","�S"," ")=="S"
        mitSepa:=.t.
      endif
      Trouble("Ueberweisung",;
        {"Commerzbank mit �berweisungsdruck.  Abfrage ergibt: "+if(mitSepa,"doch Sepa","�")})
      if ABBRUCH
        loop
      endif
    endif


    if mitSepa

      ant:=" "
      do while ! ant $"JN" .or. ABBRUCH
        if (ant:=Message("SEPA XML Datei erzeugen? (@J@/@N@)","JN"," "))<>"J"
          loop
        endif
      enddo
      if ant<>"J"
        loop
      endif

      go top
      if (fileName:=exportSepa(M_Datum))==NIL
        select Ueber_t
        UEBER_T->(OrdSetFocus(0))
        loop
      endif

      // pr�fe check sum und zeige Posten an
      SepaFileCheck(fileName,.t.)

      select Ueber_t
      UEBER_T->(OrdSetFocus(0))

    else // normale �berweisung drucken

      // druck
      if ! UeberFormDruck(M_Datum)
        loop // try again
      endif

    endif
    select UEBER_T
    zap
  enddo

  set key K_F3 to
  cls
  close data
return
/** eop UeberErfassen */




/** Ueberweisungen-Bauch */
FUNCTION UeberBauch(mitSepa)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL useIBAN:=.t. // seit 20.1.14 auch �berweisungstr�ger mit IBAN und BIC

  select UEBER_T

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  // aKopf[EDIT_ENDE_Y]:=21
  aKopf[EDIT_ENDE_Y]:=-2
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=3 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_INDEX_FELD]:={ || Ueber_T->Betr_Euro==0.00 }
  aKopf[EDIT_AFTER_EDIT_FKT]:={ || dispUeberSumme() }
  aKopf[EDIT_BEFORE_EDIT_FKT]:=aKopf[EDIT_AFTER_EDIT_FKT]
  aKopf[EDIT_CLS_EXTRA_ROWS]:=-1 // clear screen to last row of screen
  aKopf[EDIT_ZEIGE_ANZAHL]:={ || .t. } // z�hle alle Posten

  aKopf[EDIT_GESPERRT]:="ZK"


  /* Feld-Definitionen */
  // Lieferanten-Nr
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="LiefNr"
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_MESSAGE]:="Lieferanten-Nummer eingeben.     @F2@=Lieferanten   @F3@=Kunden        @ESC@=Ende"
  aSpalte[EDIT_TITEL]:="Li.Nr"
  // aSpalte[EDIT_UEBERTRAG]:=.t.
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oGet| BankliefNrNach(oGet) }
  aSpalte[EDIT_BEFORE]:={ || SetKey( K_F3 , {|| Hilfe("Bank,Kunden",getNew(),"") } ),.t. }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Kurzname
  aSpalte[EDIT_NAME]:="if(empty(_FIELD->LiefNr),space(20),getKurzName())"
  aSpalte[EDIT_TITEL]:="Name"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="BankAusw"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_MASKE]:="@!"
  aSpalte[EDIT_AUSGABE]:=.t.
  // aSpalte[EDIT_UEBERTRAG]:=.t.
  aSpalte[EDIT_MESSAGE]:="Bankleitzahl eingeben.              @F12@=Hilfe"
  aSpalte[EDIT_BEFORE]:={ || popupBank(useIBAN) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  if useIBAN
    aSpalte[EDIT_NAME]:="left(BankBez,30)"
  else
    aSpalte[EDIT_NAME]:="left(BankBez,22)"
  endif
  aSpalte[EDIT_POS_X]:=11
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  if useIBAN
    aSpalte[EDIT_NAME]:="if(empty(UEBER_T->BankAusw),space(5),'IBAN:')"
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    aSpalte[EDIT_NAME]:="IBAN"
    aSpalte[EDIT_POS_X]:=6
    aSpalte[EDIT_POS_Y]:=2
    aSpalte[EDIT_MASKE]:="@!"
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  endif

  // Verwendungszweck
  aSpalte[EDIT_NAME]:="Zweck"
  aSpalte[EDIT_TITEL]:="Verw.zweck  Eigen.Nr.  Betrag"
  aSpalte[EDIT_MESSAGE]:="Verwendungszweck eingeben."
  aSpalte[EDIT_AFTER]:={ |oGet| zweckNach(oGet) .and. checkInputSepaCharacters(oGet) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // eigene Rechn.nr.
  aSpalte[EDIT_NAME]:="eigenNr"
  aSpalte[EDIT_POS_Y]:=if(useIBAN,2,1)
  aSpalte[EDIT_POS_X]:=13
  aSpalte[EDIT_AFTER]:={ |oGet| EigenNach(oGet , mitSepa) }
  aSpalte[EDIT_MESSAGE]:="Eigene Rechnungsnummer eingeben"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Euro
  aSpalte[EDIT_NAME]:="Betr_Euro"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_POS_X]:=20
  aSpalte[EDIT_AFTER]:={ || UEBER_T->Betr_euro>0 .or. lastkey()==K_UP }
  aSpalte[EDIT_MESSAGE]:="@Euro@-Betrag eingeben."
  aSpalte[EDIT_AUSGABE]:=.t.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Skonto
  aSpalte[EDIT_NAME]:="Skonto"
  aSpalte[EDIT_TITEL]:="Skto"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_AFTER]:={ |oget| checkBankSkto( oGet) }
  aSpalte[EDIT_MESSAGE]:="Skonto eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Sk-Betrag
  aSpalte[EDIT_NAME]:="str(Betr_Euro*Skonto/100,7,2)"
  aSpalte[EDIT_TITEL]:="Sk-Bet."
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Netto
  aSpalte[EDIT_NAME]:="str(Betr_Euro*(100-Skonto)/100,9,2)"
  aSpalte[EDIT_TITEL]:="    Netto"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/

RETURN( Edit(aFelder,aKopf) )
/* EOF UeberBauch */

// /** Pr�ft die IBAN nach man. Eingabe bei den �berweisungen */
  // STATIC FUNCTION myCheckIBAN(oget)
  // LOCAL errCode

  // if lastkey()==K_UP
  // errCode:=iban_verify(oGet:buffer)
  // if errCode<>0
  // oget:varput("")
  // return .t.
  // endif
  // else
  // errCode:=checkIban(oGet:buffer)
  // if errCode<>0
  // return .f.
  // endif
  // endif

  // return .t.
// /** eof */


/** wird nach Eingabe der Eigen-Nr. ausgef�hrt */
static Function eigenNach(oget,sepa)
  default sepa:=.f.
  if sepa .and. ! checkInputSepaCharacters(oGet)
    return .f.
  endif

  if empty( oGet:buffer ) .and. lastkey() <> K_UP
    Umgebung( WRITE )
    Error("�berweisung ohne Eigen.Nr.  Bitte best�tigen (J/N)",ERR_NO_WAIT)
    if Message("�berweisung ohne Eigen.Nr.  Bitte best�tigen (@J@/@N@)","JN","N") <> "J"
      Umgebung( LOAD )
      return .f.
    endif
    Umgebung( LOAD )
  endif
return .t.
/** eof */

/** wird nach Eingabe des Zwecks ausgef�hrt */
static Function zweckNach(oget)
  if empty( oGet:buffer ) .and. lastkey() <> K_UP
    Error("Zweck muss eingegeben werden.")
    return .f.
  endif
return .t.
/** eof */

/** oeffnet Hilfe falls mehr als ein Bank vorhanden */
static Function popupBank(useIBAN)
LOCAL count:=5 , ausw , error:=.f.
LOCAL selectedBIC, firstValid:=.t.

  if lastkey() == K_UP
    return .f.
  endif

  Umgebung( WRITE_ALL )

  Fenster(9,6,16,75,"Konto-Auswahl:",.t.,.t.)

  // Lieferanten
  if ! LIEFERAN->(eof())
    BANKSTAM->(dbseek(LIEFERAN->EBlz))
    firstValid:=! empty(LIEFERAN->eIBAN) .or. ( ! useIBAN .and. ! empty( LIEFERAN->eKto))

    if firstValid
      @;
        11,;
        8;
        Prompt;
        "1. "+LIEFERAN->EBlz+space(1)+left(BANKSTAM->BankBez,30)+space(1)+left(LIEFERAN->EKto,20)
      @ 12,8 say "   BIC:"+LIEFERAN->eBIC + " IBAN:" + LIEFERAN->eiBAN
    endif

    if ! empty(LIEFERAN->pIBAN) .or. ( ! useIBAN .and. ! empty( LIEFERAN->pKto))
      count += 2
      BANKSTAM->(dbseek(LIEFERAN->pBlz))
      @ 14,8 Prompt "2. "+LIEFERAN->pBlz+space(1)+left(BANKSTAM->BankBez,30)+space(1)+;
        left(LIEFERAN->pKto,20)
      @ 15,8 say "   BIC:"+LIEFERAN->pBIC + " IBAN:" + LIEFERAN->piBAN
    else
      if ! firstValid
        Error("Lieferant: "+LIEFERAN->LiefNr+" "+trim(LIEFERAN->KurzName)+" ohne Bankverbindung.||"+;
          "Auswahl nicht m�glich.",.t.)
        error:=.t.
      endif
    endif
  else // Kunden
    if ! empty(KUNDEN->IBAN)
      BANKSTAM->(dbseek(KUNDEN->Blz))
      @;
        11,;
        8;
        Prompt "1. "+KUNDEN->Blz+space(1)+left(BANKSTAM->BankBez,30)+space(1)+left(KUNDEN->Kto,20)
      @ 12,8 say "   BIC:"+KUNDEN->BIC + " IBAN:" + KUNDEN->iBAN
    else
      Error("Kunde: "+KUNDEN->KundNr+" "+trim(KUNDEN->KurzName)+" ohne Bankverbindung.||"+;
        "Auswahl nicht m�glich.",.t.)
      error:=.t.
    endif
  endif

  if ! error
    Message("Ihre Konto-Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw
  endif

  if error .or. ;
    ABBRUCH .or. (! LIEFERAN->(eof()) .and. empty(LIEFERAN->eBIC) .and. empty(LIEFERAN->pBIC)) .or.;
    (LIEFERAN->(eof()) .and. empty(KUNDEN->BIC))
    if ! ABBRUCH
      Error("Bitte g�ltige BIC bei Kunden bzw. Lieferanten hinterlegen.||Dazu evtl. Bank in "+;
        "Bankenstamm erfassen.",.t.)
    endif
    keyboard chr(K_UP)
    Umgebung( LOAD )
    return .f.
  endif

  if ! LIEFERAN->(eof())
    if Ausw == 1 .and. firstValid
      selectedBIC:=LIEFERAN->EBic
      if empty(LIEFERAN->eBLZ)
        Error("Bitte g�ltige BLZ bei Lieferanten hinterlegen.||Dazu evtl. Bank in Bankenstamm "+;
          "erfassen.",.t.)
        keyboard chr(K_UP)
        Umgebung( LOAD )
        return .f.
      endif
    else
      selectedBIC:=LIEFERAN->pBic
      if empty(LIEFERAN->pBLZ)
        Error("Bitte g�ltige BLZ bei Lieferanten hinterlegen.||Dazu evtl. Bank in Bankenstamm "+;
          "erfassen.",.t.)
        keyboard chr(K_UP)
        Umgebung( LOAD )
        return .f.
      endif
    endif
  else
    selectedBIC:=KUNDEN->Bic
    if empty(KUNDEN->BLZ)
      Error("Bitte g�ltige BLZ bei Kunden hinterlegen.||Dazu evtl. Bank in Bankenstamm erfassen.",;
        .t.)
      keyboard chr(K_UP)
      Umgebung( LOAD )
      return .f.
    endif
  endif

  // suche BIC
  BANKSTAM->(OrdSetFocus(3)) // BIC
  BANKSTAM->(dbseek(selectedBIC))
  if BANKSTAM->(eof())
    Error("Bank: "+selectedBIC+" nicht gefunden.",.t.)
    Umgebung( LOAD )
    return .f.
  endif

  replace UEBER_T->BankBez WITH BANKSTAM->BankBez
  if ! LIEFERAN->(eof())
    if Ausw == 1 .and. firstValid
      replace UEBER_T->Kto WITH LIEFERAN->eKto
      replace UEBER_T->IBAN WITH LIEFERAN->eIBAN
      replace UEBER_T->BIC WITH LIEFERAN->eBIC
      replace UEBER_T->BankAusw WITH LIEFERAN->eBLZ
    else
      replace UEBER_T->Kto WITH LIEFERAN->pKto
      replace UEBER_T->IBAN WITH LIEFERAN->pIBAN
      replace UEBER_T->BIC WITH LIEFERAN->pBIC
      replace UEBER_T->BankAusw WITH LIEFERAN->pBLZ
    endif
  else
    if ! KUNDEN->(eof())
      replace UEBER_T->Kto WITH KUNDEN->Kto
      replace UEBER_T->IBAN WITH KUNDEN->IBAN
      replace UEBER_T->BIC WITH KUNDEN->BIC
      replace UEBER_T->BankAusw WITH KUNDEN->BLZ
    endif
  endif

  // added 13.12.2013 now check for again here already
  checkIBAN(UEBER_T->IBAN)

  keyboard chr(K_RETURN)
  Umgebung( LOAD )

return .t.
/** eof */


/** Ueberweisungs-Druck, neuer Formular-Drucker 18.1.2017
  * was UeberDruck
 */
STATIC FUNCTION UeberFormDruck(M_Datum)
LOCAL Zeile:=0,Snetto:=0,Sbrutto:=0,SSk:=0
LOCAL aktLiefNr
LOCAL betr,sk_betr,netto, verwZweck,eigenNr
LOCAL strBetrag,num1,uebernr,nachk,net1,kto1
LOCAL tBank,tBlz,tKto,tIBAN , tBIC, Adresse, ausdruck, skontoText, lm, rm

  Drucker("ON","�berweisung")

  index on UEBER_T->LiefNr tag TEMP_INDEX TEMPORARY ADDITIVE
  go top
  do while ! eof()

    /** aufsummieren der Einzel-Ueberweisungen je Lieferant und Waehrung */
    // Info: seit 8.3.2014 nicht mehr automat. Zusammenfassen!!!
    aktLiefNr:=UEBER_T->LiefNr
    verwZweck:=""
    eigenNr:=""
    tBlz:=""
    tKto:=""
    tIBAN:=""

    /** gehe auf passenden Lieferanten/Kunden */
    Adresse:=getAdresse(aktLiefNr)

    Zeile:=0 ; Snetto:=0 ; Sbrutto:=0 ; SSk:=0
    // do while ! eof() .and. aktLiefNr==UEBER_T->LiefNr
    betr:=UEBER_T->Betr_Euro

    sk_betr:=round(betr*UEBER_T->Skonto/100,2)
    netto:=betr-sk_betr

    if empty(verwZweck)
      verwZweck:=UEBER_T->Zweck
    else
      verwZweck:=alltrim(verwZweck)+", "+UEBER_T->Zweck
    endif
    if empty(eigenNr)
      eigenNr:=UEBER_T->eigenNr
    else
      eigenNr:=alltrim(eigenNr)+", "+UEBER_T->eigenNr
    endif
    Ssk += sk_betr
    SNetto += netto
    SBrutto+= betr
    /** merke Blz */
    if empty(tBLz)
      tBlz:=UEBER_T->BankAusw
    else
      if tBlz<>UEBER_T->BankAusw
        /** evtl. Fehlerquelle, jojo */
        Error(ACHTUNG+"�berweisung an verschiedene Banken m�ssen getrennt erfasst werden.",.t.)
        select UEBER_T
        UEBER_T->(OrdSetFocus(0))
        return .f.
      endif
    endif
    /** merke Kto */
    if empty(tKto)
      tKto:=UEBER_T->Kto
    else
      if tKto<>UEBER_T->Kto
        /** evtl. Fehlerquelle, jojo */
        Error(ACHTUNG+"�berweisung an verschiedene Konten m�ssen getrennt erfasst werden.",.t.)
        select UEBER_T
        UEBER_T->(OrdSetFocus(0))
        return .f.
      endif
    endif
    /** merke BIC */
    if empty(tBIC)
      tBIC:=UEBER_T->BIC
    else
      if tBIC<>UEBER_T->BIC
        /** evtl. Fehlerquelle, jojo */
        Error(ACHTUNG+"�berweisung an verschiedene Banken m�ssen getrennt erfasst werden.",.t.)
        select UEBER_T
        UEBER_T->(OrdSetFocus(0))
        return .f.
      endif
    endif
    /** merke IBAN */
    if empty(tIBAN)
      tIBAN:=UEBER_T->IBAN
    else
      if tIBAN<>UEBER_T->IBAN
        /** evtl. Fehlerquelle, jojo */
        Error(ACHTUNG+"�berweisung mit versch. IBAN-Nummern m�ssen getrennt erfasst werden.",.t.)
        select UEBER_T
        UEBER_T->(OrdSetFocus(0))
        return .f.
      endif
    endif
    skip
    // enddo

    /** gehe auf passenden Lieferanten/Kunden */
    // Adresse:=getAdresse(aktLiefNr)

    // ** Hole neue uberweis:Nummer
    UeberNr:=Hole("UeberNr",WRITE,.t.)
    num1=alltrim(right("000000000000"+alltrim(UeberNr),13))
    nachk=right("00"+alltrim(str((SNetto-int(Snetto))*100,2)),2)
    net1=alltrim(right("000000000000"+alltrim(str(int(SNetto),11,0))+nachK,11))
    kto1=alltrim(right("000000000000"+alltrim(substr(alltrim(HAUSBANK->KtoNr),1,10)),10))

    strBetrag=right( replicate("*",13)+alltrim(transform(Snetto,"@E 999,999,999.99"))+"**" ,15)

    BANKSTAM->(dbseek(tBLz))
    tBank:=BANKSTAM->BankBez
    BANKSTAM->(dbseek(HAUSBANK->Blz))

    // Drucke Leerzeilen oben
    for ausdruck:=1 to 19
      ?
    next

    lm:=2
    rm:=14

    // Drucke �berweisung 2x
    for ausdruck:=1 to 2
      ? space(lm), left(BANKSTAM->BankBez,27),space(0),HAUSBANK->BIC
      if Ausdruck==1
        ?? space(rm + 13),SCHMAL_AN,HAUSBANK->BIC,SCHMAL_AUS
      endif
      ?
      ?
      ? space(lm), noTranslate(Adresse[1]),space(5),"("+aktLiefnr+")"
      if Ausdruck==1
        ?? space(rm + 5),KLEIN_AN,noTranslate(Adresse[1]),KLEIN_AUS
      endif
      ?
      ? space(lm), tIBAN
      ?
      if Ausdruck==1
        ?? space(rm + 57),KLEIN_AN,tIBAN,KLEIN_AUS
      endif
      ? space(lm), tBIC
      if Ausdruck==1
        ?? space(rm + 51),SCHMAL_AN,tBIC,SCHMAL_AUS
      endif
      ?
      ? space(lm), space(35),strBetrag
      if Ausdruck==1
        ?? space(rm + 11),SCHMAL_AN,strBetrag,SCHMAL_AUS
      endif
      ?
      ? space(lm), noTranslate(verwZweck)
      ?
      if Ausdruck==1
        ?? space(rm + 57),KLEIN_AN,noTranslate(verwZweck),KLEIN_AUS
      endif
      skontoText:=alltrim(str(SBrutto,12,2))+" Euro abzgl. "+alltrim(str(sSk,9,2))+" Euro"
      if sSk > 0
        ? space(lm), skontoText
      else
        ?
      endif
      if Ausdruck==1 .and. sSk > 0
        ?? space(rm + 24),KLEIN_AN,skontoText,KLEIN_AUS
      endif
      ?
      ? space(lm), noTranslate(HAUSBANK->AufGeb)
      ?
      if Ausdruck==1
        ?? space(rm + 57),KLEIN_AN, noTranslate(HAUSBANK->AufGeb),KLEIN_AUS
      endif
      ? space(lm), space(3),substr(HAUSBANK->IBAN,3)
      if ausdruck == 1
        ?
        ?
        ? space(lm), M_Datum
        ?
        ?
        ?
        ?
      else
        ?
        ? space(lm), M_Datum
      endif
    next

    do while zeile < DRUCKER->Laenge
      ?
    enddo

    /** rueckschreiben nach Zahlaus */
    // Anmerkung: Skonto in % kann hier nicht gespeichert werden, da Zahlungen summiert werden
    schreibeZahlaus(M_Datum,UeberNr,UEBERWEISUNGS_KZ,aktLiefNr,verwZweck,eigenNr, sNetto,sSk,ssk/(;
      sNetto+ssk)*100,tKto,tBLZ,tIBAN,NIL)

    select UEBER_T

  enddo
  Drucker("OFF")


return .t.
  /** eop UeberweisungenDrucken */



  /** rueckschreiben nach Zahlaus und Kunden/Lieferanten */
STATIC;
  PROCEDURE;
  schreibeZahlaus(M_Datum,UeberNr,KZ,aktLiefNr,verwZweck,eigenNr,sNetto,sSk,pSk, tKto,tBLZ,tIBAN,;
  sepaNr)

  SELECT ZAHLAUS
  // /** suche letzte Nr. */
  // if month(M_datum)==12
  // go bottom
  // else
  // Monat:=right("0"+alltrim(str(month(M_Datum)+1)),2)
  // dbseek(HAUSBANK->BankNr+Monat,.t.)
  // skip -1
  // endif
  // if HAUSBANK->BankNr==ZAHLAUS->BankNr .and. month(M_Datum)==val(left(ZAHLAUS->pos,2))
  // tPos:=next(right(ZAHLAUS->Pos,4))
  // MPos:=right("0"+alltrim(str(month(M_Datum))),2)+tPos
  // else
  // MPos:=right("0"+alltrim(str(month(M_Datum))),2)+"0001"
  // endif

  ADD_REC(0)
  REPLACE ZAHLAUS->BankNr WITH HAUSBANK->BankNr
  REPLACE ZAHLAUS->ZahlNr WITH UeberNr
  // REPLACE ZAHLAUS->Pos WITH MPos
  REPLACE ZAHLAUS->KZ WITH KZ
  REPLACE ZAHLAUS->LiefNr WITH aktLiefNr
  REPLACE ZAHLAUS->Kurz WITH getKurzname()
  REPLACE ZAHLAUS->Zweck WITH verwZweck
  REPLACE ZAHLAUS->Zweck2 WITH eigenNr
  // REPLACE ZAHLAUS->BuchDat WITH M_Datum
  // REPLACE ZAHLAUS->Tag WITH str(day(M_Datum),2)
  REPLACE ZAHLAUS->Soll_Euro WITH SNetto
  REPLACE ZAHLAUS->Skto_Euro WITH sSk
  if psk<>NIL
    REPLACE ZAHLAUS->Skto_Proz WITH pSk
  endif

  // neu seit 13.7.2012
  REPLACE ZAHLAUS->Kto WITH tKto
  REPLACE ZAHLAUS->BLZ WITH tBLZ
  REPLACE ZAHLAUS->IBAN WITH tIBAN
  REPLACE ZAHLAUS->Datum WITH getUser():date
  REPLACE ZAHLAUS->BuchDat WITH M_Datum

  if sepaNr<>NIL
    REPLACE ZAHLAUS->SepaNr WITH sepaNr
  endif
  SELECT Ueber_t

  /** rueckschreiben nach Hausbank */
  /** rueckschreiben nach Hausbank */
  sumMonat(HAUSBANK->BankNr,month(M_Datum))
  HAUSBANK->(dbunlock())

return
  /** eop */





  /** addiert den ueberegebenen Monat der gew. Bank auf
  * ist der gewuenschte Monat <= HAUSBANK->aktMonat so wird der
  * Saldo des Vormonates mit einberechnet.
  * Falls der Monat > HAUSBANK->aktMonat wird nur der Monat aufsummiert
  * OHNE Beruecksichtigung der Vormonate
  */
static procedure sumMonat(M_BankNr,Monat)
LOCAL aktSaldo,before
LOCAL erstDat,merkeSaldo
LOCAL aktSel:=Alias()
MEMVAR emptyField
PRIVATE emptyField:=0

  Message(myCMonth(ctod("01."+str(Monat,2)+".80"))+" wird aktualisiert.    Bitte warten....")

  /** summiere Saldo des akt. Monats */
  merkeSaldo:=0
  select ZahlAus
  set filter to ZAHLAUS->BankNr==M_BankNr .and. ;
    year(ZAHLAUS->BuchDat)==year(getUser():date) .and. month(ZAHLAUS->BuchDat)==Monat
  go top
  do while ! ZAHLAUS->(eof())
    merkeSaldo:=merkeSaldo + ZAHLAUS->Haben_Euro - ZAHLAUS->Soll_Euro
    skip
  enddo

  if Monat > 1
    before:=&("HAUSBANK->Saldo"+right("00"+alltrim(str(Monat-1,2)),2))
  else
    before:=0
  endif
  aktSaldo:="HAUSBANK->Saldo"+right("00"+alltrim(str(Monat,2)),2)

  /** aktualisieren ? */
  if &(aktSaldo)<> (merkeSaldo + before)
    select Hausbank
    if rec_lock(5)
      replace &(aktSaldo) with (merkeSaldo + before)
      dbcommit()
    else
      Error("Saldo "+myCMonth(erstDat)+"konnte nicht aktualisert werden.",.t.)
    endif
  endif

  select Zahlaus
  set filter to

  select (aktSel)
return
  /** eop */






  /******************************* Liste ******************************************/

Procedure KtoListe()
LOCAL M_BankNr,doppelline:=replicate("=",98),line:=replicate("-",98)
LOCAL Seite:=0 , Zeile:=0
LOCAL GetList:={},druck:=.f.
LOCAL order:="C",summe
LOCAL AuszugSumme,MerkAuszug,tempDruck:=.f.,nurNeue:="J",von:=getUser():date,bis:=getUser():date

  cls
  Titel("Kontobewegungen drucken")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Hausbank","ZAHLAUS","BankStam")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  m_BankNr:=space(len(HAUSBANK->BankNr))
  do while ! ABBRUCH
    cls
    Titel("Kontobewegungen drucken")
    druck:=.f.

    Message("Hausbank eingeben.             @F12@=Hilfe")
    @ 2,2 say "Hausbank:" get M_BankNr picture "@9" valid { |oGet| check(oGet,"Hausbank",.f.,.f.) }
    read
    if ABBRUCH
      loop
    endif
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    @ 2,20 say left(BANKSTAM->BankBez,40)
    @ 3,20 say HAUSBANK->AufGeb
    @ 2,64 say "BLZ: "+HAUSBANK->Blz
    @ 3,64 say "Kto: "+HAUSBANK->KtoNr

    @ 7,28 to 15,52
    @ 8,30 say "Datum von:  " get von
    @ 10,30 say "Datum bis:  " get bis
    @ 12,30 say "Nur Neue :  " get nurNeue picture "!" valid nurNeue$"JN" ;
      when message("Nur neue (nicht gedruckte) ausdrucken? (@J@/@N@)")
    @ 14,30 say "Reihenfolge:" get order picture "!" valid order$"CK" ;
      when message("Ausdruck in @c@hronologischerReihenfolge oder nach @K@to.Ausz�gen  (@C@/@K@)?")
    read
    if ABBRUCH
      cls
      loop
    endif
    if ! druck_BS() // Abbruch
      close data
      RETURN
    endif
    set marg to 10

    Message("Liste wird erstellt.   Bitte warten....")

    select Zahlaus
    if nurNeue=="J" // nur die neuste Bewegungen

      /** gehe auf ersten ungedruckten */
      set filter to empty(ZAHLAUS->gedruckt) .and. ZAHLAUS->BankNr==M_BankNr .and.;
        ZAHLAUS->BuchDat>=von .and. ZAHLAUS->BuchDat <=bis
      go top
    else
      set filter to ZAHLAUS->BankNr==M_BankNr .and.;
        ZAHLAUS->BuchDat>=von .and. ZAHLAUS->BuchDat <=bis
      go top
    endif
    if ZAHLAUS->(eof())
      set filter to
      Error("Keine Datens�tze in Auswahl.",.t.)
      loop
    endif

    Seite:=0 ; Zeile:=0
    summe:=0
    BANKSTAM->(dbseek(HAUSBANK->Blz))

    /** Reihenfolge ? */
    if order=="K"
      // nach Kto.Auszuegen
      index on ZAHLAUS->BankNr+Ktofill(ZAHLAUS->KtoAuszug) tag TEMP_INDEX TEMPORARY ADDITIVE
    else
      // chronolog. Reihenfolge
    endif

    dbseek(M_BankNr)
    MerkAuszug:=ZAHLAUS->KtoAuszug
    AuszugSumme:=0
    do while ! eof() .and. ZAHLAUS->BankNr==M_BankNr
      seite++
      zeile:=0
      ? "Kontobewegungen:",left(BANKSTAM->BankBez,40),space(2),"vom:",getUser():date
      ? von,"-",bis,HAUSBANK->Aufgeb,"("+HAUSBANK->BankNr+")",space(8),;
        "Seite",str(Seite,3)
      ? doppelline
      ? "Li.Nr. Name               KZ        Eingang     Ausgang       Skonto   Az./ Bu.Dat.      "+;
        "Rechn.Nr."
      ? doppelline
      if Summe<>0
        ? "�bertrag:",space(32),transstr(Summe,12,2)
      endif
      do while ! eof() .and. ZAHLAUS->BankNr==M_BankNr .and. zeile < DRUCKER->laenge - 8
        if nurNeue<>"J" .or. empty(ZAHLAUS->gedruckt)
          druck:=.t.
          tempDruck:=.t.
          ? line
          ? ZAHLAUS->LiefNr,ZAHLAUS->Kurz,ZAHLAUS->Kz,space(0),space(1)
          ?? LISTE_COLSEP,transform(ZAHLAUS->Haben_Euro,"@Z"),LISTE_COLSEP,;
            transform(ZAHLAUS->Soll_Euro,"@Z"), LISTE_COLSEP,transform(ZAHLAUS->Skto_Euro,"@Z"),;
            LISTE_COLSEP
          // Summe eigenlich umgekehrt: +ZAHLAUS->Haben_Euro - ZAHLAUS->Soll_Euro
          // aber da nur Ausg�nge gebucht werden, besser da Summe dann pos.
          Summe:=Summe - ZAHLAUS->Haben_Euro + ZAHLAUS->Soll_Euro
          AuszugSumme:=AuszugSumme + ZAHLAUS->Haben_Euro - ZAHLAUS->Soll_Euro
          ?? ZAHLAUS->KtoAuszug,space(1),left(dtoc(ZAHLAUS->BuchDat),5),space(10),ZAHLAUS->Zweck

          ? space(31),LISTE_COLSEP,space(9),LISTE_COLSEP,space(9),LISTE_COLSEP,space(8),;
            LISTE_COLSEP,space(2)

          if ! empty(ZAHLAUS->Zweck2)
            ?? space(19),ZAHLAUS->zweck2
          endif
        endif
        skip

        /** Zwischensumme je Kto-Auszug */
        if order=="K" .and. ZAHLAUS->KtoAuszug<>MerkAuszug
          if tempDruck
            ? space(31),left(line,len(line)-31-1)
            ? space(64),"ZwischenSumme:",AuszugSumme,"EURO"
            ?
            tempDruck:=.f.
          endif
          MerkAuszug:=ZAHLAUS->KtoAuszug
          // AuszugSumme:=0
        endif

      enddo
      ? doppelline
      ? "Summe:",space(35),transstr(Summe,12,2),"EURO"
      /** Seitenvorschub */
      Zeile:=FormFeed(Zeile,Seite)
    enddo
    Drucker("Off")

    if nurNeue=="J" .and. druck .and. message("Ausdruck in Ordnung (@J@/@N@) ?","JN")=="J" .and.;
      ! ABBRUCH
      Message("Bewegungen werden markiert.   Bitte warten....")

      go top
      /** filter ist noch gesetzt */
      do while ! ZAHLAUS->(eof())
        if empty(ZAHLAUS->Gedruckt)
          rec_lock(0)
          replace ZAHLAUS->gedruckt with "*"
        endif
        skip
      enddo
      dbcommitAll()
      dbunlockAll()
    endif
    set filter to

    /** Reihenfolge rueckgaengig */
    if order=="K"
      close("Zahlaus")
      open("Zahlaus")
    else
      select Zahlaus
    endif
  enddo

  cls
  close data
return
  /** EOP */


  /** setzt leere KtoAuszuege nach volle -> indexReihenfolge
  * und shifte andere nach rechts
  */
Function Ktofill(s)
  if empty(s)
    return replicate(chr(255),len(s))
  endif
  if len(alltrim(s))<len(s)
    return replicate(" ",len(s)-len(alltrim(s)))+alltrim(s)
  endif
return s




  /**
  * wird nach Eingabe der Lieferanten/KundeNr. ausgefuehrt
  * temp. Datei Scheck_T, oder Ueber_T muss selektiert sein
  */
static Function BankLiefNrNach(oGet)
LOCAL okay:=.f.,kurzname

  if empty(oGet:Buffer)
    keyboard chr(HILFE_TASTE1)
    return .f.
  endif

  /** Lieferant ? */
  LIEFERAN->(dbseek(oGet:buffer))
  if ! LIEFERAN->(eof())
    kurzName:=LIEFERAN->Kurzname
    okay:=.t.
  else
    /** Kunden ? */
    KUNDEN->(dbseek(oGet:buffer))
    if ! KUNDEN->(eof())
      kurzName:=KUNDEN->Kurzname
      okay:=.t.
    endif
  endif
  if okay
    set key K_F3 to
    if fieldpos("Kurz") > 0
      _FIELD->Kurz:=kurzName
    endif
    // FIXME: was soll das hier
    if okay .and. oGet:changed
      replace _FIELD->BankAusw with "" // hier KEIN carry (Uebertrag )
      replace _FIELD->BankBez with "" // hier KEIN carry (Uebertrag )
      replace _FIELD->BIC with "" // hier KEIN carry (Uebertrag )
      replace _FIELD->IBAN with "" // hier KEIN carry (Uebertrag )
      replace _FIELD->Kto with "" // hier KEIN carry (Uebertrag )
    endif
  endif
return okay
  /** eof */

  /**
  * gibt den entsprechenden Kurznamen zurueck
  * Lieferant <-> Kunde
  * Lieferant und Kunde mussen jeweils selktiert bzw. eof sein
  */
Function getKurzName()
  if LIEFERAN->(eof())
    return left(KUNDEN->Kurzname,20)
  endif
return left(LIEFERAN->Kurzname,20)
  /** eof */

  /**
  * gibt die entsprechenden Adresse zurueck
  * Lieferant <-> Kunde
  * Lieferant und Kunde mussen jeweils selktiert bzw. eof sein
  */
static Function getAdresse(aktLiefNr)
LOCAL result[6]
  LIEFERAN->(dbseek(aktLiefNr))
  if ! LIEFERAN->(eof())
    result[1]:=LIEFERAN->Name1
    result[2]:=LIEFERAN->Name2
    result[3]:=LIEFERAN->Strasse
    result[4]:=LIEFERAN->Land
    result[5]:=LIEFERAN->PLZ
    result[6]:=LIEFERAN->ORT
  else
    KUNDEN->(dbseek(aktLiefNr))
    if ! KUNDEN->(eof())
      result[1]:=KUNDEN->Name
      result[2]:=KUNDEN->Partner
      result[3]:=KUNDEN->Strasse
      result[4]:=KUNDEN->Land
      result[5]:=KUNDEN->PLZ
      result[6]:=KUNDEN->ORT
    else
      result[1]:=space(len(KUNDEN->Name))
      result[2]:=space(len(KUNDEN->Partner))
      result[3]:=space(len(KUNDEN->Strasse))
      result[4]:=space(len(KUNDEN->Land))
      result[5]:=space(len(KUNDEN->PLZ))
      result[6]:=space(len(KUNDEN->ORT))
    endif
  endif
return result
  /** eof */


  /** debugging: dumps all the records of bank & month */
  // static Procedure dump(M_BankNr,Monat,Name)
  // LOCAL aktSel:=Alias()
  // LOCAL aktOrd:=Indexord()
  // LOCAL I

  // set alte to (TEMP+BACKSLASH+Name+".asc")
  // set alte on
  // set cons off
  // select Zahlaus
  // set filter to ZAHLAUS->BankNr==M_BankNr .and. 
  // year(ZAHLAUS->BuchDat)==year(getUser():date) .and. month(ZAHLAUS->BuchDat)==Monat
  // go top
  // do while ! eof()
  // for i:=1 to fcount()
  // qqout(fieldget(i))
  // qout()
  // next
  // skip
  // enddo

  // select Zahlaus
  // set filter to

  // set alte off
  // set cons on
  // close alte
  // select(aktSel)
  // ->(OrdSetFocus((aktOrd)
  // return
  // /** eop */






  /** freischalten von + / - Option bei Tageseingabe */
Function setTagesPlusMinus(oGet)
  if valtype(oGet)=="U"
    set key K_PLUS to
    set key K_MINUS to
  else
    set key K_PLUS to inc("",oGet,"")
    set key K_MINUS to dec("",oGet,"")
  endif
return .t.
/** eof */

  /** erhoeht/erniedrigt den Buffer oGet um n (1. Parameter)
   * Buffer muss num. Inhalt haben !!!
   */
Function inc(n,oGet)
  ignore n
  oget:varput(str(val(oGet:Buffer)+1,2))
  oGet:updateBuffer()
return .t.
/** eof */

Function dec(n,oGet)
  ignore n
  oget:varput(str(val(oGet:Buffer)-1,2))
  oGet:updateBuffer()
return .t.
/** eof */


  /** Gibt Summen-Zeile und andere Posten Infos am Ende der �berweisungen am BS aus
  *
  */
static function dispUeberSumme()
LOCAL aktRec:=recno()
LOCAL brutto:=0,netto:=0,skto:=0

  // always clear displayed sum
  @ maxrow()-2,0 clear
  @ maxrow()-2,0 to maxrow()-2,maxcol()

  go top
  do while ! UEBER_T->(eof())
    netto += round(UEBER_T->Betr_Euro*(100-UEBER_T->Skonto)/100,2)
    skto += round(UEBER_T->Betr_Euro*UEBER_T->Skonto/100,2)
    brutto+= round(UEBER_T->Betr_Euro,2)
    skip
  enddo
  go (aktRec)

  @ maxrow()-1,44 say transstr(brutto,12,2)+" "+EURO_SIGN
  @ maxrow()-1,62 say transstr(skto,8,2)
  @ maxrow()-1,70 say transstr(netto,10,2)

RETURN .t.
/** eof */


  /** Berechnet anhand des L�nder-K�rzel, BLZ und Kto Nummer die IBAN Bank Nummer
  *    IBAN = International Bank Account Number
  *
  * see hbiban package for details
  */

FUNCTION getIBAN(land,blz,kto)
LOCAL Result:=space(34)
  if land=="DE" .and. ! empty(blz) .and. ! empty(kto)
    result:=iban_from_blz_kto(blz,kto)
    if checkIBAN(result)<>0
      Result:=space(34)
    endif
  endif
return result
/** eof */

  /** Pr�ft die IBAN Bank Nummer
  *    IBAN = International Bank Account Number
  *
  * Ergebnis ist ein Error-Code, falls 0 ist die IBAN korrekt
  *
  * see hbiban package for details
  */
FUNCTION checkIBAN(IBAN)
LOCAL errCode:=iban_verify(iban)
LOCAL text
  if errCode<>0
    if empty(IBAN)
      text:="Leere IBAN Nummer"
    else
      text:="->" + IBAN + "<-"
    endif
    Error(ACHTUNG+"Fehlerhafte IBAN Nummer!||"+;
      text+"|"+;
      iban_error(errCode)+;
      if( select("ueber_t")==0 ,"",;
      "||Bitte pr�fen: "+UEBER_T->LiefNr+" "+getKurzName()),.t.)
  endif
return errCode
/** eof */


/**
*
* Pr�ft die manuelle Eingabe der IBAN Nummer
*/
FUNCTION enterIBAN(oGet)
LOCAL blz,kto,land,bic,result:=.t.,temp,changed

  if lastkey()<>K_UP

    if ! assignKtoValues( oGet, @blz , @kto , @land , @bic )
      return .f.
    endif

    if oGet:changed
      if ! empty(oGet:buffer) .and. (temp:=checkIban(oGet:buffer))<>0
        result:=.f.
        if ! empty(blz) .and. ! empty(kto) .and. ! empty(land)
          if Message("IBAN Nummer automatisch berechnen?","JN","N")=="J"
            oget:varput(getIBAN(land,blz,kto))
            oGet:updateBuffer()
            result:=.t.
          endif
        endif
      endif

      // IBAN-Nummer r�ckschreiben nach BLZ und Kto falls leer
      if left(oGet:buffer,2) == DEUTSCH_LAND .or. empty(left(oGet:buffer,2))
        changed:=.f.
        switch upper(oGet:name)
        case "KUNDEN->IBAN" // Kunden
          if KUNDEN->BLZ <> substr(KUNDEN->IBAN,5,8)
            replace KUNDEN->BLZ with substr(KUNDEN->IBAN,5,8)
            changed:=.t.
          endif
          if KUNDEN->Kto <> substr(KUNDEN->IBAN,13)
            replace KUNDEN->Kto with substr(KUNDEN->IBAN,13)
            changed:=.t.
          endif
          BANKSTAM->(dbseek(KUNDEN->Blz))
          replace KUNDEN->BIC with BANKSTAM->Bic
          exit
        case "LIEFERAN->EIBAN" // Lieferan
          if LIEFERAN->eBLZ <> substr(LIEFERAN->eIBAN,5,8)
            replace LIEFERAN->eBLZ with substr(LIEFERAN->eIBAN,5,8)
            changed:=.t.
          endif
          if LIEFERAN->eKto <> substr(LIEFERAN->eIBAN,13)
            replace LIEFERAN->eKto with substr(LIEFERAN->eIBAN,13)
            changed:=.t.
          endif
          BANKSTAM->(dbseek(LIEFERAN->eBlz))
          replace LIEFERAN->eBIC with BANKSTAM->Bic
          exit
        case "LIEFERAN->PIBAN" // Lieferan
          if LIEFERAN->pBLZ <> substr(LIEFERAN->pIBAN,5,8)
            replace LIEFERAN->pBLZ with substr(LIEFERAN->pIBAN,5,8)
            changed:=.t.
          endif
          if LIEFERAN->pKto <> substr(LIEFERAN->pIBAN,13)
            replace LIEFERAN->pKto with substr(LIEFERAN->pIBAN,13)
            changed:=.t.
          endif
          BANKSTAM->(dbseek(LIEFERAN->pBlz))
          replace LIEFERAN->pBIC with BANKSTAM->Bic
          exit
        case "HAUSBANK->IBAN" // Hausbank
          if HAUSBANK->BLZ <> substr(HAUSBANK->IBAN,5,8)
            replace HAUSBANK->BLZ with substr(HAUSBANK->IBAN,5,8)
            changed:=.t.
          endif
          if HAUSBANK->KtoNr <> substr(HAUSBANK->IBAN,13)
            replace HAUSBANK->KtoNr with substr(HAUSBANK->IBAN,13)
            changed:=.t.
          endif
          BANKSTAM->(dbseek(HAUSBANK->Blz))
          replace HAUSBANK->BIC with BANKSTAM->Bic
          exit
        endswitch

        if changed
          // Error("Info: BLZ / Kto-Nummer wurde aktualisert.||"+;
          // "      Bitte pr�fen.",.t.)
          if ! assignKtoValues( oGet, @blz , @kto , @land , @bic )
            return .f.
          endif
        endif
      endif

      if ! empty(oGet:buffer)

        // evtl. bestimme Land anhand der BIC
        if empty(land) .and. ! empty(bic)
          Land:=substr(bic,5,2)
        endif

        // if empty(land)
        // Error(ACHTUNG+"Ung�ltiges Land der Bank.|"+;
        // "         Korrekte BLZ oder BIC muss eingegeben werden.",.t.)
        // return .f.
        // endif

        if left(oGet:buffer,2)<>land .and. ! empty(land)
          Error(ACHTUNG+"falsches L�ndes-Kennzeichen in IBAN-Nummer oder BIC.",.t.)
          return .f.
        endif

      endif

    endif
  endif

RETURN result
/** eof */

static function assignKtoValues( oGet, blz , kto , land , bic )
  switch upper(oGet:name)
  case "KUNDEN->IBAN" // Kunden
    blz:=KUNDEN->Blz
    kto:=KUNDEN->Kto
    bic:=KUNDEN->BIC
    BANKSTAM->(dbseek(KUNDEN->Blz))
    land:=BANKSTAM->Land
    exit
  case "LIEFERAN->EIBAN" // Lieferan
    blz:=LIEFERAN->eBlz
    kto:=LIEFERAN->eKto
    bic:=LIEFERAN->eBIC
    BANKSTAM->(dbseek(LIEFERAN->eBlz))
    land:=BANKSTAM->Land
    exit
  case "LIEFERAN->PIBAN" // Lieferan
    blz:=LIEFERAN->pBlz
    kto:=LIEFERAN->pKto
    bic:=LIEFERAN->pBIC
    BANKSTAM->(dbseek(LIEFERAN->pBlz))
    land:=BANKSTAM->Land
    exit
  case "HAUSBANK->IBAN" // Hausbank
    blz:=HAUSBANK->Blz
    kto:=HAUSBANK->KtoNr
    bic:=HAUSBANK->BIC
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    land:=BANKSTAM->Land
    exit
  otherwise
    Error(ACHTUNG+"unbekannte IBAN check:"+oGet:name,.t.,"root")
    return .f.
  endswitch
return .t.
/** eof */

  /**
  *
  * Pr�ft die manuelle Eingabe der BIC -> aktualisiert die BLZ
  */
FUNCTION enterBIC(oGet)
LOCAL result:=.t.

  Umgebung( WRITE_ALL )
  BANKSTAM->(OrdSetFocus(3)) // BIC

  if oGet:changed .and. ! empty(oGet:buffer)
    oGet:buffer:=no_blanks( oGet:buffer )
    oGet:varPut( oGet:buffer )

    if ! check(oget,"BankStam",.f.,.f.)
      result:=.f.
    else
      switch upper(oGet:name)
      case "KUNDEN->BIC"
        if ( result:=pruefeLandBIC( KUNDEN->IBAN, oGet:Buffer ) )
          replace KUNDEN->BLZ with BANKSTAM->BLZ
        endif
        exit
      case "LIEFERAN->EBIC"
        if ( result:=pruefeLandBIC( LIEFERAN->eIBAN, oGet:Buffer ) )
          replace LIEFERAN->eBLZ with BANKSTAM->BLZ
        endif
        exit
      case "LIEFERAN->PBIC"
        if ( result:=pruefeLandBIC( LIEFERAN->pIBAN, oGet:Buffer ) )
          replace LIEFERAN->pBLZ with BANKSTAM->BLZ
        endif
        exit
      case "HAUSBANK->BIC"
        if ( result:=pruefeLandBIC( HAUSBANK->IBAN, oGet:Buffer ) )
          replace HAUSBANK->BLZ with BANKSTAM->BLZ
        endif
        exit
      otherwise
        Error(ACHTUNG+"unbek. IBAN check:"+oGet:name,.t.,"root")
      endswitch
    endif
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste

  endif
  Umgebung( LOAD )

RETURN result
/** eof */

/** pr�ft ob L�nder-KZ in IBAN und BIC �bereinstimmen */
static function pruefeLandBIC( iban, bic )
LOCAL Land:=substr(bic,5,2)
  if ! empty(iban) .and. left(iban,2)<>land .and. ! empty(land)
    Error(ACHTUNG+"falsches L�ndes-Kennzeichen in IBAN-Nummer oder BIC.",.t.)
    return .f.
  endif
return .t.
/** eof */

/** erzeugt test SEPA xml file */
static FUNCTION exportSepa(M_Datum)
LOCAL sepaExport,CT
LOCAL objErr,aktOrd
LOCAL sk_betr,hbName
LOCAL fileName
LOCAL sepaNr:=hole("SepaNr",WRITE,.t.), UeberNr

  Message("Daten werden gepr�ft.  Bitte warten...")

  // pr�fe ob alle IBAN Nummern korrekt
  select UEBER_T
  go top
  do while ! UEBER_T->(eof())
    if checkIBAN(UEBER_T->IBAN)<>0
      // Error(ACHTUNG+"unbekannte IBAN Nummer:||       "+trim(UEBER_T->IBAN)+" -> "+trim(UEBER_T->BankBez))
      return NIL
    endif
    skip
  enddo

  BANKSTAM->(dbseek(HAUSBANK->BLZ))
  hbName:=trim(no_blanks(left(BANKSTAM->BankBez,11)))
  fileName:=SEPA_PFAD+BACKSLASH+"MIKI-"+hbName+"-"+sepaNr+".xml"

  // pr�fe ob Datei existiert
  if file(fileName) .and. Message(fileName+" �berschreiben? (@J@/@N@)","JN","N")<>"J"
    return NIL
  endif

  BEGIN SEQUENCE // krit. Bereich

    sepaExport:=SEPA():new(alltrim(sepaNr), getProperty("Customer.name.long","Miki-Plastik GmbH "+;
      "Mannheim"), HAUSBANK->IBAN, BANKSTAM->BIC, M_Datum)

    select UEBER_T
    go top
    do while ! UEBER_T->(eof())
      UeberNr:=Hole("UeberNr",WRITE,.t.)
      CT:=CTrecord()
      CT:setID(UEBER_T->eigenNr)
      CT:setIBAN(UEBER_T->IBAN)
      if ! LIEFERAN->(eof())
        CT:setCreditorName(LIEFERAN->Name1)
        CT:setCreditorID(LIEFERAN->LiefNr)
        CT:setSequencer(ueberNr)
      else
        CT:setCreditorName(KUNDEN->Name)
        CT:setCreditorID(KUNDEN->KundNr)
        CT:setSequencer(ueberNr)
      endif
      BANKSTAM->(dbseek(UEBER_T->BankAusw))
      CT:setBIC(BANKSTAM->BIC)

      // Berechne Betrag & Skonto
      sk_betr:=round(UEBER_T->Betr_Euro*UEBER_T->Skonto/100,2)
      CT:setPurpose(trim(UEBER_T->Zweck))
      if sk_betr<>0
        CT:setPurpose(CT:getPurpose+", "+;
          alltrim(str(UEBER_T->Betr_Euro,12,2))+" abzgl. "+alltrim(str(sk_betr,12,2))+" Euro")
      endif
      CT:setValue(round(UEBER_T->Betr_Euro-sk_betr,2)) // NETTO Wert!!!

      sepaExport:addCreditTransfer(CT)

      /** rueckschreiben nach Zahlaus */
      schreibeZahlaus(getUser():date,ueberNr,SEPA_KZ,UEBER_T->LiefNr,trim(UEBER_T->Zweck), UEBER_T;
        ->eigenNr,CT:getValue,Sk_betr,UEBER_T->Skonto,UEBER_T->Kto, UEBER_T->BankAusw,;
        CT:getIban(),sepaNr)

      skip
    enddo

    // Now save the file
    mkmydir(SEPA_PFAD)
    sepaExport:dump(fileName)

  RECOVER USING objErr
    Error("Fehler SEPA Export: "+objErr:description)

    // SEPA Eintr�ge in Zahlaus l�schen
    select Zahlaus
    aktOrd:=ZAHLAUS->(indexord())
    ZAHLAUS->(OrdSetFocus(2))
    ZAHLAUS->(dbseek(sepaNr))
    do while ! ZAHLAUS->(eof()) .and. ZAHLAUS->SepaNr==sepaNr
      rec_lock(0)
      delete
      skip
    enddo
    ZAHLAUS->(OrdSetFocus(aktOrd))
    select UEBER_T

    return NIL
  END SEQUENCE

return fileName
/** eop */


/** �bersetzt die akt. Windows Coderpage in die "alte" EN Codepage f�r die alten Typenrad-Drucker */
static function mytranslate(text)
LOCAL result:=hb_translate(text, "DEWIN","EN")

  // Durchmesser ersetzen, wird hier eher nicht gebraucht!
  result:=strtran(result,chr(248),chr(162))

return result
/** eof */

/** nop -> neuer Bankdrucker braucht das nicht mehr */
static function notranslate(text)
return text
/** eof */

/** Zum nachtr�glichen editieren von Sepa-�berweisungen */
procedure editSepa()
LOCAL SepaNr,bankNr,fileName,hbName,Sepa,objErr,execDate

  cls
  titel("SEPA XML Datei bearbeiten")

  if ! open("Zahlaus","Ueber_T","Hausbank","BankStam")
    Error(TRY_AGAIN)
    close data
    return
  endif

  select HausBank
  set rela to HAUSBANK->BLZ into BankStam
  select ZahlAus
  ZAHLAUS->(OrdSetFocus(2))
  set rela to ZAHLAUS->BankNr into Hausbank

  go top

  Hilfe("EditSepa",getnew())

  if lastkey()==K_RETURN

    if Ueber_T->(reccount()) > 0
      Error(ACHTUNG+"Es sind noch offene �berweisungen vorhanden.||"+;
        "         Bitte vorher unter Men�punkt 2 drucken oder |"+;
        "         unter Men�punkt 20 als SEPA Datei ausleiten.")
      close data
      return
    endif

    Message("Daten werden importiert.  Bitte warten...")

    sepaNr:=ZAHLAUS->SepaNr

    backup("ZahlAus","pre-EditSepa")

    select Ueber_t
    zap
    select ZahlAus
    set rela to // WICHTIG, da sonst HAUSBANK sich bei add_rec �ndert
    set filter to ZAHLAUS->SepaNr==SepaNr .and. ZAHLAUS->KZ==SEPA_KZ

    go top
    do while ! ZAHLAUS->(eof())

      select Ueber_t
      add_rec(0)
      REPLACE UEBER_T->LiefNr WITH ZAHLAUS->LiefNr
      REPLACE UEBER_T->Zweck WITH ZAHLAUS->Zweck
      REPLACE UEBER_T->Betr_euro WITH ZAHLAUS->Soll_Euro + ZAHLAUS->Skto_Euro
      REPLACE UEBER_T->Skonto WITH ZAHLAUS->Skto_Proz
      REPLACE UEBER_T->EigenNr WITH ZAHLAUS->Zweck2
      REPLACE UEBER_T->Kto WITH ZAHLAUS->Kto
      REPLACE UEBER_T->BankAusw WITH ZAHLAUS->BLZ
      REPLACE UEBER_T->IBAN WITH ZAHLAUS->IBAN
      if bankNr==NIL
        bankNr:=ZAHLAUS->BankNr
      else
        if bankNr<>ZAHLAUS->BankNr
          Error(ACHTUNG+;
            "SEPA XML mit verschiedenen Hausbanken kann nicht bearbeitet werden.",.t.,"root")
          select Ueber_t
          zap
          close data
          return
        endif
      endif
      select Zahlaus
      skip
    enddo

    // nur falls �bernahme ok alle alten Eintr�ge l�schen
    select Zahlaus
    go top
    do while ! ZAHLAUS->(eof())
      rec_lock(0)
      delete
      skip
    enddo
    set filter to

    HAUSBANK->(dbseek(bankNr))
    BANKSTAM->(dbseek(HAUSBANK->BLZ))
    hbName:=trim(no_blanks(left(BANKSTAM->BankBez,11)))
    fileName:=SEPA_PFAD+BACKSLASH+"MIKI-"+hbName+"-"+sepaNr+".xml"
    // pr�fe ob Datei existiert
    if file(fileName) // .and. Message(fileName+" l�schen? (@J@/@N@)","JN","N")=="J"
      BEGIN SEQUENCE
        sepa:=SEPA():read(fileName) // mit Checksum File check!!!
        execDate:=sepa:getExecutionDate()
        sepa:ferase()
      RECOVER USING objErr
        Error(getErrorDispText(objErr))
      END SEQUENCE
    else
      Error(ACHTUNG+"SEPA Datei nicht gefunden.||        "+filename,.t.)
    endif

    dbcommitall()
    dbunlockall()
    select ZahlAus
    ZAHLAUS->(OrdSetFocus(1))

    UeberErfassen(.t.,bankNr,execDate)

  endif

  close data
return
/** eop */

/** Pr�ft & druckt eine Sepa XML Datei */
PROCEDURE SepaFileCheck(fileName,Ausgabe)
LOCAL sepa,allCTS,objErr,CT,oDlg
LOCAL Zeile:=0,summe,oFiles
LOCAL i,seite:=0
LOCAL aktSel:=alias(), protName

  default Ausgabe:=.f.

  cls
  Titel("SEPA XML Datei pr�fen & drucken")

  if empty(fileName)
    // �ffne FileDialog
    oDlg:=QFileDialog()
    oDlg:setWindowTitle( "SEPA Datei ausw�hlen" )
    oDlg:setNameFilter("*.xml")
    oDlg:setDirectory(SEPA_PFAD)
    oDlg:setFileMode(QFileDialog_ExistingFile)
    oDlg:setLabelText(QFileDialog_FileName,"Datei:")
    oDlg:setLabelText(QFileDialog_LookIn,"Pfad:")
    oDlg:setLabelText(QFileDialog_FileType,"Typ:")
    oDlg:setLabelText(QFileDialog_Accept,"�ffnen")
    oDlg:setLabelText(QFileDialog_Reject,"Abbrechen")

    oDlg:setReadOnly(.t.)

    // register Dialog, so it is closed when shutdown is requested
    registerDialog(oDlg)

    if oDlg:exec()==QDialog_Accepted
      oFiles:=oDlg:selectedFiles()
      fileName:=oFiles:at(0)
    endif
  endif

  // Ausgabe
  if fileName==NIL .or. empty(fileName)
    if aktSel<>NIL .and. ! empty(aktSel)
      select (aktSel)
    endif
    RETURN
  endif

  Drucker("BS","SEPA-Ueberweisungs-Liste",,,PDF_NO_CONFIRM)

  if ! open("Bankstam")
    Error(TRY_AGAIN)
    close data
    return
  endif
  select BankStam
  BANKSTAM->(OrdSetFocus(3)) // BIC

  BEGIN SEQUENCE
    summe:=0
    seite:=0
    zeile:=0

    sepa:=SEPA():read(fileName,.t.) // ohne Checksum File check!!!

    // Pr�fe Cheksum, Anzeige ob ok oder nicht, danach normal weiter
    BEGIN SEQUENCE
      if ! sepa:readCheckSumFile() // ohne Checksum File check!!!
        Error(ACHTUNG+"Keine g�ltige CheckSum-Datei gefunden.",.t.)
      endif
    RECOVER USING objErr
      Error(getErrorDispText(objErr),.t.,"root")
    END SEQUENCE

    allCTS:=sepa:getCreditTransfers()
    i:=1

    do while i<=len(allCTS)
      seite++
      ? "SEPA XML Export                  vom:",getUser():date,space(11),"Seite",str(seite,3)
      ? replicate("=",68)
      ? "Datei:",fileName
      ? "Ausf�hrungsdatum:",sepa:getExecutionDate(),space(5),"(lfd. SEPA Nr.:"+sepa:messageID+")"
      ?

      do while i<=len(allCTS) .and. zeile < DRUCKER->laenge - LISTE->Unt_Rand-10
        CT:=allCTS[i]
        BANKSTAM->(dbseek(CT:getBIC()))

        ? "Empf�nger.:",FETT_AN,CT:getCreditorID(),CT:getCreditorName(),FETT_AUS
        ? "IBAN......:",CT:getIBAN()
        if BANKSTAM->Land == DEUTSCH_LAND
          ?? "BLZ:",substr(CT:getIBAN(),5,8),"Kto:",substr(CT:getIBAN(),13)
        endif
        ? "BIC.......:",CT:getBIC(),left(BANKSTAM->BankBez,50)
        ? "Verw.Zweck:",CT:getPurpose()
        ? "Eigen-Nr..:",CT:getID(),space(5),"(lfd.Nr.:"+CT:getSequencer()+")"
        ? "Wert......:",FETT_AN,CT:getvalue() ,"Euro",FETT_AUS
        ?
        ?
        summe+= CT:getvalue()
        i++
      enddo
      if ! (zeile < DRUCKER->laenge - LISTE->Unt_Rand-10)
        Zeile:=FormFeed(Zeile,Seite)
      endif
    enddo

    ? replicate("=",68)
    ? "Anzahl Posten:",str(i-1,12,2)
    if SEPA:getNumTransactions()<>i-1
      ? COLOR_RED
    else
      ?
    endif
    ?? "Anzahl XML   :",str(SEPA:getNumTransactions(),12,2),COLOR_DEFAULT
    ?
    ? "Summe Posten :",str(summe,12,2),"Euro"
    if round(SEPA:getControlSum(),2)<>round(summe,2)
      ? COLOR_RED
    else
      ?
    endif
    ?? "Summe XML    :",str(SEPA:getControlSum(),12,2),"Euro",COLOR_DEFAULT

    if SEPA:getControlSum()<>round(summe,2) .or. SEPA:getNumTransactions()<>i-1
      Error(ACHTUNG+"Kontrollsumme falsch.  XML Datei fehlerhaft!")
    endif

    // drucker("Off")
    getUser():getCurrentPrintJob():endDoc()
    protName:=getUser():getCurrentPrintJob():pdfFullFileName

    if fileName<>NIL .and. protName <> NIL
      email(MAIN_EMAIL,"SEPA XML Export bitte pr�fen","Bitte pr�fen", protName, .f., .t.)
    endif
    getUser():setCurrentPrintJob(NIL)

  RECOVER USING objErr
    Error(getErrorDispText(objErr),.t.,"root")
  END SEQUENCE

  select Bankstam
  BANKSTAM->(OrdSetFocus(1))

  if aktSel==NIL .or. empty(aktSel)
    close data
  else
    select (aktSel)
  endif

return
/** eop */

/* aktualisiert alle Hausbanken f�rs akt. Jahr */
PROCEDURE updateHBSaldo()
LOCAL i,aktSaldo

  cls
  Titel("Hausbanken Saldo aktualisieren")

  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open( "Hausbank","ZAHLAUS")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  select Hausbank
  go top
  do while ! HAUSBANK->(eof())

    // berechne Saldo neu bis akt. Monat
    for i:=1 to 12
      if i<=month(getUser():date)
        sumMonat(HAUSBANK->BankNr,i)
      else
        rec_lock(0)
        aktSaldo:="HAUSBANK->Saldo"+right("00"+alltrim(str(i,2)),2)
        replace &(aktSaldo) with 0
        dbcommit()
        dbunlock()
      endif
    next
    skip
  enddo
  close data

return
/** eof */

/** Liest die aktuellen BLZ aus einer CSV Datei
  *
  * Download .txt file (blz-aktuell-txt-data.txt) from:
  https://www.bundesbank.de/de/aufgaben/unbarer-zahlungsverkehr/serviceangebot/bankleitzahlen
  => download-bankleitzahlen
  */
Procedure BLZImport(DateiName)
LOCAL merkBLZ
LOCAL datei,feld,oDlg,oFiles

  cls
  Titel("BLZ importieren")
  Message("Bitte Import Daten ausw�hlen.")
  if DateiName==NIL
    // �ffne FileDialog
    oDlg:=QFileDialog()
    oDlg:setWindowTitle( "BLZ Datei ausw�hlen" )
    oDlg:setNameFilter("*.txt")
    oDlg:setDirectory(IMPORT)
    oDlg:setFileMode(QFileDialog_ExistingFile)
    oDlg:setLabelText(QFileDialog_FileName,"Datei:")
    oDlg:setLabelText(QFileDialog_LookIn,"Pfad:")
    oDlg:setLabelText(QFileDialog_FileType,"Typ:")
    oDlg:setReadOnly(.t.)
    // register Dialog, so it is closed when shutdown is requested
    registerDialog(oDlg)
    if oDlg:exec()==QDialog_Accepted
      oFiles:=oDlg:selectedFiles()
      dateiName:=oFiles:at(0)
    endif
  endif

  if ! empty(DateiName)
    if ! open({"BankStam",.t.})
      Error(ACHTUNG+"bitte alle anderen Bank-Programme schlie�en und erneut versuchen.")
    else
      Message("Bank-Daten werden importiert.  Bitte warten....")
      // zap
      dele for BANKSTAM->Land == DEUTSCH_LAND
      pack
      append from (DateiName) sdf

      BANKSTAM->(OrdSetFocus(0))

      go top
      do while ! BANKSTAM->(eof())
        if ! empty(BANKSTAM->import_BLZ)
          replace BANKSTAM->blz with BANKSTAM->import_BLZ
          replace BANKSTAM->Land with DEUTSCH_LAND
        endif
        skip
      enddo

      // BLZ Reihenfolge
      BANKSTAM->(OrdSetFocus(1))

      // remove dubletten
      go top
      merkBLZ:=replicate("0",len(BANKSTAM->BLZ))
      do while ! BANKSTAM->(eof())
        if merkBLZ==BANKSTAM->BLZ
          delete
        else
          writeModData()
          merkBLZ:=BANKSTAM->BLZ
        endif
        skip
      enddo

      Protokoll(INIT_P,"BLZ Import - Konsistenzcheck")

      for each datei in {"Kunden","Hausbank"}
        if ! open(datei)
          Protokoll(PROTOKOLL,"Fehler: "+datei+" Datei konnte nicht ge�ffnet werden.")
        else
          Protokoll(PROTOKOLL,"Pr�fe: "+datei)
          go top
          do while ! (DATEI)->(eof())
            if ! empty((DATEI)->Blz) .and. (DATEI)->Blz<>"99999999"
              BANKSTAM->(dbseek((DATEI)->Blz))
              if BANKSTAM->(eof())
                Protokoll(PROTOKOLL,space(7)+fieldget(1)+" -> "+;
                  (DATEI)->Blz+" nicht gefunden => BLZ gel�scht.")
                rec_lock(0)
                replace (DATEI)->Blz with ""
                if (DATEI)->(fieldpos("Iban")) > 0
                  replace (DATEI)->IBAN with ""
                endif
                dbcommit()
                dbunlock()
              else // Bankstamm gefunden -> BIC vergleichen, neu 20160318
                if trim(BANKSTAM->BIC) <> trim((DATEI)->BIC)
                  Protokoll(PROTOKOLL, if(Datei=="Kunden",KUNDEN->KundNr +;
                    " " + KUNDEN->KurzName,;
                    "Hausbank ")+;
                    left(BANKSTAM->BankBez,25)+" BIC: alt:";
                    + (DATEI)->BIC + " neu: " + BANKSTAM->BIC)
                  rec_lock(0)
                  replace (DATEI)->BIC with BANKSTAM->BIC
                endif
              endif
            endif
            skip
          enddo
        endif
      next

      datei:="Lieferan"
      if ! open(datei)
        Protokoll(PROTOKOLL,"Fehler: "+datei+" Datei konnte nicht ge�ffnet werden.")
      else
        Protokoll(PROTOKOLL,"Pr�fe: "+datei)
        go top
        do while ! (DATEI)->(eof())
          for each feld in {"EBLZ","PBLZ"}
            if ! empty((DATEI)->&(feld))
              BANKSTAM->(dbseek((DATEI)->&(feld)))
              if BANKSTAM->(eof())
                Protokoll(PROTOKOLL,space(7)+LIEFERAN->LiefNr+" "+LIEFERAN->Kurzname+"   BLZ: "+;
                  (DATEI)->&(feld)+" nicht gefunden => BLZ gel�scht.")
                rec_lock(0)
                replace (DATEI)->&(feld) with ""
                if feld = "EBLZ"
                  replace (DATEI)->EIBAN with ""
                else
                  replace (DATEI)->PIBAN with ""
                endif
                dbcommit()
                dbunlock()
              else
                if feld = "EBLZ"
                  if trim(BANKSTAM->BIC) <> trim((DATEI)->EBIC)
                    Protokoll(PROTOKOLL,LIEFERAN->LiefNr + " " + LIEFERAN->Kurzname+;
                      left(BANKSTAM->BankBez,25)+" BIC: alt:" + (DATEI)->EBIC + " neu: " + BANKSTAM->BIC)
                    rec_lock(0)
                    replace (DATEI)->EBIC with BANKSTAM->BIC
                  endif
                else
                  if trim(BANKSTAM->BIC) <> trim((DATEI)->PBIC)
                    Protokoll(PROTOKOLL,LIEFERAN->LiefNr + " " + LIEFERAN->Kurzname+;
                      left(BANKSTAM->BankBez,25)+" BIC: alt:" + (DATEI)->PBIC + " neu: " + BANKSTAM->BIC)
                    rec_lock(0)
                    replace (DATEI)->PBIC with BANKSTAM->BIC
                  endif
                endif
              endif
            endif
          next
          skip
        enddo

        dbcommitall()
        dbunlockall()

      endif

      Protokoll(P_CREATE_PDF,,,,.t.)

      // Ergebnis anzeigen
      // Hilfe("BLZ IMPORT",getnew(),"Blubb")

      close data

      // importierte Datei nach done schieben
      mkMyDir( IMPORT_DONE )
      frename( replaceWindowsSlashes( DateiName ) , IMPORT_DONE +;
        BACKSLASH + getFileName(DateiName) )

      Message("BLZ importiert.   Bitte @Taste@ dr�cken.","@")

    endif
  endif
  cls
return
/** eop */

Procedure BLZUpdate()
LOCAL datei,feld
LOCAL merkeBLZ

  cls
  Titel("BLZ update")

  if ! open("BankStam")
    Error(ACHTUNG+"bitte alle anderen Bank-Programme schlie�en und erneut versuchen.")
    close data
    return
  endif

  // BLZ Reihenfolge
  BANKSTAM->(OrdSetFocus(1))

  Protokoll(INIT_P,"BLZ Import - Konsistenzcheck")

  // find dubletten
  go top
  merkeBLZ:=replicate("0",len(BANKSTAM->BLZ))
  do while ! BANKSTAM->(eof())
    if merkeBLZ==BANKSTAM->BLZ
      Protokoll(PROTOKOLL,"BLZ doppelt: "+merkeBLZ)
    else
      merkeBLZ:=BANKSTAM->BLZ
    endif
    skip
  enddo

  for each datei in {"Kunden","Hausbank"}
    if ! open(datei)
      Protokoll(PROTOKOLL,"Fehler: "+datei+" Datei konnte nicht ge�ffnet werden.")
    else
      Protokoll(PROTOKOLL,"Pr�fe: "+datei)
      go top
      do while ! (DATEI)->(eof())
        if ! empty((DATEI)->Blz) .and. (DATEI)->Blz<>"99999999"
          BANKSTAM->(dbseek((DATEI)->Blz))
          if BANKSTAM->(eof())
            Protokoll(PROTOKOLL,space(7)+fieldget(1)+" -> "+;
              (DATEI)->Blz+" nicht gefunden => BLZ gel�scht.")
            rec_lock(0)
            replace (DATEI)->Blz with ""
            if (DATEI)->(fieldpos("Iban")) > 0
              replace (DATEI)->IBAN with ""
            endif
            dbcommit()
            dbunlock()
          else // Bankstamm gefunden -> BIC vergleichen, neu 20160318
            if trim(BANKSTAM->BIC) <> trim((DATEI)->BIC)
              Protokoll(PROTOKOLL, if(Datei=="Kunden",KUNDEN->KundNr +;
                " " + KUNDEN->KurzName,;
                "Hausbank ")+;
                left(BANKSTAM->BankBez,25)+" BIC: alt:" + (DATEI)->BIC + " neu: " + BANKSTAM->BIC)
              rec_lock(0)
              replace (DATEI)->BIC with BANKSTAM->BIC
            endif
          endif
        endif
        skip
      enddo
    endif
  next

  datei:="Lieferan"
  if ! open(datei)
    Protokoll(PROTOKOLL,"Fehler: "+datei+" Datei konnte nicht ge�ffnet werden.")
  else
    Protokoll(PROTOKOLL,"Pr�fe: "+datei)
    go top
    do while ! (DATEI)->(eof())
      for each feld in {"EBLZ","PBLZ"}
        if ! empty((DATEI)->&(feld))
          BANKSTAM->(dbseek((DATEI)->&(feld)))
          if BANKSTAM->(eof())
            Protokoll(PROTOKOLL,space(7)+LIEFERAN->LiefNr+" "+LIEFERAN->Kurzname+"   BLZ: "+;
              (DATEI)->&(feld)+" nicht gefunden => BLZ gel�scht.")
            rec_lock(0)
            replace (DATEI)->&(feld) with ""
            if feld = "EBLZ"
              replace (DATEI)->EIBAN with ""
            else
              replace (DATEI)->PIBAN with ""
            endif
            dbcommit()
            dbunlock()
          else
            if feld = "EBLZ"
              if trim(BANKSTAM->BIC) <> trim((DATEI)->EBIC)
                Protokoll(PROTOKOLL,LIEFERAN->LiefNr + " " + LIEFERAN->Kurzname+;
                  left(BANKSTAM->BankBez,25)+" BIC: alt:" + (DATEI)->EBIC + " neu: " + BANKSTAM->BIC)
                rec_lock(0)
                replace (DATEI)->EBIC with BANKSTAM->BIC
              endif
            else
              if trim(BANKSTAM->BIC) <> trim((DATEI)->PBIC)
                Protokoll(PROTOKOLL,LIEFERAN->LiefNr + " " + LIEFERAN->Kurzname+;
                  left(BANKSTAM->BankBez,25)+" BIC: alt:" + (DATEI)->PBIC + " neu: " + BANKSTAM->BIC)
                rec_lock(0)
                replace (DATEI)->PBIC with BANKSTAM->BIC
              endif
            endif
          endif
        endif
      next
      skip
    enddo

    dbcommitall()
    dbunlockall()

  endif

  Protokoll(P_CREATE_PDF)

  // Ergebnis anzeigen
  // Hilfe("BLZ IMPORT",getnew(),"Blubb")

  close data

  cls
return
/** eop */

/**
*
* Pr�ft die manuelle Eingabe der Kto Nummer -> berechnet evtl. IBAN Nummer neu
*/
FUNCTION enterKto(oGet)
LOCAL result:=.t.

  if oGet:changed .and. ! empty(oGet:buffer)
    // keine f�hrenden Nullen automat. einf�gen
    // if len(alltrim(oGet:Buffer))<10
    // if Message("Konto-Nummer zu kurz.  Mit 0 auff�llen? (@J@/@N@)","JN","J")=="J"
    // oGet:varput(right(replicate("0",10)+alltrim(oGet:buffer),10))
    // endif
    // endif

    switch upper(oGet:name)
    case "KUNDEN->KTO"
      if ! empty(KUNDEN->Blz)
        BANKSTAM->(dbseek(KUNDEN->Blz))
        if BANKSTAM->Land == DEUTSCH_LAND .and. ;
          (empty(KUNDEN->IBAN) .or. (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
          replace KUNDEN->IBAN with getIban(BANKSTAM->Land,KUNDEN->Blz,KUNDEN->Kto)
        endif
      endif
      exit
    case "LIEFERAN->EKTO"
      if ! empty(LIEFERAN->eBLZ)
        BANKSTAM->(dbseek(LIEFERAN->eBlz))
        if BANKSTAM->Land == DEUTSCH_LAND .and. ;
          (empty(LIEFERAN->eIBAN) .or. (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
          replace LIEFERAN->eIBAN with getIban(BANKSTAM->Land,LIEFERAN->eBlz,LIEFERAN->eKto)
        endif
      endif
      exit
    case "LIEFERAN->PKTO"
      if ! empty(LIEFERAN->pBLZ)
        BANKSTAM->(dbseek(LIEFERAN->pBlz))
        if BANKSTAM->Land == DEUTSCH_LAND .and. ;
          ( empty(LIEFERAN->pIBAN) .or. (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J") )
          replace LIEFERAN->pIBAN with getIban(BANKSTAM->Land,LIEFERAN->pBlz,LIEFERAN->pKto)
        endif
      endif
      exit
    case "HAUSBANK->KTONR"
      if ! empty(HAUSBANK->BLZ)
        BANKSTAM->(dbseek(HAUSBANK->Blz))
        if BANKSTAM->Land == DEUTSCH_LAND .and. ;
          (empty(HAUSBANK->IBAN) .or. (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
          replace HAUSBANK->IBAN with getIban(BANKSTAM->Land,HAUSBANK->Blz,HAUSBANK->KtoNr)
        endif
      endif
      exit
    otherwise
      Error(ACHTUNG+"unbek. IBAN check:"+oGet:name,.t.,"root")
    endswitch
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif

RETURN result
/** eof */


/**
*
* Pr�ft die manuelle Eingabe der BLZ -> berechnet evtl. IBAN Nummer und aktualisiert die BIC
*/
FUNCTION enterBLZ(oGet)
LOCAL result:=.t.

  if oGet:changed .and. !empty(oGet:buffer)

    oGet:buffer:=no_blanks( oGet:buffer )
    oGet:varPut( oGet:buffer )

    if ! check(oget,"BankStam",.f.,.t.)
      result:=.f.
    else
      switch upper(oGet:name)
      case "KUNDEN->BLZ"
        replace KUNDEN->BIC with BANKSTAM->Bic

        if ! ( result:=pruefeLandBIC( KUNDEN->IBAN, KUNDEN->BIC ) )
          exit
        endif

        if ! empty(KUNDEN->Kto) .and. ! empty(oGet:buffer)
          BANKSTAM->(dbseek(KUNDEN->Blz))
          if BANKSTAM->Land == DEUTSCH_LAND .and. ;
            ( empty(KUNDEN->IBAN) .or.;
            (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J") )
            replace KUNDEN->IBAN with getIban(BANKSTAM->Land,KUNDEN->Blz,KUNDEN->Kto)
          endif
        endif
        exit
      case "LIEFERAN->EBLZ"
        replace LIEFERAN->eBIC with BANKSTAM->Bic
        // if trim(no_blanks(LIEFERAN->eBLZ)) == trim(no_blanks(LIEFERAN->pBLZ))
        // Error(ACHTUNG+"mehrere Konten bei einer Bank nicht m�glich.")
        // return .f.
        // endif

        if ! ( result:=pruefeLandBIC( LIEFERAN->eIBAN, LIEFERAN->eBIC ) )
          exit
        endif

        if ! empty(LIEFERAN->eKto) .and. ! empty(oGet:buffer)
          BANKSTAM->(dbseek(LIEFERAN->eBlz))
          if BANKSTAM->Land == DEUTSCH_LAND .and. ;
            ( empty(LIEFERAN->eIBAN) .or.;
            (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
            replace LIEFERAN->eIBAN with getIban(BANKSTAM->Land,LIEFERAN->eBlz,LIEFERAN->eKto)
          endif
        endif
        exit
      case "LIEFERAN->PBLZ"
        replace LIEFERAN->pBIC with BANKSTAM->Bic
        // if trim(no_blanks(LIEFERAN->eBLZ)) == trim(no_blanks(LIEFERAN->pBLZ))
        // Error(ACHTUNG+"mehrere Konten bei einer Bank nicht m�glich.")
        // return .f.
        // endif

        if !( result:=pruefeLandBIC( LIEFERAN->pIBAN, LIEFERAN->pBIC ) )
          exit
        endif

        if ! empty(LIEFERAN->pKto) .and. ! empty(oGet:buffer)
          BANKSTAM->(dbseek(LIEFERAN->pBlz))
          if BANKSTAM->Land == DEUTSCH_LAND .and. ;
            ( empty(LIEFERAN->pIBAN) .or.;
            (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
            replace LIEFERAN->pIBAN with getIban(BANKSTAM->Land,LIEFERAN->pBlz,LIEFERAN->pKto)
          endif
        endif
        exit
      case "HAUSBANK->BLZ"
        if ! empty(HAUSBANK->KtoNr) .and. ! empty(oGet:buffer)
          replace HAUSBANK->BIC with BANKSTAM->Bic

          if ! ( result:=pruefeLandBIC( HAUSBANK->IBAN, HAUSBANK->BIC ) )
            exit
          endif

          BANKSTAM->(dbseek(HAUSBANK->Blz))
          if BANKSTAM->Land == DEUTSCH_LAND .and. ;
            (empty(HAUSBANK->IBAN) .or.;
            (Message("IBAN Nummer aktualisieren? (@J@/@N@)","JN","J")=="J"))
            replace HAUSBANK->IBAN with getIban(BANKSTAM->Land,HAUSBANK->Blz,HAUSBANK->KtoNr)
          endif
        endif
        exit
      otherwise
        Error(ACHTUNG+"unbek. IBAN check:"+oGet:name,.t.,"root")
      endswitch
    endif
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif

RETURN result
/** eof */


/* pr�ft ob bei einem Lieferanten Skto eingegeben wurde, bei dem es nicht erlaubt ist */
static function checkBankSkto( oGet )
  if oGet:changed
    if val(oget:Buffer) < 0
      return .f.
    endif

    if LIEFERAN->Skonto == "N" .and. val(oget:Buffer) > 0
      Error(ACHTUNG+"bei diesem Lieferanten bitte kein Sktonto abziehen.")
      oGet:varput(0)
      return .t.
    endif
  endif
return .t.
  /* eof */



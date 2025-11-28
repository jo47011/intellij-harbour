/* Modul: disp.prg
*
* enth�lt Stammdaten-Masken, 2. Teil siehe disp2.prg , disp3.prg
*/
#include "Miki.ch"

#command Standard_disp() => ;
  if Aendern ;
  ; Sperr_Reader( GetList , Sperren ) ;
  ; GetList:={} ;
  ; dbcommit() ;
  ;else ;
  ; Sperr_Reader(GetList,.t.,"AUSGABE") ;
  ; GetList:={} ;
  ;endif

/* Zahlungskondistionen */
PROCEDURE ZK_Disp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL x:=4 , li:=3

  @ x,li-2 clear to x+9,li+7566
  @ x,li-2 to x+9,li+75
  @ x + 1,li say "Nummer: " + ZAHLKOND->ZkNr
  @ x + 2,li get ZAHLKOND->Text
  @ x + 3,li get ZAHLKOND->Text2

  @ x + 1,54 say "Monate Tage"
  @ x + 2,40 say "Skonto:" get ZAHLKOND->Skto
  qqout(" %")
  @ x + 2,56 get ZAHLKOND->SktoMonate
  @ x + 2,62 get ZAHLKOND->SktoTage

  @ x + 3,40 say "F�llig:"
  @ x + 3,56 get ZAHLKOND->Monate
  @ x + 3,62 get ZAHLKOND->Tage

  @ x + 5,40 say "Falls ein Monat eingegeben wird, gilt "
  @ x + 6,40 say "der Tag als absoluter Tag des Datums."
  @ x + 7,40 say "Also bei 3 Monaten und 2 Tagen,"
  @ x + 8,40 say "der 2. des 3 Monats ab Rechnungsdatum."

  @ x + 5,li say "Englisch:"
  @ x + 7,li get ZAHLKOND->E_Text
  @ x + 8,li get ZAHLKOND->E_Text2 when message()

  // Rechnungstext
  @ x + 10,li-2 to x+17,li+75
  @ x + 10,li say "Rechnungs-Text:"
  @ x + 11,li get ZAHLKOND->ReText;
    when Message("Text f�r Rechnung eingeben.  @F12@=Platzhalter-Auswahl")
  @ x + 12,li get ZAHLKOND->ReText2

  @ x + 14,li say "Englisch:"
  @ x + 15,li get ZAHLKOND->E_ReText
  @ x + 16,li get ZAHLKOND->E_ReText2


  Standard_disp()
RETURN


/* Versand-Arten */
PROCEDURE VarDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 13,66

  @ 10,14 say "Nummer..: " + VERSART->VersNr
  @ 10,46 say "Verpack. Fracht"
  @ 12,14 get VERSART->Text
  @ 12,50 get VERSART->verpack picture "!" valid VERSART->verpack $"JN"
  @ 12,57 get VERSART->fracht picture "!" valid VERSART->Fracht $"JN"
  @ 9,12 to 13,66

  Standard_disp()
RETURN
/* EOP VarDisp */


/* Kunden */
PROCEDURE KunDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL re:=78 , li:=01 , ob:=1 , un:=23 , count
LOCAL tempval


  @ ob,li-1 clear to un,re

  @ ob+ 0,li say "Kunden-Nr..........: " +KdOut(KUNDEN->KundNr)
  @ ob+ 0,li+36 say "Kurzname....:" get KUNDEN->Kurzname PICTURE "@!"
  @ ob+ 1,li to ob+1,re

  @ ob+ 2,li+10 say "Postanschrift"

  // Sammelstelle
  if ! empty(KUNDEN->S_Name)
    @ ob+ 2,li+27 say "-> Sammelstelle ->"
  endif
  @ ob+ 2,li+45 say "Versandanschrift"

  @ ob+ 3,li say "Name....:" get KUNDEN->Name picture"@K";
    valid;
    {;
    |oGet|;
    len(oGet:Buffer);
    > 5 .and. checkSepaValid(oGet) .and. MySetKey( K_F8 , NIL )} when Message("Kunden-Adresse "+;
    "eingeben.    @F8@=Zeile auf Versandadresse kopieren.") .and. MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  @ ob+ 4,li say "         " get KUNDEN->Partner picture"@K" valid MySetKey( K_F8 , NIL );
    when;
    Message("Kunden-Adresse eingeben.    @F8@=Zeile auf Versandadresse kopieren.");
    .and. MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  @ ob+ 5,li say "Stra�e..:" get KUNDEN->Strasse picture"@K" valid MySetKey( K_F8 , NIL );
    when;
    Message("Kunden-Adresse eingeben.    @F8@=Zeile auf Versandadresse kopieren.");
    .and. MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  @ ob+ 6,li say "Postfach:" get KUNDEN->Zusatz picture"@K";
    valid MySetKey( K_F8 , NIL ) ;
    when Message("Kunden-Adresse eingeben.    @F8@=Zeile auf Versandadresse kopieren.") .and. ;
    MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  @ ob+ 7,li say "PLZ/Ort :" get KUNDEN->land picture "@!" ;
    valid { |oGet| check(oGet,"Land",.f.,.f.) .and. nachKundLand1(oGet) .and. MySetKey( K_F8 , NIL )};
    when Message("Kunden-Adresse eingeben.    @F8@=Zeile auf Versandadresse kopieren.") .and. ;
    MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 7,li+13 get KUNDEN->Plz picture"@K" valid MySetKey( K_F8 , NIL );
    when;
    Message("Kunden-Adresse eingeben.    @F8@=Zeile auf Versandadresse kopieren.");
    .and. MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  @ ob+ 7,li+21 get KUNDEN->Ort picture "@S23";
    valid { |oGet| Kund_vor_Vers(oGet) .and. MySetKey( K_F8 , NIL )} when Message("Kunden-Adresse "+;
    "eingeben.    @F8@=Zeile auf Versandadresse kopieren.") .and. MySetKey( K_F8 , { |p1,oGet| copyKdAdr(p1,oGet) } )

  if select("Land")==0
    open("Land")
    select Kunden
  endif
  LAND->(dbseek(left(KUNDEN->Land,2)))
  @ ob+ 8,li say trim(LAND->Name)
  @ ob+ 8,li+19 say " Sprache:" get KUNDEN->Sprache picture"!";
    valid KUNDEN->Sprache $ "ED" .and. message() when Message("Bitte Sprache eingeben: @De@utsch "+;
    "oder @E@nglish      @F12@=Auswahl")

  @ ob+ 3,li+45 get KUNDEN->Name2 picture"@K"
  @ ob+ 4,li+45 get KUNDEN->Partner2 picture"@K"
  @ ob+ 5,li+45 get KUNDEN->Strasse2 picture"@K"
  @ ob+ 6,li+45 get KUNDEN->Zusatz2 picture"@K"
  @ ob+ 7,li+45 get KUNDEN->land2 picture "@!" ;
    valid { |oGet| check(oGet,"Land",.f.,.f.) .and. nachKundLand2(oGet)}
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 7,li+ 3+45 get KUNDEN->Plz2 picture"@K"
  @ ob+ 7,li+11+45 get KUNDEN->Ort2 picture "@S27"
  LAND->(dbseek(left(KUNDEN->Land2,2)))
  @ ob+ 8,li+45 say trim(LAND->Name)
  @ ob+ 8,li+62 say " Sprache:" get KUNDEN->Sprache2 picture"!" valid KUNDEN->Sprache2 $ "ED" .and.;
    message() when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")

  @ ob+9, li say "Tel:" get KUNDEN->Telefon when Message()
  @ ob+9, li + 26 say "Mobil:" get KUNDEN->Mobil
  @ ob+10,li say "Fax:" get KUNDEN->Fax
  @ ob+10,li+26 say "Email:" get KUNDEN->Email picture "@S42" valid {|oget| isValidEmail(oget)}

  tempval:="Ansprechp. (P): " + getAnsprechPartners() +;
    " | Anlief.Zeit (Z):" + memotran(KUNDEN->Anlief,' ',' ')
  qout(left(space(li)+tempVal,80))

  @ ob+12,li to ob+12,re

  @ ob+13,li say "Versandart:" get KUNDEN->VersNr picture "@9" ;
    valid { |oGet| check(oGet,"VersArt",.t.) .and. dispAusgabe(oGet,"VERSART->Text")} when Message()
  if select("Versart")==0
    open("Versart")
    select Kunden
  endif
  VERSART->(dbseek(Kunden->VersNr))
  QQout(" "+VERSART->Text)

  @ ob+13,li+49 say "Unsere LF-Nr.:" get KUNDEN->LFD_Nr

  @ ob+14,li say "Zahl.Kond.:" get KUNDEN->ZKNr valid { |oGet| check(oGet,"ZahlKond",.t.) ;
    .and. dispAusgabe(oGet,"space(1)+ZAHLKOND->Text+spac(1)+left(ZahlKond->Text2,30)")} when Message()
  if select("ZahlKond")==0
    open("ZahlKond")
    select Kunden
  endif
  ZAHLKOND->(dbseek(Kunden->ZkNr))
  QQout("  "+trim(ZahlKond->Text),left(ZahlKond->Text2,30))

  if select("KundSped")==0
    open("KundSped")
    select Kunden
  endif

  if select("Spedit")==0
    open("Spedit")
    select Kunden
  endif

  @ ob+15,li say "Ident-Nr.:" get KUNDEN->IdentNr picture "@!" ;
    valid empty(KUNDEN->IdentNr).or. syntaxIdentNr(KUNDEN->IdentNr,KUNDEN->Land)
  @ ob+16,li say "Pal.-Kto.:" get KUNDEN->PalKto picture "@!" ;
    valid KUNDEN->PalKto $ "JN " when Message("Palletneingabe bei Kunden Pflicht? (@J@/@N@)")
  @ ob+16,li+13 say "Versich.KZ:" get KUNDEN->AusfVers picture "@!" valid KUNDEN->AusfVers $ "JN ";
    when Message("Versicherungskennzeichen f�r Ausfallvers. eingeben (@J@/leer oder @N@)")

  @ ob+15,li+27 say "EU  : "+ KUNDEN->EG
  @ ob+16,li+27 say "MWST:" get KUNDEN->Mwst_kz picture "9" ;
    valid { |oGet| check(oGet,"MwSt_KZ",.f.,.f.) .and. mwstAusgabe()} ;
    when Message("MwSt-Kennziffer eingeben.      @F12@=Auswahl")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  if select("Mwst_Kz")==0
    open("Mwst_Kz")
    select Kunden
  endif
  mwstAusgabe()

  @ ob+15,li+42 say "Vers.Anschr.:" get KUNDEN->VA picture "!";
    when Message("@J@ falls Versand-Anschrift abweichend") valid KUNDEN->VA $ "JN "
  @ ob+16,li+42 say "Rech.Anschr.:" get KUNDEN->RechAnschr picture "!";
    when Message("@J@ falls Rechnungs-Anschrift abweichend") valid message()

  if KUNDEN->Rabatt_KZ == "H"
    @ ob+15,li+58 say "H�ndlerRabatt:" get KUNDEN->So_Rabatt valid { |oGet| soRabNach(oGet) }
  else
    @ ob+15,li+58 say "Sonder-Rabatt:" get KUNDEN->So_Rabatt valid { |oGet| soRabNach(oGet) }
  endif
  @ ob+16,li+58 say "Anz. Re.Ausdrucke:" get KUNDEN->Re_Anz picture "9"

  // Zoll-Stelle wenn nicht EU
  if ! KUNDEN->EG $ "DJ"
    KUNDZOLL->(dbseek(Kunden->KundNr))
    if KUNDZOLL->(eof())
      @ ob+16,li say "(Zollstelle - Taste V)"
    else
      @ ob+16,li say "Zoll: "+ KUNDZOLL->ZollNr
      KUNDZOLL->(dbskip())
      if KUNDZOLL->KundNr == KUNDEN->KundNr
        qqout( "," + chr(133) )
      endif
      qqout( " (Taste V)" )
    endif
  endif


  @ ob+17,li to ob+17,re
  @ ob+17,li say "Spedition/Paket-Dienstleister" color COLINV
  @ ob+17,li + 30 say "Art" color COLINV
  @ ob+17,li + 34 say "Pausch." color COLINV
  @ ob+17,li + 42 say "Frei" color COLINV
  @ ob+17,li + 47 say "Zollstellen / Kd.Nr" color COLINV
  @ ob+17,li + 70 say "(Taste V)"

  count:=0
  KUNDSPED->(dbseek(Kunden->KundNr))
  do while KUNDSPED->KundNr == Kunden->KundNr .and. ! KUNDSPED->(eof()) .and. count < 5
    @ ob+18+count,li say ""
    SPEDIT->(dbseek(KUNDSPED->SpedNr))
    QQout(KUNDSPED->SpedNr)
    QQout(" " + SPEDIT->KurzName)
    QQout(" " + KUNDSPED->Art )
    if KUNDSPED->Vk <> 0
      QQout(str(KUNDSPED->Vk,7,2) + " " + EURO_SIGN )
    else
      qqout(space(9))
    endif
    QQout("  " + KUNDSPED->Frei)
    QQout("   " + left(getKdSpedZollstellen("KundSped"),39))
    Qout(space(5) + KUNDSPED->Bemerk1 )
    QQout(space(11) + KUNDSPED->SPEDKDNR )

    count += 2
    KUNDSPED->(dbskip())
  enddo

  Standard_disp()
RETURN
/* EOP KunDisp */

static function soRabNach(oGet)
local result:=KUNDEN->Rabatt_KZ
  if oget:changed .and. val(oGet:buffer) > 0
    result:=Message("@S@onderrabatt oder @H@�ndlerrabatt? (@S@/@H@)","SH",result)
    if ! ABBRUCH .and. result <> KUNDEN->Rabatt_KZ
      replace KUNDEN->Rabatt_KZ with result
      if KUNDEN->Rabatt_KZ == "H"
        @ oGet:row , oget:col - 15 say "H�ndlerRabatt:"
      else
        @ oGet:row , oget:col - 15 say "Sonder-Rabatt:"
      endif
    endif
  endif
return val( oGet:buffer ) >= 0

/* Function Kund_vor_Vers
*
* schl�get Postanschr.  als Vers.Anschr. vor, falls diese leer
*/
STATIC FUNCTION Kund_vor_Vers(oGet)
  if empty(KUNDEN->Name2) .and. lastkey()<>K_UP
    replace KUNDEN->Name2 WITH KUNDEN->Name
    replace KUNDEN->Partner2 WITH KUNDEN->Partner
    replace KUNDEN->Strasse2 WITH KUNDEN->Strasse
    replace KUNDEN->Zusatz2 WITH KUNDEN->Zusatz
    replace KUNDEN->land2 WITH KUNDEN->land
    replace KUNDEN->Plz2 WITH KUNDEN->Plz
    replace KUNDEN->Ort2 WITH oGet:Buffer
    KUNDEN->(dbcommit())
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
  endif
RETURN(.t.)



// ** Rabattgruppen *****************************
PROCEDURE RabDisp(Aendern,Sperren,ausArtikelStamm)
LOCAL GetList:={}
LOCAL ob:=4 , li:=19 , re:=64
LOCAL i , rab , rabPreis , feld

  default ausArtikelStamm:=.f.

  if RABATT->RabattGr == PHOENIX_RABATT_GRUPPE .and. ! ausArtikelStamm
    PhoenixRabattDisp(Aendern,Sperren)
    return
  endif

  default ausArtikelStamm:=.f.

  /* Anzeige aus ArtStamm weiter rechts */
  if ausArtikelStamm
    li+=11 ; re+=13
  endif

  @ ob+ 2,li-2 clear to ob+16,re+1
  @ ob+ 2,li-2 to ob+16,re+1

  @ ob+ 3,li say "Rabatt-Gruppe....: " + RABATT->RabattGr
  ob:=ob+5

  if ! ausArtikelStamm // normal Rabattgruppe bearbeiten
    @ ob,li say "  Menge  Rab %            VK"
    ob++
    for i:=1 to 9
      feld:="RABATT->meng"+str(i,1)
      @ ob,li get &feld valid IS_POSITIVE

      feld:="RABATT->rab"+str(i,1)
      @ ob,li+9 get &feld valid IS_POSITIVE

      feld:="RABATT->preis"+str(i,1)
      @ ob,li+16 get &feld valid IS_POSITIVE
      ob++
    next

  else // aus Artikel und falls % Angabe -> andere Anzeige
    @ ob,li say "  Menge  Rab %            VK  Marge %     Diff."

    // Marge ohne Rabatt
    if ARTIKEL->KaPr <> 0
      ob++
      @ ob,li say str(1,7,0)
      @ ob,li+9 say str(0,5,2)
      @ ob,li+16 say str(ARTIKEL->Preis1,12,2)
      qqout( str(ARTIKEL->Preis1 / ARTIKEL->KaPr * 100 - 100 , 7 , 2 ) , "%" )
      qqout(' ' , str(ARTIKEL->Preis1 - ARTIKEL->KaPr , 8 , 2))
    endif

    ob++
    for i:=1 to 9
      feld:="RABATT->meng"+str(i,1)
      @ ob,li get &feld valid IS_POSITIVE

      if &feld > 0

        // "Eingabe" Preis
        if &("RABATT->Preis"+str(i,1)) > 0
          rab:=100 - 100 * &("RABATT->Preis"+str(i,1)) / ARTIKEL->Preis1
          @ ob,li+9 say str(rab,5,2)
          feld:="RABATT->preis"+str(i,1)
          @ ob,li+16 get &feld valid IS_POSITIVE
          rabPreis:=&("RABATT->Preis"+str(i,1))
        else // "Eingabe" Rabatt
          if &("RABATT->Rab"+str(i,1)) > 0
            feld:="RABATT->rab"+str(i,1)
            @ ob,li+9 get &feld valid IS_POSITIVE
            rabPreis:=ARTIKEL->Preis1 - ARTIKEL->Preis1 * &("RABATT->Rab"+str(i,1)) / 100
            @ ob,li+16 say str(rabPreis,12,2)
          else
            rabPreis:=0
          endif
        endif

        // Marge
        if ARTIKEL->KAPR <> 0
          qqout( str(rabPreis / ARTIKEL->KAPR * 100 - 100 , 7 , 2 ) , "%" )
          qqout( ' ' , str( rabPreis - ARTIKEL->KAPR , 8 , 2) )
        endif

      endif

      ob++
    next
  endif

  Standard_disp()
RETURN
/* EOP */



// ** Erl�s-gruppen ***************************************
PROCEDURE ErlDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 14,66
  @ 9,12 to 14,66

  @ 10,14 say "Nummer:   " + ERL_GRUP->Erl_gruppe
  @ 11,14 to 11,64
  @ 10,30 get ERL_GRUP->Text
  @ 12,14 say "Inland    EG    Sonstige"
  @ 13,14 get ERL_GRUP->inland picture "@K 99999"
  @ 13,24 get ERL_GRUP->eg picture "@K 99999"
  @ 13,34 get ERL_GRUP->sonst picture "@K 99999"

  Standard_disp()
RETURN
/* EOP ErlDisp */

// ** Mengeneinheiten *************************************
PROCEDURE EinDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 13,66
  @ 9,12 to 13,66

  @ 10,14 say "Nummer..: " + EINHEIT->ME
  @ 12,14 get EINHEIT->Text
  @ 12,20 get EINHEIT->Kommentar

  @ 10,36 say "Nachkommastellen:"
  @ 12,36 get EINHEIT->Nachkomma valid EINHEIT->Nachkomma <= 3 ;
    when Message("Anzahl Nachkommastellen eingeben.")

  @ 10,54 say "Vielfaches:"
  @ 12,54 get EINHEIT->Vielfach valid EINHEIT->Vielfach $ "JN " picture "!" ;
    when Message("@J@=Artikel m�ssen vielfaches der Menge in der St�ckliste sein.")

  @ 14,12 clear to 16,66
  @ 14,12 to 16,66
  @ 14,14 say "Englisch:"

  @ 15,14 get EINHEIT->E_Text when Message("Bezeichung in Englisch eingeben.")

  Standard_disp()
RETURN
/* EOP EinDisp */


// ** Mehrwertsteuer **************************************
PROCEDURE MwsDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 13,66
  @ 9,12 to 13,66

  @ 10,14 say "Nummer..: " + MWST_KZ->MwstNr
  @ 12,14 get MWST_KZ->MWst valid { |oGet| nachMwstKz( oGet ) }

  Standard_disp()
RETURN
/* EOP */

/** Wird nach Eingabe der MwSt ausgef�hrt */
static function nachMwstKz( oGet )
  if oGet:changed
    if message("MwSt. in offenen ABs anpassen?","JN"," ")=="J"
      if .not. open("AufAus")
        Error(TRY_AGAIN)
      else
        Message("ABs werden aktualisiert.  Bitte warten...")
        loca for AUFAUS->Mwst_kZ == MWST_KZ->MwstNr .and. AUFAUS->erledigt<>"J"
        do while ! AUFAUS->(eof())
          rec_lock(0)
          @ maxrow(),maxcol()-len(AUFAUS->AufNr) say AUFAUS->Aufnr
          repla AUFAUS->Mwst with val(oget:Buffer)
          cont
        enddo
      endif
    endif
  endif
return .t.


// ** Versandarten ***************************************
PROCEDURE VA_Disp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=7

  @ ob,12 clear to ob+3,66
  @ ob,12 to ob+3,66

  @ ob+1,14 say "Nummer: " + VERSART->VersNr
  @ ob+1,46 say "Verpack. Fracht"
  @ ob+2,14 get VERSART->Text
  @ ob+2,50 get VERSART->verpack picture "!" valid VERSART->verpack $"JN"
  @ ob+2,57 get VERSART->fracht picture "!" valid VERSART->Fracht $"JN"

  // Englische Texte
  ob += 4
  @ ob,12 clear to ob+3,66
  @ ob,12 to ob+3,66
  @ ob,14 say "Englisch:"
  @ ob+2,14 get VERSART->E_Text


  Standard_disp()
RETURN
/* EOP VerDisp */



// ** Verk�ufer ***************************************
PROCEDURE Vk_Disp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 16,66
  @ 9,12 to 16,66

  @ 10,14 say "Nummer..: " + VERKAUF->VerkNr
  @ 12,14 get VERKAUF->Text
  @ 13,14 get VERKAUF->adr1
  @ 14,14 get VERKAUF->adr2
  @ 15,14 say "Konto:"
  @ 15,25 get VERKAUF->konto
  @ 15,45 say "Mwst:" get VERKAUF->Mwst_Kz

  Standard_disp()
RETURN
/* EOP Vk_Disp */


// ** Liefertermine *************************************
PROCEDURE TerDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=10

  @ ob,12 clear to ob+3,65
  @ ob,12 to ob+3,65

  @ ob+1,14 say "Nummer: " + LIEFTERM->KW
  @ ob+2,14 get LIEFTERM->Text


  // Englische Texte
  ob += 4
  @ ob,12 clear to ob+3,65
  @ ob,12 to ob+3,65
  @ ob,14 say "Englisch:"

  @ ob+2,14 get LIEFTERM->E_Text

  Standard_disp()
RETURN
/* EOP Vk_Disp */


// ** Standort *************************************
PROCEDURE StaDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 7,17 clear to 18,68
  @ 7,17 to 18,68

  @ 8,18 say "Nummer...: "+STANDORT->StandNr

  @ 9,18 to 9,67
  @ 10,18 say "Kurz.Bez:" get STANDORT->KurzBez
  @ 12,18 say "Adresse: " get STANDORT->Adr1
  @ 13,18 say "         " get STANDORT->Adr2
  @ 14,18 say "         " get STANDORT->Adr3
  @ 15,18 say "         " get STANDORT->Adr4

  @ 17,18 say "KundenNr:" get STANDORT->KundNr PICTURE KDNR_PICT


  Standard_disp()
RETURN
/* EOP StaDisp */



// ** Reparatur-Stamm neu **************************
PROCEDURE RStDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 11,2 clear to 15,78
  @ 11,2 to 15,78

  @ 12,5 say "Nummer  : " + REPStamm->RepStNr
  @ 14,5 get REPStamm->Text

  Standard_disp()
RETURN
/* EOP RstDisp */

// ** Gerat *************************************
PROCEDURE GerDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 7,17 clear to 17,62
  @ 7,17 to 17,62

  @ 8,18 say "Nummer...: "
  QQOut( GERAT->RepGerNr)
  @ 9,18 to 9,61
  @ 10,18 say "Bezeichnung..........:" get GERAT->bezeichn
  @ 12,18 say "Art.Nr...............: "+ GERAT->artnr
  @ 14,18 say "Status...............:" get GERAT->Status
  @ 16,18 say "n�chste Etiketten-Nr.:" get GERAT->Eti_nr

  Standard_disp()
RETURN
/* EOP GerDisp */

/* Ger�tedisp - Aufruf �ber F10 (Etikett) */
PROCEDURE GerDisp3()
  if rec_lock(5)
    set key K_F10 to
    GerDisp2(.t.)
    dbcommit()
    dbunlock()
    set key K_F10 to GerDisp3()
  endif
RETURN


/* Ger�tedisp - Etiketten */
PROCEDURE GerDisp2(Aendern,Sperren)
LOCAL GetList:={}

  @ 7,17 clear to 17,62
  @ 7,17 to 17,62

  @ 8,18 say "Nummer...: "
  QQOut( GERAT->RepGerNr)
  @ 9,18 to 9,61
  @ 10,18 say "Bezeichnung..........:" get GERAT->bezeichn
  @ 12,18 say "Art.Nr...............:" get GERAT->artnr picture "@!"
  @ 14,18 say "Monat/Jahr...........:" get M->jahr picture "99.99"
  @ 16,18 say "n�chste Etiketten-Nr.:" get GERAT->Eti_nr

  Standard_disp()
RETURN



// ** Empf�nger ***********************************
PROCEDURE EmpDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,12 clear to 14,66
  @ 10,12 to 14,66

  @ 11,14 say "Nummer..: " + EMPFAENG->EmpfNr
  @ 13,14 get EMPFAENG->Bez

  Standard_disp()
RETURN
/* EOP StaDisp */

// ** Rep. Kunden *********************************
PROCEDURE RKdDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL Ob,li,re,unt,aktSatz:=recno()

  re=73
  li=15
  ob=0
  unt=21
  @ ob+ 2,li-2 clear to ob+unt,re
  @ ob+ 2,li-2 to ob+unt,re

  @ ob+ 3,li say "Kunden-Nr..........: " +REPKUND->RepKdNr
  @ ob+ 3,li+35 say "Alt: " + REPKUND->KdNrNeu
  @ ob+ 5,li say "Kurzname....:" get REPKUND->Kurz PICTURE "@!"
  @ ob+ 4,li to ob+4,re-1

  @ ob+ 6,li say "              "+space(24)+"!"
  @ ob+ 7,li say "Adresse.....:" get REPKUND->Adr1
  @ ob+ 8,li say "             " get REPKUND->Adr2
  @ ob+ 9,li say "             " get REPKUND->Adr3
  @ ob+10,li say "             " get REPKUND->Adr4
  @ ob+11,li say "Versand-Adr.:" get REPKUND->VersandKz
  QQOut( space(23)+"!" )

  @ ob+14,li say "Telefon     :" get REPKUND->TelNr
  @ ob+15,li say "Fax  -Nummer:" get REPKUND->FaxNr
  @ ob+16,li say "Ident-Nummer:" get REPKUND->IdentNr

  @ ob+18,li say "Standort    :" get REPKUND->StandOrt
  @ ob+19,li say "Ohne KV     :" get REPKUND->ohne_KV PICTURE "!"
  @ ob+20,li say "Gesperrt    :" get REPKUND->Gesperrt PICTURE "!"

  Standard_disp()
RETURN
/* EOP StaDisp */



// ** Versand (repa) *****************************
PROCEDURE RVsDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,12 clear to 14,66
  @ 10,12 to 14,66

  @ 11,14 say "Nummer..: " + VERSAND->RepVerNr
  @ 13,14 get VERSAND->Text

  Standard_disp()
RETURN
/* EOP StaDisp */


/* Menu-Aufrufe */
PROCEDURE AfrDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 9,12 clear to 13,66

  @ 10,14 say "Name..........:  " + AUFRUF->ProgName + " - " + AUFRUF->ProgNr
  @ 11,14 say "Bezeichnung...: " get AUFRUF->Bez
  @ 12,14 say "Anzahl Aufrufe: " + str(AUFRUF->Anzahl)
  @ 9,12 to 13,66

  Standard_disp()
RETURN
/* EOP VarDisp */

/* L�nder-Kennungen */
PROCEDURE LanDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 8,2 clear to 20,76
  @ 8,2 to 20,76

  @ 09,4 say "K�rzel..........:  " + LAND->LandKZ
  @ 10,4 say "Name (Deustch)  : " get LAND->Name
  @ 11,4 say "Name (Englisch) : " get LAND->E_Name

  @ 13,4 say "Sprache.........: " get LAND->Sprache picture "!";
    when;
    message("Sprache eingeben.   @D@eutsch, @E@nglisch oder  @F@ranz�sisch");
    valid LAND->Sprache$"DEF"
  @ 14,4 say "EU-Mitglied.....: " get LAND->EU picture "!" ;
    when LAND->LandKZ<>"DE" .and. message("Land ist EU Mitglied?.   @J@/@N@") ;
    valid { |oGet| afterEU( oGet ) }

  @ 16,4 say "EFTA-Land.......: " get LAND->EFTA picture "!" ;
    when message("Land ist ein EFTA-Land?  @J@/@N@");
    valid LAND->EFTA $ "JN"
  @ 17,4 say "Pr�ferenzland...: " get LAND->LLE picture "!";
    when message("Artikel aus diesem Land sollen in der Langzeitlieferantenerkl�rung erscheinen?  "+;
    "@J@/@N@") valid LAND->LLE $ "JN"
  @ 18,4 say "Zusatztext (LLE): " get LAND->LLEText picture "@S52" ;
    when message("Zusatztext in Deutsch f�r Langzeitlieferantenerkl�rung eingeben.  @J@/@N@")
  @ 19,4 say "Zusatztext (eng): " get LAND->E_LLEText picture "@S52" ;
    when message("Zusatztext in Englisch f�r Langzeitlieferantenerkl�rung eingeben.  @J@/@N@")

  Standard_disp()
RETURN
/* EOP VarDisp */

/** Wird nach Eingabe des EU-Status ausgef�hrt */
static function afterEU( oGet )
LOCAL isLocked

  if oGet:changed
    if ! LAND->EU$"JN "
      return .f.
    endif
    // passe alle Kunden an
    Message("Kunden werden aktualisiert.  Bitte warten....")
    if ! open("Kunden")
      Error(TRY_AGAIN)
      select Land
      return .f.
    endif

    Umgebung( WRITE )

    locate for KUNDEN->Land2 == LAND->LandKz
    do while ! KUNDEN->(eof())
      if ! (isLocked:=isLocked())
        rec_lock( 0 , recno() ) // additive
      endif
      nachKundLand2( oGet )
      dbcommit()
      if ! isLocked
        dbRunlock( recno() )
      endif
      cont
    enddo

    Umgebung( LOAD )

  endif
  select Land

return .t.
/** eof */


/* Function nachKundLand1()
*
* wird nach Eingabe der L�nderkennung beim Kunden (Postadresse) ausgef�hrt
* setzt MwstKZ und EU-KZ
*/
static FUNCTION nachKundLand1(oGet)
  if oGet:changed

    // pr�fe auf DATEV-Nummern Kreislauf - Deutschland oder Drittland
    if ! checkDatevNr( KUNDEN->KundNr , oGet:buffer )
      return .f.
    endif

    // seot 20210704 doch immer
    // if empty(KUNDEN->EG) // nur bei Neuanlage,notwendig falls mit page down beendet
    assignMwst()
    // endif

    oget:assign()
    LAND->(dbseek(left(KUNDEN->Land,2)))
    replace KUNDEN->Sprache with LAND->Sprache
    if empty(KUNDEN->Land2)
      replace KUNDEN->Land2 with KUNDEN->Land
      replace KUNDEN->Sprache2 with LAND->Sprache
    endif
    replace KUNDEN->IdentNr with ""
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif
return .t.
/** eof */

/* Function nachKundLand2()
*
* wird nach Eingabe der L�nderkennung beim Kunden ausgef�hrt
* setzt MwstKZ und EU-KZ
*/
static FUNCTION nachKundLand2(oGet)
  if oGet:changed

    // pr�fe auf DATEV-Nummern Kreislauf - Deutschland oder Drittland
    if ! checkDatevNr( KUNDEN->KundNr , oGet:buffer )
      return .f.
    endif

    assignMwst()

    if oGet!=NIL .and. oGet:changed
      oget:assign()
      setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
      LAND->(dbseek(left(KUNDEN->Land2,2)))
      replace KUNDEN->Sprache2 with LAND->Sprache
    endif

  endif
return .t.
/** eof */

STATIC PROCEDURE assignMwSt()
  if LAND->LandKZ=="DE"
    if empty(KUNDEN->MWST_KZ)
      replace KUNDEN->MWST_KZ with "1"
    elseif KUNDEN->MWST_KZ <> "1"
      if Message("Deutscher Kunde mit abweichender MwSt.  Sind Sie sicher? (@J@/@N@)","JN"," ")<>"J"
        replace KUNDEN->MWST_KZ with "1"
      endif
    endif
    replace KUNDEN->EG with "D"
  else
    replace KUNDEN->MWST_KZ with "0"
    if LAND->EU == "J"
      replace KUNDEN->EG with "J"
    else
      replace KUNDEN->EG with "N"
    endif
  endif
return
/** eop */

/* Function nachKundLandS()
*
* wird nach Eingabe der L�nderkennung beim Kunden (Sammelstelle) ausgef�hrt
*/
FUNCTION nachKundLandS(oGet)
  if oGet:changed
    oget:assign()
    LAND->(dbseek(left(KUNDEN->S_Land,2)))
    replace KUNDEN->S_Sprache with LAND->Sprache
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif
return .t.
/** eof */

/** Eingabe der Sammellager-Adresse */
Procedure kunSammelDisp( edit )
LOCAL GetList:={}
LOCAL li:=20 , ob:=10
LOCAL orgAltF8:=SetKey( K_F8 , { || copyVersAdr() } )

  Umgebung( WRITE )
  setcolor(COLWIN)

  IF REC_LOCK(5)
    Message("Adresse Sammelstelle eingeben.   @F8@=Versandadresse kopieren")
    Fenster(ob,li,ob+8,li+44,"Sammelstelle:")

    @ ob+8,li+14 say ""
    @ ob+ 2,li+2 get KUNDEN->S_Name picture"@K"
    @ ob+ 3,li+2 get KUNDEN->S_Partner picture"@K"
    @ ob+ 4,li+2 get KUNDEN->S_Strasse picture"@K"
    @ ob+ 5,li+2 get KUNDEN->S_Zusatz picture"@K"
    @ ob+ 6,li+2 get KUNDEN->S_land picture "@!" ;
      valid { |oGet| empty(KUNDEN->S_Name) .or. (check(oGet,"Land",.f.,.f.) .and. nachKundLandS(oGet))}
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

    @ ob+ 6,li+5 get KUNDEN->S_Plz picture"@K"
    @ ob+ 6,li+13 get KUNDEN->S_Ort picture"@K"
    LAND->(dbseek(left(KUNDEN->S_Land,2)))
    @ ob+ 7,li+2 say trim(LAND->Name)

    @ ob+ 7,li+22 say "Sprache:" get KUNDEN->S_Sprache picture"!" ;
      valid KUNDEN->S_Sprache $ "ED" .and. message() ;
      when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")

    if edit
      read
    else
      Message("Bitte Taste dr�cken.","@")
    endif
    SetKey( K_F8 , orgAltF8)
  endif
  Umgebung( LOAD )
return
/** eop */

/** Eingabe der elaternative Rechnungsadresse
  * edit Parameter:
  * 0 = editieren / read
  * 1 = anzeigen mit Taste dr�cken
  * 2 = anzeigen ohne Taste und clearscreen
  */
Procedure kunAlternativDisp( edit , Datei )
LOCAL GetList:={}
LOCAL li:=20 , ob:=10
LOCAL orgAltF8:=SetKey( K_F8 , { || copyVersAdr2() } )
  default datei:="KUNDEN"

  IF edit <> 0 .or. REC_LOCK(5)

    Umgebung( WRITE )
    setcolor(COLWIN)

    Message("Alternative Rechnungs-Adresse eingeben.   @F8@=Versandadresse kopieren")
    Fenster(ob,li,ob+8,li+44,"Alternative Rechnungsadresse:")

    @ ob+8,li+14 say ""
    if DATEI=="KUNDEN"
      @ ob+ 2,li+2 get KUNDEN->A_Name picture"@K"
      @ ob+ 3,li+2 get KUNDEN->A_Partner picture"@K"
      @ ob+ 4,li+2 get KUNDEN->A_Strasse picture"@K"
      @ ob+ 5,li+2 get KUNDEN->A_Zusatz picture"@K"
      @ ob+ 6,li+2 get KUNDEN->A_Land picture "@!" ;
        vvalid { |oGet| empty(KUNDEN->A_Name) .or. check(oGet,"Land",.f.,.f.)}

      @ ob+ 6,li+5 get KUNDEN->A_Plz picture"@K"
      @ ob+ 6,li+13 get KUNDEN->A_Ort picture"@K"
      LAND->(dbseek(left(KUNDEN->A_Land,2)))
      @ ob+ 7,li+2 say trim(LAND->Name)
    else
      @ ob+ 2,li+2 get RECHAUS->A_Name picture"@K"
      @ ob+ 3,li+2 get RECHAUS->A_Partner picture"@K"
      @ ob+ 4,li+2 get RECHAUS->A_Strasse picture"@K"
      @ ob+ 5,li+2 get RECHAUS->A_Zusatz picture"@K"
      @ ob+ 6,li+2 get RECHAUS->A_Land picture "@!" ;
        vvalid { |oGet| empty(RECHAUS->A_Name) .or. check(oGet,"Land",.f.,.f.)}

      @ ob+ 6,li+5 get RECHAUS->A_Plz picture"@K"
      @ ob+ 6,li+13 get RECHAUS->A_Ort picture"@K"
      LAND->(dbseek(left(RECHAUS->A_Land,2)))
      @ ob+ 7,li+2 say trim(LAND->Name)
    endif

    switch edit
    case 0
      read
      Umgebung( LOAD )
      exit
    case 1
      Message("Bitte Taste dr�cken.","@")
      Umgebung( LOAD )
      exit
    case 2
      setcolor(COLNOR)
      Umgebung( DISMISS_NEXT )
      exit
    endswitch

    SetKey( K_F8 , orgAltF8)
  endif

return
/** eop */

/** Kopiert beim aktuellen Kunden die Versandadresse �ber die Sammelstelle Adresse */
FUNCTION copyVersAdr()

  if Message("Versandadresse kopieren?  (@J@/@N@)","JN","N")=="J"
    replace KUNDEN->S_NAME with KUNDEN->NAME2
    replace KUNDEN->S_STRASSE with KUNDEN->STRASSE2
    replace KUNDEN->S_LAND with KUNDEN->LAND2
    replace KUNDEN->S_PLZ with KUNDEN->PLZ2
    replace KUNDEN->S_ORT with KUNDEN->ORT2
    replace KUNDEN->S_PARTNER with KUNDEN->PARTNER2
    replace KUNDEN->S_Zusatz with KUNDEN->Zusatz2
    keyboard chr(K_PGDN)+chr(K_F5) // redisplay sammelstelle fenster
  endif
return .t.
/** eof */

/** Kopiert beim aktuellen Kunden die Versandadresse �ber die Alternative Rechn. Adresse */
FUNCTION copyVersAdr2()

  if Message("Versandadresse kopieren?  (@J@/@N@)","JN","N")=="J"
    replace KUNDEN->A_NAME with KUNDEN->NAME2
    replace KUNDEN->A_STRASSE with KUNDEN->STRASSE2
    replace KUNDEN->A_LAND with KUNDEN->LAND2
    replace KUNDEN->A_PLZ with KUNDEN->PLZ2
    replace KUNDEN->A_ORT with KUNDEN->ORT2
    replace KUNDEN->A_PARTNER with KUNDEN->PARTNER2
    replace KUNDEN->A_Zusatz with KUNDEN->Zusatz2
    keyboard chr(K_PGDN)+chr(K_F6) // redisplay akt. fenster - FIXME: not working
  endif
return .t.
/** eof */

/** pr�ft ob alle eingegeben Characters f�r die SEPA XML Schnittstelle zugelassen sind. */
FUNCTION checkSepaValid(oGet)
LOCAL objErr,tempVal

  if oget:changed()
    BEGIN SEQUENCE
      checkSepaCharacters(oGet:buffer,,"&") // $ allowed here!
    RECOVER USING objErr
      tempVal:=getErrorText(objErr)
      Error(left(tempVal,at(MY_CR+MY_LF,tempVal)-1))
      return .f.
    END SEQUENCE
  endif

return .t.
/** eof */

/* Innerbetr. Auftr�ge */
PROCEDURE InnDisp(Aendern,Sperren)
LOCAL GetList:={},artText
LOCAL ob:=4,li:=10

  select Inner

  @ ob-1,li-2 clear to ob+13,li+60
  @ ob-1,li-2 to ob+13,li+60

  @ ob ,li say "Innerbetr. Nr.: " + INNER->InLfdNr
  if INNER->Erledigt=="J"
    @ ob,li+28 say " (erledigt)      " color "R/"+getBackColor()
  elseif INNER->gedruckt $ INNER_DRUCK_NEU + INNER_DRUCK_LEER
    @ ob,li+28 say " (nicht gedruckt)" color "R/"+getBackColor()
  elseif INNER->gedruckt $ INNER_DRUCK_NOCHMAL
    @ ob,li+28 say " (ge�ndert, nicht gedruckt)" color "R/"+getBackColor()
  elseif INNER->gedruckt $ INNER_DRUCK_ALT
    // @ ob,li+28 say " (Auftrag vor Umst.)" color "R/"+getBackColor()
  endif
  @ ob ,li+51 say INNER->AufDat
  @ ob+1,li to ob+1,li+58
  @ ob+2 ,li say "Artikel-Nr....: " + INNER->ArtNr

  switch INNER->Art
  case "D"
    artText:="Dienstleistung"
    exit
  case "F"
    artText:="Fert.-Artikel "
    exit
  case "M"
    artText:="Montage-Artikel "
    exit
  case "R"
    artText:="Reservierung Lagerbestand"
    exit
  case "X"
    artText:="X-Artikel     "
    exit
  otherwise
    artText:="Art: "+INNER->Art
    if ! INNER->(eof())
      troubleEmail(INNER->Art+" unbekannte Art in Inner.dbf: "+INNER->InLfdNr)
    endif
    exit
  endswitch
  @ ob+3 ,li say artText COLOR "N+/"+getBackColor()

  @ ob+2 ,li+28 say INNER->Bez1
  @ ob+3 ,li+28 say INNER->Bez2

  @ ob+5 ,li say "AB-Nr.........: " + INNER->AufNr
  @ ob+6 ,li say "Mappen-Nr.....: " + dispInnerNr(INNER->InnerNr, INNER->ArbGang)
  @ ob+7 ,li say "Fert.KW.......: " + INNER->Fert_KW
  @ ob+8 ,li say "Lief.KW.......: " + INNER->Lief_KW
  @ ob+9 ,li say "Fert.Dauer....: " + getStdTagText(INNER->FertDauer, STDTAG_TINY)
  @ ob+10,li say "Etikett. Tafel: " + str( INNER->EtiAnz , 1)


  @ ob+5 ,li+28 say "Menge AB........: " + str(INNER->MengeAB,9,2)
  @ ob+6 ,li+28 say "Menge gesamt....: " + str(INNER->Menge,9,2)
  @ ob+7 ,li+28 say "Produziert......: " + str(INNER->GeliefGes,9,2)
  @ ob+8 ,li+28 say "Ausschu�........: " + str(INNER->Ausschuss,9,2)
  @ ob+9 ,li+28 say "Rest............: " + str(INNER->Menge-INNER->GeliefGes,9,2)
  @ ob+10,li+28 say "Etikett. Stechk.: " + str( INNER->EtiAnz2,6)

  if ! empty(INNER->Werkzeug)
    @ ob+11,li say "Wkz-Nr........: "+INNER->Werkzeug
    @ ob+11,li+28 say "Nutzen......: " + str(INNER->Nutzen1,2)+"/"+str(INNER->Nutzen2,2)
  endif
  // @ ob+12,li+51 say "Tiefe: " + alltrim(str(INNER->Tiefe))
  @ ob+12,li say "Grund.........: " + INNER->Grund

  @ ob+14,li clear to ob+14,li+70

  Standard_disp()
RETURN
/* EOP */

// ** Warennummern f�r IntraStat. Meldung ans Bundesamt */
PROCEDURE IntraDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,6 clear to 17,74
  @ 10,6 to 17,74

  @ 11,8 say "Waren-Nummer: " + INTRASTAT->WarenNr
  @ 13,8 get INTRASTAT->Text1
  @ 14,8 get INTRASTAT->Text2
  @ 15,8 get INTRASTAT->Text3
  @ 16,8 get INTRASTAT->Text4

  Standard_disp()
RETURN
/* EOP StaDisp */

// ** Email-Adressen f�r Kunden *****************************
PROCEDURE EmailDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,6 clear to 15,74
  @ 10,6 to 15,74

  @ 11,8 say "Kunden-Nummer: " + EMAIL->KundNr + " " + KUNDEN->Kurzname
  @ 13,8 say "Art..........: " get EMAIL->art
  @ 14,8 say "Email-Adresse: " get EMAIL->email picture "@S50" valid {|oget| isValidEmail(oget)}

  Standard_disp()
RETURN
/* EOP StaDisp */

// ** Farben f�r Darstellung im Gant Chart *****************************
PROCEDURE FarbDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,6 clear to 16,74
  @ 10,6 to 16,74

  @ 11,8 say "Farbe............: " + FARBE->Text
  @ 13,8 say "Hey-Wert (intern):" get FARBE->HexVal

  Standard_disp()
RETURN
/* EOP StaDisp */

/** Gibt die Mwst % des Kunden am BS aus */
static function mwstAusgabe()
  if lastkey() <> K_UP
    MWST_KZ->(dbseek(KUNDEN->Mwst_Kz))
    qqout(" "+alltrim(str(MWST_KZ->MwSt,5,2)+"%"))
  endif
return .t.
/** eof */

// ** Rabattgruppen *****************************
PROCEDURE PhoenixRabattDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4 , li:=19 , re:=64 , unt:=21
LOCAL i , Feld


  @ ob+ 2,li-2 clear to ob+15,re+1
  @ ob+ 2,li-2 to ob+15,re+1

  @ ob+ 3,li say "Rabatt-Gruppe....: " + RABATT->RabattGr
  ob:=ob+5

  ob++
  for i:=1 to 9
    @ ob,li say "Stufe "+str(i,1)

    feld:="RABATT->rab"+str(i,1)
    @ ob,li+9 get &feld valid IS_POSITIVE picture "@Z"

    ob++
  next


  Standard_disp()
RETURN
/* EOP */

static function copyKdAdr(p1,oGet)
LOCAL target:=oGet:name + "2"
  ignore p1
  replace &(target) with oget:buffer
  setCargo(oGet,CARGO_DISP_GETLIST,.t.)
  keyboard chr(K_RETURN)
return .t.
/** eof */

/** Return list f Ansprechpartners, min length 2 chars, max length 58 chars */
static function getAnsprechPartners()
LOCAL result:="", tempVal

  KDKONTAKT->(dbseek(Kunden->KundNr))
  do while KDKONTAKT->KundNr == Kunden->KundNr .and. ! KDKONTAKT->(eof())
    for each tempval in {"Ansprech" }
      if ! empty(&("KDKONTAKT->"+tempval))
        result+=alltrim( &("KDKONTAKT->"+tempval)) + ", "
      endif
    next
    KDKONTAKT->(dbskip())
  enddo

  if right(result,2)==", "
    result:=left(result,len(result)-2)
  endif
  result:=trim(result)
  if len(result) > 58
    result:=left(result+space(58), 58)
  endif
  if len(result) < 2
    result:=left(result+space(2), 2)
  endif
return result
/** eof */


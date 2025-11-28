/* Modul: disp3.prg
*
* enthält Stammdaten-Masken, siehe auch disp2.prg , disp3.prg
*/

#include "Miki.ch"

#command Standard_disp() => ;
  if Aendern ;
  ; Sperr_Reader( GetList , Sperren ) ;
  ; GetList:={} ;
  ; dbcommit() ;
  ;else ;
  ; Sperr_Reader(GetList,.f.,"AUSGABE") ;
  ; GetList:={} ;
  ;endif




// ** Produktion (repa) *****************************
PROCEDURE ProDisp(Aendern,Sperren)
LOCAL ob:=5, li:=15, GetList:={}
LOCAL te,i
  if select("Empfaeng")==0
    open("Empfaeng")
  endif
  if select("Repkund")==0
    open("Repkund")
  endif
  if select("Status")==0
    open("Status")
  endif
  if select("ProdText")==0
    open("ProdText")
  endif
  select Prod

  @ ob,li-2 clear to ob+13,li+54
  @ ob,li-2 to ob+13,li+54

  STATUS->(dbseek(subRepArtikel(PROD->ArtNr)+PROD->Status))
  @ ob+1,li say "Typ..............: "+PROD->Typ
  @ ob+1,li+30 say STATUS->Kurzbez
  @ ob+2,li+1 to ob+2,li+50-1
  @ ob+3,li say "Gerätenummer.....: "+PROD->GeratNr
  @ ob+4,li say "Bezeichnung......:" get PROD->bezeichn
  @ ob+5,li say "Art.Nr...........: "+ PROD->artnr picture "@!"
  @ ob+5,li+30 say "Status.....: " + PROD->Status
  @ ob+7,li say "ProduktionsDatum.:" get PROD->ProdDat
  @ ob+8,li say "Liefer-Datum.....:" get PROD->LiefDat
  @ ob+9,li say "Anzahl Rep.......:" get PROD->AnzRep
  @ ob+9,li+30 say "letzte Rep.:" get PROD->RepDat
  @ ob+10,li say "Kunde............:" get PROD->RepKdNr picture REPKDNR_PICT;
    valid { |oGet| check(oGet,"RepKund",.t.) }
  // @ ob+10,li+25 say REPKUND->Kurz
  @ ob+11,li say "Empfänger........:" get PROD->Empfaeng PICTURE "@!";
    valid { |oGet| check(oGet,"Empfaeng",.t.) }
  @ ob+11,li+30 say EMPFAENG->Bez
  @ ob+12,li say "Text.............:" get PROD->ProdTextNr

  if ! empty(PROD->ProdTextNr)
    PRODTEXT->(dbseek(PROD->ProdTextNr))
    te:=memotran(PRODTEXT->Text,"@","@") // ersetzt Chr(13) durch @
    for i:=1 to 3
      if at("@",te) > 0
        @ ob+14+i,li say left(te,at("@",te)-1)
      else
        @ ob+14+i,li say te
        te:=""
      endif
      te:=substr(te,at("@",te)+1)
    next
    @ 18,13 to 22,69
  endif

  Standard_disp()

RETURN
/* EOP ProDisp */

  // ** Produktion-Text (repa) *****************************
// PROCEDURE PTeDisp(Aendern/*,Sperren*/)
PROCEDURE PTeDisp(Aendern)
LOCAL ob:=5, li:=15, GetList:={}
LOCAL te,i

  @ ob,li-2 clear to ob+17,li+54
  @ ob,li-2 to ob+17,li+54

  @ ob+1,li say "Nr..: "+PRODTEXT->ProdTextNr
  @ ob+2,li to ob+2,li+52

  if Aendern
    Message("@ESC@=Ende")
    SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
    te:=MEMOEDIT(PRODTEXT->Text,ob+3,li,21,65, .t.)
    Set Key K_ESC to
    replace PRODTEXT->Text with Te
  else
    te:=memotran(PRODTEXT->Text,"@","@") // ersetzt Chr(13) durch @
    for i:=1 to 12
      if at("@",te) > 0
        @ ob+2+i,li say left(te,at("@",te)-1)
      else
        @ ob+2+i,li say te
        te:=""
        exit
      endif
      te:=substr(te,at("@",te)+1)
    next
  endif


RETURN
/* EOP ProDisp */


// ** Kosten (repa) *****************************
PROCEDURE KosDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 10,12 clear to 15,66
  @ 10,12 to 15,66

  @ 11,14 say "Nummer.............: " + KOSTEN->RepKstNr
  @ 12,14 say "Text...............:" get KOSTEN->Text
  @ 13,14 say "Pauschale..........:" get KOSTEN->Pauschal
  @ 14,14 say "R klieferung (J/N):" get KOSTEN->zurueck PICTURE "!" valid KOSTEN->zurueck $ "JN"

  Standard_disp()
RETURN
/* EOP StaDisp */



// ** Login Benutzer ***************************
PROCEDURE LogDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=1 , li:=2 , re:=78 , unt:=23

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Kürzel: '+LOGIN->Kurzel
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li say 'Name..................:' get LOGIN->Name
  @ ob+4 ,li say 'Stundenlohn...........:' get LOGIN->StdLohn
  @ ob+5 ,li say 'Kostenstelle..........:' get LOGIN->Kostenst;
    valid { |oGet| check(oGet,"KstStamm") }
  @ ob+6 ,li say 'Personalnummer........:' get LOGIN->PersNr
  @ ob+6 ,li+30 say 'Telefon:' get LOGIN->Telefon
  @ ob+7 ,li say 'EMail-Adresse.........:' get LOGIN->EMail picture "@S50"


  @ ob+08,li-1 to ob+08,re-1
  @ ob+09,li say 'Fakturierung..........:' get LOGIN->Fakt picture "!" valid LOGIN->Fakt$"JN"
  @ ob+10,li say 'Bank..................:' get LOGIN->Bank picture "!" valid LOGIN->Bank$"JN"
  @ ob+11,li say 'Drucken...............:' get LOGIN->Drucken picture "!" valid LOGIN->Drucken$"JN"
  @ ob+12,li say 'DSGVO Zugriff erlaubt :' get LOGIN->StammDat picture "!";
    valid LOGIN->StammDat $ "JN"
  @ ob+13,li say 'System-Daten ändern...:' get LOGIN->SysMenu picture "!" valid LOGIN->SysMenu$"JN"
  @ ob+14,li say 'Stammdaten anzeigen...:' get LOGIN->ZeigeDat picture "!";
    valid LOGIN->ZeigeDat$"JN"
  @ ob+15,li say 'Artikel Bestand ändern:' get LOGIN->ArtLagBest picture "!";
    valid LOGIN->ArtLagBest$"JN"
  @ ob+16,li say 'Artikel EK ändern.....:' get LOGIN->EK_Aend picture "!" valid LOGIN->EK_Aend$"JN"
  @ ob+17,li say 'Artikel VK ändern.....:' get LOGIN->VK_Aend picture "!" valid LOGIN->VK_Aend$"JN"
  @ ob+18,li say 'Artikel K-Lager ändern:' get LOGIN->KLagKd picture "!" valid LOGIN->KLagKd$"JN"
  @ ob+19,li say 'Artikel Gewicht ändern:' get LOGIN->Gewicht picture "!" valid LOGIN->KLagKd$"JN"
  @ ob+20,li say 'Artikel Text ändern...:' get LOGIN->ArtikelArt picture "!";
    valid LOGIN->ArtikelArt$"JN"
  @ ob+21,li say 'Artikel anlegen.......:' get LOGIN->ArtikelAnl picture "!";
    valid LOGIN->ArtikelAnl$"JN"

  @ ob+09,li+28 say 'Inner.Aufträge.:' get LOGIN->BestellVor picture "!";
    valid LOGIN->BestellVor $ "JN"
  @ ob+10,li+28 say 'Mat. Ein-/Ausg.:' get LOGIN->MatEinAusg picture "!" ;
    valid LOGIN->MatEinAusg$"JN"
  @ ob+11,li+28 say 'Intrastat-Nr...:' get LOGIN->Intrastat picture "!" ;
    valid LOGIN->Intrastat $ "JN"

  @ ob+13,li+28 say 'Stückliste bearb.' color COLINV
  @ ob+14,li+28 say 'Material.......:' get LOGIN->STK_Mat picture "!" valid LOGIN->Stk_Mat$"JN"
  @ ob+15,li+28 say 'Werkzeug.......:' get LOGIN->Stk_Wkz picture "!" valid LOGIN->STK_Wkz$"JN"
  @ ob+16,li+28 say 'Instruktionen..:' get LOGIN->Stk_Ins picture "!" valid LOGIN->Stk_Ins$"JN"
  @ ob+17,li+28 say 'Zeiten.........:' get LOGIN->STK_Zeit picture "!" valid LOGIN->Stk_Zeit$"JN"

  @ ob+19,li+28 say 'Listen' color COLINV
  @ ob+20,li+28 say 'Größe speichern:' get LOGIN->SaveSize picture "!" valid LOGIN->SaveSize$"JN"
  @ ob+21,Li+28 say 'Pos. speichern.:' get LOGIN->SavePos picture "!" valid LOGIN->SavePos$"JN"

  @ ob+09,li+50 say 'Nachkalk. umgehen....:' get LOGIN->IgnoreNK picture "!";
    valid LOGIN->IgnoreNK$"JN"
  @ ob+10,li+50 say 'Nur Auskunft.........:' get LOGIN->NurAusk picture "!";
    valid LOGIN->NurAusk$"JN"
  @ ob+11,li+50 say 'Etiketten drucken....:' get LOGIN->Etikett picture "!";
    valid LOGIN->Etikett$"JN"
  @ ob+12,li+50 say 'Engl. Texte ändern...:' get LOGIN->Edit_Engl picture "!";
    valid LOGIN->Edit_Engl$"JN" when Message()
  @ ob+13,li+50 say 'Material-Bedarf......:' get LOGIN->MatMenu picture "!";
    valid LOGIN->MatMenu $ "JN"
  @ ob+14,li+50 say 'Nietgeräte Produktion:' get LOGIN->NietGerat picture "!";
    valid LOGIN->NietGerat $ "JN"
  @ ob+15,li+50 say 'Werkzeug anle./ändern:' get LOGIN->Werkzeug picture "!";
    valid LOGIN->Werkzeug$"JN"


  Standard_disp()
RETURN
/* EOP StaDisp */

// ** aktuelle Login des akt. Benutzers ***************************
PROCEDURE AktLoginDisp()
LOCAL ob:=5,li:=20,unt:=18,re:=64
LOCAL l, memo:=""

  Umgebung( WRITE )

  setcolor(COLWIN)

  for each l in LoginDispatcher():new():getLogins(LOGIN->Kurzel)
    memo += l:toInfoString() + MY_CR+MY_LF
  next

  Message(ARROW_UP+ARROW_DOWN+"      @ESC@=Ende")
  Fenster(ob,li,unt,re , "Aktuelle Logins")
  MyMemoEdit( memo , ob + 1,li + 2,unt - 1,re - 1 , .f. )

  Umgebung( LOAD )

RETURN
/* EOP StaDisp */



// ** BEmerkungen Reparaturen ******************
PROCEDURE KdBDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=6 , li:=2 , re:=78 , unt:=12

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Bemerkungs-K zel.....: ' + KD_BEMER->Kd_Bem_Nr

  @ ob+3 ,li say 'Bemerkung:'
  @ ob+4 ,li get KD_BEMER->Text

  Standard_disp()
RETURN
/* EOP BemDisp */

/* letzte Stelle Art.Nr bei Nietgeraeten */
PROCEDURE LtnDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=6 , li:=12 , re:=68 , unt:=9

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Letzte Stelle: '+LETZTENI->LetzteNi
  @ ob+2 ,li say 'Text.........:' get LETZTENI->Text

  Standard_disp()
RETURN
/* EOP LtzDisp */

/* Grund */
PROCEDURE GruDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=6 , li:=12 , re:=68 , unt:=9

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Grund-Nr: '+GRUND->GrundNr
  @ ob+2 ,li say 'Text....:' get Grund->Text

  Standard_disp()
RETURN
/* EOP LtzDisp */

/* Paletten */
PROCEDURE PalDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=6 , li:=16 , re:=58 , unt:=17

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Nr..: '+PALETTEN->PalNr
  @ ob+2 ,li say 'Text:' get PALETTEN->Text1
  @ ob+3 ,li say '     ' get PALETTEN->Text2
  @ ob+4 ,li say '     ' get PALETTEN->Text3

  @ ob+6 ,li say 'Englisch:'
  @ ob+8 ,li say 'Text:' get PALETTEN->E_Text1
  @ ob+9 ,li say '     ' get PALETTEN->E_Text2
  @ ob+10 ,li say '     ' get PALETTEN->E_Text3

  Standard_disp()
RETURN
/* EOP LtzDisp */

// ** Werbung *************************************
PROCEDURE WKdDisp(Aendern,Sperren)
LOCAL GetList:={}

  @ 7,14 clear to 21,68
  @ 7,14 to 21,68

  @ 8,15 say "Nummer...: "+WERBUNG->KdNr_Werb get WERBUNG->Kurzname

  @ 9,15 to 9,67
  @ 10,15 say "Partner..:" get WERBUNG->Vertreter
  @ 12,15 say "Adresse:  " get WERBUNG->Adr1
  @ 13,15 say "          " get WERBUNG->Adr2
  @ 14,15 say "          " get WERBUNG->Adr3
  @ 15,15 say "          " get WERBUNG->Adr4

  @ 17,15 say "Wein (Fl.)...:" get WERBUNG->Geschenk1
  @ 18,15 say "Tischkalender:" get WERBUNG->Geschenk2
  @ 19,15 say "Wandkalender :" get WERBUNG->Geschenk3
  @ 20,15 say "Sonstiges....:" get WERBUNG->Geschenk4


  Standard_disp()
RETURN
/* EOP WKdDisp */


// ** Werbe-Texte ***************************************
PROCEDURE WerDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4

  @ ob,18 clear to ob+8,62
  @ ob,18 to ob+8,62
  @ ob+1,20 say "KZ......: " + TEXT_KZ->Textkz_Nr
  @ ob+2,20 get TEXT_KZ->Text1
  @ ob+3,20 get TEXT_KZ->Text2
  @ ob+4,20 get TEXT_KZ->Text3
  @ ob+5,20 get TEXT_KZ->Text4
  @ ob+6,20 get TEXT_KZ->Text5
  @ ob+7,20 get TEXT_KZ->Text6

  // Englisch
  ob += 9
  @ ob,18 clear to ob+8,62
  @ ob,18 to ob+8,62
  @ ob,22 say "Englisch:"

  @ ob+2,20 get TEXT_KZ->E_Text1
  @ ob+3,20 get TEXT_KZ->E_Text2
  @ ob+4,20 get TEXT_KZ->E_Text3
  @ ob+5,20 get TEXT_KZ->E_Text4
  @ ob+6,20 get TEXT_KZ->E_Text5
  @ ob+7,20 get TEXT_KZ->E_Text6



  Standard_disp()
RETURN
/* EOP WerDisp */

static function dispMaschWerte(ob,li)
  @ ob+ 2,li + 42 say if(MASCHINE->Art=="M","Montage  ","Fertigung")
  @ ob+ 3,li + 42 say if(MASCHINE->Status=="X","Verschrottet",space(12))
return .t.

static function dispMaschGruppe(ob,li)
  MASCHGR->(dbseek(MASCHINE->MaschGr))
  @ ob+ 15,li + 12 say MASCHGR->Bez
return .t.


/* Av: Machinen / Stunden , Zeiten */
PROCEDURE MasDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=14,re:=66,ob:=3

  open("MaschGr")
  select Maschine

  @ ob+ 1,li-2 clear to ob+17,re+2
  @ ob+ 1,li-2 to ob+17,re+2

  @ ob+ 2,li say "Maschinen-Nummer......: " + MASCHINE->StdNr
  @ ob+ 2,li + 32 say "Art...:" get MASCHINE->Art picture "!";
    valid MASCHINE->Art $ "MF" .and. dispMaschWerte(ob,li) when Message("Maschinen Art eingeben  "+;
    "(@F@ertigung oder @M@ontage)")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 3,li + 32 say "Status:" get MASCHINE->Status picture "!";
    valid MASCHINE->Status $ " X" .and. dispMaschWerte(ob,li) when Message("Maschinen Status "+;
    "eingeben  (@Leer@ = Aktiv oder @X@ = verschrottet)")

  @ ob+ 5,li say "Bezeichnung...........:" get MASCHINE->Bez;
    when Message("Bezeichnung eingeben.")

  @ ob+ 7,li say "Haupt- oder Neben-Ma. :" get MASCHINE->HauptKZ picture "!" ;
    valid { |oGet| maschKzNach(oGet)} ;
    when Message("Standard-Belegung eingeben.  @H@aupt- oder @N@ebenmaschine.")
  @ ob+ 8,li say "Kosten Haupt-Maschine :" get MASCHINE->Kosten ;
    when Message("Kosten als Hauptmaschine eingeben.")
  @ ob+8,li+34 say "Kosten-Stelle:" get MASCHINE->Kostenst picture "@!" ;
    valid { |oGet| check(oGet,"KstStamm") };
    when Message("Kosten-Stelle als @Hauptmaschine@ eingeben.")

  @ ob+ 9,li say "Kosten Neben-Maschine :" get MASCHINE->KostenNe ;
    when Message("Kosten als Nebenmaschine eingeben.")
  @ ob+9,li+34 say "Kosten-Stelle:" get MASCHINE->KstStNe picture "@!" ;
    valid { |oGet| check(oGet,"KstStamm") };
    when Message("Kosten-Stelle als @Nebenmaschine@ eingeben.")

  @ ob+11,li say "Regel-Rüstzeit (Stunden):" get MASCHINE->RuestZeit ;
    valid { |oGet| maschRuestzeit(oGet) }
  qqout(" h")
  @ ob+ 12,li say "Material-Eingabe Pflicht:" get MASCHINE->MatBedarf picture "!" ;
    valid MASCHINE->MatBedarf $ "JN";
    when Message("Wird Material benötigt @J@/@N@")
  @ ob+ 13,li say "Wkz. Nutzen ignorieren..:" get MASCHINE->Nutzen picture "!" ;
    valid MASCHINE->MatBedarf $ "JN";
    when Message("Wird in der Nachkalk die Gesamt-Zeit für den Zug eingegeben? @J@/@N@")

  @ ob+ 15,li say "Gruppe:" get MASCHINE->MaschGr picture "99" ;
    valid { |oGet| check(oGet,"MaschGr",.t.,.t.) .and. dispMaschGruppe(ob,li) };
    when Message("Maschinen Gruppe eingeben  @F12@=Auswahl")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 16,li say "Farbe :" get MASCHINE->Farbe valid { |oGet| check(oGet,"Farbe",.t.,.t.)};
    picture "!AAAAAAAAAAA" when Message("Farbe an Plantafel eingeben  @F12@=Auswahl")

  dispMaschWerte(ob,li)
  dispMaschGruppe(ob,li)

  Standard_disp()
RETURN
/** eop */

/** Wird nach Eingabe der Rüstzeit für Haupt und Nebenmaschinen ausgeführt */
static function maschRuestzeit(oGet)
  if oGet:changed
    if MASCHINE->RuestZeit<0
      return .f.
    endif
    if Message("Rüstzeit für alle Hauptmaschinen in Stücklisten übernehmen? (@J@/@N@)","JN","N")=="J"
      Message("Rüstzeit wird kopiert.   Bitte warten...")
      if open("AvPost")
        locate for AVPOST->Art=="V" .and.;
          AVPOST->Text=="A" .and. trim(AVPOST->ArtNr)==MASCHINE->StdNr
        do while ! AVPOST->(eof())
          Message("Rüstzeit wird kopiert.   Bitte warten...     @"+AVPOST->AvNr+"@")
          if val(oGet:buffer)==0 .or. AVPOST->RuestZeit==0
            if rec_lock(5)
              replace AVPOST->RuestZeit with val(oGet:buffer)
              dbcommit()
              dbunlock()
            endif
          endif
          cont
        enddo
      endif
      select Maschine
    endif
  endif
return .t.
/** eof */


/** Wird nach Eingabe der Masch.KZ für Haupt und Nebenmaschinen ausgeführt */
static function maschKzNach(oGet)
  if oGet:changed
    if ! MASCHINE->HauptKZ$"HN"
      return .f.
    endif

    Message("Prüfe Stücklisten.  Bitte warten...")
    // Prüfe Stücklisten
    if open("AvPost")
      locate for AVPOST->Art=="V" .and.;
        AVPOST->Text=="A" .and. trim(AVPOST->ArtNr)==MASCHINE->StdNr
      if ! AVPOST->(eof())
        If Message("Haupt-/Nebenmaschine in allen Stücklisten anpassen? (@J@/@N@)","JN","N")=="J"
          Message("Stücklisten werden aktualisiert.  Bitte warten...")
          do while ! AVPOST->(eof())
            if rec_lock(5)
              replace AVPOST->HauptKZ with oGet:buffer
            endif
            cont
          enddo
        endif
      endif
    endif
    select Maschine
  endif
return .t.
/** eof */

/*** AV: TextMaske ***/
PROCEDURE Texdisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,06 clear to 13,68
  @ 9,06 to 13,68
  @ 10,08 say "Text-Nummer......: "+ TEXT->TextNr
  @ 12,08 get TEXT->text

  Standard_disp()
RETURN

/*** Miki Lagerorte ***/
PROCEDURE LgDisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,06 clear to 15,62
  @ 9,06 to 15,62
  @ 10,08 say "Lager......: "+ LAGERORT->LgNr
  @ 12,08 say "Bezeichnung:" get LAGERORT->Text
  @ 14,08 say "Kurz-Bez...:" get LAGERORT->KurzText

  Standard_disp()
RETURN

/*** AV: Sortierung ***/
PROCEDURE AvSDisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,06 clear to 13,69
  @ 9,06 to 13,69
  @ 10,08 say "AV-Sortier-Reihenfolge: "+ AVSORTNR->Reihenfolg
  @ 12,08 get AVSORTNR->text

  Standard_disp()
RETURN

/*** AV: Maschinen-Gruppe ***/
PROCEDURE MGrDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL aktRec:=MASCHGR->(recno())

  @ 9,06 clear to 13,69
  @ 9,06 to 13,69
  @ 10,08 say "Maschinen-Gruppe: " + MASCHGR->MaschGr get MaschGr->Bez
  @ 12,08 say "Ober-Gruppe....:" get MASCHGR->ChildGr picture "@K";
    valid { |oGet| nachChildGr(oget) } when Message("Gruppe eingeben, die für diese Gruppe "+;
    "ebenfalls verwendet werden kann.  @F12@=Hilfe")

  if ! empty(MASCHGR->ChildGr)
    MASCHGR->(dbseek(MASCHGR->ChildGr))
    @ 12,29 say MaschGr->Bez
    MASCHGR->(dbgoto(aktRec))
  endif

  Standard_disp()
RETURN

/*** AV: Kostenst. ***/
PROCEDURE Kstdisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,12 clear to 14,66
  @ 9,12 to 14,66

  @ 10,14 say "Nummer:   " + KSTSTAMM->KostNr
  @ 11,14 to 11,64
  @ 10,30 get KSTSTAMM->bez
  @ 12,14 say "Inland    EG    Sonstige"
  @ 13,14 get KSTSTAMM->inland picture "@K 99999"
  @ 13,24 get KSTSTAMM->eg picture "@K 99999"
  @ 13,34 get KSTSTAMM->sonst picture "@K 99999"

  Standard_disp()
RETURN




/* Lieferanten-Maske */
PROCEDURE LieDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=1,re:=78,ob:=2,neuLi
LOCAL aktAlias:=Alias()
  open("BankStam")
  select (aktAlias)

  @ ob,li-1 clear to ob+21,re+1
  @ ob,li-1 to ob+21,re+1

  @ ob-1 ,li say "Lieferanten-Nummer..: " + LIEFERAN->Liefnr
  @ ob-1 ,li+29 get LIEFERAN->Kurzname picture "@!"

  @ ob+ 1,li say "Name............:" get LIEFERAN->NAME1 valid { |oGet| checkSepaValid(oGet)}
  @ ob+ 2,li say "                 " get LIEFERAN->NAME2
  @ ob+ 3,li say "Straße..........:" get LIEFERAN->STRASSE
  @ ob+ 4,li say "                 " get LIEFERAN->Zusatz when Message()
  @ ob+ 5,li say "Land / PLZ / Ort:" get LIEFERAN->LAND picture "@!" ;
    valid { |oGet| check(oGet,"Land",.f.,.f.) } when Message("Land eingeben     @F12@=Auswahl")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 5,li+21 get LIEFERAN->PLZ when Message("Postleitzahl eingeben")
  @ ob+ 5,li+29 get LIEFERAN->ORT when Message("Ort eingeben")
  @ ob+ 5,li+51 say "Sprache:" get LIEFERAN->Sprache picture "@!" valid LIEFERAN->Sprache $ "ED" ;
    when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")

  @ ob+ 6,li say "Ansprechpartner :" get LIEFERAN->Ansprech;
    when Message("Ansprechpartner eingeben")
  @ ob+ 7,li say "Telefon.........:" get LIEFERAN->Telefon when Message()
  @ ob+ 7,li + 42 say "Mobil:" get LIEFERAN->Mobil picture "@S23"
  @ ob+ 8,li say "Telefax.........:" get LIEFERAN->Fax
  @ ob+ 9,li say "Email...........:" get LIEFERAN->Email picture "@S43";
    valid {|oget| isValidEmail(oget)}
  @ ob+10,li say "Zahlungs-Kz.....:" get LIEFERAN->ZKNr valid { |oGet| check(oGet,"ZahlKond",.t.) }
  if select("ZahlKond")==0
    open("ZahlKond")
    select Lieferan
  endif
  ZAHLKOND->(dbseek(Lieferan->ZkNr))
  QQout("  "+left(ZahlKond->Text2,30))

  @ ob+11,li say "Versandart......:" get LIEFERAN->VERsNr;
    valid { |oGet| check(oGet,"VersArt",.t.) }
  if select("Versart")==0
    open("Versart")
    select Lieferan
  endif
  VERSART->(dbseek(Lieferan->VersNr))
  QQout(" "+VERSART->Text)

  @ ob+10,li+60 say "UPS-Nr.:"
  @ ob+11,li+60 get LIEFERAN->UPS

  @ ob+12,li say "Sonderrabatt....:" get LIEFERAN->SO_RABATT valid IS_POSITIVE when Message()
  @ ob+12,li + 39 say "Pflicht-Verpackung :" get LIEFERAN->Verpackung ;
    when Message("Welche Verpackungen müssen eingegeben werden?  Leer = beliebig, z.B. 81,82." )

  @ ob+13,li say "Kd-Nr. bei Lief.:" get LIEFERAN->KDNR
  @ ob+13,li + 39 say "Mindest-Bestellwert:" get LIEFERAN->MindWert
  qqout( " " + EURO_SIGN )
  @ ob+14,li say "Mehrwertsteuer..:" get LIEFERAN->MWST_KZ picture "9" when Message();
    valid { |oGet| check(oGet,"Mwst_Kz",.t.) .and. dispMwst(oGet:buffer)}
  dispMwst(LIEFERAN->Mwst_Kz)
  @ ob+14,li + 39 say "Skonto (J/N).......:" get LIEFERAN->Skonto picture "!";
    valid LIEFERAN->Skonto $ "JN " when Message("Falls @N@ kann bei einer Überweisung kein "+;
    "Sktonto eingegeben werden.")
  @ ob+15,li say "Ident.Nr........:" get LIEFERAN->IDENT_NR when Message()
  @ ob+15,li + 39 say "Kostenstelle.......:" get LIEFERAN->KostNr picture "@!";
    valid { |oGet| check(oGet,"KostenSt") } when Message("Kostenstelle eingeben.  falls    "+;
    "@F12@=Auswahl")

  // 1. Bank
  @ ob+16,Li+6 say "1. Bank" color COLINV

  @ ob+17,Li say "IBAN:" get LIEFERAN->eIBAN picture "@K!" valid{ |oGet| enterIBAN(oGet) } ;
    when Message("IBAN-Nummer eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  @ ob+18,Li say "Kto.:" get LIEFERAN->Ekto picture "@9" valid { |oGet| enterKto(oGet) } ;
    when Message("Konto-Nummer eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  // Eingabe bLZ oder/und BIC
  @ ob+19,Li say "Nr. :" get LIEFERAN->Eblz picture "@!" ;
    valid { |oGet| enterBLZ(oGet) .and. dispBankName( ) } ;
    when Message("Bank-Nummer eingeben.   @F12@=Hilfe")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe
  @ ob+19,Li + 24 say "BIC:" get LIEFERAN->EBIC picture "@!" ;
    valid { |oGet| enterBIC(oGet) .and. dispBankName( )} when Message("BIC / SWIFT eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  // Ausgabe Bank Name
  // dispBankName( )


  // 2. Bank
  neuLi:=45
  @ ob+16,neuLi say "2. Bank" color COLINV

  @ ob+17,neuLi get LIEFERAN->pIBAN valid { |oGet| enterIBAN(oGet) } picture "@K!S32" ;
    when Message("IBAN-Nummer eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  @ ob+18,neuLi get LIEFERAN->Pkto picture "@9" valid { |oGet| enterKto(oGet) } ;
    when Message("Konto-Nummer eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe
  @ ob+19,neuLi get LIEFERAN->Pblz picture "@!" ;
    valid { |oGet| enterBLZ(oGet) .and. dispBankName( ) } ;
    when Message("Bank-Nummer eingeben.   @F12@=Hilfe")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe
  @ ob+19,neuLi + 16 say "BIC:" get LIEFERAN->pBIC picture "@!" ;
    valid { |oGet| enterBIC(oGet) .and. dispBankName( )} when Message("BIC / SWIFT eingeben.")
  setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe

  // Ausgabe Bank Name
  dispBankName()

  // Anzeige Zugangsdaten
  if getUser():DSGVO
    @ ob+ 1,li + 53 say "Zugangsdaten:"
    @ ob+ 2,li + 53 get LIEFERAN->Zugang1 picture "@S25"
    @ ob+ 3,li + 53 get LIEFERAN->Zugang2 picture "@S25"
    @ ob+ 4,li + 53 get LIEFERAN->Zugang3 picture "@S25"
  endif

  Standard_disp()
RETURN

static function dispBankName()
  BANKSTAM->(dbseek(LIEFERAN->EBlz))
  @ 22 , 7 say BANKSTAM->BankBez

  BANKSTAM->(dbseek(LIEFERAN->pBlz))
  @ 22 , 45 say left(BANKSTAM->BankBez,30)
return .t.


/* Personal-Maske */
PROCEDURE PerDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=5
LOCAL re:=66
LOCAL ob:=5

  @ ob+ 2,li-2 clear to ob+12,re+2
  @ ob+ 2,li-2 to ob+12,re+2
  @ ob+ 3,li say "Personal-Nummer.....: " + PERSONAL->PersNr

  @ ob+ 5,li say "Kürzel..............:" get PERSONAL->Kurzel picture "@!K" ;
    when Message("Kürzel eingeben.         @F12@=Auswahl")

  @ ob+ 7,li say "Name................:" get PERSONAL->Name when Message("Name eingeben.")
  @ ob+ 9,li say "Stundenlohn.........:" get PERSONAL->StdLohn;
    when Message("Stundenlohn in Euro eingeben.")
  @ ob+ 11,li say "Kostenstelle........:" get PERSONAL->Kostenst;
    valid { |oGet| check(oGet,"KstStamm") } when Message("Kostenstelle eingeben.         "+;
    "@F12@=Auswahl")

  Standard_disp()
RETURN

/* Spedition-Maske */
PROCEDURE SpeDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=2,re:=78,ob:=2

  @ ob,li-1 clear to ob+17,re+1
  @ ob,li-1 to ob+17,re+1

  @ ob-1 ,li say "Speditions-Nummer...: " + SPEDIT->SpedNr
  @ ob-1 ,li+29 get SPEDIT->Kurzname picture "@!"

  @ ob+ 1,li say "Name...........:" get SPEDIT->Name
  @ ob+ 2,li say "                " get SPEDIT->Name2
  @ ob+ 3,li say "Straße.........:" get SPEDIT->Strasse1
  @ ob+ 4,li say "                " get SPEDIT->Strasse2
  @ ob+ 5,li say "Land / PLZ.....:" get SPEDIT->Land picture "@!";
    valid { |oGet| nachSpeditLand(oGet) }
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  @ ob+ 5,li+25 get SPEDIT->PLZ
  @ ob+ 6,li say "Ort............:" get SPEDIT->ORT
  @ ob+ 7,li say "Sprache........:" get SPEDIT->Sprache picture"!" ;
    valid SPEDIT->Sprache $ "ED" .and. message() ;
    when Message("Bitte Sprache eingeben: @De@utsch oder @E@nglish      @F12@=Auswahl")
  @ ob+ 8,li say "Ansprechpartner:" get SPEDIT->Ansprech
  @ ob+ 9,li say "Telefon........:" get SPEDIT->Telefon
  @ ob+10,li say "Telefax........:" get SPEDIT->Fax
  @ ob+11,li say "Email..........:" get SPEDIT->Email picture "@S43";
    valid {|oget| isValidEmail(oget)}
  @ ob+12,li say "                " get SPEDIT->Email2 picture "@S43";
    valid {|oget| isValidEmail(oget)}
  @ ob+13,li say "                " get SPEDIT->Email3 picture "@S43";
    valid {|oget| isValidEmail(oget)}
  @ ob+14,li say "                " get SPEDIT->Email4 picture "@S43";
    valid {|oget| isValidEmail(oget)} when Message()

  @ ob+15,li say "Kd.Nr. bei Sped:" get SPEDIT->SpedKdNr
  @ ob+16,li say "Spedition......:" get SPEDIT->SpedKZ picture "!" valid SPEDIT->SpedKZ $ "JN" ;
    when Message("Speditionsdienstleister?  @J@=Spedition  @N@=Paketdienstleister")

  @ ob+18,li-1 to ob+21,re+1
  @ ob+18,li + 1 say "Englisch:"

  @ ob+19,li say "Name...........:" get SPEDIT->E_Name when Message("Name in Englisch eingeben")
  @ ob+20,li say "                " get SPEDIT->E_Name2

  // Anzeige Zugangsdaten
  if getUser():DSGVO
    @ ob+ 1,li + 51 say "Zugangsdaten:"
    @ ob+ 2,li + 51 get SPEDIT->Zugang1 picture "@S26"
    @ ob+ 3,li + 51 get SPEDIT->Zugang2 picture "@S26"
    @ ob+ 4,li + 51 get SPEDIT->Zugang3 picture "@S26"
  endif

  Standard_disp()
RETURN

/*
*
* wird nach Eingabe der Länderkennung bei der Spedition ausgeführt
*/
static FUNCTION nachSpeditLand(oGet)

  if ! check(oGet,"Land",.f.,.f.)
    return .f.
  endif

  if oGet:changed
    oget:assign()
    LAND->(dbseek(left(SPEDIT->Land,2)))
    replace SPEDIT->Sprache with LAND->Sprache
    setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif
return .t.
/** eof */




/* Status-Repa */
PROCEDURE SttDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=5
LOCAL re:=77
LOCAL ob:=3

  @ ob+ 2,li-2 clear to ob+18,re+2
  @ ob+ 2,li-2 to ob+18,re+2
  @ ob+ 3,li say "Artikel-Nr.: " + Status->ArtNr
  if ! empty(Status->ArtNr)
    ARTIKEL->(dbseek(STATUS->ArtNr))
  endif
  QQOut(space(1),ARTIKEL->Bez1)

  @ ob+ 4,li say "Status.....: " + Status->Status
  // @ ob+ 5,li say "Typ........:" get Status->Typ valid { |oGet| check(oGet,"Gerat",.f.) }
  @ ob+ 5,li say "Kurzbezeich:" get Status->KurzBez
  @ ob+ 7,li say "Bezeichnung:" get Status->Bez1
  @ ob+ 8,li say "            " get Status->Bez2
  @ ob+ 9,li say "            " get Status->Bez3
  @ ob+10,li say "            " get Status->Bez4
  @ ob+11,li say "            " get Status->Bez5
  @ ob+12,li say "            " get Status->Bez6
  @ ob+13,li say "            " get Status->Bez7
  @ ob+14,li say "            " get Status->Bez8
  @ ob+17,li say "ab Ger eNr." get Status->ab_geratNr

  Standard_disp()
RETURN


/* Material-Kz Magazine */
PROCEDURE MKzDisp(Aendern,Sperren)
LOCAL GetList:={} , erg,en_erg
LOCAL li:=8
LOCAL re:=38
LOCAL ob:=4
LOCAL aktColor:=setcolor()

  @ ob-1,li-2 clear to ob+2,re+2
  @ ob-1,li-2 to ob+2,re+2
  @ ob,li say "Material-Kz.: " + MAT_KZ->MatKz

  @ ob+ 3,li-2 clear to ob+11,re+2
  @ ob+ 3,li-2 to ob+11,re+2
  @ ob+ 3,li+4 say "Deutsch:"

  if aendern
    Message("@ESC@ = Englisch / Ende")
    setcolor(COLGET)
  endif
  if aendern
    do while erg==nil .or. len( HB_ATokens( erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
      erg:=MyMemoEdit( if( erg==nil , MAT_KZ->MkzText , erg ) , ob+4 , li , ob+10 , re , .t. )
      if len( HB_ATokens( erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
        Error(ACHTUNG+"Maximal "+str(MAX_ANZAHL_MATKZ, 2)+" Zeilen erlaubt.  Bitte korrigieren.")
      endif
    enddo
  else
    MemoEdit(MAT_KZ->MkzText,ob+4,li,ob+10,re, .f. , .f. )
  endif

  if aendern

    // low lighten
    setcolor( aktColor )
    MEMOEDIT(erg,ob+4,li,ob+10,re, .f. , .f.)
  endif

  li:=44
  re:=74
  @ ob+ 3,li-2 clear to ob+11,re+2
  @ ob+ 3,li-2 to ob+11,re+2
  @ ob+ 3,li+4 say "Englisch:"

  if aendern
    Message("@ESC@ = Ende")
    setcolor(COLGET)
  endif
  if aendern
    do while en_erg == nil .or. len( HB_ATokens( en_erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
      en_erg:=MyMemoEdit( if( en_erg==nil , MAT_KZ->E_MkzText , en_erg ) , ob+4 , li , ob+;
        10 , re , .t. )
      if len( HB_ATokens( en_erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
        Error(ACHTUNG+"Maximal "+str(MAX_ANZAHL_MATKZ, 2)+" Zeilen erlaubt.  Bitte korrigieren.")
      endif
    enddo
  else
    MEMOEDIT(MAT_KZ->E_MkzText,ob+4,li,ob+10,re, .f. , .f. )
  endif

  if aendern
    if ( erg <> MAT_KZ->MkzText .or. en_erg <> MAT_KZ->E_MkzText ) .and. ;
      Message("Änderungen speichern? (@J@/@N@)","JN","J") == "J"
      // rückschreiben
      replace MAT_KZ->MkzText with erg
      replace MAT_KZ->E_MkzText with en_erg
    endif

    // low lighten
    setcolor( aktColor )
    MEMOEDIT(MAT_KZ->E_MkzText,ob+4,li,ob+10,re, .f. , .f.)

    Set Key K_ESC to
  endif

  Standard_disp()
RETURN
  /** EOF Mat_kz */

/* Artikel Texte */
PROCEDURE AteDisp(Aendern,Sperren)
LOCAL GetList:={} , erg,en_erg
LOCAL li:=8
LOCAL re:=38
LOCAL ob:=4
LOCAL aktColor:=setcolor()

  @ ob-1,li-2 clear to ob+1,re+1
  @ ob-1,li-2 to ob+1,re+1
  @ ob,li say "Artikel-Text Nr.: " + ARTTEXT->ArtTextNr

  @ ob+ 3,li-2 clear to ob+11,re+2
  @ ob+ 3,li-2 to ob+11,re+2
  @ ob+ 3,li+4 say "Deutsch:"

  if aendern
    Message("@ESC@ = Englisch / Ende")
    setcolor(COLGET)
  endif
  if aendern
    do while erg==nil .or. len( HB_ATokens( erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
      erg:=MyMemoEdit( if( erg==nil , ARTTEXT->Text , erg ) , ob+4 , li , ob+10 , re , .t. )
      if len( HB_ATokens( erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
        Error(ACHTUNG+"Maximal "+str(MAX_ANZAHL_MATKZ , 2)+" Zeilen erlaubt.  Bitte korrigieren.")
      endif
    enddo
  else
    MemoEdit(ARTTEXT->Text,ob+4,li,ob+10,re, .f. , .f. )
  endif

  if aendern

    // low lighten
    setcolor( aktColor )
    MEMOEDIT(erg,ob+4,li,ob+10,re, .f. , .f.)
  endif

  li:=44
  re:=74
  @ ob+ 3,li-2 clear to ob+11,re+2
  @ ob+ 3,li-2 to ob+11,re+2
  @ ob+ 3,li+4 say "Englisch:"

  if aendern
    Message("@ESC@ = Ende")
    setcolor(COLGET)
  endif
  if aendern
    do while en_erg == nil .or. len( HB_ATokens( en_erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
      en_erg:=MyMemoEdit( if( en_erg==nil , ARTTEXT->E_Text , en_erg ) , ob+4 , li , ob+;
        10 , re , .t. )
      if len( HB_ATokens( en_erg , MY_CR+MY_LF ) ) > MAX_ANZAHL_MATKZ
        Error(ACHTUNG+"Maximal "+str(MAX_ANZAHL_MATKZ, 2)+" Zeilen erlaubt.  Bitte korrigieren.")
      endif
    enddo
  else
    MEMOEDIT(ARTTEXT->E_Text,ob+4,li,ob+10,re, .f. , .f. )
  endif

  if aendern
    if ( erg <> ARTTEXT->Text .or. en_erg <> ARTTEXT->E_Text ) .and. ;
      Message("Anderungen speichern? (@J@/@N@)","JN","J") == "J"
      // rückschreiben
      replace ARTTEXT->Text with erg
      replace ARTTEXT->E_Text with en_erg
    endif

    // low lighten
    setcolor( aktColor )
    MEMOEDIT(ARTTEXT->E_Text,ob+4,li,ob+10,re, .f. , .f.)

    Set Key K_ESC to
  endif

  Standard_disp()
RETURN
/** eop Art Texte */

  // ** BeurteilungsTexte (repa) *****************************
// PROCEDURE BTeDisp(Aendern/*,Sperren*/
PROCEDURE BTeDisp(Aendern)
LOCAL ob:=5, li:=2,GetList:={}
LOCAL te,i

  @ ob,li-2 clear to ob+17,li+78
  @ ob,li-2 to ob+17,li+78

  @ ob+1,li say "Nr..: "+BEURTEIL->BemerkNr
  @ ob+2,li to ob+2,li+77

  if Aendern
    Message("@ESC@=Ende")
    SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
    te:=MEMOEDIT(BEURTEIL->Text,ob+3,li,21,78, .t.)
    Set Key K_ESC to
    replace BEURTEIL->Text with Te
  else
    te:=memotran(BEURTEIL->Text,"@","@")+"@" // ersetzt Chr(13) durch @
    for i:=1 to 12
      if at("@",te) > 0
        @ ob+2+i,li say left(te,at("@",te)-1)
      else
        exit
      endif
      te:=substr(te,at("@",te)+1)
    next
  endif


RETURN
/* EOP ProDisp */



/* Hausbanken */
PROCEDURE HbaDisp(Aendern,Sperren)
LOCAL GetList:={}, aktSaldo
LOCAL li:=2
LOCAL re:=72
LOCAL ob:=4

  @ ob ,li-2 clear to ob+18,re+2
  @ ob+ 1,li-2 to ob+18,re+2
  @ ob+ 3,li say "BankNr.......: " + HAUSBANK->BankNr

  @ ob+5,li say "IBAN.........:" get HAUSBANK->IBAN valid { |oGet| enterIBAN(oGet) }

  @ ob+7,li say "Blz..........:" get HAUSBANK->Blz picture "@9" valid { |oGet| enterBLZ(oGet) } ;
    when Message("Bankleitzahl eingeben.                @F12@=Hilfe")
  if ! empty(HAUSBANK->Blz) .and. open("BankStam")
    BANKSTAM->(dbseek(HAUSBANK->Blz))
    @ ob+ 8,li say "Name.........: "+trim(BANKSTAM->BankBez)
    @ ob+ 9,li say "BIC..........: "+BANKSTAM->Bic
    select Hausbank
  endif

  @ ob+11,li say "Konto-Nummer :" get HAUSBANK->KtoNr;
    when Message() valid { |oGet| enterKto(oGet) }
  @ ob+12,li say "Auftrageber..:" get HAUSBANK->Aufgeb when Message()

  aktSaldo:="Saldo"+right("00"+alltrim(str(month(getUser():date),2)),2)
  @ ob+ 14,li say "Guthaben.....: "
  QQOut(&(aktSaldo))

  @ ob+ 16,li say "Scheck-Text..:" get HAUSBANK->ScheckTe1
  @ ob+ 17,li say "              " get HAUSBANK->ScheckTe2

  /** Saldo */
  @ ob+ 2,li+60 say "Saldo:" color COLINV
  @ ob+ 3,li+53 say "    " get HAUSBANK->Saldo00
  @ ob+ 4,li+53 say "Jan:" get HAUSBANK->Saldo01
  @ ob+ 5,li+53 say "Feb:" get HAUSBANK->Saldo02
  @ ob+ 6,li+53 say "Mär:" get HAUSBANK->Saldo03
  @ ob+ 7,li+53 say "Apr:" get HAUSBANK->Saldo04
  @ ob+ 8,li+53 say "Mai:" get HAUSBANK->Saldo05
  @ ob+ 9,li+53 say "Jun:" get HAUSBANK->Saldo06
  @ ob+ 10,li+53 say "Jul:" get HAUSBANK->Saldo07
  @ ob+ 11,li+53 say "Aug:" get HAUSBANK->Saldo08
  @ ob+ 12,li+53 say "Sep:" get HAUSBANK->Saldo09
  @ ob+ 13,li+53 say "Okt:" get HAUSBANK->Saldo10
  @ ob+ 14,li+53 say "Nov:" get HAUSBANK->Saldo11
  @ ob+ 15,li+53 say "Dez:" get HAUSBANK->Saldo12

  Standard_disp()
RETURN


/* BankenStamm */
PROCEDURE BanDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=6
LOCAL re:=74
LOCAL ob:=8

  @ ob+ 1,li-2 clear to ob+11,re+2
  @ ob+ 1,li-2 to ob+11,re+2
  @ ob+ 3,li say "Blz.......: " + BANKSTAM->Blz

  @ ob+ 5,li say "Name......:" get BANKSTAM->BankBez
  @ ob+ 7,li say "BIC.......:" get BANKSTAM->BIC picture "@!" valid {|oGet| checkBIC(oGet)}
  @ ob+ 9,li say "Land......: " + BANKSTAM->Land
  LAND->(dbseek(BANKSTAM->Land))
  qqout(" "+LAND->Name)

  Standard_disp()
RETURN
/** eop */

STATIC FUNCTION checkBIC(oGet)
  if oGet:changed
    if bic_verify(oGet:buffer)<>0
      Error(ACHTUNG+"ungültige BIC")
      return .f.
    endif
    replace BANKSTAM->Land with substr(oGet:buffer,5,2)
    LAND->(dbseek(BANKSTAM->Land))
    if LAND->(eof())
      Error(ACHTUNG+"ungültiges Land in BIC (5. + 6. Stelle)")
      return .f.
    endif

  endif
return .t.
/** eof */



/* HonselDaten */
PROCEDURE HonsDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=2
LOCAL re:=78
LOCAL ob:=2

  // if ! empty(HONSELDA->Fehler)
  // @ ob,li+56 say "Fehler:"+HONSELDA->Fehler color COLERR
  // endif


  @ ob ,li-1 clear to ob+18,re
  @ ob+ 1,li-1 to ob+14,re
  @ ob+ 2,li+35 to ob+11,li+35

  @ ob,li+23 say "Honsel"
  @ ob,li+42 say "MIKI"

  @ ob+ 3,li say "Miki Artnr..:"
  @ ob+ 4,li say "Honsel.Nr...:"
  @ ob+ 5,li say "Kund.Nr.....:"
  @ ob+11,li say "K-Lager Bestand:"

  // Honsel Daten
  if select("HonselDa") > 0
    if trim(HONSELDA->Miki_nr)==trim(ARTIKEL->ArtNr) .and. HONSELDA->Fehler<>"1"
      @ ob+ 3,li+14 say HONSELDA->Selektion
    else
      @ ob+ 3,li+14 say HONSELDA->Selektion color COLERR
    endif

    if trim(no_blanks(HONSELDA->Honsel_nr))==trim(no_blanks(ARTIKEL->Hartnr))
      @ ob+ 4,li+14 say HONSELDA->HONSEL_NR
    else
      @ ob+ 4,li+14 say HONSELDA->HONSEL_NR color COLERR
    endif

    if left(HONSELDA->KonsigKdnr,5)==left(ARTIKEL->KonsigKdnr,5)
      @ ob+ 5,li+14 say HONSELDA->KonsigKdNr
    else
      @ ob+ 5,li+14 say HONSELDA->KonsigKdNr color COLERR
    endif

    @ ob+ 7,li+4 say HONSELDA->Bez1
    @ ob+ 8,li+4 say HONSELDA->Bez1b
    // @ ob+ 9,li+4 say HONSELDA->Bez3

    if HONSELDA->HonselBest==HONSELDA->MikiBest
      @ ob+11,li+20 get HONSELDA->HonselBest
    else
      @ ob+11,li+20 get HONSELDA->HonselBest color COLERR
    endif

    @ ob+ 11,li+37 say HONSELDA->MikiBest

    if ! empty(HONSELDA->fehler)
      @ ob+ 13,li say "Fehler:" color COLERR
      do case
      case HONSELDA->Fehler=="1"
        QQout(" MIKI Nr. unbekannt.")
      case HONSELDA->Fehler=="2"
        QQout(" Artikel fehlt in Honsel Liste.")
      case HONSELDA->Fehler=="3"
        QQout(" Artikel ist kein K-Lager Artikel.")
      case HONSELDA->Fehler=="4"
        QQout(" Honsel-Nr nicht identisch.")
      endcase
    endif

  else
    @ ob+ 11,li+37 say ARTIKEL->KonsigBest

  endif

  // MIKI Daten

  @ ob+ 3,li+37 say ARTIKEL->ArtNr
  @ ob+ 4,li+37 say ARTIKEL->HartNr
  @ ob+5,li+37 say ARTIKEL->KonsigKdNr
  @ ob+ 7,li+37 say ARTIKEL->Bez1
  @ ob+ 8,li+37 say ARTIKEL->Bez2

  Standard_disp()
RETURN

/* Artikel Preis Historie */
PROCEDURE ArtPrDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL li:=5
LOCAL re:=77
LOCAL ob:=3

  @ ob+ 2,li-2 clear to ob+18,re+2
  @ ob+ 2,li-2 to ob+18,re+2
  @ ob+ 3,li say "Artikel-Nr.: " + ARTPREIS->ArtNr
  ARTIKEL->(dbseek(ARTPREIS->ArtNr))
  QQOut(space(1),ARTIKEL->Bez1)

  @ ob+ 5,li say "EK Preis   :" get ARTPREIS->EKPreis
  @ ob+ 6,li say "Kalk.Preis :" get ARTPREIS->Kalkpreis
  @ ob+ 7,li say "VK Preis   :" get ARTPREIS->VKPreis
  @ ob+ 8,li say "Datum      :" get ARTPREIS->Datum
  @ ob+ 9,li say "Grund      :" get ARTPREIS->Grund valid ! emptyOr2Simple(ARTPREIS->Grund,8)
  @ ob+ 10,li say "Benutzer   :" get ARTPREIS->Kurzel

  Standard_disp()
RETURN


/** gibt die entspr. MwSt in % auf BS aus. */
FUNCTION dispMwst(kz)
  if select("Mwst_Kz")==0
    open("Mwst_Kz")
    select Lieferan
  endif
  MWST_KZ->(dbseek(kz))
  qqout(" "+alltrim(str(MWST_KZ->MwSt,5,2)+"%"))
return .t.

/* letzte Stelle Art.Nr */
PROCEDURE LtzDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=6 , li:=12 , re:=68 , unt:=9

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Letzte Stelle: '+LETZTEST->LetzteSt
  @ ob+2 ,li say 'Text.........:' get LETZTEST->Text

  Standard_disp()
RETURN
/* EOP LtzDisp */

/*** Zoll-Ausgangstellen ***/
PROCEDURE ZolDisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,06 clear to 19,68
  @ 9,06 to 19,68
  @ 10,08 say "Dienstellen-Nummer: "+ ZOLLSTELLE->ZollNr
  @ 12,08 say "Art...............:" get ZOLLSTELLE->Art;
    when Message("Art eingeben.       @F12@=Auswahl") valid { |oGet| oGet:buffer $ "BELSÜ" }
  @ 14,08 say "Name..............:" get ZOLLSTELLE->Name when Message()
  @ 16,08 say "Ort...............:" get ZOLLSTELLE->Ort
  @ 18,08 say "Beschreibung......:" get ZOLLSTELLE->Text
  Standard_disp()
RETURN

/*** Artikel-Preisgruppe */
PROCEDURE ArtPrGrDisp(Aendern,Sperren)
LOCAL GetList:={}
  @ 9,06 clear to 15,68
  @ 9,06 to 15,68
  @ 10,08 say "Preisgruppe..: "+ ARTPRGR->PrGr
  @ 12,08 say "Beschreibung :" get ARTPRGR->Text
  @ 13,08 say "Erhöhung Gerät in..:" get ARTPRGR->ProzGerat
  qqout("%")
  @ 14,08 say "Erhöhung Ersatzteil:" get ARTPRGR->ProzTeil
  qqout("%")
  Standard_disp()
RETURN

/*
*
* wird nach Eingabe der Untergruppe bei den MaschGr ausgeführt
*/
static FUNCTION nachChildGr(oGet)
LOCAL aktRec:=MASCHGR->(recno()), result

  if MASCHGR->MaschGr == oGet:buffer
    Error(ACHTUNG+"Gruppe kann sich nicht selbst enthalten.")
    return .f.
  endif

  result:=check(oGet,"MaschGr",.t.)
  MASCHGR->(dbgoto(aktRec))

return result
/** eof */




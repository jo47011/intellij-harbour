// Modul: disp2.prg
//
// enth�lt Stammdaten-Masken , 1.Teil siehe Disp.prg
// /

#include "Miki.ch"
#include "Getexit.ch"
#include "error.ch"


#command Standard_disp() => ;
  if Aendern ;
  ; Sperr_Reader( GetList , Sperren ) ;
  ; GetList:={} ;
  ; dbcommit() ;
  ;else ;
  ; Sperr_Reader(GetList,.t.,"AUSGABE") ;
  ; GetList:={} ;
  ;endif


// ** Fenster-Maske ***************************************
PROCEDURE FensDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4 , li:=12 , re:=68 , unt:=18

  Fenster(ob,li-2 ,unt,re)

  @ ob+1 ,li say 'Liste   : '+FENSTER->Liste_Kurz
  @ ob+1 ,li+34 say 'Benutzer: '+FENSTER->Kurzel
  @ ob+2, li-1 to ob+2,re-1

  @ ob+ 4 ,li say 'Pos x :' get FENSTER->posX
  @ ob+ 5 ,li say 'Pos y :' get FENSTER->posY
  @ ob+ 6 ,li say 'Breite:' get FENSTER->SizeX
  @ ob+ 7 ,li say 'H�he  :' get FENSTER->SizeY
  @ ob+ 8 ,li say 'Maximiert:' get FENSTER->Maximized picture "!" valid FENSTER->Maximized$"JN"

  Standard_disp()

RETURN

// ** Listen-Maske ***************************************
PROCEDURE ListDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4 , li:=12 , re:=68 , unt:=18

  Fenster(ob,li-2 ,unt,re)

  if select("Drucker")==0
    open("Drucker")
    select Liste
    set relation to LISTE->DruckerNr into Drucker
  endif
  @ ob+1 ,li say 'Nummer......: '+LISTE->Liste_Kurz
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li say 'Bezeichnung :' get LISTE->Bez;
    when Message("Listenbezeichnung eingeben.") valid ! empty(LISTE->Bez)
  @ ob+5 ,li say 'Drucker Nr. :' get LISTE->DruckerNr picture "@K 99";
    when;
    Message("Drucker-Nummer eingeben.      @F12@=Hilfe") valid { |oGet| check(oGet,"Drucker",.f.) }
  @ ob+5 ,li+25 say DRUCKER->Bez
  @ ob+6 ,li say 'Art.........:' get LISTE->Art picture "!";
    when Message("ListenArt eingeben.      @S@=Schmaldruck (12)  @K@=Klein (15)   @W@=Winzig (17)")
  @ ob+7 ,li say 'Anzahl......:' get LISTE->Anzahl;
    when Message("Anzahl der gew�nschten Ausdrucke eingeben.") valid LISTE->Anzahl > 0

  @ ob+ 9 ,li say 'PDF-Name....:' get LISTE->PDFName Picture "@A";
    when Message("Name f�r exportierte PDF Datei eingeben.") valid checkFileName(LISTE->PDFName)
  QQOut(".pdf")
  @ ob+11 ,li say 'Unterer Rand:' get LISTE->Unt_Rand Picture "@9";
    when Message("Anzahl der Zeilen die unten abgeschnitten werden sollen.")
  @ ob+12 ,li say 'Quer (J/N)  :' get LISTE->Landscape Picture "!" valid LISTE->Landscape$"JN ";
    when Message("Liste quer drucken? (@J@/@N@)")

  Standard_disp()

RETURN

// ** Drucker-Maske ***************************************
PROCEDURE DruckDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=1 , li:=3 , re:=78 , unt:=23

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Nummer......: '+DRUCKER->DruckerNr
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li say 'Bezeichnung :' get DRUCKER->Bez
  @ ob+5 ,li say 'Print-Server:' get DRUCKER->PrintSrv picture "@K!9"
  @ ob+6 ,li say 'Queue.......:' get DRUCKER->Queue picture "@K@!"
  @ ob+7 ,li say 'Blattl�nge..:' get DRUCKER->Laenge
  @ ob+8 ,li say 'Linker Rand :' get DRUCKER->LR picture "99"
  @ ob+9 ,li say 'Form Feed   :' get DRUCKER->FormFeed picture "@9"
  @ ob+10,li say 'Init String     :' get DRUCKER->Init_Str picture "@9"
  @ ob+11,li say 'Init String chr :' get DRUCKER->Init_Str2 picture "@9"

  @ ob+12,li say 'Fett   an       :' get DRUCKER->Fett_An picture "@9"
  @ ob+13,li say 'Fett   aus      :' get DRUCKER->Fett_Aus picture "@9"
  @ ob+14,li say 'Breit  an       :' get DRUCKER->Breit_An picture "@9"
  @ ob+15,li say 'Breit  aus      :' get DRUCKER->Breit_Aus picture "@9"
  @ ob+16,li say 'Schmal an  (12) :' get DRUCKER->Schmal_An picture "@9"
  @ ob+17,li say 'Schmal aus      :' get DRUCKER->Schmal_Aus picture "@9"
  @ ob+18,li say 'Klein  an  (15) :' get DRUCKER->Klein_An picture "@9"
  @ ob+19,li say 'Klein  aus      :' get DRUCKER->Klein_Aus picture "@9"
  @ ob+20,li say 'Winzig an  (17) :' get DRUCKER->Winzig_An picture "@9"
  @ ob+21,li say 'Winzig aus      :' get DRUCKER->Winzig_Aus picture "@9"

  @ ob+3 ,li+50 say 'Postscript (J/N):' get DRUCKER->Postscript picture "!";
    valid DRUCKER->postscript $"JN "
  @ ob+4 ,li+50 say 'Duplex (J/N)....:' get DRUCKER->Duplex picture "!";
    valid DRUCKER->Duplex $"JN "
  @ ob+5 ,li+50 say 'Raw (J/N).......:' get DRUCKER->Raw picture "!" valid DRUCKER->Raw $"JN "
  @ ob+6 ,li+50 say 'Start Postion X :' get DRUCKER->PosX
  @ ob+7 ,li+50 say 'Start Postion Y :' get DRUCKER->PosY


  @ ob+10 ,li+50 say "Alternativer Drucker"
  @ ob+12 ,li+50 say "ClientName :"
  @ ob+13 ,li+50 get DRUCKER->AltClName Picture "XXXXXXXXXXXXXXXXXXXX"
  @ ob+15 ,li+50 say "Drucker.Nr.:" get DRUCKER->AltDruckNr

  Standard_disp()

RETURN


// ** Etikett-Maske eigen-erfasste ***********************
PROCEDURE EtiDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4 , li:=12 , re:=68 , unt:=18

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Nummer......: '+ETIKETT->EtikettNr
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li get ETIKETT->Eti1
  @ ob+4 ,li get ETIKETT->Eti2
  @ ob+5 ,li get ETIKETT->Eti3
  @ ob+6 ,li get ETIKETT->Eti4
  @ ob+7 ,li get ETIKETT->Eti5
  @ ob+8 ,li get ETIKETT->Eti6
  @ ob+9 ,li get ETIKETT->Eti7
  @ ob+10,li get ETIKETT->Eti8

  @ ob+13,li say "Anzahl:" get ETIKETT->anz picture "99"
  @ ob+13,li+15 say "Linker Rand:" get ETIKETT->lr picture "99"

  Standard_disp()
RETURN


// ** Etikett-Maske Repa eigen-erfasste ***********************
PROCEDURE RepDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=4 , li:=12 , re:=68 , unt:=18

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Art.Nr.:' get ETIREPA->EtiRepaNr
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li get ETIREPA->Eti1 when Message ("Text eingeben.    @F5@ = Fett")
  @ ob+4 ,li get ETIREPA->Eti2
  @ ob+5 ,li get ETIREPA->Eti3
  @ ob+6 ,li get ETIREPA->Eti4
  @ ob+7 ,li get ETIREPA->Eti5
  @ ob+8 ,li get ETIREPA->Eti6
  @ ob+9 ,li get ETIREPA->Eti7
  @ ob+10,li get ETIREPA->Eti8

  @ ob+13,li say "Anzahl:" get ETIREPA->anz picture "99"
  @ ob+13,li+15 say "Linker Rand:" get ETIREPA->lr picture "99"

  Standard_disp()
RETURN



// ** Etikett-Maske Versand-Etiketten ********************
PROCEDURE VerDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=5 , li:=12 , re:=68 , unt:=16

  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say 'Nummer......: '+VERS_ETI->VersandNr
  @ ob+2, li-1 to ob+2,re-1

  @ ob+3 ,li get VERS_ETI->Text1
  @ ob+4 ,li get VERS_ETI->Text2
  @ ob+5 ,li get VERS_ETI->Text3
  @ ob+6 ,li get VERS_ETI->Text4

  Standard_disp()
RETURN



// ** System-Paraemete ***********************************
PROCEDURE SysDisp(Aendern,Sperren)
LOCAL GetList:={}
LOCAL ob:=2 , li:=8 , re:=74 , unt:=22
LOCAL ant:="N"
LOCAL merk_Farbe:=setcolor()


  @ ob,li-2 clear to unt,re
  @ ob,li-2 to unt,re

  @ ob+1 ,li say "Z�hlerst�nde" color COLINV

  @ ob+3 ,li say "Bestell-Nr.....:" get SYSTEM->BestNr;
    when Message("N�chste Bestellnummer eingeben.  @F12@=Hilfe")
  @ ob+4 ,li say "Angebots-Nr....:" get SYSTEM->AngNr;
    when Message("N�chste Anegbotsnummer eingeben.  @F12@=Hilfe")
  @ ob+5 ,li say "Auftrags-Nr....:" get SYSTEM->AufNr;
    when Message("N�chste Auftragsnummer eingeben.  @F12@=Hilfe")
  @ ob+6 ,li say "Rechnungs-Nr...:" get SYSTEM->RechNr;
    when Message("N�chste Rechnungsnummer eingeben.  @F12@=Hilfe")
  @ ob+7 ,li say "Produktions-Nr.:" get SYSTEM->ProdNr;
    when Message("N�chste Produktionsnummer eingeben. @F12@=Hilfe")
  @ ob+8 ,li say "Lieferschein-Nr:" get SYSTEM->LSNr;
    when Message("N�chste Hand-Lieferscheinnummer eingeben. @F12@=Hilfe")


  @ ob+3 ,li+33 say "�berweisung-Nr.:" get SYSTEM->UeberNr;
    when Message("N�chste �berweisungsnummer eingeben. @F12@=Hilfe")
  @ ob+4 ,li+33 say "K-LagerLief.Nr.:" get SYSTEM->KonsigNr;
    when Message("N�chste K-Lager Lieferscheinnummer eingeben. @F12@=Hilfe")
  if getUser():id==KURZEL_DEVEL
    @ ob+5 ,li+33 say "Auf.Posten-Nr..:" get SYSTEM->ABPostNr;
      when Message("N�chste Auftragsposten-Nummer eingeben.")
  endif
  @ ob+6 ,li+33 say "SEPA -Nr.......:" get SYSTEM->SepaNr;
    when Message("N�chste SEPA-Export-Nummer eingeben.")
  // @ ob+11 ,li say "Beist.Liste.Nr.:" get SYSTEM->BeistellNr when Message("N�chste Beistellteilen-Liste-Nummer eingeben.")
  @ ob+7 ,li+33 say "Innerbetr. Nr. :" get SYSTEM->InLfdNr;
    when Message("N�chste innbetriebliche Produktions-Nummer eingeben.")
  @ ob+8 ,li+33 say "Mappen. Nr.....:" get SYSTEM->InnerNr;
    when Message("N�chste innbetriebliche Mappen-Nummer eingeben.")
  @ ob+9 ,li+33 say "Nachkalk.Nr....:" get SYSTEM->NKNr;
    when Message("N�chste Nachkalkulations-Nummer eingeben.")

  @ ob+11,li to ob+11,re-2

  @ ob+14 ,li say 'Gemeinkosten-Zuschlag:' get SYSTEM->Aufschlag;
    when Message("Aufschlag fuer Veredelungszeiten (z.B. vernickeln) eingeben.")
  qqout(" %")
  @ ob+15,li say "Drucker..............:" get SYSTEM->DruckerNr;
    when;
    Message("Standard-Drucker eingeben.  @F12@=Hilfe") valid { |oGet| check(oGet,"Drucker",.t.) }

  if getUser():id==KURZEL_DEVEL
    @ ob+12 ,li+33 say 'Version :' get SYSTEM->Version
  else
    @ ob+12 ,li+33 say 'Version : ' + alltrim(str(SYSTEM->Version))
  endif

  @ ob+13 ,li+33 say "Limit Rahmenauftr�ge"
  @ ob+14 ,li+33 say "Menge %:" get SYSTEM->RahmProz
  @ ob+15 ,li+33 say "Wochen :" get SYSTEM->RahmZeit

  @ ob+17,li say "Betriebs-Ferien:" color COLINV
  @ ob+17,li+20 say "( z.B.: 31/13,32/13,52/13,01/14 )"
  @ ob+19,li say "KWs:" get SYSTEM->Holidays valid { |oGet| checkHolidays(oGet) }

  Standard_disp()
RETURN
/** eof */

/** Pr�ft die Eingabe der KWs und sortiert diese */
static function checkHolidays(oGet)
LOCAL value:=strtran(alltrim(no_blanks(oGet:buffer)) ,";" , ",")
LOCAL allWeeks:=HB_ATokens( value , "," )
LOCAL maxWeek:=getNumWeeks(year(getUser():date))
LOCAL week

  for each week in allWeeks
    if ! KWOkay(week)
      Error(ACHTUNG+"Ung�ltige Kalenderwoche: "+week)
      return .f.
    endif
  next

  aSort(allWeeks,,, { |w1,w2| kwkleiner(w1,w2) >= 0 } )

  oget:varput( aaToToken(allWeeks,",") )
return .t.
/** eof */


  /** Artikel Display normal ******************************
  *
  * leider noch alt jojo  , ob=-2  :(
  */
PROCEDURE ArtDisp(Aendern,Sperren,AutoSperrung)
LOCAL GetList:={},m_color:=setcolor()
LOCAL ob,li,re,sollVK:=0, altStkList, altParents, p, stueckliste
LOCAL warInd, letzteBew

  li=3
  re=78
  ob=-2

  if select("Einheit")==0
    open("Einheit")
    select Artikel
  endif

  if select("LagerOrt")==0
    open("LagerOrt")
    select Artikel
  endif

  @ ob+3,li-2 clear to ob+25,re+1
  @ ob+4,li-2 to ob+25,re

  @ ob+ 3,li say "Artikel-Nummer......: " + out(ARTIKEL->ArtNr)
  if ! empty(right(ARTIKEL->ARtNr,1))
    do case
    case left(ARTIKEL->ArtNr,1)=="5" // Nietgeraete
      if select("LetzteNi")==0
        open("LetzteNi")
      endif
      LETZTENI->(dbseek(right(ARTIKEL->ArtNr,2)))
      QQOut(space(1)+LETZTENI->Text)
    otherwise // sonstige
      // if select("LetzteSt")==0
      // open("LetzteSt")
      // endif
      // LETZTEST->(dbseek(right(ARTIKEL->ArtNr,1)))
      // QQOut(space(1)+LETZTEST->Text)
    endcase
    select Artikel
  endif

  // pr�fe auf alternative St�ckliste
  stueckliste:=stueckListe():new( ARTIKEL->ArtNr, ARTIKEL->Art )
  // stueckliste:=stueckListe():new( ARTIKEL->ArtNr )
  altStkList:=stueckliste:getAlternativeMaterial()
  altParents:=stueckListe:getAlternativeParents()
  // beides sowohl als alternative St�ckliste als auch eigene Alternative definiert
  if len( altParents ) > 0 .and. ! empty(altStkList )
    @ ob+3,;
      li+32;
      say "(" + trim(out(altParents[1]:artNr)) + "/"+ trim(out(altStkList)) + ")" color LIGHT_GRAY
  else
    if ! empty( altStkList )
      @ ob+3,li+32 say "(STRG-M: " + trim(out(altStkList)) + ")" color LIGHT_GRAY
    endif
    if len( altParents ) > 0
      setcolor(LIGHT_GRAY)
      @ ob+3,li+32 say "(altern. f�r: "
      for each p in altParents
        qqout( trim(out(p:artNr)) + " " )
      next
      qqout(")")
      setcolor(COLNOR)
    endif
  endif

  if ! empty(ARTIKEL->AltArtNr)
    @ ob+3,li+50 say "(Alt: " + trim(ARTIKEL->AltArtNr)+")" color LIGHT_GRAY
  endif

  // Hinweise, dass engl. Text auch ge�ndert wird beim �ndern des dt. Textes resetten
  if aendern
    englHinweis()
  endif

  @ ob+ 5,li say "Bez. :" get ARTIKEL->Bez1 valid { |oGet| englHinweis(oGet) }
  @ ob+ 6,li say "      " get ARTIKEL->Bez2 valid { |oGet| englHinweis(oGet) }
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+ 7,li say "Artikel-Art.........:" get ARTIKEL->Art picture "!";
    when Message('@B@eisstellteil @D@ienstl. @E@inkaufs-Art. @F@ert.-Art. @T@ext @W@erkzeug '+;
    'E@x@-Artikel') valid { |oGet| nachArtikelArt(oGet) .and. Message()}
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  // @ ob+ 7,li+24 say "Wo." get ARTIKEL->DLWochen valid ARTIKEL->DLWochen >= 0 
  // when Message("Dauer externe Dienstleistung in Tagen eingeben.")
  DevPos( ob+;
    7,;
    li+24;
    );
    ;;
    DevOut( "Wo." );
    ;;
    SetPos( Row(), Col() );
    ;;
    AAdd( GetList, _GET_( ARTIKEL->DLWochen, "ARTIKEL->DLWochen",, {|| ARTIKEL->DLWochen >= 0}, {|;
    | Message("Dauer externe Dienstleistung in Tagen eingeben.")} ) ) ; ATail(GetList):Display()

  @ ob+ 7,li+32 say "KZ:" get ARTIKEL->WKZ picture "!" when Message("Kennzeichen eingeben.")

  @ ob+ 8,li say "Rabattgruppe........:" get ARTIKEL->RabattGr valid { |oGet| check(oGet,"Rabatt") } ;
    when Message("Rabattgruppe eingeben.     @F12@=Auswahl")

  if getUser():mayEditEK
    @ ob+ 9,li say "Einkaufspreis.......:   " get ARTIKEL->EKPR picture "@Z" ;
      valid { |oGet| pr_prot(oGet,.f.) .and. dispArtikelWerte() } ;
      when Message()
  else
    @ ob+ 9,li say "Einkaufspreis.......:    "+ str(ARTIKEL->EKPR,12,2)
  endif

  if getUser():mayEditVK
    // VK Ist:
    @ ob+11,li+25 get ARTIKEL->Preis1 valid { |oGet| Pr_prot(oget,.t.) .and. dispArtikelWerte()} ;
      picture "@Z" when Message() // VK
    setCargo(ATail(GetList),CARGO_DISP_GETLIST,.t.) // Ausgabe der gesamten Getliste nach Eingabe
    @ ob+12,li say "VK Soll.....(" get ARTIKEL->Zuschl_S picture "@9";
      valid {|oGet| zuschlagCheck(oGet)}
    // .and. preisKalk(oGet)
  else
    @ ob+11,li+25 say ARTIKEL->Preis1
    @ ob+12,li say "VK Soll.....( " +str(ARTIKEL->Zuschl_S,4,0)
  endif
  @ ob+12,li+18 say "%):"
  @ ob+13,li say "Preisschl�ssel......:" get ARTIKEL->Schluessel picture "!" ;
    valid { |oGet| nachSchluessel(oGet) .and. Message()} ;
    when Message("Preisschl�ssel @E@inzel oder @H@underter Preis")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  if getUser():mayEditEK
    @ ob+14,li say "Mengeneinheit Art.  :" get ARTIKEL->ME picture "9";
      valid { |oGet| nachEinheit(oGet) } when Message("Mengeneinheit (Miki) des Artikels "+;
      "eingeben.            @F12@=Hilfe")
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
    EINHEIT->(dbseek(ARTIKEL->ME))
    QQOut(space(1)+EINHEIT->Text)

    @ ob+15,li say "Umrechnungseinheit..:" get ARTIKEL->ME2 picture "9" valid { |oGet| nachMe2(oGet) } ;
      when vorME2()
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
    EINHEIT->(dbseek(ARTIKEL->ME2))
    QQOut(space(1)+EINHEIT->Text)
    EINHEIT->(dbseek(ARTIKEL->ME))
  else
    @ ob+14,li say "Mengeneinheit Artik.:  " // + ARTIKEL->ME
    @ ob+15,li say "Umrechnungseinheit..:  " // + ARTIKEL->ME2
  endif


  @ ob+16,li say "Packungsinhalt......:" get ARTIKEL->Inhalt valid { |oGet| nachInhalt(oGet) } ;
    when vorInhalt() .and. Message("Packungsinhalt eingeben.    @F10@=Einheit �ndern")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  @ ob+17,li say "Formrahmen / WKZ-Nr.:" get ARTIKEL->Formrahmen when Message()
  @ ob+18,li say "Material-Kennziffer.:" get ARTIKEL->MatKz picture MAT_PICT ;
    valid { |oGet| check(oGet,"Mat_KZ") }
  @ ob+17,li+33 say "Text-Nr.:"
  @ ob+18,li+33 get ARTIKEL->ArtTextNr picture MAT_PICT valid { |oGet| check(oGet,"ArtText") };
    when Message()

  if ARTIKEL->Art=="W"
    if stueckliste:hasMehrfachEntry()
      @ ob+20,li say "Werkzeugnutzen......: " + array2readable(stueckliste:getWerkzeugMenge(), "/")
    else
      @ ob+20,li say "Werkzeugnutzen......:" get ARTIKEL->WkzNutzen picture "999" when Message()
    endif
  else
    if stueckliste:hasMehrfachEntry()
      @ ob+20,li say "Wkz.Nutzen f�r Kalk.: " + array2readable(stueckliste:getWerkzeugMenge(), "/")
    else
      @ ob+20,li say "Wkz.Nutzen f�r Kalk.:" get ARTIKEL->Wkz_kalk picture "999" when Message()
    endif
  endif

  // neu Summe Beistellteile (rek).
  @ ob+19,li say "Beistellteil EK/Kalk: " + str(ARTIKEL->BeiEK,7,2)+"/"+str(ARTIKEL->BeiKaPr,7,2)
  if ARTIKEL->BeiEK > 0
    if ARTIKEL->BeiAufKZ == "J"
      @ ob+20,li+27 say "TZ: " + str(ARTIKEL->BeiAufschl,6,2)
    else
      @ ob+20,li+27 say "TZ:" get ARTIKEL->BeiAufschl valid { |oGet| nachBeiAufschl(oGet) } ;
        when ARTIKEL->BeiAufKZ <> "J" .and. message("Teurungszuschlag Beistellteile in Euro eingeben.")
    endif
  endif

  // picture "@K "+replicate("9",len(ARTIKEL->Wkz_kalk)) when Message()
  @ ob+21,li say "Werkzeug Eigner.....:" get ARTIKEL->Eigner when Message()
  @ ob+22,li say "Preisgruppe.........:" get ARTIKEL->PrGr picture "@!";
    valid { |oGet| check(oGet,"ArtPrGr") } when Message("Preisgruppe eingeben.    @F12@=Hilfe")
  @ ob+22,li+30 say "AV:" get ARTIKEL->Reihenfolg picture "!!!";
    valid { |oGet| check(oGet,"AvSortNr") } when Message("AV-Sortierung eingeben.    @F12@=Hilfe")
  @ ob+23,li say "Erl�s-Gruppe........:" get ARTIKEL->Erl_Gruppe ;
    valid { |oGet| check(oGet,"Erl_Grup", (ARTIKEL->Preis1 == 0)) };
    picture "@K "+replicate("9",len(ARTIKEL->Erl_Gruppe));
    when Message("Erl�sgruppe eingeben.    @F12@=Hilfe")
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  @ ob+23,li+26 say "Kst.St.:" get ARTIKEL->KOSTNR picture "XX" ;
    valid { |oGet| check(oGet,"KstStamm") .and. message() } ;
    when Message("Kostenstelle eingeben.    @F12@=Hilfe")

  // suche letzte Bewegung
  warInd:=WARAUS->(OrdSetFocus(2)) // desc
  WARAUS->(dbseek(ARTIKEL->ArtNr))
  if ! WARAUS->(eof()) .and. trim(WARAUS->Programm)<>"Neuanlage"
    letzteBew:=dtoc(WARAUS->Datum)
  else
    letzteBew:=""
  endif
  @ ob+24,li+18 say "Letzte Bew." + letzteBew
  WARAUS->(OrdSetFocus(warInd))

  @ ob+24,;
    li;
    say;
    "seit "+right(dtoc(HIST_START_DATE),5)+": "+alltrim(transform(ARTIKEL->verkauft,"999,999,999"))

  /* 2. Spalte */
  li=41

  // mittlere Trennlinie
  @ ob+5,li-1 to ob+24,li-1

  @ ob+5,li say "Lagerort :" get ARTIKEL->LG_Raum picture "@K 99" ;
    when Message("Lagerort @Raum@ eingeben.    @F12@=Auswahl") ;
    valid { |oGet| oFill(oGet,"0",.t.) .and. check(oGet,"LagerOrt",.t.,.t.) .and. dispArtikelWerte() }
  @ ob+5,li+13 say "."
  @ ob+5,li+14 get ARTIKEL->LG_Regal picture "@K 99" when Message("Lagerort @Regal@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ ob+5,li+16 say "."
  @ ob+5,li+17 get ARTIKEL->LG_Fach picture "@K 999" when Message("Lagerort @Fach@ eingeben.") ;
    valid { |oGet| oFill(oGet,"0",.t.) }
  @ ob+5,li+20 say "."
  @ ob+5,li+21 get ARTIKEL->LG_Text picture "@K" when Message("Lagerort Zusatztext eingeben.")

  @ ob +6,li say "Lagerbestand..........:" get ARTIKEL->LAGEBEST valid { |oGet| artLageBest(oGet) } ;
    when Message()
  @ ob+ 7,li say "Auftragsbestand.......:"+ str(ARTIKEL->Disponiert,10,2)

  @ ob+ 8,li say "Verf�gbar.............:"+ str(ARTIKEL->Lagebest-ARTIKEL->Disponiert,10,2)
  @ ob+ 9,li say "Interne Auftr�ge......:"+ str(ARTIKEL->BestInt,10,2)
  @ ob+10,li say "Inv.Bestand   " +if(empty(ARTIKEL->InvDate),space(8),dtoc(ARTIKEL->InvDate))+":" ;
    get ARTIKEL->Invbestand when Message() ;
    valid { |oGet| ArtInvNach(oGet) }

  @ ob+11,li say "Min.Bstand" get ARTIKEL->MinPuffer;
    when;
    Message("Anzahl Wochen (Puffer) f�r Mindestbestand eingeben");
    valid { |oGet| checkMinPuffer(oget) }
  @ ob+11,li+14 say "Ist/Soll:" get ARTIKEL->MinbestI valid ARTIKEL->MinbestI >= 0 when Message()

  @ ob+12,li say "Bestellt extern.......:" + str(ARTIKEL->BestExt,10,2) + " " + EINHEIT->Text
  @ ob+13,li say "Min.Best.Menge extern :" get ARTIKEL->MinOrderI;
    valid { |oGet| checkMinOrder(oget) } when Message("Mindest-Bestellmenge @extern@ eingeben.")

  @ ob+14,li say "Min.Menge int Ist/Soll:" get ARTIKEL->MinOrdInt ;
    when Message("Mindest-Bestellmenge @intern@ einngeben.")
  dispROIMinOrder()

  @ ob+15,li say "K-Lager-Kunden-Nr.....:" get ARTIKEL->KonsigKdNr PICTURE KDNR_PICT ;
    when getUser():mayEditKonsigKd .and. Message();
    valid { |oGet| check(oGet,"Kunden") .and. KKdNr_check(oget)}
  if ARTIKEL->KonsigKZ == "S"
    qqout(" SM")
  else
    qqout("   ")
  endif
  @ ob+16,li say "K-Lager-Bestand.......:" +str(ARTIKEL->KonsigBest,10,2)

  @ ob+17,li say "K-Lager Min/Max-Best. :" get ARTIKEL->KonsigMind Picture "99999";
    valid { |oGet| KKdnr_empty(oGet) } when getUser():mayEditKonsigKd .and. Message("K-Lager "+;
    "Mindest.-Bestand eingeben.")

  @ ob+17,li+29 say "/"
  @ ob+17,li+30 get ARTIKEL->KonsigMax Picture "99999";
    when;
    getUser():mayEditKonsigKd;
    .and.;
    Message("K-Lager Max.-Bestand eingeben.");
    valid;
    { |oGet| KKdnr_empty(oGet) .and. val(oGet:buffer)>=ARTIKEL->KonsigMind .or. val(oget:buffer)=0}

  @ ob+18,;
    li;
    say;
    "K-Lager Inv.  "+if(empty(ARTIKEL->KonsigIDat),space(8),dtoc(ARTIKEL->KonsigIDat))+":";
    get;
    ARTIKEL->KonsigInv;
    when;
    message();
    .and. getUser():mayEditKonsigKd valid { |oGet| KKdnr_empty(oGet) .and. KonsigInvNach(oGet) }

  @ ob+19,li say "Gewicht [kg]..........:" get ARTIKEL->Gewicht when Message()
  @ ob+20,li say "Spezifisches Gewicht..:" get ARTIKEL->Spez_GEW when Message()
  @ ob+21,li say "L�nge x Breite x H�he :" get ARTIKEL->Masse picture "999-999-999" when Message()
  @ ob+22,li say "Honsel-Nummer: " get ARTIKEL->HArtNr picture "XXXXXXXXXXXX-XXX-XX" ;
    valid { |oGet| doubleCheckHartNr(oGet) } when Message()
  @ ob+23,li say "Honsel-Lg.Ort: " get ARTIKEL->HLgOrt picture "@K" ;
    whwhen Message("Lagerort @Honsel@ eingeben.")

  @ ob+24,li say "Waren-Nummer : " get ARTIKEL->WarenNr picture "@9" ;
    valid { |oGet| nachIntraStat(oGet,) };
    when (getUser():mayEditIntrastat .and. ;
    Message("Waren-Nummer f�r Intra.Stat. Meldung eingeben.       @F12@=Hilfe"))

  @ ob+24,li+27 say "Land:" get ARTIKEL->LandKZ ;
    valid { |oGet| nachLandKz(oGet) };
    picture "@!" when (getUser():mayEditIntrastat .and. ;
    Message("L�nder-Kennzeichen Ursprungsland eingeben.    @XX@=Nicht-EU   @F12@=Hilfe"))

  if sperren == NIL .or. ! sperren
    setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt
  endif

  IF ValType( AutoSperrung ) == "A"
    Sperr_Reader( GetList , .f.,"NurAusgabe", AutoSperrung )
    return
  endif

  dispArtikelWerte()
  Standard_disp()

RETURN
    /** eof */


/** zeigt den Soll VK und Ist Zuschlag des akt. Artikels evtl. in Farbe an */
function dispArtikelWerte()
LOCAL ob:=-2,li:=3,sollVK:=0,MeText1,MeText2
LOCAL m_color:=setcolor(), diffVK, ort
LOCAL aktBesPostInd, firstKw, firstNr
LOCAL bewUnterNull, nTotal, oAI , bew

  EINHEIT->(dbseek(ARTIKEL->ME))

  @ ob+ 10,li say "Kalkulierter Preis..:    " + str(ARTIKEL->KAPR,12,2)// picture "@Z" valid { |oGet| kapr_prot(oGet) }

  /** Achtung: Bei Einkaufsartikel und Werkzeug wird anderer Soll VK angezeigt als
      evtl. in ARTIKEL->Soll_VK drin steht. */
  if getArtikelArt()$"WE"
    if ARTIKEL->Zuschl_S > 0
      sollVK:=ARTIKEL->KaPr*(1+ARTIKEL->Zuschl_S/100)
    endif
  else
    sollVK:=ARTIKEL->Soll_Vk
  endif
  if ARTIKEL->Preis1>0
    if sollVk > ARTIKEL->Preis1
      setcolor("R/"+getBackColor())
    endif
    @ ob+11,li say "VK Ist......( "+str(ARTIKEL->Zuschl_I,4,0)+"%):"
  else
    @ ob+11,li say "VK Ist..............:"
  endif
  @ ob+12,li+22 say left(alltrim(str(sollVk,12,2))+space(12),12)

  // Anzeige Differenz VK - Kalk.Pr
  if ARTIKEL->Preis1 - ARTIKEL->KAPR <> 0 .and. ARTIKEL->Preis1 <>0 .and. ARTIKEL->KAPR<>0
    setcolor( LIGHT_GRAY )
    diffVK = alltrim(str(ARTIKEL->Preis1 - ARTIKEL->KAPR,12,2))
    @ ob+12,li+37-len(diffVK) say diffVK
    @ ob+13,li+32 say "=Diff"
    setcolor(m_color)
  endif

  // Ausgabe Mengeneinheit
  @ ob+14,li+24 say EINHEIT->Text // hinter ME

  if empty( ARTIKEL->ME2 )
    @ ob+14,li+28 say space(9)
    @ ob+15,li+24 say space(13)
  else
    // Ausgabe Mengeneinheit
    @ ob+ 9,li+13 say " ("+alltrim( EINHEIT->Text ) + ")" // hinter EK
    @ ob+11,li+6 say " ("+alltrim( EINHEIT->Text ) + ")" // hinter VK
    @ ob+7,li+50 say " ("+alltrim( EINHEIT->Text ) + ")" // hinter Lagerbestand
    @ ob+13,li+53 say " ("+alltrim( EINHEIT->Text ) + ")" // hinter Bestellt extern

    EINHEIT->(dbseek(ARTIKEL->ME2))
    MeText2:=EINHEIT->Text
    EINHEIT->(dbseek(ARTIKEL->ME))
    MeText1:=EINHEIT->Text

    // Umrechnungsfaktor anzeigen
    if ARTIKEL->ME_FAktor > 999
      @ ob+14,li+24 say MeText1 + " " + str( round( ARTIKEL->ME_FAktor ,2) ,7,2) + MeText2
    else
      @ ob+14,li+24 say MeText1 + str( round( ARTIKEL->ME_FAktor ,2) ,6,2) + " " + MeText2
    endif
    if ARTIKEL->ME_FAktor <> 0
      if (1 / ARTIKEL->ME_FAktor) > 999
        @ Ob+15,li+24 say MeText2 + " " + str( round( 1 / ARTIKEL->ME_FAktor ,2) ,7,2) + MeText1
      else
        @ Ob+15,li+24 say MeText2 + str( round( 1 / ARTIKEL->ME_FAktor ,2) ,6,2) + " " + MeText1
      endif
    endif
  endif

  // Beistellteile VVG -> +Aufschlag = VK
  if ARTIKEL->BeiAufKZ <> "J"
    @ ob+14,li+30 say str(ARTIKEL->BeiAufschl+ARTIKEL->Preis1+ARTIKEL->BeiKaPr,7,2)
  endif

  // Einheit Packungsinhalt
  if ARTIKEL->Inhalt > 0
    @ ob+16,li+29 say "ME:" + ARTIKEL->InhaltME
    EINHEIT->(dbseek(ARTIKEL->InhaltME))
    QQOut(space(1)+EINHEIT->Text)
  else
    @ ob+16,li+29 say space(8)
  endif

  /* 2. Spalte */
  li=41

  // Konsigbestand
  @ ob+10,li say "Inv.Bestand   " +if(empty(ARTIKEL->InvDate),space(8),dtoc(ARTIKEL->InvDate))+":"
  @ ob+16,li say "K-Lager-Bestand.......:" +str(ARTIKEL->KonsigBest,10,2)
  @ ob+18,;
    li say "K-Lager Inv.  "+if(empty(ARTIKEL->KonsigIDat),space(8),dtoc(ARTIKEL->KonsigIDat))+":"

  // Mindestbestand

  // rot darstellen falls unterschritten
  if ARTIKEL->LageBest < ARTIKEL->MinbestI
    @ ob+11,li say "Min.Bstand" color "R/"+getBackColor()
    @ ob+11,li+14 say "Ist/Soll:*" color "R/"+getBackColor()
  endif

  LAGERORT->(dbseek(ARTIKEL->Lg_Raum))
  if ! empty(LAGERORT->Text)
    ort:=trim(LAGERORT->Text)
    @ ob +4,li+32-len(ort) say space(1)+ort+space(1) color LIGHT_GRAY
  endif

  @ ob+11,li+30 say "/"+left(alltrim(str(ARTIKEL->MinBestS,6))+space(6),6)

  // Artikel Lagerbestand kontrolliert / ok?
  @ ob+6,li+34 say if(empty(ARTIKEL->Best_OK),space(2),"OK")

  // interne Auftrags Nr & KW anzeigen
  if ARTIKEL->BestInt > 0
    INNER->(dbseek(ARTIKEL->ArtNr))
    if ! INNER->(eof())
      firstKW:="99/99"
      // find 1st entry by KW
      do while ! INNER->(eof()) .and. INNER->Artnr==ARTIKEL->Artnr .and.;
        INNER->Erledigt<>'J' .and. isInnerHauptArbeitsgang()
        if kwKleiner(INNER->Lief_Kw, firstKW) == 1
          firstNr:=INNER->InnerNr
          firstKW:=INNER->Lief_Kw
        endif
        INNER->(dbskip())
      enddo
      @ ob+ 9,li say "Int. Auftr."+"("+firstNr+" "+firstKw+"):"+ str(ARTIKEL->BestInt,9,2)
      if kwKleiner(firstKw, getCurrentKW()) > 0
        @ ob+ 9,li+11 say "("+firstNr+" "+firstKw+"):" COLOR "R/"+getBackColor()
      endif
    endif
  elseif left(ARTIKEL->ArtNr,3)=="295" .and. ARTIKEL->Art=="E"
    // Rohmaterial zeige Summe Oberauftr�ge
    oAI:=ArtikelInfo():new(BEW_INNER_OBER)
    oAI:checkValid()
    nTotal:=0
    for each bew in oAI:bewegungen
      bew:ignore:=.f.
      nTotal += bew:gesmenge
    next
    @ ob+ 9,li + 24 say str(abs(nTotal),9,2)
    bewUnterNull:=oai:lagerBestandUnterNull(,,.f.) // ohne Mind.Bestand
    if bewUnterNull<>NIL
      @ ob+ 9,li say "Int. Auftr�ge     "
      @ ob+ 9,li+15 say "("+bewUnterNull:kw+")" COLOR "R/"+getBackColor()
    endif
  endif

  // externe Bestell-KW
  if ARTIKEL->BestExt > 0
    select BesPost
    aktBesPostInd:=BESPOST->(OrdSetFocus(5)) // ArtNr + KW
    BESPOST->(dbseek(ARTIKEL->ArtNr))
    do while ! BESPOST->(eof()) .and. BESAUS->Erledigt == "J" .and.;
      BESPOST->ArtNr == ARTIKEL->ArtNr
      skip
    enddo
    if BESPOST->ArtNr == ARTIKEL->ArtNr
      if kwKleiner(BESPOST->Kw, getCurrentKW()) <= 0
        @ ob+12,li+15 say " ("+BESPOST->KW+")"
      else
        @ ob+12,li+15 say " ("+BESPOST->KW+")" COLOR "R/"+getBackColor()
      endif
    else
      @ ob+12,li+15 say " (F10)"
    endif
    BESPOST->(OrdSetFocus(aktBesPostInd))
    select Artikel
  endif

  dispROIMinOrder()

return .t.
/** eof */


/** wird nach Eingabe des L�nderkennzeichen Intrastat beim Artikel ausgef�hrt */
static Function nachLandKz(oGet)
return "XX" == oGet:buffer .or. check(oGet,"Land",.t.,.f.)

/** wird nach Eingabe des Aufschlags f�r Beistellteile (VVG) ausgef�hrt. */
static Function nachBeiAufschl(oGet)
  if oGet:changed
    dispArtikelWerte()
    if BeistellPreiskalk()
      setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Getliste ausgaben nach Eingabe
      dispArtikelWerte()
    endif
  endif
return .t.

function BeistellPreiskalk()
LOCAL wasLocked:=ARTIKEL->(isLocked())

  if message("Berechnter VK: "+str(ARTIKEL->BeiAufschl+ARTIKEL->Preis1+ARTIKEL->BeiKaPr,7,2) +;
    EURO_SIGN+ " �bernehmen? (@J@/@N@)","JN"," ")=="J" .and. ! ABBRUCH
    if rec_lock(5)
      replace ARTIKEL->Preis1 with ARTIKEL->BeiAufschl+ARTIKEL->Preis1+ARTIKEL->BeiKaPr
      replace ARTIKEL->BeiAufKZ with "J"

      // Preis Historie schreiben
      Pr_prot(NIL,.f.,.t.,"TZ: "+ alltrim(str(ARTIKEL->BeiAufschl))+" " + EURO_SIGN +;
        " Beist.Ka.Pr: "+alltrim(str(ARTIKEL->BeiKaPr))+" " + EURO_SIGN)

      // TZ auf 0 setzen
      // replace ARTIKEL->BeiAufschl with 0

      dbcommit()
      if ! wasLocked
        dbunlock()
      endif
      preisKalkArtikel("NOP", wasLocked)
      dispArtikelWerte()
      return .t.
    endif
  endif
return .f.


/** wird nach Eingabe des Lagerbestandes beim Artikel ausgef�hrt */
static Function artLageBest(oGet)
LOCAL GetList:={} , diff
LOCAL s01:=savescreen()
  _thread static BewGrund

  if oGet:changed .and. val(oGet:buffer) <> oget:original

    if bewGrund==NIL
      bewGrund:=space(28)
    endif

    setcolor(COLWIN)
    Fenster(7,30,9,68)
    @ 8,32 say "Grund:" get BewGrund valid ! emptyOr2Simple(BewGrund,3) ;
      when Message("Grund f�r Bestands�nderung eingeben (mind 3 Zeichen)  @F12@=Hilfe   @ESC@=Ende")
    read
    setcolor(COLNOR)
    if ABBRUCH
      restscreen(,,,,s01)
      return .f.
    endif

    diff:=(val(oGet:Buffer)-Oget:Original)
    addWaraus(diff,"M:"+BewGrund)

    AufBestand()

    // pr�fe ob Beistellteile (KLager intern) enthalten sind
    Message("Beistellteile werden gepr�ft.      Bitte warten...")
    aendArtRekKbest( ARTIKEL->ArtNr , diff , "M:"+"Korrektur K-Lager"+BewGrund )

    if ! getUser():id $ "MW" .and. ! TEST_PROG .and. ! DEVEL_PROG
      email(MAIN_EMAIL,"Artikel Stamm �nderung: "+ARTIKEL->ArtNr,"Artikel: "+ARTIKEL->ArtNr+" "+;
        ARTIKEL->Bez1+"|"+"vorher :"+str(Oget:Original,9,2)+"  nachher:"+oget:Buffer+"|Grund  : "+;
        BewGrund+" ("+getUser():id+")|Datum  : "+dtoc(date())+"  Uhrzeit: "+time())
    endif

  endif

  restscreen(,,,,s01)
  dispArtikelWerte()

return .t.


  // ** Artikel-Display Bestell-Karte *************************
  //
// PROCEDURE ArtDiKa(/*Aendern,Sperren*/)
PROCEDURE ArtDiKa()
LOCAL GetList:={}
LOCAL ob,li,re
LOCAL M_Menge:=0,M_Geliefges:=0,M_Rest:=0

  li=3
  re=75
  ob=-2
  @ ob+ 3,0 clear
  @ ob+ 3,li say "Artikel-Nummer......: " + ARTIKEL->ArtNr

  @ ob+ 5,li say "Bezeichnung.........:" get ARTIKEL->Bez1
  @ ob+ 6,li say "                     " get ARTIKEL->Bez2
  if getUser():mayEditEK
    @ ob+ 7,li say "Einkaufspreis.......:" get ARTIKEL->EKPR picture "@Z";
      valid { |oGet| pr_prot(oGet,.f.) }
  else
    @ ob+ 7,li say "Einkaufspreis.......: "+str(ARTIKEL->EKPR,10,2)
  endif
  @ ob+ 6,li+54 say "ME:" get ARTIKEL->ME
  @ ob+ 6,li+60 say EINHEIT->Text
  @ ob+ 7,li+46 say "Kalk.Preis: " +str(ARTIKEL->KaPr,10,2)// picture "@Z" valid { |oGet| kapr_prot(oGet) }

return
/* EOP ArtDiKa */



/* Function nachArtikelArt()
*
* wird nach Eingabe der Artikel-Art. ausgef�hrt
*/
static FUNCTION nachArtikelArt(oGet)
LOCAL aSatz:={}
  // if getArtikelArt() $ "T" // Text-Artikel
  // DeleteForceValid(getList)
  // keyboard chr(K_PGDN)
  // return .t.
  // endif
  if ! oGet:buffer $ ALLE_ARTIKEL_ARTEN
    Error(ACHTUNG+"Artikel Art kann nur '"+ALLE_ARTIKEL_ARTEN+"' sein.",.t.)
    return .f.
  endif

  if oGet:buffer <> "W" .and. oGet:changed .and. ! getUser():mayCreateArticles .and.;
    getUser():mayEditTool
    Error(ACHTUNG+"Nur Werkzeug erlaubt.",.t.)
    oget:varput("W")
    return .f.
  endif

  // 24.3.2012: Text Artikel nicht mehr �nderbar nach Eingabe der Art
  if oget:buffer=="T"
    if oGet:changed()
      oGet:assign()
      replace ARTIKEL->WarenNr with ""
      replace ARTIKEL->ME with ""
      replace ARTIKEL->Erl_Gruppe with ""
      replace ARTIKEL->LandKZ with ""
      replace ARTIKEL->MinPuffer with 0
      replace ARTIKEL->KOSTNR with ""
    endif
    readKill(.t.)

    // keyboard chr(K_PGDN)
  endif

  // Aktualisiere KapR bei E und B Artikeln
  if oget:buffer=="E"
    if open("System")
      select Artikel
      replace ARTIKEL->KaPr WITH ARTIKEL->EkPr*((100+SYSTEM->Aufschlag)/100)
      //replace ARTIKEL->KaPr WITH ARTIKEL->EkPr
      dispArtikelWerte()
    endif
  elseif oget:buffer=="B"
    replace ARTIKEL->KaPr WITH 0
    dispArtikelWerte()
  endif

return .t.
/** eof */

/* Function nachSchluessel()
*
* wird nach Eingabe des Preis-Schluessel. ausgef�hrt
*/
FUNCTION nachSchluessel(oGet)
  if getArtikelArt()<>"T" .and. ! oGet:buffer$"EH"
    Error(ACHTUNG+"Preis-Schl�ssel kann nur 'E'-Einzel oder 'H'-Hunderter Preis sein.",.t.)
    return .f.
  endif
return .t.
/** eof */

/* Function nachEinheit()
*
* wird nach Eingabe der Mengen Einheit. ausgef�hrt
*/
FUNCTION nachEinheit(oGet)
  if getArtikelArt()<>"T" .and. (empty(oGET:Buffer) .or. ! check(oGet,"Einheit",.f.))
    Error(ACHTUNG+"Mengeneinheit muss eingegeben werden.",.t.)
    return .f.
  endif
  dispArtikelWerte()
return .t.
/** eof */

/*
*
* wird vor Eingabe des Inhalts ausgef�hrt
*/
FUNCTION vorME2()
  if empty( ARTIKEL->Me2 )
    Message( "Mengeneinheit Lieferant eingeben (optional).            @F12@=Hilfe" )
  else
    SetKey( K_F10 , {|| editMEFaktor()} )
    Message( "Mengeneinheit Lieferant eingeben (optional).     @F10@=Faktor �ndern   @F12@=Hilfe" )
  endif
return .t.
/** eof */

  /*
*
* wird nach Eingabe der 2.  Mengen Einheit. ausgef�hrt
*/
FUNCTION nachME2(oGet)
LOCAL merkFaktor:=ARTIKEL->ME_FAktor

  if ! check(oGet,"Einheit",.t.)
    return .f.
  endif

  if oGet:Buffer == ARTIKEL->ME .and. getArtikelArt() <> "T"
    Error(ACHTUNG+"Mengeneinheiten m�ssen unterschiedlich sein.",.t.)
    return .f.
  endif

  if oGet:changed
    if empty( oGet:Buffer )
      replace ARTIKEL->ME_FAktor with 0
      dispArtikelWerte()
    else

      if oGet:buffer <> oGet:original
        replace ARTIKEL->ME_FAktor with 0
      endif

      if ! editMEFaktor()
        replace ARTIKEL->ME_FAktor with merkFaktor
        return .f.
      endif
    endif
  endif
  SetKey( K_F10 , nil )

return .t.
/** eof */

  /*
*
* Eingabe 2. Mengeneineit
*/
FUNCTION editMEFaktor()
LOCAL GetList:={}
LOCAL aktColor , s01
LOCAL text1,text2

  EINHEIT->(dbseek(ARTIKEL->ME))
  text1:=alltrim(EINHEIT->Text)
  EINHEIT->(dbseek(ARTIKEL->ME2))
  text2:=alltrim(EINHEIT->Text)
  EINHEIT->(dbseek(ARTIKEL->ME))

  aktColor:=setcolor(COLWIN)
  s01:=savescreen()
  Fenster(14,33,16,60,"Umrechnungsfaktor:")
  Message("Umrechnungsfaktor "+text1+" nach "+text2+" eingeben.       @Hinweis:@ Faktor muss > 0 "+;
    "sein.")
  @ 15,35 say "1 " + text1 +" = " get ARTIKEL->ME_FAktor valid ARTIKEL->ME_FAktor > 0
  qqout( space(1)+text2 )
  setcolor(aktColor)
  setCargo(ATail(GetList),CARGO_FORCE_VALID,.t.) // Valid Klaus wird auch bei ESC durchgesetzt

  read
  restscreen(,,,,s01)

  dispArtikelWerte()

return !ABBRUCH
/** eof */

/*
*
* wird vor Eingabe des Inhalts ausgef�hrt
*/
FUNCTION vorInhalt()
  SetKey( K_F10 , {|| editInhaltME()} )
return .t.
/** eof */

/*
*
* wird nach Eingabe des Inhalts ausgef�hrt
*/
FUNCTION nachInhalt(oGet)

  if oGet:changed
    if empty( oGet:Buffer ) .or. val( oGet:buffer ) == 0
      replace ARTIKEL->InhaltMe with " "
      dispArtikelWerte()
    else
      editInhaltME()
    endif
  endif
  SetKey( K_F10 , nil )

return .t.
/** eof */

/*
*
* Mengeneinheit Packungsinhalt
*/
FUNCTION editInhaltME()
LOCAL GetList:={}
LOCAL aktColor , s01
LOCAL text

  EINHEIT->(dbseek(ARTIKEL->InhaltME))
  text:=alltrim(EINHEIT->Text)

  aktColor:=setcolor(COLWIN)
  s01:=savescreen()
  Fenster(15,33,17,60,"Einheit Packungsinhalt:")
  Message("Mengeneinheit Packungsinhalt "+text+" eingeben.")
  @ 16,35 say "ME:" get ARTIKEL->InhaltME
  EINHEIT->(dbseek(ARTIKEL->InhaltME))
  QQOut(space(1)+EINHEIT->Text)
  setcolor(aktColor)
  read
  restscreen(,,,,s01)

  dispArtikelWerte()

return .t.
/** eof */



Function nachIntraStat(oGet)
  // seit 3.12.14 keine Pflicht mehr

  // if getArtikelArt() $ "EFM" .and. empty(oGet:buffer) .and. ARTIKEL->Preis1 <> 0
  // // nur Hinweis, keine Pflicht
  // Error(ACHTUNG+" Bitte Intra-Stat.Nummer eingeben.",.t.)
  // // Hinweis auf Nil setzen hat nicht gelangt!
  // oGet:postBlock:={|| .t.} // deshalb Abfrage nur 1x
  // setCargo( oGet , CARGO_FORCE_VALID , .f.) // Valid Klaus wird nicht mehr durchgesetzt
  // ReadModal( { oGet } )
  // else
return check(oGet,"IntraStat", .t.)

Function KKdnr_empty(oGet)
  if oGet:changed .and. (empty(ARTIKEL->KonsigKdNr) .or. alltrim(ARTIKEL->KonsigKdNr)=="-")
    Error(ACHTUNG+" Bitte erst Konsig-KundenNummer eingeben.",.t.)
    oGet:undo()
    return .f.
  endif
return .t.

Function KKdnr_check(oGet)
LOCAL result:=.t.
  if oGet:changed .and. ! empty(oGet:buffer) .and. !oGet:buffer $ "10167-  |10363-  |     -  "
    result:=(Message(ACHTUNG+;
      " Keine Honsel/VVG Kunden-Nummer.   Trotzdem fortfahren?  ( @J@/@N@ )","JN")=="J")
    if empty(left(oGet:buffer,5))
      oget:varput(replicate(" ",len(oget:Buffer)))
    endif
  endif
return result


/** Pr�ft ob die HonselNr bereits vergeben
*/
Function doubleCheckHartNr(oGet)
LOCAL merk_Rec:=recno()
LOCAL aktOrder:=indexOrd()
LOCAL result:=.t.
LOCAL time:=seconds()
LOCAL tempStr
  if oGet:changed .and. ! empty(oGet:Buffer) .and. alltrim(no_blanks(oGet:Buffer))<>"--"
    // loesche spaces in Variante und Version
    // Honsel-Nr: XXXXXXXXXXXX-XXX-XX
    tempStr:=substr(oGet:buffer,14,3)
    if ! empty(tempStr) .and. " "$left(tempStr,2)
      tempStr:=no_blanks(tempStr)
      oget:varput(left(oget:buffer,13)+left(tempStr+"   ",3)+right(oget:buffer,3))
      oGet:updateBuffer()
    endif
    tempStr:=right(oGet:buffer,2)
    if ! empty(tempStr) .and. " "$left(tempStr,1)
      // delete spaces
      tempStr:=no_blanks(tempStr)
      oget:varput(left(oget:buffer,17)+left(tempStr+"  ",2))
      oGet:updateBuffer()
    endif
    Message("Honsel-Nummer wird gepr�ft.   Bitte warten...")
    ARTIKEL->(OrdSetFocus(2)) // HonselNr
    tempStr:=left(oget:buffer,13)
    ARTIKEL->(dbseek(tempStr))
    if ! ARTIKEL->(eof())
      do while !ARTIKEL->(eof()) .and. left(ARTIKEL->HartNr,13)==tempStr
        if ARTIKEL->HartNr==oGet:buffer .and. ARTIKEL->(recno())<>merk_rec
          result:=.f.
          exit
        endif
        skip
      enddo
      if ! result
        Error(ACHTUNG+" HonselNr. bereits vergeben: "+out(ARTIKEL->ArtNr),.t.)
        result:=.f.
      endif
    endif
    ARTIKEL->(OrdSetFocus(aktOrder))
    go (merk_rec)
  endif
return result



static function zuschlagCheck(oGet)
  if ARTIKEL->Zuschl_S<0
    return .f.
  endif
  if oGet:changed
    // berechne Soll VK neu
    if getArtikelArt() $ STKLIST_ARTIKEL
      preisKalkArtikel("NOP",.t.)
    endif
    dispArtikelWerte()
    // setCargo(oGet,CARGO_DISP_GETLIST,.t.) // Ausgabe Get-Liste
  endif
return .t.

/** Eingabe der englischen Artikel Texte
  */
PROCEDURE E_ArtDisp(x,y)
LOCAL GetList:={}
LOCAL aktColor:=setcolor(COLWIN)
LOCAL s01:=savescreen()
LOCAL isLock:=isLocked()
LOCAL aktCursor:=setcursor(DEUTE_MARKE)

  default x:=10
  default y:=25

  Fenster(x-2,y-2,x+2,y+31,"Englische Bezeichnung:")
  @ x,y get ARTIKEL->E_Bez1
  @ x+1,y get ARTIKEL->E_Bez2

  if getUser():mayEditEnglishText
    IF isLock .or. REC_LOCK(5)
      set key K_F8 to copyGermanText(NIL,oGet,NIL)
      Message("Bitte englische Bezeichnung eingeben.   @F8@=deutschen Text kopieren")
      read
      set key K_F8 to
      dbcommit()
      if ! isLock
        dbunlock()
      endif
    endif
  else
    Message("Bitte @Taste@ dr�cken.","@")
  endif
  restscreen(,,,,s01)
  setcolor(aktColor)
  setcursor(aktCursor)
return
/** eop */

/** Kopiert beim aktuellen Artikel die dt. Bezeichnung auf die engl. */
static FUNCTION copyGermanText(p1,oGet)

  ignore p1

  if empty(ARTIKEL->E_Bez1) .or. Message("Englischen Text �berschreiben?  (@J@/@N@)","JN","N")=="J"
    replace ARTIKEL->E_Bez1 with ARTIKEL->Bez1
    replace ARTIKEL->E_Bez2 with ARTIKEL->Bez2

    // Ausgabe akt. Get
    setCargo(oGet,CARGO_DISP_GETLIST,.t.)
    oGet:exitState:=GE_TOP
    oGet:KillFocus()

    // keyboard chr(K_PGDN)+chr(K_ALT_E) // redisplay
  endif

return .t.
/** eof */

  /** wird nach Eingabe eines deutschen Textes (den es auch in Englisch gibt) ausgef�hrt.
  * Hinweis: an den engl. Text denken
  *          Falls der Benutzer keine Rechte zum �ndern von ENglisch hat -> Email H. Weiland
  */
static Function englHinweis(oGet)
LOCAL subject,body
  _thread static done

  // reset only?
  if oGet==NIL .or. done==NIL
    done:=.f.
    return .t.
  endif

  if oGet:changed .and. ! done .and. (! empty(ARTIKEL->E_Bez1) .or. ! empty(ARTIKEL->E_Bez2))
    done:=.t. // nur 1x warnen bei mehreren Texten
    if getUser():mayEditEnglishText
      Error(ACHTUNG+" Bitte auch den englischen Text pr�fen.")
      E_ArtDisp()
    else
      do case
      case alias()=="ARTIKEL"
        subject:="Artikel: "+ARTIKEL->ArtNr
        body:={"Benutzer: "+getUser():getLongId(),"","Artikel: "+ARTIKEL->ArtNr,ARTIKEL->Bez1,;
          ARTIKEL->Bez2,"", "Englisch:",ARTIKEL->E_Bez1,ARTIKEL->E_Bez2}
      endcase
      email(MAIN_EMAIL,"Englischen Text pr�fen: "+subject,body)
    endif
  endif
return .t.
/** eof */

/** berechnet den Gewinn des akt. Artikels f�r die Mindest-Bestellmenge

   laut Email v. H. weiland vom 8.12.2013
   ( { VK / ([Kalku-R�stkosten] + [R�stzeit*MA-Satz/Mind.Best] } -1 )/100
*/
static procedure dispROIMinOrder()
LOCAL RuestZeit:=0, RuestKosten:=0, MaSatz:=0 , ROI
LOCAL merkOrd:=AVPOST->(indexOrd())
LOCAL aktSel:=alias() , objErr
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

  if getArtikelArt() $ "FM" .and. ARTIKEL->MinOrdInt > 0 .and. ARTIKEL->Preis1 > 0

    BEGIN SEQUENCE // krit. Bereich

      // jetzt R�stzeit etc. in St�ckliste suchen
      AVPOST->(OrdSetFocus(1)) // AVNr+Art
      SELECT AvPost
      SEEK ARTIKEL->ArtNr+"V"
      do while .not. AVPOST->(eof()) .and. AVPOST->AvNr == ARTIKEL->ArtNr .and. AVPOST->Art="V"
        // nur HauptMaschinen mit Mengenvorgabe
        if AVPOST->Text=="A" .and. AVPOST->HauptKZ=="H" .and.;
          AVPOST->SollMenge > 0 .and. AVPOST->Nutzen2 > 0
          RuestZeit:=AVPOST->RuestZeit

          // suche passende Maschine
          MASCHINE->(dbseek( AVPOST->ArtNr ))
          // if eof -> values 0 okay
          ruestKosten:=round(AVPOST->RuestZeit / AVPOST->SollMenge * MASCHINE->Kosten * ;
            AVPOST->Nutzen1 / AVPOST->Nutzen2 , 2 )
          MaSatz:=MASCHINE->Kosten
          exit // nehme nur die 1. Hauptmaschine
        endif
        skip
      enddo
      select (aktSel)
      AVPOST->(OrdSetFocus(merkOrd))

      roi:=(( ARTIKEL->Preis1 / ( (ARTIKEL->KaPr - RuestKosten) + ;
        ( RuestZeit * MaSatz / ARTIKEL->MinOrdInt ) ) ) -1 ) * 100

      @ 12,71 say space(7)
      @ 12,79 say space(1)
      @ 12,71 say "/"+alltrim(str(ARTIKEL->MinOrderS,6))+" "+alltrim(str( roi ,3))+"%"

    RECOVER USING objErr
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      fehler(objErr)
    END Sequence

  else
    @ 12,71 say "/"+alltrim(str(ARTIKEL->MinOrderS,6))
  endif
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

return
/** eof */

/** wird nach Eingabe des MinPuffers des Artikels ausgef�hrt */
static function checkMinPuffer( oGet )
  if oGet:changed

    if ARTIKEL->MinPuffer < 0
      return .f.
    endif
    WarAusJahrList("NOP",ARTIKEL->ArtNr)
    Message()
    dispArtikelWerte()
  endif
return .t.
/** eof */

/** wird nach Eingabe der MindestBestellMenge Ist MinOrderI des Artikels ausgef�hrt */
static function checkMinOrder( oGet )
  if oGet:changed

    if ! empty(ARTIKEL->RabattGr)
      RABATT->(dbseek( ARTIKEL->RabattGr ))
      if ARTIKEL->MinOrderI >= RABATT->Meng1
        Error( ACHTUNG+"Mindestbestellmenge ist gr��er als die Menge der 1. Rabattstaffel||"+;
          "         1. Rabbat-Staffel Menge: " + str(RABATT->Meng1,6) )
      endif
    endif
    dispArtikelWerte()
  endif
return .t.
/** eof */

/** wird nach Eingabe des Konsig.Inventur Bestands eines Artikels ausgef�hrt */
static function KonsigInvNach( oGet )
  if oGet:changed
    if message("K-Lager Inventur Bestand manuell �ndern? (@J@/@N@)","JN"," ")=="J"
      replace ARTIKEL->KonsigIDat with getUser():date
    else
      oget:undo()
    endif
    dispArtikelWerte()
  endif
return .t.
/** eof */

/** wird nach Eingabe des Artikel Inventur Bestands eines Artikels ausgef�hrt */
static function ArtInvNach( oGet )
  if oGet:changed
    replace ARTIKEL->InvDate with getUser():date
    dispArtikelWerte()
  endif
return .t.
/** eof */


/*
* geht in alle Artikel (Unterbaugruppen) des Artikels und �ndert
* denn K-Lager-Bestand bei internen Beistellteilen
*/
PROCEDURE aendArtRekKbest( mArtNr , diff , Grund , inventur)
LOCAL avRecno,artRecno:=ARTIKEL->(recno())
LOCAL wasLocked

  default inventur:=.f.

  select Artikel
  ARTIKEL->(dbseek( mArtNr ))

  // Falls Beistellteil -> KLagerbestand anpassen
  if getArtikelArt()=="B" .and. ! empty(ARTIKEL->KonsigKdNr)
    if (! wasLocked:=ARTIKEL->(isLocked()) )
      rec_lock(0, ARTIKEL->(recno()) ) // additive lock
    endif
    aendArtKbest( diff , Grund )

    if inventur
      // update KLager Inv.Bestand
      replace ARTIKEL->KonsigInv WITH ARTIKEL->KonsigBest
      replace ARTIKEL->KonsigIDat with getUser():date
    endif

    if ! wasLocked
      dbcommit()
      dbrunlock( ARTIKEL->(recno()) ) // unlock current record only
    endif
  endif

  /* rekursiver Aufruf, Unterartikel */
  select AvPost
  seek mArtNr+"M"
  do while ! eof() .and. mArtNr==AVPOST->AvNr .and. AvPost->Art="M" .and. AVPOST->AvNr==mArtNr
    if AVPOST->Text=="A"
      avRecno:=AVPOST->(recno())
      if AVPOST->Menge <> 0
        aendArtRekKbest( AVPOST->ArtNr , diff * AVPOST->Menge , Grund, inventur )
      endif
      select AvPost
      go (avRecno)
    endif
    skip
  enddo
  select Artikel
  ARTIKEL->(dbgoto( artRecno ))

RETURN
/* eop */


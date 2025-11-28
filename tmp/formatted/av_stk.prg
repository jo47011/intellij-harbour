/* Modul Av_stk.prg
*
* alles zu St�cklisten AV
*/

#include "miki.ch"
#include "MyMemo.ch"
#include "Memoedit.ch"

#define ERSATZTEIL_LISTE left(AVAUS->AvNr,1)=="E"

/* 
* erfassen, �ndern von St�cklisten
*
* Parameter:  Status    (mit welcher StkListe anfangen)
*               W       Werkzeug
*               M       Material
*               V       Zeit
*               I       Instruktionen
*
*             StkListNr anzuzeigende Stueckliste
*
*/
PROCEDURE Stk_Liste(art_ , StkListNr )
LOCAL Ende:=.f. , Taste:=0
LOCAL GetList:={},Datei, Titel:=hb_hash()

MEMVAR Art , StkLocked, matChanged
PRIVATE Art:=art_, StkLocked:=.f. , matChanged:=.f.

  Umgebung( WRITE_ALL )

  default StkListNr:=""

  titel["M"]:="St�ckliste:  Material"
  titel["W"]:="St�ckliste:  Werkzeug"
  titel["V"]:="St�ckliste:  Maschinen/Zeit"
  titel["I"]:="St�ckliste:  Instruktionen"

  cls
  titel( titel[M->Art] )

  if ! open( "Maschine" , "AvAus" , "AvPost" , "Artikel" , "Text" , "Einheit","ArtPreis","Mehrfach",;
    "Werk_t", "Mat_t" , "Zeit_t" , "Ins_t" ,"Instrukt","BesPost","Inner","AufPost","AufAus","Auftrag",;
    "M_Mehrf", "BesAus", "BesPost")

    Error(TRY_AGAIN)
    Umgebung( LOAD )
    RETURN
  endif


  /* Relationen setzen */
  select AvAus
  set relation to AVAUS->AvNr into Artikel // wg. F12-Hilfe
  select Instrukt
  set relation to INSTRUKT->AvNr into Artikel
  select Werk_t
  SET Rela TO WERK_T->ArtNr INTO Artikel, TO WERK_T->ArtNr INTO Text, TO WERK_T->ME INTO Einheit
  select Mat_t
  SET Rela TO MAT_T->ArtNr INTO Artikel, TO MAT_T->ArtNr INTO Text, TO MAT_T->ME INTO Einheit
  select Zeit_t
  SET Rela TO substr(ZEIT_T->ArtNr,1,3) into Maschine, TO ZEIT_T->ArtNr INTO Text,;
    TO ZEIT_T->ME INTO Einheit

  do while ! Ende

    /* l�sche temp. Dateien */
    select Werk_t
    zap
    select Mat_t
    zap
    select Zeit_t
    zap
    select Ins_t
    zap

    @ 2,0 clear

    /* gehe auf leeren Datensatz */
    select AvAus
    go bottom
    skip

    /* Kopf eingeben */
    M->StkLocked:=.f.
    if empty(StkListNr)
      av_Kopf(.t.) // mit St�cklistenNr. �ndern
    else
      AVAUS->(dbseek(StkListNr))

      // St�ckliste anlegen? falls nicht vorhanden
      if AVAUS->(eof())
        if (M->Art $ getUser():mayEditPartsList )
          ARTIKEL->(dbseek(StkListNr))

          // if ! getUser():mayEditData .and. getArtikelArt()<>"W"
          // Error(ACHTUNG+"nur St�cklisten f�r Werkzeug-Artikel k�nnen angelegt werden!",.t.)
          // return
          // endif

          @ 2,1 say 'Art.Nr.: '+out(StkListNr)
          If Message("St�ckliste nicht vorhanden.   St�ckliste anlegen? ( @J@ / @N@ )","JN")<>"J"
            Umgebung( LOAD )
            RETURN
          endif
          M->StkLocked:=.t.
          add_rec(0)
          replace AVAUS->AvNr with StkListNr
        else
          beep()
          Umgebung( LOAD )
          return
        endif
      endif

      av_Kopf(.f.)

    endif
    Ende:=ABBRUCH

    /* Abbruch mit �nderung */
    if ABBRUCH
      loop
    endif

    Message("St�ckliste wird kopiert.  Bitte warten...")

    /*** Posten kopieren ***/
    select AvPost
    seek AVAUS->AVNr

    do while AVAUS->AVNr==AVPOST->AVNr .and. ! AVPOST->(eof())
      do case
      case AVPOST->Art=="M"
        Datei:="Mat_t"
      case AVPOST->Art=="W"
        Datei:="Werk_t"
      case AVPOST->Art=="V"
        Datei:="Zeit_t"
      otherwise
        Error("Achtung: St�cklistenPosten ohne Typenbezeichnung !|"+;
          "Stkliste:"+AVPOST->AvNr+" Artikel:"+AVPOST->ArtNr+SCHWERER_FEHLER)
        skip
        loop
      endcase

      select (Datei)
      if ! add_rec(5)
        Error(TRY_AGAIN)
        loop
      endif

      // REPLACE &(Datei)->AvNr WITH AVPOST->AVNr
      // REPLACE &(Datei)->Art WITH AVPOST->Art
      // REPLACE &(Datei)->Text WITH AVPOST->Text
      // REPLACE &(Datei)->ArtNr With AVPost->ArtNr
      // REPLACE &(Datei)->Menge With AVPost->Menge
      // REPLACE &(Datei)->ME With AVPost->ME
      // REPLACE &(Datei)->HonselPos With AVPost->HonselPos
      overwrite("AvPost",.f.)
      ARTIKEL->(dbseek(AVPOST->ArtNr))
      REPLACE &(Datei)->HNr With ARTIKEL->HartNr
      select AvPost
      skip
    enddo

    /*** Instruktionen kopieren ***/
    select Instrukt
    seek AVAUS->AVNr
    do while AVAUS->AVNr==INSTRUKT->AVNr .and. ! eof()
      select Ins_t
      add_rec(0)
      replace INS_T->InsText WITH INSTRUKT->InsText
      select Instrukt
      skip
    enddo

    taste:=lastkey()
    /* Bei Auskunft evtl. Auswahl schon bei Warte-Taste
    * ansonsten Default-Anfang */
    if ! (Taste=K_F9 .or. Taste=K_F10 .or. Taste=K_F11 .or. Taste=K_F12)
      do case
      case M->Art="W"
        Taste:=K_F9
      case M->Art="M"
        Taste:=K_F10
      case M->Art="V"
        Taste:=K_F11
      case M->Art="I"
        Taste:=K_F12
      endcase
    endif

    // go top damit beim 1. Mal mit dem 1. Staz angefangen wird
    // beginnt wieder mit akt. Satz bei bearbeiten
    WERK_T->(dbgotop())
    MAT_T->(dbgotop())
    ZEIT_T->(dbgotop())
    INS_T->(dbgotop())

    /*** Posten editieren **/
    do while ! ABBRUCH

      do case
        // case Taste==K_F3 .or. Taste==K_F10 .or. Taste = 254
        // brauchen wir die 254 noch, war clipper only oder?
      case Taste==K_F10 .or. Taste = 247 .or. Taste = 254
        M->Art="M"
        titel( titel[M->Art] )
        Av_Material( MAT_T->(recno()) )
        // case Taste==K_F4 .or. Taste==K_F9 .or. Taste = 248
      case (Taste==K_F9 .or. Taste = 248)
        M->Art="W"
        titel( titel[M->Art] )
        Av_Werkzeug(WERK_T->(recno()))
        // case Taste==K_F5 .or. Taste==K_F11 .or. Taste = 216
      case (Taste==K_F11 .or. Taste = 216 )
        M->Art="V"
        titel( titel[M->Art] )
        Av_Zeit(ZEIT_T->(recno()), StkListNr)
        // case Taste==K_F6 .or. Taste==K_F12 .or. Taste = 215
      case (Taste==K_F12 .or. Taste = 215 )
        M->Art="I"
        titel( titel[M->Art] )
        Av_Instrukt()

      case taste == EDIT_QUIT .or. taste=227 // Ende nach BearbeitunsgModus
        ende:=.t.
        loop

        // // JOJO: check this
        // case ! (getUser():mayEditData .or. getUser():mayEditTool)
        // Taste:=K_F9
        // TroubleEmail("Av_stk check this."+SCHWERER_FEHLER)
        // wait
        // loop

      otherwise
        if ! DEVEL_PROG
          QOut(Taste)
          inkey(0)
          exit
        else
          Taste:=asc(Message("Bitte Taste dr�cken.","@"))
        endif
      endcase

      // Ausnahme, falls Benutzer keine Artikel anschauen kann, darf
      // er hier auch nicht umschalten. Z.B. falls aus Auskunft.
      if getUser():mayShowData
        Taste:=lastkey()
      endif

    enddo

    /* ohne Zugriff, nur anschauen : hier Ende */
    if ! (M->Art $ getUser():mayEditPartsList )
      // Ende falls "nur" vorgegebene bearbeitet wird
      if ! empty(StkListNr) .and. ! Ende
        Ende:=ABBRUCH
      endif
      // loop
    endif

    savePosten()

    // Ende falls "nur" vorgegebene bearbeitet wird
    if ! empty(StkListNr) .and. ! Ende
      Ende:=ABBRUCH
    endif

  enddo

  // if empty(StkListNr)
  // close data
  // endif

  dbcommitall()

  // unlock all -> replaced see below 20160711
  ARTIKEL->(dbunlock())
  AVAUS->(dbunlock())
  AVPOST->(dbunlock())

  // Auftragsbestand komplett neu berechnen, wenn Material ge�ndert wurde
  // es kann sich die Art.Nr ge�ndert haben
  if M->matChanged
    AufBestand()
    KLagerInternKorrektur()
  endif

  Umgebung( LOAD )

RETURN
/* EOP Stk_Liste */

/* Function Av_Kopf
*
* Eingabe des Av-kopfes
*
* Parameters: .t. == Stklisten.Nr. �nderbar
*             .f. == Stklisten.Nr. fix
* R�ckgabe  : Endee ja/nein
*/
FUNCTION Av_Kopf(edit)
LOCAL GetList:={}
LOCAL ob:=2
  _thread static M_AvNr

  if M_AvNr==NIL
    M_AvNr:=space(len(AVAUS->AvNr))
  endif

  @ ob,1 say 'Art.Nr.:'

  if ! edit
    M_AvNr:=AVAUS->AvNr
    @ ob,10 say out(M_AvNr)
  else
    @ ob,10 get M_AvNr PICTURE '@K!' valid ;
      { |oGet| myAVcheck(oGet)};
      when Message("St�cklisten-Nummer eingeben.        @F12@=Hilfe")
    // GetList[1]:cargo:="A" // Getliste ausgaben nach Eingabe
    read
    if ABBRUCH
      return .f.
    endif
  endif
  @ ob ,25 say ARTIKEL->Bez1
  @ ob+1,25 say ARTIKEL->Bez2
  @ ob+2,1 to ob+2,78
  @ ob+3,1 say 'Text:'

  do case
  case M->Art="M"
    @ ob+3,10 get AVAUS->Bem1 when Message("Text eingeben.")
    @ ob+4,10 get AVAUS->Bem2
    @ ob+5,10 get AVAUS->Bem3
    @ ob+6,10 get AVAUS->Bem4
  case M->Art="W"
    @ ob+3,10 get AVAUS->Wkz_Bem1 when Message("Text eingeben.")
    @ ob+4,10 get AVAUS->Wkz_Bem2
    @ ob+5,10 get AVAUS->Wkz_Bem3
    @ ob+6,10 get AVAUS->Wkz_Bem4
  otherwise
    return .t.
  endcase

  /* Falls kein Zugriff, warte auf Tastendruck */

  if ! (M->Art $ getUser():mayEditPartsList)
    Message("Bitte Taste dr�cken.       @ESC@=Ende","@")
  else
    if upper(Message("Bitte Taste dr�cken zum Fortfahren.   @�@ndern  @ESC@=Ende","@"))$"BA�"
      if lock_StkList()
        read
      endif
    endif
  endif


RETURN(.t.)
/* EOF AufKopf */


/*
* Eingabe der StkListen-Posten: Material
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
STATIC FUNCTION Av_Material(starteBeiRecno)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL erg:=.f., extraMessage

  select Mat_t

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || Stk_Satz_nach() }
  aKopf[EDIT_INDEX_FELD]:=2
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Av_Text()}
  aKopf[EDIT_CONFIRM_LOESCHE]:=.t.
  aKopf[EDIT_KOPF_FKT]:={ || Av_Kopf(.f.) } // wird im Doppelmodus bei Eingabe
  // von K ausgef�hrt
  // aKopf[EDIT_ENDE]:=chr(K_F3)+chr(K_F4)+chr(K_F5)+chr(K_F6)+;
  // chr(K_F9)+chr(K_F10)+chr(K_F11)+chr(K_F12)
  aKopf[EDIT_ENDE]:=chr(K_F9)+chr(K_F10)+chr(K_F11)+chr(K_F12)

  aKopf[EDIT_FKT_IMMER]:={ || checkAvKonsistenz("MAT_T") } // wird nach Eingabe des Posten ausgef�hrt

  if valtype(starteBeiRecno)=="N"
    aKopf[EDIT_START_REC]:=starteBeiRecno
  endif

  // Edit- oder Ansichts-Modus?
  aKopf[EDIT_EXTRA_FKT]:={}
  if getUser():mayPrint
    Aadd(aKopf[EDIT_EXTRA_FKT], { "D"," @D@rucken", { || Stk_druck()} } )
  endif

  extraMessage = "@F9@=Werkz. @F11@=Zeit @F12@=Instr."

  // Benutzer darf editieren
  if M->Art $ getUser():mayEditPartsList

    aadd(aKopf[EDIT_EXTRA_FKT],{ "K"," @K@op.", { || Stk_kop()} })

    // Standard-Funktionen �berlagern -> vorher St�ckliste locken!
    aKopf[EDIT_GESPERRT]:="�ALlNE"+chr( K_CTRL_DOWN )+chr( K_CTRL_UP )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "��Aa"+HARBOUR_AE ,"", { || lockChange()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_UP ) ,"", { || lockCtrlUp() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_DOWN ) ,"", { || lockCtrlDown() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Nn" ,"", { || lockAppend()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ee" ,"", { || lockInsert()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ll" ,"", { || lockDelete()} } )

    /** Funktionstasten sollen Get beenden ! */
    SetKey( K_F9, {|| readkill(.T.) } )
    SetKey( K_F10, {|| readkill(.T.) } )
    SetKey( K_F11, {|| readkill(.T.) } )
    // SetKey( K_F12, {|p, l, v| readkill(.T.) } ) // disabled! soll in ArtNr Hilfe anzeigen und nicht Inst.

  else // Benutzer darf NICHT editieren
    aKopf[EDIT_GESPERRT]:="KN�AEL"
  endif
  aadd(aKopf[EDIT_EXTRA_FKT], ;
    { chr(K_F5), nil , { || MyStkListLind() } } )

  aadd(aKopf[EDIT_EXTRA_FKT], ;
    { chr(K_F6)," @F5@=aufl. @F6@=Stkl. " + extraMessage, ;
    { || if( MAT_T->Text$"A" , MatArtikelListe() , nil )} } )

  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Text"
  aSpalte[EDIT_NAME_GET]:="AV_Text"
  if ERSATZTEIL_LISTE
    aSpalte[EDIT_TITEL]:="A"
  else
    aSpalte[EDIT_TITEL]:="Art"
  endif
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AFTER]:={ |oGet| MAT_T->Text$"AT" .and. ArtNach(oGet) }
  aSpalte[EDIT_ERSATZ_1]:={ || MAT_T->Text=="T" }
  // aSpalte[EDIT_ERSATZ_2]:={ || (alias())->Text=="Z"}
  aSpalte[EDIT_AUSGABE]:=.t. // n�tig , falls Zuschlag
  aSpalte[EDIT_MESSAGE]:="Art eingeben.  @A@rtikel/@T@ext"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Artikel-Nr
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. ArtnrNach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer eingeben.         @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_DUPLICATES]:=;
    { || if( (alias())->Text=="A" .and. left(AVAUS->AvNr,1)<>"E" , (alias())->ArtNr , NIL ) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // KZ
  aSpalte[EDIT_NAME]:="ARTIKEL->WKZ"
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // aSpalte[EDIT_NAME]:="ARTIKEL->Bez2"
  // aSpalte[EDIT_POS_Y]:=1
  // aSpalte[EDIT_EDIT]:=.f.

  // aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  // aSpalte:=e_fill() // initialisieren

  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MASKE]:={ || getPictNachkomma(9 , MAT_T->ME,"1") }
  aSpalte[EDIT_AFTER]:={ |oGet| MatMengeNach(oGet) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Mengeinheit
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  if ERSATZTEIL_LISTE
    // HonselNr
    aSpalte[EDIT_NAME]:="HNr"
    aSpalte[EDIT_TITEL]:="Honsel-Nr."
    aSpalte[EDIT_AFTER]:={ |oGet| HNr_nach(oGet) }
    aSpalte[EDIT_MASKE]:="XXXXXXXXXXXX-XXX-XX"
    aSpalte[EDIT_MESSAGE]:="Honsel_Artikel-Nummer eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Pos.Nr
    aSpalte[EDIT_NAME]:="HonselPos"
    aSpalte[EDIT_TITEL]:="Pos."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

  else

    // demontierbare Baugruppe
    aSpalte[EDIT_NAME]:="Volatile"
    aSpalte[EDIT_TITEL]:="KZ"
    aSpalte[EDIT_MESSAGE]:="Oberbaugruppen anzeigen?  (@J@/@N@)"
    aSpalte[EDIT_MASKE]:="!"
    aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer $ "JN " .or. lastkey() == K_UP }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Lagerort
    aSpalte[EDIT_NAME]:="getArtikelLagerOrt(14)"
    aSpalte[EDIT_TITEL]:="Lager-Ort"
    aSpalte[EDIT_EDIT]:=.f.

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren
  endif


  /**** ENDE Feld-Definitionen ***/
  erg:=Edit(aFelder,aKopf)

  SetKey( K_F9, NIL )
  SetKey( K_F10,NIL )
  SetKey( K_F11,NIL )
  // SetKey( K_F12,NIL )
  // set key HILFE_TASTE2 to Hilfe // Hilfe-Proc

RETURN( erg )
  /* EOF Av_Material */

static function artnach(oGet)
LOCAL aktSel:=alias()
  if oget:changed
    replace (AKTSEL)->ArtNr with space(len((AKTSEL)->ArtNr))
  endif
return .t.
/** eof */

/* ***************************************
*
* Eingabe der StkListen-Posten: Werkzeug
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
STATIC FUNCTION Av_Werkzeug(starteBeiRecno)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL erg:=.f.
LOCAL orgAltT:=SetKey( K_ALT_T )

  select Werk_t

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_NEW_FKT]:={ || Stk_Satz_nach() }
  aKopf[EDIT_INDEX_FELD]:=2
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Av_Text()}
  aKopf[EDIT_CONFIRM_LOESCHE]:=.t.
  aKopf[EDIT_KOPF_FKT]:={ || Av_Kopf(.f.) } // wird im Doppelmodus bei Eingabe
  // von K ausgef�hrt
  // aKopf[EDIT_ENDE]:=chr(K_F3)+chr(K_F4)+chr(K_F5)+chr(K_F6)+;
  // chr(K_F9)+chr(K_F10)+chr(K_F11)+chr(K_F12)+chr(K_F8)
  aKopf[EDIT_ENDE]:=chr(K_F9)+chr(K_F10)+chr(K_F11)+chr(K_F12)

  aKopf[EDIT_FKT_IMMER]:={ || checkAvKonsistenz("WERK_T") } // wird nach Eingabe des Posten ausgef�hrt

  if valtype(starteBeiRecno)=="N"
    aKopf[EDIT_START_REC]:=starteBeiRecno
  endif

  // Edit- oder Ansichts-Modus?
  aKopf[EDIT_EXTRA_FKT]:={}
  if getUser():mayPrint
    Aadd(aKopf[EDIT_EXTRA_FKT], { "D"," @D@rucken", { || Stk_druck()} } )
  endif

  // Benutzer darf editieren
  if M->Art $ getUser():mayEditPartsList
    aadd(aKopf[EDIT_EXTRA_FKT],{ "K"," @K@opieren", { || Stk_kop()} })
    aadd(aKopf[EDIT_EXTRA_FKT],{ "T"," @T@=Mehrf.", { || Art_Mehrfach() } })

    // Standard-Funktionen �berlagern -> vorher St�ckliste locken!
    aKopf[EDIT_GESPERRT]:="�ALlNE"
    Aadd(aKopf[EDIT_EXTRA_FKT], { "��Aa"+HARBOUR_AE ,"", { || lockChange()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_UP ) ,"", { || lockCtrlUp() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_DOWN ) ,"", { || lockCtrlDown() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Nn" ,"", { || lockAppend()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ee" ,"", { || lockInsert()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ll" ,"", { || lockDelete()} } )

    /** Funktionstasten sollen Get beenden ! */
    SetKey( K_F9, {|| readkill(.T.) } )
    SetKey( K_F10, {|| readkill(.T.) } )
    SetKey( K_F11, {|| readkill(.T.) } )
    // SetKey( K_F12, {|p, l, v| readkill(.T.) } ) // disabled! soll in ArtNr Hilfe anzeigen und nicht Inst.

    // ALT-T zum �ndern von AV Text
    SetKey( K_ALT_T , { || avTextAend() } )

  else // Benutzer darf NICHT editieren
    aKopf[EDIT_GESPERRT]:="KN�AEL"
  endif
  aadd(aKopf[EDIT_EXTRA_FKT], ;
    { chr(K_F6)," @F6@=Stkl. @F10@=Material @F11@=Zeit @F12@=Instrukt. ", ;
    { || if( WERK_T->Text$"A" , MatArtikelListe() , nil )} } )


  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Text"
  aSpalte[EDIT_NAME_GET]:="AV_Text"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AFTER]:={ |oGet| MAT_T->Text$"AT" .and. ArtNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Art eingeben.     @A@ = Werkzeug     @T@ = Text      @ESC@ = Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || WERK_T->Text=="T" }
  // aSpalte[EDIT_ERSATZ_2]:={ || (alias())->Text=="Z"}
  aSpalte[EDIT_AUSGABE]:=.t. // n�tig , falls Zuschlag

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Artikel-Nr
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_TITEL]:="Art.Nr."
  aSpalte[EDIT_MASKE]:="@K@!"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Artikel",.f.) .and. ArtnrNach(oGet) } // kein leeres Feld erlaubt
  aSpalte[EDIT_DUPLICATES]:=;
    { || if( (alias())->Text=="A" , (alias())->ArtNr , NIL ) }
  aSpalte[EDIT_MESSAGE]:="Artikel-Nummer (Werkzeug) eingeben.         @F12@=Hilfe              @ESC@=Ende"

  // aSpalte[EDIT_DUPLICATES]:=
  // { || if( (alias())->Text=="A" .and. left(AVAUS->AvNr,1)<>"E" , (alias())->ArtNr , NIL ) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="ARTIKEL->Bez1"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="ARTIKEL->Bez2"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren


  // Menge
  aSpalte[EDIT_NAME]:="Menge"
  aSpalte[EDIT_TITEL]:="Menge"
  aSpalte[EDIT_MASKE]:={ || getPictNachkomma(9 , WERK_T->ME) }
  aSpalte[EDIT_MESSAGE]:="Menge eingeben."

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Mengeinheit
  aSpalte[EDIT_NAME]:="EINHEIT->Text"
  aSpalte[EDIT_TITEL]:="ME"
  aSpalte[EDIT_POS_X]:=5
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Lagerort
  aSpalte[EDIT_NAME]:="getArtikelLagerOrt(14)"
  aSpalte[EDIT_TITEL]:="Lager-Ort"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  /**** ENDE Feld-Definitionen ***/
  erg:=Edit(aFelder,aKopf)

  SetKey( K_F9, NIL )
  SetKey( K_F10,NIL )
  SetKey( K_F11,NIL )
  SetKey( K_ALT_T, orgAltT )

RETURN( Erg )
/* EOF */

/*
* Eingabe der StkListen-Posten: Zeit
* R�ckgabe:     Taste mit der Editor verlasen wurde
*/
STATIC FUNCTION Av_Zeit(starteBeiRecno, StkListNr)
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]
LOCAL erg:=.t., is_mehrfach, stueckliste
LOCAL aktRec:=ARTIKEL->(recno())

  select Zeit_t

  ARTIKEL->(dbseek(StkListNr))
  stueckliste:=stueckListe():new( StkListNr, ARTIKEL->Art )
  ARTIKEL->(dbgoto(aktRec))

  is_mehrfach:=stueckliste:hasMehrfachEntry()

  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=6 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  if is_mehrfach
    aKopf[EDIT_LINES]:=2 // N: Anzahl Zeilen pro Zeile
  else
    aKopf[EDIT_LINES]:=1 // N: Anzahl Zeilen pro Zeile
  endif
  aKopf[EDIT_NEW_FKT]:={ || Stk_Satz_nach() }
  aKopf[EDIT_INDEX_FELD]:={ || empty(ZEIT_T->ArtNr)}
  aKopf[EDIT_ERSATZ_ARRAY]:={ || Av_Text()}
  aKopf[EDIT_CONFIRM_LOESCHE]:=.t.
  aKopf[EDIT_ENDE]:=chr(K_F9)+chr(K_F10)+chr(K_F11)+chr(K_F12)
  aKopf[EDIT_AFTER_EDIT_FKT]:={ || copyNutzen() }

  aKopf[EDIT_FKT_IMMER]:={ || checkZeitKonsistenz() } // wird nach Eingabe des Posten ausgef�hrt

  if valtype(starteBeiRecno)=="N"
    aKopf[EDIT_START_REC]:=starteBeiRecno
  endif

  // Edit- oder Ansichts-Modus?
  aKopf[EDIT_EXTRA_FKT]:={}
  if getUser():mayPrint
    Aadd(aKopf[EDIT_EXTRA_FKT], { "D"," @D@rucken", { || Stk_druck()} } )
  endif

  // Benutzer darf editieren
  if M->Art $ getUser():mayEditPartsList

    aadd(aKopf[EDIT_EXTRA_FKT],{ "K"," @K@opieren", { || Stk_kop()} })

    // Standard-Funktionen �berlagern -> vorher St�ckliste locken!
    aKopf[EDIT_GESPERRT]:="�ALlNE"+"Z"
    Aadd(aKopf[EDIT_EXTRA_FKT], { "��Aa"+HARBOUR_AE ,"", { || lockChange()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_UP ) ,"", { || lockCtrlUp() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { chr( K_CTRL_DOWN ) ,"", { || lockCtrlDown() } } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Nn" ,"", { || lockAppend()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ee" ,"", { || lockInsert()} } )
    Aadd(aKopf[EDIT_EXTRA_FKT], { "Ll" ,"", { || lockDelete()} } )

    SetKey( K_F8, {|| StkKalkUeber() } )

    /** Funktionstasten sollen Get beenden ! */
    SetKey( K_F9, {|| readkill(.T.) } )
    SetKey( K_F10, {|| readkill(.T.) } )
    SetKey( K_F11, {|| readkill(.T.) } )
    // SetKey( K_F12, {|p, l, v| readkill(.T.) } ) // disabled! soll in ArtNr Hilfe anzeigen und nicht Inst.

  else // Benutzer darf NICHT editieren
    aKopf[EDIT_GESPERRT]:="KN�AELZ"
  endif
  Aadd(aKopf[EDIT_EXTRA_FKT], { "T","", { || Art_Mehrfach() , __Keyboard(chr(FKT_SPECIAL))}} )
  Aadd(aKopf[EDIT_EXTRA_FKT], { chr(K_F6),"", { || Stk_MaschDisp()} } )
  Aadd(aKopf[EDIT_EXTRA_FKT], ;
    { chr(K_F8)," @T@=Mehrf. @F6@=Masch. @F8@=Kalk.�bers. @F9@=Wkz @F10@=Mat. @F12@=Instr.", ;
    { || StkKalkUeber()} } )

  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Text"
  aSpalte[EDIT_NAME_GET]:="AV_Text"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AFTER]:={|oGet| textNach(oGet) }
  aSpalte[EDIT_MESSAGE]:="Art eingeben.     @A@ = Zeit         @T@ = Text       @ESC@ = Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || ZEIT_T->Text=="T" }
  // aSpalte[EDIT_ERSATZ_2]:={ || (alias())->Text=="Z"}
  aSpalte[EDIT_AUSGABE]:=.t. // n�tig , falls Zuschlag

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Artikel-Nr
  aSpalte[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_NAME_GET]:="StdNr"
  aSpalte[EDIT_BEFORE]:={ || ZEIT_T->Text$"AT" .and. SetMyKey( K_F6 , { || Stk_MaschDisp()}) }
  aSpalte[EDIT_TITEL]:="Nr."
  aSpalte[EDIT_MASKE]:="@K XXX"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Maschine",.f.) .and. ArtnrNach(oGet) .and. ;
    SetMyKey( K_F6 , NIL) } // kein leeres Feld erlaubt
  aSpalte[EDIT_MESSAGE]:="Arbeitszeit eingeben.         @F12@=Hilfe              @ESC@=Ende"
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_DUPLICATES]:=;
    { || if( (alias())->Text=="A" .and. left(AVAUS->AvNr,1)<>"E" , (alias())->ArtNr , NIL ) }

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text
  aSpalte[EDIT_NAME]:="if(ZEIT_T->Text=='A',MASCHINE->Bez,if(ZEIT_T->Text=='R',left('R�stzeit'+space(30),30),space(30)))"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  ARTIKEL->(dbseek(AVAUS->AvNr))
  if getArtikelArt()=="D" // Dienstleistung -> nur "R�stzeit"
    // R�stzeit == Dauer
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="RuestZeit"
    aSpalte[EDIT_TITEL]:="Dauer (h)"
    aSpalte[EDIT_MASKE]:="@Z"
    aSpalte[EDIT_MESSAGE]:="Dauer in Stunden eingeben."
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Tage/stunden
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="getStdTagText(ZEIT_T->Ruestzeit)"
    aSpalte[EDIT_TITEL]:="Tage/Stunden"
    aSpalte[EDIT_EDIT]:=.f.
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

  else // normaler F/X etc Artikel

    // Menge
    aSpalte[EDIT_NAME]:="Menge"
    aSpalte[EDIT_TITEL]:="Menge"
    aSpalte[EDIT_BEFORE]:={ || ZEIT_T->HauptKz=="H" }
    aSpalte[EDIT_AFTER]:={|oGet| mengeNach(oGet) }
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_MESSAGE]:="Menge eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    // Haupt oder Nebenmaschine
    aSpalte[EDIT_NAME]:="HauptKZ"
    aSpalte[EDIT_TITEL]:="H/N"
    aSpalte[EDIT_MASKE]:="!"
    aSpalte[EDIT_AUSGABE]:=.t.
    aSpalte[EDIT_BEFORE]:={ || ZEIT_T->Text=="A" }
    aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer$"HN" .and. hauptNach(oGet)}
    aSpalte[EDIT_MESSAGE]:="@H@aupt- oder @N@ebenmaschine eingeben."

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
    aSpalte:=e_fill() // initialisieren

    if is_mehrfach
      // Nutzen Divisor
      aSpalte[EDIT_NAME]:="getMehrfNutzen()"
      aSpalte[EDIT_TITEL]:="Nutzen"
      aSpalte[EDIT_EDIT]:=.f.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    else
      // Nutzen Divident
      aSpalte[EDIT_NAME]:="Nutzen1"
      aSpalte[EDIT_TITEL]:="Nutzen"
      aSpalte[EDIT_MASKE]:="99"
      aSpalte[EDIT_AFTER]:={ |oGet| val(oGet:buffer)>0 }
      aSpalte[EDIT_BEFORE]:={ || ZEIT_T->Text$"A"}
      aSpalte[EDIT_MESSAGE]:="Nutzen (Divident) eingeben."

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // geteilt durch
      aSpalte[EDIT_NAME]:="'/'"
      aSpalte[EDIT_TITEL]:=""
      aSpalte[EDIT_POS_X]:=-5
      aSpalte[EDIT_EDIT]:=.f.

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren

      // Nutzen Divisor
      aSpalte[EDIT_NAME]:="Nutzen2"
      aSpalte[EDIT_TITEL]:=""
      aSpalte[EDIT_POS_X]:=-1
      aSpalte[EDIT_MASKE]:="99"
      aSpalte[EDIT_AFTER]:={ |oGet| val(oGet:buffer)>0 .and. ZEIT_T->Nutzen2>=ZEIT_T->Nutzen1 }
      aSpalte[EDIT_BEFORE]:={ || ZEIT_T->Text$"A"}
      aSpalte[EDIT_MESSAGE]:="Nutzen (Divisor) eingeben."

      aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
      aSpalte:=e_fill() // initialisieren
    endif


    // automatisch, d.h. ohne Personal
    aSpalte[EDIT_NAME]:="Automat"
    aSpalte[EDIT_TITEL]:="Auto"
    aSpalte[EDIT_POS_X]:=1
    aSpalte[EDIT_BEFORE]:={ || ZEIT_T->HauptKz=="H" }
    aSpalte[EDIT_AFTER]:={ |oGet| oGet:buffer$"JN"}
    aSpalte[EDIT_MASKE]:="!"
    aSpalte[EDIT_MESSAGE]:="Maschine l�uft automatisch, d.h. ohne Personal (@J@/@N@)."
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen#

    // R�stzeit
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="RuestZeit"
    aSpalte[EDIT_TITEL]:="R�stz."
    aSpalte[EDIT_BEFORE]:={ || ZEIT_T->HauptKz=="H" .and. RuestZeitF12(.t.) }
    aSpalte[EDIT_AFTER]:={ || RuestZeitF12(.f.) }
    aSpalte[EDIT_MASKE]:="@Z"
    aSpalte[EDIT_MESSAGE]:="R�stzeit in Stunden eingeben.    @F12@=Standard-R�stzeit �bernehmen"
    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen

    // Durchschnittsmenge f�r R�stzeit-Berechnung
    aSpalte:=e_fill() // initialisieren
    aSpalte[EDIT_NAME]:="SollMenge"
    aSpalte[EDIT_TITEL]:=DURCHSCHNITT_SIGN+" Menge"
    aSpalte[EDIT_MESSAGE]:="Durchschnittsmenge je Auftrag f�r R�stzeitberechnung eingeben."
    aSpalte[EDIT_BEFORE]:={ || ZEIT_T->HauptKz=="H" }
    aSpalte[EDIT_MASKE]:="@Z"
    aSpalte[EDIT_AFTER]:={ |oGet| sollMengeNach(oGet) }

    aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  endif

  /**** ENDE Feld-Definitionen ***/
  dbskip(0) // relation wieder aktualisieren
  erg:=Edit(aFelder,aKopf)

  SetKey( K_F6 , NIL)
  SetKey( K_F8, NIL )
  SetKey( K_F9, NIL )
  SetKey( K_F10,NIL )
  SetKey( K_F11,NIL )
  RuestZeitF12(.f.)

  // SetKey( K_F12,NIL )
  // set key HILFE_TASTE2 to Hilfe // Hilfe-Proc

RETURN( erg )
/* EOF  */

/* Function Av_Text ***************************
*
* alternativ Spaltendef. bei Text eingabe *
* Ersatz-Array
*/
STATIC FUNCTION Av_Text
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]

  /* Feld-Definitionen */
  // Art
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Text"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="!"
  aSpalte[EDIT_AFTER]:={ || (alias())->Text$"AT" }
  aSpalte[EDIT_MESSAGE]:="Art eingeben.     @A@ = Artikel      @T@ = Text      @ESC@ = Ende"
  aSpalte[EDIT_ERSATZ_1]:={ || (alias())->Text=="T" }
  // aSpalte[EDIT_ERSATZ_2]:={ || (alias())->Text=="Z"}

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  // Text-Nr
  ASPALTE[EDIT_NAME]:="ArtNr"
  aSpalte[EDIT_NAME_GET]:="TextNr"
  aSpalte[EDIT_TITEL]:="Art"
  aSpalte[EDIT_MASKE]:="@K XXX"
  aSpalte[EDIT_AFTER]:={ |oGet| check(oGet,"Text",.f.) }
  aSpalte[EDIT_AUSGABE]:=.t.
  aSpalte[EDIT_MESSAGE]:="Text-Nummer eingeben.      @F12@=Hilfe"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren
  // Text
  aSpalte[EDIT_NAME]:="TEXT->Text"
  aSpalte[EDIT_TITEL]:="Text"
  aSpalte[EDIT_POS_X]:=7
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

RETURN(aFelder)
/* EOF Av_Text */



/* Function Stk_Satz_nach()
*
* wird nach hinzuf�gen eines neuen Satzes ausgef�hrt
*/
FUNCTION Stk_Satz_nach
LOCAL aktRec, m

  replace (alias())->AvNr with AVAUS->AvNr // neu am 29.1.13
  replace (alias())->Text with "A" // Artikel ist default
  replace (alias())->Art with M->Art

  if alias()=="ZEIT_T"
    aktRec:=ZEIT_T->(recno())

    // nehme Menge & Nutzen von der Hauptmaschine obendr�ber
    do while ! BOF() .and. ! (ZEIT_T->HauptKZ=="H" .and. ZEIT_T->Text=="A")
      skip -1
    enddo
    if (ZEIT_T->HauptKZ=="H" .and. ZEIT_T->Text=="A")
      m:=ZEIT_T->Menge
    endif
    go (aktRec)
    if m<>NIL
      replace ZEIT_T->Menge with m
    endif
  endif

RETURN(.t.)


/* Function ArtnrNach()
*
* wird nach Eingabe der Artikel-Nr. ausgef�hrt
*/
static FUNCTION ArtnrNach(oGet)

  if oGet:Buffer==AVAUS->AvNr
    Error(ACHTUNG+"St�ckliste kann sich NICHT selbst enthalten !",.t.)
    RETURN(.f.)
  endif

  if empty(oGet:Buffer) .and. lastkey()==K_UP
    return .t.
  endif

  // neu 11.4.2011: keine Text-Artikel in St�ckliste mehr
  if getArtikelArt()=="T" // bereits oben abgefragt: WERK_T->Text=="A" .and.
    Error(ACHTUNG+"keine Text-Artikel k�nnen hinzugef�gt werden!|";
      +"         Bitte St�cklisten-Texte (Art=T) verwenden.",.t.)
    return .f.
  endif
  IF upper(alias()) $ "WERK_T MAT_T" .and. (alias())->Text=="A"
    replace (alias())->me with ARTIKEL->ME
    replace (alias())->HNr with ARTIKEL->HartNr

    // jojo macht das Sinn?
    IF upper(alias()) $ "WERK_T"
      if !getArtikelArt()$"WEB"
        Error(ACHTUNG+"nur Werkzeuge, Einkaufsartikel und Beistellteile erlaubt!",.t.)
        return .f.
      endif

      // raus am 1.10.2010 jojo
      // replace (alias())->Menge with ARTIKEL->Lagebest

    else // Abfrage oben: IF upper(alias()) $ "MAT_T"

      // raus am 1.10.2010 jojo
      // if getArtikelArt()="X"
      // Error(ACHTUNG+"Ex-Artikel kann nicht verwendet werden!",.t.)
      // return .f.

      if getArtikelArt()="W"
        Error(ACHTUNG+"Werkzeug nur in Werkzeugst�ckliste zugelassen!",.t.)
        return .f.
      endif
    endif
  endif

  // Haupt- Nebenmaschine bei Zeiten
  IF oget:changed .and. upper(alias()) $ "ZEIT_T"
    if (alias())->Text=="A"
      replace ZEIT_T->HauptKz with MASCHINE->HauptKZ
      // Regel-R�stzeit kopieren
      replace ZEIT_T->Ruestzeit with MASCHINE->RuestZeit
      replace ZEIT_T->Automat with " "
      if MASCHINE->HauptKZ=="H"
        replace ZEIT_T->Automat with "N"
      else
        replace ZEIT_T->Automat with "J"
      endif
    else
      replace ZEIT_T->HauptKz with " "
      replace ZEIT_T->Automat with " "
      replace ZEIT_T->Ruestzeit with 0
    endif
  endif

  // merker setzen falls Material ge�ndert wird
  IF upper(alias()) $ "MAT_T" .and. oGet:changed
    M->matChanged:=.t.
  endif


RETURN(.t.)

/*
*
* wird nach Eingabe der Menge bei Material ausgef�hrt
*/
static FUNCTION MatMengeNach(oGet)

  // merker setzen falls Material ge�ndert wird
  IF oGet:changed
    M->matChanged:=.t.
  endif

RETURN(.t.)

/*
* wird vor der R�stzeit ausgef�hrt
*/
static FUNCTION RuestZeitF12( before )
  static oldF12
  if before
    if oldF12 == nil
      oldF12 = SetKey( K_F12 , { || MaschCopyRuest()})
    endif
  else
    if oldF12 <> nil
      SetKey( K_F12 , oldF12 )
    endif
    oldF12:=nil
  endif
return .t.
/** eof */

  /*
* �bernimmt die Standard R�stzeit aus dem Maschinenstamm
*/
static FUNCTION MaschCopyRuest()
LOCAL F12:=SetKey( K_F12 , { || NIL})

  MASCHINE->(dbseek( trim(ZEIT_T->ArtNr) ))
  if MASCHINE->(eof()) // should never happen
    Error(ACHTUNG+"Maschine: " + trim(ZEIT_T->ArtNr) + " nicht gefunden!",.t.)
  else
    if Stk_MaschDisp(.t.)
      replace ZEIT_T->Ruestzeit with MASCHINE->RuestZeit
    endif
  endif
  SetKey( K_F12 , F12 )

RETURN(.t.)

/* Function HNr_nach()
*
* wird nach Eingabe der Honsel-Artikel-Nr. ausgef�hrt
*/
FUNCTION Hnr_nach(oGet)
LOCAL datei:=alias()
  if oGet:changed
    select Artikel
    // rec_lock(0) // Artikel ist bereits gelockt
    replace ARTIKEL->HartNr with oGet:Buffer
    dbcommit()
    select (datei)
  endif
RETURN(.t.)

/*
* wird nach Eingabe der Soll Menge Zeit eingegeben
*/
static FUNCTION sollMengeNach(oGet)
LOCAL datei:=alias(),aktRec:=recno()

  if oGet:changed .and. ZEIT_T->HauptKz=="H"
    // alle (!) anderen Hauptmaschinen updaten
    if ZEIT_T->(reccount())>1
      aktRec:=ZEIT_T->(recno())

      replace ZEIT_T->SollMenge with val(oGet:Buffer);
        for (ZEIT_T->HauptKZ=="H" .and. ZEIT_T->Text=="A")

      go (aktRec)

    endif

  endif
RETURN(.t.)


/* Function Stk_kop *********************************************
*
* zum kopieren kompletter St�cklisten
*
* ACHTUNG: eventuelles Lock auf aktueller St�ckliste geht kurz verloren :(
*          Problem da in pure Clipper kein Multilock m�glich
*          FIXME: in harbou geht's!
*/
FUNCTION Stk_Kop
LOCAL M_AvNr:=space(len(AVAUS->AvNr))
LOCAL GetList:={} , Inhalt:={} , i:=0
LOCAL _Bem1,_Bem2,_Bem3,_Bem4,_WKZ_BEM1,_WKZ_BEM2,_WKZ_BEM3,_WKZ_BEM4
LOCAL aktArtikelRecno,alle:=.f.
LOCAL Merk_AvSatz:=AVAUS->(recno())
LOCAL akt_Datei:=alias()

  Umgebung( WRITE_ALL )

  /* kopiere aktuelle Felder */
  _Bem1:=AVAUS->Bem1
  _Bem2:=AVAUS->Bem2
  _Bem3:=AVAUS->Bem3
  _Bem4:=AVAUS->Bem4
  _WKZ_Bem1:=AVAUS->WKZ_Bem1
  _WKZ_Bem2:=AVAUS->WKZ_Bem2
  _WKZ_Bem3:=AVAUS->WKZ_Bem3
  _WKZ_Bem4:=AVAUS->WKZ_Bem4

  @ 1,60 say "kopieren nach:"
  Do Message WITH 'St�cklisten-Nummer (Artikel) eingeben.             @F12@ = Hilfe'
    @ 2,60 say 'Art.Nr.:'
    @ 2,69 get M_AvNr PICTURE '@!@K'
    read
    AVAUS->(dbgoto( Merk_AvSatz )) // zur�ck auf Urpsrungssatz, da F12 Posotion in AvAus ver�ndert
    If lastkey()==K_ESC .or. empty(M_AvNr)
      Umgebung(LOAD)
      RETURN(.t.)
    endif

    M_AvNr:=ShiftArtikel(M_AvNr)
    if M_AvNr==AVAUS->AvNr
      Error("St�ckliste kann nicht auf sich selbst kopiert werden.")
      Umgebung(LOAD)
      RETURN(.t.)
    endif
    select AvAus

    // H. Weiland darf auf Abfrage alle St�cklisten auf einmal kopieren
    if getUser():id==KURZEL_MAIN_CUSTOMER .or. getUser():id==KURZEL_DEVEL
      alle:=(Message("Alle St�cklisten kopieren? (@J@/@N@)","JN","N")=="J")
    endif


    SEEK M_AvNr
    if eof()
      if ! Message(M_AvNr+" nicht gefunden !  Neue St�ckliste aufnehmen ?  (@J@/@N@) ","JN")=="J"
        Umgebung(LOAD)
        RETURN(.f.)
      ENDIF
      SELECT Artikel
      SEEK M_AvNr
      if eof() .and. ! Satz_Neu(db_info("Artikel"),M_AvNr)
        Umgebung(LOAD)
        RETURN(.f.)
      endif // eof()
      SELECT AvAus
      IF ! ADD_REC(5)
        Error(TRY_AGAIN)
        Umgebung(LOAD)
        // lock wiederherstellen, falls Datensatz bereits gelockt war
        if M->StkLocked
          lock_StkList()
        endif
        RETURN(.f.)
      endif
      replace AVAUS->avdat with getUser():date
      replace AVAUS->avNr with M_AvNr

    else // alte Stk-Liste �berschreiben ???
      if message("Vorhandene St�ckliste �berschreiben ?  (@J@/@N@) ","JN")<>"J"
        Umgebung(LOAD)
        // lock wiederherstellen, falls Datensatz bereits gelockt war
        if M->StkLocked
          lock_StkList()
        endif
        RETURN(.f.)
      endif
      if ! REC_LOCK(0)
        Error(TRY_AGAIN)
        Umgebung(LOAD)
        // lock wiederherstellen, falls Datensatz bereits gelockt war
        if M->StkLocked
          lock_StkList()
        endif
        RETURN(.f.)
      endif

      // locke neue ArtikelRec.Nr. f�r sync
      aktArtikelRecno:=ARTIKEL->(recno())
      ARTIKEL->(dbseek(M_AvNr))
      select Artikel
      if ! rec_lock(5)
        Error(TRY_AGAIN)

        select AvAus // lock der Ziel-St�ckliste wieder freigeben
        dbunlock()

        Umgebung(LOAD)
        // lock wiederherstellen, falls Datensatz bereits gelockt war
        if M->StkLocked
          lock_StkList()
        endif
        RETURN(.f.)
      endif
      select Avaus
      ARTIKEL->(dbgoto(aktArtikelRecno))

    endif // .not. gefunden
  /* kopiere Kopf-Daten */

    if alle .or. M->Art="M"
      replace AVAUS->Bem1 with _Bem1
      replace AVAUS->Bem2 with _Bem2
      replace AVAUS->Bem3 with _Bem3
      replace AVAUS->Bem4 with _Bem4
    endif
    if alle .or. M->Art="W"
      replace AVAUS->WKZ_Bem1 with _WKZ_Bem1
      replace AVAUS->WKZ_Bem2 with _WKZ_Bem2
      replace AVAUS->WKZ_Bem3 with _WKZ_Bem3
      replace AVAUS->WKZ_Bem4 with _WKZ_Bem4
    endif
    dbcommitall()
    UNLOCK

    // Avpost
    if alle .or. M->Art<>"I"
      kopStkList("AvPost",M_AvNr,akt_Datei,alle)
    endif

    // Instruktionen
    if alle .or. M->Art=="I"
      kopStkList("Instrukt",M_AvNr,"Ins_t",alle)
    endif

    dbcommitall()
    ARTIKEL->(dbunlock())
    AVAUS->(dbunlock())
    AVPOST->(dbunlock())
    Umgebung(LOAD)

    // lock wiederherstellen, falls Datensatz bereits gelockt war
    if M->StkLocked
      lock_StkList()
    endif

    message("St�ckliste nach @"+M_AvNr+"@ kopiert.   @Taste !@","@")

    Return(.t.)
/* EOF Stk_Kop */

static procedure kopStkList(Datei,m_AvNr,akt_Datei,alle)
LOCAL alleDateien,tempDatei,sollMengeRuest:=NIL
LOCAL PosNr

  select (akt_Datei)
  go top

  // ex. St�ckliste l�schen, falls sie existiert
  select (Datei)
  seek M_AvNr
  do while (DATEI)->AvNr==M_AvNr .and. ! eof()
    /* nur selktierte Art l�schen */
    if upper(Datei)<>"INSTRUKT" .and. M->Art <> AVPOST->Art .and. ! alle
      skip
      loop
    endif
    rec_lock(0)
    delete
    dbunlock()
    skip
  enddo

  alleDateien:={akt_Datei}
  if alle .and. upper(Datei)<>"INSTRUKT" // Instruktionen werden separt aufgerufen wegen anderer Struktur
    alleDateien:={"WERK_T", "MAT_T" , "ZEIT_T" }
  endif

  for each tempDatei in alleDateien
    select (tempDatei)
    go top
    PosNr:=1
    select (Datei)
    /* evtl. restl. neue Posten anh�ngen */
    do while ! (tempDatei)->(eof())
      add_rec(0)
      overwrite(tempDatei)
      replace (DATEI)->AvNr with M_AvNr
      if upper(Datei)<>"INSTRUKT" // Instruktionen ohne Pos. da anderer Struktur (Memo-Feld nur 1 Eintrag)
        replace (DATEI)->Pos with right("000"+alltrim(str(PosNr++,3)),3)
      endif

      // merke erste Durchschnittsmenge f�r R�stzeitberechnung
      if tempDatei=="ZEIT_T" .and. ZEIT_T->sollMenge>0 .and. sollMengeRuest==NIL
        sollMengeRuest:=ZEIT_T->sollMenge
      endif

      (tempDatei)->(dbskip(1))
    enddo
  next

return
/** eop */

/* Procedure Stk_Loeschen ***************************************
*
* l�schen von St�cklisten
*
*/
PROCEDURE Stk_Loeschen
LOCAL GetList:={}
LOCAL M_AVNr

  cls
  titel("S t � c k l i s t e   l � s c h e n")

  if ! getUser():mayEditData
    cls
    close data
    RETURN
  endif

  if ! open( "AvAus" , "AvPost" , "Instrukt" ,"Artikel")
    close data
    Error(TRY_AGAIN)
    cls
    RETURN
  endif

  select AvAus
  set relation to AVAUS->AvNr into Artikel

  do while ! ABBRUCH
    M_AvNr:=space(len(AVAUS->AvNr))
    Message("St�cklisten-Nummer eingeben.        @F12@=Hilfe")
    @ 4,0 clear
    @ 8,10 say 'Art.Nr.:'
    @ 8,20 get M_AvNr PICTURE '@9' valid { |oGet| check(oGet,"AvAus",.f.,.f.) }
    read
    if ! ABBRUCH
      seek M_AvNr
      if eof()
        Error("St�ckliste: "+M_AvNr+" nicht gefunden !",.t.)
        loop
      endif
      @ 8,40 say "vom: "+dtoc(AVAUS->AVDat)
      @ 9,10 to 9,70
      @ 10,10 say "Bez.:"
      @ 10,20 say ARTIKEL->bez1
      @ 11,20 say ARTIKEL->bez2
      @ 13,10 say "Mat.:"
      @ 13,20 say AVAUS->Bem1
      @ 14,20 say AVAUS->Bem2
      @ 16,10 say "Wkz.:"
      @ 16,20 say AVAUS->WKZ_Bem1
      @ 17,20 say AVAUS->WKZ_Bem2
      @ 18,10 to 18,70
      if Message("St�ckliste wirklich @l�schen@ ?  ( @J@ / @N@ ) ","JN")=="J"
        if ! rec_lock(5)
          Error(TRY_AGAIN)
          loop
        endif
        Message("St�ckliste wird gel�scht.  Bitte warten...")
        select AvPost
        seek AVAUS->AvNr
        do while AVAUS->AVNr==AVPOST->AVNr .and. ! eof()
          rec_lock(0)
          delete
          skip
        enddo
        unlock
        select Instrukt
        seek AVAUS->AvNr
        do while AVAUS->AVNr==INSTRUKT->AVNr .and. ! eof()
          rec_lock(0)
          delete
          skip
        enddo
        unlock

        select AvAus
        delete
        unlock
      endif
    endif
  enddo
RETURN
/* EOP Stk_Loesch */



/**
 * locked die akt. St�ckliste indem der akt. selekt. AVAUS Datensatz gelocked wird
 */
static function lock_StkList()
LOCAL aktSel:=alias()
LOCAL aktArtikel

  // bereits gelocked -> nop
  if M->StkLocked
    return .t.
  endif

  if M->Art $ getUser():mayEditPartsList
    // new 21.2.2011 Artikel locken um St�ckliste zu bearbeiten!
    select Artikel
    if ARTIKEL->ArtNr<>AVAUS->AvNr
      aktArtikel:=recno()
      ARTIKEL->(dbseek(AVAUS->AvNr))
    endif
    if ! rec_lock(5)
      Error(TRY_AGAIN)
      if aktArtikel<>NIL
        ARTIKEL->(dbgoto(aktArtikel))
      endif
      select (aktSel)
      RETURN(.f.)
    endif
    if aktArtikel<>NIL
      ARTIKEL->(dbgoto(aktArtikel))
    endif

    // lock St�cklisten Kopf
    select AvAus
    if ! rec_lock(5)
      Error(TRY_AGAIN)
      select Artikel
      dbunlock()
      select (aktSel)
      RETURN(.f.)
    endif

    M->StkLocked:=.t.
    select (aktSel)
    return .t.
  endif
return .f.
/** eof */

/**
 * Br�cke zu check("AVAUS"....)
 * setzt StkLocked wenn neuer Datensatz angelegt ist
 */
static function myAVcheck(oGet)
LOCAL result:=.f.
LOCAL neuSatz:=(M->Art $ getUser():mayEditPartsList)

  oGet:varPut(ShiftArtikel(oGet:Buffer))
  oGet:updateBuffer()

  AVAUS->(dbseek(oGet:buffer))
  IF AVAUS->(eof())
    if check(oGet,"Artikel",.f.,neuSatz) .and. check(oGet,"AvAus",.f.,neuSatz)
      M->StkLocked:=.t.
      result:=.t.
    endif
  else
    result:=.t.
  endif
return result
/** eof */

/** pr�ft ob die eingegeben Daten konsistent sind.
 *
 * workaround for bug mit vorzeitigem ESC Abbruch und ge�ndertem Text-K�rzel
 */
static function checkAvKonsistenz(Datei)
  if lastkey()==K_ESC
    if (Datei)->Text="A" .and. len(trim((Datei)->ArtNr))==3
      replace (Datei)->Text with "T"
      keyboard chr(K_RETURN)
    else
      if (Datei)->Text="T" .and. len(trim((Datei)->ArtNr))>3
        replace (Datei)->Text with "A"
        keyboard chr(K_RETURN)
      endif
    endif
  endif
return .t.

 /** pr�ft ob die eingegeben Daten konsistent sind.
 *
 * dirty workaround for bug mit vorzeitigem ESC Abbruch und ge�ndertem Text-K�rzel
 */
static function checkZeitKonsistenz()
  if lastkey()==K_ESC
    if ZEIT_T->Text="A"
      MASCHINE->(dbseek(trim(ZEIT_T->ArtNr)))
      if MASCHINE->(eof())
        TEXT->(dbseek(trim(ZEIT_T->ArtNr)))
        if TEXT->(eof())
          Error(ACHTUNG+"AV Zeit nicht gefunden:"+ZEIT_T->AvNr+" "+ZEIT_T->ArtNr+SCHWERER_FEHLER)
        endif
        replace ZEIT_T->Text with "T"
        keyboard chr(K_RETURN)
      endif
    elseif ZEIT_T->Text="T"
      TEXT->(dbseek(trim(ZEIT_T->ArtNr)))
      if TEXT->(eof())
        MASCHINE->(dbseek(trim(ZEIT_T->ArtNr)))
        if MASCHINE->(eof())
          TroubleEmail("AV Zeit nicht gefunden:"+ZEIT_T->AvNr+" "+ZEIT_T->ArtNr+SCHWERER_FEHLER)
        endif
        replace ZEIT_T->Text with "A"
        keyboard chr(K_RETURN)
      endif
    endif
  endif
return .t.

/** druckt die akt. selektierte St�ckliste aus, Material & Werkzeug */
function Stk_druck()

  Umgebung(WRITE_ALL)

  savePosten()

  if ! open("InnStk") // alias Auferfas
    Error(TRY_AGAIN)
  else
    zap
    add_rec(0)
    replace AUFERFAS->Artnr with AVAUS->Avnr
    replace AUFERFAS->Menge with 1
    replace AUFERFAS->InnerNr with INNER_TEMP_NR
    av_druck( M->Art , .t.,,,,,.t.) // force
  endif
  Umgebung(LOAD)

return .t.
/** eof */


/**
  * Wird nach Eingabe der Text-Art ausgef�hrt
 */

static function textNach(oGet)
LOCAL result:=.f.

  if oGet:changed
    switch oGet:buffer
    case "T"
      replace ZEIT_T->HauptKz with " "
      replace ZEIT_T->Automat with " "
      replace ZEIT_T->Ruestzeit with 0
      exit
    case "A"
      // NOP
      exit
    otherwise
      return .f.
    endswitch
  endif
return .t.
/** eof */


/**
  * Wird nach Eingabe der Haupt-Nebenmaschinen-Art ausgef�hrt
 */

static function hauptNach(oGet)
LOCAL aktRec:=ZEIT_T->(recno())
LOCAL n1,n2

  if oGet:changed .or. ZEIT_T->Nutzen1==0
    // nehme Menge & Nutzen von der Hauptmaschine obendr�ber
    do while ! BOF()
      if ZEIT_T->HauptKZ=="H" .and. ZEIT_T->Text=="A"
        n1:=ZEIT_T->Nutzen1
        n2:=ZEIT_T->Nutzen2
      endif
      skip -1
    enddo
    go (aktRec)
    if n1<>NIL .and. n2<>NIL
      replace ZEIT_T->Nutzen1 with n1,ZEIT_T->Nutzen2 with n2
    endif
    replace ZEIT_T->Ruestzeit with 0
    replace ZEIT_T->SollMenge with 0
  endif
return .t.
/** eof */

/**
  * Wird nach Eingabe der Menge ausgef�hrt (nur Zeiten)
 */

static function mengeNach(oGet)
LOCAL m,aktRec
  if oGet:changed
    if ZEIT_T->HauptKZ=="H" .and. ZEIT_T->(reccount())>1
      m:=ZEIT_T->Menge
      aktRec:=ZEIT_T->(recno())

      // Menge & Nutzen nur f�r alle Nebenmaschinen die nach der
      // aktuellen Hauptmaschine und vor der n�chsten HM kommen
      skip
      do while ! eof() .and. ! (ZEIT_T->HauptKZ=="H" .and. ZEIT_T->Text=="A")
        if (ZEIT_T->HauptKZ=="N" .and. ZEIT_T->Text=="A")
          replace ZEIT_T->menge with m
        endif
        skip
      enddo

      go (aktRec)

    endif
  endif
return .t.
/** eof */


/**
  * Kopiert die Menge und Nutezn der akt. Hauptmaschinen auf alle Nebenmaschinen
  */
static function copyNutzen()
LOCAL aktRec,nutzenBruch

  RuestZeitF12( .f. ) // F12 zur�cksetzen, falls Abbruch mit ESC

  if M->StkLocked .and. ZEIT_T->HauptKZ=="H" .and. ZEIT_T->(reccount())>0

    // Bruch k�rzen
    nutzenBruch:=reduceFraction(ZEIT_T->Nutzen1,ZEIT_T->Nutzen2)
    if ZEIT_T->Nutzen1<>nutzenBruch[1] .or. ZEIT_T->Nutzen2<>nutzenBruch[2]
      replace ZEIT_T->Nutzen1 with nutzenBruch[1]
      replace ZEIT_T->Nutzen2 with nutzenBruch[2]
    endif

    if ZEIT_T->(reccount())>1
      // suche ob Nebenmaschinen definiert sind
      // alt: Nebenmaschinen die nach der aktuellen Hauptmaschine und vor der n�chsten HM kommen
      // neu 20241117: alle Maschinen bekommen den Nutzen der 1. Hauptmaschine
      aktRec:=ZEIT_T->(recno())
      replace ZEIT_T->Nutzen1 with nutzenBruch[1], ;
        ZEIT_T->Nutzen2 with nutzenBruch[2] ;
        for ZEIT_T->Text=="A" .and. aktRec<>ZEIT_T->(recno())
    endif

    // alle Posten ausgeben, auch bei Nein, da Menge sich ge�ndert haben kann
    keyboard chr(FKT_SPECIAL)

  endif

return .t.
/** eof */


/** zeigt die aktuell selektierte Maschine an, if any */
static function Stk_MaschDisp(abfrage)
LOCAL result:=.t., ant

  Umgebung(WRITE_ALL)

  default abfrage:=.f.

  if ZEIT_T->Art=="V" .and. ZEIT_T->Text=="A" .and. ! empty(ZEIT_T->ArtNr)
    setcolor(COLWIN)
    MasDisp(.f.,.f.)
    if Abfrage
      ant:=Message("Standard-R�stzeit �bernehmen?  (@J@/@N@)","JN"," ")
      if ABBRUCH .or. ant <> "J"
        result:=.f.
      endif
    else
      Message("Bitte Taste dr�cken.","@")
    endif
    setcolor(COLNOR)
  endif

  Umgebung(LOAD)

return result
/** eop */

static function StkKalkUeber()

  Umgebung(WRITE)

  ARTIKEL->(dbseek(AVAUS->AvNr))
  kalkUeber()
  Umgebung(LOAD)
  dbskip(0) // relas wieder aktualisieren

return .t.
/** eof */

/** Locked St�ckliste -> dann Standard �ndern */
static function lockChange()
  if lock_StkList()
    HB_KeyPut(EDIT_LINE_EDIT)
  endif
return .t.

/** Locked St�ckliste -> dann Standard key up */
static function lockCtrlUp()
  if lock_StkList()
    HB_KeyPut(EDIT_CTRL_UP)
  endif
return .t.

/** Locked St�ckliste -> dann Standard key down */
static function lockCtrlDown()
  if lock_StkList()
    HB_KeyPut(EDIT_CTRL_DOWN)
  endif
return .t.

/** Locked St�ckliste -> dann Standard l�schen */
static function lockDelete()
  if lock_StkList()
    HB_KeyPut(EDIT_DELETE)
    IF upper(alias()) $ "MAT_T"
      M->matChanged:=.t.
    endif
  endif
return .t.

/** Locked St�ckliste -> dann Standard einf�gen */
static function lockInsert()
  if lock_StkList()
    HB_KeyPut(EDIT_INSERT)
  endif
return .t.

/** Locked St�ckliste -> dann Standard append */
static function lockAppend()
  if lock_StkList()
    HB_KeyPut(EDIT_APPEND)
  endif
return .t.

/** Zeigt die Instruktionen an */
function showInstruktion()
  Umgebung(WRITE_ALL)
  setcolor(COLNOR)
  setcursor(DEUTE_MARKE)
  Stk_Liste("I",ARTIKEL->ArtNr)
  Umgebung(LOAD)
return .t.
/** eof */

/** speichert die Postenn aller St�cklistenarten */
static function savePosten()
LOCAL alle_Dateien:={}, i,PosNr:=1

  /* St�ckliste r�ckschreiben nur falls sie bearbeitet wurde */
  if M->StkLocked
    Message("St�ckliste wird gespeichert.  Bitte warten...")

    /* alte Posten der St�ckliste in Avpost l�schen */
    select AvPost

    // alternative St�ckliste gew�nscht/hinterlegt?
    alle_Dateien:={ "Mat_t" , "Werk_t" , "Zeit_t" }
    seek AVAUS->AvNr

    do while AVAUS->AvNr==AVPOST->AvNr .and. ! AVPOST->(eof())
      rec_lock(0)
      delete
      skip
    enddo
    dbunlock()

    for i:=1 to len(alle_Dateien)
      (alle_Dateien[i])->(dbgotop())
      PosNr:=1
      /* evtl. restl. neue Posten anh�ngen */
      do while ! (alle_Dateien[i])->(eof())
        if ! ( empty((alle_Dateien[i])->ArtNr) .and. (alle_Dateien[i])->Text=="A")
          add_rec(0)
          overwrite(alle_Dateien[i])
          replace AVPOST->AvNr with AVAUS->AvNr
          replace AVPOST->Pos with right("000"+alltrim(str(PosNr++,3)),3)
          skip // gehe auf n�chsten Satz in AvPost
        endif
        (alle_Dateien[i])->(dbskip(1))
      enddo
      dbunlock()
    next // n�chste Datei

    /* Instruktionen extra, da andere Datei */
    INS_T->(dbgotop())
    select Instrukt
    seek AVAUS->AVNr

    if INSTRUKT->(eof())
      add_rec(0)
      replace INSTRUKT->AvNr with AVAUS->AvNr
    else
      rec_lock(0)
    endif
    replace INSTRUKT->InsText with INS_T->InsText

    dbcommitall()
    dbunlock()
  endif
return .t.
/** eof */


/* Function Av_Instrukt ***********************************
*
* Eingabe der StkListen-Posten: Instruktionen
* R�ckgabe:     immer .f.
  // anzeigen der Instruktionen
*/
STATIC FUNCTION Av_Instrukt()
LOCAL aFelder:={} , erg, cKey, Taste
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  select Ins_t
  @ 3,0 clear
  @ 3,0 to 3,maxcol()


  // we need this loop to handle keys after commit of changed text
  do while (taste:=lastkey()) <> K_ESC .and. ;
    Taste<>K_F9 .and. Taste<>K_F10 .and. Taste<>K_F11

    erg:=MyMemoEdit( INS_T->InsText , 4 , 1 , 23 , 78 , .f. , "InstruktMemoFunction" )
    if erg <> INSTRUKT->InsText

      if INS_T->(eof())
        add_rec(0)
        replace INS_T->AvNr with AVAUS->AvNr
      endif

      // Abfrage speichern???
      replace INS_T->InsText WITH erg
    endif

    // handle special key here so we are sure the changed text ist commited
    cKey:=upper( chr( lastkey() ) )
    do case
    CASE cKey == "K" // kopieren
      Stk_kop()
      SetLastKey(0)

    CASE cKey == "D" // Drucken
      Stk_druck()
      SetLastKey(0)

    ENDCASE
  enddo

RETURN .f.
/* EOF  */

/******************   Functions ***********************************************/

/* MemoEdit user function
  *
  * supporting special keys
  */
FUNCTION InstruktMemoFunction( nMode, nRow, nCol , lEditMode )
LOCAL nKey:=LastKey()
LOCAL cKey:=upper( chr( nKey ) )
LOCAL nRet
  // LOCAL erg

  ignore nRow, nCol


  if lEditMode
    Message("@F1@ = Hilfe   @F5@ = Farbe   @ESC@ = �nderungsmodus verlassen")
  else

    // Benutzer darf editieren
    if M->Art $ getUser():mayEditPartsList
      Message( "@�@ndern @K@opieren @D@rucken @F9@=Werkzeug @F10@=Material @F11@=Zeit "+;
        "@F7@/@F8@=Suchen @ESC@=Ende" )
    else
      Message( "@F7@/@F8@=Suchen @ESC@=Ende")
    endif
  endif

  if nMode == ME_INIT
    Set Key K_F5 to highlight()

  else

    if M->Art $ getUser():mayEditPartsList

      if lEditMode
        if nKey == K_ESC
          nRet:=MEMO_EDIT_STOP
        endif
      else

        DO CASE
        CASE cKey $ "�A"+HARBOUR_AE // �ndern
          if lock_StkList()
            nRet:=MEMO_EDIT_START
          endif


        CASE cKey == "K" // kopieren -> must be handeld in outer loop so changed text is commited 1st
          nRet:=MEMO_EXIT_NO_ESC

        CASE cKey == "D" // Drucken
          nRet:=MEMO_EXIT_NO_ESC

          // CASE nKey == K_F5 // Farbe
          // highlight()
          // nRet:=ME_IGNORE

        CASE nKey == K_F6 // neue Zeile anh�ngen
          Keyboard chr(K_CTRL_PGDN)
          nRet:=ME_IGNORE

        CASE nKey == K_F9 .or. nKey == K_F10 .or. nKey == K_F11 // andere St�ckliste anzeigen
          nRet:=K_ESC
          SetKey( K_F5, NIL )

        otherwise
          // nop

        ENDCASE
      endif

    endif

  endif

  if nRet == nil
    // call default memo function otherwise
    nRet:=MemoUserFunction( nMode, nRow, nCol , lEditMode )
  endif

RETURN nRet
/** eof */

/** Zum �ndern des AV Textes mit ALT-T */
static function avTextAend()

  if WERK_T->Text == "T"
    Umgebung(WRITE_ALL)
    setcolor(COLWIN)
    select Text
    if rec_lock(5)
      texDisp( .t. , .f. )
      dbcommit()
      unlock
    endif
    setcolor(COLNOR)
    Umgebung(LOAD)
  endif

return .t.
/** eof */

/** liefert eine Get Picture Maske basierend auf der Anzahl der Nachkommastellen */
static function getPictNachkomma(laenge,ME,Ausnahme)
LOCAL result:=replicate("9",laenge)
LOCAL aktSel:=alias()
  if open("Einheit")
    dbseek(ME)
    if ! eof()
      if EINHEIT->NACHKOMMA > 0
        result += "." + replicate("9",EINHEIT->NACHKOMMA)
        result:=right( result , laenge )
      elseif Ausnahme == ME // die goldene Ausnahme seit 14.3.2016 St�ck hier mit 2;
        Nachkommastellen, seit 10.7.19 mit 3 Nachkommastellen
        result += "." + replicate("9",3)
        result:=right( result , laenge )
      endif
    endif
  endif
  select (aktSel)
return result
/** eof */

/* Liefert eine Liste der Mehrfach Nutzen aus Taste T als String */ 
function getMehrfNutzen()
LOCAL Stueckliste:=Stueckliste():new(ARTIKEL->ArtNr, ARTIKEL->Art)
LOCAL result:="", nutzen
  for each nutzen in stueckliste:getWerkzeugNutzen()
    result += alltrim(str(nutzen[1]))+"/"+alltrim(str(nutzen[2]))+" "
  next
return trim(result)
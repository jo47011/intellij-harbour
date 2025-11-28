/* Aend.prg
*
* �nderungsroutine f�r alle Stammdaten
*
* Parameter: Datei              == gew�nschte zu bearbeitende Datei
*            Message            == Alternativ-Message
*            gesperrte Tasten   == klar
*/

#include "Miki.ch"
#include "Hilfe.ch"
#include "Directry.ch"
#include "Setcurs.ch"
#include "hbgtinfo.ch"

#define STAND_MESSAGE "@�@ndern @K@opieren @L@�schen @N@eu @S@perren"
#define RENAME_MESSAGE "@U@mbenennen"
#define NO_EDIT_MESSAGE "@+@/@-@ Bl�ttern    @F12@-@N@eue Auswahl   "
#define END_MESSAGE "@ESC@=Ende"
#define HELP_MESSAGE "@F12@=Ausw."
#define FILTER_MESSAGE "@F12@=@Filter@"

// Art.Nr. Bereich f�r Werkzeuge festlegen (FIXME: k�nnte in die config Datei)
#define WKZ_UNTER_GRENZE "014"
#define WKZ_OBER_GRENZE "199"

// folgenden Dateien darf man umbenennen
#define RENAME_ALLOWED MERGE_ALLOWED + NO_MERGE_ALLOWED

// bei folgenden Dateien ist KEIN Merge erlaubt (umbenennen)
#define NO_MERGE_ALLOWED "ARTIKEL/LOGIN/INTRASTAT"

// bei folgenden Dateien ist Merge erlaubt (umbenennen)
#define MERGE_ALLOWED "VERSART/ZAHLKOND/TEXT_KZ/SPEDIT/MAT_KZ/MASCHINE/AVSORTNR/LIEFTERM/"

PROCEDURE;
  Aend(cdatei,Message,tasten_gesperrt,add_start_message,AutoSperrung,startValue,altNrAbfrage,datei)
LOCAL GetList:={}
LOCAL Auswahl:=chr(255)
LOCAL tempDatei,tempVal
LOCAL Disp
LOCAL Merk_Satz, aSatz:={} , aTemp , FeldNr , Merk_artNr, merk_order
LOCAL M_Neu:=" ",hilfe:=.f.
LOCAL Spalte:=8 , d_zeile:=8 , merk_Farbe,zeile:=0
LOCAL pic, v_artnr,count:=0
LOCAL export:="Honsel  "
LOCAL start_message,s01,ende,ant, dispMessage
LOCAL Eingabe, aktRec, merkNr, neuMappNr
LOCAL tempMessage
LOCAL gesperrteAsciKeys:={}, alles:=.f.
LOCAL TempFile:=TEMP+BACKSLASH+"Kopie"+getUser():getLongID()
LOCAL kopieAlias:="Kopie"

MEMVAR vor_index
PRIVATE vor_index:=""

  default Datei:=db_info(upper( cdatei ))
  Disp:=Datei[D_DISP]

  cls
  Umgebung(WRITE_ALL)

  if Message == NIL
    message:=STAND_MESSAGE
    if datei[D_NAME] $ RENAME_ALLOWED
      message += RENAME_MESSAGE
    endif
  endif

  default tasten_gesperrt:=""
  default altNrAbfrage:=.t.

  // darf Benutzer Artikel bzw. andere Daten anzeigen?
  if ! getUser():mayShowData
    Umgebung(LOAD)
    return
  endif

  // gesperrte Tasten umwandeln in array
  convertLockedKeys( gesperrteAsciKeys , tasten_gesperrt)

  // darf Benutzer Artikel bzw. �ndern?
  if ! getUser():mayEditData .and. ! (upper(cDatei) $ "INNER/TEXT" .and.;
    getUser():mayCreateInnerOrders)
    message:=NO_EDIT_MESSAGE

    tasten_gesperrt:="KLSERPDU"
    if valtype(AutoSperrung)=="U" .and. ! getUser():mayEditArticleText
      tasten_gesperrt+="�A"
    else
      message:="@�@ndern  " + message
    endif

    // gesperrte Tasten umwandeln in array
    convertLockedKeys( gesperrteAsciKeys , tasten_gesperrt)

    // Sonderzeichen
    aadd( gesperrteAsciKeys , K_CTRL_F1 )
    aadd( gesperrteAsciKeys , K_CTRL_A )

  else

    // falls Artikel anlegen verboten -> ebenso kopieren & l�schen verboten
    if (! getUser():mayCreateArticles .and. alias()=="ARTIKEL") // added 23.2.15
      tasten_gesperrt:="kl"

      // gesperrte Tasten umwandeln in array
      convertLockedKeys( gesperrteAsciKeys , tasten_gesperrt)
    endif


  endif

  // wegen DatenschutzGrundVerordnung, Zugriff auf Personendaten restriktiv
  if .not. getUser():DSGVO
    aadd( gesperrteAsciKeys , K_F3 ) // ACHTUNG nicht K_ASC_F3
    aadd( gesperrteAsciKeys , K_CTRL_F3 )
    aadd( gesperrteAsciKeys , K_F9 )
    aadd( gesperrteAsciKeys , K_CTRL_F9 )
    aadd( gesperrteAsciKeys , K_F10 )
    aadd( gesperrteAsciKeys , K_CTRL_F10 )
  endif

  IF ! open( cDatei )
    Umgebung(LOAD)
    return
  ENDIF

  Eingabe:="M->X"+getKeyFieldName(datei)
  &Eingabe:=space(getKeyFieldlen(datei))

  start_message:=Datei[D_KURZ]+" eingeben.  "
  if valtype(add_start_message)=="C"
    start_message+=" "+add_start_message
  endif


  // DO WHILE ! ( (LASTKEY()==K_ESC .and. empty(&Eingabe)) .or. Auswahl=="X" )
  DO WHILE Auswahl<>"X"

    // Abbruch beim 2. Mal, falls Feld vorgegeben war
    count++
    if startValue<>NIL .and. count>1
      startValue:=nil
    endif

    cls
    titel(Datei[D_KURZ]+" erfassen, �ndern, l�schen")
    // if startValue==NIL
    hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - "+Datei[D_KURZ])
    // else
    // hb_gtInfo(HB_GTI_WINTITLE, Datei[D_KURZ])
    // endif

    // Filter �ber Hilfe gesetzt?
    if ordNumber( HILFE_TEMP_INDEX ) > 0
      Message(start_message + " " + FILTER_MESSAGE + " " + END_MESSAGE )
    else
      Message(start_message + " " + HELP_MESSAGE + " " + END_MESSAGE )
    endif

    if valtype(Datei[D_MEHRF_INDEX])=="B" .and. ! hilfe
      if ! eval(Datei[D_MEHRF_INDEX])
        Umgebung(LOAD)
        RETURN
      endif
    endif

    // maybe auto-launch
    if startValue<>NIL
      &Eingabe:=startValue
    else
      if Datei[D_ART]=="N"
        pic:=replicate("#",len(Field(1)))
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE "@K "+pic
      elseif Datei[D_ART]=="Z" .or. Datei[D_ART]=="A"
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE "@K!"
      elseif Datei[D_ART]=="Y"
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE "@K!A"
      elseif Datei[D_ART]=="K"
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE KDNR_PICT
      elseif Datei[D_ART]=="H"
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE REPKDNR_PICT
        // elseif Datei[D_NAME]=="MAT_KZ" // allgemeiner loesen, jojo !!!
        // @ Spalte-1,d_zeile+len(Datei[D_KURZ])+2 say MAT_EINGABE
        // @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE MAT_PICT
      else
        @ Spalte,d_zeile say Datei[D_KURZ]+":" get &Eingabe PICTURE "@K"
      endif

      read
    endif

    DO CASE
    CASE LASTKEY()==K_PGUP
      if empty(M->vor_Index)
        go bottom
      else
        dbseek(next(M->vor_index))
        skip -1
      endif
    CASE LASTKEY()==K_PGDN
      if empty(M->vor_Index)
        go top
      else
        seek M->vor_index
      endif
    CASE LASTKEY()==K_ESC
      exit
    case empty(&Eingabe)
      Keyboard chr(HILFE_TASTE1)
      hilfe:=.t.
      loop
    OTHERWISE // Eingabe suchen
      IF Datei[D_ART]=="N" // numerisches Feld
        &Eingabe:=right("0000000"+alltrim(&Eingabe),getKeyFieldLen(datei)) // f�hrende Nullen
      elseIF Datei[D_ART]=="H" // numerisches Feld
        &Eingabe:=right("0000000"+alltrim(left(&Eingabe,7)),7)+"-"+right(&Eingabe,2)
      elseIF Datei[D_ART]=="A" // Artikel
        if valtype(Datei[D_NEW_REC_SHIFT])=="B"
          &Eingabe:=eval(Datei[D_NEW_REC_SHIFT],&(Eingabe))
        else
          TroubleEmail(Datei[D_NAME]+" kein shift code block definiert")
        endif
      elseif Datei[D_ART]=="R" // numerisches Feld
        &Eingabe:=left(alltrim(&Eingabe)+"0000000",getKeyFieldLen(datei)) // Nullen rechts
      ENDIF

      // Info: crontab hat keinen Index
      if indexOrd()>0
        SEEK M->vor_index + &Eingabe
        // else
        // // locate for == (M->vor_index + &Eingabe)
        // __dbLocate( &("{|| "+getKeyFieldName(Datei)+" == "+M->vor_index + Eingabe+"}" ),,,, .F. )
      endif

      IF eof()
        if valtype(Datei[D_NEW_REC_ALLOWED])=="B" .and. ! eval(Datei[D_NEW_REC_ALLOWED])
          Error(ACHTUNG+Datei[D_KURZ]+" nicht vorhanden.",.t.)
          loop
        endif

        if ! sucheAlternativeNummer(Datei,&Eingabe,altNrAbfrage)

          // neu 23.2.2015 artikel anlegen, extra flag
          if (alias()=="ARTIKEL" .and. !(getUser():mayCreateArticles .or. getUser():mayEditTool) ) .or.;
            valtype(AutoSperrung)<>"U"
            Error(ACHTUNG+Datei[D_KURZ]+" nicht vorhanden.",.t.)
            loop
          endif

          // Artikel Nummernkreislauf okay
          if (!getUser():mayEditData .and. (getUser():mayEditTool .and. alias()=="ARTIKEL")) .and. ;
            (left(&Eingabe,len(WKZ_UNTER_GRENZE))<WKZ_UNTER_GRENZE .or.;
            left(&Eingabe,len(WKZ_OBER_GRENZE))>WKZ_OBER_GRENZE)
            Error(ACHTUNG+"Werkzeugnr. muss zw. "+out(left(WKZ_UNTER_GRENZE+"xxxxxxxxxxxxxxx",8))+;
              " - "+out(left(WKZ_OBER_GRENZE+"xxxxxxxxxxxxxx",8))+" liegen!",.t.)
            loop
          endif
          IF ! Message(Datei[D_KURZ]+" nicht vorhanden. "+Datei[D_KURZ]+" aufnehmen ? ( @J@ / @N@ "+;
            ")","JN")=="J"
            loop
          endif
          if upper(Datei[D_NAME])=="WERBUNG" .and. empty(right(&Eingabe,2)) // unsch�n jojo
            if add_rec(5)
              @ Spalte,d_zeile clear
              replace WERBUNG->KDNr_Werb with &Eingabe
              replace WERBUNG->Kurzname with KUNDEN->Kurzname
              replace WERBUNG->Adr1 with KUNDEN->Name
              replace WERBUNG->Adr2 with KUNDEN->Partner
              replace WERBUNG->Adr3 with KUNDEN->Strasse
              replace WERBUNG->Adr4 with trim(KUNDEN->Land)+" "+KUNDEN->Plz+" "+KUNDEN->Ort
              &(Datei[D_DISP])(.t.) // neuen Satz erfassen
            endif
          else
            Satz_Neu(Datei,&Eingabe) // neuen Satz hinzuf�gen
          endif
          if ! empty(M->vor_index)
            FieldPut(2,M->vor_index) // FIXME: was soll das???
            /** :( */
            if Datei[D_NAME]=="STATUS"
              FieldPut(2,ARTIKEL->ArtNr)
            endif
          endif
          if alias() $ "KUNDEN" // nur Miki :( jojo
            if open("Werbung") .and. add_rec(5)
              replace WERBUNG->KDNr_Werb with &Eingabe
              replace WERBUNG->Kurzname with KUNDEN->Kurzname
              replace WERBUNG->Adr1 with KUNDEN->Name
              replace WERBUNG->Adr2 with KUNDEN->Partner
              replace WERBUNG->Adr3 with KUNDEN->Strasse
              replace WERBUNG->Adr4 with trim(KUNDEN->Land)+" "+KUNDEN->Plz+" "+KUNDEN->Ort
            endif
            select Kunden
          endif

          dbcommit()
          unlock
        ENDIF
      endif
    ENDCASE

    &Eingabe:=space(getKeyFieldLen(datei)) // alt: immer 1. Feld ist Index-Feld !

    // bei automat. Sperrung gleich editieren
    // if valtype(AutoSperrung)<>"U"
    // keyboard "a"
    // endif

    hilfe:=.f.
    @ 4,0 clear
    Auswahl:=chr(255)
    DO WHILE ! Auswahl $ 'XxNn' .and. .not. asc(Auswahl) = K_ESC

      // if startValue==NIL
      if Alias() == "ARTIKEL"
        hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - "+Datei[D_KURZ]+": "+;
          out(getKeyFieldValue(Datei)))
      else
        hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" - "+Datei[D_KURZ]+": "+;
          getKeyFieldValue(Datei))
      endif
      // else
      // hb_gtInfo(HB_GTI_WINTITLE, Datei[D_KURZ]+": "+getKeyFieldValue(Datei))
      // endif

      dbskip(0)
      &(disp)(.f.,,AutoSperrung)

      // spezielle Message je nach Inhalt? siehe z.B. InnerEdit()
      // FIMXE: unsch�n: clean up all aend.prg!!!
      if valtype(Message)=="B"
        dispMessage = eval( Message )
      else
        dispMessage = message
      endif

      // Warte auf Eingabe -> Maus wird auch akzeptiert -> Daten werden neu ausgegeben wenn Focus kommt
      if ordNumber( HILFE_TEMP_INDEX ) > 0
        tempMessage:=dispMessage + " " + FILTER_MESSAGE + " " + END_MESSAGE
      else
        tempMessage:=dispMessage + " " + HELP_MESSAGE + " " + END_MESSAGE
      endif

      Auswahl:=upper( message(tempMessage,"@",,.f.,INKEY_KEYBOARD + INKEY_LDOWN) )

      // debugging "workarea not index" error
      // if getUser():id $ "MW/JG"
      // trouble("bespost","aend.prg->Taste:"+str(asc(Auswahl))+ hb_eol()+;
      // "Datei:"+alias()+ hb_eol()+;
      // "recno:"+str(recno())+hb_eol()+;
      // "Feld :"+toString(fieldget(1)))
      // if AT_HOME .and. lastkey() == K_ALT_K
      // ascii:=space(3)
      // @ 24,20 say "Ascii-Key:" get ascii picture 9999
      // read
      // Auswahl:=upper( chr( val( ascii )))
      // HB_KeyPut( val( ascii ))
      // inkey(0)
      // endif
      // endif

      DO CASE
      case lastkey() == HB_K_GOTFOCUS
        loop

        // lastkey() von F_Keys Abfrage zu Erst, da �berschneidung von chr(K_F...) mit Buchstaben
        // CASE lastkey()==K_LBUTTONDOWN .and. ! "a" $ tasten_gesperrt
        // if Hittest( NIL , getList, mrow() , mCol() , .t. )
        // Keyboard "a"
        // endif

      /* K-Lager intern Beistelteile berechnen  */
      CASE lastkey()==K_CTRL_F2 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        KLagerInternBerechnen( ARTIKEL->ArtNr )

      CASE lastkey()==K_CTRL_F9 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        Umgebung(WRITE)
        AufBestArtikel(ARTIKEL->ArtNr)
        Umgebung(LOAD)

        /* K-Lager / Baugruppenbestand */
      CASE lastkey()==K_CTRL_L .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        zeigeKBestand()

        // CASE lastkey() == K_CTRL_O .and. Datei[D_NAME]=="ARTIKEL" .and. 
        // ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        // Umgebung(WRITE_ALL)
        // Drucker("BS")
        // rekHonsBeiList(ARTIKEL->ArtNr,0,.t.)
        // Drucker("OFF")
        // Umgebung(LOAD)

        /* Beistellteile */
      CASE lastkey()==K_CTRL_D .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        tempVal:=BeistellArtikel(ARTIKEL->ArtNr)
        if rec_lock(5)
          replace ARTIKEL->BeiEK with tempVal[1]
          replace ARTIKEL->BeiKaPr with tempVal[2]
          if left(ARTIKEL->ArtNr,3) $ "150/501/502"
            repla ARTIKEL->BeiAufschl with ARTIKEL->BeiKaPr*0.3
          endif
          dbcommit()
          dbunlock()
        endif


        /* K-Lager / Baugruppenbestand */
        //CASE lastkey()==K_CTRL_N .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        // showArtnrExcelFile()

        /* Lagerbestand kontrolliert */
      CASE Auswahl=="O" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        toggleMarkArtikelBestand()

        /* K-Lager Inventur-Liste */
      CASE lastkey()==K_CTRL_I .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        if empty( left( ARTIKEL->KonsigKdNr,5 ) )
          Error("STRG-K Inventurliste K-Lager nur bei K-Lager Artikel m�glich.")
        else
          KLagerBewegung(ARTIKEL->ARtNr,,,.t.)
        endif

        /* Info - Text  */
        // CASE lastkey()==K_CTRL_F1 .and. Datei[D_NAME] $ "ARTIKEL,KUNDEN,LIEFERANTEN" .and.  CASE (lastkey()==K_CTRL_F1 .or. lastkey()==376 /* ALT_1 */ ) .and. fieldPos( "Bemerkung" ) > 0 .and.  ((alias()=="ARTIKEL" .and. getArtikelArt()=="W" .and. getUser():mayEditTool) .or.  ! ascan( gesperrteAsciKeys , lastkey() ) > 0)

        if rec_lock(5)
          Umgebung(WRITE)
          setcolor(COLWIN)
          Fenster(12,1,21,77,"Bemerkung")
          Message("Bemerkung zu "+Datei[D_KURZ]+": "+getKeyFieldValue(Datei)+;
            " eingeben.     @F1@=Hilfe       @ESC@=Ende")
          // " eingeben.     @F1@=Hilfe  @F7@=suchen  @ESC@=Ende")
          SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
          tempVal:=MyMemoEdit((ALIAS())->Bemerkung,13,2,20,76, getUser():mayEditData)
          if getUser():mayEditData
            replace (ALIAS())->Bemerkung with MyMemoEdit((ALIAS())->Bemerkung,13,2,20,76, .t.)
          endif
          Set Key K_ESC to
          dbcommit()
          dbunlock()
          Umgebung(LOAD)
          HB_KEYCLEAR()
          Auswahl:=""

        endif

        /* AB Bemerkungen */
      CASE lastkey()==K_CTRL_A .and. alias()=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0

        if rec_lock(5)
          Umgebung(WRITE)
          setcolor(COLWIN)
          Fenster(12,1,21,77,"AB-Bemerkung")
          Message("AB-Bemerkung zu "+Datei[D_KURZ]+": "+getKeyFieldValue(Datei)+;
            " eingeben.     @F1@=Hilfe       @ESC@=Ende")
          SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
          replace (ALIAS())->AB_Bemerk with MyMemoEdit((ALIAS())->AB_Bemerk,13,2,20,76, .t.)
          Set Key K_ESC to
          dbcommit()
          dbunlock()
          Umgebung(LOAD)
          HB_KEYCLEAR()
          Auswahl:=""

        endif

        /* Bestellungen int/ext */
      CASE lastkey() == K_ALT_F10 .and. Datei[D_NAME]=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        Umgebung(WRITE_ALL)
        tempVal:=ArtikelInfo():new()
        // tempVal:getLagerBestand(getCurrentKW())
        // tempMessage:=tempVal:lagerBestandUnterNull(,,.f.)
        tempVal:toQTList()

        tempVal:=NIL
        Umgebung(LOAD)

      CASE lastkey() == K_CTRL_Z .and. Datei[D_NAME]=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0 // .and. getUser():id==KURZEL_DEVEL
        listArtikelZeiten()

        /* Stkliste QT */
      CASE lastkey() == K_ALT_F11 .and. Datei[D_NAME]=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0 // .and. getUser():id==KURZEL_DEVEL
        Umgebung(WRITE_ALL)
        tempVal:=qtStkList():new( ARTIKEL->ArtNr, "M" , "Material-St�ckliste")
        tempVal:show()
        tempVal:=NIL
        Umgebung(LOAD)

        /* Achse Zeit, hidden */
      CASE lastkey() == K_ALT_F9 .and. Datei[D_NAME]=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        // Umgebung(WRITE_ALL)
        // AufBestArtikel(ARTIKEL->ArtNr)
        // Umgebung(LOAD)

        /* Achse Zeit */
      CASE lastkey() == K_ALT_F12 .and. Datei[D_NAME]=="ARTIKEL" .and. ;
        ! ascan( gesperrteAsciKeys , lastkey() ) > 0
        Umgebung(WRITE_ALL)
        Message("Liste wird erstellt.   Bitte warten...")
        if open("Auftrag","M_Mehrf")
          tempVal:=ArtikelInfo():new()
          //tempVal:addAllAuftragsBedarf()
          tempVal:toQTAchseZeit()
          tempVal:=NIL
        endif
        Umgebung(LOAD)

        /* Kunden-Auftr�ge anzeigen (Kunden) */
      CASE asc(Auswahl)==K_ASC_F9 .and. Datei[D_NAME]=="KUNDEN"
        Umgebung(WRITE_ALL)
        //tempVal:=Message("Mit K-Lager? (@J@/@N@)","JN","N")
        Auf_KundListe(KUNDEN->KundNr) // ,,tempVal=="J"
        Umgebung(LOAD)

        /* Kunden-Auftr�ge K-Lager anzeigen (Kunden) */
      CASE lastkey()==K_CTRL_F9 .and. Datei[D_NAME]=="KUNDEN"
        Umgebung(WRITE_ALL)
        Auf_KundListe(KUNDEN->KundNr , .f. , .t.)
        Umgebung(LOAD)

        // �ndern,�ndern, editieren Innerbetr. Auftr�ge
        // ACHTUNG: je nach Codepage ist � = STRG-F9
      CASE Auswahl $ "�A�"+HARBOUR_AE .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. alias()=="INNER" ;
        .and. getUser():mayCreateInnerOrders .and. ;
        hb_gtinfo( HB_GTI_KBDSHIFTS ) <> hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_ALT ) // ALT not pressed


        if INNER->Erledigt=="J"
          Error(ACHTUNG+"erledigter Auftrag kann nicht bearbeitet werden.")
          loop
        endif

        Merk_Satz:=NIL

        s01:=savescreen()

        // jetzt Autrags-Posten editieren
        Av_Auf_erfass( INNER_EDIT , INNER->InLfdNr )

        if Merk_Satz <> NIL
          INNER->(dbgoto(merk_Satz))
        endif

        restscreen(,,,,s01)

        // �ndern,�ndern, editieren
        // ACHTUNG: je nach Codepage ist � = STRG-F9
      CASE Auswahl $ "�A�"+HARBOUR_AE .and. ( ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .or. ;
        (alias()=="ARTIKEL" .and. getArtikelArt()=="W" .and. getUser():mayEditTool)) .and. ;
        hb_gtinfo( HB_GTI_KBDSHIFTS ) <> hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_ALT ) // ALT not pressed
        IF REC_LOCK(5)
          // merke urspr. Werte, falls Mem-Feld Bemerkung existiert
          aSatz:={}
          if fieldPos( "Bemerkung" ) > 0
            aSatz:=getCurrentValues()
          endif

          // jetzt Datensatz bearbeiten
          if (alias()=="ARTIKEL" .and. valtype(AutoSperrung)=="U") .and. ;
            (! getUser():mayEditData .and. getUser():mayEditArticleText) .and. ;
            ! (getUser():mayEditTool .and. getArtikelArt()=="W")
            Sperr_Reader( ,,,, .t. ) // reset Sperrung, Sicherheit beim bl�ttern
            &(disp)(.f.,,{"ARTIKEL->Bez1","ARTIKEL->Bez2","ARTIKEL->LAGEBEST"})
            &(disp)(.t.)
            Sperr_Reader( ,,,, .t. ) // reset Sperrung, Sicherheit beim bl�ttern
          else
            &(disp)(.t.)
          endif


          // protokolliere �nderungen
          if len(aSatz) > 0
            protAend( aSatz , getCurrentValues() )
          endif

        ENDIF
        dbcommitall()
        UNLOCK ALL

        /* kopieren */
      CASE Auswahl $ "K" .and. (! ascan( gesperrteAsciKeys , lastkey() ) > 0 .or.;
        (alias()=="ARTIKEL" .and. getArtikelArt()=="W" .and. getUser():mayEditTool))

        /* evtl. gesperrte Felder l�schen */
        Sperr_Reader({},.t.,,,.t.)

        &Eingabe:=space(getKeyFieldLen(datei)) // immer 1. Feld ist Index-Feld !
        @ Maxrow(),0 clear
        if Datei[D_ART]=="N"
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture "@9"
          read
          &Eingabe:=right("00000"+alltrim(&Eingabe),getKeyFieldLen(datei)) // f�hrende Nullen
        elseif Datei[D_ART]=="Z"
          /** wieder einmal workaround , jojo*/
          if Datei[D_NAME]=="LISTE"
            &Eingabe:=LISTE->Liste_Kurz
          endif
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture "@!"
          read
        elseif Datei[D_ART]=="Y"
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture "@K!A"
          read
        elseif Datei[D_ART]=="A"
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture "@!"
          read
          if valtype(Datei[D_NEW_REC_SHIFT])=="B"
            &Eingabe:=eval(Datei[D_NEW_REC_SHIFT],&(Eingabe))
          else
            TroubleEmail(Datei[D_NAME]+" kein shift code block definiert")
          endif
          if (!getUser():mayEditData .and. (getUser():mayEditTool .and. alias()=="ARTIKEL")) .and. ;
            (left(&Eingabe,len(WKZ_UNTER_GRENZE))<WKZ_UNTER_GRENZE .or.;
            left(&Eingabe,len(WKZ_OBER_GRENZE))>WKZ_OBER_GRENZE)
            Error(ACHTUNG+"Werkzeugnr. muss zw. "+out(left(WKZ_UNTER_GRENZE+"xxxxxxxxxxxxxxx",8))+;
              " - "+out(left(WKZ_OBER_GRENZE+"xxxxxxxxxxxxxx",8))+" liegen!",.t.)
            loop
          endif

        elseif Datei[D_ART]=="K"
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture KDNR_PICT
          read
        elseif Datei[D_ART]=="H"
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture REPKDNR_PICT
          read
          // elseif Datei[D_NAME]=="MAT_KZ"
          // @ Maxrow()-1,20 say "               "+MAT_EINGABE
          // @ Maxrow(),20 say "Kopieren nach:" get &eingabe picture MAT_PICT
          // read
          // @ Maxrow()-1,20 clear
        else
          @ Maxrow(),20 say "Kopieren nach:" get &eingabe
          read
        endif

        if ! empty(&Eingabe) .and. ! ( lastkey()==K_ESC )
          /* merke akt. Satz */
          Merk_Satz=RECNO()
          aSatz:=getCurrentValues()

          /* schon vorhanden ? */
          seek &Eingabe
          if ! eof() .and. ! Datei[D_NAME] $ "LISTE/ETIREPA" // Ausnahme bei Liste Jojo,Miki
            Error(Datei[D_KURZ]+SATZ_DOPPELT )
            go Merk_Satz
            aSatz:={}
            loop
          endif

          /* Spezial-Fall MW und JG: Kunden darf alles kopieren 20180228 */
          alles:=.f.
          if getUser():id $ "MW/JG" .and. alias()=="KUNDEN"
            if Message("Alle Werte kopieren? (@A@=Alle,@N@=Nein)","AN"," ") == "A"
              alles:=.t.

              // kopiere Email und Kund.Speditionen
              for each tempDatei in {"Email","KundSped","KundZoll"}
                select (TempDatei)
                copy to (tempFile) for (TEMPDATEI)->KundNr == aSatz[getKeyFieldPos(datei)]
                sele 0
                use (tempFile) alias (kopieAlias) EXCL
                // replace all (kopieAlias)->KundNr with &Eingabe
                tempVal:=&Eingabe
                DBEval( {|| _FIELD->KOPIE->KundNr:=tempVal},,,,, .F. )
                go top
                sele (TempDatei)
                append(kopieAlias)
                ferase(tempFile + MY_MEMO_EXTENSION)
                close(kopieAlias)
              next
              select Kunden

            endif
          endif

          if ABBRUCH
            go Merk_Satz
            aSatz:={}
            loop
          endif

          if ! add_rec(5)
            go Merk_Satz
            error(Datei[D_NAME]+DATEI_EXCL)
            aSatz:={}
            loop
          endif

          /* kopieren */
          // REPLACE &(getKeyFieldName(datei)) WITH &Eingabe
          (datei[D_NAME])->(fieldPut(getKeyFieldPos(datei),&Eingabe))

          for Feldnr:=1 to FCOUNT()
            if FeldNr<>getKeyFieldPos(datei) .and.;
              (alles .or. ascan(datei[D_NO_COPY_FIELDS],FieldName(FeldNr))==0)
              REPLACE &(FieldName(FeldNr)) WITH aSatz[FeldNr]
            endif
          next

          /* Sonderf�lle */
          do case
          case alias()=="ARTIKEL"

            // Preis Neuanlage merken
            Pr_prot(NIL,.t.,.t.,"Kopie von: "+aSatz[1])

            if getUser():id==KURZEL_MAIN_CUSTOMER .or. getUser():id==KURZEL_DEVEL

              // pr�fe ob Artikel St�ckliste hat
              select AvAus
              dbseek( aSatz[1] ) // suche "alte" Art.Nr.
              if ! AVAUS->(eof())

                if Message( "St�ckliste ebenfalls kopieren? (@J@/@N@)","JN"," ") == "J"
                  // replace ARTIKEL->Art with "F"

                  // FIXME: warum nicht procedure kopStkList verwenden?

                  aTemp:=getCurrentValues()
                  add_rec(0)
                  setCurrentValues( aTemp )
                  replace AVAUS->AvNr with &(Eingabe) // setze neue Art.Nr.

                  select AvPost
                  dbseek( aSatz[1] ) // suche alte Art.Nr.
                  do while ! AVPOST->(eof()) .and. AVPOST->AvNr == aSatz[1]
                    aTemp:=getCurrentValues()
                    aktRec:=AVPOST->(recno())
                    add_rec(0)
                    setCurrentValues( aTemp )
                    replace AVPOSt->AvNr with &(Eingabe) // setze neue Art.Nr.
                    go (aktRec)
                    skip
                  enddo

                  // Instruktionen kopieren
                  select Instrukt
                  dbseek( aSatz[1] ) // suche alte Art.Nr.
                  if ! INSTRUKT->(eof())
                    aTemp:=getCurrentValues()
                    add_rec(0)
                    setCurrentValues( aTemp )
                    replace INSTRUKT->AvNr with &(Eingabe) // setze neue Art.Nr.
                  endif
                endif
              endif

            endif

          endcase

          /** eval special function on new record if applicable */
          if valtype(Datei[D_NEW_REC_CODEBLOCK])=="B" .and. ! alles
            eval(Datei[D_NEW_REC_CODEBLOCK])
          endif

          writeModData()
          writeCreaData()

          dbcommitall()
          UNLOCK all
          aSatz:={}

          // automat. editieren
          keyboard "A"
        endif


      /* Umbenennen */
        CASE Auswahl $ "U" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
          if alias() == "INTRASTAT"
            renameIntrastat()
          else
            renameData()
          endif

          // l�schen
          CASE Auswahl=="L" .and. ( ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .or. ;
            (alias()=="ARTIKEL" .and. getArtikelArt()=="W" .and. getUser():mayEditTool))

            // FIXME: use Datei[D_DELETE_CASCADE] instead of the manual way below

            // neu 22.1.25: Kunden und Lieferanten nicht mehr l�schbar
            if alias() $ "KUNDEN/LIEFERAN"
              error(ACHTUNG+alias()+" kann man nicht mehr l�schen.")
              loop
            endif

            // Standard-Abfrage
            IF Message("Datensatz soll gel�scht werden. Sind Sie sicher ?  ( @J@ / @N@ ) ","JN")=="J"
              Message("Datensatz wird gel�scht.    Bitte warten....")
              IF ! REC_LOCK(5)
                Error(SATZ_EXCL)
                loop
              endif

          /* nur MIKI */
              if alias()=="ARTIKEL"
                Merk_ArtNr:=ARTIKEL->ArtNr
              endif


          /* nur MIKI */
              do case
              case alias()=="INNER"
                tempVal:=INNER->ArtNr
                delete
                // BestellBestand neu berechnen
                BestBestand( BEST_INT , INNER->ArtNr )
                AufBestand()

              case alias()=="ARTIKEL"

                // pr�fe St�ckliste
                Merk_Satz=ARTIKEL->(RECNO())
                select AvPost
                merk_order:=AVPOST->(indexord())
                AVPOST->(OrdSetFocus(2)) // Art.Nr
                AVPOST->(dbseek(ARTIKEL->ArtNr))
                if ! AVPOST->(eof())
                  Message("St�cklisten werden durchsucht.            Bitte warten...")
                  Drucker("BS",ARTIKEL->ArtNr+" in St�cklisten")
                  ? "Artikel:",ARTIKEL->ArtNr,trim(ARTIKEL->Bez1)," kommt in folgenden "+;
                    "St�cklisten vor:"
                  ? replicate("=",80)
                  do while ! AVPOST->(eof()) .and. AVPOST->ArtNr==ARTIKEL->ArtNr
                    ARTIKEL->(dbseek(AVPOST->AvNr))
                    ? AVPOST->AvNr,ARTIKEL->Bez1,AVPOST->Menge
                    skip
                  enddo
                  ? replicate("=",80)
                  drucker("OFF")
                  AVPOST->(OrdSetFocus((merk_order)))
                  select Artikel
                  go (merk_Satz)
                  if Message("Artikel: "+ARTIKEL->ArtNr+" wirklich l�schen?  (@J@/@N@)","JN")<>"J"
                    dbunlock()
                    loop
                  endif
                else
                  AVPOST->(OrdSetFocus((merk_order)))
                  select Artikel
                  go (merk_Satz)
                endif

                DELETE

            /* St�ckliste Hauptartikel l�schen */
                SELECT AvAus
                SEEK Merk_ArtNR
                do while .not. eof() .and. AVAUS->AvNr=Merk_ArtNR
                  rec_Lock(0)
                  delete
                  skip
                enddo

            /* St�ckliste Hauptartikel */
                SELECT Avpost
                AVPOST->(OrdSetFocus(1)) // AvNr
                SEEK Merk_ArtNR
                do while .not. eof() .and. AVPOST->AvNr=Merk_ArtNR
                  rec_Lock(0)
                  delete
                  skip
                enddo

            /* St�ckliste Unterartikel l�schen + Protokoll */
                AVPOST->(OrdSetFocus(2)) // Unterartikel+Oberartikel
                SEEK Merk_ArtNR
                if ! eof() .and. ! AVPOST->(deleted())
                  // Protokoll(INIT_P,"Artikel: "+Merk_ArtNR+" wurde gel�scht.","Bitte folgende St�cklisten �berpr�fen:")
                  do while .not. eof() .and. AVPOST->ArtNr=Merk_ArtNR
                    // if AVPOST->Text=="A" .and. AVPOST->Art $ "MW" raus am 2.2.2011
                    // Protokoll(PROTOKOLL,AVPOST->AvNr)
                    rec_Lock(0)
                    delete
                    // endif
                    skip
                  enddo
                  // Protokoll(PRINT_P,"Bitte �berpr�fen !")
                endif

                AVPOST->(OrdSetFocus(1)) // AvNr

            /* Instruktionen l�schen */
                SELECT Instrukt
                SEEK Merk_ArtNR
                do while .not. eof() .and. INSTRUKT->AvNr=Merk_ArtNR
                  rec_Lock(0)
                  delete
                  skip
                enddo

            /* Bewegungs-Datei */
                if ! open("Waraus")
                  Error(ACHTUNG+"Artikel Bewegungen konnten nicht gel�scht werden.",.t.)
                else
                  seek Merk_ArtNr
                  do while .not. eof() .and. WARAUS->ArtNr=Merk_ArtNR
                    rec_Lock(0)
                    delete
                    skip
                  enddo
                endif

            /* Eti-Repa-Datei */
                if open("EtiRepa")
                  seek Merk_ArtNr
                  do while .not. eof() .and. ETIREPA->EtiRepaNr=Merk_ArtNR
                    rec_Lock(0)
                    delete
                    skip
                  enddo
                  close("EtiRepa")
                endif

            /* Artikel-Preis-Datei */
                if ! open("ArtPreis")
                  Error(ACHTUNG+" Preis-Historie konnte nicht geschrieben werden.",.t.,"root")
                else
                  seek Merk_ArtNr
                  do while .not. eof() .and. ARTPREIS->ArtNr=Merk_ArtNR
                    rec_Lock(0)
                    delete
                    skip
                  enddo
                endif

            /* BestKarte-Datei */
                if ! open("BestKart")
                  Error(ACHTUNG+" Bestellkarte konnte nicht gel�scht werden.",.t.)
                else
                  Select BestKart
                  seek Merk_ArtNr
                  do while .not. eof() .and. BESTKART->ArtNr=Merk_ArtNR
                    rec_Lock(0)
                    delete
                    skip
                  enddo
                endif

            /* Mehrfach-Datei */
                if ! open("MehrFach")
                  Error(ACHTUNG+" Mehrfach.dbf konnte nicht gel�scht werden.",.t.)
                else
                  Select MehrFach
                  seek Merk_ArtNr
                  do while .not. eof() .and. MEHRFACH->ArtNr=Merk_ArtNR
                    rec_Lock(0)
                    delete
                    skip
                  enddo
                endif

                SELECT Artikel
            /* ENDE nur Artikel */

              case alias()=="MASCHINE"
                if stdStkListe()>0
                  if Message("Maschine: "+MASCHINE->StdNr+;
                    " wirklich l�schen?  (@J@/@N@)","JN")=="J"
                    // l�sche St�ckliste
                    select AvPost
                    AVPOST->(dbseek(MASCHINE->StdNr))
                    do while ! AVPOST->(eof()) .and. trim(AVPOST->ArtNr)==MASCHINE->StdNr
                      if ! rec_lock(5)
                        Error(ACHTUNG+" St�ckliste:"+AVPOST->AvNr+;
                          " konnte nicht gel�scht werden.",.t.)
                      else
                        delete
                      endif
                      AVPOST->(dbskip())
                    enddo
                    select Maschine
                    delete // Maschine
                  else
                    select Maschine
                  endif
                else
                  select Maschine
                  delete
                endif

              case alias()=="TEXT"
                if textStkListe()>0
                  if Message("Text: "+TEXT->TextNr+" wirklich l�schen?  (@J@/@N@)","JN")=="J"
                    // l�sche St�ckliste
                    select AvPost
                    AVPOST->(dbseek(TEXT->TextNr))
                    do while ! AVPOST->(eof()) .and. trim(AVPOST->ArtNr)==TEXT->TextNr
                      if ! rec_lock(5)
                        Error(ACHTUNG+" St�ckliste:"+AVPOST->AvNr+;
                          " konnte nicht gel�scht werden.",.t.)
                      else
                        delete
                      endif
                      AVPOST->(dbskip())
                    enddo
                    select Text
                    delete // Text
                  else
                    select Text
                  endif
                else
                  select Text
                  delete
                endif

              case alias()=="RABATT" .and. RABATT->RabattGr $ SONDER_RABATT + "|" + PHOENIX_RABATT_GRUPPE
                Error(ACHTUNG+" Sonderrabatt kann nicht gel�scht werden.",.t.)

              otherwise

                delete

              endcase

              deleteCascading( Datei )

              dbcommitall()
              UNLOCK all

              Trouble("loesch",{fieldget(1),fieldget(2),alias()+" wurde geloescht."+getUser():id})

              Auswahl:="N" // neuen Datensatz aussuchen
              &Eingabe:=space(getKeyFieldLen(datei)) // immer 1. Feld ist Index-Feld !
            ENDIF

        /* spezielle Felder Sperren/entsperren */
            CASE Auswahl $ "S" .and. ( ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .or.;
              (alias()=="ARTIKEL" .and. getArtikelArt()=="W" .and. getUser():mayEditTool))

            &(disp)(.t.,.t.)

        /*** ab hier Sonderf�ller MIKI,  jojo sp�ter mit Fkts-�bergabe (Codeblock) ! ***/

        /** Hilfe anzeigen, falls vorhanden */
            CASE asc(Auswahl)==K_ASC_F1
              Info("AEND",350,getKeyFieldName(Datei))
              // CASE asc(Auswahl)==K_ASC_F1 .and. Datei[D_NAME]=="ARTIKEL"
              // Info("AEND",350,"ARTNR")
              // CASE asc(Auswahl)==K_ASC_F1 .and. Datei[D_NAME]=="KUNDEN"
              // Info("AEND",350,"KUNDNR")

        /* St�ckliste aufl�sen - F5 */
              CASE asc(Auswahl)==K_ASC_F5 .and. Datei[D_NAME]=="ARTIKEL"
                MyStkListLind(10)
                setcursor(DEUTE_MARKE)

        /* Fertigungsdauer anzeigen - STRG F5 */
                CASE lastkey()==K_CTRL_F5 .and. Datei[D_NAME]=="ARTIKEL"
                  showFertDauer(10)

        /* Alternatives Material Hierarchie anzeigen */
                  CASE lastkey()==K_ALT_F6 .and. Datei[D_NAME]=="ARTIKEL"
                    AlternatMaterialAnzeigen(ARTIKEL->ArtNr) // alternative St�ckliste f�r n�chsten Auftrag

        /* Mindest-Bestellwert */
                    CASE asc(Auswahl)==K_ASC_F7 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                      MindBestArtikel(.f.)

        /* Mindest-Bestellwert detailliert */
                      CASE lastkey()==K_CTRL_F7 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                        MindBestArtikel(.t.)

        /** zeige offenen Auftr�ge zu Artikel */
                        CASE asc(Auswahl)==K_ASC_F9 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                          ArtAuftragsListe()

        /* Bestellungen int/ext */
                          CASE asc(Auswahl)==K_ASC_F10 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                            // if DEVEL_PROG
                            // altd()
                            // BestBestand(BEST_BEIDE,ARTIKEL->ArtNr)
                            // endif
                            ArtBestellListe()

        /* Bestellungen int/ext */
                            CASE lastkey() == K_CTRL_F10 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                              ArtInnerListe()

        /** zeigt den Text der zugeh�rigen Mat.KZ. an */
                              // CASE asc(Auswahl)==K_ASC_F11 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                              CASE lastkey()==K_ASC_F11 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                zeigeMatText() // MAT_KZ

      /* Preiskalkulation Beistellteile / Teurungszuschlag */
                                CASE Auswahl=="P" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                  if ARTIKEL->BeiAufKZ <> "J" .and. ARTIKEL->Preis1 > 0
                                    BeistellPreiskalk()
                                  endif

        /** zeigt den Text der zugeh�rigen Mat.KZ. an */
                                  CASE lastkey()==K_CTRL_F11 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                    zeigeMatText() // MAT_KZ

        /** zeigt den Text der zugeh�rigen Artikel Text an */
                                    CASE lastkey()==K_CTRL_F12 .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                      zeigeArtikelText() // Arttextnr

        /* Preiskalk. BS bei Artikel */
                                      CASE Auswahl=="8" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                        if getArtikelArt() $ STKLIST_ARTIKEL
          /** Spezial Funktion Zeige freischalten */
                                          M->specialZeige:={ { chr(K_F5)+chr(K_LDBLCLK)+"8" , ;
                                            { |text, ZeigeData| rekPreisKalk(text, ZeigeData)} , " @F5@=Preiskalk. " }}

                                          aadd( M->SpecialZeige , { chr(K_F6) , { |a , b|;
                                            rekMatArtListe( a , b ) } , "@F6@=in Stkl."} )

                                          preisKalkArtikel("BS")
                                          M->specialZeige:=NIL
                                        endif

        /* Preiskalk. mit VK  */
                                        CASE Auswahl=="9" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                          if ! open("ArtPreis")
                                            Error(TRY_AGAIN)
                                            Select Artikel
                                            loop
                                          endif
                                          Select Artikel

                                          ende:=.f.
                                          do while ! ende
                                            Hilfe("ArtPreis",getnew(),"Blubb")
                                            ende:=ABBRUCH
                                            if lastkey()==K_RETURN
                                              Drucker("BS","KAL_DRUCK")
                                              getUser():getCurrentPrintJob():callerName:="KAL_DRUCK"
                                              aEval(HB_ATokens(ARTPREIS->KalkDetail,MY_CR+MY_LF),;
                                                { |x| getUser():getCurrentPrintJob():print({x},.t.) })
                                              Drucker("OFF")
                                            endif
                                          enddo

                                          CASE Auswahl==chr(K_ASC_F3) .and. Datei[D_NAME]=="INNER" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                            if rec_lock(5)
                                              editInnerBemerkung()
                                              dbcommit()
                                              dbunlock()
                                            endif

                                            CASE Auswahl=="D" .and. Datei[D_NAME]=="INNER"

                                              if INNER->Erledigt=="J"
                                                Error(ACHTUNG+"erledigter Auftrag kann nicht "+;
                                                  "gedruckt werden.")
                                                loop
                                              endif

                                              InnerDruck(NIL, .t.) // drucke alle Dokumente auch bei bei Nebenarbeitsgang


        /* Innerbetr. Materil anzeigen drucken  */
                                              CASE Auswahl $ "MK" .and. Datei[D_NAME]=="INNER"
                                                Error("Info: Nachkalk speichern noch nicht "+;
                                                  "implementiert.")

        /* Erledigt */
                                                CASE Auswahl $ "EW" .and. Datei[D_NAME]=="INNER"
                                                  if INNER->Erledigt=="J"
                                                    ant:=Message("Auftrag @w@iederherstellen -- "+;
                                                      "@ESC@=Abbruch ( @W@ / @ESC@) ","W")
                                                  else
                                                    ant:=Message("Auftrag @e@rledigt  -- "+;
                                                      "@ESC@=Abbruch ( @E@ / @ESC@) ","E")
                                                  endif
                                                  if ABBRUCH
                                                    loop
                                                  endif
                                                  if ! rec_lock(5)
                                                    Error(TRY_AGAIN)
                                                  else

                                                    Umgebung( WRITE_ALL )

                                                    merkNr:=INNER->InnerNr
                                                    aktRec:=INNER->(recno())
                                                    merk_order:=INNER->(indexord())

                                                    // pr�fe ob Mappen Nr. bereits wieder vergeben
                                                    neuMappNr:=NIL
                                                    if ant == "W"
                                                      INNER->(OrdSetFocus( 1 ))
                                                      INNER->(dbseek( merkNr )) // gehe auf 1. Satz des inner Auftrags
                                                      if ! INNER->(EOF())
                                                        if ! open("Auftrag")
                                                          Error(TRY_AGAIN)
                                                          Umgebung(LOAD)
                                                          loop
                                                        endif
                                                        select Inner
                                                        neuMappNr:=getNextInnerNr()
                                                        Error(ACHTUNG+" Neue Mappen-Nummer: "+;
                                                          neuMappNr,.t.)
                                                      endif
                                                    endif
                                                    select Inner
                                                    INNER->(OrdSetFocus( merk_order ))
                                                    INNER->(dbgoto(aktRec))

                                                    recallAllInner(ant, neuMappNr)

                                                    Umgebung( LOAD )

                                                  endif


        /* Aufrufe Menu  */
                                                  CASE Auswahl=="D" .and. Datei[D_NAME]=="AUFRUF"

                                                    s01:=savescreen()
                                                    Fenster(14,1,23,77)
                                                    Message("@ESC@=Ende")
                                                    MemoEdit(AUFRUF->Details,15,2,22,76, .f.,,100)
                                                    restscreen(,,,,s01)
                                                    keyboard ""

        /* Bestellkarte bei Artikel */
                                                    CASE Auswahl=="B" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                      ArtDiKa(.t.)
                                                      Art_BestKarte(getUser():mayEditData)

        /* Mehrfachspritzung bei Artikel, nur Werkzeug, Taste T Werkzeug */
                                                      CASE Auswahl=="T" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                        Art_Mehrfach()

    /* Zusatz fuer Honsel Inventur Daten
    * */
                                                        CASE Auswahl=="I" .and. Datei[D_NAME]=="HONSELDA" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                          H_InvVerabeiten()
                                                          // Auswahl:="x"
                                                          loop

    /* Zusatz fuer Honsel Inventur Daten
    * */
                                                          CASE Auswahl=="E" .and. Datei[D_NAME]=="HONSELDA" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                            honselDatExport()
                                                            loop

        /* Artikel Bewegungsliste */
                                                            CASE Auswahl=="H" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                              WarAusList("BS",ARTIKEL->ArtNr)
                                                              Auswahl:=""
                                                              keyboard ""

        /* Artikel Bewegungsliste */
                                                              CASE asc(Auswahl)==K_CTRL_H .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                // zur Info: K_ALT_H ist 35
                                                                WarAusJahrList("BS",ARTIKEL->ArtNr)
                                                                Auswahl:=""
                                                                keyboard ""

        /* Artikel Bewegungsliste (alt f�r debug)  */
                                                                CASE asc(Auswahl)==K_CTRL_J .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                  // zur Info: K_ALT_H ist 35
                                                                  WarAusJahrList("BS",ARTIKEL->ArtNr,,.t.) // debug alte Version
                                                                  Auswahl:=""
                                                                  keyboard ""

        /** kleiner Taschenrechner f�r Gewicht */
                                                                  CASE Auswahl=="G" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                    calcGewicht()

        /** kleiner Taschenrechner f�r Gewicht */
                                                                    // CASE Auswahl==chr(K_CTRL_G) .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                    // calcStklGewicht()

        /* welcher Kunde (Rechnung) hat den Artikel wann bekommen  */
                                                                    CASE Auswahl==chr(K_ASC_F3) .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                      // altd()
                                                                      KundArtListe(ARTIKEL->ArtNr)

        /* welcher Kunde (Angebot) hat den Artikel wann bekommen  */
                                                                      CASE Auswahl==chr(K_CTRL_F3) .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                        ArtAngebotListe(ARTIKEL->ArtNr)

        /* Spedition je Kunde */
                                                                        CASE Auswahl=="V" .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                          if getUser():mayEditData;
                                                                            .and. rec_lock(5)
                                                                            KundSpedit()
                                                                            KunDisp(.f.,.f.)
                                                                          endif

        /* Kontakt je Kunde */
                                                                          CASE Auswahl=="P" .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                            if getUser():mayEditData .and. rec_lock(5)
                                                                              KundKontakt()
                                                                              KunDisp(.f.,.f.)
                                                                            endif

        /* Anlieferungszeiten je Kunde */
                                                                            CASE Auswahl=="Z" .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                              if getUser():mayEditData .and. rec_lock(5)
                                                                                Umgebung(WRITE)
                                                                                setcolor(COLWIN)
                                                                                Fenster(13,1,22,77;
                                                                                  ,"Anlieferungs-"+;
                                                                                  "Zeiten")
                                                                                Message("Anlieferungszeiten des Kunden eingeben.     @F1@=Hilfe       @ESC@=Ende")
                                                                                SetKey( K_ESC , {|;
                                                                                  |;
                                                                                  __Keyboard(chr(;
                                                                                  K_CTRL_W))} )
                                                                                tempVal:=MyMemoEdit(KUNDEN->Anlief,14,2,21,76, .t.)
                                                                                if tempVal;
                                                                                  <> KUNDEN->Anlief
                                                                                  replace KUNDEN->;
                                                                                    Anlief;
                                                                                    with tempVal
                                                                                endif
                                                                                Set Key K_ESC to
                                                                                dbcommit()
                                                                                dbunlock()
                                                                                Umgebung(LOAD)
                                                                                HB_KEYCLEAR()
                                                                                Auswahl:=""

                                                                              endif

        /* Umsatzliste je Kunde und Jahr  */
                                                                              CASE Auswahl==chr(K_ASC_F4) .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                UmsatzListe(KUNDEN;
                                                                                  ->KundNr)

        /* Neg. Verf�gbarkeitsliste pro Artikel */
                                                                                CASE Auswahl==chr(K_CTRL_F4) .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                  NegVerfueg(;
                                                                                    getArtikelArt(;
                                                                                    ),;
                                                                                    ARTIKEL->ArtNr)

        /* Offene Rechnungen des Kunden
 * Pr�fe ob CTRL pressed since pgup has the same keycode :(
 */
                                                                                  CASE Auswahl==chr(K_CTRL_R) .and. Datei[D_NAME]=="KUNDEN" .and. ;
                                                                                    ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                    hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL )

                                                                                    MahnListe("BS";
                                                                                      ,;
                                                                                      KUNDEN->KundNr)

        /* Alle Rechnungen des Kunden  */
                                                                                    CASE Auswahl=="R" .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                      RechnListe(;
                                                                                        KUNDEN->KundNr)

        /* welche Artikel hat der Kunde wann bekommen  */
                                                                                      CASE Auswahl==chr(K_ASC_F3) .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                        ArtKundListe(KUNDEN->KundNr)

        /* welche Artikel hat der Kunde wann angeboten bekommen  */
                                                                                        CASE Auswahl==chr(K_CTRL_F3) .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                          KundAngebotsListe(KUNDEN->KundNr)

        /* Sammelstelle eingeben */
                                                                                          CASE asc(Auswahl)==K_ASC_F5 .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                            kunSammelDisp(.t.) // edit
                                                                                            inkey() // clear lastkey()

        /* Alternative Rechnungsadresse eingeben */
                                                                                            CASE asc(Auswahl)==K_ASC_F6 .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                              kunAlternativDisp(0,"KUNDEN") // edit
                                                                                              inkey() // clear lastkey()

        /* Bestellkarte bei Artikel, nur MIKI: jojo   B  */
                                                                                              CASE Auswahl=="E" .and. Datei[D_NAME]=="KUNDEN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                EMailKunden( KUNDEN->KundNr , getUser():mayEditData )

        /* Anzeige Windows Darstellung */
                                                                                                // CASE Auswahl==chr(K_SPACE) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                // qtDisp()

        /* Liefertermine etc. in welchem Kunden  */
                                                                                                CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                  Datei[D_NAME] $ "LIEFTERM"
                                                                                                  ;
                                                                                                    ABPostListe()

        /* Rabattgruppe in welcher AB  */
                                                                                                  CASE Auswahl==chr(K_ASC_F5) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                    Datei[D_NAME] $ "RABATT"
                                                                                                    ABPostListe()

        /* Rabattgruppe in welcher Artikel  */
                                                                                                    CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                      Datei[D_NAME] $ "RABATT"
                                                                                                      ArtikelWertListe()

                                                                                                      CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                        Datei[D_NAME] $ "ZAHLKOND/VERSART/TEXT_KZ"
                                                                                                        ABWertListe()

        /* Spedition -> Anzahl Paletten pro Jahr  */
                                                                                                        CASE Auswahl==chr(K_ASC_F4) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                          Datei[D_NAME] $ "SPEDIT"
                                                                                                          SpeditPaletten( .f. )

        /* Spedition -> Anzahl Paletten pro Jahr  */
                                                                                                          CASE Auswahl==chr(K_CTRL_F4) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                            Datei[D_NAME] $ "SPEDIT"
                                                                                                            SpeditPaletten(.t.)

        /* Spedition etc. in welchem Kunden  */
                                                                                                            CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                              Datei[D_NAME] $ "SPEDIT/ZAHLKOND/VERSART"
                                                                                                              if select("KundSped") > 0 .or. open("KundSped")
                                                                                                                KUNDSPED->(OrdSetFocus( 2 ))
                                                                                                                select( Datei[D_NAME] )
                                                                                                                KundWertListe( { |value| kundSpeditExists(value) } )
                                                                                                              endif

        /* AvSortNr / Reihenfolg in welchem Artikel  */
                                                                                                              CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                                Datei[D_NAME] $ "AVSORTNR/ERL_GRUP/INTRASTAT/KSTSTAMM"
                                                                                                                ArtikelWertListe()

        /* AvSortNr / Reihenfolg in welchem Artikel  */
                                                                                                                CASE Auswahl==chr(K_ASC_F6) .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0 .and. ;
                                                                                                                  Datei[D_NAME] $ "LETZTEST"
                                                                                                                  ArtikelLetzteStelle()

        /* Material in welcher Stueckliste  */
                                                                                                                  CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                    MatArtikelListe()

                                                                                                                    CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="ARTPRGR" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                      artPrGrListe()

        /* Material in welcher Stueckliste  */
                                                                                                                      CASE (Auswahl=="E" .or. lastkey()==K_ALT_E) ;
                                                                                                                        .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                        E_ArtDisp()

        /* Maschine in welcher Stueckliste  */
                                                                                                                        CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="MASCHINE" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                          if stdStkListe()==0
                                                                                                                            Error("Keine Datens�tze in Auswahl.",.t.)
                                                                                                                          endif

        /* Texte in welcher Stueckliste  */
                                                                                                                          CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="TEXT" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                            if textStkListe()==0
                                                                                                                              Error("Keine Datens�tze in Auswahl.",.t.)
                                                                                                                            endif

        /* Mat.KZ in welchem Artikel  */
                                                                                                                            CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="MAT_KZ" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                              MatKzListe(MAT_KZ->MatKz)

        /* Mat.KZ in welchem Artikel  */
                                                                                                                              CASE Auswahl==chr(K_ASC_F6) .and. Datei[D_NAME]=="MASCHGR" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                MaschGrListe(MASCHGR->MaschGr)

        /* Material Stueckliste anschauen bei Artikel, nur MIKI: jojo   B  */
                                                                                                                                CASE Auswahl=="M" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                  Umgebung(WRITE_ALL)
                                                                                                                                  Stk_Liste("M",ARTIKEL->ArtNr)
                                                                                                                                  Umgebung(LOAD)
                                                                                                                                  Auswahl:=""
                                                                                                                                  keyboard ""

                                                                                                                                  CASE lastkey() == K_CTRL_M .and. Datei[D_NAME]=="ARTIKEL" .and. ;
                                                                                                                                    ascan( gesperrteAsciKeys , lastkey() ) == 0

                                                                                                                                    AlternatMaterialErfassen(ARTIKEL->ArtNr) // alternative St�ckliste f�r n�chsten Auftrag
                                                                                                                                    Auswahl:=""
                                                                                                                                    keyboard ""

        /* Werkzeug Stueckliste anschauen bei Artikel  */
                                                                                                                                    CASE Auswahl=="W" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                      Umgebung(WRITE_ALL)
                                                                                                                                      Stk_Liste("W",ARTIKEL->ArtNr)
                                                                                                                                      Umgebung(LOAD)
                                                                                                                                      Auswahl:=""
                                                                                                                                      keyboard ""

        /* Maschinen/Zeiten anschauen bei Artikel */
                                                                                                                                      CASE Auswahl=="Z" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                        Umgebung(WRITE_ALL)
                                                                                                                                        Stk_Liste("V",ARTIKEL->ArtNr)
                                                                                                                                        Umgebung(LOAD)
                                                                                                                                        Auswahl:=""
                                                                                                                                        keyboard ""

        /* Instruktionen Stueckliste anschauen bei Artikel, nur MIKI: jojo   B  */
                                                                                                                                        CASE Auswahl=="I" .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                          Umgebung(WRITE_ALL)
                                                                                                                                          Stk_Liste("I",ARTIKEL->ArtNr)
                                                                                                                                          Umgebung(LOAD)
                                                                                                                                          Auswahl:=""
                                                                                                                                          keyboard ""


        /* Bestellkarte bei Lieferan  */
                                                                                                                                          CASE Auswahl=="B" .and. Datei[D_NAME]=="LIEFERAN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                            Lief_BestKarte()

        /* Bestellhistorie  */
                                                                                                                                            CASE lastkey()==K_CTRL_B .and. Datei[D_NAME]=="ARTIKEL" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                              LiefBestHist(nil,ARTIKEL->ArtNr) // alle Bestellungen

        /* Bestellhistorie  */
                                                                                                                                              CASE asc(Auswahl)==K_ASC_F3 .and. Datei[D_NAME]=="LIEFERAN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                LiefBestHist(LIEFERAN->LiefNr,nil) // alle Artikel des Lieferanten

        /* Bestellkarte bei Lieferan  */
                                                                                                                                                CASE asc(Auswahl)==K_ASC_F9 .and. Datei[D_NAME]=="LIEFERAN" .and. ;
                                                                                                                                                  ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                  LiefBestellListe()

        /* Druck , nur beit Etikett */
                                                                                                                                                  CASE Auswahl=="D" .and. Datei[D_NAME] $ "ETIKETT/ETIREPA"
                                                                                                                                                    Eti_Druck()

        /** aktuelle Logins anzeigen */
                                                                                                                                                    CASE Auswahl=="I" .and. Datei[D_NAME]=="LOGIN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                      AktLoginDisp()

                                                                                                                                                      CASE Auswahl=="R" .and. Datei[D_NAME]=="LOGIN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                        LoginDispatcher():new():ResetLogin(LOGIN->Kurzel)
                                                                                                                                                        AktLoginDisp()

                                                                                                                                                        CASE Auswahl=="R" .and. Datei[D_NAME]=="CRONTAB" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                          if rec_lock(5)
                                                                                                                                                            replace CRONTAB->Datum with ctod("  .  .  ")
                                                                                                                                                            dbcommit()
                                                                                                                                                            dbunlock()
                                                                                                                                                          endif

                                                                                                                                                          CASE Auswahl=="C" .and. Datei[D_NAME]=="CRONTAB" .and. getUser():id $ KURZEL_DEVEL+"|"+SERVER_LOGIN+"|"+KURZEL_MAIN_CUSTOMER
                                                                                                                                                            Umgebung(WRITE_ALL)
                                                                                                                                                            CronJobs(CRONTAB->CronName)
                                                                                                                                                            Umgebung(LOAD)

                                                                                                                                                            CASE Auswahl=="P" .and. Datei[D_NAME]=="LOGIN" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                              if Message("Passwort l�schen?   Sind Sie sicher?  (@J@/@N@)","JN")=="J"
                                                                                                                                                                if rec_lock(5)
                                                                                                                                                                  replace LOGIN->Passwort with ""
                                                                                                                                                                  dbcommit()
                                                                                                                                                                  dbunlock()
                                                                                                                                                                endif
                                                                                                                                                              endif

        /* Repstamm exportieren */
                                                                                                                                                              // CASE Auswahl=="E" .and. Datei[D_NAME]=="REPSTAMM" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                              // M_Neu:="Repa"
                                                                                                                                                              // if Message("Komplette St�rungsliste exportieren.  Bitte best�tigen. (@b@)","@")=="B"
                                                                                                                                                              // M_Neua:="f:"+BACKSLASH+"user"+BACKSLASH+"user9"+BACKSLASH+
                                                                                                                                                              // alltrim(M_Neu)+"a.txt"
                                                                                                                                                              // M_Neub:="f:"+BACKSLASH+"user"+BACKSLASH+"user9"+BACKSLASH+
                                                                                                                                                              // alltrim(M_Neu)+"b.txt"
                                                                                                                                                              // M_Neu:="f:"+BACKSLASH+"user"+BACKSLASH+"user9"+BACKSLASH+
                                                                                                                                                              // alltrim(M_Neu)+".txt"
                                                                                                                                                              // Message("Datei wird exportiert.  @"+M_Neu+"@   Bitte warten....")
                                                                                                                                                              // copy fields RepStNr to &(M_Neua) delimited with BLANK
                                                                                                                                                              // copy fields Text to &(M_Neub) delimited with BLANK
                                                                                                                                                              // copy fields RepStNr,Text to &(M_Neu) delimited with blank
                                                                                                                                                              // endif
                                                                                                                                                              // @ 4,0 clear



        /* Rabatt-Tabelle anzeigen (Artikel) */
                                                                                                                                                              CASE Auswahl=="R" .and. Datei[D_NAME]=="ARTIKEL"

                                                                                                                                                                tempDatei:=db_info("RABATT")
                                                                                                                                                                merk_Farbe:=setcolor(COLWIN)
                                                                                                                                                                RABATT->(dbseek(ARTIKEL->Rabattgr))
                                                                                                                                                                &(TempDatei[D_DISP])(.f.,.f.,.t.)
                                                                                                                                                                Message("Bitte @Taste@ dr�cken","@")
                                                                                                                                                                setcolor(merk_Farbe)


        /* Kalk.�bersicht anzeigen (Artikel) */
                                                                                                                                                                CASE Datei[D_NAME]=="ARTIKEL" .and. Auswahl $ chr(K_ASC_F8) + chr(K_ALT_F8) ;
                                                                                                                                                                  .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                                  kalkUeber()

        /* Artikel in neuem Fenster anzeigen */
                                                                                                                                                                  // case (i:=ascan( LAUNCH_TASTEN , { |k| ausWahl == chr(val(k)) } )) > 0 .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                                                                                                                                                  // launchProgram()

        /* Status komplett duplizieren */
                                                                                                                                                                  CASE Auswahl=="D" .and. Datei[D_NAME]=="STATUS" .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0
                                                                                                                                                                    open("Artikel")
                                                                                                                                                                    Merk_artNr:=space(len(STATUS->ArtNr))
                                                                                                                                                                    @ Maxrow(),0 clear
                                                                                                                                                                    @ Maxrow(),20 say "Kopieren nach Art.Nr.:" get Merk_artNr valid { |oGet| check(oGet,"Artikel",.f.) }
                                                                                                                                                                    read
                                                                                                                                                                    if ! ABBRUCH
                                                                                                                                                                      select Status
          /** suche ersten mit akt. ArtNr */
                                                                                                                                                                      v_artNr:=STATUS->ArtNr
                                                                                                                                                                      while ! bof() .and. STATUS->ArtNr==v_artnr
                                                                                                                                                                        skip -1
                                                                                                                                                                      enddo
                                                                                                                                                                      if bof()
                                                                                                                                                                        go top
                                                                                                                                                                      else
                                                                                                                                                                        skip
                                                                                                                                                                      endif

                                                                                                                                                                      do while ! eof() .and. STATUS->ArtNr==v_ArtNr
            /* merke akt. Satz */
                                                                                                                                                                        Merk_Satz=RECNO()
                                                                                                                                                                        for FeldNr:=1 to fcount()
                                                                                                                                                                          aadd( aSatz , &(FieldName(FeldNr)) )
                                                                                                                                                                        next i

                                                                                                                                                                        if ! add_rec(5)
                                                                                                                                                                          error(Datei[D_NAME]+DATEI_EXCL)
                                                                                                                                                                          aSatz:={}
                                                                                                                                                                          loop
                                                                                                                                                                        endif

            /* kopieren */
                                                                                                                                                                        for Feldnr:=1 to FCOUNT() // IndexFeld ist erste Feld
                                                                                                                                                                          REPLACE &(FieldName(FeldNr)) WITH aSatz[FeldNr]
                                                                                                                                                                        next
                                                                                                                                                                        replace STATUS->ArtNr with Merk_artNr

                                                                                                                                                                        aSatz:={}
                                                                                                                                                                        go (merk_satz)
                                                                                                                                                                        skip
                                                                                                                                                                      enddo
                                                                                                                                                                    endif
                                                                                                                                                                    select Status

                                                                                                                                                                    CASE Auswahl=="T" .and. Datei[D_NAME]=="DRUCKER"
                                                                                                                                                                      Merk_Satz:=recno()
                                                                                                                                                                      Drucker("TEST","Drucker-Test:"+trim(DRUCKER->Bez))
                                                                                                                                                                      if ! empty(DRUCKER->fett_an)
                                                                                                                                                                        ?? "Normal - ",FETT_AN,"xxxxx Fetter Ausdruck !", FETT_AUS
                                                                                                                                                                      endif
                                                                                                                                                                      ?? " -- Umlaute: ������"
                                                                                                                                                                      ?
                                                                                                                                                                      if ! empty(DRUCKER->breit_an)
                                                                                                                                                                        ? BREIT_AN, "xxxxx Breiter Ausdruck !",FETT_AN,space(0)," Breit & Fett",FETT_AUS,space(0),BREIT_AUS ," Normal weiter"
                                                                                                                                                                        ? PrintSonderZeichen():new("X"),BREIT_AN ,PrintSonderZeichen():new("TEST"),BREIT_AUS, "X"
                                                                                                                                                                      endif
                                                                                                                                                                      if ! empty(DRUCKER->schmal_an)
                                                                                                                                                                        ? SCHMAL_AN,"xxxxx Schmaler Ausdruck !",FETT_AN,space(0)," Schmal & Fett",FETT_AUS,space(0),SCHMAL_AUS,space(0)," Normal weiter"
                                                                                                                                                                      endif
                                                                                                                                                                      if ! empty(DRUCKER->klein_an)
                                                                                                                                                                        ? KLEIN_AN, "xxxxx Kleiner Ausdruck !",FETT_AN,space(0)," Klein & Fett",FETT_AUS,space(0),KLEIN_AUS ," Normal weiter"
                                                                                                                                                                      endif
                                                                                                                                                                      if ! empty(DRUCKER->winzig_an)
                                                                                                                                                                        ? WINZIG_AN,"xxxxx Winziger Ausdruck !",FETT_AN,space(0)," Winzig & Fett",FETT_AUS,space(0),WINZIG_AUS,space(0)," Normal weiter"
                                                                                                                                                                      endif

                                                                                                                                                                      Drucker("OFF")
                                                                                                                                                                      go (Merk_Satz)

                                                                                                                                                                      CASE asc(Auswahl)==K_ESC
        /* NOP */

                                                                                                                                                                        CASE Auswahl=="N"
        /* NOP */

                                                                                                                                                                          CASE asc(Auswahl)==215 .or. asc(Auswahl)==255 // K_F12,F2
                                                                                                                                                                            Auswahl:="N"
                                                                                                                                                                            keyboard toString(getKeyFieldValue(Datei),.f.) + chr(HILFE_TASTE1) + chr(FKT_SPECIAL)

                                                                                                                                                                            CASE asc(Auswahl)==253 .and. Datei[D_NAME]=="ARTIKEL" // K_F4
                                                                                                                                                                              Auswahl:="N"
                                                                                                                                                                              if ! empty(left(ARTIKEL->HartNr,12))
                                                                                                                                                                                keyboard ARTIKEL->HartNr
                                                                                                                                                                              endif

                                                                                                                                                                              // Umgebung(WRITE_ALL)
                                                                                                                                                                              Hilfe( "HONSELARTIKEL",getNew(),"" )
                                                                                                                                                                              // Umgebung(LOAD)
                                                                                                                                                                              // keyboard ""
                                                                                                                                                                              // Auswahl:=" "

        /* EMail bei Mitarbeiter - E */
                                                                                                                                                                              CASE Auswahl=="E" .and. Datei[D_NAME]=="LOGIN"
                                                                                                                                                                                Umgebung(WRITE_ALL)
                                                                                                                                                                                ErfasseEMail(LOGIN->Email)
                                                                                                                                                                                Umgebung(LOAD)

        /* EMail bei Kunden - E */
                                                                                                                                                                                // CASE Auswahl=="E" .and. Datei[D_NAME]=="KUNDEN"
                                                                                                                                                                                // Umgebung(WRITE_ALL)
                                                                                                                                                                                // ErfasseEMail(Kunden->Email)
                                                                                                                                                                                // Umgebung(LOAD)

        // /* EMail bei Lieferanten - E */
                                                                                                                                                                                // CASE Auswahl=="E" .and. Datei[D_NAME]=="LIEFERAN"
                                                                                                                                                                                // Umgebung(WRITE_ALL)
                                                                                                                                                                                // ErfasseEMail(LIEFERAN->Email)
                                                                                                                                                                                // Umgebung(LOAD)

        /* Zoll-Ausgangsstelle je Kunden  */
                                                                                                                                                                                // CASE Auswahl $ "Zz" .and. alias()=="KUNDEN" .and. getUser():mayEditData 
                                                                                                                                                                                // .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                                                                                                                                                                // if getUser():mayEditData .and. rec_lock(5)
                                                                                                                                                                                // KundZollstellen()
                                                                                                                                                                                // KunDisp(.f.,.f.)
                                                                                                                                                                                // endif

        /* Anzeige wann Datensatz erzeugt wurde */
                                                                                                                                                                                CASE Auswahl=="7" .and. fieldpos("MOD_DATE") > 0 .and. fieldpos("CREA_DATE") > 0

                                                                                                                                                                                  s01:=savescreen()
                                                                                                                                                                                  setcolor(COLWIN)
                                                                                                                                                                                  Fenster(5,16,9,50)
                                                                                                                                                                                  @ 6,20 say 'Datensatz erzeugt:'
                                                                                                                                                                                  @ 8,20 say (Alias())->Crea_Date
                                                                                                                                                                                  @ 8,30 say mytime((Alias())->Crea_time)
                                                                                                                                                                                  @ 8,40 say (Alias())->Crea_User

                                                                                                                                                                                  // @ 9,20 say 'Datensatz ge�ndert:'
                                                                                                                                                                                  // @ 10,20 say (Alias())->Mod_Date
                                                                                                                                                                                  // @ 10,30 say mytime((Alias())->Mod_time)
                                                                                                                                                                                  // @ 10,40 say (Alias())->Mod_User
                                                                                                                                                                                  setcolor(COLNOR)

                                                                                                                                                                                  Message("Bitte @Taste@ dr�cken","@")
                                                                                                                                                                                  restscreen(,,,,s01)

        /* vorw�rts bl�ttern */
                                                                                                                                                                                  CASE Auswahl=="+" .or. asc(Auswahl)==K_DOWN .or. asc(Auswahl)==K_PGDN;
                                                                                                                                                                                    .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                                                                                                                                                                    // setzte letzten Hilfe Filter, falls vorhanden
                                                                                                                                                                                    if ordNumber( HILFE_TEMP_INDEX ) > 0
                                                                                                                                                                                      merk_order:=indexord()
                                                                                                                                                                                      ordSetFocus( ordNumber( HILFE_TEMP_INDEX ) )
                                                                                                                                                                                    endif

                                                                                                                                                                                    skip
                                                                                                                                                                                    IF eof()
                                                                                                                                                                                      beep()
                                                                                                                                                                                      go bottom
                                                                                                                                                                                    ENDIF

                                                                                                                                                                                    // setzte letzten Hilfe Filter zur�ck, falls vorhanden
                                                                                                                                                                                    if ordNumber( HILFE_TEMP_INDEX ) > 0
                                                                                                                                                                                      ordSetFocus( merk_order )
                                                                                                                                                                                    endif

        /* r�ckw�rts bl�ttern */
                                                                                                                                                                                    CASE Auswahl=="-" .or. asc(Auswahl)==K_UP .or. asc(Auswahl)==K_PGUP;
                                                                                                                                                                                      .and. ! ascan( gesperrteAsciKeys , lastkey() ) > 0

                                                                                                                                                                                      // setzte letzten Hilfe Filter, falls vorhanden
                                                                                                                                                                                      if ordNumber( HILFE_TEMP_INDEX ) > 0
                                                                                                                                                                                        merk_order:=indexord()
                                                                                                                                                                                        ordSetFocus( ordNumber( HILFE_TEMP_INDEX ) )
                                                                                                                                                                                      endif

                                                                                                                                                                                      skip -1
                                                                                                                                                                                      IF bof()
                                                                                                                                                                                        beep()
                                                                                                                                                                                        go top
                                                                                                                                                                                      ENDIF

                                                                                                                                                                                      // setzte letzten Hilfe Filter zur�ck, falls vorhanden
                                                                                                                                                                                      if ordNumber( HILFE_TEMP_INDEX ) > 0
                                                                                                                                                                                        ordSetFocus( merk_order )
                                                                                                                                                                                      endif

                                                                                                                                                                                      OTHERWISE
                                                                                                                                                                                      Beep()

                                                                                                                                                                                    ENDCASE

                                                                                                                                                                                    // dbcommit() , jojo ?

                                                                                                                                                                                  ENDDO

                                                                                                                                                                                ENDDO

  /* evtl. gesperrte Felder l�schen */
                                                                                                                                                                                Sperr_Reader({},.t.,,,.t.)

                                                                                                                                                                                Umgebung(LOAD)
                                                                                                                                                                                return


/* PROcedure SysAend
*
* �ndern der SystemParameter
*/
PROCEDURE Sys_Aend
LOCAL M_BestNr , M_AufNr , M_RechNr, M_AngNr,M_SepaNr,M_LsNr
LOCAL okay:=.f. , s01,sumNrs,stornoNrs,gbsNrs

  if ! open( "System" ) .or. ! fil_lock(5)
    Error(TRY_AGAIN)
    cls
    close data
    RETURN
  endif
  cls
  Titel("S Y S T E M  -  P A R A M E T E R")
  M_BestNr:=SYSTEM->BestNr
  M_AufNr:=SYSTEM->AufNr
  M_AngNr:=SYSTEM->AngNr
  M_RechNr:=SYSTEM->RechNr
  M_SepaNr:=SYSTEM->SepaNr
  M_LSNr:=SYSTEM->LSNr
  do while ! okay

    // sicher(WRITE)
    SysDisp(.t.)

    s01:=savescreen()
    /*** Bestell-Nummer checken ***/
    if SYSTEM->BestNr > M_BestNr
      Beep()
      if ! Message("ACHTUNG: Bestellnummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->BestNr with M_BestNr
        loop
      endif
    endif
    if SYSTEM->BestNr < M_BestNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen Bestellnummern werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J" ;
        .or. ! open("Besaus","BesPost")
        replace SYSTEM->BestNr with M_BestNr
        loop
      endif
      restscreen(,,,,s01)
      select Besaus
      if fil_lock()
        select BesPost
        if fil_lock()
          Message("Bitte warten...")
          okay:=.t.
          dele for val(BESPOST->BestNr) >= SYSTEM->BestNr
          select BesAus
          dele for val(BESAUS->BestNr) >= SYSTEM->BestNr
        endif
      endif
      if ! okay
        Error("Bestellnummer"+NO_SYS_CHANGE)
        replace SYSTEM->BestNr with M_BestNr
      endif
    endif
    /* Ende Bestell-Nummer checken */


    /*** Angebots-Nummer checken ***/
    if SYSTEM->AngNr > M_AngNr
      if ! Message("ACHTUNG: Angebotsnummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->AngNr with M_AngNr
        loop
      endif
    endif
    if SYSTEM->AngNr < M_AngNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen Angebotsnummern werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J";
        .or. ! open("ANGAUS","ANGPOST")
        replace SYSTEM->AngNr with M_AngNr
        loop
      endif
      restscreen(,,,,s01)
      select ANGAUS
      if fil_lock()
        select ANGPOST
        if fil_lock()
          Message("Bitte warten...")
          okay:=.t.
          dele for val(ANGPOST->AngNr) >= SYSTEM->AngNr
          select ANGAUS
          dele for val(ANGAUS->AngNr) >= SYSTEM->AngNr
        endif
      endif
      if ! okay
        Error("Angebotsnummer"+NO_SYS_CHANGE)
        replace SYSTEM->AngNr with M_AngNr
      endif
    endif
    /* Ende Angebot-Nummer checken */

    /*** Auftrags-Nummer checken ***/
    if SYSTEM->AufNr > M_AufNr
      if ! Message("ACHTUNG: Auftragsnummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->AufNr with M_AufNr
        loop
      endif
    endif
    if SYSTEM->AufNr < M_AufNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen Auftragsnummern werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J" ;
        .or. ! open("Aufaus","AufPost")
        replace SYSTEM->AufNr with M_AufNr
        loop
      endif
      restscreen(,,,,s01)
      select Aufaus
      if fil_lock()
        select AufPost
        if fil_lock()
          Message("Bitte warten...")
          okay:=.t.
          dele for val(AUFPOST->AufNr) >= SYSTEM->AufNr
          select AufAus
          dele for val(AUFAUS->AufNr) >= SYSTEM->AufNr
        endif
      endif
      if ! okay
        Error("Auftragsnummer"+NO_SYS_CHANGE)
        replace SYSTEM->AufNr with M_AufNr
      endif
    endif
    /* Ende Auftrag-Nummer checken */

    /*** Rechnungs-Nummer checken ***/
    if SYSTEM->RechNr > M_RechNr
      Beep()
      if ! Message("ACHTUNG: Rechnungsnummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->RechNr with M_RechNr
        loop
      endif
    endif
    if SYSTEM->RechNr < M_RechNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen Rechnungen werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J";
        .or. ! open("RECHAUS","RECHPOST")
        replace SYSTEM->RechNr with M_RechNr
        loop
      endif
      if ! open({"Summen",.t.})
        Error(TRY_AGAIN)
        loop
      endif
      restscreen(,,,,s01)
      select RECHAUS
      if fil_lock()
        sumNrs:={}
        stornoNrs:={}
        gbsNrs:={}
        backup("Summen")
        backup("Rechaus")
        backup("RechPost")
        select RECHPOST
        if fil_lock()
          Message("Bitte warten...")
          okay:=.t.
          dele for val(RECHPOST->RechNr) >= SYSTEM->RechNr
          select RECHAUS
          // dele for val(RECHAUS->RechNr) >= SYSTEM->RechNr
          set filter to val(RECHAUS->RechNr) >= SYSTEM->RechNr
          RECHAUS->(OrdSetFocus(0))
          go top
          do while ! RECHAUS->(eof())
            if ! empty(RECHAUS->SumNr)
              aaddUnique(sumNrs,RECHAUS->SumNr)
            endif
            if ! empty(RECHAUS->Storno_Nr)
              aaddUnique( stornoNrs , RECHAUS->Storno_Nr )
            endif
            if ! empty(RECHAUS->GelKz)
              aaddUnique( gbsNrs , RECHAUS->RechNr )
            endif
            delete
            skip
          enddo
          set filter to

          // jetzt summen.dbf und rechaus bereinigen, falls schon gedruckt
          if len( sumNrs ) > 0
            replace RECHAUS->SumNr with "" for ascan(sumNrs,RECHAUS->SumNr)>0
            select summen
            dele for ascan(sumNrs,SUMMEN->SumNr)>0
            Error(ACHTUNG+"Rechnungsausgangsbuch bitte neu drucken/pr�fen")
          endif

          // jetzt Storno-Rechnungen bereinigen, falls schon gedruckt
          if len( stornoNrs ) > 0
            replace RECHAUS->Storno_Nr with "" for ascan( stornoNrs , RECHAUS->RechNr )>0
          endif
          if len( gbsNrs ) > 0
            replace RECHAUS->GelReNr with "" for ascan( gbsNrs , RECHAUS->GelReNr )>0
          endif
        endif
        select System

      endif
      if ! okay
        Error("Rechnungsnummer"+NO_SYS_CHANGE)
        replace SYSTEM->RechNr with M_RechNr
      endif
    endif

    /*** SEPA-Nummer checken ***/
    if SYSTEM->SepaNr > M_SepaNr
      Beep()
      if ! Message("ACHTUNG: SEPA-Nummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->SepaNr with M_SepaNr
        loop
      endif
    endif
    if SYSTEM->SepaNr < M_SepaNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen XML Zahlungen werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J";
        .or. ! open("ZAHLAUS")
        replace SYSTEM->SepaNr with M_SepaNr
        loop
      endif
      restscreen(,,,,s01)
      select ZAHLAUS
      if fil_lock()
        Message("Bitte warten...")
        okay:=.t.
        dele for val(ZAHLAUS->ZahlNr) >= SYSTEM->SepaNr .and. ZAHLAUS->KZ==SEPA_KZ
      endif
      if ! okay
        Error("SEPA-nummer"+NO_SYS_CHANGE)
        replace SYSTEM->SepaNr with M_SepaNr
      endif
    endif
    /* Ende Auftrag-Nummer checken */

    /*** Lieferschein-Nummer checken ***/
    if SYSTEM->LsNr > M_LsNr
      if !;
        Message("ACHTUNG: Lieferscheinnummer er�hen ?  Sind Sie sicher ? ( @J@ / @N@ )","JN")=="J"
        replace SYSTEM->LsNr with M_LsNr
        loop
      endif
    endif
    if SYSTEM->LsNr < M_LsNr
      Beep()
      Error(ACHTUNG+"Alle h�heren und gleichen Lieferscheinnummern werden gel�scht !",ERR_NO_WAIT)
      if ! Message("Sind Sie sicher ? (@J@/@N@)","JN"+chr(K_ESC))=="J" ;
        .or. ! open("Liefaus","Liefpost")
        replace SYSTEM->LsNr with M_LsNr
        loop
      endif
      restscreen(,,,,s01)
      select Liefaus
      if fil_lock()
        select Liefpost
        if fil_lock()
          Message("Bitte warten...")
          okay:=.t.
          dele for val(LIEFPOST->LsNr) >= SYSTEM->LsNr
          select Liefaus
          dele for val(LIEFAUS->LsNr) >= SYSTEM->LsNr
        endif
      endif
      if ! okay
        Error("Lieferscheinnummer"+NO_SYS_CHANGE)
        replace SYSTEM->LsNr with M_LsNr
      endif
    endif
    /* Ende Auftrag-Nummer checken */

    okay:=.t.
    restscreen(,,,,s01)
  enddo
  dbcommitall()
  dbunlockall()
  close data
RETURN

/* aender-Artikel
*
* zus�tzl. Dateien �ffnen , Relationen setzen  etc.
*
*/
PROCEDURE ArtikelAendern(AutoSperrung, mArtNr)
LOCAL Message

  if ! openArtikelAendernDateien()
    Error(TRY_AGAIN)
    cls
    close data
    return
  endif

  message:="@F1@=Hilfe @F4@=Honsel-Nr. "+STAND_MESSAGE

  aend("Artikel",Message,,"    @F4@=Honsel-Nr  ", AutoSperrung, mArtNr)

  close data

RETURN
/* EOP Art_aend() */

/** �ffnet alle Dateien & Relas die zum Bearbeiten des Artikel-Stamms ben�tigt werden */
function openArtikelAendernDateien()
  if !;
    open("AufPost" , "AufAus" , "BesPost" , "BesAus", "Artikel" ,"Rabatt" ,"Text","Maschine","Kunden", "Einheit" , "Avpost" , "Instrukt" ,"AvAus","Inner" , "AvSortNr","IntraStat","ArtPreis", "Lieferan","LagerOrt","KundSped","Auftrag","M_Mehrf","Mehrfach","Angaus","Waraus","KdKontakt")
    return .f.
  endif

  select Aufpost
  AUFPOST->(OrdSetFocus(4)) // Artikel-Nr+Auf.Nr
  set relation to AUFPOST->AufNr into Aufaus

  select BesPost
  BESPOST->(OrdSetFocus(2)) // Artikel-Nr+Auf.Nr
  set relation to BESPOST->BestNr into BesAus

  select Inner
  INNER->(OrdSetFocus(2)) // Artikel-Nr+Auf.Nr

  select Artikel
  set relation to ARTIKEL->ME into Einheit

return .t.
/** eof */


FUNCTION repArtAnzeig()
  Hilfe("REPARTANZEIG",getnew(,,,"STAT_ART"),"STAT_ART")
return .t.

/** Aendern von Kunden */
Procedure KundenAendern(mKundNr)
LOCAL ALt_Message
  if !;
    open("Kunden","AufPost","AufAus","Spedit","Land","Mwst_Kz","BankStam","RechPost","Rechaus","KundSped", "KundZoll","Email","AngAus","BesAus","KdKontakt")
    Error(TRY_AGAIN)
    close data
    return
  endif

  Alt_Message:="@V@ers./Sped. @F3@=Artikel @F5@=Sammelst. @F6@=altern.Re.Adr. @F9@=Auftr."
  aend("Kunden",Alt_Message,,,,mKundNr)

  close data
return
/** eop */

/** Aendern von Lieferant */
Procedure LieferantAendern(mLiefNr)
LOCAL ALt_Message:="@�@ndern @B@estellk. @L@�schen @F3@=Artikel @F9@=off.Best. @F12@ @N@eu @K@opieren Ende @(x,ESC)@"
  if open( "Lieferan" , "BankStam" , "Land","AvPost","M_Mehrf", "Auftrag", "AufPost", "AUFAUS", "Kunden")
    select Lieferan
    aend("Lieferan",Alt_Message,,,,mLiefNr)
  endif
  close data
return
/** eop */

/** Aendern der Honselda Datei */
Procedure honseldatAend
LOCAL ALt_Message,ausw

  do while .t.

    cls
    titel("Honsel Inventur Datei �ndern")

    @ 5,12 to 16,70
    @ 6,15 say "Filter Auswahl:"
    @ 8,15 Prompt "1. Alle                                             "
    @ 9,15 Prompt "2. Minderbestand    (HonselBestand < Miki K.Bestand)"
    @ 10,15 Prompt "3. Mehrbestand      (HonselBestand > Miki K.Bestand)"
    @ 11,15 Prompt "4. Gleicher Bestand (HonselBestand = Miki K.Bestand)"
    @ 12,15 Prompt "5. Nur Fehlerhafte  (1 = ohne MikiNr)               "
    @ 13,15 Prompt "6. Nur Fehlerhafte  (2 = nicht in Honsel-Liste)     "
    @ 14,15 Prompt "7. Nur Fehlerhafte  (3 = kein K-Lager Artikel)      "
    @ 15,15 Prompt "8. Nur Fehlerhafte  (4 = Honsel-Nr. falsch)         "
    Message("Ihre Auswahl bitte.                  @ESC@=Ende")
    Menu to Ausw

    if ABBRUCH
      exit
    endif

    if ! open( "Honselda" , "Artikel", "Konsig","AufAus","AufPost")
      Error(TRY_AGAIN)
      cls
      close data
      RETURN
    endif

    select AufPost
    AUFPOST->(OrdSetFocus(2)) // KundNr + Art + ArtNr

    select Honselda
    set relation to HONSELDA->Miki_nr into Artikel

    do case
    case Ausw=1
      set filter to
    case Ausw=2
      set filter to HONSELDA->HonselBest < HONSELDA->MikiBest
    case Ausw=3
      set filter to HONSELDA->HonselBest > HONSELDA->MikiBest
    case Ausw=4
      set filter to HONSELDA->HonselBest = HONSELDA->MikiBest
    case Ausw=5
      set filter to HONSELDA->Fehler=="1"
    case Ausw=6
      set filter to HONSELDA->Fehler=="2"
    case Ausw=7
      set filter to HONSELDA->Fehler=="3"
    case Ausw=8
      set filter to HONSELDA->Fehler=="4"
    endcase

    go top

    Alt_Message:="@�@ndern / @L@�schen / @E@xport / @I@nventur / @F12@-@N@eu / Ende @(x,ESC)@"
    aend("Honselda",Alt_Message,"K")

  enddo
  close data

return

/** druckt die akt. sel. Preis.Kalk eines Artikels */
  // static function KalkHistorie
  // LOCAL s01:=savescreen()
  // Drucker("ON")
  // qout(ARTPREIS->KalkDetail)
  // Drucker("OFF")
  // restscreen(,,,,s01)
  // keyboard chr(K_HOME)
  // return .t.



  /** Mergen von div. Stammdaten, z.B. alte englische Versandarten in deutsche mit �bersetzung
  */
Procedure renameData()
LOCAL datei,aDatei:=db_info(alias())
LOCAL NrAlt:=getKeyFieldValue(aDatei)
LOCAL aktRec:=&(aDatei[D_NAME])->(recno())
LOCAL okay:=.t.,isOpen,printBuffer
LOCAL GetList:={},mergen:=.f.
LOCAL Eingabe:="M->X"+getKeyFieldName(adatei),pic
LOCAL aZielDatei , feld

  // pr�fe ob Aktion f�r akt. Datei erlaubt
  if ! aDatei[D_NAME] $ RENAME_ALLOWED
    return // nop
  endif

  if ! getUser():mayEnterSysMenu
    Error("Sie brauchen Rechte zum �ndern der Systemdaten, um "+aDatei[D_KURZ]+;
      " zu verschieben.",.t.)
    return
  endif

  // pr�fe ob noch andere Benutzer eingeloggt sind
  if ! open("Login")
    Error(TRY_AGAIN)
    return
  endif

  select (aDatei[D_NAME])

  if ! DEVEL_PROG .and. ;
    (printBuffer:=LoginDispatcher():new():getPrintBuffer()):getNumLines()>0
    Error(ACHTUNG+"Bitte vorher andere Miki-Programme ("+getUser():id+") schlie�en.|"+;
      "         "+aDatei[D_KURZ]+" umbenennen nicht m�glich.",.t.)
    if Message("Andere Benutzer anzeigen? (@J@/@N@)","JN","J")=="J"
      Drucker("BS")
      getUser():getCurrentPrintJob():printBuffer(printBuffer)
      getUser():getCurrentPrintJob():endDoc()
    endif
    return
  endif

  // Eingabe neue Nr.
  @ Maxrow(),0 clear
  &Eingabe:=nrAlt
  switch aDatei[D_ART]
  case "N"
    pic:=replicate("#",len(Field(1)))
    exit
  case "Z"
  case "A"
    pic:="@K!"
    exit
  case "Y"
    pic:="@K!A"
    exit
  case "K"
    pic:=KDNR_PICT
    exit
  case "H"
    pic:=REPKDNR_PICT
    exit
  otherwise
    pic:="@K"
  endswitch

  @ Maxrow(),20 say "Umbennen nach:" get &Eingabe PICTURE pic
  read

  if ABBRUCH
    return
  endif

  if valtype(aDatei[D_NEW_REC_SHIFT])=="B"
    &Eingabe:=eval(aDatei[D_NEW_REC_SHIFT],&Eingabe)
  endif

  &(aDatei[D_NAME])->(dbseek(&Eingabe))
  if ! &(aDatei[D_NAME])->(eof())
    go (aktRec)
    if aDatei[D_NAME] $ NO_MERGE_ALLOWED
      Error(aDatei[D_KURZ]+": "+&Eingabe+" existiert bereits.  Bitte vorher manuell l�schen.",.t.)
      return
    else
      if message(aDatei[D_KURZ]+": "+&Eingabe+;
        " existiert bereits.  Zusammenf�hren? (@J@/@N@)","JN","N")<>"J"
        return
      endif
      mergen:=.t.
    endif
  else // neuer Datensatz exisitiert noch nicht -> Abfrage
    go (aktRec)
    if message(aDatei[D_KURZ]+" umbenennen nach: "+&Eingabe+"? (@J@/@N@)","JN")<>"J"
      return
    endif
  endif

  trouble(RENAME_LOG,{aDatei[D_KURZ]+" umbenennen: "+trim(NrAlt)+" -> "+trim(&Eingabe)})

  // we lock the article record and system.dbf as semaphore
  if ! open({"System",.t.})
    select (aDatei[D_NAME])
    Error(TRY_AGAIN)
    return
  endif

  select (aDatei[D_NAME])
  if ! rec_lock(5)
    Error(TRY_AGAIN)
    dbunlockall()
    return
  endif

  // merke feld name
  feld:=getKeyFieldName(adatei)

  mkmydir(PS_PDF_RENAME+BACKSLASH+aDatei[D_KURZ])
  Protokoll(INIT_P,aDatei[D_KURZ]+": "+nrAlt+" -> "+&Eingabe+" "+toString(fieldget(2)),,,,, nrAlt+;
    "-"+&Eingabe,PS_PDF_RENAME+BACKSLASH+aDatei[D_KURZ])

  for each datei in getMikiDBNames() // Artikel ist 1. Datei!!!

    aZielDatei:=db_info(datei)
    do case
    case upper(datei)==aDatei[D_NAME] // current db is handled at the end
      // nop
    case aZielDatei[D_TEMP] // close all temp. Files, will be deleted
      close (datei)
    otherwise

      isopen:=(select(datei)>0)
      if isOpen
        select (Datei)
        // FIL_LOCK(0)
      else
        if ! open(datei)
          trouble(RENAME_LOG,{datei+" konnte nicht ge�ffnet werden.", aDatei[D_KURZ]+" umbenennen"+;
            ": "+trim(NrAlt)+" -> "+trim(&Eingabe)})
          loop
        endif
      endif

      // now rename all dependencies
      switch aDatei[D_NAME]
      case "ARTIKEL"
        // renameArtNr(nrAlt,&Eingabe)
        renameDatNr(aDatei,{"ArtNr","AvNr","ANr"},nrAlt,&Eingabe)
        exit
      case "MASCHINE"
        // special case St�ckliste, da Feldname Artnr und 10 Stellen anstatt 3
        if aZielDatei[D_NAME]=="AVPOST"
          set filter to AVPOST->Art=="V" .and. AVPOST->Text=="A"
          go top
          // trailing spaces so machine number fits artnr
          renameDatNr(aDatei,{"ArtNr"},nrAlt+space(7),&Eingabe)
        else
          renameDatNr(aDatei,{"StdNr","NachKz","MaschNr"},nrAlt,&Eingabe)
        endif
        exit
      otherwise
        renameDatNr(aDatei,{feld},nrAlt,&Eingabe)
      endswitch

      if isOpen
        dbunlock()
      else
        close (datei)
      endif
    endcase
  next

  select (aDatei[D_NAME])
  go (aktRec)
  if mergen
    delete
    &(aDatei[D_NAME])->(dbseek(&Eingabe))
  else

    // special case Artikel, we remember the old nr
    if aDatei[D_NAME]=="ARTIKEL"
      replace ARTIKEL->AltArtNr with ARTIKEL->ArtNr
    endif

    fieldPut(getKeyFieldPos(adatei),&Eingabe)

  endif
  dbcommit()
  dbunlock()

  Protokoll(P_CREATE_PDF,,,,.t.)

  deleteTempFiles()

  close("System")

return
/** eop */


/** Renamed alle Vorkommnise des Key-Feldes aus aDatei in der aktuellen Datei */
static procedure renameDatNr(aDatei,felder,nrAlt,nrNeu)
LOCAL oldOrder:=0,oldValue
LOCAL count,pos,feld
LOCAL zielDatei:=upper(alias()),aZielDatei:=db_info(zielDatei)
LOCAL text:=""

  Message(aDatei[D_KURZ]+" umbenennen: "+trim(NrAlt)+" -> "+trim(NrNeu)+"   @"+;
    zielDatei+"@  Bitte warten...")

  for each feld in felder
    count:=0
    if (pos:=fieldpos(feld))>0
      text:=zielDatei+"->"+feld+MY_CR+MY_LF
      oldorder:=indexOrd()
      fil_lock(0)
      OrdSetFocus(0) // to ensure all indices are maintainend and the record counter does not jump uncontrolled
      go top
      do while ! (zielDatei)->(eof())
        oldValue:=fieldget(pos)
        // Ausnahme bei KW, da vergleichen wir linksb�ndig
        if oldValue == NrAlt .or. ( feld=="KW" .and. left(oldValue,len(NrAlt)) == NrAlt )
          if zielDatei$"RECHAUS,BESPOST,BESAUS,INNER,AUFPOST,AUFAUS,REPAUS,GERAT"
            text+=fieldget(1)+" "
          elseif zielDatei$"RECHPOST"
            text+="AB:"+fieldget(1)+"/Re:"+fieldget(fieldpos("RechNr"))+" " // REchNr
          elseif zielDatei$"KUNDEN,LIEFERAN"
            text+=space(3)+fieldget(1)+" "+fieldget(2)+MY_CR+MY_LF
          elseif zielDatei$"AVPOST" .and. feld=="ArtNr"
            text+=fieldget(1)+" "
          else
            text+=toString(fieldget(1))+" "
          endif
          fieldput(pos,NrNeu)
          count++
        endif
        skip
      enddo
      dbcommitall()
      dbunlock()
      OrdSetFocus(oldOrder)
    endif
    if ! empty(text) .and. count > 0
      Protokoll(PROTOKOLL,text)
    endif
  next

return
  /** eop */

  /** Umbenennen von Intrastat / Waren- bzw. ZolltarifNummern
  * basiert auf renameData (s.o.)
  */
Procedure renameIntrastat()
LOCAL aDatei:=db_info(alias())
LOCAL NrAlt:=getKeyFieldValue(aDatei)
LOCAL aktRec:=&(aDatei[D_NAME])->(recno())
LOCAL okay:=.t.
LOCAL GetList:={},mergen:=.f.
LOCAL Eingabe:="M->X"+getKeyFieldName(adatei),pic
LOCAL feld, ignoreArtikel:={}

  if ! getUser():mayEnterSysMenu .and. getUser():id <> "AB" // Frau Bernd darf Intrastat
    Error("Sie brauchen Rechte zum �ndern der Systemdaten, um "+aDatei[D_KURZ]+;
      " zu verschieben.",.t.)
    return
  endif

  // Eingabe neue Nr.
  @ Maxrow(),0 clear
  &Eingabe:=nrAlt
  pic:="@K!"
  @ Maxrow(),20 say "Umbennen nach:" get &Eingabe PICTURE pic
  read

  if ABBRUCH
    return
  endif

  &(aDatei[D_NAME])->(dbseek(&Eingabe))
  if ! &(aDatei[D_NAME])->(eof())
    go (aktRec)
    Error(aDatei[D_KURZ]+": "+&Eingabe+" existiert bereits.  Bitte vorher manuell l�schen.",.t.)
    return
  else // neuer Datensatz exisitiert noch nicht -> Abfrage
    go (aktRec)
    if message(aDatei[D_KURZ]+" umbenennen nach: "+&Eingabe+"? (@J@/@N@)","JN")<>"J"
      return
    endif
  endif

  Message("Warennummer wird ge�ndert.  Bitte warten...")

  trouble(RENAME_LOG,{aDatei[D_KURZ]+" umbenennen: "+trim(NrAlt)+" -> "+trim(&Eingabe)})

  select (aDatei[D_NAME])
  if ! rec_lock(5)
    Error(TRY_AGAIN)
    dbunlockall()
    return
  endif

  // merke feld name
  feld:=getKeyFieldName(adatei)

  mkmydir(PS_PDF_RENAME+BACKSLASH+aDatei[D_KURZ])

  Protokoll(INIT_P,aDatei[D_KURZ]+": "+nrAlt+" -> "+&Eingabe+" "+toString(fieldget(2)),,,,, nrAlt+;
    "-"+&Eingabe,PS_PDF_RENAME+BACKSLASH+aDatei[D_KURZ])

  if ! open("Artikel")
    Error(TRY_AGAIN)
    dbunlockall()
    return
  endif

  select Intrastat
  if rec_lock(5)
    replace INTRASTAT->WarenNr with &Eingabe
  else
    Error(TRY_AGAIN)
    dbunlockall()
    return
  endif

  select Artikel
  index on ARTIKEL->WarenNr tag TEMP_INDEX TEMPORARY ADDITIVE
  dbseek( nrAlt )
  do while ! ARTIKEL->(eof()) .and. ARTIKEL->WarenNr == nrAlt
    if rec_lock(5)
      replace ARTIKEL->WarenNr with &Eingabe
      Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+nrAlt+" => " + &Eingabe)
      dbcommit()
      dbunlock()
      dbseek( nrAlt )
      do while ! ARTIKEL->(eof()) .and. aContains(ignoreArtikel, ARTIKEL->ArtNr )
        skip
      enddo
    else
      Protokoll(PROTOKOLL,ARTIKEL->ArtNr+" "+ARTIKEL->Bez1+" "+nrAlt+" Fehler bitte pr�fen.")
      aadd(ignoreArtikel, ARTIKEL->ArtNr)
      skip
    endif
  enddo

  dbcommitall()
  dbunlockall()
  Protokoll(P_CREATE_PDF,,,,.t.)

  select Intrastat

return
/** eop */



procedure InnerEdit( alle )
LOCAL XInnerNr
LOCAL GetList:={}

  default alle:=.t.
  cls
  Titel("Innerbetr. Auftr�ge bearbeiten")

  if ! getUser():mayCreateInnerOrders
    Error(ACHTUNG+"Fehlende Rechte.",.t.)
    return
  endif

  if ! open("Inner","Artikel","AufAus","AufPost","InnEdit","AvPost","Einheit","NkPost")
    Error(TRY_AGAIN)
    close data
    cls
    return
  endif

  // InnEdit -> Alias Auferfas
  select Auferfas // InnEdit
  zap
  select Inner

  if alle

    INNER->(OrdSetFocus(3)) // lfdNr
    aend("Inner",;
      { || if(INNER->Erledigt=="J",;
      "@�@ndern @D@rucken @W@iederherstellen @L@�schen @F3@=Bem. @F12@ @N@euEnde @(x,ESC)@",;
      "@�@ndern @D@rucken @E@rledigt @L@�schen @F3@=Bem. @F12@ @N@euEnde @(x,ESC)@")},;
      "KSRPU ",NIL,NIL,NIL,NIL) // Tasten gesperrt

  else
    INNER->(OrdSetFocus(1)) // InnerNr mit Filter

    XInnerNr:=space(len( INNER->InnerNr ))
    do while .t.
      cls
      Titel("Innerbetr. Auftr�ge bearbeiten")
      @ 6,20 say "Mappen-Nr: " get XInnerNr picture "@K9";
        when Message("Innerbetr. Mappen-Nummer eingeben.    @F12@=Auswahl") ;
        valid { |oGet| check(oGet,"Inner",.f.,.f.) }
      read
      if ABBRUCH
        exit
      endif

      if INNER->Erledigt=="J"
        Error(ACHTUNG+"erledigter Auftrag kann nicht bearbeitet werden.")
        loop
      endif

      // jetzt Autrags-Posten editieren
      Av_Auf_erfass( INNER_EDIT , INNER->InLfdNr )

    enddo
  endif

  close data

return
/** eop */

/** setzt oder l�scht das erledigt Kennzeichen im allen relavanten inner.dbf S�tzen
  ACHTUNG: es kann bei Mehrfachspritzung mehrere Artikel je Mappen-Nr. geben
  neu 20200925: es kann auch mehrer Eintr�ge f�r mehrere Arbeitsg�nge geben.
  */
static procedure recallAllInner(ant , neuMappNr)
LOCAL merkDat, merkWkz, missing
LOCAL mInnerNr:=INNER->InnerNr
LOCAL aktSel:=alias()
LOCAL aktRec:=INNER->(recno())
LOCAL merk_order:=INNER->(indexord())

  // neu 20200716: pr�fen ob NachKalk bereits erfasst
  if ant == "E"
    missing:=getFehlendeNachkalkNummern(mInnerNr)
    if len(missing) > 0
      if (getUser():mayIgnoreNachkalk)
        if Message(missing+;
          " keine Nachkalkulation erfasst.  Als erledigt deklarieren? (@J@/@N@)","JN","N")<>"J"
          return
        endif
      else
        // schreibeEmailKZ("Versuch")
        ERROR("Auftrag: " + dispInnerNr(INNER->InnerNr, INNER->ArbGang)+;
          "||Bitte zuerst Nachkalkulation (1.31) erfassen.",.t.)
        return
      endif
      // else // no missing
      // schreibeEmailKZ("Erfolg")
    endif
  endif

  // markiere alle relevanten Eintr�ge in inner.dbf als erledigt/offen
  if empty(INNER->Werkzeug) .and. empty(INNER->ArbGang)
    recallInner(ant , neuMappNr )
  else
    if ! empty(INNER->Werkzeug)
      merkWkz:=INNER->Werkzeug
      merkDat:=INNER->AufDat

      // brauchen Index ohne for clause erledigt, da er beim setzen sonst springt
      index on INNER->InLfdNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        (mInnerNr==INNER->InnerNr .or. neuMappNr==INNER->InnerNr );
        .and. merkWkz == INNER->Werkzeug .and. merkDat == INNER->AufDat
    else // ! empty(INNER->ArbGang)
      merkWkz:=INNER->ArtNr
      merkDat:=INNER->AufDat

      // brauchen Index ohne for clause erledigt, da er beim setzen sonst springt
      index on INNER->InLfdNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
        (mInnerNr==INNER->InnerNr .or. neuMappNr==INNER->InnerNr );
        .and. merkWkz == INNER->ArtNr .and. merkDat == INNER->AufDat
    endif

    // gehe auf den 1. mit der Mappen-Nr.
    INNER->(dbgotop())

    do while ! INNER->(eof())
      recallInner(ant , neuMappNr)
      skip
    enddo
    INNER->(OrdDestroy(TEMP_INDEX))
  endif

  select (aktSel)
  INNER->(OrdSetFocus( merk_order ))
  INNER->(dbgoto(aktRec))

return
/** eop */

/** setzt oder l�scht das erledigt Kennzeichen im aktuellen inner.dbf Satz */
static procedure recallInner(ant , neuMappNr)
  switch ant
  case "E"
    rec_lock(0)
    replace INNER->Erledigt with "J"
    dbcommit()
    dbunlock()
    exit

  case "W"
    rec_lock(0)
    replace INNER->Erledigt with " "
    if neuMappNr <> NIL
      replace INNER->InnerNr with neuMappNr
    endif
    dbcommit()
    dbunlock()
    exit

  endswitch

  // BestellBestand neu berechnen
  BestBestand( BEST_INT , INNER->ArtNr )
  AufBestand()
return
/** eop */

/** l�schen von aktiven innerbetr. Auftr�gen */
procedure InnerDelete()
LOCAL ant
LOCAL XInnerNr
LOCAL GetList:={}

  cls
  Titel("Innerbetr. Auftr�ge erledigt/l�schen")

  if ! getUser():mayCreateInnerOrders
    Error(ACHTUNG+"Fehlende Rechte.",.t.)
    return
  endif

  if ! open("Inner","Artikel","AufAus","AufPost","InnEdit","AvPost","Einheit","NKMail","NKPost")
    Error(TRY_AGAIN)
    close data
    cls
    return
  endif

  // InnEdit -> Alias Auferfas
  select Auferfas // InnEdit
  zap
  select Inner

  INNER->(OrdSetFocus(1)) // InnerNr mit Filter

  XInnerNr:=space(len( INNER->InnerNr ))
  do while .t.
    cls
    Titel("Innerbetr. Auftr�ge erledigt/l�schen")
    @ 6,20 say "Mappen-Nr: " get XInnerNr ;
      when Message("Innerbetr. Mappen-Nummer eingeben.    @F12@=Auswahl") ;
      valid { |oGet| check(oGet,"Inner",.f.,.f.) }
    read
    if ABBRUCH
      exit
    endif

    // jetzt Autrags-Posten anzeigen
    Av_Auf_erfass( INNER_EDIT , INNER->InLfdNr , .t. )

    ant:=Message("Auftrag @e@rledigt -- @ESC@=Abbruch","E")
    if ! ABBRUCH
      select Inner // filter noch gesetzt
      dbseek( XInnerNr )
      if ant == "E"
        // als erledigt deklarieren
        recallAllInner(ant , nil )
      endif
    endif
  enddo
  close data

return
/** eop */


/** wandelt alte String-Notation der gesperrten Tasten in ASCII Werte
 * (Gro� und Kleinschreibung) um */
static procedure convertLockedKeys( gesperrteAsciKeys , tasten_gesperrt)
LOCAL i
  for i:=1 to len(tasten_gesperrt)
    aadd( gesperrteAsciKeys , asc( upper(substr(tasten_gesperrt,i,1) )) )
    aadd( gesperrteAsciKeys , asc( lower(substr(tasten_gesperrt,i,1) )) )
  next
return

/** Zum Markieren von einzelnen Rechnungsposten, dass diese nicht in
  * der IntraStat Meldung erscheinen */
PROCEDURE IntraStatEdit()
LOCAL Ende:=.f., Monat, Jahr, myDate:=getUser():date, i, GetList:={}, merkDat

  cls
  Titel("Intra-Stat. Datei bearbeiten")

  Message("Rechnungen werden gesucht.  Bitte warten...")

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

  if open("Rechaus","Rechpost")
    select Rechaus
    index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE for ;
      RECHAUS->EG=="J" .and. empty( RECHAUS->STORNO_NR ).and. RECHAUS->AufArt <> "G" ;
      .and. ! ( RECHAUS->MwSt > 0 .or. left(RECHAUS->V_KundNr,5) == MIKI_NR ) ;
      .and. month(RECHAUS->readat)=Monat .and. year(RECHAUS->readat)=Jahr;
      .and. RECHAUS->ReaDat > ctod("01.01.14")

    select Rechpost
    set rela to RECHPOST->RechNr into Rechaus
    index on RECHPOST->RechNr tag TEMP_IND2 TEMPORARY ADDITIVE for ;
      ! RECHAUS->(eof()) .and. len(alltrim(RECHPOST->ArtNr)) > FRACHT_LAENGE

    // finde ersten nicht gedruckten Eintrag
    go top

    Hilfe("IntraStatEdit",getnew(),"Blubb")
    HB_KEYCLEAR()

    if Message("Intrastat-Datei erzeugen und per Email versenden? (@J@/@N@)","JN"," ");
      =="J"
      merkDat:=RECHAUS->ReaDat
      close data // need this -> so rechaus is reopned with default index etc.
      EuUmsatzIntraStatExport(.f.,.f.,merkDat)
    endif

  endif
  close data
  cls
return
/** eop */

/** �ndert den Intrstat-Status eines Rechnungspostens */
Function intrastatToggle()
  if rec_lock(5)
    if RECHPOST->IntraStat=="X"
      replace RECHPOST->IntraStat with ""
    else
      replace RECHPOST->IntraStat with "X"
    endif
    dbcommit()
    dbunlock()
  endif
return .t.
/** eof */

/* deletes cascading files of currently selected record
 * see aDatei[D_DELETE_CASCADE]
 *
 * FIXME: add recursive delete
 */
procedure deleteCascading()
LOCAL Datei:=db_info( alias() )
LOCAL tempValue, tempName , feldName, dateiName

  Umgebung( WRITE_ALL )

  if ! empty( Datei[D_DELETE_CASCADE] )
    tempValue:=getKeyFieldValue( Datei )
    feldName:=getKeyFieldName( Datei )
    for each tempName in Datei[D_DELETE_CASCADE]
      if valtype( tempName ) == "A"
        dateiName:=tempName[1]
      else
        dateiName:=tempName
      endif
      if ! open( dateiName ) .or. fieldpos(feldName) == 0
        TroubleEmail( dateiName + " " + dateiName + ": " + tempValue + "|triggered by " + ;
          Datei[D_NAME] + "konnte nicht gel�scht werden.")
      else
        Select ( dateiName )
        // anderer Index vorgegeben?
        if valtype( tempName ) == "A"
          (DATEINAME)->(OrdSetFocus( tempName[2] ))
        else
          (DATEINAME)->(OrdSetFocus( 1 ))
        endif
        seek ( tempValue )
        do while .not. eof() .and. fieldget(fieldpos(feldName)) == tempValue
          rec_Lock(0)
          delete
          skip
        enddo
      endif
    next
    select (Datei[D_NAME])
  endif

  Umgebung( LOAD )

return

/** pr�ft ob �nderungen am Datensatz gemacht wurden und sperichert diese im MemoFeld Bemerkung,
  * falls vorhanden
  */
static procedure protAend( before , after )
LOCAL i , myText , count:=0

  // only if memo field exists
  if fieldpos("Bemerkung") == 0 .or. fieldtype(fieldpos("Bemerkung"))<>"M"
    return
  endif

  myText:=dtoc( getUser():date ) + " " + getUser():id + " " + MY_CR + MY_LF

  for i:=1 to len( before )
    if before[i] <> after[i] .and. ! fieldName( i ) $ "MOD_DATE/MOD_TIME"
      count++
      myText += space(2) + getFieldText( alias() , fieldName( i ) ) + ": " + ;
        toString( before[i] ) + " -> " + toString( after[i] ) + MY_CR + MY_LF
    endif
  next

  if count > 0
    replace (ALIAS())->Bemerkung with myText + MY_CR + MY_LF + ((ALIAS())->Bemerkung)
  endif


return
/** eop */
/* Modul Edit.prg ***************************************
*
* FIXME: das ist alles ALTER ADEL, ein Cleanup w�re ratsam ist aber viel Aufwand und fehler-anf�llig.
*
* Beispieldef. in Fakt.prg
*
* Dateien sind schon ge�ffnet.
*
* Erl�uterungen: Zeile enth�lt die absolute BS-Zeile
*                1. Datensatz auf BS ist: aKopf[EDIT_START_Y]
*
*                PageOut:       Ausgabe des BS ab akt. Zeile
*                                akt. Zeile wird 1. Bs-Zeile
*                BS_AUs  :       gibt akt. BS neu aus
*                                ver�ndert Zeilenpos. nicht !
*
*
*                aKopf[Gesperrt]: enth�lt K�rzel deren Fkt. nicht erlaubt sind
*/
#define HAUPT_FELD 1 // zu highlitendes Feld im Doppel-Modus

#include "hbgtinfo.ch"
#include "MyStd.ch"


#define MY_K_ENTER 1292812 // needed internally in handle_key() when ENTER is used for a special function

FUNCTION Edit(aFelder,aKopf,restoreWinSize)
LOCAL Taste:=0 , i
local Zeile:=aKopf[EDIT_START_Y] // 1. Zeile
LOCAL temp
LOCAL pos_x:=0 ,pos_y:=0
LOCAL Mes_Mod2:=""
LOCAL oldReadExit:=readexit() // brauchen wir bei geschachtelten Edits, 3.3.2012

Local sizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
Local sizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
LOCAL posx:=hb_gtInfo( HB_GTI_SETPOS_XY )[1]
LOCAL posy:=hb_gtInfo( HB_GTI_SETPOS_XY )[2]
Local fullScreen:=hb_gtInfo(HB_GTI_ISFULLSCREEN)
Local fontMode:=hb_gtInfo(HB_GTI_RESIZEMODE)
LOCAL tempFontWidth:=hb_gtInfo( HB_GTI_FONTWIDTH )
LOCAL tempFontSize:=hb_gtInfo( HB_GTI_FONTSIZE )

  // Local tempPos,tempSizeX,tempSizeY,tempFullscreen, tempUser
Local callerName:=procname(3)
LOCAL aktAlias:=alias()

MEMVAR IndexFeld,akt_spalte
PRIVATE IndexFeld:=1
PRIVATE akt_spalte
PRIVATE unt_rand

  default restoreWinSize:=.t.

  // Umgebung(WRITE)

  if restoreWinSize

    // don't resize font => use additional resize space for additional columns
    hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_ROWS )

    // init screen size for later resize events
    resizeBSAus()

    // don't save ind. window size for editors
    // if ! open("Fenster")
    // Error(ACHTUNG+"Fenster-Groesse kann nicht gesetzt werden.|"+callerName+"???",.t.,"root")
    // else

    // tempUser:=getUser():getWindowStorageID()
    // select Fenster
    // FENSTER->(dbseek(left(callerName+space(10),10)+left(tempUser+space(10),10)))
    // if FENSTER->(eof()) // Liste von User zum 1. Mal geöffnet
    // // nop
    // else
    // // setze aktuelle Fenster-Groesse & Position
    // if FENSTER->Maximized=="J" .and. getUser():saveWinSize
    // hb_gtInfo(HB_GTI_ISFULLSCREEN,.t.)
    // else
    // if FENSTER->SizeX>0 .and. getUser():saveWinSize
    // qout(" ") // needed as workaround for bug in setSize
    // hb_gtInfo(HB_GTI_SCREENSIZE , { FENSTER->SizeX, FENSTER->SizeY } )
    // endif
    // if getUser():saveWinPos
    // qout(" ") // needed as workaround for bug in setPos
    // hb_gtInfo(HB_GTI_SETPOS_XY,{ FENSTER->PosX, FENSTER->PosY} )
    // endif
    // endif
    // endif
    // endif
  else
    // Windows resize disabled, e.g. in innner editors
    hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_FONT )
  endif
  select(aktAlias)

  /* default f�r Index-Feld == 1 */
  aKopf:=initAKopf(aKopf,aFelder)

  M->akt_spalte:=aKopf[EDIT_GET_OFFSET]

  // clear extra lines?
  clearDispLines(aKopf)

  /* Fenster-Rahmen ? */
  if aKopf[EDIT_DRAW_FRAME]<>NIL
    drawEditFrame( aKopf, aFelder, aKopf[EDIT_DRAW_FRAME] )
  endif

  /* standard-Message generieren */
  Mes_Mod2+=if("�"$upper(getGesperrtKeys(aKopf)),""," @�@ndern")
  Mes_Mod2+=if("N"$upper(getGesperrtKeys(aKopf)),""," @N@eu")
  Mes_Mod2+=if("E"$upper(getGesperrtKeys(aKopf)),""," @E@inf.")
  Mes_Mod2+=if("L"$upper(getGesperrtKeys(aKopf)),""," @L@�schen")
  Mes_Mod2+=if("Z"$upper(getGesperrtKeys(aKopf)),""," @Z@ur�ck")
  for i:=1 to len(aKopf[EDIT_EXTRA_FKT])
    if aKopf[EDIT_EXTRA_FKT,i,EDIT_EXTRA_MESSAGE]<>NIL
      Mes_Mod2+=aKopf[EDIT_EXTRA_FKT,i,EDIT_EXTRA_MESSAGE]
    endif
  next
  Mes_Mod2+=if("S"$upper(getGesperrtKeys(aKopf)),""," @F7@/@F8@=Suchen")
  Mes_Mod2+=" @ESC@=Ende "

  do while Taste <> K_ESC .and. taste <> EDIT_QUIT .and. ! chr(Taste) $ aKopf[EDIT_ENDE]

    /* Titel-Zeile */
    Titel_Edit(aFelder,aKopf[EDIT_START_Y]-2,aKopf)

    /* falls leer f�ge Neuen Satz hinzu */
    if OrdKeyCount()==0 // .and. ! "N" $ getGesperrtKeys(aKopf) // removed am 11.3.2011
      Zeile:=handle_key(aFelder,aKopf,MY_K_ENTER,Zeile) // f�ge Leerzeile hinzu
      if ! "N" $ getGesperrtKeys(aKopf) // added am 11.3.2011
        Taste:=asc("N") // gehe in Editier-Modus
      endif
    endif

    /* gehe auf ersten zu Zeigenden Datensatz */
    goStartRec(aKopf)

    /* gebe aktuelle Seite aus */
    PageOut(aFelder,aKopf)
    goStartRec(aKopf)

    // Funktion die nach jeder �nderung ausgef�hrt werden soll aufrufen
    if aKopf[EDIT_BEFORE_EDIT_FKT]<>NIL
      eval(aKopf[EDIT_BEFORE_EDIT_FKT])
    endif

    // Z�hle Posten
    ZeigeAnzahl(aKopf)

    Zeile:=aKopf[EDIT_START_Y]
    LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus

    carry(WRITE,aFelder) // merke Feldinhalt

    /* je nach Modus, editieren bzw. Eingabe-Taste */

    do while Taste <> K_ESC .and. taste <> EDIT_QUIT .and. ! chr(Taste) $ aKopf[EDIT_ENDE]
      if Taste==0

        /* rel. x-y Verschiebung des Haupt-Feld ? */
        pos_y:=aFelder[HAUPT_FELD,EDIT_POS_Y]
        pos_x:=aFelder[HAUPT_FELD,EDIT_POS_X]

        /* higlighten der akt. Zeile */
        // SETPOS(Zeile+pos_y,aKopf[EDIT_LM]+pos_x) // akt. BS-Posoition
        // devOutPict( &(aFelder[HAUPT_FELD,EDIT_NAME]), aFelder[HAUPT_FELD,EDIT_MASKE] , COLINV )
        if valtype(aFelder[HAUPT_FELD,EDIT_MASKE])=="C" .and.;
          aFelder[HAUPT_FELD,EDIT_MASKE]==EDIT_PICT_FARBE
          colorSay(Zeile+pos_y,aKopf[EDIT_LM]+pos_x,&(aFelder[HAUPT_FELD,EDIT_NAME]),.t. )
        else
          LineOut(aFelder,aKopf,Zeile,BLAUER_BALKEN) // hightlight akt. Zeile aus
        endif

        /* evtl. Fkt. je Posten ausf�hren, ob Edit Posten beendet werden darf */
        if eval(aKopf[EDIT_FKT_IMMER])
          Message(mes_mod2)
          /* warte auf Eingabe */
          taste:=warte(0, INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN + INKEY_MWHEEL)
          // taste:=warte(0)
        else
          // Taste:=asc("a") // �ndern
          Taste:=EDIT_LINE_EDIT
        endif

        /* normale Darstellung akt. Zeile */
        // SETPOS(Zeile+pos_y,aKopf[EDIT_LM]+pos_x) // akt. BS-Posoition
        // devOutPict( &(aFelder[HAUPT_FELD,EDIT_NAME]), aFelder[HAUPT_FELD,EDIT_MASKE] , COLNOR )
        LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus

      endif

      /* gew�nschte Fkt. erlaubt ? */
      // if upper(chr(Taste)) $ getGesperrtKeys(aKopf)
      // Beep()
      // Taste:=0
      // loop
      // endif

      // FIXME: warum ist Abfrage hier getrennt von handle_key()
      // warum nicht alles in handle_key() ???
      do case

        // �ndern der aktuellen Zeile
      case (chr(Taste)$"��Aa"+HARBOUR_AE .or. Taste=EDIT_LINE_EDIT) .and.;
        ! upper(chr(Taste)) $ getGesperrtKeys(aKopf) .and. Taste <> K_CTRL_F9

        // // neu seit 11.3.2013, "�" kann auch als special Funktion definiert werden
        // // FIXME: besser w�re den ganzen case block komplett nach handle_key zu verlegen
        // if (i:=ascan(aKopf[EDIT_EXTRA_FKT],{ |aArr| chr(Taste)$aArr[1] .or. upper(chr(Taste))$aArr[1]})) > 0
        // eval(aKopf[EDIT_EXTRA_FKT,i,EDIT_EXTRA_BLOCK])
        // Taste:=K_ENTER
        // exit // Ist Abbruch hier immer gew�nscht?
        // endif

        // neu 20160223: Zeile nur editieren, falls Function erf�llt
        if aKopf[EDIT_BEFORE_ZEILE] <> NIL .and. ! eval(aKopf[EDIT_BEFORE_ZEILE])
          taste:=0
          exit
        endif

        // pr�fe ob nicht nur leerer Anfangsdatensatz -> dann "neu" ausf�hren
        if OrdKeyCount()==1 .and. eval(aKopf[EDIT_INDEX_FELD])
          Taste:=asc("N")
          loop
        endif

        aKopf[EDIT_CHANGED]:=.t.
        M->akt_spalte:=aKopf[EDIT_GET_OFFSET] // might has changed in prior column edit
        /* akt. Satz �ndern */
        Taste:=LineEdit(aFelder,aKopf,Zeile)
        /* nur editier-modus ? */
        do while aKopf[EDIT_MODUS] == 1 .and. Taste <> K_ESC .and. taste <> EDIT_QUIT .and. ;
          taste <> EDIT_APPEND
          temp:=Zeile
          Zeile:=handle_key(aFelder,aKopf,Taste,Zeile)
          // Neu: 15.10.2013 Im dauerhaften Editiermodus sollen am Schluss automat. Zeilen hinzgef�gt werden
          // we then switch to append modus
          // if Zeile == temp .and. taste == K_RETURN
          // Taste:=EDIT_APPEND
          // exit
          // endif
          Taste:=LineEdit(aFelder,aKopf,Zeile)
        enddo
        if ! chr(Taste) $ aKopf[EDIT_ENDE] // Unsch�n jojo
          Taste:=0 // warte in Bl�tterModus
          checkModeChangeFunction(aKopf)
        endif

        // Neu Eingabe Modus, immer Zeilen am Ende hinzuf�gen
      case (chr(Taste) $ "Nn" .or. Taste = EDIT_APPEND) .and. ! upper(chr(Taste)) $ getGesperrtKeys(aKopf)
        // aKopf[EDIT_CHANGED]:=.t. // JG: moved further down as of 20180103
        // neuen Satz hinzuf�gen
        /* gehe ans Ende */
        Zeile:=handle_key(aFelder,aKopf,K_END,Zeile)

        // neu seit 15.1.2013, "N" kann auch als special Funktion definiert werden
        // FIXME: besser w�re den ganzen case block komplett nach handle_key zu verlegen
        if (i:=ascan(aKopf[EDIT_EXTRA_FKT],{ |aArr| chr(Taste)$aArr[1] .or.;
          upper(chr(Taste))$aArr[1]})) > 0
          // if ! eval(aKopf[EDIT_EXTRA_FKT,i,EDIT_EXTRA_BLOCK])
          eval(aKopf[EDIT_EXTRA_FKT,i,EDIT_EXTRA_BLOCK])
          Taste:=K_ENTER
          exit // Ist Abbruch hier immer gew�nscht?
        endif

        Taste:=MY_K_ENTER
        do while Taste <> K_ESC .and. taste <> EDIT_QUIT
          /* f�ge neuen Datensatz hinzu */
          if OrdKeyCount()<=1 .and. eval(aKopf[EDIT_INDEX_FELD])
            /* steht beim ersten Mal auf 1. Satz (leer!) */
          else
            Zeile:=handle_key(aFelder,aKopf,Taste,Zeile)
          endif
          Taste:=LineEdit(aFelder,aKopf,Zeile)
          do case
          case Taste==K_PGDN
            /* evtl. Fkt. ausf�hren, darf Zeile verlassen werden (ist noch im Edit Modus) */
            if eval(aKopf[EDIT_FKT_IMMER])
              Taste:=MY_K_ENTER
            else
              // Taste:=asc("a") // �ndern
              Taste:=EDIT_LINE_EDIT
            endif
            aKopf[EDIT_CHANGED]:=.t.

          case Taste==K_PGUP
            Taste:=K_ESC
          case Taste==K_ENTER
            Taste:=MY_K_ENTER
            aKopf[EDIT_CHANGED]:=.t.
          endcase
        enddo
        if eval(aKopf[EDIT_INDEX_FELD])
          /* l�sche akt. Zeile */
          Zeile:=handle_key(aFelder,aKopf,EDIT_DELETE,Zeile)
        else
          aKopf[EDIT_CHANGED]:=.t.
        endif
        if ! chr(Taste) $ aKopf[EDIT_ENDE] // Unsch�n jojo
          Taste:=0 // warte in Bl�tterModus
          checkModeChangeFunction(aKopf)
        endif

        // Ausgabe des aktuellen BS
        case Taste == FKT_SPECIAL
          aKopf[EDIT_CHANGED]:=.t. // maybe not necessary, but like this we are save
          // alle Posten neu ausgeben
          goStartRec(aKopf)
          PageOut(aFelder,aKopf)
          goStartRec(aKopf)
          Zeile:=aKopf[EDIT_START_Y]
          taste:=0

          // Ende Tasten
          case Taste == K_ESC .or. taste == EDIT_QUIT .or. ;
            (chr(Taste) $ aKopf[EDIT_ENDE] .and. taste <> K_MWBACKWARD)
            // NOP, handled in �bergeordneter Funktion

            // removed from here, ENTER is handled in handle_key after aKopf[EDIT_EXTRA_FKT]
            // case ( Taste==K_ENTER .or. Taste == K_ALT_DOWN .or. 
            // Taste==K_ALT_RIGHT )
            // Beep()
            // Taste:=0

            otherwise
            Zeile:=handle_key(aFelder,aKopf,Taste,Zeile)
            Taste:=0
          endcase
          M->akt_spalte:=aKopf[EDIT_GET_OFFSET]

        enddo

      enddo

  /* l�sche falls leere einzigster Datensatz */
      if OrdKeyCount()==1
        go top
        if eval(aKopf[EDIT_INDEX_FELD])
      /* l�sche akt. Zeile */
          delete
          pack
        endif
      endif

      readexit(oldReadExit)

  /** was windows resized? => set default size */

      // // schreibe aktuelle Fenster-Groesse & Position
      // if select("Fenster")>0 .and. trim(callerName)<>"BS" .and. restoreWinSize
      // select Fenster

      // tempUser:=getUser():getWindowStorageID()
      // select Fenster
      // FENSTER->(dbseek(left(callerName+space(10),10)+left(tempUser+space(10),10)))
      // if FENSTER->(eof()) // Liste von User zum 1. Mal geöffnet
      // if ! add_rec(5)
      // Error(ACHTUNG+"Fenster-Groesse kann nicht gespeichert werden.",.t.)
      // else
      // replace FENSTER->LISTE_KURZ with callerName
      // replace FENSTER->Kurzel with tempUser
      // endif
      // else
      // rec_lock(5)
      // endif
      // tempsizeX:=hb_gtInfo(HB_GTI_SCREENWIDTH)
      // tempsizeY:=hb_gtInfo(HB_GTI_SCREENHEIGHT)
      // temppos:=hb_gtInfo( HB_GTI_SETPOS_XY )
      // tempFullscreen:=hb_gtInfo( HB_GTI_ISFULLSCREEN)
      // replace FENSTER->PosX with max(temppos[1],0)
      // replace FENSTER->PosY with max(temppos[2],0)
      // replace FENSTER->SizeX with tempsizeX
      // replace FENSTER->SizeY with tempsizeY
      // replace FENSTER->Maximized with if(tempFullscreen,"J","N")
      // dbcommit()
      // dbunlock()
      // endif

      if sizeX<>hb_gtInfo(HB_GTI_SCREENWIDTH) .or. sizeY<>hb_gtInfo(HB_GTI_SCREENHEIGHT);
        .or. fullScreen<>hb_gtInfo(HB_GTI_ISFULLSCREEN)
        // WATCHOUT: the order is significant here, do not change!!!
        hb_gtInfo(HB_GTI_ISFULLSCREEN,fullScreen)
        hb_gtInfo(HB_GTI_SCREENWIDTH,sizeX)
        hb_gtInfo(HB_GTI_SCREENHEIGHT,sizeY)
        hb_gtInfo( HB_GTI_FONTWIDTH ,tempFontWidth)
        hb_gtInfo( HB_GTI_FONTSIZE ,tempFontSize )
        qout(" ") // needed as workaround for bug in setPos
        hb_gtInfo(HB_GTI_SETPOS_XY,{posX,posY})
      endif
      hb_gtInfo( HB_GTI_RESIZEMODE, fontMode )
      // Umgebung(LOAD)

      // Reset �bertrage aus diesem Editor Aufruf
      carry( DISMISS_NEXT )

      RETURN(Taste)






/* Prozedur LineOut(aFelder,aKopf,Zeile,Background-Farbe) *****************************
*
* gibt aktuelle Zeile auf BS aus
* falls Farbe uebergeben, in uebergebener Farbe
*/
FUNCTION LineOut(aFelder,aKopf,Zeile,Farbe)
LOCAL i, Pict,x
LOCAL akt_Pos:=aKopf[EDIT_LM]
LOCAL laenge:=0
LOCAL pos_x:=0
LOCAL pos_y:=0
LOCAL aFeldMerk:={}

  /* l�sche akt. BS-Zeile */
  @ Zeile,aKopf[EDIT_LM] clear to Zeile+aKopf[EDIT_LINES]-1,aKopf[EDIT_RM]

  /* gehe alle Felder durch */
  for i:=1 to len(aFelder)

    /* rel. x-y Verschiebung ? */
    pos_y:=aFelder[i,EDIT_POS_Y]
    pos_x:=aFelder[i,EDIT_POS_X]
    if pos_y > 0 // 2.Zeile oder mehr
      /* suche Orientierung 1. Zeile */
      x:=1
      do while aFelder[i-x,EDIT_POS_Y] <> 0
        x++
      enddo
      pos_x-= (FeldLen(aFelder,i-x)+EDIT_NUM_LEERZEICHEN+aFelder[i-x,EDIT_POS_X])
    endif

    /* Laenge des akt. Feldes aus Picture-anweisung bestimmen */
    laenge:=FeldLen(aFelder,i)

    // if DEVEL_PROG .and. akt_Pos+pos_x+Laenge > aKopf[EDIT_RM] + 1 // ACHTUNG Umbruch
    // Message("ACHTUNG: Variable: "+aFelder[i,EDIT_NAME]+" passt nicht in akt. Zeile.  Taste !","@")
    // endif

    /* Picture-Anweisung */
    pict:=getPict(aFelder[i,EDIT_MASKE])

    /* anzeigen */
    if eval(aFelder[i,EDIT_SHOW])
      if valtype(aFelder[i,EDIT_MASKE])=="C" .and. aFelder[i,EDIT_MASKE]==EDIT_PICT_FARBE
        colorSay(Zeile+pos_y,akt_Pos+pos_x,&(aFelder[i,EDIT_NAME]) )
      else
        SETPOS(Zeile+pos_y,akt_Pos+pos_x) // akt. BS-Posoition
        if valtype(Farbe)=="U" .or. pos_y > 0 .or. aFelder[i,EDIT_NO_HIGHLIGHT]
          devOutPict( &(aFelder[i,EDIT_NAME]) , pict , eval(aFelder[i,EDIT_FARBE]) )
        else
          devOutPict( &(aFelder[i,EDIT_NAME]) , pict , getMyFarbe(eval(aFelder[i,EDIT_FARBE]),;
            Farbe) )
        endif
      endif
    endif

    /* umnschalten alternative Spaltendef. ? */
    if eval(aFelder[i,EDIT_ERSATZ_1])
      aFeldMerk:=aFelder
      aFelder:=eval(aKopf[EDIT_ERSATZ_ARRAY],aclone(aFelder))
      aKopf:=initAKopf(aKopf,aFelder)
    endif
    if eval(aFelder[i,EDIT_ERSATZ_2])
      aFeldMerk:=aFelder
      // aFelder:=aKopf[EDIT_ERSATZ_ARRAY_2]
      aFelder:=eval(aKopf[EDIT_ERSATZ_ARRAY_2],aclone(aFelder))
      aKopf:=initAKopf(aKopf,aFelder)
    endif

    /* aktuelle Pos. neu berechnen */
    // nur falls selbe Zeile
    if i < len(aFelder) .and. aFelder[i,EDIT_POS_Y]==0
      // /* Trennzeichen */
      // for y:=0 to aKopf[EDIT_LINES]-1
      // SETPOS(Zeile+y,akt_Pos+pos_x+Laenge) // akt. BS-Posoition
      // devOut( EDIT_FILL )
      // next y

      /* akt. neue Position */
      akt_Pos+= laenge+EDIT_NUM_LEERZEICHEN+pos_x
    endif

  next i

  /* r�ckschalten alt. Spaltendef. ? */
  if len(aFeldMerk) > 0
    aFelder:=aFeldMerk
  endif

RETURN(.t.)





/* Function FeldLen *************************************
*
* gibt die Laenge eines Feldes, bzw. Picture-Klausel, �berschrift z�r�ck
*/
STATIC FUNCTION FeldLen(aFelder,i)
LOCAL Laenge:=Pars(getPict(aFelder[i,EDIT_MASKE]))
LOCAL tempFeld:=aFelder[i,EDIT_NAME]
LOCAL value

  if Laenge==0

    value:=&(tempFeld)

    do case
    case valtype(value)=="B"
      tempFeld:=eval( tempFeld )
    case valtype(value)=="N"
      laenge:=len(str(value)) // fehlt Fkt. jojo
    case valtype(value)=="D"
      laenge:=8
    otherwise
      laenge:=len(value)
    endcase

  endif
  /* L�nge der �berschrift falls l�nger , bei NICHT-numerischen */
  if laenge < len(aFelder[i,EDIT_TITEL])
    laenge:=len(aFelder[i,EDIT_TITEL])
  endif

RETURN(laenge)


/* Function Pars **********
*
* parst aus einer �bergegeben Picture-Anweisung die absolute L�nge eines Feldes
* falls L�nge nicht def. R�ckgabe:=0
*/
STATIC FUNCTION Pars(Pic)
LOCAL Laenge:=0
  do while "@" $ Pic
    pic:=substr(Pic,at("@",Pic)+2,len(pic))
  enddo
RETURN(len(alltrim(pic)))
/** eof */

/* Function getPict **********
*
* gibt die Picture-Anweisung f�r das akt. Feld zur�ck
*/
STATIC FUNCTION getPict(pict)
LOCAL result
  do case
  case valtype(pict)=="B"
    result:=Eval(pict)
  case empty(pict)
    result:="@K"
  case pict==EDIT_PICT_FARBE
    result:="@X"
  otherwise
    result:=pict
  endcase
return result
/** eod */



/* Function Lineedit ****************************
*
* editieren der aktuellen Zeile
* Parameter: Felder, Zeile,
*            Left_Keys  (Tasten mit denen man sich nach links  bewegt)
*            Right_Keys (Tasten mit denen man sich nach rechts bewegt)
*/
STATIC FUNCTION LineEdit(aFelder,aKopf,Zeile) // wichtig Methode nicht umbenennen
  // LOCAL Taste:=K_ESC
LOCAL i, Pict
LOCAL akt_Pos:=aKopf[EDIT_LM], datei,fieldName,fieldBlock
LOCAL GetList:={}
LOCAL Left_Keys:="" , Right_Keys:="",exitNoConfirm:=.f.
LOCAL aFeldMerk:={},tempVal, aktIndex
LOCAL confirm:=set(_SET_CONFIRM), result:=EDIT_RESULT_UNCHANGED
  _thread static Taste
MEMVAR pZeile
private pZeile:=Zeile

  default Taste:=K_RETURN
  // dirty hack um Zeile in Unterfkt (z.B. ZeileEinfuegen) sichtbar zu machen

  /* Modusspez. Bewegungswerte festlegen */
  if aKopf[EDIT_MODUS]==1
    /* def. Keys zum verlassen eines Feldes innerhalb Lineedit */
    Left_keys:=chr(K_ALT_LEFT)
    Right_Keys:=chr(K_RETURN)+chr(K_ALT_RIGHT)+chr(KEY_SPECIAL)

    // ESC cancels edit but does not undo entered value
    SetKey( K_ESC , {|| HB_KeyPut(EDIT_QUIT) } )

  else // aKopf[EDIT_MODUS]==2
    /* def. Keys zum verlassen eines Feldes innerhalb Lineedit */
    Left_keys:=chr(K_ALT_LEFT)+chr(K_UP)
    Right_Keys:=chr(K_RETURN)+chr(K_ALT_RIGHT)+chr(K_DOWN)+chr(KEY_SPECIAL)
  endif

  // neu seit 26.1.2105: w�hrend des editierens wird der index ausgeschaltet
  if (aktIndex:=indexord()) > 0
    OrdSetFocus(0)
  endif

  readexit(.t.)

  /* gehe alle Felder durch */
  i:=M->akt_spalte
  do while i>0 .and. i <= len(aFelder)

    /* falls nicht auf 1. Feld: berechne akt. Pos */
    akt_pos:=kalkSpaltenPos(aFelder,aKopf,i)

    /* Picture-Anweisung */
    pict:=getPict(aFelder[i,EDIT_MASKE])

    /* Feld editieren ? */
    if ! aFelder[i,EDIT_EDIT]
      if lastkey()==K_PGUP .or. lastkey()==K_UP
        i--
      else
        i++
      endif
      loop
    endif

    /* Message-Ausgabe */
    if valtype(aFelder[i,EDIT_MESSAGE])=="B"
      Message( eval(aFelder[i,EDIT_MESSAGE]) )
    else
      Message(aFelder[i,EDIT_MESSAGE])
    endif

    // fieldblock bestimmen, seit 23.616 auch andere Datei m�glich
    // Satz muss in pre und post function manuell gelockt werden
    fieldName:=aFelder[i,EDIT_NAME] // Name
    if empty(aFelder[i,EDIT_NAME_GET])
      if "->" $ aFelder[i,EDIT_NAME]
        datei:=left(aFelder[i,EDIT_NAME] , at( "->" , aFelder[i,EDIT_NAME] ) -1 )
        fieldName:=substr(aFelder[i,EDIT_NAME] , at( "->" , aFelder[i,EDIT_NAME] ) + 2 )
        fieldBlock:=fieldWblock( fieldName , select(datei) )
      else
        fieldBlock:=fieldblock(aFelder[i,EDIT_NAME])
      endif
    else
      fieldName:=aFelder[i,EDIT_NAME_GET] // Name
      if fieldpos(aFelder[i,EDIT_NAME_GET])==0 // unsch�n, dann nur den Get-Namen �ndern wegen F12
        fieldBlock:=fieldblock(aFelder[i,EDIT_NAME])
      else
        fieldBlock:=fieldblock(aFelder[i,EDIT_NAME_GET])
      endif
    endif

    GetList:={ getnew( Zeile+aFelder[i,EDIT_POS_Y] , ; // Zeile
    akt_Pos, ; // Spalte
    fieldblock, ;
      fieldName,; // Name
    Pict ) } // Picture

    // custom postblock & check duplicates, after edit -> 4 cases
    if valtype(aFelder[i,EDIT_AFTER]) <> "U"
      if valtype(aFelder[i,EDIT_DUPLICATES]) <> "U"
        GetList[1]:postblock:=;
          { |oGet| eval(aFelder[i,EDIT_AFTER],oGet) .and. checkDuplicatesOK(aFelder[i,EDIT_DUPLICATES]) }
      else
        GetList[1]:postblock:=aFelder[i,EDIT_AFTER]
      endif
    else
      if valtype(aFelder[i,EDIT_DUPLICATES]) <> "U"
        GetList[1]:postblock:={ || checkDuplicatesOK(aFelder[i,EDIT_DUPLICATES]) }
      else
        // NOP
      endif
    endif

    if valtype(aFelder[i,EDIT_BEFORE]) <> "U"
      if ! eval(aFelder[i,EDIT_BEFORE],GetList[1])
        GetList:={}
        if lastkey()==K_PGUP .or. lastkey()==K_UP
          i--
        else
          i++
        endif
        loop
      endif
    endif

    // enable copy field?
    if aFelder[i,EDIT_COPY_FIELD]
      set key K_F8 to copy_field("",oGet,"")
    endif

    // read now - with exit on resize events
    ReadModal( GetList, NIL,NIL, INKEY_KEYBOARD + HB_INKEY_GTEVENT)

    if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
      Zeile:=resizeBSAus(aFelder,AKopf,Zeile)
      loop
    endif

    // field/line changed?
    // ACHTUNG: Fehlerquelle hier: getUpdated() liefert M�ll, da nicht gescheit resetted
    if result == EDIT_RESULT_UNCHANGED .and. getUpdated() // s. getsys.prg
      result:=EDIT_RESULT_CHANGED
    endif

    if ! set(_SET_CONFIRM) .and. len(GetList)>0 .and. getCargo(GetList[1],CARGO_TYPEOUT)
      exitNoConfirm:=.t.
    else
      exitNoConfirm:=.f.
    endif
    GetList:={} ; ( GetList )

    // new 20120316, we now recover the previous confirm state
    // needed here, since the EDIT_AFTER clause is no invoked on ESC
    set(_SET_CONFIRM,confirm)

    // disable copy field?
    if aFelder[i,EDIT_COPY_FIELD]
      set key K_F8 to
    endif

    /* Ausgabe der akt. Zeile ? */
    if aFelder[i,EDIT_AUSGABE] .or. i==M->IndexFeld
      dbskip(0) // wg. evtl. Relationen
      LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus
    else
      /* Ausgbabe des eben editierten Get-Feldes */
      if valtype(aFelder[i,EDIT_MASKE])=="C" .and. aFelder[i,EDIT_MASKE]==EDIT_PICT_FARBE
        colorSay(Zeile+aFelder[i,EDIT_POS_Y],akt_Pos,&(aFelder[i,EDIT_NAME]) )
      else
        SETPOS(Zeile+aFelder[i,EDIT_POS_Y],akt_Pos) // akt. BS-Posoition
        devOutPict( &(aFelder[i,EDIT_NAME]) , pict )
      endif
    endif

    /* Ausgabe des ganzen BS */
    if aFelder[i,EDIT_BS_AUSGABE]
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    endif

    if exitNoConfirm
      Taste:=K_RETURN // neu 20120423, evtl. falsch da lastkey() "verloren" geht
    else
      Taste:=lastkey()
    endif

    do case

      // vorw�rts
    case chr(Taste) $ Right_Keys .or. exitNoConfirm

      /* umschalten alternative Spaltendef. ? */
      if eval(aFelder[i,EDIT_ERSATZ_1])
        aFeldMerk:=aFelder
        aFelder:=eval(aKopf[EDIT_ERSATZ_ARRAY],aclone(aFelder))
        aKopf:=initAKopf(aKopf,aFelder)
      endif
      if eval(aFelder[i,EDIT_ERSATZ_2])
        aFeldMerk:=aFelder
        aFelder:=eval(aKopf[EDIT_ERSATZ_ARRAY_2],aclone(aFelder))
        aKopf:=initAKopf(aKopf,aFelder)
      endif

      i++ // n�chstes Feld

      /* letztes Feld nach rechst �berschritten */
      if i > len(aFelder)
        M->Akt_Spalte:=1
      endif

      // zur�ck
    case chr(Taste) $ Left_Keys
      if i > 1

        i -- // gehe auf vorergehenden

	/* umschalten auf standard Array */
        if i==1 .and. aFeldMerk <> NIL .and. len(aFeldMerk) > 0
          aFelder:=aFeldMerk
        endif

      else
        if aKopf[EDIT_MODUS]==1
          i:=len(aFelder)+1 // raus aus akt. Zeile
        endif
      endif

    otherwise
      M->akt_spalte:=i // merke aktuelle Spalte
      readexit(.f.)
      // Funktion die nach jeder �nderung ausgef�hrt werden soll aufrufen
      if aKopf[EDIT_AFTER_EDIT_FKT]<>NIL
        // merke start spalte vorher
        tempVal:=aKopf[EDIT_GET_OFFSET]
        if ! eval(aKopf[EDIT_AFTER_EDIT_FKT] , result)
          // Eingabe wiederholen, falls after_edit nicht erf�llt
          // setzte aktuelle spalte und stelle alte Start-Spalte wieder her
          if tempVal<>aKopf[EDIT_GET_OFFSET]
            i:=aKopf[EDIT_GET_OFFSET]
            // akt_pos:=kalkSpaltenPos(aFelder,aKopf,i)
            aKopf[EDIT_GET_OFFSET]:=tempVal
          endif
          loop
        endif
        LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus

      endif

      /* Zeige Spaltensumme, if applicable */
      zeigeSumme(aFelder,aKopf)

      if aKopf[EDIT_MODUS]==1
        Set Key K_ESC to
      endif

      /* r�ckschalten index */
      if aktIndex > 0
        OrdSetFocus(aktIndex)
      endif

      RETURN(Taste)
    endcase

  enddo

  /* r�ckschalten index */
  if aktIndex > 0
    OrdSetFocus(aktIndex)
  endif

  /* r�ckschalten alt. Spaltendef. ? */
  if len(aFeldMerk) > 0
    aFelder:=aFeldMerk
  endif

  // Funktion die nach jeder �nderung ausgef�hrt werden soll aufrufen
  if aKopf[EDIT_AFTER_EDIT_FKT]<>NIL
    eval(aKopf[EDIT_AFTER_EDIT_FKT],result)
    LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus
  endif

  /* Zeige Spaltensumme, if applicable */
  zeigeSumme(aFelder,aKopf)

  if aKopf[EDIT_MODUS]==1
    Set Key K_ESC to
  endif

RETURN(Taste)


/** berechnet die aktuelle SpaltenPosition (col()) f�r das aktuelle Get-Feld */
static function kalkSpaltenPos(aFelder,aKopf,posNumber)
LOCAL i,laenge
LOCAL shiftX:=aFelder[posNumber,EDIT_POS_X]
LOCAL akt_pos:=aKopf[EDIT_LM]

  // suche vorheriges Feld in 1. Zeile
  do while aFelder[posNumber,EDIT_POS_Y]>0 .and. posNumber>0
    posNumber--
  enddo

  // jetzt die Positeion des letzten Feldes der 1. Zeile berechnen
  for i:=1 to posNumber-1

    /* aktuelle Pos. neu berechnen */
    // nur falls 1. Zeile
    if i < len(aFelder) .and. aFelder[i,EDIT_POS_Y]==0
      /* Laenge des akt. Feldes aus Picture-anweisung bestimmen */
      laenge:=FeldLen(aFelder,i)
      akt_Pos+= laenge + EDIT_NUM_LEERZEICHEN + aFelder[i,EDIT_POS_X]
    endif

  next i
return akt_pos+shiftX
/** eof */

/* PROCEDURE Titel_Edit *****************************
*
* schreibt die �berschriften in Zeile: Zeile
* �berschrift nur 1-zeilig !
*/
STATIC PROCEDURE Titel_Edit(aFelder,Zeile,aKopf)
LOCAL akt_pos:=aKopf[EDIT_LM]
LOCAL i:=1
LOCAL pos_x,pos_y,left

  @ aKopf[EDIT_START_Y]-3,aKopf[EDIT_LM] clear to M->unt_Rand,aKopf[EDIT_RM]
  @ aKopf[EDIT_START_Y]-3,aKopf[EDIT_LM] to aKopf[EDIT_START_Y]-3,aKopf[EDIT_RM]
  @ aKopf[EDIT_START_Y]-1,aKopf[EDIT_LM] to aKopf[EDIT_START_Y]-1,aKopf[EDIT_RM]

  // �berschrift nur 1-zeilig !
  do while akt_pos <= aKopf[EDIT_RM] .and. i <= len(aFelder)
    pos_y:=aFelder[i,EDIT_POS_Y]
    if pos_y == 0 // Titel nur 1. Zeile
      pos_x:=aFelder[i,EDIT_POS_X]

      if valtype(&(aFelder[i,EDIT_NAME]))=="N" // numerische Titel rechtsb�ndig
        left:=Feldlen(aFelder,i) - len(aFelder[i,EDIT_TITEL])
      else
        left:=0
      endif
      SETPOS(Zeile,akt_Pos+pos_x+left) // akt. BS-Posoition
      devOut( aFelder[i,EDIT_TITEL] )

      akt_pos+=FeldLen(aFelder,i) + EDIT_NUM_LEERZEICHEN + pos_x
    endif
    i++
  enddo

RETURN


/* Procedure Handle_Key
*
* handelt die Tasten-Eingabe w�hrend und beim Verlassen von Lineedit
*
* R�ckgabe: akt. Zeile
*/
FUNCTION Handle_Key(aFelder,aKopf,Taste,Zeile)
LOCAL anz_BS:=int( (M->unt_Rand-aKopf[EDIT_START_Y])/aKopf[EDIT_LINES] + 1 )
LOCAL ok_skip:=0 , Anzeige, Erfolg,result, tempVal
LOCAL merk_Satz:=OrdKeyNo(),i // l�schen
LOCAL s01,GetList:={},merk_farbe // suchen
LOCAL excel,objErr, bLastHandler
LOCAL aTemp1 , aTemp2

  _thread static suchText

  /* gew�nschte Fkt. erlaubt ? */
  // if upper(chr(Taste)) $ getGesperrtKeys(aKopf)
  // Beep()
  // RETURN(Zeile)
  // endif

  do case

  CASE taste == HB_K_GOTFOCUS
    // nop
  CASE taste == HB_K_LOSTFOCUS
    // nop
  CASE taste == HB_K_CLOSE
    // NOP? FIXME
    // RETURN(Zeile) ???

  CASE taste == HB_K_RESIZE
    Zeile:=resizeBSAus(aFelder,AKopf,Zeile)

    /* andere Spezial-Fkt ausf�hren, seit 20.3.2012 ganz oben, damit
    * RETURN und andere Taste �berschrieben werden k�nnen
    * Ausnahme: Maus-Wheel kann nicht �berschrieben werden, da F10 wie WHEEL_DOWN gehandelt wird */

  case (i:=ascan( aKopf[EDIT_EXTRA_FKT] , { |aArr| chr(Taste)$aArr[1] .or. upper(chr(Taste))$aArr[1] } ))>0 ;
    .and. taste <> K_MWBACKWARD // F10 vs. Mouse-Wheel-Down
    // aKopf[EDIT_CHANGED]:=.t. // maybe not necessary, but like this we are save, removed 20201007
    result:=eval(aKopf[EDIT_EXTRA_FKT, i, EDIT_EXTRA_BLOCK])

    if OrdKeyCount()==0
      add_rec(0)
      carry(LOAD,aFelder) // hole �betr�ge
      if valtype(aKopf[EDIT_NEW_FKT])=="B"
        eval( aKopf[EDIT_NEW_FKT] )
      endif
      go Bottom
      Zeile-=aKopf[EDIT_LINES]
      ZeigeAnzahl(aKopf)
      keyboard chr(K_HOME)
    endif

    if valtype(result)=="N"
      zeile:=result
    endif

  case Taste == K_PGUP // BS rauf
    ok_skip:=my_skip(-anz_BS)
    if abs(ok_skip)<>anz_BS // bof()
      PageOut(aFelder,aKopf)
      Zeile:=aKopf[EDIT_START_Y] // Zeiger auf erste Zeile
    else
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    endif
    M->akt_spalte:=1 // gehe auf 1. Spalte

  case Taste == K_PGDN // BS runter
    ok_skip:=my_skip(+anz_BS)
    M->akt_spalte:=1 // gehe auf 1. Spalte
    if abs(ok_skip)<>anz_BS // eof()
      my_skip(-ok_skip)
      PageOut(aFelder,aKopf)
      /* gehe auf letzten Satz auf BS */
      Zeile:=aKopf[EDIT_START_Y]+( my_skip(+ok_skip) * aKopf[EDIT_LINES] )
    else
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    endif

    /* Modus 1+2 , Zeile runter */
  case Taste == K_DOWN .or. Taste==MY_K_ENTER .or. Taste == K_ALT_DOWN .or. ;
    Taste==K_ALT_RIGHT .or. Taste == K_MWBACKWARD


    carry(WRITE,aFelder) // merke Feldinhalt
    // 1 Zeile runter
    if my_skip(1)<=0 // eof()

      if Taste==K_DOWN .or. Taste == K_MWBACKWARD .or. "@"$getGesperrtKeys(aKopf)
        Beep()
        Zeile-=aKopf[EDIT_LINES] // bleibe auf selber Zeile
      else
        /* automat. Anf�gen eines neuen Satzes */
        if ! add_rec(0)
          error(alias()+DATEI_EXCL)
          Zeile-=aKopf[EDIT_LINES] // bleibe auf selber Zeile
        else
          M->akt_Spalte:=1
          /* Fkt. f�r neuen Datensatz */
          carry(LOAD,aFelder) // hole �betr�ge
          if valtype(aKopf[EDIT_NEW_FKT])=="B"
            eval( aKopf[EDIT_NEW_FKT] )
          endif
          ZeigeAnzahl(aKopf)
        endif
      endif
    elseif Taste==MY_K_ENTER
      M->akt_Spalte:=1
    endif
    Zeile+=aKopf[EDIT_LINES] // n�chste Zeile

  case Taste == K_UP .or. Taste == K_ALT_UP .or. Taste == K_MWFORWARD // 1 Zeile rauf
    Zeile+=( my_skip(-1) * aKopf[EDIT_LINES] ) // gehe eine Zeile h�her

  case Taste == K_ALT_LEFT .or. Taste==K_LEFT
    Zeile+=( my_skip(-1) * aKopf[EDIT_LINES] ) // gehe eine Zeile h�her
    M->akt_Spalte:=len(aFelder) // gehe auf letzte Spalte

  case ( chr(Taste) $ "Ll" .or. Taste=EDIT_DELETE ) .and. ! upper(chr(Taste)) $ getGesperrtKeys(aKopf)

    // l�schen
    if ! fil_lock(5)
      error(alias()+DATEI_EXCL)
    else
      tempVal:=eval(aKopf[EDIT_INDEX_FELD])
      if aKopf[EDIT_CONFIRM_LOESCHE] .and. ! tempVal;
        .and. Message("Zeile wirklich l�schen ? (@J@/@N@)","JN","N")<>"J"
        return(Zeile)
      endif

      if ! tempVal
        aKopf[EDIT_CHANGED]:=.t.
      endif

      if aKopf[EDIT_DELETE_FKT] == NIL
        delete
      else
        eval(aKopf[EDIT_DELETE_FKT])
      endif
      pack
      OrdKeyGoTo(Merk_Satz)
      if eof() // letzter Satz gel�scht
        if OrdKeyCount()==0
          add_rec(0)
          carry(LOAD,aFelder) // hole �bertr�ge
          if valtype(aKopf[EDIT_NEW_FKT])=="B"
            eval( aKopf[EDIT_NEW_FKT] )
          endif
          Zeile:=aKopf[EDIT_START_Y]
        else
          go Bottom
          if Zeile > aKopf[EDIT_START_Y]
            Zeile-=aKopf[EDIT_LINES]
          endif
        endif
      endif
      /* bleibe auf akt. BS-Pos. */
      // Zeile:=aKopf[EDIT_START_Y] + my_skip( -(Zeile-aKopf[EDIT_START_Y]) )

      // Funktion die nach jeder �nderung ausgef�hrt werden soll aufrufen
      if aKopf[EDIT_AFTER_EDIT_FKT]<>NIL .and. ! tempVal
        eval(aKopf[EDIT_AFTER_EDIT_FKT],EDIT_RESULT_DELETED)
        LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus
      endif

      /* Zeige Spaltensumme, if applicable */
      zeigeSumme(aFelder,aKopf)

      if ! tempVal
        checkModeChangeFunction(aKopf)
      endif

      // Ausgabe aktualisieren
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
      ZeigeAnzahl(aKopf)

    endif

  case (Taste == K_F7 .or. Taste == K_F8) .and. ! upper(chr(Taste)) $ getGesperrtKeys(aKopf)
    // suchen
    if suchText==NIL
      suchText:=space(20)
    endif
    Message("Such-Text eingeben.      @F8@=weitersuchen      @ESC@=Ende")
    if Taste == K_F7
      s01:=savescreen()
      merk_Farbe:=setcolor(COLWIN)
      Fenster(10,22,12,58)
      @ 11,24 say "Such-Text:" get suchText picture "@K";
        valid {|oGet| suchePosten(oGet:buffer,aFelder)}
      read
      setcolor(merk_Farbe)
      restscreen(,,,,s01)
    else
      cont // suche n�chsten
      if eof()
        beep()
        Error(trim(suchtext)+" nicht gefunden.",.t.)
        OrdKeyGoTo(Merk_Satz)
      endif
    endif

    if ! ABBRUCH
      // alle Posten neu ausgeben
      Zeile:=PageOut(aFelder,aKopf)
    endif


  case ( chr(Taste) $ "eE" .or. Taste=EDIT_INSERT ) .and. ;
    ! upper(chr(Taste)) $ getGesperrtKeys(aKopf) .and. indexOrd()==0
    // einf�gen, falls mit Index geht nur N->anf�gen

    carry(WRITE,aFelder) // merke Feldinhalt
    aKopf[EDIT_CHANGED]:=.t.
    insertBlank()

    carry(LOAD,aFelder) // hole Feldinhalte
    if valtype(aKopf[EDIT_NEW_FKT])=="B"
      eval( aKopf[EDIT_NEW_FKT] )
    endif
    ZeigeAnzahl(aKopf)

    Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    if aKopf[EDIT_MODUS]==2 // im Doppel-Modus: �ndern
      // Zeile:=handle_key(aFelder,aKopf,asc("�"),Zeile)
      Taste:=LineEdit(aFelder,aKopf,Zeile)
      checkModeChangeFunction(aKopf)
    endif

    /* l�sche akt. Zeile, wenn leer bzw. Bedingung erf�llt */
    if eval(aKopf[EDIT_INDEX_FELD])
      Zeile:=handle_key(aFelder,aKopf,EDIT_DELETE,Zeile)
    endif


    /* ESC nur in Modus 2 m�glich */
  case Taste == K_ESC
    RETURN(Zeile)

    /* gehe ans Ende */
  case Taste==K_END
    // Anzeige:=MIN(int(M->unt_rand-aKopf[EDIT_START_Y]+1/aKopf[EDIT_LINES]),reccount())
    Anzeige:=MIN((M->unt_Rand-aKopf[EDIT_START_Y])/aKopf[EDIT_LINES] + 1 ,OrdKeyCount())

    go bottom
    Erfolg:=abs(my_Skip(-Anzeige+1))

    /* gebe aktuelle Seite aus */
    PageOut(aFelder,aKopf)

    /* gehe auf letzten Datensatz */
    go bottom
    Zeile:=aKopf[EDIT_START_Y]+Erfolg*aKopf[EDIT_LINES]

    /* gehe an den Anfang  */
  case Taste==K_HOME
    go top
    /* gebe aktuelle Seite aus */
    PageOut(aFelder,aKopf)
    go top
    Zeile:=aKopf[EDIT_START_Y]

    /* zur�ck zur Kopf-Fkt ausf�hren */
  case chr(Taste) $"Zz" .and. ! upper(chr(Taste)) $ getGesperrtKeys(aKopf)
    if valtype(aKopf[EDIT_KOPF_FKT])=="B"
      Umgebung(WRITE)

      clearDispLines(aKopf)

      eval(aKopf[EDIT_KOPF_FKT])
      Umgebung(LOAD)
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.

      // Reset �bertrage aus letztem Editor Aufruf
      carry( DISMISS_NEXT )

      // Funktion die nach jeder �nderung ausgef�hrt werden soll aufrufen
      if aKopf[EDIT_AFTER_EDIT_FKT]<>NIL
        eval(aKopf[EDIT_AFTER_EDIT_FKT] , EDIT_RESULT_HEAD)
        LineOut(aFelder,aKopf,Zeile) // gebe akt. Zeile aus
      endif

      /* Zeige Spaltensumme, if applicable */
      zeigeSumme(aFelder,aKopf)

    endif

    // move rows up and down CTRL-UP CTRL-Down
  case (Taste == K_CTRL_DOWN .and. ! "�" $ getGesperrtKeys(aKopf)) .or. taste == EDIT_CTRL_DOWN
    aTemp1:=getCurrentValues()
    dbskip( 1 )
    if eof()
      Tone(100)
      go bottom
    else
      aTemp2:=getCurrentValues()
      setCurrentValues( aTemp1 )
      dbskip( -1 )
      setCurrentValues( aTemp2 )
      dbskip( 1 )
      Zeile+=aKopf[EDIT_LINES] // n�chste Zeile
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
      aKopf[EDIT_CHANGED]:=.t.
    endif

  case (Taste == K_CTRL_UP .and. ! "�" $ getGesperrtKeys(aKopf)) .or. taste == EDIT_CTRL_UP
    aTemp1:=getCurrentValues()
    dbskip( -1 )
    if bof()
      Tone(100)
      go top
    else
      aTemp2:=getCurrentValues()
      setCurrentValues( aTemp1 )
      dbskip( 1 )
      setCurrentValues( aTemp2 )
      dbskip( -1 )
      Zeile-=aKopf[EDIT_LINES] // vorherige Zeile
      Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
      aKopf[EDIT_CHANGED]:=.t.
    endif


    /* Ende ? */
  case Taste == K_ESC .or. taste == EDIT_QUIT
    /* NOP */

  case taste == EDIT_BS_REFRESH
    //PageOut(aFelder,aKopf)
    Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    ZeigeAnzahl(aKopf)

  case taste == EXCEL_TASTE
    if getUser():mayEditData
      BEGIN SEQUENCE // krit. Bereich
        excel:=ExcelExport():new()
        excel:addColumnsByName(getFieldArray(aFelder))
        excel:export()
        excel:=NIL
      RECOVER USING objErr
        Error(getErrorDispText(objErr))
      END SEQUENCE
    endif

  case (taste == EDIT_ASCII_EXPORT .and. (DEVEL_PROG .or. TEST_PROG) )
    // hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_ALT ) )
    exportAscii()

    // checks and launches setkeys, e.g. launch new programm for displaying Artikel, Kunden
    // case HB_SetKeyCheck(taste,procname(),nil,nil)
  case HB_SetKeyGet(taste) <> NIL .and. taste<>INFO_TASTE // setkey gesetzt??
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
    BEGIN SEQUENCE
      HB_SetKeyCheck(taste,procName(),NIL,NIL)
    RECOVER USING objErr
      email(MY_EMAIL,"ERROR: SetKey:"+str(taste)+" failed in Edit.",getErrorText(objErr))
    END SEQUENCE
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)


  otherwise
    Tone(100)
  endcase

  /* Scrolle falls ausserhalb vom BS */
  if Zeile+aKopf[EDIT_LINES]-1 > M->unt_Rand
    scroll(aKopf[EDIT_START_Y],aKopf[EDIT_LM],M->unt_Rand,aKopf[EDIT_RM],aKopf[EDIT_LINES])
    Zeile:=M->unt_Rand-aKopf[EDIT_LINES]+1
    LineOut(aFelder,aKopf,Zeile)
  else
    if Zeile < aKopf[EDIT_START_Y]
      scroll(aKopf[EDIT_START_Y],aKopf[EDIT_LM],M->unt_Rand,aKopf[EDIT_RM],aKopf[EDIT_LINES]*(-1))
      Zeile:=aKopf[EDIT_START_Y]
      LineOut(aFelder,aKopf,Zeile)
    endif
  endif

RETURN(Zeile)
/** eof */

/** l�scht alle Eingabe Zeilen am BS */
procedure clearDispLines(aKopf)
LOCAL extension:=0

  if aKopf[EDIT_DRAW_FRAME]==NIL
    extension:=2
  endif

  do case
  case aKopf[EDIT_CLS_EXTRA_ROWS]==0
    @ aKopf[EDIT_START_Y]-3,aKopf[EDIT_LM]-extension clear to M->unt_Rand,aKopf[EDIT_RM]+extension
  case aKopf[EDIT_CLS_EXTRA_ROWS]<0
    @ aKopf[EDIT_START_Y]-3,aKopf[EDIT_LM]-extension clear to maxRow(),aKopf[EDIT_RM]+extension
  otherwise
    @ aKopf[EDIT_START_Y]-3,aKopf[EDIT_LM]-extension clear to M->unt_Rand,aKopf[EDIT_RM]+extension
  endcase

return
/** eop */

/** sucht Freitext in allen Posten */
static function suchePosten(text,aFelder)
LOCAL i,suchFelder:="",aktRec:=recno()

  if ! ABBRUCH
    Message("@"+trim(text)+"@ wird gesucht.    Bitte warten...")

    /* gehe alle Felder durch */
    for i:=1 to len(aFelder)
      if ! empty(suchFelder)
        suchFelder:=suchFelder+".or."
      endif
      suchFelder += "'"+lower(trim(text))+"'$lower(toString("+aFelder[i,EDIT_NAME]+"))"
    next
    if ! empty(suchFelder)
      loca for &(suchFelder)
    endif
    if eof()
      beep()
      Error(trim(text)+" nicht gefunden.",.t.)
      go(aktRec)
    endif
  endif

return .t.
/** eof */



/* Function my_skip
*
* bl�ttert in akt. Datei
*
* Parameter: Anzahl zu skippende Datens�tze (num.)
*
* R�ckgabe : erfolgreiche Anzahl geskippter S�tze
*/
STATIC FUNCTION my_skip(n)
LOCAL count:=0
  if n==0 .or. OrdKeyCount()==0
    /* NOP */
    RETURN(0)
  endif
  if n > 0
    do while count < n .and. ! eof()
      skip
      count++
    enddo
  else
    do while abs(count) < abs(n) .and. ! bof()
      skip -1
      count--
    enddo
  endif
  if eof()
    dbgobottom()
    if count > 0 // added 25.1.2013
      count --
    endif
  else
    if bof()
      dbgotop()
      count ++
    endif
  endif

RETURN(count)


/* Function BS_aus
*
* gibt den BS neu aus, bleibt aber auf selbem Datensatz
* d.h. Zeile bleibt auch gleich !
*/
FUNCTION BS_Aus(aFelder,aKopf,Zeile)
  // LOCAL diff:=int( (Zeile-aKopf[EDIT_START_Y]-aKopf[EDIT_LINES]+1) / aKopf[EDIT_LINES] )
LOCAL diff:=int( (Zeile-aKopf[EDIT_START_Y]) / aKopf[EDIT_LINES] )
  /* gehe um Anfangs-Pos zur�ck */
  my_skip(-diff)
  PageOut(aFelder,aKopf)
  /* zur�ck auf urspr. Satz */
  Zeile:=aKopf[EDIT_START_Y]+ ( my_skip(+diff) * aKopf[EDIT_LINES] )
RETURN(Zeile)


/* Function PageOut() ***********************************
*
* gibt aktuelle Seite, ab der aktuellen Position in Datei
* steht danach wieder auf 1. Satz auf BS
*
* R�ckgabe: letzte Zeile auf akt. BS
*/
// STATIC PROCEDURE PageOut(aFelder,aKopf)
FUNCTION PageOut(aFelder,aKopf)
LOCAL Zeile:=aKopf[EDIT_START_Y]
LOCAL akt_Pos:=recno()
LOCAL nSkip:=1 // gegl�ckte Skip-Anzahl

  /* gebe einzelene Zeilen aus */
  do while ! eof() .and. Zeile <= M->unt_Rand-aKopf[EDIT_LINES]+1 .and. nskip<>0
    LineOut(aFelder,aKopf,Zeile)
    Zeile+= ( nskip:=my_skip(1) ) * (aKopf[EDIT_LINES])
  enddo

  /* Rest-BS l�schen */
  @ Zeile+aKopf[EDIT_LINES],aKopf[EDIT_LM] clear to M->unt_Rand,aKopf[EDIT_RM]

  /* Zeige Spaltensumme, if applicable */
  zeigeSumme(aFelder,aKopf)

  /* zur�ck auf ersten Datensatz auf BS */
  go akt_Pos

RETURN aKopf[EDIT_START_Y] // Zeiger auf erste Zeile
  /** eof */

STATIC FUNCTION sumRequested(aFelder)
LOCAL i

  /* gehe alle Felder durch */
  for i:=1 to len(aFelder)
    /* Summe gew�nscht? */
    if aFelder[i,EDIT_SUMME] <> NIL
      return .t.
    endif
  next

return .f.
/** eof */

/** Zeige Spaltensumme, if applicable */
STATIC PROCEDURE zeigeSumme(aFelder,aKopf)
LOCAL summe:=hb_hash()
LOCAL aktRec, i, feld
LOCAL val, pos_x, pict, laenge
LOCAL akt_pos:=aKopf[EDIT_LM]

  /* gehe alle Felder durch */
  for i:=1 to len(aFelder)
    /* Summe gew�nscht? */
    if aFelder[i,EDIT_SUMME] <> NIL
      summe[i]:=0
    endif
  next

  if len(summe:keys) > 0
    aktRec:=recno()

    @ M->unt_Rand + 1,aKopf[EDIT_LM] clear to M->unt_Rand + 2,aKopf[EDIT_RM]
    @ M->unt_Rand + 1,aKopf[EDIT_LM] to M->unt_Rand + 1,aKopf[EDIT_RM]
    @ M->unt_Rand + 2,aKopf[EDIT_LM] say "Summe:"

    /* gehe um Anfangs-Pos zur�ck */
    go top

    /* summiere einzelene Zeilen */
    do while ! eof()
      for each feld in summe:keys
        val:=&(aFelder[feld, EDIT_NAME])
        summe[feld] += toNumValue(val)
      next
      skip
    enddo

    /* zur�ck auf urspr. Satz */
    go (aktRec)

    /* Ausgabe auf BS */
    /* gehe alle Felder durch */
    for i:=1 to len(aFelder)

      /* rel. x Verschiebung ? */
      pos_x:=aFelder[i,EDIT_POS_X]

      /* Laenge des akt. Feldes aus Picture-anweisung bestimmen */
      laenge:=FeldLen(aFelder,i)

      /* anzeigen */
      if hb_HHasKey(summe, i)
        pict:=getPict(aFelder[i,EDIT_MASKE])
        SETPOS(M->unt_Rand + 2, akt_Pos + pos_x) // akt. BS-Posoition
        devOutPict(summe[i], pict)
      endif

      /* aktuelle Pos. neu berechnen */
      // nur falls selbe Zeile
      if i < len(aFelder) .and. aFelder[i,EDIT_POS_Y]==0
        akt_Pos+= laenge+EDIT_NUM_LEERZEICHEN+pos_x
      endif

    next i
  endif

return
/** eop */


/** Gibt den BS nach einem Resize event aus */
function resizeBSAus(aFelder,AKopf,Zeile)
LOCAL s01
  _thread static rows,cols

  // nop when window resize does not change row count
  if hb_gtInfo( HB_GTI_RESIZEMODE ) == HB_GTI_RESIZEMODE_FONT
    return Zeile
  endif

  if aFelder==NIL // 1st time init only
    rows:=MaxRow()
    cols:=maxCol()
  else

    // raus am 14.1.2013
    // @ rows,0 clear // Message l�schen
    // s01:=savescreen(0,0,rows,cols)

    // berechne neues Eingabe-Fenster
    aKopf[EDIT_RM]:=maxcol()
    kalkUntRand(aKopf)

    // Hinweis: cols ist hier immer die letzte Gr��e vor der �nderung
    s01:=savescreen(0,0,aKopf[EDIT_START_Y]-2,cols)
    cls

    // Ausgabe auf BS
    restscreen(0,0,aKopf[EDIT_START_Y]-2,cols,s01)
    // raus am 14.1.2013
    // restscreen(0,0,rows,cols,s01)
    Titel() // Programm - nochmal ausgeben
    Titel_Edit(aFelder,aKopf[EDIT_START_Y]-2,aKopf) // Editor - nochmal ausgeben

    /* gebe aktuelle Seite aus */
    Zeile:=BS_aus(aFelder,AKopf,Zeile) // BS-Ausgabe, selbe Pos.
    ZeigeAnzahl(aKopf)

    // remember current size for next resize event
    rows:=MaxRow()
    cols:=maxCol()
  endif

return zeile
/** eof */




/* Procedure Carry
*
* regelt carry on / off Feldweise
* Default:=off
*
  * Remember values in a stack (array)
*/
STATIC PROCEDURE carry(Status,aFelder)
LOCAL i, aValues, bLastHandler,objErr
  _thread static aMerk:={}

  do case
    /* schreiben */
  case Status==WRITE
    aValues:={} // initialisieren
    for i:=1 to len(aFelder)
      if valtype(&(aFelder[i,EDIT_NAME])) <> "B"
        aadd( aValues,&(aFelder[i,EDIT_NAME]) )
      endif
    next i
    aadd( aMerk, aValues)

  /* lesen */
  case Status==LOAD .and. len(aMerk) > 0
    aValues:=aTail(aMerk)
    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
    BEGIN SEQUENCE // krit. Bereich
      for i:=1 to len(aFelder)
        if aFelder[i,EDIT_UEBERTRAG] .and. valtype(&(aFelder[i,EDIT_NAME])) <> "B"
          replace &(aFelder[i,EDIT_NAME]) with aValues[i]
        endif
      next
    RECOVER USING objErr
      email(MY_EMAIL,"ERROR: Carry in edit.prg (abgefangen)",getErrorText(objErr))
      //altd()
    END SEQUENCE
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  /* pop */
  case Status==DISMISS_NEXT .and. len(aMerk) > 0
    if len(aMerk) > 0
      aDel(aMerk , aTail(aMerk))
    endif

  case Status==DISMISS_ALL
    aMerk:={} // initialisieren

  endcase

RETURN
/* EOP Carry */




/* Function E_Fill  *********************************************
*
*  f�llt eine Spaltendefinition f�r den Editor mit DefaultWerten
*/
FUNCTION E_Fill
LOCAL aSpalte[EDIT_FELD_MAX]
  aFill(aSpalte,NIL) // initialisieren

  aSpalte[EDIT_NAME_GET ]:="" // C: Alternativ-Name f�r Get-Objekt
  aSpalte[EDIT_TITEL ]:="" // C:
  aSpalte[EDIT_POS_X ]:=0 // N: rel. zur berechneten Pos.
  aSpalte[EDIT_POS_Y ]:=0 // N: rel. zur akt. Zeile
  // C: Picture-KLausel
  aSpalte[EDIT_MASKE ]:=""
  aSpalte[EDIT_EDIT ]:=.t. // L: editierbar: true
  // aSpalte[EDIT_BEFORE ]:=// B: Fkt. davor
  // aSpalte[EDIT_AFTER ]:=// B: Fkt. danach als CodeBlock !
  aSpalte[EDIT_MESSAGE ]:=""
  aSpalte[EDIT_UEBERTRAG]:=.f. // L: carry, default:=off
  aSpalte[EDIT_AUSGABE ]:=.f. // L: .t. komplette Zeile wird nach EIngabe ausgegeben
  aSpalte[EDIT_BS_AUSGABE ]:=.f. // L: .t. kompletter BS wird nach EIngabe ausgegeben
  aSpalte[EDIT_ERSATZ_1 ]:={ || .f. } // B: falls erf�llt Ersatz-Spaltendef.
  aSpalte[EDIT_ERSATZ_2 ]:={ || .f. } // B: falls erf�llt Ersatz-Spaltendef.
  aSpalte[EDIT_FARBE]:={ || NIL } // B: Farbe
  aSpalte[EDIT_COPY_FIELD]:=.f. // kopiere Feld aus vorherigere Zeile
  aSpalte[EDIT_NO_HIGHLIGHT]:=.f. // Feld wird gehighlighted wenn Zeile selektiert
  aSpalte[EDIT_SHOW]:={ || .t. } // B: default wir zeigen jede Spalte an
RETURN( aSpalte )
/* EOF E_Fill */

/** initilisiere Kopf-Daten */
Function initAKopf(aKopf,aFelder)
  default aKopf[EDIT_INDEX_FELD]:=1
  if valtype(aKopf[EDIT_INDEX_FELD])=="N"
    M->IndexFeld:=aKopf[EDIT_INDEX_FELD]
    aKopf[EDIT_INDEX_FELD]:={ || empty( &(aFelder[M->IndexFeld,EDIT_NAME]) ) }
  endif
  default aKopf[EDIT_GESPERRT]:=""
  default aKopf[EDIT_ENDE]:=""
  default aKopf[EDIT_EXTRA_FKT]:={}
  // default aKopf[EDIT_ERSATZ_ARRAY]:={ || .t.}
  // default aKopf[EDIT_ERSATZ_ARRAY_2]:={ || .t.}
  default aKopf[EDIT_FKT_IMMER]:={ || .t. }
  default aKopf[EDIT_AFTER_EDIT_FKT]:=NIL
  default aKopf[EDIT_BEFORE_EDIT_FKT]:=NIL
  default aKopf[EDIT_BEFORE_ZEILE]:=NIL
  default aKopf[EDIT_CHANGED]:=.f.
  default aKopf[EDIT_GET_OFFSET]:=1
  default aKopf[EDIT_LINES]:=1
  default aKopf[EDIT_CONFIRM_LOESCHE]:=.f.
  default aKopf[EDIT_START_REC]:=NIL
  // default aKopf[EDIT_DRAW_FRAME]:=.f.
  default aKopf[EDIT_ZEIGE_ANZAHL]:=NIL // default: keine Anzeige der Anzahl

  // resize stuff
  default aKopf[EDIT_RM]:=maxcol()
  default aKopf[EDIT_LM]:=0
  default aKopf[EDIT_ENDE_Y]:=-1
  default aKopf[EDIT_CLS_EXTRA_ROWS]:=0
  kalkUntRand(aKopf)
return aKopf


/** kopiert akt. Feld aus Datensatz vorher */
static FUNCTION copy_field(p1,oget,fieldName)
LOCAL merk_Satz:=recno(),value
  ignore p1,oGet

  if my_skip(-1)<>0
    value:=fieldget(fieldpos(fieldName))
    // direkt oget �ndern geht leider nicht
    // wegen oget:updateBuffer in GetSys#GetDoSetKey
    // oget:varput(value)
    // oGet:updateBuffer()
    if value <> nil .and. valtype(value)=="C"
      keyboard chr(K_HOME)+chr(K_CTRL_Y)+alltrim(value)
    endif
    go(merk_Satz)
  endif
RETURN(.t.)

/** liefert die Spaltennummer zum Namen (ignores upper/lower case) */
Function getColPosByName(aFelder,name)
LOCAL result:=0,x:=1

  do while x<=len(aFelder) .and. upper(aFelder[x,EDIT_NAME])<>upper(name)
    x++
  enddo
  if x<=len(aFelder)
    result:=x
  endif

return result
/** eof */

static procedure kalkUntRand(aKopf)
  // ACHTUNG Wert aKopf[EDIT_ENDE_Y] ist negativ, also die Anzahl der Zeilen von unten!!!
  M->unt_Rand:=maxRow()+aKopf[EDIT_ENDE_Y]

  do while ! Mod(M->unt_rand-aKopf[EDIT_START_Y]+1,aKopf[EDIT_LINES]) == 0
    M->unt_rand--
  enddo

return
/** eop */

/** Zeigt die Anzahl der Datens�tze in der vorletzten Zeile an */
Function ZeigeAnzahl(aKopf)
LOCAL aktRec,anz

  if aKopf[EDIT_ZEIGE_ANZAHL]<>NIL
    aktRec:=recno()
    count to anz for eval(aKopf[EDIT_ZEIGE_ANZAHL])
    // FIXME: gescheite positionierung am BS
    @ maxRow()-1,aKopf[EDIT_LM] say "Anzahl Posten: "+alltrim(str(anz))
    // @ M->unt_Rand+2,aKopf[EDIT_LM] say "Anzahl Posten: "+alltrim(str(anz))
    go (aktRec)
  endif

return .t.
/** eof */

/** Merged 2 Farben, nimmt vom 1. String den Foreground und vom 2. den Background */
static function getMyFarbe(f1,f2)
LOCAL fg,bg

  if f1==NIL
    return f2
  endif
  if f2==NIL
    return f1
  endif

  // foreground
  if "/"$f1
    fg:=left(f1,at("/",f1)-1)
  else
    fg:=f1
  endif

  // background
  if "/"$f2
    bg:=substr(f2,at("/",f2)+1)
  else
    bg:=f2
  endif

return fg+"/"+bg
/** eof */

/** geht auf edn ersten zu editierenden Datensatz, falls gesetzt, ansonsten go top */
static procedure goStartRec(aKopf)
  if aKopf[EDIT_START_REC]==NIL
    go top
  else
    go (aKopf[EDIT_START_REC])
  endif
return
/** eop */

/** liefert die gesperrten Tasten als einfachen String zur�ck z.B. "�kln" */
static function getGesperrtKeys(aKopf)
LOCAL result
  if valtype(aKopf[EDIT_GESPERRT]) == "B"
    result:=eval( aKopf[EDIT_GESPERRT] )
  elseif valtype(aKopf[EDIT_GESPERRT]) == "C"
    result:=aKopf[EDIT_GESPERRT]
  else
    troubleEmail("Unkownn locked keys type: "+valtype(aKopf[EDIT_GESPERRT]))
  endif

  // falls � gesperrt, dann auch a
  if "�"$upper( result )
    result += "aA"+HARBOUR_AE
  endif

return result
/** eof */

/** Druckt alle Posten in eine ASCI Datei */
static function exportAscii()
local stop,zeile:=0
LOCAL GetList:={},aktRec:=recno(),i
LOCAL s001:=savescreen() // brauchen wir wegen Message()
  _thread static exportName

  default exportName:=left("Zeige"+getUser():getLongID()+"    ",8)

  if (exportName:=openFileDialog(WRITE,getUser():exportPATH(),exportName,"txt",nil))<>NIL

    Message("Datei wird generiert.  Bitte warten....")
    set alte to (exportName)
    set alte on
    set cons off
    stop:=.f.

    go top
    do while ! eof() .and. ! stop
      qout("Satz # "+str(recno())+":")
      for i:=1 to fcount()
        qout(fieldname(i)+":",fieldget(i))
      next
      qout("----------------------------------------------------------")
      skip
      Stop=stop_key()
    enddo
    set alte off
    close alte
    set cons on
    go (aktRec)

    Message("Datei:"+trim(exportName)+" wurde erzeugt.   Bitte @Taste@ dr�cken.","@")
    myrun(exportName)
    restscreen(,,,,s001)

  endif

RETURN .t.

/** liefert die aktuellen Felder als 2 dim. array { Name,Titel } zum verwenden im Excel-Export */
static function getFieldArray(aFelder)
LOCAL result:={},i
  for i:=1 to len(afelder)
    aadd(result, { aFelder[i,EDIT_NAME] , afelder[i,EDIT_TITEL] } )
  next
return result
/** eof */

/** pr�ft ob es Dubletten gibt,
  *
  * Dublette hei�t der Codeblock aKopf[i,EDIT_DUPLICATES] liefert beim aktuellen Record und
  * and mind. einer anderen Stelle den gleichen Wert <> NIL!!!
  *
  * Returns .f. falls Dublette vorhanden!
  */
function checkDuplicatesOk(cb)
LOCAL aktRec:=recno()
LOCAL aktVal:=eval(cb)
LOCAL result:=.t. // we're optimistic

  if aktVal <> NIL

    go top
    do while ! eof() .and. result
      if aktRec<>recno()
        result:=(aktVal <> eval(cb) )
      endif
      skip
    enddo

    go (aktRec)

    if ! result
      Error(ACHTUNG+"Datensatz ist bereits erfasst.  Kann nicht mehrfach erfasst werden!")
    endif

  endif
return result
/** eof */

/** malt einen Rahmen mit Titel um den Editor */
procedure drawEditFrame(aKopf,aFelder,text)
LOCAL add:=1

  if sumRequested(aFelder)
    add += 2
  endif

  setcolor(COLWIN)
  Fenster(aKopf[EDIT_START_Y]-4,aKopf[EDIT_LM]-2,M->unt_Rand+add,aKopf[EDIT_RM]+2, text ,.f.)
  setcolor(COLNOR)

  /* Titel-Zeile */
  Titel_Edit(aFelder,aKopf[EDIT_START_Y]-2,aKopf)

return
/** eop */

static function checkModeChangeFunction(aKopf)
  // benutzerdef. Funktion nach Eingabe Modus ausf�hren?
  if aKopf[EDIT_AFTER_MODE_CHANGE]<>NIL
    if ! eval( aKopf[EDIT_AFTER_MODE_CHANGE] )
      return .f.
    endif
  endif
return .t.
/** eof */


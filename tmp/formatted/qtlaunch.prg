/**
* Hauptmodul:   zum starten von QT Guis als stand alone AApplikation
*
* sowie Funktionen zum internen und externen Anzeigen von QT Masken
*
*/

#include "Miki.ch"

#include "hbgtinfo.ch"
// #include "hbwin.ch"
#include "hbqtgui.ch"


#define QVARIANT_UNCHANGED 0
#define QVARIANT_CHANGED 1
#define QVARIANT_DELETED 2

  /** startet ein komplett neues Miki-Programm bzw. ein QMainWindow
  * FIXME: this does no longer belong to qt*.*
  */
function launchProgram( ProcName, oGet, taste )
LOCAL startNr, startNr2:=NIL, params:=LAUNCH_DIRECT+LAUNCH_SEP
LOCAL aktRec, aktSel:=alias(),prog
LOCAL Text:=""

  ignore procname

  if valtype(taste) <> "N"
    taste:=lastKey()
  endif

  if ! getUser():mayShowData
    return .f.
  endif
  Umgebung(WRITE_ALL)

  do case
  case taste == K_ALT_A ; // ARTIKEL ***************************************
    .or. taste == K_ALT_Q ; // Material-St�ckliste ***************************
    .or. taste == K_ALT_W ; // Werkzeug-St�ckliste****************************
    .or. ( oGet <> NIL .and. "TREE" $ oGet:className() .and. ;
      ( taste == Qt_Key_Return .or. taste == Qt_Key_Enter .or. upper(chr(taste)) == "A" ) ) ;

    // bisher nur A - Artikel freigegeben, Thread-Problem / Datei-Zugriff
    // Siehe qtDisp.prg und qtLaunch.prg als evtl. L�sungsansatz
    // .or. ( oGet <> NIL .and. "TREE" $ oGet:className() .and. taste $ "MZWA")
    // QT: Material-St�ckliste ***************************
    // QT: Zeit-St�ckliste ***************************
    // QT: Werkzeug-St�ckliste ***************************
    // QT: Artikel-St�ckliste ***************************

    // suche Art.Nr
    if ! open("Artikel","Einheit","AvPost","Text")
      Error(TRY_AGAIN)
      Umgebung(LOAD)
      return .f.
    endif
    select Artikel
    set relation to ARTIKEL->ME into Einheit

    if ! empty(aktSel)
      select (aktSel) // alt: wegen fieldget() unten, neu: eigentlich unn�tig wegen (aktsel)->(fieldget())...
    endif

    do case

      // kommt aus QT Tree-View-Fenster, Abfrage muss vor Artikel stehen, da Tree-Selektion vorgeht!
    case oGet <> NIL .and. "TREE" $ oGet:className()
      startNr:=oGet:getCurrentItemData()

    case oGet <> NIL .and. ("VARTNR" $ oGet:name .or. "BARTNR" $ oGet:name .or. "editMatArtNr" $ oGet:name)
      startNr:=oGet:buffer

    case aktSel == "ARTIKEL"
      startNr:=ARTIKEL->ArtNr

    case aktSel == "NKERF"
      if ! empty(NKERF->ArtNr)
        startNr:=NKERF->ArtNr
      else
        startNr:=INNER->ArtNr
      endif

    case aktSel == "NKARTIKEL"
      startNr:=INNER->ArtNr

    case aktSel == "MEHRTEMP"
      startNr:=MEHRTEMP->ANr

    case aktSel == "ZEIGE"

      if empty( ZEIGE->ArtNr )
        startNr:=left(ltrim(ZEIGE->Line),len(out(ARTIKEL->ArtNr)))
      else
        startNr:=ZEIGE->ArtNr
      endif

      // removed dot, if any
      if "." $ startNr
        startNr:=deleteString(startNr,".")
      endif

      if len(startnr) <> len(ARTIKEL->ArtNr)
        startNr:=left(startNr+space(len(ARTIKEL->ArtNr)),len(ARTIKEL->ArtNr))
      endif


    otherwise
      if ! empty(aktSel) .and. fieldpos("ArtNr") > 0
        startNr:=fieldget(fieldpos("ArtNr"))
      endif
    endcase

    // now launch it
    if startNr<>NIL .and. ! empty(alltrim(startNr))
      aktRec:=ARTIKEL->(recno())
      ARTIKEL->(OrdSetFocus(1))
      ARTIKEL->(dbseek(startNr))
      if ARTIKEL->(eof())
        Error(ACHTUNG+ "Artikel: "+startNr + " nicht gefunden.")
        ARTIKEL->(dbgoto(aktRec))
        Umgebung(LOAD)
        return .f.
      endif
      ARTIKEL->(dbgoto(aktRec))

      // Artikel launchen
      if taste == K_ALT_A .or. ;
        taste == Qt_Key_Return .or. taste == Qt_Key_Enter .or. ;
        (taste <> NIL .and. upper(chr(taste)) == "A")
        params += getUser():id + LAUNCH_SEP
        params += "ARTIKEL" + LAUNCH_SEP
        params += getLaunchKey(getUser():id) + LAUNCH_SEP
        params += startNr
        params:='"'+params+'"'

        // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramer
        // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
        wapi_SHELLEXECUTE(,,ExeName(), params )

      else // St�ckliste etc.

        do case
        case taste == K_ALT_Q .or. ;
          ( oGet <> NIL .and. "TREE" $ oGet:className() .and. taste = "M")
          showStkList( startNr,"M",trim(startNr)+" Material-St�ckliste")
          // case taste == K_CTRL_Z .or. taste == K_CTRL_Y .or. 
          // ( oGet <> NIL .and. "TREE" $ oGet:className() .and. taste = "Z")
          // showStkList( startNr,"V",trim(startNr)+" Zeiten-St�ckliste")
        case taste == K_ALT_W .or. ;
          ( oGet <> NIL .and. "TREE" $ oGet:className() .and. taste = "W")
          showStkList( startNr,"W",trim(startNr)+" Werkzeug-St�ckliste")
        endcase
      endif

      // zur�ck auf urspr. Artikel
      ARTIKEL->(dbgoto(aktRec))

    endif

    case lastkey() == K_ALT_K // KUNDEN ***************************************

      // suche Kund.Nr
      if select("Kunden")==0 .and. ! open("Kunden")
        Error(TRY_AGAIN)
        Umgebung(LOAD)
        return .f.
      endif
      if ! empty(aktSel)
        select (aktSel) // wegen fieldget() unten
      endif

      do case
      case oGet <> NIL .and. oGet:className()=="GET" .and. "KUNDNR" $ upper(oGet:Name)
        startNr:=oGet:buffer

      case aktSel == "KUNDEN"
        startNr:=KUNDEN->KundNr

      case aktSel == "ZEIGE"
        if empty( ZEIGE->KundNr )
          startNr:=left(ltrim(ZEIGE->Line),len(KUNDEN->KundNr))
        else
          startNr:=ZEIGE->KundNr
        endif

      otherwise
        if ! empty(aktSel) .and. fieldpos("Kundnr")>0
          startNr:=fieldget(fieldpos("Kundnr"))
        endif
      endcase

      // now launch it
      if startNr<>NIL .and. ! empty(alltrim(startNr))
        aktRec:=KUNDEN->(recno())
        KUNDEN->(OrdSetFocus(1))
        KUNDEN->(dbseek(startNr))
        if KUNDEN->(eof())
          Error(ACHTUNG+ "Kunden: "+startNr + " nicht gefunden.")
          KUNDEN->(dbgoto(aktRec))
          Umgebung(LOAD)
          return .f.
        endif
        KUNDEN->(dbgoto(aktRec))

        params += getUser():id + LAUNCH_SEP
        params += "KUNDEN" + LAUNCH_SEP
        params += getLaunchKey(getUser():id) + LAUNCH_SEP
        params += startNr
        params:='"'+params+'"'

        // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
        // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
        wapi_SHELLEXECUTE(,,ExeName(), params )
      endif

      case lastkey() == K_ALT_G // Angebot ***************************************
        // altd()

        do case
        case aktSel == "ZEIGE"
          if empty( ZEIGE->AngNr )
            startNr:=left(ltrim(ZEIGE->Line),5)
          else
            startNr:=ZEIGE->AngNr
          endif

        otherwise
          // nop
        endcase

        // now launch it
        if startNr<>NIL .and. ! empty(alltrim(startNr))
          aktRec:=ANGAUS->(recno())
          ANGAUS->(OrdSetFocus(1))
          ANGAUS->(dbseek(startNr))
          if ANGAUS->(eof())
            Error(ACHTUNG+ "Angebot: "+startNr + " nicht gefunden.")
            ANGAUS->(dbgoto(aktRec))
            Umgebung(LOAD)
            return .f.
          endif
          ANGAUS->(dbgoto(aktRec))

          params += getUser():id + LAUNCH_SEP
          params += "ANGEBOT" + LAUNCH_SEP
          params += getLaunchKey(getUser():id) + LAUNCH_SEP
          params += startNr
          params:='"'+params+'"'

          // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
          // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
          wapi_SHELLEXECUTE(,,ExeName(), params )

        else // neues Angebot

          // only when the ALT key is pressed, since � has the same key code as ALT_� :(
          if hb_gtinfo( HB_GTI_KBDSHIFTS );
            == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ), HB_GTI_KBD_ALT )
            if aktSel == "ARTIKEL"
              startNr:=ARTIKEL->ArtNr
            elseif aktSel == "KUNDEN"
              startNr2:=KUNDEN->KundNr
            elseif aktSel == "ZEIGE"
              startNr:=ZEIGE->ArtNr
            elseif fieldpos("ArtNr") > 0
              startNr:=(alias())->(fieldget(fieldpos("artnr")))
            endif
            params += getUser():id + LAUNCH_SEP
            params += "ANGEBOT" + LAUNCH_SEP
            params += getLaunchKey(getUser():id) + LAUNCH_SEP
            params += "" + LAUNCH_SEP
            if valtype(startNr)<>"U"
              params += startNr
            endif
            if valtype(startNr2)<>"U"
              params += "" + LAUNCH_SEP
              params += startNr2
            endif
            params:='"'+params+'"'


            // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramer
            // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
            wapi_SHELLEXECUTE(,,ExeName(), params )
          endif

        endif

        case lastkey() == K_CTRL_F6 // OberBaugruppen ***************************************

          do case
          case aktSel == "ZEIGE"
            if empty( ZEIGE->ArtNr )
              startNr:=invOut(left(ltrim(ZEIGE->Line),len(out(ARTIKEL->ArtNr))))
            else
              startNr:=ZEIGE->ArtNr
            endif
          case aktSel == "ARTIKEL"
            startNr:=ARTIKEL->Artnr

          otherwise
            // nop
          endcase

          if startNr <> NIL .and. ! empty(startNr)
            aktRec:=ARTIKEL->(recno())
            ARTIKEL->(OrdSetFocus(1))
            ARTIKEL->(dbseek(startNr))
            if ARTIKEL->(eof())
              Error(ACHTUNG+ "Artikel: "+startNr + " nicht gefunden.")
              ARTIKEL->(dbgoto(aktRec))
              Umgebung(LOAD)
              return .f.
            endif
            ARTIKEL->(dbgoto(aktRec))

            // Baugruppe launchen
            params += getUser():id + LAUNCH_SEP
            params += "OBERBAUGRUPPEN" + LAUNCH_SEP
            params += getLaunchKey(getUser():id) + LAUNCH_SEP
            params += startNr
            params:='"'+params+'"'

            // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramer
            // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
            wapi_SHELLEXECUTE(,,ExeName(), params )
          endif

          case lastkey() == K_ALT_L // Lieferanten ***************************************

            // suche Lief.Nr
            if select("Lieferan")==0 .and. ! open("Lieferan")
              Error(TRY_AGAIN)
              Umgebung(LOAD)
              return .f.
            endif
            if ! empty(aktSel)
              select (aktSel) // wegen fieldget() unten
            endif

            do case
            case oGet <> NIL .and. oGet:className()=="GET" .and. "LIEFNR" $ upper(oGet:Name)
              startNr:=oGet:buffer

            case aktSel == "LIEFERAN"
              startNr:=LIEFERAN->Liefnr

            case aktSel == "ZEIGE"
              if empty( ZEIGE->LiefNr )
                startNr:=left(ltrim(ZEIGE->Line),len(LIEFERAN->Liefnr))
              else
                startNr:=ZEIGE->Liefnr
              endif

            otherwise
              if ! empty(aktSel) .and. fieldpos("LiefNr")>0
                startNr:=fieldget(fieldpos("LiefNr"))
              endif
            endcase

            // now launch it
            if startNr<>NIL .and. ! empty(alltrim(startNr))
              aktRec:=LIEFERAN->(recno())
              LIEFERAN->(OrdSetFocus(1))
              LIEFERAN->(dbseek(startNr))
              if LIEFERAN->(eof())
                Error(ACHTUNG+ "Lieferanten: " + startNr + " nicht gefunden.")
                LIEFERAN->(dbgoto(aktRec))
                Umgebung(LOAD)
                return .f.
              endif
              LIEFERAN->(dbgoto(aktRec))

              params += getUser():id + LAUNCH_SEP
              params += "LIEFERAN" + LAUNCH_SEP
              params += getLaunchKey(getUser():id) + LAUNCH_SEP
              params += startNr
              params:='"'+params+'"'

              // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
              // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
              wapi_SHELLEXECUTE(,,ExeName(), params )
            endif

            case lastkey() == K_ALT_R // Rechnungen ***************************************

              // suche Rech.Nr
              if select("Rechaus")==0 .and. ! open("Rechaus")
                Error(TRY_AGAIN)
                Umgebung(LOAD)
                return .f.
              endif
              if ! empty(aktSel)
                select (aktSel) // wegen fieldget() unten
              endif

              do case
              case oGet <> NIL .and. oGet:className()=="GET" .and. "RECHNR" $ upper(oGet:Name)
                startNr:=oGet:buffer

              case aktSel == "RECHAUS"
                startNr:=RECHAUS->RechNr

              case aktSel == "RECHPOST"
                startNr:=RECHPOST->RechNr

              case aktSel == "ZEIGE"
                if empty( ZEIGE->RechNr )
                  startNr:=left(ltrim(ZEIGE->Line),len(RECHAUS->RechNr))
                else
                  startNr:=ZEIGE->Rechnr
                endif

              otherwise
                if ! empty(aktSel) .and. fieldpos("RechNr")>0
                  startNr:=fieldget(fieldpos("RechNr"))
                endif
              endcase

              // now launch it
              if startNr<>NIL .and. ! empty(alltrim(startNr))
                aktRec:=RECHAUS->(recno())
                RECHAUS->(OrdSetFocus(1))
                RECHAUS->(dbseek(startNr))
                if RECHAUS->(eof())
                  Error(ACHTUNG+ "Rechnung: " + startNr + " nicht gefunden.")
                  RECHAUS->(dbgoto(aktRec))
                  Umgebung(LOAD)
                  return .f.
                endif
                RECHAUS->(dbgoto(aktRec))

                params += getUser():id + LAUNCH_SEP
                params += "RECHAUS" + LAUNCH_SEP
                params += getLaunchKey(getUser():id) + LAUNCH_SEP
                params += startNr
                params:='"'+params+'"'

                // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                wapi_SHELLEXECUTE(,,ExeName(), params )
              endif

              // Zeiten / Maschine **********************
              case lastkey() == K_ALT_Z .or. lastkey() == K_ALT_Y .or. lastkey() == K_ALT_M

                // suche Maschinen.Nr
                if select("Maschine")==0 .and. ! open("Maschine")
                  Error(TRY_AGAIN)
                  Umgebung(LOAD)
                  return .f.
                endif
                if ! empty(aktSel)
                  select (aktSel) // wegen fieldget() unten
                endif

                do case
                case oGet <> NIL .and. oGet:className()=="GET" .and. "STDNR" $ upper(oGet:Name)
                  startNr:=oGet:buffer

                case aktSel == "MASCHINE"
                  startNr:=MASCHINE->Stdnr

                case aktSel == "ZEIT_T"
                  startNr:=trim( ZEIT_T->ArtNr )

                case aktSel == "NKPOST"
                  startNr:=NKPOST->MaschNr

                case aktSel == "NKERF"
                  startNr:=NKERF->MaschNr

                case aktSel == "ZEIGE"
                  if empty( ZEIGE->Stdnr )
                    startNr:=left(ltrim(ZEIGE->Line),len(MASCHINE->Stdnr))
                  else
                    startNr:=ZEIGE->Stdnr
                  endif

                otherwise
                  if ! empty(aktSel) .and. fieldpos("Stdnr")>0
                    startNr:=fieldget(fieldpos("Stdnr"))
                  endif
                endcase

                // now launch it
                if startNr<>NIL .and. ! empty(alltrim(startNr))
                  aktRec:=MASCHINE->(recno())
                  MASCHINE->(OrdSetFocus(1))
                  MASCHINE->(dbseek(startNr))
                  if MASCHINE->(eof())
                    Error(ACHTUNG+ "Maschine: " + startNr + " nicht gefunden.")
                    MASCHINE->(dbgoto(aktRec))
                    Umgebung(LOAD)
                    return .f.
                  endif
                  MASCHINE->(dbgoto(aktRec))

                  params += getUser():id + LAUNCH_SEP
                  params += "MASCHINE" + LAUNCH_SEP
                  params += getLaunchKey(getUser():id) + LAUNCH_SEP
                  params += startNr
                  params:='"'+params+'"'

                  // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                  // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                  wapi_SHELLEXECUTE(,,ExeName(), params )
                endif

                case lastkey() == K_ALT_F // Fakturierung AB ***************************************

                  // suche Auf.Nr
                  if select("Aufaus")==0 .and. ! open("Aufaus")
                    Error(TRY_AGAIN)
                    Umgebung(LOAD)
                    return .f.
                  endif
                  if ! empty(aktSel)
                    select (aktSel) // wegen fieldget() unten
                  endif

                  do case
                  case oGet <> NIL .and. oGet:className()=="GET" .and. "AUFNR" $ upper(oGet:Name)
                    startNr:=oGet:buffer

                  case aktSel == "AUFAUS"
                    startNr:=AUFAUS->AufNr

                  case aktSel == "ZEIGE"
                    if empty( ZEIGE->AufNr )
                      startNr:=left(ltrim(ZEIGE->Line),len(AUFAUS->AufNr))
                    else
                      startNr:=ZEIGE->AufNr
                    endif

                  otherwise
                    if ! empty(aktSel) .and. fieldpos("AufNr")>0
                      startNr:=fieldget(fieldpos("AufNr"))
                    endif
                  endcase

                  // now launch it
                  if startNr<>NIL .and. ! empty(alltrim(startNr))
                    aktRec:=AUFAUS->(recno())
                    AUFAUS->(OrdSetFocus(1))
                    AUFAUS->(dbseek(startNr))
                    if AUFAUS->(eof())
                      Error(ACHTUNG+ "AB: " + startNr + " nicht gefunden.")
                      AUFAUS->(dbgoto(aktRec))
                      Umgebung(LOAD)
                      return .f.
                    endif
                    AUFAUS->(dbgoto(aktRec))

                    params += getUser():id + LAUNCH_SEP
                    params += "AUFAUS" + LAUNCH_SEP
                    params += getLaunchKey(getUser():id) + LAUNCH_SEP
                    params += startNr
                    params:='"'+params+'"'

                    // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                    // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                    wapi_SHELLEXECUTE(,,ExeName(), params )
                  endif

                  case lastkey() == K_ALT_B // Bestellung extern ***************************************

                    // suche Best.Nr
                    if select("Besaus")==0 .and. ! open("Besaus")
                      Error(TRY_AGAIN)
                      Umgebung(LOAD)
                      return .f.
                    endif
                    if ! empty(aktSel)
                      select (aktSel) // wegen fieldget() unten
                    endif

                    do case
                    case oGet <> NIL .and. oGet:className()=="GET" .and. "BESTNR" $ upper(oGet:Name)
                      startNr:=oGet:buffer

                    case aktSel == "BESAUS"
                      startNr:=BESAUS->BestNr

                    case aktSel == "BESTEMP"
                      startNr:=BESTEMP->BestNr

                    case aktSel == "ZEIGE"
                      if empty( ZEIGE->BestNr )
                        startNr:=left(ltrim(ZEIGE->Line),len(BESAUS->BestNr))
                      else
                        startNr:=ZEIGE->Bestnr
                      endif

                    otherwise
                      if ! empty(aktSel) .and. fieldpos("BestNr")>0
                        startNr:=fieldget(fieldpos("BestNr"))
                      endif
                    endcase

                    // now launch it
                    if startNr<>NIL .and. ! empty(alltrim(startNr))
                      aktRec:=BESAUS->(recno())
                      BESAUS->(OrdSetFocus(1))
                      BESAUS->(dbseek(startNr))
                      if BESAUS->(eof())
                        Error(ACHTUNG+ "Bestellung: " + startNr + " nicht gefunden.")
                        BESAUS->(dbgoto(aktRec))
                        Umgebung(LOAD)
                        return .f.
                      endif
                      BESAUS->(dbgoto(aktRec))

                      params += getUser():id + LAUNCH_SEP
                      params += "BESAUS" + LAUNCH_SEP
                      params += getLaunchKey(getUser():id) + LAUNCH_SEP
                      params += startNr
                      params:='"'+params+'"'

                      // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                      // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                      wapi_SHELLEXECUTE(,,ExeName(), params )
                    endif

                    case lastkey() == K_ALT_I // Bestellung intern ***************************************

                      // suche InnerNr
                      if select("Inner")==0 .and. ! open("Inner")
                        Error(TRY_AGAIN)
                        Umgebung(LOAD)
                        return .f.
                      endif
                      if ! empty(aktSel)
                        select (aktSel) // wegen fieldget() unten
                      endif

                      do case
                      case oGet <> NIL .and. oGet:className()=="GET" .and. "INNERNR" $ upper(oGet:Name)
                        startNr:=oGet:buffer

                      case aktSel == "INNER"
                        startNr:=INNER->InnerNr

                      case aktSel == "NKARTIKEL" .or. aktSel == "NKERF"
                        prog:="INLFDNR"
                        startNr:=INNER->InLfdNr

                      case aktSel == "ZEIGE"
                        prog:="INNER"
                        if ! empty( ZEIGE->InnerNr )
                          startNr:=ZEIGE->InnerNr
                        elseif ! empty( ZEIGE->InLfdNr )
                          startNr:=ZEIGE->InLfdNr
                          prog:="INLFDNR"
                        else
                          startNr:=left(ltrim(ZEIGE->Line),len(INNER->InnerNr))
                        endif

                      otherwise
                        if ! empty(aktSel) .and. fieldpos("InnerNr")>0
                          startNr:=fieldget(fieldpos("InnerNr"))
                        endif
                      endcase

                      // now launch it
                      if startNr<>NIL .and. ! empty(alltrim(startNr))
                        aktRec:=INNER->(recno())
                        if prog == "INNER"
                          INNER->(OrdSetFocus(1))
                        else // Inlfdnr
                          INNER->(OrdSetFocus(3))
                        endif
                        INNER->(dbseek(startNr))
                        if INNER->(eof())
                          Error(ACHTUNG+ "Interner Auftrag: " + startNr + " nicht gefunden.")
                          INNER->(dbgoto(aktRec))
                          Umgebung(LOAD)
                          return .f.
                        endif
                        INNER->(dbgoto(aktRec))

                        params += getUser():id + LAUNCH_SEP
                        params += prog + LAUNCH_SEP
                        params += getLaunchKey(getUser():id) + LAUNCH_SEP
                        params += startNr
                        params:='"'+params+'"'

                        // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                        // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                        wapi_SHELLEXECUTE(,,ExeName(), params )
                      endif

                      case lastkey() == K_ALT_N // Neues Programm

                        params += getUser():id + LAUNCH_SEP
                        params += "MIKI_PROG" + LAUNCH_SEP
                        params += getLaunchKey(getUser():id) + LAUNCH_SEP
                        params:='"'+params+'"'

                        // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
                        // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
                        wapi_SHELLEXECUTE(,,ExeName(), params )

                      endcase

                      Umgebung(LOAD)
                      return .t.
  /** eof */

  /** startet ein neues Prorgamm mit neuer Bestellung des akt. Lieferanten aus der Bestkarte
  */
function launchNeueBestellung()
LOCAL params:=LAUNCH_DIRECT+LAUNCH_SEP
  params += getUser():id + LAUNCH_SEP
  params += "BESTELLUNG" + LAUNCH_SEP
  params += getLaunchKey(getUser():id) + LAUNCH_SEP
  params += BESTTEMP->LiefNr + LAUNCH_SEP
  params += ARTIKEL->ArtNr // nehme ArtNr aus Artikel, dann geht's auch bei leerer Bestellkarte
  params:='"'+params+'"'

  // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramert
  // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
  if AT_HOME
    // FIXME: should not be harcoded here!
    wapi_SHELLEXECUTE(,,"hbmiki.exe",params)
  else
    wapi_SHELLEXECUTE(,,"miki.exe",params)
  endif

  // Bestellkart schliessen
  keyboard( chr(K_ESC) )
return .t.
/** eof */

/** �berpr�ft den �bergebenen Launchkey */
function validateLaunchKey(user,value)
return (getLaunchKey(user)==value)
/** eof */

  /** liefert den aktuellen Launchkey
  * z.Zt. seconds seit midnight ohne letze Stell
  * d.h. key gilt max. 10 sekunden
  */
  #define KEY_TIME 2 // -> 99 Sekunden
function getLaunchKey(userId)
LOCAL result:="FIXMEencryptMe"+UserID
  // LOCAL result:=alltrim(str(seconds(),12,0))
  // if len(result)>KEY_TIME
  // result:=left(result,len(result)-KEY_TIME)
  // endif
  // result += userId
  // result += dtoc(hb_date())
  // result:=encrypt(result)
return result
/** eof */

/** Zeigt die St�ckliste des �bergebenen Artikels in einem QT Fenster an */
static procedure showStkList(mArtNr, mArt,Titel )
LOCAL oWnd:=QMainWindow()
LOCAL oTree
LOCAL dock

  // Zeiten
  if mArt=="V" // ACHTUNG KZ f�r Zeit ist V!!!
    oTree:=qtTree():new( oWnd, ;
      {"Artikel","Text","Menge","H/N","Nutzen","Auto","R�stzeit","� Menge"} )
  else
    // Material & Werkzeug
    oTree:=qtTree():new( oWnd, {"Artikel","Text","Menge","ME","Ort"} )
  endif

  select Artikel
  set relation to ARTIKEL->ME into Einheit

  oWnd:setWindowTitle( titel )
  oTree:addTopLevelItem( populateStkList( oTree, MArtNr, mArt, .t. ) )

  oWnd:setWindowIcon( QIcon( RESOURCES+BACKSLASH+getProperty("System.icon.png","") ) )
  oWnd:setCentralWidget( oTree:getWidget() )

  // create filter dock widget
  dock:=QDockWidget("Filter", oWnd, 0)
  dock:setWidget( oTree:getTreeNavigationPanel() )
  dock:setFeatures(hb_bitOR(QDockWidget_DockWidgetMovable,QDockWidget_DockWidgetVerticalTitleBar,;
    QDockWidget_DockWidgetFloatable))
  // dock:setFeatures( QDockWidget_DockWidgetMovable )
  oWnd:addDockWidget( Qt_BottomDockWidgetArea, dock )

  oWnd:connect( QEvent_KeyPress, { |x| winKeyPressed(x, oWnd, oTree) } )
  oWnd:resize(700,500)

  // Info: no registerDialog() needed, because it is non modal and will be closed by main app
  oWnd:show()

return
/** eop */

/*----------------------------------------------------------------------*/
/** sortiert alle Unter-Artikel in Baumstruktur ein und liefert root node zur�ck */
static function populateStkList(oTree, MArtNr, filterArt, isTopLevel, tiefe)
LOCAL node:=oTree:getNewTreeItem( MArtNr )
LOCAL child
LOCAL aktArt:=ARTIKEL->(recno())
LOCAL aktAV
LOCAL aktSel

  default tiefe:=0

  // Zeiten
  if filterArt=="V" // ACHTUNG KZ f�r Zeit ist V!!!
    // Material & Werkzeug
    if isTopLevel
      ARTIKEL->(dbseek( MArtNr ))
      node:setText( 0, MArtNr)
      node:setText( 1, ARTIKEL->Bez1 + if(empty(ARTIKEL->Bez2),"",MY_CR + MY_LF + ARTIKEL->Bez2) )
      // Menge ist immer 1, bei 1. Artikel
      node:setText( 2, "1,000" )
      node:setTextAlignment( 2, Qt_AlignRight )
    else
      if select("Maschine") == 0
        aktsel:=alias()
        if ! open("Maschine")
          return node
        endif
        select (aktSel)
      endif

      MASCHINE->(dbseek(mArtNr))
      node:setText( 0, MArtNr)
      node:setText( 1, MASCHINE->Bez )
      node:setText( 2, transStr( AVPOST->Menge,11,3 ) )
      node:setTextAlignment( 2, Qt_AlignRight )
      node:setText( 3, AVPOST->HauptKZ )
      node:setText( 4, getMehrfNutzen() )
      node:setText( 5, AVPOST->Automat )
      node:setText( 6, str(AVPOST->RUESTZEIT,5,2) )
      node:setText( 7, str(AVPOST->SollMenge,7,0) )
      node:setTextAlignment( 7, Qt_AlignRight )
    endif
  else
    ARTIKEL->(dbseek( MArtNr ))
    node:setText( 0, MArtNr)
    node:setText( 1, ARTIKEL->Bez1 + if(empty(ARTIKEL->Bez2),"",MY_CR + MY_LF + ARTIKEL->Bez2) )
    if isTopLevel
      // Menge ist immer 1, bei 1. Artikel
      node:setText( 2, "1,000" )
    else
      node:setText( 2, transStr( AVPOST->Menge,11,3 ) )
    endif
    node:setTextAlignment( 2, Qt_AlignRight )
    node:setText( 3, EINHEIT->Text )
    node:setText( 4, getArtikelLagerOrt(11) )
  endif

  // lade Posten
  AVPOST->(dbseek( MArtNr + filterArt ))
  do while ! AVPOST->(eof()) .and. AVPOST->AvNr == MArtNr .and. AVPOST->Art == filterArt
    if AVPOST->Text == "T"
      TEXT->(dbseek( trim(AVPOST->ArtNr) ))
      child:=oTree:getNewTreeItem( AVPOST->ArtNr )
      child:setText( 0, AVPOST->ArtNr )
      child:setText( 1, TEXT->Text )
    else
      if tiefe >= 50
        exit
      endif
      aktAv:=AVPOST->(recno())
      child:=populateStkList( oTree, AVPOST->ArtNr, filterArt, .f., tiefe + 1)
      AVPOST->(dbgoto(aktAv))
    endif
    node:addChild( child )
    AVPOST->(dbskip())
  enddo

  ARTIKEL->(dbgoto(aktArt))

return node
/** eof */


FUNCTION winKeyPressed( x, oWnd, oTree )
LOCAL handled:=.t.

  ignore oTree

  do case
  case x:key() == 16777251 // Alt-Key
    // NOP

  case x:key() == Qt_Key_Escape
    oWnd:close()

    // Alt-Enter -> Maximize
  case (x:key() == Qt_Key_Return .or. x:key() == Qt_Key_Enter ) .and.;
    hb_bitAnd( x:modifiers(), Qt_AltModifier ) == Qt_AltModifier
    if oWnd:isMaximized()
      oWnd:showNormal()
    else
      oWnd:showMaximized()
    endif

  otherwise
    handled:=.f.

  endcase

return handled
/** eop */


procedure launchNewProgram( dateiname, startnr, keyboard )
LOCAL params:=LAUNCH_DIRECT+LAUNCH_SEP
  params += getUser():id + LAUNCH_SEP
  params += upper(dateiname) + LAUNCH_SEP
  params += getLaunchKey(getUser():id) + LAUNCH_SEP
  params += startNr
  params:='"'+params+'"'
  if valtype(keyboard) == "C"
    params += LAUNCH_SEP + keyboard
  endif

  // nehme wapi_SHELLEXECUTE anstatt myRun, da die ersten Paramer
  // NIL sein m�ssen, da sonst kein Fenster angezeigt wird
  wapi_SHELLEXECUTE(,,ExeName(), params )
return
/** eop */
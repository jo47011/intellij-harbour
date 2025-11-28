/***
*
*  Errorsys.prg
*
*  Standard Fehlerbehandlung f�r CA-Clipper 5.2
*
*  Copyright (c) 1990-1993, Computer Associates International, Inc.
*  Alle Rechte Vorbehlten.
*
*  Kompileren mit Schalter  /m /n /w
*
*/

#include "error.ch"
#include "mystd.ch"


// Umleiten der Fehlerausgaben auf STDERR */
#command ? <list,...> => ?? Chr(13) + Chr(10) ; ?? <list>
#command ?? <list,...> => OutErr(<list>)


// Pseudofunktion, wird sp�ter ben�tigt
#define NTRIM(n) ( LTrim(Str(n)) )



/***
*  ErrorSys()
*
* Hinweis:  wird automatisch bei Programmstart ausgef�hrt
*/

// removed 20160617 -> now in init
// proc ErrorSys()
// ErrorBlock( {|e| DefError(e)} )
// return




/***
*  DefError()
*/
function DefError(objErr)
local i, cMessage, aOptions, nChoice
local fix, sendEmail:=.t.

  // altd()
  fix:=fixError(objErr)
  if fix != NIL
    return fix
  endif

  // if objErr:tries <= 2 .and. ! str(objErr:genCode,4) $ TRIVIAL_ERROR // nur beim 1. + 2. Versuch
  // ABfrage auf tries ist nicht mehr 0 am Anfang ??? jojo
  if ! str(objErr:genCode,4) $ TRIVIAL_ERROR // nur beim 1. Versuch
    sendEmail:=fehler(objErr)
  endif

  // Bei access or create Problemen schreibe alle file handles
  if objErr:osCode == 38 .or. objErr:osCode == 20
    writeHandles(objErr:FILENAME)
  endif

  // Setzen des Status von NETERR() bei Datei�ffnen-Fehler im Netzwerk
  if ( objErr:genCode == EG_OPEN .and. objErr:osCode == 32 .and. objErr:canDefault )

    if sendEmail
      Trouble("root", { "not fixed: "+objErr:Description+" EG_OPEN" , ;
        "Benutzer:"+getUser():getLongId() } )
    endif

    NetErr(.t.)
    return (.f.) // Achtung
    end

    // Setzen des Status von NETERR() bei Dateisperren-Fehler durch APPEND BLANK im Netzwerk
    if ( objErr:genCode == EG_APPENDLOCK .and. objErr:canDefault )

      if sendEmail
        Trouble("root", { "not fixed: "+objErr:Description+" EG_APPENDLOCK" , ;
          "Benutzer:"+getUser():getLongId() } )
      endif

      NetErr(.t.)
      return (.f.) // Achtung
      end

      // Zusammensetzen einer Fehlernachricht
      cMessage:=ErrorMessage(objErr)

      // Drucker nicht bereit , jojo
      if ( objErr:genCode == EG_PRINT )
        cMessage:="Drucker nicht bereit !"
      endif

      // Zusammensetzen einer Fehlernachricht
      // aOptions:={"Abbruch", "Beenden"}
      aOptions:={}

      if (objErr:canRetry)
        AAdd(aOptions, "Wiederholen")
        end

        if (objErr:canDefault)
          AAdd(aOptions, "�bergehen")
          end

          aadd(aOptions,"Beenden")


          // Anzeigen �ber Dialogbox (ALERT())
          nChoice:=0
          while ( nChoice == 0 )

            if ( Empty(objErr:osCode) )
              nChoice:=Alert( cMessage, aOptions )

            else
              nChoice:=Alert( cMessage + ;
                ";(DOS Fehler " + NTRIM(objErr:osCode) + ")", ;
                aOptions )
              end


              if ( nChoice == NIL )
                exit
                end

                end


                if ( !Empty(nChoice) )

                  // Ausf�hren der gew�hlten Option
                  if ( aOptions[nChoice] == "Abbruch" ) // never reached !
                    Break(objErr)

                  elseif ( aOptions[nChoice] == "Wiederholen" )
                    return (.t.)

                  elseif ( aOptions[nChoice] == "�bergehen" )
                    return (.f.)

                  elseif ( aOptions[nChoice] == "Beenden" ) .and. ( objErr:genCode == EG_PRINT )
                    Drucker("RESET")
                    return .t.

                    end

                    end


                    // Anzeige der Fehlernachricht und traceback
                    if ( !Empty(objErr:osCode) )
                      cMessage += " (DOS Fehler " + NTRIM(objErr:osCode) + ") "
                      end

                      ? cMessage
                      i:=2
                      while ( !Empty(ProcName(i)) )
                        ? "Aufgerufen von", Trim(ProcName(i)) + ;
                          "(" + NTRIM(ProcLine(i)) + ")  "

                        i++
                        end

                        // Generate PyCharm-compatible stack trace
                        #ifdef DBG_PORT
                        printDebugStackTrace()
                        #endif

                        // Aufgeben und DOS ERRORLEVEL setzen
                        ErrorLevel(1)
                        // QUIT , jojo
                        if ! DEVEL_PROG
                          Down(.f.)
                        else
                          QUIT
                        endif

                        return (.f.)




/***
*  ErrorMessage()
*/
static function ErrorMessage(objErr)
local cMessage


  // Fehlermeldung
  cMessage:=if( objErr:severity > ES_WARNING, "Fehler ", "Warnung " )


  // Name des Subsystems hinzuf�gen, falls vorhanden
  if ( ValType(objErr:subsystem) == "C" )
    cMessage += objErr:subsystem()
  else
    cMessage += "???"
    end


    // Fehlercode des Subsystems hinzuf�gen, falls vorhanden
    if ( ValType(objErr:subCode) == "N" )
      cMessage += ("/" + NTRIM(objErr:subCode))
    else
      cMessage += "/???"
      end


      // Fehlerbeschreibung hinzuf�gen, falls vorhanden
      if ( ValType(objErr:description) == "C" )
        cMessage += ("  " + objErr:description)
        end


        // Dateiname oder Operation hinzuf�gen
        if ( !Empty(objErr:filename) )
          cMessage += (": " + alltrim(objErr:filename))
        elseif ( !Empty(objErr:operation) )
          cMessage += (": " + alltrim(objErr:operation))
          end


          return (cMessage)


/* Fehlerspeicherungsroutine
*
* speichert den Fehler in Datei: Fehler.dbf (im HauptDatenverz.)
* schickt Nachricht an root !
*
* falls Fehler gefixt werden konnte: erg -> true
*
*/

FUNCTION Fehler(obj)
LOCAL i,Calls:=""
LOCAL aktSel:=Alias()

  if ! Open( "Fehler" )
    return(.f.)
  endif

  // falls Fehler schonmal in den letzten 6 Minuten passiert ist -> keine Benachrichtigung
  go bottom
  if FEHLER->Date==Date() .and. FEHLER->Code==obj:genCode .and. FEHLER->User==getUser():id ;
    .and. seconds() - FEHLER->Mod_Time < 300
    if upper(aktSel) <> "FEHLER"
      close Fehler
    endif
    if ! empty(aktSel)
      select(aktSel)
    endif
    return(.f.)
  endif

  IF ADD_REC(1)
    REPLACE FEHLER->Date WITH Date()
    REPLACE FEHLER->Time WITH Time()
    REPLACE FEHLER->CODE WITH obj:genCODE
    REPLACE FEHLER->DEFAULT WITH obj:canDEFAULT
    REPLACE FEHLER->RETRY WITH obj:canRETRY
    REPLACE FEHLER->SUBSTITUTE WITH obj:canSUBSTITUTE
    REPLACE FEHLER->DESCRIPT WITH obj:DESCRIPTion
    if empty(obj:FILENAME)
      REPLACE FEHLER->FILENAME WITH aktSel
    else
      REPLACE FEHLER->FILENAME WITH aktSel+" -> "+obj:FILENAME
    endif
    REPLACE FEHLER->OPERATION WITH obj:OPERATION
    REPLACE FEHLER->OSCODE WITH obj:OSCODE
    REPLACE FEHLER->SEVERITY WITH obj:SEVERITY
    REPLACE FEHLER->SUBCODE WITH obj:SUBCODE
    REPLACE FEHLER->SYSTEM WITH obj:SubSYSTEM
    REPLACE FEHLER->Tries WITH obj:Tries
    REPLACE FEHLER->User WITH getUser():id
    REPLACE FEHLER->ClientName WITH CLIENT_NAME
    REPLACE FEHLER->UserName WITH USER_NAME
    replace FEHLER->Mod_Time WITH seconds()
    i:=1
    while ( !Empty(ProcName(i)) )
      Calls += Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")" +MY_CR+MY_LF
      i++
      end
      REPLACE FEHLER->Call WITH Calls

    endif

    obj:cargo:="protokolliert !"

  /* Mail an Systemmanager ? */
    Trouble("root", { 'Fehler   : '+obj:Description+" "+obj:filename , ;
      'Operation: '+obj:operation, ;
      'Filename : '+aktSel, ;
      'Code     : '+str(obj:genCode), ;
      "Benutzer :"+getUser():getLongId() } )

    use
    if ! empty(aktSel)
      select (aktSel)
    endif


    return(.f.)

/** creates a new default error object */
FUNCTION createErrorObject(description,fileName,operation,genCode)
LOCAL oResult:=errorNew()
  oResult:genCode:=genCode
  oResult:CanDefault:=.f.
  oResult:CanSubstitute:=.f.
  oResult:CanRetry:=.f.
  oResult:Severity:=ES_ERROR
  if description<>nil
    oResult:Description:=description
  endif
  oResult:fileName:=fileName
  oResult:Operation:=operation
  // oResult:Cargo:=getStackTrace()
return oResult
/** eof */

/** returns the ErrorObject & akt. Stacktrace als mehrzeilgen text f�r Ausgabe/Email */
function getErrorText(objErr)
LOCAL result:="",i
  // result+=objErr:canDEFAULT+MY_CR+MY_LF
  // result+=objErr:canRETRY+MY_CR+MY_LF
  // result+=objErr:canSUBSTITUTE+MY_CR+MY_LF
  result+=objErr:DESCRIPTion+MY_CR+MY_LF
  result+=MY_CR+MY_LF
  result+="FILENAME:  "+objErr:FILENAME+MY_CR+MY_LF
  result+="OPERATION: "+objErr:OPERATION+MY_CR+MY_LF
  result+="genCODE:   "+str(objErr:genCODE)+MY_CR+MY_LF
  result+="OSCODE:    "+str(objErr:OSCODE)+MY_CR+MY_LF
  result+="SEVERITY:  "+str(objErr:SEVERITY)+MY_CR+MY_LF
  result+="SUBCODE:   "+str(objErr:SUBCODE)+MY_CR+MY_LF
  result+=objErr:SubSYSTEM+MY_CR+MY_LF
  // result+=objErr:Tries+MY_CR+MY_LF
  result+=getUser():getLongId()+MY_CR+MY_LF
  result+=CLIENT_NAME+MY_CR+MY_LF
  i:=1
  while ( !Empty(ProcName(i)) )
    result += Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")" +MY_CR+MY_LF
    i++
    end
    return result

/** returns the ErrorObject als mehrzeilgen text f�r Anzeige am BS mit Error() */
function getErrorDispText(objErr)
LOCAL result:=""
  result+=objErr:DESCRIPTion+"|"
  result+="|"
  if objErr:FILENAME<>NIL
    // we take the right hand end in case of a long filename
    result+="FILENAME:  "+alltrim(right(space(60)+objErr:FILENAME,60))+"|"
  endif
  result+="OPERATION: "+objErr:OPERATION+"|"
  result+="genCODE:   "+str(objErr:genCODE)+"|"
  result+="OSCODE:    "+str(objErr:OSCODE)+"|"
  result+="SEVERITY:  "+str(objErr:SEVERITY)+"|"
  result+="SUBCODE:   "+str(objErr:SUBCODE)+"|"
  result+=objErr:SubSYSTEM+"|"
  result+=getUser():getLongId()+"|"
  result+=CLIENT_NAME+"|"
return result

/* lBreak ***
*
* Funktion ist n�tig um Break zu senden
*/
FUNCTION lBreak(objErr)
LOCAL aktSel:=alias()
local fix

  // altd()
  fix:=fixError(objErr)
  if fix != NIL
    return .t.
  endif

  fehler(objErr) // Fehler protokollieren

  // kein Absturz bei Division durch 0
  // we also need this to avoid "Warning W0028  Unreachable code"
  if ( objErr:genCode <> EG_ZERODIV )
    BREAK objErr
  endif

RETURN NIL
/* EOF Break */

/* lBreak ***
*
* Funktion ist n�tig um Break zu senden
*/
FUNCTION ignoreBreak(objErr)

  if 1 > 0 // we need this to avoid "Warning W0028  Unreachable code"
    BREAK objErr
  endif

RETURN NIL
/* EOF Break */

function MyErrorBlock( foo )
  // was for debugging only
  // printStackTrace()
  // altd()
return ErrorBlock( foo )

/**
  * fixed manche Fehler
  */
static function fixError(objErr)
LOCAL aktSel:=Alias()
LOCAL bLastHandler:=MyErrorBlock({ |objErr| defError(objErr) }) // stelle auf default error handler

  // Workaround/Fallbacks for errors which we could avoid:
  do case

    /* nicht selek. Arbeitsbereich */
  case objErr:genCODE==EG_NOALIAS // Error Code 15
    if ! empty(objErr:operation) .and. open(objErr:operation)

      // select or not select new opened file, neu 20160223
      if ! myEmpty( aktSel ) .and. ! inStackTrace( "DBSELECTAREA" )
        select (aktSel)
      endif

      if TEST_PROG .or. DEVEL_PROG
        Error("unbekannter Arbeitsbereich "+objErr:operation,.t.)
      endif
      Trouble("root", { "fixed: "+objErr:Description+" "+objErr:filename+objErr:operation , ;
        "Benutzer:"+getUser():getLongId() } )
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

      return(.t.)
    endif

    /* Datei kann icht erzeugt, werden => Lege temp. Verzeichnisse an */
  case objErr:genCODE==EG_CREATE // Error Code 20
    createTempPaths()
    // Trouble("idx-error", { "fixed: "+objErr:Description+" "+objErr:filename+objErr:operation , 
    // "Benutzer:"+getUser():getLongId() } )
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    return(.t.)


    /* Index corrupted */
    // no auto-fix as it may be a temporary index, so we rather crash instead of reopening w/o it.
    // case objErr:genCODE == EG_CORRUPTION // Error Code 32
    // altd()
    // if ! empty(objErr:filename) .and. right(objErr:filename,4) == indexExt()
    // close (aktsel)
    // ferase(objErr:filename)
    // select Fehler
    // Trouble(BIG_ERROR, { "fixed: "+objErr:Description+" "+objErr:filename+objErr:operation , 
    // "Benutzer:"+getUser():getLongId() } )
    // return(.t.)
    // endif

    /** Data width error shall not crash but inform by email */
    // Info: found no way to recover :(
    // case objErr:genCODE == EG_DATAWIDTH
    // temp:=toString(objErr:operation)

    // Trouble("root", { objErr:Description+" "+objErr:filename+objErr:operation , 
    // "Benutzer:"+getUser():getLongId() } )

    // email(MAIN_EMAIL,"Wert zu gro�: "+ temp + "||Bitte unbedingt �berpr�fen.")


    // return .f.

    /** no exported method, so far missing printJob only */
  case objErr:genCODE==EG_NOMETHOD // Error Code 13

    // printjob accessed but not initialized, we fix it here.
    if getUser():getCurrentPrintJob()==NIL
      getUser():setCurrentPrintJob(DummyJob():new())
      Trouble("root", { "fixed: "+objErr:Description+" DummyJob()" , ;
        "Benutzer:"+getUser():getLongId() } )
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

      return(.t.)
    endif

    // Division durch Null liefert als Vorgabe den Wert Null
  case ( objErr:genCode == EG_ZERODIV )
    Trouble("root", { "fixed: "+objErr:Description+" Div durch 0" , ;
      "Benutzer:"+getUser():getLongId() } )
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    return (0)

    /* zuviele Dateien ge�ffnet ? */
  case objErr:OsCode==4
    close data
    ERROR("Zuviele Dateien ge�ffnet !"+SCHWERER_FEHLER)
    ERROR(INFO_LINE)

  endcase

  MyErrorBlock(bLastHandler) // stelle auf ursprungs handler

return NIL // NIL = not fixed
/** eof */


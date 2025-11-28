/*
* Write some data to benefit from harbour locking
*
* Call w/ json data to be updated, e.g.:
*

.\pymiki.exe "{'inlfdnr':'      153816', 'fert_kw':'15/24' ,'maschnr':'303'}"

* IMPORTANT: use single quotes in json as otherwise they get lost in harbour
*/

#include "mystd.ch"
#include "hbclass.ch"
#include "dbinfo.ch"

#define ERROR_REC_LOCK 1
#define ERROR_DB_OPEN 2
#define ERROR_DB_INDEX 3
#define ERROR_NOT_FOUND 4
#define ERROR_MISSING_PARAM 5
#define ERROR_UNKNOWN 42

#define ATTRIBUTES {"inlfdnr","fert_kw","maschnr"}

PROCEDURE Main(jsonData)
LOCAL attr, hjson, kwDiff

  ErrorBlock({ |objErr| errorPrint(objErr) })

  init_hb()


  if valtype(jsonData) == "U"
    error(ERROR_MISSING_PARAM, "Alle Daten fehlen.")
  endif

  // load json parameters
  hb_jsonDecode(strtran(jsonData,"'",'"'), @hJson )

  // extract attributes
  for each attr in ATTRIBUTES
    if .not. hb_HHasKey(hJson, attr)
      error(ERROR_MISSING_PARAM, attr+" fehlt.")
    endif
  next

  qout("Suche Innerbetr. Auftrag: "+hJson["inlfdnr"]+" -> Maschine: "+hJson["maschnr"])
  if open("Inner","Maschine")
    MASCHINE->(dbSeek(hJson["maschnr"]))
    if MASCHINE->(eof()) .or. MASCHINE->StdNr<>hJson["maschnr"]
      error(ERROR_NOT_FOUND, "Maschine nicht gefunden: "+hJson["maschnr"])
    endif

    select Inner
    INNER->(ordSetFocus(3)) // inLfdNr
    INNER->(dbSeek(hJson["inlfdnr"]))
    if INNER->(eof())
      error(ERROR_NOT_FOUND, "Innerbetr. Auftrag: "+hJson["inlfdnr"]+" nicht gefunden.")
    endif
    qout("InnerNr.: "+INNER->InnerNr+" Masch.Nr: "+INNER->MaschNr)
    kwDiff:=kwDiff(INNER->Fert_KW, hJson["fert_kw"])
    qout("Akt. KW: "+INNER->Fert_KW+" neu: "+hJson["fert_kw"]+" diff: "+str(kwDiff))
    if ! rec_lock()
      error(ERROR_REC_LOCK,"Datensatz konnte nicht gelocked werden.")
    endif
    replace INNER->MaschNr with hJson["maschnr"]
    replace INNER->Fert_KW with kwincr(INNER->Fert_KW, kwDiff)
    replace INNER->Lief_KW with kwincr(INNER->Lief_KW, kwDiff)
    dbcommit()
    dbunlock()
    qout("InnerNr.: "+INNER->InnerNr+" Masch.Nr: "+INNER->MaschNr)
  endif
  close data
RETURN

/** lock row in table */
FUNCTION REC_LOCK()
  IF dbRLOCK()
    RETURN (.T.) // locked
  ENDIF
RETURN .f.



/** Returns a dummy user */
Function getUser()
LOCAL user:=User():new("PY")
return user

/* gibt den string 1:1 zuröck */
FUNCTION ShiftArtikel(artikel)
return artikel


/* gibt empty string zuröck */
FUNCTION getProperty()
return ""

/* gibt den string 1:1 zuröck */
FUNCTION strShift(s)
return s

/* returns true */
FUNCTION Typ_repa
return .t.

/* returns true */
FUNCTION Art_Status
return .t.

/* returns 0 */
FUNCTION BIC_VERIFY
return 0

/** return nil */
Function aendArtBest
return nil

/** dummy empty print job */
CLASS DummyJob
METHOD new()
ENDCLASS

METHOD new()
RETURN NIL

/* öffnet alle Dateien im Array aDatei, s. datei.prg
*
* not supported:
* - non-exclusive
* - TEMP_DATEI 
* - open w/o index
* - reindex
* - open already open datei
*/
FUNCTION db_Open( aDat_open)
LOCAL AktDatei, IndexName, i, Datei

  FOR i:=1 TO len(aDat_open)

    if valtype(aDat_Open[i])=="C"
      Datei:=db_info(aDat_open[i])
      AktDatei:=Datei[D_PFAD]+BACKSLASH+aDat_open[i]
    else
      Datei:=db_info(aDat_open[i,IND_EXPRESSION])
      AktDatei:=Datei[D_PFAD]+BACKSLASH+aDat_open[i,IND_EXPRESSION]
    endif

    default Datei[D_ALIAS]:=Datei[D_NAME]

    dbUseArea( .T. , , AktDatei , Datei[D_ALIAS] , .t. , .f. , "DEWIN" )
    if NETERR()
      error(ERROR_DB_OPEN, "Fehler beim öffnen von: "+Datei[D_ALIAS]+" "+aktDatei)
    endif

    /* öffne zugehör. Indices */
    if Datei[INDEX_BEGIN]<>NIL
      IndexName:=getIndexFullFileName(datei)

      // create index if needed
      if ! File(IndexName)
        error(ERROR_DB_INDEX, "Index-Datei fehlt: "+IndexName)
      endif
      dbSetIndex( IndexName )
    endif

  NEXT

RETURN(.t.)

/** all indiceswerden pro DBF in einer cdx gespeichert */
function getIndexFullFileName(datei)
return Datei[D_PFAD]+BACKSLASH+trim(Datei[D_NAME])+"1"+indexExt()
/** eof */

  REQUEST MY_REQ_RDDI
  REQUEST HB_CODEPAGE_DE850
  REQUEST HB_CODEPAGE_DEWIN
  REQUEST HB_CODEPAGE_DEISO

  REQUEST HB_LANG_DE


PROCEDURE init_hb()
  // select German Language
  hb_langSelect( "DE" )

  // set code page -> windows germany
  set( _SET_CODEPAGE, "DEWIN" )
  hb_setTermCP( "DEWIN" )

  rddSetDefault(MY_RDDI)
  rddInfo( RDDI_MEMOEXT , MY_MEMO_EXTENSION , MY_RDDI )

  SET DELE ON // zeigt zur löschung markierte sötze NICHT

  SET DATE GERMAN // Datum = Deutsch
  SET EPOCH to 1960 // Jahrhundertgrenze !
  Set( _SET_EXACT, .t.) // sucht nach absolut gleichem INDEX !
return

/*
* Drucke Fehler nach std.err. anstatt popup Fenster
*/
FUNCTION errorPrint(objErr)
  error(ERROR_UNKNOWN, getErrorText(objErr))
return .t.

/** returns the ErrorObject & akt. Stacktrace als mehrzeilgen text för Ausgabe/Email */
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
  i:=1
  while ( !Empty(ProcName(i)) )
    result += Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")" +MY_CR+MY_LF
    i++
    end
    return result

/* exits the system */
PROCEDURE error(ErrCode, ErrMess)
  ErrorBlock(NIL)

  default ErrCode:=ERROR_UNKNOWN
  default ErrMess:="unknown"
  qout()
  qout("Error "+alltrim(str(ErrCode))+": ")
  OutErr(ErrMess)
  ErrorLevel( ErrCode )
  quit
return



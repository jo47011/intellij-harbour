/* Modul Datei.prg
*
* handelt alles bzgl. Dateien: �ffnen , reorg etc.
*
*/

#include "MyStd.ch"

#include "error.ch"
#include "dbstruct.ch"
#include "DbInfo.ch"


/* �ffnet alle Dateien im Array aDatei ***
*
* falls Element von aDatei wieder Array:  {  <x> , <x> , { <x> , .t. } , <x> }
* 2. element des "Unter-Arrays" ist logischer Wert f�r Exclusiv-Modus
*
* Parameter:    aDatei       zu �ffnende Dateien (Array)
*               Inidices     mit Indices         (bool)
*
*/
FUNCTION db_Open( aDat_open, warn_on_error )
LOCAL aktSel:=Alias()
LOCAL i,objErr,IndexName
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
LOCAL Datei[INFO_LAENGE] , AktDatei
LOCAL lShared,lWithIndex:=.t.
LOCAL okay,s01,taste, count:=0

  default warn_on_error:=.t.

  FOR i:=1 TO len(aDat_open)

    count++

    lShared:=! set( _SET_EXCLUSIVE )

    if valtype(aDat_Open[i])=="C"
      Datei:=db_info(aDat_open[i])

      /* �ffnen als temp. Datei ? */
      if Datei[D_TEMP] .and. ! procname(1)=="TEMPDATEI"
        lShared:=.f.
        aktDatei:=getTempDateiName( datei )
        if ! file(AktDatei+".dbf")
          /* erstelle Temp. Datei */
          Message("Erstellen der tempor�ren Dateien.  Bitte warten...")
          if ! TempDatei(Datei)
            Error(DATEI_CREATE)
            MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
            RETURN(.f.)
          endif
        endif
      else // normale Datei
        AktDatei:=Datei[D_PFAD]+BACKSLASH+aDat_open[i]
      endif
    else
      Datei:=db_info(aDat_open[i,IND_EXPRESSION])

      /* �ffnen als temp. Datei ? */
      if Datei[D_TEMP] .and. ! procname(1)=="TEMPDATEI"
        lShared:=.f.
        aktDatei:=getTempDateiName( datei )
        if ! file(AktDatei+".dbf")
          /* erstelle Temp. Datei */
          Message("Erstellen der tempor�ren Dateien.  Bitte warten...")
          if ! TempDatei(Datei)
            Error(DATEI_CREATE)
            MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
            RETURN(.f.)
          endif
        endif
      else // normale Datei
        AktDatei:=Datei[D_PFAD]+BACKSLASH+aDat_open[i,IND_EXPRESSION]
        lShared:=! aDat_Open[i,IND_EXCL]
      endif

      // if new flag for opening without index is set, then apply it
      if len(aDat_Open[i])>=IND_WITH_INDEX
        lWithIndex:=aDat_Open[i,IND_WITH_INDEX]
      endif

    endif

    default Datei[D_ALIAS]:=Datei[D_NAME]

    // always reopen exclusive files (added 20160726)
    if select(Datei[D_ALIAS]) >0 .and. ! lShared
      close (Datei[D_ALIAS])
    endif

    if select(Datei[D_ALIAS])==0 // falls noch nicht offen, oder excl. gew�nscht

      BEGIN SEQUENCE // krit. Bereich

        // FIXME: in case an exclusive lock can not be granted a new area will be selected on
        // every try, resulting in alias(x)="" causing problems on Umgebung( WRITE_ALL )
        // OutErr(AktDatei+MY_LF)
        dbUseArea( .T. , , AktDatei , Datei[D_ALIAS] , lShared , .F. , "DEWIN" )
        if NETERR()
          BREAK createErrorObject(DATEI_EXCL,AktDatei,"open file",EG_OPEN)
        endif

        /* �ffne zugeh�r. Indices */
        if lWithIndex .and. procname(1)<>"TEMPDATEI" .and. Datei[INDEX_BEGIN]<>NIL

          IndexName:=getIndexFullFileName(datei)

          // create index if needed
          if ! File(IndexName)
            if ! reindex(Datei)
              BREAK createErrorObject(INDEX_CREATION,Datei[D_NAME],"Index Erzeugung - "+;
                "Netzwerk-Fehler?", EG_OPEN)
            endif
          endif

          okay:=.f.
          s01:=nil

          // FIXME: terminate programm with ESC fails
          // set index
          do while ! okay
            // open index fails while another user is searching with a filter condition
            BEGIN SEQUENCE // krit. Bereich
              dbSetIndex( IndexName )
              okay:=.t.
            RECOVER USING objErr
              if s01==NIL
                s01:=savescreen()
              endif
              keyboard ""
              taste:=INKEY(.5) // warte 1/2 second
              ERROR("Index: "+IndexName+" wird schon benutzt.|Bitte warten ..." ,ERR_NO_WAIT)
              if ABBRUCH
                break objErr
              endif
              END
            enddo
            if s01<>NIL
              restscreen(,,,,s01)
              // FXIME: disabled 20240212
              // if type("M->qtWidget")<>"U" // we use QT currently
              // qtError() // close MessageBox
              // endif

            endif
          endif
        RECOVER USING objErr
          MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

          if .not. warn_on_error
            return .f.
          endif

        /* falls kein Error-Objekt �bergeben: Abbruch indiziert */
          if ! valtype(objErr)=="O"
            Error("Kein Error-Objekt �bergeben"+SCHWERER_FEHLER)
            RETURN(.f.)
          endif

          IF ! file(AktDatei+".dbf")
            if Datei[D_TEMP]
              if procname(1)=="TEMPDATEI"
                Error(aktdatei+DATEI_EXIST)
                RETURN(.f.)
              endif
            /* erstelle Temp. Datei */
              Message("Erstellen der tempor�ren Dateien.  Bitte warten...")
              if ! TempDatei(Datei)
                Error(DATEI_CREATE)
                RETURN(.f.)
              endif
              MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
              i-- // dasselbe nochmal (max. 2x)
              loop
            else
              Error(AktDatei+DATEI_EXIST)
            endif
            if select(aktSel)>0
              select(aktSel)
            endif
            RETURN(.f.)

          elseif select(Datei[D_ALIAS]) >0 // Index-Fehler?
            close (Datei[D_ALIAS])
            Error("Fehler: "+objErr:description+"|"+Datei[D_ALIAS]+"->"+objErr:operation+;
              SCHWERER_FEHLER)
            RETURN(.f.)

          else

            if s01==NIL
              s01:=savescreen()
              fehler(objErr)
            endif
            ERROR(AktDatei+DATEI_EXCL_WARTE)
            keyboard ""
            taste:=INKEY(.5) // warte 1/2 second
            if s01<>NIL
              restscreen(,,,,s01)
            endif
            if ABBRUCH .or. (count > 72 .and. getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN)
              if select(aktSel)>0
                select(aktSel)
              endif
              if ! ABBRUCH
                TroubleEmail(aktDatei+" Server Abbruch - Bitte pr�fen")
              endif
              MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
              RETURN(.f.)
            else
              i-- // dasselbe nochmal
              loop
            endif
          endif

        END Sequence

      else
      /* Datei schon offen, selektiere */
        select (Datei[D_ALIAS])

        // todo: vorher Abfrage ob Lock-Status bereits stimmt w�re effektiver, n2h

        // raus am 3.2.2011
        // if lshared
        // unlock
        // else
        if !lshared
          fil_lock(5)
        endif
      endif

      count:=0

    NEXT

    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    RETURN(.t.)
/* Ende Func Open */





/* Reorganisation
*
*  Dauer: @home:          110 sec
*         @miki/win:      304 sec
*
*
*  Result: .t. wenn okay ansonsten .f.
*/
Function Reorg(Abfrage)
LOCAL Best:=0
LOCAL i, Datei[INFO_LAENGE]
LOCAL alle_Dateien:=getAllDBNames()
LOCAL ant:="A" // default Alle reorganisieren
LOCAL AusNum,taste,time
LOCAL Auswahl:=getAllDBSections()
LOCAL s01:=savescreen()

  default abfrage:=.t.

  close data // schlie�en aller Dateien !
  cls
  titel("R E O R G A N I S A T I O N")

  if Abfrage .and. len(Auswahl)>1
    Message("Teilbereich ausw�hlen.       @ESC@=Ende")
    @ 5,28 to 15,52
    for i:=1 to len(Auswahl)
      @ 5+i,30 prompt left(Auswahl[i,1]+space(20),20)
    next
    menu to AusNum
  else
    AusNum=1
  endif

  if AusNum==0
    cls
    close data
    restscreen(,,,,s01)
    RETURN .F.
  endif

  if getUser():isBackgroundTask
    ant:="A" // Alle
  elseif DEVEL_PROG
    ant:="J" // Best�tigung erw�nscht
  endif

  // start
  time:=seconds()

  // we now use the system.dbf as Semaphore to prevent other users from logging in
  if ! open({"System",.t.})
    cls
    close data
    restscreen(,,,,s01)
    RETURN .F.
  endif

  // now start reorg
  for i:=1 to len(alle_Dateien)
    Datei:=db_info(alle_Dateien[i])

    // nothing to do for system.dbf (no index) and is used as Semaphore
    if Datei[D_NAME]=="SYSTEM"
      loop
    endif

    /* nur Auswahl */
    if Auswahl[ausNum,1]=="Gesamt" .or. Datei[D_PFAD]=Auswahl[ausNum,2]
      /* Falls keine temp. Datei */
      if ! Datei[D_TEMP]

        if DEVEL_PROG .and. ! ant $ "A" // wenn nicht alle
          ant:=Message("Reorg:"+Datei[D_NAME]+"  ?  ( @J@a / @N@ein / @Q@uit / @A@lle )","JNQA")
          Message()
          if ant=="Q"
            cls
            close data
            restscreen(,,,,s01)
            RETURN .t.
          endif
        endif
        if ant $ "JA"
          Message("Bitte warten...    @ESC@=Ende")
          if open( { Datei[D_NAME] ,.t.,.f. } ) // �ffnen der Datei, excl. und ohne index!

            @ 16,21 say "Datei: "+ alias() + ".dbf wird gepackt.   "
            pack

            /* SonderFall Info-Text */
            if Datei[D_NAME]=="INFO"
              go top
              do while .not. eof()
                if empty(MEMOTRAN(INFO->Text,"@","@")) // ersetzt Chr(13) durch @
                  delete
                endif
                skip
              enddo
            endif

            /* Datei wieder schliesen */
            use

            /* l�sche Index Datei -> reindex wird erzwungen */
            ferase(getIndexFullFileName(Datei))

            /* �ffnen und Neu-Indizierung */
            open( Datei[D_NAME] ) // �ffnen & automat. Neubildung der Indices
            use

          endif // open

          taste:=inkey()
          if ABBRUCH
            if Message("Reorg wirklich abbrechen?  @J@/@N@","JN")=="J"
              exit
            endif
          endif
        endif
      endif
    endif
    close (Datei[D_NAME]) // Datei wieder schlie�en
  NEXT

  close data // System.dbf

  if DEVEL_PROG .and. ! getUser():isBackgroundTask
    Message("Reorg beendet.   Bitte @Taste@ drucken.  Zeit (sec):"+str(seconds()-time),"@")
  endif


  // MyDel(TEMP,"\*.*" )

  Beep(1)
  restscreen(,,,,s01)

RETURN .t.
/* End of Proc Reorg */


/* Func ReIndex ***
*
* reindiziert Index der �bergebenen Datei
*
* Parameter:    Datei, IndexNr
*/
static FUNCTION ReIndex(Datei)
LOCAL IndexName,MyTag,IndexNr
LOCAL s001:=savescreen()

  IndexName:=getIndexFullFileName(Datei)
  if ! fil_lock()
    BREAK;
      createErrorObject(INDEX_CREATION,Datei[D_NAME],"Index: "+str(IndexNr-INDEX_BEGIN+1)+;
      " File-Lock", EG_OPEN)
  endif

  for IndexNr:=INDEX_BEGIN to INDEX_BEGIN+INDEX_MAX-1

    if ! Datei[D_TEMP] .and. ! getUser():isBackgroundTask
      @ 16,20 clear to 17,75
      @ 17,21 say str(IndexNr-INDEX_BEGIN+1,1)+". Index"
    endif

    myTag:=trim(left(Datei[D_NAME],8))+alltrim(str(IndexNr-INDEX_BEGIN+1,2))

    // FIXME: Index erzeugen mit OrdCondSet, support for IND_TAG missing
    // s. Hilfe#sortByColumn() for example

    if Datei[IndexNr]==NIL // kein Index mehr definiert
      exit
    elseif valtype(Datei[IndexNr])=="C" // normaler Index
      index on &(Datei[IndexNr]) TAG &(MyTag) to &(IndexName) eval IndexProz(IndexNr-INDEX_BEGIN+1);
        every lastrec()/20
    elseif valtype(Datei[IndexNr])=="A" // Index mit Sonderfunktion z.B. for clause
      if valtype(Datei[IndexNr,2])=="C" .and. Datei[IndexNr,2]==D_DESCENDING
        index on &(Datei[IndexNr,1]) TAG &(MyTag) to &(IndexName) eval IndexProz(IndexNr-INDEX_BEGIN+1) ;
          every lastrec()/20 DESCENDING
      elseif valtype(Datei[IndexNr,2])=="C" .and. Datei[IndexNr,2]==D_UNIQUE
        index on &(Datei[IndexNr,1]) TAG &(MyTag) to &(IndexName) eval IndexProz(IndexNr-INDEX_BEGIN+1) ;
          every lastrec()/20 UNIQUE
      else // FOR clause, added 10.7.2012
        index on &(Datei[IndexNr,1]) TAG &(MyTag) to &(IndexName) eval IndexProz(IndexNr-INDEX_BEGIN+1);
          every lastrec()/20 For &(Datei[Indexnr,2])
      endif
    else // falsche Index Def.
      BREAK createErrorObject(INDEX_CREATION,Datei[D_NAME],"Index: "+str(IndexNr-INDEX_BEGIN+1)+;
        " Definition?",EG_OPEN)
    endif
  next

  set index to
  if ! Datei[D_TEMP]
    go bottom
    IndexProz()
  endif
  dbcommit()
  unlock

  restscreen(,,,,s001)
RETURN( ! NetErr() )
/* EOF ReIndex */




/* IndexProz **
*
* zeigt die aktuelle Prozentzahl des Index an
*/
FUNCTION IndexProz(Nr)
LOCAL cComplete:=if(lastrec()>0,str((recno()/lastrec()) * 100 ,3),"100")
  @ 15,19 clear to 18,60
  @ 15,19 to 18,60
  @ 16,21 say "Datei: "+ alias() + ".dbf wird reorganisiert"
  if nr<>nil .and. valtype(nr)=="N"
    @ 17,21 say "Index Nr: "+alltrim(str(Nr))
  endif
  @ 17,35 say "Indiziert: "+cComplete+" %"
RETURN(.t.)




/* Satz_Neu
*
* neuen Satz an Datei hinzuf�gen
*
* Parameters: aDatei     A      // Datei-Infoarray
*             cIndex     C      // �bergabe des Index-Feldes (Inhalt !)
*/
FUNCTION Satz_Neu( aDatei , cInDex )

  Umgebung(WRITE)
  select (aDatei[D_NAME])

  IF ! ADD_REC(5)
    ERROR(aDatei[D_NAME]+DATEI_EXCL)
    Umgebung(LOAD)
    RETURN(.f.)
  ENDIF

  if procname(1)=="AEND" // kommt aus �nderungsprog.
    @ 3,0 clear
  else // sonst Fenster aufmachen
    setcolor(COLWIN)
  endif

  /* Default-Feld f�r Index: 1. Feld ! */
  // REPLACE &(getKeyFieldName(adatei)) WITH cIndex
  (aDatei[D_NAME])->(fieldPut(getKeyFieldPos(aDatei),cIndex))

  /** eval special function on new record if applicable */
  if valtype(aDatei[D_NEW_REC_CODEBLOCK])=="B"
    eval(aDatei[D_NEW_REC_CODEBLOCK])
  endif

  if valtype(aDatei[D_DISP])=="C"
    &(aDatei[D_DISP])(.t.,.f.) // neuen Satz erfassen ohne Sperren
  endif
  dbcommit()
  dbunlock() // added 20161117

  Umgebung(LOAD)
RETURN(.t.)



/* Function Check ***************************************
*
* kontrolliert ob Datensatz mit �bergegebem Schl�ssel existiert,
* falls nicht Abfrage: Aufnehmen j/n
*
*
* PARAMETER:    oGet            akt. Get-Objekt
*               cDatei          DateiName in der zu checken ist
*               leer(boolean) , ob Leersatz erlaubt ! Default:=.t.
*               neuSatz(bool) , ob neuen Satz aufnehmen m�glich, default:=.t.
*               VorIndex(Char), enthaelt evtl. vorIndex-Feld z.B. bei Prod.dbf:Typ+GeratNr
*
*/


FUNCTION check(oGet,cDatei,leer,NeuSatz,VorIndex)
LOCAL akt_sel:=select()
LOCAL lang, okay:=.f.
LOCAL zw_erg,s01
LOCAL aDatei[INFO_LAENGE]
  default leer:=.t.
  default NeuSatz:=.t.
  default VorIndex:=""

  aDatei:=db_info(cDatei) // suche zugeh�r. Datei

  // check whether user may add a record here
  if neusatz .and. valtype(aDatei[D_NEW_REC_ALLOWED])=="B"
    neuSatz:=eval(aDatei[D_NEW_REC_ALLOWED])
  endif

  // check wheter record is empty and if this is allowed
  if ( leer .and. (empty(oget:buffer) .or. eval(aDatei[D_REC_EMPTY],oget:buffer)) ) // leeres Feld
    RETURN(.t.)
  endif

  // zur�ck erlaubt
  if chr(lastkey()) $ LEAVE_CHECK .and. ! inStackTrace("checkForceValid")
    // undo neu seit 12.1.2010
    oGet:undo()
    RETURN(.t.)
  endif

  // leere Eingabe nicht m�glich !
  if (empty(oget:buffer) .or. eval(aDatei[D_REC_EMPTY],oget:buffer))
    if getProperty("System.popup.help","J")=="J"
      Keyboard chr(HILFE_TASTE1)
    endif
    RETURN(.f.)
  endif


  // shiften oder auff�llen
  do case
    case ADatei[D_ART]=="N" // Nullen links auff�llen */
    if len(trim(oget:buffer))<len(oget:buffer)
      lang:=len(oGet:buffer)
      oget:varput(right("0000000"+alltrim(oget:buffer),lang))
      oGet:updateBuffer()
    endif
    case ADatei[D_ART]=="R" // Nullen rechts auff�llen */
    if len(trim(oget:buffer))<len(oget:buffer)
      lang:=len(oGet:buffer)
      oget:varput(left(alltrim(oget:buffer)+"0000000",lang))
      oGet:updateBuffer()
    endif
    case ADatei[D_ART]=="S" // SHIFT_CHAR (i.d.R Space) links auff�llen */
    if len(trim(oget:buffer))<len(oget:buffer)
      shift(oGet)
    endif

  case ADatei[D_ART]=="A" // custom shift block
    if valtype(aDatei[D_NEW_REC_SHIFT])=="B"
      oget:varput(eval(aDatei[D_NEW_REC_SHIFT],oget:buffer))
    else
      TroubleEmail(aDatei[D_NAME]+" kein shift code block definiert")
    endif
    oGet:updateBuffer()

    // Rep.Kunde (Honsel) unscheon jojo :(
  case ADatei[D_ART]=="H"
    if len(trim(left(oget:buffer,7)))<7
      lang:=7
      oget:varput(right("0000000"+alltrim(left(oget:buffer,7)),lang)+"-"+right(oGet:buffer,2))
      oGet:updateBuffer()
    endif
  endcase

  open( ADatei[D_NAME] )
  if empty(vorindex)
    dbSeek(oGet:buffer)
  else
    dbSeek(vorindex+oGet:buffer)
  endif
  // Datensatz nicht gefunden
  if eof()

    // alternative Suche definiert?
    if sucheAlternativeNummer(aDatei,oget:buffer)
      zw_erg:=getKeyFieldValue(adatei)
      select &akt_Sel
      oget:varput(zw_erg)
      oGet:updateBuffer()
    else
      // Datensatz nicht gefunden
      if ! NeuSatz
        Error(ACHTUNG+oGet:buffer+NICHT_VORHANDEN)
        select &akt_Sel
        RETURN(.f.)
      endif
      beep()
      s01:=savescreen()
      if Message(ADatei[D_KURZ]+;
        " nicht vorhanden.  Neuen Datensatz aufnehmen ? ( J / N ) ","JN")=="J"
        Message()
        zw_erg:=Satz_Neu(aDatei,oGet:buffer)
        select &akt_Sel
        restscreen(,,,,s01)
        RETURN(zw_erg)
      else
        Message()
        select &akt_Sel
        restscreen(,,,,s01)
        RETURN(.f.)
      endif
    endif
  endif

  select &akt_Sel

RETURN(.t.)
/** eof */

/** sucht in aktueller Datei nach aDatei[D_ALT_SEARCH],
result=.t. wenn Treffer und steht auf gefundenem Datensatz */
FUNCTION sucheAlternativeNummer(aDatei,nr,Abfrage)
LOCAL s01,aktSel:=alias(),result:=.f., taste:=0
LOCAL aktRec

  if valtype(aDatei[D_ALT_SEARCH])=="B"

    default Abfrage:=.t.

    select (aDatei[D_NAME])
    aktRec:=recno()
    s01:=savescreen()
    Message("Alternative Nummer wird gesucht.   Bitte warten...   @ESC@=Ende")
    go top
    do while taste <> K_ESC .and. ! eof() .and. ! result:=(eval(aDatei[D_ALT_SEARCH],nr))
      taste:=inkey()
      skip
    enddo

    // gefunden
    if result .and. Abfrage
      if Message("Neue "+ aDatei[D_KURZ]+" Nr. @"+getKeyFieldValue(adatei)+;
        "@ gefunden.   Diesen Datensatz verwenden? (@J@/@N@)","JN"," ")<>"J"
        result:=.f.
      endif
    endif
    dbgoto(aktRec)
    select (aktSel)

    restscreen(,,,,s01)
  endif
RETURN result
/** eof */



/* Procedure Close
*
* schliest die im Array: aDatei �bergebenen Dateien
* falls aDatei leer ist, schliese alle
*/
PROCEDURE Close_Only(aDatei)
LOCAL i
LOCAL Akt_Datei:=select()

  for i:=1 TO len(aDatei)

    if select(aDatei[i]) > 0
      (aDatei[i])->( dbcloseArea() )
    endif
  next

  select &Akt_Datei

RETURN




/*
* l�schen aller Datens�tze aus �bergebener Datei f�r die die Bedingung erf�llt
*/
FUNCTION myDelete(Org_Datei, Bedingung)
LOCAL AktSel:=alias()
LOCAL i:=1

  if valtype(Bedingung)=="U"
    TroubleEmail("Function delete: undefined Bedingung!")
    return .f.
  endif

  select (Org_Datei)
  do while ! eof() .and. eval(Bedingung)
    rec_lock(0)
    delete
    skip
  enddo

  select (aktSel)
RETURN(.t.)
/* EOF */


/*
*
* anh�ngen aller Datens�tze aus �bergebener Datei ab dortiger Position oder top falls angegebn
* und solange Bedingung erf�llt
* -> nach akt. selektierte Datei
*
* Struktur muss identisch sein !
*
* Parameter: Quell_Datei,Bedingung,
*/
FUNCTION append(Org_Datei, Bedingung, fuzzy)
LOCAL Neu:=alias()
LOCAL i:=1 , Quelle

  default Bedingung:={ || .t.}
  default fuzzy:=.f.

  select (Org_Datei)
  do while ! eof() .and. eval(Bedingung)
    select (Neu)
    if ! add_rec(5)
      Error(Neu+DATEI_EXCL)
      RETURN(.f.)
    endif
    for i:=1 to fcount()
      if ! "/"+fieldname(i)+"/" $ INTERNAL_SYS_FIELDS
        Quelle:=Org_Datei+"->"+fieldname(i)
        if (.not. fuzzy) .or. (Org_Datei)->(fieldpos((NEU)->(fieldname(i)))) > 0
          replace &(fieldname(i)) with &(Quelle)
        endif
      endif
    next
    select (Org_Datei)
    skip
  enddo

  select (neu)
RETURN(.t.)
/* EOF */



/*
* �berschreibt akt. Datensatz mit Datensatz aus �bergebener Datei
*
* Struktur muss identisch sein oder fuzzy muss .t. sein
*
* Parameter: Quell_Datei
*/
FUNCTION overwrite(Org_Datei,fuzzy)
LOCAL i, Quelle,feldName

  default fuzzy:=.f.

  for i:=1 to fcount()
    feldName:=fieldname(i)
    if ! "/"+feldName+"/" $ INTERNAL_SYS_FIELDS
      Quelle:=Org_Datei+"->"+feldName
      if &(Org_Datei)->(fieldpos(feldName))==0
        if ! fuzzy
          Error(ACHTUNG+Org_Datei+"->"+feldName+" existiert nicht.",.t.,"root")
        endif
      else
        replace &(feldName) with &(Quelle)
      endif
    endif
  next

RETURN(.t.)
/* EOF overwrite */

/* liefert alle Felder/Fields des akt. Datensatz in einem Array (gleiche Order) zur�ck
*/
FUNCTION getCurrentValues() // alle Fields, Felder einer DB, saveAllFields()
LOCAL i, result:={}

  for i:=1 to fcount()
    aadd(result,fieldget(i))
  next

RETURN result
/* EOF overwrite */

/* Function setCurrentValues()
*
* setzt alle Felder des akt. Datensatz auf die Werte des Arrays (gleiche Order)
  * siehe getCurrentValues()
*
*/
FUNCTION setCurrentValues(values)
LOCAL i

  for i:=1 to fcount()
    fieldPut(i,values[i])
  next

RETURN .t.
/* EOF */



/* 
* Parameter:   aDatei: Anlegen der ben�tigten temp. Datei
*              ""    : l�schen aller temp. Dateien des akt. Benutzers
*
* R�ckgabe:   .t. falls erfolgreich
*
* Achtung :  merkt in Datei.prg (open) automat. , da� hier Orginal-Datei gew�nscht
*            deshalb Prozedurname NICHT �ndern !
*/
FUNCTION TempDatei(Datei)
LOCAL i
LOCAL Temp:="",schon_offen:=.f.
LOCAL alle_Dateien

  if len(Datei) > 0

    /**** erstellen der ben�tigten temp. Datei ****/

    if Datei[D_TEMP]
      temp:=getTempDateiName( datei )

      if ! mkMyDir(TEMP_USER)
        return .f.
      endif

      if Datei[D_TEMP_ERASE] .or. ! file(temp+".dbf")
        if valtype(Datei[D_TEMP_STRU])=="C"
          schon_offen:=( select(Datei[D_TEMP_STRU]) >0 )
          if ! open(Datei[D_TEMP_STRU]) // Struktur-Datei
            RETURN(.f.)
          endif
        else
          schon_offen:=( select(Datei[D_NAME]) >0 )
          if ! open(Datei[D_NAME]) // merkt automat.,da� hier Orginal-Datei gew�nscht
            RETURN(.f.)
          endif
        endif
        copy stru to (temp)
        if ! schon_offen
          dbcloseArea()
        endif
      endif
    endif

  else

    alle_Dateien:=getAllDBNames()
    /* l�schen aller temp. Dateien */
    for i:=1 to len(alle_Dateien)
      if alle_Dateien[i]==NIL
        TroubleEmail("Komma zu viel in ALLE_DATEIN bei Stelle:"+str(i))
      else
        Datei:=db_info(alle_Dateien[i])
        if Datei[D_TEMP] .and. Datei[D_TEMP_ERASE]
          if file(getTempDateiName( datei )+".dbf")
            // ACHTUNG: nimmt hier TEMP_DATEI_NAME auseinandenr
            // l�sche auch zugeh. Indices:
            mydel( getBaseName( getTempDateiName( datei ) ) , getFileName( getTempDateiName( datei;
              )+"*.*" ) )
          endif
        endif
      endif
    next


    ferase( LISTEN_AUS )
    ferase( TEMP_FILE )
    ferase(TEMP_PROTOKOLL)

    // FIXME: we delete all users's temp files here due to concurrency issues using shellexecute
    // myDel(TEMP,getUser():id+"*.*")

  endif

RETURN(.t.)
/* EOF tempDatei */






  // ***
  // REC_LOCK function (alt)
  //
  // Trys to lock the current record
  // Pass the following parameter
  // 1. Numeric - seconds to warte (0 = warte forever)
  // 2. addRecno - if specified the passed record number is locked ADDITIVE
  // if not specified all other locks of this area are released before (see dbrlock(...))
  //
  // Note: us dbRunlock instead of dbunlock to just release one lock!!!

FUNCTION REC_LOCK( warte , addRecno)
LOCAL s001:=savescreen()
LOCAL t:=0,field
LOCAL forever,interr:=.f.

  // changed on 9.7.2012
  // IF RLOCK()
  // writeModData()
  // RETURN (.T.) // locked
  // ENDIF

  forever = (warte = 0)
  DO WHILE (forever .OR. t<>27)

    IF dbRLOCK(addRecno)
      if interr
        restscreen(,,,,s001)
      endif
      writeModData()
      RETURN (.T.) // locked
    ENDIF

    t=INKEY(.5) // warte 1/2 second
    if field == nil
      field:=toString( fieldget(1) )
    endif
    if warte = 0
      ERROR("Datei: "+Alias()+": "+field+;
        "||Datensatz wird schon benutzt.|Bitte warten ..." ,ERR_NO_WAIT)
    else
      ERROR("Datei: "+Alias()+": "+field+"||Datensatz wird schon benutzt.|Bitte warten ...||ESC = "+;
        "Abbruch", ERR_NO_WAIT)
    endif
    interr=.t.

  ENDDO
  if interr
    restscreen(,,,,s001)
    // FXIME: disabled 20240212
    // if type("M->qtWidget")<>"U" // we use QT currently
    // qtError() // close MessageBox
    // endif
  endif
RETURN (.F.) // not locked
  // End - REC_LOCK

  // ***
  // FIL_LOCK function (alt)
  //
  // Trys to lock the current database
  // Pass the following parameter
  // 1. Numeric - seconds to warte (0 = warte forever)
  //

FUNCTION FIL_LOCK(warte)
LOCAL s001:=savescreen()
LOCAL t:=0
LOCAL forever,interr:=.f.

  // changed on 9.7.2012
  // IF FLOCK()
  // RETURN (.T.) // locked
  // ENDIF

  forever = (warte = 0)
  DO WHILE (forever .OR. t<>27)

    IF FLOCK()
      if interr
        restscreen(,,,,s001)
      endif
      RETURN (.T.) // locked
    ENDIF

    t=INKEY(.5) // warte 1/2 second

    ERROR(alias()+DATEI_EXCL_WARTE)
    interr=.t.

  ENDDO
  if interr
    restscreen(,,,,s001)
  endif
RETURN (.F.) // not locked
  // End - FIL_LOCK





  // ***
  // ADD_REC function (alt)
  //
  // Returns true if record appended. The new record is current
  // and locked.
  // Pass the following parameter
  // 1. Numeric - seconds to warte (0 = warte forever)
  //

  // FIXME: warte is not really used (seconds are ignored)lock,fil_lock
// see -> waitperiod...
FUNCTION ADD_REC( warte , lUnlockRecords )
LOCAL s001:=savescreen()
LOCAL t:=0
LOCAL forever,interr:=.f.

  // changed on 9.7.2012
  // APPEND BLANK
  // IF .NOT. NETERR()
  // if alias()<>"FEHLER"
  // writeModData()
  // writeCreaData()
  // endif
  // RETURN (.T.)
  // ENDIF

  forever = (warte = 0)
  DO WHILE (forever .OR. t<>K_ESC)

    dbAppend( lUnlockRecords )
    IF .NOT. NETERR()
      if interr
        restscreen(,,,,s001)
      endif

      // added on 9.7.2012, debugging might be removed in future
      // check whether append blank really added a new plain record
      // FIXME: check if empty(fieldget(1)) works for non character fields
      if fieldType(1)=="C" .and. ! empty(cStr(fieldget(1)))
        Trouble("root","Append on non empty record:"+alias()+"->"+str(recno())+": "+;
          cStr(fieldget(1)))
        // return .f.
        // Try again
        dbunlock()
        dbskip(0)
        loop
      endif

      if alias()<>"FEHLER"
        writeModData()
        writeCreaData()
      endif
      RETURN .T.
    else // NetErr()
      Trouble("root","NetError on append record:"+alias())
    ENDIF

    t:=Inkey(.5) // warte 1/2 second

    error(Alias()+DATEI_EXCL_WARTE)
    interr=.t.

  ENDDO
  if interr
    restscreen(,,,,s001)
  endif
RETURN (.F.) // not locked
  // End ADD_REC



/**
 * schreibt alle strukturen der benutzen DBASE-DAteien nach "Doku.asc"
 * lesbares Format zum nachschauen
*/

Function DB_DokExp()
LOCAL allDBF:=getAllDBNames()
LOCAL dbstruct,i,j,datei,zeile:=0

  cls
  titel("Datei Struktur Export")
  set cons off
  set alte to doku.asc
  set alte on
  qqout( 'Dokumentation vom',date() )
  qout( '==========================')
  qout( )
  for i:=1 to len(allDBF)
    Message("Bitte warten: "+allDBF[i])
    datei:=db_info(allDBF[i])
    // qout(open(allDBF[i])))
    if ! open({ allDBF[i] , .f. , .f.})
      qout( upper(datei[D_PFAD])+BACKSLASH+allDBF[i]+" konnte nicht ge�ffnet werden.")
    else
      dbstruct:=dbstruct()
      qout( "Datei:  "+upper(datei[D_PFAD])+BACKSLASH+allDBF[i]+".dbf")
      qout( "------")
      qout( "Feld     FeldName    Typ  L�nge   Dez")
      for j:=1 to len(dbstruct)
        qout( str(j,3),space(4),left(dbstruct[j,DBS_NAME]+;
          space(12),12),dbstruct[j,DBS_TYPE], str(dbstruct[j,DBS_LEN],6),;
          str(dbstruct[j,DBS_DEC],5))
      next
    endif
    qout( "-------------------------------------------------")
    qout()
    close data
  next
  set alte off
  close alte
  Message("Doku.asc erstellt.     Bitte @Taste@ dr�cken.","@")

  cls
return .t.
/** eof */

/**
 * DB_DokStru     schreibt alle strukturen der benutzen DBASE-DAteien nach "Stru.asc"
    *
    * maschinen-lesbares Format zum automat. erzeugen
*/

Function DB_StruExp()
LOCAL allDBF:=getAllDBNames()
LOCAL dbstruct,i,j,datei,zeile:=0

  cls
  titel("Datei Struktur Export")
  set cons off
  set alte to stru.asc
  set alte on
  qqout( 'Generiert am',date() )
  qout( '=======================')
  qout( )
  for i:=1 to len(allDBF)
    Message("Bitte warten: "+allDBF[i])
    datei:=db_info(allDBF[i])
    // qout(open(allDBF[i])))
    if ! open(allDBF[i])
      qout( upper(datei[D_PFAD])+BACKSLASH+allDBF[i]+" konnte nicht ge�ffnet werden.")
    else
      dbstruct:=dbstruct()
      qout( "Datei:  "+upper(datei[D_PFAD])+BACKSLASH+allDBF[i]+".dbf")
      qout( "------")
      qout('tempVal:="'+allDBF[i]+'"')
      qout('datei:=db_Info(tempVal)')
      qout('tempArray:={;')
      for j:=1 to len(dbstruct)
        qout('{"'+dbstruct[j,DBS_NAME]+'","'+dbstruct[j,DBS_TYPE]+'",'+str(dbstruct[j,DBS_LEN],6)+','+;
          str(dbstruct[j,DBS_DEC],5)+'}')
        if j==len(dbstruct)
          qqout('}')
        else
          qqout(',;')
        endif
      next
      qout("myDBcreate(upper(datei[D_PFAD])+BACKSLASH+tempVal+'.dbf',tempArray)")
      qout()
    endif
    close data
  next
  set alte off
  close alte
  Message("Stru.asc erstellt.     Bitte @Taste@ dr�cken.","@")

  cls
return .t.
/** eof */


/** PROCEDURE dumpFile()
*
* druckt den kompletten Inhalt der Datei als Replace Parameter
*/
PROCEDURE dumpFile(exportPath)
LOCAL GetList:={}
LOCAL Message:="", DateiName:=space(10),dbstruct
LOCAL Zeile:=0,j

  cls
  titel("Datei dumpen")
  @ 10,20 say "ACHTUNG !"
  @ 12,20 say "zu dumpende Datei:" get DateiName
  read
  DateiName:=trim(dateiName)
  if ! ABBRUCH
    if ! open(dateiName)
      Error(TRY_AGAIN)
    else
      mkMyDir(exportPath)
      dbstruct:=dbstruct()
      set alte to (exportPath+BACKSLASH+trim(dateiName)+".txt")
      set alte on
      qout( "//Datei:  "+dateiName)
      qout( "//------")
      go top
      do while ! eof()
        qout( "add_rec(0)")
        for j:=1 to len(dbstruct)
          do case
          case dbstruct[j,DBS_TYPE]=="N"
            if fieldget(j)<>0
              qout( "  replace "+upper(trim(dateiName))+"->"+lower(dbstruct[j,DBS_NAME])+" with "+;
                str(fieldget(j),dbstruct[j,DBS_LEN],dbstruct[j,DBS_DEC]))
            endif
          case dbstruct[j,DBS_TYPE]=="D"
            qout( "  replace "+upper(trim(dateiName))+"->"+lower(dbstruct[j,DBS_NAME])+" with ctod('"+dtoc(fieldget(j))+"')")
          case dbstruct[j,DBS_TYPE]=="C"
            if ! empty(fieldget(j))
              qout( "  replace "+upper(trim(dateiName))+"->"+lower(dbstruct[j,DBS_NAME])+;
                " with '"+trim(fieldget(j))+"'")
            endif
          otherwise
            qout( "  replace "+upper(trim(dateiName))+"->"+lower(dbstruct[j,DBS_NAME])+;
              " with UNKNOW TYPE:"+dbstruct[j,DBS_TYPE])
          endcase
        next
        qout( "//-------------------------------------------------")
        skip
      enddo
    endif
  endif
  Message("Datei: "+exportPath+BACKSLASH+trim(dateiName)+".txt"+;
    " erstellt.          Bitte @Taste@","@")
  cls
  close alte
  close data
RETURN
/* EOP delete */

/** Macht ein backup falls Datei existiert und ruft dbcreate auf */
Procedure MyDbCreate(Datei,Structure)
  if file(Datei+".dbf")
    backup( getFileName(Datei) )
    deleteTempFiles()
    ferase(Datei + MY_MEMO_EXTENSION)
    ferase(Datei+".dbf")
    ferase(getIndexFullFileName( db_info( getFileName(Datei) ) ))
  endif
  Message(Datei+" wird erzeugt.")
  dbcreate(Datei,Structure)
return

/** Macht ein backup falls Datei existiert und l�scht diese danach
 */
Procedure MyDbDelete(Datei,Pfad)
  Message("Datei:"+Datei+" wird gel�scht.  @Bitte warten@")
  // backup(Datei)
  copy file &(Pfad+BACKSLASH+datei+".dbf") to &(Pfad+BACKSLASH+datei+".old")
  ferase(Pfad+BACKSLASH+datei+".dbf")
  myDel(Pfad,datei+"*"+indexExt())

  if file( Pfad + BACKSLASH + datei + MY_MEMO_EXTENSION)
    copy file (Pfad + BACKSLASH + datei + MY_MEMO_EXTENSION ) to &(Pfad+BACKSLASH+datei+".dt2")
    ferase(Pfad+BACKSLASH+datei + MY_MEMO_EXTENSION )
    myDel(Pfad,datei+"*"+ MY_MEMO_EXTENSION )
  endif

  deleteTempFiles()
return

/** erzeugt eine vorhanden DBF Datei neu und kopiert die Daten.
 * kann bei korrupten Dateien helfen
 */
Procedure reCreate(datei)
LOCAL dbinfo:=db_info(datei)
local DateiDat:=TEMP+BACKSLASH+"tempDat"
local DateiStru:=TEMP+BACKSLASH+"tempStr"
local DateiInfo:=db_info(Datei),change:=.f.

  Message("Datei:"+Datei+" wird aktualisiert.  @Bitte warten@")
  backup(Datei)

  if ! open(datei)
    TroubleEmail("Fehler beim �ffnen der Datei:"+datei)
    return
  endif
  copy stru exte to (DateiStru)
  close data
  copy file &(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf") to &(DateiDat+".dbf")
  ferase(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf")

  // copy memo
  if file(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION)
    copy;
      file &(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION) to &(DateiDat+MY_MEMO_EXTENSION)
  endif

  create (DateiInfo[D_PFAD]+BACKSLASH+DateiInfo[D_NAME]) from (DateiStru)
  append from (DateiDat)

  close data
  ferase(DateiDat+".dbf")
  ferase(DateiDat+MY_MEMO_EXTENSION)
  ferase(DateiStru+".dbf")

  // loesche Index file
  ferase(getIndexFullFileName(DateiInfo))

return


/** Function getFieldDescription
 * gruppiert Paramater zu einem Array
 */
Function getField(FeldName,FeldTyp,FeldLen,FeldDec,FeldPos)
LOCAL result
  default FeldTyp:="C"
  default FeldLen:=10
  default FeldDec:=0
  result:={FeldName,FeldTyp,FeldLen,FeldDec,FeldPos}
return result


/** l�sche alle temp. Dateien inkl. Unterverzeichnisse (aller Benutzer) */
procedure deleteTempFiles(filter)
LOCAL datei,aktSel:=alias(),i:=0
LOCAL isOpen:={}

  default filter:=""

  // schliese temp. Dateien
  DbSelectArea(++i)
  do while ! empty(alias())
    datei:=alias()
    if db_info(datei)[D_TEMP]
      aadd(isOpen,datei)
      close (datei)
    endif
    DbSelectArea(++i)
  enddo

  // l�sche all temp. Datein
  myDel(TEMP,filter+"*.*",.t.)
  // erzeuge User Temp Verzeichnis
  mkMyDir(TEMP_USER)

  // �ffne temp. Dateien, die bereits offen waren
  for each datei in isOpen
    open(datei)
  next
  if select(aktSel)>0
    select(aktSel)
  endif

return

/** Backuped die �bergebene Datei in den Ordner .\dat\bak\YYYYMMTT
 */
Function backup( Datei , postfix )
LOCAL bakverz:=BACKUP_SUBDIR
LOCAL dbInfo:=db_info(Datei)
LOCAL ZielPfad ,zieldbf:="dbf",zieldbt:="dbt"
LOCAL wasOpen:=.f.,wasExcl:=.f.
LOCAL aktSel:=alias()
LOCAL indOrd

  if postfix <> NIL
    bakVerz += "-"+trim(postfix)
  endif

  if select(Datei)>0
    wasOpen:=.t.
    select(Datei)
    wasExcl:=(dbinfo(DBI_ISFLOCK) .or. !dbinfo(DBI_SHARED))
    indOrd:=(Datei)->( indexOrd() )
    (Datei)->( dbcloseArea() )
  endif

  Message(Datei+"-Datei wird kopiert.     Bitte warten.")

  if dbInfo[D_TEMP] .and. valtype(dbInfo[D_TEMP_STRU])=="C"
    // nehme Original Structur-Datei, nicht die Arbeits-Kopie
    Datei:=dbInfo[D_TEMP_STRU]
    dbinfo:=db_info(datei)
  endif

  // cut of absolute path, we need it relative here
  Zielpfad:=substr(dbinfo[D_PFAD],len(HB_CWD()))

  mkMyDir(bakverz+Zielpfad)

  // ACHTUNG: mehr als 3 Kopien am selben Tag �berschreiben sich
  if file(bakVerz+Zielpfad+BACKSLASH+datei+".dbf")
    if ! file(bakVerz+Zielpfad+BACKSLASH+datei+".db2")
      zielDbf:="db2"
      zielDbt:="dt2"
    else
      zielDbf:="db3"
      zielDbt:="dt3"
    endif
  endif

  copy;
    file;
    &(dbinfo[D_PFAD]+BACKSLASH+datei+".dbf") to &(bakVerz+Zielpfad+BACKSLASH+datei+"."+ZielDbf)
  if file(dbinfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION)
    copy;
      file;
      &(dbinfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION);
      to &(bakVerz+Zielpfad+BACKSLASH+datei+"."+ZielDbt)
  endif

  // re-open file, if it was opend before
  if wasOpen
    if ! open(Datei)
      Error(TRY_AGAIN)
    else
      if wasExcl .and. ! fil_lock(5)
        Error(TRY_AGAIN)
      endif
    endif
    (Datei)->( OrdSetFocus( indOrd ) )
  endif

  if ! empty(aktSel)
    select(aktSel)
  endif

return .t.


/** F�gt ein oder mehrere Felder zu einer DBase-Datei dazu
 *
 * Parameter: Datei    - String/Dateiname
 *            fieldDescription = array of FeldName,FeldTyp,FeldLen,FeldDec
 */
Function addDBFields(DateiName,fieldDescription)
local DateiDat:=TEMP+"\tempDat"
local DateiStru:=TEMP+"\tempStr"
local i,Datei:=db_info(DateiName),change:=.f.
local DatStruInfo , tempVal
LOCAL AktDatei:=Datei[D_PFAD]+BACKSLASH+Datei[D_NAME]
LOCAL objErr
LOCAL bLastHandler

  backup(DateiName)

  Message("Datei:"+DateiName+" wird aktualisiert.  @Bitte warten@")

  if Datei[D_TEMP]
    // nehme Original Datei, nicht die Kopie des akt. Benutzers!

    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
    if valtype(Datei[D_TEMP_STRU])=="C"
      // nehme Original Structur-Datei, nicht die Arbeits-Kopie
      DatStruInfo:=db_info(Datei[D_TEMP_STRU])
      AktDatei:=DatStruInfo[D_PFAD]+BACKSLASH+Datei[D_TEMP_STRU]
    endif

    // create temp. copies
    copy file &(aktDatei+".dbf") to &(DateiDat+".dbf")
    if file(aktDatei+MY_MEMO_EXTENSION)
      copy file &(aktDatei+MY_MEMO_EXTENSION) to &(DateiDat+MY_MEMO_EXTENSION)
    endif

    BEGIN SEQUENCE // krit. Bereich
      dbUseArea( .T. , , AktDatei, Datei[D_NAME] , .f. , .F. )
      if NETERR()
        break
      endif
    RECOVER USING objErr
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      Error(AktDatei+DATEI_EXCL)
      RETURN(.f.)
      END
      MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    else
      // create temp. copies
      copy file &(aktDatei+".dbf") to &(+DateiDat+".dbf")
      if file(aktDatei+MY_MEMO_EXTENSION)
        copy file &(aktDatei+MY_MEMO_EXTENSION) to &(DateiDat+MY_MEMO_EXTENSION)
      endif
      if ! open({dateiName,.t.,.f.})
        Error(ACHTUNG+"Fehler beim �ffnen der Datei:"+dateiName,.t.)
        return .f.
      endif
    endif
    copy stru exte to (DateiStru)
    waitForAccessFile (DateiStru+".dbf")
    use (DateiStru) exclusive ALIAS DatStru

    // gehe alle neuen Felder durch
    for i:=1 to len(fieldDescription)

      // pr�fe ob Feld bereits existiert
      loca for alltrim(DATSTRU->FIELD_NAME)==upper(alltrim(fieldDescription[i,DBS_NAME]))
      if DATSTRU->(eof())
        // Field Position gesetzt?
        if valtype(fieldDescription[i,5]) == "N" .and. fieldDescription[i,5] < reccount()
          go (fieldDescription[i,5])
          insertBlank(.t.)
        else
          // hinten anf�gen
          add_rec(0)
        endif
        replace DATSTRU->Field_name with alltrim(fieldDescription[i,DBS_NAME])
        change:=.t.
      endif

      // Field Position gesetzt?
      if valtype(fieldDescription[i,5]) == "N" .and. DATSTRU->(recno()) <> fieldDescription[i,5]
        tempVal:=getCurrentValues()
        delete
        pack
        go (fieldDescription[i,5])
        insertBlank(.t.)
        setCurrentValues( tempVal )
        change:=.t.
      endif

      if DATSTRU->Field_type<>fieldDescription[i,DBS_TYPE]
        change:=.t.
        replace DATSTRU->Field_type with fieldDescription[i,DBS_TYPE]
      endif
      if DATSTRU->Field_len<>fieldDescription[i,DBS_LEN]
        replace DATSTRU->Field_len with fieldDescription[i,DBS_LEN]
        change:=.t.
      endif
      if DATSTRU->Field_Dec<>fieldDescription[i,DBS_DEC]
        replace DATSTRU->Field_Dec with fieldDescription[i,DBS_DEC]
        change:=.t.
      endif
    next i

    close data

    if change

      ferase(aktDatei+".dbf")
      create (aktDatei) from (dateiStru)
      appe from (DateiDat)
      close data

      // l�sche alle Indices und evtl. temp. Dateien aller User
      // FIXME: falls Datei als TEMP_STRU verwendet wird sollten diese temp. Dateien auch gel�scht werden
      if Datei[D_TEMP]

        if ! open("Login")
          Error(ACHTUNG+" temp. Dateien konnten nicht gel�scht werden!",.t.)
        else
          go top
          do while ! LOGIN->(eof())
            myDel(TEMP,getTempDateiName( datei )+"*.*")
            skip
          enddo
        endif

      else // keine temp.Datei

        // loesche Index file
        ferase(getIndexFullFileName(Datei))
      endif

    endif

    ferase(DateiDat+".dbf")
    ferase(DateiDat+MY_MEMO_EXTENSION)
    ferase(DateiStru+".dbf")

    return .t.
/** eof */

/** L�scht ein oder mehrere Felder von einer DBase-Datei
 *
 * Parameter: Datei    - String/Dateiname
 *            fieldDescription = array of FeldName,  (-- wird ignoriert:FeldTyp,FeldLen,FeldDec)
 *
 *
 * TODO: kann noch nicht mit TEMP_STRU Dateien umgehen
 */
Function removeDBFields(Datei,fieldDescription)
local DateiDat:=TEMP+"\tempDat"
local DateiStru:=TEMP+"\tempStr"
local i,DateiInfo:=db_info(Datei),change:=.f.


  Message("Datei:"+Datei+" wird aktualisiert.  @Bitte warten@")
  backup(Datei)

  copy file &(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf") to &(DateiDat+".dbf")

  // Memo-Felder kopieren
  if file(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION)
    copy;
      file &(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION) to &(DateiDat+MY_MEMO_EXTENSION)
  endif

  if ! open({datei,.t.,.f.})
    TroubleEmail("Fehler beim �ffnen der Datei:"+datei)
    return .f.
  endif
  copy stru exte to (DateiStru)
  waitForAccessFile (DateiStru+".dbf")
  use (DateiStru) exclusive ALIAS DatStru

  // gehe alle neuen Felder durch
  for i:=1 to len(fieldDescription)

    // pr�fe ob Feld bereits existiert
    loca for alltrim(DATSTRU->FIELD_NAME)==upper(alltrim(fieldDescription[i,DBS_NAME]))
    if DATSTRU->(eof())
      // nop
      Error(ACHTUNG+" Feld:"+Datei+"->"+fieldDescription[i,DBS_NAME]+" nicht gefunden.",.t.)
    else
      delete
      change:=.t.
    endif
  next i

  close data

  if change

    ferase(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf")
    create (DateiInfo[D_PFAD]+BACKSLASH+datei) from (dateiStru)
    appe from (DateiDat)

    close data

    // loesche Index file
    ferase(getIndexFullFileName(DateiInfo))

    close data

    // l�sche alle temp. Dateien
    if DateiInfo[D_TEMP]
      deleteTempFiles()
    endif

  endif

  ferase(DateiDat+".dbf")
  ferase(DateiStru+".dbf")
  ferase(DateiStru+MY_MEMO_EXTENSION)

return .t.
/** eof */

/** Verschiebt ein Feld einer DBase-Datei
 *
 * Parameter: Datei     = String/Dateiname
 *            fieldname = FeldName
 *            newPos    = neue Postion, 1 == erster
 *
 */
Function moveDBField(Datei,fieldName,newPos)
local DateiDat:=TEMP+"\tempDat"
local DateiStru:=TEMP+"\tempStr"
local DateiInfo:=db_info(Datei),change:=.f.
LOCAL aDateiFelder

  Message("Datei:"+Datei+" wird aktualisiert.  @Bitte warten@")
  backup(Datei)

  copy file &(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf") to &(DateiDat+".dbf")

  // Memo-Felder kopieren
  if file(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION)
    copy;
      file &(DateiInfo[D_PFAD]+BACKSLASH+datei+MY_MEMO_EXTENSION) to &(DateiDat+MY_MEMO_EXTENSION)
  endif

  if ! open({datei,.t.,.f.})
    TroubleEmail("Fehler beim �ffnen der Datei:"+datei)
    return .f.
  endif
  copy stru exte to (DateiStru)
  waitForAccessFile (DateiStru+".dbf")
  use (DateiStru) exclusive ALIAS DatStru

  // suche Feld an alter Position
  loca for alltrim(DATSTRU->FIELD_NAME)==upper(alltrim(fieldName))
  if DATSTRU->(eof())
    // nop
    Error(ACHTUNG+" Feld:"+Datei+"->"+fieldName+" nicht gefunden.",.t.)
  else
    aDateiFelder:=getCurrentValues()
    delete
    pack
    go (newPos)
    insertBlank(.t.)
    setCurrentValues(ADateiFelder)
    change:=.t.
  endif

  close data

  if change

    ferase(DateiInfo[D_PFAD]+BACKSLASH+datei+".dbf")
    create (DateiInfo[D_PFAD]+BACKSLASH+datei) from (dateiStru)
    appe from (DateiDat)

    close data

    // loesche Index file
    ferase(getIndexFullFileName(DateiInfo))

    close data

    // l�sche alle temp. Dateien
    if DateiInfo[D_TEMP]
      deleteTempFiles()
    endif

  endif

  ferase(DateiDat+".dbf")
  ferase(DateiStru+".dbf")
  ferase(DateiStru+MY_MEMO_EXTENSION)

return .t.
/** eof */


/** liefert den Haupt-Feldnamen (i.d.R. unique ID Column) zur�ck, default ist die 1. Spalte */
function getKeyFieldName(aDatei)
return if(aDatei[D_KEY]==NIL,(aDatei[D_NAME])->(fieldName(1)),aDatei[D_KEY])
/** eof */

/** liefert die L�nge des Haupt-Feldes (i.d.R. unique ID Column) zur�ck, default ist die 1. Spalte */
function getKeyFieldLen(aDatei)
return if(aDatei[D_KEY]==NIL,fieldLen(1),;
  (aDatei[D_NAME])->(fieldlen((aDatei[D_NAME])->(fieldpos(aDatei[D_KEY])))))
/** eof */

/** liefert den Inhalt des Haupt-Feldes (i.d.R. unique ID Column) zur�ck, default ist die 1. Spalte */
function getKeyFieldValue(aDatei)
return if(aDatei[D_KEY]==NIL,(aDatei[D_NAME])->(fieldget(1)),;
  (aDatei[D_NAME])->(fieldget((aDatei[D_NAME])->(fieldpos(aDatei[D_KEY])))))
/** eof */

/** liefert die Position des Haupt-Feldes (i.d.R. unique ID Column) zur�ck, default ist die 1. Spalte */
function getKeyFieldPos(aDatei)
return if(aDatei[D_KEY]==NIL,1,(aDatei[D_NAME])->(fieldpos(aDatei[D_KEY])))
/** eof */

  /** Adds a record to the current work area at the current position
  * workarea must be exlusivly opened.
  * The newly inserted record is selected afterwards
  *
  * ACHTUNG: geht nur bei excl. offener Datei, ohne Index und ohne deleted() records!!!
  */
procedure insertBlank(before)
LOCAL merk_Satz:=recno()
LOCAL aDateiFelder,i,FeldNr

  default before:=.t.

  if ! before
    skip
    merk_Satz:=recno()
  endif

  add_rec(0)
  i = RECCOUNT()
  // shift all following record
  Do While i > Merk_Satz
    GOTO (i-1)
    ADateiFelder:=getCurrentValues()
    GOTO i
    setCurrentValues(ADateiFelder)
    i = i-1
  enddo

  // clear new current record
  goto Merk_Satz
  for Feldnr:=1 to fcount()
    DO CASE
    CASE type(FieldName(FeldNr))$"CM"
      REPLACE &(FieldName(FeldNr)) WITH ""
    CASE type(FieldName(FeldNr))="N"
      REPLACE &(FieldName(FeldNr)) WITH 0.00
    CASE type(FieldName(FeldNr))="D"
      REPLACE &(FieldName(FeldNr)) WITH ctod('  .  .  ')
    CASE type(FieldName(FeldNr))="T" // Date Time
      REPLACE &(FieldName(FeldNr)) WITH ctot()
    CASE type(FieldName(FeldNr))="L"
      REPLACE &(FieldName(FeldNr)) WITH .f.
    otherwise
      TroubleEmail("Fehler beim Insert:"+FieldName(FeldNr))
    ENDCASE
  next
return
/** eop */

  // all indiceswerden pro DBF in einer CDX gespeichert
  // ACHTUNG: sollte nicht der gleiche name wie die dbf haben,
// da ansonsten TEMPORARY ADDITIVE indices dort persistent gespeichert werden!!!
function getIndexFullFileName(datei)
LOCAL indexName
  if Datei[D_TEMP]
    IndexName:=getTempDateiName( datei )+"1"+indexExt()
  else // normale Datei
    IndexName:=Datei[D_PFAD]+BACKSLASH+trim(Datei[D_NAME])+"1"+indexExt()
  endif
return indexName
/** eof */

function getTempDateiName( datei )
LOCAL result
  if Datei[D_TEMP_STATIC]
    // selbe Datei f�r alle Logins des Benutzers
    result:=TEMP + BACKSLASH + ;
      left(getUser():getLongId(),2)+BACKSLASH+trim(Datei[D_NAME])
  else
    // eine Datei f�r jedes Logins des Benutzers
    result:=TEMP + BACKSLASH + ;
      left(getUser():getLongId(),2)+BACKSLASH+trim(Datei[D_NAME])+right(getUser():getLongId(),2)
  endif
return result
/** eof */

/** erzeugt die Pfade in TMP and TEMP env var.
  *
  * behebt den Fehler: Create error C:\MikiProg\PROD\DAT\...\*.cdx
    Create error -- Fehler:   20
  */
procedure createTempPaths()
LOCAL cTmpDir
  for each cTmpDir in {GetEnv("TMP"), GetEnv("TEMP")}
    IF ! Empty(cTmpDir)
      IF ! mkMyDir(cTmpDir)
        troubleEmail("Verzeichnis konnte nicht erstellt werden: " + cTmpDir)
      ENDIF
    endif
  next
return
  /** eop */


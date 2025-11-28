/* Modul Help.prg
*
* allem�glichen Hilfs-Fkt:
*
*       titel          // zeigt Kasten + Titel etc. an
*/

#include "Miki.ch"
#include "Directry.ch"

#include "hbgtinfo.ch"
#include "hbqtgui.ch"
#include "mynetio.ch"


/* 
* gibt die fuer Repartur-Artikel relevanten Stellen zurueck.
* die 3. Stelle entfaellt
* (503101.0 == 504101.0)
*/
FUNCTION subRepArtikel(ArtNr)
RETURN substr(ArtNr,1,2)+substr(Artnr,4)
/* EOF */

/** protokolliert die Aufrufe von Programmen */
procedure protAufruf(MenuPkt)
local l

  if ! TEST_PROG .and. ! DEVEL_PROG

    if ! open("Aufruf")
      Error(TRY_AGAIN)
      close data
      RETURN
    endif

    l:=len(AUFRUF->ProgName)
    dbseek(left(procname(1)+space(l),l)+right("00"+alltrim(str(MenuPkt,2)),2))
    if AUFRUF->(eof())
      Add_Rec(0)
      replace AUFRUF->ProgName with procname(1)
      replace AUFRUF->ProgNr with right("00"+alltrim(str(MenuPkt,2)),2)
      replace AUFRUF->Anzahl with AUFRUF->Anzahl+1
      replace AUFRUF->Details with dtoc(getUser():date)+" "+time()+" "+getUser():id

      do case
      case procname(1)=="MAIN"
        replace AUFRUF->Bez with "Hauptmenu"
      case procname(1)=="STAM_MENU"
        replace AUFRUF->Bez with "Stammdaten Men�"
      case procname(1)=="STAM2_MENU"
        replace AUFRUF->Bez with "Reparaturen Men� (8.90)"
      case procname(1)=="SYS_MENU"
        replace AUFRUF->Bez with "Systemdaten Men�"
      case procname(1)=="INV_MENU"
        replace AUFRUF->Bez with "Inventur Men�"
      case procname(1)=="LIST_MENU"
        replace AUFRUF->Bez with "Listen Men�"
      case procname(1)=="LIST2_MENU"
        replace AUFRUF->Bez with "Weitere Listen Men� (6.49)"
      case procname(1)=="ETI_MENU"
        replace AUFRUF->Bez with "Etiketten Men�"
      case procname(1)=="MAT_MENU"
        replace AUFRUF->Bez with "Material Men�"
      case procname(1)=="EINAUS_MENU"
        replace AUFRUF->Bez with "Material Ein/Ausgang Men� (11)"
      case procname(1)=="BEST_MENU"
        replace AUFRUF->Bez with "Bestellung Men�"
      case procname(1)=="FAKT_MENU"
        replace AUFRUF->Bez with "Fakturierung Men�"
      case procname(1)=="AV_MENU"
        replace AUFRUF->Bez with "Arbeitsvorbereitung Men�"
      case procname(1)=="AUS_MENU"
        replace AUFRUF->Bez with "Auskunft Men�"
      case procname(1)=="WERBE_MENU"
        replace AUFRUF->Bez with "Werbegeschenke Men� (6.17)"
      case procname(1)=="BANK_MENU"
        replace AUFRUF->Bez with "Bank Men�"
      case procname(1)=="KLAG_MENU"
        replace AUFRUF->Bez with "KLager Men�"
      case procname(1)=="SYS2_MENU"
        replace AUFRUF->Bez with "System intern (nur JG)"
      endcase

    else
      rec_lock(0)
      replace AUFRUF->Anzahl with AUFRUF->Anzahl+1
      if AUFRUF->Anzahl < 10
        replace AUFRUF->Details with AUFRUF->Details+MY_CR+MY_LF+;
          dtoc(getUser():date)+" "+time()+" "+getUser():id
      endif
    endif
    dbcommit()
    dbunlock()
    close data
  endif

return


/** L�scht unn�tige Logfiles, kopiert & schickt krit. log Dateien an MY_EMAIL */
Procedure HouseKeeping()
LOCAL myAttachments:={}
LOCAL debugBespost:=MAIL+BACKSLASH+"bespost.inf"
LOCAL debugAvpost:=MAIL+BACKSLASH+"avpost.inf"
LOCAL temp

  Umgebung(WRITE_ALL)

  Message("Housekeeping.   Bitte warten...")

  // re-new date, since server is running 24/7
  getUser():date:=hb_date()

  // clean up some dead records
  if open({"BesAus",.t.})
    dele for left(BESAUS->Bestnr,2)=="**" .or. empty(BESAUS->Bestnr)
    pack
    dbcommitall()
  endif
  close data

  // clean up some dead records
  if open({"AufAus",.t.})
    dele for left(AUFAUS->Aufnr,2)=="**"
    pack
    dbcommitall()
  endif
  close data
  // clean up some dead records
  if open({"AngAus",.t.})
    dele for left(ANGAUS->Angnr,2)=="**"
    pack
    dbcommitall()
  endif
  close data

  // clean up some dead records (Zeiterfassung AB)
  if open({"AufZeit",.t.},"AufPost")
    select AufZeit
    set rela to AUFZEIT->ABPostNr into AufPost
    dele for AUFPOST->(eof())
    pack
    dbcommitall()
  endif
  close data

  // cleanup dead records in avpost -> should not happen anymore
  if open( "Artikel", "AvAus",{"AvPost",.t.})
    select AvPost
    set rela to AVPOST->AvNr into AvAus, to AVPOST->AvNr into Artikel
    loca for AVAUS->(eof()) .or. ARTIKEL->(eof()) .or. empty(AVPOST->ArtNr)
    do while ! AVPOST->(eof())
      trouble("Avpost","Avpost:" + AVPOST->AvNr + "->"+ AVPOST->ArtNr + ;
        " AV:" + AvAus->AvNr + " ArtNr:" + Artikel->ArtNr + "  -> gel�scht")
      delete
      cont
    enddo
  endif

  // cleanup dead records in avaus # new 11.12.24
  if open({"AvAus",.t.}, "AvPost")
    select AvAus
    go top
    do while ! AVAUS->(eof())
      AVPOST->(dbseek( AVAUS->AvNr ))
      if AVPOST->(eof())
        if rec_lock(5) // delete Avaus
          delete
          dbcommit()
          dbunlock()
        endif
      endif
      skip
    enddo
  endif
  Protokoll(P_CREATE_PDF,,,,.t.)
  close data

  if file( debugBespost )
    temp:=fileStr( debugBespost )
    if "no index" $ temp
      aadd(myAttachments , debugBespost )
    endif
  endif

  if file( debugAvpost )
    aadd(myAttachments , debugAvpost )
  endif

  MyHouseKeeping( myAttachments )

  Umgebung(LOAD)
return

/** Liefert den passenden Adressblock je nach L�nderk�rzel,
 *
   *  beachtet alten Adel und liefert LAND=leer, wenn L�nder-KZ nicht
   *  genau 2-stellig!

   *  Deutschland:                  mit 4. Adress-Feld:

   *        <leer>                  Karl Napf
   *        Karl Napf               Firma Muster
   *        Firma Muster            Bsp.Str. 17
   *        Bsp.Str. 17             Hinterhaus
   *        <leer>                  <leer>
   *        68163 Mannheim          68163 Mannheim

   *  Ausland:                      mit 4. Adress-Feld:

   *        <leer>                  Karl Napf
   *        Karl Napf               Examle company
   *        Examle company          Examplestreet 17
   *        Examplestreet 17        Westminster
   *        2000 London             2000 London
   *        Gro�-Britianien         Gro�-Britianien


   *
   * Bemerkung:: forceLand==.t. druckt den L�ndernamen auf jeden Fall
   * aus (nur Deutschland), z.B. f�r Bestellungen
   *
  * maxlines (default 6) untertuetzt bisher nur 5 max. Zeilen

	
*/

  // Hinweis: PLZ (7) +Ort (30) k�nnte abgeschnitten werden, falls voll benutzt!
  #define adr_length 34

FUNCTION getAdrBlock(Name,Partner,Strasse,Zusatz,Land,Plz,Ort,forceLand,maxlines)
LOCAL result:={} , i
LOCAL aktSel,aktRec

  default forceLand:=.f.
  default maxlines:=6

  // Falls alles leer -> kein Land drucken
  if empty(Name) .and. empty(Partner) .and. empty(Strasse) .and. empty(Zusatz) .and. empty(Plz) ;
    .and. empty(Ort)
    for i:=1 to maxlines
      aadd(result,setLength("",adr_length))
    next
    return shrinkAdr(result,maxlines)
  endif

  if select("Land")==0
    aktSel:=alias()
    if ! open("Land")
      Error(TRY_AGAIN)
      select (aktSel)
      return shrinkAdr(result,maxlines)
    endif
    select (aktSel)
  endif
  aktRec:=LAND->(recno())

  if alltrim(Land)=="DE" .or. alltrim(Land)=="D"
    if empty(Zusatz)
      if ! forceLand
        aadd(result,setLength("",adr_length))
      endif
      aadd(result,setLength(Name,adr_length))
      aadd(result,setLength(Partner,adr_length))
      aadd(result,setLength(Strasse,adr_length))
      aadd(result,setLength("",adr_length))
      aadd(result,setLength(mytrim(PLZ)+Ort,adr_length))
      if forceLand
        aadd(result,setLength("Deutschland (D)",adr_length))
      endif
    else
      aadd(result,setLength(Name,adr_length))
      aadd(result,setLength(Partner,adr_length))
      aadd(result,setLength(Strasse,adr_length))
      aadd(result,setLength(Zusatz,adr_length))
      if ! forceLand
        aadd(result,setLength("",adr_length))
      endif
      aadd(result,setLength(mytrim(PLZ)+Ort,adr_length))
      if forceLand
        aadd(result,setLength("Deutschland (D)",adr_length))
      endif
    endif
  else

    // suche Land
    Umgebung(WRITE)

    if select("Land")==0
      if ! open("Land")
        TroubleEmail("Land.dbf nicht verfuegbar!")
        Umgebung(LOAD)
        aadd(result,setLength(Name,adr_length))
        aadd(result,setLength(Partner,adr_length))
        aadd(result,setLength(Strasse,adr_length))
        aadd(result,setLength(Zusatz,adr_length))
        aadd(result,setLength(mytrim(Land)+mytrim(PLZ)+Ort,adr_length))
        aadd(result,setLength("",adr_length))
        return shrinkAdr(result,maxlines)
      endif
    endif

    // Neu Adress-Art mit korrektem L�nder-KZ
    if len(trim(Land))==2 .and. isAlpha(left(land,1)) .and. isAlpha(substr(land,2))
      Land->(dbseek(land))

      if empty(Zusatz)
        aadd(result,setLength("",adr_length))
        aadd(result,setLength(Name,adr_length))
        aadd(result,setLength(Partner,adr_length))
        aadd(result,setLength(Strasse,adr_length))
        aadd(result,setLength(mytrim(PLZ)+Ort,adr_length))
        aadd(result,setLength(LAND->Name,adr_length))
      else
        aadd(result,setLength(Name,adr_length))
        aadd(result,setLength(Partner,adr_length))
        aadd(result,setLength(Strasse,adr_length))
        aadd(result,setLength(Zusatz,adr_length))
        aadd(result,setLength(mytrim(PLZ)+Ort,adr_length))
        aadd(result,setLength(LAND->Name,adr_length))
      endif
    else
      // Alte Adress-Art mit falschem L�nder-KZ
      Trouble("Land-KZ",{"Land-KZ unbekannt:"+Land})
      Umgebung(LOAD)
      aadd(result,setLength(Name,adr_length))
      aadd(result,setLength(Partner,adr_length))
      aadd(result,setLength(Strasse,adr_length))
      aadd(result,setLength(Zusatz,adr_length))
      aadd(result,setLength(mytrim(Land)+mytrim(PLZ)+Ort,adr_length))
      aadd(result,setLength("",adr_length))
      return shrinkAdr(result,maxlines)
    endif

    Umgebung(LOAD)
    LAND->(dbgoto(aktRec))

  endif // DE

return shrinkAdr(result,maxlines)
/** eof */

function shrinkAdr(adresse,maxlines)
LOCAL i:=len(adresse)
  do while len(adresse) > maxlines .and. i > 0
    // remove empty lines from bottom
    if empty(adresse[i])
      hb_adel( adresse , i , .t.)
    else
      i--
    endif
  enddo

  // falls keine Leerzeile frei, drucke letzte beiden Zeilen in eine
  do while len(adresse) > maxlines
    adresse[maxlines]:=alltrim(adresse[maxlines]) + ", " + alltrim(adresse[maxlines+1])
    hb_adel( adresse , maxlines + 1,.t.)
  enddo

return adresse

  /** k�rzt/verl�ngert einen String auf die angegeben Gr��e,
      bzw. "druckt" einen zu langen String in schmal */
FUNCTION setLength(s,l)
  if len(trim(s))>l
    // Error(ACHTUNG+"Adress-Feld zu land.||Adresse bitte pr�fen:||"+;
    // s+"|->|"+left(s,l),.t.,"root")
    // ACHTUNG: schmal(space(+8)) kompensiert die L�nge bei 34 Zeichen, leider hardcoded
    // FIXME
    // return SCHMAL_AN,left(s+space(l),l+8),SCHMAL_AUS
    // NOP da SCHMAL_AN+ nicht geht
  endif
return left(s+space(l),l)
/** eof */


/** Returns the current user, if null returns a dummy user */
Function getUser()
  if M->User==NIL .or. valtype(M->User)<>"O"
    initUser(DUMMY_USER,"1")
    TroubleEmail("User nicht gestzt!")
  endif
return M->User

/** Creates, sets and returns a new user with the given ID and counter */
Function initUser(kurzel,counter)
  M->User:=User():new(kurzel,counter)
return M->User
/** eof */

/** returns the property file name for this application */
Function getPropertiesFileName()
return PROPERTIES_FILE
/** eof */

/* FUNCTION trim_matkz()
*
* liefert �bergebenen String ohne "-" zur�ck falls letztes Zeichen
*/
FUNCTION trim_matKz(tempStr)
LOCAL retStr:=alltrim(tempStr)
  if right(retStr,1)=="-"
    RETURN alltrim(left(retStr,len(retStr)-1))
  endif
RETURN retStr
/* EOF */


/* FUNCTION KdNr_trans
*
* temp. Fkt. zum update der Kund.Nr
*/
FUNCTION KdNr_trans(UrSprung)
LOCAL tempStr
  tempStr:=UrSprung+"-"+"  "
RETURN tempStr
/* EOF KdNr_Trans */




/* 
* holt bestimmte Systemparameter aus System.dbf
* speichere immer n�chste freie Nr.
*
* Parameter:  gew�nschte Variable, Status (lesen Schreiben)
*             force: aktives warten, kein Abbruch m�glich
*/
FUNCTION Hole(Variable,Status,force)
LOCAL sel:=select()
LOCAL pos
LOCAL Merke,aStruct,lang:=0
  default force:=.f.

  open( "System" )
  dbskip(0)
  aStruct:=dbstruct()
  pos:=fieldpos(variable)
  if pos==0
    Error("Feld:"+Variable+" existiert nicht in System.dbf"+SCHWERER_FEHLER)
    return "0"
  endif
  Merke:=&(variable)
  lang:=aStruct[pos,3]

  if Status==LOAD // nur lesen
    /* NOP */
  else // schreiben
    if ! fil_lock(if(force,0,5))
      select (sel)
      Error("System.dbf"+DATEI_EXCL)
      RETURN("0")
    endif
    merke:=&(variable)
    /* �berlauf ? */
    if merke+1 >= 10**lang
      if lower(Variable)=="bestnr"
        replace &(variable) with 10**(lang-1)
        trouble("root",{"System Parameter �berlauf:"+variable})
      elseif lower(Variable)=="innernr"
        replace &(variable) with INNER_NR_BEGINN-1 // wird unten 1 hochgez�hlt
      else
        replace &(variable) with 0
        trouble("root",{"System Parameter �berlauf:"+variable})
      endif
    endif
    replace &(variable) with ++&(variable)
    dbcommit()
    unlock
  endif
  select (sel)

RETURN( str(merke,lang) )
/** eof */


/** Ersetzt alle Sonderzeichen @ im �bergebenen String  mit COLOR_RED und COLOR_DEFAULT abwechselnd
  */
FUNCTION configColorPrint(text,colStart)
LOCAL result:="",pos
  _thread static oldColor

  if colStart<>NIL
    oldColor:=colStart
  endif

  if oldColor==NIL
    oldColor:=COLOR_DEFAULT
  endif

  do while (pos:=at("@",text)) > 0
    result+=left(text,pos-1)
    if oldColor==COLOR_RED
      result+=COLOR_DEFAULT
      oldColor:=COLOR_DEFAULT
    else
      result+=COLOR_RED
      oldColor:=COLOR_RED
    endif
    text:=substr(text,pos+1)
  enddo

  result+=text

  // Bildschirm-Ausgabe andere Sonderzeichen
  if getUser():getCurrentPrintJob():className()=="BSJOB"
    result:=strtran(result,COLOR_RED,BS_FARBE)
    result:=strtran(result,COLOR_DEFAULT,BS_FARBE)
  endif

return result
/** eof */

/** Liefert je nach selektiertem Land in Land.dbf, falls vorhanden
    und nicht leer die englische �bersetzung
  *
  * Parameter Sprache ist optional, falls nil wird LAND->Spache genommen
  */
FUNCTION getTransField(fieldName,M_Sprache)
LOCAL result:="",pos:=at(">",fieldName)
LOCAL enField,deField,datei,enAvailable

  default M_Sprache:=LAND->Sprache

  datei:=left(fieldName,pos-2)
  deField:=substr(fieldName,pos+1)
  enField:="E_"+deField

  // pr�fe ob dt. Feld vorhanden
  if &(Datei)->(fieldPos(deField))==0
    Error(ACHTUNG+datei+" -> "+deField+" unbekannt.",.t.,"root")
    return result
  endif

  result:=&(Datei)->(fieldGet(fieldPos(deField)))

  // get englisch text if any
  if M_Sprache<>DEUTSCH

    switch upper(datei)
    case "ARTIKEL"
      enAvailable:=!empty(ARTIKEL->E_Bez1)
      exit
    case "ZAHLKOND"
      enAvailable:=!empty(ZAHLKOND->E_TEXT)
      exit
    case "TEXT_KZ"
      enAvailable:=!empty(TEXT_KZ->E_TEXT1)
      exit
    case "AUFTRAG"
      enAvailable:=!empty(AUFTRAG->E_KOMM1)
      exit
    case "RECHPOST"
      enAvailable:=!empty(RECHPOST->E_KOMM1)
      exit
    case "BESPOST"
      enAvailable:=!empty(BESPOST->E_KOMM1)
      exit
      // aktRec:=ARTIKEL->(recno())
      // ARTIKEL->(dbseek(&(Datei)->ArtNr))
      // enAvailable:=.f. // we set the result right below
      // if ! ARTIKEL->(eof()) .and. ! empty(ARTIKEL->E_Bez1)
      // if right(deField,1)=="1"
      // result:=ARTIKEL->E_Bez1
      // else
      // result:=ARTIKEL->E_Bez2
      // endif
      // endif
      // exit
    otherwise
      enAvailable:=!empty(&(Datei)->(fieldGet(fieldPos(enField))))
    endswitch

    // pr�fe ob eng. Feld vorhanden
    // if &(Datei)->(fieldPos(enField))==0
    // Error(ACHTUNG+datei+" -> "+enField+" unbekannt.",.t.,"root")
    // return result
    // endif

    if enAvailable
      result:=&(Datei)->(fieldGet(fieldPos(enField)) )
    endif
  endif

return result
/** eof */

/** Geht auf ein Dummy-Land je nach gew�nschter Sprache */
PROCEDURE selLandBySprache(Sprache)

  switch Sprache
  case " "
  case DEUTSCH
    LAND->(dbseek(DEUTSCH_LAND))
    exit
  case ENGLISCH
    LAND->(dbseek(ENGLISCH_LAND))
    exit
  case FRANZOESISCH
    LAND->(dbseek(FRANZ_LAND))
    exit
  otherwise
    Error(ACHTUNG+"Sprache:"+Sprache+" nicht unterst�tzt.",.t.,"root")
  endswitch
return
/** eop */

/** Schaltet die Sprache im Editor-Bauch um */
function toggleSprache()

  if LAND->Sprache==DEUTSCH
    selLandBySprache(ENGLISCH)
  else
    selLandBySprache(DEUTSCH)
  endif

  // beende akt. Editor -> wird neu gestartet mit neuer Sprache
  if inStackTrace("LineEdit")
    HB_KeyPut(K_ESC)
  endif
  HB_KeyPut(EDIT_QUIT)

return .t.
/** eof */


/** liefert die Fertigungsdauer des aktuellen Artikels */  
function getArtikelFertigungsdauer(Menge)
LOCAL dauer
LOCAL aktRec:=AVPOST->(recno())
  // Bei 503er Artikel nehme den 1. aus St�ckliste i.d.R. 504er
  if left(ARTIKEL->ArtNr,3)=="503"
    AVPOST->(dbseek(ARTIKEL->ArtNr))
    if AVPOST->(eof()) .or. left(AVPOST->ArtNr,3)<>"504"
      dauer:="Fehler"
    else
      dauer:=getStdTagText( getGesFertDauer( AVPOST->ArtNr, menge ), STDTAG_TINY)
    endif
  else
    dauer:=getStdTagText( getGesFertDauer( ARTIKEL->ArtNr, menge ), STDTAG_TINY)
  endif
  AVPOST->(dbgoto(aktRec))
return dauer
  /** eof */

/** encoded URL parameter */
FUNCTION URLEncode( cParam )
LOCAL cUTF8:=hb_StrToUTF8( cParam )
LOCAL cResult:=""
LOCAL i, c, nAsc

  FOR i:=1 TO Len( cUTF8 )
    c:=SubStr( cUTF8, i, 1 )
    nAsc:=Asc( c )

    // Keep [0-9], [A-Z], [a-z], and -_.~ unencoded
    IF ( nAsc >= 48 .AND. nAsc <= 57 ) ; // 0-9
      .OR. ( nAsc >= 65 .AND. nAsc <= 90 ) ; // A-Z
      .OR. ( nAsc >= 97 .AND. nAsc <= 122 ) ; // a-z
      .OR. ( c $ "?&-_.~=" )
      cResult += c
    ELSE
      // Convert the byte to %XX hex form
      cResult += URLEncodeByte( nAsc )
    ENDIF
  NEXT

RETURN cResult
  /** EOF */

FUNCTION URLEncodeByte( nAsc )
LOCAL cHex:=NumToHex( nAsc ) // e.g. 194 => "C2"
  cHex:=Upper( Right( "00" + cHex, 2 ) )
  // Now cHex is exactly 2 hex digits, e.g. "C2"
RETURN "%" + cHex
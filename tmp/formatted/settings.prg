/** Settings.prg
 *
 * returns customer and system specific settings
 * should be initialized (#see init(fileName)) with a config file
 * otherwise default values from the getProperty request are returned
*
* see .../harbour/src/rtl/hbini.prg
 */

#include "Error.ch"
#include "MyStd.ch"

_thread static hCustomer:=NIL // customer values
_thread static configFile:=NIL
_thread static langFiles:=NIL
_thread static hFieldText:=NIL // human readable field description

/** for testing */
PROCEDURE SettingsTest()

  qout( "Start:")
  dumpProperties()
  dumpLangProperties()
  WAIT

RETURN
/** eop */


/** eop */

  /** reads ini file using hb_IniRead(file)
   *
   * see harbour\tests or \harbour\src\rtl
   *
   */
FUNCTION initProperties( cfgFile )
LOCAL text

  IF cfgFile <> NIL .AND. ! File( cfgFile )
    text:='"'+trim(cfgFile)+' nicht gefunden."'+MY_CR+MY_LF+;
      +MY_CR+MY_LF+;
      '"KEIN LOGIN m�glich."'+MY_CR+MY_LF+;
      '"Bitte Herrn Gruhn kontaktieren."'
    extMsgBox(text)
    QUIT
  ENDIF
  configFile:=cfgFile

  hCustomer:=hb_IniRead( cfgFile )

RETURN 0 // Bingo
/** eof */

  /** Returns the requested property
   *
   * Returns the passed defaultValue if property is not found
   */
FUNCTION getProperty( fullname, defaultValue )
LOCAL result

  IF At( ".", fullName ) > 0
    result:=getPropertyValue( Left( fullName,At(".",fullName ) -;
      1 ), SubStr( fullName,At(".",fullName ) + 1 ) )
  ELSE
    result:=getPropertyValue( "Main", fullName )
  ENDIF
  IF result == NIL
    result:=defaultValue
    if defaultValue==NIL
      if DEVEL_PROG
        Error(ACHTUNG+" Kein Default Wert gesetzt f�r Property: "+fullName,.t.)
      else
        TroubleEmail(ACHTUNG+" Kein Default Wert gesetzt f�r Property: "+fullName)
      endif
    endif

  ENDIF

RETURN result

/** eof */

/** Returns the requested property if set in the customer config file
*/

STATIC FUNCTION getPropertyValue( section, key )
LOCAL sec, result:=NIL

  // get section
  IF hCustomer <> NIL .AND. hb_HHasKey( hCustomer, section )
    sec:=hCustomer[ section ]
    // get key
    IF hb_HHasKey( sec , key )
      result:=sec[key]
    ENDIF
  ENDIF

RETURN result
/** eof */

  /**
  * Sets the property transiently to the new value
  * will be discarded after restart
  *
  * Result: always true (success)
  */
FUNCTION setProperty( fullname, newValue )
LOCAL section:=Left( fullName,At(".",fullName ) - 1 )
LOCAL Key:=SubStr( fullName,At(".",fullName ) + 1 )

  // get section
  IF hCustomer <> NIL
    if ! hb_HHasKey( hCustomer, section )
      // Section existiert noch nicht
      // HSetAutoAdd(hCustomer,.t.)
      // hCustomer[section]:=hb_hash()
      hset(hCustomer,section,hb_hash())
    endif
    hset(hCustomer[section],key,newValue)
  else
    Error("ACHTUNG: Property:"+fullName+" not initialized.",.t.)
  ENDIF

RETURN .t.



/** Gibt alle properties aus */
PROCEDURE dumpProperties()
LOCAL cSection, aSect, ckey, value, zeile:=0

  IF hCustomer == NIL
    initProperties()
  ENDIF

  @ 2, 0 SAY ""

  ? "Property File: "+configFile

  FOR EACH cSection IN hCustomer:Keys
    ?
    ? "Customer Section [" + cSection + "]"
    aSect:=hCustomer[ cSection ]

    FOR EACH cKey IN hCustomer[cSection]:Keys
      value:=getPropertyValue( cSection, cKey )
      ? cKey, "=" , if( value == NIL, "", value )
    NEXT
  NEXT

  IF hFieldText == NIL
    initFieldText()
  ENDIF

  @ 2, 0 SAY ""

  ?
  ? "============="
  ? "Field Names: "

  FOR EACH cSection IN hFieldText:Keys
    ?
    ? "Datei [" + cSection + "]"
    aSect:=hFieldText[ cSection ]

    FOR EACH cKey IN hFieldText[cSection]:Keys
      value:=getFieldText( cSection, cKey )
      ? cKey, "=" , if( value == NIL, "", value )
    NEXT
  NEXT

RETURN
/** eop */

/** Liest das PropertyFile neu
 * falls interaktiv==.t. kann der Name eingegeben werden.
 */
PROCEDURE readProperties(propFile,interaktiv)
LOCAL eingabe:=if(propFile==NIL,NIL,left(propFile+space(60),60))
LOCAL GetList:={}
  default interaktiv:=.f.

  if interaktiv
    setcolor(COLWIN)
    Fenster(12,20,14,66)
    Message("Config-Datei eingeben.")
    @ 13,12 say "Datei:" get eingabe
    read
    setcolor(COLNOR)
    if ABBRUCH
      return
    endif
    eingabe:=trim(eingabe)
  endif

  // load properties file
  if initProperties(eingabe)<>0
    Error(ACHTUNG+"Config-Datei: "+trim(eingabe)+" konnte nicht gelesen werden.",.t.)
    down()
  endif

  // load field text if any
  initFieldText()
return
/** eop */



/**
  * Returns the translation of the text based on the language shortcut
  *
  * D - deutsch.cfg  (default & fallback)
  * E - englisch.cfg
  * F - franz.cfg
  *
  * invokes readLangFiles() at the 1st time
  *
  * FIXME: File names deutsch.cfg etc. should be configurable
  *
  */
FUNCTION getTranslation(fullName,land,laenge)
LOCAL datei:="deutsch.cfg"
LOCAL transTable,tempSec,sec,key
LOCAL result:="" // default result is empty string

  // Landessprache
  switch land
  case "E"
    datei:="englisch.cfg"
    exit
  case "F"
    datei:="franz.cfg"
    exit
  endswitch

  if langFiles==NIL
    readLangFiles()
  endif

  if langFiles <> NIL
    // does the requested language translation table exist?
    if hb_HHasKey( langFiles, datei )
      transTable:=langFiles[ datei ]
    elseif land<>"E" .and. ! empty(land) // 1. fallback Englisch
      datei:="englisch.cfg"
      if hb_HHasKey( langFiles, datei )
        transTable:=langFiles[ datei ]
      elseif land<>"D" .and. ! empty(land) // 2. fallback Deutsch
        datei:="deutsch.cfg"
        if hb_HHasKey( langFiles, datei )
          transTable:=langFiles[ datei ]
        endif
      endif
    endif
  ENDIF

  // get translation
  if transTable<>NIL

    // get main section
    IF At( ".", fullName ) > 0
      sec:=left( fullName,At(".",fullName ) - 1 )
      key:=substr( fullName,At(".",fullName ) + 1 )
    else
      key:=fullName
      sec:=fullName
    endif

    // try requested language
    if hb_HHasKey( transTable, sec )
      tempSec:=transTable[sec]
      if hb_HHasKey( tempSec, key )
        result:=tempSec[key]
      endif
    endif

    // fallback German
    if empty(result) .and. land<>"D" .and. ! empty(land)
      datei:="deutsch.cfg"
      if hb_HHasKey( langFiles, datei )
        transTable:=langFiles[ datei ]
      endif
      if hb_HHasKey( transTable, sec )
        tempSec:=transTable[sec]
        if hb_HHasKey( tempSec, key )
          result:=tempSec[key]
        endif
      endif
    endif

  endif

  // check wheter translated field shall be empty
  if result==I8N_EMPTY
    result:=""
  endif

  // change all � to spaces -> moved to linewrap
  // result:=strtran(result,"�"," ")

  // auf laenge bringen
  if laenge<>NIL
    result:=left(result+space(laenge),laenge)
  endif

return result
/** eof */

/**  Reads the corresponding from the same directory as the customer config file
  * (see initProperties)
    */
STATIC PROCEDURE readLangFiles()
LOCAL cfgPath, langTable,file

  if configFile==NIL
    Error("FEHLER: Config File must be read 1st.||Bitte Herrn Gruhn anrufen.",.t.)
  else

    langFiles:=hb_Hash()
    cfgPath:=getBaseName(configFile)
    for each file in {"deutsch.cfg","englisch.cfg","franz.cfg"}
      if file(cfgPath+BACKSLASH+file)
        langTable:=hb_IniRead( cfgPath+BACKSLASH+file )
        langFiles[file]:=langTable
      endif
    next

  endif
return
/** eop */

/** Gibt alle language properties aus */
PROCEDURE dumpLangProperties()
LOCAL cSection, aSect, ckey, value,file
LOCAL Zeile:=0

  if langFiles==NIL
    readLangFiles()
  endif

  Drucker("BS")

  for each file in langFiles

    @ 2, 0 SAY "Property File: "
    ? file

    FOR EACH cSection IN file:Keys
      ?
      ? "Customer Section [" + cSection + "]"
      aSect:=file[ cSection ]

      FOR EACH cKey IN file[cSection]:Keys
        value:=file[cSection, cKey]
        ? cKey, "=" , if( value == NIL, "", value )
      NEXT
    NEXT
  next

  Drucker("OFF")

RETURN
/** eop */

  /** reads the field name file using hb_IniRead(file)
   *
   * see harbour\tests or \harbour\src\rtl
   *
   */
FUNCTION initFieldText( )
LOCAL cfgFile:=FIELDTEXT_FILE

  // kein Fehler, falls Datei nicht existiert
  IF File( cfgFile )
    hFieldText:=hb_IniRead( cfgFile )
    hb_HCaseMatch( hFieldText, .f. ) // case insensitive match
  else
    hFieldText:=NIL
  endif

RETURN 0 // Bingo
/** eof */

  /** Returns the requested property
   *
   * Returns the passed defaultValue == fieldName() if property is not found
    *
   */
FUNCTION getFieldText( section, key )
LOCAL sec, result:=NIL

  // get section
  IF hFieldText <> NIL .AND. hb_HHasKey( hFieldText, section )
    sec:=hFieldText[ section ]
    hb_HCaseMatch( sec , .f. ) // case insensitive match
    // get key
    IF hb_HHasKey( sec , key )
      result:=sec[key]
    ENDIF
  ENDIF

  IF result == NIL
    result:=toReadable( (section)->(fieldName( (section)->(fieldpos ( key ) ))) )
  ENDIF

RETURN result
/** eof */


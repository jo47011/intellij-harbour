// Test Programm,encr
//

#include "mystd.ch"
#include "hbgtinfo.ch"
#include "hbmxml.ch"

STATIC user

/**
 * Procedure for testing, must be 1st
*/

PROCEDURE Test()

  // initialize the test system
  initTest()
  init_hb()
  initProperties()


  // init error handling
  ErrorSys()

  // login dummy user, so colors etc. are applied
  // init("00")

  // alternativ:
  // farbe_zuweisen()
  init_set() // setze Standard-Werte


  // now start whatever test needed
  // SettingsTest()
  // EmailTest()

  Titel("Test")

  // set( _SET_CODEPAGE, "EN" )

  enterDecrypt(enterEncrypt())
  // altd()

  // login("")


  // editEMail()

  // IF hb_mtvm()
  // Hb_ThreadStart( {|oCrt| hb_gtReload( 'WVT' ) , 
  // oCrt:=hb_gtSelect(), ;
  // WvtNextGetsConsole() , ;
  // oCrt:=NIL ;
  // } )
  // ENDIF

  // TestFax()

  // TestDatev()

  // netTest()

  // xmlTest()
  // SepaWriteTest()
  // SepaReadTest()

  testHtml()

  Message("Bitte @Taste@ dr�cken.","@")

RETURN
/** eop */

/** Enter Test Email */
static procedure editEmail
  if open("Login")
    dbseek(KURZEL_DEVEL)
    if LOGIN->(eof())
      add_rec(0)
      replace LOGIN->Kurzel with KURZEL_DEVEL
      replace LOGIN->Email with MY_EMAIL
    endif
    ErfasseEMail(LOGIN->Email)
    close data
  endif
return



/** Creates all neccesary folders and alike */
static Procedure initTest()
  mkmydir(TEMP)
  mkmydir(MAIL)
  createDBFFiles()
return
/** eop */


/** Returns the current user, or a dummy user if null */
Function getUser()
  if User==NIL
    initUser("00","1")
  endif
return User
/** eof */

/** Creates, sets and returns a new user with the given ID and counter */
Function initUser(kurzel,counter)
  user:=User():new(kurzel,counter)
return User
/** eof */

/** Returns the structure and indices for all existing database files */
Function db_Info(Datei)
return Dbinfo(Datei)
/** eof */

/** Returns the list of all available database files */
FUNCTION getAllDBNames()
RETURN( { } )


/** Returns a list of all available sections & description, e.g. "Etiketten",ETI */
FUNCTION getAllDBSections()
RETURN ({ {"Gesamt",""} })

/** configures the oBrowse object for the Help function (Hilfe.prg) */
FUNCTION HilfDef( oBrowse , oGet , cProg)
  ignore oGet , cProg
return oBrowse
/** eof */
/** F�hrt alle automat. Updates, Datei-Struktur-�nderungen etc. durch
 */
Procedure installUpdate(thisVersion)
  ignore thisVersion
return
/** eop*/

/** returns the num value of the currently installed version - dummy value is 0 */
function getCurrentVersion()
return 0
/** eof */

/** returns the property file name for this application - dummy value is nil, so default.cfg is used */
Function getPropertiesFileName()
return NIL
/** eof */

/** Display a List.dbf record, needed for creation of new records upon list creation */
PROCEDURE ListDisp(Aendern)
  ignore Aendern
RETURN
/** eop */

/** Method will be invoked when system is started with paramter CRONTAB, so far NOP */
Procedure CronJobs()
return
/** eop */

/** ******************************** testing stuff */

PROCEDURE WvtNextGetsConsole()
LOCAL dDate:=ctod( "" )
LOCAL cName:=Space( 35 )
LOCAL cAdd1:=Space( 35 )
LOCAL cAdd2:=Space( 35 )
LOCAL cAdd3:=Space( 35 )
LOCAL nSlry:=0
LOCAL nColGet:=8
LOCAL GetList:={}

  SetMode( 20,51 )
  SetColor( "N/W,N/GR*,,,N/W*" )
  CLS
  hb_gtInfo( HB_GTI_WINTITLE, "WVT Console in WVG Application" )

  // enable mouse
  SET( _SET_EVENTMASK, INKEY_ALL )
  MSetCursor( .T. )

  @ MaxRow(), 0 SAY PadC( "GTWVT in GTWVG Console Gets", maxcol()+1 ) COLOR "W+/B*"

  @ 2, nColGet SAY "< Date >"
  @ 5, nColGet SAY "<" + PadC( "Name", 33 ) + ">"
  @ 8, nColGet SAY "<" + PadC( "Address", 33) + ">"
  @ 15, nColGet SAY "< Salary >"

  @ 3, nColGet GET dDate
  @ 6, nColGet GET cName
  @ 9, nColGet GET cAdd1
  @ 11, nColGet GET cAdd2
  @ 13, nColGet GET cAdd3
  @ 16, nColGet GET nSlry PICTURE "@Z 9999999.99"

  READ

RETURN

/** Sending a fax ***********************************************/
Procedure testFax()
LOCAL oFax:=CREATEOBJECT( "FaxComEx.FaxServer" )
LOCAL oDoc:=CREATEOBJECT( "FaxComEx.FaxDocument" )

  cls
  Titel("Fax versenden")

  oFax:Connect( "" )
  oDoc:Body = "README.txt"
  oDoc:DocumentName = "Fax test"
  oDoc:Recipients:Add( "06391409934" )
  oDoc:ConnectedSubmit( oFax )
  oFax:Disconnect()

  // IF hb_FileExists( "C:\Windows\System32\winfax.dll" )
  // hDLL:=DllLoad( "C:\Windows\System32\winfax.dll" )

  // oWinFax = CreateObject("WinFax.FaxRegisterServiceProviderW")
  // oWinFax = win_OleCreateObject("WinFax.SDKSend")
  // oWinFax = TOleAuto():New( "WinFax.SDKSend" )
  // oWinFax:SetSubject("Test Fax")
  // oWinFax:SetNumber("1234567")
  // oWinFax:SetAreaCode("555")
  // oWinFax:SetCompany("Some Company")
  // oWinFax:AddRecipient() && Required
  // oWinFax:SetPrintFromApp(1)
  // oWinFax:AddAttachmentFile("")
  // oWinFax:Send(1)



  // else
  // Error("WinFax not found.",.t.)
  // endif

return
/** eop */

/** Creating a DATEV Dump file */
procedure testDatev()
LOCAL export:=DatevExport():new()
LOCAL datevRec

  datevRec:=DatevRecord():new()
  datevRec:Umsatz:=12
  datevRec:Konto:=4711
  datevRec:BelegDatum:=ctod("01.01.2012")
  export:add(datevRec)

  datevRec:=DatevRecord():new()
  datevRec:Umsatz:=13
  datevRec:Konto:=4712
  datevRec:BelegDatum:=ctod("01.02.2012")
  export:add(datevRec)

  export:dump()

return
/** eop */

/** tests creating and openin a file right away,
  testing network opening bug at miki */
procedure netTest()
local DateiStru:=TEMP+"\tempStr"

  if open("System")
    copy stru exte to (DateiStru)
    // waitForAccessFile (DateiStru+".dbf")
    use (DateiStru) exclusive ALIAS DatStru
    qout("Success")
  endif
  close data

return
/** eop */

/** erzeugt test xml file */
PROCEDURE xmlTest()

  #xtranslate _ENCODE( <xData> ) => ( hb_base64encode( hb_serialize( mxmlGetCustom( <xData> ) ) ) )

LOCAL tree, group, element, node,doc
LOCAL hData:={=>}

  // mxmlSetErrorCallback( @my_mxmlError() )
  mxmlSetCustomHandlers( @load_c(), @save_c() )

  hData[ "Today" ]:=hb_tsToStr( hb_dateTime() )
  /* etc. */

  tree:=mxmlNewXML()
  // mxmlElementSetAttr( tree, "foo", "bar" )

  doc:=mxmlNewElement( tree, "Document" )
  mxmlElementSetAttr( doc, "xmlns","urn:iso:std:iso:20022:tech:xsd:pain.001.002.03")
  mxmlElementSetAttr( doc, "xmlns:xsi","http://www.w3.org/2001/XMLSchema-instance")
  mxmlElementSetAttr( doc, "xsi:schemaLocation","urn:iso:std:iso:20022:tech:xsd:pain.001.002.03"+;
    " pain.001.002.03.xsd")

  group:=mxmlNewElement( doc, "group" )
  element:=mxmlNewElement( group, "hash" )
  node:=mxmlNewCustom( element, hData )

  mxmlElementSetAttr( element, "type", "custom" )
  mxmlElementSetAttr( element, "checksum", hb_md5( _ENCODE( node ) ) )

  // mxmlNewInteger( hTree, 123 )
  // mxmlNewOpaque( hTree, "opaque" )
  // mxmlNewReal( hTree, 123.4 )
  // mxmlNewText( hTree, 1, "text" )


  mxmlSaveFile( tree, "test.xml", @whitespace_cb() )
  Message("test.xml erzeugt.    Taste","@")

return
/** eop */

/** erzeugt test SEPA xml file */
PROCEDURE sepaWriteTest()
LOCAL sepa:=SEPA():new("4711","Miki-Plastik GmbH Mannheim","DE00123456789","XFGAZSKY")
LOCAL CT

  CT:=CTrecord()
  CT:setCreditor("Jochen Gruhn")
  CT:setIBAN("DE00123456789888555241222")
  CT:setBIC("BGASLJSDL")
  CT:setPurpose("Dies ist ein Test.")
  CT:setValue(217.56)
  sepa:addCreditTransfer(CT)

  sepa:dump("sepa.xml")
return
/** eop */

/** liest ein SEPA xml file */
PROCEDURE sepaReadTest()
  // LOCAL sepa:=SEPA():read("C:\MyProg\hbmiki\DAT\Export\SEPA\MIKI-Commerzbank-2012-07-11-47384.xml")
LOCAL sepa,allCTS,objErr,CT

  BEGIN SEQUENCE
    sepa:=SEPA():read("sepa.xml")
    allCTS:=sepa:getCreditTransfers()
    for each CT in allCTS
      CT:print()
      qout()
    next
  RECOVER USING objErr
    Error(getErrorDispText(objErr))
  END SEQUENCE

return
/** eop */

/** creates an empty fehler and login dbf file */
Function createDBFFiles()
LOCAL updateStructure

  mkMyDir(TEMP)
  mkMyDir(HAUPT)
  mkMyDir(MAIL)

  // System Datei
  if ! file(HAUPT+"\System.dbf")
    updateStructure:={;
      {"VERSION" ,"N", 5,0},;
      {"DRUCKERNR" ,"C", 2,0},;
      {"MOD_DATE" ,"D", 8,0},;
      {"MOD_TIME" ,"N", 5,0},;
      {"MOD_USER" ,"C", 2,0}}

    myDBcreate(HAUPT+"\System" ,updateStructure)

    // erzeuge Dummy-Datensatz
    if ! open("System")
      Error(ACHTUNG+" System.dbf konnte nicht erzeugt werden.",.t.)
    else
      add_rec(0)
    endif
  endif

  // Fehler Datei
  if ! file(HAUPT+"\fehler.dbf")
    updateStructure:={;
      {"DATE" ,"D", 8,0},;
      {"TIME" ,"C", 8,0},;
      {"CODE" ,"N", 4,0},;
      {"DEFAULT" ,"L", 1,0},;
      {"RETRY" ,"L", 1,0},;
      {"SUBSTITUTE" ,"L", 1,0},;
      {"DESCRIPT" ,"C", 40,0},;
      {"FILENAME" ,"C", 50,0},;
      {"OPERATION" ,"C", 40,0},;
      {"SEVERITY" ,"N", 1,0},;
      {"SUBCODE" ,"N", 4,0},;
      {"SYSTEM" ,"C", 12,0},;
      {"TRIES" ,"N", 8,0},;
      {"CALL" ,"M", 10,0},;
      {"USER" ,"C", 2,0},;
      {"CLIENTNAME" ,"C", 12,0},;
      {"OSCODE" ,"N", 4,0},;
      {"MOD_DATE" ,"D", 8,0},;
      {"MOD_TIME" ,"N", 5,0},;
      {"MOD_USER" ,"C", 2,0}}

    myDBcreate(HAUPT+"\fehler" ,updateStructure)

    // erzeuge Dummy-Datensatz
    if ! open("Fehler")
      Error(ACHTUNG+" Fehler.tbk konnte nicht angepasst werden.",.t.)
    else
      add_rec(0)
      replace FEHLER->DESCRIPT with "Fehler.dbf Created."
    endif
  endif

  // Login Datei
  if ! file(HAUPT+"\Login.dbf")
    updateStructure:={;
      {"KURZEL" ,"C", 2,0},;
      {"NAME" ,"C", 30,0},;
      {"STDLOHN" ,"N", 6,2},;
      {"KOSTENST" ,"C", 2,0},;
      {"PERSNR" ,"C", 3,0},;
      {"LOG_DAT" ,"D", 8,0},;
      {"LOG_TIME" ,"C", 8,0},;
      {"LOG_MACH" ,"C", 2,0},;
      {"EMAIL" ,"C", 30,0},;
      {"LOGIN1" ,"C", 25,0},;
      {"LOGIN2" ,"C", 25,0},;
      {"LOGIN3" ,"C", 25,0},;
      {"LOGIN4" ,"C", 25,0},;
      {"LOGIN5" ,"C", 25,0},;
      {"LOGIN6" ,"C", 25,0},;
      {"LOGIN7" ,"C", 25,0},;
      {"LOGIN8" ,"C", 25,0},;
      {"LOGIN9" ,"C", 25,0},;
      {"PASSWORT" ,"C", 20,0},;
      {"TELEFON" ,"C", 2,0},;
      {"GRUPPE" ,"C", 1,0},;
      {"DRUCKEN" ,"C", 1,0},;
      {"STAMMDAT" ,"C", 1,0},;
      {"ZEIGEDAT" ,"C", 1,0},;
      {"NURAUSK" ,"C", 1,0},;
      {"SavePos" ,"C", 1,0},;
      {"SaveSize" ,"C", 1,0},;
      {"FontName" ,"C", 30,0},;
      {"FontSize" ,"N", 2,0},;
      {"FontBold" ,"C", 1,0},;
      {"WARNING" ,"C", 1,0}}

    myDBcreate(HAUPT+"\Login" ,updateStructure)

    // erzeuge Dummy-Datensatz
    if ! open("Login")
      Error(ACHTUNG+" Login.dbf konnte nicht erzeugt werden.",.t.)
    else
      add_rec(0)
      replace LOGIN->Name with "Auto-Create Dummy User"
      replace LOGIN->Kurzel with DUMMY_USER

      add_rec(0)
      replace LOGIN->Name with "Software-Entwickler"
      replace LOGIN->Kurzel with KURZEL_DEVEL
      replace LOGIN->DRUCKEN with "J"
      replace LOGIN->STAMMDAT with "J"
      replace LOGIN->ZEIGEDAT with "J"
      replace LOGIN->NURAUSK with "N"
      replace LOGIN->GRUPPE with "N"
      replace LOGIN->EMAIL with MY_EMAIL

      add_rec(0)
      replace LOGIN->Name with "System Benutzer (intern)"
      replace LOGIN->Kurzel with SERVER_LOGIN
    endif
  endif

  // Fenster Datei
  if ! file(HAUPT+"\Fenster.dbf")
    updateStructure:={;
      {"LISTE_KURZ" ,"C", 10,0},;
      {"KURZEL" ,"C", 10,0},;
      {"POSX" ,"N", 4,0},;
      {"POSY" ,"N", 4,0},;
      {"SIZEX" ,"N", 4,0},;
      {"SIZEY" ,"N", 4,0},;
      {"MAXIMIZED" ,"C", 1,0}}

    myDBcreate(HAUPT+"\Fenster" ,updateStructure)

    if ! open("Fenster")
      Error(ACHTUNG+" Fenster.dbf konnte nicht erzeugt werden.",.t.)
    endif
  endif

  // Zeige Datei
  if ! file(HAUPT+"\Zeige.dbf")
    updateStructure:={;
      {"Line" ,"C", 220,0}}

    myDBcreate(HAUPT+"\Zeige" ,updateStructure)

    if ! open("Zeige")
      Error(ACHTUNG+" Zeige.dbf konnte nicht erzeugt werden.",.t.)
    endif
  endif

  // Info Datei - Hilfe Text
  if ! file(HAUPT+"\Info.dbf")
    updateStructure:={;
      {"VAR" ,"C", 20,0},;
      {"PROG" ,"C", 20,0},;
      {"IN_LI" ,"N", 2,0},;
      {"IN_RE" ,"N", 2,0},;
      {"IN_OB" ,"N", 2,0},;
      {"IN_UN" ,"N", 2,0},;
      {"TEXT" ,"M", 10,0},;
      {"MOD_DATE" ,"D", 8,0},;
      {"MOD_TIME" ,"N", 5,0},;
      {"MOD_USER" ,"C", 2,0}}

    myDBcreate(HAUPT+"\Info" ,updateStructure)

    if ! open("Info")
      Error(ACHTUNG+" Info.dbf konnte nicht erzeugt werden.",.t.)
    endif
  endif

  // Drucker Datei
  if ! file(HAUPT+"\Drucker.dbf")
    updateStructure:={;
      {"DRUCKERNR " ,"C", 2,0},;
      {"BEZ       " ,"C", 30,0},;
      {"QUEUE     " ,"C", 30,0},;
      {"FETT_AN   " ,"C", 30,0},;
      {"FETT_AUS  " ,"C", 30,0},;
      {"BREIT_AN  " ,"C", 30,0},;
      {"BREIT_AUS " ,"C", 30,0},;
      {"SCHMAL_AN " ,"C", 30,0},;
      {"SCHMAL_AUS" ,"C", 30,0},;
      {"KLEIN_AN  " ,"C", 30,0},;
      {"KLEIN_AUS " ,"C", 30,0},;
      {"WINZIG_AN " ,"C", 30,0},;
      {"WINZIG_AUS" ,"C", 30,0},;
      {"LR        " ,"C", 2,0},;
      {"LAENGE    " ,"N", 2,0},;
      {"FORMFEED  " ,"C", 10,0},;
      {"INIT_STR  " ,"C", 30,0},;
      {"POSTSCRIPT" ,"C", 1,0},;
      {"DUPLEX    " ,"C", 1,0},;
      {"FORMULAR  " ,"C", 30,0},;
      {"AGB       " ,"C", 30,0},;
      {"INIT_STR2 " ,"C", 30,0},;
      {"MOD_DATE  " ,"D", 8,0},;
      {"MOD_TIME  " ,"N", 5,0},;
      {"MOD_USER  " ,"C", 2,0},;
      {"RAW       " ,"C", 1,0},;
      {"POSX      " ,"N", 2,0},;
      {"POSY      " ,"N", 2,0},;
      {"FONT      " ,"C", 30,0}}

    myDBcreate(HAUPT+"\Drucker" ,updateStructure)

    // erzeuge Dummy-Datensatz
    if ! open("Drucker")
      Error(ACHTUNG+" Drucker.dbf konnte nicht erzeugt werden.",.t.)
    else
      add_rec(0)
      replace DRUCKER->DruckerNr with "BS"
      replace DRUCKER->Bez with "Bildschirm-Ausgabe"
      replace DRUCKER->Laenge with 66

      // Drucker zum Erzeugen von PDF Dateien
      add_rec(0)
      replace DRUCKER->DruckerNr with "PD"
      replace DRUCKER->Bez with "Zum Erzeugen von PDF Dateien"
      replace DRUCKER->Font with "Lucida Console"
      replace DRUCKER->Queue with "PDFCreator"
      replace DRUCKER->Laenge with 66
      replace DRUCKER->LR with "10"
      replace DRUCKER->Raw with "J"
      dbcommit()
      dbunlock()

    endif
  endif

  // Liste Datei
  if ! file(HAUPT+"\Liste.dbf")
    updateStructure:={;
      {"LISTE_KURZ" ,"C", 10,0},;
      {"BEZ       " ,"C", 40,0},;
      {"DRUCKERNR " ,"C", 2,0},;
      {"ART       " ,"C", 1,0},;
      {"ANZAHL    " ,"N", 1,0},;
      {"PDFNAME   " ,"C", 12,0},;
      {"UNT_RAND  " ,"N", 2,0},;
      {"LANDSCAPE " ,"C", 1,0},;
      {"MOD_DATE  " ,"D", 8,0},;
      {"MOD_TIME  " ,"N", 5,0},;
      {"MOD_USER  " ,"C", 2,0}}

    myDBcreate(HAUPT+"\Liste" ,updateStructure)

    if ! open("Liste")
      Error(ACHTUNG+" Liste.dbf konnte nicht erzeugt werden.",.t.)
    else
      add_rec(0)
      replace LISTE->liste_kurz with 'PROTOKOLL'
      replace LISTE->bez with 'Allgemeines Protokoll/Liste'
      replace LISTE->druckernr with 'BS'
      replace LISTE->art with 'K'
      replace LISTE->anzahl with 1
      replace LISTE->pdfname with 'Protokoll'
      replace LISTE->unt_rand with 2
      replace LISTE->mod_date with ctod('  .  .  ')
    endif
  endif

  // Crontab Datei
  if ! file(HAUPT+"\Crontab.dbf")
    updateStructure:={;
      {"NAME     " ,"C", 15,0},;
      {"DATUM    " ,"D", 8,0},;
      {"WOCHENTAG" ,"N", 12,0},;
      {"MONAT    " ,"N", 2,0},;
      {"MOD_DATE " ,"D", 8,0},;
      {"MOD_TIME " ,"N", 5,0},;
      {"MOD_USER " ,"C", 2,0}}

    myDBcreate(HAUPT+"\Crontab" ,updateStructure)

    if ! open("Crontab")
      Error(ACHTUNG+" Crontab.dbf konnte nicht erzeugt werden.",.t.)
    endif
  endif

  close data

return .t.
/** eof */

/** 1st simple html test */
static Procedure testHTML()
LOCAL job:=HTMLJob():new())
  job:StartDoc( "Formular" )
  ? "Hallo die ist eni Test"
  ?
  ? "Und","das","ist","die",3,". Zeile"
  ?? "Selbe Zeile"
  FormFeed()
  job:endDoc()
return
/** eop */


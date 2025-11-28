/**
* Various tools, procedures & functions
*/

#define DEFAULT_INKEY_FLAGS INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN

#define SHUTDOWN_INFO_TEXT1 '"SYSTEM-Arbeiten"'+MY_CR+MY_LF+MY_CR+MY_LF+'"Programm wird beendet."'
#define SHUTDOWN_INFO_TEXT2 '"SYSTEM-Arbeiten"'+MY_CR+MY_LF+MY_CR+MY_LF+'"Programm wurde beendet."'

#include "mystd.ch"
#include "extern.ch"

#include "set.ch"
#include "debug.ch"

#include "hbclass.ch"
// #include "hboo.ch"
#include "Fileio.ch"
#include "SetCurs.ch"
#include "Directry.ch"
#include "hbgtinfo.ch"
#include "hbmxml.ch"
#include "common.ch"
#include "hbver.ch"
#include "hbthread.ch"
#include "mynetio.ch"
#include "dbinfo.ch"
#include "Getexit.ch"

#define MIN_BREITE 45
#define TITEL_COLSEP "|"

#define SCREENSHOT_KEY_SIZE "size"
#define SCREENSHOT_KEY_SEP "_"

/* zeigt Error-Message an
*
*  Parameters:  ErrMess mit | als Zeilentrenner
*               warten:
*               #define ERR_WARTEN  0 (default) alternativ: .t.
*               #define ERR_ESC   1           alternativ: .f.
*               #define ERR_NO_WAIT  2
*               [Mail]  Name an den evtl. MAil geschickt werden soll
*  R�ckgabe  :  immer .f.
*/

FUNCTION Error(ErrMess,warten,Mail)
LOCAL s001:=savescreen()
LOCAL akt_Farbe:=SetColor(COLERR)
LOCAL Cursor:=set( _SET_CURSOR ,.f. )
LOCAL i:=1
LOCAL rows:=MaxRow()
LOCAL cols:=maxCol()
LOCAL mess:={}
LOCAL rowX:=row(),colY:=col()
LOCAL Max_Len:=0
LOCAL links,rechts,oben,unten
  // LOCAL aktSizeMode:=hb_gtInfo( HB_GTI_RESIZEMODE, HB_GTI_RESIZEMODE_FONT )

  // workaround f�r alte Aufrufe
  if valtype(warten)=="U"
    warten:=ERR_WARTEN
  else
    if valtype(warten)=="L"
      if warten
        warten:=ERR_WARTEN
      else
        warten:=ERR_ESC
      endif
    endif
  endif

  // /* Mail an Systemmanager ? */
  if valtype(Mail)<>"U"
    Trouble(Mail,HB_ATokens(errMess,"|"))
  endif

  beep()

  if type("M->qtWidget")<>"U" // we use QT currently
    qtError(ErrMess,warten)
  else
    // old style we show message on default screen

    /* Message splitten */
    ErrMess+="|"
    do while "|" $ ErrMess
      aadd( mess,left(ErrMess,at("|",ErrMess)-1) )
      ErrMess:=substr(ErrMess,at("|",ErrMess)+1,len(ErrMess))
      Max_Len:=Max( Max_Len,len(atail(Mess)) )
    enddo
    Max_Len:=Max( Max_Len, MIN_BREITE )

    aadd(Mess,"")
    do case
    case warten==ERR_WARTEN
      aadd( Mess,Padc("---- Bitte Taste dr�cken ----",Max_Len) )
    case warten==ERR_ESC
      aadd( Mess,Padc("---- ESC = Ende ----",Max_Len) )
    case warten==ERR_NO_WAIT
      // NOP
    OTHERWISE
      Error("Falscher warte-Code bei Function Error"+" :FEHLER !",.t.,"root")
    endcase

    /* Koordinaten */
    links:=Max(0,maxcol()/2-Max_len/2)
    rechts:=maxcol()/2+Max_len/2
    oben:=12-len(Mess)/2
    unten:=12+len(Mess)/2

    @ oben-1,links-2 clear to unten+1,rechts+2
    @ oben-1,links-2 to unten+1,rechts+2 DOUBLE
    for i:=1 to len(Mess)
      @ oben+i-1,links say Mess[i]
    next

    if warten==ERR_WARTEN
      Message("Bitte @Taste@ dr�cken","@",,,INKEY_KEYBOARD + INKEY_RDOWN)
      // we need min/max here in case window was resized meanwhile
      restscreen(0,0,min(rows,maxrow()),min(cols,maxcol()),s001)
      // restscreen(,,,,s001)
    endif
  endif
  setcolor(Akt_Farbe)
  set( _SET_CURSOR ,Cursor )

  @ rowX,colY say ""

  // hb_gtInfo( HB_GTI_RESIZEMODE, aktSizeMode )

RETURN(.f.)
/** eof */

  /* Message
  *
  * Ausgabe einer Nachrichtenzeile, bzw. einfache Abfrage
  * Parameter:
  *   Text     ==String mit m�glichen Antworten
  *   Abfrage  =="@", alle Eingaben erlaubt
  *   default_a== optional Vorschlag falls Abfrage
  *   sound    == .t.     falls Aufforderungs-Beep erw�nscht !
  */

FUNCTION Message(Text , Abfrage , default_a , sound , inkeyValues )
LOCAL akt_Farbe
LOCAL GetList:={}, taste:=0
LOCAL ant:=.t. , invers:=.f. , erst:=.t.
LOCAL bLastHandler, objErr
  // default inkeyValues:=INKEY_KEYBOARD + INKEY_LDOWN
  default inkeyValues:=INKEY_KEYBOARD

  if type("M->qtWidget")<>"U" // we use QT currently
    return qtMessage( Text , Abfrage , default_a , sound )
  else

    // no message display or feedback when we run in background!!!
    if getUser():isBackgroundTask
      return .t.
    endif

    if valtype(Text)=="U"
      @ Maxrow(),0 clear
      RETURN(.t.)
    endif

    akt_Farbe:=SETCOLOR(COLINV)
    if DEVEL_PROG
      if len(strtran(Text,"@","")) > maxCol()
        Trouble("Message",{procname(1)+":"+left(Text,40)+"Message Text zu lang."})
      endif
    endif

    // trimme Text, falls Zeile zu lang
    // if len(deleteString(text,"@"))>maxCol()
    // text:=right(text,maxCol())
    // endif

    /* Ausgabe der TextZeile mit highlightet Buchstaben */
    High_Out(Text)

    /* evtl. Abfrage */
    IF VALTYPE(Abfrage)<>"U"
      default sound:=.f.
      if sound
        Beep()
      endif
      if Abfrage=="@"

        // the following was NOT working
        // as user MW go to 1.31, die message abfrage danach wird �bersprungen
        // ant:=upper(chr(warte( 0 , INKEY_KEYBOARD + HB_INKEY_GTEVENT )))

        taste:=warte( 0 , inkeyValues )
        if taste == K_LBUTTONDOWN
          ant:="@"
        else
          ant:=upper(chr( taste ))
        endif

        // so gings, aber kein refresh mehr on FOCUS_GAINED :(
        // ant:=upper(chr(warte(0,INKEY_KEYBOARD))) // Nur Keyboard, kein Maus kein Focus

        // send screenshot?
        if ant==chr(KEY_SCREENSHOT)
          sendScreenShot()
        endif

        // pr�fe auf LaunchKeys
        bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
        BEGIN SEQUENCE
          HB_SetKeyCheck( taste , procName() , NIL , NIL )
        RECOVER USING objErr
          email(MY_EMAIL,"ERROR: SetKey:"+str(taste)+" failed in Message.",getErrorText(objErr))
        END SEQUENCE
        MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

      else
        /* Default-Wert anggeben ? */
        if valtype(default_a)=="U"
          ant:=space(1)
        else
          ant:=default_a
        endif

        SetPos( Row(), Col()+1 )
        AAdd( GetList, _GET_( ant, "ant", "!" ):display() )
        do while ! (ant $ Abfrage ) .and. ! ABBRUCH .or. erst
          erst:=.f.
          ReadModal(GetList)

          // // read now - with exit on resize events
          // ReadModal( GetList, NIL,NIL,.t. )
          // if len(GetList)>0 .and. GetList[1]:exitState == GE_RESIZE_EVENT
          // altd()
          // endif

        enddo
        GetList:={}
        if ABBRUCH
          ant:=chr(255)
        endif
      endif
      Message() // Ausgabe-Zeile l�schen
    endif
    SETCOLOR(akt_Farbe)
  endif
RETURN(ant)
/* EOF Message */



    /**
    * Encrypts the passed String with the default passwort
    *
    * Info: we do not use hb_crypt / hb/decrypt here as the result
      contains special characters which can not be stored without loss
      in the config file and the CVS system.
    */
FUNCTION encrypt(text)
LOCAL result:="",i
  if text==NIL
    return NIL
  endif

  // result:=hb_crypt(text,CRYPT_PASSWORT)
  /* gehe jedes Zeichen einzeln durch */
  for i:=1 to len(Text)
    result+=chr(asc(substr(Text,i,1))+if(mod(i,2)==0,1,2))
  next

return result
/** eof */

    /**
    * Decrypts the passed String with the default passwort
    */
function decrypt(text)
LOCAL result:="",i
  if text==NIL
    return NIL
  endif

  // result:=hb_decrypt(text,CRYPT_PASSWORT)
  for i:=1 to len(Text)
    result+=chr(asc(substr(Text,i,1))-if(mod(i,2)==0,1,2))
  next

return result
/** eof */

    /**
    * Decrypts the entered String with the default passwort
    */
FUNCTION enterDecrypt(text)
LOCAL GetList:={}
  default text:=space(20)

  cls
  titel("Passwort decryption")
  @ 10,20 say "Passwort" get text
  read
  @ 10,50
  qqout(" -> ")
  qqout(decrypt(trim(text)))
  Message("Bitte @Taste@ dr�cken","@")
  cls
return decrypt(trim(text))
/** eop */

    /**
    * Encrypts the entered String with the default passwort
    */
FUNCTION enterEncrypt(text)
LOCAL GetList:={}
  default text:=space(20)

  cls
  titel("Passwort encryption")
  @ 10,20 say "Passwort" get text
  read
  @ 10,50
  qqout(" -> ")
  qqout(encrypt(trim(text)))
  Message("Bitte @Taste@ dr�cken","@")
  cls
return encrypt(trim(text))
/** eop */

    /* Procedure Beep
    *
    * piept !
    */
PROCEDURE Beep(Action)
  // if ! AT_HOME
  if valtype(Action)=="U"
    Tone(300,1)
  else
    do case
    case Action==1
      tone(300,2)
      tone(100,2)
    case Action==2
      Tone(300,1)
      Tone(100,1)
      Tone(300,1)
    endcase
  endif
  // endif
RETURN
/** eop */



/* High_Out              (alt)
*
* gibt Message-Text farbig aus
*/
STATIC FUNCTION High_Out(TextZeile)
LOCAL Mesx:=1, OutX:=0, invers:=.f. , tz1
LOCAL Auff, Dist

  TextZeile=" "+alltrim(TextZeile)+" "

  // replace escaped @ "\@" mit dummy character
  TextZeile=strtran(TextZeile , "\@" , chr(255) )

  tz1=strtran(TextZeile,"@","")
  if len(Tz1) < 36
    auff=int( (36-len(Tz1)) /2)
    TextZeile=space(auff)+TextZeile+space(auff)
    tz1=strtran(TextZeile,"@","")
  endif
  // OutX=max( maxCol()/2 - (MAX(len(TZ1)+2,36) /2) , 0 )
  if len(TZ1) > maxcol()
    OutX=0
  else
    outX:=int(maxCol()/2 - len(TZ1)/2)+1
  endif
  SETCOLOR(COLNOR)
  @ Maxrow(),0 clear
  SETCOLOR(COLINV)
  if left(TextZeile,1)="@"
    invers:=.t.
    TextZeile=substr(TextZeile,2,len(TextZeile))
  endif
  do while len(TextZeile) > 0
    dist:=at("@",TextZeile)
    if dist = 0 // kein @ mehr vorhanden
      dist=len(TextZeile)+1
    endif


    @ Maxrow(),OutX say left(strtran(TextZeile , chr(255) , "@" ) , dist-1 )
    OutX=OutX+dist-1
    TextZeile=substr(TextZeile,dist+1,len(TextZeile))
    invers=.not. invers
    if invers
      SETCOLOR(COLERR)
    else
      SETCOLOR(COLINV)
    endif
  enddo
  SETCOLOR(COLNOR)
return(.t.)
/*** EOF Out() ***/

/* Procedure Fenster
*
* �ffnet ein Fenster mit Schatten an den �bergebenen Koordinaten
*
*/
PROCEDURE Fenster(ob,li,unt,re,titel,printFrame,double)
  default printFrame:=.t.
  default double:=.f.

  hb_shadow(ob,li,unt,re)
  @ ob,li clear to unt,re
  if printFrame
    if double
      @ ob,li to unt,re DOUBLE
    else
      @ ob,li to unt,re
    endif
  endif
  if titel<>NIL
    titel:=" "+titel+" "
    @ ob,li+(re-li)/2-len(titel)/2 say titel
  endif

RETURN
/** eop */



/* 
* Logbuch aller auftretenden Fehler
*
* schreibt in die Datei .\dat\mail\"ziel".txt
* bei schwerwiegenden Fehlern eine EMail an MY_EMAIL
*
* Openeing a common file excl. is not safe for MT or multi-user environmemnt
* therefore we need to make some extra checks
*
* Parameter:    Ziel:   C       Kurzbezeichnung Zielperson
*               Text:   A       Array mit Info-Text oder 1 String
*/
PROCEDURE Trouble(ziel,Text)
LOCAL i , j , alte_file:="",fileOpen:=.f.,objErr,retry:=1
LOCAL set_print:=set ( _SET_PRINTER , .f. ) // printer
LOCAL set_alte:=set (_SET_ALTERNATE)
LOCAL set_cons:=set (_SET_CONSOLE)
LOCAL fileName // must be set after dirchange below!!!
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr,.t.) }) // stelle quiet Break ein
LOCAL aktDir

  // gehe in Main Pfad, set alte to .\dat\temp\... geht sonst schief
  if set(_SET_DEFAULT) <> hb_cwd()
    aktDir:=hb_cwd()
    dirchange(set(_SET_DEFAULT))
  endif
  fileName:=MAIL+BACKSLASH+alltrim(ziel)+".inf"

  if set( _SET_ALTERNATE )
    alte_file:=set( _SET_ALTFILE )
    set alte off
    close alte
  endif

  Umgebung(WRITE)

  mkMyDir(MAIL)
  if waitForAccessFile(fileName)

    do while .not. fileOpen .and. retry<=3
      BEGIN SEQUENCE
        set alte to (fileName) Additive
        set alte on
        set cons off
        fileOpen:=.t.
      RECOVER USING objErr
        email(MY_EMAIL,"ERROR: Trouble-Datei access - recovered: "+fileName+" retry"+;
          str(retry),text)
        retry++
      END SEQUENCE
    enddo

    if fileOpen
      QOut( )
      QOut( Hb_dateTime(),Time(),"Teminal:",getUser():getLongID(),"User:",getUser():id,":")
      if valtype(text)=="A"
        for i:=1 to len(Text)
          if valtype(text[i])=="A"
            QOut(space(10))
            for j:=1 to len(Text[i])
              QQOut(Text[i,j])
            next
          else
            QOut(space(10),Text[i])
          endif
        next
      else
        QOut(space(10),Text)
      endif
      QOut( )

      printStackTrace()
    else
      email(MY_EMAIL,"ERROR: Trouble-Datei konnte nicht geschrieben werden:"+fileName,text)
    endif

    set alte off
    close alte
  endif
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

  if ! empty(alte_file)
    set alte to (alte_file) ADDITIVE
  endif
  set (_SET_ALTERNATE, set_alte)
  set (_SET_CONSOLE, set_cons)

  Umgebung(LOAD)
  set( _SET_PRINTER , set_print )

  /* schicke evtl. Trouble Email */
  if lower(ziel) $ lower(BIG_ERROR)
    TroubleEmail(Text)
  endif

  if aktDir<>NIL
    dirchange(aktDir)
  endif

RETURN
/** eop */


/* 
* versendet Email an MY_EMAIL
* Info aus Fehler-Datei !
*/

PROCEDURE TroubleEmail(Text,subject)
LOCAL aktSel:=Alias()
LOCAL descr,Code:=-1,errFileName,aktSatz,description:=""
LOCAL subText:="",debugFile // ,zipDebugFile,screenFile
LOCAL bodyText:={},stack
LOCAL alte_file,Zeile:=0

  default text:={"kein Text"}
  default subject:="ERROR "+CUSTOMER_NAME+": "

  // increase unique counter for temp files, to avoid concurreny problems
  getUniqueCounter(COUNTER_INCREASE)

  if valtype(text)=="C"
    text:={strtran(text,"|",MY_CR+MY_LF)}
  endif

  Umgebung(WRITE)

  /* teste ob letzte 5 Fehler selber FehlerCode */
  if select("Fehler") > 0
    sele Fehler
    aktSatz:=FEHLER->(Recno())
    Code:=FEHLER->CODE
    Descr:=FEHLER->descript
    errFileName:=FEHLER->FileName
    go bottom
    skip -5
    do while ! eof()
      if Code==FEHLER->Code .and. descr==FEHLER->descript .and. aktSatz<>FEHLER->(Recno())
        Umgebung(LOAD)
        RETURN // Abbruch !
      endif
      skip
    enddo
    /* gehe auf akt. Fehler */
    go (aktSatz)
    description:=FEHLER->DESCRIPT
  endif

  aadd(bodyText,"A C H T U N G - Fehler bei "+CUSTOMER_NAME+if(AT_HOME,+"@home",""))
  aadd(bodyText,"" )
  // aadd(bodyText,"Bitte verst�ndigen Sie sofort Ihren Programmierer:")
  // aadd(bodyText,"email: "+MY_EMAIL )
  // aadd(bodyText,)
  aadd(bodyText, ttoc(Hb_dateTime())+" Terminal: "+getUser():getLongID()+" User: "+getUser():id+;
    ":")
  aadd(bodyText, space(10)+"akt.Datei: "+aktSel )
  if select("Fehler") > 0
    aadd(bodyText,space(10)+"DATE      :"+dtoc(FEHLER->DATE) )
    aadd(bodyText,space(10)+"TIME      :"+FEHLER->TIME )
    aadd(bodyText,space(10)+"MYTIME    :"+mytime(FEHLER->Mod_TIME) )
    aadd(bodyText,space(10)+"CODE      :"+str(FEHLER->CODE,4) )
    // FIXME: add Message ErrorMessage(objErr)) to fehler.dbf
    //aadd(bodyText,space(10)+"MESSAGE   :"+FEHLER->Message)
    aadd(bodyText,space(10)+"DEFAULT   :"+if(FEHLER->DEFAULT,"Y","N") )
    aadd(bodyText,space(10)+"RETRY     :"+if(FEHLER->RETRY,"Y","N") )
    aadd(bodyText,space(10)+"SUBSTITUTE:"+if(FEHLER->SUBSTITUTE,"Y","N"))
    aadd(bodyText,space(10)+"DESCRIPT  :"+FEHLER->DESCRIPT )
    aadd(bodyText,space(10)+"FILENAME  :"+FEHLER->FILENAME )
    aadd(bodyText,space(10)+"OPERATION :"+FEHLER->OPERATION )
    aadd(bodyText,space(10)+"OSCODE    :"+str(FEHLER->OSCODE,4) )
    aadd(bodyText,space(10)+"SEVERITY  :"+str(FEHLER->SEVERITY,4) )
    aadd(bodyText,space(10)+"SUBCODE   :"+str(FEHLER->SUBCODE,4) )
    aadd(bodyText,space(10)+"SYSTEM    :"+FEHLER->SYSTEM )
    aadd(bodyText,space(10)+"ClientName:"+FEHLER->ClientName)
    aadd(bodyText,space(10)+"UserName  :"+FEHLER->UserName)
    aadd(bodyText,space(10)+"TRIES     :"+str(FEHLER->TRIES,4) )
    aadd(bodyText,space(10)+"SELECTED  :"+aktSel )
    // aadd(bodyText,space(10)+"CALL      :"+FEHLER->CALL ) , geht nicht,also aufrollen:
    aadd(bodyText,"" )
  endif

  stack:=stackTrace()
  aeval(stack,{ |s| aadd(bodytext,space(10)+s)})

  aadd(bodyText,"Text:")
  if valtype(Text)=="A"
    aeval(text,{ |s| aadd(bodyText,space(10)+s)})
  else
    aadd(bodyText,space(10)+Text)
  endif

  // alle Variablen und Debug-Infos
  if set( _SET_ALTERNATE )
    alte_file:=set( _SET_ALTFILE )
    set alte off
    close alte
  endif

  debugFile:=MAIL+BACKSLASH+"debug-"+getUser():getLongID()+"-"+getFileStyleDate()+".txt"
  //zipDebugFile:=getFileBaseName(debugFile) + ".zip"

  // No absolute path for sources in zip here -> zip needs relative path
  // debugFile:=substr(debugFile , len(HB_CWD()) + 1 )

  set alte to (debugFile)
  set alte on
  set cons off
  qqout( "Debug-Infos: ",dateTime())
  qout()
  qout( getDebugDetails( aktSel ))

  set alte off
  close alte

  // now zip debug file, added 20160824
  // if ! hb_ZipFile( zipDebugFile , { debugFile } , 9 , nil ,.t.,nil,.t.,.t.)
  // zipDebugFile:=debugFile // send w/o compression
  // endif

  if ! empty(alte_file)
    set alte to (alte_file) ADDITIVE
    set alte on
  else
    set cons on
  endif

  // schicke EMail intern & extern#
  if ! empty(description)
    subText:=description
  else
    if len(text)>0
      subText:=text[1]
    endif
  endif

  // screenshot currently blocked:
  // Exception calling "Send" with "1" argument(s): "Exceeded storage allocation. The server response was: 5.7.0 This message was
  // blocked because its content presents a potential"
  // if ! getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN
  // screenFile:=MAIL+BACKSLASH+"screenshot-"+getUser():id+"-"+getFileStyleDate()+;
  // "-" + SCREENSHOT_KEY_SIZE + SCREENSHOT_KEY_SEP + ;
  // alltrim(str(hb_gtInfo(HB_GTI_SCREENWIDTH))) + SCREENSHOT_KEY_SEP +;
  // alltrim(str(hb_gtInfo(HB_GTI_SCREENHEIGHT))) + SCREENSHOT_KEY_SEP +;
  // hb_gtInfo( HB_GTI_FONTNAME ) + SCREENSHOT_KEY_SEP +;
  // alltrim(str(hb_gtInfo( HB_GTI_FONTWIDTH ))) + SCREENSHOT_KEY_SEP +;
  // "."+SCREENSHOT_EXT
  // screenFile(screenFile)
  // EMail(MY_EMAIL,trim(subject) +": "+subText,;
  // bodyText,{screenFile,debugFile},getProperty("Email.attachment.delete","J")=="J")
  //
  // else
  EMail(MY_EMAIL,"ERROR "+CUSTOMER_NAME+": "+;
    subText,bodyText,{debugFile},getProperty("Email.attachment.delete","J")=="J")
  // endif

  Umgebung(LOAD)

RETURN

/** Liefert einen String mit detaillierten Infos zu allen Public, Local Variablen etc. */
function getDebugDetails( aktSel )
LOCAL cString:=""
LOCAL vars,i,j,temp

  default aktSel:=alias()

  // public vars
  vars:=__MVSYMBOLINFO()
  cString += "Public Variables" + hb_eol()
  cString += "================" + hb_eol()
  for i:=1 to len(vars)
    cString += vars[i,1]+":="
    cString += toString(vars[i,2]) + hb_eol()
  next
  cString += hb_eol()

  // print paramter of last called functions
  cString += "Parameter/Local" + hb_eol()
  cString += "===============" + hb_eol()
  i:=1
  do while ( !Empty(ProcName(i)) )
    cString += ProcName(i)+"("
    temp:=hb_aParams(i)
    for j:=1 to len(temp)
      cString += toString(temp[j]) + ", "
    next
    // remove trailing komma ,
    cString:=trim(cString)
    if right(cString,1)==","
      cString:=left(cString,len(cString)-1)
    endif
    cString += +")" + hb_eol()
    cString += "Line:"+alltrim(str(ProcLine(i))) + hb_eol()

    // local vars of calling functions
    vars:=__DBGVMLOCALLIST( i )
    for j:=1 to len(vars)
      cString += str(j,4)+":"
      cString += toString(vars[j]) + hb_eol()
    next
    cString += hb_eol()
    cString += hb_eol()
    i++
  enddo
  cString += hb_eol()

  // alle settings
  cString += hb_eol()
  cString += "Settings:" + hb_eol()
  cString += "=========" + hb_eol()
  for i:=1 to _SET_COUNT
    temp:=left(if(len(ALL_SETTINGS_NAMES)>=i,ALL_SETTINGS_NAMES[i],"unknown")+space(20),20)
    cString += str(i,3)+" "+temp+":" + toString(Set(i))+ hb_eol()
  next
  cString += hb_eol()
  for i:=HB_SET_BASE to HB_SET_BASE+HB_SET_COUNT+1
    temp:=left(if(len(ALL_HB_SETTINGS_NAMES)>=i-HB_SET_BASE+1,ALL_HB_SETTINGS_NAMES[i-HB_SET_BASE+;
      1],"unknown")+ space(20),20)
    cString += str(i,3)+" "+temp+":" +toString(Set(i))+ hb_eol()
  next

  // alle offenen Dateien & Relations
  cString += hb_eol()
  cString += "Open Files:" + hb_eol()
  cString += "===========" + hb_eol()
  cString += "Selected :" + aktSel + hb_eol()
  cString += hb_eol()
  i:=1
  do while ! empty(alias(i))
    temp:=Alias(i)
    cString += 'Workarea.: ' + (temp)->(Str( Select()) ) + hb_eol()
    cString += 'Alias....: ' + temp + hb_eol()
    cString;
      += 'Recno....: ' + (temp)->(Str( Recno()))+"/"+alltrim((temp)->(Str( Reccount()))) + hb_eol()
    cString += 'isLocked.: ' + (temp)->(toString(isLocked())) + hb_eol()
    cString += '1. Field.: ' + toString((temp)->(fieldget(1))) + hb_eol()
    cString += 'Filter...: ' + (temp)->(DbFilter() ) + hb_eol()
    cString += '....Index: ' + (temp)->(ordFor() ) + hb_eol()
    if (temp)->(indexOrd()) > 0
      cString += 'Order....: ' + str((temp)->(IndexOrd())) + hb_eol()
      cString += 'Index Key: ' + (temp)->(IndexKey( IndexOrd())) + hb_eol()
    endif
    j:=1
    do while ! empty((temp)->(DbRelation(j)))
      cString += 'Relation.: ' + (temp)->(DbRelation(j))
      cString += ' into ' + alias((temp)->(DbRSelect(j))) + hb_eol()
      j++
    enddo
    cString += hb_eol()
    i++
  enddo


return cString
/** eof */

  /* Function Warte ***********************************
  *
  * Parameter: Zeit
  *            Inkey-Flags: default ist s.o. INKEY_KEYBOARD + HB_INKEY_GTEVENT + INKEY_LDOWN
  *            disableFocusEvents: wenn .t. werden die Focus-Events protokolliert aber nicht
  *                                an die aufrufende Prozedur weitergegeben
  *                                wird gebraucht um den 1. Maus-Klick bei Focus_Gained abzufangen!
  *
  */

FUNCTION Warte(Zeit, hb_inkey_flags, disableFocusEvents)
LOCAL Taste,pflicht:=.f.
LOCAL ink_flags

  _thread static lastTaste

  if hb_inkey_flags==NIL
    // Info: falls Aufruf ohne besondere Flags, dann nur HB_K_CLOSE durchlassen
    // FOCUS/Resize Events werden unten abgefangen
    ink_flags:=DEFAULT_INKEY_FLAGS
    default disableFocusEvents:=.t.
  else
    ink_flags:=hb_inkey_flags
    default disableFocusEvents:=.f.
  endif

  Taste:=Inkey(,ink_flags)

  if zeit<>NIL // nur falls Zeit angegeben
    if Zeit=0
      if getUser():id==SERVER_LOGIN
        Zeit:=TIMEOUT_SERVER_WAIT
      else
        Zeit:=TIME_CHECK
        pflicht:=.t.
      endif
    endif
    do while Taste == 0

      taste:=INKEY(Zeit,ink_flags)

      // set alte to foo.txt additive
      // set alte on
      // set cons off
      // qout(taste)
      // close alte
      // set cons on

      time_disp() // Ausgabe der Uhrzeit

      // always disable 1st. mouse click after focus event
      // disable windows close click
      switch taste
      case HB_K_CLOSE
        Error(getProperty("System.close.window.message","Programm bitte mit Men�punkt 99 beenden.";
          ),.t.)
        lastTaste:=taste
        Taste:=0
        loop
      case K_LBUTTONDOWN
      case K_RBUTTONDOWN
        if lastTaste == HB_K_GOTFOCUS
          lastTaste:=taste
          taste:=0
          loop
        endif
        exit
      endswitch


      // Disable some hb events for message input
      if disableFocusEvents

        switch taste
          // ignore all other focus events
        case HB_K_GOTFOCUS
        case HB_K_RESIZE
        case HB_K_LOSTFOCUS
        case HB_K_CONNECT
        case HB_K_DISCONNECT
          lastTaste:=taste
          Taste:=0
          loop
          // exit -> unreachable code
        endswitch
      endif
      lastTaste:=taste

      checkShutdownRequest()

      // If limit<>0 we bail out
      if ! pflicht
        exit
      endif

    enddo
  endif

  RETURN(Taste) // keine Zeitangabe
/* EOF Warte */

/** pr�ft ob das Sytem von extern aus beendet werden soll */
function checkShutdownRequest()
  _thread static shutdownInfo
  default shutdownInfo:=.f.

  // shutdown requested?
  if getUser():id<>SERVER_LOGIN
    if file(SHUTDOWN_S) .or. file(SHUTDOWN_S+"-"+getUser():getLongID())
      if file(SHUTDOWN_1) .or. file(SHUTDOWN_1+"-"+getUser():getLongID())
        Error(ACHTUNG+"Systemarbeiten.  Bitte das Programm beenden.||         Danke.|",ERR_NO_WAIT)
        return 1
      elseif file(SHUTDOWN_2) .or. file(SHUTDOWN_2+"-"+getUser():getLongID())
        Trouble("shutdown", { "Shutdown 2 - User: "+getUser():id } )
        Error(ACHTUNG+"Systemarbeiten.  1. Versuch Programm wird beendet.",ERR_NO_WAIT)
        keyboard chr(K_ESC)+chr(K_ESC)+chr(K_ESC)+chr(K_ESC)+chr(K_ESC)+chr(K_ESC)+;
          getProperty("System.close.window.keyboard","99")+CHR(K_RETURN)
        if ! shutdownInfo
          extMsgBox(SHUTDOWN_INFO_TEXT1)
          shutdownInfo:=.t.
        endif
        return 2
      elseif file(SHUTDOWN_3) .or. file(SHUTDOWN_3+"-"+getUser():getLongID())
        Trouble("shutdown", { "Shutdown 3 - User: "+getUser():id } )
        if ! shutdownInfo
          extMsgBox(SHUTDOWN_INFO_TEXT2)
          shutdownInfo:=.t.
        endif
        down(.f.,.f.) // don't wait for background tasks
      endif
    endif
  endif
return 0
/** eof */


/*
* speichert den augenblicklichen Kontext
*       z.Zt. implementiert:    - akt. Datei
*                               - akt. Index
*                               - akt. Position (recno(), seit 2.4.2013)
*                               - akt. Relationen
*                               - BS
*                               - Farben / Color
*                               - Cursor
*                               - Windows Title
*                               - Filter   (seit 28.01.15)
*                               - PrintJob (seit 09.04.15)
* Achtung: ANZAHL_UMGEB_SPEICHERN ist die Anzahl der Parameter die gespeichert
*          werden sollen + 1 (f�r ProgName)
*
* Parameter:       WRITE     - merket sich die Indexorder des akt. Bereichs und s.o.
*                  WRITE_ALL - merkt sich die Indexorder, auch anderer Arbeitsbereiche  und s.o.
*                  LOAD      - wiederherstellen
*                  CHECK     - guckt beim Beenden des Programms ob Umgebung leer
*                              ansonsten Programmierfehler: Umgebung(LOAD) vergessen !
*                  DISMISS_NEXT - l�scht n�chste gespeicherte Umgebung
*                  DISMISS_ALL  - l�scht gespeicherte Umgebung, nur bei ShutDown()
*
  *
  * Infos werden folgendermassen gespeichert:
  *

  {U_NAME,U_SCREEN,U_COLOR,U_CURSOR,U_ROWS,U_COLS,U_CURRENT_ALIAS,U_WIN_TITLE,U_PRINTJOB,;
    { {U_ALIAS,U_ORDER,U_RECNO,U_FILTER, { dbRelation, child }},;
      {U_ALIAS,U_ORDER,U_RECNO,U_FILTER, { dbRelation, child }},;
      {U_ALIAS,U_ORDER,U_RECNO,U_FILTER, { dbRelation, child }},;
      {U_ALIAS,U_ORDER,U_RECNO,U_FILTER, { dbRelation, child }} } }


  *
  * INFO: to save keys, sue HB_SetKeySave() in calling file
*/

  // allgemeine Infos
  #define U_NAME 1 // procname immer zuerst !
  #define U_SCREEN 2
  #define U_COLOR 3
  #define U_CURSOR 4
  #define U_ROWS 5
  #define U_COLS 6
  #define U_CURRENT_ALIAS 7
  #define U_WIN_TITLE 8
  #define U_PRINTJOB 9
  #define U_WRITE_ALL 10
  // #define U_DB_DATA 10 // is always the last, is determined in sources below
  #define UMGEB_STRING_GLOBAL procname(1),savescreen(),setcolor(),setcursor(),maxRow(),maxCol(),;
    alias(), hb_gtInfo(HB_GTI_WINTITLE),getUser():getCurrentPrintJob(.t.,.t.),action==WRITE_ALL

  // je datei bei WRITE_ALL
  #define UMGEB_STRING_DB_ALL alias(i),(alias(i))->(indexord()),(alias(i))->(recno()),;
    getFilterCond(i),getRelations(i),getOrdNames(i)

  // akt datei bei WRITE
  #define UMGEB_STRING_DB alias(),(alias())->(indexord()),(alias())->(recno()),;
    getFilterCond(),getRelations(),getOrdNames()

  // Infos zu Dateien (WRITE = nur aktuelle , WRITE_ALL = alle offenen Dateien)
  #define U_ALIAS 1
  #define U_ORDER 2
  #define U_RECNO 3
  #define U_FILTER 4
  #define U_RELA 5
  #define U_ORDNAMES 6

PROCEDURE Umgebung(action)
  _thread static aUmgeb:={}
LOCAL Um_Nr:=0 , aInfo:={}
LOCAL aDBInfos:={} , Merk_Sel:=""
LOCAL Temp_alle:=0
LOCAL i:=1,db,wasOpen
LOCAL col,row, tempFilter

  /**** speichern ****/
  if action==WRITE
    aadd(aUmgeb,{ UMGEB_STRING_GLOBAL, {{ UMGEB_STRING_DB }} } )

    /**** speichern alles ****/
  elseif action==WRITE_ALL
    Merk_Sel:=alias()

    // FIXME: in case an exclusive lock can not be granted a new area will be selected on
    // every try, resulting in alias(x)="" causing problems on Umgebung( WRITE_ALL )
    // see datei.prg dbUseArea( .T., ...)

    /* merke alle Order-Nr. aller Bereiche */
    do while ! empty(alias(i)) // solange DatenBank offen
      aadd( aDBInfos , { UMGEB_STRING_DB_ALL } )
      i++
    enddo
    if ! empty(Merk_Sel)
      select (Merk_sel)
    endif
    aadd(aUmgeb,{ UMGEB_STRING_GLOBAL , aDBInfos } )

    /**** lesen ****/
  elseif action==LOAD
    if ! (aUmgeb[Um_Nr:=len(aUmgeb),U_NAME]) == procname(1)
      Umgebung(CHECK) // ausdrucken der Umgebung

      // pr�fe n�chste Ebene, falls eins vergessen wurde

      /* l�sche Feld in Array */
      asize(aUmgeb,Um_Nr-1)
      if ! (aUmgeb[Um_Nr:=len(aUmgeb),U_NAME]) == procname(1)
        Umgebung(CHECK) // ausdrucken der Umgebung
        Error( UNKNOWN_ERROR )
        down() // dann lieber Ende
      endif
    endif

    // setzte DB_Daten zuerst, l�sche alle relations (seit 21.7.2014)
    aDBInfos:=aUmgeb[Um_Nr,len(aUmgeb[Um_nr])] // was U_DB_DATA before
    for i:=1 to len(aDBInfos)
      if aDBInfos[i,U_ALIAS]<>NIL .and. ! empty(aDBInfos[i,U_ALIAS])

        // Datei bereits closed? -> dann wieder �ffnen, added 25.9.2013
        if select(aDBInfos[i,U_ALIAS]) == 0
          open( aDBInfos[i,U_ALIAS] )
        else
          select(aDBInfos[i,U_ALIAS])
        endif
        ordSetFocus(aDBInfos[i,U_ORDER])

        // clear previous relations!
        dbclearRelation()
      endif
    next

    // seit 21.7.2104: alle relas & filter am Schluss setzen
    for i:=1 to len(aDBInfos)
      if aDBInfos[i,U_ALIAS]<>NIL .and. ! empty(aDBInfos[i,U_ALIAS])
        select(aDBInfos[i,U_ALIAS])
        restoreRelations(aDBInfos[i,U_RELA])
        restoreOrdNames(aDBInfos[i,U_ORDNAMES])
      endif
    next

    // gehe auf urspr. Datensatz, hier neu seit 11.8.2013
    for i:=1 to len(aDBInfos)
      if aDBInfos[i,U_ALIAS]<>NIL .and. ! empty(aDBInfos[i,U_ALIAS])

        select(aDBInfos[i,U_ALIAS])

        // filter setzen, if applicaple
        if aDBInfos[i,U_FILTER] <> dbfilter()
          if empty( aDBInfos[i,U_FILTER] )
            dbClearFilter()
          else
            // set filter to AUFTRAG->geloescht$"N "
            tempFilter:=aDBInfos[i,U_FILTER]
            set filter to &(tempFilter)

            // 24.2.15 die hier gehen nicht
            // set filter to &(aDBInfos[i,U_FILTER])
            // dbSetFilter( { || &(aDBInfos[i,U_FILTER])} , aDBInfos[i,U_FILTER] )

          endif
        endif

        // Info: nur falls Satz unterschiedlich
        if (alias())->(recno()) <> aDBInfos[i,U_RECNO]
          (alias())->(dbgoto( aDBInfos[i,U_RECNO] ) )
        endif

      endif
    next

    // NOCHMAL: gehe auf urspr. Datensatz, neu seit 23.2.2105
    //
    // wird gebraucht falls beim rela setzen ein anderer (eigentlich
    // aktuellerer) Datensatz ausgew�hlt wurde. Wir wollen aber den
    // Status-Quo von vorher. 2x sollte langen, da nur abweichende
    // Datens�tze gesetzt werden
    for i:=1 to len(aDBInfos)
      if aDBInfos[i,U_ALIAS]<>NIL .and. ! empty(aDBInfos[i,U_ALIAS])

        // Info: nur falls Satz unterschiedlich
        select(aDBInfos[i,U_ALIAS])
        if (alias())->(recno()) <> aDBInfos[i,U_RECNO]
          (alias())->(dbgoto( aDBInfos[i,U_RECNO] ) )
        endif

      endif
    next

    // schliesse alle anderen Dateien, wenn WRTITE_ALL gerufen war
    if aUmgeb[Um_Nr,U_WRITE_ALL]
      i:=1
      do while ! empty(alias(i)) // f�r alle ge�ffneten Dateien
        wasOpen:=.f.
        for each db in aDBInfos // scan aktuelle Umgebungs-String
          if db[U_ALIAS] == alias(i)
            wasOpen:=.t.
            exit
          endif
        next
        if ! wasOpen
          close (alias(i))
        endif
        i++
      enddo
    endif

    // jetzt den Rest assignen
    if aUmgeb[Um_Nr,U_CURRENT_ALIAS]<>NIL .and. ! empty(aUmgeb[Um_Nr,U_CURRENT_ALIAS])
      dbSelectArea(aUmgeb[Um_Nr,U_CURRENT_ALIAS])
    endif

    // Bildschirm Infos nur, falls kein Background Task
    if ! getUser():isBackgroundTask
      if hb_gtInfo(HB_GTI_WINTITLE) <>aUmgeb[Um_Nr,U_WIN_TITLE]
        hb_gtInfo(HB_GTI_WINTITLE,aUmgeb[Um_Nr,U_WIN_TITLE])
      endif
      col:=col()
      row:=row()
      cls
      restscreen(0,0,min(aUmgeb[Um_Nr,U_ROWS],maxrow()),min(aUmgeb[Um_Nr,U_COLS],maxcol()), aUmgeb;
        [Um_Nr,U_SCREEN])
      setcolor(aUmgeb[Um_Nr,U_COLOR])
      setcursor(aUmgeb[Um_Nr,U_CURSOR])
      @ row,col say ""
    endif

    // recover print job, if any
    getUser():setCurrentPrintJob(aUmgeb[Um_Nr, U_PRINTJOB ])

    /* l�sche Feld in Array */
    asize(aUmgeb,Um_Nr-1)

    /**** lesen ****/
  elseif action==DISMISS_NEXT
    if ! (aUmgeb[Um_Nr:=len(aUmgeb),U_NAME]) == procname(1)
      Umgebung(CHECK) // ausdrucken der Umgebung
      RETURN
    endif

    /* l�sche Feld in Array */
    asize(aUmgeb,Um_Nr-1)

  elseif action == CHECK .and. len(aUmgeb) > 0
    aAdd(aInfo, "Umgebung nicht leer !")
    for Um_Nr:=1 to len(aUmgeb)
      aAdd(aInfo,aUmgeb[Um_Nr,1])
    next
    trouble("Umgebung",aInfo)

  elseif action == DISMISS_ALL   /* reset */
    aUmgeb:={}

  endif

RETURN
/** eop */

/** returns the current filter condition
    *
    * returns current if num is nil
*/
static function getFilterCond(num)
LOCAL result
  if num == nil
    result:=(alias())->(dbfilter())
  else
    result:=(alias(num))->(dbfilter())
  endif

  // altd()
  // // now replace " with ' -> caused an error on recovering filter
  // if '"' $ result
  // result:=strtran( result , '"' , "'" )
  // endif

return result
/** eof */

  /** liefert die Relationen des akt. selektierten Bereichs als Array zur�ck oder
    * von select(nArea) wenn nArea<>NIL
    */
function getRelations(nArea)
local result:={},x:=1
LOCAL aktSel

  if nArea<>NIL
    aktSel:=alias()
    dbSelectArea(nArea)
  endif

  do while ! empty(dbRelation(x))
    aadd(result,{dbRelation(x),alias(dbrSelect(x))})
    x++
  enddo

  if aktSel<>NIL
    dbSelectArea(aktSel)
  endif

return result
/** eof */

/** setzt die �bergebenen Relationen f�r akt. selektierten Bereichs */
static function restoreRelations( aRelas )
LOCAL x:=1

  // clear previous relations!
  dbclearRelation()

  do while x<=len(aRelas)
    // set relation to (aRelas[x,1]) into (aRelas[x,2]) ADDITIVE
    dbSetRelation( aRelas[x,2] , &("{|| "+aRelas[x,1]+"}"), aRelas[x,1], .F. )
    x++
  enddo

RETURN .t.
/** eof */

  /** liefert die Index Namen/Tags des akt. selektierten Bereichs als Array zur�ck
    */
function getOrdNames(nArea)
local result:={},x:=1
LOCAL aktSel

  if nArea<>NIL
    aktSel:=alias()
    dbSelectArea(nArea)
  endif

  if ! empty(alias())
    do while ! empty(OrdName(x))
      aadd(result, OrdName(x))
      x++
    enddo
  endif

  if aktSel<>NIL
    dbSelectArea(aktSel)
  endif

return result
/** eof */

/** setzpr�ft die �bergebenen Index/Tag Namen f�r akt. selektierten Bereichs und schlie�t evtl. temp Indices
*
* Achtung dir Reihenfolge ordsetfocus() wird hier nicht ge�ndert, daf�r
*/ 
static function restoreOrdNames( aNames )
LOCAL x:=1

  do while ! empty(OrdName(x))
    if .not. aContains(aNames, OrdName(x))
      ordDestroy( OrdName(x) ) // delete tag TEMP_INDEX
      // index is removed => no increment i needed
    else
      x++
    endif
  enddo

RETURN .t.
/** eof */


/** Returns a unique 2 digit number for the current session:
    e.g.  to avoid concurrency problems scheduling multiple print
    jobs */
function getUniqueCounter(param)
  _thread static count

  do case
  case param=COUNTER_INCREASE
    if valtype(count)<>"N" .or. count>=99
      count=0
    else
      count++
    endif
  case param=COUNTER_GET
    // nop, counter is returned by default
  otherwise
    Error(ACHTUNG+"Unknown paramater",.t.,"root")
  endcase

return right("00"+alltrim(str(count,2)),2)
/** eof */

/** legt das �bergebene Verzeichnis an, falls nicht vorhanden */
function mkMyDir(dir)
LOCAL result:=.t. // we think positive
LOCAL parent

  if dir==NIL .or. empty(dir)
    return .f.
  endif
  parent:=left(dir,rat(BACKSLASH,dir)-1)
  // remove trailing BACKSLASH
  if right(dir,1)==BACKSLASH
    dir:=left(dir,len(dir)-1)
  endif
  if ! file(dir+BACKSLASH+"*.*") .and. len(directory(dir+BACKSLASH,"D"))==0

    if ! file(parent+BACKSLASH+"*.*") .and. len(directory(parent+BACKSLASH,"D"))==0
      if ! mkMyDir(parent)
        trouble("dir",{"Fehler beim anlegen von Parent Directory:"+dir})
        return .f.
      endif
    endif
    result:=(makedir(dir)==0)
    if ! result
      // Nochmal: machmal delay/Netzwerk Problem?
      trouble("dir",{"Fehler beim anlegen von Directory:"+dir+" - try again"})

      hb_idleSleep( 1 )
      result:=(makedir(dir)==0)
    endif

  endif

return result
/** eof */



/** Pr�ft ob eine Datei existiert und wartet darauf bis sie
 *   existiert (result=.t.) oder timeout (expired result=.f.)
 */
Function waitForFile(fileName)
LOCAL start:=seconds()
LOCAL nInfile:=-1, lastChar:=space(1)

  do while ! file(FileName)
    if seconds()-start > TIMEOUT_WAIT_FOR_FILE
      TroubleEmail("Timeout, file not accesable: ||"+filename)
      return .f.
    endif
    inkey(0.5)
    if DEVEL_PROG .or. seconds()-start > TIMEOUT_WARN_FOR_FILE
      Error("Waiting for File:"+fileName,ERR_NO_WAIT)
      if ABBRUCH
        exit
      endif
    endif
  enddo
  if type("M->qtWidget")<>"U" // we use QT currently
    qtError() // close MessageBox
  endif

return .t.
/** eof */

/**
 * Pr�ft ob eine Datei excl. verf�gbar ist:
 *  result=.t. wenn Datei schreibbar opder nicht existent oder
 *  result=.f. when expired/timeout
 */
Function waitForAccessFile(fileName,enableAbort)
LOCAL start:=seconds()
LOCAL nInfile:=-1, lastChar:=space(1)
  default enableAbort:=.t.

  if file(FileName)

    // �ffne exclusiv zum Test
    do while (nInfile:=FOPEN(fileName, FO_READ+FO_EXCLUSIVE))<0
      if seconds()-start > TIMEOUT_WAIT_FOR_FILE
        fclose(nInfile)
        TroubleEmail("Timeout, file not accesable: "+filename)
        return .f.
      endif
      inkey(0.5)
      if DEVEL_PROG .or. seconds()-start > TIMEOUT_WARN_FOR_FILE
        Error("Waiting for Access:"+filename,ERR_NO_WAIT)
        if enableAbort .and. ABBRUCH
          return .f.
        endif
      endif
    enddo
    fclose(nInfile)
    if type("M->qtWidget")<>"U" // we use QT currently
      qtError() // close MessageBox
    endif

  endif
return .t.
/** eof */

/* FUNCTION StackTrace
*
* gibt den akt. Stacktrace als array zurueck
*/
FUNCTION stackTrace()
LOCAL erg:={}
LOCAL i:=1

  Aadd(erg,CLIENT_NAME+"/"+USER_NAME+":")

  while ( !Empty(ProcName(i)) )
    Aadd(erg,Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")" )
    i++
    end

    RETURN erg
/* EOF */

/*
* gibt den akt. Stacktrace als String zurueck m it CR/LF
*/
FUNCTION getStackTraceAsString()
LOCAL erg
LOCAL i:=1

  erg:=CLIENT_NAME+"/"+USER_NAME+":"+MY_CR+MY_LF

  while ( !Empty(ProcName(i)) )
    erg+=Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")"+MY_CR+MY_LF
    i++
    end

    RETURN erg
/* EOF */

/*
*
* pr�ft ob ein Text (Methodenname) im akt. Stacktrace vorkommt
*/
FUNCTION inStackTrace(name)
LOCAL i:=1
LOCAL temp

  while ( !Empty((temp:=ProcName(i))) )
    if upper(name)==temp
      return .t. // Bingo
    endif
    i++
    end

    RETURN .f. // not found
/* EOF */

/* Procedure PrintStackTrace
*
* druckt den akt. Stacktrace
*/
PROCEDURE printStackTrace()
LOCAL Text:=Stacktrace()
LOCAL i:=1

  for i:=1 to len(Text)
    QOut(space(10),Text[i])
  next
  QOut( )

RETURN
/* EOP */

/** Function MyTime
 *
 * Returns a time string HH:MM based on the passed number of seconds since midnight
 * Inversion to seconds()
 *
 *
 */
Function MyTime(secs)
LOCAL mins:=int(secs/60)
LOCAL hours:=int(mins/60)

return right("00"+alltrim(str(hours,2)),2)+;
  ":"+right("00"+alltrim(str(mins-hours*60,2)),2)+":"+right("00"+alltrim(str(secs-mins*60,2)),2)
/** eof */

/** Gibt die Titelzeile, Uhrzeit etc. aus */
PROCEDURE Titel(Text)
LOCAL currColor:=setColor()
  _thread static lastTitel

  if text==NIL
    text:=lastTitel
  else
    lastTitel:=text
  endif

  Text:="  "+trim(Text)+"  "

  if DEVEL_PROG .and. len(Text) > 53
    Error("FEHLER: �berschrift zu lang:|"+Text)
  endif

  SETColor(COLINV)
  @ 0,0 clear to 0,maxCol()
  @ 0,maxCol()/2-len(text)/2 say Text
  @ 0,3 say getUser():date
  // @ 0,3 say Hb_date(), maybe changed by user
  @ 0,13 say TITEL_COLSEP
  time_disp(0) // Ausgabe der Uhrzeit
  @ 0,maxCol()-13 say TITEL_COLSEP
  setcolor(COLERR)
  if getUser():id<>DUMMY_USER
    @ 0,maxCol()-11 say getUser():getLongId()
  endif
  if TEST_PROG
    @ 0,0 say "TEST-PROGRAMM"
    // @ 0,0 say hb_gtInfo( HB_GTI_FONTNAME)
  endif
  if DEVEL_PROG
    @ 0,0 say "DEVEL        "
    // @ 0,13 say "Run:"+str(Memory(2),7)
  endif

  // SETColor(COLNOR)
  SETColor(currColor)

Return
/* EOP Titel */


/* Procedure Time_disp
*
* gibt die akt. Uhrzeit auf BS aus
*
* Parameter: akt TitelZeile (optional)
*/
PROCEDURE Time_disp(Zeile_Neu)
  _thread static farbe
  _thread static time_Zeile:=1
  _thread static Counter
LOCAL spalte:=col()
LOCAL zeile:=row()
LOCAL Cursor:=set( _SET_CURSOR ,.f. )
LOCAL akt_Farbe:=setcolor()
  default counter:=0
  if valtype(Zeile_Neu)=="N"
    time_Zeile:=Zeile_Neu
    farbe:=setcolor()
  endif
  setcolor(Farbe)

  @ time_Zeile,maxCol()-6 say left(time(),5)
  // if DEVEL_PROG
  // @ time_Zeile,0 say "DEVEL      "
  // // @ time_Zeile,0 say "count:"+str(++counter,9) // jojo nur zum Check
  // endif

  setpos(Zeile,Spalte)
  set( _SET_CURSOR ,Cursor)
  set( _SET_COLOR ,akt_farbe )
RETURN
/** eof */

/**
 * l�scht alle Dateien im angegeben Verzeichnis die der Wildcard entsprechen
 * wenn rekursiv=.t. dann werden auch rek. alle verzeichnisse gel�scht
 */
Function myDel(pfad,wildcard,rekursiv)
LOCAL aFiles,i,result:=0
  default Rekursiv:=.f.

  if right(pfad,1)<>BACKSLASH
    pfad:=pfad+BACKSLASH
  endif

  // Sicherheitsabfrage???
  if empty(wildcard)
    Error(ACHTUNG+" wildcard *.* muss angegeben werden.",.t.)
    return .f.
  endif

  aFiles:=directory(pfad+wildcard)
  for i:=1 to len(aFiles)
    if (result:=ferase(pfad+aFiles[i,F_NAME]))<>0
      Error(ACHTUNG+pfad+aFiles[i,F_NAME]+" kann nicht gel�scht werden.|Fehler:"+str(result,5),.t.)
    endif
  next

  if Rekursiv
    aFiles:=directory(pfad+"*.*","D")
    for i:=1 to len(aFiles)
      if ! aFiles[i,F_NAME]$".." .and. isDirectory(pfad+aFiles[i,F_NAME])
        myDel(pfad+aFiles[i,F_NAME],wildcard,.t.)
        // l�sche Verzeichnis falls kein Filter angegeben
        // FIXME: evtl. auch falls Verz.Name dern Filter matched???
        if wildcard=="*.*" .and. (result:=dirRemove(pfad+aFiles[i,F_NAME]))<>0
          Error(ACHTUNG+pfad+aFiles[i,F_NAME]+" kann nicht gel�scht werden.|Fehler:"+;
            str(result,5),.t.)
        endif
      endif
    next
  endif

return .t.
/** eof */

/** FUNCTION setMyKey
*
* entspricht Clipper: Setkey allerdings als Funktion mit .t. als result
*/
FUNCTION SetMyKey(Taste,Fkt)
  setKey(Taste,Fkt)
RETURN .t.
/* EOF */


/** zeigt alle unterst�tzen Sonderzeichen an, s. HilfDef.prg
 */
function ZeigeSonderzeichen
  Hilfe("SONDERZEICHEN",getnew(,,,"Sonderzeichen","X"),"Blubb")
return .t.
/** eof */



/** Erzeugt eine leere TextDatei
 */
Function createEmptyFile(name)
  set alte to (name)
  close alte
return file(name)

/** Ruft MSDOS/Windows runtime UMgebung auf
 *
 *  Parameter: runtime  : der eigentlich aufruf
 *             winParams: opt. parameter f�r WindowsAufruf, geht nicht immer in runtime variable
 *             wait     : wenn true -> wartet aktiv auf Beednung des Befehls (Dos Fenster wird ge�ffnet)
 *                        wenn false -> shellexecute wird im Background ausgef�hrt (default)
 *
 * TODO: Fehler Abfrage
 *
 * Wait ohne Dos-Fenster aber synchron (waiting):

  HB_ProcessValue(nProcessId,.t.)  If this is doing what I think it is
  (halting the process until the process with nProcessId handle has
  finished), then putting it after win_RunDetached( ,
  "C:\PCL_GHOST\PCL6",@nProcessId , .t. )  seems to be what I was
  looking for.

  see https://groups.google.com/forum/#!topic/harbour-users/CjrYXC71Z7I

 */
Function MyRun(runtime,winParams,wait)
LOCAL s001:=savescreen()
LOCAL dosParams:="/c ",test:="", result:=0
  default wait:=.f.

  if DEBUG // .and. ! set( _SET_ALTERNATE )
    cls
    qout("Run-Memory:"+str(Memory(2),7))
    qout(runtime,winParams)
    qout()
    printStackTrace()
  endif

  // TESTME: what about hb_run()???
  if wait
    default winParams:=""
    // FIXME: Use hb_run(), same thing, but returns errorlevel.
    // see: https://groups.google.com/forum/?fromgroups=#!topic/harbour-devel/Y_BQvUDA__Y
    // maybe: switch to hb_process*() API
    result:=hb_run(runtime+" "+winParams) // wartet aktiv, �ffnet schwarzes DOS Fenster
    //run(runtime+" "+winParams) // wartet aktiv, �ffnet schwarzes DOS Fenster, aber ohne result
  else
    // startet neuen Prozess ohne Show!
    // leider auch ohne result

    wapi_SHELLEXECUTE( 0, 0, runtime, winParams, hb_DirBase(), 0 )
    // qout(wapi_SHELLEXECUTE( 0, 0, runtime )) // mit show
  endif


  // damit geht's, aber asynchron :(
  // set ComSpec=C:\WINDOWS\nircmd.exe
  // HB_SetEnv("ComSpec","C:\WINDOWS\nircmd.exe") // das geht nicht!
  // run("execmd "+runtime) // wartet aktiv, �ffnet schwarzes DOS Fenster


  // HB_PROCESSRUN(runtime) // wartet aktiv, �ffnet schwarzes DOS Fenster

  // qqout("Error Code (>32 is ok.):")
  // qout(wapi_SHELLEXECUTE( 0, 0, runtime, , 0, 0 )) // startet neuen Prozess
  // z:b. �ffne iconofied:
  // wapi_SHELLEXECUTE( 0, "edit", "test.bat",nil , nil, 2 ) // startet neuen Prozess
  // wapi_SHELLEXECUTE( 0, nil, "test.bat",nil , nil, 0 ) // startet neuen Prozess


  // FIXME: return DOS error after run
  // if DosError()<>0
  // Error(ACHTUNG+runtime+"|konnte nicht ausgef�hrt werden.  Dos-Fehler:"+str(DosError(),3),.t.)
  // endif

  if DEBUG // .and. ! set( _SET_ALTERNATE )
    // if wait==NIL .or. wait
    Message("Bitte @Taste@ dr�cken","@")
    // endif
  endif

  restscreen(,,,,s001)
return result
  /** eof */

/** testing other hb run function: HB_OpenProcess() */
Function my_hb_run(cmd, params)
LOCAL nBytes, nChild, nStdIN, nStdOUT, nStdERR, stdOut:=space(80), stdErr:=space(80)
LOCAL Zeile:=0

  CLS
  ? "Opening child process:", cmd + " "+ params

  nChild:=HB_OpenProcess( cmd + " "+ params, @nStdIN, @nStdOUT, @nStdERR , .f.)

  IF nChild < 0
    ? "Error:", FError()
    return "Error: " + cmd
  ENDIF

  ? "Receiving data       : "
  nBytes:=Fread( nStdOUT, @stdOut, Len(stdOut) )
  ?? Left( stdout, nBytes )

  ? "Reading errors       : "
  nBytes:=Fread( nStdERR, @stdErr, Len(stdErr) )
  ?? Left( stdErr, nBytes )

  ? "Waiting for end      :", HB_ProcessValue( nChild )

  FClose( nChild )
  FClose( nStdIN )
  FClose( nStdOUT )
  FClose( nStdERR )

RETURN alltrim(stdErr)

/* FUNCTION invclr
*
* returns the inverted color of the actual color
* "R/W" is converted to "W/R"
*
*/
FUNCTION invclr(actColor)
LOCAL x
  if (x:=at(",",actColor)) > 0
    actColor:=left(actColor,x-1)
  endif
  x:=at("/",actColor)
RETURN ( right(actColor,x-1)+"/"+left(actColor,x-1) )



/** FUNCTION colorSay(row,col,text)
*
* zeigt Zeichen zw. 2 BS_FARBE-Zeichen in definierter Farbe an
* (urspr. ext. library ftxbox.lib)
*/

  #define COLOR_CURRENT "N/BG"
  #define HIGHLIGHT_CURRENT "R/BG"

FUNCTION colorSay(row,col,text,current,offset)
LOCAL color:=.f.,i,mcol,currentCol
LOCAL currColor:=setColor()
LOCAL countSZ:=0,invisibleText:="",printText:=""
  default current:=.f.
  default offset:=1

  // nothing to do on invalid text
  if text == nil
    qout()
    return .t.
  endif

  // finde echtes offset, d.h. ohne BS_FARBE Sonderzeichen
  i:=1
  do while len(invisibleText)<offSet-1 .and. i <= len( text )
    if substr(text,i,1)==BS_FARBE
      countSZ++
    else
      invisibleText+=substr(text,i,1)
    endif
    i++
  enddo

  // starte mit highlightet Ausgabe falls ungerade Anzahl von aus/aus Strings
  if countSz>0 .and. int(countSZ/2)<>countSZ/2
    color:=.t.
    if current
      setColor(HIGHLIGHT_CURRENT)
    else
      setColor("R/"+getBackColor())
    endif
  else
    if current
      setColor(COLOR_CURRENT)
    endif
  endif

  printText:=substr(text,len(invisibleText)+countSZ+1) // real offset

  // @ row,col say ""
  // setPos(row,col)
  // Info: setPos und qout hat bei manchen werten nicht funktioniert -> deshalb @ row,col say ?!!!

  currentCol:=col // col() seems not to be updated properly
  do while at(BS_FARBE,printText) > 0 .and. currentCol<=maxCol()
    mcol:=min(at(BS_FARBE,printText),maxcol()+2)
    // Info: maxcol()+2 ist notwendig hier, da maxcol() bei 0 beginnt und unten 1 abgezogen wird
    @ row,currentCol say left(printText,min(mcol-1,maxCol()-currentCol+1))
    // qqout(left(printText,min(mcol-1,maxCol()-currentCol+1)))
    currentCol += mcol-1
    if color
      if current
        setColor(COLOR_CURRENT)
      else
        setColor(currColor)
      endif
    else
      if current
        setColor(HIGHLIGHT_CURRENT)
      else
        setColor("R/"+getBackColor())
      endif
    endif
    color:=(! color)
    printText:=substr(printText,mcol+1)
  enddo
  @ row,currentCol say left(printText,maxCol()-currentCol+1)
  // geht: DevPos( row, col ) ; DevOut( left(printText,maxCol()-currentCol+1) )
  // qqout(left(printText,maxCol()-currentCol+1))
  currentCol += maxCol()-currentCol+1
  if currentCol<=maxCol()
    qqout(space(maxCol()-currentCol))
  endif
  setColor(currColor)
RETURN .t.
/* EOF */

/** FUNCTION colorprint(text)
*
* druckt Zeichen zw. 2 BS_FARBE-Zeichen in definierter Farbe an (z.Zt rot)
*/

FUNCTION colorPrint(text,newline)
LOCAL color:=.f.
LOCAL zeile:=0,SZ
  default text:=""
  default newline:=.t.
  text:=trim(text)

  if newline
    ?
  endif
  do while at(BS_FARBE,text) > 0
    if color // ACHTUNG: Farbabfrage negiert!
      SZ:=getUser():getCurrentPrintJob():color(0,0,0)
    else
      SZ:=getUser():getCurrentPrintJob():color(1,0,0)
    endif
    if valtype(SZ) == "O" .and. SZ:className() == "PRINTSONDERZEICHEN"
      ?? substr(text,1,at(BS_FARBE,text)-1),SZ
    else
      ?? substr(text,1,at(BS_FARBE,text)-1)+SZ // no space here between output!!!
    endif
    color:=(! color)
    text:=substr(text,at(BS_FARBE,text)+1,len(text))
  enddo
  ?? text,getUser():getCurrentPrintJob():color(0,0,0)

RETURN zeile
/* EOF */

/** FUNCTION highlight()
*
* inserts a special character (BS_FARBE) to highlicht text
*/
FUNCTION highlight
LOCAL insKey:=set(_SET_INSERT,.t.)
  keyboard BS_FARBE
  // set(_SET_INSERT , insKey)

RETURN .t.

/** PROCEDURE zapFile()
*
* loescht den kompletten Inhalt einer Datei !
* (da dbase->zap nicht 100% kompatibel)
*/
PROCEDURE zapFile()
LOCAL GetList:={}
LOCAL Message:="", DateiName:=space(10),pass:=space(10)

  cls
  titel("Datei loeschen !!!")
  @ 10,20 say "ACHTUNG !"
  @ 12,20 say "zu loeschende Datei:" get DateiName
  @ 14,20 say "Passwort           :" get Pass picture "@!"
  read
  if ! ABBRUCH .and. encrypt(trim(pass))==MASTER_PASS
    if open({ trim(dateiName) , .t. })
      if Message("Sind Sie sicher ? (@J@/@N@)","JN")=="J"
        zap
      endif
    endif
  endif
  cls
  close data
RETURN
/* EOP delete */

/** FUNCTION for displaying strings in a valid-clause */
FUNCTION display(oGet,s)
  if ! empty( oGet:buffer )
    QQout(s)
  endif
return .t.

/** Function ChangeCursor
* passt den Cursor dem insert-modus an
*/
Function ChangeCursor()
  // nur, wenn Cusror im Augenblick sichtbar, also nichtin Auskunft oder so
  if setcursor() <> SC_NONE
    set(_SET_INSERT,!set(_SET_INSERT))
    if set(_SET_INSERT)
      setCursor(SC_INSERT)
    else
      setCursor(DEUTE_MARKE)
    endif
  endif
return .t.
/** eof*/


/** Procedure zum manuellen Erfassen von Emails
 */

Function ErfasseEMail(toAdress)
LOCAL GetList:={},text,result:=-1
LOCAL subject:=space(60)
LOCAL TempFile:=TEMP+BACKSLASH+left(getUser():getLongId(),2)+BACKSLASH+;
  "Email-"+getUser():getLongID()+".txt"

  toAdress:=no_blanks(toAdress)

  cls
  titel("Email verfassen an:"+trim(toAdress))
  Message("Bitte das EMail-Subject eingeben                @ESC@=Ende")
  Message()
  @ 2,0 to 2,maxcol()
  @ 1,0 say "Subject:" get subject
  read
  if ABBRUCH
    return result
  endif


  set key K_ESC to terminateEdit()
  text:=MyMemoEdit(memoread(tempFile),3,1,21,79, .t.)
  set key K_ESC to
  if len(text)==0 .or. Message("Email senden?  (@J@/@N@)","JN")<>"J"
    cls
    return result
  endif
  if ! MemoWrit(tempFile,text)
    Error(ACHTUNG+" konnte Email Text nicht auf Platte schreiben.|"+tempFile,.t.)
  endif

  result:=Email(toAdress,subject,text,,,.t.) // enforce manual email also on holidays!

return result
/** eof */

Function terminateEdit()
  keyboard chr(K_CTRL_W)
return .t.



/* FUNCTION FaxNr
*
* liefert nur numerische Felder eines Strings zur�ck -> zum Faxen
*/
FUNCTION FaxNr(Eingang)
LOCAL Ausgang:="" , x:=1
  do while x <= len(Eingang)
    if substr(Eingang,x,1) $ "0123456789"
      Ausgang += substr(Eingang,x,1)
    endif
    x++
  enddo
RETURN(Ausgang)
/* EOF FAxNr */

/** loescht den trailing CTRL-Z aus einer Datei
*
*
* Parameters
* Datei: DateiName  // inkl. Pfadname, Datei muss geschlossen sein!
*/
Procedure deleteCTRLZ(Datei)
LOCAL nInfile:=FOPEN(Datei, FO_READWRITE)
LOCAL lastChar:=space(1), nBytesRead, lastChar2:=space(1)

  // pr�fe ob letztes Zeichen ein CTRL-Z
  FSEEK(nInfile,-1,FS_END)
  nBytesRead:=FREAD(nInfile, @lastChar, 1)
  if nBytesRead<>1
    Error(ACHTUNG+Datei+" CTRL-Z konnte nicht gelesen werden.",.t.,"root")
    FCLOSE(nInfile)
    return
  endif
  if lastChar<>chr(K_CTRL_Z)
    // NOP
    FCLOSE(nInfile)
    return
  endif

  // lese vorletztes Zeichen
  FSEEK(nInfile,-2,FS_END)
  nBytesRead:=FREAD(nInfile, @lastChar2, 1)
  if nBytesRead<>1
    Error(ACHTUNG+Datei+" vorletztes Zeichen konnte nicht gelesen werden.",.t.,"root")
    FCLOSE(nInfile)
    return
  endif

  if lastChar2==chr(K_CTRL_L)
    // schreibe CTRL-L als letztes Zeichen
    FSEEK(nInfile,-2,FS_END)
    IF FWRITE(nInFile, " "+chr(K_CTRL_L)) < 2
      FCLOSE(nInfile)
      Error(" Schreibfehler in Proc deleteCTRLZ.  File:"+Datei+" Error:"+str(Ferror()),.t.,"root")
      return
    endif
  else
    // "l�sche" letztes Zeichen
    FSEEK(nInfile,-1,FS_END)
    IF FWRITE(nInFile, " ") < 1
      FCLOSE(nInfile)
      Error("Schreibfehler in Proc deleteCTRLZ.  File:"+Datei+" Error:"+str(Ferror()),.t.,"root")
      return
    endif
  endif

  FCLOSE(nInfile)

return
/** eof deleteCTRLZ */


/**
* andere Benutzer rausschmeissen
*/

  #define SHUTDOWN_DELAY 62

Function forceQuit(abfrage)
LOCAL tempFileName2:=TEMP+BACKSLASH+getUser():getLongId()+"prog.txt"
LOCAL attachments:={}
LOCAL kurzel:=space(4), quit:=.f.
LOCAL GetList:={}, ext:=""

  default abfrage:=.t.

  Umgebung( WRITE_ALL )

  cls
  Titel("Miki-Programme beenden")

  if Abfrage

    @ 6,18 to 10,62
    @ 7 ,20 say "Beendet andere offene Programme."
    @ 9 ,20 say "Auch die von anderen Benutzern."
    @ 11,20 say "K�rzel:" get kurzel picture "@K!" ;
      when Message( "Bitte genaues K�rzel eingeben (z.B. @MW2@) oder @ALLE@ f�r alle Programme" )
    Message("@Esc@ = Abbruch")
    read
  endif

  if !Abfrage .or. (! ABBRUCH .and. !empty(kurzel))
    if getUser():id $ KURZEL_DEVEL
      quit:=Message("Danach Programm beenden?  (@J@/@N@" , "JN" , "J") == "J"
      if ABBRUCH
        Umgebung(LOAD)
        return .f.
      endif
    endif

    Message("Dieser Vorgang kann bis zu 2 Minuten dauern.  Bitte warten...   @ESC@=Abbruch")

    // pr�fe K�rzel
    if kurzel <> "ALLE"
      if ! open("Login")
        LOGIN->(dbseek( left( kurzel,2 )))
        if LOGIN->(eof())
          Error("K�rzel: "+ kurzel + "nicht gefunden.",.t.)
          // Umgebung( LOAD )
          trouble("crontab",{"Crontab abgeborchen (quit 1)   ===================================="+;
            "====="})
          // return .f.
        endif
      endif
      ext:="-" + trim(kurzel)
    endif

    createEmptyFile(SHUTDOWN_S + ext)
    @ 14,20 say "Shutdown start...                  "

    createEmptyFile(SHUTDOWN_1 + ext)
    @ 14,20 say "Shutdown Level 1 "
    inkey(SHUTDOWN_DELAY)
    ferase(SHUTDOWN_1 + ext)

    if ABBRUCH
      ferase(SHUTDOWN_S + ext)
      // Umgebung( LOAD )
      trouble("crontab",{"Crontab abgeborchen (quit 2)   ========================================="})
      // return .f.
    endif

    createEmptyFile(SHUTDOWN_2 + ext)
    @ 14,20 say "Shutdown Level 2 "
    inkey(SHUTDOWN_DELAY)
    ferase(SHUTDOWN_2 + ext)

    if ABBRUCH
      ferase(SHUTDOWN_S + ext)
      // Umgebung( LOAD )
      trouble("crontab",{"Crontab abgeborchen (quit 3)   ========================================="})
      // return .f.
    endif

    createEmptyFile(SHUTDOWN_3 + ext)
    @ 14,20 say "Shutdown Level 3 "
    inkey(SHUTDOWN_DELAY)
    ferase(SHUTDOWN_3 + ext)

    if ABBRUCH
      ferase(SHUTDOWN_S + ext)
      // Umgebung( LOAD )
      trouble("crontab",{"Crontab abgeborchen (quit 4)   ========================================="})
      // return .f.
    endif

    // kill other hanging programs
    if !Abfrage .or. kurzel=="ALLE"
      if killByName(getFileName(ExeName()),tempFileName2) > 1
        aadd(attachments,tempFileName2)
        email(MY_EMAIL,"ERROR: Miki-Programme h�ngen.","Bitte dringend pr�fen",attachments,.t.)
        // Umgebung( LOAD )
        trouble("crontab",{"Crontab abgeborchen (quit 5)   ======================================"+;
          "==="})
        // return .f.
      endif
    endif

    ferase(SHUTDOWN_S + ext)
    @ 14,20 say space(20)
    // qout("Shutdown Ende.")
  endif

  if kurzel == "ALLE" .or. ! Abfrage
    LoginDispatcher():new():ResetLogin(,.t.)
  endif

  Umgebung( LOAD )

  if quit
    down(.f.,.f.) // don't wait for background tasks
  endif
return .t.
/** eof */


/** returns random number between 0 and n-1 */
FUNCTION Random(N)
  _thread static XRNDSEED:=.123456789
  IF XRNDSEED = .123456789
    XRNDSEED += VAL(SUBSTR(TIME(), 7, 2)) / 100
  ENDIF
  XRNDSEED:=(XRNDSEED * 31415821 + 1) / 1000000
return int( (XRNDSEED -= INT(XRNDSEED)) * N)
/** eof */

  #define LEGAL_CHARS "ABCDEFGHIJKLMNOPQRSTUVWXYZ_-1234567890���"
/** checkt ob ein String den Standard-characters f�r einen Dateinamen enstpricht */
function checkFileName(s)
LOCAL i
  for i:=1 to len(trim(s))
    if ! upper(substr(s,i,1)) $ LEGAL_CHARS
      Error(ACHTUNG+" Name enth�lt nicht erlaubte Zeichen.")
      return .f.
    endif
  next
return .t.
/** eof */

/** s�ubert ein String so dass er als Dateiname verwendet werden kann */
function cleanFileName(s)
LOCAL i
  for i:=1 to len(trim(s))
    if ! upper(substr(s,i,1)) $ LEGAL_CHARS
      // remove character
      s:=substr(s,0,i-1)+substr(s,i+1)
    endif
  next
return alltrim(s)
/** eof */

/* FUNCTION count
*
* gibt die Anzahl der vorkommenden Suchzeichenkette im ZielString zur�ck
*
* Parameter: SuchZeichenKett
*            Ziel
*/
FUNCTION count(Suche,Ziel)
LOCAL x:=0
LOCAL pos
  do while (pos:=at(Suche,Ziel)) > 0
    x++
    Ziel:=substr(Ziel,pos+1,len(Ziel))
  enddo
return x
/* EOF */


/** Procedure AsciiTabelle
 * gibt alle ASCII Zeichen ab 20 auf dem BS aus
*/
Procedure ASCIITabelle()
LOCAL i,x:=5
LOCAL cp:=set( _SET_CODEPAGE)+space(5)
LOCAL GetList:={}
  CLS
  Titel("ASCII Zeichen")

  @ 2,0 say "CodePage:" get cp picture "@K"
  read

  if ! ABBRUCH
    set( _SET_CODEPAGE,trim(cp))
    qqout("->",set( _SET_CODEPAGE))
    hb_setTermCP( trim(cp) )

    for i:=0 to 19
      @ 4,3+i*3 say str(i,3)
    next
    for i:=20 to 255
      if mod(i,20)=0
        x++
        @ x,1 say str(i,3)
      endif
      @ x,5+mod(i,20)*3 say chr(i)
    next

  endif

  // LOCAL i,x,step
  // i:=20
  // step:=25
  // do while i<step+20
  // for x:=0 to 9
  // qqout(str(i+x*step,3),space(0),chr(i+x*step),space(4))
  // next
  // qout()
  // i++
  // enddo


  // Drucker("PDF",,,.t.,PDF_YES_CONFIRM)
  // ? "Hallo"
  // for i:=65 to 240
  // ? i ,space(10),chr(i)
  // next
  // drucker("off")





  // @ 22,0 say "Codepage:"
  // qqout(hb_GtInfo( HB_GTI_CODEPAGE))
  // hb_gtInfo( HB_GTI_CODEPAGE,1252)
  // qqout(" -->>",hb_GtInfo( HB_GTI_CODEPAGE))
  // @ 22,40 say "Font:"
  // qqout( HB_GTInfo(HB_GTI_FONTNAME))

  Message("Bitte Taste dr�cken.","@")
  cls

return


/* EOP delete */


/** replaces the str() method using a , as separator */
Function transStr(text,orgVorKomma,orgNachKomma,tausenderPunkt,removeTrailingZeros)
LOCAL pict:="", i:=0, result,dots:=0
LOCAL vorKomma:=orgVorKomma
LOCAL nachKomma:=orgNachKomma
  default tausenderPunkt:=.t.

  default vorKomma:=12
  default orgVorkomma:=12
  default nachKomma:=2
  default orgNachkomma:=2
  default removeTrailingZeros:=.f.

  // bail out if empty
  if text == nil
    return space( orgVorkomma )
  endif

  // Ausnahme Ausgabe nach Excel, dann ohne Fomartierung!!!
  // Hinweis: trotzdem als String, da evtl. concated wird
  if getUser():getCurrentPrintJob(.t.,.t.):className()=="EXCELJOB"
    return str( text , orgVorkomma , orgNachkomma )
  endif

  if orgVorKomma==NIL
    vorKomma:=orgVorKomma:=9
    TroubleEmail("TransStr ohne Vorkomma.")
  endif
  if orgNachKomma==NIL
    nachKomma:=orgNachKomma:=2
    TroubleEmail("TransStr ohne Nachkomma.")
  endif

  if removeTrailingZeros
    if int(text) == text
      nachKomma:=orgNachKomma:=0
    endif
  endif

  // remove counter for decimal point, if any
  if nachkomma>0
    vorkomma=vorkomma-1-nachkomma
  endif

  do while i+dots<vorkomma
    pict="9"+pict
    i++
    if tausenderPunkt .and. mod(i,3)=0 .and. i+dots<vorkomma-1
      pict=","+pict
      dots++
    endif
  enddo

  if nachkomma>0
    pict+="."+replicate("9",nachkomma)
  endif

  pict:="@E "+pict

  result:=transform(text,pict)

  // falls Nummer zu gross mit 1000er Trennern, dann lieber ohne!
  if "*"$result
    if tausenderPunkt
      result:=transstr(text,orgvorkomma,orgnachkomma,.f.)
    else
      result:=str(text,orgvorkomma,orgnachkomma)
    endif
  endif

  // falls Nummer zu gross mit Nachkommastellen, dann lieber ohne!
  if "*"$result
    result:=str(text,orgvorkomma,0)
  endif

return result
/* EOF*/

/** invertion to transstr, macht aus 123.456,12 wieder 123456.12 */
Function untransStr(text)
LOCAL result:=deleteString(text,".")
return strtran(result,",",".")
/* EOF*/

/* Function shift  **************************************
*
* shiftet den Inhalt des �bergebenen Oget:Buffers nach rechts !
*
*/
FUNCTION shift(oGet,Shift_Char)
LOCAL Inhalt:=oGet:buffer , lang
  default Shift_char:=SHIFT_CHAR
  lang:=len(Inhalt)
  if right(Inhalt,1)==" " .and. ! empty(Inhalt) .and. ! alltrim(oGet:Buffer)=="*"
    Inhalt:=alltrim(Inhalt)
    oGet:varput(Replicate(Shift_char,lang-len(Inhalt))+Inhalt)
    oget:updateBuffer()
    oGet:display()
  endif
RETURN(.t.)
/* EOF shift */

/* 
* shiftet den Inhalt des �bergebenen Strings nach rechts, L�nge bleibt gleich.
*/
FUNCTION strShift(s)
LOCAL l:=len(s)
return right(space(l)+alltrim(s),l)
/* EOF strShift */

/* Function Next ****************************************
*
* z�hlt �bergebene Variable an der letzten Stelle (!) um 1 hoch (Asci-Code)
*/
FUNCTION Next(Wert)
LOCAL cWert:=left(Wert,len(Wert)-1)+chr(asc(right(wert,1))+1)
RETURN(cWert)
/* EOF Next */

/* Function previous ****************************************
*
* z�hlt �bergebene Variable um 1 runter (Asci-Code)
*/
FUNCTION previous(Wert)
LOCAL cWert:=left(Wert,len(Wert)-1)+chr(asc(right(wert,1))-1)
RETURN(cWert)
/* EOF Next */

/** liefert den getrimmten String+space(1) oder leer, falls leer */
FUNCTION myTrim(s)
LOCAL result:=""
  if ! empty(s)
    result:=alltrim(s)+" "
  endif
return result
/** eof */



/** Liefert aus Liste.dbf den PDFNamen bzw. falls leer den DefaultNamen
*/
Function meinLiName()
LOCAL name
  if select("Liste")>0 .and. ! empty(LISTE->PDFName)
    name:=trim(LISTE->PDFName) // +getUser():getLongID()
  else
    name:=trim(left(procName(2),12)) // +getUser():getLongID()
  endif
return name
/** eof */



/* 
* nimmt eine Liste neu in Liste.dbf auf
* Liste ist selektiert
* Parameter: Neuer ListenName
*/
FUNCTION Druck_Neu(Name)
LOCAL li:=20, ob:=8 , re:=60 ,unt:=18

  if ! add_rec(5)
    error("Liste.dbf"+DATEI_EXCL)
    RETURN(.f.)
  endif

  Umgebung(WRITE)
  open("System")

  replace LISTE->Liste_Kurz with Name
  replace LISTE->DruckerNr with SYSTEM->DruckerNr
  replace LISTE->Anzahl with 1
  replace LISTE->Art with "K" // Klein ist default -> weniger Fehler wg. falscher Umbruch
  replace LISTE->PDFName with Name

  setcolor(COLWIN)

  // inform me, as we want to avoid user interaction here
  TroubleEmail("Liste nicht vorhanden: "+LISTE->Liste_Kurz)

  ListDisp(.t.)

  Umgebung(LOAD)

RETURN(.t.)


/* 
* fragt ob Ausgabe auf Drucker, BS ,PDF oder in Datei (Export)
*
* ACHTUNG: erg ist boolean au�er bei Export -> dann der DateiName :(
* Parameter: default Dateiname f�r den Export bzw. JobName
*/
FUNCTION Druck_BS(jobName,enableExport,enablePdf,enableFax)
LOCAL ant,GetList:={},export
LOCAL erg:=.f.
LOCAL mess:={},taste:={},messtext:="",messText2:="",tastAuswahl:="",i
LOCAL exportFilter:="*" // was dbf but wrong for xlsx

  if valtype( enableExport ) =="C"
    exportFilter:=enableExport
    enableExport:=.t.
  endif

  default enablePdf:=.t.
  default enableExport:=.f.
  default enableFax:=.f.

  if valtype(jobName)=="U"
    export:=space(8)
  else
    export:=jobName
  endif

  // defaul BS Und Drucker
  aadd(mess,"@D@rucker")
  aadd(taste,"D")
  aadd(mess,"@B@ildschirm")
  aadd(taste,"B")

  if enableExport
    aadd(mess,"@E@xport")
    aadd(taste,"E")
  endif

  if enablePdf
    aadd(mess,"@P@DF Datei")
    aadd(taste,"P")
  endif

  if enableFax
    aadd(mess,"@F@ax")
    aadd(taste,"F")
  endif

  for i:=1 to len(mess)
    messtext+=" "+mess[i]+" "
    messtext2+="@"+taste[i]+"@/"
    tastAuswahl+=taste[i]
    if i==len(mess)-1
      messtext+="oder"
    endif
  next

  ant:=Message(messText+" ("+left(messText2,len(messText2)-1)+")",tastAuswahl,"B")

  do case
  case ant=="D" // Drucker
    if ! ( erg:=drucker("on",jobName) )
      erg:=drucker("BS")
    endif
  case ant=="B" // BS
    erg:=drucker("BS",jobName)
  case ant=="F" // Fax
    if ! ( erg:=drucker("FAX",jobName) )
      erg:=drucker("BS")
    endif
  case ant=="P" // PDF
    erg:=drucker("PDF",nil,getUser():exportPATH(),.f.,PDF_YES_CONFIRM)
    if empty(LISTE->PDFName) .and. jobName<>NIL
      export:=jobName
    else
      export:=LISTE->PDFName
    endif

    if (export:=openFileDialog(WRITE,getUser():exportPATH(),export,"pdf",nil))<>NIL
      export:=getFileName(export,.t.)
      getUser():getCurrentPrintJob():setJobName(export)
    else
      getUser():getCurrentPrintJob():endDoc(.t.)
      getUser():setCurrentPrintJob(NIL)
      erg:=.f. // Ende
    endif
  case ant=="E" // Export
    if (export:=openFileDialog(WRITE,getUser():exportPATH() , export , exportFilter , nil ))<>NIL
      erg:=getFileName(export,.t.)
    endif
  otherwise
    erg:=.f. // Ende
  endcase

RETURN(erg)
/* EOF Druck_BS */


/** Retunrs the file name only (extracts the dirbase if any)
 * Windows only
  *
  * \Myprog\miki\foo.dbf  -> foo.dbf
  * falls removeExtension==.t. -> foo
  *
  *
* FIXME: wrong wording rename to getBaseName
  
  // FIXME: maybe use the xhb function instead?
  // LOCAL cPath,cName,cExt
  // HB_FNameSplit("\schrott\foo.prg",@cPath,@cName,@cExt)
 */
FUNCTION getFileName(s, removeExtension)
  default removeExtension:=.f.

  // replace slash with back slash -> Windows only!
  s:=replaceWindowsSlashes(s)

  // remove extension if any
  if removeExtension .and. rat(".",s)>0
    s:=substr(s,1,rat(".",s)-1)
  endif

  if rat(BACKSLASH,s) > 0
    s:=substr(s,rat(BACKSLASH,s)+1)
  endif

return s
/** eof */

/** Retunrs the base file name only (extracts the last extension .dbf or others any)
 * Windows only
  *
  * \Myprog\miki\foo.dbf  -> \Myprog\miki\foo
 */
FUNCTION getFileBaseName(s)
LOCAL result:=s
  s:=replaceWindowsSlashes(s)
  if rat(".",s) > 0
    result:=substr(s,1,rat(".",s)-1)
  endif
return result
/** eof */

/** Retunrs the file name's extemnsion (extracts the last extension .dbf or others any)
 * Windows only
  *
  * \Myprog\miki\foo.dbf  -> .dbf
 */
FUNCTION getFileExt(s)
LOCAL result:=s
  s:=replaceWindowsSlashes(s)
  if rat(".",s) > 0
    result:=substr(s,rat(".",s))
  endif
return result
/** eof */

/** Retunrs the base name only (extracts the file name and extension .dbf or others from the path)
 * Windows only
  *
  * \Myprog\miki\foo.dbf  -> \Myprog\miki

* FIXME: wrong wording rename to getDirName  

 */
FUNCTION getBaseName(s)
  s:=replaceWindowsSlashes(s)
  if rat(BACKSLASH,s) > 0
    s:=left(s,rat(BACKSLASH,s)-1)
  endif
return s
/** eof */

/** replace / with \ */
FUNCTION replaceWindowsSlashes(s)
  if s <> nil .and. ! BACKSLASH $ s .and. at(FORWARD_SLASH,s)>0
    s:=strtran(s,FORWARD_SLASH,BACKSLASH)
  endif
return s

/** liefert von einem String nur die Zahlen und Buchstaben getrimmed zur�ck */
function ignoreSZ(text)
LOCAL result:="", i, char
  for i:=1 to len(text)
    char:=substr(text,i,1)
    if isDigit(char) .or. isAlpha(char)
      result += char
    endif
  next
return result
/** eof */

/** pr�ft die Plausibilt�t der Ident.Nr. */
FUNCTION syntaxIdentNr(idNr,Land,interaktiv)
LOCAL result:=.f.
LOCAL ErrorText:=""
  default interaktiv:=.t.

  LAND->(dbseek(Land))

  // keine Pr�fung bei Nicht-EU Kunden
  if ! LAND->EU $ "JD"
    return .t.
  endif

  // pr�fe L�nderk�rzel
  if substr(idNr,1,2)<>LAND
    if interaktiv
      Error(ACHTUNG+"Ident.Nr. muss mit L�nderk�rzel "+Land+" beginnen.",.t.)
    endif
    return .f.
  endif

  // strip of l�nderk�rzel
  idNr:=trim(substr(idNr,3))

  do case

  case Land $ "BE"
    result:=(len(idNr)==9 .or. len(idNr)==10) .and. isAllDigit(idNr)
    ErrorText:=;
      "zehn, nur Ziffern|(alte neunstellige USt-IdNrn. werden durch Voran-stellen der Ziffer 0 erg�nzt)"

  case Land $ "BG"
    result:=(len(idNr)==9 .or. len(idNr)==10) .and. isAllDigit(idNr)
    ErrorText:="neun oder zehn, nur Ziffern"

  case Land $ "DK/FI/LU/MT/SI/HU"
    result:=len(idNr)==8 .and. isAllDigit(idNr)
    ErrorText:="acht, nur Ziffern"

    // EL==GR == Griechenland
  case Land $ "DE/EE/EL/GR/PT"
    result:=len(idNr)==9 .and. isAllDigit(idNr)
    ErrorText:="neun, nur Ziffern"

  case Land $ "FR"
    result:=len(idNr)==11 .and. isAllDigit(substr(idNr,3))
    ErrorText:="elf, nur Ziffern bzw. die erste und / oder die zweite Stelle|kann ein Buchstabe sein"

  case Land $ "IE"
    result:=(len(idNr)==8 .and. isAlpha(substr(idNr,8,1))) .or.;
      (len(idNr)==9 .and. isAllDigit(substr(idNr,1,7)) .and. ;
      substr(idNr,8,1) $ "ABCDEFGHIJKLMNOPQRSTUVW" .and.;
      substr(idNr,9,1) $ "ABCDEFGHI")

    ErrorText:="acht, die zweite Stelle kann und die letzte Stelle muss ein Buchstabe sein|oder:|"+;
      "neun Stellen (ab 01.01.2013) , 1. - 7. Stelle Ziffern und|"+;
      "8. Stelle Buchstaben von A bis W und 9. Stelle Buchstaben von A bis I"

  case Land $ "IT/LV/HR"
    result:=len(idNr)==11 .and. isAllDigit(idNr)
    ErrorText:="elf, nur Ziffern"

  case Land $ "NL"
    result:=len(idNr)==12 .and. isAllDigit(substr(idNr,1,8)) .and. isAllDigit(substr(idNr,11)) .and. ;
      substr(idNr,10,1)=="B"
    ErrorText:="zw�lf, die drittletzte Stelle muss der Buchstabe B sein"

  case Land $ "AT"
    result:=len(idNr)==9 .and. substr(idNr,1,1)=="U"
    ErrorText:="neun, die erste Stelle muss der Buchstabe U sein"

  case Land $ "PL/SK"
    result:=len(idNr)==10 .and. isAllDigit(idNr)
    ErrorText:="zehn, nur Ziffern"

  case Land $ "RO"
    result:=len(idNr)<=10 .and. isAllDigit(idNr)
    ErrorText:="maximal zehn, nur Ziffern Ziffernfolge nicht mit 0 beginnend"

  case Land $ "SE"
    result:=len(idNr)==12 .and. isAllDigit(idNr) // .and.
    ErrorText:="zw�lf, nur Ziffern,|die beiden letz-ten Stellen bestehen immer aus der Ziffernkombination 01"

  case Land $ "ES"
    result:=len(idNr)==9 .and. isDigit(substr(idNr,2,7))
    ErrorText:="neun, die erste und die letzte Stel-le bzw. die erste oder die letzte Stelle|kann ein Buchstabe sein"

  case Land $ "CZ"
    result:=(len(idNr)==8 .or. len(idNr)==9 .or. len(idNr)==10) .and. isAllDigit(idNr)
    ErrorText:="acht, neun oder zehn, nur Ziffern"

  case Land $ "GB|LT"
    result:=(len(idNr)==9 .or. len(idNr)==12) .and. isAllDigit(idNr)
    ErrorText:="neun oder zw�lf, nur Ziffern"

  case Land $ "CY"
    result:=len(idNr)==9 .and. isDigit(substr(idNr,1,8)) .and.isAlpha(substr(idNr,9,1))
    ErrorText:="neun, die letzte Stelle muss ein Buchstabe sein."

  otherwise
    result:=.t.
    Error(ACHTUNG+Land+" "+LAND->Name+"||        Keine Ident.Nr. Regel hinterlegt.",.t.)
  endcase

  if ! result .and. interaktiv
    Error(ACHTUNG+Land+" "+LAND->Name+"||Nach dem L�nderk�rzel gilt:||L�nge der Ident.Nr.:|";
      +ErrorText,.t.)
    if getUser():id $ KURZEL_MAIN_CUSTOMER // KURZEL_DEVEL+
      Error(ACHTUNG+Land+" "+LAND->Name+"||      Ausnahme H. Weiland gestattet.",.t.)
      result:=.t.
    endif
  endif
return result
/** eof */


/* Procedure Info_Koord
*
* �ndern der Koordinaten des Info-Fensters
* nur falls FERTIG nicht def. !
*/
PROCEDURE Info_Koord()
LOCAL I_Li:=INFO->In_Li
LOCAL I_re:=INFO->In_re
LOCAL I_ob:=INFO->In_ob
LOCAL I_un:=INFO->In_un
LOCAL GetList:={}

  Umgebung(WRITE)

  setcolor(COLNOR)
  setcursor(DEUTE_MARKE)
  Fenster(10,28,15,45)
  @ 11,30 say 'Links: ' get I_Li
  @ 12,30 say 'Rechts:' get I_re
  @ 13,30 say 'Oben:  ' get I_ob
  @ 14,30 say 'Unten: ' get I_un
  read
  if Rec_Lock(5)
    replace INFO->In_LI with I_Li
    replace INFO->In_re with I_re
    replace INFO->In_ob with I_ob
    replace INFO->In_un with I_un
    keyboard chr(K_ESC)
  endif

  Umgebung(LOAD)

RETURN



/* Procedure Shutdown
*
* gibt den aktuellen Programm-Stapel aus
* und beendet nach Abfrage das Programm
* HotKey:=SHUTDOWN
*/
PROCEDURE ShutDown()
LOCAL i:=1

  trouble("shutdown",{ "Shutdown Versuch von:"+getUser():getLongID() })

  if DEVEL_PROG .or. TEST_PROG

    Umgebung(WRITE)

    @ 0,0
    /* gebe Programm-Stapel aus */
    while ( !Empty(ProcName(i)) )
      qout( Trim(ProcName(i)) +"("+ LTRIM(str(ProcLine(i))) +")" )
      i++
      end

      beep()
      if Message("System wirklich anhalten ? ( J / N ) ","@")="J"
        trouble("shutdown",{ "Shutdown von:"+getUser():getLongID() })
        Umgebung(DISMISS_ALL)
        down(.f.,.t.)
        quit
      endif

      Umgebung(LOAD)
    endif

    RETURN


/* Function ExactSeek   *****************************************
*
* sucht nach exakt gleichem Index, auch Leerstellen !
* ACHTUNG: Feldl�ngenfehler bei verkn�pften Index
*
* Parameter: cSuche:char
* R�ckgabe : Erfolg:bool
*/
FUNCTION ExactSeek(cSuche)
  seek padr( cSuche, len(&(IndexKey(0))) )
RETURN( Found() )



/* Procedure Info       *****************************************
*
* gibt HilfeText auf BS nach dr�cken von INFO_TASTE
* Parameters:
*    p1 = aufrufendes Programm
*    p2 = Zeile des obigen
*    p3 = offen Get-Variable
*/
PROCEDURE Info(p1,p2,p3)
LOCAL edit
LOCAL text:="" , title
  // default position am BS
LOCAL li:=0
LOCAL re:=78
LOCAL ob:=2
LOCAL un:=22
LOCAL bKeyBlockEsc, bKeyBlockF1, bKeyBlockF10
  ignore p2

  /* keine Rekursion m�glich ! */
  if p1=="INFO" .or. (p1==NIL) .or. (p3 == NIL)
    beep()
    RETURN
  endif

  Umgebung(WRITE)

  if ! open("Info")
    Umgebung(LOAD)
    RETURN
  endif

  // #ifdef INFO_JE_PROG // Info je Programm
  // seek padr(p1,len(INFO->Prog))
  // #else // Info je Feld
  seek padr(p1,len(INFO->Prog))+p3
  // #endif

  if eof() // akt. Hilfe Text nicht vorhanden !
    if ! ( getUser():mayEditInfoText ) // keine �nderung der Hilfe-Text mehr m�glich
      if file( INFO_DATEI )
        text:=memoRead( INFO_DATEI )
      else
        close_only({"Info"})
        Umgebung(LOAD)
        return
      endif
    else // Hilfe Texte erweitern
      if add_rec(5)
        replace INFO->Var with p3
        replace INFO->Prog with p1
        replace INFO->In_ob with ob
        replace INFO->In_li with li
        replace INFO->In_un with un
        replace INFO->In_re with re
      endif
    endif
  else // gefunden -> �bernehme Werte
    ob:=INFO->In_ob
    li:=INFO->In_li
    un:=INFO->In_un
    re:=INFO->In_re
    if fieldpos("Datei") > 0 .and. ! empty(INFO->Datei)
      text:=memoRead( INFO->Datei )
    else
      text:=INFO->Text
    endif
    title:=INFO->Title
  endif

  Message()
  setcolor(INFO_FARBE)
  fenster( ob , li , un , re ,if(empty(Title),"Hilfe",trim(Title)))

  edit:=( getUser():mayEditInfoText ) // �nderung der Hilfe-Text m�glich
  if edit
    Message("Info-Text eingeben.     @F10@ = Koordinaten �ndern         @ESC@ = Ende")
    bKeyBlockF10:=SetKey( K_F10 , {|| INfo_Koord()} )
    setcursor( .t. )
  else
    SET CURSOR OFF
    if mlcount(Text) > un - ob -1
      Message( " @"+chr(24)+chr(25)+"@  @ESC@ / @F1@ = Ende " )
    else
      Message( " @ESC@ / @F1@ = Ende " )
    endif
  endif

  /* setze Esc auf Ctrl-W , speichern der Hilfe-Texte */
  bKeyBlockEsc:=SetKey( K_ESC , {|| __Keyboard(chr(K_CTRL_W))} )
  bKeyBlockF1:=SetKey( K_F1 , {|| __Keyboard(chr(K_CTRL_W))} )

  /* editiere bzw. Zeige Hilfetexte */
  SetLastKey(0)
  text=MyMemoEdit(text , ob+1 , li+2 , un-1 , re-2 , edit)

  if edit // �nderung m�glich
    if ! rec_lock(5)
      error(SATZ_EXCL)
      close_only({"info"})
      Umgebung(LOAD)
      setkey( K_ESC , bKeyBlockEsc )
      setkey( K_F1 , bKeyBlockF1 )
      if edit
        setkey( K_F10 , bKeyBlockF10 )
      endif
      return
    endif

    if empty(text)
      delete
    else
      replace INFO->Text with Text
    endif
    dbcommit()
    UNLOCK
  endif

  close_only({"Info"})
  Umgebung(LOAD)

  setkey( K_ESC , bKeyBlockEsc )
  setkey( K_F1 , bKeyBlockF1 )
  if edit
    setkey( K_F10 , bKeyBlockF10 )
  endif

  #ifdef INFO_TASTE
  set key INFO_TASTE to Info // Informations-Proc
  #endif

RETURN
/* EOP Info */


/* 
* Abfrage Bereichsbeschr�nkung
*
* R�ckgabe des bis-Wertes, steht auf 1. ausgew�hlten Satz
* Abbruch falls R�ckgabe-wert leer !
*
* Parameter:    Datei
*/
FUNCTION von_bis(cDatei,startSpalte,startZeile)
LOCAL Datei:=db_info(cDatei)
LOCAL GetList:={}
LOCAL Spalte:=20,Zeile:=8

  STATIC lastBuffer

MEMVAR von,bis,buffer
PRIVATE von,bis

  if startSpalte <> NIL
    Spalte:=startSpalte
  endif
  if startZeile <> NIL
    Zeile:=startZeile
  endif

  set key K_F8 to copy_buffer("",oGet,"")
  M->Buffer:=lastBuffer

  select (cDatei)
  von:="M->V"+getKeyFieldName(datei)
  bis:="M->B"+getKeyFieldName(datei)
  &(von):=&(bis):=space(getKeyFieldLen(datei))

  if Datei[D_ART]=="N"
    @ Zeile ,Spalte say Datei[D_KURZ]+" von:" get &von PICTURE "@#";
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and.;
      Ausgabe(oGet);
      };
      when;
      Message("1. "+Datei[D_KURZ]+" eingeben.     "+if(lastBuffer<>NIL,"@F8@=kopieren","")+;
      "   @F12@=Hilfe")
    @ Zeile+2,Spalte say Datei[D_KURZ]+" bis:" get &bis PICTURE "@#";
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and. Ausgabe(oGet) } when Message("letzter "+Datei[D_KURZ]+" eingeben.        "+;
      "@F8@=kopieren          @F12@=Hilfe")
  elseif Datei[D_ART]=="Z" .or. Datei[D_ART]=="A"
    @ Zeile ,Spalte say Datei[D_KURZ]+" von:" get &von PICTURE "@!";
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and.;
      ausgabe(oGet);
      };
      when;
      Message("1. "+Datei[D_KURZ]+" eingeben.     "+if(lastBuffer<>NIL,"@F8@=kopieren","")+;
      "   @F12@=Hilfe")
    @ Zeile+2,Spalte say Datei[D_KURZ]+" bis:" get &bis PICTURE "@!";
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and. Ausgabe(oGet) } when Message("letzter "+Datei[D_KURZ]+" eingeben.        "+;
      "@F8@=kopieren          @F12@=Hilfe")
  elseif Datei[D_ART]=="K"
    @ Zeile ,Spalte say Datei[D_KURZ]+" von:" get &von PICTURE KDNR_PICT;
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and.;
      ausgabe(oGet);
      };
      when;
      Message("1. "+Datei[D_KURZ]+" eingeben.    "+if(lastBuffer<>NIL,"@F8@=kopieren","")+;
      "    @F12@=Hilfe")
    @ Zeile+2,Spalte say Datei[D_KURZ]+" bis:" get &bis PICTURE KDNR_PICT;
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and. Ausgabe(oGet) } when Message("letzter "+Datei[D_KURZ]+" eingeben.        "+;
      "@F8@=kopieren          @F12@=Hilfe")
  else
    @ Zeile ,Spalte say Datei[D_KURZ]+" von:" get &von;
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and.;
      Ausgabe(oGet);
      };
      when;
      Message("1. "+Datei[D_KURZ]+" eingeben.   "+if(lastBuffer<>NIL,"@F8@=kopieren","")+;
      "     @F12@=Hilfe")
    @ Zeile+2,Spalte say Datei[D_KURZ]+" bis:" get &bis;
      valid;
      {;
      |oGet|;
      check(Oget,cDatei,.t.,.f.);
      .and. Ausgabe(oGet) } when Message("letzter "+Datei[D_KURZ]+" eingeben.        "+;
      "@F8@=kopieren          @F12@=Hilfe")
  endif
  read

  set key K_F8 to

  if ABBRUCH
    RETURN( "" )
  endif

  lastBuffer:=M->Buffer

  if empty(&(bis))
    go bottom
    &(bis):=fieldget(1)
  endif

  if empty(&(von))
    go top
  else
    dbseek( &(von) , .t.)
    if eof()
      RETURN( "" )
    endif
  endif

RETURN( trim(&(bis)) )
/* EOF von_bis */

FUNCTION Ausgabe(oGet)
  if ! empty(oGet:Buffer) .and. alltrim(oGet:Buffer)<>"-"
    QQOut(space(1+len(oGet:Buffer)))
    QQout(fieldget(2))
    M->Buffer=oGet:Buffer
  endif
RETURN(.t.)


FUNCTION copy_buffer(p1,oGet,p2)
  ignore p1,p2
  if ! empty(M->Buffer)
    oget:varput(M->Buffer)
    oGet:updateBuffer()
  endif
RETURN(.t.)

/* 
* protokolliert evtl. Fehler etc in Sammelliste
* 3 Schritte:   INIT_P - Initialisierung (Listenkopf)
*               PROTOKOLL - Protokoll       (Listenbauch)
*               PRINT_P   - Ende,ausdrucken (ListenFuss )
*               P_CREATE_PDF  // erzeuge nur PDF, muss nach dem Erzeugen der Liste aufgereufen werden
*               P_HEADER  - Listen Kopf Zeile(n)
*               P_FILE_NAME - Name der evtl. erzeugten PDF Datei
*               P_COUNT - Liefert die Anzahl der Eintr�ge
*
* Parameters:   Status (1-4)
*               Text
*               Text2   (opt.)
*
* Info:         show PDF File after creation like this: myrun(Protokoll(P_FILE_NAME))
*
*
*/
FUNCTION Protokoll(Status,Text,Text2,Text3,Abfrage,Ausgabe,DateiName,ZielPfad)
LOCAL Zeile:=0,l,result,aktSel
  _thread static linie,empty:=.t.,spaceHeader:=0
  _thread static count:=0,seite:=1
  _thread static header1,header2,header3

  default abfrage:=.t.

  // reopen drucker in case "close data" was called meanwhile
  if Status<>INIT_P
    if select("Drucker")==0
      aktSel:=alias()
      if ! open("Drucker","Liste")
        Error(TRY_AGAIN)
        select(aktSel)
        return .f.
      endif
      if ! seekPrinter(procname(0))
        Error(TRY_AGAIN)
        select(aktSel)
        return .f.
      endif
      if aktSel<>nil .and. ! empty(aktSel)
        select(aktSel)
      endif
    endif
  endif

  do case
  case Status==INIT_P // Initialisierung

    default Ausgabe:="PDF"
    default DateiName:="Protokoll" + getUniqueCounter(COUNTER_INCREASE)

    Drucker(Ausgabe,DateiName,ZielPfad)

    // default Text2:=space(0)
    seite:=1
    empty:=.t.
    count:=0
    header1:=text
    if valtype(Text2)<>"U"
      header2:=text2
      if len(header2)>len(header1)+11+14
        spaceHeader:=len(header2)-len(header1)-11-14
      endif
      if valtype(Text3)<>"U"
        header3:=text3
        if len(header3)>len(header1)+11+14
          spaceHeader:=len(header3)-len(header1)-11-14
        endif
      else
        header3:=nil
      endif
    else
      header2:=nil
    endif

    l:=len(text)+11+14 // +Seite:
    if valtype(Text2)<>"U"
      l:=max(l,len(text2))
    endif
    if valtype(Text3)<>"U"
      l:=max(l,len(text3))
    endif
    linie:=replicate("-",l)

    Protokoll(P_HEADER)

  case Status==P_HEADER // drucke Kopf Zeile

    set cons off
    set alte on
    ? header1,space(spaceHeader),"vom: "+dtoc(getUser():date),"Seite",str(seite,3)
    count++
    if valtype(header2)<>"U"
      ? header2
      count++
    endif
    if valtype(header3)<>"U"
      ? header3
      count++
    endif
    ? Linie
    count++
    set cons on
    set alte off

  case Status==PROTOKOLL // Protokollierung

    // reopen drucker in case "close data" was called meanwhile
    if select("Drucker")==0
      aktSel:=alias()
      if ! open("Drucker","Liste")
        Error(TRY_AGAIN)
        select(aktSel)
        return .f.
      endif

      if ! seekPrinter(procname(0))
        Error(TRY_AGAIN)
        select(aktSel)
        return .f.
      endif
      select(aktSel)
    endif

    empty:=.f.
    set cons off
    set alte on
    ? text
    count++
    if ! valtype(Text2)=="U"
      ? Text2
      count++
    endif
    if ! valtype(Text3)=="U"
      ? Text3
      count++
    endif

    if count>=DRUCKER->Laenge - LISTE->Unt_Rand
      count:=FormFeed(count,Seite)
      seite++
      Protokoll(P_HEADER)
    endif
    set cons on
    set alte off

  case Status==PRINT_P // Ausdrucken

    getUser():getCurrentPrintJob():printToFileOnly:=.f.

    // erzeuge PDF
    if Protokoll(P_CREATE_PDF)

      // // drucken (quick solution, FIXME: cleanup all Protokoll)
      // seekPrinter("PROTOKOLL")
      // PrintServer:=NETZWERK_DRUCK_SERVER
      // PrinterQueue:=if(AT_HOME,trim(DRUCKER->Queue),;
      // BACKSLASH+BACKSLASH+PrintServer+BACKSLASH+trim(DRUCKER->Queue))
      // if (WIN_PRINTFILERAW( PrinterQueue,;
      // getUser():getCurrentPrintJob():pdfFullFileName,;
      // getUser():getCurrentPrintJob():jobName )) < 0
      // Error(ACHTUNG+"Protokoll konnte nicht gedruckt werden.||"+;
      // "        "+PrinterQueue+"->"+getUser():getCurrentPrintJob():pdfFullFileName,.t.,"root")
      // endif
    endif

    return .t.

  case Status==P_CREATE_PDF // erzeuge nur PDF, muss nach dem Erzeugen der Liste aufgereufen werden

    if empty
      close alte
      Drucker("RESET")
      return .f.
    endif

    set cons off
    set alte on
    ? Linie
    count++
    if ! valtype(Text)=="U"
      ? text
      count++
    endif
    if ! valtype(Text2)=="U"
      ? Text2
      count++
    endif
    FormFeed(count,Seite)
    set cons on
    set alte off
    close alte

    if count > 0 .or. seite > 1
      getUser():getCurrentPrintJob():generatePDF:=.t.

      if valtype(Abfrage)=="L" .and. Abfrage
        getUser():getCurrentPrintJob():confirmPDF:=.t.
      endif
      getUser():getCurrentPrintJob():endDoc()
      // Drucker("OFF")
      return .t.
    endif

    return .f.

  case Status == P_FILE_NAME // liefert den Namen des erzeugten PDF Files
    result:=getUser():getCurrentPrintJob():pdfFullFileName
    getUser():setCurrentPrintJob(NIL)
    return result

  case Status == P_COUNT // liefert die Anzahl der Eintr�ge
    return count

  otherwise
    ? "Falscher Protokoll Paramter:"
    ? Status

  endcase

RETURN(.t.)
/* EOF Protokoll */

/* 
* liefert �bergebenen String ohne den angebenen sub-String zur�ck
* Ergebnis String ist k�rzer oder gleich lang.
*/
FUNCTION deleteString(tempStr,deleteStr)
LOCAL x,l:=len(deleteStr)
  do while (x:=at(deleteStr,tempStr)) > 0
    tempStr:=substr(tempStr,1,x-1)+substr(tempStr,x+l)
  enddo
RETURN tempStr
/* EOF deleteString */

/* 
* liefert �bergebenen String ohne mittlere (!) Leerzeichen zur�ck ,
* die Leerzeichen werden am Ende wieder angeh�ngt, d.h. der String bleibt gleich
* lang, kann aber mit einem trim() aller Leerzeichen bereinigt werden.
*/
FUNCTION no_blanks(tempStr, trimmit)
LOCAL x,numBlanks:=0
  default tempStr:=""
  default trimmIt:=.f.
  do while (x:=at(" ",tempStr)) > 0
    tempStr:=substr(tempStr,1,x-1)+substr(tempStr,x+1)
    numBlanks++
  enddo
RETURN tempStr+if(trimmit,"",replicate(" ",numBlanks))
/* EOF no_blanks */

/* 
* liefert �bergebenen Zahl als String ohne triling 0 nach dem Punkt.
* 
* also: 10.2000 => 10.2
*/
FUNCTION no_trailing_zeros(value)
LOCAL cString:=alltrim(str(value)) // Remove trailing spaces
  IF "." $ cString
    DO WHILE RIGHT(cString, 1) == "0"
      cString:=LEFT(cString, LEN(cString) - 1)
    ENDDO
    // Remove the decimal point if it's the last character
    IF RIGHT(cString, 1) == "."
      cString:=LEFT(cString, LEN(cString) - 1)
    ENDIF
  ENDIF
return cString
/* EOF */

/*
* liefert �bergebenen String ohne . zur�ck, Ergebnis ist enstprechend k�rzer
*/
FUNCTION no_dots(tempStr)
LOCAL x,numBlanks:=0
  do while (x:=at(".",tempStr)) > 0
    tempStr:=substr(tempStr,1,x-1)+substr(tempStr,x+1)
  enddo
RETURN tempStr
/* EOF */

/* FUNCTION digitOnly()
*
* liefert nur die Zahlen des �bergebenen Strings zur�ck mit (!) Leerzeichen,
* Kommas,Buchstaben etc. werden durch Leerzeichen ersetzt
  *
  * siehe #no_blanks()
*/
FUNCTION digitOnly(tempStr)
LOCAL i,result:="",num:=0,val
  for i:=1 to len(tempStr)
    val:=substr(tempstr,i,1)
    if isDigit(val) .or. val==" "
      result+=substr(tempstr,i,1)
    else
      result+=" "
    endif
  next
RETURN result
/* EOF no_blanks */

/* schaltet
   Farbe zur Hervorhebung ein */
FUNCTION color_on()
  toggleColor("ON")
RETURN .t.

FUNCTION toggleColor(toggle)
  _thread static Farbe
  if upper(toggle)=="ON"
    Message("Color red")
    Farbe:=setcolor("R/W")
  else
    Message("Color default")
    setcolor(Farbe)
  endif
RETURN .t.
/** eof */

/* 
* falls ESC gedr�ckt geht ans Ende der akt. Datei
*
* und gibt true zur�ck ansonsten false
*/
FUNCTION Stop_Key
LOCAL Stop:=inkey()
LOCAL Zeile:=0
  if stop==K_ESC
    // jojo: hier eigentlich ?? wegen Zeilenz�hler, aber bei MIKI egal
    if DRUCKER->DruckerNr="BS"
      ? BS_FARBE+"---------  Druck Unterbrochen ---------"+BS_FARBE
    else
      ? "---------  Druck Unterbrochen ---------"
    endif
    // raus a, 3.12.2010 okay? jojo
    // go bottom
    // skip
    Message("Druck unterbrochen.  Bitte warten...")
    // n_cancelcap(1)
    RETURN(.t.)
  endif
RETURN(.f.)
/** eof */


/** Returns the character name for the month of the given date in CP1252 DEWIN */
function myCMonth(Datum)
return hb_translate(cMonth(Datum), "EN", "DEWIN")
/** eof */

/** L�scht unn�tige Logfiles, kopiert & schickt krit. log Dateien an MY_EMAIL */

Procedure MyHouseKeeping(logfiles)
LOCAL myDat:=getUser():date-1 // crontab l�uft nach Mitternacht
LOCAL bakverz:=MAIL+BACKSLASH+"bak-"+str(year(myDat),4)+;
  right("00"+alltrim(str(month(myDat)),),2)+right("00"+alltrim(str(day(myDat)),),2)
LOCAL logfile,logfilelist:={},tempFileName,tempMailNames,mailFile
LOCAL tempFehler:=(TEMP_USER+BACKSLASH+"fehler.dbf")
LOCAL tempFehlerMemo:=(TEMP_USER+BACKSLASH+"fehler"+ MY_MEMO_EXTENSION)
LOCAL aText:={},extension, preText:=""

  default logfiles:={}

  if open({"Fehler",.t.})
    set filter to FEHLER->date>=getUser():date-1
    go top
    if ! FEHLER->(eof())
      copy to (tempFehler)
      aadd(aText,"Fehler.dbf:")
      aadd(aText,"===========")
      go top
      do while ! FEHLER->(eof())
        aadd(aText,dtoc(FEHLER->Date)+" "+FEHLER->Time)
        aadd(aText,trim(FEHLER->DESCRIPT)+" -- Fehler:"+str(FEHLER->CODE,5))
        aadd(aText,trim(FEHLER->OPERATION)+"     "+trim(FEHLER->FILENAME))
        aadd(aText,"User:"+FEHLER->User+" "+FEHLER->ClientName)
        aadd(aText,memotran(FEHLER->Call))
        aadd(aText,"----")
        aadd(aText,"")
        skip
      enddo

      preText:="!!! "
    endif
    // l�sche alle Fehler die �lter als 1 Monat sind
    set filter to
    go top
    delete for FEHLER->date<=getUser():date-30
    pack
    close data
  endif

  // send some logfiles per email
  for each logfile in { HARBOUR_ERROR_LOG, tempFehler , tempFehlerMemo }
    aadd(logfiles,logFile)
  next

  // Freitag morgen/nachts alle MAIL.inf Dateien schicken & verschieben
  if dow(myDat)==5
    tempMailNames:=directory(MAIL+BACKSLASH+"*.inf")
    ASort( tempMailNames ,,, {|x,y| x[F_TIME] < y[F_TIME] } )
    for each mailFile in tempMailNames
      aadd(logfiles,MAIL+BACKSLASH+mailFile[F_NAME])
      aadd(aText,left(mailFile[F_NAME]+space(20),20)+" "+trim(transstr(mailFile[F_SIZE],12,0))+" kb "+;
        dtoc(mailFile[F_DATE])+" "+mailFile[F_TIME])
    next
  endif

  // now send & backup & erase the log files
  for each logfile in logFiles
    if file(logfile)
      mkmydir(bakverz)
      tempFileName:=getFileName(logfile)
      // myrun("copy ",logfile+" "+bakverz+BACKSLASH+tempFileName,.t.)
      // ferase(logfile)
      frename(logfile,bakverz+BACKSLASH+tempFileName)
      aadd(logfilelist,bakverz+BACKSLASH+tempFileName)

      if "root.inf" $ logfile .and. empty(preText)
        preText:="!!! "
      endif
    endif
  next

  // send email, disabled 20251003
  // do case
  // case len(logfilelist)==1
  // email(MY_EMAIL,preText+"Logfile attached",aText,logfilelist)
  // case len(logfilelist)>1
  // email(MY_EMAIL,preText+alltrim(str(len(logfilelist)))+" Logfiles attached",aText,logfilelist)
  // endcase

  // move all logfiles etc. to backup folder
  for each extension in {"*.inf","*.txt","*."+SCREENSHOT_EXT}
    logFiles:=directory(MAIL+BACKSLASH+extension)
    for each logFile in logFiles
      frename(MAIL+BACKSLASH+logfile[F_NAME],bakverz+BACKSLASH+logfile[F_NAME])
    next
  next

  close data
return
/** eop */

  /** returns the current background color
  * e.g. from color string "W+/BG,N/G,R/R" returns BG
  * info: harbour fkt. getClrBack() returns entire string "BG,N/G,.."
  */
function getBackColor()
local col:=setColor()
  col:=substr(col,at("/",col)+1)
  col:=left(col,at(",",col)-1)
return col
/** eof */


procedure showColors()
LOCAL nRow, nCol, nColor, cColor

  nRow:=0
  nCol:=0

  FOR nColor:=0 TO 255
    cColor:=NtoColor( nColor, .T. )

    @ nRow, nCol SAY PadC( cColor, 8 ) COLOR (cColor)

    IF ++nRow > MaxRow()
      nRow:=0
      nCol += 8
    ENDIF
  NEXT
  Message("Bitte @Taste@ d�cken","@")
return
/** eop */

  /** Pastes the clipboard contents to the keyboard buffer.
  *
  * Parameter: Array with method names where the text should not (!) be truncated after 1st CR
  */
function pasteClipBoard(excep)
LOCAL text:=hb_gtInfo( HB_GTI_CLIPBOARDDATA )
LOCAL ret:=at(MY_CR,text),i:=1,truncate:=.t.

  // only when the CTRL key is pressed, since INSERT has the same key code as CTRL_V :(
  // if FT_CTRL()
  if hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL )

    default excep:={}
    aadd(excep,"MYMEMOEDIT")
    aadd(excep,"MEMOEDIT")

    // truncate clipboard at CarriageReturn for most functions
    if ret>0
      do while i<=len(excep) .and. truncate
        truncate:=(!inStackTrace(excep[i]))
        i++
      enddo
      if truncate
        text:=left(text,ret-1)
      endif
    endif
    KeyBoard (removeTrailingCRLF(trim(text)))

  else // no ctrl -> insert key
    ChangeCursor()
  endif

return .t.
  /** eof */

static function removeTrailingCRLF(cString)
  if right(cString,1)==MY_LF
    cString:=left(cString,len(cString)-1)
  endif
  if right(cString,1)==MY_CR
    cString:=left(cString,len(cString)-1)
  endif
return cString
  /** eof */

/* removes prefix from string if it starts with it */
function lstrip(text, removeText)
LOCAL l:=len(removeText)
LOCAL result:=text
  if left(text,l)==removeText
    result:=substr(result, l+1)
  endif
return result

/* removes postfix from string if it ends with it */
function rstrip(text, removeText)
LOCAL l:=len(removeText)
LOCAL result:=text
  if right(text, l)==removeText
    result:=left(text,len(text)-l)
  endif
return result

  /** Bricht den Text an der �bergebenen Stelle um, und gibt enstpr. String-Array zur�ck.
  *   Ergebnis Zeilen sind genau "col" Spalten breit.
  *
  *   returns: Array ist genau numRows lang, falls angegeben.
  *
  *   Bricht auch bei BACKSLASH (manueller Umbruch) um
  * */
  #define LINE_SEP " -/"+MY_CR+MY_LF
FUNCTION lineWrap(text,col,numRows)
LOCAL result:={}
LOCAL x

  if text == NIL
    return result
  endif

  if col==NIL // nur manueller Umbruch
    col:=len(text) - 1
  endif

  do while len(text) > col .or. at(BACKSLASH,text)>0
    // manueller Umbruch?
    if at(BACKSLASH,left(text,col)) > 0
      x:=at(BACKSLASH,left(text,col)) -1
    else
      // finde letztes Trennzeichen
      x:=col
      do while x>0 .and. ! substr(text,x,1)$LINE_SEP
        x--
      enddo
      if x==0
        x:=col
      endif
    endif

    aadd(result,strtran( left(text,x) ,"�"," ") )
    text:=ltrim(substr(text,x+1))
    if left(text,1)==BACKSLASH // war manueller Umbruch
      text:=ltrim( substr(text,2) )
    endif

  enddo

  aadd(result,strtran( text ,"�"," ") )

  if numRows<>NIL
    do while len(result)<numRows
      aadd(result,space(col))
    enddo
  endif

return result
/** eof */

/** Pr�ft ob ein Feld leer ist oder mit zu einfacher Eingabe, z.B. 111
  *
  * Returns: .t. falls leer oder zu einfach -> reject
  */
FUNCTION emptyOr2Simple(feld,mindLen)
LOCAL x , i , countX:=0 , countY:=0

  feld:=trim(feld)

  default mindLen:=3

  if empty(feld) .or. len(feld)<mindLen
    return .t.
  endif

  // pr�fe ob mehr als 3 nachfolgende Zeichen gleich sind, bzw. aufsteigen
  x:=substr(feld,1,1)
  i:=2
  do while i<=len(feld) .and. i < 5 // nur bei den 1. 5 Zeichen
    // 1. Fall: Zeichen unterschiedlich
    if x <> substr(feld,i,1)
      // �berpr�fe aufsteigende Reihenfolge
      if asc(substr(feld,i,1)) - asc(x) == 1
        countY++
      else
        countY:=0
      endif
      countX:=0
      x:=substr(feld,i,1)
    else // 2. Fall: Zeichen gleich
      countX++
      countY:=0
    endif
    if countX > 2 .or. countY > 2
      return .t.
    endif
    i++
  enddo

return .f. // nicht empty
/** eof */

  /** centers the passed string on the passed length
  *  FIXME: use harbour function pad(s,lenth,"") instead
  */
FUNCTION mycenter(s,length)
LOCAL diff,result

  default length:=80 // page width is default

  s:=alltrim(s)
  diff:=length-len(s)
  if diff < 0
    return left(s,length)
  endif
  result:=left(space(int(diff/2))+s+space(int(diff/2))+space(1),length)

return result
/** eof */


/* Setzt die �bergebene Taste auf den Codeblock und liefert immer .t. zur�ck */
FUNCTION MySetKey(key,cb)
  SetKey( key,cb)
return .t.
/** eof  */


/** Liefert das aktuelle Datum als String: YYYY-MM-DD-hh_mm_ss zur�ck */
FUNCTION getFileStyleDate( date , ms )
LOCAL dateFormat:=Set( _SET_DATEFORMAT )
LOCAL result

  default date:=getUser():date
  default ms:=.t.

  SET DATE FORMAT TO "yyyymmdd"
  result:=dtoc(date)
  // reset date type
  SET DATE FORMAT TO (dateFormat)

  if ms
    result += "-"+strtran(time(),":","_")
  endif

RETURN result
/** eof */

/** Devel-Funtcion for testing elapsed time
* keywords: time(),seconds(), timers
* usage:

  LOCAL aTimers:=init_timers()
  ....                   -> code to test
  test_timers( aTimers ) // -> debug output
  wait

*/
function init_timers()
return { hb_secondscpu(1), hb_secondscpu(2), hb_secondscpu(3), 
  seconds() }
/** eof */

function test_timers( aTimers )
  qout( "user space", hb_secondscpu(1) - aTimers[1], "sec." )
  qout( "    system", hb_secondscpu(2) - aTimers[2], "sec." )
  qout( "     total", hb_secondscpu(3) - aTimers[3], "sec." )
  qout( " real time", seconds() - aTimers[4], "sec." )
return nil
/** eof */


/** Prints all development info */
procedure develInfo()
LOCAL k,zeile:=0

  Drucker("BS")

  ? "Customer:",getProperty("Customer.name","none")
  ? "Test :",getProperty("System.test","?")
  ? "DEVEL:",getProperty("System.devel","?")
  ?
  ? "Harbour build date:                " + hb_Version( HB_VERSION_BUILD_DATE_STR )
  ? "Major version number:              " , hb_Version( HB_VERSION_MAJOR )
  ? "Minor version number:              " , hb_Version( HB_VERSION_MINOR )
  ? "Revision number:                   " , hb_Version( HB_VERSION_RELEASE )
  ? "Build status:                      " , hb_Version( HB_VERSION_STATUS )
  ? "-------------------------------------------------------------------"
  for k = 0 TO 25
    ? k , hb_Version( k )
  next k
  ? "-------------------------------------------------------------------"
  ? "Compiler used:                     " , hb_Version( HB_VERSION_COMPILER )

  Drucker("OFF")

RETURN
/** eop */


/** L�dt einen Screenshot aus einer Datei
  * see sceenFile()
  */
procedure restScreenFromFile()
LOCAL fileName

  if (fileName:=openFileDialog(LOAD,"C:\schrott",nil,SCREENSHOT_EXT,nil))<>NIL
    hb_threadStart(HB_THREAD_INHERIT_PUBLIC, @showScreenShot(),fileName)
  endif
RETURN
/** eop */

/** Zeigt �bergebenen ScreenShot Datei in neuem Fenster & Thread an */
procedure showScreenShot(fileName)
LOCAL sizeValues

  /* allocate own GT driver */
  hb_gtReload( "WVT" )
  hb_gtInfo( HB_GTI_WINTITLE, fileName )

  // resize screen
  if at( SCREENSHOT_KEY_SIZE , fileName ) > 0
    sizeValues:=HB_ATokens( fileName , SCREENSHOT_KEY_SEP )
    qout(" ") // needed as workaround for bug in setSize
    hb_gtInfo(HB_GTI_SCREENSIZE , { val(sizeValues[1]) , val(sizeValues[2]) } )
  endif

  fileScreen(fileName)
  warte(0)

RETURN
/** eop */

/** schickt den akt. Screen per Email an MY_EMAIL */
function sendScreenShot(p1,p2,p3)
LOCAL text:="" , ant:=" ", subject:=space(64)
LOCAL GetList:={} , s001
LOCAL keySave

  ignore p1,p2,p3

  Umgebung( WRITE )
  keySave:=HB_SetKeySave(NIL)
  setcolor(COLWIN)
  Fenster(10,1,21,77,"Email an GruhnSoft")

  // Eingabe Kommentar
  do while ! ant $ "JN"
    Message("Email an H. Gruhn schicken.  Bitte Betreff eingeben.    @ESC@=Ende")
    setkey( K_ESC , { |p1, oGet| exitSendEmail( p1, oGet ) } )
    @ 12,3 say "Betreff:" get subject
    read
    Set Key K_ESC to

    if ! ABBRUCH
      Message("Email an H. Gruhn schicken.  Bitte Text eingeben.    @ESC@=Ende")
      text:=MyMemoEdit(text,14,2,20,76, .t.)
    endif

    if empty( text ) .and. empty( subject )
      ant:="N"
      loop
    endif

    // ESC soll Abfrage nicht beenden
    ant:=Message("Email verschicken? (@J@/@N@)    @ESC@ = weiter bearbeiten","JN"," ")
  enddo

  Umgebung( LOAD )
  if ant == "J"
    s001:=savescreen( 0,0,maxrow(),maxcol())
    Message( "Email wird verschickt.     Bitte warten...")
    TroubleEmail( text , "User Request:" + subject )
    restscreen(0,0,maxrow(),maxcol(),s001)
  endif

  HB_SetKeySave(keySave)

return .t.
/** eof */

static function exitSendEmail( p1, oGet )

  ignore p1

  if empty( oGet:buffer )
    oget:undo()
    oget:exitState:=GE_ESCAPE
  else
    oget:exitState:=GE_ENTER
  endif
return .t.

/** liefert die �bergebene Variable als String (getrimmed ist default) zur�ck */
function toString(value,trimmIt) // includes objDump() for valtype=="O"
LOCAL result,i,tempVal
LOCAL TRUNCATE_NOF_ENTRIES:=50

  default trimmIt:=.t.

  switch valtype(value)
  case "C"
  case "M"
    result:=value
    exit
  case "N"
    result:=transform(value,"@E")
    exit
  case "D"
    result:=dtoc(value)
    exit
  case "T" // DateTime
    result:=TtoC(value)
    exit
  case "L" // Logical
    if value
      result:=".t."
    else
      result:=".f."
    endif
    exit
  case "A" // Array
    result:="{"
    for i:=1 to min(len(value),TRUNCATE_NOF_ENTRIES)
      result += toString(value[i])+" "
    next
    if len(value) > TRUNCATE_NOF_ENTRIES
      result+="... truncated "
    endif
    result:=trim(result)+"}"
    exit
  case "O" // Object
    result:=hb_DumpVar( value ,.t.,2 ) // recursive, 2 level max
    exit
  case "S" // Error-Code-Block
    result:="ErrorBlock" // FIXME: how to get the details of a CodeBlock
    exit
  case "B" // Code-Block
    result:="CodeBlock" // FIXME: how to get the details of a CodeBlock
    exit
  case "H" // Hash-Object
    result:="{"
    i:=1
    for EACH tempVal IN value:keys
      result += toString( tempval ) +"->"+ toString(value[tempVal]) +", "
      i++
      if i > TRUNCATE_NOF_ENTRIES
        result+="... truncated "
        exit
      endif
    NEXT
    result:=trim(result)
    if right(result,1)==","
      result:=left(result,len(result)-1)
    endif
    result +="}"
    exit
  case "P"
    result:="Pointer"
    exit
  case "U" // Undefined == NIL
    result:="NIL"
    exit
  otherwise
    Error("MyTools.prg#toString():  Datenformat nicht unterst�tzt:"+valtype(value),.t.)
    result:="*UNKNOWN TYPE*"
  endswitch

return if(trimmIt,alltrim(result),result)
/** eof */

/** liefert falls m�glich einen numerischen Wert zur�ck, ansonsten 0 */
function toNumValue(value)
LOCAL result:=0

  BEGIN SEQUENCE // krit. Bereich
    switch valtype(value)
    case "C"
      result:=val(value)
      exit
    case "N"
      result:=value
      exit
    endswitch
  END Sequence
return result
/** eof */

/** Startet eine Info-Anzeige als extra Programm im Hintergrund */
procedure extMsgBox(text)
  // startet neuen Prozess ohne msdos box!
  if wapi_SHELLEXECUTE( 0, 0, "MsgBox", '"'+getProperty("System.window.title","Info")+'" '+;
    text , 0, 0 )<>42
    // if msgbox not in path, try bin directory
    wapi_SHELLEXECUTE( 0, 0, ".\bin\MsgBox", '"'+getProperty("System.window.title","Info")+'" '+;
      text,0,0)
  endif
return
/** eop */

/*
 * returns all public data (variables) of a class
*/
FUNCTION objGetAllVarNames( oObject )
LOCAL aReturn
LOCAL aVars,aVar

  IF ! ISOBJECT( oObject )
    Error("Kein Objekt �bergeben.")
  ENDIF

  aVars:=__objGetMsgFullList( oObject, .T., HB_MSGLISTALL,NIL, HB_OO_MSG_METHOD)
  // aVars:=__objGetMsgFullList( oObject, .T., HB_MSGLISTALL,HB_OO_MSG_METHOD, HB_OO_MSG_DATA )
  aReturn:={}
  FOR EACH aVar IN aVars
    AAdd( aReturn, aVar[HB_OO_DATA_SYMBOL] )
  NEXT

  // close alte

RETURN aReturn
/** eof */

/*
 * (C) 2003 - Francesco Saverio Giudice
 *
 * return all informations about classes, included type and scope
*/
FUNCTION __objGetMsgFullList( oObject, lData, nRange, nScope, nNoScope )
LOCAL aMessages
LOCAL aReturn
LOCAL nFirstProperty, aMsg

  IF ! ISOBJECT( oObject )
    Error("Kein Objekt �bergeben.")
  ENDIF

  IF ! ISLOGICAL( lData )
    lData:=.T.
  ENDIF

  IF ! ISNUMBER( nNoScope )
    nNoScope:=0
  ENDIF

  // nRange is already defaulted in ClassFullSel in classes.c

  aMessages:=ASort( oObject:ClassSel( nRange, nScope, .T. ),,, {|x,y| x[HB_OO_DATA_SYMBOL] < y[HB_OO_DATA_SYMBOL] } )
  aReturn:={}

  nFirstProperty:=aScan( aMessages, { | aElement | Left( aElement[HB_OO_DATA_SYMBOL], 1 ) == '_' };
    )

  // set alte to foo-all.txt
  // set alte on

  FOR EACH aMsg IN aMessages

    // qout(aMsg[1],aMsg[2],aMsg[3],aMsg[4])

    IF Left( aMsg[HB_OO_DATA_SYMBOL], 1 ) == '_'
      LOOP
    ENDIF

    // IF ( AScan( aMessages, { | aElement | aElement[HB_OO_DATA_SYMBOL] == "_" + aMsg[HB_OO_DATA_SYMBOL] }, nFirstProperty ) != 0 ) == lData
    IF nNoScope == 0 .OR. HB_BITAND( aMsg[HB_OO_DATA_SCOPE], nNoScope ) == 0
      AAdd( aReturn, aMsg )
    ENDIF
    // ENDIF
  NEXT

  // close alte

RETURN aReturn
/** eof */

/** returns an array of all methods of an object */
FUNCTION __objGetMsgType( obj, msgType, msgScope, filtSuper )
LOCAL itm
LOCAL aClsSel
LOCAL a:={}

  IF msgScope = NIL
    msgScope:=0
  ENDIF

  aClsSel:=obj:ClassSel( HB_MSGLISTPURE, msgScope, .T. )

  FOR EACH itm IN aClsSel
    IF !filtSuper == .T. .OR. HB_BitAnd( itm[ HB_OO_DATA_SCOPE ], HB_OO_CLSTP_SUPER ) = 0
      IF msgType = NIL .OR. itm[ HB_OO_DATA_TYPE ] = msgType
        AAdd( a, itm[ HB_OO_DATA_SYMBOL ] )
      ENDIF
    ENDIF
  NEXT
RETURN a
/** eof */

/** K�rzt den �bergebenen "Bruch" und liefert das Ergebnis als Array zur�ck
  z.B. 3/6 -> [1,3]
  */
function reduceFraction(a,b)
LOCAL i

  for i:=min(a,b) to 2 Step -1
    if a%i==0 .and. b%i==0
      a:=a/i
      b:=b/i
    endif
  next

return {int(a),int(b)}
/** eof */

/* Crontab anzeigen / �ndern */
PROCEDURE CroDisp(Aendern)
LOCAL GetList:={}

  @ 9,12 clear to 16,60
  @ 9,12 to 16,60
  @ 10,14 say "Name.....: " get CRONTAB->CronName picture "@!"
  @ 12,14 say "Datum....: " get CRONTAB->Datum
  qqout(" (letzte Ausf�hrung)")
  @ 13,14 say "Wochentag: " get CRONTAB->WochenTag
  qqout("  "+dowName(CRONTAB->WochenTag))
  @ 14,14 say "Monat....: " get CRONTAB->Monat
  qqout(" "+mycmonth(ctod("01."+alltrim(str(CRONTAB->Monat))+".13")))
  @ 15,14 say "Excel....: " get CRONTAB->Excel picture "@!"valid CRONTAB->Excel $ "JN "

  if Aendern
    Sperr_Reader( GetList )
    GetList:={}
    dbcommit()
  else
    Sperr_Reader(GetList,.t.,"AUSGABE")
    GetList:={}
  endif

RETURN
/** eop */

/** shiftet die dow() Ergebnisse so, dass Montag der 1. Tag ist -> zum sortiern */
function dowShift(num)
  if num==1 // Sonntag
    return 8
  endif
return num
/** eof */

/** liefert den Namen des Wochentages */
function dowName(num)
LOCAL result:=""
  switch num
  case 1
    result:="Sonntag"
    exit
  case 2
    result:="Montag"
    exit
  case 3
    result:="Dienstag"
    exit
  case 4
    result:="Mittwoch"
    exit
  case 5
    result:="Donnerstag"
    exit
  case 6
    result:="Freitag"
    exit
  case 7
    result:="Samstag"
    exit
  endswitch

return result
/** eof */


/** in depth compare of all elements in both array, was Function ArrayCompare.
    returns die Position des 1. Diffs, 0 == keine Diffs
    */
Function ArrayDiff(a1, a2) // aCompare, vergleiche den Inhalt 2er arrays
local lSame:=.T.
local x, result:=0

  if valtype(a1) <> "A" .or. valtype(a2) <> "A" // Not arrays?
    lSame:=.F.
  elseif len(a1) <> len(a2) // Different lengths?
    lSame:=.F.
  else
    for x:=1 to len(a1)
      if valtype(a1[x]) == valtype(a2[x]) // Same data type?
        if valtype(a1[x]) == "A"
          lSame:=len(ArrayDiff(a1[x], a2[x])) == 0 // Recurse subarrays
        else
          lSame:=(a1[x] == a2[x]) // Exactly equal values?
        endif
      else
        lSame:=.F.
      endif
      if !lSame // Don't continue once failure is known!
        result:=x
        exit
      endif
    next
  endif
Return result
/** eof */

/** liefert einen String als lower und den 1. Buchstaben als upper */
function toReadable(s) // almost CamelCase
return upper(left(s,1))+lower(substr(s,2))
/** eof */

/** liefert einen String als PascalCase */
function ToPascalCase(cString)
LOCAL aWords:={}, cWord, cFinal:=""

  // Split the string into words based on spaces
  aWords:=HB_ATokens(cString, " ")

  // Capitalize the first letter of each word and concatenate
  FOR EACH cWord IN aWords
    cFinal += UPPER(LEFT(cWord, 1)) + LOWER(SUBSTR(cWord, 2))
  NEXT

RETURN cFinal
/** eof */

/** markiert alle Crontab-Eintr�ge als ausgef�hrt */
PROCEDURE clearCrontab()
  if open({"Crontab",.t.})
    replace all CRONTAB->Datum with ctod("  .  .  ")
  endif
  close data
  Message("Alle Crontab Eintr�ge als offen markiert.   @Taste@","@")
return

/** markiert alle Crontab-Eintr�ge als ausgef�hrt */
PROCEDURE fillCrontab()
  if open({"Crontab",.t.})
    replace all CRONTAB->Datum with getUser():date
  endif
  close data
  Message("Alle Crontab Eintr�ge als erledigt markiert.   @Taste@","@")
return

  /**
  * liest alle Windows Prozess in Prozesse.dbf ein und l�schte alle die ungleich name?.xxx  sind
  */
procedure readRunningProcesse(name)
LOCAL TempFile:=TEMP+BACKSLASH+"Proz"+getUser():getLongID() + ".csv"
LOCAL base,ext

  if ! open("Prozesse")
    Error( TRY_AGAIN )
    close data
    return
  endif
  zap

  myrun("TASKLIST"," /FO csv /v > " + TempFile,.t.)

  append from (TempFile) delimited

  // now delete non matching names
  base:=getFileBaseName( name )
  ext:=getFileExt( name )
  base:=removeExeCounter( base )

  // add wildcard to name
  //name:=base + ".*" + ext
  name:=base + ext // removed * because of hbmiki-service
  delete for ! HB_RegExMatch( name , PROZESSE->Abbildname , .f. )
  pack

return
/** eop */

/**
* removes triling 1-9 from filename like hbmiki1 -> hbmiki
*/
function removeExeCounter( name )

  if isDigit(right(name,1))
    name:=substr( name , 1 , len(name) -1 )
  endif

return name
  /** eof


/** killt alle Prozess mit �bergebenem Prozess-Namen, au�er (!) den eigenen */
function killByName(name,fileName)
LOCAL aktTitle:=hb_gtInfo(HB_GTI_WINTITLE, MAIN_WINDOW_NAME+" calling killByName()")
LOCAL aktSel:=alias()

  // disabled for Test-System
  // if TEST_PROG
  // return 0
  // endif

  readRunningProcesse( name )

  select Prozesse
  go top
  do while ! PROZESSE->(eof())
    // kill it if it is not the current process
    if type(PROZESSE->PID)=="N" .and. val(PROZESSE->PID) <> wapi_getCurrentProcessID()
      killByPID(alltrim(PROZESSE->PID))
    endif
    skip
  enddo

  // Fehler protokollieren
  readRunningProcesse( name )

  if PROZESSE->(reccount()) > 1
    set alte to (filename)
    set alte on
    set cons off

    select Prozesse
    go top
    do while ! PROZESSE->(eof())
      // kill it if it is not the current process
      if type(PROZESSE->PID)=="N" .and. val(PROZESSE->PID) <> wapi_getCurrentProcessID()
        qout("not killed:" )
      else
        qout("current   :" )
      endif
      qqout( alltrim( PROZESSE->PID ) + " " + alltrim( PROZESSE->Abbildname ) + " " +;
        alltrim( PROZESSE->Sitzungsna ) + " " + alltrim( PROZESSE->Benutzerna ) + " '" + ;
        alltrim( PROZESSE->Fenstertit ) + "'")
      skip
    enddo

    set cons on
    set alte off
    close alte

  endif

  hb_gtInfo(HB_GTI_WINTITLE, aktTitle)

  if ! myEmpty( aktSel )
    select (aktSel)
  endif

return PROZESSE->(reccount())
/** eof */

/** killt alle Prozess mit �bergebenem Process ID */
static function killByPID(PID)
LOCAL result:=.f.
  if valtype(pid)=="C"
    myrun("taskKill","/PID "+pid,.t.)
    inkey(2)
    myrun("taskKill","/PID "+pid+" /F",.t.)
    result:=.t.
  endif
return result
/** eof */

/** Pingt den remote service s. mynetio.ch */
function pingRemoteService()
LOCAL objErr, result:=NIL
  BEGIN SEQUENCE
    if ! myEmpty( NETSERVER )
      if netio_connect( NETSERVER , NETPORT, NETTIMEOUT , decrypt(NETPASSWD_ENCRYPTED))
        if net:exists:remote_ping
          result:=net:remote_ping(getUser():id)
        endif
        netio_disconnect( NETSERVER, NETPORT )
      endif
      if result==NIL // lokal aufrufen
        TroubleEmail("Ping Remote failed!")
      else
        result:=.t.
      endif
    endif
  RECOVER USING objErr
    netio_disconnect( NETSERVER, NETPORT )
    TroubleEmail("Ping Remote crashed!")
  END SEQUENCE
return result <> NIL .and. result
/** eof */

  /** runs a procedure / function in the background
  * Procedure should not have any screen output
  *
  * We keep noc reference to the thread id, so it is always detached
  *
  * Call with runBackgroundTask( @AufBest() [,param1][,param2][,param3]...)
  */
procedure runBackgroundTask(func,...)

  HbConsoleLock() // (not working???)
  hb_threadStart( HB_THREAD_MEMVARS_COPY, @_runBackgroundTask(), func , getUser():id , ... )
  HbConsoleUnlock()

return

/** Logs in the passed user, reads the config file, launches the func
*   and logs out again */
static procedure _runBackgroundTask( func , userID , ... )
LOCAL GetList:={}

MEMVAR User,QTWidget
  PUBLIC User:=NIL
PRIVATE QTWidget

  // we need a proper login, to avoid concurreny conflicts

  // we need this since the memotype setting (rddInfo( RDDI_MEMOEXT , ".dbt" , "DBFCDX" ))
  // is not inherited
  rddSetDefault(MY_RDDI)
  rddInfo( RDDI_MEMOEXT , MY_MEMO_EXTENSION , MY_RDDI )

  readProperties(getPropertiesFileName())
  setProperty("System.window.gtwvt","N")
  init(userID)
  getUser():isBackgroundTask:=.t.

  /* allocate own GT driver -> for debugging */
  // hb_gtReload( "WVT" )
  // altd()

  // now run the task
  eval( func, ... )

  // clean up
  logout()

return
/** eop */

/** f�gt eine Liste von Elementen zu einem Array, see also aJoin
  * liefert analog zu aadd() die hinzuf�gten Werte zur�ck als Array, NICHT das Gesamt-Array
  */
function myAadd(array, ...)
LOCAL aValues:=hb_aParams() , i
  for i:=2 to len(aValues)
    aadd( array , aValues[i] )
  next
return aValues
/** eof */

/**
  * liefert true wenn ein Array ein Element enth�lt
  */
function aContains(array, element)
LOCAL i
  for i:=1 to len(array)
    if array[i] == element
      return .t.
    endif
  next
return .f.
/** eof */


/**
  * liefert die Schnittmenge von zwei Arrays
  */
function aIntersect(array1, array2)
LOCAL i, result:={}
  for i:=1 to len(array1)
    if aContains(array2, array1[i])
      aadd( result, array1[i])
    endif
  next
return result
/** eof */


/**
  * liefert die die invertierte Schnittmenge, also alle Elemente die nur in einem der beiden Array vorkommen.
  */
function aDiff(array1, array2)
LOCAL i, result:={}
  for i:=1 to len(array1)
    if .not. aContains(array2, array1[i])
      aadd( result, array1[i])
    endif
  next
  for i:=1 to len(array2)
    if .not. aContains(array1, array2[i])
      aadd( result, array2[i])
    endif
  next
return result
/** eof */


/** F�gt das �bergebenen Element zu dem Array, falls es noch nicht darin enthalten ist (Set)
  */
function aaddUnique( array , element )
  if aScan( array , element ) == 0
    aadd( array , element )
  endif
return array
/** eof */

/**
  * merged 2 oder mehrere arrays in ein neues, liefert das Ergebnis als Array zur�ck
  */
function aJoin(...)
LOCAL aValues:=hb_aParams()
LOCAL result:={} , arr
  for each arr in aValues
    aEval( arr , { |x| aadd( result , x ) } )
  next
return result
/** eof */

/**
  * merged 2 oder mehrere arrays in ein neues, liefert das Ergebnis als Array zur�ck
  */
function aJoinUnique(...)
LOCAL aValues:=hb_aParams()
LOCAL result:={} , arr
  for each arr in aValues
    aEval( arr , { |x| aaddUnique( result , x ) } )
  next
return result
/** eof */


/** F�gt ein Array als Token-String zusammen
  FIXME: duplicate array2readable*/
FUNCTION AaToToken( aArray, cDelim, nFrom, nTo )
LOCAL cReturned:="", nX

  cDelim:=IIF( VALTYPE( cDelim ) == "U", ";", cDelim )
  nFrom:=IIF( VALTYPE( nFrom ) == "U", 1, nFrom )
  nTo:=IIF( VALTYPE( nTo ) == "U", LEN( aArray ), nTo )

  FOR nX:=nFrom TO nTo - 1
    cReturned += aArray[nX] + cDelim
  NEXT nX
  cReturned += aArray[ nTo ]

RETURN cReturned
/** eof */


/* 
 * gibt die Art.Nr ohne Pkt. und Spaces zur�ck, Ergebnis String ist entsprechend k�rzer
*/
FUNCTION invOut(Artikel)
return no_dots(no_blanks(Artikel ))

/** Ersetzt alle deutschen Umlaute mit validen Zeichen:
  *
  * � -> ae
  * � -> ue
  * etc.
  */
FUNCTION cleanUmlaut( text )
  // translate german sonderzeichen
  text:=strtran(Text,"�","ae")
  text:=strtran(Text,"�","oe")
  text:=strtran(Text,"�","ue")
  text:=strtran(Text,"�","Ae")
  text:=strtran(Text,"�","Oe")
  text:=strtran(Text,"�","Ue")
  text:=strtran(Text,"�" ,"ss")
return text
/** eof */

/* vergleicht 2 Werte mit der �bergebenen Toleranz
* teilw. verwendet um Rundungsproblematik zu umgehen
*
* returns value < 0 if v1 < v2
* returns value > 0 if v1 > v2
* returns 0 otherwise
*/
function flexCompare( v1 , v2 , toleranz )
LOCAL tempVal:=v1 - v2

  if abs( tempVal ) <= toleranz
    return 0
  endif

return tempVal
/** eof */

/** pr�ft ob ein numerischer Eingabewert die angegeben Gr��e �bersteigt
  * falls ja muss dies best�tigt werden
  */
function maxConfirm( oGet , limit , text )
LOCAL result:=.t.

  if lastkey() <> K_UP
    default text:="Menge"
    if val(oGet:buffer) > limit
      result:=Message(text + " ist gr��er als " + alltrim(transform(limit,"@E 999,999")) + ;
        " - Ist diese Eingabe korrekt? (@J@/@N@)","JN"," ") == "J"
    endif
  endif
return result
/** eof */

/** liefert ein String array als komma-separierten String zur�ck */
function array2readable( values, sep )
LOCAL result:="", i
  if valtype(values)=="A"
    default sep:=", "
    for i:=1 to len( values )
      result += toString(values[i])
      if i < len(values)
        result += sep
      endif
    next
  else
    result:=values
  endif
return result
/** eof */

/** liefert ein String array als komma-separierten parsable Arry-String zur�ck, inkl. Hochkommas */
function array2parsable( values )
LOCAL result:="{", i
  for i:=1 to len( values )
    result += "'"+toString(values[i])+"'"
    if i < len(values)
      result += ", "
    endif
  next
  result += "}"
return result
/** eof */

FUNCTION dispAusgabe(oGet,text)
  if empty(oGet:Buffer)
    // QQOut(space(1+len(oGet:Buffer)))
    QQout( space(len( &(text) )))
  else
    QQout( space(1) + &(text) )
  endif
RETURN(.t.)

  // // Missing on windows binary download
  // // https://groups.google.com/forum/#!topic/harbour-devel/C0now2MX9zg
  // procedure hb_default( a , b )
  // default a:=b
  // return

/* rundet Zahl auf max Stelle, also:
  * 598 -> 600
  * 64 -> 70
  * etc.
  * ACHTUNG 0 -> 0
  */
function roundMaxInt(zahl , maxStellen)
LOCAL len:=len(alltrim(str(zahl,12,0))) - 1
  if Zahl == 0
    return 0
  endif
  if maxStellen <> NIL .and. maxStellen < len
    len:=maxStellen
  endif
return round(zahl + 0.5 * 10**len , len *(-1))
/** eof */

/* rundet auf ganze Zahl auf:
  * 36 -> 36
  * 36.1 -> 37
  */
function roundUp(zahl)
  if zahl == int(zahl)
    return zahl
  endif
return int(zahl) + if(zahl<0,-1,1)
/** eof */

/** �berpr�ft ob die KW g�ltig ist, z.B. zw. 01-53 liegt */
Function kwOkay(kw)
LOCAL woche:=left(kw,2)
LOCAL jahr:=right(kw,2)
LOCAL result:=.f.

  if len(kw)>5 .or. substr(kw,3,1)<>"/"
    return .f.
  endif

  if empty(woche) .or. type(woche)<>"N" .or. empty(jahr) .or. type(jahr)<>"N"
    return .f.
  endif
  result:=! (val(woche)<=0 .or. val(woche)>getNumWeeks(val(jahr)) .or. val(jahr)<=0)
return result
/** eof */


/*
  * rechnet eine geg. Zeiten im 60-Minuten-System in Ind.Minuten um
*/
FUNCTION IndMin(x)
LOCAL std:=int(x)
LOCAL min:=(x-std)*100
RETURN(Std+(min/60))

/* 
*  rechnet eine geg. Zeit in Ind.Minuten ins 60-Minuten-System um
*/
FUNCTION ZeitMin(x)
LOCAL std:=int(x)
LOCAL min:=(x-std)*60
RETURN(Std+(min/100))

  #define SEARCH_COLOR "R+/"+getBackColor()

function searchScreen()
LOCAL s001
LOCAL search:=space(20)
LOCAL GetList:={}
LOCAL kEsc

  s001:=savescreen()
  kEsc:=SetKey( K_ESC , nil ) // back to default ESC is quit

  do while ! ABBRUCH
    @ maxrow(),0 clear
    @ maxrow(),maxCol()/2-20 say "Suche nach:" get search picture "@K"
    read
    if empty(search)
      exit
    endif
    restscreen(,,,,s001)
    ScreenMark( trim(search), SEARCH_COLOR, .f., .t.)
  enddo
  restscreen(,,,,s001)
  SetKey( K_ESC , kEsc )
return .t.

/*  fill an array with all month names abbreviated to the first x letters */
FUNCTION MonthNames( nLen )
LOCAL aArray[12], i
LOCAL aMonths:={"Januar","Februar","M�rz","April","Mai","Juni","Juli","August","September",;
  "Oktober","November","Dezember"}

  IF Valtype( nLen ) == "N"
    FOR i:=1 TO 12
      aArray[i]:=Left( aMonths[i], nLen )
    NEXT
  else
    aArray:=aMonths
  endif

RETURN aArray

/* left substring match based on length of search string */
function lmatch(haystack, needle)
return left(haystack, len(needle)) == needle

/** Pr�ft ob der Wert einer Email entsproicht */
function isValidEmail(email)
LOCAL match:=['dummy'], token
  if valtype(email) == "O" // Object
    email = email:buffer
  endif
  email = trim(email)
  if len(email) > 0
    for each token in HB_ATokens(email,';')
      token = ltrim(trim(token))
      match:=HB_RegEx("^\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$", token)
      if (match == NIL .or. len(match) == 0)
        Error("ACHTUNG: ung�ltige Email:||"+token,.t.)
        return .f.
      endif
    next
  endif
return .t.
/** eof */


/** Liefert die Menu-Nummern zur�ck um an das aktuelle Programm zu gelangen. */
function getMenuPath()
LOCAL cString:="", prog, i:=1, auswahl, result:={}, params

  do while ( !Empty(ProcName(i)) )
    prog:=upper(ProcName(i))
    if "_MENU" $ prog
      params:=hb_aParams(i)
      if len(params) > 0
        auswahl:=HB_ATokens(params[1], ".")
      endif
      aadd(result, auswahl[1])
    elseif "MAIN" == prog // special case top level call
      params:=__DBGVMLOCALLIST( i )
      aadd(result, toString(params[1])) // akt_auswahl muss 1. lokale Variable sein
    endif
    i++
  enddo

  for i:=len(result) to 1 step -1
    cString += iif(len(cString)==0,"",".") + result[i]
  next

return cString
/** eof */


/* print text to alte file, call like this:
  mylog("C:\schrott\foo\gaga.txt","Bingo")  
*/
procedure mylog(filename, text, erase)
LOCAL bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein

  default erase:=.f.

  BEGIN SEQUENCE // krit. Bereich
    dirMake(getBaseName(fileName))
    if erase
      set alte to &filename
    else
      set alte to &filename ADDITIVE
    endif
    set alte on
    qout(text)
    set alte off
    close alte
    RECOVER
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
    TroubleEmail("Cannot write logfile: "+filename)
  END Sequence
  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
return
/** eop */

/** Write the processes using a file to disk */
procedure writeHandles(fileName)
LOCAL ziel:="./DAT/MAIL/handle.out"
LOCAL ausgabe:="| Out-File -Filepath "+ziel+" -append"
  myrun('powershell','Get-Date ' + ausgabe, .f.)
  myrun('powershell','handle64.exe ' + filename + ausgabe, .f.)
return

/**************************************************************************
* Helper function: dateToISO(dDate)
* Converts a Harbour date to string in ISO 8601 format (YYYY-MM-DD).
**************************************************************************/
FUNCTION dateToISO( dDate )
LOCAL cYear:=str(year(dDate),4)
LOCAL cMonth:=substr("0"+ltrim(str(month(dDate))),-2)
LOCAL cDay:=substr("0"+ltrim(str(day(dDate))),-2)
  if dtoc(dDate) == "  .  .  "
    return NIL
  endif
RETURN cYear+"-"+cMonth+"-"+cDay

/** Close all databases and temp. indices if any */
procedure myCloseDatabases()
LOCAL i:=1, name

  //altd()
  do while ! empty(alias(i)) // solange DatenBank offen
    DbSelectArea(i)
    for each name in {TEMP_INDEX, TEMP_IND2, TEMP_IND3, TEMP_IND4}
      ordDestroy( name ) // delete tag TEMP_INDEX
    next
    i++
  enddo

  dbCloseAll()

return
/** eop */
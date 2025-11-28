/** Class for printing using harbour */


#include "mystd.ch"
#include "Fileio.ch"

#include "hbclass.ch"

#define TEMP_LISTEN_AUS (TEMP_USER+BACKSLASH+"print"+getUser():counter+::id+".asc")
#define TEMP_ENSCRIPT_IN (TEMP_USER+BACKSLASH+"enscr"+getUser():counter+::id+".asc")
#define TEMP_PS_PATH (TEMP_USER+BACKSLASH)
#define TEMP_PS_FILENAME ("post"+getUser():counter+::id+".ps")
#define TEMP_PS_FULL_FILENAME (TEMP_PS_PATH+TEMP_PS_FILENAME)

#define FONT_PREFIX ESC_CHAR_PS+"font{"

#define FASTAPI_PDF "pdf"
#define FASTAPI_PS "ps"

CLASS printJob

DATA id READONLY

// ::id:=getUniqueCounter(COUNTER_INCREASE)

DATA JobName // INIT "NoName"
DATA Landscape INIT .f.
DATA Duplex INIT .f.

DATA numCopies INIT 1 // ACHTUNG: muss VOR startDoc gesetzt werden!
DATA quiet INIT .f. // wenn .t. wird nix gedruckt -> s. print()

DATA printToFileOnly INIT .f. // by default we print on a printer
DATA informEmail INIT .f.
DATA pdfFilePath
DATA ascFullFileName
DATA pdfFullFileName
DATA generatePDF INIT .f.
DATA confirmPDF INIT .f.
DATA popup INIT .t. // shall new lists be shown in a new popup window

DATA AGBs INIT .f.
DATA background INIT NIL

DATA startCopyText INIT 2 // by default we print "Kopie" on the 2nd and addtional pages
DATA currentNumberOfCopy INIT 1 HIDDEN

DATA defaultTextWidth INIT str(HB_FONTSIZE_STANDARD,2)
DATA currentTextWidth INIT str(HB_FONTSIZE_STANDARD,2)
DATA defaultFontInitStr INIT FONT_DEFAULT

DATA currentlyBold INIT .f.
DATA fontSizeString INIT nil

DATA lastLineEmpty INIT .f. // no print, no last line

DATA confirmEnd INIT .f. // as of now: used in BSJob

METHOD new()
METHOD StartDoc( cjobName ) // Calls initQueue & getInitString
METHOD initQueue()
METHOD getInitString()
METHOD print(aText,newLine)
METHOD printBuffer(oPrintBuffer)
METHOD endDoc(lAbortDoc)
METHOD formfeed(Zeile , Seite , duplex)
METHOD toLpr()
METHOD toLprInternal(numCopy) HIDDEN
METHOD writeToPDF()
METHOD writeToPS()
METHOD getOpts() HIDDEN
METHOD getEscSeq(drNum) HIDDEN
METHOD setFontSize(size,lPar,specialChar,escOn,escOff) HIDDEN
METHOD setFontSizeString(str)
METHOD send2PrintServer(type) HIDDEN

METHOD bold(lPar)
METHOD large(lPar)
METHOD small(lPar)
METHOD little(lPar)
METHOD tiny(lPar)

METHOD color(r,g,b)
METHOD colorGreen()
METHOD colorRed()
METHOD colorRedLight()
METHOD colorGrey()
METHOD colorDefault()

METHOD setBackground(cForm)

METHOD setJobName(jobName)

METHOD getFixedHeaderLines()

  // METHOD UnderLine(l)
  // METHOD Italic(l)
  // METHOD barcode(l)


ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
  ::id:=getUniqueCounter(COUNTER_INCREASE)
  ::ascFullFileName:=TEMP_LISTEN_AUS
  ::pdfFilePath:=getUser():exportPATH()
RETURN self

/*----------------------------------------------------------------------*/

METHOD StartDoc( cjobName )
  if cjobName<>NIL
    ::setJobName(cjobName)
  endif
  ::initQueue()

  // Removed output of default font size at beginning of list (as of 20111022)
  // we now use the font= defaultFontInitStr option
  // qqout(::getInitString())
  ::defaultFontInitStr:=::getInitString()

RETURN nil

/*----------------------------------------------------------------------*/

METHOD getInitString()
LOCAL result:="",tempResult
  //LOCAL result:=::defaultFontInitStr, tempResult

  // set pre-defined list font size
  do case
  case LISTE->Art=="S"
    ::defaultTextWidth:=alltrim(str(HB_FONTSIZE_SCHMAL,2))
    tempResult:=::small(.t.)
    if valtype(tempResult)=="C"
      result+= tempResult
    else
      // we ignore PrintSonderZeichen and others, hope this is correct
    endif

  case LISTE->Art=="K"
    ::defaultTextWidth:=alltrim(str(HB_FONTSIZE_KLEIN,2))
    tempResult:=::little(.t.)
    if valtype(tempResult)=="C"
      result+= tempResult
    else
      // we ignore PrintSonderZeichen and others, hope this is correct
    endif

  case LISTE->Art=="W"
    ::defaultTextWidth:=alltrim(str(HB_FONTSIZE_WINZIG,2))
    tempResult:=::tiny(.t.)
    if valtype(tempResult)=="C"
      result+= tempResult
    else
      // we ignore PrintSonderZeichen and others, hope this is correct
    endif

  otherwise
    ::defaultTextWidth:=alltrim(str(HB_FONTSIZE_STANDARD,2))
    result+= ::setFontSize(alltrim(str(HB_FONTSIZE_STANDARD,2)))
  endcase
  ::currentTextWidth:=::defaultTextWidth

return result

/*----------------------------------------------------------------------*/

METHOD initQueue()
  set alte to (::ascFullFileName)
  set alte on
  set cons off
  // File wird am Ende mit lpr gedruckt
return nil

/*----------------------------------------------------------------------*/

METHOD setJobName(jobName)
  ::JobName:=trim(no_blanks(jobName))
return nil

/*----------------------------------------------------------------------*/

METHOD print(aText,newLine)
LOCAL i,tempStr

  // bail out if quiet is on
  if ::quiet
    return NIL
  endif

  default newLine:=.t.

  if newline
    QOut()
    ::lastLineEmpty:=.t.
  endif

  if aText==NIL
    // newline only?
    return NIL
  endif

  for i:=1 to len(aText)
    do case
      // nop
    case aText[i] == NIL

    case valtype(aText[i]) == "O" .and. aText[i]:className()=="PRINTSONDERZEICHEN"
      tempStr:=aText[i]:getPrintChars( self )
      if tempstr <> NIL .and. ! empty( TempStr )
        qqout( tempStr )
        ::lastLineEmpty:=.f.
      endif

      // nop
    case valtype(aText[i]) == "C"
      // checken ob doch numerisch
      if (type(aText[i])=="N" .and. val(aText[i]) < 0) .or. ;
        (","$aText[i] .and. type(tempstr:=untransStr(aText[i]))=="N" .and. val(tempStr) < 0)
        // Anmerkung: wir suchen hier nach , obwohl wir . ersetzen
        // da . so oft in echten Texten vorkommt z.B. Art.Nr
        qqout(::colorRed())
        qqout(aText[i])
        qqout(::colorDefault())
        ::lastLineEmpty:=.f.
      else
        QQOut(aText[i])
        ::lastLineEmpty:=.f.
      endif
    case valtype(aText[i]) == "N"
      // neg. Zahlen in rot
      if aText[i] < 0
        qqout(::colorRed())
        qqout(aText[i])
        qqout(::colorDefault())
        ::lastLineEmpty:=.f.
      else
        QQOut(aText[i])
        ::lastLineEmpty:=.f.
      endif
    case valtype(aText[i]) == "D"
      QQOut(aText[i])
      ::lastLineEmpty:=.f.
    otherwise
      QQOut(aText[i])
      Error(ACHTUNG+" valtype nicht definiert:"+valtype(aText[i]),.t.)
    endcase

    // kein space mehr nach Sonderzeichen druck
    // temp. L�sung so lange wir Clipper kompatibel sind
    // Hinweis: die 1. beiden Zeilen sind "alt"
    if valtype(aText[i])=="C" .and. (ESC_CHAR_PS $ aText[i] .or. ESC_CHAR_ASCI $ aText[i];
      .or. aText[i]==chr(val(DRUCKER->FormFeed))) ;
      .or. valtype(aText[i]) == "O" .and. aText[i]:className()=="PRINTSONDERZEICHEN"
      // Sonderzeichen etc. -> no space
    else
      QQOut(' ')
    endif

  next i

return self

/*----------------------------------------------------------------------*/

METHOD printBuffer(oPrintBuffer)
LOCAL allLines,line

  if valtype(oPrintBuffer) == "O" .and. oPrintBuffer:className()=="PRINTBUFFER"
    allLines:=oPrintBuffer:getText()
    for each line in allLines
      ::print(line,.t.)
    next
  endif

return oPrintBuffer:getNumLines()

/*----------------------------------------------------------------------*/

METHOD endDoc(lAbortDoc)
LOCAL aDir
  default lAbortDoc:=.f.

  set alte off
  close alte
  set cons on

  #define MIN_SIZE 2 // min. Gr��e damit Liste angezeigt wird
  #define SONDER_SIZE 50 // falls kleiner wird auf nur Sonderzeichen getestet

  if ! lAbortDoc

    // check whether file exists
    aDir:=directory(::ascFullFileName)
    if len(aDir) > 0
      if aDir[1,2] > MIN_SIZE .and.;
        !(aDir[1,2] < SONDER_SIZE .and. aDir[1,2] == len(::getInitString())+1)
        // pr�fe ob evtl. nur Sonderzeichen an, ansonsten nix => leere Seite
        // Liste schmal etc. + CTRL-Z

        // Hole Pfad & Name falls noch nicht gesetzt
        if valtype(::JobName)=="U"
          // JobName:="NoName"+getUser():getLongID()
          ::JobName:=meinLiName()
        endif

        // erst drucken scheint schneller
        if .NOT. ::printToFileOnly
          ::toLpr()
        endif
        if ::generatePDF
          ::writeToPDF()
        endif
      endif
    endif
  endif

  // delete temp files
  if getProperty("System.cleanup","J")<>"N"
    ferase(TEMP_LISTEN_AUS)
    ferase(TEMP_PS_FILENAME)
    ferase(TEMP_PS_FULL_FILENAME)
    ferase(TEMP_ENSCRIPT_IN)
  endif

RETURN NIL


/*----------------------------------------------------------------------*/

METHOD formfeed(Zeile , Seite , duplex)
LOCAL laenge:=DRUCKER->laenge

  static abortRequested
  default zeile:=0

  if duplex <> NIL
    ::duplex:=duplex
  endif

  if ! empty(DRUCKER->FormFeed)
    ::print( {chr(val(DRUCKER->FormFeed))} ,.f.)
  else
    do while Zeile<laenge
      ::print(,.t.)
      zeile++
    enddo
  endif
  // endif

  if valtype(Seite)<>"U"
    if Seite < 5
      abortRequested:=.f.
    endif

    @ MaxRow(),0 say "Seite: "+alltrim(str(Seite))
    if (Seite==MAX_NOF_PAGES .or. (Seite == MAX_NOF_PAGES + 2 .and. abortRequested)) .and.;
      upper(getUser():getCurrentPrintJob():className()) <> "DUMMYJOB" // quiet, since this is intented behaviour
      if getUser():id==SERVER_LOGIN
        abortRequested:=.t.
        keyboard chr(K_ESC)
      else
        if abortRequested // K_ESC hat nicht funktioniert
          Trouble("root",{"Dokument mit �ber "+alltrim(str(MAX_NOF_PAGES))+" Seiten. System / "+;
            "Benutzer Abbruch"})
          // FIXME: maybe there is a smarter way to get out of a potential loop?
          down()
        else
          if Message("Dokument hat �ber "+alltrim(str(MAX_NOF_PAGES))+" Seiten.  "+;
            "Wollen Sie abbrechen? (@J@/@N@)","JN","N")=="J"
            abortRequested:=.t.
            keyboard chr(K_ESC) // try Escape 1st
          endif
        endif
      endif
    endif

  endif

RETURN 0

/*----------------------------------------------------------------------*/


METHOD bold(lPar)

  if lPar // bold on
    ::currentlyBold:=.t.
  else
    ::currentlyBold:=.f.
  endif

RETURN ::setFontSize(::currentTextWidth,lPar,,DRUCKER->Fett_an,DRUCKER->Fett_aus)

/*----------------------------------------------------------------------*/

METHOD large(lPar)
RETURN ::setFontSize(alltrim(str(HB_FONTSIZE_BREIT,2)),lPar
  ,"-BoldOblique",DRUCKER->Breit_an,DRUCKER->Breit_aus)

/*----------------------------------------------------------------------*/

METHOD small(lPar)
RETURN ::setFontSize(alltrim(str(HB_FONTSIZE_SCHMAL,2)),lPar
  ,,DRUCKER->Schmal_an,DRUCKER->Schmal_aus)

/*----------------------------------------------------------------------*/

METHOD little(lPar)
RETURN ::setFontSize(alltrim(str(HB_FONTSIZE_KLEIN,2)),lPar
  ,,DRUCKER->Klein_an,DRUCKER->Klein_aus)

/*----------------------------------------------------------------------*/

METHOD tiny(lPar)
RETURN ::setFontSize(alltrim(str(HB_FONTSIZE_WINZIG,2)),lPar
  ,,DRUCKER->Winzig_an,DRUCKER->Winzig_aus)

/*----------------------------------------------------------------------*/

METHOD color(r,g,b)
RETURN ESC_CHAR_PS+"color{"+str(r)+" "+str(g)+" "+str(b)+"}"

/*----------------------------------------------------------------------*/

METHOD colorGreen()
RETURN ESC_CHAR_PS+"color{0 1 0}"
/*----------------------------------------------------------------------*/
METHOD colorRed()
RETURN ESC_CHAR_PS+"color{1 0 0}"
/*----------------------------------------------------------------------*/
METHOD colorRedLight()
RETURN ESC_CHAR_PS+"color{0.5 0 0}"
/*----------------------------------------------------------------------*/
METHOD colorDefault()
RETURN ESC_CHAR_PS+"color{0 0 0}"
/*----------------------------------------------------------------------*/
METHOD colorGrey()
RETURN ESC_CHAR_PS+"color{0.5 0.5 0.5}"


/*----------------------------------------------------------------------*/

METHOD setFontSizeString(str)
  ::fontSizeString:=str
return ::fontSizeString

/*----------------------------------------------------------------------*/


// Note: special char (e.g. -BoldOblique when large) can not yet be combined with bold
METHOD setFontSize(size,lPar,specialChar,escOn,escOff)

  default lPar:=.t.

  if lPar // on
    if valtype(size)=="N"
      ::currentTextWidth:=str(size,2)
      trouble("root",{"Size should be char not numeric."})
    else
      ::currentTextWidth:=size
    endif
    if DRUCKER->Postscript=="J"
      if specialChar==NIL
        ::FontSizeString:=FONT_PREFIX+FONT+if(::currentlyBold,"-Bold","")+;
          ::currentTextWidth+"/"+FONT_HEIGHT+"}"
      else // FIXME: we miss bold here, maybe too generic
        ::FontSizeString:=FONT_PREFIX+FONT+specialChar+::currentTextWidth+"/"+FONT_HEIGHT+"}"
      endif
    else
      ::fontSizeString:=::getEscSeq(escOn)
    endif
  else // off
    ::currentTextWidth:=::defaultTextWidth
    if DRUCKER->Postscript=="J"
      ::FontSizeString:=FONT_PREFIX+FONT+if(::currentlyBold,"-Bold","")+::defaultTextWidth+"/"+;
        FONT_HEIGHT+"}"
    else
      ::fontSizeString:=::getEscSeq(escOff)
    endif
  endif

  // qqout(::FontSizeString)
RETURN ::FontSizeString

/*----------------------------------------------------------------------*/

METHOD getEscSeq(drNum)
LOCAL DrStr:="",i:=1
  if drNum<>NIL
    Do While (I+2) <= Len(trim(DrNum))
      DrStr = DrStr + Chr( Int( Val( SubStr(DrNum,I,3) )))
      i = i + 3
    ENDDO
  endif
RETURN DrStr

/*----------------------------------------------------------------------*/

METHOD toLpr()
LOCAL i,memAGB:=::AGBs
LOCAL numOrgPages:=::numCopies

  set alte off
  close alte
  set cons on

  // print 1st original
  if ::startCopyText>0
    numOrgPages:=min(::numCopies,::startCopyText-1)
  endif
  for i:=1 to numOrgPages // FIXME: rather send number of copies to print server
    ::currentNumberOfCopy:=i
    ::toLprInternal()
  next

  // print additional copies
  if ::numCopies >= 1
    ::AGBs:=.f. // Kopie ohne AGBs
    for i:=(numOrgPages+1) to ::numCopies
      ::currentNumberOfCopy:=i
      @ MaxRow(),0 say "Kopie: "+alltrim(str(::currentNumberOfCopy,3))+space(4)
      ::toLprInternal()
    next
    ::AGBs:=memAGB
  endif

  ::currentNumberOfCopy:=1

RETURN nil

/*----------------------------------------------------------------------*/

METHOD toLprInternal()
LOCAL PrintServer:=trim(DRUCKER->PrintSrv)
LOCAL PrinterQueue, nPrn:=0, cMess
LOCAL s01,tempJobName:=::jobName
LOCAL queueName:=trim(DRUCKER->Queue)
LOCAL count:=1 // we try multiple times
LOCAL RETRIES:=3

  if AT_HOME
    PrintServer:=getProperty("System.printer.server",trim(DRUCKER->PrintSrv))
    queueName:=getProperty("System.printer.queue",trim(DRUCKER->Queue))
  endif

  if empty(PrintServer)
    PrinterQueue:=queueName
  else
    PrinterQueue:=BACKSLASH + BACKSLASH + PrintServer + BACKSLASH + queueName
  endif
  cMess:="PrintFileRaw(): "+PrinterQueue+"  PrinterStatus:"+alltrim(str(WIN_PRINTERSTATUS()))+"|"

  if ::startCopyText>0 .and. ::currentNumberOfCopy >= ::startCopyText
    tempJobName:=tempJobName+"-Kopie"
  endif

  if DEVEL_PROG .and. DEBUG .and. ::currentNumberOfCopy == 1
    s01:=savescreen()
  endif

  // try twice
  do while count <= RETRIES

    trouble(;
      "printer",{PrinterQueue+" "+TEMP_PS_FULL_FILENAME+" "+tempJobName,;
      "PrinterStatus:"+alltrim(str(WIN_PRINTERSTATUS())),;
      "File:"+toString(file(TEMP_PS_FULL_FILENAME));
      })


    // convert to postscript if applicable
    if DRUCKER->Postscript=="J"

      // if we test our fast api service we bail out since we spool the ps file directly
      if getProperty("System.printer.service.spool","N")=="J"
        nPrn:=::writeToPs(.t.)
        exit
      endif

      // wandle ASCI -> Postscript nur beim 1. Mal & bei 1. Kopie
      if ::currentNumberOfCopy==1 .or. ::currentNumberOfCopy == ::startCopyText
        nPrn:=::writeToPS()
        waitForFile(TEMP_PS_FULL_FILENAME)
      endif

      if count < RETRIES
        // we print directly to the windows printer queue
        nPrn:=WIN_PRINTFILERAW( PrinterQueue, TEMP_PS_FULL_FILENAME, tempJobName )
        if DEBUG .and. ::currentNumberOfCopy == 1
          qout("Printed:",PrinterQueue, TEMP_PS_FULL_FILENAME, tempJobName )
        endif

      else
        // last fallback we print via fastapi (no duplex only)
        email(MY_EMAIL,"Print failed => print file attached.","Bitte pr�fen",TEMP_PS_FULL_FILENAME;
          , .f., .t.)
        nPrn:=::writeToPs(.t.)
      endif

    else
      // Etikett
      nPrn:=WIN_PRINTFILERAW( PrinterQueue, ::ascFullFileName, tempJobName )
      if DEBUG .and. ::currentNumberOfCopy == 1
        qout("Printed:",PrinterQueue, ::ascFullFileName, tempJobName )
      endif
    endif

    if nPrn >= 0
      trouble(;
        "printer",{"Failed:",;
        "PrinterStatus:"+alltrim(str(WIN_PRINTERSTATUS())),;
        "File:"+toString(file(TEMP_PS_FULL_FILENAME));
        })
      exit
    endif
    trouble(;
      "printer",{"Success:",;
      "PrinterStatus:"+alltrim(str(WIN_PRINTERSTATUS())),;
      "File:"+toString(file(TEMP_PS_FULL_FILENAME));
      })

    count++
    if count < RETRIES
      createTempPaths()
      Error(ACHTUNG+cMess+"WINAPI PrinterError: "+str(nPrn)+"||We try again...",.t.,"root")
      hb_idleSleep( count * 5 )
    else
      Error(ACHTUNG+cMess+"WINAPI PrinterError: "+str(nPrn)+;
        "||Now try: PrintRawViaPowerShell()",.t.,"root")
    endif
    trouble("printer", "dos:"+str(DosError())+" os:"+str(Hb_osError()))
  enddo

  DO CASE
  CASE nPrn >= 0
    // NOP everything ok.
  CASE nPrn = -1
    Error(ACHTUNG+cMess+"Incorrect parameters passed to function",.t.,"root")
  CASE nPrn = -2
    Error(ACHTUNG+cMess+"WINAPI ERROR_FILE_NOT_FOUND call failed",.t.,"root")
  CASE nPrn = -3
    Error(ACHTUNG+cMess+"WINAPI ERROR_PATH_NOT_FOUND call failed",.t.,"root")
  CASE nPrn = -4
    Error(ACHTUNG+cMess+"WINAPI StartPagePrinter() call failed",.t.,"root")
  CASE nPrn = -5
    Error(ACHTUNG+cMess+"WINAPI malloc() of memory failed",.t.,"root")
  CASE nPrn = -6
    Error(ACHTUNG+cMess+"WINAPI CreateFile() failed - ||File "+::ascFullFileName+" or "+;
      TEMP_PS_FULL_FILENAME+" not found??",.t.,"root")
  OTHERWISE
    Error(ACHTUNG+::ascFullFileName+" PRINTED OK!!!?  Fehler:"+str(nPrn),.t.,"root")
  ENDCASE

  if DEBUG .and. ::currentNumberOfCopy == 1
    Message("Bitte @Taste@ dr�cken","@")
    restscreen(,,,,s01)
  endif

RETURN nil

/*----------------------------------------------------------------------*/

Method writeToPDF()
LOCAL s01,ant,pdfCreated:=-1,tempName
LOCAL nStart:=Seconds()

  if ! mkmydir(::pdfFilePath)
    ::pdfFilePath:=getUser():exportFallbackPath
    if ! mkmydir(::pdfFilePath)
      // we're lost now
      return .f.
    endif
  endif

  ::pdfFullFileName:=::pdfFilePath+BACKSLASH+no_blanks(::jobName, .t.)+".pdf"

  if PDF_SERVICE==PDF_PRINT_FASTAPI
    pdfCreated:=::send2PrintServer(FASTAPI_PDF)
  else
    TroubleEmail("Unbekannter Print Server in miki.cfg: "+str(PDF_SERVICE))
  endif

  // confirm file creation
  // if (::confirmPDF .or. DEVEL_PROG) .and. pdfCreated == 0 .and. getUser():id <> REMOTE_SERVICE_LOGIN
  if (::confirmPDF) .and. pdfCreated == 0 .and. getUser():id <> REMOTE_SERVICE_LOGIN
    s01:=savescreen()
    if len(::pdfFullFileName)>maxcol()-29
      tempName:=".."+right(::pdfFullFileName,maxcol()-32)
    else
      tempName:=::pdfFullFileName
    endif
    if (ant:=Message(tempName+" anzeigen? (@J@/@N@/@O@rdner)","JNO","N"))$"OJ"
      waitForFile(::pdfFullFileName)
      // FIXME: use myrun here
      if ant=="J"
        wapi_SHELLEXECUTE( 0, 0, ::pdfFullFileName, , 0, 0 ) // startet neuen Prozess ohne Show!
      else
        wapi_SHELLEXECUTE( 0, "open", ::pdfFilePath) // �ffnet Ordner
      endif
      // wait
      restscreen(,,,,s01)
    endif
  endif

  if DEBUG
    qout("Dauer in Sekunden:" + str(Seconds() - nStart,8,0))
    wait
  endif

RETURN .t.

/*----------------------------------------------------------------------*/

/* Erzeugt eine Postscript Datei und je nach Methode sendet diese direkt an den Drucker.
  *  Returns error_code: 0 if all ok
  */
Method writeToPS(printit)
LOCAL queue:=""
LOCAL result:=0
LOCAL nPos

  default printit:=.f.

  if PDF_SERVICE==PDF_PRINT_FASTAPI
    if printit
      nPos:=RAT(BACKSLASH, trim(DRUCKER->Queue)) // Find last occurrence of "\"
      queue:=ToPascalCase(SUBSTR(trim(DRUCKER->Queue), nPos + 1)) // Extract substring after last "\"
    endif
    result:=::send2PrintServer(FASTAPI_PS, queue)

  else
    TroubleEmail("Unbekannter Print Server in miki.cfg: "+str(PDF_SERVICE))
  endif

RETURN result

/*----------------------------------------------------------------------*/

  // Folgende Optionen kennt der iCADA PDF/PS Web Service
  // kopie=0
  // agb=0
  // landscape=0
  // duplex=0
  // form=form form=form-en form=formbuch form=brief form=liste (nur Miki Logo) form=liste-duplex mit Pfeil
  // watermark=test watermark=devel

METHOD getOpts()
LOCAL result:="?",tempStr, menu, trimMenu

  if ::startCopyText>0 .and. ::currentNumberOfCopy >= ::startCopyText
    result+="kopie=1&"
  endif
  if ::AGBs
    // AGBs werden je nach selektierten Land gedruckt
    switch LAND->Sprache
    case ENGLISCH
      result+="agb=en&"
      exit
    case FRANZOESISCH
      result+="agb=fr&"
      exit
    otherwise
      result+="agb=de&"
    endswitch
  endif

  do case
  case ::background==NIL // Liste

    if ::duplex
      result+="form=liste-duplex&"
    else
      result+="form=liste&"
    endif
    tempStr:=::defaultFontInitStr
    // remove leading "@font{"
    if left(tempStr,len(FONT_PREFIX))==FONT_PREFIX
      tempstr:=substr(tempStr,len(FONT_PREFIX)+1)
      // remove trailing }
      tempstr:=substr(tempStr,1,len(tempStr)-1)
    endif
    result+="font="+tempStr+"&"
  otherwise
    result+="form="+trim(getFileBaseName(::background))+"&"
    // unknown background
    // TroubleEmail("Druck-Background:"+::background+" unbekannt!"+SCHWERER_FEHLER)
  endcase

  if ::landscape
    result+="landscape=1&"
  endif

  // if ::duplex // .or. ::AGBs
  // result+="duplex=1&"
  // endif

  if TEST_PROG .and. ! DEVEL_PROG .and. ! file ("NO_TEST.txt")
    result+="watermark=test&"
  else
    if DEVEL_PROG
      result+="watermark=devel&"
    endif
  endif

  // Men� Nummern bei Listen drucken, nicht bei Formularen
  if getProperty("System.printer.menu_info","N") == "J" .and. ::background==NIL
    menu:=getMenuPath()
    if len(menu) > 0
      trimMenu:=no_blanks(menu,.t.)
      if trimMenu <> "-1"
        result+="header=Menu:"+trimMenu+"&"
      endif
    endif
  endif

  // setze Escape Zeichen
  result+="esc="+ESC_CHAR_PS

RETURN result

/** eoc - end of class */

/*----------------------------------------------------------------------*/

METHOD setBackground(cForm)
  ::background:=cForm
return self

/*----------------------------------------------------------------------*/

METHOD getFixedHeaderLines()
return {} // as of now always empty

/*----------------------------------------------------------------------*/

/**************************************************************************
* Methode: send2PrintServer()
*
* Send the ASC file with special � commands to the new FastAPI endpoint
* and retrieve a PDF/A-3 invoice. Save it locally as ::pdfFullFileName.
*
* Steps:
*  1. Ensure the ASC file exists (the file with � commands).
*  2. Use curl to POST the file as multipart/form-data to "/pdf?form=..."
*  3. Save the returned PDF to a local path.
*  4. Capture HTTP status code (via -w "%{http_code}") and handle errors.
*
*  Returns error_code: 0 if all ok
**************************************************************************/
METHOD send2PrintServer(type, queue, num_copies)
LOCAL TempPath:=TEMP+BACKSLASH+left(getUser():getLongId(),2)+BACKSLASH
LOCAL cTempFileIn:=TempPath+"PDFIN-"+getUser():getTempCounter()+".txt"
LOCAL cTempFileOut:=TempPath+"PDFOUT-"+getUser():getTempCounter()+".txt"
LOCAL cCommand, outFile
LOCAL cStatusCode, cErrorText
LOCAL host:=getProperty("System.zugferd.server","")
LOCAL jError, text, textUTF8, nHandle
LOCAL opts:=::getOpts(), nRetCode:=0, jobName

  default queue:=""
  default num_copies:=1

  // 1) Check if the ASC file exists
  IF ! File(::ascFullFileName)
    Error("ASC file not found: " + ::ascFullFileName)
    RETURN 1
  ENDIF

  // Convert to UTF-8
  text:=MemoRead( ::ascFullFileName )
  textUTF8:=hb_StrToUTF8(text)
  // Write UTF-8 data manually
  nHandle:=FCreate(cTempFileIn, FC_NORMAL)
  IF nHandle != -1
    FWrite(nHandle, textUTF8) // write raw UTF-8 bytes
    FClose(nHandle)
  ELSE
    qout("Error writing JSON file: " + cTempFileIn)
  ENDIF

  if type == FASTAPI_PDF
    outFile:=::pdfFullFileName
  else // PS
    outFile:=TEMP_PS_FULL_FILENAME // FIXME: once remote printing is working we do not need to return ps file
  endif

  // F�ge printer queue dazu f�r den direkten postscript Druck
  if len(queue) > 0
    opts += Chr(38) + "queue=" + queue
  endif

  if num_copies > 1
    opts += Chr(38) + "copies=" + alltrim(str(num_copies))
  endif

  // if DEBUG // FIXME: as of now always
  opts += Chr(38) + "debug=1"
  // endif

  // Move to getOpts once iCADA server is removed
  opts += Chr(38) + "user=" + getUser():id
  JobName:=::jobName
  if ::startCopyText>0 .and. ::currentNumberOfCopy >= ::startCopyText
    JobName:=JobName+"-Kopie"
  endif
  opts += Chr(38) + "jobname=" + jobName

  // 2) Build the curl command
  // We pass the form field "file" => @my_invoice.asc;type=text/plain
  // Also append "?form=brief-de" or any other form param.
  // -o saves the response body to cOutputPdf
  // -s (silent) + -w "%{http_code}" writes the code to cTempFile
  // You can set the form name to anything, but must match the Python `UploadFile(..., name="file")`
  cCommand:='cmd /c curl -X PUT ' +;
    '-F "file=@' + cTempFileIn + ';type=text/plain" ' +;
    '"http://' + host + '/v1/'+type+URLEncode(opts)+'" ' +;
    '-o "' + outfile + '" ' +;
    '-s -w "%{http_code}" > "' + cTempFileOut + '"'

  // run(cCommand)
  nRetCode:=RUNHIDDEN( cCommand, DEBUG ) // FIXME: move mytools#myrun() once tested

  if (DEVEL_PROG .or. TEST_PROG) .and. DEBUG
    QOut( cCommand )
    wait
    //altd()
  else
    ferase(cTempFileIn)
  endif

  if nRetCode <> 0 .or. nRetCode == NIL
    do case
    case nRetCode==6 .or. nRetCode == NIL
      Error("DNS Eintrag "+host+" nicht gefunden.")
    case nRetCode==7 .or. nRetCode == NIL
      Error("Print Server "+host+" nicht erreichbar.")
    otherwise
      Error("Print Server Fehler: " + alltrim(str(nRetCode)))
    endcase
    RETURN nRetCode
  ENDIF

  // 3) Read status code
  IF FILE(cTempFileOut)
    cStatusCode:=AllTrim( MemoRead( cTempFileOut ) )
    ferase(cTempFileOut)
  ELSE
    Error("Could not retrieve status code. Temp file not found:||" + cTempFileOut)
    RETURN 2
  ENDIF

  // 4) If not HTTP 200, handle error
  IF cStatusCode <> "200"
    // Possibly the server returned JSON with an error message.
    // We tried saving to cOutputPdf, so let's see if there's text inside:
    IF FILE(outfile)
      cErrorText:=MemoRead(outfile)
      hb_jsonDecode( cErrorText, @jError)
      if jError <> NIL
        cErrorText:=jError["detail"]
      endif
      Error("PDF Server Error:||"+;
        array2readable(linewrap(strtran(cErrorText,MY_LF,"|"),60), "|"), .t. ,"root")
      //ferase(outfile)
    ELSE
      Error("PDF creation failed: No response file found (HTTP " + cStatusCode + ").", .T., "root")
    ENDIF
  ENDIF

RETURN 0 // Bingo

/** eoc */


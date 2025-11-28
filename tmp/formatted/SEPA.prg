/**
 * Class for EU SEPA Export
 *
 * see "Anlage 3-Spezifikation der Datenformate - Version 2.5 Endfassung vom 10.06.2010.pdf"
 *
 * Sample file for generating a SEPA XML file for Credit Transfer Initiation.
 * Note: Direct Debit Initiation is not supported.
 *
 * Commerzbank techn. Hotline: 069 136 26 360 (oder Durchwahl: 069 136 26 003)
 * Auftragsart: CCT
 *
 * see: hbmxml\tests\custom.prg
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

#include "mystd.ch"
#include "error.ch"
#include "hbmxml.ch"
#include "hbclass.ch"

// Info: we set real number as text, as we don't now how te set the number of digits :(

// A-Z,a-z,0-9 and the below characters are allowed (see Function checkSepaCharacters())
#define ALLOWED_SPECIAL_CHARACTERS "':?,- (+.)/"

// the file extension for the checksum
#define CHECKSUM_EXT ".chk"

// relative path name to store checksum files
#define CHECKSUM_PATH "checksum"

// relative path where "deleted" files are moved
#define DELETED_PATH "old"

#define SEPA_DATE_FORMAT "yyyy-mm-dd"

// prefix for MessageId
#define MESSAGE_ID_PREFIX "Message-ID-"

// some special key node names
#define CREDIT_TRANSFER_NODE_NAME "CdtTrfTxInf"

CLASS SEPA

DATA tree READONLY // top level tree node
DATA pmtInf READONLY // Payment Information, here we add the CTs

DATA originator READONLY
DATA messageID READONLY

DATA numTransactionsNode1 HIDDEN // number of transaction (tree node!)
DATA numTransactionsNode2 HIDDEN // number of transaction (tree node!)
DATA numTransactions HIDDEN // number of transaction
DATA controlSumNode1 HIDDEN // control sum (tree node!)
DATA controlSumNode2 HIDDEN // control sum (tree node!)
DATA controlSum HIDDEN INIT 0.00 // control sum
DATA executionDate HIDDEN // stored as text e.g. 2012-07-19
DATA fileName HIDDEN

// creates a new SEPA transfer from scratch
METHOD new(id,originator,iban,bic)

  // creates a SEPA transfer from a XML File
// can be used for validation & listing of contents
METHOD read(xmlFileName)

METHOD dumpCheckSumFile() HIDDEN
METHOD readCheckSumFile()
METHOD getCheckSumFileName() HIDDEN

METHOD addCreditTransfer(CT)
METHOD getCreditTransfers()
METHOD getControlSum()
METHOD getNumTransactions()
METHOD dump(fileName)
METHOD ferase()
METHOD getExecutionDate()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(id,originator,iban,bic,execDate)
LOCAL doc,date
LOCAL group,node,CstmrCdtTrfInitn
LOCAL dateFormat:=Set( _SET_DATEFORMAT )

  SET DATE FORMAT TO SEPA_DATE_FORMAT
  ::originator:=trim(checkSepaCharacters(originator))
  ::messageID:=trim(checkSepaCharacters(id))

  if execDate==nil
    execDate:=date()
  endif

  // set XML defaults
  mxmlSetCustomHandlers( @load_c(), @save_c() )

  ::tree:=mxmlNewXML()
  doc:=mxmlNewElement( ::tree, "Document" )
  // pre 9.5.2016
  // mxmlElementSetAttr( doc, "xmlns","urn:iso:std:iso:20022:tech:xsd:pain.001.002.03")
  // mxmlElementSetAttr( doc, "xmlns:xsi","http://www.w3.org/2001/XMLSchema-instance")
  // mxmlElementSetAttr( doc, "xsi:schemaLocation","urn:iso:std:iso:20022:tech:xsd:pain.001.002.03"+
  // " pain.001.002.03.xsd")

  // ab 9.5.2016
  mxmlElementSetAttr( doc, "xmlns","urn:iso:std:iso:20022:tech:xsd:pain.001.003.03")
  mxmlElementSetAttr( doc, "xmlns:xsi","http://www.w3.org/2001/XMLSchema-instance")
  mxmlElementSetAttr( doc, "xsi:schemaLocation","urn:iso:std:iso:20022:tech:xsd:pain.001.003.03"+;
    " pain.001.003.03.xsd")

  // Customer Credit Transfer Initiation
  CstmrCdtTrfInitn:=mxmlNewElement( doc, "CstmrCdtTrfInitn" )

  // Group Header ------------------------------------------------------------
  group:=mxmlNewElement( CstmrCdtTrfInitn ,"GrpHdr" )

  // MessageIdentification
  node:=mxmlNewElement( group, "MsgId" )
  mxmlNewText( node, 0, MESSAGE_ID_PREFIX+checkSepaCharacters(id))

  // CreationDateTime
  node:=mxmlNewElement( group, "CreDtTm" )
  date:=strtran(TtoC(DateTime())," ","T") // using 24hours, is ok based on fedback from Commerzbank
  mxmlNewText( node, 0, date)

  // // NumberOfTransactions -> value will be set later
  node:=mxmlNewElement( group, "NbOfTxs" )
  ::numTransactionsNode1:=mxmlNewInteger( node, 0)

  // // ControlSum -> value will be set later
  node:=mxmlNewElement( group, "CtrlSum" )
  ::controlSumNode1:=mxmlNewText(node,0,"0.00")

  // InitiatingParty
  node:=mxmlNewElement( group, "InitgPty" )
  node:=mxmlNewElement( node, "Nm" )
  mxmlNewText( node, 0,::originator)

  // end of Group Header---------------------------------------------------------

  // PaymentInformationIdentification (Header for all transactions) -------------
  ::pmtinf:=mxmlNewElement( CstmrCdtTrfInitn, "PmtInf" )

  // PaymentInformationIdentification
  node:=mxmlNewElement( ::pmtinf, "PmtInfId" )
  mxmlNewText( node, 0, "Payment-ID-"+checkSepaCharacters(id))

  // PaymentMethod always TRF
  node:=mxmlNewElement( ::pmtinf, "PmtMtd" )
  mxmlNewText( node, 0, "TRF")

  // BatchBooking
  node:=mxmlNewElement( ::pmtinf, "BtchBookg" )
  mxmlNewText( node, 0, "false")

  // NumberOfTransactions --> will be set later
  node:=mxmlNewElement( ::pmtinf, "NbOfTxs" )
  ::numTransactionsNode2:=mxmlNewInteger( node, 0)

  // ControlSum --> will be set later
  node:=mxmlNewElement( ::pmtinf, "CtrlSum" )
  ::controlSumNode2:=mxmlNewText(node,0,"0.00")

  // PaymentTypeInformation
  node:=mxmlNewElement( ::pmtinf, "PmtTpInf" )

  // ServiceLevel
  node:=mxmlNewElement( node , "SvcLvl" )

  // Code always SEPA
  node:=mxmlNewElement( node, "Cd" )
  mxmlNewText( node, 0, "SEPA")

  // RequestedExecutionDate
  node:=mxmlNewElement( ::pmtinf, "ReqdExctnDt" )
  mxmlNewText( node, 0, dtoc(execDate))
  ::executionDate:=dtoc(execDate)

  // Debtor
  node:=mxmlNewElement( ::pmtinf, "Dbtr" )
  node:=mxmlNewElement( node, "Nm" )
  mxmlNewText( node, 0, ::originator)

  // DebtorAccount
  node:=mxmlNewElement( ::pmtinf, "DbtrAcct" )
  node:=mxmlNewElement( node, "Id" )
  node:=mxmlNewElement( node, "IBAN" )
  mxmlNewText( node, 0, trim(iban))

  // DebtorAgent
  node:=mxmlNewElement( ::pmtinf, "DbtrAgt" )
  node:=mxmlNewElement( node, "FinInstnId" )
  node:=mxmlNewElement( node, "BIC" )
  mxmlNewText( node, 0, trim(checkSepaCharacters(bic)))

  // ChargeBearer immer SLEV
  node:=mxmlNewElement( ::pmtinf, "ChrgBr" )
  mxmlNewText( node, 0, "SLEV")

  // end of PaymentInformationIdentification (Header for all transactions) -----------


  // reset date type
  SET DATE FORMAT TO (dateFormat)

RETURN self
/*----------------------------------------------------------------------*/

METHOD read(xmlFileName,ignoreChecksumFile)
LOCAL tempNode
  default ignoreChecksumFile:=.f.

  ::fileName:=xmlFileName

  // check whether file exists
  if empty(xmlFileName)
    BREAK myErrorNew("SEPA",EG_OPEN,,"read","missing filename")
  endif
  if ! hb_FileExists( xmlFileName )
    BREAK myErrorNew("SEPA",EG_OPEN,,"read","file not found",xmlFileName)
  endif

  // check for checkSumFile
  if ! ignoreChecksumFile .and. ! ::readCheckSumFile()
    BREAK myErrorNew("SEPA",EG_READ,,"checksum","invalid checksum file",xmlFileName)
  endif

  // set XML defaults
  mxmlSetCustomHandlers( @load_c(), @save_c() )

  ::tree:=mxmlLoadFile( ::tree, xmlFileName, @type_cb() )
  IF Empty( ::tree )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","Invalid XML File",xmlFileName)
  endif

  // find MessageId
  tempNode:=mxmlFindElement( ::tree, ::tree, "MsgId", NIL, NIL, MXML_DESCEND )
  IF Empty( tempNode )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","XML Node: MsgId not found",xmlFileName)
  endif
  ::messageID:=substr(mxmlGetText(tempNode),len(MESSAGE_ID_PREFIX)+1)

  // find executionDate
  tempNode:=mxmlFindElement( ::tree, ::tree, "ReqdExctnDt", NIL, NIL, MXML_DESCEND )
  IF Empty( tempNode )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","XML Node: ReqdExctnDt not found",xmlFileName)
  endif
  ::executionDate:=mxmlGetText(tempNode)

  // find 1st CreditSum
  ::controlSumNode1:=mxmlFindElement( ::tree, ::tree, "CtrlSum", NIL, NIL, MXML_DESCEND )
  IF Empty( ::controlSumNode1 )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","XML Node: CtrlSum not found",xmlFileName)
  endif
  ::controlSum:=val(mxmlGetText(::controlSumNode1))

  // find 1st number of transactions
  ::numTransactionsNode1:=mxmlFindElement( ::tree, ::tree, "NbOfTxs", NIL, NIL, MXML_DESCEND )
  IF Empty( ::numTransactionsNode1 )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","XML Node: NbOfTxs not found",xmlFileName)
  endif
  // ::numTransactions:=mxmlGetInteger(::numTransactionsNode1) FIXME: why is getInt not working here?
  ::numTransactions:=val(mxmlGetText(::numTransactionsNode1))

  // find PaymentInformationIdentification (Header for all transactions) -------------
  ::pmtinf:=mxmlFindElement( ::tree, ::tree, "PmtInf", NIL, NIL, MXML_DESCEND )
  IF Empty( ::pmtinf )
    BREAK myErrorNew("SEPA",EG_DATATYPE,,"read","XML Node: PmtInf not found",xmlFileName)
  endif

RETURN self

/*----------------------------------------------------------------------*/

METHOD getCreditTransfers()
LOCAL result:={},node,CT
  if !empty(::PmtInf)
    node:=mxmlFindElement( ::PmtInf, ::PmtInf, CREDIT_TRANSFER_NODE_NAME, NIL, NIL, MXML_DESCEND )
    do while ! empty(node)
      CT:=CTrecord():read(node)
      aadd(result,CT)
      node:=mxmlFindElement( node, ::PmtInf, CREDIT_TRANSFER_NODE_NAME, NIL, NIL, MXML_DESCEND )
    enddo
  endif
return result
/** eom */

/*----------------------------------------------------------------------*/



METHOD addCreditTransfer(CT)
LOCAL CdtTrfTxInf,cdtr,node

  // CreditTransferTransactionInformation ---------------------------------
  CdtTrfTxInf:=mxmlNewElement( ::pmtinf, CREDIT_TRANSFER_NODE_NAME )

  // PaymentIdentification
  node:=mxmlNewElement( CdtTrfTxInf, "PmtId" )

  // EndToEndIdentification
  node:=mxmlNewElement( node, "EndToEndId" )
  mxmlNewText( node, 0, CT:getID())

  // Amount
  node:=mxmlNewElement( CdtTrfTxInf, "Amt" )

  // InstructedAmount
  node:=mxmlNewElement( node, "InstdAmt" )
  mxmlElementSetAttr( node, "Ccy" , "EUR" )
  mxmlNewText( node,0,alltrim(str(CT:getValue(),20,2)))

  // CreditorAgent
  if ! empty( CT:getBIC() )
    node:=mxmlNewElement( CdtTrfTxInf, "CdtrAgt" )
    // FinancialInstitutionIdentificat
    node:=mxmlNewElement( node, "FinInstnId" )
    node:=mxmlNewElement( node, "BIC" )
    mxmlNewText( node, 0, CT:getBIC())
  else
    // node:=mxmlNewElement( node, "Othr" )
    // mxmlNewText( node, 0, "NOTPROVIDED" )
  endif

  // Creditor
  cdtr:=mxmlNewElement( CdtTrfTxInf, "Cdtr" )
  // Creditor-Name
  node:=mxmlNewElement( cdtr, "Nm" )
  mxmlNewText( node, 0, trim(CT:getCreditorName()))

  // Creditor-ID / OrgId -> Other see 2.2.1.5
  node:=mxmlNewElement( cdtr, "Id" )
  node:=mxmlNewElement( node, "OrgId" )
  node:=mxmlNewElement( node, "Othr" )
  node:=mxmlNewElement( node, "Id" )
  // watchout: we join Creditor-ID and Sequencer in one field here
  // therefore Creditor-ID and Sequencer should not contain a "-" :(
  mxmlNewText( node, 0, trim(CT:getCreditorID()+if(empty(CT:getSequencer()),"","-"+;
    CT:getSequencer())))

  // CreditorAccount
  node:=mxmlNewElement( CdtTrfTxInf, "CdtrAcct" )
  // Identification
  node:=mxmlNewElement( node, "Id" )
  node:=mxmlNewElement( node, "IBAN" )
  mxmlNewText( node, 0, trim(CT:getIBAN()))

  // RemittanceInformation
  node:=mxmlNewElement( CdtTrfTxInf, "RmtInf" )
  // unstructured
  node:=mxmlNewElement( node, "Ustrd" )
  mxmlNewText( node, 0, CT:getPurpose())

  // end of CreditTransferTransactionInformation ----------------------------


  // increase number of transactions
  ::numTransactions:=mxmlGetInteger(::numTransactionsNode1)+1
  mxmlSetInteger( ::numTransactionsNode1, ::numTransactions )
  mxmlSetInteger( ::numTransactionsNode2, ::numTransactions )

  // increase control sum
  ::controlSum+=round(CT:getValue(),2)
  // we set it as text, as we don't now how te set the number of digits :(
  mxmlSetText(::controlSumNode1,0,alltrim(str(::controlSum,20,2)))
  mxmlSetText(::controlSumNode2,0,alltrim(str(::controlSum,20,2)))

RETURN self
/*----------------------------------------------------------------------*/

METHOD getControlSum()
return ::controlSum

/*----------------------------------------------------------------------*/
METHOD getNumTransactions()
return ::numTransactions

/*----------------------------------------------------------------------*/
METHOD getExecutionDate()
LOCAL dateFormat:=Set( _SET_DATEFORMAT )
LOCAL result

  SET DATE FORMAT TO SEPA_DATE_FORMAT
  result:=ctod(::executionDate)

  // reset date type
  SET DATE FORMAT TO (dateFormat)

return result

/*----------------------------------------------------------------------*/
METHOD dump(dumpName)

  if dumpName<>NIL
    ::fileName:=dumpName
  endif

  if ::fileName<>NIL

    // save the file
    mxmlSaveFile( ::tree, ::filename, @whitespace_cb() )

    // create checksum file
    ::dumpCheckSumFile()
  endif

RETURN self
/*----------------------------------------------------------------------*/


METHOD getCheckSumFileName()
LOCAL checkFileName

  if ::fileName==NIL
    BREAK myErrorNew("SEPA",EG_READ,"read","filename not set")
  else
    checkFileName:=getBaseName(::fileName)+BACKSLASH+CHECKSUM_PATH+BACKSLASH+;
      getFileName(::fileName)+ CHECKSUM_EXT
    if ! file(getBaseName(::fileName)+BACKSLASH+CHECKSUM_PATH)
      dirMake(getBaseName(::fileName)+BACKSLASH+CHECKSUM_PATH)
    endif
  endif

return checkFileName

/*----------------------------------------------------------------------*/

METHOD ferase()
LOCAL checkFileName

  if ::fileName==NIL
    BREAK myErrorNew("SEPA",EG_READ,"read","filename not set")
  else

    // as of now we move the files to the old direcory instead of deleting them

    // ferase(::fileName)
    // ferase(::getCheckSumFileName())

    if ! file(getBaseName(::fileName)+BACKSLASH+DELETED_PATH)
      dirMake(getBaseName(::fileName)+BACKSLASH+DELETED_PATH)
      dirMake(getBaseName(::fileName)+BACKSLASH+DELETED_PATH+BACKSLASH+CHECKSUM_PATH)
    endif
    checkFileName:=::getCheckSumFileName()
    frename(::fileName,getBaseName(::fileName)+BACKSLASH+DELETED_PATH+BACKSLASH+;
      getFileName(::fileName))
    frename(checkFileName, getBaseName(::fileName)+BACKSLASH+DELETED_PATH+BACKSLASH+CHECKSUM_PATH+;
      BACKSLASH+ getFileName(checkFileName))
  endif

return self

/*----------------------------------------------------------------------*/


METHOD dumpCheckSumFile()
LOCAL checksum,checkTree,doc
LOCAL checkFileName

  if ::fileName==NIL
    BREAK myErrorNew("SEPA",EG_WRITE,,"write","filename not set")
  else
    // create checksum file
    checkSum:=HB_MD5File(::filename)

    checkFileName:=::getCheckSumFileName()
    checkTree:=mxmlNewXML()
    doc:=mxmlNewElement( checkTree, "Document" )
    mxmlElementSetAttr( doc, "checksum",checkSum)
    mxmlElementSetAttr( doc, "file",checkFileName)
    mxmlSaveFile( checkTree, checkFileName, @whitespace_cb() )

  endif
RETURN self
/*----------------------------------------------------------------------*/

METHOD readCheckSumFile()
LOCAL checkFileName,checkTree,node,checkSum

  if ::fileName==NIL
    BREAK myErrorNew("SEPA",EG_READ,"read","filename not set")
  else

    checkFileName:=::getCheckSumFileName()
    if ! file(checkFileName)
      return .f.
    endif

    // set XML defaults
    mxmlSetCustomHandlers( @load_c(), @save_c() )

    checkTree:=mxmlLoadFile( checkTree, checkFileName, @type_cb() )
    IF Empty( checkTree )
      return .f.
    endif

    node:=mxmlFindElement( checkTree, checkTree, "Document", NIL, NIL, MXML_DESCEND )
    IF Empty( node)
      return .f.
    endif

    checkSum:=mxmlElementGetAttr(node,"checksum")
    IF Empty(checkSum)
      return .f.
    endif

    // check whether checksum is ok
    if checkSum <> HB_MD5File(::filename)
      return .f.
    endif
  endif

RETURN .t.
/*----------------------------------------------------------------------*/

/** eoc - end of class */


/** Class CTrecord (Credit Transfer Record)********************************************** */
CLASS CTrecord
DATA ID INIT "" HIDDEN
DATA sequencer INIT "" HIDDEN
DATA creditorName INIT "" HIDDEN
DATA creditorID INIT "" HIDDEN
DATA IBAN INIT "" HIDDEN
DATA BIC INIT "" HIDDEN
DATA purpose INIT "" HIDDEN
DATA value INIT 0.0 HIDDEN

// getters & setters
METHOD setID(s)
METHOD getID()
METHOD setSequencer(s)
METHOD getSequencer()
METHOD setCreditorName(s)
METHOD getCreditorName()
METHOD setCreditorID(s)
METHOD getCreditorID()
METHOD setIBAN(s)
METHOD getIBAN()
METHOD setBIC(s)
METHOD getBIC()
METHOD setPurpose(s)
METHOD getPurpose()
METHOD setValue(r)
METHOD getValue()

METHOD read(xmlNode)
METHOD print()

ENDCLASS

/*----------------------------------------------------------------------*/

// getters & setters
METHOD setID(s)
  ::ID:=checkSepaCharacters(s)
RETURN ::ID

METHOD getID()
RETURN ::ID

METHOD setSequencer(s)
  ::sequencer:=trim(checkSepaCharacters(s))
return ::Sequencer

METHOD getSequencer()
RETURN ::sequencer

METHOD setCreditorName(s)
  ::creditorName:=trim(checkSepaCharacters(s))
RETURN ::creditorName

METHOD getCreditorName()
RETURN ::creditorName

METHOD setCreditorId(s)
  ::creditorID:=trim(checkSepaCharacters(s))
RETURN ::creditorID

METHOD getCreditorID()
RETURN ::creditorID

METHOD setIBAN(s)
  ::IBAN:=trim(checkSepaCharacters(s)) // FIXME: call additional IBAN check!
RETURN ::IBAN

METHOD getIBAN()
RETURN ::IBAN

METHOD setBIC(s)
  ::BIC:=trim(checkSepaCharacters(s))
RETURN ::BIC

METHOD getBIC()
RETURN ::BIC

METHOD setPurpose(s)
  ::purpose:=trim(checkSepaCharacters(s,.t.))
RETURN ::purpose

METHOD getPurpose()
RETURN ::purpose

METHOD setValue(r)
LOCAL text
  if r<=0
    text:=if(::getCreditorID()==NIL,"",::getCreditorID()+" ")
    text+=if(::getCreditorName()==NIL,"",::getCreditorName())
    BREAK;
      myErrorNew("SEPA",EG_NUMERR,,"setValue","||Unerlaubter Betrag: "+alltrim(str(r,20,2))+"|"+;
      text)
  endif
  ::value:=r
RETURN ::value

METHOD getValue()
RETURN ::value

/*----------------------------------------------------------------------*/

METHOD read(xmlNode)
LOCAL node,childNode,tempNode,tempText

  if xmlNode==NIL .or. mxmlgetelement(xmlNode)<>CREDIT_TRANSFER_NODE_NAME
    BREAK myErrorNew("SEPA:CT",EG_DATATYPE,,"read","Not a valid CdtTrfTxInf XML Node")
  endif

  node = mxmlWalkNext(xmlNode,xmlNode, MXML_DESCEND)
  do while ! empty(node)
    switch mxmlgetelement(Node)
    case "EndToEndId"
      ::setID(getNodeText(node))
      exit

    case "Cdtr" // creditor
      // go one level down
      childNode = mxmlGetFirstChild(node)
      do while ! empty(childNode)

        switch mxmlgetelement(childNode)
        case "Nm" // creditor
          ::setCreditorName(getNodeText(childNode))
          exit
        case "Id" // creditor
          tempNode:=mxmlFindElement( childNode, childNode, "Id", NIL, NIL, MXML_DESCEND )
          tempText:=getNodeText(tempNode)
          if "-" $ tempText
            ::setCreditorID(left(tempText,at("-",tempText)-1))
            ::setSequencer(substr(tempText,at("-",tempText)+1))
          else
            ::setCreditorID(tempText)
          endif
          exit
        endswitch

        // go to next child node
        // childNode = mxmlWalkNext(childNode, node, MXML_DESCEND)
        childNode = mxmlWalkNext(childNode, node, MXML_NO_DESCEND)
      enddo

      case "IBAN"
        ::setIBAN(getNodeText(node))
        exit
        case "BIC"
          ::setBIC(getNodeText(node))
          exit
          case "Ustrd"
            ::setPurpose(getNodeText(node))
            exit
            case "InstdAmt"
              ::setValue(val(getNodeText(node)))
              exit

              otherwise
                // qout(getNodeText(node))
            endswitch

            // go to next node
            node = mxmlWalkNext(node, xmlNode, MXML_DESCEND)
          enddo

          return self
/** eom */

/*----------------------------------------------------------------------*/

METHOD print()
  // qout("Creditor:",::creditor)
  // qout("IBAN....:",::IBAN )
  // qout("BIC.....:",::BIC )
  // qout("Purpose.:",::purpose )
  // qout("Value...:",::value )

  qout("Empf�nger.:",::creditor)
  qout("IBAN......:",::IBAN )
  qout("BIC.......:",::BIC )
  qout("Verw.Zweck:",::purpose )
  qout("Wert......:",::value ,"Euro" )
return self
/** eom */


/** eoc - end of class ****************************************************************/


/** Some utility functions ************************************************************/

/** returns the entire string of a TextNode
  * concatenates the text blocks from mxmlGetText(node) with spaces */
static FUNCTION getNodeText(mainNode)
LOCAL result:="",node

  // FIXME: check whether this is a text node?!
  node = mxmlGetFirstChild(mainNode)
  do while ! empty(node)
    result += mxmlGetText(node)+" "
    // go to next node
    node = mxmlWalkNext(node, mainNode, MXML_NO_DESCEND)
  enddo
return trim(result)
/** eof */

/** replaces all illegal characters with space if quiet,
    if not quiet we bail out on wrong characters */
FUNCTION checkSepaCharacters(s,quiet,exceptions)
LOCAL result:="",i,tempVal

  default exceptions:=""
  default quiet:=.f.

  for i:=1 to len(s)
    tempVal:=substr(s,i,1)
    if isAlpha(tempVal) .or. isDigit(tempVal) .or. tempVal $ ALLOWED_SPECIAL_CHARACTERS
      result+= tempVal
    else
      if tempVal == "&"
        result+="+" // special case & / +
      else
        if quiet
          result+=" " // we use blank instead of wrong characters
        else
          // ERROR, wichtig wird bei Eingabe der �berweisungen abgefangen!
          BREAK myErrorNew("SEPA",EG_DATATYPE,,"checkSepaCharacters","SEPA-Pr�fung||Ung�ltiges "+;
            "Zeichen: "+tempVal+"| in "+s)
        endif
      endif
    endif
  next
return result
/** eom */

/** checks user input for valid characters */
FUNCTION checkInputSepaCharacters(oGet)
LOCAL objErr
  BEGIN SEQUENCE // krit. Bereich
    checkSepaCharacters(oGet:buffer,.f.)
  RECOVER USING objErr
    Error("Fehler SEPA Export: "+objErr:description)
    return .f.
  END SEQUENCE
return .t.
/** eof */

/** creates a new error object */
static FUNCTION myErrorNew(cSubSystem,nGenCode,nSubCode,cOperation,cDescription,cFileName)
LOCAL oResult:=errorNew()
  oResult:SubSystem:=cSubSystem
  oResult:genCode:=nGenCode
  if nSubCode<>NIL
    oResult:SubCode:=nSubCode
  endif
  oResult:Operation:=coperation
  oResult:Description:=cDescription
  oResult:FileName:=cFileName

  oResult:CanDefault:=.f.
  oResult:CanSubstitute:=.f.
  oResult:CanRetry:=.f.
  oResult:Severity:=ES_ERROR
return oResult
/** eof */

/***** Some XML specific stuff (copied from hbmxml\tests\custom.prg) ****************************/

/*
 * 'whitespace_cb()' - Let the mxmlSaveFile() function know when to insert
 *                     newlines and tabs...
 */

static FUNCTION whitespace_cb( hNode, nWhere )   /* O - Whitespace string or nil */
  /* I - Element node */
  /* I - Open or close tag? */

  // LOCAL hParent                          /* Parent node */
  // LOCAL nLevel                           /* Indentation level */
  LOCAL cName                            /* Name of element */

  /*
  * We can conditionally break to a new line before or after any element.
  * These are just common HTML elements...
  */

  cName:=Lower( mxmlGetElement( hNode ) )
  IF nWhere == MXML_WS_BEFORE_OPEN
    // IF cName$"document/cstmrcdttrfinitn/grphdr/pmtinf" .or. Empty( mxmlGetFirstChild( hNode ) )
    IF cName$"document/cstmrcdttrfinitn/grphdr" // SEPA unsch�n!!!
      RETURN hb_eol()
    else
      RETURN Space( 0 )
    endif
  ELSEIF nWhere == MXML_WS_AFTER_CLOSE
    RETURN hb_eol()
  ENDIF

  /*
  * Return NULL for no added whitespace...
  */

RETURN nil
/** eof */

/*
 * 'type_cb()' - XML data type callback for mxmlLoadFile()...
 */

static FUNCTION type_cb( hNode )                 /* O - Data type */
  /* I - Element node */
  LOCAL cType                            /* Type string */

   /*
    * You can lookup attributes and/or use the element name, hierarchy, etc...
    */

  IF Empty( cType:=mxmlElementGetAttr( hNode, "type" ) )
    cType:=mxmlGetElement( hNode )
  ENDIF

  SWITCH Lower( cType )
  CASE "integer" ; RETURN MXML_INTEGER
  CASE "opaque" ; RETURN MXML_OPAQUE
  CASE "real" ; RETURN MXML_REAL
  ENDSWITCH

RETURN MXML_TEXT
/** eof */

  #xtranslate _ENCODE( <xData> ) => ( hb_base64encode( hb_serialize( mxmlGetCustom( <xData> ) ) ) )
static FUNCTION load_c( node, cString )

  mxmlSetCustom( node, hb_deserialize( hb_base64decode( cString ) ) )

RETURN 0  /* 0 on success or non-zero on error */

static FUNCTION save_c( node )

RETURN _ENCODE( node ) /* string on success or NIL on error */


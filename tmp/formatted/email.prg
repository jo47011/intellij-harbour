/** Verschicken von Emails with win api CDO
 *
 * see http://msdn.microsoft.com/en-us/library/ms526947(v=exchg.10).aspx
*
*/

#include "mystd.ch"

#include "simpleio.ch"

// #require "hbwin" // ->removed on win64

// #include "extern.ch"

// #include "common.ch"
#include "hbthread.ch"
#include "hbgtinfo.ch"


// Info we use my setup as default, so we don't need to write it in any config file
// overwrite in cfg file for customer specific values
#define FROM_EMAIL getProperty("Email.from","programm@gruhnsoft.de")
#define FROM_NAME getProperty("Customer.name","GruhnSoft")
#define REPLY_EMAIL getProperty("Email.reply","programm@gruhnsoft.de")
#define SMTP_SERVER getProperty("Email.smtp.server","")
#define SMTP_USER getProperty("Email.smtp.user","")
#define SMTP_PASS decrypt(getProperty("Email.smtp.pass",""))
#define SMTP_PORT getProperty("Email.smtp.port","")

#define MS_PREFIX "http://schemas.microsoft.com/cdo/configuration/"



/* Procedure EMail       *****************************************
*
* dient zum automat. verschicken von emails
*
* Parameters:
*    mailto = Empfaenger
*    subject
*    body   (string or array)
*    attachments (binary attachment) .or text attachment if ends with ".txt|.log|.inf|.asc"
*
*/

Function EMail( mailto , subject , body , attachments , eraseAttachment , forceEmail)
LOCAL tempHolidays:=getProperty("Email.holidays","J")
LOCAL tempWeeks, von,bis
LOCAL tempText:=""
LOCAL result, tempRecipients, Recipient

  default eraseAttachment:=.f.
  default forceEmail:=.f.

  if NO_EMAIL
    if ! getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN
      Error("ACHTUNG: Email nicht freigeschaltet.|"+subject,.t.)
    endif
    return .f.
  endif

  // Email disabled during holidays -> quiet?
  if mailto<>MY_EMAIL .and. ( tempHolidays == "N" .and. ! forceEmail)
    Umgebung(WRITE_ALL)
    if open("System")
      tempWeeks:=HB_ATokens( trim(System->Holidays) , "," )
      if ascan( tempWeeks , getKw(getUser():date) ) >0
        Umgebung(LOAD)
        // NOP!
        return .f.
      endif
    endif
    Umgebung(LOAD)
  endif

  if ! forceEmail
    // nur H. Weiland Urlaub, aber keine Betriebsferien
    if getProperty("Email.customer","") $ mailto
      tempWeeks:=HB_ATokens( getProperty("Email.sperre","") , "-" )
      if len(tempWeeks) > 1 .and. getUser():id $ REMOTE_SERVICE_LOGIN+"|"+SERVER_LOGIN + "|JG" .and. ;
        dow(getUser():date) <> 1 // neu 20240724: Sonntags trotzdem schicken
        // inStackTrace("CRONJOBS")

        von:=ctod(alltrim( tempWeeks[1] ))
        bis:=ctod(alltrim( tempWeeks[2] ))
        if getUser():date >= von .and. getUser():date <= bis
          if "," $ mailto
            tempRecipients:=HB_ATokens( mailto, "," )
            mailto:=""
            for each recipient in tempRecipients
              recipient:=alltrim(recipient)
              if recipient<>getProperty("Email.customer","")
                mailto+=recipient+", "
              endif
            next
            mailto:=left(mailto,len(mailto)-2) // remove trailing ,
          else
            // NOP!
            return .f.
          endif
        endif
      endif
    endif
  endif

  // escape special characters
  subject:=escapeSpecialChars(subject)
  body:=escapeSpecialChars(body)

  default subject:="<Kein Betreff>"

  // Test oder Devel System?
  if DEVEL_PROG
    subject:="Devel: "+subject
  elseif TEST_PROG
    subject:="Test: "+subject
  endif

  if AT_HOME
    subject:="HOME->"+subject
  endif
  if TEST_PROG
    subject:="TEST->"+subject
  endif
  result:=winEmail( mailto , subject , body , attachments , eraseAttachment)

return result

/** eof */

/** escapes special characters from string */
static function escapeSpecialChars(text)
LOCAL result:=text // ,sz, pos

  if valtype(Text)=="C"

    // // translate german sonderzeichen
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�","�")
    // text:=strtran(Text,"�" ,"�")

    // ersetze | mit CR+LF
    result:=text:=strtran( text , "|" , MY_CR+MY_LF )

    // escape special characters like "
    result:=text:=strtran( text , '"' , "" ) // Neu 20230930
    //result:=text:=strtran( text , BACKSLASH , "|" ) // Neu 20230930

    // for each sz in { '"' , BACKSLASH }
    // result:=text:=strtran( text , sz , "" ) // Neu 20211009
    // // result:=""
    // // do while (pos:=at(sz,text)) > 0
    // // result:=result+left(text,pos-1)+BACKSLASH+sz
    // // text:=substr(text,pos+1)
    // // enddo
    // // result:=result+text // Rest ohne SZ kopieren
    // // text:=result // for next sonderzeichen in for loop
    // next

  endif

return result
/** eof */

static function winEmail(mailto , subject , body , attachments , eraseAttachment )
LOCAL TempPath:=TEMP+BACKSLASH+left(getUser():getLongId(),2)+BACKSLASH
LOCAL TempFile:=TempPath+"Email-"+getUser():getTempCounter()+".ps1"
LOCAL Zeile:=0, att, tempText:="", i
LOCAL alte_file, result, warte

  if set( _SET_ALTERNATE )
    alte_file:=set( _SET_ALTFILE )
    set alte off
    close alte
  endif

  // if getUser():id $ SERVER_LOGIN + "|" + REMOTE_SERVICE_LOGIN
  // warte:=.f. // sende emails im Hintergrund, Dos-Fenster �ffnen geht nicht
  // else
  // warte:=.t. // sende emails im Vordergrund, Test.
  // endif
  warte:=.f. // sende emails im Hintergrund, ohne Dos-Fenster

  mkMyDir(TempPath)

  set cons off
  set alte to (TempFile)
  set alte on

  qout( '$EmailFrom = "'+trim(FROM_EMAIL)+'"')
  qout( '$EmailTo = "'+trim(mailto)+'"')
  qout( '$Subject = "'+trim(subject)+'"')
  if body <> NIL
    if valtype(body)=="C"
      qout( '$Body = "'+body+'"')
    elseif valtype(body)=="A"
      for i:=1 to len(body)
        if valtype(body[i])=="C"
          tempText+=body[i]+MY_CR+MY_LF
        endif
      next
      qout( '$Body = "'+tempText+'"')
    else
      qout( '$Body = "unbekannter Typ:"'+valtype(body))
    endif
  endif
  qout( '$SMTPServer = "', SMTP_SERVER,'"')
  qout( '$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer,',SMTP_PORT,')')
  qout( '$SMTPClient.EnableSsl = $true')
  qout( '$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("'+SMTP_USER+'", "'+;
    SMTP_PASS+'");')
  qout( '$SMTPMessage = New-Object System.Net.Mail.MailMessage($EmailFrom,$EmailTo,$Subject,$Body)' )
  qout( '$SMTPMessage.ReplyToList.Add("'+REPLY_EMAIL+'")')
  if attachments <> NIL
    if valtype(attachments)=="C"
      addAttachement(attachments)
    elseif valtype(attachments)=="A"
      for each att in attachments
        addAttachement(att)
      next
    endif
  endif
  //qout( '$SMTPClient.Send($SMTPMessage) | Out-File -FilePath C:\schrott\email.txt')
  qout('$SMTPClient.Send($SMTPMessage)')
  qout()
  qout('$SMTPMessage.Attachments.Dispose()')
  qout('$SMTPClient.Dispose()')
  qout('$SMTPMessage.Dispose()')

  if .not. warte .and. ! DEBUG
    qout( '')
    qout( '# delete temp files')
    //qout( 'Start-Sleep -Seconds 1')
    qout( 'Remove-Item -Force "' + TempFile+'"')
  endif
  if eraseAttachment
    if valtype(attachments)== "C"
      qout( 'Remove-Item -Force "' + attachments+'"')
    elseif valtype(attachments)== "A"
      for each att in attachments
        if left(att,len(hb_cwd())) <> hb_cwd()
          att:=hb_cwd() + att
        endif
        if file( att )
          qout( 'Remove-Item -Force "' + att+'"')
        endif
      next
    endif
  endif

  set alte off
  close alte
  deleteCTRLZ(TempFile)

  // run command in powershell, warte:=.f. im background ohne schwarzes Fenster
  result:=myrun('powershell',' -File ' + TempFile , warte)
  //result:=RunHidden('powershell -File ' + TempFile, .t.)

  trouble("email", { "Win-Email: "+subject ,;
    "sent to  : "+mailTo , ;
    "Anhang   : "+getAttachmentList(attachments) })
  //"result   : "+str(result) } )

  if .f. .and. warte .and. ! DEBUG // l�sche Dateien, the old way
    // ferase( TempFile) -> now done in script itself

    // erase attachments if applicable
    if eraseAttachment
      if valtype(attachments)== "C"
        ferase(attachments)
      elseif valtype(attachments)== "A"
        for each att in attachments
          if left(att,len(hb_cwd())) <> hb_cwd()
            att:=hb_cwd() + att
          endif
          if file( att )
            ferase( att )
          endif
        next
      endif
    endif
  endif

  if ! empty(alte_file)
    set alte to (alte_file) ADDITIVE
    set alte on
  else
    set cons on
  endif

return .t.

/** liefert einen String mit der Liste aller Attachemnents (filenamen) */  
static function getAttachmentList(attachments)
  if attachments == NIL
    return "<ohne>"
  endif
return array2readable(attachments)

static procedure addAttachement(att)
  default att:="None!!!"
  if file(att)
    qout( '$attachment = New-Object System.Net.Mail.Attachment("' + att + '")')
    qout( '$SMTPMessage.Attachments.Add($attachment)' )
  else
    trouble("root", att+" nicht gefunden.")
  endif
return


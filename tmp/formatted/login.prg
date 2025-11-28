/** Class representing the current loginsd of a user */

#include "MyStd.ch"

#include "hbclass.ch"

#define SPLIT_LOGINS "@"
#define SPLIT_FIELDS "|"

/** Maximale Anzahl zu �ffnende Fenster */
#define MAX_WINDOWS 30

CLASS Login

DATA id READONLY
DATA counter READONLY
DATA datetime INIT ttoc(Hb_dateTime())
DATA clientName INIT CLIENT_NAME+":"+USER_NAME

METHOD new(kurzel, counter)
METHOD fromString(line)
METHOD toString()
METHOD toInfoString()
METHOD isCurrent()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(kurzel, counter)

  ::id:=kurzel

  if counter == NIL
    counter:=LoginDispatcher():new():getFreeNumber(kurzel) // get next free number
    if counter == NIL
      // no more logins possible, raise error
      throw( ErrorNew("LOGIN",EG_LOGIN_EXHAUSTED,,"login","No free Numbers found. Max is: " +;
        str(MAX_WINDOWS,2)) )
    endif
    counter:=str(counter,2)
  endif

  ::counter:=right("00"+alltrim(counter),2) // seit 11.7.19 2 Stellen f�r mehr Fenster

RETURN self
/** eom */

METHOD fromString(line)
  ::id:=token(line, SPLIT_FIELDS, 1)
  ::counter:=token(line, SPLIT_FIELDS, 2)
  ::datetime:=token(line, SPLIT_FIELDS, 3)
  ::clientName:=token(line, SPLIT_FIELDS, 4)
return self
/** eom */

METHOD toString()
LOCAL result:=""
  result += ::id + SPLIT_FIELDS
  result += ::counter + SPLIT_FIELDS
  result += ::datetime + SPLIT_FIELDS
  result += ::clientName
return result
/** eom */

METHOD toInfoString()
LOCAL result:="", i:=0
LOCAL tempNames:=getProperty("Customer.igel","")
LOCAL igelNames:=HB_ATokens(tempNames,";")

  result += ::id + space(1)
  result += ::counter + space(1)
  result += ::datetime + space(1)
  if "IGEL" $ ::clientName
    i:=ascan( igelNames , { |aName| substr(::clientName,at("IGEL",::clientName),15) $ aName } )
  endif

  if i>0
    result += igelNames[i] + substr(::clientName,16)
  else
    result += ::clientName
  endif

return result
/** eom */

METHOD isCurrent()
return ::id == getUser():id .and. ::counter == getUser():counter
/** eom */


/*----------------------------------------------------------------------
 * Helper Class for managing logins
 *----------------------------------------------------------------------*/

CLASS LoginDispatcher

DATA logins READONLY INIT {}

METHOD new()
METHOD getLogins(mKurzel, exceptCurrent) // mKurzel optional
METHOD getLoginsByClient(clientName)
METHOD addLogin(mKurzel)
METHOD removeLogin(mKurzel) // logout
METHOD getFreeNumber(mKurzel)
METHOD resetLogin(kurzel) // mKurzel optional
METHOD getPrintBuffer()
METHOD writeLogins(mKurzel, allLogins)

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new()
RETURN self

/*----------------------------------------------------------------------*/

METHOD getLogins(mKurzel, exceptCurrent) // mKurzel optional
LOCAL result:={}
LOCAL aktSel:=alias()
LOCAL aktRec
LOCAL tokens, t, login
LOCAL loginOpend:=(select("Login") > 0)
LOCAL objErr

  default mKurzel:=""
  default exceptCurrent:=.f.

  if loginOpend .or. open("login")
    select Login
    aktRec:=LOGIN->(recno())
    if empty(mKurzel)
      go top
    else
      dbseek(mKurzel)
    endif

    do while ! LOGIN->(eof()) .and. (empty(mKurzel) .or. mKurzel == LOGIN->Kurzel)
      BEGIN SEQUENCE // krit. Bereich
        if ! empty(LOGIN->Logins)
          tokens:=HB_ATokens(LOGIN->Logins,SPLIT_LOGINS)
          for each t in tokens
            login:=login():fromString(t)
            if .not. exceptCurrent .or. .not. login:isCurrent()
              aadd(result, login)
            endif
          next
        endif
      RECOVER USING objErr
        Error("Fehler Login access: "+objErr:description)
      END Sequence
      skip
    enddo
  endif

  if loginOpend
    dbgoto(aktRec)
  else
    close login
  endif
  if ! empty(aktSel)
    select (aktSel)
  endif

return result
/** eom */

METHOD getLoginsByClient(mClientName)
LOCAL logins:=::getLogins()
LOCAL result:={}, l
  for each l in logins
    if l:clientName == mClientName
      aadd(result, l)
    endif
  next
return result
/** eom */


/** Resets all logins, except for current login
  * mKurzel is optional
  */
METHOD ResetLogin(mKurzel, warning)
LOCAL aktSel:=alias()
LOCAL aktRec
LOCAL tokens, t, current, login
LOCAL loginOpend:=(select("Login") > 0)

  default mKurzel:=""
  default warning:=.f.

  if loginOpend .or. open("login")
    select Login
    aktRec:=LOGIN->(recno())
    if empty(mKurzel)
      go top
    else
      dbseek(mKurzel)
    endif
    if LOGIN->(eof())
      Error(ACHTUNG+" Benutzer: " + mKurzel + " nicht gefunden.")
    else
      do while ! LOGIN->(eof()) .and. (empty(mKurzel) .or. mKurzel == LOGIN->Kurzel)
        current:=""
        if ! empty(LOGIN->Logins)
          tokens:=HB_ATokens(LOGIN->Logins, SPLIT_LOGINS)
          for each t in tokens
            login:=login():fromString(t)
            if login:isCurrent()
              current:=login:toString()
            endif
          next
        endif

        if LOGIN->Logins <> current
          rec_lock(0)
          replace LOGIN->Logins with current
          if mKurzel <> getUser():id .and. len(tokens) > 0 .and. warning .and.;
            getProperty("System.logout.warning","J")=="J"
            replace LOGIN->Warning with "J"
          endif
          dbcommit()
          dbunlock()
        endif
        skip
      enddo
    endif
  endif

  if loginOpend
    dbgoto(aktRec)
  else
    close login
  endif
  if ! empty(aktSel)
    select (aktSel)
  endif

return self
/** eom */


/** Liefert eine Liste (PrintBuffer) aller z.Zt. eingeloggter Benutzer (ausgenommen eigener Login)
  */
METHOD getPrintBuffer()
LOCAL printBuffer:=printBuffer():new()
LOCAL all:=::getLogins(), l

  if len(all) > 1
    ->? "Aktuelle Logins "+ttoc(DateTime())
    ->? replicate("=",37)

    for each l in all
      ->? l:toInfoString()
    next

  endif

return printBuffer
/** eom */

/** Liefert die niedrigste freie Nummer eines Users
  */
METHOD getFreeNumber(mKurzel)
LOCAL all:=::getLogins(mKurzel), l
LOCAL last:=NIL

  for each l in all
    if last <> NIL .and. last + 1 < val(l:counter)
      return last + 1
    elseif last == NIL .and. val(l:counter) > 1
      return 1
    endif
    last:=val(l:counter)
  next

  if len(all) + 1 <= MAX_WINDOWS
    return len(all) + 1
  endif

return NIL // no more windows possible
/** eom */

/** F�gt neuen Login Eintrag hinzu, steht danach auf korrektem Benutzer in Login.dbf
* returns: new login object */
METHOD addLogin(mKurzel)
LOCAL all:=::getLogins(mKurzel)
LOCAL result:=login():new(mKurzel)

  aadd(all, result)
  ::writeLogins(mKurzel, all)

return result
/** eom */

/** L�scht den aktuellen Login Eintrag
* returns: new login object */
METHOD removeLogin(mKurzel)
LOCAL all:=LoginDispatcher():new():getLogins(mKurzel, .t.) // remove current

  ::writeLogins(mKurzel, all)

return self
/** eom */

METHOD writeLogins(mKurzel, allLogins)
LOCAL l, allString:=""
LOCAL isLocked:=LOGIN->(isLocked())
LOCAL aktSel:=alias()

  allLogins:=aSort(allLogins,,,{|x,y| x:counter < y:counter})

  for each l in allLogins
    allString += l:toString() + SPLIT_LOGINS
  next

  if isLocked
    replace LOGIN->Logins with substr(allString, 0, len(allString) - 1)
  else
    if open("login")
      dbseek(mKurzel)
      rec_lock(0)
      replace LOGIN->Logins with substr(allString, 0, len(allString) - 1)
      dbcommit()
      dbunlock()
      close login
    endif
    if ! empty(aktSel)
      select (aktSel)
    endif
  endif // was locked

return self
  /** eom */



/* Modul Logins.prg
*
* allem�glichen Login Functions
*
* s. auch ./utils/liust-logins.prg
*/

#include "Fileio.ch"

#define BACKSLASH chr(92)
#define SPLIT_LOGINS "@"
#define SPLIT_FIELDS "|"

  /** Pfad zur Igelliste */
#define IGEL_LISTE ".\resources\igel-list.txt"


/** Return array w/ details on currently logged in users */
Function getLogins(dir, reset)
LOCAL i:=0, tokens, mytext
LOCAL igels, t
LOCAL result:={}

  if valtype(reset) == "U"
    reset:=.f.
  endif

  aadd(result, dir)
  aadd(result, replicate("=",len(dir)))

  if right(dir,1)<>BACKSLASH
    dir:=dir+BACKSLASH
  endif

  // existiert das Verzeichnis?
  if ! file(dir+"*.*") .and. len(directory(dir,"D"))==0
    aadd(result, "ungueltiges Verzeichnis.")
    return result
  endif

  SET EXCLUSIVE OFF // Netzwerk !
  use (dir+"DAT"+BACKSLASH+"login.dbf") alias login
  go top
  do while ! LOGIN->(eof())
    if ! empty(LOGIN->Logins)
      tokens:=HB_ATokens(LOGIN->Logins, SPLIT_LOGINS)
      for each t in tokens
        i++
        aadd(result, strtran(t, SPLIT_FIELDS, " "))

        if "IGEL" $ t
          if igels == NIL
            igels:=getIgelList()
            if igels == NIL
              aadd(result, "ACHTUNG: "+IGEL_LISTE+" nicht gefunden.")
            endif
          endif
          if igels != NIL
            mytext:=space(9)
            aEval( igels , { |x| mytext += if(substr(t, at("IGEL",t ),15) $ x,x,"") } )
            aadd(result, strtran(t, SPLIT_FIELDS, " "))
          endif
        endif
      next
    endif
    skip
  enddo
  if i==0
    aadd(result, "Keine Logins.")
    aadd(result, "")
  endif
return result
/** eop */

/** liest die aktuelle Igel-Liste ein */
static function getIgelList()
LOCAL igels:={}
LOCAL nInfile , cData:=Space( 1000 ) , cOutPut:="", nLen

  if ! file(IGEL_LISTE)
    return NIL
  endif

  nInfile:=FOPEN( IGEL_LISTE , FO_READ )

  // Info: HB_FReadLine() scheint beim Stream nicht zu funktionieren
  do while ( nLen:=FRead( nInfile , @cData, hb_BLen( cData ) ) ) > 0
    cOutPut += hb_BLeft( cData, nLen )
    cData:=Space( 1000 )
  enddo
  fclose(nInfile)
  igels:=HB_ATokens( cOutPut , chr(10) ) // LineFeed
return igels
  /** eof */


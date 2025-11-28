/**
* Various procedures & functions related to the week of the year (KW)
*/

#include "mystd.ch"


/** pr�ft ob beide Felder (Wochen und Jahr) leer sind
  * d.h. "* /  " ist nicht leer!
  */
Function KWempty(kw)
return kw == NIL .or. (empty(left(kw,2)) .and. empty(right(kw,2)))

/** pr�ft ob ein String ein KW ist (99/99)  */
FUNCTION isKW(kw)
LOCAL result
  if KW == NIL .or. valtype(kw)<>"C"
    return .F.
  endif
  result:=HB_RegEx("^[0-5][0-9]/[0-9][0-9]$",kw)
return len(result) > 0


/** liefert KW in indexable Format, also 13/01, 13/51 etc.
*/
FUNCTION kwIndex(kw, leerAnsEnde)
  if leerAnsEnde <> NIL .and. leerAnsEnde .and. KWempty(kw)
    return "99/99"
  endif
return right(kw,2)+"/"+left(kw,2)
/** eof */

/** liefert eine Zahl in indexable Format als String, also 0009,0010,...
*/
FUNCTION NumIndex(num,length)
  default length:=12
return padl(alltrim(str(num,12,2)),length,"0")
/** eof */

/** liefert die n�chste KW im aktuellen oder n�chsten Jahr
  * oder falls angegeben die inc-n�chste Woche
*/
FUNCTION kwIncr(kw,inc)
LOCAL woche:=val(left(kw,2))
LOCAL Jahr:=val(right(kw,2))
LOCAL result
  default inc:=1
  if inc == 0
    return kw
  endif

  result:=woche + inc
  if result > getNumWeeks(Jahr)
    result -= getNumWeeks(Jahr)
    Jahr++
  elseif result < 1
    result += getNumWeeks(Jahr)
    Jahr--
  endif
return right("00"+alltrim(str(result,2)),2)+"/"+right("00"+alltrim(str(Jahr,2)),2)
/** eof */

/** vergl. kw
*
*  Monat/Jahr
*
* Ergebnis: 1 = falls 1. KW kleiner  als 2. KW
*           0 = falls 1. KW gleich   als 2. KW
*          -1 = falls 1. KW groesser als 2. KW
*/
FUNCTION kwKleiner( kw1 , kw2 )
LOCAL Jahr1, Jahr2
  default kw1:="  /  "
  default kw2:="  /  "

  Jahr1:=val(right(kw1,2))
  Jahr2:=val(right(kw2,2))
  if Jahr1 < Jahr2
    RETURN 1
  endif
  if Jahr1 == Jahr2
    if left(kw1,2) < left(kw2,2)
      RETURN 1
    endif
    if left(kw1,2) == left(kw2,2)
      return 0
    endif
  endif
RETURN -1
/*EOF*/

/** liefert den Abstand zw. 2 KWs in Wochen
*
*  Monat/Jahr
*
* Pos. Wert, wenn KW1 < KW2, ansonsten neg
*
* Bsp: kwDiff("01/20","02/20") => 1
*      kwDiff("03/20","01/20") => -2
*
* ACHTUNG: Betriebsferien werden bisher hier ignoriert!!!
*/
FUNCTION kwDiff(kw1,kw2)
LOCAL Jahr1, Jahr2
LOCAL result:=0,i,faktor:=1, temp

  // Vergleich nur bei num. KWs möglich (nicht bie X1 etc.)
  if isAllDigit(right(kw1,2)) .and. isAllDigit(right(kw2,2)) .and. ;
    isAlisAllDigit(left(kw1,2)) .and. isAllDigit(left(kw2,2))

    Jahr1:=val(right(kw1,2))
    Jahr2:=val(right(kw2,2))

    if Jahr1 > Jahr2
      temp:=Jahr1
      Jahr1:=Jahr2
      Jahr2:=temp
      temp:=kw1
      kw1:=kw2
      kw2:=temp
      faktor:=-1
    endif

    for i:=Jahr1 to Jahr2-1
      result+=getNumWeeks(i)
    next
    result:=result + val(left(kw2,2)) - val(left(kw1,2))
  endif

  // qout(kw1,kw2,result * faktor)

RETURN result * faktor
/*EOF*/

/**
* liefert die kleinere (j�ngere) der beiden KWs
*/
FUNCTION kwMin(kw1,kw2)
LOCAL result
  if kw1 == nil
    return kw2
  endif
  if kw2 == nil
    return kw1
  endif
  result:=( kwDiff(kw1,kw2) > 0 )
RETURN if(result,kw1,kw2)
/*EOF*/


/**
* liefert die gr��ere (�ltere) der beiden KWs
*/
FUNCTION kwMax(kw1,kw2)
LOCAL result
  if kw1 == nil
    return kw2
  endif
  if kw2 == nil
    return kw1
  endif
  result:=( kwDiff(kw1,kw2) < 0 )
RETURN if(result,kw1,kw2)
/*EOF*/


/** liefert die akt. KW zur�ck im Format WW/YY
 */
Function getCurrentKW()
return getKw(getUser():date)
/** eof */

/** liefert die KW zur�ck im Format WW-YY (zum speichern als Dateiname)
 */
Function getKWFileName(kw)
LOCAL w:=alltrim(substr(kw,1,2))
LOCAL y:=alltrim(substr(kw,4,2))
  if empty(kw)
    return "ohne-KW"
  endif
return w+"-"+y
/** eof */

/** liefert f�r die KW den letzten Tag der Woche als Datum des Jahres zur�ck. */
Function getKWLastDate(kw)
LOCAL nWeek:=val(substr(kw,1,2))
LOCAL nYear:=val(substr(kw,4,2))
LOCAL dJan4, nDayOfWeek, dMonday, dFriday
  if empty(kw)
    return ctod("01.01.80")
  endif

  // ISO-Kalender: Woche mit dem 4. Januar ist Woche 1
  dJan4:=CTOD("04/01/" + str(nYear,2)) // 4. Januar
  nDayOfWeek:=DOW(dJan4) // 1=Sonntag, 2=Montag, ... 7=Samstag
  IF nDayOfWeek = 1
    nDayOfWeek:=8
  ENDIF
  // Montag der 1. Woche:
  dMonday:=dJan4 - (nDayOfWeek - 2)

  // Montag der gew�nschten Woche:
  dMonday:=dMonday + (nWeek - 1) * 7

  // Freitag = Montag + 4 Tage
  dFriday:=dMonday + 4

RETURN dFriday
/** eof */

/** liefert Anzahl der Wochen eines Jahres zur�ck
 */
Function getNumWeeks(jahr)
LOCAL silvester
  default jahr:=year(getUser():date)
  silvester:=ctod("31.12."+str(jahr))

  if week(silvester)==1
    return 52
  endif
return 53
/** eof */

/** liefert die KW zur�ck im Format WW/YY, default ist currentKW
 */
Function getKW(datum)
LOCAL myWeek , myYear , kw

  if empty( datum )
    return "  /  "
  endif

  default datum:=getUser():date
  myWeek:=week(datum)
  myYear:=year(datum)
  // ACHTUNG die letzten Tage im alten Jahr, können bereits zur 1. KW des neuen Jahrs gehören!!!
  if myWeek==1 .and. month(datum)==12
    myYear++
  endif
  // ACHTUNG die letzten Tage im alten Jahr, können bereits zur 1. KW des neuen Jahrs gehören!!!
  if myWeek>=52 .and. month(datum)==1
    myYear--
  endif
  kw:=right("00"+alltrim(str(myWeek,2)),2)+"/"+right(str(myYear,4),2)
return kw
/** eof */

/** liefert den Monat im Format MM/YY
 */
Function getMonth(datum)
LOCAL myMonth , myYear , result
  myMonth:=month(datum)
  myYear:=year(datum)
  result:=right("00"+alltrim(str(myMonth,2)),2)+"/"+right(str(myYear,4),2)
return result
/** eof */

/** pr�ft ob der ganze String nur aus Zahlen besteht */
FUNCTION isAllDigit(s)
LOCAL i
  for i:=1 to len(s)
    if ! isdigit(substr(s,i,1))
      return .f.
    endif
  next
return .t.
/** eof */

/** Liefert die KalenderWoche des Datums zur�ck (1-53)
 *
 * funktioniert ab dem 4.1.0100 bis und mit 29.12.2999
 */
FUNCTION Week(datum)
LOCAL firstdate:=DATE()
LOCAL kalwoche:=0
LOCAL neudatum:=DATE()
LOCAL resttage:=0
LOCAL wochentag:=0
  IF VALTYPE(datum)=="D"
    wochentag=DOW(datum)+5
    resttage =wochentag-(INT((wochentag+0.1)/7)*7)
    neudatum =datum+3-resttage
    firstdate=CTOD("01.01."+STR(YEAR(neudatum),4,0))
    kalwoche =1+INT((neudatum-firstdate+0.1)/7)
  ENDIF
RETURN(kalwoche)

/** Liefert den Monat einer KalenderWoche zur�ck  */
FUNCTION getKWMonth(kw)
LOCAL nYear:=2025 // Year
LOCAL nWeek:=val(substr(kw,1,2)) // Calendar week
LOCAL dDate // Computed date
LOCAL nMonth // Month to be extracted
LOCAL dFirstDay:=CTOD("01/01/" + substr(kw,4)) // Get the first day of the year

  if left(KW,2)=="X1" // Abruf
    return 0
  endif

  // Determine the date for the specified week and its Monday
  dDate:=dFirstDay + (nWeek - 1) * 7 - (DOW(dFirstDay) - 1)

  // Extract the month
  nMonth:=MONTH(dDate)

RETURN nMonth
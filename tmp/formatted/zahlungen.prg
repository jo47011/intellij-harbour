/* Modul: Allg_Miki.prg
*
* enth�lt alle globalen, Miki-spez. Proceduren
*/

#include "Miki.ch"


/*
*
*  kennzeichnen von Rechnungen als bezahlt
*/
PROCEDURE RechAuswahl()

  cls
  Titel("Zahlungseingang")
  Message("Dateien werden ge�ffnet.  Bitte warten...")

  if ! open("Rechaus","Zahlkond")
    Error(TRY_AGAIN)
    close data
    RETURN
  endif

  Message("Liste wird vorbereitet.   Bitte warten...")

  SELECT Rechaus
  // Hinweis: Bitte F5 -> toggleZahlIndex() beachten
  index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE DESCENDING; // alle
  for empty( RECHAUS->STORNO_NR )
    // for RECHAUS->Brutto > 0 .and. empty( RECHAUS->STORNO_NR )
    index on RECHAUS->RechNr tag TEMP_IND2 TEMPORARY ADDITIVE DESCENDING ; // alle offenen
    for empty( RECHAUS->STORNO_NR ) .and. RECHAUS->Bezahlt==ctod("  .  .  ") ;
      .and. RECHAUS->Mahnstufe > 0 .and. RECHAUS->Brutto > 0
      //for RECHAUS->Brutto > 0 .and. empty( RECHAUS->STORNO_NR ) .and. RECHAUS->Bezahlt==ctod("  .  .  ") RECHAUS->(ordSetFocus( ordNumber( TEMP_INDEX ) ) ) // alle auch bezahlte anzeigen

  /* Relation setzten */
      SELECT Rechaus
      SET RELATION TO RECHAUS->ZkNr into Zahlkond

      Message("Rechnungsnummer eingeben oder Rechnung ausw�hlen.           @ESC@=Ende")
      do while ! ABBRUCH
        Hilfe("RECHBEZAHLT",getnew(),"")
      enddo

      close data
      return
/** eop */


  /** Abfrage ob Rechnung bezahlt ist j/n
  */
FUNCTION RechBezahlt()
LOCAL top:=6

  Umgebung(WRITE)

  ZAHLKOND->(dbseek( RECHAUS->ZkNr ))

  // Rechnung anzeigen
  setcolor(COLWIN)
  Fenster(top , 16 , top + 14 , 65, "Rechnung")

  @ top + 1,18 say "Rech.Nr..: " + RECHAUS->RechNr
  @ top + 1,51 say "vom: " + dtoc(RECHAUS->ReaDat)
  @ top + 2,18 say "AB.Nr....: " + RECHAUS->AufNr
  @ top + 4,18 say "Kunde....: " + RECHAUS->KundNr + " " + left( RECHAUS->KurzName , 26 )
  @ top + 6,18 say "Brutto...: " + transstr(RECHAUS->Brutto,12,2) + space(1) + EURO_SIGN

  // noch nicht bezahlt
  if empty( RECHAUS->Bezahlt )
    @ top + 7,18 say "Bezahlt..: " + transstr(0,12,2) + space(1) + EURO_SIGN
    @ top + 8,18 say "            ============"
    @ top + 9,18 say "Rest.....: " + transstr(RECHAUS->Brutto,12,2) + space(1) + EURO_SIGN + ;
      "     f�llig: "+ dtoc(RECHAUS->Faellig)

    @ top + 11,18 say "Mahnstufe: " + str( RECHAUS->Mahnstufe , 1)
    @ top + 12,18 say "Zahl.Kond: " + ZAHLKOND->Text
    @ top + 13,18 say "("+ZAHLKOND->ZkNr+")"+space(7) + ZAHLKOND->Text2

    if Message( "Rechnung: " +;
      RECHAUS->RechNr + " Zahlung @e@rhalten?     @E@/@ESC@=Abbruch","E","E")=="E"
      if rec_lock(5)
        replace RECHAUS->Bezahlt with getUser():date
        dbcommit()
        dbunlock()
      endif
    endif

  else
    // bereits bezahlt
    @ top + 7,18 say "Bezahlt..: " + transstr(RECHAUS->Brutto,12,2) + space(1) + EURO_SIGN + ;
      "         am: "+ dtoc(RECHAUS->Bezahlt)
    @ top + 8,18 say "            ============"
    @ top + 9,18 say "Rest.....: " + transstr(0,12,2) + space(1) + EURO_SIGN

    if Message( "Zahlungseingang f�r Rechnung: " + RECHAUS->RechNr + " @w@iderrufen?   "+;
      "@W@/@ESC@=Abbruch","W"," ")=="W"
      if rec_lock(5)
        replace RECHAUS->Bezahlt with ctod("  .  .  ")
        setDuedate()
        dbcommit()
        dbunlock()
      endif
    endif
  endif

  keyboard( chr(K_DOWN) ) // gehe auf n�chsten -> l�sche Suchfeld

  Umgebung(LOAD)

return .t.
/** eof */


/** Berechnet und setzt das F�lligkeitsdatum sowie die Mahnstufe (falls 0 ) in Rechaus.
  *
  * returns: Liefert die Mahnstufe zur�ck
  *
  * Hinweis: Monate sind nicht 30 Tage sondern als Folge-Monat definiert:
  * d.h. wenn man am 18. Mai eine Rechnung ZK mit 1 Monat und 15 Tage hat,
  * hei�t das am 15. Juni ist die Rechnung f�llig.
  *
  * Rechaus muss selektiert und gelockt sein!
  */
FUNCTION setDuedate()
LOCAL mahnDat

  // nop bei Gutschriften, seit 16.2.16 doch bei 0-Rechnungen
  if RECHAUS->Brutto < 0
    return 0
  endif

  ZAHLKOND->(dbseek( RECHAUS->ZkNr ))
  if ZAHLKOND->(eof())
    if ! empty( RECHAUS->ZkNr ) .or. year( RECHAUS->ReaDat ) > 2009 // alter Adel wird ignoriert
      Error( ACHTUNG +"Zahlungskonditionen ("+RECHAUS->ZkNr+") nicht gefunden.||"+;
        "          Rechnung: "+RECHAUS->RechNr + SCHWERER_FEHLER )
    endif
    return -1
  endif

  // => vershcoben nach getDueDate()
  // // 1. Fall: nur Tage des F�lligkeitszeitraums eingegeben
  // if empty( ZAHLKOND->Monate )
  // replace RECHAUS->Faellig with RECHAUS->ReaDat + ZAHLKOND->Tage
  //
  // // 0 Tage Zahlungsziel heist bar oder Vorkasse, ist also bezahlt
  // // if ZAHLKOND->Tage == 0
  // // replace RECHAUS->Bezahlt with RECHAUS->ReaDat
  // // endif
  //
  // // 2. Fall: Folgemonat und absoluter Tag angegeben.
  // else
  // month = month(RECHAUS->ReaDat) + ZAHLKOND->Monate
  // year = year(RECHAUS->ReaDat)
  // // n�chstes Jahr?
  // if month > 12
  // month:=month - 12
  // year++
  // endif
  // mahnDat:=right( "0"+alltrim(str(ZAHLKOND->Tage,2)) , 2) + "." +; // Tag
  // right( "0"+alltrim(str(month,2)) , 2) + "." + str(year,4) // Monat + Jahr
  // replace RECHAUS->Faellig with ctod( mahnDat )
  // endif
  //
  replace RECHAUS->Faellig with getDueDate(RECHAUS->ReaDat)

  // Skto-F�lligkeit
  if empty( ZAHLKOND->SktoMonate )
    replace RECHAUS->SktoFaell with RECHAUS->ReaDat + ZAHLKOND->SktoTage

    // 0 Tage Zahlungsziel heist bar oder Vorkasse, ist also bezahlt
    // if ZAHLKOND->SktoTage == 0
    // replace RECHAUS->Bezahlt with RECHAUS->ReaDat
    // endif

    // 2. Fall: Folgemonat und absoluter Tag angegeben.
  else
    if month( RECHAUS->ReaDat ) < 12
      mahnDat:=right( "0"+alltrim(str(ZAHLKOND->SktoTage,2)) , 2) + "." +; // Tag
      right( "0"+alltrim(str(month(RECHAUS->ReaDat) + ZAHLKOND->SktoMonate,2)) , 2) + "." + ;// Monat
      str(year(RECHAUS->ReaDat),4) // Jahr
    else
      mahnDat:=right( "0"+alltrim(str(ZAHLKOND->SktoTage,2)) , 2) + "." +; // Tag
      right( "0"+alltrim(str(0 + ZAHLKOND->SktoMonate,2)) , 2) + "." + ;// Monat
      "01."+ ; // Monat
      str(year(RECHAUS->ReaDat) + 1 , 4) // Jahr
    endif
    replace RECHAUS->SktoFaell with ctod( mahnDat )
  endif

  // setzte Mahnstufe auf 1 falls f�llig
  if RECHAUS->Faellig <= getUser():date .and. RECHAUS->Mahnstufe == 0 .and. RECHAUS->Brutto > 0
    replace RECHAUS->Mahnstufe with 1
  elseif RECHAUS->Faellig > getUser():date .and. RECHAUS->Mahnstufe > 0
    replace RECHAUS->Mahnstufe with 0
  endif

return RECHAUS->Mahnstufe
/** eof */

/** erh�ht die Mahnstufe von 0 auf 1 bei allen f�lligen Rechnungen */
PROCEDURE setAllDuedates()
  cls
  Titel("Mahnstufen werden berechnet.")
  if open( {"RechAus",.t.} , "Zahlkond" )
    select Rechaus
    go top
    do while ! RECHAUS->(eof())
      setDuedate()
      skip
    enddo
    dbcommitall()
  endif
  close data
return
/** eop */

/** schaltet den Index beim Zahlungseingang um */
  // Hinweis: einfaches umschalten zw. temp. Index ging auf Anhieb nicht?!
// deshalb werden die Indices neu erstellt
function toggleZahlIndex()
  if RECHAUS->(indexOrd()) == ordNumber( TEMP_INDEX )
    RECHAUS->(ordSetFocus( ordNumber( TEMP_IND2 ) ) ) // alle offenen
  else
    // index on RECHAUS->RechNr tag TEMP_INDEX TEMPORARY ADDITIVE ; // alle
    // for RECHAUS->Brutto > 0 .and. empty( RECHAUS->STORNO_NR )
    RECHAUS->(ordSetFocus( ordNumber( TEMP_INDEX ) ) ) // alle auch bezahlte anzeigen
  endif
  keyboard( chr(K_END) ) // gehe ans Ende
return .t.
/** eof */

/** Liefert das F�lligkeitsdatum zum �bergebenen Datum und dem aktuellen Satz in ZAHLKOND. */
Function getDueDate(datum)
LOCAL result
LOCAL month
LOCAL year
LOCAL mahnDat
  // 1. Fall: nur Tage des F�lligkeitszeitraums eingegeben
  if empty( ZAHLKOND->Monate )
    result:=datum + ZAHLKOND->Tage

    // 0 Tage Zahlungsziel heist bar oder Vorkasse, ist also bezahlt
    // if ZAHLKOND->Tage == 0
    // replace RECHAUS->Bezahlt with datum
    // endif

    // 2. Fall: Folgemonat und absoluter Tag angegeben.
  else
    month = month(datum) + ZAHLKOND->Monate
    year = year(datum)
    // n�chstes Jahr?
    if month > 12
      month:=month - 12
      year++
    endif
    mahnDat:=right( "0"+alltrim(str(ZAHLKOND->Tage,2)) , 2) + "." +; // Tag
    right( "0"+alltrim(str(month,2)) , 2) + "." + str(year,4) // Monat + Jahr
    result:=ctod( mahnDat )
  endif

return result
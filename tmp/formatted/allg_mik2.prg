/* modul: Allg_Miki2.prg
*
* enth�lt alle globalen, Miki-spez. Proceduren
*/

#include "Miki.ch"


/*
* erfassen und anzeigen der Kontaktdaten je Kunde
*/
FUNCTION KundKontakt()
LOCAL GetList:={}
LOCAL aFelder:={}
LOCAL aSpalte[EDIT_FELD_MAX]
LOCAL aKopf[EDIT_KOPF_MAX]

  Umgebung(WRITE_ALL)

  if ! open("KdKontakt","Kunden","KdKontTemp")
    Error(TRY_AGAIN)
    Umgebung(LOAD)
    RETURN("")
  endif

  select KdKontTemp
  zap

  /* hole alle Speditionen des Kundens */
  select KdKontakt
  KDKONTAKT->(dbseek(KUNDEN->KundNr))
  select KdKontTemp
  do while ! KDKONTAKT->(eof()) .and. KDKONTAKT->KundNr == KUNDEN->KundNr
    add_rec(0)
    overwrite( "KdKontakt" )
    KDKONTAKT->(dbskip())
  enddo

  aFelder:={}
  /* Kopf-Definitionen */
  aKopf[EDIT_START_Y]:=7 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_ENDE_Y]:=-2 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_LM]:=4 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_RM]:=76 // N: Begin des Eingabe-Berreiches BS
  aKopf[EDIT_MODUS]:=2 // N: 1=immer �ndern, 2=Wahl-Modus
  aKopf[EDIT_LINES]:=4 // N: Anzahl Zeilen pro Zeile
  aKopf[EDIT_GESPERRT]:="Z"

  aKopf[EDIT_DRAW_FRAME]:="Kunde - Ansprechpartner"
  aKopf[EDIT_NEW_FKT]:={ || _FIELD->KDKONTTEMP->KundNr:=KUNDEN->KundNr }

  /* Feld-Definitionen */
  aSpalte:=e_fill() // initialisieren
  aSpalte[EDIT_NAME]:="Ansprech"
  aSpalte[EDIT_TITEL]:="Ansprechpartner"
  aSpalte[EDIT_MESSAGE]:="Ansprechpartner eingeben.              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Email:  '"
  aSpalte[EDIT_EDIT]:=.f.

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Telefon:'"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=1

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="'Fax:    '"
  aSpalte[EDIT_EDIT]:=.f.
  aSpalte[EDIT_POS_Y]:=2

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Email"
  aSpalte[EDIT_TITEL]:=""
  aSpalte[EDIT_MASKE]:="@S26"
  aSpalte[EDIT_AFTER]:={ |oGet| isValidEmail(oget) }
  aSpalte[EDIT_MESSAGE]:="Email-Adresse Ansprechpartner eingeben.              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Telefon"
  aSpalte[EDIT_POS_Y]:=1
  aSpalte[EDIT_MESSAGE]:="Telefonnummer Ansprechpartner eingeben.              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  aSpalte[EDIT_NAME]:="Fax"
  aSpalte[EDIT_POS_Y]:=2
  aSpalte[EDIT_MESSAGE]:="Fax-Nummer Ansprechpartner eingeben.              @ESC@=Ende"

  aadd(aFelder,aclone(aSpalte)) // neues Feld hinzuf�gen
  aSpalte:=e_fill() // initialisieren

  Edit(aFelder,aKopf)

  // r�ckschreiben nach SpedKund
  if aKopf[EDIT_CHANGED]
    select KdKontakt
    KDKONTAKT->(dbseek(KUNDEN->KundNr))
    do while ! KDKONTAKT->(eof()) .and. KDKONTAKT->KundNr == KUNDEN->KundNr
      rec_lock(0)
      delete
      skip
    enddo

    // h�nge neu an
    KDKONTTEMP->(dbgotop())
    append("KDKONTTEMP",{ || .t. })
    dbcommitall()
    dbunlockall()
  endif

  Umgebung(LOAD)

RETURN .t.
/* eof */


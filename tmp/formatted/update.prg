/**
* enthält alles zum update von Dateien etc.
*/

/** Aktuelle Version */
#define CURRENT_VERSION "705"
#include "Miki.ch"

#include "dbstruct.ch"
#include "Directry.ch"

/** returns the num value of the currently installed version */
function getCurrentVersion()
return val(CURRENT_VERSION)
/** eof */


/** F�hrt alle automat. Updates, Datei-Struktur-Änderungen etc. durch
 */
Procedure installUpdate(thisVersion)
LOCAL newFields:={},removeFields:={},fehler:=.f.,i
LOCAL getList:={},pass:=space(5)
LOCAL tempArray:={},tempVal,datei,tempText,mArtnr
LOCAL text,count,zeile:=0, temp
LOCAL aDatei,aStruct,Anz,Feld
LOCAL Temp_Datei:=TEMP+"\temp"+getUser():getLongID()
LOCAL aFiles, aFile, tempNr, fileName
LOCAL oExcel, oAS
LOCAL diff, mat, menge, aktRec, dir
LOCAL aFields, info, field, summe, temp2, printBuffer, stueckliste


  ignore i,tempVal,datei,text,count,aDatei,aStruct,anz,feld,tempText, oExcel, oAS, temp, mArtNr
  ignore aFiles,aFile, tempNr, filename, diff, mat, menge, aktRec, dir
  ignore aFields, info, field, summe, temp2, printBuffer, stueckliste

  // prevent other users from logging in
  if getUser():id<>SERVER_LOGIN
    if ! mylogin(SERVER_LOGIN) // Systemparameter setzten, Auto Login als Server
      TroubleEmail("Server could not logon")
      quit
    endif
  endif
  set alte to NO_LOGIN_FILE
  set alte on
  close alte

  if AT_HOME
    pass:="JOJO "
  endif

  cls
  Titel("ACHTUNG: Update - Systemmanager ONLY")

  @ 10,20 say "Update auf Version : "+alltrim(str(SYSTEM->Version,5)+"->"+CURRENT_VERSION)
  @ 12,20 say "Passwort           :" get Pass picture "@!"
  read
  if ABBRUCH .or. encrypt(trim(pass))<>MASTER_PASS
    ferase(NO_LOGIN_FILE)
    down()
  endif

  trouble("Update",{"Update auf Version : "+alltrim(str(SYSTEM->Version,5)+"->"+CURRENT_VERSION)})

  // erzeuge User Temp Verzeichnis
  mkMyDir(TEMP+BACKSLASH+getUser():id)

  /**** Version 700, am 8.1.25
  *
  * Index1 -> Index
  */
  if bumpVersionTo(thisVersion,700)
    DeleteCDXRecursive(".\DAT"+BACKSLASH)
    reorg(.f.) // ohne Abfrage !
  endif

  /**** Version 701, am 28.7.25
  *
  * Fix Klager Bestand, s. Konsistenzcheck vom 28.7.25
  */
  if bumpVersionTo(thisVersion,701)

    if ! open({"Artikel", .t.}, "Waraus")
      Error(TRY_AGAIN)
      close data
      return
    endif

    tempArray:={;
      {"5063100", 6}, ;
      {"5063150", 12}, ;
      {"5063600", 196}, ;
      {"5063655", 327} ;
      }

    select Artikel
    for each temp in tempArray
      ARTIKEL->(dbseek(temp[1]))
      aendArtKBest(temp[2]-ARTIKEL->KonsigBest,"K-Lager Korrektur Fehllieferung")
    next

    close data
  endif

  /**** Version 702, am 29.7.25
  *
  * Betriebsferien
  *
  */
  if bumpVersionTo(thisVersion,702)

    backup( "System" )

    if open( {"System",.t.})
      replace SYSTEM->Holidays with "32/25,33/25,52/25,01/26"
    endif

    close data
  endif


  /**** Version 703, am 4.8.25
  *
  * Kunden mit KZ f�r VersicherungsListe Forderungsausfall
  */
  if bumpVersionTo(thisVersion,703)

    for each tempVal in {"Kunden"}
      newFields:={}
      aadd(newFields,getField("AusfVers","C", 1, 0 ))
      fehler:=!addDBFields(tempVal,newFields)
    next
    close data
  endif

  /**** Version 704, am 21.10.25
  *
  * AB mit Hinweis auf Angebot
  */
  if bumpVersionTo(thisVersion,704)

    for each tempVal in {"Aufaus"}
      newFields:={}
      aadd(newFields,getField("AngNr","C", 5, 0 ))
      fehler:=!addDBFields(tempVal,newFields)
    next
    close data
  endif

  /**** Version 705, am 17.11.25
  *
  * Kunde mit Anlieferungszeit
  */
  if bumpVersionTo(thisVersion,705)

    for each tempVal in {"Kunden"}
      newFields:={}
      aadd(newFields,getField("Anlief","M", 10, 0 ))
      fehler:=!addDBFields(tempVal,newFields)
    next
    close data
  endif

  // ------------------------------
  close data
  commitCurrentVersion()

return
/** eop */


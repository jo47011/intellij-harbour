
/* Modul: DateiDef.prg
*
* enth�lt alle def. Dateien
*
*
*  WICHTIG: beim hinzuf�gen/l�schen von Dateien unbedingt #define ALLE_DATEIEN anpassen
*
*           mod_date nicht im Index verwenden, springt sonst beim l�schen,
*           da vorher in rec_lock() das mod_date wieder ge�ndert wird!
*/

#include "miki.ch"
#include "Directry.ch"

/* folgende Dateien gibt es */
#define ALLE_DATEIEN SYSTEM_DATEIN,MIKI_DATEIEN

#define MIKI_DATEIEN "Artikel","AvPost", "Etikett" , "Artreserv" ,"Vers_Eti","EtiStru","Einheit",;
  "BesAus","BesPost","Inner" ,"AufAus","AufPost","AvAus" ,"Maschine" ,"MaschGr","Text" ,"Manuell",;
  "ManBeist","Mat_Man" ,"Ersatz" ,"Bestell","MwSt_KZ","Text_Kz","ZahlKond","VersArt" ,"Waraus",;
  "Lieferan","BestPlan","WarenEin","Kunden","KundSped","KdSpedTemp","KdKontakt","KdKontTemp" ,;
  "Rabatt","Verkauf","Erl_Grup","LiefTerm","Instrukt" ,"RechPost","RechAus","Auftrag","Kd_Bemer" ,;
  "Mat_t","Zeit_t","Ins_t","Werk_t","MatEing" ,"KostenSt","MatAusg","HonAusg","KstStamm" ,;
  "RepAus","RepFehl","Standort","RepStamm","Gerat","Kosten" ,"Prod","GeratErf","GeratProd",;
  "Empfaeng","Etisam","RepKund","Versand","Personal" ,"FehErf","ZeitErf","Summen","FremdEin",;
  "LiefPlan","GruppSum" ,"M_Mehrf","X_mehrf","BestKart","Werbung" ,"Spedit","AngAus","AngPost",;
  "Status","LetzteNi","Beistemp" ,"Mehrfach","MehrTemp","Mat_Kz","EtiRepa" ,"BankStam","Hausbank",;
  "ZahlAus","Scheck","Scheck_T","Ueber_T" ,"MatList","Konsig","Honselda","Beistell","DLEmail" ,;
  "KFremdEi","HonselVK","ArtPreis","Aufruf","Land","AufZeit" ,"LiefAus","LiefPost","LiefTemp",;
  "InnAB","InnMiki","InnStk","InnEdit","AvSortNr" ,"LetzteSt","Grund","IntraStat","Email",;
  "EmailTemp","Paletten","Abhol","Abruf" ,"SammelBest","SammelTemp","LagerOrt","ZollStelle",;
  "KundZoll", "KdZollTemp","ArtMinOrd" ,"NKPost","NKErf","NkArtikel","NkMehrf", "NKZeit","NkMail",;
  "ProdText","ArtText" ,"TODO","ARTPRGR","Farbe"

/** returns an array with an default db_info array */
function getEmptyDBDescription(Datei)
LOCAL aDatei[INFO_LAENGE]
  aFill(aDatei,NIL) // initialisieren

  /* setze Default-Werte */
  aDatei[D_NAME]:=upper(Datei)
  aDatei[D_ART ]:="Z" // Z nur Gro�-Buchstaben
  aDatei[D_TEMP]:=.f. // nicht als temp. Datei
  aDatei[D_TEMP_STATIC]:=.f. // wenn temp. dann 1x je Login
  aDatei[D_TEMP_ERASE]:=.t. // l�sche temp. Datei bei Prog.Ende
  // aDatei[D_TEMP_STRU] nicht vordefiniert !
  aDatei[D_TOGGLE_INDEX]:=.f. // kein Umschalten der Indices bei Hilfe
  aDatei[D_REC_EMPTY]:={|| .f.} // Datensatz ist per defaultnicht leer (interner Wert)
return aDatei
/** eof */

/*
* gibt Infos �ber benutzte Dateien
*
* Datei-Definitionen
*
* leider: muss jede Datei noch in alle_Dateien aufgelistet werden (s.o.)!
*
* Paramater Datei:   String     - DateiName
*
*
  //  aDatei[D_ART ]:="Z"             // Z    nur Gro�-Buchstaben
  // Y    nur Gro�-Buchstaben, keine Nummern !
  // S    nach rechts geshiftet mit Shift-Char
  // N    num. 1. Index-Feld, f�hrende Nullen
  // R    num. 1. Index-Feld, Nullen hinten
  // X    alle Eingaben m�glich
  // A    Artikel: Nach rechts geshiftet mit Shift-Char,falls<6 Stellen
  // K    Kunden : 5 Stellen - 2 Stellen (numerisch)
  // H    Rep.Kunden : (Honsel) siehe miki.ch:  RepKdnr_pict
  // Y    WerbeTexte nur Buchstaben keine Ziffern
*/
FUNCTION db_Info(Datei)
LOCAL aDatei[INFO_LAENGE]

  Datei:=upper(alltrim(Datei))

  aDatei:=getEmptyDBDescription(Datei) // initialisieren
  adatei[D_NEW_REC_ALLOWED]:={|| getUser():mayEditData}

  do case
  case Datei=="ARTIKEL"
    /* Artikel */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Artikel"
    aDatei[D_DISP]:="ArtDisp"
    aDatei[D_IND1]:="ARTIKEL->ArtNr"
    aDatei[D_IND2]:="if(empty(left(ARTIKEL->HArtNr,8)),chr(255)+substr(ARTIKEL->HartNr,2),ARTIKEL->HartNr)"
    aDatei[D_IND3]:="ARTIKEL->MatArtNr"
    aDatei[D_ART ]:="A" // Artikel-Eingabe

    aDatei[D_NEW_REC_CODEBLOCK]:={ || ArtNeuSatz() }
    adatei[D_NEW_REC_ALLOWED]:={|| getUser():mayCreateArticles .or. getUser():mayEditTool }
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }
    aDatei[D_ALT_SEARCH]:={ |nr| ARTIKEL->AltArtNr==nr }
    aDatei[D_NO_COPY_FIELDS]:={"INVBESTAND","LAGEBEST","BESTEXT","BESTINT","DISPONIERT","VERKAUFT",;
      "PREIS1","SOLL_VK","ZUSCHL_S","HARTNR","LAGERORT","WKZ","INHALT","FORMRAHMEN","PRGR",;
      "SCHLUESSEL","INV_KZ","NUTZEN","MINDBEST","MINORDERI","GEWICHT","SPEZ_GEW","MASSE","WKZ_KALK",;
      "EKPR","KAPR","KONSIGBEST","KONSIGMIND","KONSIGMAX","KONSIGINV","EIGNER","KONSIGKDNR","ALTARTNR",;
      "ME2","ME_FAKTOR","LG_RAUM","LG_REGAL","LG_FACH","LG_TEXT","MINPUFFER","MINBESTI","MINBESTS"}
    if getUser():mayEditData
      aadd(aDatei[D_NO_COPY_FIELDS],"ART")
    endif

  case Datei=="AVAUS"
    /* St�cklisten Kopfdatei */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�ckliste"
    aDatei[D_IND1]:="AVAUS->AvNr"
    aDatei[D_ART ]:="A" // Artikel-Eingabe
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }

  case Datei=="AVPOST"
    /* Posten St�ckListe */
    /** Art: M = Material, W = Werkzeug, V = Zeit */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�cklisten-Posten"
    aDatei[D_IND1]:="AVPOST->AvNr+AVPOST->Art+AVPOST->Pos"
    aDatei[D_IND2]:="AVPOST->ArtNr+AVPOST->AvNr"

  case Datei=="EINHEIT"
    /* MengenEinh  */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KEY ]:="ME"
    aDatei[D_KURZ]:="Mengeneinheit"
    aDatei[D_DISP]:="EinDisp"
    aDatei[D_IND1]:="EINHEIT->ME"
    aDatei[D_ART ]:="N"

  case Datei=="KUNDEN"
    /* MengenEinh  */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunde"
    aDatei[D_DISP]:="KunDisp"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_IND1]:="KUNDEN->KundNr"
    aDatei[D_IND2]:="KUNDEN->KurzName"
    aDatei[D_ART]:="K" // Kunden-Eingabe
    aDatei[D_REC_EMPTY]:={|feld| feld==KDNR_LEER }
    aDatei[D_NO_COPY_FIELDS]:={"IBAN","IDENTNR"}
    aDatei[D_NEW_REC_CODEBLOCK]:={ || _FIELD->Re_Anz:=getProperty("Miki.kunden.rechn.anzahl","4"),;
      _FIELD->Sprache:=DEUTSCH,_FIELD->Sprache2:=DEUTSCH,_FIELD->S_Sprache:=DEUTSCH }
    aDatei[D_DELETE_CASCADE]:={"Email","KundSped"}

  case Datei=="KDKONTAKT"
    /* Reparturen: Kontaktdaten pro Kunde */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-Kontakt"
    aDatei[D_IND1]:="KDKONTAKT->KundNr"

  case Datei=="KDKONTTEMP"
    /* temp. Datei f�r Kontakte je Kunde */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-Kontakt"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="KdKontakt" // wird hier als Struktur genommen !

  case Datei=="KUNDSPED"
    /* MengenEinh  */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-Spedition"
    aDatei[D_IND1]:="KUNDSPED->KundNr"
    aDatei[D_IND2]:="KUNDSPED->KundNr+KUNDSPED->SpedNr"

  case Datei=="KDSPEDTEMP"
    /* temp. Datei f�r Speditionen je Kunde */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-Spedition"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="KundSped" // wird hier als Struktur genommen !

  case Datei=="BESAUS"
    /* Bestellungen Kopf-Datei */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Bestellung"
    aDatei[D_IND1]:="BESAUS->BestNr"
    aDatei[D_IND2]:="BESAUS->Kurzname+BESAUS->BestNr"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe

  case Datei=="BESPOST"
    /* Bestellungen Bauch-Datei */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Bestellung"
    aDatei[D_IND1]:="BESPOST->BestNr" // alt:BesPost
    aDatei[D_IND2]:="BESPOST->ArtNr+BESPOST->BestNr" // alt:BesArt
    aDatei[D_IND3]:="BESPOST->ArtNr+BESPOST->LiefNr+mydescend(BESPOST->AufDat)"
    aDatei[D_IND4]:="BESPOST->BesPostNr"
    // ACHTUNG BESAUS->erledigt<>"J" fehlt hier extra
    aDatei[D_IND5]:={"BESPOST->ArtNr+kwindex(BESPOST->Kw)","BESPOST->Menge > BESPOST->GeliefGes .and. !'X'$upper(BESPOST->kw) .and. !'*'$BESPOST->kw"}

  case Datei=="INNER"
    /* Innerbetr. Auftr�ge */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Innerbetr. Auftrag"
    aDatei[D_KEY ]:="InLfdNr"
    aDatei[D_IND1]:={"INNER->InnerNr" ,"INNER->Erledigt<>'J' .and. isInnerHauptArbeitsgang()"}
    aDatei[D_IND2]:={"INNER->ArtNr+INNER->InnerNr","INNER->Erledigt<>'J' .and. isInnerHauptArbeitsgang()"}
    aDatei[D_IND3]:="INNER->InlfdNr"
    aDatei[D_IND4]:={"INNER->AufNr","INNER->Erledigt<>'J' .and. isInnerHauptArbeitsgang()"}
    aDatei[D_IND5]:="str(INNER->AbPostnr,8)+INNER->ArtNr"
    aDatei[D_IND6]:="INNER->NKNr"
    aDatei[D_IND7]:={"INNER->InnerNr+INNER->ArbGang" ,"INNER->Erledigt<>'J'"}
    aDatei[D_DISP]:="InnDisp"
    aDatei[D_NEW_REC_ALLOWED]:={|| .f. } // Benutzer darf selbst keine anlegen
    aDatei[D_ART ]:="A" // unsch�n, aber nur so nimmt er den D_NEW_REC_SHIFT cb (FIXME)
    aDatei[D_NEW_REC_SHIFT]:={ |s| strShift(s) }

  case Datei=="AUFAUS"
    /* Auftr�ge Kopf-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Auftrag"
    aDatei[D_IND1]:="AUFAUS->AufNr"
    aDatei[D_IND2]:="upper(AUFAUS->Kurzname)+AUFAUS->AufNr"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_ART ]:="S" // Shiften des 1. Index

  case Datei=="LIEFAUS"
    /* Auftr�ge Kopf-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Lieferschein"
    aDatei[D_IND1]:="LIEFAUS->LsNr"
    aDatei[D_IND2]:="upper(LIEFAUS->Kurzname)+LIEFAUS->LSNr"
    aDatei[D_IND3]:="LIEFAUS->AufNr"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_ART ]:="S" // Shiften des 1. Index

  case Datei=="ANGAUS"
    /* Angebote Kopf-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Angebot"
    aDatei[D_IND1]:="ANGAUS->AngNr"
    aDatei[D_IND2]:="ANGAUS->Kurzname+ANGAUS->AngNr"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_ART ]:="S" // Shiften des 1. Index

  case Datei=="ANGAUS"
    /* Angebote Kopf-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Angebot"
    aDatei[D_IND1]:="ANGAUS->AngNr"
    aDatei[D_IND2]:="ANGAUS->Kurzname+ANGAUS->AngNr"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_ART ]:="S" // Shiften des 1. Index

    // case Datei=="MATSUM"
    // /* zum summieren von Material */
    // aDatei[D_PFAD]:=FAKT
    // aDatei[D_KURZ]:="Material Summe"
    // aDatei[D_IND1]:="MATSUM->ArtNr"
    // aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="NKARTIKEL"
    /* NachKalkulations-Kopf-Datei / Artikel/Material */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Nachkalkulation"
    aDatei[D_IND1]:="NKARTIKEL->NKNr+NKARTIKEL->ArtNr"

  case Datei=="NKMEHRF"
    /* NachKalkulations-Kopf-Datei */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Nachkalkulation Mehrfachnutzen"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="NkArtikel" // wird hier als Struktur genommen !

  case Datei=="NKPOST"
    /* NachKalkulations-Datei */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Nachkalkulation"
    aDatei[D_IND1]:="NKPOST->NkNr"
    aDatei[D_IND2]:="NKPOST->NkNr+str(NKPOST->lfdNr,3)"

  case Datei=="NKERF"
    /* NachKalkulations-Datei */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Nachkalkulation"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="NkPost" // wird hier als Struktur genommen !

  case Datei=="NKZEIT"
    /* Datei zum erfassen der Zeit bei Nachkalkulation */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="NK-Zeiten"
    aDatei[D_IND1]:="NKZEIT->NKNr+str(NKZEIT->lfdNr,3)"

  case Datei=="NKMAIL"
    /* NachKalkulations-Email Notifikationen */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Nachkalkulation-Email"
    aDatei[D_IND1]:="NKMAIL->InlfdNr"

  case Datei=="MAT_T"
    /* temp. Posten St�ckListe: Material */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�cklisten-Posten: Material"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="AVpost" // wird hier als Struktur genommen !

  case Datei=="ZEIT_T"
    /* temp. Posten St�ckListe: Material */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�cklisten-Posten: Zeit"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="AVpost" // wird hier als Struktur genommen !

  case Datei=="WERK_T"
    /* temp. Posten St�ckListe: Werkzeug */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�cklisten-Posten: Werkzeug"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="AVpost" // wird hier als Struktur genommen !

  case Datei=="INS_T"
    /* temp. Posten St�ckListe: Instruktionen */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="St�cklisten-Posten: Instruktionen"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Instrukt" // wird hier als Struktur genommen !

  case Datei=="ARTRESERV"
    /* Artikel reserviert */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Reservierte Artikel"
    aDatei[D_IND1]:="ARTRESERV->ArtNr+str(ARTRESERV->AbPostNr,8)"
    aDatei[D_IND2]:="str(ARTRESERV->AbPostNr,8)+str(ARTRESERV->Tiefe,4)"
    aDatei[D_IND3]:="ARTRESERV->AlternZu+ARTRESERV->ArtNr"

  CASE DATEI=="REPAUS"
    /* Kopfdaten reparturen */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Kopfdaten-Reparturen"
    aDatei[D_ART ]:="N"
    aDatei[D_IND1]:="REPAUS->Belegnr"
    aDatei[D_IND2]:={ "REPAUS->Typ+REPAUS->Geratnr+REPAUS->BelegNr",D_DESCENDING}
    aDatei[D_IND3]:="REPAUS->Dr_STat+REPAUS->Stand_Rech+REPAUS->Berechnet+REPAUS->Belegnr"

  CASE DATEI=="STANDORT"
    /* Standort */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Standort"
    aDatei[D_DISP]:="StaDisp"
    aDatei[D_ART ]:="N"
    aDatei[D_IND1]:="STANDORT->StandNr"

  case Datei=="REPFEHL"
    /* Posten Reparturen, Fehler */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Repartur-Posten"
    aDatei[D_IND1]:="REPFEHL->BelegNr"
    aDatei[D_IND2]:="REPFEHL->Nummer"
    aDatei[D_ART ]:="N"

  case Datei=="FEHERF"
    /* temp. Datei zum Erfassen der Posten Reparturen */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Repartur-Posten"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="RepFehl" // wird hier als Struktur genommen !


  case Datei=="REPSTAMM"
    /* Reparturen: Beschreibungen Fehler/Ursache */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Nummer"
    aDatei[D_DISP]:="RStDisp"
    aDatei[D_IND1]:="REPSTAMM->RepStNr"
    aDatei[D_ART ]:="N"

  case Datei=="PRODTEXT"
    /* Texte je Geraet */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Ger�t-Texte"
    aDatei[D_DISP]:="PTeDisp"
    aDatei[D_IND1]:="PRODTEXT->ProdTextNr"
    aDatei[D_ART ]:="N"

  case Datei=="ARTTEXT"
    /* Texte je Artikel */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Artikel-Texte"
    aDatei[D_DISP]:="AteDisp"
    aDatei[D_IND1]:="ARTTEXT->ArtTextNr"
    aDatei[D_ART ]:="N"

  case Datei=="KD_BEMER"
    /* Reparturen: Bemerkung von Kunde bzgl. Ger�t */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Bemerkung"
    aDatei[D_DISP]:="KdBDisp"
    aDatei[D_IND1]:="KD_BEMER->KD_Bem_Nr"
    aDatei[D_ART ]:="N"

  case Datei=="BEURTEIL"
    /* Reparturen: Beurteilung */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Beurteilung"
    aDatei[D_DISP]:="BTeDisp"
    aDatei[D_IND1]:="BEURTEIL->BemerkNr"
    aDatei[D_ART ]:="N"

  case Datei=="VERSAND"
    /* Reparturen: Beschreibungen Fehler/Ursache */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Versand-Nummer"
    aDatei[D_DISP]:="RVsDisp"
    aDatei[D_IND1]:="VERSAND->RepVerNr"
    aDatei[D_ART ]:="N"

  case Datei=="SPEDIT"
    /* Fakt: Spedition */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Spediteur"
    aDatei[D_DISP]:="SpeDisp"
    aDatei[D_IND1]:="SPEDIT->SpedNr"
    aDatei[D_IND2]:="upper(SPEDIT->Name)"
    aDatei[D_ART ]:="N"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_DELETE_CASCADE]:={"KundSped"}

  case Datei=="EMAIL"
    /* Fakt: Spedition */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Email-Adresse"
    aDatei[D_DISP]:="EMailDisp"
    aDatei[D_IND1]:="EMAIL->KundNr+EMAIL->Art"
    aDatei[D_ART]:="K" // Kunden-Eingabe

  case Datei=="EMAILTEMP"
    /* temp. Email-Karte, Preise & Rabatte der Lieferanten je Artikel */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Email-Adresse"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="EMail" // wird hier als Struktur genommen !

  case Datei=="AVSORTNR"
    /* Fakt: sortierreihenfolge der Artikel in der Arbeitsvorbereitung */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Sort.Reihenfolge"
    aDatei[D_DISP]:="AvSDisp"
    aDatei[D_IND1]:="AVSORTNR->Reihenfolg"
    aDatei[D_ART ]:="A" // unsch�n, aber nur so nimmt er den D_NEW_REC_SHIFT cb (FIXME)
    aDatei[D_NEW_REC_SHIFT]:={ |s| strShift(s) }

  case Datei=="MEHRFACH"
    /* AV: MehrfachSpritzungen */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Mehrfachspritzung"
    aDatei[D_IND1]:="MEHRFACH->ArtNr" // Werkzeug
    aDatei[D_IND2]:="MEHRFACH->ANr+MEHRFACH->ArtNr+MEHRFACH->Gruppe" // ArtNr + Werkzeug
    aDatei[D_ART ]:="A"
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }

  case Datei=="MEHRTEMP"
    /* AV: MehrfachSpritzungen , temp.Datei */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Mehrfachspritzung"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Mehrfach" // wird hier als Struktur genommen !

  case Datei=="REPKUND"
    /* Rep. Kunden */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Rep.Kunden"
    aDatei[D_DISP]:="RKdDisp"
    aDatei[D_IND1]:="REPKUND->RepKdNr"
    aDatei[D_IND2]:="REPKUND->Kurz"
    aDatei[D_ART ]:="H"
    aDatei[D_REC_EMPTY]:={|feld| feld==REPKDNR_LEER }
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe

  case Datei=="GERAT"
    /* Ger�te */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Ger�te-Typ"
    aDatei[D_DISP]:="GerDisp"
    aDatei[D_IND1]:="GERAT->RepGerNr"
    aDatei[D_ART ]:="N"

  case Datei=="KOSTEN"
    /* Reparatur-Kosten */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Reparatur-Kosten"
    aDatei[D_DISP]:="KosDisp"
    aDatei[D_IND1]:="KOSTEN->RepKstNr"

  case Datei=="PROD"
    /* Ger�te produziert */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="produziertes Ger�t"
    aDatei[D_DISP]:="ProDisp"
    aDatei[D_IND1]:="PROD->Typ+PROD->GeratNr"
    aDatei[D_IND2]:="PROD->RepKdNr+PROD->Typ+PROD->GeratNr"
    aDatei[D_IND3]:="PROD->Empfaeng+PROD->Typ+PROD->GeratNr"
    aDatei[D_IND4]:={ "PROD->Typ+subRepArtikel(PROD->ArtNr)",D_UNIQUE }
    aDatei[D_IND5]:="subRepArtikel(PROD->ArtNr)+PROD->Typ+PROD->GeratNr"
    aDatei[D_ART ]:="N"
    aDatei[D_MEHRF_INDEX]:={ || Typ_Repa() } // Mehrfachindex bei Neuerfass. : Typ+GeratNr
    aDatei[D_NEW_REC_ALLOWED]:={|| .f. } // Benutzer darf selbst keine anlegen

  case Datei=="GERATPROD"
    /* Ger�te produziert */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="produziertes Niet-Ger�t"
    aDatei[D_IND1]:="GERATPROD->RepGerNr+GERATPROD->GerVon"
    aDatei[D_NEW_REC_ALLOWED]:={|| .f. } // Benutzer darf selbst keine anlegen

  case Datei=="GERATERF"
    /* Ger�te produziert */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="produziertes Niet-Ger�t"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="GERATPROD" // wird hier als Struktur genommen !

  case Datei=="EMPFAENG"
    /* Empf�nger */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Empf�nger"
    aDatei[D_ART ]:="Z"
    aDatei[D_DISP]:="EmpDisp"
    aDatei[D_IND1]:="EMPFAENG->EmpfNr"

  case Datei=="ETISAM"
    /* Etiketten-Sammel-Datei */
    aDatei[D_PFAD]:=ETI // (eigentl. repa)
    aDatei[D_KURZ]:="Etikett"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="AUFPOST"
    /* Auftr�ge Bauch-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Auftrag"
    aDatei[D_IND1]:="AUFPOST->AufNr"
    aDatei[D_IND2]:="AUFPOST->KundNr+AUFPOST->AufArt+AUFPOST->ArtNr+kwindex(AUFPOST->Kw)"
    aDatei[D_IND3]:="AUFPOST->AufNr+AUFPOST->ArtNr"
    aDatei[D_IND4]:="AUFPOST->ArtNr+AUFPOST->AufNr"
    aDatei[D_IND5]:="AUFPOST->ABPostNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="LIEFPOST"
    /* Auftr�ge Bauch-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Lieferschein"
    aDatei[D_IND1]:="LIEFPOST->LsNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="ANGPOST"
    /* Angebote Bauch-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Angebot"
    aDatei[D_IND1]:="ANGPOST->AngNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="RECHAUS"
    /* Rechnung Kopf-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Rechnung"
    aDatei[D_IND1]:="RECHAUS->RechNr"
    aDatei[D_IND2]:="RECHAUS->AufNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="RECHPOST"
    /* Rechnung Bauch-Datei , Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Rechnungsposten"
    aDatei[D_IND1]:="RECHPOST->RechNr"
    aDatei[D_IND2]:="RECHPOST->KundNr+RECHPOST->AufNr+RECHPOST->ArtNr+RECHPOST->RechNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="AUFTRAG"

    /* temp. Auftragsdatei, Menu */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Auftrag"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="AufPost" // wird hier als Struktur genommen !

  case Datei=="LIEFTEMP"

    /* temp. Datei zum Erfassen von Lieferscheinen */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Lieferschein"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="LiefPost" // wird hier als Struktur genommen !

  case Datei=="MASCHINE" // war bis 18.10.2012 Stunden.dbf!!!
    /* Zeiten f�r St�ckliste, Nacharbeiten */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Maschine"
    aDatei[D_DISP]:="MasDisp"
    aDatei[D_IND1]:="MASCHINE->StdNr"
    aDatei[D_ART ]:="N"
    aDatei[D_NEW_REC_CODEBLOCK]:={ || _FIELD->MASCHINE->HauptKZ:="H",;
      _FIELD->MASCHINE->MatBedarf:="J"}

  case Datei=="MASCHGR"
    /* Maschinen Gruppen */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Maschinen-Gruppe"
    aDatei[D_DISP]:="MgrDisp"
    aDatei[D_IND1]:="MASCHGR->MaschGr"
    aDatei[D_ART ]:="N"

  case Datei=="TEXT"
    /* Text f�r Av */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="AV-Text"
    aDatei[D_DISP]:="TexDisp"
    aDatei[D_IND1]:="TEXT->TextNr"
    aDatei[D_ART ]:="N"
    adatei[D_NEW_REC_ALLOWED]:={|| getUser():mayEditData .or. getUser():mayCreateInnerOrders}

  case Datei $ "INNAB" // war Auferfass.dbf
    /* zum Erfassen von internen Auftr�gen anhand von externen ABs */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Inner-Auftrag AB"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    // aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    aDatei[D_ALIAS]:="AufErfas" // wird als Alias gesetzt
    aDatei[D_TEMP_STRU]:="Inner"

  case Datei $ "INNEDIT" // war Auferfass.dbf
    /* zum Editieren von internen Auftr�gen anhand von externen ABs */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Inner-Auftrag Edit"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    // aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    aDatei[D_ALIAS]:="AufErfas" // wird als Alias gesetzt
    aDatei[D_TEMP_STRU]:="Inner"

  case Datei $ "INNMIKI" // war Auferfass.dbf
    /* zum Erfassen von internen Auftr�gen anhand von internen ABs */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Inner-Auftrag Miki"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    // aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    aDatei[D_ALIAS]:="AufErfas" // wird als Alias gesetzt
    aDatei[D_TEMP_STRU]:="Inner"

  case Datei $ "INNSTK" // war Auferfass.dbf
    /* zum Ausdrucken von St�cklisten */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Inner-Auftrag St�ckliste"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    // aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    aDatei[D_ALIAS]:="AufErfas" // wird als Alias gesetzt
    aDatei[D_TEMP_STRU]:="Inner"

  case Datei $ "MANUELL"
    /* zum manuellen erfassen von Material-Bedarf */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="Material"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. NICHT Datei bei Prog.Ende

  case Datei $ "MANBEIST"
    /* zum manuellen erfassen von Material-Bedarf */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="Material/Beist."
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. NICHT Datei bei Prog.Ende
    aDatei[D_TEMP_STRU]:="Manuell" // wird hier als Struktur genommen !

  case Datei $ "MATLIST"
    /* zum manuellen erfassen von Material-Bedarf */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="MaterialListe"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="MAT_MAN"
    /* temp. Datei zum Aufschl�sseln der Stk-Listen */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="Material"
    aDatei[D_IND1]:="MAT_MAN->ArtNr+kwIndex(MAT_MAN->Kw)"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="BESTELL"
    /* temp. Datei zum erfassen von Bestellungen */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Bestellung"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="BesPost" // wird hier als Struktur genommen !

  case Datei=="BESTPLAN"
    /* temp. Datei zur Bestell�berwachung */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Bestell�berwachung"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_IND1]:="kwIndex(BESTPLAN->KW)+BESTPLAN->Artnr"

  case Datei=="BESTKART"
    /* BestellKarte, Preise & Rabatte der Lieferanten je Artikel */
    aDatei[D_PFAD]:=BEST
    aDatei[D_ART ]:="N"
    aDatei[D_KURZ]:="Bestell-Karte"
    aDatei[D_IND1]:="BESTKART->ArtNr+BESTKART->LiefNr+mydescend(BESTKART->Datum)"
    aDatei[D_IND2]:="BESTKART->LiefNr+BESTKART->ArtNr+mydescend(BESTKART->Datum)"
    aDatei[D_IND3]:="BESTKART->BestNr+BESTKART->ArtNr"

  case Datei=="BESTTEMP"
    /* temp. BestellKarte, Preise & Rabatte der Lieferanten je Artikel */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Bestell-Karte"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="BestKart" // wird hier als Struktur genommen !

  case Datei=="SAMMELBEST"
    /* Sammelbestellung */
    aDatei[D_PFAD]:=BEST
    aDatei[D_ART ]:="N"
    aDatei[D_KURZ]:="Sammelbestellung"
    aDatei[D_IND1]:="SAMMELBEST->BestNr"

  case Datei=="SAMMELTEMP"
    /* temp. Sammelbestellung */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Sammelbestellung"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="SammelBest" // wird hier als Struktur genommen !

  case Datei=="ZAHLKOND"
    /* Zahlungs-Konditionen */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Zahlungskondition"
    aDatei[D_DISP]:="Zk_Disp"
    aDatei[D_IND1]:="ZAHLKOND->ZKNr"
    aDatei[D_ART ]:="N"

  case Datei=="VERSART"
    /* Versand-Arten */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Versand-Art"
    aDatei[D_ART ]:="N"
    aDatei[D_DISP]:="VA_Disp"
    aDatei[D_IND1]:="VERSART->VersNr"

  case Datei=="MWST_KZ"
    /* Mwst-KZ */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Mehrwertsteuer"
    aDatei[D_DISP]:="MwsDisp"
    aDatei[D_IND1]:="MWST_KZ->MWSTNr"
    aDatei[D_ART ]:="N"

  case Datei $ "MATEING"
    /* zum Erfassen von Material-Eingang */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Material-Eingang"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende

    // erst bei Druck !
  case Datei $ "FREMDEIN"
    /* zum Erfassen von Material-Eingang */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Fremd-Material-Eingang"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    // erst bei Druck !

  case Datei $ "KFREMDEI"
    /* zum Erfassen von Material-Eingang */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Fremd-Material-Eingang K-Lager"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    // erst bei Druck !

  case Datei $ "MATAUSG"
    /* zum Erfassen von Material-Ausgang MIKI */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Material-Ausgang Miki"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Mateing" // wird hier als Struktur genommen !
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    // erst bei Druck !

  case Datei $ "HONAUSG"
    /* zum Erfassen von Material-Ausgang Honsel*/
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Material-Ausgang Honsel"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Mateing" // wird hier als Struktur genommen !
    aDatei[D_TEMP_ERASE]:=.f. // l�sche temp. Datei NICHT bei Prog.Ende
    // erst bei Druck !

  case Datei $ "KOSTENST"
    /* Kosten-Stelle */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Kostenstelle"
    aDatei[D_IND1]:="KOSTENST->KostNr"
    aDatei[D_IND2]:="KOSTENST->KostNr+KOSTENST->ArtNr"
    aDatei[D_ART ]:="R"

  case Datei $ "KSTSTAMM"
    /* Kosten-Stelle */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Kostenstelle"
    aDatei[D_DISP]:="KstDisp"
    aDatei[D_IND1]:="KSTSTAMM->KostNr"
    aDatei[D_ART ]:="N"

  case Datei=="LIEFERAN"
    /* Lieferanten */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Lieferant"
    aDatei[D_DISP]:="LieDisp"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_IND1]:="LIEFERAN->LiefNr" // alt: Lieferan
    aDatei[D_IND2]:="LIEFERAN->Kurzname" // alt: LiefSchl
    aDatei[D_ART ]:="N"
    aDatei[D_NO_COPY_FIELDS]:={"EIBAN","PIBAN"}
    aDatei[D_DELETE_CASCADE]:={ {"BestKart",2} } // 2. INdex der Bestellkart

  case Datei=="WARAUS"
    /* Warenausgangs-buch */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Artikel"
    aDatei[D_IND1]:="WARAUS->ArtNr+dtos(WARAUS->Datum)"
    aDatei[D_IND2]:={"WARAUS->ArtNr+dtos(WARAUS->Datum)+str(WARAUS->(recno()),8)",D_DESCENDING}
    aDatei[D_IND3]:="WARAUS->InlfdNr+WARAUS->ArtNr"

  case Datei=="TEXT_KZ"
    /* Text-Kz ? */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Text"
    aDatei[D_DISP]:="WerDisp"
    aDatei[D_IND1]:="TEXT_KZ->TextKz_Nr"
    aDatei[D_ART ]:="Y"

  case Datei=="WARENEIN"
    /* temp. Datei zum erfassen von Wareneingangs-Kontrolle */
    aDatei[D_PFAD]:=BEST
    aDatei[D_KURZ]:="Wareneingang"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="AUFRUF"
    /* Potokoll aller Menü-Aufrufe */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Aufruf"
    aDatei[D_DISP]:="AfrDisp"
    aDatei[D_IND1]:="AUFRUF->ProgName+AUFRUF->ProgNr"
    aDatei[D_ART ]:="C"

  case Datei=="RABATT"
    /* Rabattgruppen */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Rabattgruppe"
    aDatei[D_DISP]:="RabDisp"
    aDatei[D_IND1]:="RABATT->Rabattgr"
    // aDatei[D_ART ]:="Z" ge�ndert am 22.3.2011, zur�ck wieder am 12.6.2012
    aDatei[D_ART ]:="N"

  case Datei=="VERKAUF"
    /* Verk�ufer */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Verk�ufer"
    aDatei[D_DISP]:="VK_Disp"
    aDatei[D_IND1]:="VERKAUF->VerkNr"
    aDatei[D_ART ]:="N"

  case Datei=="ERL_GRUP"
    /* EWrl�s-gruppen */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Erl�sgruppe"
    aDatei[D_DISP]:="ErlDisp"
    aDatei[D_IND1]:="ERL_GRUP->Erl_gruppe"
    aDatei[D_ART ]:="N"

  case Datei=="INSTRUKT"
    /* Instruktionen , AV */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Instruktionen"
    aDatei[D_IND1]:="INSTRUKT->AvNr"

  case Datei=="LIEFTERM"
    /* Liefertermine */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KEY ]:="KW"
    aDatei[D_KURZ]:="Liefertermin"
    aDatei[D_DISP]:="TerDisp"
    aDatei[D_IND1]:="LIEFTERM->KW"

  case Datei=="ZEITERF"
    /* Zeiterfassung Nachkalk. */
    aDatei[D_PFAD]:=AV
    aDatei[D_KURZ]:="Zeit"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="ETIREPA"
    /* Etikett Reparaturen , eigen-erfasst */
    aDatei[D_PFAD]:=ETI
    aDatei[D_KURZ]:="Etikett (Nietger�te)"
    aDatei[D_DISP]:="RepDisp"
    aDatei[D_IND1]:="ETIREPA->EtiRepaNr"
    aDatei[D_ART ]:="A" // Artikel-Eingabe
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }

  case Datei=="ETIKETT"
    /* Etikett , eigen-erfasst */
    aDatei[D_PFAD]:=ETI
    aDatei[D_KURZ]:="Etikett"
    aDatei[D_DISP]:="EtiDisp"
    aDatei[D_IND1]:="ETIKETT->EtikettNr"
    aDatei[D_ART ]:="N"

  case Datei=="VERS_ETI"
    /* Versand-Etiketten */
    aDatei[D_PFAD]:=ETI
    aDatei[D_KURZ]:="Etikett"
    aDatei[D_DISP]:="VerDisp"
    aDatei[D_IND1]:="VERS_ETI->VersandNr"


  case Datei=="ETISTRU"
    /* Etiketten-Struktur   (repa)  */
    aDatei[D_PFAD]:=ETI
    aDatei[D_KURZ]:="Versandetiketten"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="GRUPPSUM"
    /* zum aufsummieren je Gruppe bei Lagerliste */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="STATUS"
    /* zum aufsummieren je Gruppe bei Lagerliste */
    aDatei[D_PFAD]:=REPA
    aDatei[D_IND1]:="subRepArtikel(STATUS->ArtNr)+STATUS->Status"
    aDatei[D_DISP]:="SttDisp"
    aDatei[D_KURZ]:="Status"
    aDatei[D_ART ]:="Z" // fuehrende Nullen
    aDatei[D_MEHRF_INDEX]:={ || Art_Status()} // Mehrfachindex bei Neuerfass. : Typ+Status

  case Datei=="SUMMEN"
    /* zum Speichern der Summen/�bertr�ge im Rechnungsausgangbuch */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_IND1]:="SUMMEN->SumNr"
    aDatei[D_ART ]:="N"
    aDatei[D_KEY ]:="SumNr" // Stelle des Main Key Fields

  case Datei=="LIEFPLAN"
    /* zum Erstellen des Lieferplans */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_IND1]:="kwindex(LIEFPLAN->Kw)+LIEFPLAN->ArtNr"

  case Datei=="ABRUF"
    /* zum ausdrucken des Mat.Bedarfs bei Abrufauftraegen in Fakt.prg */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_IND1]:="ABRUF->ArtNr"

  case Datei=="BEISTELL"
    /* Beistellteile bei Rechnungsausdruck */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_IND1]:="BEISTELL->RechNr"

  case Datei=="BEISTEMP"
    /* zum ausdrucken des Mat.Bedarfs bei Abrufauftraegen in Fakt.prg */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Beistell" // wird hier als Struktur genommen !
    aDatei[D_IND1]:="BEISTEMP->ArtNr"

  case Datei=="LETZTEST"
    /* Letzte Stelle Artikel-Nummer */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Text"
    aDatei[D_IND1]:="LETZTEST->LetzteSt"
    aDatei[D_DISP]:="LtzDisp"

  case Datei=="ABHOL"
    /* Letzte Stelle Artikel-Nummer */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Abhol-Auftrag"
    aDatei[D_IND1]:="ABHOL->AufNr"

  case Datei=="PALETTEN"
    /* Letzte Stelle Artikel-Nummer */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Paletten"
    aDatei[D_IND1]:="PALETTEN->PalNr"
    aDatei[D_DISP]:="PalDisp"

  case Datei=="GRUND"
    /* Auswahlliste beim Eingabe eines Grundes, bisher ohne Kontext */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_ART ]:="N"
    aDatei[D_KURZ]:="Grund"
    aDatei[D_IND1]:="GRUND->GrundNr"
    aDatei[D_IND2]:="GRUND->Text"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_DISP]:="GruDisp"

  case Datei=="AUFZEIT"
    /* Datei zum erfassen der Zeit bei Auftr�gen */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Auftrags-Zeiten"
    aDatei[D_IND1]:="AUFZEIT->ABPostNr"

  case Datei=="TODO"
    /* temp. Datei f�r TODO items zum Anzeigen am BS */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="TODOs"
    aDatei[D_IND1]:="TODO->Type+TODO->ArtNr"

  case Datei=="LETZTENI"
    /* Letzte Stelle NietGeraete */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Letzte Stelle Niet."
    aDatei[D_IND1]:="LETZTENI->LetzteNi"
    aDatei[D_DISP]:="LtnDisp"

  case Datei=="MAT_KZ"
    /* Texte zur Material-Kennziffer (Artikel)/Magazine */
    aDatei[D_PFAD]:=AV
    aDatei[D_ART]:="N"
    aDatei[D_KURZ]:="Material-Kz-Text"
    aDatei[D_IND1]:="MAT_KZ->MatKz"
    aDatei[D_DISP]:="MKzDisp"

    // case Datei=="MATKZ_TE"
    // /* Texte der jeweiligen Stelle der Material-Kennziffer (Artikel)/Magazine */
    // aDatei[D_PFAD]:=AV
    // aDatei[D_ART]:="Z"
    // aDatei[D_KURZ]:="Material-Kz-Text"
    // aDatei[D_IND1]:="MATKZ_TE->Kz_Nr"
    // aDatei[D_DISP]:="MKtDisp"

  case Datei=="PERSONAL"
    /* Login   */
    aDatei[D_PFAD]:=AV
    aDatei[D_DISP]:="PerDisp"
    aDatei[D_KURZ]:="Mitarbeiter"
    aDatei[D_ART]:="N" // num. f�hrende Nullen !
    aDatei[D_IND1]:="PERSONAL->PersNr"

  case Datei=="BANKSTAM"
    aDatei[D_PFAD]:=BANK
    aDatei[D_DISP]:="BanDisp"
    aDatei[D_KURZ]:="Bank"
    aDatei[D_KEY ]:="Blz"
    aDatei[D_ART]:="Y" // Nur Gro�-Buchstaben
    aDatei[D_IND1]:="BANKSTAM->Blz"
    aDatei[D_IND2]:="upper(BANKSTAM->BankBez)"
    aDatei[D_IND3]:="BANKSTAM->BIC"
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    // aDatei[D_ALT_SEARCH]:={ |nr| BANKSTAM->BIC == nr }
    aDatei[D_NEW_REC_CODEBLOCK]:={ || if(bic_verify(BANKSTAM->Blz)==0,;
      (_FIELD->BIC:=BANKSTAM->Blz, _FIELD->Land:=substr(BANKSTAM->BIC,5,2)),.t.) }

  case Datei=="HAUSBANK"
    aDatei[D_PFAD]:=BANK
    aDatei[D_DISP]:="HBaDisp"
    aDatei[D_KURZ]:="Hausbank"
    aDatei[D_ART]:="N"
    aDatei[D_IND1]:="HAUSBANK->BankNr"

  case Datei=="ZAHLAUS"
    aDatei[D_PFAD]:=BANK
    aDatei[D_ART]:="N"
    // aDatei[D_IND1]:="ZAHLAUS->BankNr+ZAHLAUS->Pos"
    // aDatei[D_IND2]:={"ZAHLAUS->ZahlNr+ZAHLAUS->Pos","ZAHLAUS->KZ=='"+SEPA_KZ+"'"}
    aDatei[D_IND1]:="ZAHLAUS->BankNr"
    aDatei[D_IND2]:={"ZAHLAUS->SepaNr+ZAHLAUS->ZahlNr","ZAHLAUS->KZ=='"+SEPA_KZ+"'"}

  case Datei=="SCHECK" // Achtung wird als Stru von Ueber.dbf genutzt, ansonsten obsolete
    aDatei[D_PFAD]:=BANK

  case Datei=="SCHECK_T"
    /* zur Scheckeingabe   */
    aDatei[D_PFAD]:=BANK
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STRU]:="Scheck" // wird hier als Struktur genommen !
    aDatei[D_TEMP_STATIC]:=.t.
    aDatei[D_TEMP_ERASE]:=.f.

  case Datei=="UEBER_T"
    /* zur Eingabe von Ueberweisungen   */
    aDatei[D_PFAD]:=BANK
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt
    aDatei[D_TEMP_STATIC]:=.t.
    aDatei[D_TEMP_STRU]:="Scheck" // wird hier als Struktur genommen !
    aDatei[D_TEMP_ERASE]:=.f.

  case Datei=="M_MEHRF"
    /* Mat.Bedarf Mehrfach vorkommend (Sammeldatei) */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="Material-Bedarf"
    aDatei[D_IND1]:="M_MEHRF->ArtNr + kwindex(M_MEHRF->Kw)"
    aDatei[D_IND2]:={ "kwindex(M_MEHRF->Kw)",D_UNIQUE }
    aDatei[D_IND3]:="M_MEHRF->Reihenfolg+M_MEHRF->ArtNr"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="X_MEHRF"
    /* Mat.Bedarf Mehrfach vorkommend (Sammeldatei) */
    aDatei[D_PFAD]:=MAT
    aDatei[D_KURZ]:="Material-Bedarf2"
    aDatei[D_IND1]:="X_MEHRF->ArtNr + kwindex(X_MEHRF->Kw)"
    aDatei[D_IND2]:={ "kwindex(X_MEHRF->Kw)",D_UNIQUE }
    aDatei[D_IND3]:="X_MEHRF->Reihenfolg+X_MEHRF->ArtNr"
    aDatei[D_TEMP_STRU]:="M_MEHRF" // wird hier als Struktur genommen !
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="ERSATZ"
    /* Mat.Bedarf Mehrfach vorkommend (Sammeldatei) */
    aDatei[D_PFAD]:=REPA
    aDatei[D_KURZ]:="Ersatzteile-Honsel"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="WERBUNG"
    /* MengenEinh  */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Werbe-Kunden"
    aDatei[D_DISP]:="WKdDisp"
    aDatei[D_ART]:="K" // Kunden-Eingabe
    aDatei[D_REC_EMPTY]:={|feld| feld==KDNR_LEER }
    aDatei[D_TOGGLE_INDEX]:=.t. // Umschalten der Indices bei Hilfe
    aDatei[D_IND1]:="WERBUNG->KdNr_Werb"
    aDatei[D_IND2]:="WERBUNG->Kurzname"

  case Datei=="KONSIG"
    /* Konsignationslager-Abruf */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="K-Lager"
    aDatei[D_IND1]:="KONSIG->AufNr+KONSIG->ArtNr"
    aDatei[D_IND2]:="KONSIG->LiefNr"
    aDatei[D_IND3]:="KONSIG->KundNr+KONSIG->ArtNr+dtos(KONSIG->LieDat)"
    // ge�ndert 5.11.2013, da mache LSNr leer?!
    // aDatei[D_IND3]:="KONSIG->KundNr+KONSIG->ArtNr+KONSIG->LiefNr"
    aDatei[D_ART ]:="S" // Rechts-Shift , 1. Index

  case Datei=="HONSELDA"
    /* Konsignationslager-Abruf */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="K-Lager-Artikel"
    aDatei[D_IND1]:="HONSELDA->Miki_nr"
    aDatei[D_DISP]:="HonsDisp"
    aDatei[D_ART ]:="A" // Artikel-Eingabe
    aDatei[D_KEY ]:="Miki_nr" // MIKI_Nr (Reihenfolge auf Grund von Import "festgelegt")
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }

  case Datei=="HONSELVK"
    /* Konsignationslager-Abruf */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Honsel VK Datei"
    // aDatei[D_IND1]:="HONSELDA->Miki_nr"

  case Datei=="ARTPREIS"
    /* Konsignationslager-Abruf */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Art.Preis-Hist."
    aDatei[D_IND1]:="ARTPREIS->ArtNr"
    aDatei[D_DISP]:="ArtPrDisp"
    aDatei[D_ART ]:="A" // Artikel-Eingabe
    aDatei[D_NEW_REC_SHIFT]:={ |s| shiftArtikel(s) }

  case Datei=="ARTPRGR"
    /* Konsignationslager-Abruf */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Art.Preis-Gruppe."
    aDatei[D_IND1]:="ARTPRGR->PrGr"
    aDatei[D_DISP]:="ArtPrGrDisp"

  case Datei=="LAGERORT"
    /* Text f�r Av */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Lagerort"
    aDatei[D_DISP]:="LgDisp"
    aDatei[D_IND1]:="LAGERORT->LgNr"
    aDatei[D_ART ]:="N"

  case Datei=="ZOLLSTELLE"
    /* Text f�r Av */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="ZollStelle"
    aDatei[D_DISP]:="ZolDisp"
    aDatei[D_IND1]:="ZOLLSTELLE->ZollNr"
    aDatei[D_ART ]:="Z"
    aDatei[D_DELETE_CASCADE]:={"KundZoll"}

  case Datei=="DLEMAIL" // Dienstleistungen Email Benachrichtigung
    aDatei[D_PFAD]:=AV
    aDatei[D_ART]:="A"
    aDatei[D_IND1]:="DLEMAIL->ArtNr+str(DLEMAIL->AbPostNr,8)"

  case Datei=="KUNDZOLL"
    /* Text f�r Av */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-ZollStelle"
    aDatei[D_IND1]:="KUNDZOLL->KundNr+KUNDZOLL->SpedNr"

  case Datei=="KDZOLLTEMP"
    /* temp. Datei f�r Zollstelle je Kunde */
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Kunden-Zollstelle"
    aDatei[D_TEMP]:=.t.
    aDatei[D_TEMP_STRU]:="KundZoll" // wird hier als Struktur genommen !

  case Datei=="LAND"
    /* L�nder-Kennungen */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="L�nder-Kennung"
    aDatei[D_IND1]:="LAND->LandKZ"
    aDatei[D_DISP]:="LanDisp"
    aDatei[D_ART ]:="Y"

  case Datei=="FARBE"
    /* L�nder-Kennungen */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Farben"
    aDatei[D_IND1]:="FARBE->Text"
    aDatei[D_DISP]:="FarbDisp"

  case Datei=="TEST"
    aDatei[D_PFAD]:=TEMP
    aDatei[D_KURZ]:="Test"

  case Datei=="INTRASTAT"
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Warennummer"
    aDatei[D_IND1]:="INTRASTAT->WarenNr"
    aDatei[D_DISP]:="IntraDisp"

  case Datei=="ARTMINORD"
    aDatei[D_PFAD]:=FAKT
    aDatei[D_KURZ]:="Artikel - Mind.Bestellmenge"
    aDatei[D_IND1]:="ARTMINORD->ArtNr"

  case Datei=="FERTIGMELD"
    aDatei[D_KURZ]:="Temp Datei Fertigmeldung Storno"

  case Datei=="FEHLER"
    /* Fehler-Protokoll */
    aDatei[D_PFAD]:=HAUPT

  case Datei=="FENSTER"
    /* Liste   */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Fenster"
    aDatei[D_DISP]:="FensDisp"
    aDatei[D_ART ]:="Z"
    aDatei[D_IND1]:="FENSTER->Liste_Kurz+FENSTER->Kurzel"

  case Datei=="LOGIN"
    /* Login   */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_DISP]:="LogDisp"
    aDatei[D_KURZ]:="Mitarbeiter"
    aDatei[D_ART]:="Y"
    aDatei[D_IND1]:="LOGIN->Kurzel"
    aDatei[D_NO_COPY_FIELDS]:={"NAME","PASSWORT","TELEFON","WARNING","LOGIN1","LOGIN2","LOGIN3",;
      "LOGIN4","LOGIN5","LOGIN6","LOGIN7","LOGIN8","LOGIN9"}


  case Datei=="INFO"
    /* INFO    */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_IND1]:="upper(padr(INFO->Prog,len(INFO->Prog)))+upper(INFO->Var)"

  case Datei=="SYSTEM"
    /* System   (Alle Systemparameter) */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_DISP]:="SysDisp"

  case Datei=="DRUCKER"
    /* Drucker */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Drucker"
    aDatei[D_DISP]:="DruckDisp"
    aDatei[D_IND1]:="DRUCKER->DruckerNr"
    aDatei[D_ART ]:="Z"

  case Datei=="LISTE"
    /* Liste   */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Liste"
    aDatei[D_DISP]:="ListDisp"
    aDatei[D_ART ]:="Z"
    aDatei[D_IND1]:="LISTE->Liste_Kurz"

  case Datei=="ZEIGE"
    /* Datei zum Anzeigen von ASCI-Files */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Zeige"
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  case Datei=="CRONTAB"
    /* crontab-workaround */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_KURZ]:="Crontab-Eintrag"
    aDatei[D_DISP]:="CroDisp"
    aDatei[D_IND1]:="CRONTAB->CronName" // FIXME: maybe we need a pre-defined order field
    aDatei[D_KEY ]:="CronName"

  case Datei=="PROZESSE"
    /* INFO    */
    aDatei[D_PFAD]:=HAUPT
    aDatei[D_TEMP]:=.t. // wird als temp. DAtei excl. benutzt

  otherwise
    Error(Datei+DATEI_INIT)
    Error(INFO_LINE)
    aDatei[D_PFAD]:=HAUPT // Verhindert vorzeiten Absturz

  endcase

RETURN(aDatei)
/** eof */

/** Returns the list of all available database files */
FUNCTION getAllDBNames()
RETURN( { ALLE_DATEIEN } )

/** Returns the list of all miki database files */
FUNCTION getMikiDBNames()
RETURN( { MIKI_DATEIEN } )


/** Returns a list of all available sections & description, e.g. "Etiketten",ETI */
FUNCTION getAllDBSections()
RETURN ({ {"Gesamt",""} , {"System", HAUPT } , { "Reparaturen" , REPA } ,;
  { "Fakturierung",FAKT } , {"Arbeitsvorbereitung",AV },;
  { "Etiketten",ETI } , { "Bestellungen", BEST }, {"Material",MAT } ,{"Bank",BANK} })


/** Wird beim neu anlegen eines Artikels ausgef�hrt */
Function ArtNeuSatz()
LOCAL Puffer:=val(getProperty("Miki.mindestbestand.puffer","6"))

  // setze default Puffer f�r Berechnung Mindestbestand
  replace ARTIKEL->MinPuffer with puffer

  // setzte default values f�r Werkzeug-Nutzer im Artikel-Stamm :(
  if ! getUser():mayCreateArticles .and. getUser():mayEditTool
    replace ARTIKEL->Art with "W"
    replace ARTIKEL->Schluessel with "E"
  endif
  aendArtBest(0,"Neuanlage")

  select Artikel

return .t.
/** eof */

/** liefert den umgekehrten Wert eines Feldes -> f�r Index only */
FUNCTION mydescend(value)
LOCAL Result

  switch valtype(value)
  case "C"
    result:=descend(value)
    exit
  case "D"
    result:=str(9999-year(value),4)+str(99-month(value),2)+str(99-day(value),2)
    exit
  otherwise
    Error("Dateidef.mydescend: Datenformat nicht unterst�tzt:"+valtype(value),.t.)
  endswitch

return result
/** eof */

/** Opens ArtReserv, tries for x seconds.  Returns success or not */    
function openArtReserv(timeout, exclusive)
LOCAL start:=seconds()
  default timeout:=13
  default exclusive:=.t.
  // NOTE: using db_open to avoid translation by mystd.ch
  do while .not. db_open({{"ArtReserv", exclusive}}, .f.) .and. seconds() < start + timeout
    hb_idleSleep( 1 )
  enddo
return select("ArtReserv") > 0
  /** eof */


/** Bedingung f�r Inner.dbf dass es sich um den Haupteintrag handelt:
  * Bei mehreren Arbeitsg�ngen: liefert nur der 1. true alle anderen false
  */
function isInnerHauptArbeitsgang()
return empty(INNER->ArbGang) .or. INNER->ArbGang=="A"

/** schreibt die Modification Datum, Sekunden und Benutzer in die akt. Datei
 *
 * Datensatz muss bereits gelockt sein!
 */
procedure writeModData()
  if fieldpos("Mod_Date")>0
    replace (alias())->Mod_Date with date()
    replace (alias())->Mod_Time with seconds()
    replace (alias())->Mod_User with getUser():id
  endif
return

/** schreibt die Creation Datum, Sekunden und Benutzer in die akt. Datei
 *
 * Datensatz muss bereits gelockt sein!
 */
procedure writeCreaData()
  if fieldpos("Crea_Date")>0
    replace (alias())->Crea_Date with date()
    replace (alias())->Crea_Time with seconds()
    replace (alias())->Crea_User with getUser():id
  endif
return




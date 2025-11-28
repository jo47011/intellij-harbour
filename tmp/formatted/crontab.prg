/** F�hrt alle automat. regelm. jobs auf
   *
   * ACHTUNG: dow("Sonntag")==1
   */

#include "miki.ch"

Procedure CronJobs(jobName, run_all)
LOCAL aktRec:=0,tempName,countdown,taste
LOCAL objErr, bLastHandler, alleRaus:=.t.
LOCAL okJobs:="",debugJobs:="",s01,foo:="X",subject
LOCAL getlist:={}, printBuffer, tempVal, fehler:=.f. // we're optimistic

  default run_all:=.f.

  cls
  Titel("Automatische Jobs starten")

  if ! open("crontab")
    TroubleEmail("Crontab konnte nicht ge�ffnet werden.")
    cls
    close data
    return
  endif

  if jobName == NIL
    @ 9,19 to 15,60
    @ 10,21 say 'Dieser Vorgang dauert einige Zeit !'
    @ 14,21 say 'S = Start             ESC = Abbruch'

    taste:=0
    countdown=CRONTAB_COUNTDOWN
    do while countdown>0 .and. Taste <> K_ESC .and. ! chr(Taste) $ "sS"

      @ 12,21 say 'Startet in '+str(countdown,2)+' Sekunden'
      taste=INKEY(1)
      // qqout(taste)
      countdown--
    enddo
    @ 12,21 say 'Bitte warten...                      '
  endif

  if Taste <> K_ESC

    if jobName == NIL
      // alle anderen Benutzer rausschmeissen
      if ! forceQuit(.f.)
        trouble("crontab",{"Crontab abgebrochen (quit)   ========================================="})
        Down() // ende aus
      endif

      // list user currently logged in, should be none!!!
      if (printBuffer:=LoginDispatcher():new():getPrintBuffer()):getNumLines() > 0
        trouble("crontab", printBuffer:getText() )
      endif

      // disallow login
      createEmptyFile(SHUTDOWN_S)
    endif

    trouble("crontab",{"Crontab gestartet   ================================================="})

    /** HouseKeeping / Service clean up, since 20180821 always 1st */
    if jobName == NIL
      BEGIN SEQUENCE
        HouseKeeping()
        okJobs+="Houskeeping ausgef�hrt."+MY_CR+MY_LF
      RECOVER USING objErr
        email(MY_EMAIL,"ERROR: Crontab-Absturz: Service.","Service am "+dtoc(date()))
      END SEQUENCE
    endif

    // seit 12.3.2014 mit automatischem backup
    trouble("crontab",{"About to backup"})
    if AT_HOME
      trouble("crontab",{"No backup at home"})
    else
      trouble("crontab",{"In backup"})
      BEGIN SEQUENCE
        autoBackupData( .f. )
        deleteBackupData( 31 ) // l�sche alle backups �lter als 31 Tage
        okJobs+="Backup erstellt."+MY_CR+MY_LF

        trouble("crontab",{"Backup done."})
        // wait 3 minutes, why?
        inkey( 3 * 60 )

      RECOVER USING objErr
        email(MY_EMAIL,"ERROR: Crontab-Absturz: Backup",getErrorText(objErr))
      END SEQUENCE
    endif

    // seit 10.10.2023 Reorg immer am Anfang
    /** Reorganisation */
    BEGIN SEQUENCE
      // l�sche alle indices vorher, inkl temp. indices
      DeleteCDXRecursive(".\DAT"+BACKSLASH)
      reorg(.f.) // ohne Abfrage !
      okJobs+="Reorganisation ausgef�hrt."+MY_CR+MY_LF
    RECOVER USING objErr
      email(MY_EMAIL,"ERROR: Crontab-Absturz: Reorg.","Reorg erstellt am "+dtoc(date()))
    END SEQUENCE


    bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle quiet Break ein

    if ! open("crontab")
      TroubleEmail("Crontab konnte nicht ge�ffnet werden.")
      cls
      close data
      return
    endif

    select crontab
    if jobName == NIL
      go top // changed to alphatical order, set order to 0 here if not wanted
    else
      dbseek(jobName)
      if CRONTAB->(eof())
        Error(ACHTUNG+"Cronjob: " + jobName + " nicht gefunden.")
        close data
        return
      endif
    endif

    do while ! CRONTAB->(eof())
      if ( CRONTAB->Wochentag==dow(getUser():date) .and.;
        getUser():date<>CRONTAB->Datum ) .or. ( CRONTAB->Monat==month(getUser():date) .and. (month(getUser():date)<>month(CRONTAB->Datum) .or. year(getUser():date)<>year(CRONTAB->Datum) )) .or. jobName != NIL .or. (run_all .and. tempName<>trim(CRONTAB->CronName))

        // Excel not supported as Task, see CronExcel()
        if CRONTAB->Excel == "J"
          skip
          loop
        endif

        aktRec:=CRONTAB->(recno())
        tempName=trim(CRONTAB->CronName)
        s01:=savescreen()

        // Ausnahme EU-Umsatz / Intra.Stat. Meldung, erst am 5. Tag des Monats
        // muss hier sein, da ansonsten Merker (erledigt) gesetzt wird
        if tempName=="EU_UMSATZ" .and. day( getUser():date ) < 2
          // altd()
          skip
          loop
        endif

        /** setze Merker fuer erledigt vorher ! (falls Absturz geht beim 2.MAl) */
        rec_lock(0)
        replace CRONTAB->Datum with getUser():date
        dbcommit()
        dbunlock()

        trouble("crontab",{"Crontab Job starte:"+CRONTAB->CronName})

        /** fuehre entsp. Programm aus */
        // Umweg ueber if-Abfrage -> Systemsicherheit !

        do case

          /** Rechnungsausgangsbuch */
        case tempName=="RECHAUS"
          BEGIN SEQUENCE
            Rechaus(.f.,.f.) // t�glich ohne Abfrage
            okJobs+="Rechnungsausgangsbuch t�gl."+MY_CR+MY_LF
            setAllDuedates()
            okJobs+="Mahnstufen / F�lligkeit angepasst."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Rechaus.",getErrorText(objErr),,,.t.)
          END SEQUENCE

          /** Rechnungsausgangsbuch */
        case tempName=="RECHAUS_MONAT"
          BEGIN SEQUENCE
            Rechaus(.t.,.f.) // monatlich ohne Abfrage
            okJobs+="Rechnungsausgangsbuch monatl."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Rechaus-Monat.",getErrorText(objErr))
          END SEQUENCE

          /** EU Umsatz Liste (1x Monat) */
        case tempName=="EU_UMSATZ"
          BEGIN SEQUENCE
            EuUmsatzIntraStatExport(.f.) // ohne Abfrage
            okJobs+="Intra.Stat. XML-Datei / EU Ums�tze monatl."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: EU-Umsatz.",getErrorText(objErr))
          END SEQUENCE

          /** vorab EU Umsatz Liste (1x Monat) */
        case tempName=="PRE_EU_UMSATZ"
          BEGIN SEQUENCE
            EuUmsatzIntraStatExport(.f.,.t.) // ohne Abfrage, test-only
            okJobs+="Vorab Intra.Stat. XML-Datei / EU Ums�tze monatl."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Vorab-EU-Umsatz.",getErrorText(objErr))
          END SEQUENCE

          /** Gelangensbescheinigungen */
        case tempName=="GELANGENS_LISTE"
          BEGIN SEQUENCE
            GelangensList(.f.) // ohne Abfrage
            okJobs+="Gelangensbescheinigungen Liste."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Gelangensbescheinigungen Liste",getErrorText(objErr))
          END SEQUENCE

          /** K-Lager Liste */
          // raus. siehe Email vom 18.12.22
          // case tempName=="KLAGER_LIST"
          // BEGIN SEQUENCE
          // KKundArtikelListe(3, "10167-  ",.t.)
          // okJobs+="K-Lager Liste."+MY_CR+MY_LF
          // RECOVER USING objErr
          // email(MY_EMAIL,"ERROR: K-Lager Liste",getErrorText(objErr))
          // END SEQUENCE

          /** AV/St�ckliste Konsistenzcheck */
        case tempName=="STUECKLISTE"
          BEGIN SEQUENCE
            StkList_check(.t.)
            checkDublettenAvPost()
            checkAvAus()
            debugJobs+="St�ckliste Rekursion & Dubletten"+MY_CR+MY_LF

          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Stueckliste.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** Preiskalkulation */
        case tempName=="KALKU"
          BEGIN SEQUENCE
            Preis_Check(.f.) // ohne Abfrage !
            okJobs+="Preiskalkulation berechnet."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Preiskalk.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** Waraus Konsistenzcheck */
        case tempName=="WARAUS"
          BEGIN SEQUENCE
            Waraus1KonsistenzCheck()
            Waraus2KonsistenzCheck()
            RechausKonsistenzCheck()
            debugJobs+="Waraus Konsistenzchecks 1 + 2."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Waraus.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** Auftragsbestand neu berechnen */
        case tempName=="AUF_BESTAND"
          BEGIN SEQUENCE
            // neue Berechnung mit abweichenden St�ckliste je Ab, (Parameters: mail ja, quiet: ja, background: nein)
            // run in foreground!!!
            AufBestand(.t. , .t. , .f.)
            okJobs+="Auftragsbestand neu berechnet."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: AufBestand.",getErrorText(objErr))
          END SEQUENCE

          /** KLager Konsistenzcheck */
        case tempName=="KKONSISTENZ"
          BEGIN SEQUENCE
            KKonsistenzCheck()
            debugJobs+="KLager Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: KKonsistenzCheck.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** AB Konsistenzcheck */
        case tempName=="ABKONSISTENZ"
          BEGIN SEQUENCE
            AufausKonsistenzCheck()
            InnerABKonsistenzCheck()
            debugJobs+="Aufaus Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: ABKonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** AB Konsistenzcheck2 */
        case tempName=="ABCHECKALTER"
          BEGIN SEQUENCE
            AufausKonsistenzCheck2()
            debugJobs+="Aufaus Konsistenzcheck Alter"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: ABKonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** Bestellungen Konsistenzcheck */
        case tempName=="BESTKONS"
          BEGIN SEQUENCE
            BestellKonsistenzCheck()
            debugJobs+="Aufaus Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: ABKonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** AB Konsistenzcheck */
        case tempName=="BEISTKONSISTENZ"
          BEGIN SEQUENCE
            BeistBestandsListe(.t.)
            debugJobs+="Beistellteile Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: BeistKonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** Rahmenauftrag pr�fen */
        case tempName=="RAHMENAB"
          BEGIN SEQUENCE
            RahmenABListe(.f.)
            okJobs+="Rahmenauftr�ge gepr�ft."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Rahmenauftrage.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** VK Konsistenzcheck */
        case tempName=="VK_KONSISTENZ"
          BEGIN SEQUENCE
            VK_HistCheck()
            // VK_KonsistenzCheck()
            debugJobs+="VK Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: VK-KonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** Ping Remote Service */
        case tempName=="PING"
          BEGIN SEQUENCE
            tempVal:=pingRemoteService()
            if tempVal
              debugJobs+="PING RS okay."+MY_CR+MY_LF
            else
              debugJobs+="PING RS failed."+MY_CR+MY_LF
              fehler:=.t.
            endif
          RECOVER USING objErr
            TroubleEmail(MY_EMAIL,"ERROR: Crontab-Absturz: Ping.","Check erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** Kunden Konsistenzcheck */
        case tempName=="KUNDKONSISTENZ"
          BEGIN SEQUENCE
            KundenKonsistenzCheck()
            debugJobs+="Kunden Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: VK-KonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** Artikel-> Verkauft, Artikel-> Mehrfach Konsistenzcheck */
        case tempName=="ARTKONSISTENZ"
          BEGIN SEQUENCE
            ArtVerkauftUpdate()
            MehrfachKonsistenzCheck()
            checkInnerGeloescht() // FIXME: sollte evtl. eigener Konsistenzcheck sein
            debugJobs+="Artikel Konsistenzcheck"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Artikel-KonsistenzCheck.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

          /** AB: Dienstleistungen Email schicken */
        case tempName=="DIENSTL_EMAIL"
          BEGIN SEQUENCE
            DienstLeistungsCheck()
            debugJobs+="Dienstleistungen AB gepr�ft"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: DIENSTL_EMAIL.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** Offene AB: Email schicken falls Liefertermin erreicht */
        case tempName=="OFFENE_AB_CHECK"
          BEGIN SEQUENCE
            OffeneABCheck()
            debugJobs+="Offene AB gepr�ft"+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: OFFENE_AB_CHECK.","Erstellt am "+dtoc(date()))
          END SEQUENCE

          /** AB Liefer-Liste */
        case tempName=="LIEFLIST"
          BEGIN SEQUENCE
            Lieferliste("  /  ",getKw(getUser():date+1),"ON") // Achtung l�uft Sonntags, deshalb +1
            okJobs+="Lieferliste erstellt."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Liefer-Liste.","Erstellt am "+;
              dtoc(date()),,,.t.)
          END SEQUENCE

        case tempName=="AUFTRAGS_LISTE"
          BEGIN SEQUENCE
            Auf_KundListe(,.t.)
            okJobs+="Auftragsliste erstellt."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Auftrags-Liste.","Erstellt am "+dtoc(date()))
          END SEQUENCE

        case tempName=="MAHN_LISTE"
          BEGIN SEQUENCE
            MahnListe("PDF")
            okJobs+="Liste f�llige Rechnungen erstellt."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Auftrags-Liste.","Erstellt am "+dtoc(date()))
          END SEQUENCE

        case tempName=="BESTELL_LISTE"
          BEGIN SEQUENCE
            BestellListe(.t.)
            okJobs+="Bestellliste erstellt."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Bestell-Liste.","Erstellt am "+dtoc(date()))
          END SEQUENCE

        case tempName=="NEGBEST_LISTE"
          BEGIN SEQUENCE
            NegLageNeu()
            okJobs+="Negativer Lagerbestand gepr�ft."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Neg.Lagerbestand-Liste.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        case tempName=="KMINDBEST_LISTE"
          BEGIN SEQUENCE
            //KlagMindBestListe("KLager-VVG-bei-Miki",KDNR_VVG)
            KlagMindBestListe("KLager-VVG-bei-Miki-excel",KDNR_VVG)
            okJobs+="K-Lager Mindestbestandsliste erstellt."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: K-Lager Mindestbestandsliste.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        case tempName=="BESTBESTAND"
          BEGIN SEQUENCE
            BestBestand()
            okJobs+="Bestellbestand intern/extern aktualisiert."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Bestellbestand.","Erstellt am "+dtoc(date()))
          END SEQUENCE

        case tempName=="NEGVERFUEG"
          BEGIN SEQUENCE
            trouble("crontab", "Negverfueg" )
            NegVerfueg("BDEFMX",,,,,"N") // ohne bestell details
            // MaterialBedarfsListe("BDEFMX") // lokal
            MatBedarfAktuell("BDEFMX") // aktueller Bestand, ohne Vorschau, auto-login
            RohMatBedarf(.t.) // Bedarf Rohmaterial
            okJobs+="Artikel Verf�gbarkeit gepr�ft."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Artikel Verf�gbarkeits-Liste.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        case tempName=="MINDESTBESTELL"
          BEGIN SEQUENCE
            MindestBestellMenge(.t.)
            okJobs+="Mindest-Bestellmenge F-Artikel berechnet."+MY_CR+MY_LF
            MindBestRabattCheck(.t.)
            okJobs+="mit 1. Rabatt-Staffel verglichen."+MY_CR+MY_LF
            MindBestSollIstCheck(.t.)
            okJobs+="    Soll/Ist-Wert verglichen."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Mindest-Bestellmenge","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        case tempName=="MINDESTBESTAND"
          BEGIN SEQUENCE
            WarAusJahrList("NOP")
            okJobs+="Mindest-Bestand E-Artikel berechnet."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Mindest-Bestand-Liste.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        case tempName=="MAT_TOLERANZ"
          BEGIN SEQUENCE
            checkMatVerfuegbar(.t.)
            okJobs+="Material Verf�gbarkeit gepr�ft."+MY_CR+MY_LF
          RECOVER USING objErr
            email(MY_EMAIL,"ERROR: Crontab-Absturz: Material Verf�gbarkeit.","Erstellt am "+;
              dtoc(date()))
          END SEQUENCE

        endcase

        if ! open("crontab")
          Error(INFO_LINE)
          Error("Fehler beim Oeffnen der Crontab")
          ferase(SHUTDOWN_S) // einloggen wieder erlauben
          RETURN
        endif
        go (aktRec)
        restscreen(,,,,s01)

        trouble("crontab",{"Crontab Job beendet:"+CRONTAB->CronName})

      endif
      skip

      if jobName <> NIL
        exit
      endif

    enddo
    MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)

    // // testing
    // if AT_HOME
    // HouseKeeping()
    // debugJobs+="Service ausgef�hrt."+MY_CR+MY_LF
    // endif


    if len(okJobs)>0 .or. len(debugJobs)>0
      subject:=if(fehler,"ERROR: ","") + "Crontab ausgef�hrt: "
      if AT_HOME
        email(MY_EMAIL,subject+str(mlcount(okJobs)+mlcount(debugJobs))+" Jobs", okJobs+"---"+;
          MY_CR+MY_LF+debugJobs)
      else
        email(CUSTOMER_EMAIL,"Crontab ausgef�hrt",okJobs)
        email(MY_EMAIL,subject+str(mlcount(okJobs)+mlcount(debugJobs))+" Jobs", okJobs+"---"+;
          MY_CR+MY_LF+debugJobs)
      endif

      // // FIXME: delay needed once running emails in background
      // alternativ: hb_threadWaitForAll()
      // Error("INFO: Crontab -> warten auf Shutdown",.f.)
      // warte(17) // make sure email is sent before shut-down

    endif

    ferase(SHUTDOWN_S) // einloggen wieder erlauben
    trouble("crontab",{"Crontab beendet.   ================================================="})

  endif
RETURN


/** Special crontab: excel Jobs are not launched as Windows Task but upon login of MW

  as of now only for daily triggers.
  */
procedure cronExcel()
LOCAL objErr, bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle quiet Break ein

  trouble("crontab",{"CronExcel start"})

  if ! open("crontab")
    TroubleEmail("Crontab konnte nicht ge�ffnet werden.")
    cls
    close data
    return
  endif

  loca for CRONTAB->Excel == "J"
  do while ! CRONTAB->(eof())
    // execute it on the same day or on the next login afterwards
    if ( CRONTAB->Wochentag==dow(getUser():date) .and. getUser():date<>CRONTAB->Datum ) .or.;
      getUser():date - CRONTAB->Datum > 6 // mind. 1x pro Woche
      if trim(CRONTAB->CronName) == "KMINDBEST_LISTE"
        BEGIN SEQUENCE
          KlagMindBestListe("KLager-VVG-bei-Miki-excel",KDNR_VVG)

          rec_lock(0)
          replace CRONTAB->Datum with getUser():date
          dbcommit()
          dbunlock()

        RECOVER USING objErr
          email(MY_EMAIL,"ERROR: Crontab-Absturz: K-Lager Mindestbestandsliste",getErrorText(;
            objErr))
        END SEQUENCE
      endif
    endif
    cont
  enddo

  MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
  trouble("crontab",{"CronExcel end"})
  close data
return
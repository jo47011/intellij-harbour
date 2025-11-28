/** Class representing the current user */

#include "miki.ch"

#include "hbclass.ch"

CLASS User

DATA id READONLY // U_KURZEL M->User[1]
DATA counter READONLY // U_TERMINAL M->User[2]
DATA mayPrint INIT .f. // U_DRUCKEN M->User[3]
DATA mayEditData INIT .f. // U_STAMMDAT M->User[4]
DATA mayShowData INIT .f. // neu
DATA infoOnly INIT .f. // U_NURAUSKUNFT M->User[7]
DATA mayEditInfoText INIT .f. // INFO_TEXT
DATA isGroupAccount INIT .f. // is used by multiple users

DATA saveWinPos INIT .t. // U_SAVE_POS M->User[12]
DATA saveWinSize INIT .t. // U_SAVE_SIZE M->User[13]
DATA fontName INIT HB_DEFAULT_FONT
DATA fontSize INIT HB_DEFAULT_FONT_WIDTH
DATA fontBold INIT .f.


DATA exportPath INIT "." // EXPORT
DATA exportFallbackPath INIT "./TRANSFER" // getUser():exportFallbackPath

DATA date INIT hb_date()
DATA isBackgroundTask INIT .f.
DATA printJob // HIDDEN

DATA tempSelected INIT hb_hash()

// Static data
CLASSDATA tempCounter INIT 0 READONLY // used for unique filenames or alike

// flags for editing articles, tooles, etc.
DATA mayEditStock INIT .f. // U_LAGEBEST M->User[5]
DATA mayEditGewicht INIT .f.
DATA mayEditTool INIT .f. // U_WERKZEUG M->User[6]
DATA mayPrintLabel INIT .f. // U_ETIKETT M->User[8]
DATA mayEditVK INIT .f. // U_VK_AEND M->User[9]
DATA mayEditEK INIT .f. // U_EK_AEND M->User[10]
DATA mayEditPartsList INIT .f. // U_STK_AEND M->User[11]
DATA mayEditEnglishText INIT .f.
DATA mayEditKonsigKd INIT .f. // Konsig KundNr in Artikel �ndern
DATA mayEditIntrastat INIT .f. // Konsig KundNr in Artikel �ndern
DATA mayIgnoreNachkalk INIT .f. // darf innerbetr.Auftrag ohne Nachkalk l�schen

// flags for entering specific menus
DATA mayEnterSysMenu INIT .f.
DATA mayEnterBank INIT .f.
DATA mayEnterMatEinAusg INIT .f.
DATA mayEnterFakt INIT .f.
DATA DSGVO INIT .f.
DATA mayCreateInnerOrders INIT .f.
DATA mayEnterNietGerat INIT .f.

// neu 23.2.15
DATA mayCreateArticles INIT .f.
DATA mayEditArticleText INIT .f.

// neu 27.3.15
DATA mayEnterMatMenu INIT .f.

METHOD new(kurzel,terminal)
METHOD getLongID()
METHOD getWindowStorageID()
METHOD getCurrentPrintJob(quiet, nilAllowed)
METHOD setCurrentPrintJob(job)
METHOD readSettings()
METHOD setUserDefaults(isSuperUser)
METHOD resetTempSelected()

METHOD getTempCounter()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new(kurzel,terminal)
  ::id:=kurzel
  ::counter:=right("00"+alltrim(terminal),2) // seit 11.7.19 2 Stellen f�r mehr Fenster

  do case
  case kurzel==DUMMY_USER
    ::setUserDefaults(.f.)
  case SERVER_LOGIN==kurzel
    ::setUserDefaults(.t.)
  otherwise
    ::setUserDefaults(.f.)
    ::readSettings()
  endcase

  ::exportPath:=EXPORT + BACKSLASH + ::id
  ::exportFallbackPath:=EXPORT_FALLBACK + BACKSLASH + ::id
RETURN self


/** Returns a unique combination of user ID & counter (was MACHINE) */
METHOD getLongID()
return ::id + ::counter

/*----------------------------------------------------------------------*/

/** returns the ID for storing windows paramters,
* Returns the username or clientname or computername
*/

METHOD getWindowStorageID()
LOCAL result
  if empty(result:=USER_NAME)
    if empty(result:=CLIENT_NAME)
      result:=getenv("COMPUTERNAME") // FIXME: there maybe a better uniqe fallback solution?
    endif
  endif
return result
/** eom */

/*----------------------------------------------------------------------*/

/** returns the current PrintJob, should not be NIL, rather return a DummJob instead */
METHOD getCurrentPrintJob(quiet , nilAllowed)
LOCAL result:=::PrintJob

  default nilAllowed:=.f.

  if result==NIL .and. ! nilAllowed
    ::printJob:=DummyJob():new(quiet)
    result:=::PrintJob
  endif

return result
/*----------------------------------------------------------------------*/

/** sets the current PrintJob, can be NIL when printing is done */
METHOD setCurrentPrintJob(job)
  ::PrintJob:=job
return self
/*----------------------------------------------------------------------*/

/** l�scht alle temp. selektierten Datens�tze */
METHOD resetTempSelected()
  ::tempSelected:=hb_hash()
return self
/** eop */
/*----------------------------------------------------------------------*/

/** Liefert den n�chsten temp. Counter Value, max value ist 99 -> danach wieder 1 */
METHOD getTempCounter()
  if ::tempCounter >= 99
    ::tempcounter:=0
  endif
  ::tempcounter ++
return right("00"+alltrim(str(::tempcounter,2)),2)
/** eop */
/*----------------------------------------------------------------------*/

/*----------------------------------------------------------------------*/
/** reads all permission from currently select LOGIN record to this user */
METHOD readSettings()
  if select("Login")==0
    Error(ACHTUNG+" User Settings konnten nicht zugewiesen werden.",.t.)
  else
    IF LOGIN->Kurzel<>::id
      Error(ACHTUNG+" User Settings: falscher Benutzer selektiert.",.t.)
    else
      ::mayPrint:=LOGIN->Drucken=="J"
      ::mayEditData:=LOGIN->StammDat=="J"
      ::mayShowData:=LOGIN->ZeigeDat=="J"
      ::infoOnly:=(empty(LOGIN->Passwort) .or. LOGIN->NurAusk=="J")
      ::saveWinPos:=LOGIN->SavePos=="J"
      ::saveWinSize:=LOGIN->SaveSize=="J"
      ::isGroupAccount:=LOGIN->Gruppe=="J"
      ::fontBold:=LOGIN->FontBold=="J"
      ::fontName:=trim(LOGIN->FontName)
      ::fontSize:=LOGIN->FontSize

      // developer only may edit info (help) text
      ::mayEditInfoText:=(::id==KURZEL_DEVEL)
    endif
  endif

  ::mayEditStock:=LOGIN->ArtLagBest=="J"
  ::mayEditTool:=LOGIN->Werkzeug=="J"
  ::mayPrintLabel:=LOGIN->Etikett=="J"
  ::mayEditVK:=LOGIN->VK_aend=="J"
  ::mayEditEK:=LOGIN->EK_aend=="J"
  ::mayEditGewicht:=LOGIN->Gewicht=="J"
  ::mayEditEnglishText:=LOGIN->Edit_Engl=="J"
  ::mayEditKonsigKd:=LOGIN->KLagKd=="J"
  ::mayEditIntrastat:=LOGIN->Intrastat=="J"
  if LOGIN->(fieldpos("IgnoreNK")) > 0 // FIXME: can be removed
    ::mayIgnoreNachkalk:=LOGIN->IgnoreNK=="J"
  else
    ::mayIgnoreNachkalk:=.f.
  endif

  ::mayEnterSysMenu:=LOGIN->SysMenu=="J"
  ::mayEnterBank:=LOGIN->Bank=="J"
  ::mayEnterMatEinAusg:=LOGIN->MatEinAusg=="J"
  ::mayEnterFakt:=LOGIN->Fakt=="J"
  ::DSGVO:=LOGIN->StammDat=="J"
  ::mayCreateInnerOrders:=LOGIN->BestellVor=="J"
  ::mayEnterNietGerat:=LOGIN->NietGerat=="J"

  ::mayCreateArticles:=LOGIN->ArtikelAnl=="J"
  ::mayEditArticleText:=LOGIN->ArtikelArt=="J"

  ::mayEnterMatMenu:=LOGIN->MatMenu=="J"

  // St�cklisten �ndern
  // M - Material
  // W - Werkzeug
  // V - Zeit
  // I - Instruktionen
  ::mayEditPartsList:=""
  if LOGIN->STK_MAT=="J"
    ::mayEditPartsList+="M"
  endif
  if LOGIN->STK_Wkz=="J"
    ::mayEditPartsList+="W"
  endif
  if LOGIN->STK_ZEIT=="J"
    ::mayEditPartsList+="V"
  endif
  if LOGIN->STK_INS=="J"
    ::mayEditPartsList+="I"
  endif


return self
/*----------------------------------------------------------------------*/

/** Setzt alle User Werte auf �bergegbenen Parameter, au�er Auskunft auf das Gegenteil */
METHOD setUserDefaults(superUser)
  default superUser:=.f.

  ::mayPrint:=superUser
  ::mayEditData:=superUser
  ::mayShowData:=superUser
  ::saveWinPos:=superUser
  ::saveWinSize:=superUser
  ::infoOnly:=!superUser

  ::mayEditTool:=superUser
  ::mayEditStock:=superUser
  ::mayEditGewicht:=superUser
  ::mayPrintLabel:=superUser
  ::mayEditVK:=superUser
  ::mayEditEK:=superUser
  ::mayEditKonsigKd:=superUser
  ::mayEditPartsList:=""
  ::mayEditEnglishText:=superUser
  ::mayEditKonsigKd:=superUser
  ::mayEditIntrastat:=superUser
  ::mayIgnoreNachkalk:=superUser

  ::mayCreateArticles:=superUser
  ::mayEditArticleText:=superUser
  ::mayEnterMatMenu:=superUser

return self
/** eom */
/*----------------------------------------------------------------------*/


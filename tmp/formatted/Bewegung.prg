/************************************************************************************
 * Class Bewegung
 *
 * repr�sentiert eine Artikel Bewegung,
   z.B. ext. AB -> Ausgang
        int. Auftag -> Eingang
        int. Auftag des Oberartikels -> Ausgang
        ext. Bestellung -> Eingang
 *
 * FIXME: sollte �ber Vererbung �ber versch. Klassen gel�st werden
 *
 ************************************************************************************/

#include "Miki.ch"
#include "hbclass.ch"

CLASS Bewegung

DATA artNr
DATA art
DATA menge INIT 0 // Rest-Menge == Menge - GeliefGes
DATA gesmenge INIT 0 // Gesamt Menge == Menge
DATA lgVor INIT 0
DATA lgNach INIT 0
DATA KW INIT space(5)
DATA nummer INIT ""
DATA inLfdNr INIT ""
DATA BesPostNr
DATA Datum INIT space(8)
DATA oberArtNr INIT ""

DATA AbPostNr
DATA AufNr INIT space(5)
DATA AufMenge INIT 0 // Rest-Menge == Menge - GeliefGes
DATA AufGesMenge INIT 0 // Gesamt Menge == Menge
DATA AufKW INIT ""
DATA AufArt
DATA AufDat INIT space(8)

DATA ignore INIT .f.
DATA tiefe INIT 0
DATA Grund INIT ""
DATA Faktor INIT 1

DATA cargo // generic field whatsoever
DATA cargo2 // generic field whatsoever
DATA cargo3 // generic field whatsoever
DATA cargo4 // generic field whatsoever

METHOD new()
METHOD compare(beweg2)
METHOD print(indent)
METHOD clone()

ENDCLASS

/*----------------------------------------------------------------------*/

METHOD new() CLASS Bewegung
RETURN self

/*----------------------------------------------------------------------*/

METHOD print(indent) CLASS Bewegung
  default indent:=0
  qout(::className())
  qout("artNr 		:",::artNr )
  qout("art 		:",::art )
  qout("menge 		:",::menge )
  qout("gesmenge	:",::gesmenge )
  qout("lgVor 		:",::lgVor )
  qout("lgNach 		:",::lgNach )
  qout("KW 		:",::KW )
  qout("nummer 		:",::nummer )
  qout("inLfdNr 	:",::inLfdNr )
  qout("BesPostNr	:",::BesPostNr)
  qout("Datum 		:",::Datum )
  qout("oberArtNr	:",::oberArtNr )

  qout("AbPostNr	:",::AbPostNr)
  qout("AufNr 		:",::AufNr )
  qout("AufMenge	:",::AufMenge )
  qout("AufGesMenge	:",::AufGesMenge )
  qout("AufKW 		:",::AufKW )
  qout("AufArt		:",::AufArt)
  qout("AufDat 		:",::AufDat )

  qout("ignore 		:",::ignore )
  qout("tiefe 		:",::tiefe )
  qout("Grund 		:",::Grund )
  qout("Faktor 		:",::Faktor )
  qout(replicate("-",20))
  qout()
RETURN self

/*----------------------------------------------------------------------*/


/** sortiere alle Bewegungen aufsteigend nach KW und dann absteigend nach Menge (Eingang immer zuerst!)
  *
  * Ergebnis: 1 oder mehr    = falls akt. Bew. vor     �bergebene Bew.
  *           0              = falls akt. Bew. gleich  �bergebene Bew.
  *          -1 oder weniger = falls akt. Bew. nach    �bergebene Bew.
  */

METHOD compare(beweg2) CLASS Bewegung
LOCAL result:=0

  // Bei beiden temp. Datens�tzen in Auferfass entscheidet die Tiefe
  // tieferer kommen zuerst, werden fr�her gebraucht
  // muss vor KW stehen, da diese bei neuen Posten erst sp�ter gesetzt wird
  if ::art $ BEW_AUFERFAS_E + BEW_AUFERFAS_O .and. beweg2:art $ BEW_AUFERFAS_E + BEW_AUFERFAS_O
    return ( ::tiefe - beweg2:tiefe )
  endif

  // vergleiche KW
  if (result:=kwKleiner(::kw , beweg2:kw)) <> 0 // ungleiche KW

    if KWempty(beweg2:kw)
      return 1
    endif
    if KWempty(::kw)
      return -1
    endif

    // bei "falscher" KW immer ans Ende
    if ( KWempty(beweg2:kw) .or. "*" $ beweg2:kw .or. "X" $ beweg2:kw )
      return 1
    endif
    if ( KWempty(::kw) .or. "*" $ ::kw .or. "X" $ ::kw )
      return -1
    endif

    return result
  endif

  // Wochenbedarf immer an den Anfang
  // if ::art $ BEW_WOCHEN_BEDARF
  // return 1
  // elseif beweg2:art $ BEW_WOCHEN_BEDARF
  // return -1
  // endif

  // Bei beiden temp. Datens�tzen aus ext. ABs entscheidet die Menge
  // if ::art <> beweg2:art

  // switch ::art
  // case BEW_AUFTRAG
  // if ::aufart=="K"
  // return -10
  // else
  // return -11
  // endif
  // case BEW_AUFTRAG_OBER
  // return -20
  // case BEW_AB_DISPO
  // return -30
  // case BEW_INNER_EIGEN
  // return -40
  // case BEW_INNER_OBER
  // return -50
  // case BEW_AUFERFAS_E
  // return -60
  // case BEW_AUFERFAS_O
  // return -70
  // case BEW_ARTRESERV
  // return -90
  // case BEW_BESTELLUNG
  // return -95
  // case BEW_WOCHEN_BEDARF
  // return -100
  // otherwise
  // altd() // ok, nur bei Fehler
  // endswitch

  // endif

  // neu 20220817, Bestellungen / Eing�nge immer zuerst
  if ::art == BEW_BESTELLUNG
    return 1
  endif
  if beweg2:art == BEW_BESTELLUNG
    return -1
  endif

  // // falls ein Datensatz nur ein temp. aus Auferfas ist, kommt dieser ans Ende
  // if ::art $ BEW_AUFERFAS_E + BEW_AUFERFAS_O
  // return -1
  // elseif beweg2:art $ BEW_AUFERFAS_E + BEW_AUFERFAS_O
  // return 1
  // endif

  // Ansonsten: vergleiche Mengen, seit 20192009 Ausg�nge immer zuerst
  result:=beweg2:menge - ::menge
  if result == 0 // gleiche Menge
    // Ansonsten: vergleiche Nummer
    if ::nummer < beweg2:nummer
      result:=1
    else
      result:=-1
    endif
  endif

return ( result )
  /** eom */

// Generic Clone Method
METHOD Bewegung:Clone()
LOCAL oClone:=Bewegung():New()

  // Manually copy each data member
  oClone:artNr:=::artNr
  oClone:art:=::art
  oClone:menge:=::menge
  oClone:gesmenge:=::gesmenge
  oClone:lgVor:=::lgVor
  oClone:lgNach:=::lgNach
  oClone:KW:=::KW
  oClone:nummer:=::nummer
  oClone:inLfdNr:=::inLfdNr
  oClone:BesPostNr:=::BesPostNr
  oClone:Datum:=::Datum
  oClone:oberArtNr:=::oberArtNr
  oClone:AbPostNr:=::AbPostNr
  oClone:AufNr:=::AufNr
  oClone:AufMenge:=::AufMenge
  oClone:AufGesMenge:=::AufGesMenge
  oClone:AufKW:=::AufKW
  oClone:AufArt:=::AufArt
  oClone:AufDat:=::AufDat
  oClone:ignore:=::ignore
  oClone:tiefe:=::tiefe
  oClone:Grund:=::Grund
  oClone:Faktor:=::Faktor
  oClone:cargo:=::cargo
  oClone:cargo2:=::cargo2
  oClone:cargo3:=::cargo3
  oClone:cargo4:=::cargo4

RETURN oClone

/************************************************************************************/
/* end of Class Bewegung
/************************************************************************************/


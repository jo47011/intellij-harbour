/***
*       Getsys.prg
*  Standard Clipper 5.2 GET/READ subsystem
*
*       NOTE: compile with /n/w
*
*  ************************************
*  WARNING: MODIFIED VERSION!!!!!!!!!!!
*  ************************************
*
*/

// #include "Set.ch"
#include "MyStd.ch"
#include "Inkey.ch"

#include "hbgtinfo.ch"
#include "Getexit.ch"

#define K_UNDO K_CTRL_U

// Sperr Kennzeichen
#define MERKMAL chr(149)
#define SPERR_COLOR "R/"+getBackColor()
#define SPERR_TRENNER "|"

// default input flags unless specified in procedure call
#define GETSYS_INKEY_FLAGS INKEY_KEYBOARD + INKEY_LDOWN


// workaround to save dgroup-memory !
_thread static _aSysStuff:={ NIL, .F., NIL, NIL, NIL, NIL,;
  NIL, NIL, NIL, NIL, NIL, NIL }


#xtranslate Format => _aSysStuff\[ GSV_FORMAT \]
#xtranslate slUpdated => _aSysStuff\[ GSV_UPDATED \]
#xtranslate KillRead => _aSysStuff\[ GSV_KILLREAD \]
#xtranslate BumpTop => _aSysStuff\[ GSV_BUMPTOP \]
#xtranslate BumpBot => _aSysStuff\[ GSV_BUMPBOT \]
#xtranslate LastExit => _aSysStuff\[ GSV_LASTEXIT \]
#xtranslate LastPos => _aSysStuff\[ GSV_LASTPOS \]
#xtranslate ActiveGet => _aSysStuff\[ GSV_ACTIVEGET \]
#xtranslate xReadVar => _aSysStuff\[ GSV_READVAR \]
#xtranslate ReadProcName => _aSysStuff\[ GSV_READPROCNAME \]
#xtranslate ReadProcLine => _aSysStuff\[ GSV_READPROCLINE \]
#xtranslate snNextGet => _aSysStuff\[ GSV_NEXTGET \]


// format of array used to preserve state variables
#define GSV_FORMAT 1
#define GSV_UPDATED 2
#define GSV_KILLREAD 3
#define GSV_BUMPTOP 4
#define GSV_BUMPBOT 5
#define GSV_LASTEXIT 6
#define GSV_LASTPOS 7
#define GSV_ACTIVEGET 8
#define GSV_READVAR 9
#define GSV_READPROCNAME 10
#define GSV_READPROCLINE 11
#define GSV_NEXTGET 12

#define GSV_COUNT 12

// Time-out variable
_thread static lTimedOut:=.F.
_thread static nTimeOut:=0

// Exit at Get variable
_thread static nAtGet

// STATIC hist:={} FIXME: we could store the history typed be the user


/***
*       ReadModal()
*       Standard modal READ on an array of GETs.
*/

FUNCTION ReadModal( GetList, nTime, nStartAt , nInkeyFlags , disableFocusEvents)

local get
local pos
local savedGetSysVars
local i // jojo

  default ninkeyFlags:=GETSYS_INKEY_FLAGS

  // added JG 26.2.2014
  // _aSysStuff:={ NIL, .F., NIL, NIL, NIL, NIL,NIL, NIL, NIL, NIL, NIL, NIL }
  // slUpdated:=.f.


  // set alte to var.txt
  // set alte on
  // for i:=1 to GSV_COUNT
  // qout(i,_aSysStuff[i])
  // next
  // close alte
  // altd()

  nTimeOut:=IF(nTime == NIL, 0, nTime)
  lTimedOut:=.F.

  if ( ValType(Format) == "B" )
    Eval(Format)
    end

    if ( Empty(getList) )
      // S87 compat.
      SetPos( MaxRow()-1, 0 )
      return (.f.) // NOTE
      end


      // preserve state vars
      savedGetSysVars:=ClearGetSysVars()

      // set these for use in SET KEYs
      ReadProcName:=ProcName(1)
      ReadProcLine:=ProcLine(1)


      IF nStartAt != NIL
        pos:=nStartAt

      ELSE

        // set initial GET to be read
        pos:=Settle( Getlist, 0 )

      ENDIF

      while ( pos <> 0 )

        // get next GET from list and post it as the active GET
        get:=GetList[pos]
        PostActiveGet( get )


        // read the GET
        if ( ValType( get:reader ) == "B" )
          Eval( get:reader, get ) // use custom reader block
        else
          GetReader( get , GetList , nInkeyFlags, disableFocusEvents ) // use standard reader
          end

    /* komplette Ausgabe der gesmaten GetListe ? , jojo */
          // if valtype(Get:cargo)=="C" .and. Get:cargo=="A"
          if getCargo(get,CARGO_DISP_GETLIST)
            for i:=1 to len(GetList)
              Getlist[i]:display()
            next
          endif

          nAtGet:=pos

          // move to next GET based on exit condition
          pos:=Settle( GetList, pos )

          end

          checkForceValid(GetList)


          // restore state vars
          RestoreGetSysVars(savedGetSysVars )

          // S87 compat.
          SetPos( MaxRow()-1, 0 )

          return (slUpdated)



/***
*       GetReader()
*       Standard modal read of a single GET.
*/
          static proc GetReader( get , GetList , nInkeyFlags , disableFocusEvents )

          // read the GET if the WHEN condition is satisfied
          if ( GetPreValidate(get) )

            // activate the GET for reading
            get:SetFocus()

            while ( get:exitState == GE_NOEXIT )

              // check for initial typeout (no editable positions)
              if ( get:typeOut )
                get:exitState:=GE_ENTER
                end

                // apply keystrokes until exit
                while ( get:exitState == GE_NOEXIT )
                  GetApplyKey( get, MyInkey(nInkeyFlags , disableFocusEvents ) , GetList )
                  end

                  // disallow exit if the VALID condition is not satisfied
                  if ( !GetPostValidate(get) )
                    get:exitState:=GE_NOEXIT
                    end

                    // // testing historie
                    // altd()
                    // if get:type=="C"
                    // aadd(hist,get:buffer)
                    // endif

                    end

                    // de-activate the GET
                    get:KillFocus()

                    end

                    return



/***
*       GetApplyKey()
*       Apply a single Inkey() keystroke to a GET.
*
*       NOTE: GET must have focus.
*/
                    proc GetApplyKey(get, key , GetList)

local cKey , i
local bKeyBlock

                    // check for SET KEY first
                    ifif;
                      ( (bKeyBlock:=SetKey(key)) <> NIL .and. .not. (key==K_CTRL_S .and.;
                      hb_gtinfo( HB_GTI_KBDSHIFTS );
                      != hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL ) ))
                    // Ausnahme CTRL-S and left arrow, only keblock for ctrl-s allowed (hmmmm)
                    GetDoSetKey(bKeyBlock, get)
                    return // NOTE
                    end


                    do case
                      //
                      // Time-out
                      //
                    CASE ( lTimedOut )
                      get:undo()
                      get:exitState:=GE_ESCAPE

                      // only when the CTRL key is pressed, since STRG_C has the same key code as PgDn :(
                      // must be before keyy==K_HOME
                      // CASE (key==K_CTRL_C .and. FT_CTRL())
                    CASE (key==K_CTRL_C .and. ;
                      hb_gtinfo( HB_GTI_KBDSHIFTS ) == hb_bitor( hb_gtinfo( HB_GTI_KBDSHIFTS ) , HB_GTI_KBD_CTRL ) )

                      hb_gtInfo( HB_GTI_CLIPBOARDDATA ,get:buffer )

                    case ( key == K_UP )
                      get:exitState:=GE_UP

                    case ( key == K_SH_TAB )
                      get:exitState:=GE_UP

                    case ( key == K_DOWN )
                      get:exitState:=GE_DOWN

                    case ( key == K_TAB )
                      get:exitState:=GE_DOWN

                    case ( key == K_ENTER ) .or. ( Key == K_CTRL_RETURN ) .or. (Key=K_F10)
                      // .or. key == K_LBUTTONDOWN // Maus / Mouse links
                      get:exitState:=GE_ENTER

                    case ( Key == HB_K_GOTFOCUS )
                      // aktuellen Satz neu lesen
                      if ! empty( alias() )
                        dbskip(0)
                      endif
                      // aktuelle Gets neu ausgeben
                      for i:=1 to len(GetList)
                        Getlist[i]:display()
                      next

                    case ( Key == K_LBUTTONDOWN ) .or. ( Key == K_LDBLCLK )
                      if Hittest( get, getList, mrow() , mCol() , .t. )
                        get:exitstate:=GE_MOUSEHIT
                        if Key == K_LDBLCLK
                          keyboard chr(HILFE_TASTE1)
                        endif
                      endif

                    case ( key == K_ESC )

                      if ( Set(_SET_ESCAPE) )
                        get:undo()
                        get:exitState:=GE_ESCAPE
                        end

                      case ( key == K_PGUP )
                        get:exitState:=GE_WRITE

                      case ( key == K_PGDN )
                        get:exitState:=GE_WRITE

                      case ( key == K_CTRL_HOME )
                        get:exitState:=GE_TOP


                        #ifdef CTRL_END_SPECIAL

                        // both ^W and ^End go to the last GET
                      case (key == K_CTRL_END)
                        get:exitState:=GE_BOTTOM

                        #else

                        // both ^W and ^End terminate the READ (the default)
                      case (key == K_CTRL_W)
                        get:exitState:=GE_WRITE

                        #endif


                      case (key == K_INS)
                        // Set( _SET_INSERT, !Set(_SET_INSERT) )
                        ChangeCursor()
                        ShowScoreboard()

                      case (key == K_UNDO)
                        get:Undo()

                      case (key == K_HOME)
                        get:Home()

                      case (key == K_END)
                        get:End()

                      case (key == K_RIGHT)
                        get:Right()

                      case (key == K_LEFT)
                        get:Left()

                      case (key == K_CTRL_RIGHT)
                        get:WordRight()

                      case (key == K_CTRL_LEFT)
                        get:WordLeft()

                      case (key == K_BS)
                        get:BackSpace()

                      case (key == K_DEL)
                        get:Delete()

                      case (key == K_CTRL_T)
                        get:DelWordRight()

                      case (key == K_CTRL_Y)
                        get:DelEnd()

                      case (key == K_CTRL_BS)
                        get:DelWordLeft()

    /* eigene Def. , jojo */
                      CASE (key==FKT_SPECIAL)
                        Get:exitState:=GE_ESCAPE

                      CASE (key== EDIT_QUIT)
                        Get:exitState:=GE_ESCAPE

                      CASE ( Key == KEY_SPECIAL )
                        Get:exitState:=GE_WRITE

                      CASE key == HB_K_GOTFOCUS
                        // nop
                      CASE key == HB_K_LOSTFOCUS
                        // nop
                      CASE key == HB_K_CLOSE
                        Error(getProperty("System.close.window.message","Programm bitte mit "+;
                          "Men�punkt 99 beenden."),.t.)

                      CASE key == HB_K_RESIZE
                        Get:exitState:=GE_RESIZE_EVENT

                      OTHERWISE

    /* Datum + - */
                        do case
                        case Get:type == "D"
                          if Key==K_PLUS
                            if empty(get:buffer) .or. get:buffer=="  .  .  "
                              Get:Buffer:=transform(getUser():date,Get:picture) // today
                            else
                              Get:Buffer:=transform(Get:untransform+1,Get:picture)
                            endif
                            Get:changed:=.t.
                            Get:display()
                            RETURN
                          elseif Key==K_MINUS
                            if empty(get:buffer) .or. get:buffer=="  .  .  "
                              Get:Buffer:=transform(getUser():date,Get:picture) // today
                            else
                              Get:Buffer:=transform(Get:untransform-1,Get:picture)
                            endif
                            Get:changed:=.t.
                            Get:display()
                            RETURN
                          elseif Key==K_MAL
                            Get:Buffer:=transform(getUser():date,Get:picture)
                            Get:changed:=.t.
                            Get:display()
                            RETURN
                          elseif Key==K_SPACE // Datum leeren
                            Get:delEnd()
                            RETURN
                          endif
                          // case "N" // Info: minus allein geht nicht, da keine absolute Eingabe von Minus m�glich ist
                          // if Key==K_PLUS .or. Key==KP_CTRL_PLUS
                          // Get:varPut(val(Get:buffer)+1)
                          // Get:updateBuffer()
                          // Get:changed:=.t.
                          // Get:display()
                          // RETURN
                          // elseif Key==KP_CTRL_MINUS
                          // Get:varPut(val(Get:buffer)-1)
                          // Get:updateBuffer()
                          // Get:changed:=.t.
                          // Get:display()
                          // RETURN
                          // endif
                          // exit
                        endcase
                        // ende jojo

                        if (key >= 32 .and. key <= 255)

                          cKey:=Chr(key)

                          if (get:type == "N" .and. (cKey == "." .or. cKey == ","))
                            get:ToDecPos()

                          else
                            if ( Set(_SET_INSERT) )
                              get:Insert(cKey)
                            else
                              get:Overstrike(cKey)
                              end

                              if (get:typeOut .and. !Set(_SET_CONFIRM) )
                                if ( Set(_SET_BELL) )
                                  beep()
                                  end

                                  get:exitState:=GE_ENTER
                                  end

                                  end

                                  end

                                endcase

                                return



/***
*       GetPreValidate()
*       Test entry condition (WHEN clause) for a GET.
*/
function GetPreValidate(get)

local saveUpdated
local when:=.t.


  if ( get:preBlock <> NIL )

    saveUpdated:=slUpdated

    when:=Eval(get:preBlock, get)

    get:Display()

    ShowScoreBoard()
    slUpdated:=saveUpdated

    end


    if ( KillRead )
      when:=.f.
      get:exitState:=GE_ESCAPE // provokes ReadModal() exit

    elseif ( !when )
      get:exitState:=GE_WHEN // indicates failure

    else
      get:exitState:=GE_NOEXIT // prepares for editing

      end

      return (when)



/***
*       GetPostValidate()
*       Test exit condition (VALID clause) for a GET.
*
*       NOTE: bad dates are rejected in such a way as to preserve edit buffer.
*/
function GetPostValidate(get)
local saveUpdated, objErr
local valid:=.t.
LOCAL bLastHandler

  if ( get:exitState == GE_ESCAPE .or. get:exitState == GE_RESIZE_EVENT )
    return (.t.) // NOTE
    end

    if ( get:BadDate() )
      get:Home()
      DateMsg()
      ShowScoreboard()
      return (.f.) // NOTE
      end


      // if editing occurred, assign the new value to the variable
      if ( get:changed )
        bLastHandler:=MyErrorBlock({ |objErr| lBreak(objErr) }) // stelle Break ein
        BEGIN SEQUENCE // krit. Bereich
          get:Assign()
          if ! getCargo(get,CARGO_UPDATE_IGNORE)
            slUpdated:=.t.
          endif
        RECOVER USING objErr
          MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
          // email(MY_EMAIL,"ERROR: GetSys (abgefangen)",getErrorText(objErr))
          if objErr:genCode == 34
            Error("Eingabewert zu gro�.")
          endif
        END SEQUENCE
        MyErrorBlock(bLastHandler) // stelle auf orignal-handler (errorsys)
      endif


      // debugging
      // set alte to c:\schrott\get.txt ADDITIVE
      // set alte on
      // qout(toString(get))
      // set alte off
      // wait

      // now we remeber the typeout value, needed for edit.prg if confirm is off, 20120316
      setCargo(get,CARGO_TYPEOUT,get:typeOut)

      // Info: wenn hier Posten verschwinden, kann es an einem Filter liegen
      // reset macht wohl einen dbskip(0) und aktualsiert die for clause eines index

      // reform edit buffer, set cursor to home position, redisplay
      get:Reset()

      // check VALID condition if specified
      if ( get:postBlock <> NIL )

        saveUpdated:=slUpdated

        // S87 compat.
        SetPos( get:row, get:col + Len(get:buffer) )

        valid:=Eval(get:postBlock, get)

        // reset compat. pos
        SetPos( get:row, get:col )

        ShowScoreBoard()
        get:UpdateBuffer()

        slUpdated:=saveUpdated

        if ( KillRead )
          get:exitState:=GE_ESCAPE // provokes ReadModal() exit
          valid:=.t.
          end

          end

          return (valid)




/***
*       GetDoSetKey()
*       Process SET KEY during editing.
*/
          proc GetDoSetKey(keyBlock, get)

local saveUpdated


          // if editing has occurred, assign variable
          if ( get:changed )
            get:Assign()
            slUpdated:=.t.
            end


            saveUpdated:=slUpdated

            // Eval(keyBlock, ReadProcName, ReadProcLine, ReadVar())
            // jojo
            EVAL( keyBlock, ReadProcName, Get , ReadVar() )

            ShowScoreboard()
            get:UpdateBuffer()

            slUpdated:=saveUpdated


            if ( KillRead )
              get:exitState:=GE_ESCAPE // provokes ReadModal() exit
              end

              return



/**************************
*
*       READ services
*
*/



/***
*       Settle()
*
*       Returns new position in array of Get objects, based on
*
*               - current position
*               - exitState of Get object at current position
*
*       NOTE return value of 0 indicates termination of READ
*       NOTE exitState of old Get is transferred to new Get
*/
static function Settle(GetList, pos)

local exitState

  if ( pos == 0 )
    exitState:=GE_DOWN
  else
    exitState:=GetList[pos]:exitState
    end


    if ( exitState == GE_ESCAPE .or. exitState == GE_WRITE .or. exitState == GE_RESIZE_EVENT )
      return ( 0 ) // NOTE
      end


      if ( exitState <> GE_WHEN )
        // reset state info
        LastPos:=pos
        BumpTop:=.f.
        BumpBot:=.f.

      else
        // re-use last exitState, do not disturb state info
        exitState:=LastExit

        end


        /***
        *       move
        */
        do case
        case ( exitState == GE_UP )
          pos --

        case ( exitState == GE_DOWN )
          pos ++

        case ( exitState == GE_TOP )
          pos:=1
          BumpTop:=.T.
          exitState:=GE_DOWN

        case ( exitState == GE_BOTTOM )
          pos:=Len(GetList)
          BumpBot:=.T.
          exitState:=GE_UP

        case ( exitState == GE_ENTER )
          pos ++

        CASE ( exitState < 0 .AND. -exitState <= LEN(GetList))
          pos:=-exitState
          exitState:=GE_NOEXIT

        CASE ( exitState == GE_MOUSEHIT )
          return ( snNextGet )

        endcase


        /***
        *       bounce
        */
        if ( pos == 0 ) // bumped top

          if ( !ReadExit() .and. !BumpBot )
            BumpTop:=.T.
            pos:=LastPos
            exitState:=GE_DOWN
            end

          elseif ( pos == Len(GetList) + 1 ) // bumped bottom

            if ( !ReadExit() .and. exitState <> GE_ENTER .and. !BumpTop )
              BumpBot:=.T.
              pos:=LastPos
              exitState:=GE_UP
            else
              pos:=0
              end
              end


              // record exit state
              LastExit:=exitState

              if ( pos <> 0 )
                GetList[pos]:exitState:=exitState
                end

                return (pos)



/***
*       PostActiveGet()
*       Post active GET for ReadVar(), GetActive().
*/
                static proc PostActiveGet(get)

                GetActive( get )
                ReadVar( GetReadVar(get) )

                ShowScoreBoard()

                return



/***
*       ClearGetSysVars()
*       Save and clear READ state variables. Return array of saved values.
*
*       NOTE: 'Updated' status is cleared but not saved (S87 compat.).
*/
static function ClearGetSysVars()

local saved[ GSV_COUNT ]

  saved[ GSV_KILLREAD ]:=KillRead
  KillRead:=.f.

  saved[ GSV_BUMPTOP ]:=BumpTop
  BumpTop:=.f.

  saved[ GSV_BUMPBOT ]:=BumpBot
  BumpBot:=.f.

  saved[ GSV_LASTEXIT ]:=LastExit
  LastExit:=0

  saved[ GSV_LASTPOS ]:=LastPos
  LastPos:=0

  saved[ GSV_ACTIVEGET ]:=GetActive( NIL )

  saved[ GSV_READVAR ]:=ReadVar( "" )

  saved[ GSV_READPROCNAME ]:=ReadProcName
  ReadProcName:=""

  saved[ GSV_READPROCLINE ]:=ReadProcLine
  ReadProcLine:=0

  saved[ GSV_NEXTGET ]:=snNextGet
  snNextGet:=0

  slUpdated:=.f.

return (saved)



/***
*   RestoreGetSysVars()
*       Restore READ state variables from array of saved values.
*
*       NOTE: 'Updated' status is not restored (S87 compat.).
*/
  static proc RestoreGetSysVars(saved)

  KillRead:=saved[ GSV_KILLREAD ]

  BumpTop:=saved[ GSV_BUMPTOP ]

  BumpBot:=saved[ GSV_BUMPBOT ]

  LastExit:=saved[ GSV_LASTEXIT ]

  LastPos:=saved[ GSV_LASTPOS ]

  GetActive( saved[ GSV_ACTIVEGET ] )

  ReadVar( saved[ GSV_READVAR ] )

  ReadProcName:=saved[ GSV_READPROCNAME ]

  ReadProcLine:=saved[ GSV_READPROCLINE ]

  snNextGet:=saved[ GSV_NEXTGET ]

return



/***
*       GetReadVar()
*       Set READVAR() value from a GET.
*/
static function GetReadVar(get)

local name:=Upper(get:name)


  // #ifdef SUBSCRIPT_IN_READVAR
local i

        /***
        *       The following code includes subscripts in the name returned by
        *       this function, if the get variable is an array element.
        *
        *       Subscripts are retrieved from the get:subscript instance variable.
        *
        *       NOTE: incompatible with Summer 87
        */

  if ( get:subscript <> NIL )
    for i:=1 to len(get:subscript)
      name += "[" + ltrim(str(get:subscript[i])) + "]"
    next
    end

    // #endif

    return (name)



/**********************
*
*       system services
*
*/



/***
*   __SetFormat()
*       SET FORMAT service
*/
function __SetFormat(b)
  Format:=if ( ValType(b) == "B", b, NIL )
return (NIL)


/***
*       __KillRead()
*   CLEAR GETS service
*/
  proc __KillRead()
  KillRead:=.t.
return

/** workaround jojo
*
* clear gets wird in std.ch -> readkill(.t.) uebersetzt
* diese Fkt. entspricht __killread()
*/
FUNCTION ReadKill( lKill )

LOCAL lSavKill:=KillRead

  IF ( PCOUNT() > 0 )
    KillRead:=lKill
  ENDIF

RETURN ( lSavKill )



/***
*       GetActive()
*/
function GetActive(g)
local oldActive:=ActiveGet
  if ( PCount() > 0 )
    ActiveGet:=g
    end
    return ( oldActive )


/***
*       Updated()
*/
function getUpdated()
return slUpdated

/***
*       ReadExit()
*/
function ReadExit(lNew)
return ( Set(_SET_EXIT, lNew) )


/***
*       ReadInsert()
*/
function ReadInsert(lNew)
return ( Set(_SET_INSERT, lNew) )



/**********************************
*
*       wacky compatibility services
*
*/


  // display coordinates for SCOREBOARD
  #define SCORE_ROW 0
  #define SCORE_COL 60


/***
*   ShowScoreboard()
*/
  static proc ShowScoreboard()

local nRow, nCol


  if ( Set(_SET_SCOREBOARD) )
    nRow:=Row()
    nCol:=Col()

    SetPos(SCORE_ROW, SCORE_COL)
    DispOut( if(Set(_SET_INSERT), "Ins", "   ") )
    SetPos(nRow, nCol)
    end

    return



/***
*       DateMsg()
*/
    static proc DateMsg()

local nRow, nCol


    if ( Set(_SET_SCOREBOARD) )
      nRow:=Row()
      nCol:=Col()

      SetPos(SCORE_ROW, SCORE_COL)
      DispOut("Invalid Date")
      SetPos(nRow, nCol)

      while ( Nextkey() == 0 )
        end

        SetPos(SCORE_ROW, SCORE_COL)
        DispOut("            ")
        SetPos(nRow, nCol)

        end

        return

/*****
 *
 * Time-Out?
 *
 */

FUNCTION TimedOut()
RETURN (lTimedOut)

/*****
 *
 * Time-Out feature
 *
 */

STATIC FUNCTION MyInKey(nInkeyFlags, disableFocusEvents )
LOCAL nKey

  nKey:=warte(nTimeOut, nInkeyFlags , disableFocusEvents )

  IF nKey == 0
    //
    // If after the wait time
    // keystroke is still 0
    // We are supposed to
    // get out of here.
    // So, lets do it
    //
    lTimedOut:=.T.
    __KillRead()

  ENDIF

RETURN (nKey)

/*****
 *
 * Go to a particular get
 *
 */

FUNCTION GoToGet(nGet)
  GetActive():exitState:=-nGet
RETURN (.T.) // !!!!NOTE!!!!

/*****
 *
 * What was the Get?
 *
 */

FUNCTION ExitAtGet()
RETURN (nAtGet)


/***
*
*  sperr_Reader()
*
*  READER zum Sperren/Entspaerren eines einzelnes GETs
*
*  Parameter:   Getliste        A
*               Sperren         L
*               Anzeige         C
*               SperrPreset     A   - FelderVorgabe zum Sperren
*               SperrReset      B   - alle Sperren aufheben, default .f.
*/

PROCEDURE Sperr_Reader( GetList , Sperren , Anzeige , SperrPreset, SperrReset)
LOCAL Taste:=0
LOCAL Get , i , j , Pos
LOCAL akt_Farbe:=setcolor()
LOCAL savedGetSysVars
LOCAL ninkeyFlags:=GETSYS_INKEY_FLAGS
LOCAL sperrName, allSperrungen


  _thread static Auswahl:=""
  _thread static SperrCaller:="" // nur beim 1. (gleichen) Level ist sperren erlaubt

  default Sperren:=.f.
  default SperrReset:=.f.

  /* Sperrung l�schen ? */
  // FIXME: nur der caller sollte reseted(blaDisp() oder so sein)
  if SperrReset
    Auswahl:=""
    SperrCaller:=""
    RETURN
  endif

  if sperren .and. empty(SperrCaller)
    SperrCaller:=procName(1)
  endif

  // �bernehme Vorauswahl von Sperrung, if any
  if valtype(SperrPreset) = "A"
    for each sperrName in SperrPreset
      Auswahl += sperrName + SPERR_TRENNER
    next
  endif

  /* Ausgabe der bisherigen Auswahl */
  if SperrCaller==procName(1) .and. ! empty( Auswahl )
    setcolor(SPERR_COLOR)
    allSperrungen:=HB_ATokens( Auswahl , SPERR_TRENNER )

    // wir gehen hier die Sperrungen durch und nicht alle gets,
    // da i.d.R. KEINE Sperrung besteht
    for each sperrName in allSperrungen

      if ! empty(SperrName) // Info: the last one is empty as we always finish substring with SPERR_TRENNER

        // suche get in GetList
        pos:=aScan( GetList , { |oGet| oGet:name == sperrName } )
        if pos = 0
          // Info: kann passieren bei nested getlists
          // FIXME: wie bei Umgebung sollten wir uns die Sperrung je Caller merken...
          // Trouble("root", { "Sperr-Name nicht gefunden:" + sperrName } )
        else
          SETPOS( GetList[pos]:row, GetList[pos]:col-1)
          QQOut(MERKMAL)
        endif
      endif

    next
    setcolor(akt_farbe)
  endif

  if ! valtype(Anzeige)=="U" // nur Ausgabe selektiert !
    RETURN
  endif

  /* keine Sperrung vorhanden und keine Sperrung gew�nscht */
  if (! sperren .and. empty(Auswahl)) .or. (! empty(SperrCaller) .and. SperrCaller<>procName(1))
    ReadModal(GetList,,,nInkeyFlags)
    RETURN
  endif

  /* jojo ??? sbFormat ? */
  IF ( VALTYPE( Format ) == "B" )
    EVAL( Format )
  ENDIF

  // preserve state vars
  savedGetSysVars:=ClearGetSysVars()

  // set these for use in SET KEYs
  ReadProcName:=ProcName(1)
  ReadProcLine:=ProcLine(1)

  // ACHTUNG: beim editieren von gesperrten Feldern keine Maus-Selektion m�glich!
  ninkeyFlags:=INKEY_KEYBOARD

  /* erstes Get bestimmen */
  Pos:=Settle( Getlist, 0 )

  // gehe alle GETs durch
  do while !( Pos == 0 ) .and. Pos <= len(GetList)

    // N�chstes Get bestimmen und aktivieren
    get:=GetList[pos]
    nAtGet:=pos
    PostActiveGet( get )

    /* 2 F�lle:
    * 1. Sperrungen �ndern */
    if Sperren
      if (get:Name + SPERR_TRENNER) $ Auswahl
        Message("@LEER-Taste@ = entsperren        @ESC@=Ende")
      else
        Message("@LEER-Taste@ = sperren           @ESC@=Ende")
      endif

      SETPOS( Get:row, Get:col-1)
      if (get:Name + SPERR_TRENNER) $ Auswahl
        setcolor(COLINV)
      endif

      QQOut(chr(16))
      setcolor(akt_farbe)

      do while Taste<>K_SPACE .and. Taste<>K_UP .and. Taste<>K_DOWN;
        .and. Taste<>K_PGDN .and. Taste<>K_LBUTTONDOWN .and. ! ABBRUCH
        Taste:=warte( 0 )
      enddo

      SETPOS( Get:row, Get:col-1)
      if (get:Name + SPERR_TRENNER) $ Auswahl
        setcolor(SPERR_COLOR)
        QQOut(MERKMAL)
        setcolor(akt_farbe)
      else
        setcolor(akt_farbe)
        QQout(" ")
      endif

      if ABBRUCH .or. Taste==K_PGDN
        RETURN
      endif

      // Mause / Mouse selektiert gew�hlten Datensatz sofort
      if Taste == K_LBUTTONDOWN .and. Hittest( get, getList, mrow() , mCol() , .f. )
        pos:=snNextGet
        get:=GetList[pos]
        PostActiveGet( get )
      endif

      do case
      case Taste == K_UP
        Pos--
      case Taste == K_DOWN
        Pos++
      otherwise
        // LeerTaste gedr�ckt
        SETPOS( Get:row, Get:col-1)

        // war selektiert -> selektion l�schen
        if (get:Name + SPERR_TRENNER) $ Auswahl

          j:=at( get:name + SPERR_TRENNER , Auswahl )
          if j = 0 // should never happen
            Trouble("root", { "Sperr-Name nicht gefunden:" + get:name } )
          else
            Auswahl:=left(Auswahl,j-1)+substr( Auswahl ,j + len( get:name ) + 1 )
            QQout(" ")
          endif
        else

          // neue Selektion hinzuf�gen
          Auswahl += get:name + SPERR_TRENNER
          setcolor(SPERR_COLOR)
          QQOut(MERKMAL)
          setcolor(akt_farbe)
        endif
        Pos++
      endcase
      Taste:=0

    else
      // 2. normales �ndern der Gets

      if empty(Auswahl) .or. (get:name + SPERR_TRENNER) $ Auswahl
        // Aktives GET �ber den Reader einlesen
        GetReader( Get , GetList , nInkeyFlags ) // Standard reader
      endif

      // komplette Ausgabe der gesamten GetListe ?
      // if valtype(Get:cargo)=="C" .and. Get:cargo=="A"
      if getCargo(get,CARGO_DISP_GETLIST)
        for i:=1 to len(GetList)
          Getlist[i]:display()
        next
      endif

      // Zum n�chsten GET, abh�ngig vom Verlassen des aktuellen GETs
      Pos:=Settle( GetList, Pos )
    endif

  enddo

  checkForceValid(GetList)

  // restore state vars
  RestoreGetSysVars(savedGetSysVars)

RETURN

// unschoen, aber geht...
Function ValidClauseOK(get)
LOCAL result,preCond

  PostActiveGet(get)
  preCond:=GetPreValidate(get)
  // keyboard K_ESC
  get:SetFocus()
  result:=Eval(get:postBlock, get)
  get:KillFocus()

  if ! result .and. ! preCond
    // we bail out to avoid loop here
    return .t.
  endif

return result

  /** pr�ft ob alle Pflicht Valid Clauses erf�llt sind
  *
  * ACHTUNG: Methodennamen nicht �ndern wird in Datei.prg abgefragt :(
  * FIXME!
  */
PROCEDURE checkForceValid(GetList)
LOCAL i,get

  // pr�fe Ausnahme zuerst: hat letztes Feld hat cargo==FORCE_EXIT_ALLOWED
  get:=Getlist[nAtGet]
  // if valtype(Get:cargo)=="C" .and. Get:cargo==FORCE_EXIT_ALLOWED
  if getCargo(get,CARGO_EXIT_ALLOWED)
    return
  endif

  for i:=1 to len(GetList)
    get:=Getlist[i]
    // if valtype(Get:cargo)=="C" .and. Get:cargo==FORCE_VALID
    if getCargo(get,CARGO_FORCE_VALID)
      do while !ValidClauseOK(get)
        keyboard ""
        // besser: spezielle Warnung/Hinweis in post block verwenden!
        // Error(ACHTUNG+" "+get:name+" muss eingegeben werden.",.t.)
        GetReader( get , GetList ) // use standard reader
      enddo
    endif
  next
return
/** eop */

// /** l�scht alle Force_Valid flags der akt. Getlist */
  // Function DeleteForceValid(getList)
  // LOCAL i,get
  // for i:=1 to len(GetList)
  // get:=Getlist[i]
  // if valtype(Get:cargo)=="C" .and. Get:cargo==FORCE_VALID
  // Get:cargo:=nil
  // endif
  // next
  // return .t.

/** Setzt den entsprechenden Cargo-Wert des get Objects
  *
  */
procedure setCargo(oGet,type,value)
LOCAL tempArray[CARGO_MAX_VALUE]

  if oGet:cargo==NIL
    // init cargo & set default values
    oGet:cargo:=tempArray
    oget:cargo[CARGO_FORCE_VALID]:=.f.
    oget:cargo[CARGO_EXIT_ALLOWED]:=.f.
    oget:cargo[CARGO_DISP_GETLIST]:=.f.
    oget:cargo[CARGO_TYPEOUT]:=.f.
    oget:cargo[CARGO_UPDATE_IGNORE]:=.f.
  endif

  if type<>NIL
    oget:cargo[type]:=value
  endif

return
/** eop */

/** Liefert den entsprechenden Cargo-Wert des get Objects
  *
  */
function getCargo(oGet,type)
LOCAL tempArray[CARGO_MAX_VALUE]

  if oGet:cargo==NIL
    return .f.

    // better would be this, but maybe overkill
    // init cargo & set default values
    // setCargo(oGet)
  endif

return oget:cargo[type]
/** eof */

function HitTest( get, GetList, MouseRow, MouseCol , evalPost )
local nCount, nTotal , nPos

  snNextGet:=0
  nTotal:=Len( GetList )

  for nCount:=1 to nTotal
    if ( GetList[ nCount ]:HitTest( MouseRow, MouseCol ) != 0 )
      // // au�er falls gesperrt und nicht in gesperrt selektion
      // if ! empty(Auswahl) .and. ! str(nCount,3) $ Auswahl
      // return .f.
      // endif
      snNextGet:=nCount
      exit
    endif
  next

  if ( snNextGet <> 0 ) .and. ! GetPrevalidate( GetList[ snNextGet ] )
    snNextGet:=0
  elseif evalPost

    // alle post validates pr�fen, damit keine Pflichtfelder �bersprungen werden
    nPos:=aScan( GetList, { |x| get==x } )
    nPos++ // das aktuelle Get wird eh gepr�ft, lassen wir also aus
    if nPos < snNextGet
      for nCount:=nPos to snNextGet-1
        if GetPreValidate( GetList[ nCount ] )
          // activate the GET for reading
          GetList[ nCount ]:SetFocus()
          if ! GetPostValidate( GetList[ nCount ] )
            // Error(ACHTUNG+" "+GetList[ nCount ]:name+" muss eingegeben werden.",.t.)
            snNextGet:=nCount
          endif
          // de-activate the GET
          GetList[ nCount ]:KillFocus()
        endif
      next
    endif

  endif

return ( snNextGet != 0 )
/** eof */

/*
* fuellt den Oget:Buffers mit gew. Zeichen von links her auf, bis er voll ist
*/
FUNCTION oFill(oGet,fill_Char,emptyAllowed)
LOCAL Inhalt:=alltrim(oGet:buffer)

  default fill_char:=FILL_CHAR

  if emptyAllowed .and. empty(oGet:buffer)
    return .t.
  endif

  oGet:varput(right(Replicate(fill_char,len(oGet:Buffer))+Inhalt,len(oGet:Buffer)))
  oget:updateBuffer()
  oGet:display()

RETURN(.t.)
/* EOF fill */


# TODOs

- db viewer
  - dbf file open in project explorer, right click => not available


- new: 
- tab completion: ctrl tab?
- structure view, methode in der der Cusror steht sollte ge-highlighted werden
- refactor: in Methode auslagern
- hotkey zum linten des aktuellen programms => settings oder als commando mit default key
- ctrl-T toggle
- Klammer auf eingeben -> Klammer zu automatisch => konfigurierbar, default=False

Bugs:
- F2 on include miki.ch => Cannot perform refactoring.
                            Caret should be positioned at symbol to be renamed

- reformat listen2.prg => a lot of errors esp. for existing ;

- code completion: e.g. PROCEDURE Auf_KundListe()
  ferase(Temp->ctrl-space) => local tempDatei wird nicht vorgeschlagen

  ebenso linting s. workspace/screenshot

- using printDebugStackTrace() only works inside pycharm, how to compile otherwsie?
hbmk2: Compiling resources...
hbmk2: Compiling...
hbmk2: Linking... hbmiki.exe
.hbmk/win/mingw/errorsys.o:errorsys.c:(.data+0x1e8): undefined reference to `HB_FUN_PRINTDEBUGSTACKTRACE'
collect2.exe: error: ld returned 1 exit status



# TODOs

## Debugging Improvements

- **Process Coupling**: Debugging process in PyCharm and running GUI should be coupled
  - if one ends or crashes, the other should be stopped

- code completion should propose local and public vars as well
  as well as constants, e.g. Error(TRY_AGAIN)

indentation:
- indent newly type code to current level, e.g.
  if ! valtype(objErr)=="O"
    Error("Kein Error-Objekt übergeben: Art.Bestand"+SCHWERER_FEHLER)
  endif

Qout("This is added afterwards and should be indented as other code, works on reformat action")

  if ( objErr:genCode == EG_DATAWIDTH  )

- code inside BEGIN SEQUENCE, RECOVER USING and END SEQUENCE should be indented. 
  The keywords BEGIN SEQUENCE, RECOVER USING and END SEQUENCE should be highlighted like if,endif, etc.


- Linting, see https://github.com/APerricone/harbourCodeExtension/wiki/Diagnostics-Lint

- making-of schreiben:
    - Erfahrung O1 Pro vs claude, evtl. als Tabelle
    - mein prompt Vorgaben etc.


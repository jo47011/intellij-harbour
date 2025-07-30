# TODOs

## Debugging Improvements

- **Process Coupling**: Debugging process in PyCharm and running GUI should be coupled - if one ends or crashes, the other should be stopped

- **Console Output**: Improve stderr/stacktrace handling in PyCharm console (rolled back pending redesign)


code formatting
- indentation
    - should be correct while you type / after return
    - only return at eof should be left aligned, e.g. this not:
      if ...
      ...
      RETURN
      endif

- code completion should propose local and public vars as well
  as well as constants, e.g. Error(TRY_AGAIN)

- debugging: ALT-F8 evaluator or alike not avaiable

- Debugger not showing static vars


- Linting, see https://github.com/APerricone/harbourCodeExtension/wiki/Diagnostics-Lint

- making-of schreiben:
    - Erfahrung O1 Pro vs claude, evtl. als Tabelle
    - mein prompt Vorgaben etc.


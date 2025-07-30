# TODOs

## Debugging Improvements

- **Process Coupling**: Debugging process in PyCharm and running GUI should be coupled - if one ends or crashes, the other should be stopped

- **Console Output**: Improve stderr/stacktrace handling in PyCharm console (rolled back pending redesign)

The following files are still written to the project dir, either remove or move to.hbmk (from settings):
- debug_entry_handler.log  debug_trace.log  error_handler_init.log  init_called.log  sendlocals_trace.log

code formatting
- refactor -> reformat no longer there?
- Tab should have the same as indent (2 in my case)
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

- Settings: provide for flag rebuild yes/no

- Settings: Harbour Fily Types should support *.prg and *.ch not *.hb


- Linting, see https://github.com/APerricone/harbourCodeExtension/wiki/Diagnostics-Lint

- making-of schreiben:
    - Erfahrung O1 Pro vs claude, evtl. als Tabelle
    - mein prompt Vorgaben etc.


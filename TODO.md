# TODOs

- add database viewer

- when typing endif it is not unindented after return

  if foo
    qout(Bla)
    endif <RETURN>   <= should be unindented after return

- debugger:
  - arrays should be unfoldable in var view
  - Expression evaluation not yet implemented for: aentry[1]
  - can we somehow mark bp w/ a condition so you see it may not always stop

- startup: scanning harbour project files hangs at 8/111 or so

- navigation
  - CLASS NegVerfuegItem<= not navigatable pls fix

- code completion
  - rech:faell <ctrls-space> should propose matching methods and data fields

- db viewer
  - Record Navigation (Previous/Next buttons)
  - Live Updates (Auto-refresh on record changes)
  - Advanced Views (Table grid, index browsing)

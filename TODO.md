# TODOs

Testen:
- startup: scanning harbour project files hangs at 8/111 or so
- harbour dbf view icon -> always to "Bottom right"

- navigation
  - CLASS NegVerfuegItem<= not navigatable pls fix
  - define definition in ch files not found, should be at top like func names etc.

- code completion
  - rech:faell <ctrls-space> should propose matching methods and data fields
  - Error(TRY_ ctrl-space => should deliver TRY_AGAIN from ch file

- db viewer
  - dbf file open in project explorer, right click => not available

- debugger
  - harbour stack should display entire call history

indentation:
- endif return not unindented

new: tab completion: ctrl tab?

---

check:

fyi the files defined as excluded in the harbour settings should also be discarded from indexing
---

unix plugin:

Scanning harbour project files hangs, see screenshot
see logs in workspace/log-unix
and workspace/hbmiki-test for idea log

2. File size limit - Skips files > 5MB to prevent memory issues

=> this is not an option pls undo
-----


# TODOs

- add database viewer

- when typing endif it is not unindented after return

  if foo
    qout(Bla)
    endif <RETURN>   <= should be unindented after return

- debugger:
  - arrays should be unfoldable in var view
  - Expression evaluation not yet implemented for: aentry[1] same for aMaxRech:rechNr
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


---

what happens during startup while the progessbar: Scanning Harbour Project Files is shown?
It is not really processing, seems to stop/hang each start at after a different number:
11/111 or 27/111 or 37/111

=> if you can fix it but anyways show me a list of files that you are scanning.

---
dbf file open in project explorer, right click => not available

pls explain where it should show up.
---

1. Cache Check When Coming Back to Panel (Lines 293-329):

Line 293: if (nodeText.startsWith("Fields")) {
Line 294:     if (cache.fieldData != null) {  // SET BP HERE - Check if cache exists
Line 295:         displayFieldData(workarea, cache.fieldData);  // Shows cached data
Line 296:         HarbourLogger.log(..., "Showing cached fields");

Line 307: } else if (nodeText.equals("Current Record")) {
Line 308:     if (cache.recordData != null) {  // SET BP HERE - Check if cache exists
Line 309:         displayRecordData(workarea, cache.recordData);  // Shows cached data

Line 320: } else if (nodeText.equals("Schema Info")) {
Line 321:     if (cache.schemaData != null) {  // SET BP HERE - Check if cache exists
Line 322:         displaySchemaData(workarea, cache.schemaData);  // Shows cached data

2. Auto-Load When Data Arrives (Lines 458-470, 519-531):

Line 458: if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) &&
"Fields".equals(waitingForDataType)) {
Line 459:     shouldDisplay = true;  // SET BP HERE - Auto-load trigger for Fields
Line 470:     displayFieldData(workarea, fieldData);  // Actually display

Line 519: if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) &&
"Record".equals(waitingForDataType)) {
Line 520:     shouldDisplay = true;  // SET BP HERE - Auto-load trigger for Record
Line 531:     displayRecordData(workarea, recordData);  // Actually display

3. Setting Waiting State (Lines 300-303, 313-316):

Line 300: showLoadingMessage("Fields");
Line 301: waitingForWorkarea = alias;  // SET BP HERE - Setting waiting state
Line 302: waitingForDataType = "Fields";

Line 313: showLoadingMessage("Current Record");
Line 314: waitingForWorkarea = alias;  // SET BP HERE - Setting waiting state
Line 315: waitingForDataType = "Record";

Key Breakpoints Summary:

- Line 294, 308, 321: Check if cache exists when clicking
- Line 301, 314, 327: Setting waiting state when no cache
- Line 459, 520: Auto-display trigger when data arrives
- Line 470, 531: Actual display call

Set these breakpoints to trace:
1. Click on panel → Line 294/308/321 (cache check)
2. If cache exists → Line 295/309/322 (show cached)
3. If no cache → Line 301/314/327 (set waiting)
4. Data arrives → Line 459/520 (check waiting)
5. Auto-display → Line 470/531 (display data)

----

harbour dbf icon -> always to "Bottom right"
# TODOs

## Debugging Improvements

- **Process Coupling**: Debugging process in PyCharm and running GUI should be coupled
  - if one ends or crashes, the other should be stopped

- runtime error e.g. menu 42
 
- Linting, see https://github.com/APerricone/harbourCodeExtension/wiki/Diagnostics-Lint

- making-of schreiben:
    - Erfahrung O1 Pro vs claude, evtl. als Tabelle
    - mein prompt Vorgaben etc.


---

from INIT_PROCEDURES_EXPLANATION.md:

### 2. **SetGlobalErrorHandler()** in `harbour_debug.prg:61`
- **Status**: ❌ INACTIVE - Commented out with `/*`
- **Purpose**: Was intended to set up global error handling
- **Why commented**: Says "REMOVED: INIT procedures can interfere with program startup in debug mode"
- **Result**: This INIT procedure is NOT executed

if it is no longer needed or used, pls remove.
# Lessons Learned - Harbour IntelliJ Plugin

## Formatting Issues

### Continuation Lines and Block Indent Tracking

**Issue (v1.2.57)**: When an `if`/`while`/`for` statement has continuation lines (e.g., `if cond .and.;`), subsequent lines inside the block (like `RETURN` and `endif`) get wrong indentation.

**Root Cause**: Lines ending with continuation patterns (`.and.;`, `.or.;`, etc.) trigger `shouldPreserveCompletely=true`. This causes the formatter to skip ALL processing including the critical `indentLevel++` increment for block-opening statements.

**Fix**: Inside the `shouldPreserveCompletely` block, added explicit `indentLevel++` logic for `if`/`while`/`for`/`do`/`switch` statements. This ensures the indent level is tracked correctly even when the line content is preserved.

**Key Learning**: When adding "preserve line" logic, always verify that indent tracking and other state updates still occur. The `continue` statement can silently skip critical updates.

### RETURN Indentation Context

**Issue (v1.2.56)**: `returnIndent` setting was applied to ALL return statements, including those inside control structures.

**Rule**: `returnIndent` setting (default: 0 spaces) applies ONLY to RETURN at the end of a function/method (where `indentLevel == 1`). RETURN inside control structures uses normal block indentation.

### RETURN Pattern Matching

**Issue (v1.2.56)**: `RETURN(.t.)` not matched by pattern because old regex required space after RETURN.

**Fix**: Changed pattern from `^\\s*RETURN(?:\\s+.*)?$` to `^\\s*RETURN(?:\\s*\\(.*\\)|\\s+.*)?$` to allow parentheses without space.

**Key Learning**: Test regex patterns with all common variants: `RETURN`, `RETURN .t.`, `RETURN(.t.)`, `RETURN(x)`, `RETURN NIL`.

### Comment Indentation Inside Function Body

**Issue (v1.2.58)**: Comments (`// comment`) at the start of a function body (after `FUNCTION` but before any code) were not being indented.

**Root Cause**: Comment indentation logic used `previousLineActualIndent`, which was 0 after a function declaration. Comments inside function body should use `indentLevel * indentSize` instead.

**Fix**: Added `else if (inFunctionBody)` condition to use current `indentLevel` for comments when inside a function body.

**Key Learning**: Comments should follow the block indent level, not the previous line's actual indent, when at the start of a block.

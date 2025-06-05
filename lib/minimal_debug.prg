// Minimal debug stub - does absolutely nothing
// Just provides __dbgEntry function to satisfy static library requirement

// No includes, no constants, just the bare minimum

// Main debug entry point - does nothing
PROCEDURE __dbgEntry(nMode, uParam1, uParam2, uParam3)
   // Do absolutely nothing - just return
RETURN

// Dummy function to initialize if needed
FUNCTION __InitIntelliJDebugger()
RETURN .T.
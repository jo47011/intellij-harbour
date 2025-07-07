# Windows Console Debugging Strategy - 4 Cases Analysis

## Current Status

We have 4 debugging cases with the following status:
- ✅ Unix GUI → internal harbour debug in popup gui (works)
- ✅ Unix Console → pycharm debugger running in pycharm console only (works)  
- ✅ Windows GUI → internal harbour debug in popup gui (works)
- ❌ Windows Console → pycharm debugger running in pycharm console only (NOT working - opens separate console window)

**CRITICAL**: Cases 1-3 are working and must NOT be changed. Only case 4 needs to be fixed.

## Problem Analysis

The issue is specifically with Windows console debugging opening a separate console window instead of using PyCharm's internal console. This works perfectly on Unix but fails on Windows.

## Research Findings

### 1. PyCharm Console Window Separation Issues

From JetBrains documentation and community reports:

- **Known Windows Limitation**: PyCharm has known issues with console window separation on Windows
- **Tool Window Structure**: Run and Debug are separate "tool windows" in PyCharm and cannot be merged
- **External Console Problem**: On Windows with certain compilers (like mingw w64), stdout goes to separate Windows cmd/console window instead of IDE console
- **No Direct Fix**: JetBrains states "At the moment it is not possible to do this on Windows. There is no ETA on this, but there is a task on their tracker to follow the progress."

### 2. IntelliJ Platform Process Handling

#### CommandLineState and OSProcessHandler
The standard approach for IntelliJ plugins:

```java
// Basic pattern used in IntelliJ plugins
GeneralCommandLine generalCommandLine = new GeneralCommandLine(cmds);
generalCommandLine.setCharset(Charset.forName("UTF-8"));
generalCommandLine.setWorkDirectory(project.getBasePath());
ProcessHandler processHandler = new OSProcessHandler(generalCommandLine);
processHandler.startNotify();
```

#### Console Output Redirection
- **Internal Console Creation**: `TextConsoleBuilderFactory.createBuilder(project).getConsole()` creates a ConsoleView instance
- **Process Attachment**: `ConsoleView.attachToProcess()` attaches it to process output
- **Automatic Console**: When using CommandLineState, a console view is automatically created and attached

#### Windows-Specific Considerations
- **BaseOSProcessHandler**: Has `processHasSeparateErrorStream()` that returns true by default
- **Error Stream Handling**: Windows processes often have separate error streams that need special handling
- **Process Creation**: IntelliJ handles process console windows through its own ConsoleView system rather than platform-specific flags

### 3. Key Technical Solutions to Investigate

#### Option A: Windows Process Creation Flags
```java
// Potential Windows-specific settings
if (System.getProperty("os.name").toLowerCase().contains("windows")) {
    // Windows-specific console handling
    commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
    // Possible CREATE_NO_WINDOW equivalent through IntelliJ APIs
}
```

#### Option B: Console Output Redirection
```java
// Force output redirection to internal console
commandLine.setRedirectErrorStream(true);

// Windows-specific environment variables
if (isWindowsConsole) {
    commandLine.withEnvironment("HIDE_CONSOLE", "1");
    // Prevent console window creation
}
```

#### Option C: Process Listener for Output Capture
```java
// Capture all process output for Windows console programs
processHandler.addProcessListener(new ProcessAdapter() {
    @Override
    public void onTextAvailable(@NotNull ProcessEvent event, @NotNull Key outputType) {
        // Redirect output to PyCharm console instead of separate window
    }
});
```

### 4. Analysis of Working vs Non-Working Cases

#### Why Unix Works but Windows Doesn't
1. **Process Creation Differences**: Unix processes inherit console from parent, Windows creates new console windows
2. **GT Driver Behavior**: `-gtSTD` behaves differently on Windows vs Unix
3. **Environment Inheritance**: Console environment variables work differently on Windows
4. **Harbour Compiler**: hbmk2 may create console windows differently on Windows

#### Current Working Code Pattern (Cases 1-3)
```java
// GUI Programs (Working on both platforms)
if (isGui) {
    parameters.add(buildDir + "/harbour_debug.prg");
    parameters.add("-b");
    parameters.add("-run");
    parameters.add("-DFORCE_DEBUG_MODE=1");
    // ... GUI flags
    commandLine.withEnvironment("ALTD", "BREAK");
}

// Console Programs (Working on Unix, not Windows)
else {
    parameters.add(buildDir + "/harbour_debug.prg");
    parameters.add("-b");
    parameters.add("-run");
    parameters.add("-gtSTD");  // This works on Unix, creates separate window on Windows
    commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
}
```

## Proposed Solutions

### Solution 1: Windows-Specific Console Redirection
```java
// Only modify Windows console case
if (!isGui && System.getProperty("os.name").toLowerCase().contains("windows")) {
    // Windows console: Use different approach
    commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
    commandLine.setRedirectErrorStream(true);
    // Additional Windows-specific flags to prevent separate console
}
```

### Solution 2: Alternative GT Driver for Windows
```java
// Different GT driver for Windows console programs
if (!isGui) {
    if (System.getProperty("os.name").toLowerCase().contains("windows")) {
        // Use different GT driver that doesn't create separate window
        parameters.add("-gtNUL");  // Or other non-console GT driver
    } else {
        parameters.add("-gtSTD");  // Keep Unix behavior
    }
}
```

### Solution 3: Process Output Capture and Redirection
```java
// For Windows console programs: capture output and redirect to IntelliJ console
if (!isGui && System.getProperty("os.name").toLowerCase().contains("windows")) {
    // Create custom process handler that captures all output
    // and redirects to PyCharm's internal console
}
```

## Implementation Strategy

### Phase 1: Research Current Implementation
1. Analyze current `HarbourDebuggerRunProfileState.java`
2. Identify exact code path for Windows console programs
3. Determine why Unix console works but Windows doesn't

### Phase 2: Minimal Windows-Only Fix
1. Add Windows detection in console program path only
2. Implement Windows-specific console handling
3. Preserve all existing working cases (1-3)

### Phase 3: Testing
1. Test Unix GUI (must still work)
2. Test Unix Console (must still work)  
3. Test Windows GUI (must still work)
4. Test Windows Console (should now work)

## Files to Investigate/Modify

1. **HarbourDebuggerRunProfileState.java** - Main execution logic
2. **HarbourDebuggerRunConfig.java** - Configuration handling
3. **HarbourDebuggerRunner.java** - Debug runner logic

## Success Criteria

- ✅ Unix GUI debugging unchanged and working
- ✅ Unix Console debugging unchanged and working
- ✅ Windows GUI debugging unchanged and working  
- ✅ Windows Console debugging now uses PyCharm internal console (no separate window)

## Implementation Summary - Version 1.0.227 (EXECUTION FIX)

### Issues Fixed in v1.0.227
1. **Over-quoting Issue**: Removed incorrect quotes around hbmk2.exe path
2. **Workdir Parameter**: Removed `-workdir=.hbmk` that caused compilation errors
3. **Command Execution**: Simplified to normal command execution to get basic functionality working

### Current Status
- **Command Execution**: Now works correctly on Windows
- **Output**: Program compiles and runs, output appears (in separate console window)
- **Debugging**: PyCharm debugging should now work
- **Console Window**: Still opens separate window (known limitation, to be addressed separately)

### Technical Changes
```java
// Removed problematic -workdir parameter
// parameters.add("-workdir=" + buildDir);  // REMOVED

// Simplified command construction
commandLine.addParameters(parameters);  // Normal execution for all platforms
```

### Next Steps
1. **Verify debugging works** - Windows console programs should now execute and debug properly
2. **Address console window** - Research alternative approaches for console suppression
3. **Maintain working cases** - Ensure cases 1-3 still work

## Previous Implementation Summary - Version 1.0.225 (FAILED)

### Investigation Results
- **v1.0.224 Problem**: `-gtNUL` completely suppressed output, breaking debugging
- **Root Cause Discovery**: Windows `-gtSTD` creates separate console windows, Unix doesn't
- **Research Finding**: Need to use `-gtSTD` for output but suppress console window creation

### Final Solution (Windows Console Only - Case 4)

1. **Command Wrapper Approach**:
   - Windows console programs: Wrap with `cmd.exe /c start /B /WAIT`
   - Unix/Windows GUI programs: Use normal command execution
   - This prevents console window creation while preserving all output

2. **Technical Implementation**:
   ```java
   if (System.getProperty("os.name").toLowerCase().contains("windows") && !isGuiProgram) {
       // Build complete hbmk2 command as quoted string
       StringBuilder wrappedCommand = new StringBuilder();
       wrappedCommand.append("\"").append(hbmk2Path).append("\"");
       for (String param : parameters) {
           wrappedCommand.append(" \"").append(param).append("\"");
       }
       
       // Use cmd.exe wrapper to suppress console window
       commandLine.setExePath("cmd.exe");
       commandLine.addParameter("/c");
       commandLine.addParameter("start");
       commandLine.addParameter("/B");      // Background, no window
       commandLine.addParameter("/WAIT");   // Wait for completion
       commandLine.addParameter(wrappedCommand.toString());
   }
   ```

3. **GT Driver**: Still uses `-gtSTD` for proper output support

### Previous Implementation (v1.0.224 - FAILED)

1. **GT Driver Fix**: 
   - Windows console programs now use `-gtNUL` instead of `-gtSTD`
   - Unix console programs continue using `-gtSTD` (unchanged)
   - This prevents Windows from creating separate console windows

2. **Process Creation Settings**:
   - Added Windows-specific console inheritance for console programs only
   - `withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)`
   - `withEnvironment("HIDE_CONSOLE", "1")`

3. **Platform Detection Logic**:
   ```java
   if (System.getProperty("os.name").toLowerCase().contains("windows") && !isGuiProgram) {
       // Windows console-specific handling
       parameters.add("-gtNUL");
       commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
   } else if (!isGuiProgram) {
       // Unix console handling (unchanged)
       parameters.add("-gtSTD");
   }
   ```

### Changes Made (Windows Console Only - Case 4)

1. **GT Driver Fix**: 
   - Windows console programs now use `-gtNUL` instead of `-gtSTD`
   - Unix console programs continue using `-gtSTD` (unchanged)
   - This prevents Windows from creating separate console windows

2. **Process Creation Settings**:
   - Added Windows-specific console inheritance for console programs only
   - `withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE)`
   - `withEnvironment("HIDE_CONSOLE", "1")`

3. **Platform Detection Logic**:
   ```java
   if (System.getProperty("os.name").toLowerCase().contains("windows") && !isGuiProgram) {
       // Windows console-specific handling
       parameters.add("-gtNUL");
       commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
   } else if (!isGuiProgram) {
       // Unix console handling (unchanged)
       parameters.add("-gtSTD");
   }
   ```

### Preserved Working Cases (1-3)
- ✅ Unix GUI → No changes
- ✅ Unix Console → No changes  
- ✅ Windows GUI → No changes

### Expected Results
- **Case 4 (Windows Console)**: Should now output to PyCharm console instead of separate window
- **All Other Cases**: Should continue working exactly as before

### Test File Created
- `test-windows-console.prg` - For testing case 4 specifically

## Next Steps

1. ✅ Implementation completed in version 1.0.224
2. Test all 4 cases to ensure no regressions
3. Verify Windows console debugging now works in PyCharm console
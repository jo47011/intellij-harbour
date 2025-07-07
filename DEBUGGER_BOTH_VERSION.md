# Harbour IntelliJ Plugin - Dual Debugging Implementation Guide

## Executive Summary

This document provides a comprehensive implementation guide for merging two debugging approaches in the Harbour IntelliJ plugin:

1. **Console Programs**: Use PyCharm's internal debugger (from commit 5107483)
2. **GUI Programs**: Use Harbour's internal debugger with init.cld (from commit a57024d)

The current implementation always uses Harbour internal debugger for all programs, but we need a hybrid approach that automatically detects program type and uses the appropriate debugging method.

## Problem Statement

- **Working PyCharm Version (5107483)**: Works with PyCharm internal debugger for both GUI and console programs, but GUI version doesn't hook up to the Harbour GUI properly
- **GUI Version (a57024d)**: Both GUI and console programs launch GUI and use Harbour internal debugger, which is wrong for console programs

## Solution Requirements

We need to combine both versions:
- **GUI programs** (with flags like -gui, -gtwvt, etc.) → Use Harbour internal debugger with init.cld popup
- **Console programs** (without GUI flags) → Use PyCharm internal debugger

## Git Version Analysis

### Version 5107483 (Working PyCharm Debugger)

**Key Characteristics:**
- Uses PyCharm remote debugging for ALL programs
- Skips ProcessTerminatedListener to allow debug connection to outlive process
- Sets environment: `HB_REMOTE_DEBUG=1`, `HB_DBG_PATH=.`
- Uses `-gtSTD` for console output
- Default debug port: 6110 (needs updating to 9876)
- Simple approach - no GUI detection

**HarbourDebuggerRunProfileState.java differences:**
```java
// In startProcess() method:
// For remote debugging, don't auto-terminate the debug session when process ends
// The debug connection can outlive the process, especially on Windows
HarbourLogger.log(env.getProject(), "HarbourDebugger", 
        "Skipping ProcessTerminatedListener to allow debug connection to outlive process");
// ProcessTerminatedListener.attach(handler); // DISABLED for remote debugging

// In compileAndRunHarbourProgram():
// Force standard GT driver to prevent console windows and redirect output to IntelliJ
parameters.add("-gtSTD");

// Environment setup:
commandLine.withEnvironment("HB_DBG_PATH", ".");
commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
```

### Version a57024d (GUI Version with Harbour Internal Debugger)

**Key Characteristics:**
- Has sophisticated GUI vs Console detection logic
- Conditional ProcessTerminatedListener based on program type
- Different environment variables per program type
- Enhanced init.cld generation with multiple file locations
- Comprehensive GUI flag detection

**HarbourDebuggerRunProfileState.java differences:**
```java
// In startProcess() method:
// We need to detect if this is a GUI program to determine process termination behavior
boolean isGuiProgram = isGuiProgram(runConfig);

if (isGuiProgram) {
    // For GUI programs: terminate debug session when process ends
    ProcessTerminatedListener.attach(handler);
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Attached ProcessTerminatedListener - debug session will end with process");
} else {
    // For console programs using remote debugging: allow debug connection to outlive process
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "Console program: Skipping ProcessTerminatedListener to allow remote debug connection to outlive process");
}

// GUI Detection Methods:
private boolean isGuiProgram(HarbourDebuggerRunConfig config) {
    String sourceFile = config.getSourceFile();
    if (sourceFile == null) return false;
    
    // For .hbp files, check their contents
    if (sourceFile.endsWith(".hbp")) {
        return isGuiProgram(sourceFile, config.getCompilerOptions());
    } else {
        // For standalone .prg files, we add GUI flags automatically (see current logic)
        // So they are considered GUI programs
        return true;
    }
}

private boolean isGuiProgram(String buildTarget, String compilerOptions) {
    // Check compiler options for GUI flags
    if (!StringUtil.isEmpty(compilerOptions)) {
        String opts = compilerOptions.toLowerCase();
        if (opts.contains("-gui") || opts.contains("-gtwvt") || opts.contains("-gtwvw") || 
            opts.contains("-gtwin") || opts.contains("-gtwvg") || opts.contains("-gtxwc")) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI flags detected in compiler options: " + compilerOptions);
            return true;
        }
    }
    
    // Check .hbp file for GUI flags
    if (buildTarget.endsWith(".hbp")) {
        try {
            File hbpFile = new File(buildTarget);
            if (!hbpFile.isAbsolute()) {
                String workingDir = runConfig.getWorkingDirectory();
                if (StringUtil.isEmpty(workingDir)) {
                    File sourceFile = new File(runConfig.getSourceFile());
                    workingDir = sourceFile.getParent();
                }
                hbpFile = new File(workingDir, buildTarget);
            }
            
            if (hbpFile.exists()) {
                String content = new String(java.nio.file.Files.readAllBytes(hbpFile.toPath()));
                String contentLower = content.toLowerCase();
                if (contentLower.contains("-gui") || contentLower.contains("-gtwvt") || 
                    contentLower.contains("-gtwvw") || contentLower.contains("-gtwin") || 
                    contentLower.contains("-gtwvg") || contentLower.contains("-gtxwc")) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "GUI flags detected in .hbp file: " + hbpFile.getName());
                    return true;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error reading .hbp file for GUI detection: " + e.getMessage());
        }
    } else {
        // For standalone .prg files, check if we're adding GUI flags automatically
        // Current logic adds -gui for standalone .prg files
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Standalone .prg file detected - will add GUI flags automatically");
        return true;
    }
    
    return false;
}

// Environment setup based on program type:
if (isGui) {
    // GUI programs: Use Harbour internal debugger environment
    String debugPath = finalWorkingDir != null ? finalWorkingDir : ".";
    commandLine.withEnvironment("HB_DBG_PATH", debugPath);
    
    // CRITICAL: Set ALTD=BREAK to trigger AltD(1) in menu.prg line 90
    commandLine.withEnvironment("ALTD", "BREAK");
    
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Set HB_DBG_PATH=" + debugPath);
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Set ALTD=BREAK to trigger AltD(1) in program");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: init.cld will be loaded automatically by Harbour internal debugger");
} else {
    // Console programs: Use PyCharm remote debugging
    commandLine.withEnvironment("HB_DBG_PATH", ".");
    commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "Console program: Using PyCharm remote debugging with HB_DBG_PATH=.");
}
```

## Implementation Plan

### Step 1: Update HarbourDebuggerRunConfig.java
**File**: `src/main/java/org/intellij/sdk/language/HarbourDebuggerRunConfig.java`

**Change default debug port from 6110 to 9876:**
```java
// Line 29: Change from:
private String debugPort = "6110";
// To:
private String debugPort = "9876";

// Line 91: Change from:
debugPort = element.getAttributeValue("debugPort", "6110");
// To:
debugPort = element.getAttributeValue("debugPort", "9876");

// Line 190-191: Change from:
} catch (NumberFormatException e) {
    return 6110; // Default port
// To:
} catch (NumberFormatException e) {
    return 9876; // Default port
```

### Step 2: Merge HarbourDebuggerRunProfileState.java
**File**: `src/main/java/org/intellij/sdk/language/HarbourDebuggerRunProfileState.java`

**Add GUI detection methods from version a57024d:**
```java
/**
 * Detects if the program uses GUI flags by checking run configuration
 */
private boolean isGuiProgram(HarbourDebuggerRunConfig config) {
    String sourceFile = config.getSourceFile();
    if (sourceFile == null) return false;
    
    // For .hbp files, check their contents
    if (sourceFile.endsWith(".hbp")) {
        return isGuiProgram(sourceFile, config.getCompilerOptions());
    } else {
        // For standalone .prg files, we add GUI flags automatically (see current logic)
        // So they are considered GUI programs
        return true;
    }
}

/**
 * Detects if the program uses GUI flags by checking:
 * 1. .hbp file contents for GUI flags
 * 2. Compiler options for GUI flags
 * 3. Default GUI flags for standalone .prg files
 */
private boolean isGuiProgram(String buildTarget, String compilerOptions) {
    // Check compiler options for GUI flags
    if (!StringUtil.isEmpty(compilerOptions)) {
        String opts = compilerOptions.toLowerCase();
        if (opts.contains("-gui") || opts.contains("-gtwvt") || opts.contains("-gtwvw") || 
            opts.contains("-gtwin") || opts.contains("-gtwvg") || opts.contains("-gtxwc")) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI flags detected in compiler options: " + compilerOptions);
            return true;
        }
    }
    
    // Check .hbp file for GUI flags
    if (buildTarget.endsWith(".hbp")) {
        try {
            File hbpFile = new File(buildTarget);
            if (!hbpFile.isAbsolute()) {
                // Make it relative to working directory
                String workingDir = runConfig.getWorkingDirectory();
                if (StringUtil.isEmpty(workingDir)) {
                    File sourceFile = new File(runConfig.getSourceFile());
                    workingDir = sourceFile.getParent();
                }
                hbpFile = new File(workingDir, buildTarget);
            }
            
            if (hbpFile.exists()) {
                String content = new String(java.nio.file.Files.readAllBytes(hbpFile.toPath()));
                String contentLower = content.toLowerCase();
                if (contentLower.contains("-gui") || contentLower.contains("-gtwvt") || 
                    contentLower.contains("-gtwvw") || contentLower.contains("-gtwin") || 
                    contentLower.contains("-gtwvg") || contentLower.contains("-gtxwc")) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "GUI flags detected in .hbp file: " + hbpFile.getName());
                    return true;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error reading .hbp file for GUI detection: " + e.getMessage());
        }
    } else {
        // For standalone .prg files, check if we're adding GUI flags automatically
        // Current logic adds -gui for standalone .prg files
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Standalone .prg file detected - will add GUI flags automatically");
        return true;
    }
    
    return false;
}
```

**Update startProcess() method to use conditional ProcessTerminatedListener:**
```java
@NotNull
@Override
protected ProcessHandler startProcess() throws ExecutionException {
    HarbourLogger.log(env.getProject(), "HarbourDebugger", "========= START PROCESS DEBUG =========");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", "startProcess() method called");
    
    exportBreakpointsToFile();

    GeneralCommandLine commandLine = new GeneralCommandLine();

    if (runConfig.isUseDirectExecution()) {
        runCompiledHarbourProgram(commandLine);
    } else {
        compileAndRunHarbourProgram(commandLine);
    }

    commandLine.setRedirectErrorStream(true);
    
    // Windows-specific console handling to prevent popup windows
    if (System.getProperty("os.name").toLowerCase().contains("windows")) {
        commandLine.withEnvironment("HIDE_CONSOLE", "1");
        commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Applied Windows console inheritance settings");
    }
    
    // Log full command details before starting
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "Starting process with command: " + commandLine.getCommandLineString());

    OSProcessHandler handler;
    try {
        handler = new OSProcessHandler(commandLine);
        
        // CRITICAL: Detect if this is a GUI program to determine process termination behavior
        boolean isGuiProgram = isGuiProgram(runConfig);
        
        if (isGuiProgram) {
            // For GUI programs: terminate debug session when process ends
            ProcessTerminatedListener.attach(handler);
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program: Attached ProcessTerminatedListener - debug session will end with process");
        } else {
            // For console programs using remote debugging: allow debug connection to outlive process
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program: Skipping ProcessTerminatedListener to allow remote debug connection to outlive process");
        }
        
        handler.startNotify();
        
    } catch (Exception e) {
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Failed to start process: " + e.getMessage());
        throw new ExecutionException("Failed to start Harbour process: " + e.getMessage(), e);
    }
    
    return handler;
}
```

**Update compileAndRunHarbourProgram() method environment setup:**
```java
// At the end of compileAndRunHarbourProgram() method, replace current environment setup with:

// Detect if this is a GUI program early
boolean isGuiProgram = isGuiProgram(buildTarget, runConfig.getCompilerOptions());

// Set debug environment based on program type per CLAUDE.md rules
if (isGuiProgram) {
    // GUI programs: Use Harbour internal debugger environment
    String debugPath = finalWorkingDir != null ? finalWorkingDir : ".";
    commandLine.withEnvironment("HB_DBG_PATH", debugPath);
    
    // CRITICAL: Set ALTD=BREAK to trigger AltD(1) in program
    commandLine.withEnvironment("ALTD", "BREAK");
    
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Set HB_DBG_PATH=" + debugPath);
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Set ALTD=BREAK to trigger AltD(1) in program");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: init.cld will be loaded automatically by Harbour internal debugger");
} else {
    // Console programs: Use PyCharm remote debugging
    commandLine.withEnvironment("HB_DBG_PATH", ".");
    commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "Console program: Using PyCharm remote debugging with HB_DBG_PATH=.");
}

// Add appropriate GT driver based on program type
if (!isGuiProgram) {
    // Console programs: use standard console output for PyCharm debugging
    parameters.add("-gtSTD");
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "Console program: Using -gtSTD for PyCharm debugging");
} else {
    // GUI programs: add appropriate GUI flags if not already present
    if (!finalBuildTarget.endsWith(".hbp")) {
        parameters.add("-gui");
        
        // Use platform-specific GT driver
        if (System.getProperty("os.name").toLowerCase().contains("windows")) {
            parameters.add("-gtwvt");  // Windows Video Terminal
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added Windows GUI flags (-gui -gtwvt) for standalone .prg file");
        } else {
            parameters.add("-gtxwc");  // X Window Console
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added Linux GUI flags (-gui -gtxwc) for standalone .prg file");
        }
    }
    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
            "GUI program: Will use Harbour internal debugger with init.cld");
}
```

### Step 3: Update HarbourDebuggerRunner.java (Optional)
**File**: `src/main/java/org/intellij/sdk/language/HarbourDebuggerRunner.java`

The main difference is just enhanced logging. The version a57024d has more comprehensive logging:
```java
HarbourLogger.log("HarbourDebuggerRunner", "========= RUNNER DEBUG =========");
HarbourLogger.log("HarbourDebuggerRunner", "HarbourDebuggerRunner.doExecute() called");
HarbourLogger.log(project, "HarbourDebugger", "========= RUNNER DEBUG =========");
HarbourLogger.log(project, "HarbourDebugger", "HarbourDebuggerRunner.doExecute() called");
```

## Configuration Changes Required

### Debug Port Update
- **Current**: Default port 6110 (and some references to 6111)
- **Required**: Default port 9876
- **Files to update**: HarbourDebuggerRunConfig.java

### GUI Flag Detection
The system must detect these GUI flags in compiler options or .hbp files:
- `-gui`
- `-gtwvt` (Windows Video Terminal)
- `-gtwvw` (Windows Video Window)
- `-gtwin` (Windows)
- `-gtwvg` (Windows VG)
- `-gtxwc` (X Window Console)

## Testing Scenarios

### Test Case 1: Console Program with PyCharm Debugger
1. Create a simple .prg file without GUI flags
2. Set breakpoints in PyCharm
3. Run with debugger
4. Verify:
   - Uses PyCharm remote debugging
   - No ProcessTerminatedListener attached
   - Environment: `HB_REMOTE_DEBUG=1`, `HB_DBG_PATH=.`
   - Uses `-gtSTD` flag
   - Debug port 9876

### Test Case 2: GUI Program with Harbour Internal Debugger
1. Create a .prg file with GUI flags or .hbp with GUI options
2. Set breakpoints in PyCharm  
3. Run with debugger
4. Verify:
   - Uses Harbour internal debugger
   - ProcessTerminatedListener attached
   - Environment: `ALTD=BREAK`, `HB_DBG_PATH=<workingDir>`
   - Creates and loads init.cld file
   - GUI popup appears with Harbour debugger

### Test Case 3: .hbp File with GUI Flags
1. Create .hbp file containing `-gui` or `-gtwvt`
2. Verify GUI detection works correctly
3. Uses Harbour internal debugger approach

### Test Case 4: .hbp File without GUI Flags  
1. Create .hbp file with only console options
2. Verify console detection works correctly
3. Uses PyCharm remote debugger approach

## Todo List

- [ ] **HIGH PRIORITY**: Change default debug port from 6110 to 9876 in HarbourDebuggerRunConfig.java
- [ ] Implement GUI detection logic from version a57024d
- [ ] Add conditional ProcessTerminatedListener attachment
- [ ] Update environment variable setup based on program type
- [ ] Add appropriate GT driver flags based on program type
- [ ] Test console program debugging with PyCharm
- [ ] Test GUI program debugging with Harbour internal debugger
- [ ] Test .hbp file GUI flag detection
- [ ] Verify init.cld loading works on both Windows and Linux
- [ ] Update documentation with new dual debugging approach

## Files to Modify

1. **HarbourDebuggerRunConfig.java**:
   - Line 29: Change `debugPort = "6110"` to `debugPort = "9876"`
   - Line 91: Change default port parameter from "6110" to "9876"  
   - Line 190-191: Change default return value from 6110 to 9876

2. **HarbourDebuggerRunProfileState.java**:
   - Add `isGuiProgram()` methods
   - Update `startProcess()` method with conditional ProcessTerminatedListener
   - Update `compileAndRunHarbourProgram()` with dual environment setup
   - Add GUI flag detection logic

3. **HarbourDebuggerRunner.java** (optional):
   - Enhanced logging for better debugging visibility

## Expected Behavior After Implementation

- **Console programs** (.prg files or .hbp files without GUI flags):
  - Use PyCharm's internal debugger
  - Remote debugging connection on port 9876
  - Breakpoints work through PyCharm interface
  - No GUI popup windows
  - Process can outlive debug connection

- **GUI programs** (.prg files or .hbp files with GUI flags like -gui, -gtwvt):
  - Use Harbour's internal debugger
  - Breakpoints exported to init.cld file
  - GUI popup window with Harbour debugger interface
  - Debug session terminates when process ends
  - Environment variable ALTD=BREAK triggers debugging

This dual approach ensures optimal debugging experience for both console and GUI Harbour applications while maintaining compatibility with existing code.
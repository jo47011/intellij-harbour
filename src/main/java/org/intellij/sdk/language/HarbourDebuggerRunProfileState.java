package org.intellij.sdk.language;

import com.intellij.execution.DefaultExecutionResult;
import com.intellij.execution.ExecutionException;
import com.intellij.execution.ExecutionResult;
import com.intellij.execution.Executor;
import com.intellij.execution.configurations.CommandLineState;
import com.intellij.execution.configurations.GeneralCommandLine;
import com.intellij.execution.filters.TextConsoleBuilder;
import com.intellij.execution.filters.TextConsoleBuilderFactory;
import com.intellij.execution.process.OSProcessHandler;
import com.intellij.execution.process.ProcessHandler;
import com.intellij.execution.process.ProcessTerminatedListener;
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.execution.ui.ConsoleView;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.project.Project;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.breakpoints.XBreakpoint;

import java.io.*;
import java.util.*;
import com.intellij.xdebugger.breakpoints.XBreakpointManager;
import com.intellij.xdebugger.breakpoints.XLineBreakpoint;
import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.HashSet;
import java.util.Set;

/**
 * RunProfileState that compiles and runs a Harbour program with debugging enabled.
 *
 * BREAKTHROUGH FIX v1.0.141: Uses pre-compiled static library (libharbour_debug.a) 
 * instead of runtime source compilation to receive HB_DBG_MODULENAME events.
 * This enables proper variable name display (nCounter, cMessage vs Local1, Local2).
 */
public class HarbourDebuggerRunProfileState extends CommandLineState {
    private final HarbourDebuggerRunConfig runConfig;
    private final ExecutionEnvironment env;
    private String lastExecutedCommand; // Store command for console output
    private final Project project;

    public HarbourDebuggerRunProfileState(ExecutionEnvironment env,
                                          HarbourDebuggerRunConfig runConfig) {
        super(env);
        this.env = env;
        this.runConfig = runConfig;
        this.project = env.getProject();
    }

    @NotNull
    @Override
    protected ProcessHandler startProcess() throws ExecutionException {
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "========= START PROCESS DEBUG =========");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "startProcess() method called");
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "About to call exportBreakpointsToFile()");
        
        exportBreakpointsToFile();
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "exportBreakpointsToFile() call completed");

        GeneralCommandLine commandLine = new GeneralCommandLine();

        if (runConfig.isUseDirectExecution()) {
            runCompiledHarbourProgram(commandLine);
        } else {
            compileAndRunHarbourProgram(commandLine);
        }

        commandLine.setRedirectErrorStream(true);
        
        // Windows-specific console handling to prevent popup windows
        if (System.getProperty("os.name").toLowerCase().contains("windows")) {
            // Try to prevent creation of new console window on Windows
            // Keep debugging functionality intact - only modify process creation
            commandLine.withEnvironment("HIDE_CONSOLE", "1");
            commandLine.withParentEnvironmentType(GeneralCommandLine.ParentEnvironmentType.CONSOLE);
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Applied Windows console inheritance settings");
        }
        
        // Log full command details before starting
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Starting process with command: " + commandLine.getCommandLineString());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Working directory: " + commandLine.getWorkDirectory());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Environment: " + commandLine.getEnvironment());

        OSProcessHandler handler;
        try {
            handler = new OSProcessHandler(commandLine);
            
            // CRITICAL: Detect if this is a GUI program to determine process termination behavior
            // For GUI programs: terminate debug session when process ends
            // For console programs using remote debugging: allow debug connection to outlive process
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
            
            // Log process start status
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Process started successfully: " + handler.getProcess().isAlive());
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Process PID: " + handler.getProcess().pid());
            
            // Add process output listener for debugging
            handler.addProcessListener(new com.intellij.execution.process.ProcessAdapter() {
                @Override
                public void onTextAvailable(@NotNull com.intellij.execution.process.ProcessEvent event, 
                                          @NotNull com.intellij.openapi.util.Key outputType) {
                    String text = event.getText();
                    if (text != null && !text.trim().isEmpty()) {
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                "Process output: " + text.trim());
                    }
                }
                
                @Override
                public void processTerminated(@NotNull com.intellij.execution.process.ProcessEvent event) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Process terminated with exit code: " + event.getExitCode());
                }
            });
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Failed to start process: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebugger", e);
            throw new ExecutionException("Failed to start Harbour process: " + e.getMessage(), e);
        }
        
        return handler;
    }

    private void compileAndRunHarbourProgram(GeneralCommandLine commandLine) throws ExecutionException {
        String hbmk2Path = runConfig.getHbmk2Path();
        if (StringUtil.isEmpty(hbmk2Path)) {
            throw new ExecutionException("Hbmk2 compiler path is not specified");
        }
        
        // Use the configured hbmk2 path as-is (user should configure correct path for their OS)
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Using configured hbmk2 path: " + hbmk2Path);

        commandLine.setExePath(hbmk2Path);

        String workingDir = runConfig.getWorkingDirectory();
        if (StringUtil.isEmpty(workingDir)) {
            File sourceFile = new File(runConfig.getSourceFile());
            workingDir = sourceFile.getParent();
        }
        
        // Fix Windows/WSL path issues for working directory
        if (workingDir != null && workingDir.contains("\\wsl.localhost\\")) {
            // Convert WSL path back to Linux path
            workingDir = workingDir.replaceAll(".*\\\\wsl\\.localhost\\\\Ubuntu-22\\.04", "");
            workingDir = workingDir.replace("\\", "/");
            // Ensure it starts with /
            if (!workingDir.startsWith("/")) {
                workingDir = "/" + workingDir;
            }
            
            // Remove hardcoded user path mapping - use working directory as-is
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Converted WSL working directory to Linux path: " + workingDir);
        }
        
        // Instrument source file if needed
        String buildTarget = runConfig.getSourceFile();
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Original buildTarget from runConfig: " + buildTarget);
        
        // Fix Windows/WSL path issues
        if (buildTarget.contains("\\wsl.localhost\\")) {
            // Convert WSL path back to Linux path
            buildTarget = buildTarget.replaceAll(".*\\\\wsl\\.localhost\\\\Ubuntu-22\\.04", "");
            buildTarget = buildTarget.replace("\\", "/");
            // Ensure it starts with /
            if (!buildTarget.startsWith("/")) {
                buildTarget = "/" + buildTarget;
            }
            
            // Remove hardcoded user path mapping - use build target as-is
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Converted WSL path to Linux path: " + buildTarget);
        }
        
        // Get build directory setting early
        HarbourSettings settings = HarbourSettings.getInstance(env.getProject());
        String buildDir = ".hbmk"; // Default
        if (settings != null) {
            String settingsBuildDir = settings.getBuildOutputDirectory();
            if (!StringUtil.isEmpty(settingsBuildDir)) {
                buildDir = settingsBuildDir;
            }
        }
        
        // Create build directory if it doesn't exist
        File buildDirFile = new File(workingDir, buildDir);
        if (!buildDirFile.exists()) {
            if (!buildDirFile.mkdirs()) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to create build directory: " + buildDirFile.getPath());
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Created build directory: " + buildDirFile.getPath());
            }
        }
        
        // Copy harbour_debug.prg to build directory for console programs
        // This provides network connectivity for PyCharm debugging
        File debugLibFile = new File(buildDirFile, "harbour_debug.prg");
        try {
            copyResourceFile(debugLibFile, "/debug/harbour_debug.prg");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Copied debug library to: " + debugLibFile.getAbsolutePath());
        } catch (IOException e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Warning: Failed to copy debug library: " + e.getMessage());
            // Continue without debug library
        }

        // Detect if this is a GUI program early - use same logic as in startProcess()
        boolean isGuiProgram = isGuiProgram(runConfig);
        // USER FEEDBACK: Don't use instrumentation - debug original files only
        // The instrumented approach causes confusion and file management issues
        boolean shouldInstrument = shouldInstrumentSource() && !isGuiProgram; // Only console programs, never GUI
        File instrumentedFile = null;
        
        // Only instrument console programs, not GUI programs
        if (shouldInstrument && !isGuiProgram) {
            try {
                // Ensure we have an absolute path for the source file
                File sourceFile = new File(buildTarget);
                if (!sourceFile.isAbsolute()) {
                    sourceFile = new File(workingDir, buildTarget);
                }
                
                HarbourSourceInstrumenter instrumenter = new HarbourSourceInstrumenter(sourceFile, buildDirFile);
                
                // Use console-specific instrumentation (full debug hooks)
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Console program detected - using full debug instrumentation: " + sourceFile.getAbsolutePath());
                instrumentedFile = instrumenter.instrument();
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Console instrumentation completed in build dir: " + instrumentedFile.getAbsolutePath());
                
                buildTarget = instrumentedFile.getAbsolutePath();
                
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Failed to instrument source file: " + e.getMessage());
                HarbourLogger.logStackTrace("HarbourDebugger", new Exception("Instrumentation failed", e));
                // Continue with original file
            }
        } else if (isGuiProgram) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program detected - using Harbour internal debugger (no instrumentation)");
        }

        List<String> parameters = new ArrayList<>();

        // Look for .hbp file in working directory
        File workingDirFile = new File(workingDir != null ? workingDir : ".");
        // If we instrumented the file, use the instrumented version directly, don't look for .hbp
        String finalBuildTarget;
        if (instrumentedFile != null && instrumentedFile.exists()) {
            finalBuildTarget = instrumentedFile.getAbsolutePath();
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Using instrumented file: " + finalBuildTarget);
        } else {
            finalBuildTarget = findHbpFileOrUseSource(workingDirFile, buildTarget);
        }
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Final buildTarget: " + finalBuildTarget);
        
        // Verify we're using the current source file by checking its modification time and a content sample
        try {
            File sourceFile = new File(finalBuildTarget);
            if (sourceFile.exists()) {
                long lastModified = sourceFile.lastModified();
                String modifiedTime = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date(lastModified));
                
                // Read first few lines to verify content
                String sampleContent = "";
                try {
                    java.util.List<String> lines = java.nio.file.Files.readAllLines(sourceFile.toPath());
                    if (lines.size() > 20) {
                        sampleContent = lines.get(20); // Get line 21 (should contain "HARBOUR GUI TEST PROGRAM")
                    }
                } catch (Exception e) {
                    sampleContent = "Error reading content: " + e.getMessage();
                }
                
                
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Source verification: " + finalBuildTarget + " modified " + modifiedTime + ", size " + sourceFile.length());
            }
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error verifying source file: " + e.getMessage());
        }
        
        // Use the GUI detection from earlier (already computed)
        boolean isGui = isGuiProgram;
        
        // Ensure finalBuildTarget is an absolute path for GUI programs
        if (isGui && !new File(finalBuildTarget).isAbsolute()) {
            File absoluteTarget = new File(workingDir, finalBuildTarget);
            finalBuildTarget = absoluteTarget.getAbsolutePath();
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Converted to absolute path: " + finalBuildTarget);
        }
        
        // For console programs, let PyCharm handle debugging without additional libraries
        if (!isGui) {
            // Console programs: Use PyCharm debugger - no additional debug library needed
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program: Using PyCharm debugging (no additional library needed)");
        } else {
            // GUI programs: Use Harbour internal debugger
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program: Will use Harbour internal debugger with init.cld");
        }
        
        // CRITICAL FIX: Use relative filename, not absolute path for hbmk2
        // Absolute paths break debugging - user confirmed this is the root cause
        File targetFile = new File(finalBuildTarget);
        String relativeTarget = targetFile.getName();
        parameters.add(relativeTarget);
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Using relative target: " + relativeTarget + " (was: " + finalBuildTarget + ")");
        
        // Add debug source based on program type per CLAUDE.md rules
        if (!finalBuildTarget.endsWith("harbour_debug.prg")) {
            if (!isGui) {
                // Console programs: Use debug library for PyCharm network connectivity
                String debugSourcePath = buildDir + "/harbour_debug.prg";
                parameters.add(debugSourcePath);
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Console program: Added debug library for PyCharm connectivity: " + debugSourcePath);
            }
            // GUI programs: No custom debug source - use Harbour internal debugger with init.cld
        }
        
        // Add debug flags - both program types need -b flag for debugging support
        parameters.add("-b");
        parameters.add("-run");
        
        if (isGui) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program: Using -b flag with Harbour internal debugger");
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program: Using -b flag with PyCharm debugging (environment controls which interface)");
        }
        
        // Remove FORCE_DEBUG_MODE - it was triggering Harbour debugger instead of PyCharm
        // parameters.add("-DFORCE_DEBUG_MODE=1");  // REMOVED - not in working version
        
        // CRITICAL: Add debug flags for F9 breakpoint support
        parameters.add("-debug");  // Add C-level debug information 
        // NOTE: Removed -lhbdebug as hbmk2 warns it's a core library automatically included with -b
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Added debug flag: -debug for C-level debug support");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Using incremental build (removed -clean as it prevented execution)");

        // Add -workdir for console programs like the working version
        if (!isGui) {
            parameters.add("-workdir=" + buildDir);
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program: Added -workdir=" + buildDir + " like working version");
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program: No -workdir needed");
        }
        parameters.add("-D__HARBOUR_DEBUG__");
        parameters.add("-DDBG_PORT=" + runConfig.getDebugPort());
        
        if (isGui) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program detected - using GUI debugging approach");
            
            // For GUI programs: add appropriate GUI flags and use init.cld approach
            if (!finalBuildTarget.endsWith(".hbp")) {
                // Add platform-specific GUI flags for standalone .prg files
                parameters.add("-gui");
                
                // Use platform-specific GT driver
                if (System.getProperty("os.name").toLowerCase().contains("windows")) {
                    parameters.add("-gtwvt");  // Windows Video Terminal
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Added Windows GUI flags (-gui -gtwvt) for standalone .prg file");
                } else {
                    // Linux/Unix: use X Window Console GT driver
                    parameters.add("-gtxwc");  // X Window Console
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Added Linux GUI flags (-gui -gtxwc) for standalone .prg file");
                }
            }
            
            // For GUI programs: Use built-in debug support (don't add -lhbdebug as it causes warnings)
            // Debug builds automatically include hbdebug library
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "GUI program: Using built-in debug support (hbdebug included automatically in -b builds)");
            
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program detected - using PyCharm debugging approach");
            
            // For console programs: use standard console output for PyCharm debugging
            parameters.add("-gtSTD");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Console program: Using -gtSTD for PyCharm debugging");
        }
        
        // Additional Windows-specific console redirection (only for GUI programs)
        if (System.getProperty("os.name").toLowerCase().contains("windows") && isGui) {
            // Prevent new console window creation on Windows for GUI programs
            parameters.add("-D__INTELLIJ_DEBUG__");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added Windows-specific console redirection flags for GUI program");
        }

        // Don't set ALTD environment variable for remote debugging
        // commandLine.withEnvironment("ALTD", "BREAK");

        if (!StringUtil.isEmpty(runConfig.getCompilerOptions())) {
            parameters.addAll(StringUtil.split(runConfig.getCompilerOptions(), " "));
        }

        if (!StringUtil.isEmpty(runConfig.getProgramArguments())) {
            parameters.add("--");
            parameters.addAll(StringUtil.split(runConfig.getProgramArguments(), " "));
        }

        // Log the complete command for debugging - make it very visible
        StringBuilder cmdLog = new StringBuilder();
        cmdLog.append(hbmk2Path).append(" ");
        for (String param : parameters) {
            cmdLog.append(param).append(" ");
        }

        String fullCommand = cmdLog.toString();
        lastExecutedCommand = fullCommand; // Store for console output
        
        // Check for any existing executables that might cause confusion
        String sourceBaseName = new File(finalBuildTarget).getName();
        if (sourceBaseName.endsWith(".prg")) {
            sourceBaseName = sourceBaseName.substring(0, sourceBaseName.length() - 4);
        }
        File potentialOldExe = new File("/home/developer/workspace/" + sourceBaseName);
        
        if (potentialOldExe.exists()) {
        }
        
        // Also log to PyCharm console via HarbourLogger
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "=== EXACT HBMK2 COMMAND ===");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", fullCommand);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Working Directory: " + workingDir);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Build Target: " + finalBuildTarget);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Instrumented: " + shouldInstrument);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "GUI Program: " + isGui);

        commandLine.addParameters(parameters);
        
        // CRITICAL FIX: Ensure working directory uses Windows format on Windows for init.cld loading
        String finalWorkingDir = workingDir;
        if (System.getProperty("os.name").toLowerCase().contains("windows") && workingDir != null) {
            // Convert to Windows path format for proper init.cld loading
            finalWorkingDir = workingDir.replace("/", "\\");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Converted working directory to Windows format: " + finalWorkingDir);
        }
        
        commandLine.setWorkDirectory(finalWorkingDir);
        
        // REVERT to working version approach: Use same environment for ALL programs
        // Based on working commit 5107483 - no GUI detection for environment variables
        commandLine.withEnvironment("HB_DBG_PATH", ".");
        commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
        // DON'T set ALTD environment variable (per working version)
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "ALL programs: Using working version environment (HB_DBG_PATH=., HB_REMOTE_DEBUG=1, no ALTD)");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Program type detected as: " + (isGui ? "GUI" : "Console") + " but using same environment for all");
    }

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
            // For standalone .prg files, check compiler options first
            String compilerOptions = config.getCompilerOptions();
            if (!StringUtil.isEmpty(compilerOptions)) {
                String opts = compilerOptions.toLowerCase();
                if (opts.contains("-gui") || opts.contains("-gtwvt") || opts.contains("-gtwvw") || 
                    opts.contains("-gtwin") || opts.contains("-gtwvg") || opts.contains("-gtxwc")) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "GUI flags detected in compiler options for standalone .prg: " + compilerOptions);
                    return true;
                }
            }
            
            // Check filename to determine program type
            String fileName = new File(sourceFile).getName().toLowerCase();
            if (fileName.contains("gui") || fileName.contains("window") || fileName.contains("dialog")) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "GUI program detected by filename: " + fileName);
                return true;
            }
            
            // Default for standalone .prg files without GUI indicators: console program
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Standalone .prg file without GUI indicators - treating as console program");
            return false;
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
            // For standalone .prg files, they default to console programs
            // Only consider GUI if explicit GUI flags were already checked above
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Standalone .prg file without GUI flags - treating as console program");
            return false;
        }
        
        return false;
    }

    /**
     * Finds the first .hbp file in the working directory or returns the source file path
     */
    private String findHbpFileOrUseSource(File workingDir, String sourceFile) {
        // Extract the base name of the source file (without extension)
        String sourceBaseName = sourceFile;
        int lastDot = sourceFile.lastIndexOf('.');
        if (lastDot > 0) {
            sourceBaseName = sourceFile.substring(0, lastDot);
        }
        
        // Look for a matching .hbp file for this source
        File matchingHbp = new File(workingDir, sourceBaseName + ".hbp");
        if (matchingHbp.exists()) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger",
                    "Found matching .hbp file: " + matchingHbp.getName());
            return matchingHbp.getName();
        }
        
        // If no matching .hbp, just use the source file directly
        HarbourLogger.log(env.getProject(), "HarbourDebugger",
                "No matching .hbp file found for " + sourceFile + ", using source file directly");
        
        // Ensure the source file has .prg extension
        if (!sourceFile.endsWith(".prg")) {
            // Check if the .prg file exists
            File prgFile = new File(workingDir, sourceFile + ".prg");
            if (prgFile.exists()) {
                return sourceFile + ".prg";
            }
        }
        return sourceFile;
    }

    private void runCompiledHarbourProgram(GeneralCommandLine commandLine) throws ExecutionException {
        String exePath = runConfig.getExecutablePath();
        if (StringUtil.isEmpty(exePath)) {
            throw new ExecutionException("Executable path is not specified");
        }

        commandLine.setExePath(exePath);

        String workingDir = runConfig.getWorkingDirectory();
        if (StringUtil.isEmpty(workingDir)) {
            File exeFile = new File(exePath);
            workingDir = exeFile.getParent();
        }

        List<String> parameters = new ArrayList<>();

        // For pre-compiled executables: Need to detect if GUI program to set ALTD
        // TODO: Add GUI detection logic for direct execution mode
        // For now, assuming console programs use remote debugging
        // commandLine.withEnvironment("ALTD", "BREAK");  // Enable for GUI programs only

        if (!StringUtil.isEmpty(runConfig.getProgramArguments())) {
            parameters.addAll(StringUtil.split(runConfig.getProgramArguments(), " "));
        }

        commandLine.addParameters(parameters);
        commandLine.setWorkDirectory(workingDir);
        commandLine.withEnvironment("HB_DBG_PATH", ".");
        commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
        
        // Log the complete executable command for debugging - make it very visible
        StringBuilder cmdLog = new StringBuilder();
        cmdLog.append(exePath).append(" ");
        for (String param : parameters) {
            cmdLog.append(param).append(" ");
        }
        
        String fullCommand = cmdLog.toString();
        lastExecutedCommand = fullCommand; // Store for console output
        
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "=== EXECUTABLE COMMAND ===");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Command: " + fullCommand);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Working Directory: " + workingDir);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Environment: HB_DBG_PATH=., HB_REMOTE_DEBUG=1");
    }

    private void exportBreakpointsToFile() {
        Project project = env.getProject();
        XBreakpointManager breakpointManager = XDebuggerManager.getInstance(project).getBreakpointManager();

        // COMPREHENSIVE DEBUG LOGGING
        HarbourLogger.log(project, "HarbourDebugger", "========= EXPORT BREAKPOINTS DEBUG START =========");
        
        // Check if this method is actually being called
        HarbourLogger.log(project, "HarbourDebugger", "exportBreakpointsToFile() method called");
        
        // Check total breakpoints available
        XBreakpoint<?>[] allBreakpoints = breakpointManager.getAllBreakpoints();
        HarbourLogger.log(project, "HarbourDebugger", "Total breakpoints in manager: " + allBreakpoints.length);
        
        for (XBreakpoint<?> bp : allBreakpoints) {
            HarbourLogger.log(project, "HarbourDebugger", "Breakpoint: " + bp.toString());
            if (bp instanceof XLineBreakpoint) {
                XLineBreakpoint<?> lineBp = (XLineBreakpoint<?>) bp;
                if (lineBp.getSourcePosition() != null) {
                    String bpFile = lineBp.getSourcePosition().getFile().getName();
                    String bpPath = lineBp.getSourcePosition().getFile().getPath();
                    int bpLine = lineBp.getSourcePosition().getLine() + 1;
                    String bpType = lineBp.getType().getClass().getSimpleName();
                    
                    HarbourLogger.log(project, "HarbourDebugger", "  - File: " + bpFile);
                    HarbourLogger.log(project, "HarbourDebugger", "  - Full Path: " + bpPath);
                    HarbourLogger.log(project, "HarbourDebugger", "  - Line: " + bpLine);
                    HarbourLogger.log(project, "HarbourDebugger", "  - Type: " + bpType);
                    
                    // Check if this is a test-gui.prg breakpoint
                    if (bpFile.equals("test-gui.prg")) {
                        HarbourLogger.log(project, "HarbourDebugger", "  >>> FOUND test-gui.prg breakpoint at line " + bpLine + " !!!");
                        HarbourLogger.log(project, "HarbourDebugger", "  >>> Path: " + bpPath);
                        HarbourLogger.log(project, "HarbourDebugger", "  >>> This should NOT be included in test.prg debugging!");
                    }
                }
            }
        }

        String breakpointFileName = StringUtil.isEmpty(runConfig.getBreakpointFile())
                ? "init.cld" : runConfig.getBreakpointFile();
        
        HarbourLogger.log(project, "HarbourDebugger", "Breakpoint filename: " + breakpointFileName);

        String workingDir = runConfig.getWorkingDirectory();
        if (StringUtil.isEmpty(workingDir)) {
            if (runConfig.isUseDirectExecution() && !StringUtil.isEmpty(runConfig.getExecutablePath())) {
                File exeFile = new File(runConfig.getExecutablePath());
                workingDir = exeFile.getParent();
            } else if (!StringUtil.isEmpty(runConfig.getSourceFile())) {
                File sourceFile = new File(runConfig.getSourceFile());
                workingDir = sourceFile.getParent();
            } else {
                workingDir = project.getBasePath();
            }
        }

        File breakpointFile = new File(workingDir, breakpointFileName);

        // Add diagnostic logging for Windows debugging
        HarbourLogger.log(project, "HarbourDebugger", "=== INIT.CLD CREATION DIAGNOSTICS ===");
        HarbourLogger.log(project, "HarbourDebugger", "Working directory from config: " + runConfig.getWorkingDirectory());
        HarbourLogger.log(project, "HarbourDebugger", "Computed working directory: " + workingDir);
        HarbourLogger.log(project, "HarbourDebugger", "Breakpoint file path: " + breakpointFile.getAbsolutePath());
        HarbourLogger.log(project, "HarbourDebugger", "Parent directory exists: " + breakpointFile.getParentFile().exists());
        HarbourLogger.log(project, "HarbourDebugger", "Is direct execution: " + runConfig.isUseDirectExecution());
        HarbourLogger.log(project, "HarbourDebugger", "Source file: " + runConfig.getSourceFile());
        
        // For Windows with .hbp files, we need to write init.cld to multiple locations
        // because hbmk2 may change the working directory when running
        List<File> breakpointFiles = new ArrayList<>();
        breakpointFiles.add(breakpointFile);
        
        if (System.getProperty("os.name").toLowerCase().contains("windows") && 
            runConfig.getSourceFile().endsWith(".hbp")) {
            // When using hbmk2 with .hbp, the executable is typically created 
            // in the same directory as the .hbp file, and that's where it runs from
            File hbpDir = new File(runConfig.getSourceFile()).getParentFile();
            File altBreakpointFile = new File(hbpDir, breakpointFileName);
            if (!altBreakpointFile.equals(breakpointFile)) {
                breakpointFiles.add(altBreakpointFile);
                HarbourLogger.log(project, "HarbourDebugger", "Windows .hbp detected - also writing init.cld to: " + 
                    altBreakpointFile.getAbsolutePath());
            }
        }
        HarbourLogger.log(project, "HarbourDebugger", "=====================================");

        if (!breakpointFile.getParentFile().exists()) {
            if (!breakpointFile.getParentFile().mkdirs()) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", "Failed to create breakpoint directory");
            }
        }

        int totalBreakpoints = 0;
        Set<String> breakpointFileNames = new HashSet<>();
        String sourceFileName = new File(runConfig.getSourceFile()).getName();

        // Get the actual .prg file to debug - use full path if relative
        String sourceFilePath = runConfig.getSourceFile();
        if (!new File(sourceFilePath).isAbsolute()) {
            sourceFilePath = new File(workingDir, sourceFilePath).getAbsolutePath();
        }
        String targetPrgFile = getMainPrgFileFromSource(sourceFilePath);
        HarbourLogger.log(project, "HarbourDebugger", "Target .prg file for debugging: " + targetPrgFile);
        
        // Check if we're debugging an instrumented file
        boolean isInstrumented = targetPrgFile.endsWith("_instrumented.prg");
        String originalFileName = isInstrumented ? 
            targetPrgFile.replace("_instrumented.prg", ".prg") : targetPrgFile;
        // Count total breakpoints for logging
        for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
            if (bp instanceof XLineBreakpoint &&
                    bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                    bp.getSourcePosition() != null) {

                VirtualFile file = bp.getSourcePosition().getFile();
                String fileName = file.getName();

                // Only count breakpoints for the file we're actually debugging
                if (fileName.equals(originalFileName) || 
                    (isInstrumented && fileName.equals(targetPrgFile))) {
                    totalBreakpoints++;
                    breakpointFileNames.add(fileName);
                }
            }
        }
        
        // Write breakpoints to all init.cld file locations, preserving existing content
        HarbourLogger.log(project, "HarbourDebugger", "About to write to " + breakpointFiles.size() + " locations");
        
        for (File bpFile : breakpointFiles) {
            HarbourLogger.log(project, "HarbourDebugger", "Processing init.cld at: " + bpFile.getAbsolutePath());
            
            try {
                updateInitCldFile(bpFile, originalFileName, totalBreakpoints, breakpointManager, project);
                HarbourLogger.log(project, "HarbourDebugger", "Successfully updated init.cld at: " + bpFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(project, "HarbourDebugger", "Failed to update init.cld at " + 
                    bpFile.getAbsolutePath() + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
            
        // Check for breakpoint file mismatch
        if (totalBreakpoints > 0 && !breakpointFileNames.isEmpty()) {
            boolean hasMatchingBreakpoint = false;
            for (String bpFile : breakpointFileNames) {
                if (bpFile.equals(targetPrgFile) || 
                    bpFile.equals(targetPrgFile.replace(".prg", "_instrumented.prg")) ||
                    targetPrgFile.equals(bpFile.replace("_instrumented.prg", ".prg"))) {
                    hasMatchingBreakpoint = true;
                    break;
                }
            }
            
            if (!hasMatchingBreakpoint) {
                String message = String.format(
                    "Warning: Breakpoints are set in %s but debugging %s. " +
                    "The debugger will not stop at these breakpoints.",
                    breakpointFileNames, targetPrgFile
                );
                HarbourLogger.log(project, "HarbourDebugger", message);
                HarbourDebuggerNotification.notifyEvent(project, "Breakpoint File Mismatch", message);
            }
        }

        HarbourLogger.log(project, "HarbourDebugger", "Exported " + totalBreakpoints +
                " breakpoints using FILE OPEN + BP approach");
        for (File bpFile : breakpointFiles) {
        }
        
        HarbourLogger.log(project, "HarbourDebugger", "========= EXPORT BREAKPOINTS DEBUG END =========");

    }

    /**
     * Extracts the main .prg file from the source file (either direct .prg or from .hbp)
     */
    private String getMainPrgFileFromSource(String sourceFile) {
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "getMainPrgFileFromSource() called with: " + sourceFile);
        
        if (sourceFile.endsWith(".hbp")) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", "Detected .hbp file, parsing...");
            
            // Parse .hbp file to find the main .prg file
            try {
                File hbpFile = new File(sourceFile);
                HarbourLogger.log(env.getProject(), "HarbourDebugger", "HBP file exists: " + hbpFile.exists());
                
                if (hbpFile.exists()) {
                    String content = new String(java.nio.file.Files.readAllBytes(hbpFile.toPath()));
                    String[] lines = content.split("\\r?\\n");
                    
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", "HBP file has " + lines.length + " lines");
                    
                    for (String line : lines) {
                        line = line.trim();
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Processing line: " + line);
                        
                        // Look for .prg files (first one is typically the main)
                        if (line.endsWith(".prg") && !line.startsWith("#") && !line.startsWith("//")) {
                            // Handle relative paths
                            if (line.startsWith("./")) {
                                line = line.substring(2);
                            }
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                "Found main .prg file in .hbp: " + line);
                            return line;
                        }
                    }
                }
            } catch (Exception e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error parsing .hbp file: " + e.getMessage());
                e.printStackTrace();
            }
            // Fallback: use .hbp filename if no .prg found
            String fallback = new File(sourceFile).getName();
            HarbourLogger.log(env.getProject(), "HarbourDebugger", "No .prg found, using fallback: " + fallback);
            return fallback;
        } else {
            // Direct .prg file
            String result = new File(sourceFile).getName();
            HarbourLogger.log(env.getProject(), "HarbourDebugger", "Direct .prg file: " + result);
            return result;
        }
    }

    /**
     * Updates init.cld file by preserving existing content and only modifying BP entries
     */
    private void updateInitCldFile(File initCldFile, String targetPrgFile, int totalBreakpoints, 
                                   XBreakpointManager breakpointManager, Project project) throws IOException {
        HarbourLogger.log(project, "HarbourDebugger", "updateInitCldFile() called for: " + initCldFile.getAbsolutePath());
        
        List<String> existingLines = new ArrayList<>();
        
        // Read existing content if file exists
        HarbourLogger.log(project, "HarbourDebugger", "File exists: " + initCldFile.exists());
        
        if (initCldFile.exists()) {
            try {
                existingLines = java.nio.file.Files.readAllLines(initCldFile.toPath());
                HarbourLogger.log(project, "HarbourDebugger", 
                    "Read " + existingLines.size() + " existing lines from init.cld");
                
                for (int i = 0; i < existingLines.size(); i++) {
                    HarbourLogger.log(project, "HarbourDebugger", "Line " + i + ": " + existingLines.get(i));
                }
            } catch (IOException e) {
                HarbourLogger.log(project, "HarbourDebugger", 
                    "Could not read existing init.cld, creating new: " + e.getMessage());
            }
        } else {
            HarbourLogger.log(project, "HarbourDebugger", "File does not exist, will create new");
        }
        
        // Filter out old BP entries, FILE OPEN commands for our target file, and Options Path
        List<String> filteredLines = new ArrayList<>();
        for (String line : existingLines) {
            String trimmedLine = line.trim();
            if (trimmedLine.startsWith("BP ") && trimmedLine.contains(targetPrgFile)) {
                // Remove old breakpoint entries for our target file only
                HarbourLogger.log(project, "HarbourDebugger", "Removing old BP entry for target file: " + line);
                continue;
            }
            if (trimmedLine.startsWith("FILE OPEN ") && trimmedLine.contains(targetPrgFile)) {
                // Remove old FILE OPEN commands for our target file only
                HarbourLogger.log(project, "HarbourDebugger", "Removing old FILE OPEN entry for target file: " + line);
                continue;
            }
            // NOTE: We now preserve Options Path as it's needed for source file lookup
            // The user manually added the correct path, so we should keep it
            // Keep other lines (Options Colors, Window settings, etc.)
            filteredLines.add(line);
        }
        
        // NOTE: FILE OPEN command removed - causes "Command Error" in Harbour debugger
        // The debugger will work with just breakpoint entries
        HarbourLogger.log(project, "HarbourDebugger", "Skipping FILE OPEN command (causes Command Error)");
        
        // Add new breakpoints
        HarbourLogger.log(project, "HarbourDebugger", "Adding new breakpoints...");
        
        int addedBreakpoints = 0;
        for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
            if (bp instanceof XLineBreakpoint &&
                    bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                    bp.getSourcePosition() != null) {

                VirtualFile file = bp.getSourcePosition().getFile();
                String fileName = file.getName();
                int line = bp.getSourcePosition().getLine() + 1;
                String filePath = file.getPath();
                
                HarbourLogger.log(project, "HarbourDebugger", "  Checking breakpoint - file: " + fileName + ", path: " + filePath + ", line: " + line);
                HarbourLogger.log(project, "HarbourDebugger", "  Target file: " + targetPrgFile);
                HarbourLogger.log(project, "HarbourDebugger", "  Init.cld directory: " + initCldFile.getParent());

                // Add ALL breakpoints from files in the project directory
                String initCldDir = initCldFile.getParent();
                boolean isInProjectDir = false;
                
                if (initCldDir != null) {
                    // Normalize both paths to use the same separator for comparison
                    String normalizedFilePath = filePath.replace('\\', '/').replace('/', File.separatorChar);
                    String normalizedInitCldDir = initCldDir.replace('\\', '/').replace('/', File.separatorChar);
                    
                    isInProjectDir = normalizedFilePath.startsWith(normalizedInitCldDir) || normalizedFilePath.contains(normalizedInitCldDir);
                    HarbourLogger.log(project, "HarbourDebugger", "  Normalized file path: " + normalizedFilePath);
                    HarbourLogger.log(project, "HarbourDebugger", "  Normalized init.cld dir: " + normalizedInitCldDir);
                } else {
                    // If initCldDir is null (file in current directory), try to get the absolute parent
                    try {
                        String absoluteParent = initCldFile.getAbsoluteFile().getParent();
                        if (absoluteParent != null) {
                            // Normalize both paths for comparison
                            String normalizedFilePath = filePath.replace('\\', '/').replace('/', File.separatorChar);
                            String normalizedAbsoluteParent = absoluteParent.replace('\\', '/').replace('/', File.separatorChar);
                            
                            isInProjectDir = normalizedFilePath.startsWith(normalizedAbsoluteParent) || normalizedFilePath.contains(normalizedAbsoluteParent);
                            HarbourLogger.log(project, "HarbourDebugger", "  Using absolute parent: " + absoluteParent);
                            HarbourLogger.log(project, "HarbourDebugger", "  Normalized file path: " + normalizedFilePath);
                            HarbourLogger.log(project, "HarbourDebugger", "  Normalized absolute parent: " + normalizedAbsoluteParent);
                        } else {
                            // Last resort: include all .prg files in same directory
                            isInProjectDir = fileName.endsWith(".prg");
                            HarbourLogger.log(project, "HarbourDebugger", "  No parent directory available - including .prg files only");
                        }
                    } catch (Exception e) {
                        // Fallback: include all .prg files
                        isInProjectDir = fileName.endsWith(".prg");
                        HarbourLogger.log(project, "HarbourDebugger", "  Exception getting parent - including .prg files: " + e.getMessage());
                    }
                }
                
                HarbourLogger.log(project, "HarbourDebugger", "  Is in project dir: " + isInProjectDir + " (initCldDir: " + initCldDir + ")");
                
                if (isInProjectDir) {
                    // Use just filename for BP command
                    String bpLine = "BP " + line + " " + fileName;
                    filteredLines.add(bpLine);
                    addedBreakpoints++;
                    HarbourLogger.log(project, "HarbourDebugger", "Added BP entry: " + bpLine);
                } else {
                    HarbourLogger.log(project, "HarbourDebugger", "  Skipping breakpoint - not in project directory");
                }
            }
        }
        
        HarbourLogger.log(project, "HarbourDebugger", "Added " + addedBreakpoints + " breakpoints total");
        
        // Write updated content
        HarbourLogger.log(project, "HarbourDebugger", "Writing " + filteredLines.size() + " lines to init.cld");
        
        for (int i = 0; i < filteredLines.size(); i++) {
            HarbourLogger.log(project, "HarbourDebugger", "Writing line " + i + ": " + filteredLines.get(i));
        }
        
        try (FileWriter writer = new FileWriter(initCldFile)) {
            String lineEnding = System.getProperty("line.separator");
            HarbourLogger.log(project, "HarbourDebugger", "Using line ending: " + lineEnding.replace("\r", "\\r").replace("\n", "\\n"));
            
            for (String line : filteredLines) {
                writer.write(line + lineEnding);
            }
            writer.flush();
        }
        
        HarbourLogger.log(project, "HarbourDebugger", "Successfully wrote init.cld file");
        
        // Verify the file was written
        if (initCldFile.exists()) {
            long fileSize = initCldFile.length();
            HarbourLogger.log(project, "HarbourDebugger", "File verification: exists=" + true + ", size=" + fileSize);
            
            // Read back and verify content
            try {
                List<String> writtenLines = java.nio.file.Files.readAllLines(initCldFile.toPath());
                HarbourLogger.log(project, "HarbourDebugger", "Verification: Read back " + writtenLines.size() + " lines");
                for (int i = 0; i < writtenLines.size(); i++) {
                    HarbourLogger.log(project, "HarbourDebugger", "Verified line " + i + ": " + writtenLines.get(i));
                }
            } catch (IOException e) {
                HarbourLogger.log(project, "HarbourDebugger", "Could not read back file for verification: " + e.getMessage());
            }
        } else {
            HarbourLogger.log(project, "HarbourDebugger", "WARNING: File does not exist after writing!");
        }
        
        HarbourLogger.log(project, "HarbourDebugger", 
            "Updated init.cld with " + addedBreakpoints + " breakpoints for " + targetPrgFile);
    }

    @NotNull
    @Override
    public ExecutionResult execute(@NotNull Executor executor, @NotNull com.intellij.execution.runners.ProgramRunner<?> runner)
            throws ExecutionException {
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "========= EXECUTE DEBUG =========");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "execute() method called");
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "About to call startProcess()");
        
        ProcessHandler processHandler = startProcess();
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "startProcess() completed");

        TextConsoleBuilder consoleBuilder = TextConsoleBuilderFactory.getInstance()
                .createBuilder(env.getProject());
        consoleBuilder.filters(new HarbourCompilerOutputFilter(env.getProject()));
        ConsoleView console = consoleBuilder.getConsole();
        console.attachToProcess(processHandler);

        // Print the exact command to the PyCharm console
        if (lastExecutedCommand != null) {
            console.print("=== EXACT HBMK2 COMMAND ===\n", com.intellij.execution.ui.ConsoleViewContentType.SYSTEM_OUTPUT);
            console.print(lastExecutedCommand + "\n", com.intellij.execution.ui.ConsoleViewContentType.SYSTEM_OUTPUT);
            console.print("================================\n", com.intellij.execution.ui.ConsoleViewContentType.SYSTEM_OUTPUT);
        }

        return new DefaultExecutionResult(console, processHandler);
    }
    
    /**
     * Copy the remote debug library from resources to working directory
     */
    private void copyDebugLibrary(String workingDir) throws ExecutionException {
        // Copy the debug library to build directory (.hbmk) to avoid cluttering project directory
        String buildDir = workingDir + File.separator + ".hbmk";
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Copying IntelliJ debug library to build directory: " + buildDir);
        
        // Ensure build directory exists
        File buildDirFile = new File(buildDir);
        if (!buildDirFile.exists()) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Build directory does not exist, creating: " + buildDir);
            if (!buildDirFile.mkdirs()) {
                throw new ExecutionException("Failed to create build directory: " + buildDir);
            }
        }
        
        // Copy harbour_debug_simple.prg to build directory (for console programs)
        File debugLibFile = new File(buildDir, "harbour_debug_simple.prg");
        try {
            copyResourceFile(debugLibFile, "/debug/harbour_debug_simple.prg");
        } catch (IOException e) {
            throw new ExecutionException("Failed to copy simple debug library: " + e.getMessage(), e);
        }
    }
    
    
    private void copyResourceFile(File targetFile) throws IOException, ExecutionException {
        copyResourceFile(targetFile, "/debug/harbour_debug.prg");
    }
    
    private void copyResourceFile(File targetFile, String resourcePath) throws IOException, ExecutionException {
        try (InputStream resourceStream = getClass().getResourceAsStream(resourcePath)) {
            if (resourceStream == null) {
                throw new ExecutionException("Resource not found: " + resourcePath);
            }
            Files.copy(resourceStream, targetFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            
            // Verify the file was copied
            if (targetFile.exists()) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Successfully copied " + resourcePath + " to " + targetFile.getAbsolutePath() + 
                        " (size: " + targetFile.length() + " bytes)");
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "ERROR: Failed to copy " + resourcePath + " to " + targetFile.getAbsolutePath());
            }
        }
    }
    
    /**
     * Determines if we should instrument the source file for debugging
     */
    private boolean shouldInstrumentSource() {
        // VM-based debugging - no instrumentation needed
        // The Harbour VM will call __dbgEntry automatically when compiled with -b flag
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "VM-based debugging - instrumentation disabled");
        return false;
    }

}
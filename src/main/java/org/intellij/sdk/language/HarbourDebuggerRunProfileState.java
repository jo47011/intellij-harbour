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
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.execution.ui.ConsoleView;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.project.Project;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.breakpoints.XBreakpoint;

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
    private String originalWorkingDir; // Store original working directory for GUI executable launch
    private boolean isDebugMode = false; // Track whether we're running in debug vs run mode

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
        
        // Check if mute state is available from HarbourDebuggerRunner (two-phase startup)
        Boolean globalMuteState = env.getUserData(HarbourDebuggerRunner.GLOBAL_MUTE_STATE_KEY);
        if (globalMuteState != null) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Two-phase startup: Using actual mute state from runner: " + globalMuteState);
            exportBreakpointsToFile(globalMuteState);
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Two-phase startup: Mute state not available, using fallback approach");
            exportBreakpointsToFile();
        }
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "exportBreakpointsToFile() call completed");

        GeneralCommandLine commandLine = new GeneralCommandLine();

        if (runConfig.isUseDirectExecution()) {
            runCompiledHarbourProgram(commandLine);
        } else {
            compileAndRunHarbourProgram(commandLine);
        }

        commandLine.setRedirectErrorStream(true);
        
        // FIXED: Program type detection for reference only - no manual parameter override
        boolean isGuiProgram = isGuiProgram(runConfig);
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "FIXED: Program type detection: " + (isGuiProgram ? "GUI" : "Console") + " (based on config/hbp only)");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "FIXED: No manual parameter additions - respecting user's compiler options");
        
        // Log full command details before starting
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Starting process with command: " + commandLine.getCommandLineString());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Working directory: " + commandLine.getWorkDirectory());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Environment variables count: " + commandLine.getEnvironment().size());
        
        // DEBUGGING: Log key environment variables for comparison with manual execution
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "PATH: " + commandLine.getEnvironment().get("PATH"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "TEMP: " + commandLine.getEnvironment().get("TEMP"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Current working directory (Java): " + System.getProperty("user.dir"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Project base path: " + env.getProject().getBasePath());
        
        // Add comprehensive debugging for Windows connection issues
        String osName = System.getProperty("os.name", "").toLowerCase();
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "========= CONNECTION DEBUGGING v1.0.240 =========");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "OS detected: " + osName);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Debug library selection: " + (osName.contains("windows") ? "Windows Simple" : "Unix Standard"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "HB_REMOTE_DEBUG environment variable: " + commandLine.getEnvironment().get("HB_REMOTE_DEBUG"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "HB_DBG_PATH environment variable: " + commandLine.getEnvironment().get("HB_DBG_PATH"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Expected debug protocol: TCP socket on port 9876");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Expected PyCharm behavior: Should listen on 127.0.0.1:9876 for incoming connections");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "================================================");

        OSProcessHandler handler;
        try {
            String currentOS = System.getProperty("os.name").toLowerCase();
            boolean isWindowsConsole = currentOS.contains("windows") && !isGuiProgram(runConfig);
            
            // UNIFIED APPROACH: Use single-phase compile+run for all platforms
            // This ensures proper debug console integration
            handler = new OSProcessHandler(commandLine);
            
            if (isWindowsConsole) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Windows Console: Using unified single-phase approach for console integration");
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Using standard OSProcessHandler for " + (currentOS.contains("windows") ? "Windows GUI" : "Unix"));
            }
            
            // UNIFIED APPROACH: Use same ProcessTerminatedListener handling as successful Unix
            // Based on successful Unix implementation, skip ProcessTerminatedListener for remote debugging
            // This allows debug connection to outlive process for ALL programs
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "UNIFIED: Skipping ProcessTerminatedListener to allow remote debug connection to outlive process");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "UNIFIED: Using same approach as successful Unix implementation");
            
            // HANGING ISSUE DEBUG v1.0.516: Add timing logging around startNotify()
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "HANGING DEBUG: About to call handler.startNotify()");
            long startTime = System.currentTimeMillis();
            
            handler.startNotify();
            
            long endTime = System.currentTimeMillis();
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "HANGING DEBUG: startNotify() completed in " + (endTime - startTime) + "ms");
            
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
                    
                    // FIXED: For GUI applications, launch executable after successful compilation
                    if (event.getExitCode() == 0 && isGuiProgram) {
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                "GUI APPLICATION: Compilation successful, launching executable for debugging");
                        
                        try {
                            // Determine executable name from build target
                            String buildTarget = runConfig.getSourceFile();
                            String exeName;
                            String currentOS = System.getProperty("os.name").toLowerCase();
                            String exeExtension = currentOS.contains("windows") ? ".exe" : "";
                            
                            if (buildTarget.endsWith(".hbp")) {
                                // For .hbp files, use the project name
                                File hbpFile = new File(buildTarget);
                                String projectName = hbpFile.getName().replace(".hbp", "");
                                exeName = projectName + exeExtension;
                            } else {
                                // For .prg files, use the source name
                                File sourceFile = new File(buildTarget);
                                String sourceName = sourceFile.getName().replace(".prg", "");
                                exeName = sourceName + exeExtension;
                            }
                            
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                    "CRITICAL FIX v1.0.348: Using OS-appropriate executable extension: '" + exeExtension + "'");
                            
                            // Launch executable in original project directory (not hbmk2's working directory)
                            File projectDir = new File(originalWorkingDir);
                            File executable = new File(projectDir, exeName);
                            
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                    "Looking for GUI executable in original directory: " + projectDir.getAbsolutePath());
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                    "Expected executable path: " + executable.getAbsolutePath());
                            
                            if (executable.exists()) {
                                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                        "Found GUI executable: " + executable.getAbsolutePath());
                                
                                // Create command to launch executable with debug environment
                                GeneralCommandLine launchCommand = new GeneralCommandLine();
                                launchCommand.setExePath(executable.getAbsolutePath());
                                launchCommand.setWorkDirectory(projectDir);
                                launchCommand.withEnvironment("HB_REMOTE_DEBUG", "1");
                                launchCommand.withEnvironment("HB_DBG_PATH", projectDir.getAbsolutePath());
                                
                                // Launch as separate process for debugging
                                OSProcessHandler launchHandler = new OSProcessHandler(launchCommand);
                                launchHandler.startNotify();
                                
                                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                        "GUI executable launched successfully for debugging");
                            } else {
                                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                        "GUI executable not found: " + executable.getAbsolutePath());
                                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                        "CRITICAL FIX v1.0.342: Check original working directory vs hbmk2 working directory");
                            }
                        } catch (Exception e) {
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                    "Error launching GUI executable: " + e.getMessage());
                        }
                    }
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
    
    /* REMOVED: executeCompiledProgram method - no longer needed with unified single-phase approach
     * This two-phase approach was causing console output to go to Terminal instead of PyCharm Debug Console
     * Now using unified single-phase compile+run approach for all platforms for proper PyCharm integration
     */

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
        
        // Save original working directory for GUI executable launch
        originalWorkingDir = workingDir;
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Saved original working directory: " + originalWorkingDir);
        
        // RESTART FIX: Clean up any running processes and executables before compilation
        cleanupExecutableBeforeCompilation(commandLine);
        terminateRunningProcesses();
        
        // Copy debug libraries to build directory before compilation (debug mode only)
        if (isDebugMode) {
            copyDebugLibrary(workingDir);
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
        
        // Copy harbour_debug.prg to build directory for console programs (debug mode only)
        // This provides network connectivity for PyCharm debugging
        if (isDebugMode) {
            File debugLibFile = new File(buildDirFile, "harbour_debug.prg");
            try {
                copyResourceFile(debugLibFile, "/debugger/harbour_debug.prg");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE: Copied debug library to: " + debugLibFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to copy debug library: " + e.getMessage());
                // Continue without debug library
            }
            
            // Also copy harbour_error_handler.prg which is included by harbour_debug.prg
            File errorHandlerFile = new File(buildDirFile, "harbour_error_handler.prg");
            try {
                copyResourceFile(errorHandlerFile, "/debugger/harbour_error_handler.prg");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE: Copied error handler to: " + errorHandlerFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to copy error handler: " + e.getMessage());
                // Continue without error handler
            }
            
            // Copy harbour_error_monitor.prg for debug mode
            File errorMonitorFile = new File(buildDirFile, "harbour_error_monitor.prg");
            try {
                copyResourceFile(errorMonitorFile, "/debugger/harbour_error_monitor.prg");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE: Copied error monitor to: " + errorMonitorFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to copy error monitor: " + e.getMessage());
            }
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE: Copying error monitoring files");
            
            // For run mode, copy error handler and monitor files
            File errorHandlerFile = new File(buildDirFile, "harbour_error_handler.prg");
            try {
                copyResourceFile(errorHandlerFile, "/debugger/harbour_error_handler.prg");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "RUN MODE: Copied error handler to: " + errorHandlerFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to copy error handler: " + e.getMessage());
            }
            
            File errorMonitorFile = new File(buildDirFile, "harbour_error_monitor.prg");
            try {
                copyResourceFile(errorMonitorFile, "/debugger/harbour_error_monitor.prg");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "RUN MODE: Copied error monitor to: " + errorMonitorFile.getAbsolutePath());
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Warning: Failed to copy error monitor: " + e.getMessage());
            }
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
        
        // Get OS name once for use throughout the method
        String currentOS = System.getProperty("os.name").toLowerCase();
        
        // PLATFORM-SPECIFIC DEBUG LIBRARY: Added later after compiler options
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Debug library will be added after compiler options for proper parameter order");
        
        // Check if we're in debug mode before adding debug-specific parameters
        if (isDebugMode) {
            // DEBUG MODE: Add debug-specific compilation flags
            parameters.add("-b");
            
            if (isGui) {
                // GUI programs: Compile only, don't auto-launch with -run
                // PyCharm will handle the executable launch separately for proper debugging
                parameters.add("-debug");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - GUI PROGRAM: Added debug flags: -b -debug (no -run for GUI apps)");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - GUI STRATEGY: Compile only, let PyCharm handle executable launch for proper debugging context");
            } else {
                // Console programs: Use -run for immediate execution
                parameters.add("-run");
                parameters.add("-debug");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - CONSOLE PROGRAM: Added debug flags: -b -run -debug");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - CONSOLE STRATEGY: Immediate execution with -run flag");
            }
        } else {
            // RUN MODE: Standard compilation without debug flags
            if (isGui) {
                // GUI programs: Just compile
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "RUN MODE - GUI PROGRAM: Standard compilation (no debug flags)");
            } else {
                // Console programs: Use -run for immediate execution
                parameters.add("-run");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "RUN MODE - CONSOLE PROGRAM: Standard compilation with -run");
            }
        }
        
        boolean isWindowsConsole = currentOS.contains("windows") && !isGui;
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Purpose: Enable debugging symbols and immediate execution with console integration");
        
        // Remove FORCE_DEBUG_MODE - it was triggering Harbour debugger instead of PyCharm
        // parameters.add("-DFORCE_DEBUG_MODE=1");  // REMOVED - not in working version
        
        // Add debug defines only in debug mode
        if (isDebugMode) {
            parameters.add("-D__HARBOUR_DEBUG__");
            parameters.add("-DDBG_PORT=" + runConfig.getDebugPort());
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "DEBUG MODE: Added debug defines: -D__HARBOUR_DEBUG__ -DDBG_PORT=" + runConfig.getDebugPort());
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE: Skipped debug defines");
        }
        
        // FIXED: No manual GUI parameter additions
        // Let compiler options from config and .hbp files determine GUI settings
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "FIXED: No manual GUI parameter additions - using config/hbp settings only");

        // Add compiler options before debug library
        if (!StringUtil.isEmpty(runConfig.getCompilerOptions())) {
            parameters.addAll(StringUtil.split(runConfig.getCompilerOptions(), " "));
        }
        
        // Add rebuild flag if requested
        if (runConfig.isUseRebuildFlag()) {
            parameters.add("-rebuild");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added -rebuild flag to compiler arguments");
        }

        // Add error handling libraries - order matters!
        String errorHandlerPath;
        String errorMonitorPath;
        
        if (currentOS.contains("windows")) {
            errorHandlerPath = buildDir + "\\" + "harbour_error_handler.prg";
            errorMonitorPath = buildDir + "\\" + "harbour_error_monitor.prg";
        } else {
            errorHandlerPath = buildDir + File.separator + "harbour_error_handler.prg";
            errorMonitorPath = buildDir + File.separator + "harbour_error_monitor.prg";
        }
        
        // Always add error handler first (provides functions)
        parameters.add(errorHandlerPath);
        
        // Add debug library only in debug mode
        if (isDebugMode && !finalBuildTarget.endsWith("harbour_debug.prg")) {
            String debugSourcePath;
            
            if (currentOS.contains("windows")) {
                debugSourcePath = buildDir + "\\" + "harbour_debug.prg";
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - WINDOWS: Adding debug library: " + debugSourcePath);
            } else {
                debugSourcePath = buildDir + File.separator + "harbour_debug.prg";
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - UNIX: Adding debug library: " + debugSourcePath);
            }
            
            // Add error monitor then debug library
            parameters.add(errorMonitorPath);
            parameters.add(debugSourcePath);
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "DEBUG MODE: Added error handler, monitor and debug library");
        } else if (!isDebugMode) {
            // For run mode, add error monitor
            parameters.add(errorMonitorPath);
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE: Added error handler and monitor for error capture");
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

        // All cases: Use normal command construction
        // Windows console programs will still create popup, but environment variables work correctly
        commandLine.addParameters(parameters);
        if (currentOS.contains("windows") && !isGui) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Windows Console: Using direct execution (environment variables preserved)");
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Using normal command construction");
        }
        
        // UNIFIED APPROACH: Use same path format as successful Unix implementation
        // Keep Unix-style paths for debugging compatibility
        String finalWorkingDir = workingDir;
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "UNIFIED: Using same path format as Unix for debugging compatibility: " + finalWorkingDir);
        
        commandLine.setWorkDirectory(finalWorkingDir);
        
        // WINDOWS PROCESS CREATION: Try alternative approach for console popup suppression
        if (currentOS.contains("windows")) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Windows: IntelliJ 2024.3.4 - myCreationFlags field not available, trying alternative approach");
            
            // Alternative 1: Try using ProcessBuilder approach through environment
            // Set Windows-specific environment to minimize console visibility
            commandLine.withEnvironment("_CONSOLE_LOGON", "0");
            commandLine.withEnvironment("SUBPROCESS_MODE", "1");
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Windows: Set alternative environment variables to minimize console visibility");
            
            // Alternative 2: Consider using different process creation pattern
            // The myProcessCreator function might be customizable in newer IntelliJ versions
            try {
                java.lang.reflect.Field processCreatorField = GeneralCommandLine.class.getDeclaredField("myProcessCreator");
                processCreatorField.setAccessible(true);
                Object currentCreator = processCreatorField.get(commandLine);
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Windows: Current process creator: " + (currentCreator != null ? currentCreator.getClass().getName() : "null"));
                
                // Note: In newer IntelliJ, process creation might be handled differently
                // This logs the current approach for potential future customization
                
            } catch (Exception e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Windows: Process creator inspection failed: " + e.getMessage());
            }
        }
        
        // DEBUGGING APPROACH: Set debug environment variables only in debug mode
        if (isDebugMode) {
            String debugPath = finalWorkingDir != null ? finalWorkingDir : ".";
            commandLine.withEnvironment("HB_DBG_PATH", debugPath);
            commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "DEBUG MODE: Set debug environment variables - HB_DBG_PATH=" + debugPath + ", HB_REMOTE_DEBUG=1");
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE: Skipped debug environment variables");
        }
        
        // WINDOWS-SPECIFIC: Add environment variables for Windows debug library (debug mode only)
        if (currentOS.contains("windows") && isDebugMode) {
            // Help Windows debug library detect GUI mode
            if (isGui) {
                commandLine.withEnvironment("HB_GUI_MODE", "1");
                commandLine.withEnvironment("HB_GT_LIB", "GTWVT");
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - Windows: Set GUI mode environment variables");
            } else {
                // Windows Console: Back to NUL approach with enhanced output handling
                commandLine.withEnvironment("HB_GUI_MODE", "0");     // Console mode
                commandLine.withEnvironment("HB_GT_LIB", "GTNUL");   // NULL terminal  
                commandLine.withEnvironment("HB_GT_DEFAULT", "NUL"); // NULL terminal
                // Force output to stdout/stderr for PyCharm capture
                commandLine.withEnvironment("HB_FORCE_STDOUT", "1");
                commandLine.withEnvironment("HARBOUR_STDOUT_REDIRECT", "1");
                // Ensure temp directory is in working directory, not C:\WINDOWS
                commandLine.withEnvironment("TMP", finalWorkingDir);
                commandLine.withEnvironment("TEMP", finalWorkingDir);
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "DEBUG MODE - Windows: Using NUL terminal with forced stdout redirection for PyCharm capture");
            }
        } else if (currentOS.contains("windows") && !isDebugMode) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE - Windows: Skipped debug library environment variables");
        }
        
        // CRITICAL: Do NOT set ALTD=BREAK as it conflicts with PyCharm remote debugging
        // ALTD=BREAK triggers Harbour's internal debugger instead of PyCharm debugger
        
        // Add comprehensive logging for debugging analysis
        boolean isWindows = currentOS.contains("windows");
        
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "=== UNIFIED DEBUGGING APPROACH ===");
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Operating System: " + currentOS);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Platform: " + (isWindows ? "Windows" : "Unix/Linux"));
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Program Type Detection: " + (isGuiProgram ? "GUI" : "Console") + " (for reference only)");
        if (isDebugMode) {
            String debugPath = finalWorkingDir != null ? finalWorkingDir : ".";
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "DEBUG MODE: PyCharm Remote Debugging Environment: HB_DBG_PATH=" + debugPath + ", HB_REMOTE_DEBUG=1");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Target: PyCharm remote debugging for ALL programs (no ALTD=BREAK)");
        } else {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "RUN MODE: No debugging environment set");
        }
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
            
            // Default for standalone .prg files: console program
            // GUI detection only from compiler options or .hbp file contents, NOT filename
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Standalone .prg file - treating as console program (no GUI flags in compiler options)");
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

        // RESTART FIX: Terminate any running instances before starting
        terminateRunningProcesses();

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
        
        // Set debug environment variables only in debug mode
        if (isDebugMode) {
            commandLine.withEnvironment("HB_DBG_PATH", ".");
            commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
        }
        
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

    private void exportBreakpointsToFile(boolean globallyMuted) {
        Project project = env.getProject();
        XBreakpointManager breakpointManager = XDebuggerManager.getInstance(project).getBreakpointManager();

        // COMPREHENSIVE DEBUG LOGGING
        HarbourLogger.log(project, "HarbourDebugger", "========= EXPORT BREAKPOINTS DEBUG START (WITH MUTE STATE) =========");
        
        // Check if this method is actually being called
        HarbourLogger.log(project, "HarbourDebugger", "exportBreakpointsToFile(boolean) method called with globallyMuted: " + globallyMuted);
        
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
        
        List<File> breakpointFiles = new ArrayList<>();
        breakpointFiles.add(breakpointFile);
        
        if (System.getProperty("os.name").toLowerCase().contains("windows") && 
            runConfig.getSourceFile().endsWith(".hbp")) {
            File hbpDir = new File(runConfig.getSourceFile()).getParentFile();
            File altBreakpointFile = new File(hbpDir, breakpointFileName);
            if (!altBreakpointFile.equals(breakpointFile)) {
                breakpointFiles.add(altBreakpointFile);
            }
            
            File hbmkBuildDir = new File(hbpDir, ".hbmk");
            if (hbmkBuildDir.exists() || hbmkBuildDir.mkdirs()) {
                File hbmkBreakpointFile = new File(hbmkBuildDir, breakpointFileName);
                if (!hbmkBreakpointFile.equals(breakpointFile) && !hbmkBreakpointFile.equals(altBreakpointFile)) {
                    breakpointFiles.add(hbmkBreakpointFile);
                }
            }
        }

        if (!breakpointFile.getParentFile().exists()) {
            if (!breakpointFile.getParentFile().mkdirs()) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", "Failed to create breakpoint directory");
            }
        }

        String sourceFilePath = runConfig.getSourceFile();
        if (!new File(sourceFilePath).isAbsolute()) {
            sourceFilePath = new File(workingDir, sourceFilePath).getAbsolutePath();
        }
        String targetPrgFile = getMainPrgFileFromSource(sourceFilePath);
        HarbourLogger.log(project, "HarbourDebugger", "Target .prg file for debugging: " + targetPrgFile);
        
        // Count total enabled breakpoints
        int totalBreakpoints = 0;
        for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
            if (bp instanceof XLineBreakpoint &&
                    bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                    bp.getSourcePosition() != null) {

                VirtualFile file = bp.getSourcePosition().getFile();
                String fileName = file.getName();

                if (fileName.equals(targetPrgFile)) {
                    if (bp.isEnabled()) {
                        totalBreakpoints++;
                    }
                }
            }
        }
        
        HarbourLogger.log(project, "HarbourDebugger", 
                "TWO-PHASE APPROACH: Global mute state: " + globallyMuted + 
                ", Total enabled breakpoints: " + totalBreakpoints);
        
        for (File bpFile : breakpointFiles) {
            try {
                if (!bpFile.getParentFile().exists()) {
                    bpFile.getParentFile().mkdirs();
                }
                
                if (globallyMuted) {
                    // Create minimal init.cld when globally muted
                    try (java.io.FileWriter writer = new java.io.FileWriter(bpFile)) {
                        writer.write("// IntelliJ-managed breakpoints - globally muted, all breakpoints via remote protocol\n");
                    }
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Created minimal init.cld (muted mode) at: " + bpFile.getAbsolutePath());
                } else {
                    // Write full breakpoints to init.cld when not muted
                    updateInitCldFile(bpFile, targetPrgFile, totalBreakpoints, breakpointManager, project);
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Created full init.cld with " + totalBreakpoints + " breakpoints at: " + bpFile.getAbsolutePath());
                }
            } catch (IOException e) {
                HarbourLogger.log(project, "HarbourDebugger", "Failed to create init.cld at " + 
                    bpFile.getAbsolutePath() + ": " + e.getMessage());
            }
        }

        HarbourLogger.log(project, "HarbourDebugger", "========= EXPORT BREAKPOINTS DEBUG END (WITH MUTE STATE) =========");
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
            
            // Also write to .hbmk build directory where hbmk2 may look for files
            File hbmkBuildDir = new File(hbpDir, ".hbmk");
            if (hbmkBuildDir.exists() || hbmkBuildDir.mkdirs()) {
                File hbmkBreakpointFile = new File(hbmkBuildDir, breakpointFileName);
                if (!hbmkBreakpointFile.equals(breakpointFile) && !hbmkBreakpointFile.equals(altBreakpointFile)) {
                    breakpointFiles.add(hbmkBreakpointFile);
                    HarbourLogger.log(project, "HarbourDebugger", "Windows .hbp detected - also writing init.cld to .hbmk build dir: " + 
                        hbmkBreakpointFile.getAbsolutePath());
                }
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
        // Count total enabled breakpoints and check for potential global mute
        int totalBreakpointsAvailable = 0;
        int individuallyDisabledCount = 0;
        
        for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
            if (bp instanceof XLineBreakpoint &&
                    bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                    bp.getSourcePosition() != null) {

                VirtualFile file = bp.getSourcePosition().getFile();
                String fileName = file.getName();

                // Count breakpoints for the file we're actually debugging
                if (fileName.equals(originalFileName) || 
                    (isInstrumented && fileName.equals(targetPrgFile))) {
                    totalBreakpointsAvailable++;
                    
                    if (bp.isEnabled()) {
                        totalBreakpoints++;
                        breakpointFileNames.add(fileName);
                    } else {
                        individuallyDisabledCount++;
                    }
                }
            }
        }
        
        // Check last known global mute state from settings
        HarbourSettings settings = HarbourSettings.getInstance(project);
        boolean lastKnownMuteState = false;
        if (settings != null) {
            lastKnownMuteState = settings.getLastKnownGlobalMuteState();
            HarbourLogger.log(project, "HarbourDebugger", 
                    "Last known global mute state from settings: " + lastKnownMuteState);
        }
        
        // Heuristic: If we have breakpoints but none are individually disabled, 
        // they might be globally muted (since global mute doesn't change individual isEnabled())
        boolean possiblyGloballyMuted = (totalBreakpointsAvailable > 0) && 
                                      (individuallyDisabledCount == 0) && 
                                      (totalBreakpoints == totalBreakpointsAvailable);
        
        HarbourLogger.log(project, "HarbourDebugger", 
                "Breakpoint analysis: total=" + totalBreakpointsAvailable + 
                ", enabled=" + totalBreakpoints + 
                ", individually disabled=" + individuallyDisabledCount + 
                ", possibly globally muted=" + possiblyGloballyMuted);
        
        // HARMONIZED SOLUTION: Use last known mute state to decide init.cld content
        boolean shouldUseMinimalInitCld = lastKnownMuteState;
        
        HarbourLogger.log(project, "HarbourDebugger", 
                "HARMONIZED APPROACH: Using " + (shouldUseMinimalInitCld ? "minimal" : "full") + 
                " init.cld based on last known mute state: " + lastKnownMuteState);
        
        for (File bpFile : breakpointFiles) {
            try {
                if (!bpFile.getParentFile().exists()) {
                    bpFile.getParentFile().mkdirs();
                }
                
                if (shouldUseMinimalInitCld) {
                    // Create minimal init.cld when globally muted
                    try (java.io.FileWriter writer = new java.io.FileWriter(bpFile)) {
                        writer.write("// IntelliJ-managed breakpoints - globally muted, all breakpoints via remote protocol\n");
                    }
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Created minimal init.cld (muted mode) at: " + bpFile.getAbsolutePath());
                } else {
                    // Write full breakpoints to init.cld when not muted
                    updateInitCldFile(bpFile, targetPrgFile, totalBreakpoints, breakpointManager, project);
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Created full init.cld with " + totalBreakpoints + " breakpoints at: " + bpFile.getAbsolutePath());
                }
            } catch (IOException e) {
                HarbourLogger.log(project, "HarbourDebugger", "Failed to create init.cld at " + 
                    bpFile.getAbsolutePath() + ": " + e.getMessage());
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
                        // Removed flooding log message - was logging every HBP line
                        
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
        
        // Filter out ALL old BP entries and FILE OPEN commands to prevent growing
        List<String> filteredLines = new ArrayList<>();
        for (String line : existingLines) {
            String trimmedLine = line.trim();
            if (trimmedLine.startsWith("BP ")) {
                // Remove ALL old breakpoint entries to prevent file growing
                HarbourLogger.log(project, "HarbourDebugger", "Removing old BP entry: " + line);
                continue;
            }
            if (trimmedLine.startsWith("FILE OPEN ")) {
                // Remove ALL old FILE OPEN commands to prevent file growing
                HarbourLogger.log(project, "HarbourDebugger", "Removing old FILE OPEN entry: " + line);
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
        int skippedBreakpoints = 0;
        for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
            if (bp instanceof XLineBreakpoint &&
                    bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                    bp.getSourcePosition() != null) {
                    
                if (!bp.isEnabled()) {
                    // Log skipped disabled breakpoints with detailed info
                    VirtualFile file = bp.getSourcePosition().getFile();
                    String fileName = file.getName();
                    int line = bp.getSourcePosition().getLine() + 1;
                    
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "=== SKIPPING DISABLED BREAKPOINT ===");
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "File: " + fileName + ", Line: " + line);
                    HarbourLogger.log(project, "HarbourDebugger", 
                            "Enabled: " + bp.isEnabled() + " (muted/disabled)");
                    skippedBreakpoints++;
                    continue;
                }
                
                // Log enabled breakpoints
                VirtualFile file = bp.getSourcePosition().getFile();
                String fileName = file.getName();
                int line = bp.getSourcePosition().getLine() + 1;

                // Variables already declared above for logging
                String filePath = file.getPath();
                
                HarbourLogger.log(project, "HarbourDebugger", 
                        "=== WRITING BREAKPOINT TO init.cld ===");
                HarbourLogger.log(project, "HarbourDebugger", 
                        "File: " + fileName + ", Line: " + line);
                HarbourLogger.log(project, "HarbourDebugger", 
                        "Enabled: " + bp.isEnabled() + " (should be true)");
                
                // Removed flooding log message - was logging every breakpoint check
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
        
        HarbourLogger.log(project, "HarbourDebugger", "Added " + addedBreakpoints + " enabled breakpoints");
        HarbourLogger.log(project, "HarbourDebugger", "Skipped " + skippedBreakpoints + " disabled/muted breakpoints");
        
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
        
        // Check if this is debug mode and if mute state is available from HarbourDebuggerRunner
        this.isDebugMode = DefaultDebugExecutor.EXECUTOR_ID.equals(executor.getId());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Executor mode: " + (this.isDebugMode ? "DEBUG" : "RUN") + " (ID: " + executor.getId() + ")");
        
        // Create console BEFORE starting process to capture all output
        TextConsoleBuilder consoleBuilder = TextConsoleBuilderFactory.getInstance()
                .createBuilder(env.getProject());
        consoleBuilder.filters(new HarbourCompilerOutputFilter(env.getProject(), runConfig.getWorkingDirectory()));
        ConsoleView console = consoleBuilder.getConsole();
        
        ProcessHandler processHandler = startProcess();
        
        // Attach console immediately after process creation to ensure no output is lost
        console.attachToProcess(processHandler);
        
        // Set the console in HarbourLogger
        HarbourLogger.setConsole(console);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Console logging enabled", HarbourLogger.LogLevel.DEBUG);

        // File monitor for error display in console
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "About to start error file monitor");
        startHarbourErrorFileMonitor(console, env.getProject());
        HarbourLogger.log(env.getProject(), "HarbourDebugger", "Error file monitor started");
        
        // Clear console after monitors are set up but before showing command
        console.clear();

        // Print the exact command to the console
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
                "Copying IntelliJ debug libraries to build directory: " + buildDir);
        
        // Ensure build directory exists
        File buildDirFile = new File(buildDir);
        if (!buildDirFile.exists()) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Build directory does not exist, creating: " + buildDir);
            if (!buildDirFile.mkdirs()) {
                throw new ExecutionException("Failed to create build directory: " + buildDir);
            }
        }
        
        // Copy unified debug library (for all platforms)
        File standardDebugLibFile = new File(buildDir, "harbour_debug.prg");
        try {
            copyResourceFile(standardDebugLibFile, "/debugger/harbour_debug.prg");
        } catch (IOException e) {
            throw new ExecutionException("Failed to copy standard debug library: " + e.getMessage(), e);
        }
        
        // Also copy harbour_error_handler.prg which is included by harbour_debug.prg
        File errorHandlerFile = new File(buildDir, "harbour_error_handler.prg");
        try {
            copyResourceFile(errorHandlerFile, "/debugger/harbour_error_handler.prg");
        } catch (IOException e) {
            throw new ExecutionException("Failed to copy error handler library: " + e.getMessage(), e);
        }
        
        // Copy harbour_error_monitor.prg for error monitoring
        File errorMonitorFile = new File(buildDir, "harbour_error_monitor.prg");
        try {
            copyResourceFile(errorMonitorFile, "/debugger/harbour_error_monitor.prg");
        } catch (IOException e) {
            throw new ExecutionException("Failed to copy error monitor library: " + e.getMessage(), e);
        }
        
    }
    
    
    private void copyResourceFile(File targetFile) throws IOException, ExecutionException {
        copyResourceFile(targetFile, "/debugger/harbour_debug.prg");
    }
    
    private void copyResourceFile(File targetFile, String resourcePath) throws IOException, ExecutionException {
        // Check if target file already exists and compare with resource
        if (targetFile.exists()) {
            try (InputStream resourceStream = getClass().getResourceAsStream(resourcePath)) {
                if (resourceStream == null) {
                    throw new ExecutionException("Resource not found: " + resourcePath);
                }
                
                // Read resource content
                byte[] resourceBytes = resourceStream.readAllBytes();
                
                // Read existing file content
                byte[] existingBytes = Files.readAllBytes(targetFile.toPath());
                
                // Compare contents
                if (java.util.Arrays.equals(resourceBytes, existingBytes)) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Skipping copy of " + resourcePath + " - file unchanged (size: " + targetFile.length() + " bytes)");
                    return;
                }
                
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Updating " + resourcePath + " - content has changed");
            }
        }
        
        // File doesn't exist or content has changed - copy it
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
    
    /**
     * Clean up executable files before compilation to prevent "Permission denied" errors
     */
    private void cleanupExecutableBeforeCompilation(GeneralCommandLine commandLine) {
        try {
            String workingDir = commandLine.getWorkDirectory() != null ? 
                commandLine.getWorkDirectory().getAbsolutePath() : runConfig.getWorkingDirectory();
            
            if (workingDir == null) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "cleanupExecutableBeforeCompilation: No working directory, skipping cleanup");
                return;
            }
            
            // Determine executable name
            String sourceFile = runConfig.getSourceFile();
            String executableName;
            
            if (sourceFile.endsWith(".hbp")) {
                executableName = new File(sourceFile).getName().replace(".hbp", "");
            } else {
                executableName = new File(sourceFile).getName().replace(".prg", "");
            }
            
            String osName = System.getProperty("os.name").toLowerCase();
            String[] extensions;
            
            if (osName.contains("windows")) {
                extensions = new String[]{".exe", ""};
            } else {
                extensions = new String[]{"", ".exe"};
            }
            
            // Try to delete all possible executable files
            for (String ext : extensions) {
                File execFile = new File(workingDir, executableName + ext);
                if (execFile.exists()) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Attempting to delete executable: " + execFile.getAbsolutePath());
                    
                    if (!execFile.delete()) {
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Failed to delete executable, attempting force cleanup: " + execFile.getAbsolutePath());
                        
                        // If delete fails, try to kill processes using it
                        forceCleanupExecutable(execFile.getAbsolutePath());
                        
                        // Try delete again after cleanup
                        Thread.sleep(500);
                        if (execFile.delete()) {
                            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                "Successfully deleted executable after force cleanup");
                        }
                    } else {
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Successfully deleted executable: " + execFile.getAbsolutePath());
                    }
                }
            }
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Error in cleanupExecutableBeforeCompilation: " + e.getMessage());
        }
    }
    
    /**
     * Force cleanup of an executable file by killing processes using it
     */
    private void forceCleanupExecutable(String executablePath) {
        try {
            String osName = System.getProperty("os.name").toLowerCase();
            ProcessBuilder pb;
            
            if (osName.contains("windows")) {
                // Windows: Use handle.exe or wmic to find and kill processes
                String fileName = new File(executablePath).getName();
                pb = new ProcessBuilder("cmd", "/c", 
                    "taskkill /f /im \"" + fileName + "\"");
            } else {
                // Unix/Linux: Use fuser to kill processes using the file
                pb = new ProcessBuilder("bash", "-c", 
                    "fuser -k \"" + executablePath + "\" 2>/dev/null || true");
            }
            
            Process process = pb.start();
            boolean finished = process.waitFor(3, java.util.concurrent.TimeUnit.SECONDS);
            
            if (finished) {
                int exitCode = process.exitValue();
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Force cleanup executable finished with exit code: " + exitCode);
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Force cleanup executable timed out");
            }
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Error in forceCleanupExecutable: " + e.getMessage());
        }
    }
    
    /**
     * Terminate all running Harbour processes
     */
    private void terminateRunningProcesses() {
        try {
            String osName = System.getProperty("os.name").toLowerCase();
            
            // Get the base name of our program
            String sourceFile = runConfig.getSourceFile();
            String programName;
            
            if (sourceFile.endsWith(".hbp")) {
                programName = new File(sourceFile).getName().replace(".hbp", "");
            } else {
                programName = new File(sourceFile).getName().replace(".prg", "");
            }
            
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Terminating any running instances of: " + programName);
            
            ProcessBuilder pb;
            
            if (osName.contains("windows")) {
                // Windows: Kill by image name
                String[] commands = {
                    "taskkill /f /im \"" + programName + ".exe\" 2>nul",
                    "taskkill /f /im \"" + programName + "\" 2>nul"
                };
                
                for (String cmd : commands) {
                    pb = new ProcessBuilder("cmd", "/c", cmd);
                    executeKillCommand(pb, "Windows taskkill");
                }
            } else {
                // Unix/Linux: Kill by process name
                String[] commands = {
                    "pkill -f \"" + programName + "\" 2>/dev/null || true",
                    "killall \"" + programName + "\" 2>/dev/null || true"
                };
                
                for (String cmd : commands) {
                    pb = new ProcessBuilder("bash", "-c", cmd);
                    executeKillCommand(pb, "Unix kill");
                }
            }
            
            // Also kill any harbour_debug processes that might be hanging
            if (osName.contains("windows")) {
                pb = new ProcessBuilder("cmd", "/c", "taskkill /f /im harbour_debug.exe 2>nul");
                executeKillCommand(pb, "harbour_debug cleanup");
            } else {
                pb = new ProcessBuilder("bash", "-c", "pkill -f harbour_debug 2>/dev/null || true");
                executeKillCommand(pb, "harbour_debug cleanup");
            }
            
            // Give processes time to terminate
            Thread.sleep(500);
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Error in terminateRunningProcesses: " + e.getMessage());
        }
    }
    
    /**
     * Execute a kill command and log the result
     */
    private void executeKillCommand(ProcessBuilder pb, String description) {
        try {
            Process process = pb.start();
            boolean finished = process.waitFor(3, java.util.concurrent.TimeUnit.SECONDS);
            
            if (finished) {
                int exitCode = process.exitValue();
                if (exitCode == 0) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        description + " succeeded");
                } else {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        description + " completed with exit code: " + exitCode);
                }
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    description + " timed out");
            }
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                description + " error: " + e.getMessage());
        }
    }

    /**
     * Extract compiler parameters from .hbp file
     */
    private String extractHbpParameters(String hbpFilePath) {
        try {
            File hbpFile = new File(hbpFilePath);
            List<String> lines = Files.readAllLines(hbpFile.toPath());
            
            List<String> parameters = new ArrayList<>();
            
            for (String line : lines) {
                line = line.trim();
                
                // Skip comments, empty lines, and source files
                if (line.isEmpty() || line.startsWith("#") || line.endsWith(".prg") || line.endsWith(".hbc")) {
                    continue;
                }
                
                // Include hbmk2 parameters (lines starting with -)
                if (line.startsWith("-")) {
                    parameters.add(line);
                }
            }
            
            return String.join(" ", parameters);
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error extracting .hbp parameters: " + e.getMessage());
            return "";
        }
    }

    /**
     * CRITICAL FIX v1.0.343: Convert .hbp file to command line parameters
     * This treats .hbp files like expanded .prg files for unified debugging approach
     */
    private String expandHbpToCommandLine(String hbpFilePath, File workingDir) {
        try {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "CRITICAL FIX v1.0.343: Expanding .hbp to command line: " + hbpFilePath);
            
            File hbpFile = new File(hbpFilePath);
            List<String> lines = Files.readAllLines(hbpFile.toPath());
            
            String mainPrgFile = null;
            List<String> hbpParameters = new ArrayList<>();
            
            for (String line : lines) {
                line = line.trim();
                
                // Skip comments and empty lines
                if (line.isEmpty() || line.startsWith("#")) {
                    continue;
                }
                
                // Find the main .prg file (first .prg file found)
                if (line.endsWith(".prg") && !line.contains("harbour_debug")) {
                    if (mainPrgFile == null) {
                        mainPrgFile = line;
                        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                                "Found main PRG file: " + mainPrgFile);
                    }
                } else if (line.startsWith("-")) {
                    // Add hbmk2 parameters from .hbp file to runConfig compiler options
                    hbpParameters.add(line);
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                            "Found hbmk2 parameter: " + line);
                }
            }
            
            // Combine existing compiler options with .hbp parameters
            String existingOptions = runConfig.getCompilerOptions();
            String combinedOptions = String.join(" ", hbpParameters);
            if (!StringUtil.isEmpty(existingOptions)) {
                combinedOptions = existingOptions + " " + combinedOptions;
            }
            
            // Update the runConfig with combined compiler options
            // Note: We need to find a way to pass these parameters to the compilation
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Combined compiler options from .hbp: " + combinedOptions);
            
            if (mainPrgFile != null) {
                // Return the main .prg file path (relative to working directory)
                File mainPrg = new File(workingDir, mainPrgFile);
                String result = mainPrg.getAbsolutePath();
                
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "CRITICAL FIX v1.0.343: Converted .hbp to main PRG: " + result);
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Will add .hbp parameters to compiler options: " + combinedOptions);
                
                return result;
            } else {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "ERROR: No main .prg file found in .hbp file");
                return hbpFilePath; // Fallback to original
            }
            
        } catch (Exception e) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Error expanding .hbp file: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebugger", e);
            return hbpFilePath; // Fallback to original
        }
    }

    /**
     * Start error file monitor for Harbour runtime errors
     */
    private void startHarbourErrorFileMonitor(ConsoleView console, Project project) {
        String workingDir = runConfig.getWorkingDirectory();
        if (workingDir == null || workingDir.isEmpty()) {
            File sourceFile = new File(runConfig.getSourceFile());
            workingDir = sourceFile.getParent();
        }
        
        // Create .hbmk directory if needed
        File hbmkDir = new File(workingDir, ".hbmk");
        if (!hbmkDir.exists()) {
            hbmkDir.mkdirs();
        }
        
        // Clean old error logs on startup
        File oldHbmkErrorFile = new File(hbmkDir, "pycharm_errors.log");
        if (oldHbmkErrorFile.exists()) {
            oldHbmkErrorFile.delete();
            HarbourLogger.log(project, "HarbourDebugger", "Deleted old .hbmk/pycharm_errors.log");
        }
        
        // Monitor universal error log: .hbmk/pycharm_errors.log (works for ALL Harbour projects)
        final String hbmkErrorPath = workingDir + File.separator + ".hbmk" + File.separator + "pycharm_errors.log";
        final File hbmkErrorFile = new File(hbmkErrorPath);
        
        HarbourLogger.log(project, "HarbourDebugger", "Starting universal error monitor for: " + hbmkErrorPath);
        HarbourLogger.log(project, "HarbourDebugger", "Error file monitor working directory: " + workingDir);
        
        // Start a background thread to monitor the error file
        Thread errorMonitor = new Thread(() -> {
            long hbmkLastModified = 0;
            long hbmkLastSize = 0;
            int checkCount = 0;
            
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    checkCount++;
                    if (checkCount % 50 == 0) { // Log every 5 seconds (50 * 100ms)
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "Error monitor check #" + checkCount + 
                            ", .hbmk/pycharm_errors.log exists: " + hbmkErrorFile.exists() + 
                            ", size: " + (hbmkErrorFile.exists() ? hbmkErrorFile.length() : 0));
                    }
                    
                    // Check .hbmk/pycharm_errors.log (PRIMARY)
                    if (hbmkErrorFile.exists()) {
                        long currentModified = hbmkErrorFile.lastModified();
                        long currentSize = hbmkErrorFile.length();
                        
                        // Only read if file was modified and has new content
                        if (currentModified > hbmkLastModified || currentSize > hbmkLastSize) {
                            HarbourLogger.log(project, "HarbourDebugger", 
                                ".hbmk/pycharm_errors.log changed! Modified: " + currentModified + " > " + hbmkLastModified + 
                                ", Size: " + currentSize + " > " + hbmkLastSize);
                            try {
                                String content = new String(java.nio.file.Files.readAllBytes(hbmkErrorFile.toPath()));
                                if (!content.trim().isEmpty()) {
                                    // Send error to console
                                    console.print("\n[Harbour Runtime Error from .hbmk/pycharm_errors.log]\n\n" + content.trim() + "\n", 
                                        com.intellij.execution.ui.ConsoleViewContentType.ERROR_OUTPUT);
                                    
                                    HarbourLogger.log(project, "HarbourDebugger", 
                                        "Runtime error captured from .hbmk/pycharm_errors.log");
                                }
                            } catch (Exception e) {
                                HarbourLogger.log(project, "HarbourDebugger", 
                                    "Error reading .hbmk/pycharm_errors.log: " + e.getMessage());
                            }
                            
                            hbmkLastModified = currentModified;
                            hbmkLastSize = currentSize;
                        }
                    }
                    
                    // UNIVERSAL MONITORING: Only .hbmk/pycharm_errors.log 
                    // This works for ALL Harbour projects through our harbour_error_monitor.prg
                    
                    // Check every 100ms (much less frequent than before)
                    Thread.sleep(100);
                    
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "Error in error file monitor: " + e.getMessage());
                    break;
                }
            }
            
            HarbourLogger.log(project, "HarbourDebugger", "Error file monitor stopped");
        });
        
        errorMonitor.setDaemon(true);
        errorMonitor.setName("Harbour-Error-Monitor");
        errorMonitor.start();
        
        HarbourLogger.log(project, "HarbourDebugger", "Error file monitor started successfully");
    }

}
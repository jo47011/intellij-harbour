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

    public HarbourDebuggerRunProfileState(ExecutionEnvironment env,
                                          HarbourDebuggerRunConfig runConfig) {
        super(env);
        this.env = env;
        this.runConfig = runConfig;
    }

    @NotNull
    @Override
    protected ProcessHandler startProcess() throws ExecutionException {
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
            
            // For remote debugging, don't auto-terminate the debug session when process ends
            // The debug connection can outlive the process, especially on Windows
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Skipping ProcessTerminatedListener to allow debug connection to outlive process");
            // ProcessTerminatedListener.attach(handler); // DISABLED for remote debugging
            
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
        
        // Copy debug library from plugin resources to working directory
        copyDebugLibrary(workingDir);
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Copied debug library from plugin resources to working directory");
        
        // Instrument source file if needed
        String buildTarget = runConfig.getSourceFile();
        
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
        
        boolean shouldInstrument = shouldInstrumentSource();
        File instrumentedFile = null;
        
        if (shouldInstrument) {
            try {
                // Ensure we have an absolute path for the source file
                File sourceFile = new File(buildTarget);
                if (!sourceFile.isAbsolute()) {
                    sourceFile = new File(workingDir, buildTarget);
                }
                
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Attempting to instrument source file: " + sourceFile.getAbsolutePath());
                
                HarbourSourceInstrumenter instrumenter = new HarbourSourceInstrumenter(sourceFile);
                instrumentedFile = instrumenter.instrument();
                buildTarget = instrumentedFile.getAbsolutePath();
                
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Instrumented source file: " + buildTarget);
            } catch (IOException e) {
                HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                        "Failed to instrument source file: " + e.getMessage());
                HarbourLogger.logStackTrace("HarbourDebugger", new Exception("Instrumentation failed", e));
                // Continue with original file
            }
        }

        // Get build directory setting
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
        parameters.add(finalBuildTarget);
        
        // Add COMPLETE debug source for IntelliJ debugging (Variable names + breakpoint support)
        if (!finalBuildTarget.endsWith("harbour_debug.prg")) {
            // Use debug source copied to working directory
            String debugSourcePath = "harbour_debug_complete.prg";
            parameters.add(debugSourcePath);
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added COMPLETE debug source with variable names AND breakpoint support: " + debugSourcePath);
        }
        
        parameters.add("-b");
        parameters.add("-run");

        // Use only -workdir like earlier working versions
        parameters.add("-workdir=" + buildDir);
        parameters.add("-D__HARBOUR_DEBUG__");
        parameters.add("-DDBG_PORT=" + runConfig.getDebugPort());
        
        // Add GUI support for programs that need it (when not using .hbp files)
        // For standalone .prg files, add -gui flag to enable GUI functionality
        if (!finalBuildTarget.endsWith(".hbp")) {
            parameters.add("-gui");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added -gui flag for standalone .prg file: " + finalBuildTarget);
        }
        // Don't force GT driver - let .hbp file specify correct GT driver (-gui, -gtwvt, etc.)
        // parameters.add("-gtSTD");  // Commented out to allow GUI programs to work
        
        // Additional Windows-specific console redirection
        if (System.getProperty("os.name").toLowerCase().contains("windows")) {
            // Prevent new console window creation on Windows
            parameters.add("-D__INTELLIJ_DEBUG__");
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Added Windows-specific console redirection flags");
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
        System.out.println("=== HBMK2 COMMAND ===");
        System.out.println(fullCommand);
        System.out.println("Working Directory: " + workingDir);
        System.out.println("Build Target: " + finalBuildTarget);
        System.out.println("Instrumented: " + shouldInstrument);
        System.out.println("=====================");

        commandLine.addParameters(parameters);
        commandLine.setWorkDirectory(workingDir);
        commandLine.withEnvironment("HB_DBG_PATH", ".");
        commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
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

        // Don't set ALTD environment variable for remote debugging
        // commandLine.withEnvironment("ALTD", "BREAK");

        if (!StringUtil.isEmpty(runConfig.getProgramArguments())) {
            parameters.addAll(StringUtil.split(runConfig.getProgramArguments(), " "));
        }

        commandLine.addParameters(parameters);
        commandLine.setWorkDirectory(workingDir);
        commandLine.withEnvironment("HB_DBG_PATH", ".");
        commandLine.withEnvironment("HB_REMOTE_DEBUG", "1");
    }

    private void exportBreakpointsToFile() {
        try {
            Project project = env.getProject();
            XBreakpointManager breakpointManager = XDebuggerManager.getInstance(project).getBreakpointManager();

            String breakpointFileName = StringUtil.isEmpty(runConfig.getBreakpointFile())
                    ? "init.cld" : runConfig.getBreakpointFile();

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

            if (!breakpointFile.getParentFile().exists()) {
                if (!breakpointFile.getParentFile().mkdirs()) {
                    HarbourLogger.log(env.getProject(), "HarbourDebugger", "Failed to create breakpoint directory");
                }
            }

            int totalBreakpoints = 0;
            Set<String> breakpointFiles = new HashSet<>();
            String sourceFileName = new File(runConfig.getSourceFile()).getName();

            // Check if we're debugging an instrumented file
            boolean isInstrumented = sourceFileName.endsWith("_instrumented.prg");
            String originalFileName = isInstrumented ? 
                sourceFileName.replace("_instrumented.prg", ".prg") : sourceFileName;
            
            try (FileWriter writer = new FileWriter(breakpointFile)) {
                for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
                    if (bp instanceof XLineBreakpoint &&
                            bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                            bp.getSourcePosition() != null) {

                        VirtualFile file = bp.getSourcePosition().getFile();
                        String fileName = file.getName();
                        int line = bp.getSourcePosition().getLine() + 1;

                        // Only export breakpoints for the file we're actually debugging
                        if (fileName.equals(originalFileName) || 
                            (isInstrumented && fileName.equals(sourceFileName))) {
                            // Always use the original filename in the breakpoint file
                            writer.write("BP " + line + " " + originalFileName + "\n");
                            totalBreakpoints++;
                            breakpointFiles.add(fileName);
                        }
                    }
                }
            }
            
            // Check for breakpoint file mismatch
            if (totalBreakpoints > 0 && !breakpointFiles.isEmpty()) {
                boolean hasMatchingBreakpoint = false;
                for (String bpFile : breakpointFiles) {
                    if (bpFile.equals(sourceFileName) || 
                        bpFile.equals(sourceFileName.replace(".prg", "_instrumented.prg")) ||
                        sourceFileName.equals(bpFile.replace("_instrumented.prg", ".prg"))) {
                        hasMatchingBreakpoint = true;
                        break;
                    }
                }
                
                if (!hasMatchingBreakpoint) {
                    String message = String.format(
                        "Warning: Breakpoints are set in %s but debugging %s. " +
                        "The debugger will not stop at these breakpoints.",
                        breakpointFiles, sourceFileName
                    );
                    HarbourLogger.log(project, "HarbourDebugger", message);
                    HarbourDebuggerNotification.notifyEvent(project, "Breakpoint File Mismatch", message);
                }
            }

            HarbourLogger.log(project, "HarbourDebugger", "Exported " + totalBreakpoints +
                    " breakpoints to " + breakpointFile.getPath());

        } catch (IOException e) {
            HarbourLogger.logStackTrace("HarbourDebugger", e);
        }
    }

    @NotNull
    @Override
    public ExecutionResult execute(@NotNull Executor executor, @NotNull com.intellij.execution.runners.ProgramRunner<?> runner)
            throws ExecutionException {
        ProcessHandler processHandler = startProcess();

        TextConsoleBuilder consoleBuilder = TextConsoleBuilderFactory.getInstance()
                .createBuilder(env.getProject());
        consoleBuilder.filters(new HarbourCompilerOutputFilter(env.getProject()));
        ConsoleView console = consoleBuilder.getConsole();
        console.attachToProcess(processHandler);

        return new DefaultExecutionResult(console, processHandler);
    }
    
    /**
     * Copy the remote debug library from resources to working directory
     */
    private void copyDebugLibrary(String workingDir) throws ExecutionException {
        // Copy the debug library to enable debugging
        HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                "Copying IntelliJ debug library to working directory");
        
        // Ensure working directory exists
        File workingDirFile = new File(workingDir);
        if (!workingDirFile.exists()) {
            HarbourLogger.log(env.getProject(), "HarbourDebugger", 
                    "Working directory does not exist, creating: " + workingDir);
            if (!workingDirFile.mkdirs()) {
                throw new ExecutionException("Failed to create working directory: " + workingDir);
            }
        }
        
        // Copy harbour_debug_complete.prg
        File debugLibFile = new File(workingDir, "harbour_debug_complete.prg");
        try {
            copyResourceFile(debugLibFile);
        } catch (IOException e) {
            throw new ExecutionException("Failed to copy debug library: " + e.getMessage(), e);
        }
    }
    
    private void copyResourceFile(File targetFile) throws IOException, ExecutionException {
        String resourcePath = "/debug/harbour_debug_complete.prg";
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
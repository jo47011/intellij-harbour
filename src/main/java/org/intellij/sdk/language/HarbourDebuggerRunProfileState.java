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
import com.intellij.xdebugger.breakpoints.XBreakpointManager;
import com.intellij.xdebugger.breakpoints.XLineBreakpoint;
import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * RunProfileState that compiles and runs a Harbour program with debugging enabled.
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

        OSProcessHandler handler = new OSProcessHandler(commandLine);
        ProcessTerminatedListener.attach(handler);
        handler.startNotify();
        return handler;
    }

    private void compileAndRunHarbourProgram(GeneralCommandLine commandLine) throws ExecutionException {
        String hbmk2Path = runConfig.getHbmk2Path();
        if (StringUtil.isEmpty(hbmk2Path)) {
            throw new ExecutionException("hbmk2 compiler path is not specified");
        }

        commandLine.setExePath(hbmk2Path);

        String workingDir = runConfig.getWorkingDirectory();
        if (StringUtil.isEmpty(workingDir)) {
            File sourceFile = new File(runConfig.getSourceFile());
            workingDir = sourceFile.getParent();
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

        List<String> parameters = new ArrayList<>();

        // Look for .hbp file in working directory
        String sourceFile = runConfig.getSourceFile();
        File workingDirFile = new File(workingDir);
        String buildTarget = findHbpFileOrUseSource(workingDirFile, sourceFile);
        parameters.add(buildTarget);

        parameters.add("-b");
        parameters.add("-run");

        // Use only -workdir like earlier working versions
        parameters.add("-workdir=" + buildDir);
        parameters.add("-D__HARBOUR_DEBUG__");

        commandLine.withEnvironment("ALTD", "BREAK");

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
        System.out.println("Build Target: " + buildTarget);
        System.out.println("=====================");

        commandLine.addParameters(parameters);
        commandLine.setWorkDirectory(workingDir);
        commandLine.withEnvironment("HB_DBG_PATH", ".");
    }

    /**
     * Finds the first .hbp file in the working directory or returns the source file path
     */
    private String findHbpFileOrUseSource(File workingDir, String sourceFile) {
        // Look for any .hbp file in the working directory
        File[] hbpFiles = workingDir.listFiles((dir, name) ->
                name.toLowerCase().endsWith(".hbp"));

        if (hbpFiles != null && hbpFiles.length > 0) {
            // Use the first .hbp file found
            String hbpFileName = hbpFiles[0].getName();
            HarbourLogger.log(env.getProject(), "HarbourDebugger",
                    "Found .hbp file: " + hbpFileName + " in " + workingDir.getPath());
            return hbpFileName;
        }

        // No .hbp file found, use source file
        HarbourLogger.log(env.getProject(), "HarbourDebugger",
                "No .hbp file found, using source file: " + sourceFile);
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

        commandLine.withEnvironment("ALTD", "BREAK");

        if (!StringUtil.isEmpty(runConfig.getProgramArguments())) {
            parameters.addAll(StringUtil.split(runConfig.getProgramArguments(), " "));
        }

        commandLine.addParameters(parameters);
        commandLine.setWorkDirectory(workingDir);
        commandLine.withEnvironment("HB_DBG_PATH", ".");
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
                breakpointFile.getParentFile().mkdirs();
            }

            int totalBreakpoints = 0;

            try (FileWriter writer = new FileWriter(breakpointFile)) {
                for (XBreakpoint<?> bp : breakpointManager.getAllBreakpoints()) {
                    if (bp instanceof XLineBreakpoint &&
                            bp.getType() instanceof HarbourDebuggerLineBreakpointType &&
                            bp.getSourcePosition() != null) {

                        VirtualFile file = bp.getSourcePosition().getFile();
                        String fileName = file.getName();
                        int line = bp.getSourcePosition().getLine() + 1;

                        writer.write("BP " + line + " " + fileName + "\n");
                        totalBreakpoints++;
                    }
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
}
package org.intellij.sdk.language;

import com.intellij.execution.ExecutionResult;
import com.intellij.execution.process.ProcessHandler;
import com.intellij.execution.process.ProcessListener;
import com.intellij.execution.process.ProcessEvent;
import com.intellij.execution.process.ProcessOutputTypes;
import com.intellij.execution.ui.ExecutionConsole;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.Key;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerUtil;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.breakpoints.XBreakpointHandler;
import com.intellij.xdebugger.evaluation.XDebuggerEditorsProvider;
import com.intellij.xdebugger.frame.XSuspendContext;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

/**
 * Main debug process handler for Harbour applications with source file discovery.
 */
public class HarbourDebuggerProcess extends XDebugProcess {
    private final ExecutionResult executionResult;
    private final ProcessHandler processHandler;
    private final Map<String, HarbourDebuggerValue> variables = new ConcurrentHashMap<>();
    private HarbourDebuggerBreakpointHandler breakpointHandler;
    private final Project project;
    private XSourcePosition lastPosition;

    // Source file discovery
    private final List<VirtualFile> sourceFiles = new ArrayList<>();
    private String sourcePath;

    // Pattern to detect debug break points in output
    private static final Pattern DEBUG_BREAK_PATTERN =
            Pattern.compile("DEBUG: Break at ([^:]+):(\\d+)");
    private static final Pattern VARIABLE_PATTERN =
            Pattern.compile("([A-Za-z0-9_]+)\\s*=\\s*(.+)");

    public HarbourDebuggerProcess(@NotNull XDebugSession session,
                                  @NotNull ExecutionResult executionResult) {
        super(session);
        this.executionResult = executionResult;
        this.processHandler = executionResult.getProcessHandler();
        this.project = session.getProject();
        this.breakpointHandler = new HarbourDebuggerBreakpointHandler(this);

        // Discover source files from init.cld
        discoverSourceFiles();

        // Process output to detect breakpoints
        processHandler.addProcessListener(new ProcessListener() {
            @Override
            public void onTextAvailable(@NotNull ProcessEvent event, @NotNull Key outputType) {
                String text = event.getText();

                // Check for breakpoints and variables in regular output
                if (outputType == ProcessOutputTypes.STDOUT) {
                    checkForBreakpoint(text);
                    extractVariable(text);
                }
            }

            @Override
            public void startNotified(@NotNull ProcessEvent event) {
                HarbourLogger.log(project, "HarbourDebugger", "Process started with " +
                        sourceFiles.size() + " source files discovered");
            }

            @Override
            public void processTerminated(@NotNull ProcessEvent event) {
                HarbourLogger.log(project, "HarbourDebugger",
                        "Process terminated with exit code: " + event.getExitCode());
                stop();
            }

            @Override
            public void processWillTerminate(@NotNull ProcessEvent event, boolean willBeDestroyed) {
                HarbourLogger.log(project, "HarbourDebugger", "Process will terminate");
            }
        });
    }

    /**
     * Discover source files from working directory
     */
    private void discoverSourceFiles() {
        try {
            // Use working directory as source path
            String workingDir = System.getProperty("user.dir");

            // Try project base path if working dir doesn't have .prg files
            if (project.getBasePath() != null) {
                File projectDir = new File(project.getBasePath());
                if (projectDir.exists() && projectDir.isDirectory()) {
                    workingDir = project.getBasePath();
                }
            }

            this.sourcePath = workingDir;
            HarbourLogger.log(project, "HarbourDebugger", "Source path: " + sourcePath);

            // Scan for .prg files in working directory
            scanForSourceFiles(workingDir);

        } catch (Exception e) {
            HarbourLogger.logStackTrace("HarbourDebugger", e);
        }
    }

    /**
     * Scan directory for .prg source files
     */
    private void scanForSourceFiles(String pathStr) {
        try {
            Path sourcePath = Paths.get(pathStr);
            if (!Files.exists(sourcePath) || !Files.isDirectory(sourcePath)) {
                HarbourLogger.log(project, "HarbourDebugger", "Source path does not exist: " + pathStr);
                return;
            }

            // Scan for .prg files
            try (Stream<Path> files = Files.walk(sourcePath, 2)) { // Max depth 2 to avoid deep recursion
                files.filter(path -> path.toString().toLowerCase().endsWith(".prg"))
                        .forEach(path -> {
                            VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(path.toString());
                            if (vFile != null) {
                                sourceFiles.add(vFile);
                                HarbourLogger.log(project, "HarbourDebugger", "Found source file: " + vFile.getName());
                            }
                        });
            }

            HarbourLogger.log(project, "HarbourDebugger", "Discovered " + sourceFiles.size() + " source files");

        } catch (Exception e) {
            HarbourLogger.logStackTrace("HarbourDebugger", e);
        }
    }

    private void extractVariable(String text) {
        Matcher matcher = VARIABLE_PATTERN.matcher(text);
        if (matcher.find()) {
            String name = matcher.group(1);
            String value = matcher.group(2);

            // Simple type detection based on value format
            String type = "VAR";
            if (value.startsWith("\"") && value.endsWith("\"")) {
                type = "C";
            } else if (value.equals(".T.") || value.equals(".F.")) {
                type = "L";
            } else {
                try {
                    Double.parseDouble(value);
                    type = "N";
                } catch (NumberFormatException e) {
                    // Not a number
                }
            }

            variables.put(name, new HarbourDebuggerValue(name, type, value));
        }
    }

    private void checkForBreakpoint(String text) {
        Matcher matcher = DEBUG_BREAK_PATTERN.matcher(text);
        if (matcher.find()) {
            String fileName = matcher.group(1);
            int line = Integer.parseInt(matcher.group(2));

            HarbourLogger.log(project, "HarbourDebugger", "Detected breakpoint at " + fileName + ":" + line);

            // Try to find the file in our discovered source files first
            VirtualFile vFile = findSourceFile(fileName);

            // If not found, try absolute path
            if (vFile == null) {
                vFile = LocalFileSystem.getInstance().findFileByPath(fileName);
            }

            // If still not found, try relative to source path
            if (vFile == null && sourcePath != null) {
                String fullPath = Paths.get(sourcePath, fileName).toString();
                vFile = LocalFileSystem.getInstance().findFileByPath(fullPath);
            }

            if (vFile != null) {
                XSourcePosition position = XDebuggerUtil.getInstance()
                        .createPosition(vFile, line - 1); // Convert to 0-based

                lastPosition = position;

                ApplicationManager.getApplication().invokeLater(() -> {
                    HarbourDebuggerSuspendContext suspendContext =
                            new HarbourDebuggerSuspendContext(this, fileName, line);
                    getSession().positionReached(suspendContext);
                });
            } else {
                HarbourLogger.log(project, "HarbourDebugger", "Could not find source file: " + fileName);
            }
        }
    }

    /**
     * Find source file by name in discovered files
     */
    private VirtualFile findSourceFile(String fileName) {
        for (VirtualFile file : sourceFiles) {
            if (file.getName().equals(fileName)) {
                return file;
            }
        }
        return null;
    }

    /**
     * Get discovered source files for debugger UI
     */
    public List<VirtualFile> getSourceFiles() {
        return new ArrayList<>(sourceFiles);
    }

    /**
     * Get source path
     */
    public String getSourcePath() {
        return sourcePath;
    }

    @NotNull
    @Override
    public ExecutionConsole createConsole() {
        return executionResult.getExecutionConsole();
    }

    @NotNull
    @Override
    protected ProcessHandler doGetProcessHandler() {
        return processHandler;
    }

    @NotNull
    @Override
    public XDebuggerEditorsProvider getEditorsProvider() {
        return new HarbourDebuggerEditorsProvider();
    }

    @NotNull
    @Override
    public XBreakpointHandler<?>[] getBreakpointHandlers() {
        return new XBreakpointHandler[]{breakpointHandler};
    }

    @Override
    public void startStepOver(@Nullable XSuspendContext context) {
        resume(context); // Simple continue for now
    }

    @Override
    public void startStepInto(@Nullable XSuspendContext context) {
        resume(context); // Simple continue for now
    }

    @Override
    public void startStepOut(@Nullable XSuspendContext context) {
        resume(context); // Simple continue for now
    }

    @Override
    public void resume(@Nullable XSuspendContext context) {
        variables.clear();
        getSession().resume();
    }

    @Override
    public void stop() {
        if (processHandler != null && !processHandler.isProcessTerminated()) {
            processHandler.destroyProcess();
        }
        HarbourLogger.log("HarbourDebugger", "Debugger stopped");
    }

    @Override
    public void runToPosition(@NotNull XSourcePosition position, @Nullable XSuspendContext context) {
        resume(context); // Simple continue for now
    }

    public void sendCommand(String command, String... args) {
        // Send command via standard input to the process
        ProcessHandler handler = getProcessHandler();
        if (handler != null && handler.getProcessInput() != null) {
            try {
                StringBuilder commandStr = new StringBuilder(command);
                for (String arg : args) {
                    commandStr.append(" ").append(arg);
                }
                commandStr.append("\n");

                handler.getProcessInput().write(commandStr.toString().getBytes());
                handler.getProcessInput().flush();

                HarbourLogger.log("HarbourDebugger", "Sent command: " + commandStr);
            } catch (java.io.IOException e) {
                HarbourLogger.logStackTrace("HarbourDebugger", e);
            }
        }
    }

    public Map<String, HarbourDebuggerValue> getVariables() {
        return variables;
    }

    public XSourcePosition getLastPosition() {
        return lastPosition;
    }
}
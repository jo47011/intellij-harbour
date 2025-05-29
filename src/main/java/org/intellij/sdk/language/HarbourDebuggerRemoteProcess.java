package org.intellij.sdk.language;

import com.intellij.execution.ExecutionResult;
import com.intellij.execution.process.ProcessHandler;
import com.intellij.execution.ui.ExecutionConsole;
import com.intellij.execution.ui.ConsoleView;
import com.intellij.execution.ui.ConsoleViewContentType;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
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

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Stream;

/**
 * Remote debug process handler using TCP communication
 */
public class HarbourDebuggerRemoteProcess extends HarbourDebuggerBaseProcess {
    private final ExecutionResult executionResult;
    private final ProcessHandler processHandler;
    private final HarbourDebuggerConnection connection;
    private final Map<String, HarbourDebuggerValue> variables = new ConcurrentHashMap<>();
    private final HarbourDebuggerBreakpointHandler breakpointHandler;
    private final Project project;
    private final int debugPort;
    private XSourcePosition lastPosition;
    private final List<VirtualFile> sourceFiles = new ArrayList<>();
    private final Map<String, VirtualFile> fileCache = new HashMap<>();
    private String currentFile;
    private int currentLine;
    private boolean isConnected = false;
    private volatile boolean isLocked = false;
    
    // Simple state management
    private final Object stateLock = new Object();
    
    public HarbourDebuggerRemoteProcess(@NotNull XDebugSession session,
                                       @NotNull ExecutionResult executionResult,
                                       int debugPort) {
        super(session);
        this.executionResult = executionResult;
        this.processHandler = executionResult.getProcessHandler();
        this.project = session.getProject();
        this.debugPort = debugPort;
        this.breakpointHandler = new HarbourDebuggerBreakpointHandler(this);
        
        // Create debug connection
        this.connection = new HarbourDebuggerConnection(debugPort);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Created remote debugger on port " + debugPort);
        
        // Discover source files
        discoverSourceFiles();
        
        // Start debug server in background
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Starting debug server...");
                isConnected = connection.start(this::handleDebugMessage);
                
                if (isConnected) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug connection established");
                    
                    // Send initial breakpoints
                    sendInitialBreakpoints();
                } else {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to establish debug connection");
                }
            } catch (IOException e) {
                // Don't log socket exceptions as errors if they're due to normal session termination
                if (e.getMessage() != null && e.getMessage().contains("Socket closed")) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug connection closed - likely session was stopped");
                } else {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug connection error: " + e.getMessage());
                    HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
                }
            }
        });
    }
    
    /**
     * Handle incoming debug messages
     */
    private synchronized void handleDebugMessage(String message) {
        // Lock at the start - if already busy, return immediately
        if (isLocked) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Already processing message, dropping: " + message);
            return;
        }
        
        isLocked = true;
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Handling message (locked): " + message);
        
        try {
            String[] lines = message.split("\r\n");
            if (lines.length == 0) return;
        
        String command = lines[0];
        
        // Handle colon-separated commands like "STOP:file:line"
        if (command.contains(":")) {
            String[] parts = command.split(":");
            if (parts.length >= 1) {
                String cmd = parts[0];
                
                switch (cmd) {
                    case "STOP":
                        if (parts.length >= 4) {
                            // Format: STOP:reason:file:line
                            try {
                                handleStop(parts[2], Integer.parseInt(parts[3].trim()));
                            } catch (NumberFormatException e) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Invalid line number in STOP command: " + parts[3]);
                            }
                        } else if (parts.length >= 3) {
                            // Old format: STOP:file:line
                            try {
                                handleStop(parts[1], Integer.parseInt(parts[2].trim()));
                            } catch (NumberFormatException e) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Invalid line number in STOP command: " + parts[2]);
                            }
                        }
                        break;
                        
                    case "BREAK":
                        if (parts.length >= 3) {
                            // BREAK messages are just acknowledgments of breakpoint registration
                            // They should not trigger a stop
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Breakpoint acknowledged at " + parts[1] + ":" + parts[2]);
                        }
                        break;
                        
                    case "CONSOLE":
                        if (parts.length >= 2) {
                            // Reconstruct the console output (in case it contains colons)
                            String consoleOutput = command.substring(8); // Skip "CONSOLE:"
                            handleConsoleOutput(consoleOutput);
                        }
                        break;
                }
            }
            return;
        }
        
        // Handle multi-line commands (original format)
        switch (command) {
            case "STOP":
                if (lines.length >= 3) {
                    try {
                        handleStop(lines[1], Integer.parseInt(lines[2].trim()));
                    } catch (NumberFormatException e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Invalid line number in STOP command: " + lines[2]);
                    }
                }
                break;
                
            case "BREAK":
                if (lines.length >= 3) {
                    // BREAK messages are just acknowledgments of breakpoint registration
                    // They should not trigger a stop
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Breakpoint acknowledged at " + lines[1] + ":" + lines[2]);
                }
                break;
                
            case "STACK":
                handleStackTrace(Arrays.copyOfRange(lines, 1, lines.length));
                break;
                
            case "LOCALS":
            case "STATICS":
            case "PRIVATES":
            case "PUBLICS":
                handleVariables(command, Arrays.copyOfRange(lines, 1, lines.length));
                break;
                
            case "END":
                handleEnd();
                break;
                
            case "ERROR":
                handleError(lines.length > 1 ? lines[1] : "Unknown error");
                break;
                
            case "LOG":
                if (lines.length > 1) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug log: " + lines[1]);
                }
                break;
                
            case "CONSOLE":
                if (lines.length > 1) {
                    handleConsoleOutput(lines[1]);
                }
                break;
        }
        } finally {
            isLocked = false;
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Message processing complete (unlocked)");
        }
    }
    
    private void handleStop(String file, int line) {
        currentFile = file;
        currentLine = line;
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stopped at " + file + ":" + line);
        
        VirtualFile vFile = findSourceFile(file);
        if (vFile != null) {
            XSourcePosition position = XDebuggerUtil.getInstance()
                    .createPosition(vFile, line - 1); // Convert to 0-based
            
            lastPosition = position;
            
            ApplicationManager.getApplication().invokeLater(() -> {
                HarbourDebuggerSuspendContext suspendContext = 
                        new HarbourDebuggerSuspendContext(this, file, line, position);
                getSession().positionReached(suspendContext);
                
                // Notify user that debugger has stopped
                HarbourDebuggerNotification.notifyBreakpointHit(getSession().getProject(), file, line);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session suspended, waiting for user action");
            });
            
            // Request variable information
            requestVariables();
        } else {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Could not find source file: " + file);
        }
    }
    
    
    private void handleStackTrace(String[] stackLines) {
        // TODO: Parse and store stack trace
        for (String line : stackLines) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stack: " + line);
        }
    }
    
    private void handleVariables(String scope, String[] varLines) {
        boolean inVariableList = false;
        
        for (String line : varLines) {
            // Check for end markers
            if (line.equals("END_" + scope)) {
                break;
            }
            
            // Parse variable line
            String[] parts = line.split(":", 3);
            if (parts.length >= 3) {
                String name = parts[0];
                String type = parts[1];
                String value = parts[2];
                
                String key = scope + "." + name;
                variables.put(key, new HarbourDebuggerValue(name, type, value));
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Variable " + scope + ": " + name + " = " + value + " (" + type + ")");
            }
        }
    }
    
    private void handleEnd() {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session ended");
        stop();
    }
    
    private void handleError(String error) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug error: " + error);
        // TODO: Show error in UI
    }
    
    private void requestVariables() {
        connection.sendCommand("LOCALS", "0");
        connection.sendCommand("STATICS");
        connection.sendCommand("PRIVATES", "0");
        connection.sendCommand("PUBLICS");
    }
    
    private void sendInitialBreakpoints() {
        // Send all breakpoints registered with the handler
        breakpointHandler.sendAllBreakpoints();
        
        // Don't send GO automatically - wait for user to click Continue
        // The program will pause when it hits AltD() and send STOP
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Breakpoints sent, waiting for program to hit AltD()");
    }
    
    /**
     * Discover source files from working directory
     */
    private void discoverSourceFiles() {
        try {
            String workingDir = System.getProperty("user.dir");
            
            if (project.getBasePath() != null) {
                workingDir = project.getBasePath();
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Discovering source files in: " + workingDir);
            scanForSourceFiles(workingDir);
            
        } catch (Exception e) {
            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
        }
    }
    
    private void scanForSourceFiles(String pathStr) {
        try {
            Path sourcePath = Paths.get(pathStr);
            if (!Files.exists(sourcePath) || !Files.isDirectory(sourcePath)) {
                return;
            }
            
            try (Stream<Path> files = Files.walk(sourcePath, 3)) { // Max depth 3
                files.filter(path -> path.toString().toLowerCase().endsWith(".prg"))
                        .forEach(path -> {
                            VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(path.toString());
                            if (vFile != null) {
                                sourceFiles.add(vFile);
                                fileCache.put(vFile.getName(), vFile);
                                fileCache.put(path.toString(), vFile);
                                fileCache.put(path.getFileName().toString(), vFile);
                            }
                        });
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Discovered " + sourceFiles.size() + " source files");
            
        } catch (Exception e) {
            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
        }
    }
    
    private VirtualFile findSourceFile(String fileName) {
        // Check cache first
        VirtualFile cached = fileCache.get(fileName);
        if (cached != null) return cached;
        
        // Try exact path
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(fileName);
        if (vFile != null) {
            fileCache.put(fileName, vFile);
            return vFile;
        }
        
        // Try filename only
        for (VirtualFile file : sourceFiles) {
            if (file.getName().equals(fileName) || 
                file.getPath().endsWith(fileName) ||
                file.getPath().endsWith(fileName.replace("\\", "/"))) {
                fileCache.put(fileName, file);
                return file;
            }
        }
        
        // Try relative to project
        if (project.getBasePath() != null) {
            String fullPath = Paths.get(project.getBasePath(), fileName).toString();
            vFile = LocalFileSystem.getInstance().findFileByPath(fullPath);
            if (vFile != null) {
                fileCache.put(fileName, vFile);
                return vFile;
            }
        }
        
        return null;
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
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring NEXT command - not connected");
            return;
        }
        
        if (isLocked) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Dropping NEXT command - processing message");
            return;
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sending NEXT command");
        connection.sendCommand("NEXT");
    }
    
    @Override
    public void startStepInto(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring STEP command - not connected");
            return;
        }
        
        if (isLocked) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Dropping STEP command - processing message");
            return;
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sending STEP command");
        connection.sendCommand("STEP");
    }
    
    @Override
    public void startStepOut(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring OUT command - not connected");
            return;
        }
        
        if (isLocked) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Dropping OUT command - processing message");
            return;
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sending OUT command");
        connection.sendCommand("OUT");
    }
    
    @Override
    public void resume(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring GO command - not connected");
            return;
        }
        
        if (isLocked) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Dropping GO command - processing message");
            return;
        }
        
        variables.clear();
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sending GO command");
        connection.sendCommand("GO");
    }
    
    @Override
    public void stop() {
        // Log the stop call but don't prevent it
        
        // Don't stop if we're still waiting for the initial connection
        if (connection != null && connection.isWaitingForConnection()) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring stop() call - waiting for debug client connection");
            return;
        }
        
        // Log stack trace to see what's calling stop()
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "stop() called from:");
        StackTraceElement[] stack = Thread.currentThread().getStackTrace();
        for (int i = 0; i < Math.min(stack.length, 10); i++) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "  " + stack[i].toString());
        }
        
        if (isConnected) {
            connection.sendCommand("EXIT");
        }
        connection.close();
        
        if (processHandler != null && !processHandler.isProcessTerminated()) {
            processHandler.destroyProcess();
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debugger stopped");
    }
    
    @Override
    public void runToPosition(@NotNull XSourcePosition position, @Nullable XSuspendContext context) {
        // TODO: Implement run to cursor
        resume(context);
    }
    
    @Override
    public void sendCommand(String command, String... args) {
        if (isConnected) {
            connection.sendCommand(command, args);
        }
    }
    
    public HarbourDebuggerConnection getConnection() {
        return connection;
    }
    
    @Override
    public Map<String, HarbourDebuggerValue> getVariables() {
        return variables;
    }
    
    @Override
    public XSourcePosition getLastPosition() {
        return lastPosition;
    }
    
    public String getCurrentFile() {
        return currentFile;
    }
    
    public int getCurrentLine() {
        return currentLine;
    }
    
    /**
     * Handle console output from the debugged program
     */
    private void handleConsoleOutput(String output) {
        ApplicationManager.getApplication().invokeLater(() -> {
            ExecutionConsole console = getSession().getConsoleView();
            if (console instanceof ConsoleView) {
                ConsoleView consoleView = (ConsoleView) console;
                // Replace escaped characters
                String processedOutput = output
                        .replace("\\r", "\r")
                        .replace("\\n", "\n")
                        .replace("\\t", "\t");
                consoleView.print(processedOutput, ConsoleViewContentType.NORMAL_OUTPUT);
            }
        });
    }
}
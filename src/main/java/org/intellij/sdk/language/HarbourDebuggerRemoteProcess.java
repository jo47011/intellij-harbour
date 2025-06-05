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
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
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
    private volatile String lastCommand = "";
    private volatile long lastCommandTime = 0;
    
    // Enhanced command execution management
    private final Object commandLock = new Object();
    private final BlockingQueue<DebugCommand> commandQueue = new LinkedBlockingQueue<>();
    private final Thread commandExecutor;
    private volatile boolean shutdownRequested = false;
    
    // Command throttling settings - tuned for optimal stability
    private static final long MIN_COMMAND_INTERVAL = 200; // Minimum ms between commands
    private static final long NEXT_COMMAND_DELAY = 350;   // Extra delay for NEXT commands
    
    // Debugger state management - prevents rapid command execution
    public enum DebuggerState {
        DISCONNECTED,  // Not connected to debug target
        RUNNING,       // Program is running
        SUSPENDED,     // Stopped at breakpoint, ready for commands
        STEPPING       // Executing a step command, ignore new commands
    }
    
    private volatile DebuggerState debuggerState = DebuggerState.DISCONNECTED;
    private volatile boolean hasPendingStepCommand = false;
    
    // Variables for delayed position notification
    private volatile boolean waitingForVariables = false;
    private volatile int variablesExpected = 0;
    private volatile int variablesReceived = 0;
    private volatile String pendingStopFile = null;
    private volatile int pendingStopLine = -1;
    private volatile XSourcePosition pendingStopPosition = null;
    
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
        
        // Add shutdown hook to ensure cleanup even if normal shutdown fails
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "JVM shutdown hook - cleaning up debugger resources");
            cleanupResources();
        }, "Harbour-Debug-Cleanup"));
        
        // Discover source files
        discoverSourceFiles();
        
        // Start command executor thread
        commandExecutor = new Thread(this::processCommandQueue, "Harbour-Debug-Command-Executor");
        commandExecutor.setDaemon(true);
        commandExecutor.start();
        
        // Start debug server in background
        ApplicationManager.getApplication().executeOnPooledThread(() -> {
            try {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Starting debug server...");
                isConnected = connection.start(this::handleDebugMessage);
                
                if (isConnected) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug connection established");
                    updateDebuggerState(DebuggerState.RUNNING, false);  // Initially running
                    
                    // Send initial breakpoints
                    sendInitialBreakpoints();
                } else {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to establish debug connection");
                    updateDebuggerState(DebuggerState.DISCONNECTED, false);
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
    private void handleDebugMessage(String message) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Handling message: " + message);
        
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
                String[] varLines = Arrays.copyOfRange(lines, 1, lines.length);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "DEBUGGING: " + command + " with " + varLines.length + " variable lines");
                for (int i = 0; i < varLines.length; i++) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "DEBUGGING varLine[" + i + "]: " + varLines[i]);
                }
                handleVariables(command, varLines);
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
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Message processing complete");
        }
    }
    
    private void handleStop(String file, int line) {
        currentFile = file;
        currentLine = line;
        
        // Update debugger state to SUSPENDED when we stop and clear pending step flag
        updateDebuggerState(DebuggerState.SUSPENDED, false);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stopped at " + file + ":" + line + " (state: SUSPENDED, pendingStep=false)");
        
        VirtualFile vFile = findSourceFile(file);
        if (vFile != null) {
            XSourcePosition position = XDebuggerUtil.getInstance()
                    .createPosition(vFile, line - 1); // Convert to 0-based
            
            lastPosition = position;
            
            // Store the position information for later use
            pendingStopFile = file;
            pendingStopLine = line;
            pendingStopPosition = position;
            
            // Request variable information BEFORE notifying about position reached
            requestVariables();
            
            // Set a flag to indicate we're waiting for variables
            waitingForVariables = true;
            variablesExpected = 4; // LOCALS, STATICS, PRIVATES, PUBLICS
            variablesReceived = 0;
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Requesting variables before notifying position reached");
            
            // Set a timeout in case variables don't arrive
            ApplicationManager.getApplication().executeOnPooledThread(() -> {
                try {
                    Thread.sleep(1500); // Wait 1.5 seconds for variables (4 types * 200ms throttle + buffer)
                    if (waitingForVariables && pendingStopPosition != null) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Variable timeout - notifying position reached anyway");
                        waitingForVariables = false;
                        
                        // Capture values before clearing them
                        final String stopFile = pendingStopFile;
                        final int stopLine = pendingStopLine;
                        final XSourcePosition stopPosition = pendingStopPosition;
                        
                        // Clear pending info BEFORE invokeLater
                        pendingStopFile = null;
                        pendingStopLine = -1;
                        pendingStopPosition = null;
                        
                        ApplicationManager.getApplication().invokeLater(() -> {
                            if (getSession() == null) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Debug session is null in timeout handler!");
                                return;
                            }
                            
                            HarbourDebuggerSuspendContext suspendContext = 
                                    new HarbourDebuggerSuspendContext(this, 
                                        stopFile != null ? stopFile : "Unknown", 
                                        stopLine, 
                                        stopPosition);
                            
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Calling positionReached after timeout for " + (stopFile != null ? stopFile : "Unknown") + 
                                ":" + stopLine);
                            
                            getSession().positionReached(suspendContext);
                            
                            if (stopFile != null) {
                                HarbourDebuggerNotification.notifyBreakpointHit(getSession().getProject(), stopFile, stopLine);
                            }
                            
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session suspended after timeout");
                        });
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            });
        } else {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Could not find source file: " + file);
            
            // Even if we can't find the file, we should still notify that we're suspended
            // Create a suspend context without a valid position
            ApplicationManager.getApplication().invokeLater(() -> {
                if (getSession() == null) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Debug session is null (no source file)!");
                    return;
                }
                
                HarbourDebuggerSuspendContext suspendContext = 
                        new HarbourDebuggerSuspendContext(this, file, line, null);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Calling positionReached without source position for " + file + ":" + line);
                
                getSession().positionReached(suspendContext);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session suspended (no source file found)");
            });
        }
    }
    
    
    private void handleStackTrace(String[] stackLines) {
        // TODO: Parse and store stack trace
        for (String line : stackLines) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stack: " + line);
        }
    }
    
    private void handleVariables(String scope, String[] varLines) {
        // Clear only this scope's variables to prevent stale data
        variables.entrySet().removeIf(entry -> entry.getKey().startsWith(scope + "."));
        
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
        
        // If we're waiting for variables, check if we've received all expected scopes
        if (waitingForVariables) {
            variablesReceived++;
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Received " + scope + " variables (" + variablesReceived + "/" + variablesExpected + ")");
            
            if (variablesReceived >= variablesExpected) {
                // All variables received, now notify position reached
                waitingForVariables = false;
                variablesReceived = 0;
                
                if (pendingStopPosition != null) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "All variables received, notifying position reached");
                    
                    // Capture values before clearing them
                    final String stopFile = pendingStopFile;
                    final int stopLine = pendingStopLine;
                    final XSourcePosition stopPosition = pendingStopPosition;
                    
                    // Clear pending info BEFORE invokeLater to prevent race conditions
                    pendingStopFile = null;
                    pendingStopLine = -1;
                    pendingStopPosition = null;
                    
                    ApplicationManager.getApplication().invokeLater(() -> {
                        if (getSession() == null) {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Debug session is null!");
                            return;
                        }
                        
                        HarbourDebuggerSuspendContext suspendContext = 
                                new HarbourDebuggerSuspendContext(this, 
                                    stopFile != null ? stopFile : "Unknown", 
                                    stopLine, 
                                    stopPosition);
                        
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Calling positionReached for " + (stopFile != null ? stopFile : "Unknown") + 
                            ":" + stopLine);
                        
                        getSession().positionReached(suspendContext);
                        
                        // Notify user that debugger has stopped
                        if (stopFile != null) {
                            HarbourDebuggerNotification.notifyBreakpointHit(getSession().getProject(), stopFile, stopLine);
                        }
                        
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session suspended, waiting for user action");
                    });
                }
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
        sendCommand("LOCALS", "0");
        sendCommand("STATICS");
        sendCommand("PRIVATES", "0");
        sendCommand("PUBLICS");
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
        
        // State machine: only allow commands when SUSPENDED and no pending step command
        if (debuggerState != DebuggerState.SUSPENDED || hasPendingStepCommand) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring NEXT command - debugger state is " + debuggerState + ", hasPendingStepCommand=" + hasPendingStepCommand);
            return;
        }
        
        // Clear any pending NEXT/STEP/OUT commands from the queue to prevent accumulation
        clearStepCommandsFromQueue();
        
        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing NEXT command (state: STEPPING, pendingStep=true)");
        try {
            commandQueue.offer(new DebugCommand("NEXT"), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            updateDebuggerState(DebuggerState.SUSPENDED, false); // Reset flags on error
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue NEXT command");
        }
    }
    
    @Override
    public void startStepInto(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring STEP command - not connected");
            return;
        }
        
        // State machine: only allow commands when SUSPENDED and no pending step command
        if (debuggerState != DebuggerState.SUSPENDED || hasPendingStepCommand) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring STEP command - debugger state is " + debuggerState + ", hasPendingStepCommand=" + hasPendingStepCommand);
            return;
        }
        
        // Clear any pending NEXT/STEP/OUT commands from the queue to prevent accumulation
        clearStepCommandsFromQueue();
        
        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing STEP command (state: STEPPING, pendingStep=true)");
        try {
            commandQueue.offer(new DebugCommand("STEP"), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            updateDebuggerState(DebuggerState.SUSPENDED, false); // Reset flags on error
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue STEP command");
        }
    }
    
    @Override
    public void startStepOut(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring OUT command - not connected");
            return;
        }
        
        // State machine: only allow commands when SUSPENDED and no pending step command
        if (debuggerState != DebuggerState.SUSPENDED || hasPendingStepCommand) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring OUT command - debugger state is " + debuggerState + ", hasPendingStepCommand=" + hasPendingStepCommand);
            return;
        }
        
        // Clear any pending NEXT/STEP/OUT commands from the queue to prevent accumulation
        clearStepCommandsFromQueue();
        
        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing OUT command (state: STEPPING, pendingStep=true)");
        try {
            commandQueue.offer(new DebugCommand("OUT"), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            updateDebuggerState(DebuggerState.SUSPENDED, false); // Reset flags on error
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue OUT command");
        }
    }
    
    @Override
    public void resume(@Nullable XSuspendContext context) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring GO command - not connected");
            return;
        }
        
        // State machine: only allow resume when SUSPENDED
        if (debuggerState != DebuggerState.SUSPENDED) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring GO command - debugger state is " + debuggerState);
            return;
        }
        
        // Change state to RUNNING to prevent additional commands
        updateDebuggerState(DebuggerState.RUNNING, false);
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing GO command (state: RUNNING)");
        try {
            commandQueue.offer(new DebugCommand("GO"), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            updateDebuggerState(DebuggerState.SUSPENDED, false); // Reset state on error
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue GO command");
        }
    }
    
    @Override
    public void stop() {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "stop() called - beginning shutdown sequence");
        
        // Update state to DISCONNECTED and clear pending flags
        updateDebuggerState(DebuggerState.DISCONNECTED, false);
        
        // Log stack trace to see what's calling stop()
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "stop() called from:");
        StackTraceElement[] stack = Thread.currentThread().getStackTrace();
        for (int i = 0; i < Math.min(stack.length, 5); i++) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "  " + stack[i].toString());
        }
        
        // Signal shutdown to command executor immediately
        shutdownRequested = true;
        
        // 1. Send EXIT command if connected
        if (isConnected && connection != null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sending EXIT command to debugger");
            try {
                connection.sendCommand("EXIT");
                // Give a brief moment for the command to be sent
                Thread.sleep(100);
            } catch (Exception e) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Error sending EXIT command: " + e.getMessage());
            }
        }
        
        // 2. Shutdown command executor thread first
        if (commandExecutor != null && commandExecutor.isAlive()) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Shutting down command executor thread");
            commandExecutor.interrupt();
            try {
                commandExecutor.join(2000); // Wait up to 2 seconds
                if (commandExecutor.isAlive()) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Command executor thread did not terminate gracefully");
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Interrupted while waiting for command executor shutdown");
            }
        }
        
        // 3. Close connection (this handles socket cleanup)
        if (connection != null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Closing debugger connection");
            try {
                connection.close();
            } catch (Exception e) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Error closing connection: " + e.getMessage());
                HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
            }
        }
        
        // 4. Terminate process if still running
        if (processHandler != null && !processHandler.isProcessTerminated()) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Destroying process");
            try {
                processHandler.destroyProcess();
            } catch (Exception e) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Error destroying process: " + e.getMessage());
            }
        }
        
        // 5. Clear state
        isConnected = false;
        variables.clear();
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debugger stop sequence completed");
    }
    
    @Override
    public void runToPosition(@NotNull XSourcePosition position, @Nullable XSuspendContext context) {
        // TODO: Implement run to cursor
        resume(context);
    }
    
    /**
     * Check if it is possible to perform debugging commands (step, resume, etc.)
     * This method controls the enabled/disabled state of debug action buttons.
     * 
     * @return true if commands can be executed, false to disable debug buttons
     */
    @Override
    public boolean checkCanPerformCommands() {
        // Disable buttons when not connected
        if (!isConnected) {
            return false;
        }
        
        // Disable buttons when disconnected or running (not suspended)
        if (debuggerState == DebuggerState.DISCONNECTED || 
            debuggerState == DebuggerState.RUNNING) {
            return false;
        }
        
        // Disable buttons during stepping operations to prevent rapid clicking
        if (debuggerState == DebuggerState.STEPPING || hasPendingStepCommand) {
            return false;
        }
        
        // Enable buttons only when suspended and ready for commands
        return debuggerState == DebuggerState.SUSPENDED && !hasPendingStepCommand;
    }
    
    /**
     * Update the debugger state and notify the session to refresh button states
     */
    private void updateDebuggerState(DebuggerState newState, boolean pendingStep) {
        DebuggerState oldState = debuggerState;
        boolean oldPendingStep = hasPendingStepCommand;
        
        debuggerState = newState;
        hasPendingStepCommand = pendingStep;
        
        // Log state changes for debugging
        if (oldState != newState || oldPendingStep != pendingStep) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                String.format("State change: %s->%s, pendingStep: %s->%s", 
                    oldState, newState, oldPendingStep, pendingStep));
        }
    }
    
    @Override
    public void sendCommand(String command, String... args) {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring " + command + " command - not connected");
            return;
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Queuing " + command + " command");
        try {
            commandQueue.offer(new DebugCommand(command, args), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue " + command + " command");
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
    
    /**
     * Clear pending step commands (NEXT, STEP, OUT) from the queue to prevent accumulation
     */
    private void clearStepCommandsFromQueue() {
        // Create a new list to hold non-step commands
        List<DebugCommand> nonStepCommands = new ArrayList<>();
        
        // Drain the queue and filter out step commands
        DebugCommand cmd;
        while ((cmd = commandQueue.poll()) != null) {
            if (!"NEXT".equals(cmd.command) && !"STEP".equals(cmd.command) && !"OUT".equals(cmd.command)) {
                nonStepCommands.add(cmd);
            } else {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Clearing pending step command: " + cmd.command);
            }
        }
        
        // Put back the non-step commands
        for (DebugCommand nonStepCmd : nonStepCommands) {
            commandQueue.offer(nonStepCmd);
        }
    }
    
    /**
     * Internal class representing a debug command
     */
    private static class DebugCommand {
        final String command;
        final String[] args;
        final long timestamp;
        
        DebugCommand(String command, String... args) {
            this.command = command;
            this.args = args;
            this.timestamp = System.currentTimeMillis();
        }
    }
    
    /**
     * Process commands from the queue with proper throttling
     */
    private void processCommandQueue() {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Command executor thread started");
        long lastExecutionTime = 0;
        
        while (!shutdownRequested) {
            try {
                // Wait for a command with timeout
                DebugCommand cmd = commandQueue.poll(200, TimeUnit.MILLISECONDS);
                
                if (cmd == null) {
                    continue;
                }
                
                // Check if we're connected
                if (!isConnected || connection == null) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Dropping command " + cmd.command + " - not connected");
                    updateDebuggerState(DebuggerState.DISCONNECTED, false);
                    continue;
                }
                
                // Calculate required delay
                long now = System.currentTimeMillis();
                long timeSinceLastCommand = now - lastExecutionTime;
                long requiredDelay = MIN_COMMAND_INTERVAL;
                
                // Extra delay for consecutive NEXT commands
                if ("NEXT".equals(cmd.command) && "NEXT".equals(lastCommand)) {
                    requiredDelay = NEXT_COMMAND_DELAY;
                }
                
                // Apply throttling if needed
                if (timeSinceLastCommand < requiredDelay) {
                    long sleepTime = requiredDelay - timeSinceLastCommand;
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Throttling " + cmd.command + " command by " + sleepTime + "ms");
                    Thread.sleep(sleepTime);
                }
                
                // Execute the command
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Executing command: " + cmd.command);
                
                if (cmd.args.length > 0) {
                    connection.sendCommand(cmd.command, cmd.args);
                } else {
                    connection.sendCommand(cmd.command);
                }
                
                // Update state
                lastCommand = cmd.command;
                lastExecutionTime = System.currentTimeMillis();
                
                // Don't clear variables on GO - let them persist until new ones are received
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Error processing command: " + e.getMessage());
                HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
            }
        }
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Command executor thread stopped");
    }
    
    /**
     * Helper method to clean up all resources - can be called from shutdown hook
     */
    private void cleanupResources() {
        try {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Performing resource cleanup");
            
            // Signal shutdown
            shutdownRequested = true;
            isConnected = false;
            
            // Interrupt and cleanup command executor
            if (commandExecutor != null && commandExecutor.isAlive()) {
                commandExecutor.interrupt();
            }
            
            // Close connection
            if (connection != null) {
                connection.close();
            }
            
            // Clear variables
            if (variables != null) {
                variables.clear();
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Resource cleanup completed");
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Error during resource cleanup: " + e.getMessage());
        }
    }
}
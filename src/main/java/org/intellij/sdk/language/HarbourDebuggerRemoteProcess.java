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
    
    // Conditional breakpoint evaluation fields
    private String conditionalBreakpointFile = null;
    private int conditionalBreakpointLine = -1;
    
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
    
    // Hit count tracking for conditional breakpoints
    private final Map<String, Integer> breakpointHitCounts = new ConcurrentHashMap<>();
    
    // Track connection timing to prevent premature shutdown
    private volatile long connectionStartTime = 0;
    private static final long MIN_CONNECTION_TIME = 2000; // 2 seconds minimum before allowing stop()
    
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
                    
                    // Record connection start time to prevent premature shutdown
                    connectionStartTime = System.currentTimeMillis();
                    
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
            // Check if this is a handshake message (executable path + PID)
            if (message.contains(".exe") && message.contains("\n") && !message.contains("STOP") && !message.contains("BREAK")) {
                String[] checkLines = message.split("\\r?\\n");
                if (checkLines.length >= 2 && checkLines[0].contains(".exe") && checkLines[1].trim().matches("\\d+")) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Received handshake message - ignoring as debug command");
                    return; // Don't process handshake as debug command
                }
            }
            
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
                                String reason = parts[1];
                                String file = parts[2];
                                int line = Integer.parseInt(parts[3].trim());
                                
                                // Check if this is a breakpoint hit that needs condition evaluation
                                if ("break".equals(reason)) {
                                    // Store the conditional breakpoint info for later evaluation
                                    conditionalBreakpointFile = file;
                                    conditionalBreakpointLine = line;
                                    // Handle the stop to collect variables first, then evaluate condition
                                    handleStop(file, line);
                                } else {
                                    // Non-breakpoint stop (AltD, step, etc.)
                                    handleStop(file, line);
                                }
                            } catch (NumberFormatException e) {
                                HarbourLogger.log(project, "HarbourDebuggerRemoteProcess", "Invalid line number in STOP command: " + parts[3]);
                            }
                        } else if (parts.length >= 3) {
                            // Old format: STOP:file:line
                            try {
                                handleStop(parts[1], Integer.parseInt(parts[2].trim()));
                            } catch (NumberFormatException e) {
                                HarbourLogger.log(project, "HarbourDebuggerRemoteProcess", "Invalid line number in STOP command: " + parts[2]);
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
                    Thread.sleep(3000); // Wait 3 seconds for variables (increased to handle slower responses)
                    if (waitingForVariables && pendingStopPosition != null) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Variable timeout - notifying position reached anyway");
                        waitingForVariables = false;
                        variablesReceived = 0; // Reset counter for next stop
                        
                        // Capture values before clearing them
                        final String stopFile = pendingStopFile;
                        final int stopLine = pendingStopLine;
                        final XSourcePosition stopPosition = pendingStopPosition;
                        
                        // Check if this is a conditional breakpoint that needs evaluation BEFORE notifying
                        if (conditionalBreakpointFile != null && conditionalBreakpointLine != -1) {
                            if (stopFile != null && stopFile.equals(conditionalBreakpointFile) && stopLine == conditionalBreakpointLine) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "TIMEOUT DEBUG: About to evaluate condition for " + stopFile + ":" + stopLine);
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "TIMEOUT DEBUG: Current variables: " + variables);
                                
                                boolean shouldStop = shouldStopAtConditionalBreakpoint(stopFile, stopLine);
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "TIMEOUT DEBUG: shouldStopAtConditionalBreakpoint returned: " + shouldStop);
                                
                                if (!shouldStop) {
                                    // Condition not met, continue execution without notifying position
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                        "TIMEOUT: Breakpoint condition not met at " + stopFile + ":" + stopLine + ", continuing");
                                    
                                    // Clear all pending and conditional info
                                    pendingStopFile = null;
                                    pendingStopLine = -1;
                                    pendingStopPosition = null;
                                    conditionalBreakpointFile = null;
                                    conditionalBreakpointLine = -1;
                                    
                                    // Continue execution
                                    sendCommand("GO");
                                    return;
                                } else {
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                        "TIMEOUT: Breakpoint condition met at " + stopFile + ":" + stopLine + ", stopping");
                                }
                            }
                            // Clear conditional breakpoint info
                            conditionalBreakpointFile = null;
                            conditionalBreakpointLine = -1;
                        }
                        
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
                    
                    // Check if this is a conditional breakpoint that needs evaluation
                    if (conditionalBreakpointFile != null && conditionalBreakpointLine != -1) {
                        if (stopFile.equals(conditionalBreakpointFile) && stopLine == conditionalBreakpointLine) {
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "NORMAL DEBUG: About to evaluate condition for " + stopFile + ":" + stopLine);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "NORMAL DEBUG: Current variables: " + variables);
                            
                            boolean shouldStop = shouldStopAtConditionalBreakpoint(stopFile, stopLine);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "NORMAL DEBUG: shouldStopAtConditionalBreakpoint returned: " + shouldStop);
                            
                            if (!shouldStop) {
                                // Condition not met, continue execution without notifying position
                                HarbourLogger.log(project, "HarbourDebugger", 
                                    "Breakpoint condition not met at " + stopFile + ":" + stopLine + ", continuing");
                                
                                // Clear pending and conditional info
                                pendingStopFile = null;
                                pendingStopLine = -1;
                                pendingStopPosition = null;
                                conditionalBreakpointFile = null;
                                conditionalBreakpointLine = -1;
                                
                                // Continue execution
                                sendCommand("GO");
                                return;
                            } else {
                                HarbourLogger.log(project, "HarbourDebugger", 
                                    "Breakpoint condition met at " + stopFile + ":" + stopLine + ", stopping");
                            }
                        }
                        // Clear conditional breakpoint info
                        conditionalBreakpointFile = null;
                        conditionalBreakpointLine = -1;
                    }
                    
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
        sendCommand("STATICS", "0");
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
        // CRITICAL FIX: Return null to prevent XDebugSessionImpl from attaching ProcessListeners
        // This allows IntelliJ to create a DefaultDebugProcessHandler instead of using the actual
        // process handler, preventing premature session termination when the process ends.
        // This is the standard pattern used by other successful remote debuggers (Java, Python, etc.)
        HarbourLogger.log(project, "HarbourDebugger", 
            "Returning null from doGetProcessHandler() - using DefaultDebugProcessHandler for remote debugging");
        return null;
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
    
    /**
     * Check if we should stop at a conditional breakpoint by evaluating its condition
     */
    private boolean shouldStopAtConditionalBreakpoint(String file, int line) {
        HarbourLogger.log(project, "HarbourDebugger", 
            "SHOULD_STOP DEBUG: Checking conditional breakpoint for " + file + ":" + line);
        
        // Get the breakpoint for this location
        String breakpointKey = file + ":" + line;
        
        // Find the breakpoint with conditions
        var registeredBreakpoints = breakpointHandler.getRegisteredBreakpoints();
        HarbourLogger.log(project, "HarbourDebugger", 
            "SHOULD_STOP DEBUG: Found " + registeredBreakpoints.size() + " registered breakpoints");
        
        for (var breakpoint : registeredBreakpoints) {
            HarbourLogger.log(project, "HarbourDebugger", 
                "SHOULD_STOP DEBUG: Checking breakpoint: " + breakpoint);
            
            if (breakpoint.getSourcePosition() != null) {
                String bpFile = breakpoint.getSourcePosition().getFile().getName();
                int bpLine = breakpoint.getSourcePosition().getLine() + 1; // 0-based to 1-based
                
                HarbourLogger.log(project, "HarbourDebugger", 
                    "SHOULD_STOP DEBUG: Breakpoint at " + bpFile + ":" + bpLine + 
                    " vs target " + file + ":" + line);
                
                if (bpFile.equals(file) && bpLine == line) {
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "SHOULD_STOP DEBUG: Found matching breakpoint!");
                    
                    HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "SHOULD_STOP DEBUG: Properties: " + (properties != null ? "not null" : "NULL"));
                    
                    // Check custom properties storage if properties is null
                    if (properties == null) {
                        properties = HarbourDebuggerBreakpointPropertiesPanel.getCustomProperties(breakpoint);
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: Custom properties: " + (properties != null ? "not null" : "NULL"));
                    }
                    
                    // Also check persistent storage service
                    if (properties == null) {
                        HarbourBreakpointPropertiesStorage storage = HarbourBreakpointPropertiesStorage.getInstance(project);
                        properties = storage.getBreakpointProperties(breakpoint);
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: Persistent storage properties: " + (properties != null ? "not null" : "NULL"));
                    }
                    
                    if (properties != null) {
                        // Track hit count for this breakpoint
                        int currentHitCount = breakpointHitCounts.getOrDefault(breakpointKey, 0) + 1;
                        breakpointHitCounts.put(breakpointKey, currentHitCount);
                        
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: Breakpoint hit count: " + currentHitCount);
                        
                        boolean hasCondition = properties.hasCondition();
                        boolean hasHitCondition = properties.hasHitCondition();
                        String condition = properties.getCondition();
                        String hitCondition = properties.getHitCondition();
                        
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: hasCondition=" + hasCondition + ", condition='" + condition + "'");
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: hasHitCondition=" + hasHitCondition + ", hitCondition='" + hitCondition + "'");
                        
                        // Check hit condition first (if present)
                        if (hasHitCondition) {
                            boolean hitConditionMet = evaluateHitCondition(hitCondition, currentHitCount);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "SHOULD_STOP DEBUG: Hit condition '" + hitCondition + "' with count " + currentHitCount + " evaluated to: " + hitConditionMet);
                            
                            if (!hitConditionMet) {
                                return false; // Hit condition not met, don't stop
                            }
                        }
                        
                        // Check regular condition (if present)
                        if (hasCondition) {
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "SHOULD_STOP DEBUG: Evaluating breakpoint condition: " + condition);
                            
                            // Evaluate the condition using current variables
                            boolean result = evaluateCondition(condition);
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "SHOULD_STOP DEBUG: Condition '" + condition + "' evaluated to: " + result);
                            return result;
                        } else {
                            HarbourLogger.log(project, "HarbourDebugger", 
                                "SHOULD_STOP DEBUG: No condition, returning true");
                            return true;
                        }
                    } else {
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "SHOULD_STOP DEBUG: Properties is null, returning true");
                        return true;
                    }
                }
            } else {
                HarbourLogger.log(project, "HarbourDebugger", 
                    "SHOULD_STOP DEBUG: Breakpoint has null source position");
            }
        }
        
        HarbourLogger.log(project, "HarbourDebugger", 
            "SHOULD_STOP DEBUG: No matching breakpoint found, returning true");
        return true;
    }
    
    /**
     * Simple condition evaluator for basic Harbour expressions
     */
    private boolean evaluateCondition(String condition) {
        if (condition == null || condition.trim().isEmpty()) {
            HarbourLogger.log(project, "HarbourDebugger", "EVAL DEBUG: Empty condition, returning true");
            return true;
        }
        
        HarbourLogger.log(project, "HarbourDebugger", "EVAL DEBUG: Original condition: '" + condition + "'");
        condition = condition.trim().toLowerCase();
        HarbourLogger.log(project, "HarbourDebugger", "EVAL DEBUG: Normalized condition: '" + condition + "'");
        
        try {
            // Handle simple numeric comparisons: variable == value, variable > value, etc.
            if (condition.contains("==")) {
                String[] parts = condition.split("==");
                HarbourLogger.log(project, "HarbourDebugger", "EVAL DEBUG: Split on '==', got " + parts.length + " parts");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "EVAL DEBUG: Calling evaluateComparison('" + varName + "', '" + expectedValue + "', '==')");
                    boolean result = evaluateComparison(varName, expectedValue, "==");
                    HarbourLogger.log(project, "HarbourDebugger", "EVAL DEBUG: evaluateComparison returned: " + result);
                    return result;
                }
            } else if (condition.contains("!=")) {
                String[] parts = condition.split("!=");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    return evaluateComparison(varName, expectedValue, "!=");
                }
            } else if (condition.contains(">=")) {
                String[] parts = condition.split(">=");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    return evaluateComparison(varName, expectedValue, ">=");
                }
            } else if (condition.contains("<=")) {
                String[] parts = condition.split("<=");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    return evaluateComparison(varName, expectedValue, "<=");
                }
            } else if (condition.contains(">")) {
                String[] parts = condition.split(">");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    return evaluateComparison(varName, expectedValue, ">");
                }
            } else if (condition.contains("<")) {
                String[] parts = condition.split("<");
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    return evaluateComparison(varName, expectedValue, "<");
                }
            }
            
            HarbourLogger.log(project, "HarbourDebugger", 
                "Unsupported condition format: " + condition + " - defaulting to true");
            return true;
            
        } catch (Exception e) {
            HarbourLogger.log(project, "HarbourDebugger", 
                "Error evaluating condition '" + condition + "': " + e.getMessage() + " - defaulting to true");
            return true;
        }
    }
    
    /**
     * Evaluates hit condition for conditional breakpoints.
     * Supports formats like: "=5", ">3", ">=10", "%3", "==2"
     */
    private boolean evaluateHitCondition(String hitCondition, int currentHitCount) {
        if (hitCondition == null || hitCondition.trim().isEmpty()) {
            HarbourLogger.log(project, "HarbourDebugger", "HIT_EVAL DEBUG: Empty hit condition, returning true");
            return true;
        }
        
        String condition = hitCondition.trim();
        HarbourLogger.log(project, "HarbourDebugger", 
            "HIT_EVAL DEBUG: Evaluating hit condition '" + condition + "' with count " + currentHitCount);
        
        try {
            // Handle modulo (every N hits): %N
            if (condition.startsWith("%")) {
                int modValue = Integer.parseInt(condition.substring(1));
                boolean result = (currentHitCount % modValue) == 0;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Modulo condition %" + modValue + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // Handle equality: =N or ==N
            if (condition.startsWith("==") || condition.startsWith("=")) {
                String numStr = condition.startsWith("==") ? condition.substring(2) : condition.substring(1);
                int targetCount = Integer.parseInt(numStr);
                boolean result = currentHitCount == targetCount;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Equality condition " + condition + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // Handle greater than or equal: >=N
            if (condition.startsWith(">=")) {
                int targetCount = Integer.parseInt(condition.substring(2));
                boolean result = currentHitCount >= targetCount;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Greater-equal condition " + condition + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // Handle less than or equal: <=N
            if (condition.startsWith("<=")) {
                int targetCount = Integer.parseInt(condition.substring(2));
                boolean result = currentHitCount <= targetCount;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Less-equal condition " + condition + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // Handle greater than: >N
            if (condition.startsWith(">")) {
                int targetCount = Integer.parseInt(condition.substring(1));
                boolean result = currentHitCount > targetCount;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Greater-than condition " + condition + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // Handle less than: <N
            if (condition.startsWith("<")) {
                int targetCount = Integer.parseInt(condition.substring(1));
                boolean result = currentHitCount < targetCount;
                HarbourLogger.log(project, "HarbourDebugger", 
                    "HIT_EVAL DEBUG: Less-than condition " + condition + " with count " + currentHitCount + " = " + result);
                return result;
            }
            
            // If just a number, treat as equality
            int targetCount = Integer.parseInt(condition);
            boolean result = currentHitCount == targetCount;
            HarbourLogger.log(project, "HarbourDebugger", 
                "HIT_EVAL DEBUG: Number-only condition " + condition + " with count " + currentHitCount + " = " + result);
            return result;
            
        } catch (NumberFormatException e) {
            HarbourLogger.log(project, "HarbourDebugger", 
                "HIT_EVAL DEBUG: Invalid hit condition format '" + condition + "', defaulting to true");
            return true;
        } catch (Exception e) {
            HarbourLogger.log(project, "HarbourDebugger", 
                "HIT_EVAL DEBUG: Error evaluating hit condition '" + condition + "': " + e.getMessage() + ", defaulting to true");
            return true;
        }
    }
    
    /**
     * Evaluate a comparison between a variable and a value
     */
    private boolean evaluateComparison(String varName, String expectedValue, String operator) {
        HarbourLogger.log(project, "HarbourDebugger", 
            "COMP DEBUG: Starting evaluateComparison(varName='" + varName + "', expectedValue='" + expectedValue + "', operator='" + operator + "')");
        
        // Get current variable value - search through all scopes
        String upperVarName = varName.toUpperCase();
        HarbourLogger.log(project, "HarbourDebugger", "COMP DEBUG: upperVarName='" + upperVarName + "'");
        HarbourDebuggerValue variable = null;
        
        // Try direct lookup first
        variable = variables.get(upperVarName);
        HarbourLogger.log(project, "HarbourDebugger", "COMP DEBUG: Direct lookup result: " + (variable != null ? "found" : "not found"));
        
        // If not found, search through scoped variables (LOCALS.VAR, STATICS.VAR, etc.)
        if (variable == null) {
            HarbourLogger.log(project, "HarbourDebugger", "COMP DEBUG: Searching through scoped variables...");
            for (String key : variables.keySet()) {
                HarbourLogger.log(project, "HarbourDebugger", "COMP DEBUG: Checking key: '" + key + "'");
                if (key.endsWith("." + upperVarName)) {
                    variable = variables.get(key);
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "COMP DEBUG: Found variable '" + varName + "' in scope: " + key);
                    break;
                }
            }
        }
        
        if (variable == null) {
            HarbourLogger.log(project, "HarbourDebugger", 
                "Variable '" + varName + "' not found in any scope - condition defaults to false");
            HarbourLogger.log(project, "HarbourDebugger", 
                "Available variables: " + variables.keySet());
            return false;
        }
        
        String actualValue = variable.getValue();
        String actualType = variable.getType();
        
        HarbourLogger.log(project, "HarbourDebugger", 
            "Comparing " + varName + " (" + actualValue + ", type: " + actualType + ") " + operator + " " + expectedValue);
        
        // Handle numeric comparisons
        if ("N".equals(actualType) || "NUM".equals(actualType) || "NUMBER".equals(actualType)) {
            HarbourLogger.log(project, "HarbourDebugger", "COMP DEBUG: Handling numeric comparison");
            try {
                double actualNum = Double.parseDouble(actualValue);
                double expectedNum = Double.parseDouble(expectedValue);
                HarbourLogger.log(project, "HarbourDebugger", 
                    "COMP DEBUG: Parsed numbers - actual: " + actualNum + ", expected: " + expectedNum);
                
                boolean result;
                switch (operator) {
                    case "==": 
                        result = actualNum == expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " == " + expectedNum + " = " + result);
                        return result;
                    case "!=": 
                        result = actualNum != expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " != " + expectedNum + " = " + result);
                        return result;
                    case ">": 
                        result = actualNum > expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " > " + expectedNum + " = " + result);
                        return result;
                    case "<": 
                        result = actualNum < expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " < " + expectedNum + " = " + result);
                        return result;
                    case ">=": 
                        result = actualNum >= expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " >= " + expectedNum + " = " + result);
                        return result;
                    case "<=": 
                        result = actualNum <= expectedNum;
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: " + actualNum + " <= " + expectedNum + " = " + result);
                        return result;
                    default:
                        HarbourLogger.log(project, "HarbourDebugger", 
                            "COMP DEBUG: Unknown numeric operator: " + operator);
                        return false;
                }
            } catch (NumberFormatException e) {
                HarbourLogger.log(project, "HarbourDebugger", 
                    "COMP DEBUG: Error parsing numbers: " + e.getMessage());
                return false;
            }
        }
        // Handle string comparisons  
        else if ("C".equals(actualType) || "CHAR".equals(actualType) || "CHARACTER".equals(actualType)) {
            // Remove quotes from expected value if present
            String cleanExpectedValue = expectedValue.replaceAll("^\"|\"$", "").replaceAll("^'|'$", "");
            
            switch (operator) {
                case "==": return actualValue.equals(cleanExpectedValue);
                case "!=": return !actualValue.equals(cleanExpectedValue);
                default:
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "String comparison operator '" + operator + "' not supported");
                    return false;
            }
        }
        // Handle logical comparisons
        else if ("L".equals(actualType) || "LOGICAL".equals(actualType)) {
            boolean actualBool = ".T.".equals(actualValue) || "true".equalsIgnoreCase(actualValue);
            boolean expectedBool = ".T.".equals(expectedValue) || "true".equalsIgnoreCase(expectedValue);
            
            switch (operator) {
                case "==": return actualBool == expectedBool;
                case "!=": return actualBool != expectedBool;
                default:
                    HarbourLogger.log(project, "HarbourDebugger", 
                        "Logical comparison operator '" + operator + "' not supported");
                    return false;
            }
        }
        
        HarbourLogger.log(project, "HarbourDebugger", 
            "Unsupported variable type '" + actualType + "' for comparison");
        return false;
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
        
        // Check if we're in the initial connection phase - prevent premature shutdown
        long timeSinceConnection = System.currentTimeMillis() - connectionStartTime;
        if (connectionStartTime > 0 && timeSinceConnection < MIN_CONNECTION_TIME) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "IGNORING premature stop() call - only " + timeSinceConnection + "ms since connection (minimum " + MIN_CONNECTION_TIME + "ms)");
            return; // Don't proceed with shutdown during initial connection phase
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
        
        // 3. Close connection (this handles socket cleanup and port release)
        if (connection != null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Closing debugger connection");
            try {
                connection.close();
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug connection closed successfully - port should be available");
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
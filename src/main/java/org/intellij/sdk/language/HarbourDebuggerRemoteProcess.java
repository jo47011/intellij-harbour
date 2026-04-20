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
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.XDebuggerManagerListener;
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
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.stream.Stream;

/**
 * Remote debug process handler using TCP communication
 */
public class HarbourDebuggerRemoteProcess extends HarbourDebuggerBaseProcess {
    private final ExecutionResult executionResult;
    private final ProcessHandler processHandler;
    private final HarbourDebuggerConnection connection;
    private final HarbourLiveDBFConnection liveDBFConnection;
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
    private volatile boolean sessionInitialized = false;
    
    // Conditional breakpoint evaluation fields
    private String conditionalBreakpointFile = null;
    private int conditionalBreakpointLine = -1;
    
    // Enhanced command execution management
    private final Object commandLock = new Object();
    private final BlockingQueue<DebugCommand> commandQueue = new LinkedBlockingQueue<>();
    private final Thread commandExecutor;
    private volatile boolean shutdownRequested = false;
    
    // Command throttling settings - ZERO DELAY for absolute maximum speed
    private static final long MIN_COMMAND_INTERVAL = 0;   // No delay between commands 
    private static final long NEXT_COMMAND_DELAY = 0;     // No extra delay for NEXT commands
    
    // Debugger state management - prevents rapid command execution
    public enum DebuggerState {
        DISCONNECTED,  // Not connected to debug target
        RUNNING,       // Program is running
        SUSPENDED,     // Stopped at breakpoint, ready for commands
        STEPPING       // Executing a step command, ignore new commands
    }
    
    private volatile DebuggerState debuggerState = DebuggerState.DISCONNECTED;
    private volatile boolean hasPendingStepCommand = false;

    // STACK-based positioning
    private volatile boolean expectingStackForPosition = false;
    private volatile String lastStopFile = null;
    private volatile int lastStopLine = -1;
    private volatile long lastStopTime = 0;

    // Track variable scope completion for synchronized UI update
    private final Set<String> receivedVariableScopes = Collections.synchronizedSet(new HashSet<>());
    private volatile boolean waitingForVariables = false;

    // Step generation counter for aborting variable waits on rapid stepping
    private volatile long stepGeneration = 0;
    private volatile boolean abortVariableWait = false;

    // Hit count tracking for conditional breakpoints
    private final Map<String, Integer> breakpointHitCounts = new ConcurrentHashMap<>();

    // Tracepoint manager for data breakpoints (watch variable changes)
    private HarbourTracepointManager tracepointManager;

    // Track connection timing to prevent premature shutdown
    private volatile long connectionStartTime = 0;
    private static final long MIN_CONNECTION_TIME = 2000; // 2 seconds minimum before allowing stop()
    
    // Buffer for accumulating area response data (FIELDS, RECORD, SCHEMA)
    private List<String> areaResponseBuffer = null;
    private String areaResponseCommand = null;
    
    public HarbourDebuggerRemoteProcess(@NotNull XDebugSession session,
                                       @NotNull ExecutionResult executionResult,
                                       int debugPort) {
        super(session);
        this.executionResult = executionResult;
        this.processHandler = executionResult.getProcessHandler();
        this.project = session.getProject();
        this.debugPort = debugPort;
        this.breakpointHandler = new HarbourDebuggerBreakpointHandler(this);
        
        // Set up listener for proper breakpoint timing
        project.getMessageBus().connect(project).subscribe(XDebuggerManager.TOPIC, new XDebuggerManagerListener() {
            @Override
            public void processStarted(@NotNull XDebugProcess debugProcess) {
                if (debugProcess == HarbourDebuggerRemoteProcess.this) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Session initialized - safe to check mute state");
                    sessionInitialized = true;
                    // Defer breakpoint sending to ensure proper state
                    ApplicationManager.getApplication().invokeLater(() -> {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "XDebuggerManagerListener.processStarted - about to check breakpoints");
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "isConnected: " + isConnected + ", sessionInitialized: " + sessionInitialized);
                        if (isConnected && sessionInitialized) {
                            sendBreakpointsAfterSessionReady();
                        } else {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Not ready to send breakpoints yet");
                        }
                    });
                }
            }
        });
        
        // Create debug connection
        this.connection = new HarbourDebuggerConnection(debugPort);
        
        // Create live DBF connection for workarea monitoring
        this.liveDBFConnection = new HarbourLiveDBFConnection(project, connection);

        // Create tracepoint manager for data breakpoints
        this.tracepointManager = new HarbourTracepointManager(this);

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
        
        // Monitor process termination for GUI programs to automatically stop debug session
        if (processHandler != null) {
            processHandler.addProcessListener(new com.intellij.execution.process.ProcessAdapter() {
                @Override
                public void processTerminated(@NotNull com.intellij.execution.process.ProcessEvent event) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Target process terminated with exit code: " + event.getExitCode() + " - stopping debug session");
                    
                    // Delay stopping the debug session to allow connection to establish
                    // This prevents race condition where process exits before connection is made
                    ApplicationManager.getApplication().executeOnPooledThread(() -> {
                        // Wait 5 seconds for connection to establish
                        try {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Process terminated - waiting 5 seconds for debug connection...");
                            Thread.sleep(5000);
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                        }
                        
                        // Now check if we have a connection
                        ApplicationManager.getApplication().invokeLater(() -> {
                            if (isConnected) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Connection established - keeping debug session active despite process termination");
                            } else {
                                try {
                                    getSession().stop();
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                        "No debug connection after 5s wait - stopping debug session");
                                } catch (Exception e) {
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                        "Error stopping debug session: " + e.getMessage());
                                }
                            }
                        });
                    });
                }
            });
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Added process termination listener with connection wait");
        }
        
        // Start debug server listening immediately in constructor to ensure it's ready before Harbour execution
        try {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Starting debug server on port " + debugPort);
            
            // Start listening immediately in constructor - this is synchronous and fast
            boolean serverStarted = connection.startListening();
            
            if (serverStarted) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug server listening on port " + debugPort);
            } else {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to start debug server on port " + debugPort);
            }
            
            // Now start accepting connections asynchronously (this will block until connection arrives)
            ApplicationManager.getApplication().executeOnPooledThread(() -> {
                try {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Waiting for Harbour program to connect...");
                    
                    isConnected = connection.acceptConnection(this::handleDebugMessage);
                
                    if (isConnected) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Harbour connection established");
                        updateDebuggerState(DebuggerState.RUNNING, false);  // Initially running
                        
                        // Start live DBF monitoring
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** VERSION 1.1.14 DEBUG - CALLING liveDBFConnection.startMonitoring()");
                        liveDBFConnection.startMonitoring();
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** VERSION 1.1.14 DEBUG - FINISHED liveDBFConnection.startMonitoring()");
                        
                        // Record connection start time to prevent premature shutdown
                        connectionStartTime = System.currentTimeMillis();
                        
                        // With minimal init.cld approach, no immediate clearing needed
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Connection established - init.cld is minimal, will set breakpoints via remote protocol");
                        
                        // Standard breakpoint processing 
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "sessionInitialized: " + sessionInitialized);
                        if (sessionInitialized) {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Session ready, processing breakpoints via remote protocol");
                            sendBreakpointsAfterSessionReady();
                        } else {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Waiting for proper session initialization");
                        }
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
            
        } catch (IOException e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "❌ CRITICAL ERROR: Failed to start debug server listening: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
        }
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
            
            String[] lines = message.split("\\r?\\n");  // Handle both Unix (\n) and Windows (\r\n) line endings
            if (lines.length == 0) return;
        
        // Check if message contains multiple commands (e.g., END_PUBLICS followed by ARRAY or HASH)
        // This can happen when responses are buffered together
        int arrayStartIndex = -1;
        int hashStartIndex = -1;
        for (int i = 0; i < lines.length; i++) {
            if ("ARRAY".equals(lines[i])) {
                arrayStartIndex = i;
                break;
            }
            if ("HASH".equals(lines[i])) {
                hashStartIndex = i;
                break;
            }
        }
        
        // If ARRAY command found in the message, process it separately
        if (arrayStartIndex >= 0) {
            // First, process any command before ARRAY if present
            if (arrayStartIndex > 0) {
                String firstCommand = lines[0];
                String[] firstCommandLines = Arrays.copyOfRange(lines, 0, arrayStartIndex);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Processing first command: " + firstCommand);
                processCommand(firstCommand, firstCommandLines);
            }
            
            // Then process the ARRAY command
            String[] arrayCommandLines = Arrays.copyOfRange(lines, arrayStartIndex, lines.length);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Processing ARRAY command with " + arrayCommandLines.length + " lines");
            processCommand("ARRAY", arrayCommandLines);
            return;
        }
        
        // If HASH command found in the message, process it separately
        if (hashStartIndex >= 0) {
            // First, process any command before HASH if present
            if (hashStartIndex > 0) {
                String firstCommand = lines[0];
                String[] firstCommandLines = Arrays.copyOfRange(lines, 0, hashStartIndex);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Processing first command: " + firstCommand);
                processCommand(firstCommand, firstCommandLines);
            }
            
            // Then process the HASH command
            String[] hashCommandLines = Arrays.copyOfRange(lines, hashStartIndex, lines.length);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Processing HASH command with " + hashCommandLines.length + " lines");
            processCommand("HASH", hashCommandLines);
            return;
        }
        
        String command = lines[0];
        
        // Add debug logging for message routing
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** MESSAGE ROUTING - command='" + command + "', lines.length=" + lines.length + ", contains colon=" + command.contains(":"));
        
        processCommand(command, lines);
        
        } finally {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Message processing complete");
        }
    }
    
    private void processCommand(String command, String[] lines) {
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
                                
                                // Check if this is a conditional breakpoint
                                if ("break".equals(reason) &&
                                        hasConditionalBreakpoint(file, line)) {
                                    conditionalBreakpointFile = file;
                                    conditionalBreakpointLine = line;
                                }
                                handleStop(file, line);
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
                        
                    case "ERROR_MSG":
                        if (parts.length >= 2) {
                            // Handle runtime error messages from global error handler
                            String errorMessage = command.substring(10); // Skip "ERROR_MSG:"
                            handleErrorMessage(errorMessage);
                        }
                        break;
                        
                    case "ERROR_STACK":
                        if (parts.length >= 2) {
                            // Handle stack trace lines from global error handler
                            String stackLine = command.substring(12); // Skip "ERROR_STACK:"
                            handleErrorStackTrace(stackLine);
                        }
                        break;
                        
                    case "EXPRESSION":
                        // Handle expression evaluation response
                        // Format: EXPRESSION:stack_level:type:value
                        handleExpressionResult(command);
                        break;
                        
                    case "AREA":
                        // Check if this is a workarea info message or a detailed data request response
                        if (parts.length >= 2 && (parts[1].equals("FIELDS") || parts[1].equals("RECORD") || parts[1].equals("SCHEMA"))) {
                            // This is a response to AREA{n}:FIELDS/RECORD/SCHEMA request
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", ">>> AREA RESPONSE DETECTED in single-line path: " + command);
                            // Don't return early - let it fall through to the multi-line handler
                            break;
                        } else {
                            // Handle workarea information messages (during enumeration)
                            liveDBFConnection.processWorkareaMessage(command);
                            break;
                        }
                        
                    case "WORKAREAS":
                        // Handle complete WORKAREAS message (fallback if routed here)
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** WORKAREAS in first switch - redirecting to multi-line handler");
                        // Fall through to multi-line handler below
                        break;

                    case "TRACEPOINT_HIT":
                        // Handle tracepoint hit notification
                        // Format: TRACEPOINT_HIT:variableName:oldValue:newValue
                        handleTracepointHit(command);
                        break;

                    default:
                        // Check if this is a variable sent outside blocks (format: NAME:TYPE:VALUE)
                        if (parts.length == 3) {
                            String varName = parts[0];
                            String varType = parts[1];
                            String varValue = parts[2];
                            
                            // Log the variable for debugging
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "DEBUGGING: Variable outside block detected - Name: " + varName + 
                                ", Type: " + varType + ", Value: " + varValue);
                            
                            // Check if this looks like a variable (type should be single letter)
                            if (varType.length() == 1 && "CNLDAOHUP".contains(varType)) {
                                // This is a variable sent outside standard blocks
                                // Process ALL lines in the message as variables
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Processing " + lines.length + " lines of variables outside blocks");
                                
                                // Build a list of all valid variable lines
                                java.util.List<String> validVarLines = new java.util.ArrayList<>();
                                
                                for (String line : lines) {
                                    String[] lineParts = line.split(":", 3);
                                    if (lineParts.length == 3 && lineParts[1].length() == 1 && 
                                        "CNLDAOHUP".contains(lineParts[1])) {
                                        validVarLines.add(line);
                                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                            "Adding variable to LOCALS: " + line);
                                    }
                                }
                                
                                // Handle all valid variables at once
                                // Pass special flag to indicate these are additional variables, not replacements
                                if (!validVarLines.isEmpty()) {
                                    handleVariablesAdditive("LOCALS", validVarLines.toArray(new String[0]));
                                }
                            }
                        }
                        break;
                }
            }
            
            // Check if we're buffering area responses and this is data for the buffer
            if (areaResponseBuffer != null) {
                // Check for VALUE:, FIELD:, INFO:, COLUMN:, ROW:, CELL:, INDEX: lines
                if (command.startsWith("VALUE:") || command.startsWith("FIELD:") || command.startsWith("INFO:") ||
                    command.startsWith("COLUMN:") || command.startsWith("ROW:") || command.startsWith("CELL:") ||
                    command.startsWith("INDEX:") || command.startsWith("CURRENT")) {
                    // If this is a multi-line message, add ALL lines to the buffer
                    if (lines.length > 1) {
                        for (String line : lines) {
                            if (!line.trim().isEmpty()) {
                                areaResponseBuffer.add(line);
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Buffered data line (multi-line message): " + line);
                            }
                        }
                    } else {
                        // Single line message
                        areaResponseBuffer.add(command);
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Buffered data line (single-line path): " + command);
                    }
                    
                    // Send the data immediately, don't wait for END marker
                    // This ensures the UI updates as soon as data arrives
                    if (areaResponseBuffer != null && areaResponseCommand != null) {
                        String[] responseData = areaResponseBuffer.toArray(new String[0]);
                        liveDBFConnection.processAreaResponse(areaResponseCommand, responseData);
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sent partial data to UI: " + areaResponseBuffer.size() + " lines");
                    }
                    
                    return;
                }
                // Check for END markers
                else if (command.equals("END_RECORD") || command.equals("END_FIELDS") || command.equals("END_SCHEMA") || 
                         command.equals("END_RECORDS") || command.equals("END_INDEXES")) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", ">>> END MARKER RECEIVED: " + command + " for buffered command: " + areaResponseCommand + " with " + areaResponseBuffer.size() + " lines");
                    
                    // Process the complete buffered response
                    String[] responseData = areaResponseBuffer.toArray(new String[0]);
                    liveDBFConnection.processAreaResponse(areaResponseCommand, responseData);
                    
                    // Clear the buffer
                    areaResponseCommand = null;
                    areaResponseBuffer = null;
                    return;
                }
            }
            
            // Don't return early if it's WORKAREAS or AREA response - let them continue to multi-line handler
            if (!command.equals("WORKAREAS") && 
                !(command.startsWith("AREA") && command.contains(":") && 
                  (command.contains("FIELDS") || command.contains("RECORD") || command.contains("SCHEMA") ||
                   command.contains("RECORDS") || command.contains("INDEXES")))) {
                return;
            }
        }
        
        // Normalize STACK command (it may come as "STACK 3" with frame count)
        String normalizedCommand = command;
        if (command.startsWith("STACK ")) {
            normalizedCommand = "STACK";
        }

        // Handle multi-line commands (original format)
        switch (normalizedCommand) {
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
                // Handle "STACK" or "STACK n" where n is the number of frames
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

            case "END_LOCALS":
            case "END_STATICS":
            case "END_PRIVATES":
            case "END_PUBLICS":
                // Mark this variable scope as received
                String scope = command.substring(4);  // Remove "END_" prefix
                receivedVariableScopes.add(scope);
                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                    "Variable scope completed: " + scope + " (total=" + receivedVariableScopes.size() + "/4)");
                // All variables received - mark as ready
                if (receivedVariableScopes.size() == 4) {
                    waitingForVariables = false;
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "All variables ready");
                }
                break;
                
            case "ARRAY":
                // Handle array elements response
                String[] arrayLines = Arrays.copyOfRange(lines, 1, lines.length);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "ARRAY response with " + arrayLines.length + " element lines");
                handleArrayElements(arrayLines);
                break;
                
            case "HASH":
                // Handle hash elements response
                String[] hashLines = Arrays.copyOfRange(lines, 1, lines.length);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "HASH response with " + hashLines.length + " element lines");
                handleHashElements(hashLines);
                break;
                
            case "OBJECT":
                // Handle object properties response
                String[] objectLines = Arrays.copyOfRange(lines, 1, lines.length);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "OBJECT response with " + objectLines.length + " property lines");
                handleObjectProperties(objectLines);
                break;
                
            case "EXPRESSION":
                // Handle expression evaluation response
                // Format: EXPRESSION:stack_level:type:value
                if (lines.length > 0) {
                    handleExpressionResult(lines[0]);
                }
                break;
                
            case "WORKAREAS":
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** WORKAREAS CASE REACHED - lines.length=" + lines.length);
                // Handle workarea enumeration - process all lines in the message
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** CALLING liveDBFConnection.processWorkareaMessage('" + command + "')");
                liveDBFConnection.processWorkareaMessage(command); // Process "WORKAREAS" start
                
                // Process all AREA: lines and END_WORKAREAS in this message
                for (int i = 1; i < lines.length; i++) {
                    String line = lines[i].trim();
                    if (!line.isEmpty()) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** CALLING liveDBFConnection.processWorkareaMessage('" + line + "')");
                        liveDBFConnection.processWorkareaMessage(line);
                    }
                }
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** WORKAREAS CASE COMPLETED");
                break;
                
            default:
                // Check if we're currently buffering and this is multi-line data for the buffer
                if (areaResponseBuffer != null && areaResponseCommand != null && lines.length > 1) {
                    // This is likely COLUMN/ROW/CELL data that arrived as a multi-line message
                    // Check if the first line matches what we expect for the current buffer type
                    boolean isBufferData = false;
                    
                    if (areaResponseCommand.contains(":RECORDS") && 
                        (command.startsWith("COLUMN:") || command.startsWith("ROW:") || 
                         command.startsWith("CELL:") || command.startsWith("ERROR:"))) {
                        isBufferData = true;
                    } else if (areaResponseCommand.contains(":INDEXES") && 
                               (command.startsWith("CURRENT:") || command.startsWith("CURRENT_") || 
                                command.startsWith("INDEX:") || command.startsWith("ERROR:"))) {
                        isBufferData = true;
                    }
                    
                    if (isBufferData) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Adding " + lines.length + " lines to buffer for " + areaResponseCommand);
                        // Add all lines to the buffer
                        for (String line : lines) {
                            areaResponseBuffer.add(line);
                        }
                        break;
                    }
                }
                
                // Handle area-specific responses (AREA1:FIELDS, AREA2:RECORD, etc.)
                if (command.startsWith("AREA") && command.contains(":")) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "*** AREA-SPECIFIC COMMAND RECEIVED: " + command);
                    
                    // Check if this is a multi-line area response that needs buffering
                    String[] parts = command.split(":", 2);  // Split only on first colon
                    if (parts.length >= 2) {
                        String responseType = parts[1].split(":")[0];  // Get the command type (FIELDS, RECORDS, etc.)
                        if (responseType.equals("FIELDS") || responseType.equals("RECORD") || responseType.equals("SCHEMA") ||
                            responseType.equals("RECORDS") || responseType.equals("INDEXES")) {
                            // Start buffering for multi-line responses
                            areaResponseCommand = command;
                            areaResponseBuffer = new ArrayList<>();
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", ">>> BUFFERING STARTED for command: " + command + " (type: " + responseType + ")");
                            
                            // Add any immediate data from this message
                            if (lines.length > 1) {
                                for (int i = 1; i < lines.length; i++) {
                                    if (!lines[i].trim().isEmpty()) {
                                        areaResponseBuffer.add(lines[i]);
                                    }
                                }
                            }
                        } else {
                            // Single-line area response, process immediately
                            liveDBFConnection.processAreaResponse(command, Arrays.copyOfRange(lines, 1, lines.length));
                        }
                    }
                    break;
                }
                
                // Check if we're buffering area responses and this is data for the buffer
                if (areaResponseBuffer != null) {
                    // Check for data lines - but be more selective based on what we're waiting for
                    boolean shouldBuffer = false;
                    
                    if (areaResponseCommand != null) {
                        if (areaResponseCommand.contains(":RECORD") && !areaResponseCommand.contains(":RECORDS")) {
                            // For RECORD, only accept VALUE: lines
                            shouldBuffer = command.startsWith("VALUE:");
                        } else if (areaResponseCommand.contains(":RECORDS")) {
                            // For RECORDS, only accept COLUMN:, ROW:, CELL:, ERROR:
                            shouldBuffer = command.startsWith("COLUMN:") || command.startsWith("ROW:") || 
                                         command.startsWith("CELL:") || command.startsWith("ERROR:");
                        } else if (areaResponseCommand.contains(":INDEXES")) {
                            // For INDEXES, only accept CURRENT:, CURRENT_*, INDEX:, ERROR:
                            shouldBuffer = command.startsWith("CURRENT:") || command.startsWith("CURRENT_") || 
                                         command.startsWith("INDEX:") || command.startsWith("ERROR:");
                        } else if (areaResponseCommand.contains(":FIELDS")) {
                            // For FIELDS, only accept FIELD:
                            shouldBuffer = command.startsWith("FIELD:");
                        } else if (areaResponseCommand.contains(":SCHEMA")) {
                            // For SCHEMA, only accept INFO:, FIELD:
                            shouldBuffer = command.startsWith("INFO:") || command.startsWith("FIELD:");
                        }
                    }
                    
                    if (shouldBuffer) {
                        areaResponseBuffer.add(command);
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Buffered data line: " + command);
                        
                        // Don't send partial data for RECORDS/INDEXES - wait for complete data
                        if (areaResponseCommand != null && 
                            !areaResponseCommand.contains(":RECORDS") && 
                            !areaResponseCommand.contains(":INDEXES")) {
                            // Send the data immediately for other types
                            String[] responseData = areaResponseBuffer.toArray(new String[0]);
                            liveDBFConnection.processAreaResponse(areaResponseCommand, responseData);
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Sent partial data to UI: " + areaResponseBuffer.size() + " lines");
                        }
                        
                        break;
                    }
                    // Check for END markers
                    else if (command.equals("END_RECORD") || command.equals("END_FIELDS") || command.equals("END_SCHEMA") ||
                             command.equals("END_RECORDS") || command.equals("END_INDEXES")) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Area response complete: " + areaResponseCommand + " with " + areaResponseBuffer.size() + " lines");
                        
                        // Process the complete buffered response
                        String[] responseData = areaResponseBuffer.toArray(new String[0]);
                        liveDBFConnection.processAreaResponse(areaResponseCommand, responseData);
                        
                        // Clear the buffer
                        areaResponseCommand = null;
                        areaResponseBuffer = null;
                        break;
                    }
                }
                
                // CRITICAL FIX: Add break to prevent fallthrough to END case
                // END_LOCALS, END_STATICS etc. should NOT trigger session end!
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
                
            case "END_WORKAREAS":
                // Handle end of workarea enumeration
                liveDBFConnection.processWorkareaMessage(command);
                break;
        }
    }
    
    private void handleStop(String file, int line) {
        // Duplicate STOP suppression: ignore same file:line within 100ms
        long now = System.currentTimeMillis();
        if (file.equals(lastStopFile) && line == lastStopLine &&
                (now - lastStopTime) < 100) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Suppressing duplicate STOP for " + file + ":" + line);
            return;
        }

        currentFile = file;
        currentLine = line;

        // Update debugger state to SUSPENDED when we stop and clear pending step flag
        updateDebuggerState(DebuggerState.SUSPENDED, false);

        // Reset abort flag so variable waiting can proceed for this stop
        abortVariableWait = false;

        // Set flags to track STACK and variable scope arrivals
        waitingForVariables = true;
        receivedVariableScopes.clear();
        lastStopFile = file;
        lastStopLine = line;
        lastStopTime = now;

        // Request stack trace for call stack panel AND position verification
        sendCommand("STACK");

        // Request variables for variables panel (async - they'll arrive soon)
        sendCommand("LOCALS", "0");
        sendCommand("STATICS", "0");
        sendCommand("PRIVATES", "0");
        sendCommand("PUBLICS");

        // Check if this is a conditional breakpoint that needs evaluation
        if (conditionalBreakpointFile != null &&
                conditionalBreakpointLine >= 0) {
            final String cbFile = conditionalBreakpointFile;
            final int cbLine = conditionalBreakpointLine;
            // Don't let STACK auto-trigger showPositionInUI
            expectingStackForPosition = false;

            ApplicationManager.getApplication().executeOnPooledThread(() -> {
                // Wait for variables to arrive (needed for condition eval)
                waitForVariables(2000);

                boolean shouldStop =
                    shouldStopAtConditionalBreakpoint(cbFile, cbLine);
                conditionalBreakpointFile = null;
                conditionalBreakpointLine = -1;

                if (shouldStop) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                        "Conditional BP met at " + cbFile + ":" + cbLine);
                    showPositionInUI(file, line);
                } else {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                        "Conditional BP NOT met at " +
                        cbFile + ":" + cbLine + ", continuing");
                    updateDebuggerState(DebuggerState.RUNNING, false);
                    sendCommand("GO");
                }
            });
        } else {
            // Normal (non-conditional) stop
            expectingStackForPosition = true;

            // Start timeout thread to show position if STACK doesn't arrive
            ApplicationManager.getApplication().executeOnPooledThread(() -> {
                try {
                    Thread.sleep(1000);  // Wait 1 second for STACK
                } catch (InterruptedException e) {
                    // Interrupted, that's fine
                }
                // If we still haven't shown position, do it now with STOP data
                if (expectingStackForPosition) {
                    expectingStackForPosition = false;
                    showPositionInUI(file, line);
                }
            });
        }

        // Note: We'll show UI when STACK arrives (fast), but variables will load async
        // HarbourDebuggerStackFrame.computeChildren() will wait for variables if needed
    }
    
    
    // Store the current stack trace
    private List<StackFrameInfo> currentStackTrace = new ArrayList<>();

    private void handleStackTrace(String[] stackLines) {
        currentStackTrace.clear();

        for (String line : stackLines) {
            if (line == null || line.trim().isEmpty()) {
                continue;
            }

            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stack: " + line);

            // Try different parsing formats
            // Format 1: "function_name at file.prg:line"
            // Format 2: "function_name(file.prg:line)"
            // Format 3: "file.prg:line:function_name"

            String functionName = null;
            String file = null;
            int lineNum = -1;

            // Try format 1: "function_name at file.prg:line"
            if (line.contains(" at ")) {
                String[] parts = line.split(" at ");
                if (parts.length == 2) {
                    functionName = parts[0].trim();
                    String location = parts[1].trim();
                    int colonIndex = location.lastIndexOf(':');
                    if (colonIndex > 0) {
                        file = location.substring(0, colonIndex);
                        try {
                            lineNum = Integer.parseInt(location.substring(colonIndex + 1));
                        } catch (NumberFormatException e) {
                            // Ignore
                        }
                    }
                }
            }
            // Try format 2: "function_name(file.prg:line)"
            else if (line.contains("(") && line.contains(")")) {
                int parenStart = line.indexOf('(');
                int parenEnd = line.lastIndexOf(')');
                if (parenStart > 0 && parenEnd > parenStart) {
                    functionName = line.substring(0, parenStart).trim();
                    String location = line.substring(parenStart + 1, parenEnd).trim();
                    int colonIndex = location.lastIndexOf(':');
                    if (colonIndex > 0) {
                        file = location.substring(0, colonIndex);
                        try {
                            lineNum = Integer.parseInt(location.substring(colonIndex + 1));
                        } catch (NumberFormatException e) {
                            // Ignore
                        }
                    }
                }
            }
            // Try format 3: Simple colon-separated "file:line:function" or "function:file:line"
            else if (line.contains(":")) {
                String[] parts = line.split(":");
                if (parts.length >= 2) {
                    // Try to find which part is the line number
                    for (int i = 0; i < parts.length; i++) {
                        try {
                            lineNum = Integer.parseInt(parts[i].trim());
                            // Found line number, now determine file and function
                            if (i == 1 && parts.length >= 3) {
                                // Format: file:line:function
                                file = parts[0].trim();
                                functionName = parts[2].trim();
                            } else if (i == 2 && parts.length >= 3) {
                                // Format: function:file:line
                                functionName = parts[0].trim();
                                file = parts[1].trim();
                            } else if (i == 1 && parts.length == 2) {
                                // Format: file:line (no function name)
                                file = parts[0].trim();
                                functionName = "Unknown";
                            }
                            break;
                        } catch (NumberFormatException e) {
                            // This part is not a number, continue
                        }
                    }
                }
            }

            // If we successfully parsed the stack frame, add it
            if (functionName != null && file != null && lineNum > 0) {
                currentStackTrace.add(new StackFrameInfo(functionName, file, lineNum));
                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                    "Parsed stack frame: " + functionName + " at " + file + ":" + lineNum);
            } else {
                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                    "Could not parse stack line: " + line);
            }
        }

        // Check if we should update position based on STACK response
        if (expectingStackForPosition && !currentStackTrace.isEmpty()) {
            StackFrameInfo firstFrame = currentStackTrace.get(0);

            // Normalize file paths for comparison (remove .\ prefix if present)
            String stackFile = firstFrame.file.startsWith(".\\") || firstFrame.file.startsWith("./")
                ? firstFrame.file.substring(2) : firstFrame.file;
            String stopFile = lastStopFile.startsWith(".\\") || lastStopFile.startsWith("./")
                ? lastStopFile.substring(2) : lastStopFile;

            // Compare STACK position with STOP position
            boolean positionChanged = !stackFile.equalsIgnoreCase(stopFile) || firstFrame.line != lastStopLine;

            if (positionChanged) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                    "STACK position differs from STOP: STOP=" + lastStopFile + ":" + lastStopLine +
                    ", STACK=" + firstFrame.file + ":" + firstFrame.line + " - updating position");

                // Update current position
                currentFile = firstFrame.file;
                currentLine = firstFrame.line;
            } else {
                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                    "STACK position matches STOP position: " + stackFile + ":" + firstFrame.line);
            }

            // Mark that STACK has arrived and show UI immediately (fast!)
            expectingStackForPosition = false;
            showPositionInUI(currentFile, currentLine);
        }

        // Stack trace is now available for the Frames panel
    }

    // Check if all variables have arrived (used by HarbourDebuggerStackFrame)
    public boolean areVariablesReady() {
        return receivedVariableScopes.contains("LOCALS") &&
               receivedVariableScopes.contains("STATICS") &&
               receivedVariableScopes.contains("PRIVATES") &&
               receivedVariableScopes.contains("PUBLICS");
    }

    // Wait for variables to be ready (with timeout)
    // Returns the step generation at the time of call for checking if aborted
    public void waitForVariables(long timeoutMs) {
        long myGeneration = stepGeneration;
        long startTime = System.currentTimeMillis();
        while (!areVariablesReady() &&
               System.currentTimeMillis() - startTime < timeoutMs &&
               !abortVariableWait &&
               myGeneration == stepGeneration) {
            try {
                Thread.sleep(10);  // Check every 10ms
            } catch (InterruptedException e) {
                break;
            }
        }
        // Log if we were aborted due to rapid stepping
        if (myGeneration != stepGeneration || abortVariableWait) {
            HarbourLogger.log("HarbourDebuggerStackFrame",
                "Variable wait aborted due to new step (gen:" + myGeneration + " vs " + stepGeneration + ")");
        }
    }

    // Get current step generation (for HarbourDebuggerStackFrame to check)
    public long getStepGeneration() {
        return stepGeneration;
    }

    // Abort any ongoing variable waits
    public void abortVariableWaits() {
        abortVariableWait = true;
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Aborting variable waits");
    }

    // Show position in UI with current stack trace and variables
    private void showPositionInUI(String file, int line) {
        VirtualFile vFile = findSourceFile(file);
        if (vFile != null) {
            XSourcePosition position = XDebuggerUtil.getInstance()
                    .createPosition(vFile, line - 1);

            lastPosition = position;

            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Showing position in UI: " + file + ":" + line + " (variables=" + variables.size() +
                ", stackFrames=" + currentStackTrace.size() + ")");

            // Update UI with position, stack trace, and variables
            ApplicationManager.getApplication().invokeLater(() -> {
                if (getSession() == null) {
                    return;
                }

                HarbourDebuggerSuspendContext suspendContext =
                        new HarbourDebuggerSuspendContext(this, file, line, position);

                getSession().positionReached(suspendContext);

                try {
                    getSession().showExecutionPoint();

                    com.intellij.execution.ui.RunnerLayoutUi ui = getSession().getUI();
                    if (ui != null) {
                        com.intellij.ui.content.Content targetContent = null;

                        for (com.intellij.ui.content.Content content : ui.getContents()) {
                            String displayName = content.getDisplayName();
                            if (displayName != null && !displayName.equals("Console")) {
                                targetContent = content;
                                break;
                            }
                        }

                        if (targetContent != null) {
                            ui.selectAndFocus(targetContent, true, true);
                        }
                    }
                } catch (Exception e) {
                    // Ignore
                }
            });
        } else {
            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Could not find source file for position: " + file);
        }
    }
    
    // Helper class to store stack frame information
    public static class StackFrameInfo {
        public final String functionName;
        public final String file;
        public final int line;
        
        public StackFrameInfo(String functionName, String file, int line) {
            this.functionName = functionName;
            this.file = file;
            this.line = line;
        }
    }
    
    public List<StackFrameInfo> getCurrentStackTrace() {
        // If we have no stack trace, create a minimal one from current position
        if (currentStackTrace.isEmpty() && currentFile != null && currentLine > 0) {
            List<StackFrameInfo> minimal = new ArrayList<>();
            String funcName = extractFunctionName(currentFile);
            minimal.add(new StackFrameInfo(funcName, currentFile, currentLine));
            return minimal;
        }
        return new ArrayList<>(currentStackTrace);
    }
    
    private String extractFunctionName(String file) {
        // Extract function name from file path for display
        if (file == null) return "Unknown";
        
        String name = file;
        int lastSep = Math.max(file.lastIndexOf('/'), file.lastIndexOf('\\'));
        if (lastSep >= 0) {
            name = file.substring(lastSep + 1);
        }
        
        // Remove extension
        int dotIndex = name.lastIndexOf('.');
        if (dotIndex > 0) {
            name = name.substring(0, dotIndex);
        }
        
        return name;
    }
    
    private boolean isDuplicate(List<StackFrameInfo> frames, StackFrameInfo frame) {
        for (StackFrameInfo existing : frames) {
            if (existing.file.equals(frame.file) && existing.line == frame.line) {
                return true;
            }
        }
        return false;
    }
    
    // Helper method to find nested array elements
    private HarbourDebuggerValue findNestedArray(HarbourDebuggerValue parent, String indices) {
        // Parse indices like "[2]" or "[2][1]"
        if (!indices.startsWith("[") || !indices.contains("]")) {
            return null;
        }
        
        int closeIndex = indices.indexOf("]");
        String indexStr = indices.substring(1, closeIndex);
        
        try {
            // Find child with this index
            for (HarbourDebuggerValue child : parent.getChildren()) {
                if (child.getName().equals("[" + indexStr + "]")) {
                    // If there are more indices, recurse
                    if (closeIndex + 1 < indices.length() && indices.charAt(closeIndex + 1) == '[') {
                        return findNestedArray(child, indices.substring(closeIndex + 1));
                    }
                    return child;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Error finding nested array: " + e.getMessage());
        }
        
        return null;
    }
    
    private void handleHashElements(String[] hashLines) {
        // Handle hash elements response
        // Format expected: scope:hashName followed by key:type:value lines
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Processing hash elements: " + hashLines.length + " lines");
        
        if (hashLines.length == 0) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "No hash element data received");
            return;
        }
        
        // First line should contain hash info: scope:name
        String[] info = hashLines[0].split(":", 2);
        if (info.length < 2) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Invalid hash info format: " + hashLines[0]);
            return;
        }
        
        String scope = info[0];
        String hashName = info[1];
        String hashKey = scope + "." + hashName;
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Hash elements for " + hashKey);
        
        // Get the hash variable from our map (similar to arrays)
        HarbourDebuggerValue hashVar = variables.get(hashKey);
        
        // If not found directly, it might be a nested hash element
        if (hashVar == null && hashName.contains("[")) {
            // Parse nested path similar to arrays
            int bracketIndex = hashName.indexOf("[");
            String parentName = hashName.substring(0, bracketIndex);
            String parentKey = scope + "." + parentName;
            
            HarbourDebuggerValue parentVar = variables.get(parentKey);
            if (parentVar != null) {
                String indices = hashName.substring(bracketIndex);
                hashVar = findNestedArray(parentVar, indices);  // Reuse for nested structures
                
                if (hashVar != null) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Found nested hash: " + hashName);
                }
            }
        }
        
        if (hashVar == null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Hash variable not found: " + hashKey);
            return;
        }
        
        // Clear any existing children
        hashVar.clearChildren();
        
        // Process element lines
        for (int i = 1; i < hashLines.length; i++) {
            String line = hashLines[i];
            if (line.equals("END_HASH")) {
                break;
            }
            
            // Parse element: key:type:value
            String[] parts = line.split(":", 3);
            if (parts.length >= 3) {
                String key = parts[0];
                String type = parts[1];
                String value = parts[2];
                
                // Create child value for hash element
                HarbourDebuggerValue elementValue = new HarbourDebuggerValue(
                    "[\"" + key + "\"]", type, value);
                elementValue.setIsHashElement(true);
                
                // If element is also a hash, set it up for expansion
                if ("H".equals(type) && value.startsWith("Hash(") && value.endsWith(")")) {
                    try {
                        String sizeStr = value.substring(5, value.length() - 1);
                        int hashSize = Integer.parseInt(sizeStr);
                        // Use composite key for nested hashes
                        elementValue.setHashInfo(scope, hashName + "[\"" + key + "\"]", hashSize);
                        elementValue.setDebugProcess(this);
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Failed to parse nested hash size from: " + value);
                    }
                }
                // If element is an array, set it up for expansion
                else if ("A".equals(type) && value.startsWith("Array(") && value.endsWith(")")) {
                    try {
                        String sizeStr = value.substring(6, value.length() - 1);
                        int arraySize = Integer.parseInt(sizeStr);
                        elementValue.setArrayInfo(scope, hashName + "[\"" + key + "\"]", arraySize);
                        elementValue.setDebugProcess(this);
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Failed to parse array size from hash value: " + value);
                    }
                }
                
                hashVar.addChild(elementValue);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Hash element [\"" + key + "\"] = " + value + " (" + type + ")");
            }
        }
        
        // Trigger UI update
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Hash " + hashKey + " now has " + hashVar.getChildren().size() + " elements loaded");
        
        // Update the UI with the loaded children
        hashVar.updateChildren();
    }
    
    private void handleObjectProperties(String[] objectLines) {
        // Handle object properties response
        // Format expected: scope:objectName followed by property:type:value lines
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Processing object properties: " + objectLines.length + " lines");
        
        if (objectLines.length == 0) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "No object property data received");
            return;
        }
        
        // First line should contain object info: scope:name
        String[] info = objectLines[0].split(":", 2);
        if (info.length < 2) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Invalid object info format: " + objectLines[0]);
            return;
        }
        
        String scope = info[0];
        String objectName = info[1];
        String objectKey = scope + "." + objectName;
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Object properties for " + objectKey);
        
        // Get the object variable from our map
        HarbourDebuggerValue objectVar = variables.get(objectKey);
        
        if (objectVar == null) {
            // Log all available keys for debugging
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Object variable not found: " + objectKey);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Available keys in variables map: " + variables.keySet());
            
            // Maybe the response arrived after variables were cleared, keep the object for next time
            // Store a placeholder if needed
            return;
        }
        
        // Clear any existing children
        objectVar.clearChildren();
        
        // Process property lines
        for (int i = 1; i < objectLines.length; i++) {
            String line = objectLines[i];
            if (line.equals("END_OBJECT")) {
                break;
            }
            
            // Parse property: name:type:value
            String[] parts = line.split(":", 3);
            if (parts.length >= 3) {
                String propName = parts[0];
                String type = parts[1];
                String value = parts[2];
                
                // Create child value for object property
                HarbourDebuggerValue propertyValue = new HarbourDebuggerValue(
                    propName, type, value);
                propertyValue.setIsObjectProperty(true);
                
                // If property is a hash, set it up for expansion
                if ("H".equals(type) && value.startsWith("Hash(") && value.endsWith(")")) {
                    try {
                        String sizeStr = value.substring(5, value.length() - 1);
                        int hashSize = Integer.parseInt(sizeStr);
                        propertyValue.setHashInfo(scope, objectName + ":" + propName, hashSize);
                        propertyValue.setDebugProcess(this);
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Failed to parse hash size from object property: " + value);
                    }
                }
                // If property is an array, set it up for expansion
                else if ("A".equals(type) && value.startsWith("Array(") && value.endsWith(")")) {
                    try {
                        String sizeStr = value.substring(6, value.length() - 1);
                        int arraySize = Integer.parseInt(sizeStr);
                        propertyValue.setArrayInfo(scope, objectName + ":" + propName, arraySize);
                        propertyValue.setDebugProcess(this);
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Failed to parse array size from object property: " + value);
                    }
                }
                // If property is also an object, set it up for expansion
                else if ("O".equals(type)) {
                    propertyValue.setObjectInfo(scope, objectName + ":" + propName);
                    propertyValue.setDebugProcess(this);
                }
                
                objectVar.addChild(propertyValue);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Object property " + propName + " = " + value + " (" + type + ")");
            }
        }
        
        // Trigger UI update
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Object " + objectKey + " now has " + objectVar.getChildren().size() + " properties loaded");
        
        // Update the UI with the loaded children
        objectVar.updateChildren();
    }
    
    private void handleArrayElements(String[] arrayLines) {
        // Handle array elements response
        // Format expected: scope:arrayName:index:type:value
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Processing array elements: " + arrayLines.length + " lines");
        
        if (arrayLines.length == 0) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "No array element data received");
            return;
        }
        
        // First line should contain array info: scope:name
        String[] info = arrayLines[0].split(":", 2);
        if (info.length < 2) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Invalid array info format: " + arrayLines[0]);
            return;
        }
        
        String scope = info[0];
        String arrayName = info[1];
        String arrayKey = scope + "." + arrayName;
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Array elements for " + arrayKey);
        
        // Get the array variable from our map
        HarbourDebuggerValue arrayVar = variables.get(arrayKey);
        
        // If not found directly, it might be a nested array element
        if (arrayVar == null && arrayName.contains("[")) {
            // Parse nested array path like "BAR[2]"
            int bracketIndex = arrayName.indexOf("[");
            String parentName = arrayName.substring(0, bracketIndex);
            String parentKey = scope + "." + parentName;
            
            HarbourDebuggerValue parentVar = variables.get(parentKey);
            if (parentVar != null) {
                // Extract indices from path like "BAR[2]" or "BAR[2][1]"
                String indices = arrayName.substring(bracketIndex);
                arrayVar = findNestedArray(parentVar, indices);
                
                if (arrayVar != null) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Found nested array: " + arrayName);
                }
            }
        }
        
        if (arrayVar == null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Array variable not found: " + arrayKey);
            return;
        }
        
        // Clear any existing children
        arrayVar.clearChildren();
        
        // Process element lines
        for (int i = 1; i < arrayLines.length; i++) {
            String line = arrayLines[i];
            if (line.equals("END_ARRAY")) {
                break;
            }
            
            // Parse element: index:type:value
            String[] parts = line.split(":", 3);
            if (parts.length >= 3) {
                String index = parts[0];
                String type = parts[1];
                String value = parts[2];
                
                // Create child value for array element
                HarbourDebuggerValue elementValue = new HarbourDebuggerValue(
                    "[" + index + "]", type, value);
                elementValue.setIsArrayElement(true);
                
                // If element is also an array, set it up for expansion
                if ("A".equals(type) && value.startsWith("Array(") && value.endsWith(")")) {
                    try {
                        String sizeStr = value.substring(6, value.length() - 1);
                        int arraySize = Integer.parseInt(sizeStr);
                        // Use composite key for nested arrays
                        elementValue.setArrayInfo(scope, arrayName + "[" + index + "]", arraySize);
                        elementValue.setDebugProcess(this);
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Failed to parse nested array size from: " + value);
                    }
                }
                
                arrayVar.addChild(elementValue);
                
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Array element [" + index + "] = " + value + " (" + type + ")");
            }
        }
        
        // Trigger UI update - this needs to be done through the debug session
        // The array variable should now have its children populated
        HarbourLogger.log("HarbourDebuggerRemoteProcess",
            "Array " + arrayKey + " now has " + arrayVar.getChildren().size() + " elements loaded");

        // Complete pending synchronous future if this matches
        if (pendingArrayLoadFuture != null && arrayKey.equals(pendingArrayLoadKey)) {
            pendingArrayLoadFuture.complete(true);
        }

        // Update the UI with the loaded children
        arrayVar.updateChildren();
    }
    
    // New method that adds variables without clearing existing ones
    private void handleVariablesAdditive(String scope, String[] varLines) {
        try {
            // Validate input parameters to prevent crashes
            if (scope == null || scope.trim().isEmpty()) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Invalid scope for additive variables: " + scope);
                return;
            }
            
            if (varLines == null) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Variable lines are null for additive scope: " + scope);
                return;
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Processing " + varLines.length + " additive variable lines for scope: " + scope);
            
            // DO NOT CLEAR existing variables - this is the key difference
            // Just add new variables to the existing ones
            
            // Process each variable line with robust error handling
            for (int i = 0; i < varLines.length; i++) {
                try {
                    String line = varLines[i];
                    
                    // Validate line
                    if (line == null) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "WARNING: Null variable line at index " + i + " for additive scope " + scope);
                        continue;
                    }
                    
                    // Parse variable line with validation
                    String[] parts = line.split(":", 3);
                    if (parts.length >= 3) {
                        String name = parts[0];
                        String type = parts[1];
                        String value = parts[2];
                        
                        // Create variable key and value
                        String key = scope + "." + name;
                        HarbourDebuggerValue debugValue = new HarbourDebuggerValue(name, type, value);

                        // ALWAYS set debug process reference for tracepoint icon support
                        debugValue.setDebugProcess(this);

                        // Special handling for arrays
                        if ("A".equals(type) && value.startsWith("Array(") && value.endsWith(")")) {
                            try {
                                String sizeStr = value.substring(6, value.length() - 1);
                                int arraySize = Integer.parseInt(sizeStr);
                                debugValue.setArrayInfo(scope, name, arraySize);
                                debugValue.setDebugProcess(this);
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Array detected: " + name + " with size " + arraySize);
                            } catch (Exception e) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Failed to parse array size from: " + value);
                            }
                        }
                        // Special handling for hashes
                        else if ("H".equals(type) && value.startsWith("Hash(") && value.endsWith(")")) {
                            try {
                                String sizeStr = value.substring(5, value.length() - 1);
                                int hashSize = Integer.parseInt(sizeStr);
                                debugValue.setHashInfo(scope, name, hashSize);
                                debugValue.setDebugProcess(this);
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Hash detected: " + name + " with size " + hashSize);
                            } catch (Exception e) {
                                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Failed to parse hash size from: " + value);
                            }
                        }
                        // Special handling for objects
                        else if ("O".equals(type)) {
                            debugValue.setObjectInfo(scope, name);
                            debugValue.setDebugProcess(this);
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Object detected: " + name + " of type " + value);
                        }
                        
                        // Add to variables map
                        variables.put(key, debugValue);
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Variable " + scope + ": " + name + " = " + value + " (" + type + ")");
                    }
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "ERROR: Exception processing additive variable line " + i + " for scope " + scope + ": " + e.getMessage());
                }
            }

        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "ERROR: Unhandled exception in handleVariablesAdditive for scope " + scope + ": " + e.getMessage());
        }
    }
    
    private void handleVariables(String scope, String[] varLines) {
        try {
            // Validate input parameters to prevent crashes
            if (scope == null || scope.trim().isEmpty()) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Invalid scope for variables: " + scope);
                return;
            }
            
            if (varLines == null) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "ERROR: Variable lines are null for scope: " + scope);
                return;
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Processing " + varLines.length + " variable lines for scope: " + scope);
            
            // Clear only this scope's variables to prevent stale data
            try {
                variables.entrySet().removeIf(entry -> {
                    try {
                        return entry.getKey() != null && entry.getKey().startsWith(scope + ".");
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "ERROR: Exception during variable cleanup for key: " + entry.getKey() + " - " + e.getMessage());
                        return false; // Don't remove on error
                    }
                });
            } catch (Exception e) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "ERROR: Exception during variable map cleanup for scope " + scope + ": " + e.getMessage());
                HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
            }
            
            // Process each variable line with robust error handling
            for (int i = 0; i < varLines.length; i++) {
                try {
                    String line = varLines[i];
                    
                    // Validate line
                    if (line == null) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "WARNING: Null variable line at index " + i + " for scope " + scope);
                        continue;
                    }
                    
                    // Check for end markers
                    if (line.equals("END_" + scope)) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Found end marker for scope: " + scope);
                        break;
                    }
                    
                    // Parse variable line with validation
                    String[] parts = line.split(":", 3);
                    if (parts.length >= 3) {
                        String name = parts[0];
                        String type = parts[1];
                        String value = parts[2];
                        
                        // Validate parsed parts
                        if (name == null || name.trim().isEmpty()) {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "WARNING: Invalid variable name in line: " + line);
                            continue;
                        }
                        
                        if (type == null) {
                            type = "Unknown";
                        }
                        
                        if (value == null) {
                            value = "";
                        }
                        
                        // Safely create variable entry
                        try {
                            String key = scope + "." + name.trim();

                            // Check if variable already exists (may have pending expansion request)
                            HarbourDebuggerValue existingValue = variables.get(key);

                            HarbourDebuggerValue debugValue = new HarbourDebuggerValue(name.trim(), type.trim(), value);

                            // ALWAYS set debug process reference for tracepoint icon support
                            debugValue.setDebugProcess(this);

                            // Parse array info if it's an array type
                            if ("A".equals(type.trim()) && value.startsWith("Array(") && value.endsWith(")")) {
                                // Extract array size from "Array(n)" format
                                try {
                                    String sizeStr = value.substring(6, value.length() - 1);
                                    int arraySize = Integer.parseInt(sizeStr);
                                    debugValue.setArrayInfo(scope, name.trim(), arraySize);
                                    debugValue.setDebugProcess(this);  // Set reference to this debug process

                                    // Preserve pending expansion state from existing value
                                    if (existingValue != null) {
                                        debugValue.transferPendingState(existingValue);
                                    }

                                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                                        "Array detected: " + name.trim() + " with size " + arraySize);
                                } catch (Exception e) {
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                                        "Failed to parse array size from: " + value);
                                }
                            }
                            // Parse hash info if it's a hash type
                            else if ("H".equals(type.trim()) && value.startsWith("Hash(") && value.endsWith(")")) {
                                // Extract hash size from "Hash(n)" format
                                try {
                                    String sizeStr = value.substring(5, value.length() - 1);
                                    int hashSize = Integer.parseInt(sizeStr);
                                    debugValue.setHashInfo(scope, name.trim(), hashSize);
                                    debugValue.setDebugProcess(this);  // Set reference to this debug process

                                    // Preserve pending expansion state from existing value
                                    if (existingValue != null) {
                                        debugValue.transferPendingState(existingValue);
                                    }

                                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                                        "Hash detected: " + name.trim() + " with size " + hashSize);
                                } catch (Exception e) {
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess",
                                        "Failed to parse hash size from: " + value);
                                }
                            }
                            // Parse object info if it's an object type
                            else if ("O".equals(type.trim())) {
                                debugValue.setObjectInfo(scope, name.trim());
                                debugValue.setDebugProcess(this);  // Set reference to this debug process

                                // Preserve pending expansion state from existing value
                                if (existingValue != null) {
                                    debugValue.transferPendingState(existingValue);
                                }

                                HarbourLogger.log("HarbourDebuggerRemoteProcess",
                                    "Object detected: " + name.trim() + " of type " + value);
                            }

                            variables.put(key, debugValue);
                            
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Variable " + scope + ": " + name.trim() + " = " + value + " (" + type.trim() + ")");
                        } catch (Exception e) {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "ERROR: Failed to create variable entry for line: " + line + " - " + e.getMessage());
                            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
                        }
                    } else {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "WARNING: Malformed variable line (expected 3 parts, got " + parts.length + "): " + line);
                    }
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "ERROR: Exception processing variable line " + i + " for scope " + scope + ": " + e.getMessage());
                    HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
                    // Continue processing other lines despite this error
                }
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Finished processing variables for scope: " + scope + " (total variables: " + variables.size() + ")");
                
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "CRITICAL ERROR: Exception in handleVariables for scope " + scope + ": " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
            
            // Don't let variable processing errors crash the entire debug session
            // Continue with partial variable information
        }
    }

    private void handleEnd() {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session ended");
        stop();
    }

    private void handleError(String error) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug error: " + error);
    }

    private void requestVariables() {
        sendCommand("LOCALS", "0");
        sendCommand("STATICS", "0");
        sendCommand("PRIVATES", "0");
        sendCommand("PUBLICS");
    }
    private void sendBreakpointsAfterSessionReady() {
        // This method is called after session is properly initialized
        boolean globallyMuted = getSession().areBreakpointsMuted();
        
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "=== SENDING BREAKPOINTS AFTER SESSION READY ===");
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Global mute state: " + globallyMuted);
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Session initialized: " + sessionInitialized);
        
        // Save the mute state to settings for next run
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings != null) {
            settings.setLastKnownGlobalMuteState(globallyMuted);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Saved global mute state to settings: " + globallyMuted);
        }
        
        // ALWAYS send breakpoints via remote protocol (init.cld is now minimal)
        if (globallyMuted) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Breakpoints globally muted - NOT sending any breakpoints");
        } else {
            // Send all breakpoints registered with the handler
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Sending breakpoints via remote protocol (init.cld is minimal)");
            breakpointHandler.sendAllBreakpoints();
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Breakpoints sent, waiting for program to hit AltD()");
        }
        
        // Don't send GO automatically - wait for user to click Continue
        // The program will pause when it hits AltD() and send STOP
    }
    
    /**
     * Clear breakpoints that were set from init.cld file when globally muted
     */
    private void clearInitCldBreakpoints() {
        try {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "=== CLEAR INIT.CLD BREAKPOINTS START ===");
            
            // Get working directory from the project and other potential locations
            String currentDir = System.getProperty("user.dir");
            String projectDir = project.getBasePath();
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Current working directory: " + currentDir);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Project base path: " + projectDir);
            
            // Check multiple potential init.cld locations
            String[] initCldPaths = {
                currentDir + "/init.cld",
                projectDir + "/init.cld",
                currentDir + "/../init.cld",
                currentDir + "/../../init.cld"
            };
            
            int clearedCount = 0;
            boolean foundAnyFile = false;
            
            for (String initCldPath : initCldPaths) {
                File initCldFile = new File(initCldPath);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Checking init.cld at: " + initCldFile.getAbsolutePath() + " - exists: " + initCldFile.exists());
                
                if (initCldFile.exists()) {
                    foundAnyFile = true;
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "FOUND init.cld at: " + initCldFile.getAbsolutePath());
                    
                    try {
                        List<String> lines = java.nio.file.Files.readAllLines(initCldFile.toPath());
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Read " + lines.size() + " lines from init.cld");
                        
                        for (String line : lines) {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                    "Processing line: '" + line + "'");
                            
                            if (line.trim().startsWith("BP ") && line.contains(" ")) {
                                // Parse line format: "BP line filename"
                                String[] parts = line.trim().split(" ", 3);
                                if (parts.length >= 3) {
                                    String lineNum = parts[1];
                                    String fileName = parts[2];
                                    
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                            "Parsed BP: line=" + lineNum + ", file=" + fileName);
                                    
                                    // Send remove command
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                            "Sending BREAKPOINT command...");
                                    sendCommand("BREAKPOINT");
                                    
                                    String removeCmd = "-:" + fileName + ":" + lineNum;
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                            "Sending remove command: " + removeCmd);
                                    sendCommand(removeCmd);
                                    
                                    clearedCount++;
                                    
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                            "Successfully sent clear command for: " + fileName + ":" + lineNum);
                                }
                            }
                        }
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Error reading init.cld: " + e.getMessage());
                        e.printStackTrace();
                    }
                }
            }
            
            if (!foundAnyFile) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "WARNING: No init.cld files found in any checked location!");
            }
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "=== CLEAR SUMMARY: Found files=" + foundAnyFile + ", Cleared " + clearedCount + " breakpoints ===");
            
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                    "Error clearing init.cld breakpoints: " + e.getMessage());
            e.printStackTrace();
        }
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
        String normalizedFileName = HarbourFileUtils.normalizePathSeparators(fileName);
        for (VirtualFile file : sourceFiles) {
            String normalizedFilePath = HarbourFileUtils.normalizePathSeparators(file.getPath());
            if (file.getName().equals(fileName) || 
                normalizedFilePath.endsWith(fileName) ||
                normalizedFilePath.endsWith(normalizedFileName)) {
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
    
    /**
     * Crash recovery mechanism to restart debug server after PyCharm crashes
     */
    private void initiateCrashRecovery() {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Initiating crash recovery sequence");
        
        try {
            // Close existing connection cleanly
            if (connection != null) {
                try {
                    connection.close();
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Error closing connection during crash recovery: " + e.getMessage());
                }
            }


            // Reset debug state
            conditionalBreakpointFile = null;
            conditionalBreakpointLine = -1;
            debuggerState = DebuggerState.DISCONNECTED;
            isConnected = false;
            
            // Stop live DBF monitoring
            liveDBFConnection.stopMonitoring();
            
            // Clear variables to prevent stale data
            variables.clear();
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug state reset for crash recovery");
            
            // Schedule restart with delay to allow cleanup
            ApplicationManager.getApplication().executeOnPooledThread(() -> {
                try {
                    Thread.sleep(2000); // Wait 2 seconds for cleanup
                    
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Attempting to restart debug server connection");
                    
                    // Since connection is final, we'll try to restart the existing connection
                    // First close it cleanly, then restart it
                    try {
                        boolean started = connection.start(this::handleDebugMessage);
                        if (started) {
                            isConnected = true;
                            debuggerState = DebuggerState.RUNNING;
                            connectionStartTime = System.currentTimeMillis();
                            
                            // Start live DBF monitoring
                            liveDBFConnection.startMonitoring();
                            
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Debug server successfully restarted after crash recovery");
                            
                            // Send initial setup commands - but only if session is ready
                            if (sessionInitialized) {
                                sendBreakpointsAfterSessionReady();
                            }
                            
                            // Notify user about successful recovery
                            ApplicationManager.getApplication().invokeLater(() -> {
                                try {
                                    ConsoleView console = (ConsoleView) executionResult.getExecutionConsole();
                                    if (console != null) {
                                        console.print("Debug server recovered and restarted successfully.\n", 
                                            ConsoleViewContentType.SYSTEM_OUTPUT);
                                    }
                                } catch (Exception e) {
                                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                        "Error notifying user about recovery: " + e.getMessage());
                                }
                            });
                            
                        } else {
                            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                                "Failed to restart debug server during crash recovery");
                        }
                    } catch (Exception e) {
                        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                            "Exception during debug server restart: " + e.getMessage());
                        HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
                    }
                    
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", "Crash recovery interrupted");
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                        "Unexpected error during crash recovery: " + e.getMessage());
                    HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
                }
            });
            
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "CRITICAL ERROR: Exception in crash recovery initiation: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerRemoteProcess", e);
        }
    }
    
    /**
     * Check if the debug session appears to have crashed and needs recovery
     */
    private boolean isSessionCrashed() {
        try {
            // Check if we lost connection unexpectedly
            if (connection != null && !connection.isConnected() && isConnected) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Connection lost detected");
                return true;
            }
            
            // Check if the debug session is null (IDE disconnected)
            if (getSession() == null && isConnected) {
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Debug session is null - IDE may have disconnected");
                return true;
            }
            
            return false;
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Error checking session crash status: " + e.getMessage());
            // If we can't check, assume we need recovery
            return true;
        }
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

        // Increment step generation to abort any pending variable waits
        stepGeneration++;
        abortVariableWait = true;

        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);

        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing NEXT command (state: STEPPING, pendingStep=true, gen=" + stepGeneration + ")");
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

        // Increment step generation to abort any pending variable waits
        stepGeneration++;
        abortVariableWait = true;

        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);

        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing STEP command (state: STEPPING, pendingStep=true, gen=" + stepGeneration + ")");
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

        // Increment step generation to abort any pending variable waits
        stepGeneration++;
        abortVariableWait = true;

        // Mark that we have a pending step command to prevent rapid clicking
        updateDebuggerState(DebuggerState.STEPPING, true);

        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing OUT command (state: STEPPING, pendingStep=true, gen=" + stepGeneration + ")");
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
     * Pause execution at the current point without requiring a breakpoint.
     * Sends a PAUSE command to the Harbour process which will stop at the next line execution.
     */
    public void pause() {
        if (!isConnected) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring PAUSE command - not connected");
            return;
        }

        // Can only pause when running
        if (debuggerState != DebuggerState.RUNNING) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Ignoring PAUSE command - debugger state is " + debuggerState);
            return;
        }

        HarbourLogger.log("HarbourDebuggerRemoteProcess", "Executing PAUSE command");
        try {
            commandQueue.offer(new DebugCommand("PAUSE"), 500, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "Failed to queue PAUSE command");
        }
    }

    /**
     * Get the current debugger state
     * @return the current DebuggerState
     */
    public DebuggerState getDebuggerState() {
        return debuggerState;
    }

    /**
     * Quick check if a breakpoint at file:line has any condition or hit condition.
     */
    private boolean hasConditionalBreakpoint(String file, int line) {
        if (breakpointHandler == null) return false;
        for (var bp : breakpointHandler.getRegisteredBreakpoints()) {
            if (bp.getSourcePosition() != null) {
                String bpFile = bp.getSourcePosition().getFile().getName();
                int bpLine = bp.getSourcePosition().getLine() + 1;
                if (bpFile.equalsIgnoreCase(file) && bpLine == line) {
                    HarbourDebuggerBreakpointProperties props =
                        bp.getProperties();
                    if (props != null &&
                            (props.hasCondition() ||
                             props.hasHitCondition())) {
                        return true;
                    }
                }
            }
        }
        // Also check with path-stripped filename
        String stripped = file;
        int idx = Math.max(stripped.lastIndexOf('/'),
                           stripped.lastIndexOf('\\'));
        if (idx >= 0) stripped = stripped.substring(idx + 1);
        if (!stripped.equals(file)) {
            return hasConditionalBreakpoint(stripped, line);
        }
        return false;
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
            } else if (condition.contains("=")) {
                // Single = is Harbour's equality operator (checked last
                // after ==, !=, >=, <= which all contain =)
                String[] parts = condition.split("=", 2);
                if (parts.length == 2) {
                    String varName = parts[0].trim();
                    String expectedValue = parts[1].trim();
                    HarbourLogger.log(project, "HarbourDebugger",
                        "EVAL DEBUG: Single '=' operator: '" +
                        varName + "' = '" + expectedValue + "'");
                    return evaluateComparison(
                        varName, expectedValue, "==");
                }
            }

            HarbourLogger.log(project, "HarbourDebugger",
                "Unsupported condition format: " + condition +
                " - defaulting to true");
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
        
        // Stop live DBF monitoring
        liveDBFConnection.stopMonitoring();
        
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
    
    /**
     * Check if the debugger is ready to accept breakpoint commands
     * Breakpoints can be sent anytime when connected, regardless of state
     */
    public boolean canAcceptBreakpoints() {
        return isConnected && connection != null && connection.isConnected();
    }
    
    /**
     * TEST METHOD: Generate a realistic Harbour debugging error for console logging verification
     * This simulates common debugging errors that could occur during real debugging sessions
     */
    public void generateTestHarbourError() {
        try {
            HarbourLogger.log(project, "HarbourDebugger", "=== TESTING HARBOUR ERROR LOGGING ===");
            
            // Simulate a common debugging error: file not found during source resolution
            String testFileName = "NonExistentHarbourFile.prg";
            Path testPath = Paths.get("/invalid/path/to/" + testFileName);
            
            HarbourLogger.log(project, "HarbourDebugger", "Attempting to resolve source file: " + testPath);
            
            // This will throw a realistic exception that could occur during debugging
            List<String> lines = Files.readAllLines(testPath);
            
            // This code should never be reached
            HarbourLogger.log(project, "HarbourDebugger", "Unexpectedly succeeded reading file: " + lines.size() + " lines");
            
        } catch (IOException e) {
            // This is a realistic error that could occur during Harbour debugging
            HarbourLogger.log(project, "HarbourDebugger", "ERROR: Failed to read Harbour source file during debugging");
            HarbourLogger.log(project, "HarbourDebugger", "Error details: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebugger", e);
            
        } catch (Exception e) {
            // Any other unexpected errors
            HarbourLogger.log(project, "HarbourDebugger", "UNEXPECTED ERROR during Harbour debugging operation");
            HarbourLogger.log(project, "HarbourDebugger", "Error details: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebugger", e);
            
        } finally {
            HarbourLogger.log(project, "HarbourDebugger", "=== HARBOUR ERROR LOGGING TEST COMPLETED ===");
        }
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
     * Handle tracepoint hit notification from the Harbour debugger.
     * Format: TRACEPOINT_HIT:variableName:oldValue:newValue
     */
    private void handleTracepointHit(String command) {
        // Parse the tracepoint hit message
        // Format: TRACEPOINT_HIT:variableName:oldValue:newValue
        String[] parts = command.split(":", 4);
        if (parts.length >= 4) {
            String variableName = parts[1];
            String oldValue = parts[2];
            String newValue = parts[3];

            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Tracepoint hit: " + variableName + " changed from '" + oldValue + "' to '" + newValue + "'");

            // Update the tracepoint manager
            if (tracepointManager != null) {
                tracepointManager.handleTracepointHit(variableName, oldValue, newValue);
            }

            // Note: Tracepoint notification is logged but not printed to console to reduce noise

            // The debugger is already stopped at this point (STOP message should follow)
            // The variables panel will show the changed value
        } else {
            HarbourLogger.warning("HarbourDebuggerRemoteProcess",
                "Invalid TRACEPOINT_HIT format: " + command);
        }
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
     * Handle runtime error messages from global error handler
     */
    private void handleErrorMessage(String errorMessage) {
        ApplicationManager.getApplication().invokeLater(() -> {
            ExecutionConsole console = getSession().getConsoleView();
            if (console instanceof ConsoleView) {
                ConsoleView consoleView = (ConsoleView) console;
                // Display error with ERROR formatting (red text) - no duplicate logging
                consoleView.print(errorMessage + "\n", ConsoleViewContentType.ERROR_OUTPUT);
                // REMOVED: HarbourLogger.error() to prevent Java stack traces in console
            }
        });
    }
    
    /**
     * Handle stack trace lines from global error handler with clickable file references
     */
    private void handleErrorStackTrace(String stackLine) {
        ApplicationManager.getApplication().invokeLater(() -> {
            ExecutionConsole console = getSession().getConsoleView();
            if (console instanceof ConsoleView) {
                ConsoleView consoleView = (ConsoleView) console;
                // Display stack trace line - CompilerOutputFilter will make file references clickable
                consoleView.print(stackLine + "\n", ConsoleViewContentType.ERROR_OUTPUT);
                HarbourLogger.log("HarbourDebuggerRemoteProcess", "Stack trace: " + stackLine);
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
                // Wait for a command with timeout - ultra-minimal for maximum speed
                DebugCommand cmd = commandQueue.poll(1, TimeUnit.MILLISECONDS);
                
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
                
                // Calculate required delay - optimize for step commands
                long now = System.currentTimeMillis();
                long timeSinceLastCommand = now - lastExecutionTime;
                long requiredDelay = MIN_COMMAND_INTERVAL;
                
                // Check if this is a step command (NEXT, STEP, OUT)
                boolean isStepCommand = "NEXT".equals(cmd.command) || 
                                       "STEP".equals(cmd.command) || 
                                       "OUT".equals(cmd.command);
                
                // Only apply extra delay for consecutive NEXT commands
                if ("NEXT".equals(cmd.command) && "NEXT".equals(lastCommand)) {
                    requiredDelay = NEXT_COMMAND_DELAY;
                }
                
                // Skip ALL throttling for step commands - maximum speed
                if (isStepCommand) {
                    requiredDelay = 0; // ZERO delay for step commands
                }
                
                // Apply throttling only for non-step commands if needed
                if (requiredDelay > 0 && timeSinceLastCommand < requiredDelay) {
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
     * Get the live DBF connection for external access
     */
    @NotNull
    public HarbourLiveDBFConnection getLiveDBFConnection() {
        return liveDBFConnection;
    }

    /**
     * Get the tracepoint manager for data breakpoints (watch variable changes)
     */
    @Nullable
    public HarbourTracepointManager getTracepointManager() {
        return tracepointManager;
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
            
            // Stop live DBF monitoring
            liveDBFConnection.stopMonitoring();
            
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
    
    /**
     * Request array elements for a specific array variable
     * @param scope The variable scope (LOCALS, STATICS, etc.)
     * @param arrayName The name of the array variable
     * @param start The starting index (1-based)
     * @param count The number of elements to retrieve
     */
    public void requestArrayElements(String scope, String arrayName, int start, int count) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess",
            "Requesting array elements for " + scope + "." + arrayName + " [" + start + ".." + (start+count-1) + "]");

        // Send command to debugger to get array elements
        // Format: ARRAY:scope:name:start:count
        sendCommand("ARRAY", scope + ":" + arrayName + ":" + start + ":" + count);
    }

    // Pending future for synchronous array element requests
    private volatile CompletableFuture<Boolean> pendingArrayLoadFuture = null;
    private volatile String pendingArrayLoadKey = null;

    /**
     * Synchronously request array elements for a variable and wait for them.
     * Used by the evaluator to resolve expressions like "Logins[1]".
     * @param arrayValue The HarbourDebuggerValue representing the array
     * @return The loaded children list, or empty list on failure
     */
    public java.util.List<HarbourDebuggerValue> requestArrayElementsSync(
            HarbourDebuggerValue arrayValue) {
        String scope = null;
        String arrayName = null;
        int arraySize = 0;

        // Extract scope and array name from the value's stored info
        // We need to find this value in our variables map to get the key
        for (var entry : variables.entrySet()) {
            if (entry.getValue() == arrayValue) {
                String key = entry.getKey();
                int dotIndex = key.indexOf('.');
                if (dotIndex > 0) {
                    scope = key.substring(0, dotIndex);
                    arrayName = key.substring(dotIndex + 1);
                }
                break;
            }
        }

        // Fallback: check children of other variables (nested arrays)
        if (scope == null) {
            for (var entry : variables.entrySet()) {
                HarbourDebuggerValue parent = entry.getValue();
                if (parent.getChildren() != null) {
                    for (HarbourDebuggerValue child : parent.getChildren()) {
                        if (child == arrayValue) {
                            String key = entry.getKey();
                            int dotIndex = key.indexOf('.');
                            if (dotIndex > 0) {
                                scope = key.substring(0, dotIndex);
                                // For nested array, build path
                                String parentName = key.substring(dotIndex + 1);
                                int childIdx = parent.getChildren().indexOf(child) + 1;
                                arrayName = parentName + "[" + childIdx + "]";
                            }
                            break;
                        }
                    }
                }
                if (scope != null) break;
            }
        }

        if (scope == null || arrayName == null) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Cannot determine scope/name for array sync request");
            return java.util.Collections.emptyList();
        }

        // Parse array size from value string like "Array(5)"
        String valueStr = arrayValue.getValue();
        if (valueStr != null && valueStr.startsWith("Array(") &&
                valueStr.endsWith(")")) {
            try {
                arraySize = Integer.parseInt(
                    valueStr.substring(6, valueStr.length() - 1));
            } catch (NumberFormatException e) {
                arraySize = 100;
            }
        } else {
            arraySize = 100;
        }

        String arrayKey = scope + "." + arrayName;
        HarbourLogger.log("HarbourDebuggerRemoteProcess",
            "Synchronous array request for " + arrayKey +
            " (size=" + arraySize + ")");

        // Set up future before sending command
        pendingArrayLoadKey = arrayKey;
        pendingArrayLoadFuture = new CompletableFuture<>();

        // Send the request
        int maxElements = Math.min(arraySize, 100);
        sendCommand("ARRAY", scope + ":" + arrayName + ":" + 1 + ":" + maxElements);

        // Wait for response
        try {
            pendingArrayLoadFuture.get(5, TimeUnit.SECONDS);
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                "Sync array request timed out or failed for " + arrayKey +
                ": " + e.getMessage());
        } finally {
            pendingArrayLoadFuture = null;
            pendingArrayLoadKey = null;
        }

        // Return children (may have been populated by handleArrayElements)
        java.util.List<HarbourDebuggerValue> children = arrayValue.getChildren();
        return children != null ? children : java.util.Collections.emptyList();
    }

    /**
     * Request hash elements for a specific hash variable
     * @param scope The variable scope (LOCALS, STATICS, etc.)
     * @param hashName The name of the hash variable
     */
    public void requestHashElements(String scope, String hashName) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Requesting hash elements for " + scope + "." + hashName);
        
        // Send command to debugger to get hash key-value pairs
        // Format: HASH:scope:name
        sendCommand("HASH", scope + ":" + hashName);
    }
    
    /**
     * Request object properties for a specific object variable
     * @param scope The variable scope (LOCALS, STATICS, etc.)
     * @param objectName The name of the object variable
     */
    public void requestObjectProperties(String scope, String objectName) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Requesting object properties for " + scope + "." + objectName);
        
        // Send command to debugger to get object properties
        // Format: OBJECT:scope:name
        sendCommand("OBJECT", scope + ":" + objectName);
    }
    
    // Store pending expression evaluations
    private final Map<String, CompletableFuture<String>> pendingExpressions = new ConcurrentHashMap<>();
    private String lastExpressionCommand = null;
    
    public String requestExpression(String command) {
        lastExpressionCommand = command;
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Requesting expression evaluation: " + command);
        
        // Create a future to wait for the result
        CompletableFuture<String> future = new CompletableFuture<>();
        pendingExpressions.put(command, future);
        
        // Send command to debugger
        sendCommand("EVAL", command);
        
        try {
            // Wait for response with timeout
            return future.get(5, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Expression evaluation timed out: " + command);
            pendingExpressions.remove(command);
            return "Evaluation timed out";
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Expression evaluation failed: " + e.getMessage());
            pendingExpressions.remove(command);
            return "Evaluation failed: " + e.getMessage();
        }
    }
    
    private void handleExpressionResult(String response) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", 
            "Received expression result: " + response);
        
        // Parse EXPRESSION:stack_level:type:value
        String[] parts = response.split(":", 4);
        if (parts.length >= 4) {
            String stackLevel = parts[1];
            String type = parts[2];
            String value = parts[3];
            
            // Format the result based on type
            String result;
            if ("E".equals(type)) {
                // Error
                result = "Error: " + value;
            } else {
                // Success - format based on type
                result = value;
                if ("C".equals(type)) {
                    // String - already quoted by FormatValue
                } else if ("N".equals(type)) {
                    // Number
                } else if ("L".equals(type)) {
                    // Logical
                } else if ("A".equals(type)) {
                    // Array
                } else if ("H".equals(type)) {
                    // Hash
                } else if ("O".equals(type)) {
                    // Object
                } else if ("U".equals(type)) {
                    // NIL
                }
            }
            
            // Complete any pending future for this expression
            if (lastExpressionCommand != null) {
                CompletableFuture<String> future = pendingExpressions.remove(lastExpressionCommand);
                if (future != null) {
                    future.complete(result);
                }
                lastExpressionCommand = null;
            }
            
            // Also complete any futures that might match (in case of multiple evaluations)
            for (Map.Entry<String, CompletableFuture<String>> entry : pendingExpressions.entrySet()) {
                entry.getValue().complete(result);
            }
            pendingExpressions.clear();
        } else {
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                "Invalid expression result format: " + response);
        }
    }
}
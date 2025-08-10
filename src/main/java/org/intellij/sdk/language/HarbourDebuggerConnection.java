package org.intellij.sdk.language;


import java.io.*;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

/**
 * Handles TCP communication with the Harbour debug process.
 * Implements the same protocol as the VSCode extension.
 */
public class HarbourDebuggerConnection {
    private static final int DEFAULT_PORT = 6110;
    private static final int ACCEPT_TIMEOUT = 60000; // 60 seconds
    private static final String CRLF = "\r\n";
    
    private final int port;
    private ServerSocket serverSocket;
    private Socket clientSocket;
    private BufferedReader reader;
    private PrintWriter writer;
    private Thread messageThread;
    private volatile boolean connected = false;
    private volatile boolean waitingForConnection = false;
    private final BlockingQueue<String> commandQueue = new LinkedBlockingQueue<>();
    private Consumer<String> messageHandler;
    
    public HarbourDebuggerConnection(int port) {
        this.port = port > 0 ? port : DEFAULT_PORT;
        HarbourLogger.log("HarbourDebuggerConnection", "Created debugger connection on port " + this.port);
    }
    
    /**
     * Start listening on the debug port without accepting connections yet
     * This allows us to ensure the server is ready before Harbour program execution
     */
    public boolean startListening() throws IOException {
        try {
            HarbourLogger.log("HarbourDebuggerConnection", "=== STARTING PYCHARM DEBUG SERVER v1.0.260 ===");
            HarbourLogger.log("HarbourDebuggerConnection", "Starting to listen on port " + port);
            
            // Aggressive port cleanup before binding
            if (!isPortAvailable(port)) {
                HarbourLogger.log("HarbourDebuggerConnection", "Port " + port + " is in use, attempting to free it");
                forceReleasePort(port);
                
                // Wait a moment for port to be released
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                
                // Check again
                if (!isPortAvailable(port)) {
                    HarbourLogger.log("HarbourDebuggerConnection", "WARNING: Port " + port + " still appears to be in use");
                }
            }
            
            serverSocket = new ServerSocket(port);
            serverSocket.setReuseAddress(true); // Allow quick restart
            serverSocket.setSoTimeout(ACCEPT_TIMEOUT);
            
            HarbourLogger.log("HarbourDebuggerConnection", "✅ Server socket created and listening on port " + port);
            HarbourLogger.log("HarbourDebuggerConnection", "Server socket address: " + serverSocket.getInetAddress() + ":" + serverSocket.getLocalPort());
            
            return true;
            
        } catch (IOException e) {
            HarbourLogger.log("HarbourDebuggerConnection", "❌ Failed to start listening on port " + port + ": " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerConnection", e);
            throw e;
        }
    }
    
    /**
     * Accept a connection from the debug client (blocking operation)
     */
    public boolean acceptConnection(Consumer<String> messageHandler) throws IOException {
        this.messageHandler = messageHandler;
        
        if (serverSocket == null || serverSocket.isClosed()) {
            HarbourLogger.log("HarbourDebuggerConnection", "❌ Server socket not available for accepting connections");
            return false;
        }
        
        try {
            HarbourLogger.log("HarbourDebuggerConnection", "Waiting for debug client connection on port " + port + "...");
            
            waitingForConnection = true;
            
            // Accept connection with proper timeout handling
            try {
                clientSocket = serverSocket.accept();
                waitingForConnection = false;
                HarbourLogger.log("HarbourDebuggerConnection", "✅ Client connection accepted successfully");
            } catch (SocketTimeoutException e) {
                waitingForConnection = false;
                throw e; // Re-throw to be handled by outer catch block
            }
            
            // Setup streams
            reader = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            writer = new PrintWriter(new OutputStreamWriter(clientSocket.getOutputStream()), true);
            
            connected = true;
            HarbourLogger.log("HarbourDebuggerConnection", "Debug client connected from " + clientSocket.getInetAddress());
            
            // Start message reading thread
            startMessageThread();
            
            // Read handshake directly (executable name and PID)
            // We need to read two lines: executable name and PID
            String executableName = reader.readLine();
            String pid = reader.readLine();
            
            if (executableName != null && pid != null) {
                HarbourLogger.log("HarbourDebuggerConnection", "Received handshake - Executable: " + executableName + ", PID: " + pid);
                
                // Send HELLO response to complete handshake
                sendCommand("HELLO");
                HarbourLogger.log("HarbourDebuggerConnection", "Sent HELLO response");
                
                // Store handshake info if needed
                if (messageHandler != null) {
                    messageHandler.accept(executableName + CRLF + pid);
                }
                
                return true;
            }
            
        } catch (SocketTimeoutException e) {
            HarbourLogger.log("HarbourDebuggerConnection", "Timeout waiting for debug client connection");
            close();
        } catch (IOException e) {
            waitingForConnection = false;
            if (e.getMessage() != null && e.getMessage().contains("Socket closed")) {
                HarbourLogger.log("HarbourDebuggerConnection", "Server socket was closed externally - likely debug session ended or stopped by user");
                // Don't rethrow if socket was intentionally closed
                return false;
            }
            HarbourLogger.log("HarbourDebuggerConnection", "Error accepting connection: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerConnection", e);
            close();
            // Don't rethrow the exception - just return false to indicate failure
            return false;
        }
        
        return false;
    }
    
    /**
     * Start the debug server and wait for client connection (DEPRECATED - use startListening + acceptConnection)
     */
    public boolean start(Consumer<String> messageHandler) throws IOException {
        this.messageHandler = messageHandler;
        
        try {
            HarbourLogger.log("HarbourDebuggerConnection", "Starting debug server on port " + port);
            
            // Aggressive port cleanup before binding
            if (!isPortAvailable(port)) {
                HarbourLogger.log("HarbourDebuggerConnection", "Port " + port + " is in use, attempting to free it");
                forceReleasePort(port);
                
                // Wait a moment for port to be released
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
                
                // Check again
                if (!isPortAvailable(port)) {
                    HarbourLogger.log("HarbourDebuggerConnection", "WARNING: Port " + port + " still appears to be in use");
                }
            }
            
            serverSocket = new ServerSocket(port);
            serverSocket.setReuseAddress(true); // Allow quick restart
            serverSocket.setSoTimeout(ACCEPT_TIMEOUT);
            
            // Wait for connection from Harbour process
            HarbourLogger.log("HarbourDebuggerConnection", "Waiting for debug client connection on port " + port + "...");
            HarbourLogger.log("HarbourDebuggerConnection", "Server socket listening on: " + serverSocket.getInetAddress() + ":" + serverSocket.getLocalPort());
            
            waitingForConnection = true;
            
            // Check if socket is still open before accepting
            if (serverSocket.isClosed()) {
                HarbourLogger.log("HarbourDebuggerConnection", "Server socket was closed before accept()");
                waitingForConnection = false;
                return false;
            }
            
            // Accept connection with proper timeout handling
            try {
                clientSocket = serverSocket.accept();
                waitingForConnection = false;
                HarbourLogger.log("HarbourDebuggerConnection", "Client connection accepted successfully");
            } catch (SocketTimeoutException e) {
                waitingForConnection = false;
                throw e; // Re-throw to be handled by outer catch block
            }
            
            // Setup streams
            reader = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            writer = new PrintWriter(new OutputStreamWriter(clientSocket.getOutputStream()), true);
            
            connected = true;
            HarbourLogger.log("HarbourDebuggerConnection", "Debug client connected from " + clientSocket.getInetAddress());
            
            // Start message reading thread
            startMessageThread();
            
            // Read handshake directly (executable name and PID)
            // We need to read two lines: executable name and PID
            String executableName = reader.readLine();
            String pid = reader.readLine();
            
            if (executableName != null && pid != null) {
                HarbourLogger.log("HarbourDebuggerConnection", "Received handshake - Executable: " + executableName + ", PID: " + pid);
                
                // Send HELLO response to complete handshake
                sendCommand("HELLO");
                HarbourLogger.log("HarbourDebuggerConnection", "Sent HELLO response");
                
                // Store handshake info if needed
                if (messageHandler != null) {
                    messageHandler.accept(executableName + CRLF + pid);
                }
                
                return true;
            }
            
        } catch (SocketTimeoutException e) {
            HarbourLogger.log("HarbourDebuggerConnection", "Timeout waiting for debug client connection");
            close();
        } catch (IOException e) {
            waitingForConnection = false;
            if (e.getMessage() != null && e.getMessage().contains("Socket closed")) {
                HarbourLogger.log("HarbourDebuggerConnection", "Server socket was closed externally - likely debug session ended or stopped by user");
                // Don't rethrow if socket was intentionally closed
                return false;
            }
            HarbourLogger.log("HarbourDebuggerConnection", "Error starting debug server: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerConnection", e);
            close();
            // Don't rethrow the exception - just return false to indicate failure
            return false;
        }
        
        return false;
    }
    
    /**
     * Send a command to the debug client
     */
    public void sendCommand(String command) {
        HarbourLogger.log("HarbourDebuggerConnection", "sendCommand() called with: " + command);
        
        if (!connected || writer == null) {
            HarbourLogger.log("HarbourDebuggerConnection", "Cannot send command - not connected (connected=" + connected + ", writer=" + (writer != null ? "not null" : "null") + ")");
            return;
        }
        
        HarbourLogger.log("HarbourDebuggerConnection", "About to send command: " + command);
        
        try {
            HarbourLogger.log("HarbourDebuggerConnection", "Calling writer.print()...");
            writer.print(command + CRLF);
            
            HarbourLogger.log("HarbourDebuggerConnection", "Calling writer.flush()...");
            writer.flush();
            
            HarbourLogger.log("HarbourDebuggerConnection", "Command sent successfully: " + command);
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerConnection", "Error sending command '" + command + "': " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerConnection", e);
        }
    }
    
    /**
     * Send a command with parameters
     */
    public void sendCommand(String command, String... params) {
        HarbourLogger.log("HarbourDebuggerConnection", "sendCommand() called with command: " + command + ", params: " + java.util.Arrays.toString(params));
        
        if (!connected || writer == null) {
            HarbourLogger.log("HarbourDebuggerConnection", "Cannot send command with params - not connected");
            return;
        }
        
        // Try unified approach for all commands including breakpoints
        StringBuilder cmd = new StringBuilder(command);
        for (String param : params) {
            cmd.append(":").append(param);
        }
        HarbourLogger.log("HarbourDebuggerConnection", "Sending unified command: " + cmd);
        sendCommand(cmd.toString());
    }
    
    
    /**
     * Start the message reading thread
     */
    private void startMessageThread() {
        messageThread = new Thread(() -> {
            HarbourLogger.log("HarbourDebuggerConnection", "Message thread started");
            StringBuilder messageBuilder = new StringBuilder();
            
            try {
                String line;
                while (connected && (line = reader.readLine()) != null) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Received line: " + line);
                    
                    // Check if this is a command start
                    if (isCommand(line)) {
                        // If we have a pending message, process it
                        if (!messageBuilder.isEmpty()) {
                            processMessage(messageBuilder.toString());
                            messageBuilder.setLength(0);
                        }
                        
                        // For single-line commands like "STOP:file:line", process immediately
                        if (line.contains(":")) {
                            processMessage(line);
                        } else {
                            // Start new multi-line message
                            messageBuilder.append(line);
                        }
                    } else {
                        // Continue building message
                        if (!messageBuilder.isEmpty()) {
                            messageBuilder.append(CRLF);
                        }
                        messageBuilder.append(line);
                    }
                }
            } catch (IOException e) {
                if (connected) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Error reading from debug client: " + e.getMessage());
                }
            } finally {
                // Process any remaining message
                if (!messageBuilder.isEmpty()) {
                    processMessage(messageBuilder.toString());
                }
                HarbourLogger.log("HarbourDebuggerConnection", "Message thread ending");
                close();
            }
        }, "Harbour-Debug-Reader");
        
        messageThread.setDaemon(true);
        messageThread.start();
    }
    
    /**
     * Check if a line starts a new command
     */
    private boolean isCommand(String line) {
        // Commands from the Harbour side
        return line.equals("STOP") || line.startsWith("STOP:") ||
               line.equals("STACK") || line.equals("BREAK") || line.startsWith("BREAK:") ||
               line.equals("ERROR") || line.equals("LOG") || line.equals("END") ||
               line.equals("ACTIVATED") || line.equals("LOCALS") || line.equals("STATICS") ||
               line.equals("PRIVATES") || line.equals("PUBLICS") || line.equals("AREAS") ||
               line.startsWith("ARRAY:") || line.startsWith("OBJECT:") ||
               line.startsWith("CONSOLE:") || // Add console output recognition
               line.equals("END_LOCALS") || line.equals("END_STATICS") || 
               line.equals("END_PRIVATES") || line.equals("END_PUBLICS") ||
               (line.length() == 1 && Character.isUpperCase(line.charAt(0))); // Type responses
    }
    
    /**
     * Process a complete message
     */
    private void processMessage(String message) {
        HarbourLogger.log("HarbourDebuggerConnection", "Processing message: " + message);
        
        // Add to command queue for synchronous processing
        try {
            commandQueue.put(message);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        // Also notify async handler if set
        if (messageHandler != null) {
            messageHandler.accept(message);
        }
    }
    
    /**
     * Close the connection
     */
    public void close() {
        HarbourLogger.log("HarbourDebuggerConnection", "Closing debug connection (waitingForConnection=" + waitingForConnection + ")");
        connected = false;
        waitingForConnection = false;
        
        // Close resources in reverse order of creation for proper cleanup
        try {
            // First interrupt the message thread to stop any blocking operations
            if (messageThread != null && messageThread.isAlive()) {
                HarbourLogger.log("HarbourDebuggerConnection", "Interrupting message thread");
                messageThread.interrupt();
                try {
                    // Wait briefly for thread to terminate gracefully
                    messageThread.join(1000);
                    if (messageThread.isAlive()) {
                        HarbourLogger.log("HarbourDebuggerConnection", "Message thread did not terminate gracefully");
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            
            // Close streams first
            if (writer != null) {
                try {
                    writer.close();
                    HarbourLogger.log("HarbourDebuggerConnection", "Writer closed");
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Error closing writer: " + e.getMessage());
                }
                writer = null;
            }
            
            if (reader != null) {
                try {
                    reader.close();
                    HarbourLogger.log("HarbourDebuggerConnection", "Reader closed");
                } catch (IOException e) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Error closing reader: " + e.getMessage());
                }
                reader = null;
            }
            
            // Close client socket
            if (clientSocket != null && !clientSocket.isClosed()) {
                try {
                    clientSocket.close();
                    HarbourLogger.log("HarbourDebuggerConnection", "Client socket closed");
                } catch (IOException e) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Error closing client socket: " + e.getMessage());
                }
                clientSocket = null;
            }
            
            // Close server socket - most important for port cleanup
            if (serverSocket != null && !serverSocket.isClosed()) {
                try {
                    // Force close immediately to release port
                    serverSocket.close();
                    HarbourLogger.log("HarbourDebuggerConnection", "Server socket closed and port " + port + " released");
                } catch (IOException e) {
                    HarbourLogger.log("HarbourDebuggerConnection", "Error closing server socket: " + e.getMessage());
                }
                serverSocket = null;
            }
            
            // Clear command queue to prevent memory leaks
            commandQueue.clear();
            HarbourLogger.log("HarbourDebuggerConnection", "Command queue cleared");
            
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerConnection", "Unexpected error during cleanup: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourDebuggerConnection", e);
        }
        
        HarbourLogger.log("HarbourDebuggerConnection", "Connection cleanup completed");
    }
    
    public boolean isConnected() {
        return connected;
    }
    
    /**
     * Check if a port is available for binding
     */
    private boolean isPortAvailable(int port) {
        try (java.net.ServerSocket socket = new java.net.ServerSocket(port)) {
            socket.setReuseAddress(true);
            return true;
        } catch (IOException e) {
            return false;
        }
    }
    
    /**
     * Force release of a port by killing processes using it
     */
    private void forceReleasePort(int port) {
        try {
            String os = System.getProperty("os.name").toLowerCase();
            ProcessBuilder pb;
            
            if (os.contains("windows")) {
                // Windows: netstat and taskkill
                pb = new ProcessBuilder("cmd", "/c", 
                    "for /f \"tokens=5\" %a in ('netstat -ano ^| findstr :" + port + "') do taskkill /f /pid %a");
            } else {
                // Linux/Unix: lsof and kill
                pb = new ProcessBuilder("bash", "-c", 
                    "lsof -ti:" + port + " | xargs -r kill -9");
            }
            
            Process process = pb.start();
            boolean finished = process.waitFor(3, java.util.concurrent.TimeUnit.SECONDS);
            
            if (finished) {
                int exitCode = process.exitValue();
                HarbourLogger.log("HarbourDebuggerConnection", 
                    "Port cleanup command finished with exit code: " + exitCode);
            } else {
                HarbourLogger.log("HarbourDebuggerConnection", 
                    "Port cleanup command timed out");
                process.destroyForcibly();
            }
            
        } catch (Exception e) {
            HarbourLogger.log("HarbourDebuggerConnection", 
                "Error during port cleanup: " + e.getMessage());
        }
    }
    
}
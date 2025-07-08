package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.util.SystemInfo;
import org.jetbrains.annotations.NotNull;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Forces the debug server to start regardless of runner calls.
 * This is a diagnostic tool to isolate the issue.
 */
public class HarbourDebugServerForcer implements StartupActivity {
    
    @Override
    public void runActivity(@NotNull Project project) {
        System.out.println("🚀 HarbourDebugServerForcer v1.0.268 - FORCING DEBUG SERVER START");
        System.out.println("🚀 OS: " + SystemInfo.getOsNameAndVersion());
        System.out.println("🚀 Project: " + project.getName());
        
        // Log to file
        try {
            FileWriter fw = new FileWriter("harbour_debug_server_forcer.txt", true);
            fw.write("HarbourDebugServerForcer startup at " + LocalDateTime.now() + "\n");
            fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
            fw.write("Project: " + project.getName() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            System.err.println("Failed to write debug server forcer log: " + e.getMessage());
        }
        
        // Force create a debug connection on port 9876
        try {
            System.out.println("🚀 Creating forced debug connection on port 9876...");
            HarbourDebuggerConnection forcedConnection = new HarbourDebuggerConnection(9876);
            
            // Start the server
            boolean serverStarted = forcedConnection.startListening();
            System.out.println("🚀 Forced debug server started: " + serverStarted);
            
            // Log success
            try {
                FileWriter fw = new FileWriter("harbour_forced_debug_server.txt", true);
                fw.write("Forced debug server started at " + LocalDateTime.now() + "\n");
                fw.write("Server started: " + serverStarted + "\n");
                fw.write("Port: 9876\n");
                fw.write("---\n");
                fw.close();
            } catch (IOException e) {
                System.err.println("Failed to write forced debug server log: " + e.getMessage());
            }
            
            // Keep the connection alive in a separate thread
            Thread serverThread = new Thread(() -> {
                try {
                    System.out.println("🚀 Starting server accept loop...");
                    forcedConnection.acceptConnection(message -> {
                        System.out.println("🚀 Received debug message: " + message);
                        // Log messages from Harbour debug client
                        try {
                            FileWriter fw = new FileWriter("harbour_debug_messages.txt", true);
                            fw.write("Message at " + LocalDateTime.now() + ": " + message + "\n");
                            fw.close();
                        } catch (IOException e) {
                            System.err.println("Failed to log debug message: " + e.getMessage());
                        }
                    });
                    System.out.println("🚀 Server accept loop finished");
                } catch (Exception e) {
                    System.err.println("🚀 Server accept loop error: " + e.getMessage());
                }
            });
            serverThread.setDaemon(true);
            serverThread.start();
            
        } catch (Exception e) {
            System.err.println("🚀 Failed to create forced debug connection: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
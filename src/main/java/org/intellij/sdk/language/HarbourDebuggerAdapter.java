package org.intellij.sdk.language;

import com.intellij.execution.process.ProcessHandler;
import com.intellij.execution.process.ProcessOutputTypes;
import com.intellij.openapi.util.Key;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;

/**
 * Adapter between IntelliJ debugger framework and the external Harbour debugger.
 * Manages communication and protocol translation.
 */
public class HarbourDebuggerAdapter {
    private final ProcessHandler processHandler;
    private final OutputStream processInput;
    private File infoFile;
    private PrintWriter infoWriter;

    public HarbourDebuggerAdapter(ProcessHandler processHandler) {
        this.processHandler = processHandler;
        this.processInput = processHandler.getProcessInput();
        initializeInfoFile();
    }

    private void initializeInfoFile() {
        try {
            infoFile = File.createTempFile("harbour_debug_", ".info");
            infoWriter = new PrintWriter(infoFile);
            infoWriter.println("RunAtStart = Off");
            infoWriter.println("Dir = " + System.getProperty("java.io.tmpdir"));
            infoWriter.close();

            processHandler.notifyTextAvailable("Debug info file: " + infoFile.getAbsolutePath() + "\n",
                    ProcessOutputTypes.SYSTEM);
        } catch (IOException e) {
            HarbourLogger.logStackTrace("HarbourDebugger", e);
        }
    }

    public void sendCommand(String command) throws IOException {
        if (processInput != null) {
            processInput.write((command + "\n").getBytes());
            processInput.flush();
        }
    }

    public void startDebugSession() {
        try {
            // Create hwgdebug.info for the debugger
            sendCommand("Debugger = hwgdebug");
            sendCommand("Dir = " + System.getProperty("java.io.tmpdir"));

            // Save info file path for the debugger to find
            processHandler.putUserData(Key.create("DEBUG_INFO_PATH"), infoFile.getAbsolutePath());
        } catch (IOException e) {
            HarbourLogger.logStackTrace("HarbourDebugger", e);
        }
    }

    public void cleanup() {
        if (infoFile != null && infoFile.exists()) {
            infoFile.delete();
        }
    }
}
package org.intellij.sdk.language;

import com.intellij.execution.ExecutionException;
import com.intellij.execution.configurations.RunProfile;
import com.intellij.execution.configurations.RunProfileState;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.execution.runners.GenericProgramRunner;
import com.intellij.execution.ui.RunContentDescriptor;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.SystemInfo;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Simple test debug runner to isolate Windows-specific issues.
 * This class only logs its activities without complex functionality.
 */
public class HarbourDebuggerRunnerSimple extends GenericProgramRunner {
    private static final Logger LOG = Logger.getInstance(HarbourDebuggerRunnerSimple.class);
    private static final String RUNNER_ID = "HarbourDebuggerRunnerSimple";
    
    public HarbourDebuggerRunnerSimple() {
        LOG.info("HarbourDebuggerRunnerSimple initialized on " + SystemInfo.getOsNameAndVersion());
        
        // Log to file for Windows debugging (use temp directory to avoid permission issues)
        try {
            String tempDir = System.getProperty("java.io.tmpdir");
            FileWriter fw = new FileWriter(tempDir + "/harbour_simple_runner_created.txt", true);
            fw.write("HarbourDebuggerRunnerSimple constructor called at " + LocalDateTime.now() + "\n");
            fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
            fw.write("Thread: " + Thread.currentThread().getName() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            LOG.error("Failed to write simple runner log", e);
        }
    }

    @NotNull
    @Override
    public String getRunnerId() {
        return RUNNER_ID;
    }

    @Override
    public boolean canRun(@NotNull String executorId, @NotNull RunProfile profile) {
        LOG.info("HarbourDebuggerRunnerSimple.canRun() called");
        
        // Log to file for Windows debugging
        try {
            String tempDir = System.getProperty("java.io.tmpdir");
            FileWriter fw = new FileWriter(tempDir + "/harbour_simple_canRun_called.txt", true);
            fw.write("HarbourDebuggerRunnerSimple.canRun() called at " + LocalDateTime.now() + "\n");
            fw.write("Executor ID: " + executorId + "\n");
            fw.write("Profile class: " + profile.getClass().getName() + "\n");
            fw.write("Profile name: " + profile.getName() + "\n");
            fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            LOG.error("Failed to write canRun log", e);
        }
        
        boolean isDebugExecutor = DefaultDebugExecutor.EXECUTOR_ID.equals(executorId);
        boolean isHarbourDebugConfig = profile instanceof HarbourDebuggerRunConfig;
        
        
        boolean result = isDebugExecutor && isHarbourDebugConfig;
        LOG.info("HarbourDebuggerRunnerSimple.canRun() returning: " + result);
        
        return result;
    }

    @Nullable
    @Override
    protected RunContentDescriptor doExecute(@NotNull RunProfileState state,
                                             @NotNull ExecutionEnvironment env) throws ExecutionException {
        LOG.info("HarbourDebuggerRunnerSimple.doExecute() called");
        
        // Log to file for Windows debugging
        try {
            String tempDir = System.getProperty("java.io.tmpdir");
            FileWriter fw = new FileWriter(tempDir + "/harbour_simple_doExecute_called.txt", true);
            fw.write("HarbourDebuggerRunnerSimple.doExecute() called at " + LocalDateTime.now() + "\n");
            fw.write("Project: " + env.getProject().getName() + "\n");
            fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            LOG.error("Failed to write doExecute log", e);
        }
        
        // For now, just return null to see if this method gets called
        LOG.info("HarbourDebuggerRunnerSimple.doExecute() - returning null (test mode)");
        return null;
    }
}
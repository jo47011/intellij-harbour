package org.intellij.sdk.language;

import com.intellij.execution.ExecutionException;
import com.intellij.execution.ExecutionResult;
import com.intellij.execution.configurations.RunProfile;
import com.intellij.execution.configurations.RunProfileState;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.execution.runners.GenericProgramRunner;
import com.intellij.execution.ui.RunContentDescriptor;
import com.intellij.openapi.project.Project;
import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugProcessStarter;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerManager;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Debug runner for Harbour applications.
 * Responsible for starting debug sessions and creating debug processes.
 */
public class HarbourDebuggerRunner extends GenericProgramRunner {
    private static final String RUNNER_ID = "HarbourDebuggerRunner";
    
    // Windows-specific registration fix
    static {
        System.setProperty("idea.runner.debug.windows.fix", "true");
    }
    
    // Removed static initialization block - it's discouraged in IntelliJ Platform plugins
    // and can cause Windows-specific loading issues. Using proper initialization patterns instead.

    @NotNull
    @Override
    public String getRunnerId() {
        return RUNNER_ID;
    }

    @Override
    public boolean canRun(@NotNull String executorId, @NotNull RunProfile profile) {
        System.out.println("🔍 HarbourDebuggerRunner.canRun() called - v1.0.274");
        System.out.println("🔍 OS: " + System.getProperty("os.name"));
        System.out.println("🔍 Executor ID: " + executorId);
        System.out.println("🔍 Expected ID: " + DefaultDebugExecutor.EXECUTOR_ID);
        System.out.println("🔍 Profile class: " + profile.getClass().getName());
        System.out.println("🔍 Profile name: " + profile.getName());
        
        // Windows-specific logging with absolute path
        try {
            String logPath = System.getProperty("user.home") + "/harbour_canRun_called.txt";
            java.io.FileWriter fw = new java.io.FileWriter(logPath, true);
            fw.write("canRun() called at " + java.time.LocalDateTime.now() + "\n");
            fw.write("OS: " + System.getProperty("os.name") + "\n");
            fw.write("Executor ID: " + executorId + "\n");
            fw.write("Profile class: " + profile.getClass().getName() + "\n");
            fw.write("Profile name: " + profile.getName() + "\n");
            fw.write("Runner ID: " + getRunnerId() + "\n");
            fw.write("---\n");
            fw.close();
            System.out.println("🔍 Log written to: " + logPath);
        } catch (Exception e) {
            System.err.println("Failed to write canRun log: " + e.getMessage());
        }
        
        boolean isDebugExecutor = DefaultDebugExecutor.EXECUTOR_ID.equals(executorId);
        boolean isHarbourDebugConfig = profile instanceof HarbourDebuggerRunConfig;
        
        System.out.println("🔍 Is debug executor: " + isDebugExecutor);
        System.out.println("🔍 Is HarbourDebuggerRunConfig: " + isHarbourDebugConfig);
        
        boolean result = isDebugExecutor && isHarbourDebugConfig;
        System.out.println("🔍 canRun() returning: " + result);
        
        return result;
    }

    @Nullable
    @Override
    protected RunContentDescriptor doExecute(@NotNull RunProfileState state,
                                             @NotNull ExecutionEnvironment env) throws ExecutionException {
        // CRITICAL DEBUG OUTPUT - ALWAYS VISIBLE
        System.out.println("🚀🚀🚀 HARBOUR DEBUG RUNNER doExecute() CALLED v1.0.274 🚀🚀🚀");
        System.err.println("🚀🚀🚀 [STDERR] HARBOUR DEBUG RUNNER doExecute() CALLED v1.0.274 🚀🚀🚀");
        
        Project project = env.getProject();

        HarbourLogger.log("HarbourDebuggerRunner", "========= RUNNER DEBUG =========");
        HarbourLogger.log("HarbourDebuggerRunner", "HarbourDebuggerRunner.doExecute() called");
        HarbourLogger.log(project, "HarbourDebugger", "========= RUNNER DEBUG =========");
        HarbourLogger.log(project, "HarbourDebugger", "HarbourDebuggerRunner.doExecute() called");
        HarbourLogger.log(project, "HarbourDebugger", "Starting debug session...");

        // Get debug configuration
        HarbourDebuggerRunConfig config = (HarbourDebuggerRunConfig) env.getRunProfile();
        int debugPort = config.getDebugPortAsInt();
        HarbourLogger.log(project, "HarbourDebugger", "Debug port configured: " + debugPort);

        // Start debug session
        XDebuggerManager debuggerManager = XDebuggerManager.getInstance(project);
        ExecutionResult executionResult = state.execute(env.getExecutor(), this);

        if (executionResult == null) {
            throw new ExecutionException("Failed to execute debug configuration");
        }

        // Create debug session
        System.out.println("🚀 HARBOUR DEBUG RUNNER v1.0.274 - CREATING DEBUG SESSION");
        System.out.println("🔧 Runner called - about to start debug session");
        
        // Log to file for debugging
        try {
            String tempDir = System.getProperty("java.io.tmpdir");
            java.io.FileWriter fw = new java.io.FileWriter(tempDir + "/harbour_doExecute_called.txt", true);
            fw.write("doExecute() called at " + java.time.LocalDateTime.now() + "\n");
            fw.write("Project: " + project.getName() + "\n");
            fw.write("Debug port: " + debugPort + "\n");
            fw.write("---\n");
            fw.close();
        } catch (Exception e) {
            System.err.println("Failed to write doExecute log: " + e.getMessage());
        }
        
        XDebugSession debugSession = debuggerManager.startSession(env, new XDebugProcessStarter() {
            @Override
            @NotNull
            public XDebugProcess start(@NotNull XDebugSession session) throws ExecutionException {
                System.out.println("🔧 XDebugProcessStarter.start() called");
                
                // Get debug configuration
                HarbourDebuggerRunConfig config = (HarbourDebuggerRunConfig) env.getRunProfile();
                int debugPort = config.getDebugPortAsInt();
                
                System.out.println("🔧 Debug port from config: " + debugPort);
                System.out.println("🔧 About to create HarbourDebuggerRemoteProcess...");
                
                // Create remote debug process
                HarbourDebuggerRemoteProcess process = new HarbourDebuggerRemoteProcess(session, executionResult, debugPort);

                System.out.println("🔧 HarbourDebuggerRemoteProcess created successfully");
                return process;
            }
        });

        // PROPER FIX (v1.0.230): No longer need to remove ProcessListeners
        // The real solution is in HarbourDebuggerRemoteProcess.doGetProcessHandler() returning null
        // This causes IntelliJ to use DefaultDebugProcessHandler instead of the actual process handler
        // which prevents XDebugSessionImpl from attaching problematic ProcessListeners
        HarbourLogger.log(project, "HarbourDebugger", 
            "Using proper remote debugging pattern - doGetProcessHandler() returns null");

        return debugSession.getRunContentDescriptor();
    }
}
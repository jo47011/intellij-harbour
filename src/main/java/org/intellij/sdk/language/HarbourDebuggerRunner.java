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

    @NotNull
    @Override
    public String getRunnerId() {
        return RUNNER_ID;
    }

    @Override
    public boolean canRun(@NotNull String executorId, @NotNull RunProfile profile) {
        return DefaultDebugExecutor.EXECUTOR_ID.equals(executorId) &&
                profile instanceof HarbourDebuggerRunConfig;
    }

    @Nullable
    @Override
    protected RunContentDescriptor doExecute(@NotNull RunProfileState state,
                                             @NotNull ExecutionEnvironment env) throws ExecutionException {
        Project project = env.getProject();

        System.out.println("========= RUNNER DEBUG =========");
        System.out.println("HarbourDebuggerRunner.doExecute() called");
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
        XDebugSession debugSession = debuggerManager.startSession(env, new XDebugProcessStarter() {
            @Override
            @NotNull
            public XDebugProcess start(@NotNull XDebugSession session) throws ExecutionException {
                // Get debug configuration
                HarbourDebuggerRunConfig config = (HarbourDebuggerRunConfig) env.getRunProfile();
                int debugPort = config.getDebugPortAsInt();
                
                // Create remote debug process
                HarbourDebuggerRemoteProcess process = new HarbourDebuggerRemoteProcess(session, executionResult, debugPort);

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
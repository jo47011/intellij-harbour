package org.intellij.sdk.language;

import com.intellij.execution.ExecutionException;
import com.intellij.execution.ExecutionResult;
import com.intellij.execution.configurations.RunProfile;
import com.intellij.execution.configurations.RunProfileState;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.execution.process.ProcessAdapter;
import com.intellij.execution.process.ProcessEvent;
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

        HarbourLogger.log(project, "HarbourDebugger", "Starting debug session...");

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
                HarbourDebuggerProcess process = new HarbourDebuggerProcess(session, executionResult);

                // Listen for process termination
                executionResult.getProcessHandler().addProcessListener(new ProcessAdapter() {
                    @Override
                    public void processTerminated(@NotNull ProcessEvent event) {
                        HarbourLogger.log(project, "HarbourDebugger",
                                "Debug process terminated with exit code: " + event.getExitCode());
                        session.stop();
                    }
                });

                return process;
            }
        });

        return debugSession.getRunContentDescriptor();
    }
}
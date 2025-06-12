package org.intellij.sdk.language;

import com.intellij.execution.ExecutionException;
import com.intellij.execution.ExecutionResult;
import com.intellij.execution.configurations.RunProfile;
import com.intellij.execution.configurations.RunProfileState;
import com.intellij.execution.executors.DefaultDebugExecutor;
import com.intellij.execution.process.ProcessAdapter;
import com.intellij.execution.process.ProcessEvent;
import com.intellij.execution.process.ProcessHandler;
import com.intellij.execution.process.ProcessListener;
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.execution.runners.GenericProgramRunner;
import com.intellij.execution.ui.RunContentDescriptor;
import com.intellij.openapi.project.Project;
import com.intellij.util.ReflectionUtil;
import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugProcessStarter;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerManager;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.List;

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

        // Remove ALL process listeners AFTER the debug session is fully created
        // This prevents IntelliJ from adding listeners after our removal
        ProcessHandler processHandler = executionResult.getProcessHandler();
        
        // Use ReflectionUtil to access private myListeners field
        List<ProcessListener> listeners = ReflectionUtil.getField(
            ProcessHandler.class, 
            processHandler, 
            List.class, 
            "myListeners"
        );
        
        if (listeners != null) {
            // Create a copy to avoid ConcurrentModificationException
            List<ProcessListener> listenersCopy = new ArrayList<>(listeners);
            
            HarbourLogger.log(project, "HarbourDebugger", 
                "AFTER session creation: Removing " + listenersCopy.size() + " process listeners to prevent auto-termination");
            
            for (ProcessListener listener : listenersCopy) {
                processHandler.removeProcessListener(listener);
                HarbourLogger.log(project, "HarbourDebugger", 
                    "AFTER session creation: Removed process listener: " + listener.getClass().getSimpleName());
            }
        } else {
            HarbourLogger.log(project, "HarbourDebugger", 
                "Could not access process listeners via reflection - auto-termination may still occur");
        }

        return debugSession.getRunContentDescriptor();
    }
}
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
import com.intellij.openapi.util.Key;
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
    
    // UserData key for passing global mute state from runner to profile state
    public static final Key<Boolean> GLOBAL_MUTE_STATE_KEY = Key.create("harbour.debugger.globalMuteState");
    
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
        boolean isDebugExecutor = DefaultDebugExecutor.EXECUTOR_ID.equals(executorId);
        boolean isHarbourDebugConfig = profile instanceof HarbourDebuggerRunConfig;
        boolean result = isDebugExecutor && isHarbourDebugConfig;
        
        return result;
    }

    @Nullable
    @Override
    protected RunContentDescriptor doExecute(@NotNull RunProfileState state,
                                             @NotNull ExecutionEnvironment env) throws ExecutionException {
        
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

        // Start debug session FIRST to check mute state
        XDebuggerManager debuggerManager = XDebuggerManager.getInstance(project);
        
        // Create debug session
        
        // Create a holder for the execution result
        final ExecutionResult[] executionResultHolder = new ExecutionResult[1];
        
        // Use startSessionAndShowTab(...) instead of startSession(...) +
        // debugSession.getRunContentDescriptor(). The latter calls the deprecated
        // XDebugSession.getRunContentDescriptor(), which logs an IDE error
        // ("[Split debugger] RunContentDescriptor should not be used in split mode")
        // on newer IntelliJ versions running in split mode and surfaces as a popup.
        // Letting the platform build/show the run tab avoids touching that getter.
        debuggerManager.startSessionAndShowTab(config.getName(), env.getContentToReuse(),
                new XDebugProcessStarter() {
            @Override
            @NotNull
            public XDebugProcess start(@NotNull XDebugSession session) throws ExecutionException {
                // PHASE 1: Check mute state immediately
                boolean globallyMuted = session.areBreakpointsMuted();
                HarbourLogger.log(project, "HarbourDebugger", 
                        "Two-phase startup - mute state detected: " + globallyMuted);
                
                // Store mute state in environment for RunProfileState to access
                env.putUserData(GLOBAL_MUTE_STATE_KEY, globallyMuted);
                
                // PHASE 2: Now execute the program with correct init.cld
                ExecutionResult executionResult = state.execute(env.getExecutor(), HarbourDebuggerRunner.this);
                
                if (executionResult == null) {
                    throw new ExecutionException("Failed to execute debug configuration");
                }
                
                executionResultHolder[0] = executionResult;
                
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

        // The run tab is already shown by startSessionAndShowTab() above, so return
        // null here to avoid showing a second tab and to avoid calling the deprecated
        // XDebugSession.getRunContentDescriptor().
        return null;
    }
}
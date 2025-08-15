package org.intellij.sdk.language;

import com.intellij.execution.RunnerRegistry;
import com.intellij.execution.runners.ProgramRunner;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.ProjectActivity;
import kotlin.Unit;
import kotlin.coroutines.Continuation;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Windows-specific registration component for HarbourDebuggerRunner.
 * This ensures the runner is properly registered and provides debugging information.
 */
public class HarbourDebuggerRunnerRegistration implements ProjectActivity {

    @Nullable
    @Override
    public Object execute(@NotNull Project project, @NotNull Continuation<? super Unit> continuation) {
        
        // Log to file for debugging
        try {
            FileWriter fw = new FileWriter("harbour_startup_activity.txt", true);
            fw.write("HarbourDebuggerRunnerRegistration startup at " + LocalDateTime.now() + "\n");
            fw.write("OS: " + System.getProperty("os.name") + "\n");
            fw.write("Project: " + project.getName() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            // Silent failure
        }
        
        // Force load the HarbourDebuggerRunner classes on Windows
        if (System.getProperty("os.name").toLowerCase().contains("windows")) {
            try {
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunner");
            } catch (ClassNotFoundException e) {
            }
            
            try {
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunnerSimple");
            } catch (ClassNotFoundException e) {
            }
        }
        
        return Unit.INSTANCE;
    }
}
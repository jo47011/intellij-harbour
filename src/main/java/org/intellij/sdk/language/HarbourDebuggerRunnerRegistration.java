package org.intellij.sdk.language;

import com.intellij.execution.RunnerRegistry;
import com.intellij.execution.runners.ProgramRunner;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import org.jetbrains.annotations.NotNull;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Windows-specific registration component for HarbourDebuggerRunner.
 * This ensures the runner is properly registered and provides debugging information.
 */
public class HarbourDebuggerRunnerRegistration implements StartupActivity {

    @Override
    public void runActivity(@NotNull Project project) {
        System.out.println("🔧 HarbourDebuggerRunnerRegistration v1.0.265 - STARTUP ACTIVITY");
        System.out.println("🔧 OS: " + System.getProperty("os.name"));
        System.out.println("🔧 Project: " + project.getName());
        
        // Log to file for debugging
        try {
            FileWriter fw = new FileWriter("harbour_startup_activity.txt", true);
            fw.write("HarbourDebuggerRunnerRegistration startup at " + LocalDateTime.now() + "\n");
            fw.write("OS: " + System.getProperty("os.name") + "\n");
            fw.write("Project: " + project.getName() + "\n");
            fw.write("---\n");
            fw.close();
        } catch (IOException e) {
            System.err.println("Failed to write startup activity log: " + e.getMessage());
        }
        
        // Force load the HarbourDebuggerRunner classes on Windows
        if (System.getProperty("os.name").toLowerCase().contains("windows")) {
            try {
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunner");
                System.out.println("🔧 WINDOWS: HarbourDebuggerRunner class loaded successfully");
            } catch (ClassNotFoundException e) {
                System.err.println("🔧 WINDOWS: Failed to load HarbourDebuggerRunner class: " + e.getMessage());
            }
            
            try {
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunnerSimple");
                System.out.println("🔧 WINDOWS: HarbourDebuggerRunnerSimple class loaded successfully");
            } catch (ClassNotFoundException e) {
                System.err.println("🔧 WINDOWS: Failed to load HarbourDebuggerRunnerSimple class: " + e.getMessage());
            }
        }
        
        // Simply log that the startup activity ran
        System.out.println("🔧 Startup activity completed - HarbourDebuggerRunner class loading attempted");
    }
}
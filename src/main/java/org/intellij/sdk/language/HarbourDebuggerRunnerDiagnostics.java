package org.intellij.sdk.language;

import com.intellij.execution.RunnerRegistry;
import com.intellij.execution.configurations.ConfigurationFactory;
import com.intellij.execution.configurations.ConfigurationType;
import com.intellij.execution.configurations.RunConfiguration;
import com.intellij.execution.runners.ProgramRunner;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.util.SystemInfo;
import org.jetbrains.annotations.NotNull;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Arrays;

/**
 * Comprehensive diagnostics for debug runner registration and availability.
 */
public class HarbourDebuggerRunnerDiagnostics implements StartupActivity {
    
    // DEBUG FLAG: Set to false to disable test error logging
    private static final boolean ENABLE_TEST_ERROR = false;
    
    @Override
    public void runActivity(@NotNull Project project) {
        System.out.println("🔍 HarbourDebuggerRunnerDiagnostics v1.0.270 - COMPREHENSIVE DEBUG ANALYSIS");
        System.out.println("🔍 OS: " + SystemInfo.getOsNameAndVersion());
        System.out.println("🔍 Project: " + project.getName());
        
        // TEST ERROR: Generate a test error to verify console logging is working
        // Can be easily disabled by setting ENABLE_TEST_ERROR = false
        if (ENABLE_TEST_ERROR) {
            System.out.println("🧪 TEST ERROR: Creating intentional test error for console logging verification");
            HarbourLogger.log(project, "TEST_ERROR", "=== TEST ERROR START ===");
            HarbourLogger.log(project, "TEST_ERROR", "This is a test error to verify PyCharm console logging");
            HarbourLogger.log(project, "TEST_ERROR", "Time: " + LocalDateTime.now());
            
            // Create a test exception for stack trace logging
            try {
                throw new RuntimeException("TEST ERROR: Intentional test exception for logging verification");
            } catch (Exception e) {
                HarbourLogger.log(project, "TEST_ERROR", "Test exception caught: " + e.getMessage());
                HarbourLogger.logStackTrace("TEST_ERROR", e);
                System.out.println("🧪 TEST ERROR: Exception logged to HarbourLogger - check PyCharm console");
            }
            
            HarbourLogger.log(project, "TEST_ERROR", "=== TEST ERROR END ===");
            System.out.println("🧪 TEST ERROR: Test error logging completed");
        }
        
        StringBuilder diagnostics = new StringBuilder();
        diagnostics.append("HarbourDebuggerRunnerDiagnostics v1.0.270 - " + LocalDateTime.now() + "\n");
        diagnostics.append("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
        diagnostics.append("Project: " + project.getName() + "\n");
        diagnostics.append("---\n");
        
        // Check if HarbourDebuggerConfigType is registered
        try {
            HarbourDebuggerConfigType configType = HarbourDebuggerConfigType.getInstance();
            if (configType != null) {
                diagnostics.append("✓ HarbourDebuggerConfigType found: " + configType.getDisplayName() + "\n");
                diagnostics.append("✓ Config Type ID: " + configType.getId() + "\n");
                
                // Check configuration factories
                ConfigurationFactory[] factories = configType.getConfigurationFactories();
                diagnostics.append("✓ Factories: " + factories.length + "\n");
                for (ConfigurationFactory factory : factories) {
                    diagnostics.append("  - Factory: " + factory.getId() + "\n");
                }
            } else {
                diagnostics.append("❌ HarbourDebuggerConfigType NOT FOUND\n");
            }
        } catch (Exception e) {
            diagnostics.append("❌ Error checking config type: " + e.getMessage() + "\n");
        }
        
        // Check if runners are registered
        try {
            // Check all available runners
            diagnostics.append("Available runners:\n");
            
            // Try to find our runner specifically
            boolean foundHarbourRunner = false;
            boolean foundHarbourSimpleRunner = false;
            
            try {
                // Check if classes can be loaded
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunner");
                diagnostics.append("✓ HarbourDebuggerRunner class loadable\n");
                
                // Try to create instance
                HarbourDebuggerRunner runner = new HarbourDebuggerRunner();
                diagnostics.append("✓ HarbourDebuggerRunner instance created: " + runner.getRunnerId() + "\n");
                foundHarbourRunner = true;
                
            } catch (Exception e) {
                diagnostics.append("❌ HarbourDebuggerRunner class loading failed: " + e.getMessage() + "\n");
            }
            
            try {
                Class.forName("org.intellij.sdk.language.HarbourDebuggerRunnerSimple");
                diagnostics.append("✓ HarbourDebuggerRunnerSimple class loadable\n");
                
                HarbourDebuggerRunnerSimple simpleRunner = new HarbourDebuggerRunnerSimple();
                diagnostics.append("✓ HarbourDebuggerRunnerSimple instance created: " + simpleRunner.getRunnerId() + "\n");
                foundHarbourSimpleRunner = true;
                
            } catch (Exception e) {
                diagnostics.append("❌ HarbourDebuggerRunnerSimple class loading failed: " + e.getMessage() + "\n");
            }
            
            diagnostics.append("Summary:\n");
            diagnostics.append("- HarbourDebuggerRunner found: " + foundHarbourRunner + "\n");
            diagnostics.append("- HarbourDebuggerRunnerSimple found: " + foundHarbourSimpleRunner + "\n");
            
        } catch (Exception e) {
            diagnostics.append("❌ Error checking runners: " + e.getMessage() + "\n");
        }
        
        // Write diagnostics to file
        try {
            FileWriter fw = new FileWriter("harbour_runner_diagnostics.txt");
            fw.write(diagnostics.toString());
            fw.close();
            System.out.println("🔍 Runner diagnostics written to harbour_runner_diagnostics.txt");
        } catch (IOException e) {
            System.err.println("Failed to write runner diagnostics: " + e.getMessage());
        }
        
        System.out.println("🔍 Runner diagnostics completed");
    }
}
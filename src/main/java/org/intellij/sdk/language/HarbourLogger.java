package org.intellij.sdk.language;

import com.intellij.execution.ui.ConsoleView;
import com.intellij.execution.ui.ConsoleViewContentType;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * Common logging utility for Harbour plugin components.
 */
public class HarbourLogger {
    private static final DateTimeFormatter TIMESTAMP_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    
    // Static reference to current console for direct PyCharm console output
    private static ConsoleView currentConsole = null;
    
    // Log levels for console filtering
    public enum LogLevel {
        DEBUG,    // Only to files/IntelliJ log
        INFO,     // Only to files/IntelliJ log  
        WARNING,  // To console + files/IntelliJ log
        ERROR     // To console + files/IntelliJ log
    }
    
    /**
     * Set the current console for direct PyCharm console output
     */
    public static void setConsole(ConsoleView console) {
        currentConsole = console;
    }
    
    /**
     * Clear the console reference
     */
    public static void clearConsole() {
        currentConsole = null;
    }
    
    /**
     * Get the current console reference
     */
    public static ConsoleView getCurrentConsole() {
        return currentConsole;
    }

    /**
     * Log a message to both the IntelliJ log and optional file log
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void log(String componentName, String message) {
        log(null, componentName, message, LogLevel.INFO);
    }

    /**
     * Log a message to both the IntelliJ log and optional file log
     *
     * @param project Project context, or null to auto-detect
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void log(Project project, String componentName, String message) {
        log(project, componentName, message, LogLevel.INFO);
    }
    
    /**
     * Log a message with specified level to both the IntelliJ log and optional file log
     * Only WARNING and ERROR levels go to PyCharm console
     *
     * @param project Project context, or null to auto-detect
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     * @param level Log level (only WARNING/ERROR go to console)
     */
    public static void log(Project project, String componentName, String message, LogLevel level) {
        // Get the appropriate logger
        Logger logger = Logger.getInstance(componentName);

        // Only log WARNING and ERROR to IntelliJ log (not DEBUG/INFO to avoid flooding)
        switch (level) {
            case ERROR:
                logger.error("[Harbour " + componentName + "] " + message);
                break;
            case WARNING:
                logger.warn("[Harbour " + componentName + "] " + message);
                break;
            case INFO:
            case DEBUG:
            default:
                // Skip logging DEBUG/INFO to idea.log to avoid flooding
                // These will still go to custom log files if configured
                break;
        }
        
        // ONLY log WARNING and ERROR to PyCharm console (not DEBUG/INFO)
        if (level == LogLevel.WARNING || level == LogLevel.ERROR) {
            String timestamp = LocalDateTime.now().format(TIMESTAMP_FORMAT);
            String consoleMessage = "[" + timestamp + "] [Harbour " + componentName + "] " + message + "\n";
            
            // Try to write to PyCharm console directly if available
            if (currentConsole != null) {
                try {
                    ConsoleViewContentType contentType = (level == LogLevel.ERROR) ? 
                        ConsoleViewContentType.ERROR_OUTPUT : ConsoleViewContentType.SYSTEM_OUTPUT;
                    currentConsole.print(consoleMessage, contentType);
                } catch (Exception e) {
                    // Fallback to System.out if console write fails
                    System.out.println(consoleMessage.trim());
                }
            } else {
                // Fallback to System.out if no console available
                System.out.println(consoleMessage.trim());
            }
        }

        try {
            // If project is null, try to get the current active project
            if (project == null) {
                Project[] projects = ProjectManager.getInstance().getOpenProjects();
                if (projects.length > 0) {
                    project = projects[0];
                }
            }

            if (project != null) {
                HarbourSettings settings = HarbourSettings.getInstance(project);
                if (settings != null) {
                    // Use componentName as-is with hyphens instead of converting to lowercase
                    String logFileName = componentName.replace(" ", "-") + ".log";
                    String logFilePath = settings.getLogFilePath(logFileName);

                    if (logFilePath != null) {
                        // We have a valid log path, write to file
                        writeToLogFile(logFilePath, message);
                    }
                }
            }
        } catch (Exception e) {
            // If any issues with file logging, just silently continue
            logger.warn("Failed to write to log file: " + e.getMessage());
        }
    }

    /**
     * Log a warning message - goes to PyCharm console + logs
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void warning(String componentName, String message) {
        log(null, componentName, message, LogLevel.WARNING);
    }
    
    /**
     * Log a warning message - goes to PyCharm console + logs
     *
     * @param project Project context
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void warning(Project project, String componentName, String message) {
        log(project, componentName, message, LogLevel.WARNING);
    }
    
    /**
     * Log an error message - goes to PyCharm console + logs
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void error(String componentName, String message) {
        log(null, componentName, message, LogLevel.ERROR);
    }
    
    /**
     * Log an error message - goes to PyCharm console + logs
     *
     * @param project Project context
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void error(Project project, String componentName, String message) {
        log(project, componentName, message, LogLevel.ERROR);
    }

    /**
     * Log an important message - highlighted in both logs
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void logImportant(String componentName, String message) {
        log(null, componentName, "!!IMPORTANT!! " + message, LogLevel.WARNING);
    }

    /**
     * Log a stack trace with component identifier
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param e Exception to log
     */
    public static void logStackTrace(String componentName, Exception e) {
        Logger logger = Logger.getInstance(componentName);
        logger.error("[Harbour " + componentName + "] Exception:", e);
        
        // ALSO log stack trace to PyCharm console for immediate visibility
        String timestamp = LocalDateTime.now().format(TIMESTAMP_FORMAT);
        String exceptionMessage = "[" + timestamp + "] [Harbour " + componentName + "] EXCEPTION: " + e.getMessage() + "\n";
        
        // Try to write to PyCharm console directly if available
        if (currentConsole != null) {
            try {
                currentConsole.print(exceptionMessage, ConsoleViewContentType.ERROR_OUTPUT);
                for (StackTraceElement element : e.getStackTrace()) {
                    currentConsole.print("    at " + element.toString() + "\n", ConsoleViewContentType.ERROR_OUTPUT);
                }
            } catch (Exception ex) {
                // Fallback to System.out if console write fails
                System.out.println(exceptionMessage.trim());
                for (StackTraceElement element : e.getStackTrace()) {
                    System.out.println("    at " + element.toString());
                }
            }
        } else {
            // Fallback to System.out if no console available
            System.out.println(exceptionMessage.trim());
            for (StackTraceElement element : e.getStackTrace()) {
                System.out.println("    at " + element.toString());
            }
        }

        try {
            Project[] projects = ProjectManager.getInstance().getOpenProjects();
            if (projects.length > 0) {
                Project project = projects[0];
                HarbourSettings settings = HarbourSettings.getInstance(project);
                if (settings != null) {
                    // Use componentName as-is with hyphens instead of converting to lowercase
                    String logFileName = componentName.replace(" ", "-") + ".log";
                    String logFilePath = settings.getLogFilePath(logFileName);

                    if (logFilePath != null) {
                        // Format exception for file log
                        StringBuilder sb = new StringBuilder();
                        sb.append("EXCEPTION: ").append(e.getMessage()).append("\n");
                        for (StackTraceElement element : e.getStackTrace()) {
                            sb.append("    at ").append(element.toString()).append("\n");
                        }
                        writeToLogFile(logFilePath, sb.toString());
                    }
                }
            }
        } catch (Exception ex) {
            // Silently continue if there's an issue with file logging
        }
    }

    /**
     * Calculate line number for a PSI element
     *
     * @param element The PSI element
     * @return The line number, or -1 if it can't be determined
     */
    public static int calculateLineNumber(PsiElement element) {
        if (element == null || !element.isValid() || element.getContainingFile() == null) {
            return -1;
        }

        try {
            PsiFile file = element.getContainingFile();
            String fileText = file.getText();
            int offset = element.getTextOffset();

            // Ensure offset is valid
            if (offset >= 0 && offset <= fileText.length()) {
                // Count the number of newlines up to this offset
                // Lines are 1-based, so the number of newlines + 1 gives us the line number
                int lineNumber = 1;
                for (int i = 0; i < offset && i < fileText.length(); i++) {
                    if (fileText.charAt(i) == '\n') {
                        lineNumber++;
                    }
                }
                return lineNumber;
            }
        } catch (Exception e) {
            log("LineCalculator", "Error calculating line number: " + e.getMessage());
        }

        return -1;
    }

    /**
     * Get a file-unique ID for a PSI element based on file path and position
     */
    public static String getElementLocationId(PsiElement element) {
        if (element == null || !element.isValid() || element.getContainingFile() == null) {
            return null;
        }

        try {
            PsiFile file = element.getContainingFile();
            if (file.getVirtualFile() == null) {
                return null;
            }

            String filePath = file.getVirtualFile().getPath();
            int lineNumber = calculateLineNumber(element);

            return filePath + ":" + lineNumber;
        } catch (Exception e) {
            log("LocationId", "Error getting element location ID: " + e.getMessage());
            return null;
        }
    }

    /**
     * Write a message to the specified log file
     */
    private static void writeToLogFile(String logFilePath, String message) throws IOException {
        File logFile = new File(logFilePath);
        boolean isNewFile = !logFile.exists();

        // Create parent directory if needed
        if (!logFile.getParentFile().exists()) {
            logFile.getParentFile().mkdirs();
        }

        try (FileWriter writer = new FileWriter(logFile, true)) {
            if (isNewFile) {
                writer.write("=== Harbour Log ===\n");
            }

            LocalDateTime now = LocalDateTime.now();
            String timestamp = now.format(TIMESTAMP_FORMAT);
            writer.write(timestamp + " " + message + "\n");
        }
    }
}
package org.intellij.sdk.language;

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

    /**
     * Log a message to both the IntelliJ log and optional file log
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void log(String componentName, String message) {
        log(null, componentName, message);
    }

    /**
     * Log a message to both the IntelliJ log and optional file log
     *
     * @param project Project context, or null to auto-detect
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void log(Project project, String componentName, String message) {
        // Get the appropriate logger
        Logger logger = Logger.getInstance(componentName);

        // Always log to IntelliJ log
        logger.info("[Harbour " + componentName + "] " + message);

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
     * Log an important message - highlighted in both logs
     *
     * @param componentName Name of the component for IntelliJ logs
     * @param message Message to log
     */
    public static void logImportant(String componentName, String message) {
        log(componentName, "!!IMPORTANT!! " + message);
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
            if (offset >= 0 && offset < fileText.length()) {
                // Count the number of newlines up to this offset
                return fileText.substring(0, offset).split("\n").length;
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
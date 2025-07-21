package org.intellij.sdk.language;

import com.intellij.application.options.CodeStyle;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.*;
import com.intellij.openapi.editor.EditorFactory;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.psi.codeStyle.CodeStyleSettingsManager;
import com.intellij.util.xmlb.XmlSerializerUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Persistent settings for Harbour plugin.
 */
@State(
        name = "HarbourSettings",
        storages = {@Storage("harbour-plugin.xml")}
)
public class HarbourSettings implements PersistentStateComponent<HarbourSettings> {
    // Default exclusion list
    private Set<String> excludedFiles = new HashSet<>();

    // List of Harbour commands for code completion
    private List<String> harbourCommands = new ArrayList<>();

    // Include paths for #include directives
    private List<String> includePaths = new ArrayList<>();

    // Documentation base URL
    private String documentationBaseUrl = "https://harbour.github.io/doc/clc53.html";

    // Default log path based on user home
    private static final String DEFAULT_LOG_PATH = getDefaultLogPath();

    // Debug log path (empty = disabled)
    private String debugLogPath = DEFAULT_LOG_PATH;

    // Build output directory (default .hbmk)
    private String buildOutputDirectory = ".hbmk";
    
    // Last known global mute state for debugger
    private boolean lastKnownGlobalMuteState = false;

    // Indentation size (default 2 spaces)
    private int indentationSize = 2;

    // Line break position (default 99, 0 or negative means no line breaking)
    private int lineBreakPosition = 99;


    // Formatting settings
    private boolean returnStatementsAtLevel0 = true;
    private boolean localStatementsAtLevel0 = false; // Default is false to match current behavior

    // Auto-completion setting
    private boolean autoCompletionEnabled = false; // Default to false (only show on Ctrl+Space)


    public HarbourSettings() {
        // Empty constructor
    }

    // Debug log path methods
    public String getDebugLogPath() {
        return debugLogPath;
    }

    public void setDebugLogPath(String debugLogPath) {
        this.debugLogPath = debugLogPath;
    }

    // Build output directory methods
    public String getBuildOutputDirectory() {
        return buildOutputDirectory;
    }

    public void setBuildOutputDirectory(String buildOutputDirectory) {
        this.buildOutputDirectory = buildOutputDirectory;
    }
    
    // Last known mute state methods
    public boolean getLastKnownGlobalMuteState() {
        return lastKnownGlobalMuteState;
    }
    
    public void setLastKnownGlobalMuteState(boolean muted) {
        this.lastKnownGlobalMuteState = muted;
    }

    /**
     * Gets platform-specific default log path
     */
    private static String getDefaultLogPath() {
        String userHome = System.getProperty("user.home");
        if (userHome == null) {
            return ""; // No user home defined
        }

        // Add proper separator for the OS
        return userHome + File.separator + "log";
    }

    /**
     * Gets the full path for a log file
     * @param fileName The log file name
     * @return The full path, or null if debug logging is disabled
     */
    public String getLogFilePath(String fileName) {
        if (debugLogPath == null || debugLogPath.trim().isEmpty()) {
            return null; // Debug logging disabled
        }

        File dir = new File(debugLogPath);
        if (!dir.exists()) {
            //noinspection ResultOfMethodCallIgnored
            dir.mkdirs();
        }

        return new File(dir, fileName).getAbsolutePath();
    }

    // Line break position methods
    public int getLineBreakPosition() {
        return lineBreakPosition;
    }



    // Replace the existing setLineBreakPosition method
    public void setLineBreakPosition(int lineBreakPosition) {
        this.lineBreakPosition = lineBreakPosition;

        ApplicationManager.getApplication().invokeLater(() -> {
            for (Project openProject : ProjectManager.getInstance().getOpenProjects()) {
                try {
                    // Update global settings first
                    CodeStyleSettings settings = CodeStyle.getSettings(openProject);
                    settings.setRightMargin(HarbourLanguage.INSTANCE, lineBreakPosition);

                    // Force UI refresh for each editor
                    for (com.intellij.openapi.editor.Editor editor : EditorFactory.getInstance().getAllEditors()) {
                        try {
                            // Check if this editor belongs to the current project
                            Project editorProject = editor.getProject();
                            if (editorProject == null || editorProject != openProject) {
                                continue; // Skip editors from other projects or without project
                            }
                            
                            PsiFile psiFile = PsiDocumentManager.getInstance(openProject).getPsiFile(editor.getDocument());
                            if (psiFile instanceof HarbourFile) {
                                // Update the editor specific settings
                                CodeStyle.getSettings(psiFile).setRightMargin(psiFile.getLanguage(), lineBreakPosition);

                                // Force margin renderer to update
                                editor.getSettings().setRightMargin(lineBreakPosition);

                                // Force component repaint
                                editor.getComponent().repaint();
                                editor.getContentComponent().repaint();
                            }
                        } catch (Exception e) {
                            // Log but don't fail if there's an issue with a specific editor
                            HarbourLogger.log("HarbourSettings", 
                                "Error updating editor settings: " + e.getMessage());
                        }
                    }

                    // Trigger settings change notification
                    CodeStyleSettingsManager.getInstance(openProject)
                            .notifyCodeStyleSettingsChanged();

                    // Add logging
                    HarbourLogger.log("HarbourSettings", "Updated right margin to: " + lineBreakPosition);
                } catch (Exception e) {
                    HarbourLogger.log("HarbourSettings", "Error updating margin: " + e.getMessage());
                }
            }
        });
    }

    // Auto-completion setting methods
    public boolean isAutoCompletionEnabled() {
        return autoCompletionEnabled;
    }

    public void setAutoCompletionEnabled(boolean autoCompletionEnabled) {
        this.autoCompletionEnabled = autoCompletionEnabled;
    }

    // Excluded files methods
    public Set<String> getExcludedFiles() {
        return excludedFiles;
    }

    public void setExcludedFiles(Set<String> excludedFiles) {
        this.excludedFiles = excludedFiles;
    }

    // Harbour commands methods
    public List<String> getHarbourCommands() {
        if (harbourCommands.isEmpty()) {
            // Initialize with default commands if empty
            initializeDefaultCommands();
        }
        return harbourCommands;
    }

    public void setHarbourCommands(List<String> harbourCommands) {
        this.harbourCommands = harbourCommands;
    }

    private void initializeDefaultCommands() {
        // Add default Harbour commands
        List<String> defaults = getDefaultHarbourCommands();
        harbourCommands.addAll(defaults);
    }

    /**
     * Gets default list of Harbour commands
     */
    public static List<String> getDefaultHarbourCommands() {
        // Basic commands
        String[] commands = {
                "ACCEPT", "APPEND", "AVERAGE", "BEGIN SEQUENCE", "BEGIN TRANSACTION", "BOX", "BREAK",
                "CALL", "CANCEL", "CASE", "CLEAR", "CLEAR ALL", "CLEAR GETS", "CLEAR MEMORY",
                "CLEAR TYPEAHEAD", "CLOSE", "CLOSE ALL", "CLOSE DATABASES", "COMMIT", "CONTINUE",
                "COPY", "COPY FILE", "COPY STRUCTURE", "COPY TO", "COUNT", "CREATE", "CREATE FROM",
                "DATE", "DECLARE", "DEFAULT", "DELETE", "DELETE FILE", "DELETE TAG", "DIR", "DIRECTORY",
                "DISPLAY", "DISPLAY STRUCTURE", "DO", "DO CASE", "DO WHILE", "EJECT", "ELSE", "ELSEIF",
                "ENDCASE", "ENDDO", "ENDIF", "ENDSEQUENCE", "ERASE", "EXIT", "FIELD", "FIND", "FOR",
                "GET", "GO", "GO BOTTOM", "GO TOP", "HEADING", "IF", "INDEX", "INDEX ON", "INPUT",
                "JOIN", "KEYBOARD", "LABEL", "LABEL FORM", "LIST", "LOAD", "LOCATE", "LOOP", "MENU",
                "MENU TO", "NOTE", "ON ERROR", "ON KEY", "PACK", "PARAMETERS", "PLAY MACRO",
                "POP KEY", "POP MENU", "PRINT", "PRIVATE", "PROCEDURE", "PUBLIC", "PUSH KEY",
                "PUSH MENU", "QUIT", "READ", "READ MENU", "RECALL", "REINDEX", "RELEASE", "RELEASE ALL",
                "RENAME", "REPLACE", "REPORT", "REPORT FORM", "RESTORE", "RESUME", "RETURN", "ROLLBACK",
                "RUN", "SAVE", "SAVE MACROS", "SAVE SCREEN", "SAVE TO", "SAY", "SCAN", "SEEK", "SELECT",
                "SET", "SKIP", "SORT", "STORE", "SUM", "TEXT", "TOTAL", "TYPE", "UNLOCK", "UNLOCK ALL",
                "UPDATE", "USE", "WAIT", "ZAP",

                // Set commands
                "SET ALTERNATE ON", "SET ALTERNATE OFF", "SET ALTERNATE TO", "SET BELL ON", "SET BELL OFF",
                "SET CENTURY ON", "SET CENTURY OFF", "SET COLOR TO", "SET CONFIRM ON", "SET CONFIRM OFF",
                "SET CONSOLE ON", "SET CONSOLE OFF", "SET DATE ANSI", "SET DATE AMERICAN",
                "SET DATE BRITISH", "SET DATE FRENCH", "SET DATE GERMAN", "SET DATE ITALIAN",
                "SET DATE JAPANESE", "SET DATE MDY", "SET DATE DMY", "SET DATE YMD", "SET DECIMALS TO",
                "SET DEFAULT TO", "SET DELETED ON", "SET DELETED OFF", "SET DELIMITERS ON",
                "SET DELIMITERS OFF", "SET DELIMITERS TO", "SET DEVICE TO SCREEN", "SET DEVICE TO PRINTER",
                "SET EXACT ON", "SET EXACT OFF", "SET EXCLUSIVE ON", "SET EXCLUSIVE OFF", "SET FILTER TO",
                "SET FIXED ON", "SET FIXED OFF", "SET FORMAT TO", "SET FUNCTION TO", "SET HEADING ON",
                "SET HEADING OFF", "SET INDEX TO", "SET INTENSITY ON", "SET INTENSITY OFF", "SET KEY TO",
                "SET MARGIN TO", "SET MESSAGE TO", "SET ORDER TO", "SET PATH TO", "SET PRINTER ON",
                "SET PRINTER OFF", "SET PRINTER TO", "SET RELATION TO", "SET SCOPE TO", "SET SCOREBOARD ON",
                "SET SCOREBOARD OFF", "SET SOFTSEEK ON", "SET SOFTSEEK OFF", "SET TYPEAHEAD TO",
                "SET UNIQUE ON", "SET UNIQUE OFF",

                // Keywords
                "FUNCTION", "PROCEDURE", "RETURN", "LOCAL", "STATIC", "PUBLIC", "PRIVATE", "PARAMETERS",
                "DO", "CASE", "OTHERWISE", "ENDCASE", "IF", "ELSE", "ELSEIF", "ENDIF", "FOR", "TO",
                "STEP", "NEXT", "WHILE", "ENDDO", "EXIT", "LOOP", "BEGIN", "SEQUENCE", "TRY", "CATCH",
                "FINALLY", "END", "ENDSEQUENCE", "CLASS", "ENDCLASS", "METHOD", "ENDMETHOD", "DATA",
                "VAR", "INLINE", "INIT", "NIL", "SELF", "SUPER"
        };

        return new ArrayList<>(Arrays.asList(commands));
    }

    // Include paths methods
    public List<String> getIncludePaths() {
        return includePaths;
    }

    public void setIncludePaths(List<String> includePaths) {
        this.includePaths = includePaths;
    }

    // Documentation URL methods
    public String getDocumentationBaseUrl() {
        return documentationBaseUrl;
    }

    public void setDocumentationBaseUrl(String documentationBaseUrl) {
        this.documentationBaseUrl = documentationBaseUrl;
    }

    // Indentation size methods
    public int getIndentationSize() {
        return indentationSize;
    }

    public void setIndentationSize(int indentationSize) {
        this.indentationSize = indentationSize;
    }

    // Formatting settings methods
    public boolean isReturnStatementsAtLevel0() {
        return returnStatementsAtLevel0;
    }

    public void setReturnStatementsAtLevel0(boolean returnStatementsAtLevel0) {
        this.returnStatementsAtLevel0 = returnStatementsAtLevel0;
    }

    public boolean isLocalStatementsAtLevel0() {
        return localStatementsAtLevel0;
    }

    public void setLocalStatementsAtLevel0(boolean localStatementsAtLevel0) {
        this.localStatementsAtLevel0 = localStatementsAtLevel0;
    }


    /**
     * Resolves a path that might be relative to the project
     * @param project The project
     * @param path The path to resolve
     * @return The resolved absolute path
     */
    public String resolveRelativePath(Project project, String path) {
        if (path.startsWith("./") || path.startsWith("../")) {
            // Convert relative path to absolute based on project location
            String basePath = project.getBasePath();
            if (basePath != null) {
                File baseDir = new File(basePath);
                File resolvedPath = new File(baseDir, path);
                return resolvedPath.getAbsolutePath();
            }
        }
        return path;
    }

    /**
     * Gets all include paths, resolving any relative paths to absolute paths
     * @param project The project
     * @return List of resolved paths
     */
    public List<String> getResolvedIncludePaths(Project project) {
        List<String> resolvedPaths = new ArrayList<>();
        for (String path : includePaths) {
            resolvedPaths.add(resolveRelativePath(project, path));
        }
        return resolvedPaths;
    }

    @Nullable
    @Override
    public HarbourSettings getState() {
        return this;
    }

    @Override
    public void loadState(@NotNull HarbourSettings state) {
        XmlSerializerUtil.copyBean(state, this);
    }

    public static HarbourSettings getInstance(Project project) {
        return project.getService(HarbourSettings.class);
    }
}
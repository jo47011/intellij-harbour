package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import java.util.List;

/**
 * Information collected from a Harbour file for linting.
 * This is passed from collectInformation to doAnnotate in HarbourExternalAnnotator.
 */
public class HarbourLintInfo {
    private final String filePath;
    private final String fileContent;
    private final Project project;
    private final String harbourCompilerPath;
    private final List<String> extraIncludePaths;
    private final String extraOptions;
    private final int warningLevel;

    public HarbourLintInfo(String filePath, String fileContent, Project project,
                          String harbourCompilerPath, List<String> extraIncludePaths,
                          String extraOptions, int warningLevel) {
        this.filePath = filePath;
        this.fileContent = fileContent;
        this.project = project;
        this.harbourCompilerPath = harbourCompilerPath;
        this.extraIncludePaths = extraIncludePaths;
        this.extraOptions = extraOptions;
        this.warningLevel = warningLevel;
    }

    public String getFilePath() {
        return filePath;
    }

    public String getFileContent() {
        return fileContent;
    }

    public Project getProject() {
        return project;
    }

    public String getHarbourCompilerPath() {
        return harbourCompilerPath;
    }

    public List<String> getExtraIncludePaths() {
        return extraIncludePaths;
    }

    public String getExtraOptions() {
        return extraOptions;
    }

    public int getWarningLevel() {
        return warningLevel;
    }
}
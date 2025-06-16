package org.intellij.sdk.language;

import com.intellij.execution.ExecutionException;
import com.intellij.execution.Executor;
import com.intellij.execution.configurations.*;
import com.intellij.execution.runners.ExecutionEnvironment;
import com.intellij.openapi.options.SettingsEditor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.InvalidDataException;
import com.intellij.openapi.util.WriteExternalException;
import org.jdom.Element;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;

/**
 * Debug run configuration for Harbour applications.
 * Stores debug settings and creates debug states.
 */
public class HarbourDebuggerRunConfig extends RunConfigurationBase<Element> {
    private String executablePath;
    private String workingDirectory;
    private String programArguments;
    private String hbmk2Path;
    private String sourceFile;
    private String compilerOptions;
    private String sourcePath;
    private String debugPort = "6110";
    private String breakpointFile = "init.cld";
    private boolean useDirectExecution = false;

    protected HarbourDebuggerRunConfig(@NotNull Project project,
                                       @NotNull ConfigurationFactory factory,
                                       @Nullable String name) {
        super(project, factory, name);
    }

    @NotNull
    @Override
    public SettingsEditor<? extends RunConfiguration> getConfigurationEditor() {
        return new HarbourDebuggerSettingsEditor();
    }

    @Nullable
    @Override
    public RunProfileState getState(@NotNull Executor executor, @NotNull ExecutionEnvironment env)
            throws ExecutionException {
        return new HarbourDebuggerRunProfileState(env, this);
    }

    @Override
    public void checkConfiguration() throws RuntimeConfigurationException {
        if (useDirectExecution) {
            // When using direct execution, executable path must be specified
            if (executablePath == null || executablePath.isEmpty()) {
                throw new RuntimeConfigurationError("Executable path is not specified");
            }
        } else {
            // When compiling, need hbmk2 and source file
            if (hbmk2Path == null || hbmk2Path.isEmpty()) {
                throw new RuntimeConfigurationError("hbmk2 compiler path is not specified");
            }
            if (sourceFile == null || sourceFile.isEmpty()) {
                throw new RuntimeConfigurationError("Source file is not specified");
            }
        }

        // Set workingDirectory to sourceFile's directory if not specified
        if (workingDirectory == null || workingDirectory.isEmpty()) {
            if (useDirectExecution && executablePath != null) {
                File execFile = new File(executablePath);
                workingDirectory = execFile.getParent();
            } else if (sourceFile != null) {
                File sourceFileObj = new File(sourceFile);
                workingDirectory = sourceFileObj.getParent();
            }
        }
    }

    @Override
    public void readExternal(@NotNull Element element) throws InvalidDataException {
        super.readExternal(element);
        hbmk2Path = element.getAttributeValue("hbmk2Path");
        sourceFile = element.getAttributeValue("sourceFile");
        executablePath = element.getAttributeValue("executablePath");
        workingDirectory = element.getAttributeValue("workingDirectory");
        programArguments = element.getAttributeValue("programArguments");
        compilerOptions = element.getAttributeValue("compilerOptions");
        sourcePath = element.getAttributeValue("sourcePath");
        debugPort = element.getAttributeValue("debugPort", "6110");
        breakpointFile = element.getAttributeValue("breakpointFile", "init.cld");
        useDirectExecution = Boolean.parseBoolean(element.getAttributeValue("useDirectExecution", "false"));
    }

    @Override
    public void writeExternal(@NotNull Element element) throws WriteExternalException {
        super.writeExternal(element);
        if (hbmk2Path != null) {
            element.setAttribute("hbmk2Path", hbmk2Path);
        }
        if (sourceFile != null) {
            element.setAttribute("sourceFile", sourceFile);
        }
        if (executablePath != null) {
            element.setAttribute("executablePath", executablePath);
        }
        if (workingDirectory != null) {
            element.setAttribute("workingDirectory", workingDirectory);
        }
        if (programArguments != null) {
            element.setAttribute("programArguments", programArguments);
        }
        if (compilerOptions != null) {
            element.setAttribute("compilerOptions", compilerOptions);
        }
        if (sourcePath != null) {
            element.setAttribute("sourcePath", sourcePath);
        }
        element.setAttribute("debugPort", debugPort);
        element.setAttribute("breakpointFile", breakpointFile);
        element.setAttribute("useDirectExecution", String.valueOf(useDirectExecution));
    }

    // Getters and setters
    public String getHbmk2Path() {
        return hbmk2Path;
    }

    public void setHbmk2Path(String hbmk2Path) {
        this.hbmk2Path = hbmk2Path;
    }

    public String getSourceFile() {
        return sourceFile;
    }

    public void setSourceFile(String sourceFile) {
        this.sourceFile = sourceFile;
    }

    public String getExecutablePath() {
        return executablePath;
    }

    public void setExecutablePath(String executablePath) {
        this.executablePath = executablePath;
    }

    public String getWorkingDirectory() {
        return workingDirectory;
    }

    public void setWorkingDirectory(String workingDirectory) {
        this.workingDirectory = workingDirectory;
    }

    public String getProgramArguments() {
        return programArguments;
    }

    public void setProgramArguments(String programArguments) {
        this.programArguments = programArguments;
    }

    public String getCompilerOptions() {
        return compilerOptions;
    }

    public void setCompilerOptions(String compilerOptions) {
        this.compilerOptions = compilerOptions;
    }

    public String getSourcePath() {
        return sourcePath;
    }

    public void setSourcePath(String sourcePath) {
        this.sourcePath = sourcePath;
    }

    public String getDebugPort() {
        return debugPort;
    }
    
    public int getDebugPortAsInt() {
        try {
            return Integer.parseInt(debugPort);
        } catch (NumberFormatException e) {
            return 6110; // Default port
        }
    }

    public void setDebugPort(String debugPort) {
        this.debugPort = debugPort;
    }

    public String getBreakpointFile() {
        return breakpointFile;
    }

    public void setBreakpointFile(String breakpointFile) {
        this.breakpointFile = breakpointFile;
    }

    public boolean isUseDirectExecution() {
        return useDirectExecution;
    }

    public void setUseDirectExecution(boolean useDirectExecution) {
        this.useDirectExecution = useDirectExecution;
    }
}
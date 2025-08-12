package org.intellij.sdk.language;

import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.fileChooser.FileChooserDescriptor;
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory;
import com.intellij.openapi.fileChooser.FileChooserFactory;
import com.intellij.openapi.fileChooser.FileTextField;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.options.Configurable;
import com.intellij.openapi.options.ConfigurationException;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.Messages;
import com.intellij.openapi.ui.TextFieldWithBrowseButton;
import com.intellij.ui.AnActionButton;
import com.intellij.ui.AnActionButtonRunnable;
import com.intellij.ui.CollectionListModel;
import com.intellij.ui.ToolbarDecorator;
import com.intellij.ui.components.JBList;
import com.intellij.icons.AllIcons;
import org.jetbrains.annotations.Nls;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.awt.*;
import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;

/**
 * Settings UI for Harbour plugin
 */
public class HarbourSettingsConfigurable implements Configurable {
    private JPanel myMainPanel;
    private JBList<String> myExcludedFilesList;
    private CollectionListModel<String> myExcludedFilesModel;
    private JBList<String> myIncludePathsList;
    private CollectionListModel<String> myIncludePathsModel;
    private JBList<String> myHarbourCommandsList;
    private CollectionListModel<String> myHarbourCommandsModel;
    private final Project myProject;
    private JTextField myScanPathField;
    private JButton myScanButton;
    private JTextField myDocumentationBaseUrlField;
    private JTextField myDebugLogPathField;
    private JTextField myBuildOutputDirField;
    private JCheckBox myAutoCompletionEnabledCheckBox;
    
    // Linting settings components
    private JCheckBox myLintingEnabledCheckBox;
    private JCheckBox myLintOnSaveCheckBox;
    private JTextField myHarbourCompilerPathField;
    private JSpinner myLintWarningLevelSpinner;
    private JTextField myLintExtraOptionsField;
    private JTextField myLinterExclusionCommentField;
    
    // Navigation settings components
    private JSpinner myMaxNavigationResultsSpinner;
    private JSpinner myMaxNavigationLimitSpinner;

    public HarbourSettingsConfigurable(Project project) {
        myProject = project;
    }

    @Nls(capitalization = Nls.Capitalization.Title)
    @Override
    public String getDisplayName() {
        return "Harbour";
    }

    @Nullable
    @Override
    public JComponent createComponent() {
        myMainPanel = new JPanel(new BorderLayout());

        // Create a tabbed pane for different settings sections
        JTabbedPane tabbedPane = new JTabbedPane();

        // GENERAL TAB (Renamed from Links)
        JPanel generalPanel = new JPanel(new GridBagLayout());
        generalPanel.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

        GridBagConstraints constraints = new GridBagConstraints();
        constraints.fill = GridBagConstraints.HORIZONTAL;
        constraints.weightx = 1.0;
        constraints.insets = new Insets(5, 5, 5, 5);

        // Documentation base URL
        constraints.gridx = 0;
        constraints.gridy = 0;
        JLabel docBaseUrlLabel = new JLabel("Documentation base URL:");
        generalPanel.add(docBaseUrlLabel, constraints);

        constraints.gridx = 1;
        myDocumentationBaseUrlField = new JTextField();
        generalPanel.add(myDocumentationBaseUrlField, constraints);

        // Debug log path
        constraints.gridx = 0;
        constraints.gridy = 1;
        JLabel debugLogPathLabel = new JLabel("Debug log directory (empty to disable):");
        generalPanel.add(debugLogPathLabel, constraints);

        // Create the file browser in a non-deprecated way
        constraints.gridx = 1;
        myDebugLogPathField = new JTextField();
        JPanel debugPathPanel = new JPanel(new BorderLayout());
        debugPathPanel.add(myDebugLogPathField, BorderLayout.CENTER);

        JButton browseButton = new JButton("...");
        browseButton.addActionListener(e -> {
            // Check if project is already disposed
            if (myProject.isDisposed()) return;

            FileChooserDescriptor dirChooser = FileChooserDescriptorFactory.createSingleFolderDescriptor();
            com.intellij.openapi.fileChooser.FileChooser.chooseFile(
                    dirChooser,
                    myProject,
                    HarbourFileUtils.getVirtualFileFromPath(myDebugLogPathField.getText()), // Initial file from current path
                    file -> myDebugLogPathField.setText(HarbourFileUtils.normalizePathSeparators(file.getPath()))
            );
        });

        debugPathPanel.add(browseButton, BorderLayout.EAST);
        generalPanel.add(debugPathPanel, constraints);

        // Build output directory
        constraints.gridx = 0;
        constraints.gridy = 2;
        JLabel buildOutputDirLabel = new JLabel("Build output directory:");
        generalPanel.add(buildOutputDirLabel, constraints);

        constraints.gridx = 1;
        myBuildOutputDirField = new JTextField();
        generalPanel.add(myBuildOutputDirField, constraints);

        // Auto completion option
        constraints.gridx = 0;
        constraints.gridy = 3;
        constraints.gridwidth = 2;
        myAutoCompletionEnabledCheckBox = new JCheckBox("Enable auto-completion while typing (otherwise only on Ctrl+Space)");
        generalPanel.add(myAutoCompletionEnabledCheckBox, constraints);
        
        // Navigation results limit
        constraints.gridx = 0;
        constraints.gridy = 4;
        constraints.gridwidth = 2;
        JLabel maxNavResultsLabel = new JLabel("Max preload results:");
        generalPanel.add(maxNavResultsLabel, constraints);
        
        // Explanation below the label
        constraints.gridy = 5;
        JLabel navResultsExplanation = new JLabel("<html><i>Number of results to show before 'Load All' button appears</i></html>");
        navResultsExplanation.setFont(navResultsExplanation.getFont().deriveFont(Font.ITALIC));
        generalPanel.add(navResultsExplanation, constraints);
        
        // Spinner on next line
        constraints.gridy = 6;
        constraints.gridwidth = 1;
        SpinnerModel navResultsModel = new SpinnerNumberModel(20, 10, 500, 10);
        myMaxNavigationResultsSpinner = new JSpinner(navResultsModel);
        myMaxNavigationResultsSpinner.setToolTipText("Initial results to show before 'Load All' button appears");
        generalPanel.add(myMaxNavigationResultsSpinner, constraints);
        
        // Max navigation limit label
        constraints.gridx = 0;
        constraints.gridy = 7;
        constraints.gridwidth = 2;
        JLabel maxNavLimitLabel = new JLabel("Max navigation limit:");
        generalPanel.add(maxNavLimitLabel, constraints);
        
        // Explanation for max limit
        constraints.gridy = 8;
        JLabel navLimitExplanation = new JLabel("<html><i>Absolute maximum results to load (for functions like Message())</i></html>");
        navLimitExplanation.setFont(navLimitExplanation.getFont().deriveFont(11f));
        generalPanel.add(navLimitExplanation, constraints);
        
        // Max limit spinner
        constraints.gridy = 9;
        constraints.gridwidth = 1;
        SpinnerModel navLimitModel = new SpinnerNumberModel(1200, 100, 5000, 100);
        myMaxNavigationLimitSpinner = new JSpinner(navLimitModel);
        myMaxNavigationLimitSpinner.setToolTipText("Never load more than this many results");
        generalPanel.add(myMaxNavigationLimitSpinner, constraints);

        // Add spacer to general panel
        constraints.gridx = 0;
        constraints.gridy = 10;
        constraints.weighty = 1.0;
        constraints.gridwidth = 2;
        constraints.fill = GridBagConstraints.BOTH;
        generalPanel.add(new JPanel(), constraints);

        // INCLUDE PATHS TAB
        JPanel includePathsPanel = new JPanel(new BorderLayout());

        // Create list model for include paths
        myIncludePathsModel = new CollectionListModel<>();
        myIncludePathsList = new JBList<>(myIncludePathsModel);

        // Create UI for include paths with add/remove/move buttons
        ToolbarDecorator includePathsDecorator = ToolbarDecorator.createDecorator(myIncludePathsList)
                .setAddAction(createAddPathAction())
                .setRemoveAction(createRemovePathAction())
                .setMoveUpAction(anActionButton -> moveIncludePath(-1))
                .setMoveDownAction(anActionButton -> moveIncludePath(1))
                .addExtraAction(new AnActionButton("Copy Path", AllIcons.Actions.Copy) {
                    @Override
                    public void actionPerformed(@NotNull AnActionEvent e) {
                        copySelectedIncludePath();
                    }
                });

        JPanel includePathsListPanel = new JPanel(new BorderLayout());
        includePathsListPanel.add(
                new JLabel("Include Paths (both absolute and relative paths are supported):"),
                BorderLayout.NORTH
        );
        includePathsListPanel.add(includePathsDecorator.createPanel(), BorderLayout.CENTER);

        // Auto-scan panel
        JPanel scanPanel = new JPanel(new BorderLayout());
        scanPanel.setBorder(BorderFactory.createTitledBorder("Auto-Scan"));

        myScanPathField = new JTextField();
        myScanButton = new JButton("Scan for Include Directories");

        JPanel scanControlsPanel = new JPanel(new BorderLayout());
        scanControlsPanel.add(new JLabel("Root Directory:"), BorderLayout.WEST);
        scanControlsPanel.add(myScanPathField, BorderLayout.CENTER);

        scanPanel.add(scanControlsPanel, BorderLayout.NORTH);
        scanPanel.add(myScanButton, BorderLayout.SOUTH);

        // Action for the scan button
        myScanButton.addActionListener(e -> scanForIncludeDirs());

        includePathsPanel.add(includePathsListPanel, BorderLayout.CENTER);
        includePathsPanel.add(scanPanel, BorderLayout.SOUTH);

        // EXCLUDED FILES TAB
        JPanel excludedFilesPanel = new JPanel(new BorderLayout());

        // Create model for excluded files
        myExcludedFilesModel = new CollectionListModel<>();
        myExcludedFilesList = new JBList<>(myExcludedFilesModel);

        // Create UI for excluded files with add/remove buttons
        ToolbarDecorator excludedFilesDecorator = ToolbarDecorator.createDecorator(myExcludedFilesList)
                .setAddAction(button -> {
                    String filename = Messages.showInputDialog(
                            myMainPanel,
                            "Enter filename to exclude (e.g. test.prg):",
                            "Add Excluded File",
                            null);

                    if (filename != null && !filename.isEmpty()) {
                        myExcludedFilesModel.add(filename);
                    }
                })
                .setRemoveAction(button -> {
                    int selectedIndex = myExcludedFilesList.getSelectedIndex();
                    if (selectedIndex != -1) {
                        myExcludedFilesModel.remove(selectedIndex);
                    }
                });

        JPanel excludedFilesListPanel = new JPanel(new BorderLayout());
        excludedFilesListPanel.add(
                new JLabel("Files excluded from navigation (won't be indexed):"),
                BorderLayout.NORTH
        );
        excludedFilesListPanel.add(excludedFilesDecorator.createPanel(), BorderLayout.CENTER);

        excludedFilesPanel.add(excludedFilesListPanel, BorderLayout.CENTER);


        // Add all tabs to the tabbed pane (General first)
        tabbedPane.addTab("General", generalPanel);
        tabbedPane.addTab("Include Paths", includePathsPanel);
        tabbedPane.addTab("Excluded Files", excludedFilesPanel);
        tabbedPane.addTab("Commands", createCommandsPanel());
        tabbedPane.addTab("Linting", createLintingPanel());

        myMainPanel.add(tabbedPane, BorderLayout.CENTER);

        loadSettings();

        return myMainPanel;
    }

    /**
     * Creates the Harbour commands panel
     */
    private JPanel createCommandsPanel() {
        JPanel commandsPanel = new JPanel(new BorderLayout());

        // Create model for commands list
        myHarbourCommandsModel = new CollectionListModel<>();
        myHarbourCommandsList = new JBList<>(myHarbourCommandsModel);

        // Create UI for commands with add/remove/edit buttons
        ToolbarDecorator commandsDecorator = ToolbarDecorator.createDecorator(myHarbourCommandsList)
                .setAddAction(button -> {
                    String command = Messages.showInputDialog(
                            myMainPanel,
                            "Enter Harbour command (in uppercase):",
                            "Add Command",
                            null);

                    if (command != null && !command.isEmpty()) {
                        // Convert to uppercase for consistency
                        command = command.toUpperCase();
                        if (!myHarbourCommandsModel.getItems().contains(command)) {
                            myHarbourCommandsModel.add(command);
                        }
                    }
                })
                .setRemoveAction(button -> {
                    int selectedIndex = myHarbourCommandsList.getSelectedIndex();
                    if (selectedIndex >= 0) {
                        myHarbourCommandsModel.remove(selectedIndex);
                    }
                })
                .setEditAction(button -> {
                    int selectedIndex = myHarbourCommandsList.getSelectedIndex();
                    if (selectedIndex >= 0) {
                        String oldCommand = myHarbourCommandsModel.getElementAt(selectedIndex);
                        String newCommand = Messages.showInputDialog(
                                myMainPanel,
                                "Edit Harbour command:",
                                "Edit Command",
                                null,
                                oldCommand,
                                null);

                        if (newCommand != null && !newCommand.isEmpty()) {
                            // Convert to uppercase for consistency
                            newCommand = newCommand.toUpperCase();
                            myHarbourCommandsModel.setElementAt(newCommand, selectedIndex);
                        }
                    }
                });

        // Add buttons for resetting to defaults and sorting
        commandsDecorator.addExtraAction(new AnActionButton("Reset to Defaults", null) {
            @Override
            public void actionPerformed(@NotNull AnActionEvent e) {
                int result = Messages.showYesNoDialog(
                        myMainPanel,
                        "This will reset all commands to the default list. Continue?",
                        "Reset to Defaults",
                        null);

                if (result == Messages.YES) {
                    resetCommandsToDefaults();
                }
            }
        });

        commandsDecorator.addExtraAction(new AnActionButton("Sort", null) {
            @Override
            public void actionPerformed(@NotNull AnActionEvent e) {
                sortCommands();
            }
        });

        JPanel commandsListPanel = new JPanel(new BorderLayout());
        commandsListPanel.add(
                new JLabel("Harbour commands for code completion:"),
                BorderLayout.NORTH
        );
        commandsListPanel.add(commandsDecorator.createPanel(), BorderLayout.CENTER);

        commandsPanel.add(commandsListPanel, BorderLayout.CENTER);

        return commandsPanel;
    }

    /**
     * Creates the Linting settings panel
     */
    private JPanel createLintingPanel() {
        JPanel lintingPanel = new JPanel(new BorderLayout());
        lintingPanel.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

        JPanel settingsPanel = new JPanel(new GridBagLayout());
        GridBagConstraints constraints = new GridBagConstraints();
        constraints.fill = GridBagConstraints.HORIZONTAL;
        constraints.weightx = 1.0;
        constraints.insets = new Insets(5, 5, 5, 5);

        // Enable linting checkbox
        constraints.gridx = 0;
        constraints.gridy = 0;
        constraints.gridwidth = 2;
        myLintingEnabledCheckBox = new JCheckBox("Enable linting (runs Harbour compiler for syntax checking)");
        settingsPanel.add(myLintingEnabledCheckBox, constraints);
        
        // Lint on save checkbox
        constraints.gridx = 0;
        constraints.gridy = 1;
        constraints.gridwidth = 2;
        myLintOnSaveCheckBox = new JCheckBox("Lint on save only (uncheck for real-time linting)");
        myLintOnSaveCheckBox.setToolTipText("When checked, linting runs only when file is saved. When unchecked, linting runs as you type (slower).");
        settingsPanel.add(myLintOnSaveCheckBox, constraints);

        // Harbour compiler path
        constraints.gridx = 0;
        constraints.gridy = 2;
        constraints.gridwidth = 2;
        JLabel compilerPathLabel = new JLabel("Harbour compiler path:");
        settingsPanel.add(compilerPathLabel, constraints);
        
        // Explanation below the label
        constraints.gridy = 3;
        String os = System.getProperty("os.name").toLowerCase();
        String compilerName = os.contains("win") ? "harbour.exe" : "harbour";
        String buildToolName = os.contains("win") ? "hbmk2.exe" : "hbmk2";
        String examplePath = os.contains("win") ? "C:\\harbour\\bin\\harbour.exe" : "/usr/local/bin/harbour";
        JLabel compilerPathExplanation = new JLabel("<html><i>Use " + compilerName + " (the compiler), not " + buildToolName + " (the build tool)</i></html>");
        compilerPathExplanation.setFont(compilerPathExplanation.getFont().deriveFont(Font.ITALIC));
        settingsPanel.add(compilerPathExplanation, constraints);

        // Compiler path text field
        constraints.gridx = 0;
        constraints.gridy = 4;
        constraints.gridwidth = 2;
        myHarbourCompilerPathField = new JTextField();
        myHarbourCompilerPathField.setToolTipText("Path to " + compilerName + " (the compiler), NOT " + buildToolName + " (the build tool). Example: " + examplePath);
        JPanel compilerPathPanel = new JPanel(new BorderLayout());
        compilerPathPanel.add(myHarbourCompilerPathField, BorderLayout.CENTER);

        JButton browseCompilerButton = new JButton("...");
        browseCompilerButton.addActionListener(e -> {
            FileChooserDescriptor descriptor = FileChooserDescriptorFactory.createSingleFileDescriptor();
            descriptor.setTitle("Select Harbour Compiler");
            descriptor.setDescription("Select " + compilerName + " (the compiler), NOT " + buildToolName + ". Usually located in harbour/bin directory.");
            
            VirtualFile[] selectedFiles = FileChooserFactory.getInstance()
                    .createFileChooser(descriptor, myProject, null)
                    .choose(myProject, VirtualFile.EMPTY_ARRAY);
            
            VirtualFile selectedFile = (selectedFiles.length > 0) ? selectedFiles[0] : null;
            
            if (selectedFile != null) {
                myHarbourCompilerPathField.setText(selectedFile.getPath());
            }
        });
        compilerPathPanel.add(browseCompilerButton, BorderLayout.EAST);
        settingsPanel.add(compilerPathPanel, constraints);

        // Warning level
        constraints.gridx = 0;
        constraints.gridy = 5;
        constraints.gridwidth = 1;
        JLabel warningLevelLabel = new JLabel("Warning level:");
        settingsPanel.add(warningLevelLabel, constraints);

        constraints.gridx = 1;
        SpinnerModel warningLevelModel = new SpinnerNumberModel(1, 0, 3, 1);
        myLintWarningLevelSpinner = new JSpinner(warningLevelModel);
        JPanel spinnerPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));
        spinnerPanel.add(myLintWarningLevelSpinner);
        spinnerPanel.add(new JLabel("(0=none, 1=low, 2=medium, 3=high)"));
        settingsPanel.add(spinnerPanel, constraints);

        // Extra options
        constraints.gridx = 0;
        constraints.gridy = 6;
        JLabel extraOptionsLabel = new JLabel("Extra compiler options:");
        settingsPanel.add(extraOptionsLabel, constraints);

        constraints.gridx = 1;
        myLintExtraOptionsField = new JTextField();
        myLintExtraOptionsField.setToolTipText("Additional options to pass to the Harbour compiler (e.g., -DMYDEFINE)");
        settingsPanel.add(myLintExtraOptionsField, constraints);
        
        // Linter exclusion comment
        constraints.gridx = 0;
        constraints.gridy = 7;
        constraints.gridwidth = 1;
        JLabel exclusionCommentLabel = new JLabel("Exclude lines with comment:");
        settingsPanel.add(exclusionCommentLabel, constraints);
        
        constraints.gridx = 1;
        myLinterExclusionCommentField = new JTextField();
        myLinterExclusionCommentField.setToolTipText("Lines with comments starting with this word will be excluded from linting (e.g., // noqa, /* noqa comment */)");
        settingsPanel.add(myLinterExclusionCommentField, constraints);

        // Note about include paths
        constraints.gridx = 0;
        constraints.gridy = 8;
        constraints.gridwidth = 2;
        constraints.weighty = 0.1;
        JLabel includePathsNote = new JLabel("<html><i>Note: Linting uses the include paths configured in Tools → Harbour → Include Paths</i></html>");
        includePathsNote.setFont(includePathsNote.getFont().deriveFont(Font.ITALIC));
        settingsPanel.add(includePathsNote, constraints);

        lintingPanel.add(settingsPanel, BorderLayout.CENTER);

        return lintingPanel;
    }

    /**
     * Reset the commands list to default values
     */
    private void resetCommandsToDefaults() {
        myHarbourCommandsModel.removeAll();
        List<String> defaultCommands = HarbourSettings.getDefaultHarbourCommands();
        for (String command : defaultCommands) {
            myHarbourCommandsModel.add(command);
        }
    }

    /**
     * Sort the commands alphabetically
     */
    private void sortCommands() {
        List<String> commands = new ArrayList<>(myHarbourCommandsModel.getItems());
        Collections.sort(commands);

        myHarbourCommandsModel.removeAll();
        for (String command : commands) {
            myHarbourCommandsModel.add(command);
        }
    }

    /**
     * Move the selected path up or down in the list
     * @param direction -1 for up, 1 for down
     */
    private void moveIncludePath(int direction) {
        int selectedIndex = myIncludePathsList.getSelectedIndex();
        if (selectedIndex < 0) {
            return; // No selection
        }

        int newIndex = selectedIndex + direction;
        if (newIndex < 0 || newIndex >= myIncludePathsModel.getSize()) {
            return; // Out of bounds
        }

        // Swap items
        String selectedPath = myIncludePathsModel.getElementAt(selectedIndex);
        String targetPath = myIncludePathsModel.getElementAt(newIndex);

        myIncludePathsModel.setElementAt(targetPath, selectedIndex);
        myIncludePathsModel.setElementAt(selectedPath, newIndex);

        // Update selection
        myIncludePathsList.setSelectedIndex(newIndex);
    }
    
    /**
     * Copy the selected include path to clipboard
     */
    private void copySelectedIncludePath() {
        int selectedIndex = myIncludePathsList.getSelectedIndex();
        if (selectedIndex < 0) {
            Messages.showWarningDialog(
                myMainPanel,
                "Please select a path to copy",
                "No Selection"
            );
            return;
        }
        
        String selectedPath = myIncludePathsModel.getElementAt(selectedIndex);
        
        // Copy to clipboard
        java.awt.datatransfer.StringSelection selection = new java.awt.datatransfer.StringSelection(selectedPath);
        java.awt.Toolkit.getDefaultToolkit().getSystemClipboard().setContents(selection, null);
        
        Messages.showInfoMessage(
            myMainPanel,
            "Path copied to clipboard:\n" + selectedPath,
            "Path Copied"
        );
    }

    private AnActionButtonRunnable createAddPathAction() {
        return button -> {
            String path = Messages.showInputDialog(
                    myMainPanel,
                    "Enter include path (absolute or relative to project):",
                    "Add Include Path",
                    null);

            if (path != null && !path.isEmpty()) {
                // For relative paths, don't check if they exist
                boolean isRelativePath = path.startsWith("./") || path.startsWith("../");

                if (!isRelativePath) {
                    // Check if the absolute path exists
                    File file = new File(path);
                    if (!file.exists() || !file.isDirectory()) {
                        int result = Messages.showYesNoDialog(
                                myMainPanel,
                                "The specified path does not exist or is not a directory. Add anyway?",
                                "Warning",
                                null);
                        if (result != Messages.YES) {
                            return;
                        }
                    }
                }

                if (!myIncludePathsModel.getItems().contains(path)) {
                    myIncludePathsModel.add(path);
                }
            }
        };
    }

    private AnActionButtonRunnable createRemovePathAction() {
        return button -> {
            int selectedIndex = myIncludePathsList.getSelectedIndex();
            if (selectedIndex >= 0) {
                myIncludePathsModel.remove(selectedIndex);
            }
        };
    }

    private void scanForIncludeDirs() {
        String rootPath = myScanPathField.getText();
        if (rootPath.isEmpty()) {
            Messages.showWarningDialog(
                    myMainPanel,
                    "Please specify a root directory to scan.",
                    "Warning");
            return;
        }

        File rootDir = new File(rootPath);
        if (!rootDir.exists() || !rootDir.isDirectory()) {
            Messages.showWarningDialog(
                    myMainPanel,
                    "The specified path does not exist or is not a directory.",
                    "Warning");
            return;
        }

        // Start a background process to scan
        setCursor(Cursor.getPredefinedCursor(Cursor.WAIT_CURSOR));
        try {
            List<String> foundPaths = findIncludeDirectories(rootDir);
            int addedCount = 0;

            for (String path : foundPaths) {
                if (!myIncludePathsModel.getItems().contains(path)) {
                    myIncludePathsModel.add(path);
                    addedCount++;
                }
            }

            Messages.showInfoMessage(
                    myMainPanel,
                    "Found " + foundPaths.size() + " potential include directories. Added " + addedCount + " new paths.",
                    "Scan Complete");

        } finally {
            setCursor(Cursor.getDefaultCursor());
        }
    }

    private void setCursor(Cursor cursor) {
        if (myMainPanel != null) {
            myMainPanel.setCursor(cursor);
        }
    }

    /**
     * Recursively find potential include directories
     */
    private List<String> findIncludeDirectories(File rootDir) {
        List<String> result = new ArrayList<>();
        scanDirectory(rootDir, result);
        return result;
    }

    private void scanDirectory(File dir, List<String> result) {
        // Check if this might be an include directory
        if (isLikelyIncludeDir(dir)) {
            result.add(dir.getAbsolutePath());
        }

        // Only go 5 levels deep max to avoid excessive scanning
        int maxDepth = 5;
        scanSubdirectories(dir, result, 0, maxDepth);
    }

    private void scanSubdirectories(File dir, List<String> result, int currentDepth, int maxDepth) {
        if (currentDepth >= maxDepth) {
            return;
        }

        File[] subdirs = dir.listFiles(File::isDirectory);
        if (subdirs == null) {
            return;
        }

        for (File subdir : subdirs) {
            if (isLikelyIncludeDir(subdir)) {
                result.add(subdir.getAbsolutePath());
            }
            scanSubdirectories(subdir, result, currentDepth + 1, maxDepth);
        }
    }

    private boolean isLikelyIncludeDir(File dir) {
        // Check if the directory name suggests it's an include directory
        String dirName = dir.getName().toLowerCase();
        if (dirName.contains("include") || dirName.equals("inc")) {
            return true;
        }

        // Check if it contains .ch files
        File[] chFiles = dir.listFiles((d, name) -> name.toLowerCase().endsWith(".ch"));
        return chFiles != null && chFiles.length > 0;
    }

    @Override
    public boolean isModified() {
        HarbourSettings settings = HarbourSettings.getInstance(myProject);
        return !settings.getIncludePaths().equals(new ArrayList<>(myIncludePathsModel.getItems())) ||
                !settings.getExcludedFiles().equals(new HashSet<>(myExcludedFilesModel.getItems())) ||
                !settings.getHarbourCommands().equals(new ArrayList<>(myHarbourCommandsModel.getItems())) ||
                !settings.getDocumentationBaseUrl().equals(myDocumentationBaseUrlField.getText()) ||
                !settings.getDebugLogPath().equals(myDebugLogPathField.getText()) ||
                !settings.getBuildOutputDirectory().equals(myBuildOutputDirField.getText()) ||
                settings.isAutoCompletionEnabled() != myAutoCompletionEnabledCheckBox.isSelected() ||
                settings.isLintingEnabled() != myLintingEnabledCheckBox.isSelected() ||
                settings.isLintOnSave() != myLintOnSaveCheckBox.isSelected() ||
                !settings.getHarbourCompilerPath().equals(myHarbourCompilerPathField.getText()) ||
                settings.getLintWarningLevel() != (Integer) myLintWarningLevelSpinner.getValue() ||
                !settings.getLintExtraOptions().equals(myLintExtraOptionsField.getText()) ||
                !settings.getLinterExclusionComment().equals(myLinterExclusionCommentField.getText()) ||
                settings.getMaxNavigationResults() != (Integer) myMaxNavigationResultsSpinner.getValue() ||
                settings.getMaxNavigationLimit() != (Integer) myMaxNavigationLimitSpinner.getValue();
    }

    @Override
    public void apply() throws ConfigurationException {
        HarbourSettings settings = HarbourSettings.getInstance(myProject);
        settings.setIncludePaths(new ArrayList<>(myIncludePathsModel.getItems()));
        settings.setExcludedFiles(new HashSet<>(myExcludedFilesModel.getItems()));
        settings.setHarbourCommands(new ArrayList<>(myHarbourCommandsModel.getItems()));

        // Save documentation base URL
        settings.setDocumentationBaseUrl(myDocumentationBaseUrlField.getText());

        // Save debug log path
        settings.setDebugLogPath(myDebugLogPathField.getText());

        // Save build output directory
        settings.setBuildOutputDirectory(myBuildOutputDirField.getText());

        // Save auto-completion setting
        settings.setAutoCompletionEnabled(myAutoCompletionEnabledCheckBox.isSelected());

        // Save linting settings
        settings.setLintingEnabled(myLintingEnabledCheckBox.isSelected());
        settings.setLintOnSave(myLintOnSaveCheckBox.isSelected());
        settings.setHarbourCompilerPath(myHarbourCompilerPathField.getText());
        settings.setLintWarningLevel((Integer) myLintWarningLevelSpinner.getValue());
        settings.setLintExtraOptions(myLintExtraOptionsField.getText());
        settings.setLinterExclusionComment(myLinterExclusionCommentField.getText());
        
        // Save navigation settings
        settings.setMaxNavigationResults((Integer) myMaxNavigationResultsSpinner.getValue());
        settings.setMaxNavigationLimit((Integer) myMaxNavigationLimitSpinner.getValue());

        // Notify HarbourReferenceService to update exclusions
        HarbourReferenceService service = HarbourReferenceService.getInstance(myProject);
        if (service != null) {
            service.refreshExclusions();
        }
        
        // Ensure function classification service is initialized  
        HarbourFunctionClassificationService classificationService = 
            HarbourFunctionClassificationService.getInstance(myProject);
        if (!classificationService.isInitialized()) {
            HarbourLogger.log("Settings", "Triggering function classification scan on settings apply");
            classificationService.rescanProject();
        }
    }

    @Override
    public void reset() {
        loadSettings();
    }

    private void loadSettings() {
        HarbourSettings settings = HarbourSettings.getInstance(myProject);

        // Load include paths
        myIncludePathsModel.removeAll();
        for (String path : settings.getIncludePaths()) {
            myIncludePathsModel.add(path);
        }

        // Load excluded files
        myExcludedFilesModel.removeAll();
        for (String filename : settings.getExcludedFiles()) {
            myExcludedFilesModel.add(filename);
        }

        // Load Harbour commands
        myHarbourCommandsModel.removeAll();
        for (String command : settings.getHarbourCommands()) {
            myHarbourCommandsModel.add(command);
        }

        // Load documentation base URL
        myDocumentationBaseUrlField.setText(settings.getDocumentationBaseUrl());

        // Load debug log path
        myDebugLogPathField.setText(settings.getDebugLogPath());

        // Load build output directory
        myBuildOutputDirField.setText(settings.getBuildOutputDirectory());

        // Load auto-completion setting
        myAutoCompletionEnabledCheckBox.setSelected(settings.isAutoCompletionEnabled());

        // Load linting settings
        myLintingEnabledCheckBox.setSelected(settings.isLintingEnabled());
        myLintOnSaveCheckBox.setSelected(settings.isLintOnSave());
        myHarbourCompilerPathField.setText(settings.getHarbourCompilerPath());
        myLintWarningLevelSpinner.setValue(settings.getLintWarningLevel());
        myLintExtraOptionsField.setText(settings.getLintExtraOptions());
        myLinterExclusionCommentField.setText(settings.getLinterExclusionComment());
        
        // Load navigation settings
        myMaxNavigationResultsSpinner.setValue(settings.getMaxNavigationResults());
        myMaxNavigationLimitSpinner.setValue(settings.getMaxNavigationLimit());

        // Default scan path to the project base path
        String defaultScanPath = myProject.getBasePath();
        if (defaultScanPath == null) {
            defaultScanPath = "";
        }
        myScanPathField.setText(defaultScanPath);
    }
}
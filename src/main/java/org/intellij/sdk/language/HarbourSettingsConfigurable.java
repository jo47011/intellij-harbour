package org.intellij.sdk.language;

import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.fileChooser.FileChooserDescriptor;
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory;
import com.intellij.openapi.fileChooser.FileChooserFactory;
import com.intellij.openapi.fileChooser.FileTextField;
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
    private JSpinner myIndentationSizeSpinner;
    private JCheckBox myReturnStatementsAtLevel0CheckBox;
    private JCheckBox myLocalStatementsAtLevel0CheckBox;
    private JCheckBox myAutoCompletionEnabledCheckBox;
    private JSpinner myLineBreakPositionSpinner;

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

        // Add spacer to general panel
        constraints.gridx = 0;
        constraints.gridy = 4;
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
                .setMoveDownAction(anActionButton -> moveIncludePath(1));

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

        // FORMATTER SETTINGS TAB
        JPanel formatterPanel = new JPanel(new GridBagLayout());
        formatterPanel.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

        GridBagConstraints formatterConstraints = new GridBagConstraints();
        formatterConstraints.fill = GridBagConstraints.HORIZONTAL;
        formatterConstraints.weightx = 1.0;
        formatterConstraints.gridx = 0;
        formatterConstraints.gridy = 0;
        formatterConstraints.insets = new Insets(5, 5, 5, 5);

        // Indentation size
        JLabel indentationSizeLabel = new JLabel("Indentation size (spaces):");
        formatterPanel.add(indentationSizeLabel, formatterConstraints);

        formatterConstraints.gridx = 1;
        myIndentationSizeSpinner = new JSpinner(new SpinnerNumberModel(2, 1, 8, 1));
        JComponent editor = myIndentationSizeSpinner.getEditor();
        JFormattedTextField ftf = ((JSpinner.DefaultEditor) editor).getTextField();
        ftf.setColumns(2);
        formatterPanel.add(myIndentationSizeSpinner, formatterConstraints);

        // Line break position
        formatterConstraints.gridx = 0;
        formatterConstraints.gridy = 1;
        JLabel lineBreakPositionLabel = new JLabel("Line break position (0 = no breaking):");
        formatterPanel.add(lineBreakPositionLabel, formatterConstraints);

        formatterConstraints.gridx = 1;
        myLineBreakPositionSpinner = new JSpinner(new SpinnerNumberModel(99, 0, 999, 1));
        JComponent lineBreakEditor = myLineBreakPositionSpinner.getEditor();
        JFormattedTextField lineBreakFtf = ((JSpinner.DefaultEditor) lineBreakEditor).getTextField();
        lineBreakFtf.setColumns(3);
        formatterPanel.add(myLineBreakPositionSpinner, formatterConstraints);

        // Return statements checkbox
        formatterConstraints.gridx = 0;
        formatterConstraints.gridy = 2;
        formatterConstraints.gridwidth = 2;
        myReturnStatementsAtLevel0CheckBox = new JCheckBox("Format 'return' statements at level 0 at the end of functions");
        formatterPanel.add(myReturnStatementsAtLevel0CheckBox, formatterConstraints);

        // Local statements checkbox
        formatterConstraints.gridx = 0;
        formatterConstraints.gridy = 3;
        formatterConstraints.gridwidth = 2;
        myLocalStatementsAtLevel0CheckBox = new JCheckBox("Format 'local' declarations at level 0");
        formatterPanel.add(myLocalStatementsAtLevel0CheckBox, formatterConstraints);

        // Add spacer
        formatterConstraints.gridx = 0;
        formatterConstraints.gridy = 4;
        formatterConstraints.weighty = 1.0;
        formatterConstraints.gridwidth = 2;
        formatterConstraints.fill = GridBagConstraints.BOTH;
        formatterPanel.add(new JPanel(), formatterConstraints);

        // Add all tabs to the tabbed pane (General first)
        tabbedPane.addTab("General", generalPanel);
        tabbedPane.addTab("Include Paths", includePathsPanel);
        tabbedPane.addTab("Excluded Files", excludedFilesPanel);
        tabbedPane.addTab("Commands", createCommandsPanel());
        tabbedPane.addTab("Formatting", formatterPanel);

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
                settings.getIndentationSize() != (Integer) myIndentationSizeSpinner.getValue() ||
                settings.getLineBreakPosition() != (Integer) myLineBreakPositionSpinner.getValue() ||
                settings.isReturnStatementsAtLevel0() != myReturnStatementsAtLevel0CheckBox.isSelected() ||
                settings.isLocalStatementsAtLevel0() != myLocalStatementsAtLevel0CheckBox.isSelected() ||
                settings.isAutoCompletionEnabled() != myAutoCompletionEnabledCheckBox.isSelected();
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

        // Save indentation size
        settings.setIndentationSize((Integer) myIndentationSizeSpinner.getValue());

        // Save line break position
        settings.setLineBreakPosition((Integer) myLineBreakPositionSpinner.getValue());

        // Save formatting settings
        settings.setReturnStatementsAtLevel0(myReturnStatementsAtLevel0CheckBox.isSelected());
        settings.setLocalStatementsAtLevel0(myLocalStatementsAtLevel0CheckBox.isSelected());

        // Save auto-completion setting
        settings.setAutoCompletionEnabled(myAutoCompletionEnabledCheckBox.isSelected());

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

        // Load indentation size
        myIndentationSizeSpinner.setValue(settings.getIndentationSize());

        // Load line break position
        myLineBreakPositionSpinner.setValue(settings.getLineBreakPosition());

        // Load formatting settings
        myReturnStatementsAtLevel0CheckBox.setSelected(settings.isReturnStatementsAtLevel0());
        myLocalStatementsAtLevel0CheckBox.setSelected(settings.isLocalStatementsAtLevel0());

        // Load auto-completion setting
        myAutoCompletionEnabledCheckBox.setSelected(settings.isAutoCompletionEnabled());

        // Default scan path to the project base path
        String defaultScanPath = myProject.getBasePath();
        if (defaultScanPath == null) {
            defaultScanPath = "";
        }
        myScanPathField.setText(defaultScanPath);
    }
}
package org.intellij.sdk.language;

import com.intellij.openapi.fileChooser.FileChooserDescriptor;
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory;
import com.intellij.openapi.options.ConfigurationException;
import com.intellij.openapi.options.SettingsEditor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.LabeledComponent;
import com.intellij.openapi.ui.TextFieldWithBrowseButton;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.ui.components.JBTextField;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;

/**
 * Settings editor for Harbour debug configuration.
 */
public class HarbourDebuggerSettingsEditor extends SettingsEditor<HarbourDebuggerRunConfig> {
    private JPanel mainPanel;
    private JPanel executionPanel;
    private JPanel compilePanel;
    private JPanel directPanel;
    private JPanel commonPanel;

    private TextFieldWithBrowseButton hbmk2PathField;
    private TextFieldWithBrowseButton sourceFileField;
    private TextFieldWithBrowseButton workingDirField;
    private JTextField compilerOptionsField;
    private TextFieldWithBrowseButton executablePathField;
    private JTextField programArgsField;
    private JTextField breakpointFileField;
    private JCheckBox useDirectExecutionCheckbox;

    public HarbourDebuggerSettingsEditor() {
        createUIComponents();
    }

    private void createUIComponents() {
        // Main panel layout
        mainPanel = new JPanel(new BorderLayout());

        // Create the common panel (top section)
        commonPanel = new JPanel(new GridBagLayout());
        GridBagConstraints c = new GridBagConstraints();
        c.fill = GridBagConstraints.HORIZONTAL;
        c.weightx = 1.0;
        c.gridwidth = GridBagConstraints.REMAINDER;
        c.insets = new Insets(5, 5, 5, 5);

        // Working directory
        workingDirField = new TextFieldWithBrowseButton();
        FileChooserDescriptor workingDirChooser = FileChooserDescriptorFactory.createSingleFolderDescriptor();
        workingDirField.addActionListener(e -> {
            com.intellij.openapi.fileChooser.FileChooser.chooseFile(
                    workingDirChooser,
                    null,
                    null,
                    file -> workingDirField.setText(file.getPath())
            );
        });
        commonPanel.add(createLabeledField("Working Directory:", workingDirField), c);

        // Program arguments
        programArgsField = new JTextField();
        commonPanel.add(createLabeledField("Program Arguments:", programArgsField), c);

        // Breakpoint file
        breakpointFileField = new JTextField();
        breakpointFileField.setText("init.cld");
        commonPanel.add(createLabeledField("Breakpoint File:", breakpointFileField), c);

        // Execution mode selector
        useDirectExecutionCheckbox = new JCheckBox("Use Direct Execution (run executable instead of compiling)");
        commonPanel.add(useDirectExecutionCheckbox, c);

        // Create the compile panel (for compile and run)
        compilePanel = new JPanel(new GridBagLayout());

        // hbmk2 compiler path
        hbmk2PathField = new TextFieldWithBrowseButton();
        FileChooserDescriptor hbmk2Chooser = FileChooserDescriptorFactory.createSingleFileDescriptor();
        hbmk2PathField.addActionListener(e -> {
            com.intellij.openapi.fileChooser.FileChooser.chooseFile(
                    hbmk2Chooser,
                    null,
                    null,
                    file -> hbmk2PathField.setText(file.getPath())
            );
        });
        compilePanel.add(createLabeledField("hbmk2 Path:", hbmk2PathField), c);

        // Source file
        sourceFileField = new TextFieldWithBrowseButton();
        FileChooserDescriptor sourceFileDesc = FileChooserDescriptorFactory.createSingleFileDescriptor("prg");
        sourceFileField.addActionListener(e -> {
            com.intellij.openapi.fileChooser.FileChooser.chooseFile(
                    sourceFileDesc,
                    null,
                    null,
                    file -> sourceFileField.setText(file.getPath())
            );
        });
        compilePanel.add(createLabeledField("Source File:", sourceFileField), c);

        // Compiler options
        compilerOptionsField = new JTextField();
        compilePanel.add(createLabeledField("Compiler Options:", compilerOptionsField), c);

        // Create the direct panel (for direct execution)
        directPanel = new JPanel(new GridBagLayout());

        // Executable path
        executablePathField = new TextFieldWithBrowseButton();
        FileChooserDescriptor exeChooser = FileChooserDescriptorFactory.createSingleFileDescriptor();
        executablePathField.addActionListener(e -> {
            com.intellij.openapi.fileChooser.FileChooser.chooseFile(
                    exeChooser,
                    null,
                    null,
                    file -> executablePathField.setText(file.getPath())
            );
        });
        directPanel.add(createLabeledField("Executable Path:", executablePathField), c);

        // Create the execution panel (card layout to switch between modes)
        executionPanel = new JPanel(new CardLayout());
        executionPanel.add(compilePanel, "compile");
        executionPanel.add(directPanel, "direct");

        // Add listener to switch between panels
        useDirectExecutionCheckbox.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                CardLayout cl = (CardLayout)(executionPanel.getLayout());
                if (useDirectExecutionCheckbox.isSelected()) {
                    cl.show(executionPanel, "direct");
                } else {
                    cl.show(executionPanel, "compile");
                }
            }
        });

        // Add all panels to main panel
        mainPanel.add(commonPanel, BorderLayout.NORTH);
        mainPanel.add(executionPanel, BorderLayout.CENTER);
    }

    private JPanel createLabeledField(String label, JComponent field) {
        JPanel panel = new JPanel(new BorderLayout());
        panel.add(new JLabel(label), BorderLayout.WEST);
        panel.add(field, BorderLayout.CENTER);
        return panel;
    }

    @Override
    protected void resetEditorFrom(@NotNull HarbourDebuggerRunConfig configuration) {
        workingDirField.setText(StringUtil.notNullize(configuration.getWorkingDirectory()));
        programArgsField.setText(StringUtil.notNullize(configuration.getProgramArguments()));
        breakpointFileField.setText(StringUtil.notNullize(configuration.getBreakpointFile()));

        // Compilation settings
        hbmk2PathField.setText(StringUtil.notNullize(configuration.getHbmk2Path()));
        sourceFileField.setText(StringUtil.notNullize(configuration.getSourceFile()));
        compilerOptionsField.setText(StringUtil.notNullize(configuration.getCompilerOptions()));

        // Direct execution settings
        executablePathField.setText(StringUtil.notNullize(configuration.getExecutablePath()));

        // Execution mode
        boolean useDirectExec = configuration.isUseDirectExecution();
        useDirectExecutionCheckbox.setSelected(useDirectExec);

        // Show appropriate panel
        CardLayout cl = (CardLayout)(executionPanel.getLayout());
        if (useDirectExec) {
            cl.show(executionPanel, "direct");
        } else {
            cl.show(executionPanel, "compile");
        }
    }

    @Override
    protected void applyEditorTo(@NotNull HarbourDebuggerRunConfig configuration) throws ConfigurationException {
        configuration.setWorkingDirectory(workingDirField.getText());
        configuration.setProgramArguments(programArgsField.getText());
        configuration.setBreakpointFile(breakpointFileField.getText());

        // Compilation settings
        configuration.setHbmk2Path(hbmk2PathField.getText());
        configuration.setSourceFile(sourceFileField.getText());
        configuration.setCompilerOptions(compilerOptionsField.getText());

        // Direct execution settings
        configuration.setExecutablePath(executablePathField.getText());

        // Execution mode
        configuration.setUseDirectExecution(useDirectExecutionCheckbox.isSelected());
    }

    @NotNull
    @Override
    protected JComponent createEditor() {
        return mainPanel;
    }
}
package org.intellij.sdk.language;

import com.intellij.application.options.CodeStyleAbstractPanel;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.highlighter.EditorHighlighter;
import com.intellij.openapi.fileTypes.FileType;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.ui.components.JBLabel;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.awt.*;

/**
 * Custom formatting panel for Harbour-specific code style settings
 */
public class HarbourFormattingPanel extends CodeStyleAbstractPanel {
    
    private JSpinner myLocalIndentSpinner;
    private JSpinner myReturnIndentSpinner;
    private JSpinner myDataIndentSpinner;
    private JSpinner myMethodIndentSpinner;
    private JCheckBox mySequenceCheckBox;
    
    protected HarbourFormattingPanel(CodeStyleSettings settings) {
        super(settings);
    }
    
    @Override
    protected String getTabTitle() {
        return "Harbour Formatting";
    }
    
    @Override
    protected int getRightMargin() {
        return 0;
    }
    
    @Nullable
    @Override
    protected EditorHighlighter createHighlighter(EditorColorsScheme scheme) {
        return null;
    }
    
    @NotNull
    @Override
    protected FileType getFileType() {
        return HarbourFileType.INSTANCE;
    }
    
    @Nullable
    @Override
    protected String getPreviewText() {
        return """
                FUNCTION TestFunction()
                   LOCAL nCount := 0
                   LOCAL cText := "Hello"
                   
                   IF nCount > 10
                      ? "Count is large"
                   ENDIF
                   
                   RETURN nCount
                END
                """;
    }
    
    @Override
    public void apply(@NotNull CodeStyleSettings settings) {
        HarbourCodeStyleSettings harbourSettings = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        harbourSettings.LOCAL_INDENT = (Integer) myLocalIndentSpinner.getValue();
        harbourSettings.RETURN_INDENT = (Integer) myReturnIndentSpinner.getValue();
        harbourSettings.DATA_INDENT = (Integer) myDataIndentSpinner.getValue();
        harbourSettings.METHOD_INDENT = (Integer) myMethodIndentSpinner.getValue();
        harbourSettings.SEQUENCE_LIKE_NORMAL_CODE = mySequenceCheckBox.isSelected();
    }
    
    @Override
    public boolean isModified(CodeStyleSettings settings) {
        HarbourCodeStyleSettings harbourSettings = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        return harbourSettings.LOCAL_INDENT != (Integer) myLocalIndentSpinner.getValue() ||
               harbourSettings.RETURN_INDENT != (Integer) myReturnIndentSpinner.getValue() ||
               harbourSettings.DATA_INDENT != (Integer) myDataIndentSpinner.getValue() ||
               harbourSettings.METHOD_INDENT != (Integer) myMethodIndentSpinner.getValue() ||
               harbourSettings.SEQUENCE_LIKE_NORMAL_CODE != mySequenceCheckBox.isSelected();
    }
    
    @Nullable
    @Override
    public JComponent getPanel() {
        JPanel panel = new JPanel(new GridBagLayout());
        GridBagConstraints c = new GridBagConstraints();
        c.fill = GridBagConstraints.NONE;
        c.anchor = GridBagConstraints.WEST;
        c.insets = new Insets(20, 16, 8, 8);
        
        // Title label
        c.gridx = 0;
        c.gridy = 0;
        c.gridwidth = 2;
        JBLabel titleLabel = new JBLabel("<html><b>Statement Indentation Settings</b><br>" +
                "<i>Set the number of spaces for indenting each statement type:</i></html>");
        panel.add(titleLabel, c);
        
        // LOCAL indentation
        c.gridy = 1;
        c.gridwidth = 1;
        JBLabel localLabel = new JBLabel("LOCAL:");
        panel.add(localLabel, c);
        
        c.gridx = 1;
        myLocalIndentSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 20, 1));
        panel.add(myLocalIndentSpinner, c);
        
        // RETURN indentation
        c.gridx = 0;
        c.gridy = 2;
        JBLabel returnLabel = new JBLabel("RETURN:");
        panel.add(returnLabel, c);
        
        c.gridx = 1;
        myReturnIndentSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 20, 1));
        panel.add(myReturnIndentSpinner, c);
        
        // DATA indentation
        c.gridx = 0;
        c.gridy = 3;
        JBLabel dataLabel = new JBLabel("DATA:");
        panel.add(dataLabel, c);
        
        c.gridx = 1;
        myDataIndentSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 20, 1));
        panel.add(myDataIndentSpinner, c);
        
        // METHOD indentation
        c.gridx = 0;
        c.gridy = 4;
        JBLabel methodLabel = new JBLabel("METHOD (declaration only):");
        panel.add(methodLabel, c);
        
        c.gridx = 1;
        myMethodIndentSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 20, 1));
        panel.add(myMethodIndentSpinner, c);
        
        // SEQUENCE indentation
        c.gridx = 0;
        c.gridy = 5;
        c.gridwidth = 2;
        mySequenceCheckBox = new JCheckBox("Indent BEGIN SEQUENCE like normal code (if/endif style)");
        mySequenceCheckBox.setToolTipText("When checked, BEGIN SEQUENCE blocks indent like other control structures. When unchecked, they use custom indentation.");
        panel.add(mySequenceCheckBox, c);
        c.gridwidth = 1; // Reset gridwidth
        
        // Add horizontal glue to push everything to the left
        c.gridx = 2;
        c.gridy = 0;
        c.gridwidth = 1;
        c.gridheight = 6;
        c.weightx = 1.0;
        c.weighty = 0.0;
        c.fill = GridBagConstraints.HORIZONTAL;
        panel.add(Box.createHorizontalGlue(), c);
        
        // Add vertical glue to push everything to the top
        c.gridx = 0;
        c.gridy = 6;
        c.gridwidth = 3;
        c.gridheight = 1;
        c.weightx = 0.0;
        c.weighty = 1.0;
        c.fill = GridBagConstraints.VERTICAL;
        panel.add(Box.createVerticalGlue(), c);
        
        return panel;
    }
    
    @Override
    protected void resetImpl(@NotNull CodeStyleSettings settings) {
        HarbourCodeStyleSettings harbourSettings = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        myLocalIndentSpinner.setValue(harbourSettings.LOCAL_INDENT);
        myReturnIndentSpinner.setValue(harbourSettings.RETURN_INDENT);
        myDataIndentSpinner.setValue(harbourSettings.DATA_INDENT);
        myMethodIndentSpinner.setValue(harbourSettings.METHOD_INDENT);
        mySequenceCheckBox.setSelected(harbourSettings.SEQUENCE_LIKE_NORMAL_CODE);
    }
}
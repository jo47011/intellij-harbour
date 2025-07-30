package org.intellij.sdk.language;

import com.intellij.application.options.CodeStyleAbstractPanel;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.highlighter.EditorHighlighter;
import com.intellij.openapi.fileTypes.FileType;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.psi.codeStyle.CommonCodeStyleSettings;
import com.intellij.ui.components.JBLabel;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.awt.*;

/**
 * Custom wrapping and braces panel for Harbour with hard wrap setting
 */
public class HarbourWrappingAndBracesPanel extends CodeStyleAbstractPanel {
    
    private JSpinner myRightMarginSpinner;
    private JCheckBox myWrapOnTypingCheckBox;
    private JSpinner myVisualGuideSpinner;
    
    protected HarbourWrappingAndBracesPanel(CodeStyleSettings settings) {
        super(settings);
    }
    
    @Override
    protected String getTabTitle() {
        return "Wrapping and Braces";
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
                FUNCTION LongFunctionNameWithManyParametersToTestWrapping(param1, param2, param3, param4, param5)
                   LOCAL veryLongVariableNameToTestHowLineWrappingWorks := "This is a very long string that might need to be wrapped"
                   
                   IF veryLongVariableNameToTestHowLineWrappingWorks == "Something" .AND. param1 > 10 .AND. param2 < 100
                      ? "This line is very long and should be wrapped according to the hard wrap setting"
                   ENDIF
                   
                   RETURN veryLongVariableNameToTestHowLineWrappingWorks
                END
                """;
    }
    
    @Override
    public void apply(@NotNull CodeStyleSettings settings) {
        CommonCodeStyleSettings commonSettings = settings.getCommonSettings(HarbourLanguage.INSTANCE);
        commonSettings.RIGHT_MARGIN = (Integer) myRightMarginSpinner.getValue();
        commonSettings.WRAP_ON_TYPING = myWrapOnTypingCheckBox.isSelected() ? CommonCodeStyleSettings.WrapOnTyping.WRAP.intValue : CommonCodeStyleSettings.WrapOnTyping.NO_WRAP.intValue;
        
        // Handle visual guide
        settings.getDefaultSoftMargins().clear();
        int visualGuide = (Integer) myVisualGuideSpinner.getValue();
        if (visualGuide > 0) {
            settings.getDefaultSoftMargins().add(visualGuide);
        }
    }
    
    @Override
    public boolean isModified(CodeStyleSettings settings) {
        CommonCodeStyleSettings commonSettings = settings.getCommonSettings(HarbourLanguage.INSTANCE);
        boolean wrapOnTyping = commonSettings.WRAP_ON_TYPING == CommonCodeStyleSettings.WrapOnTyping.WRAP.intValue;
        
        // Check visual guide
        int currentVisualGuide = settings.getDefaultSoftMargins().isEmpty() ? 0 : settings.getDefaultSoftMargins().get(0);
        int spinnerVisualGuide = (Integer) myVisualGuideSpinner.getValue();
        
        return commonSettings.RIGHT_MARGIN != (Integer) myRightMarginSpinner.getValue() ||
               wrapOnTyping != myWrapOnTypingCheckBox.isSelected() ||
               currentVisualGuide != spinnerVisualGuide;
    }
    
    @Nullable
    @Override
    public JComponent getPanel() {
        JPanel panel = new JPanel(new GridBagLayout());
        GridBagConstraints c = new GridBagConstraints();
        c.fill = GridBagConstraints.HORIZONTAL;
        c.anchor = GridBagConstraints.WEST;
        c.insets = new Insets(20, 8, 8, 8);
        
        // Hard wrap setting
        c.gridx = 0;
        c.gridy = 0;
        JBLabel hardWrapLabel = new JBLabel("Hard wrap at:");
        panel.add(hardWrapLabel, c);
        
        c.gridx = 1;
        myRightMarginSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 999, 1));
        panel.add(myRightMarginSpinner, c);
        
        c.gridx = 2;
        JBLabel columnLabel = new JBLabel("columns (0 = disabled)");
        panel.add(columnLabel, c);
        
        // Wrap on typing
        c.gridx = 0;
        c.gridy = 1;
        c.gridwidth = 3;
        myWrapOnTypingCheckBox = new JCheckBox("Wrap on typing");
        panel.add(myWrapOnTypingCheckBox, c);
        
        // Visual guide
        c.gridx = 0;
        c.gridy = 2;
        c.gridwidth = 1;
        JBLabel visualGuideLabel = new JBLabel("Visual guide:");
        panel.add(visualGuideLabel, c);
        
        c.gridx = 1;
        myVisualGuideSpinner = new JSpinner(new SpinnerNumberModel(0, 0, 999, 1));
        panel.add(myVisualGuideSpinner, c);
        
        c.gridx = 2;
        JBLabel visualGuideColumnLabel = new JBLabel("columns (0 = none)");
        panel.add(visualGuideColumnLabel, c);
        
        // Add vertical glue to push everything to the top
        c.gridx = 0;
        c.gridy = 3;
        c.gridwidth = 3;
        c.weighty = 1.0;
        panel.add(Box.createVerticalGlue(), c);
        
        return panel;
    }
    
    @Override
    protected void resetImpl(@NotNull CodeStyleSettings settings) {
        CommonCodeStyleSettings commonSettings = settings.getCommonSettings(HarbourLanguage.INSTANCE);
        myRightMarginSpinner.setValue(commonSettings.RIGHT_MARGIN);
        myWrapOnTypingCheckBox.setSelected(commonSettings.WRAP_ON_TYPING == CommonCodeStyleSettings.WrapOnTyping.WRAP.intValue);
        
        // Set visual guide
        int visualGuide = settings.getDefaultSoftMargins().isEmpty() ? 0 : settings.getDefaultSoftMargins().get(0);
        myVisualGuideSpinner.setValue(visualGuide);
    }
}
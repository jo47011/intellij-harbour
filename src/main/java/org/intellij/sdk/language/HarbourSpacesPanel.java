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
 * Spaces settings panel for Harbour code style configuration.
 * Controls spacing around operators and commas.
 */
public class HarbourSpacesPanel extends CodeStyleAbstractPanel {

    private JCheckBox mySpaceAfterComma;
    private JCheckBox mySpaceBeforeComma;
    private JCheckBox mySpaceAroundAdditive;
    private JCheckBox mySpaceAroundMultiplicative;
    private JCheckBox mySpaceAroundComparison;
    private JCheckBox mySpaceAroundAssignment;
    private JCheckBox mySpaceAroundLogical;

    protected HarbourSpacesPanel(CodeStyleSettings settings) {
        super(settings);
    }

    @Override
    protected String getTabTitle() {
        return "Spaces";
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
                FUNCTION TestSpacing(a,b,c)
                LOCAL x:=a+b*c
                LOCAL y:=a-b/c
                LOCAL ok:=x==y .AND. a>=0 .OR. b<=100

                   aArray:={1,2,3,4,5}
                   IF a>0 .AND. b<10
                      x:=a+b
                      y:=a*b-c
                   ENDIF

                RETURN x+y
                """;
    }

    @Override
    public void apply(@NotNull CodeStyleSettings settings) {
        HarbourCodeStyleSettings s = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        s.SPACE_AFTER_COMMA = mySpaceAfterComma.isSelected();
        s.SPACE_BEFORE_COMMA = mySpaceBeforeComma.isSelected();
        s.SPACE_AROUND_ADDITIVE_OPERATORS = mySpaceAroundAdditive.isSelected();
        s.SPACE_AROUND_MULTIPLICATIVE_OPERATORS = mySpaceAroundMultiplicative.isSelected();
        s.SPACE_AROUND_COMPARISON_OPERATORS = mySpaceAroundComparison.isSelected();
        s.SPACE_AROUND_ASSIGNMENT_OPERATOR = mySpaceAroundAssignment.isSelected();
        s.SPACE_AROUND_LOGICAL_OPERATORS = mySpaceAroundLogical.isSelected();
    }

    @Override
    public boolean isModified(CodeStyleSettings settings) {
        HarbourCodeStyleSettings s = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        return s.SPACE_AFTER_COMMA != mySpaceAfterComma.isSelected() ||
               s.SPACE_BEFORE_COMMA != mySpaceBeforeComma.isSelected() ||
               s.SPACE_AROUND_ADDITIVE_OPERATORS != mySpaceAroundAdditive.isSelected() ||
               s.SPACE_AROUND_MULTIPLICATIVE_OPERATORS != mySpaceAroundMultiplicative.isSelected() ||
               s.SPACE_AROUND_COMPARISON_OPERATORS != mySpaceAroundComparison.isSelected() ||
               s.SPACE_AROUND_ASSIGNMENT_OPERATOR != mySpaceAroundAssignment.isSelected() ||
               s.SPACE_AROUND_LOGICAL_OPERATORS != mySpaceAroundLogical.isSelected();
    }

    @Nullable
    @Override
    public JComponent getPanel() {
        JPanel panel = new JPanel(new GridBagLayout());
        GridBagConstraints c = new GridBagConstraints();
        c.fill = GridBagConstraints.NONE;
        c.anchor = GridBagConstraints.WEST;
        c.insets = new Insets(10, 8, 2, 4);
        int row = 0;

        // Section: Commas
        c.gridx = 0; c.gridy = row++;
        c.gridwidth = 2;
        panel.add(new JBLabel("<html><b>Commas</b></html>"), c);

        c.insets = new Insets(2, 24, 2, 4);
        c.gridy = row++;
        mySpaceAfterComma = new JCheckBox("Space after comma");
        mySpaceAfterComma.setToolTipText("a,b,c  =>  a, b, c");
        panel.add(mySpaceAfterComma, c);

        c.gridy = row++;
        mySpaceBeforeComma = new JCheckBox("Space before comma");
        mySpaceBeforeComma.setToolTipText("a, b, c  =>  a , b , c");
        panel.add(mySpaceBeforeComma, c);

        // Section: Operators
        c.insets = new Insets(12, 8, 2, 4);
        c.gridy = row++;
        panel.add(new JBLabel("<html><b>Around Operators</b></html>"), c);

        c.insets = new Insets(2, 24, 2, 4);
        c.gridy = row++;
        mySpaceAroundAssignment = new JCheckBox("Assignment operator  :=");
        mySpaceAroundAssignment.setToolTipText("x:=1  vs  x := 1");
        panel.add(mySpaceAroundAssignment, c);

        c.gridy = row++;
        mySpaceAroundAdditive = new JCheckBox("Additive operators  + -");
        mySpaceAroundAdditive.setToolTipText("a+b  vs  a + b");
        panel.add(mySpaceAroundAdditive, c);

        c.gridy = row++;
        mySpaceAroundMultiplicative = new JCheckBox("Multiplicative operators  * / %");
        mySpaceAroundMultiplicative.setToolTipText("a*b  vs  a * b");
        panel.add(mySpaceAroundMultiplicative, c);

        c.gridy = row++;
        mySpaceAroundComparison = new JCheckBox("Comparison operators  == != < > <= >=");
        mySpaceAroundComparison.setToolTipText("a==b  vs  a == b");
        panel.add(mySpaceAroundComparison, c);

        c.gridy = row++;
        mySpaceAroundLogical = new JCheckBox("Logical operators  .AND. .OR. .NOT.");
        mySpaceAroundLogical.setToolTipText("a.and.b  vs  a .and. b");
        panel.add(mySpaceAroundLogical, c);

        // Glue
        c.gridx = 1; c.gridy = 0;
        c.gridwidth = 1; c.gridheight = row;
        c.weightx = 1.0; c.fill = GridBagConstraints.HORIZONTAL;
        panel.add(Box.createHorizontalGlue(), c);

        c.gridx = 0; c.gridy = row;
        c.gridwidth = 2; c.gridheight = 1;
        c.weightx = 0.0; c.weighty = 1.0;
        c.fill = GridBagConstraints.VERTICAL;
        panel.add(Box.createVerticalGlue(), c);

        return panel;
    }

    @Override
    protected void resetImpl(@NotNull CodeStyleSettings settings) {
        HarbourCodeStyleSettings s = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        mySpaceAfterComma.setSelected(s.SPACE_AFTER_COMMA);
        mySpaceBeforeComma.setSelected(s.SPACE_BEFORE_COMMA);
        mySpaceAroundAdditive.setSelected(s.SPACE_AROUND_ADDITIVE_OPERATORS);
        mySpaceAroundMultiplicative.setSelected(s.SPACE_AROUND_MULTIPLICATIVE_OPERATORS);
        mySpaceAroundComparison.setSelected(s.SPACE_AROUND_COMPARISON_OPERATORS);
        mySpaceAroundAssignment.setSelected(s.SPACE_AROUND_ASSIGNMENT_OPERATOR);
        mySpaceAroundLogical.setSelected(s.SPACE_AROUND_LOGICAL_OPERATORS);
    }
}

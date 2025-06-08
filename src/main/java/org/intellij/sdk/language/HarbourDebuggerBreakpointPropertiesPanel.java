package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.LabeledComponent;
import com.intellij.ui.EditorTextField;
import com.intellij.xdebugger.breakpoints.XLineBreakpoint;
import com.intellij.xdebugger.breakpoints.ui.XBreakpointCustomPropertiesPanel;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;
import java.awt.*;

/**
 * Custom properties panel for Harbour debugger breakpoints.
 * Allows setting conditional expressions, hit conditions, and log messages.
 */
public class HarbourDebuggerBreakpointPropertiesPanel extends XBreakpointCustomPropertiesPanel<XLineBreakpoint<HarbourDebuggerBreakpointProperties>> {
    
    private static final Logger LOG = Logger.getInstance(HarbourDebuggerBreakpointPropertiesPanel.class);
    
    private EditorTextField conditionTextField;
    private EditorTextField hitConditionTextField;
    private EditorTextField logMessageTextField;
    private final Project project;
    
    // Fallback storage for custom properties if reflection fails
    private static java.util.Map<XLineBreakpoint<HarbourDebuggerBreakpointProperties>, HarbourDebuggerBreakpointProperties> customProperties;
    
    /**
     * Get custom properties for a breakpoint (used by breakpoint handler when properties are null)
     */
    public static HarbourDebuggerBreakpointProperties getCustomProperties(XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        if (customProperties != null) {
            return customProperties.get(breakpoint);
        }
        return null;
    }

    public HarbourDebuggerBreakpointPropertiesPanel(Project project) {
        this.project = project;
        System.out.println("DEBUG: HarbourDebuggerBreakpointPropertiesPanel constructor called for project: " + project.getName());
    }

    @NotNull
    @Override
    public JComponent getComponent() {
        System.out.println("DEBUG: getComponent() called - creating UI panel");
        JPanel panel = new JPanel(new GridBagLayout());
        GridBagConstraints gbc = new GridBagConstraints();
        
        // Condition field
        gbc.gridx = 0;
        gbc.gridy = 0;
        gbc.weightx = 1.0;
        gbc.fill = GridBagConstraints.HORIZONTAL;
        gbc.insets = new Insets(5, 5, 5, 5);
        
        conditionTextField = new EditorTextField("", project, HarbourFileType.INSTANCE);
        conditionTextField.setPreferredSize(new Dimension(300, 25));
        LabeledComponent<EditorTextField> conditionComponent = 
            LabeledComponent.create(conditionTextField, "Condition (e.g., nCounter == 2):");
        panel.add(conditionComponent, gbc);

        // Hit condition field
        gbc.gridy = 1;
        hitConditionTextField = new EditorTextField("", project, HarbourFileType.INSTANCE);
        hitConditionTextField.setPreferredSize(new Dimension(300, 25));
        LabeledComponent<EditorTextField> hitConditionComponent = 
            LabeledComponent.create(hitConditionTextField, "Hit count (e.g., >= 3):");
        panel.add(hitConditionComponent, gbc);

        // Log message field
        gbc.gridy = 2;
        logMessageTextField = new EditorTextField("", project, HarbourFileType.INSTANCE);
        logMessageTextField.setPreferredSize(new Dimension(300, 25));
        LabeledComponent<EditorTextField> logMessageComponent = 
            LabeledComponent.create(logMessageTextField, "Log message:");
        panel.add(logMessageComponent, gbc);

        return panel;
    }

    @Override
    public void saveTo(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        try {
            HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
            System.out.println("=== SAVE TO DEBUG ===");
            System.out.println("Properties object: " + properties);
            System.out.println("Breakpoint type: " + breakpoint.getType());
            System.out.println("Breakpoint class: " + breakpoint.getClass());
            System.out.println("Condition field text: '" + conditionTextField.getText() + "'");
            System.out.println("Hit condition field text: '" + hitConditionTextField.getText() + "'");
            System.out.println("Log message field text: '" + logMessageTextField.getText() + "'");
            
            if (properties == null) {
                // FORCE CREATE properties if null
                System.out.println("FORCING creation of properties object!");
                properties = new HarbourDebuggerBreakpointProperties();
                
                // Try to force-set the properties via reflection or alternative method
                try {
                    // Use Java reflection to force set the properties
                    java.lang.reflect.Field field = breakpoint.getClass().getDeclaredField("myProperties");
                    field.setAccessible(true);
                    field.set(breakpoint, properties);
                    System.out.println("Successfully forced properties via reflection!");
                } catch (Exception reflectionEx) {
                    System.out.println("Reflection failed: " + reflectionEx.getMessage());
                    
                    // Alternative: Store in our own map
                    if (customProperties == null) {
                        customProperties = new java.util.HashMap<>();
                    }
                    customProperties.put(breakpoint, properties);
                    System.out.println("Stored properties in custom map as fallback");
                }
            }
            
            if (properties != null) {
                String condition = conditionTextField.getText();
                String hitCondition = hitConditionTextField.getText();
                String logMessage = logMessageTextField.getText();
                
                // Don't trim yet - preserve exact input
                properties.setCondition(condition);
                properties.setHitCondition(hitCondition);
                properties.setLogMessage(logMessage);
                
                System.out.println("AFTER SAVE - Properties: " + properties);
                System.out.println("AFTER SAVE - condition: '" + properties.getCondition() + "'");
                
                // Debug logging
                LOG.info("Saving breakpoint properties: condition='" + condition + 
                        "', hitCondition='" + hitCondition + "', logMessage='" + logMessage + "'");
            } else {
                LOG.warn("Properties object is still null after force creation!");
                System.out.println("ERROR: Properties object is still null after force creation!");
            }
        } catch (Exception e) {
            System.out.println("ERROR in saveTo: " + e.getMessage());
            e.printStackTrace();
        }
    }

    @Override
    public void loadFrom(@NotNull XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        try {
            HarbourDebuggerBreakpointProperties properties = breakpoint.getProperties();
            System.out.println("=== LOAD FROM DEBUG ===");
            System.out.println("Properties object: " + properties);
            System.out.println("Breakpoint type: " + breakpoint.getType());
            
            // If properties is null, try to get from our custom storage
            if (properties == null && customProperties != null) {
                properties = customProperties.get(breakpoint);
                System.out.println("Retrieved properties from custom storage: " + properties);
            }
            
            if (properties != null) {
                String condition = properties.getCondition();
                String hitCondition = properties.getHitCondition();
                String logMessage = properties.getLogMessage();
                
                System.out.println("BEFORE LOAD - Properties values:");
                System.out.println("  condition: '" + condition + "'");
                System.out.println("  hitCondition: '" + hitCondition + "'");
                System.out.println("  logMessage: '" + logMessage + "'");
                
                conditionTextField.setText(condition);
                hitConditionTextField.setText(hitCondition);
                logMessageTextField.setText(logMessage);
                
                System.out.println("AFTER LOAD - UI field values:");
                System.out.println("  condition field: '" + conditionTextField.getText() + "'");
                System.out.println("  hitCondition field: '" + hitConditionTextField.getText() + "'");
                System.out.println("  logMessage field: '" + logMessageTextField.getText() + "'");
                
                // Debug logging
                LOG.info("Loading breakpoint properties: condition='" + condition + 
                        "', hitCondition='" + hitCondition + "', logMessage='" + logMessage + "'");
            } else {
                LOG.warn("Properties object is null during load!");
                System.out.println("ERROR: Properties object is null during load - no custom storage either!");
                
                // Initialize empty fields
                conditionTextField.setText("");
                hitConditionTextField.setText("");
                logMessageTextField.setText("");
            }
        } catch (Exception e) {
            System.out.println("ERROR in loadFrom: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
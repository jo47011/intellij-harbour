package org.intellij.sdk.language;

import com.intellij.openapi.options.Configurable;
import com.intellij.openapi.options.ConfigurationException;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.openapi.ui.Messages;
import org.jetbrains.annotations.Nls;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.awt.*;

/**
 * Application-level settings configurable that creates project-specific configurables
 */
public class HarbourApplicationSettingsConfigurable implements Configurable {
    private JPanel myMainPanel;
    private HarbourSettingsConfigurable projectConfigurable;

    @Nls(capitalization = Nls.Capitalization.Title)
    @Override
    public String getDisplayName() {
        return "Harbour";
    }

    @Nullable
    @Override
    public JComponent createComponent() {
        myMainPanel = new JPanel(new BorderLayout());
        
        // Get the default project or the first open project
        Project project = null;
        Project[] openProjects = ProjectManager.getInstance().getOpenProjects();
        if (openProjects.length > 0) {
            project = openProjects[0];
        }
        
        if (project == null) {
            // Show a message if no project is open
            JPanel messagePanel = new JPanel(new BorderLayout());
            JLabel messageLabel = new JLabel("Please open a project to configure Harbour settings.", JLabel.CENTER);
            messagePanel.add(messageLabel, BorderLayout.CENTER);
            myMainPanel.add(messagePanel, BorderLayout.CENTER);
        } else {
            // Create the actual settings UI with the project context
            projectConfigurable = new HarbourSettingsConfigurable(project);
            JComponent component = projectConfigurable.createComponent();
            if (component != null) {
                myMainPanel.add(component, BorderLayout.CENTER);
            }
        }
        
        return myMainPanel;
    }

    @Override
    public boolean isModified() {
        return projectConfigurable != null && projectConfigurable.isModified();
    }

    @Override
    public void apply() throws ConfigurationException {
        if (projectConfigurable != null) {
            projectConfigurable.apply();
        }
    }

    @Override
    public void reset() {
        if (projectConfigurable != null) {
            projectConfigurable.reset();
        }
    }

    @Override
    public void disposeUIResources() {
        if (projectConfigurable != null) {
            projectConfigurable.disposeUIResources();
        }
        projectConfigurable = null;
        myMainPanel = null;
    }
}
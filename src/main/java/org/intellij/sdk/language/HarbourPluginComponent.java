package org.intellij.sdk.language;

import com.intellij.openapi.components.ProjectComponent;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;

/**
 * Component loaded when the plugin is initialized.
 */
public class HarbourPluginComponent implements ProjectComponent {
    private static final Logger LOG = Logger.getInstance(HarbourPluginComponent.class);
    private final Project project;

    public HarbourPluginComponent(Project project) {
        this.project = project;
    }

    @Override
    public void projectOpened() {
        LOG.info("Harbour plugin component initialized");
        HarbourLogger.log("HarbourPluginComponent", "DEBUG: Harbour plugin component initialized");

        // Register structure view listeners for proper disposal
        HarbourStructureViewFactory.registerDisposableListeners(project);

        // Notification removed - user doesn't want popup on every project open
    }
}
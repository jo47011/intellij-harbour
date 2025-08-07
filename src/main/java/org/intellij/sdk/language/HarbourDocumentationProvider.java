package org.intellij.sdk.language;

import com.intellij.lang.documentation.AbstractDocumentationProvider;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.ide.BrowserUtil;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.jetbrains.annotations.Nullable;
import com.intellij.notification.Notification;
import com.intellij.notification.NotificationAction;
import com.intellij.notification.NotificationGroupManager;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.options.ShowSettingsUtil;
import org.jetbrains.annotations.NotNull;

public class HarbourDocumentationProvider extends AbstractDocumentationProvider {

    @Override
    public @Nullable String getQuickNavigateInfo(PsiElement element, PsiElement originalElement) {
        
        // Check if we're in hover mode
        boolean isClick = HarbourExternalDocumentationHandler.isClickMode();
        
        if (!isClick) {
            // During hover, return null to prevent popup
            return null;
        }
        
        // During click, generate documentation
        return generateDocumentation(element);
    }

    @Override
    public @Nullable String generateDoc(PsiElement element, @Nullable PsiElement originalElement) {
        return generateDocumentation(element);
    }

    private String generateDocumentation(PsiElement element) {
        // Handle if element is the identifier inside a function declaration
        if (element.getParent() instanceof HarbourFunctionDeclaration) {
            HarbourFunctionDeclaration function = (HarbourFunctionDeclaration) element.getParent();
            String doc = "Function: " + function.getName();
            return doc;
        }

        // Handle if element is the function declaration itself
        if (element instanceof HarbourFunctionDeclaration) {
            HarbourFunctionDeclaration function = (HarbourFunctionDeclaration) element;
            String doc = "Function: " + function.getName();
            return doc;
        }

        return null;
    }

    /**
     * Gets the documentation URL for a function
     * @param project Current project
     * @param functionName Name of the function
     * @return Complete URL to documentation
     */
    public String getDocumentationUrl(Project project, String functionName) {
        HarbourSettings settings = HarbourSettings.getInstance(project);
        String baseUrl = settings.getDocumentationBaseUrl();
        
        // Ensure proper URL formatting
        if (baseUrl == null || baseUrl.isEmpty()) {
            baseUrl = "https://harbour.github.io/doc/clc53.html";
        }
        
        // Add # separator if not present
        if (!baseUrl.endsWith("#") && !baseUrl.endsWith("/")) {
            baseUrl = baseUrl + "#";
        }
        
        return baseUrl + functionName;
    }

    /**
     * Opens the external documentation for a function in the default browser
     * @param project Current project
     * @param functionName Name of the function
     * @return true if the browser was launched, false otherwise
     */
    public boolean openExternalDocumentation(Project project, String functionName) {
        try {
            String url = getDocumentationUrl(project, functionName);

            // Launch browser with the URL
            BrowserUtil.browse(url);
            
            // Show notification with actions
            showExternalDocumentationNotification(project, functionName, url);

            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Checks if external documentation is available for a function
     * @param project Current project
     * @param functionName Name of the function
     * @return true if external documentation is available
     */
    public boolean hasExternalDocumentation(Project project, String functionName) {
        if (functionName == null || functionName.isEmpty()) {
            return false;
        }

        HarbourSettings settings = HarbourSettings.getInstance(project);
        return settings != null && settings.getDocumentationBaseUrl() != null &&
                !settings.getDocumentationBaseUrl().isEmpty();
    }
    
    /**
     * Shows a notification with actions after opening external documentation
     * @param project Current project
     * @param functionName Name of the function
     * @param url The documentation URL
     */
    private void showExternalDocumentationNotification(Project project, String functionName, String url) {
        try {
            // Create notification with actions
            Notification notification = NotificationGroupManager.getInstance()
                .getNotificationGroup("Harbour Application")
                .createNotification(
                    "Opening documentation for: " + functionName,
                    "URL: " + url,
                    NotificationType.INFORMATION
                )
                .addAction(new NotificationAction("Open Browser Settings") {
                    @Override
                    public void actionPerformed(@NotNull AnActionEvent e, @NotNull Notification notification) {
                        // Open the Tools > Web Browsers settings page
                        ShowSettingsUtil.getInstance().showSettingsDialog(project, "Web Browsers");
                        notification.expire();
                    }
                })
                .addAction(new NotificationAction("Copy URL") {
                    @Override
                    public void actionPerformed(@NotNull AnActionEvent e, @NotNull Notification notification) {
                        // Copy URL to clipboard
                        java.awt.datatransfer.StringSelection selection = new java.awt.datatransfer.StringSelection(url);
                        java.awt.Toolkit.getDefaultToolkit().getSystemClipboard().setContents(selection, null);
                        
                        // Show a brief success message
                        NotificationGroupManager.getInstance()
                            .getNotificationGroup("Harbour Application")
                            .createNotification("URL copied to clipboard", NotificationType.INFORMATION)
                            .notify(project);
                        
                        notification.expire();
                    }
                });
            
            // Show the notification
            notification.notify(project);
            
        } catch (Exception e) {
        }
    }
}
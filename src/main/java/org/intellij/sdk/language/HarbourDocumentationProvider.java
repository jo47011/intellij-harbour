package org.intellij.sdk.language;

import com.intellij.lang.documentation.AbstractDocumentationProvider;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
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
        // Always generate documentation for quick navigate
        // The platform will handle when to show it (Ctrl+Q or navigation)
        return generateDocumentation(element);
    }

    @Override
    public @Nullable String generateDoc(PsiElement element, @Nullable PsiElement originalElement) {
        return generateDocumentation(element);
    }

    private String generateDocumentation(PsiElement element) {
        // Get proper function/procedure context
        HarbourFunctionDeclaration function = null;
        
        // Handle if element is the identifier inside a function declaration
        if (element.getParent() instanceof HarbourFunctionDeclaration) {
            function = (HarbourFunctionDeclaration) element.getParent();
        }
        // Handle if element is the function declaration itself
        else if (element instanceof HarbourFunctionDeclaration) {
            function = (HarbourFunctionDeclaration) element;
        }
        
        if (function != null) {
            // Build formatted documentation with HTML for better presentation
            StringBuilder doc = new StringBuilder();
            doc.append("<html><body>");
            doc.append("<b>").append(function.getName()).append("</b><br>");
            
            // Add file location
            PsiFile file = function.getContainingFile();
            if (file != null) {
                doc.append("<i>").append(file.getName()).append("</i><br>");
            }
            
            // Add line number
            int lineNumber = HarbourLogger.calculateLineNumber(function);
            doc.append("Line: ").append(lineNumber + 1).append("<br>");
            
            // Add function text preview (first line)
            String text = function.getText();
            if (text != null && !text.isEmpty()) {
                String firstLine = text.split("\n")[0];
                if (firstLine.length() > 100) {
                    firstLine = firstLine.substring(0, 100) + "...";
                }
                doc.append("<br><code>").append(firstLine).append("</code>");
            }
            
            doc.append("</body></html>");
            return doc.toString();
        }

        // For other elements (including external functions), provide enhanced info
        if (element != null) {
            String elementText = element.getText();
            StringBuilder doc = new StringBuilder();
            doc.append("<html><body>");
            doc.append("<b>").append(elementText).append("</b><br>");
            
            // Check if this looks like a function call
            if (elementText != null && !elementText.isEmpty()) {
                // Check if it's likely an external/system function
                HarbourFunctionClassificationService classifier = element.getProject().getService(HarbourFunctionClassificationService.class);
                if (classifier != null && classifier.isExternalFunction(elementText)) {
                    doc.append("<i>External Function</i><br>");
                    doc.append("<br>No local declaration found.<br>");
                    doc.append("This function may be a built-in Harbour function<br>");
                    doc.append("or defined in an external library.");
                } else {
                    // It's an internal element without a declaration context
                    PsiFile file = element.getContainingFile();
                    if (file != null) {
                        doc.append("<i>").append(file.getName()).append("</i><br>");
                    }
                }
            }
            
            doc.append("</body></html>");
            return doc.toString();
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
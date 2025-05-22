package org.intellij.sdk.language;

import com.intellij.lang.documentation.AbstractDocumentationProvider;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.ide.BrowserUtil;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.jetbrains.annotations.Nullable;

public class HarbourDocumentationProvider extends AbstractDocumentationProvider {

    @Override
    public @Nullable String getQuickNavigateInfo(PsiElement element, PsiElement originalElement) {
        HarbourLogger.log("DocumentationProvider", "QuickNavigateInfo requested for: " + element.getText());
        return generateDocumentation(element);
    }

    @Override
    public @Nullable String generateDoc(PsiElement element, @Nullable PsiElement originalElement) {
        HarbourLogger.log("DocumentationProvider", "Generating doc for element: " + element.getText());
        return generateDocumentation(element);
    }

    private String generateDocumentation(PsiElement element) {
        // Handle if element is the identifier inside a function declaration
        if (element.getParent() instanceof HarbourFunctionDeclaration) {
            HarbourFunctionDeclaration function = (HarbourFunctionDeclaration) element.getParent();
            String doc = "Function: " + function.getName();
            HarbourLogger.log("DocumentationProvider", "Documentation generated for function: " + doc);
            return doc;
        }

        // Handle if element is the function declaration itself
        if (element instanceof HarbourFunctionDeclaration) {
            HarbourFunctionDeclaration function = (HarbourFunctionDeclaration) element;
            String doc = "Function: " + function.getName();
            HarbourLogger.log("DocumentationProvider", "Documentation generated for function: " + doc);
            return doc;
        }

        HarbourLogger.log("DocumentationProvider", "Documentation not generated for element type: " + element.getClass().getSimpleName());
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
        return settings.getDocumentationBaseUrl() + functionName;
    }

    /**
     * Opens the external documentation for a function in the default browser
     * @param project Current project
     * @param functionName Name of the function
     * @return true if the browser was launched, false otherwise
     */
    public boolean openExternalDocumentation(Project project, String functionName) {
        try {
            HarbourLogger.log("DocumentationProvider", "Opening external documentation for: " + functionName);
            String url = getDocumentationUrl(project, functionName);
            HarbourLogger.log("DocumentationProvider", "Documentation URL: " + url);

            // Launch browser with the URL
            BrowserUtil.browse(url);

            HarbourLogger.log("DocumentationProvider", "Browser launched successfully for: " + url);
            return true;
        } catch (Exception e) {
            HarbourLogger.log("DocumentationProvider", "Error opening external documentation: " + e.getMessage());
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
}
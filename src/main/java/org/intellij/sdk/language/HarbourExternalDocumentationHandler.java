package org.intellij.sdk.language;

import com.intellij.codeInsight.navigation.actions.GotoDeclarationHandler;
import com.intellij.ide.BrowserUtil;
import com.intellij.ide.browsers.BrowserLauncher;
import com.intellij.ide.browsers.WebBrowserManager;
import com.intellij.notification.Notification;
import com.intellij.notification.NotificationAction;
import com.intellij.notification.NotificationGroupManager;
import com.intellij.notification.NotificationType;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.options.ShowSettingsUtil;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Handles "Go To Declaration" for external Harbour functions by opening documentation in a browser.
 * Only responds to actual ctrl+click (not hover) and only for external functions.
 */
public class HarbourExternalDocumentationHandler implements GotoDeclarationHandler {
    
    public HarbourExternalDocumentationHandler() {
        String osName = System.getProperty("os.name");
        HarbourLogger.log("DocHandler", "HarbourExternalDocumentationHandler initialized on " + osName);
    }
    // Using static variable since ThreadLocal wasn't working correctly
    private static boolean IS_CLICK_MODE = false;
    private static long LAST_CLICK_TIME = 0;
    private static AtomicInteger CALL_COUNTER = new AtomicInteger(0);
    private static boolean MOUSE_LISTENER_REGISTERED = false;
    
    // Cache to prevent duplicate browser openings within a short time window
    private static final Map<String, Long> recentlyOpenedUrls = new HashMap<>();
    private static final long DUPLICATE_PREVENTION_WINDOW_MS = 2000; // 2 seconds

    // Method to set click mode - called from mouse listener
    public static void setClickMode(boolean isClick) {
        IS_CLICK_MODE = isClick;
        if (isClick) {
            LAST_CLICK_TIME = System.currentTimeMillis();
            CALL_COUNTER.set(0);
        }
        HarbourLogger.log("DocHandler", "Click mode set to: " + isClick);
    }
    
    // Method to check if currently in click mode - used by main handler for consistency
    public static boolean isClickMode() {
        return IS_CLICK_MODE;
    }

    @Override
    public PsiElement @Nullable [] getGotoDeclarationTargets(@Nullable PsiElement element, int offset, Editor editor) {
        // Count calls
        int count = CALL_COUNTER.incrementAndGet();

        // Ensure mouse listener is registered on first call
        if (!MOUSE_LISTENER_REGISTERED && element != null) {
            ensureMouseListenerRegistered(element.getProject());
        }
        

        // Log this call for debugging
        String osName = System.getProperty("os.name");
        long timeSinceClick = System.currentTimeMillis() - LAST_CLICK_TIME;
        boolean isRecentClick = timeSinceClick < 500;
        
        HarbourLogger.log("DocHandler", "=== EXTERNAL HANDLER START === (count: " + count +
                ", clickMode: " + IS_CLICK_MODE + 
                ", timeSinceClick: " + timeSinceClick + "ms" +
                ", isRecentClick: " + isRecentClick +
                ", element: " + (element != null ? element.getText() : "null") + 
                ") on " + osName);

        if (element == null) {
            HarbourLogger.log("DocHandler", "=== EARLY EXIT === Element is null, returning null");
            return null;
        }
        

        // Check if this is a Harbour file
        PsiFile containingFile = element.getContainingFile();
        if (!(containingFile instanceof HarbourFile)) {
            HarbourLogger.log("DocHandler", "=== EARLY EXIT === Not a Harbour file, returning null");
            return null;
        }

        // Handle string literals (includes)
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement) element).getElementType() == HarbourTypes.STRING_LITERAL) {
            String includeFileName = element.getText().replace("\"", "").replace("'", "");
            HarbourLogger.log("DocHandler", "Processing STRING_LITERAL for possible include: " + includeFileName);

            // Check if we're in an include context - look at the entire line for #include
            String lineText = getLineText(element);
            HarbourLogger.log("DocHandler", "Line text: " + lineText);

            if (lineText != null && (lineText.contains("#include") || lineText.contains("#INCLUDE"))) {
                HarbourLogger.log("DocHandler", "Found #include directive in line: " + lineText);

                // If it's an actual click, let the include reference handler handle it
                if (IS_CLICK_MODE) {
                    HarbourLogger.log("DocHandler", "Click mode active for include file, delegating to include handler");
                    return null;
                }

                // For tooltips, provide a dummy target
                PsiElement dummyTarget = new HarbourDummyPsiElement(element, false, "Include File");
                return new PsiElement[] { dummyTarget };
            }
        }

        // Check if this is an identifier
        if (!(element instanceof LeafPsiElement) ||
                ((LeafPsiElement) element).getElementType() != HarbourTypes.IDENT) {
            HarbourLogger.log("DocHandler", "Not an IDENT element: " +
                    (element instanceof LeafPsiElement ? ((LeafPsiElement) element).getElementType() : "not LeafPsiElement"));
            return null;
        }

        String functionName = element.getText();
        HarbourLogger.log("DocHandler", "Processing identifier: " + functionName);

        // Check if this is part of a function call
        if (!isFunctionCall(((LeafPsiElement) element))) {
            // Check if this is a function declaration
            if (isFunctionDeclaration(((LeafPsiElement) element))) {
                HarbourLogger.log("DocHandler", "Function declaration detected: " + functionName + ", letting normal handlers take over");
                // Return null to let normal IntelliJ handlers (Find Usages, etc.) take over
                return null;
            }
            HarbourLogger.log("DocHandler", "Not a function call: " + functionName);
            return null;
        }

        // First check if this is a class method call (e.g., User():new())
        boolean isClassMethod = isClassMethodCall((LeafPsiElement) element);
        if (isClassMethod) {
            HarbourLogger.log("DocHandler", "Detected as class method call: " + functionName + ", not handling");
            // Don't interfere with class methods - let the class method handlers work
            return null;
        }

        // Check if it has internal declarations using the new classification service
        Project project = element.getProject();
        HarbourFunctionClassificationService classificationService = 
            HarbourFunctionClassificationService.getInstance(project);
        boolean isInternal = classificationService.isInternalFunction(functionName);

        if (isInternal) {
            HarbourLogger.log("DocHandler", "=== EARLY EXIT === Internal function detected: " + functionName + ", returning null");
            // Don't interfere with internal functions - let the normal handlers work
            return null;
        }

        // It's an external function
        HarbourLogger.log("DocHandler", "External function detected: " + functionName + 
                         ", clickMode=" + IS_CLICK_MODE + 
                         ", count=" + count + 
                         ", timeSinceClick=" + timeSinceClick + "ms");

        // Check if we're in click mode - only open browser on actual clicks, not hover
        boolean shouldOpenBrowser = IS_CLICK_MODE;
        
        if (shouldOpenBrowser) {
            HarbourLogger.log("DocHandler", "Opening documentation for external function: " + functionName);
            openExternalDocumentation(project, functionName);
            
            // Always reset click mode immediately after opening browser
            setClickMode(false);
        } else {
            HarbourLogger.log("DocHandler", "Not opening browser - no recent click detected for: " + functionName);
        }
        
        // Return a dummy element to prevent the "Cannot find declaration" popup
        // Returning empty array doesn't prevent the popup, but returning a dummy element does
        PsiElement dummyTarget = new HarbourDummyPsiElement(element, false, "External Function: " + functionName);
        HarbourLogger.log("DocHandler", "=== EXTERNAL HANDLER END === Returning dummy element to prevent popup for: " + functionName);
        return new PsiElement[] { dummyTarget };
    }

    /**
     * Determines if an element is a function call
     */
    private boolean isFunctionCall(LeafPsiElement element) {
        // Check if parent is a function call
        PsiElement parent = element.getParent();
        if (parent instanceof FunctionCallImpl) {
            HarbourLogger.log("DocHandler", "Direct function call identified via parent: " + element.getText());
            return true;
        }

        // Check for parenthesis after the element (with potential whitespace)
        PsiElement sibling = element.getNextSibling();
        while (sibling != null && sibling.getText().trim().isEmpty()) {
            sibling = sibling.getNextSibling();
        }

        boolean isFunction = sibling != null && sibling.getText().startsWith("(");
        if (isFunction) {
            HarbourLogger.log("DocHandler", "Function call identified by parenthesis: " + element.getText());
            return true;
        }
        
        return false;
    }

    /**
     * Check if the element is part of a class method call pattern like User():new()
     */
    private boolean isClassMethodCall(LeafPsiElement element) {
        String elementText = element.getText();

        // Get the line text for context
        String lineText = getLineText(element);
        if (lineText == null) {
            return false;
        }

        // Find where our element is in the line
        int pos = lineText.indexOf(elementText);
        if (pos < 0) {
            return false;
        }

        // First check case where element is the method part (after colon)
        String beforeElement = lineText.substring(0, pos).trim();
        if (beforeElement.endsWith(":")) {
            // Look for Class() pattern before the colon
            int closeParenPos = beforeElement.lastIndexOf(')');
            if (closeParenPos > 0 && beforeElement.indexOf('(') > 0) {
                HarbourLogger.log("DocHandler", "Detected class method: " + elementText + " after colon");
                return true;
            }
        }

        // Second check case where element is the class part (before colon)
        String afterElement = lineText.substring(pos + elementText.length()).trim();
        if (afterElement.startsWith("()") &&
                (afterElement.length() > 2 && (afterElement.charAt(2) == ':' || afterElement.charAt(2) == '.'))) {
            HarbourLogger.log("DocHandler", "Detected class: " + elementText + " before colon");
            return true;
        }

        // Generic check: any method after colon and parentheses pattern
        if (beforeElement.endsWith(":") && beforeElement.contains("(") && beforeElement.contains(")")) {
            HarbourLogger.log("DocHandler", "Found class method pattern for: " + elementText);
            return true;
        }

        return false;
    }

    /**
     * Get the full text of the line containing the element
     */
    private String getLineText(PsiElement element) {
        if (element == null || element.getContainingFile() == null) {
            return null;
        }

        PsiFile file = element.getContainingFile();
        String fileText = file.getText();
        if (fileText == null || fileText.isEmpty()) {
            return null;
        }

        int offset = element.getTextOffset();
        int startOffset = offset;
        int endOffset = offset;

        // Find the start of the line
        while (startOffset > 0 && fileText.charAt(startOffset - 1) != '\n') {
            startOffset--;
        }

        // Find the end of the line
        while (endOffset < fileText.length() && fileText.charAt(endOffset) != '\n') {
            endOffset++;
        }

        return fileText.substring(startOffset, endOffset);
    }

    /**
     * Check if a function has actual declarations (not just references) in the project
     */
    private boolean hasInternalDeclaration(Project project, String functionName) {
        if (project == null || functionName == null || functionName.isEmpty()) {
            return false;
        }

        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        if (service == null) {
            return false;
        }

        // Get all Harbour files in the project
        Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

        PsiManager psiManager = PsiManager.getInstance(project);

        // Direct search for function declarations in all project files
        for (VirtualFile virtualFile : virtualFiles) {
            if (service.isExcluded(virtualFile)) {
                continue;
            }

            PsiFile psiFile = psiManager.findFile(virtualFile);
            if (!(psiFile instanceof HarbourFile)) {
                continue;
            }

            HarbourFile harbourFile = (HarbourFile) psiFile;

            // Check for direct function declarations using PsiTreeUtil
            Collection<HarbourFunctionDeclaration> declarations =
                    PsiTreeUtil.findChildrenOfType(harbourFile, HarbourFunctionDeclaration.class);

            for (HarbourFunctionDeclaration decl : declarations) {
                String declName = decl.getName();
                if (declName != null && functionName.equalsIgnoreCase(declName)) {
                    HarbourLogger.log("DocHandler", "Found function declaration: " + declName + " in " + virtualFile.getName());
                    return true;
                }
            }

            // Fallback to text-based search for FUNCTION keyword if PSI search fails
            String fileContent = harbourFile.getText();

            // Search for function and method declarations
            // Enhanced to catch class methods too
            Pattern functionPattern = Pattern.compile(
                    "(?i)\\b(FUNCTION|PROCEDURE|METHOD)\\s+" + Pattern.quote(functionName) + "\\b");

            Matcher matcher = functionPattern.matcher(fileContent);
            if (matcher.find()) {
                HarbourLogger.log("DocHandler", "Found text-based declaration for: " + functionName +
                        " type: " + matcher.group(1) + " in " + virtualFile.getName());
                return true;
            }
        }

        // Also check if it's a standard function
        if (HarbourStandardFunctionCache.isStandardFunction(functionName)) {
            HarbourLogger.log("DocHandler", "Standard function detected: " + functionName);
            // For UI purposes, treat standard functions as external
            return false;
        }

        HarbourLogger.log("DocHandler", "No internal declarations found for: " + functionName);
        return false;
    }

    /**
     * Opens documentation in a browser
     */
    private void openExternalDocumentation(Project project, String functionName) {
        HarbourLogger.log("DocHandler", "openExternalDocumentation called for: " + functionName + 
                         " in project: " + (project != null ? project.getName() : "null"));
        
        HarbourSettings settings = HarbourSettings.getInstance(project);
        HarbourLogger.log("DocHandler", "Settings instance: " + (settings != null ? "found" : "null"));
        
        if (settings == null) {
            HarbourLogger.log("DocHandler", "ERROR: HarbourSettings instance is null");
            return;
        }
        
        String baseUrl = settings.getDocumentationBaseUrl();
        HarbourLogger.log("DocHandler", "Base URL from settings: '" + baseUrl + "'");
        
        if (baseUrl == null || baseUrl.isEmpty()) {
            HarbourLogger.log("DocHandler", "ERROR: Documentation base URL not configured - using default");
            baseUrl = "https://harbour.github.io/doc/clc53.html";
        }

        if (!baseUrl.endsWith("#") && !baseUrl.endsWith("/")) {
            baseUrl = baseUrl + "#";
        }

        String docUrl = baseUrl + functionName;
        HarbourLogger.log("DocHandler", "Final URL to open: " + docUrl);

        // Check if we've recently opened this URL to prevent duplicates
        long currentTime = System.currentTimeMillis();
        Long lastOpenTime = recentlyOpenedUrls.get(docUrl);
        
        if (lastOpenTime != null && (currentTime - lastOpenTime) < DUPLICATE_PREVENTION_WINDOW_MS) {
            HarbourLogger.log("DocHandler", "Skipping duplicate URL opening: " + docUrl + 
                            " (opened " + (currentTime - lastOpenTime) + "ms ago)");
            return;
        }

        // Clean up old entries from the cache (older than 10 seconds)
        recentlyOpenedUrls.entrySet().removeIf(entry -> 
            (currentTime - entry.getValue()) > 10000);

        // Check if a browser is configured before attempting to open
        WebBrowserManager browserManager = WebBrowserManager.getInstance();
        boolean hasBrowsers = !browserManager.getActiveBrowsers().isEmpty();
        
        HarbourLogger.log("DocHandler", "Browser check - has browsers: " + hasBrowsers + 
                         ", active browsers: " + browserManager.getActiveBrowsers().size());
        
        // Show notification if no browsers configured
        if (!hasBrowsers) {
            HarbourLogger.log("DocHandler", "No browsers configured, showing notification for external function: " + functionName);
            showBrowserConfigurationNotification(project, functionName, docUrl, "No browsers configured");
            return;
        }
        
        boolean browserLaunchFailed = false;
        String errorMessage = null;
        
        try {
            // Add platform-specific logging
            String osName = System.getProperty("os.name");
            HarbourLogger.log("DocHandler", "OS detected: " + osName + " - attempting to open: " + docUrl);
            
            BrowserUtil.browse(docUrl);
            
            // Record this URL opening to prevent duplicates
            recentlyOpenedUrls.put(docUrl, currentTime);
            
            HarbourLogger.log("DocHandler", "BrowserUtil.browse() called successfully for: " + docUrl);
        } catch (Exception e) {
            browserLaunchFailed = true;
            errorMessage = e.getMessage();
            HarbourLogger.log("DocHandler", "ERROR opening browser: " + errorMessage);
            HarbourLogger.log("DocHandler", "Exception stack trace: " + java.util.Arrays.toString(e.getStackTrace()));
        }
        
        // Always show notification for ALL external functions to test if it works
        // This catches cases where BrowserUtil.browse() doesn't throw exception but browser still fails
        HarbourLogger.log("DocHandler", "Showing notification for all external functions for testing: " + functionName);
        String message = errorMessage != null ? errorMessage : "Browser configuration test - please verify browser opens correctly";
        showBrowserConfigurationNotification(project, functionName, docUrl, message);
    }
    
    /**
     * Show a user-friendly notification when browser opening fails, with instructions to configure browser settings.
     */
    private void showBrowserConfigurationNotification(Project project, String functionName, String docUrl, String errorMessage) {
        HarbourLogger.log("DocHandler", "showBrowserConfigurationNotification called for function: " + functionName);
        
        String title = "Documentation Access";
        String content = String.format(
            "Documentation for function '%s'.<br/>" +
            "If browser did not open, configure it in PyCharm settings.<br/>" +
            "URL: <a href=\"%s\">%s</a>",
            functionName, docUrl, docUrl
        );
        
        HarbourLogger.log("DocHandler", "Creating notification with title: " + title);
        HarbourLogger.log("DocHandler", "Notification content: " + content);
        
        try {
            // Create notification with action to open settings
            Notification notification = NotificationGroupManager.getInstance()
                .getNotificationGroup("Harbour Application")
                .createNotification(title, content, NotificationType.WARNING)
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
                    java.awt.datatransfer.StringSelection selection = new java.awt.datatransfer.StringSelection(docUrl);
                    java.awt.Toolkit.getDefaultToolkit().getSystemClipboard().setContents(selection, null);
                    
                    // Show a brief success message
                    NotificationGroupManager.getInstance()
                        .getNotificationGroup("Harbour Application")
                        .createNotification("URL copied to clipboard", NotificationType.INFORMATION)
                        .notify(project);
                    
                    notification.expire();
                }
            });
        
            notification.notify(project);
            
            HarbourLogger.log("DocHandler", "Notification displayed successfully for function: " + functionName);
        } catch (Exception e) {
            HarbourLogger.log("DocHandler", "ERROR creating/showing notification: " + e.getMessage());
            HarbourLogger.log("DocHandler", "Notification exception: " + java.util.Arrays.toString(e.getStackTrace()));
        }
    }
    
    /**
     * Check if an element is part of a function declaration.
     * @param element The element to check
     * @return true if this element is in a function declaration line
     */
    private boolean isFunctionDeclaration(LeafPsiElement element) {
        // Get the line text
        String lineText = getLineText(element);
        if (lineText == null) {
            return false;
        }
        
        // Check if the line contains FUNCTION or PROCEDURE declaration
        String functionName = element.getText();
        Pattern pattern = Pattern.compile("(?i)\\b(FUNCTION|PROCEDURE)\\s+" + Pattern.quote(functionName) + "\\b");
        boolean isDeclaration = pattern.matcher(lineText).find();
        
        HarbourLogger.log("DocHandler", "Checking if declaration for " + functionName + ": " + isDeclaration);
        return isDeclaration;
    }

    /**
     * Ensure the mouse listener is registered for this project
     */
    private static synchronized void ensureMouseListenerRegistered(Project project) {
        if (MOUSE_LISTENER_REGISTERED || project == null) {
            return;
        }
        
        try {
            HarbourMouseListener listener = new HarbourMouseListener();
            com.intellij.openapi.editor.EditorFactory.getInstance().getEventMulticaster()
                .addEditorMouseListener(listener, project);
            com.intellij.openapi.editor.EditorFactory.getInstance().getEventMulticaster()
                .addEditorMouseMotionListener(listener, project);
            
            MOUSE_LISTENER_REGISTERED = true;
            HarbourLogger.log("DocHandler", "Mouse listener registered successfully");
        } catch (Exception e) {
            HarbourLogger.log("DocHandler", "Failed to register mouse listener: " + e.getMessage());
        }
    }
}

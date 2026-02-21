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
    }
    // Using static variable since ThreadLocal wasn't working correctly
    private static volatile boolean IS_CLICK_MODE = false;
    private static volatile long LAST_CLICK_TIME = 0;
    private static final AtomicInteger CALL_COUNTER = new AtomicInteger(0);
    private static boolean MOUSE_LISTENER_REGISTERED = false;
    
    // Flag to prevent premature click mode reset during concurrent handler processing
    private static volatile boolean CLICK_MODE_LOCKED = false;
    private static final Object CLICK_MODE_LOCK = new Object();
    
    // Cache to prevent duplicate browser openings within a short time window
    private static final Map<String, Long> recentlyOpenedUrls = new HashMap<>();
    private static final long DUPLICATE_PREVENTION_WINDOW_MS = 2000; // 2 seconds

    // Method to set click mode - called from mouse listener
    public static void setClickMode(boolean isClick) {
        synchronized (CLICK_MODE_LOCK) {
            IS_CLICK_MODE = isClick;
            if (isClick) {
                LAST_CLICK_TIME = System.currentTimeMillis();
                CALL_COUNTER.set(0);
                CLICK_MODE_LOCKED = true; // Lock to prevent premature reset during processing
            } else if (!CLICK_MODE_LOCKED) {
                // Only reset if not locked during active processing
                IS_CLICK_MODE = false;
            } else {
                HarbourLogger.trace("DocHandler", "Click mode reset blocked - system is locked during processing");
            }
        }
    }
    
    // Method to check if currently in click mode - used by main handler for consistency
    public static boolean isClickMode() {
        synchronized (CLICK_MODE_LOCK) {
            // Defensive check: auto-expire click mode if too much time has passed
            if (IS_CLICK_MODE) {
                long timeSinceClick = System.currentTimeMillis() - LAST_CLICK_TIME;
                if (timeSinceClick > 5000) { // 5 second safety timeout
                    IS_CLICK_MODE = false;
                    CLICK_MODE_LOCKED = false;
                }
            }
            return IS_CLICK_MODE;
        }
    }
    
    // Method to safely reset click mode after processing - prevents race conditions
    public static void resetClickMode() {
        synchronized (CLICK_MODE_LOCK) {
            IS_CLICK_MODE = false;
            CLICK_MODE_LOCKED = false;
        }
    }
    
    // Method to check if click mode should be handled (recent click within timeout)
    public static boolean shouldHandleAsClick() {
        synchronized (CLICK_MODE_LOCK) {
            if (!IS_CLICK_MODE) {
                return false;
            }
            
            long timeSinceClick = System.currentTimeMillis() - LAST_CLICK_TIME;
            if (timeSinceClick > 2000) { // 2 second timeout for click events
                IS_CLICK_MODE = false;
                CLICK_MODE_LOCKED = false;
                return false;
            }
            
            return true;
        }
    }

    @Override
    public PsiElement @Nullable [] getGotoDeclarationTargets(@Nullable PsiElement element, int offset, Editor editor) {
        CALL_COUNTER.incrementAndGet();

        // Ensure mouse listener is registered on first call
        if (!MOUSE_LISTENER_REGISTERED && element != null) {
            ensureMouseListenerRegistered(element.getProject());
        }
        

        if (element == null) {
            return null;
        }
        

        // Check if this is a Harbour file
        PsiFile containingFile = element.getContainingFile();
        if (!(containingFile instanceof HarbourFile)) {
            return null;
        }

        // Handle string literals (includes)
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement) element).getElementType() == HarbourTypes.STRING_LITERAL) {
            // Check if we're in an include context - look at the entire line for #include
            String lineText = getLineText(element);

            if (lineText != null && (lineText.contains("#include") || lineText.contains("#INCLUDE"))) {
                // If it's an actual click, let the include reference handler handle it
                if (IS_CLICK_MODE) {
                    return null;
                }

                // Return empty array to prevent tooltips on hover
                return PsiElement.EMPTY_ARRAY;
            }
        }

        // Check if this is an identifier
        if (!(element instanceof LeafPsiElement) ||
                ((LeafPsiElement) element).getElementType() != HarbourTypes.IDENT) {
            return null;
        }

        String functionName = element.getText();

        // Check if this is part of a function call
        if (!isFunctionCall(((LeafPsiElement) element))) {
            // Check if this is a function declaration
            if (isFunctionDeclaration(((LeafPsiElement) element))) {
                return null;
            }
            return null;
        }

        // First check if this is a class method call (e.g., User():new())
        boolean isClassMethod = isClassMethodCall((LeafPsiElement) element);
        if (isClassMethod) {
            return null;
        }

        // Check if it has internal declarations using the new classification service
        Project project = element.getProject();
        HarbourFunctionClassificationService classificationService = 
            HarbourFunctionClassificationService.getInstance(project);
        boolean isInternal = classificationService.isInternalFunction(functionName);

        if (isInternal) {
            return null;
        }

        // Check if we're in click mode - only open browser on actual clicks, not hover
        boolean shouldOpenBrowser = shouldHandleAsClick();
        
        if (shouldOpenBrowser) {
            HarbourLogger.log("DocHandler", "Opening documentation for: " + functionName);
            openExternalDocumentation(project, functionName);
            resetClickMode();
            return PsiElement.EMPTY_ARRAY;
        } else {
            // Return empty array to prevent popups on hover
            return PsiElement.EMPTY_ARRAY;
        }
    }

    /**
     * Determines if an element is a function call
     */
    private boolean isFunctionCall(LeafPsiElement element) {
        // Check if parent is a function call
        PsiElement parent = element.getParent();
        if (parent instanceof FunctionCallImpl) {
            return true;
        }

        // Check for parenthesis after the element (with potential whitespace)
        PsiElement sibling = element.getNextSibling();
        while (sibling != null && sibling.getText().trim().isEmpty()) {
            sibling = sibling.getNextSibling();
        }

        boolean isFunction = sibling != null && sibling.getText().startsWith("(");
        if (isFunction) {
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
                return true;
            }
        }

        // Second check case where element is the class part (before colon)
        String afterElement = lineText.substring(pos + elementText.length()).trim();
        if (afterElement.startsWith("()") &&
                (afterElement.length() > 2 && (afterElement.charAt(2) == ':' || afterElement.charAt(2) == '.'))) {
            return true;
        }

        // Generic check: any method after colon and parentheses pattern
        if (beforeElement.endsWith(":") && beforeElement.contains("(") && beforeElement.contains(")")) {
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
                return true;
            }
        }

        // Also check if it's a standard function
        if (HarbourStandardFunctionCache.isStandardFunction(functionName)) {
            return false;
        }

        return false;
    }

    /**
     * Opens documentation in a browser
     */
    private void openExternalDocumentation(Project project, String functionName) {
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings == null) {
            HarbourLogger.warning("DocHandler", "HarbourSettings instance is null");
            return;
        }

        String baseUrl = settings.getDocumentationBaseUrl();
        if (baseUrl == null || baseUrl.isEmpty()) {
            baseUrl = "https://harbour.github.io/doc/clc53.html";
        }

        if (!baseUrl.endsWith("#") && !baseUrl.endsWith("/")) {
            baseUrl = baseUrl + "#";
        }

        String docUrl = baseUrl + functionName;

        // Check if we've recently opened this URL to prevent duplicates
        long currentTime = System.currentTimeMillis();
        Long lastOpenTime = recentlyOpenedUrls.get(docUrl);

        if (lastOpenTime != null && (currentTime - lastOpenTime) < DUPLICATE_PREVENTION_WINDOW_MS) {
            return;
        }

        // Clean up old entries from the cache (older than 10 seconds)
        recentlyOpenedUrls.entrySet().removeIf(entry ->
            (currentTime - entry.getValue()) > 10000);

        // Check if a browser is configured before attempting to open
        WebBrowserManager browserManager = WebBrowserManager.getInstance();
        boolean hasBrowsers = !browserManager.getActiveBrowsers().isEmpty();

        if (!hasBrowsers) {
            HarbourLogger.warning("DocHandler", "No browsers configured for: " + functionName);
            showBrowserConfigurationNotification(project, functionName, docUrl, "No browsers configured");
            return;
        }

        try {
            BrowserUtil.browse(docUrl);
            recentlyOpenedUrls.put(docUrl, currentTime);
        } catch (Exception e) {
            HarbourLogger.error("DocHandler", "Failed to open browser for " + functionName + ": " + e.getMessage());
            showBrowserConfigurationNotification(project, functionName, docUrl, e.getMessage());
        }
    }
    
    /**
     * Show a user-friendly notification when browser opening fails, with instructions to configure browser settings.
     */
    private void showBrowserConfigurationNotification(Project project, String functionName, String docUrl, String errorMessage) {
        String title = "Documentation Access";
        String content = String.format(
            "Documentation for function '%s'.<br/>" +
            "If browser did not open, configure it in PyCharm settings.<br/>" +
            "URL: <a href=\"%s\">%s</a>",
            functionName, docUrl, docUrl
        );

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
        } catch (Exception e) {
            HarbourLogger.error("DocHandler", "Notification failed: " + e.getMessage());
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
        return pattern.matcher(lineText).find();
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
        } catch (Exception e) {
            HarbourLogger.error("DocHandler", "Failed to register mouse listener: " + e.getMessage());
        }
    }
}

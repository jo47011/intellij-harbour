package org.intellij.sdk.language;

import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.ui.popup.JBPopupFactory;
import com.intellij.pom.Navigatable;
import com.intellij.psi.PsiElement;
import com.intellij.ui.components.JBList;
import com.intellij.openapi.editor.colors.EditorColorsManager;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.markup.TextAttributes;

import javax.swing.*;
import java.awt.*;
import java.awt.event.ActionEvent;
import java.util.ArrayList;
import java.util.List;

/**
 * Custom navigation popup for Harbour elements with syntax highlighting support
 */
public class HarbourNavigationPopup {
    private static final String COMPONENT = "NavigationPopup";

    /**
     * Show a custom navigation popup with syntax-highlighted code
     * @param targets List of navigation targets
     * @param editor The current editor
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor) {
        showNavigationPopup(targets, editor, null);
    }
    
    /**
     * Show a custom navigation popup with syntax-highlighted code
     * @param targets List of navigation targets
     * @param editor The current editor
     * @param searchedFunctionName The function name being searched for (optional)
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor, String searchedFunctionName) {
        HarbourLogger.log(COMPONENT, "Showing custom navigation popup with " + targets.size() + " targets");
        
        // Get the max results setting
        HarbourSettings settings = HarbourSettings.getInstance(editor.getProject());
        int maxResults = settings.getMaxNavigationResults();
        
        // Check if we need to limit results
        boolean hasMore = targets.size() > maxResults;
        List<PsiElement> displayTargets = hasMore ? 
            new ArrayList<>(targets.subList(0, maxResults)) : 
            new ArrayList<>(targets);
        
        HarbourLogger.log(COMPONENT, "Max results: " + maxResults + ", Total targets: " + targets.size() + 
                          ", Has more: " + hasMore + ", Display targets before: " + displayTargets.size());
        
        // Add a special element to indicate there are more results
        if (hasMore) {
            int remainingCount = targets.size() - maxResults;
            String message = String.format("↓ ... and %d more results. Click to load all.", remainingCount);
            HarbourNavigationElement moreElement = HarbourNavigationElement.createLoadAllElement(
                editor.getProject(), 
                message
            );
            if (moreElement != null) {
                displayTargets.add(moreElement);
                HarbourLogger.log(COMPONENT, "Added Load All element. Display targets after: " + displayTargets.size());
            } else {
                HarbourLogger.log(COMPONENT, "Failed to create Load All element");
            }
        }

        // Create the list with custom renderer that can highlight the searched function
        JBList<PsiElement> list = new JBList<>(displayTargets);
        list.setCellRenderer(new HarbourNavigationListRenderer(searchedFunctionName));
        
        // Set visible row count to show all items in displayTargets (up to a reasonable limit)
        list.setVisibleRowCount(Math.min(displayTargets.size(), 30)); // Max 30 visible rows

        // Create the title with HTML formatting for alignment
        String title;
        if (searchedFunctionName != null) {
            // Get the color for local functions from the color scheme
            String functionColor = "#0066CC"; // Default blue
            try {
                EditorColorsScheme scheme = EditorColorsManager.getInstance().getGlobalScheme();
                TextAttributes attrs = scheme.getAttributes(HarbourSyntaxHighlighter.LOCAL_FUNCTION);
                if (attrs != null && attrs.getForegroundColor() != null) {
                    Color color = attrs.getForegroundColor();
                    functionColor = String.format("#%02x%02x%02x", color.getRed(), color.getGreen(), color.getBlue());
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error getting local function color: " + e.getMessage());
            }
            
            // Create HTML title with function name on the left
            String declarationText = hasMore ? 
                String.format("Choose Declaration (showing %d of %d)", displayTargets.size() - 1, targets.size()) :
                "Choose Declaration";
            
            // Simple title: function name on left, declaration text stays centered by popup
            title = String.format("<html><b style='color:%s'>%s</b>&nbsp;&nbsp;&nbsp;&nbsp;%s</html>", 
                functionColor, searchedFunctionName, declarationText);
        } else {
            title = hasMore ? 
                String.format("Choose Declaration (showing %d of %d)", displayTargets.size(), targets.size()) :
                "Choose Declaration";
        }
        
        // Create and show the popup using the original working approach
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(title)
                .setItemChoosenCallback(() -> {
                    PsiElement selected = list.getSelectedValue();
                    
                    // Check if "Load All" was clicked
                    if (selected instanceof HarbourNavigationElement && 
                        ((HarbourNavigationElement) selected).isSeparator() &&
                        ((HarbourNavigationElement) selected).getElementName() != null &&
                        ((HarbourNavigationElement) selected).getElementName().contains("more results")) {
                        // Show all results
                        showNavigationPopup(targets, editor, searchedFunctionName, true);
                    } else if (selected instanceof Navigatable) {
                        HarbourLogger.log(COMPONENT, "Navigating to selected target: " + selected);
                        ((Navigatable) selected).navigate(true);
                    }
                })
                .createPopup()
                .showInBestPositionFor(editor);
    }
    
    /**
     * Show navigation popup with option to show all results
     * @param targets List of navigation targets
     * @param editor The current editor
     * @param showAll Whether to show all results regardless of limit
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor, boolean showAll) {
        showNavigationPopup(targets, editor, null, showAll);
    }
    
    /**
     * Show navigation popup with option to show all results
     * @param targets List of navigation targets
     * @param editor The current editor
     * @param searchedFunctionName The function name being searched for (optional)
     * @param showAll Whether to show all results regardless of limit
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor, String searchedFunctionName, boolean showAll) {
        if (!showAll) {
            showNavigationPopup(targets, editor, searchedFunctionName);
            return;
        }
        
        HarbourLogger.log(COMPONENT, "Showing ALL " + targets.size() + " navigation targets");
        
        // Create the list with custom renderer showing all results
        JBList<PsiElement> list = new JBList<>(targets);
        list.setCellRenderer(new HarbourNavigationListRenderer(searchedFunctionName));

        // Create and show the popup with all results
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(searchedFunctionName != null ?
                    createHtmlTitle(searchedFunctionName, String.format("Choose Declaration (showing all %d results)", targets.size())) :
                    String.format("Choose Declaration (showing all %d results)", targets.size()))
                .setItemChoosenCallback(() -> {
                    PsiElement selected = list.getSelectedValue();
                    if (selected instanceof Navigatable) {
                        HarbourLogger.log(COMPONENT, "Navigating to selected target: " + selected);
                        ((Navigatable) selected).navigate(true);
                    }
                })
                .createPopup()
                .showInBestPositionFor(editor);
    }
    
    /**
     * Create HTML title with colored function name
     */
    private static String createHtmlTitle(String functionName, String declarationText) {
        // Get the color for local functions from the color scheme
        String functionColor = "#0066CC"; // Default blue
        try {
            EditorColorsScheme scheme = EditorColorsManager.getInstance().getGlobalScheme();
            TextAttributes attrs = scheme.getAttributes(HarbourSyntaxHighlighter.LOCAL_FUNCTION);
            if (attrs != null && attrs.getForegroundColor() != null) {
                Color color = attrs.getForegroundColor();
                functionColor = String.format("#%02x%02x%02x", color.getRed(), color.getGreen(), color.getBlue());
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error getting local function color: " + e.getMessage());
        }
        
        // Simple title: function name on left, declaration text stays centered by popup
        return String.format("<html><b style='color:%s'>%s</b>&nbsp;&nbsp;&nbsp;&nbsp;%s</html>", 
            functionColor, functionName, declarationText);
    }
}
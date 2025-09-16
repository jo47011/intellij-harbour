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
import java.util.function.Supplier;

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
        showNavigationPopup(targets, editor, searchedFunctionName, -1);
    }
    
    /**
     * Show a custom navigation popup with syntax-highlighted code
     * @param targets List of navigation targets (may be limited subset)
     * @param editor The current editor
     * @param searchedFunctionName The function name being searched for (optional)
     * @param actualTotalCount The actual total count before limiting (-1 if same as targets.size())
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor, String searchedFunctionName, int actualTotalCount) {
        showNavigationPopup(targets, editor, searchedFunctionName, actualTotalCount, null);
    }
    
    /**
     * Show a custom navigation popup with syntax-highlighted code
     * @param targets List of navigation targets (may be limited subset)
     * @param editor The current editor
     * @param searchedFunctionName The function name being searched for (optional)
     * @param actualTotalCount The actual total count before limiting (-1 if same as targets.size())
     * @param allResultsSupplier Supplier to get all results when Load All is clicked (optional)
     */
    public static void showNavigationPopup(List<PsiElement> targets, Editor editor, String searchedFunctionName, int actualTotalCount, Supplier<List<PsiElement>> allResultsSupplier) {
        HarbourLogger.log(COMPONENT, "Showing custom navigation popup with " + targets.size() + " targets" +
                (actualTotalCount > 0 ? " (actual total: " + actualTotalCount + ")" : ""));
        
        // Get the max results setting
        HarbourSettings settings = HarbourSettings.getInstance(editor.getProject());
        int maxResults = settings.getMaxNavigationResults();
        
        // Use actual total count if provided, otherwise use targets size
        int totalCount = actualTotalCount > 0 ? actualTotalCount : targets.size();
        
        // Check if we need to limit results
        boolean hasMore = targets.size() > maxResults;
        List<PsiElement> displayTargets = hasMore ? 
            new ArrayList<>(targets.subList(0, maxResults)) : 
            new ArrayList<>(targets);
        
        HarbourLogger.log(COMPONENT, "Max results: " + maxResults + ", Total targets: " + targets.size() + 
                          ", Has more: " + hasMore + ", Display targets before: " + displayTargets.size());
        
        // Add a special element to indicate there are more results
        if (hasMore) {
            int remainingCount = totalCount - maxResults;
            String message = totalCount > targets.size() ? 
                String.format("↓ ... and %d more results. Click to load all.", remainingCount) :
                String.format("↓ ... and %d more results. Click to load all.", remainingCount);
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
            String declarationText;
            if (hasMore) {
                if (totalCount > targets.size()) {
                    // We hit the processing limit, show approximate count
                    declarationText = String.format("Choose Declaration (showing %d of %d)", displayTargets.size() - 1, totalCount);
                } else {
                    declarationText = String.format("Choose Declaration (showing %d of %d)", displayTargets.size() - 1, totalCount);
                }
            } else {
                declarationText = "Choose Declaration";
            }
            
            // Simple title: function name on left, declaration text stays centered by popup
            title = String.format("<html><b style='color:%s'>%s</b>&nbsp;&nbsp;&nbsp;&nbsp;%s</html>", 
                functionColor, searchedFunctionName, declarationText);
        } else {
            if (hasMore) {
                if (totalCount > targets.size()) {
                    title = String.format("Choose Declaration (showing %d of %d)", displayTargets.size(), totalCount);
                } else {
                    title = String.format("Choose Declaration (showing %d of %d)", displayTargets.size(), totalCount);
                }
            } else {
                title = "Choose Declaration";
            }
        }
        
        // Create and show the popup using the original working approach
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(title)
                .setMovable(true)
                .setResizable(true)
                .setItemChoosenCallback(() -> {
                    PsiElement selected = list.getSelectedValue();
                    
                    // Check if "Load All" was clicked
                    if (selected instanceof HarbourNavigationElement && 
                        ((HarbourNavigationElement) selected).isSeparator() &&
                        ((HarbourNavigationElement) selected).getElementName() != null &&
                        ((HarbourNavigationElement) selected).getElementName().contains("more results")) {
                        // Show all results
                        if (allResultsSupplier != null) {
                            // Use the supplier to get all results
                            List<PsiElement> allResults = allResultsSupplier.get();
                            if (allResults != null && !allResults.isEmpty()) {
                                // Load all results from supplier
                                showNavigationPopup(allResults, editor, searchedFunctionName, true);
                            } else {
                                // Fallback to current targets if supplier returns null
                                showNavigationPopup(targets, editor, searchedFunctionName, true);
                            }
                        } else {
                            // Fallback to showing current targets if no supplier provided
                            showNavigationPopup(targets, editor, searchedFunctionName, true);
                        }
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
        
        HarbourLogger.log(COMPONENT, "Showing all " + targets.size() + " navigation targets");
        
        // Create the list with custom renderer showing all results
        JBList<PsiElement> list = new JBList<>(targets);
        list.setCellRenderer(new HarbourNavigationListRenderer(searchedFunctionName));

        // Create and show the popup with all results
        String titleSuffix = String.format("Choose Declaration (showing all %d results)", targets.size());
        
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(searchedFunctionName != null ?
                    createHtmlTitle(searchedFunctionName, titleSuffix) :
                    titleSuffix)
                .setMovable(true)
                .setResizable(true)
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
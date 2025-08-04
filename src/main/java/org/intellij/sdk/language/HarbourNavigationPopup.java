package org.intellij.sdk.language;

import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.ui.popup.JBPopupFactory;
import com.intellij.pom.Navigatable;
import com.intellij.psi.PsiElement;
import com.intellij.ui.components.JBList;

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
            String message = String.format("... and %d more results. Click to load all.", remainingCount);
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

        // Create the list with custom renderer
        JBList<PsiElement> list = new JBList<>(displayTargets);
        list.setCellRenderer(new HarbourNavigationListRenderer());
        
        // Set visible row count to show all items in displayTargets (up to a reasonable limit)
        list.setVisibleRowCount(Math.min(displayTargets.size(), 30)); // Max 30 visible rows

        // Create and show the popup using the original working approach
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(hasMore ? 
                    String.format("Choose Declaration (showing %d of %d)", displayTargets.size(), targets.size()) :
                    "Choose Declaration")
                .setItemChoosenCallback(() -> {
                    PsiElement selected = list.getSelectedValue();
                    
                    // Check if "Load All" was clicked
                    if (selected instanceof HarbourNavigationElement && 
                        ((HarbourNavigationElement) selected).isSeparator() &&
                        ((HarbourNavigationElement) selected).getElementName() != null &&
                        ((HarbourNavigationElement) selected).getElementName().contains("more results")) {
                        // Show all results
                        showNavigationPopup(targets, editor, true);
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
        if (!showAll) {
            showNavigationPopup(targets, editor);
            return;
        }
        
        HarbourLogger.log(COMPONENT, "Showing ALL " + targets.size() + " navigation targets");
        
        // Create the list with custom renderer showing all results
        JBList<PsiElement> list = new JBList<>(targets);
        list.setCellRenderer(new HarbourNavigationListRenderer());

        // Create and show the popup with all results
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle(String.format("Choose Declaration (showing all %d results)", targets.size()))
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
}
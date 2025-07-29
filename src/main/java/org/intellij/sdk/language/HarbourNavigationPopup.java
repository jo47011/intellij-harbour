package org.intellij.sdk.language;

import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.ui.popup.JBPopupFactory;
import com.intellij.pom.Navigatable;
import com.intellij.psi.PsiElement;
import com.intellij.ui.components.JBList;

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

        // Create the list with custom renderer
        JBList<PsiElement> list = new JBList<>(targets);
        list.setCellRenderer(new HarbourNavigationListRenderer());

        // Create and show the popup using the original working approach
        JBPopupFactory.getInstance()
                .createListPopupBuilder(list)
                .setTitle("Choose Declaration")
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
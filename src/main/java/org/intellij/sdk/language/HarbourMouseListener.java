package org.intellij.sdk.language;

import com.intellij.openapi.editor.event.EditorMouseEvent;
import com.intellij.openapi.editor.event.EditorMouseListener;
import com.intellij.openapi.editor.event.EditorMouseMotionListener;

/**
 * Mouse listener for Harbour plugin that detects actual mouse clicks vs. hover
 */
public class HarbourMouseListener implements EditorMouseListener, EditorMouseMotionListener {
    private static final String COMPONENT = "MouseListener";
    private static final long CLICK_TIMEOUT = 1000; // 1 second

    private static long lastClickTime = 0;

    /**
     * Get current click state - used by handlers to determine if in click or hover mode
     * @return true if currently in a click operation (not hover)
     */
    public static boolean isClickOperation() {
        long timeSinceClick = System.currentTimeMillis() - lastClickTime;
        return timeSinceClick < CLICK_TIMEOUT;
    }

    @Override
    public void mouseClicked(EditorMouseEvent event) {
        if (event.getMouseEvent().isControlDown()) {
            HarbourLogger.logImportant(COMPONENT, "Ctrl+Click detected - setting click mode");
            lastClickTime = System.currentTimeMillis();
            HarbourExternalDocumentationHandler.setClickMode(true);
        }
    }

    @Override
    public void mousePressed(EditorMouseEvent event) {
        if (event.getMouseEvent().isControlDown()) {
            HarbourLogger.logImportant(COMPONENT, "Ctrl+Press detected - setting click mode");
            lastClickTime = System.currentTimeMillis();
            HarbourExternalDocumentationHandler.setClickMode(true);
        }
    }

    @Override
    public void mouseReleased(EditorMouseEvent event) {
        // No action needed
    }

    @Override
    public void mouseEntered(EditorMouseEvent event) {
        // No action needed
    }

    @Override
    public void mouseExited(EditorMouseEvent event) {
        // No action needed
    }

    @Override
    public void mouseMoved(EditorMouseEvent event) {
        // CRITICAL: Do not update click mode on hover
        // This prevents hover from canceling click operations
        if (event.getMouseEvent().isControlDown()) {
            HarbourLogger.log(COMPONENT, "Ctrl+Hover detected (ignoring)");
        }
    }

    @Override
    public void mouseDragged(EditorMouseEvent event) {
        // No action needed
    }
}
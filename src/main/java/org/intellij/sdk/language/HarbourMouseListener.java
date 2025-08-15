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


    @Override
    public void mouseClicked(EditorMouseEvent event) {
        // No action needed - we only handle mousePressed to avoid double-triggering
    }

    @Override
    public void mousePressed(EditorMouseEvent event) {
        boolean ctrlDown = event.getMouseEvent().isControlDown();
        HarbourLogger.log(COMPONENT, "Mouse pressed - Ctrl down: " + ctrlDown);
        
        if (ctrlDown) {
            HarbourLogger.log(COMPONENT, "Ctrl+Press detected - setting click mode to TRUE");
            lastClickTime = System.currentTimeMillis();
            HarbourExternalDocumentationHandler.setClickMode(true);
        } else {
            HarbourLogger.log(COMPONENT, "Mouse pressed without Ctrl - setting click mode to FALSE");
            HarbourExternalDocumentationHandler.setClickMode(false);
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
        // CRITICAL: Do not interfere with click mode on hover events
        // The ExternalDocumentationHandler now has its own timeout mechanism
        boolean ctrlDown = event.getMouseEvent().isControlDown();
        
        if (ctrlDown) {
            HarbourLogger.log(COMPONENT, "Ctrl+Hover detected - click mode: " + 
                HarbourExternalDocumentationHandler.isClickMode());
        }
        
        // No longer manage timeout here - let the ExternalDocumentationHandler handle it
        // This prevents race conditions between mouse events and handler processing
    }

    @Override
    public void mouseDragged(EditorMouseEvent event) {
        // No action needed
    }
}
package org.intellij.sdk.language;

import com.intellij.psi.PsiElement;
import com.intellij.psi.SmartPsiElementPointer;
import com.intellij.psi.SmartPointerManager;

/**
 * A lazy wrapper for navigation elements that defers creation of the actual
 * HarbourNavigationElement until it's needed for display.
 * This significantly improves performance when dealing with large result sets.
 */
public class LazyNavigationElement {
    private final SmartPsiElementPointer<PsiElement> targetPointer;
    private final String elementName;
    private final String filePath;
    private final int lineNumber;
    private final String contextInfo;
    private final boolean isDefinition;
    private final boolean isSeparator;
    private HarbourNavigationElement cachedElement;
    
    public LazyNavigationElement(PsiElement target, String elementName, String filePath,
                                 int lineNumber, String contextInfo,
                                 boolean isDefinition, boolean isSeparator) {
        this.targetPointer = SmartPointerManager.getInstance(target.getProject())
            .createSmartPsiElementPointer(target);
        this.elementName = elementName;
        this.filePath = filePath;
        this.lineNumber = lineNumber;
        this.contextInfo = contextInfo;
        this.isDefinition = isDefinition;
        this.isSeparator = isSeparator;
    }
    
    /**
     * Get the actual navigation element, creating it if necessary.
     * This method is synchronized to ensure thread safety.
     */
    public synchronized HarbourNavigationElement getNavigationElement() {
        if (cachedElement == null) {
            PsiElement target = targetPointer.getElement();
            if (target != null && target.isValid()) {
                cachedElement = new HarbourNavigationElement(
                    target, elementName, filePath, lineNumber, 
                    contextInfo, isDefinition, isSeparator
                );
            }
        }
        return cachedElement;
    }
    
    // Quick accessors that don't require creating the full element
    public boolean isDefinition() {
        return isDefinition;
    }
    
    public String getFilePath() {
        return filePath;
    }
    
    public int getLineNumber() {
        return lineNumber;
    }
    
    public String getElementName() {
        return elementName;
    }
}
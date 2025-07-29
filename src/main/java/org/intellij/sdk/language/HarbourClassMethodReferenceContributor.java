package org.intellij.sdk.language;

import com.intellij.openapi.util.TextRange;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Contributes references for class method calls in Harbour code.
 * Handles patterns like: ClassName():methodName() and User():new(kurzel,counter)
 */
public class HarbourClassMethodReferenceContributor extends PsiReferenceContributor {

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        HarbourLogger.log("ClassMethodReferenceContributor", "Registering class method reference providers");

        // Register for method names after Class():
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(PsiElement.class).withElementType(HarbourTypes.IDENT),
                new PsiReferenceProvider() {
                    @NotNull
                    @Override
                    public PsiReference[] getReferencesByElement(@NotNull PsiElement element,
                                                                 @NotNull ProcessingContext context) {
                        // Only process in Harbour files
                        if (!(element.getContainingFile() instanceof HarbourFile)) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        // Only process identifiers
                        if (!(element instanceof LeafPsiElement) ||
                                ((LeafPsiElement) element).getElementType() != HarbourTypes.IDENT) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        String methodName = element.getText();

                        // Check if this is a method after Class():method
                        if (isClassMethodReference(element)) {
                            HarbourLogger.log("ClassMethodReferenceContributor", "Found class method reference: " + methodName);

                            // Create a method reference
                            TextRange range = new TextRange(0, methodName.length());
                            return new PsiReference[]{new HarbourMethodReference(element, range)};
                        }

                        return PsiReference.EMPTY_ARRAY;
                    }
                });
    }

    /**
     * Check if element is a method reference after a class reference (ClassName():method)
     */
    private boolean isClassMethodReference(PsiElement element) {
        if (element == null) {
            return false;
        }

        String methodName = element.getText();
        HarbourLogger.log("ClassMethodReferenceContributor", "Checking if " + methodName + " is a class method reference");

        // First, check the PSI structure directly
        PsiElement prev = element.getPrevSibling();
        if (prev != null) {
            // Look for colon before this element
            while (prev != null) {
                if (prev.getText().equals(":")) {
                    // Found a colon, now check if there's a class() pattern before it
                    PsiElement classRef = findClassReferenceBeforeColon(prev);
                    if (classRef != null) {
                        HarbourLogger.log("ClassMethodReferenceContributor", "Found class method by PSI structure: class=" + classRef.getText() + ", method=" + methodName);
                        return true;
                    }
                    break;
                }

                // Skip whitespace
                if (prev instanceof PsiWhiteSpace) {
                    prev = prev.getPrevSibling();
                    continue;
                }

                // If we hit a non-whitespace, non-colon element, break
                break;
            }
        }

        // For robustness, also check the line text
        String lineText = getLineText(element.getContainingFile(), element);
        if (lineText == null) {
            return false;
        }

        // Find where our element appears in the line
        int pos = lineText.indexOf(methodName);
        if (pos <= 0) {
            return false;
        }

        // Check for Class():method pattern
        int colonPos = lineText.lastIndexOf(':', pos);
        if (colonPos > 0) {
            // Look for closing parenthesis before colon
            int closingParenPos = lineText.lastIndexOf(')', colonPos);
            if (closingParenPos > 0) {
                // Look for opening parenthesis before closing
                int openingParenPos = lineText.lastIndexOf('(', closingParenPos);
                if (openingParenPos > 0) {
                    // Check if there's an identifier before the opening parenthesis
                    // This would be our class name
                    String beforeParens = lineText.substring(0, openingParenPos).trim();
                    if (!beforeParens.isEmpty() &&
                            Character.isLetterOrDigit(beforeParens.charAt(beforeParens.length() - 1))) {
                        HarbourLogger.log("ClassMethodReferenceContributor", "Found class method by pattern: " + lineText.substring(0, pos + methodName.length()));
                        return true;
                    }
                }
            }
        }

        // Generic check: any method after colon and parentheses pattern
        String beforeMethod = lineText.substring(0, pos).trim();
        if (beforeMethod.endsWith(":") && beforeMethod.contains("(") && beforeMethod.contains(")")) {
            HarbourLogger.log("ClassMethodReferenceContributor", "Found class method pattern for: " + methodName);
            return true;
        }

        return false;
    }

    /**
     * Find class reference before a colon in PSI structure
     */
    private PsiElement findClassReferenceBeforeColon(PsiElement colonElement) {
        if (colonElement == null) {
            return null;
        }

        // Look for closing parenthesis before colon
        PsiElement prev = colonElement.getPrevSibling();
        while (prev != null && (prev instanceof PsiWhiteSpace)) {
            prev = prev.getPrevSibling();
        }

        if (prev == null || !prev.getText().equals(")")) {
            return null;
        }

        // Now look for matching opening parenthesis
        int depth = 1;
        PsiElement current = prev.getPrevSibling();

        while (current != null && depth > 0) {
            String text = current.getText();
            if (text.equals(")")) {
                depth++;
            } else if (text.equals("(")) {
                depth--;
            }

            if (depth == 0) {
                // Found matching opening parenthesis, now look for class name
                PsiElement classRef = current.getPrevSibling();
                while (classRef != null && (classRef instanceof PsiWhiteSpace)) {
                    classRef = classRef.getPrevSibling();
                }

                if (classRef != null && classRef instanceof LeafPsiElement &&
                        ((LeafPsiElement) classRef).getElementType() == HarbourTypes.IDENT) {
                    return classRef;
                }

                return null;
            }

            current = current.getPrevSibling();
        }

        return null;
    }

    /**
     * Get the text of the line containing the element
     */
    private String getLineText(PsiFile file, PsiElement element) {
        if (file == null || element == null) {
            return null;
        }

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
}
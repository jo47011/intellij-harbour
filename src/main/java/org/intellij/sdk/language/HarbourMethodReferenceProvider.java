package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;

/**
 * Provider for Harbour method references
 */
public class HarbourMethodReferenceProvider extends PsiReferenceProvider {
    private static final Logger LOG = Logger.getInstance(HarbourMethodReferenceProvider.class);
    private static final String COMPONENT = "MethodRefProvider";

    @Override
    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element, @NotNull ProcessingContext context) {
        HarbourLogger.log(COMPONENT, "Getting references for: " + element.getText() + ", class: " + element.getClass().getName());

        // Handle different types of elements
        if (element instanceof FunctionCallImpl) {
            FunctionCallImpl functionCall = (FunctionCallImpl) element;
            String text = functionCall.getText();
            int parenIndex = text.indexOf('(');

            if (parenIndex > 0) {
                String methodName = text.substring(0, parenIndex);
                HarbourLogger.log(COMPONENT, "Found function call: " + methodName);

                return new PsiReference[]{
                        new HarbourMethodReference(element, new TextRange(0, parenIndex))
                };
            }
        } else if (element instanceof LeafPsiElement) {
            LeafPsiElement leafElement = (LeafPsiElement) element;
            String elementType = leafElement.getElementType().toString();

            if (elementType.contains("IDENT")) {
                // Only create method references for actual method calls, not variables
                if (isActualMethodCall(leafElement)) {
                    System.err.println("*** DEBUG: CREATING method reference for: " + element.getText() + " (method call detected)");
                    HarbourLogger.log(COMPONENT, "Found method call identifier: " + element.getText());
                    return new PsiReference[]{
                            new HarbourMethodReference(element, new TextRange(0, element.getTextLength()))
                    };
                } else {
                    // Add debug output to understand what's happening
                    System.err.println("*** DEBUG: SKIPPING variable identifier: " + element.getText() + " (not creating PsiReference)");
                    HarbourLogger.log(COMPONENT, "Skipping variable identifier: " + element.getText());
                }
            }
        }

        return PsiReference.EMPTY_ARRAY;
    }

    /**
     * Check if an identifier is actually a method call rather than a variable
     */
    private boolean isActualMethodCall(LeafPsiElement element) {
        String text = element.getText();
        if (text == null || text.isEmpty()) {
            return false;
        }

        // Get the containing line to check context
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return false;
        }

        String fileText = file.getText();
        if (fileText == null) {
            return false;
        }

        int offset = element.getTextOffset();
        int lineStart = offset;
        int lineEnd = offset;

        // Find start of line
        while (lineStart > 0 && fileText.charAt(lineStart - 1) != '\n') {
            lineStart--;
        }

        // Find end of line
        while (lineEnd < fileText.length() && fileText.charAt(lineEnd) != '\n') {
            lineEnd++;
        }

        String lineText = fileText.substring(lineStart, lineEnd);
        int identifierPos = offset - lineStart;

        // Check if followed by parentheses (function call)
        int afterIdentifier = identifierPos + text.length();
        if (afterIdentifier < lineText.length()) {
            // Skip whitespace after identifier
            int pos = afterIdentifier;
            while (pos < lineText.length() && Character.isWhitespace(lineText.charAt(pos))) {
                pos++;
            }
            // If followed by opening parenthesis, it's a function call
            if (pos < lineText.length() && lineText.charAt(pos) == '(') {
                return true;
            }
        }

        // Check if preceded by colon or dot (method call: obj:method or obj.method)
        if (identifierPos > 0) {
            // Skip whitespace before identifier
            int pos = identifierPos - 1;
            while (pos >= 0 && Character.isWhitespace(lineText.charAt(pos))) {
                pos--;
            }
            // If preceded by colon or dot, it's a method call
            if (pos >= 0 && (lineText.charAt(pos) == ':' || lineText.charAt(pos) == '.')) {
                return true;
            }
        }

        // Check for double colon :: (scope resolution/field assignment) which should not be confused with method reference
        if (lineText.contains("::")) {
            int doubleColonPos = lineText.indexOf("::");
            // If our element appears after ::, it's likely a field assignment, not a method reference
            if (doubleColonPos >= 0 && identifierPos > doubleColonPos) {
                System.err.println("*** DEBUG: Found :: scope resolution, not a method reference: " + text);
                HarbourLogger.log(COMPONENT, "Found :: scope resolution, not a method reference: " + text);
                return false;
            }
        }

        // Check if it's inside parentheses after a colon (class method: ClassName():method())
        // Look for pattern like "ClassName():identifierName"
        if (identifierPos > 2) {
            int colonPos = lineText.lastIndexOf(':', identifierPos);
            if (colonPos >= 0) {
                // Check if there's a closing parenthesis between colon and identifier
                String between = lineText.substring(colonPos + 1, identifierPos).trim();
                if (between.isEmpty()) {
                    return true; // Direct after colon: ClassName():method
                }
            }
        }

        // If none of the method call patterns match, it's likely a variable
        return false;
    }
}
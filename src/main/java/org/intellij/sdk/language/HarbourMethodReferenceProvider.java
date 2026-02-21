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
        HarbourLogger.trace(COMPONENT, "Getting references for: " + element.getText() + ", class: " + element.getClass().getName());

        // CRITICAL FIX: Skip comment elements completely
        if (element instanceof PsiComment || element.getClass().getName().contains("Comment")) {
            return PsiReference.EMPTY_ARRAY;
        }

        // Handle different types of elements
        if (element instanceof FunctionCallImpl) {
            FunctionCallImpl functionCall = (FunctionCallImpl) element;
            String text = functionCall.getText();
            int parenIndex = text.indexOf('(');

            if (parenIndex > 0) {
                String methodName = text.substring(0, parenIndex);
                HarbourLogger.trace(COMPONENT, "Found function call: " + methodName);

                return new PsiReference[]{
                        new HarbourMethodReference(element, new TextRange(0, parenIndex))
                };
            }
        } else if (element instanceof LeafPsiElement) {
            LeafPsiElement leafElement = (LeafPsiElement) element;
            String elementType = leafElement.getElementType().toString();

            if (elementType.contains("IDENT")) {
                String text = element.getText();
                
                // Skip keywords - they should never have references
                if (isKeyword(text)) {
                    return PsiReference.EMPTY_ARRAY;
                }

                // Only create method references for actual method calls, not variables
                if (isActualMethodCall(leafElement)) {
                    HarbourLogger.trace(COMPONENT, "Found method call identifier: " + element.getText());
                    return new PsiReference[]{
                            new HarbourMethodReference(element, new TextRange(0, element.getTextLength()))
                    };
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
                HarbourLogger.trace(COMPONENT, "Found :: scope resolution, not a method reference: " + text);
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
    
    /**
     * Checks if the text is a Harbour keyword that should not have references.
     */
    private boolean isKeyword(String text) {
        if (text == null || text.isEmpty()) {
            return false;
        }

        String upperText = text.toUpperCase();
        
        // Language structure keywords
        if (upperText.equals("IF") || upperText.equals("ELSE") || upperText.equals("ELSEIF") || 
            upperText.equals("ENDIF") || upperText.equals("DO") || upperText.equals("WHILE") || 
            upperText.equals("ENDDO") || upperText.equals("FOR") || upperText.equals("NEXT") || 
            upperText.equals("CASE") || upperText.equals("OTHERWISE") || upperText.equals("SWITCH") || 
            upperText.equals("ENDSWITCH") || upperText.equals("BEGIN") || upperText.equals("SEQUENCE") ||
            upperText.equals("RECOVER") || upperText.equals("USING") || upperText.equals("END")) {
            return true;
        }
        
        // Commands and declarations
        if (upperText.equals("SET") || upperText.equals("RETURN") || upperText.equals("EXIT") || 
            upperText.equals("LOOP") || upperText.equals("LOCAL") || upperText.equals("STATIC") || 
            upperText.equals("PRIVATE") || upperText.equals("PUBLIC") || upperText.equals("FIELD") ||
            upperText.equals("MEMVAR") || upperText.equals("PARAMETER") || upperText.equals("PARAMETERS")) {
            return true;
        }
        
        // Class-related keywords
        if (upperText.equals("CLASS") || upperText.equals("ENDCLASS") || upperText.equals("METHOD") || 
            upperText.equals("ENDMETHOD") || upperText.equals("DATA") || upperText.equals("CLASSDATA") ||
            upperText.equals("EXPORTED") || upperText.equals("PROTECTED") || upperText.equals("HIDDEN")) {
            return true;
        }
        
        // Function/Procedure keywords
        if (upperText.equals("FUNCTION") || upperText.equals("PROCEDURE") || upperText.equals("ENDFUNCTION") ||
            upperText.equals("ENDPROC") || upperText.equals("ENDFUNC")) {
            return true;
        }
        
        // Operators
        if (upperText.equals("AND") || upperText.equals("OR") || upperText.equals("NOT") || 
            upperText.equals(".AND.") || upperText.equals(".OR.") || upperText.equals(".NOT.")) {
            return true;
        }
        
        // Other keywords
        if (upperText.equals("TO") || upperText.equals("STEP") || upperText.equals("ADDITIVE") ||
            upperText.equals("NIL") || upperText.equals("TRUE") || upperText.equals("FALSE") ||
            upperText.equals("IN") || upperText.equals("WITH") || upperText.equals("REPLACE") ||
            upperText.equals("ALL") || upperText.equals("REST") || upperText.equals("FROM") ||
            upperText.equals("SEEK") || upperText.equals("SKIP") || upperText.equals("USE") ||
            upperText.equals("INDEX") || upperText.equals("ALIAS") || upperText.equals("EXCLUSIVE") ||
            upperText.equals("SHARED") || upperText.equals("NEW") || upperText.equals("READONLY")) {
            return true;
        }
        
        return false;
    }
}
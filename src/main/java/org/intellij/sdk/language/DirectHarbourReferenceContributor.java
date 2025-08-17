package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.tree.IElementType;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.intellij.sdk.language.reference.HarbourFunctionReference;
import org.jetbrains.annotations.NotNull;

/**
 * Contributes function and method references to the Harbour language.
 * This is for direct navigation to the function declaration or method declaration.
 */
public class DirectHarbourReferenceContributor extends PsiReferenceContributor {
    private static final Logger LOG = Logger.getInstance(DirectHarbourReferenceContributor.class);
    private static final String COMPONENT = "DirectRef";

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        HarbourLogger.log(COMPONENT, "DirectHarbourReferenceContributor registering providers");

        // Register provider for IDENT tokens only - not all elements
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(LeafPsiElement.class)
                        .withElementType(HarbourTypes.IDENT),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element,
                                                                           @NotNull ProcessingContext context) {
                        // Element is guaranteed to be IDENT token due to pattern matching
                        String text = element.getText();
                        
                        // Check if element is in a comment
                        if (isInComment(element)) {
                            return PsiReference.EMPTY_ARRAY;
                        }
                        
                        // Skip keywords - they should not have references
                        if (isKeyword(text)) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        // Check if this is a method call (after a colon or dot)
                        if (isMethodCall(element)) {
                            String methodName = element.getText();
                            HarbourLogger.log(COMPONENT, "Method call: " + methodName);
                            return new PsiReference[] { new HarbourMethodReference(element, methodName) };
                        }

                        // Check if this is a function call (followed by parenthesis)
                        if (isFollowedByParenthesis(element)) {
                            String functionName = element.getText();
                            HarbourLogger.log(COMPONENT, "Function call: " + functionName);
                            return new PsiReference[] { new HarbourFunctionReference(element, functionName) };
                        }
                        
                        // Also check if this is part of a function call PSI element
                        PsiElement parent = element.getParent();
                        if (parent instanceof FunctionCallImpl) {
                            String functionName = element.getText();
                            if (functionName != null && !functionName.isEmpty()) {
                                HarbourLogger.log(COMPONENT, "Function call via parent: " + functionName);
                                return new PsiReference[] { new HarbourFunctionReference(element, functionName) };
                            }
                        }
                        
                        // Not a function or method call
                        return PsiReference.EMPTY_ARRAY;
                    }
                });
    }

    /**
     * Check if an element is inside a comment
     */
    private boolean isInComment(PsiElement element) {
        // Check if the element itself is a comment
        if (element instanceof PsiComment) {
            return true;
        }
        
        // Check if any parent is a comment
        PsiElement parent = element.getParent();
        while (parent != null) {
            if (parent instanceof PsiComment) {
                return true;
            }
            parent = parent.getParent();
        }
        
        return false;
    }

    /**
     * Check if the given text is a Harbour keyword
     */
    private boolean isKeyword(String text) {
        if (text == null || text.isEmpty()) {
            return false;
        }
        
        String upperText = text.toUpperCase();
        
        // Control flow keywords
        if (upperText.equals("IF") || upperText.equals("ELSEIF") || upperText.equals("ELSE") || 
            upperText.equals("ENDIF") || upperText.equals("DO") || upperText.equals("WHILE") || 
            upperText.equals("ENDDO") || upperText.equals("FOR") || upperText.equals("NEXT") || 
            upperText.equals("FOREACH") || upperText.equals("CASE") || upperText.equals("SWITCH") || 
            upperText.equals("OTHERWISE") || upperText.equals("ENDCASE") || upperText.equals("BEGIN") || 
            upperText.equals("SEQUENCE") || upperText.equals("TRY") || upperText.equals("CATCH") || 
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

    /**
     * Check if an element is a method call (after a colon or dot)
     */
    private boolean isMethodCall(PsiElement element) {
        // Get the line text for context
        PsiFile file = element.getContainingFile();
        if (file == null) return false;

        String fileText = file.getText();
        if (fileText == null || fileText.isEmpty()) return false;

        int elementOffset = element.getTextOffset();
        if (elementOffset < 1) return false;

        // Look back for a colon or dot
        int checkPos = elementOffset - 1;
        while (checkPos >= 0 && Character.isWhitespace(fileText.charAt(checkPos))) {
            checkPos--;
        }

        if (checkPos >= 0) {
            char prevChar = fileText.charAt(checkPos);
            if (prevChar == ':' || prevChar == '.') {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if an element is followed by a parenthesis (indicating a function call)
     */
    private boolean isFollowedByParenthesis(PsiElement element) {
        PsiElement next = element.getNextSibling();
        while (next != null) {
            String text = next.getText();
            if (text == null || text.isEmpty()) {
                next = next.getNextSibling();
                continue;
            }
            
            // Skip whitespace
            if (text.trim().isEmpty()) {
                next = next.getNextSibling();
                continue;
            }
            
            // Check if it starts with parenthesis
            if (text.startsWith("(")) {
                return true;
            }
            
            // If we hit something else, stop looking
            break;
        }
        
        return false;
    }
}
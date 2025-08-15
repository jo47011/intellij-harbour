package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.PsiComment;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiReference;
import com.intellij.psi.PsiReferenceBase;
import com.intellij.psi.PsiReferenceContributor;
import com.intellij.psi.PsiReferenceProvider;
import com.intellij.psi.PsiReferenceRegistrar;
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

        // Register provider for function calls
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(PsiElement.class),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element,
                                                                           @NotNull ProcessingContext context) {
                        // COMPREHENSIVE DEBUG: Log every element we process
                        String elementText = element.getText();
                        String elementClass = element.getClass().getSimpleName();
                        String elementType = "unknown";
                        
                        if (element instanceof LeafPsiElement) {
                            LeafPsiElement leaf = (LeafPsiElement) element;
                            IElementType type = leaf.getElementType();
                            elementType = type != null ? type.toString() : "null";
                        }
                        
                        HarbourLogger.log(COMPONENT, "=== PROCESSING ELEMENT ===");
                        HarbourLogger.log(COMPONENT, "Text: '" + elementText + "'");
                        HarbourLogger.log(COMPONENT, "Class: " + elementClass);
                        HarbourLogger.log(COMPONENT, "Type: " + elementType);
                        
                        // Check if element is in a comment
                        if (isInComment(element)) {
                            HarbourLogger.log(COMPONENT, "Element is in comment - SKIPPING");
                            return PsiReference.EMPTY_ARRAY;
                        }
                        
                        // Only process LeafPsiElements which are IDENT
                        if (!(element instanceof LeafPsiElement)) {
                            HarbourLogger.log(COMPONENT, "Not a LeafPsiElement - SKIPPING");
                            return PsiReference.EMPTY_ARRAY;
                        }

                        LeafPsiElement leafElement = (LeafPsiElement) element;
                        if (leafElement.getElementType() != HarbourTypes.IDENT) {
                            HarbourLogger.log(COMPONENT, "Not an IDENT token - SKIPPING");
                            return PsiReference.EMPTY_ARRAY;
                        }
                        
                        // BREAKPOINT LOCATION: Set breakpoint here for FEEDBACK.txt line 18-19
                        // This is where we determine if an element should get a reference (and thus underline)
                        String text = element.getText();
                        HarbourLogger.log(COMPONENT, "Checking if '" + text + "' is a keyword...");
                        
                        if (isKeyword(text)) {
                            // Keywords should NOT get references (no underline on ctrl-hover)
                            HarbourLogger.log(COMPONENT, "KEYWORD DETECTED - SKIPPING: " + text);
                            return PsiReference.EMPTY_ARRAY;
                        }
                        HarbourLogger.log(COMPONENT, "Not a keyword, continuing with: " + text);

                        // Check if this is a method call (after a colon or dot)
                        HarbourLogger.log(COMPONENT, "Checking if '" + text + "' is a method call...");
                        if (isMethodCall(element)) {
                            String methodName = element.getText();
                            HarbourLogger.log(COMPONENT, "METHOD CALL DETECTED - Creating reference for: " + methodName);
                            return new PsiReference[] { new HarbourMethodReference(element, methodName) };
                        }

                        // Check if this is a function call (followed by parenthesis)
                        HarbourLogger.log(COMPONENT, "Checking if '" + text + "' is followed by parenthesis...");
                        if (isFollowedByParenthesis(element)) {
                            String functionName = element.getText();
                            HarbourLogger.log(COMPONENT, "FUNCTION CALL DETECTED - Creating reference for: " + functionName);
                            return new PsiReference[] { new HarbourFunctionReference(element, functionName) };
                        }
                        
                        // Also check if this is part of a function call PSI element
                        HarbourLogger.log(COMPONENT, "Checking parent element type for '" + text + "'...");
                        PsiElement parent = element.getParent();
                        if (parent instanceof FunctionCallImpl) {
                            String functionName = element.getText();
                            if (functionName != null && !functionName.isEmpty()) {
                                HarbourLogger.log(COMPONENT, "FUNCTION CALL VIA PARENT DETECTED - Creating reference for: " + functionName);
                                return new PsiReference[] { new HarbourFunctionReference(element, functionName) };
                            }
                        }
                        
                        // For all other identifiers (could be variables or functions without parentheses)
                        // Create a generic reference that will be resolved by the reference service
                        String identifierName = element.getText();
                        if (identifierName != null && !identifierName.isEmpty()) {
                            HarbourLogger.log(COMPONENT, "GENERIC IDENTIFIER DETECTED - Creating reference for: " + identifierName);
                            return new PsiReference[] { new HarbourFunctionReference(element, identifierName) };
                        }

                        HarbourLogger.log(COMPONENT, "NO REFERENCE CREATED for: " + text);
                        return PsiReference.EMPTY_ARRAY;
                    }
                }
        );

        HarbourLogger.log(COMPONENT, "DirectHarbourReferenceContributor registration complete");
    }
    
    /**
     * Checks if the text is a Harbour keyword that should not be underlined.
     * BREAKPOINT LOCATION: This is the case consideration for keywords vs functions/variables
     */
    private static boolean isKeyword(String text) {
        if (text == null || text.isEmpty()) {
            HarbourLogger.log(COMPONENT, "isKeyword: null/empty text - returning false");
            return false;
        }
        
        String upperText = text.toUpperCase();
        HarbourLogger.log(COMPONENT, "isKeyword: checking '" + text + "' (uppercase: '" + upperText + "')");
        
        // Language structure keywords
        if (upperText.equals("IF") || upperText.equals("ELSE") || upperText.equals("ELSEIF") || 
            upperText.equals("ENDIF") || upperText.equals("DO") || upperText.equals("WHILE") || 
            upperText.equals("ENDDO") || upperText.equals("FOR") || upperText.equals("NEXT") || 
            upperText.equals("CASE") || upperText.equals("OTHERWISE") || upperText.equals("SWITCH") || 
            upperText.equals("ENDSWITCH") || upperText.equals("BEGIN") || upperText.equals("SEQUENCE") ||
            upperText.equals("RECOVER") || upperText.equals("USING") || upperText.equals("END")) {
            HarbourLogger.log(COMPONENT, "isKeyword: LANGUAGE STRUCTURE keyword detected: " + upperText);
            return true;
        }
        
        // Commands and declarations
        if (upperText.equals("SET") || upperText.equals("RETURN") || upperText.equals("EXIT") || 
            upperText.equals("LOOP") || upperText.equals("LOCAL") || upperText.equals("STATIC") || 
            upperText.equals("PRIVATE") || upperText.equals("PUBLIC") || upperText.equals("FIELD") ||
            upperText.equals("MEMVAR") || upperText.equals("PARAMETER") || upperText.equals("PARAMETERS")) {
            HarbourLogger.log(COMPONENT, "isKeyword: COMMAND/DECLARATION keyword detected: " + upperText);
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
            HarbourLogger.log(COMPONENT, "isKeyword: OTHER keyword detected: " + upperText);
            return true;
        }
        
        HarbourLogger.log(COMPONENT, "isKeyword: NOT A KEYWORD - returning false for: " + upperText);
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

        int offset = element.getTextOffset();
        int startOffset = offset;

        // Find the start of the line
        while (startOffset > 0 && fileText.charAt(startOffset - 1) != '\n') {
            startOffset--;
        }

        // Get the part of the line before our element
        String linePrefix = fileText.substring(startOffset, offset);

        // Check if there's a colon or dot before our element
        if (linePrefix.contains(":") || linePrefix.contains(".")) {
            HarbourLogger.log(COMPONENT, "Found method call pattern for: " + element.getText());
            return true;
        }

        return false;
    }
    
    /**
     * Check if an element is followed by parenthesis, indicating a function call.
     */
    private static boolean isFollowedByParenthesis(PsiElement element) {
        PsiElement next = element.getNextSibling();
        int maxDistance = 5;
        int distance = 0;

        while (next != null && distance < maxDistance) {
            if (next instanceof LeafPsiElement) {
                LeafPsiElement leaf = (LeafPsiElement) next;
                IElementType type = leaf.getElementType();

                if (type == HarbourTypes.LPAREN) {
                    return true;
                } else if (type != com.intellij.psi.TokenType.WHITE_SPACE) {
                    break;
                }
            }
            next = next.getNextSibling();
            distance++;
        }
        return false;
    }
    
    /**
     * Check if an element is inside a comment.
     * This should prevent comments from getting references and underlines.
     */
    private static boolean isInComment(PsiElement element) {
        // Direct check: is the element itself a comment?
        if (element instanceof PsiComment) {
            HarbourLogger.log(COMPONENT, "Element is a PsiComment");
            return true;
        }
        
        // Check if the element class name contains "Comment" 
        if (element.getClass().getName().contains("Comment")) {
            HarbourLogger.log(COMPONENT, "Element class is a comment type: " + element.getClass().getName());
            return true;
        }
        
        // For LeafPsiElement, check if it has a comment token type
        if (element instanceof LeafPsiElement) {
            LeafPsiElement leaf = (LeafPsiElement) element;
            IElementType type = leaf.getElementType();
            if (type != null) {
                String typeName = type.toString();
                if (typeName.contains("COMMENT") || typeName.contains("comment")) {
                    HarbourLogger.log(COMPONENT, "Element has comment token type: " + typeName);
                    return true;
                }
            }
        }
        
        return false;
    }

    /**
     * Custom reference for Harbour methods that resolves to the method declaration.
     */
    private static class HarbourMethodReference extends PsiReferenceBase<PsiElement> {
        private final String methodName;
        private static final String COMPONENT = "MethodRef";

        public HarbourMethodReference(@NotNull PsiElement element, String methodName) {
            super(element);
            this.methodName = methodName;
            HarbourLogger.log(COMPONENT, "Created reference for: " + methodName);
        }

        @Override
        public TextRange getRangeInElement() {
            return new TextRange(0, getElement().getTextLength());
        }

        @Override
        public PsiElement resolve() {
            try {
                HarbourLogger.log(COMPONENT, "Resolving method: " + methodName);

                // Extract the class name from the line context
                String className = extractClassFromContext(getElement());
                HarbourLogger.log(COMPONENT, "Found potential class: " +
                        (className != null ? className : "unknown"));

                // Get the reference service
                HarbourReferenceService service =
                        HarbourReferenceService.getInstance(getElement().getProject());

                // If we found a class name, try to find the method in that class
                java.util.List<PsiElement> methodDeclarations;
                if (className != null) {
                    HarbourLogger.log(COMPONENT, "Searching for method " + methodName +
                            " in class " + className);
                    methodDeclarations = service.findClassMethods(className, methodName);
                } else {
                    // Fall back to general method/function search
                    HarbourLogger.log(COMPONENT, "Searching for general method: " + methodName);
                    methodDeclarations = service.findFunctions(methodName);
                }

                // Check if we found any declarations
                if (methodDeclarations.isEmpty()) {
                    HarbourLogger.log(COMPONENT, "No method declarations found for: " + methodName);
                    return null;
                }

                HarbourLogger.log(COMPONENT, "Found " + methodDeclarations.size() +
                        " potential method declarations");

                // Return the first declaration
                PsiElement resolvedElement = methodDeclarations.get(0);

                // Create a navigation element
                PsiFile file = resolvedElement.getContainingFile();
                if (file != null && file.getVirtualFile() != null) {
                    String filePath = file.getVirtualFile().getPath();
                    int lineNumber = HarbourLogger.calculateLineNumber(resolvedElement);

                    HarbourLogger.log(COMPONENT, "Creating navigation element for: " +
                            methodName + " at " + filePath + ":" + lineNumber);

                    return new HarbourNavigationElement(
                            resolvedElement,
                            methodName,
                            filePath,
                            lineNumber,
                            "Method declaration",
                            true,
                            false
                    );
                }

                return resolvedElement;
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error resolving method reference: " + e.getMessage());
                return null;
            }
        }

        /**
         * Extract the class name from the context of a method reference
         */
        private String extractClassFromContext(PsiElement methodElement) {
            // Get the line text
            PsiFile file = methodElement.getContainingFile();
            if (file == null) return null;

            String fileText = file.getText();
            if (fileText == null || fileText.isEmpty()) return null;

            int offset = methodElement.getTextOffset();
            int startOffset = offset;

            // Find the start of the line
            while (startOffset > 0 && fileText.charAt(startOffset - 1) != '\n') {
                startOffset--;
            }

            // Get the line text
            int endOffset = offset;
            while (endOffset < fileText.length() && fileText.charAt(endOffset) != '\n') {
                endOffset++;
            }

            String lineText = fileText.substring(startOffset, endOffset);

            // Find method position in the line
            String methodName = methodElement.getText();
            int methodPos = lineText.indexOf(methodName);

            if (methodPos <= 0) {
                return null;
            }

            // Find colon or dot before the method
            int colonPos = lineText.lastIndexOf(':', methodPos);
            int dotPos = lineText.lastIndexOf('.', methodPos);
            int separatorPos = Math.max(colonPos, dotPos);

            if (separatorPos <= 0) {
                return null;
            }

            // Look for patterns like "ClassName()" before the separator
            String beforeSeparator = lineText.substring(0, separatorPos);

            // Pattern for class instantiation
            java.util.regex.Pattern classPattern =
                    java.util.regex.Pattern.compile("(\\w+)\\s*\\(\\s*\\)");
            java.util.regex.Matcher matcher = classPattern.matcher(beforeSeparator);

            if (matcher.find()) {
                // Found a class instantiation pattern
                String className = matcher.group(1);
                HarbourLogger.log(COMPONENT, "Found class name from instantiation: " + className);
                return className;
            }

            // Otherwise try to find nearest identifier before separator
            // (this would be an object variable name)
            int objNameEnd = separatorPos;
            int objNameStart = objNameEnd - 1;

            // Find start of the identifier
            while (objNameStart >= 0 &&
                    (Character.isLetterOrDigit(lineText.charAt(objNameStart)) ||
                            lineText.charAt(objNameStart) == '_')) {
                objNameStart--;
            }
            objNameStart++; // Adjust after loop

            if (objNameStart < objNameEnd) {
                String objName = lineText.substring(objNameStart, objNameEnd);
                HarbourLogger.log(COMPONENT, "Found object variable name: " + objName);
                return objName;
            }

            return null;
        }

        @Override
        public Object @NotNull [] getVariants() {
            return EMPTY_ARRAY;
        }
    }
}
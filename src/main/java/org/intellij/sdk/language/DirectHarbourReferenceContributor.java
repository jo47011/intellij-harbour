package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
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
                        // Only process LeafPsiElements which are IDENT
                        if (!(element instanceof LeafPsiElement)) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        LeafPsiElement leafElement = (LeafPsiElement) element;
                        if (leafElement.getElementType() != HarbourTypes.IDENT) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        // Check if this is a method call (after a colon or dot)
                        if (isMethodCall(element)) {
                            String methodName = element.getText();
                            HarbourLogger.log(COMPONENT, "Creating method reference for: " + methodName);
                            return new PsiReference[] { new HarbourMethodReference(element, methodName) };
                        }

                        // Check if this is part of a function call
                        PsiElement parent = element.getParent();
                        if (parent instanceof FunctionCallImpl) {
                            String functionName = element.getText();
                            if (functionName != null && !functionName.isEmpty()) {
                                // Create a function reference
                                return new PsiReference[] { new HarbourFunctionReference(element, functionName) };
                            }
                        }

                        return PsiReference.EMPTY_ARRAY;
                    }
                }
        );

        HarbourLogger.log(COMPONENT, "DirectHarbourReferenceContributor registration complete");
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
     * Custom reference for Harbour functions that resolves to the function declaration.
     */
    private static class HarbourFunctionReference extends PsiReferenceBase<PsiElement> {
        private final String functionName;
        private static final String COMPONENT = "FunctionRef";

        public HarbourFunctionReference(@NotNull PsiElement element, String functionName) {
            super(element);
            this.functionName = functionName;
        }

        @Override
        public TextRange getRangeInElement() {
            return new TextRange(0, getElement().getTextLength());
        }

        @Override
        public PsiElement resolve() {
            try {
                // Get the service and look for declarations
                HarbourReferenceService service =
                        HarbourReferenceService.getInstance(getElement().getProject());

                // Find all declarations of this function
                java.util.List<PsiElement> declarations = service.findFunctions(functionName);

                // Check if we found any
                if (declarations.isEmpty()) {
                    return null;
                }

                // Try to find a function declaration
                for (PsiElement decl : declarations) {
                    if (decl instanceof HarbourFunctionDeclaration) {
                        return decl;
                    }
                }

                // If no function declaration was found, return the first element
                PsiElement resolvedElement = declarations.get(0);

                // Get the file and line number for this element
                PsiFile file = resolvedElement.getContainingFile();
                if (file != null && file.getVirtualFile() != null) {
                    String filePath = file.getVirtualFile().getPath();
                    int lineNumber = HarbourLogger.calculateLineNumber(resolvedElement);

                    // Create and return a navigation element
                    return new HarbourNavigationElement(
                            resolvedElement,
                            functionName,
                            filePath,
                            lineNumber,
                            "Function declaration"
                    );
                }

                return resolvedElement;
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error resolving function reference: " + e.getMessage());
                return null;
            }
        }

        @Override
        public Object @NotNull [] getVariants() {
            return EMPTY_ARRAY;
        }
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
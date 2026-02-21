package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.util.IncorrectOperationException;
import org.intellij.sdk.language.psi.HarbourElementFactory;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class HarbourMethodReference extends PsiReferenceBase<PsiElement> implements PsiPolyVariantReference {
    private static final Logger LOG = Logger.getInstance(HarbourMethodReference.class);
    private static final String COMPONENT = "MethodReference";
    private String methodName;

    // Original constructor
    public HarbourMethodReference(@NotNull PsiElement element) {
        super(element);
        this.methodName = element.getText();
        LOG.info("HarbourMethodReference created for element: " + element.getText());
        HarbourLogger.log(COMPONENT, "Created method reference for: " + element.getText());
    }

    // Original constructor with specific method name
    public HarbourMethodReference(@NotNull PsiElement element, String methodName) {
        super(element);
        this.methodName = methodName;
        LOG.info("HarbourMethodReference created for method: " + methodName);
        HarbourLogger.log(COMPONENT, "Created method reference for specific method: " + methodName);
    }

    // New constructor with text range for rename support
    public HarbourMethodReference(@NotNull PsiElement element, TextRange rangeInElement) {
        super(element, rangeInElement);
        methodName = element.getText().substring(rangeInElement.getStartOffset(), rangeInElement.getEndOffset());
        HarbourLogger.log(COMPONENT, "Created reference for: " + methodName + " with range: " + rangeInElement);
    }

    // Handle rename operations
    @Override
    public PsiElement handleElementRename(@NotNull String newElementName) throws IncorrectOperationException {
        HarbourLogger.log(COMPONENT, "Handling rename from " + methodName + " to " + newElementName);

        try {
            // For function calls, we need to preserve the parameters
            if (myElement instanceof FunctionCallImpl) {
                FunctionCallImpl functionCall = (FunctionCallImpl) myElement;
                String oldText = functionCall.getText();
                int parenIndex = oldText.indexOf('(');

                if (parenIndex > 0) {
                    String params = oldText.substring(parenIndex);
                    String newText = newElementName + params;

                    HarbourLogger.log(COMPONENT, "Renaming function call from " + oldText + " to " + newText);

                    PsiElement newElement = HarbourElementFactory.createFile(myElement.getProject(), newText).getFirstChild();
                    return myElement.replace(newElement);
                }
            } else if (myElement instanceof LeafPsiElement) {
                // For leaf elements like identifiers
                LeafPsiElement leafElement = (LeafPsiElement) myElement;
                String elementType = leafElement.getElementType().toString();

                if (elementType.contains("IDENT")) {
                    HarbourLogger.log(COMPONENT, "Renaming identifier from " + methodName + " to " + newElementName);
                    PsiElement newElement = HarbourElementFactory.createIdentifier(myElement.getProject(), newElementName);
                    return myElement.replace(newElement);
                }
            }

            // For other elements, try standard approach
            String oldText = myElement.getText();
            String newText = oldText.replace(methodName, newElementName);

            HarbourLogger.log(COMPONENT, "Renaming element from " + oldText + " to " + newText);

            PsiElement newElement = HarbourElementFactory.createIdentifier(myElement.getProject(), newText);
            return myElement.replace(newElement);
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Exception during rename: " + e.getMessage());
            LOG.error("Error handling method rename", e);
            throw new IncorrectOperationException("Failed to rename method reference", e);
        }
    }

    @Override
    public @Nullable PsiElement resolve() {
        LOG.info("Attempting to resolve reference for element: " + myElement.getText());
        HarbourLogger.log(COMPONENT, "Resolving reference for: " + methodName);

        // Resolve the method/function definition
        PsiElement parent = myElement.getParent();
        if (parent instanceof HarbourFunctionDeclaration) {
            LOG.info("Resolved reference to function declaration: " + parent.getText());
            HarbourLogger.log(COMPONENT, "Resolved to function declaration: " + parent.getText());
            return parent; // Return the function declaration as the target
        }

        // Try to find method by direct pattern search
        PsiElement methodElement = findMethodByPattern(myElement.getProject(), methodName);
        if (methodElement != null) {
            LOG.info("Resolved reference to method by pattern: " + methodElement.getText());
            HarbourLogger.log(COMPONENT, "Resolved to method by pattern");
            return methodElement;
        }

        LOG.warn("Failed to resolve reference for element: " + myElement.getText());
        HarbourLogger.log(COMPONENT, "Failed to resolve reference for: " + methodName);
        return null;
    }

    @NotNull
    @Override
    public ResolveResult[] multiResolve(boolean incompleteCode) {
        HarbourLogger.log(COMPONENT, "multiResolve called for: " + methodName);
        
        // Check if we're in hover context - prevent multiple implementations popup on hover
        boolean isClick = HarbourExternalDocumentationHandler.isClickMode();
        HarbourLogger.log(COMPONENT, "Click mode detected: " + isClick);
        
        PsiElement resolved = resolve();
        if (resolved != null) {
            HarbourLogger.log(COMPONENT, "Resolved to: " + resolved.getText() + " in " + resolved.getContainingFile().getName());
            
            // During hover (non-click), always return single result to prevent "Multiple implementations" popup
            if (!isClick) {
                HarbourLogger.log(COMPONENT, "HOVER MODE - returning single result to prevent popup");
                return new ResolveResult[]{new PsiElementResolveResult(resolved)};
            }
            
            // During click, we can return multiple results if we find them
            HarbourLogger.log(COMPONENT, "CLICK MODE - allowing multiple results for navigation popup");
            
            // For now, still return single result but logged differently
            // TODO: In future, could search for multiple implementations here
            return new ResolveResult[]{new PsiElementResolveResult(resolved)};
        }
        
        HarbourLogger.log(COMPONENT, "No resolution found for: " + methodName);
        return ResolveResult.EMPTY_ARRAY;
    }

    @NotNull
    @Override
    public Object[] getVariants() {
        return EMPTY_ARRAY;
    }

    /**
     * Find a method declaration by pattern matching in all project files
     */
    private PsiElement findMethodByPattern(Project project, String methodName) {
        if (methodName == null || methodName.isEmpty()) {
            return null;
        }

        try {
            java.util.Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.allScope(project));

            // Create pattern for METHOD declarations
            Pattern methodPattern = Pattern.compile(
                    "\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\s*(?:\\(|$)",
                    Pattern.CASE_INSENSITIVE);

            // Also look for FUNCTION declarations
            Pattern functionPattern = Pattern.compile(
                    "\\bFUNCTION\\s+" + Pattern.quote(methodName) + "\\s*(?:\\(|$)",
                    Pattern.CASE_INSENSITIVE);

            for (VirtualFile virtualFile : virtualFiles) {
                if (HarbourFileUtils.isFileExcluded(project, virtualFile)) {
                    continue;
                }
                try {
                    PsiFile psiFile = PsiManager.getInstance(project).findFile(virtualFile);
                    if (psiFile == null) continue;

                    String fileText = psiFile.getText();
                    Matcher methodMatcher = methodPattern.matcher(fileText);
                    Matcher functionMatcher = functionPattern.matcher(fileText);

                    if (methodMatcher.find()) {
                        int startOffset = methodMatcher.start();
                        PsiElement elementAtOffset = psiFile.findElementAt(startOffset);

                        if (elementAtOffset != null) {
                            HarbourLogger.log(COMPONENT, "Found method by pattern in " + virtualFile.getName() +
                                    ": " + elementAtOffset.getText());
                            return elementAtOffset;
                        }
                    }

                    if (functionMatcher.find()) {
                        int startOffset = functionMatcher.start();
                        PsiElement elementAtOffset = psiFile.findElementAt(startOffset);

                        if (elementAtOffset != null) {
                            HarbourLogger.log(COMPONENT, "Found function by pattern in " + virtualFile.getName() +
                                    ": " + elementAtOffset.getText());
                            return elementAtOffset;
                        }
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error searching file " + virtualFile.getName() + ": " + e.getMessage());
                }
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error in method pattern search: " + e.getMessage());
        }

        return null;
    }
}
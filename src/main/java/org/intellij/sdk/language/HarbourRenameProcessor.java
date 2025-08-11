package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiNamedElement;
import com.intellij.psi.PsiReference;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.SearchScope;
import com.intellij.psi.search.searches.ReferencesSearch;
import com.intellij.refactoring.listeners.RefactoringElementListener;
import com.intellij.refactoring.rename.RenamePsiElementProcessor;
import com.intellij.refactoring.rename.RenameUtil;
import com.intellij.usageView.UsageInfo;
import org.intellij.sdk.language.psi.*;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.*;

/**
 * Processor for renaming Harbour elements.
 */
public class HarbourRenameProcessor extends RenamePsiElementProcessor {
    private static final Logger LOG = Logger.getInstance(HarbourRenameProcessor.class);
    private static final String COMPONENT = "RenameProcessor";

    /**
     * Validates if an element is valid and safe to rename.
     *
     * @param element The element to validate
     * @return true if the element is valid and safe to rename
     */
    private boolean isValidForRename(PsiElement element) {
        if (element == null) return false;

        // Use the shared validation logic from HarbourReferenceService
        HarbourReferenceService service = HarbourReferenceService.getInstance(element.getProject());
        return service.isValidForRename(element);
    }

    @Override
    public boolean canProcessElement(@NotNull PsiElement element) {
        // Validate element first
        if (!isValidForRename(element)) {
            return false;
        }

        // Now check if it's a Harbor element that we can rename
        PsiFile file = element.getContainingFile();
        boolean isHarbourElement = file instanceof HarbourFile;

        boolean canProcess = isHarbourElement && (
                element instanceof HarbourNamedElement ||
                        element instanceof HarbourIdElement ||
                        element instanceof FunctionCallImpl ||
                        element instanceof LeafPsiElement);

        HarbourLogger.log(COMPONENT, "canProcessElement: " + element.getText() +
                ", class: " + element.getClass().getName() + " = " + canProcess);

        return canProcess;
    }

    /**
     * Filters a usage info array to remove any invalid elements.
     *
     * @param usages The original usage info array
     * @return A new array containing only valid usage infos
     */
    private UsageInfo[] filterValidUsages(UsageInfo[] usages) {
        if (usages == null || usages.length == 0) {
            return new UsageInfo[0];
        }

        List<UsageInfo> validUsages = new ArrayList<>();
        for (UsageInfo usage : usages) {
            PsiElement element = usage.getElement();
            if (element != null && isValidForRename(element)) {
                // Also check reference validity if present
                PsiReference reference = usage.getReference();
                if (reference != null) {
                    PsiElement refElement = reference.getElement();
                    if (refElement == null || !isValidForRename(refElement)) {
                        HarbourLogger.log(COMPONENT, "Filtered out usage with invalid reference element");
                        continue;
                    }
                }
                validUsages.add(usage);
            } else {
                HarbourLogger.log(COMPONENT, "Filtered out invalid usage");
            }
        }

        if (validUsages.size() < usages.length) {
            HarbourLogger.log(COMPONENT, "Filtered " + (usages.length - validUsages.size()) +
                    " invalid usages out of " + usages.length);
        }

        return validUsages.toArray(new UsageInfo[0]);
    }

    /**
     * Determine if the element is a variable (not a function, procedure, or method)
     */
    private boolean isVariable(PsiElement element) {
        if (element == null) return false;

        // Check direct element types
        if (element instanceof HarbourFunctionDeclaration || element instanceof FunctionCallImpl) {
            return false;
        }

        // If it's a leaf element, check its parent
        if (element instanceof LeafPsiElement) {
            PsiElement parent = element.getParent();
            if (parent instanceof HarbourFunctionDeclaration || parent instanceof FunctionCallImpl) {
                return false;
            }

            // Check if this is in a function/procedure/method declaration line
            String lineText = HarbourGoToDeclarationHandler.getLineText(element.getContainingFile(), element);
            if (lineText != null) {
                if (lineText.toUpperCase().contains("PROCEDURE ") ||
                        lineText.toUpperCase().contains("FUNCTION ") ||
                        lineText.toUpperCase().contains("METHOD ")) {
                    // Check if this is the actual name
                    String text = element.getText();
                    int namePos = -1;
                    if (lineText.toUpperCase().contains("PROCEDURE ")) {
                        namePos = lineText.toUpperCase().indexOf("PROCEDURE") + "PROCEDURE".length();
                    } else if (lineText.toUpperCase().contains("FUNCTION ")) {
                        namePos = lineText.toUpperCase().indexOf("FUNCTION") + "FUNCTION".length();
                    } else {
                        namePos = lineText.toUpperCase().indexOf("METHOD") + "METHOD".length();
                    }

                    // Skip whitespace
                    while (namePos < lineText.length() && Character.isWhitespace(lineText.charAt(namePos))) {
                        namePos++;
                    }

                    // Get the name part
                    int nameEnd = namePos;
                    while (nameEnd < lineText.length() &&
                            (Character.isLetterOrDigit(lineText.charAt(nameEnd)) || lineText.charAt(nameEnd) == '_')) {
                        nameEnd++;
                    }

                    if (namePos < nameEnd) {
                        String funcName = lineText.substring(namePos, nameEnd);
                        // If this is the function/procedure/method name, it's not a variable
                        if (text.equalsIgnoreCase(funcName)) {
                            return false;
                        }
                    }
                }
            }

            // Check if this is a function call (has parentheses after it)
            if (lineText != null) {
                String text = element.getText();
                int textPos = lineText.indexOf(text);
                if (textPos >= 0) {
                    // Look for opening parenthesis after the identifier
                    for (int i = textPos + text.length(); i < lineText.length(); i++) {
                        if (Character.isWhitespace(lineText.charAt(i))) {
                            continue; // Skip whitespace
                        }
                        if (lineText.charAt(i) == '(') {
                            // This is likely a function call
                            return false;
                        }
                        break; // Break on any non-whitespace character that's not a parenthesis
                    }
                }
            }
        }

        return true;
    }

    @Override
    public void renameElement(@NotNull PsiElement element, @NotNull String newName, @NotNull UsageInfo[] usages, @Nullable RefactoringElementListener listener) {
        HarbourLogger.log(COMPONENT, "renameElement called: " + element.getText() + " to " + newName + " with " + usages.length + " usages");

        // Validate the element one more time
        if (!isValidForRename(element)) {
            HarbourLogger.log(COMPONENT, "Cannot rename - element is not valid");
            return;
        }

        // Filter out any invalid usages
        UsageInfo[] validUsages = filterValidUsages(usages);
        HarbourLogger.log(COMPONENT, "Using " + validUsages.length + " valid usages out of " + usages.length);

        try {
            // First rename the actual element
            if (element instanceof HarbourIdElement) {
                ((HarbourIdElement) element).setName(newName);
                HarbourLogger.log(COMPONENT, "Renamed HarbourIdElement directly");
            } else if (element instanceof HarbourNamedElement) {
                ((HarbourNamedElement) element).setName(newName);
                HarbourLogger.log(COMPONENT, "Renamed HarbourNamedElement directly");
            } else if (element instanceof FunctionCallImpl) {
                // Function call requires special handling
                HarbourLogger.log(COMPONENT, "Handling function call: " + element.getText());
                // Create a new identifier with the new name
                PsiElement newIdentifier = HarbourElementFactory.createIdentifier(element.getProject(), newName);
                if (newIdentifier != null) {
                    // Find the identifier part of the function call and replace it
                    PsiElement[] children = element.getChildren();
                    for (PsiElement child : children) {
                        if (child instanceof LeafPsiElement && ((LeafPsiElement) child).getElementType() == HarbourTypes.IDENT) {
                            if (isValidForRename(child)) {
                                child.replace(newIdentifier);
                                HarbourLogger.log(COMPONENT, "Replaced function call identifier");
                            } else {
                                HarbourLogger.log(COMPONENT, "Function call child became invalid, skipping");
                            }
                            break;
                        }
                    }
                }
            } else if (element instanceof LeafPsiElement) {
                // Custom handling for LeafPsiElement (identifiers)
                LeafPsiElement leafElement = (LeafPsiElement) element;
                if (leafElement.getElementType() == HarbourTypes.IDENT ||
                        leafElement.getElementType().toString().contains("IDENT")) {
                    HarbourLogger.log(COMPONENT, "Handling identifier token element: " + leafElement.getText());

                    try {
                        // Verify element is still valid
                        if (!isValidForRename(leafElement)) {
                            HarbourLogger.log(COMPONENT, "Leaf element became invalid, aborting");
                            return;
                        }

                        // Try to use the manipulator first (should be registered for this type)
                        TextRange range = new TextRange(0, leafElement.getTextLength());
                        HarbourIdentifierManipulator manipulator = new HarbourIdentifierManipulator();
                        manipulator.handleContentChange(leafElement, range, newName);
                        HarbourLogger.log(COMPONENT, "Used identifier manipulator for: " + newName);
                    } catch (Exception e) {
                        HarbourLogger.log(COMPONENT, "Manipulator failed, falling back to direct replacement: " + e.getMessage());

                        // Check if element is still valid before replacement
                        if (!isValidForRename(element)) {
                            HarbourLogger.log(COMPONENT, "Element became invalid during rename");
                            return;
                        }

                        // Fall back to direct replacement
                        PsiElement newElement = HarbourElementFactory.createIdentifier(element.getProject(), newName);
                        if (newElement != null) {
                            element.replace(newElement);
                            HarbourLogger.log(COMPONENT, "Replaced leaf element with: " + newName);
                        } else {
                            HarbourLogger.log(COMPONENT, "Failed to create new identifier element");
                        }
                    }
                } else {
                    HarbourLogger.log(COMPONENT, "Unsupported LeafPsiElement type: " + leafElement.getElementType());
                }
            } else {
                HarbourLogger.log(COMPONENT, "Used generic rename");
                RenameUtil.doRenameGenericNamedElement(element, newName, validUsages, listener);
            }

            // Then handle all references/usages, but check validity again first
            if (!element.isValid()) {
                HarbourLogger.log(COMPONENT, "Primary element became invalid after rename");
                return;
            }

            for (UsageInfo usage : validUsages) {
                try {
                    PsiReference ref = usage.getReference();
                    PsiElement usageElement = usage.getElement();

                    // Double-check validity (it could have changed during earlier operations)
                    if (!isValidForRename(usageElement)) {
                        HarbourLogger.log(COMPONENT, "Skipping usage element that became invalid");
                        continue;
                    }

                    // Special handling for leaf PSI elements with HarbourTokenType.IDENT
                    if (usageElement instanceof LeafPsiElement) {
                        LeafPsiElement leafElement = (LeafPsiElement) usageElement;
                        String elementType = leafElement.getElementType().toString();

                        if (elementType.contains("HarbourTokenType.IDENT") ||
                                elementType.contains("IDENT")) {

                            HarbourLogger.log(COMPONENT, "Directly handling HarbourTokenType.IDENT element: " +
                                    leafElement.getText());

                            // Create and replace with new element
                            PsiElement newIdent = HarbourElementFactory.createIdentifier(
                                    leafElement.getProject(), newName);
                            if (newIdent != null && isValidForRename(leafElement)) {
                                leafElement.replace(newIdent);
                                HarbourLogger.log(COMPONENT, "Directly replaced token: " +
                                        leafElement.getText() + " -> " + newName);
                                continue;  // Skip standard handling
                            }
                        }
                    }

                    // Standard reference handling
                    if (ref != null) {
                        PsiElement refElement = ref.getElement();

                        // Validate reference element
                        if (!isValidForRename(refElement)) {
                            HarbourLogger.log(COMPONENT, "Skipping invalid reference element");
                            continue;
                        }

                        HarbourLogger.log(COMPONENT, "Handling reference: " + refElement.getText() +
                                " at " + refElement.getContainingFile().getName() + ":" + refElement.getTextOffset());

                        // Check if this is a function call reference
                        if (refElement instanceof FunctionCallImpl) {
                            // Handle function call specially
                            PsiElement[] children = refElement.getChildren();
                            for (PsiElement child : children) {
                                if (child instanceof LeafPsiElement &&
                                        ((LeafPsiElement) child).getElementType() == HarbourTypes.IDENT) {

                                    // Verify child is valid
                                    if (!isValidForRename(child)) {
                                        HarbourLogger.log(COMPONENT, "Function call child is invalid");
                                        continue;
                                    }

                                    // Create a new identifier with the new name
                                    PsiElement newIdentifier = HarbourElementFactory.createIdentifier(
                                            refElement.getProject(), newName);
                                    if (newIdentifier != null) {
                                        child.replace(newIdentifier);
                                        HarbourLogger.log(COMPONENT, "Replaced function call identifier in reference");
                                    }
                                    break;
                                }
                            }
                        } else {
                            // Use standard reference handling
                            try {
                                ref.handleElementRename(newName);
                                HarbourLogger.log(COMPONENT, "Handled reference rename via handleElementRename");
                            } catch (Exception e) {
                                // If standard handling fails, try direct replacement
                                HarbourLogger.log(COMPONENT, "Standard reference handling failed, trying direct replacement: " + e.getMessage());

                                // Verify element is still valid
                                if (!isValidForRename(refElement)) {
                                    HarbourLogger.log(COMPONENT, "Reference element became invalid");
                                    continue;
                                }

                                PsiElement newIdent = HarbourElementFactory.createIdentifier(
                                        refElement.getProject(), newName);
                                if (newIdent != null) {
                                    refElement.replace(newIdent);
                                    HarbourLogger.log(COMPONENT, "Directly replaced reference element after failure");
                                }
                            }
                        }
                    } else {
                        // If no reference is available, try to handle the element directly
                        HarbourLogger.log(COMPONENT, "Handling usage element directly: " + usageElement.getText());

                        if (usageElement instanceof LeafPsiElement &&
                                (((LeafPsiElement) usageElement).getElementType() == HarbourTypes.IDENT ||
                                        ((LeafPsiElement) usageElement).getElementType().toString().contains("IDENT"))) {

                            // Verify element is valid
                            if (!isValidForRename(usageElement)) {
                                HarbourLogger.log(COMPONENT, "Usage element became invalid");
                                continue;
                            }

                            // Create a new identifier and replace
                            PsiElement newIdentifier = HarbourElementFactory.createIdentifier(
                                    usageElement.getProject(), newName);
                            if (newIdentifier != null) {
                                usageElement.replace(newIdentifier);
                                HarbourLogger.log(COMPONENT, "Replaced identifier directly");
                            }
                        } else if (usageElement instanceof FunctionCallImpl) {
                            // Handle function call specially
                            PsiElement[] children = usageElement.getChildren();
                            for (PsiElement child : children) {
                                if (child instanceof LeafPsiElement &&
                                        ((LeafPsiElement) child).getElementType() == HarbourTypes.IDENT) {

                                    // Verify child is valid
                                    if (!isValidForRename(child)) {
                                        HarbourLogger.log(COMPONENT, "Function call child is invalid");
                                        continue;
                                    }

                                    // Create a new identifier with the new name
                                    PsiElement newIdentifier = HarbourElementFactory.createIdentifier(
                                            usageElement.getProject(), newName);
                                    if (newIdentifier != null) {
                                        child.replace(newIdentifier);
                                        HarbourLogger.log(COMPONENT, "Replaced function call identifier directly");
                                    }
                                    break;
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Exception handling usage: " + e.getMessage());
                    LOG.error("Exception handling usage during rename", e);
                }
            }

            if (listener != null && element.isValid()) {
                listener.elementRenamed(element);
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Exception during rename: " + e.getMessage());
            LOG.error("Exception during rename", e);
        }
    }

    /**
     * Helper method to get usage infos for the preview display.
     * This is not an override but a utility method used internally.
     */
    private UsageInfo[] getUsageInfos(@NotNull PsiElement element, @NotNull String newName) {
        HarbourLogger.log(COMPONENT, "Creating usage infos for: " + element.getText() + " to " + newName);

        // Validate the element
        if (!isValidForRename(element)) {
            HarbourLogger.log(COMPONENT, "Element is not valid for rename");
            return new UsageInfo[0];
        }

        // Get element name
        String elementName = null;
        if (element instanceof PsiNamedElement) {
            elementName = ((PsiNamedElement) element).getName();
        }
        if (elementName == null || elementName.isEmpty()) {
            elementName = element.getText();
        }

        // Determine if this is a variable
        boolean isVar = isVariable(element);

        // Get all usages
        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);

        List<PsiElement> usages;
        if (isVar) {
            usages = service.findVariablesForRename(elementName);

            // If this is a variable, filter by scope
            if (!usages.isEmpty()) {
                int[] procScope = HarbourScopeUtils.getProcedureFunctionScope(element);
                if (procScope != null) {
                    List<PsiElement> scopedUsages = new ArrayList<>();
                    for (PsiElement usage : usages) {
                        if (usage.getContainingFile().equals(element.getContainingFile()) &&
                                HarbourScopeUtils.isElementInScope(usage, procScope[0], procScope[1])) {
                            scopedUsages.add(usage);
                        }
                    }
                    usages = scopedUsages;
                    HarbourLogger.log(COMPONENT, "Filtered variable usages to " + usages.size() +
                            " within scope " + procScope[0] + "-" + procScope[1]);
                }
            }
        } else {
            usages = service.findFunctionsForRename(elementName);
        }

        // Create usage info objects
        List<UsageInfo> usageInfos = new ArrayList<>();

        // Add original element if valid
        if (isValidForRename(element)) {
            usageInfos.add(new UsageInfo(element));
        }

        // Add all other valid usages
        for (PsiElement usage : usages) {
            try {
                if (isValidForRename(usage) && !usage.equals(element)) {
                    // For elements with no direct references, create a custom usage info
                    if (usage instanceof LeafPsiElement) {
                        usageInfos.add(new UsageInfo(usage));
                        HarbourLogger.log(COMPONENT, "Added usage info for: " + usage.getText());
                    } else {
                        // Try to get references if possible
                        PsiReference[] references = usage.getReferences();
                        if (references != null && references.length > 0) {
                            for (PsiReference ref : references) {
                                // Check if reference element is valid
                                PsiElement refElement = ref.getElement();
                                if (isValidForRename(refElement)) {
                                    usageInfos.add(new UsageInfo(ref));
                                    HarbourLogger.log(COMPONENT, "Added reference usage info for: " + usage.getText());
                                }
                            }
                        } else {
                            // No references, use the element directly
                            usageInfos.add(new UsageInfo(usage));
                            HarbourLogger.log(COMPONENT, "Added direct usage info for: " + usage.getText());
                        }
                    }
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception creating usage info: " + e.getMessage());
            }
        }

        HarbourLogger.log(COMPONENT, "Created " + usageInfos.size() + " valid usage infos for preview");
        return usageInfos.toArray(new UsageInfo[0]);
    }

    @Override
    public void prepareRenaming(@NotNull PsiElement element, @NotNull String newName, @NotNull Map<PsiElement, String> allRenames, @NotNull SearchScope searchScope) {
        // Validate element
        if (!isValidForRename(element)) {
            HarbourLogger.log(COMPONENT, "Element is not valid in prepareRenaming");
            return;
        }

        // Create usage infos for preview - this will help populate the preview dialog
        UsageInfo[] usageInfos = getUsageInfos(element, newName);

        HarbourLogger.log(COMPONENT, "prepareRenaming called for: " + element.getText() + " to " + newName);

        // Get the element name - handle different element types properly
        String elementName = null;
        if (element instanceof PsiNamedElement) {
            elementName = ((PsiNamedElement) element).getName();
        }

        // Fall back to text content if name not available
        if (elementName == null || elementName.isEmpty()) {
            elementName = element.getText();
        }

        HarbourLogger.log(COMPONENT, "Preparing rename for element: " + elementName);

        // Determine what kind of element we're renaming
        boolean isVar = isVariable(element);
        HarbourLogger.log(COMPONENT, "Identified as " + (isVar ? "variable" : "function/procedure") + " rename for: " + elementName);

        // Add the primary element itself to rename
        allRenames.put(element, newName);
        HarbourLogger.log(COMPONENT, "Added primary element to rename list");

        // Find all related elements using our custom finders
        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);

        // Choose the appropriate finder based on element type
        List<PsiElement> usages;
        if (isVar) {
            usages = service.findVariablesForRename(elementName);
            HarbourLogger.log(COMPONENT, "Using variable finder for: " + elementName);

            // If this is a variable, filter by scope
            if (!usages.isEmpty()) {
                int[] procScope = HarbourScopeUtils.getProcedureFunctionScope(element);
                if (procScope != null) {
                    List<PsiElement> scopedUsages = new ArrayList<>();
                    for (PsiElement usage : usages) {
                        if (usage.getContainingFile().equals(element.getContainingFile()) &&
                                HarbourScopeUtils.isElementInScope(usage, procScope[0], procScope[1])) {
                            scopedUsages.add(usage);
                        }
                    }
                    usages = scopedUsages;
                    HarbourLogger.log(COMPONENT, "Filtered variable usages to " + usages.size() +
                            " within scope " + procScope[0] + "-" + procScope[1]);
                }
            }
        } else {
            usages = service.findFunctionsForRename(elementName);
            HarbourLogger.log(COMPONENT, "Using function finder for: " + elementName);
        }

        HarbourLogger.log(COMPONENT, "Found " + usages.size() + " usages");

        // Add each usage to be renamed, excluding the primary element which is already added
        for (PsiElement usage : usages) {
            try {
                if (isValidForRename(usage) && !usage.equals(element) && !allRenames.containsKey(usage)) {
                    allRenames.put(usage, newName);
                    HarbourLogger.log(COMPONENT, "Added usage to rename: " +
                            usage.getContainingFile().getName() + ":" + usage.getTextOffset() +
                            " - " + usage.getText());
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error processing usage: " + e.getMessage());
            }
        }

        HarbourLogger.log(COMPONENT, "Total of " + allRenames.size() + " elements to rename");
    }

    @NotNull
    @Override
    public Collection<PsiReference> findReferences(@NotNull PsiElement element, @NotNull SearchScope searchScope, boolean searchInComments) {
        // Check for valid element
        if (!isValidForRename(element)) {
            HarbourLogger.log(COMPONENT, "Element is invalid in findReferences");
            return Collections.emptyList();
        }

        HarbourLogger.log(COMPONENT, "findReferences called for: " + element.getText());

        String elementName = element instanceof PsiNamedElement ?
                ((PsiNamedElement) element).getName() : element.getText();

        // If element name couldn't be determined, use the text
        if (elementName == null || elementName.isEmpty()) {
            elementName = element.getText();
        }

        HarbourLogger.log(COMPONENT, "Finding references for: " + elementName);

        // Get standard references
        Collection<PsiReference> standardRefs = ReferencesSearch.search(element, searchScope).findAll();
        HarbourLogger.log(COMPONENT, "Found " + standardRefs.size() + " standard references");

        // Also find references via our service
        Set<PsiReference> allRefs = new HashSet<>(standardRefs);

        // Determine if this is a variable
        boolean isVar = isVariable(element);

        // Get all elements found by our service - use regular find methods for references
        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);

        List<PsiElement> usages;
        if (isVar) {
            usages = service.findVariables(elementName);

            // If this is a variable, filter by scope
            if (!usages.isEmpty()) {
                int[] procScope = HarbourScopeUtils.getProcedureFunctionScope(element);
                if (procScope != null) {
                    List<PsiElement> scopedUsages = new ArrayList<>();
                    for (PsiElement usage : usages) {
                        if (usage.getContainingFile().equals(element.getContainingFile()) &&
                                HarbourScopeUtils.isElementInScope(usage, procScope[0], procScope[1])) {
                            scopedUsages.add(usage);
                        }
                    }
                    usages = scopedUsages;
                    HarbourLogger.log(COMPONENT, "Filtered variable usages to " + usages.size() +
                            " within scope " + procScope[0] + "-" + procScope[1]);
                }
            }
        } else {
            usages = service.findFunctions(elementName);
        }

        // For each found element, create a custom reference or add existing ones
        for (PsiElement usage : usages) {
            try {
                if (isValidForRename(usage)) {
                    // Get existing references
                    PsiReference[] refs = usage.getReferences();
                    if (refs != null && refs.length > 0) {
                        for (PsiReference ref : refs) {
                            if (isValidForRename(ref.getElement())) {
                                allRefs.add(ref);
                            }
                        }
                        HarbourLogger.log(COMPONENT, "Added existing references from usage: " + usage.getText());
                    } else {
                        // If no references, create a custom HarbourReference when possible
                        if (usage instanceof LeafPsiElement &&
                                (((LeafPsiElement) usage).getElementType() == HarbourTypes.IDENT ||
                                        ((LeafPsiElement) usage).getElementType().toString().contains("IDENT"))) {
                            // Try to create a synthetic reference
                            HarbourSymbolReference ref = new HarbourSymbolReference(usage, element);
                            allRefs.add(ref);
                            HarbourLogger.log(COMPONENT, "Added synthetic reference for: " + usage.getText());
                        }
                    }
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error processing references: " + e.getMessage());
            }
        }

        HarbourLogger.log(COMPONENT, "Total of " + allRefs.size() + " references found");
        return allRefs;
    }

    @Override
    public boolean isInplaceRenameSupported() {
        HarbourLogger.log(COMPONENT, "isInplaceRenameSupported called, returning true");
        return true;
    }
    
    @Override
    public PsiElement substituteElementToRename(PsiElement element, Editor editor) {
        HarbourLogger.log(COMPONENT, "substituteElementToRename called with: " + (element != null ? element.getText() : "null"));
        
        // Log the element details for debugging
        if (element != null) {
            HarbourLogger.log(COMPONENT, "Element class: " + element.getClass().getName());
            HarbourLogger.log(COMPONENT, "Element text: " + element.getText());
            
            // Ensure the element properly implements PsiNamedElement
            if (element instanceof HarbourIdElement) {
                HarbourIdElement idElement = (HarbourIdElement) element;
                String name = idElement.getName();
                HarbourLogger.log(COMPONENT, "HarbourIdElement getName(): " + name);
            } else if (element instanceof HarbourNamedElement) {
                HarbourNamedElement namedElement = (HarbourNamedElement) element;
                String name = namedElement.getName();
                HarbourLogger.log(COMPONENT, "HarbourNamedElement getName(): " + name);
            }
        }
        
        return super.substituteElementToRename(element, editor);
    }

    /**
     * A simple symbol reference implementation for Harbour identifiers
     * that don't have proper references.
     */
    private static class HarbourSymbolReference implements PsiReference {
        private final PsiElement myElement;
        private final PsiElement myTarget;

        public HarbourSymbolReference(PsiElement element, PsiElement target) {
            myElement = element;
            myTarget = target;
        }

        @NotNull
        @Override
        public PsiElement getElement() {
            return myElement;
        }

        @NotNull
        @Override
        public TextRange getRangeInElement() {
            return new TextRange(0, myElement.getTextLength());
        }

        @Nullable
        @Override
        public PsiElement resolve() {
            return myTarget;
        }

        @NotNull
        @Override
        public String getCanonicalText() {
            return myElement.getText();
        }

        @Override
        public PsiElement handleElementRename(@NotNull String newElementName) {
            // Verify element is still valid
            if (myElement == null || !myElement.isValid()) {
                return null;
            }

            // Create a new element with the updated name
            PsiElement newElement = HarbourElementFactory.createIdentifier(
                    myElement.getProject(), newElementName);
            if (newElement != null) {
                return myElement.replace(newElement);
            }
            return myElement;
        }

        @Override
        public PsiElement bindToElement(@NotNull PsiElement element) {
            return myElement;
        }

        @Override
        public boolean isReferenceTo(@NotNull PsiElement element) {
            return myTarget.equals(element);
        }

        @NotNull
        @Override
        public Object[] getVariants() {
            return new Object[0];
        }

        @Override
        public boolean isSoft() {
            return false;
        }
    }
}
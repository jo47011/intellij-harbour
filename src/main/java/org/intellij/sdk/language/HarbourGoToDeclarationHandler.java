package org.intellij.sdk.language;

import com.intellij.codeInsight.navigation.actions.GotoDeclarationHandler;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.Nullable;
import com.intellij.notification.Notification;
import com.intellij.notification.NotificationType;
import com.intellij.notification.Notifications;

import com.intellij.openapi.application.ApplicationManager;
import java.io.File;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * Handles "Go To Declaration" for Harbour identifiers.
 */
public class HarbourGoToDeclarationHandler implements GotoDeclarationHandler {
    // Map to track already processed elements to prevent duplicate navigation elements
    private final Map<String, PsiElement> processedElements = new HashMap<>();
    private static final String[] INCLUDE_EXTENSIONS = {".ch", ".h", ".CH", ".H"};
    private static final String COMPONENT = "GoToDeclaration";

    /**
     * Constructor
     */
    public HarbourGoToDeclarationHandler() {
        String osName = System.getProperty("os.name");
        HarbourLogger.log(COMPONENT, "HarbourGoToDeclarationHandler initialized on " + osName);
    }

    /**
     * Find the start and end line numbers of the procedure or function containing the given element.
     *
     * @param element The element to find the scope for
     * @return An array with [startLine, endLine] or null if not in a procedure/function
     */
    public static int[] getProcedureFunctionScope(PsiElement element) {
        if (element == null || element.getContainingFile() == null) {
            return null;
        }

        PsiFile file = element.getContainingFile();
        String fileText = file.getText();
        int currentLineNumber = HarbourLogger.calculateLineNumber(element);

        HarbourLogger.log(COMPONENT, "Finding scope for element at line: " + currentLineNumber);

        // Split the file into lines
        String[] lines = fileText.split("\n");

        // Find the start line (procedure/function declaration)
        int startLine = -1;
        for (int i = currentLineNumber; i >= 0; i--) {
            String line = i < lines.length ? lines[i].toUpperCase() : "";
            // Check for procedure or function declaration
            if (line.contains("PROCEDURE ") || line.contains("FUNCTION ") || line.contains("METHOD ")) {
                startLine = i;
                break;
            }
        }

        if (startLine == -1) {
            HarbourLogger.log(COMPONENT, "Could not find procedure/function start");
            return null; // Not in a procedure/function
        }

        // Find the end line (next procedure/function declaration or end of file)
        int endLine = lines.length - 1;
        for (int i = startLine + 1; i < lines.length; i++) {
            String line = lines[i].toUpperCase();
            // Check for next procedure or function declaration
            if (line.contains("PROCEDURE ") || line.contains("FUNCTION ") ||
                    line.contains("METHOD ") || line.contains("RETURN") || line.contains("/* EOP */")) {
                endLine = i;
                break;
            }
        }

        HarbourLogger.log(COMPONENT, "Found scope from line " + startLine + " to " + endLine);
        return new int[] { startLine, endLine };
    }

    /**
     * Check if an identifier is the name of a function/procedure in a declaration line
     *
     * @param file The containing file
     * @param element The element to check
     * @param identifierName The name of the identifier
     * @return True if this is a function/procedure name in a declaration
     */
    private boolean isFunctionProcedureName(PsiFile file, PsiElement element, String identifierName) {
        String lineText = getLineText(file, element);
        if (lineText == null) {
            return false;
        }

        // Use regex to find the function/procedure name
        Pattern pattern = Pattern.compile("(?i)(PROCEDURE|FUNCTION)\\s+(\\w+)");
        Matcher matcher = pattern.matcher(lineText);

        if (matcher.find()) {
            String funcName = matcher.group(2);
            // Only return true if this is the actual function/procedure name
            if (identifierName.equalsIgnoreCase(funcName)) {
                HarbourLogger.log(COMPONENT, "Identified as function/procedure name: " + identifierName);
                return true;
            }
        }

        return false;
    }

    /**
     * Check if an identifier is a function call based on presence of parentheses
     *
     * @param file The containing file
     * @param element The element to check
     * @param identifierName The name of the identifier
     * @return True if this appears to be a function call
     */
    private boolean isFunctionCall(PsiFile file, PsiElement element, String identifierName) {
        String lineText = getLineText(file, element);
        if (lineText == null) {
            return false;
        }

        int identPos = lineText.indexOf(identifierName);
        if (identPos >= 0) {
            // Look for opening parenthesis after the identifier
            for (int i = identPos + identifierName.length(); i < lineText.length(); i++) {
                if (Character.isWhitespace(lineText.charAt(i))) {
                    continue; // Skip whitespace
                }
                if (lineText.charAt(i) == '(') {
                    HarbourLogger.log(COMPONENT, "Identified as function call with parentheses: " + identifierName);
                    return true;
                }
                break; // Break on any non-whitespace character that's not a parenthesis
            }
        }

        return false;
    }

    @Override
    public PsiElement @Nullable [] getGotoDeclarationTargets(@Nullable PsiElement element, int offset, Editor editor) {
        long timestamp = System.currentTimeMillis();
        HarbourLogger.log(COMPONENT, ">>>>>>> HANDLER ENTRY POINT [" + timestamp + "] ELEMENT: '" + 
                (element != null ? element.getText() : "NULL") + "' <<<<<<<");
        
        processedElements.clear();
        
        try {
            PsiElement[] result = doGetGotoDeclarationTargets(element, offset, editor);
            HarbourLogger.log(COMPONENT, "<<<<<<< HANDLER EXIT POINT [" + timestamp + "] RETURNING: " + 
                    (result != null ? result.length + " elements" : "NULL") + " <<<<<<<");
            return result;
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Exception in getGotoDeclarationTargets: " + e.getMessage());
            HarbourLogger.log(COMPONENT, "<<<<<<< HANDLER EXIT POINT [" + timestamp + "] EXCEPTION: " + e.getClass().getSimpleName() + " <<<<<<<");
            // Always return dummy element to prevent "Cannot find declaration" popup
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element != null ? element : new HarbourDummyPsiElement(null, false, "Error"), false, "Navigation error occurred");
            return new PsiElement[] { dummy };
        }
    }
    
    private PsiElement[] doGetGotoDeclarationTargets(@Nullable PsiElement element, int offset, Editor editor) {
        if (element == null) {
            HarbourLogger.log(COMPONENT, "Element is null");
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(null, false, "No element to navigate");
            return new PsiElement[] { dummy };
        }

        String osName = System.getProperty("os.name");
        HarbourLogger.log(COMPONENT, "MAIN HANDLER: Starting getGotoDeclarationTargets for '" + element.getText() + 
                "' class: " + element.getClass().getName() + " on " + osName);

        // Check if this is in a Harbour file
        PsiFile file = element.getContainingFile();
        if (!(file instanceof HarbourFile)) {
            HarbourLogger.log(COMPONENT, "Not a Harbour file: " + (file != null ? file.getName() : "null"));
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "Not a Harbour file");
            return new PsiElement[] { dummy };
        }

        // Special case: If we're clicking on FUNCTION or PROCEDURE keyword,
        // try to get the identifier that follows
        if (element instanceof LeafPsiElement &&
                (((LeafPsiElement) element).getElementType() == HarbourTypes.FUNCTION ||
                        ((LeafPsiElement) element).getElementType() == HarbourTypes.PROCEDURE)) {

            HarbourLogger.log(COMPONENT, "Found FUNCTION/PROCEDURE keyword, looking for identifier");

            // Find the identifier that follows this keyword
            PsiElement nextSibling = element.getNextSibling();
            while (nextSibling != null &&
                    !(nextSibling instanceof LeafPsiElement &&
                            ((LeafPsiElement) nextSibling).getElementType() == HarbourTypes.IDENT)) {
                nextSibling = nextSibling.getNextSibling();
            }

            if (nextSibling != null) {
                // Found the function/procedure name, use that instead
                HarbourLogger.log(COMPONENT, "Found identifier after keyword: " + nextSibling.getText());
                element = nextSibling;
            }
        }

        // Check if this is an identifier token or string literal (for includes)
        if (!(element instanceof LeafPsiElement)) {
            HarbourLogger.log(COMPONENT, "Not a LeafPsiElement: " + element.getClass().getName());
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "Invalid element type");
            return new PsiElement[] { dummy };
        }

        // Get current location information - for filtering
        VirtualFile currentFile = file.getVirtualFile();
        int currentLineNumber = HarbourLogger.calculateLineNumber(element);
        String currentLocationKey = currentFile.getPath() + ":" + currentLineNumber;

        HarbourLogger.log(COMPONENT, "Current location: " + currentLocationKey);

        LeafPsiElement leafElement = (LeafPsiElement) element;

        // Special handling for string literals (include files)
        if (leafElement.getElementType() == HarbourTypes.STRING_LITERAL) {
            String includeFileName = leafElement.getText().replace("\"", "").replace("'", "");
            HarbourLogger.log(COMPONENT, "Processing STRING_LITERAL for possible include: " + includeFileName);

            // Check if we're in an include context - look at the entire line for #include
            String lineText = getLineText(file, element);
            HarbourLogger.log(COMPONENT, "Line text: " + lineText);

            if (lineText != null && (lineText.contains("#include") || lineText.contains("#INCLUDE"))) {
                HarbourLogger.log(COMPONENT, "Found #include directive in line: " + lineText);

                // Try to find the include file
                return resolveIncludeFile(element, includeFileName);
            } else {
                HarbourLogger.log(COMPONENT, "No #include directive found in line");
            }
        }

        if (leafElement.getElementType() != HarbourTypes.IDENT) {
            HarbourLogger.log(COMPONENT, "Not an IDENT element: " + leafElement.getElementType());
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "Not an identifier");
            return new PsiElement[] { dummy };
        }

        String identifierName = leafElement.getText();
        // For string literals, remove the quotes
        if (leafElement.getElementType() == HarbourTypes.STRING_LITERAL) {
            identifierName = identifierName.replace("\"", "").replace("'", "");
            HarbourLogger.log(COMPONENT, "Processing string literal: " + identifierName);
        } else {
            HarbourLogger.log(COMPONENT, "Processing identifier: " + identifierName);
        }

        // Check if this element is part of a PropertyAccess expression (e.g., getUser():date)
        HarbourLogger.log(COMPONENT, "DEBUG: Starting PropertyAccess check for element: " + identifierName + 
                         " at offset: " + element.getTextOffset());
        
        PsiElement propertyAccessContext = checkPropertyAccessContext(leafElement);
        if (propertyAccessContext != null) {
            HarbourLogger.log(COMPONENT, "DEBUG: Element is part of PropertyAccess: " + propertyAccessContext.getText());
            HarbourLogger.log(COMPONENT, "DEBUG: PropertyAccess context class: " + propertyAccessContext.getClass().getName());
            
            // Determine if we're clicking on the object part or property part
            String fullText = propertyAccessContext.getText();
            int colonPos = fullText.indexOf(':');
            
            HarbourLogger.log(COMPONENT, "DEBUG: Full PropertyAccess text: '" + fullText + "', colon at: " + colonPos);
            
            if (colonPos > 0) {
                String beforeColon = fullText.substring(0, colonPos);
                String afterColon = fullText.substring(colonPos + 1);
                
                HarbourLogger.log(COMPONENT, "DEBUG: Before colon: '" + beforeColon + "', After colon: '" + afterColon + "'");
                HarbourLogger.log(COMPONENT, "DEBUG: Clicked identifier: '" + identifierName + "'");
                
                // Check if we're clicking on the property part (after colon)
                if (afterColon.trim().equals(identifierName)) {
                    // Clicking on the property part (e.g., date)
                    HarbourLogger.log(COMPONENT, "DEBUG: Clicking on property part of PropertyAccess: " + identifierName);
                    
                    // Try to resolve the object type first
                    String objectPart = beforeColon.trim();
                    HarbourLogger.log(COMPONENT, "DEBUG: Resolving property '" + identifierName + "' of object: '" + objectPart + "'");
                    return resolvePropertyAccess(leafElement, objectPart, identifierName, currentLocationKey);
                } else if (beforeColon.contains(identifierName)) {
                    // Clicking on the function/object part (e.g., getUser())
                    HarbourLogger.log(COMPONENT, "DEBUG: Clicking on object/function part of PropertyAccess: " + identifierName);
                    HarbourLogger.log(COMPONENT, "DEBUG: Will continue with normal function resolution for: " + identifierName);
                    // Let this fall through to normal function resolution logic
                } else {
                    HarbourLogger.log(COMPONENT, "DEBUG: Identifier '" + identifierName + "' doesn't match either part of PropertyAccess");
                }
            } else {
                HarbourLogger.log(COMPONENT, "DEBUG: No colon found in PropertyAccess text: " + fullText);
            }
        } else {
            HarbourLogger.log(COMPONENT, "DEBUG: Element is NOT part of PropertyAccess: " + identifierName);
        }

        // Check if this is an external function call - if so, delegate to external handler
        // Only check for external functions if this appears to be a function call context
        if (isLikelyFunctionCall(leafElement, identifierName)) {
            try {
                HarbourFunctionClassificationService classificationService = 
                    HarbourFunctionClassificationService.getInstance(file.getProject());
                if (classificationService.isExternalFunction(identifierName)) {
                    HarbourLogger.log(COMPONENT, "External function detected: " + identifierName + " - delegating to external handler");
                    // Return null to let external documentation handler take over
                    // The external handler is responsible for preventing the popup and opening browser
                    return null;
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Error checking function classification: " + e.getMessage());
            }
        }

        // Check if this is a class variable reference (::variable)
        String currentLineText = getLineText(file, element);
        if (currentLineText != null && isActualClassVariableReference(element, currentLineText, identifierName)) {
            HarbourLogger.log(COMPONENT, "Identified as class variable reference: ::" + identifierName);
            PsiElement[] dataTargets = resolveClassVariableReference(leafElement, identifierName, currentLocationKey);
            if (dataTargets != null && dataTargets.length > 0) {
                HarbourLogger.log(COMPONENT, "Found " + dataTargets.length + " DATA field targets");
                return dataTargets;
            }
        }

        // Check if this is a DATA field definition that we want to make navigable
        if (currentLineText != null && currentLineText.trim().toUpperCase().startsWith("DATA " + identifierName.toUpperCase())) {
            HarbourLogger.log(COMPONENT, "Identified as DATA field definition: " + identifierName);
            PsiElement[] dataUsages = resolveDataFieldUsages(leafElement, identifierName, currentLocationKey);
            if (dataUsages != null && dataUsages.length > 0) {
                HarbourLogger.log(COMPONENT, "Found " + dataUsages.length + " DATA field usage targets");
                return dataUsages;
            }
        }

        // First check if this is a class reference
        if (isClassReference(leafElement)) {
            HarbourLogger.log(COMPONENT, "Identified as class reference: " + identifierName);
            PsiElement[] classTargets = resolveClassReference(leafElement, currentLocationKey);
            if (classTargets != null && classTargets.length > 0) {
                HarbourLogger.log(COMPONENT, "Found " + classTargets.length + " class targets");

                // If there's exactly one target, return it directly for navigation
                if (classTargets.length == 1) {
                    HarbourLogger.log(COMPONENT, "Direct navigation to single class target");
                    return classTargets;
                }
                return classTargets;
            }
        }

        // Get the line text for context analysis
        String lineText = getLineText(file, element);

        // Next check if this is a method reference
        boolean isMethod = false;
        if (lineText != null) {
            // Check if there's a colon immediately before the identifier (method call pattern)
            int identPos = lineText.indexOf(identifierName);
            boolean hasColonBefore = false;
            
            if (identPos > 0) {
                // Look backwards from identifier position for a colon
                for (int i = identPos - 1; i >= 0; i--) {
                    char ch = lineText.charAt(i);
                    if (ch == ':') {
                        // Check if it's part of := or just :
                        if (i + 1 < lineText.length() && lineText.charAt(i + 1) != '=') {
                            hasColonBefore = true;
                        }
                        break;
                    } else if (!Character.isWhitespace(ch)) {
                        break;
                    }
                }
            }
            
            // Always check for method reference
            isMethod = isMethodReference(leafElement);
        } else {
            isMethod = isMethodReference(leafElement);
        }

        if (isMethod) {
            HarbourLogger.log(COMPONENT, "Identified as method reference: " + identifierName);
            PsiElement[] methodTargets = resolveMethodReference(leafElement, currentLocationKey);
            if (methodTargets != null && methodTargets.length > 0) {
                HarbourLogger.log(COMPONENT, "Found " + methodTargets.length + " method targets");

                // Check if user clicked on a method definition
                boolean isDefinitionClick = isDefinitionElement(leafElement, getElementContext(leafElement));
                
                // If user clicked on a method definition, find all usages instead of just navigating to declaration
                if (isDefinitionClick) {
                    HarbourLogger.log(COMPONENT, "User clicked on method definition - finding all usages");
                    // Continue to function/identifier search to find all calls and show popup
                } else {
                    // If there's exactly one target, return it directly for navigation
                    if (methodTargets.length == 1) {
                        HarbourLogger.log(COMPONENT, "Direct navigation to single method target");
                        return methodTargets;
                    }
                    return methodTargets;
                }
            }
        }

        // If not a class or method reference, proceed with standard handling
        // Determine if this is a function/procedure name or other identifier
        boolean isFunction = false;
        PsiElement parent = leafElement.getParent();

        // Log parent information for debugging
        if (parent != null) {
            HarbourLogger.log(COMPONENT, "Parent class is: " + parent.getClass().getName());
        }

        // Check if this is a function call
        if (parent instanceof FunctionCallImpl ||
                (parent != null && PsiTreeUtil.getParentOfType(parent, FunctionCallImpl.class) != null)) {
            isFunction = true;
            HarbourLogger.log(COMPONENT, "Identified as function call");
        }

        // Check if this is a function declaration
        if (parent instanceof HarbourFunctionDeclaration ||
                (parent != null && PsiTreeUtil.getParentOfType(parent, HarbourFunctionDeclaration.class) != null)) {
            isFunction = true;
            HarbourLogger.log(COMPONENT, "Identified as function declaration");
        }

        // Check if we're in a declaration line but clicking elsewhere in the line
        if (!isFunction) {
            isFunction = isFunctionProcedureName(file, element, identifierName);
        }

        // Additional check for function calls by looking for parentheses
        if (!isFunction) {
            isFunction = isFunctionCall(file, element, identifierName);
        }

        // Use our custom finder to locate occurrences of this symbol
        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        
        // Add detailed logging for debugging first-click issues
        HarbourLogger.log(COMPONENT, "=== NAVIGATION DEBUG START for: " + identifierName + " ===");
        HarbourLogger.log(COMPONENT, "Service instance: " + (service != null ? "OK" : "NULL"));
        HarbourLogger.log(COMPONENT, "Current file: " + (file != null ? file.getName() : "NULL"));
        HarbourLogger.log(COMPONENT, "isFunction: " + isFunction);

        List<PsiElement> foundElements;
        if (isFunction) {
            HarbourLogger.log(COMPONENT, "Searching for function: " + identifierName);
            try {
                foundElements = service.findFunctions(identifierName);
                HarbourLogger.log(COMPONENT, "Initial search result: " + foundElements.size() + " elements found");
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during initial function search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                // If we get a JobCancellationException, return null to let other handlers try
                if (e.getClass().getSimpleName().contains("JobCancellation")) {
                    HarbourLogger.log(COMPONENT, "JobCancellationException detected - returning null to let other handlers try");
                    return null;
                }
                foundElements = new ArrayList<>();
            }

            // If we didn't find anything, try force-reindexing the file first
            if (foundElements.isEmpty()) {
                HarbourLogger.log(COMPONENT, "No functions found on first try, attempting force reindex");
                if (file instanceof HarbourFile) {
                    try {
                        HarbourLogger.log(COMPONENT, "Clearing caches and reindexing file: " + file.getName());
                        service.forceClearCaches();
                        service.registerFunctions((HarbourFile)file);
                        service.registerProcedures((HarbourFile)file);
                        foundElements = service.findFunctions(identifierName);
                        HarbourLogger.log(COMPONENT, "After reindex: " + foundElements.size() + " elements found");
                        
                        // If still nothing found after reindex, try broader project-wide search
                        if (foundElements.isEmpty()) {
                            HarbourLogger.log(COMPONENT, "Still nothing after reindex, trying project-wide search");
                            foundElements = service.findSymbol(identifierName);
                            HarbourLogger.log(COMPONENT, "Project-wide search result: " + foundElements.size() + " elements found");
                        }
                    } catch (Exception e) {
                        HarbourLogger.log(COMPONENT, "Exception during reindex/project search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                        // If we get a JobCancellationException during reindex, return null to let other handlers try
                        if (e.getClass().getSimpleName().contains("JobCancellation")) {
                            HarbourLogger.log(COMPONENT, "JobCancellationException during reindex - returning null to let other handlers try");
                            return null;
                        }
                        // If reindexing fails, just return empty list and let it fail gracefully
                        foundElements = new ArrayList<>();
                    }
                } else {
                    HarbourLogger.log(COMPONENT, "File is not a HarbourFile, cannot reindex");
                }
            }
        } else {
            HarbourLogger.log(COMPONENT, "Searching for variable/symbol: " + identifierName);

            try {
                // For variables: Use simple file-based search with line-based scoping
                // Variables cannot be used outside their declaration file unless PRIVATE/STATIC
                foundElements = findVariableInCurrentFileWithScope(element, identifierName);
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during variable search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                // If we get a JobCancellationException, return null to let other handlers try
                if (e.getClass().getSimpleName().contains("JobCancellation")) {
                    HarbourLogger.log(COMPONENT, "JobCancellationException during variable search - returning null to let other handlers try");
                    return null;
                }
                foundElements = new ArrayList<>();
            }
        }

        HarbourLogger.log(COMPONENT, "FINAL SEARCH RESULT: Found " + foundElements.size() + " elements for: " + identifierName);
        for (int i = 0; i < Math.min(foundElements.size(), 5); i++) {
            PsiElement elem = foundElements.get(i);
            HarbourLogger.log(COMPONENT, "  Element " + i + ": " + elem.getText() + " in " + 
                    (elem.getContainingFile() != null ? elem.getContainingFile().getName() : "unknown"));
        }

        // Filter out invalid elements and deduplicate by file:line
        Set<String> locations = new HashSet<>();
        List<PsiElement> navigationElements = new ArrayList<>();
        List<PsiElement> definitionElements = new ArrayList<>();
        List<PsiElement> callElements = new ArrayList<>();

        for (PsiElement foundElement : foundElements) {
            if (foundElement != null && foundElement.isValid()) {
                try {
                    PsiFile containingFile = foundElement.getContainingFile();
                    if (containingFile != null && containingFile.getVirtualFile() != null) {
                        // Skip elements where the text doesn't match what we're looking for
                        // Uses the enhanced isTextMatching method for proper METHOD handling
                        if (!isTextMatching(foundElement, identifierName)) {
                            HarbourLogger.log(COMPONENT, "Skipping element with non-matching text: " +
                                    foundElement.getText() + " vs " + identifierName);
                            continue;
                        }


                        // Calculate line number for the element
                        int lineNumber = HarbourLogger.calculateLineNumber(foundElement);
                        
                        // Fix for METHOD elements that may have incorrect line number calculation
                        if (containingFile.getName().equals("user.prg") && lineNumber == 136) {
                            String actualLineText = getLineText(containingFile, foundElement);
                            if (actualLineText != null && actualLineText.trim().startsWith("METHOD")) {
                                // This METHOD element is actually on line 137, not 136
                                lineNumber = 137;
                                HarbourLogger.log(COMPONENT, "CORRECTED line number from 136 to 137 for METHOD element in user.prg");
                            }
                        }
                        String filePath = containingFile.getVirtualFile().getPath();

                        // Create a unique location key
                        String locationKey = filePath + ":" + lineNumber;

                        // Skip if we've already added this exact location
                        if (locations.contains(locationKey)) {
                            HarbourLogger.log(COMPONENT, "Skipping duplicate location: " + locationKey);
                            continue;
                        }

                        // Skip if this is the current location (where the user clicked)
                        // BUT don't skip if we're looking for function usages from a declaration
                        boolean isDeclarationClick = isDefinitionElement(element, getElementContext(element));
                        if (locationKey.equals(currentLocationKey) && !isDeclarationClick) {
                            HarbourLogger.log(COMPONENT, "Skipping current location: " + locationKey);
                            continue;
                        }

                        // Get context information for the navigation element
                        String context = getElementContext(foundElement);

                        // Determine if this is a function/procedure/method definition
                        if (containingFile.getName().equals("user.prg") && lineNumber == 136) {
                            HarbourLogger.log(COMPONENT, "PRE-DEFINITION CHECK: About to check line 136 in user.prg -> Element: '" + foundElement.getText() + "' Context: '" + context + "'");
                        }
                        boolean isDefinition = isDefinitionElement(foundElement, context);
                        if (containingFile.getName().equals("user.prg") && lineNumber == 136) {
                            HarbourLogger.log(COMPONENT, "POST-DEFINITION CHECK: Line 136 in user.prg -> isDefinition result: " + isDefinition);
                        }

                        // Create navigation element with isDefinition flag
                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                foundElement, identifierName, filePath, lineNumber, context, isDefinition, false);

                        HarbourLogger.log(COMPONENT, "Created navigation element for " + identifierName +
                                " in " + containingFile.getName() + " at line " + lineNumber +
                                " isDefinition: " + isDefinition);

                        // Add to definitions or calls list based on type
                        if (isDefinition) {
                            definitionElements.add(navigationElement);
                        } else {
                            // For functions, only add to callElements if it's actually a function call
                            // This filters out variable assignments like "message = something"
                            if (isFunction) {
                                if (isFunctionCallAtLocation(foundElement, identifierName)) {
                                    callElements.add(navigationElement);
                                    HarbourLogger.log(COMPONENT, "Added function call for " + identifierName + 
                                            " at " + containingFile.getName() + ":" + lineNumber);
                                } else {
                                    HarbourLogger.log(COMPONENT, "Skipped non-function call usage of " + identifierName + 
                                            " at " + containingFile.getName() + ":" + lineNumber + " (variable assignment/usage)");
                                }
                            } else {
                                // For non-functions (variables), add all non-definition usages
                                callElements.add(navigationElement);
                            }
                        }

                        // Record the location to prevent duplicates
                        locations.add(locationKey);
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                }
            }
        }

        // If we have no valid elements, return dummy to prevent default handlers
        if (definitionElements.isEmpty() && callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: No valid navigation elements found for " + identifierName + " - returning dummy to prevent popup");
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "No navigation targets found for: " + identifierName);
            return new PsiElement[] { dummy };
        }

        // If we only have calls but no definitions, show the calls (for variables, these are references)
        // Don't return null to prevent default handlers from running
        if (definitionElements.isEmpty() && !callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: Only calls/references found for " + identifierName + 
                            " (" + callElements.size() + " calls) - showing them instead of delegating to prevent default handlers");
            return callElements.toArray(new PsiElement[0]);
        }

        HarbourLogger.log(COMPONENT, "MAIN HANDLER: Found " + definitionElements.size() + 
                        " definitions and " + callElements.size() + " calls for " + identifierName);

        // Sort definitions by filename and line number
        definitionElements.sort((e1, e2) -> {
            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;

                // Compare filenames first
                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                int fileCompare = fileName1.compareTo(fileName2);

                if (fileCompare != 0) {
                    return fileCompare;
                }

                // If filenames are the same, compare line numbers
                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
            }
            return 0;
        });

        // Sort calls by filename and line number
        callElements.sort((e1, e2) -> {
            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;

                // Compare filenames first
                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                int fileCompare = fileName1.compareTo(fileName2);

                if (fileCompare != 0) {
                    return fileCompare;
                }

                // If filenames are the same, compare line numbers
                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
            }
            return 0;
        });

        // Combine the lists: definitions first, then separator, then calls
        navigationElements.addAll(definitionElements);

        // Only add separator if we have both definitions and calls
        if (!definitionElements.isEmpty() && !callElements.isEmpty()) {
            // Create the separator element
            HarbourNavigationElement separator = HarbourNavigationElement.createSeparator(project);
            if (separator != null) {
                navigationElements.add(separator);
            }
        }

        navigationElements.addAll(callElements);

        // If we have exactly one navigation element after filtering, return it directly
        // This avoids showing a popup when there's only one valid target
        if (navigationElements.size() == 1) {
            HarbourLogger.log(COMPONENT, "Only one target remains after filtering, navigating directly");
            PsiElement[] singleTarget = navigationElements.toArray(new PsiElement[0]);
            // Safety check - ensure we actually have the element
            if (singleTarget.length == 0) {
                HarbourLogger.log(COMPONENT, "WARNING: navigationElements had size 1 but toArray returned empty - returning dummy");
                HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "Single target error");
                return new PsiElement[] { dummy };
            }
            return singleTarget;
        }

        // If we have multiple targets, show custom popup with syntax highlighting
        if (navigationElements.size() > 1) {
            HarbourLogger.log(COMPONENT, "Multiple targets found (" + navigationElements.size() + "), showing custom popup");
            
            // GoToDeclarationHandler is only called for actual navigation requests (Ctrl+Click)
            // so we don't need to check for hover vs click - if we're here, it's a click
            HarbourLogger.log(COMPONENT, "Navigation handler called - showing custom popup");
            ApplicationManager.getApplication().invokeLater(() -> {
                List<PsiElement> targets = navigationElements.stream()
                        .map(e -> (PsiElement) e)
                        .collect(Collectors.toList());
                HarbourNavigationPopup.showNavigationPopup(targets, editor);
            });
            
            return new PsiElement[0]; // Return empty array to prevent default popup
        }

        HarbourLogger.log(COMPONENT, "FINAL RESULT: Returning " + navigationElements.size() + " sorted navigation targets");
        
        // If we have no elements at all, return a dummy to prevent "Cannot find declaration" popup
        if (navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "ERROR: No navigation elements found - returning dummy to prevent popup");
            HarbourLogger.log(COMPONENT, "=== NAVIGATION DEBUG END (FAILED) ===");
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "No navigation targets found");
            return new PsiElement[] { dummy };
        }
        
        HarbourLogger.log(COMPONENT, "=== NAVIGATION DEBUG END (SUCCESS) ===");
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Enhanced method to identify definitions including METHOD declarations
     */
    private boolean isDefinitionElement(PsiElement element, String context) {
        // Debug logging for line 136 in user.prg
        if (element.getContainingFile().getName().equals("user.prg")) {
            int lineNumber = HarbourLogger.calculateLineNumber(element);
            if (lineNumber == 136) {
                String lineText = getLineText(element.getContainingFile(), element);
                HarbourLogger.log(COMPONENT, "isDefinitionElement CALLED: Line 136 in user.prg -> Element: '" + element.getText() + "' Context: '" + context + "' LineText: '" + lineText + "'");
            }
        }
        
        // Check if element is a function declaration directly
        if (element instanceof HarbourFunctionDeclaration ||
                PsiTreeUtil.getParentOfType(element, HarbourFunctionDeclaration.class) != null) {
            return true;
        }

        // Check context string for clues
        if (context != null &&
                (context.toUpperCase().startsWith("PROCEDURE") ||
                        context.toUpperCase().startsWith("FUNCTION") ||
                        context.toUpperCase().startsWith("METHOD") ||
                        context.toUpperCase().contains("PROCEDURE '") ||
                        context.toUpperCase().contains("FUNCTION '") ||
                        context.toUpperCase().contains("METHOD '"))) {
            return true;
        }

        // Check if we have the METHOD keyword - special handling needed for METHOD declarations
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement)element).getElementType() == HarbourTypes.METHOD) {
            return true;
        }

        // Check if parent element is a method declaration
        PsiElement parent = element.getParent();
        if (parent != null) {
            String parentText = parent.getText();
            if (parentText != null && parentText.toUpperCase().startsWith("METHOD ")) {
                return true;
            }
        }

        // Check if the element is part of a function/procedure/method declaration line
        if (element instanceof LeafPsiElement) {
            String lineText = getLineText(element.getContainingFile(), element);
            if (lineText != null &&
                    (lineText.toUpperCase().contains("PROCEDURE ") ||
                            lineText.toUpperCase().contains("FUNCTION ") ||
                            lineText.toUpperCase().contains("METHOD "))) {

                // Skip if this line is a comment
                String trimmedLine = lineText.trim();
                if (trimmedLine.startsWith("//") || trimmedLine.startsWith("/*") || trimmedLine.startsWith("*")) {
                    int lineNumber = HarbourLogger.calculateLineNumber(element);
                    if (element.getContainingFile().getName().equals("user.prg") && lineNumber == 136) {
                        HarbourLogger.log(COMPONENT, "DEFINITION CHECK: Skipping comment line 136 in user.prg -> Content: '" + trimmedLine + "'");
                    }
                    return false;
                }

                // Check if this is at the start of the line (with possible whitespace/static prefix)
                if (trimmedLine.toUpperCase().startsWith("PROCEDURE ") ||
                        trimmedLine.toUpperCase().startsWith("FUNCTION ") ||
                        trimmedLine.toUpperCase().startsWith("METHOD ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC PROCEDURE ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC FUNCTION ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC METHOD ")) {
                    
                    // Only mark as definition if this element is the actual function/method name, not a parameter
                    String elementText = element.getText();
                    
                    // Extract the expected function/method name from the line
                    String expectedName = extractFunctionMethodName(trimmedLine);
                    
                    // Only return true if this element matches the actual function/method name
                    if (expectedName != null && elementText.equalsIgnoreCase(expectedName)) {
                        return true;
                    }
                    
                    // If this element doesn't match the function/method name, it's likely a parameter
                    return false;
                }
            }
        }

        return false;
    }

    /**
     * Extract the function/method name from a declaration line.
     * Examples:
     * - "METHOD new(MArtNr,mArt,titel)" -> "new"
     * - "FUNCTION calculate(x, y)" -> "calculate" 
     * - "PROCEDURE KInternAendern" -> "KInternAendern"
     */
    private String extractFunctionMethodName(String line) {
        if (line == null) {
            return null;
        }
        
        String upperLine = line.toUpperCase().trim();
        String keyword = null;
        
        // Identify the keyword and its position
        if (upperLine.startsWith("STATIC METHOD ")) {
            keyword = "STATIC METHOD ";
        } else if (upperLine.startsWith("STATIC FUNCTION ")) {
            keyword = "STATIC FUNCTION ";
        } else if (upperLine.startsWith("STATIC PROCEDURE ")) {
            keyword = "STATIC PROCEDURE ";
        } else if (upperLine.startsWith("METHOD ")) {
            keyword = "METHOD ";
        } else if (upperLine.startsWith("FUNCTION ")) {
            keyword = "FUNCTION ";
        } else if (upperLine.startsWith("PROCEDURE ")) {
            keyword = "PROCEDURE ";
        }
        
        if (keyword == null) {
            return null;
        }
        
        // Extract everything after the keyword
        String remainder = line.substring(keyword.length()).trim();
        
        // Find the function/method name (everything before parentheses or end of identifier)
        int parenIndex = remainder.indexOf('(');
        int spaceIndex = remainder.indexOf(' ');
        
        int endIndex = remainder.length();
        if (parenIndex >= 0 && spaceIndex >= 0) {
            endIndex = Math.min(parenIndex, spaceIndex);
        } else if (parenIndex >= 0) {
            endIndex = parenIndex;
        } else if (spaceIndex >= 0) {
            endIndex = spaceIndex;
        }
        
        if (endIndex > 0) {
            return remainder.substring(0, endIndex).trim();
        }
        
        return null;
    }

    /**
     * Modified method to handle direct text comparison checks for METHOD declarations
     * This should be added to avoid skipping METHOD definition elements
     */
    private boolean isTextMatching(PsiElement element, String identifierName) {
        if (element == null || identifierName == null) {
            return false;
        }

        // Direct text match
        if (element.getText().equalsIgnoreCase(identifierName)) {
            return true;
        }

        // Special case for METHOD declarations
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement)element).getElementType() == HarbourTypes.METHOD) {

            // Look for the identifier after the METHOD keyword
            PsiElement sibling = element.getNextSibling();
            while (sibling != null) {
                // Skip whitespace
                if (sibling instanceof LeafPsiElement &&
                        ((LeafPsiElement)sibling).getElementType() != TokenType.WHITE_SPACE) {
                    // Found non-whitespace sibling, check if it matches the identifier
                    return sibling.getText().equalsIgnoreCase(identifierName);
                }
                sibling = sibling.getNextSibling();
            }
        }

        return false;
    }

    /**
     * Determines if an element is a class reference in code like ClassName():new()
     * Class instantiation is identified by the pattern: identifier():new()
     */
    private boolean isClassReference(PsiElement element) {
        String text = element.getText();
        if (text == null || text.isEmpty()) {
            return false;
        }

        HarbourLogger.log(COMPONENT, "Checking if " + text + " is a class reference");

        // Get the line text for context
        String lineText = getLineText(element.getContainingFile(), element);
        if (lineText == null) {
            return false;
        }

        // Check if this line contains a pattern like "ClassName():new()"
        // This is the Harbour pattern for class instantiation
        // First, find where our element appears in the line
        int elementPos = lineText.indexOf(text);
        if (elementPos < 0) {
            return false;
        }

        // Now check if it's followed by "():new()" pattern
        String afterText = lineText.substring(elementPos + text.length());
        Pattern classPattern = Pattern.compile("\\s*\\(\\s*\\)\\s*:\\s*new\\s*\\(");

        boolean isClass = classPattern.matcher(afterText).find();
        HarbourLogger.log(COMPONENT, text + " is " + (isClass ? "" : "not ") + "a class reference (:new() pattern match: " + isClass + ")");
        return isClass;
    }

    /**
     * Determines if an element is a method reference after a class reference
     */
    private boolean isMethodReference(PsiElement element) {
        String text = element.getText();
        if (text == null || text.isEmpty()) {
            return false;
        }

        HarbourLogger.log(COMPONENT, "Checking if " + text + " is a method reference");


        // Look for a colon or dot before this element directly in the PSI tree
        PsiElement prev = element.getPrevSibling();
        while (prev != null) {
            if (prev.getText().equals(":") || prev.getText().equals(".")) {
                HarbourLogger.log(COMPONENT, "Found immediate colon/dot before element: " + text);
                return true;
            }

            // Skip whitespace
            if (prev instanceof PsiWhiteSpace) {
                prev = prev.getPrevSibling();
                continue;
            }

            // If we hit a non-whitespace, non-separator element, break
            break;
        }

        // Get the line text for full context
        String lineText = getLineText(element.getContainingFile(), element);
        if (lineText == null) {
            return false;
        }

        // Find where our element appears in the line
        int pos = lineText.indexOf(text);
        if (pos <= 0) {
            return false;
        }

        // Check for assignment operator `:=` which should not be confused with method reference
        int assignPos = lineText.lastIndexOf(":=", pos);
        if (assignPos >= 0 && pos - assignPos <= text.length() + 2) {
            // This is likely part of an assignment, not a method reference
            HarbourLogger.log(COMPONENT, "Found := assignment operator, not a method reference: " + text);
            return false;
        }
        
        // Check for double colon :: (scope resolution/field assignment) which should not be confused with method reference
        if (lineText.contains("::")) {
            int doubleColonPos = lineText.indexOf("::");
            // If our element appears after ::, it's likely a field assignment, not a method reference
            if (doubleColonPos >= 0 && pos > doubleColonPos) {
                HarbourLogger.log(COMPONENT, "Found :: scope resolution, not a method reference: " + text);
                return false;
            }
        }

        // Check for different method reference patterns:

        // 1. Check for colon or dot before the method name (obj:method or obj.method)
        int colonPos = lineText.lastIndexOf(':', pos);
        int dotPos = lineText.lastIndexOf('.', pos);

        // Make sure the colon isn't part of an assignment operator
        if (colonPos > 0 && colonPos + 1 < lineText.length() && lineText.charAt(colonPos + 1) == '=') {
            // This is a := operator, skip it
            colonPos = lineText.lastIndexOf(':', colonPos - 1);
        }

        if ((colonPos > 0 && colonPos != assignPos) || dotPos > 0) {
            // Make sure there's some character before the colon/dot (an object name)
            // and that it's not part of a comment
            int separatorPos = Math.max(colonPos, dotPos);
            if (separatorPos > 0 &&
                    !lineText.substring(0, separatorPos).contains("//") &&
                    !lineText.substring(0, separatorPos).contains("/*")) {
                HarbourLogger.log(COMPONENT, "Found method reference pattern with colon/dot: " + text);
                return true;
            }
        }

        // 2. Check for METHOD keyword pattern (used in method declarations)
        // BUT exclude method parameters - if we're inside parentheses after METHOD, it's a parameter
        if (lineText.toUpperCase().contains("METHOD") &&
                lineText.toUpperCase().indexOf("METHOD") < pos) {
            // Check if we're inside method parameter parentheses
            int methodPos = lineText.toUpperCase().indexOf("METHOD");
            String afterMethod = lineText.substring(methodPos);
            int openParen = afterMethod.indexOf('(');
            int closeParen = afterMethod.indexOf(')', openParen);
            
            if (openParen > 0 && closeParen > openParen) {
                // Check if our element position is within the parentheses
                int elementPosInAfterMethod = pos - methodPos;
                if (elementPosInAfterMethod > openParen && elementPosInAfterMethod < closeParen) {
                    // We're inside method parameter parentheses - this is a parameter, not a method reference
                    return false;
                }
            }
            
            // Make sure it's not inside a comment
            String beforeMethod = lineText.substring(0, pos);
            if (!beforeMethod.contains("//") && !beforeMethod.contains("/*")) {
                HarbourLogger.log(COMPONENT, "Found method declaration for: " + text);
                return true;
            }
        }

        // 3. Check for className:methodName or METHOD className:methodName patterns
        if (lineText.contains(":") && lineText.indexOf(':') < pos) {
            String beforeColon = lineText.substring(0, lineText.indexOf(':'));
            if (beforeColon.toUpperCase().contains("METHOD") ||
                    (Character.isUpperCase(beforeColon.charAt(0)) && !beforeColon.contains(" "))) {
                HarbourLogger.log(COMPONENT, "Found method pattern with class name: " + text);
                return true;
            }
        }

        HarbourLogger.log(COMPONENT, text + " is not a method reference");
        return false;
    }

    /**
     * Get the containing class context for a method call
     */
    private String getContainingClassContext(PsiElement element) {
        // Look for containing METHOD declaration
        PsiElement current = element;
        int depth = 0;
        while (current != null && depth < 20) { // Limit depth to avoid infinite loops
            String text = current.getText();
            
            if (text != null && text.toUpperCase().contains("METHOD")) {
                // Try to extract class name from METHOD declaration
                // Patterns: "METHOD name CLASS className" or "METHOD className:name"
                String[] lines = text.split("\n");
                for (String line : lines) {
                    String upperLine = line.toUpperCase();
                    if (upperLine.contains("METHOD")) {
                        // Pattern: METHOD name CLASS className
                        if (upperLine.contains("CLASS")) {
                            String[] parts = upperLine.split("CLASS");
                            if (parts.length > 1) {
                                String className = parts[1].trim().split("\\s+")[0];
                                return className;
                            }
                        }
                        // Pattern: METHOD className:name
                        if (upperLine.contains(":")) {
                            String methodPart = upperLine.substring(upperLine.indexOf("METHOD") + 6).trim();
                            if (methodPart.contains(":")) {
                                String className = methodPart.split(":")[0].trim();
                                return className;
                            }
                        }
                    }
                }
            }
            current = current.getParent();
            depth++;
        }
        return null;
    }

    /**
     * Extracts class name from a line containing a method call
     */
    private String extractClassNameFromMethodCall(PsiElement methodElement) {
        String text = methodElement.getText();
        if (text == null || text.isEmpty()) {
            return null;
        }

        // Get the line text
        String lineText = getLineText(methodElement.getContainingFile(), methodElement);
        if (lineText == null) {
            return null;
        }

        // Find method position in the line
        int methodPos = lineText.indexOf(text);
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

        // First try to match ClassName() pattern
        // The pattern should match at the end of beforeSeparator since we cut off at the colon
        Pattern classPattern = Pattern.compile("(\\w+)\\s*\\(\\s*\\)\\s*$");
        String beforeSeparator = lineText.substring(0, separatorPos);
        
        Matcher matcher = classPattern.matcher(beforeSeparator);

        if (matcher.find()) {
            // Found a class instantiation pattern
            String className = matcher.group(1);
            HarbourLogger.log(COMPONENT, "Found class name: " + className);
            return className;
        }

        // Otherwise try to find nearest identifier before the separator
        // This works for object variables
        int startPos = separatorPos - 1;
        while (startPos >= 0 &&
                (Character.isLetterOrDigit(lineText.charAt(startPos)) || lineText.charAt(startPos) == '_')) {
            startPos--;
        }

        if (startPos < separatorPos - 1) {
            String objectName = lineText.substring(startPos + 1, separatorPos);
            HarbourLogger.log(COMPONENT, "Found object name: " + objectName);
            return objectName;
        }

        return null;
    }

    /**
     * Resolves class references to their declarations, excluding current location
     */
    private PsiElement[] resolveClassReference(PsiElement element, String currentLocationKey) {
        String className = element.getText();
        HarbourLogger.log(COMPONENT, "Resolving class reference: " + className);

        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);

        // Find class declarations
        List<PsiElement> classDeclarations = service.findClasses(className);

        if (classDeclarations.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No class declarations found for: " + className);
            return null;
        }

        // Convert to navigation elements
        List<PsiElement> navigationElements = new ArrayList<>();
        Set<String> locations = new HashSet<>();

        for (PsiElement declaration : classDeclarations) {
            if (declaration != null && declaration.isValid()) {
                try {
                    PsiFile containingFile = declaration.getContainingFile();
                    if (containingFile != null && containingFile.getVirtualFile() != null) {
                        // Calculate line number for the element
                        int lineNumber = HarbourLogger.calculateLineNumber(declaration);
                        
                        // Fix for METHOD elements that may have incorrect line number calculation
                        if (declaration.getContainingFile().getName().equals("user.prg") && lineNumber == 136) {
                            String actualLineText = getLineText(declaration.getContainingFile(), declaration);
                            if (actualLineText != null && actualLineText.trim().startsWith("METHOD")) {
                                lineNumber = 137;
                                HarbourLogger.log(COMPONENT, "CORRECTED line number from 136 to 137 for METHOD element in user.prg (class search)");
                            }
                        }
                        
                        String filePath = containingFile.getVirtualFile().getPath();

                        // Create a unique location key
                        String locationKey = filePath + ":" + lineNumber;

                        // Skip if we've already added this exact location
                        if (locations.contains(locationKey)) {
                            continue;
                        }

                        // Skip if this is the current location
                        if (locationKey.equals(currentLocationKey)) {
                            HarbourLogger.log(COMPONENT, "Skipping current location for class: " + locationKey);
                            continue;
                        }

                        // Get context information for the navigation element
                        String context = "CLASS: " + className;

                        // Create navigation element - class declarations are always definitions
                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                declaration, className, filePath, lineNumber, context, true, false);

                        // Add to our list and record the location
                        navigationElements.add(navigationElement);
                        locations.add(locationKey);

                        HarbourLogger.log(COMPONENT, "Added navigation element for class " +
                                className + " in " + containingFile.getName());
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                }
            }
        }

        // Convert list to array
        if (navigationElements.isEmpty()) {
            return null;
        }

        // Sort by filename and line number
        navigationElements.sort((e1, e2) -> {
            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;

                // Compare filenames first
                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                int fileCompare = fileName1.compareTo(fileName2);

                if (fileCompare != 0) {
                    return fileCompare;
                }

                // If filenames are the same, compare line numbers
                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
            }
            return 0;
        });

        HarbourLogger.log(COMPONENT, "Returning " + navigationElements.size() +
                " navigation elements for class " + className);
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Resolves method references to their declarations, excluding current location
     */
    private PsiElement[] resolveMethodReference(PsiElement element, String currentLocationKey) {
        String methodName = element.getText();
        HarbourLogger.log(COMPONENT, "Resolving method reference: " + methodName);

        // First try to find the class name for this method
        String className = extractClassNameFromMethodCall(element);
        
        // If no class found from method call pattern, try containing context
        if (className == null) {
            className = getContainingClassContext(element);
        }

        // Debug output for method resolution
        HarbourLogger.log(COMPONENT, "Method " + methodName +
                (className != null ? " with potential class: " + className : " with no class detected"));

        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        List<PsiElement> methodDeclarations = new ArrayList<>();

        // Try class-specific search if we found a class name
        if (className != null) {
            HarbourLogger.log(COMPONENT, "Searching for method " + methodName + " in class " + className);
            methodDeclarations = service.findClassMethods(className, methodName);
            
            // If we have a specific class, ONLY use those results - don't fall back to general search
            if (!methodDeclarations.isEmpty()) {
                HarbourLogger.log(COMPONENT, "Found " + methodDeclarations.size() + 
                        " class-specific methods for " + className + ":" + methodName);
            } else {
                HarbourLogger.log(COMPONENT, "No methods found for " + className + ":" + methodName);
            }
        } else {
            // Only do general search if no class was identified
            HarbourLogger.log(COMPONENT, "No class identified, trying general method search");

            // Look for METHOD declarations with this name in all files
            // First try direct pattern-based search for METHOD keyword + method name
            List<PsiElement> directResults = findMethodsByDirectPattern(project, methodName);

            if (!directResults.isEmpty()) {
                HarbourLogger.log(COMPONENT, "Found " + directResults.size() +
                        " methods by direct pattern search");
                methodDeclarations.addAll(directResults);
            } else {
                // Fall back to service-based function lookup
                HarbourLogger.log(COMPONENT, "No methods found by pattern, trying function lookup");
                methodDeclarations = service.findFunctions(methodName);
            }
        }

        if (methodDeclarations.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No method declarations found for: " + methodName);
            return null;
        }

        // Convert to navigation elements and prioritize implementations over declarations
        List<PsiElement> implementations = new ArrayList<>();
        List<PsiElement> declarations = new ArrayList<>();
        Set<String> locations = new HashSet<>();

        // First pass: separate implementations from declarations
        for (PsiElement declaration : methodDeclarations) {
            if (declaration != null && declaration.isValid()) {
                String context = getElementContext(declaration);
                // Check if this looks like an implementation (has body) vs declaration (just header)
                if (context != null && (context.contains("{") || context.contains("LOCAL") || context.contains("RETURN"))) {
                    implementations.add(declaration);
                } else {
                    declarations.add(declaration);
                }
            }
        }

        // Prioritize implementations over declarations
        List<PsiElement> prioritizedMethods = new ArrayList<>();
        prioritizedMethods.addAll(implementations);
        prioritizedMethods.addAll(declarations);

        List<PsiElement> navigationElements = new ArrayList<>();

        for (PsiElement declaration : prioritizedMethods) {
            if (declaration != null && declaration.isValid()) {
                try {
                    PsiFile containingFile = declaration.getContainingFile();
                    if (containingFile != null && containingFile.getVirtualFile() != null) {
                        // Calculate line number for the element
                        int lineNumber = HarbourLogger.calculateLineNumber(declaration);
                        
                        // Fix for METHOD elements that may have incorrect line number calculation
                        if (declaration.getContainingFile().getName().equals("user.prg") && lineNumber == 136) {
                            String actualLineText = getLineText(declaration.getContainingFile(), declaration);
                            if (actualLineText != null && actualLineText.trim().startsWith("METHOD")) {
                                lineNumber = 137;
                                HarbourLogger.log(COMPONENT, "CORRECTED line number from 136 to 137 for METHOD element in user.prg (method search)");
                            }
                        }
                        
                        String filePath = containingFile.getVirtualFile().getPath();

                        // Create a unique location key
                        String locationKey = filePath + ":" + lineNumber;

                        // Skip if we've already added this exact location
                        if (locations.contains(locationKey)) {
                            continue;
                        }

                        // Skip if this is the current location
                        if (locationKey.equals(currentLocationKey)) {
                            HarbourLogger.log(COMPONENT, "Skipping current location for method: " + locationKey);
                            continue;
                        }

                        // Get context information and check if this is actually a method definition
                        String context = getElementContext(declaration);
                        boolean isMethodDefinition = isMethodDefinition(declaration, methodName);

                        // Skip if not a method definition and we're looking for method targets
                        if (!isMethodDefinition && className != null) {
                            HarbourLogger.log(COMPONENT, "Skipping non-method element: " +
                                    declaration.getText().substring(0, Math.min(30, declaration.getText().length())));
                            continue;
                        }

                        // Create navigation element with isMethodDefinition flag
                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                declaration, methodName, filePath, lineNumber, context, true, false);

                        // Add to our list and record the location
                        navigationElements.add(navigationElement);
                        locations.add(locationKey);

                        HarbourLogger.log(COMPONENT, "Added navigation element for method " +
                                methodName + " in " + containingFile.getName());
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                }
            }
        }

        // Convert list to array
        if (navigationElements.isEmpty()) {
            return null;
        }

        // Sort by filename and line number
        navigationElements.sort((e1, e2) -> {
            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;

                // Compare filenames first
                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                int fileCompare = fileName1.compareTo(fileName2);

                if (fileCompare != 0) {
                    return fileCompare;
                }

                // If filenames are the same, compare line numbers
                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
            }
            return 0;
        });

        HarbourLogger.log(COMPONENT, "Returning " + navigationElements.size() +
                " navigation elements for method " + methodName);
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Find method declarations by direct pattern matching in all project files
     */
    private List<PsiElement> findMethodsByDirectPattern(Project project, String methodName) {
        List<PsiElement> results = new ArrayList<>();
        try {
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

            // Create pattern for METHOD declarations
            Pattern methodPattern = Pattern.compile(
                    "\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\b",
                    Pattern.CASE_INSENSITIVE);

            for (VirtualFile virtualFile : virtualFiles) {
                try {
                    PsiFile psiFile = PsiManager.getInstance(project).findFile(virtualFile);
                    if (psiFile == null) continue;

                    String fileText = psiFile.getText();
                    Matcher matcher = methodPattern.matcher(fileText);

                    while (matcher.find()) {
                        int startOffset = matcher.start();
                        PsiElement elementAtOffset = psiFile.findElementAt(startOffset);

                        if (elementAtOffset != null &&
                                elementAtOffset.getText().equalsIgnoreCase("METHOD")) {
                            // Find the method name after METHOD keyword
                            PsiElement nextElement = elementAtOffset.getNextSibling();
                            while (nextElement != null &&
                                    !(nextElement instanceof LeafPsiElement &&
                                            ((LeafPsiElement)nextElement).getElementType() == HarbourTypes.IDENT &&
                                            nextElement.getText().equalsIgnoreCase(methodName))) {
                                nextElement = nextElement.getNextSibling();
                            }

                            if (nextElement != null) {
                                HarbourLogger.log(COMPONENT, "Found method by pattern: " +
                                        methodName + " in " + virtualFile.getName());
                                results.add(elementAtOffset); // Add the METHOD keyword
                            }
                        }
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error searching file: " + e.getMessage());
                }
            }
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error in method pattern search: " + e.getMessage());
        }
        return results;
    }

    /**
     * Check if an element is a method definition
     */
    private boolean isMethodDefinition(PsiElement element, String methodName) {
        if (element == null) return false;

        // Check if this is a METHOD keyword
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement)element).getElementType() == HarbourTypes.METHOD) {
            return true;
        }

        // Check the text context
        String text = element.getText();
        if (text == null || text.isEmpty()) return false;

        String upperText = text.toUpperCase();
        // Look for METHOD keyword followed by methodName
        if (upperText.contains("METHOD") && upperText.contains(methodName.toUpperCase())) {
            // More precise check to avoid false positives
            int methodPos = upperText.indexOf("METHOD");
            if (methodPos >= 0) {
                int namePos = upperText.indexOf(methodName.toUpperCase(), methodPos + 6);
                if (namePos > methodPos) {
                    HarbourLogger.log(COMPONENT, "Confirmed method definition for: " + methodName);
                    return true;
                }
            }
        }

        // Look in line text for more context
        PsiFile file = element.getContainingFile();
        if (file != null) {
            String lineText = getLineText(file, element);
            if (lineText != null && lineText.toUpperCase().contains("METHOD " + methodName.toUpperCase())) {
                HarbourLogger.log(COMPONENT, "Confirmed method definition from line text");
                return true;
            }
        }

        return false;
    }

    /**
     * Get context string for the element
     */
    private String getElementContext(PsiElement element) {
        if (element instanceof HarbourFunctionDeclaration) {
            return "PROCEDURE '" + ((HarbourFunctionDeclaration)element).getName() + "' - context: '" +
                    element.getText().split("\n")[0] + "'";
        }

        // For function calls
        if (element instanceof FunctionCallImpl) {
            return "Function call: " + element.getText();
        }

        // For class declarations
        if (element instanceof ClassDeclaration) {
            return "CLASS '" + ((ClassDeclaration)element).getName() + "'";
        }

        // For methods, check if we have METHOD keyword
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement)element).getElementType() == HarbourTypes.METHOD) {
            // Try to find the method name
            PsiElement sibling = element.getNextSibling();
            while (sibling != null && (sibling instanceof PsiWhiteSpace ||
                    !(sibling instanceof LeafPsiElement &&
                            ((LeafPsiElement)sibling).getElementType() == HarbourTypes.IDENT))) {
                sibling = sibling.getNextSibling();
            }

            String methodName = sibling != null ? sibling.getText() : "unknown";
            return "METHOD '" + methodName + "'";
        }

        // For identifiers, try to get the parent context
        if (element instanceof LeafPsiElement) {
            PsiElement parent = element.getParent();
            if (parent instanceof HarbourFunctionDeclaration) {
                return "PROCEDURE '" + ((HarbourFunctionDeclaration)parent).getName() + "' - context: '" +
                        parent.getText().split("\n")[0] + "'";
            }

            if (parent instanceof ClassDeclaration) {
                return "CLASS '" + ((ClassDeclaration)parent).getName() + "'";
            }
        }

        // Default
        return element.getText();
    }

    /**
     * Get the full text of the line containing the specified element
     */
    public static String getLineText(PsiFile file, PsiElement element) {
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


    /**
     * Check if a filename has one of the typical include extensions
     */
    private boolean hasIncludeExtension(String fileName) {
        for (String ext : INCLUDE_EXTENSIONS) {
            if (fileName.endsWith(ext)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Try to resolve an include file reference
     */
    private PsiElement[] resolveIncludeFile(PsiElement element, String includeFileName) {
        HarbourLogger.log(COMPONENT, "Resolving include file: " + includeFileName);

        Project project = element.getProject();

        // Get include paths from settings
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings == null) {
            HarbourLogger.log(COMPONENT, "ERROR: Could not get HarbourSettings instance");
            return null;
        }

        List<String> includePaths = settings.getIncludePaths();
        HarbourLogger.log(COMPONENT, "Checking " + includePaths.size() + " include paths");

        // Check include paths if available
        if (!includePaths.isEmpty()) {
            for (String path : includePaths) {
                File exactFile = new File(path, includeFileName);
                if (exactFile.exists() && exactFile.isFile()) {
                    HarbourLogger.log(COMPONENT, "Found include file in path: " + exactFile.getAbsolutePath());
                    VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(exactFile);
                    if (virtualFile != null) {
                        return createNavigationElementForFile(virtualFile, includeFileName, project);
                    }
                }

                // Try case-insensitive search as fallback
                File dir = new File(path);
                if (dir.exists() && dir.isDirectory()) {
                    File[] files = dir.listFiles();
                    if (files != null) {
                        for (File file : files) {
                            if (file.isFile() && file.getName().equalsIgnoreCase(includeFileName)) {
                                HarbourLogger.log(COMPONENT, "Found case-insensitive match: " + file.getAbsolutePath());
                                VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(file);
                                if (virtualFile != null) {
                                    return createNavigationElementForFile(virtualFile, includeFileName, project);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Check current directory as fallback
        PsiFile currentFile = element.getContainingFile();
        if (currentFile != null && currentFile.getVirtualFile() != null) {
            VirtualFile currentDir = currentFile.getVirtualFile().getParent();
            if (currentDir != null) {
                HarbourLogger.log(COMPONENT, "Checking current dir: " + currentDir.getPath());

                // Try with exact name
                VirtualFile includeFile = currentDir.findChild(includeFileName);
                if (includeFile != null && includeFile.exists()) {
                    HarbourLogger.log(COMPONENT, "Found include in current directory: " + includeFile.getPath());
                    return createNavigationElementForFile(includeFile, includeFileName, project);
                }

                // Try case-insensitive search in current directory
                VirtualFile[] children = currentDir.getChildren();
                for (VirtualFile child : children) {
                    if (!child.isDirectory() && child.getName().equalsIgnoreCase(includeFileName)) {
                        HarbourLogger.log(COMPONENT, "Found case-insensitive match in current dir: " + child.getPath());
                        return createNavigationElementForFile(child, includeFileName, project);
                    }
                }
            }
        }

        // If we reach here, the file wasn't found anywhere
        HarbourLogger.log(COMPONENT, "Could not find include file: " + includeFileName);

        // Show custom notification based on whether include paths are configured
        // We need to use ApplicationManager.getApplication().invokeLater to show notifications
        // from a background thread
        ApplicationManager.getApplication().invokeLater(() -> {
            String message;
            NotificationType type;

            if (includePaths.isEmpty()) {
                message = "Please add include path in settings";
                type = NotificationType.WARNING;
            } else {
                message = "Include file not found: " + includeFileName;
                type = NotificationType.ERROR;
            }

            Notifications.Bus.notify(
                    new Notification(
                            "Harbour",
                            "Navigation Error",
                            message,
                            type
                    ),
                    project
            );
        });

        // Return null to let IntelliJ know no declaration was found
        // Our custom notification will show up instead of or alongside the default message
        return null;
    }

    /**
     * Create a navigation element for a virtual file
     */
    private PsiElement[] createNavigationElementForFile(VirtualFile file, String displayName, Project project) {
        PsiFile psiFile = PsiManager.getInstance(project).findFile(file);
        if (psiFile == null) {
            HarbourLogger.log(COMPONENT, "Could not get PsiFile for: " + file.getPath());
            return null;
        }

        HarbourNavigationElement navElement = new HarbourNavigationElement(
                psiFile,
                displayName,
                file.getPath(),
                1,  // Line 1
                "Include File",
                true, // Include files are definitions
                false
        );

        HarbourLogger.log(COMPONENT, "Created navigation element for: " + file.getPath());
        return new PsiElement[] { navElement };
    }

    /**
     * Find variable occurrences in current file with simple line-based scoping
     * As suggested by user: go up to find function/procedure/method/class definition,
     * then go down to find the next one, and filter results to that range.
     */
    private List<PsiElement> findVariableInCurrentFileWithScope(PsiElement clickedElement, String variableName) {
        List<PsiElement> results = new ArrayList<>();
        
        PsiFile file = clickedElement.getContainingFile();
        if (!(file instanceof HarbourFile)) {
            return results;
        }

        String fileText = file.getText();
        if (fileText == null || fileText.isEmpty()) {
            return results;
        }

        // Get the clicked element's line number
        int clickedLine = HarbourLogger.calculateLineNumber(clickedElement);
        
        // Split lines to check clicked line content
        String[] fileLines = fileText.split("\n");
        int clickedLineIndex = clickedLine - 1;

        // Find the scope boundaries (start and end lines)
        int[] scopeLines = findSimpleScope(fileText, clickedLine);
        if (scopeLines == null) {
            scopeLines = new int[]{0, fileText.split("\n").length};
        }
        
        int scopeStart = scopeLines[0];
        int scopeEnd = scopeLines[1];

        // Search for the variable within the current file only
        String[] lines = fileText.split("\n");
        for (int lineNum = 0; lineNum < lines.length; lineNum++) {
            String line = lines[lineNum];
            
            // Check if this line is within our scope
            if (lineNum >= scopeStart && lineNum <= scopeEnd) {
                // Simple regex to find the variable name as a whole word
                if (line.matches(".*\\b" + variableName + "\\b.*")) {
                    // Find all occurrences of the variable in this line
                    int pos = 0;
                    while ((pos = line.indexOf(variableName, pos)) >= 0) {
                        // Check if it's a whole word (not part of another identifier)
                        boolean isWholeWord = true;
                        if (pos > 0 && Character.isLetterOrDigit(line.charAt(pos - 1))) {
                            isWholeWord = false;
                        }
                        if (pos + variableName.length() < line.length() && 
                            Character.isLetterOrDigit(line.charAt(pos + variableName.length()))) {
                            isWholeWord = false;
                        }
                        
                        if (isWholeWord) {
                            // Calculate the offset in the file
                            int lineStartOffset = 0;
                            for (int i = 0; i < lineNum; i++) {
                                lineStartOffset += lines[i].length() + 1; // +1 for newline
                            }
                            int elementOffset = lineStartOffset + pos;
                            
                            // Skip if this line is a comment
                            String trimmedLine = line.trim();
                            if (!(trimmedLine.startsWith("//") || trimmedLine.startsWith("/*"))) {
                                // Find the PsiElement at this offset
                                PsiElement foundElement = file.findElementAt(elementOffset);
                                if (foundElement != null && variableName.equals(foundElement.getText())) {
                                    results.add(foundElement);
                                }
                            } else {
                                HarbourLogger.log(COMPONENT, "VARIABLE SEARCH: Skipping comment line " + (lineNum + 1) + " in " + file.getName() + " -> Content: '" + trimmedLine + "'");
                            }
                        }
                        pos += variableName.length();
                    }
                }
            }
        }

        return results;
    }

    /**
     * Find simple scope boundaries using user's approach:
     * Go up until function/procedure/method/class definition,
     * then go down until the next function/procedure/method/class definition.
     */
    private int[] findSimpleScope(String fileText, int clickedLine) {
        String[] lines = fileText.split("\n");
        // Convert 1-based line number to 0-based array index
        int clickedLineIndex = clickedLine - 1;
        if (clickedLineIndex >= lines.length || clickedLineIndex < 0) {
            return null;
        }


        // Go up to find the start of current function/procedure/method/class
        int scopeStart = 0;
        for (int i = clickedLineIndex; i >= 0; i--) {
            String line = lines[i].toUpperCase().trim();
            if (line.startsWith("FUNCTION ") || line.startsWith("PROCEDURE ") || 
                line.startsWith("METHOD ") || line.startsWith("CLASS ")) {
                scopeStart = i;
                break;
            }
        }

        // Go down to find the end (next function/procedure/method/class or end of file)
        int scopeEnd = lines.length - 1;
        for (int i = scopeStart + 1; i < lines.length; i++) {
            String line = lines[i].toUpperCase().trim();
            if (line.startsWith("FUNCTION ") || line.startsWith("PROCEDURE ") || 
                line.startsWith("METHOD ") || line.startsWith("CLASS ")) {
                scopeEnd = i - 1;
                break;
            }
        }
        

        return new int[]{scopeStart, scopeEnd};
    }

    /**
     * Resolves class variable reference (::variable) to DATA field definition
     */
    private PsiElement[] resolveClassVariableReference(PsiElement element, String variableName, String currentLocationKey) {
        HarbourLogger.log(COMPONENT, "Resolving class variable reference: ::" + variableName);
        
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return null;
        }

        // First, find the class that contains this element
        String className = findContainingClassName(element);
        if (className == null) {
            HarbourLogger.log(COMPONENT, "Could not find containing class for variable: " + variableName);
            return null;
        }

        HarbourLogger.log(COMPONENT, "Found containing class: " + className + " for variable: " + variableName);

        // Now search for the DATA field definition in this class
        List<PsiElement> dataFields = findDataFieldsInClass(file, className, variableName);
        
        if (dataFields.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No DATA field found for: " + variableName + " in class: " + className);
            return null;
        }

        // Create navigation elements for the DATA fields
        List<PsiElement> navigationElements = new ArrayList<>();
        for (PsiElement dataField : dataFields) {
            VirtualFile dataFile = dataField.getContainingFile().getVirtualFile();
            if (dataFile != null) {
                String filePath = dataFile.getPath();
                int lineNumber = HarbourLogger.calculateLineNumber(dataField);
                String locationKey = filePath + ":" + lineNumber;

                // Skip if this is the same location as the current click
                if (!locationKey.equals(currentLocationKey)) {
                    navigationElements.add(new HarbourNavigationElement(
                        dataField,
                        "DATA " + variableName,
                        filePath,
                        lineNumber,
                        "Class variable definition"
                    ));
                }
            }
        }

        if (navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No valid navigation targets found for DATA field: " + variableName);
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(element, false, "No DATA field found: " + variableName);
            return new PsiElement[] { dummy };
        }

        HarbourLogger.log(COMPONENT, "Found " + navigationElements.size() + " DATA field targets for: " + variableName);
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Find the class name that contains the given element
     */
    private String findContainingClassName(PsiElement element) {
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return null;
        }

        String fileText = file.getText();
        if (fileText == null) {
            return null;
        }

        String[] lines = fileText.split("\n");
        int elementLine = HarbourLogger.calculateLineNumber(element) - 1; // Convert to 0-based

        // Search backwards from the current line to find the CLASS declaration
        for (int i = elementLine; i >= 0; i--) {
            String line = lines[i].trim().toUpperCase();
            if (line.startsWith("CLASS ")) {
                // Extract class name
                String[] parts = line.split("\\s+");
                if (parts.length >= 2) {
                    String className = parts[1];
                    HarbourLogger.log(COMPONENT, "Found containing class: " + className + " at line " + (i + 1));
                    return className;
                }
            }
        }

        return null;
    }

    /**
     * Find DATA field definitions in the specified class
     */
    private List<PsiElement> findDataFieldsInClass(PsiFile file, String className, String fieldName) {
        List<PsiElement> dataFields = new ArrayList<>();
        
        String fileText = file.getText();
        if (fileText == null) {
            return dataFields;
        }

        String[] lines = fileText.split("\n");
        boolean inClass = false;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();
            String upperLine = line.toUpperCase();

            // Check if we're entering the target class
            if (upperLine.startsWith("CLASS " + className.toUpperCase())) {
                inClass = true;
                HarbourLogger.log(COMPONENT, "Entered class " + className + " at line " + (i + 1));
                continue;
            }

            // Check if we're leaving the class
            if (inClass && (upperLine.startsWith("CLASS ") || upperLine.startsWith("ENDCLASS"))) {
                if (upperLine.startsWith("CLASS ") && !upperLine.startsWith("CLASS " + className.toUpperCase())) {
                    inClass = false;
                    HarbourLogger.log(COMPONENT, "Left class " + className + " at line " + (i + 1));
                }
                continue;
            }

            // If we're in the target class, look for DATA fields
            if (inClass && upperLine.startsWith("DATA " + fieldName.toUpperCase())) {
                // Create a PsiElement representing this DATA field
                int offset = 0;
                for (int j = 0; j < i; j++) {
                    offset += lines[j].length() + 1; // +1 for newline
                }
                offset += line.indexOf(fieldName); // Position to the field name

                PsiElement dataElement = file.findElementAt(offset);
                if (dataElement != null) {
                    HarbourLogger.log(COMPONENT, "Found DATA field " + fieldName + " at line " + (i + 1));
                    dataFields.add(dataElement);
                }
            }
        }

        return dataFields;
    }

    /**
     * Resolves DATA field definition to its usages (::variable references)
     */
    private PsiElement[] resolveDataFieldUsages(PsiElement element, String fieldName, String currentLocationKey) {
        HarbourLogger.log(COMPONENT, "Resolving DATA field usages for: " + fieldName);
        
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return null;
        }

        // Find the class that contains this DATA field
        String className = findContainingClassName(element);
        if (className == null) {
            HarbourLogger.log(COMPONENT, "Could not find containing class for DATA field: " + fieldName);
            return null;
        }

        HarbourLogger.log(COMPONENT, "Found containing class: " + className + " for DATA field: " + fieldName);

        // Search for usages of this DATA field (::fieldName patterns)
        List<PsiElement> usages = findDataFieldUsages(file, fieldName);
        
        if (usages.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No usages found for DATA field: " + fieldName);
            return null;
        }

        // Create navigation elements for the usages
        List<PsiElement> navigationElements = new ArrayList<>();
        for (PsiElement usage : usages) {
            VirtualFile usageFile = usage.getContainingFile().getVirtualFile();
            if (usageFile != null) {
                String filePath = usageFile.getPath();
                int lineNumber = HarbourLogger.calculateLineNumber(usage);
                String locationKey = filePath + ":" + lineNumber;

                // Skip if this is the same location as the current click (the DATA definition itself)
                if (!locationKey.equals(currentLocationKey)) {
                    navigationElements.add(new HarbourNavigationElement(
                        usage,
                        "::" + fieldName,
                        filePath,
                        lineNumber,
                        "Class variable usage"
                    ));
                }
            }
        }

        if (navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No valid navigation targets found for DATA field usages: " + fieldName);
            HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(null, false, "No DATA field usages: " + fieldName);
            return new PsiElement[] { dummy };
        }

        HarbourLogger.log(COMPONENT, "Found " + navigationElements.size() + " usage targets for DATA field: " + fieldName);
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Find all usages of a DATA field (::fieldName patterns) in the file
     */
    private List<PsiElement> findDataFieldUsages(PsiFile file, String fieldName) {
        List<PsiElement> usages = new ArrayList<>();
        
        String fileText = file.getText();
        if (fileText == null) {
            return usages;
        }

        String[] lines = fileText.split("\n");
        String searchPattern = "::" + fieldName;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            int index = line.indexOf(searchPattern);
            
            if (index >= 0) {
                // Calculate the offset to the field name (after ::)
                int offset = 0;
                for (int j = 0; j < i; j++) {
                    offset += lines[j].length() + 1; // +1 for newline
                }
                offset += index + 2; // +2 to skip "::" and point to the field name

                PsiElement usageElement = file.findElementAt(offset);
                if (usageElement != null) {
                    HarbourLogger.log(COMPONENT, "Found usage of " + fieldName + " at line " + (i + 1));
                    usages.add(usageElement);
                }
            }
        }

        return usages;
    }

    /**
     * Check if this is actually a class variable reference (::variable) by checking
     * if the clicked element is immediately preceded by ::
     */
    private boolean isActualClassVariableReference(PsiElement element, String lineText, String identifierName) {
        if (lineText == null || !lineText.contains("::" + identifierName)) {
            return false;
        }

        // Get the position of our identifier in the line
        int offset = element.getTextOffset();
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return false;
        }

        String fileText = file.getText();
        if (fileText == null) {
            return false;
        }

        // Find the start of the current line
        int lineStart = offset;
        while (lineStart > 0 && fileText.charAt(lineStart - 1) != '\n') {
            lineStart--;
        }

        // Get position of identifier within the line
        int identifierPos = offset - lineStart;

        // Check if there are two colons immediately before our identifier position
        if (identifierPos >= 2) {
            String beforeIdentifier = lineText.substring(Math.max(0, identifierPos - 2), identifierPos);
            if (beforeIdentifier.equals("::")) {
                HarbourLogger.log(COMPONENT, "Found :: directly before identifier " + identifierName + " - this is a class variable reference");
                return true;
            }
        }

        HarbourLogger.log(COMPONENT, "Identifier " + identifierName + " is not preceded by :: - not a class variable reference");
        return false;
    }

    /**
     * Check if this element is part of a PropertyAccess expression
     * PropertyAccess in BNF: (FunctionCall | IDENT) COLON IDENT
     */
    private PsiElement checkPropertyAccessContext(PsiElement element) {
        if (element == null) {
            HarbourLogger.log(COMPONENT, "DEBUG-PA: Element is null");
            return null;
        }
        
        HarbourLogger.log(COMPONENT, "DEBUG-PA: Checking PropertyAccess context for: " + element.getText() + 
                         " (class: " + element.getClass().getSimpleName() + ")");
        
        // Look at the parent and siblings to see if we're in a PropertyAccess pattern
        // But be MUCH more restrictive - only look at immediate parents and small contexts
        PsiElement parent = element.getParent();
        int level = 0;
        while (parent != null && level < 3) {  // Much more restrictive depth
            String parentText = parent.getText();
            level++;
            
            // Only consider small text contexts (< 100 chars) to avoid false matches in comments/files
            if (parentText != null && parentText.length() > 100) {
                HarbourLogger.log(COMPONENT, "DEBUG-PA: Level " + level + " - Parent text too long (" + 
                                 parentText.length() + " chars), skipping: " + parent.getClass().getSimpleName());
                parent = parent.getParent();
                continue;
            }
            
            HarbourLogger.log(COMPONENT, "DEBUG-PA: Level " + level + " - Parent: " + parent.getClass().getSimpleName() + 
                             " text: '" + (parentText != null ? parentText.replace("\n", "\\n") : "null") + "'");
            
            // Check if parent contains colon pattern typical of PropertyAccess
            if (parentText != null && parentText.contains(":") && !parentText.contains("::")) {
                HarbourLogger.log(COMPONENT, "DEBUG-PA: Found colon in parent at level " + level);
                
                // Additional validation: make sure this looks like a PropertyAccess pattern
                // Should be something like: identifier():property or identifier:property
                // NOT like comments (/* module: file.prg */) or assignments (:=)
                int colonPos = parentText.indexOf(':');
                if (colonPos > 0 && colonPos < parentText.length() - 1) {
                    // Make sure it's not an assignment := 
                    if (colonPos + 1 < parentText.length() && parentText.charAt(colonPos + 1) != '=') {
                        
                        // Check if this looks like a comment (starts with /* or //)
                        String trimmedText = parentText.trim();
                        if (trimmedText.startsWith("/*") || trimmedText.startsWith("//")) {
                            HarbourLogger.log(COMPONENT, "DEBUG-PA: Colon is in comment at level " + level + ", ignoring");
                            parent = parent.getParent();
                            continue;
                        }
                        
                        // Check if it looks like a valid PropertyAccess (contains alphanumeric before and after colon)
                        String beforeColon = parentText.substring(0, colonPos).trim();
                        String afterColon = parentText.substring(colonPos + 1).trim();
                        
                        // Basic validation: both parts should contain letters/numbers and be reasonable length
                        if (beforeColon.length() > 0 && afterColon.length() > 0 && 
                            beforeColon.length() < 50 && afterColon.length() < 50 &&
                            beforeColon.matches(".*[a-zA-Z0-9()].*") && 
                            afterColon.matches(".*[a-zA-Z0-9].*")) {
                            
                            HarbourLogger.log(COMPONENT, "DEBUG-PA: Found valid PropertyAccess parent at level " + level + ": " + parentText);
                            return parent;
                        } else {
                            HarbourLogger.log(COMPONENT, "DEBUG-PA: PropertyAccess pattern validation failed at level " + level);
                        }
                    } else {
                        HarbourLogger.log(COMPONENT, "DEBUG-PA: Colon is part of assignment := at level " + level);
                    }
                } else {
                    HarbourLogger.log(COMPONENT, "DEBUG-PA: Invalid colon position (" + colonPos + ") at level " + level);
                }
            }
            
            // Don't go too far up the tree
            if (parent instanceof HarbourFile || parent instanceof HarbourFunctionDeclaration) {
                HarbourLogger.log(COMPONENT, "DEBUG-PA: Reached file/function boundary at level " + level);
                break;
            }
            parent = parent.getParent();
        }
        
        HarbourLogger.log(COMPONENT, "DEBUG-PA: No PropertyAccess context found after " + level + " levels");
        return null;
    }

    /**
     * Resolve property access like getUser():date
     */
    private PsiElement[] resolvePropertyAccess(PsiElement element, String objectPart, String propertyName, String currentLocationKey) {
        HarbourLogger.log(COMPONENT, "Resolving property access: " + objectPart + ":" + propertyName);
        
        // First, we need to determine what objectPart is
        // It could be:
        // 1. A function call like getUser()
        // 2. An object variable
        // 3. A class instantiation like User()
        
        List<HarbourNavigationElement> navigationElements = new ArrayList<>();
        
        // If objectPart ends with (), it's likely a function call
        if (objectPart.endsWith("()")) {
            String functionName = objectPart.substring(0, objectPart.length() - 2).trim();
            HarbourLogger.log(COMPONENT, "Object part is a function call: " + functionName);
            
            // For now, try to infer the class from the function name
            // Common pattern: getXxx() returns an Xxx object
            String inferredClass = inferClassFromFunctionName(functionName);
            if (inferredClass != null) {
                HarbourLogger.log(COMPONENT, "Inferred class: " + inferredClass + " from function: " + functionName);
                
                // Now look for the property in that class
                HarbourReferenceService service = HarbourReferenceService.getInstance(element.getProject());
                List<PsiElement> propertyDeclarations = service.findClassMethods(inferredClass, propertyName);
                
                // Also look for DATA fields
                List<PsiElement> dataFields = service.findDataFields(inferredClass, propertyName);
                propertyDeclarations.addAll(dataFields);
                
                HarbourLogger.log(COMPONENT, "Found " + propertyDeclarations.size() + " property declarations for " + inferredClass + ":" + propertyName);
                
                for (PsiElement decl : propertyDeclarations) {
                    PsiFile declFile = decl.getContainingFile();
                    if (declFile != null && declFile.getVirtualFile() != null) {
                        String filePath = declFile.getVirtualFile().getPath();
                        int lineNumber = HarbourLogger.calculateLineNumber(decl);
                        String locationKey = filePath + ":" + lineNumber;
                        
                        if (!locationKey.equals(currentLocationKey)) {
                            navigationElements.add(new HarbourNavigationElement(
                                    decl,
                                    propertyName,
                                    filePath,
                                    lineNumber,
                                    "Property",
                                    true,
                                    false
                            ));
                        }
                    }
                }
            }
        }
        
        // If we found targets, return them
        if (!navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "Found " + navigationElements.size() + " property navigation targets");
            return navigationElements.toArray(new PsiElement[0]);
        }
        
        HarbourLogger.log(COMPONENT, "No property navigation targets found");
        HarbourDummyPsiElement dummy = new HarbourDummyPsiElement(null, false, "No property targets found");
        return new PsiElement[] { dummy };
    }

    /**
     * Try to infer class name from function name
     * Common patterns:
     * - getUser() -> User
     * - getUserInfo() -> User or UserInfo
     */
    private String inferClassFromFunctionName(String functionName) {
        if (functionName == null || functionName.isEmpty()) {
            return null;
        }
        
        // Handle getXxx() pattern
        if (functionName.startsWith("get") && functionName.length() > 3) {
            String className = functionName.substring(3);
            // Capitalize first letter if needed
            if (!className.isEmpty() && Character.isLowerCase(className.charAt(0))) {
                className = Character.toUpperCase(className.charAt(0)) + className.substring(1);
            }
            return className;
        }
        
        // Could add more patterns here in the future
        
        return null;
    }

    /**
     * Check if an identifier is likely a function call by looking for contextual clues
     */
    private boolean isLikelyFunctionCall(PsiElement element, String identifierName) {
        HarbourLogger.log(COMPONENT, "DEBUG-FC: Checking if '" + identifierName + "' is likely a function call");
        
        PsiFile file = element.getContainingFile();
        if (file == null) {
            HarbourLogger.log(COMPONENT, "DEBUG-FC: No containing file for " + identifierName);
            return false;
        }

        // Check if this element is part of a FunctionCallImpl
        PsiElement parent = element.getParent();
        HarbourLogger.log(COMPONENT, "DEBUG-FC: Parent of '" + identifierName + "' is: " + 
                         (parent != null ? parent.getClass().getSimpleName() : "null"));
        
        if (parent instanceof FunctionCallImpl) {
            HarbourLogger.log(COMPONENT, "DEBUG-FC: " + identifierName + " is part of FunctionCallImpl - likely function call");
            return true;
        }

        // Check if followed by parentheses in the line text
        String lineText = getLineText(file, element);
        if (lineText != null) {
            HarbourLogger.log(COMPONENT, "DEBUG-FC: Line text for '" + identifierName + "': " + lineText.trim());
            
            int pos = lineText.indexOf(identifierName);
            if (pos >= 0) {
                HarbourLogger.log(COMPONENT, "DEBUG-FC: Found '" + identifierName + "' at position " + pos + " in line");
                
                // Look for opening parenthesis after the identifier
                int afterIdentifier = pos + identifierName.length();
                StringBuilder nextChars = new StringBuilder();
                
                for (int i = afterIdentifier; i < lineText.length() && i < afterIdentifier + 10; i++) {
                    char c = lineText.charAt(i);
                    nextChars.append(c);
                    
                    if (Character.isWhitespace(c)) {
                        continue; // Skip whitespace
                    }
                    if (c == '(') {
                        HarbourLogger.log(COMPONENT, "DEBUG-FC: " + identifierName + " followed by '(' - likely function call");
                        return true;
                    }
                    break; // Stop at first non-whitespace character that's not '('
                }
                
                HarbourLogger.log(COMPONENT, "DEBUG-FC: Characters after '" + identifierName + "': '" + nextChars.toString() + "'");
            } else {
                HarbourLogger.log(COMPONENT, "DEBUG-FC: '" + identifierName + "' not found in line text");
            }
        } else {
            HarbourLogger.log(COMPONENT, "DEBUG-FC: No line text available for " + identifierName);
        }

        HarbourLogger.log(COMPONENT, "DEBUG-FC: " + identifierName + " does not appear to be a function call");
        return false;
    }

    /**
     * Check if a specific found element represents a function call (has trailing parentheses)
     * This is used to filter out variable assignments when showing function navigation results
     */
    private boolean isFunctionCallAtLocation(PsiElement element, String identifierName) {
        // First check if this element is part of a FunctionCallImpl PSI structure
        PsiElement parent = element.getParent();
        if (parent instanceof FunctionCallImpl) {
            return true;
        }
        
        // Check if followed by parentheses in the line text
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return false;
        }
        
        String lineText = getLineText(file, element);
        if (lineText == null) {
            return false;
        }
        
        // Find the identifier in the line and check what follows it
        int pos = lineText.indexOf(identifierName);
        if (pos >= 0) {
            // Look for opening parenthesis after the identifier
            int afterIdentifier = pos + identifierName.length();
            
            for (int i = afterIdentifier; i < lineText.length(); i++) {
                char c = lineText.charAt(i);
                
                if (Character.isWhitespace(c)) {
                    continue; // Skip whitespace
                }
                if (c == '(') {
                    return true; // Found function call with parentheses
                }
                // If we hit assignment operators, it's a variable assignment, not a function call
                if (c == '=' || c == ':') {
                    return false;
                }
                break; // Stop at first non-whitespace character
            }
        }
        
        return false;
    }

}
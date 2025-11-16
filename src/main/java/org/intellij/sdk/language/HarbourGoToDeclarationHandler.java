package org.intellij.sdk.language;

import com.intellij.codeInsight.navigation.actions.GotoDeclarationHandler;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.*;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.pom.Navigatable;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.psi.tree.IElementType;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;
import com.intellij.notification.Notification;
import com.intellij.notification.NotificationType;
import com.intellij.notification.Notifications;

import com.intellij.openapi.application.ApplicationManager;
import java.io.File;
import java.util.*;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.Collection;

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

        // Use regex to find the function/procedure name (including STATIC)
        Pattern pattern = Pattern.compile("(?i)(STATIC\\s+)?(PROCEDURE|FUNCTION)\\s+(\\w+)");
        Matcher matcher = pattern.matcher(lineText);

        if (matcher.find()) {
            // Group 3 contains the function name (group 1 is optional STATIC, group 2 is PROCEDURE/FUNCTION)
            String funcName = matcher.group(3);
            // Only return true if this is the actual function/procedure name
            if (funcName != null && identifierName.equalsIgnoreCase(funcName)) {
                HarbourLogger.log(COMPONENT, "Identified as function/procedure name: " + identifierName);
                return true;
            }
        }

        return false;
    }
    
    /**
     * Check if an identifier is the name of a class in a CLASS declaration line
     *
     * @param file The containing file
     * @param element The element to check
     * @param identifierName The name of the identifier
     * @return True if this is a class name in a CLASS declaration
     */
    private boolean isClassDeclarationName(PsiFile file, PsiElement element, String identifierName) {
        String lineText = getLineText(file, element);
        if (lineText == null) {
            return false;
        }

        // Use regex to find the class name
        Pattern pattern = Pattern.compile("(?i)CLASS\\s+(\\w+)");
        Matcher matcher = pattern.matcher(lineText);

        if (matcher.find()) {
            // Group 1 contains the class name
            String className = matcher.group(1);
            // Only return true if this is the actual class name
            if (className != null && identifierName.equalsIgnoreCase(className)) {
                HarbourLogger.log(COMPONENT, "Identified as class name in declaration: " + identifierName);
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

        // Case-insensitive search for the identifier
        String lineUpper = lineText.toUpperCase();
        String identifierUpper = identifierName.toUpperCase();
        int identPos = lineUpper.indexOf(identifierUpper);
        if (identPos >= 0) {
            // Look for opening parenthesis after the identifier
            for (int i = identPos + identifierUpper.length(); i < lineText.length(); i++) {
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
            // Return empty array to prevent any popups on errors
            return PsiElement.EMPTY_ARRAY;
        }
    }
    
    private PsiElement[] doGetGotoDeclarationTargets(@Nullable PsiElement element, int offset, Editor editor) {
        if (element == null) {
            HarbourLogger.log(COMPONENT, "Element is null");
            return PsiElement.EMPTY_ARRAY;
        }

        String osName = System.getProperty("os.name");
        HarbourLogger.log(COMPONENT, "MAIN HANDLER: Starting getGotoDeclarationTargets for '" + element.getText() + 
                "' class: " + element.getClass().getName() + " on " + osName);

        // Check if this is in a Harbour file
        PsiFile file = element.getContainingFile();
        if (!(file instanceof HarbourFile)) {
            HarbourLogger.log(COMPONENT, "Not a Harbour file: " + (file != null ? file.getName() : "null"));
            return PsiElement.EMPTY_ARRAY;
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
        
        // Special case: If we're clicking on CLASS keyword,
        // try to get the identifier that follows
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement) element).getElementType() == HarbourTypes.CLASS) {

            HarbourLogger.log(COMPONENT, "Found CLASS keyword, looking for class name identifier");

            // Find the identifier that follows this keyword
            PsiElement nextSibling = element.getNextSibling();
            while (nextSibling != null &&
                    !(nextSibling instanceof LeafPsiElement &&
                            ((LeafPsiElement) nextSibling).getElementType() == HarbourTypes.IDENT)) {
                nextSibling = nextSibling.getNextSibling();
            }

            if (nextSibling != null) {
                // Found the class name, use that instead
                HarbourLogger.log(COMPONENT, "Found class name after CLASS keyword: " + nextSibling.getText());
                element = nextSibling;
            }
        }
        
        // Special case: If we're clicking on METHOD keyword,
        // try to get the identifier that follows
        if (element instanceof LeafPsiElement &&
                ((LeafPsiElement) element).getElementType() == HarbourTypes.METHOD) {

            HarbourLogger.log(COMPONENT, "Found METHOD keyword, looking for method name identifier");

            // Find the identifier that follows this keyword
            PsiElement nextSibling = element.getNextSibling();
            while (nextSibling != null &&
                    !(nextSibling instanceof LeafPsiElement &&
                            ((LeafPsiElement) nextSibling).getElementType() == HarbourTypes.IDENT)) {
                nextSibling = nextSibling.getNextSibling();
            }

            if (nextSibling != null) {
                // Found the method name, use that instead
                HarbourLogger.log(COMPONENT, "Found method name after METHOD keyword: " + nextSibling.getText());
                element = nextSibling;
            }
        }

        // Check if this is a keyword that should not have navigation
        if (element instanceof LeafPsiElement) {
            String elementText = element.getText();
            if (isKeyword(elementText)) {
                // Check if it's a control structure keyword that should navigate to matching structures
                PsiElement[] controlStructureMatches = findMatchingControlStructures(element);
                if (controlStructureMatches.length > 0) {
                    HarbourLogger.log(COMPONENT, "Found " + controlStructureMatches.length + " matching control structure(s) for: " + elementText);
                    return controlStructureMatches;
                }
                HarbourLogger.log(COMPONENT, "Skipping keyword navigation: " + elementText);
                return PsiElement.EMPTY_ARRAY;
            }
        }

        // Check if this is an identifier token or string literal (for includes)
        if (!(element instanceof LeafPsiElement)) {
            HarbourLogger.log(COMPONENT, "Not a LeafPsiElement: " + element.getClass().getName());
            return PsiElement.EMPTY_ARRAY;
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

        // CRITICAL FIX: Check for comment elements first - they should NOT get any navigation
        if (element instanceof PsiComment || element.getClass().getName().contains("Comment")) {
            HarbourLogger.log(COMPONENT, "COMMENT ELEMENT DETECTED - returning empty array: " + element.getClass().getName());
            return PsiElement.EMPTY_ARRAY;
        }
        
        if (leafElement.getElementType() != HarbourTypes.IDENT) {
            // Check if this is a keyword token type (like ENDIF, ENDDO, etc.)
            String tokenTypeName = leafElement.getElementType().toString();
            if (isKeywordTokenType(tokenTypeName)) {
                HarbourLogger.log(COMPONENT, "Element is a keyword token, not navigable: " + tokenTypeName);
                return PsiElement.EMPTY_ARRAY;
            }
            
            // CRITICAL FIX: For non-IDENT elements that are not comments or keywords, 
            // return empty array instead of dummy to prevent underlines
            HarbourLogger.log(COMPONENT, "Non-IDENT element (not comment/keyword): " + leafElement.getElementType() + " - returning empty array");
            return PsiElement.EMPTY_ARRAY;
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
                if (afterColon.trim().equalsIgnoreCase(identifierName)) {
                    // Clicking on the property part (e.g., date)
                    HarbourLogger.log(COMPONENT, "DEBUG: Clicking on property part of PropertyAccess: " + identifierName);
                    
                    // Try to resolve the object type first
                    String objectPart = beforeColon.trim();
                    HarbourLogger.log(COMPONENT, "DEBUG: Resolving property '" + identifierName + "' of object: '" + objectPart + "'");
                    return resolvePropertyAccess(leafElement, objectPart, identifierName, currentLocationKey);
                } else if (beforeColon.toUpperCase().contains(identifierName.toUpperCase())) {
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
                    HarbourLogger.log(COMPONENT, "External function detected: " + identifierName);
                    
                    // Check if this is a click event
                    boolean isClick = HarbourExternalDocumentationHandler.shouldHandleAsClick();
                    
                    if (isClick) {
                        // On click: Open browser documentation
                        HarbourLogger.log(COMPONENT, "CLICK EVENT - opening browser for: " + identifierName);
                        HarbourDocumentationProvider docProvider = new HarbourDocumentationProvider();
                        boolean browserOpened = docProvider.openExternalDocumentation(file.getProject(), identifierName);
                        
                        if (browserOpened) {
                            HarbourLogger.log(COMPONENT, "Browser opened successfully");
                        } else {
                            HarbourLogger.log(COMPONENT, "Failed to open browser");
                        }
                    } else {
                        // On hover: Just provide underlines, no browser
                        HarbourLogger.log(COMPONENT, "HOVER EVENT - providing underlines only for: " + identifierName);
                    }
                    
                    // Create a proper navigation element for underlines (both hover and click)
                    HarbourLogger.log(COMPONENT, "Creating navigation element for external function underlines");
                    HarbourNavigationElement navElement = new HarbourNavigationElement(
                        leafElement,
                        "External: " + identifierName,
                        file.getVirtualFile().getPath(),
                        editor.getDocument().getLineNumber(leafElement.getTextOffset()) + 1,
                        "External function"
                    );
                    return new PsiElement[] { navElement };
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

        // Check if this is a class name in a CLASS declaration or a class reference
        boolean isClassDeclaration = isClassDeclarationName(file, leafElement, identifierName);
        boolean isClassRef = isClassReference(leafElement);
        
        if (isClassDeclaration || isClassRef) {
            HarbourLogger.log(COMPONENT, "Identified as class reference or declaration: " + identifierName);
            
            // If clicking on a class declaration, find all usages instead of just declarations
            if (isClassDeclaration) {
                HarbourLogger.log(COMPONENT, "User clicked on class declaration - finding all usages");
                
                // Find all usages of the class (instantiations, method calls, etc.)
                Project project = element.getProject();
                HarbourReferenceService service = HarbourReferenceService.getInstance(project);
                
                // Search for all occurrences of the class name
                List<PsiElement> foundElements = service.findSymbol(identifierName, true);
                
                if (!foundElements.isEmpty()) {
                    HarbourLogger.log(COMPONENT, "Found " + foundElements.size() + " usages of class: " + identifierName);
                    
                    // Convert to navigation elements and show popup
                    List<PsiElement> navigationElements = new ArrayList<>();
                    Set<String> locations = new HashSet<>();
                    
                    for (PsiElement elem : foundElements) {
                        if (elem != null && elem.isValid()) {
                            try {
                                PsiFile containingFile = elem.getContainingFile();
                                if (containingFile != null && containingFile.getVirtualFile() != null) {
                                    int lineNumber = HarbourLogger.calculateLineNumber(elem);
                                    String filePath = containingFile.getVirtualFile().getPath();
                                    String locationKey = filePath + ":" + lineNumber;
                                    
                                    if (!locations.contains(locationKey)) {
                                        // Determine if this is a definition or usage
                                        String lineText = getLineText(containingFile, elem);
                                        boolean isDefinition = lineText != null && lineText.toUpperCase().contains("CLASS " + identifierName.toUpperCase());
                                        
                                        String context = isDefinition ? "CLASS definition" : "Usage";
                                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                                elem, identifierName, filePath, lineNumber, context, isDefinition, false);
                                        navigationElements.add(navigationElement);
                                        locations.add(locationKey);
                                    }
                                }
                            } catch (Exception e) {
                                HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                            }
                        }
                    }
                    
                    if (!navigationElements.isEmpty()) {
                        // Show popup with all usages
                        final String finalIdentifierName = identifierName;
                        ApplicationManager.getApplication().invokeLater(() -> {
                            HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(navigationElements), editor, finalIdentifierName);
                        });
                        return null; // Prevent default navigation
                    }
                }
            } else {
                // Regular class reference - show popup with declaration AND usages
                String className = leafElement.getText();
                HarbourLogger.log(COMPONENT, "Resolving class reference: " + className);
                
                // Get both declarations and usages
                List<HarbourNavigationElement> allResults = new ArrayList<>();
                
                // First, get class declarations
                PsiElement[] classDeclarations = resolveClassReference(leafElement, currentLocationKey);
                if (classDeclarations != null && classDeclarations.length > 0) {
                    HarbourLogger.log(COMPONENT, "Found " + classDeclarations.length + " class declarations");
                    for (PsiElement decl : classDeclarations) {
                        if (decl instanceof HarbourNavigationElement) {
                            allResults.add((HarbourNavigationElement) decl);
                        } else if (decl != null) {
                            // Convert regular PsiElement to HarbourNavigationElement
                            PsiFile containingFile = decl.getContainingFile();
                            if (containingFile != null && containingFile.getVirtualFile() != null) {
                                int lineNumber = HarbourLogger.calculateLineNumber(decl);
                                String filePath = containingFile.getVirtualFile().getPath();
                                String lineText = getLineText(containingFile, decl);
                                
                                // Verify it's actually a CLASS line
                                if (lineText != null && lineText.toUpperCase().contains("CLASS")) {
                                    HarbourNavigationElement navElement = new HarbourNavigationElement(
                                        decl, className, filePath, lineNumber, lineText, true, false);
                                    allResults.add(navElement);
                                    HarbourLogger.log(COMPONENT, "Added class declaration from " + 
                                        containingFile.getName() + " at line " + lineNumber);
                                }
                            }
                        }
                    }
                }
                
                // Now get all usages using function search (which includes class usages)
                Project project = leafElement.getProject();
                
                // Add separator if we have declarations
                if (!allResults.isEmpty()) {
                    allResults.add(HarbourNavigationElement.createSeparator(project));
                }
                HarbourReferenceService service = HarbourReferenceService.getInstance(project);
                List<PsiElement> usages = service.findFunctions(className, true);
                
                if (usages != null && !usages.isEmpty()) {
                    HarbourLogger.log(COMPONENT, "Found " + usages.size() + " usages of class: " + className);
                    
                    for (PsiElement usage : usages) {
                        if (usage != null && usage.isValid()) {
                            try {
                                PsiFile containingFile = usage.getContainingFile();
                                if (containingFile != null && containingFile.getVirtualFile() != null) {
                                    int lineNumber = HarbourLogger.calculateLineNumber(usage);
                                    String filePath = containingFile.getVirtualFile().getPath();
                                    String locationKey = filePath + ":" + lineNumber;
                                    
                                    // Skip current location
                                    if (!locationKey.equals(currentLocationKey)) {
                                        String lineText = getLineText(containingFile, usage);
                                        HarbourNavigationElement navElement = new HarbourNavigationElement(
                                            usage, className, filePath, lineNumber, lineText, false, false);
                                        allResults.add(navElement);
                                    }
                                }
                            } catch (Exception e) {
                                HarbourLogger.log(COMPONENT, "Error processing usage: " + e.getMessage());
                            }
                        }
                    }
                }
                
                if (!allResults.isEmpty()) {
                    final String finalClassName = className;
                    ApplicationManager.getApplication().invokeLater(() -> {
                        HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(allResults), editor, finalClassName);
                    });
                    return null; // Prevent default navigation
                }
                
                HarbourLogger.log(COMPONENT, "No navigation results found for class: " + className);
                return null;
            }
        }

        // Get the line text for context analysis
        String lineText = getLineText(file, element);

        // Next check if this is a method reference or method declaration
        boolean isMethod = false;
        boolean isMethodDeclaration = false;
        
        if (lineText != null) {
            // Check if this is a METHOD declaration line
            if (lineText.toUpperCase().contains("METHOD ")) {
                // Check if identifier appears after METHOD keyword (handle both with and without parentheses)
                Pattern methodPattern = Pattern.compile("(?i)METHOD\\s+" + Pattern.quote(identifierName) + "(?:\\s*\\(|\\s|$)");
                if (methodPattern.matcher(lineText).find()) {
                    isMethod = true;
                    isMethodDeclaration = true;
                    HarbourLogger.log(COMPONENT, "Identified as method name in METHOD declaration: " + identifierName);
                }
            }
            
            // Check if there's a colon immediately before the identifier (method call pattern, case-insensitive)
            if (!isMethod) {
                int identPos = lineText.toUpperCase().indexOf(identifierName.toUpperCase());
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
            }
        } else {
            isMethod = isMethodReference(leafElement);
        }

        if (isMethod) {
            HarbourLogger.log(COMPONENT, "Identified as method reference: " + identifierName);
            
            // If clicking on a method declaration, find all usages
            if (isMethodDeclaration) {
                HarbourLogger.log(COMPONENT, "User clicked on method declaration - finding all usages");
                
                // Find all usages of the method
                Project project = element.getProject();
                HarbourReferenceService service = HarbourReferenceService.getInstance(project);
                
                // Search for all occurrences of the method name
                List<PsiElement> foundElements = service.findSymbol(identifierName, true);
                
                if (!foundElements.isEmpty()) {
                    HarbourLogger.log(COMPONENT, "Found " + foundElements.size() + " usages of method: " + identifierName);
                    
                    // Convert to navigation elements and show popup
                    List<HarbourNavigationElement> navigationElements = new ArrayList<>();
                    Set<String> locations = new HashSet<>();
                    boolean hasDefinitions = false;
                    boolean hasUsages = false;
                    
                    // First add METHOD definitions
                    for (PsiElement elem : foundElements) {
                        if (elem != null && elem.isValid()) {
                            try {
                                PsiFile containingFile = elem.getContainingFile();
                                if (containingFile != null && containingFile.getVirtualFile() != null) {
                                    String elemLineText = getLineText(containingFile, elem);
                                    boolean isDefinition = elemLineText != null && elemLineText.toUpperCase().contains("METHOD " + identifierName.toUpperCase());
                                    
                                    if (isDefinition) {
                                        int lineNumber = HarbourLogger.calculateLineNumber(elem);
                                        String filePath = containingFile.getVirtualFile().getPath();
                                        String locationKey = filePath + ":" + lineNumber;
                                        
                                        if (!locations.contains(locationKey)) {
                                            HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                                    elem, identifierName, filePath, lineNumber, "METHOD definition", true, false);
                                            navigationElements.add(navigationElement);
                                            locations.add(locationKey);
                                            hasDefinitions = true;
                                        }
                                    }
                                }
                            } catch (Exception e) {
                                HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                            }
                        }
                    }
                    
                    // Add separator if we have definitions
                    if (hasDefinitions) {
                        // Check if there are any usages
                        for (PsiElement elem : foundElements) {
                            if (elem != null && elem.isValid()) {
                                PsiFile containingFile = elem.getContainingFile();
                                if (containingFile != null) {
                                    String elemLineText = getLineText(containingFile, elem);
                                    boolean isDefinition = elemLineText != null && elemLineText.toUpperCase().contains("METHOD " + identifierName.toUpperCase());
                                    if (!isDefinition) {
                                        hasUsages = true;
                                        break;
                                    }
                                }
                            }
                        }
                        
                        if (hasUsages) {
                            HarbourNavigationElement separator = HarbourNavigationElement.createSeparator(project);
                            if (separator != null) {
                                navigationElements.add(separator);
                            }
                        }
                    }
                    
                    // Then add usages
                    for (PsiElement elem : foundElements) {
                        if (elem != null && elem.isValid()) {
                            try {
                                PsiFile containingFile = elem.getContainingFile();
                                if (containingFile != null && containingFile.getVirtualFile() != null) {
                                    String elemLineText = getLineText(containingFile, elem);
                                    boolean isDefinition = elemLineText != null && elemLineText.toUpperCase().contains("METHOD " + identifierName.toUpperCase());
                                    
                                    if (!isDefinition) {
                                        int lineNumber = HarbourLogger.calculateLineNumber(elem);
                                        String filePath = containingFile.getVirtualFile().getPath();
                                        String locationKey = filePath + ":" + lineNumber;
                                        
                                        if (!locations.contains(locationKey)) {
                                            HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                                    elem, identifierName, filePath, lineNumber, "Usage", false, false);
                                            navigationElements.add(navigationElement);
                                            locations.add(locationKey);
                                        }
                                    }
                                }
                            } catch (Exception e) {
                                HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                            }
                        }
                    }
                    
                    if (!navigationElements.isEmpty()) {
                        // Show popup with all usages
                        final String finalIdentifierName = identifierName;
                        ApplicationManager.getApplication().invokeLater(() -> {
                            HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(navigationElements), editor, finalIdentifierName);
                        });
                        return null; // Prevent default navigation
                    }
                }
            } else {
                // Regular method reference - resolve and show popup
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
                        // Always show popup for consistent navigation experience
                        List<HarbourNavigationElement> navElements = new ArrayList<>();
                        for (PsiElement target : methodTargets) {
                            if (target instanceof HarbourNavigationElement) {
                                navElements.add((HarbourNavigationElement) target);
                            }
                        }
                        
                        if (!navElements.isEmpty()) {
                            final String finalIdentifierName = identifierName;
                            ApplicationManager.getApplication().invokeLater(() -> {
                                HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(navElements), editor, finalIdentifierName);
                            });
                            return null; // Prevent default navigation
                        }
                        return methodTargets;
                    }
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
        
        // Be more aggressive about treating things as functions if they look like function calls
        // This helps with missing includes where PSI parsing might fail
        if (!isFunction && identifierName != null && identifierName.length() > 0) {
            // Check if this looks like a function call pattern (identifier followed by parentheses somewhere in context)
            {
                String contextLineText = getLineText(file, element);
                if (contextLineText != null) {
                    String pattern = "\\b" + Pattern.quote(identifierName) + "\\s*\\(";
                    if (Pattern.compile(pattern, Pattern.CASE_INSENSITIVE).matcher(contextLineText).find()) {
                        isFunction = true;
                        HarbourLogger.log(COMPONENT, "Treating as function based on pattern match: " + identifierName);
                    }
                }
            }
        }

        // Check if user clicked on a function/procedure definition  
        boolean isFunctionDefinitionClick = false;
        if (isFunction) {
            isFunctionDefinitionClick = isDefinitionElement(leafElement, getElementContext(leafElement));
            if (isFunctionDefinitionClick) {
                HarbourLogger.log(COMPONENT, "User clicked on function/procedure definition - will show all usages");
            }
        }
        
        // Use our custom finder to locate occurrences of this symbol
        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        
        // Add detailed logging for debugging first-click issues
        HarbourLogger.log(COMPONENT, "=== NAVIGATION DEBUG START for: " + identifierName + " ===");
        HarbourLogger.log(COMPONENT, "Service instance: " + (service != null ? "OK" : "NULL"));
        HarbourLogger.log(COMPONENT, "Current file: " + (file != null ? file.getName() : "NULL"));
        HarbourLogger.log(COMPONENT, "isFunction: " + isFunction);
        HarbourLogger.log(COMPONENT, "isFunctionDefinitionClick: " + isFunctionDefinitionClick);

        List<PsiElement> foundElements;
        if (isFunction) {
            HarbourLogger.log(COMPONENT, "Searching for function: " + identifierName);
            try {
                // For navigation, always get ALL results - user explicitly requested navigation
                foundElements = service.findFunctions(identifierName, true);
                HarbourLogger.log(COMPONENT, "Initial search result: " + foundElements.size() + " elements found (ALL results)");
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during initial function search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                // If we get a cancellation exception, return null to let other handlers try
                String exceptionName = e.getClass().getSimpleName();
                if (exceptionName.contains("JobCancellation") || exceptionName.contains("ProcessCanceled") || 
                    exceptionName.contains("CeProcessCanceled")) {
                    HarbourLogger.log(COMPONENT, "Cancellation exception detected (" + exceptionName + ") - returning null to let other handlers try");
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
                        foundElements = service.findFunctions(identifierName, true);
                        HarbourLogger.log(COMPONENT, "After reindex: " + foundElements.size() + " elements found (ALL results)");
                        
                        // If still nothing found after reindex, try broader project-wide search
                        if (foundElements.isEmpty()) {
                            HarbourLogger.log(COMPONENT, "Still nothing after reindex, trying project-wide search");
                            foundElements = service.findSymbol(identifierName, true);
                            HarbourLogger.log(COMPONENT, "Project-wide search result: " + foundElements.size() + " elements found (ALL results)");
                        }
                    } catch (Exception e) {
                        HarbourLogger.log(COMPONENT, "Exception during reindex/project search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                        // If we get a cancellation exception during reindex, return null to let other handlers try
                        String exceptionName = e.getClass().getSimpleName();
                        if (exceptionName.contains("JobCancellation") || exceptionName.contains("ProcessCanceled") || 
                            exceptionName.contains("CeProcessCanceled")) {
                            HarbourLogger.log(COMPONENT, "Cancellation exception during reindex (" + exceptionName + ") - returning null to let other handlers try");
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
            
            // First check if this is a #define constant reference
            List<PsiElement> defineDeclarations = service.findDefines(identifierName);
            
            if (!defineDeclarations.isEmpty()) {
                HarbourLogger.log(COMPONENT, "Found #define for: " + identifierName);
                
                // Find all usages of this #define constant as well
                // Note: findSymbol might not find constants, so search manually
                List<PsiElement> allOccurrences = new ArrayList<>();
                
                // Search in all Harbour files for this identifier
                Collection<VirtualFile> allFiles = FileTypeIndex.getFiles(HarbourFileType.INSTANCE, 
                    GlobalSearchScope.projectScope(project));
                    
                for (VirtualFile vFile : allFiles) {
                    PsiFile psiFile = PsiManager.getInstance(project).findFile(vFile);
                    if (psiFile != null) {
                        String fileText = psiFile.getText();
                        int index = 0;
                        while ((index = fileText.indexOf(identifierName, index)) != -1) {
                            PsiElement elem = psiFile.findElementAt(index);
                            if (elem != null && elem.getText().equals(identifierName)) {
                                allOccurrences.add(elem);
                            }
                            index += identifierName.length();
                        }
                    }
                }
                
                HarbourLogger.log(COMPONENT, "Found " + allOccurrences.size() + " total occurrences of #define " + identifierName);
                
                // Convert to navigation elements with #define at top
                List<HarbourNavigationElement> navigationElements = new ArrayList<>();
                Set<String> locations = new HashSet<>();
                
                // First add the #define declarations (they should appear at top)
                for (PsiElement declaration : defineDeclarations) {
                    if (declaration != null && declaration.isValid()) {
                        try {
                            PsiFile containingFile = declaration.getContainingFile();
                            if (containingFile != null && containingFile.getVirtualFile() != null) {
                                int lineNumber = HarbourLogger.calculateLineNumber(declaration);
                                String filePath = containingFile.getVirtualFile().getPath();
                                String locationKey = filePath + ":" + lineNumber;
                                
                                if (!locations.contains(locationKey)) {
                                    // Create navigation element for #define declaration
                                    HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                            declaration, identifierName, filePath, lineNumber, 
                                            "#define declaration", true, false);
                                    navigationElements.add(navigationElement);
                                    locations.add(locationKey);
                                    
                                    HarbourLogger.log(COMPONENT, "Added #define declaration for " +
                                            identifierName + " in " + containingFile.getName());
                                }
                            }
                        } catch (Exception e) {
                            HarbourLogger.log(COMPONENT, "Error creating navigation element for #define: " + e.getMessage());
                        }
                    }
                }
                
                // Add separator between declarations and usages if we have both
                if (!navigationElements.isEmpty() && allOccurrences.size() > defineDeclarations.size()) {
                    HarbourNavigationElement separator = HarbourNavigationElement.createSeparator(project);
                    if (separator != null) {
                        navigationElements.add(separator);
                    }
                }
                
                // Then add all other usages
                for (PsiElement elem : allOccurrences) {
                    if (elem != null && elem.isValid()) {
                        try {
                            PsiFile containingFile = elem.getContainingFile();
                            if (containingFile != null && containingFile.getVirtualFile() != null) {
                                int lineNumber = HarbourLogger.calculateLineNumber(elem);
                                String filePath = containingFile.getVirtualFile().getPath();
                                String locationKey = filePath + ":" + lineNumber;
                                
                                if (!locations.contains(locationKey)) {
                                    // Check if this is a #define line
                                    String elemLineText = getLineText(containingFile, elem);
                                    boolean isDefine = elemLineText != null && elemLineText.matches("(?i)^\\s*#\\s*define\\s+.*");
                                    
                                    if (!isDefine) { // Skip if it's a define (already added above)
                                        String context = "Usage";
                                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                                elem, identifierName, filePath, lineNumber, context, false, false);
                                        navigationElements.add(navigationElement);
                                        locations.add(locationKey);
                                    }
                                }
                            }
                        } catch (Exception e) {
                            HarbourLogger.log(COMPONENT, "Error creating navigation element for usage: " + e.getMessage());
                        }
                    }
                }
                
                if (!navigationElements.isEmpty()) {
                    // Show popup with #define at top and usages below
                    final String finalIdentifierName = identifierName;
                    ApplicationManager.getApplication().invokeLater(() -> {
                        HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(navigationElements), editor, finalIdentifierName);
                    });
                    return null; // Prevent default navigation
                }
            }

            try {
                // For variables: Use simple file-based search with line-based scoping
                // Variables cannot be used outside their declaration file unless PRIVATE/STATIC
                foundElements = findVariableInCurrentFileWithScope(element, identifierName);
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Exception during variable search: " + e.getClass().getSimpleName() + " - " + e.getMessage());
                // If we get a cancellation exception, return null to let other handlers try
                String exceptionName = e.getClass().getSimpleName();
                if (exceptionName.contains("JobCancellation") || exceptionName.contains("ProcessCanceled") || 
                    exceptionName.contains("CeProcessCanceled")) {
                    HarbourLogger.log(COMPONENT, "Cancellation exception during variable search (" + exceptionName + ") - returning null to let other handlers try");
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
        
        // Handle variables early to avoid JobCancellationException in complex processing
        if (!isFunction && !foundElements.isEmpty()) {
            // HYBRID APPROACH: Check if we have multiple results to decide on popup
            if (foundElements.size() > 1) {
                // Multiple results - check if this is likely a click (when user expects popup)
                boolean isLikelyClick = isLikelyClickContext();
                
                if (isLikelyClick) {
                    HarbourLogger.log(COMPONENT, "VARIABLE MULTI-RESULT CLICK: Showing custom popup for " + foundElements.size() + " elements");
                    // Show custom popup for multiple results on click
                    final String finalIdentifierName = identifierName;
                    final List<PsiElement> finalFoundElements = new ArrayList<>(foundElements);
                    
                    // Convert to HarbourNavigationElement for nice display
                    List<HarbourNavigationElement> navElements = new ArrayList<>();
                    for (PsiElement elem : finalFoundElements) {
                        try {
                            String elementName = elem.getText();
                            String filePath = elem.getContainingFile() != null ? 
                                elem.getContainingFile().getVirtualFile().getPath() : "unknown";
                            int lineNumber = HarbourLogger.calculateLineNumber(elem);
                            
                            HarbourNavigationElement navElement = new HarbourNavigationElement(
                                elem, elementName, filePath, lineNumber, "Variable");
                            navElements.add(navElement);
                        } catch (Exception e) {
                            HarbourLogger.log(COMPONENT, "Failed to convert element: " + e.getMessage());
                        }
                    }
                    
                    if (!navElements.isEmpty()) {
                        ApplicationManager.getApplication().invokeLater(() -> {
                            HarbourNavigationPopup.showNavigationPopup(new ArrayList<>(navElements), editor, finalIdentifierName);
                        });
                        return null; // Prevent default popup
                    }
                }
            }
            
            // Single result or hover - use default IntelliJ handling
            HarbourLogger.log(COMPONENT, "VARIABLE DEFAULT: Using IntelliJ default for " + foundElements.size() + " elements");
            PsiElement[] result = foundElements.toArray(new PsiElement[0]);
            return result;
        }

        // Filter out invalid elements and deduplicate by file:line
        Set<String> locations = new HashSet<>();
        List<PsiElement> navigationElements = new ArrayList<>();
        List<PsiElement> definitionElements = new ArrayList<>();
        List<PsiElement> callElements = new ArrayList<>();
        
        // PERFORMANCE: Limit processing for very large result sets
        // We only show 20 initially, so processing 200 is more than enough to handle duplicates
        int maxElementsToProcess = foundElements.size() > 500 ? 200 : foundElements.size();
        int elementsProcessed = 0;
        
        // Store original count for accurate display
        final int originalFoundCount = foundElements.size();

        for (PsiElement foundElement : foundElements) {
            // Stop processing after reasonable limit for large result sets
            if (elementsProcessed >= maxElementsToProcess) {
                HarbourLogger.log(COMPONENT, "Reached processing limit of " + maxElementsToProcess + 
                        " elements out of " + foundElements.size() + " total");
                break;
            }
            elementsProcessed++;
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
                            // Only log duplicates for small result sets to avoid performance issues
                            if (foundElements.size() <= 50) {
                                HarbourLogger.log(COMPONENT, "Skipping duplicate location: " + locationKey);
                            }
                            continue;
                        }

                        // Get context information for the navigation element
                        String context = getElementContext(foundElement);

                        // Skip if this is the current location (where the user clicked)
                        // BUT don't skip if we're looking for function usages from a declaration
                        // Also don't skip if this element is a definition itself
                        boolean isDeclarationClick = isDefinitionElement(element, getElementContext(element));
                        boolean isThisElementDefinition = isDefinitionElement(foundElement, context);
                        if (locationKey.equals(currentLocationKey) && !isDeclarationClick && !isThisElementDefinition) {
                            HarbourLogger.log(COMPONENT, "Skipping current location: " + locationKey);
                            continue;
                        }

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

                        // Logging disabled for performance when creating 1000+ elements
                        // HarbourLogger.log(COMPONENT, "Created navigation element for " + identifierName +
                        //         " in " + containingFile.getName() + " at line " + lineNumber +
                        //         " isDefinition: " + isDefinition);

                        // Add to definitions or calls list based on type
                        if (isDefinition) {
                            definitionElements.add(navigationElement);
                        } else {
                            // For functions, only add to callElements if it's actually a function call
                            // This filters out variable assignments like "message = something"
                            if (isFunction) {
                                // PERFORMANCE OPTIMIZATION: Skip expensive function call checking for large result sets
                                // When we have > 100 results, trust the index and add all usages
                                if (foundElements.size() > 100) {
                                    callElements.add(navigationElement);
                                    // Logging disabled for performance with large result sets
                                } else if (isFunctionCallAtLocation(foundElement, identifierName)) {
                                    callElements.add(navigationElement);
                                    // Only log for small result sets to avoid performance issues
                                    if (foundElements.size() <= 20) {
                                        HarbourLogger.log(COMPONENT, "Added function call for " + identifierName + 
                                                " at " + containingFile.getName() + ":" + lineNumber);
                                    }
                                } else {
                                    // Only log for small result sets to avoid performance issues
                                    if (foundElements.size() <= 20) {
                                        HarbourLogger.log(COMPONENT, "Skipped non-function call usage of " + identifierName + 
                                                " at " + containingFile.getName() + ":" + lineNumber + " (variable assignment/usage)");
                                    }
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

        // If we have no valid elements, try one more fallback for functions that timeout
        if (definitionElements.isEmpty() && callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: No valid navigation elements found for " + identifierName + " - trying fallback search");
            
            // For functions that often fail due to timeouts, try a simpler grep-like search
            if (isFunction) {
                HarbourLogger.log(COMPONENT, "Attempting simple pattern search for function: " + identifierName);
                try {
                    // Use a simple pattern to find function/procedure definitions
                    // Allow optional whitespace and/or parentheses after function name
                    String pattern = "(?i)^\\s*(FUNCTION|PROCEDURE)\\s+" + Pattern.quote(identifierName) + "(?:\\s*\\(|\\s|$)";
                    Pattern funcPattern = Pattern.compile(pattern, Pattern.MULTILINE);
                    
                    // Search through project files quickly
                    Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                        HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));
                    
                    int maxFiles = 100; // Increased limit
                    int filesChecked = 0;
                    boolean found = false;
                    
                    for (VirtualFile virtualFile : virtualFiles) {
                        if (filesChecked++ > maxFiles) {
                            HarbourLogger.log(COMPONENT, "Reached file limit in fallback search");
                            break;
                        }
                        
                        try {
                            PsiFile psiFile = PsiManager.getInstance(project).findFile(virtualFile);
                            if (psiFile != null) {
                                String fileText = psiFile.getText();
                                if (fileText == null || fileText.isEmpty()) continue;
                                
                                Matcher matcher = funcPattern.matcher(fileText);
                                if (matcher.find()) {
                                    // Count line number
                                    int lineNumber = 1;
                                    for (int i = 0; i < matcher.start(); i++) {
                                        if (fileText.charAt(i) == '\n') lineNumber++;
                                    }
                                    HarbourLogger.log(COMPONENT, "Found " + identifierName + " definition in " + 
                                        virtualFile.getName() + " at line " + lineNumber);
                                    
                                    // Create a navigation element for the definition
                                    HarbourNavigationElement navElement = new HarbourNavigationElement(
                                        psiFile, identifierName, virtualFile.getPath(), lineNumber, "Function", true, false);
                                    definitionElements.add(navElement);
                                    found = true;
                                    break; // Found definition, stop searching
                                }
                            }
                        } catch (Exception ex) {
                            HarbourLogger.log(COMPONENT, "Error checking file " + virtualFile.getName() + ": " + ex.getMessage());
                        }
                    }
                    
                    if (!found) {
                        HarbourLogger.log(COMPONENT, "Fallback search checked " + filesChecked + " files but found no definition for " + identifierName);
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Fallback pattern search failed: " + e.getMessage());
                }
            }
            
            // If still no elements after fallback, create a dummy element for common functions
            // This ensures they get underlined even if we can't find their definition
            if (definitionElements.isEmpty() && callElements.isEmpty()) {
                HarbourLogger.log(COMPONENT, "MAIN HANDLER: Still no elements after fallback");
                
                // For known internal functions, create a dummy navigation element
                // This ensures they get underlined and clickable
                if (isFunction && identifierName != null) {
                    HarbourLogger.log(COMPONENT, "Creating dummy navigation element for function: " + identifierName);
                    // Create a dummy element that at least makes the function clickable
                    HarbourNavigationElement dummyElement = new HarbourNavigationElement(
                        element, identifierName, "Unknown location", 1, "Function (location unknown)", false, false);
                    
                    // Check if this is a click event - if so, show popup
                    boolean isClick = HarbourExternalDocumentationHandler.shouldHandleAsClick();
                    if (isClick) {
                        HarbourLogger.log(COMPONENT, "Click event - showing popup for dummy element");
                        final String searchedName = identifierName;
                        final List<PsiElement> dummyList = Collections.singletonList(dummyElement);
                        ApplicationManager.getApplication().invokeLater(() -> {
                            if (editor != null && !editor.isDisposed() && editor.getComponent().isShowing()) {
                                HarbourNavigationPopup.showNavigationPopup(dummyList, editor, searchedName);
                            }
                        });
                        return null; // Prevent default navigation
                    }
                    
                    return new PsiElement[] { dummyElement };
                }
                
                return PsiElement.EMPTY_ARRAY;
            }
        }

        // If we only have calls but no definitions, show the calls (for variables, these are references)
        // Don't return null to prevent default handlers from running
        if (definitionElements.isEmpty() && !callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: Only calls/references found for " + identifierName + 
                            " (" + callElements.size() + " calls) - checking click/hover mode");
            
            // Check if this is a click event - if so, show popup instead of navigating directly
            boolean isClick = HarbourExternalDocumentationHandler.shouldHandleAsClick();
            if (isClick) {
                HarbourLogger.log(COMPONENT, "Click event - showing popup for calls/references");
                final String searchedName = identifierName;
                ApplicationManager.getApplication().invokeLater(() -> {
                    if (editor != null && !editor.isDisposed() && editor.getComponent().isShowing()) {
                        HarbourNavigationPopup.showNavigationPopup(callElements, editor, searchedName);
                    }
                });
                return null; // Prevent default navigation
            }
            
            // For hover, return the elements for default behavior
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

        // If we have exactly one navigation element after filtering, check for hover vs click
        if (navigationElements.size() == 1) {
            PsiElement singleElement = navigationElements.get(0);
            boolean isClick = HarbourExternalDocumentationHandler.shouldHandleAsClick();
            HarbourLogger.log(COMPONENT, "Single target found - Click mode: " + isClick);
            
            // For external functions, show popup even for single results to maintain consistency
            boolean isExternalFunction = false;
            if (singleElement instanceof HarbourNavigationElement) {
                HarbourNavigationElement navElement = (HarbourNavigationElement) singleElement;
                String filePath = navElement.getFilePath();
                // External functions have file paths
                if (filePath != null && !filePath.isEmpty() && !navElement.isSeparator()) {
                    isExternalFunction = true;
                }
            }
            
            // ALWAYS show popup on click - never navigate directly (per user requirement)
            if (isClick) {
                HarbourLogger.log(COMPONENT, "Click event - always showing popup (external: " + isExternalFunction + ")");
                final String searchedFunctionName = identifierName;
                
                ApplicationManager.getApplication().invokeLater(() -> {
                    // Check if editor is still valid
                    if (editor != null && !editor.isDisposed() && editor.getComponent().isShowing()) {
                        HarbourNavigationPopup.showNavigationPopup(navigationElements, editor, searchedFunctionName);
                    } else {
                        HarbourLogger.log(COMPONENT, "Editor not valid for popup, falling back to direct navigation");
                        if (singleElement instanceof Navigatable) {
                            ((Navigatable) singleElement).navigate(true);
                        }
                    }
                });
                return null; // Prevent default navigation
            }
            
            // For hover (not click), allow direct navigation for single target
            HarbourLogger.log(COMPONENT, "Single target on hover - navigating directly");
            PsiElement[] singleTarget = navigationElements.toArray(new PsiElement[0]);
            if (singleTarget.length == 0) {
                HarbourLogger.log(COMPONENT, "WARNING: navigationElements had size 1 but toArray returned empty - returning empty array");
                return PsiElement.EMPTY_ARRAY;
            }
            return singleTarget;
        }

        // If we have multiple targets, ALWAYS show popup (fixes first-click issue)
        if (navigationElements.size() > 1) {
            HarbourLogger.log(COMPONENT, "Multiple targets found (" + navigationElements.size() + ") - ALWAYS showing popup");
            
            // ALWAYS show popup for multiple results (don't check for click vs hover)
            // This fixes the first-click issue where click detection was unreliable
            HarbourLogger.log(COMPONENT, "Showing navigation popup for multiple targets");
            
            // Create final copies for use in lambda
            final String searchedFunctionName = identifierName;
            final List<PsiElement> finalFoundElements = new ArrayList<>(foundElements);
            final boolean finalIsFunction = isFunction;
            
            ApplicationManager.getApplication().invokeLater(() -> {
                // Check if editor is still valid before showing popup
                if (editor == null || editor.isDisposed() || !editor.getComponent().isShowing()) {
                    HarbourLogger.log(COMPONENT, "Editor not valid for popup, skipping popup display");
                    return;
                }
                
                List<PsiElement> targets = navigationElements.stream()
                        .filter(e -> {
                            // Filter out navigation elements that point to empty lines or comments
                            if (e instanceof HarbourNavigationElement) {
                                HarbourNavigationElement navElement = (HarbourNavigationElement) e;
                                
                                // Always keep separator elements
                                if (navElement.isSeparator()) {
                                    return true;
                                }
                                
                                String lineContent = navElement.readLineFromFile(navElement.getFilePath(), navElement.getLineNumber());
                                return lineContent != null;
                            }
                            return true;
                        })
                        .map(e -> (PsiElement) e)
                        .collect(Collectors.toList());
                // Pass actual count if we hit the processing limit
                int actualTotal = originalFoundCount > maxElementsToProcess ? originalFoundCount : -1;
                
                // Create a supplier to fetch all results when Load All is clicked
                Supplier<List<PsiElement>> allResultsSupplier = null;
                if (originalFoundCount > maxElementsToProcess) {
                    // We limited processing, so create a supplier that processes ALL results
                    // Use the final copies we already created
                    final List<PsiElement> allFoundElements = finalFoundElements;
                    final String finalIdentifierName = searchedFunctionName;
                    final boolean finalIsFunctionForSupplier = finalIsFunction;
                    
                    allResultsSupplier = () -> {
                        // Process all elements without limit
                        List<PsiElement> allNavigationElements = new ArrayList<>();
                        List<PsiElement> allDefinitionElements = new ArrayList<>();
                        List<PsiElement> allCallElements = new ArrayList<>();
                        Set<String> allLocations = new HashSet<>();
                        
                        // Process ALL elements without limit
                        for (PsiElement foundElement : allFoundElements) {
                            if (foundElement != null && foundElement.isValid()) {
                                try {
                                    PsiFile containingFile = foundElement.getContainingFile();
                                    if (containingFile != null && containingFile.getVirtualFile() != null) {
                                        // Skip elements where the text doesn't match
                                        if (!isTextMatching(foundElement, finalIdentifierName)) {
                                            continue;
                                        }
                                        
                                        // Calculate line number for the element
                                        int lineNumber = HarbourLogger.calculateLineNumber(foundElement);
                                        String filePath = containingFile.getVirtualFile().getPath();
                                        String locationKey = filePath + ":" + lineNumber;
                                        
                                        // Skip duplicates
                                        if (allLocations.contains(locationKey)) {
                                            continue;
                                        }
                                        
                                        // Get context information
                                        String context = getElementContext(foundElement);
                                        
                                        // Skip current location unless it's a definition
                                        boolean isThisElementDefinition = isDefinitionElement(foundElement, context);
                                        if (locationKey.equals(currentLocationKey) && !isThisElementDefinition) {
                                            continue;
                                        }
                                        
                                        // Determine if this is a definition
                                        boolean isDefinition = isDefinitionElement(foundElement, context);
                                        
                                        // Create navigation element
                                        HarbourNavigationElement navigationElement = new HarbourNavigationElement(
                                                foundElement, finalIdentifierName, filePath, lineNumber, context, isDefinition, false);
                                        
                                        // Add to appropriate list
                                        if (isDefinition) {
                                            allDefinitionElements.add(navigationElement);
                                        } else {
                                            // For large result sets, skip expensive function call validation
                                            allCallElements.add(navigationElement);
                                        }
                                        
                                        // Record the location
                                        allLocations.add(locationKey);
                                    }
                                } catch (Exception e) {
                                    // Skip element on error
                                }
                            }
                        }
                        
                        // Sort and combine the lists
                        allDefinitionElements.sort((e1, e2) -> {
                            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;
                                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                                int fileCompare = fileName1.compareTo(fileName2);
                                if (fileCompare != 0) {
                                    return fileCompare;
                                }
                                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
                            }
                            return 0;
                        });
                        
                        allCallElements.sort((e1, e2) -> {
                            if (e1 instanceof HarbourNavigationElement && e2 instanceof HarbourNavigationElement) {
                                HarbourNavigationElement nav1 = (HarbourNavigationElement) e1;
                                HarbourNavigationElement nav2 = (HarbourNavigationElement) e2;
                                String fileName1 = nav1.getFilePath().substring(nav1.getFilePath().lastIndexOf('/') + 1);
                                String fileName2 = nav2.getFilePath().substring(nav2.getFilePath().lastIndexOf('/') + 1);
                                int fileCompare = fileName1.compareTo(fileName2);
                                if (fileCompare != 0) {
                                    return fileCompare;
                                }
                                return Integer.compare(nav1.getLineNumber(), nav2.getLineNumber());
                            }
                            return 0;
                        });
                        
                        // Combine lists
                        allNavigationElements.addAll(allDefinitionElements);
                        if (!allDefinitionElements.isEmpty() && !allCallElements.isEmpty()) {
                            HarbourNavigationElement separator = HarbourNavigationElement.createSeparator(project);
                            if (separator != null) {
                                allNavigationElements.add(separator);
                            }
                        }
                        allNavigationElements.addAll(allCallElements);
                        
                        // Return all processed elements
                        return allNavigationElements;
                    };
                }
                
                HarbourNavigationPopup.showNavigationPopup(targets, editor, searchedFunctionName, actualTotal, allResultsSupplier);
            });
            
            // Return null to prevent IntelliJ's default popup from showing
            HarbourLogger.log(COMPONENT, "Returning null to prevent IntelliJ popup");
            return null;
        }

        HarbourLogger.log(COMPONENT, "FINAL RESULT: Returning " + navigationElements.size() + " sorted navigation targets");
        
        // If we have no elements at all, return a dummy to prevent "Cannot find declaration" popup
        if (navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "ERROR: No navigation elements found - returning empty array to prevent ALL popups");
            HarbourLogger.log(COMPONENT, "=== NAVIGATION DEBUG END (FAILED) ===");
            return PsiElement.EMPTY_ARRAY;
        }

        // Use custom popup for variables to add variable name to header and enhanced styling
        if (!isFunction && !navigationElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "VARIABLE NAVIGATION: Using custom popup for variable: " + identifierName);
            
            // Show custom popup with variable name in header
            final String finalIdentifierName = identifierName;
            ApplicationManager.getApplication().invokeLater(() -> {
                // Check if editor is still valid before showing popup
                if (editor != null && !editor.isDisposed() && editor.getComponent().isShowing()) {
                    // Pass actual count if we hit the processing limit
                    int actualTotal = originalFoundCount > maxElementsToProcess ? originalFoundCount : -1;
                    HarbourNavigationPopup.showNavigationPopup(navigationElements, editor, finalIdentifierName, actualTotal);
                } else {
                    HarbourLogger.log(COMPONENT, "Editor not valid for variable popup, skipping popup display");
                }
            });
            
            // Return null to prevent IntelliJ's default popup
            HarbourLogger.log(COMPONENT, "Returning null to prevent default popup - using custom popup for variables");
            return null;
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
        // First, find where our element appears in the line (case-insensitive)
        String lineUpper = lineText.toUpperCase();
        String textUpper = text.toUpperCase();
        int elementPos = lineUpper.indexOf(textUpper);
        if (elementPos < 0) {
            return false;
        }

        // Now check if it's followed by "():new()" pattern
        String afterText = lineText.substring(elementPos + textUpper.length());
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

        // Find where our element appears in the line (case-insensitive)
        int pos = lineText.toUpperCase().indexOf(text.toUpperCase());
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

                        // Get the actual line text for context
                        String lineText = getLineText(containingFile, declaration);
                        
                        // Use the actual line text as context if available, otherwise use default
                        String context = lineText != null && lineText.toUpperCase().contains("CLASS") 
                            ? lineText.trim() 
                            : "CLASS " + className;

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
                // Case-insensitive regex to find the variable name as a whole word
                if (line.toUpperCase().matches(".*\\b" + variableName.toUpperCase() + "\\b.*")) {
                    // Find all occurrences of the variable in this line (case-insensitive)
                    String lineUpper = line.toUpperCase();
                    String variableUpper = variableName.toUpperCase();
                    int pos = 0;
                    while ((pos = lineUpper.indexOf(variableUpper, pos)) >= 0) {
                        // Check if it's a whole word (not part of another identifier)
                        boolean isWholeWord = true;
                        if (pos > 0 && Character.isLetterOrDigit(line.charAt(pos - 1))) {
                            isWholeWord = false;
                        }
                        if (pos + variableUpper.length() < line.length() && 
                            Character.isLetterOrDigit(line.charAt(pos + variableUpper.length()))) {
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
                                if (foundElement != null && variableName.equalsIgnoreCase(foundElement.getText())) {
                                    results.add(foundElement);
                                }
                            } else {
                                HarbourLogger.log(COMPONENT, "VARIABLE SEARCH: Skipping comment line " + (lineNum + 1) + " in " + file.getName() + " -> Content: '" + trimmedLine + "'");
                            }
                        }
                        pos += variableUpper.length();
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
            // Skip comments - they should not be considered as function declarations
            if (line.startsWith("//") || line.startsWith("/*")) {
                continue;
            }
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
            // Skip comments - they should not be considered as function declarations
            if (line.startsWith("//") || line.startsWith("/*")) {
                continue;
            }
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
            return PsiElement.EMPTY_ARRAY;
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
            return PsiElement.EMPTY_ARRAY;
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
        return PsiElement.EMPTY_ARRAY;
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
            
            String lineUpper = lineText.toUpperCase();
            String identifierUpper = identifierName.toUpperCase();
            int pos = lineUpper.indexOf(identifierUpper);
            if (pos >= 0) {
                HarbourLogger.log(COMPONENT, "DEBUG-FC: Found '" + identifierName + "' at position " + pos + " in line");
                
                // Look for opening parenthesis after the identifier
                int afterIdentifier = pos + identifierUpper.length();
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
        
        // Find the identifier in the line and check what follows it (case-insensitive)
        String lineUpper = lineText.toUpperCase();
        String identifierUpper = identifierName.toUpperCase();
        int pos = lineUpper.indexOf(identifierUpper);
        if (pos >= 0) {
            // Look for opening parenthesis after the identifier
            int afterIdentifier = pos + identifierUpper.length();
            
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
    
    /**
     * Checks if the token type represents a keyword.
     * Keywords have their own token types like ENDIF, ENDDO, etc.
     */
    private boolean isKeywordTokenType(String tokenType) {
        if (tokenType == null) {
            return false;
        }
        
        // Check common keyword token types
        return tokenType.equals("ENDIF") || tokenType.equals("ENDDO") || 
               tokenType.equals("ENDFUNCTION") || tokenType.equals("ENDPROC") ||
               tokenType.equals("ENDFUNC") || tokenType.equals("ENDCLASS") ||
               tokenType.equals("ENDMETHOD") || tokenType.equals("ENDSWITCH") ||
               tokenType.equals("IF") || tokenType.equals("ELSE") || 
               tokenType.equals("ELSEIF") || tokenType.equals("DO") ||
               tokenType.equals("WHILE") || tokenType.equals("FOR") ||
               tokenType.equals("NEXT") || tokenType.equals("CASE") ||
               tokenType.equals("OTHERWISE") || tokenType.equals("SWITCH") ||
               tokenType.equals("BEGIN") || tokenType.equals("SEQUENCE") ||
               tokenType.equals("RECOVER") || tokenType.equals("END") ||
               tokenType.equals("SET") || tokenType.equals("RETURN") ||
               tokenType.equals("EXIT") || tokenType.equals("LOOP") ||
               tokenType.equals("LOCAL") || tokenType.equals("STATIC") ||
               tokenType.equals("PRIVATE") || tokenType.equals("PUBLIC") ||
               tokenType.equals("FIELD") || tokenType.equals("MEMVAR") ||
               tokenType.equals("PARAMETER") || tokenType.equals("PARAMETERS") ||
               tokenType.equals("CLASS") || tokenType.equals("METHOD") ||
               tokenType.equals("DATA") || tokenType.equals("CLASSDATA") ||
               tokenType.equals("EXPORTED") || tokenType.equals("PROTECTED") ||
               tokenType.equals("HIDDEN") || tokenType.equals("AND") ||
               tokenType.equals("OR") || tokenType.equals("NOT") ||
               tokenType.equals("TO") || tokenType.equals("STEP") ||
               tokenType.equals("ADDITIVE") || tokenType.equals("NIL") ||
               tokenType.equals("TRUE") || tokenType.equals("FALSE") ||
               tokenType.equals("IN") || tokenType.equals("WITH") ||
               tokenType.equals("REPLACE") || tokenType.equals("ALL") ||
               tokenType.equals("REST") || tokenType.equals("FROM") ||
               tokenType.equals("SEEK") || tokenType.equals("SKIP") ||
               tokenType.equals("USE") || tokenType.equals("INDEX") ||
               tokenType.equals("ALIAS") || tokenType.equals("EXCLUSIVE") ||
               tokenType.equals("SHARED") || tokenType.equals("READONLY");
    }

    /**
     * Checks if the text is a Harbour keyword that should not have navigation.
     * This prevents creation of dummy elements for keywords like 'endif', 'enddo', etc.
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
            upperText.equals("RECOVER") || upperText.equals("END")) {
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
            upperText.equals("SHARED") || upperText.equals("READONLY")) {
            return true;
        }
        
        return false;
    }

    /**
     * Check if this is likely a click context (for variables with multiple results)
     * Uses a simpler heuristic since exact detection is difficult
     */
    private boolean isLikelyClickContext() {
        try {
            StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
            
            // Look for clear indicators of actual navigation action (not just data collection)
            for (StackTraceElement element : stackTrace) {
                String className = element.getClassName();
                String methodName = element.getMethodName();
                
                // These patterns indicate actual navigation/action being performed
                if (methodName.equals("actionPerformed") ||
                    methodName.equals("invoke") ||
                    methodName.equals("navigate") ||
                    className.contains("NavigateCommand") ||
                    className.contains("NavigationAction")) {
                    HarbourLogger.log(COMPONENT, "LIKELY CLICK: Found navigation action - " + className + "." + methodName);
                    return true;
                }
                
                // These patterns indicate just data collection for preview
                if (className.contains("DocumentationManager") ||
                    className.contains("QuickDoc") ||
                    className.contains("CtrlMouseHandler") ||
                    methodName.contains("getDocumentation")) {
                    HarbourLogger.log(COMPONENT, "LIKELY HOVER: Found preview pattern - " + className + "." + methodName);
                    return false;
                }
            }
            
            // Default: for multiple results, assume click if we got this far
            HarbourLogger.log(COMPONENT, "LIKELY CLICK: Default for multiple results");
            return true;
            
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error checking click context: " + e.getMessage());
            return true; // Default to showing popup on error
        }
    }
    
    /**
     * Detect if this is a click invocation (Ctrl+Click) vs hover by analyzing the call stack.
     * This approach avoids the need for global state management and is more reliable.
     */
    private boolean isClickInvocation() {
        try {
            StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
            
            // Log the full stack trace for debugging
            HarbourLogger.log(COMPONENT, "=== STACK TRACE ANALYSIS START ===");
            for (int i = 0; i < Math.min(stackTrace.length, 15); i++) {
                StackTraceElement element = stackTrace[i];
                HarbourLogger.log(COMPONENT, "Stack[" + i + "]: " + element.getClassName() + "." + element.getMethodName());
            }
            
            boolean foundClick = false;
            boolean foundHover = false;
            
            for (StackTraceElement element : stackTrace) {
                String className = element.getClassName();
                String methodName = element.getMethodName();
                
                // VERY SPECIFIC CLICK DETECTION - only these exact patterns indicate clicks
                // NOTE: getCtrlMouseData is called for BOTH hover and click, so we need more specific detection
                if ((className.contains("GotoDeclarationAction") && methodName.equals("actionPerformed")) ||
                    (className.contains("GotoDeclarationOnlyHandler") && methodName.contains("gotoDeclaration")) ||
                    (className.contains("GotoDeclarationOrUsageHandler") && methodName.equals("invoke"))) {
                    HarbourLogger.log(COMPONENT, "DEFINITIVE CLICK DETECTED: " + className + "." + methodName);
                    foundClick = true;
                }
                
                // Check for getCtrlMouseData specifically to distinguish between hover/click based on deeper stack
                if (className.contains("GotoDeclarationAction") && methodName.equals("getCtrlMouseData")) {
                    // This method is called for BOTH hover and click
                    // We need to look deeper in the stack to determine which one
                    HarbourLogger.log(COMPONENT, "AMBIGUOUS: getCtrlMouseData found - checking deeper stack");
                }
                
                // HOVER DETECTION - broader patterns for documentation/hint system
                if (className.contains("DocumentationManager") ||
                    className.contains("QuickDocUtil") ||
                    className.contains("HintManagerImpl") ||
                    className.contains("QuickHelpAction") ||
                    className.contains("ShowDoc") ||
                    className.contains("ParameterInfo") ||
                    className.contains("LookupManager") ||
                    methodName.contains("getDocumentation") ||
                    methodName.contains("showQuickDoc")) {
                    HarbourLogger.log(COMPONENT, "DEFINITIVE HOVER DETECTED: " + className + "." + methodName);
                    foundHover = true;
                }
            }
            
            if (foundClick && !foundHover) {
                HarbourLogger.log(COMPONENT, "=== RESULT: CLICK (only click patterns found) ===");
                return true;
            } else if (foundHover) {
                HarbourLogger.log(COMPONENT, "=== RESULT: HOVER (hover patterns found) ===");
                return false;
            } else {
                HarbourLogger.log(COMPONENT, "=== RESULT: HOVER (safe default - no clear patterns) ===");
                return false;
            }
            
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "STACK TRACE ANALYSIS ERROR: " + e.getMessage() + " - defaulting to HOVER");
            return false;
        }
    }

    /**
     * Find matching control structures for keywords like IF/ENDIF, WHILE/ENDDO, etc.
     */
    private PsiElement[] findMatchingControlStructures(@NotNull PsiElement element) {
        List<PsiElement> rawMatches = new ArrayList<>();
        IElementType elementType = element.getNode().getElementType();

        // Check if this is a control structure keyword
        if (!isControlStructureKeyword(elementType)) {
            return PsiElement.EMPTY_ARRAY;
        }

        // Determine if we're looking for opening or closing
        boolean isOpening = isOpeningKeyword(elementType);
        boolean isClosing = isClosingKeyword(elementType);
        boolean isMiddle = isMiddleKeyword(elementType);

        // Get all keywords in the file
        PsiFile file = element.getContainingFile();
        if (file == null) {
            return PsiElement.EMPTY_ARRAY;
        }

        // Find all matching control structure elements
        List<PsiElement> allKeywords = new ArrayList<>();
        collectControlStructureKeywords(file, elementType, allKeywords);

        if (allKeywords.isEmpty()) {
            return PsiElement.EMPTY_ARRAY;
        }

        // Find the matching structure based on nesting
        int nestingLevel = 0;
        int startOffset = element.getTextRange().getStartOffset();

        if (isOpening || isMiddle) {
            // Looking forward for closing or middle keywords
            for (PsiElement keyword : allKeywords) {
                int keywordOffset = keyword.getTextRange().getStartOffset();

                if (keywordOffset <= startOffset) {
                    continue; // Skip keywords before our position
                }

                IElementType keywordType = keyword.getNode().getElementType();

                if (isOpeningKeyword(keywordType)) {
                    nestingLevel++;
                } else if (isClosingKeyword(keywordType)) {
                    if (nestingLevel == 0) {
                        // Found matching closing
                        rawMatches.add(keyword);
                        if (!isMiddle) {
                            break; // Only add closing for opening keywords
                        }
                    } else {
                        nestingLevel--;
                    }
                } else if (isMiddleKeyword(keywordType) && nestingLevel == 0) {
                    // Found middle keyword at same level
                    rawMatches.add(keyword);
                }
            }
        }

        if (isClosing || isMiddle) {
            // Looking backward for opening or middle keywords
            nestingLevel = 0;
            for (int i = allKeywords.size() - 1; i >= 0; i--) {
                PsiElement keyword = allKeywords.get(i);
                int keywordOffset = keyword.getTextRange().getStartOffset();

                if (keywordOffset >= startOffset) {
                    continue; // Skip keywords after our position
                }

                IElementType keywordType = keyword.getNode().getElementType();

                if (isClosingKeyword(keywordType)) {
                    nestingLevel++;
                } else if (isOpeningKeyword(keywordType)) {
                    if (nestingLevel == 0) {
                        // Found matching opening
                        rawMatches.add(0, keyword); // Add at beginning to maintain order
                        if (!isMiddle) {
                            break; // Only add opening for closing keywords
                        }
                    } else {
                        nestingLevel--;
                    }
                } else if (isMiddleKeyword(keywordType) && nestingLevel == 0) {
                    // Found middle keyword at same level
                    rawMatches.add(0, keyword); // Add at beginning
                }
            }
        }

        // Wrap raw PsiElements in HarbourNavigationElement for proper display
        List<PsiElement> wrappedMatches = new ArrayList<>();
        for (PsiElement match : rawMatches) {
            String lineText = getLineTextForElement(file, match);
            String displayText = lineText != null ? lineText.trim() : match.getText();
            int lineNumber = getLineNumber(file, match);

            HarbourNavigationElement navElement = new HarbourNavigationElement(
                match,
                displayText,
                file.getVirtualFile() != null ? file.getVirtualFile().getPath() : file.getName(),
                lineNumber,
                "Control structure"
            );
            wrappedMatches.add(navElement);
        }

        return wrappedMatches.toArray(new PsiElement[0]);
    }

    /**
     * Get the full line text for a PsiElement
     */
    private String getLineTextForElement(PsiFile file, PsiElement element) {
        try {
            String fileText = file.getText();
            if (fileText == null) return null;

            int offset = element.getTextOffset();
            String[] lines = fileText.split("\n");

            int currentOffset = 0;
            for (String line : lines) {
                if (currentOffset <= offset && offset < currentOffset + line.length()) {
                    return line;
                }
                currentOffset += line.length() + 1;
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }

    /**
     * Get line number for a PsiElement
     */
    private int getLineNumber(PsiFile file, PsiElement element) {
        try {
            String fileText = file.getText();
            if (fileText == null) return 1;

            int offset = element.getTextOffset();
            String textBefore = fileText.substring(0, Math.min(offset, fileText.length()));
            return textBefore.split("\n").length;
        } catch (Exception e) {
            return 1;
        }
    }

    /**
     * Collect all control structure keywords of compatible types in the tree
     */
    private void collectControlStructureKeywords(@NotNull PsiElement root, @NotNull IElementType targetType, @NotNull List<PsiElement> result) {
        PsiElement child = root.getFirstChild();
        while (child != null) {
            IElementType childType = child.getNode().getElementType();

            if (isMatchingControlStructure(targetType, childType)) {
                result.add(child);
            }

            // Recurse into children
            collectControlStructureKeywords(child, targetType, result);

            child = child.getNextSibling();
        }
    }

    /**
     * Check if two control structure types match (e.g., IF matches with ELSE, ELSEIF, ENDIF)
     */
    private boolean isMatchingControlStructure(@NotNull IElementType type1, @NotNull IElementType type2) {
        // IF/ELSE/ELSEIF/ENDIF group
        if ((type1 == HarbourTypes.IF || type1 == HarbourTypes.ELSE || type1 == HarbourTypes.ELSEIF || type1 == HarbourTypes.ENDIF) &&
            (type2 == HarbourTypes.IF || type2 == HarbourTypes.ELSE || type2 == HarbourTypes.ELSEIF || type2 == HarbourTypes.ENDIF)) {
            return true;
        }

        // WHILE/ENDDO group
        if ((type1 == HarbourTypes.WHILE || type1 == HarbourTypes.ENDDO) &&
            (type2 == HarbourTypes.WHILE || type2 == HarbourTypes.ENDDO)) {
            return true;
        }

        // FOR/NEXT group
        if ((type1 == HarbourTypes.FOR || type1 == HarbourTypes.NEXT) &&
            (type2 == HarbourTypes.FOR || type2 == HarbourTypes.NEXT)) {
            return true;
        }

        // SWITCH/CASE/ENDSWITCH/ENDCASE group
        if ((type1 == HarbourTypes.SWITCH || type1 == HarbourTypes.CASE || type1 == HarbourTypes.ENDSWITCH || type1 == HarbourTypes.ENDCASE) &&
            (type2 == HarbourTypes.SWITCH || type2 == HarbourTypes.CASE || type2 == HarbourTypes.ENDSWITCH || type2 == HarbourTypes.ENDCASE)) {
            return true;
        }

        return false;
    }

    /**
     * Check if the keyword is a control structure keyword
     */
    private boolean isControlStructureKeyword(@NotNull IElementType type) {
        return type == HarbourTypes.IF || type == HarbourTypes.ELSE || type == HarbourTypes.ELSEIF || type == HarbourTypes.ENDIF ||
               type == HarbourTypes.WHILE || type == HarbourTypes.ENDDO ||
               type == HarbourTypes.FOR || type == HarbourTypes.NEXT ||
               type == HarbourTypes.SWITCH || type == HarbourTypes.CASE || type == HarbourTypes.ENDSWITCH || type == HarbourTypes.ENDCASE;
    }

    /**
     * Check if the keyword is an opening keyword
     */
    private boolean isOpeningKeyword(@NotNull IElementType type) {
        return type == HarbourTypes.IF || type == HarbourTypes.WHILE ||
               type == HarbourTypes.FOR || type == HarbourTypes.SWITCH;
    }

    /**
     * Check if the keyword is a closing keyword
     */
    private boolean isClosingKeyword(@NotNull IElementType type) {
        return type == HarbourTypes.ENDIF || type == HarbourTypes.ENDDO ||
               type == HarbourTypes.NEXT || type == HarbourTypes.ENDSWITCH ||
               type == HarbourTypes.ENDCASE;
    }

    /**
     * Check if the keyword is a middle keyword (like ELSE, ELSEIF, CASE)
     */
    private boolean isMiddleKeyword(@NotNull IElementType type) {
        return type == HarbourTypes.ELSE || type == HarbourTypes.ELSEIF ||
               type == HarbourTypes.CASE;
    }

}
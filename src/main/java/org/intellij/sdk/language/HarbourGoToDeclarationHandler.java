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
        processedElements.clear();

        if (element == null) {
            HarbourLogger.log(COMPONENT, "Element is null");
            return null;
        }

        String osName = System.getProperty("os.name");
        HarbourLogger.log(COMPONENT, "MAIN HANDLER: Starting getGotoDeclarationTargets for '" + element.getText() + 
                "' class: " + element.getClass().getName() + " on " + osName);

        // Check if this is in a Harbour file
        PsiFile file = element.getContainingFile();
        if (!(file instanceof HarbourFile)) {
            HarbourLogger.log(COMPONENT, "Not a Harbour file: " + (file != null ? file.getName() : "null"));
            return null;
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
            return null;
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
            return null;
        }

        String identifierName = leafElement.getText();
        // For string literals, remove the quotes
        if (leafElement.getElementType() == HarbourTypes.STRING_LITERAL) {
            identifierName = identifierName.replace("\"", "").replace("'", "");
            HarbourLogger.log(COMPONENT, "Processing string literal: " + identifierName);
        } else {
            HarbourLogger.log(COMPONENT, "Processing identifier: " + identifierName);
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

        // Next check if this is a method reference - but explicitly check for assignment operators
        boolean isMethod = false;
        if (lineText != null) {
            // Check for assignment operator that might be confused with method reference
            boolean hasAssignmentOperator = lineText.contains(":=");
            int assignPos = lineText.indexOf(":=");
            int identPos = lineText.indexOf(identifierName);

            // Only consider it a method if we don't have an assignment or the assignment is after the identifier
            if (!hasAssignmentOperator || (assignPos > identPos)) {
                isMethod = isMethodReference(leafElement);
            }
        } else {
            isMethod = isMethodReference(leafElement);
        }

        if (isMethod) {
            HarbourLogger.log(COMPONENT, "Identified as method reference: " + identifierName);
            PsiElement[] methodTargets = resolveMethodReference(leafElement, currentLocationKey);
            if (methodTargets != null && methodTargets.length > 0) {
                HarbourLogger.log(COMPONENT, "Found " + methodTargets.length + " method targets");

                // If there's exactly one target, return it directly for navigation
                if (methodTargets.length == 1) {
                    HarbourLogger.log(COMPONENT, "Direct navigation to single method target");
                    return methodTargets;
                }
                return methodTargets;
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

        List<PsiElement> foundElements;
        if (isFunction) {
            HarbourLogger.log(COMPONENT, "Searching for function: " + identifierName);
            foundElements = service.findFunctions(identifierName);

            // If we didn't find anything, try force-reindexing the file first
            if (foundElements.isEmpty()) {
                HarbourLogger.log(COMPONENT, "No functions found, trying to reindex file");
                if (file instanceof HarbourFile) {
                    service.forceClearCaches();
                    service.registerFunctions((HarbourFile)file);
                    service.registerProcedures((HarbourFile)file);
                    foundElements = service.findFunctions(identifierName);
                }
            }
        } else {
            HarbourLogger.log(COMPONENT, "Searching for variable/symbol: " + identifierName);

            // Find ALL occurrences first
            List<PsiElement> allElements = service.findSymbol(identifierName);

            // If this is a variable, filter to current procedure/function scope
            int[] scope = getProcedureFunctionScope(element);
            if (scope != null) {
                HarbourLogger.log(COMPONENT, "Filtering variables to scope: " + scope[0] + "-" + scope[1]);

                // Create filtered list with only elements in the same scope
                foundElements = new ArrayList<>();
                for (PsiElement found : allElements) {
                    if (found != null && found.isValid()) {
                        int foundLine = HarbourLogger.calculateLineNumber(found);
                        if (foundLine >= scope[0] && foundLine <= scope[1]) {
                            foundElements.add(found);
                            HarbourLogger.log(COMPONENT, "Adding in-scope variable at line: " + foundLine);
                        }
                    }
                }
            } else {
                // If we couldn't determine scope, use all results
                foundElements = allElements;
            }
        }

        HarbourLogger.log(COMPONENT, "Found " + foundElements.size() + " elements for: " + identifierName);

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
                        boolean isDefinition = isDefinitionElement(foundElement, context);

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
                            callElements.add(navigationElement);
                        }

                        // Record the location to prevent duplicates
                        locations.add(locationKey);
                    }
                } catch (Exception e) {
                    HarbourLogger.log(COMPONENT, "Error creating navigation element: " + e.getMessage());
                }
            }
        }

        // If we have no valid elements, return null
        if (definitionElements.isEmpty() && callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: No valid navigation elements found for " + identifierName);
            return null;
        }

        // If we only have calls but no definitions, this might be an external function
        // Return null to let the external documentation handler take over
        if (definitionElements.isEmpty() && !callElements.isEmpty()) {
            HarbourLogger.log(COMPONENT, "MAIN HANDLER: Only calls found for " + identifierName + 
                            " (" + callElements.size() + " calls) on " + osName + " - delegating to external handler");
            return null;
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
            return navigationElements.toArray(new PsiElement[0]);
        }

        HarbourLogger.log(COMPONENT, "Returning " + navigationElements.size() + " sorted navigation targets");
        return navigationElements.toArray(new PsiElement[0]);
    }

    /**
     * Enhanced method to identify definitions including METHOD declarations
     */
    private boolean isDefinitionElement(PsiElement element, String context) {
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

                // Check if this is at the start of the line (with possible whitespace/static prefix)
                String trimmedLine = lineText.trim();
                if (trimmedLine.toUpperCase().startsWith("PROCEDURE ") ||
                        trimmedLine.toUpperCase().startsWith("FUNCTION ") ||
                        trimmedLine.toUpperCase().startsWith("METHOD ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC PROCEDURE ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC FUNCTION ") ||
                        trimmedLine.toUpperCase().startsWith("STATIC METHOD ")) {
                    return true;
                }
            }
        }

        return false;
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
     * Determines if an element is a class reference in code like ClassName():method()
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

        // Check if this line contains a pattern like "ClassName():method"
        // First, find where our element appears in the line
        int elementPos = lineText.indexOf(text);
        if (elementPos < 0) {
            return false;
        }

        // Now check if it's followed by "()" and then ":" or "."
        String afterText = lineText.substring(elementPos + text.length());
        Pattern classPattern = Pattern.compile("\\s*\\(\\s*\\)\\s*[:.]");

        boolean isClass = classPattern.matcher(afterText).find();
        HarbourLogger.log(COMPONENT, text + " is " + (isClass ? "" : "not ") + "a class reference");
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
        if (lineText.toUpperCase().contains("METHOD") &&
                lineText.toUpperCase().indexOf("METHOD") < pos) {
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
        Pattern classPattern = Pattern.compile("(\\w+)\\s*\\(\\s*\\)\\s*[:.]");
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

        // Log both the method name and potential class name for debugging
        HarbourLogger.log(COMPONENT, "Method " + methodName +
                (className != null ? " with potential class: " + className : " with no class detected"));

        Project project = element.getProject();
        HarbourReferenceService service = HarbourReferenceService.getInstance(project);
        List<PsiElement> methodDeclarations = new ArrayList<>();

        // Try class-specific search if we found a class name
        if (className != null) {
            HarbourLogger.log(COMPONENT, "Searching for method " + methodName + " in class " + className);
            methodDeclarations = service.findClassMethods(className, methodName);
        }

        // If class-specific search didn't yield results, try general method search
        if (methodDeclarations.isEmpty()) {
            HarbourLogger.log(COMPONENT, "No class-specific methods found, trying general method search");

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

        // Convert to navigation elements
        List<PsiElement> navigationElements = new ArrayList<>();
        Set<String> locations = new HashSet<>();

        for (PsiElement declaration : methodDeclarations) {
            if (declaration != null && declaration.isValid()) {
                try {
                    PsiFile containingFile = declaration.getContainingFile();
                    if (containingFile != null && containingFile.getVirtualFile() != null) {
                        // Calculate line number for the element
                        int lineNumber = HarbourLogger.calculateLineNumber(declaration);
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
}
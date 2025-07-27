package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.EditorFactory;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Service for resolving references to functions and methods in the Harbour language.
 * This service indexes all function declarations in the project and provides methods
 * to find them by name.
 */
@Service(Service.Level.PROJECT)
public final class HarbourReferenceService {
    private static final Logger LOG = Logger.getInstance(HarbourReferenceService.class);

    // Cache of function name (lowercase) to list of declarations
    private final Map<String, List<PsiElement>> functionCaches = new ConcurrentHashMap<>();

    // Cache of symbol name (lowercase) to list of declarations
    private final Map<String, List<PsiElement>> symbolCaches = new ConcurrentHashMap<>();

    // Cache of variable name (lowercase) to list of declarations
    private final Map<String, List<PsiElement>> variableCaches = new ConcurrentHashMap<>();

    // Cache of class name (lowercase) to list of declarations
    private final Map<String, List<PsiElement>> classCaches = new ConcurrentHashMap<>();

    // Set of excluded files (paths)
    private final Set<String> excludedFiles = new HashSet<>();

    // Set of excluded filenames (just the filenames, no paths)
    private final Set<String> excludedFilenames = new HashSet<>();

    // Flag to track if indexing is complete
    private boolean indexed = false;

    // Project instance
    private final Project project;

    /**
     * Get the instance of the service for the given project.
     */
    public static HarbourReferenceService getInstance(Project project) {
        return project.getService(HarbourReferenceService.class);
    }

    /**
     * Constructor
     */
    public HarbourReferenceService(Project project) {
        this.project = project;
    }

    /**
     * Find all functions with the given name.
     *
     * @param functionName The name of the function to find
     * @return A list of PSI elements for the function declarations
     */
    public List<PsiElement> findFunctions(String functionName) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of function: " + functionName);

        // Log cache state
        if (functionCaches.containsKey(functionName.toLowerCase())) {
            HarbourLogger.log("ReferenceService", "Found in cache: " + functionName + " with " +
                    functionCaches.get(functionName.toLowerCase()).size() + " results");
        } else {
            HarbourLogger.log("ReferenceService", "Not in cache: " + functionName);
        }

        if (functionName == null || functionName.isEmpty()) {
            return Collections.emptyList();
        }

        // Check cache first
        String functionKey = functionName.toLowerCase();
        if (functionCaches.containsKey(functionKey)) {
            List<PsiElement> cachedResults = functionCaches.get(functionKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " results in cache for: " + functionName);
            return new ArrayList<>(cachedResults);
        }

        HarbourLogger.log("ReferenceService", "Function not found in cache, trying direct search for: " + functionName);
        List<PsiElement> result = directSearch(functionName, true);

        // Cache the result
        if (!result.isEmpty()) {
            functionCaches.put(functionKey, new ArrayList<>(result));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for: " + functionName);
        }

        // Before returning results
        HarbourLogger.log("ReferenceService", "Returning " + result.size() + " results for " + functionName);
        for (PsiElement element : result) {
            HarbourLogger.log("ReferenceService", "Found " + functionName + " at " +
                    element.getContainingFile().getName() + ":" + element.getTextOffset());
        }

        return result;
    }

    /**
     * Find all variables with the given name.
     *
     * @param variableName The name of the variable to find
     * @return A list of PSI elements for the variable usages
     */
    public List<PsiElement> findVariables(String variableName) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of variable: " + variableName);

        if (variableName == null || variableName.isEmpty()) {
            return Collections.emptyList();
        }

        // Check cache first
        String variableKey = variableName.toLowerCase();
        if (variableCaches.containsKey(variableKey)) {
            List<PsiElement> cachedResults = variableCaches.get(variableKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " variable results in cache for: " + variableName);
            return new ArrayList<>(cachedResults);
        }

        // Do a direct search
        HarbourLogger.log("ReferenceService", "Variable not found in cache, trying direct search for: " + variableName);
        List<PsiElement> result = directSearch(variableName, false);

        // Cache the result
        if (!result.isEmpty()) {
            variableCaches.put(variableKey, new ArrayList<>(result));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for variable: " + variableName);
        }

        return result;
    }

    /**
     * Find all symbols with the given name.
     * This includes functions, procedures, variables, etc.
     *
     * @param symbolName The name of the symbol to find
     * @return A list of PSI elements for the symbol declarations
     */
    public List<PsiElement> findSymbol(String symbolName) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of symbol: " + symbolName);

        if (symbolName == null || symbolName.isEmpty()) {
            return Collections.emptyList();
        }

        // Check cache first
        String symbolKey = symbolName.toLowerCase();
        if (symbolCaches.containsKey(symbolKey)) {
            List<PsiElement> cachedResults = symbolCaches.get(symbolKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " symbol results in cache for: " + symbolName);
            return new ArrayList<>(cachedResults);
        }

        // If not in symbol cache, look in function cache
        if (functionCaches.containsKey(symbolKey)) {
            List<PsiElement> cachedResults = functionCaches.get(symbolKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " function results in cache for symbol: " + symbolName);
            return new ArrayList<>(cachedResults);
        }

        // Check variable cache
        if (variableCaches.containsKey(symbolKey)) {
            List<PsiElement> cachedResults = variableCaches.get(symbolKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " variable results in cache for symbol: " + symbolName);
            return new ArrayList<>(cachedResults);
        }

        // Check class cache
        if (classCaches.containsKey(symbolKey)) {
            List<PsiElement> cachedResults = classCaches.get(symbolKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " class results in cache for symbol: " + symbolName);
            return new ArrayList<>(cachedResults);
        }

        // Do a direct search
        HarbourLogger.log("ReferenceService", "Symbol not found in cache, trying direct search for: " + symbolName);
        List<PsiElement> result = directSearch(symbolName, true);

        // Cache the result
        if (!result.isEmpty()) {
            symbolCaches.put(symbolKey, new ArrayList<>(result));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for symbol: " + symbolName);
        }

        return result;
    }

    /**
     * Find all class declarations with the given name.
     *
     * @param className The name of the class to find
     * @return A list of PSI elements for the class declarations
     */
    public List<PsiElement> findClasses(String className) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of class: " + className);

        if (className == null || className.isEmpty()) {
            return Collections.emptyList();
        }

        // Check cache first
        String classKey = className.toLowerCase();
        if (classCaches.containsKey(classKey)) {
            List<PsiElement> cachedResults = classCaches.get(classKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " class results in cache for: " + className);
            return new ArrayList<>(cachedResults);
        }

        // Do a direct search
        HarbourLogger.log("ReferenceService", "Class not found in cache, trying direct search for: " + className);
        List<PsiElement> result = directSearchForClass(className);

        // Cache the result
        if (!result.isEmpty()) {
            classCaches.put(classKey, new ArrayList<>(result));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for class: " + className);
        }

        return result;
    }

    /**
     * Find all methods of a specific class or related to a class name.
     *
     * @param className The name of the class
     * @param methodName Optional method name to filter by (can be null)
     * @return A list of PSI elements for the class methods
     */
    public List<PsiElement> findClassMethods(String className, String methodName) {
        HarbourLogger.log("ReferenceService", "Searching for methods of class: " + className +
                (methodName != null ? " with name: " + methodName : ""));

        if (className == null || className.isEmpty()) {
            return Collections.emptyList();
        }

        List<PsiElement> result = new ArrayList<>();

        // Get class declarations first
        List<PsiElement> classDeclarations = findClasses(className);

        HarbourLogger.log("ReferenceService", "Found " + classDeclarations.size() + " class declarations for: " + className);

        // If we have class declarations, look for methods within them
        for (PsiElement classDecl : classDeclarations) {
            if (classDecl instanceof ClassDeclaration) {
                ClassDeclaration declaration = (ClassDeclaration) classDecl;
                // Scan for METHOD declarations within the class
                String classText = declaration.getText();

                // Use regex to find METHOD declarations
                Pattern methodPattern = methodName != null
                        ? Pattern.compile("(?i)\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\b")
                        : Pattern.compile("(?i)\\bMETHOD\\s+\\w+");

                Matcher matcher = methodPattern.matcher(classText);
                while (matcher.find()) {
                    int offset = matcher.start() + classDecl.getTextOffset();
                    PsiElement methodElement = classDecl.getContainingFile().findElementAt(offset);

                    if (methodElement != null) {
                        result.add(methodElement);
                        HarbourLogger.log("ReferenceService", "Found method declaration in class " + className + ": " + methodElement.getText());
                    }
                }
            }
        }

        // Also search in the files containing these class declarations
        Set<PsiFile> classFiles = new HashSet<>();
        for (PsiElement classDecl : classDeclarations) {
            PsiFile file = classDecl.getContainingFile();
            if (file != null && file instanceof HarbourFile) {
                classFiles.add(file);
            }
        }

        for (PsiFile file : classFiles) {
            // Look for methods with this name in the same file as the class
            Collection<HarbourFunctionDeclaration> functionDeclarations =
                    PsiTreeUtil.findChildrenOfType(file, HarbourFunctionDeclaration.class);

            for (HarbourFunctionDeclaration decl : functionDeclarations) {
                // Check if this is a method declaration for our class and method
                String declText = decl.getText().toUpperCase();
                if (declText.contains("METHOD") && declText.contains(className.toUpperCase()) &&
                        (methodName == null || declText.contains(methodName.toUpperCase()))) {
                    result.add(decl);
                    HarbourLogger.log("ReferenceService", "Found method declaration in file for class " + className);
                }
            }
        }

        // Search for all variations of METHOD declarations:
        // 1. METHOD name CLASS className
        // 2. METHOD className:name
        // 3. Inside class {...} METHOD name
        List<PsiElement> directResults = new ArrayList<>();

        if (methodName != null) {
            // Pattern for "METHOD methodName CLASS className"
            Pattern pattern1 = Pattern.compile(
                    "\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\s+CLASS\\s+" + Pattern.quote(className),
                    Pattern.CASE_INSENSITIVE);

            // Pattern for "METHOD className:methodName"
            Pattern pattern2 = Pattern.compile(
                    "\\bMETHOD\\s+" + Pattern.quote(className) + "\\s*:\\s*" + Pattern.quote(methodName),
                    Pattern.CASE_INSENSITIVE);

            // Search all Harbour files
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

            for (VirtualFile virtualFile : virtualFiles) {
                // Skip excluded files
                if (isFileExcluded(virtualFile)) {
                    continue;
                }

                PsiFile psiFile = PsiManager.getInstance(project).findFile(virtualFile);
                if (psiFile == null) continue;

                String fileText = psiFile.getText();

                // Search for pattern 1
                Matcher matcher1 = pattern1.matcher(fileText);
                while (matcher1.find()) {
                    int offset = matcher1.start();
                    PsiElement element = psiFile.findElementAt(offset);
                    if (element != null) {
                        directResults.add(element);
                        HarbourLogger.log("ReferenceService", "Found method " + methodName +
                                " CLASS " + className + " at " + virtualFile.getName() + ":" + matcher1.start());
                    }
                }

                // Search for pattern 2
                Matcher matcher2 = pattern2.matcher(fileText);
                while (matcher2.find()) {
                    int offset = matcher2.start();
                    PsiElement element = psiFile.findElementAt(offset);
                    if (element != null) {
                        directResults.add(element);
                        HarbourLogger.log("ReferenceService", "Found method " + className + ":" +
                                methodName + " at " + virtualFile.getName() + ":" + matcher2.start());
                    }
                }
            }

            if (!directResults.isEmpty()) {
                HarbourLogger.log("ReferenceService", "Found " + directResults.size() +
                        " direct method references for " + className + ":" + methodName);
                result.addAll(directResults);
            }
        }

        HarbourLogger.log("ReferenceService", "Found " + result.size() + " methods for class: " + className);
        return result;
    }

    /**
     * Search for identifiers with the given name directly in all Harbour files.
     *
     * @param identifierName The name of the identifier to find
     * @param isFunction Whether to look for function declarations/calls or just identifiers
     * @return A list of PSI elements matching the identifier
     */
    private List<PsiElement> directSearch(String identifierName, boolean isFunction) {
        Instant start = Instant.now();
        List<PsiElement> results = new ArrayList<>();

        // Pattern for matching exact identifiers with word boundaries
        Pattern identifierPattern = Pattern.compile(
                "\\b" + Pattern.quote(identifierName) + "\\b", Pattern.CASE_INSENSITIVE);

        // Function specific patterns
        Pattern functionPattern = null;
        Pattern callPattern = null;

        if (isFunction) {
            // Create patterns for function and procedure declarations
            functionPattern = Pattern.compile(
                    "(?i)\\b(FUNCTION|PROCEDURE|METHOD)\\s+" + Pattern.quote(identifierName) + "\\b");

            // Create pattern for function calls
            callPattern = Pattern.compile(
                    "(?i)\\b" + Pattern.quote(identifierName) + "\\s*\\(");
        }

        try {
            // Get all Harbour files in the project
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

            PsiManager psiManager = PsiManager.getInstance(project);

            for (VirtualFile virtualFile : virtualFiles) {
                // Skip excluded files
                if (isFileExcluded(virtualFile)) {
                    continue;
                }

                // Process cancellation should be rethrown, not caught
                PsiFile psiFile = psiManager.findFile(virtualFile);
                if (psiFile == null) continue;

                // Get the file content
                String fileContent = psiFile.getText();

                if (isFunction && functionPattern != null && callPattern != null) {
                    // Look for function declarations
                    Matcher declarationMatcher = functionPattern.matcher(fileContent);
                    while (declarationMatcher.find()) {
                        int startOffset = declarationMatcher.start();
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null) {
                            // Try to get the full declaration
                            PsiElement declaration = null;

                            if (element.getText().equalsIgnoreCase("FUNCTION") ||
                                    element.getText().equalsIgnoreCase("PROCEDURE")) {
                                declaration = PsiTreeUtil.getParentOfType(element, HarbourFunctionDeclaration.class);
                            }

                            // If we found a declaration, add it
                            if (declaration != null) {
                                results.add(declaration);
                            } else {
                                // Otherwise, add the element itself
                                results.add(element);
                            }
                        }
                    }

                    // Look for function calls
                    Matcher callMatcher = callPattern.matcher(fileContent);
                    while (callMatcher.find()) {
                        int startOffset = callMatcher.start();
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null && element.getText().equalsIgnoreCase(identifierName)) {
                            // Check if this is a function call
                            PsiElement functionCall = PsiTreeUtil.getParentOfType(element, FunctionCallImpl.class);
                            if (functionCall != null) {
                                results.add(functionCall);
                            } else if (element instanceof LeafPsiElement &&
                                    ((LeafPsiElement) element).getElementType() == HarbourTypes.IDENT) {
                                // Add identifier elements too
                                results.add(element);
                            }
                        }
                    }
                }

                // For all identifiers (function identifiers and variable identifiers)
                Matcher identMatcher = identifierPattern.matcher(fileContent);
                while (identMatcher.find()) {
                    int startOffset = identMatcher.start();
                    PsiElement element = psiFile.findElementAt(startOffset);

                    if (element != null) {
                        // Check if this is an identifier
                        if (element instanceof LeafPsiElement) {
                            LeafPsiElement leafElement = (LeafPsiElement) element;
                            if (leafElement.getElementType() == HarbourTypes.IDENT &&
                                    leafElement.getText().equalsIgnoreCase(identifierName)) {
                                results.add(element);
                            }
                        }
                    }
                }
            }
        } catch (com.intellij.openapi.progress.ProcessCanceledException e) {
            // Rethrow ProcessCanceledException - these should never be caught and logged
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "Error during direct search: " + e.getMessage());
            // Log other exceptions without passing the exception object to avoid nested PCE issues
            LOG.error("Error during direct search for: " + identifierName);
        }

        Instant end = Instant.now();
        Duration duration = Duration.between(start, end);
        HarbourLogger.log("ReferenceService", "Direct search took: " + duration.toMillis() + "ms");

        return results;
    }

    /**
     * Search for class declarations with the given name directly in all Harbour files.
     *
     * @param className The name of the class to find
     * @return A list of PSI elements matching the class declaration
     */
    private List<PsiElement> directSearchForClass(String className) {
        Instant start = Instant.now();
        List<PsiElement> results = new ArrayList<>();

        // Pattern for matching class declarations
        Pattern classPattern = Pattern.compile(
                "(?i)\\bCLASS\\s+" + Pattern.quote(className) + "\\b");

        try {
            // Get all Harbour files in the project
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

            PsiManager psiManager = PsiManager.getInstance(project);

            for (VirtualFile virtualFile : virtualFiles) {
                // Skip excluded files
                if (isFileExcluded(virtualFile)) {
                    continue;
                }

                // Process cancellation should be rethrown, not caught
                PsiFile psiFile = psiManager.findFile(virtualFile);
                if (psiFile == null) continue;

                // Get the file content
                String fileContent = psiFile.getText();

                // Look for class declarations
                Matcher declarationMatcher = classPattern.matcher(fileContent);
                while (declarationMatcher.find()) {
                    int startOffset = declarationMatcher.start();
                    PsiElement element = psiFile.findElementAt(startOffset);

                    if (element != null) {
                        // Try to get the full class declaration
                        PsiElement declaration = null;

                        if (element.getText().equalsIgnoreCase("CLASS")) {
                            declaration = PsiTreeUtil.getParentOfType(element, ClassDeclaration.class);
                        }

                        // If we found a declaration, add it
                        if (declaration != null) {
                            results.add(declaration);
                        } else {
                            // Otherwise, add the element itself
                            results.add(element);
                        }
                    }
                }
            }
        } catch (com.intellij.openapi.progress.ProcessCanceledException e) {
            // Rethrow ProcessCanceledException - these should never be caught and logged
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "Error during class direct search: " + e.getMessage());
            // Log other exceptions without passing the exception object to avoid nested PCE issues
            LOG.error("Error during direct search for class: " + className);
        }

        Instant end = Instant.now();
        Duration duration = Duration.between(start, end);
        HarbourLogger.log("ReferenceService", "Direct class search took: " + duration.toMillis() + "ms");

        return results;
    }

    /**
     * Search for method declarations related to a class directly in all Harbour files.
     *
     * @param className The name of the class
     * @param methodName The name of the method to find
     * @return A list of PSI elements matching the method declaration
     */
    private List<PsiElement> directSearchForMethod(String className, String methodName) {
        Instant start = Instant.now();
        List<PsiElement> results = new ArrayList<>();

        // Pattern for matching method declarations in class context
        Pattern methodPattern = Pattern.compile(
                "(?i)\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\s+CLASS\\s+" +
                        Pattern.quote(className) + "\\b");

        // Alternative pattern for Harbour-style method declarations
        Pattern methodPattern2 = Pattern.compile(
                "(?i)\\bMETHOD\\s+" + Pattern.quote(className) + ":" +
                        Pattern.quote(methodName) + "\\b");

        // Pattern for METHOD declarations in ClassDeclaration blocks
        Pattern classBlockPattern = Pattern.compile(
                "(?i)\\bCLASS\\s+" + Pattern.quote(className) + "\\b.*?\\bMETHOD\\s+" +
                        Pattern.quote(methodName) + "\\b",
                Pattern.DOTALL);

        try {
            // Get all Harbour files in the project
            Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                    HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

            PsiManager psiManager = PsiManager.getInstance(project);

            for (VirtualFile virtualFile : virtualFiles) {
                // Skip excluded files
                if (isFileExcluded(virtualFile)) {
                    continue;
                }

                // Process cancellation should be rethrown, not caught
                PsiFile psiFile = psiManager.findFile(virtualFile);
                if (psiFile == null) continue;

                // Get the file content
                String fileContent = psiFile.getText();

                // Check if this file contains the CLASS declaration
                if (!fileContent.toUpperCase().contains("CLASS " + className.toUpperCase())) {
                    // Skip files that don't contain the class declaration
                    continue;
                }

                // Look for class block pattern first (most accurate)
                Matcher classBlockMatcher = classBlockPattern.matcher(fileContent);
                while (classBlockMatcher.find()) {
                    String matchText = classBlockMatcher.group(0);
                    int methodPos = matchText.toUpperCase().lastIndexOf("METHOD " + methodName.toUpperCase());
                    if (methodPos >= 0) {
                        int startOffset = classBlockMatcher.start() + methodPos;
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null && element.getText().equalsIgnoreCase("METHOD")) {
                            // Find the method identifier after METHOD keyword
                            PsiElement nextElement = element.getNextSibling();
                            while (nextElement != null &&
                                    !(nextElement instanceof LeafPsiElement &&
                                            ((LeafPsiElement)nextElement).getElementType() == HarbourTypes.IDENT &&
                                            nextElement.getText().equalsIgnoreCase(methodName))) {
                                nextElement = nextElement.getNextSibling();
                            }

                            if (nextElement != null) {
                                // This is a confirmed method declaration inside the class
                                results.add(nextElement);
                                HarbourLogger.log("ReferenceService", "Found class method declaration: " +
                                        nextElement.getText() + " in class " + className);
                            } else {
                                // Fallback to the METHOD keyword
                                results.add(element);
                            }
                        }
                    }
                }

                // Check for explicit method patterns if we haven't found anything
                if (results.isEmpty()) {
                    // Look for method declarations with first pattern
                    Matcher declarationMatcher = methodPattern.matcher(fileContent);
                    while (declarationMatcher.find()) {
                        int startOffset = declarationMatcher.start();
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null && element.getText().equalsIgnoreCase("METHOD")) {
                            // Get the next element which should be the method name
                            PsiElement nextElement = element.getNextSibling();
                            while (nextElement != null &&
                                    !(nextElement instanceof LeafPsiElement &&
                                            ((LeafPsiElement)nextElement).getElementType() == HarbourTypes.IDENT &&
                                            nextElement.getText().equalsIgnoreCase(methodName))) {
                                nextElement = nextElement.getNextSibling();
                            }

                            if (nextElement != null) {
                                // Verified the method name matches
                                results.add(nextElement);
                                HarbourLogger.log("ReferenceService", "Found method " + methodName +
                                        " CLASS " + className + " declaration");
                            } else {
                                results.add(element);
                            }
                        }
                    }

                    // Look for method declarations with second pattern
                    declarationMatcher = methodPattern2.matcher(fileContent);
                    while (declarationMatcher.find()) {
                        int startOffset = declarationMatcher.start();
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null && element.getText().equalsIgnoreCase("METHOD")) {
                            // For this pattern we need to check className:methodName after METHOD
                            int colonPos = declarationMatcher.group(0).indexOf(':');
                            if (colonPos > 0) {
                                PsiElement nextElement = element.getNextSibling();
                                while (nextElement != null &&
                                        !nextElement.getText().contains(":")) {
                                    nextElement = nextElement.getNextSibling();
                                }

                                if (nextElement != null) {
                                    String text = nextElement.getText();
                                    if (text.toLowerCase().startsWith(className.toLowerCase()) &&
                                            text.toLowerCase().contains(":" + methodName.toLowerCase())) {
                                        results.add(element); // Add the METHOD keyword
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (com.intellij.openapi.progress.ProcessCanceledException e) {
            // Rethrow ProcessCanceledException - these should never be caught and logged
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "Error during method direct search: " + e.getMessage());
            // Log other exceptions without passing the exception object to avoid nested PCE issues
            LOG.error("Error during direct search for method: " + methodName + " of class: " + className);
        }

        Instant end = Instant.now();
        Duration duration = Duration.between(start, end);
        HarbourLogger.log("ReferenceService", "Direct method search took: " + duration.toMillis() + "ms");

        return results;
    }

    /**
     * Update the cache with new declarations for a function.
     */
    public void updateCache(String functionName, List<PsiElement> declarations) {
        if (functionName == null || functionName.isEmpty()) return;

        String functionKey = functionName.toLowerCase();
        functionCaches.put(functionKey, new ArrayList<>(declarations));
        HarbourLogger.log("ReferenceService", "Updated cache for: " + functionName + " with " + declarations.size() + " declarations");
    }

    /**
     * Update the cache with new usages for a variable.
     */
    public void updateVariableCache(String variableName, List<PsiElement> usages) {
        if (variableName == null || variableName.isEmpty()) return;

        String variableKey = variableName.toLowerCase();
        variableCaches.put(variableKey, new ArrayList<>(usages));
        HarbourLogger.log("ReferenceService", "Updated variable cache for: " + variableName + " with " + usages.size() + " usages");
    }

    /**
     * Update the cache with new declarations for a class.
     */
    public void updateClassCache(String className, List<PsiElement> declarations) {
        if (className == null || className.isEmpty()) return;

        String classKey = className.toLowerCase();
        classCaches.put(classKey, new ArrayList<>(declarations));
        HarbourLogger.log("ReferenceService", "Updated class cache for: " + className + " with " + declarations.size() + " declarations");
    }

    /**
     * Clear the function cache.
     */
    public void clearCache() {
        functionCaches.clear();
        symbolCaches.clear();
        variableCaches.clear();
        classCaches.clear();
        indexed = false;
        HarbourLogger.log("ReferenceService", "All caches cleared");
    }

    /**
     * Force clear all caches.
     */
    public void forceClearCaches() {
        clearCache();
        HarbourLogger.log("ReferenceService", "All caches forcibly cleared");
    }

    /**
     * Check if an element is valid for rename operation.
     *
     * @param element The element to check
     * @return True if the element can be renamed
     */
    public boolean isValidForRename(PsiElement element) {
        if (element == null || !element.isValid()) {
            return false;
        }

        // Check if this is an identifier
        if (element instanceof LeafPsiElement) {
            LeafPsiElement leafElement = (LeafPsiElement) element;

            // Only identifiers can be renamed
            if (leafElement.getElementType() == HarbourTypes.IDENT) {
                return true;
            }
        }

        // Check for function declarations and other renameable elements
        if (element instanceof HarbourFunctionDeclaration) {
            return true;
        }

        return false;
    }

    /**
     * Find all variable elements for rename operation.
     *
     * @param variableName The name of the variable to find
     * @return A list of PSI elements for the variable usages
     */
    public List<PsiElement> findVariablesForRename(String variableName) {
        return findVariables(variableName);
    }

    /**
     * Find all function elements for rename operation.
     *
     * @param functionName The name of the function to find
     * @return A list of PSI elements for the function declarations/calls
     */
    public List<PsiElement> findFunctionsForRename(String functionName) {
        return findFunctions(functionName);
    }

    /**
     * Find all symbol elements for rename operation.
     *
     * @param symbolName The name of the symbol to find
     * @return A list of PSI elements for the symbol occurrences
     */
    public List<PsiElement> findSymbolForRename(String symbolName) {
        return findSymbol(symbolName);
    }

    /**
     * Check if a function name is in the cache.
     */
    public boolean isCached(String functionName) {
        if (functionName == null || functionName.isEmpty()) return false;
        return functionCaches.containsKey(functionName.toLowerCase());
    }

    /**
     * Check if a variable name is in the cache.
     */
    public boolean isVariableCached(String variableName) {
        if (variableName == null || variableName.isEmpty()) return false;
        return variableCaches.containsKey(variableName.toLowerCase());
    }

    /**
     * Check if a class name is in the cache.
     */
    public boolean isClassCached(String className) {
        if (className == null || className.isEmpty()) return false;
        return classCaches.containsKey(className.toLowerCase());
    }

    /**
     * Register functions found in a Harbour file to the cache.
     */
    public void registerFunctions(HarbourFile file) {
        HarbourLogger.log("ReferenceService", "Registering functions from file: " + file.getName());

        // Implementation would scan the file for function declarations
        // and add them to the cache. Simplified version for now.
        Collection<HarbourFunctionDeclaration> declarations = PsiTreeUtil.findChildrenOfType(file, HarbourFunctionDeclaration.class);
        for (HarbourFunctionDeclaration declaration : declarations) {
            String name = declaration.getName();
            if (name != null && !name.isEmpty()) {
                List<PsiElement> elements = new ArrayList<>();
                elements.add(declaration);
                updateCache(name, elements);
            }
        }
    }

    /**
     * Register classes found in a Harbour file to the cache.
     */
    public void registerClasses(HarbourFile file) {
        HarbourLogger.log("ReferenceService", "Registering classes from file: " + file.getName());

        // Find all CLASS declarations in the file
        Collection<ClassDeclaration> declarations = PsiTreeUtil.findChildrenOfType(file, ClassDeclaration.class);
        for (ClassDeclaration declaration : declarations) {
            // Get the name from CLASS element - search for first IDENT after CLASS keyword
            PsiElement[] children = declaration.getChildren();
            PsiElement nameElement = null;
            for (PsiElement child : children) {
                if (child.getNode() != null && child.getNode().getElementType() == HarbourTypes.IDENT) {
                    nameElement = child;
                    break;
                }
            }

            String name = nameElement != null ? nameElement.getText() : null;

            if (name != null && !name.isEmpty()) {
                List<PsiElement> elements = new ArrayList<>();
                elements.add(declaration);
                updateClassCache(name, elements);
            }
        }
    }

    /**
     * Register procedures found in a Harbour file to the cache.
     */
    public void registerProcedures(HarbourFile file) {
        HarbourLogger.log("ReferenceService", "Registering procedures from file: " + file.getName());

        // Similar to registerFunctions but for procedures
        // Simplified implementation for now
    }

    /**
     * Process file changes to update the cache.
     */
    public void fileChanged(HarbourFile file) {
        HarbourLogger.log("ReferenceService", "Processing file change: " + file.getName());

        // Clear all caches related to this file
        forceClearCaches();

        // Register functions, procedures and classes
        registerFunctions(file);
        registerProcedures(file);
        registerClasses(file);

        // Trigger progressive indexer to update in background
        ApplicationManager.getApplication().invokeLater(() -> {
            if (!project.isDisposed()) {
                HarbourProgressiveIndexer.reindexFile(project, file.getVirtualFile());
            }
        });

        HarbourLogger.log("ReferenceService", "Completed re-indexing of changed file: " + file.getName());
    }

    /**
     * Check if a file is excluded from indexing based on its full path.
     */
    public boolean isExcluded(VirtualFile file) {
        if (file == null) return false;

        String path = file.getPath();
        if (excludedFiles.contains(path)) {
            return true;
        }

        // Also check by filename
        String filename = file.getName();
        return excludedFilenames.contains(filename);
    }

    /**
     * Check if a file should be excluded from navigation based on its filename.
     */
    public boolean isFileExcluded(VirtualFile file) {
        return HarbourFileUtils.isFileExcluded(project, file);
    }

    /**
     * Refresh the exclusion list from settings.
     */
    public void refreshExclusions() {
        HarbourLogger.log("ReferenceService", "Refreshing exclusion list from settings");

        // Clear existing exclusions
        excludedFiles.clear();
        excludedFilenames.clear();

        // Load exclusions from HarbourSettings
        HarbourSettings settings = HarbourSettings.getInstance(project);
        Set<String> excludedFileSettings = settings.getExcludedFiles();

        // Add filenames to our local set
        for (String filename : excludedFileSettings) {
            excludedFilenames.add(filename);
            HarbourLogger.log("ReferenceService", "Added excluded filename: " + filename);
        }

        HarbourLogger.log("ReferenceService", "Loaded " + excludedFilenames.size() + " excluded files from settings");
    }

    /**
     * Initializer for the service that runs on project startup.
     */
    public static class HarbourReferenceServiceInitializer implements StartupActivity.DumbAware {
        @Override
        public void runActivity(@NotNull Project project) {
            System.err.println("*** HARBOUR REFERENCE SERVICE INITIALIZER CALLED ***");
            HarbourLogger.log("ReferenceService", "Registering class method reference provider");

            // Initialize the service
            HarbourReferenceService service = getInstance(project);

            // Load exclusions
            service.refreshExclusions();

            // Register mouse listener to detect real clicks vs hover
            ApplicationManager.getApplication().invokeLater(() -> {
                try {
                    HarbourMouseListener listener = new HarbourMouseListener();
                    EditorFactory.getInstance().getEventMulticaster().addEditorMouseListener(listener, project);
                    EditorFactory.getInstance().getEventMulticaster().addEditorMouseMotionListener(listener, project);
                    System.err.println("*** HARBOUR MOUSE LISTENER REGISTERED SUCCESSFULLY ***");
                    HarbourLogger.log("ReferenceService", "Harbour mouse listener registered successfully");
                } catch (Exception e) {
                    System.err.println("*** FAILED TO REGISTER MOUSE LISTENER: " + e.getMessage());
                    HarbourLogger.log("ReferenceService", "Failed to register Harbour mouse listener: " + e.getMessage());
                }
            });

        }
    }
}
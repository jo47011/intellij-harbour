package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.components.Service;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.EditorFactory;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.PsiRecursiveElementVisitor;
import com.intellij.psi.PsiWhiteSpace;
import com.intellij.psi.impl.FakePsiElement;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.stubs.StubIndex;
import com.intellij.psi.util.PsiTreeUtil;
import com.intellij.util.indexing.FileBasedIndex;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.HarbourProcedureDeclaration;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.intellij.sdk.language.index.HarbourFunctionIndex;
import org.intellij.sdk.language.psi.stub.HarbourFunctionNameIndex;
import org.intellij.sdk.language.psi.stub.HarbourProcedureNameIndex;
import org.intellij.sdk.language.psi.stub.HarbourClassNameIndex;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.openapi.editor.Document;
import org.intellij.sdk.language.index.HarbourFunctionIndex;

/**
 * Service for resolving references to functions and methods in the Harbour language.
 * This service indexes all function declarations in the project and provides methods
 * to find them by name.
 */
@Service(Service.Level.PROJECT)
public final class HarbourReferenceService {
    private static final Logger LOG = Logger.getInstance(HarbourReferenceService.class);
    
    // Result limits - configurable via settings
    private static final int MAX_CACHE_SIZE = 1000;
    private static final int MAX_DEFINITIONS = 5;  // Limit definitions to show

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
        // Load excluded files from settings on initialization
        refreshExclusions();
    }

    /**
     * Find all functions with the given name using StubIndex for fast lookup.
     *
     * @param functionName The name of the function to find
     * @return A list of PSI elements for the function declarations
     */
    public List<PsiElement> findFunctions(String functionName) {
        return findFunctions(functionName, false);
    }
    
    /**
     * Find all #define declarations with the given name.
     *
     * @param defineName The name of the #define to find
     * @return A list of PSI elements for the #define declarations
     */
    public List<PsiElement> findDefines(String defineName) {
        HarbourLogger.log("ReferenceService", "Searching for #define: " + defineName);

        if (defineName == null || defineName.isEmpty()) {
            return Collections.emptyList();
        }

        List<PsiElement> result = new ArrayList<>();
        Pattern definePattern = Pattern.compile("(?i)^\\s*#\\s*define\\s+" + Pattern.quote(defineName) + "(?:\\s|\\()", Pattern.MULTILINE);

        // 1. Search in project files
        Collection<VirtualFile> allFiles = FileTypeIndex.getFiles(HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));
        result.addAll(searchDefinesInFiles(allFiles, defineName, definePattern));

        // 2. Search in include paths (e.g., /home/developer/workspace/harbour/include)
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings != null && settings.getIncludePaths() != null) {
            for (String includePath : settings.getIncludePaths()) {
                result.addAll(searchDefinesInIncludePath(includePath, defineName, definePattern));
            }
        }

        HarbourLogger.log("ReferenceService", "Found " + result.size() + " #define declarations for: " + defineName);
        return result;
    }

    /**
     * Search for #define in a collection of VirtualFiles
     */
    private List<PsiElement> searchDefinesInFiles(Collection<VirtualFile> files, String defineName, Pattern definePattern) {
        List<PsiElement> result = new ArrayList<>();

        for (VirtualFile file : files) {
            PsiFile psiFile = PsiManager.getInstance(project).findFile(file);
            if (psiFile != null) {
                result.addAll(searchDefinesInPsiFile(psiFile, defineName, definePattern));
            }
        }

        return result;
    }

    /**
     * Search for #define in include path directory
     */
    private List<PsiElement> searchDefinesInIncludePath(String includePath, String defineName, Pattern definePattern) {
        List<PsiElement> result = new ArrayList<>();

        try {
            java.io.File includeDir = new java.io.File(includePath);
            if (!includeDir.exists() || !includeDir.isDirectory()) {
                return result;
            }

            // Search for .ch files in include path
            java.io.File[] chFiles = includeDir.listFiles((dir, name) ->
                name.toLowerCase().endsWith(".ch") || name.toLowerCase().endsWith(".h"));

            if (chFiles != null) {
                for (java.io.File chFile : chFiles) {
                    VirtualFile vFile = com.intellij.openapi.vfs.LocalFileSystem.getInstance().findFileByIoFile(chFile);
                    if (vFile != null) {
                        PsiFile psiFile = PsiManager.getInstance(project).findFile(vFile);
                        if (psiFile != null) {
                            result.addAll(searchDefinesInPsiFile(psiFile, defineName, definePattern));
                        }
                    }
                }
                HarbourLogger.log("ReferenceService", "Searched " + chFiles.length + " .ch files in " + includePath);
            }
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "Error searching include path " + includePath + ": " + e.getMessage());
        }

        return result;
    }

    /**
     * Search for #define declarations in a single PSI file
     */
    private List<PsiElement> searchDefinesInPsiFile(PsiFile psiFile, String defineName, Pattern definePattern) {
        List<PsiElement> result = new ArrayList<>();

        String content = psiFile.getText();
        String[] lines = content.split("\n");

        for (int i = 0; i < lines.length; i++) {
            Matcher matcher = definePattern.matcher(lines[i]);
            if (matcher.find()) {
                // Find the PSI element at this line
                int lineStartOffset = getLineStartOffset(content, i);
                int defineNameStart = lineStartOffset + matcher.end() - defineName.length();
                PsiElement element = psiFile.findElementAt(defineNameStart);

                if (element != null) {
                    result.add(element);
                    HarbourLogger.log("ReferenceService", "Found #define " + defineName + " in " + psiFile.getName() + " at line " + (i + 1));
                }
            }
        }

        return result;
    }
    
    private int getLineStartOffset(String content, int lineNumber) {
        int offset = 0;
        int currentLine = 0;
        for (int i = 0; i < content.length() && currentLine < lineNumber; i++) {
            if (content.charAt(i) == '\n') {
                currentLine++;
                if (currentLine == lineNumber) {
                    offset = i + 1;
                    break;
                }
            }
        }
        return offset;
    }
    
    /**
     * Find all functions with the given name using StubIndex for fast lookup.
     *
     * @param functionName The name of the function to find
     * @param getAllResults If true, returns all results without limit
     * @return A list of PSI elements for the function declarations
     */
    public List<PsiElement> findFunctions(String functionName, boolean getAllResults) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of function: " + functionName + 
            (getAllResults ? " (getting ALL results)" : " (limited results)"));

        if (functionName == null || functionName.isEmpty()) {
            return Collections.emptyList();
        }
        
        // Try the enhanced FileBasedIndex first (includes both declarations and usages)
        List<PsiElement> indexResults = searchUsingEnhancedIndex(functionName, getAllResults);
        if (indexResults != null && !indexResults.isEmpty()) {
            HarbourLogger.log("ReferenceService", "Found " + indexResults.size() + " results via enhanced index for: " + functionName);
            return indexResults;
        }
        
        // If index is not available or empty, continue with cache and direct search
        HarbourLogger.log("ReferenceService", "Enhanced index not available or empty for: " + functionName + ", falling back to direct search");
        
        // Log runtime cache state
        if (functionCaches.containsKey(functionName.toLowerCase())) {
            HarbourLogger.log("ReferenceService", "Found in runtime cache: " + functionName + " with " +
                    functionCaches.get(functionName.toLowerCase()).size() + " results");
        } else {
            HarbourLogger.log("ReferenceService", "Not in runtime cache: " + functionName);
        }

        // Check runtime cache
        String functionKey = functionName.toLowerCase();
        if (functionCaches.containsKey(functionKey)) {
            List<PsiElement> cachedResults = functionCaches.get(functionKey);
            if (!cachedResults.isEmpty()) {
                HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " results in cache for: " + functionName);
                return new ArrayList<>(cachedResults);
            }
            // Cache exists but is empty, fall through to perform search
            HarbourLogger.log("ReferenceService", "Cache exists but is empty for: " + functionName + ", performing search");
        }

        HarbourLogger.log("ReferenceService", "Function not found in cache, trying direct search for: " + functionName);
        List<PsiElement> result = directSearch(functionName, true, getAllResults);

        // Cache the result (limit cache size to prevent memory issues)
        if (!result.isEmpty()) {
            List<PsiElement> toCache = result.size() > MAX_CACHE_SIZE ? 
                result.subList(0, MAX_CACHE_SIZE) : result;
            functionCaches.put(functionKey, new ArrayList<>(toCache));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for: " + functionName + 
                " (cached " + toCache.size() + ")");
            
            // Check cache sizes periodically
            checkCacheSizes();
        }

        // Detailed result logging removed for performance

        return result;
    }

    /**
     * Find all variables with the given name.
     *
     * @param variableName The name of the variable to find
     * @return A list of PSI elements for the variable usages
     */
    public List<PsiElement> findVariables(String variableName) {
        return findVariables(variableName, false);
    }
    
    /**
     * Find all variables with the given name.
     *
     * @param variableName The name of the variable to find
     * @param getAllResults If true, returns all results without limit
     * @return A list of PSI elements for the variable usages
     */
    public List<PsiElement> findVariables(String variableName, boolean getAllResults) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of variable: " + variableName);

        if (variableName == null || variableName.isEmpty()) {
            return Collections.emptyList();
        }

        // Note: Variables are typically local and not persisted in cache
        // We only use runtime cache for variables
        
        // Check runtime cache first
        String variableKey = variableName.toLowerCase();
        if (variableCaches.containsKey(variableKey)) {
            List<PsiElement> cachedResults = variableCaches.get(variableKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " variable results in cache for: " + variableName);
            return new ArrayList<>(cachedResults);
        }

        // Do a direct search
        HarbourLogger.log("ReferenceService", "Variable not found in cache, trying direct search for: " + variableName);
        List<PsiElement> result = directSearch(variableName, false, getAllResults);

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
        return findSymbol(symbolName, false);
    }
    
    /**
     * Find all symbols with the given name.
     * This includes functions, procedures, variables, etc.
     *
     * @param symbolName The name of the symbol to find
     * @param getAllResults If true, returns all results without limit
     * @return A list of PSI elements for the symbol declarations
     */
    public List<PsiElement> findSymbol(String symbolName, boolean getAllResults) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of symbol: " + symbolName);

        if (symbolName == null || symbolName.isEmpty()) {
            return Collections.emptyList();
        }

        // Skip persistent cache check since convertCacheEntriesToPsiElements is disabled
        // Go directly to runtime caches

        // Check runtime cache
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
        List<PsiElement> result = directSearch(symbolName, true, getAllResults);

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

        // Skip persistent cache check since convertCacheEntriesToPsiElements is disabled

        // Check runtime cache
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
     * Find all procedure declarations with the given name.
     *
     * @param procedureName The name of the procedure to find
     * @return A list of PSI elements for the procedure declarations
     */
    public List<PsiElement> findProcedures(String procedureName) {
        HarbourLogger.log("ReferenceService", "Searching for all occurrences of procedure: " + procedureName);

        if (procedureName == null || procedureName.isEmpty()) {
            return Collections.emptyList();
        }

        // Skip persistent cache check since convertCacheEntriesToPsiElements is disabled

        // For now, procedures are indexed the same as functions
        // in the runtime cache
        String procedureKey = procedureName.toLowerCase();
        if (functionCaches.containsKey(procedureKey)) {
            List<PsiElement> cachedResults = functionCaches.get(procedureKey);
            HarbourLogger.log("ReferenceService", "Found " + cachedResults.size() + " procedure results in cache for: " + procedureName);
            return new ArrayList<>(cachedResults);
        }

        // Do a direct search
        HarbourLogger.log("ReferenceService", "Procedure not found in cache, trying direct search for: " + procedureName);
        List<PsiElement> result = directSearch(procedureName, true);

        // Cache the result
        if (!result.isEmpty()) {
            functionCaches.put(procedureKey, new ArrayList<>(result));
            HarbourLogger.log("ReferenceService", "Direct search found " + result.size() + " results for procedure: " + procedureName);
        }

        return result;
    }

    /**
     * Find DATA fields in a given class.
     *
     * @param className The name of the class  
     * @param fieldName The name of the DATA field
     * @return A list of PSI elements for the DATA field declarations
     */
    public List<PsiElement> findDataFields(String className, String fieldName) {
        HarbourLogger.log("ReferenceService", "Searching for DATA field: " + fieldName + " in class: " + className);
        
        if (className == null || className.isEmpty() || fieldName == null || fieldName.isEmpty()) {
            return Collections.emptyList();
        }
        
        List<PsiElement> result = new ArrayList<>();
        
        // Get class declarations first
        List<PsiElement> classDeclarations = findClasses(className);
        HarbourLogger.log("ReferenceService", "Found " + classDeclarations.size() + " class declarations for: " + className);
        
        // Search for DATA fields in each class file
        for (PsiElement classDecl : classDeclarations) {
            PsiFile containingFile = classDecl.getContainingFile();
            if (containingFile == null) continue;
            
            // Search for DATA fieldName patterns in the file
            String fileText = containingFile.getText();
            if (fileText == null) continue;
            
            // Look for DATA fieldName pattern
            String[] lines = fileText.split("\n");
            for (int i = 0; i < lines.length; i++) {
                String line = lines[i].trim();
                
                // Match patterns like:
                // DATA fieldName
                // DATA fieldName INIT value
                // DATA fieldName READONLY
                if (line.toUpperCase().startsWith("DATA ")) {
                    String dataLine = line.substring(5).trim(); // Remove "DATA "
                    
                    // Extract the field name (first word after DATA)
                    String[] parts = dataLine.split("\\s+");
                    if (parts.length > 0 && parts[0].equalsIgnoreCase(fieldName)) {
                        // Found a matching DATA field
                        // Try to find the exact PSI element
                        int lineStartOffset = getLineStartOffset(fileText, i);
                        PsiElement element = containingFile.findElementAt(lineStartOffset + line.indexOf(fieldName));
                        
                        if (element != null) {
                            // Get the identifier element
                            while (element != null && !(element instanceof LeafPsiElement && 
                                   ((LeafPsiElement)element).getElementType() == HarbourTypes.IDENT &&
                                   element.getText().equalsIgnoreCase(fieldName))) {
                                element = element.getNextSibling();
                            }
                            
                            if (element != null) {
                                HarbourLogger.log("ReferenceService", "Found DATA field: " + fieldName + " at line " + (i + 1));
                                result.add(element);
                            }
                        }
                    }
                }
            }
        }
        
        HarbourLogger.log("ReferenceService", "Found " + result.size() + " DATA field declarations for: " + className + ":" + fieldName);
        return result;
    }
    
    /**
     * Calculate the offset of the start of a line
     */

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
        Set<PsiFile> classFiles = new HashSet<>();

        // Get class declarations first
        List<PsiElement> classDeclarations = findClasses(className);

        HarbourLogger.log("ReferenceService", "Found " + classDeclarations.size() + " class declarations for: " + className);

        // If we have class declarations, look for methods within them
        for (PsiElement classDecl : classDeclarations) {
            // Handle both ClassDeclaration and raw elements
            PsiFile containingFile = classDecl.getContainingFile();
            if (containingFile == null) {
                continue;
            }
            
            // Add the file to search for methods
            if (containingFile instanceof HarbourFile) {
                classFiles.add(containingFile);
            }
            
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
                    
                    // Comment checking disabled for performance
                    
                    PsiElement methodElement = classDecl.getContainingFile().findElementAt(offset);

                    if (methodElement != null) {
                        result.add(methodElement);
                        HarbourLogger.log("ReferenceService", "Found method declaration in class " + className + ": " + methodElement.getText());
                    }
                }
            }
        }

        // Also search in the files containing these class declarations
        for (PsiFile file : classFiles) {
            // Direct text search for METHOD declarations in the file
            String fileText = file.getText();
            Pattern methodPattern = methodName != null
                    ? Pattern.compile("(?i)\\bMETHOD\\s+" + Pattern.quote(methodName) + "\\b")
                    : Pattern.compile("(?i)\\bMETHOD\\s+\\w+");
            
            Matcher matcher = methodPattern.matcher(fileText);
            while (matcher.find()) {
                int offset = matcher.start();
                
                // Comment checking disabled for performance
                
                PsiElement methodElement = file.findElementAt(offset);
                
                if (methodElement != null) {
                    result.add(methodElement);
                    HarbourLogger.log("ReferenceService", "Found method declaration in file for class " + className + " at offset " + offset);
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
                    
                    // Comment checking disabled for performance
                    
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
                    
                    // Comment checking disabled for performance
                    
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
     * Check if a given offset position is inside a comment
     * OPTIMIZED: Removed expensive operations for performance
     */
    private boolean isLineComment(String fileText, int offset, String filename) {
        if (fileText == null || offset < 0 || offset >= fileText.length()) {
            return false;
        }
        
        // Quick check for comment markers before the offset
        // Check previous characters for // or /*
        if (offset >= 2) {
            if (fileText.charAt(offset - 2) == '/' && 
                (fileText.charAt(offset - 1) == '/' || fileText.charAt(offset - 1) == '*')) {
                return true;
            }
        }
        
        // Find the start of the line - but limit search to 200 chars back for performance
        int lineStart = Math.max(0, offset - 200);
        for (int i = offset - 1; i >= lineStart; i--) {
            if (fileText.charAt(i) == '\n') {
                lineStart = i + 1;
                break;
            }
        }
        
        // Quick check if line starts with comment
        if (lineStart < fileText.length() - 2) {
            char c1 = fileText.charAt(lineStart);
            if (c1 == '/' && lineStart + 1 < fileText.length()) {
                char c2 = fileText.charAt(lineStart + 1);
                if (c2 == '/' || c2 == '*') return true;
            }
            if (c1 == '*' || c1 == ' ' || c1 == '\t') {
                // Skip whitespace
                int pos = lineStart;
                while (pos < offset && pos < fileText.length() && 
                       (fileText.charAt(pos) == ' ' || fileText.charAt(pos) == '\t')) {
                    pos++;
                }
                if (pos < fileText.length() - 1) {
                    if (fileText.charAt(pos) == '*') return true;
                    if (fileText.charAt(pos) == '/' && pos + 1 < fileText.length() &&
                        (fileText.charAt(pos + 1) == '/' || fileText.charAt(pos + 1) == '*')) {
                        return true;
                    }
                }
            }
        }
        
        return false;
    }
    
    /**
     * Search using the enhanced FileBasedIndex that indexes both declarations and usages.
     * Returns null if the index is not available or on error.
     */
    @Nullable
    private List<PsiElement> searchUsingEnhancedIndex(String functionName, boolean getAllResults) {
        try {
            Instant start = Instant.now();
            List<PsiElement> declarations = new ArrayList<>();
            List<PsiElement> usages = new ArrayList<>();
            
            FileBasedIndex index = FileBasedIndex.getInstance();
            String searchKey = functionName.toLowerCase();
            GlobalSearchScope scope = GlobalSearchScope.projectScope(project);
            
            // Get the current element's file for smart ordering
            VirtualFile currentFile = null; // TODO: Get from context if available
            
            // Optimized: Get all keys once and filter them into a list
            // This avoids repeated filtering in nested loops
            Collection<String> allKeys = index.getAllKeys(HarbourFunctionIndex.INDEX_ID, project);
            List<String> matchingKeys = new ArrayList<>();
            Map<VirtualFile, List<String>> fileToKeys = new HashMap<>();
            
            // Filter keys and build file-to-keys mapping in a single pass
            for (String key : allKeys) {
                if (key.startsWith(searchKey + "#") || key.equals(searchKey)) {
                    matchingKeys.add(key);
                    
                    // Get files for this key and map them
                    Collection<VirtualFile> files = index.getContainingFiles(
                        HarbourFunctionIndex.INDEX_ID, key, scope);
                    for (VirtualFile file : files) {
                        fileToKeys.computeIfAbsent(file, k -> new ArrayList<>()).add(key);
                    }
                }
            }
            
            if (fileToKeys.isEmpty()) {
                HarbourLogger.log("ReferenceService", "No files found in index for: " + functionName);
                return null;
            }
            
            PsiManager psiManager = PsiManager.getInstance(project);
            
            // Process each file with its associated keys
            for (Map.Entry<VirtualFile, List<String>> entry : fileToKeys.entrySet()) {
                VirtualFile file = entry.getKey();
                List<String> keysForFile = entry.getValue();
                
                // Skip excluded files
                if (isFileExcluded(file)) {
                    continue;
                }
                
                PsiFile psiFile = psiManager.findFile(file);
                if (psiFile == null) continue;
                
                Document document = PsiDocumentManager.getInstance(project).getDocument(psiFile);
                if (document == null) continue;
                
                // Process only the keys that are actually in this file
                for (String key : keysForFile) {
                    index.processValues(
                        HarbourFunctionIndex.INDEX_ID,
                        key,
                        file,
                        (vf, info) -> {
                            if (info.lineNumber > 0 && info.lineNumber <= document.getLineCount()) {
                                int lineStartOffset = document.getLineStartOffset(info.lineNumber - 1);
                                
                                // Find the element at this line
                                PsiElement element = psiFile.findElementAt(lineStartOffset);
                                
                                // Navigate to the actual identifier
                                while (element != null) {
                                    if (element instanceof LeafPsiElement &&
                                        ((LeafPsiElement)element).getElementType() == HarbourTypes.IDENT &&
                                        element.getText().equalsIgnoreCase(functionName)) {
                                        
                                        if (info.isDeclaration) {
                                            declarations.add(element);
                                        } else {
                                            usages.add(element);
                                        }
                                        break;
                                    }
                                    
                                    // Try next sibling or child
                                    if (element.getFirstChild() != null) {
                                        element = element.getFirstChild();
                                    } else if (element.getNextSibling() != null) {
                                        element = element.getNextSibling();
                                    } else {
                                        // Move up and try next sibling
                                        element = element.getParent();
                                        if (element != null && element != psiFile) {
                                            element = element.getNextSibling();
                                        } else {
                                            break;
                                        }
                                    }
                                    
                                    // Don't search too far from the line
                                    if (element != null && element.getTextOffset() > lineStartOffset + 200) {
                                        break;
                                    }
                                }
                            }
                            return true; // Continue processing
                        },
                        scope
                    );
                }
                
                // Apply result limits if not getting all
                if (!getAllResults) {
                    HarbourSettings settings = HarbourSettings.getInstance(project);
                    int maxResults = settings.getMaxNavigationResults();
                    if (maxResults > 0 && (declarations.size() + usages.size()) >= maxResults) {
                        break;
                    }
                }
            }
            
            // Combine results with declarations first
            List<PsiElement> results = new ArrayList<>();
            results.addAll(declarations);
            results.addAll(usages);
            
            Duration duration = Duration.between(start, Instant.now());
            HarbourLogger.log("ReferenceService", "Enhanced index search took: " + duration.toMillis() + 
                "ms - Found " + declarations.size() + " declarations and " + usages.size() + 
                " usages for: " + functionName);
            
            return results.isEmpty() ? null : results;
            
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "Enhanced index search failed: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Find functions using FileBasedIndex for ultra-fast lookup.
     * This is orders of magnitude faster than directSearch.
     */
    private List<PsiElement> findFunctionsViaStubIndex(String functionName, boolean getAllResults) {
        try {
            Instant start = Instant.now();
            List<PsiElement> results = new ArrayList<>();
            
            // Use FileBasedIndex for instant lookup
            GlobalSearchScope scope = GlobalSearchScope.projectScope(project);
            String key = functionName.toLowerCase();
            
            // Get all files containing this function
            Collection<VirtualFile> files = FileBasedIndex.getInstance()
                .getContainingFiles(HarbourFunctionIndex.INDEX_ID, key, scope);
            
            PsiManager psiManager = PsiManager.getInstance(project);
            
            for (VirtualFile file : files) {
                // Get function info from index
                List<HarbourFunctionIndex.FunctionInfo> infos = new ArrayList<>();
                for (HarbourFunctionIndex.FunctionInfo info : 
                     FileBasedIndex.getInstance().getValues(HarbourFunctionIndex.INDEX_ID, key, scope)) {
                    infos.add(info);
                }
                
                // Create PSI elements for the functions
                PsiFile psiFile = psiManager.findFile(file);
                if (psiFile != null) {
                    for (HarbourFunctionIndex.FunctionInfo info : infos) {
                        // Find the element at the line
                        int offset = getOffsetForLine(psiFile, info.lineNumber);
                        if (offset >= 0) {
                            PsiElement element = psiFile.findElementAt(offset);
                            if (element != null) {
                                // Find the function/procedure declaration
                                PsiElement funcDecl = PsiTreeUtil.getParentOfType(element, 
                                    HarbourFunctionDeclaration.class, HarbourProcedureDeclaration.class);
                                if (funcDecl != null) {
                                    results.add(funcDecl);
                                } else {
                                    // Fallback to the element itself
                                    results.add(element);
                                }
                            }
                        }
                    }
                }
                
                // Apply limit if not getting all results
                if (!getAllResults) {
                    HarbourSettings settings = HarbourSettings.getInstance(project);
                    int maxResults = settings.getMaxNavigationResults();
                    if (maxResults > 0 && results.size() >= maxResults) {
                        results = results.subList(0, maxResults);
                        break;
                    }
                }
            }
            
            Duration duration = Duration.between(start, Instant.now());
            HarbourLogger.log("ReferenceService", "FileBasedIndex search took: " + duration.toMillis() + 
                "ms - Found " + results.size() + " results for: " + functionName);
            
            return results;
        } catch (Exception e) {
            HarbourLogger.log("ReferenceService", "FileBasedIndex not ready or error: " + e.getMessage());
            return Collections.emptyList();
        }
    }
    
    /**
     * Get offset for a specific line number in a file.
     */
    private int getOffsetForLine(PsiFile file, int lineNumber) {
        String text = file.getText();
        int line = 1;
        for (int i = 0; i < text.length(); i++) {
            if (line == lineNumber) {
                return i;
            }
            if (text.charAt(i) == '\n') {
                line++;
            }
        }
        return -1;
    }
    
    private int getLineNumberFromOffset(String fileContent, int offset) {
        int lineNumber = 1;
        for (int i = 0; i < Math.min(offset, fileContent.length()); i++) {
            if (fileContent.charAt(i) == '\n') {
                lineNumber++;
            }
        }
        return lineNumber;
    }

    /**
     * Search for identifiers with the given name directly in all Harbour files.
     *
     * @param identifierName The name of the identifier to find
     * @param isFunction Whether to look for function declarations/calls or just identifiers
     * @return A list of PSI elements matching the identifier
     */
    private List<PsiElement> directSearch(String identifierName, boolean isFunction) {
        return directSearch(identifierName, isFunction, false);
    }
    
    /**
     * Search for identifiers with the given name directly in all Harbour files.
     *
     * @param identifierName The name of the identifier to find
     * @param isFunction Whether to look for function declarations/calls or just identifiers
     * @param getAllResults If true, returns all results without limit
     * @return A list of PSI elements matching the identifier
     */
    private List<PsiElement> directSearch(String identifierName, boolean isFunction, boolean getAllResults) {
        Instant start = Instant.now();
        List<PsiElement> definitions = new ArrayList<>();
        List<PsiElement> sameFileUsages = new ArrayList<>();
        List<PsiElement> otherFileUsages = new ArrayList<>();
        
        // Get max results from settings (unless getting all results)
        HarbourSettings settings = HarbourSettings.getInstance(project);
        int maxResults = getAllResults ? Integer.MAX_VALUE : settings.getMaxNavigationResults();
        if (maxResults <= 0) maxResults = 20; // Default fallback
        
        // Track the file containing the definition for smart ordering
        VirtualFile definitionFile = null;

        // Pattern for matching exact identifiers with word boundaries
        Pattern identifierPattern = Pattern.compile(
                "\\b" + Pattern.quote(identifierName) + "\\b", Pattern.CASE_INSENSITIVE);

        // Function specific patterns
        Pattern functionPattern = null;
        Pattern callPattern = null;

        if (isFunction) {
            // Create patterns for function and procedure declarations (including STATIC)
            functionPattern = Pattern.compile(
                    "(?i)\\b(STATIC\\s+)?(FUNCTION|PROCEDURE|METHOD)\\s+" + Pattern.quote(identifierName) + "\\b");

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
                // Check for cancellation periodically to allow graceful cancellation
                ProgressManager.checkCanceled();
                
                // Skip excluded files
                if (isFileExcluded(virtualFile)) {
                    continue;
                }

                PsiFile psiFile = psiManager.findFile(virtualFile);
                if (psiFile == null) continue;

                // Get the file content
                String fileContent = psiFile.getText();

                if (isFunction && functionPattern != null && callPattern != null) {
                    // Look for function declarations
                    Matcher declarationMatcher = functionPattern.matcher(fileContent);
                    while (declarationMatcher.find()) {
                        int startOffset = declarationMatcher.start();
                        String matchedText = declarationMatcher.group();
                        int lineNumber = getLineNumberFromOffset(fileContent, startOffset);
                        
                        // Debug logging removed for performance
                        
                        // Comment checking disabled for performance - was causing first invocation hang
                        
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null) {
                            // Try to find the actual function name identifier after FUNCTION/PROCEDURE keyword
                            PsiElement funcNameElement = null;
                            
                            // If we're on the FUNCTION/PROCEDURE keyword, look for the next identifier
                            if (element.getText().equalsIgnoreCase("FUNCTION") ||
                                element.getText().equalsIgnoreCase("PROCEDURE") ||
                                element.getText().equalsIgnoreCase("METHOD") ||
                                element.getText().equalsIgnoreCase("STATIC")) {
                                
                                // Find the function name identifier
                                PsiElement current = element;
                                while (current != null && funcNameElement == null) {
                                    current = current.getNextSibling();
                                    if (current instanceof LeafPsiElement) {
                                        LeafPsiElement leaf = (LeafPsiElement) current;
                                        if (leaf.getElementType() == HarbourTypes.IDENT &&
                                            leaf.getText().equalsIgnoreCase(identifierName)) {
                                            funcNameElement = leaf;
                                            break;
                                        }
                                    }
                                }
                            }
                            
                            // Add the function name element if found, otherwise the keyword element
                            if (funcNameElement != null) {
                                definitions.add(funcNameElement);
                                if (definitionFile == null) {
                                    definitionFile = virtualFile;
                                }
                                HarbourLogger.log("ReferenceService", "Found function definition identifier for " + 
                                    identifierName + " at line " + lineNumber);
                            } else {
                                // Fallback to adding the element itself
                                definitions.add(element);
                                if (definitionFile == null) {
                                    definitionFile = virtualFile;
                                }
                            }
                            
                            // Early termination if we have enough definitions
                            if (definitions.size() >= MAX_DEFINITIONS) {
                                HarbourLogger.log("ReferenceService", "Reached max definitions limit (" + MAX_DEFINITIONS + "), continuing for usages");
                            }
                        }
                    }

                    // Look for function calls
                    Matcher callMatcher = callPattern.matcher(fileContent);
                    while (callMatcher.find()) {
                        int startOffset = callMatcher.start();
                        String matchedText = callMatcher.group();
                        int lineNumber = getLineNumberFromOffset(fileContent, startOffset);
                        
                        // Debug logging removed for performance
                        
                        // Comment checking disabled for performance - was causing first invocation hang
                        
                        PsiElement element = psiFile.findElementAt(startOffset);

                        if (element != null && element.getText().equalsIgnoreCase(identifierName)) {
                            // Check if this is a function call
                            PsiElement functionCall = PsiTreeUtil.getParentOfType(element, FunctionCallImpl.class);
                            if (functionCall != null) {
                                // Categorize usage by file
                                if (definitionFile != null && virtualFile.equals(definitionFile)) {
                                    sameFileUsages.add(functionCall);
                                } else {
                                    otherFileUsages.add(functionCall);
                                }
                                // Stop collecting usages if we have too many (unless getting all)
                                if (!getAllResults) {
                                    int totalUsages = sameFileUsages.size() + otherFileUsages.size();
                                    if (totalUsages >= maxResults * 2) {
                                        break;
                                    }
                                }
                            } else if (element instanceof LeafPsiElement &&
                                    ((LeafPsiElement) element).getElementType() == HarbourTypes.IDENT) {
                                // Categorize usage by file
                                if (definitionFile != null && virtualFile.equals(definitionFile)) {
                                    sameFileUsages.add(element);
                                } else {
                                    otherFileUsages.add(element);
                                }
                                // Stop collecting usages if we have too many (unless getting all)
                                if (!getAllResults) {
                                    int totalUsages = sameFileUsages.size() + otherFileUsages.size();
                                    if (totalUsages >= maxResults * 2) {
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                
                if (!isFunction) {
                // For all identifiers (function identifiers and variable identifiers)
                Matcher identMatcher = identifierPattern.matcher(fileContent);
                while (identMatcher.find()) {
                    int startOffset = identMatcher.start();
                    String matchedText = identMatcher.group();
                    int lineNumber = getLineNumberFromOffset(fileContent, startOffset);
                    
                    // Special debugging for user.prg line 136
                    if (virtualFile.getPath().contains("user.prg") && lineNumber == 136) {
                        HarbourLogger.log("ReferenceService", "DEBUG: Found match '" + matchedText + "' at offset " + startOffset + " line " + lineNumber + " in user.prg");
                    }
                    
                    // Comment checking disabled for performance
                    
                    PsiElement element = psiFile.findElementAt(startOffset);

                    if (element != null) {
                        // Check if this is an identifier
                        if (element instanceof LeafPsiElement) {
                            LeafPsiElement leafElement = (LeafPsiElement) element;
                            if (leafElement.getElementType() == HarbourTypes.IDENT &&
                                    leafElement.getText().equalsIgnoreCase(identifierName)) {
                                // Categorize usage by file for non-function identifiers
                                if (definitionFile != null && virtualFile.equals(definitionFile)) {
                                    sameFileUsages.add(element);
                                } else {
                                    otherFileUsages.add(element);
                                }
                                // Stop collecting if we have too many (unless getting all)
                                if (!getAllResults) {
                                    int totalUsages = sameFileUsages.size() + otherFileUsages.size();
                                    if (totalUsages >= maxResults * 2) {
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
                } // End of for loop
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
        
        // Smart result ordering:
        // 1. Definitions first (always include all definitions found)
        // 2. Same file usages second
        // 3. Other file usages last
        List<PsiElement> results = new ArrayList<>();
        
        // Add all definitions first (they are most important)
        results.addAll(definitions);
        
        if (getAllResults) {
            // When getting all results, add everything without limits
            results.addAll(sameFileUsages);
            results.addAll(otherFileUsages);
        } else {
            // Calculate remaining slots for usages
            int remainingSlots = maxResults - results.size();
            
            if (remainingSlots > 0) {
                // Add same-file usages first (up to half of remaining slots)
                int sameFileLimit = Math.min(remainingSlots / 2, sameFileUsages.size());
                if (sameFileLimit > 0) {
                    results.addAll(sameFileUsages.subList(0, sameFileLimit));
                    remainingSlots -= sameFileLimit;
                }
                
                // Add other file usages with remaining slots
                if (remainingSlots > 0 && !otherFileUsages.isEmpty()) {
                    int otherFileLimit = Math.min(remainingSlots, otherFileUsages.size());
                    results.addAll(otherFileUsages.subList(0, otherFileLimit));
                }
            }
        }
        
        HarbourLogger.log("ReferenceService", "Direct search took: " + duration.toMillis() + "ms - Found " + 
                definitions.size() + " definitions, " + sameFileUsages.size() + " same-file usages, and " + 
                otherFileUsages.size() + " other-file usages for " + identifierName);
        
        // Log if we found any definitions
        if (!definitions.isEmpty()) {
            HarbourLogger.log("ReferenceService", "Prioritized " + definitions.size() + " definition(s) at top for " + identifierName);
        }
        
        HarbourLogger.log("ReferenceService", "Returning " + results.size() + " results (limit: " + maxResults + ")");

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

                // Use PSI tree traversal instead of regex on text
                // This is more reliable for finding the actual PSI elements
                psiFile.accept(new PsiRecursiveElementVisitor() {
                    @Override
                    public void visitElement(@NotNull PsiElement element) {
                        super.visitElement(element);
                        
                        // Look for CLASS keyword elements
                        if (element instanceof LeafPsiElement) {
                            LeafPsiElement leaf = (LeafPsiElement) element;
                            if (leaf.getText().equalsIgnoreCase("CLASS")) {
                                // Found a CLASS keyword, now check if the next identifier is our class name
                                PsiElement nextElement = leaf.getNextSibling();
                                
                                // Skip whitespace
                                while (nextElement != null && (nextElement instanceof PsiWhiteSpace || 
                                       nextElement.getText().trim().isEmpty())) {
                                    nextElement = nextElement.getNextSibling();
                                }
                                
                                // Check if the next element is our class name
                                if (nextElement != null && nextElement.getText().equalsIgnoreCase(className)) {
                                    // Found our class declaration!
                                    // Get the actual line text to verify
                                    int lineNumber = HarbourLogger.calculateLineNumber(leaf);
                                    String fileText = psiFile.getText();
                                    String[] lines = fileText.split("\n");
                                    
                                    if (lineNumber > 0 && lineNumber <= lines.length) {
                                        String actualLine = lines[lineNumber - 1];
                                        if (!actualLine.toUpperCase().contains("CLASS")) {
                                            // Line calculation is off, try to find the correct line
                                            HarbourLogger.log("ReferenceService", 
                                                "WARNING: Line " + lineNumber + " doesn't contain CLASS, got: " + actualLine);
                                            // Search nearby lines for the CLASS line
                                            for (int offset = -2; offset <= 2; offset++) {
                                                int checkLine = lineNumber + offset;
                                                if (checkLine > 0 && checkLine <= lines.length) {
                                                    String checkLineText = lines[checkLine - 1];
                                                    if (checkLineText.toUpperCase().contains("CLASS " + className.toUpperCase())) {
                                                        lineNumber = checkLine;
                                                        HarbourLogger.log("ReferenceService", 
                                                            "CORRECTED: Found CLASS at line " + lineNumber);
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Add the CLASS keyword element directly - no wrapper
                                    // Navigation needs real PSI elements to work correctly
                                    results.add(leaf);
                                    HarbourLogger.log("ReferenceService", 
                                        "Found CLASS " + className + " at line " + lineNumber + 
                                        " in " + virtualFile.getName());
                                }
                            }
                        }
                    }
                });
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
        HarbourLogger.log("ReferenceService", "Direct search found " + results.size() + " results for class: " + className);

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
                        
                        // Comment checking disabled for performance
                        
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
                        
                        // Comment checking disabled for performance
                        
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
                        
                        // Comment checking disabled for performance
                        
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
     * Check and limit cache sizes to prevent memory issues.
     */
    private void checkCacheSizes() {
        int totalSize = functionCaches.size() + symbolCaches.size() + 
                       variableCaches.size() + classCaches.size();
        
        if (totalSize > 1000) {
            HarbourLogger.log("ReferenceService", "Cache size exceeded limit (" + totalSize + "), clearing caches");
            clearCache();
        }
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
     * Uses getAllResults=true to ensure ALL occurrences are found for renaming.
     *
     * @param variableName The name of the variable to find
     * @return A list of PSI elements for the variable usages
     */
    public List<PsiElement> findVariablesForRename(String variableName) {
        return findVariables(variableName, true);  // Get ALL results for rename
    }

    /**
     * Find all function elements for rename operation.
     * Uses getAllResults=true to ensure ALL occurrences are found for renaming.
     *
     * @param functionName The name of the function to find
     * @return A list of PSI elements for the function declarations/calls
     */
    public List<PsiElement> findFunctionsForRename(String functionName) {
        return findFunctions(functionName, true);  // Get ALL results for rename
    }

    /**
     * Find all symbol elements for rename operation.
     * Uses getAllResults=true to ensure ALL occurrences are found for renaming.
     *
     * @param symbolName The name of the symbol to find
     * @return A list of PSI elements for the symbol occurrences
     */
    public List<PsiElement> findSymbolForRename(String symbolName) {
        return findSymbol(symbolName, true);  // Get ALL results for rename
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
        if (file == null) {
            HarbourLogger.log("ReferenceService", "registerFunctions called with null file");
            return;
        }
        
        String fileName = file.getName() != null ? file.getName() : "<unnamed>";
        HarbourLogger.log("ReferenceService", "Registering functions from file: " + fileName);
        
        try {
            long startTime = System.currentTimeMillis();
            
            // Implementation would scan the file for function declarations
            // and add them to the cache. Simplified version for now.
            Collection<HarbourFunctionDeclaration> declarations = PsiTreeUtil.findChildrenOfType(file, HarbourFunctionDeclaration.class);
            
            long scanTime = System.currentTimeMillis() - startTime;
            if (scanTime > 500) {
                HarbourLogger.warning("ReferenceService", "Slow PSI scan (" + scanTime + "ms) for: " + fileName + " found " + declarations.size() + " functions");
            }
            
            int count = 0;
            for (HarbourFunctionDeclaration declaration : declarations) {
                String name = declaration.getName();
                if (name != null && !name.isEmpty()) {
                    List<PsiElement> elements = new ArrayList<>();
                    elements.add(declaration);
                    updateCache(name, elements);
                    count++;
                }
            }
            
            if (count > 0) {
                HarbourLogger.log("ReferenceService", "Registered " + count + " functions from: " + fileName);
            }
        } catch (Exception e) {
            HarbourLogger.error("ReferenceService", "Error registering functions from " + fileName + ": " + e.getMessage());
        }
    }

    /**
     * Register classes found in a Harbour file to the cache.
     */
    public void registerClasses(HarbourFile file) {
        if (file == null) {
            HarbourLogger.log("ReferenceService", "registerClasses called with null file");
            return;
        }
        
        String fileName = file.getName() != null ? file.getName() : "<unnamed>";
        HarbourLogger.log("ReferenceService", "Registering classes from file: " + fileName);

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
        if (file == null) {
            HarbourLogger.log("ReferenceService", "registerProcedures called with null file");
            return;
        }
        
        String fileName = file.getName() != null ? file.getName() : "<unnamed>";
        HarbourLogger.log("ReferenceService", "Registering procedures from file: " + fileName);

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
     * Uses configurable directory patterns from settings.
     */
    public boolean isExcluded(VirtualFile file) {
        if (file == null) return false;

        String path = file.getPath();
        if (excludedFiles.contains(path)) {
            return true;
        }

        // Also check by filename
        String filename = file.getName();
        if (excludedFilenames.contains(filename)) {
            return true;
        }

        // Check against configurable exclusion patterns from settings
        HarbourSettings settings = HarbourSettings.getInstance(project);
        if (settings != null) {
            List<String> patterns = settings.getExcludedDirectoryPatterns();
            if (patterns != null && !patterns.isEmpty()) {
                String pathLower = path.toLowerCase();
                for (String pattern : patterns) {
                    if (pattern != null && !pattern.isEmpty()) {
                        String patternLower = pattern.toLowerCase().trim();
                        // Check if path contains the pattern (case-insensitive)
                        if (pathLower.contains("/" + patternLower + "/") ||
                            pathLower.contains("\\" + patternLower + "\\") ||
                            pathLower.contains("/" + patternLower) ||
                            pathLower.contains("\\" + patternLower)) {
                            return true;
                        }
                    }
                }
            }
        }

        return false;
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
     * Convert cache entries to PSI elements.
     */
    private List<PsiElement> convertCacheEntriesToPsiElements(List<HarbourIndexCache.CacheEntry> entries) {
        // For now, return empty list to avoid file modification errors during resolution
        // The cache lookup is causing issues with PSI modification during read actions
        HarbourLogger.log("ReferenceService", "Cache lookup disabled temporarily - " + entries.size() + " entries skipped");
        return Collections.emptyList();
    }
    
    /**
     * Find element at specific line number.
     */
    private PsiElement findElementAtLine(PsiFile file, int lineNumber, String name) {
        com.intellij.openapi.editor.Document document = PsiDocumentManager.getInstance(project).getDocument(file);
        if (document == null || lineNumber <= 0) return null;
        
        int lineStartOffset = document.getLineStartOffset(Math.min(lineNumber - 1, document.getLineCount() - 1));
        PsiElement element = file.findElementAt(lineStartOffset);
        
        // Search for the named element near this line
        while (element != null && element.getTextOffset() < lineStartOffset + 500) {
            if (element instanceof HarbourFunctionDeclaration || 
                element instanceof ClassDeclaration) {
                if (name.equalsIgnoreCase(element.getText()) || 
                    (element instanceof com.intellij.psi.PsiNamedElement && 
                     name.equalsIgnoreCase(((com.intellij.psi.PsiNamedElement) element).getName()))) {
                    return element;
                }
            }
            element = element.getNextSibling();
        }
        
        return null;
    }

    /**
     * Initializer for the service that runs on project startup.
     */
    public static class HarbourReferenceServiceInitializer implements StartupActivity.DumbAware {
        @Override
        public void runActivity(@NotNull Project project) {
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
                    HarbourLogger.log("ReferenceService", "Harbour mouse listener registered successfully");
                } catch (Exception e) {
                    HarbourLogger.log("ReferenceService", "Failed to register Harbour mouse listener: " + e.getMessage());
                }
            });

        }
    }
}
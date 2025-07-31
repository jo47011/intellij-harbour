package org.intellij.sdk.language;

import com.intellij.codeInsight.completion.*;
import com.intellij.codeInsight.completion.impl.CamelHumpMatcher;
import com.intellij.codeInsight.lookup.LookupElement;
import com.intellij.codeInsight.lookup.LookupElementBuilder;
import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.ProcessCanceledException;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Contributes code completion items for Harbour language.
 * Provides completion for commands, standard functions, user-defined functions, and class methods.
 */
public class HarbourCompletionContributor extends CompletionContributor {

    private static Project currentProject = null;

    public HarbourCompletionContributor() {
        // Add completion for all Harbour elements - only use BASIC type
        extend(CompletionType.BASIC,
                PlatformPatterns.psiElement().withLanguage(HarbourLanguage.INSTANCE),
                new CompletionProvider<>() {
                    @Override
                    protected void addCompletions(@NotNull CompletionParameters parameters,
                                                  @NotNull ProcessingContext context,
                                                  @NotNull CompletionResultSet result) {

                        try {
                            // Store project for future use if available
                            if (currentProject == null && parameters.getOriginalFile() != null) {
                                currentProject = parameters.getOriginalFile().getProject();
                            }

                            // Check if this is an auto-popup situation (set breakpoint here)
                            if (parameters.isAutoPopup()) {
                                // Early check for auto-completion setting
                                if (currentProject != null) {
                                    HarbourSettings settings = HarbourSettings.getInstance(currentProject);
                                    if (!settings.isAutoCompletionEnabled()) {
                                        // Skip completion when auto-completion is disabled
                                        HarbourLogger.log("CompletionContributor", "Auto-completion disabled, canceling");
                                        return;
                                    }
                                }
                            }

                            // Standard completion handling proceeds
                            HarbourLogger.log("CompletionContributor", "Starting completion");

                            // Debug: log list of commands for diagnostic purposes
                            if (currentProject != null) {
                                HarbourSettings settings = HarbourSettings.getInstance(currentProject);
                                List<String> commands = settings.getHarbourCommands();
                                HarbourLogger.log("CompletionContributor", "Available commands: " + String.join(", ", commands));
                            }

                            // Create case-insensitive prefix matcher
                            CompletionResultSet caseInsensitiveResult = result.withPrefixMatcher(
                                    new CamelHumpMatcher(result.getPrefixMatcher().getPrefix(), true));

                            // Get project from original file
                            Project project = parameters.getOriginalFile().getProject();

                            // Determine if we're in a method context
                            boolean inClassContext = isInClassContext(parameters);
                            HarbourLogger.log("CompletionContributor", "In class context: " + inClassContext);

                            // Add commands from settings
                            addCommandCompletions(caseInsensitiveResult, project);

                            // Add standard functions
                            addStandardFunctions(caseInsensitiveResult);

                            // Add local variables from current scope
                            addLocalVariablesFromCurrentScope(caseInsensitiveResult, parameters);

                            // Add public variables from current file scope
                            addPublicVariablesFromCurrentFile(caseInsensitiveResult, parameters);

                            // Add constants/defines from current file and included .ch files
                            addConstantsAndDefines(caseInsensitiveResult, parameters);

                            // Add user-defined functions from project
                            addUserDefinedFunctions(caseInsensitiveResult, project, parameters);

                            // Add class methods if we're in a class context
                            if (inClassContext) {
                                addClassMethods(caseInsensitiveResult, parameters, project);
                            }

                        } catch (ProcessCanceledException e) {
                            // Re-throw ProcessCanceledException
                            throw e;
                        } catch (Exception e) {
                            HarbourLogger.log("CompletionContributor", "Completion error: " + e.getMessage());
                        }
                    }
                });
    }

    /**
     * Adds Harbour commands from settings to completion results
     */
    private void addCommandCompletions(CompletionResultSet result, Project project) {
        try {
            // Get Harbour commands from settings
            HarbourSettings settings = HarbourSettings.getInstance(project);
            List<String> commands = settings.getHarbourCommands();

            HarbourLogger.log("CompletionContributor", "Adding " + commands.size() + " commands");

            // Add commands with proper presentation (only one case variant)
            for (String command : commands) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createCommandLookupElement(command));
            }
        } catch (ProcessCanceledException e) {
            // Re-throw ProcessCanceledException
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Command completion error: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a Harbour command
     */
    private LookupElement createCommandLookupElement(String command) {
        // Check if this is a block end keyword that needs special handling
        if (isBlockEndKeyword(command.toLowerCase())) {
            return LookupElementBuilder.create(command)
                    .withCaseSensitivity(false)
                    .withTypeText("Command")
                    .withIcon(HarbourIcons.FILE)
                    .withBoldness(true)
                    .withInsertHandler((context, item) -> {
                        // Apply unindentation for block end keywords
                        applyBlockEndUnindent(context, command);
                    });
        } else {
            return LookupElementBuilder.create(command)
                    .withCaseSensitivity(false)
                    .withTypeText("Command")
                    .withIcon(HarbourIcons.FILE)
                    .withBoldness(true);
        }
    }

    /**
     * Check if a command is a block end keyword that should trigger unindentation
     */
    private boolean isBlockEndKeyword(String command) {
        return command.equals("endif") || command.equals("enddo") ||
                command.equals("endclass") || command.equals("endcase") ||
                command.equals("endswitch") || command.equals("next") ||
                command.equals("else") || command.equals("elseif") ||
                command.equals("return") || command.equals("exit") ||
                command.equals("loop") ||
                // BEGIN SEQUENCE block end keywords
                command.equals("recover") || command.equals("end sequence") ||
                command.equals("end");
    }

    /**
     * Apply unindentation for block end keywords during completion
     */
    private void applyBlockEndUnindent(InsertionContext context, String keyword) {
        try {
            Document document = context.getDocument();
            Editor editor = context.getEditor();
            Project project = context.getProject();

            // Get current line
            int offset = editor.getCaretModel().getOffset();
            int lineNumber = document.getLineNumber(offset);
            int lineStart = document.getLineStartOffset(lineNumber);
            int lineEnd = document.getLineEndOffset(lineNumber);
            String currentLineText = document.getText().substring(lineStart, lineEnd);

            // Extract current indentation
            String currentIndent = getIndentation(currentLineText);
            String lineContent = currentLineText.trim();

            // Get indentation size from settings
            HarbourSettings settings = HarbourSettings.getInstance(project);
            int indentSize = settings != null ? settings.getIndentationSize() : 2;

            // Calculate correct indentation (one level less)
            String correctIndent;
            if (currentIndent.length() >= indentSize) {
                correctIndent = currentIndent.substring(0, currentIndent.length() - indentSize);
            } else {
                correctIndent = "";
            }

            // Only adjust if the indentation is different
            if (!currentIndent.equals(correctIndent)) {
                // Calculate cursor position relative to the start of the word
                int wordStartInLine = lineContent.indexOf(keyword.toLowerCase());
                if (wordStartInLine == -1) {
                    wordStartInLine = lineContent.indexOf(keyword);
                }
                int cursorPosInWord = offset - (lineStart + currentIndent.length() + wordStartInLine);

                // Replace the entire line with properly indented version
                document.replaceString(lineStart, lineEnd, correctIndent + lineContent);

                // Adjust cursor position
                int newWordStart = lineStart + correctIndent.length() + wordStartInLine;
                int newOffset = newWordStart + cursorPosInWord;

                if (newOffset >= 0 && newOffset <= document.getTextLength()) {
                    editor.getCaretModel().moveToOffset(newOffset);
                }

                PsiDocumentManager.getInstance(project).commitDocument(document);
                HarbourLogger.log("CompletionContributor", "Adjusted indentation for block end keyword: " + keyword);
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error applying block end unindent: " + e.getMessage());
        }
    }

    /**
     * Extracts indentation (leading spaces) from a line
     */
    private String getIndentation(String line) {
        int i = 0;
        while (i < line.length() && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        return line.substring(0, i);
    }

    /**
     * Adds standard Harbour functions to completion results
     */
    private void addStandardFunctions(CompletionResultSet result) {
        try {
            // Get all standard functions from the provider
            Set<String> standardFunctions = HarbourStandardFunctionsProvider.getAllStandardFunctions();

            HarbourLogger.log("CompletionContributor", "Adding " + standardFunctions.size() + " standard functions");

            // Add each standard function to completion results (only one case variant)
            for (String function : standardFunctions) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createStandardFunctionLookupElement(function));
            }
        } catch (ProcessCanceledException e) {
            // Re-throw ProcessCanceledException
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Standard function completion error: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a standard Harbour function
     */
    private LookupElement createStandardFunctionLookupElement(String function) {
        return LookupElementBuilder.create(function)
                .withCaseSensitivity(false)
                .withTypeText("Standard Function")
                .withIcon(HarbourIcons.FILE)
                .withTailText("()", true)
                .withInsertHandler((context, item) -> {
                    // Insert parentheses after function name
                    context.getDocument().insertString(context.getSelectionEndOffset(), "()");
                    // Position caret between parentheses
                    context.getEditor().getCaretModel().moveToOffset(context.getSelectionEndOffset() - 1);
                });
    }

    /**
     * Adds local variables from current procedure/function scope to completion results
     */
    private void addLocalVariablesFromCurrentScope(CompletionResultSet result, CompletionParameters parameters) {
        try {
            // Get the current file and position
            PsiFile file = parameters.getOriginalFile();
            PsiElement position = parameters.getPosition();

            if (file == null || position == null || !(file instanceof HarbourFile)) {
                return;
            }

            // Get the scope of the current procedure/function
            int[] scope = HarbourGoToDeclarationHandler.getProcedureFunctionScope(position);
            if (scope == null) {
                // Not in a procedure/function scope
                return;
            }

            HarbourLogger.log("CompletionContributor", "Found scope from line " + scope[0] + " to line " + scope[1]);

            // Extract the text of the current scope
            String fileText = file.getText();
            String[] lines = fileText.split("\n");

            // Build the text of the current scope
            StringBuilder scopeText = new StringBuilder();
            for (int i = scope[0]; i <= Math.min(scope[1], lines.length - 1); i++) {
                scopeText.append(lines[i]).append("\n");
            }

            // Find all LOCAL variable declarations in the current scope
            Set<String> localVariables = new HashSet<>();
            Set<String> paramSet = new HashSet<>(); // Set to track parameters separately

            // Pattern for LOCAL variable declarations
            Pattern localPattern = Pattern.compile("(?i)\\bLOCAL\\s+([\\w,\\s:=]+)");
            Matcher localMatcher = localPattern.matcher(scopeText.toString());

            while (localMatcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                // Extract the variable declaration part
                String declarations = localMatcher.group(1);

                // Split by commas to get individual variables
                String[] vars = declarations.split(",");
                for (String var : vars) {
                    // Extract variable name (before any assignment or type declaration)
                    String varName = var.trim();

                    // Handle assignments (:=)
                    int assignPos = varName.indexOf(":=");
                    if (assignPos > 0) {
                        varName = varName.substring(0, assignPos).trim();
                    }

                    // Handle type declarations (:)
                    int typePos = varName.indexOf(":");
                    if (typePos > 0) {
                        varName = varName.substring(0, typePos).trim();
                    }

                    // Add the variable if it's valid
                    if (!varName.isEmpty() && Character.isLetter(varName.charAt(0))) {
                        localVariables.add(varName);
                        HarbourLogger.log("CompletionContributor", "Found local variable: " + varName);
                    }
                }
            }

            // Extract parameters from the procedure/function declaration
            if (scope[0] >= 0 && scope[0] < lines.length) {
                // Find the complete declaration that might span multiple lines
                String declarationText = extractCompleteDeclaration(lines, scope[0]);
                HarbourLogger.log("CompletionContributor", "Complete declaration: " + declarationText);

                // Extract parameters from the declaration
                extractParametersFromDeclaration(declarationText, paramSet);
            }

            // Add each local variable to completion results
            for (String variable : localVariables) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createVariableLookupElement(variable, false));
            }

            // Add each parameter to completion results
            for (String param : paramSet) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createVariableLookupElement(param, true));
            }

            HarbourLogger.log("CompletionContributor", "Added " + localVariables.size() +
                    " local variables and " + paramSet.size() + " parameters from current scope");

        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error adding local variables: " + e.getMessage());
        }
    }

    /**
     * Extract the complete function/procedure declaration that might span multiple lines
     */
    private String extractCompleteDeclaration(String[] lines, int startLine) {
        StringBuilder declaration = new StringBuilder();
        int currentLine = startLine;

        // Add the first line of the declaration
        declaration.append(lines[currentLine]);

        // Keep adding lines as long as they end with a line continuation character (;)
        while (currentLine < lines.length - 1 &&
                declaration.toString().trim().endsWith(";")) {
            currentLine++;
            declaration.append("\n").append(lines[currentLine]);
        }

        return declaration.toString();
    }

    /**
     * Extract parameters from a complete function/procedure declaration
     */
    private void extractParametersFromDeclaration(String declaration, Set<String> paramSet) {
        try {
            // Find opening and closing parentheses for parameters
            int openParen = declaration.indexOf('(');
            int closeParen = declaration.lastIndexOf(')');

            if (openParen > 0 && closeParen > openParen) {
                // Extract the parameters text between parentheses
                String paramsText = declaration.substring(openParen + 1, closeParen);

                // Remove line continuation characters
                paramsText = paramsText.replace(";", "");

                // Split by commas to get individual parameters
                String[] paramList = paramsText.split(",");

                for (String param : paramList) {
                    ProgressManager.checkCanceled(); // Check for cancellation

                    // Clean up the parameter name
                    String paramName = param.trim();

                    // Skip empty params
                    if (paramName.isEmpty()) {
                        continue;
                    }

                    // Add the parameter
                    paramSet.add(paramName);
                    HarbourLogger.log("CompletionContributor", "Found parameter: " + paramName);
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error extracting parameters: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a local variable or parameter
     *
     * @param variable The variable name
     * @param isParameter True if this is a parameter, false if local variable
     */
    private LookupElement createVariableLookupElement(String variable, boolean isParameter) {
        return LookupElementBuilder.create(variable)
                .withCaseSensitivity(false)
                .withTypeText(isParameter ? "Parameter" : "Local Variable")
                .withIcon(HarbourIcons.FILE);
    }

    /**
     * Adds public variables from current file scope to completion results
     */
    private void addPublicVariablesFromCurrentFile(CompletionResultSet result, CompletionParameters parameters) {
        try {
            // Get the current file
            PsiFile file = parameters.getOriginalFile();
            if (file == null || !(file instanceof HarbourFile)) {
                return;
            }

            // Get the entire file text
            String fileText = file.getText();
            
            // Find all PUBLIC variable declarations in the file
            Set<String> publicVariables = new HashSet<>();

            // Pattern for PUBLIC variable declarations: must be at start of line (with optional whitespace)
            // and stop at line end or comment to avoid matching comments
            Pattern publicPattern = Pattern.compile("(?i)^\\s*PUBLIC\\s+([\\w,\\s:=\"'.\\(\\)]+?)(?:\\s*//|\\s*$)", Pattern.MULTILINE);
            Matcher publicMatcher = publicPattern.matcher(fileText);

            while (publicMatcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                // Extract the variable declaration part
                String declarations = publicMatcher.group(1);

                // Split by commas to get individual variables
                String[] vars = declarations.split(",");
                for (String var : vars) {
                    // Extract variable name (before any assignment or type declaration)
                    String varName = var.trim();

                    // Handle assignments (:=)
                    int assignPos = varName.indexOf(":=");
                    if (assignPos > 0) {
                        varName = varName.substring(0, assignPos).trim();
                    }

                    // Handle type declarations (:)
                    int typePos = varName.indexOf(":");
                    if (typePos > 0) {
                        varName = varName.substring(0, typePos).trim();
                    }

                    // Add the variable if it's valid
                    if (!varName.isEmpty() && Character.isLetter(varName.charAt(0))) {
                        publicVariables.add(varName);
                        HarbourLogger.log("CompletionContributor", "Found public variable: " + varName);
                    }
                }
            }

            // Add each public variable to completion results
            for (String variable : publicVariables) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createPublicVariableLookupElement(variable));
            }

            HarbourLogger.log("CompletionContributor", "Added " + publicVariables.size() + " public variables from current file");

        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error adding public variables: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a public variable
     */
    private LookupElement createPublicVariableLookupElement(String variable) {
        return LookupElementBuilder.create(variable)
                .withCaseSensitivity(false)
                .withTypeText("Public Variable")
                .withIcon(HarbourIcons.FILE);
    }

    /**
     * Adds constants and defines from current file and included .ch files to completion results
     */
    private void addConstantsAndDefines(CompletionResultSet result, CompletionParameters parameters) {
        try {
            // Get the current file
            PsiFile file = parameters.getOriginalFile();
            if (file == null || !(file instanceof HarbourFile)) {
                return;
            }

            Set<String> constants = new HashSet<>();

            // Add defines from current .prg file
            addDefinesFromFile(file.getText(), constants);

            // Add defines from included .ch files
            addDefinesFromIncludedFiles(file, constants, parameters.getOriginalFile().getProject());

            // Add each constant to completion results
            for (String constant : constants) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createConstantLookupElement(constant));
            }

            HarbourLogger.log("CompletionContributor", "Added " + constants.size() + " constants/defines");

        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error adding constants: " + e.getMessage());
        }
    }

    /**
     * Adds defines from a file's text content
     */
    private void addDefinesFromFile(String fileText, Set<String> constants) {
        try {
            // Pattern for #define statements: "#define CONSTANT_NAME value"
            Pattern definePattern = Pattern.compile("(?i)^\\s*#define\\s+([A-Z_][A-Z0-9_]*)\\s+", Pattern.MULTILINE);
            Matcher defineMatcher = definePattern.matcher(fileText);

            while (defineMatcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                String constantName = defineMatcher.group(1);
                if (!constantName.isEmpty()) {
                    constants.add(constantName);
                    HarbourLogger.log("CompletionContributor", "Found define: " + constantName);
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error parsing defines from file: " + e.getMessage());
        }
    }

    /**
     * Adds defines from included .ch files (recursive)
     */
    private void addDefinesFromIncludedFiles(PsiFile currentFile, Set<String> constants, Project project) {
        Set<String> processedIncludes = new HashSet<>(); // Avoid circular includes
        processIncludesRecursively(currentFile.getText(), currentFile, constants, project, processedIncludes);
    }

    /**
     * Recursively process include files to find all defines
     */
    private void processIncludesRecursively(String fileText, PsiFile currentFile, Set<String> constants, 
                                           Project project, Set<String> processedIncludes) {
        try {
            // Pattern for #include statements: "#include "filename.ch"" or "#include <filename.ch>"
            Pattern includePattern = Pattern.compile("(?i)^\\s*#include\\s+[\"<]([^\">\n]+\\.ch)[\">\n]", Pattern.MULTILINE);
            Matcher includeMatcher = includePattern.matcher(fileText);

            while (includeMatcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                String includeFileName = includeMatcher.group(1);
                
                // Skip if already processed (prevent circular includes)
                if (processedIncludes.contains(includeFileName.toLowerCase())) {
                    continue;
                }
                processedIncludes.add(includeFileName.toLowerCase());

                // Find the include file
                VirtualFile includeFile = findIncludeFile(includeFileName, currentFile, project);
                if (includeFile != null) {
                    try {
                        // Read the include file content
                        String includeContent = new String(includeFile.contentsToByteArray(), includeFile.getCharset());
                        
                        // Add defines from this include file
                        addDefinesFromFile(includeContent, constants);
                        
                        HarbourLogger.log("CompletionContributor", "Processed include file: " + includeFileName);
                        
                        // RECURSIVE: Process includes within this include file
                        processIncludesRecursively(includeContent, currentFile, constants, project, processedIncludes);
                        
                    } catch (Exception e) {
                        HarbourLogger.log("CompletionContributor", "Error reading include file " + includeFileName + ": " + e.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error processing include files recursively: " + e.getMessage());
        }
    }

    /**
     * Find an include file (.ch) by searching in include paths
     */
    private VirtualFile findIncludeFile(String fileName, PsiFile currentFile, Project project) {
        try {
            // First try relative to current file
            VirtualFile currentDir = currentFile.getVirtualFile().getParent();
            if (currentDir != null) {
                VirtualFile includeFile = currentDir.findChild(fileName);
                if (includeFile != null && includeFile.exists()) {
                    return includeFile;
                }
            }

            // Try in project root
            VirtualFile projectRoot = project.getBaseDir();
            if (projectRoot != null) {
                VirtualFile includeFile = projectRoot.findChild(fileName);
                if (includeFile != null && includeFile.exists()) {
                    return includeFile;
                }
            }

            // Try in include paths from settings
            HarbourSettings settings = HarbourSettings.getInstance(project);
            if (settings != null) {
                for (String includePath : settings.getResolvedIncludePaths(project)) {
                    VirtualFile includeDir = LocalFileSystem.getInstance().findFileByPath(includePath);
                    if (includeDir != null && includeDir.exists()) {
                        VirtualFile includeFile = includeDir.findChild(fileName);
                        if (includeFile != null && includeFile.exists()) {
                            return includeFile;
                        }
                    }
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error finding include file " + fileName + ": " + e.getMessage());
        }
        return null;
    }

    /**
     * Creates a lookup element for a constant/define
     */
    private LookupElement createConstantLookupElement(String constant) {
        return LookupElementBuilder.create(constant)
                .withCaseSensitivity(false)
                .withTypeText("Constant")
                .withIcon(HarbourIcons.FILE)
                .withBoldness(true);
    }

    /**
     * Adds user-defined functions from the project to completion results
     */
    private void addUserDefinedFunctions(CompletionResultSet result, Project project,
                                         CompletionParameters parameters) {
        Set<String> projectFunctions = new HashSet<>();

        try {
            // First, scan the current file for functions - most relevant to completion
            PsiFile currentFile = null;

            try {
                // Get the current file being edited from the parameters
                currentFile = parameters.getOriginalFile();
                if (currentFile != null && currentFile instanceof HarbourFile) {
                    // Scan current file first for immediate functions
                    scanFileForFunctions((HarbourFile)currentFile, projectFunctions);
                    HarbourLogger.log("CompletionContributor", "Found " + projectFunctions.size() + " functions in current file");
                }
            } catch (ProcessCanceledException e) {
                throw e;
            } catch (Exception e) {
                HarbourLogger.log("CompletionContributor", "Could not get current file: " + e.getMessage());
            }

            // Next, use reference service to find global functions
            HarbourLogger.log("CompletionContributor", "Scanning project files for functions");

            // Create final copy of currentFile for use in lambda
            final PsiFile finalCurrentFile = currentFile;

            // Collect functions from all Harbour files in the project
            Set<String> globalFunctions = new HashSet<>();
            try {
                globalFunctions = ReadAction.compute(() -> {
                    Set<String> functions = new HashSet<>();
                    try {
                        // Get all Harbour files in the project
                        Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(
                                HarbourFileType.INSTANCE, GlobalSearchScope.projectScope(project));

                        // Also find files with .prg extension explicitly
                        FileTypeIndex.processFiles(HarbourFileType.INSTANCE, file -> {
                            if (file.getName().endsWith(".prg")) {
                                virtualFiles.add(file);
                            }
                            return true;
                        }, GlobalSearchScope.projectScope(project));

                        HarbourLogger.log("CompletionContributor", "Found " + virtualFiles.size() + " Harbour files in project");

                        PsiManager psiManager = PsiManager.getInstance(project);
                        int fileCount = 0;

                        for (VirtualFile virtualFile : virtualFiles) {
                            ProgressManager.checkCanceled();

                            // Skip excluded files
                            if (HarbourFileUtils.isFileExcluded(project, virtualFile)) {
                                continue;
                            }

                            // Skip current file - we've already processed it
                            if (finalCurrentFile != null && virtualFile.equals(finalCurrentFile.getVirtualFile())) {
                                HarbourLogger.log("CompletionContributor", "Skipping current file: " + virtualFile.getName());
                                continue;
                            }

                            // Get file content and scan for function declarations
                            PsiFile psiFile = psiManager.findFile(virtualFile);
                            if (psiFile != null) {
                                fileCount++;
                                String content = psiFile.getText();
                                scanTextForFunctionsDirectly(content, functions);

                                if (fileCount % 20 == 0) {
                                    HarbourLogger.log("CompletionContributor", "Scanned " + fileCount + " files, found " +
                                            functions.size() + " functions so far");
                                }
                            }
                        }

                        HarbourLogger.log("CompletionContributor", "Completed project scan: " + fileCount + " files, " +
                                functions.size() + " total functions");

                    } catch (ProcessCanceledException e) {
                        throw e;
                    } catch (Exception e) {
                        HarbourLogger.log("CompletionContributor", "Project scan error: " + e.getMessage());
                    }
                    return functions;
                });
            } catch (ProcessCanceledException e) {
                throw e;
            }

            // Add global functions to the project functions set
            projectFunctions.addAll(globalFunctions);

            HarbourLogger.log("CompletionContributor", "Adding " + projectFunctions.size() + " user-defined functions");

            // Add each user function to completion results (only one case variant)
            for (String function : projectFunctions) {
                ProgressManager.checkCanceled(); // Check for cancellation

                // Skip standard functions - they've already been added
                if (HarbourStandardFunctionCache.isStandardFunction(function)) {
                    continue;
                }

                result.addElement(createUserFunctionLookupElement(function));
            }
        } catch (ProcessCanceledException e) {
            // Re-throw ProcessCanceledException
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "User function completion error: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a user-defined function
     */
    private LookupElement createUserFunctionLookupElement(String function) {
        return LookupElementBuilder.create(function)
                .withCaseSensitivity(false)
                .withTypeText("Project Function")
                .withIcon(HarbourIcons.FILE)
                .withTailText("()", true)
                .withInsertHandler((context, item) -> {
                    // Insert parentheses after function name
                    context.getDocument().insertString(context.getSelectionEndOffset(), "()");
                    // Position caret between parentheses
                    context.getEditor().getCaretModel().moveToOffset(context.getSelectionEndOffset() - 1);
                });
    }

    /**
     * Adds class methods to completion results if in a class context
     */
    private void addClassMethods(CompletionResultSet result, CompletionParameters parameters, Project project) {
        try {
            // Find the current class context
            String className = getCurrentClassName(parameters);
            if (className == null || className.isEmpty()) {
                HarbourLogger.log("CompletionContributor", "No current class context found");
                return;
            }

            HarbourLogger.log("CompletionContributor", "Adding methods for class: " + className);

            // Get the reference service
            HarbourReferenceService referenceService = HarbourReferenceService.getInstance(project);

            // Find all methods for this class
            List<PsiElement> methodElements = ReadAction.compute(() ->
                    referenceService.findClassMethods(className, null)
            );

            Set<String> classMethods = new HashSet<>();

            // Extract method names
            for (PsiElement element : methodElements) {
                ProgressManager.checkCanceled(); // Check for cancellation

                if (element != null) {
                    String methodName = extractMethodName(element.getText(), className);
                    if (methodName != null && !methodName.isEmpty()) {
                        classMethods.add(methodName);
                    }
                }
            }

            HarbourLogger.log("CompletionContributor", "Adding " + classMethods.size() + " methods for class " + className);

            // Add each method to completion results (only one case variant)
            for (String method : classMethods) {
                ProgressManager.checkCanceled(); // Check for cancellation
                result.addElement(createClassMethodLookupElement(method, className));
            }
        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Class method completion error: " + e.getMessage());
        }
    }

    /**
     * Creates a lookup element for a class method
     */
    private LookupElement createClassMethodLookupElement(String method, String className) {
        return LookupElementBuilder.create(method)
                .withCaseSensitivity(false)
                .withTypeText("Method of " + className)
                .withIcon(HarbourIcons.FILE)
                .withTailText("()", true)
                .withInsertHandler((context, item) -> {
                    // Insert parentheses after method name
                    context.getDocument().insertString(context.getSelectionEndOffset(), "()");
                    // Position caret between parentheses
                    context.getEditor().getCaretModel().moveToOffset(context.getSelectionEndOffset() - 1);
                });
    }

    /**
     * Extract a function name from a function declaration string
     */
    private String extractFunctionName(String declaration) {
        try {
            // Match FUNCTION or PROCEDURE followed by an identifier
            Pattern pattern = Pattern.compile("(?i)(FUNCTION|PROCEDURE)\\s+(\\w+)");
            Matcher matcher = pattern.matcher(declaration);

            if (matcher.find()) {
                return matcher.group(2);
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error extracting function name: " + e.getMessage());
        }
        return null;
    }

    /**
     * Extract a method name from a method declaration string
     */
    private String extractMethodName(String declaration, String className) {
        try {
            // Match "METHOD methodName CLASS className" pattern
            Pattern pattern1 = Pattern.compile("(?i)METHOD\\s+(\\w+)\\s+CLASS\\s+" + Pattern.quote(className));
            Matcher matcher1 = pattern1.matcher(declaration);

            if (matcher1.find()) {
                return matcher1.group(1);
            }

            // Match "METHOD className:methodName" pattern
            Pattern pattern2 = Pattern.compile("(?i)METHOD\\s+" + Pattern.quote(className) + "\\s*:\\s*(\\w+)");
            Matcher matcher2 = pattern2.matcher(declaration);

            if (matcher2.find()) {
                return matcher2.group(1);
            }
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error extracting method name: " + e.getMessage());
        }
        return null;
    }

    /**
     * Determine if we're in a class context for method completion
     */
    private boolean isInClassContext(CompletionParameters parameters) {
        PsiElement position = parameters.getPosition();

        // Check if we're inside a class declaration
        ClassDeclaration classDeclaration = ReadAction.compute(() -> {
            return com.intellij.psi.util.PsiTreeUtil.getParentOfType(position, ClassDeclaration.class);
        });

        if (classDeclaration != null) {
            return true;
        }

        // Check for SELF-> or ::method calls
        String fileText = position.getContainingFile().getText();
        int offset = position.getTextOffset();

        // Look for "SELF->" or "::" preceding the current position
        for (int i = offset - 1; i >= Math.max(0, offset - 20); i--) {
            if (i >= fileText.length()) continue;

            char c = fileText.charAt(i);
            if (Character.isWhitespace(c)) continue;

            // Check for "->" operator after "SELF"
            if (c == '>' && i > 0 && fileText.charAt(i-1) == '-') {
                // Check if "SELF" precedes the arrow
                int start = Math.max(0, i - 6);
                String text = fileText.substring(start, i - 1).trim().toUpperCase();
                if (text.endsWith("SELF")) {
                    return true;
                }
            }

            // Check for "::" operator
            if (c == ':' && i > 0 && fileText.charAt(i-1) == ':') {
                return true;
            }

            // If we hit another character, stop looking
            if (!Character.isWhitespace(c)) {
                break;
            }
        }

        return false;
    }

    /**
     * Get the current class name from context
     */
    private String getCurrentClassName(CompletionParameters parameters) {
        PsiElement position = parameters.getPosition();

        // Check if we're inside a class declaration
        ClassDeclaration classDeclaration = ReadAction.compute(() -> {
            return com.intellij.psi.util.PsiTreeUtil.getParentOfType(position, ClassDeclaration.class);
        });

        if (classDeclaration != null) {
            // Extract class name from the declaration
            for (PsiElement element : classDeclaration.getChildren()) {
                if (element instanceof LeafPsiElement &&
                        ((LeafPsiElement) element).getElementType() == HarbourTypes.IDENT) {
                    return element.getText();
                }
            }
        }

        // Check for SELF-> or ::method calls
        String fileText = position.getContainingFile().getText();
        int offset = position.getTextOffset();

        // Look for "className::" preceding the current position
        for (int i = offset - 1; i >= Math.max(0, offset - 100); i--) {
            if (i >= fileText.length()) continue;

            // Look for :: operator
            if (i > 0 && fileText.charAt(i) == ':' && i < fileText.length() - 1 &&
                    fileText.charAt(i+1) == ':') {

                // Extract class name before ::
                int start = i;
                while (start > 0 && (Character.isLetterOrDigit(fileText.charAt(start-1)) ||
                        fileText.charAt(start-1) == '_')) {
                    start--;
                }

                if (start < i) {
                    return fileText.substring(start, i);
                }
            }
        }

        return null;
    }

    /**
     * Scans a Harbour file for function declarations
     */
    private void scanFileForFunctions(HarbourFile file, Set<String> functions) {
        try {
            // Get text content for regex-based scanning (faster than PSI traversal)
            String content = file.getText();

            // Use regex to find FUNCTION and PROCEDURE declarations
            scanTextForFunctionsDirectly(content, functions);

        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error scanning file for functions: " + e.getMessage());
        }
    }

    /**
     * Scans text content for function declarations using regex
     */
    private void scanTextForFunctionsDirectly(String content, Set<String> functions) {
        try {
            // Match patterns for FUNCTION and PROCEDURE declarations
            // Case insensitive, with word boundary for the keywords
            Pattern functionPattern = Pattern.compile("(?i)\\b(FUNCTION|PROCEDURE)\\s+(\\w+)");
            Matcher matcher = functionPattern.matcher(content);

            while (matcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                String functionName = matcher.group(2);
                if (functionName != null && !functionName.isEmpty()) {
                    functions.add(functionName);
                    // Only log if this is a new function we found
                    if (functions.size() % 10 == 0) {
                        HarbourLogger.log("CompletionContributor", "Found function #" + functions.size() + ": " + functionName);
                    }
                }
            }
        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error in regex scanning: " + e.getMessage());
        }
    }

    /**
     * Scans text and adds function PSI elements to the list
     */
    private void scanTextForFunctions(String content, List<PsiElement> functions, PsiFile file) {
        try {
            // Match patterns for FUNCTION and PROCEDURE declarations
            Pattern functionPattern = Pattern.compile("(?i)\\b(FUNCTION|PROCEDURE)\\s+(\\w+)");
            Matcher matcher = functionPattern.matcher(content);

            while (matcher.find()) {
                ProgressManager.checkCanceled(); // Check for cancellation

                int offset = matcher.start();
                PsiElement element = file.findElementAt(offset);
                if (element != null) {
                    functions.add(element);
                }
            }
        } catch (ProcessCanceledException e) {
            throw e;
        } catch (Exception e) {
            HarbourLogger.log("CompletionContributor", "Error scanning text for functions: " + e.getMessage());
        }
    }

    /**
     * Extract function name from a PsiElement
     */
    private String extractFunctionNameFromElement(PsiElement element) {
        if (element == null) return null;

        // Get text of the element or its parent if needed
        String text = element.getText();

        // If it's just the FUNCTION keyword, get the parent's text
        if (text.equalsIgnoreCase("FUNCTION") || text.equalsIgnoreCase("PROCEDURE")) {
            PsiElement parent = element.getParent();
            if (parent != null) {
                text = parent.getText();
            }
        }

        // Extract function name using regex
        return extractFunctionName(text);
    }
}
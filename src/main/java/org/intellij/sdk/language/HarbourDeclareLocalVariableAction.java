package org.intellij.sdk.language;

import com.intellij.codeInsight.hint.HintManager;
import com.intellij.openapi.actionSystem.ActionUpdateThread;
import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.actionSystem.CommonDataKeys;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.command.WriteCommandAction;
import com.intellij.openapi.editor.CaretModel;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import com.intellij.psi.codeStyle.CodeStyleSettingsManager;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Action to declare a LOCAL variable for the identifier under cursor
 */
public class HarbourDeclareLocalVariableAction extends AnAction {

    @Override
    public @NotNull ActionUpdateThread getActionUpdateThread() {
        return ActionUpdateThread.BGT;
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        VirtualFile file = e.getData(CommonDataKeys.VIRTUAL_FILE);

        boolean isHarbourFile = false;
        if (project != null && file != null) {
            String extension = file.getExtension();
            isHarbourFile = extension != null && (extension.equals("prg") || extension.equals("ch"));
        }

        e.getPresentation().setEnabledAndVisible(isHarbourFile);
    }

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        final Project project = e.getProject();
        final Editor editor = e.getData(CommonDataKeys.EDITOR);
        final VirtualFile virtualFile = e.getData(CommonDataKeys.VIRTUAL_FILE);

        if (project == null || editor == null || virtualFile == null) {
            return;
        }

        final Document document = editor.getDocument();
        final PsiFile psiFile = PsiDocumentManager.getInstance(project).getPsiFile(document);

        if (!(psiFile instanceof HarbourFile)) {
            return;
        }

        // Get the caret position
        CaretModel caretModel = editor.getCaretModel();
        int offset = caretModel.getOffset();
        
        // Get the word under cursor
        String variableName = getWordAtOffset(document, offset);
        
        if (variableName == null || variableName.isEmpty()) {
            showHint(editor, "No variable name found under cursor", true);
            return;
        }

        // Check if it's a valid identifier
        if (!isValidIdentifier(variableName)) {
            showHint(editor, "'" + variableName + "' is not a valid variable name", true);
            return;
        }

        HarbourLogger.log("DeclareLocalVariable", "Variable to declare: " + variableName);

        // Check if this is actually a function/method call or keyword
        String validationResult = validateIdentifier(project, variableName);
        if (validationResult != null) {
            HarbourLogger.log("DeclareLocalVariable", "Validation failed: " + validationResult);
            showHint(editor, validationResult, true);
            return;
        }
        HarbourLogger.log("DeclareLocalVariable", "Validation passed");

        // Find the containing function, procedure, or method
        String text = document.getText();
        int functionStart = findFunctionStart(text, offset);
        HarbourLogger.log("DeclareLocalVariable", "Function start: " + functionStart);

        if (functionStart == -1) {
            HarbourLogger.log("DeclareLocalVariable", "No function found");
            showHint(editor, "Cursor is not inside a FUNCTION, PROCEDURE, or METHOD", true);
            return;
        }

        // Perform the modification in a write action
        HarbourLogger.log("DeclareLocalVariable", "Starting WriteCommandAction");
        WriteCommandAction.runWriteCommandAction(project, "Declare LOCAL Variable", null, () -> {
            try {
                HarbourLogger.log("DeclareLocalVariable", "Inside WriteCommandAction try block");
                // Find where to insert the LOCAL declaration
                String functionText = text.substring(functionStart);
                int localInsertPosition = findLocalInsertPosition(text, functionStart);
                HarbourLogger.log("DeclareLocalVariable", "Local insert position: " + localInsertPosition);

                if (localInsertPosition == -1) {
                    HarbourLogger.log("DeclareLocalVariable", "Could not determine insert position");
                    showHint(editor, "Could not determine where to insert LOCAL declaration", true);
                    return;
                }

                // Check if variable is already declared
                if (isVariableDeclared(text, functionStart, localInsertPosition, variableName)) {
                    HarbourLogger.log("DeclareLocalVariable", "Variable already declared");
                    String msg = "'" + variableName + "' is already declared as LOCAL";
                    showHint(editor, msg, true);
                    return;
                }
                HarbourLogger.log("DeclareLocalVariable", "Variable not yet declared, proceeding");

                // Get the configured LOCAL indentation from settings
                int localIndent = getLocalIndentSetting(project);
                
                // Create the indentation string based on settings
                String indentation = " ".repeat(localIndent);
                
                // Check if we're inserting at end of LOCAL block or after function
                // If there are existing LOCALs, we add at end with no leading newline
                // If no LOCALs exist, we add right after function with no leading newline
                String localDeclaration = indentation + "LOCAL " + variableName + "\n";
                HarbourLogger.log("DeclareLocalVariable", "Inserting: '" + localDeclaration.trim() + "' at position " + localInsertPosition);

                // Insert the declaration
                document.insertString(localInsertPosition, localDeclaration);

                // Commit changes
                PsiDocumentManager.getInstance(project).commitDocument(document);

                HarbourLogger.log("DeclareLocalVariable", "Success - LOCAL " + variableName + " added");
                showHint(editor, "Added: LOCAL " + variableName, false);
                    
            } catch (Exception ex) {
                HarbourLogger.log("DeclareLocalVariable", "Error: " + ex.getMessage());
                showHint(editor, "Failed to declare variable: " + ex.getMessage(), true);
            }
        });
    }

    private String getWordAtOffset(Document document, int offset) {
        String text = document.getText();
        if (offset < 0 || offset > text.length()) {
            return null;
        }

        // Find word boundaries
        int start = offset;
        int end = offset;

        // Move start back to beginning of word
        while (start > 0 && isIdentifierChar(text.charAt(start - 1))) {
            start--;
        }

        // Move end forward to end of word
        while (end < text.length() && isIdentifierChar(text.charAt(end))) {
            end++;
        }

        if (start >= end) {
            return null;
        }

        return text.substring(start, end);
    }

    private boolean isIdentifierChar(char c) {
        return Character.isLetterOrDigit(c) || c == '_';
    }

    private boolean isValidIdentifier(String name) {
        // Check if it starts with a letter or underscore
        if (name.isEmpty() || (!Character.isLetter(name.charAt(0)) && name.charAt(0) != '_')) {
            return false;
        }
        
        // Check rest of characters
        for (char c : name.toCharArray()) {
            if (!isIdentifierChar(c)) {
                return false;
            }
        }
        
        // Check it's not a keyword
        String upper = name.toUpperCase();
        return !isKeyword(upper);
    }

    private boolean isKeyword(String word) {
        // List of Harbour keywords that shouldn't be used as variable names
        String[] keywords = {
            "FUNCTION", "PROCEDURE", "RETURN", "LOCAL", "STATIC", "PRIVATE", "PUBLIC",
            "IF", "ELSE", "ELSEIF", "ENDIF", "DO", "WHILE", "ENDDO", "FOR", "NEXT",
            "SWITCH", "CASE", "OTHERWISE", "ENDSWITCH", "ENDCASE", "BEGIN", "SEQUENCE",
            "RECOVER", "END", "CLASS", "METHOD", "ENDCLASS", "ENDMETHOD", "NIL",
            "AND", "OR", "NOT", "LOOP", "EXIT", "MEMVAR", "USING", "DATA", "INIT"
        };
        
        for (String keyword : keywords) {
            if (keyword.equals(word)) {
                return true;
            }
        }
        return false;
    }

    private int findFunctionStart(String text, int offset) {
        // Look backwards for FUNCTION, PROCEDURE, or METHOD
        String textBefore = text.substring(0, offset);
        
        // Pattern to match function/procedure/method declarations
        Pattern pattern = Pattern.compile(
            "(?i)^\\s*((?:STATIC|LOCAL)?\\s*)?(FUNCTION|PROCEDURE|METHOD)\\s+\\w+",
            Pattern.MULTILINE
        );
        
        Matcher matcher = pattern.matcher(textBefore);
        int lastMatch = -1;
        
        while (matcher.find()) {
            lastMatch = matcher.start();
        }
        
        return lastMatch;
    }

    private int findLocalInsertPosition(String text, int functionStart) {
        // Find where to insert the LOCAL declaration
        // If LOCAL block exists, add to end of it
        // Otherwise, add right after function declaration
        
        String functionText = text.substring(functionStart);
        String[] lines = functionText.split("\n", -1); // -1 to preserve trailing empty strings
        
        int currentPos = functionStart;
        boolean foundFunctionLine = false;
        boolean inLocalBlock = false;
        int lastLocalLine = -1;
        int functionLineEnd = -1;
        
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            String trimmed = line.trim().toUpperCase();
            
            // Found function/procedure/method declaration
            if (!foundFunctionLine && (trimmed.startsWith("FUNCTION") || trimmed.startsWith("PROCEDURE") || trimmed.startsWith("METHOD") ||
                trimmed.startsWith("STATIC FUNCTION") || trimmed.startsWith("STATIC PROCEDURE") || trimmed.startsWith("STATIC METHOD") ||
                trimmed.startsWith("LOCAL FUNCTION") || trimmed.startsWith("LOCAL PROCEDURE") || trimmed.startsWith("LOCAL METHOD"))) {
                foundFunctionLine = true;
                functionLineEnd = currentPos + line.length() + 1;  // Position after the newline
                currentPos += line.length() + 1;
                continue;
            }
            
            if (!foundFunctionLine) {
                currentPos += line.length() + 1;
                continue;
            }
            
            // Skip empty lines
            if (trimmed.isEmpty()) {
                currentPos += line.length() + 1;
                continue;
            }
            
            // Skip comments
            if (trimmed.startsWith("*") || trimmed.startsWith("//")) {
                currentPos += line.length() + 1;
                continue;
            }
            
            // Check for LOCAL declarations
            if (trimmed.startsWith("LOCAL ")) {
                inLocalBlock = true;
                lastLocalLine = currentPos + line.length() + 1;  // After this LOCAL line
                currentPos += line.length() + 1;
                continue;
            }
            
            // Check for other declaration keywords (STATIC, PRIVATE, etc.)
            if (trimmed.startsWith("STATIC ") || trimmed.startsWith("PRIVATE ") || 
                trimmed.startsWith("PUBLIC ") || trimmed.startsWith("MEMVAR ")) {
                // These can come after LOCAL
                if (inLocalBlock && lastLocalLine > 0) {
                    // Found end of LOCAL block, insert at end of block
                    return lastLocalLine;
                }
                currentPos += line.length() + 1;
                continue;
            }
            
            // If we hit an executable statement or PARAMETER
            if (inLocalBlock && lastLocalLine > 0) {
                // We have a LOCAL block, add to end of it
                return lastLocalLine;
            }
            
            // No LOCAL block exists, insert right after function declaration
            return functionLineEnd;
        }
        
        // If we reach end of function
        if (inLocalBlock && lastLocalLine > 0) {
            return lastLocalLine;  // Add to end of LOCAL block
        }
        
        return functionLineEnd;  // Add after function declaration
    }

    private boolean isVariableDeclared(String text, int functionStart, int insertPosition, String variableName) {
        // Check if the variable is already declared in LOCAL statements
        // We need to check the entire function, not just before insert position
        // Find the end of the function
        int functionEnd = findFunctionEnd(text, functionStart);
        if (functionEnd == -1) {
            functionEnd = text.length();
        }

        String functionText = text.substring(functionStart, functionEnd);

        // Pattern to match LOCAL declarations
        Pattern pattern = Pattern.compile(
            "(?i)^\\s*LOCAL\\s+(.+)$",
            Pattern.MULTILINE
        );

        Matcher matcher = pattern.matcher(functionText);

        while (matcher.find()) {
            String varList = matcher.group(1);
            // Split by comma to get individual variables
            String[] vars = varList.split(",");
            for (String var : vars) {
                // Remove any assignment or type declaration
                String cleanVar = var.trim().split("\\s+")[0].split(":")[0].split("=")[0];
                if (cleanVar.equalsIgnoreCase(variableName)) {
                    HarbourLogger.log("DeclareLocalVariable",
                            "Variable '" + variableName + "' already declared in: LOCAL " + varList.trim());
                    return true;
                }
            }
        }

        return false;
    }
    
    private int findFunctionEnd(String text, int functionStart) {
        // Find the next FUNCTION, PROCEDURE, METHOD, or ENDCLASS
        String textAfter = text.substring(functionStart);
        Pattern pattern = Pattern.compile(
            "(?i)^\\s*(STATIC\\s+|LOCAL\\s+)?(FUNCTION|PROCEDURE|METHOD|ENDCLASS|ENDMETHOD)\\s",
            Pattern.MULTILINE
        );
        
        Matcher matcher = pattern.matcher(textAfter);
        // Skip the first match as that's our current function
        if (matcher.find()) {
            // Look for the next one
            if (matcher.find()) {
                return functionStart + matcher.start();
            }
        }
        
        return -1;
    }

    private String getIndentationAtPosition(String text, int position) {
        // Find the line containing the position
        int lineStart = position;
        while (lineStart > 0 && text.charAt(lineStart - 1) != '\n') {
            lineStart--;
        }
        
        // Extract indentation
        StringBuilder indent = new StringBuilder();
        for (int i = lineStart; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == ' ' || c == '\t') {
                indent.append(c);
            } else {
                break;
            }
        }
        
        return indent.toString();
    }

    /**
     * Show a hint message near the caret position in the editor.
     * This is more visible than notifications which may be collapsed.
     */
    private void showHint(Editor editor, String message, boolean isError) {
        ApplicationManager.getApplication().invokeLater(() -> {
            if (editor != null && !editor.isDisposed()) {
                if (isError) {
                    HintManager.getInstance().showErrorHint(editor, message);
                } else {
                    HintManager.getInstance().showInformationHint(editor, message);
                }
            }
        });
    }

    private int getLocalIndentSetting(Project project) {
        CodeStyleSettings settings = CodeStyleSettingsManager.getInstance(project).getCurrentSettings();
        HarbourCodeStyleSettings customSettings = settings.getCustomSettings(HarbourCodeStyleSettings.class);
        return customSettings.LOCAL_INDENT;
    }

    private String validateIdentifier(Project project, String identifier) {
        if (identifier == null || identifier.isEmpty()) {
            return null;
        }

        String upperIdent = identifier.toUpperCase();

        // Check if it's a Harbour keyword - these cannot be used as variable names
        if (isKeyword(upperIdent)) {
            return "'" + identifier + "' is a Harbour keyword and cannot be declared as a variable";
        }

        // Note: We intentionally DO NOT check if it's a function/procedure name
        // In Harbour, it's valid (though potentially confusing) to have a LOCAL variable
        // with the same name as a function. The LOCAL will shadow the function within scope.
        // This is a common pattern and should be allowed.

        return null; // Identifier is valid for declaration
    }
}
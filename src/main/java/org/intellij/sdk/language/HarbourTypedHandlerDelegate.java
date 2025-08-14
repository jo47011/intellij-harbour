package org.intellij.sdk.language;

import com.intellij.codeInsight.editorActions.TypedHandlerDelegate;
import com.intellij.openapi.editor.Document;
import com.intellij.openapi.editor.Editor;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiDocumentManager;
import com.intellij.psi.PsiFile;
import com.intellij.openapi.fileTypes.FileType;
import com.intellij.psi.codeStyle.CodeStyleSettingsManager;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

/**
 * Handles typing events for auto-indentation correction of end keywords
 */
public class HarbourTypedHandlerDelegate extends TypedHandlerDelegate {

    @Override
    public @NotNull Result charTyped(char c, @NotNull Project project, @NotNull Editor editor, @NotNull PsiFile file) {
        // Only process Harbour files
        if (!(file instanceof HarbourFile)) {
            return Result.CONTINUE;
        }

        try {
            // Check if the character could complete an end keyword
            if (couldCompleteEndKeyword(c)) {
                Document document = editor.getDocument();
                
                // Commit document to sync PSI
                PsiDocumentManager.getInstance(project).commitDocument(document);
                
                int offset = editor.getCaretModel().getOffset();
                int lineNumber = document.getLineNumber(offset);
                int lineStart = document.getLineStartOffset(lineNumber);
                int lineEnd = document.getLineEndOffset(lineNumber);
                
                String lineText = document.getCharsSequence().subSequence(lineStart, lineEnd).toString();
                String trimmedLine = lineText.trim().toLowerCase();
                
                HarbourLogger.log("TypedHandler", "Character typed: '" + c + "', line: '" + trimmedLine + "'");
                
                // Check if current line is an end keyword that needs indentation correction
                if (isEndKeyword(trimmedLine)) {
                    HarbourLogger.log("TypedHandler", "Found end keyword: " + trimmedLine);
                    correctIndentationForEndKeyword(editor, document, lineNumber, trimmedLine);
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("TypedHandler", "Error in charTyped: " + e.getMessage());
        }

        return Result.CONTINUE;
    }
    
    private boolean couldCompleteEndKeyword(char c) {
        // Characters that could complete end keywords (including 'n' for return)
        return c == 'f' || c == 'o' || c == 't' || c == 'e' || c == 's' || c == 'h' || c == 'n';
    }
    
    private boolean isEndKeyword(String word) {
        return word.equals("endif") ||
               word.equals("enddo") ||
               word.equals("endfor") ||
               word.equals("next") ||
               word.equals("endwhile") ||
               word.equals("endcase") ||
               word.equals("endswitch") ||
               word.equals("endclass") ||
               word.equals("endmethod") ||
               word.equals("endfunction") ||
               word.equals("endprocedure") ||
               word.equals("else") ||
               word.startsWith("elseif") ||
               word.equals("recover using") ||
               word.equals("end sequence") ||
               word.equals("return");
    }
    
    private void correctIndentationForEndKeyword(Editor editor, Document document, int lineNumber, String keyword) {
        try {
            // Find the matching start keyword and its indentation
            String targetIndent = findMatchingIndentation(document, lineNumber, keyword);
            
            if (targetIndent != null) {
                int lineStart = document.getLineStartOffset(lineNumber);
                int lineEnd = document.getLineEndOffset(lineNumber);
                String lineText = document.getCharsSequence().subSequence(lineStart, lineEnd).toString();
                
                // Find the first non-whitespace character
                int nonWsStart = 0;
                while (nonWsStart < lineText.length() && Character.isWhitespace(lineText.charAt(nonWsStart))) {
                    nonWsStart++;
                }
                
                if (nonWsStart > 0) {
                    // Replace the existing indentation with the target indentation
                    String newLine = targetIndent + lineText.substring(nonWsStart);
                    document.replaceString(lineStart, lineEnd, newLine);
                    
                    HarbourLogger.log("TypedHandler", "Corrected indentation for " + keyword + " to: '" + targetIndent + "'");
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("TypedHandler", "Error correcting indentation: " + e.getMessage());
        }
    }
    
    private String findMatchingIndentation(Document document, int lineNumber, String endKeyword) {
        try {
            // Map end keywords to their start keywords
            String[] startKeywords = getMatchingStartKeywords(endKeyword);
            if (startKeywords == null) {
                return null;
            }
            
            // Special handling for 'return' - check if it should be unindented based on context and settings
            if (endKeyword.equals("return")) {
                // First check if we're inside any control structures (if, while, for, etc.)
                boolean insideControlStructure = isInsideControlStructure(document, lineNumber);
                
                if (insideControlStructure) {
                    // Return inside control structure - don't unindent
                    HarbourLogger.log("TypedHandler", "Return is inside control structure, no auto-unindent");
                    return null;
                }
                
                // At function level - check RETURN_INDENT setting
                Project project = getProjectFromDocument(document);
                if (project != null) {
                    HarbourCodeStyleSettings settings = CodeStyleSettingsManager.getSettings(project).getCustomSettings(HarbourCodeStyleSettings.class);
                    if (settings.RETURN_INDENT > 0) {
                        // RETURN_INDENT is set to a specific column, don't auto-unindent
                        HarbourLogger.log("TypedHandler", "RETURN_INDENT is " + settings.RETURN_INDENT + ", no auto-unindent");
                        return null;
                    }
                }
                
                // RETURN at function level with RETURN_INDENT = 0 - find function indentation
                for (int i = lineNumber - 1; i >= 0; i--) {
                    int lineStart = document.getLineStartOffset(i);
                    int lineEnd = document.getLineEndOffset(i);
                    String lineText = document.getCharsSequence().subSequence(lineStart, lineEnd).toString();
                    String trimmedLine = lineText.trim().toLowerCase();
                    
                    if (trimmedLine.isEmpty()) {
                        continue;
                    }
                    
                    // Check if this line contains a function/procedure/method declaration
                    for (String startKeyword : startKeywords) {
                        if (trimmedLine.equals(startKeyword) || trimmedLine.startsWith(startKeyword + " ")) {
                            // Found the enclosing function/procedure/method, return its indentation
                            String indentation = getIndentation(lineText);
                            HarbourLogger.log("TypedHandler", "Found enclosing " + startKeyword + " at line " + i + " with indent: '" + indentation + "'");
                            return indentation;
                        }
                    }
                }
                return null;
            }
            
            int depth = 1; // We start with depth 1 since we found one end keyword
            
            // Search backwards for the matching start keyword
            for (int i = lineNumber - 1; i >= 0; i--) {
                int lineStart = document.getLineStartOffset(i);
                int lineEnd = document.getLineEndOffset(i);
                String lineText = document.getCharsSequence().subSequence(lineStart, lineEnd).toString();
                String trimmedLine = lineText.trim().toLowerCase();
                
                if (trimmedLine.isEmpty()) {
                    continue;
                }
                
                // Check if this line contains an end keyword (increases depth)
                if (isEndKeyword(trimmedLine) && !trimmedLine.equals("else") && !trimmedLine.startsWith("elseif")) {
                    depth++;
                    continue;
                }
                
                // Check if this line contains a matching start keyword
                for (String startKeyword : startKeywords) {
                    if (trimmedLine.equals(startKeyword) || trimmedLine.startsWith(startKeyword + " ")) {
                        depth--;
                        if (depth == 0) {
                            // Found the matching start keyword, return its indentation
                            String indentation = getIndentation(lineText);
                            HarbourLogger.log("TypedHandler", "Found matching " + startKeyword + " at line " + i + " with indent: '" + indentation + "'");
                            return indentation;
                        }
                        break;
                    }
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("TypedHandler", "Error finding matching indentation: " + e.getMessage());
        }
        
        return null; // No matching start keyword found
    }
    
    private String[] getMatchingStartKeywords(String endKeyword) {
        switch (endKeyword) {
            case "endif":
                return new String[]{"if"};
            case "enddo":
                return new String[]{"do"};
            case "endfor":
            case "next":
                return new String[]{"for"};
            case "endwhile":
                return new String[]{"while"};
            case "endcase":
            case "endswitch":
                return new String[]{"switch"};
            case "endclass":
                return new String[]{"class"};
            case "endmethod":
                return new String[]{"method"};
            case "endfunction":
                return new String[]{"function"};
            case "endprocedure":
                return new String[]{"procedure"};
            case "else":
            case "elseif":
                return new String[]{"if"};
            case "recover using":
                return new String[]{"begin sequence"};
            case "end sequence":
                return new String[]{"begin sequence"};
            case "return":
                // return should match with function or procedure declarations
                return new String[]{"function", "procedure", "method"};
            default:
                return null;
        }
    }
    
    private String getIndentation(String line) {
        int i = 0;
        while (i < line.length() && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        return line.substring(0, i);
    }
    
    private boolean isInsideControlStructure(Document document, int lineNumber) {
        try {
            int depth = 0;
            // Search backwards to see if we're inside control structures
            for (int i = lineNumber - 1; i >= 0; i--) {
                int lineStart = document.getLineStartOffset(i);
                int lineEnd = document.getLineEndOffset(i);
                String lineText = document.getCharsSequence().subSequence(lineStart, lineEnd).toString();
                String trimmedLine = lineText.trim().toLowerCase();
                
                if (trimmedLine.isEmpty() || trimmedLine.startsWith("//") || trimmedLine.startsWith("*")) {
                    continue;
                }
                
                // Check for control structure end keywords (going backwards, these increase depth)
                if (trimmedLine.equals("endif") || trimmedLine.equals("enddo") || 
                    trimmedLine.equals("next") || trimmedLine.equals("endfor") || 
                    trimmedLine.equals("endwhile") || trimmedLine.equals("endcase") ||
                    trimmedLine.equals("endswitch") || trimmedLine.equals("endwith")) {
                    depth++;
                }
                // Check for control structure start keywords (going backwards, these decrease depth)
                else if (trimmedLine.startsWith("if ") || trimmedLine.equals("if") ||
                         trimmedLine.startsWith("do ") || trimmedLine.equals("do") ||
                         trimmedLine.startsWith("while ") || trimmedLine.equals("while") ||
                         trimmedLine.startsWith("for ") || trimmedLine.equals("for") ||
                         trimmedLine.startsWith("switch ") || trimmedLine.equals("switch") ||
                         trimmedLine.startsWith("with ") || trimmedLine.equals("with") ||
                         trimmedLine.equals("do case") || trimmedLine.startsWith("do case")) {
                    depth--;
                    if (depth < 0) {
                        // We found an unclosed control structure, so we're inside it
                        HarbourLogger.log("TypedHandler", "Found unclosed control structure: " + trimmedLine);
                        return true;
                    }
                }
                // Check for function/procedure/method declaration - stop searching if we hit one
                else if (trimmedLine.startsWith("function ") || trimmedLine.equals("function") ||
                         trimmedLine.startsWith("procedure ") || trimmedLine.equals("procedure") ||
                         trimmedLine.startsWith("method ") || trimmedLine.equals("method") ||
                         trimmedLine.startsWith("static function ") || 
                         trimmedLine.startsWith("static procedure ") ||
                         trimmedLine.startsWith("static method ")) {
                    // Reached function boundary, we're at function level if depth is 0
                    return depth != 0;
                }
            }
        } catch (Exception e) {
            HarbourLogger.log("TypedHandler", "Error checking control structure context: " + e.getMessage());
        }
        return false;
    }
    
    private Project getProjectFromDocument(Document document) {
        try {
            // Try to get project through the EditorFactory
            com.intellij.openapi.editor.EditorFactory editorFactory = com.intellij.openapi.editor.EditorFactory.getInstance();
            Editor[] editors = editorFactory.getEditors(document);
            if (editors.length > 0 && editors[0].getProject() != null) {
                return editors[0].getProject();
            }
            
            // Fall back to default project
            return com.intellij.openapi.project.ProjectManager.getInstance().getDefaultProject();
        } catch (Exception e) {
            HarbourLogger.log("TypedHandler", "Error getting project from document: " + e.getMessage());
        }
        return null;
    }
}
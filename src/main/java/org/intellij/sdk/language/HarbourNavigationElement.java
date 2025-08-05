package org.intellij.sdk.language;

import com.intellij.navigation.ItemPresentation;
import com.intellij.navigation.NavigationItem;
import com.intellij.openapi.fileEditor.FileEditorManager;
import com.intellij.openapi.fileEditor.OpenFileDescriptor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.pom.Navigatable;
import com.intellij.psi.*;
import com.intellij.psi.impl.FakePsiElement;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.search.LocalSearchScope;
import com.intellij.psi.search.SearchScope;
import com.intellij.icons.AllIcons;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.Objects;
import com.intellij.lexer.Lexer;
import com.intellij.openapi.editor.colors.EditorColorsManager;
import com.intellij.openapi.editor.colors.EditorColorsScheme;
import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.editor.markup.TextAttributes;
import java.awt.Color;

/**
 * Custom implementation of a navigatable element for Harbour declarations.
 * This handles opening the file and positioning the caret at the right line.
 * It also implements PsiElement to allow it to be used in navigation contexts.
 */
public class HarbourNavigationElement extends FakePsiElement implements PsiElement, NavigationItem {
    private final SmartPsiElementPointer<PsiElement> targetPointer;
    private final String elementName;
    private final String filePath;
    private final int lineNumber;
    private final String contextInfo;
    private final Project project;
    private final boolean isDefinition;
    private final boolean isSeparator;
    private static final String COMPONENT = "Navigation";

    /**
     * Create a navigation element
     *
     * @param target The target element
     * @param elementName The name of the element
     * @param filePath The path to the file
     * @param lineNumber The line number
     * @param contextInfo Additional context information
     */
    public HarbourNavigationElement(PsiElement target, String elementName, String filePath, int lineNumber, String contextInfo) {
        this(target, elementName, filePath, lineNumber, contextInfo, false, false);
    }

    /**
     * Create a navigation element with additional flags
     *
     * @param target The target element
     * @param elementName The name of the element
     * @param filePath The path to the file
     * @param lineNumber The line number
     * @param contextInfo Additional context information
     * @param isDefinition Whether this element is a function/procedure definition
     * @param isSeparator Whether this element is a separator
     */
    public HarbourNavigationElement(PsiElement target, String elementName, String filePath,
                                    int lineNumber, String contextInfo,
                                    boolean isDefinition, boolean isSeparator) {
        this.targetPointer = SmartPointerManager.getInstance(target.getProject()).createSmartPsiElementPointer(target);
        this.elementName = elementName;
        this.filePath = filePath;
        this.lineNumber = lineNumber;
        this.contextInfo = contextInfo;
        this.project = target.getProject();
        this.isDefinition = isDefinition;
        this.isSeparator = isSeparator;

        HarbourLogger.log(COMPONENT, "Created navigation element for " + elementName +
                " in " + filePath + " at line " + lineNumber +
                " hashcode: " + this.hashCode() +
                " target hashcode: " + target.hashCode() +
                " isDefinition: " + isDefinition +
                " isSeparator: " + isSeparator);
    }

    /**
     * Create a "Load All" navigation element
     *
     * @param project The project
     * @param message The message to display
     * @return A special navigation element for loading all results
     */
    public static HarbourNavigationElement createLoadAllElement(Project project, String message) {
        // Create a dummy element that will show as a "Load All" button in the list
        // First find any valid file in the project to use as a base
        VirtualFile[] files = FileEditorManager.getInstance(project).getSelectedFiles();
        PsiFile psiFile;

        if (files.length > 0) {
            psiFile = PsiManager.getInstance(project).findFile(files[0]);
        } else {
            // Fallback if no file is open - get any file from the project
            psiFile = PsiManager.getInstance(project).findFile(
                    project.getProjectFile() != null ? project.getProjectFile() : project.getWorkspaceFile()
            );
        }

        if (psiFile == null) {
            // Last resort fallback - create a dummy element from the first file we can find
            PsiDirectory baseDir = PsiManager.getInstance(project).findDirectory(project.getBaseDir());
            if (baseDir != null && baseDir.getFiles().length > 0) {
                psiFile = baseDir.getFiles()[0];
            } else {
                // If we still can't find a file, just return null
                return null;
            }
        }

        return new HarbourNavigationElement(
                psiFile,
                message,
                "", 0, "", false, true);
    }
    
    /**
     * Create a separator navigation element
     *
     * @param project The project
     * @return A separator navigation element
     */
    public static HarbourNavigationElement createSeparator(Project project) {
        // Create a dummy element that will show as a separator in the list
        // First find any valid file in the project to use as a base
        VirtualFile[] files = FileEditorManager.getInstance(project).getSelectedFiles();
        PsiFile psiFile;

        if (files.length > 0) {
            psiFile = PsiManager.getInstance(project).findFile(files[0]);
        } else {
            // Fallback if no file is open - get any file from the project
            psiFile = PsiManager.getInstance(project).findFile(
                    project.getProjectFile() != null ? project.getProjectFile() : project.getWorkspaceFile()
            );
        }

        if (psiFile == null) {
            // Last resort fallback - create a dummy element from the first file we can find
            PsiDirectory baseDir = PsiManager.getInstance(project).findDirectory(project.getBaseDir());
            if (baseDir != null && baseDir.getFiles().length > 0) {
                psiFile = baseDir.getFiles()[0];
            } else {
                // If we still can't find a file, just use any valid element from the project
                // This is unlikely to happen, but just in case
                return null;
            }
        }

        return new HarbourNavigationElement(
                psiFile,
                "────────────────────────────────────────────────────────────────────────────────",
                "", 0, "", false, true);
    }

    @Override
    public String getName() {
        return elementName;
    }

    public String getElementName() {
        return elementName;
    }

    public String getFilePath() {
        return filePath;
    }

    public int getLineNumber() {
        return lineNumber;
    }

    public String getContextInfo() {
        return contextInfo;
    }

    public boolean isDefinition() {
        return isDefinition;
    }

    public boolean isSeparator() {
        return isSeparator;
    }

    @Nullable
    public PsiElement getTarget() {
        return targetPointer.getElement();
    }

    @Override
    public PsiElement getParent() {
        PsiElement target = getTarget();
        return target != null ? target.getParent() : null;
    }

    @Override
    public PsiElement getNavigationElement() {
        return getTarget();
    }

    @Override
    public boolean isValid() {
        if (isSeparator) {
            return true; // Separators are always valid
        }
        PsiElement target = getTarget();
        return target != null && target.isValid();
    }

    @Override
    public boolean isWritable() {
        PsiElement target = getTarget();
        return target != null && target.isWritable();
    }

    @Override
    public PsiFile getContainingFile() {
        return null;
    }

    @Override
    public PsiManager getManager() {
        PsiElement target = getTarget();
        return target != null ? target.getManager() : null;
    }

    @Override
    public Project getProject() {
        return project;
    }

    @Override
    public TextRange getTextRange() {
        PsiElement target = getTarget();
        return target != null ? target.getTextRange() : null;
    }

    @Override
    public int getTextOffset() {
        PsiElement target = getTarget();
        return target != null ? target.getTextOffset() : 0;
    }

    @NotNull
    @Override
    public SearchScope getUseScope() {
        PsiElement target = getTarget();
        if (target != null) {
            if (target instanceof PsiQualifiedNamedElement) {
                return GlobalSearchScope.projectScope(getProject());
            }
            return new LocalSearchScope(target.getContainingFile());
        }
        return GlobalSearchScope.EMPTY_SCOPE;
    }

    @Override
    public ItemPresentation getPresentation() {
        return new ItemPresentation() {
            @Nullable
            @Override
            public String getPresentableText() {
                if (isSeparator) {
                    return elementName; // Return the separator line
                }

                // Extract filename from path
                String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                
                // Read the actual line from the file
                String lineText = readLineFromFile(filePath, lineNumber);
                String formattedLine = formatLineForDisplay(lineText);

                // If we couldn't read the line, fall back to just filename:line
                if (formattedLine.isEmpty()) {
                    return formatPyCharmStyle(fileName, lineNumber, "");
                }

                // Format in PyCharm style: filename + line number + code content
                return formatPyCharmStyle(fileName, lineNumber, formattedLine);
            }

            @Nullable
            @Override
            public String getLocationString() {
                if (isSeparator) {
                    return null;
                }

                // Definition text removed as requested by user
                return null; // No additional location info needed
            }

            @Nullable
            @Override
            public Icon getIcon(boolean unused) {
                if (isSeparator) {
                    return null;
                }
                
                return getFileIcon();
            }
        };
    }

    @Override
    public void navigate(boolean requestFocus) {
        if (isSeparator) {
            return; // Separators are not navigatable
        }

        PsiElement target = getTarget();
        if (target instanceof Navigatable && ((Navigatable) target).canNavigate()) {
            HarbourLogger.log(COMPONENT, "Navigating via target to " + elementName +
                    " at line " + lineNumber + " in " + filePath);
            ((Navigatable) target).navigate(requestFocus);
        } else {
            // Fallback navigation using the file and line number
            try {
                VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(new File(filePath));
                if (virtualFile != null && virtualFile.isValid()) {
                    HarbourLogger.log(COMPONENT, "Navigating via descriptor to " +
                            elementName + " at line " + lineNumber + " in " + filePath);
                    OpenFileDescriptor descriptor = new OpenFileDescriptor(
                            project, virtualFile, Math.max(0, lineNumber - 1), 0);
                    FileEditorManager.getInstance(project).openEditor(descriptor, requestFocus);
                }
            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "Navigation failed: " + e.getMessage());
            }
        }
    }

    @Override
    public boolean canNavigate() {
        if (isSeparator) {
            return false; // Separators are not navigatable
        }

        PsiElement target = getTarget();
        if (target instanceof Navigatable) {
            return ((Navigatable) target).canNavigate();
        }

        // Check if we can navigate using the file path
        VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(new File(filePath));
        return virtualFile != null && virtualFile.isValid();
    }

    @Override
    public boolean canNavigateToSource() {
        if (isSeparator) {
            return false; // Separators are not navigatable
        }

        PsiElement target = getTarget();
        if (target instanceof Navigatable) {
            return ((Navigatable) target).canNavigateToSource();
        }
        return false;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        HarbourNavigationElement that = (HarbourNavigationElement) o;
        return lineNumber == that.lineNumber &&
                Objects.equals(elementName, that.elementName) &&
                Objects.equals(filePath, that.filePath);
    }

    @Override
    public int hashCode() {
        return Objects.hash(elementName, filePath, lineNumber);
    }

    @Override
    public String toString() {
        return elementName + " (" + filePath + ":" + lineNumber + ")";
    }

    /**
     * Read a specific line from a file
     * @param filePath The path to the file
     * @param lineNumber The line number (1-based)
     * @return The text of the line, or null if the line cannot be read
     */
    public String readLineFromFile(String filePath, int lineNumber) {
        if (filePath == null || lineNumber <= 0) {
            return null;
        }

        try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;
            int currentLine = 1;
            
            while ((line = reader.readLine()) != null) {
                if (currentLine == lineNumber) {
                    String trimmedLine = line.trim();
                    
                    // Check if this line is a comment or empty line that should be filtered out
                    if (isCommentOrEmptyLine(trimmedLine)) {
                        HarbourLogger.log(COMPONENT, "Filtering out comment/empty line at " + lineNumber + " in " + filePath + ": '" + trimmedLine + "'");
                        return null; // Return null to indicate this line should be skipped
                    }
                    
                    return trimmedLine; // Return the trimmed line for display
                }
                currentLine++;
            }
        } catch (IOException e) {
            HarbourLogger.log(COMPONENT, "Failed to read line " + lineNumber + " from " + filePath + ": " + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * Check if a line is a comment or empty line that should be filtered from navigation popup
     */
    private boolean isCommentOrEmptyLine(String trimmedLine) {
        if (trimmedLine == null || trimmedLine.isEmpty()) {
            return true; // Empty lines should be filtered
        }
        
        // Check for various comment patterns
        return trimmedLine.startsWith("//") || 
               trimmedLine.startsWith("/*") || 
               trimmedLine.startsWith("/**");
    }

    /**
     * Get the appropriate file icon for the navigation element
     * @return Icon for the file type
     */
    private Icon getFileIcon() {
        if (filePath != null && filePath.toLowerCase().endsWith(".prg")) {
            // Use custom Harbour icon for .prg files, fall back to text file icon
            return HarbourIcons.FILE != null ? HarbourIcons.FILE : AllIcons.FileTypes.Text;
        }
        return AllIcons.FileTypes.Unknown;
    }

    /**
     * Format the line text for display, truncating if too long
     * @param lineText The raw line text
     * @return Formatted text suitable for display
     */
    private String formatLineForDisplay(String lineText) {
        if (lineText == null || lineText.isEmpty()) {
            return "";
        }

        // Truncate very long lines to prevent popup from being too wide
        final int MAX_LINE_LENGTH = 80;
        if (lineText.length() > MAX_LINE_LENGTH) {
            return lineText.substring(0, MAX_LINE_LENGTH - 3) + "...";
        }

        return lineText;
    }

    /**
     * Format the presentation text in PyCharm style with HTML syntax highlighting
     * @param fileName The filename (without path)
     * @param lineNumber The line number
     * @param htmlCodeText The HTML-formatted code text with syntax highlighting
     * @return HTML formatted text with fixed-width columns
     */
    private String formatPyCharmStyleWithHTML(String fileName, int lineNumber, String htmlCodeText) {
        // Fixed width columns like PyCharm Find Usages
        final int FILENAME_WIDTH = 30;  // Fixed width for filename column
        final int LINE_WIDTH = 4;       // Fixed width for line number column
        
        // Truncate filename if too long, but keep extension
        String displayFileName = fileName;
        if (fileName.length() > FILENAME_WIDTH - 2) {
            String extension = "";
            int dotIndex = fileName.lastIndexOf('.');
            if (dotIndex > 0) {
                extension = fileName.substring(dotIndex);
                String baseName = fileName.substring(0, dotIndex);
                int maxBase = FILENAME_WIDTH - extension.length() - 3; // -3 for "..."
                if (maxBase > 0) {
                    displayFileName = baseName.substring(0, Math.min(baseName.length(), maxBase)) + "..." + extension;
                } else {
                    displayFileName = "..." + extension;
                }
            } else {
                displayFileName = fileName.substring(0, FILENAME_WIDTH - 3) + "...";
            }
        }
        
        // Format with HTML support for syntax highlighting
        return "<html><body style='font-family: monospace;'>" +
               String.format("%-" + FILENAME_WIDTH + "s %4d  ", displayFileName, lineNumber) + 
               htmlCodeText + "</body></html>";
    }

    /**
     * Format the presentation text in PyCharm style with fixed-width columns
     * @param fileName The filename (without path)
     * @param lineNumber The line number
     * @param codeText The actual code text
     * @return Formatted text with fixed-width columns
     */
    private String formatPyCharmStyle(String fileName, int lineNumber, String codeText) {
        // Fixed width columns like PyCharm Find Usages
        final int FILENAME_WIDTH = 30;  // Fixed width for filename column
        final int LINE_WIDTH = 4;       // Fixed width for line number column
        
        // Truncate filename if too long, but keep extension
        String displayFileName = fileName;
        if (fileName.length() > FILENAME_WIDTH - 2) {
            String extension = "";
            int dotIndex = fileName.lastIndexOf('.');
            if (dotIndex > 0) {
                extension = fileName.substring(dotIndex);
                String baseName = fileName.substring(0, dotIndex);
                int maxBase = FILENAME_WIDTH - extension.length() - 3; // -3 for "..."
                if (maxBase > 0) {
                    displayFileName = baseName.substring(0, Math.min(baseName.length(), maxBase)) + "..." + extension;
                } else {
                    displayFileName = "..." + extension;
                }
            } else {
                displayFileName = fileName.substring(0, FILENAME_WIDTH - 3) + "...";
            }
        }
        
        // Format: "filename.prg                  42  code content here"
        // Note: HTML rendering is not supported in getPresentableText()
        // Syntax highlighting will be handled by a custom cell renderer
        return String.format("%-" + FILENAME_WIDTH + "s %4d  %s", 
                           displayFileName, 
                           lineNumber, 
                           codeText != null ? codeText : "");
    }

    /**
     * Apply Harbour syntax highlighting to text using HTML formatting
     * @param codeText The raw code text
     * @return HTML formatted text with syntax highlighting
     */
    private String applySyntaxHighlightingHTML(String codeText) {
        try {
            // Use the existing Harbour syntax highlighter
            HarbourSyntaxHighlighter highlighter = new HarbourSyntaxHighlighter();
            Lexer lexer = highlighter.getHighlightingLexer();
            lexer.start(codeText);
            
            // Get current color scheme
            EditorColorsScheme scheme = EditorColorsManager.getInstance().getGlobalScheme();
            
            StringBuilder htmlBuilder = new StringBuilder("<html><body style='font-family: monospace'>");
            
            while (lexer.getTokenType() != null) {
                String tokenText = lexer.getTokenText();
                TextAttributesKey[] keys = highlighter.getTokenHighlights(lexer.getTokenType());
                
                if (keys.length > 0) {
                    TextAttributes attrs = scheme.getAttributes(keys[0]);
                    if (attrs != null && attrs.getForegroundColor() != null) {
                        Color color = attrs.getForegroundColor();
                        String colorHex = String.format("#%02x%02x%02x", 
                                                      color.getRed(), 
                                                      color.getGreen(), 
                                                      color.getBlue());
                        htmlBuilder.append("<span style='color:").append(colorHex).append("'>");
                        htmlBuilder.append(escapeHtml(tokenText));
                        htmlBuilder.append("</span>");
                    } else {
                        htmlBuilder.append(escapeHtml(tokenText));
                    }
                } else {
                    htmlBuilder.append(escapeHtml(tokenText));
                }
                
                lexer.advance();
            }
            
            htmlBuilder.append("</body></html>");
            return htmlBuilder.toString();
            
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Failed to apply syntax highlighting: " + e.getMessage());
            return codeText; // Return plain text on error
        }
    }

    /**
     * Creates a dummy navigation element for external functions to enable underlines
     * @param project The current project
     * @param functionName Name of the external function
     * @param description Description for the element
     * @return A dummy navigation element or null if creation fails
     */
    public static HarbourNavigationElement createExternalElement(Project project, String functionName, String description) {
        try {
            // Create a dummy element for external functions to enable underlines
            // First find any valid file in the project to use as a base
            VirtualFile[] files = FileEditorManager.getInstance(project).getSelectedFiles();
            PsiFile psiFile;
            if (files.length > 0) {
                psiFile = PsiManager.getInstance(project).findFile(files[0]);
            } else {
                // Fallback if no file is open - get any file from the project
                psiFile = PsiManager.getInstance(project).findFile(
                        project.getProjectFile() != null ? project.getProjectFile() : project.getWorkspaceFile()
                );
            }
            if (psiFile == null) {
                // Last resort fallback - create a dummy element from the first file we can find
                PsiDirectory baseDir = PsiManager.getInstance(project).findDirectory(project.getBaseDir());
                if (baseDir != null && baseDir.getFiles().length > 0) {
                    psiFile = baseDir.getFiles()[0];
                } else {
                    // If we still can't find a file, just return null
                    return null;
                }
            }
            
            HarbourNavigationElement element = new HarbourNavigationElement(
                    psiFile,
                    "External: " + functionName,
                    "external", 0, description, false, false);
            HarbourLogger.log(COMPONENT, "Created external navigation element for: " + functionName);
            return element;
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Failed to create external navigation element: " + e.getMessage());
            return null;
        }
    }

    /**
     * Escape HTML special characters
     * @param text The text to escape
     * @return Escaped text safe for HTML
     */
    private String escapeHtml(String text) {
        if (text == null) return "";
        return text.replace("&", "&amp;")
                   .replace("<", "&lt;")
                   .replace(">", "&gt;")
                   .replace("\"", "&quot;")
                   .replace("'", "&#39;");
    }
}
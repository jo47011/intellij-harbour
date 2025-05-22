package org.intellij.sdk.language;

import com.intellij.navigation.ItemPresentation;
import com.intellij.navigation.NavigationItem;
import com.intellij.openapi.fileEditor.FileEditorManager;
import com.intellij.openapi.fileEditor.OpenFileDescriptor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.pom.Navigatable;
import com.intellij.psi.*;
import com.intellij.psi.impl.FakePsiElement;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.psi.search.LocalSearchScope;
import com.intellij.psi.search.SearchScope;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.io.File;
import java.util.Objects;

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
                "────────────────────────────────────",
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

                String fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                String location = fileName + ":" + lineNumber;

                // For definitions, add a prefix to make them stand out
                if (isDefinition) {
                    return location;
                }

                return location;
            }

            @Nullable
            @Override
            public String getLocationString() {
                // Extract just the filename without path
                return null;
            }

            @Nullable
            @Override
            public Icon getIcon(boolean unused) {
                return null;
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
}
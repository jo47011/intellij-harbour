package org.intellij.sdk.language;

import com.intellij.navigation.ItemPresentation;
import com.intellij.navigation.NavigationItem;
import com.intellij.openapi.project.Project;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.impl.FakePsiElement;
import com.intellij.psi.search.GlobalSearchScope;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;

/**
 * A dummy PsiElement that shows simple tooltips and prevents
 * "Cannot find declaration" messages
 */
public class HarbourDummyPsiElement extends FakePsiElement implements NavigationItem {
    private final PsiElement source;
    private PsiFile containingFile;
    private Project project;
    private boolean isExternal = true;
    private String tooltipText;

    public HarbourDummyPsiElement(PsiElement source, boolean isExternal) {
        this.source = source;
        this.isExternal = isExternal;
        this.tooltipText = isExternal ? "External" : "Internal";

        if (source != null) {
            try {
                this.containingFile = source.getContainingFile();
                this.project = source.getProject();
            } catch (Exception e) {
                // Ignore exceptions, we'll handle null values
            }
        }
    }

    // Constructor that allows explicit tooltip setting
    public HarbourDummyPsiElement(PsiElement source, boolean isExternal, String tooltipText) {
        this.source = source;
        this.isExternal = isExternal;
        this.tooltipText = tooltipText != null ? tooltipText : (isExternal ? "External" : "Internal");

        if (source != null) {
            try {
                this.containingFile = source.getContainingFile();
                this.project = source.getProject();
            } catch (Exception e) {
                // Ignore exceptions, we'll handle null values
            }
        }
    }

    @Override
    public String getName() {
        return tooltipText;
    }

    @Override
    public ItemPresentation getPresentation() {
        return new ItemPresentation() {
            @Nullable
            @Override
            public String getPresentableText() {
                return tooltipText;
            }

            @Nullable
            @Override
            public String getLocationString() {
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
        // Do nothing - browser is already being opened by the handler
    }

    @Override
    public boolean canNavigate() {
        return true;
    }

    @Override
    public boolean canNavigateToSource() {
        return false;
    }

    @Override
    public PsiElement getParent() {
        if (source != null && source.isValid()) {
            try {
                return source.getParent();
            } catch (Exception e) {
                // Fall back to containing file
            }
        }
        return containingFile;
    }

    @Override
    public boolean isValid() {
        return true;
    }

    @Override
    public PsiFile getContainingFile() {
        return null; // Return null to avoid file name in tooltip
    }

    @Override
    public GlobalSearchScope getResolveScope() {
        return null; // Return null to simplify tooltip
    }

    @Override
    public String toString() {
        return tooltipText; // Return just the tooltip text
    }

    @Override
    public @NotNull Project getProject() {
        if (project != null) {
            return project;
        }
        if (source != null && source.isValid()) {
            try {
                return source.getProject();
            } catch (Exception e) {
                // Handle below
            }
        }
        return super.getProject();
    }
}
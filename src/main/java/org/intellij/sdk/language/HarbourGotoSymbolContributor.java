package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.navigation.ChooseByNameContributorEx;
import com.intellij.navigation.ItemPresentation;
import com.intellij.navigation.NavigationItem;
import com.intellij.openapi.fileEditor.OpenFileDescriptor;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.util.Processor;
import com.intellij.util.indexing.FileBasedIndex;
import com.intellij.util.indexing.FindSymbolParameters;
import com.intellij.util.indexing.IdFilter;
import org.intellij.sdk.language.index.HarbourDeclarationIndex;
import org.intellij.sdk.language.index.HarbourFunctionIndex.FunctionInfo;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;

/**
 * Go to Symbol (Ctrl+Alt+Shift+N): all FUNCTION / PROCEDURE / METHOD declarations of the project.
 * Items are built from HarbourDeclarationIndex only, so no file has to be parsed for the list.
 */
public class HarbourGotoSymbolContributor implements ChooseByNameContributorEx {

    @Override
    public void processNames(@NotNull Processor<? super String> processor,
                             @NotNull GlobalSearchScope scope, @Nullable IdFilter filter) {
        FileBasedIndex.getInstance().processAllKeys(HarbourDeclarationIndex.INDEX_ID, processor, scope, filter);
    }

    @Override
    public void processElementsWithName(@NotNull String name,
                                        @NotNull Processor<? super NavigationItem> processor,
                                        @NotNull FindSymbolParameters parameters) {
        Project project = parameters.getProject();
        FileBasedIndex.getInstance().processValues(HarbourDeclarationIndex.INDEX_ID, name.toLowerCase(), null,
            (file, infos) -> {
                if (HarbourFileUtils.isFileExcluded(project, file)) {
                    return true;
                }
                for (FunctionInfo info : infos) {
                    if (!processor.process(new SymbolItem(project, file, info))) {
                        return false;
                    }
                }
                return true;
            }, parameters.getSearchScope(), parameters.getIdFilter());
    }

    /** Lightweight navigation target: name, file and line taken straight from the index. */
    private static class SymbolItem implements NavigationItem, ItemPresentation {
        private final Project project;
        private final VirtualFile file;
        private final FunctionInfo info;

        SymbolItem(Project project, VirtualFile file, FunctionInfo info) {
            this.project = project;
            this.file = file;
            this.info = info;
        }

        @Override
        public String getName() {
            return info.name;
        }

        @Override
        public ItemPresentation getPresentation() {
            return this;
        }

        @Override
        public String getPresentableText() {
            return info.name;
        }

        @Override
        public String getLocationString() {
            return (info.isStatic ? "STATIC " : "") + info.type + "  " + file.getName() + ":" + info.lineNumber;
        }

        @Override
        public Icon getIcon(boolean unused) {
            return "METHOD".equals(info.type) ? AllIcons.Nodes.Method : AllIcons.Nodes.Function;
        }

        @Override
        public void navigate(boolean requestFocus) {
            new OpenFileDescriptor(project, file, info.lineNumber - 1, 0).navigate(requestFocus);
        }

        @Override
        public boolean canNavigate() {
            return file.isValid();
        }

        @Override
        public boolean canNavigateToSource() {
            return canNavigate();
        }
    }
}

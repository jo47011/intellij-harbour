package org.intellij.sdk.language;

import com.intellij.ide.structureView.StructureViewModel;
import com.intellij.ide.structureView.StructureViewModelBase;
import com.intellij.ide.structureView.StructureViewTreeElement;
import com.intellij.ide.util.treeView.smartTree.Sorter;
import com.intellij.openapi.Disposable;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.Disposer;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

/**
 * Structure View Model for Harbour files
 */
public class HarbourStructureViewModel extends StructureViewModelBase implements
        StructureViewModel.ElementInfoProvider, Disposable {

    private static final Logger LOG = Logger.getInstance(HarbourStructureViewModel.class);
    private boolean isDisposed = false;

    public HarbourStructureViewModel(HarbourFile psiFile) {
        super(psiFile, new HarbourStructureViewElement(psiFile));

        LOG.info("Created structure view model for file: " + psiFile.getName());
    }

    @Override
    public boolean isAlwaysShowsPlus(StructureViewTreeElement element) {
        return element.getValue() instanceof HarbourFile;
    }

    @Override
    public boolean isAlwaysLeaf(StructureViewTreeElement element) {
        return false; // Allow expansion of elements that have children
    }

    @Override
    public @NotNull Sorter[] getSorters() {
        return new Sorter[]{Sorter.ALPHA_SORTER};
    }

    @Override
    public synchronized void dispose() {
        if (!isDisposed) {
            isDisposed = true;
            LOG.info("Disposing Harbour structure view model");

            // Clean up any resources here
            super.dispose();
        }
    }
}
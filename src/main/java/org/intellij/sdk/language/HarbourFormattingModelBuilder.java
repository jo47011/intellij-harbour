package org.intellij.sdk.language;

import com.intellij.formatting.*;
import com.intellij.lang.ASTNode;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiFile;
import com.intellij.psi.codeStyle.CodeStyleSettings;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.Collections;
import java.util.List;

/**
 * Provides formatting model for Harbour code
 */
public class HarbourFormattingModelBuilder implements FormattingModelBuilder {

    @Override
    public @NotNull FormattingModel createModel(@NotNull FormattingContext formattingContext) {
        final PsiFile file = formattingContext.getContainingFile();
        final CodeStyleSettings settings = formattingContext.getCodeStyleSettings();

        HarbourLogger.log("FormattingModelBuilder", "Creating formatting model for " + file.getName());

        // Set formatting flag to prevent reference resolution during formatting
        HarbourTokenTypeExtension.setFormattingInProgress(true);

        try {
            // Create a dummy block without modifying the document
            // The actual formatting happens in the post-processor
            DummyBlock rootBlock = new DummyBlock(file.getNode());
            FormattingModel model = FormattingModelProvider.createFormattingModelForPsiFile(file, rootBlock, settings);


            HarbourLogger.log("FormattingModelBuilder", "Created formatting model for " + file.getName());
            return model;
        } finally {
            // Reset formatting flag
            HarbourTokenTypeExtension.setFormattingInProgress(false);
        }
    }

    /**
     * A dummy block that doesn't do any additional formatting
     */
    private static class DummyBlock implements Block {
        private final ASTNode myNode;

        public DummyBlock(@NotNull ASTNode node) {
            myNode = node;
        }

        @Override
        public @NotNull TextRange getTextRange() {
            return myNode.getTextRange();
        }

        @Override
        public @Nullable Wrap getWrap() {
            return null;
        }

        @Override
        public @Nullable Indent getIndent() {
            return Indent.getNoneIndent();
        }

        @Override
        public @Nullable Alignment getAlignment() {
            return null;
        }

        @Override
        public @NotNull List<Block> getSubBlocks() {
            return Collections.emptyList();
        }

        @Override
        public @Nullable Spacing getSpacing(@Nullable Block child1, @NotNull Block child2) {
            return null;
        }

        @Override
        public @NotNull ChildAttributes getChildAttributes(int newChildIndex) {
            return new ChildAttributes(Indent.getNoneIndent(), null);
        }

        @Override
        public boolean isIncomplete() {
            return false;
        }

        @Override
        public boolean isLeaf() {
            return true;
        }
    }
}
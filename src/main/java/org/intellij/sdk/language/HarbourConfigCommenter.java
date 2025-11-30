package org.intellij.sdk.language;

import com.intellij.lang.Commenter;
import org.jetbrains.annotations.Nullable;

/**
 * Provides commenting functionality for Harbour configuration files.
 * Uses # for line comments (shell-style comments, like .hbp and .hbc files)
 */
public class HarbourConfigCommenter implements Commenter {

    @Nullable
    @Override
    public String getLineCommentPrefix() {
        return "#";
    }

    @Nullable
    @Override
    public String getBlockCommentPrefix() {
        return null;  // No block comments in config files
    }

    @Nullable
    @Override
    public String getBlockCommentSuffix() {
        return null;  // No block comments in config files
    }

    @Nullable
    @Override
    public String getCommentedBlockCommentPrefix() {
        return null;
    }

    @Nullable
    @Override
    public String getCommentedBlockCommentSuffix() {
        return null;
    }
}

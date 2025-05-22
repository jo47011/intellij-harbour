package org.intellij.sdk.language;

import com.intellij.psi.ElementDescriptionLocation;
import com.intellij.psi.ElementDescriptionProvider;
import com.intellij.psi.PsiElement;
import com.intellij.usageView.UsageViewTypeLocation;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Provides clean tooltips for Harbour elements by removing type descriptions
 */
public class HarbourElementDescriptionProvider implements ElementDescriptionProvider {
    @Nullable
    @Override
    public String getElementDescription(@NotNull PsiElement element, @NotNull ElementDescriptionLocation location) {
        if (element instanceof HarbourDummyPsiElement) {
            if (location == UsageViewTypeLocation.INSTANCE) {
                // Return empty string to hide the type name ("Harbour Dummy Psi Element") in tooltips
                return "";
            }
        }
        return null; // Let other providers handle elements we're not customizing
    }
}
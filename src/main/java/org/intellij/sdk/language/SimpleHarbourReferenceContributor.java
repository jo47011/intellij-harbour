package org.intellij.sdk.language;

import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.PsiReferenceContributor;
import com.intellij.psi.PsiReferenceRegistrar;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;

/**
 * Adds references to Harbour PSI elements
 */
public class SimpleHarbourReferenceContributor extends PsiReferenceContributor {

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        HarbourLogger.log("ReferenceContributor", "Registering Harbour reference providers");
        System.out.println("HARBOUR PLUGIN: Registering Harbour reference providers");

        // Register provider for all IDENT tokens inside function calls
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement().withElementType(HarbourTypes.IDENT)
                        .withParent(PlatformPatterns.psiElement().withElementType(HarbourTypes.FUNCTION_CALL)),
                new HarbourReferenceProvider()
        );

        // Log that we've registered providers
        HarbourLogger.log("ReferenceContributor", "Reference providers registered successfully");
        System.out.println("HARBOUR PLUGIN: Reference providers registered successfully");
    }
}
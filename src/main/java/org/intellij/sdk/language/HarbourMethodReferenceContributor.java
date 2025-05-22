package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiReferenceContributor;
import com.intellij.psi.PsiReferenceRegistrar;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import org.intellij.sdk.language.psi.impl.FunctionCallImpl;
import org.jetbrains.annotations.NotNull;

/**
 * Contributes method reference provider for Harbour
 */
public class HarbourMethodReferenceContributor extends PsiReferenceContributor {
    private static final Logger LOG = Logger.getInstance(HarbourMethodReferenceContributor.class);
    private static final String COMPONENT = "MethodRefContributor";

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        HarbourLogger.log(COMPONENT, "Registering method reference provider");

        // Register for function calls
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(FunctionCallImpl.class),
                new HarbourMethodReferenceProvider()
        );

        // Register for identifiers
        registrar.registerReferenceProvider(
                PlatformPatterns.psiElement(LeafPsiElement.class),
                new HarbourMethodReferenceProvider()
        );

        HarbourLogger.log(COMPONENT, "Method reference providers registered");
    }
}
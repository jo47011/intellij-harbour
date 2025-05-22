package org.intellij.sdk.language;

import com.intellij.codeInsight.daemon.RelatedItemLineMarkerInfo;
import com.intellij.codeInsight.daemon.RelatedItemLineMarkerProvider;
import com.intellij.codeInsight.navigation.NavigationGutterIconBuilder;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.psi.PsiElement;
import org.intellij.sdk.language.psi.FunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.ProcedureDeclaration;
import org.jetbrains.annotations.NotNull;

import java.util.Collection;

/**
 * Provides line markers for Harbour functions and methods.
 */
public class HarbourLineMarkerProvider extends RelatedItemLineMarkerProvider {
    private static final Logger LOG = Logger.getInstance(HarbourLineMarkerProvider.class);

    @Override
    protected void collectNavigationMarkers(@NotNull PsiElement element,
                                            @NotNull Collection<? super RelatedItemLineMarkerInfo<?>> result) {
        // Add markers for function declarations
        if (element instanceof FunctionDeclaration) {
            FunctionDeclaration function = (FunctionDeclaration) element;
            PsiElement nameIdentifier = function.getNameIdentifier();

            if (nameIdentifier != null) {
                NavigationGutterIconBuilder<PsiElement> builder =
                        NavigationGutterIconBuilder.create(HarbourIcons.FILE)
                                .setTargets(function)
                                .setTooltipText("Navigate to function declaration");

                result.add(builder.createLineMarkerInfo(nameIdentifier));
            }
        }

        // Add markers for procedure declarations too
        if (element instanceof ProcedureDeclaration) {
            ProcedureDeclaration procedure = (ProcedureDeclaration) element;

            // Find the identifier element directly since ProcedureDeclaration doesn't have getNameIdentifier()
            PsiElement identifier = null;
            for (PsiElement child : procedure.getChildren()) {
                if (child.getNode() != null &&
                        child.getNode().getElementType() == HarbourTypes.IDENT) {
                    identifier = child;
                    break;
                }
            }

            if (identifier != null) {
                NavigationGutterIconBuilder<PsiElement> builder =
                        NavigationGutterIconBuilder.create(HarbourIcons.FILE)
                                .setTargets(procedure)
                                .setTooltipText("Navigate to procedure declaration");

                result.add(builder.createLineMarkerInfo(identifier));
            }
        }
    }
}
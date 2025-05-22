package org.intellij.sdk.language;

import com.intellij.openapi.util.TextRange;
import com.intellij.psi.*;
import com.intellij.util.ProcessingContext;
import org.intellij.sdk.language.psi.FunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.List;

/**
 * Provides references for IDENT elements in function calls
 */
public class HarbourReferenceProvider extends PsiReferenceProvider {

    @Override
    public @NotNull PsiReference[] getReferencesByElement(@NotNull PsiElement element,
                                                          @NotNull ProcessingContext context) {
        String elementText = element.getText();
        HarbourLogger.log("ReferenceProvider", "Creating reference for: " + elementText);

        // Show notification
        com.intellij.notification.Notifications.Bus.notify(
                new com.intellij.notification.Notification(
                        "Harbour Plugin",
                        "Reference Created",
                        "Creating reference for: " + element.getText(),
                        com.intellij.notification.NotificationType.INFORMATION
                )
        );

        // Create a direct PsiReference implementation for immediate navigation
        return new PsiReference[] {
                new PsiReferenceBase<PsiElement>(element) {
                    @Override
                    public @NotNull TextRange getRangeInElement() {
                        return new TextRange(0, element.getTextLength());
                    }

                    @Override
                    public PsiElement resolve() {
                        HarbourLogger.log("ReferenceProvider", "Resolving reference for: " + element.getText());

                        // Find the corresponding function declaration
                        PsiFile file = element.getContainingFile();
                        if (file instanceof HarbourFile) {
                            HarbourFile harbourFile = (HarbourFile) file;

                            // Get all function declarations
                            List<FunctionDeclaration> functions = harbourFile.getFunctionDeclarations();
                            HarbourLogger.log("ReferenceProvider", "Found " + functions.size() + " functions in file");

                            // Find matching function by name
                            String name = myElement.getText();
                            for (FunctionDeclaration function : functions) {
                                String functionName = function.getName();
                                if (name.equalsIgnoreCase(functionName)) {
                                    HarbourLogger.log("ReferenceProvider", "Found matching function: " + functionName);
                                    return function;
                                }
                            }
                        }

                        HarbourLogger.log("ReferenceProvider", "No matching function found for: " + element.getText());
                        return null;
                    }

                    @Override
                    public boolean isSoft() {
                        return false; // Hard reference that will be validated
                    }
                }
        };
    }
}
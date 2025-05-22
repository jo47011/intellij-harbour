package org.intellij.sdk.language;

import com.intellij.openapi.application.ReadAction;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.roots.ProjectRootManager;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.HarbourTypes;

import java.util.Collection;

/**
 * Utility class to check PSI structure of Harbour files.
 */
public class PsiElementTypesChecker {
    private static final Logger LOG = Logger.getInstance(PsiElementTypesChecker.class);

    public static void checkPsiElements(Project project) {
        LOG.info("Checking PSI Element Types registration...");

        // This must be run inside a read action
        ReadAction.run(() -> {
            // Check if IDENT is properly defined
            if (HarbourTypes.IDENT != null) {
                LOG.info("IDENT element type is defined: " + HarbourTypes.IDENT);
            } else {
                LOG.error("IDENT element type is NOT defined!");
            }

            // Try to find and parse a sample Harbour file
            VirtualFile[] contentRoots = ProjectRootManager.getInstance(project).getContentRoots();
            LOG.info("Found " + contentRoots.length + " content roots");

            for (VirtualFile root : contentRoots) {
                LOG.info("Checking content root: " + root.getPath());
                findAndAnalyzeHarbourFiles(project, root);
            }
        });
    }

    private static void findAndAnalyzeHarbourFiles(Project project, VirtualFile directory) {
        if (!directory.isDirectory()) {
            return;
        }

        for (VirtualFile file : directory.getChildren()) {
            if (file.isDirectory()) {
                findAndAnalyzeHarbourFiles(project, file);
                continue;
            }

            if (file.getExtension() != null &&
                    (file.getExtension().equals("prg") || file.getExtension().equals("hb"))) {

                LOG.info("Found Harbour file: " + file.getName());
                PsiFile psiFile = PsiManager.getInstance(project).findFile(file);

                if (psiFile instanceof HarbourFile) {
                    LOG.info("File is a HarbourFile instance");

                    // Look for function declarations
                    Collection<HarbourFunctionDeclaration> functions =
                            PsiTreeUtil.findChildrenOfType(psiFile, HarbourFunctionDeclaration.class);

                    LOG.info("Found " + functions.size() + " function declarations");

                    for (HarbourFunctionDeclaration func : functions) {
                        LOG.info("Function: " + func.getName());

                        // Check if name identifier is available and correctly typed
                        if (func.getNameIdentifier() != null) {
                            LOG.info("  Function has name identifier: " + func.getNameIdentifier().getText());
                            LOG.info("  Element type: " + func.getNameIdentifier().getNode().getElementType().toString());
                        } else {
                            LOG.error("  Function has NO name identifier!");
                        }
                    }
                } else {
                    LOG.error("File is NOT a HarbourFile instance: " +
                            (psiFile != null ? psiFile.getClass().getName() : "null"));
                }
            }
        }
    }
}
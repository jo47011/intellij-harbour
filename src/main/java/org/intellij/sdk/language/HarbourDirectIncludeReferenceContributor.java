package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.TextRange;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.psi.*;
import com.intellij.util.ProcessingContext;
import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Specialized reference contributor for Harbour include statements that acts on files as a whole
 */
public class HarbourDirectIncludeReferenceContributor extends PsiReferenceContributor {
    private static final Logger LOG = Logger.getInstance(HarbourDirectIncludeReferenceContributor.class);
    private static final Pattern INCLUDE_PATTERN = Pattern.compile("(#include|#INCLUDE)\\s*[\"<]([^\">\n]+)[>\"]");
    private static final String COMPONENT = "DirectIncludeRef";

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        // Register for entire files
        registrar.registerReferenceProvider(
                PlatformPatterns.psiFile().withLanguage(HarbourLanguage.INSTANCE),
                new PsiReferenceProvider() {
                    @Override
                    public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element, @NotNull ProcessingContext context) {
                        if (!(element instanceof PsiFile)) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        PsiFile file = (PsiFile) element;
                        LOG.info("Processing entire file for includes: " + file.getName());
                        HarbourLogger.log(COMPONENT, "Processing entire file for includes: " + file.getName());

                        // Parse file text to find all include statements
                        String fileText = file.getText();
                        if (fileText == null || fileText.isEmpty()) {
                            return PsiReference.EMPTY_ARRAY;
                        }

                        return processIncludes(fileText, file);
                    }

                    /**
                     * Process the file text to find include statements and create references
                     */
                    private PsiReference[] processIncludes(String fileText, PsiFile file) {
                        Matcher matcher = INCLUDE_PATTERN.matcher(fileText);
                        List<PsiReference> references = new ArrayList<>();

                        while (matcher.find()) {
                            try {
                                if (matcher.groupCount() < 2) {
                                    continue;
                                }

                                String includeFile = matcher.group(2);
                                if (includeFile == null || includeFile.isEmpty()) {
                                    continue;
                                }

                                int filenameStart = matcher.start(2);
                                int filenameEnd = matcher.end(2);

                                HarbourLogger.log(COMPONENT, "Found include in file text: " + includeFile +
                                        " at position " + filenameStart + " to " + filenameEnd);

                                // Create a reference for this include statement
                                TextRange range = new TextRange(filenameStart, filenameEnd);
                                references.add(new HarbourIncludeReferenceContributor.HarbourIncludeReference(file, range, includeFile));
                            } catch (Exception e) {
                                LOG.error("Error processing include statement: " + e.getMessage(), e);
                                HarbourLogger.log(COMPONENT, "Error processing include statement: " + e.getMessage());
                            }
                        }

                        HarbourLogger.log(COMPONENT, "Created " + references.size() + " include references for file");
                        return references.toArray(new PsiReference[0]);
                    }
                });

        LOG.info("Registered HarbourDirectIncludeReferenceContributor for entire files");
        HarbourLogger.log(COMPONENT, "Registered HarbourDirectIncludeReferenceContributor for entire files");
    }
}
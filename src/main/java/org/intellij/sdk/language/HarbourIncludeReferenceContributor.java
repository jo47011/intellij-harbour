package org.intellij.sdk.language;

import com.intellij.openapi.util.TextRange;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.patterns.PlatformPatterns;
import com.intellij.patterns.PsiElementPattern;
import com.intellij.psi.*;
import com.intellij.util.ProcessingContext;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reference contributor for Harbour #include statements
 */
public class HarbourIncludeReferenceContributor extends PsiReferenceContributor {
    private static final Pattern INCLUDE_PATTERN = Pattern.compile("(#include|#INCLUDE)\\s*[\"<]([^\">\n]+)[>\"]");
    private static final String COMPONENT = "IncludeRef";

    @Override
    public void registerReferenceProviders(@NotNull PsiReferenceRegistrar registrar) {
        // Register for any text in a Harbour file
        PsiElementPattern.Capture<PsiElement> pattern =
                PlatformPatterns.psiElement().inFile(PlatformPatterns.psiFile().withLanguage(HarbourLanguage.INSTANCE));

        HarbourLogger.log("IncludeReferenceContributor", "Registering HarbourIncludeReferenceContributor");
        HarbourLogger.log(COMPONENT, "Registering HarbourIncludeReferenceContributor");

        registrar.registerReferenceProvider(pattern, new PsiReferenceProvider() {
            @Override
            public PsiReference @NotNull [] getReferencesByElement(@NotNull PsiElement element, @NotNull ProcessingContext context) {
                String elementType = element.getClass().getSimpleName();
                String text = element.getText();

                if (text == null || text.isEmpty()) {
                    return PsiReference.EMPTY_ARRAY;
                }

                // Try to find include statements
                Matcher matcher = INCLUDE_PATTERN.matcher(text);
                boolean found = matcher.find();

                // Check if we found a match
                if (!found) {
                    return PsiReference.EMPTY_ARRAY;
                }

                // Safely get the matched group
                if (matcher.groupCount() < 2) {
                    HarbourLogger.log(COMPONENT, "Include pattern matched but has insufficient groups");
                    return PsiReference.EMPTY_ARRAY;
                }

                // Get the filename from the matched pattern
                String includeFile = matcher.group(2);
                if (includeFile == null || includeFile.isEmpty()) {
                    HarbourLogger.log(COMPONENT, "Include pattern matched but filename is empty");
                    return PsiReference.EMPTY_ARRAY;
                }

                HarbourLogger.log(COMPONENT, "Found include file reference: " + includeFile);

                // Calculate the position of the filename within the element
                int startOffset = element.getTextRange().getStartOffset();
                int filenameStart = matcher.start(2);  // Use the start of the second capture group
                int filenameEnd = matcher.end(2);      // Use the end of the second capture group

                if (filenameStart < 0 || filenameEnd < 0) {
                    HarbourLogger.log(COMPONENT, "Could not locate filename position in match");
                    return PsiReference.EMPTY_ARRAY;
                }

                // Create the text range for the reference (just the filename part)
                TextRange range = new TextRange(filenameStart, filenameEnd);

                // Log the exact position and text for verification
                HarbourLogger.log(COMPONENT, "Filename range: " + filenameStart + " to " + filenameEnd +
                        " text: '" + text.substring(filenameStart, filenameEnd) + "'");

                // Create and return the reference
                return new PsiReference[]{
                        new HarbourIncludeReference(element, range.shiftRight(startOffset), includeFile)
                };
            }
        });
    }

    /**
     * Reference implementation for include files
     */
    public static class HarbourIncludeReference extends PsiReferenceBase<PsiElement> {
        private final String includeFile;
        private static final List<String> ALTERNATE_EXTENSIONS = Arrays.asList(".ch", ".h", ".prg", ".CH", ".H", ".PRG");
        private static final String COMPONENT = "IncludeRef";

        public HarbourIncludeReference(@NotNull PsiElement element, TextRange rangeInElement, String includeFile) {
            super(element, rangeInElement);
            this.includeFile = includeFile;
            HarbourLogger.log(COMPONENT, "Created HarbourIncludeReference for: " + includeFile);
        }

        @Override
        public PsiElement resolve() {
            HarbourLogger.log(COMPONENT, "Resolving include reference: " + includeFile);

            try {
                // Get settings to retrieve include paths
                HarbourSettings settings = HarbourSettings.getInstance(getElement().getProject());
                if (settings == null) {
                    HarbourLogger.log(COMPONENT, "ERROR: Could not get HarbourSettings instance");
                    return null;
                }

                List<String> includePaths = settings.getIncludePaths();
                HarbourLogger.log(COMPONENT, "Checking " + includePaths.size() + " include paths");

                // Try to find the file in the include paths
                PsiElement result = findFileInPaths(includePaths);
                if (result != null) {
                    return result;
                }

                // Try in the current directory
                result = findFileInCurrentDirectory();
                if (result != null) {
                    return result;
                }

                // Try with alternate extensions in include paths
                result = findFileWithAlternateExtensions(includePaths);
                if (result != null) {
                    return result;
                }

            } catch (Exception e) {
                HarbourLogger.log(COMPONENT, "ERROR resolving include reference: " + e.getMessage());
                e.printStackTrace();
            }

            HarbourLogger.log(COMPONENT, "Could not resolve include file: " + includeFile);
            return null;
        }

        /**
         * Try to find the file in the given include paths
         */
        @Nullable
        private PsiElement findFileInPaths(List<String> includePaths) {
            HarbourLogger.log(COMPONENT, "findFileInPaths for: " + includeFile);

            for (String path : includePaths) {
                HarbourLogger.log(COMPONENT, "Checking include path: " + path);

                // Try exact filename
                File file = new File(path, includeFile);
                HarbourLogger.log(COMPONENT, "Checking path: " + file.getAbsolutePath() + " (exists: " + file.exists() + ")");

                if (file.exists()) {
                    return getPsiElementFromFile(file);
                }

                // Try case-insensitive search in the directory
                File dir = new File(path);
                if (dir.exists() && dir.isDirectory()) {
                    HarbourLogger.log(COMPONENT, "Directory exists, checking case-insensitively");
                    File[] files = dir.listFiles();
                    if (files != null) {
                        for (File dirFile : files) {
                            if (dirFile.getName().equalsIgnoreCase(includeFile)) {
                                HarbourLogger.log(COMPONENT, "Found case-insensitive match: " + dirFile.getAbsolutePath());
                                return getPsiElementFromFile(dirFile);
                            }
                        }
                    }
                    HarbourLogger.log(COMPONENT, "No case-insensitive match found");
                }
            }

            HarbourLogger.log(COMPONENT, "No match found in any include path");
            return null;
        }

        /**
         * Try to find the file with alternate extensions
         */
        @Nullable
        private PsiElement findFileWithAlternateExtensions(List<String> includePaths) {
            String baseName = stripExtension(includeFile);
            HarbourLogger.log(COMPONENT, "Trying alternate extensions for base name: " + baseName);

            for (String path : includePaths) {
                for (String ext : ALTERNATE_EXTENSIONS) {
                    String altFileName = baseName + ext;
                    File altFile = new File(path, altFileName);
                    HarbourLogger.log(COMPONENT, "Checking alternate extension: " + altFile.getAbsolutePath() + " (exists: " + altFile.exists() + ")");

                    if (altFile.exists()) {
                        HarbourLogger.log(COMPONENT, "Found with alternate extension: " + altFile.getAbsolutePath());
                        return getPsiElementFromFile(altFile);
                    }
                }
            }
            return null;
        }

        /**
         * Try to find the file in the current directory
         */
        @Nullable
        private PsiElement findFileInCurrentDirectory() {
            HarbourLogger.log(COMPONENT, "findFileInCurrentDirectory for: " + includeFile);

            PsiFile currentFile = getElement().getContainingFile();
            if (currentFile == null) {
                HarbourLogger.log(COMPONENT, "Current file is null");
                return null;
            }

            VirtualFile virtualFile = currentFile.getVirtualFile();
            if (virtualFile == null) {
                HarbourLogger.log(COMPONENT, "Current file's virtual file is null");
                return null;
            }

            VirtualFile currentDir = virtualFile.getParent();
            if (currentDir == null) {
                HarbourLogger.log(COMPONENT, "Current file has no parent directory");
                return null;
            }

            HarbourLogger.log(COMPONENT, "Checking current directory: " + currentDir.getPath());

            // Try exact filename
            VirtualFile includeVirtualFile = currentDir.findChild(includeFile);
            if (includeVirtualFile != null) {
                PsiFile includePsiFile = PsiManager.getInstance(getElement().getProject()).findFile(includeVirtualFile);
                if (includePsiFile != null) {
                    HarbourLogger.log(COMPONENT, "Found include file in current directory: " + includeVirtualFile.getPath());
                    return includePsiFile;
                }
            }

            // Try with alternate extensions
            String baseName = stripExtension(includeFile);
            for (String ext : ALTERNATE_EXTENSIONS) {
                String altFileName = baseName + ext;
                VirtualFile altFile = currentDir.findChild(altFileName);
                if (altFile != null) {
                    PsiFile includePsiFile = PsiManager.getInstance(getElement().getProject()).findFile(altFile);
                    if (includePsiFile != null) {
                        HarbourLogger.log(COMPONENT, "Found with alternate extension in current directory: " + altFile.getPath());
                        return includePsiFile;
                    }
                }
            }

            // Try case-insensitive search
            VirtualFile[] children = currentDir.getChildren();
            for (VirtualFile child : children) {
                if (child.getName().equalsIgnoreCase(includeFile)) {
                    PsiFile includePsiFile = PsiManager.getInstance(getElement().getProject()).findFile(child);
                    if (includePsiFile != null) {
                        HarbourLogger.log(COMPONENT, "Found case-insensitive match in current directory: " + child.getPath());
                        return includePsiFile;
                    }
                }
            }

            HarbourLogger.log(COMPONENT, "Include file not found in current directory: " + includeFile);
            return null;
        }

        /**
         * Convert a File to a PsiElement
         */
        @Nullable
        private PsiElement getPsiElementFromFile(File file) {
            HarbourLogger.log(COMPONENT, "Getting PsiElement from file: " + file.getAbsolutePath());

            VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(file);
            if (virtualFile != null) {
                HarbourLogger.log(COMPONENT, "Found VirtualFile: " + virtualFile.getPath());

                PsiFile psiFile = PsiManager.getInstance(getElement().getProject()).findFile(virtualFile);
                if (psiFile != null) {
                    HarbourLogger.log(COMPONENT, "Found include file at: " + file.getAbsolutePath());

                    // Create a navigation element for better presentation
                    String fileName = file.getName();
                    int lineNumber = 1; // Default to first line

                    // Wrap in a HarbourNavigationElement for consistent navigation behavior
                    HarbourNavigationElement navElement = new HarbourNavigationElement(
                            psiFile,
                            fileName,
                            file.getAbsolutePath(),
                            lineNumber,
                            "Include file");

                    HarbourLogger.log(COMPONENT, "Created navigation element for include file: " + fileName);
                    return navElement;
                } else {
                    HarbourLogger.log(COMPONENT, "Virtual file exists but PsiFile is null: " + virtualFile.getPath());
                }
            } else {
                HarbourLogger.log(COMPONENT, "File exists but VirtualFile is null: " + file.getAbsolutePath());
            }
            return null;
        }

        /**
         * Strip extension from filename
         */
        private String stripExtension(String filename) {
            int dotPos = filename.lastIndexOf('.');
            if (dotPos > 0) {
                return filename.substring(0, dotPos);
            }
            return filename;
        }

        @Override
        public Object @NotNull [] getVariants() {
            return EMPTY_ARRAY;
        }
    }
}
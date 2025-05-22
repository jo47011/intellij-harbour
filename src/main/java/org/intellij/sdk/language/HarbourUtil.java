package org.intellij.sdk.language;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Utility methods for Harbour plugin
 */
public class HarbourUtil {
    private static final Logger LOG = Logger.getInstance(HarbourUtil.class);

    /**
     * Find all function, procedure, and method declarations in a project
     */
    public static Map<String, List<PsiElement>> findAllFunctionDeclarations(
            @NotNull Project project,
            @NotNull Set<String> excludedFiles,
            @NotNull List<Pattern> excludedPatterns) {

        Map<String, List<PsiElement>> result = new ConcurrentHashMap<>();
        Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(HarbourFileType.INSTANCE,
                GlobalSearchScope.allScope(project));

        // Patterns for different types of declarations
        Pattern functionPattern = Pattern.compile("\\bFUNCTION\\s+(\\w+)\\b", Pattern.CASE_INSENSITIVE);
        Pattern procedurePattern = Pattern.compile("\\bPROCEDURE\\s+(\\w+)\\b", Pattern.CASE_INSENSITIVE);
        Pattern methodPattern = Pattern.compile("\\bMETHOD\\s+(\\w+)\\s*(?:\\(|$)", Pattern.CASE_INSENSITIVE);
        Pattern classMethodPattern = Pattern.compile("\\bMETHOD\\s+(\\w+)\\s*\\(.*?\\)\\s*CLASS\\s+(\\w+)",
                Pattern.CASE_INSENSITIVE);

        for (VirtualFile virtualFile : virtualFiles) {
            // Skip excluded files
            if (excludedFiles.contains(virtualFile.getName().toLowerCase())) {
                continue;
            }

            boolean excluded = false;
            for (Pattern pattern : excludedPatterns) {
                if (pattern.matcher(virtualFile.getPath()).matches()) {
                    excluded = true;
                    break;
                }
            }
            if (excluded) continue;

            // Process file
            HarbourFile harbourFile = (HarbourFile) PsiManager.getInstance(project).findFile(virtualFile);
            if (harbourFile != null) {
                String fileContent = harbourFile.getText();

                // Find functions
                findDeclarations(harbourFile, fileContent, functionPattern, 1, result);

                // Find procedures
                findDeclarations(harbourFile, fileContent, procedurePattern, 1, result);

                // Find methods
                findDeclarations(harbourFile, fileContent, methodPattern, 1, result);

                // Find class methods
                findDeclarations(harbourFile, fileContent, classMethodPattern, 1, result);
            }
        }

        return result;
    }

    /**
     * Find specific function declarations in a project
     */
    public static List<PsiElement> findFunctionDeclarations(
            @NotNull Project project,
            @NotNull String functionName,
            @NotNull Set<String> excludedFiles,
            @NotNull List<Pattern> excludedPatterns) {

        List<PsiElement> result = new ArrayList<>();
        Collection<VirtualFile> virtualFiles = FileTypeIndex.getFiles(HarbourFileType.INSTANCE,
                GlobalSearchScope.allScope(project));

        // Normalize function name for case-insensitive comparison
        String normalizedName = functionName.toLowerCase();

        // Patterns for different types of declarations
        Pattern functionPattern = Pattern.compile("\\bFUNCTION\\s+" + Pattern.quote(normalizedName) + "\\b",
                Pattern.CASE_INSENSITIVE);
        Pattern procedurePattern = Pattern.compile("\\bPROCEDURE\\s+" + Pattern.quote(normalizedName) + "\\b",
                Pattern.CASE_INSENSITIVE);
        Pattern methodPattern = Pattern.compile("\\bMETHOD\\s+" + Pattern.quote(normalizedName) + "\\s*(?:\\(|$)",
                Pattern.CASE_INSENSITIVE);
        Pattern classMethodPattern = Pattern.compile("\\bMETHOD\\s+" + Pattern.quote(normalizedName) +
                "\\s*\\(.*?\\)\\s*CLASS\\s+\\w+", Pattern.CASE_INSENSITIVE);

        for (VirtualFile virtualFile : virtualFiles) {
            // Skip excluded files
            if (excludedFiles.contains(virtualFile.getName().toLowerCase())) {
                continue;
            }

            boolean excluded = false;
            for (Pattern pattern : excludedPatterns) {
                if (pattern.matcher(virtualFile.getPath()).matches()) {
                    excluded = true;
                    break;
                }
            }
            if (excluded) continue;

            // Process file
            PsiFile psiFile = PsiManager.getInstance(project).findFile(virtualFile);
            if (psiFile instanceof HarbourFile) {
                HarbourFile harbourFile = (HarbourFile) psiFile;
                String fileContent = harbourFile.getText();

                // Search for declarations
                findAndAddDeclarations(harbourFile, fileContent, functionPattern, result);
                findAndAddDeclarations(harbourFile, fileContent, procedurePattern, result);
                findAndAddDeclarations(harbourFile, fileContent, methodPattern, result);
                findAndAddDeclarations(harbourFile, fileContent, classMethodPattern, result);
            }
        }

        return result;
    }

    /**
     * Find declarations using a pattern and add to a map
     */
    private static void findDeclarations(
            @NotNull HarbourFile file,
            @NotNull String content,
            @NotNull Pattern pattern,
            int nameGroup,
            @NotNull Map<String, List<PsiElement>> result) {

        Matcher matcher = pattern.matcher(content);
        while (matcher.find()) {
            try {
                String name = matcher.group(nameGroup).toLowerCase();
                int offset = matcher.start();
                PsiElement element = file.findElementAt(offset);
                if (element != null) {
                    result.computeIfAbsent(name, k -> new ArrayList<>()).add(element);
                }
            } catch (Exception e) {
                // Skip invalid matches
                LOG.warn("Error processing declaration match", e);
            }
        }
    }

    /**
     * Find declarations using a pattern and add to a list
     */
    private static void findAndAddDeclarations(
            @NotNull HarbourFile file,
            @NotNull String content,
            @NotNull Pattern pattern,
            @NotNull List<PsiElement> result) {

        Matcher matcher = pattern.matcher(content);
        while (matcher.find()) {
            try {
                int offset = matcher.start();
                PsiElement element = file.findElementAt(offset);
                if (element != null) {
                    result.add(element);
                }
            } catch (Exception e) {
                // Skip invalid matches
                LOG.warn("Error processing declaration match", e);
            }
        }
    }
}
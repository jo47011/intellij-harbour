package org.intellij.sdk.language;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.FileTypeIndex;
import com.intellij.psi.search.GlobalSearchScope;

import java.io.File;
import java.util.Collection;
import java.util.List;
import java.util.Set;

/**
 * Utility methods for file operations in Harbour plugin
 */
public class HarbourFileUtils {

    /**
     * Find a file in the include paths, ignoring case
     * @param project The project
     * @param filename The filename to find
     * @return The PsiFile if found, null otherwise
     */
    public static PsiFile findIncludeFile(Project project, String filename) {
        HarbourSettings settings = HarbourSettings.getInstance(project);
        List<String> includePaths = settings.getResolvedIncludePaths(project);

        // First try exact match
        for (String path : includePaths) {
            File file = new File(path, filename);
            if (file.exists()) {
                return getPsiFile(project, file);
            }
        }

        // If exact match fails, try case-insensitive search
        String lowerFilename = filename.toLowerCase();
        for (String path : includePaths) {
            File dir = new File(path);
            if (!dir.exists() || !dir.isDirectory()) {
                continue;
            }

            File[] files = dir.listFiles();
            if (files == null) {
                continue;
            }

            for (File file : files) {
                if (file.getName().toLowerCase().equals(lowerFilename)) {
                    return getPsiFile(project, file);
                }
            }
        }

        // Try with additional extensions if no extension provided
        if (!filename.contains(".")) {
            String[] extensions = {".ch", ".h", ".prg"};
            for (String ext : extensions) {
                PsiFile result = findIncludeFile(project, filename + ext);
                if (result != null) {
                    return result;
                }
            }
        }

        return null;
    }

    /**
     * Convert a File to PsiFile
     */
    private static PsiFile getPsiFile(Project project, File file) {
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByIoFile(file);
        if (vFile != null) {
            return PsiManager.getInstance(project).findFile(vFile);
        }
        return null;
    }

    /**
     * Check if a file exists in any include path, ignoring case
     * @param project The project
     * @param filename The filename to check
     * @return True if file exists, false otherwise
     */
    public static boolean fileExistsInIncludePaths(Project project, String filename) {
        HarbourSettings settings = HarbourSettings.getInstance(project);
        List<String> includePaths = settings.getResolvedIncludePaths(project);

        // Try exact match first
        for (String path : includePaths) {
            File file = new File(path, filename);
            if (file.exists()) {
                return true;
            }
        }

        // Try case-insensitive match
        String lowerFilename = filename.toLowerCase();
        for (String path : includePaths) {
            File dir = new File(path);
            if (!dir.exists() || !dir.isDirectory()) {
                continue;
            }

            File[] files = dir.listFiles();
            if (files == null) {
                continue;
            }

            for (File file : files) {
                if (file.getName().toLowerCase().equals(lowerFilename)) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Find all Harbour files in the project within the given scope
     *
     * @param project The project to search in
     * @param scope The scope to limit the search to
     * @return Collection of VirtualFile objects representing Harbour files
     */
    public static Collection<VirtualFile> findHarbourFiles(Project project, GlobalSearchScope scope) {
        return FileTypeIndex.getFiles(HarbourFileType.INSTANCE, scope);
    }

    /**
     * Find all Harbour files in the entire project
     *
     * @param project The project to search in
     * @return Collection of VirtualFile objects representing Harbour files
     */
    public static Collection<VirtualFile> findHarbourFiles(Project project) {
        return findHarbourFiles(project, GlobalSearchScope.projectScope(project));
    }

    /**
     * Check if a file should be excluded from navigation based on settings
     *
     * @param project The project
     * @param file The virtual file to check
     * @return True if the file should be excluded, false otherwise
     */
    public static boolean isFileExcluded(Project project, VirtualFile file) {
        if (file == null) {
            return false;
        }

        String filename = file.getName();
        HarbourSettings settings = HarbourSettings.getInstance(project);
        Set<String> excludedFiles = settings.getExcludedFiles();

        return excludedFiles.contains(filename);
    }

    /**
     * Check if a file should be excluded from navigation based on settings
     *
     * @param project The project
     * @param filename The filename to check
     * @return True if the file should be excluded, false otherwise
     */
    public static boolean isFileExcluded(Project project, String filename) {
        if (filename == null || filename.isEmpty()) {
            return false;
        }

        HarbourSettings settings = HarbourSettings.getInstance(project);
        Set<String> excludedFiles = settings.getExcludedFiles();

        return excludedFiles.contains(filename);
    }

    /**
     * Normalize a file path to use OS-appropriate separators
     * Converts Unix-style paths (with forward slashes) to the native OS format
     *
     * @param path The path to normalize
     * @return The path with OS-appropriate separators
     */
    public static String normalizePathSeparators(String path) {
        if (path == null || path.isEmpty()) {
            return path;
        }
        
        // Convert to OS-appropriate separators
        return path.replace('/', File.separatorChar).replace('\\', File.separatorChar);
    }

    /**
     * Get VirtualFile from a path string, useful for file chooser initialization
     * 
     * @param path The file or directory path
     * @return VirtualFile if path exists, null otherwise
     */
    public static VirtualFile getVirtualFileFromPath(String path) {
        if (path == null || path.trim().isEmpty()) {
            return null;
        }
        
        // Normalize path separators first
        String normalizedPath = normalizePathSeparators(path.trim());
        File file = new File(normalizedPath);
        
        // If file doesn't exist, try parent directory for file paths
        if (!file.exists() && file.getParentFile() != null && file.getParentFile().exists()) {
            file = file.getParentFile();
        }
        
        if (file.exists()) {
            return LocalFileSystem.getInstance().findFileByIoFile(file);
        }
        
        return null;
    }
}
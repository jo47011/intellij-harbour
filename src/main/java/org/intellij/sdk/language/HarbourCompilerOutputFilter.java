package org.intellij.sdk.language;

import com.intellij.execution.filters.Filter;
import com.intellij.execution.filters.HyperlinkInfo;
import com.intellij.execution.filters.OpenFileHyperlinkInfo;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.execution.ui.ConsoleViewContentType;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Filter Harbour compiler output to create file links and highlight errors.
 */
public class HarbourCompilerOutputFilter implements Filter {
    private final Project project;

    // Pattern to match file:line references in compiler output
    private static final Pattern FILE_PATTERN = Pattern.compile("([^:]+)\\((\\d+)\\)");

    // Pattern to match error codes in compiler output
    private static final Pattern ERROR_PATTERN = Pattern.compile("Error [A-Z]\\d+");

    public HarbourCompilerOutputFilter(Project project) {
        this.project = project;
        HarbourLogger.log("HarbourCompilerOutputFilter", "Filter initialized");
    }

    /**
     * Process a line of compiler or program output and filter/recognize patterns.
     *
     * @param line Output line from compiler or program
     * @return Filtered result with links or highlighting as needed
     */
    @Nullable
    @Override
    public Result applyFilter(@NotNull String line, int entireLength) {
        HarbourLogger.log("HarbourCompilerOutputFilter", "Processing: " + line);

        Result result = null;
        Matcher fileMatcher = FILE_PATTERN.matcher(line);
        Matcher errorMatcher = ERROR_PATTERN.matcher(line);

        // Check for compiler error with file and line
        if (fileMatcher.find()) {
            String filePath = fileMatcher.group(1);
            int lineNumber = Integer.parseInt(fileMatcher.group(2));
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found file reference: " + filePath + ":" + lineNumber);

            result = createResult(line, entireLength, filePath, lineNumber);
        }
        // Check for generic error with code
        else if (errorMatcher.find()) {
            HarbourLogger.log("HarbourCompilerOutputFilter", "Found error: " + errorMatcher.group(0));

            // Just mark as error without link
            result = new Result(entireLength - line.length(), entireLength, null,
                    ConsoleViewContentType.ERROR_OUTPUT.getAttributes());
        }
        // For normal output, we'll just leave it as is

        return result;
    }

    /**
     * Create a result with file hyperlink.
     */
    private Result createResult(String line, int entireLength, String filePath, int lineNumber) {
        VirtualFile vFile = LocalFileSystem.getInstance().findFileByPath(filePath);
        HyperlinkInfo hyperlinkInfo = null;

        if (vFile != null) {
            hyperlinkInfo = new OpenFileHyperlinkInfo(project, vFile, lineNumber - 1);
        }

        // Create result with hyperlink
        return new Result(entireLength - line.length(), entireLength, hyperlinkInfo, null);
    }
}
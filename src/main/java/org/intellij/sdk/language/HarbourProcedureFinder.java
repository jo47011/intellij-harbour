package org.intellij.sdk.language;

import com.intellij.openapi.vfs.VirtualFile;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.ArrayList;
import java.util.List;

/**
 * A utility class to directly find procedure and function declarations in Harbour files
 */
public class HarbourProcedureFinder {
    private static final String COMPONENT = "ProcedureFinder";

    // Key patterns for Harbour language declarations
    private static final Pattern PROCEDURE_PATTERN = Pattern.compile(
            "^\\s*PROCEDURE\\s+([A-Za-z0-9_]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern FUNCTION_PATTERN = Pattern.compile(
            "^\\s*FUNCTION\\s+([A-Za-z0-9_]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern METHOD_PATTERN = Pattern.compile(
            "^\\s*METHOD\\s+([A-Za-z0-9_]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern STATIC_PROCEDURE_PATTERN = Pattern.compile(
            "^\\s*STATIC\\s+PROCEDURE\\s+([A-Za-z0-9_]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern STATIC_FUNCTION_PATTERN = Pattern.compile(
            "^\\s*STATIC\\s+FUNCTION\\s+([A-Za-z0-9_]+)", Pattern.CASE_INSENSITIVE);

    // Comment patterns to filter out
    private static final Pattern COMMENT_LINE_PATTERN = Pattern.compile(
            "^\\s*(?://.*|\\*.*|/\\*.*|.*\\*/)\\s*$", Pattern.CASE_INSENSITIVE);

    /**
     * Find the line number of a specific procedure/function/method in a file
     *
     * @param file The virtual file to search in
     * @param name The name of the procedure/function/method to find
     * @param occurrence Which occurrence to find (1 for first, 2 for second, etc.)
     * @return The line number (1-based) or -1 if not found
     */
    public static int findDeclarationLine(VirtualFile file, String name, int occurrence) {
        if (file == null || name == null || name.isEmpty()) {
            return -1;
        }

        HarbourLogger.log(COMPONENT, "Looking for declaration: '" + name + "', occurrence: " + occurrence);

        try {
            String content = new String(file.contentsToByteArray());
            String[] lines = content.split("\n");

            // Get all declarations with details
            List<DeclarationInfo> declarations = findAllDeclarations(lines, name);

            // Log finding details
            if (!declarations.isEmpty()) {
                StringBuilder sb = new StringBuilder("Found " + declarations.size() +
                        " declarations of '" + name + "' in " + file.getName() + ":");
                for (DeclarationInfo info : declarations) {
                    sb.append("\n  Line ").append(info.lineNumber)
                            .append(": ").append(info.type)
                            .append(" '").append(info.name)
                            .append("' - context: '").append(info.lineText).append("'");
                }
                HarbourLogger.log(COMPONENT, sb.toString());
            } else {
                HarbourLogger.log(COMPONENT, "No declarations found for '" + name + "' in " + file.getName());
            }

            // If we have enough occurrences, return the requested one
            if (declarations.size() >= occurrence && occurrence > 0) {
                int result = declarations.get(occurrence - 1).lineNumber;
                HarbourLogger.log(COMPONENT, "Returning line " + result + " for occurrence " + occurrence);
                return result;
            }
        } catch (Exception e) {
            HarbourLogger.logStackTrace(COMPONENT, e);
            HarbourLogger.log(COMPONENT, "Error finding declaration: " + e.getMessage());
        }

        return -1;
    }

    /**
     * Count occurrences of a procedure/function/method in a file
     */
    public static int countDeclarations(VirtualFile file, String name) {
        if (file == null || name == null || name.isEmpty()) {
            return 0;
        }

        HarbourLogger.log(COMPONENT, "Counting declarations for: '" + name + "' in " + file.getName());

        try {
            String content = new String(file.contentsToByteArray());
            String[] lines = content.split("\n");

            List<DeclarationInfo> declarations = findAllDeclarations(lines, name);

            HarbourLogger.log(COMPONENT, "Found " + declarations.size() + " occurrences of '" + name + "' in " + file.getName());
            return declarations.size();
        } catch (Exception e) {
            HarbourLogger.log(COMPONENT, "Error counting declarations: " + e.getMessage());
        }

        return 0;
    }

    /**
     * Find all declarations of the given name in the file content
     *
     * @param lines The lines of the file
     * @param name The name to search for
     * @return List of declaration info objects
     */
    private static List<DeclarationInfo> findAllDeclarations(String[] lines, String name) {
        List<DeclarationInfo> declarations = new ArrayList<>();

        // Process each line to find declarations
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].trim();

            // Skip if line is empty or a comment
            if (line.isEmpty() || COMMENT_LINE_PATTERN.matcher(line).matches()) {
                continue;
            }

            DeclarationInfo info = checkLineForDeclaration(line, i + 1, name);
            if (info != null) {
                declarations.add(info);
            }
        }

        return declarations;
    }

    /**
     * Check if a line contains a declaration of the given name
     */
    private static DeclarationInfo checkLineForDeclaration(String line, int lineNumber, String name) {
        // Check for STATIC PROCEDURE declaration
        Matcher staticProcMatcher = STATIC_PROCEDURE_PATTERN.matcher(line);
        if (staticProcMatcher.find()) {
            String declName = staticProcMatcher.group(1);
            if (declName.equalsIgnoreCase(name)) {
                return new DeclarationInfo(declName, "STATIC PROCEDURE", lineNumber, line);
            }
        }

        // Check for STATIC FUNCTION declaration
        Matcher staticFuncMatcher = STATIC_FUNCTION_PATTERN.matcher(line);
        if (staticFuncMatcher.find()) {
            String declName = staticFuncMatcher.group(1);
            if (declName.equalsIgnoreCase(name)) {
                return new DeclarationInfo(declName, "STATIC FUNCTION", lineNumber, line);
            }
        }

        // Check for PROCEDURE declaration
        Matcher procMatcher = PROCEDURE_PATTERN.matcher(line);
        if (procMatcher.find()) {
            String declName = procMatcher.group(1);
            if (declName.equalsIgnoreCase(name)) {
                return new DeclarationInfo(declName, "PROCEDURE", lineNumber, line);
            }
        }

        // Check for FUNCTION declaration
        Matcher funcMatcher = FUNCTION_PATTERN.matcher(line);
        if (funcMatcher.find()) {
            String declName = funcMatcher.group(1);
            if (declName.equalsIgnoreCase(name)) {
                return new DeclarationInfo(declName, "FUNCTION", lineNumber, line);
            }
        }

        // Check for METHOD declaration
        Matcher methMatcher = METHOD_PATTERN.matcher(line);
        if (methMatcher.find()) {
            String declName = methMatcher.group(1);
            if (declName.equalsIgnoreCase(name)) {
                return new DeclarationInfo(declName, "METHOD", lineNumber, line);
            }
        }

        return null;
    }

    /**
     * Class to hold information about a declaration
     */
    private static class DeclarationInfo {
        final String name;
        final String type;
        final int lineNumber;
        final String lineText;

        DeclarationInfo(String name, String type, int lineNumber, String lineText) {
            this.name = name;
            this.type = type;
            this.lineNumber = lineNumber;
            this.lineText = lineText;
        }
    }
}
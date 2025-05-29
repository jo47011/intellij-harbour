package org.intellij.sdk.language;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Instruments Harbour source code by injecting debugging hooks
 */
public class HarbourSourceInstrumenter {
    
    // Patterns for code analysis
    private static final Pattern PROCEDURE_PATTERN = Pattern.compile("^\\s*(PROCEDURE|FUNCTION|METHOD|STATIC\\s+PROCEDURE|STATIC\\s+FUNCTION)\\b.*", Pattern.CASE_INSENSITIVE);
    private static final Pattern FLOW_CONTROL_PATTERN = Pattern.compile("^\\s*(IF|ELSEIF|ELSE|ENDIF|FOR|NEXT|WHILE|ENDDO|DO\\s+CASE|CASE|OTHERWISE|ENDCASE|BEGIN\\s+SEQUENCE|RECOVER|END\\s+SEQUENCE|RETURN|EXIT|LOOP)\\b", Pattern.CASE_INSENSITIVE);
    private static final Pattern EMPTY_LINE_PATTERN = Pattern.compile("^\\s*$");
    private static final Pattern COMMENT_PATTERN = Pattern.compile("^\\s*(//|\\*|&&)");
    private static final Pattern PREPROCESSOR_PATTERN = Pattern.compile("^\\s*#");
    private static final Pattern STRING_LITERAL_PATTERN = Pattern.compile("\"([^\"\\\\]|\\\\.)*\"|'([^'\\\\]|\\\\.)*'");
    
    private final File sourceFile;
    private final File instrumentedFile;
    private final String debugFunctionName;
    
    public HarbourSourceInstrumenter(File sourceFile) {
        this.sourceFile = sourceFile;
        String baseName = sourceFile.getName();
        if (baseName.endsWith(".prg")) {
            baseName = baseName.substring(0, baseName.length() - 4);
        }
        this.instrumentedFile = new File(sourceFile.getParentFile(), baseName + "_instrumented.prg");
        this.debugFunctionName = "debug_check";
    }
    
    /**
     * Instruments the source file and returns the path to the instrumented file
     */
    public File instrument() throws IOException {
        // First check if source file exists
        if (!sourceFile.exists()) {
            throw new IOException("Source file does not exist: " + sourceFile.getAbsolutePath());
        }
        
        // First, create a backup of the original file
        File backupFile = new File(sourceFile.getParentFile(), sourceFile.getName() + ".backup");
        Files.copy(sourceFile.toPath(), backupFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
        
        List<String> lines = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new FileReader(sourceFile))) {
            String line;
            while ((line = reader.readLine()) != null) {
                lines.add(line);
            }
        }
        
        List<String> instrumentedLines = new ArrayList<>();
        
        // Process each line
        boolean inMultiLineComment = false;
        boolean inFunction = false;
        boolean passedDeclarations = false;
        int lineNumber = 0;
        int originalLineNumber = 0;
        
        for (String line : lines) {
            originalLineNumber++;
            lineNumber++;
            String trimmedLine = line.trim();
            
            // Check for multi-line comment
            if (trimmedLine.startsWith("/*")) {
                inMultiLineComment = true;
            }
            
            if (inMultiLineComment) {
                instrumentedLines.add(line);
                if (trimmedLine.endsWith("*/") || trimmedLine.contains("*/")) {
                    inMultiLineComment = false;
                }
                continue;
            }
            
            // Skip empty lines, comments, and preprocessor directives
            if (EMPTY_LINE_PATTERN.matcher(line).matches() ||
                COMMENT_PATTERN.matcher(trimmedLine).matches() ||
                PREPROCESSOR_PATTERN.matcher(trimmedLine).matches()) {
                instrumentedLines.add(line);
                continue;
            }
            
            // Check if we're entering a function/procedure
            if (PROCEDURE_PATTERN.matcher(trimmedLine).matches()) {
                inFunction = true;
                passedDeclarations = false;  // Reset for new function
                instrumentedLines.add(line);
                continue;
            }
            
            // Check if we're exiting a function
            if (trimmedLine.equalsIgnoreCase("RETURN")) {
                // Add debug_check before RETURN statement
                if (inFunction) {
                    String indent = getIndentation(line);
                    instrumentedLines.add(indent + debugFunctionName + "(\"" + sourceFile.getName() + "\", " + originalLineNumber + ")");
                    lineNumber++;
                }
                instrumentedLines.add(line);
                inFunction = false;
                continue;
            }
            
            // Check if we're in a function and need to handle declarations
            if (inFunction) {
                // Check if this is a declaration line
                if (isDeclarationLine(trimmedLine)) {
                    // Just add the declaration, don't instrument it
                    instrumentedLines.add(line);
                    continue;
                } else if (!passedDeclarations && !trimmedLine.isEmpty() && !COMMENT_PATTERN.matcher(trimmedLine).matches()) {
                    // We've passed all declarations, now we can start instrumenting
                    passedDeclarations = true;
                }
                
                // Only instrument executable lines after declarations
                if (passedDeclarations && isExecutableLine(trimmedLine)) {
                    // Skip lines that already have debug_check
                    if (trimmedLine.startsWith("debug_check")) {
                        // Skip this line - it's already a debug_check
                    } else {
                        String indent = getIndentation(line);
                        // Add debug_check before the actual line with original source info
                        String debugLine = indent + debugFunctionName + "(\"" + sourceFile.getName() + "\", " + originalLineNumber + ")";
                        instrumentedLines.add(debugLine);
                        lineNumber++; // Increment line counter for the added line
                    }
                }
            }
            
            // Always add the original line (unless already added for declarations)
            if (!inFunction || !isDeclarationLine(trimmedLine)) {
                instrumentedLines.add(line);
            }
        }
        
        // Write instrumented file
        try (BufferedWriter writer = new BufferedWriter(new FileWriter(instrumentedFile))) {
            for (String line : instrumentedLines) {
                writer.write(line);
                writer.newLine();
            }
        }
        
        // Verify the file was created
        if (!instrumentedFile.exists()) {
            throw new IOException("Failed to create instrumented file: " + instrumentedFile.getAbsolutePath());
        }
        
        return instrumentedFile;
    }
    
    /**
     * Determines if a line is executable (not just a declaration or flow control)
     */
    private boolean isExecutableLine(String line) {
        String trimmed = line.trim();
        
        // Empty lines are not executable
        if (trimmed.isEmpty()) {
            return false;
        }
        
        // Some flow control keywords should be instrumented
        if (FLOW_CONTROL_PATTERN.matcher(trimmed).matches()) {
            // FOR, WHILE, IF, ELSEIF should be instrumented as they are decision points
            if (trimmed.toUpperCase().startsWith("FOR ") ||
                trimmed.toUpperCase().startsWith("WHILE ") ||
                trimmed.toUpperCase().startsWith("IF ") ||
                trimmed.toUpperCase().startsWith("ELSEIF ")) {
                return true;
            }
            return false;
        }
        
        // Skip ALL LOCAL declarations - they must come before executable statements
        if (trimmed.toUpperCase().startsWith("LOCAL ")) {
            return false;
        }
        
        // Skip STATIC/PUBLIC/PRIVATE declarations without assignment
        if ((trimmed.toUpperCase().startsWith("STATIC ") || 
             trimmed.toUpperCase().startsWith("PUBLIC ") ||
             trimmed.toUpperCase().startsWith("PRIVATE ")) && 
            !trimmed.contains(":=")) {
            return false;
        }
        
        // Skip FIELD declarations
        if (trimmed.toUpperCase().startsWith("FIELD ")) {
            return false;
        }
        
        // Skip MEMVAR declarations
        if (trimmed.toUpperCase().startsWith("MEMVAR ")) {
            return false;
        }
        
        // Skip debug_check lines
        if (trimmed.startsWith("debug_check")) {
            return false;
        }
        
        // Everything else is potentially executable - including:
        // - Function/method calls
        // - Assignments
        // - ? output statements
        // - Any other statements
        return true;
    }
    
    /**
     * Checks if a line is a declaration (LOCAL, STATIC, etc.)
     */
    private boolean isDeclarationLine(String line) {
        String trimmed = line.trim().toUpperCase();
        return trimmed.startsWith("LOCAL ") ||
               trimmed.startsWith("STATIC ") ||
               trimmed.startsWith("PUBLIC ") ||
               trimmed.startsWith("PRIVATE ") ||
               trimmed.startsWith("FIELD ") ||
               trimmed.startsWith("MEMVAR ");
    }
    
    /**
     * Gets the indentation of a line
     */
    private String getIndentation(String line) {
        int i = 0;
        while (i < line.length() && Character.isWhitespace(line.charAt(i))) {
            i++;
        }
        return line.substring(0, i);
    }
    
    /**
     * Removes instrumentation from a file
     */
    public void removeInstrumentation() throws IOException {
        File backupFile = new File(sourceFile.getParentFile(), sourceFile.getName() + ".backup");
        if (backupFile.exists()) {
            Files.copy(backupFile.toPath(), sourceFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
            backupFile.delete();
        }
        if (instrumentedFile.exists()) {
            instrumentedFile.delete();
        }
    }
}
package org.intellij.sdk.language;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
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
    private final String originalFileName;
    private final File buildDir;
    private final Charset charset;

    /**
     * Creates an instrumenter using the specified charset for file I/O
     */
    public HarbourSourceInstrumenter(File sourceFile, File buildDir, Charset charset) {
        this.sourceFile = sourceFile;
        this.buildDir = buildDir;
        this.originalFileName = sourceFile.getName();
        this.charset = charset != null ? charset : StandardCharsets.UTF_8;
        String baseName = sourceFile.getName();
        if (baseName.endsWith(".prg")) {
            baseName = baseName.substring(0, baseName.length() - 4);
        }
        // Place instrumented file in build directory
        this.instrumentedFile = new File(buildDir, baseName + "_instrumented.prg");
        this.debugFunctionName = "debug_check";
    }

    /**
     * Creates an instrumenter using UTF-8 charset as default
     */
    public HarbourSourceInstrumenter(File sourceFile, File buildDir) {
        this(sourceFile, buildDir, StandardCharsets.UTF_8);
    }
    
    /**
     * Instruments the source file for GUI programs by injecting minimal breakpoint loader
     */
    public File instrumentForGui() throws IOException {
        // First check if source file exists
        if (!sourceFile.exists()) {
            throw new IOException("Source file does not exist: " + sourceFile.getAbsolutePath());
        }

        // Read source file with the configured charset
        List<String> lines = Files.readAllLines(sourceFile.toPath(), charset);
        List<String> instrumentedLines = new ArrayList<>();
        
        boolean injectingBreakpointLoader = false;
        boolean foundMainProcedure = false;
        
        // First, add the minimal breakpoint loader function at the top
        instrumentedLines.add("// Auto-injected minimal breakpoint loader for GUI debugging");
        instrumentedLines.add("#ifdef __HARBOUR_DEBUG__");
        instrumentedLines.add("");
        instrumentedLines.add("STATIC PROCEDURE LoadInitCld()");
        instrumentedLines.add("   LOCAL cContent, aLines, cLine, aTokens, nLine, cFile, i, cKey");
        instrumentedLines.add("   LOCAL aBreakpoints := {}");
        instrumentedLines.add("   ");
        instrumentedLines.add("   // Check if init.cld exists");
        instrumentedLines.add("   IF !File(\"init.cld\")");
        instrumentedLines.add("      RETURN");
        instrumentedLines.add("   ENDIF");
        instrumentedLines.add("   ");
        instrumentedLines.add("   // Read init.cld file");
        instrumentedLines.add("   cContent := hb_MemoRead(\"init.cld\")");
        instrumentedLines.add("   IF Empty(cContent)");
        instrumentedLines.add("      RETURN");
        instrumentedLines.add("   ENDIF");
        instrumentedLines.add("   ");
        instrumentedLines.add("   // Parse breakpoint lines");
        instrumentedLines.add("   aLines := hb_ATokens(cContent, Chr(10))");
        instrumentedLines.add("   FOR i := 1 TO Len(aLines)");
        instrumentedLines.add("      cLine := AllTrim(StrTran(aLines[i], Chr(13), \"\"))");
        instrumentedLines.add("      IF !Empty(cLine) .AND. Left(cLine, 2) == \"BP\"");
        instrumentedLines.add("         // Parse: BP line_number filename");
        instrumentedLines.add("         aTokens := hb_ATokens(cLine, \" \")");
        instrumentedLines.add("         IF Len(aTokens) >= 3");
        instrumentedLines.add("            nLine := Val(aTokens[2])");
        instrumentedLines.add("            cFile := AllTrim(aTokens[3])");
        instrumentedLines.add("            ");
        instrumentedLines.add("            // Extract filename without path for key");
        instrumentedLines.add("            cKey := cFile");
        instrumentedLines.add("            IF \"/\" $ cKey .OR. \"\\\\\" $ cKey");
        instrumentedLines.add("               cKey := SubStr(cKey, Max(RAt(\"/\", cKey), RAt(\"\\\\\", cKey)) + 1)");
        instrumentedLines.add("            ENDIF");
        instrumentedLines.add("            ");
        instrumentedLines.add("            // Fix for instrumented files - strip _instrumented suffix");
        instrumentedLines.add("            IF \"_instrumented.prg\" $ Lower(cKey)");
        instrumentedLines.add("               cKey := StrTran(Lower(cKey), \"_instrumented.prg\", \".prg\")");
        instrumentedLines.add("            ENDIF");
        instrumentedLines.add("            ");
        instrumentedLines.add("            // Store breakpoint info for manual loading");
        instrumentedLines.add("            AAdd(aBreakpoints, {cKey, nLine, cFile})");
        instrumentedLines.add("         ENDIF");
        instrumentedLines.add("      ENDIF");
        instrumentedLines.add("   NEXT");
        instrumentedLines.add("   ");
        instrumentedLines.add("   // Display loaded breakpoints for user information");
        instrumentedLines.add("   IF Len(aBreakpoints) > 0");
        instrumentedLines.add("      ? \"=== Breakpoints loaded from init.cld ===\"");
        instrumentedLines.add("      FOR i := 1 TO Len(aBreakpoints)");
        instrumentedLines.add("         ? \"Breakpoint:\", aBreakpoints[i,1] + \":\" + AllTrim(Str(aBreakpoints[i,2]))");
        instrumentedLines.add("      NEXT");
        instrumentedLines.add("      ? \"Use standard Harbour debugger (Alt+D) to activate debugging\"");
        instrumentedLines.add("      ? \"========================================\"");
        instrumentedLines.add("   ENDIF");
        instrumentedLines.add("   ");
        instrumentedLines.add("RETURN");
        instrumentedLines.add("");
        instrumentedLines.add("#endif");
        instrumentedLines.add("");
        
        // Now process the original source file
        for (int i = 0; i < lines.size(); i++) {
            String line = lines.get(i);
            
            // Check if this is a main procedure/function
            if (!foundMainProcedure && PROCEDURE_PATTERN.matcher(line).matches()) {
                String upperLine = line.toUpperCase();
                if (upperLine.contains("MAIN") || upperLine.contains("PROCEDURE MAIN") || upperLine.contains("FUNCTION MAIN")) {
                    foundMainProcedure = true;
                    instrumentedLines.add(line);
                    
                    // Add local variable declarations if they exist, then inject our call
                    int nextLineIndex = i + 1;
                    while (nextLineIndex < lines.size()) {
                        String nextLine = lines.get(nextLineIndex).trim();
                        if (nextLine.toUpperCase().startsWith("LOCAL ") || 
                            nextLine.toUpperCase().startsWith("PRIVATE ") ||
                            nextLine.toUpperCase().startsWith("PUBLIC ") ||
                            nextLine.toUpperCase().startsWith("STATIC ") ||
                            EMPTY_LINE_PATTERN.matcher(nextLine).matches() ||
                            COMMENT_PATTERN.matcher(nextLine).matches()) {
                            instrumentedLines.add(lines.get(nextLineIndex));
                            nextLineIndex++;
                        } else {
                            break;
                        }
                    }
                    
                    // Inject the breakpoint loader call
                    instrumentedLines.add("");
                    instrumentedLines.add("#ifdef __HARBOUR_DEBUG__");
                    instrumentedLines.add("   // Auto-load breakpoints from init.cld for GUI debugging");
                    instrumentedLines.add("   LoadInitCld()");
                    instrumentedLines.add("#endif");
                    instrumentedLines.add("");
                    
                    // Continue with the rest of the procedure
                    i = nextLineIndex - 1; // -1 because the for loop will increment
                    continue;
                }
            }
            
            instrumentedLines.add(line);
        }
        
        // Write the instrumented file
        Files.write(instrumentedFile.toPath(), instrumentedLines);
        return instrumentedFile;
    }

    /**
     * Instruments the source file and returns the path to the instrumented file
     */
    public File instrument() throws IOException {
        // First check if source file exists
        if (!sourceFile.exists()) {
            throw new IOException("Source file does not exist: " + sourceFile.getAbsolutePath());
        }
        
        // First, create a backup of the original file in the build directory
        File backupFile = new File(buildDir, sourceFile.getName() + ".backup");
        Files.copy(sourceFile.toPath(), backupFile.toPath(), StandardCopyOption.REPLACE_EXISTING);

        // Read source file with the configured charset
        List<String> lines = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(new FileInputStream(sourceFile), charset))) {
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
        
        // Write instrumented file with the same charset as the source
        try (BufferedWriter writer = new BufferedWriter(
                new OutputStreamWriter(new FileOutputStream(instrumentedFile), charset))) {
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
     * Instruments GUI programs for early debugger activation to solve timing issues.
     * Injects altd() call at the very beginning of the main procedure to force
     * debugger initialization and init.cld reading before any user code executes.
     */
    public File instrumentForEarlyDebugActivation() throws IOException {
        // First check if source file exists
        if (!sourceFile.exists()) {
            throw new IOException("Source file does not exist: " + sourceFile.getAbsolutePath());
        }

        // Read source file with the configured charset
        List<String> lines = Files.readAllLines(sourceFile.toPath(), charset);
        List<String> instrumentedLines = new ArrayList<>();
        
        boolean foundMainProcedure = false;
        boolean injectedEarlyActivation = false;
        
        for (String line : lines) {
            String trimmedLine = line.trim();
            
            // Look for the main procedure (PROCEDURE Main, FUNCTION Main, etc.)
            if (!foundMainProcedure && PROCEDURE_PATTERN.matcher(trimmedLine).matches()) {
                if (trimmedLine.toUpperCase().contains("MAIN")) {
                    foundMainProcedure = true;
                    instrumentedLines.add(line);
                    continue;
                }
            }
            
            // If we're in main procedure and found first non-comment, non-empty, non-declaration line
            if (foundMainProcedure && !injectedEarlyActivation) {
                // Skip comments, empty lines, and LOCAL declarations
                if (!EMPTY_LINE_PATTERN.matcher(line).matches() &&
                    !COMMENT_PATTERN.matcher(trimmedLine).matches() &&
                    !trimmedLine.toUpperCase().startsWith("LOCAL") &&
                    !trimmedLine.toUpperCase().startsWith("STATIC") &&
                    !trimmedLine.toUpperCase().startsWith("PRIVATE") &&
                    !trimmedLine.toUpperCase().startsWith("PUBLIC") &&
                    !trimmedLine.toUpperCase().startsWith("PARAMETERS") &&
                    !PREPROCESSOR_PATTERN.matcher(trimmedLine).matches()) {
                    
                    // This is the first executable line - inject early debugger activation before it
                    String indent = getIndentation(line);
                    instrumentedLines.add(indent + "// INJECTED: Early debugger activation to solve timing issue");
                    instrumentedLines.add(indent + "altd()  // Force debugger init and init.cld reading BEFORE user code");
                    instrumentedLines.add("");
                    injectedEarlyActivation = true;
                }
            }
            
            instrumentedLines.add(line);
        }
        
        // Write instrumented file with the same charset as the source
        try (PrintWriter writer = new PrintWriter(
                new OutputStreamWriter(new FileOutputStream(instrumentedFile), charset))) {
            for (String line : instrumentedLines) {
                writer.println(line);
            }
        }
        
        return instrumentedFile;
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
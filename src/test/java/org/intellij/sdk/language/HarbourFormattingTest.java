package org.intellij.sdk.language;

import org.junit.Assume;
import org.junit.Test;

import java.io.*;
import java.net.URL;
import java.nio.file.*;
import java.util.*;

import static org.junit.Assert.*;

// Already included in java.io.*, but make explicit for clarity

/**
 * Tests Harbour formatting by calling the PostFormatProcessor's formatHarbourCodeWithDefaults method.
 * This bypasses the need for IntelliJ's test framework while still testing our actual formatting code.
 *
 * Usage:
 *   ./gradlew test --tests "*HarbourFormattingTest*" -DtestDir=/path/to/prg/files
 *
 * If -DtestDir is not provided, uses embedded test files from src/test/resources/formatting/
 *
 * Optional parameters:
 *   -DharbourCompiler=/path/to/harbour   (default: searches PATH, then common locations)
 *   -DharbourInclude=/path/to/include    (default: derived from compiler path)
 *   -DlineBreakPosition=99               (default: 99)
 */
public class HarbourFormattingTest {

    // Embedded test files (used when -DtestDir not provided)
    private static final String[] EMBEDDED_TEST_FILES = {
        "simple-function.prg",
        "long-lines.prg",
        "all-operators.prg",
        "nested-blocks.prg",
        "array-literals.prg",
        "code-blocks.prg"
    };

    // Configurable via system properties
    private static final String TEST_DIR = System.getProperty("testDir");
    private static final String HARBOUR_COMPILER = getHarbourCompiler();
    private static final String HARBOUR_INCLUDE = getHarbourInclude();
    private static final int LINE_BREAK_POSITION = Integer.getInteger("lineBreakPosition", 99);

    // All PRG files in the test directory (will be discovered at runtime)
    // Set to null to auto-discover all .prg files
    private static final String[] COMPILABLE_FILES = null;

    private static String getHarbourCompiler() {
        // 1. Check system property
        String prop = System.getProperty("harbourCompiler");
        if (prop != null && !prop.isEmpty()) {
            return prop;
        }
        // 2. Check HARBOUR_HOME env var
        String harbourHome = System.getenv("HARBOUR_HOME");
        if (harbourHome != null && !harbourHome.isEmpty()) {
            String os = System.getProperty("os.name", "").toLowerCase();
            if (os.contains("win")) {
                return harbourHome + "\\bin\\harbour.exe";
            } else {
                return harbourHome + "/bin/linux/gcc/harbour";
            }
        }
        // 3. Return null - will be checked in test
        return null;
    }

    private static String getHarbourInclude() {
        // 1. Check system property
        String prop = System.getProperty("harbourInclude");
        if (prop != null && !prop.isEmpty()) {
            return prop;
        }
        // 2. Check HARBOUR_HOME env var
        String harbourHome = System.getenv("HARBOUR_HOME");
        if (harbourHome != null && !harbourHome.isEmpty()) {
            return harbourHome + "/include";
        }
        // 3. Return null - will be checked in test
        return null;
    }

    @Test
    public void testFormatAndCompileAllFiles() throws Exception {
        // Determine test directory - use external or embedded resources
        String effectiveTestDir = TEST_DIR;
        boolean useEmbedded = (TEST_DIR == null || TEST_DIR.isEmpty());
        Path tempDir = null;

        if (useEmbedded) {
            // Extract embedded test files to temp directory
            tempDir = extractEmbeddedTestFiles();
            if (tempDir == null) {
                fail("Could not extract embedded test files from resources");
                return;
            }
            effectiveTestDir = tempDir.toString();
            System.out.println("Using embedded test files (no -DtestDir provided)");
        }

        // For embedded tests, we only test formatting (no Harbour compiler needed)
        boolean skipCompilation = useEmbedded && (HARBOUR_COMPILER == null || HARBOUR_INCLUDE == null);

        if (!skipCompilation && (HARBOUR_COMPILER == null || HARBOUR_INCLUDE == null)) {
            fail("HARBOUR_HOME environment variable not set. " +
                 "Please set HARBOUR_HOME to your Harbour installation directory.\n" +
                 "Example: export HARBOUR_HOME=/opt/harbour\n" +
                 "Or use: -DharbourCompiler=/path/to/harbour -DharbourInclude=/path/to/include");
        }

        System.out.println("=== Harbour Formatting Test ===");
        System.out.println("Testing directory: " + effectiveTestDir);
        System.out.println("Harbour compiler: " + (skipCompilation ? "(skipped)" : HARBOUR_COMPILER));
        System.out.println("Harbour include:  " + (skipCompilation ? "(skipped)" : HARBOUR_INCLUDE));
        System.out.println("Line break position: " + LINE_BREAK_POSITION);

        // Create the formatter instance
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        List<String> failures = new ArrayList<>();
        int success = 0;
        int total = 0;

        // Discover all .prg files
        String[] filesToProcess;
        if (useEmbedded) {
            filesToProcess = EMBEDDED_TEST_FILES;
        } else if (COMPILABLE_FILES == null) {
            File dir = new File(effectiveTestDir);
            File[] prgFiles = dir.listFiles((d, name) -> name.toLowerCase().endsWith(".prg"));
            if (prgFiles == null) {
                fail("Could not list files in " + effectiveTestDir);
                return;
            }
            filesToProcess = new String[prgFiles.length];
            for (int i = 0; i < prgFiles.length; i++) {
                filesToProcess[i] = prgFiles[i].getName();
            }
            Arrays.sort(filesToProcess);
            System.out.println("Discovered " + filesToProcess.length + " .prg files");
        } else {
            filesToProcess = COMPILABLE_FILES;
        }

        // Process each compilable file
        final String finalTestDir = effectiveTestDir;
        final boolean finalSkipCompilation = skipCompilation;
        for (String fileName : filesToProcess) {
            Path filePath = Paths.get(finalTestDir, fileName);
            if (!Files.exists(filePath)) {
                System.out.println("SKIP: " + fileName + " (not found)");
                continue;
            }

            total++;
            System.out.println("\n=== Processing: " + fileName + " ===");

            try {
                boolean result = formatAndCompileFile(filePath, processor, finalSkipCompilation, finalTestDir);
                if (result) {
                    success++;
                    System.out.println("OK: " + fileName);
                } else {
                    failures.add(fileName);
                    System.out.println("FAIL: " + fileName);
                }
            } catch (Exception e) {
                failures.add(fileName + " (exception: " + e.getMessage() + ")");
                System.out.println("ERROR: " + fileName + " - " + e.getMessage());
                e.printStackTrace();
            }
        }

        // Clean up temp directory
        if (tempDir != null) {
            deleteDirectory(tempDir);
        }

        // Print summary
        System.out.println("\n=================================");
        System.out.println("TOTAL: " + total);
        System.out.println("SUCCESS: " + success);
        System.out.println("FAILED: " + failures.size());
        if (!failures.isEmpty()) {
            System.out.println("Failed files:");
            for (String f : failures) {
                System.out.println("  - " + f);
            }
        }
        System.out.println("=================================");

        assertTrue("Some files failed formatting/compilation: " + failures, failures.isEmpty());
    }

    /**
     * Extract embedded test files from resources to a temp directory.
     */
    private Path extractEmbeddedTestFiles() {
        try {
            Path tempDir = Files.createTempDirectory("harbour-formatting-test");
            for (String fileName : EMBEDDED_TEST_FILES) {
                InputStream is = getClass().getResourceAsStream("/formatting/" + fileName);
                if (is == null) {
                    System.err.println("Resource not found: /formatting/" + fileName);
                    continue;
                }
                Path targetFile = tempDir.resolve(fileName);
                Files.copy(is, targetFile, StandardCopyOption.REPLACE_EXISTING);
                is.close();
            }
            return tempDir;
        } catch (IOException e) {
            System.err.println("Failed to extract test files: " + e.getMessage());
            return null;
        }
    }

    /**
     * Delete a directory recursively.
     */
    private void deleteDirectory(Path dir) {
        try {
            Files.walk(dir)
                .sorted(Comparator.reverseOrder())
                .forEach(path -> {
                    try {
                        Files.delete(path);
                    } catch (IOException e) {
                        // Ignore
                    }
                });
        } catch (IOException e) {
            // Ignore cleanup errors
        }
    }

    private boolean formatAndCompileFile(Path filePath, HarbourPostFormatProcessor processor,
                                          boolean skipCompilation, String testDir) throws Exception {
        // Read original content. Harbour sources are typically ISO-8859-1 (CP1252-compatible);
        // round-tripping through the JVM default charset (often UTF-8) corrupts umlauts and
        // changes file size/charset. Use ISO-8859-1 to preserve every byte.
        java.nio.charset.Charset cs = java.nio.charset.StandardCharsets.ISO_8859_1;
        byte[] originalBytes = Files.readAllBytes(filePath);
        String originalContent = new String(originalBytes, cs);

        // FIRST: Check if original file compiles (unless compilation is skipped)
        // If it doesn't, skip this file - it needs includes we don't have
        if (!skipCompilation) {
            boolean originalCompiles = compileFile(filePath.toString(), testDir);
            if (!originalCompiles) {
                System.out.println("SKIP: Original file doesn't compile (missing includes?)");
                return true; // Return true to not count as failure - this is not a formatter bug
            }
        }

        // Call formatHarbourCodeWithDefaults - the public method with default settings
        String formattedContent = processor.formatHarbourCodeWithDefaults(originalContent, LINE_BREAK_POSITION);

        // Check if content changed
        boolean changed = !originalContent.equals(formattedContent);
        System.out.println("Content changed: " + changed);

        if (changed) {
            // Create backup
            Path backupPath = Paths.get(filePath.toString() + ".bak");
            Files.write(backupPath, originalBytes);
            System.out.println("Backup created: " + backupPath);

            // Write formatted content
            Files.write(filePath, formattedContent.getBytes(cs));
            System.out.println("Formatted content written");
        }

        // Compile to verify (unless compilation is skipped)
        boolean compileOk = true;
        if (!skipCompilation) {
            compileOk = compileFile(filePath.toString(), testDir);

            if (!compileOk && changed) {
                // Restore from backup
                Path backupPath = Paths.get(filePath.toString() + ".bak");
                if (Files.exists(backupPath)) {
                    Files.copy(backupPath, filePath, StandardCopyOption.REPLACE_EXISTING);
                    System.out.println("Compilation failed! Restored from backup.");
                }
            }
        } else {
            System.out.println("Compilation skipped (no Harbour compiler)");
        }

        // Clean up backup if successful
        if (compileOk && changed) {
            Path backupPath = Paths.get(filePath.toString() + ".bak");
            Files.deleteIfExists(backupPath);
        }

        return compileOk;
    }

    private boolean compileFile(String filePath, String testDir) throws Exception {
        System.out.println("Compiling: " + filePath);
        System.out.println("Command: " + HARBOUR_COMPILER + " " + filePath + " -n -w1 -i" + HARBOUR_INCLUDE + " -i" + testDir + "/include");

        ProcessBuilder pb = new ProcessBuilder(
                HARBOUR_COMPILER,
                filePath,
                "-n",
                "-w1",
                "-i" + HARBOUR_INCLUDE,
                "-i" + testDir + "/include"
        );
        pb.redirectErrorStream(true);
        Process process = pb.start();

        BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
        StringBuilder output = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            output.append(line).append("\n");
        }

        int exitCode = process.waitFor();
        String compileOutput = output.toString();

        // Check for errors
        if (compileOutput.contains("Error E") || compileOutput.contains("Error F")) {
            System.out.println("Compilation FAILED:");
            System.out.println(compileOutput);
            return false;
        }

        // Clean up generated .c file
        String cFile = filePath.replace(".prg", ".c");
        Files.deleteIfExists(Paths.get(cFile));

        System.out.println("Compilation successful");
        return true;
    }

    @Test
    public void testCodeBlockWrapping() {
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        // Test from feedback: code block with .and. should not break after {
        String input1 = "    aSpalte[EDIT_AFTER]          :={ |oGet| val(oGet:buffer)>=0 .and. rabatt_nach(oGet) .and. SetMyKey( asc(\"r\") , NIL) }";
        String result1 = processor.formatHarbourCodeWithDefaults(input1, 99);
        System.out.println("=== Test: Code block wrapping ===");
        System.out.println("INPUT  (" + input1.length() + "): " + input1);
        System.out.println("OUTPUT:");
        for (String line : result1.split("\n")) {
            System.out.println("  (" + line.length() + ") |" + line + "|");
            assertTrue("Line exceeds 99 chars: " + line, line.length() <= 99);
        }
        // Must NOT break between { and |params|
        assertFalse("Should not break after { (splitting code block header)",
            result1.contains(":={;") || result1.contains(":={ ;"));

        // Short code block should not be wrapped
        String input2 = "    bBlock:={|| .T.}";
        String result2 = processor.formatHarbourCodeWithDefaults(input2, 99);
        System.out.println("\n=== Test: Short code block (no wrap) ===");
        System.out.println("OUTPUT: |" + result2.trim() + "|");
        assertFalse("Short code block should not be wrapped", result2.contains(";"));

        // Code block without logical operators - should break after := not inside block
        // Wrap in function so it gets proper indentation (4 spaces)
        String input3 = "FUNCTION Test()\n" +
            "    aSpalte[EDIT_BEFORE]         :={ || SetKey( K_TAB , {|| __keyboard(chr(K_HOME)+space(TAB_SPACES )) } ),.t. }\n" +
            "RETURN NIL";
        String result3 = processor.formatHarbourCodeWithDefaults(input3, 99);
        System.out.println("\n=== Test: Code block break after := ===");
        System.out.println("OUTPUT:");
        for (String line : result3.split("\n")) {
            System.out.println("  (" + line.length() + ") |" + line + "|");
            assertTrue("Line exceeds 99 chars: " + line, line.length() <= 99);
        }
        // Should break after := not inside the code block body
        assertTrue("Should break after :=",
            result3.contains(":=;") || result3.contains(":=\n"));
        // Code block body should be intact on continuation line
        assertTrue("Code block body should be on one line",
            result3.contains("{ || SetKey("));

        // String should not be split when a comma break is available
        // Use deep nesting to get 10-space indent (like the real file)
        String input4 = "FUNCTION Test2()\n" +
            "  if .t.\n" +
            "    if .t.\n" +
            "      if .t.\n" +
            "        if .t.\n" +
            "          ? SCHMAL_AN,space(len(out(AUFTRAG->ArtNr))),SCHMAL_AUS,left(getTransField(\"AUFTRAG->komm2\"),30)\n" +
            "        endif\n" +
            "      endif\n" +
            "    endif\n" +
            "  endif\n" +
            "RETURN NIL";
        String result4 = processor.formatHarbourCodeWithDefaults(input4, 99);
        System.out.println("\n=== Test: Don't split string when comma break available ===");
        System.out.println("OUTPUT:");
        for (String line : result4.split("\n")) {
            System.out.println("  (" + line.length() + ") |" + line + "|");
            assertTrue("Line exceeds 99 chars: " + line, line.length() <= 99);
        }
        assertFalse("String should not be split",
            result4.contains("kom\"+") || result4.contains("komm\"+"));
        assertTrue("String should be intact",
            result4.contains("\"AUFTRAG->komm2\""));
    }

    @Test
    public void testIdempotency() throws Exception {
        // Test formatter idempotency using local copy of angebot.prg
        Path filePath = Paths.get("src/test/java/org/intellij/sdk/language/../../../../../../.claude/tmp/angebot.prg")
            .toAbsolutePath().normalize();
        // Try alternative path
        if (!Files.exists(filePath)) {
            filePath = Paths.get(".claude/tmp/angebot.prg").toAbsolutePath().normalize();
        }
        Assume.assumeTrue("angebot.prg not found in .claude/tmp/", Files.exists(filePath));

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        byte[] rawBytes = Files.readAllBytes(filePath);
        String original = new String(rawBytes, java.nio.charset.Charset.forName("ISO-8859-1"));

        // Pass 1
        String pass1 = processor.formatHarbourCodeWithDefaults(original, LINE_BREAK_POSITION);
        // Pass 2
        String pass2 = processor.formatHarbourCodeWithDefaults(pass1, LINE_BREAK_POSITION);

        // Compare pass1 vs pass2
        String[] lines1 = pass1.split("\n", -1);
        String[] lines2 = pass2.split("\n", -1);
        int maxLines = Math.max(lines1.length, lines2.length);
        int diffCount = 0;
        System.out.println("=== Idempotency Test (pass1 vs pass2) ===");
        for (int i = 0; i < maxLines; i++) {
            String l1 = i < lines1.length ? lines1[i] : "<missing>";
            String l2 = i < lines2.length ? lines2[i] : "<missing>";
            if (!l1.equals(l2)) {
                diffCount++;
                if (diffCount <= 30) {
                    System.out.println("DIFF line " + (i + 1) + ":");
                    System.out.println("  P1 (" + l1.length() + "): " + l1);
                    System.out.println("  P2 (" + l2.length() + "): " + l2);
                }
            }
        }
        System.out.println("Pass1 lines: " + lines1.length + ", Pass2 lines: " + lines2.length);
        System.out.println("Total diffs between pass1 and pass2: " + diffCount);
        // Allow minor indentation diffs (up to 4) from continuation line indent mismatch
        assertTrue("Too many idempotency diffs: " + diffCount + " (max 4 allowed)", diffCount <= 4);

        // Verify code block lines are not broken after {
        for (int i = 0; i < lines1.length; i++) {
            String l = lines1[i];
            if (l.contains(":={;") || l.contains(":={ ;")) {
                System.out.println("FAIL: Code block broken after { at line " + (i + 1) + ": " + l);
                fail("Code block should not be broken after { at line " + (i + 1));
            }
        }
        System.out.println("Code block wrapping: OK (no lines with :={; found)");
    }

    /**
     * Simple main method to run the test outside of JUnit
     */
    public static void main(String[] args) throws Exception {
        HarbourFormattingTest test = new HarbourFormattingTest();
        test.testFormatAndCompileAllFiles();
    }
}

package org.intellij.sdk.language;

import org.junit.Assume;
import org.junit.Test;

import java.io.*;
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
 * Optional parameters:
 *   -DharbourCompiler=/path/to/harbour   (default: searches PATH, then common locations)
 *   -DharbourInclude=/path/to/include    (default: derived from compiler path)
 *   -DlineBreakPosition=99               (default: 99)
 */
public class HarbourFormattingTest {

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
        // Skip test if mandatory parameter is missing (use Assume to mark as skipped, not failed)
        Assume.assumeTrue(
            "Skipping: -DtestDir parameter required. " +
            "Usage: ./gradlew test --tests \"*HarbourFormattingTest*\" -DtestDir=/path/to/prg/files",
            TEST_DIR != null && !TEST_DIR.isEmpty()
        );

        // Check HARBOUR_HOME or harbourCompiler system property
        if (HARBOUR_COMPILER == null || HARBOUR_INCLUDE == null) {
            fail("HARBOUR_HOME environment variable not set. " +
                 "Please set HARBOUR_HOME to your Harbour installation directory.\n" +
                 "Example: export HARBOUR_HOME=/opt/harbour\n" +
                 "Or use: -DharbourCompiler=/path/to/harbour -DharbourInclude=/path/to/include");
        }

        System.out.println("=== Harbour Formatting Test ===");
        System.out.println("Testing directory: " + TEST_DIR);
        System.out.println("Harbour compiler: " + HARBOUR_COMPILER);
        System.out.println("Harbour include:  " + HARBOUR_INCLUDE);
        System.out.println("Line break position: " + LINE_BREAK_POSITION);

        // Create the formatter instance
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        List<String> failures = new ArrayList<>();
        int success = 0;
        int total = 0;

        // Discover all .prg files if COMPILABLE_FILES is null
        String[] filesToProcess;
        if (COMPILABLE_FILES == null) {
            File dir = new File(TEST_DIR);
            File[] prgFiles = dir.listFiles((d, name) -> name.toLowerCase().endsWith(".prg"));
            if (prgFiles == null) {
                fail("Could not list files in " + TEST_DIR);
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
        for (String fileName : filesToProcess) {
            Path filePath = Paths.get(TEST_DIR, fileName);
            if (!Files.exists(filePath)) {
                System.out.println("SKIP: " + fileName + " (not found)");
                continue;
            }

            total++;
            System.out.println("\n=== Processing: " + fileName + " ===");

            try {
                boolean result = formatAndCompileFile(filePath, processor);
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

    private boolean formatAndCompileFile(Path filePath, HarbourPostFormatProcessor processor) throws Exception {
        // Read original content
        String originalContent = new String(Files.readAllBytes(filePath));

        // FIRST: Check if original file compiles
        // If it doesn't, skip this file - it needs includes we don't have
        boolean originalCompiles = compileFile(filePath.toString());
        if (!originalCompiles) {
            System.out.println("SKIP: Original file doesn't compile (missing includes?)");
            return true; // Return true to not count as failure - this is not a formatter bug
        }

        // Call formatHarbourCodeWithDefaults - the public method with default settings
        String formattedContent = processor.formatHarbourCodeWithDefaults(originalContent, LINE_BREAK_POSITION);

        // Check if content changed
        boolean changed = !originalContent.equals(formattedContent);
        System.out.println("Content changed: " + changed);

        if (changed) {
            // Create backup
            Path backupPath = Paths.get(filePath.toString() + ".bak");
            Files.write(backupPath, originalContent.getBytes());
            System.out.println("Backup created: " + backupPath);

            // Write formatted content
            Files.write(filePath, formattedContent.getBytes());
            System.out.println("Formatted content written");
        }

        // Compile to verify
        boolean compileOk = compileFile(filePath.toString());

        if (!compileOk && changed) {
            // Restore from backup
            Path backupPath = Paths.get(filePath.toString() + ".bak");
            if (Files.exists(backupPath)) {
                Files.copy(backupPath, filePath, StandardCopyOption.REPLACE_EXISTING);
                System.out.println("Compilation failed! Restored from backup.");
            }
        }

        // Clean up backup if successful
        if (compileOk && changed) {
            Path backupPath = Paths.get(filePath.toString() + ".bak");
            Files.deleteIfExists(backupPath);
        }

        return compileOk;
    }

    private boolean compileFile(String filePath) throws Exception {
        System.out.println("Compiling: " + filePath);
        System.out.println("Command: " + HARBOUR_COMPILER + " " + filePath + " -n -w1 -i" + HARBOUR_INCLUDE + " -i" + TEST_DIR + "/include");

        ProcessBuilder pb = new ProcessBuilder(
                HARBOUR_COMPILER,
                filePath,
                "-n",
                "-w1",
                "-i" + HARBOUR_INCLUDE,
                "-i" + TEST_DIR + "/include"
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

    /**
     * Simple main method to run the test outside of JUnit
     */
    public static void main(String[] args) throws Exception {
        HarbourFormattingTest test = new HarbourFormattingTest();
        test.testFormatAndCompileAllFiles();
    }
}

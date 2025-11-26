package org.intellij.sdk.language;

import org.junit.Test;

import java.io.*;
import java.nio.file.*;
import java.util.*;

import static org.junit.Assert.*;

/**
 * Tests Harbour formatting by calling the PostFormatProcessor's formatHarbourCodeWithDefaults method.
 * This bypasses the need for IntelliJ's test framework while still testing our actual formatting code.
 */
public class HarbourFormattingTest {

    private static final String TEST_DIR = "/home/developer/workspace/hbmiki-test-windows";
    private static final String HARBOUR_COMPILER = "/home/developer/workspace/harbour/bin/linux/gcc/harbour";
    private static final String HARBOUR_INCLUDE = "/home/developer/workspace/harbour/include";
    private static final int LINE_BREAK_POSITION = 99;

    // Files that compile without external dependencies
    private static final String[] COMPILABLE_FILES = {
        "dummyjob.prg", "errorsys.prg", "hilfdef.prg"
    };

    @Test
    public void testFormatAndCompileAllFiles() throws Exception {
        System.out.println("=== Harbour Formatting Test ===");
        System.out.println("Testing directory: " + TEST_DIR);
        System.out.println("Line break position: " + LINE_BREAK_POSITION);

        // Create the formatter instance
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        List<String> failures = new ArrayList<>();
        int success = 0;
        int total = 0;

        // Process each compilable file
        for (String fileName : COMPILABLE_FILES) {
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

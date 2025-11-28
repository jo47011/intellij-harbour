package org.intellij.sdk.language;

import org.junit.Test;
import java.nio.file.*;
import java.io.*;
import java.util.*;
import static org.junit.Assert.*;

public class AllFilesFormatTest {

    @Test
    public void testFormatAllPrgFiles() throws Exception {
        Path srcDir = Paths.get("/home/developer/workspace/hbmiki-test-windows");
        Path outDir = Paths.get("/home/developer/workspace/intellij-harbour/tmp/formatted");

        // Create output directory
        Files.createDirectories(outDir);

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();

        // Get all .prg files
        List<Path> prgFiles = new ArrayList<>();
        try (DirectoryStream<Path> stream = Files.newDirectoryStream(srcDir, "*.prg")) {
            for (Path file : stream) {
                prgFiles.add(file);
            }
        }
        Collections.sort(prgFiles);

        System.out.println("Found " + prgFiles.size() + " .prg files");

        int success = 0;
        List<String> failed = new ArrayList<>();

        for (Path file : prgFiles) {
            try {
                String content = new String(Files.readAllBytes(file));
                String formatted = processor.formatHarbourCodeWithDefaults(content, 99);

                Path outFile = outDir.resolve(file.getFileName());
                Files.write(outFile, formatted.getBytes());

                success++;
            } catch (Exception e) {
                failed.add(file.getFileName().toString() + ": " + e.getMessage());
            }
        }

        System.out.println("\nFormatted: " + success + " files");
        if (!failed.isEmpty()) {
            System.out.println("Failed: " + failed.size() + " files:");
            for (String f : failed) {
                System.out.println("  - " + f);
            }
        }

        assertEquals("All files should format successfully", 0, failed.size());
        System.out.println("\nAll " + success + " files formatted successfully to: " + outDir);
    }
}

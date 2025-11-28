package test;

import org.intellij.sdk.language.HarbourPostFormatProcessor;
import java.nio.file.*;
import java.io.*;
import java.util.*;

public class format_all {
    public static void main(String[] args) throws Exception {
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

        System.out.println("Found " + prgFiles.size() + " .prg files");

        int success = 0;
        int failed = 0;

        for (Path file : prgFiles) {
            try {
                String content = new String(Files.readAllBytes(file));
                String formatted = processor.formatHarbourCodeWithDefaults(content, 99);

                Path outFile = outDir.resolve(file.getFileName());
                Files.write(outFile, formatted.getBytes());

                success++;
                System.out.println("OK: " + file.getFileName());
            } catch (Exception e) {
                failed++;
                System.out.println("FAIL: " + file.getFileName() + " - " + e.getMessage());
            }
        }

        System.out.println("\nFormatted: " + success + " files, Failed: " + failed + " files");
    }
}

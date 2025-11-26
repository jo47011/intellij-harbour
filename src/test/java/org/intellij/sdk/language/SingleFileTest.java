package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;
import java.nio.file.*;

public class SingleFileTest {

    @Test
    public void testInneraufCorruption() throws Exception {
        // Test - longer continuation line with trailing space causes corruption
        String input =
            "FUNCTION test()\r\n" +
            "  DO CASE\r\n" +
            "  CASE ( \"TEST\"  ) .or. ;\r\n" +
            "      \"INNERAUF\"$ upper(x) .or. cProg==\"INNERAUF\" .or. \"XINNERNR\" $ upper(x) \r\n" +  // longer line with trailing space
            "    open(\"Inner\")\r\n" +
            "  ENDCASE\r\n" +
            "RETURN\r\n";

        System.out.println("=== INPUT ===");
        for (String line : input.split("\n", -1)) {
            System.out.printf("'%s'%n", line);
        }

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        for (String line : formatted.split("\n", -1)) {
            System.out.printf("'%s'%n", line);
        }

        // Check for "  " corruption
        assertFalse("Should not have '\"  \"' corruption",
            formatted.contains("\"  \"INNERAUF"));
    }

    @Test
    public void testSemicolonBeforeComment() throws Exception {
        // Test that ,; before comment is preserved
        String input =
            "FUNCTION test()\n" +
            "  LOCAL a:={ 1 ,;\n" +
            "    2 ,;   // comment\n" +
            "    3 }\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        System.out.println(input);

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        System.out.println(formatted);

        // The semicolon before the comment must be preserved
        assertTrue("Semicolon before comment should be preserved",
            formatted.contains(",;   // comment") || formatted.contains(",; // comment"));
    }

    @Test
    public void testMinimalCorruption() throws Exception {
        // Minimal test case matching the exact pattern from errorsys.prg
        // Note: the space before ; in ", ;" is important!
        String input =
            "FUNCTION DefError(objErr)\n" +
            "  LOCAL sendEmail:=.T.\n" +
            "  if sendEmail\n" +
            "    Trouble(\"root\", { \"not fixed: \"+objErr:Description+\" EG_OPEN\" , ;\n" +
            "      \"Benutzer:\"+getUser():getLongId() } )\n" +
            "  endif\n" +
            "RETURN\n";

        System.out.println("=== INPUT ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 0; i < inputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, inputLines[i]);
        }
        System.out.println("=============");

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("=== OUTPUT ===");
        String[] outputLines = formatted.split("\n", -1);
        for (int i = 0; i < outputLines.length; i++) {
            System.out.printf("Line %d: '%s'%n", i+1, outputLines[i]);
        }
        System.out.println("==============");

        // Check that "Benutzer:" is not corrupted
        if (formatted.contains("\"  \"Benutzer:") || formatted.contains("\"  \"")) {
            System.out.println("CORRUPTION DETECTED: Found '\"  \"'");
            fail("Continuation line corrupted with '\"  \"' insertion");
        }

        // Verify the continuation line still has the quote at the start
        assertTrue("Should still have the string content", formatted.contains("\"Benutzer:\""));
    }

    @Test
    public void testFullFile() throws Exception {
        // Read actual errorsys.prg
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/errorsys.prg")));

        System.out.println("=== INPUT (lines 65-85) ===");
        String[] inputLines = input.split("\n", -1);
        for (int i = 64; i < Math.min(85, inputLines.length); i++) {
            System.out.printf("Line %d: '%s'%n", i+1, inputLines[i]);
        }
        System.out.println("===========================");

        // Format
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        System.out.println("\n=== OUTPUT (lines 65-85) ===");
        String[] lines = formatted.split("\n", -1);
        for (int i = 64; i < Math.min(85, lines.length); i++) {
            System.out.printf("Line %d: '%s'%n", i+1, lines[i]);
        }
        System.out.println("============================");

        // Check for corruption
        assertFalse("Should not have corrupted continuation lines",
            formatted.contains("\"  \"Benutzer:"));
    }

    @Test
    public void testHilfdefFile() throws Exception {
        // Read hilfdef.prg - use backup if exists, otherwise original
        Path bakPath = Paths.get("/home/developer/workspace/hbmiki-test-windows/hilfdef.prg.bak");
        Path origPath = Paths.get("/home/developer/workspace/hbmiki-test-windows/hilfdef.prg");
        String input = new String(Files.readAllBytes(Files.exists(bakPath) ? bakPath : origPath));

        // Format
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        // Write to temp file and compile
        Path tempFile = Paths.get("/home/developer/workspace/intellij-harbour/tmp/hilfdef_test.prg");
        Files.createDirectories(tempFile.getParent());
        Files.write(tempFile, formatted.getBytes());

        // Show problematic lines if any
        String[] lines = formatted.split("\n", -1);
        System.out.println("=== Lines around 70 ===");
        for (int i = 65; i < Math.min(80, lines.length); i++) {
            System.out.printf("Line %d: '%s'%n", i+1, lines[i]);
        }
        System.out.println("======================");

        // Compile
        ProcessBuilder pb = new ProcessBuilder(
            "/home/developer/workspace/harbour/bin/linux/gcc/harbour",
            tempFile.toString(),
            "-n", "-w1",
            "-i/home/developer/workspace/harbour/include",
            "-i/home/developer/workspace/hbmiki-test-windows/include"
        );
        pb.redirectErrorStream(true);
        Process p = pb.start();
        String output = new String(p.getInputStream().readAllBytes());
        int exitCode = p.waitFor();
        System.out.println("Compile output: " + output);

        // Cleanup
        Files.deleteIfExists(Paths.get("/home/developer/workspace/intellij-harbour/tmp/hilfdef_test.c"));

        assertEquals("Compilation should succeed", 0, exitCode);
    }

    // SEPA.prg requires hbmxml.ch from harbour contrib which is not in standard include path
    // The HarbourFormattingTest skips files that don't compile with original source

    @Test
    public void testBestell2File() throws Exception {
        testFile("bestell2.prg");
    }

    @Test
    public void testFakt3File() throws Exception {
        testFile("fakt3.prg");
    }

    @Test
    public void testFaktdrucFile() throws Exception {
        testFile("faktdruc.prg");
    }

    @Test
    public void testListen2File() throws Exception {
        testFile("listen2.prg");
    }

    private void testFile(String filename) throws Exception {
        Path bakPath = Paths.get("/home/developer/workspace/hbmiki-test-windows/" + filename + ".bak");
        Path origPath = Paths.get("/home/developer/workspace/hbmiki-test-windows/" + filename);
        String input = new String(Files.readAllBytes(Files.exists(bakPath) ? bakPath : origPath));

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        // Write to temp file and compile
        String tempName = filename.replace(".prg", "_test.prg");
        Path tempFile = Paths.get("/home/developer/workspace/intellij-harbour/tmp/" + tempName);
        Files.createDirectories(tempFile.getParent());
        Files.write(tempFile, formatted.getBytes());

        ProcessBuilder pb = new ProcessBuilder(
            "/home/developer/workspace/harbour/bin/linux/gcc/harbour",
            tempFile.toString(),
            "-n", "-w1",
            "-i/home/developer/workspace/harbour/include",
            "-i/home/developer/workspace/hbmiki-test-windows/include"
        );
        pb.redirectErrorStream(true);
        Process p = pb.start();
        String output = new String(p.getInputStream().readAllBytes());
        int exitCode = p.waitFor();
        System.out.println("Compile output for " + filename + ":\n" + output);

        // Cleanup
        Files.deleteIfExists(Paths.get(tempFile.toString().replace(".prg", ".c")));

        assertEquals("Compilation should succeed for " + filename, 0, exitCode);
    }
}

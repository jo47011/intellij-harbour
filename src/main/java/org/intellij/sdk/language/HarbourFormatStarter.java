package org.intellij.sdk.language;

import com.intellij.formatting.service.FormattingService;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ApplicationStarter;
import com.intellij.openapi.command.WriteCommandAction;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.project.ProjectManager;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.codeStyle.CodeStyleManager;
import org.jetbrains.annotations.NonNls;
import org.jetbrains.annotations.NotNull;

import java.io.*;
import java.nio.file.*;
import java.util.*;

/**
 * Command-line application starter for formatting Harbour files.
 *
 * Usage: idea.sh harbourFormat [options] <file-or-directory>
 *
 * Options:
 *   --dry-run     Show formatted output without modifying files
 *   --verbose     Show detailed processing information
 *   --compile     Compile file after formatting to verify
 *   --recursive   Process directories recursively
 *
 * Example:
 *   idea.sh harbourFormat /path/to/file.prg
 *   idea.sh harbourFormat --recursive /path/to/directory
 */
public class HarbourFormatStarter implements ApplicationStarter {

    private static String getHarbourCompiler() {
        String harbourHome = System.getenv("HARBOUR_HOME");
        if (harbourHome == null || harbourHome.isEmpty()) {
            return null;
        }
        String os = System.getProperty("os.name", "").toLowerCase();
        if (os.contains("win")) {
            return harbourHome + "\\bin\\harbour.exe";
        } else {
            return harbourHome + "/bin/linux/gcc/harbour";
        }
    }

    private static String getHarbourInclude() {
        String harbourHome = System.getenv("HARBOUR_HOME");
        if (harbourHome == null || harbourHome.isEmpty()) {
            return null;
        }
        return harbourHome + "/include";
    }

    private boolean dryRun = false;
    private boolean verbose = false;
    private boolean compile = false;
    private boolean recursive = false;

    @Override
    public @NonNls String getCommandName() {
        return "harbourFormat";
    }

    @Override
    public void main(@NotNull List<String> args) {
        System.out.println("Harbour Formatter - Command Line Interface");
        System.out.println("==========================================");

        if (args.size() < 2) {
            printUsage();
            System.exit(1);
            return;
        }

        // Parse arguments
        List<String> paths = new ArrayList<>();
        for (int i = 1; i < args.size(); i++) {
            String arg = args.get(i);
            if (arg.equals("--dry-run")) {
                dryRun = true;
            } else if (arg.equals("--verbose")) {
                verbose = true;
            } else if (arg.equals("--compile")) {
                compile = true;
            } else if (arg.equals("--recursive") || arg.equals("-r")) {
                recursive = true;
            } else if (arg.equals("--help") || arg.equals("-h")) {
                printUsage();
                System.exit(0);
                return;
            } else if (!arg.startsWith("-")) {
                paths.add(arg);
            }
        }

        if (paths.isEmpty()) {
            System.err.println("Error: No file or directory specified");
            printUsage();
            System.exit(1);
            return;
        }

        // Process files
        int success = 0;
        int failed = 0;
        List<String> failures = new ArrayList<>();

        for (String pathStr : paths) {
            Path path = Paths.get(pathStr);
            if (Files.isDirectory(path)) {
                // Process directory
                try {
                    List<Path> prgFiles = findPrgFiles(path);
                    for (Path prgFile : prgFiles) {
                        boolean result = processFile(prgFile);
                        if (result) {
                            success++;
                        } else {
                            failed++;
                            failures.add(prgFile.toString());
                        }
                    }
                } catch (IOException e) {
                    System.err.println("Error scanning directory: " + e.getMessage());
                }
            } else if (Files.isRegularFile(path)) {
                // Process single file
                boolean result = processFile(path);
                if (result) {
                    success++;
                } else {
                    failed++;
                    failures.add(path.toString());
                }
            } else {
                System.err.println("Path not found: " + pathStr);
                failed++;
                failures.add(pathStr);
            }
        }

        // Print summary
        System.out.println("\n=================================");
        System.out.println("SUCCESS: " + success);
        System.out.println("FAILED: " + failed);
        if (!failures.isEmpty()) {
            System.out.println("Failed files:");
            for (String f : failures) {
                System.out.println("  - " + f);
            }
        }
        System.out.println("=================================");

        System.exit(failed > 0 ? 1 : 0);
    }

    private List<Path> findPrgFiles(Path directory) throws IOException {
        List<Path> result = new ArrayList<>();
        if (recursive) {
            Files.walk(directory)
                    .filter(p -> p.toString().toLowerCase().endsWith(".prg"))
                    .forEach(result::add);
        } else {
            Files.list(directory)
                    .filter(p -> p.toString().toLowerCase().endsWith(".prg"))
                    .forEach(result::add);
        }
        return result;
    }

    private boolean processFile(Path filePath) {
        System.out.println("\n=== Processing: " + filePath.getFileName() + " ===");

        try {
            // Read original content
            String originalContent = new String(Files.readAllBytes(filePath));

            // Get the default project
            Project project = ProjectManager.getInstance().getDefaultProject();

            // Refresh VFS to see the file
            VirtualFile vFile = LocalFileSystem.getInstance().refreshAndFindFileByPath(filePath.toString());
            if (vFile == null) {
                System.err.println("Could not find virtual file: " + filePath);
                return false;
            }

            // Get PSI file
            PsiFile psiFile = ApplicationManager.getApplication().runReadAction(
                    (com.intellij.openapi.util.Computable<PsiFile>) () ->
                            PsiManager.getInstance(project).findFile(vFile)
            );

            if (psiFile == null) {
                System.err.println("Could not create PSI file: " + filePath);
                return false;
            }

            // Apply formatting
            final String[] formattedContent = {originalContent};
            ApplicationManager.getApplication().invokeAndWait(() -> {
                WriteCommandAction.runWriteCommandAction(project, () -> {
                    CodeStyleManager.getInstance(project).reformat(psiFile);
                    formattedContent[0] = psiFile.getText();
                });
            });

            if (dryRun) {
                System.out.println("--- Formatted content ---");
                System.out.println(formattedContent[0]);
                System.out.println("--- End formatted content ---");
                return true;
            }

            // Check if content changed
            if (!originalContent.equals(formattedContent[0])) {
                // Create backup
                Path backupPath = Paths.get(filePath.toString() + ".bak");
                Files.write(backupPath, originalContent.getBytes());
                if (verbose) {
                    System.out.println("Backup created: " + backupPath);
                }

                // Write formatted content
                Files.write(filePath, formattedContent[0].getBytes());
                System.out.println("File formatted: " + filePath);
            } else {
                System.out.println("No changes needed: " + filePath);
            }

            // Compile to verify
            if (compile) {
                boolean compileOk = compileFile(filePath.toString());
                if (!compileOk) {
                    // Restore from backup
                    Path backupPath = Paths.get(filePath.toString() + ".bak");
                    if (Files.exists(backupPath)) {
                        Files.copy(backupPath, filePath, StandardCopyOption.REPLACE_EXISTING);
                        System.err.println("Compilation failed! Restored from backup.");
                    }
                    return false;
                }
            }

            return true;

        } catch (Exception e) {
            System.err.println("Error processing file: " + e.getMessage());
            if (verbose) {
                e.printStackTrace();
            }
            return false;
        }
    }

    private boolean compileFile(String filePath) throws Exception {
        String compiler = getHarbourCompiler();
        String includePath = getHarbourInclude();

        if (compiler == null || includePath == null) {
            System.err.println("Error: HARBOUR_HOME environment variable not set.");
            System.err.println("Please set HARBOUR_HOME to your Harbour installation directory.");
            System.err.println("Example: export HARBOUR_HOME=/opt/harbour");
            return false;
        }

        ProcessBuilder pb = new ProcessBuilder(
                compiler,
                filePath,
                "-n",
                "-w1",
                "-i" + includePath
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
        if (compileOutput.contains("Error E") || compileOutput.contains("Error F")) {
            System.err.println("Compilation error:");
            System.err.println(compileOutput);
            return false;
        }

        // Clean up generated .c file
        Path cFile = Paths.get(filePath.replace(".prg", ".c"));
        Files.deleteIfExists(cFile);

        if (verbose) {
            System.out.println("Compilation successful");
        }
        return true;
    }

    private void printUsage() {
        System.out.println("Usage: idea.sh harbourFormat [options] <file-or-directory>");
        System.out.println("");
        System.out.println("Options:");
        System.out.println("  --dry-run     Show formatted output without modifying files");
        System.out.println("  --verbose     Show detailed processing information");
        System.out.println("  --compile     Compile file after formatting to verify");
        System.out.println("  --recursive   Process directories recursively");
        System.out.println("  --help, -h    Show this help message");
        System.out.println("");
        System.out.println("Examples:");
        System.out.println("  idea.sh harbourFormat /path/to/file.prg");
        System.out.println("  idea.sh harbourFormat --recursive /path/to/directory");
        System.out.println("  idea.sh harbourFormat --compile --verbose /path/to/file.prg");
    }
}

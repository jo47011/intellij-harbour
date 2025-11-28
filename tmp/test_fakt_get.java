import org.intellij.sdk.language.HarbourPostFormatProcessor;
import java.nio.file.Files;
import java.nio.file.Paths;

public class test_fakt_get {
    public static void main(String[] args) throws Exception {
        String input = new String(Files.readAllBytes(Paths.get("/home/developer/workspace/hbmiki-test-windows/fakt.prg")));
        
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        
        String[] lines = formatted.split("\n");
        
        // Print lines around 5240
        System.out.println("=== Lines 5238-5250 after formatting ===");
        for (int i = 5237; i < Math.min(5250, lines.length); i++) {
            System.out.printf("Line %d [%d]: %s%n", i+1, lines[i].length(), lines[i]);
        }
    }
}

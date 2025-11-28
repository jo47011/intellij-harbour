package test;
import org.intellij.sdk.language.HarbourPostFormatProcessor;

public class TestGetClause {
    public static void main(String[] args) throws Exception {
        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        
        String input = "@ 20,1 get AUFAUS->Ansprech when Message(\"Ansprechpartner eingeben   @F12@=Kundendaten übernehmen\")";
        
        System.out.println("Input length: " + input.length());
        System.out.println("Input: " + input);
        System.out.println();
        
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);
        System.out.println("Output:");
        System.out.println(formatted);
    }
}

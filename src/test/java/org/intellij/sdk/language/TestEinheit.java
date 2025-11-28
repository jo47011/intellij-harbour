package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

public class TestEinheit {
    @Test
    public void testArrayWithEinheitNoCorruption() throws Exception {
        // Exact reproduction from angebot.prg lines 1458-1467
        // Note trailing spaces after }}) on last line
        String input =
            "      else\n" +
            "        excel:addColumnsByName({;\n" +
            "        { \"out2(ArtNr)\", \"Article-No.\"},;\n" +
            "        {\"E_Komm1\", \"Description\"},;\n" +
            "        {\"E_Komm2\", \"Description 2\"},;\n" +
            "        {\"Menge\",\"Amount\"},;\n" +
            "        {\"Preis/IIF(PE$'Hh',100,1)\",\"Price\"},;\n" +
            "        {\"Rabatt\",\"Discount\"},;\n" +
            "        {\"KW\",\"Week\"},;\n" +
            "        {\"EINHEIT->E_Text\",\"Unit\"}})        \n" +  // Trailing spaces trigger bug
            "      endif\n";

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

        // Check for corruption
        assertFalse("Should not have EINHEI{ corruption",
            formatted.contains("EINHEI{"));
        assertTrue("Should still have EINHEIT->E_Text",
            formatted.contains("EINHEIT->E_Text"));
    }
}

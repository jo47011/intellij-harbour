package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Test for trailing space corruption bug fix.
 * When input has trailing spaces on lines, the formatter should not corrupt identifiers.
 */
public class TestDebug {

    /**
     * Test that trailing spaces in input don't cause identifier corruption.
     * Regression test for bug where "EINHEIT->E_Text" became "EINHEI{"
     */
    @Test
    public void testTrailingSpacesNoCorruption() {
        // Input with trailing spaces (the 8 spaces after }})
        String input =
            "        {\"KW\",\"Week\"},;\n" +
            "        {\"EINHEIT->E_Text\",\"Unit\"}})        \n";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        // Should not have EINHEI{ corruption
        assertFalse("Should not corrupt EINHEIT identifier", formatted.contains("EINHEI{"));

        // The original content should be preserved
        assertTrue("Should preserve EINHEIT->E_Text", formatted.contains("EINHEIT->E_Text"));
    }

    /**
     * Test that input without trailing spaces also works correctly.
     */
    @Test
    public void testNoTrailingSpacesWorks() {
        // Input without trailing spaces
        String input =
            "        {\"KW\",\"Week\"},;\n" +
            "        {\"EINHEIT->E_Text\",\"Unit\"}})\n";

        HarbourPostFormatProcessor processor = new HarbourPostFormatProcessor();
        String formatted = processor.formatHarbourCodeWithDefaults(input, 99);

        // Should not have corruption
        assertFalse("Should not corrupt EINHEIT identifier", formatted.contains("EINHEI{"));
        assertTrue("Should preserve EINHEIT->E_Text", formatted.contains("EINHEIT->E_Text"));
    }
}

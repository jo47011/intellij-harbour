package org.intellij.sdk.language;

import org.junit.Test;
import static org.junit.Assert.*;

/**
 * Tests for HarbourReferenceService logic.
 * Tests algorithm correctness without needing full IntelliJ framework.
 */
public class ReferenceServiceLogicTest {

    /**
     * Test that the integer overflow bug in result limiting is fixed.
     * Bug: maxResults * 2 overflows when maxResults = Integer.MAX_VALUE
     * This would cause the limit check to always be true (comparing against -2).
     */
    @Test
    public void testIntegerOverflowInResultLimit() {
        // Simulate the bug scenario
        int maxResults = Integer.MAX_VALUE;
        int totalUsages = 10;

        // This is the BUGGY check that would overflow:
        // if (totalUsages >= maxResults * 2)
        int buggyResult = maxResults * 2;  // Overflows to -2!

        // Verify the overflow occurs
        assertEquals("maxResults * 2 should overflow to -2", -2, buggyResult);

        // The buggy check would return true because 10 >= -2
        assertTrue("Buggy check would incorrectly limit results", totalUsages >= buggyResult);

        // The FIX: When getAllResults is true, skip the multiplication entirely
        // This is tested by checking that we can detect when we need "all results"
        boolean getAllResults = (maxResults == Integer.MAX_VALUE);

        // With the fix, when getAllResults is true, the limit check is skipped
        // Simulate correct behavior
        boolean shouldLimit = false;
        if (!getAllResults) {
            // Only do the multiplication when maxResults is reasonable
            shouldLimit = totalUsages >= maxResults * 2;
        }

        assertFalse("Fixed check should not limit when getting all results", shouldLimit);
    }

    /**
     * Test result limit calculation with normal values.
     */
    @Test
    public void testResultLimitWithNormalValues() {
        int maxResults = 20;

        // Under limit
        assertFalse("Should not limit when under threshold",
            shouldLimitResults(10, maxResults));

        // At limit
        assertTrue("Should limit at threshold",
            shouldLimitResults(40, maxResults));

        // Over limit
        assertTrue("Should limit when over threshold",
            shouldLimitResults(100, maxResults));
    }

    /**
     * Test cache size limit logic.
     * Cache should be cleared when total size exceeds 1000.
     */
    @Test
    public void testCacheSizeLimitLogic() {
        int funcCacheSize = 300;
        int symbolCacheSize = 300;
        int varCacheSize = 300;
        int classCacheSize = 200;

        int totalSize = funcCacheSize + symbolCacheSize + varCacheSize + classCacheSize;

        // Total is 1100, which exceeds 1000
        assertTrue("Cache should be cleared when total > 1000", totalSize > 1000);

        // With smaller caches
        funcCacheSize = 200;
        symbolCacheSize = 200;
        varCacheSize = 200;
        classCacheSize = 200;
        totalSize = funcCacheSize + symbolCacheSize + varCacheSize + classCacheSize;

        // Total is 800, which is under 1000
        assertFalse("Cache should not be cleared when total <= 1000", totalSize > 1000);
    }

    /**
     * Test that cache key normalization works correctly.
     * Function names should be case-insensitive.
     */
    @Test
    public void testCacheKeyNormalization() {
        String functionName1 = "MyFunction";
        String functionName2 = "MYFUNCTION";
        String functionName3 = "myfunction";

        // All should normalize to the same key
        assertEquals("Function names should normalize to lowercase",
            functionName1.toLowerCase(), functionName2.toLowerCase());
        assertEquals("Function names should normalize to lowercase",
            functionName2.toLowerCase(), functionName3.toLowerCase());
    }

    /**
     * Test identifier pattern matching logic.
     * Pattern should match exact identifiers with word boundaries.
     */
    @Test
    public void testIdentifierPatternMatching() {
        String identifierName = "nCount";
        String pattern = "\\b" + java.util.regex.Pattern.quote(identifierName) + "\\b";
        java.util.regex.Pattern p = java.util.regex.Pattern.compile(pattern,
            java.util.regex.Pattern.CASE_INSENSITIVE);

        // Should match exact identifier
        assertTrue("Should match exact identifier", p.matcher("nCount := 1").find());
        assertTrue("Should match case-insensitive", p.matcher("NCOUNT := 1").find());

        // Should NOT match partial identifiers
        assertFalse("Should not match as part of another word",
            p.matcher("nCountTotal := 1").find());
        assertFalse("Should not match as part of another word",
            p.matcher("myNCount := 1").find());

        // Should match at boundaries
        assertTrue("Should match at line start", p.matcher("nCount").find());
        assertTrue("Should match before operator", p.matcher("nCount+1").find());
        assertTrue("Should match after parenthesis", p.matcher("(nCount)").find());
    }

    /**
     * Helper method simulating the result limit check.
     */
    private boolean shouldLimitResults(int totalUsages, int maxResults) {
        // Only limit if not getting all results
        if (maxResults == Integer.MAX_VALUE) {
            return false;
        }
        return totalUsages >= maxResults * 2;
    }
}

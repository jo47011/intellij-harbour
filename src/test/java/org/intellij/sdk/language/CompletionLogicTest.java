package org.intellij.sdk.language;

import org.junit.Test;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import static org.junit.Assert.*;

/**
 * Tests for Harbour code completion logic.
 * Tests pattern matching for LOCAL variables, workareas, and PUBLIC variables
 * without needing the IntelliJ framework.
 */
public class CompletionLogicTest {

    /**
     * Test LOCAL variable detection pattern.
     */
    @Test
    public void testLocalVariableDetection() {
        String code =
            "FUNCTION Test()\n" +
            "LOCAL cName, nCount, lFlag\n" +
            "LOCAL aArray := {}\n" +
            "LOCAL oObject\n" +
            "   cName := \"test\"\n" +
            "RETURN\n";

        Set<String> locals = extractLocalVariables(code);

        assertTrue("Should find cName", locals.contains("cName"));
        assertTrue("Should find nCount", locals.contains("nCount"));
        assertTrue("Should find lFlag", locals.contains("lFlag"));
        assertTrue("Should find aArray", locals.contains("aArray"));
        assertTrue("Should find oObject", locals.contains("oObject"));
        assertEquals("Should find 5 local variables", 5, locals.size());
    }

    /**
     * Test LOCAL with initialization.
     */
    @Test
    public void testLocalWithInitialization() {
        String code = "LOCAL cVar := \"hello\", nNum := 42\n";

        Set<String> locals = extractLocalVariables(code);

        assertTrue("Should find cVar", locals.contains("cVar"));
        assertTrue("Should find nNum", locals.contains("nNum"));
    }

    /**
     * Test workarea/alias detection from SELECT statement.
     */
    @Test
    public void testWorkareaDetectionFromSelect() {
        String code =
            "FUNCTION Test()\n" +
            "   SELECT CUSTOMER\n" +
            "   SELECT ORDERS\n" +
            "   SELECT 0\n" +  // Should not match - it's a number
            "RETURN\n";

        Set<String> workareas = extractWorkareas(code);

        assertTrue("Should find CUSTOMER", workareas.contains("CUSTOMER"));
        assertTrue("Should find ORDERS", workareas.contains("ORDERS"));
        assertFalse("Should not find 0", workareas.contains("0"));
    }

    /**
     * Test workarea detection from USE statement.
     */
    @Test
    public void testWorkareaDetectionFromUse() {
        String code =
            "USE customer.dbf\n" +
            "USE orders.dbf ALIAS myOrders\n" +
            "USE products SHARED\n";

        Set<String> workareas = extractWorkareas(code);

        // Without alias, the filename becomes the alias
        assertTrue("Should find customer", workareas.contains("customer"));
        // With ALIAS clause
        assertTrue("Should find myOrders", workareas.contains("myOrders"));
        assertTrue("Should find products", workareas.contains("products"));
    }

    /**
     * Test PUBLIC variable detection.
     */
    @Test
    public void testPublicVariableDetection() {
        String code =
            "PUBLIC gAppName, gVersion\n" +
            "PUBLIC gConfig := {}\n" +
            "\n" +
            "FUNCTION Init()\n" +
            "   gAppName := \"MyApp\"\n" +
            "RETURN\n";

        Set<String> publics = extractPublicVariables(code);

        assertTrue("Should find gAppName", publics.contains("gAppName"));
        assertTrue("Should find gVersion", publics.contains("gVersion"));
        assertTrue("Should find gConfig", publics.contains("gConfig"));
    }

    /**
     * Test PRIVATE variable detection.
     */
    @Test
    public void testPrivateVariableDetection() {
        String code =
            "FUNCTION Test()\n" +
            "PRIVATE mVar, mCount\n" +
            "   mVar := \"test\"\n" +
            "RETURN\n";

        Set<String> privates = extractPrivateVariables(code);

        assertTrue("Should find mVar", privates.contains("mVar"));
        assertTrue("Should find mCount", privates.contains("mCount"));
    }

    /**
     * Test STATIC variable detection.
     */
    @Test
    public void testStaticVariableDetection() {
        String code =
            "STATIC sCounter := 0\n" +
            "\n" +
            "FUNCTION IncrementCounter()\n" +
            "   sCounter++\n" +
            "RETURN sCounter\n";

        Set<String> statics = extractStaticVariables(code);

        assertTrue("Should find sCounter", statics.contains("sCounter"));
    }

    /**
     * Test function parameter detection.
     */
    @Test
    public void testFunctionParameterDetection() {
        String funcDecl = "FUNCTION Calculate(nValue, cOption, lVerbose)";

        Set<String> params = extractFunctionParameters(funcDecl);

        assertTrue("Should find nValue", params.contains("nValue"));
        assertTrue("Should find cOption", params.contains("cOption"));
        assertTrue("Should find lVerbose", params.contains("lVerbose"));
        assertEquals("Should find 3 parameters", 3, params.size());
    }

    /**
     * Test multi-line function parameter detection.
     */
    @Test
    public void testMultiLineFunctionParameters() {
        String funcDecl =
            "FUNCTION ProcessData(cInput, ;\n" +
            "                      nCount, ;\n" +
            "                      lDebug)";

        Set<String> params = extractFunctionParameters(funcDecl);

        assertTrue("Should find cInput", params.contains("cInput"));
        assertTrue("Should find nCount", params.contains("nCount"));
        assertTrue("Should find lDebug", params.contains("lDebug"));
    }

    /**
     * Test block end keyword detection.
     */
    @Test
    public void testBlockEndKeywords() {
        String[] blockEndKeywords = {
            "endif", "enddo", "endclass", "endcase", "endswitch",
            "next", "else", "elseif", "return", "exit", "loop",
            "recover", "end sequence", "otherwise", "endwith"
        };

        for (String keyword : blockEndKeywords) {
            assertTrue("Should recognize " + keyword + " as block end",
                isBlockEndKeyword(keyword.toLowerCase()));
        }

        assertFalse("if should not be block end", isBlockEndKeyword("if"));
        assertFalse("do should not be block end", isBlockEndKeyword("do"));
        assertFalse("for should not be block end", isBlockEndKeyword("for"));
    }

    /**
     * Test object method context detection (after colon).
     */
    @Test
    public void testObjectMethodContextDetection() {
        // These should trigger object method completion
        assertTrue("oWindow: should trigger", hasObjectContext("oWindow:"));
        assertTrue("Self: should trigger", hasObjectContext("Self:"));
        assertTrue("::cName should trigger", hasObjectContext("::cName"));

        // These should NOT trigger object method completion
        assertFalse("Just identifier should not trigger", hasObjectContext("oWindow"));
        assertFalse("Empty should not trigger", hasObjectContext(""));
    }

    // ===== Helper methods that replicate completion logic =====

    private Set<String> extractLocalVariables(String code) {
        Set<String> locals = new HashSet<>();
        // Match LOCAL followed by variable declarations until end of line
        Pattern localPattern = Pattern.compile("(?i)\\bLOCAL\\s+(.+?)(?:\\r?\\n|$)", Pattern.MULTILINE);
        Matcher matcher = localPattern.matcher(code);

        while (matcher.find()) {
            String declarations = matcher.group(1).trim();
            String[] vars = declarations.split(",");
            for (String var : vars) {
                String varName = var.trim();
                // Remove assignment and anything after
                int assignIdx = varName.indexOf(":=");
                if (assignIdx > 0) {
                    varName = varName.substring(0, assignIdx).trim();
                }
                if (!varName.isEmpty() && Character.isLetter(varName.charAt(0))) {
                    locals.add(varName);
                }
            }
        }
        return locals;
    }

    private Set<String> extractWorkareas(String code) {
        Set<String> workareas = new HashSet<>();

        // SELECT pattern
        Pattern selectPattern = Pattern.compile("(?i)\\bSELECT\\s+(\\w+)", Pattern.MULTILINE);
        Matcher selectMatcher = selectPattern.matcher(code);
        while (selectMatcher.find()) {
            String alias = selectMatcher.group(1);
            // Skip numbers
            if (!alias.matches("\\d+")) {
                workareas.add(alias);
            }
        }

        // USE pattern with optional ALIAS
        Pattern usePattern = Pattern.compile("(?i)\\bUSE\\s+(\\w+)(?:\\.\\w+)?(?:\\s+ALIAS\\s+(\\w+))?", Pattern.MULTILINE);
        Matcher useMatcher = usePattern.matcher(code);
        while (useMatcher.find()) {
            String filename = useMatcher.group(1);
            String alias = useMatcher.group(2);
            workareas.add(alias != null ? alias : filename);
        }

        return workareas;
    }

    private Set<String> extractPublicVariables(String code) {
        Set<String> publics = new HashSet<>();
        Pattern publicPattern = Pattern.compile("(?i)^\\s*PUBLIC\\s+([\\w,\\s:=\\[\\]{}()\"'.]+?)(?:\\s*//|\\s*$)", Pattern.MULTILINE);
        Matcher matcher = publicPattern.matcher(code);

        while (matcher.find()) {
            String declarations = matcher.group(1);
            String[] vars = declarations.split(",");
            for (String var : vars) {
                String varName = var.trim();
                int assignIdx = varName.indexOf(":=");
                if (assignIdx > 0) {
                    varName = varName.substring(0, assignIdx).trim();
                }
                if (!varName.isEmpty() && Character.isLetter(varName.charAt(0))) {
                    publics.add(varName);
                }
            }
        }
        return publics;
    }

    private Set<String> extractPrivateVariables(String code) {
        Set<String> privates = new HashSet<>();
        Pattern privatePattern = Pattern.compile("(?i)\\bPRIVATE\\s+(.+?)(?:\\r?\\n|$)", Pattern.MULTILINE);
        Matcher matcher = privatePattern.matcher(code);

        while (matcher.find()) {
            String declarations = matcher.group(1).trim();
            String[] vars = declarations.split(",");
            for (String var : vars) {
                String varName = var.trim();
                int assignIdx = varName.indexOf(":=");
                if (assignIdx > 0) {
                    varName = varName.substring(0, assignIdx).trim();
                }
                if (!varName.isEmpty() && Character.isLetter(varName.charAt(0))) {
                    privates.add(varName);
                }
            }
        }
        return privates;
    }

    private Set<String> extractStaticVariables(String code) {
        Set<String> statics = new HashSet<>();
        Pattern staticPattern = Pattern.compile("(?i)^\\s*STATIC\\s+(\\w+)", Pattern.MULTILINE);
        Matcher matcher = staticPattern.matcher(code);

        while (matcher.find()) {
            statics.add(matcher.group(1));
        }
        return statics;
    }

    private Set<String> extractFunctionParameters(String declaration) {
        Set<String> params = new HashSet<>();

        // Remove line continuation characters
        String cleanDecl = declaration.replace(";", "").replaceAll("\\s+", " ");

        int openParen = cleanDecl.indexOf('(');
        int closeParen = cleanDecl.lastIndexOf(')');

        if (openParen > 0 && closeParen > openParen) {
            String paramsText = cleanDecl.substring(openParen + 1, closeParen);
            String[] paramList = paramsText.split(",");
            for (String param : paramList) {
                String paramName = param.trim();
                if (!paramName.isEmpty()) {
                    params.add(paramName);
                }
            }
        }
        return params;
    }

    private boolean isBlockEndKeyword(String command) {
        return command.equals("endif") || command.equals("enddo") ||
                command.equals("endclass") || command.equals("endcase") ||
                command.equals("endswitch") || command.equals("next") ||
                command.equals("else") || command.equals("elseif") ||
                command.equals("return") || command.equals("exit") ||
                command.equals("loop") || command.equals("recover") ||
                command.equals("end sequence") || command.equals("otherwise") ||
                command.equals("endwith");
    }

    private boolean hasObjectContext(String text) {
        if (text == null || text.isEmpty()) return false;
        // Check for :: (self reference) or identifier followed by :
        return text.startsWith("::") || text.endsWith(":");
    }
}

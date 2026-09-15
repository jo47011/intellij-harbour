package org.intellij.sdk.language;

import com.intellij.openapi.editor.Document;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.testFramework.fixtures.BasePlatformTestCase;
import com.intellij.xml.breadcrumbs.PsiFileBreadcrumbsCollector;

import java.util.ArrayList;
import java.util.List;

/**
 * Verifies what {@link HarbourBreadcrumbsProvider} reports for a caret position - this is what
 * both the sticky lines and the breadcrumb bar are built from.
 *
 * <p>Sticky lines use the element's text range as the scope of the sticky line, so the tests
 * check the range as well, not only the name.
 */
public class HarbourBreadcrumbsTest extends BasePlatformTestCase {

    private static final String CODE =
            "// ** Werbung ***\r\n" +
            "PROCEDURE WKdDisp(Aendern,Sperren)\r\n" +
            "LOCAL GetList:={}\r\n" +
            "  @  8,15 say \"Nummer...: \" get WERBUNG->Kurzname\r\n" +
            "RETURN\r\n" +
            "/* EOP WKdDisp */\r\n" +
            "\r\n" +
            "static function dispMaschGruppe(ob,li)\r\n" +
            "  MASCHGR->(dbseek(MASCHINE->MaschGr))\r\n" +
            "return .t.\r\n" +
            "\r\n" +
            "/* Av: Machinen / Stunden , Zeiten */\r\n" +
            "PROCEDURE MasDisp(Aendern,Sperren)\r\n" +
            "LOCAL GetList:={}\r\n" +
            "\r\n" +
            "  open(\"MaschGr\")<caret>\r\n" +
            "  select Maschine\r\n" +
            "RETURN\r\n";

    private static final String CLASS_CODE =
            "CLASS TBrowseDB FROM TBrowse\r\n" +
            "   DATA cAlias\r\n" +
            "   METHOD New(nTop)\r\n" +
            "ENDCLASS\r\n" +
            "\r\n" +
            "METHOD New(nTop) CLASS TBrowseDB\r\n" +
            "   LOCAL oBrw\r\n" +
            "   oBrw:=1<caret>\r\n" +
            "RETURN Self\r\n";

    public void testCrumbIsTheEnclosingProcedure() {
        assertCrumbs(CODE, "MasDisp");
    }

    /** "METHOD x() CLASS y" is a routine of its own - the CLASS suffix must not start one. */
    public void testCrumbInsideMethodImplementation() {
        assertCrumbs(CLASS_CODE, "New");
    }

    public void testCrumbOnDeclarationLineItself() {
        assertCrumbs("FUNCTION Main()\r\nRETURN <caret>NIL\r\n", "Main");
    }

    public void testNoCrumbsOutsideAnyDeclaration() {
        assertCrumbs("#include \"inkey.ch\"<caret>\r\nFUNCTION Main()\r\nRETURN NIL\r\n");
    }

    /**
     * Same case as {@link #testCrumbIsTheEnclosingProcedure()}, but through the real platform
     * collector - this also covers the plugin.xml registration and the language lookup.
     */
    public void testPlatformCollectorFindsTheProcedure() {
        PsiFile file = myFixture.configureByText("breadcrumbs.prg", CODE);
        PsiElement[] elements = PsiFileBreadcrumbsCollector.getLinePsiElements(
                myFixture.getEditor().getDocument(), myFixture.getCaretOffset(),
                file.getVirtualFile(), getProject(), null);

        assertNotNull("no breadcrumbs provider found for Harbour", elements);
        List<String> crumbs = new ArrayList<>();
        HarbourBreadcrumbsProvider provider = new HarbourBreadcrumbsProvider();
        for (PsiElement element : elements) {
            crumbs.add(provider.getElementInfo(element));
        }
        assertEquals(List.of("MasDisp"), crumbs);
    }

    /**
     * The sticky line scope: StickyLinesCollector takes the element's range for every line of the
     * document, so the range has to cover the routine from its declaration to its last line.
     */
    public void testStickyLineScopeCoversTheWholeRoutine() {
        PsiFile file = myFixture.configureByText("breadcrumbs.prg", CODE);
        Document document = myFixture.getEditor().getDocument();

        PsiElement declaration = declarationAt(file, document, "  select Maschine");
        assertNotNull("no declaration element for the routine", declaration);
        assertEquals("MasDisp", new HarbourBreadcrumbsProvider().getElementInfo(declaration));
        assertEquals("sticky line starts on the declaration line",
                lineOf(document, "PROCEDURE MasDisp(Aendern,Sperren)"),
                document.getLineNumber(declaration.getTextOffset()));
        assertEquals("sticky line ends on the last line of the routine",
                lineOf(document, "RETURN", true),
                document.getLineNumber(declaration.getTextRange().getEndOffset()));
    }

    /** Every routine of the file must produce exactly one sticky line scope. */
    public void testEveryRoutineIsRecognized() {
        PsiFile file = myFixture.configureByText("breadcrumbs.prg", CODE);
        Document document = myFixture.getEditor().getDocument();
        HarbourBreadcrumbsProvider provider = new HarbourBreadcrumbsProvider();

        List<String> names = new ArrayList<>();
        for (int line = 0; line < document.getLineCount(); line++) {
            PsiElement declaration = declarationAtOffset(file, document, document.getLineEndOffset(line));
            if (declaration != null) {
                String name = provider.getElementInfo(declaration);
                if (!names.contains(name)) {
                    names.add(name);
                }
            }
        }
        assertEquals(List.of("WKdDisp", "dispMaschGruppe", "MasDisp"), names);
    }

    private PsiElement declarationAt(PsiFile file, Document document, String lineText) {
        return declarationAtOffset(file, document, document.getLineEndOffset(lineOf(document, lineText)));
    }

    private PsiElement declarationAtOffset(PsiFile file, Document document, int offset) {
        List<PsiElement> elements = new PsiFileBreadcrumbsCollector(getProject())
                .computePsiElements(file.getVirtualFile(), document, offset);
        return elements.isEmpty() ? null : elements.get(elements.size() - 1);
    }

    private static int lineOf(Document document, String lineText) {
        return lineOf(document, lineText, false);
    }

    private static int lineOf(Document document, String lineText, boolean last) {
        int result = -1;
        for (int line = 0; line < document.getLineCount(); line++) {
            String text = document.getText().substring(
                    document.getLineStartOffset(line), document.getLineEndOffset(line));
            if (text.equals(lineText)) {
                result = line;
                if (!last) {
                    return result;
                }
            }
        }
        assertTrue("line not found: " + lineText, result >= 0);
        return result;
    }

    /** Walks the crumb chain exactly like PsiFileBreadcrumbsCollector does. */
    private void assertCrumbs(String code, String... expected) {
        PsiFile file = myFixture.configureByText("breadcrumbs.prg", code);
        HarbourBreadcrumbsProvider provider = new HarbourBreadcrumbsProvider();

        List<String> crumbs = new ArrayList<>();
        PsiElement element = file.findElementAt(myFixture.getCaretOffset());
        assertNotNull("no PSI element at the caret", element);
        for (int guard = 0; element != null && !(element instanceof PsiFile); guard++) {
            assertTrue("breadcrumb parent chain does not terminate", guard < 100);
            if (provider.acceptElement(element)) {
                crumbs.add(0, provider.getElementInfo(element));
            }
            element = provider.getParent(element);
        }

        assertEquals(List.of(expected), crumbs);
    }
}

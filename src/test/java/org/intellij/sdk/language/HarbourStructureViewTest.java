package org.intellij.sdk.language;

import com.intellij.ide.util.treeView.smartTree.TreeElement;
import com.intellij.psi.PsiFile;
import com.intellij.testFramework.fixtures.BasePlatformTestCase;

import java.util.ArrayList;
import java.util.List;

/**
 * Guards the Structure View against changes of the AST shape - it walks the token leaves and
 * their siblings, which the DECLARATION_BLOCK nodes of the parser must not disturb.
 */
public class HarbourStructureViewTest extends BasePlatformTestCase {

    public void testRoutinesAreListed() {
        assertStructure(
                "PROCEDURE WKdDisp(Aendern,Sperren)\r\n" +
                "LOCAL GetList:={}\r\n" +
                "RETURN\r\n" +
                "\r\n" +
                "static function dispMaschGruppe(ob,li)\r\n" +
                "return .t.\r\n" +
                "\r\n" +
                "PROCEDURE MasDisp(Aendern,Sperren)\r\n" +
                "RETURN\r\n",
                "PROCEDURE WKdDisp", "FUNCTION dispMaschGruppe", "PROCEDURE MasDisp");
    }

    public void testClassIsListed() {
        assertStructure(
                "CLASS TBrowseDB FROM TBrowse\r\n" +
                "   DATA cAlias\r\n" +
                "   METHOD New(nTop)\r\n" +
                "ENDCLASS\r\n" +
                "\r\n" +
                "METHOD New(nTop) CLASS TBrowseDB\r\n" +
                "RETURN Self\r\n",
                // Pre-existing quirk of the Structure View (not caused by DECLARATION_BLOCK):
                // the CLASS suffix of "METHOD New() CLASS TBrowseDB" is listed as a class as well
                "CLASS TBrowseDB", "CLASS TBrowseDB");
    }

    private void assertStructure(String code, String... expected) {
        PsiFile file = myFixture.configureByText("structure.prg", code);

        List<String> texts = new ArrayList<>();
        for (TreeElement child : new HarbourStructureViewElement(file).getChildren()) {
            texts.add(child.getPresentation().getPresentableText());
        }
        assertEquals(List.of(expected), texts);
    }
}

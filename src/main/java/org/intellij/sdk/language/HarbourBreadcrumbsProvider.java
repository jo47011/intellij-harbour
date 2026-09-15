package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.lang.ASTNode;
import com.intellij.lang.Language;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.tree.IElementType;
import com.intellij.psi.tree.TokenSet;
import com.intellij.ui.breadcrumbs.BreadcrumbsProvider;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.util.regex.Pattern;

/**
 * Describes a Harbour routine (CLASS / FUNCTION / PROCEDURE / METHOD) to the platform.
 *
 * <p>This drives the <b>sticky lines</b> above the editor: they are collected from the elements
 * this provider accepts and use their text range as the scope, which is why the parser wraps
 * every routine in a {@link HarbourTypes#DECLARATION_BLOCK} node.
 *
 * <p>The breadcrumb bar uses the same provider but is switched off by default
 * ({@link #isShownByDefault()}); it can be enabled in Settings | Editor | General | Breadcrumbs.
 */
public class HarbourBreadcrumbsProvider implements BreadcrumbsProvider {

    /** Keyword a declaration block starts with. */
    private static final TokenSet DECLARATION_KEYWORDS = TokenSet.create(
            HarbourTypes.CLASS, HarbourTypes.FUNCTION, HarbourTypes.PROCEDURE, HarbourTypes.METHOD);

    /** Generic declaration name - keeps keyword-like names (DATA, ERROR, ...) working. */
    private static final Pattern DECLARATION_NAME = Pattern.compile("[A-Za-z_][A-Za-z_0-9]*");

    private static final Language[] LANGUAGES = new Language[]{HarbourLanguage.INSTANCE};

    private static final String COMPONENT = "Breadcrumbs";

    @Override
    public Language[] getLanguages() {
        return LANGUAGES;
    }

    /** Sticky lines stay on, the breadcrumb bar does not. */
    @Override
    public boolean isShownByDefault() {
        return false;
    }

    @Override
    public boolean acceptElement(@NotNull PsiElement element) {
        return getDeclarationName(element) != null;
    }

    @Override
    public String getElementInfo(@NotNull PsiElement element) {
        String name = getDeclarationName(element);
        String info = name != null ? name : element.getText();
        HarbourLogger.log(COMPONENT, "declaration '" + info + "' at offset " + element.getTextOffset()
                + " length " + element.getTextLength() + " in " + element.getContainingFile().getName());
        return info;
    }

    @Override
    public @Nullable String getElementTooltip(@NotNull PsiElement element) {
        PsiElement keyword = declarationKeyword(element);
        String name = getDeclarationName(element);
        return keyword == null || name == null
                ? null : StringUtil.toUpperCase(keyword.getText()) + " " + name;
    }

    @Override
    public @Nullable Icon getElementIcon(@NotNull PsiElement element) {
        PsiElement keyword = declarationKeyword(element);
        return keyword != null && tokenType(keyword) == HarbourTypes.CLASS
                ? AllIcons.Nodes.Class : AllIcons.Nodes.Method;
    }

    /** Routines are never nested in Harbour, so a declaration block is always the outermost one. */
    @Override
    public @Nullable PsiElement getParent(@NotNull PsiElement element) {
        if (isDeclarationBlock(element)) {
            return null;
        }
        PsiElement parent = element.getParent();
        return parent instanceof PsiFile ? null : parent;
    }

    /** Name of the routine a declaration block declares, or null for any other element. */
    private static @Nullable String getDeclarationName(@NotNull PsiElement element) {
        PsiElement keyword = declarationKeyword(element);
        if (keyword == null) {
            return null;
        }
        for (PsiElement next = keyword.getNextSibling(); next != null; next = next.getNextSibling()) {
            String text = next.getText();
            if (text.isBlank()) {
                if (text.indexOf('\n') >= 0) {
                    return null;            // nothing but the keyword on this line
                }
                continue;
            }
            return DECLARATION_NAME.matcher(text).matches() ? text : null;
        }
        return null;
    }

    /** Keyword a declaration block starts with, or null if the element is not such a block. */
    private static @Nullable PsiElement declarationKeyword(@NotNull PsiElement element) {
        if (!isDeclarationBlock(element)) {
            return null;
        }
        for (PsiElement child = element.getFirstChild(); child != null;
             child = child.getNextSibling()) {
            IElementType type = tokenType(child);
            if (type != null && DECLARATION_KEYWORDS.contains(type)) {
                return child;
            }
            if (!child.getText().isBlank()) {
                return null;
            }
        }
        return null;
    }

    private static boolean isDeclarationBlock(@NotNull PsiElement element) {
        return tokenType(element) == HarbourTypes.DECLARATION_BLOCK;
    }

    private static @Nullable IElementType tokenType(@NotNull PsiElement element) {
        ASTNode node = element.getNode();
        return node != null ? node.getElementType() : null;
    }
}

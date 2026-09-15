package org.intellij.sdk.language;

import com.intellij.extapi.psi.ASTWrapperPsiElement;
import com.intellij.lang.ASTNode;
import com.intellij.lang.ParserDefinition;
import com.intellij.lang.PsiBuilder;
import com.intellij.lang.PsiParser;
import com.intellij.lexer.Lexer;
import com.intellij.openapi.project.Project;
import com.intellij.psi.FileViewProvider;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.tree.IElementType;
import com.intellij.psi.tree.IFileElementType;
import com.intellij.psi.tree.TokenSet;
import org.intellij.sdk.language.psi.HarbourFile;
import org.intellij.sdk.language.psi.HarbourTypes;
import org.intellij.sdk.language.psi.impl.HarbourPsiElementFactoryImpl;
import org.jetbrains.annotations.NotNull;

public class HarbourParserDefinition implements ParserDefinition {
  public static final IFileElementType FILE = new IFileElementType(HarbourLanguage.INSTANCE);

  private static final TokenSet COMMENTS = TokenSet.create(
          HarbourTypes.EOL_COMMENT,
          HarbourTypes.BLOCK_COMMENT
  );

  private static final TokenSet STRINGS = TokenSet.create(
          HarbourTypes.STRING_LITERAL
  );

  @NotNull
  @Override
  public Lexer createLexer(Project project) {
    return new HarbourLexerAdapter();
  }

  @NotNull
  @Override
  public TokenSet getCommentTokens() {
    return COMMENTS;
  }

  @NotNull
  @Override
  public TokenSet getStringLiteralElements() {
    return STRINGS;
  }

  @NotNull
  @Override
  public IFileElementType getFileNodeType() {
    return FILE;
  }

  /** Keywords that open a routine: everything up to the next one belongs to it. */
  private static final TokenSet DECLARATION_KEYWORDS = TokenSet.create(
          HarbourTypes.FUNCTION,
          HarbourTypes.PROCEDURE,
          HarbourTypes.METHOD,
          HarbourTypes.CLASS
  );

  @NotNull
  @Override
  public PsiParser createParser(Project project) {
    // The tokens stay flat, but each routine gets one DECLARATION_BLOCK node around it so that
    // its text range covers the whole routine (sticky lines, breadcrumbs).
    return new PsiParser() {
      @NotNull
      @Override
      public ASTNode parse(@NotNull IElementType root, @NotNull PsiBuilder builder) {
        PsiBuilder.Marker rootMarker = builder.mark();
        PsiBuilder.Marker declaration = null;
        while (!builder.eof()) {
          if (DECLARATION_KEYWORDS.contains(builder.getTokenType()) && startsStatement(builder)) {
            if (declaration != null) {
              declaration.done(HarbourTypes.DECLARATION_BLOCK);
            }
            declaration = builder.mark();
          }
          builder.advanceLexer();
        }
        if (declaration != null) {
          declaration.done(HarbourTypes.DECLARATION_BLOCK);
        }
        rootMarker.done(root);
        return builder.getTreeBuilt();
      }
    };
  }

  /**
   * True if only words separated by blanks precede the current token on its line - that is what a
   * declaration looks like ("PROCEDURE x", "STATIC FUNCTION y", "INIT PROCEDURE z"), while
   * "METHOD m() CLASS c" or "#define CLASS" do not qualify.
   */
  private static boolean startsStatement(@NotNull PsiBuilder builder) {
    CharSequence text = builder.getOriginalText();
    for (int i = builder.getCurrentOffset() - 1; i >= 0; i--) {
      char c = text.charAt(i);
      if (c == '\n' || c == '\r') {
        return true;
      }
      if (c != ' ' && c != '\t' && c != '_' && !Character.isLetterOrDigit(c)) {
        return false;
      }
    }
    return true;
  }

  @NotNull
  @Override
  public PsiElement createElement(ASTNode node) {
    if (node.getElementType() == HarbourTypes.DECLARATION_BLOCK) {
      return new ASTWrapperPsiElement(node);
    }
    return new HarbourPsiElementFactoryImpl().createElement(node);
  }

  @NotNull
  @Override
  public PsiFile createFile(@NotNull FileViewProvider viewProvider) {
    return new HarbourFile(viewProvider);
  }
}
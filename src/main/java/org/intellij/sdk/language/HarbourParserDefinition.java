package org.intellij.sdk.language;

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

  @NotNull
  @Override
  public PsiParser createParser(Project project) {
    // Simple fallback parser implementation for development
    return new PsiParser() {
      @NotNull
      @Override
      public ASTNode parse(@NotNull IElementType root, @NotNull PsiBuilder builder) {
        PsiBuilder.Marker rootMarker = builder.mark();
        while (!builder.eof()) {
          builder.advanceLexer();
        }
        rootMarker.done(root);
        return builder.getTreeBuilt();
      }
    };
  }

  @NotNull
  @Override
  public PsiElement createElement(ASTNode node) {
    return new HarbourPsiElementFactoryImpl().createElement(node);
  }

  @NotNull
  @Override
  public PsiFile createFile(@NotNull FileViewProvider viewProvider) {
    return new HarbourFile(viewProvider);
  }
}
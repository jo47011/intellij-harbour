package org.intellij.sdk.language.psi.impl;

import com.intellij.lang.ASTNode;
import org.intellij.sdk.language.psi.FunctionCall;
import org.jetbrains.annotations.NotNull;

public class FunctionCallImpl extends HarbourFunctionCallMixin implements FunctionCall {
    public FunctionCallImpl(@NotNull ASTNode node) {
        super(node);
    }
}
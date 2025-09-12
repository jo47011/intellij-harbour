package org.intellij.sdk.language.psi.stub.impl;

import com.intellij.psi.stubs.IStubElementType;
import com.intellij.psi.stubs.StubBase;
import com.intellij.psi.stubs.StubElement;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.intellij.sdk.language.psi.stub.HarbourFunctionStub;
import org.jetbrains.annotations.Nullable;

/**
 * Implementation of HarbourFunctionStub.
 */
public class HarbourFunctionStubImpl extends StubBase<HarbourFunctionDeclaration> implements HarbourFunctionStub {
    private final String name;
    private final String signature;
    private final boolean isStatic;

    public HarbourFunctionStubImpl(StubElement parent, IStubElementType elementType, 
                                   @Nullable String name, @Nullable String signature, boolean isStatic) {
        super(parent, elementType);
        this.name = name;
        this.signature = signature;
        this.isStatic = isStatic;
    }

    @Override
    @Nullable
    public String getName() {
        return name;
    }

    @Override
    @Nullable
    public String getSignature() {
        return signature;
    }

    @Override
    public boolean isStatic() {
        return isStatic;
    }
}
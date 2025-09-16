package org.intellij.sdk.language.psi.stub;

import com.intellij.psi.stubs.StubElement;
import org.intellij.sdk.language.psi.HarbourProcedureDeclaration;
import org.jetbrains.annotations.Nullable;

/**
 * Stub interface for Harbour procedure declarations.
 */
public interface HarbourProcedureStub extends StubElement<HarbourProcedureDeclaration> {
    @Nullable
    String getName();
    
    @Nullable
    String getSignature();
    
    boolean isStatic();
}
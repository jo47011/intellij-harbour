package org.intellij.sdk.language.psi.stub;

import com.intellij.psi.stubs.StubElement;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.jetbrains.annotations.Nullable;

/**
 * Stub interface for Harbour function declarations.
 * Stores minimal information needed for fast indexing and navigation.
 */
public interface HarbourFunctionStub extends StubElement<HarbourFunctionDeclaration> {
    /**
     * @return the function name
     */
    @Nullable
    String getName();
    
    /**
     * @return the function signature/parameters
     */
    @Nullable
    String getSignature();
    
    /**
     * @return true if this is a static function
     */
    boolean isStatic();
}
package org.intellij.sdk.language.psi.stub;

import com.intellij.psi.stubs.StringStubIndexExtension;
import com.intellij.psi.stubs.StubIndexKey;
import org.intellij.sdk.language.psi.HarbourFunctionDeclaration;
import org.jetbrains.annotations.NotNull;

/**
 * Stub index for Harbour function names.
 * Provides instant lookup of functions by name.
 */
public class HarbourFunctionNameIndex extends StringStubIndexExtension<HarbourFunctionDeclaration> {
    public static final StubIndexKey<String, HarbourFunctionDeclaration> KEY = 
        StubIndexKey.createIndexKey("harbour.function.name");
    
    private static final HarbourFunctionNameIndex INSTANCE = new HarbourFunctionNameIndex();
    
    public static HarbourFunctionNameIndex getInstance() {
        return INSTANCE;
    }
    
    @NotNull
    @Override
    public StubIndexKey<String, HarbourFunctionDeclaration> getKey() {
        return KEY;
    }
    
    @Override
    public int getVersion() {
        return 1;
    }
}
package org.intellij.sdk.language.psi.stub;

import com.intellij.psi.stubs.StringStubIndexExtension;
import com.intellij.psi.stubs.StubIndexKey;
import org.intellij.sdk.language.psi.ClassDeclaration;
import org.jetbrains.annotations.NotNull;

/**
 * Stub index for Harbour class names.
 * Provides instant lookup of classes by name.
 */
public class HarbourClassNameIndex extends StringStubIndexExtension<ClassDeclaration> {
    public static final StubIndexKey<String, ClassDeclaration> KEY = 
        StubIndexKey.createIndexKey("harbour.class.name");
    
    private static final HarbourClassNameIndex INSTANCE = new HarbourClassNameIndex();
    
    public static HarbourClassNameIndex getInstance() {
        return INSTANCE;
    }
    
    @NotNull
    @Override
    public StubIndexKey<String, ClassDeclaration> getKey() {
        return KEY;
    }
    
    @Override
    public int getVersion() {
        return 1;
    }
}
package org.intellij.sdk.language.psi.stub;

import com.intellij.psi.stubs.StringStubIndexExtension;
import com.intellij.psi.stubs.StubIndexKey;
import org.intellij.sdk.language.psi.HarbourProcedureDeclaration;
import org.jetbrains.annotations.NotNull;

/**
 * Stub index for Harbour procedure names.
 * Provides instant lookup of procedures by name.
 */
public class HarbourProcedureNameIndex extends StringStubIndexExtension<HarbourProcedureDeclaration> {
    public static final StubIndexKey<String, HarbourProcedureDeclaration> KEY = 
        StubIndexKey.createIndexKey("harbour.procedure.name");
    
    private static final HarbourProcedureNameIndex INSTANCE = new HarbourProcedureNameIndex();
    
    public static HarbourProcedureNameIndex getInstance() {
        return INSTANCE;
    }
    
    @NotNull
    @Override
    public StubIndexKey<String, HarbourProcedureDeclaration> getKey() {
        return KEY;
    }
    
    @Override
    public int getVersion() {
        return 1;
    }
}
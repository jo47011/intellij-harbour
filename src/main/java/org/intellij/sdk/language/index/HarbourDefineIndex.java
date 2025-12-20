package org.intellij.sdk.language.index;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.psi.PsiFile;
import com.intellij.psi.PsiManager;
import com.intellij.psi.search.GlobalSearchScope;
import com.intellij.util.indexing.*;
import com.intellij.util.io.DataExternalizer;
import com.intellij.util.io.EnumeratorStringDescriptor;
import com.intellij.util.io.KeyDescriptor;
import com.intellij.util.io.VoidDataExternalizer;
import org.intellij.sdk.language.HarbourFileType;
import org.jetbrains.annotations.NotNull;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class HarbourDefineIndex extends FileBasedIndexExtension<String, Void> {
    public static final ID<String, Void> INDEX_ID = ID.create("HarbourDefineIndex");
    
    private static final Pattern DEFINE_PATTERN = Pattern.compile("(?i)^\\s*#\\s*define\\s+(\\w+)(?:\\s|\\()");
    
    @NotNull
    @Override
    public ID<String, Void> getName() {
        return INDEX_ID;
    }
    
    @NotNull
    @Override
    public DataIndexer<String, Void, FileContent> getIndexer() {
        return inputData -> {
            Map<String, Void> map = new HashMap<>();
            
            String content = inputData.getContentAsText().toString();
            String[] lines = content.split("\n");
            
            for (String line : lines) {
                Matcher matcher = DEFINE_PATTERN.matcher(line);
                if (matcher.find()) {
                    String defineName = matcher.group(1);
                    if (defineName != null && !defineName.isEmpty()) {
                        map.put(defineName.toUpperCase(), null);
                    }
                }
            }
            
            return map;
        };
    }
    
    @NotNull
    @Override
    public KeyDescriptor<String> getKeyDescriptor() {
        return EnumeratorStringDescriptor.INSTANCE;
    }
    
    @NotNull
    @Override
    public DataExternalizer<Void> getValueExternalizer() {
        return VoidDataExternalizer.INSTANCE;
    }
    
    @NotNull
    @Override
    public FileBasedIndex.InputFilter getInputFilter() {
        // Use explicit extension check in addition to file type to avoid indexing
        // backup files like .old, .bak etc. that IntelliJ may associate with Harbour
        // due to cached VFS file type associations
        return file -> {
            if (file.getFileType() != HarbourFileType.INSTANCE) {
                return false;
            }
            String ext = file.getExtension();
            return ext != null && (ext.equalsIgnoreCase("prg") || ext.equalsIgnoreCase("ch"));
        };
    }
    
    @Override
    public boolean dependsOnFileContent() {
        return true;
    }
    
    @Override
    public int getVersion() {
        return 2; // Added explicit extension check to avoid indexing .old/.bak files
    }
    
    public static boolean isDefinedConstant(@NotNull Project project, @NotNull String constantName) {
        return !FileBasedIndex.getInstance()
                .getContainingFiles(INDEX_ID, constantName.toUpperCase(), GlobalSearchScope.allScope(project))
                .isEmpty();
    }
}
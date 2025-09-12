package org.intellij.sdk.language.index;

import com.intellij.openapi.vfs.VirtualFile;
import com.intellij.util.indexing.*;
import com.intellij.util.io.DataExternalizer;
import com.intellij.util.io.EnumeratorStringDescriptor;
import com.intellij.util.io.KeyDescriptor;
import org.intellij.sdk.language.HarbourFileType;
import org.jetbrains.annotations.NotNull;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * FileBasedIndex for Harbour functions and procedures.
 * Indexes BOTH declarations AND usages for instant lookup.
 */
public class HarbourFunctionIndex extends FileBasedIndexExtension<String, HarbourFunctionIndex.FunctionInfo> {
    public static final ID<String, FunctionInfo> INDEX_ID = ID.create("harbour.function.index");
    
    // Pattern for finding function/procedure declarations
    private static final Pattern DECLARATION_PATTERN = Pattern.compile(
        "(?i)^\\s*(STATIC\\s+)?(FUNCTION|PROCEDURE|METHOD)\\s+(\\w+)", Pattern.MULTILINE);
    
    // Pattern for finding function calls/usages
    private static final Pattern USAGE_PATTERN = Pattern.compile(
        "(?i)\\b(\\w+)\\s*\\(", Pattern.MULTILINE);
    
    @NotNull
    @Override
    public ID<String, FunctionInfo> getName() {
        return INDEX_ID;
    }

    @NotNull
    @Override
    public DataIndexer<String, FunctionInfo, FileContent> getIndexer() {
        return inputData -> {
            // Return ALL occurrences with unique keys
            // FileBasedIndex will store them all
            Map<String, FunctionInfo> map = new HashMap<>();
            String content = inputData.getContentAsText().toString();
            String fileName = inputData.getFileName();
            
            int occurrenceCounter = 0;
            
            // First, find all declarations
            Matcher declMatcher = DECLARATION_PATTERN.matcher(content);
            while (declMatcher.find()) {
                String type = declMatcher.group(2).toUpperCase();
                String name = declMatcher.group(3);
                boolean isStatic = declMatcher.group(1) != null;
                
                // Calculate line number
                int lineNumber = 1;
                for (int i = 0; i < declMatcher.start(); i++) {
                    if (content.charAt(i) == '\n') {
                        lineNumber++;
                    }
                }
                
                String key = name.toLowerCase();
                FunctionInfo info = new FunctionInfo(name, type, lineNumber, isStatic, true, fileName);
                
                // Store with unique key
                map.put(key + "#" + occurrenceCounter++, info);
            }
            
            // Then find all usages (function calls)
            Matcher usageMatcher = USAGE_PATTERN.matcher(content);
            while (usageMatcher.find()) {
                String name = usageMatcher.group(1);
                String key = name.toLowerCase();
                
                // Calculate line number for usage
                int lineNumber = 1;
                for (int i = 0; i < usageMatcher.start(); i++) {
                    if (content.charAt(i) == '\n') {
                        lineNumber++;
                    }
                }
                
                FunctionInfo info = new FunctionInfo(name, "USAGE", lineNumber, false, false, fileName);
                
                // Store with unique key
                map.put(key + "#" + occurrenceCounter++, info);
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
    public DataExternalizer<FunctionInfo> getValueExternalizer() {
        return new DataExternalizer<FunctionInfo>() {
            @Override
            public void save(@NotNull DataOutput out, FunctionInfo value) throws IOException {
                out.writeUTF(value.name);
                out.writeUTF(value.type);
                out.writeInt(value.lineNumber);
                out.writeBoolean(value.isStatic);
                out.writeBoolean(value.isDeclaration);
                out.writeUTF(value.fileName);
            }

            @Override
            public FunctionInfo read(@NotNull DataInput in) throws IOException {
                String name = in.readUTF();
                String type = in.readUTF();
                int lineNumber = in.readInt();
                boolean isStatic = in.readBoolean();
                boolean isDeclaration = in.readBoolean();
                String fileName = in.readUTF();
                return new FunctionInfo(name, type, lineNumber, isStatic, isDeclaration, fileName);
            }
        };
    }

    @Override
    public int getVersion() {
        return 5; // Force re-indexing with aggregated approach
    }

    @NotNull
    @Override
    public FileBasedIndex.InputFilter getInputFilter() {
        return new DefaultFileTypeSpecificInputFilter(HarbourFileType.INSTANCE);
    }

    @Override
    public boolean dependsOnFileContent() {
        return true;
    }
    
    /**
     * Information about a function/procedure declaration or usage.
     */
    public static class FunctionInfo {
        public final String name;
        public final String type; // FUNCTION, PROCEDURE, METHOD, or USAGE
        public final int lineNumber;
        public final boolean isStatic;
        public final boolean isDeclaration;
        public final String fileName;
        
        public FunctionInfo(String name, String type, int lineNumber, boolean isStatic, boolean isDeclaration, String fileName) {
            this.name = name;
            this.type = type;
            this.lineNumber = lineNumber;
            this.isStatic = isStatic;
            this.isDeclaration = isDeclaration;
            this.fileName = fileName;
        }
        
        // For backward compatibility
        public FunctionInfo(String name, String type, int lineNumber, boolean isStatic) {
            this(name, type, lineNumber, isStatic, false, "");
        }
        
        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            
            FunctionInfo that = (FunctionInfo) o;
            
            if (lineNumber != that.lineNumber) return false;
            if (isStatic != that.isStatic) return false;
            if (isDeclaration != that.isDeclaration) return false;
            if (!name.equals(that.name)) return false;
            if (!type.equals(that.type)) return false;
            return fileName.equals(that.fileName);
        }
        
        @Override
        public int hashCode() {
            int result = name.hashCode();
            result = 31 * result + type.hashCode();
            result = 31 * result + lineNumber;
            result = 31 * result + (isStatic ? 1 : 0);
            result = 31 * result + (isDeclaration ? 1 : 0);
            result = 31 * result + fileName.hashCode();
            return result;
        }
    }
}
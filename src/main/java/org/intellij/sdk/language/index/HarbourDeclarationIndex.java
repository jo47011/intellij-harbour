package org.intellij.sdk.language.index;

import com.intellij.util.indexing.*;
import com.intellij.util.io.DataExternalizer;
import com.intellij.util.io.EnumeratorStringDescriptor;
import com.intellij.util.io.KeyDescriptor;
import org.jetbrains.annotations.NotNull;

import java.io.DataInput;
import java.io.DataOutput;
import java.io.IOException;
import java.util.*;
import java.util.regex.Matcher;

/**
 * FileBasedIndex of FUNCTION / PROCEDURE / METHOD declarations only, keyed by lower-case name.
 * Feeds Go to Symbol (HarbourGotoSymbolContributor). A list per key because one file may
 * declare the same name several times (e.g. METHOD New in multiple classes).
 */
public class HarbourDeclarationIndex
        extends FileBasedIndexExtension<String, List<HarbourFunctionIndex.FunctionInfo>> {
    public static final ID<String, List<HarbourFunctionIndex.FunctionInfo>> INDEX_ID =
        ID.create("harbour.declaration.index");

    @NotNull
    @Override
    public ID<String, List<HarbourFunctionIndex.FunctionInfo>> getName() {
        return INDEX_ID;
    }

    @NotNull
    @Override
    public DataIndexer<String, List<HarbourFunctionIndex.FunctionInfo>, FileContent> getIndexer() {
        return inputData -> {
            Map<String, List<HarbourFunctionIndex.FunctionInfo>> map = new HashMap<>();
            CharSequence content = inputData.getContentAsText();
            String fileName = inputData.getFileName();
            Matcher matcher = HarbourFunctionIndex.DECLARATION_PATTERN.matcher(content);
            int lineNumber = 1;
            int lastOffset = 0;
            while (matcher.find()) {
                // Count lines incrementally from the previous match
                for (int i = lastOffset; i < matcher.start(); i++) {
                    if (content.charAt(i) == '\n') {
                        lineNumber++;
                    }
                }
                lastOffset = matcher.start();
                String name = matcher.group(3);
                map.computeIfAbsent(name.toLowerCase(), k -> new ArrayList<>())
                    .add(new HarbourFunctionIndex.FunctionInfo(name, matcher.group(2).toUpperCase(),
                        lineNumber, matcher.group(1) != null, true, fileName));
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
    public DataExternalizer<List<HarbourFunctionIndex.FunctionInfo>> getValueExternalizer() {
        return new DataExternalizer<List<HarbourFunctionIndex.FunctionInfo>>() {
            @Override
            public void save(@NotNull DataOutput out, List<HarbourFunctionIndex.FunctionInfo> value)
                    throws IOException {
                out.writeInt(value.size());
                for (HarbourFunctionIndex.FunctionInfo info : value) {
                    HarbourFunctionIndex.INFO_EXTERNALIZER.save(out, info);
                }
            }

            @Override
            public List<HarbourFunctionIndex.FunctionInfo> read(@NotNull DataInput in) throws IOException {
                int size = in.readInt();
                List<HarbourFunctionIndex.FunctionInfo> list = new ArrayList<>(size);
                for (int i = 0; i < size; i++) {
                    list.add(HarbourFunctionIndex.INFO_EXTERNALIZER.read(in));
                }
                return list;
            }
        };
    }

    @Override
    public int getVersion() {
        return 1;
    }

    @NotNull
    @Override
    public FileBasedIndex.InputFilter getInputFilter() {
        return HarbourFunctionIndex::isHarbourSource;
    }

    @Override
    public boolean dependsOnFileContent() {
        return true;
    }
}

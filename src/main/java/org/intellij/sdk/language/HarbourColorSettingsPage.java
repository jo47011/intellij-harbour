package org.intellij.sdk.language;

import com.intellij.openapi.editor.colors.TextAttributesKey;
import com.intellij.openapi.fileTypes.SyntaxHighlighter;
import com.intellij.openapi.options.colors.AttributesDescriptor;
import com.intellij.openapi.options.colors.ColorDescriptor;
import com.intellij.openapi.options.colors.ColorSettingsPage;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.util.HashMap;
import java.util.Map;

/**
 * Puts the "Harbour" page in Settings → Editor → Color Scheme
 */
public class HarbourColorSettingsPage implements ColorSettingsPage {

    private static final AttributesDescriptor[] DESCRIPTORS = new AttributesDescriptor[] {
            new AttributesDescriptor("Keyword", HarbourSyntaxHighlighter.KEYWORD),
            new AttributesDescriptor("Number", HarbourSyntaxHighlighter.NUMBER),
            new AttributesDescriptor("String", HarbourSyntaxHighlighter.STRING),
            new AttributesDescriptor("Comment", HarbourSyntaxHighlighter.COMMENT),
            new AttributesDescriptor("Operator", HarbourSyntaxHighlighter.OPERATOR),
            new AttributesDescriptor("At symbol (@)", HarbourSyntaxHighlighter.AT_SYMBOL),
            new AttributesDescriptor("Ampersand (&)", HarbourSyntaxHighlighter.AMPERSAND),
            new AttributesDescriptor("Local function", HarbourSyntaxHighlighter.LOCAL_FUNCTION),
            new AttributesDescriptor("External function", HarbourSyntaxHighlighter.EXTERNAL_FUNCTION),
    };

    @Override
    public @NotNull String getDisplayName() {
        return "Harbour";
    }

    @Override
    public @NotNull SyntaxHighlighter getHighlighter() {
        return new HarbourSyntaxHighlighter();
    }

    @Override
    public @NotNull String getDemoText() {
        // Demo code with tags to show the function highlighting
        return "// Demo code\n"
                + "function main()\n"
                + "local someVar = 10\n"
                + "  if someVar > 0\n"
                + "    ? \"Ok\"\n"
                + "    // Call local and external functions\n"
                + "    <local>localFunction</local>()\n"
                + "    <external>externalFunction</external>()\n"
                + "  endif\n"
                + "return\n"
                + "\n"
                + "// Local function definition\n"
                + "function localFunction()\n"
                + "  return .T.\n"
                + "/* eof */\n";
    }

    @Override
    public AttributesDescriptor @NotNull [] getAttributeDescriptors() {
        return DESCRIPTORS;
    }

    /**
     * Required by ColorAndFontDescriptorsProvider
     */
    @Override
    public ColorDescriptor @NotNull [] getColorDescriptors() {
        // No additional color descriptors (e.g. gutter background)
        return new ColorDescriptor[0];
    }

    @Nullable
    @Override
    public Map<String, TextAttributesKey> getAdditionalHighlightingTagToDescriptorMap() {
        // Map tags in demo text to text attribute keys
        Map<String, TextAttributesKey> map = new HashMap<>();
        map.put("local", HarbourSyntaxHighlighter.LOCAL_FUNCTION);
        map.put("external", HarbourSyntaxHighlighter.EXTERNAL_FUNCTION);
        return map;
    }

    // If you want an icon in the top-right corner of the page:
    @Nullable
    @Override
    public Icon getIcon() {
        return HarbourIcons.FILE;  // or null if you prefer no icon
    }
}
package org.intellij.sdk.language;

import com.intellij.lang.annotation.AnnotationHolder;
import com.intellij.lang.annotation.Annotator;
import com.intellij.lang.annotation.HighlightSeverity;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.editor.markup.EffectType;
import com.intellij.openapi.editor.markup.TextAttributes;
import com.intellij.openapi.util.TextRange;
import com.intellij.psi.PsiElement;
import org.jetbrains.annotations.NotNull;

import java.awt.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Annotator for Harbour #include statements
 */
public class HarbourIncludeAnnotator implements Annotator {
    private static final Logger LOG = Logger.getInstance(HarbourIncludeAnnotator.class);
    private static final String COMPONENT = "IncludeAnnotator";

    // Use the same pattern as in the GoToDeclarationHandler
    private static final Pattern INCLUDE_PATTERN = Pattern.compile("(#include|#INCLUDE)\\s*[\"<]([^\">\n]+)[>\"]");

    // Text attributes for include filename (like "file.ch")
    private static final TextAttributes INCLUDE_FILENAME_ATTRIBUTES = new TextAttributes();

    static {
        // Filename color (similar to function calls)
        INCLUDE_FILENAME_ATTRIBUTES.setForegroundColor(new Color(0, 102, 204)); // Standard blue
        INCLUDE_FILENAME_ATTRIBUTES.setEffectType(EffectType.LINE_UNDERSCORE);
        INCLUDE_FILENAME_ATTRIBUTES.setEffectColor(new Color(0, 102, 204));
    }

    @Override
    public void annotate(@NotNull PsiElement element, @NotNull AnnotationHolder holder) {
        try {
            // Get the text content
            String text = element.getText();
            if (text == null || text.isEmpty()) {
                return;
            }

            // Find include statements in the text
            Matcher matcher = INCLUDE_PATTERN.matcher(text);
            while (matcher.find()) {
                int startOffset = element.getTextRange().getStartOffset();

                // Handle only the filename part ("file.ch")
                String filename = matcher.group(2);
                if (filename != null) {
                    // Find where the filename starts and ends
                    int fullMatchStart = matcher.start();

                    // Find quotes or brackets around the filename
                    int quotePos = text.indexOf('"', fullMatchStart);
                    int bracketPos = text.indexOf('<', fullMatchStart);

                    int filenameStart;
                    if (quotePos >= 0 && (bracketPos < 0 || quotePos < bracketPos)) {
                        filenameStart = quotePos + 1; // After the quote
                    } else if (bracketPos >= 0) {
                        filenameStart = bracketPos + 1; // After the bracket
                    } else {
                        // Shouldn't happen, but fallback
                        filenameStart = text.indexOf(filename, fullMatchStart);
                    }

                    if (filenameStart >= 0) {
                        int filenameEnd = filenameStart + filename.length();

                        TextRange filenameRange = new TextRange(
                                startOffset + filenameStart,
                                startOffset + filenameEnd);

                        // Always use blue highlighting for include files
                        holder.newSilentAnnotation(HighlightSeverity.INFORMATION)
                                .range(filenameRange)
                                .enforcedTextAttributes(INCLUDE_FILENAME_ATTRIBUTES)
                                .create();

                        HarbourLogger.log(COMPONENT, "Annotated include filename: " + filename);
                    }
                }
            }
        } catch (Exception e) {
            LOG.error("Error in HarbourIncludeAnnotator", e);
            HarbourLogger.log(COMPONENT, "Include Annotator Error: " + e.getMessage());
        }
    }
}
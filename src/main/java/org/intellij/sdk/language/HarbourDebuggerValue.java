package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.*;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Represents a variable value in the Harbour debugger.
 */
public class HarbourDebuggerValue extends XValue {
    private final String name;
    private final String type;
    private final String value;
    private final List<HarbourDebuggerValue> children;

    public HarbourDebuggerValue(String name, String type, String value) {
        this.name = name;
        this.type = type;
        this.value = value;
        this.children = new ArrayList<>();
    }

    public void addChild(HarbourDebuggerValue child) {
        children.add(child);
    }
    
    // Getter methods for debugging
    public String getName() { return name; }
    public String getType() { return type; }
    public String getValue() { return value; }

    @Override
    public void computePresentation(@NotNull XValueNode node, @NotNull XValuePlace place) {
        Icon icon = AllIcons.Debugger.Value;

        if ("N".equals(type) || "NUM".equals(type) || "NUMBER".equals(type)) {
            icon = AllIcons.Debugger.Db_primitive;
        } else if ("C".equals(type) || "CHAR".equals(type) || "CHARACTER".equals(type)) {
            icon = AllIcons.Debugger.Db_primitive;
        } else if ("L".equals(type) || "LOGICAL".equals(type)) {
            icon = AllIcons.Debugger.Db_primitive;
        } else if ("D".equals(type) || "DATE".equals(type)) {
            icon = AllIcons.Debugger.Db_primitive;
        } else if ("A".equals(type) || "ARRAY".equals(type)) {
            icon = AllIcons.Debugger.Db_array;
        } else if ("O".equals(type) || "OBJECT".equals(type)) {
            icon = AllIcons.Debugger.Value;
        }

        boolean hasChildren = !children.isEmpty();
        node.setPresentation(icon, type, value, hasChildren);
    }

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        if (!children.isEmpty()) {
            XValueChildrenList childrenList = new XValueChildrenList();
            for (HarbourDebuggerValue child : children) {
                childrenList.add(child.name, child);
            }
            node.addChildren(childrenList, true);
        } else {
            super.computeChildren(node);
        }
    }

    // TODO: Find a way to disable "Jump to Source" functionality
    // Currently not possible through XValue API
}
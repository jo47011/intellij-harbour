package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.xdebugger.frame.XCompositeNode;
import com.intellij.xdebugger.frame.XNamedValue;
import com.intellij.xdebugger.frame.XValueChildrenList;
import com.intellij.xdebugger.frame.XValueNode;
import com.intellij.xdebugger.frame.XValuePlace;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.List;

/**
 * Represents a collapsible group of unnamed local variable slots (Local_1, Local_2, etc.)
 * from the Harbour debugger. These are typically variables from the calling function's
 * scope that don't have explicit names in the current context.
 */
public class HarbourUnnamedSlotsGroup extends XNamedValue {
    private final List<HarbourDebuggerValue> stackSlots;

    public HarbourUnnamedSlotsGroup(@NotNull List<HarbourDebuggerValue> stackSlots) {
        super("Unnamed Stack Slots (" + stackSlots.size() + ")");
        this.stackSlots = new ArrayList<>(stackSlots);
    }

    @Override
    public void computePresentation(@NotNull XValueNode node, @NotNull XValuePlace place) {
        // Display as a folder icon with count
        node.setPresentation(
            AllIcons.Nodes.Folder,
            null,  // No type
            stackSlots.size() + " variable" + (stackSlots.size() != 1 ? "s" : ""),
            true   // Has children
        );
    }

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        XValueChildrenList children = new XValueChildrenList();

        // Add all stack slot variables to the group
        for (HarbourDebuggerValue value : stackSlots) {
            children.add(value.getName(), value);
        }

        node.addChildren(children, true);
    }

    @Nullable
    @Override
    public String getEvaluationExpression() {
        // No evaluation expression for this group
        return null;
    }

    @Override
    public boolean canNavigateToSource() {
        return false;
    }

    @Override
    public boolean canNavigateToTypeSource() {
        return false;
    }
}

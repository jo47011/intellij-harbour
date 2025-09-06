package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.*;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.Icon;
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
    private String scope;  // For arrays: store scope (LOCALS, STATICS, etc.)
    private String arrayName;  // For arrays: store the array variable name
    private int arraySize;  // For arrays: store the size
    private boolean isArrayElement = false;  // Flag to indicate if this is an array element
    private HarbourDebuggerBaseProcess debugProcess;  // Reference to debug process for array expansion
    private XCompositeNode pendingNode = null;  // Store node for async update
    private boolean childrenRequested = false;  // Track if we've already requested children

    public HarbourDebuggerValue(String name, String type, String value) {
        this.name = name;
        this.type = type;
        this.value = value;
        this.children = new ArrayList<>();
    }

    public void addChild(HarbourDebuggerValue child) {
        children.add(child);
    }
    
    public void clearChildren() {
        children.clear();
    }
    
    public List<HarbourDebuggerValue> getChildren() {
        return children;
    }
    
    // Set array info for expandable arrays
    public void setArrayInfo(String scope, String arrayName, int arraySize) {
        this.scope = scope;
        this.arrayName = arrayName;
        this.arraySize = arraySize;
    }
    
    // Set debug process reference for array element requests
    public void setDebugProcess(HarbourDebuggerBaseProcess debugProcess) {
        this.debugProcess = debugProcess;
    }
    
    // Mark this value as an array element
    public void setIsArrayElement(boolean isElement) {
        this.isArrayElement = isElement;
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

        // For arrays, indicate they have children even if not loaded yet
        boolean hasChildren = !children.isEmpty() || ("A".equals(type) && arraySize > 0);
        node.setPresentation(icon, type, value, hasChildren);
    }

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        // If this is an array with no children loaded yet, request them
        if ("A".equals(type) && arraySize > 0 && debugProcess != null) {
            if (!children.isEmpty()) {
                // Children already loaded, display them
                XValueChildrenList childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
                node.addChildren(childrenList, arraySize > children.size());
            } else if (!childrenRequested) {
                // Request array elements from the debugger
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Requesting array elements for " + name + " (scope: " + scope + ", size: " + arraySize + ")");
                
                // Store the node for later update
                pendingNode = node;
                childrenRequested = true;
                
                // Request elements (up to a reasonable limit)
                int maxElements = Math.min(arraySize, 100);  // Limit to 100 elements for performance
                
                if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                    HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                    // Request array elements - this will trigger an async response
                    remoteProcess.requestArrayElements(scope, arrayName, 1, maxElements);
                    
                    // Don't show loading message - just wait for real data
                    // This prevents the "loading" item from sticking around
                } else {
                    // No debug process available
                    super.computeChildren(node);
                }
            } else {
                // Already requested, wait for response
                // Don't show loading message - it will be replaced when data arrives
            }
        } else if (!children.isEmpty()) {
            // Non-array with children
            XValueChildrenList childrenList = new XValueChildrenList();
            for (HarbourDebuggerValue child : children) {
                childrenList.add(child.name, child);
            }
            node.addChildren(childrenList, true);
        } else {
            super.computeChildren(node);
        }
    }
    
    // Method to update children when array response arrives
    public void updateChildren() {
        if (pendingNode != null) {
            HarbourLogger.log("HarbourDebuggerValue", 
                "Updating array children for " + name + " with " + children.size() + " elements");
            
            if (!children.isEmpty()) {
                // Create new children list with actual array elements
                XValueChildrenList childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
                
                // Add all children at once
                // The 'true' parameter indicates all children have been added
                pendingNode.addChildren(childrenList, true);
            } else {
                // No children - mark as complete with empty list
                pendingNode.addChildren(XValueChildrenList.EMPTY, true);
            }
            
            pendingNode = null;  // Clear the reference
        }
    }

    // TODO: Find a way to disable "Jump to Source" functionality
    // Currently not possible through XValue API
}
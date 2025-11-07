package org.intellij.sdk.language;

import com.intellij.icons.AllIcons;
import com.intellij.openapi.application.ApplicationManager;
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
    private String scope;  // For arrays/hashes: store scope (LOCALS, STATICS, etc.)
    private String arrayName;  // For arrays: store the array variable name
    private int arraySize;  // For arrays: store the size
    private String hashName;  // For hashes: store the hash variable name
    private int hashSize;  // For hashes: store the size
    private String objectName;  // For objects: store the object variable name
    private boolean isArrayElement = false;  // Flag to indicate if this is an array element
    private boolean isHashElement = false;  // Flag to indicate if this is a hash element
    private boolean isObjectProperty = false;  // Flag to indicate if this is an object property
    private HarbourDebuggerBaseProcess debugProcess;  // Reference to debug process for array/hash expansion
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
    
    // Set hash info for expandable hashes
    public void setHashInfo(String scope, String hashName, int hashSize) {
        this.scope = scope;
        this.hashName = hashName;
        this.hashSize = hashSize;
    }
    
    // Mark this value as a hash element
    public void setIsHashElement(boolean isElement) {
        this.isHashElement = isElement;
    }
    
    // Set object info for expandable objects
    public void setObjectInfo(String scope, String objectName) {
        this.scope = scope;
        this.objectName = objectName;
    }
    
    // Mark this value as an object property
    public void setIsObjectProperty(boolean isProperty) {
        this.isObjectProperty = isProperty;
    }
    
    // Getter methods for debugging
    public String getName() { return name; }
    public String getType() { return type; }
    public String getValue() { return value; }

    @Override
    public void computePresentation(@NotNull XValueNode node, @NotNull XValuePlace place) {
        Icon icon = AllIcons.Debugger.Value;

        if ("N".equals(type) || "NUM".equals(type) || "NUMBER".equals(type)) {
            icon = AllIcons.Debugger.Value;  // Use generic value icon for primitives
        } else if ("C".equals(type) || "CHAR".equals(type) || "CHARACTER".equals(type)) {
            icon = AllIcons.Debugger.Value;  // Use generic value icon for primitives
        } else if ("L".equals(type) || "LOGICAL".equals(type)) {
            icon = AllIcons.Debugger.Value;  // Use generic value icon for primitives
        } else if ("D".equals(type) || "DATE".equals(type)) {
            icon = AllIcons.Debugger.Value;  // Use generic value icon for primitives
        } else if ("A".equals(type) || "ARRAY".equals(type)) {
            icon = AllIcons.Debugger.Value;  // Use generic value icon for arrays (Db_array might not exist)
        } else if ("O".equals(type) || "OBJECT".equals(type)) {
            icon = AllIcons.Debugger.Value;
        }

        // For arrays, hashes, and objects, indicate they have children even if not loaded yet
        boolean hasChildren = !children.isEmpty() || 
            ("A".equals(type) && arraySize > 0) || 
            ("H".equals(type) && hashSize > 0) ||
            ("O".equals(type));  // Objects are always expandable
        node.setPresentation(icon, type, value, hasChildren);
    }

    @Override
    public void computeChildren(@NotNull XCompositeNode node) {
        HarbourLogger.log("HarbourDebuggerValue", 
            "=== computeChildren called for " + name + " (type=" + type + ", arraySize=" + arraySize + 
            ", hashSize=" + hashSize + ", hasDebugProcess=" + (debugProcess != null) + ") ===");
        
        // If this is an array with no children loaded yet, request them
        if ("A".equals(type) && arraySize > 0 && debugProcess != null) {
            if (!children.isEmpty()) {
                // Children already loaded, display them
                XValueChildrenList childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
                node.addChildren(childrenList, arraySize > children.size());
            } else if (!childrenRequested || pendingNode == null) {
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
        } else if ("H".equals(type) && hashSize > 0 && debugProcess != null) {
            HarbourLogger.log("HarbourDebuggerValue", 
                "computeChildren called for hash " + name + " - children.isEmpty()=" + children.isEmpty() + 
                ", childrenRequested=" + childrenRequested + ", pendingNode=" + (pendingNode != null));
            
            // Handle hash expansion similar to arrays
            if (!children.isEmpty()) {
                // Children already loaded, display them
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Hash " + name + " already has " + children.size() + " children loaded, displaying them");
                XValueChildrenList childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
                node.addChildren(childrenList, hashSize > children.size());
            } else if (!childrenRequested || pendingNode == null) {
                // Request hash elements from the debugger
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Requesting hash elements for " + name + " (scope: " + scope + ", size: " + hashSize + ")");
                
                // Store the node for later update
                pendingNode = node;
                childrenRequested = true;
                
                if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                    HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                    // Request hash elements - this will trigger an async response
                    remoteProcess.requestHashElements(scope, hashName);
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "Hash request sent for " + name + ", waiting for response");
                    
                    // Don't show loading message - just wait for real data
                } else {
                    // No debug process available
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "No debug process available for hash " + name);
                    super.computeChildren(node);
                }
            } else {
                // Already requested, wait for response
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Hash " + name + " already requested, waiting for response (pendingNode=" + (pendingNode != null) + ")");
                
                // If we get here and pendingNode is null, it means the update was lost
                // This could happen if computeChildren is called again after update
                if (pendingNode == null && childrenRequested) {
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "WARNING: pendingNode is null but childrenRequested is true for " + name + 
                        " - update may have been lost. Storing new node.");
                    pendingNode = node;
                }
            }
        } else if ("O".equals(type) && debugProcess != null) {
            HarbourLogger.log("HarbourDebuggerValue", 
                "computeChildren called for object " + name + " - children.isEmpty()=" + children.isEmpty() + 
                ", childrenRequested=" + childrenRequested + ", pendingNode=" + (pendingNode != null));
            
            // Handle object expansion
            if (!children.isEmpty()) {
                // Children already loaded, display them
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Object " + name + " already has " + children.size() + " children loaded, displaying them");
                XValueChildrenList childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
                node.addChildren(childrenList, true);
            } else if (!childrenRequested || pendingNode == null) {
                // Request object properties from the debugger
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Requesting object properties for " + name + " (scope: " + scope + ")");
                
                // Store the node for later update
                pendingNode = node;
                childrenRequested = true;
                
                if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                    HarbourDebuggerRemoteProcess remoteProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                    // Request object properties - this will trigger an async response
                    remoteProcess.requestObjectProperties(scope, objectName);
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "Object request sent for " + name + ", waiting for response");
                    
                    // Don't show loading message - just wait for real data
                } else {
                    // No debug process available
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "No debug process available for object " + name);
                    super.computeChildren(node);
                }
            } else {
                // Already requested, wait for response
                HarbourLogger.log("HarbourDebuggerValue", 
                    "Object " + name + " already requested, waiting for response (pendingNode=" + (pendingNode != null) + ")");
                
                // If we get here and pendingNode is null, it means the update was lost
                if (pendingNode == null && childrenRequested) {
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "WARNING: pendingNode is null but childrenRequested is true for " + name + 
                        " - update may have been lost. Storing new node.");
                    pendingNode = node;
                }
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
    
    // Method to update children when array/hash response arrives
    // Transfer pending expansion state from another value (used when variables are refreshed)
    public void transferPendingState(HarbourDebuggerValue from) {
        if (from != null) {
            this.pendingNode = from.pendingNode;
            this.childrenRequested = from.childrenRequested;
            // Also transfer any already-loaded children
            if (!from.children.isEmpty()) {
                this.children.clear();
                this.children.addAll(from.children);
            }
            HarbourLogger.log("HarbourDebuggerValue",
                "Transferred pending state for " + name + " (pendingNode=" + (pendingNode != null) +
                ", childrenRequested=" + childrenRequested + ", children=" + children.size() + ")");
        }
    }

    public void updateChildren() {
        if (pendingNode != null) {
            // Determine if this is an array or hash for logging
            String childType = "H".equals(type) ? "hash" : "array";
            HarbourLogger.log("HarbourDebuggerValue", 
                "Updating " + childType + " children for " + name + " with " + children.size() + " elements");
            
            // Store the node reference locally to avoid race conditions
            final XCompositeNode nodeToUpdate = pendingNode;
            pendingNode = null;  // Clear immediately to prevent double updates
            
            // Create the children list before dispatching to EDT
            final XValueChildrenList childrenList;
            if (!children.isEmpty()) {
                childrenList = new XValueChildrenList();
                for (HarbourDebuggerValue child : children) {
                    childrenList.add(child.name, child);
                }
            } else {
                childrenList = XValueChildrenList.EMPTY;
            }
            
            // Update UI on the Event Dispatch Thread
            ApplicationManager.getApplication().invokeLater(() -> {
                try {
                    if (!children.isEmpty()) {
                        nodeToUpdate.addChildren(childrenList, true);
                        HarbourLogger.log("HarbourDebuggerValue", 
                            "Successfully updated " + childType + " children for " + name);
                    } else {
                        nodeToUpdate.addChildren(XValueChildrenList.EMPTY, true);
                        HarbourLogger.log("HarbourDebuggerValue", 
                            "Successfully updated empty " + childType + " children for " + name);
                    }
                } catch (Exception e) {
                    HarbourLogger.log("HarbourDebuggerValue", 
                        "Error updating children for " + name + ": " + e.getMessage());
                    // Reset state on error so it can be retried
                    childrenRequested = false;
                }
            });
        } else {
            HarbourLogger.log("HarbourDebuggerValue", 
                "updateChildren called but pendingNode is null for " + name);
        }
    }

    // TODO: Find a way to disable "Jump to Source" functionality
    // Currently not possible through XValue API
}
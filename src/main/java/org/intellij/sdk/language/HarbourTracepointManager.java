package org.intellij.sdk.language;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Manages tracepoints (data breakpoints) that stop execution when a variable's value changes.
 * Each tracepoint tracks a variable name and its last known value.
 */
public class HarbourTracepointManager {
    private static final String COMPONENT = "TracepointManager";

    // Map of variable name -> last known value (null if not yet captured)
    private final Map<String, String> tracepoints = new ConcurrentHashMap<>();

    // Reference to debug process for sending commands
    private final HarbourDebuggerRemoteProcess debugProcess;

    public HarbourTracepointManager(@NotNull HarbourDebuggerRemoteProcess debugProcess) {
        this.debugProcess = debugProcess;
        HarbourLogger.log(COMPONENT, "TracepointManager initialized");
    }

    /**
     * Add a tracepoint for a variable. The debugger will stop when this variable's value changes.
     * @param variableName The name of the variable to watch (e.g., "myVar", "ALIAS->Field")
     * @param currentValue The current value of the variable (for initial tracking)
     */
    public void addTracepoint(@NotNull String variableName, @Nullable String currentValue) {
        if (tracepoints.containsKey(variableName)) {
            HarbourLogger.log(COMPONENT, "Tracepoint already exists for: " + variableName);
            return;
        }

        tracepoints.put(variableName, currentValue);
        HarbourLogger.log(COMPONENT, "Added tracepoint for: " + variableName + " (initial value: " + currentValue + ")");

        // Send tracepoint to Harbour debugger
        sendTracepointCommand("+", variableName, currentValue);
    }

    /**
     * Remove a tracepoint for a variable.
     * @param variableName The name of the variable to stop watching
     */
    public void removeTracepoint(@NotNull String variableName) {
        if (!tracepoints.containsKey(variableName)) {
            HarbourLogger.log(COMPONENT, "No tracepoint exists for: " + variableName);
            return;
        }

        tracepoints.remove(variableName);
        HarbourLogger.log(COMPONENT, "Removed tracepoint for: " + variableName);

        // Send remove command to Harbour debugger
        sendTracepointCommand("-", variableName, null);
    }

    /**
     * Toggle a tracepoint on/off for a variable.
     * @param variableName The name of the variable
     * @param currentValue The current value (used if adding)
     * @return true if tracepoint is now active, false if removed
     */
    public boolean toggleTracepoint(@NotNull String variableName, @Nullable String currentValue) {
        if (hasTracepoint(variableName)) {
            removeTracepoint(variableName);
            return false;
        } else {
            addTracepoint(variableName, currentValue);
            return true;
        }
    }

    /**
     * Check if a variable has an active tracepoint.
     */
    public boolean hasTracepoint(@NotNull String variableName) {
        return tracepoints.containsKey(variableName);
    }

    /**
     * Update the stored value for a tracepoint (called when value changes are detected).
     */
    public void updateTracepointValue(@NotNull String variableName, @NotNull String newValue) {
        if (tracepoints.containsKey(variableName)) {
            tracepoints.put(variableName, newValue);
            HarbourLogger.log(COMPONENT, "Updated tracepoint value for " + variableName + ": " + newValue);
        }
    }

    /**
     * Get the last known value for a tracepoint.
     */
    @Nullable
    public String getTracepointValue(@NotNull String variableName) {
        return tracepoints.get(variableName);
    }

    /**
     * Get all active tracepoint variable names.
     */
    @NotNull
    public Set<String> getActiveTracepoints() {
        return tracepoints.keySet();
    }

    /**
     * Get the number of active tracepoints.
     */
    public int getTracepointCount() {
        return tracepoints.size();
    }

    /**
     * Check if there are any active tracepoints.
     */
    public boolean hasActiveTracepoints() {
        return !tracepoints.isEmpty();
    }

    /**
     * Clear all tracepoints.
     */
    public void clearAllTracepoints() {
        for (String varName : tracepoints.keySet()) {
            sendTracepointCommand("-", varName, null);
        }
        tracepoints.clear();
        HarbourLogger.log(COMPONENT, "Cleared all tracepoints");
    }

    /**
     * Handle a tracepoint hit notification from the Harbour debugger.
     * @param variableName The variable that changed
     * @param oldValue The previous value
     * @param newValue The new value
     */
    public void handleTracepointHit(@NotNull String variableName,
                                    @NotNull String oldValue,
                                    @NotNull String newValue) {
        HarbourLogger.log(COMPONENT, "Tracepoint hit: " + variableName +
            " changed from '" + oldValue + "' to '" + newValue + "'");

        // Update stored value
        updateTracepointValue(variableName, newValue);

        // The debugger will already be stopped at this point
        // The UI will show the changed variable
    }

    /**
     * Send a tracepoint command to the Harbour debugger.
     * Protocol: TRACEPOINT followed by +|-:variableName[:initialValue]
     */
    private void sendTracepointCommand(@NotNull String operation,
                                        @NotNull String variableName,
                                        @Nullable String initialValue) {
        debugProcess.sendCommand("TRACEPOINT");

        // Build command: +|-:variableName[:initialValue]
        StringBuilder cmd = new StringBuilder();
        cmd.append(operation).append(":").append(variableName);

        // Include initial value for add operations (helps Harbour side know current state)
        if ("+".equals(operation) && initialValue != null) {
            // Escape colons in value to avoid protocol conflicts
            String safeValue = initialValue.replace(":", ";");
            cmd.append(":").append(safeValue);
        }

        debugProcess.sendCommand(cmd.toString());
        HarbourLogger.log(COMPONENT, "Sent tracepoint command: TRACEPOINT " + cmd);
    }

    /**
     * Re-send all active tracepoints to the debugger (e.g., after reconnection).
     */
    public void resendAllTracepoints() {
        HarbourLogger.log(COMPONENT, "Resending " + tracepoints.size() + " tracepoints");
        for (Map.Entry<String, String> entry : tracepoints.entrySet()) {
            sendTracepointCommand("+", entry.getKey(), entry.getValue());
        }
    }
}

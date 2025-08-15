package org.intellij.sdk.language;

import com.intellij.openapi.Disposable;
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.util.containers.ContainerUtil;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Live database connection that provides real-time DBF workarea information during Harbour debugging.
 * This class bridges the debugging session with PyCharm's database tools.
 */
public class HarbourLiveDBFConnection implements Disposable {
    
    private static final Logger LOG = Logger.getInstance(HarbourLiveDBFConnection.class);
    
    private final Project project;
    private final HarbourDebuggerConnection debuggerConnection;
    private final Map<String, WorkareaInfo> workareas = new ConcurrentHashMap<>();
    private final List<WorkareaUpdateListener> listeners = new CopyOnWriteArrayList<>();
    private volatile boolean isActive = false;
    
    public HarbourLiveDBFConnection(@NotNull Project project, 
                                   @NotNull HarbourDebuggerConnection debuggerConnection) {
        this.project = project;
        this.debuggerConnection = debuggerConnection;
        
        HarbourLogger.log("HarbourLiveDBFConnection", "Created live DBF connection for project: " + project.getName());
    }
    
    /**
     * Start monitoring workarea information from the debugging session
     */
    public void startMonitoring() {
        if (isActive) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Already monitoring - startMonitoring() called but already active");
            return;
        }
        
        isActive = true;
        HarbourLogger.log("HarbourLiveDBFConnection", "*** STARTED MONITORING workarea information - isActive = true ***");
        
        // Request initial workarea information
        requestWorkareaUpdate();
    }
    
    /**
     * Stop monitoring workarea information
     * NOTE: Keep workareas data so it remains visible during breakpoints
     */
    public void stopMonitoring() {
        if (!isActive) {
            return;
        }
        
        isActive = false;
        // DON'T clear workareas - keep them visible during breakpoints!
        // workareas.clear(); // REMOVED - databases should persist during debugging
        HarbourLogger.log("HarbourLiveDBFConnection", "Stopped monitoring workarea information - keeping " + workareas.size() + " workareas visible");
        
        // DON'T notify listeners about disconnection - databases should remain visible
        // notifyListeners(); // REMOVED - keep UI showing databases
    }
    
    /**
     * Request updated workarea information from the debugger
     */
    public void requestWorkareaUpdate() {
        if (!isActive || !debuggerConnection.isConnected()) {
            return;
        }
        
        HarbourLogger.log("HarbourLiveDBFConnection", "Requesting workarea update");
        
        try {
            debuggerConnection.sendCommand("WORKAREAS");
        } catch (Exception e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Failed to request workarea update: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourLiveDBFConnection", e);
        }
    }
    
    /**
     * Process workarea information received from the debugger
     */
    public void processWorkareaMessage(@NotNull String message) {
        // GUARANTEED log - this should appear if method is called AT ALL
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "@@@ HarbourLiveDBFConnection.processWorkareaMessage() ENTRY - message: " + message);
        
        HarbourLogger.log("HarbourLiveDBFConnection", "*** processWorkareaMessage CALLED - isActive=" + isActive + ", message: " + message);
        
        if (!isActive) {
            HarbourLogger.log("HarbourLiveDBFConnection", "*** IGNORING message - NOT ACTIVE: " + message);
            HarbourLogger.log("HarbourDebuggerRemoteProcess", "@@@ HarbourLiveDBFConnection NOT ACTIVE - returning early");
            return;
        }
        
        HarbourLogger.log("HarbourLiveDBFConnection", "*** Processing workarea message: " + message);
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "@@@ HarbourLiveDBFConnection ACTIVE - processing message");
        
        try {
            if (message.startsWith("AREA:")) {
                parseWorkareaInfo(message);
            } else if (message.equals("END_WORKAREAS")) {
                // Workarea enumeration complete, notify listeners
                HarbourLogger.log("HarbourLiveDBFConnection", "Workarea enumeration complete, found " + workareas.size() + " workareas");
                notifyListeners();
            } else if (message.equals("WORKAREAS")) {
                // Clear existing workareas for fresh enumeration
                workareas.clear();
                HarbourLogger.log("HarbourLiveDBFConnection", "Starting workarea enumeration");
            }
        } catch (Exception e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Error processing workarea message: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourLiveDBFConnection", e);
        }
    }
    
    /**
     * Parse workarea information from debugger message
     * Format: AREA:Alias:Area:fCount:recno:reccount:scope:
     */
    private void parseWorkareaInfo(@NotNull String message) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "@@@ parseWorkareaInfo() parsing: " + message);
        
        // Split only on the first 6 colons to handle index expressions with colons
        String[] parts = message.split(":", 7);
        if (parts.length >= 7) {
            String alias = parts[1];
            int areaNumber = Integer.parseInt(parts[2]);
            int fieldCount = Integer.parseInt(parts[3]);
            int currentRecord = Integer.parseInt(parts[4]);
            int totalRecords = Integer.parseInt(parts[5]);
            String indexScope = parts[6]; // This can now contain colons
            
            WorkareaInfo workarea = new WorkareaInfo(
                alias, areaNumber, fieldCount, currentRecord, totalRecords, indexScope
            );
            
            workareas.put(alias, workarea);
            
            HarbourLogger.log("HarbourDebuggerRemoteProcess", 
                String.format("@@@ WORKAREA ADDED: %s (Area %d, %d/%d records, %d fields)", 
                    alias, areaNumber, currentRecord, totalRecords, fieldCount));
            
            HarbourLogger.log("HarbourLiveDBFConnection", 
                String.format("Updated workarea: %s (Area %d, %d/%d records, %d fields)", 
                    alias, areaNumber, currentRecord, totalRecords, fieldCount));
        }
    }
    
    /**
     * Get all currently open workareas
     */
    @NotNull
    public Collection<WorkareaInfo> getWorkareas() {
        return new ArrayList<>(workareas.values());
    }
    
    /**
     * Get workarea by alias
     */
    @Nullable
    public WorkareaInfo getWorkarea(@NotNull String alias) {
        return workareas.get(alias);
    }
    
    /**
     * Add listener for workarea updates
     */
    public void addWorkareaUpdateListener(@NotNull WorkareaUpdateListener listener) {
        listeners.add(listener);
    }
    
    /**
     * Remove listener for workarea updates
     */
    public void removeWorkareaUpdateListener(@NotNull WorkareaUpdateListener listener) {
        listeners.remove(listener);
    }
    
    /**
     * Notify all listeners about workarea updates
     */
    private void notifyListeners() {
        HarbourLogger.log("HarbourLiveDBFConnection", "*** notifyListeners() called - listeners.size=" + listeners.size() + ", workareas.size=" + workareas.size());
        ApplicationManager.getApplication().invokeLater(() -> {
            for (WorkareaUpdateListener listener : listeners) {
                try {
                    HarbourLogger.log("HarbourLiveDBFConnection", "*** Calling listener.onWorkareasUpdated() with " + workareas.size() + " workareas");
                    listener.onWorkareasUpdated(getWorkareas());
                } catch (Exception e) {
                    HarbourLogger.log("HarbourLiveDBFConnection", 
                        "Error notifying listener: " + e.getMessage());
                }
            }
        });
    }
    
    /**
     * Request detailed field information for a specific workarea
     */
    public void requestFieldInfo(@NotNull String alias) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            String command = "AREA" + workarea.getAreaNumber() + ":FIELDS";
            debuggerConnection.sendCommand(command);
        }
    }
    
    /**
     * Request current record data for a specific workarea
     */
    public void requestRecordData(@NotNull String alias) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            String command = "AREA" + workarea.getAreaNumber() + ":RECORD";
            debuggerConnection.sendCommand(command);
        }
    }
    
    /**
     * Request complete schema information for a specific workarea
     */
    public void requestSchemaInfo(@NotNull String alias) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            String command = "AREA" + workarea.getAreaNumber() + ":SCHEMA";
            debuggerConnection.sendCommand(command);
        }
    }
    
    /**
     * Process area-specific responses (FIELDS, RECORD, SCHEMA)
     */
    public void processAreaResponse(@NotNull String command, @NotNull String[] responseLines) {
        HarbourLogger.log("HarbourLiveDBFConnection", "Processing area response: " + command);
        
        if (!isActive) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Not active, ignoring area response");
            return;
        }
        
        // Parse command (e.g., "AREA1:FIELDS", "AREA2:RECORD")  
        String[] parts = command.split(":");
        if (parts.length < 2) return;
        
        int areaNumber = Integer.parseInt(parts[0].substring(4)); // Remove "AREA"
        String responseType = parts[1];
        
        // Find the workarea by area number
        WorkareaInfo workarea = null;
        for (WorkareaInfo wa : workareas.values()) {
            if (wa.getAreaNumber() == areaNumber) {
                workarea = wa;
                break;
            }
        }
        
        if (workarea == null) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Workarea " + areaNumber + " not found");
            return;
        }
        
        // Notify listeners with the response data
        HarbourLogger.log("HarbourLiveDBFConnection", 
            "Notifying listeners for " + responseType + " with " + responseLines.length + " lines of data");
        
        for (WorkareaUpdateListener listener : listeners) {
            if (listener instanceof DetailedDataListener) {
                DetailedDataListener detailedListener = (DetailedDataListener) listener;
                
                HarbourLogger.log("HarbourLiveDBFConnection", 
                    "Calling DetailedDataListener for " + responseType);
                
                switch (responseType) {
                    case "FIELDS":
                        detailedListener.onFieldsReceived(workarea, responseLines);
                        break;
                    case "RECORD":
                        detailedListener.onRecordDataReceived(workarea, responseLines);
                        break;
                    case "SCHEMA":
                        detailedListener.onSchemaInfoReceived(workarea, responseLines);
                        break;
                }
            } else {
                HarbourLogger.log("HarbourLiveDBFConnection", 
                    "Listener is not a DetailedDataListener: " + listener.getClass().getName());
            }
        }
    }
    
    /**
     * Extended interface for detailed data responses
     */
    public interface DetailedDataListener extends WorkareaUpdateListener {
        void onFieldsReceived(@NotNull WorkareaInfo workarea, @NotNull String[] fieldData);
        void onRecordDataReceived(@NotNull WorkareaInfo workarea, @NotNull String[] recordData);
        void onSchemaInfoReceived(@NotNull WorkareaInfo workarea, @NotNull String[] schemaData);
    }
    
    @Override
    public void dispose() {
        isActive = false;
        workareas.clear();
        listeners.clear();
        HarbourLogger.log("HarbourLiveDBFConnection", "Disposed live DBF connection - all data cleared");
        
        // Final notification of complete disconnection
        try {
            notifyListeners();
        } catch (Exception e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Error during final notification: " + e.getMessage());
        }
    }
    
    /**
     * Interface for listening to workarea updates
     */
    public interface WorkareaUpdateListener {
        void onWorkareasUpdated(@NotNull Collection<WorkareaInfo> workareas);
    }
    
    /**
     * Information about a single workarea
     */
    public static class WorkareaInfo {
        private final String alias;
        private final int areaNumber;
        private final int fieldCount;
        private final int currentRecord;
        private final int totalRecords;
        private final String indexScope;
        
        public WorkareaInfo(@NotNull String alias, int areaNumber, int fieldCount, 
                           int currentRecord, int totalRecords, @NotNull String indexScope) {
            this.alias = alias;
            this.areaNumber = areaNumber;
            this.fieldCount = fieldCount;
            this.currentRecord = currentRecord;
            this.totalRecords = totalRecords;
            this.indexScope = indexScope;
        }
        
        @NotNull
        public String getAlias() {
            return alias;
        }
        
        public int getAreaNumber() {
            return areaNumber;
        }
        
        public int getFieldCount() {
            return fieldCount;
        }
        
        public int getCurrentRecord() {
            return currentRecord;
        }
        
        public int getTotalRecords() {
            return totalRecords;
        }
        
        @NotNull
        public String getIndexScope() {
            return indexScope;
        }
        
        @Override
        public String toString() {
            return String.format("%s (Area %d): %d/%d records, %d fields", 
                alias, areaNumber, currentRecord, totalRecords, fieldCount);
        }
    }
}
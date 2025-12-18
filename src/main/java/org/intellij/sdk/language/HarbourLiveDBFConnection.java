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
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
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
    private volatile CountDownLatch workareaUpdateLatch = null;
    private volatile int currentSelectedArea = 0;  // Currently selected workarea in the program
    
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

        // DO NOT request initial workarea information on startup
        // Only refresh on debugger stop/step events
        // requestWorkareaUpdate(); // REMOVED - user feedback: only refresh when debugger stops
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
     * Request updated workarea information from the debugger SYNCHRONOUSLY.
     * Blocks until the workarea list is received or timeout occurs.
     *
     * @return Collection of current workareas, or current cached list if request fails
     */
    @NotNull
    public Collection<WorkareaInfo> requestWorkareaUpdateSync() {
        if (!isActive || !debuggerConnection.isConnected()) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Sync workarea request skipped - not active or not connected");
            return getWorkareas();
        }

        HarbourLogger.log("HarbourLiveDBFConnection", "Requesting SYNCHRONOUS workarea update");

        try {
            // Create latch to wait for END_WORKAREAS signal
            workareaUpdateLatch = new CountDownLatch(1);

            // Send the WORKAREAS command
            debuggerConnection.sendCommand("WORKAREAS");

            // Wait up to 3 seconds for the response
            boolean received = workareaUpdateLatch.await(3, TimeUnit.SECONDS);

            if (!received) {
                HarbourLogger.log("HarbourLiveDBFConnection", "Sync workarea update TIMEOUT - returning cached data");
            } else {
                HarbourLogger.log("HarbourLiveDBFConnection", "Sync workarea update COMPLETED with " + workareas.size() + " workareas");
            }

            return getWorkareas();

        } catch (InterruptedException e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Sync workarea update INTERRUPTED: " + e.getMessage());
            Thread.currentThread().interrupt();
            return getWorkareas();
        } catch (Exception e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Sync workarea update FAILED: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourLiveDBFConnection", e);
            return getWorkareas();
        } finally {
            workareaUpdateLatch = null;
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
            } else if (message.startsWith("CURRENT_AREA:")) {
                // Parse currently selected workarea in the program
                String[] parts = message.split(":");
                if (parts.length >= 2) {
                    currentSelectedArea = Integer.parseInt(parts[1].trim());
                    HarbourLogger.log("HarbourLiveDBFConnection",
                        "Program's current selected area: " + currentSelectedArea);
                }
            } else if (message.equals("END_WORKAREAS")) {
                // Workarea enumeration complete, notify listeners
                HarbourLogger.log("HarbourLiveDBFConnection", "Workarea enumeration complete, found " + workareas.size() + " workareas");
                notifyListeners();

                // Signal synchronous waiters that workareas are ready
                if (workareaUpdateLatch != null) {
                    workareaUpdateLatch.countDown();
                    HarbourLogger.log("HarbourLiveDBFConnection", "Signaled sync waiter - workareas ready");
                }
            } else if (message.equals("WORKAREAS")) {
                // Clear existing workareas for fresh enumeration
                workareas.clear();
                currentSelectedArea = 0;  // Reset on new enumeration
                HarbourLogger.log("HarbourLiveDBFConnection", "Starting workarea enumeration");
            }
        } catch (Exception e) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Error processing workarea message: " + e.getMessage());
            HarbourLogger.logStackTrace("HarbourLiveDBFConnection", e);
        }
    }
    
    /**
     * Parse workarea information from debugger message
     * Format: AREA:Alias:Area:fCount:recno:reccount:scope:eof:deleted:
     */
    private void parseWorkareaInfo(@NotNull String message) {
        HarbourLogger.log("HarbourDebuggerRemoteProcess", "@@@ parseWorkareaInfo() parsing: " + message);

        // Split only on the first 8 colons to handle index expressions with colons
        String[] parts = message.split(":", 9);
        if (parts.length >= 7) {
            String alias = parts[1];
            int areaNumber = Integer.parseInt(parts[2]);
            int fieldCount = Integer.parseInt(parts[3]);
            int currentRecord = Integer.parseInt(parts[4]);
            int totalRecords = Integer.parseInt(parts[5]);
            String indexScope = parts[6]; // This can now contain colons

            // Parse EOF and DELETED flags (new in protocol, backwards compatible)
            boolean eof = false;
            boolean deleted = false;
            if (parts.length >= 9) {
                eof = "T".equalsIgnoreCase(parts[7]);
                deleted = "T".equalsIgnoreCase(parts[8]);
            }

            WorkareaInfo workarea = new WorkareaInfo(
                alias, areaNumber, fieldCount, currentRecord, totalRecords, indexScope, eof, deleted
            );

            workareas.put(alias, workarea);

            HarbourLogger.log("HarbourDebuggerRemoteProcess",
                String.format("@@@ WORKAREA ADDED: %s (Area %d, %d/%d records, %d fields, EOF=%b, DEL=%b)",
                    alias, areaNumber, currentRecord, totalRecords, fieldCount, eof, deleted));

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
     * Get the currently selected workarea area number in the program
     */
    public int getCurrentSelectedArea() {
        return currentSelectedArea;
    }

    /**
     * Get the currently selected workarea info in the program (or null if none)
     */
    @Nullable
    public WorkareaInfo getCurrentSelectedWorkarea() {
        HarbourLogger.log("HarbourLiveDBFConnection",
            "getCurrentSelectedWorkarea() called - currentSelectedArea=" + currentSelectedArea +
            ", workareas.size=" + workareas.size());
        if (currentSelectedArea <= 0) {
            HarbourLogger.log("HarbourLiveDBFConnection",
                "getCurrentSelectedWorkarea() returning null - area <= 0");
            return null;
        }
        for (WorkareaInfo wa : workareas.values()) {
            HarbourLogger.log("HarbourLiveDBFConnection",
                "  Checking: " + wa.getAlias() + " (Area " + wa.getAreaNumber() + ")");
            if (wa.getAreaNumber() == currentSelectedArea) {
                HarbourLogger.log("HarbourLiveDBFConnection",
                    "  MATCH FOUND: " + wa.getAlias());
                return wa;
            }
        }
        HarbourLogger.log("HarbourLiveDBFConnection",
            "getCurrentSelectedWorkarea() returning null - no match found for area " + currentSelectedArea);
        return null;
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
            HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING COMMAND: " + command + " for alias: " + alias);
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
            HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING COMMAND: " + command + " for alias: " + alias);
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
            HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING COMMAND: " + command + " for alias: " + alias);
            debuggerConnection.sendCommand(command);
        }
    }
    
    /**
     * Navigate to the next record in a specific workarea
     */
    public void navigateToNextRecord(@NotNull String alias) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            String command = "AREA" + workarea.getAreaNumber() + ":NEXT";
            HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING NAVIGATION COMMAND: " + command + " for alias: " + alias);
            debuggerConnection.sendCommand(command);
            
            // Update the workarea info with the new record position
            if (workarea.getCurrentRecord() < workarea.getTotalRecords()) {
                WorkareaInfo updatedWorkarea = new WorkareaInfo(
                    workarea.getAlias(),
                    workarea.getAreaNumber(),
                    workarea.getFieldCount(),
                    workarea.getCurrentRecord() + 1,
                    workarea.getTotalRecords(),
                    workarea.getIndexScope()
                );
                workareas.put(alias, updatedWorkarea);
            }
        }
    }
    
    /**
     * Navigate to the previous record in a specific workarea
     */
    public void navigateToPreviousRecord(@NotNull String alias) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            String command = "AREA" + workarea.getAreaNumber() + ":PREVIOUS";
            HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING NAVIGATION COMMAND: " + command + " for alias: " + alias);
            debuggerConnection.sendCommand(command);
            
            // Update the workarea info with the new record position
            if (workarea.getCurrentRecord() > 1) {
                WorkareaInfo updatedWorkarea = new WorkareaInfo(
                    workarea.getAlias(),
                    workarea.getAreaNumber(),
                    workarea.getFieldCount(),
                    workarea.getCurrentRecord() - 1,
                    workarea.getTotalRecords(),
                    workarea.getIndexScope()
                );
                workareas.put(alias, updatedWorkarea);
            }
        }
    }
    
    /**
     * Navigate to a specific record number in a workarea
     */
    public void navigateToRecord(@NotNull String alias, int recordNumber) {
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null && debuggerConnection.isConnected()) {
            if (recordNumber > 0 && recordNumber <= workarea.getTotalRecords()) {
                String command = "AREA" + workarea.getAreaNumber() + ":GOTO:" + recordNumber;
                HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING GOTO COMMAND: " + command + " for alias: " + alias);
                debuggerConnection.sendCommand(command);
                
                // Update the workarea info with the new record position
                WorkareaInfo updatedWorkarea = new WorkareaInfo(
                    workarea.getAlias(),
                    workarea.getAreaNumber(),
                    workarea.getFieldCount(),
                    recordNumber,
                    workarea.getTotalRecords(),
                    workarea.getIndexScope()
                );
                workareas.put(alias, updatedWorkarea);
            }
        }
    }
    
    /**
     * Request multiple records for table grid view
     */
    public void requestRecords(@NotNull String alias, int startRecord, int count) {
        HarbourLogger.log("HarbourLiveDBFConnection", "*** requestRecords called - alias: " + alias + 
            ", start: " + startRecord + ", count: " + count);
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Found workarea for " + alias + 
                ", area number: " + workarea.getAreaNumber());
            if (debuggerConnection.isConnected()) {
                String command = "AREA" + workarea.getAreaNumber() + ":RECORDS:" + startRecord + ":" + count;
                HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING RECORDS COMMAND: " + command + " for alias: " + alias);
                debuggerConnection.sendCommand(command);
            } else {
                HarbourLogger.log("HarbourLiveDBFConnection", "ERROR: debuggerConnection is NOT connected!");
            }
        } else {
            HarbourLogger.log("HarbourLiveDBFConnection", "ERROR: No workarea found for alias: " + alias);
        }
    }
    
    /**
     * Request index information for a workarea
     */
    public void requestIndexInfo(@NotNull String alias) {
        HarbourLogger.log("HarbourLiveDBFConnection", "*** requestIndexInfo called for alias: " + alias);
        WorkareaInfo workarea = workareas.get(alias);
        if (workarea != null) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Found workarea for " + alias + 
                ", area number: " + workarea.getAreaNumber());
            if (debuggerConnection.isConnected()) {
                String command = "AREA" + workarea.getAreaNumber() + ":INDEXES";
                HarbourLogger.log("HarbourLiveDBFConnection", ">>> SENDING INDEXES COMMAND: " + command + " for alias: " + alias);
                debuggerConnection.sendCommand(command);
            } else {
                HarbourLogger.log("HarbourLiveDBFConnection", "ERROR: debuggerConnection is NOT connected!");
            }
        } else {
            HarbourLogger.log("HarbourLiveDBFConnection", "ERROR: No workarea found for alias: " + alias);
        }
    }
    
    /**
     * Process area-specific responses (FIELDS, RECORD, SCHEMA)
     */
    public void processAreaResponse(@NotNull String command, @NotNull String[] responseLines) {
        HarbourLogger.log("HarbourLiveDBFConnection", "Processing area response: " + command + " with " + responseLines.length + " lines");
        
        if (!isActive) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Not active, ignoring area response");
            return;
        }
        
        // Parse command (e.g., "AREA1:FIELDS", "AREA2:RECORD")  
        String[] parts = command.split(":");
        if (parts.length < 2) {
            HarbourLogger.log("HarbourLiveDBFConnection", "Invalid command format: " + command);
            return;
        }
        
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
            HarbourLogger.log("HarbourLiveDBFConnection", 
                "WARNING: Workarea " + areaNumber + " not found in map. Available workareas: " + 
                workareas.keySet() + " (total: " + workareas.size() + ")");
            
            // Try to create a temporary workarea info for display
            // This can happen if we receive data before workarea enumeration
            workarea = new WorkareaInfo("AREA" + areaNumber, areaNumber, 0, 0, 0, "");
            HarbourLogger.log("HarbourLiveDBFConnection", 
                "Created temporary workarea info for area " + areaNumber);
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
                    case "RECORDS":
                        detailedListener.onRecordsReceived(workarea, responseLines);
                        break;
                    case "INDEXES":
                        detailedListener.onIndexesReceived(workarea, responseLines);
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
        void onRecordsReceived(@NotNull WorkareaInfo workarea, @NotNull String[] recordsData);
        void onIndexesReceived(@NotNull WorkareaInfo workarea, @NotNull String[] indexesData);
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
        private final boolean eof;
        private final boolean deleted;

        public WorkareaInfo(@NotNull String alias, int areaNumber, int fieldCount,
                           int currentRecord, int totalRecords, @NotNull String indexScope) {
            this(alias, areaNumber, fieldCount, currentRecord, totalRecords, indexScope, false, false);
        }

        public WorkareaInfo(@NotNull String alias, int areaNumber, int fieldCount,
                           int currentRecord, int totalRecords, @NotNull String indexScope,
                           boolean eof, boolean deleted) {
            this.alias = alias;
            this.areaNumber = areaNumber;
            this.fieldCount = fieldCount;
            this.currentRecord = currentRecord;
            this.totalRecords = totalRecords;
            this.indexScope = indexScope;
            this.eof = eof;
            this.deleted = deleted;
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

        public boolean isEof() {
            return eof;
        }

        public boolean isDeleted() {
            return deleted;
        }

        @Override
        public String toString() {
            StringBuilder sb = new StringBuilder();
            sb.append(String.format("%s (Area %d): %d/%d records, %d fields",
                alias, areaNumber, currentRecord, totalRecords, fieldCount));
            if (eof) {
                sb.append(" [EOF]");
            }
            if (deleted) {
                sb.append(" [DEL]");
            }
            return sb.toString();
        }
    }
}
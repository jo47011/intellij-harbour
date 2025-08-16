package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.wm.ToolWindow;
import com.intellij.openapi.wm.ToolWindowFactory;
import com.intellij.ui.components.JBScrollPane;
import com.intellij.ui.content.Content;
import com.intellij.ui.content.ContentFactory;
import com.intellij.ui.table.JBTable;
import com.intellij.ui.treeStructure.Tree;
import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.XDebuggerManagerListener;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;
import javax.swing.table.AbstractTableModel;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.DefaultTreeModel;
import javax.swing.tree.TreePath;
import java.awt.*;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/**
 * Tool window for displaying live DBF workarea information during debugging.
 * This tool window integrates with PyCharm's database tools to provide real-time database inspection.
 * 
 * KEY BREAKPOINT LOCATIONS FOR DEBUGGING:
 * 
 * 1. CLICK HANDLING (when user clicks on tree items):
 *    - Line 262: onWorkareaSelected() - Main click handler entry
 *    - Line 295: Showing cached fields data
 *    - Line 301: Requesting new fields data (no cache)
 *    - Line 308: Showing cached record data  
 *    - Line 314: Requesting new record data (no cache)
 *    - Line 321: Showing cached schema data
 *    - Line 327: Requesting new schema data (no cache)
 *    - Line 346: showWorkareaDetails() - clicking on workarea name
 * 
 * 2. DATA RECEPTION (when data arrives from debugger):
 *    - Line 450: onFieldsReceived() - Field data arrives
 *    - Line 458: Check if we're waiting for this field data
 *    - Line 470: Display field data
 *    - Line 506: onRecordDataReceived() - Record data arrives  
 *    - Line 519: Check if we're waiting for this record data
 *    - Line 531: Display record data
 *    - Line 620: onSchemaInfoReceived() - Schema data arrives
 *    - Line 628: Check if we're waiting for this schema data
 *    - Line 640: Display schema data
 * 
 * 3. DISPLAY METHODS (actually showing data in table):
 *    - Line 478: displayFieldData() - Shows field structure
 *    - Line 502: Field count logged
 *    - Line 539: displayRecordData() - Shows current record
 *    - Line 585: Record value count logged
 *    - Line 664: displaySchemaData() - Shows schema info
 *    - Line 707: Schema item count logged
 * 
 * 4. STATE VARIABLES (check these in debugger):
 *    - waitingForWorkarea: Which workarea we're waiting for
 *    - waitingForDataType: What type (Fields/Record/Schema)
 *    - dataCache: HashMap storing cached data per workarea
 */
public class HarbourDBFToolWindow implements ToolWindowFactory {
    
    @Override
    public void createToolWindowContent(@NotNull Project project, @NotNull ToolWindow toolWindow) {
        HarbourDBFToolWindowContent content = new HarbourDBFToolWindowContent(project);
        Content toolContent = ContentFactory.getInstance().createContent(
            content.getContent(), "Harbour DBF", false);
        toolWindow.getContentManager().addContent(toolContent);
    }
    
    /**
     * Content panel for the DBF tool window
     */
    private static class HarbourDBFToolWindowContent implements HarbourLiveDBFConnection.DetailedDataListener {
        
        private final Project project;
        private final JPanel mainPanel;
        private final Tree workareaTree;
        private final JBTable detailsTable;
        private final DefaultTreeModel treeModel;
        private final DetailsTableModel tableModel;
        private final JLabel statusLabel;
        
        private HarbourLiveDBFConnection liveConnection;
        
        // Cache for storing received data per workarea
        private static class WorkareaCache {
            String[] fieldData = null;
            String[] recordData = null;
            String[] schemaData = null;
            
            // Limit cache size to prevent memory issues
            void setFieldData(String[] data) {
                // Limit to first 100 fields to prevent memory issues
                if (data != null && data.length > 100) {
                    fieldData = java.util.Arrays.copyOf(data, 100);
                } else {
                    fieldData = data;
                }
            }
            
            void setRecordData(String[] data) {
                // Limit to first 200 record values to prevent memory issues
                if (data != null && data.length > 200) {
                    recordData = java.util.Arrays.copyOf(data, 200);
                } else {
                    recordData = data;
                }
            }
            
            void setSchemaData(String[] data) {
                // Schema is usually small, but limit just in case
                if (data != null && data.length > 50) {
                    schemaData = java.util.Arrays.copyOf(data, 50);
                } else {
                    schemaData = data;
                }
            }
        }
        private final java.util.Map<String, WorkareaCache> dataCache = new java.util.HashMap<>();
        
        // Track what we're currently waiting for
        private String waitingForWorkarea = null;
        private String waitingForDataType = null;
        
        public HarbourDBFToolWindowContent(@NotNull Project project) {
            this.project = project;
            
            // Create UI components
            mainPanel = new JPanel(new BorderLayout());
            
            // Listen for debug session changes
            setupDebugSessionListener();
            
            // Create workarea tree
            DefaultMutableTreeNode rootNode = new DefaultMutableTreeNode("Database Workareas");
            treeModel = new DefaultTreeModel(rootNode);
            workareaTree = new Tree(treeModel);
            workareaTree.setRootVisible(true);
            workareaTree.addTreeSelectionListener(e -> onWorkareaSelected());
            
            // Create details table
            tableModel = new DetailsTableModel();
            detailsTable = new JBTable(tableModel);
            detailsTable.setAutoResizeMode(JTable.AUTO_RESIZE_ALL_COLUMNS);
            
            // Create status label
            statusLabel = new JLabel("No debugging session active");
            statusLabel.setBorder(BorderFactory.createEmptyBorder(5, 5, 5, 5));
            
            // Create refresh button
            JButton refreshButton = new JButton("Refresh Workareas");
            refreshButton.addActionListener(e -> refreshWorkareas());
            
            // Create toolbar
            JPanel toolbar = new JPanel(new BorderLayout());
            toolbar.add(refreshButton, BorderLayout.EAST);
            
            // Layout components
            JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT);
            splitPane.setLeftComponent(new JBScrollPane(workareaTree));
            splitPane.setRightComponent(new JBScrollPane(detailsTable));
            splitPane.setDividerLocation(250);
            
            mainPanel.add(toolbar, BorderLayout.NORTH);
            mainPanel.add(splitPane, BorderLayout.CENTER);
            mainPanel.add(statusLabel, BorderLayout.SOUTH);
            
            // Initialize with empty state
            updateStatus("No debugging session active");
            
            // Check for existing debug sessions AFTER all UI components are created
            checkForExistingDebugSession();
            
            HarbourLogger.log("HarbourDBFToolWindow", "Created DBF tool window for project: " + project.getName());
        }
        
        public JComponent getContent() {
            return mainPanel;
        }
        
        /**
         * Connect to a live debugging session
         */
        public void connectToDebuggingSession(@NotNull HarbourLiveDBFConnection connection) {
            if (liveConnection != null) {
                liveConnection.removeWorkareaUpdateListener(this);
            }
            
            // Clear cache when connecting to new session
            dataCache.clear();
            waitingForWorkarea = null;
            waitingForDataType = null;
            
            this.liveConnection = connection;
            connection.addWorkareaUpdateListener(this);
            
            updateStatus("Connected to debugging session");
            
            HarbourLogger.log("HarbourDBFToolWindow", "Connected to live debugging session, cache cleared");
        }
        
        /**
         * Disconnect from debugging session
         */
        public void disconnectFromDebuggingSession() {
            if (liveConnection != null) {
                liveConnection.removeWorkareaUpdateListener(this);
                liveConnection = null;
            }
            
            // Clear UI
            DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
            rootNode.removeAllChildren();
            treeModel.reload();
            tableModel.clearData();
            
            // Clear cache and waiting state
            dataCache.clear();
            waitingForWorkarea = null;
            waitingForDataType = null;
            
            updateStatus("Debugging session disconnected");
            
            HarbourLogger.log("HarbourDBFToolWindow", "Disconnected from debugging session");
        }
        
        @Override
        public void onWorkareasUpdated(@NotNull Collection<HarbourLiveDBFConnection.WorkareaInfo> workareas) {
            HarbourLogger.log("HarbourDBFToolWindow", "*** onWorkareasUpdated() called with " + workareas.size() + " workareas");
            ApplicationManager.getApplication().invokeLater(() -> {
                HarbourLogger.log("HarbourDBFToolWindow", "*** About to call updateWorkareaTree()");
                updateWorkareaTree(workareas);
                if (workareas.isEmpty()) {
                    updateStatus("Connected - No database files are currently open");
                } else {
                    updateStatus(String.format("Connected - %d workarea(s) open", workareas.size()));
                    HarbourLogger.log("HarbourDBFToolWindow", "*** Updated status to show " + workareas.size() + " workarea(s)");
                }
            });
        }
        
        /**
         * Update the workarea tree with new data
         */
        private void updateWorkareaTree(@NotNull Collection<HarbourLiveDBFConnection.WorkareaInfo> workareas) {
            // Save expansion state
            java.util.Set<String> expandedWorkareas = new java.util.HashSet<>();
            DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
            for (int i = 0; i < rootNode.getChildCount(); i++) {
                DefaultMutableTreeNode child = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                TreePath path = new TreePath(child.getPath());
                if (workareaTree.isExpanded(path)) {
                    if (child.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                        HarbourLiveDBFConnection.WorkareaInfo info = (HarbourLiveDBFConnection.WorkareaInfo) child.getUserObject();
                        expandedWorkareas.add(info.getAlias());
                    }
                }
            }
            
            rootNode.removeAllChildren();
            
            for (HarbourLiveDBFConnection.WorkareaInfo workarea : workareas) {
                DefaultMutableTreeNode workareaNode = new DefaultMutableTreeNode(workarea);
                rootNode.add(workareaNode);
                
                // Add child nodes for different information types
                workareaNode.add(new DefaultMutableTreeNode("Fields (" + workarea.getFieldCount() + ")"));
                workareaNode.add(new DefaultMutableTreeNode("Current Record"));
                workareaNode.add(new DefaultMutableTreeNode("Schema Info"));
            }
            
            treeModel.reload();
            
            // Expand root node
            workareaTree.expandPath(new TreePath(rootNode.getPath()));
            
            // Restore expansion state
            for (int i = 0; i < rootNode.getChildCount(); i++) {
                DefaultMutableTreeNode child = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                if (child.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                    HarbourLiveDBFConnection.WorkareaInfo info = (HarbourLiveDBFConnection.WorkareaInfo) child.getUserObject();
                    if (expandedWorkareas.contains(info.getAlias())) {
                        workareaTree.expandPath(new TreePath(child.getPath()));
                    }
                }
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "Updated workarea tree with " + workareas.size() + " workareas");
        }
        
        /**
         * Handle workarea selection in tree
         */
        private void onWorkareaSelected() {
            TreePath selectionPath = workareaTree.getSelectionPath();
            if (selectionPath == null || liveConnection == null) {
                return;
            }
            
            DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
            
            // Check if a workarea info node is selected
            if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                HarbourLiveDBFConnection.WorkareaInfo workarea = 
                    (HarbourLiveDBFConnection.WorkareaInfo) selectedNode.getUserObject();
                    
                showWorkareaDetails(workarea);
            }
            
            // Check if a specific information type is selected
            else if (selectedNode.getParent() != null) {
                DefaultMutableTreeNode parentNode = (DefaultMutableTreeNode) selectedNode.getParent();
                if (parentNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                    HarbourLiveDBFConnection.WorkareaInfo workarea = 
                        (HarbourLiveDBFConnection.WorkareaInfo) parentNode.getUserObject();
                    String nodeText = selectedNode.getUserObject().toString();
                    String alias = workarea.getAlias();
                    
                    // Get or create cache for this workarea
                    WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
                    
                    if (nodeText.startsWith("Fields")) {
                        if (cache.fieldData != null) {
                            // Show cached data immediately
                            displayFieldData(workarea, cache.fieldData);
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 267] Showing cached fields for " + alias);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Fields");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Fields";
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 273] Requesting fields for " + alias + ", waiting state set");
                            liveConnection.requestFieldInfo(alias);
                        }
                    } else if (nodeText.equals("Current Record")) {
                        if (cache.recordData != null) {
                            // Show cached data immediately
                            displayRecordData(workarea, cache.recordData);
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 280] Showing cached record for " + alias);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Current Record");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Record";
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 286] Requesting record for " + alias + ", waiting state set");
                            liveConnection.requestRecordData(alias);
                        }
                    } else if (nodeText.equals("Schema Info")) {
                        if (cache.schemaData != null) {
                            // Show cached data immediately
                            displaySchemaData(workarea, cache.schemaData);
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 293] Showing cached schema for " + alias);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Schema Info");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Schema";
                            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 299] Requesting schema for " + alias + ", waiting state set");
                            liveConnection.requestSchemaInfo(alias);
                        }
                    }
                }
            }
        }
        
        /**
         * Show basic workarea details in the details table - DEFAULT: show current record data
         */
        private void showWorkareaDetails(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea) {
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            
            // Default behavior: show current record data when clicking on table name
            if (cache.recordData != null) {
                // Show cached data immediately
                displayRecordData(workarea, cache.recordData);
                HarbourLogger.log("HarbourDBFToolWindow", "[LINE 318] Showing cached record for workarea: " + alias);
            } else {
                // Show loading message and request data
                showLoadingMessage("Current Record");
                waitingForWorkarea = alias;
                waitingForDataType = "Record";
                HarbourLogger.log("HarbourDBFToolWindow", "[LINE 324] Requesting record for workarea: " + alias + ", waiting state set");
                liveConnection.requestRecordData(alias);
            }
        }
        
        /**
         * Show loading message in the details table
         */
        private void showLoadingMessage(@NotNull String dataType) {
            List<String[]> data = new ArrayList<>();
            data.add(new String[]{"Loading " + dataType + "...", ""});
            data.add(new String[]{"", ""});
            data.add(new String[]{"Collecting data. Please wait...", ""});
            tableModel.setData(data);
        }
        
        /**
         * Update status label
         */
        private void updateStatus(@NotNull String status) {
            statusLabel.setText(status);
        }
        
        /**
         * Manually refresh workarea information
         */
        private void refreshWorkareas() {
            if (liveConnection != null) {
                // Don't clear cache - keep existing data until new data arrives
                // This prevents data loss when switching panels
                waitingForWorkarea = null;
                waitingForDataType = null;
                liveConnection.requestWorkareaUpdate();
                updateStatus("Refreshing workarea information...");
            } else {
                updateStatus("No active debugging session to refresh");
            }
        }
        
        /**
         * Set up listener to automatically connect to debugging sessions
         */
        private void setupDebugSessionListener() {
            project.getMessageBus().connect().subscribe(XDebuggerManager.TOPIC, new XDebuggerManagerListener() {
                @Override
                public void processStarted(@NotNull XDebugProcess debugProcess) {
                    // Check if this is a Harbour debug process
                    if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                        HarbourDebuggerRemoteProcess harbourProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                        HarbourLiveDBFConnection dbfConnection = harbourProcess.getLiveDBFConnection();
                        if (dbfConnection != null) {
                            connectToDebuggingSession(dbfConnection);
                            HarbourLogger.log("HarbourDBFToolWindow", "Auto-connected to Harbour debugging session");
                        }
                    }
                }
                
                @Override
                public void processStopped(@NotNull XDebugProcess debugProcess) {
                    // Check if this was a Harbour debug process
                    if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                        disconnectFromDebuggingSession();
                        HarbourLogger.log("HarbourDBFToolWindow", "Auto-disconnected from Harbour debugging session");
                    }
                }
            });
        }
        
        /**
         * Check for existing debugging sessions when tool window is created
         */
        private void checkForExistingDebugSession() {
            XDebuggerManager debuggerManager = XDebuggerManager.getInstance(project);
            XDebugSession currentSession = debuggerManager.getCurrentSession();
            
            if (currentSession != null) {
                XDebugProcess debugProcess = currentSession.getDebugProcess();
                if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                    HarbourDebuggerRemoteProcess harbourProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                    HarbourLiveDBFConnection dbfConnection = harbourProcess.getLiveDBFConnection();
                    if (dbfConnection != null) {
                        connectToDebuggingSession(dbfConnection);
                        HarbourLogger.log("HarbourDBFToolWindow", "Connected to existing Harbour debugging session");
                    }
                }
            }
        }
        
        // Implement DetailedDataListener interface methods
        
        @Override
        public void onFieldsReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] fieldData) {
            // Cache the data
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            cache.setFieldData(fieldData);
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 424] onFieldsReceived for " + alias + 
                ", waiting for: " + waitingForWorkarea + "/" + waitingForDataType);
            
            // Display if we're waiting for this data OR if it's currently selected
            ApplicationManager.getApplication().invokeLater(() -> {
                boolean shouldDisplay = false;
                
                // Check if we're waiting for this specific data
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Fields".equals(waitingForDataType)) {
                    shouldDisplay = true;
                    // Clear waiting state
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
                // Or if it's currently selected
                else if (isCurrentlySelected(alias, "Fields")) {
                    shouldDisplay = true;
                }
                
                if (shouldDisplay) {
                    displayFieldData(workarea, fieldData);
                }
            });
        }
        
        /**
         * Display field data in the table
         */
        private void displayFieldData(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] fieldData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayFieldData(workarea, fieldData));
                return;
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 478] displayFieldData called for " + workarea.getAlias() + 
                " with " + fieldData.length + " lines");
            
            List<String[]> data = new ArrayList<>();
            data.add(new String[]{"Field Information for " + workarea.getAlias(), ""});
            data.add(new String[]{"", ""});
            
            int fieldCount = 0;
            for (String fieldLine : fieldData) {
                // Removed verbose logging to reduce memory usage
                if (fieldLine.startsWith("FIELD:")) {
                    // Parse FIELD:name:type:length:decimals:
                    String[] parts = fieldLine.split(":");
                    if (parts.length >= 5) {
                        String fieldName = parts[1];
                        String fieldType = parts[2];
                        String fieldLength = parts[3];
                        String fieldDecimals = parts[4];
                        
                        data.add(new String[]{fieldName, fieldType + "(" + fieldLength + 
                            (Integer.parseInt(fieldDecimals) > 0 ? "," + fieldDecimals : "") + ")"});
                        fieldCount++;
                    }
                }
            }
            
            tableModel.setData(data);
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 502] Displayed " + fieldCount + " fields for " + workarea.getAlias());
        }
        
        @Override 
        public void onRecordDataReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordData) {
            HarbourLogger.log("HarbourDBFToolWindow", 
                "[LINE 458] onRecordDataReceived called for " + workarea.getAlias() + " with " + recordData.length + " lines" +
                ", waiting for: " + waitingForWorkarea + "/" + waitingForDataType);
            
            // Cache the data
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            cache.setRecordData(recordData);
            
            // Display if we're waiting for this data OR if it's currently selected
            ApplicationManager.getApplication().invokeLater(() -> {
                boolean shouldDisplay = false;
                
                // Check if we're waiting for this specific data
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Record".equals(waitingForDataType)) {
                    shouldDisplay = true;
                    // Clear waiting state
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
                // Or if it's currently selected
                else if (isCurrentlySelected(alias, "Record")) {
                    shouldDisplay = true;
                }
                
                if (shouldDisplay) {
                    displayRecordData(workarea, recordData);
                }
            });
        }
        
        /**
         * Display record data in the table
         */
        private void displayRecordData(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayRecordData(workarea, recordData));
                return;
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 539] displayRecordData called for " + workarea.getAlias() + 
                " with " + recordData.length + " lines");
            
            List<String[]> data = new ArrayList<>();
            data.add(new String[]{"Current Record Data for " + workarea.getAlias(), ""});
            data.add(new String[]{"Record " + workarea.getCurrentRecord() + " of " + workarea.getTotalRecords(), ""});
            data.add(new String[]{"", ""});
            
            int valueCount = 0;
            for (String dataLine : recordData) {
                // Removed verbose logging to reduce memory usage
                
                // Accept both DATA: and VALUE: prefixes (Harbour sends VALUE:)
                if (dataLine.startsWith("DATA:") || dataLine.startsWith("VALUE:")) {
                    // Parse VALUE:fieldname:type:value: format
                    // Find the positions of the colons to handle values that might contain colons
                    int firstColon = dataLine.indexOf(':');
                    int secondColon = dataLine.indexOf(':', firstColon + 1);
                    int thirdColon = dataLine.indexOf(':', secondColon + 1);
                    
                    if (firstColon > 0 && secondColon > 0 && thirdColon > 0) {
                        String fieldName = dataLine.substring(firstColon + 1, secondColon);
                        String fieldType = dataLine.substring(secondColon + 1, thirdColon);
                        String fieldValue = dataLine.substring(thirdColon + 1);
                        
                        // Clean up the value:
                        // 1. Remove trailing colon if present
                        if (fieldValue.endsWith(":")) {
                            fieldValue = fieldValue.substring(0, fieldValue.length() - 1);
                        }
                        
                        // 2. For string values (type C or M), remove surrounding quotes
                        if ((fieldType.equals("C") || fieldType.equals("M")) && 
                            fieldValue.startsWith("\"") && fieldValue.endsWith("\"")) {
                            fieldValue = fieldValue.substring(1, fieldValue.length() - 1);
                        }
                        
                        // 3. Trim the value
                        fieldValue = fieldValue.trim();
                        
                        data.add(new String[]{fieldName, fieldValue});
                        valueCount++;
                    }
                }
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 585] Added " + valueCount + " field values to display");
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 586] Total rows in data list: " + data.size());
            tableModel.setData(data);
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 588] Set data in table model for " + workarea.getAlias() + 
                ", table now has " + tableModel.getRowCount() + " rows");
        }
        
        @Override
        public void onSchemaInfoReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] schemaData) {
            // Cache the data
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            cache.setSchemaData(schemaData);
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 493] onSchemaInfoReceived for " + alias + 
                ", waiting for: " + waitingForWorkarea + "/" + waitingForDataType);
            
            // Display if we're waiting for this data OR if it's currently selected
            ApplicationManager.getApplication().invokeLater(() -> {
                boolean shouldDisplay = false;
                
                // Check if we're waiting for this specific data
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Schema".equals(waitingForDataType)) {
                    shouldDisplay = true;
                    // Clear waiting state
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
                // Or if it's currently selected
                else if (isCurrentlySelected(alias, "Schema")) {
                    shouldDisplay = true;
                }
                
                if (shouldDisplay) {
                    displaySchemaData(workarea, schemaData);
                }
            });
        }
        
        /**
         * Check if the given workarea and data type is currently selected
         */
        private boolean isCurrentlySelected(@NotNull String alias, @NotNull String dataType) {
            TreePath selectionPath = workareaTree.getSelectionPath();
            if (selectionPath == null) {
                return false;
            }
            
            DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
            
            // Check direct workarea selection (shows record by default)
            if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                HarbourLiveDBFConnection.WorkareaInfo workarea = 
                    (HarbourLiveDBFConnection.WorkareaInfo) selectedNode.getUserObject();
                return workarea.getAlias().equals(alias) && dataType.equals("Record");
            }
            
            // Check specific data type selection
            if (selectedNode.getParent() != null) {
                DefaultMutableTreeNode parentNode = (DefaultMutableTreeNode) selectedNode.getParent();
                if (parentNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                    HarbourLiveDBFConnection.WorkareaInfo workarea = 
                        (HarbourLiveDBFConnection.WorkareaInfo) parentNode.getUserObject();
                    
                    if (!workarea.getAlias().equals(alias)) {
                        return false;
                    }
                    
                    String nodeText = selectedNode.getUserObject().toString();
                    if (dataType.equals("Fields") && nodeText.startsWith("Fields")) {
                        return true;
                    } else if (dataType.equals("Record") && nodeText.equals("Current Record")) {
                        return true;
                    } else if (dataType.equals("Schema") && nodeText.equals("Schema Info")) {
                        return true;
                    }
                }
            }
            
            return false;
        }
        
        /**
         * Display schema data in the table
         */
        private void displaySchemaData(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] schemaData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displaySchemaData(workarea, schemaData));
                return;
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 664] displaySchemaData called for " + workarea.getAlias() + 
                " with " + schemaData.length + " lines");
            
            List<String[]> data = new ArrayList<>();
            data.add(new String[]{"Schema Information for " + workarea.getAlias(), ""});
            data.add(new String[]{"", ""});
            
            int itemCount = 0;
            // Parse schema response
            for (String schemaLine : schemaData) {
                // Removed verbose logging to reduce memory usage
                if (schemaLine.startsWith("INFO:")) {
                    // Parse INFO:key:value: or INFO:key:value
                    String[] parts = schemaLine.split(":", 3);
                    if (parts.length >= 3) {
                        String infoKey = parts[1];
                        String infoValue = parts[2];
                        
                        // Clean up the value - remove trailing colon if present
                        if (infoValue.endsWith(":")) {
                            infoValue = infoValue.substring(0, infoValue.length() - 1);
                        }
                        
                        // Format the key nicely
                        String displayKey = infoKey.substring(0, 1).toUpperCase() + infoKey.substring(1).toLowerCase();
                        data.add(new String[]{displayKey, infoValue.trim()});
                        itemCount++;
                    }
                } else if (schemaLine.startsWith("FIELD:")) {
                    // Show field structure as part of schema
                    String[] parts = schemaLine.split(":");
                    if (parts.length >= 5) {
                        String fieldName = parts[1];
                        String fieldType = parts[2]; 
                        String fieldLength = parts[3];
                        String fieldDecimals = parts[4];
                        
                        data.add(new String[]{"Field: " + fieldName, 
                            fieldType + "(" + fieldLength + 
                            (Integer.parseInt(fieldDecimals) > 0 ? "," + fieldDecimals : "") + ")"});
                        itemCount++;
                    }
                }
            }
            
            tableModel.setData(data);
            HarbourLogger.log("HarbourDBFToolWindow", "[LINE 707] Displayed " + itemCount + " schema items for " + workarea.getAlias());
        }
    }
    
    /**
     * Table model for displaying workarea details
     */
    private static class DetailsTableModel extends AbstractTableModel {
        
        private final String[] columnNames = {"Property", "Value"};
        private List<String[]> data = new ArrayList<>();
        
        @Override
        public int getRowCount() {
            return data.size();
        }
        
        @Override
        public int getColumnCount() {
            return columnNames.length;
        }
        
        @Override
        public String getColumnName(int column) {
            return columnNames[column];
        }
        
        @Override
        public Object getValueAt(int rowIndex, int columnIndex) {
            if (rowIndex < data.size()) {
                String[] row = data.get(rowIndex);
                if (columnIndex < row.length) {
                    return row[columnIndex];
                }
            }
            return "";
        }
        
        public void setData(@NotNull List<String[]> newData) {
            this.data = new ArrayList<>(newData);
            fireTableDataChanged();
        }
        
        public void clearData() {
            this.data.clear();
            fireTableDataChanged();
        }
    }
}
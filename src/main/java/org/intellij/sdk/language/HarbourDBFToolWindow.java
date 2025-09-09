package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.wm.ToolWindow;
import com.intellij.openapi.wm.ToolWindowFactory;
import com.intellij.ui.components.JBScrollPane;
import com.intellij.ui.components.JBTabbedPane;
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
import javax.swing.table.DefaultTableModel;
import javax.swing.table.TableColumn;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.DefaultTreeModel;
import javax.swing.tree.TreePath;
import java.awt.*;
import java.awt.event.ActionListener;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
        private JLabel totalRecordsLabel;
        
        // Grid view components
        private JBTable gridTable;
        private JBScrollPane tableScrollPane;
        
        // Navigation controls
        private JButton prevButton;
        private JButton nextButton;
        private JButton gotoButton;
        private JSpinner recordSpinner;
        private String currentWorkarea = null;
        
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
        
        // Track all pending requests so we can display them when they arrive
        // Key: workarea:datatype, Value: timestamp
        private final java.util.Map<String, Long> pendingRequests = new java.util.HashMap<>();
        
        // Flag to prevent selection events during tree updates
        private boolean updatingTree = false;
        
        public HarbourDBFToolWindowContent(@NotNull Project project) {
            this.project = project;
            
            // Version indicator - CRITICAL: Table Grid View and Indexes nodes MUST appear
            HarbourLogger.log("HarbourDBFToolWindow", "");
            HarbourLogger.log("HarbourDBFToolWindow", "==========================================");
            HarbourLogger.log("HarbourDBFToolWindow", "*** PLUGIN VERSION 1.2.28 LOADED ***");
            HarbourLogger.log("HarbourDBFToolWindow", "*** Table Grid View and Indexes ENABLED ***");
            HarbourLogger.log("HarbourDBFToolWindow", "==========================================");
            HarbourLogger.log("HarbourDBFToolWindow", "");
            
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
            
            // Create refresh button - now handles both workarea refresh and data reload
            JButton refreshButton = new JButton("Refresh");
            refreshButton.setToolTipText("Refresh workareas and reload current data");
            refreshButton.addActionListener(e -> refreshData());
            
            // Create navigation controls
            prevButton = new JButton("Previous");
            prevButton.setEnabled(false);
            prevButton.addActionListener(e -> navigateToPreviousRecord());
            
            nextButton = new JButton("Next");
            nextButton.setEnabled(false);
            nextButton.addActionListener(e -> navigateToNextRecord());
            
            recordSpinner = new JSpinner(new SpinnerNumberModel(1, 1, 1, 1));
            recordSpinner.setEnabled(false);
            recordSpinner.setPreferredSize(new Dimension(80, 25));
            
            gotoButton = new JButton("Go To");
            gotoButton.setEnabled(false);
            gotoButton.addActionListener(e -> navigateToRecord());
            
            // Create total records label
            totalRecordsLabel = new JLabel("");
            
            // Create navigation panel
            JPanel navigationPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));
            navigationPanel.add(new JLabel("Record Navigation:"));
            navigationPanel.add(prevButton);
            navigationPanel.add(nextButton);
            navigationPanel.add(new JLabel("  Go to:"));
            navigationPanel.add(recordSpinner);
            navigationPanel.add(gotoButton);
            navigationPanel.add(new JLabel("  "));
            navigationPanel.add(totalRecordsLabel);
            
            // Create toolbar
            JPanel toolbar = new JPanel(new BorderLayout());
            toolbar.add(navigationPanel, BorderLayout.CENTER);
            toolbar.add(refreshButton, BorderLayout.EAST);
            
            // Create split pane with tree on left, details on right
            JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT);
            splitPane.setLeftComponent(new JBScrollPane(workareaTree));
            tableScrollPane = new JBScrollPane(detailsTable);
            splitPane.setRightComponent(tableScrollPane);
            splitPane.setDividerLocation(250);
            
            mainPanel.add(toolbar, BorderLayout.NORTH);
            mainPanel.add(splitPane, BorderLayout.CENTER);
            mainPanel.add(statusLabel, BorderLayout.SOUTH);
            
            // Initialize with empty state
            updateStatus("No debugging session active");
            
            // Check for existing debug sessions AFTER all UI components are created
            checkForExistingDebugSession();
            
            HarbourLogger.log("HarbourDBFToolWindow", "Created DBF tool window for project: " + project.getName());
            
            // Auto-refresh when tool window is first opened
            SwingUtilities.invokeLater(() -> {
                if (liveConnection != null) {
                    refreshData();
                    HarbourLogger.log("HarbourDBFToolWindow", "Auto-refreshed data on tool window open");
                }
            });
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
            
            // Clear cache and pending requests when connecting to new session
            dataCache.clear();
            waitingForWorkarea = null;
            waitingForDataType = null;
            pendingRequests.clear();
            currentWorkarea = null;
            updateNavigationButtons();
            
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
            
            // Clear UI - properly handle tree updates on EDT
            SwingUtilities.invokeLater(() -> {
                // Clear selection first to avoid assertion errors
                workareaTree.clearSelection();
                
                DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
                rootNode.removeAllChildren();
                treeModel.reload();
                tableModel.clearData();
                
                // Clear cache, waiting state, and pending requests
                dataCache.clear();
                waitingForWorkarea = null;
                waitingForDataType = null;
                pendingRequests.clear();
                currentWorkarea = null;
                updateNavigationButtons();
                
                updateStatus("Debugging session disconnected");
                
                HarbourLogger.log("HarbourDBFToolWindow", "Disconnected from debugging session");
            });
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
            // Set flag to prevent selection events during update
            updatingTree = true;
            
            // Save current selection info
            String selectedWorkarea = null;
            String selectedDataType = null;
            TreePath selectionPath = workareaTree.getSelectionPath();
            if (selectionPath != null) {
                DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                
                // Check if a workarea is selected
                if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                    HarbourLiveDBFConnection.WorkareaInfo info = (HarbourLiveDBFConnection.WorkareaInfo) selectedNode.getUserObject();
                    selectedWorkarea = info.getAlias();
                    selectedDataType = null; // Direct workarea selection
                }
                // Check if a data type under a workarea is selected
                else if (selectedNode.getParent() != null) {
                    DefaultMutableTreeNode parentNode = (DefaultMutableTreeNode) selectedNode.getParent();
                    if (parentNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                        HarbourLiveDBFConnection.WorkareaInfo info = (HarbourLiveDBFConnection.WorkareaInfo) parentNode.getUserObject();
                        selectedWorkarea = info.getAlias();
                        String nodeText = selectedNode.getUserObject().toString();
                        if (nodeText.startsWith("Fields")) {
                            selectedDataType = "Fields";
                        } else if (nodeText.equals("Current Record")) {
                            selectedDataType = "Record";
                        } else if (nodeText.equals("Schema Info")) {
                            selectedDataType = "Schema";
                        }
                    }
                }
            }
            
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
                workareaNode.add(new DefaultMutableTreeNode("Table Grid View"));
                workareaNode.add(new DefaultMutableTreeNode("Indexes"));
                workareaNode.add(new DefaultMutableTreeNode("Schema Info"));
                
                HarbourLogger.log("HarbourDBFToolWindow", "Added tree nodes for " + workarea.getAlias() + 
                    " including Table Grid View and Indexes");
                
                // Log all child nodes to verify they exist
                for (int i = 0; i < workareaNode.getChildCount(); i++) {
                    DefaultMutableTreeNode child = (DefaultMutableTreeNode) workareaNode.getChildAt(i);
                    HarbourLogger.log("HarbourDBFToolWindow", "  Child node " + i + ": '" + child.getUserObject() + "'");
                }
            }
            
            treeModel.reload();
            
            // Expand root node
            workareaTree.expandPath(new TreePath(rootNode.getPath()));
            
            // Keep workareas collapsed by default for cleaner UI
            // Users can expand them as needed
            for (int i = 0; i < rootNode.getChildCount(); i++) {
                DefaultMutableTreeNode child = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                if (child.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                    HarbourLiveDBFConnection.WorkareaInfo info = (HarbourLiveDBFConnection.WorkareaInfo) child.getUserObject();
                    // Check if this workarea was previously expanded
                    if (expandedWorkareas.contains(info.getAlias())) {
                        TreePath childPath = new TreePath(child.getPath());
                        workareaTree.expandPath(childPath);
                        HarbourLogger.log("HarbourDBFToolWindow", "Restored expanded state for: " + info.getAlias());
                    } else {
                        // Keep collapsed - user can expand if needed
                        TreePath childPath = new TreePath(child.getPath());
                        workareaTree.collapsePath(childPath);
                        HarbourLogger.log("HarbourDBFToolWindow", "Keeping collapsed: " + info.getAlias() + 
                            " with " + child.getChildCount() + " child nodes");
                    }
                }
            }
            
            // Force UI refresh to ensure all nodes are visible
            SwingUtilities.invokeLater(() -> {
                workareaTree.revalidate();
                workareaTree.repaint();
                HarbourLogger.log("HarbourDBFToolWindow", "UI refresh completed for workarea tree");
            });
            
            // Don't restore selection - it causes unwanted event triggering
            // The user's waiting state is preserved, so when data arrives it will display correctly
            
            HarbourLogger.log("HarbourDBFToolWindow", "Updated workarea tree with " + workareas.size() + " workareas" +
                (selectedWorkarea != null ? ", had selection: " + selectedWorkarea + 
                 (selectedDataType != null ? "/" + selectedDataType : "") : "") +
                ", waiting for: " + waitingForWorkarea + "/" + waitingForDataType);
            
            // Clear the updating flag
            updatingTree = false;
        }
        
        /**
         * Handle workarea selection in tree
         */
        private void onWorkareaSelected() {
            // Ignore selection events during tree updates
            if (updatingTree) {
                return;
            }
            
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
                    
                    HarbourLogger.log("HarbourDBFToolWindow", "==============================================");
                    HarbourLogger.log("HarbourDBFToolWindow", "*** NODE SELECTED: '" + nodeText + "' ***");
                    HarbourLogger.log("HarbourDBFToolWindow", "*** WORKAREA: " + alias + " ***");
                    HarbourLogger.log("HarbourDBFToolWindow", "==============================================");
                    
                    // Get or create cache for this workarea
                    WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
                    
                    if (nodeText.startsWith("Fields")) {
                        currentWorkarea = alias;
                        updateNavigationButtons();
                        if (cache.fieldData != null) {
                            // Show cached data immediately
                            displayFieldData(workarea, cache.fieldData);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Fields");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Fields";
                            pendingRequests.put(alias + ":Fields", System.currentTimeMillis());
                            liveConnection.requestFieldInfo(alias);
                        }
                    } else if (nodeText.equals("Current Record")) {
                        if (cache.recordData != null) {
                            // Show cached data immediately
                            displayRecordData(workarea, cache.recordData);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Current Record");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Record";
                            pendingRequests.put(alias + ":Record", System.currentTimeMillis());
                            liveConnection.requestRecordData(alias);
                            currentWorkarea = alias;
                            updateNavigationButtons();
                        }
                    } else if (nodeText.equals("Table Grid View")) {
                        HarbourLogger.log("HarbourDBFToolWindow", "*** TABLE GRID VIEW SELECTED for " + alias);
                        currentWorkarea = alias;
                        updateNavigationButtons();
                        // Request multiple records for grid view
                        showLoadingMessage("Table Grid View");
                        waitingForWorkarea = alias;
                        waitingForDataType = "Records";
                        pendingRequests.put(alias + ":Records", System.currentTimeMillis());
                        HarbourLogger.log("HarbourDBFToolWindow", "Setting up request for table grid - alias: " + alias + 
                            ", waitingForDataType: Records, pendingRequest key: " + alias + ":Records");
                        liveConnection.requestRecords(alias, 1, 50); // Request first 50 records
                        HarbourLogger.log("HarbourDBFToolWindow", "Called liveConnection.requestRecords(" + alias + ", 1, 50)");
                    } else if (nodeText.equals("Indexes")) {
                        HarbourLogger.log("HarbourDBFToolWindow", "*** INDEXES SELECTED for " + alias);
                        currentWorkarea = alias;
                        updateNavigationButtons();
                        // Request index information
                        showLoadingMessage("Index Information");
                        waitingForWorkarea = alias;
                        waitingForDataType = "Indexes";
                        pendingRequests.put(alias + ":Indexes", System.currentTimeMillis());
                        HarbourLogger.log("HarbourDBFToolWindow", "Setting up request for indexes - alias: " + alias + 
                            ", waitingForDataType: Indexes, pendingRequest key: " + alias + ":Indexes");
                        liveConnection.requestIndexInfo(alias);
                        HarbourLogger.log("HarbourDBFToolWindow", "Called liveConnection.requestIndexInfo(" + alias + ")");
                    } else if (nodeText.equals("Schema Info")) {
                        currentWorkarea = alias;
                        updateNavigationButtons();
                        if (cache.schemaData != null) {
                            // Show cached data immediately
                            displaySchemaData(workarea, cache.schemaData);
                        } else {
                            // Show loading message and request data
                            showLoadingMessage("Schema Info");
                            waitingForWorkarea = alias;
                            waitingForDataType = "Schema";
                            pendingRequests.put(alias + ":Schema", System.currentTimeMillis());
                            liveConnection.requestSchemaInfo(alias);
                        }
                    }
                }
            }
        }
        
        /**
         * Navigate to the previous record
         */
        private void navigateToPreviousRecord() {
            if (currentWorkarea != null && liveConnection != null) {
                liveConnection.navigateToPreviousRecord(currentWorkarea);
                // Clear cached record data to force refresh
                WorkareaCache cache = dataCache.get(currentWorkarea);
                if (cache != null) {
                    cache.recordData = null;
                }
                // Request updated record data
                liveConnection.requestRecordData(currentWorkarea);
                updateNavigationButtons();
            }
        }
        
        /**
         * Navigate to the next record
         */
        private void navigateToNextRecord() {
            if (currentWorkarea != null && liveConnection != null) {
                liveConnection.navigateToNextRecord(currentWorkarea);
                // Clear cached record data to force refresh
                WorkareaCache cache = dataCache.get(currentWorkarea);
                if (cache != null) {
                    cache.recordData = null;
                }
                // Request updated record data
                liveConnection.requestRecordData(currentWorkarea);
                updateNavigationButtons();
            }
        }
        
        /**
         * Navigate to a specific record number
         */
        private void navigateToRecord() {
            if (currentWorkarea != null && liveConnection != null) {
                int recordNumber = (Integer) recordSpinner.getValue();
                liveConnection.navigateToRecord(currentWorkarea, recordNumber);
                // Clear cached record data to force refresh
                WorkareaCache cache = dataCache.get(currentWorkarea);
                if (cache != null) {
                    cache.recordData = null;
                }
                // Request updated record data
                liveConnection.requestRecordData(currentWorkarea);
                updateNavigationButtons();
            }
        }
        
        /**
         * Reload current data manually
         */
        private void reloadCurrentData() {
            if (currentWorkarea == null || liveConnection == null) {
                return;
            }
            
            TreePath selectionPath = workareaTree.getSelectionPath();
            if (selectionPath == null) {
                return;
            }
            
            DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
            
            // Determine what type of data is currently selected
            String nodeText = "";
            if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                // Workarea selected - reload current record
                nodeText = "Current Record";
            } else if (selectedNode.getParent() != null) {
                nodeText = selectedNode.getUserObject().toString();
            }
            
            // Clear cache for the selected data type
            WorkareaCache cache = dataCache.get(currentWorkarea);
            if (cache != null) {
                if (nodeText.startsWith("Fields")) {
                    cache.fieldData = null;
                    liveConnection.requestFieldInfo(currentWorkarea);
                } else if (nodeText.equals("Current Record")) {
                    cache.recordData = null;
                    liveConnection.requestRecordData(currentWorkarea);
                } else if (nodeText.equals("Table Grid View")) {
                    // Request records again
                    showLoadingMessage("Table Grid View");
                    waitingForWorkarea = currentWorkarea;
                    waitingForDataType = "Records";
                    pendingRequests.put(currentWorkarea + ":Records", System.currentTimeMillis());
                    liveConnection.requestRecords(currentWorkarea, 1, 50);
                } else if (nodeText.equals("Indexes")) {
                    // Request indexes again
                    showLoadingMessage("Index Information");
                    waitingForWorkarea = currentWorkarea;
                    waitingForDataType = "Indexes";
                    pendingRequests.put(currentWorkarea + ":Indexes", System.currentTimeMillis());
                    liveConnection.requestIndexInfo(currentWorkarea);
                } else if (nodeText.equals("Schema Info")) {
                    cache.schemaData = null;
                    liveConnection.requestSchemaInfo(currentWorkarea);
                }
            }
            
            HarbourLogger.log("HarbourDBFToolWindow", "Manual reload requested for " + currentWorkarea + " - " + nodeText);
        }
        
        /**
         * Update navigation button states based on current record position
         */
        private void updateNavigationButtons() {
            if (currentWorkarea == null || liveConnection == null) {
                prevButton.setEnabled(false);
                nextButton.setEnabled(false);
                gotoButton.setEnabled(false);
                recordSpinner.setEnabled(false);
                totalRecordsLabel.setText("");
                return;
            }
            
            HarbourLiveDBFConnection.WorkareaInfo workarea = liveConnection.getWorkarea(currentWorkarea);
            if (workarea != null) {
                int currentRecord = workarea.getCurrentRecord();
                int totalRecords = workarea.getTotalRecords();
                
                prevButton.setEnabled(currentRecord > 1);
                nextButton.setEnabled(currentRecord < totalRecords);
                gotoButton.setEnabled(totalRecords > 0);
                recordSpinner.setEnabled(totalRecords > 0);
                
                // Update spinner model
                if (totalRecords > 0) {
                    recordSpinner.setModel(new SpinnerNumberModel(currentRecord, 1, totalRecords, 1));
                    totalRecordsLabel.setText("Total: " + totalRecords);
                } else {
                    totalRecordsLabel.setText("");
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
            } else {
                // Show loading message and request data
                showLoadingMessage("Current Record");
                waitingForWorkarea = alias;
                waitingForDataType = "Record";
                pendingRequests.put(alias + ":Record", System.currentTimeMillis());
                liveConnection.requestRecordData(alias);
                currentWorkarea = alias;
                updateNavigationButtons();
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
         * Refresh both workareas and current data
         */
        private void refreshData() {
            if (liveConnection != null) {
                // First refresh workareas
                liveConnection.requestWorkareaUpdate();
                
                // Then reload current data if something is selected
                reloadCurrentData();
                
                updateStatus("Refreshing data...");
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
            
            
            // Check if we should display this data
            boolean shouldDisplay = false;
            String requestKey = alias + ":Fields";
            
            // Check if we have a pending request for this data
            if (pendingRequests.containsKey(requestKey)) {
                shouldDisplay = true;
                pendingRequests.remove(requestKey);
                
                // Also clear waiting state if it matches
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Fields".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            }
            // Or if it's currently selected
            else if (isCurrentlySelected(alias, "Fields")) {
                shouldDisplay = true;
            }
            
            if (shouldDisplay) {
                // Display the data - displayFieldData will handle EDT properly
                displayFieldData(workarea, fieldData);
            }
        }
        
        /**
         * Display field data in the table
         */
        private void displayFieldData(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] fieldData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayFieldData(workarea, fieldData));
                return;
            }
            
            // Switch back to details table
            switchToDetailsTable();
            
            List<String[]> data = new ArrayList<>();
            
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
            
            // Force table to repaint
            detailsTable.repaint();
            detailsTable.revalidate();
            
        }
        
        @Override 
        public void onRecordDataReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordData) {
            
            // Cache the data
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            cache.setRecordData(recordData);
            
            // Check if we should display this data
            boolean shouldDisplay = false;
            String requestKey = alias + ":Record";
            
            // Check if we have a pending request for this data
            if (pendingRequests.containsKey(requestKey)) {
                shouldDisplay = true;
                pendingRequests.remove(requestKey);
                
                // Also clear waiting state if it matches
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Record".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            }
            // Or if it's currently selected
            else if (isCurrentlySelected(alias, "Record")) {
                shouldDisplay = true;
            }
            
            if (shouldDisplay) {
                // Display the data - displayRecordData will handle EDT properly
                displayRecordData(workarea, recordData);
                // Update navigation buttons to reflect current record position
                updateNavigationButtons();
            }
        }
        
        /**
         * Display record data in the table
         */
        private void displayRecordData(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayRecordData(workarea, recordData));
                return;
            }
            
            // Switch back to details table
            switchToDetailsTable();
            
            List<String[]> data = new ArrayList<>();
            
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
            
            tableModel.setData(data);
            
            // Force table to repaint
            detailsTable.repaint();
            detailsTable.revalidate();
            
        }
        
        @Override
        public void onSchemaInfoReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] schemaData) {
            // Cache the data
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            cache.setSchemaData(schemaData);
            
            
            // Check if we should display this data
            boolean shouldDisplay = false;
            String requestKey = alias + ":Schema";
            
            // Check if we have a pending request for this data
            if (pendingRequests.containsKey(requestKey)) {
                shouldDisplay = true;
                pendingRequests.remove(requestKey);
                
                // Also clear waiting state if it matches
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Schema".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            }
            // Or if it's currently selected
            else if (isCurrentlySelected(alias, "Schema")) {
                shouldDisplay = true;
            }
            
            if (shouldDisplay) {
                // Display the data - displaySchemaData will handle EDT properly
                displaySchemaData(workarea, schemaData);
            }
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
                    } else if (dataType.equals("Records") && nodeText.equals("Table Grid View")) {
                        return true;
                    } else if (dataType.equals("Indexes") && nodeText.equals("Indexes")) {
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
            
            // Switch back to details table
            switchToDetailsTable();
            
            List<String[]> data = new ArrayList<>();
            
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
            
            // Force table to repaint
            detailsTable.repaint();
            detailsTable.revalidate();
            
        }
        
        @Override
        public void onRecordsReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordsData) {
            // Check if we should display this data
            String alias = workarea.getAlias();
            boolean shouldDisplay = false;
            String requestKey = alias + ":Records";
            
            HarbourLogger.log("HarbourDBFToolWindow", "onRecordsReceived called for " + alias + " with " + recordsData.length + " lines of data");
            
            if (pendingRequests.containsKey(requestKey)) {
                shouldDisplay = true;
                pendingRequests.remove(requestKey);
                
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Records".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            }
            
            if (shouldDisplay) {
                displayRecordsGrid(workarea, recordsData);
            }
        }
        
        @Override
        public void onIndexesReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] indexesData) {
            // Check if we should display this data
            String alias = workarea.getAlias();
            boolean shouldDisplay = false;
            String requestKey = alias + ":Indexes";
            
            HarbourLogger.log("HarbourDBFToolWindow", "onIndexesReceived called for " + alias + " with " + indexesData.length + " lines of data");
            
            if (pendingRequests.containsKey(requestKey)) {
                shouldDisplay = true;
                pendingRequests.remove(requestKey);
                
                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Indexes".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            }
            
            if (shouldDisplay) {
                displayIndexes(workarea, indexesData);
            }
        }
        
        /**
         * Display multiple records in a grid view
         */
        private void displayRecordsGrid(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordsData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayRecordsGrid(workarea, recordsData));
                return;
            }
            
            List<String> columnNames = new ArrayList<>();
            List<Map<String, String>> rows = new ArrayList<>();
            Map<String, String> currentRow = null;
            
            // Parse the records data
            for (String line : recordsData) {
                if (line.startsWith("ERROR:")) {
                    // Handle error - show in regular table
                    List<String[]> errorData = new ArrayList<>();
                    errorData.add(new String[]{"Error:", line.substring(6)});
                    tableModel.setData(errorData);
                    switchToDetailsTable();
                    return;
                } else if (line.startsWith("COLUMN:")) {
                    // Parse column definition - format: COLUMN:name:type:length:decimals
                    String[] parts = line.substring(7).split(":");
                    if (parts.length >= 1) {
                        columnNames.add(parts[0]);
                    }
                } else if (line.startsWith("ROW:")) {
                    // Save previous row if exists
                    if (currentRow != null) {
                        rows.add(new HashMap<>(currentRow));
                    }
                    // Start new row
                    currentRow = new HashMap<>();
                    currentRow.put("RecNo", line.substring(4));
                } else if (line.startsWith("CELL:") && currentRow != null) {
                    // Parse cell data - format: CELL:fieldname:value
                    int colonPos = line.indexOf(':', 5);
                    if (colonPos > 0) {
                        String fieldName = line.substring(5, colonPos);
                        String value = line.substring(colonPos + 1);
                        // Remove quotes from values
                        if (value.startsWith("\"") && value.endsWith("\"") && value.length() > 1) {
                            value = value.substring(1, value.length() - 1);
                        }
                        // Trim trailing spaces from character fields
                        value = value.trim();
                        currentRow.put(fieldName, value);
                    }
                }
            }
            
            // Add last row
            if (currentRow != null) {
                rows.add(currentRow);
            }
            
            // If no columns found, show error
            if (columnNames.isEmpty() || rows.isEmpty()) {
                List<String[]> data = new ArrayList<>();
                data.add(new String[]{"No data available", ""});
                tableModel.setData(data);
                switchToDetailsTable();
                return;
            }
            
            // Create proper grid table
            createAndSwitchToGridTable(columnNames, rows);
        }
        
        /**
         * Create a new JTable for grid view and switch to it
         */
        private void createAndSwitchToGridTable(List<String> columnNames, List<Map<String, String>> rows) {
            // Add RecNo as first column
            List<String> allColumns = new ArrayList<>();
            allColumns.add("RecNo");
            allColumns.addAll(columnNames);
            
            // Create column names array
            String[] columnArray = allColumns.toArray(new String[0]);
            
            // Create data array
            Object[][] dataArray = new Object[rows.size()][allColumns.size()];
            for (int i = 0; i < rows.size(); i++) {
                Map<String, String> row = rows.get(i);
                for (int j = 0; j < allColumns.size(); j++) {
                    String columnName = allColumns.get(j);
                    String value = row.get(columnName);
                    dataArray[i][j] = value != null ? value : "";
                }
            }
            
            // Create new table model for grid
            DefaultTableModel gridModel = new DefaultTableModel(dataArray, columnArray) {
                @Override
                public boolean isCellEditable(int row, int column) {
                    return false; // Make table read-only
                }
            };
            
            // Create new grid table
            gridTable = new JBTable(gridModel);
            gridTable.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);
            gridTable.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
            
            // Set column widths based on content
            for (int i = 0; i < gridTable.getColumnCount(); i++) {
                TableColumn column = gridTable.getColumnModel().getColumn(i);
                String columnName = columnArray[i];
                
                // Set preferred width based on column name and content
                int width;
                if ("RecNo".equals(columnName)) {
                    width = 60;
                } else {
                    // Calculate width based on column name length and sample data
                    width = Math.max(columnName.length() * 8, 80);
                    width = Math.min(width, 200); // Cap maximum width
                }
                column.setPreferredWidth(width);
            }
            
            // Replace the table in the scroll pane
            tableScrollPane.setViewportView(gridTable);
            tableScrollPane.revalidate();
            tableScrollPane.repaint();
        }
        
        /**
         * Switch back to the details table view
         */
        private void switchToDetailsTable() {
            if (tableScrollPane.getViewport().getView() != detailsTable) {
                tableScrollPane.setViewportView(detailsTable);
                tableScrollPane.revalidate();
                tableScrollPane.repaint();
            }
        }
        
        /**
         * Display index information
         */
        private void displayIndexes(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] indexesData) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayIndexes(workarea, indexesData));
                return;
            }
            
            // Switch back to details table
            switchToDetailsTable();
            
            List<String[]> data = new ArrayList<>();
            
            String currentIndex = null;
            String currentName = null;
            String currentKey = null;
            String currentFor = null;
            String currentBag = null;
            List<String[]> indexList = new ArrayList<>();
            
            // Parse all index data
            for (String line : indexesData) {
                if (line.startsWith("ERROR:")) {
                    data.add(new String[]{"Error:", line.substring(6)});
                } else if (line.startsWith("CURRENT:")) {
                    currentIndex = line.substring(8);
                } else if (line.startsWith("CURRENT_NAME:")) {
                    currentName = line.substring(13);
                } else if (line.startsWith("CURRENT_KEY:")) {
                    currentKey = line.substring(12);
                } else if (line.startsWith("CURRENT_FOR:")) {
                    currentFor = line.substring(12);
                } else if (line.startsWith("CURRENT_BAG:")) {
                    currentBag = line.substring(12);
                } else if (line.startsWith("INDEX:")) {
                    // Parse INDEX:number:name:file:key:for
                    String[] parts = line.substring(6).split(":", 5);
                    if (parts.length >= 4) {
                        indexList.add(parts);
                    }
                }
            }
            
            // Display current index details
            if (currentIndex != null && !currentIndex.equals("0")) {
                data.add(new String[]{"Currently Selected Index", ""});
                data.add(new String[]{"Index Order:", currentIndex});
                if (currentName != null && !currentName.isEmpty()) {
                    data.add(new String[]{"Index Name:", currentName});
                }
                if (currentBag != null && !currentBag.isEmpty()) {
                    data.add(new String[]{"Index File:", currentBag});
                }
                if (currentKey != null && !currentKey.isEmpty()) {
                    data.add(new String[]{"Key Expression:", currentKey});
                }
                if (currentFor != null && !currentFor.isEmpty() && !currentFor.equals("NIL")) {
                    data.add(new String[]{"For Condition:", currentFor});
                }
                data.add(new String[]{"", ""});
            }
            
            // Display all indexes
            if (!indexList.isEmpty()) {
                data.add(new String[]{"All Indexes", ""});
                
                for (String[] parts : indexList) {
                    String indexNum = parts[0];
                    String indexName = parts[1];
                    String indexFile = parts[2];
                    String indexKey = parts[3];
                    String indexFor = parts.length > 4 ? parts[4] : "";
                    
                    data.add(new String[]{"", ""});
                    String indexTitle = "Index #" + indexNum;
                    if (!indexName.isEmpty()) {
                        indexTitle += " (" + indexName + ")";
                    }
                    if (currentIndex != null && currentIndex.equals(indexNum)) {
                        indexTitle += " [ACTIVE]";
                    }
                    data.add(new String[]{indexTitle, ""});
                    
                    if (!indexFile.isEmpty()) {
                        data.add(new String[]{"  File:", indexFile});
                    }
                    data.add(new String[]{"  Key:", indexKey});
                    if (!indexFor.isEmpty() && !indexFor.equals("NIL")) {
                        data.add(new String[]{"  For:", indexFor});
                    }
                }
            } else {
                data.add(new String[]{"No indexes defined for this workarea", ""});
            }
            
            tableModel.setData(data);
            detailsTable.repaint();
            detailsTable.revalidate();
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
    
    /**
     * Table model for the grid view of DBF data
     */
}
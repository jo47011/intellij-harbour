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
            
            this.liveConnection = connection;
            connection.addWorkareaUpdateListener(this);
            
            updateStatus("Connected to debugging session");
            
            HarbourLogger.log("HarbourDBFToolWindow", "Connected to live debugging session");
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
            DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
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
            
            // Also expand each workarea node to show the child options
            for (int i = 0; i < rootNode.getChildCount(); i++) {
                DefaultMutableTreeNode childNode = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                workareaTree.expandPath(new TreePath(childNode.getPath()));
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
                    
                    if (nodeText.startsWith("Fields")) {
                        liveConnection.requestFieldInfo(workarea.getAlias());
                    } else if (nodeText.equals("Current Record")) {
                        liveConnection.requestRecordData(workarea.getAlias());
                    } else if (nodeText.equals("Schema Info")) {
                        liveConnection.requestSchemaInfo(workarea.getAlias());
                    }
                }
            }
        }
        
        /**
         * Show basic workarea details in the details table - DEFAULT: show current record data
         */
        private void showWorkareaDetails(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea) {
            // Default behavior: show current record data when clicking on table name
            liveConnection.requestRecordData(workarea.getAlias());
            
            HarbourLogger.log("HarbourDBFToolWindow", "Showing current record data for workarea: " + workarea.getAlias());
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
            ApplicationManager.getApplication().invokeLater(() -> {
                List<String[]> data = new ArrayList<>();
                data.add(new String[]{"Field Information for " + workarea.getAlias(), ""});
                data.add(new String[]{"", ""});
                
                for (String fieldLine : fieldData) {
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
                        }
                    }
                }
                
                tableModel.setData(data);
                HarbourLogger.log("HarbourDBFToolWindow", "Displayed field information for " + workarea.getAlias());
            });
        }
        
        @Override 
        public void onRecordDataReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordData) {
            HarbourLogger.log("HarbourDBFToolWindow", 
                "onRecordDataReceived called for " + workarea.getAlias() + " with " + recordData.length + " lines");
            
            ApplicationManager.getApplication().invokeLater(() -> {
                List<String[]> data = new ArrayList<>();
                data.add(new String[]{"Current Record Data for " + workarea.getAlias(), ""});
                data.add(new String[]{"Record " + workarea.getCurrentRecord() + " of " + workarea.getTotalRecords(), ""});
                data.add(new String[]{"", ""});
                
                int valueCount = 0;
                for (String dataLine : recordData) {
                    HarbourLogger.log("HarbourDBFToolWindow", "Record data line: " + dataLine);
                    
                    // Accept both DATA: and VALUE: prefixes (Harbour sends VALUE:)
                    if (dataLine.startsWith("DATA:") || dataLine.startsWith("VALUE:")) {
                        // Parse DATA/VALUE:fieldname:type:value: or VALUE:fieldname:value:
                        String[] parts = dataLine.split(":", 4); // Split into max 4 parts to handle type and values with colons
                        if (parts.length >= 3) {
                            String fieldName = parts[1];
                            // Skip type if present (parts[2]) and get value from last part
                            String fieldValue = parts.length == 4 ? parts[3] : parts[2];
                            
                            data.add(new String[]{fieldName, fieldValue});
                            valueCount++;
                        }
                    }
                }
                
                HarbourLogger.log("HarbourDBFToolWindow", "Added " + valueCount + " field values to display");
                
                tableModel.setData(data);
                HarbourLogger.log("HarbourDBFToolWindow", "Displayed current record data for " + workarea.getAlias());
            });
        }
        
        @Override
        public void onSchemaInfoReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] schemaData) {
            ApplicationManager.getApplication().invokeLater(() -> {
                List<String[]> data = new ArrayList<>();
                data.add(new String[]{"Schema Information for " + workarea.getAlias(), ""});
                data.add(new String[]{"", ""});
                
                // Parse schema response
                for (String schemaLine : schemaData) {
                    if (schemaLine.startsWith("INFO:")) {
                        // Parse INFO:key:value:
                        String[] parts = schemaLine.split(":", 3);
                        if (parts.length >= 3) {
                            String infoKey = parts[1];
                            String infoValue = parts[2];
                            
                            // Format the key nicely
                            String displayKey = infoKey.substring(0, 1).toUpperCase() + infoKey.substring(1).toLowerCase();
                            data.add(new String[]{displayKey, infoValue});
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
                        }
                    }
                }
                
                tableModel.setData(data);
                HarbourLogger.log("HarbourDBFToolWindow", "Displayed schema information for " + workarea.getAlias());
            });
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
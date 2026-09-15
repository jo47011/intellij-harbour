package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.wm.ToolWindow;
import com.intellij.openapi.wm.ToolWindowFactory;
import com.intellij.ui.SearchTextField;
import com.intellij.ui.components.JBScrollPane;
import com.intellij.ui.components.JBTabbedPane;
import com.intellij.ui.content.Content;
import com.intellij.ui.content.ContentFactory;
import com.intellij.ui.table.JBTable;
import com.intellij.ui.treeStructure.Tree;
import com.intellij.xdebugger.XDebugProcess;
import com.intellij.xdebugger.XDebugSession;
import com.intellij.xdebugger.XDebugSessionListener;
import com.intellij.xdebugger.XDebuggerManager;
import com.intellij.xdebugger.XDebuggerManagerListener;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;
import javax.swing.table.AbstractTableModel;
import javax.swing.table.DefaultTableModel;
import javax.swing.table.TableColumn;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.DefaultTreeModel;
import javax.swing.tree.TreeNode;
import javax.swing.tree.TreePath;
import java.awt.*;
import java.awt.event.ActionListener;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.text.ParseException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;

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
        HarbourDBFToolWindowContent content = new HarbourDBFToolWindowContent(project, toolWindow);
        Content toolContent = ContentFactory.getInstance().createContent(
            content.getContent(), "Harbour DBF", false);
        toolWindow.getContentManager().addContent(toolContent);
    }
    
    /**
     * Content panel for the DBF tool window
     */
    private static class HarbourDBFToolWindowContent implements HarbourLiveDBFConnection.DetailedDataListener {

        private final Project project;
        private final ToolWindow toolWindow;
        private final JPanel mainPanel;
        private final Tree workareaTree;
        private final JBTable detailsTable;
        private final DefaultTreeModel treeModel;
        private final DetailsTableModel tableModel;
        private final JLabel statusLabel;
        private JLabel totalRecordsLabel;
        private JLabel currentInfoLabel;  // Shows current alias and recno

        // Filter components
        private SearchTextField filterNameField;
        private SearchTextField filterValueField;
        private JPanel filterPanel;  // Panel containing filter fields
        private List<String[]> unfilteredData;  // Original data before filtering

        // Grid view components
        private JBTable gridTable;
        private JBScrollPane tableScrollPane;

        // Grid load controls
        private JSpinner gridRecordCountSpinner;  // Number of records to load for grid view
        private JLabel gridRecordLabel;
        private JLabel gridEnterLabel;  // "(Enter)" label for grid spinner
        private JLabel gridLoadingLabel; // Loading indicator (spinner character)

        // Navigation controls
        private JButton prevButton;
        private JButton nextButton;
        // Removed gotoButton and loadAllButton - using Enter key in spinner instead
        private JSpinner recordSpinner;
        private JLabel gotoLabel;        // "Go to:" label
        private JLabel enterLabel;       // "(Enter)" label for record spinner
        private JLabel separatorLabel;   // separator between record navigation and grid controls
        private String currentWorkarea = null;
        private String currentViewType = null;  // Tracks current view: "Fields", "Record", "Schema", "Indexes", "Grid"

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

        // User-defined row order for Record view, per workarea alias (session-only).
        // When present, overrides natural order so the user can pin relevant attributes to the top.
        private final java.util.Map<String, List<String>> recordRowOrder = new java.util.HashMap<>();

        // Drag-and-drop state for reordering rows in Record view
        private int dragSourceRow = -1;

        // Track what we're currently waiting for
        private String waitingForWorkarea = null;
        private String waitingForDataType = null;
        
        // Track all pending requests so we can display them when they arrive
        // Key: workarea:datatype, Value: timestamp
        private final java.util.Map<String, Long> pendingRequests = new java.util.HashMap<>();

        // Track the current grid loading request ID - used to ensure only the active request hides indicator
        private long currentGridLoadingRequestId = 0;

        // Flag to prevent selection events during tree updates
        private boolean updatingTree = false;

        // Flag to track if we should auto-select first workarea on initial load
        private boolean autoSelectOnFirstLoad = true;

        // Sorting options (controlled via clickable column headers)
        private boolean sortWorkareasByName = false;  // false = by order, true = alphabetically
        private boolean sortColumnsByName = false;    // Property column: false = original order, true = sorted
        private boolean sortColumnsByValue = false;   // Value column: false = original order, true = sorted

        public HarbourDBFToolWindowContent(@NotNull Project project, @NotNull ToolWindow toolWindow) {
            this.project = project;
            this.toolWindow = toolWindow;
            
            // Version indicator - CRITICAL: Table Grid View and Indexes nodes MUST appear
            HarbourLogger.log("HarbourDBFToolWindow", "");
            HarbourLogger.log("HarbourDBFToolWindow", "==========================================");
            HarbourLogger.log("HarbourDBFToolWindow", "*** PLUGIN VERSION 1.2.104 LOADED ***");
            HarbourLogger.log("HarbourDBFToolWindow", "*** Loading indicator added ***");
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
            
            // Create details table with sortable column headers
            tableModel = new DetailsTableModel();
            detailsTable = new JBTable(tableModel);
            detailsTable.setAutoResizeMode(JTable.AUTO_RESIZE_ALL_COLUMNS);

            // Make table header clickable for sorting
            detailsTable.getTableHeader().setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
            detailsTable.getTableHeader().setToolTipText("Click column header to sort (cycles: none → ascending → descending)");
            detailsTable.getTableHeader().addMouseListener(new java.awt.event.MouseAdapter() {
                @Override
                public void mouseClicked(java.awt.event.MouseEvent e) {
                    // Only allow sorting if not in Schema Info or Index view
                    if (!isSortingAllowedForCurrentView()) {
                        return;
                    }
                    int col = detailsTable.columnAtPoint(e.getPoint());
                    if (col == 0 || col == 1) {  // Property or Value column
                        int newState = tableModel.toggleSortState(col);
                        // Store sort state for applyFilters
                        if (col == 0) {
                            sortColumnsByName = (newState > 0);
                            sortColumnsByValue = false;
                        } else {
                            sortColumnsByValue = (newState > 0);
                            sortColumnsByName = false;
                        }
                        applyFilters();
                    }
                }
            });

            installRowReorderHandlers();

            // Create status label
            statusLabel = new JLabel("No debugging session active");
            statusLabel.setBorder(BorderFactory.createEmptyBorder(5, 5, 5, 5));
            
            // Create refresh button - now handles both workarea refresh and data reload
            JButton refreshButton = new JButton("Refresh");
            refreshButton.setToolTipText("Refresh workareas and reload current data");
            refreshButton.addActionListener(e -> refreshData());
            
            // Removed Load All button per user request
            
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
            
            // Setup Enter key handling (will be called again after model changes)
            setupSpinnerEnterKeyHandling();
            
            // Removed Go To button - using Enter key in spinner instead
            
            // Create total records label
            totalRecordsLabel = new JLabel("");

            // Create current info label for alias and recno
            currentInfoLabel = new JLabel("");
            currentInfoLabel.setFont(currentInfoLabel.getFont().deriveFont(Font.BOLD));

            // Create navigation panel
            JPanel navigationPanel = new JPanel(new FlowLayout(FlowLayout.LEFT));
            navigationPanel.add(currentInfoLabel);
            navigationPanel.add(new JLabel("  |  "));
            navigationPanel.add(prevButton);
            navigationPanel.add(nextButton);
            gotoLabel = new JLabel("  Go to:");
            navigationPanel.add(gotoLabel);
            navigationPanel.add(recordSpinner);
            enterLabel = new JLabel(" (Enter)");
            navigationPanel.add(enterLabel);
            navigationPanel.add(new JLabel("  "));
            navigationPanel.add(totalRecordsLabel);

            // Grid view controls (initially hidden, shown when Table Grid View is selected)
            separatorLabel = new JLabel("   |  ");
            navigationPanel.add(separatorLabel);
            gridRecordLabel = new JLabel("Load:");
            navigationPanel.add(gridRecordLabel);
            // Min value 0 means "all records"
            SpinnerNumberModel gridRecordModel = new SpinnerNumberModel(10, 0, 10000, 10);
            gridRecordCountSpinner = new JSpinner(gridRecordModel);
            gridRecordCountSpinner.setToolTipText("Number of records to load (0 = all). Press Enter to load.");
            gridRecordCountSpinner.setPreferredSize(new Dimension(70, 25));
            navigationPanel.add(gridRecordCountSpinner);
            gridEnterLabel = new JLabel(" (Enter)");
            navigationPanel.add(gridEnterLabel);
            gridLoadingLabel = new JLabel(" ⏳");  // Loading indicator
            gridLoadingLabel.setVisible(false);  // Initially hidden
            navigationPanel.add(gridLoadingLabel);

            // Setup Enter key handling for grid record spinner
            setupGridSpinnerEnterKeyHandling();

            // Initially hide grid controls
            setGridControlsVisible(false);

            // Create button panel for right side of toolbar
            JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.RIGHT));
            buttonPanel.add(refreshButton);

            // Create toolbar
            JPanel toolbar = new JPanel(new BorderLayout());
            toolbar.add(navigationPanel, BorderLayout.CENTER);
            toolbar.add(buttonPanel, BorderLayout.EAST);

            // Create filter panel with labeled filter fields
            filterPanel = new JPanel(new FlowLayout(FlowLayout.LEFT, 5, 2));

            // Name filter
            filterPanel.add(new JLabel("Name:"));
            filterNameField = new SearchTextField(false);
            filterNameField.setToolTipText("Filter by property name (case-insensitive)");
            filterNameField.getTextEditor().setColumns(12);
            filterPanel.add(filterNameField);

            // Value filter
            filterPanel.add(new JLabel("  Value:"));
            filterValueField = new SearchTextField(false);
            filterValueField.setToolTipText("Filter by value (case-insensitive)");
            filterValueField.getTextEditor().setColumns(15);
            filterPanel.add(filterValueField);

            // Add filter change listeners to SearchTextField
            DocumentListener filterListener = new DocumentListener() {
                @Override
                public void insertUpdate(DocumentEvent e) { applyFilters(); }
                @Override
                public void removeUpdate(DocumentEvent e) { applyFilters(); }
                @Override
                public void changedUpdate(DocumentEvent e) { applyFilters(); }
            };
            filterNameField.addDocumentListener(filterListener);
            filterValueField.addDocumentListener(filterListener);

            // Create right panel with filter and table
            JPanel rightPanel = new JPanel(new BorderLayout());
            rightPanel.add(filterPanel, BorderLayout.NORTH);
            tableScrollPane = new JBScrollPane(detailsTable);
            rightPanel.add(tableScrollPane, BorderLayout.CENTER);

            // Create left panel with tree (click header "Workareas" to toggle sort)
            JPanel leftPanel = new JPanel(new BorderLayout());
            JPanel treeHeaderPanel = new JPanel(new FlowLayout(FlowLayout.LEFT, 5, 2));
            JLabel workareasLabel = new JLabel("Workareas (click to sort)");
            workareasLabel.setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));
            workareasLabel.setToolTipText("Click to toggle alphabetical sorting");
            workareasLabel.addMouseListener(new java.awt.event.MouseAdapter() {
                @Override
                public void mouseClicked(java.awt.event.MouseEvent e) {
                    sortWorkareasByName = !sortWorkareasByName;
                    workareasLabel.setText(sortWorkareasByName ? "Workareas (A-Z)" : "Workareas (click to sort)");
                    if (liveConnection != null) {
                        liveConnection.requestWorkareaUpdate();
                    }
                }
            });
            treeHeaderPanel.add(workareasLabel);
            leftPanel.add(treeHeaderPanel, BorderLayout.NORTH);
            leftPanel.add(new JBScrollPane(workareaTree), BorderLayout.CENTER);

            // Create split pane with tree on left, details on right
            JSplitPane splitPane = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT);
            splitPane.setLeftComponent(leftPanel);
            splitPane.setRightComponent(rightPanel);
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
            recordRowOrder.clear();
            waitingForWorkarea = null;
            waitingForDataType = null;
            pendingRequests.clear();
            currentWorkarea = null;
            updateNavigationButtons();
            
            this.liveConnection = connection;
            connection.addWorkareaUpdateListener(this);

            // Ensure monitoring is started (safe to call multiple times)
            connection.startMonitoring();

            updateStatus("Connected to debugging session");

            HarbourLogger.log("HarbourDBFToolWindow", "Connected to live debugging session, cache cleared");

            // Auto-refresh workareas on connect and reset auto-select flag
            autoSelectOnFirstLoad = true;
            SwingUtilities.invokeLater(() -> {
                if (liveConnection != null) {
                    liveConnection.requestWorkareaUpdate();
                    HarbourLogger.log("HarbourDBFToolWindow", "Auto-refreshed workareas on connection");
                }
            });
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
                recordRowOrder.clear();
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

                // Remember if "Current Record" was selected before tree rebuild
                String selectedWorkarea = null;
                boolean currentRecordWasSelected = false;

                TreePath selectionPath = workareaTree.getSelectionPath();
                if (selectionPath != null) {
                    DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                    if (selectedNode != null && selectedNode.getUserObject() != null) {
                        String nodeText = selectedNode.getUserObject().toString();
                        if (nodeText.equals("Current Record")) {
                            currentRecordWasSelected = true;
                            // Get parent workarea
                            TreeNode parentNode = selectedNode.getParent();
                            if (parentNode instanceof DefaultMutableTreeNode) {
                                Object parentObj = ((DefaultMutableTreeNode) parentNode).getUserObject();
                                if (parentObj instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                                    selectedWorkarea = ((HarbourLiveDBFConnection.WorkareaInfo) parentObj).getAlias();
                                }
                            }
                        }
                    }
                }

                HarbourLogger.log("HarbourDBFToolWindow",
                    "Before tree update: currentRecordWasSelected=" + currentRecordWasSelected +
                    ", workarea=" + selectedWorkarea);

                // Update the tree
                updateWorkareaTree(workareas);

                if (workareas.isEmpty()) {
                    updateStatus("Connected - No database files are currently open");
                    // Clear the details view since no workareas are open
                    List<String[]> emptyData = new ArrayList<>();
                    emptyData.add(new String[]{"No database files open", ""});
                    tableModel.setData(emptyData);
                    HarbourLogger.log("HarbourDBFToolWindow", "Cleared details view - no workareas open");
                } else {
                    updateStatus(String.format("Connected - %d workarea(s) open", workareas.size()));
                    HarbourLogger.log("HarbourDBFToolWindow", "*** Updated status to show " + workareas.size() + " workarea(s)");

                    // Auto-select program's current workarea on first load
                    if (!currentRecordWasSelected && autoSelectOnFirstLoad && liveConnection != null) {
                        autoSelectOnFirstLoad = false;  // Only auto-select once
                        // Auto-select the program's currently selected workarea (from SELECT())
                        // Fall back to first workarea if none is selected
                        HarbourLiveDBFConnection.WorkareaInfo targetWorkarea = liveConnection.getCurrentSelectedWorkarea();
                        if (targetWorkarea == null) {
                            targetWorkarea = workareas.iterator().next();
                        }
                        final String targetAlias = targetWorkarea.getAlias();
                        HarbourLogger.log("HarbourDBFToolWindow",
                            "Auto-selecting program's current workarea: " + targetAlias);

                        SwingUtilities.invokeLater(() -> {
                            DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
                            for (int i = 0; i < rootNode.getChildCount(); i++) {
                                DefaultMutableTreeNode child = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                                if (child.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                                    HarbourLiveDBFConnection.WorkareaInfo info =
                                        (HarbourLiveDBFConnection.WorkareaInfo) child.getUserObject();
                                    if (info.getAlias().equals(targetAlias)) {
                                        // Expand the workarea node
                                        TreePath workareaPath = new TreePath(child.getPath());
                                        workareaTree.expandPath(workareaPath);

                                        // Find and select "Current Record" child node
                                        for (int j = 0; j < child.getChildCount(); j++) {
                                            DefaultMutableTreeNode childNode =
                                                (DefaultMutableTreeNode) child.getChildAt(j);
                                            if (childNode.getUserObject().toString().equals("Current Record")) {
                                                TreePath recordPath = new TreePath(childNode.getPath());
                                                workareaTree.setSelectionPath(recordPath);
                                                HarbourLogger.log("HarbourDBFToolWindow",
                                                    "Auto-selected Current Record for " + targetAlias);
                                                break;
                                            }
                                        }
                                        break;
                                    }
                                }
                            }
                        });
                    } else if (!currentRecordWasSelected) {
                        List<String[]> selectData = new ArrayList<>();
                        selectData.add(new String[]{"Select a workarea to view details", ""});
                        tableModel.setData(selectData);
                        HarbourLogger.log("HarbourDBFToolWindow", "Cleared 'No database files open' message - showing selection prompt");
                    }
                }

                // IMPORTANT: If "Current Record" was selected, restore selection and refresh
                if (currentRecordWasSelected && selectedWorkarea != null && !workareas.isEmpty()) {
                    // Find the workarea in the new tree
                    for (HarbourLiveDBFConnection.WorkareaInfo wa : workareas) {
                        if (wa.getAlias().equals(selectedWorkarea)) {
                            HarbourLogger.log("HarbourDBFToolWindow",
                                "Restoring Current Record selection and refreshing for " + selectedWorkarea);

                            // CRITICAL: Invalidate cached record data so onWorkareaSelected() requests fresh data
                            WorkareaCache cache = dataCache.get(selectedWorkarea);
                            if (cache != null) {
                                cache.recordData = null;
                                HarbourLogger.log("HarbourDBFToolWindow",
                                    "Invalidated cached record data for " + selectedWorkarea + " to force fresh request");
                            }

                            // Use invokeLater to ensure tree is fully updated first
                            final String finalWorkarea = selectedWorkarea;
                            SwingUtilities.invokeLater(() -> {
                                // Find and select the "Current Record" node in the tree
                                DefaultMutableTreeNode rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
                                for (int i = 0; i < rootNode.getChildCount(); i++) {
                                    DefaultMutableTreeNode child = (DefaultMutableTreeNode) rootNode.getChildAt(i);
                                    if (child.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                                        HarbourLiveDBFConnection.WorkareaInfo info =
                                            (HarbourLiveDBFConnection.WorkareaInfo) child.getUserObject();
                                        if (info.getAlias().equals(finalWorkarea)) {
                                            // Expand the workarea node
                                            TreePath workareaPath = new TreePath(child.getPath());
                                            workareaTree.expandPath(workareaPath);

                                            // Find the "Current Record" child node
                                            for (int j = 0; j < child.getChildCount(); j++) {
                                                DefaultMutableTreeNode childNode =
                                                    (DefaultMutableTreeNode) child.getChildAt(j);
                                                if (childNode.getUserObject().toString().equals("Current Record")) {
                                                    // Select it
                                                    TreePath recordPath = new TreePath(childNode.getPath());
                                                    workareaTree.setSelectionPath(recordPath);

                                                    HarbourLogger.log("HarbourDBFToolWindow",
                                                        "Restored selection to Current Record for " + finalWorkarea);

                                                    // Trigger refresh - this will happen via onWorkareaSelected()
                                                    // which is called automatically when selection changes
                                                    break;
                                                }
                                            }
                                            break;
                                        }
                                    }
                                }
                            });
                            break;
                        }
                    }
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

            // Sort workareas if sorting is enabled
            List<HarbourLiveDBFConnection.WorkareaInfo> sortedWorkareas = new ArrayList<>(workareas);
            if (sortWorkareasByName) {
                sortedWorkareas.sort(Comparator.comparing(
                    HarbourLiveDBFConnection.WorkareaInfo::getAlias,
                    String.CASE_INSENSITIVE_ORDER));
            }

            for (HarbourLiveDBFConnection.WorkareaInfo workarea : sortedWorkareas) {
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
                        currentWorkarea = alias;
                        updateNavigationButtons();
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
                        }
                    } else if (nodeText.equals("Table Grid View")) {
                        HarbourLogger.log("HarbourDBFToolWindow", "*** TABLE GRID VIEW SELECTED for " + alias);
                        currentWorkarea = alias;
                        updateNavigationButtons();
                        setCurrentViewType("Grid");
                        // Track loading request ID and show indicator
                        currentGridLoadingRequestId = System.currentTimeMillis();
                        showGridLoadingIndicator(true);
                        // Load records when user clicks Grid View
                        waitingForWorkarea = alias;
                        waitingForDataType = "Records";
                        pendingRequests.put(alias + ":Records", currentGridLoadingRequestId);
                        int currentRec = workarea != null ? workarea.getCurrentRecord() : 1;
                        int recordCount = (Integer) gridRecordCountSpinner.getValue();
                        // Show loading message
                        showLoadingMessage(recordCount + " records... Please wait.");
                        HarbourLogger.log("HarbourDBFToolWindow", "Loading " + recordCount + " records for grid view");
                        liveConnection.requestRecords(alias, currentRec, recordCount);
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
                
                // Check what view we're in and refresh accordingly
                TreePath selectionPath = workareaTree.getSelectionPath();
                if (selectionPath != null) {
                    DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                    if (selectedNode != null && selectedNode.getUserObject() != null) {
                        boolean isCurrentRecord = false;
                        boolean isGridView = false;
                        
                        // Check if it's a workarea node (defaults to current record)
                        if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                            isCurrentRecord = true;
                        } else {
                            String nodeText = selectedNode.getUserObject().toString();
                            isCurrentRecord = nodeText.equals("Current Record");
                            isGridView = nodeText.equals("Table Grid View");
                        }
                        
                        if (isCurrentRecord) {
                            // Request updated record data to refresh the display
                            liveConnection.requestRecordData(currentWorkarea);
                        } else if (isGridView) {
                            // Refresh grid view with new position
                            HarbourSettings settings = HarbourSettings.getInstance(project);
                            int recordCount = settings.getMaxGridPreloadResults();

                            // Clear any pending request for this workarea to avoid duplicates
                            String requestKey = currentWorkarea + ":Records";
                            if (pendingRequests.containsKey(requestKey)) {
                                pendingRequests.remove(requestKey);
                            }

                            // Track loading request ID and show indicator
                            currentGridLoadingRequestId = System.currentTimeMillis();
                            showGridLoadingIndicator(true);

                            // Request records starting from new position
                            waitingForWorkarea = currentWorkarea;
                            waitingForDataType = "Records";
                            pendingRequests.put(requestKey, currentGridLoadingRequestId);
                            liveConnection.requestRecords(currentWorkarea, recordNumber, recordCount);
                        }
                    }
                }
                
                updateNavigationButtons();
                
                // Keep focus in the spinner field after navigation
                // Use SwingUtilities.invokeLater to ensure all UI updates are complete
                SwingUtilities.invokeLater(() -> {
                    // Additional delay to ensure model update is complete
                    Timer focusTimer = new Timer(100, e -> {
                        JComponent editor = recordSpinner.getEditor();
                        if (editor instanceof JSpinner.DefaultEditor) {
                            JTextField textField = ((JSpinner.DefaultEditor) editor).getTextField();
                            textField.requestFocusInWindow();
                            textField.selectAll(); // Select all text for easy typing of next number
                        }
                    });
                    focusTimer.setRepeats(false);
                    focusTimer.start();
                });
            }
        }
        
        // Removed loadAllRecords method per user request
        
        /**
         * Setup Enter key handling for the record spinner
         * This needs to be called after any model change as it recreates the editor
         */
        private void setupSpinnerEnterKeyHandling() {
            JComponent editor = recordSpinner.getEditor();
            
            if (editor instanceof JSpinner.DefaultEditor) {
                JFormattedTextField textField = ((JSpinner.DefaultEditor) editor).getTextField();
                
                // Clear existing listeners first to avoid duplicates
                for (var listener : textField.getActionListeners()) {
                    textField.removeActionListener(listener);
                }
                
                // Single ActionListener for Enter key
                textField.addActionListener(e -> {
                    try {
                        recordSpinner.commitEdit(); // Ensure the value is committed
                        navigateToRecord();
                    } catch (ParseException ex) {
                        HarbourLogger.log("HarbourDBFToolWindow", "Invalid record number input: " + ex.getMessage());
                    }
                });
            }
        }

        /**
         * Setup Enter key handling for the grid record count spinner
         */
        private void setupGridSpinnerEnterKeyHandling() {
            JComponent editor = gridRecordCountSpinner.getEditor();

            if (editor instanceof JSpinner.DefaultEditor) {
                JFormattedTextField textField = ((JSpinner.DefaultEditor) editor).getTextField();

                // Use InputMap/ActionMap for reliable Enter key handling
                textField.getInputMap(JComponent.WHEN_FOCUSED).put(
                    KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, 0), "loadGridRecords");
                textField.getActionMap().put("loadGridRecords", new AbstractAction() {
                    @Override
                    public void actionPerformed(java.awt.event.ActionEvent e) {
                        try {
                            gridRecordCountSpinner.commitEdit();
                            HarbourLogger.log("HarbourDBFToolWindow", "Grid spinner Enter key pressed, loading records");
                            loadGridRecords();
                        } catch (ParseException ex) {
                            HarbourLogger.log("HarbourDBFToolWindow", "Invalid record count input: " + ex.getMessage());
                        }
                    }
                });
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
                    // Request records again - track loading request ID
                    currentGridLoadingRequestId = System.currentTimeMillis();
                    showGridLoadingIndicator(true);
                    showLoadingMessage("Table Grid View");
                    waitingForWorkarea = currentWorkarea;
                    waitingForDataType = "Records";
                    pendingRequests.put(currentWorkarea + ":Records", currentGridLoadingRequestId);
                    // Get current record position for reload
                    HarbourLiveDBFConnection.WorkareaInfo workarea = liveConnection.getWorkarea(currentWorkarea);
                    int currentRec = workarea != null ? workarea.getCurrentRecord() : 1;
                    // Start at current record, get records from settings
                    HarbourSettings settings = HarbourSettings.getInstance(project);
                    int recordCount = settings.getMaxGridPreloadResults();
                    HarbourLogger.log("HarbourDBFToolWindow", "Reload using grid preload setting: " + recordCount + " records");
                    liveConnection.requestRecords(currentWorkarea, currentRec, recordCount);
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
                // Removed gotoButton and loadAllButton
                recordSpinner.setEnabled(false);
                totalRecordsLabel.setText("");
                // Update header with program's currently selected workarea (not tree selection)
                updateProgramSelectedInfo();
                return;
            }

            // Update header with program's currently selected workarea (not tree selection)
            updateProgramSelectedInfo();

            HarbourLiveDBFConnection.WorkareaInfo workarea = liveConnection.getWorkarea(currentWorkarea);
            if (workarea != null) {
                int currentRecord = workarea.getCurrentRecord();
                int totalRecords = workarea.getTotalRecords();

                // Check what view is selected - only enable navigation for Current Record and Table Grid View
                boolean navigationEnabled = false;
                TreePath selectionPath = workareaTree.getSelectionPath();
                if (selectionPath != null) {
                    DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                    if (selectedNode != null && selectedNode.getUserObject() != null) {
                        // Check if it's a workarea node (defaults to Current Record view)
                        if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                            HarbourLiveDBFConnection.WorkareaInfo selectedWorkarea =
                                (HarbourLiveDBFConnection.WorkareaInfo) selectedNode.getUserObject();
                            // Enable navigation if this is the current workarea
                            navigationEnabled = selectedWorkarea.getAlias().equals(currentWorkarea);
                        } else {
                            // Check specific child node selections
                            String nodeText = selectedNode.getUserObject().toString();
                            navigationEnabled = nodeText.equals("Current Record") || nodeText.equals("Table Grid View");
                        }
                    }
                }

                // Enable/disable navigation based on view and record position
                prevButton.setEnabled(navigationEnabled && currentRecord > 1);
                nextButton.setEnabled(navigationEnabled && currentRecord < totalRecords);
                recordSpinner.setEnabled(navigationEnabled && totalRecords > 0);

                // Update spinner model
                if (totalRecords > 0) {
                    // Ensure currentRecord is within valid range [1, totalRecords]
                    // Harbour can return 0 (BOF) or totalRecords+1 (EOF)
                    int validRecord = Math.max(1, Math.min(currentRecord, totalRecords));
                    recordSpinner.setModel(new SpinnerNumberModel(validRecord, 1, totalRecords, 1));
                    // IMPORTANT: Re-setup Enter key handling after model change
                    setupSpinnerEnterKeyHandling();
                    // Format with thousand separator
                    String formattedTotal = String.format("%,d", totalRecords);
                    totalRecordsLabel.setText("Total: " + formattedTotal);
                } else {
                    totalRecordsLabel.setText("");
                }
            }
        }

        /**
         * Update the header info label with the program's currently selected workarea
         * This shows what SELECT() returns in the Harbour program, not what's selected in tree
         */
        private void updateProgramSelectedInfo() {
            if (liveConnection == null) {
                currentInfoLabel.setText("");
                return;
            }

            HarbourLiveDBFConnection.WorkareaInfo programSelected = liveConnection.getCurrentSelectedWorkarea();
            if (programSelected != null) {
                String formattedRecno = String.format("%,d", programSelected.getCurrentRecord());
                StringBuilder info = new StringBuilder();
                info.append("Selected: ").append(programSelected.getAlias())
                    .append(" [").append(formattedRecno).append("]");
                // Add EOF/DELETED flags
                if (programSelected.isEof()) {
                    info.append(" EOF");
                }
                if (programSelected.isDeleted()) {
                    info.append(" DEL");
                }
                currentInfoLabel.setText(info.toString());
            } else {
                int areaNum = liveConnection.getCurrentSelectedArea();
                if (areaNum > 0) {
                    currentInfoLabel.setText("Selected: Area " + areaNum);
                } else {
                    currentInfoLabel.setText("");
                }
            }
        }

        /**
         * Apply filters and sorting to the displayed data
         */
        private void applyFilters() {
            if (unfilteredData == null || unfilteredData.isEmpty()) {
                return;
            }

            String nameFilter = filterNameField.getText().toLowerCase().trim();
            String valueFilter = filterValueField.getText().toLowerCase().trim();

            List<String[]> resultData = new ArrayList<>();

            // Apply filters
            for (String[] row : unfilteredData) {
                boolean matchesName = nameFilter.isEmpty() ||
                    (row.length > 0 && row[0] != null && row[0].toLowerCase().contains(nameFilter));
                boolean matchesValue = valueFilter.isEmpty() ||
                    (row.length > 1 && row[1] != null && row[1].toLowerCase().contains(valueFilter));

                if (matchesName && matchesValue) {
                    resultData.add(row);
                }
            }

            // Apply sorting based on column sort state (0=none, 1=asc, 2=desc)
            int propSortState = tableModel.getPropertySortState();
            int valueSortState = tableModel.getValueSortState();

            if (propSortState > 0 && !resultData.isEmpty()) {
                final boolean ascending = (propSortState == 1);
                resultData.sort((a, b) -> {
                    String nameA = (a.length > 0 && a[0] != null) ? a[0] : "";
                    String nameB = (b.length > 0 && b[0] != null) ? b[0] : "";
                    int cmp = nameA.compareToIgnoreCase(nameB);
                    return ascending ? cmp : -cmp;
                });
            } else if (valueSortState > 0 && !resultData.isEmpty()) {
                final boolean ascending = (valueSortState == 1);
                resultData.sort((a, b) -> {
                    String valA = (a.length > 1 && a[1] != null) ? a[1] : "";
                    String valB = (b.length > 1 && b[1] != null) ? b[1] : "";
                    int cmp = valA.compareToIgnoreCase(valB);
                    return ascending ? cmp : -cmp;
                });
            } else if ("Record".equals(currentViewType) && currentWorkarea != null
                    && recordRowOrder.containsKey(currentWorkarea) && !resultData.isEmpty()) {
                // Apply user-defined row order; rows missing from the saved order keep
                // their original (relative) position by getting a max-int rank
                List<String> order = recordRowOrder.get(currentWorkarea);
                Map<String, Integer> rank = new HashMap<>();
                for (int i = 0; i < order.size(); i++) {
                    rank.put(order.get(i), i);
                }
                resultData.sort((a, b) -> {
                    String nameA = (a.length > 0 && a[0] != null) ? a[0] : "";
                    String nameB = (b.length > 0 && b[0] != null) ? b[0] : "";
                    int posA = rank.getOrDefault(nameA, Integer.MAX_VALUE);
                    int posB = rank.getOrDefault(nameB, Integer.MAX_VALUE);
                    return Integer.compare(posA, posB);
                });
            }

            tableModel.setData(resultData);
        }

        /**
         * Build the canonical full-attribute order for the current workarea.
         * Starts from the saved custom order (if any), then appends any names from
         * unfilteredData that are not yet covered. Returns a fresh, mutable list.
         */
        private List<String> buildFullOrder() {
            List<String> all = new ArrayList<>();
            List<String> saved = recordRowOrder.get(currentWorkarea);
            if (saved != null) {
                all.addAll(saved);
            }
            if (unfilteredData != null) {
                for (String[] row : unfilteredData) {
                    String name = (row.length > 0 && row[0] != null) ? row[0] : "";
                    if (!name.isEmpty() && !all.contains(name)) {
                        all.add(name);
                    }
                }
            }
            return all;
        }

        /**
         * Move the given attribute name to the top of the custom order, then re-render.
         */
        private void moveAttributeToTop(@NotNull String name) {
            if (currentWorkarea == null || name.isEmpty()) return;
            List<String> order = buildFullOrder();
            order.remove(name);
            order.add(0, name);
            recordRowOrder.put(currentWorkarea, order);
            resetSortAndApply();
        }

        /**
         * Move the given attribute name to the bottom of the custom order, then re-render.
         */
        private void moveAttributeToBottom(@NotNull String name) {
            if (currentWorkarea == null || name.isEmpty()) return;
            List<String> order = buildFullOrder();
            order.remove(name);
            order.add(name);
            recordRowOrder.put(currentWorkarea, order);
            resetSortAndApply();
        }

        /**
         * Insert sourceName immediately before targetName in the custom order, then re-render.
         */
        private void moveAttributeBefore(@NotNull String sourceName, @NotNull String targetName) {
            if (currentWorkarea == null || sourceName.isEmpty() || targetName.isEmpty()) return;
            if (sourceName.equals(targetName)) return;
            List<String> order = buildFullOrder();
            order.remove(sourceName);
            int targetIdx = order.indexOf(targetName);
            if (targetIdx < 0) {
                order.add(sourceName);
            } else {
                order.add(targetIdx, sourceName);
            }
            recordRowOrder.put(currentWorkarea, order);
            resetSortAndApply();
        }

        /**
         * Drop any custom order for the current workarea and re-render.
         */
        private void resetRowOrder() {
            if (currentWorkarea == null) return;
            recordRowOrder.remove(currentWorkarea);
            resetSortAndApply();
        }

        /**
         * Reset column-sort state (custom order only kicks in when no column sort is active),
         * then re-apply filters so the table redraws.
         */
        private void resetSortAndApply() {
            sortColumnsByName = false;
            sortColumnsByValue = false;
            tableModel.resetSortState();
            applyFilters();
        }

        /**
         * Return the attribute name (Property column) for the given visible row,
         * or null if the row index is out of range.
         */
        private String attributeNameAt(int viewRow) {
            if (viewRow < 0 || viewRow >= detailsTable.getRowCount()) return null;
            Object v = detailsTable.getValueAt(viewRow, 0);
            return v == null ? null : v.toString();
        }

        /**
         * True when row reordering (drag/drop and context menu) is meaningful:
         * only the Record view operates on a stable per-attribute name list.
         */
        private boolean isRecordView() {
            return "Record".equals(currentViewType);
        }

        /**
         * Install drag-and-drop and right-click handlers on the details table so the
         * user can reorder attribute rows in the Record view.
         */
        private void installRowReorderHandlers() {
            JPopupMenu rowMenu = new JPopupMenu();
            JMenuItem topItem = new JMenuItem("Move to Top");
            JMenuItem bottomItem = new JMenuItem("Move to Bottom");
            JMenuItem resetItem = new JMenuItem("Reset Order");
            rowMenu.add(topItem);
            rowMenu.add(bottomItem);
            rowMenu.addSeparator();
            rowMenu.add(resetItem);

            topItem.addActionListener(e -> {
                String name = attributeNameAt(detailsTable.getSelectedRow());
                if (name != null) moveAttributeToTop(name);
            });
            bottomItem.addActionListener(e -> {
                String name = attributeNameAt(detailsTable.getSelectedRow());
                if (name != null) moveAttributeToBottom(name);
            });
            resetItem.addActionListener(e -> resetRowOrder());

            java.awt.event.MouseAdapter handler = new java.awt.event.MouseAdapter() {
                @Override
                public void mousePressed(java.awt.event.MouseEvent e) {
                    if (!isRecordView()) return;
                    int row = detailsTable.rowAtPoint(e.getPoint());
                    if (row >= 0) {
                        detailsTable.setRowSelectionInterval(row, row);
                    }
                    if (e.isPopupTrigger() && row >= 0) {
                        rowMenu.show(detailsTable, e.getX(), e.getY());
                        return;
                    }
                    if (SwingUtilities.isLeftMouseButton(e) && row >= 0) {
                        dragSourceRow = row;
                    }
                }

                @Override
                public void mouseDragged(java.awt.event.MouseEvent e) {
                    if (!isRecordView() || dragSourceRow < 0) return;
                    detailsTable.setCursor(Cursor.getPredefinedCursor(Cursor.MOVE_CURSOR));
                }

                @Override
                public void mouseReleased(java.awt.event.MouseEvent e) {
                    detailsTable.setCursor(Cursor.getDefaultCursor());
                    if (e.isPopupTrigger()) {
                        int row = detailsTable.rowAtPoint(e.getPoint());
                        if (isRecordView() && row >= 0) {
                            detailsTable.setRowSelectionInterval(row, row);
                            rowMenu.show(detailsTable, e.getX(), e.getY());
                        }
                        dragSourceRow = -1;
                        return;
                    }
                    if (!isRecordView() || dragSourceRow < 0) {
                        dragSourceRow = -1;
                        return;
                    }
                    int targetRow = detailsTable.rowAtPoint(e.getPoint());
                    int source = dragSourceRow;
                    dragSourceRow = -1;
                    if (targetRow < 0 || targetRow == source) return;
                    String sourceName = attributeNameAt(source);
                    String targetName = attributeNameAt(targetRow);
                    if (sourceName == null || targetName == null) return;
                    moveAttributeBefore(sourceName, targetName);
                }
            };
            detailsTable.addMouseListener(handler);
            detailsTable.addMouseMotionListener(handler);
        }

        /**
         * Clear all filters and show full data
         */
        private void clearFilters() {
            filterNameField.setText("");
            filterValueField.setText("");
            if (unfilteredData != null) {
                tableModel.setData(unfilteredData);
            }
        }

        /**
         * Store unfiltered data and apply current filters
         */
        private void setDataWithFiltering(List<String[]> data) {
            unfilteredData = new ArrayList<>(data);
            applyFilters();
        }

        /**
         * Check if sorting is allowed for the current view (not Schema Info or Indexes)
         */
        private boolean isSortingAllowedForCurrentView() {
            return currentViewType != null &&
                !currentViewType.equals("Schema") &&
                !currentViewType.equals("Indexes");
        }

        /**
         * Show/hide the grid view record count controls
         */
        private void setGridControlsVisible(boolean visible) {
            if (separatorLabel != null) separatorLabel.setVisible(visible);
            if (gridRecordLabel != null) gridRecordLabel.setVisible(visible);
            if (gridRecordCountSpinner != null) gridRecordCountSpinner.setVisible(visible);
            if (gridEnterLabel != null) gridEnterLabel.setVisible(visible);
        }

        /**
         * Show/hide navigation controls (Previous, Next, Go to, etc.)
         */
        private void setNavigationControlsVisible(boolean visible) {
            if (prevButton != null) prevButton.setVisible(visible);
            if (nextButton != null) nextButton.setVisible(visible);
            if (gotoLabel != null) gotoLabel.setVisible(visible);
            if (recordSpinner != null) recordSpinner.setVisible(visible);
            if (enterLabel != null) enterLabel.setVisible(visible);
            if (totalRecordsLabel != null) totalRecordsLabel.setVisible(visible);
        }

        /**
         * Show/hide the filter panel (hidden for Grid view since it has many columns)
         */
        private void setFilterPanelVisible(boolean visible) {
            if (filterPanel != null) {
                filterPanel.setVisible(visible);
            }
        }

        /**
         * Load grid records with user-specified count
         */
        private void loadGridRecords() {
            if (currentWorkarea == null || liveConnection == null) return;

            HarbourLiveDBFConnection.WorkareaInfo workarea = liveConnection.getWorkarea(currentWorkarea);
            if (workarea == null) return;

            int currentRec = workarea.getCurrentRecord();
            int recordCount = (Integer) gridRecordCountSpinner.getValue();
            int totalRecords = workarea.getTotalRecords();

            // Show loading indicator and track request ID
            currentGridLoadingRequestId = System.currentTimeMillis();
            showGridLoadingIndicator(true);

            // Show appropriate loading message (don't include "Loading" - showLoadingMessage adds it)
            String loadingMsg;
            if (recordCount == 0) {
                loadingMsg = "all " + String.format("%,d", totalRecords) + " records... Please wait.";
            } else {
                loadingMsg = recordCount + " records... Please wait.";
            }
            showLoadingMessage(loadingMsg);

            waitingForWorkarea = currentWorkarea;
            waitingForDataType = "Records";
            pendingRequests.put(currentWorkarea + ":Records", currentGridLoadingRequestId);
            liveConnection.requestRecords(currentWorkarea, currentRec, recordCount);

            HarbourLogger.log("HarbourDBFToolWindow",
                "User requested grid load: " + currentWorkarea + " from " + currentRec + ", count " + recordCount);
        }

        /**
         * Show/hide the grid loading indicator
         */
        private void showGridLoadingIndicator(boolean show) {
            HarbourLogger.log("HarbourDBFToolWindow", ">>> showGridLoadingIndicator(" + show +
                ") - currentRequestId=" + currentGridLoadingRequestId +
                ", stacktrace=" + Thread.currentThread().getStackTrace()[2]);
            if (gridLoadingLabel != null) {
                gridLoadingLabel.setVisible(show);
            }
        }

        /**
         * Hide loading indicator only if the given request ID matches the current active request.
         * Uses Timer with 200ms delay to ensure Swing has completed all painting.
         */
        private void hideLoadingIndicatorIfActive(long requestId) {
            HarbourLogger.log("HarbourDBFToolWindow", ">>> hideLoadingIndicatorIfActive(requestId=" + requestId +
                ") - currentRequestId=" + currentGridLoadingRequestId);
            if (requestId != 0 && requestId == currentGridLoadingRequestId) {
                HarbourLogger.log("HarbourDBFToolWindow", ">>> hideLoadingIndicatorIfActive - IDs match, scheduling hide with 200ms delay");
                // Use Timer with delay to ensure painting is complete
                Timer hideTimer = new Timer(200, e -> {
                    HarbourLogger.log("HarbourDBFToolWindow", ">>> hideLoadingIndicatorIfActive - Timer fired, checking IDs: requestId=" +
                        requestId + ", currentRequestId=" + currentGridLoadingRequestId);
                    if (requestId == currentGridLoadingRequestId) {
                        showGridLoadingIndicator(false);
                    } else {
                        HarbourLogger.log("HarbourDBFToolWindow", ">>> hideLoadingIndicatorIfActive - IDs no longer match, NOT hiding");
                    }
                });
                hideTimer.setRepeats(false);
                hideTimer.start();
            } else {
                HarbourLogger.log("HarbourDBFToolWindow", ">>> hideLoadingIndicatorIfActive - IDs don't match or requestId=0, NOT hiding");
            }
        }

        /**
         * Update the view type and table model sort indicator visibility
         */
        private void setCurrentViewType(String viewType) {
            this.currentViewType = viewType;

            boolean isGridView = "Grid".equals(viewType);

            // Show/hide grid controls based on view type
            setGridControlsVisible(isGridView);

            // Show/hide filter panel based on view type (hide for Grid view)
            setFilterPanelVisible(!isGridView);

            // Hide record navigation in Grid view (not really needed there)
            setNavigationControlsVisible(!isGridView);

            boolean sortingAllowed = isSortingAllowedForCurrentView();
            if (sortingAllowed) {
                tableModel.setSortingEnabled(true);
            } else {
                tableModel.setSortingEnabled(false);
                // Reset sort state when entering non-sortable view
                sortColumnsByName = false;
                sortColumnsByValue = false;
            }
        }

        /**
         * Show basic workarea details in the details table - DEFAULT: show current record data
         */
        private void showWorkareaDetails(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea) {
            String alias = workarea.getAlias();
            WorkareaCache cache = dataCache.computeIfAbsent(alias, k -> new WorkareaCache());
            
            // Set current workarea immediately
            currentWorkarea = alias;
            updateNavigationButtons();
            
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
            }
        }
        
        /**
         * Show instructions for Grid View (before loading)
         */
        private void showGridViewInstructions() {
            setCurrentViewType("Grid");
            int recordCount = (Integer) gridRecordCountSpinner.getValue();
            List<String[]> data = new ArrayList<>();
            data.add(new String[]{"Table Grid View", ""});
            data.add(new String[]{"", ""});
            data.add(new String[]{"Enter number of records to load", "in the 'Load:' field above"});
            data.add(new String[]{"(0 = load all records)", ""});
            data.add(new String[]{"", ""});
            data.add(new String[]{"Press Enter to load", recordCount + " records"});
            tableModel.setData(data);
            unfilteredData = new ArrayList<>(data);
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
            project.getMessageBus().connect(project).subscribe(XDebuggerManager.TOPIC, new XDebuggerManagerListener() {
                @Override
                public void processStarted(@NotNull XDebugProcess debugProcess) {
                    // Check if this is a Harbour debug process
                    if (debugProcess instanceof HarbourDebuggerRemoteProcess) {
                        HarbourDebuggerRemoteProcess harbourProcess = (HarbourDebuggerRemoteProcess) debugProcess;
                        HarbourLiveDBFConnection dbfConnection = harbourProcess.getLiveDBFConnection();
                        if (dbfConnection != null) {
                            connectToDebuggingSession(dbfConnection);
                            HarbourLogger.log("HarbourDBFToolWindow", "Auto-connected to Harbour debugging session");

                            // Add session listener to refresh DBF view on each step/pause
                            XDebugSession session = debugProcess.getSession();
                            setupStepListener(session);

                            // If already suspended (first breakpoint already hit), trigger immediate refresh
                            // This handles the case where processStarted fires after first breakpoint
                            if (session.isSuspended()) {
                                HarbourLogger.log("HarbourDBFToolWindow",
                                    "Session already suspended on processStarted - triggering DBF refresh");
                                SwingUtilities.invokeLater(() -> {
                                    if (liveConnection != null) {
                                        liveConnection.requestWorkareaUpdate();
                                    }
                                });
                            }
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
         * Setup listener to refresh DBF view when debugger steps/pauses
         */
        private void setupStepListener(@NotNull XDebugSession session) {
            session.addSessionListener(new XDebugSessionListener() {
                @Override
                public void sessionPaused() {
                    // Only refresh if session is actually paused (not running)
                    // This prevents refreshing during rapid stepping or continuous execution
                    if (session.isSuspended()) {
                        // Always request workarea update - the visibility check was causing
                        // issues with first-time loading. The workareas request is lightweight.
                        String visibility = toolWindow.isVisible() ? "visible" : "hidden";
                        HarbourLogger.log("HarbourDBFToolWindow",
                            "Session paused - triggering ASYNC DBF refresh (window " + visibility + ")");

                        // Request fresh workarea list asynchronously
                        // This will call onWorkareasUpdated() when complete
                        if (liveConnection != null) {
                            liveConnection.requestWorkareaUpdate();
                        }
                    } else {
                        HarbourLogger.log("HarbourDBFToolWindow",
                            "Session paused event but not suspended - skipping auto-refresh");
                    }
                }

                @Override
                public void sessionResumed() {
                    // Don't refresh when resuming - wait for next pause
                    HarbourLogger.log("HarbourDBFToolWindow", "Session resumed - no refresh");
                }
            });
        }

        /**
         * Refresh the current record view if it's currently selected
         * (Legacy method - kept for manual refresh operations)
         */
        private void refreshCurrentRecordViewIfSelected() {
            ApplicationManager.getApplication().invokeLater(() -> {
                // Only refresh if we have an active connection
                if (liveConnection == null) {
                    return;
                }

                TreePath selectionPath = workareaTree.getSelectionPath();
                if (selectionPath != null) {
                    DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                    if (selectedNode != null && selectedNode.getUserObject() != null) {
                        String nodeText = selectedNode.getUserObject().toString();

                        // Check if "Current Record" view is selected
                        if (nodeText.equals("Current Record")) {
                            // Get parent workarea node
                            TreeNode parentNode = selectedNode.getParent();
                            if (parentNode instanceof DefaultMutableTreeNode) {
                                Object parentObj = ((DefaultMutableTreeNode) parentNode).getUserObject();
                                if (parentObj instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                                    HarbourLiveDBFConnection.WorkareaInfo workarea =
                                        (HarbourLiveDBFConnection.WorkareaInfo) parentObj;

                                    HarbourLogger.log("HarbourDBFToolWindow",
                                        "Auto-refreshing Current Record view for " + workarea.getAlias());

                                    // Force fresh data request by calling reloadCurrentData
                                    reloadCurrentData();
                                }
                            }
                        }
                        // Also refresh if the workarea itself is selected (defaults to Current Record)
                        else if (selectedNode.getUserObject() instanceof HarbourLiveDBFConnection.WorkareaInfo) {
                            HarbourLiveDBFConnection.WorkareaInfo workarea =
                                (HarbourLiveDBFConnection.WorkareaInfo) selectedNode.getUserObject();

                            HarbourLogger.log("HarbourDBFToolWindow",
                                "Auto-refreshing workarea view for " + workarea.getAlias());

                            // Force fresh data request by calling reloadCurrentData
                            reloadCurrentData();
                        }
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

                        // Add session listener to refresh DBF view on each step/pause
                        setupStepListener(currentSession);

                        // If session is already paused/suspended, trigger immediate refresh
                        // (the sessionPaused listener won't fire for already-paused sessions)
                        if (currentSession.isSuspended()) {
                            HarbourLogger.log("HarbourDBFToolWindow",
                                "Session already suspended - triggering immediate DBF refresh");
                            if (liveConnection != null) {
                                liveConnection.requestWorkareaUpdate();
                            }
                        }
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

            setCurrentViewType("Fields");

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

            setDataWithFiltering(data);

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

            setCurrentViewType("Record");

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
                            fieldValue.length() >= 2 &&
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

            setDataWithFiltering(data);

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

            setCurrentViewType("Schema");

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

            setDataWithFiltering(data);

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
            
            // Process records data
            
            // Check if this is for the current grid view even without pending request
            boolean isCurrentGridView = false;
            if (currentWorkarea != null && currentWorkarea.equals(alias)) {
                TreePath selectionPath = workareaTree.getSelectionPath();
                if (selectionPath != null) {
                    DefaultMutableTreeNode selectedNode = (DefaultMutableTreeNode) selectionPath.getLastPathComponent();
                    if (selectedNode != null && selectedNode.getUserObject() != null) {
                        String nodeText = selectedNode.getUserObject().toString();
                        isCurrentGridView = nodeText.equals("Table Grid View");
                    }
                }
            }
            
            // Process if we have a pending request OR if this is the current grid view
            long requestIdForHide = 0;  // 0 means don't hide
            if (pendingRequests.containsKey(requestKey)) {
                Long requestTimestamp = pendingRequests.get(requestKey);
                shouldDisplay = true;
                pendingRequests.remove(requestKey);

                // Pass the request ID so we can verify it's still the active request when hiding
                if (requestTimestamp != null && requestTimestamp == currentGridLoadingRequestId) {
                    requestIdForHide = requestTimestamp;
                }

                if (waitingForWorkarea != null && waitingForWorkarea.equals(alias) && "Records".equals(waitingForDataType)) {
                    waitingForWorkarea = null;
                    waitingForDataType = null;
                }
            } else if (isCurrentGridView) {
                // Accept duplicate for current grid view to ensure UI updates
                shouldDisplay = true;
                // But don't hide loading indicator for duplicates - only for actual pending requests
            } else {
                // Ignore unexpected records
            }

            if (shouldDisplay) {
                // Pass the request ID - displayRecordsGrid will use it to verify before hiding
                displayRecordsGrid(workarea, recordsData, requestIdForHide);
            }
        }

        @Override
        public void onIndexesReceived(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] indexesData) {
            // Check if we should display this data
            String alias = workarea.getAlias();
            boolean shouldDisplay = false;
            String requestKey = alias + ":Indexes";
            
            // Process indexes data
            
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
         * @param requestId Request ID for this load operation. If non-zero and matches currentGridLoadingRequestId,
         *                  the loading indicator will be hidden after rendering. 0 means don't hide.
         */
        private void displayRecordsGrid(@NotNull HarbourLiveDBFConnection.WorkareaInfo workarea, @NotNull String[] recordsData, long requestId) {
            if (!SwingUtilities.isEventDispatchThread()) {
                SwingUtilities.invokeLater(() -> displayRecordsGrid(workarea, recordsData, requestId));
                return;
            }

            setCurrentViewType("Grid");

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
                    hideLoadingIndicatorIfActive(requestId);
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
                hideLoadingIndicatorIfActive(requestId);
                return;
            }

            // Create proper grid table - pass request ID for hiding indicator
            createAndSwitchToGridTable(columnNames, rows, requestId);
        }
        
        /**
         * Create a new JTable for grid view and switch to it
         * @param requestId The request ID - if non-zero and matches current, hide indicator after render
         */
        private void createAndSwitchToGridTable(List<String> columnNames, List<Map<String, String>> rows, long requestId) {
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

            // Hide loading indicator AFTER the grid is fully rendered
            // Use double invokeLater to ensure Swing has painted the table first
            // Only hide if this request is still the active one
            hideLoadingIndicatorIfActive(requestId);
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

            setCurrentViewType("Indexes");

            // Switch back to details table
            switchToDetailsTable();

            List<String[]> data = new ArrayList<>();
            
            String currentIndex = null;
            String currentName = null;
            String currentKey = null;
            String currentFor = null;
            String currentBag = null;
            String currentKeyNo = null;
            String currentKeyCount = null;
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
                } else if (line.startsWith("CURRENT_KEYNO:")) {
                    currentKeyNo = line.substring(14);
                } else if (line.startsWith("CURRENT_KEYCOUNT:")) {
                    currentKeyCount = line.substring(18);
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
                if (currentKeyNo != null && !currentKeyNo.isEmpty()) {
                    try {
                        String formattedKeyNo = String.format("%,d", Integer.parseInt(currentKeyNo));
                        data.add(new String[]{"Current Position:", formattedKeyNo});
                    } catch (NumberFormatException e) {
                        data.add(new String[]{"Current Position:", currentKeyNo});
                    }
                }
                if (currentKeyCount != null && !currentKeyCount.isEmpty()) {
                    try {
                        String formattedCount = String.format("%,d", Integer.parseInt(currentKeyCount));
                        data.add(new String[]{"Total Keys:", formattedCount});
                    } catch (NumberFormatException e) {
                        data.add(new String[]{"Total Keys:", currentKeyCount});
                    }
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

            setDataWithFiltering(data);
            detailsTable.repaint();
            detailsTable.revalidate();
        }
    }
    
    /**
     * Table model for displaying workarea details
     */
    private static class DetailsTableModel extends AbstractTableModel {

        private String[] columnNames = {"Property", "Value"};
        private List<String[]> data = new ArrayList<>();
        private boolean sortingEnabled = false;  // Whether sorting is allowed
        // 0 = no sort, 1 = ascending, 2 = descending
        private int propertySortState = 0;
        private int valueSortState = 0;

        // Sort indicator characters (subtle arrows)
        private static final String SORT_NONE = "";
        private static final String SORT_ASC = " \u25B5";  // Small up triangle
        private static final String SORT_DESC = " \u25BF"; // Small down triangle

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
            if (!sortingEnabled) {
                return columnNames[column];
            }
            if (column == 0) {
                return columnNames[column] + getSortIndicator(propertySortState);
            } else if (column == 1) {
                return columnNames[column] + getSortIndicator(valueSortState);
            }
            return columnNames[column];
        }

        private String getSortIndicator(int state) {
            switch (state) {
                case 1: return SORT_ASC;
                case 2: return SORT_DESC;
                default: return SORT_NONE;
            }
        }

        /**
         * Toggle sort state for a column (cycles: none -> asc -> desc -> none)
         * @param column 0 for Property, 1 for Value
         * @return the new sort state (0=none, 1=asc, 2=desc)
         */
        public int toggleSortState(int column) {
            if (column == 0) {
                propertySortState = (propertySortState + 1) % 3;
                valueSortState = 0;  // Reset other column
                fireTableStructureChanged();
                return propertySortState;
            } else if (column == 1) {
                valueSortState = (valueSortState + 1) % 3;
                propertySortState = 0;  // Reset other column
                fireTableStructureChanged();
                return valueSortState;
            }
            return 0;
        }

        public int getPropertySortState() { return propertySortState; }
        public int getValueSortState() { return valueSortState; }

        public void setSortingEnabled(boolean enabled) {
            this.sortingEnabled = enabled;
            if (!enabled) {
                propertySortState = 0;
                valueSortState = 0;
            }
            fireTableStructureChanged();
        }

        public void resetSortState() {
            propertySortState = 0;
            valueSortState = 0;
            fireTableStructureChanged();
        }

        // Legacy methods for compatibility
        public void setSortIndicator(boolean visible, boolean ascending) {
            // Convert old API to new
            this.sortingEnabled = visible;
            if (visible) {
                propertySortState = ascending ? 1 : 2;
            } else {
                propertySortState = 0;
            }
            valueSortState = 0;
            fireTableStructureChanged();
        }

        public void hideSortIndicator() {
            setSortingEnabled(false);
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
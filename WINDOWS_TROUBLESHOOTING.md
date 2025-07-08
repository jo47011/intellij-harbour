# Windows Plugin Loading Issue - Troubleshooting Guide

## Current Status
The Harbour plugin is NOT loading at all on Windows. This is confirmed by the complete absence of any diagnostic files that should be created immediately when the plugin loads.

## Diagnostic Files That Should Exist
If the plugin was loading, these files would be created:
- `harbour_plugin_loaded.txt` - Plugin constructor called
- `harbour_plugin_init.txt` - Plugin initComponent() called  
- `harbour_notification_test.txt` - Notification startup activity ran
- `harbour_startup_activity.txt` - Debug runner registration activity

## Possible Causes

### 1. Plugin Installation Issues
- Plugin ZIP file not properly installed
- IntelliJ Platform not recognizing the plugin
- Plugin file corrupted during installation

### 2. Plugin Dependencies Issues
- Missing required platform modules
- Incompatible IntelliJ Platform version
- Module dependency conflicts

### 3. Windows-Specific Issues
- File path/permission issues
- Antivirus software blocking plugin loading
- Windows defender blocking unknown plugins
- JVM security restrictions

### 4. Plugin.xml Configuration Issues
- Invalid plugin descriptor
- Incorrect extension point definitions
- Missing required plugin metadata

## Troubleshooting Steps

### Step 1: Verify Plugin Installation
1. Open IntelliJ IDEA
2. Go to File → Settings → Plugins
3. Look for "Harbour Language Support" in the installed plugins list
4. Check if it's enabled (checkbox should be checked)

### Step 2: Check Plugin Directory
1. Go to IntelliJ configuration directory
2. Look in `plugins/` folder for harbour plugin
3. Verify the plugin JAR file exists

### Step 3: Check IntelliJ Logs
1. Go to Help → Show Log in Files
2. Look for any plugin loading errors
3. Search for "harbour" or "HarbourDebugger" in logs

### Step 4: Plugin Validation
1. Try installing the plugin on a clean IntelliJ installation
2. Test with IntelliJ IDEA Community Edition 2024.3.4
3. Disable other plugins temporarily to check for conflicts

### Step 5: Alternative Installation Methods
1. Try installing from plugin marketplace if available
2. Manual installation from ZIP file
3. Development installation using gradle runIde

## Manual Plugin Installation
1. Download harbour-language-plugin-1.0.266.zip
2. Open IntelliJ IDEA
3. Go to File → Settings → Plugins
4. Click gear icon → "Install Plugin from Disk"
5. Select the ZIP file
6. Restart IntelliJ IDEA

## Expected Behavior When Working
When the plugin loads correctly, you should see:
1. A notification balloon: "Harbour Plugin v1.0.266 loaded successfully"
2. Multiple diagnostic files created in working directory
3. "Harbour Debugger" configuration type in Run/Debug configurations
4. Console output showing plugin loading messages

## Next Steps
Since the plugin is not loading at all, we need to:
1. Verify the plugin ZIP file is valid
2. Check IntelliJ Platform compatibility
3. Investigate Windows-specific plugin loading issues
4. Consider alternative plugin distribution methods

## Contact Information
If none of these steps resolve the issue, the problem is likely:
- IntelliJ Platform version incompatibility
- Windows-specific plugin loading restrictions
- Plugin descriptor validation failures
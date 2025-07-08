# Minimal Test Plugin for Windows

## Problem
The Harbour plugin is not loading at all on Windows. No diagnostic files are created, no notifications shown, no console output visible.

## Test Strategy
Create a minimal plugin that only:
1. Loads and creates a diagnostic file
2. Shows a notification
3. Logs to console

## Minimal Plugin Code

### plugin.xml (minimal)
```xml
<idea-plugin>
    <id>test.minimal</id>
    <name>Minimal Test Plugin</name>
    <version>1.0.0</version>
    <vendor>Test</vendor>
    <description>Minimal test plugin for Windows</description>
    
    <depends>com.intellij.modules.platform</depends>
    
    <extensions defaultExtensionNs="com.intellij">
        <applicationService serviceImplementation="MinimalTestService"/>
    </extensions>
</idea-plugin>
```

### MinimalTestService.java
```java
import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.Service;
import java.io.FileWriter;
import java.time.LocalDateTime;

@Service
public class MinimalTestService {
    public MinimalTestService() {
        System.out.println("MINIMAL TEST PLUGIN LOADED!");
        System.err.println("MINIMAL TEST PLUGIN LOADED!");
        
        try {
            FileWriter fw = new FileWriter("C:\\temp\\minimal_test_plugin.txt");
            fw.write("Minimal test plugin loaded at " + LocalDateTime.now());
            fw.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

## Test Instructions
1. Create this minimal plugin
2. Build and install it
3. Check if `C:\\temp\\minimal_test_plugin.txt` is created
4. Check console output for "MINIMAL TEST PLUGIN LOADED!"

## Expected Results
- **If minimal plugin works**: Issue is with our Harbour plugin code
- **If minimal plugin fails**: Issue is with Windows plugin loading system

## Alternative: Use IntelliJ Platform Plugin Template
1. Download official IntelliJ Platform Plugin Template
2. Build minimal example
3. Test on Windows
4. Compare with our plugin structure

## Debugging Plugin Loading
```java
// Add this to any constructor to force visibility
public MyClass() {
    // Multiple output channels
    System.out.println("CLASS LOADED: " + this.getClass().getName());
    System.err.println("CLASS LOADED: " + this.getClass().getName());
    
    // File output with exception handling
    try {
        FileWriter fw = new FileWriter("C:\\temp\\class_loaded.txt", true);
        fw.write(this.getClass().getName() + " loaded at " + LocalDateTime.now() + "\n");
        fw.close();
    } catch (Exception e) {
        e.printStackTrace();
    }
    
    // JVM shutdown hook as last resort
    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
        try {
            FileWriter fw = new FileWriter("C:\\temp\\jvm_shutdown.txt", true);
            fw.write("JVM shutdown - " + this.getClass().getName() + " was loaded\n");
            fw.close();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }));
}
```

This will help isolate whether the issue is plugin-specific or system-wide.
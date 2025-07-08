package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.ApplicationComponent;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.SystemInfo;

import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Basic plugin load test to verify if the plugin is loaded at all on Windows.
 * This will be called when the plugin is loaded by IntelliJ Platform.
 */
public class HarbourPluginLoadTest implements ApplicationComponent {
    private static final Logger LOG = Logger.getInstance(HarbourPluginLoadTest.class);
    
    public HarbourPluginLoadTest() {
        LOG.info("HarbourPluginLoadTest constructor called - plugin is loading!");
        System.out.println("🔧 HARBOUR PLUGIN LOAD TEST v1.0.266 - CONSTRUCTOR CALLED!");
        System.out.println("🔧 OS: " + SystemInfo.getOsNameAndVersion());
        System.err.println("🔧 [STDERR] HARBOUR PLUGIN LOAD TEST v1.0.266 - CONSTRUCTOR CALLED!");
        
        // Write to multiple file locations to ensure visibility
        String[] logPaths = {
            "harbour_plugin_loaded.txt",
            "C:\\temp\\harbour_plugin_loaded.txt",
            System.getProperty("user.home") + "\\harbour_plugin_loaded.txt",
            System.getProperty("java.io.tmpdir") + "\\harbour_plugin_loaded.txt"
        };
        
        for (String path : logPaths) {
            try {
                FileWriter fw = new FileWriter(path);
                fw.write("HarbourPluginLoadTest v1.0.266 - PLUGIN LOADED!\n");
                fw.write("OS: " + SystemInfo.getOsNameAndVersion() + "\n");
                fw.write("Time: " + LocalDateTime.now() + "\n");
                fw.write("User Home: " + System.getProperty("user.home") + "\n");
                fw.write("Working Dir: " + System.getProperty("user.dir") + "\n");
                fw.write("Java Temp Dir: " + System.getProperty("java.io.tmpdir") + "\n");
                fw.write("Thread: " + Thread.currentThread().getName() + "\n");
                fw.close();
                System.out.println("🔧 Plugin load test file written to: " + path);
                break;
            } catch (IOException e) {
                System.err.println("Failed to write plugin load test file to " + path + ": " + e.getMessage());
            }
        }
    }
    
    @Override
    public void initComponent() {
        LOG.info("HarbourPluginLoadTest.initComponent() called");
        System.out.println("🔧 HARBOUR PLUGIN LOAD TEST - initComponent() called!");
        
        // Additional log for initComponent
        try {
            FileWriter fw = new FileWriter("harbour_plugin_init.txt", true);
            fw.write("HarbourPluginLoadTest.initComponent() called at " + LocalDateTime.now() + "\n");
            fw.close();
        } catch (IOException e) {
            LOG.error("Failed to write init log", e);
        }
    }
    
    @Override
    public void disposeComponent() {
        LOG.info("HarbourPluginLoadTest.disposeComponent() called");
        System.out.println("🔧 HARBOUR PLUGIN LOAD TEST - disposeComponent() called!");
    }
    
    @Override
    public String getComponentName() {
        return "HarbourPluginLoadTest";
    }
}
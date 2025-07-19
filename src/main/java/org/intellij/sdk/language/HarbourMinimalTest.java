package org.intellij.sdk.language;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.components.Service;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Minimal test to verify plugin loading.
 * This should create files if the plugin loads at all.
 */
@Service
public final class HarbourMinimalTest {
    
    public HarbourMinimalTest() {
        // Multiple output methods to ensure visibility
        System.out.println("🔥 HARBOUR MINIMAL TEST v1.0.274 - PLUGIN LOADED!");
        System.err.println("🔥 HARBOUR MINIMAL TEST v1.0.274 - PLUGIN LOADED!");
        
        // Try multiple file locations
        String[] paths = {
            "C:/temp/harbour_minimal_test.txt",
            "C:/harbour_minimal_test.txt",
            "harbour_minimal_test.txt",
            System.getProperty("user.home") + "/harbour_minimal_test.txt",
            System.getProperty("java.io.tmpdir") + "/harbour_minimal_test.txt"
        };
        
        for (String path : paths) {
            try {
                // Ensure directory exists
                File file = new File(path);
                File parent = file.getParentFile();
                if (parent != null && !parent.exists()) {
                    parent.mkdirs();
                }
                
                FileWriter fw = new FileWriter(file);
                fw.write("HarbourMinimalTest v1.0.274 - PLUGIN LOADED!\n");
                fw.write("Time: " + LocalDateTime.now() + "\n");
                fw.write("OS: " + System.getProperty("os.name") + "\n");
                fw.write("Java Version: " + System.getProperty("java.version") + "\n");
                fw.write("User Home: " + System.getProperty("user.home") + "\n");
                fw.write("Working Dir: " + System.getProperty("user.dir") + "\n");
                fw.write("Java Temp Dir: " + System.getProperty("java.io.tmpdir") + "\n");
                fw.close();
                
                System.out.println("🔥 Minimal test file created: " + path);
                break; // Success, no need to try other paths
                
            } catch (IOException e) {
                System.err.println("🔥 Failed to create file at " + path + ": " + e.getMessage());
                // Continue to next path
            }
        }
        
        // Also try to create a file in the current working directory
        try {
            FileWriter fw = new FileWriter("HARBOUR_PLUGIN_LOADED_v1.0.274.txt");
            fw.write("HARBOUR PLUGIN LOADED v1.0.274\n");
            fw.write("This file proves the plugin loaded successfully.\n");
            fw.write("Time: " + LocalDateTime.now() + "\n");
            fw.close();
            System.out.println("🔥 Working directory file created: HARBOUR_PLUGIN_LOADED_v1.0.274.txt");
        } catch (IOException e) {
            System.err.println("🔥 Failed to create working directory file: " + e.getMessage());
        }
    }
}
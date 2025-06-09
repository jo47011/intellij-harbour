package org.intellij.sdk.language;

import com.intellij.openapi.components.PersistentStateComponent;
import com.intellij.openapi.components.State;
import com.intellij.openapi.components.Storage;
import com.intellij.openapi.project.Project;
import com.intellij.util.xmlb.XmlSerializerUtil;
import com.intellij.util.xmlb.annotations.MapAnnotation;
import com.intellij.xdebugger.breakpoints.XLineBreakpoint;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.Map;

/**
 * Persistent storage for Harbour breakpoint properties to ensure conditions
 * are preserved between IDE restarts.
 */
@State(
    name = "HarbourBreakpointPropertiesStorage",
    storages = @Storage("harbourBreakpoints.xml")
)
public class HarbourBreakpointPropertiesStorage implements PersistentStateComponent<HarbourBreakpointPropertiesStorage.State> {
    
    public static class State {
        @MapAnnotation(surroundWithTag = false, keyAttributeName = "url", valueAttributeName = "properties")
        public Map<String, StoredBreakpointProperties> breakpointProperties = new HashMap<>();
    }
    
    public static class StoredBreakpointProperties {
        public String condition = "";
        public String hitCondition = "";
        public String logMessage = "";
        public int line = 0;
        
        public StoredBreakpointProperties() {}
        
        public StoredBreakpointProperties(String condition, String hitCondition, String logMessage, int line) {
            this.condition = condition != null ? condition : "";
            this.hitCondition = hitCondition != null ? hitCondition : "";
            this.logMessage = logMessage != null ? logMessage : "";
            this.line = line;
        }
    }
    
    private State myState = new State();
    
    public static HarbourBreakpointPropertiesStorage getInstance(Project project) {
        return project.getService(HarbourBreakpointPropertiesStorage.class);
    }
    
    @Nullable
    @Override
    public State getState() {
        return myState;
    }
    
    @Override
    public void loadState(@NotNull State state) {
        XmlSerializerUtil.copyBean(state, myState);
    }
    
    /**
     * Store breakpoint properties for a given breakpoint
     */
    public void storeBreakpointProperties(XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint,
                                        HarbourDebuggerBreakpointProperties properties) {
        if (breakpoint.getSourcePosition() != null) {
            String key = generateKey(breakpoint);
            StoredBreakpointProperties stored = new StoredBreakpointProperties(
                properties.getCondition(),
                properties.getHitCondition(), 
                properties.getLogMessage(),
                breakpoint.getSourcePosition().getLine()
            );
            myState.breakpointProperties.put(key, stored);
            System.out.println("STORAGE: Stored breakpoint properties for " + key + ": " + stored.condition);
        }
    }
    
    /**
     * Retrieve breakpoint properties for a given breakpoint
     */
    @Nullable
    public HarbourDebuggerBreakpointProperties getBreakpointProperties(XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        if (breakpoint.getSourcePosition() != null) {
            String key = generateKey(breakpoint);
            StoredBreakpointProperties stored = myState.breakpointProperties.get(key);
            if (stored != null) {
                HarbourDebuggerBreakpointProperties properties = new HarbourDebuggerBreakpointProperties();
                properties.setCondition(stored.condition);
                properties.setHitCondition(stored.hitCondition);
                properties.setLogMessage(stored.logMessage);
                System.out.println("STORAGE: Retrieved breakpoint properties for " + key + ": " + stored.condition);
                return properties;
            }
        }
        return null;
    }
    
    /**
     * Remove breakpoint properties when breakpoint is deleted
     */
    public void removeBreakpointProperties(XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        if (breakpoint.getSourcePosition() != null) {
            String key = generateKey(breakpoint);
            myState.breakpointProperties.remove(key);
            System.out.println("STORAGE: Removed breakpoint properties for " + key);
        }
    }
    
    /**
     * Generate a unique key for a breakpoint based on file and line
     */
    private String generateKey(XLineBreakpoint<HarbourDebuggerBreakpointProperties> breakpoint) {
        return breakpoint.getSourcePosition().getFile().getUrl() + ":" + breakpoint.getSourcePosition().getLine();
    }
}
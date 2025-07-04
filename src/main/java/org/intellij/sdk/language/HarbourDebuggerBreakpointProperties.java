package org.intellij.sdk.language;

import com.intellij.util.xmlb.XmlSerializerUtil;
import com.intellij.util.xmlb.annotations.Attribute;
import com.intellij.xdebugger.breakpoints.XBreakpointProperties;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

/**
 * Properties for Harbour debugger breakpoints.
 * This is required by the XLineBreakpointType interface.
 * Supports conditional breakpoints with expressions.
 */
public class HarbourDebuggerBreakpointProperties extends XBreakpointProperties<HarbourDebuggerBreakpointProperties> {

    @Attribute("condition")
    private String condition = "";

    @Attribute("hitCondition")
    private String hitCondition = "";

    @Attribute("logMessage")
    private String logMessage = "";
    
    // Default constructor needed for serialization
    public HarbourDebuggerBreakpointProperties() {
    }

    public String getCondition() {
        return condition != null ? condition : "";
    }

    public void setCondition(String condition) {
        this.condition = condition != null ? condition : "";
    }

    public String getHitCondition() {
        return hitCondition != null ? hitCondition : "";
    }

    public void setHitCondition(String hitCondition) {
        this.hitCondition = hitCondition != null ? hitCondition : "";
    }

    public String getLogMessage() {
        return logMessage != null ? logMessage : "";
    }

    public void setLogMessage(String logMessage) {
        this.logMessage = logMessage != null ? logMessage : "";
    }

    public boolean hasCondition() {
        return condition != null && !condition.trim().isEmpty();
    }

    public boolean hasHitCondition() {
        return hitCondition != null && !hitCondition.trim().isEmpty();
    }

    public boolean hasLogMessage() {
        return logMessage != null && !logMessage.trim().isEmpty();
    }

    @Nullable
    @Override
    public HarbourDebuggerBreakpointProperties getState() {
        return this;
    }

    @Override
    public void loadState(@NotNull HarbourDebuggerBreakpointProperties state) {
        XmlSerializerUtil.copyBean(state, this);
    }
    
    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        
        HarbourDebuggerBreakpointProperties that = (HarbourDebuggerBreakpointProperties) obj;
        
        if (condition != null ? !condition.equals(that.condition) : that.condition != null) return false;
        if (hitCondition != null ? !hitCondition.equals(that.hitCondition) : that.hitCondition != null) return false;
        return logMessage != null ? logMessage.equals(that.logMessage) : that.logMessage == null;
    }
    
    @Override
    public int hashCode() {
        int result = condition != null ? condition.hashCode() : 0;
        result = 31 * result + (hitCondition != null ? hitCondition.hashCode() : 0);
        result = 31 * result + (logMessage != null ? logMessage.hashCode() : 0);
        return result;
    }
    
    @Override
    public String toString() {
        return "HarbourDebuggerBreakpointProperties{" +
                "condition='" + condition + '\'' +
                ", hitCondition='" + hitCondition + '\'' +
                ", logMessage='" + logMessage + '\'' +
                '}';
    }
}
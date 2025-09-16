package org.intellij.sdk.language;

import com.intellij.xdebugger.XDebuggerUtil;
import com.intellij.xdebugger.XSourcePosition;
import com.intellij.xdebugger.frame.XExecutionStack;
import com.intellij.xdebugger.frame.XStackFrame;
import com.intellij.openapi.vfs.LocalFileSystem;
import com.intellij.openapi.vfs.VirtualFile;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Collections;

/**
 * Represents the call stack in the Harbour debugger.
 * Displays the current execution context and stack frames.
 */
public class HarbourDebuggerExecutionStack extends XExecutionStack {
    private final HarbourDebuggerBaseProcess debugProcess;
    private final HarbourDebuggerStackFrame topFrame;
    private final List<HarbourDebuggerStackFrame> allFrames;

    public HarbourDebuggerExecutionStack(HarbourDebuggerBaseProcess debugProcess,
                                         String file,
                                         int line,
                                         XSourcePosition sourcePosition,
                                         List<HarbourDebuggerRemoteProcess.StackFrameInfo> stackTrace) {
        super("Harbour Stack");
        this.debugProcess = debugProcess;
        this.allFrames = new ArrayList<>();
        
        // Create the top frame (current position)
        this.topFrame = new HarbourDebuggerStackFrame(debugProcess, getFunctionNameFromFile(file), file, line, sourcePosition);
        allFrames.add(topFrame);
        
        // Add additional stack frames if available
        if (stackTrace != null && !stackTrace.isEmpty()) {
            // Skip the first frame if it matches the current position
            int startIndex = 0;
            if (!stackTrace.isEmpty()) {
                HarbourDebuggerRemoteProcess.StackFrameInfo firstFrame = stackTrace.get(0);
                if (firstFrame.file.equals(file) && firstFrame.line == line) {
                    startIndex = 1;
                }
            }
            
            // Add remaining frames
            for (int i = startIndex; i < stackTrace.size(); i++) {
                HarbourDebuggerRemoteProcess.StackFrameInfo frameInfo = stackTrace.get(i);
                XSourcePosition framePosition = createSourcePosition(frameInfo.file, frameInfo.line);
                HarbourDebuggerStackFrame frame = new HarbourDebuggerStackFrame(
                    debugProcess, 
                    frameInfo.functionName, 
                    frameInfo.file, 
                    frameInfo.line, 
                    framePosition
                );
                allFrames.add(frame);
            }
        }
    }

    @Nullable
    @Override
    public XStackFrame getTopFrame() {
        return topFrame;
    }

    @Override
    public void computeStackFrames(int firstFrameIndex, @NotNull XStackFrameContainer container) {
        if (firstFrameIndex < allFrames.size()) {
            List<XStackFrame> frames = new ArrayList<>();
            for (int i = firstFrameIndex; i < allFrames.size(); i++) {
                frames.add(allFrames.get(i));
            }
            container.addStackFrames(frames, true);
        } else {
            container.addStackFrames(Collections.emptyList(), true);
        }
    }
    
    private XSourcePosition createSourcePosition(String file, int line) {
        if (file == null || line <= 0) {
            return null;
        }
        
        // Try to find the file
        File sourceFile = new File(file);
        if (!sourceFile.isAbsolute()) {
            // Try relative to project
            sourceFile = new File(debugProcess.getSession().getProject().getBasePath(), file);
        }
        
        if (sourceFile.exists()) {
            VirtualFile virtualFile = LocalFileSystem.getInstance().findFileByIoFile(sourceFile);
            if (virtualFile != null) {
                return XDebuggerUtil.getInstance().createPosition(virtualFile, line - 1);
            }
        }
        
        return null;
    }

    private String getFunctionNameFromFile(String filePath) {
        // Handle null filePath
        if (filePath == null) {
            return "Unknown";
        }
        
        // Extract the function name from the file path
        int lastSlash = filePath.lastIndexOf('/');
        int lastBackslash = filePath.lastIndexOf('\\');
        int lastSeparator = Math.max(lastSlash, lastBackslash);
        
        String fileName = (lastSeparator >= 0) ? filePath.substring(lastSeparator + 1) : filePath;
        
        if (fileName.toLowerCase().endsWith(".prg")) {
            fileName = fileName.substring(0, fileName.length() - 4);
        }
        return fileName;
    }
}
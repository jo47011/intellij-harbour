# TODOs

Testen:
- startup: scanning harbour project files hangs at 8/111 or so
- harbour dbf view icon -> always to "Bottom right"

- navigation
  - CLASS NegVerfuegItem<= not navigatable pls fix

- code completion
  - rech:faell <ctrls-space> should propose matching methods and data fields
  - Error(TRY_ ctrl-space => should deliver TRY_AGAIN from ch file

- db viewer
  - Advanced Views (Table grid, index browsing)
  - dbf file open in project explorer, right click => not available

indentation:
- endif return not unindented

new: tab completion: ctrl tab?

---

check:

fyi the files defined as excluded in the harbour settings should also be discarded from indexing

----

Freeze in EDT for 15 seconds
Sampled time: 8400ms, sampling rate: 100ms, GC time: 90ms (0%), Class loading: 0%, CPU load: 3%

com.intellij.diagnostic.Freeze
at java.base@21.0.7/java.lang.Object.wait0(Native Method)
at java.base@21.0.7/java.lang.Object.wait(Object.java:366)
at com.intellij.openapi.progress.util.EternalEventStealer.dispatchAllEventsForTimeout(SuvorovProgress.kt:261)
at com.intellij.openapi.progress.util.SuvorovProgress.processInvocationEventsWithoutDialog(SuvorovProgress.kt:125)
at com.intellij.openapi.progress.util.SuvorovProgress.dispatchEventsUntilComputationCompletes(SuvorovProgress.kt:73)
at com.intellij.openapi.application.impl.ApplicationImpl.lambda$postInit$14(ApplicationImpl.java:1434)
at com.intellij.openapi.application.impl.ApplicationImpl$$Lambda/0x00000200bc503c00.invoke(Unknown Source)
at com.intellij.platform.locking.impl.RunSuspend.await(NestedLocksThreadingSupport.kt:1517)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupportKt.runSuspendWithWaitingConsumer(NestedLocksThreadingSupport.kt:1472)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupportKt.access$runSuspendWithWaitingConsumer(NestedLocksThreadingSupport.kt:1)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupport.runSuspendMaybeConsuming(NestedLocksThreadingSupport.kt:1439)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupport$ComputationState.acquireWriteIntentPermit(NestedLocksThreadingSupport.kt:410)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupport.doRunWriteIntentReadAction(NestedLocksThreadingSupport.kt:657)
at com.intellij.platform.locking.impl.NestedLocksThreadingSupport.runPreventiveWriteIntentReadAction(NestedLocksThreadingSupport.kt:640)
at com.intellij.ide.IdeEventQueue._dispatchEvent(IdeEventQueue.kt:471)
at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12$lambda$11$lambda$10$lambda$9(IdeEventQueue.kt:313)
at com.intellij.ide.IdeEventQueue$$Lambda/0x00000200bcc4f288.compute(Unknown Source)
at com.intellij.openapi.progress.impl.CoreProgressManager.computePrioritized(CoreProgressManager.java:865)
at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12$lambda$11$lambda$10(IdeEventQueue.kt:312)
at com.intellij.ide.IdeEventQueue$$Lambda/0x00000200bc6afae0.invoke(Unknown Source)
at com.intellij.ide.IdeEventQueueKt.performActivity$lambda$3(IdeEventQueue.kt:974)
at com.intellij.ide.IdeEventQueueKt$$Lambda/0x00000200bc6b4288.run(Unknown Source)
at com.intellij.openapi.application.TransactionGuardImpl.performActivity(TransactionGuardImpl.java:110)
at com.intellij.ide.IdeEventQueueKt.performActivity(IdeEventQueue.kt:974)
at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12(IdeEventQueue.kt:307)
at com.intellij.ide.IdeEventQueue$$Lambda/0x00000200bc6ac000.run(Unknown Source)
at com.intellij.ide.IdeEventQueue.dispatchEvent(IdeEventQueue.kt:347)
at java.desktop/java.awt.EventDispatchThread.pumpOneEventForFilters(EventDispatchThread.java:207)
at java.desktop/java.awt.EventDispatchThread.pumpEventsForFilter(EventDispatchThread.java:128)
at java.desktop/java.awt.EventDispatchThread.pumpEventsForHierarchy(EventDispatchThread.java:117)
at java.desktop/java.awt.EventDispatchThread.pumpEvents(EventDispatchThread.java:113)
at java.desktop/java.awt.EventDispatchThread.pumpEvents(EventDispatchThread.java:105)
at java.desktop/java.awt.EventDispatchThread.run(EventDispatchThread.java:92)

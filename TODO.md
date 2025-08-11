# TODOs

- cleanup code, get claude to find duplicate, unused etc code snippets


renaming feature:

- ctrl-F6 rename => propose current function or variable name in rename field

=> not working, pls fix, see Screenshot where I want the text that the user wants to rename



formatting:

      do case
      case RECHAUS->Aufart$"NG"
        kom:="GS"
      case RECHAUS->Aufart="A"
        kom:="Au"
      case RECHAUS->Aufart="S"
        kom:="St"
        otherwise  <= this is wrong, should not be indented
        kom:="Re"
      endcase  <= wrong color, should be keyword as well




code completion:
- sometimes extra word is added, see Screenshot

general:

- function/procedure stuff should also work for func or proce
- stacktrace on startup:
  java.io.IOException: Can not read hash: data length is zero
  at com.intellij.vcs.log.impl.HashImpl.read(HashImpl.java:32)
  at com.intellij.vcs.log.data.VcsLogStorageImpl$MyCommitIdKeyDescriptor.read(VcsLogStorageImpl.java:240)
  at com.intellij.vcs.log.data.VcsLogStorageImpl$MyCommitIdKeyDescriptor.read(VcsLogStorageImpl.java:219)
  at com.intellij.util.io.keyStorage.AppendableStorageBackedByResizableMappedFile.read(AppendableStorageBackedByResizableMappedFile.java:92)
  at com.intellij.util.io.PersistentEnumeratorBase.findValueFor(PersistentEnumeratorBase.java:464)
  at com.intellij.util.io.PersistentEnumeratorBase.lambda$valueOf$2(PersistentEnumeratorBase.java:453)
  at com.intellij.util.io.PersistentEnumeratorBase.catchCorruption(PersistentEnumeratorBase.java:673)
  at com.intellij.util.io.PersistentEnumeratorBase.valueOf(PersistentEnumeratorBase.java:452)
  at com.intellij.util.io.PersistentBTreeEnumerator.valueOf(PersistentBTreeEnumerator.java:787)
  at com.intellij.util.io.PersistentEnumeratorBase.isKeyAtIndex(PersistentEnumeratorBase.java:399)
  at com.intellij.util.io.PersistentBTreeEnumerator.enumerateImpl(PersistentBTreeEnumerator.java:604)
  at com.intellij.util.io.PersistentEnumeratorBase.lambda$doEnumerate$0(PersistentEnumeratorBase.java:268)
  at com.intellij.util.io.PersistentEnumeratorBase.catchCorruption(PersistentEnumeratorBase.java:673)
  at com.intellij.util.io.PersistentEnumeratorBase.doEnumerate(PersistentEnumeratorBase.java:267)
  at com.intellij.util.io.PersistentEnumeratorBase.enumerate(PersistentEnumeratorBase.java:280)
  at com.intellij.vcs.log.data.VcsLogStorageImpl.getOrPut(VcsLogStorageImpl.java:108)
  at com.intellij.vcs.log.data.VcsLogStorageImpl.getCommitIndex(VcsLogStorageImpl.java:115)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.compactCommit(VcsLogRefresherImpl.java:216)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.lambda$compactCommits$5(VcsLogRefresherImpl.java:201)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceKt.use(trace.kt:30)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.compactCommits(VcsLogRefresherImpl.java:193)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.lambda$loadRecentData$2(VcsLogRefresherImpl.java:157)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceKt.runWithSpanIgnoreThrows(trace.kt:73)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceUtil.runWithSpanThrows(TraceUtil.java:33)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.lambda$loadRecentData$3(VcsLogRefresherImpl.java:155)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceKt.computeWithSpanIgnoreThrows(trace.kt:68)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceUtil.computeWithSpanThrows(TraceUtil.java:24)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.loadRecentData(VcsLogRefresherImpl.java:150)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.loadRecentData(VcsLogRefresherImpl.java:138)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.lambda$readFirstBlock$1(VcsLogRefresherImpl.java:121)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceKt.computeWithSpanIgnoreThrows(trace.kt:68)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceUtil.computeWithSpanThrows(TraceUtil.java:24)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl.readFirstBlock(VcsLogRefresherImpl.java:119)
  at com.intellij.vcs.log.data.VcsLogRefresherImpl$MyInitializationTask.run(VcsLogRefresherImpl.java:250)
  at com.intellij.openapi.progress.impl.CoreProgressManager.startTask(CoreProgressManager.java:491)
  at com.intellij.openapi.progress.impl.ProgressManagerImpl.startTask(ProgressManagerImpl.java:133)
  at com.intellij.openapi.progress.impl.CoreProgressManager.lambda$runProcessWithProgressAsynchronously$7(CoreProgressManager.java:542)
  at com.intellij.openapi.progress.impl.ProgressRunner.lambda$submit$4(ProgressRunner.java:249)
  at com.intellij.openapi.progress.ProgressManager.lambda$runProcess$0(ProgressManager.java:98)
  at com.intellij.openapi.progress.impl.CoreProgressManager.lambda$runProcess$1(CoreProgressManager.java:223)
  at com.intellij.platform.diagnostic.telemetry.helpers.TraceKt.use(trace.kt:45)
  at com.intellij.openapi.progress.impl.CoreProgressManager.lambda$runProcess$2(CoreProgressManager.java:222)
  at com.intellij.openapi.progress.impl.CoreProgressManager.lambda$executeProcessUnderProgress$14(CoreProgressManager.java:674)
  at com.intellij.openapi.progress.impl.CoreProgressManager.registerIndicatorAndRun(CoreProgressManager.java:749)
  at com.intellij.openapi.progress.impl.CoreProgressManager.computeUnderProgress(CoreProgressManager.java:705)
  at com.intellij.openapi.progress.impl.CoreProgressManager.executeProcessUnderProgress(CoreProgressManager.java:673)
  at com.intellij.openapi.progress.impl.ProgressManagerImpl.executeProcessUnderProgress(ProgressManagerImpl.java:79)
  at com.intellij.openapi.progress.impl.CoreProgressManager.runProcess(CoreProgressManager.java:203)
  at com.intellij.openapi.progress.ProgressManager.runProcess(ProgressManager.java:98)
  at com.intellij.openapi.progress.impl.ProgressRunner.lambda$submit$5(ProgressRunner.java:249)
  at com.intellij.openapi.progress.impl.ProgressRunner$ProgressRunnable.run(ProgressRunner.java:502)
  at com.intellij.openapi.progress.impl.ProgressRunner.lambda$launchTask$18(ProgressRunner.java:467)
  at com.intellij.util.concurrency.ChildContext$runInChildContext$1.invoke(propagation.kt:103)
  at com.intellij.util.concurrency.ChildContext$runInChildContext$1.invoke(propagation.kt:103)
  at com.intellij.util.concurrency.ChildContext.runInChildContext(propagation.kt:109)
  at com.intellij.util.concurrency.ChildContext.runInChildContext(propagation.kt:103)
  at com.intellij.openapi.progress.impl.ProgressRunner.lambda$launchTask$19(ProgressRunner.java:463)
  at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1144)
  at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:642)
  at java.base/java.util.concurrent.Executors$PrivilegedThreadFactory$1$1.run(Executors.java:735)
  at java.base/java.util.concurrent.Executors$PrivilegedThreadFactory$1$1.run(Executors.java:732)
  at java.base/java.security.AccessController.doPrivileged(AccessController.java:400)
  at java.base/java.util.concurrent.Executors$PrivilegedThreadFactory$1.run(Executors.java:732)
  at java.base/java.lang.Thread.run(Thread.java:1583)


n2h:

- function / hotkey to add variable under cursor to LOCAL in function
# TODOs

- db viewer
  - dbf file open in project explorer, right click => not available

- new: 
- tab completion: ctrl tab?
- structure view, methode in der der Cusror steht sollte ge-highlighted werden
- refactor: in Methode auslagern
- hotkey zum linten des aktuellen programms => settings oder als commando mit default key
- ctrl-T toggle
- Klammer auf eingeben -> Klammer zu automatisch => konfigurierbar, default=False

Code navigation:
- clicking on a if/endif or while/enddo etc. => shpuld jump to the counterpart in code

Harbour DBF View
- Bug:
  java.lang.IllegalArgumentException: (minimum <= value <= maximum) is false
	at java.desktop/javax.swing.SpinnerNumberModel.<init>(SpinnerNumberModel.java:139)
	at java.desktop/javax.swing.SpinnerNumberModel.<init>(SpinnerNumberModel.java:161)
	at org.intellij.sdk.language.HarbourDBFToolWindow$HarbourDBFToolWindowContent.updateNavigationButtons(HarbourDBFToolWindow.java:830)
	at org.intellij.sdk.language.HarbourDBFToolWindow$HarbourDBFToolWindowContent.showWorkareaDetails(HarbourDBFToolWindow.java:851)
	at org.intellij.sdk.language.HarbourDBFToolWindow$HarbourDBFToolWindowContent.onWorkareaSelected(HarbourDBFToolWindow.java:487)
	at org.intellij.sdk.language.HarbourDBFToolWindow$HarbourDBFToolWindowContent.lambda$new$0(HarbourDBFToolWindow.java:183)
	at java.desktop/javax.swing.JTree.fireValueChanged(JTree.java:3020)
	at java.desktop/javax.swing.JTree$TreeSelectionRedirector.valueChanged(JTree.java:3521)
	at java.desktop/javax.swing.tree.DefaultTreeSelectionModel.fireValueChanged(DefaultTreeSelectionModel.java:650)
	at com.intellij.ui.treeStructure.Tree$MySelectionModel.fireValueChanged(Tree.java:944)
	at java.desktop/javax.swing.tree.DefaultTreeSelectionModel.notifyPathChange(DefaultTreeSelectionModel.java:1120)
	at java.desktop/javax.swing.tree.DefaultTreeSelectionModel.setSelectionPaths(DefaultTreeSelectionModel.java:306)
	at java.desktop/javax.swing.tree.DefaultTreeSelectionModel.setSelectionPath(DefaultTreeSelectionModel.java:200)
	at java.desktop/javax.swing.JTree.setSelectionPath(JTree.java:1710)
	at java.desktop/javax.swing.plaf.basic.BasicTreeUI.selectPathForEvent(BasicTreeUI.java:2761)
	at java.desktop/javax.swing.plaf.basic.BasicTreeUI$Handler.handleSelection(BasicTreeUI.java:4096)
	at java.desktop/javax.swing.plaf.basic.BasicTreeUI$Handler.mousePressed(BasicTreeUI.java:4035)
	at com.intellij.util.ui.MouseEventAdapter.mousePressed(MouseEventAdapter.java:30)
	at java.desktop/java.awt.AWTEventMulticaster.mousePressed(AWTEventMulticaster.java:287)
	at java.desktop/java.awt.AWTEventMulticaster.mousePressed(AWTEventMulticaster.java:287)
	at java.desktop/java.awt.AWTEventMulticaster.mousePressed(AWTEventMulticaster.java:287)
	at java.desktop/java.awt.Component.processMouseEvent(Component.java:6670)
	at java.desktop/javax.swing.JComponent.processMouseEvent(JComponent.java:3394)
	at com.intellij.ui.treeStructure.Tree.processMouseEvent(Tree.java:491)
	at java.desktop/java.awt.Component.processEvent(Component.java:6438)
	at java.desktop/java.awt.Container.processEvent(Container.java:2266)
	at java.desktop/java.awt.Component.dispatchEventImpl(Component.java:5043)
	at java.desktop/java.awt.Container.dispatchEventImpl(Container.java:2324)
	at java.desktop/java.awt.Component.dispatchEvent(Component.java:4871)
	at java.desktop/java.awt.LightweightDispatcher.retargetMouseEvent(Container.java:4963)
	at java.desktop/java.awt.LightweightDispatcher.processMouseEvent(Container.java:4574)
	at java.desktop/java.awt.LightweightDispatcher.dispatchEvent(Container.java:4518)
	at java.desktop/java.awt.Container.dispatchEventImpl(Container.java:2310)
	at java.desktop/java.awt.Window.dispatchEventImpl(Window.java:2810)
	at java.desktop/java.awt.Component.dispatchEvent(Component.java:4871)
	at java.desktop/java.awt.EventQueue.dispatchEventImpl(EventQueue.java:783)
	at java.desktop/java.awt.EventQueue$4.run(EventQueue.java:728)
	at java.desktop/java.awt.EventQueue$4.run(EventQueue.java:722)
	at java.base/java.security.AccessController.doPrivileged(AccessController.java:400)
	at java.base/java.security.ProtectionDomain$JavaSecurityAccessImpl.doIntersectionPrivilege(ProtectionDomain.java:87)
	at java.base/java.security.ProtectionDomain$JavaSecurityAccessImpl.doIntersectionPrivilege(ProtectionDomain.java:98)
	at java.desktop/java.awt.EventQueue$5.run(EventQueue.java:755)
	at java.desktop/java.awt.EventQueue$5.run(EventQueue.java:753)
	at java.base/java.security.AccessController.doPrivileged(AccessController.java:400)
	at java.base/java.security.ProtectionDomain$JavaSecurityAccessImpl.doIntersectionPrivilege(ProtectionDomain.java:87)
	at java.desktop/java.awt.EventQueue.dispatchEvent(EventQueue.java:752)
	at com.intellij.ide.IdeEventQueue.defaultDispatchEvent(IdeEventQueue.kt:595)
	at com.intellij.ide.IdeEventQueue.dispatchMouseEvent(IdeEventQueue.kt:540)
	at com.intellij.ide.IdeEventQueue._dispatchEvent$lambda$16(IdeEventQueue.kt:479)
	at com.intellij.platform.locking.impl.NestedLocksThreadingSupport.doRunWriteIntentReadAction(NestedLocksThreadingSupport.kt:666)
	at com.intellij.platform.locking.impl.NestedLocksThreadingSupport.runPreventiveWriteIntentReadAction(NestedLocksThreadingSupport.kt:640)
	at com.intellij.ide.IdeEventQueue._dispatchEvent(IdeEventQueue.kt:479)
	at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12$lambda$11$lambda$10$lambda$9(IdeEventQueue.kt:313)
	at com.intellij.openapi.progress.impl.CoreProgressManager.computePrioritized(CoreProgressManager.java:865)
	at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12$lambda$11$lambda$10(IdeEventQueue.kt:312)
	at com.intellij.ide.IdeEventQueueKt.performActivity$lambda$3(IdeEventQueue.kt:974)
	at com.intellij.openapi.application.TransactionGuardImpl.performActivity(TransactionGuardImpl.java:118)
	at com.intellij.ide.IdeEventQueueKt.performActivity(IdeEventQueue.kt:974)
	at com.intellij.ide.IdeEventQueue.dispatchEvent$lambda$12(IdeEventQueue.kt:307)
	at com.intellij.ide.IdeEventQueue.dispatchEvent(IdeEventQueue.kt:347)
	at java.desktop/java.awt.EventDispatchThread.pumpOneEventForFilters(EventDispatchThread.java:207)
	at java.desktop/java.awt.EventDispatchThread.pumpEventsForFilter(EventDispatchThread.java:128)
	at java.desktop/java.awt.EventDispatchThread.pumpEventsForHierarchy(EventDispatchThread.java:117)
	at java.desktop/java.awt.EventDispatchThread.pumpEvents(EventDispatchThread.java:113)
	at java.desktop/java.awt.EventDispatchThread.pumpEvents(EventDispatchThread.java:105)
	at java.desktop/java.awt.EventDispatchThread.run(EventDispatchThread.java:92)

- offer option to sort workareas (default current order/numbering, alternativ: name)
  same for proptery column, maybe also value

Debugger:
- stepping slow
- sometimes does not step at all but jumps to calling function -> no longer debugging

Code completion:
- very slow
- local varaiable not proposed, e.g.
  LOCAL erledigt:=.t.
  LOCAL erledigt_fast:=.t.
  erledigt_<ctrl-space>

Bugs:
- missing include -> link: configure include path should open the correct tab in settings
- when debugging cannot open 2nd hbmiki UI
- stacktrace not shown in debug mode, e.g. getMaschinen() stueckliste.prg#443
- debug stepping too slow

Recherche:
3. Command-line formatting - Confirmed support and documented usage:
   - pycharm.sh format file.prg - format single file
   - pycharm.sh format -recursive /directory - format directory
   - Works when IDE is not running

-----
Gave up on this, will try later:
Note testing in windows in your container here: workspace/hbmiki-test-windows
see logs and screenshots (if any) in workspace/log, clean the content of this directory when finished.

Pls use instructions on CLAUDE.md for formatting and testing.

-----
format bug:

Now applied the formatting twice and the 2nd time still lines got reformatted
which shouldn't be.

Pls look in workspace/log/Screenshot* left hand site is after 1st format, right side after 2nd format.

The original errors are back.  The indentation after 2nd format (right hand side) is correct and should have
been applied right away on 1st reformat (right side)

still wrong, see listen2.prg line 195
        ? "Miki Plastik GMBH  ***  Auftragsbestandsliste  ***",space(1),;
          left(alltrim(text)+space(50),50),space(20),"vom:",getUser():date,space(10),"  Seite :",;
            str(seite,3)   you

You have your own test framework.  pls reformat and test it yourself.  if it doesn't work don't come back.
Start over again fix, reformat, test,....
Start over again fix, reformat, test,....
etc.



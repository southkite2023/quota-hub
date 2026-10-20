import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var allowTermination = false
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if allowTermination { return .terminateNow }
    (mainFlutterWindow as? MainFlutterWindow)?.requestQuit()
    return .terminateCancel
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    (mainFlutterWindow as? MainFlutterWindow)?.openDashboard()
    return true
  }
}

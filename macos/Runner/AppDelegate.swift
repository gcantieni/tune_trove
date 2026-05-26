import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
    if #available(macOS 14, *) {
      CloudKitSyncBridge.shared?.handleRemoteNotification(userInfo)
    }
  }

  override func application(
    _ application: NSApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[CKSync] APNs registration failed: \(error.localizedDescription)")
  }
}

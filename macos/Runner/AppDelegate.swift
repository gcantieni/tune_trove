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

  // Finder "Open With" / double-clicking an audio file routes it here. The
  // bridge buffers URLs that arrive before the Flutter engine is ready. Call
  // super so FlutterAppDelegate still forwards openURLs to plugins.
  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    for url in urls where url.isFileURL {
      AudioImportBridge.receive(url)
    }
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

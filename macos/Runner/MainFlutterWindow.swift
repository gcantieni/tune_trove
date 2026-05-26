import Cocoa
import FlutterMacOS
import MusicKit

class MainFlutterWindow: NSWindow {
    private var musicKitBridge: AnyObject?
    private var cloudKitSyncBridge: AnyObject?

    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        if #available(macOS 14, *) {
            let bridge = MusicKitBridge()
            bridge.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
            musicKitBridge = bridge

            let syncBridge = CloudKitSyncBridge()
            syncBridge.setup(binaryMessenger: flutterViewController.engine.binaryMessenger)
            cloudKitSyncBridge = syncBridge

            // Needed to receive CloudKit's silent change pushes.
            NSApplication.shared.registerForRemoteNotifications()
        }

        super.awakeFromNib()
    }
}

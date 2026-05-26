import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var musicKitBridge: AnyObject?
    private var cloudKitSyncBridge: AnyObject?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Needed to receive CloudKit's silent change pushes.
        application.registerForRemoteNotifications()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if #available(iOS 17, *),
           CloudKitSyncBridge.shared?.handleRemoteNotification(userInfo) == true {
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[CKSync] APNs registration failed: \(error.localizedDescription)")
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        if #available(iOS 17, *) {
            guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusicKitBridge") else { return }
            let bridge = MusicKitBridge()
            bridge.setup(binaryMessenger: registrar.messenger())
            musicKitBridge = bridge

            let syncBridge = CloudKitSyncBridge()
            syncBridge.setup(binaryMessenger: registrar.messenger())
            cloudKitSyncBridge = syncBridge
        }
    }
}

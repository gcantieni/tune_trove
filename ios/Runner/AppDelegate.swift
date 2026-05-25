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
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        if #available(iOS 15, *) {
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

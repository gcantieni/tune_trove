import Flutter
import UIKit

/// Subclasses Flutter's scene delegate so we can intercept audio files shared
/// into the app ("Copy to Tune Trove") under the UIScene lifecycle. `super`
/// must be called first on every override so Flutter's engine/plugin wiring
/// stays intact.
class SceneDelegate: FlutterSceneDelegate {
    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        for context in connectionOptions.urlContexts {
            handle(context.url)
        }
    }

    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        super.scene(scene, openURLContexts: URLContexts)
        for context in URLContexts {
            handle(context.url)
        }
    }

    private func handle(_ url: URL) {
        guard url.isFileURL else { return }
        AudioImportBridge.receive(url)
    }
}

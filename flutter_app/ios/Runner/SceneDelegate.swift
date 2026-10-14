import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// The OS delivers `moali://auth?token=...` here after the browser finishes
  /// Google sign-in. We forward it to the engine via a notification, which the
  /// `AppDelegate` bridges onto the `moali/auth` method channel.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      NotificationCenter.default.post(
        name: .moaliDeepLink,
        object: context.url
      )
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}

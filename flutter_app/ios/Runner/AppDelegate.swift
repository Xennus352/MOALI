import Flutter
import UIKit

extension Notification.Name {
  /// Posted by `SceneDelegate` when the OS opens the app with a URL. Carries the
  /// `URL` as its object.
  static let moaliDeepLink = Notification.Name("moaliDeepLink")
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var channel: FlutterMethodChannel?
  private var pendingLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MoaliAuth") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "moali/auth",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getInitialLink":
        result(self?.pendingLink)
        self?.pendingLink = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel

    NotificationCenter.default.addObserver(
      forName: .moaliDeepLink,
      object: nil,
      queue: .main
    ) { [weak self] note in
      guard let url = note.object as? URL else { return }
      let link = url.absoluteString
      if let channel = self?.channel {
        channel.invokeMethod("deepLink", arguments: link)
      } else {
        self?.pendingLink = link
      }
    }
  }
}

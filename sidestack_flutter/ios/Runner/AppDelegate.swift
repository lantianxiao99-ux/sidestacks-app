import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pin the App Check debug token so it matches what's registered in Firebase console.
    // This only runs in debug builds — production builds use DeviceCheck instead.
    #if DEBUG
    UserDefaults.standard.set(
      "A1B2C3D4-E5F6-4890-ABCD-EF1234567890",
      forKey: "FIRAAppCheckDebugToken"
    )
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

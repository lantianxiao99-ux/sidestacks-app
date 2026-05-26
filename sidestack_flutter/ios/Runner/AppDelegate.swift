import Flutter
import UIKit
import WidgetKit

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

    // ── Widget data sync channel ───────────────────────────────────────────
    // Flutter calls this whenever financial data changes so the home screen
    // widget stays fresh without needing a background fetch.
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    let messenger = controller.binaryMessenger
    let channel = FlutterMethodChannel(
      name: "com.sidestacks.app/widget",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "updateWidgetData" {
        if let args = call.arguments as? [String: Any],
           let shared = UserDefaults(suiteName: "group.com.sidestacks.app") {
          // Write each field — widget reads these keys directly
          shared.set(args["monthIncome"] as? Double ?? 0.0, forKey: "monthIncome")
          shared.set(args["monthProfit"] as? Double ?? 0.0, forKey: "monthProfit")
          shared.set(args["monthExpenses"] as? Double ?? 0.0, forKey: "monthExpenses")
          shared.set(args["currencySymbol"] as? String ?? "$", forKey: "currencySymbol")
          shared.set(args["monthLabel"] as? String ?? "", forKey: "monthLabel")
          shared.set(args["topStackName"] as? String, forKey: "topStackName")
          shared.set(args["stackCount"] as? Int ?? 0, forKey: "stackCount")
          shared.synchronize()
          // Tell WidgetKit to reload all timelines so the widget re-renders
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "App Group not accessible", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

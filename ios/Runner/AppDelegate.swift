import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase
    FirebaseApp.configure()
    
    // Initialize Google Maps with API key from Info.plist (GMSApiKey)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    } else {
      // Fallback: try alternative keys
      let altKeys = ["GOOGLE_MAPS_API_KEY", "MAPS_API_KEY", "GOOGLE_API_KEY"]
      for key in altKeys {
        if let k = Bundle.main.object(forInfoDictionaryKey: key) as? String, !k.isEmpty {
          GMSServices.provideAPIKey(k)
          break
        }
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // Window / root FlutterViewController may not exist until after this run loop tick.
    DispatchQueue.main.async { [weak self] in
      guard let self = self,
            let controller = self.window?.rootViewController as? FlutterViewController else {
        return
      }
      let channel = FlutterMethodChannel(
        name: "io.lumio.app/permissions",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "openExternalUrl":
          guard let urlString = call.arguments as? String,
                let url = URL(string: urlString) else {
            result(FlutterError(code: "invalid_args", message: "Missing url", details: nil))
            return
          }
          UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
              if success {
                result(nil)
              } else {
                result(FlutterError(code: "launch_failed", message: "Could not open URL", details: nil))
              }
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return ok
  }
}

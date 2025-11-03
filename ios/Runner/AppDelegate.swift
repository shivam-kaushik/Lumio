import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

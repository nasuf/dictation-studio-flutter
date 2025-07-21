import UIKit
import Flutter
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure Google Sign In with error handling
    do {
      if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let plist = NSDictionary(contentsOfFile: path),
         let clientId = plist["CLIENT_ID"] as? String {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign In configured with GoogleService-Info.plist")
      } else {
        // Fallback to hardcoded client ID if GoogleService-Info.plist is not found
        let fallbackClientId = "107650640585-tnqr7jl8i7gnqgbil128pj6c6h8l0g36.apps.googleusercontent.com"
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: fallbackClientId)
        print("⚠️ Using fallback Google client ID (GoogleService-Info.plist not found)")
      }
    } catch {
      print("❌ Error configuring Google Sign In: \(error)")
      // Don't let Google Sign In configuration failure crash the app
      // Just log the error and continue
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    do {
      if GIDSignIn.sharedInstance.handle(url) {
        return true
      }
    } catch {
      print("❌ Error handling URL with Google Sign In: \(error)")
    }
    return super.application(app, open: url, options: options)
  }
}
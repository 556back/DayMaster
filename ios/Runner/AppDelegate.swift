import Flutter
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    private var dayMasterBridge: DayMasterNativeBridge?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let url = launchOptions?[.url] as? URL { DayMasterNativeBridge.receive(url: url) }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        dayMasterBridge = DayMasterNativeBridge(messenger: engineBridge.applicationRegistrar.messenger())
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if DayMasterNativeBridge.receive(url: url) { return true }
        return super.application(app, open: url, options: options)
    }

    override func applicationSignificantTimeChange(_ application: UIApplication) {
        dayMasterBridge?.refreshForLocalTime()
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let id = response.notification.request.content.userInfo["eventId"] as? String {
            DispatchQueue.main.async {
                DayMasterNativeBridge.receive(eventID: id)
                completionHandler()
            }
        } else {
            super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
        }
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.identifier.hasPrefix("daymaster.event.") {
            completionHandler([.banner, .list, .sound])
        } else {
            super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
        }
    }
}
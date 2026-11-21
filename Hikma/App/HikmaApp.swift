import SwiftUI
import UserNotifications

@main
struct HikmaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = HikmaStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openedSlot)) { note in
                    if let slot = note.object as? Int { store.openFromNotification(slot: slot) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await HikmaStore.shared.refresh()
        }
    }
}

/// Shows notifications while the app is open, and opens the tapped quote.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static let openedSlot = Notification.Name("hikma.openedSlot")

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let slot = response.notification.request.content.userInfo["slot"] as? Int
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: AppDelegate.openedSlot, object: slot)
        }
        completionHandler()
    }
}

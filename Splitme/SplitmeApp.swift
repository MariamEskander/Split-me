import SwiftUI
import SwiftData
import UserNotifications

@main
struct SplitmeApp: App {
    @State private var notifications = NotificationCoordinator()

    init() {
        // Must be the first statement: anything that crashes during start-up
        // after this point is captured and reported.
        Observability.start()

        GoingOutReminders.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .splitmeLanguage()
        }
        .modelContainer(for: [Bill.self, SavedGroup.self, Essential.self])
    }
}

/// Holds the launch screen just long enough to land, then crossfades into the
/// app. The navy ground is identical on both sides of the transition, so only
/// the lockup moves.
private struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            RootView()
                .opacity(showingSplash ? 0 : 1)

            if showingSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            // Permissions can change in iOS Settings while the app is closed,
            // so the reminder is re-applied on every launch rather than only
            // when the Essentials screen happens to be open.
            await GoingOutReminders().rescheduleFromRemembered()

            #if DEBUG
            SampleData.seedIfNeeded(context)
            SampleData.dumpShareTextIfRequested(context)
            await SampleData.dumpNearbyIfRequested()
            await SampleData.dumpRemindersIfRequested(context)
            #endif
            try? await Task.sleep(for: .milliseconds(1900))
            withAnimation(.easeInOut(duration: 0.45)) { showingSplash = false }
        }
    }
}


/// Handles taps on the going-out reminder. "Remind me in 10 minutes" reschedules
/// the same content, which is the answer to "I saw it but my hands were full".
@Observable
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == GoingOutReminders.snoozeAction else { return }

        let content = response.notification.request.content.mutableCopy() as! UNMutableNotificationContent
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        )
        try? await center.add(request)
    }

    /// Show it even with Splitme open — you may be on your way out with the app
    /// in your hand.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

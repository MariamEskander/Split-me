import CoreLocation
import Foundation
import SwiftUI
import UserNotifications

/// Reminds you what you are about to walk out without.
///
/// The reminder is delivered by the system, not by the app: a notification is
/// registered against a circle around home with `notifyOnExit`, so it arrives
/// even when Billy has not been opened for days and nothing of ours is
/// running. That is also why it needs *Always* location — a "while in use"
/// permission cannot wake anything once you have put the phone in your pocket.
///
/// When only "while using the app" is granted, it falls back to a daily
/// reminder at a chosen time, which needs no location at all. The list is never
/// useless; it just gets less clever.
@MainActor
@Observable
final class GoingOutReminders: NSObject, CLLocationManagerDelegate {

    enum Readiness: Equatable {
        /// Everything needed for the leaving-home reminder is granted.
        case armedByLocation
        /// Notifications are on but location is not — daily reminder instead.
        case armedByTime
        case needsNotificationPermission
        case needsLocation
        case needsHome
        case off
    }

    private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var lastError: String?

    private let manager = CLLocationManager()
    private var pendingHomeRequest = false

    // MARK: Stored settings

    private enum Key {
        static let enabled = "splitme.reminders.enabled"
        static let latitude = "splitme.reminders.home.lat"
        static let longitude = "splitme.reminders.home.lon"
        static let radius = "splitme.reminders.home.radius"
        static let items = "splitme.reminders.items"
        static let hour = "splitme.reminders.fallback.hour"
        static let minute = "splitme.reminders.fallback.minute"
    }

    static let categoryIdentifier = "splitme.goingOut"
    static let snoozeAction = "splitme.goingOut.snooze"
    static let requestIdentifier = "splitme.goingOut.leavingHome"
    static let dailyIdentifier = "splitme.goingOut.daily"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Key.enabled) }
    }

    /// How far from home counts as "gone out". Below ~100m iOS gets noisy.
    var radius: Double {
        didSet { UserDefaults.standard.set(radius, forKey: Key.radius) }
    }

    var fallbackHour: Int {
        didSet { UserDefaults.standard.set(fallbackHour, forKey: Key.hour) }
    }

    var fallbackMinute: Int {
        didSet { UserDefaults.standard.set(fallbackMinute, forKey: Key.minute) }
    }

    private(set) var home: CLLocationCoordinate2D?

    override init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Key.enabled)
        // Written out on first run so every instance reads the same number
        // rather than each re-deriving a default.
        if defaults.object(forKey: Key.radius) == nil {
            defaults.set(150.0, forKey: Key.radius)
        }
        radius = defaults.double(forKey: Key.radius)
        fallbackHour = defaults.object(forKey: Key.hour) as? Int ?? 9
        fallbackMinute = defaults.object(forKey: Key.minute) as? Int ?? 0
        if let lat = defaults.object(forKey: Key.latitude) as? Double,
           let lon = defaults.object(forKey: Key.longitude) as? Double {
            home = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        super.init()
        manager.delegate = self
        locationStatus = manager.authorizationStatus
    }

    // MARK: Status

    var readiness: Readiness {
        guard isEnabled else { return .off }
        guard notificationStatus == .authorized || notificationStatus == .provisional else {
            return .needsNotificationPermission
        }
        if locationStatus == .authorizedAlways {
            return home == nil ? .needsHome : .armedByLocation
        }
        return locationStatus == .authorizedWhenInUse ? .armedByTime : .needsLocation
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
        locationStatus = manager.authorizationStatus
    }

    // MARK: Permissions

    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
        await refreshStatus()
    }

    /// iOS only offers "Always" as an upgrade *after* "while in use", so this
    /// escalates in two steps rather than asking for the big one up front.
    func requestLocationPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    // MARK: Home

    func useCurrentLocationAsHome() {
        pendingHomeRequest = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            pendingHomeRequest = false
            lastError = "Location access is off, so home cannot be set."
        }
    }

    private func setHome(_ coordinate: CLLocationCoordinate2D) {
        home = coordinate
        UserDefaults.standard.set(coordinate.latitude, forKey: Key.latitude)
        UserDefaults.standard.set(coordinate.longitude, forKey: Key.longitude)
        // readiness moves from .needsHome to .armedByLocation, so the geofence
        // has to be created now.
        Task { await rescheduleFromRemembered() }
    }

    func clearHome() {
        home = nil
        UserDefaults.standard.removeObject(forKey: Key.latitude)
        UserDefaults.standard.removeObject(forKey: Key.longitude)
    }

    // MARK: Scheduling

    /// Registers the notification categories once, so the actions on the
    /// delivered reminder work.
    static func registerCategories() {
        let snooze = UNNotificationAction(identifier: snoozeAction,
                                          title: String(localized: "Remind me in 10 minutes"),
                                          options: [])
        let category = UNNotificationCategory(identifier: categoryIdentifier,
                                              actions: [snooze],
                                              intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Rewrites the scheduled reminder to match the current list and settings.
    /// Called whenever the list or a setting changes, so what is scheduled and
    /// what is on screen never drift apart.
    func reschedule(items: [String]) async {
        UserDefaults.standard.set(items, forKey: Key.items)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.requestIdentifier, Self.dailyIdentifier
        ])

        // Schedule exactly what the screen claims is armed. Falling back to a
        // 9am daily reminder while the UI still says "Set home" would put a
        // notification on someone's phone that they never agreed to.
        guard !items.isEmpty else { return }
        let mode = readiness
        guard mode == .armedByLocation || mode == .armedByTime else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Heading out?")
        content.body = Self.body(for: items)
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.interruptionLevel = .timeSensitive

        do {
            if mode == .armedByLocation, let home {
                let region = CLCircularRegion(center: home, radius: radius,
                                              identifier: Self.requestIdentifier)
                region.notifyOnEntry = false
                region.notifyOnExit = true
                try await center.add(UNNotificationRequest(
                    identifier: Self.requestIdentifier,
                    content: content,
                    trigger: UNLocationNotificationTrigger(region: region, repeats: true)
                ))
            } else {
                var components = DateComponents()
                components.hour = fallbackHour
                components.minute = fallbackMinute
                try await center.add(UNNotificationRequest(
                    identifier: Self.dailyIdentifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                ))
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Re-applies the schedule from the remembered list.
    ///
    /// Without this, the common path silently produced no geofence at all: the
    /// toggle is flipped while location is still "when in use", which schedules
    /// the daily fallback; the user then grants "always"; the screen switches to
    /// "Armed", but the pending notification is still the daily one. Any change
    /// in authorisation has to rewrite the schedule, not just the label.
    func rescheduleFromRemembered() async {
        await refreshStatus()
        let items = UserDefaults.standard.stringArray(forKey: Key.items) ?? []
        guard !items.isEmpty else { return }
        await reschedule(items: items)
    }

    /// Fires in a few seconds so the wording and actions can be checked without
    /// walking out of the house.
    func sendPreview(items: [String]) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Heading out?")
        content.body = Self.body(for: items)
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func body(for items: [String]) -> String {
        let list = ListFormatter.localizedString(byJoining: items)
        return String(format: String(localized: "Got your %@?"), list)
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let previous = locationStatus
        locationStatus = manager.authorizationStatus

        if pendingHomeRequest,
           manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }

        // Upgrading to "always" changes which trigger is correct.
        if previous != manager.authorizationStatus {
            Task { await rescheduleFromRemembered() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard pendingHomeRequest, let location = locations.last else { return }
        pendingHomeRequest = false
        setHome(location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        pendingHomeRequest = false
        lastError = error.localizedDescription
    }
}

extension String {
    /// Short form for looking up a key from non-View code.
    init(localized key: String.LocalizationValue) {
        self.init(localized: key, bundle: .main)
    }
}

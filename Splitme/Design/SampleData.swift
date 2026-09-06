#if DEBUG
import CoreLocation
import Foundation
import SwiftData
import UserNotifications

/// Fills an empty store with one realistic bill so the design can be reviewed
/// (and screenshotted) without scanning a receipt first. Debug builds only, and
/// only when launched with `-seedSampleData`.
enum SampleData {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleData")
    }

    /// `-previewTab shares` opens the seeded bill straight onto that tab, so a
    /// screen can be reviewed without tapping through the app.
    static var previewTab: BillEditorView.Tab? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-previewTab"), index + 1 < args.count else { return nil }
        return BillEditorView.Tab.allCases.first { $0.rawValue.lowercased() == args[index + 1].lowercased() }
    }

    /// `-dumpShareText` prints the shareable message for the first bill to the
    /// console, so the exact wire format can be checked without a share sheet.
    static func dumpShareTextIfRequested(_ context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-dumpShareText"),
              let bill = try? context.fetch(FetchDescriptor<Bill>()).first else { return }
        var dump = "=== FULL BREAKDOWN ===\n" + BillSharing.summary(for: bill)
        if let first = bill.result.shares.first {
            dump += "\n=== ONE PERSON ===\n" + BillSharing.message(for: first, bill: bill)
        }
        print(dump)
        // Also written to disk: console capture from the simulator is unreliable.
        if let url = FileManager.default.urls(for: .documentDirectory,
                                              in: .userDomainMask).first?
            .appendingPathComponent("share-dump.txt") {
            try? dump.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// `-dumpNearby` runs the real place lookup — location fix and MapKit
    /// search — and writes what came back, so the networked path can be checked
    /// without tapping through the UI.
    @MainActor
    static func dumpNearbyIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-dumpNearby") else { return }
        let picker = PlacePicker()
        picker.findNearby()

        var report = "=== NEARBY LOOKUP ===\n"
        for _ in 0..<60 {
            try? await Task.sleep(for: .milliseconds(250))
            switch picker.status {
            case .ready(let places):
                report += "status: ready (\(places.count))\n"
                for place in places {
                    report += "  \(place.name) | \(place.detail ?? "—") | \(place.category ?? "—")\n"
                }
            case .noResults:   report += "status: no results\n"
            case .denied:      report += "status: location denied\n"
            case .failed(let m): report += "status: failed — \(m)\n"
            case .idle, .locating, .searching: continue
            }
            break
        }
        if report == "=== NEARBY LOOKUP ===\n" { report += "status: timed out\n" }

        /// `-dumpRates` does the same for the exchange-rate request.
        if ProcessInfo.processInfo.arguments.contains("-dumpRates") {
            let store = RatesStore()
            await store.refresh(force: true)
            report += "=== RATES ===\nstatus: \(store.status)\n"
            if let snapshot = store.snapshot {
                report += "base \(snapshot.base), \(snapshot.rates.count) currencies,"
                report += " published \(snapshot.publishedAt)\n"
                for pair in [("EGP", "USD"), ("USD", "EGP"), ("EGP", "AED"), ("KWD", "EGP")] {
                    let rate = snapshot.rate(from: pair.0, to: pair.1) ?? -1
                    let hundred = snapshot.convert(100, from: pair.0, to: pair.1) ?? -1
                    report += "  1 \(pair.0) = \(rate) \(pair.1)  ·  100 → \(hundred)\n"
                }
            }
        }

        print(report)
        if let url = FileManager.default.urls(for: .documentDirectory,
                                              in: .userDomainMask).first?
            .appendingPathComponent("api-dump.txt") {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// `-dumpReminders` seeds a few essentials, arms the reminder and reports
    /// what the system now holds — including the geofence — so the scheduling
    /// can be checked without walking out of the house.
    @MainActor
    static func dumpRemindersIfRequested(_ context: ModelContext) async {
        guard ProcessInfo.processInfo.arguments.contains("-dumpReminders") else { return }

        let existing = (try? context.fetch(FetchDescriptor<Essential>())) ?? []
        if existing.isEmpty {
            for (index, thing) in [("Water bottle", "waterbottle.fill"),
                                   ("ID", "person.text.rectangle.fill"),
                                   ("Keys", "key.fill")].enumerated() {
                context.insert(Essential(name: thing.0, symbol: thing.1, sortIndex: index))
            }
        }
        let names = ((try? context.fetch(
            FetchDescriptor<Essential>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? [])
            .filter(\.isEnabled).map(\.name)

        let reminders = GoingOutReminders()
        reminders.isEnabled = true
        await reminders.requestNotificationPermission()
        await reminders.refreshStatus()

        // Set home from the simulated location so the geofence path is the one
        // under test, not the fallback.
        if reminders.home == nil {
            reminders.useCurrentLocationAsHome()
            for _ in 0..<20 where reminders.home == nil {
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        await reminders.reschedule(items: names)

        var report = "=== GOING-OUT REMINDER ===\n"
        report += "notifications: \(reminders.notificationStatus.rawValue) "
        report += "(2 = authorized)\nlocation: \(reminders.locationStatus.rawValue) "
        report += "(3 = always, 4 = whenInUse)\n"
        report += "readiness: \(reminders.readiness)\n"
        report += "home: \(reminders.home.map { "\($0.latitude), \($0.longitude)" } ?? "not set")\n"
        report += "body: \(GoingOutReminders.body(for: names))\n"

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        report += "pending requests: \(pending.count)\n"
        for request in pending {
            report += "  id \(request.identifier)\n"
            report += "    title: \(request.content.title)\n"
            report += "    body: \(request.content.body)\n"
            report += "    category: \(request.content.categoryIdentifier)\n"
            switch request.trigger {
            case let trigger as UNLocationNotificationTrigger:
                let region = trigger.region as? CLCircularRegion
                report += "    trigger: location, repeats \(trigger.repeats)\n"
                report += "    region: r=\(region?.radius ?? -1)m "
                report += "onExit=\(region?.notifyOnExit ?? false) "
                report += "onEntry=\(region?.notifyOnEntry ?? false)\n"
            case let trigger as UNCalendarNotificationTrigger:
                report += "    trigger: daily at \(trigger.dateComponents.hour ?? -1):"
                report += String(format: "%02d", trigger.dateComponents.minute ?? 0)
                report += ", repeats \(trigger.repeats)\n"
            default:
                report += "    trigger: \(String(describing: request.trigger))\n"
            }
        }
        if let error = reminders.lastError { report += "error: \(error)\n" }

        print(report)
        if let url = FileManager.default.urls(for: .documentDirectory,
                                              in: .userDomainMask).first?
            .appendingPathComponent("reminders-dump.txt") {
            try? report.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func seedIfNeeded(_ context: ModelContext) {
        guard isRequested else { return }
        let existing = try? context.fetch(FetchDescriptor<Bill>())
        guard existing?.isEmpty ?? true else { return }

        // `-tinyBill` seeds a short, fully-assigned bill so the whole Shares
        // screen — including the footer artwork — fits on one page.
        if ProcessInfo.processInfo.arguments.contains("-tinyBill") {
            let small = Bill(title: "Coffee run", currencyCode: "EGP")
            let a = small.addParticipant(name: "Mariam")
            let b = small.addParticipant(name: "Omar")
            let flat = small.addItem(name: "Flat white", unitPriceMinor: 8500)
            flat.assigneeIDs = [a.id]
            let cortado = small.addItem(name: "Cortado", unitPriceMinor: 7500)
            cortado.assigneeIDs = [b.id]
            context.insert(small)
            return
        }

        let bill = Bill(title: "Zooba, Zamalek", currencyCode: "EGP")
        let mariam = bill.addParticipant(name: "Mariam")
        let omar = bill.addParticipant(name: "Omar")
        let nour = bill.addParticipant(name: "Nour")
        let hana = bill.addParticipant(name: "Hana")

        // `-manyPeople` stresses the assignee chip layout, which has to show
        // every person on every item rather than hiding them off an edge.
        if ProcessInfo.processInfo.arguments.contains("-manyPeople") {
            for name in ["Youssef", "Salma", "Karim", "Dina", "Tarek"] {
                _ = bill.addParticipant(name: name)
            }
        }

        let taameya = bill.addItem(name: "Taameya sandwich", unitPriceMinor: 6500, quantity: 2)
        taameya.assigneeIDs = [mariam.id, omar.id]
        let koshary = bill.addItem(name: "Koshary bowl", unitPriceMinor: 12000)
        koshary.assigneeIDs = [nour.id]
        let halloumi = bill.addItem(name: "Grilled halloumi", unitPriceMinor: 14500)
        halloumi.assigneeIDs = [hana.id]
        let mango = bill.addItem(name: "Mango & basil", unitPriceMinor: 5500, quantity: 3)
        mango.assigneeIDs = [mariam.id, nour.id, hana.id]
        _ = bill.addItem(name: "Bottled water", unitPriceMinor: 2000, quantity: 4)

        bill.servicePercent = 12
        bill.taxPercent = 14
        context.insert(bill)

        let work = SavedGroup(name: "Work lunch", memberNames: ["Mariam", "Omar", "Nour", "Hana"])
        work.lastUsedAt = Date()
        context.insert(work)
        context.insert(SavedGroup(name: "Flatmates", memberNames: ["Mariam", "Youssef"]))
    }
}
#endif

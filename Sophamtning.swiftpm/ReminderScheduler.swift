import Foundation
import UserNotifications

/// Lokala påminnelser kvällen före hämtning.
enum ReminderScheduler {
    private static let prefix = "sophamtning."

    enum Permission { case allowed, denied, notSupported, failed(String) }

    static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// Kollar aktuell behörighet och frågar användaren bara om ingen
    /// bedömning gjorts ännu. Läser alltid om status efteråt i stället för
    /// att lita på returvärdet, som kan bli false/fel vid samtidiga anrop.
    static func requestAuthorization() async -> Permission {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            var failure: String?
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch let error as UNError where error.code == .notificationsNotAllowed {
                // UNErrorDomain error 1: systemet tillåter inte att appen ens
                // frågar. Händer när appen körs inuti Swift Playgrounds.
                return .notSupported
            } catch {
                failure = error.localizedDescription
            }
            status = await center.notificationSettings().authorizationStatus
            if !isAllowed(status), let failure { return .failed(failure) }
        }
        return isAllowed(status) ? .allowed : .denied
    }

    static func clear() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func schedule(_ pickups: [Pickup], hour: Int, address: String) async {
        await clear()
        let center = UNUserNotificationCenter.current()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!

        // Slå ihop flera kärl som hämtas samma dag till en notis.
        let byDate = Dictionary(grouping: pickups, by: \.dateString)
        for (dateString, items) in byDate {
            guard let day = Pickup.dateFormatter.date(from: dateString),
                  let eve = calendar.date(byAdding: .day, value: -1, to: day),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: eve),
                  fire > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Sophämtning i morgon"
            content.body = items.map(\.group).sorted().joined(separator: ", ")
                + " – ställ fram kärlet. (\(address))"
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + dateString, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}

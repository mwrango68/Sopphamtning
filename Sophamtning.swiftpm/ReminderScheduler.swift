import Foundation
import UserNotifications

/// Lokala påminnelser kvällen före hämtning.
enum ReminderScheduler {
    private static let prefix = "sophamtning."

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
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

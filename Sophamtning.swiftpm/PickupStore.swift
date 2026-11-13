import Foundation
import SwiftUI

@MainActor
final class PickupStore: ObservableObject {
    @Published var address: String {
        didSet { UserDefaults.standard.set(address, forKey: Keys.address) }
    }
    @Published private(set) var pickups: [Pickup] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Problem med notiser – visas i Inställningar, skiljt från hämtfel.
    @Published private(set) var notificationProblem: String?
    private var reminderUpdate: Task<Void, Never>?

    @Published var remindersOn: Bool {
        didSet {
            UserDefaults.standard.set(remindersOn, forKey: Keys.reminders)
            Task { await updateReminders() }
        }
    }
    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.hour)
            Task { await updateReminders() }
        }
    }

    private let client = SVOAClient()

    private enum Keys {
        static let address = "address"
        static let pickups = "pickups"
        static let updated = "lastUpdated"
        static let reminders = "remindersOn"
        static let hour = "reminderHour"
    }

    init() {
        let d = UserDefaults.standard
        address = d.string(forKey: Keys.address) ?? ""
        remindersOn = d.bool(forKey: Keys.reminders)
        reminderHour = d.object(forKey: Keys.hour) as? Int ?? 19
        if let data = d.data(forKey: Keys.pickups),
           let cached = try? JSONDecoder().decode([Pickup].self, from: data) {
            pickups = cached
        }
        lastUpdated = d.object(forKey: Keys.updated) as? Date
    }

    /// Hämtningar från idag och framåt.
    var upcoming: [Pickup] {
        let today = Pickup.dateFormatter.string(from: Date())
        return pickups.filter { $0.dateString >= today }
    }

    var hasAddress: Bool { !address.trimmingCharacters(in: .whitespaces).isEmpty }

    func choose(address newAddress: String) async {
        address = newAddress
        pickups = []
        await refresh()
    }

    func refresh() async {
        guard hasAddress, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.pickups(for: address)
            if result.isEmpty { throw SVOAError.noResult }
            pickups = result
            lastUpdated = Date()
            errorMessage = nil
            let d = UserDefaults.standard
            d.set(try? JSONEncoder().encode(result), forKey: Keys.pickups)
            d.set(lastUpdated, forKey: Keys.updated)
            await updateReminders()
        } catch is CancellationError {
            // ignorera
        } catch let error as URLError where error.code == .cancelled {
            // ignorera
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Uppdatera om senaste hämtningen är äldre än 6 timmar.
    func refreshIfStale() async {
        if let last = lastUpdated, Date().timeIntervalSince(last) < 6 * 3600, !upcoming.isEmpty { return }
        await refresh()
    }

    func suggestions(for query: String) async throws -> [String] {
        try await client.suggestAddresses(query)
    }

    /// Körs i tur och ordning så att två samtidiga anrop (t.ex. reglaget och
    /// automatisk uppdatering vid start) inte frågar om behörighet samtidigt.
    func updateReminders() async {
        let previous = reminderUpdate
        let task = Task { [weak self] in
            await previous?.value
            await self?.applyReminders()
        }
        reminderUpdate = task
        await task.value
    }

    private func applyReminders() async {
        guard remindersOn else {
            notificationProblem = nil
            await ReminderScheduler.clear()
            return
        }
        switch await ReminderScheduler.requestAuthorization() {
        case .allowed:
            notificationProblem = nil
            await ReminderScheduler.schedule(upcoming, hour: reminderHour, address: address)
        case .denied:
            // Behåll användarens val – när notiser slås på i Inställningar
            // planeras de automatiskt nästa gång appen blir aktiv.
            notificationProblem = "Notiser är avstängda för appen. Slå på dem i Inställningar."
        case .notSupported:
            notificationProblem = "Notiser fungerar inte när appen körs inuti Swift Playgrounds. "
                + "Installera appen via TestFlight eller Xcode för att få påminnelser."
        case .failed(let reason):
            notificationProblem = "Kunde inte aktivera notiser: \(reason)"
        }
    }
}

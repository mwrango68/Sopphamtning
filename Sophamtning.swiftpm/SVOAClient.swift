import Foundation

/// En kommande hämtning för en avfallsgrupp/kärl.
struct Pickup: Identifiable, Codable, Hashable {
    var id: String { group + "|" + dateString }
    let group: String
    let dateString: String   // yyyy-MM-dd
    let frequency: String

    var date: Date? { Pickup.dateFormatter.date(from: dateString) }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Stockholm")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

enum SVOAError: LocalizedError {
    case badResponse(Int)
    case unreadable
    case noResult

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "Stockholm Vatten och Avfall svarade med felkod \(code). Försök igen senare."
        case .unreadable:
            return "Svaret från Stockholm Vatten och Avfall kunde inte tolkas. Tjänsten kan ha ändrats."
        case .noResult:
            return "Inga hämtningar hittades för adressen. Välj en adress ur förslagslistan."
        }
    }
}

/// Klient mot SVOA:s publika tjänst "När kommer sopbilen?".
/// OBS: Det är inget dokumenterat API – samma anrop som webbsidan gör.
struct SVOAClient {
    static let baseURL = URL(string: "https://www.stockholmvattenochavfall.se/villa-och-radhus/avfallstjanster/nar-kommer-sopbilen")!

    var session: URLSession = .shared

    /// Adressförslag, t.ex. "Testvägen 12, Bromma, 168 00".
    func suggestAddresses(_ query: String) async throws -> [String] {
        let term = query.split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard term.count >= 3 else { return [] }
        let data = try await get("AutoCompleteMe", item: URLQueryItem(name: "query", value: term))
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SVOAError.unreadable
        }
        var seen = Set<String>()
        return rows.compactMap { ($0["value"] ?? $0["Value"]) as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Kommande hämtningar för en fullständig adress.
    func pickups(for address: String) async throws -> [Pickup] {
        let data = try await get("Search", item: URLQueryItem(name: "address", value: address))
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SVOAError.unreadable
        }
        let pickups: [Pickup] = rows.compactMap { row in
            guard let group = (row["group"] ?? row["Group"]) as? String,
                  let rawDate = (row["executionDate"] ?? row["ExecutionDate"]) as? String,
                  rawDate.count >= 10 else { return nil }
            let date = String(rawDate.prefix(10))
            guard Pickup.dateFormatter.date(from: date) != nil else { return nil }
            let freq = (row["fetchFrequency"] ?? row["FetchFrequency"]) as? String ?? ""
            return Pickup(group: group.trimmingCharacters(in: .whitespaces), dateString: date, frequency: freq)
        }
        if !rows.isEmpty && pickups.isEmpty { throw SVOAError.unreadable }
        return pickups.sorted { ($0.dateString, $0.group) < ($1.dateString, $1.group) }
    }

    private func get(_ path: String, item: URLQueryItem) async throws -> Data {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [item]
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SVOAError.badResponse(http.statusCode)
        }
        return data
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PickupStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSearch = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !store.hasAddress {
                    ContentUnavailableView {
                        Label("Ingen adress vald", systemImage: "house")
                    } description: {
                        Text("Sök fram din adress för att se när Stockholm Vatten och Avfall hämtar dina sopor.")
                    } actions: {
                        Button("Välj adress") { showSearch = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    PickupListView()
                }
            }
            .navigationTitle("Sophämtning")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.hasAddress {
                        Button { Task { await store.refresh() } } label: {
                            Label("Uppdatera", systemImage: "arrow.clockwise")
                        }
                        .disabled(store.isLoading)
                    }
                    Button { showSearch = true } label: {
                        Label("Byt adress", systemImage: "magnifyingglass")
                    }
                    Button { showSettings = true } label: {
                        Label("Inställningar", systemImage: "bell")
                    }
                }
            }
            .sheet(isPresented: $showSearch) { AddressSearchView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .task { await store.refreshIfStale() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refreshIfStale() } }
        }
    }
}

struct PickupListView: View {
    @EnvironmentObject private var store: PickupStore

    var body: some View {
        List {
            Section {
                Label(store.address, systemImage: "house.fill")
                    .font(.headline)
            }

            if let error = store.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if let next = store.upcoming.first {
                Section("Nästa hämtning") {
                    NextPickupCard(date: next.date, groups: store.upcoming.filter { $0.dateString == next.dateString })
                }
            }

            if !store.upcoming.isEmpty {
                Section("Alla kommande hämtningar") {
                    ForEach(store.upcoming) { PickupRow(pickup: $0) }
                }
            } else if store.isLoading {
                Section { HStack { ProgressView(); Text("Hämtar från SVOA …") } }
            }

            Section {
                if let updated = store.lastUpdated {
                    Text("Uppdaterad \(updated.formatted(date: .abbreviated, time: .shortened))")
                }
                Link("Öppna SVOA:s sida \"När kommer sopbilen?\"", destination: SVOAClient.baseURL)
            } footer: {
                Text("Data hämtas från Stockholm Vatten och Avfalls publika söktjänst. Kontrollera vid tveksamhet på deras webbplats.")
            }
        }
        .refreshable { await store.refresh() }
    }
}

struct NextPickupCard: View {
    let date: Date?
    let groups: [Pickup]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(DateText.relative(date))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
            if let date {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sv_SE"))).capitalized)
                    .font(.title3)
            }
            ForEach(groups) { p in
                Label(p.group, systemImage: WasteIcon.symbol(for: p.group))
                    .font(.title3.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
    }
}

struct PickupRow: View {
    let pickup: Pickup

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: WasteIcon.symbol(for: pickup.group))
                .font(.title2)
                .foregroundStyle(WasteIcon.color(for: pickup.group))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(pickup.group).font(.headline)
                if !pickup.frequency.isEmpty {
                    Text(pickup.frequency).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let d = pickup.date {
                    Text(d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "sv_SE"))))
                        .font(.headline)
                }
                Text(DateText.relative(pickup.date)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum DateText {
    static func relative(_ date: Date?) -> String {
        guard let date else { return "–" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<0: return "Passerad"
        case 0: return "Idag"
        case 1: return "I morgon"
        default: return "Om \(days) dagar"
        }
    }
}

enum WasteIcon {
    static func symbol(for group: String) -> String {
        let g = group.lowercased()
        if g.contains("mat") { return "leaf.fill" }
        if g.contains("trädgård") { return "tree.fill" }
        if g.contains("plast") || g.contains("förpack") { return "shippingbox.fill" }
        if g.contains("papper") || g.contains("tidning") { return "newspaper.fill" }
        if g.contains("glas") { return "wineglass.fill" }
        if g.contains("slam") || g.contains("brunn") { return "drop.fill" }
        return "trash.fill"
    }

    static func color(for group: String) -> Color {
        let g = group.lowercased()
        if g.contains("mat") { return .brown }
        if g.contains("trädgård") { return .green }
        if g.contains("plast") || g.contains("förpack") { return .orange }
        if g.contains("papper") || g.contains("tidning") { return .blue }
        if g.contains("slam") || g.contains("brunn") { return .teal }
        return .gray
    }
}

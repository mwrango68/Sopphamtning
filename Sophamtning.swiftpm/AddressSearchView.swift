import SwiftUI

struct AddressSearchView: View {
    @EnvironmentObject private var store: PickupStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [String] = []
    @State private var isSearching = false
    @State private var message: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Gatuadress, t.ex. Storgatan 12", text: $query)
                            .focused($fieldFocused)
                            .textContentType(.fullStreetAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                        if !query.isEmpty {
                            Button {
                                query = ""
                                fieldFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { fieldFocused = true }
                }
                if let message {
                    Text(message).foregroundStyle(.secondary)
                }
                ForEach(results, id: \.self) { address in
                    Button {
                        Task {
                            await store.choose(address: address)
                            dismiss()
                        }
                    } label: {
                        Label(address, systemImage: "mappin.and.ellipse")
                    }
                }
            }
            .overlay { if isSearching { ProgressView() } }
            .scrollDismissesKeyboard(.interactively)
            .task(id: query) { await search() }
            .task {
                // Ge sheetet tid att visas klart innan tangentbordet tas fram.
                try? await Task.sleep(for: .milliseconds(500))
                fieldFocused = true
            }
            .navigationTitle("Välj adress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        fieldFocused.toggle()
                    } label: {
                        Image(systemName: fieldFocused ? "keyboard.chevron.compact.down" : "keyboard")
                    }
                    .accessibilityLabel(fieldFocused ? "Dölj tangentbord" : "Visa tangentbord")
                }
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3 else {
            results = []
            message = "Skriv minst tre tecken av gatuadressen."
            return
        }
        // Vänta lite så att vi inte anropar SVOA för varje tangenttryck.
        try? await Task.sleep(for: .milliseconds(400))
        if Task.isCancelled { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await store.suggestions(for: q)
            if Task.isCancelled { return }
            results = found
            message = found.isEmpty ? "Inga adresser hittades. Prova med bara gatunamnet." : nil
        } catch {
            if Task.isCancelled { return }
            results = []
            message = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: PickupStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Påminn kvällen före", isOn: $store.remindersOn)
                    Picker("Klockslag", selection: $store.reminderHour) {
                        ForEach(15..<23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    .disabled(!store.remindersOn)
                } header: {
                    Text("Påminnelser")
                } footer: {
                    Text("Notiserna planeras när appen öppnas och uppdaterar hämtdatum. Öppna appen då och då så hålls de aktuella.")
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}

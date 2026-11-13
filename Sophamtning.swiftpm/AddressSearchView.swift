import SwiftUI
import UIKit

struct AddressSearchView: View {
    @EnvironmentObject private var store: PickupStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [String] = []
    @State private var isSearching = false
    @State private var message: String?
    @State private var keyboardUp = true

    var body: some View {
        NavigationStack {
            List {
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
            .safeAreaInset(edge: .top) {
                AddressField(text: $query, isFirstResponder: $keyboardUp,
                             placeholder: "Gatuadress, t.ex. Storgatan 12")
                    .frame(height: 44)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .overlay { if isSearching { ProgressView() } }
            .task(id: query) { await search() }
            .navigationTitle("Välj adress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        keyboardUp.toggle()
                    } label: {
                        Image(systemName: keyboardUp ? "keyboard.chevron.compact.down" : "keyboard")
                    }
                    .accessibilityLabel(keyboardUp ? "Dölj tangentbord" : "Visa tangentbord")
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
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Påminn kvällen före", isOn: $store.remindersOn)
                    Picker("Klockslag", selection: $store.reminderHour) {
                        ForEach(15..<23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    .disabled(!store.remindersOn)
                    if let problem = store.notificationProblem {
                        Label(problem, systemImage: "bell.slash.fill")
                            .foregroundStyle(.orange)
                        Button("Öppna notisinställningar") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                } header: {
                    Text("Påminnelser")
                } footer: {
                    Text("Notiserna planeras när appen öppnas och uppdaterar hämtdatum. Öppna appen då och då så hålls de aktuella.")
                }
            }
            .task { await store.updateReminders() }
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

/// UIKit-textfält. SwiftUI:s TextField/.searchable tar inte alltid fram
/// tangentbordet i ett sheet i Swift Playgrounds – UITextField gör det.
struct AddressField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.textContentType = .fullStreetAddress
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
        field.keyboardType = .default
        field.returnKeyType = .search
        field.font = .preferredFont(forTextStyle: .body)
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 32, height: 20)
        field.leftView = icon
        field.leftViewMode = .always
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if isFirstResponder, !field.isFirstResponder {
            // Vänta tills fältet ligger i fönstret (sheetet animeras in).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if isFirstResponder, field.window != nil { field.becomeFirstResponder() }
            }
        } else if !isFirstResponder, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AddressField
        init(_ parent: AddressField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFirstResponder { parent.isFirstResponder = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFirstResponder { parent.isFirstResponder = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

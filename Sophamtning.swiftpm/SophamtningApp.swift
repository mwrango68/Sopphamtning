import SwiftUI

@main
struct SophamtningApp: App {
    @StateObject private var store = PickupStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

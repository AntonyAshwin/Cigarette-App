import SwiftUI
import SwiftData

@main
struct Cigarette_AppApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { HomeDashboardView() }
                    .tabItem { Label("Home", systemImage: "house") }

                NavigationStack { ManageTypesView() }
                    .tabItem { Label("Manage", systemImage: "gearshape") }
            }
        }
        .modelContainer(for: [CigType.self, SmokeEvent.self])
    }
}

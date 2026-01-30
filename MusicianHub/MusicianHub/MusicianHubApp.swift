import SwiftUI

@main
struct MusicianHubApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

class AppState: ObservableObject {
    @Published var selectedTab: Tab = .pulse
    @Published var selectedMusician: Musician?
    @Published var isProcessingMessages: Bool = false
    @Published var lastSyncDate: Date?

    enum Tab: String, CaseIterable {
        // Nexus views
        case pulse = "Pulse"
        case threads = "Threads"
        case workbench = "Workbench"
        // Traditional views
        case dashboard = "Dashboard"
        case musicians = "Musicians"
        case events = "Events"
        case actions = "Actions"
        case plans = "Plans"
        case messages = "Messages"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .pulse: return "bolt.heart"
            case .threads: return "bubble.left.and.bubble.right"
            case .workbench: return "hammer"
            case .dashboard: return "square.grid.2x2"
            case .musicians: return "person.2"
            case .events: return "calendar"
            case .actions: return "checkmark.circle"
            case .plans: return "list.bullet.clipboard"
            case .messages: return "message"
            case .settings: return "gear"
            }
        }
    }
}

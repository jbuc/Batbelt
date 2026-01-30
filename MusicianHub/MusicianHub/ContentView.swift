import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        #if os(iOS)
        TabView(selection: $appState.selectedTab) {
            // Nexus Views
            PulseView()
                .tabItem {
                    Label("Pulse", systemImage: "bolt.heart")
                }
                .tag(AppState.Tab.pulse)

            ThreadsView()
                .tabItem {
                    Label("Threads", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(AppState.Tab.threads)

            WorkbenchView()
                .tabItem {
                    Label("Workbench", systemImage: "hammer")
                }
                .tag(AppState.Tab.workbench)

            MusiciansView()
                .tabItem {
                    Label(AppState.Tab.musicians.rawValue, systemImage: AppState.Tab.musicians.icon)
                }
                .tag(AppState.Tab.musicians)

            DashboardView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(AppState.Tab.dashboard)
        }
        #else
        NavigationSplitView {
            SidebarView()
        } detail: {
            switch appState.selectedTab {
            case .pulse:
                PulseView()
            case .threads:
                ThreadsView()
            case .workbench:
                WorkbenchView()
            case .dashboard:
                DashboardView()
            case .musicians:
                MusiciansView()
            case .events:
                EventsView()
            case .actions:
                ActionsView()
            case .plans:
                PlansView()
            case .messages:
                MessagesView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        #endif
    }
}

#if os(macOS)
struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedTab) {
            Section("Nexus") {
                Label("Pulse", systemImage: "bolt.heart")
                    .tag(AppState.Tab.pulse)
                Label("Threads", systemImage: "bubble.left.and.bubble.right")
                    .tag(AppState.Tab.threads)
                Label("Workbench", systemImage: "hammer")
                    .tag(AppState.Tab.workbench)
            }

            Section("Overview") {
                Label(AppState.Tab.dashboard.rawValue, systemImage: AppState.Tab.dashboard.icon)
                    .tag(AppState.Tab.dashboard)
            }

            Section("Organization") {
                Label(AppState.Tab.musicians.rawValue, systemImage: AppState.Tab.musicians.icon)
                    .tag(AppState.Tab.musicians)
                Label(AppState.Tab.events.rawValue, systemImage: AppState.Tab.events.icon)
                    .tag(AppState.Tab.events)
                Label(AppState.Tab.actions.rawValue, systemImage: AppState.Tab.actions.icon)
                    .tag(AppState.Tab.actions)
                Label(AppState.Tab.plans.rawValue, systemImage: AppState.Tab.plans.icon)
                    .tag(AppState.Tab.plans)
            }

            Section("Communications") {
                Label(AppState.Tab.messages.rawValue, systemImage: AppState.Tab.messages.icon)
                    .tag(AppState.Tab.messages)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Nexus")
    }
}
#endif

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}

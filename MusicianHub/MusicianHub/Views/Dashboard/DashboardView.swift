import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var communicationService = CommunicationService.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.date, ascending: true)],
        predicate: NSPredicate(format: "date >= %@", Date() as NSDate),
        animation: .default
    )
    private var upcomingEvents: FetchedResults<Event>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Action.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO"),
        animation: .default
    )
    private var pendingActions: FetchedResults<Action>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)],
        predicate: NSPredicate(format: "isProcessed == NO"),
        animation: .default
    )
    private var unprocessedMessages: FetchedResults<Message>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Overview
                    statsSection

                    // Quick Actions
                    quickActionsSection

                    // Upcoming Events
                    upcomingEventsSection

                    // Pending Actions
                    pendingActionsSection

                    // Unprocessed Messages
                    if !unprocessedMessages.isEmpty {
                        unprocessedMessagesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: processMessages) {
                        if communicationService.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Process Messages", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(communicationService.isProcessing)
                }
            }
            .refreshable {
                dataManager.refreshAllData()
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Events",
                value: "\(upcomingEvents.prefix(30).count)",
                subtitle: "Upcoming",
                icon: "calendar",
                color: .blue
            )

            StatCard(
                title: "Actions",
                value: "\(pendingActions.count)",
                subtitle: "Pending",
                icon: "checkmark.circle",
                color: .orange
            )

            StatCard(
                title: "Messages",
                value: "\(unprocessedMessages.count)",
                subtitle: "To Process",
                icon: "message",
                color: .green
            )

            StatCard(
                title: "Overdue",
                value: "\(pendingActions.filter { $0.isOverdue }.count)",
                subtitle: "Actions",
                icon: "exclamationmark.triangle",
                color: .red
            )
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Musician",
                    icon: "person.badge.plus",
                    color: .purple
                ) {
                    // Navigate to add musician
                }

                QuickActionButton(
                    title: "New Event",
                    icon: "calendar.badge.plus",
                    color: .blue
                ) {
                    // Navigate to add event
                }

                QuickActionButton(
                    title: "Add Action",
                    icon: "plus.circle",
                    color: .orange
                ) {
                    // Navigate to add action
                }

                QuickActionButton(
                    title: "Import Note",
                    icon: "square.and.arrow.down",
                    color: .green
                ) {
                    // Import a note
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Upcoming Events Section

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    EventsView()
                }
                .font(.subheadline)
            }

            if upcomingEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Upcoming Events",
                    message: "Events will appear here when extracted from your messages"
                )
            } else {
                ForEach(Array(upcomingEvents.prefix(5))) { event in
                    EventRowView(event: event)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Pending Actions Section

    private var pendingActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Actions")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    ActionsView()
                }
                .font(.subheadline)
            }

            if pendingActions.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "All Caught Up!",
                    message: "No pending actions. Actions will appear when extracted from messages."
                )
            } else {
                ForEach(Array(pendingActions.prefix(5))) { action in
                    ActionRowView(action: action)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Unprocessed Messages Section

    private var unprocessedMessagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unprocessed Messages")
                    .font(.headline)

                Spacer()

                Button("Process All") {
                    processMessages()
                }
                .font(.subheadline)
                .disabled(communicationService.isProcessing)
            }

            ForEach(Array(unprocessedMessages.prefix(3))) { message in
                MessagePreviewRow(message: message)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func processMessages() {
        Task {
            await communicationService.processAllUnprocessedMessages()
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct EventRowView: View {
    @ObservedObject var event: Event

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .font(.title3)
                .foregroundColor(Color(event.type.color))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.wrappedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text(event.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if event.isConfirmed {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ActionRowView: View {
    @ObservedObject var action: Action
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggleComplete) {
                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(action.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.wrappedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(action.isCompleted)

                HStack {
                    Image(systemName: action.priorityLevel.icon)
                        .foregroundColor(Color(action.priorityLevel.color))
                        .font(.caption)

                    if let dueDate = action.dueDate {
                        Text(action.relativeDueDate)
                            .font(.caption)
                            .foregroundColor(action.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer()

            if action.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }

    private func toggleComplete() {
        withAnimation {
            action.isCompleted.toggle()
            action.completedAt = action.isCompleted ? Date() : nil
            try? viewContext.save()
        }
    }
}

struct MessagePreviewRow: View {
    @ObservedObject var message: Message

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.messageSource.icon)
                .font(.title3)
                .foregroundColor(Color(message.messageSource.color))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.wrappedSenderName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(message.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(message.relativeReceivedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
}

import SwiftUI
import CoreData

// MARK: - Workbench View (Split-Screen Productivity)

struct WorkbenchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedMessage: Message?
    @State private var draftText = ""
    @State private var workbenchMode: WorkbenchMode = .notes
    @State private var showingMessagePicker = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)],
        predicate: NSPredicate(format: "isProcessed == NO"),
        animation: .default
    )
    private var unprocessedMessages: FetchedResults<Message>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Action.dueDate, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO"),
        animation: .default
    )
    private var pendingActions: FetchedResults<Action>

    enum WorkbenchMode: String, CaseIterable {
        case notes = "Notes"
        case actions = "Actions"
        case compose = "Compose"

        var icon: String {
            switch self {
            case .notes: return "note.text"
            case .actions: return "checkmark.circle"
            case .compose: return "square.and.pencil"
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                #if os(macOS)
                HSplitView {
                    conversationPane
                        .frame(minWidth: 300)
                    workPane
                        .frame(minWidth: 350)
                }
                #else
                if geometry.size.width > 700 {
                    // iPad landscape or large screen
                    HStack(spacing: 0) {
                        conversationPane
                            .frame(width: geometry.size.width * 0.5)

                        Divider()

                        workPane
                            .frame(width: geometry.size.width * 0.5)
                    }
                } else {
                    // iPhone or iPad portrait - use tabs
                    TabView {
                        conversationPane
                            .tabItem {
                                Label("Messages", systemImage: "message")
                            }

                        workPane
                            .tabItem {
                                Label("Workbench", systemImage: "hammer")
                            }
                    }
                }
                #endif
            }
            .navigationTitle("Workbench")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Conversation Pane

    private var conversationPane: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversation")
                    .font(.headline)
                Spacer()
                Button {
                    showingMessagePicker = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            if let message = selectedMessage {
                // Selected message view
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Message header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(message.senderName ?? "Unknown")
                                    .font(.headline)
                                Text(message.messageSource.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(message.receivedAt?.formatted() ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // Subject
                        if let subject = message.subject, !subject.isEmpty {
                            Text(subject)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        // Content
                        Text(message.content ?? "")
                            .font(.body)

                        // Extracted items
                        if message.hasExtractedItems {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Extracted Items")
                                    .font(.headline)

                                ForEach(message.extractedEventsArray) { event in
                                    ExtractedItemCard(
                                        icon: "calendar",
                                        title: event.wrappedTitle,
                                        subtitle: event.formattedDate,
                                        color: .blue
                                    )
                                }

                                ForEach(message.extractedActionsArray) { action in
                                    ExtractedItemCard(
                                        icon: "checkmark.circle",
                                        title: action.wrappedTitle,
                                        subtitle: action.relativeDueDate,
                                        color: .orange
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Quick actions
                HStack(spacing: 12) {
                    WorkbenchQuickAction(icon: "arrow.turn.up.left", title: "Reply") {
                        workbenchMode = .compose
                    }
                    WorkbenchQuickAction(icon: "calendar.badge.plus", title: "Event") {
                        createEventFromMessage(message)
                    }
                    WorkbenchQuickAction(icon: "checkmark.circle", title: "Action") {
                        createActionFromMessage(message)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            } else {
                // No message selected
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Select a message")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose from unprocessed messages or pick any conversation to work with.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .sheet(isPresented: $showingMessagePicker) {
            MessagePickerSheet(selectedMessage: $selectedMessage)
        }
    }

    // MARK: - Work Pane

    private var workPane: some View {
        VStack(spacing: 0) {
            // Mode picker
            Picker("Mode", selection: $workbenchMode) {
                ForEach(WorkbenchMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch workbenchMode {
            case .notes:
                notesPane
            case .actions:
                actionsPane
            case .compose:
                composePane
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Notes Pane

    private var notesPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Notes")
                .font(.headline)
                .padding(.horizontal)

            TextEditor(text: $draftText)
                .font(.body)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)

            HStack {
                Spacer()

                Button("Save as Note") {
                    saveAsNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    // MARK: - Actions Pane

    private var actionsPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Pending Actions")
                    .font(.headline)
                Spacer()
                Text("\(pendingActions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            List {
                ForEach(pendingActions) { action in
                    WorkbenchActionRow(action: action)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Compose Pane

    private var composePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compose Reply")
                .font(.headline)
                .padding(.horizontal)

            if let message = selectedMessage {
                HStack {
                    Text("To: \(message.senderName ?? "Unknown")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }

            TextEditor(text: $draftText)
                .font(.body)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)

            HStack {
                Spacer()

                Button("Send") {
                    sendReply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    // MARK: - Actions

    private func createEventFromMessage(_ message: Message) {
        let event = Event(context: viewContext)
        event.id = UUID()
        event.title = "Event from \(message.senderName ?? "message")"
        event.date = Date()
        event.sourceMessage = message
        event.createdAt = Date()

        try? viewContext.save()
    }

    private func createActionFromMessage(_ message: Message) {
        let action = Action(context: viewContext)
        action.id = UUID()
        action.title = "Follow up: \(message.senderName ?? "Unknown")"
        action.sourceMessage = message
        action.createdAt = Date()
        action.priority = ActionPriority.medium.rawValue
        action.category = ActionCategory.followUp.rawValue

        try? viewContext.save()
    }

    private func saveAsNote() {
        let message = Message(context: viewContext)
        message.id = UUID()
        message.content = draftText
        message.source = MessageSource.note.rawValue
        message.senderName = "Self"
        message.receivedAt = Date()
        message.createdAt = Date()
        message.isProcessed = false

        try? viewContext.save()
        draftText = ""
    }

    private func sendReply() {
        // In a real app, this would send the reply
        // For now, just save as a note
        saveAsNote()
    }
}

// MARK: - Supporting Views

struct ExtractedItemCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct WorkbenchQuickAction: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct WorkbenchActionRow: View {
    @ObservedObject var action: Action
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    action.isCompleted.toggle()
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(action.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.wrappedTitle)
                    .font(.subheadline)
                    .strikethrough(action.isCompleted)

                if let dueDate = action.dueDate {
                    Text(action.relativeDueDate)
                        .font(.caption)
                        .foregroundColor(action.isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            Image(systemName: action.priorityLevel.icon)
                .foregroundColor(Color(action.priorityLevel.color))
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct MessagePickerSheet: View {
    @Binding var selectedMessage: Message?
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)]
    )
    private var messages: FetchedResults<Message>

    var body: some View {
        NavigationStack {
            List {
                Section("Unprocessed") {
                    ForEach(messages.filter { !$0.isProcessed }) { message in
                        MessagePickerRow(message: message)
                            .onTapGesture {
                                selectedMessage = message
                                dismiss()
                            }
                    }
                }

                Section("All Messages") {
                    ForEach(messages.filter { $0.isProcessed }) { message in
                        MessagePickerRow(message: message)
                            .onTapGesture {
                                selectedMessage = message
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle("Select Message")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct MessagePickerRow: View {
    let message: Message

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.messageSource.icon)
                .foregroundColor(Color(message.messageSource.color))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.senderName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(message.content ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if !message.isProcessed {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkbenchView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

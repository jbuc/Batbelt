import SwiftUI
import CoreData

struct MessagesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var communicationService = CommunicationService.shared
    @State private var searchText = ""
    @State private var selectedMessage: Message?
    @State private var filterSource: MessageSource?
    @State private var showProcessedOnly = false
    @State private var showingAddMessage = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)],
        animation: .default
    )
    private var allMessages: FetchedResults<Message>

    var filteredMessages: [Message] {
        var messages = Array(allMessages)

        // Filter by source
        if let source = filterSource {
            messages = messages.filter { $0.messageSource == source }
        }

        // Filter by processed status
        if showProcessedOnly {
            messages = messages.filter { $0.isProcessed }
        }

        // Search filter
        if !searchText.isEmpty {
            messages = messages.filter {
                $0.wrappedContent.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedSenderName.localizedCaseInsensitiveContains(searchText) ||
                ($0.subject ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return messages
    }

    var unprocessedMessages: [Message] {
        filteredMessages.filter { !$0.isProcessed }
    }

    var processedMessages: [Message] {
        filteredMessages.filter { $0.isProcessed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allMessages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }
            .navigationTitle("Messages")
            .searchable(text: $searchText, prompt: "Search messages...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddMessage = true
                        } label: {
                            Label("Add Message", systemImage: "plus")
                        }

                        Button {
                            processAllMessages()
                        } label: {
                            Label("Process All", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(unprocessedMessages.isEmpty || communicationService.isProcessing)

                        Divider()

                        Button {
                            generateSampleData()
                        } label: {
                            Label("Generate Sample Data", systemImage: "wand.and.stars")
                        }
                    } label: {
                        if communicationService.isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Options", systemImage: "ellipsis.circle")
                        }
                    }
                }

                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu {
                        Button {
                            filterSource = nil
                        } label: {
                            if filterSource == nil {
                                Label("All Sources", systemImage: "checkmark")
                            } else {
                                Text("All Sources")
                            }
                        }

                        Divider()

                        ForEach(MessageSource.allCases, id: \.self) { source in
                            Button {
                                filterSource = source
                            } label: {
                                Label(source.displayName, systemImage: filterSource == source ? "checkmark" : source.icon)
                            }
                        }
                    } label: {
                        Label("Source", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Toggle("Processed Only", isOn: $showProcessedOnly)
                }
            }
            .sheet(item: $selectedMessage) { message in
                MessageDetailView(message: message)
            }
            .sheet(isPresented: $showingAddMessage) {
                AddMessageView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message")
        } description: {
            Text("Import messages from your texts, emails, or notes to extract events, actions, and plans.")
        } actions: {
            VStack(spacing: 12) {
                Button("Add Message") {
                    showingAddMessage = true
                }
                .buttonStyle(.borderedProminent)

                Button("Generate Sample Data") {
                    generateSampleData()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var messagesList: some View {
        List {
            if !unprocessedMessages.isEmpty {
                Section {
                    ForEach(unprocessedMessages) { message in
                        MessageRow(message: message)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMessage = message
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    processMessage(message)
                                } label: {
                                    Label("Process", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMessage(message)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    ignoreMessage(message)
                                } label: {
                                    Label("Ignore", systemImage: "eye.slash")
                                }
                                .tint(.orange)
                            }
                    }
                } header: {
                    HStack {
                        Label("Unprocessed", systemImage: "tray.full")
                        Spacer()
                        Button("Process All") {
                            processAllMessages()
                        }
                        .font(.caption)
                        .disabled(communicationService.isProcessing)
                    }
                }
            }

            if !processedMessages.isEmpty {
                Section("Processed") {
                    ForEach(processedMessages) { message in
                        MessageRow(message: message)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMessage = message
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteMessage(message)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    reprocessMessage(message)
                                } label: {
                                    Label("Reprocess", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func processMessage(_ message: Message) {
        Task {
            try? await communicationService.processMessage(message)
        }
    }

    private func processAllMessages() {
        Task {
            await communicationService.processAllUnprocessedMessages()
        }
    }

    private func reprocessMessage(_ message: Message) {
        Task {
            try? await communicationService.reprocessMessage(message)
        }
    }

    private func ignoreMessage(_ message: Message) {
        withAnimation {
            message.status = .ignored
            message.isProcessed = true
            try? viewContext.save()
        }
    }

    private func deleteMessage(_ message: Message) {
        withAnimation {
            // Delete extracted items too
            if let events = message.extractedEvents as? Set<Event> {
                events.forEach { viewContext.delete($0) }
            }
            if let actions = message.extractedActions as? Set<Action> {
                actions.forEach { viewContext.delete($0) }
            }
            viewContext.delete(message)
            try? viewContext.save()
        }
    }

    private func generateSampleData() {
        communicationService.generateSampleData()
    }
}

struct MessageRow: View {
    @ObservedObject var message: Message

    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: message.messageSource.icon)
                .font(.title2)
                .foregroundColor(Color(message.messageSource.color))
                .frame(width: 40, height: 40)
                .background(Color(message.messageSource.color).opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.wrappedSenderName)
                        .font(.headline)

                    Spacer()

                    Text(message.relativeReceivedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let subject = message.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Text(message.preview)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Status badges
                HStack(spacing: 8) {
                    if message.isProcessed && message.hasExtractedItems {
                        if !message.extractedEventsArray.isEmpty {
                            Label("\(message.extractedEventsArray.count)", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        if !message.extractedActionsArray.isEmpty {
                            Label("\(message.extractedActionsArray.count)", systemImage: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }

                    if message.status == .ignored {
                        Label("Ignored", systemImage: "eye.slash")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !message.isProcessed {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct MessageDetailView: View {
    @ObservedObject var message: Message
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var communicationService = CommunicationService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: message.messageSource.icon)
                            .font(.largeTitle)
                            .foregroundColor(Color(message.messageSource.color))
                            .frame(width: 60, height: 60)
                            .background(Color(message.messageSource.color).opacity(0.2))
                            .cornerRadius(12)

                        VStack(spacing: 8) {
                            Text(message.wrappedSenderName)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(message.messageSource.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text(message.formattedReceivedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                    // Subject (if email)
                    if let subject = message.subject, !subject.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(subject)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(message.wrappedContent)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Extracted Events
                    if !message.extractedEventsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Extracted Events", systemImage: "calendar")
                                .font(.headline)

                            ForEach(message.extractedEventsArray) { event in
                                EventRowView(event: event)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Extracted Actions
                    if !message.extractedActionsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Extracted Actions", systemImage: "checkmark.circle")
                                .font(.headline)

                            ForEach(message.extractedActionsArray) { action in
                                ActionRowView(action: action)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Processing Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Image(systemName: message.isProcessed ? "checkmark.circle.fill" : "clock")
                                .foregroundColor(message.isProcessed ? .green : .orange)

                            Text(message.status.displayName)
                                .font(.subheadline)

                            if let processedAt = message.processedAt {
                                Spacer()
                                Text("Processed \(processedAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Actions
                    VStack(spacing: 12) {
                        if !message.isProcessed {
                            Button {
                                Task {
                                    try? await communicationService.processMessage(message)
                                }
                            } label: {
                                if communicationService.isProcessing {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Label("Process Message", systemImage: "arrow.triangle.2.circlepath")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(communicationService.isProcessing)
                        } else {
                            Button {
                                Task {
                                    try? await communicationService.reprocessMessage(message)
                                }
                            } label: {
                                Label("Reprocess", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Message")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var communicationService = CommunicationService.shared

    @State private var content = ""
    @State private var source: MessageSource = .note
    @State private var senderName = ""
    @State private var subject = ""
    @State private var processImmediately = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Message Type") {
                    Picker("Source", selection: $source) {
                        ForEach(MessageSource.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.icon)
                                .tag(s)
                        }
                    }
                }

                if source != .note {
                    Section("Sender") {
                        TextField("Name", text: $senderName)
                    }
                }

                if source == .email {
                    Section("Subject") {
                        TextField("Subject", text: $subject)
                    }
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }

                Section {
                    Toggle("Process Immediately", isOn: $processImmediately)
                } footer: {
                    Text("When enabled, the message will be automatically analyzed to extract events, actions, and plans.")
                }
            }
            .navigationTitle("Add Message")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMessage()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveMessage() {
        let message = communicationService.importMessage(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            senderName: senderName.isEmpty ? (source == .note ? "Self" : nil) : senderName,
            subject: subject.isEmpty ? nil : subject
        )

        if processImmediately {
            Task {
                try? await communicationService.processMessage(message)
            }
        }

        dismiss()
    }
}

#Preview {
    MessagesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

import SwiftUI
import CoreData

// MARK: - Threads View (Merged Conversations)

struct ThreadsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedThread: ConversationThread?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Musician.name, ascending: true)],
        animation: .default
    )
    private var musicians: FetchedResults<Musician>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)],
        animation: .default
    )
    private var messages: FetchedResults<Message>

    var threads: [ConversationThread] {
        // Group messages by contact
        var threadMap: [String: ConversationThread] = [:]

        for message in messages {
            let contactKey = message.senderName?.lowercased() ?? "unknown"

            if var thread = threadMap[contactKey] {
                thread.messages.append(message)
                thread.lastActivity = max(thread.lastActivity, message.receivedAt ?? Date.distantPast)
                thread.unreadCount += message.isProcessed ? 0 : 1
                threadMap[contactKey] = thread
            } else {
                let musician = musicians.first { $0.name?.lowercased() == contactKey }
                threadMap[contactKey] = ConversationThread(
                    contactName: message.senderName ?? "Unknown",
                    musician: musician,
                    messages: [message],
                    lastActivity: message.receivedAt ?? Date(),
                    unreadCount: message.isProcessed ? 0 : 1
                )
            }
        }

        var result = Array(threadMap.values)

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.contactName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by last activity
        return result.sorted { $0.lastActivity > $1.lastActivity }
    }

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    emptyState
                } else {
                    threadsList
                }
            }
            .navigationTitle("Threads")
            .searchable(text: $searchText, prompt: "Search conversations...")
            .sheet(item: $selectedThread) { thread in
                ThreadDetailView(thread: thread)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Your conversations will appear here, merged across email, text, and other sources.")
        }
    }

    private var threadsList: some View {
        List {
            ForEach(threads) { thread in
                ThreadRow(thread: thread)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedThread = thread
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Conversation Thread

struct ConversationThread: Identifiable {
    let id = UUID()
    var contactName: String
    var musician: Musician?
    var messages: [Message]
    var lastActivity: Date
    var unreadCount: Int

    var sources: Set<MessageSource> {
        Set(messages.compactMap { MessageSource(rawValue: $0.source ?? "") })
    }

    var lastMessage: Message? {
        messages.max(by: { ($0.receivedAt ?? .distantPast) < ($1.receivedAt ?? .distantPast) })
    }

    var initials: String {
        let components = contactName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(contactName.prefix(2)).uppercased()
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: ConversationThread

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 56, height: 56)

                if let musician = thread.musician {
                    Text(musician.initials)
                        .font(.headline)
                        .foregroundColor(.purple)
                } else {
                    Text(thread.initials)
                        .font(.headline)
                        .foregroundColor(.purple)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(thread.contactName)
                        .font(.headline)

                    if thread.musician != nil {
                        Image(systemName: "music.note")
                            .foregroundColor(.purple)
                            .font(.caption)
                    }

                    Spacer()

                    Text(thread.lastActivity, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Source icons
                HStack(spacing: 4) {
                    ForEach(Array(thread.sources), id: \.self) { source in
                        Image(systemName: source.icon)
                            .font(.caption2)
                            .foregroundColor(Color(source.color))
                    }
                }

                // Last message preview
                if let lastMessage = thread.lastMessage {
                    Text(lastMessage.content ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            if thread.unreadCount > 0 {
                Text("\(thread.unreadCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Thread Detail View

struct ThreadDetailView: View {
    let thread: ConversationThread
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var replyText = ""

    var sortedMessages: [Message] {
        thread.messages.sorted { ($0.receivedAt ?? .distantPast) < ($1.receivedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedMessages) { message in
                                ThreadMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if let lastID = sortedMessages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }

                Divider()

                // Reply bar
                HStack(spacing: 12) {
                    TextField("Reply...", text: $replyText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button {
                        sendReply()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(thread.contactName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let musician = thread.musician {
                        NavigationLink {
                            MusicianDetailView(musician: musician)
                        } label: {
                            Image(systemName: "person.circle")
                        }
                    }
                }
            }
        }
    }

    private func sendReply() {
        // In a real app, this would send via the appropriate channel
        let message = Message.create(
            in: viewContext,
            content: replyText,
            source: .note,
            senderName: "Me"
        )
        message.musician = thread.musician

        try? viewContext.save()
        replyText = ""
    }
}

// MARK: - Thread Message Bubble

struct ThreadMessageBubble: View {
    let message: Message

    var isOutgoing: Bool {
        message.senderName?.lowercased() == "me" || message.senderName?.lowercased() == "self"
    }

    var body: some View {
        HStack {
            if isOutgoing { Spacer() }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                // Source indicator
                HStack(spacing: 4) {
                    Image(systemName: message.messageSource.icon)
                        .font(.caption2)
                    Text(message.messageSource.displayName)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)

                // Message content
                Text(message.content ?? "")
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isOutgoing ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundColor(isOutgoing ? .white : .primary)
                    .cornerRadius(20)

                // Timestamp
                Text(message.receivedAt?.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Extracted items
                if !message.extractedEventsArray.isEmpty || !message.extractedActionsArray.isEmpty {
                    HStack(spacing: 8) {
                        if !message.extractedEventsArray.isEmpty {
                            Label("\(message.extractedEventsArray.count) event(s)", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        if !message.extractedActionsArray.isEmpty {
                            Label("\(message.extractedActionsArray.count) action(s)", systemImage: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isOutgoing ? .trailing : .leading)

            if !isOutgoing { Spacer() }
        }
    }
}

#Preview {
    ThreadsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

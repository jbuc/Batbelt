import SwiftUI
import CoreData

// MARK: - Pulse View (Unified Timeline)

struct PulseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var brain = NexusBrain.shared
    @State private var selectedItem: UnifiedCommunicationItem?
    @State private var showingBrief: UnifiedBrief?
    @State private var filterSource: CommunicationSource?
    @State private var searchText = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)],
        animation: .default
    )
    private var messages: FetchedResults<Message>

    var unifiedItems: [UnifiedCommunicationItem] {
        var items = messages.map { UnifiedCommunicationItem(from: $0) }

        // Apply source filter
        if let source = filterSource {
            items = items.filter { $0.source == source }
        }

        // Apply search
        if !searchText.isEmpty {
            items = items.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.contactName.localizedCaseInsensitiveContains(searchText) ||
                ($0.subject ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Calculate priorities and sort
        return items
            .map { item in
                var mutableItem = item
                mutableItem.priority = brain.calculatePriority(for: item)
                return mutableItem
            }
            .sorted { $0.priority > $1.priority || ($0.priority == $1.priority && $0.timestamp > $1.timestamp) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if messages.isEmpty {
                    emptyState
                } else {
                    pulseTimeline
                }
            }
            .navigationTitle("Pulse")
            .searchable(text: $searchText, prompt: "Search communications...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            filterSource = nil
                        } label: {
                            Label("All Sources", systemImage: filterSource == nil ? "checkmark" : "")
                        }

                        Divider()

                        ForEach(CommunicationSource.allCases, id: \.self) { source in
                            Button {
                                filterSource = source
                            } label: {
                                Label(source.rawValue.capitalized, systemImage: filterSource == source ? "checkmark" : source.icon)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task {
                            for item in unifiedItems.prefix(20) {
                                await brain.indexItem(item)
                            }
                        }
                    } label: {
                        Label("Index All", systemImage: "brain.head.profile")
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailSheet(item: item)
            }
            .sheet(item: $showingBrief) { brief in
                BriefSheet(brief: brief)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Communications", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Your unified communication timeline will appear here. Import messages, emails, or notes to get started.")
        } actions: {
            NavigationLink("Go to Messages") {
                MessagesView()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var pulseTimeline: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Priority section header
                if unifiedItems.contains(where: { $0.priority >= .high }) {
                    PrioritySectionHeader(title: "Priority", icon: "bolt.fill", color: .orange)

                    ForEach(unifiedItems.filter { $0.priority >= .high }) { item in
                        PulseCard(item: item, isPriority: true)
                            .onTapGesture {
                                selectedItem = item
                            }
                            .onLongPressGesture {
                                generateBrief(for: item)
                            }
                    }
                }

                // Recent section
                PrioritySectionHeader(title: "Recent", icon: "clock.fill", color: .blue)

                ForEach(unifiedItems.filter { $0.priority < .high }) { item in
                    PulseCard(item: item, isPriority: false)
                        .onTapGesture {
                            selectedItem = item
                        }
                        .onLongPressGesture {
                            generateBrief(for: item)
                        }
                }
            }
            .padding()
        }
    }

    private func generateBrief(for item: UnifiedCommunicationItem) {
        Task {
            let brief = await brain.generateBrief(for: item)
            await MainActor.run {
                showingBrief = brief
            }
        }
    }
}

// MARK: - Priority Section Header

struct PrioritySectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Pulse Card

struct PulseCard: View {
    let item: UnifiedCommunicationItem
    let isPriority: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Source indicator with glow effect for priority
            ZStack {
                if isPriority {
                    Circle()
                        .fill(Color(item.source.color).opacity(0.3))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)
                }

                Image(systemName: item.source.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(Color(item.source.color))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.contactName)
                        .font(.headline)
                        .lineLimit(1)

                    if item.priority == .family {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    } else if item.priority == .urgent {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Spacer()

                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let subject = item.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Text(item.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Extracted intents badges
                if !item.extractedIntents.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(item.extractedIntents.prefix(3)) { intent in
                            IntentBadge(intent: intent)
                        }
                    }
                }

                // Related items indicator
                if !item.linkedEvents.isEmpty || !item.linkedActions.isEmpty {
                    HStack(spacing: 12) {
                        if !item.linkedEvents.isEmpty {
                            Label("\(item.linkedEvents.count)", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        if !item.linkedActions.isEmpty {
                            Label("\(item.linkedActions.count)", systemImage: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            if !item.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: isPriority ? Color(item.source.color).opacity(0.3) : .black.opacity(0.05), radius: isPriority ? 8 : 4)
        )
    }
}

// MARK: - Intent Badge

struct IntentBadge: View {
    let intent: ExtractedIntent

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconForVerb(intent.verb))
            Text(intent.verb.rawValue.capitalized)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.2))
        .foregroundColor(.purple)
        .cornerRadius(8)
    }

    private func iconForVerb(_ verb: ExtractedIntent.IntentVerb) -> String {
        switch verb {
        case .schedule: return "calendar.badge.plus"
        case .send: return "paperplane"
        case .call: return "phone"
        case .remind: return "bell"
        case .book: return "ticket"
        case .pay: return "creditcard"
        case .review: return "doc.text.magnifyingglass"
        case .confirm: return "checkmark.seal"
        case .cancel: return "xmark.circle"
        case .meet: return "person.2"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Item Detail Sheet

struct ItemDetailSheet: View {
    let item: UnifiedCommunicationItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var brain = NexusBrain.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: item.source.icon)
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color(item.source.color))
                            .clipShape(Circle())

                        Text(item.contactName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(item.source.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(item.timestamp.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Subject
                    if let subject = item.subject, !subject.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(subject)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(item.content)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Linked Events
                    if !item.linkedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Related Events", systemImage: "calendar")
                                .font(.headline)

                            ForEach(item.linkedEvents) { event in
                                EventRowView(event: event)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Linked Actions
                    if !item.linkedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Related Actions", systemImage: "checkmark.circle")
                                .font(.headline)

                            ForEach(item.linkedActions) { action in
                                ActionRowView(action: action)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Communication")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Brief Sheet

struct BriefSheet: View {
    let brief: UnifiedBrief
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundColor(.purple)
                            .frame(width: 80, height: 80)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Circle())

                        Text("AI Brief")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(brief.timestamp.formatted())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                        Text(brief.summary)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Suggested Actions
                    if !brief.suggestedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Actions")
                                .font(.headline)

                            ForEach(brief.suggestedActions) { action in
                                SuggestedActionRow(action: action)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Calendar Conflicts
                    if !brief.calendarConflicts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Calendar Conflicts", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                                .foregroundColor(.orange)

                            ForEach(brief.calendarConflicts) { event in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading) {
                                        Text(event.wrappedTitle)
                                            .font(.subheadline)
                                        Text(event.formattedDate)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Context
                    if !brief.relevantContext.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Related Context")
                                .font(.headline)

                            ForEach(brief.relevantContext) { context in
                                HStack {
                                    Image(systemName: context.source.icon)
                                        .foregroundColor(Color(context.source.color))
                                    VStack(alignment: .leading) {
                                        Text(context.type)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(context.description)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(brief.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Suggested Action Row

struct SuggestedActionRow: View {
    let action: SuggestedAction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(action.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(Int(action.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    PulseView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

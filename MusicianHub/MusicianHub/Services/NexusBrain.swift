import Foundation
import CoreData
import NaturalLanguage
#if canImport(CoreML)
import CoreML
#endif

// MARK: - Foundation Models Protocol (for future Apple Foundation Models integration)

protocol LanguageModelProvider {
    func generateEmbedding(for text: String) async throws -> [Float]
    func extractIntents(from text: String) async throws -> [ExtractedIntent]
    func generateBrief(context: BriefContext) async throws -> UnifiedBrief
    func suggestActions(for item: any CommunicationItem) async throws -> [SuggestedAction]
}

// MARK: - Communication Item Protocol

protocol CommunicationItem {
    var itemID: UUID? { get }
    var content: String { get }
    var timestamp: Date { get }
    var source: CommunicationSource { get }
    var contactName: String { get }
    var priority: ItemPriority { get }
    var embedding: [Float]? { get set }
}

enum CommunicationSource: String, CaseIterable, Codable {
    case email
    case sms
    case imessage
    case call
    case voicemail
    case note
    case calendar

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .sms: return "message.fill"
        case .imessage: return "bubble.left.and.bubble.right.fill"
        case .call: return "phone.fill"
        case .voicemail: return "recordingtape"
        case .note: return "note.text"
        case .calendar: return "calendar"
        }
    }

    var color: String {
        switch self {
        case .email: return "blue"
        case .sms: return "green"
        case .imessage: return "systemBlue"
        case .call: return "orange"
        case .voicemail: return "purple"
        case .note: return "yellow"
        case .calendar: return "red"
        }
    }
}

enum ItemPriority: Int, Comparable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
    case family = 4 // Family always highest

    static func < (lhs: ItemPriority, rhs: ItemPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        case .family: return "Family"
        }
    }
}

// MARK: - Unified Communication Item

struct UnifiedCommunicationItem: CommunicationItem, Identifiable {
    let id = UUID()
    var itemID: UUID?
    var content: String
    var timestamp: Date
    var source: CommunicationSource
    var contactName: String
    var contactEmail: String?
    var contactPhone: String?
    var subject: String?
    var priority: ItemPriority
    var embedding: [Float]?
    var isRead: Bool
    var extractedIntents: [ExtractedIntent]
    var relatedItems: [UUID]
    var threadID: String?

    // For cross-referencing
    var linkedMusician: Musician?
    var linkedEvents: [Event]
    var linkedActions: [Action]

    init(from message: Message) {
        self.itemID = message.id
        self.content = message.content ?? ""
        self.timestamp = message.receivedAt ?? Date()
        self.source = CommunicationSource(rawValue: message.source ?? "note") ?? .note
        self.contactName = message.senderName ?? "Unknown"
        self.contactEmail = message.senderContact
        self.subject = message.subject
        self.priority = .normal
        self.embedding = nil
        self.isRead = message.isProcessed
        self.extractedIntents = []
        self.relatedItems = []
        self.linkedMusician = message.musician
        self.linkedEvents = message.extractedEventsArray
        self.linkedActions = message.extractedActionsArray
    }
}

// MARK: - Extracted Intent

struct ExtractedIntent: Identifiable, Codable {
    let id: UUID
    let verb: IntentVerb
    let subject: String
    let parameters: [String: String]
    let confidence: Double
    let suggestedAction: IntentAction?

    enum IntentVerb: String, Codable {
        case schedule
        case send
        case call
        case remind
        case book
        case pay
        case review
        case confirm
        case cancel
        case meet
        case unknown
    }

    enum IntentAction: String, Codable {
        case createEvent
        case createReminder
        case findFile
        case composeEmail
        case makeCall
        case openMap
        case addTodo
    }
}

// MARK: - Unified Brief

struct UnifiedBrief: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let relatedItems: [UnifiedCommunicationItem]
    let suggestedActions: [SuggestedAction]
    let calendarConflicts: [Event]
    let relevantContext: [ContextItem]
    let timestamp: Date

    struct ContextItem: Identifiable {
        let id = UUID()
        let type: String
        let description: String
        let source: CommunicationSource
    }
}

// MARK: - Suggested Action

struct SuggestedAction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let actionType: ActionType
    let parameters: [String: Any]
    let confidence: Double

    enum ActionType {
        case createEvent
        case sendReply
        case createTask
        case makeCall
        case openFile
        case navigateTo
        case custom(String)
    }
}

// MARK: - Brief Context

struct BriefContext {
    let currentItem: UnifiedCommunicationItem
    let relatedMessages: [UnifiedCommunicationItem]
    let calendarEvents: [Event]
    let pendingActions: [Action]
    let contactHistory: [UnifiedCommunicationItem]
}

// MARK: - Nexus Brain (Local AI Engine)

@MainActor
class NexusBrain: ObservableObject {
    static let shared = NexusBrain()

    @Published var isProcessing = false
    @Published var lastProcessedDate: Date?
    @Published var embeddingsCount: Int = 0

    private let context: NSManagedObjectContext
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
    private let embeddingModel = NLEmbedding.wordEmbedding(for: .english)

    // Priority contacts (family, close collaborators)
    private var priorityContacts: Set<String> = []

    // Semantic index for fast similarity search
    private var semanticIndex: [UUID: [Float]] = [:]

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        loadPriorityContacts()
    }

    // MARK: - Semantic Indexing

    func generateEmbedding(for text: String) async -> [Float] {
        // Use NLEmbedding for local vector generation
        guard let embedding = embeddingModel else {
            return generateSimpleEmbedding(for: text)
        }

        var vector: [Float] = []
        let words = text.lowercased().split(separator: " ").map(String.init)

        for word in words.prefix(50) { // Limit to first 50 words
            if let wordVector = embedding.vector(for: word) {
                if vector.isEmpty {
                    vector = wordVector.map { Float($0) }
                } else {
                    // Average the vectors
                    for i in 0..<min(vector.count, wordVector.count) {
                        vector[i] = (vector[i] + Float(wordVector[i])) / 2
                    }
                }
            }
        }

        if vector.isEmpty {
            return generateSimpleEmbedding(for: text)
        }

        return vector
    }

    private func generateSimpleEmbedding(for text: String) -> [Float] {
        // Fallback: Generate a simple TF-based embedding
        let words = text.lowercased().split(separator: " ").map(String.init)
        var embedding = [Float](repeating: 0, count: 128)

        for (index, word) in words.enumerated() where index < 128 {
            embedding[index] = Float(word.hashValue % 1000) / 1000.0
        }

        return embedding
    }

    func indexItem(_ item: UnifiedCommunicationItem) async {
        guard let itemID = item.itemID else { return }
        let embedding = await generateEmbedding(for: item.content)
        semanticIndex[itemID] = embedding
        embeddingsCount = semanticIndex.count
    }

    func findSimilarItems(to item: UnifiedCommunicationItem, limit: Int = 5) async -> [UUID] {
        guard let itemID = item.itemID,
              let itemEmbedding = semanticIndex[itemID] else {
            return []
        }

        var similarities: [(UUID, Float)] = []

        for (id, embedding) in semanticIndex where id != itemID {
            let similarity = cosineSimilarity(itemEmbedding, embedding)
            similarities.append((id, similarity))
        }

        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }

    // MARK: - Intent Extraction

    func extractIntents(from text: String) async -> [ExtractedIntent] {
        var intents: [ExtractedIntent] = []

        let patterns: [(String, ExtractedIntent.IntentVerb, ExtractedIntent.IntentAction?)] = [
            ("send.*file|attach.*file|share.*document", .send, .findFile),
            ("let's meet|meet.*at|meeting.*at", .meet, .createEvent),
            ("schedule.*for|book.*for|set up.*meeting", .schedule, .createEvent),
            ("call.*me|give.*call|phone.*call", .call, .makeCall),
            ("remind.*me|don't forget|remember to", .remind, .createReminder),
            ("confirm.*booking|confirm.*reservation", .confirm, .addTodo),
            ("cancel.*meeting|cancel.*event", .cancel, nil),
            ("pay.*invoice|send.*payment|transfer", .pay, .addTodo),
            ("review.*contract|look over|check out", .review, .addTodo),
            ("book.*hotel|reserve.*room|book.*flight", .book, .addTodo)
        ]

        let lowercaseText = text.lowercased()

        for (pattern, verb, action) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
                if let match = regex.firstMatch(in: lowercaseText, options: [], range: range) {
                    let matchedText = String(lowercaseText[Range(match.range, in: lowercaseText)!])

                    // Extract subject using NLP
                    let subject = extractSubject(from: text, near: matchedText)

                    // Extract parameters (dates, times, locations)
                    let parameters = extractParameters(from: text)

                    let intent = ExtractedIntent(
                        id: UUID(),
                        verb: verb,
                        subject: subject,
                        parameters: parameters,
                        confidence: 0.8,
                        suggestedAction: action
                    )
                    intents.append(intent)
                }
            }
        }

        return intents
    }

    private func extractSubject(from text: String, near matchedText: String) -> String {
        tagger.string = text
        var subjects: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .personalName || tag == .organizationName || tag == .placeName {
                subjects.append(String(text[range]))
            }
            return true
        }

        return subjects.joined(separator: ", ")
    }

    private func extractParameters(from text: String) -> [String: String] {
        var params: [String: String] = [:]

        // Extract dates
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let matches = dateDetector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let firstDate = matches.first?.date {
                params["date"] = ISO8601DateFormatter().string(from: firstDate)
            }
        }

        // Extract times (simple pattern)
        if let timeMatch = text.range(of: #"\d{1,2}:\d{2}\s*(am|pm|AM|PM)?"#, options: .regularExpression) {
            params["time"] = String(text[timeMatch])
        }

        // Extract locations
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .placeName {
                params["location"] = String(text[range])
            }
            return true
        }

        return params
    }

    // MARK: - Cross-Reference Engine

    func generateBrief(for item: UnifiedCommunicationItem) async -> UnifiedBrief {
        isProcessing = true
        defer { isProcessing = false }

        // Find related items
        let relatedIDs = await findSimilarItems(to: item, limit: 5)
        let relatedItems = fetchItems(withIDs: relatedIDs)

        // Check calendar conflicts
        let calendarConflicts = findCalendarConflicts(for: item)

        // Extract intents
        let intents = await extractIntents(from: item.content)

        // Generate suggested actions
        let suggestedActions = generateSuggestedActions(from: intents, item: item)

        // Build context
        var contextItems: [UnifiedBrief.ContextItem] = []

        // Add related message context
        for related in relatedItems {
            contextItems.append(UnifiedBrief.ContextItem(
                type: "Related Message",
                description: "\(related.contactName): \(related.content.prefix(100))...",
                source: related.source
            ))
        }

        // Add calendar context
        for conflict in calendarConflicts {
            contextItems.append(UnifiedBrief.ContextItem(
                type: "Calendar Conflict",
                description: "\(conflict.wrappedTitle) on \(conflict.formattedDate)",
                source: .calendar
            ))
        }

        let summary = generateSummary(item: item, intents: intents, relatedCount: relatedItems.count)

        lastProcessedDate = Date()

        return UnifiedBrief(
            title: item.subject ?? "Communication from \(item.contactName)",
            summary: summary,
            relatedItems: relatedItems,
            suggestedActions: suggestedActions,
            calendarConflicts: calendarConflicts,
            relevantContext: contextItems,
            timestamp: Date()
        )
    }

    private func fetchItems(withIDs ids: [UUID]) -> [UnifiedCommunicationItem] {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)

        guard let messages = try? context.fetch(request) else { return [] }
        return messages.map { UnifiedCommunicationItem(from: $0) }
    }

    private func findCalendarConflicts(for item: UnifiedCommunicationItem) -> [Event] {
        // Check if item mentions a date/time
        guard let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        let matches = dateDetector.matches(in: item.content, options: [], range: NSRange(item.content.startIndex..., in: item.content))

        var conflicts: [Event] = []

        for match in matches {
            guard let date = match.date else { continue }

            // Find events within 2 hours of this date
            let startRange = date.addingTimeInterval(-7200)
            let endRange = date.addingTimeInterval(7200)

            let request: NSFetchRequest<Event> = Event.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startRange as NSDate, endRange as NSDate)

            if let events = try? context.fetch(request) {
                conflicts.append(contentsOf: events)
            }
        }

        return conflicts
    }

    private func generateSuggestedActions(from intents: [ExtractedIntent], item: UnifiedCommunicationItem) -> [SuggestedAction] {
        var actions: [SuggestedAction] = []

        for intent in intents {
            switch intent.suggestedAction {
            case .createEvent:
                actions.append(SuggestedAction(
                    title: "Create Event",
                    description: "Schedule: \(intent.subject)",
                    icon: "calendar.badge.plus",
                    actionType: .createEvent,
                    parameters: intent.parameters,
                    confidence: intent.confidence
                ))

            case .createReminder:
                actions.append(SuggestedAction(
                    title: "Create Reminder",
                    description: "Remind: \(intent.subject)",
                    icon: "bell.badge.fill",
                    actionType: .createTask,
                    parameters: intent.parameters,
                    confidence: intent.confidence
                ))

            case .findFile:
                actions.append(SuggestedAction(
                    title: "Find File",
                    description: "Search for document",
                    icon: "doc.badge.plus",
                    actionType: .openFile,
                    parameters: intent.parameters,
                    confidence: intent.confidence
                ))

            case .makeCall:
                actions.append(SuggestedAction(
                    title: "Make Call",
                    description: "Call \(item.contactName)",
                    icon: "phone.fill",
                    actionType: .makeCall,
                    parameters: ["contact": item.contactName],
                    confidence: intent.confidence
                ))

            default:
                actions.append(SuggestedAction(
                    title: "Add Task",
                    description: intent.subject,
                    icon: "checkmark.circle",
                    actionType: .createTask,
                    parameters: intent.parameters,
                    confidence: intent.confidence
                ))
            }
        }

        // Always add reply action
        actions.append(SuggestedAction(
            title: "Reply",
            description: "Send a reply to \(item.contactName)",
            icon: "arrowshape.turn.up.left.fill",
            actionType: .sendReply,
            parameters: ["contact": item.contactName],
            confidence: 1.0
        ))

        return actions.sorted { $0.confidence > $1.confidence }
    }

    private func generateSummary(item: UnifiedCommunicationItem, intents: [ExtractedIntent], relatedCount: Int) -> String {
        var parts: [String] = []

        // Main content summary
        let contentPreview = String(item.content.prefix(150))
        parts.append(contentPreview)

        // Intents summary
        if !intents.isEmpty {
            let intentVerbs = intents.map { $0.verb.rawValue }.joined(separator: ", ")
            parts.append("Detected intents: \(intentVerbs)")
        }

        // Related items
        if relatedCount > 0 {
            parts.append("Found \(relatedCount) related communications.")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Priority Classification

    func calculatePriority(for item: UnifiedCommunicationItem) -> ItemPriority {
        // Family contacts get highest priority
        if priorityContacts.contains(item.contactName.lowercased()) {
            return .family
        }

        // Check for urgent keywords
        let urgentKeywords = ["urgent", "asap", "emergency", "immediately", "critical"]
        if urgentKeywords.contains(where: { item.content.lowercased().contains($0) }) {
            return .urgent
        }

        // Check for high-priority keywords
        let highKeywords = ["important", "deadline", "due today", "time-sensitive"]
        if highKeywords.contains(where: { item.content.lowercased().contains($0) }) {
            return .high
        }

        // Check for music-related keywords (domain-specific priority)
        let musicKeywords = ["gig", "rehearsal", "studio", "recording", "show", "tour"]
        if musicKeywords.contains(where: { item.content.lowercased().contains($0) }) {
            return .high
        }

        return .normal
    }

    // MARK: - Priority Contacts Management

    private func loadPriorityContacts() {
        // Load from UserDefaults or Core Data
        if let saved = UserDefaults.standard.stringArray(forKey: "priorityContacts") {
            priorityContacts = Set(saved.map { $0.lowercased() })
        }
    }

    func addPriorityContact(_ name: String) {
        priorityContacts.insert(name.lowercased())
        savePriorityContacts()
    }

    func removePriorityContact(_ name: String) {
        priorityContacts.remove(name.lowercased())
        savePriorityContacts()
    }

    private func savePriorityContacts() {
        UserDefaults.standard.set(Array(priorityContacts), forKey: "priorityContacts")
    }
}

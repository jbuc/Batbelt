import Foundation
import CoreData

enum MessageSource: String, CaseIterable, Codable {
    case text = "text"
    case email = "email"
    case note = "note"
    case call = "call"
    case voicemail = "voicemail"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .text: return "Text Message"
        case .email: return "Email"
        case .note: return "Note"
        case .call: return "Phone Call"
        case .voicemail: return "Voicemail"
        case .manual: return "Manual Entry"
        }
    }

    var icon: String {
        switch self {
        case .text: return "message"
        case .email: return "envelope"
        case .note: return "note.text"
        case .call: return "phone"
        case .voicemail: return "recordingtape"
        case .manual: return "square.and.pencil"
        }
    }

    var color: String {
        switch self {
        case .text: return "green"
        case .email: return "blue"
        case .note: return "yellow"
        case .call: return "orange"
        case .voicemail: return "purple"
        case .manual: return "gray"
        }
    }
}

enum ProcessingStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case processing = "processing"
    case processed = "processed"
    case failed = "failed"
    case ignored = "ignored"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .processed: return "Processed"
        case .failed: return "Failed"
        case .ignored: return "Ignored"
        }
    }
}

@objc(Message)
public class Message: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var source: String?
    @NSManaged public var senderName: String?
    @NSManaged public var senderContact: String?
    @NSManaged public var subject: String?
    @NSManaged public var receivedAt: Date?
    @NSManaged public var processedAt: Date?
    @NSManaged public var isProcessed: Bool
    @NSManaged public var processingStatus: String?
    @NSManaged public var rawData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var musician: Musician?
    @NSManaged public var extractedEvents: NSSet?
    @NSManaged public var extractedActions: NSSet?
    @NSManaged public var extractedPlans: NSSet?

    public var wrappedContent: String {
        content ?? ""
    }

    public var wrappedSenderName: String {
        senderName ?? "Unknown"
    }

    public var messageSource: MessageSource {
        get { MessageSource(rawValue: source ?? "manual") ?? .manual }
        set { source = newValue.rawValue }
    }

    public var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: processingStatus ?? "pending") ?? .pending }
        set { processingStatus = newValue.rawValue }
    }

    public var extractedEventsArray: [Event] {
        let set = extractedEvents as? Set<Event> ?? []
        return set.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }

    public var extractedActionsArray: [Action] {
        let set = extractedActions as? Set<Action> ?? []
        return set.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    public var formattedReceivedDate: String {
        guard let date = receivedAt else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var relativeReceivedDate: String {
        guard let date = receivedAt else { return "Unknown date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public var preview: String {
        let maxLength = 100
        let text = wrappedContent
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }

    public var hasExtractedItems: Bool {
        !extractedEventsArray.isEmpty || !extractedActionsArray.isEmpty
    }
}

extension Message {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
        return NSFetchRequest<Message>(entityName: "Message")
    }

    static func create(in context: NSManagedObjectContext,
                       content: String,
                       source: MessageSource,
                       senderName: String? = nil,
                       senderContact: String? = nil) -> Message {
        let message = Message(context: context)
        message.id = UUID()
        message.content = content
        message.source = source.rawValue
        message.senderName = senderName
        message.senderContact = senderContact
        message.receivedAt = Date()
        message.createdAt = Date()
        message.isProcessed = false
        message.processingStatus = ProcessingStatus.pending.rawValue
        return message
    }

    static func unprocessedMessages(in context: NSManagedObjectContext) -> [Message] {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "isProcessed == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    static func recentMessages(in context: NSManagedObjectContext, limit: Int = 50) -> [Message] {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.receivedAt, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }
}

// MARK: - Generated accessors for extractedEvents
extension Message {
    @objc(addExtractedEventsObject:)
    @NSManaged public func addToExtractedEvents(_ value: Event)

    @objc(removeExtractedEventsObject:)
    @NSManaged public func removeFromExtractedEvents(_ value: Event)

    @objc(addExtractedEvents:)
    @NSManaged public func addToExtractedEvents(_ values: NSSet)

    @objc(removeExtractedEvents:)
    @NSManaged public func removeFromExtractedEvents(_ values: NSSet)
}

// MARK: - Generated accessors for extractedActions
extension Message {
    @objc(addExtractedActionsObject:)
    @NSManaged public func addToExtractedActions(_ value: Action)

    @objc(removeExtractedActionsObject:)
    @NSManaged public func removeFromExtractedActions(_ value: Action)

    @objc(addExtractedActions:)
    @NSManaged public func addToExtractedActions(_ values: NSSet)

    @objc(removeExtractedActions:)
    @NSManaged public func removeFromExtractedActions(_ values: NSSet)
}

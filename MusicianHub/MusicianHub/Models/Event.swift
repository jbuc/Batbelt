import Foundation
import CoreData

enum EventType: String, CaseIterable, Codable {
    case rehearsal = "rehearsal"
    case gig = "gig"
    case recording = "recording"
    case meeting = "meeting"
    case audition = "audition"
    case lesson = "lesson"
    case other = "other"

    var displayName: String {
        switch self {
        case .rehearsal: return "Rehearsal"
        case .gig: return "Gig"
        case .recording: return "Recording"
        case .meeting: return "Meeting"
        case .audition: return "Audition"
        case .lesson: return "Lesson"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .rehearsal: return "music.note.list"
        case .gig: return "music.mic"
        case .recording: return "waveform"
        case .meeting: return "person.2.circle"
        case .audition: return "person.badge.clock"
        case .lesson: return "book"
        case .other: return "calendar"
        }
    }

    var color: String {
        switch self {
        case .rehearsal: return "blue"
        case .gig: return "purple"
        case .recording: return "red"
        case .meeting: return "green"
        case .audition: return "orange"
        case .lesson: return "teal"
        case .other: return "gray"
        }
    }
}

@objc(Event)
public class Event: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var eventDescription: String?
    @NSManaged public var location: String?
    @NSManaged public var date: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var eventType: String?
    @NSManaged public var notes: String?
    @NSManaged public var isConfirmed: Bool
    @NSManaged public var reminderDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var musicians: NSSet?
    @NSManaged public var sourceMessage: Message?
    @NSManaged public var relatedPlan: Plan?

    public var wrappedTitle: String {
        title ?? "Untitled Event"
    }

    public var wrappedLocation: String {
        location ?? "No location"
    }

    public var wrappedDate: Date {
        date ?? Date()
    }

    public var type: EventType {
        get { EventType(rawValue: eventType ?? "other") ?? .other }
        set { eventType = newValue.rawValue }
    }

    public var musiciansArray: [Musician] {
        let set = musicians as? Set<Musician> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    public var isUpcoming: Bool {
        guard let eventDate = date else { return false }
        return eventDate > Date()
    }

    public var isPast: Bool {
        guard let eventDate = date else { return true }
        return eventDate < Date()
    }

    public var formattedDate: String {
        guard let date = date else { return "No date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public var relativeDate: String {
        guard let date = date else { return "No date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension Event {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    static func create(in context: NSManagedObjectContext,
                       title: String,
                       date: Date,
                       type: EventType = .other,
                       location: String? = nil) -> Event {
        let event = Event(context: context)
        event.id = UUID()
        event.title = title
        event.date = date
        event.eventType = type.rawValue
        event.location = location
        event.createdAt = Date()
        event.isConfirmed = false
        return event
    }

    static func upcomingEvents(in context: NSManagedObjectContext, limit: Int? = nil) -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.date, ascending: true)]
        if let limit = limit {
            request.fetchLimit = limit
        }
        return (try? context.fetch(request)) ?? []
    }
}

// MARK: - Generated accessors for musicians
extension Event {
    @objc(addMusiciansObject:)
    @NSManaged public func addToMusicians(_ value: Musician)

    @objc(removeMusiciansObject:)
    @NSManaged public func removeFromMusicians(_ value: Musician)

    @objc(addMusicians:)
    @NSManaged public func addToMusicians(_ values: NSSet)

    @objc(removeMusicians:)
    @NSManaged public func removeFromMusicians(_ values: NSSet)
}

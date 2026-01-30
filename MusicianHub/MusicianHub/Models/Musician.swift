import Foundation
import CoreData

@objc(Musician)
public class Musician: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var instrument: String?
    @NSManaged public var email: String?
    @NSManaged public var phone: String?
    @NSManaged public var notes: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var band: String?
    @NSManaged public var events: NSSet?
    @NSManaged public var actions: NSSet?
    @NSManaged public var messages: NSSet?
    @NSManaged public var plans: NSSet?

    public var wrappedName: String {
        name ?? "Unknown Musician"
    }

    public var wrappedInstrument: String {
        instrument ?? "Not specified"
    }

    public var wrappedEmail: String {
        email ?? ""
    }

    public var wrappedPhone: String {
        phone ?? ""
    }

    public var eventsArray: [Event] {
        let set = events as? Set<Event> ?? []
        return set.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }

    public var actionsArray: [Action] {
        let set = actions as? Set<Action> ?? []
        return set.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    public var messagesArray: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted { ($0.receivedAt ?? Date.distantPast) > ($1.receivedAt ?? Date.distantPast) }
    }

    public var initials: String {
        let components = wrappedName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(wrappedName.prefix(2)).uppercased()
    }
}

extension Musician {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Musician> {
        return NSFetchRequest<Musician>(entityName: "Musician")
    }

    static func create(in context: NSManagedObjectContext,
                       name: String,
                       instrument: String? = nil,
                       email: String? = nil,
                       phone: String? = nil) -> Musician {
        let musician = Musician(context: context)
        musician.id = UUID()
        musician.name = name
        musician.instrument = instrument
        musician.email = email
        musician.phone = phone
        musician.createdAt = Date()
        musician.isFavorite = false
        return musician
    }
}

// MARK: - Generated accessors for events
extension Musician {
    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: Event)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: Event)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)
}

// MARK: - Generated accessors for actions
extension Musician {
    @objc(addActionsObject:)
    @NSManaged public func addToActions(_ value: Action)

    @objc(removeActionsObject:)
    @NSManaged public func removeFromActions(_ value: Action)

    @objc(addActions:)
    @NSManaged public func addToActions(_ values: NSSet)

    @objc(removeActions:)
    @NSManaged public func removeFromActions(_ values: NSSet)
}

// MARK: - Generated accessors for messages
extension Musician {
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: Message)

    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: Message)

    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)

    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}

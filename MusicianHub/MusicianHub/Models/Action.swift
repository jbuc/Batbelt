import Foundation
import CoreData

enum ActionPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var icon: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

enum ActionCategory: String, CaseIterable, Codable {
    case followUp = "followUp"
    case booking = "booking"
    case administrative = "administrative"
    case creative = "creative"
    case financial = "financial"
    case equipment = "equipment"
    case promotion = "promotion"
    case other = "other"

    var displayName: String {
        switch self {
        case .followUp: return "Follow Up"
        case .booking: return "Booking"
        case .administrative: return "Administrative"
        case .creative: return "Creative"
        case .financial: return "Financial"
        case .equipment: return "Equipment"
        case .promotion: return "Promotion"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .followUp: return "arrow.turn.up.right"
        case .booking: return "calendar.badge.plus"
        case .administrative: return "doc.text"
        case .creative: return "paintbrush"
        case .financial: return "dollarsign.circle"
        case .equipment: return "guitars"
        case .promotion: return "megaphone"
        case .other: return "square"
        }
    }
}

@objc(Action)
public class Action: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var actionDescription: String?
    @NSManaged public var priority: String?
    @NSManaged public var category: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var dueDate: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var notes: String?
    @NSManaged public var musician: Musician?
    @NSManaged public var sourceMessage: Message?
    @NSManaged public var relatedPlan: Plan?
    @NSManaged public var relatedEvent: Event?

    public var wrappedTitle: String {
        title ?? "Untitled Action"
    }

    public var priorityLevel: ActionPriority {
        get { ActionPriority(rawValue: priority ?? "medium") ?? .medium }
        set { priority = newValue.rawValue }
    }

    public var actionCategory: ActionCategory {
        get { ActionCategory(rawValue: category ?? "other") ?? .other }
        set { category = newValue.rawValue }
    }

    public var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    public var isDueToday: Bool {
        guard let due = dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    public var isDueSoon: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return due <= twoDaysFromNow && due >= Date()
    }

    public var formattedDueDate: String {
        guard let dueDate = dueDate else { return "No due date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }

    public var relativeDueDate: String {
        guard let dueDate = dueDate else { return "No due date" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: dueDate, relativeTo: Date())
    }
}

extension Action {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Action> {
        return NSFetchRequest<Action>(entityName: "Action")
    }

    static func create(in context: NSManagedObjectContext,
                       title: String,
                       priority: ActionPriority = .medium,
                       category: ActionCategory = .other,
                       dueDate: Date? = nil) -> Action {
        let action = Action(context: context)
        action.id = UUID()
        action.title = title
        action.priority = priority.rawValue
        action.category = category.rawValue
        action.dueDate = dueDate
        action.createdAt = Date()
        action.isCompleted = false
        return action
    }

    static func pendingActions(in context: NSManagedObjectContext, limit: Int? = nil) -> [Action] {
        let request: NSFetchRequest<Action> = Action.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Action.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Action.priority, ascending: true)
        ]
        if let limit = limit {
            request.fetchLimit = limit
        }
        return (try? context.fetch(request)) ?? []
    }

    static func overdueActions(in context: NSManagedObjectContext) -> [Action] {
        let request: NSFetchRequest<Action> = Action.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO AND dueDate < %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Action.dueDate, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
}

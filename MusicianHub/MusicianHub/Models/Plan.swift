import Foundation
import CoreData

enum PlanStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case planning = "planning"
    case inProgress = "inProgress"
    case onHold = "onHold"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .planning: return "Planning"
        case .inProgress: return "In Progress"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .planning: return "pencil.and.outline"
        case .inProgress: return "play.circle"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .planning: return "blue"
        case .inProgress: return "green"
        case .onHold: return "orange"
        case .completed: return "purple"
        case .cancelled: return "red"
        }
    }
}

enum PlanType: String, CaseIterable, Codable {
    case album = "album"
    case tour = "tour"
    case single = "single"
    case musicVideo = "musicVideo"
    case liveShow = "liveShow"
    case collaboration = "collaboration"
    case promotion = "promotion"
    case project = "project"
    case other = "other"

    var displayName: String {
        switch self {
        case .album: return "Album"
        case .tour: return "Tour"
        case .single: return "Single Release"
        case .musicVideo: return "Music Video"
        case .liveShow: return "Live Show"
        case .collaboration: return "Collaboration"
        case .promotion: return "Promotion"
        case .project: return "Project"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .album: return "opticaldisc"
        case .tour: return "map"
        case .single: return "music.note"
        case .musicVideo: return "video"
        case .liveShow: return "person.3"
        case .collaboration: return "person.2.wave.2"
        case .promotion: return "megaphone"
        case .project: return "folder"
        case .other: return "square.grid.2x2"
        }
    }
}

@objc(Plan)
public class Plan: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var planDescription: String?
    @NSManaged public var status: String?
    @NSManaged public var planType: String?
    @NSManaged public var targetDate: Date?
    @NSManaged public var startDate: Date?
    @NSManaged public var completedDate: Date?
    @NSManaged public var budget: Double
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var musicians: NSSet?
    @NSManaged public var events: NSSet?
    @NSManaged public var actions: NSSet?
    @NSManaged public var sourceMessages: NSSet?

    public var wrappedTitle: String {
        title ?? "Untitled Plan"
    }

    public var wrappedDescription: String {
        planDescription ?? ""
    }

    public var currentStatus: PlanStatus {
        get { PlanStatus(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }

    public var type: PlanType {
        get { PlanType(rawValue: planType ?? "other") ?? .other }
        set { planType = newValue.rawValue }
    }

    public var musiciansArray: [Musician] {
        let set = musicians as? Set<Musician> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    public var eventsArray: [Event] {
        let set = events as? Set<Event> ?? []
        return set.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }

    public var actionsArray: [Action] {
        let set = actions as? Set<Action> ?? []
        return set.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    public var completedActionsCount: Int {
        actionsArray.filter { $0.isCompleted }.count
    }

    public var progress: Double {
        let total = actionsArray.count
        guard total > 0 else { return 0 }
        return Double(completedActionsCount) / Double(total)
    }

    public var formattedTargetDate: String {
        guard let date = targetDate else { return "No target date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    public var daysUntilTarget: Int? {
        guard let target = targetDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: target).day
    }
}

extension Plan {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Plan> {
        return NSFetchRequest<Plan>(entityName: "Plan")
    }

    static func create(in context: NSManagedObjectContext,
                       title: String,
                       type: PlanType = .project,
                       status: PlanStatus = .pending,
                       targetDate: Date? = nil) -> Plan {
        let plan = Plan(context: context)
        plan.id = UUID()
        plan.title = title
        plan.planType = type.rawValue
        plan.status = status.rawValue
        plan.targetDate = targetDate
        plan.createdAt = Date()
        plan.budget = 0
        return plan
    }

    static func activePlans(in context: NSManagedObjectContext) -> [Plan] {
        let request: NSFetchRequest<Plan> = Plan.fetchRequest()
        let activeStatuses = [PlanStatus.planning.rawValue, PlanStatus.inProgress.rawValue, PlanStatus.pending.rawValue]
        request.predicate = NSPredicate(format: "status IN %@", activeStatuses)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Plan.targetDate, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
}

// MARK: - Generated accessors for musicians
extension Plan {
    @objc(addMusiciansObject:)
    @NSManaged public func addToMusicians(_ value: Musician)

    @objc(removeMusiciansObject:)
    @NSManaged public func removeFromMusicians(_ value: Musician)

    @objc(addMusicians:)
    @NSManaged public func addToMusicians(_ values: NSSet)

    @objc(removeMusicians:)
    @NSManaged public func removeFromMusicians(_ values: NSSet)
}

// MARK: - Generated accessors for events
extension Plan {
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
extension Plan {
    @objc(addActionsObject:)
    @NSManaged public func addToActions(_ value: Action)

    @objc(removeActionsObject:)
    @NSManaged public func removeFromActions(_ value: Action)

    @objc(addActions:)
    @NSManaged public func addToActions(_ values: NSSet)

    @objc(removeActions:)
    @NSManaged public func removeFromActions(_ values: NSSet)
}

import Foundation
import CoreData
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()

    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    @Published var musicians: [Musician] = []
    @Published var upcomingEvents: [Event] = []
    @Published var pendingActions: [Action] = []
    @Published var activePlans: [Plan] = []
    @Published var recentMessages: [Message] = []

    @Published var overdueActionsCount: Int = 0
    @Published var todayEventsCount: Int = 0
    @Published var unprocessedMessagesCount: Int = 0

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        setupNotifications()
        refreshAllData()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllData()
            }
            .store(in: &cancellables)
    }

    func refreshAllData() {
        fetchMusicians()
        fetchUpcomingEvents()
        fetchPendingActions()
        fetchActivePlans()
        fetchRecentMessages()
        updateCounts()
    }

    // MARK: - Fetch Methods

    func fetchMusicians() {
        let request: NSFetchRequest<Musician> = Musician.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Musician.isFavorite, ascending: false),
            NSSortDescriptor(keyPath: \Musician.name, ascending: true)
        ]
        musicians = (try? context.fetch(request)) ?? []
    }

    func fetchUpcomingEvents(limit: Int = 10) {
        upcomingEvents = Event.upcomingEvents(in: context, limit: limit)
    }

    func fetchPendingActions(limit: Int = 20) {
        pendingActions = Action.pendingActions(in: context, limit: limit)
    }

    func fetchActivePlans() {
        activePlans = Plan.activePlans(in: context)
    }

    func fetchRecentMessages(limit: Int = 50) {
        recentMessages = Message.recentMessages(in: context, limit: limit)
    }

    private func updateCounts() {
        overdueActionsCount = Action.overdueActions(in: context).count

        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!

        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        eventRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", todayStart as NSDate, todayEnd as NSDate)
        todayEventsCount = (try? context.count(for: eventRequest)) ?? 0

        let messageRequest: NSFetchRequest<Message> = Message.fetchRequest()
        messageRequest.predicate = NSPredicate(format: "isProcessed == NO")
        unprocessedMessagesCount = (try? context.count(for: messageRequest)) ?? 0
    }

    // MARK: - CRUD Operations

    // Musicians
    func createMusician(name: String, instrument: String? = nil, email: String? = nil, phone: String? = nil) -> Musician {
        let musician = Musician.create(in: context, name: name, instrument: instrument, email: email, phone: phone)
        save()
        return musician
    }

    func deleteMusician(_ musician: Musician) {
        context.delete(musician)
        save()
    }

    func toggleFavorite(_ musician: Musician) {
        musician.isFavorite.toggle()
        musician.updatedAt = Date()
        save()
    }

    // Events
    func createEvent(title: String, date: Date, type: EventType = .other, location: String? = nil) -> Event {
        let event = Event.create(in: context, title: title, date: date, type: type, location: location)
        save()
        return event
    }

    func deleteEvent(_ event: Event) {
        context.delete(event)
        save()
    }

    func confirmEvent(_ event: Event) {
        event.isConfirmed = true
        event.updatedAt = Date()
        save()
    }

    // Actions
    func createAction(title: String, priority: ActionPriority = .medium, category: ActionCategory = .other, dueDate: Date? = nil) -> Action {
        let action = Action.create(in: context, title: title, priority: priority, category: category, dueDate: dueDate)
        save()
        return action
    }

    func deleteAction(_ action: Action) {
        context.delete(action)
        save()
    }

    func toggleActionComplete(_ action: Action) {
        action.isCompleted.toggle()
        action.completedAt = action.isCompleted ? Date() : nil
        action.updatedAt = Date()
        save()
    }

    // Plans
    func createPlan(title: String, type: PlanType = .project, status: PlanStatus = .pending, targetDate: Date? = nil) -> Plan {
        let plan = Plan.create(in: context, title: title, type: type, status: status, targetDate: targetDate)
        save()
        return plan
    }

    func deletePlan(_ plan: Plan) {
        context.delete(plan)
        save()
    }

    func updatePlanStatus(_ plan: Plan, status: PlanStatus) {
        plan.currentStatus = status
        plan.updatedAt = Date()
        if status == .completed {
            plan.completedDate = Date()
        }
        save()
    }

    // Messages
    func deleteMessage(_ message: Message) {
        // Also delete extracted items
        if let events = message.extractedEvents as? Set<Event> {
            events.forEach { context.delete($0) }
        }
        if let actions = message.extractedActions as? Set<Action> {
            actions.forEach { context.delete($0) }
        }
        context.delete(message)
        save()
    }

    func ignoreMessage(_ message: Message) {
        message.status = .ignored
        message.isProcessed = true
        save()
    }

    // MARK: - Search

    func searchMusicians(query: String) -> [Musician] {
        guard !query.isEmpty else { return musicians }

        let request: NSFetchRequest<Musician> = Musician.fetchRequest()
        request.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR instrument CONTAINS[cd] %@ OR band CONTAINS[cd] %@",
            query, query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Musician.name, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func searchEvents(query: String) -> [Event] {
        guard !query.isEmpty else { return upcomingEvents }

        let request: NSFetchRequest<Event> = Event.fetchRequest()
        request.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR location CONTAINS[cd] %@",
            query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Event.date, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func searchActions(query: String) -> [Action] {
        guard !query.isEmpty else { return pendingActions }

        let request: NSFetchRequest<Action> = Action.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Action.createdAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Statistics

    func getStatistics() -> DashboardStatistics {
        let totalMusicians = musicians.count
        let totalEvents = upcomingEvents.count
        let completedActions = pendingActions.filter { $0.isCompleted }.count
        let totalActions = pendingActions.count
        let activePlansCount = activePlans.count

        return DashboardStatistics(
            totalMusicians: totalMusicians,
            upcomingEvents: totalEvents,
            pendingActions: totalActions - completedActions,
            completedActions: completedActions,
            activePlans: activePlansCount,
            overdueActions: overdueActionsCount,
            todayEvents: todayEventsCount,
            unprocessedMessages: unprocessedMessagesCount
        )
    }

    // MARK: - Utilities

    private func save() {
        if context.hasChanges {
            do {
                try context.save()
                refreshAllData()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}

struct DashboardStatistics {
    let totalMusicians: Int
    let upcomingEvents: Int
    let pendingActions: Int
    let completedActions: Int
    let activePlans: Int
    let overdueActions: Int
    let todayEvents: Int
    let unprocessedMessages: Int

    var actionCompletionRate: Double {
        let total = pendingActions + completedActions
        guard total > 0 else { return 0 }
        return Double(completedActions) / Double(total)
    }
}

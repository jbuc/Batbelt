import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Create sample data for previews
        let sampleMusicians = [
            ("John Smith", "Drummer", "john@email.com", "+1234567890"),
            ("Sarah Johnson", "Bassist", "sarah@email.com", "+1234567891"),
            ("Mike Davis", "Guitarist", "mike@email.com", "+1234567892"),
            ("Emily Chen", "Vocalist", "emily@email.com", "+1234567893")
        ]

        for (name, instrument, email, phone) in sampleMusicians {
            let musician = Musician(context: viewContext)
            musician.id = UUID()
            musician.name = name
            musician.instrument = instrument
            musician.email = email
            musician.phone = phone
            musician.createdAt = Date()
            musician.notes = "Sample musician for preview"
        }

        // Create sample events
        let sampleEvents = [
            ("Band Rehearsal", "Studio A", Date().addingTimeInterval(86400), EventType.rehearsal),
            ("Gig at Blue Note", "Blue Note Jazz Club", Date().addingTimeInterval(86400 * 3), EventType.gig),
            ("Recording Session", "Abbey Road Studios", Date().addingTimeInterval(86400 * 7), EventType.recording),
            ("Songwriting Meeting", "Coffee Shop", Date().addingTimeInterval(86400 * 2), EventType.meeting)
        ]

        for (title, location, date, type) in sampleEvents {
            let event = Event(context: viewContext)
            event.id = UUID()
            event.title = title
            event.location = location
            event.date = date
            event.eventType = type.rawValue
            event.createdAt = Date()
            event.notes = "Sample event for preview"
        }

        // Create sample actions
        let sampleActions = [
            ("Send setlist to band", ActionPriority.high, false),
            ("Book rehearsal space", ActionPriority.medium, true),
            ("Review contract", ActionPriority.high, false),
            ("Order new strings", ActionPriority.low, false)
        ]

        for (title, priority, completed) in sampleActions {
            let action = Action(context: viewContext)
            action.id = UUID()
            action.title = title
            action.priority = priority.rawValue
            action.isCompleted = completed
            action.createdAt = Date()
            action.dueDate = Date().addingTimeInterval(86400 * Double.random(in: 1...7))
        }

        // Create sample plans
        let samplePlans = [
            ("Album Recording", "Complete 10-track album", PlanStatus.inProgress),
            ("Summer Tour", "5-city tour in July", PlanStatus.planning),
            ("Music Video Shoot", "Video for lead single", PlanStatus.pending)
        ]

        for (title, description, status) in samplePlans {
            let plan = Plan(context: viewContext)
            plan.id = UUID()
            plan.title = title
            plan.planDescription = description
            plan.status = status.rawValue
            plan.createdAt = Date()
            plan.targetDate = Date().addingTimeInterval(86400 * Double.random(in: 30...90))
        }

        // Create sample messages
        let sampleMessages = [
            ("Hey, can we reschedule rehearsal to 3pm?", MessageSource.text, "John Smith"),
            ("Contract attached for your review", MessageSource.email, "Manager"),
            ("Don't forget to bring the charts tomorrow", MessageSource.text, "Sarah Johnson"),
            ("Studio booked for next Tuesday", MessageSource.email, "Studio Manager")
        ]

        for (content, source, sender) in sampleMessages {
            let message = Message(context: viewContext)
            message.id = UUID()
            message.content = content
            message.source = source.rawValue
            message.senderName = sender
            message.receivedAt = Date().addingTimeInterval(-Double.random(in: 0...86400 * 3))
            message.isProcessed = Bool.random()
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MusicianHub")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

import Foundation
import CoreData
import Contacts
#if canImport(Messages)
import Messages
#endif

protocol CommunicationServiceDelegate: AnyObject {
    func communicationService(_ service: CommunicationService, didReceiveMessage message: Message)
    func communicationService(_ service: CommunicationService, didProcessMessage message: Message, extractedItems: [ExtractedItem])
    func communicationService(_ service: CommunicationService, didFailWithError error: Error)
}

class CommunicationService: ObservableObject {
    static let shared = CommunicationService()

    weak var delegate: CommunicationServiceDelegate?

    @Published var isProcessing = false
    @Published var lastSyncDate: Date?
    @Published var unprocessedCount = 0

    private let parsingService = MessageParsingService.shared
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Message Import

    func importMessage(content: String,
                       source: MessageSource,
                       senderName: String? = nil,
                       senderContact: String? = nil,
                       subject: String? = nil,
                       receivedAt: Date = Date()) -> Message {
        let message = Message.create(
            in: context,
            content: content,
            source: source,
            senderName: senderName,
            senderContact: senderContact
        )
        message.subject = subject
        message.receivedAt = receivedAt

        // Try to link to existing musician
        if let contact = senderContact {
            linkMessageToMusician(message, contact: contact)
        } else if let name = senderName {
            linkMessageToMusicianByName(message, name: name)
        }

        saveContext()
        updateUnprocessedCount()

        return message
    }

    func importTextMessage(content: String, from sender: String, phone: String? = nil) -> Message {
        return importMessage(
            content: content,
            source: .text,
            senderName: sender,
            senderContact: phone
        )
    }

    func importEmail(subject: String, body: String, from sender: String, email: String? = nil) -> Message {
        let message = importMessage(
            content: body,
            source: .email,
            senderName: sender,
            senderContact: email,
            subject: subject
        )
        return message
    }

    func importNote(content: String, title: String? = nil) -> Message {
        let message = importMessage(
            content: content,
            source: .note,
            subject: title
        )
        return message
    }

    func importCallLog(with contact: String, duration: TimeInterval, notes: String? = nil) -> Message {
        let durationMinutes = Int(duration / 60)
        let content = notes ?? "Phone call with \(contact) - Duration: \(durationMinutes) minutes"

        return importMessage(
            content: content,
            source: .call,
            senderName: contact
        )
    }

    // MARK: - Message Processing

    func processMessage(_ message: Message) async throws {
        guard !message.isProcessed else { return }

        await MainActor.run {
            message.status = .processing
            isProcessing = true
        }

        do {
            let extractedItems = parsingService.parseMessage(message, context: context)

            await MainActor.run {
                // Create entities for extracted items
                for item in extractedItems {
                    switch item.type {
                    case .event(let title, let date, let location, let eventType):
                        if item.confidence >= 0.5 {
                            let event = Event.create(
                                in: context,
                                title: title,
                                date: date ?? Date(),
                                type: eventType,
                                location: location
                            )
                            event.sourceMessage = message
                            message.addToExtractedEvents(event)

                            if let musician = message.musician {
                                event.addToMusicians(musician)
                            }
                        }

                    case .action(let title, let priority, let dueDate, let category):
                        if item.confidence >= 0.5 {
                            let action = Action.create(
                                in: context,
                                title: title,
                                priority: priority,
                                category: category,
                                dueDate: dueDate
                            )
                            action.sourceMessage = message
                            message.addToExtractedActions(action)

                            if let musician = message.musician {
                                action.musician = musician
                            }
                        }

                    case .plan(let title, let type, let targetDate):
                        if item.confidence >= 0.6 {
                            let plan = Plan.create(
                                in: context,
                                title: title,
                                type: type,
                                targetDate: targetDate
                            )

                            if let musician = message.musician {
                                plan.addToMusicians(musician)
                            }
                        }
                    }
                }

                message.isProcessed = true
                message.status = .processed
                message.processedAt = Date()

                saveContext()
                isProcessing = false
                updateUnprocessedCount()

                delegate?.communicationService(self, didProcessMessage: message, extractedItems: extractedItems)
            }
        } catch {
            await MainActor.run {
                message.status = .failed
                isProcessing = false
                saveContext()
            }
            throw error
        }
    }

    func processAllUnprocessedMessages() async {
        let messages = Message.unprocessedMessages(in: context)

        for message in messages {
            do {
                try await processMessage(message)
            } catch {
                print("Failed to process message: \(error)")
            }
        }

        await MainActor.run {
            lastSyncDate = Date()
        }
    }

    func reprocessMessage(_ message: Message) async throws {
        // Clear existing extracted items
        await MainActor.run {
            if let events = message.extractedEvents as? Set<Event> {
                for event in events {
                    context.delete(event)
                }
            }
            if let actions = message.extractedActions as? Set<Action> {
                for action in actions {
                    context.delete(action)
                }
            }

            message.isProcessed = false
            message.status = .pending
            message.processedAt = nil
            saveContext()
        }

        try await processMessage(message)
    }

    // MARK: - Musician Linking

    private func linkMessageToMusician(_ message: Message, contact: String) {
        let request: NSFetchRequest<Musician> = Musician.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@ OR phone == %@", contact, contact)
        request.fetchLimit = 1

        if let musician = try? context.fetch(request).first {
            message.musician = musician
        }
    }

    private func linkMessageToMusicianByName(_ message: Message, name: String) {
        let request: NSFetchRequest<Musician> = Musician.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)
        request.fetchLimit = 1

        if let musician = try? context.fetch(request).first {
            message.musician = musician
        }
    }

    // MARK: - Contacts Integration

    func requestContactsAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("Contacts access error: \(error)")
            return false
        }
    }

    func importMusiciansFromContacts(withGroup groupName: String? = nil) async throws {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        try store.enumerateContacts(with: request) { contact, _ in
            // Check if contact has music-related keywords in notes or organization
            let note = contact.note.lowercased()
            let org = contact.organizationName.lowercased()
            let musicKeywords = ["musician", "band", "music", "drummer", "guitarist", "bass", "vocal", "singer", "keyboard", "producer"]

            let isMusicRelated = musicKeywords.contains { note.contains($0) || org.contains($0) }

            if isMusicRelated || groupName != nil {
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }

                let email = contact.emailAddresses.first?.value as String?
                let phone = contact.phoneNumbers.first?.value.stringValue

                // Check if musician already exists
                let fetchRequest: NSFetchRequest<Musician> = Musician.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "name == %@ OR (email != nil AND email == %@) OR (phone != nil AND phone == %@)",
                    name,
                    email ?? "",
                    phone ?? ""
                )

                if let existing = try? self.context.fetch(fetchRequest), !existing.isEmpty {
                    return // Skip existing musicians
                }

                let musician = Musician.create(
                    in: self.context,
                    name: name,
                    email: email,
                    phone: phone
                )
                musician.notes = contact.note
                musician.band = contact.organizationName
            }
        }

        await MainActor.run {
            saveContext()
        }
    }

    // MARK: - Utilities

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }

    private func updateUnprocessedCount() {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "isProcessed == NO")
        unprocessedCount = (try? context.count(for: request)) ?? 0
    }
}

// MARK: - Mock Data Generator for Testing

extension CommunicationService {
    func generateSampleData() {
        let sampleMessages = [
            ("Hey, can we move rehearsal to Thursday at 7pm? The studio is free then.", "text", "John Smith"),
            ("Don't forget to send the setlist to everyone before the gig on Saturday", "text", "Sarah Johnson"),
            ("Subject: Contract for Blue Note Gig\n\nPlease review and sign the attached contract for our upcoming show at Blue Note on March 15th. Payment is $500 per musician.", "email", "Venue Manager"),
            ("Planning meeting for the album recording - let's discuss the track list and studio dates. Thinking we should aim for April release.", "text", "Mike Davis"),
            ("Reminder: Guitar needs new strings before the show. Also need to confirm the sound engineer.", "note", "Self"),
            ("Great call with the festival organizer. They want us for the summer festival in July. Need to follow up with rider requirements.", "call", "Festival Contact"),
            ("Can you book the rehearsal space for next Tuesday? We need at least 3 hours.", "text", "Emily Chen"),
            ("Tour planning: Looking at venues in Chicago, Detroit, and Cleveland for September. Budget is around $2000 for travel.", "email", "Tour Manager")
        ]

        for (content, sourceType, sender) in sampleMessages {
            let source = MessageSource(rawValue: sourceType) ?? .text
            _ = importMessage(
                content: content,
                source: source,
                senderName: sender,
                receivedAt: Date().addingTimeInterval(-Double.random(in: 0...86400 * 7))
            )
        }

        saveContext()
    }
}

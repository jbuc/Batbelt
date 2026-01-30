import Foundation
import NaturalLanguage
import CoreData

struct ExtractedItem {
    enum ItemType {
        case event(title: String, date: Date?, location: String?, eventType: EventType)
        case action(title: String, priority: ActionPriority, dueDate: Date?, category: ActionCategory)
        case plan(title: String, type: PlanType, targetDate: Date?)
    }

    let type: ItemType
    let confidence: Double
    let sourceText: String
}

class MessageParsingService {
    static let shared = MessageParsingService()

    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])

    // Music-related keywords for better context understanding
    private let musicKeywords = Set([
        "rehearsal", "practice", "gig", "show", "concert", "tour", "album", "single",
        "recording", "studio", "session", "soundcheck", "setlist", "song", "track",
        "band", "musician", "drummer", "guitarist", "bassist", "vocalist", "singer",
        "keyboard", "piano", "venue", "club", "festival", "audition", "jam"
    ])

    private let eventIndicators = [
        "rehearsal", "practice", "gig", "show", "concert", "recording", "session",
        "meeting", "audition", "soundcheck", "tour", "festival", "lesson"
    ]

    private let actionIndicators = [
        "need to", "have to", "should", "must", "will", "can you", "please",
        "don't forget", "remember to", "make sure", "let's", "we need",
        "follow up", "send", "book", "call", "email", "order", "buy", "get",
        "confirm", "check", "review", "prepare", "bring", "schedule"
    ]

    private let planIndicators = [
        "planning", "project", "album", "tour", "release", "launch",
        "upcoming", "future", "goal", "strategy", "campaign", "collaboration"
    ]

    private let datePatterns: [(pattern: String, parser: (String) -> Date?)] = [
        ("tomorrow", { _ in Calendar.current.date(byAdding: .day, value: 1, to: Date()) }),
        ("today", { _ in Date() }),
        ("next week", { _ in Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) }),
        ("next month", { _ in Calendar.current.date(byAdding: .month, value: 1, to: Date()) }),
        ("this weekend", { _ in
            let calendar = Calendar.current
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            let daysUntilSaturday = (7 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today)
        }),
        ("monday|tuesday|wednesday|thursday|friday|saturday|sunday", { dayName in
            let calendar = Calendar.current
            let today = Date()
            let weekdaySymbols = calendar.weekdaySymbols.map { $0.lowercased() }
            guard let targetWeekday = weekdaySymbols.firstIndex(of: dayName.lowercased()) else { return nil }
            let currentWeekday = calendar.component(.weekday, from: today)
            var daysToAdd = (targetWeekday + 1) - currentWeekday
            if daysToAdd <= 0 { daysToAdd += 7 }
            return calendar.date(byAdding: .day, value: daysToAdd, to: today)
        })
    ]

    private let timePattern = #"(\d{1,2})\s*(?::(\d{2}))?\s*(am|pm|AM|PM)?"#

    func parseMessage(_ message: Message, context: NSManagedObjectContext) -> [ExtractedItem] {
        guard let content = message.content else { return [] }

        var extractedItems: [ExtractedItem] = []

        // Extract events
        extractedItems.append(contentsOf: extractEvents(from: content))

        // Extract actions
        extractedItems.append(contentsOf: extractActions(from: content))

        // Extract plans
        extractedItems.append(contentsOf: extractPlans(from: content))

        return extractedItems.sorted { $0.confidence > $1.confidence }
    }

    func extractEvents(from text: String) -> [ExtractedItem] {
        var events: [ExtractedItem] = []
        let lowercaseText = text.lowercased()

        for indicator in eventIndicators {
            if lowercaseText.contains(indicator) {
                let eventType = determineEventType(from: indicator)
                let date = extractDate(from: text)
                let location = extractLocation(from: text)
                let title = extractEventTitle(from: text, indicator: indicator)

                let confidence = calculateEventConfidence(text: text, hasDate: date != nil, hasLocation: location != nil)

                events.append(ExtractedItem(
                    type: .event(title: title, date: date, location: location, eventType: eventType),
                    confidence: confidence,
                    sourceText: text
                ))
            }
        }

        return events
    }

    func extractActions(from text: String) -> [ExtractedItem] {
        var actions: [ExtractedItem] = []
        let lowercaseText = text.lowercased()

        for indicator in actionIndicators {
            if lowercaseText.contains(indicator) {
                let (title, category) = extractActionDetails(from: text, indicator: indicator)
                let priority = determinePriority(from: text)
                let dueDate = extractDate(from: text)

                let confidence = calculateActionConfidence(text: text, indicator: indicator)

                actions.append(ExtractedItem(
                    type: .action(title: title, priority: priority, dueDate: dueDate, category: category),
                    confidence: confidence,
                    sourceText: text
                ))
                break // Only extract one action per indicator match to avoid duplicates
            }
        }

        return actions
    }

    func extractPlans(from text: String) -> [ExtractedItem] {
        var plans: [ExtractedItem] = []
        let lowercaseText = text.lowercased()

        for indicator in planIndicators {
            if lowercaseText.contains(indicator) {
                let planType = determinePlanType(from: text)
                let title = extractPlanTitle(from: text, indicator: indicator)
                let targetDate = extractFutureDate(from: text)

                let confidence = calculatePlanConfidence(text: text)

                plans.append(ExtractedItem(
                    type: .plan(title: title, type: planType, targetDate: targetDate),
                    confidence: confidence,
                    sourceText: text
                ))
                break
            }
        }

        return plans
    }

    // MARK: - Helper Methods

    private func determineEventType(from indicator: String) -> EventType {
        switch indicator {
        case "rehearsal", "practice":
            return .rehearsal
        case "gig", "show", "concert", "festival":
            return .gig
        case "recording", "session", "studio":
            return .recording
        case "meeting":
            return .meeting
        case "audition":
            return .audition
        case "lesson":
            return .lesson
        default:
            return .other
        }
    }

    private func determinePriority(from text: String) -> ActionPriority {
        let lowercaseText = text.lowercased()

        if lowercaseText.contains("urgent") || lowercaseText.contains("asap") || lowercaseText.contains("immediately") {
            return .urgent
        } else if lowercaseText.contains("important") || lowercaseText.contains("critical") {
            return .high
        } else if lowercaseText.contains("when you can") || lowercaseText.contains("no rush") {
            return .low
        }
        return .medium
    }

    private func determinePlanType(from text: String) -> PlanType {
        let lowercaseText = text.lowercased()

        if lowercaseText.contains("album") {
            return .album
        } else if lowercaseText.contains("tour") {
            return .tour
        } else if lowercaseText.contains("single") || lowercaseText.contains("release") {
            return .single
        } else if lowercaseText.contains("video") {
            return .musicVideo
        } else if lowercaseText.contains("collaboration") || lowercaseText.contains("collab") {
            return .collaboration
        } else if lowercaseText.contains("promotion") || lowercaseText.contains("marketing") {
            return .promotion
        }
        return .project
    }

    private func extractDate(from text: String) -> Date? {
        let lowercaseText = text.lowercased()

        // Check relative date patterns first
        for (pattern, parser) in datePatterns {
            if let range = lowercaseText.range(of: pattern, options: .regularExpression) {
                let matchedText = String(lowercaseText[range])
                if let date = parser(matchedText) {
                    // Try to extract time if available
                    if let time = extractTime(from: text) {
                        return combineDateAndTime(date: date, time: time)
                    }
                    return date
                }
            }
        }

        // Try to extract specific dates using data detector
        let types: NSTextCheckingResult.CheckingType = [.date]
        guard let detector = try? NSDataDetector(types: types.rawValue) else { return nil }

        let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        return matches.first?.date
    }

    private func extractTime(from text: String) -> (hour: Int, minute: Int)? {
        guard let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }

        guard let hourRange = Range(match.range(at: 1), in: text),
              var hour = Int(text[hourRange]) else { return nil }

        var minute = 0
        if let minuteRange = Range(match.range(at: 2), in: text),
           let mins = Int(text[minuteRange]) {
            minute = mins
        }

        if let ampmRange = Range(match.range(at: 3), in: text) {
            let ampm = text[ampmRange].lowercased()
            if ampm == "pm" && hour != 12 {
                hour += 12
            } else if ampm == "am" && hour == 12 {
                hour = 0
            }
        }

        return (hour, minute)
    }

    private func combineDateAndTime(date: Date, time: (hour: Int, minute: Int)) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return Calendar.current.date(from: components) ?? date
    }

    private func extractFutureDate(from text: String) -> Date? {
        // For plans, look for dates further in the future
        if let date = extractDate(from: text) {
            return date
        }

        // Default to 30 days from now if no date found
        return nil
    }

    private func extractLocation(from text: String) -> String? {
        tagger.string = text
        var locations: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .placeName || tag == .organizationName {
                locations.append(String(text[range]))
            }
            return true
        }

        // Also look for common venue patterns
        let venuePatterns = ["at ", "@ ", "location: ", "venue: ", "place: "]
        for pattern in venuePatterns {
            if let range = text.lowercased().range(of: pattern) {
                let afterPattern = text[range.upperBound...]
                // Extract until end of line or common delimiters
                if let endIndex = afterPattern.firstIndex(where: { $0 == "\n" || $0 == "," || $0 == "." }) {
                    let location = String(afterPattern[..<endIndex]).trimmingCharacters(in: .whitespaces)
                    if !location.isEmpty {
                        return location
                    }
                } else {
                    let location = String(afterPattern).trimmingCharacters(in: .whitespaces)
                    if !location.isEmpty && location.count < 100 {
                        return location
                    }
                }
            }
        }

        return locations.first
    }

    private func extractEventTitle(from text: String, indicator: String) -> String {
        // Try to create a meaningful title from the text
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        for sentence in sentences {
            if sentence.lowercased().contains(indicator) {
                let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count <= 100 {
                    return cleaned.isEmpty ? "\(indicator.capitalized)" : cleaned
                }
                return String(cleaned.prefix(100))
            }
        }
        return indicator.capitalized
    }

    private func extractActionDetails(from text: String, indicator: String) -> (title: String, category: ActionCategory) {
        var category: ActionCategory = .other

        let lowercaseText = text.lowercased()

        if lowercaseText.contains("follow up") || lowercaseText.contains("get back") {
            category = .followUp
        } else if lowercaseText.contains("book") || lowercaseText.contains("schedule") || lowercaseText.contains("reserve") {
            category = .booking
        } else if lowercaseText.contains("contract") || lowercaseText.contains("sign") || lowercaseText.contains("paperwork") {
            category = .administrative
        } else if lowercaseText.contains("write") || lowercaseText.contains("compose") || lowercaseText.contains("arrange") {
            category = .creative
        } else if lowercaseText.contains("pay") || lowercaseText.contains("invoice") || lowercaseText.contains("budget") {
            category = .financial
        } else if lowercaseText.contains("gear") || lowercaseText.contains("equipment") || lowercaseText.contains("strings") {
            category = .equipment
        } else if lowercaseText.contains("promote") || lowercaseText.contains("post") || lowercaseText.contains("share") {
            category = .promotion
        }

        // Extract title - look for the action phrase
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        for sentence in sentences {
            if sentence.lowercased().contains(indicator) {
                let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count <= 100 {
                    return (cleaned.isEmpty ? "Follow up" : cleaned, category)
                }
                return (String(cleaned.prefix(100)), category)
            }
        }

        return ("Action item", category)
    }

    private func extractPlanTitle(from text: String, indicator: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        for sentence in sentences {
            if sentence.lowercased().contains(indicator) {
                let cleaned = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.count <= 100 {
                    return cleaned.isEmpty ? "\(indicator.capitalized) Plan" : cleaned
                }
                return String(cleaned.prefix(100))
            }
        }
        return "\(indicator.capitalized) Plan"
    }

    private func calculateEventConfidence(text: String, hasDate: Bool, hasLocation: Bool) -> Double {
        var confidence = 0.5

        if hasDate { confidence += 0.25 }
        if hasLocation { confidence += 0.15 }

        // Check for music-related keywords
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let musicWordCount = words.filter { musicKeywords.contains($0) }.count
        confidence += min(Double(musicWordCount) * 0.05, 0.1)

        return min(confidence, 1.0)
    }

    private func calculateActionConfidence(text: String, indicator: String) -> Double {
        var confidence = 0.6

        // Higher confidence for explicit action phrases
        let strongIndicators = ["need to", "have to", "must", "don't forget", "make sure"]
        if strongIndicators.contains(where: { text.lowercased().contains($0) }) {
            confidence += 0.2
        }

        // Check for music context
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let musicWordCount = words.filter { musicKeywords.contains($0) }.count
        confidence += min(Double(musicWordCount) * 0.05, 0.1)

        return min(confidence, 1.0)
    }

    private func calculatePlanConfidence(text: String) -> Double {
        var confidence = 0.4

        // Plans are generally less certain without explicit confirmation
        let planWords = ["planning", "project", "goal", "strategy"]
        if planWords.contains(where: { text.lowercased().contains($0) }) {
            confidence += 0.2
        }

        // Check for future-oriented language
        let futureWords = ["upcoming", "future", "next year", "next month", "going to"]
        if futureWords.contains(where: { text.lowercased().contains($0) }) {
            confidence += 0.15
        }

        return min(confidence, 1.0)
    }
}

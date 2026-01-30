import SwiftUI
import CoreData

struct EventsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddEvent = false
    @State private var selectedEvent: Event?
    @State private var viewMode: ViewMode = .list
    @State private var filterType: EventType?
    @State private var showPastEvents = false

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.date, ascending: true)],
        animation: .default
    )
    private var allEvents: FetchedResults<Event>

    var filteredEvents: [Event] {
        var events = Array(allEvents)

        // Filter by past/future
        if !showPastEvents {
            events = events.filter { $0.isUpcoming || Calendar.current.isDateInToday($0.wrappedDate) }
        }

        // Filter by type
        if let filterType = filterType {
            events = events.filter { $0.type == filterType }
        }

        // Filter by search
        if !searchText.isEmpty {
            events = events.filter {
                $0.wrappedTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedLocation.localizedCaseInsensitiveContains(searchText)
            }
        }

        return events
    }

    var groupedEvents: [(String, [Event])] {
        let grouped = Dictionary(grouping: filteredEvents) { event -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: event.wrappedDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Events")
            .searchable(text: $searchText, prompt: "Search events...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddEvent = true }) {
                        Label("Add Event", systemImage: "calendar.badge.plus")
                    }
                }

                ToolbarItemGroup(placement: .secondaryAction) {
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode == .list ? "list.bullet" : "calendar")
                                .tag(mode)
                        }
                    }

                    Menu {
                        Button {
                            filterType = nil
                        } label: {
                            if filterType == nil {
                                Label("All Types", systemImage: "checkmark")
                            } else {
                                Text("All Types")
                            }
                        }

                        Divider()

                        ForEach(EventType.allCases, id: \.self) { type in
                            Button {
                                filterType = type
                            } label: {
                                if filterType == type {
                                    Label(type.displayName, systemImage: "checkmark")
                                } else {
                                    Text(type.displayName)
                                }
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Toggle("Show Past Events", isOn: $showPastEvents)
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Events", systemImage: "calendar")
        } description: {
            Text("Events will appear here when extracted from your messages or added manually.")
        } actions: {
            Button("Add Event") {
                showingAddEvent = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var eventsList: some View {
        List {
            ForEach(groupedEvents, id: \.0) { date, events in
                Section(header: Text(date)) {
                    ForEach(events) { event in
                        EventCard(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    confirmEvent(event)
                                } label: {
                                    Label(
                                        event.isConfirmed ? "Unconfirm" : "Confirm",
                                        systemImage: event.isConfirmed ? "xmark.seal" : "checkmark.seal"
                                    )
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteEvent(event)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func confirmEvent(_ event: Event) {
        withAnimation {
            event.isConfirmed.toggle()
            try? viewContext.save()
        }
    }

    private func deleteEvent(_ event: Event) {
        withAnimation {
            viewContext.delete(event)
            try? viewContext.save()
        }
    }
}

struct EventCard: View {
    @ObservedObject var event: Event

    var body: some View {
        HStack(spacing: 16) {
            // Type indicator
            VStack {
                Image(systemName: event.type.icon)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .background(Color(event.type.color))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.wrappedTitle)
                        .font(.headline)

                    if event.isConfirmed {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    Label {
                        Text(formatTime(event.wrappedDate))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if !event.wrappedLocation.isEmpty && event.wrappedLocation != "No location" {
                        Label {
                            Text(event.wrappedLocation)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "mappin")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                if !event.musiciansArray.isEmpty {
                    Text("\(event.musiciansArray.count) musician(s)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(event.relativeDate)
                .font(.caption)
                .foregroundColor(event.isPast ? .secondary : .blue)
        }
        .padding(.vertical, 8)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var eventType: EventType = .rehearsal
    @State private var date = Date()
    @State private var endDate = Date().addingTimeInterval(7200)
    @State private var location = ""
    @State private var notes = ""
    @State private var hasEndDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $eventType) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    TextField("Location", text: $location)
                }

                Section("Date & Time") {
                    DatePicker("Start", selection: $date)

                    Toggle("End Time", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End", selection: $endDate)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveEvent() {
        let event = Event(context: viewContext)
        event.id = UUID()
        event.title = title.trimmingCharacters(in: .whitespaces)
        event.eventType = eventType.rawValue
        event.date = date
        event.endDate = hasEndDate ? endDate : nil
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        event.createdAt = Date()
        event.isConfirmed = false

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save event: \(error)")
        }
    }
}

struct EventDetailView: View {
    @ObservedObject var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(event.type.color).opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: event.type.icon)
                                .font(.largeTitle)
                                .foregroundColor(Color(event.type.color))
                        }

                        VStack(spacing: 8) {
                            HStack {
                                Text(event.wrappedTitle)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if event.isConfirmed {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.green)
                                }
                            }

                            Text(event.type.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                    // Date & Time
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(icon: "calendar", title: "Date", value: formatDate(event.wrappedDate))
                        DetailRow(icon: "clock", title: "Time", value: formatTime(event.wrappedDate))

                        if let endDate = event.endDate {
                            DetailRow(icon: "clock.badge.checkmark", title: "End Time", value: formatTime(endDate))
                        }

                        if !event.wrappedLocation.isEmpty && event.wrappedLocation != "No location" {
                            DetailRow(icon: "mappin.circle", title: "Location", value: event.wrappedLocation)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Musicians
                    if !event.musiciansArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Musicians")
                                .font(.headline)

                            ForEach(event.musiciansArray) { musician in
                                HStack {
                                    Text(musician.initials)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.purple)
                                        .frame(width: 32, height: 32)
                                        .background(Color.purple.opacity(0.2))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading) {
                                        Text(musician.wrappedName)
                                            .font(.subheadline)
                                        Text(musician.wrappedInstrument)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)

                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            event.isConfirmed.toggle()
                            try? viewContext.save()
                        } label: {
                            Label(
                                event.isConfirmed ? "Mark as Unconfirmed" : "Confirm Event",
                                systemImage: event.isConfirmed ? "xmark.seal" : "checkmark.seal"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(event.isConfirmed ? .gray : .green)
                    }
                    .padding()
                }
            }
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }

            Spacer()
        }
    }
}

#Preview {
    EventsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

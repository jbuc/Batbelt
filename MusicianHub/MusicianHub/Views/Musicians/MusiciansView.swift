import SwiftUI
import CoreData

struct MusiciansView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddMusician = false
    @State private var selectedMusician: Musician?
    @State private var sortOption: SortOption = .name

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case instrument = "Instrument"
        case recent = "Recently Added"
        case favorites = "Favorites"
    }

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Musician.name, ascending: true)],
        animation: .default
    )
    private var musicians: FetchedResults<Musician>

    var filteredMusicians: [Musician] {
        let filtered: [Musician]
        if searchText.isEmpty {
            filtered = Array(musicians)
        } else {
            filtered = musicians.filter {
                $0.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedInstrument.localizedCaseInsensitiveContains(searchText) ||
                ($0.band ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return sortMusicians(filtered)
    }

    var body: some View {
        NavigationStack {
            Group {
                if musicians.isEmpty {
                    emptyState
                } else {
                    musiciansList
                }
            }
            .navigationTitle("Musicians")
            .searchable(text: $searchText, prompt: "Search musicians...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddMusician = true }) {
                        Label("Add Musician", systemImage: "person.badge.plus")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingAddMusician) {
                AddMusicianView()
            }
            .sheet(item: $selectedMusician) { musician in
                MusicianDetailView(musician: musician)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Musicians", systemImage: "person.2")
        } description: {
            Text("Add musicians to keep track of your collaborators and their contact information.")
        } actions: {
            Button("Add Musician") {
                showingAddMusician = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var musiciansList: some View {
        List {
            ForEach(filteredMusicians) { musician in
                MusicianRow(musician: musician)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedMusician = musician
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleFavorite(musician)
                        } label: {
                            Label(
                                musician.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: musician.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteMusician(musician)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sortMusicians(_ musicians: [Musician]) -> [Musician] {
        switch sortOption {
        case .name:
            return musicians.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .instrument:
            return musicians.sorted { ($0.instrument ?? "") < ($1.instrument ?? "") }
        case .recent:
            return musicians.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .favorites:
            return musicians.sorted { $0.isFavorite && !$1.isFavorite }
        }
    }

    private func toggleFavorite(_ musician: Musician) {
        withAnimation {
            musician.isFavorite.toggle()
            try? viewContext.save()
        }
    }

    private func deleteMusician(_ musician: Musician) {
        withAnimation {
            viewContext.delete(musician)
            try? viewContext.save()
        }
    }
}

struct MusicianRow: View {
    @ObservedObject var musician: Musician

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 50, height: 50)

                Text(musician.initials)
                    .font(.headline)
                    .foregroundColor(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(musician.wrappedName)
                        .font(.headline)

                    if musician.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }

                Text(musician.wrappedInstrument)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let band = musician.band, !band.isEmpty {
                    Text(band)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !musician.eventsArray.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(musician.eventsArray.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                if !musician.actionsArray.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                        Text("\(musician.actionsArray.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddMusicianView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var name = ""
    @State private var instrument = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var band = ""
    @State private var notes = ""

    let instruments = ["Vocals", "Guitar", "Bass", "Drums", "Keyboard", "Piano", "Saxophone", "Trumpet", "Violin", "Cello", "DJ", "Producer", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)

                    Picker("Instrument", selection: $instrument) {
                        Text("Select...").tag("")
                        ForEach(instruments, id: \.self) { instrument in
                            Text(instrument).tag(instrument)
                        }
                    }

                    TextField("Band/Group", text: $band)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Musician")
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
                        saveMusician()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveMusician() {
        let musician = Musician(context: viewContext)
        musician.id = UUID()
        musician.name = name.trimmingCharacters(in: .whitespaces)
        musician.instrument = instrument.isEmpty ? nil : instrument
        musician.email = email.isEmpty ? nil : email
        musician.phone = phone.isEmpty ? nil : phone
        musician.band = band.isEmpty ? nil : band
        musician.notes = notes.isEmpty ? nil : notes
        musician.createdAt = Date()
        musician.isFavorite = false

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save musician: \(error)")
        }
    }
}

struct MusicianDetailView: View {
    @ObservedObject var musician: Musician
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 100, height: 100)

                            Text(musician.initials)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }

                        Text(musician.wrappedName)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(musician.wrappedInstrument)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if let band = musician.band, !band.isEmpty {
                            Text(band)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()

                    // Contact Info
                    if !musician.wrappedEmail.isEmpty || !musician.wrappedPhone.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact")
                                .font(.headline)

                            if !musician.wrappedEmail.isEmpty {
                                ContactRow(icon: "envelope", label: "Email", value: musician.wrappedEmail)
                            }

                            if !musician.wrappedPhone.isEmpty {
                                ContactRow(icon: "phone", label: "Phone", value: musician.wrappedPhone)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Recent Events
                    if !musician.eventsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Events")
                                .font(.headline)

                            ForEach(musician.eventsArray.prefix(5)) { event in
                                EventRowView(event: event)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Pending Actions
                    if !musician.actionsArray.filter({ !$0.isCompleted }).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pending Actions")
                                .font(.headline)

                            ForEach(musician.actionsArray.filter { !$0.isCompleted }.prefix(5)) { action in
                                ActionRowView(action: action)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Notes
                    if let notes = musician.notes, !notes.isEmpty {
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
                }
                .padding(.vertical)
            }
            .navigationTitle("Musician")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        musician.isFavorite.toggle()
                        try? viewContext.save()
                    } label: {
                        Image(systemName: musician.isFavorite ? "star.fill" : "star")
                            .foregroundColor(musician.isFavorite ? .yellow : .gray)
                    }
                }
            }
        }
    }
}

struct ContactRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(label)
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
    MusiciansView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

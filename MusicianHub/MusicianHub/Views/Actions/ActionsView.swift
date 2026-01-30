import SwiftUI
import CoreData

struct ActionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddAction = false
    @State private var selectedAction: Action?
    @State private var filterPriority: ActionPriority?
    @State private var filterCategory: ActionCategory?
    @State private var showCompleted = false

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Action.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \Action.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \Action.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var allActions: FetchedResults<Action>

    var filteredActions: [Action] {
        var actions = Array(allActions)

        // Filter completed
        if !showCompleted {
            actions = actions.filter { !$0.isCompleted }
        }

        // Filter by priority
        if let priority = filterPriority {
            actions = actions.filter { $0.priorityLevel == priority }
        }

        // Filter by category
        if let category = filterCategory {
            actions = actions.filter { $0.actionCategory == category }
        }

        // Search filter
        if !searchText.isEmpty {
            actions = actions.filter {
                $0.wrappedTitle.localizedCaseInsensitiveContains(searchText)
            }
        }

        return actions
    }

    var overdueActions: [Action] {
        filteredActions.filter { $0.isOverdue }
    }

    var dueSoonActions: [Action] {
        filteredActions.filter { $0.isDueSoon && !$0.isOverdue }
    }

    var otherActions: [Action] {
        filteredActions.filter { !$0.isOverdue && !$0.isDueSoon }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allActions.isEmpty {
                    emptyState
                } else {
                    actionsList
                }
            }
            .navigationTitle("Actions")
            .searchable(text: $searchText, prompt: "Search actions...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddAction = true }) {
                        Label("Add Action", systemImage: "plus.circle")
                    }
                }

                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu {
                        Button {
                            filterPriority = nil
                        } label: {
                            if filterPriority == nil {
                                Label("All Priorities", systemImage: "checkmark")
                            } else {
                                Text("All Priorities")
                            }
                        }

                        Divider()

                        ForEach(ActionPriority.allCases, id: \.self) { priority in
                            Button {
                                filterPriority = priority
                            } label: {
                                Label(priority.displayName, systemImage: filterPriority == priority ? "checkmark" : priority.icon)
                            }
                        }
                    } label: {
                        Label("Priority", systemImage: "flag")
                    }

                    Menu {
                        Button {
                            filterCategory = nil
                        } label: {
                            if filterCategory == nil {
                                Label("All Categories", systemImage: "checkmark")
                            } else {
                                Text("All Categories")
                            }
                        }

                        Divider()

                        ForEach(ActionCategory.allCases, id: \.self) { category in
                            Button {
                                filterCategory = category
                            } label: {
                                Label(category.displayName, systemImage: filterCategory == category ? "checkmark" : category.icon)
                            }
                        }
                    } label: {
                        Label("Category", systemImage: "folder")
                    }

                    Toggle("Show Completed", isOn: $showCompleted)
                }
            }
            .sheet(isPresented: $showingAddAction) {
                AddActionView()
            }
            .sheet(item: $selectedAction) { action in
                ActionDetailView(action: action)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Actions", systemImage: "checkmark.circle")
        } description: {
            Text("Actions and to-dos will appear here when extracted from your messages or added manually.")
        } actions: {
            Button("Add Action") {
                showingAddAction = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var actionsList: some View {
        List {
            if !overdueActions.isEmpty {
                Section {
                    ForEach(overdueActions) { action in
                        ActionItemRow(action: action)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAction = action
                            }
                    }
                    .onDelete { indexSet in
                        deleteActions(from: overdueActions, at: indexSet)
                    }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }

            if !dueSoonActions.isEmpty {
                Section {
                    ForEach(dueSoonActions) { action in
                        ActionItemRow(action: action)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAction = action
                            }
                    }
                    .onDelete { indexSet in
                        deleteActions(from: dueSoonActions, at: indexSet)
                    }
                } header: {
                    Label("Due Soon", systemImage: "clock.fill")
                        .foregroundColor(.orange)
                }
            }

            if !otherActions.isEmpty {
                Section {
                    ForEach(otherActions) { action in
                        ActionItemRow(action: action)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAction = action
                            }
                    }
                    .onDelete { indexSet in
                        deleteActions(from: otherActions, at: indexSet)
                    }
                } header: {
                    Text(showCompleted ? "All Actions" : "Other")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteActions(from list: [Action], at offsets: IndexSet) {
        withAnimation {
            offsets.map { list[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct ActionItemRow: View {
    @ObservedObject var action: Action
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HStack(spacing: 12) {
            // Completion toggle
            Button {
                withAnimation {
                    action.isCompleted.toggle()
                    action.completedAt = action.isCompleted ? Date() : nil
                    try? viewContext.save()
                }
            } label: {
                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(action.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(action.wrappedTitle)
                    .font(.body)
                    .strikethrough(action.isCompleted)
                    .foregroundColor(action.isCompleted ? .secondary : .primary)

                HStack(spacing: 12) {
                    // Priority badge
                    HStack(spacing: 4) {
                        Image(systemName: action.priorityLevel.icon)
                        Text(action.priorityLevel.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(Color(action.priorityLevel.color))

                    // Category badge
                    HStack(spacing: 4) {
                        Image(systemName: action.actionCategory.icon)
                        Text(action.actionCategory.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // Due date
                    if let dueDate = action.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(action.relativeDueDate)
                        }
                        .font(.caption)
                        .foregroundColor(action.isOverdue ? .red : .secondary)
                    }
                }

                // Musician
                if let musician = action.musician {
                    HStack(spacing: 4) {
                        Image(systemName: "person")
                        Text(musician.wrappedName)
                    }
                    .font(.caption2)
                    .foregroundColor(.purple)
                }
            }

            Spacer()

            if action.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddActionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var priority: ActionPriority = .medium
    @State private var category: ActionCategory = .other
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Musician.name, ascending: true)]
    )
    private var musicians: FetchedResults<Musician>

    @State private var selectedMusician: Musician?

    var body: some View {
        NavigationStack {
            Form {
                Section("Action Details") {
                    TextField("Title", text: $title)

                    Picker("Priority", selection: $priority) {
                        ForEach(ActionPriority.allCases, id: \.self) { p in
                            Label(p.displayName, systemImage: p.icon)
                                .tag(p)
                        }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(ActionCategory.allCases, id: \.self) { c in
                            Label(c.displayName, systemImage: c.icon)
                                .tag(c)
                        }
                    }
                }

                Section("Due Date") {
                    Toggle("Has Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date])
                    }
                }

                if !musicians.isEmpty {
                    Section("Related Musician") {
                        Picker("Musician", selection: $selectedMusician) {
                            Text("None").tag(nil as Musician?)
                            ForEach(musicians) { musician in
                                Text(musician.wrappedName).tag(musician as Musician?)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Action")
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
                        saveAction()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveAction() {
        let action = Action(context: viewContext)
        action.id = UUID()
        action.title = title.trimmingCharacters(in: .whitespaces)
        action.priority = priority.rawValue
        action.category = category.rawValue
        action.dueDate = hasDueDate ? dueDate : nil
        action.notes = notes.isEmpty ? nil : notes
        action.musician = selectedMusician
        action.createdAt = Date()
        action.isCompleted = false

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save action: \(error)")
        }
    }
}

struct ActionDetailView: View {
    @ObservedObject var action: Action
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
                                .fill(Color(action.priorityLevel.color).opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: action.isCompleted ? "checkmark.circle.fill" : action.priorityLevel.icon)
                                .font(.largeTitle)
                                .foregroundColor(action.isCompleted ? .green : Color(action.priorityLevel.color))
                        }

                        Text(action.wrappedTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .strikethrough(action.isCompleted)

                        HStack(spacing: 12) {
                            Label(action.priorityLevel.displayName, systemImage: action.priorityLevel.icon)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(action.priorityLevel.color).opacity(0.2))
                                .cornerRadius(8)

                            Label(action.actionCategory.displayName, systemImage: action.actionCategory.icon)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding()

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let dueDate = action.dueDate {
                            DetailRow(icon: "calendar", title: "Due Date", value: action.formattedDueDate)

                            if action.isOverdue {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("This action is overdue!")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        if let musician = action.musician {
                            DetailRow(icon: "person", title: "Musician", value: musician.wrappedName)
                        }

                        if action.isCompleted, let completedAt = action.completedAt {
                            let formatter = DateFormatter()
                            let _ = formatter.dateStyle = .medium
                            DetailRow(icon: "checkmark.circle", title: "Completed", value: formatter.string(from: completedAt))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Notes
                    if let notes = action.notes, !notes.isEmpty {
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

                    // Toggle completion
                    Button {
                        action.isCompleted.toggle()
                        action.completedAt = action.isCompleted ? Date() : nil
                        try? viewContext.save()
                    } label: {
                        Label(
                            action.isCompleted ? "Mark as Incomplete" : "Mark as Complete",
                            systemImage: action.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(action.isCompleted ? .gray : .green)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Action Details")
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
}

#Preview {
    ActionsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

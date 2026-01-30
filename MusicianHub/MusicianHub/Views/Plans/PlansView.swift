import SwiftUI
import CoreData

struct PlansView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var showingAddPlan = false
    @State private var selectedPlan: Plan?
    @State private var filterStatus: PlanStatus?
    @State private var filterType: PlanType?

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Plan.targetDate, ascending: true),
            NSSortDescriptor(keyPath: \Plan.createdAt, ascending: false)
        ],
        animation: .default
    )
    private var allPlans: FetchedResults<Plan>

    var filteredPlans: [Plan] {
        var plans = Array(allPlans)

        // Filter by status
        if let status = filterStatus {
            plans = plans.filter { $0.currentStatus == status }
        }

        // Filter by type
        if let type = filterType {
            plans = plans.filter { $0.type == type }
        }

        // Search filter
        if !searchText.isEmpty {
            plans = plans.filter {
                $0.wrappedTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        return plans
    }

    var activePlans: [Plan] {
        filteredPlans.filter { [.planning, .inProgress, .pending].contains($0.currentStatus) }
    }

    var onHoldPlans: [Plan] {
        filteredPlans.filter { $0.currentStatus == .onHold }
    }

    var completedPlans: [Plan] {
        filteredPlans.filter { $0.currentStatus == .completed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allPlans.isEmpty {
                    emptyState
                } else {
                    plansList
                }
            }
            .navigationTitle("Plans")
            .searchable(text: $searchText, prompt: "Search plans...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPlan = true }) {
                        Label("Add Plan", systemImage: "plus.rectangle.on.folder")
                    }
                }

                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu {
                        Button {
                            filterStatus = nil
                        } label: {
                            if filterStatus == nil {
                                Label("All Statuses", systemImage: "checkmark")
                            } else {
                                Text("All Statuses")
                            }
                        }

                        Divider()

                        ForEach(PlanStatus.allCases, id: \.self) { status in
                            Button {
                                filterStatus = status
                            } label: {
                                Label(status.displayName, systemImage: filterStatus == status ? "checkmark" : status.icon)
                            }
                        }
                    } label: {
                        Label("Status", systemImage: "line.3.horizontal.decrease.circle")
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

                        ForEach(PlanType.allCases, id: \.self) { type in
                            Button {
                                filterType = type
                            } label: {
                                Label(type.displayName, systemImage: filterType == type ? "checkmark" : type.icon)
                            }
                        }
                    } label: {
                        Label("Type", systemImage: "folder")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlan) {
                AddPlanView()
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailView(plan: plan)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Plans", systemImage: "list.bullet.clipboard")
        } description: {
            Text("Plans help you organize larger projects like album releases, tours, or collaborations.")
        } actions: {
            Button("Add Plan") {
                showingAddPlan = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var plansList: some View {
        List {
            if !activePlans.isEmpty {
                Section("Active Plans") {
                    ForEach(activePlans) { plan in
                        PlanCard(plan: plan)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlan = plan
                            }
                    }
                    .onDelete { indexSet in
                        deletePlans(from: activePlans, at: indexSet)
                    }
                }
            }

            if !onHoldPlans.isEmpty {
                Section("On Hold") {
                    ForEach(onHoldPlans) { plan in
                        PlanCard(plan: plan)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlan = plan
                            }
                    }
                    .onDelete { indexSet in
                        deletePlans(from: onHoldPlans, at: indexSet)
                    }
                }
            }

            if !completedPlans.isEmpty {
                Section("Completed") {
                    ForEach(completedPlans) { plan in
                        PlanCard(plan: plan)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlan = plan
                            }
                    }
                    .onDelete { indexSet in
                        deletePlans(from: completedPlans, at: indexSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deletePlans(from list: [Plan], at offsets: IndexSet) {
        withAnimation {
            offsets.map { list[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct PlanCard: View {
    @ObservedObject var plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plan.type.icon)
                    .font(.title2)
                    .foregroundColor(Color(plan.currentStatus.color))
                    .frame(width: 40, height: 40)
                    .background(Color(plan.currentStatus.color).opacity(0.2))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.wrappedTitle)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Label(plan.type.displayName, systemImage: plan.type.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Label(plan.currentStatus.displayName, systemImage: plan.currentStatus.icon)
                            .font(.caption)
                            .foregroundColor(Color(plan.currentStatus.color))
                    }
                }

                Spacer()

                if let days = plan.daysUntilTarget {
                    VStack(alignment: .trailing) {
                        Text("\(abs(days))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(days < 0 ? .red : days <= 7 ? .orange : .primary)

                        Text(days < 0 ? "days ago" : "days left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Progress bar
            if !plan.actionsArray.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(plan.completedActionsCount)/\(plan.actionsArray.count) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(plan.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: plan.progress)
                        .tint(Color(plan.currentStatus.color))
                }
            }

            // Musicians
            if !plan.musiciansArray.isEmpty {
                HStack(spacing: -8) {
                    ForEach(plan.musiciansArray.prefix(4)) { musician in
                        Text(musician.initials)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .frame(width: 28, height: 28)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    }

                    if plan.musiciansArray.count > 4 {
                        Text("+\(plan.musiciansArray.count - 4)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var title = ""
    @State private var planType: PlanType = .project
    @State private var status: PlanStatus = .planning
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(86400 * 30)
    @State private var budget: String = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $planType) {
                        ForEach(PlanType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Status", selection: $status) {
                        ForEach(PlanStatus.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.icon)
                                .tag(s)
                        }
                    }
                }

                Section("Timeline") {
                    Toggle("Has Target Date", isOn: $hasTargetDate)

                    if hasTargetDate {
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: [.date])
                    }
                }

                Section("Budget") {
                    TextField("Budget (optional)", text: $budget)
                        .keyboardType(.decimalPad)
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Plan")
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
                        savePlan()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func savePlan() {
        let plan = Plan(context: viewContext)
        plan.id = UUID()
        plan.title = title.trimmingCharacters(in: .whitespaces)
        plan.planType = planType.rawValue
        plan.status = status.rawValue
        plan.targetDate = hasTargetDate ? targetDate : nil
        plan.budget = Double(budget) ?? 0
        plan.planDescription = description.isEmpty ? nil : description
        plan.createdAt = Date()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save plan: \(error)")
        }
    }
}

struct PlanDetailView: View {
    @ObservedObject var plan: Plan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingStatusPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color(plan.currentStatus.color).opacity(0.2))
                                .frame(width: 80, height: 80)

                            Image(systemName: plan.type.icon)
                                .font(.largeTitle)
                                .foregroundColor(Color(plan.currentStatus.color))
                        }

                        Text(plan.wrappedTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            Label(plan.type.displayName, systemImage: plan.type.icon)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)

                            Button {
                                showingStatusPicker = true
                            } label: {
                                Label(plan.currentStatus.displayName, systemImage: plan.currentStatus.icon)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(plan.currentStatus.color).opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()

                    // Progress
                    if !plan.actionsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Progress")
                                .font(.headline)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("\(plan.completedActionsCount) of \(plan.actionsArray.count) tasks completed")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(plan.progress * 100))%")
                                        .font(.headline)
                                        .foregroundColor(Color(plan.currentStatus.color))
                                }

                                ProgressView(value: plan.progress)
                                    .tint(Color(plan.currentStatus.color))
                                    .scaleEffect(x: 1, y: 2, anchor: .center)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let targetDate = plan.targetDate {
                            DetailRow(icon: "calendar", title: "Target Date", value: plan.formattedTargetDate)

                            if let days = plan.daysUntilTarget {
                                HStack {
                                    Image(systemName: days < 0 ? "exclamationmark.triangle" : "clock")
                                        .foregroundColor(days < 0 ? .red : days <= 7 ? .orange : .blue)
                                    Text(days < 0 ? "Overdue by \(abs(days)) days" : "\(days) days remaining")
                                        .font(.caption)
                                        .foregroundColor(days < 0 ? .red : days <= 7 ? .orange : .secondary)
                                }
                            }
                        }

                        if plan.budget > 0 {
                            DetailRow(icon: "dollarsign.circle", title: "Budget", value: String(format: "$%.2f", plan.budget))
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Description
                    if !plan.wrappedDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description")
                                .font(.headline)

                            Text(plan.wrappedDescription)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Musicians
                    if !plan.musiciansArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Musicians")
                                .font(.headline)

                            ForEach(plan.musiciansArray) { musician in
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

                    // Related Actions
                    if !plan.actionsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tasks")
                                .font(.headline)

                            ForEach(plan.actionsArray.prefix(5)) { action in
                                ActionRowView(action: action)
                            }

                            if plan.actionsArray.count > 5 {
                                Text("+ \(plan.actionsArray.count - 5) more tasks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Events
                    if !plan.eventsArray.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Related Events")
                                .font(.headline)

                            ForEach(plan.eventsArray.prefix(3)) { event in
                                EventRowView(event: event)
                            }
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
            .navigationTitle("Plan Details")
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
            .confirmationDialog("Update Status", isPresented: $showingStatusPicker) {
                ForEach(PlanStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        plan.currentStatus = status
                        if status == .completed {
                            plan.completedDate = Date()
                        }
                        try? viewContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    PlansView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

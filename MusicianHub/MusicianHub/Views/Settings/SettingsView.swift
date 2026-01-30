import SwiftUI

struct SettingsView: View {
    @AppStorage("autoProcessMessages") private var autoProcessMessages = true
    @AppStorage("showConfidenceLevels") private var showConfidenceLevels = false
    @AppStorage("minimumConfidence") private var minimumConfidence = 0.5
    @AppStorage("defaultEventType") private var defaultEventType = EventType.rehearsal.rawValue
    @AppStorage("defaultActionPriority") private var defaultActionPriority = ActionPriority.medium.rawValue
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("reminderTime") private var reminderTime = 60 // minutes before

    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingResetAlert = false
    @State private var showingExportSheet = false

    var body: some View {
        Form {
            // Processing Settings
            Section {
                Toggle("Auto-process Messages", isOn: $autoProcessMessages)

                Toggle("Show Confidence Levels", isOn: $showConfidenceLevels)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Minimum Confidence")
                        Spacer()
                        Text("\(Int(minimumConfidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $minimumConfidence, in: 0.3...0.9, step: 0.1)
                }
            } header: {
                Text("Message Processing")
            } footer: {
                Text("Items with confidence below the threshold will not be automatically created.")
            }

            // Default Values
            Section("Defaults") {
                Picker("Default Event Type", selection: $defaultEventType) {
                    ForEach(EventType.allCases, id: \.rawValue) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type.rawValue)
                    }
                }

                Picker("Default Action Priority", selection: $defaultActionPriority) {
                    ForEach(ActionPriority.allCases, id: \.rawValue) { priority in
                        Label(priority.displayName, systemImage: priority.icon)
                            .tag(priority.rawValue)
                    }
                }
            }

            // Notifications
            Section {
                Toggle("Enable Notifications", isOn: $enableNotifications)

                if enableNotifications {
                    Picker("Reminder Time", selection: $reminderTime) {
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                        Text("1 hour before").tag(60)
                        Text("2 hours before").tag(120)
                        Text("1 day before").tag(1440)
                    }
                }
            } header: {
                Text("Notifications")
            }

            // Data Management
            Section("Data Management") {
                Button {
                    showingExportSheet = true
                } label: {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }

                Link(destination: URL(string: "https://github.com")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "mailto:support@musicianhub.com")!) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }

            // Privacy
            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all musicians, events, actions, plans, and messages. This action cannot be undone.")
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportDataView()
        }
    }

    private func resetAllData() {
        // Delete all entities
        let entityNames = ["Musician", "Event", "Action", "Plan", "Message"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try viewContext.execute(deleteRequest)
            } catch {
                print("Failed to delete \(entityName): \(error)")
            }
        }

        try? viewContext.save()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Last updated: January 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    Text("Data Collection")
                        .font(.headline)

                    Text("""
                    MusicianHub stores all your data locally on your device. We do not collect, transmit, or store any of your personal information on external servers.

                    The app may request access to:
                    - Contacts: To import musician information
                    - Notifications: To send reminders for events and actions

                    All message content, musician details, events, actions, and plans remain on your device and are not shared with any third parties.
                    """)
                }

                Group {
                    Text("Data Security")
                        .font(.headline)

                    Text("""
                    Your data is stored using Apple's Core Data framework with encryption enabled when your device is locked. We recommend enabling a passcode or biometric authentication on your device for additional security.
                    """)
                }

                Group {
                    Text("Your Rights")
                        .font(.headline)

                    Text("""
                    You can delete all your data at any time through the Settings menu. Uninstalling the app will also remove all stored data from your device.
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Last updated: January 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    Text("Acceptance of Terms")
                        .font(.headline)

                    Text("""
                    By using MusicianHub, you agree to these terms of service. If you do not agree with any part of these terms, please do not use the application.
                    """)
                }

                Group {
                    Text("Use of the Application")
                        .font(.headline)

                    Text("""
                    MusicianHub is designed to help musicians organize their communications and schedules. The app uses natural language processing to extract events, actions, and plans from text, but the accuracy of these extractions is not guaranteed.

                    You are responsible for verifying the accuracy of any extracted information before relying on it.
                    """)
                }

                Group {
                    Text("Limitation of Liability")
                        .font(.headline)

                    Text("""
                    MusicianHub is provided "as is" without warranty of any kind. We are not liable for any missed events, forgotten actions, or other consequences resulting from use of this application.
                    """)
                }

                Group {
                    Text("Changes to Terms")
                        .font(.headline)

                    Text("""
                    We reserve the right to modify these terms at any time. Continued use of the application after changes constitutes acceptance of the new terms.
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var exportMusicians = true
    @State private var exportEvents = true
    @State private var exportActions = true
    @State private var exportPlans = true
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Data to Export") {
                    Toggle("Musicians", isOn: $exportMusicians)
                    Toggle("Events", isOn: $exportEvents)
                    Toggle("Actions", isOn: $exportActions)
                    Toggle("Plans", isOn: $exportPlans)
                }

                Section {
                    Button {
                        exportData()
                    } label: {
                        if isExporting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Export as JSON")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isExporting || (!exportMusicians && !exportEvents && !exportActions && !exportPlans))
                } footer: {
                    Text("Data will be exported as a JSON file that you can save or share.")
                }
            }
            .navigationTitle("Export Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportData() {
        isExporting = true

        // Build export data
        var exportDict: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": "1.0.0"
        ]

        if exportMusicians {
            let request: NSFetchRequest<Musician> = Musician.fetchRequest()
            if let musicians = try? viewContext.fetch(request) {
                exportDict["musicians"] = musicians.map { musician in
                    [
                        "name": musician.name ?? "",
                        "instrument": musician.instrument ?? "",
                        "email": musician.email ?? "",
                        "phone": musician.phone ?? "",
                        "band": musician.band ?? "",
                        "notes": musician.notes ?? ""
                    ]
                }
            }
        }

        if exportEvents {
            let request: NSFetchRequest<Event> = Event.fetchRequest()
            if let events = try? viewContext.fetch(request) {
                exportDict["events"] = events.map { event in
                    [
                        "title": event.title ?? "",
                        "date": event.date?.ISO8601Format() ?? "",
                        "location": event.location ?? "",
                        "type": event.eventType ?? "",
                        "notes": event.notes ?? ""
                    ]
                }
            }
        }

        if exportActions {
            let request: NSFetchRequest<Action> = Action.fetchRequest()
            if let actions = try? viewContext.fetch(request) {
                exportDict["actions"] = actions.map { action in
                    [
                        "title": action.title ?? "",
                        "priority": action.priority ?? "",
                        "category": action.category ?? "",
                        "dueDate": action.dueDate?.ISO8601Format() ?? "",
                        "isCompleted": action.isCompleted,
                        "notes": action.notes ?? ""
                    ] as [String : Any]
                }
            }
        }

        if exportPlans {
            let request: NSFetchRequest<Plan> = Plan.fetchRequest()
            if let plans = try? viewContext.fetch(request) {
                exportDict["plans"] = plans.map { plan in
                    [
                        "title": plan.title ?? "",
                        "type": plan.planType ?? "",
                        "status": plan.status ?? "",
                        "targetDate": plan.targetDate?.ISO8601Format() ?? "",
                        "description": plan.planDescription ?? ""
                    ]
                }
            }
        }

        // Convert to JSON and share
        if let jsonData = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("MusicianHub_Export.json")
            try? jsonData.write(to: tempURL)

            #if os(iOS)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
            #endif
        }

        isExporting = false
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

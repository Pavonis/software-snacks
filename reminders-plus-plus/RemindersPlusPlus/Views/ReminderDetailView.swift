import EventKit
import SwiftUI

/// Full detail/edit view for a reminder, exposing all EventKit properties.
struct ReminderDetailView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State var item: ReminderItem
    let listSource: ReminderSource

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var urlString: String = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasDueTime = false
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var priority: Int = 0
    @State private var isFlagged = false
    @State private var selectedListId: String = ""
    @State private var showRecurrence = false
    @State private var recurrenceFrequency: RecurrenceInfo.Frequency = .daily
    @State private var recurrenceInterval = 1
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                titleNotesSection
                dateSection
                priorityFlagSection
                listSection
                recurrenceSection
                alarmsSection
                urlSection
                metadataSection
                deleteSection
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { saveAndDismiss() }
                        .bold()
                }
            }
            .onAppear { populateFields() }
            .confirmationDialog("Delete Reminder", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    try? store.deleteReminder(item)
                    dismiss()
                }
            } message: {
                Text("This reminder will be permanently deleted.")
            }
        }
    }

    // MARK: - Sections

    private var titleNotesSection: some View {
        Section {
            TextField("Title", text: $title)
                .font(.body)

            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var dateSection: some View {
        Section {
            Toggle("Due Date", isOn: $hasDueDate.animation())

            if hasDueDate {
                DatePicker(
                    "Date",
                    selection: $dueDate,
                    displayedComponents: hasDueTime ? [.date, .hourAndMinute] : [.date]
                )

                Toggle("Time", isOn: $hasDueTime.animation())
            }

            Toggle("Start Date", isOn: $hasStartDate.animation())

            if hasStartDate {
                DatePicker("Start", selection: $startDate, displayedComponents: [.date])
            }
        }
    }

    private var priorityFlagSection: some View {
        Section {
            Picker("Priority", selection: $priority) {
                Text("None").tag(0)
                HStack {
                    Text("High")
                    Text("!!!").foregroundStyle(.red).bold()
                }.tag(1)
                HStack {
                    Text("Medium")
                    Text("!!").foregroundStyle(.orange).bold()
                }.tag(5)
                HStack {
                    Text("Low")
                    Text("!").foregroundStyle(.blue).bold()
                }.tag(9)
            }

            Toggle(isOn: $isFlagged) {
                Label("Flagged", systemImage: isFlagged ? "flag.fill" : "flag")
            }
        }
    }

    private var listSection: some View {
        Section {
            Picker("List", selection: $selectedListId) {
                ForEach(store.lists) { list in
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(list.color)
                            .font(.caption)
                        Text(list.title)
                    }
                    .tag(list.id)
                }
            }
        }
    }

    private var recurrenceSection: some View {
        Section {
            Toggle("Repeat", isOn: $showRecurrence.animation())

            if showRecurrence {
                Picker("Frequency", selection: $recurrenceFrequency) {
                    ForEach(RecurrenceInfo.Frequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue.capitalized).tag(freq)
                    }
                }

                Stepper("Every \(recurrenceInterval) \(recurrenceFrequency.rawValue)\(recurrenceInterval > 1 ? "s" : "")", value: $recurrenceInterval, in: 1...365)
            }

            if !item.recurrenceRules.isEmpty {
                ForEach(item.recurrenceRules) { rule in
                    LabeledContent("Current", value: rule.displayText)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var alarmsSection: some View {
        Section("Alarms") {
            if item.alarms.isEmpty {
                Text("No alarms")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(item.alarms) { alarm in
                    HStack {
                        Image(systemName: alarm.isLocationBased ? "location.fill" : "bell.fill")
                            .foregroundStyle(.secondary)
                        Text(alarm.displayText)
                    }
                }
            }

            // Alarm info — what the API supports
            DisclosureGroup("Alarm Capabilities") {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Absolute date alarms", systemImage: "checkmark.circle.fill")
                    Label("Relative offset alarms", systemImage: "checkmark.circle.fill")
                    Label("Location enter/leave geofences", systemImage: "checkmark.circle.fill")
                    Label("EKStructuredLocation with radius", systemImage: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var urlSection: some View {
        Section {
            TextField("URL", text: $urlString)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
        }
    }

    private var metadataSection: some View {
        Section("Metadata") {
            if let created = item.creationDate {
                LabeledContent("Created", value: created.formatted(date: .abbreviated, time: .shortened))
            }
            if let modified = item.lastModifiedDate {
                LabeledContent("Modified", value: modified.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("List", value: item.listTitle)
            LabeledContent("ID", value: String(item.id.prefix(12)) + "...")
            if let ext = item.externalIdentifier {
                LabeledContent("External ID", value: String(ext.prefix(12)) + "...")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Reminder")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func populateFields() {
        title = item.title
        notes = item.notes ?? ""
        urlString = item.url?.absoluteString ?? ""
        priority = item.priority
        isFlagged = item.isFlagged
        selectedListId = item.listId

        if let due = item.dueDate {
            hasDueDate = true
            dueDate = due
            hasDueTime = item.dueDateComponents?.hour != nil
        }
        if let start = item.startDate {
            hasStartDate = true
            startDate = start
        }

        showRecurrence = item.hasRecurrenceRules
        if let first = item.recurrenceRules.first {
            recurrenceFrequency = first.frequency
            recurrenceInterval = first.interval
        }
    }

    private func saveAndDismiss() {
        do {
            var dueDateComps: DateComponents?? = nil
            if hasDueDate {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
                if hasDueTime {
                    let timeComps = Calendar.current.dateComponents([.hour, .minute], from: dueDate)
                    comps.hour = timeComps.hour
                    comps.minute = timeComps.minute
                }
                dueDateComps = .some(comps)
            } else {
                dueDateComps = .some(nil) // Clear the due date
            }

            var startDateComps: DateComponents?? = nil
            if hasStartDate {
                startDateComps = .some(Calendar.current.dateComponents([.year, .month, .day], from: startDate))
            } else {
                startDateComps = .some(nil)
            }

            let url: URL? = urlString.isEmpty ? nil : URL(string: urlString)

            _ = try store.updateReminder(
                item,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                url: url,
                dueDate: dueDateComps,
                startDate: startDateComps,
                priority: priority,
                isFlagged: isFlagged,
                listId: selectedListId != item.listId ? selectedListId : nil
            )

            // Handle recurrence changes
            if showRecurrence && item.recurrenceRules.isEmpty {
                _ = try store.addRecurrenceRule(
                    to: item,
                    frequency: recurrenceFrequency,
                    interval: recurrenceInterval
                )
            } else if !showRecurrence && !item.recurrenceRules.isEmpty {
                _ = try store.removeRecurrenceRules(from: item)
            }

            dismiss()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ReminderDetailView(item: .preview, listSource: .smart(.all))
        .environment(ReminderStore())
}

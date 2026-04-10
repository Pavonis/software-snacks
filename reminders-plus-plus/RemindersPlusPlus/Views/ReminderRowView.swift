import SwiftUI

/// Individual reminder row with completion toggle and summary info.
struct ReminderRowView: View {
    let item: ReminderItem
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Completion toggle
                Button(action: onToggle) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isCompleted ? .green : priorityColor)
                }
                .buttonStyle(.plain)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(item.title)
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            .lineLimit(2)

                        if item.isFlagged {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    // Subtitle line: due date, list, notes preview
                    HStack(spacing: 6) {
                        if let due = item.dueDate {
                            Label {
                                Text(due, style: .date)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(item.isOverdue ? .red : .secondary)
                        }

                        if item.hasRecurrenceRules {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if item.hasAlarms {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let notes = item.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Priority indicator
                if item.priority > 0 {
                    priorityBadge
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color {
        switch item.priority {
        case 1...4: return .red
        case 5: return .orange
        case 6...9: return .blue
        default: return .secondary
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        let exclamations: String = switch item.priority {
        case 1...4: "!!!"
        case 5: "!!"
        case 6...9: "!"
        default: ""
        }
        Text(exclamations)
            .font(.caption.bold())
            .foregroundStyle(priorityColor)
    }
}

#Preview {
    List {
        ReminderRowView(
            item: ReminderItem.preview,
            onToggle: {},
            onTap: {}
        )
    }
}

// MARK: - Preview Helper

extension ReminderItem {
    static var preview: ReminderItem {
        ReminderItem(
            id: "preview-1",
            title: "Buy groceries",
            notes: "Milk, eggs, bread",
            url: nil,
            isCompleted: false,
            completionDate: nil,
            dueDateComponents: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: Date()
            ),
            startDateComponents: nil,
            priority: 1,
            isFlagged: true,
            listId: "list-1",
            listTitle: "Personal",
            creationDate: Date(),
            lastModifiedDate: Date(),
            hasAlarms: true,
            alarms: [],
            hasRecurrenceRules: false,
            recurrenceRules: [],
            externalIdentifier: nil
        )
    }

    /// Memberwise initializer for previews (bypasses EKReminder).
    init(
        id: String,
        title: String,
        notes: String?,
        url: URL?,
        isCompleted: Bool,
        completionDate: Date?,
        dueDateComponents: DateComponents?,
        startDateComponents: DateComponents?,
        priority: Int,
        isFlagged: Bool,
        listId: String,
        listTitle: String,
        creationDate: Date?,
        lastModifiedDate: Date?,
        hasAlarms: Bool,
        alarms: [AlarmInfo],
        hasRecurrenceRules: Bool,
        recurrenceRules: [RecurrenceInfo],
        externalIdentifier: String?
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.url = url
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.dueDateComponents = dueDateComponents
        self.startDateComponents = startDateComponents
        self.priority = priority
        self.isFlagged = isFlagged
        self.listId = listId
        self.listTitle = listTitle
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.hasAlarms = hasAlarms
        self.alarms = alarms
        self.hasRecurrenceRules = hasRecurrenceRules
        self.recurrenceRules = recurrenceRules
        self.externalIdentifier = externalIdentifier
    }
}

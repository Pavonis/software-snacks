import EventKit
import Foundation

/// Bridges EKReminder to an app-friendly value type.
/// Captures the full surface area of reminder properties exposed by EventKit.
struct ReminderItem: Identifiable, Hashable {
    let id: String
    var title: String
    var notes: String?
    var url: URL?
    var isCompleted: Bool
    var completionDate: Date?
    var dueDateComponents: DateComponents?
    var startDateComponents: DateComponents?
    /// 0 = none, 1 = high, 5 = medium, 9 = low (EKReminder uses 0-9 scale)
    var priority: Int
    var isFlagged: Bool
    var listId: String
    var listTitle: String
    var creationDate: Date?
    var lastModifiedDate: Date?
    var hasAlarms: Bool
    var alarms: [AlarmInfo]
    var hasRecurrenceRules: Bool
    var recurrenceRules: [RecurrenceInfo]
    var externalIdentifier: String?

    init(from reminder: EKReminder) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? ""
        self.notes = reminder.notes
        self.url = reminder.url
        self.isCompleted = reminder.isCompleted
        self.completionDate = reminder.completionDate
        self.dueDateComponents = reminder.dueDateComponents
        self.startDateComponents = reminder.startDateComponents
        self.priority = reminder.priority
        self.isFlagged = reminder.isFlagged
        self.listId = reminder.calendar?.calendarIdentifier ?? ""
        self.listTitle = reminder.calendar?.title ?? ""
        self.creationDate = reminder.creationDate
        self.lastModifiedDate = reminder.lastModifiedDate
        self.hasAlarms = reminder.hasAlarms
        self.alarms = (reminder.alarms ?? []).map { AlarmInfo(from: $0) }
        self.hasRecurrenceRules = reminder.hasRecurrenceRules
        self.recurrenceRules = (reminder.recurrenceRules ?? []).map { RecurrenceInfo(from: $0) }
        self.externalIdentifier = reminder.calendarItemExternalIdentifier
    }

    var dueDate: Date? {
        guard let components = dueDateComponents else { return nil }
        return Calendar.current.date(from: components)
    }

    var startDate: Date? {
        guard let components = startDateComponents else { return nil }
        return Calendar.current.date(from: components)
    }

    var priorityLabel: String {
        switch priority {
        case 0: return "None"
        case 1...4: return "High"
        case 5: return "Medium"
        case 6...9: return "Low"
        default: return "None"
        }
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReminderItem, rhs: ReminderItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Alarm Info

/// Captures EKAlarm properties including location-based alarms
struct AlarmInfo: Identifiable, Hashable {
    let id = UUID()
    var absoluteDate: Date?
    var relativeOffset: TimeInterval?
    var proximityType: ProximityType
    var locationTitle: String?
    var locationRadius: Double?
    var locationLatitude: Double?
    var locationLongitude: Double?

    enum ProximityType: String, Hashable {
        case none, enter, leave
    }

    init(from alarm: EKAlarm) {
        self.absoluteDate = alarm.absoluteDate
        self.relativeOffset = alarm.relativeOffset
        switch alarm.proximity {
        case .enter: self.proximityType = .enter
        case .leave: self.proximityType = .leave
        default: self.proximityType = .none
        }
        if let location = alarm.structuredLocation {
            self.locationTitle = location.title
            self.locationRadius = location.radius
            self.locationLatitude = location.geoLocation?.coordinate.latitude
            self.locationLongitude = location.geoLocation?.coordinate.longitude
        }
    }

    var isLocationBased: Bool {
        proximityType != .none
    }

    var displayText: String {
        if let date = absoluteDate {
            return date.formatted(date: .abbreviated, time: .shortened)
        } else if let offset = relativeOffset {
            let minutes = Int(abs(offset) / 60)
            if minutes == 0 { return "At time of event" }
            if minutes < 60 { return "\(minutes) min before" }
            let hours = minutes / 60
            if hours < 24 { return "\(hours) hr before" }
            return "\(hours / 24) day(s) before"
        } else if let title = locationTitle {
            let action = proximityType == .enter ? "Arriving" : "Leaving"
            return "\(action): \(title)"
        }
        return "Alarm"
    }
}

// MARK: - Recurrence Info

/// Captures EKRecurrenceRule properties
struct RecurrenceInfo: Identifiable, Hashable {
    let id = UUID()
    var frequency: Frequency
    var interval: Int
    var daysOfTheWeek: [Int]?
    var daysOfTheMonth: [Int]?
    var monthsOfTheYear: [Int]?
    var endDate: Date?
    var endCount: Int?

    enum Frequency: String, CaseIterable, Hashable {
        case daily, weekly, monthly, yearly
    }

    init(from rule: EKRecurrenceRule) {
        switch rule.frequency {
        case .daily: self.frequency = .daily
        case .weekly: self.frequency = .weekly
        case .monthly: self.frequency = .monthly
        case .yearly: self.frequency = .yearly
        @unknown default: self.frequency = .daily
        }
        self.interval = rule.interval
        self.daysOfTheWeek = rule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue }
        self.daysOfTheMonth = rule.daysOfTheMonth?.map { $0.intValue }
        self.monthsOfTheYear = rule.monthsOfTheYear?.map { $0.intValue }
        if let end = rule.recurrenceEnd {
            self.endDate = end.endDate
            self.endCount = end.occurrenceCount > 0 ? end.occurrenceCount : nil
        }
    }

    var displayText: String {
        let freq = interval == 1 ? frequency.rawValue : "Every \(interval) \(frequency.rawValue)s"
        return freq.capitalized
    }
}

import EventKit
import SwiftUI

/// Bridges EKCalendar to an app-friendly value type for reminder lists.
struct ReminderList: Identifiable, Hashable {
    let id: String
    var title: String
    var color: Color
    var cgColor: CGColor
    var sourceName: String
    var sourceType: SourceType
    var isImmutable: Bool
    var allowsModifications: Bool
    var reminderCount: Int?

    enum SourceType: String, Hashable {
        case local, calDAV, exchange, birthday, subscribed, unknown

        init(from ekType: EKSourceType) {
            switch ekType {
            case .local: self = .local
            case .calDAV: self = .calDAV
            case .exchange: self = .exchange
            case .birthdays: self = .birthday
            case .subscribed: self = .subscribed
            @unknown default: self = .unknown
            }
        }

        var displayName: String {
            switch self {
            case .local: return "On My Device"
            case .calDAV: return "iCloud"
            case .exchange: return "Exchange"
            case .birthday: return "Birthdays"
            case .subscribed: return "Subscribed"
            case .unknown: return "Other"
            }
        }
    }

    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.cgColor = calendar.cgColor
        self.color = Color(cgColor: calendar.cgColor) ?? .blue
        self.sourceName = calendar.source?.title ?? "Unknown"
        self.sourceType = SourceType(from: calendar.source?.sourceType ?? .local)
        self.isImmutable = calendar.isImmutable
        self.allowsModifications = calendar.allowsContentModifications
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ReminderList, rhs: ReminderList) -> Bool {
        lhs.id == rhs.id
    }
}

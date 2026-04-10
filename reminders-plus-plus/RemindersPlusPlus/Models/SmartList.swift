import SwiftUI

/// Built-in smart lists that mirror Apple Reminders' smart categories.
enum SmartList: String, CaseIterable, Identifiable {
    case today
    case scheduled
    case all
    case flagged
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .scheduled: return "Scheduled"
        case .all: return "All"
        case .flagged: return "Flagged"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .today: return "calendar.circle.fill"
        case .scheduled: return "calendar.badge.clock"
        case .all: return "tray.circle.fill"
        case .flagged: return "flag.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .today: return .blue
        case .scheduled: return .red
        case .all: return .gray
        case .flagged: return .orange
        case .completed: return .gray
        }
    }
}

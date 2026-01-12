import SwiftUI

/// Direction of a flick gesture and its associated action
enum FlickDirection {
    case up     // Favorite
    case down   // Delete

    /// The color associated with this flick direction
    var color: Color {
        switch self {
        case .up:
            return .green
        case .down:
            return .red
        }
    }

    /// Human-readable action name for logging
    var actionName: String {
        switch self {
        case .up:
            return "Favorited"
        case .down:
            return "Deleted"
        }
    }

    /// Emoji for console logging
    var emoji: String {
        switch self {
        case .up:
            return "⭐"
        case .down:
            return "🗑️"
        }
    }

    /// Determine direction from vertical offset
    static func from(verticalOffset: CGFloat) -> FlickDirection? {
        if verticalOffset < 0 {
            return .up
        } else if verticalOffset > 0 {
            return .down
        }
        return nil
    }
}

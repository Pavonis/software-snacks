import SwiftUI

/// Direction of a flick gesture - 8 possible directions (4 edges + 4 corners)
enum FlickDirection: String, CaseIterable {
    case up
    case upRight
    case right
    case downRight
    case down
    case downLeft
    case left
    case upLeft

    /// The color associated with this flick direction
    var color: Color {
        switch self {
        case .up:
            return .green
        case .upRight:
            return .cyan
        case .right:
            return .blue
        case .downRight:
            return .yellow
        case .down:
            return .red
        case .downLeft:
            return .pink
        case .left:
            return .orange
        case .upLeft:
            return .purple
        }
    }

    /// Emoji for console logging
    var emoji: String {
        switch self {
        case .up:        return "⬆️"
        case .upRight:   return "↗️"
        case .right:     return "➡️"
        case .downRight: return "↘️"
        case .down:      return "⬇️"
        case .downLeft:  return "↙️"
        case .left:      return "⬅️"
        case .upLeft:    return "↖️"
        }
    }

    /// Display name for logging
    var displayName: String {
        switch self {
        case .up:        return "UP"
        case .upRight:   return "UP_RIGHT"
        case .right:     return "RIGHT"
        case .downRight: return "DOWN_RIGHT"
        case .down:      return "DOWN"
        case .downLeft:  return "DOWN_LEFT"
        case .left:      return "LEFT"
        case .upLeft:    return "UP_LEFT"
        }
    }

    /// Center angle in radians for this direction (0 = right, positive = clockwise)
    var centerAngle: Double {
        switch self {
        case .right:     return 0
        case .downRight: return .pi / 4
        case .down:      return .pi / 2
        case .downLeft:  return 3 * .pi / 4
        case .left:      return .pi
        case .upLeft:    return -.pi * 3 / 4
        case .up:        return -.pi / 2
        case .upRight:   return -.pi / 4
        }
    }

    /// Whether this is a corner direction (gets larger wedge)
    var isCorner: Bool {
        switch self {
        case .upRight, .downRight, .downLeft, .upLeft:
            return true
        case .up, .down, .left, .right:
            return false
        }
    }

    /// Determine direction from drag offset using angle-based detection
    /// - Parameters:
    ///   - offset: The drag offset from center
    ///   - cornerWedgeDegrees: Size of corner wedges in degrees (edges get remainder)
    /// - Returns: The detected direction, or nil if offset is zero
    static func from(offset: CGSize, cornerWedgeDegrees: Double = 50) -> FlickDirection? {
        guard offset.width != 0 || offset.height != 0 else { return nil }

        // Calculate angle in radians (-π to π, 0 = right, positive = down/clockwise)
        let angle = atan2(offset.height, offset.width)
        let degrees = angle * 180 / .pi

        // Convert corner wedge to half-width for range checking
        let cornerHalf = cornerWedgeDegrees / 2
        let edgeHalf = (90 - cornerWedgeDegrees) / 2

        // Define ranges for each direction (center ± half-width)
        // Corners: 50° wedge, Edges: 40° wedge (with default 50° corners)

        // Right: centered at 0°
        if degrees >= -edgeHalf && degrees < edgeHalf {
            return .right
        }
        // Down-Right: centered at 45°
        if degrees >= edgeHalf && degrees < edgeHalf + cornerWedgeDegrees {
            return .downRight
        }
        // Down: centered at 90°
        if degrees >= 90 - edgeHalf && degrees < 90 + edgeHalf {
            return .down
        }
        // Down-Left: centered at 135°
        if degrees >= 90 + edgeHalf && degrees < 180 - edgeHalf {
            return .downLeft
        }
        // Left: centered at 180° (wraps around)
        if degrees >= 180 - edgeHalf || degrees < -180 + edgeHalf {
            return .left
        }
        // Up-Left: centered at -135°
        if degrees >= -180 + edgeHalf && degrees < -90 - edgeHalf {
            return .upLeft
        }
        // Up: centered at -90°
        if degrees >= -90 - edgeHalf && degrees < -90 + edgeHalf {
            return .up
        }
        // Up-Right: centered at -45°
        if degrees >= -90 + edgeHalf && degrees < -edgeHalf {
            return .upRight
        }

        return .right // Fallback
    }
}

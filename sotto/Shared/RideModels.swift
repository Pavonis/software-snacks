import Foundation

/// A point-in-time view of the ride, produced on the watch and mirrored to the
/// phone over WatchConnectivity for the Live Activity and in-app live card.
struct RideSnapshot: Codable {
    var elapsedSeconds: TimeInterval = 0
    var power: Int = 0
    var cadence: Int = 0
    var heartRate: Int = 0
    var speedMph: Double = 0
    var distanceMiles: Double = 0
    var elevationGainFeet: Double = 0
    var gradePercent: Double = 0
    var activeCalories: Double = 0
    var powerMeterConnected: Bool = false
    var heartRateConnected: Bool = false
    var startDate: Date = .now
    var timestamp: Date = .now
}

struct RoutePoint: Codable {
    var latitude: Double
    var longitude: Double
}

struct RideSummary: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Ride"
    var startDate: Date
    var duration: TimeInterval
    var distanceMiles: Double
    var averagePower: Int
    var averageSpeedMph: Double
    var averageHeartRate: Int
    var activeCalories: Double
    var elevationGainFeet: Double
    var route: [RoutePoint] = []
}

/// Chainring/cassette setup, configured on the phone and synced to the watch.
/// Used for gear display and as a fallback for speed-from-cadence.
struct DrivetrainConfig: Codable, Equatable {
    var chainrings: [Int] = [48, 35]
    var cassette: [Int] = [10, 11, 12, 13, 14, 15, 17, 19, 21, 24, 28, 33]
    var wheelCircumferenceMM: Int = 2110

    var speedCount: Int { cassette.count }
}

enum RideFormat {
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func miles(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

enum LinkPayload {
    static let snapshot = "snapshot"
    static let rideState = "rideState"
    static let summary = "summary"
    static let drivetrainConfig = "drivetrainConfig"

    enum RideState: String {
        case idle, active, ended
    }
}

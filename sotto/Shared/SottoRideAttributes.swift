import Foundation
import ActivityKit

struct SottoRideAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var power: Int
        var speedMph: Double
        var distanceMiles: Double
        var heartRate: Int
        var startDate: Date
    }

    var rideName: String
}

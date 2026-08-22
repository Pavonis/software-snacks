import Foundation
import ActivityKit

/// Starts, updates, and ends the ride Live Activity on the phone.
final class LiveActivityController {
    private var activity: Activity<SottoRideAttributes>?

    func startOrUpdate(with snapshot: RideSnapshot) {
        let state = SottoRideAttributes.ContentState(
            power: snapshot.power,
            speedMph: snapshot.speedMph,
            distanceMiles: snapshot.distanceMiles,
            heartRate: snapshot.heartRate,
            startDate: snapshot.startDate
        )
        let content = ActivityContent(state: state, staleDate: Date(timeIntervalSinceNow: 30))

        if let activity {
            Task { await activity.update(content) }
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: SottoRideAttributes(rideName: "Outdoor Ride"),
            content: content
        )
    }

    func end(with snapshot: RideSnapshot?) {
        guard let activity else { return }
        let state = SottoRideAttributes.ContentState(
            power: snapshot?.power ?? 0,
            speedMph: snapshot?.speedMph ?? 0,
            distanceMiles: snapshot?.distanceMiles ?? 0,
            heartRate: snapshot?.heartRate ?? 0,
            startDate: snapshot?.startDate ?? .now
        )
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date(timeIntervalSinceNow: 60))
            )
        }
        self.activity = nil
    }
}

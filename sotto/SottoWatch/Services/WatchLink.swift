import Foundation
import WatchConnectivity

/// Watch-side WatchConnectivity bridge. Mirrors ride state to the phone
/// (which drives the Live Activity) and receives drivetrain configuration.
final class WatchLink: NSObject, ObservableObject {
    @Published var drivetrainConfig = DrivetrainConfig()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSnapshot(_ snapshot: RideSnapshot, state: LinkPayload.RideState) {
        guard WCSession.default.activationState == .activated,
              let data = try? encoder.encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext([
            LinkPayload.snapshot: data,
            LinkPayload.rideState: state.rawValue,
        ])
    }

    func sendSummary(_ summary: RideSummary) {
        guard WCSession.default.activationState == .activated,
              let data = try? encoder.encode(summary) else { return }
        WCSession.default.transferUserInfo([LinkPayload.summary: data])
    }

    func sendRideEnded() {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([
            LinkPayload.rideState: LinkPayload.RideState.ended.rawValue,
        ])
    }
}

extension WatchLink: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext[LinkPayload.drivetrainConfig] as? Data,
           let config = try? decoder.decode(DrivetrainConfig.self, from: data) {
            DispatchQueue.main.async {
                self.drivetrainConfig = config
            }
        }
    }
}

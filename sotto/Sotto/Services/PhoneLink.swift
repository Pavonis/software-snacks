import Foundation
import WatchConnectivity

/// Phone-side WatchConnectivity bridge: receives live ride snapshots (which
/// drive the Live Activity), receives finished ride summaries, and pushes
/// drivetrain configuration to the watch.
final class PhoneLink: NSObject, ObservableObject {
    @Published var latestSnapshot: RideSnapshot?
    @Published var rideActive = false

    let store: RideStore
    private let liveActivity = LiveActivityController()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(store: RideStore) {
        self.store = store
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendDrivetrainConfig(_ config: DrivetrainConfig) {
        guard WCSession.default.activationState == .activated,
              let data = try? encoder.encode(config) else { return }
        try? WCSession.default.updateApplicationContext([LinkPayload.drivetrainConfig: data])
    }

    private func handle(context: [String: Any]) {
        let state = (context[LinkPayload.rideState] as? String)
            .flatMap(LinkPayload.RideState.init(rawValue:))

        if let data = context[LinkPayload.snapshot] as? Data,
           let snapshot = try? decoder.decode(RideSnapshot.self, from: data) {
            latestSnapshot = snapshot
            if state == .active {
                rideActive = true
                liveActivity.startOrUpdate(with: snapshot)
            }
        }

        if state == .ended {
            rideActive = false
            liveActivity.end(with: latestSnapshot)
        }
    }
}

extension PhoneLink: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handle(context: applicationContext)
        }
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[LinkPayload.summary] as? Data,
              let summary = try? decoder.decode(RideSummary.self, from: data) else { return }
        DispatchQueue.main.async {
            self.store.add(summary)
            self.rideActive = false
        }
    }
}

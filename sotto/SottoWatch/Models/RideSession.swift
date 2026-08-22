import Foundation
import SwiftUI
import Combine

/// Ties the workout, sensors, and phone link together and exposes the values
/// the ride screens render. Once a second it merges HealthKit + BLE data into
/// a RideSnapshot and mirrors it to the phone.
@MainActor
final class RideSession: ObservableObject {
    let workout = WorkoutManager()
    let sensors = SensorManager()
    let link = WatchLink()

    @Published var snapshot = RideSnapshot()

    private var mirrorTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        workout.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        sensors.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        link.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var heartRate: Int {
        sensors.heartRateStrapConnected ? sensors.strapHeartRate : workout.wristHeartRate
    }

    func start() {
        workout.startRide()
        startMirroring()
    }

    func end() {
        mirrorTimer?.invalidate()
        workout.endRide()
    }

    /// Called by SummaryView once the workout finalizes, so the summary and
    /// ride-ended signal reach the phone exactly once.
    func publishSummary(_ summary: RideSummary) {
        link.sendSummary(summary)
        link.sendRideEnded()
    }

    private func startMirroring() {
        mirrorTimer?.invalidate()
        mirrorTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard workout.phase == .active || workout.phase == .paused else { return }
        workout.recordSensorSample(power: sensors.power3s, heartRate: heartRate)
        snapshot = RideSnapshot(
            elapsedSeconds: workout.elapsed,
            power: sensors.power3s,
            cadence: sensors.cadence,
            heartRate: heartRate,
            speedMph: workout.speedMph,
            distanceMiles: workout.distanceMiles,
            elevationGainFeet: workout.elevationGainFeet,
            gradePercent: workout.gradePercent,
            activeCalories: workout.activeCalories,
            powerMeterConnected: sensors.powerMeterConnected,
            heartRateConnected: sensors.heartRateStrapConnected || workout.wristHeartRate > 0,
            startDate: workout.startDate,
            timestamp: .now
        )
        link.sendSnapshot(snapshot, state: .active)
    }
}

/// Sotto's metric palette — one vivid color per metric, Apple Fitness style.
extension Color {
    static let sottoTime = Color(red: 1.0, green: 0.839, blue: 0.039)      // #FFD60A
    static let sottoDistance = Color(red: 0.188, green: 0.820, blue: 0.345) // #30D158
    static let sottoPower = Color(red: 0.749, green: 0.353, blue: 0.949)   // #BF5AF2
    static let sottoSpeed = Color(red: 0.392, green: 0.824, blue: 1.0)     // #64D2FF
    static let sottoCadence = Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A
    static let sottoHeart = Color(red: 1.0, green: 0.216, blue: 0.373)     // #FF375F
    static let sottoCalories = Color(red: 1.0, green: 0.271, blue: 0.227)  // #FF453A
}

/// Rough power zones from a configurable FTP; drives the zone bar on the
/// metrics page. FTP lives in UserDefaults until a real settings screen exists.
enum PowerZones {
    static var ftp: Int {
        let stored = UserDefaults.standard.integer(forKey: "ftpWatts")
        return stored > 0 ? stored : 220
    }

    static let zoneColors: [Color] = [
        Color(white: 0.55), .sottoSpeed, .sottoDistance, .sottoTime,
        .sottoCadence, .sottoHeart, .sottoPower,
    ]

    static let zoneNames = [
        "RECOVERY", "ENDURANCE", "TEMPO", "THRESHOLD", "VO2 MAX", "ANAEROBIC", "NEUROMUSCULAR",
    ]

    static func zoneIndex(for watts: Int) -> Int {
        let pct = Double(watts) / Double(ftp)
        switch pct {
        case ..<0.55: return 0
        case ..<0.75: return 1
        case ..<0.90: return 2
        case ..<1.05: return 3
        case ..<1.20: return 4
        case ..<1.50: return 5
        default: return 6
        }
    }
}

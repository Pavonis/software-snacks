import Foundation
import HealthKit
import CoreLocation
import Combine

/// Runs the HealthKit workout session on the watch and folds in GPS data.
/// HealthKit supplies heart rate (wrist), active energy, and cycling distance;
/// CoreLocation supplies speed, altitude, grade, and the route line.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    enum Phase {
        case idle, requesting, active, paused, ended
    }

    @Published var phase: Phase = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var wristHeartRate: Int = 0
    @Published var activeCalories: Double = 0
    @Published var distanceMiles: Double = 0
    @Published var speedMph: Double = 0
    @Published var altitudeFeet: Double = 0
    @Published var elevationGainFeet: Double = 0
    @Published var gradePercent: Double = 0
    @Published var altitudeProfile: [Double] = []
    @Published var summary: RideSummary?
    @Published var healthAuthorized = false

    private(set) var startDate: Date = .now
    private(set) var routePoints: [RoutePoint] = []

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let locationManager = CLLocationManager()
    private var elapsedTimer: Timer?
    private var lastLocation: CLLocation?
    private var lastRoutePoint: CLLocation?
    private var gradeWindow: [(distance: Double, altitude: Double)] = []
    private var cumulativeDistanceMeters: Double = 0
    private var powerSamples: [Int] = []
    private var heartRateSamples: [Int] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKQuantityType.workoutType()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceCycling),
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { [weak self] granted, _ in
            Task { @MainActor in
                self?.healthAuthorized = granted
            }
        }
        locationManager.requestWhenInUseAuthorization()
    }

    func startRide() {
        guard phase == .idle || phase == .ended else { return }
        phase = .requesting
        summary = nil
        resetMetrics()

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            startDate = .now
            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { _, _ in }
            locationManager.startUpdatingLocation()
            startElapsedTimer()
            phase = .active
        } catch {
            phase = .idle
        }
    }

    func togglePause() {
        guard let session else { return }
        if phase == .active {
            session.pause()
            phase = .paused
        } else if phase == .paused {
            session.resume()
            phase = .active
        }
    }

    func endRide() {
        guard let session, let builder else {
            phase = .ended
            return
        }
        locationManager.stopUpdatingLocation()
        elapsedTimer?.invalidate()
        session.end()

        let endDate = Date.now
        builder.endCollection(withEnd: endDate) { [weak self] _, _ in
            builder.finishWorkout { _, _ in
                Task { @MainActor in
                    self?.finalizeSummary(endDate: endDate)
                }
            }
        }
    }

    func reset() {
        session = nil
        builder = nil
        summary = nil
        phase = .idle
    }

    /// External sensors report through SensorManager; the ride summary wants
    /// their averages, so the session model feeds samples in once a second.
    func recordSensorSample(power: Int, heartRate: Int) {
        guard phase == .active else { return }
        powerSamples.append(power)
        if heartRate > 0 { heartRateSamples.append(heartRate) }
    }

    private func resetMetrics() {
        elapsed = 0
        wristHeartRate = 0
        activeCalories = 0
        distanceMiles = 0
        speedMph = 0
        elevationGainFeet = 0
        gradePercent = 0
        altitudeProfile = []
        routePoints = []
        powerSamples = []
        heartRateSamples = []
        gradeWindow = []
        cumulativeDistanceMeters = 0
        lastLocation = nil
        lastRoutePoint = nil
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let builder = self.builder else { return }
                self.elapsed = builder.elapsedTime
            }
        }
    }

    private func finalizeSummary(endDate: Date) {
        let heartRate = heartRateSamples.isEmpty
            ? wristHeartRate
            : heartRateSamples.reduce(0, +) / heartRateSamples.count
        let power = powerSamples.isEmpty ? 0 : powerSamples.reduce(0, +) / powerSamples.count
        let hours = max(elapsed / 3600, 1.0 / 3600)
        summary = RideSummary(
            startDate: startDate,
            duration: elapsed,
            distanceMiles: distanceMiles,
            averagePower: power,
            averageSpeedMph: distanceMiles / hours,
            averageHeartRate: heartRate,
            activeCalories: activeCalories,
            elevationGainFeet: elevationGainFeet,
            route: routePoints
        )
        phase = .ended
    }

    private func ingest(location: CLLocation) {
        if location.speed >= 0 {
            speedMph = location.speed * 2.23694
        }
        altitudeFeet = location.altitude * 3.28084

        if let last = lastLocation {
            let delta = location.distance(from: last)
            cumulativeDistanceMeters += delta
            let climb = location.altitude - last.altitude
            if climb > 0.3 {
                elevationGainFeet += climb * 3.28084
            }
        }
        lastLocation = location

        gradeWindow.append((cumulativeDistanceMeters, location.altitude))
        gradeWindow.removeAll { cumulativeDistanceMeters - $0.distance > 60 }
        if let first = gradeWindow.first,
           cumulativeDistanceMeters - first.distance > 10 {
            let run = cumulativeDistanceMeters - first.distance
            let rise = location.altitude - first.altitude
            gradePercent = (rise / run) * 100
        }

        if altitudeProfile.isEmpty || cumulativeDistanceMeters.truncatingRemainder(dividingBy: 25) < 5 {
            altitudeProfile.append(altitudeFeet)
            if altitudeProfile.count > 120 { altitudeProfile.removeFirst() }
        }

        if lastRoutePoint == nil || location.distance(from: lastRoutePoint!) > 15 {
            routePoints.append(RoutePoint(latitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude))
            lastRoutePoint = location
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        Task { @MainActor in
            self.phase = .idle
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            Task { @MainActor in
                self.apply(statistics: statistics, for: quantityType)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func apply(statistics: HKStatistics, for type: HKQuantityType) {
        switch type {
        case HKQuantityType(.heartRate):
            let bpm = HKUnit.count().unitDivided(by: .minute())
            wristHeartRate = Int(statistics.mostRecentQuantity()?.doubleValue(for: bpm) ?? 0)
        case HKQuantityType(.activeEnergyBurned):
            activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        case HKQuantityType(.distanceCycling):
            distanceMiles = statistics.sumQuantity()?.doubleValue(for: .mile()) ?? 0
        default:
            break
        }
    }
}

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard self.phase == .active else { return }
            for location in locations where location.horizontalAccuracy >= 0 {
                self.ingest(location: location)
            }
        }
    }
}

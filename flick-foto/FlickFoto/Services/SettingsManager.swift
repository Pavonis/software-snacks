import SwiftUI

/// Manages persisted settings for flick behavior with access to default values
@MainActor
class SettingsManager: ObservableObject {
    // MARK: - Default Values (for showing initial position on sliders)

    static let defaults = Defaults()

    struct Defaults {
        let velocityThreshold: Double = 800
        let distanceThreshold: Double = 150
        let resistanceFactor: Double = 0.7
        let flyOffDuration: Double = 0.3
        let glowExponent: Double = 2.0
        let maxGlowRadius: Double = 20
        let maxGlowOpacity: Double = 0.8
        let cornerWedgeDegrees: Double = 50
    }

    // MARK: - Persisted Settings (Thresholds)

    @AppStorage("velocityThreshold") var velocityThreshold: Double = 800 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("distanceThreshold") var distanceThreshold: Double = 150 {
        didSet { objectWillChange.send() }
    }

    // MARK: - Persisted Settings (Feel)

    @AppStorage("resistanceFactor") var resistanceFactor: Double = 0.7 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("flyOffDuration") var flyOffDuration: Double = 0.3 {
        didSet { objectWillChange.send() }
    }

    // MARK: - Persisted Settings (Glow)

    @AppStorage("glowExponent") var glowExponent: Double = 2.0 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("maxGlowRadius") var maxGlowRadius: Double = 20 {
        didSet { objectWillChange.send() }
    }

    @AppStorage("maxGlowOpacity") var maxGlowOpacity: Double = 0.8 {
        didSet { objectWillChange.send() }
    }

    // MARK: - Persisted Settings (Direction Detection)

    @AppStorage("cornerWedgeDegrees") var cornerWedgeDegrees: Double = 50 {
        didSet { objectWillChange.send() }
    }

    // MARK: - Computed Configuration

    /// Generate a FlickConfiguration from current settings
    var config: FlickConfiguration {
        var config = FlickConfiguration()
        config.velocityThreshold = CGFloat(velocityThreshold)
        config.distanceThreshold = CGFloat(distanceThreshold)
        config.resistanceFactor = CGFloat(resistanceFactor)
        config.flyOffDuration = flyOffDuration
        config.glowExponent = CGFloat(glowExponent)
        config.maxGlowRadius = CGFloat(maxGlowRadius)
        config.maxGlowOpacity = CGFloat(maxGlowOpacity)
        config.cornerWedgeDegrees = cornerWedgeDegrees
        return config
    }

    // MARK: - Reset

    /// Reset all settings to defaults
    func resetToDefaults() {
        velocityThreshold = Self.defaults.velocityThreshold
        distanceThreshold = Self.defaults.distanceThreshold
        resistanceFactor = Self.defaults.resistanceFactor
        flyOffDuration = Self.defaults.flyOffDuration
        glowExponent = Self.defaults.glowExponent
        maxGlowRadius = Self.defaults.maxGlowRadius
        maxGlowOpacity = Self.defaults.maxGlowOpacity
        cornerWedgeDegrees = Self.defaults.cornerWedgeDegrees
    }
}

// MARK: - Setting Metadata

/// Metadata for a configurable setting (for UI generation)
struct SettingInfo {
    let key: String
    let label: String
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    let format: String

    static let all: [SettingInfo] = [
        // Thresholds
        SettingInfo(
            key: "velocityThreshold",
            label: "Velocity Threshold",
            range: 200...2000,
            step: 50,
            defaultValue: SettingsManager.defaults.velocityThreshold,
            format: "%.0f pt/s"
        ),
        SettingInfo(
            key: "distanceThreshold",
            label: "Distance Threshold",
            range: 50...300,
            step: 10,
            defaultValue: SettingsManager.defaults.distanceThreshold,
            format: "%.0f pt"
        ),
        // Feel
        SettingInfo(
            key: "resistanceFactor",
            label: "Resistance Factor",
            range: 0.1...1.0,
            step: 0.05,
            defaultValue: SettingsManager.defaults.resistanceFactor,
            format: "%.2f"
        ),
        SettingInfo(
            key: "flyOffDuration",
            label: "Fly-Off Duration",
            range: 0.1...1.0,
            step: 0.05,
            defaultValue: SettingsManager.defaults.flyOffDuration,
            format: "%.2f s"
        ),
        // Glow
        SettingInfo(
            key: "glowExponent",
            label: "Glow Exponent",
            range: 1.0...5.0,
            step: 0.25,
            defaultValue: SettingsManager.defaults.glowExponent,
            format: "%.2f"
        ),
        SettingInfo(
            key: "maxGlowRadius",
            label: "Max Glow Radius",
            range: 5...50,
            step: 1,
            defaultValue: SettingsManager.defaults.maxGlowRadius,
            format: "%.0f pt"
        ),
        SettingInfo(
            key: "maxGlowOpacity",
            label: "Max Glow Opacity",
            range: 0.2...1.0,
            step: 0.05,
            defaultValue: SettingsManager.defaults.maxGlowOpacity,
            format: "%.2f"
        ),
    ]
}

import SwiftUI

/// Configuration for flick gesture behavior - highly tweakable for testing
struct FlickConfiguration {
    // MARK: - Thresholds

    /// Minimum velocity (points/second) required to trigger a flick action
    var velocityThreshold: CGFloat = 800

    /// Minimum distance (points) required to trigger a flick action
    var distanceThreshold: CGFloat = 150

    // MARK: - Drag Behavior

    /// Resistance factor applied to drag (0 = no movement, 1 = no resistance)
    var resistanceFactor: CGFloat = 0.7

    // MARK: - Glow Effect

    /// Exponent for glow intensity curve (higher = more sudden glow near threshold)
    var glowExponent: CGFloat = 2.0

    /// Maximum blur radius for glow effect
    var maxGlowRadius: CGFloat = 20

    /// Maximum opacity for glow effect
    var maxGlowOpacity: CGFloat = 0.8

    // MARK: - Animation

    /// Spring animation for snap-back
    var snapBackAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.7)

    /// Duration for fly-off animation
    var flyOffDuration: Double = 0.3

    /// How far off-screen to animate (multiplier of screen height)
    var flyOffDistanceMultiplier: CGFloat = 1.5

    // MARK: - Stack Appearance

    /// Maximum rotation angle (degrees) for cards in stack
    var maxRotationDegrees: Double = 8

    /// Maximum position offset for cards in stack
    var maxPositionOffset: CGFloat = 10

    /// Scale reduction per card in stack
    var scaleReductionPerCard: CGFloat = 0.05

    /// Number of cards visible in stack (including top card)
    var visibleCardCount: Int = 4

    // MARK: - Presets

    static let `default` = FlickConfiguration()

    static let sensitive = FlickConfiguration(
        velocityThreshold: 500,
        distanceThreshold: 100,
        resistanceFactor: 0.85
    )

    static let resistant = FlickConfiguration(
        velocityThreshold: 1200,
        distanceThreshold: 200,
        resistanceFactor: 0.5
    )
}

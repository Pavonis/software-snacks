import SwiftUI
import Photos

/// A photo in the stack with its display properties
struct StackPhoto: Identifiable {
    /// Unique identifier for this stack photo
    let id: String

    /// The underlying photo asset from the library
    let asset: PHAsset

    /// Loaded image (nil until loaded)
    var image: UIImage?

    /// Random rotation for haphazard stack appearance (in degrees)
    let rotation: Double

    /// Random X offset for haphazard stack appearance
    let offsetX: CGFloat

    /// Random Y offset for haphazard stack appearance
    let offsetY: CGFloat

    /// Create a StackPhoto with random visual properties
    /// - Parameters:
    ///   - asset: The photo asset from PhotoKit
    ///   - config: Configuration to determine max rotation/offset values
    init(asset: PHAsset, config: FlickConfiguration = .default) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.image = nil

        // Generate seeded random values for consistent appearance
        var generator = SeededRandomGenerator(seed: asset.localIdentifier.hashValue)

        self.rotation = Double.random(
            in: -config.maxRotationDegrees...config.maxRotationDegrees,
            using: &generator
        )
        self.offsetX = CGFloat.random(
            in: -config.maxPositionOffset...config.maxPositionOffset,
            using: &generator
        )
        self.offsetY = CGFloat.random(
            in: -config.maxPositionOffset...config.maxPositionOffset,
            using: &generator
        )
    }

    /// Create a copy with a loaded image
    func withImage(_ image: UIImage?) -> StackPhoto {
        var copy = self
        copy.image = image
        return copy
    }
}

/// Simple seeded random number generator for consistent random values
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }

    mutating func next() -> UInt64 {
        // xorshift64 algorithm
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

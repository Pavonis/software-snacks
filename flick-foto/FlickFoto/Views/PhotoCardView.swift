import SwiftUI
import Photos

/// A single photo card styled as a Polaroid with flick gesture support
struct PhotoCardView: View {
    let photo: StackPhoto
    let config: FlickConfiguration
    let isInteractive: Bool
    let onFlick: (FlickDirection) -> Void

    /// Current drag offset (with resistance applied)
    @State private var offset: CGSize = .zero

    /// Whether the card is currently being dragged
    @State private var isDragging: Bool = false

    /// Whether the card is animating off screen
    @State private var isFlickingOff: Bool = false

    /// Direction the card is flying off (for animation)
    @State private var flickDirection: FlickDirection? = nil

    /// Fly-off offset for animation
    @State private var flyOffOffset: CGSize = .zero

    // MARK: - Polaroid Dimensions

    private let cardWidth: CGFloat = 280
    private let cardPadding: CGFloat = 16
    private let bottomPadding: CGFloat = 48
    private let photoCornerRadius: CGFloat = 2

    var body: some View {
        ZStack {
            // Polaroid frame
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            // Photo content
            VStack(spacing: 0) {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(
                            width: cardWidth - (cardPadding * 2),
                            height: cardWidth - (cardPadding * 2)
                        )
                        .clipped()
                        .cornerRadius(photoCornerRadius)
                } else {
                    // Loading placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(
                            width: cardWidth - (cardPadding * 2),
                            height: cardWidth - (cardPadding * 2)
                        )
                        .cornerRadius(photoCornerRadius)
                        .overlay(
                            ProgressView()
                        )
                }

                Spacer()
                    .frame(height: bottomPadding - cardPadding)
            }
            .padding(cardPadding)
        }
        .frame(width: cardWidth, height: cardWidth + bottomPadding)
        // Apply glow effect
        .background(
            glowView
        )
        // Apply transforms
        .rotationEffect(.degrees(photo.rotation + dragRotation))
        .offset(
            x: photo.offsetX + offset.width + flyOffOffset.width,
            y: photo.offsetY + offset.height + flyOffOffset.height
        )
        .opacity(isFlickingOff ? 0 : 1)
        // Gesture handling
        .gesture(isInteractive ? dragGesture : nil)
        .animation(isDragging ? nil : config.snapBackAnimation, value: offset)
    }

    // MARK: - Current Direction

    /// The current direction based on drag offset
    private var currentDirection: FlickDirection? {
        FlickDirection.from(offset: offset, cornerWedgeDegrees: config.cornerWedgeDegrees)
    }

    // MARK: - Glow Effect

    private var glowView: some View {
        let direction = currentDirection
        let intensity = glowIntensity

        return RoundedRectangle(cornerRadius: 4)
            .fill(direction?.color ?? .clear)
            .blur(radius: config.maxGlowRadius * intensity)
            .opacity(Double(intensity) * config.maxGlowOpacity)
    }

    /// Calculate glow intensity based on drag distance (exponential curve)
    private var glowIntensity: CGFloat {
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)
        let normalizedDistance = min(distance / config.distanceThreshold, 1.0)
        return pow(normalizedDistance, config.glowExponent)
    }

    // MARK: - Drag Rotation

    /// Slight rotation during drag for natural feel
    private var dragRotation: Double {
        guard isDragging else { return 0 }
        return Double(offset.width) * 0.05
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                // Apply resistance to the drag
                offset = CGSize(
                    width: value.translation.width * config.resistanceFactor,
                    height: value.translation.height * config.resistanceFactor
                )
            }
            .onEnded { value in
                isDragging = false
                handleDragEnd(value: value)
            }
    }

    private func handleDragEnd(value: DragGesture.Value) {
        // Calculate velocity from predicted end location
        let velocity = CGSize(
            width: value.predictedEndLocation.x - value.location.x,
            height: value.predictedEndLocation.y - value.location.y
        )

        // Calculate total velocity magnitude
        let velocityMagnitude = sqrt(velocity.width * velocity.width + velocity.height * velocity.height)

        // Calculate total distance
        let distance = sqrt(offset.width * offset.width + offset.height * offset.height)

        // Check if flick threshold is met
        let meetsVelocityThreshold = velocityMagnitude > config.velocityThreshold
        let meetsDistanceThreshold = distance > config.distanceThreshold

        if meetsVelocityThreshold || meetsDistanceThreshold {
            // Trigger flick action in detected direction
            if let direction = currentDirection {
                triggerFlick(direction: direction)
            } else {
                offset = .zero
            }
        } else {
            // Snap back
            offset = .zero
        }
    }

    private func triggerFlick(direction: FlickDirection) {
        flickDirection = direction
        isFlickingOff = true

        // Calculate fly-off offset based on direction
        let screenSize = UIScreen.main.bounds.size
        let flyDistance = max(screenSize.width, screenSize.height) * config.flyOffDistanceMultiplier

        // Use the direction's center angle to calculate fly-off vector
        let angle = direction.centerAngle
        let targetOffset = CGSize(
            width: cos(angle) * flyDistance,
            height: sin(angle) * flyDistance
        )

        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            flyOffOffset = targetOffset
        }

        // Notify after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + config.flyOffDuration) {
            onFlick(direction)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        // Mock photo card for preview
        PhotoCardView(
            photo: StackPhoto.preview,
            config: .default,
            isInteractive: true,
            onFlick: { direction in
                print("Flicked \(direction)")
            }
        )
    }
}

// MARK: - Preview Helper

extension StackPhoto {
    static var preview: StackPhoto {
        // Create a mock StackPhoto for previews
        // In real use, this would come from PhotoKit
        var photo = StackPhoto(
            asset: PHAsset(), // Empty asset for preview
            config: .default
        )
        // Create a simple colored image for preview
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        photo.image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        return photo
    }
}

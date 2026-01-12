import SwiftUI

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
        .offset(x: photo.offsetX + offset.width, y: photo.offsetY + offset.height)
        // Flick off-screen offset
        .offset(y: flickOffsetY)
        .opacity(isFlickingOff ? 0 : 1)
        // Gesture handling
        .gesture(isInteractive ? dragGesture : nil)
        .animation(isDragging ? nil : config.snapBackAnimation, value: offset)
    }

    // MARK: - Glow Effect

    private var glowView: some View {
        let direction = FlickDirection.from(verticalOffset: offset.height)
        let intensity = glowIntensity

        return RoundedRectangle(cornerRadius: 4)
            .fill(direction?.color ?? .clear)
            .blur(radius: config.maxGlowRadius * intensity)
            .opacity(intensity * config.maxGlowOpacity)
    }

    /// Calculate glow intensity based on drag distance (exponential curve)
    private var glowIntensity: CGFloat {
        let distance = abs(offset.height)
        let normalizedDistance = min(distance / config.distanceThreshold, 1.0)
        return pow(normalizedDistance, config.glowExponent)
    }

    // MARK: - Drag Rotation

    /// Slight rotation during drag for natural feel
    private var dragRotation: Double {
        guard isDragging else { return 0 }
        return Double(offset.width) * 0.05
    }

    // MARK: - Flick Animation

    private var flickOffsetY: CGFloat {
        guard isFlickingOff, let direction = flickDirection else { return 0 }
        let screenHeight = UIScreen.main.bounds.height
        return direction == .up ? -screenHeight * config.flyOffDistanceMultiplier : screenHeight * config.flyOffDistanceMultiplier
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

        let verticalVelocity = abs(velocity.height)
        let verticalDistance = abs(offset.height)

        // Check if flick threshold is met
        let meetsVelocityThreshold = verticalVelocity > config.velocityThreshold
        let meetsDistanceThreshold = verticalDistance > config.distanceThreshold

        if meetsVelocityThreshold || meetsDistanceThreshold {
            // Trigger flick action
            if let direction = FlickDirection.from(verticalOffset: offset.height) {
                triggerFlick(direction: direction)
            }
        } else {
            // Snap back
            offset = .zero
        }
    }

    private func triggerFlick(direction: FlickDirection) {
        flickDirection = direction
        isFlickingOff = true

        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            // The flickOffsetY computed property handles the actual movement
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

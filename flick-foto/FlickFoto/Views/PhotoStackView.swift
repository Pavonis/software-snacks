import SwiftUI

/// Displays a stack of photo cards with the top card interactive
struct PhotoStackView: View {
    @Binding var photos: [StackPhoto]
    let config: FlickConfiguration
    let onFlick: (StackPhoto, FlickDirection) -> Void

    var body: some View {
        ZStack {
            if photos.isEmpty {
                EmptyStackView()
            } else {
                // Show visible cards from bottom to top
                ForEach(Array(visiblePhotos.enumerated().reversed()), id: \.element.id) { index, photo in
                    let stackIndex = visiblePhotos.count - 1 - index
                    let isTopCard = stackIndex == 0

                    PhotoCardView(
                        photo: photo,
                        config: config,
                        isInteractive: isTopCard,
                        onFlick: { direction in
                            handleFlick(photo: photo, direction: direction)
                        }
                    )
                    .scaleEffect(scale(for: stackIndex))
                    .zIndex(Double(visiblePhotos.count - stackIndex))
                    .allowsHitTesting(isTopCard)
                }
            }
        }
    }

    /// Photos visible in the stack (limited by config)
    private var visiblePhotos: [StackPhoto] {
        Array(photos.prefix(config.visibleCardCount))
    }

    /// Calculate scale for a card at given stack position
    private func scale(for index: Int) -> CGFloat {
        1.0 - (CGFloat(index) * config.scaleReductionPerCard)
    }

    /// Handle a flick action on a photo
    private func handleFlick(photo: StackPhoto, direction: FlickDirection) {
        // Remove the photo from the stack
        withAnimation(.easeInOut(duration: 0.2)) {
            photos.removeAll { $0.id == photo.id }
        }

        // Notify the parent
        onFlick(photo, direction)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var photos: [StackPhoto] = []

        var body: some View {
            ZStack {
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                PhotoStackView(
                    photos: $photos,
                    config: .default,
                    onFlick: { photo, direction in
                        print("\(direction.emoji) \(direction.actionName) photo \(photo.id)")
                    }
                )
            }
            .onAppear {
                // Create mock photos for preview
                photos = (0..<5).map { i in
                    var photo = StackPhoto.preview
                    // Give each a unique ID for preview
                    return photo
                }
            }
        }
    }

    return PreviewWrapper()
}

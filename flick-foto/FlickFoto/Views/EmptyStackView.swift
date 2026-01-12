import SwiftUI

/// Empty state view showing a blank Polaroid
struct EmptyStackView: View {
    // Match PhotoCardView dimensions
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

            // Empty photo area
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(
                        width: cardWidth - (cardPadding * 2),
                        height: cardWidth - (cardPadding * 2)
                    )
                    .cornerRadius(photoCornerRadius)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.gray.opacity(0.4))

                            Text("All caught up!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    )

                Spacer()
                    .frame(height: bottomPadding - cardPadding)
            }
            .padding(cardPadding)
        }
        .frame(width: cardWidth, height: cardWidth + bottomPadding)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        EmptyStackView()
    }
}

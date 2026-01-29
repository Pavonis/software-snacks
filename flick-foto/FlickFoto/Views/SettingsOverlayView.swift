import SwiftUI

/// Floating settings button with expandable settings panel
struct SettingsOverlayView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var isExpanded = false

    var body: some View {
        VStack {
            Spacer()

            if isExpanded {
                settingsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            floatingButton
                .padding(.bottom, 20)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Floating Button

    private var floatingButton: some View {
        Button(action: {
            isExpanded.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                Image(systemName: isExpanded ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Flick Settings")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    withAnimation {
                        settingsManager.resetToDefaults()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Settings list
            ScrollView {
                VStack(spacing: 16) {
                    // Thresholds Section
                    SettingsSection(title: "Thresholds") {
                        SettingSlider(
                            label: "Velocity",
                            value: $settingsManager.velocityThreshold,
                            range: 200...2000,
                            defaultValue: SettingsManager.defaults.velocityThreshold,
                            format: "%.0f pt/s"
                        )
                        SettingSlider(
                            label: "Distance",
                            value: $settingsManager.distanceThreshold,
                            range: 50...300,
                            defaultValue: SettingsManager.defaults.distanceThreshold,
                            format: "%.0f pt"
                        )
                    }

                    // Feel Section
                    SettingsSection(title: "Feel") {
                        SettingSlider(
                            label: "Resistance",
                            value: $settingsManager.resistanceFactor,
                            range: 0.1...1.0,
                            defaultValue: SettingsManager.defaults.resistanceFactor,
                            format: "%.2f"
                        )
                        SettingSlider(
                            label: "Fly-Off Speed",
                            value: $settingsManager.flyOffDuration,
                            range: 0.1...1.0,
                            defaultValue: SettingsManager.defaults.flyOffDuration,
                            format: "%.2f s"
                        )
                    }

                    // Glow Section
                    SettingsSection(title: "Glow") {
                        SettingSlider(
                            label: "Exponent",
                            value: $settingsManager.glowExponent,
                            range: 1.0...5.0,
                            defaultValue: SettingsManager.defaults.glowExponent,
                            format: "%.1f"
                        )
                        SettingSlider(
                            label: "Radius",
                            value: $settingsManager.maxGlowRadius,
                            range: 5...50,
                            defaultValue: SettingsManager.defaults.maxGlowRadius,
                            format: "%.0f pt"
                        )
                        SettingSlider(
                            label: "Opacity",
                            value: $settingsManager.maxGlowOpacity,
                            range: 0.2...1.0,
                            defaultValue: SettingsManager.defaults.maxGlowOpacity,
                            format: "%.2f"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 400)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            content
        }
    }
}

// MARK: - Setting Slider

struct SettingSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let defaultValue: Double
    let format: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Custom slider with default marker
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Filled portion
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: thumbPosition(in: geometry.size.width), height: 6)

                    // Default value marker
                    defaultMarker(in: geometry.size.width)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .offset(x: thumbPosition(in: geometry.size.width) - 12)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            updateValue(from: gesture.location.x, in: geometry.size.width)
                        }
                )
            }
            .frame(height: 24)
        }
    }

    private func thumbPosition(in width: CGFloat) -> CGFloat {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(normalized) * width
    }

    private func defaultPosition(in width: CGFloat) -> CGFloat {
        let normalized = (defaultValue - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(normalized) * width
    }

    private func updateValue(from x: CGFloat, in width: CGFloat) {
        let normalized = max(0, min(1, x / width))
        value = range.lowerBound + Double(normalized) * (range.upperBound - range.lowerBound)
    }

    @ViewBuilder
    private func defaultMarker(in width: CGFloat) -> some View {
        let position = defaultPosition(in: width)

        VStack(spacing: 2) {
            // Tick mark
            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: 12)

            // Small label
            Text("•")
                .font(.system(size: 8))
                .foregroundColor(.orange)
        }
        .offset(x: position - 1, y: -8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        SettingsOverlayView(settingsManager: SettingsManager())
    }
}

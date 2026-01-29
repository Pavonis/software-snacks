import SwiftUI

/// Visual overlay showing the 8 flick target zones
struct ZoneIndicatorView: View {
    let config: FlickConfiguration
    let activeDirection: FlickDirection?
    let dragIntensity: CGFloat // 0-1, how close to triggering

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) * 0.45

            ZStack {
                // Zone wedges (subtle background)
                ForEach(FlickDirection.allCases, id: \.self) { direction in
                    ZoneWedge(
                        direction: direction,
                        center: center,
                        radius: radius,
                        config: config,
                        isActive: activeDirection == direction,
                        intensity: activeDirection == direction ? dragIntensity : 0
                    )
                }

                // Direction labels at edges
                ForEach(FlickDirection.allCases, id: \.self) { direction in
                    ZoneLabel(
                        direction: direction,
                        center: center,
                        radius: radius * 0.85,
                        isActive: activeDirection == direction
                    )
                }

                // Divider lines between zones
                ZoneDividers(center: center, radius: radius, config: config)
            }
        }
        .allowsHitTesting(false) // Don't intercept touches
    }
}

// MARK: - Zone Wedge

struct ZoneWedge: View {
    let direction: FlickDirection
    let center: CGPoint
    let radius: CGFloat
    let config: FlickConfiguration
    let isActive: Bool
    let intensity: CGFloat

    var body: some View {
        let wedgeSize = direction.isCorner ? config.cornerWedgeDegrees : (90 - config.cornerWedgeDegrees)
        let startAngle = Angle(radians: direction.centerAngle) - Angle(degrees: wedgeSize / 2)
        let endAngle = Angle(radians: direction.centerAngle) + Angle(degrees: wedgeSize / 2)

        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(direction.color.opacity(isActive ? 0.15 + (Double(intensity) * 0.2) : 0.05))
        .animation(.easeOut(duration: 0.15), value: isActive)
        .animation(.easeOut(duration: 0.1), value: intensity)
    }
}

// MARK: - Zone Label

struct ZoneLabel: View {
    let direction: FlickDirection
    let center: CGPoint
    let radius: CGFloat
    let isActive: Bool

    var body: some View {
        let angle = direction.centerAngle
        let x = center.x + cos(angle) * radius
        let y = center.y + sin(angle) * radius

        Text(direction.emoji)
            .font(.system(size: isActive ? 28 : 22))
            .opacity(isActive ? 1.0 : 0.4)
            .position(x: x, y: y)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Zone Dividers

struct ZoneDividers: View {
    let center: CGPoint
    let radius: CGFloat
    let config: FlickConfiguration

    var body: some View {
        let edgeWedge = 90 - config.cornerWedgeDegrees

        Path { path in
            // Draw 8 divider lines at the boundaries between zones
            for i in 0..<8 {
                // Calculate the boundary angle
                // Starting from right edge (0°), boundaries are at:
                // edgeHalf, edgeHalf + corner, edgeHalf + corner + edge, etc.
                let edgeHalf = edgeWedge / 2
                let cornerSize = config.cornerWedgeDegrees

                var boundaryAngle: Double
                switch i {
                case 0: boundaryAngle = edgeHalf                           // right/downRight boundary
                case 1: boundaryAngle = edgeHalf + cornerSize              // downRight/down boundary
                case 2: boundaryAngle = 90 + edgeHalf                      // down/downLeft boundary
                case 3: boundaryAngle = 90 + edgeHalf + cornerSize         // downLeft/left boundary
                case 4: boundaryAngle = 180 - edgeHalf                     // left boundary (wraps)
                case 5: boundaryAngle = -(180 - edgeHalf - cornerSize)     // left/upLeft boundary
                case 6: boundaryAngle = -(90 + edgeHalf)                   // upLeft/up boundary
                case 7: boundaryAngle = -(90 - edgeHalf)                   // up/upRight boundary
                default: boundaryAngle = 0
                }

                let angleRad = boundaryAngle * .pi / 180
                let innerRadius: CGFloat = 30
                let startX = center.x + cos(angleRad) * innerRadius
                let startY = center.y + sin(angleRad) * innerRadius
                let endX = center.x + cos(angleRad) * radius
                let endY = center.y + sin(angleRad) * radius

                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
        }
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.opacity(0.9)
            .ignoresSafeArea()

        ZoneIndicatorView(
            config: .default,
            activeDirection: .upRight,
            dragIntensity: 0.7
        )
    }
}

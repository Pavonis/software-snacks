import SwiftUI

struct ElevationView: View {
    @EnvironmentObject private var session: RideSession

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("ELEVATION")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%+.1f", session.workout.gradePercent))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            AltitudeSparkline(samples: session.workout.altitudeProfile)
                .frame(height: 56)

            Spacer(minLength: 0)

            HStack {
                SmallMetric(value: "\(Int(session.workout.elevationGainFeet))",
                            unit: "FT GAIN", color: .white, alignment: .leading)
                Spacer()
                SmallMetric(value: "\(Int(session.workout.altitudeFeet))",
                            unit: "ELEV FT", color: .white, alignment: .center)
                Spacer()
                SmallMetric(value: averageSpeed,
                            unit: "AVG MPH", color: .sottoSpeed, alignment: .trailing)
            }
        }
        .padding(.horizontal, 2)
    }

    private var averageSpeed: String {
        let hours = session.workout.elapsed / 3600
        guard hours > 0.005 else { return "0.0" }
        return RideFormat.miles(session.workout.distanceMiles / hours)
    }
}

struct AltitudeSparkline: View {
    let samples: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = normalized(in: proxy.size)
            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.12))

                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(Color.white.opacity(0.9),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Circle()
                        .fill(Color.sottoDistance)
                        .frame(width: 6, height: 6)
                        .position(points[points.count - 1])
                } else {
                    Text("Profile builds as you climb")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard samples.count > 1,
              let minValue = samples.min(),
              let maxValue = samples.max() else { return [] }
        let range = max(maxValue - minValue, 10)
        let stepX = size.width / CGFloat(samples.count - 1)
        return samples.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * stepX,
                y: size.height - (CGFloat((value - minValue) / range) * (size.height - 6)) - 3
            )
        }
    }
}

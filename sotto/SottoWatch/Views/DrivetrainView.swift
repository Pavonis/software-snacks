import SwiftUI

/// Drivetrain page. Gear position from AXS/Di2 is proprietary BLE, so until
/// that's cracked (or an SDK adopted) this shows the configured setup and an
/// estimated gear derived from speed + cadence + wheel circumference.
struct DrivetrainView: View {
    @EnvironmentObject private var session: RideSession

    var body: some View {
        let config = session.link.drivetrainConfig
        let estimate = estimatedGear(config: config)

        VStack(spacing: 5) {
            Text("DRIVETRAIN")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .kerning(1.5)
                .foregroundStyle(.secondary)

            if let estimate {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(estimate.chainring)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("×")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(estimate.cog)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.sottoSpeed)
                }
                Text("Est. gear \(estimate.index + 1) of \(config.speedCount) · ratio \(String(format: "%.2f", estimate.ratio))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("— × —")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Pedal to estimate gear")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            CassetteBars(cassette: config.cassette, activeIndex: estimate?.index)

            Text("Shift data needs AXS/Di2 protocol — estimated from speed + cadence")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 2)
    }

    private struct GearEstimate {
        var chainring: Int
        var cog: Int
        var index: Int
        var ratio: Double
    }

    /// speed = cadence × ratio × wheel circumference; invert for ratio, then
    /// pick the configured gear whose ratio is closest.
    private func estimatedGear(config: DrivetrainConfig) -> GearEstimate? {
        let cadence = Double(session.sensors.cadence)
        let speedMps = session.workout.speedMph / 2.23694
        guard cadence > 20, speedMps > 0.5 else { return nil }
        let wheelMeters = Double(config.wheelCircumferenceMM) / 1000
        let targetRatio = (speedMps * 60) / (cadence * wheelMeters)

        var best: GearEstimate?
        for ring in config.chainrings {
            for (index, cog) in config.cassette.enumerated() {
                let ratio = Double(ring) / Double(cog)
                if best == nil || abs(ratio - targetRatio) < abs(best!.ratio - targetRatio) {
                    best = GearEstimate(chainring: ring, cog: cog, index: index, ratio: ratio)
                }
            }
        }
        return best
    }
}

struct CassetteBars: View {
    let cassette: [Int]
    let activeIndex: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(cassette.enumerated()), id: \.offset) { index, cog in
                Capsule()
                    .fill(index == activeIndex ? Color.sottoSpeed : Color(white: 0.3))
                    .frame(width: 5, height: 12 + CGFloat(cog))
            }
        }
        .frame(height: 50, alignment: .bottom)
    }
}

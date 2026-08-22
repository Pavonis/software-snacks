import SwiftUI

/// The head-unit page: 3s power dominant with a zone bar,
/// speed / cadence / heart rate below, time + distance pinned top.
struct MetricsView: View {
    @EnvironmentObject private var session: RideSession

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(RideFormat.clock(session.workout.elapsed))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.sottoTime)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(RideFormat.miles(session.workout.distanceMiles))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("MI")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .opacity(0.7)
                }
                .foregroundStyle(Color.sottoDistance)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text("POWER · 3S")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .kerning(1.5)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(session.sensors.power3s)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("W")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .opacity(0.7)
                }
                .foregroundStyle(Color.sottoPower)
                ZoneBar(activeZone: PowerZones.zoneIndex(for: session.sensors.power3s))
                Text("ZONE \(PowerZones.zoneIndex(for: session.sensors.power3s) + 1) · \(PowerZones.zoneNames[PowerZones.zoneIndex(for: session.sensors.power3s)])")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack {
                SmallMetric(value: RideFormat.miles(session.workout.speedMph),
                            unit: "MPH", color: .sottoSpeed, alignment: .leading)
                Spacer()
                SmallMetric(value: "\(session.sensors.cadence)",
                            unit: "RPM", color: .sottoCadence, alignment: .center)
                Spacer()
                SmallMetric(value: "\(session.heartRate)",
                            unit: "BPM", color: .sottoHeart, alignment: .trailing)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct SmallMetric: View {
    let value: String
    let unit: String
    let color: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct ZoneBar: View {
    let activeZone: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<PowerZones.zoneColors.count, id: \.self) { zone in
                Capsule()
                    .fill(PowerZones.zoneColors[zone])
                    .opacity(zone == activeZone ? 1 : 0.25)
                    .frame(height: 5)
            }
        }
        .padding(.top, 4)
    }
}

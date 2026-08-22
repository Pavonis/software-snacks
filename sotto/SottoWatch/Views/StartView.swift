import SwiftUI

struct StartView: View {
    @EnvironmentObject private var session: RideSession

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("SOTTO")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .kerning(4)
                Text("Ready to ride")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                SensorChip(label: "PWR", connected: session.sensors.powerMeterConnected)
                SensorChip(label: "HR", connected: session.sensors.heartRateStrapConnected || session.workout.healthAuthorized)
                SensorChip(label: "GPS", connected: true)
            }

            Button {
                session.start()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Start Ride")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.sottoDistance)
            .foregroundStyle(.black)
        }
        .onAppear {
            session.workout.requestAuthorization()
            session.sensors.startScanning()
        }
    }
}

struct SensorChip: View {
    let label: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? Color.sottoDistance : Color(white: 0.35))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(connected ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.11), in: Capsule())
    }
}

import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var session: RideSession
    @State private var published = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                VStack(spacing: 1) {
                    Text("Ride Complete")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(session.workout.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                if let summary = session.workout.summary {
                    SummaryRow(label: "Time", value: RideFormat.clock(summary.duration), color: .sottoTime)
                    SummaryRow(label: "Distance", value: "\(RideFormat.miles(summary.distanceMiles)) MI", color: .sottoDistance)
                    SummaryRow(label: "Avg Power", value: "\(summary.averagePower) W", color: .sottoPower)
                    SummaryRow(label: "Avg Speed", value: "\(RideFormat.miles(summary.averageSpeedMph)) MPH", color: .sottoSpeed)
                    SummaryRow(label: "Avg Heart Rate", value: "\(summary.averageHeartRate) BPM", color: .sottoHeart)
                    SummaryRow(label: "Active Calories", value: "\(Int(summary.activeCalories)) CAL", color: .sottoCalories)
                    SummaryRow(label: "Elev Gain", value: "\(Int(summary.elevationGainFeet)) FT", color: .white)

                    Label("Saved to Apple Fitness", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                Button("Done") {
                    session.workout.reset()
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .onAppear {
            guard !published, let summary = session.workout.summary else { return }
            published = true
            session.publishSummary(summary)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RideStore
    @EnvironmentObject private var link: PhoneLink

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if link.rideActive, let snapshot = link.latestSnapshot {
                        LiveRideCard(snapshot: snapshot)
                    } else {
                        StartHero()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Recent Rides") {
                    if store.rides.isEmpty {
                        Text("No rides yet — start one from your watch.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.rides) { ride in
                            NavigationLink(value: ride.id) {
                                RideRow(ride: ride)
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("Sotto")
            .navigationDestination(for: UUID.self) { id in
                if let ride = store.rides.first(where: { $0.id == id }) {
                    RideDetailView(ride: ride)
                }
            }
        }
    }
}

private struct StartHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(.sottoGreen)
                Text("Start a ride on your watch")
                    .font(.headline)
            }
            Text("Sotto lives on your wrist. This app handles sensors, configuration, your ride archive — and mirrors live stats to the Lock Screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LiveRideCard: View {
    let snapshot: RideSnapshot

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Riding now", systemImage: "figure.outdoor.cycle")
                    .font(.headline)
                    .foregroundStyle(.sottoGreen)
                Spacer()
                Text(RideFormat.clock(snapshot.elapsedSeconds))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.sottoYellow)
            }
            HStack {
                LiveStat(value: "\(snapshot.power)", unit: "W", color: .sottoPurple)
                Spacer()
                LiveStat(value: RideFormat.miles(snapshot.speedMph), unit: "MPH", color: .sottoCyan)
                Spacer()
                LiveStat(value: RideFormat.miles(snapshot.distanceMiles), unit: "MI", color: .sottoGreen)
                Spacer()
                LiveStat(value: "\(snapshot.heartRate)", unit: "BPM", color: .sottoPink)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LiveStat: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct RideRow: View {
    let ride: RideSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "map")
                .font(.title3)
                .foregroundStyle(.sottoGreen)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(ride.name)
                    .font(.body.weight(.semibold))
                Text("\(ride.startDate.formatted(date: .abbreviated, time: .omitted)) · \(RideFormat.miles(ride.distanceMiles)) mi · \(RideFormat.clock(ride.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

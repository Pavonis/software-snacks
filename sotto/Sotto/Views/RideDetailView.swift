import SwiftUI
import MapKit

struct RideDetailView: View {
    let ride: RideSummary

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RouteMap(route: ride.route)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    StatTile(value: RideFormat.miles(ride.distanceMiles), label: "MILES", color: .sottoGreen)
                    StatTile(value: RideFormat.clock(ride.duration), label: "TIME", color: .sottoYellow)
                    StatTile(value: "\(Int(ride.elevationGainFeet))", label: "FT GAIN", color: .white)
                    StatTile(value: "\(ride.averagePower) W", label: "AVG POWER", color: .sottoPurple)
                    StatTile(value: RideFormat.miles(ride.averageSpeedMph), label: "AVG MPH", color: .sottoCyan)
                    StatTile(value: "\(Int(ride.activeCalories))", label: "ACTIVE CAL", color: .sottoRed)
                }

                HStack(spacing: 10) {
                    WideStat(label: "AVG HR", value: "\(ride.averageHeartRate) BPM", color: .sottoPink)
                }
            }
            .padding()
        }
        .navigationTitle(ride.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct RouteMap: View {
    let route: [RoutePoint]

    var body: some View {
        if route.count > 1 {
            let coordinates = route.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            Map(interactionModes: [.zoom, .pan]) {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.sottoGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                if let start = coordinates.first {
                    Annotation("Start", coordinate: start) {
                        Circle().fill(Color.sottoGreen).frame(width: 12, height: 12)
                    }
                }
                if let end = coordinates.last {
                    Annotation("End", coordinate: end) {
                        Circle().fill(Color.white).frame(width: 12, height: 12)
                    }
                }
            }
        } else {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                VStack(spacing: 6) {
                    Image(systemName: "map")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No route recorded")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WideStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

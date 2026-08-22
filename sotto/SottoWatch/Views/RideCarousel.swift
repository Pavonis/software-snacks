import SwiftUI
import WatchKit

/// The in-ride pager: Controls · Metrics · Elevation · Drivetrain · Music,
/// with Metrics as the default page — the watchOS Workout app pattern.
struct RideCarousel: View {
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            ControlsView().tag(0)
            MetricsView().tag(1)
            ElevationView().tag(2)
            DrivetrainView().tag(3)
            NowPlayingView().tag(4)
        }
    }
}

struct ControlsView: View {
    @EnvironmentObject private var session: RideSession
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                ControlButton(
                    title: "End",
                    systemImage: "xmark",
                    color: .sottoHeart
                ) {
                    session.end()
                }
                ControlButton(
                    title: session.workout.phase == .paused ? "Resume" : "Pause",
                    systemImage: session.workout.phase == .paused ? "play.fill" : "pause.fill",
                    color: .sottoTime
                ) {
                    session.workout.togglePause()
                }
            }
            GridRow {
                ControlButton(title: "Lock", systemImage: "lock.fill", color: .sottoSpeed) {
                    WKInterfaceDevice.current().enableWaterLock()
                }
                ControlButton(title: "Segment", systemImage: "flag.fill", color: .sottoDistance) {
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
        .opacity(isLuminanceReduced ? 0.6 : 1)
    }
}

private struct ControlButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Color(white: 0.14))
    }
}

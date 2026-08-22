import ActivityKit
import WidgetKit
import SwiftUI

struct SottoRideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SottoRideAttributes.self) { context in
            LockScreenRideView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.outdoor.cycle")
                            .foregroundStyle(WidgetPalette.green)
                        Text(timerInterval: context.state.startDate...Date(timeIntervalSinceNow: 60 * 60 * 12),
                             countsDown: false)
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetPalette.yellow)
                            .frame(maxWidth: 70)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(WidgetPalette.pink)
                        Text("\(context.state.heartRate)")
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetPalette.pink)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        IslandStat(value: "\(context.state.power) W", color: WidgetPalette.purple)
                        Spacer()
                        IslandStat(value: String(format: "%.1f MPH", context.state.speedMph),
                                   color: WidgetPalette.cyan)
                        Spacer()
                        IslandStat(value: String(format: "%.1f MI", context.state.distanceMiles),
                                   color: WidgetPalette.green)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.outdoor.cycle")
                    .foregroundStyle(WidgetPalette.green)
            } compactTrailing: {
                Text("\(context.state.power) W")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.purple)
            } minimal: {
                Image(systemName: "figure.outdoor.cycle")
                    .foregroundStyle(WidgetPalette.green)
            }
        }
    }
}

private struct LockScreenRideView: View {
    let context: ActivityViewContext<SottoRideAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WidgetPalette.green)
                    Text("Sotto · \(context.attributes.rideName)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(timerInterval: context.state.startDate...Date(timeIntervalSinceNow: 60 * 60 * 12),
                     countsDown: false)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.yellow)
                    .frame(maxWidth: 80)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                LockStat(value: "\(context.state.power)", unit: "W", label: "POWER", color: WidgetPalette.purple)
                Spacer()
                LockStat(value: String(format: "%.1f", context.state.speedMph), unit: "MPH", label: "SPEED", color: WidgetPalette.cyan)
                Spacer()
                LockStat(value: String(format: "%.1f", context.state.distanceMiles), unit: "MI", label: "DIST", color: WidgetPalette.green)
                Spacer()
                LockStat(value: "\(context.state.heartRate)", unit: "BPM", label: "HEART", color: WidgetPalette.pink)
            }
        }
        .padding(16)
    }
}

private struct LockStat: View {
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .opacity(0.75)
            }
            .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct IslandStat: View {
    let value: String
    let color: Color

    var body: some View {
        Text(value)
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}

/// Metric palette, duplicated here because the widget extension is its own
/// target and shouldn't pull in the app's view layer.
private enum WidgetPalette {
    static let yellow = Color(red: 1.0, green: 0.839, blue: 0.039)
    static let green = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let purple = Color(red: 0.749, green: 0.353, blue: 0.949)
    static let cyan = Color(red: 0.392, green: 0.824, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.216, blue: 0.373)
}

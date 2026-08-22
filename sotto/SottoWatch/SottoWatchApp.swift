import SwiftUI

@main
struct SottoWatchApp: App {
    @StateObject private var session = RideSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: RideSession

    var body: some View {
        switch session.workout.phase {
        case .idle, .requesting:
            StartView()
        case .active, .paused:
            RideCarousel()
        case .ended:
            SummaryView()
        }
    }
}

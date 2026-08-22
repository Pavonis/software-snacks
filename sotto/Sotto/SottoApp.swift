import SwiftUI

@main
struct SottoApp: App {
    @StateObject private var store: RideStore
    @StateObject private var link: PhoneLink

    init() {
        let store = RideStore()
        _store = StateObject(wrappedValue: store)
        _link = StateObject(wrappedValue: PhoneLink(store: store))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label("Ride", systemImage: "figure.outdoor.cycle") }
                SensorsView()
                    .tabItem { Label("Sensors", systemImage: "dot.radiowaves.left.and.right") }
            }
            .environmentObject(store)
            .environmentObject(link)
            .preferredColorScheme(.dark)
            .tint(.sottoGreen)
        }
    }
}

/// Sotto's metric palette, shared across the iOS screens and the widget.
extension Color {
    static let sottoYellow = Color(red: 1.0, green: 0.839, blue: 0.039)   // #FFD60A time
    static let sottoGreen = Color(red: 0.188, green: 0.820, blue: 0.345)  // #30D158 distance
    static let sottoPurple = Color(red: 0.749, green: 0.353, blue: 0.949) // #BF5AF2 power
    static let sottoCyan = Color(red: 0.392, green: 0.824, blue: 1.0)     // #64D2FF speed
    static let sottoOrange = Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A cadence
    static let sottoPink = Color(red: 1.0, green: 0.216, blue: 0.373)     // #FF375F heart
    static let sottoRed = Color(red: 1.0, green: 0.271, blue: 0.227)      // #FF453A calories
}

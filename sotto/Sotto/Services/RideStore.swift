import Foundation

/// Persists finished rides as JSON in Application Support.
/// Good enough for the prototype; swap for SwiftData later if it sticks.
final class RideStore: ObservableObject {
    @Published private(set) var rides: [RideSummary] = []

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("rides.json")
    }()

    init() {
        load()
    }

    func add(_ summary: RideSummary) {
        var named = summary
        named.name = Self.defaultName(for: summary.startDate)
        rides.insert(named, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        rides.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RideSummary].self, from: data) else { return }
        rides = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rides) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultName(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<12: return "Morning Ride"
        case 12..<17: return "Afternoon Ride"
        case 17..<21: return "Evening Ride"
        default: return "Night Ride"
        }
    }
}

import Foundation
import CoreLocation

/// One plan you opened, enough of it to open again: which kind of day, where, how long.
struct RecentTrip: Codable, Identifiable {
    var id = UUID()
    let intentID: String
    let placeName: String?
    let latitude: Double
    let longitude: Double
    let days: Int
    let createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    /// The recipe behind the trip, looked up from the stored id. `nil` only if an intent is
    /// ever removed from the app.
    var intent: DayIntent? { DayIntent.all.first { $0.id == intentID } }
}

/// The last few plans, so the home screen can offer "pick up where you left off".
///
/// Stored in `UserDefaults` — a handful of tiny records, not worth a database. Recorded the
/// moment a plan is opened, deduplicated by kind + place + length so opening the same day
/// twice does not fill the list with copies.
@MainActor
final class RecentTripsStore: ObservableObject {
    @Published private(set) var trips: [RecentTrip] = []

    private let key = "recentTrips.v1"
    private let maxTrips = 8

    init() { load() }

    func record(intent: DayIntent, placeName: String?,
                coordinate: CLLocationCoordinate2D, days: Int) {
        trips.removeAll {
            $0.intentID == intent.id && $0.placeName == placeName && $0.days == days
        }
        trips.insert(RecentTrip(intentID: intent.id, placeName: placeName,
                                latitude: coordinate.latitude, longitude: coordinate.longitude,
                                days: days, createdAt: Date()),
                     at: 0)
        if trips.count > maxTrips { trips = Array(trips.prefix(maxTrips)) }
        save()
    }

    func clear() {
        trips = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentTrip].self, from: data) else { return }
        trips = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

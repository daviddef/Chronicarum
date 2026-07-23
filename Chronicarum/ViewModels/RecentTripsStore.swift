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
    /// Starred to keep. Saved trips survive the recent cap and sit in their own section.
    var isSaved: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    /// The recipe behind the trip, looked up from the stored id. `nil` only if an intent is
    /// ever removed from the app.
    var intent: DayIntent? { DayIntent.all.first { $0.id == intentID } }
}

/// The plans you've opened — the last few automatically, and any you star to keep.
///
/// Stored in `UserDefaults`: a handful of tiny records, not worth a database. A plan is
/// recorded the moment it opens, deduplicated by kind + place + length. Only *unsaved*
/// recents are capped; a starred trip stays until you unstar it.
@MainActor
final class RecentTripsStore: ObservableObject {
    @Published private(set) var trips: [RecentTrip] = []

    private let key = "recentTrips.v1"
    private let maxRecent = 8

    /// Starred trips, newest first.
    var saved: [RecentTrip] { trips.filter(\.isSaved) }
    /// Recently opened but not starred, newest first.
    var recent: [RecentTrip] { trips.filter { !$0.isSaved } }

    init() { load() }

    func record(intent: DayIntent, placeName: String?,
                coordinate: CLLocationCoordinate2D, days: Int) {
        // Reopening the same day keeps its starred state rather than resetting it.
        let wasSaved = trips.first {
            $0.intentID == intent.id && $0.placeName == placeName && $0.days == days
        }?.isSaved ?? false

        trips.removeAll {
            $0.intentID == intent.id && $0.placeName == placeName && $0.days == days
        }
        trips.insert(RecentTrip(intentID: intent.id, placeName: placeName,
                                latitude: coordinate.latitude, longitude: coordinate.longitude,
                                days: days, createdAt: Date(), isSaved: wasSaved),
                     at: 0)
        prune()
        save()
    }

    func toggleSaved(_ trip: RecentTrip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index].isSaved.toggle()
        prune()
        save()
    }

    func clearRecent() {
        trips.removeAll { !$0.isSaved }
        save()
    }

    /// Keep every starred trip; keep only the newest few unstarred ones.
    private func prune() {
        var kept: [RecentTrip] = []
        var recentCount = 0
        for trip in trips {
            if trip.isSaved {
                kept.append(trip)
            } else if recentCount < maxRecent {
                kept.append(trip)
                recentCount += 1
            }
        }
        trips = kept
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

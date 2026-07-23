import Foundation
import CoreLocation

/// Where the app is currently pointed — the place you searched for on the home screen, or
/// nothing, meaning "wherever I am".
///
/// One object shared by every tab so a search on the home screen flows everywhere: Explore
/// lists near it, the map centres on it, a plan is built around it. Clearing it returns the
/// whole app to your own location.
@MainActor
final class AppFocus: ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var name: String?

    /// The place to work from, given a fallback of the user's own location.
    func origin(fallback: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        coordinate ?? fallback
    }

    func set(_ coordinate: CLLocationCoordinate2D, name: String) {
        self.coordinate = coordinate
        self.name = name
    }

    func clear() {
        coordinate = nil
        name = nil
    }
}

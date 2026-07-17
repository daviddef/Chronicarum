import Foundation
import CoreLocation

// MARK: - Conquest / Timeline Models

struct TimelinePeriod: Codable, Identifiable {
    let id: String             // e.g. "500bc", "100ad"
    let year: Int              // negative = BC
    let label: String          // e.g. "500 BC"
    let subtitle: String
    let empires: [Empire]
    let regionLabels: [RegionLabel]
    let nameChanges: [NameChange]
}

struct Empire: Codable, Identifiable {
    let id: String
    let name: String
    let color: String          // hex
    /// Polygon ring: array of [lon, lat] coordinate pairs
    let polygon: [[Double]]
    /// Label anchor position [lon, lat]
    let labelLongitude: Double
    let labelLatitude: Double

    var labelCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: labelLatitude, longitude: labelLongitude)
    }

    /// Convert polygon to CLLocationCoordinate2D array for MapKit overlay
    var coordinates: [CLLocationCoordinate2D] {
        polygon.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}

struct RegionLabel: Codable, Identifiable {
    let id: String
    let name: String
    let longitude: Double
    let latitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct NameChange: Codable, Identifiable {
    let id: String
    let oldName: String
    let newName: String
    let year: Int
}

// MARK: - Timeline State

struct TimelineState {
    var periodIndex: Int = 1       // default: 100 AD
    var isAnimating: Bool = false
    var isVisible: Bool = false

    var currentPeriod: TimelinePeriod? {
        guard periodIndex < TimelineData.periods.count else { return nil }
        return TimelineData.periods[periodIndex]
    }
}

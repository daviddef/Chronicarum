import Foundation
import CoreLocation
import Combine

/// Wraps CLLocationManager in a Combine-friendly interface.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: Error? = nil

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        error = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            // Surface an error to the UI
            error = LocationError.denied
        @unknown default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        Task { @MainActor in
            self.userLocation = loc.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            self.authorizationStatus = status
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                // Denying at the system prompt lands here, not in `requestLocation`.
                // Without this, a caller waiting on a fix would wait forever.
                self.error = LocationError.denied
            default:
                break
            }
        }
    }

    enum LocationError: LocalizedError {
        case denied
        var errorDescription: String? {
            "Location access denied. Enable it in Settings → Chronicarum."
        }
    }
}
